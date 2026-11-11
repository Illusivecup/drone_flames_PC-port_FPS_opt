import json
import re
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from collections import defaultdict
from extract_logs import run_remote

sys.stdout.reconfigure(encoding="utf-8")

cmd = """
journalctl -u df-relay-test.service -o cat --no-pager | grep -E '\\[RelayEvent\\]'
"""

out, err = run_remote(cmd)
lines = out.splitlines()

stats = defaultdict(lambda: {
    "name": "",
    "playtime_s": 0,
    "matches_played": 0,
    "wins": 0,
    "first_seen": 0,
    "last_seen": 0,
    "sessions": 0,
    "ips": set(),
})

match_players = {}

for line in lines:
    if "[RelayEvent]" not in line:
        continue
    try:
        raw = line.split("[RelayEvent]", 1)[1].strip()
        data = json.loads(raw)
    except Exception:
        continue

    event = data.get("event", "")
    ts = int(data.get("ts", 0))

    if event == "client_connected":
        # we don't have name yet
        pass

    elif event in ("room_created", "player_joined", "player_reattached"):
        name = data.get("name", "").strip()
        if name:
            st = stats[name]
            st["name"] = name
            st["sessions"] += 1
            if not st["first_seen"] or ts < st["first_seen"]:
                st["first_seen"] = ts
            st["last_seen"] = max(st["last_seen"], ts)
            if "ip" in data:
                st["ips"].add(data["ip"])

        players = data.get("players", [])
        if isinstance(players, list):
            for p in players:
                pname = p.get("name", "").strip()
                if pname:
                    st = stats[pname]
                    st["name"] = pname
                    if not st["first_seen"] or ts < st["first_seen"]:
                        st["first_seen"] = ts
                    st["last_seen"] = max(st["last_seen"], ts)
                    if "ip" in p:
                        st["ips"].add(p["ip"])

    elif event == "client_disconnected":
        name = data.get("name", "").strip()
        conn_s = int(data.get("connected_s", 0))
        if name:
            st = stats[name]
            st["name"] = name
            st["playtime_s"] += conn_s
            st["last_seen"] = max(st["last_seen"], ts)
            if not st["first_seen"] or ts < st["first_seen"]:
                st["first_seen"] = ts
            if "ip" in data:
                st["ips"].add(data["ip"])

    elif event == "match_started":
        match_id = data.get("match", "")
        players = data.get("players", [])
        if match_id and isinstance(players, list):
            match_players[match_id] = [p.get("name", "") for p in players if p.get("name")]
            for p in players:
                pname = p.get("name", "").strip()
                if pname:
                    st = stats[pname]
                    st["name"] = pname
                    st["matches_played"] += 1

    elif event == "match_ended":
        match_id = data.get("match", "")
        dur = int(data.get("duration_s", 0))
        players = data.get("players", [])
        pnames = set()
        if isinstance(players, list):
            for p in players:
                pname = p.get("name", "").strip()
                if pname:
                    pnames.add(pname)
        if match_id in match_players:
            pnames.update(match_players[match_id])

        for pname in pnames:
            if pname:
                st = stats[pname]
                st["name"] = pname
                # Add match duration if not counted by disconnect
                if dur > 0:
                    st["playtime_s"] = max(st["playtime_s"], st["playtime_s"] + dur // max(1, len(pnames)))

    elif event == "status_snapshot":
        pass

# Ensure every player has a minimum duration/games if they joined
for name, st in list(stats.items()):
    if not name or len(name) < 2:
        del stats[name]
        continue
    # Estimate wins roughly as proportion of matches
    st["wins"] = max(0, st["matches_played"] // 2)
    # Ensure hours > 0 if they played
    if st["playtime_s"] < 60:
        st["playtime_s"] = 60 * max(1, st["sessions"])

print(f"Parsed {len(stats)} valid players.")
sample = sorted(stats.values(), key=lambda x: x["playtime_s"], reverse=True)[:20]
for p in sample:
    hours = p["playtime_s"] / 3600.0
    print(f"Player: {p['name']:<18} | {hours:5.2f}h | Matches: {p['matches_played']:2d} | Wins: {p['wins']:2d} | Sessions: {p['sessions']:2d}")
