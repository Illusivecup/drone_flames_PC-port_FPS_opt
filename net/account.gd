class_name Account
extends RefCounted

const ALL_COSMETICS: Array = [
	'fr_steel', 'fr_concrete', 'fr_brick', 'fr_tin', 'fr_tape', 'fr_garage', 'fr_pipe',
	'fr_sandbag', 'fr_crate', 'fr_net', 'fr_rotor', 'fr_circuit', 'fr_searchlight',
	'fr_radar', 'fr_antenna', 'fr_barrier', 'fr_frost', 'fr_wires', 'fr_panel',
	'fr_intercept', 'fr_copper', 'fr_storm', 'fr_fire', 'fr_aerostat', 'fr_dome',
	'fr_flares', 'fr_dawn', 'fr_goldrotor', 'fr_dev', 'fr_cbt', 'fr_hw_web', 'fr_hw_candles',
	'fr_hw_bats', 'fr_hw_pumpkin', 'bn_steel', 'bn_dusk', 'bn_yard', 'bn_garages', 'bn_tec',
	'bn_field', 'bn_embankment', 'bn_tram', 'bn_snow', 'bn_roof', 'bn_droneport', 'bn_refinery',
	'bn_workshop', 'bn_radar', 'bn_topo', 'bn_night', 'bn_fog', 'bn_bridge', 'bn_airfield',
	'bn_intercept', 'bn_rebuild', 'bn_storm', 'bn_flares', 'bn_balloons', 'bn_swarm', 'bn_sunset',
	'bn_orbit', 'bn_dawn', 'bn_dev', 'bn_cbt', 'bn_hw_pumpkins', 'bn_hw_ghosts', 'bn_hw_moon',
	'bn_hw_night', 'tt_newbie', 'tt_dispatcher', 'tt_spotter', 'tt_radio', 'tt_mechanic',
	'tt_operator', 'tt_garage', 'tt_signal', 'tt_stoker', 'tt_nightshift', 'tt_dronehunter',
	'tt_navigator', 'tt_sentinel', 'tt_radarman', 'tt_oldtimer', 'tt_tactician', 'tt_loner',
	'tt_wingman', 'tt_trio', 'tt_ace', 'tt_skyshield', 'tt_strategist', 'tt_duelist', 'tt_wing',
	'tt_leader', 'tt_above', 'tt_legend', 'tt_eternal', 'tt_dev', 'tt_dev_rgb', 'tt_cbt'
]

const COMMON_FRAMES: Array = [
	"fr_steel", "fr_concrete", "fr_brick", "fr_tin", "fr_tape", "fr_garage", "fr_pipe",
	"fr_sandbag", "fr_crate", "fr_net", "fr_rotor", "fr_circuit", "fr_searchlight",
	"fr_radar", "fr_antenna", "fr_barrier", "fr_frost", "fr_wires", "fr_panel",
	"fr_intercept", "fr_copper", "fr_storm", "fr_fire", "fr_aerostat", "fr_dome",
	"fr_flares", "fr_dawn", "fr_goldrotor"
]

const COMMON_BANNERS: Array = [
	"bn_steel", "bn_dusk", "bn_yard", "bn_garages", "bn_tec", "bn_field", "bn_embankment",
	"bn_tram", "bn_snow", "bn_roof", "bn_droneport", "bn_refinery", "bn_workshop",
	"bn_radar", "bn_topo", "bn_night", "bn_fog", "bn_bridge", "bn_airfield",
	"bn_intercept", "bn_rebuild", "bn_storm", "bn_flares", "bn_balloons", "bn_swarm",
	"bn_sunset", "bn_orbit", "bn_dawn"
]

const COMMON_TITLES: Array = [
	"tt_newbie", "tt_dispatcher", "tt_spotter", "tt_radio", "tt_mechanic", "tt_operator",
	"tt_garage", "tt_signal", "tt_stoker", "tt_nightshift", "tt_dronehunter",
	"tt_navigator", "tt_sentinel", "tt_radarman", "tt_oldtimer", "tt_tactician",
	"tt_loner", "tt_wingman", "tt_trio", "tt_ace", "tt_skyshield", "tt_strategist",
	"tt_duelist", "tt_wing", "tt_leader", "tt_above", "tt_legend", "tt_eternal"
]

const DEV_NICKS: Array = ["reborn_team", "CryptoAngelazaz", "mxka"]
const NICK_RULE: String = "НИК: ТОЛЬКО ЛАТИНИЦА И ЦИФРЫ"

const FILE: String = "user://account.bin"
const JSON_BACKUP: String = "user://account_data.json"

static var access: String = ""
static var token: String = ""
static var info: Dictionary = {}
static var last_email: String = ""
static var expired: bool = false
static var _loaded: bool = false
static var persist: bool = true

static var avatar_b64: String:
	get:
		load_state()
		return String(info.get("avatar", ""))
	set(v):
		load_state()
		info["avatar"] = v

static var owned: Array = []
static var seen: Array = []
static var seen_init: bool = false
static var catalog: Dictionary = {}

static var pending_playtime_s: int = 0
static var pending_solo_wins: int = 0
static var _syncing: bool = false

static var _avatar_cache: Dictionary = {}


static func load_state() -> void:
	if _loaded:
		return
	_loaded = true
	if not persist:
		return
	var d: Variant = DeviceCheck.secure_load("account", FILE, "|droneflames-account-1")
	if not (d is Dictionary) and FileAccess.file_exists(JSON_BACKUP):
		var jf: = FileAccess.open(JSON_BACKUP, FileAccess.READ)
		if jf != null:
			var txt: String = jf.get_as_text()
			jf.close()
			d = JSON.parse_string(txt)
	
	if d is Dictionary:
		access = String(d.get("a", ""))
		token = access
		info = d.get("i", {})
		last_email = String(d.get("e", ""))
		seen = d.get("s", [])
		seen_init = bool(d.get("si", false))
		pending_playtime_s = int(d.get("pp", 0))
		pending_solo_wins = int(d.get("psw", 0))
	
	if not info.has("username") or String(info.get("username", "")).strip_edges() == "":
		NetConfig.load_cfg()
		var n: String = NetConfig.nick()
		info["username"] = n if n != "" else "reborn_player"
	
	info["is_multiplayer_available"] = true
	
	_ensure_all_cosmetics()
	
	# Clean developer cosmetics for non-devs
	if not is_dev():
		var c_dict: Dictionary = info.get("cosmetics", {})
		var changed: bool = false
		if String(c_dict.get("title", "")) in ["tt_dev_rgb", "tt_dev"]:
			c_dict["title"] = ""
			changed = true
		if String(c_dict.get("frame", "")) == "fr_dev":
			c_dict["frame"] = COMMON_FRAMES[randi() % COMMON_FRAMES.size()]
			changed = true
		if String(c_dict.get("banner", "")) == "bn_dev":
			c_dict["banner"] = COMMON_BANNERS[randi() % COMMON_BANNERS.size()]
			changed = true
		if changed:
			info["cosmetics"] = c_dict
			_save()


static func _save() -> void:
	if not persist:
		return
	var save_dict: Dictionary = {
		"a": access,
		"i": info,
		"e": last_email,
		"s": seen,
		"si": seen_init,
		"pp": pending_playtime_s,
		"psw": pending_solo_wins
	}
	DeviceCheck.secure_store("account", save_dict, FILE, "|droneflames-account-1")
	# Save human-readable JSON backup as safety fallback
	var f: = FileAccess.open(JSON_BACKUP, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(save_dict, "\t"))
		f.close()


static func _changed() -> void:
	Api.i().account_changed.emit()


static func signed_in() -> bool:
	load_state()
	return is_authenticated()


static func is_authenticated() -> bool:
	load_state()
	return access != "" and bool(info.get("is_registered", false))


static func is_dev() -> bool:
	load_state()
	return bool(info.get("is_dev", false)) or is_dev_name(username())


static func is_dev_name(uname: String) -> bool:
	var l: String = uname.strip_edges().to_lower()
	for d: String in DEV_NICKS:
		if d.to_lower() == l:
			return true
	return false


static func username() -> String:
	load_state()
	var un: String = String(info.get("username", ""))
	if un != "":
		return un
	NetConfig.load_cfg()
	return NetConfig.nick()


static func mp_ok() -> bool:
	return bool(info.get("is_multiplayer_available", true))


static func mp_open() -> bool:
	return mp_ok() and suspended_s() <= 0


static func suspended_s() -> int:
	return 0


static func suspension_reason() -> String:
	return ""


static func suspension_until() -> String:
	return ""


static func suspension_left() -> String:
	return ""


static func device_check_missing() -> bool:
	return false


static func _ensure_all_cosmetics() -> void:
	var dev: bool = is_dev()
	if dev:
		owned = ALL_COSMETICS.duplicate()
	else:
		owned = ALL_COSMETICS.filter(func(c: String) -> bool:
			return not c in ["fr_dev", "bn_dev", "tt_dev", "tt_dev_rgb"]
		)
	seen = owned.duplicate()
	seen_init = true
	
	if not (info.get("cosmetics") is Dictionary) or (info.get("cosmetics", {}) as Dictionary).is_empty():
		var rf: String = "fr_dev" if dev else COMMON_FRAMES[randi() % COMMON_FRAMES.size()]
		var rb: String = "bn_dev" if dev else COMMON_BANNERS[randi() % COMMON_BANNERS.size()]
		var rt: String = "tt_dev_rgb" if dev else (COMMON_TITLES[randi() % COMMON_TITLES.size()] if randf() > 0.4 else "")
		info["cosmetics"] = {"title": rt, "frame": rf, "banner": rb}


static func equipped() -> Dictionary:
	load_state()
	var c: Variant = info.get("cosmetics", {})
	if c is Dictionary and not (c as Dictionary).is_empty():
		return c
	return {"title": "", "frame": "fr_steel", "banner": "bn_steel"}


static func unseen() -> Array:
	return []


static func mark_seen(_code: String) -> void:
	pass


static func fetch_cosmetics() -> Dictionary:
	load_state()
	_ensure_all_cosmetics()
	if catalog.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(Cosmetics.FILE))
		if d is Dictionary:
			for it: Dictionary in (d as Dictionary).get("items", []):
				catalog[String(it["code"])] = it
	return {"ok": true, "err": ""}


static func fetch_info() -> Dictionary:
	load_state()
	if access != "":
		var res: Dictionary = await get_profile(username())
		if bool(res.get("ok", false)) and res.get("user") is Dictionary:
			var u: Dictionary = res["user"]
			info.merge(u, true)
			_ensure_all_cosmetics()
			_save()
			_changed()
	return {"ok": true, "data": info}


## Calls our multiplayer relay server via WebSocket
static func call_server(msg: Dictionary, timeout_s: float = 6.0) -> Dictionary:
	load_state()
	NetConfig.load_cfg()
	var url: String = NetConfig.signal_url
	if url == "":
		return {"ok": false, "err": "Сервер не настроен"}
	
	var ws: = WebSocketPeer.new()
	ws.inbound_buffer_size = 1048576
	ws.outbound_buffer_size = 1048576
	ws.max_queued_packets = 2048
	var tls: TLSOptions = NetTls.for_url(url)
	var err: int = ws.connect_to_url(url, tls)
	if err != OK:
		return {"ok": false, "err": "Не удалось подключиться к серверу"}
	
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return {"ok": false, "err": "No scene tree"}
	
	var t0: int = Time.get_ticks_msec()
	var connected: bool = false
	
	while Time.get_ticks_msec() - t0 < int(timeout_s * 1000.0):
		ws.poll()
		var st: int = ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			connected = true
			break
		elif st == WebSocketPeer.STATE_CLOSED:
			return {"ok": false, "err": "Ошибка соединения с сервером"}
		await tree.process_frame
	
	if not connected:
		ws.close()
		return {"ok": false, "err": "Таймаут соединения с сервером"}
	
	ws.send_text(JSON.stringify(msg))
	
	var expected_type: String = ""
	match String(msg.get("t", "")):
		"auth_register", "auth_login", "auth_token":
			expected_type = "auth"
		"get_top":
			expected_type = "top_data"
		"get_profile":
			expected_type = "profile_data"
		"search_profiles":
			expected_type = "search_results"
		"save_profile":
			expected_type = "profile_saved"
		"sync_stats":
			expected_type = "stats_synced"
	
	var res_dict: Dictionary = {}
	var wait_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - wait_start < int(timeout_s * 1000.0):
		ws.poll()
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			break
		while ws.get_available_packet_count() > 0:
			var pkt: PackedByteArray = ws.get_packet()
			var d: Variant = JSON.parse_string(pkt.get_string_from_utf8())
			if d is Dictionary:
				var t: String = String((d as Dictionary).get("t", ""))
				if expected_type == "auth" and (t == "auth_ok" or t == "auth_fail"):
					res_dict = d
					break
				elif t == expected_type or t == "error":
					res_dict = d
					break
		if not res_dict.is_empty():
			break
		await tree.process_frame
	
	ws.close(1000)
	if res_dict.is_empty():
		return {"ok": false, "err": "Сервер не ответил вовремя"}
	return res_dict


static func register(nick: String, arg2: String, arg3: String = "") -> Dictionary:
	load_state()
	var email: String = ""
	var password: String = ""
	if arg3 == "":
		email = ""
		password = arg2
	else:
		email = arg2
		password = arg3
	nick = clean_nick(nick)
	var ne: String = nick_error(nick)
	if ne != "":
		return {"ok": false, "err": ne, "field": "nick"}
	var pe: String = password_error(password)
	if pe != "":
		return {"ok": false, "err": pe, "field": "password"}
	
	var r: Dictionary = await call_server({"t": "auth_register", "username": nick, "password": password})
	if String(r.get("t", "")) == "auth_ok":
		access = String(r.get("token", ""))
		token = access
		if r.get("user") is Dictionary:
			info.merge(r["user"], true)
		info["username"] = nick
		info["is_registered"] = true
		last_email = email
		NetConfig.set_nick(nick)
		GameConfig.my_name = nick
		_ensure_all_cosmetics()
		_save()
		_changed()
		sync_pending_stats()
		return {"ok": true, "err": "", "token": access}
	
	return {"ok": false, "err": String(r.get("why", r.get("err", "Ошибка регистрации"))), "field": "nick" if "ник" in String(r.get("why", "")).to_lower() else "password"}


static func login(nick_or_email: String, password: String) -> Dictionary:
	load_state()
	var nick: String = clean_nick(nick_or_email.split("@")[0] if "@" in nick_or_email else nick_or_email)
	var pe: String = password_error(password)
	if pe != "":
		return {"ok": false, "err": pe, "field": "password"}
	
	var r: Dictionary = await call_server({"t": "auth_login", "username": nick, "password": password})
	if String(r.get("t", "")) == "auth_ok":
		access = String(r.get("token", ""))
		token = access
		if r.get("user") is Dictionary:
			info.merge(r["user"], true)
		info["username"] = nick
		info["is_registered"] = true
		last_email = nick_or_email if "@" in nick_or_email else ""
		NetConfig.set_nick(nick)
		GameConfig.my_name = nick
		_ensure_all_cosmetics()
		_save()
		_changed()
		sync_pending_stats()
		return {"ok": true, "err": "", "token": access}
	
	return {"ok": false, "err": String(r.get("why", r.get("err", "Неверный логин или пароль"))), "field": "password"}


static func logout() -> void:
	load_state()
	access = ""
	token = ""
	info["is_registered"] = false
	_save()
	_changed()


static func get_top(by: String = "hours", limit: int = 100) -> Dictionary:
	load_state()
	var r: Dictionary = await call_server({"t": "get_top", "by": by, "limit": limit})
	if String(r.get("t", "")) == "top_data":
		var l: Array = r.get("list", [])
		return {"ok": true, "by": by, "list": l, "top": l, "total_count": int(r.get("total_count", 0))}
	return {"ok": false, "err": String(r.get("err", "Ошибка получения топа")), "list": [], "top": []}


static func get_profile(uname: String) -> Dictionary:
	load_state()
	var r: Dictionary = await call_server({"t": "get_profile", "username": uname})
	if String(r.get("t", "")) == "profile_data" and bool(r.get("ok", false)):
		return {"ok": true, "user": r.get("user", {})}
	return {"ok": false, "err": String(r.get("why", r.get("err", "Игрок не найден")))}


static func search_profiles(query: String) -> Dictionary:
	load_state()
	var r: Dictionary = await call_server({"t": "search_profiles", "query": query})
	if String(r.get("t", "")) == "search_results":
		var l: Array = r.get("list", [])
		return {"ok": true, "list": l, "users": l}
	return {"ok": false, "err": String(r.get("err", "Ошибка поиска")), "list": [], "users": []}


static func equip(kind: String, code: Variant) -> Dictionary:
	load_state()
	var cos: Dictionary = info.get("cosmetics", {}).duplicate()
	if code == null or str(code) == "":
		cos.erase(kind)
	else:
		var scode: String = str(code)
		if scode in ["fr_dev", "bn_dev", "tt_dev", "tt_dev_rgb"] and not is_dev():
			return {"ok": false, "err": "Только для разработчиков"}
		cos[kind] = scode
	
	info["cosmetics"] = cos
	_save()
	_changed()
	
	if access != "":
		call_server({
			"t": "save_profile",
			"token": access,
			"cosmetics": cos,
			"avatar": String(info.get("avatar", ""))
		})
	return {"ok": true, "err": "", "code": 200}


static func save_profile() -> Dictionary:
	load_state()
	_save()
	if access != "":
		return await call_server({
			"t": "save_profile",
			"token": access,
			"cosmetics": equipped(),
			"avatar": String(info.get("avatar", ""))
		})
	return {"ok": true, "err": ""}


static func save_avatar_file(path: String) -> Dictionary:
	load_state()
	if not FileAccess.file_exists(path):
		return {"ok": false, "err": "Файл не найден"}
	var img: = Image.new()
	var err: int = img.load(path)
	if err != OK:
		return {"ok": false, "err": "Не удалось загрузить изображение"}
	
	img.resize(96, 96, Image.INTERPOLATE_LANCZOS)
	var raw: PackedByteArray = img.save_png_to_buffer()
	var b64: String = Marshalls.raw_to_base64(raw)
	
	info["avatar"] = b64
	_avatar_cache[b64] = ImageTexture.create_from_image(img)
	_save()
	_changed()
	
	if access != "":
		call_server({
			"t": "save_profile",
			"token": access,
			"cosmetics": equipped(),
			"avatar": b64
		})
	return {"ok": true, "err": ""}


static func get_avatar_texture(b64: String) -> Texture2D:
	if b64 == "":
		return null
	if _avatar_cache.has(b64):
		return _avatar_cache[b64]
	var raw: PackedByteArray = Marshalls.base64_to_raw(b64)
	if raw.is_empty():
		return null
	var img: = Image.new()
	if img.load_png_from_buffer(raw) == OK:
		var tex: = ImageTexture.create_from_image(img)
		_avatar_cache[b64] = tex
		return tex
	return null


static func record_solo_win() -> void:
	load_state()
	info["solo_wins"] = int(info.get("solo_wins", 0)) + 1
	info["wins"] = int(info.get("wins", 0))
	pending_solo_wins += 1
	_save()
	_changed()
	sync_pending_stats()


static func record_playtime(seconds: int) -> void:
	load_state()
	if seconds <= 0:
		return
	info["playtime_s"] = int(info.get("playtime_s", 0)) + seconds
	pending_playtime_s += seconds
	_save()
	if pending_playtime_s >= 60:
		sync_pending_stats()


static func sync_pending_stats() -> void:
	load_state()
	if access == "" or _syncing or (pending_playtime_s <= 0 and pending_solo_wins <= 0):
		return
	_syncing = true
	var pt: int = pending_playtime_s
	var sw: int = pending_solo_wins
	var r: Dictionary = await call_server({
		"t": "sync_stats",
		"token": access,
		"playtime_add_s": pt,
		"solo_wins_add": sw
	})
	_syncing = false
	if String(r.get("t", "")) == "stats_synced" and bool(r.get("ok", false)):
		pending_playtime_s = maxi(0, pending_playtime_s - pt)
		pending_solo_wins = maxi(0, pending_solo_wins - sw)
		if r.get("user") is Dictionary:
			info.merge(r["user"], true)
		_save()
		_changed()


static func change_username(nick: String) -> Dictionary:
	load_state()
	nick = clean_nick(nick)
	var err: String = nick_error(nick)
	if err != "":
		return {"ok": false, "err": err}
	info["username"] = nick
	NetConfig.set_nick(nick)
	GameConfig.my_name = nick
	_save()
	_changed()
	return {"ok": true, "err": ""}


static func clean_nick(n: String) -> String:
	var out: String = ""
	for ch: String in n.strip_edges():
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127:
			out += ch
	return out.strip_edges().left(24)


static func nick_error(n: String) -> String:
	if n.length() < 2:
		return "НИК: МИНИМУМ 2 СИМВОЛА"
	if n.length() > 24:
		return "НИК: НЕ БОЛЬШЕ 24 СИМВОЛОВ"
	return ""


static func email_error(e: String) -> String:
	e = e.strip_edges()
	if e == "":
		return ""
	var re := RegEx.create_from_string("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")
	return "" if re.search(e) != null else "ПОЧТА: ПРОВЕРЬТЕ АДРЕС"


static func password_error(p: String) -> String:
	if p.length() < 4:
		return "ПАРОЛЬ: МИНИМУМ 4 СИМВОЛА"
	if p.length() > 128:
		return "ПАРОЛЬ: НЕ БОЛЬШЕ 128 СИМВОЛОВ"
	return ""


static func filter_nick(t: String) -> Array:
	var out: String = clean_nick(t)
	return [out, out != t]


static func nick_state(_nick: String) -> String:
	return "free"


static func format_hours(s: float) -> String:
	var h: float = s / 3600.0
	if h < 0.1:
		return "0.0"
	return "%.1f" % h


static func refresh() -> bool:
	return true


static func ensure_fresh() -> bool:
	return true


static func mark_banned() -> void:
	pass


static func lost_session() -> void:
	pass


static func set_suspension(_d: Dictionary) -> void:
	pass



