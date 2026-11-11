class_name Protect
extends RefCounted














const HIT_DRONE: int = 0
const HIT_JET: int = 1
const HIT_CRUISE: int = 2
const HIT_BALLISTIC: int = 3
const HIT_HYPER: int = 4
const HIT_KAB: int = 5

const BLAST_R: Array = [3, 7, 3, 7, 7, 4]


const ELIGIBLE_NAMES: Array = ["REFINERY", "POWER_PLANT", "CIV_FACTORY", "DRONE_FACTORY", "MISSILE_FACTORY", "OIL_RIG", "PORT"]


const NET_MAX: int = 3
const NET_CHANCE: Array = [0.0, 0.35, 0.5, 0.65]
const NET_JET_MULT: float = 0.5
const NET_CATCHES: Array = [0, 1, 1, 2]
const NET_COST: Array = [{}, {"money": 400, "metal": 5}, {"money": 900, "metal": 10}, {"money": 1800, "metal": 20}]
const NET_TIME: Array = [0.0, 15.0, 20.0, 30.0]
const NET_REPAIR_SHARE: float = 0.4
const NET_REPAIR_TIME: float = 12.0




const CONC_MAX: int = 3
const CONC_COST: Array = [{}, {"money": 1000, "metal": 10, "wood": 8}, {"money": 2200, "metal": 20, "wood": 15}, {"money": 4000, "metal": 35, "wood": 25}]
const CONC_TIME: Array = [0.0, 30.0, 45.0, 60.0]
const CONC_CHARGES: Array = [[0, 0], [1, 2], [2, 3], [2, 3]]
const CONC_LAST_HALF: Array = [false, false, false, true]
const CONC_HALF_MULT: float = 0.5
const CONC_HYPER_CHANCE: float = 0.5
const CONC_DRONE_MULT: Array = [1.0, 1.0, 0.75, 0.75]
const CONC_REBUILD_SHARE: float = 0.6
const CONC_REBUILD_TIME_SHARE: float = 0.6

const SPARE_TTL: float = 3.0
const TICK_DT: float = 0.5
const MSG_GAP: float = 2.0




const AI_DT: float = 6.0
const AI_GAP: float = 45.0
const AI_FLOOR: int = 300
const AI_FLOOR_CAUTION: int = 400
const AI_SHARE: float = 0.12
const AI_SHARE_WAR: float = 0.2
const AI_NET_KINDS: Array = ["REFINERY", "POWER_PLANT"]
const AI_NET_KINDS2: Array = ["MISSILE_FACTORY", "DRONE_FACTORY"]
const AI_CONC_KINDS: Array = ["REFINERY", "POWER_PLANT", "MISSILE_FACTORY"]
const AI_DRONE_MORE: int = 3
const AI_DRONE_MAX: int = 8
const AI_CONC_L2_EXTRA: int = 4

const S_NONE: int = 0
const S_BUILDING: int = 1
const S_OK: int = 2
const S_BROKEN: int = 3
const NET_STATES: Array = ["none", "building", "ok", "torn"]
const CONC_STATES: Array = ["none", "building", "ok", "broken"]

var gw: GameWorld



var st: Dictionary = {}
var ver: int = 0
var hits: Dictionary = {}
var ai_spent: Dictionary = {}
var stats: Dictionary = {"caught": 0, "absorbed": 0, "half": 0, "torn": 0, "broken": 0, "through": 0, "splash": 0, "captured": 0}


var _hit_q: Array = []
const HIT_MSG_GAP: float = 20.0
const HIT_CHECK: float = 0.4
const HIT_WEAPON: Array = ["ударным дроном", "реактивным БПЛА", "крылатой ракетой", "баллистической ракетой", "гиперзвуковой ракетой", "КАБ"]

const OWN_WEAPON: Array = ["дронов", "реактивных БПЛА", "КР", "ракеты", "гиперзвука", "КАБ"]

const LOC_OWN_HEAD: Array = ["Наш удар дронов", "Наш удар реактивных БПЛА", "Наш удар КР", "Наш удар ракеты", "Наш удар гиперзвука", "Наш удар КАБ"]
const OWN_WINDOW: float = 2.5
const AD_COUNTERS: Array = [
	[Facility.Kind.AD_MFG, Facility.Kind.AD_SPAAG, Facility.Kind.AD_EW, Facility.Kind.AD_INT, Facility.Kind.AD_SAM], 
	[Facility.Kind.AD_SPAAG, Facility.Kind.AD_SAM, Facility.Kind.AD_INT], 
	[Facility.Kind.AD_SPAAG, Facility.Kind.AD_SAM, Facility.Kind.AD_PATRIOT, Facility.Kind.AD_INT], 
	[Facility.Kind.AD_PATRIOT, Facility.Kind.AD_SAM], 
	[Facility.Kind.AD_PATRIOT], 
	[Facility.Kind.AD_SAM, Facility.Kind.AD_SPAAG], 
]
const AD_TIP_NAME: Dictionary = {Facility.Kind.AD_MFG: "мобильную группу", Facility.Kind.AD_SPAAG: "ЗСУ «Шершень»", Facility.Kind.AD_SAM: "ЗРК «Купол»", 
	Facility.Kind.AD_PATRIOT: "ЗРК «Щит»", Facility.Kind.AD_INT: "дроны-перехватчики", Facility.Kind.AD_EW: "РЭБ"}
const AD_TIP_NOM: Dictionary = {Facility.Kind.AD_MFG: "мобильная группа"}
const AD_LATE: Dictionary = {Facility.Kind.AD_MFG: "мобильная группа не успела", Facility.Kind.AD_SPAAG: "«Шершень» не успел", Facility.Kind.AD_SAM: "«Купол» не успел", 
	Facility.Kind.AD_PATRIOT: "«Щит» не успел", Facility.Kind.AD_INT: "перехватчики не успели", Facility.Kind.AD_EW: "РЭБ не помог"}
var _own_q: Array = []
var _own_buf: Array = []
var _own_buf_t: float = -1.0
var _own_down: Dictionary = {}
var _tip_n: int = 0
var _spare: Array = []
var _acc: float = 0.0
var _ai_acc: float = 0.0
var _msg_t: Dictionary = {}
var _ai_next: Dictionary = {}
var _kinds: Array[int] = []


func _init(world: GameWorld) -> void :
	gw = world
	for n: String in ELIGIBLE_NAMES:
		if Facility.Kind.has(n):
			_kinds.append(int(Facility.Kind[n]))
	ProtectLayer.ensure(gw)




func eligible(f: Facility) -> bool:
	return f != null and f.parent == null and not f.is_line() and _kinds.has(f.kind)



func info(f: Facility) -> Dictionary:
	var s: Dictionary = st.get(f.id, {}) if f != null else {}
	var nl: int = int(s.get("nl", 0))
	var ns: int = int(s.get("ns", S_NONE))
	var cl: int = int(s.get("cl", 0))
	var cs: int = int(s.get("cs", S_NONE))
	return {
		"net_lvl": nl, "net_state": NET_STATES[ns], "net_t": float(s.get("nt", 0.0)), "net_total": float(s.get("nT", 0.0)), 
		"net_chance": NET_CHANCE[nl] if ns == S_OK else 0.0, "net_catches": int(s.get("nw", 0)) if ns == S_OK else 0, 
		"conc_lvl": cl, "conc_state": CONC_STATES[cs], "conc_charges": int(s.get("cc", 0)) if cs == S_OK else 0, 
		"conc_max": int(s.get("cm", 0)), "conc_half": bool(s.get("ch", false)) and cs == S_OK, 
		"conc_t": float(s.get("ct", 0.0)), "conc_total": float(s.get("cT", 0.0)), 
		"next_net_cost": (NET_COST[nl + 1] as Dictionary).duplicate() if nl < NET_MAX else {}, 
		"next_conc_cost": (CONC_COST[cl + 1] as Dictionary).duplicate() if cl < CONC_MAX else {}, 
		"repair_net_cost": _share(NET_COST[nl], NET_REPAIR_SHARE) if ns == S_BROKEN else {}, 
		"repair_conc_cost": _share(CONC_COST[cl], CONC_REBUILD_SHARE) if cs == S_BROKEN else {}, 
	}



func upgrade(f: Facility, what: String, country: Country) -> String:
	var why: String = _check(f, what, country)
	if why != "":
		return why
	var s: Dictionary = _state(f)
	var net: bool = what == "net"
	var lvl: int = int(s["nl" if net else "cl"])
	if lvl >= (NET_MAX if net else CONC_MAX):
		return Loc.t("Максимальный уровень")
	var cost: Dictionary = NET_COST[lvl + 1] if net else CONC_COST[lvl + 1]
	if not country.has_res(cost):
		return Loc.t("Не хватает: %s") % country.missing_res(cost)
	country.pay_res(cost)
	var t: float = float(NET_TIME[lvl + 1] if net else CONC_TIME[lvl + 1])
	if net:
		s["np"] = lvl if int(s["ns"]) == S_OK else 0
		s["nl"] = lvl + 1
		s["ns"] = S_BUILDING
		s["nt"] = t
		s["nT"] = t
		s["nw"] = 0
	else:
		s["cl"] = lvl + 1
		s["cs"] = S_BUILDING
		s["ct"] = t
		s["cT"] = t
		s["cc"] = 0
		s["cm"] = 0
		s["ch"] = false
	_spent(country, int(cost.get("money", 0)))
	ver += 1
	gw.fx.spawn("dust_s", f.center_px().round(), 6)
	if country.is_player:
		gw.say(country, Loc.mk("%s %d: стройка %d с — пока без защиты", [Loc.t("Сетка") if net else Loc.t("Бетон"), lvl + 1, int(t)]))
	return ""



func repair(f: Facility, what: String, country: Country) -> String:
	var why: String = _check(f, what, country)
	if why != "":
		return why
	var s: Dictionary = _state(f)
	var net: bool = what == "net"
	if int(s["ns" if net else "cs"]) != S_BROKEN:
		return Loc.t("Ремонт не нужен")
	var lvl: int = int(s["nl" if net else "cl"])
	var cost: Dictionary = _share(NET_COST[lvl], NET_REPAIR_SHARE) if net else _share(CONC_COST[lvl], CONC_REBUILD_SHARE)
	if not country.has_res(cost):
		return Loc.t("Не хватает: %s") % country.missing_res(cost)
	country.pay_res(cost)
	var t: float = NET_REPAIR_TIME if net else float(CONC_TIME[lvl]) * CONC_REBUILD_TIME_SHARE
	if net:
		s["ns"] = S_BUILDING
		s["nt"] = t
		s["nT"] = t
	else:
		s["cs"] = S_BUILDING
		s["ct"] = t
		s["cT"] = t
	_spent(country, int(cost.get("money", 0)))
	ver += 1
	gw.fx.spawn("dust_s", f.center_px().round(), 6)
	if country.is_player:
		gw.say(country, Loc.mk("%s: ремонт %d с", [Loc.t("Сетка") if net else Loc.t("Бетон"), int(t)]))
	return ""



func act_label(f: Facility, what: String) -> String:
	var s: Dictionary = st.get(f.id, {}) if f != null else {}
	var net: bool = what == "net"
	var lvl: int = int(s.get("nl" if net else "cl", 0))
	var state: int = int(s.get("ns" if net else "cs", S_NONE))
	var base: String = Loc.t("СЕТКА") if net else Loc.t("БЕТОН")
	if state == S_BROKEN:
		return Loc.t("ЧИН.%s") % [base]
	if state == S_BUILDING:
		return Loc.t("%s %dС") % [base, ceili(float(s.get("nt" if net else "ct", 0.0)))]
	if lvl >= (NET_MAX if net else CONC_MAX):
		return base + " 3"
	if lvl == 0:
		return "+" + base
	return "%s %d→%d" % [base, lvl, lvl + 1]



func card_line(f: Facility) -> String:
	var i: Dictionary = info(f)
	var parts: PackedStringArray = PackedStringArray()
	match String(i["net_state"]):
		"ok":
			parts.append(Loc.t("СЕТКА %d: %d%%") % [int(i["net_lvl"]), roundi(float(i["net_chance"]) * 100.0)])
		"torn":
			parts.append(Loc.t("СЕТКА ПОРВАНА"))
		"building":
			parts.append(Loc.t("СЕТКА: %d С") % ceili(float(i["net_t"])))
	match String(i["conc_state"]):
		"ok":
			parts.append(Loc.t("БЕТОН %d: %d УД.%s") % [int(i["conc_lvl"]), int(i["conc_charges"]), "+½" if bool(i["conc_half"]) else ""])
		"broken":
			parts.append(Loc.t("БЕТОН РАЗРУШЕН"))
		"building":
			parts.append(Loc.t("БЕТОН: %d С") % ceili(float(i["conc_t"])))
	return "  ".join(parts)






func intercept(f: Facility, kind: int, attacker: int) -> Dictionary:
	var out: Dictionary = {"blocked": false, "dmg_mult": 1.0, "by": ""}
	if f == null or not st.has(f.id):
		return out
	var s: Dictionary = st[f.id]
	var cl: int = int(s["cl"])
	var conc_ok: bool = int(s["cs"]) == S_OK
	if kind == HIT_DRONE or kind == HIT_JET:
		if int(s["ns"]) == S_BUILDING and int(s.get("np", 0)) > 0:
			var chp: float = float(NET_CHANCE[int(s["np"])]) * (NET_JET_MULT if kind == HIT_JET else 1.0)
			if gw.rng.roll() < chp:
				s["np"] = 0
				stats["caught"] = int(stats["caught"]) + 1
				ver += 1
				out["blocked"] = true
				out["by"] = "net"
				return out
		if int(s["ns"]) == S_OK:
			var ch: float = float(NET_CHANCE[int(s["nl"])]) * (NET_JET_MULT if kind == HIT_JET else 1.0)
			if gw.rng.roll() < ch:
				s["nw"] = int(s["nw"]) - 1
				if int(s["nw"]) <= 0:
					s["ns"] = S_BROKEN
					s["nw"] = 0
					stats["torn"] = int(stats["torn"]) + 1
				stats["caught"] = int(stats["caught"]) + 1
				ver += 1
				out["blocked"] = true
				out["by"] = "net"
				return out
		if conc_ok:
			out["dmg_mult"] = float(CONC_DRONE_MULT[cl])
			out["by"] = "conc" if cl >= 2 else ""
		return out
	if not conc_ok:
		return out
	if int(s["cc"]) > 0:
		s["cc"] = int(s["cc"]) - 1
		var ok: bool = kind != HIT_HYPER or gw.rng.roll() < CONC_HYPER_CHANCE
		if int(s["cc"]) <= 0 and not bool(s["ch"]):
			_break_conc(s)
		ver += 1
		out["by"] = "conc"
		out["blocked"] = ok
		stats["absorbed" if ok else "through"] = int(stats["absorbed" if ok else "through"]) + 1
		return out
	if bool(s["ch"]):
		s["ch"] = false
		_break_conc(s)
		ver += 1
		out["by"] = "conc"
		out["dmg_mult"] = CONC_HALF_MULT
		stats["half"] = int(stats["half"]) + 1
	return out






func on_impact(p: Vector2, kind: int, by: int) -> Dictionary:
	var cell: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	_note_victim(cell, kind, by)
	var r: int = int(BLAST_R[clampi(kind, 0, BLAST_R.size() - 1)])
	_report_hit(cell, kind, by, r)
	Nuclear.on_impact(gw, self, cell, kind, r)
	var res: Dictionary = {"blocked": false, "dmg_mult": 1.0, "by": "", "caught": false, "fac": -1}
	if st.is_empty():
		return res
	var drone: bool = kind == HIT_DRONE or kind == HIT_JET




	var near: Array[Facility] = []
	var prim: Facility = null
	var pd: int = 1 << 30
	for fid: int in st.keys():
		var f: Facility = fac(fid)
		if f == null or not gw.mil.alive(f):
			continue
		var rect: = Rect2i(f.cell, f.size)
		var direct: bool = rect.grow(1).has_point(cell)
		if drone and not direct:
			continue
		var d2: int = 0 if direct else _dist2(rect, cell)
		if d2 > r * r:
			continue
		near.append(f)
		if d2 < pd:
			pd = d2
			prim = f
	if prim != null and pd > 0 and _direct_other(cell, prim):
		prim = null
	for f: Facility in near:
		if f != prim:
			var s: Dictionary = st[f.id]
			if not drone and int(s["cs"]) == S_OK and int(s["cc"]) > 0:
				_spare.append({"c": cell, "ids": f.obj_ids.duplicate(), "t": gw.game_time + SPARE_TTL})
				stats["splash"] = int(stats.get("splash", 0)) + 1
			continue
		var one: Dictionary = intercept(f, kind, by)
		var spared: bool = bool(one["blocked"])
		if not spared and float(one["dmg_mult"]) < 1.0 and gw.rng.roll() < 1.0 - float(one["dmg_mult"]):
			spared = true
		if spared:
			_spare.append({"c": cell, "ids": f.obj_ids.duplicate(), "t": gw.game_time + SPARE_TTL})
		_feedback(f, kind, by, one, spared)
		if spared and gw.player != null and by == gw.player.id and not _own_q.is_empty():
			(_own_q[_own_q.size() - 1] as Dictionary)["prot"] = String(one["by"])
		res.merge(one, true)
		res["caught"] = String(one["by"]) == "net" and bool(one["blocked"])
		res["fac"] = f.id
		res["spared"] = spared
	return res



func _direct_other(cell: Vector2i, skip: Facility) -> bool:
	for f: Facility in gw.mil.facilities:
		if f == skip or f.parent != null or f.is_line() or f.moving or st.has(f.id):
			continue
		if Rect2i(f.cell, f.size).grow(1).has_point(cell) and gw.mil.alive(f):
			return true
	return false



func _hit_fac(cell: Vector2i, r: int) -> Facility:
	var best: Facility = null
	var bd: int = r * r + 1
	for f: Facility in gw.mil.facilities:
		if f.parent != null or f.is_line() or f.moving:
			continue
		var rect: = Rect2i(f.cell, f.size)
		var d2: int = 0 if rect.grow(1).has_point(cell) else _dist2(rect, cell)
		if d2 < bd and gw.mil.alive(f):
			bd = d2
			best = f
			if d2 == 0:
				break
	return best


func _intact(f: Facility) -> int:
	var n: int = 0
	for id in f.obj_ids:
		if gw.obj_kind[id] == GameWorld.KIND_BUILDING and gw.obj_state[id] == 0:
			n += 1
	return n


func _report_hit(cell: Vector2i, kind: int, by: int, r: int) -> void :
	if not gw.data.inside(cell.x, cell.y):
		return
	var f: Facility = _hit_fac(cell, r)
	if gw.player != null and by == gw.player.id:

		var tf: Facility = f if f != null and f.country_id != by else null
		_own_q.append({"cell": cell, "k": kind, "f": tf.id if tf != null else -1, "n": _intact(tf) if tf != null else 0, "t": gw.game_time + HIT_CHECK, "prot": ""})
	if f == null:
		return
	if gw.mil.has_method("note_impact"):
		gw.mil.note_impact(f, by)
	if gw.player == null or by == gw.player.id:
		return

	for g: Facility in gw.mil.facilities:
		if g.country_id != gw.player.id or g.parent != null or g.is_line() or g.moving:
			continue
		if g != f and _dist2(Rect2i(g.cell, g.size), cell) > r * r:
			continue
		if gw.mil.alive(g):
			_hit_q.append({"f": g.id, "k": kind, "by": by, "t": gw.game_time + HIT_CHECK, "n": _intact(g), "tip": hit_tip(g, kind)})


func _flush_hits() -> void :
	for k in range(_hit_q.size() - 1, -1, -1):
		var e: Dictionary = _hit_q[k]
		if gw.game_time < float(e["t"]):
			continue
		_hit_q.remove_at(k)
		var f: Facility = fac(int(e["f"]))
		if f == null:
			continue
		var ruined: bool = not gw.mil.alive(f)
		if not ruined and _intact(f) >= int(e["n"]):
			continue
		_toast_own(f, "hit", strike_text(f, int(e["k"]), ruined, String(e.get("tip", ""))), HIT_MSG_GAP)
		if ruined:
			_msg_t["lost:%d" % f.id] = gw.game_time




func own_lost(kind: int) -> void :
	_own_down[kind] = int(_own_down.get(kind, 0)) + 1
	if _own_buf_t < 0.0:
		_own_buf_t = gw.game_time



func _flush_own() -> void :
	var now: float = gw.game_time
	for k in range(_own_q.size() - 1, -1, -1):
		var e: Dictionary = _own_q[k]
		if now < float(e["t"]):
			continue
		_own_q.remove_at(k)
		var txt: String = ""
		var f: Facility = fac(int(e["f"])) if int(e["f"]) >= 0 else null
		if f != null:
			var oc: Country = gw.country_by_id(f.country_id)
			var whose: String = (" (%s)" % Loc.name(oc.name)) if oc != null else ""
			if not gw.mil.alive(f):
				txt = "%s %s%s" % [_title(f), Military.pp(f.kind, "разрушен"), whose]
			elif _intact(f) < int(e["n"]):
				txt = "%s %s%s" % [_title(f), Military.pp(f.kind, "поврежден"), whose]
			elif String(e["prot"]) == "net":
				txt = Loc.t("сетка над «%s» поймала дрон") % _title(f)
			elif String(e["prot"]) == "conc":
				txt = Loc.t("бетон «%s» выдержал") % _title(f)
			else:
				txt = Loc.t("мимо: %s %s") % [_title(f), Military.pp(f.kind, "цел")]
		else:
			var cell: Vector2i = e["cell"]
			var city: City = gw.city_at_cell(cell)
			txt = (Loc.t("попадание в %s") % [Loc.case_of(city.name, "loc")]) if city != null else Loc.t("попадание в поле, объектов нет")
		_own_buf.append([int(e["k"]), txt])
		if _own_buf_t < 0.0:
			_own_buf_t = now
	if _own_buf_t < 0.0 or now - _own_buf_t < OWN_WINDOW or not _own_q.is_empty():
		return
	var kinds: Dictionary = {}
	var parts: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for b: Array in _own_buf:
		kinds[int(b[0])] = true
		var t: String = String(b[1])
		seen[t] = int(seen.get(t, 0)) + 1
	for t2: String in seen:
		if parts.size() < 3:
			parts.append(t2 + ((" ×%d" % int(seen[t2])) if int(seen[t2]) > 1 else ""))
	var down: int = 0
	for k2: Variant in _own_down:
		kinds[int(k2)] = true
		down += int(_own_down[k2])
	var head: String = Loc.t("Наш удар")
	if kinds.size() == 1:
		head = Loc.t(String(LOC_OWN_HEAD[clampi(int(kinds.keys()[0]), 0, LOC_OWN_HEAD.size() - 1)]))
	if down > 0:
		var bal: bool = _own_down.has(HIT_BALLISTIC) or _own_down.has(HIT_HYPER)
		parts.append((Loc.t("перехвачено %d") if bal and _own_down.size() == 1 else Loc.t("сбито %d")) % down)
	_own_buf.clear()
	_own_down.clear()
	_own_buf_t = -1.0
	if gw.player != null and not gw.player.eliminated and not parts.is_empty():
		gw.message.emit("%s: %s" % [head, ", ".join(parts)])





func strike_text(f: Facility, kind: int, ruined: bool, tip: String = "") -> String:
	var title: String = _title(f)
	var verb: String = Military.pp(f.kind, "разрушен" if ruined else "поражен")
	if tip == "":
		tip = hit_tip(f, kind)
	if kind == HIT_KAB:
		if title.get_slice(" ", 0) == title.get_slice(" ", 0).to_upper():
			return Loc.t("КАБ по %s%s — %s") % [title, (": " + verb) if ruined else "", tip]
		return Loc.t("%s %s КАБ — %s") % [title, verb, tip]
	return "%s %s %s — %s" % [title, verb, Loc.t(String(HIT_WEAPON[clampi(kind, 0, HIT_WEAPON.size() - 1)])), tip]





func hit_tip(f: Facility, kind: int) -> String:
	var s: Dictionary = st.get(f.id, {})
	var ns: int = int(s.get("ns", S_NONE))
	var cs: int = int(s.get("cs", S_NONE))
	var el: bool = eligible(f)
	var prot: String = ""
	if el and (kind == HIT_DRONE or kind == HIT_JET):
		prot = [Loc.t("поставьте сетку"), Loc.t("сетка ещё строилась"), Loc.t("сетка не поймала: поднимите уровень"), Loc.t("сетка порвана: почините")][ns]
	elif el and kind != HIT_DRONE and kind != HIT_JET:
		if kind == HIT_HYPER and cs == S_OK:
			prot = Loc.t("гиперзвук пробил бетон")
		else:
			prot = [Loc.t("залейте бетон"), Loc.t("бетон ещё строился"), "", Loc.t("бетон разрушен: восстановите")][cs]
	var ad: String = _ad_tip(f, kind)
	_tip_n += 1
	if prot == "":
		return ad
	if ad == "":
		return prot
	return (prot + "; " + ad) if _tip_n % 2 == 1 else (ad + "; " + prot)




func _ad_tip(f: Facility, kind: int) -> String:
	var cnt: Array = AD_COUNTERS[clampi(kind, 0, AD_COUNTERS.size() - 1)]
	var p: Vector2 = f.center_px()
	var near: Dictionary = {}
	var far: Dictionary = {}
	for g: Facility in gw.mil.facilities:
		if g.country_id != f.country_id or not cnt.has(g.kind) or not gw.mil.alive(g):
			continue
		var r: float = Defense.EW_R if g.kind == Facility.Kind.AD_EW else float(Defense.SPEC[g.kind]["range"])
		if g.center_px().distance_to(p) <= r:
			near[g.kind] = true
		else:
			far[g.kind] = true
	var late: String = ""
	for k: int in cnt:
		if near.has(k):
			late = String(AD_LATE[k])
			break
	for k2: int in cnt:
		if near.has(k2):
			continue
		if far.has(k2):
			return ("%s; " % late if late != "" else "") + Loc.t("%s далеко: поставьте ещё у объекта") % String(AD_TIP_NOM.get(k2, AD_TIP_NAME[k2]))
		return (Loc.t("%s — добавьте %s") % [late, AD_TIP_NAME[k2]]) if late != "" else Loc.t("поставьте %s") % AD_TIP_NAME[k2]
	return Loc.t("%s: нужна ещё одна установка рядом") % late if late != "" else Loc.t("нужна ПВО")



func take_spare(cell: Vector2i) -> PackedInt32Array:
	var out: = PackedInt32Array()
	if _spare.is_empty():
		return out
	for k in range(_spare.size() - 1, -1, -1):
		if _spare[k]["c"] == cell:
			out.append_array(_spare[k]["ids"])
			_spare.remove_at(k)
	return out




func update(dt: float) -> void :
	_acc += dt
	if _acc < TICK_DT:
		return
	var step: float = _acc
	_acc = 0.0
	if not _hit_q.is_empty():
		_flush_hits()
	if not _own_q.is_empty() or _own_buf_t >= 0.0:
		_flush_own()
	for fid: int in st.keys():
		var f: Facility = fac(fid)
		if f == null:
			st.erase(fid)
			ver += 1
			continue
		var s: Dictionary = st[fid]
		if not gw.mil.alive(f):
			_wipe(f, s)
			continue
		if not s.has("own"):
			s["own"] = f.country_id
		elif int(s["own"]) != f.country_id:
			_captured(f, s)
			continue
		if int(s["ns"]) == S_BUILDING:
			s["nt"] = float(s["nt"]) - step
			if float(s["nt"]) <= 0.0:
				s["nt"] = 0.0
				s["ns"] = S_OK
				s["nw"] = int(NET_CATCHES[int(s["nl"])])
				ver += 1
				_toast_own(f, "net_ok", Loc.msg(Loc.mk("Сетка %d готова: %s", [int(s["nl"]), _title(f)])))
		if int(s["cs"]) == S_BUILDING:
			s["ct"] = float(s["ct"]) - step
			if float(s["ct"]) <= 0.0:
				var cl: int = int(s["cl"])
				var rr: Array = CONC_CHARGES[cl]
				s["ct"] = 0.0
				s["cs"] = S_OK
				s["cc"] = gw.rng.range_ab(int(rr[0]), int(rr[1]))
				s["cm"] = int(s["cc"])
				s["ch"] = bool(CONC_LAST_HALF[cl])
				ver += 1
				_toast_own(f, "conc_ok", Loc.msg(Loc.mk("Бетон %d готов: %s (%d уд.)", [cl, _title(f), int(s["cc"])])))
	for k in range(_spare.size() - 1, -1, -1):
		if gw.game_time > float(_spare[k]["t"]):
			_spare.remove_at(k)
	_ai_acc += step
	if _ai_acc >= AI_DT:
		_ai_acc = 0.0
		for c: Country in gw.countries:
			if not c.is_player and not c.eliminated and c.capital_id >= 0:
				_ai_country(c)


func fac(fid: int) -> Facility:
	var fs: Array[Facility] = gw.mil.facilities
	if fid >= 0 and fid < fs.size() and fs[fid].id == fid:
		return fs[fid]
	for f: Facility in fs:
		if f.id == fid:
			return f
	return null




func _ai_country(c: Country) -> void :
	if gw.game_time < float(_ai_next.get(c.id, 0.0)):
		return
	var P: Dictionary = gw.ai.persona_of(c) if gw.ai != null else AiPersona.NEUTRAL
	var caut: float = float(P.get("caution", 0.5))
	var h: Dictionary = hits.get(c.id, {})
	var dr: int = int(h.get("dr", 0))
	var ms: int = int(h.get("ms", 0))
	var war: bool = not c.at_war.is_empty()
	if not war and dr == 0 and ms == 0:
		return
	var budget: int = int(float(c.earned) * (AI_SHARE_WAR if war else AI_SHARE)) - int(ai_spent.get(c.id, 0))
	var reserve: int = AI_FLOOR + int(AI_FLOOR_CAUTION * caut)
	var own: Array[Facility] = []
	for f: Facility in gw.mil.facilities:
		if f.country_id == c.id and eligible(f) and gw.mil.alive(f):
			own.append(f)
	if own.is_empty():
		return

	for f: Facility in own:
		var s: Dictionary = st.get(f.id, {})
		if s.is_empty():
			continue
		for what: String in ["net", "conc"]:
			if int(s["ns" if what == "net" else "cs"]) != S_BROKEN:
				continue
			var cost: Dictionary = _share(NET_COST[int(s["nl"])], NET_REPAIR_SHARE) if what == "net" else _share(CONC_COST[int(s["cl"])], CONC_REBUILD_SHARE)
			if c.money - int(cost.get("money", 0)) >= reserve and int(cost.get("money", 0)) <= budget and c.has_res(cost):
				if repair(f, what, c) == "":
					_ai_next[c.id] = gw.game_time + AI_GAP
				return

	if war or dr > 0:
		var want: int = 1 + (1 if dr >= AI_DRONE_MORE or caut > 0.6 else 0) + (1 if dr >= AI_DRONE_MAX else 0)
		var names: Array = AI_NET_KINDS + (AI_NET_KINDS2 if dr >= AI_DRONE_MORE else [])
		if _ai_buy(c, own, names, "net", want, reserve, budget):
			_ai_next[c.id] = gw.game_time + AI_GAP
			return

	var need: int = maxi(1, 3 - roundi(2.0 * caut))
	if ms >= need:
		var want_c: int = 1 + (1 if ms >= need + AI_CONC_L2_EXTRA and caut >= 0.5 else 0)
		if _ai_buy(c, own, AI_CONC_KINDS, "conc", want_c, reserve, budget):
			_ai_next[c.id] = gw.game_time + AI_GAP


func _ai_buy(c: Country, own: Array[Facility], names: Array, what: String, want: int, reserve: int, budget: int) -> bool:
	for n: String in names:
		if not Facility.Kind.has(n):
			continue
		var k: int = int(Facility.Kind[n])
		for f: Facility in own:
			if f.kind != k:
				continue
			var s: Dictionary = st.get(f.id, {})
			var lvl: int = int(s.get("nl" if what == "net" else "cl", 0))
			if lvl >= want or int(s.get("ns" if what == "net" else "cs", S_NONE)) == S_BUILDING:
				continue
			var cost: Dictionary = NET_COST[lvl + 1] if what == "net" else CONC_COST[lvl + 1]
			if c.money - int(cost.get("money", 0)) < reserve or int(cost.get("money", 0)) > budget or not c.has_res(cost):
				return false
			return upgrade(f, what, c) == ""
	return false




func _check(f: Facility, what: String, country: Country) -> String:
	if what != "net" and what != "conc":
		return Loc.t("Неизвестная защита")
	if not eligible(f):
		return Loc.t("Сюда защиту не поставить")
	if country == null or f.country_id != country.id:
		return Loc.t("Это не ваш объект")
	if not gw.mil.alive(f):
		return Loc.t("Объект разрушен")
	var s: Dictionary = st.get(f.id, {})
	if int(s.get("ns" if what == "net" else "cs", S_NONE)) == S_BUILDING:
		return Loc.t("Уже строится")
	return ""


func _state(f: Facility) -> Dictionary:
	if not st.has(f.id):
		st[f.id] = {"nl": 0, "ns": S_NONE, "nt": 0.0, "nT": 0.0, "nw": 0, "cl": 0, "cs": S_NONE, "ct": 0.0, "cT": 0.0, "cc": 0, "cm": 0, "ch": false, 
			"own": f.country_id}
	return st[f.id]


func _break_conc(s: Dictionary) -> void :
	s["cs"] = S_BROKEN
	s["cc"] = 0
	s["ch"] = false
	stats["broken"] = int(stats["broken"]) + 1



func _wipe(f: Facility, s: Dictionary) -> void :
	var had: bool = int(s["ns"]) != S_NONE or int(s["cs"]) != S_NONE
	st.erase(f.id)
	ver += 1
	for e: Dictionary in _hit_q:
		if int(e["f"]) == f.id:
			return
	if had:
		_toast_own(f, "lost", Loc.msg(Loc.mk("Защита потеряна: %s %s", [_title(f), Military.pp(f.kind, "разрушен")])))



func _captured(f: Facility, s: Dictionary) -> void :
	var old: int = int(s["own"])
	var had: bool = int(s["ns"]) != S_NONE or int(s["cs"]) != S_NONE
	st.erase(f.id)
	ver += 1
	stats["captured"] = int(stats.get("captured", 0)) + 1
	if had and gw.player != null and old == gw.player.id:
		var k: String = "capt:%d" % f.id
		if gw.game_time - float(_msg_t.get(k, -100.0)) >= MSG_GAP:
			_msg_t[k] = gw.game_time
			gw.message.emit(Loc.msg(Loc.mk("Защита потеряна: %s %s", [_title(f), Military.pp(f.kind, "захвачен")])))


static func _share(cost: Dictionary, k: float) -> Dictionary:
	var out: Dictionary = {}
	for key: String in cost:
		out[key] = ceili(float(cost[key]) * k)
	return out


static func _dist2(r: Rect2i, c: Vector2i) -> int:
	var qx: int = clampi(c.x, r.position.x, r.end.x - 1)
	var qy: int = clampi(c.y, r.position.y, r.end.y - 1)
	return (qx - c.x) * (qx - c.x) + (qy - c.y) * (qy - c.y)


func _note_victim(cell: Vector2i, kind: int, by: int) -> void :
	if not gw.data.inside(cell.x, cell.y):
		return
	var v: int = gw.data.get_owner_id(cell.x, cell.y)
	if v <= 0 or v == by:
		return
	var h: Dictionary = hits.get(v, {"dr": 0, "ms": 0})
	var key: String = "dr" if kind == HIT_DRONE or kind == HIT_JET else "ms"
	h[key] = int(h[key]) + 1
	hits[v] = h


func _spent(c: Country, money: int) -> void :
	if not c.is_player:
		ai_spent[c.id] = int(ai_spent.get(c.id, 0)) + money


func _title(f: Facility) -> String:
	return String(Military.TITLES.get(f.kind, "объект"))


func _toast_own(f: Facility, key: String, text: String, gap: float = MSG_GAP) -> void :
	if gw.player == null or f.country_id != gw.player.id:
		return
	var k: String = "%s:%d" % [key, f.id]
	if gw.game_time - float(_msg_t.get(k, -100.0)) < gap:
		return
	_msg_t[k] = gw.game_time
	gw.message.emit(text)


func _feedback(f: Facility, kind: int, by: int, one: Dictionary, spared: bool) -> void :
	var what: String = String(one["by"])
	if what == "":
		return
	var s: Dictionary = st.get(f.id, {})
	var c: Vector2 = f.center_px()
	var top: = Vector2(c.x, f.origin_px().y - float(ProtectLayer.canopy_h(gw, f)) * 0.5)
	if what == "net" and bool(one["blocked"]):
		gw.fx.spawn("intercept_flash", top.round(), 7)
		gw.fx.spawn("spark_burst", (top + Vector2(randf_range(-6, 6), 2)).round(), 7)
		gw.fx.debris_burst(top.round(), 3, false, true)
		Sfx.play("net_catch", top)
		if gw.battle_watch != null:
			gw.battle_watch.note(top, 2.0, "Сетка поймала БПЛА", f.country_id)
		_toast_own(f, "net", Loc.msg(Loc.mk("Сетка поймала дрон: %s", [_title(f)])))
		if int(s.get("ns", S_NONE)) == S_BROKEN:
			_toast_own(f, "torn", Loc.msg(Loc.mk("Сетка порвана — нужен ремонт")))
		if gw.player != null and by == gw.player.id and f.country_id != gw.player.id:
			if gw.vision == null or gw.vision.shows(f.country_id, c):
				_toast_attacker(Loc.msg(Loc.mk("Наш БПЛА пойман сеткой: %s", [_title(f)])))
		return
	if what == "conc":
		if (kind == HIT_DRONE or kind == HIT_JET) and not spared:
			return
		var foot: = Vector2(c.x, f.origin_px().y + f.size.y * GameWorld.CELL)
		for k in 3:
			gw.fx.spawn("dust_s", (foot + Vector2(randf_range( - f.size.x * 2.0, f.size.x * 2.0), randf_range(-3, 1))).round(), 6)
		gw.fx.spawn("dirt_burst", foot.round(), 6)
		Sfx.play("concrete_thud", foot)
		if kind == HIT_DRONE or kind == HIT_JET:
			if spared:
				_toast_own(f, "concd", Loc.msg(Loc.mk("Бетон защитил: %s", [_title(f)])))
			return
		if int(s.get("cs", S_NONE)) == S_BROKEN or s.is_empty():
			_toast_own(f, "cbroke", Loc.msg(Loc.mk("Бетонное укрепление разрушено: %s", [_title(f)])))
		elif bool(one["blocked"]):
			var left: int = int(s.get("cc", 0))
			_toast_own(f, "conc", Loc.msg(Loc.mk("Бетон выдержал удар (осталось %d%s)", [left, "+½" if bool(s.get("ch", false)) else ""])))
		elif kind == HIT_HYPER:
			_toast_own(f, "chyp", Loc.msg(Loc.mk("Гиперзвук пробил бетон: %s", [_title(f)])))
		if gw.battle_watch != null:
			gw.battle_watch.note(foot, 2.0, "Бетон выдержал удар", f.country_id)


func _toast_attacker(text: String) -> void :
	if gw.game_time - float(_msg_t.get("att", -100.0)) < MSG_GAP * 2.0:
		return
	_msg_t["att"] = gw.game_time
	gw.message.emit(text)




func save_state() -> Dictionary:
	var s2: Dictionary = {}
	for fid: int in st:
		s2[str(fid)] = (st[fid] as Dictionary).duplicate()
	var sp: Array = []
	for e: Dictionary in _spare:
		sp.append([e["c"].x, e["c"].y, Array(e["ids"]), float(e["t"])])
	var hh: Dictionary = {}
	for k: int in hits:
		hh[str(k)] = (hits[k] as Dictionary).duplicate()
	var ss: Dictionary = {}
	for k: int in ai_spent:
		ss[str(k)] = int(ai_spent[k])
	var an: Dictionary = {}
	for k: int in _ai_next:
		an[str(k)] = float(_ai_next[k])
	var hq: Array = []
	for e: Dictionary in _hit_q:
		hq.append([int(e["f"]), int(e["k"]), int(e["by"]), float(e["t"]), int(e["n"]), String(e.get("tip", ""))])
	return {"st": s2, "spare": sp, "hits": hh, "spent": ss, "stats": stats.duplicate(), "acc": _acc, "ai_acc": _ai_acc, "ai_next": an, "hitq": hq}


func load_state(d: Dictionary) -> void :
	st.clear()
	var s2: Dictionary = d.get("st", {})
	for k in s2:
		var e: Dictionary = (s2[k] as Dictionary).duplicate()
		for key: String in ["nl", "ns", "nw", "cl", "cs", "cc", "cm"]:
			e[key] = int(e.get(key, 0))
		if e.has("own"):
			e["own"] = int(e["own"])
		for key: String in ["nt", "nT", "ct", "cT"]:
			e[key] = float(e.get(key, 0.0))
		e["ch"] = bool(e.get("ch", false))
		st[int(str(k))] = e
	_spare.clear()
	for a in d.get("spare", []):
		_spare.append({"c": Vector2i(int(a[0]), int(a[1])), "ids": PackedInt32Array(a[2]), "t": float(a[3])})
	hits.clear()
	var hh: Dictionary = d.get("hits", {})
	for k in hh:
		hits[int(str(k))] = {"dr": int(hh[k].get("dr", 0)), "ms": int(hh[k].get("ms", 0))}
	ai_spent.clear()
	var ss: Dictionary = d.get("spent", {})
	for k in ss:
		ai_spent[int(str(k))] = int(ss[k])
	var sx: Dictionary = d.get("stats", {})
	for k in sx:
		stats[String(k)] = int(sx[k])
	_ai_next.clear()
	var an: Dictionary = d.get("ai_next", {})
	for k in an:
		_ai_next[int(str(k))] = float(an[k])
	_acc = float(d.get("acc", 0.0))
	_ai_acc = float(d.get("ai_acc", 0.0))
	_hit_q.clear()
	for a in d.get("hitq", []):
		_hit_q.append({"f": int(a[0]), "k": int(a[1]), "by": int(a[2]), "t": float(a[3]), "n": int(a[4]), "tip": String(a[5]) if a.size() > 5 else ""})
	ver += 1
