extends SceneTree

const ALPHABET: String = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const MAX_PEERS: int = 8

const TURN_TTL: int = 4 * 3600
const MAX_CONN_PER_IP: int = 12
const MAX_ROOMS_PER_IP: int = 3
const MAX_MSG_PER_S: int = 1500
const MAX_JOINS_PER_MIN: int = 60
const MAX_PKT_BYTES: int = 262144
const IDLE_NO_ROOM_S: float = 60.0
const IDLE_IN_ROOM_S: float = 70.0
const DIAG_INTERVAL_S: float = 30.0
const MAX_CLIENTS: int = 64
const MAX_ROOMS: int = 24
const LIST_MAX: int = 30
const NAME_MAX: int = 24

var _tcp: = TCPServer.new()
var _tls: TLSOptions = null
var _pending: Array = []
var _clients: Dictionary = {}
var _rooms: Dictionary = {}
var _next_key: int = 1
var _stun: PackedStringArray = []
var _turn: PackedStringArray = []
var _secret: String = ""
var _cf_key: String = ""
var _cf_token: String = ""
var _cf_api: String = "https://rtc.live.cloudflare.com"
const CF_STUN: Dictionary = {"urls": ["stun:stun.cloudflare.com:3478"]}
var _proxied: bool = false
var _diag_elapsed: float = 0.0

# User database and persistent stats
var _users: Dictionary = {}
var _db_file: String = ""
var _db_dirty: bool = false
var _db_save_timer: float = 0.0

const DEV_NICKS: Array = ["reborn_team", "CryptoAngelazaz", "mxka"]

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


func _initialize() -> void :
	Engine.max_fps = 30
	var port: int = 9080
	var bind: String = "*"
	var cert: String = ""
	var key: String = ""
	for a: String in OS.get_cmdline_user_args():
		var v: String = a.get_slice("=", 1)
		if a.begins_with("--port="):
			port = int(v)
		elif a.begins_with("--bind="):
			bind = v
		elif a.begins_with("--stun="):
			_stun = v.split(",", false)
		elif a.begins_with("--turn="):
			_turn = v.split(",", false)
		elif a.begins_with("--cert="):
			cert = v
		elif a.begins_with("--key="):
			key = v
		elif a.begins_with("--cf-api="):
			_cf_api = v
		elif a.begins_with("--db="):
			_db_file = v
		elif a == "--behind-proxy":
			_proxied = true
	_secret = OS.get_environment("DF_TURN_SECRET")
	_cf_key = OS.get_environment("DF_CF_TURN_KEY_ID")
	_cf_token = OS.get_environment("DF_CF_TURN_TOKEN")
	if cert != "" and key != "":
		var c: = X509Certificate.new()
		var k: = CryptoKey.new()
		if c.load(cert) != OK or k.load(key) != OK:
			printerr("[Signal] cannot load TLS cert / key")
			quit(1)
			return
		_tls = TLSOptions.server(k, c)
	var err: int = _tcp.listen(port, bind)
	if err != OK:
		printerr("[Signal] cannot listen on %d: %s" % [port, error_string(err)])
		quit(1)
		return
	
	_init_users_db()
	
	var turn_mode: String = "Cloudflare Realtime TURN" if _cf_key != "" and _cf_token != "" else ("own coturn" if not _turn.is_empty() and _secret != "" else "OFF (no --turn + DF_TURN_SECRET, no DF_CF_TURN_KEY_ID + DF_CF_TURN_TOKEN)")
	print("[Signal] listening on %d (%s), TURN: %s%s" % [port, "wss" if _tls != null else "ws", turn_mode, ", behind a proxy (client IP from ?rip=)" if _proxied else ""])
	_event("server_started", {"port": port, "transport": "wss" if _tls != null else "ws", "turn": turn_mode,
		"behind_proxy": _proxied, "godot": String(Engine.get_version_info().get("string", "unknown")),
		"max_players": MAX_PEERS, "max_clients": MAX_CLIENTS, "max_rooms": MAX_ROOMS, "users_count": _users.size()})


func _init_users_db() -> void:
	if _db_file == "":
		if FileAccess.file_exists("/var/lib/df-relay-test/users_db.json"):
			_db_file = "/var/lib/df-relay-test/users_db.json"
		elif DirAccess.dir_exists_absolute("/var/lib/df-relay-test"):
			_db_file = "/var/lib/df-relay-test/users_db.json"
		else:
			_db_file = "user://users_db.json"
	
	if FileAccess.file_exists(_db_file):
		var f: = FileAccess.open(_db_file, FileAccess.READ)
		if f != null:
			var txt: String = f.get_as_text()
			f.close()
			var d: Variant = JSON.parse_string(txt)
			if d is Dictionary:
				_users = d
				print("[Signal] Loaded %d users from database: %s" % [_users.size(), _db_file])
	
	if _users.is_empty():
		for p: String in [
			"/opt/df-relay-test/seed_users.json",
			"res://net/server/seed_users.json",
			"res://seed_users.json",
			"net/server/seed_users.json",
			"seed_users.json"
		]:
			if FileAccess.file_exists(p):
				var f2: = FileAccess.open(p, FileAccess.READ)
				if f2 != null:
					var txt2: String = f2.get_as_text()
					f2.close()
					var d2: Variant = JSON.parse_string(txt2)
					if d2 is Dictionary:
						_users = d2
						print("[Signal] Seeded %d users from: %s" % [_users.size(), p])
						_save_users(true)
						break
	
	for dn: String in DEV_NICKS:
		if dn.to_lower() == "reborn_team":
			continue
		var u: Dictionary = _find_user(dn)
		if u.is_empty():
			_users[dn] = {
				"username": dn,
				"password_hash": "",
				"salt": "",
				"is_registered": false,
				"is_dev": true,
				"token": "",
				"created_at": int(Time.get_unix_time_from_system()),
				"last_seen": int(Time.get_unix_time_from_system()),
				"playtime_s": 54000,
				"matches_played": 35,
				"wins": 25,
				"losses": 10,
				"solo_wins": 15,
				"avatar": "",
				"cosmetics": {"frame": "fr_dev", "banner": "bn_dev", "title": "tt_dev_rgb"}
			}
			_db_dirty = true
		else:
			u["is_dev"] = true
	
	if _db_dirty:
		_save_users(true)


func _save_users(immediate: bool = false) -> void:
	if immediate:
		_db_dirty = false
		_db_save_timer = 0.0
		if _db_file == "":
			return
		var tmp: String = _db_file + ".tmp"
		var f: = FileAccess.open(tmp, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(_users, "\t"))
			f.close()
			var pdir: String = _db_file.get_base_dir()
			var da: DirAccess = DirAccess.open(pdir if pdir != "" else ".")
			if da != null:
				if da.file_exists(_db_file.get_file()):
					da.remove(_db_file.get_file())
				da.rename(tmp.get_file(), _db_file.get_file())
		else:
			var f2: = FileAccess.open(_db_file, FileAccess.WRITE)
			if f2 != null:
				f2.store_string(JSON.stringify(_users, "\t"))
				f2.close()
	else:
		_db_dirty = true


func _find_user(uname: String) -> Dictionary:
	var target: String = uname.strip_edges().to_lower()
	for k: String in _users:
		if k.to_lower() == target:
			return _users[k]
	return {}


func _find_user_by_token(tok: String) -> Dictionary:
	if tok == "":
		return {}
	for k: String in _users:
		if String(_users[k].get("token", "")) == tok and bool(_users[k].get("is_registered", false)):
			return _users[k]
	return {}


func _is_dev(uname: String) -> bool:
	var l: String = uname.strip_edges().to_lower()
	for d: String in DEV_NICKS:
		if d.to_lower() == l:
			return true
	return false


func _public_user(u: Dictionary) -> Dictionary:
	return {
		"username": String(u.get("username", "")),
		"is_registered": bool(u.get("is_registered", false)),
		"is_dev": bool(u.get("is_dev", false)),
		"created_at": int(u.get("created_at", 0)),
		"last_seen": int(u.get("last_seen", 0)),
		"playtime_s": int(u.get("playtime_s", 0)),
		"hours": snappedf(float(u.get("playtime_s", 0)) / 3600.0, 0.1),
		"matches_played": int(u.get("matches_played", 0)),
		"wins": int(u.get("wins", 0)),
		"losses": int(u.get("losses", 0)),
		"solo_wins": int(u.get("solo_wins", 0)),
		"total_wins": int(u.get("wins", 0)) + int(u.get("solo_wins", 0)),
		"avatar": String(u.get("avatar", "")),
		"cosmetics": u.get("cosmetics", {})
	}


func _process(delta: float) -> bool:
	while _tcp.is_connection_available():
		var tcp: StreamPeerTCP = _tcp.take_connection()
		var ip: String = tcp.get_connected_host()
		var reject_reason: String = ""
		if _clients.size() + _pending.size() >= MAX_CLIENTS:
			reject_reason = "server_capacity"
		elif not _proxied and _count_ip(ip) >= MAX_CONN_PER_IP:
			reject_reason = "ip_connection_limit"
		if reject_reason != "":
			_event("connection_rejected", {"ip": ip, "reason": reject_reason})
			tcp.disconnect_from_host()
			continue
		var s: StreamPeer = tcp
		if _tls != null:
			var t: = StreamPeerTLS.new()
			t.accept_stream(s, _tls)
			s = t
		_pending.append([s, null, Time.get_ticks_msec(), ip])
	for i in range(_pending.size() - 1, -1, -1):
		var p: Array = _pending[i]
		if p[1] == null:
			if p[0] is StreamPeerTLS:
				(p[0] as StreamPeerTLS).poll()
				if (p[0] as StreamPeerTLS).get_status() == StreamPeerTLS.STATUS_HANDSHAKING:
					continue
				if (p[0] as StreamPeerTLS).get_status() != StreamPeerTLS.STATUS_CONNECTED:
					_event("tls_handshake_failed", {"ip": String(p[3]), "elapsed_ms": Time.get_ticks_msec() - int(p[2])})
					_pending.remove_at(i)
					continue
			var ws: = WebSocketPeer.new()
			ws.inbound_buffer_size = 1048576
			ws.outbound_buffer_size = 1048576
			ws.max_queued_packets = 2048
			ws.accept_stream(p[0])
			p[1] = ws
		var w: WebSocketPeer = p[1]
		w.poll()
		var st: int = w.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			var cip: String = String(p[3])
			if _proxied:
				cip = _url_ip(w.get_requested_url(), cip)
				if _count_ip(cip) >= MAX_CONN_PER_IP:
					_event("connection_rejected", {"ip": cip, "reason": "ip_connection_limit"})
					w.close(1008, "too many connections")
					_pending.remove_at(i)
					continue
			var connected_ms: int = Time.get_ticks_msec()
			_clients[_next_key] = {"ws": w, "room": "", "id": 0, "ip": cip, "t0": connected_ms, "last": connected_ms,
				"connected_at": int(Time.get_unix_time_from_system()), "joined_at": 0, "name": "", "version": "",
				"msg_s": 0, "msg_n": 0, "join_m": 0, "join_n": 0, "auth": false, "auth_user": ""}
			_event("client_connected", {"client": _next_key, "ip": cip, "via_proxy": _proxied})
			_next_key += 1
			_pending.remove_at(i)
		elif st == WebSocketPeer.STATE_CLOSED or Time.get_ticks_msec() - int(p[2]) > 8000:
			if st == WebSocketPeer.STATE_CLOSED:
				_event("websocket_handshake_failed", {"ip": String(p[3]), "close_code": w.get_close_code(), "reason": w.get_close_reason()})
			else:
				_event("websocket_handshake_timeout", {"ip": String(p[3]), "elapsed_ms": Time.get_ticks_msec() - int(p[2])})
			_pending.remove_at(i)
	for ck: int in _clients.keys():
		var cl: Dictionary = _clients[ck]
		var ws2: WebSocketPeer = cl["ws"]
		ws2.poll()
		if ws2.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_drop(ck, "websocket_closed:%d:%s" % [ws2.get_close_code(), ws2.get_close_reason()])
			continue
		var now_ms: int = Time.get_ticks_msec()
		if String(cl["room"]) == "" and now_ms - int(cl["t0"]) > int(IDLE_NO_ROOM_S * 1000.0):
			ws2.close(1000, "idle")
			_drop(ck, "idle_without_room")
			continue
		if String(cl["room"]) != "" and now_ms - int(cl["last"]) > int(IDLE_IN_ROOM_S * 1000.0):
			ws2.close(1000, "dead")
			_drop(ck, "idle_in_room")
			continue
		var bad: bool = false
		while ws2.get_available_packet_count() > 0:
			var pkt: PackedByteArray = ws2.get_packet()
			cl["last"] = now_ms
			var sec: int = now_ms / 1000
			if int(cl["msg_s"]) != sec:
				cl["msg_s"] = sec
				cl["msg_n"] = 0
			cl["msg_n"] = int(cl["msg_n"]) + 1
			if int(cl["msg_n"]) > MAX_MSG_PER_S or pkt.size() > MAX_PKT_BYTES:
				_event("protocol_error", {"client": ck, "ip": String(cl.get("ip", "")), "room": String(cl.get("room", "")),
					"name": String(cl.get("name", "")), "version": String(cl.get("version", "")),
					"reason": "message_rate_limit" if int(cl["msg_n"]) > MAX_MSG_PER_S else "packet_too_large", "packet_bytes": pkt.size()})
				bad = true
				break
			var d: Variant = JSON.parse_string(pkt.get_string_from_utf8())
			if d is Dictionary:
				_on_msg(ck, d)
			else:
				_event("protocol_error", {"client": ck, "ip": String(cl.get("ip", "")), "room": String(cl.get("room", "")),
					"reason": "invalid_json", "packet_bytes": pkt.size()})
			if not _clients.has(ck):
				break
		if bad and _clients.has(ck):
			ws2.close(1008, "rate")
			_drop(ck, "rate_or_packet_size_limit")
	
	if _db_dirty:
		_db_save_timer += delta
		if _db_save_timer >= 2.0:
			_save_users(true)

	_diag_elapsed += delta
	if _diag_elapsed >= DIAG_INTERVAL_S:
		_diag_elapsed = 0.0
		_status_snapshot()
	return false


func _event(kind: String, data: Dictionary = {}) -> void:
	var event: Dictionary = {"ts": int(Time.get_unix_time_from_system()), "event": kind}
	event.merge(data, true)
	print("[RelayEvent] " + JSON.stringify(event))


func _player_rows(room: Dictionary) -> Array:
	var out: Array = []
	for peer_id: int in (room.get("peers", {}) as Dictionary):
		var client_id: int = int((room["peers"] as Dictionary)[peer_id])
		if not _clients.has(client_id):
			continue
		var client: Dictionary = _clients[client_id]
		var uname: String = String(client.get("auth_user", client.get("name", "")))
		var u: Dictionary = _find_user(uname)
		var is_dev: bool = bool(u.get("is_dev", false)) if not u.is_empty() else _is_dev(uname)
		var cos: Dictionary = u.get("cosmetics", {}) if not u.is_empty() else {}
		var av: String = String(u.get("avatar", "")) if not u.is_empty() else ""
		out.append({
			"slot": peer_id,
			"name": uname,
			"ip": String(client.get("ip", "")),
			"version": String(client.get("version", "")),
			"joined_at": int(client.get("joined_at", 0)),
			"connection_started_at": int(client.get("connected_at", 0)),
			"is_dev": is_dev,
			"is_registered": bool(u.get("is_registered", false)) if not u.is_empty() else false,
			"cosmetics": cos,
			"avatar": av
		})
	return out


func _elapsed_seconds(started_at: int) -> int:
	return maxi(0, int(Time.get_unix_time_from_system()) - started_at) if started_at > 0 else 0


func _room_duration(room: Dictionary) -> int:
	var started_at: int = int(room.get("started_at", 0))
	if started_at <= 0:
		return 0
	var ended_at: int = int(room.get("ended_at", 0))
	return maxi(0, (ended_at if ended_at > 0 else int(Time.get_unix_time_from_system())) - started_at)


func _status_snapshot() -> void:
	var rooms: Array = []
	for code: String in _rooms:
		var room: Dictionary = _rooms[code]
		var started_at: int = int(room.get("started_at", 0))
		rooms.append({"code": code, "name": String(room.get("name", "")), "public": bool(room.get("pub", false)),
			"state": "ended" if int(room.get("ended_at", 0)) > 0 else ("running" if bool(room.get("sealed", false)) else "lobby"),
			"version": String(room.get("v", "")), "match": String(room.get("match", "")),
			"created_at": int(room.get("created_at", 0)), "started_at": started_at,
			"duration_s": _room_duration(room) if started_at > 0 else _elapsed_seconds(int(room.get("created_at", 0))),
			"end_reason": String(room.get("end_reason", "")), "players": _player_rows(room)})
	var idle_clients: Array = []
	for client_id: int in _clients:
		var client: Dictionary = _clients[client_id]
		if String(client.get("room", "")) == "":
			idle_clients.append({"name": String(client.get("name", "")), "ip": String(client.get("ip", "")),
				"version": String(client.get("version", "")), "connected_at": int(client.get("connected_at", 0)),
				"connected_s": _elapsed_seconds(int(client.get("connected_at", 0)))})
	_event("status_snapshot", {"connections": _clients.size(), "rooms": rooms, "unassigned": idle_clients, "users_count": _users.size()})


func _url_ip(url: String, fallback: String) -> String:
	var q: int = url.find("rip=")
	if q < 0:
		return fallback
	var v: String = url.substr(q + 4).get_slice("&", 0).uri_decode()
	return v if v.is_valid_ip_address() else fallback


func _count_ip(ip: String) -> int:
	var n: int = 0
	for k: int in _clients:
		if String(_clients[k]["ip"]) == ip:
			n += 1
	for p: Array in _pending:
		if String(p[3]) == ip:
			n += 1
	return n


func _send(ck: int, d: Dictionary) -> void :
	if _clients.has(ck):
		(_clients[ck]["ws"] as WebSocketPeer).send_text(JSON.stringify(d))


func _check_auth(ck: int, d: Dictionary) -> bool:
	var cl: Dictionary = _clients[ck]
	if bool(cl.get("auth", false)):
		return true
	var tok: String = String(d.get("auth_token", ""))
	var uname: String = String(d.get("auth_user", cl.get("name", "")))
	if tok != "" and uname != "":
		var u: Dictionary = _find_user(uname)
		if not u.is_empty() and String(u.get("token", "")) == tok and bool(u.get("is_registered", false)):
			cl["auth"] = true
			cl["auth_user"] = String(u["username"])
			cl["name"] = String(u["username"])
			return true
	return false


func _on_msg(ck: int, d: Dictionary) -> void :
	var cl: Dictionary = _clients[ck]
	if d.get("v") is String:
		cl["version"] = String(d["v"])
	if d.get("name") is String and String(d["name"]).strip_edges() != "":
		cl["name"] = _clean_name(String(d["name"]))
	
	match String(d.get("t", "")):
		"auth_register":
			_handle_auth_register(ck, d)
		"auth_login":
			_handle_auth_login(ck, d)
		"auth_token":
			_handle_auth_token(ck, d)
		"get_top":
			_handle_get_top(ck, d)
		"get_profile":
			_handle_get_profile(ck, d)
		"search_profiles":
			_handle_search_profiles(ck, d)
		"save_profile":
			_handle_save_profile(ck, d)
		"sync_stats":
			_handle_sync_stats(ck, d)

		"host":
			if String(cl["room"]) != "":
				return
			if not _check_auth(ck, d):
				_send(ck, {"t": "error", "why": "Требуется авторизация в сети DroneFlames Multiplayer"})
				return
			var mine: int = 0
			for k: int in _clients:
				var o: Dictionary = _clients[k]
				if String(o["ip"]) == String(cl["ip"]) and int(o["id"]) == 1:
					mine += 1
			if mine >= MAX_ROOMS_PER_IP or _rooms.size() >= MAX_ROOMS:
				_event("room_create_rejected", {"ip": String(cl.get("ip", "")), "name": _clean_name(String(d.get("name", ""))),
					"version": String(d.get("v", "")), "reason": "room_limit"})
				_send(ck, {"t": "error", "why": "Слишком много комнат с одного адреса"})
				return
			var want: String = String(d.get("code", "")).to_upper()
			var code: String = want if _code_ok(want) and not _rooms.has(want) else _new_code()
			var host_name: String = String(cl.get("auth_user", _clean_name(String(d.get("name", "")))))
			var host_version: String = String(d.get("v", ""))
			var created_at: int = int(Time.get_unix_time_from_system())
			_rooms[code] = {"v": host_version, "peers": {1: ck}, "sealed": false,
				"pub": bool(d.get("pub", false)), "name": host_name, "t": Time.get_ticks_msec(),
				"created_at": created_at, "started_at": 0, "ended_at": 0, "end_reason": ""}
			cl["room"] = code
			cl["id"] = 1
			cl["name"] = host_name
			cl["version"] = host_version
			cl["joined_at"] = created_at
			_with_ice(ck, 1, func(ice: Array) -> void : _send(ck, {"t": "room", "code": code, "ice": ice}))
			_event("room_created", {"room": code, "name": host_name, "ip": String(cl.get("ip", "")),
				"version": host_version, "public": bool(d.get("pub", false)), "max_players": MAX_PEERS})
		"reattach":
			if not _check_auth(ck, d):
				_send(ck, {"t": "error", "why": "Требуется авторизация в сети DroneFlames Multiplayer"})
				return
			var re_code: String = String(d.get("code", "")).to_upper()
			var re_room: Dictionary = _rooms.get(re_code, {})
			var re_id: int = int(d.get("id", 0))
			if re_room.is_empty() or not (re_room["peers"] as Dictionary).has(1):
				_send(ck, {"t": "error", "why": "Комната %s не найдена" % re_code})
				return
			if re_id < 2 or re_id > MAX_PEERS:
				_send(ck, {"t": "error", "why": "Неверное место игрока"})
				return
			if not (re_room.get("toks", []) as Array).has(String(d.get("tok_h", ""))):
				_event("reattach_rejected", {"room": re_code, "ip": String(cl.get("ip", "")), "slot": re_id, "reason": "invalid_token"})
				_send(ck, {"t": "error", "why": "Нет доступа к месту игрока"})
				return
			var re_peers: Dictionary = re_room["peers"]
			var old_ck: int = int(re_peers.get(re_id, 0))
			if old_ck > 0 and old_ck != ck and _clients.has(old_ck):
				_drop(old_ck, "replaced_by_reattach")
			re_peers[re_id] = ck
			cl["room"] = re_code
			cl["id"] = re_id
			cl["name"] = String(cl.get("auth_user", _clean_name(String(d.get("name", "")))))
			cl["version"] = String(d.get("v", ""))
			cl["joined_at"] = int(Time.get_unix_time_from_system())
			_with_ice(ck, re_id, func(ice: Array) -> void :
				_send(ck, {"t": "reattached", "id": re_id, "match": String(re_room.get("match", "")), "ice": ice}))
			_send(int(re_peers[1]), {"t": "peer", "id": re_id})
			_event("player_reattached", {"room": re_code, "match": String(re_room.get("match", "")), "slot": re_id,
				"name": String(cl.get("name", "")), "ip": String(cl.get("ip", "")), "version": String(cl.get("version", "")),
				"players": _player_rows(re_room)})
		"join":
			var minute: int = Time.get_ticks_msec() / 60000
			if int(cl["join_m"]) != minute:
				cl["join_m"] = minute
				cl["join_n"] = 0
			cl["join_n"] = int(cl["join_n"]) + 1
			if int(cl["join_n"]) > MAX_JOINS_PER_MIN:
				_event("connection_rejected", {"ip": String(cl.get("ip", "")), "name": String(d.get("name", "")),
					"version": String(d.get("v", "")), "reason": "join_rate_limit"})
				_send(ck, {"t": "error", "why": "Слишком много попыток входа, подождите минуту"})
				return
			if not _check_auth(ck, d):
				_send(ck, {"t": "error", "why": "Требуется авторизация в сети DroneFlames Multiplayer"})
				return
			var code2: String = String(d.get("code", "")).to_upper()
			var r: Dictionary = _rooms.get(code2, {})
			var why: String = ""
			var sealed_join: bool = not r.is_empty() and bool(r.get("sealed", false))
			var token_ok: bool = sealed_join and (r.get("toks", []) as Array).has(String(d.get("tok_h", "")))
			if r.is_empty():
				why = "Комната %s не найдена" % code2
			elif String(r["v"]) != String(d.get("v", "")):
				why = "Другая версия игры у хоста: обновите игру"
			elif int(r.get("ended_at", 0)) > 0:
				why = "Партия уже завершена"
			elif sealed_join and not bool(d.get("late", false)) and not (bool(d.get("rejoin", false)) and token_ok):
				why = "Партия уже идёт"
			elif (r["peers"] as Dictionary).size() >= MAX_PEERS:
				why = "Комната заполнена"
			if why != "":
				var reason: String = "room_not_found" if r.is_empty() else ("version_mismatch" if String(r["v"]) != String(d.get("v", "")) else ("match_ended" if int(r.get("ended_at", 0)) > 0 else ("match_started" if sealed_join and not token_ok and not bool(d.get("late", false)) else "room_full")))
				_event("join_rejected", {"room": code2, "name": _clean_name(String(d.get("name", ""))),
					"ip": String(cl.get("ip", "")), "client_version": String(d.get("v", "")),
					"room_version": String(r.get("v", "")), "reason": reason})
				_send(ck, {"t": "error", "why": why})
				return
			var peer_list: Dictionary = r["peers"]
			var id: int = 2
			while peer_list.has(id) and id <= MAX_PEERS:
				id += 1
			if id > MAX_PEERS:
				_send(ck, {"t": "error", "why": "Комната заполнена"})
				return
			peer_list[id] = ck
			cl["room"] = code2
			cl["id"] = id
			cl["name"] = String(cl.get("auth_user", _clean_name(String(d.get("name", "")))))
			cl["version"] = String(d.get("v", ""))
			cl["joined_at"] = int(Time.get_unix_time_from_system())
			_with_ice(ck, id, func(ice: Array) -> void :
				var joined: Dictionary = {"t": "joined", "id": id, "code": code2, "ice": ice, "sealed": sealed_join}
				if sealed_join:
					joined["match"] = String(r.get("match", ""))
				_send(ck, joined))
			_send(int(r["peers"][1]), {"t": "peer", "id": id})
			_event("player_joined", {"room": code2, "match": String(r.get("match", "")), "slot": id,
				"name": String(cl["name"]), "ip": String(cl["ip"]), "version": String(cl["version"]),
				"state": "running" if sealed_join else "lobby", "players": _player_rows(r)})
		"seal":
			var r2: Dictionary = _rooms.get(String(cl["room"]), {})
			if not r2.is_empty() and int(cl["id"]) == 1:
				var first_start: bool = int(r2.get("started_at", 0)) == 0
				r2["sealed"] = true
				if first_start:
					r2["started_at"] = int(Time.get_unix_time_from_system())
					r2["started_msec"] = Time.get_ticks_msec()
				var th: Array = []
				for h: Variant in (d.get("toks", []) as Array):
					if h is String and String(h).length() == 64:
						th.append(String(h))
				r2["toks"] = th.slice(0, MAX_PEERS)
				if not r2.has("match"):
					r2["match"] = Crypto.new().generate_random_bytes(12).hex_encode()
				if first_start:
					_event("match_started", {"room": String(cl.get("room", "")), "match": String(r2["match"]),
						"name": String(r2.get("name", "")), "version": String(r2.get("v", "")),
						"started_at": int(r2.get("started_at", 0)), "players": _player_rows(r2)})
					for pid: int in (r2["peers"] as Dictionary):
						var pck: int = int((r2["peers"] as Dictionary)[pid])
						if _clients.has(pck):
							var pu: String = String(_clients[pck].get("auth_user", ""))
							if pu != "":
								var usr: Dictionary = _find_user(pu)
								if not usr.is_empty():
									usr["matches_played"] = int(usr.get("matches_played", 0)) + 1
									_db_dirty = true
				var started: Dictionary = {"t": "turn", "match": String(r2["match"]), "ice": []}
				for peer_id: int in (r2["peers"] as Dictionary):
					_send(int((r2["peers"] as Dictionary)[peer_id]), started)
		"match_end":
			var end_room: Dictionary = _rooms.get(String(cl.get("room", "")), {})
			if not end_room.is_empty() and int(cl.get("id", 0)) == 1 and bool(end_room.get("sealed", false)) \
					and String(d.get("match", "")) == String(end_room.get("match", "")):
				if int(end_room.get("ended_at", 0)) == 0:
					end_room["ended_at"] = int(Time.get_unix_time_from_system())
					end_room["end_reason"] = String(d.get("reason", "host_closed")).left(40)
					var mdur: int = _room_duration(end_room)
					for pid2: int in (end_room.get("peers", {}) as Dictionary):
						var pck2: int = int((end_room["peers"] as Dictionary)[pid2])
						if _clients.has(pck2):
							var pu2: String = String(_clients[pck2].get("auth_user", ""))
							if pu2 != "":
								var usr2: Dictionary = _find_user(pu2)
								if not usr2.is_empty():
									usr2["playtime_s"] = int(usr2.get("playtime_s", 0)) + mdur
									_db_dirty = true
					_event("match_ended", {"room": String(cl.get("room", "")), "match": String(end_room.get("match", "")),
						"name": String(end_room.get("name", "")), "version": String(end_room.get("v", "")),
						"reason": String(end_room["end_reason"]), "duration_s": mdur,
						"played_s": float(d.get("played_s", 0.0)), "players": _player_rows(end_room)})
		"reserve":
			var reserve_room: Dictionary = _rooms.get(String(cl["room"]), {})
			var token_hash: String = String(d.get("tok_h", ""))
			if not reserve_room.is_empty() and int(cl["id"]) == 1 and bool(reserve_room.get("sealed", false)) \
					and token_hash.length() == 64:
				var saved_tokens: Array = reserve_room.get("toks", [])
				if not saved_tokens.has(token_hash):
					saved_tokens.append(token_hash)
					if saved_tokens.size() > MAX_PEERS:
						saved_tokens.pop_front()
					reserve_room["toks"] = saved_tokens
		"rpc":
			var r5: Dictionary = _rooms.get(String(cl["room"]), {})
			var data: Variant = d.get("d", {})
			if r5.is_empty() or not (data is Dictionary):
				return
			var peer_list: Dictionary = r5["peers"]
			var from_id: int = int(cl["id"])
			var to_id: int = int(d.get("to", 0))
			var packet: Dictionary = {"t": "rpc", "from": from_id, "d": data}
			if to_id == 0:
				for peer_id2: int in peer_list:
					if peer_id2 != from_id:
						_send(int(peer_list[peer_id2]), packet)
			elif peer_list.has(to_id) and to_id != from_id:
				_send(int(peer_list[to_id]), packet)
		"set_pub":
			var r4: Dictionary = _rooms.get(String(cl["room"]), {})
			if not r4.is_empty() and int(cl["id"]) == 1:
				r4["pub"] = bool(d.get("pub", false))
		"list":
			cl["t0"] = Time.get_ticks_msec()
			_send(ck, {"t": "rooms", "rooms": _public_rooms()})
		"peek":
			cl["t0"] = Time.get_ticks_msec()
			var pc: String = String(d.get("code", "")).to_upper()
			var pr: Dictionary = _rooms.get(pc, {}) if _code_ok(pc) else {}
			_send(ck, {"t": "peek", "code": pc, "open": not pr.is_empty() and bool(pr.get("sealed", false)) and int(pr.get("ended_at", 0)) == 0})
		"offer", "answer", "cand":
			var r3: Dictionary = _rooms.get(String(cl["room"]), {})
			var to: int = int(d.get("to", 0))
			if r3.is_empty() or not (r3["peers"] as Dictionary).has(to):
				_event("signaling_rejected", {"room": String(cl.get("room", "")), "from_slot": int(cl.get("id", 0)),
					"to_slot": to, "signal": String(d.get("t", "")), "reason": "target_peer_missing"})
				return
			d["from"] = int(cl["id"])
			d.erase("to")
			_send(int(r3["peers"][to]), d)
		"ping":
			_send(ck, {"t": "pong"})
		"done":
			_drop(ck, "done")
		_:
			_event("protocol_error", {"client": ck, "ip": String(cl.get("ip", "")),
				"room": String(cl.get("room", "")), "type": String(d.get("t", "")), "reason": "unknown_message_type"})


func _handle_auth_register(ck: int, d: Dictionary) -> void:
	var raw_name: String = String(d.get("username", ""))
	var uname: String = _clean_name(raw_name)
	var pw: String = String(d.get("password", ""))
	if uname.length() < 2 or uname.length() > NAME_MAX:
		_send(ck, {"t": "auth_fail", "why": "Длина ника от 2 до %d символов" % NAME_MAX})
		return
	if pw.length() < 4:
		_send(ck, {"t": "auth_fail", "why": "Пароль минимум 4 символа"})
		return
	
	var existing: Dictionary = _find_user(uname)
	if not existing.is_empty() and bool(existing.get("is_registered", false)):
		_send(ck, {"t": "auth_fail", "why": "Этот ник уже зарегистрирован. Войдите по паролю."})
		return
	
	var salt: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var hash: String = (salt + ":" + pw).sha256_text()
	var tok: String = Crypto.new().generate_random_bytes(24).hex_encode()
	var now: int = int(Time.get_unix_time_from_system())
	
	var u: Dictionary
	if not existing.is_empty():
		u = existing
		u["password_hash"] = hash
		u["salt"] = salt
		u["is_registered"] = true
		u["is_dev"] = _is_dev(uname)
		u["token"] = tok
		u["last_seen"] = now
	else:
		var is_dev: bool = _is_dev(uname)
		var fr: String = "fr_dev" if is_dev else COMMON_FRAMES[randi() % COMMON_FRAMES.size()]
		var bn: String = "bn_dev" if is_dev else COMMON_BANNERS[randi() % COMMON_BANNERS.size()]
		var tt: String = "tt_dev_rgb" if is_dev else (COMMON_TITLES[randi() % COMMON_TITLES.size()] if randf() > 0.3 else "")
		u = {
			"username": uname,
			"password_hash": hash,
			"salt": salt,
			"is_registered": true,
			"is_dev": is_dev,
			"token": tok,
			"created_at": now,
			"last_seen": now,
			"playtime_s": 0,
			"matches_played": 0,
			"wins": 0,
			"losses": 0,
			"solo_wins": 0,
			"avatar": "",
			"cosmetics": {"frame": fr, "banner": bn, "title": tt}
		}
		_users[uname] = u
	
	_save_users(true)
	if _clients.has(ck):
		var cl: Dictionary = _clients[ck]
		cl["auth"] = true
		cl["auth_user"] = u["username"]
		cl["name"] = u["username"]
	_send(ck, {"t": "auth_ok", "token": tok, "user": _public_user(u)})
	_event("user_registered", {"username": u["username"], "is_dev": u["is_dev"]})


func _handle_auth_login(ck: int, d: Dictionary) -> void:
	var uname: String = String(d.get("username", "")).strip_edges()
	var pw: String = String(d.get("password", ""))
	var u: Dictionary = _find_user(uname)
	if u.is_empty():
		_send(ck, {"t": "auth_fail", "why": "Аккаунт не найден. Зарегистрируйтесь."})
		return
	if not bool(u.get("is_registered", false)):
		_send(ck, {"t": "auth_fail", "why": "Аккаунт еще не зарегистрирован в сети. Создайте пароль."})
		return
	var salt: String = String(u.get("salt", ""))
	var expected_hash: String = String(u.get("password_hash", ""))
	var given_hash: String = (salt + ":" + pw).sha256_text()
	if given_hash != expected_hash:
		_send(ck, {"t": "auth_fail", "why": "Неверный пароль"})
		return
	var tok: String = Crypto.new().generate_random_bytes(24).hex_encode()
	u["token"] = tok
	u["last_seen"] = int(Time.get_unix_time_from_system())
	_save_users(true)
	if _clients.has(ck):
		var cl: Dictionary = _clients[ck]
		cl["auth"] = true
		cl["auth_user"] = u["username"]
		cl["name"] = u["username"]
	_send(ck, {"t": "auth_ok", "token": tok, "user": _public_user(u)})
	_event("user_logged_in", {"username": u["username"]})


func _handle_auth_token(ck: int, d: Dictionary) -> void:
	var uname: String = String(d.get("username", "")).strip_edges()
	var tok: String = String(d.get("token", ""))
	var u: Dictionary = _find_user(uname)
	if not u.is_empty() and tok != "" and String(u.get("token", "")) == tok and bool(u.get("is_registered", false)):
		u["last_seen"] = int(Time.get_unix_time_from_system())
		if _clients.has(ck):
			var cl: Dictionary = _clients[ck]
			cl["auth"] = true
			cl["auth_user"] = u["username"]
			cl["name"] = u["username"]
		_send(ck, {"t": "auth_ok", "token": tok, "user": _public_user(u)})
	else:
		_send(ck, {"t": "auth_fail", "why": "Сессия устарела. Войдите снова."})


func _handle_get_top(ck: int, d: Dictionary) -> void:
	var by: String = String(d.get("by", "hours"))
	var limit: int = clampi(int(d.get("limit", 100)), 1, 1000)
	var list: Array = []
	for k: String in _users:
		var u: Dictionary = _users[k]
		list.append(_public_user(u))
	
	if by == "wins":
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var wa: int = int(a.get("total_wins", 0))
			var wb: int = int(b.get("total_wins", 0))
			return wa > wb if wa != wb else int(a.get("playtime_s", 0)) > int(b.get("playtime_s", 0))
		)
	elif by == "matches":
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ma: int = int(a.get("matches_played", 0))
			var mb: int = int(b.get("matches_played", 0))
			return ma > mb if ma != mb else int(a.get("playtime_s", 0)) > int(b.get("playtime_s", 0))
		)
	else:
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var pa: int = int(a.get("playtime_s", 0))
			var pb: int = int(b.get("playtime_s", 0))
			return pa > pb if pa != pb else int(a.get("total_wins", 0)) > int(b.get("total_wins", 0))
		)
	
	var out: Array = []
	var rank: int = 1
	for row: Dictionary in list.slice(0, limit):
		row["rank"] = rank
		out.append(row)
		rank += 1
	
	_send(ck, {"t": "top_data", "by": by, "list": out, "total_count": list.size()})


func _handle_get_profile(ck: int, d: Dictionary) -> void:
	var uname: String = String(d.get("username", "")).strip_edges()
	var u: Dictionary = _find_user(uname)
	if not u.is_empty():
		_send(ck, {"t": "profile_data", "ok": true, "user": _public_user(u)})
	else:
		_send(ck, {"t": "profile_data", "ok": false, "why": "Игрок не найден"})


func _handle_search_profiles(ck: int, d: Dictionary) -> void:
	var q: String = String(d.get("query", "")).strip_edges().to_lower()
	var res: Array = []
	if q != "":
		for k: String in _users:
			if k.to_lower().contains(q):
				res.append(_public_user(_users[k]))
				if res.size() >= 30:
					break
	_send(ck, {"t": "search_results", "query": d.get("query", ""), "list": res})


func _handle_save_profile(ck: int, d: Dictionary) -> void:
	var tok: String = String(d.get("token", ""))
	var u: Dictionary = _find_user_by_token(tok)
	if u.is_empty():
		_send(ck, {"t": "profile_saved", "ok": false, "why": "Требуется авторизация"})
		return
	
	var is_dev: bool = bool(u.get("is_dev", false))
	if d.get("cosmetics") is Dictionary:
		var cos: Dictionary = d["cosmetics"]
		var fr: String = String(cos.get("frame", "fr_steel"))
		var bn: String = String(cos.get("banner", "bn_steel"))
		var tt: String = String(cos.get("title", ""))
		if not is_dev:
			if fr == "fr_dev": fr = "fr_steel"
			if bn == "bn_dev": bn = "bn_steel"
			if tt in ["tt_dev", "tt_dev_rgb"]: tt = ""
		u["cosmetics"] = {"frame": fr, "banner": bn, "title": tt}
	
	if d.has("avatar") and d["avatar"] is String:
		var av: String = String(d["avatar"])
		if av.length() <= 200000:
			u["avatar"] = av
	
	_save_users(true)
	_send(ck, {"t": "profile_saved", "ok": true, "user": _public_user(u)})
	_event("profile_updated", {"username": u["username"]})


func _handle_sync_stats(ck: int, d: Dictionary) -> void:
	var tok: String = String(d.get("token", ""))
	var u: Dictionary = _find_user_by_token(tok)
	if u.is_empty():
		_send(ck, {"t": "stats_synced", "ok": false, "why": "Требуется авторизация"})
		return
	
	var add_pt: int = clampi(int(d.get("playtime_add_s", 0)), 0, 86400)
	var add_sw: int = clampi(int(d.get("solo_wins_add", 0)), 0, 100)
	
	u["playtime_s"] = int(u.get("playtime_s", 0)) + add_pt
	u["solo_wins"] = int(u.get("solo_wins", 0)) + add_sw
	u["last_seen"] = int(Time.get_unix_time_from_system())
	_save_users()
	_send(ck, {"t": "stats_synced", "ok": true, "user": _public_user(u)})
	_event("stats_synced", {"username": u["username"], "add_playtime": add_pt, "add_solo_wins": add_sw})


func _drop(ck: int, reason: String = "disconnected") -> void :
	if not _clients.has(ck):
		return
	var cl: Dictionary = _clients[ck]
	var code: String = String(cl.get("room", ""))
	var room: Dictionary = _rooms.get(code, {})
	var old_players: Array = _player_rows(room) if not room.is_empty() else []
	_clients.erase(ck)
	_event("client_disconnected", {"client": ck, "room": code, "slot": int(cl.get("id", 0)),
		"name": String(cl.get("name", "")), "ip": String(cl.get("ip", "")), "version": String(cl.get("version", "")),
		"connected_s": _elapsed_seconds(int(cl.get("connected_at", 0))), "reason": reason.left(80)})
	if code == "" or room.is_empty():
		return
	var peers: Dictionary = room["peers"]
	peers.erase(int(cl.get("id", 0)))
	if int(cl.get("id", 0)) == 1:
		if bool(room.get("sealed", false)) and int(room.get("ended_at", 0)) == 0:
			room["ended_at"] = int(Time.get_unix_time_from_system())
			room["end_reason"] = "host_disconnected"
			var dur: int = _room_duration(room)
			for p_row: Dictionary in old_players:
				var pu: String = String(p_row.get("name", ""))
				if pu != "":
					var usr: Dictionary = _find_user(pu)
					if not usr.is_empty():
						usr["playtime_s"] = int(usr.get("playtime_s", 0)) + dur
						_db_dirty = true
			_event("match_ended", {"room": code, "match": String(room.get("match", "")), "reason": "host_disconnected",
				"duration_s": dur, "players": old_players})
		_event("room_closed", {"room": code, "match": String(room.get("match", "")), "reason": reason.left(80), "players": old_players})
		for id: int in peers:
			_send(int(peers[id]), {"t": "error", "why": "Хост закрыл комнату"})
		_rooms.erase(code)
	elif peers.has(1):
		_send(int(peers[1]), {"t": "left", "id": int(cl.get("id", 0))})
		_event("player_left", {"room": code, "match": String(room.get("match", "")), "slot": int(cl.get("id", 0)),
			"name": String(cl.get("name", "")), "ip": String(cl.get("ip", "")), "version": String(cl.get("version", "")),
			"reason": reason.left(80), "match_duration_s": _room_duration(room)})


func _public_rooms() -> Array:
	var out: Array = []
	for code: String in _rooms:
		var r: Dictionary = _rooms[code]
		var n: int = (r["peers"] as Dictionary).size()
		if bool(r.get("pub", false)) and not bool(r["sealed"]) and n < MAX_PEERS:
			out.append({"code": code, "name": String(r.get("name", "")), "n": n, "max": MAX_PEERS, "v": String(r["v"]), "t": int(r.get("t", 0))})
	out.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["n"]) > int(b["n"]) if int(a["n"]) != int(b["n"]) else int(a["t"]) > int(b["t"]))
	out = out.slice(0, LIST_MAX)
	for e: Dictionary in out:
		e.erase("t")
	return out


static func _clean_name(s: String) -> String:
	var o: String = ""
	for ch: String in s.strip_edges():
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127:
			o += ch
	return o.left(NAME_MAX)


func _code_ok(c: String) -> bool:
	if c.length() != 6:
		return false
	for ch: String in c:
		if ALPHABET.find(ch) < 0:
			return false
	return true


func _new_code() -> String:
	var code: String = ""
	while code == "" or _rooms.has(code):
		code = ""
		for i in 6:
			code += ALPHABET[randi() % ALPHABET.length()]
	return code


func _with_ice(ck: int, id: int, done: Callable) -> void :
	if _cf_key == "" or _cf_token == "":
		done.call(_ice(id))
		return
	var req: = HTTPRequest.new()
	req.timeout = 8.0
	root.add_child(req)
	req.request_completed.connect( func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void :
		req.queue_free()
		var ice: Array = [CF_STUN]
		if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
			var d: Variant = JSON.parse_string(body.get_string_from_utf8())
			if d is Dictionary and (d as Dictionary).get("iceServers") is Array:
				ice = _cf_filter((d as Dictionary)["iceServers"])
		else:
			printerr("[Signal] Cloudflare TURN credentials failed: result %d, HTTP %d" % [result, code])
			_event("turn_credentials_failed", {"room_client": ck, "result": result, "http_status": code})
		if _clients.has(ck):
			done.call(ice))
	var url: String = "%s/v1/turn/keys/%s/credentials/generate-ice-servers" % [_cf_api, _cf_key.uri_encode()]
	var err: int = req.request(url, ["Authorization: Bearer " + _cf_token, "Content-Type: application/json"], 
		HTTPClient.METHOD_POST, JSON.stringify({"ttl": TURN_TTL}))
	if err != OK:
		req.queue_free()
		printerr("[Signal] Cloudflare TURN request not sent: %s" % error_string(err))
		_event("turn_credentials_failed", {"client": ck, "reason": error_string(err)})
		done.call([CF_STUN])


func _cf_filter(servers: Array) -> Array:
	var out: Array = []
	for sv: Variant in servers:
		if not (sv is Dictionary):
			continue
		var e: Dictionary = (sv as Dictionary).duplicate()
		var urls: Array = []
		for u: Variant in (e.get("urls", []) if e.get("urls") is Array else [e.get("urls", "")]):
			if not String(u).contains(":53?") and not String(u).ends_with(":53"):
				urls.append(String(u))
		if not urls.is_empty():
			e["urls"] = urls
			out.append(e)
	return out if not out.is_empty() else [CF_STUN]


func _ice(id: int) -> Array:
	var out: Array = []
	if not _stun.is_empty():
		out.append({"urls": Array(_stun)})
	if not _turn.is_empty() and _secret != "":
		var user: String = "%d:df%d" % [int(Time.get_unix_time_from_system()) + TURN_TTL, id]
		var mac: PackedByteArray = Crypto.new().hmac_digest(HashingContext.HASH_SHA1, _secret.to_utf8_buffer(), user.to_utf8_buffer())
		out.append({"urls": Array(_turn), "username": user, "credential": Marshalls.raw_to_base64(mac)})
	return out
