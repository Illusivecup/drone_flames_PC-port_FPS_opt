import json
import os
import random
import sys
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
    "solo_wins": 0,
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

    if event in ("room_created", "player_joined", "player_reattached"):
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
                if dur > 0:
                    st["playtime_s"] = max(st["playtime_s"], st["playtime_s"] + dur // max(1, len(pnames)))

# Load cosmetics to pick random ones for users (non-dev)
cosmetics_path = os.path.join(os.path.dirname(__file__), "..", "ui", "cosmetics.json")
with open(cosmetics_path, "r", encoding="utf-8") as f:
    cos_data = json.load(f)

frames = [c["code"] for c in cos_data.get("items", []) if c.get("kind") == "frame" and c.get("exclusive") != "dev"]
banners = [c["code"] for c in cos_data.get("items", []) if c.get("kind") == "banner" and c.get("exclusive") != "dev"]
titles = [c["code"] for c in cos_data.get("items", []) if c.get("kind") == "title" and c.get("exclusive") != "dev"]

rng = random.Random(42)

DEV_NICKS = {"reborn", "reborn", "CryptoAngelazaz", "mxka"}

seed_users = {}

for name, st in stats.items():
    if not name or len(name) < 2:
        continue
    # Clean name
    clean_name = "".join(ch for ch in name if ord(ch) >= 32 and ord(ch) != 127).strip()[:16]
    if not clean_name:
        continue

    # Playtime hours
    playtime_s = max(st["playtime_s"], 120 * max(1, st["sessions"]))
    matches = max(st["matches_played"], 1 if playtime_s > 600 else 0)
    wins = max(0, matches // 2)
    solo_wins = rng.randint(0, max(1, wins // 2 + 1))

    is_dev = clean_name.lower() in [d.lower() for d in DEV_NICKS]

    # Pick cosmetics
    frame = "fr_dev" if is_dev else rng.choice(frames)
    banner = "bn_dev" if is_dev else rng.choice(banners)
    title = "tt_dev_rgb" if is_dev else (rng.choice(titles) if rng.random() > 0.3 else "")

    seed_users[clean_name] = {
        "username": clean_name,
        "password_hash": "",
        "salt": "",
        "is_registered": False, # Unregistered until user creates password
        "is_dev": is_dev,
        "token": "",
        "created_at": st["first_seen"] or 1794000000,
        "last_seen": st["last_seen"] or 1794300000,
        "playtime_s": playtime_s,
        "matches_played": matches,
        "wins": wins,
        "losses": max(0, matches - wins),
        "solo_wins": solo_wins,
        "avatar": "",
        "cosmetics": {
            "frame": frame,
            "banner": banner,
            "title": title
        }
    }

# Also ensure developer accounts exist in seed
for dn in DEV_NICKS:
    if dn not in seed_users:
        seed_users[dn] = {
            "username": dn,
            "password_hash": "",
            "salt": "",
            "is_registered": False,
            "is_dev": True,
            "token": "",
            "created_at": 1794000000,
            "last_seen": 1794327000,
            "playtime_s": 50000,
            "matches_played": 35,
            "wins": 25,
            "losses": 10,
            "solo_wins": 15,
            "avatar": "",
            "cosmetics": {
                "frame": "fr_dev",
                "banner": "bn_dev",
                "title": "tt_dev_rgb"
            }
        }

out_path = os.path.join(os.path.dirname(__file__), "..", "net", "server", "seed_users.json")
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(seed_users, f, ensure_ascii=False, indent=2)

print(f"Generated seed database with {len(seed_users)} users saved to {out_path}")
