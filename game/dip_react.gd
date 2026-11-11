extends RefCounted

















const STAGE_NAMES: Array = ["ПРОТЕСТ", "УГРОЗА", "ТРЕБОВАНИЕ", "УЛЬТИМАТУМ"]
const STAGE_ICONS: Array = ["icon_dip_protest", "icon_dip_threat", "icon_dip_demand", "icon_dip_ult"]
const CAUSE_ICONS: Dictionary = {"convoy": "icon_cause_convoy", "port": "icon_cause_port", "bridge": "icon_cause_bridge", 
	"oil": "icon_cause_oil", "blockade": "icon_cause_blockade", "neutral": "icon_cause_neutral", "crisis": "icon_cause_oil"}
const HEAT_AT: Array = [1.0, 3.0, 5.5, 8.5]
const HEAT_HALF: float = 240.0
const HEAT_MAX: float = 12.0
const KEPT_OPEN: float = 2.0
const ANSWER_T: Array = [45.0, 60.0, 90.0, 75.0]
const COMPLY_T: float = 180.0
const STAGE_GAP: float = 60.0
const FROM_GAP: float = 120.0
const WIN: float = 600.0
const NOTES_MAX: int = 8
const NOTES_HI: int = 2
const PLAYER_MAX: int = 5
const PLAYER_HI: int = 2
const LAST_BLK: float = 1.5
const ULT_GAP: float = 300.0
const PLAYER_ULT_GAP: float = 480.0
const FIRST_T: float = 120.0
const AI_ANSWER_T: float = 15.0
const PROMISE_GRACE: float = 15.0
const CLOSE_HEAT: float = 0.35
const QUIET_T: float = 120.0
const DESCALE_T: float = 180.0
const TICK: float = 2.0
const LAST_DT: float = 60.0
const CRISIS_LONG: float = 120.0
const IMPORTERS_MAX: int = 2
const NEWS_GAP: float = 20.0
const NEWS_MAX: int = 10
const NEWS_KEY_GAP: float = 180.0
const INS_N: int = 3
const INS_T: float = 180.0
const INS_CALM: float = 300.0
const COMP_MUL: Array = [1.0, 1.3, 1.7, 2.2]

const SEV_VICTIM: Dictionary = {"convoy_sunk": 2.2, "neutral_sunk": 3.5, "port_hit": 3.0, "bridge_destroyed": 2.5, "oil_hit": 3.0, "blockade_start": 4.0, "jam": 0.0}
const SEV_IMPORT: Dictionary = {"convoy_sunk": 1.0, "neutral_sunk": 0.6, "port_hit": 1.2, "bridge_destroyed": 0.9, "oil_hit": 1.2, "blockade_start": 1.6, "jam": 0.3}
const RES_GEN: Dictionary = {"oil": "НЕФТИ", "fuel": "ТОПЛИВА", "metal": "МЕТАЛЛА", "titanium": "ТИТАНА", "wood": "ЛЕСА", 
	"food": "ПРОДОВОЛЬСТВИЯ", "goods": "ТОВАРОВ", "precious": "ДРАГМЕТАЛЛОВ", "uranium": "УРАНА"}
const RES_NOM: Dictionary = {"oil": "НЕФТЬ", "fuel": "ТОПЛИВО", "metal": "МЕТАЛЛ", "titanium": "ТИТАН", "wood": "ЛЕС", 
	"food": "ПРОДОВОЛЬСТВИЕ", "goods": "ТОВАРЫ", "precious": "ДРАГМЕТАЛЛЫ", "uranium": "УРАН"}

var dp: Diplomacy
var gw: GameWorld
var threads: Array = []
var events: Dictionary = {}
var blockades: Dictionary = {}
var counters: Dictionary = {}
var _id: int = 1
var _t: float = 0.0
var _last_t: float = 0.0
var _emits: Array = []
var _news_t: Array = []
var _news_key: Dictionary = {}
var _from_t: Dictionary = {}
var _ult_t: float = -1000000000.0
var _pult_t: float = -1000000000.0
var _sinks: Array = []
var _inc_log: Array = []
var _sup: Object = null
var _navy_cb: bool = false


func _init(d: Diplomacy) -> void :
	dp = d
	gw = d.gw






func _wire() -> void :
	var s: Object = gw.get("supply") as Object
	if s != null and s != _sup and s.has_signal("incident"):
		if _sup != null and is_instance_valid(_sup) and _sup.is_connected("incident", on_incident):
			_sup.disconnect("incident", on_incident)
		s.connect("incident", on_incident)
		_sup = s
	if _sup != null and is_instance_valid(_sup):
		if _navy_cb and gw.navy != null and gw.navy.event.is_connected(_on_navy):
			gw.navy.event.disconnect(_on_navy)
		_navy_cb = false
		return
	if not _navy_cb and gw.get("navy") != null:
		gw.navy.event.connect(_on_navy)
		_navy_cb = true



func _on_navy(ev: Dictionary) -> void :
	if String(ev.get("k", "")) != "convoy_sunk":
		return
	var by: int = int(ev.get("by", 0))
	var own: int = int(ev.get("c", 0))
	var kind: String = "convoy_sunk" if dp.at_war(by, own) else "neutral_sunk"
	on_incident(kind, by, own, "", ev.get("pos", Vector2.ZERO), {"value": int(ev.get("value", 0))})





func on_incident(kind: String, attacker: int, victim: int, commodity: String, pos: Vector2, info: Dictionary) -> void :
	var now: float = gw.game_time
	_count("inc_" + kind)
	match kind:
		"crisis_start":

			_event_on("crisis:" + String(info.get("key", commodity)), "crisis", commodity, pos, Loc.mk("Кризис %s в регионе%s", [Loc.mk(_gen(commodity)), _why(info)]), "")
			return
		"crisis_end":
			_event_off("crisis:" + String(info.get("key", commodity)), "", "")
			return
		"jam":
			var place: String = _place(pos, info)
			_event_on("jam:" + place, "jam", commodity, pos, Loc.mk("Пробка на мосту у г. %s", [place]), "")
		"pontoon_built":
			_news(Loc.msg(Loc.mk("ПОНТОН У Г. %s: ПОСТАВКИ ИДУТ", [_place(pos, info).to_upper()])), "grass_light", "pont:" + _place(pos, info))
			return
		"blockade_end":
			blockades.erase("%d>%d" % [attacker, victim])
			for t: Dictionary in threads:
				if int(t["to"]) == attacker and String(t["cause"]) == "blockade" and int(t["vs"]) == victim and String(t["state"]) == "comply":
					t["comply_until"] = now
			return
	if attacker <= 0 or attacker == victim or now < FIRST_T or not dp._alive(attacker):
		return
	if kind == "convoy_sunk" or kind == "neutral_sunk":
		_sinks.append(now)
	_inc_log.append([now, attacker, victim, commodity])
	var cause: String = _cause(kind, commodity, info)
	var obj: String = _obj(cause, victim, pos, info)
	var value: int = int(info.get("value", 0))
	if kind == "blockade_start":
		blockades["%d>%d" % [attacker, victim]] = {"since": now, "obj": obj, "t": now, "res": commodity}

	var sv: float = float(SEV_VICTIM.get(kind, 1.5))
	if victim > 0 and sv > 0.0 and _may_complain(victim, attacker):
		_heat(victim, attacker, victim if cause != "neutral" else 0, cause, commodity, sv, obj, value)

	var cargo: int = 0
	for k: String in ["to", "buyer", "from", "seller"]:
		var o: int = int(info.get(k, 0))
		if o > 0 and o != victim and o != attacker and _may_complain(o, attacker):
			_heat(o, attacker, victim, cause, commodity, float(SEV_IMPORT.get(kind, 0.8)) * 1.4, obj, value / 2)
			cargo = o
			break

	var si: float = float(SEV_IMPORT.get(kind, 0.8))
	if si <= 0.0 or victim <= 0:
		return
	var deps: Array = []
	for c: Country in gw.countries:
		if c.is_player or c.id == attacker or c.id == victim or c.id == cargo or not _may_complain(c.id, attacker) or dp.at_war(c.id, victim):
			continue
		var d: float = _dep(c, victim, commodity)
		if d > 0.0:
			deps.append([d, c.id])
	deps.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for i in mini(IMPORTERS_MAX, deps.size()):
		_heat(int(deps[i][1]), attacker, victim, cause, commodity, si * float(deps[i][0]), obj, 0)



func _may_complain(c: int, culprit: int) -> bool:
	var cc: Country = gw.country_by_id(c)
	if cc == null or cc.is_player or not dp._alive(c) or c == culprit:
		return false
	if dp.at_war(c, culprit) or dp.allied(c, culprit) or dp.subject_of(c) == culprit or dp.subject_of(culprit) == c:
		return false
	return true



func _dep(c: Country, victim: int, res: String) -> float:
	var d: float = 0.0
	if gw.econ != null and gw.econ.trading(c.id, victim):
		d += 0.6
	if res != "" and gw.econ != null and gw.econ.need(c, res) > 0:
		d += 0.5
		if gw.econ.scarce_of(c).has(res):
			d += 0.3
	return d




func real_deficit(c: int, res: String) -> bool:
	var cc: Country = gw.country_by_id(c)
	if cc == null or gw.econ == null:
		return false
	var list: Array = [res] if res != "" else ["oil", "fuel", "metal", "food"]
	for r: String in list:
		if not Economy.TRADE_RES.has(r):
			continue
		if gw.econ.need(cc, r) > 0 and (gw.econ.scarce_of(cc).has(r) or _crisis_on(r)):
			return true
	return false


func _crisis_on(res: String) -> bool:
	if events.has("crisis:" + res):
		return true
	if _sup != null and is_instance_valid(_sup) and _sup.has_method("crises"):
		for cr: Variant in _sup.call("crises"):
			if cr is Dictionary and String((cr as Dictionary).get("commodity", "")) == res and gw.game_time - float((cr as Dictionary).get("since", gw.game_time)) >= CRISIS_LONG:
				return true
	return false


func _cause(kind: String, res: String, info: Dictionary) -> String:
	match kind:
		"neutral_sunk":
			return "neutral"
		"port_hit":
			return "oil" if res == "oil" or res == "fuel" or String(info.get("fac", "")) == "oil" else "port"
		"bridge_destroyed", "jam":
			return "bridge"
		"blockade_start":
			return "blockade"
		"oil_hit":
			return "oil"
	return "convoy"




func thread(from: int, to: int) -> Dictionary:
	for t: Dictionary in threads:
		if int(t["from"]) == from and int(t["to"]) == to:
			return t
	return {}


func thread_by_id(id: int) -> Dictionary:
	for t: Dictionary in threads:
		if int(t["id"]) == id:
			return t
	return {}



func _heat(from: int, to: int, vs: int, cause: String, res: String, sev: float, obj: String, value: int) -> void :
	var now: float = gw.game_time
	var t: Dictionary = thread(from, to)
	if t.is_empty():
		t = {"id": _id, "from": from, "to": to, "vs": vs, "cause": cause, "obj": obj, "res": res, "stage": -1, "heat": 0.0, "n": 0, 
			"dmg": 0, "made": now, "last": now, "st_t": -1000000000.0, "until": 0.0, "state": "open", "comply_until": 0.0, "ai_t": 0.0}
		_id += 1
		threads.append(t)
		_count("threads")
	else:
		_count("merged")
	if String(t["state"]) == "comply":


		if (vs == int(t["vs"]) or cause == String(t["cause"]) and cause == "neutral") and _same_family(cause, String(t["cause"]))\
		and now - float(t.get("promise_t", 0.0)) >= PROMISE_GRACE:
			_count("broken_by_" + cause)
			_broken(t)
		else:
			t["heat"] = minf(HEAT_MAX, float(t["heat"]) + sev * 0.5)
			t["ch"] = float(t.get("ch", 0.0)) + sev * 0.5
			t["last"] = now
			return
	t["heat"] = minf(HEAT_MAX, float(t["heat"]) + sev)
	t["n"] = int(t["n"]) + 1
	t["dmg"] = int(t["dmg"]) + maxi(0, value)
	t["last"] = now
	if sev >= 1.0 or String(t["cause"]) == cause:
		t["cause"] = cause
		t["obj"] = obj
		t["vs"] = vs
		if res != "":
			t["res"] = res
	_escalate(t)



func _escalate(t: Dictionary) -> void :
	if String(t["state"]) != "open":
		return
	var now: float = gw.game_time
	var h: float = float(t["heat"])
	var want: int = -1
	for i in HEAT_AT.size():
		if h >= float(HEAT_AT[i]):
			want = i
	var st: int = int(t["stage"])
	if want <= st:
		return
	if st >= 0 and now - float(t["st_t"]) < STAGE_GAP:
		return
	var nxt: int = mini(want, 1) if st < 0 else st + 1
	var from: int = int(t["from"])
	if st < 0 and now - float(_from_t.get(from, -1000000000.0)) < FROM_GAP:
		_count("suppressed_from")
		return
	var to: int = int(t["to"])
	var cto: Country = gw.country_by_id(to)
	var player: bool = cto != null and cto.is_player
	if nxt == 3:
		var P: Dictionary = dp._p(from)
		var ok: bool = real_deficit(from, String(t["res"])) and float(P["aggr"]) >= 0.45 and dp.war_allowed(from, to, true)\
		and now - _ult_t >= ULT_GAP and ( not player or now - _pult_t >= PLAYER_ULT_GAP)
		if not ok:
			if not t.has("ub"):
				t["ub"] = true
				_count("ult_blocked")
			return
	if not _can_emit(player, nxt):
		_count("suppressed_rate")
		return
	t["stage"] = nxt
	t["st_t"] = now
	_from_t[from] = now
	t["until"] = now + float(ANSWER_T[nxt])
	t["ai_t"] = now + AI_ANSWER_T
	_emits.append([now, player, nxt])
	_count(["notes", "threats", "demands", "ults"][nxt])
	if nxt == 3:
		_ult_t = now
		if player:
			_pult_t = now
	dp._reveal(from, to, true)
	_announce(t)


func _can_emit(player: bool, stage: int) -> bool:
	var now: float = gw.game_time
	var n: int = 0
	var np: int = 0
	for i in range(_emits.size() - 1, -1, -1):
		if now - float(_emits[i][0]) > WIN:
			_emits.remove_at(i)
			continue
		n += 1
		if bool(_emits[i][1]):
			np += 1
	if stage >= 3:
		return true
	if n >= NOTES_MAX + (NOTES_HI if stage >= 2 else 0):
		return false
	if player and np >= PLAYER_MAX + (PLAYER_HI if stage >= 2 else 0):
		return false
	return true



func demand_text(t: Dictionary) -> String:
	return Loc.msg(demand_msg(t))



func demand_msg(t: Dictionary) -> Array:
	var obj: String = String(t["obj"])
	var at: Variant = Loc.mk(" у г. %s", [obj]) if obj != "" else ""
	match String(t["cause"]):
		"convoy":
			return Loc.mk("прекратите атаки на наши конвои") if int(t["vs"]) == int(t["from"]) else Loc.mk("прекратите топить конвои с нашими грузами")
		"port":
			return Loc.mk("прекратите обстрелы порта %s", [obj])
		"bridge":
			return Loc.mk("прекратите удары по мостам%s", [at])
		"oil":
			return Loc.mk("прекратите удары по нефти%s", [at])
		"blockade":
			return Loc.mk("снимите блокаду порта %s", [obj])
		"neutral":
			return Loc.mk("прекратите топить наши суда")
		"crisis":
			return Loc.mk("прекратите удары по поставкам: %s в дефиците", [_nom(String(t["res"])).to_lower()]) if String(t["res"]) != "" else Loc.mk("прекратите срывать нашу торговлю")
	return Loc.mk("прекратите удары по торговле")



func conseq_code(t: Dictionary) -> String:
	return ["rel", "demand", "sanctions"][int(t["stage"])] if int(t["stage"]) >= 0 and int(t["stage"]) <= 2 else "war"



func conseq(t: Dictionary) -> String:
	match int(t["stage"]):
		0:
			return Loc.t("отношения")
		1:
			return Loc.t("требование")
		2:
			return Loc.t("санкции")
	return Loc.t("война")


func _announce(t: Dictionary) -> void :
	var st: int = int(t["stage"])
	var from: int = int(t["from"])
	var to: int = int(t["to"])
	var cto: Country = gw.country_by_id(to)
	var pl: bool = cto != null and cto.is_player
	var line: String = demand_text(t)
	if pl:
		var tail: String = ""
		match st:
			1:
				tail = Loc.t(" — иначе требование")
			2:
				tail = Loc.t(" — срок %d с, иначе санкции") % int(ANSWER_T[2])
			3:
				tail = Loc.t(" — иначе ВОЙНА")
		gw.say(int(t["to"]), Loc.mk("%s · %s: %s%s", [Loc.mk(String(STAGE_NAMES[st])), dp._cname(from), line, tail]))
		if gw.player != null and int(t["to"]) == gw.player.id:
			Sfx.ui("protest_note" if st < 2 else "call_to_arms")
		dp.pending_changed.emit()
	if st >= 2:
		var col: String = "alert_red" if st == 3 else "amber"
		var head: String = Loc.t("УЛЬТИМАТУМ") if st == 3 else Loc.t("ТРЕБОВАНИЕ")
		_news(Loc.msg(Loc.mk("%s: %s → %s · %s", [head, _up(from), _up(to), line.to_upper()])), col, 
			"thr%d:%d" % [int(t["id"]), st])






func item_to(id: int) -> int:
	var t: Dictionary = thread_by_id(id)
	return -1 if t.is_empty() else int(t["to"])


func answer(id: int, act: String) -> String:
	var t: Dictionary = thread_by_id(id)
	if t.is_empty() or int(t["stage"]) < 0 or String(t["state"]) != "open" or float(t["until"]) <= 0.0:
		return Loc.t("Нота устарела")
	match act:
		"stop", "accept":
			_promise(t)
		"pay":
			var why: String = _pay(t)
			if why != "":
				return why
		_:
			_refuse(t)
	dp.pending_changed.emit()
	return ""


func _promise(t: Dictionary) -> void :
	var now: float = gw.game_time
	t["state"] = "comply"
	t["promise_t"] = now
	t["ch"] = 0.0
	t["until"] = 0.0
	t["comply_until"] = now + COMPLY_T
	dp.add_opinion(int(t["from"]), int(t["to"]), 3)
	_count("promised")
	var cto: Country = gw.country_by_id(int(t["to"]))
	if cto != null and cto.is_player:
		gw.say(cto, Loc.t("Обещано %s: %s — %d мин. Нарушение = санкции%s") % [dp._cname(int(t["from"])), _promise_text(t), int(COMPLY_T / 60.0), 
			Loc.t(" и война") if int(t["stage"]) == 3 else ""])
	if String(t["cause"]) == "blockade" and _sup != null and is_instance_valid(_sup) and _sup.has_method("lift_blockade"):
		_sup.call("lift_blockade", int(t["to"]), int(t["vs"]))



func _promise_text(t: Dictionary) -> String:
	return Loc.msg(_promise_msg(t))



func _promise_msg(t: Dictionary) -> Array:
	var obj: String = String(t["obj"])
	var at: Variant = Loc.mk(" у г. %s", [obj]) if obj != "" else ""
	match String(t["cause"]):
		"convoy":
			return Loc.mk("не атаковать их конвои") if int(t["vs"]) == int(t["from"]) else Loc.mk("не топить конвои с их грузами")
		"port":
			return Loc.mk("не бить порт %s", [obj])
		"bridge":
			return Loc.mk("не бить мосты%s", [at])
		"oil":
			return Loc.mk("не бить нефть%s", [at])
		"blockade":
			return Loc.mk("снять блокаду %s", [obj])
		"neutral":
			return Loc.mk("не топить их суда")
	return Loc.mk("не бить поставки")



func compensation(t: Dictionary) -> Array:
	var st: int = clampi(int(t["stage"]), 0, 3)
	var base: float = float(int(t["dmg"])) * 0.4 + 180.0 * float(int(t["n"]))
	var m: int = int(clampf(base * float(COMP_MUL[st]), 200.0, 4000.0) / 50.0) * 50
	var cto: Country = gw.country_by_id(int(t["to"]))
	if cto != null and cto.is_player:
		m = mini(m, maxi(200, int(float(maxi(cto.money, 1000)) * 0.25 / 50.0) * 50))
	var res: String = String(t["res"])
	var n: int = 0
	if Economy.TRADE_RES.has(res) and gw.econ != null:
		n = maxi(1, ceili(float(m) / float(maxi(1, gw.econ.market_price(res)))))
	return [m, res if n > 0 else "", n]


func _pay(t: Dictionary) -> String:
	var c: Array = compensation(t)
	var to: int = int(t["to"])
	var from: int = int(t["from"])
	var cto: Country = gw.country_by_id(to)
	if cto == null:
		return Loc.t("Нет такого")
	var paid: String = ""
	if cto.money >= int(c[0]):
		dp._move(to, from, "money", int(c[0]))
		paid = _num(int(c[0]))
	elif String(c[1]) != "" and int(cto.get(String(c[1]))) >= int(c[2]):
		dp._move(to, from, String(c[1]), int(c[2]))
		paid = "%s ×%d" % [String(Economy.RES_NAMES.get(String(c[1]), "")).to_lower(), int(c[2])]
	else:
		return Loc.t("Не хватает: нужно %d денег") % int(c[0])
	dp.add_opinion(from, to, 4 + 2 * int(t["stage"]))
	_count("paid")
	if cto.is_player:
		gw.say(cto, Loc.mk("Компенсация %s: %s. Претензии сняты", [Loc.name(dp._cname(from)), paid]))
		Sfx.ui("aid_sent")
	elif int(t["stage"]) >= 2:
		_news(Loc.msg(Loc.mk("%s ВЫПЛАТИЛА КОМПЕНСАЦИЮ %s", [_up(to), _up(from)])), "grass_light", "pay%d" % int(t["id"]))
	_close(t)
	return ""


func _refuse(t: Dictionary) -> void :
	var st: int = int(t["stage"])
	var from: int = int(t["from"])
	var to: int = int(t["to"])
	t["until"] = 0.0
	_count("refused")
	match st:
		0:
			dp.add_opinion(from, to, -4)
			t["heat"] = float(t["heat"]) + 1.0
		1:
			dp.add_opinion(from, to, -8)
			t["heat"] = maxf(float(t["heat"]) + 1.5, float(HEAT_AT[2]) * 1.25)
		2:
			_sanction(t, Loc.t("отказ выполнить требование"))
		_:
			if dp.war_allowed(from, to, true):
				_count("wars")
				dp.declare_war(from, to, "ультиматум: %s" % [Loc.src(demand_msg(t))])
				_close(t)
				return
			_sanction(t, Loc.t("отказ на ультиматум"))
	var cto: Country = gw.country_by_id(to)
	if cto != null and cto.is_player and st < 2:
		gw.say(cto, Loc.mk("%s: отказ принят к сведению. Следующий удар — %s", [Loc.name(dp._cname(from)), Loc.t("требование") if st == 1 else Loc.t("угроза")]))
	_escalate(t)




func _sanction(t: Dictionary, why: String) -> void :
	var from: int = int(t["from"])
	var to: int = int(t["to"])
	_count("sanctions")
	dp.add_opinion(from, to, -12)
	var mat: String = ""
	var trd: Variant = gw.econ.get("trd") if gw.econ != null else null
	if not dp.embargoed(from, to):
		var first: bool = trd != null and trd.has_method("sanctions_by") and (trd.sanctions_by(from, to) as Array).is_empty() and not bool(t.get("sanct1", false))
		if first and trd.has_method("impose_sanction"):
			var r0: String = String(t.get("res", ""))
			if r0 != "" and String(trd.can_sanction(from, to, r0, true)) != "":
				r0 = ""
			if String(trd.impose_sanction(from, to, r0)) == "":
				t["sanct1"] = true
				var got: Array = trd.sanctions_by(from, to)
				mat = String(got[got.size() - 1]) if not got.is_empty() else ""
				_count("sanct_material")
		if mat == "":
			dp.set_embargo(from, to, true)
	var coal: Array = []
	for o: Dictionary in threads:
		var f2: int = int(o["from"])
		if int(o["to"]) == to and f2 != from and int(o["stage"]) >= 1 and not dp.embargoed(f2, to):
			if mat != "" and trd != null and trd.has_method("impose_sanction"):
				if String(trd.impose_sanction(f2, to, "")) == "":
					_count("coal_material")
				continue
			coal.append(f2)
	for c: Country in gw.countries:
		if c.id != from and c.id != to and not c.is_player and dp._alive(c.id) and dp.relation(c.id, from) >= 40:
			dp.add_opinion(c.id, to, -6)
	for f3: int in coal:
		_quiet_embargo(f3, to)
	if not coal.is_empty():
		_count("coalitions")
		_news(Loc.msg(Loc.mk("КОАЛИЦИЯ САНКЦИЙ ПРОТИВ %s: %d СТРАН", [_up(to), coal.size() + 1])), "alert_red", "coal:%d" % to)
	var cto: Country = gw.country_by_id(to)
	if cto != null and cto.is_player:
		if mat != "":
			gw.say(cto, Loc.mk("САНКЦИИ: %s — %s (%s). Следующий отказ — эмбарго", [Loc.name(dp._cname(from)), String(RES_NOM.get(mat, mat.to_upper())), why]))
		else:
			gw.say(cto, Loc.mk("САНКЦИИ: %s закрывает торговлю (%s)%s", [Loc.name(dp._cname(from)), why, (Loc.t(", с ней ещё %d") % coal.size()) if not coal.is_empty() else ""]))
	t["heat"] = float(HEAT_AT[2])




static func _same_family(a: String, b: String) -> bool:
	if b == "crisis" or a == b:
		return true
	var fam: Dictionary = {"convoy": "sea", "neutral": "sea", "port": "port", "oil": "port", "bridge": "bridge", "blockade": "blockade", "crisis": "all"}
	return String(fam.get(a, a)) == String(fam.get(b, b))



func _quiet_embargo(f: int, to: int) -> void :
	var k: String = "%d>%d" % [f, to]
	if dp.embargo.has(k) or f == to or not dp._alive(f) or not dp._alive(to):
		return
	dp.embargo[k] = gw.game_time
	if gw.econ != null and gw.econ.trading(f, to):
		gw.econ.set_trade(f, to, false)
	dp.add_opinion(f, to, -20)
	dp._count("embargo")
	dp._reveal(f, to, true)
	gw.relations_changed.emit()



func _broken(t: Dictionary) -> void :
	var from: int = int(t["from"])
	var to: int = int(t["to"])
	var st: int = int(t["stage"])
	_count("broken")
	t["state"] = "open"
	t["comply_until"] = 0.0
	dp.add_opinion(from, to, -20)
	_news(Loc.msg(Loc.mk("%s НАРУШИЛА ОБЕЩАНИЕ: %s", [_up(to), _promise_text(t).to_upper()])), "alert_red", "brk%d" % int(t["id"]))
	if st >= 3 and dp.war_allowed(from, to, true):
		_count("wars")
		dp.declare_war(from, to, "нарушено обещание: %s" % [Loc.src(_promise_msg(t))])
		_close(t)
		return
	_sanction(t, Loc.t("нарушено обещание"))
	t["stage"] = maxi(st, 1)
	t["st_t"] = -1000000000.0
	t["heat"] = maxf(float(t["heat"]), float(HEAT_AT[2]))


func _kept(t: Dictionary) -> void :
	var from: int = int(t["from"])
	var to: int = int(t["to"])
	_count("kept")
	if float(t.get("ch", 0.0)) >= KEPT_OPEN:


		dp.add_opinion(from, to, 3)
		t["state"] = "open"
		t["comply_until"] = 0.0
		t["heat"] = maxf(float(t["heat"]) * 0.5, float(t["ch"]))
		t["ch"] = 0.0
		t["st_t"] = gw.game_time - STAGE_GAP
		_count("kept_open")
		dp.pending_changed.emit()
		_escalate(t)
		return
	dp.add_opinion(from, to, 8)
	var cto: Country = gw.country_by_id(to)
	if cto != null and cto.is_player:
		gw.say(cto, Loc.mk("%s: обещание выполнено, претензии сняты (+8)", [Loc.name(dp._cname(from))]))
		Sfx.ui("treaty_signed")
	elif int(t["stage"]) >= 2:
		_news(Loc.msg(Loc.mk("НАПРЯЖЁННОСТЬ СПАЛА: %s И %s", [_up(from), _up(to)])), "grass_light", "kept%d" % int(t["id"]))
	_close(t)


func _close(t: Dictionary) -> void :
	threads.erase(t)
	_count("closed")
	dp.pending_changed.emit()



func _ai_answer(t: Dictionary) -> void :
	var from: int = int(t["from"])
	var to: int = int(t["to"])
	var P: Dictionary = dp._p(to)
	var st: int = int(t["stage"])
	var ratio: float = dp.strength(from) / maxf(1.0, dp.strength(to))
	var r: float = float(Hash32.h2(int(t["id"]), st, 977) % 1000) / 1000.0
	var cto: Country = gw.country_by_id(to)
	var comp: Array = compensation(t)
	var rich: bool = cto != null and cto.money >= int(comp[0]) * 3
	var p_stop: float = 0.25 + float(P["caution"]) * 0.35 + clampf(ratio - 0.8, 0.0, 1.0) * 0.4 - float(P["aggr"]) * 0.25 + 0.12 * float(st)
	if st == 3 and ratio > 0.7:
		p_stop += 0.25
	if r < clampf(p_stop, 0.05, 0.92):
		answer(int(t["id"]), "stop")
	elif rich and r < clampf(p_stop + float(P["trade"]) * 0.35, 0.0, 0.97):
		answer(int(t["id"]), "pay")
	else:
		answer(int(t["id"]), "refuse")




func update(dt: float) -> void :
	_t += dt
	if _t < TICK:
		return
	var step: float = _t
	_t = 0.0
	_wire()
	var now: float = gw.game_time
	var k: float = pow(0.5, step / HEAT_HALF)
	for i in range(threads.size() - 1, -1, -1):
		var t: Dictionary = threads[i]
		var from: int = int(t["from"])
		var to: int = int(t["to"])
		if not dp._alive(from) or not dp._alive(to) or dp.at_war(from, to) or dp.allied(from, to):
			threads.remove_at(i)
			dp.pending_changed.emit()
			continue
		var state: String = String(t["state"])
		t["heat"] = float(t["heat"]) * k
		if state == "comply":
			var blk: bool = String(t["cause"]) == "blockade" and blockades.has("%d>%d" % [to, int(t["vs"])])
			if String(t["cause"]) == "blockade" and not blk and now + 1.0 < float(t["comply_until"]):
				t["comply_until"] = now
			if now >= float(t["comply_until"]):
				if blk:
					_broken(t)
				else:
					_kept(t)
			continue
		if float(t["until"]) > 0.0:
			var cto: Country = gw.country_by_id(to)
			if cto != null and not cto.is_player and now >= float(t["ai_t"]):
				_ai_answer(t)
				continue
			if now >= float(t["until"]):
				_count("expired")
				if int(t["stage"]) >= 2:
					_refuse(t)
				else:
					t["until"] = 0.0
					dp.add_opinion(from, to, -3)
					dp.pending_changed.emit()
				continue
		var stg: int = int(t["stage"])
		if stg >= 1 and float(t["until"]) <= 0.0 and float(t["heat"]) < float(HEAT_AT[stg]) * 0.5 and now - float(t["st_t"]) >= DESCALE_T:
			t["stage"] = stg - 1
			t["st_t"] = now
			_count("descaled")
			dp.pending_changed.emit()
		_escalate(t)
		if float(t["until"]) <= 0.0 and float(t["heat"]) < CLOSE_HEAT and now - float(t["last"]) >= QUIET_T:
			threads.remove_at(i)
			_count("cooled")
			dp.pending_changed.emit()
	_last_t += step
	if _last_t >= LAST_DT:
		_last_t = 0.0
		_lasting()
	_events_tick()
	for j in range(_inc_log.size() - 1, -1, -1):
		if now - float(_inc_log[j][0]) > 360.0:
			_inc_log.remove_at(j)



func _lasting() -> void :
	for bk: String in blockades.keys():
		var ab: PackedStringArray = bk.split(">")
		var by: int = int(ab[0])
		var own: int = int(ab[1])
		if not dp._alive(by) or not dp._alive(own):
			blockades.erase(bk)
			continue
		if restrained(by, own, "blockade"):
			continue
		var b: Dictionary = blockades[bk]
		var n: int = 0
		for c: Country in gw.countries:
			if n >= IMPORTERS_MAX:
				break
			if c.is_player or c.id == by or c.id == own or not _may_complain(c.id, by) or dp.at_war(c.id, own):
				continue
			var d: float = _dep(c, own, String(b.get("res", "")))
			if d > 0.0:
				_heat(c.id, by, own, "blockade", String(b.get("res", "")), 0.5 * d, String(b["obj"]), 0)
				n += 1
		if _may_complain(own, by):
			_heat(own, by, own, "blockade", String(b.get("res", "")), LAST_BLK, String(b["obj"]), 0)
	if _sup == null or not is_instance_valid(_sup) or not _sup.has_method("crises"):
		return
	var now: float = gw.game_time
	for cr: Variant in _sup.call("crises"):
		if not (cr is Dictionary):
			continue
		var d2: Dictionary = cr
		var res: String = String(d2.get("commodity", ""))
		if now - float(d2.get("since", now)) < CRISIS_LONG:
			continue
		if res == "":
			_route_crisis(String(d2.get("route", "")), float(d2.get("level", 0.5)))
			continue
		var cul: Array = _culprit(res)
		if int(cul[0]) <= 0:
			continue
		var n2: int = 0
		for c2: Country in gw.countries:
			if n2 >= IMPORTERS_MAX:
				break
			if c2.is_player or c2.id == int(cul[0]) or not _may_complain(c2.id, int(cul[0])) or gw.econ == null or gw.econ.need(c2, res) <= 0:
				continue
			_heat(c2.id, int(cul[0]), int(cul[1]), "crisis", res, 0.6 * clampf(float(d2.get("level", 0.5)) * 1.5, 0.5, 1.5), "", 0)
			n2 += 1



func _route_crisis(route: String, level: float) -> void :
	var ab: PackedStringArray = route.split(":")
	if ab.size() != 2:
		return
	for i in 2:
		var me: int = int(ab[i])
		var other: int = int(ab[1 - i])
		var cnt: Dictionary = {}
		for e: Array in _inc_log:
			if int(e[2]) == me or int(e[2]) == other:
				cnt[int(e[1])] = int(cnt.get(int(e[1]), 0)) + 1
		var best: int = 0
		var bn: int = 1
		for a: int in cnt:
			if int(cnt[a]) > bn and a != me and a != other:
				bn = int(cnt[a])
				best = a
		if best > 0 and _may_complain(me, best):
			_heat(me, best, other, "crisis", "", 0.6 * clampf(level * 1.5, 0.5, 1.5), "", 0)



func _culprit(res: String) -> Array:
	var cnt: Dictionary = {}
	var vic: Dictionary = {}
	for e: Array in _inc_log:
		if String(e[3]) == res or res == "":
			cnt[int(e[1])] = int(cnt.get(int(e[1]), 0)) + 1
			vic[int(e[1])] = int(e[2])
	var best: int = 0
	var bn: int = 1
	for a: int in cnt:
		if int(cnt[a]) > bn:
			bn = int(cnt[a])
			best = a
	return [best, int(vic.get(best, 0))]




func _event_on(key: String, kind: String, res: String, pos: Vector2, title: Variant, col: String) -> void :
	var now: float = gw.game_time
	if events.has(key):
		events[key]["last"] = now
		return
	events[key] = {"kind": kind, "title": title, "res": res, "since": now, "last": now, "pos": pos}
	_count("ev_" + kind)
	if col != "":
		_news(Loc.msg(title), col, "ev:" + key)


func _event_off(key: String, title: Variant, col: String) -> void :
	if not events.has(key):
		return
	events.erase(key)
	if col != "":
		_news(Loc.msg(title), col, "evoff:" + key)


func _events_tick() -> void :
	var now: float = gw.game_time
	for i in range(_sinks.size() - 1, -1, -1):
		if now - float(_sinks[i]) > INS_CALM:
			_sinks.remove_at(i)
	var recent: int = 0
	for s: float in _sinks:
		if now - s <= INS_T:
			recent += 1
	if recent >= INS_N:
		_event_on("ins", "insurance", "", Vector2.ZERO, Loc.mk("СТРАХОВКА ФРАХТА ВЫРОСЛА · %d СУДНА ЗА 3 МИН", [recent]), "amber")
	elif events.has("ins") and (_sinks.is_empty() or now - float(_sinks[_sinks.size() - 1]) >= INS_CALM) and _risk_low():
		_event_off("ins", Loc.mk("СТРАХОВКА ФРАХТА СНИЖЕНА: МОРЕ СПОКОЙНЕЕ"), "grass_light")
	for key: String in events.keys():
		var e: Dictionary = events[key]
		match String(e["kind"]):
			"jam":
				if now - float(e["last"]) > 120.0:
					events.erase(key)
			"crisis":
				if _sup != null and is_instance_valid(_sup) and _sup.has_method("crises") and now - float(e["since"]) > 30.0:
					var on: bool = false
					for cr: Variant in _sup.call("crises"):
						if cr is Dictionary and String((cr as Dictionary).get("commodity", "")) == String(e["res"]):
							on = true
					if not on:
						_event_off(key, "", "")
				elif (_sup == null or not is_instance_valid(_sup)) and now - float(e["last"]) > 300.0:
					_event_off(key, Loc.mk("ЦЕНЫ НА %s СТАБИЛИЗИРОВАЛИСЬ", [Loc.mk(_nom(String(e["res"])))]), "grass_light")


func _risk_low() -> bool:
	if _sup == null or not is_instance_valid(_sup) or not _sup.has_method("risk"):
		return true
	var s: float = 0.0
	for r: String in ["oil", "goods", "metal", "food"]:
		s += float(_sup.call("risk", r))
	return s / 4.0 < 0.35



func world_events() -> Array:
	var out: Array = []
	for key: String in events:
		var e: Dictionary = events[key]
		out.append({"kind": e["kind"], "title": Loc.msg(e["title"]), "res": e["res"], "since": e["since"]})
	return out


func _news(text: String, col: String, key: String) -> void :
	var now: float = gw.game_time
	if now - float(_news_key.get(key, -1000000000.0)) < NEWS_KEY_GAP:
		return
	for i in range(_news_t.size() - 1, -1, -1):
		if now - float(_news_t[i]) > WIN:
			_news_t.remove_at(i)
	var serious: bool = col == "alert_red"
	if not serious and (_news_t.size() >= NEWS_MAX or ( not _news_t.is_empty() and now - float(_news_t[_news_t.size() - 1]) < NEWS_GAP)):
		_count("news_dropped")
		return
	_news_key[key] = now
	_news_t.append(now)
	_count("news")
	gw.news.emit(text, col)






func restrained(a: int, vs: int, cause: String = "") -> bool:
	for t: Dictionary in threads:
		if int(t["to"]) == a and String(t["state"]) == "comply" and (int(t["vs"]) == vs or int(t["vs"]) == 0 and int(t["from"]) == vs)\
		and (cause == "" or String(t["cause"]) == cause or String(t["cause"]) == "crisis"):
			return true
	return false



func pending(now: float) -> Array:
	var out: Array = []
	var p: Country = gw.player
	if p == null:
		return out
	for t: Dictionary in threads:
		if int(t["to"]) != p.id or float(t["until"]) <= 0.0 or String(t["state"]) != "open" or int(t["stage"]) < 0:
			continue
		var st: int = int(t["stage"])
		var comp: Array = compensation(t)
		var from: int = int(t["from"])
		var opts: Array = [{"act": "stop", "label": Loc.t("ПРЕКРАТИТЬ")}, {"act": "pay", "label": Loc.t("КОМПЕНС. · %s") % _num(int(comp[0]))}, {"act": "refuse", "label": Loc.t("ОТКАЗАТЬ")}]
		if st == 0:
			opts = [{"act": "stop", "label": Loc.t("ПРЕКРАТИТЬ")}, {"act": "refuse", "label": Loc.t("ОТКАЗАТЬ")}]
		var line: String = demand_text(t)
		out.append({"id": "e%d" % int(t["id"]), "from": from, "kind": "react", "icon": String(STAGE_ICONS[st]), "stage": st, 
			"stage_name": String(STAGE_NAMES[st]), "cause": String(t["cause"]), "cause_icon": String(CAUSE_ICONS.get(String(t["cause"]), "icon_cause_convoy")), 
			"vs": int(t["vs"]), "n": int(t["n"]), "line": line, "conseq": conseq_code(t), "comp": int(comp[0]), "comp_res": String(comp[1]), "comp_n": int(comp[2]), 
			"text": line.left(1).to_upper() + line.substr(1), 
			"lane_title": "%s · %s" % [String(STAGE_NAMES[st]), dp._cname(from).to_upper()], "lane_sub": Loc.t("%s · отказ = %s") % [line, conseq(t)], 
			"lane_style": "red" if st >= 2 else "amber", "deadline": float(t["until"]), "left": maxf(0.0, float(t["until"]) - now), 
			"total": float(ANSWER_T[st]), "options": opts})
	return out





func tension(me: int, cid: int) -> Dictionary:
	var best: Dictionary = {}
	var bs: float = -1.0
	for t: Dictionary in threads:
		var st: int = int(t["stage"])
		if st < 0:
			continue
		var f: int = int(t["from"])
		var o: int = int(t["to"])
		var mine: bool = (f == cid and o == me) or (f == me and o == cid)
		if not mine and f != cid and o != cid:
			continue
		var sc: float = float(st) + (10.0 if mine else 0.0) + (0.5 if String(t["state"]) == "comply" else 0.0)
		if sc > bs:
			bs = sc
			best = t
	if best.is_empty():
		return {}
	var t2: Dictionary = best
	var st2: int = int(t2["stage"])
	var f2: int = int(t2["from"])
	var o2: int = int(t2["to"])
	var mine2: bool = (f2 == cid and o2 == me) or (f2 == me and o2 == cid)
	var comply: bool = String(t2["state"]) == "comply"
	var who: String = ""
	if not mine2:
		who = ("%s → %s: " % [Loc.name(dp._cname(f2)), Loc.name(dp._cname(o2))])
	var text: String = ""
	var body: String = ""
	if comply:
		body = _promise_text(t2)
		text = Loc.t("%sОБЕЩАНИЕ: %s") % [who, body]
	else:
		body = demand_text(t2)
		text = Loc.t("%s%s: %s") % [who, Loc.t(String(STAGE_NAMES[st2])), body]
	var dl: float = float(t2["comply_until"]) if comply else float(t2["until"])
	return {"text": text, "body": body, "stage": st2, "state": String(t2["state"]), "deadline": dl, "total": COMPLY_T if comply else float(ANSWER_T[st2]), 
		"icon": String(STAGE_ICONS[st2]), "cause_icon": String(CAUSE_ICONS.get(String(t2["cause"]), "icon_cause_convoy")), "mine": mine2, "n": int(t2["n"])}



func sig() -> String:
	var s: String = ""
	for t: Dictionary in threads:
		if int(t["stage"]) >= 0:
			s += "%d:%d:%s:%s;" % [int(t["id"]), int(t["stage"]), String(t["state"]), float(t["until"]) > 0.0]
	return s




static func _num(v: int) -> String:
	var s: String = str(absi(v))
	var out: String = ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("−" if v < 0 else "") + s + out


func _count(k: String, n: int = 1) -> void :
	counters[k] = int(counters.get(k, 0)) + n


func _up(id: int) -> String:
	return dp._cname(id).to_upper()


func _gen(res: String) -> String:
	return String(RES_GEN.get(res, "ПОСТАВОК"))


func _nom(res: String) -> String:
	return String(RES_NOM.get(res, "ТОВАРЫ"))


func _why(info: Dictionary) -> String:
	var r: String = String(info.get("reason_ru", info.get("reason", "")))
	return (" · " + r) if r != "" else ""



func _obj(cause: String, victim: int, pos: Vector2, info: Dictionary) -> String:
	if cause == "neutral":
		return ""
	if cause == "port" or cause == "blockade" or cause == "bridge" or cause == "oil":
		return _place(pos, info)
	return dp._cname(victim) if victim > 0 else ""



func _place(pos: Vector2, info: Dictionary) -> String:
	for k: String in ["name", "city", "port_name", "place"]:
		if String(info.get(k, "")) != "":
			return String(info[k])
	var best: String = ""
	var bd: float = INF
	var cp: = pos / float(GameWorld.CELL)
	for city: City in gw.cities:
		if city == null:
			continue
		var d: float = Vector2(city.center).distance_squared_to(cp)
		if d < bd:
			bd = d
			best = city.name
	return best




func save_state() -> Dictionary:
	var bl: Dictionary = {}
	for k: String in blockades:
		bl[k] = (blockades[k] as Dictionary).duplicate()
	var ev: Dictionary = {}
	for k2: String in events:
		var e: Dictionary = (events[k2] as Dictionary).duplicate()
		e["pos"] = [float((e["pos"] as Vector2).x), float((e["pos"] as Vector2).y)]
		ev[k2] = e
	return {"threads": threads.duplicate(true), "events": ev, "blockades": bl, "counters": counters.duplicate(), "id": _id, 
		"emits": _emits.duplicate(true), "news_t": _news_t.duplicate(), "from_t": _from_t.duplicate(), "ult_t": _ult_t, "pult_t": _pult_t, 
		"sinks": _sinks.duplicate()}


func load_state(d: Dictionary) -> void :
	threads = []
	for v: Variant in (d.get("threads", []) as Array):
		if not (v is Dictionary):
			continue
		var s: Dictionary = v
		var f: int = int(s.get("from", 0))
		var o: int = int(s.get("to", 0))
		if gw.country_by_id(f) == null or gw.country_by_id(o) == null or f == o:
			continue
		var state: String = String(s.get("state", "open"))
		if state != "open" and state != "comply":
			state = "open"
		threads.append({"id": int(s.get("id", 0)), "from": f, "to": o, "vs": int(s.get("vs", 0)), "cause": String(s.get("cause", "convoy")), 
			"obj": String(s.get("obj", "")), "res": String(s.get("res", "")), "stage": clampi(int(s.get("stage", -1)), -1, 3), 
			"heat": clampf(float(s.get("heat", 0.0)), 0.0, 50.0), "n": maxi(0, int(s.get("n", 0))), "dmg": maxi(0, int(s.get("dmg", 0))), 
			"made": float(s.get("made", 0.0)), "last": float(s.get("last", 0.0)), "st_t": float(s.get("st_t", -1000000000.0)), 
			"until": maxf(0.0, float(s.get("until", 0.0))), "state": state, "comply_until": float(s.get("comply_until", 0.0)), 
			"ai_t": float(s.get("ai_t", 0.0)), "promise_t": float(s.get("promise_t", 0.0)), "ch": float(s.get("ch", 0.0))})
	events = {}
	var ev: Dictionary = d.get("events", {})
	for k: Variant in ev:
		var e: Dictionary = ev[k]
		var pa: Array = e.get("pos", [0.0, 0.0]) if e.get("pos") is Array else [0.0, 0.0]
		events[String(k)] = {"kind": String(e.get("kind", "")), "title": e.get("title", "") if Loc.is_msg(e.get("title", "")) else String(e.get("title", "")), "res": String(e.get("res", "")), 
			"since": float(e.get("since", 0.0)), "last": float(e.get("last", 0.0)), "pos": Vector2(float(pa[0]), float(pa[1])) if pa.size() >= 2 else Vector2.ZERO}
	blockades = {}
	var bl: Dictionary = d.get("blockades", {})
	for k2: Variant in bl:
		var b: Dictionary = bl[k2]
		blockades[String(k2)] = {"since": float(b.get("since", 0.0)), "obj": String(b.get("obj", "")), "t": float(b.get("t", 0.0)), "res": String(b.get("res", ""))}
	counters = {}
	var ct: Dictionary = d.get("counters", {})
	for k3: Variant in ct:
		counters[String(k3)] = int(ct[k3])
	_id = maxi(1, int(d.get("id", 1)))
	for t: Dictionary in threads:
		_id = maxi(_id, int(t["id"]) + 1)
	_emits = []
	for e2: Variant in (d.get("emits", []) as Array):
		if e2 is Array and (e2 as Array).size() >= 3:
			_emits.append([float(e2[0]), bool(e2[1]), int(e2[2])])
	_news_t = []
	for x: Variant in (d.get("news_t", []) as Array):
		_news_t.append(float(x))
	_from_t = {}
	var ft: Dictionary = d.get("from_t", {})
	for k4: Variant in ft:
		_from_t[int(k4)] = float(ft[k4])
	_ult_t = float(d.get("ult_t", -1000000000.0))
	_pult_t = float(d.get("pult_t", -1000000000.0))
	_sinks = []
	for y: Variant in (d.get("sinks", []) as Array):
		_sinks.append(float(y))
