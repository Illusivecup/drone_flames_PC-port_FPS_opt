class_name DipChat
extends RefCounted









signal changed(cid: int)
signal incoming(cid: int, text: String)




const KEYS: Dictionary = {"k1": "a3ae5e38ad04791299af515c6790ed07511bdab22e756ac01a4e0db72356ce65"}


const DEV_KEYS: Dictionary = {"dev": "19665d3a2d245a49c4e51dd72f8b89a343e2b50428051e6d8f41891c81baa9db"}
const DOMAIN: String = "DFCHAT1"
const MAX_LEN: int = 200
const GAP_S: float = 1.5
const MAX_HIST: int = 80
const MAX_DATA: int = 400
const MAX_ENV_BYTES: int = 1800
const VERIFY_PER_SENDER: int = 4
const VERIFY_ALL: int = 12

var net: NetSession
var hist: Dictionary = {}
var unread: Dictionary = {}
var muted: Dictionary = {}
var open_cid: int = -1
var _last_seq: Dictionary = {}
var _queue: Dictionary = {}
var _draining: Dictionary = {}
var _gen: int = 0
var _in_flight: int = 0
var _next_send: float = 0.0
var _id: int = 0
var _keys: Dictionary = {}


func _init(session: NetSession) -> void :
	net = session
	for k: String in KEYS:
		_keys[k] = String(KEYS[k]).hex_decode()
	if OS.has_feature("editor"):
		for k2: String in DEV_KEYS:
			_keys[k2] = String(DEV_KEYS[k2]).hex_decode()



func reset() -> void :
	hist.clear()
	unread.clear()
	muted.clear()
	_last_seq.clear()
	_queue.clear()
	_draining.clear()
	_gen += 1
	open_cid = -1


func online() -> bool:
	return net.mode == NetSession.Mode.ONLINE



func slot_of(cid: int) -> int:
	var s: int = cid - 1
	return s if s >= 0 and s < net.slots.size() and s != net.local_slot else -1


func seat_of_slot(s: int) -> int:
	return int(net.slots[s].get("seat", 0)) if s >= 0 and s < net.slots.size() else 0




func my_seat() -> int:
	return seat_of_slot(net.local_slot)



func why_closed(cid: int) -> String:
	if net == null or not net.in_match or net.mode == NetSession.Mode.OFF:
		return "off"
	var s: int = slot_of(cid)
	if s < 0:
		return "off"
	var sl: Dictionary = net.slots[s]
	if bool(sl.get("left", false)) or bool(sl.get("rot", false)):
		return "left"
	if seat_of_slot(s) <= 0:
		return "off"
	if online() and net.match_id == "":
		return "off"
	return ""



func available(cid: int) -> bool:
	return why_closed(cid) == "" or (why_closed(cid) == "left" and hist.has(cid))


func cooldown() -> float:
	return maxf(0.0, _next_send - Time.get_ticks_msec() / 1000.0)


func send(cid: int, text: String) -> void :
	var t: String = text.strip_edges().replace("\n", " ")
	if t == "" or why_closed(cid) != "" or cooldown() > 0.0:
		return
	t = t.left(MAX_LEN)
	_next_send = Time.get_ticks_msec() / 1000.0 + GAP_S
	_id += 1
	var m: Dictionary = {"mine": true, "text": t, "t": _now(), "state": "sending", "why": "", "masked": false, "id": _id, "raw": t}
	_push(cid, m)
	_deliver_mine(cid, m)



func retry(cid: int, id: int) -> void :
	for m: Dictionary in hist.get(cid, []):
		if int(m["id"]) == id and String(m["state"]) == "fail" and cooldown() <= 0.0 and why_closed(cid) == "":
			_next_send = Time.get_ticks_msec() / 1000.0 + GAP_S
			m["state"] = "sending"
			m["why"] = ""
			changed.emit(cid)
			_deliver_mine(cid, m)


func drop(cid: int, id: int) -> void :
	var h: Array = hist.get(cid, [])
	for i in h.size():
		if int(h[i]["id"]) == id:
			h.remove_at(i)
			changed.emit(cid)
			return


func set_open(cid: int) -> void :
	open_cid = cid
	if cid >= 0 and unread.erase(cid):
		changed.emit(cid)


func unread_total() -> int:
	var n: int = 0
	for c: int in unread:
		if not muted.has(c):
			n += int(unread[c])
	return n


func _deliver_mine(cid: int, m: Dictionary) -> void :
	var to: int = seat_of_slot(slot_of(cid))
	if not online():
		m["state"] = "ok"
		changed.emit(cid)
		_send_env({"lan": 1, "data": m["text"], "from_seat": my_seat(), "to_seat": to})
		return
	var gen: int = _gen
	var r: Dictionary = await Api.i().call_api("POST", "/mp/chat_message", {"match": net.match_id, "to_seat": to, "text": String(m["raw"])})
	if gen != _gen:
		return
	var code: int = int(r["code"])
	if code != 200 or not (r["data"] is Dictionary):
		m["state"] = "fail"
		m["why"] = _why_ru(code, r["data"])
		if code == 403:
			var det: Variant = (r["data"] as Dictionary).get("detail") if r["data"] is Dictionary else null
			if det is Dictionary:
				Account.set_suspension(det)
			m["why"] = "ЧАТ ЗАКРЫТ ДО %s" % Account.suspension_until() if Account.suspended_s() > 0 else "ЧАТ ЗАКРЫТ"
			m["no_retry"] = true
		if code == 422 and String((r["data"] as Dictionary).get("detail", "") if r["data"] is Dictionary else "") == "Empty after filter":
			m["why"] = "ПУСТО ПОСЛЕ ФИЛЬТРА"
			m["no_retry"] = true
		changed.emit(cid)
		return
	var env: Dictionary = r["data"]
	var ok_own: bool = await _verify(env, true)
	if gen != _gen:
		return
	if not ok_own:
		m["state"] = "fail"
		m["why"] = "ПОДПИСЬ НЕ СОШЛАСЬ"
		changed.emit(cid)
		return
	m["text"] = String(env["data"])
	m["masked"] = bool(env.get("masked", false))
	env.erase("masked")
	m["env"] = env
	if _send_env(env):
		m["state"] = "ok"
	else:
		m["state"] = "fail"
		m["why"] = "НЕТ СВЯЗИ С ХОСТОМ"
	changed.emit(cid)


func _send_env(env: Dictionary) -> bool:
	if net.is_host:
		net.chat_route(env)
		return true
	return net.chat_to_host(env)




func on_env(env: Variant, from_peer: int) -> void :
	if not (env is Dictionary) or var_to_bytes(env).size() > MAX_ENV_BYTES:
		return
	var e: Dictionary = env
	if net.is_host and from_peer > 1:
		var ps: int = net._slot_of(from_peer)
		if ps < 0 or seat_of_slot(ps) != int(e.get("from_seat", 0)):
			return
	if net.is_host and int(e.get("to_seat", 0)) != my_seat():
		net.chat_route(e, from_peer)
		return
	if not net.is_host and from_peer != 1:
		return
	if int(e.get("to_seat", 0)) != my_seat():
		return
	var from_seat: int = int(e.get("from_seat", 0))
	var cid: int = _cid_of_seat(from_seat)
	if cid < 0:
		return
	if not online():
		if net.mode == NetSession.Mode.LAN:
			_show_theirs(cid, String(e.get("data", "")).strip_edges().replace("\n", " ").left(MAX_DATA))
		return
	var q: Array = _queue.get(from_seat, [])
	if q.size() >= VERIFY_PER_SENDER or _queued_all() >= VERIFY_ALL:
		return
	q.append(e)
	_queue[from_seat] = q
	if not _draining.has(from_seat):
		_drain(from_seat)




func _drain(from_seat: int) -> void :
	_draining[from_seat] = true
	var gen: int = _gen
	while not (_queue.get(from_seat, []) as Array).is_empty():
		var e: Dictionary = (_queue[from_seat] as Array).pop_front()
		var ok: bool = await _verify(e, false)
		if gen != _gen:
			return
		var cid: int = _cid_of_seat(from_seat)
		if not ok or cid < 0:
			print("[Chat] an envelope from seat %d refused" % from_seat)
			continue
		var seq: int = int(e["seq"])
		if seq <= int(_last_seq.get(from_seat, 0)):
			continue
		_last_seq[from_seat] = seq
		_show_theirs(cid, String(e["data"]), e)
	_draining.erase(from_seat)


func _queued_all() -> int:
	var n: int = 0
	for k: int in _queue:
		n += (_queue[k] as Array).size()
	return n


func _show_theirs(cid: int, text: String, env: Dictionary = {}) -> void :
	if text == "":
		return
	_id += 1
	_push(cid, {"mine": false, "text": text, "t": _now(), "state": "ok", "why": "", "masked": false, "id": _id, "env": env})
	if cid != open_cid:
		unread[cid] = int(unread.get(cid, 0)) + 1
		changed.emit(cid)
		if not muted.has(cid):
			incoming.emit(cid, text)


func _cid_of_seat(seat: int) -> int:
	if seat <= 0:
		return -1
	for i in net.slots.size():
		if i != net.local_slot and seat_of_slot(i) == seat:
			return i + 1
	return -1



func _verify(e: Dictionary, mine: bool) -> bool:
	for k: String in ["data", "sign", "ts", "kid", "match", "from_seat", "to_seat", "seq", "n"]:
		if not e.has(k):
			return false
	var data: String = String(e["data"])
	var kid: String = String(e["kid"])
	if data.length() > MAX_DATA or data.contains("\n") or not _keys.has(kid) or String(e["n"]).length() > 32:
		return false
	if String(e["match"]) != net.match_id:
		return false
	var me_seat: int = my_seat()
	if (mine and int(e["from_seat"]) != me_seat) or ( not mine and int(e["to_seat"]) != me_seat):
		return false
	var sig: PackedByteArray = Marshalls.base64_to_raw(String(e["sign"]))
	if sig.size() != 64:
		return false
	var msg: PackedByteArray = "\n".join(PackedStringArray([DOMAIN, kid, String(e["match"]), str(int(e["from_seat"])), 
		str(int(e["to_seat"])), str(int(e["seq"])), str(int(e["ts"])), String(e["n"]), data])).to_utf8_buffer()
	var pk: PackedByteArray = _keys[kid]
	var res: Array = [false, false]
	_in_flight += 1
	Ed25519.prepare()
	var task: int = WorkerThreadPool.add_task( func() -> void :
		res[1] = Ed25519.verify(sig, msg, pk)
		res[0] = true)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	while not bool(res[0]):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	_in_flight -= 1
	return bool(res[1])


func _push(cid: int, m: Dictionary) -> void :
	var h: Array = hist.get(cid, [])
	h.append(m)
	while h.size() > MAX_HIST:
		h.pop_front()
	hist[cid] = h
	changed.emit(cid)


func _now() -> float:
	return net.gw.game_time if net.gw != null else 0.0


static func _why_ru(code: int, data: Variant) -> String:
	match code:
		0:
			return "СЕРВЕР НЕДОСТУПЕН"
		429:
			return "СЛИШКОМ ЧАСТО"
		404:
			return "ПАРТИЯ НЕ НАЙДЕНА НА СЕРВЕРЕ"
		422:
			return "СЛИШКОМ ДЛИННО" if str(data).contains("long") else "ПУСТОЕ СООБЩЕНИЕ"
		503:
			return "ЧАТ ВРЕМЕННО ВЫКЛЮЧЕН"
		401:
			return "СЕССИЯ ЗАКОНЧИЛАСЬ"
	return "ОШИБКА СЕРВЕРА %d" % code




func evidence(cid: int) -> Array:
	var out: Array = []
	for m: Dictionary in hist.get(cid, []):
		var e: Dictionary = m.get("env", {})
		if not e.is_empty():
			out.append(e)
	return out.slice(-40)



func evidence_theirs(cid: int) -> int:
	return hist.get(cid, []).filter( func(m: Dictionary) -> bool: return not bool(m["mine"]) and not (m.get("env", {}) as Dictionary).is_empty()).size()
