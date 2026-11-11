#!/usr/bin/env python3
"""Read-only status monitor for the DroneFlames relay."""

from __future__ import annotations

import argparse
import asyncio
import collections
import datetime
import ipaddress
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
SSH_HELPER = Path.home() / ".codex" / "servers" / "remnawave-ssh.py"
CA_FILE = ROOT / "net" / "tls" / "df_relay_root.crt"
SIGNAL_URL = "wss://45.145.12.165:19080/mp/signal"
SERVICE = "df-relay-test.service"

REMOTE_READ = f"""set -e
printf '__STATE__\\n'
systemctl is-active {SERVICE} || true
printf '__TCP__\\n'
ss -Hnt state established sport = :19080
printf '__EVENTS__\\n'
journalctl -u {SERVICE} -o cat --no-pager | grep -E '\\[RelayEvent\\]|\\[Signal\\]' | tail -n 120 || true
"""


def read_remote() -> tuple[str, list[str], list[str]]:
    if not SSH_HELPER.is_file():
        raise RuntimeError(f"Не найден SSH helper: {SSH_HELPER}")
    temp_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", suffix=".sh", delete=False
        ) as temp:
            temp.write(REMOTE_READ)
            temp_path = Path(temp.name)
        result = subprocess.run(
            [sys.executable, str(SSH_HELPER), "--script", str(temp_path)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=30,
            check=False,
        )
        if result.returncode != 0:
            detail = (result.stderr or result.stdout).strip()
            raise RuntimeError(detail or f"SSH завершился с кодом {result.returncode}")
        chunks = result.stdout.split("__TCP__\n", 1)
        if len(chunks) != 2:
            raise RuntimeError("Не удалось разобрать ответ relay по SSH")
        before_tcp, after_tcp = chunks
        tcp_and_events = after_tcp.split("__EVENTS__\n", 1)
        if len(tcp_and_events) != 2:
            raise RuntimeError("В ответе relay отсутствует блок журнала")
        state_block = before_tcp.split("__STATE__\n", 1)[-1]
        state = next((line.strip() for line in state_block.splitlines() if line.strip()), "unknown")
        tcp_lines = [line.strip() for line in tcp_and_events[0].splitlines() if line.strip()]
        event_lines = [line.strip() for line in tcp_and_events[1].splitlines() if line.strip()]
        return state, tcp_lines, event_lines
    finally:
        if temp_path is not None:
            try:
                temp_path.unlink(missing_ok=True)
            except OSError:
                pass


def peer_endpoint(ss_line: str) -> str | None:
    fields = ss_line.split()
    if not fields:
        return None
    endpoint = fields[-1]
    if endpoint.startswith("[") and "]:" in endpoint:
        address, port = endpoint[1:].rsplit("]:", 1)
    elif ":" in endpoint:
        address, port = endpoint.rsplit(":", 1)
    else:
        return endpoint
    try:
        ip = ipaddress.ip_address(address)
        if isinstance(ip, ipaddress.IPv6Address) and ip.ipv4_mapped:
            address = str(ip.ipv4_mapped)
        else:
            address = str(ip)
    except ValueError:
        pass
    return f"{address}:{port}"


def active_room_codes(event_lines: list[str]) -> list[str]:
    active: set[str] = set()
    for line in event_lines:
        if "[Signal] listening on 19080" in line:
            # Room state is in memory and is lost whenever the relay process restarts.
            active.clear()
            continue
        opened = re.search(r"room ([A-Z0-9]{6}) opened", line)
        closed = re.search(r"room ([A-Z0-9]{6}) closed", line)
        if opened:
            active.add(opened.group(1))
        if closed:
            active.discard(closed.group(1))
    return sorted(active)


def relay_events(lines: list[str]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    marker = "[RelayEvent] "
    for line in lines:
        if marker not in line:
            continue
        try:
            event = json.loads(line.split(marker, 1)[1])
        except (json.JSONDecodeError, IndexError):
            continue
        if isinstance(event, dict):
            out.append(event)
    return out


async def read_rooms(codes: list[str]) -> tuple[list[dict[str, Any]], dict[str, bool]]:
    try:
        import websockets
    except ImportError as exc:
        raise RuntimeError("Не найден Python-пакет websockets; список лобби недоступен") from exc
    if not CA_FILE.is_file():
        raise RuntimeError(f"Не найден сертификат relay: {CA_FILE}")

    import ssl

    tls = ssl.create_default_context(cafile=str(CA_FILE))
    rooms: list[dict[str, Any]] = []
    sealed: dict[str, bool] = {}
    async with websockets.connect(
        SIGNAL_URL, ssl=tls, open_timeout=8, close_timeout=2, ping_interval=None
    ) as ws:
        await ws.send(json.dumps({"t": "list"}))
        response = json.loads(await asyncio.wait_for(ws.recv(), timeout=8))
        if response.get("t") != "rooms":
            raise RuntimeError("Relay вернул неожиданный ответ на запрос списка комнат")
        rooms = [row for row in response.get("rooms", []) if isinstance(row, dict)]
        for code in codes:
            await ws.send(json.dumps({"t": "peek", "code": code}))
            peek = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
            if peek.get("t") == "peek" and peek.get("code") == code:
                sealed[code] = bool(peek.get("open", False))
    return rooms, sealed


def render(state: str, tcp_lines: list[str], event_lines: list[str]) -> None:
    endpoints = [value for line in tcp_lines if (value := peer_endpoint(line))]
    by_ip: collections.Counter[str] = collections.Counter()
    for endpoint in endpoints:
        host = endpoint.rsplit(":", 1)[0]
        by_ip[host] += 1

    events = relay_events(event_lines)
    snapshots = [event for event in events if event.get("event") == "status_snapshot"]
    snapshot = snapshots[-1] if snapshots else {}

    os.system("cls" if os.name == "nt" else "clear")
    print("DroneFlames relay · только чтение")
    print(f"Снимок: {datetime.datetime.now().astimezone().strftime('%d.%m.%Y %H:%M:%S %Z')}")
    print(f"Сервис: {state}")
    print(f"Активных TCP-подключений к relay: {len(endpoints)}")
    if by_ip:
        print("Источники (IP: число подключений):")
        for ip, count in sorted(by_ip.items(), key=lambda item: (-item[1], item[0])):
            print(f"  {ip}: {count}")
    else:
        print("Источников сейчас нет.")

    if snapshot:
        snapshot_ts = int(snapshot.get("ts", 0))
        snapshot_time = datetime.datetime.fromtimestamp(snapshot_ts).astimezone().strftime("%H:%M:%S") if snapshot_ts else "?"
        print(f"\nАктивные комнаты: {len(snapshot.get('rooms', []))} · снимок relay {snapshot_time}")
        for room in snapshot.get("rooms", []):
            state_name = {"running": "матч", "lobby": "лобби", "ended": "завершён"}.get(str(room.get("state", "")), str(room.get("state", "")))
            seconds = int(room.get("duration_s", 0))
            duration = f"{seconds // 60}м {seconds % 60}с"
            match_id = str(room.get("match", ""))[:8]
            start_at = int(room.get("started_at", 0) or room.get("created_at", 0))
            started = datetime.datetime.fromtimestamp(start_at).astimezone().strftime("%H:%M") if start_at else ""
            duration_label = f"{state_name} {duration}" if room.get("started_at", 0) else f"лобби {duration}"
            access = "публичная" if room.get("public") else "по коду"
            print(f"  {room.get('code', '')} · {room.get('name') or 'Комната'} · {access} · {duration_label} · с {started} · матч {match_id} · v{room.get('version', '')}")
            for player in room.get("players", []):
                joined_at = int(player.get("joined_at", 0))
                player_seconds = max(0, int(time.time()) - joined_at) if joined_at else 0
                print(f"    слот {player.get('slot')}: {player.get('name') or 'без ника'} · {player.get('ip', '?')} · v{player.get('version', '')} · {player_seconds // 60}м в комнате")
        idle = snapshot.get("unassigned", [])
        print(f"Подключены вне комнаты: {len(idle)}")
        for client in idle:
            print(f"  {client.get('name') or 'без ника'} · {client.get('ip', '?')} · v{client.get('version', '')} · {int(client.get('connected_s', 0))}с")
    else:
        codes = active_room_codes(event_lines)
        try:
            rooms, sealed = asyncio.run(read_rooms(codes))
            room_error = ""
        except Exception as exc:  # legacy relay fallback until it emits structured status snapshots
            rooms, sealed = [], {}
            room_error = str(exc)
        started = [code for code, is_sealed in sealed.items() if is_sealed]
        print(f"\nОткрытых публичных лобби: {len(rooms)}")
        for room in rooms:
            print(f"  {room.get('name') or 'Комната'}: {int(room.get('n', 0))}/{int(room.get('max', 0))}")
        print(f"Матчей, которым relay отправил сигнал старта: {len(started)}")
        print("Детали игроков появятся после обновления relay-сервера.")
        if room_error:
            print(f"Список комнат недоступен: {room_error}")

    failures = [event for event in events if event.get("event") in {
        "connection_rejected", "room_create_rejected", "join_rejected", "reattach_rejected",
        "tls_handshake_failed", "websocket_handshake_failed", "websocket_handshake_timeout",
        "protocol_error", "signaling_rejected",
    }]
    if failures:
        print("\nПоследние ошибки подключения:")
        for event in failures[-8:]:
            version = event.get("client_version", event.get("version", ""))
            print(f"  {event.get('event')}: {event.get('reason', '')} · {event.get('name') or event.get('ip', '')} · v{version}")
    ended = [event for event in events if event.get("event") == "match_ended"]
    if ended:
        print("\nНедавно завершились:")
        for event in ended[-5:]:
            seconds = int(event.get("duration_s", 0))
            print(f"  {event.get('name') or event.get('room', 'Матч')} · {seconds // 60}м {seconds % 60}с · {event.get('reason', '')} · v{event.get('version', '')}")
    print("\nIP показывает адрес выхода в интернет (возможны NAT/VPN/мобильная сеть), не личность и не точный адрес.")
    print("Снимок комнат обновляется на сервере раз в 30 секунд; TCP-счётчик берётся в момент опроса.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Read-only DroneFlames relay monitor")
    parser.add_argument("--once", action="store_true", help="сделать один снимок и выйти")
    parser.add_argument("--interval", type=float, default=10.0, help="интервал опроса в секундах (по умолчанию 10)")
    args = parser.parse_args()
    interval = max(5.0, args.interval)
    while True:
        try:
            state, tcp_lines, event_lines = read_remote()
            render(state, tcp_lines, event_lines)
        except KeyboardInterrupt:
            print("\nОстановлено.")
            return 0
        except Exception as exc:
            print(f"Не удалось проверить relay: {exc}", file=sys.stderr)
            if args.once:
                return 1
        if args.once:
            return 0
        try:
            time.sleep(interval)
        except KeyboardInterrupt:
            print("\nОстановлено.")
            return 0


if __name__ == "__main__":
    raise SystemExit(main())
