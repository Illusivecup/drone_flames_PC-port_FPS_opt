extends RefCounted








const C_REVOKE: Array = ["revoke_passage"]
const C_OFFER_PASS: Array = ["offer_passage"]
const C_EXPEL: Array = ["expel_troops"]
const C_RECALL: Array = ["recall_troops"]
const C_SKY_END: Array = ["sky_end"]
const C_SKY_OFFER: Array = ["sky_offer"]
const C_SKY_ASK: Array = ["sky_ask"]
const C_SKY_HOME: Array = ["sky_take_home"]


const TRD: String = "econ.trd"
const C_REQUEST: Array = ["request"]
const C_REQ_CANCEL: Array = ["cancel_request"]
const C_GUARD: Array = ["guard_send", "send_guard"]
const C_GUARD_END: Array = ["guard_end", "guard_recall"]

const AG = preload("res://game/army_groups.gd")
const MIL_AID: Array = ["drones", "missile_b", "missile_c", "missile_sam"]

var gw: GameWorld
var dp: Diplomacy
var me: int = 0


func _init(world: GameWorld, me_id: int) -> void :
	gw = world
	dp = world.diplo
	me = me_id



func cmd(names: Array) -> String:
	for n: String in names:
		if dp.has_method(n) and NetSession.allowed().has("diplo." + n):
			return n
	return ""


func has(names: Array) -> bool:
	return cmd(names) != ""



func trd():
	return gw.econ.get("trd") if gw.econ != null else null



func tcmd(m: String) -> String:
	var t = trd()
	return m if t != null and t.has_method(m) and NetSession.allowed().has(TRD + "." + m) else ""


func _call(obj: Object, m: String, args: Array) -> Variant:
	return obj.callv(m, args) if obj != null and obj.has_method(m) else null





func troops_on(who: int, land: int) -> int:
	return int(dp.troops_on(who, land)) if dp.has_method("troops_on") else 0



func leaving(who: int, land: int) -> int:
	if gw.ops != null and gw.ops.has_method("withdraw_left"):
		return int(gw.ops.withdraw_left(who, land))
	return -1



func t_offer(a: int, b: int, kind: String) -> Dictionary:
	for o: Dictionary in dp.t_offers:
		if int(o["from"]) == a and int(o["to"]) == b and String(o["kind"]) == kind and gw.game_time <= float(o.get("until", 1e+18)):
			return o
	return {}



func pass_wait(grantor: int, grantee: int) -> Dictionary:
	if not dp.has_method("passage_wait"):
		return {}
	var r: Variant = dp.passage_wait(grantor, grantee)
	return r if r is Dictionary else {}



func war_block(a: int, b: int) -> Dictionary:
	if not dp.has_method("war_block"):
		return {}
	var r: Variant = dp.war_block(a, b)
	return r if r is Dictionary else {}




func sky_ready() -> bool:
	return has(C_SKY_END) and dp.has_method("sky_info")





func sky(c: int, h: int) -> Dictionary:
	if not dp.has_method("sky_info"):
		return {}
	var other: int = h if c == me else c
	var info: Variant = dp.sky_info(me, other)
	if not (info is Dictionary):
		return {}
	var d: Variant = (info as Dictionary).get("over_them" if c == me else "over_me", {})
	return d if d is Dictionary else {}



func sky_sig(c: int, h: int) -> String:
	var d: Dictionary = sky(c, h)
	return "%s%d%s%s" % [d.get("on", false), int(d.get("n", 0)), d.get("pending", false), String(d.get("can", ""))]



func sky_away(host: int) -> Array:
	var out: Array = []
	if dp.has_method("sky_away"):
		for a: Dictionary in dp.sky_away(me):
			if int(a.get("host", -1)) == host:
				out.append(a)
	return out



func status(cid: int) -> Dictionary:
	var ps = gw.get("pstat")
	if ps != null and ps.has_method("label_parts"):
		var r: Variant = ps.label_parts(cid)
		if r is Dictionary:
			return r
	return {}



func rival_of(cid: int) -> int:
	var ps = gw.get("pstat")
	if ps != null and ps.has_method("rival_of"):
		return int(ps.rival_of(cid))
	return -1



func rival_dir(a: int, b: int) -> int:
	if rival_of(a) == b:
		return 1
	if rival_of(b) == a:
		return 2
	return 0



func rivals(a: int, b: int) -> bool:
	var ps = gw.get("pstat")
	if ps != null and ps.has_method("is_rival"):
		return bool(ps.is_rival(a, b)) or bool(ps.is_rival(b, a))
	return rival_of(a) == b or rival_of(b) == a




func sanct_ready() -> bool:
	return tcmd("set_sanctions") != ""



func sanctions(f: int, t: int) -> Array:
	var tr = trd()
	return tr.sanctions_by(f, t) if tr != null and tr.has_method("sanctions_by") else []



func sanction_grid(t: int) -> Array:
	var tr = trd()
	return tr.sanction_grid(me, t) if tr != null and tr.has_method("sanction_grid") else []



func sanction_preview(t: int, want: Array) -> Dictionary:
	var tr = trd()
	return tr.sanction_preview(me, t, want) if tr != null and tr.has_method("sanction_preview") else {"why": "скоро", "text": ""}



func pressing(t: int) -> Array:
	var out: Array = []
	for c: Country in gw.countries:
		if c.id == t or c.eliminated:
			continue
		if dp.embargoed(c.id, t) or not sanctions(c.id, t).is_empty():
			out.append(c.id)
	return out




func contracts(cid: int) -> Array:
	var tr = trd()
	return tr.contracts_of(me, cid) if tr != null and tr.has_method("contracts_of") else []



func contract_room(cid: int, res: String = "") -> String:
	if NetSession.inst() != null and (NetSession.inst().reconnecting or NetSession.inst().rejoining):
		return "нет связи — контракт не отправить"
	var tr = trd()
	if tr != null and tr.has_method("contract_why"):
		return String(tr.contract_why(me, cid, res))
	var c: Country = gw.country_by_id(cid)
	if c == null or not c.is_player:
		return "только с живым игроком"
	return Loc.t("только в сетевой игре") if not gw.net_driven else ""



func contract_terms(cid: int, res: String, selling: bool) -> Dictionary:
	var tr = trd()
	if tr != null and tr.has_method("contract_terms"):
		return tr.contract_terms(me, cid, res, selling)
	var mp: int = int(gw.econ.market_price(res)) if gw.econ != null else 10
	return {"market": mp, "price_min": maxi(1, mp / 2), "price_max": mp * 2, "per": [5, 10, 20, 30, 40, 60], "every": [60], "n_min": 2, "n_max": 20, 
		"have": int(gw.player.get(res)) if gw.player != null else 0, "room": 0, "why": "скоро"}



func mil_aid(cid: int) -> Array:
	var out: Array = []
	var ct: Country = gw.country_by_id(cid)
	for o: Dictionary in dp.aid_options(me, cid):
		var w: String = String(o["what"])
		if not MIL_AID.has(w):
			continue
		var room: int = int(o.get("room", -1))
		if room < 0 and ct != null and gw.mil != null:
			match w:
				"drones":
					room = int(gw.mil.drone_room(ct))
				"missile_b":
					room = maxi(0, int(Military.MT_CAP[Military.MT_BALLISTIC]) - int(ct.missile_stock[Military.MT_BALLISTIC]))
				"missile_c":
					room = maxi(0, int(Military.MT_CAP[Military.MT_CRUISE]) - int(ct.missile_stock[Military.MT_CRUISE]))
				"missile_sam":
					room = maxi(0, int(Military.MT_CAP[Military.MT_SAM]) - int(ct.missile_stock[Military.MT_SAM]))
		var d: Dictionary = o.duplicate()
		d["room"] = maxi(0, room)
		out.append(d)
	return out





func reqs_between(a: int, b: int) -> Array:
	var out: Array = []
	var rs: Variant = dp.get("reqs")
	var arr: Array = []
	if rs is Dictionary:
		arr = (rs as Dictionary).values()
	elif rs is Array:
		arr = rs
	for q: Variant in arr:
		if q is Dictionary:
			var d: Dictionary = q
			if int(d.get("from", -1)) == a and int(d.get("to", -1)) == b:
				out.append(d)
	return out





func outlook(cid: int, kind: String, x: int) -> Dictionary:
	if dp.has_method("request_outlook"):
		var r: Variant = dp.request_outlook(me, cid, kind, x)
		if r is Dictionary:
			return r
	if kind == "join_war" and dp.has_method("call_outlook"):
		var o: Dictionary = dp.call_outlook(me, cid, x)
		var a: String = String(o.get("ans", "no"))
		var why: String = String(o.get("why", ""))
		var w: float = float(o.get("wait", 0.0))
		match a:
			"join":
				return {"ans": "yes", "why": "", "pros": [Loc.t("%s воюет с вами") % _nm(x)], "cons": [], "wait": w}
			"aid":
				return {"ans": "maybe", "why": why, "pros": [], "cons": [(Loc.t("в войну не пойдёт: %s") % [why]) if why != "" else Loc.t("скорее пришлёт помощь")], "wait": w}
			"human":
				return {"ans": "maybe", "why": "", "pros": [], "cons": [], "wait": w, "human": true}
			"pending":
				return {"ans": "wait", "why": "уже просили · ждём ответа", "pros": [], "cons": [], "wait": w}
		return {"ans": "lock" if a == "no" else "no", "why": why, "pros": [], "cons": [why] if why != "" else [], "wait": w}
	return {"ans": "lock", "why": "скоро", "soon": true, "pros": [], "cons": [], "wait": 0.0}


func _nm(cid: int) -> String:
	var c: Country = gw.country_by_id(cid)
	return c.name if c != null else "?"






func guard_of(cid: int) -> Dictionary:
	if dp.has_method("guard_info"):
		var r: Variant = dp.guard_info(me, cid)
		if r is Dictionary:
			return r
	return {}



func guard_in(cid: int) -> Dictionary:
	if not dp.has_method("req_stations"):
		return {}
	for e: Dictionary in dp.req_stations(me):
		if int(e.get("who", -1)) == cid and int(e.get("host", -1)) == me:
			return e
	return {}



func req_targets(cid: int, kind: String) -> Array:
	return dp.req_targets(me, cid, kind) if dp.has_method("req_targets") else []



func press_on(t: int) -> Array:
	return dp.req_press_on(t) if dp.has_method("req_press_on") else []



func req_wait(cid: int, kind: String) -> float:
	var rq = dp.get("rq")
	return float(rq.wait_left(me, cid, kind)) if rq != null and rq.has_method("wait_left") else 0.0



func subject_wars(sid: int) -> Dictionary:
	if not dp.has_method("subject_wars") or dp.subject_of(sid) != me:
		return {}
	return dp.subject_wars(sid)




func rate_wait() -> float:
	var rq = dp.get("rq")
	if rq == null or not (rq.get("sent") is Dictionary):
		return 0.0
	var cm: Dictionary = (rq.get_script() as Script).get_script_constant_map()
	var n: int = int(cm.get("HUMAN_RATE_N", 3))
	var t: float = float(cm.get("HUMAN_RATE_T", 120.0))
	var recent: Array = []
	for x: Variant in (rq.sent.get(me, []) as Array):
		if gw.game_time - float(x) < t:
			recent.append(float(x))
	if recent.size() < n:
		return 0.0
	recent.sort()
	return maxf(0.0, float(recent[recent.size() - n]) + t - gw.game_time)
