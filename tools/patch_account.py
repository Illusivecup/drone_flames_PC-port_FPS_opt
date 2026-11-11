import re

path = r'c:\Users\mxka\Documents\port\game\net\account.gd'
with open(path, 'r', encoding='utf-8') as f:
    code = f.read()

all_cosmetics = ['fr_steel', 'fr_concrete', 'fr_brick', 'fr_tin', 'fr_tape', 'fr_garage', 'fr_pipe', 'fr_sandbag', 'fr_crate', 'fr_net', 'fr_rotor', 'fr_circuit', 'fr_searchlight', 'fr_radar', 'fr_antenna', 'fr_barrier', 'fr_frost', 'fr_wires', 'fr_panel', 'fr_intercept', 'fr_copper', 'fr_storm', 'fr_fire', 'fr_aerostat', 'fr_dome', 'fr_flares', 'fr_dawn', 'fr_goldrotor', 'fr_dev', 'fr_cbt', 'fr_hw_web', 'fr_hw_candles', 'fr_hw_bats', 'fr_hw_pumpkin', 'bn_steel', 'bn_dusk', 'bn_yard', 'bn_garages', 'bn_tec', 'bn_field', 'bn_embankment', 'bn_tram', 'bn_snow', 'bn_roof', 'bn_droneport', 'bn_refinery', 'bn_workshop', 'bn_radar', 'bn_topo', 'bn_night', 'bn_fog', 'bn_bridge', 'bn_airfield', 'bn_intercept', 'bn_rebuild', 'bn_storm', 'bn_flares', 'bn_balloons', 'bn_swarm', 'bn_sunset', 'bn_orbit', 'bn_dawn', 'bn_dev', 'bn_cbt', 'bn_hw_pumpkins', 'bn_hw_ghosts', 'bn_hw_moon', 'bn_hw_night', 'tt_newbie', 'tt_dispatcher', 'tt_spotter', 'tt_radio', 'tt_mechanic', 'tt_operator', 'tt_garage', 'tt_signal', 'tt_stoker', 'tt_nightshift', 'tt_dronehunter', 'tt_navigator', 'tt_sentinel', 'tt_radarman', 'tt_oldtimer', 'tt_tactician', 'tt_loner', 'tt_wingman', 'tt_trio', 'tt_ace', 'tt_skyshield', 'tt_strategist', 'tt_duelist', 'tt_wing', 'tt_leader', 'tt_above', 'tt_legend', 'tt_eternal', 'tt_dev', 'tt_dev_rgb', 'tt_cbt']

# 1. Add ALL_COSMETICS constant
cosm_const = f"const ALL_COSMETICS: Array = {repr(all_cosmetics)}\n"
code = code.replace("const FILE: String = \"user://account.bin\"", cosm_const + "const FILE: String = \"user://account.bin\"")

# 2. Patch load_state
old_load_tail = """\t\tseen = d.get("s", [])
\t\tseen_init = bool(d.get("si", false))"""

new_load_tail = """\t\tseen = d.get("s", [])
\t\tseen_init = bool(d.get("si", false))
\tif owned.is_empty():
\t\towned = ALL_COSMETICS.duplicate()
\telse:
\t\tfor c in ALL_COSMETICS:
\t\t\tif not owned.has(c):
\t\t\t\towned.append(c)
\tseen = owned.duplicate()
\tseen_init = true
\tif not (info.get("cosmetics") is Dictionary) or info.get("cosmetics", {}).is_empty():
\t\tinfo["cosmetics"] = {"title": "tt_dev_rgb", "frame": "fr_dev", "banner": "bn_dev"}
\tif not info.has("username") or String(info.get("username", "")) == "":
\t\tinfo["username"] = "reborn"
\tinfo["is_multiplayer_available"] = true"""

code = code.replace(old_load_tail, new_load_tail)

# 3. Patch device_check_missing
old_dcm = """static func device_check_missing() -> bool:
\tNetConfig.load_cfg()
\treturn not DeviceCheck.available() and NetConfig.api_url.contains("snaipix.com")"""

new_dcm = """static func device_check_missing() -> bool:
\treturn false"""

code = code.replace(old_dcm, new_dcm)

# 4. Patch _signed
old_signed = """\tvar dc: Dictionary = await DeviceCheck.headers(hc.finish(), assertion_only)
\tif not bool(dc["ok"]):
\t\treturn {"code": 0, "data": null, "err": String(dc["err"])}
\treturn await Api.i().call_api(method, path, null, false, raw, dc["headers"])"""

new_signed = """\tvar dc_headers: PackedStringArray = PackedStringArray(["X-PC-Port: reborn"])
\tif DeviceCheck.available():
\t\tvar dc: Dictionary = await DeviceCheck.headers(hc.finish(), assertion_only)
\t\tif bool(dc.get("ok", false)):
\t\t\tdc_headers = dc["headers"]
\treturn await Api.i().call_api(method, path, null, false, raw, dc_headers)"""

code = code.replace(old_signed, new_signed)

# 5. Patch equip
old_equip = """static func equip(kind: String, code: Variant) -> Dictionary:
\tvar r: Dictionary = await Api.i().call_api("POST", "/user/cosmetics/equip", {kind: code})
\tif int(r["code"]) == 200 and r["data"] is Dictionary:
\t\t_take_cosmetics(r["data"])
\t\treturn {"ok": true, "err": "", "code": 200}
\treturn {"ok": false, "err": String(r["err"]), "code": int(r["code"])}"""

new_equip = """static func equip(kind: String, code: Variant) -> Dictionary:
\tif not (info.get("cosmetics") is Dictionary):
\t\tinfo["cosmetics"] = {}
\tif code == null or str(code) == "":
\t\tinfo["cosmetics"].erase(kind)
\telse:
\t\tinfo["cosmetics"][kind] = code
\t_save()
\t_changed()
\tif signed_in() and access != "":
\t\tApi.i().call_api("POST", "/user/cosmetics/equip", {kind: code})
\treturn {"ok": true, "err": "", "code": 200}"""

code = code.replace(old_equip, new_equip)

# 6. Patch username and signed_in
old_username = """static func username() -> String:
\tload_state()
\treturn String(info.get("username", ""))"""

new_username = """static func username() -> String:
\tload_state()
\tvar un: String = String(info.get("username", ""))
\treturn un if un != "" else "reborn" """

code = code.replace(old_username, new_username)

old_signed_in = """static func signed_in() -> bool:
\tload_state()
\treturn refresh_tok != \"\""""

new_signed_in = """static func signed_in() -> bool:
\tload_state()
\treturn true"""

code = code.replace(old_signed_in, new_signed_in)

with open(path, 'w', encoding='utf-8') as f:
    f.write(code)

print('Successfully patched account.gd!')
