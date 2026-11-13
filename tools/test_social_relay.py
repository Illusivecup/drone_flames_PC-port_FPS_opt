"""Exercise the social protocol and guest migration against an isolated local relay."""
import asyncio
from contextlib import AsyncExitStack
import hashlib
import json
from pathlib import Path
import socket
import subprocess
import tempfile

import websockets

from migrate_guest_stats import apply, archive, guest_snapshot, read_database


async def request(ws, expected, **packet):
    await ws.send(json.dumps(packet))
    while True:
        result = json.loads(await asyncio.wait_for(ws.recv(), 4))
        if result["t"] == expected:
            return result
        if result["t"] in ("error", "auth_fail"):
            raise AssertionError((packet["t"], result["t"], result.get("why")))


async def social(ws, action, **fields):
    return await request(ws, "social_result", t="social", action=action, **fields)


async def scenario(uri):
    async with (
        websockets.connect(uri) as alice,
        websockets.connect(uri) as bob,
        websockets.connect(uri) as phone,
        websockets.connect(uri) as host,
    ):
        old = await request(alice, "auth_ok", t="auth_token", token="legacy", subscribe=True)
        assert old["user"]["playtime_s"] == 30
        guest = await request(bob, "auth_ok", t="auth_register", username="Guest", password="synthetic")
        token = guest["token"]
        assert guest["user"]["wins"] == 0
        await request(bob, "auth_ok", t="auth_token", token=token, subscribe=True)
        second = await request(phone, "auth_ok", t="auth_login", username="Guest", password="synthetic")
        phone_token = second["token"]
        await request(phone, "auth_ok", t="auth_token", token=phone_token, subscribe=True)

        assert not (await social(alice, "message", username="Guest", body="closed"))["ok"]
        await request(bob, "profile_saved", t="save_profile", token=token, message_visibility="all")
        assert (await social(alice, "message", username="Guest", body="open"))["ok"]
        assert (await social(phone, "state"))["conversations"][0]["unread"] == 1
        assert (await social(phone, "chat", username="Old"))["messages"][0]["body"] == "open"
        await request(bob, "profile_saved", t="save_profile", token=token, message_visibility="friends")
        assert not (await social(alice, "message", username="Guest", body="closed again"))["ok"]

        for _ in range(2):
            assert (await social(alice, "request", username="Guest"))["ok"]
        assert len((await social(bob, "state"))["incoming"]) == 1
        assert (await social(bob, "accept", username="Old"))["ok"]
        assert len((await social(alice, "state"))["friends"]) == 1
        assert (await social(alice, "message", username="Guest", body="hello"))["ok"]
        assert (await social(bob, "state"))["unread"] == 1
        assert (await social(phone, "chat", username="Old"))["messages"][-1]["body"] == "hello"
        assert (await social(bob, "state"))["unread"] == 0

        await request(bob, "profile_saved", t="save_profile", token=token,
                      avatar="sample", avatar_visibility="friends", flag="flag")
        friend_view = await request(alice, "profile_data", t="get_profile", username="Guest", token="legacy")
        public_view = await request(alice, "profile_data", t="get_profile", username="Guest", token="")
        assert friend_view["user"]["avatar"] == "sample" and public_view["user"]["avatar"] == ""
        assert friend_view["user"]["flag"] == "flag"

        room = await request(host, "room", t="host", auth_token="legacy", v="synthetic")
        assert (await social(alice, "invite", username="Guest", room=room["code"]))["ok"]
        invite = (await social(bob, "state"))["invites"][0]
        assert (await social(bob, "join_invite", invite=invite["id"]))["room"] == room["code"]
        assert not (await social(phone, "join_invite", invite=invite["id"]))["ok"]
        assert (await social(alice, "invite", username="Guest", room=room["code"]))["ok"]
        invite = (await social(bob, "state"))["invites"][0]
        await request(host, "turn", t="seal")
        assert not (await social(bob, "join_invite", invite=invite["id"]))["ok"]
        async with websockets.connect(uri) as temporary:
            closed_room = await request(temporary, "room", t="host", auth_token="legacy", v="synthetic")
            assert (await social(alice, "invite", username="Guest", room=closed_room["code"]))["ok"]
            closing_invite = (await social(bob, "state"))["invites"][0]
        await asyncio.sleep(0.15)
        assert not (await social(bob, "join_invite", invite=closing_invite["id"]))["ok"]

        async with AsyncExitStack() as sockets:
            new_host = await sockets.enter_async_context(websockets.connect(uri))
            full = await request(new_host, "room", t="host", auth_token="legacy", v="synthetic")
            assert (await social(alice, "invite", username="Guest", room=full["code"]))["ok"]
            filling_invite = (await social(bob, "state"))["invites"][0]
            for _ in range(7):
                guest_ws = await sockets.enter_async_context(websockets.connect(uri))
                await request(guest_ws, "joined", t="join", auth_token="legacy",
                              v="synthetic", code=full["code"])
            assert not (await social(bob, "join_invite", invite=filling_invite["id"]))["ok"]


        for _ in range(2):
            stats = await request(bob, "stats_synced", t="sync_stats", token=token,
                                  batch="batch", playtime_add_s=7)
            assert stats["user"]["playtime_s"] == 7
        await request(bob, "logged_out", t="auth_logout", token=token)
        await request(bob, "auth_fail", t="auth_token", token=token)
        assert "Guest" in (await social(alice, "state"))["online_users"]
        await request(phone, "logged_out", t="auth_logout", token=phone_token)
        assert "Guest" not in (await social(alice, "state"))["online_users"]
        assert (await social(alice, "message", username="Guest", body="offline"))["ok"]
        third = await request(phone, "auth_ok", t="auth_login", username="Guest", password="synthetic")
        await request(phone, "auth_ok", t="auth_token", token=third["token"], subscribe=True)
        assert (await social(phone, "state"))["unread"] == 1
        assert (await social(phone, "chat", username="Old"))["messages"][-1]["body"] == "offline"


async def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory() as folder:
        folder = Path(folder)
        db = folder / "users.json"
        registered = {
            "username": "Old", "is_registered": True, "token": "legacy", "salt": "s",
            "password_hash": hashlib.sha256(b"s:synthetic").hexdigest(), "playtime_s": 30,
        }
        db.write_text(json.dumps({"Old": registered, "Guest": {"username": "Guest", "wins": 16}}))
        snapshot = guest_snapshot(*read_database(db))
        archive(snapshot, folder / "archive")
        assert apply(db, snapshot) == 1
        assert apply(db, snapshot) == 0
        assert read_database(db)[1] == {"Old": registered}

        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        uri = f"ws://127.0.0.1:{port}"
        log = folder / "relay.log"
        with log.open("w") as output:
            relay = subprocess.Popen(
                ["godot", "--headless", "--path", str(root), "--script", "net/server/signal_server.gd",
                 "--", f"--db={db}", f"--port={port}", "--bind=127.0.0.1"],
                stdout=output, stderr=subprocess.STDOUT,
            )
        try:
            for _ in range(60):
                try:
                    async with websockets.connect(uri):
                        break
                except OSError:
                    await asyncio.sleep(0.1)
            else:
                raise AssertionError("Local relay did not start")
            await scenario(uri)
        finally:
            relay.terminate()
            relay.wait(timeout=5)
            errors = [line for line in log.read_text(errors="replace").splitlines() if "SCRIPT ERROR" in line]
            assert not errors, errors
    print("Guest migration and social relay checks passed")


if __name__ == "__main__":
    asyncio.run(main())
