import asyncio
import json
import ssl
import sys
import websockets

sys.stdout.reconfigure(encoding="utf-8")

async def test_auth():
    ssl_ctx = ssl.create_default_context()
    ssl_ctx.check_hostname = False
    ssl_ctx.verify_mode = ssl.CERT_NONE

    uri = "wss://45.145.12.165:19080/mp/signal"
    async with websockets.connect(uri, ssl=ssl_ctx) as ws:
        # Register a test account
        test_nick = f"TestPilot_{int(asyncio.get_event_loop().time()) % 10000}"
        test_pass = "securePass123"
        print(f"Registering {test_nick}...")
        await ws.send(json.dumps({"t": "auth_register", "username": test_nick, "password": test_pass}))
        res = await asyncio.wait_for(ws.recv(), timeout=5.0)
        data = json.loads(res)
        print("REGISTER RES:", data)
        token = data.get("token")
        assert data.get("t") == "auth_ok", f"Expected auth_ok, got {data}"

        # Login with correct password
        print(f"Logging in {test_nick}...")
        await ws.send(json.dumps({"t": "auth_login", "username": test_nick, "password": test_pass}))
        lres = await asyncio.wait_for(ws.recv(), timeout=5.0)
        ldata = json.loads(lres)
        print("LOGIN RES:", ldata)
        assert ldata.get("t") == "auth_ok"
        token = ldata.get("token")

        # Login with incorrect password
        print("Testing wrong password...")
        await ws.send(json.dumps({"t": "auth_login", "username": test_nick, "password": "wrongPassword"}))
        wres = await asyncio.wait_for(ws.recv(), timeout=5.0)
        wdata = json.loads(wres)
        print("WRONG PASS RES:", wdata)
        assert wdata.get("t") == "auth_fail"

        # Update cosmetics
        print("Saving profile cosmetics...")
        await ws.send(json.dumps({
            "t": "save_profile",
            "token": token,
            "cosmetics": {"frame": "fr_brick", "banner": "bn_yard", "title": "tt_ace"}
        }))
        cres = await asyncio.wait_for(ws.recv(), timeout=5.0)
        cdata = json.loads(cres)
        print("SAVE_PROFILE RES:", cdata)
        assert cdata.get("ok") is True

        # Sync stats (solo win + playtime)
        print("Syncing stats...")
        await ws.send(json.dumps({
            "t": "sync_stats",
            "token": token,
            "playtime_add_s": 300,
            "solo_wins_add": 1
        }))
        sres = await asyncio.wait_for(ws.recv(), timeout=5.0)
        sdata = json.loads(sres)
        print("SYNC_STATS RES:", sdata)
        assert sdata.get("ok") is True

    print("\nALL AUTH AND SYNC TESTS PASSED SUCCESSFULLY!")

asyncio.run(test_auth())
