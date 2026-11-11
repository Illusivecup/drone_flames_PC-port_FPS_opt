class_name RtcLink
extends Node











signal room_ready(code: String)
signal failed(why: String)
signal joined_room
signal match_started(match_id: String)
signal waiting_host
signal resumed
signal reattaching(why: String)
signal p2p_started
signal promoted
signal host_changed(host: String, you: bool)
signal ranked_msg(d: Dictionary)

var ranked: Dictionary = {}

var tunnel: WsTunnelPeer = null
var peer_names: Dictionary = {}
var _close_after: bool = false
var _p2p: bool = false

var peer: WebRTCMultiplayerPeer = null
var code: String = ""
var my_id: int = 0
var match_id: String = ""
var _ws: WebSocketPeer = null
var _ice: Array = []
var _conns: Dictionary = {}
var _want: Dictionary = {}
var _open: bool = false
var _ping_t: float = 0.0
var _out: Array = []
var _tokens: float = SEND_BURST
var _bye: bool = false
var _ra_try: int = 0
var _ra_wait: float = -1.0
var _sealed: bool = false
var late_join: bool = false
var _auth_tok_h: String = ""
var _gen: int = 0
const PING_S: float = 25.0
const SEND_PER_S: float = 45.0
const SEND_BURST: float = 8.0
const REATTACH_S: Array = [1.0, 2.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0]
var _closing: Array = []
var _refreshed: bool = false


static func available() -> bool:
	return true


## MultiplayerPeer packets use the WSS room relay when this build selects relay transport.
static func relay_only() -> bool:
	return OS.has_feature("mp_relay") or NetConfig.signal_url.contains("45.145.12.165") or not ClassDB.class_exists("WebRTCPeerConnectionExtension")


func room_sealed() -> bool:
	return _sealed



static func open_socket(ws: WebSocketPeer) -> int:
	NetConfig.load_cfg()
	var headers := PackedStringArray()
	if relay_only():
		headers.append("User-Agent: DroneFlames/" + NetConfig.version())
	else:
		headers.append("Authorization: Bearer " + Account.access)
		headers.append("User-Agent: " + Api.user_agent())
	ws.handshake_headers = headers
	ws.inbound_buffer_size = 1048576
	ws.outbound_buffer_size = 1048576
	ws.max_queued_packets = 2048
	return ws.connect_to_url(NetConfig.signal_url, NetTls.for_url(NetConfig.signal_url))




func host(pub: bool = false, code: String = "") -> void :
	_start({"t": "host", "v": NetConfig.version(), "pub": pub, "code": code, "name": Account.username(), "auth_user": Account.username(), "auth_token": Account.token})



func set_pub(pub: bool) -> void :
	_send({"t": "set_pub", "pub": pub})


func join(room: String, tok: String = "") -> void :
	var msg: Dictionary = {"t": "join", "code": NetConfig.clean_code(room), "v": NetConfig.version(), "late": true,
		"name": Account.username(), "auth_user": Account.username(), "auth_token": Account.token}
	if tok != "":
		msg["rejoin"] = true
		msg["tok_h"] = tok.sha256_text()
	_start(msg)


func reserve(tok: String) -> void:
	if tok != "":
		_send({"t": "reserve", "tok_h": tok.sha256_text()})


func match_end(match_key: String, reason: String, played_s: float) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN or my_id != 1:
		return
	_ws.send_text(JSON.stringify({"t": "match_end", "match": match_key, "reason": reason, "played_s": snappedf(played_s, 1.0)}))
	_ws.poll()




var epoch: int = 0
var snap: int = 0


func resume(mid: String, tok: String = "") -> void :
	var msg: Dictionary = {"t": "resume", "match": mid, "v": NetConfig.version(), "epoch": epoch, "snap": snap,
		"name": Account.username(), "auth_user": Account.username(), "auth_token": Account.token}
	if tok != "":
		msg["tok_h"] = tok.sha256_text()
	_start(msg, my_id == 1 and peer != null)




func seal(tok_hashes: Array = []) -> void :
	_send({"t": "seal", "toks": tok_hashes})



func send_rpc(to: int, d: Dictionary) -> void :
	_send({"t": "rpc", "to": to, "d": d})



func _start_p2p() -> void :
	_p2p = true
	peer = WebRTCMultiplayerPeer.new()
	if my_id == 1:
		peer.create_server()
	else:
		peer.create_client(my_id)
		_conn(1).create_offer()
	p2p_started.emit()



func p2p_connected() -> Array:
	var out: Array = []
	if peer == null:
		return out
	for id: int in _conns:
		if peer.has_peer(id) and bool(peer.get_peer(id).get("connected", false)):
			out.append(id)
	return out



func p2p_done() -> void :
	_p2p = false
	tunnel = null
	if _ws != null:
		done()
		_close_after = true



func done() -> void :
	_send({"t": "done"})
	_bye = true


func socket_open() -> bool:
	return _ws != null



func close() -> void :
	for c: WebRTCPeerConnection in _conns.values():
		c.close()
	_conns.clear()
	close_socket()
	peer = null
	tunnel = null
	_p2p = false
	_close_after = false
	peer_names = {}
	ranked = {}
	my_id = 0
	match_id = ""
	_sealed = false
	late_join = false
	_auth_tok_h = ""



func close_socket() -> void :
	_bye = true
	_gen += 1
	if _ws != null:
		_ws.close(1000)
		_closing.append([_ws, Time.get_ticks_msec()])
	_ws = null
	_open = false
	_out.clear()
	_ra_wait = -1.0


func _start(msg: Dictionary, keep_peer: bool = false) -> void :
	if keep_peer:
		close_socket()
	else:
		close()
	_sealed = false
	NetConfig.load_cfg()
	if NetConfig.signal_url == "":
		failed.emit("Сервер не настроен: net/net.cfg → signal_url")
		return
	_tokens = 120.0 if relay_only() else SEND_BURST
	if not Account.signed_in() and not relay_only():
		failed.emit("Войдите в аккаунт")
		return
	_want = msg
	_auth_tok_h = String(msg.get("tok_h", ""))
	_connect()


func _connect() -> void :
	var g: int = _gen
	if not relay_only():
		await Account.ensure_fresh()
	if g != _gen:
		return
	if not Account.signed_in() and not relay_only():
		failed.emit("Сессия закончилась. Войдите снова")
		return
	_bye = false
	_open = false
	_ws = WebSocketPeer.new()
	var err: int = open_socket(_ws)
	if err != OK:
		failed.emit("Нет связи с сервером (%s)" % error_string(err))
		_ws = null


func _process(delta: float) -> void :
	for k in range(_closing.size() - 1, -1, -1):
		var cw: WebSocketPeer = _closing[k][0]
		cw.poll()
		if cw.get_ready_state() == WebSocketPeer.STATE_CLOSED or Time.get_ticks_msec() - int(_closing[k][1]) > 1000:
			_closing.remove_at(k)
	if _ra_wait >= 0.0:
		_ra_wait -= delta
		if _ra_wait < 0.0:
			_want = {"t": "reattach", "code": code, "id": my_id, "tok_h": _auth_tok_h,
				"v": NetConfig.version(), "name": Account.username(),
				"auth_user": Account.username(), "auth_token": Account.token}
			_connect()
		return
	if _ws == null:
		return
	_ws.poll()
	var st: int = _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN and not _open:
		_open = true
		_refreshed = false
		_ping_t = PING_S
		_out.push_front(_want)
	elif st == WebSocketPeer.STATE_OPEN:
		_ping_t -= delta
		if _ping_t <= 0.0:
			_ping_t = PING_S
			_send({"t": "ping"})
		var send_burst: float = 120.0 if relay_only() else SEND_BURST
		var send_rate: float = 600.0 if relay_only() else SEND_PER_S
		_tokens = minf(send_burst, _tokens + delta * send_rate)
		while not _out.is_empty() and _tokens >= 1.0:
			_tokens -= 1.0
			_ws.send_text(JSON.stringify(_out.pop_front()))
		if _close_after and _out.is_empty():
			_close_after = false
			close_socket()
			return

	while _ws != null and _ws.get_available_packet_count() > 0:
		var d: Variant = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
		if d is Dictionary:
			_on_msg(d)
	if _ws != null and st == WebSocketPeer.STATE_CLOSED:
		_closed(_ws.get_close_code(), _ws.get_close_reason())



func _closed(c: int, reason: String) -> void :
	if NetConfig.trace_api:
		print("[Rtc] closed %d «%s» (sealed %s, bye %s)" % [c, reason, str(_sealed), str(_bye)])
	var was_open: bool = _open
	var pending: Array = _out
	_ws = null
	_open = false
	_out = []
	if c == 4003:
		Account.mark_banned()
		if not _bye:
			failed.emit("Онлайн-игра закрыта для аккаунта")
		return
	if c == 4401 and not _refreshed and Account.signed_in():
		_refreshed = true
		var g4: int = _gen
		if await Account.refresh() and g4 == _gen:
			_out = pending
			_connect()
			return
		failed.emit("Сессия закончилась. Войдите снова")
		return
	if c == 1013 and not _bye:
		failed.emit("Слишком много подключений. Попробуйте позже")
		return
	if _bye or (_sealed and not _p2p and not relay_only()):
		return
	if _p2p and not relay_only():
		return
	if not was_open and String(_want.get("t", "")) == "reattach" and _ra_try < REATTACH_S.size():
		_out = pending
		_ra_wait = float(REATTACH_S[_ra_try])
		_ra_try += 1
		return
	if not was_open and not _refreshed and Account.signed_in():
		_refreshed = true
		var g: int = _gen
		if await Account.refresh() and g == _gen:
			_out = pending
			_connect()
			return
	if not was_open:
		_ra_try = 0
		failed.emit("Сервер не пустил. Попробуйте через минуту" if c == 1008 or c == 1013 else "Нет связи с сервером")
		return
	if c == 1000 and reason == "match started":


		_sealed = true
		match_started.emit("")
		return
	if c == 1000 and reason == "done":
		return
	if c == 1000:
		failed.emit({"idle": "Отключено за бездействие", "resume window": "Время на возвращение истекло", 
			"match ended": "Хост закрыл партию", "match void": "Партия отменена"}.get(reason, "Сервер закрыл соединение"))
		return
	if c == 1008:
		failed.emit("Сервер разорвал соединение")
		return

	if code != "" and my_id > 0 and String(_want.get("t", "")) in ["host", "join", "reattach"]:
		if _ra_try >= REATTACH_S.size():
			_ra_try = 0
			failed.emit("Комната закрылась, пока не было связи")
			return
		_out = pending
		_ra_wait = float(REATTACH_S[_ra_try])
		_ra_try += 1
		reattaching.emit("Сервер перезапускается · переподключаемся..." if c == 1012 else "Связь прервалась · переподключаемся...")
		return
	failed.emit("Нет связи с сервером")


func _send(d: Dictionary) -> void :
	if _ws != null or _ra_wait >= 0.0:
		_out.append(d)




func wait_turn(max_s: float = 3.0) -> void :
	var t0: int = Time.get_ticks_msec()
	while _ws != null and not _sealed and Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		await get_tree().process_frame



func lobby() -> bool:
	return String(_want.get("t", "")) in ["host", "join", "reattach", "queue"] and (not late_join or relay_only())



func queue(mode: String, caps: Dictionary) -> void :
	ranked = {}
	_start({"t": "queue", "mode": mode, "v": NetConfig.version(), "caps": caps})


func unqueue() -> void :
	_send({"t": "unqueue"})


func accept(check_id: String, yes: bool) -> void :
	_send({"t": "accept" if yes else "decline", "id": check_id})



func ready(tok_hashes: Array = []) -> void :
	var m: Dictionary = {"t": "ready"}
	if my_id == 1:
		m["toks"] = tok_hashes
	_send(m)


func _on_msg(d: Dictionary) -> void :
	if NetConfig.trace_api:
		print("[Rtc] <- %s" % String(d.get("t", "")))
	match String(d.get("t", "")):
		"queued", "unqueued", "found", "accept_progress", "mm_cancel":
			ranked_msg.emit(d)
		"room":
			if d.get("ranked") is Dictionary:
				ranked = d["ranked"]
				for c9: WebRTCPeerConnection in _conns.values():
					c9.close()
				_conns.clear()
				peer = null
			code = String(d["code"])
			my_id = 1
			_ice = d.get("ice", [])
			tunnel = WsTunnelPeer.new(self, 1, true)
			room_ready.emit(code)
		"joined":
			for c0: WebRTCPeerConnection in _conns.values():
				c0.close()
			_conns.clear()
			my_id = int(d["id"])
			code = String(d.get("code", ""))
			late_join = bool(d.get("sealed", false))
			if late_join:
				match_id = String(d.get("match", ""))
				_sealed = true
			_ice = d.get("ice", [])
			if d.get("ranked") is Dictionary:
				ranked = d["ranked"]
			if lobby():
				tunnel = WsTunnelPeer.new(self, my_id, false)
				joined_room.emit()
				tunnel.add(1)
				return
			peer = WebRTCMultiplayerPeer.new()
			peer.create_client(my_id)
			var c: WebRTCPeerConnection = _conn(1)
			c.create_offer()
			joined_room.emit()
			if late_join:
				_p2p = true
				p2p_started.emit()
		"resumed":
			my_id = 1
			match_id = String(d.get("match", match_id))
			_ice = d.get("ice", _ice)
			if peer == null:
				peer = WebRTCMultiplayerPeer.new()
				peer.create_server()
			resumed.emit()
		"waiting_host":
			waiting_host.emit()
		"promoted":
			epoch = int(d.get("epoch", epoch))
			my_id = 1
			match_id = String(d.get("match", match_id))
			_ice = d.get("ice", _ice)
			for c7: WebRTCPeerConnection in _conns.values():
				c7.close()
			_conns.clear()
			peer = WebRTCMultiplayerPeer.new()
			peer.create_server()
			promoted.emit()
		"host_changed":
			epoch = int(d.get("epoch", epoch))
			host_changed.emit(String(d.get("host", "")), bool(d.get("you", false)))
		"reattached":
			_ra_try = 0
			my_id = int(d.get("id", my_id))
			_ice = d.get("ice", _ice)
			reattaching.emit("")
		"turn":
			_sealed = true
			match_id = String(d["match"]) if d.get("match") != null else ""
			_ice = d.get("ice", _ice)
			match_started.emit(match_id)
			if tunnel != null and peer == null:
				if not relay_only():
					_start_p2p()
			else:
				close_socket()
		"peer":
			var pid: int = int(d["id"])
			peer_names[pid] = String(d.get("name", ""))
			if tunnel != null and peer == null:
				tunnel.add(pid)
				return
			if _conns.has(pid):
				(_conns[pid] as WebRTCPeerConnection).close()
				_conns.erase(pid)
				if peer != null and peer.has_peer(pid):
					peer.remove_peer(pid)
			_conn(pid)
		"offer":
			var c2: WebRTCPeerConnection = _conn(int(d["from"]))
			c2.set_remote_description("offer", clean_sdp(String(d["sdp"])))
		"answer":
			if _conns.has(int(d["from"])):
				(_conns[int(d["from"])] as WebRTCPeerConnection).set_remote_description("answer", clean_sdp(String(d["sdp"])))
		"cand":
			if _conns.has(int(d["from"])) and ice_ok(String(d["sdp"])):
				(_conns[int(d["from"])] as WebRTCPeerConnection).add_ice_candidate(String(d["mid"]), int(d["idx"]), String(d["sdp"]))
		"rpc":
			if tunnel != null and d.get("d") is Dictionary:
				tunnel.receive(int(d.get("from", 0)), d["d"])
		"left":
			var lid: int = int(d["id"])
			if tunnel != null and peer == null:
				tunnel.remove(lid)
				return
			if _conns.has(lid) and (peer == null or not peer.has_peer(lid) or peer.get_peer(lid).get("connected") != true):
				(_conns[lid] as WebRTCPeerConnection).close()
				_conns.erase(lid)
		"pong":
			pass
		"error":
			var why: String = String(d.get("why", "Ошибка сервера"))
			if String(d.get("code", "")) == "suspended":
				Account.set_suspension(d)
				failed.emit("ОТСТРАНЕНИЕ ДО %s · %s" % [Account.suspension_until(), Account.suspension_reason()])
				return
			if why.begins_with("Сессия закончилась") and not _refreshed:
				return
			_bye = true
			failed.emit(why)






static func ice_ok(cand: String) -> bool:
	var parts: PackedStringArray = cand.strip_edges().split(" ", false)
	if parts.size() < 8 or parts.find("typ") < 0:
		return true
	var addr: String = parts[4].to_lower()
	var typ: String = parts[parts.find("typ") + 1] if parts.find("typ") + 1 < parts.size() else ""
	if typ == "relay":
		return true
	if addr.begins_with("169.254.") or addr.begins_with("fe80:") or addr.begins_with("2002:"):
		return false
	if addr.begins_with("2001:0:") or addr.begins_with("2001::") or addr.begins_with("2001:0000:"):
		return false
	return true



static func clean_sdp(sdp: String) -> String:
	if sdp.find("a=candidate:") < 0:
		return sdp
	var out: PackedStringArray = PackedStringArray()
	for ln: String in sdp.split("\n"):
		var l2: String = ln.strip_edges()
		if l2.begins_with("a=candidate:") and not ice_ok(l2.substr(2)):
			continue
		out.append(ln)
	return "\n".join(out)


func _conn(id: int) -> WebRTCPeerConnection:
	if _conns.has(id):
		return _conns[id]
	var c: = WebRTCPeerConnection.new()
	var err: int = c.initialize({"iceServers": _ice})
	if err != OK:
		failed.emit("WebRTC недоступен (%s)" % error_string(err))
	c.session_description_created.connect( func(type: String, sdp: String) -> void :
		c.set_local_description(type, sdp)
		_send({"t": type, "to": id, "sdp": sdp}))
	c.ice_candidate_created.connect( func(mid: String, idx: int, sdp: String) -> void :
		if ice_ok(sdp):
			_send({"t": "cand", "to": id, "mid": mid, "idx": idx, "sdp": sdp}))
	peer.add_peer(c, id)
	_conns[id] = c
	return c
