import asyncio
import json
import ssl
import sys
import websockets

sys.stdout.reconfigure(encoding="utf-8")

async def test_live():
    ssl_ctx = ssl.create_default_context()
    ssl_ctx.check_hostname = False
    ssl_ctx.verify_mode = ssl.CERT_NONE

    uri = "wss://45.145.12.165:19080/mp/signal"
    print(f"Connecting to {uri}...")
    async with websockets.connect(uri, ssl=ssl_ctx) as ws:
        # 1. Test get_top
        await ws.send(json.dumps({"t": "get_top", "by": "hours", "limit": 10}))
        res = await asyncio.wait_for(ws.recv(), timeout=5.0)
        data = json.loads(res)
        print("GET_TOP RESPONSE:")
        print(f"Total users in database: {data.get('total_count')}")
        for r in data.get("list", []):
            dev_str = " [DEV]" if r.get("is_dev") else ""
            reg_str = " (Reg)" if r.get("is_registered") else " (Unreg)"
            print(f"  #{r.get('rank'):2d} {r.get('username')}{dev_str}{reg_str} - {r.get('hours')}h, {r.get('total_wins')} wins, cos: {r.get('cosmetics')}")

        # 2. Test search_profiles
        await ws.send(json.dumps({"t": "search_profiles", "query": "good"}))
        res = await asyncio.wait_for(ws.recv(), timeout=5.0)
        sdata = json.loads(res)
        print("\nSEARCH_PROFILES 'good':")
        for u in sdata.get("list", []):
            print(f"  Found: {u.get('username')} (dev: {u.get('is_dev')}, reg: {u.get('is_registered')})")

        # 3. Test get_profile
        await ws.send(json.dumps({"t": "get_profile", "username": "s0rrow"}))
        res = await asyncio.wait_for(ws.recv(), timeout=5.0)
        pdata = json.loads(res)
        print("\nGET_PROFILE 's0rrow':")
        print(f"  {pdata}")

asyncio.run(test_live())
