extends RefCounted











const W_CAP: float = 1.0
const W_DMG: float = 1.0 / 150.0
const W_AID: float = 1.0 / 400.0
const W_TIME: float = 1.0 / 60.0
const CAP_TIME: float = 900.0
const CITY_COST: Array = [30, 14, 6]
const ENT_COST: int = 2
const PUPPET_MUL: float = 0.7
const CONF_T: float = 180.0
const CONF_T_NET: float = 360.0
const REPICK_T: float = 120.0
const CHECK_DT: float = 3.0
const CAP_SHARE: float = 0.4
const SURRENDER_T: float = 420.0
const PUPPET_PREF: Dictionary = {"cautious": 0.7, "trader": 0.35, "adventurer": 0.45, "militarist": 0.15}
const ARMY_SHARE: float = 0.15
const SURR_MIN_T: float = 240.0
const BEATEN_T: float = 480.0
const BEATEN_RATIO: float = 2.2
const SURR_T: float = 60.0
const SURR_GAP: float = 300.0
const ASK_GAP: float = 120.0

var dp
var gw: GameWorld
var active: Array = []
var results: Array = []
var peak: Dictionary = {}
var cap0: Dictionary = {}
var contrib: Dictionary = {}
var _dmg_last: Dictionary = {}
var _id: int = 1
var _t: float = 0.0
var applying: bool = false
var hold_id: int = -1
var offers: Array = []
var _surr_next: Dictionary = {}
var _ask_next: Dictionary = {}
var counters: Dictionary = {}
var fill_orphans: bool = true
var orphan_stats: Dictionary = {}


func _init(d) -> void :
	dp = d
	gw = d.gw
	if not gw.city_captured.is_connected(_on_capture):
		gw.city_captured.connect(_on_capture)


func _count(k: String, n: int = 1) -> void :
	counters[k] = int(counters.get(k, 0)) + n





func on_war(a: int, b: int) -> void :
	for id: int in [a, b]:
		var c: Country = gw.country_by_id(id)
		if c == null:
			continue
		if not peak.has(id) or c.at_war.size() <= 1:
			peak[id] = c.city_ids.size()
			cap0[id] = c.capital_id
		_dmg_last[id] = c.destroyed


func _ck(a: int, b: int) -> String:
	return "%d>%d" % [a, b]


func _add(a: int, b: int, field: String, v: float) -> void :
	var k: String = _ck(a, b)
	var c: Dictionary = contrib.get(k, {"cap": 0.0, "dmg": 0.0, "aid": 0.0})
	c[field] = float(c.get(field, 0.0)) + v
	contrib[k] = c


func _on_capture(city: City, old: int) -> void :
	if applying or city == null:
		return
	var nw: int = city.country_id
	if dp.at_war(nw, old):
		_add(nw, old, "cap", float(city_cost(city, old)) + (20.0 if int(cap0.get(old, -1)) == city.id else 0.0))



func note_aid(from: int, to: int, value: int) -> void :
	var ct: Country = gw.country_by_id(to)
	if ct == null or ct.at_war.is_empty():
		return
	var n: int = ct.at_war.size()
	for e: int in ct.at_war.keys():
		if e != from:
			_add(from, e, "aid", float(value) / float(n))


func score_parts(a: int, d: int) -> Dictionary:
	var c: Dictionary = contrib.get(_ck(a, d), {})
	var t: float = minf(dp.war_time(a, d), CAP_TIME) if dp.at_war(a, d) else 0.0
	return {"cap": float(c.get("cap", 0.0)) * W_CAP, "dmg": float(c.get("dmg", 0.0)) * W_DMG, "aid": float(c.get("aid", 0.0)) * W_AID, "time": t * W_TIME, 
		"cap_raw": float(c.get("cap", 0.0)), "dmg_raw": float(c.get("dmg", 0.0)), "aid_raw": float(c.get("aid", 0.0)), "t_raw": t}


func score_of(a: int, d: int) -> float:
	var s: Dictionary = score_parts(a, d)
	return 1.0 + float(s["cap"]) + float(s["dmg"]) + float(s["aid"]) + float(s["time"])



func city_cost(city: City, owner: int) -> int:
	var cost: int = int(CITY_COST[clampi(city.kind, 0, 2)])
	var r2: float = pow(float(city.claim_max) * 1.2 + 4.0, 2.0)
	for f: Facility in gw.mil.facilities:
		if f.country_id == owner and Economy.is_enterprise(f.kind) and gw.mil.alive(f) and Vector2(f.cell).distance_squared_to(Vector2(city.center)) <= r2:
			cost += ENT_COST
	return cost




func update(dt: float) -> void :
	var now: float = gw.game_time
	for cf: Dictionary in active.duplicate():
		if int(cf["id"]) == hold_id and not gw.net_driven:
			cf["until"] = float(cf["until"]) + dt
		elif now >= float(cf["until"]):
			_auto_player(cf)
	for i in range(offers.size() - 1, -1, -1):
		var o: Dictionary = offers[i]
		var dd: Country = gw.country_by_id(int(o["def"]))
		if dd == null or dd.eliminated or dd.at_war.is_empty() or _in_conf(dd.id):
			offers.remove_at(i)
			dp.pending_changed.emit()
		elif _answerers(o).is_empty():




			offers.remove_at(i)
			_surr_next.erase(dd.id)
			dp.pending_changed.emit()
	_t += dt
	if _t < CHECK_DT:
		return
	_t = 0.0
	_check()


func _check() -> void :
	for c: Country in gw.countries:
		if c.eliminated:
			continue
		if c.at_war.is_empty():
			if not _in_conf(c.id):
				peak.erase(c.id)
				cap0.erase(c.id)
			_dmg_last[c.id] = c.destroyed
			continue
		var delta: int = c.destroyed - int(_dmg_last.get(c.id, c.destroyed))
		_dmg_last[c.id] = c.destroyed
		if delta > 0:
			for e: int in c.at_war.keys():
				_add(c.id, e, "dmg", float(delta) / float(c.at_war.size()))
		peak[c.id] = maxi(int(peak.get(c.id, c.city_ids.size())), c.city_ids.size())
		if not cap0.has(c.id):
			cap0[c.id] = c.capital_id
	for k: String in contrib.keys():
		var ab: PackedStringArray = k.split(">")
		if ab.size() != 2 or ( not dp.at_war(int(ab[0]), int(ab[1])) and not _in_conf(int(ab[1]))):
			contrib.erase(k)
	for d: Country in gw.countries:
		if d.is_player or d.eliminated or d.capital_id < 0 or d.at_war.is_empty() or _in_conf(d.id):
			continue
		if dp._young(d.id):
			continue
		var n: int = d.city_ids.size()
		var pk: int = int(peak.get(d.id, n))
		var c0: int = int(cap0.get(d.id, -1))
		var lost_cap: bool = c0 >= 0 and c0 < gw.cities.size() and gw.cities[c0].country_id != d.id
		var strongest: float = 0.0
		var longest: float = 0.0
		for e2: int in d.at_war.keys():
			strongest = maxf(strongest, dp.strength(e2))
			longest = maxf(longest, dp.war_time(d.id, e2))
		var surrender: bool = longest > SURRENDER_T and dp.strength(d.id) < strongest * 0.25 and n < pk and float(n) <= ceilf(float(pk) * 0.6)
		var foe_units: int = 0
		for e3: int in d.at_war.keys():
			foe_units += gw.army.count_units(e3)
		var army_lost: bool = longest >= SURR_MIN_T and foe_units >= 6 and float(gw.army.count_units(d.id)) < float(foe_units) * ARMY_SHARE\
		and (n < pk or longest > 600.0)

		var beaten: bool = longest >= BEATEN_T and n < pk and float(gw.army.count_units(d.id)) * BEATEN_RATIO <= float(foe_units)
		var capit: bool = lost_cap and float(n) <= maxf(1.0, float(pk) * CAP_SHARE)
		if n >= 1 and (capit or surrender or army_lost or beaten) and gw.game_time >= float(_surr_next.get(d.id, 0.0)) and not _has_offer(d.id):
			_offer_surrender(d, Loc.t("капитуляция") if capit else Loc.t("сдаётся"))


func _in_conf(id: int) -> bool:
	for cf: Dictionary in active:
		if int(cf["def"]) == id:
			return true
	return false







func locks(a: int, b: int) -> bool:
	for cf: Dictionary in active:
		var d: int = int(cf["def"])
		if a != d and b != d:
			continue
		var o: int = b if a == d else a
		var parts: Array = cf["parts"]
		if parts.has(o) or _fought(cf, o):
			return true
	return _ally_pair(a, b) >= 0




func _ally_pair(a: int, b: int) -> int:
	for i in active.size():
		for pr: Variant in (active[i] as Dictionary).get("ally_war", []):
			var x: int = int((pr as Array)[0])
			var y: int = int((pr as Array)[1])
			if (x == a and y == b) or (x == b and y == a):
				return i
	return -1




func _fought(cf: Dictionary, o: int) -> bool:
	if not (cf["parts"] as Array).has(dp.subject_of(o)):
		return false
	if not cf.has("at"):
		return true
	for v: Variant in (cf["at"] as Array):
		if int(v) == o:
			return true
	return false



func holds(c: int, owner: int) -> bool:
	for cf: Dictionary in active:
		if int(cf["def"]) == owner and ((cf["parts"] as Array).has(c) or _fought(cf, c)):
			return true
	return _ally_pair(c, owner) >= 0


func _has_offer(id: int) -> bool:
	for o: Dictionary in offers:
		if int(o["def"]) == id:
			return true
	return false




func _offer_surrender(d: Country, why: String) -> void :
	_count("surrender_offers")
	var p: Country = null
	for hc: Country in gw.countries:
		if hc.is_player and not hc.eliminated and dp.at_war(hc.id, d.id):
			p = hc
			break
	gw.news_m(Loc.mk("%s ПРОСИТ МИРА НА ЛЮБЫХ УСЛОВИЯХ", [Loc.name(d.name).to_upper()]), "amber")
	if p != null:
		offers.append({"id": _id, "def": d.id, "until": gw.game_time + SURR_T, "why": why, "to": p.id})
		_id += 1
		gw.say(p, Loc.mk("КАПИТУЛЯЦИЯ: %s сдаётся — принять и делить землю?", [Loc.name(d.name)]))
		if p == gw.player:
			Sfx.ui("ui_alert")
		gw.offer_received.emit()
		dp.pending_changed.emit()
		return
	_start(d, why)




func answer_offer(id: int, act: String, by: int = -1) -> String:
	for i in offers.size():
		var o: Dictionary = offers[i]
		if int(o["id"]) != id or (by >= 0 and _offer_to(o) != by and not _answerers(o).has(by)):
			continue
		offers.remove_at(i)
		var d: Country = gw.country_by_id(int(o["def"]))
		if d == null or d.eliminated:
			return Loc.t("Страны больше нет")
		if act == "accept":
			_count("surrender_accepted")
			_start(d, String(o["why"]))
		else:
			_count("surrender_refused")
			_surr_next[d.id] = gw.game_time + SURR_GAP
			gw.news_m(Loc.mk("КАПИТУЛЯЦИЯ ОТВЕРГНУТА: %s ВОЮЕТ ДАЛЬШЕ", [Loc.name(d.name).to_upper()]), "alert_red")
		dp.pending_changed.emit()
		return ""
	return Loc.t("Предложение устарело")





func can_demand_surrender(me: int, d: int) -> Dictionary:
	var c: Country = gw.country_by_id(d)
	if c == null or c.eliminated or not dp.at_war(me, d) or c.is_player:
		return {"ok": false, "why": "", "edge": 0.0}
	if _in_conf(d) or _has_offer(d):
		return {"ok": false, "why": Loc.t("уже решается"), "edge": 0.0}
	if dp.war_time(me, d) < 120.0:
		return {"ok": false, "why": Loc.t("война только началась"), "edge": 0.0}
	var ours: int = 0
	for o: Country in gw.countries:
		if not o.eliminated and dp.at_war(o.id, d):
			ours += gw.army.count_units(o.id)
	var n: int = c.city_ids.size()
	var pk: int = maxi(n, int(peak.get(d, n)))
	var lost: float = 1.0 - float(n) / float(maxi(1, pk))
	var army: float = float(gw.army.count_units(d)) / float(maxi(1, ours))
	var ratio: float = dp.strength(me) / maxf(1.0, dp.strength(d))
	var ok: bool = lost >= 0.4 or (army < 0.25 and ours >= 6) or ratio >= 3.0
	return {"ok": ok, "why": "" if ok else Loc.t("перевес ещё не подавляющий"), "edge": maxf(lost * 2.5, maxf((1.0 - army) * 1.3, ratio / 3.0))}



func demand_surrender(me: int, d: int) -> String:
	var ok: Dictionary = can_demand_surrender(me, d)
	var c: Country = gw.country_by_id(d)
	if not bool(ok["ok"]):
		return Loc.t("Нельзя: %s") % [String(ok["why"])]
	var wait: float = float(_ask_next.get(d, 0.0)) - gw.game_time
	if wait > 0.0:
		return Loc.t("Уже требовали: ещё %d с") % ceili(wait)
	_ask_next[d] = gw.game_time + ASK_GAP
	_count("surrender_asked")
	var n: int = c.city_ids.size()
	var pk: int = maxi(n, int(peak.get(d, n)))
	var c0: int = int(cap0.get(d, -1))
	var lost_cap: bool = c0 >= 0 and c0 < gw.cities.size() and gw.cities[c0].country_id != d
	var ours: int = 0
	for o: Country in gw.countries:
		if not o.eliminated and dp.at_war(o.id, d):
			ours += gw.army.count_units(o.id)
	var army: float = float(gw.army.count_units(d)) / float(maxi(1, ours))
	var yes: bool = lost_cap or float(n) <= float(pk) * 0.6 or army < 0.2 or dp.strength(me) >= dp.strength(d) * 4.0
	if not yes:
		dp.add_opinion(me, d, -5)
		return Loc.t("%s отказывается сдаваться") % c.name
	_count("surrender_forced")
	_start(c, Loc.t("капитуляция"))
	return ""


func has_conf(id: int) -> bool:
	return not get_conf(id).is_empty()


func get_conf(id: int) -> Dictionary:
	for cf: Dictionary in active:
		if int(cf["id"]) == id:
			return cf
	return {}



func conf_for_player() -> Dictionary:
	return conf_for(gw.player.id) if gw.player != null else {}



func conf_for(pid: int) -> Dictionary:
	for cf: Dictionary in active:
		if String(cf.get("phase", "")) in ["people", "repick"]:
			if _people_left(cf).has(pid):
				return cf
			continue
		var parts: Array = cf.get("order", cf["parts"])
		if int(cf["turn"]) < parts.size() and int(parts[int(cf["turn"])]) == pid:
			return cf
	return {}




func _answerers(o: Dictionary) -> Array:
	var out: Array = []
	for hc: Country in gw.countries:
		if hc.is_player and not hc.eliminated and dp.at_war(hc.id, int(o["def"])):
			out.append(hc.id)
	return out



func _offer_to(o: Dictionary) -> int:
	if o.has("to"):
		return int(o["to"])
	for hc: Country in gw.countries:
		if hc.is_player and not hc.eliminated and dp.at_war(hc.id, int(o["def"])):
			return hc.id
	return -1



func item_to(id: String) -> int:
	var n: int = int(id.substr(1))
	if id.begins_with("s"):
		for o: Dictionary in offers:
			if int(o["id"]) == n:
				if dp._who_hint >= 0 and _answerers(o).has(int(dp._who_hint)):
					return int(dp._who_hint)
				return _offer_to(o)
	elif id.begins_with("k"):
		var cf: Dictionary = get_conf(n)
		if not cf.is_empty() and String(cf.get("phase", "")) in ["people", "repick"]:
			var left: Array = _people_left(cf)
			if left.has(int(dp._who_hint)):
				return int(dp._who_hint)
			return int(left[0]) if not left.is_empty() else -1
		if not cf.is_empty():
			var parts: Array = cf.get("order", cf["parts"])
			if int(cf["turn"]) < parts.size():
				return int(parts[int(cf["turn"])])
	return -1





func forecast(cf: Dictionary, spent_out: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	if cf.is_empty():
		return out
	var sim: Dictionary = cf.duplicate()
	sim["terr"] = (cf["terr"] as Array).duplicate(true)
	sim["spent"] = (cf["spent"] as Dictionary).duplicate()
	var order: Array = cf.get("order", cf["parts"])
	var from: int = int(cf["turn"]) + 1
	if String(cf.get("phase", "")) == "people":
		_resolve_people(sim, false)
		from = int(sim["turn"])
	for i in range(from, order.size()):
		_ai_pick(sim, int(order[i]), false)
	for t: Dictionary in sim["terr"]:
		if int(t["by"]) != 0 and bool(t.get("fc", false)):
			out[int(t["city"])] = {"by": int(t["by"]), "mode": String(t["mode"])}
	spent_out.merge(sim["spent"], true)
	return out





func start_now(d: Country, why: String = "капитуляция") -> Dictionary:
	if d == null or _in_conf(d.id):
		return {}
	return _start(d, why)


func _start(d: Country, why: String) -> Dictionary:
	var parts: Array = []
	var at: Array = []
	for c: Country in gw.countries:
		if c.id != d.id and not c.eliminated and c.capital_id >= 0 and dp.at_war(c.id, d.id):
			at.append(c.id)
			var ov: int = dp.subject_of(c.id)
			if not (ov > 0 and dp.at_war(ov, d.id)):
				parts.append(c.id)
	if parts.is_empty():
		return {}
	var sc: Dictionary = {}
	var brk: Dictionary = {}
	var tot_sc: float = 0.0
	for pid: int in parts:
		sc[pid] = score_of(pid, d.id)
		brk[pid] = score_parts(pid, d.id)
		for sid: int in dp.subjects_of(pid):
			if at.has(sid):
				sc[pid] = float(sc[pid]) + score_of(sid, d.id) - 1.0
		tot_sc += float(sc[pid])
	parts.sort_custom( func(a: int, b: int) -> bool: return float(sc[a]) > float(sc[b]) or (float(sc[a]) == float(sc[b]) and a < b))
	var terr: Array = []
	var total: int = 0
	for cid: int in d.city_ids:
		var city: City = gw.cities[cid]
		var cost: int = city_cost(city, d.id)
		total += cost
		terr.append({"city": cid, "name": city.name, "kind": city.kind, "cost": cost, "pcost": maxi(1, ceili(float(cost) * PUPPET_MUL)), "by": 0, "mode": "", "auto": false})
	terr.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a["cost"]) > int(b["cost"]))
	var pts: Dictionary = {}
	var share: Dictionary = {}
	var spent: Dictionary = {}
	for pid2: int in parts:
		share[pid2] = float(sc[pid2]) / maxf(0.001, tot_sc)
		pts[pid2] = roundi(float(total) * float(share[pid2])) if parts.size() > 1 else total
		spent[pid2] = 0
	var order: Array = []
	for pid5: int in parts:
		if gw.country_by_id(pid5).is_player:
			order.append(pid5)
	for pid6: int in parts:
		if not order.has(pid6):
			order.append(pid6)
	var people: Array = []
	for pid7: int in order:
		if gw.country_by_id(pid7).is_player:
			people.append(pid7)



	var cf: Dictionary = {"id": _id, "def": d.id, "name": d.name, "why": why, "parts": parts, "order": order, "score": sc, "brk": brk, "share": share, "pts": pts, "spent": spent, 
		"terr": terr, "total": total, "turn": 0, "t0": gw.game_time, "until": gw.game_time + CONF_T, "at": at.duplicate(), 
		"phase": "people" if not people.is_empty() else "bots", "people": people, "done": []}
	var aw: Array = []
	for x: Country in gw.countries:
		if x.id == d.id or x.eliminated or not dp.allied(x.id, d.id):
			continue
		for y: int in at:
			if dp.at_war(x.id, y):
				aw.append([x.id, y])
	cf["ally_war"] = aw
	_id += 1
	active.append(cf)
	_count("conferences")
	if parts.size() > 1:
		_count("conf_shared")
	for pid3: int in at:
		dp._set_rel(d.id, pid3, Diplomacy.Rel.TRUCE)
	for pr: Array in aw:
		dp._set_rel(int(pr[0]), int(pr[1]), Diplomacy.Rel.TRUCE)
	var names: PackedStringArray = PackedStringArray()
	for pid4: int in parts:
		names.append(dp._cname(pid4))
	gw.news_m(Loc.mk("%s: %s — КОНФЕРЕНЦИЯ ПОБЕДИТЕЛЕЙ (%s)", [why.to_upper(), Loc.name(d.name).to_upper(), ", ".join(names).to_upper()]), "alert_red")
	_advance(cf)
	return cf



func _advance(cf: Dictionary) -> void :
	if String(cf.get("phase", "")) == "people":
		if not _people_left(cf).is_empty():
			if not bool(cf.get("told", false)):
				cf["told"] = true
				cf["until"] = gw.game_time + (CONF_T_NET if gw.net_driven else CONF_T)
				for pid0: int in _people_left(cf):
					var c0: Country = gw.country_by_id(pid0)
					var others: String = ", ".join(PackedStringArray((cf["people"] as Array).filter( func(x: int) -> bool: return x != pid0).map( func(x: int) -> String: return dp._cname(x))))
					gw.say(c0, Loc.mk("КОНФЕРЕНЦИЯ: %s капитулирует — делите землю (%d очк.)%s", [String(cf["name"]), int(cf["pts"][pid0]), (Loc.t(" одновременно с: ") + others) if others != "" else ""]))
					if c0 == gw.player:
						Sfx.ui("conference_gong")
				gw.offer_received.emit()
				dp.pending_changed.emit()
			return
		_resolve_people(cf, true)
	if String(cf.get("phase", "")) == "repick":
		if not _people_left(cf).is_empty():
			return
		cf["phase"] = "bots"
	var parts: Array = cf.get("order", cf["parts"])
	while int(cf["turn"]) < parts.size():
		var pid: int = int(parts[int(cf["turn"])])
		var c: Country = gw.country_by_id(pid)
		if c != null and c.is_player and not c.eliminated:
			cf["until"] = gw.game_time + CONF_T
			gw.say(c, Loc.mk("КОНФЕРЕНЦИЯ: %s капитулирует — ваша очередь делить землю (%d очк.)", [String(cf["name"]), int(cf["pts"][pid])]))
			if c == gw.player:
				Sfx.ui("conference_gong")
			gw.offer_received.emit()
			dp.pending_changed.emit()
			return
		if c != null and not c.eliminated:
			_ai_pick(cf, pid)
		cf["turn"] = int(cf["turn"]) + 1
	_apply(cf)


func points_left(cf: Dictionary, pid: int) -> int:
	return int((cf["pts"] as Dictionary).get(pid, 0)) - int((cf["spent"] as Dictionary).get(pid, 0))



func pick(conf_id: int, city_id: int, mode: String, pid: int = -1) -> String:
	var cf: Dictionary = get_conf(conf_id)
	var p: Country = gw.country_by_id(pid) if pid > 0 else gw.player
	if cf.is_empty() or p == null or conf_for(p.id) != cf:
		return Loc.t("Сейчас не ваша очередь")
	if String(cf.get("phase", "")) == "people":
		return _claim(cf, p, city_id, mode)
	for t: Dictionary in cf["terr"]:
		if int(t["city"]) != city_id:
			continue
		var by: int = int(t["by"])
		if by != 0 and by != p.id:
			return Loc.t("Уже забрал %s") % dp._cname(by)
		var old: int = 0
		if by == p.id:
			old = int(t["cost"]) if String(t["mode"]) == "annex" else int(t["pcost"])
		var need: int = 0
		if mode == "annex":
			need = int(t["cost"])
		elif mode == "puppet":
			need = int(t["pcost"])
		if need > points_left(cf, p.id) + old:
			return Loc.t("Не хватает очков: нужно %d, есть %d") % [need, points_left(cf, p.id) + old]
		cf["spent"][p.id] = int(cf["spent"][p.id]) - old + need
		t["by"] = p.id if mode != "" else 0
		t["mode"] = mode
		if mode != "" and p == gw.player:
			Sfx.ui("territory_claim")
		return ""
	return Loc.t("Нет такой территории")



func reset_picks(conf_id: int, pid: int = -1) -> void :
	var cf: Dictionary = get_conf(conf_id)
	var p: Country = gw.country_by_id(pid) if pid > 0 else gw.player
	if cf.is_empty() or p == null:
		return
	if String(cf.get("phase", "")) == "people" and conf_for(p.id) != cf:
		return
	for t: Dictionary in cf["terr"]:
		if int(t["by"]) == p.id:
			t["by"] = 0
			t["mode"] = ""
		_cl_set(t, p.id, "")
	cf["spent"][p.id] = 0



func confirm(conf_id: int, pid: int = -1) -> String:
	var cf: Dictionary = get_conf(conf_id)
	var who: int = pid if pid > 0 else (gw.player.id if gw.player != null else -1)
	if cf.is_empty() or conf_for(who) != cf:
		return Loc.t("Конференция закончилась")
	if hold_id == conf_id:
		hold_id = -1
	_count("conf_player_confirm")
	if String(cf.get("phase", "")) in ["people", "repick"]:
		(cf["done"] as Array).append(who)
		if not _people_left(cf).is_empty():
			gw.say(gw.country_by_id(who), Loc.mk("Конференция: ваш выбор принят — ждём: %s", [", ".join(PackedStringArray(_people_left(cf).map( func(x: int) -> String: return Loc.name(dp._cname(x)))))]))
			dp.pending_changed.emit()
		_advance(cf)
		return ""
	cf["turn"] = int(cf["turn"]) + 1
	_advance(cf)
	return ""


func _auto_player(cf: Dictionary) -> void :
	if String(cf.get("phase", "")) == "repick":
		for pid1: int in _people_left(cf):
			_ai_pick(cf, pid1)
			gw.say(gw.country_by_id(pid1), Loc.mk("Конференция: время вышло — оставшиеся очки потрачены на ближайшие города"))
			(cf["done"] as Array).append(pid1)
		_advance(cf)
		return
	if String(cf.get("phase", "")) == "people":
		for pid0: int in _people_left(cf):
			_auto_claim(cf, pid0)
			gw.say(gw.country_by_id(pid0), Loc.mk("Конференция: время вышло — оставшиеся очки потрачены на ближайшие города"))
			(cf["done"] as Array).append(pid0)
			_count("conf_player_timeout")
		_advance(cf)
		return
	var parts: Array = cf.get("order", cf["parts"])
	if int(cf["turn"]) >= parts.size():
		return
	var p: Country = gw.country_by_id(int(parts[int(cf["turn"])]))
	if p == null or not p.is_player:
		return
	_ai_pick(cf, p.id)
	gw.say(p, Loc.mk("Конференция: время вышло — земля поделена без вас (взято ближайшее)"))
	_count("conf_player_timeout")
	cf["turn"] = int(cf["turn"]) + 1
	_advance(cf)



func _ai_pick(cf: Dictionary, pid: int, real: bool = true) -> void :
	var c: Country = gw.country_by_id(pid)
	if c == null or c.capital_id < 0:
		return
	var P: Dictionary = dp._p(pid)
	var pref: float = 0.0 if c.is_player else float(PUPPET_PREF.get(String(P.get("id", "")), 0.3))
	var home: = Vector2(gw.cities[c.capital_id].center)
	var cands: Array = []
	for t: Dictionary in cf["terr"]:
		if int(t["by"]) == 0:
			cands.append(t)
	cands.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		return Vector2(gw.cities[int(a["city"])].center).distance_squared_to(home) < Vector2(gw.cities[int(b["city"])].center).distance_squared_to(home))
	for t2: Dictionary in cands:
		var left: int = points_left(cf, pid)
		if left <= 0:
			break
		var puppet: bool = float(Hash32.h2(pid, int(t2["city"]), 919) % 1000) < pref * 1000.0
		if not puppet and int(t2["cost"]) > left:
			puppet = int(t2["pcost"]) <= left
		var need: int = int(t2["pcost"]) if puppet else int(t2["cost"])
		if need > left:
			continue
		t2["by"] = pid
		t2["mode"] = "puppet" if puppet else "annex"
		t2["auto"] = true
		if not real:
			t2["fc"] = true
		cf["spent"][pid] = int(cf["spent"][pid]) + need
	if real:
		_count("conf_ai_picks")





func _people_left(cf: Dictionary) -> Array:
	var out: Array = []
	for pid: int in (cf.get("repick", []) if String(cf.get("phase", "")) == "repick" else cf.get("people", [])):
		var c: Country = gw.country_by_id(pid)
		if c != null and not c.eliminated and c.is_player and not (cf["done"] as Array).has(pid):
			out.append(pid)
	return out



static func claim_of(t: Dictionary, pid: int) -> String:
	for e: Array in t.get("cl", []):
		if int(e[0]) == pid:
			return String(e[1])
	return ""


static func claimers(t: Dictionary) -> Array:
	var out: Array = []
	for e: Array in t.get("cl", []):
		out.append(int(e[0]))
	return out


static func _cl_set(t: Dictionary, pid: int, mode: String) -> void :
	var cl: Array = t.get("cl", [])
	for i in range(cl.size() - 1, -1, -1):
		if int(cl[i][0]) == pid:
			cl.remove_at(i)
	if mode != "":
		cl.append([pid, mode])
	if cl.is_empty():
		t.erase("cl")
	else:
		t["cl"] = cl




func _claim(cf: Dictionary, p: Country, city_id: int, mode: String) -> String:
	for t: Dictionary in cf["terr"]:
		if int(t["city"]) != city_id:
			continue
		var cur: String = claim_of(t, p.id)
		var old: int = (int(t["cost"]) if cur == "annex" else int(t["pcost"])) if cur != "" else 0
		var need: int = int(t["cost"]) if mode == "annex" else (int(t["pcost"]) if mode == "puppet" else 0)
		if need > points_left(cf, p.id) + old:
			return Loc.t("Не хватает очков: нужно %d, есть %d") % [need, points_left(cf, p.id) + old]
		cf["spent"][p.id] = int(cf["spent"][p.id]) - old + need
		_cl_set(t, p.id, mode)
		if mode != "" and p == gw.player:
			Sfx.ui("territory_claim")
		return ""
	return Loc.t("Нет такой территории")



func _auto_claim(cf: Dictionary, pid: int) -> void :
	var c: Country = gw.country_by_id(pid)
	if c == null or c.capital_id < 0:
		return
	var home: = Vector2(gw.cities[c.capital_id].center)
	var cands: Array = []
	for t: Dictionary in cf["terr"]:
		if int(t["by"]) == 0 and not t.has("cl"):
			cands.append(t)
	cands.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = Vector2(gw.cities[int(a["city"])].center).distance_squared_to(home)
		var db: float = Vector2(gw.cities[int(b["city"])].center).distance_squared_to(home)
		return da < db if da != db else int(a["city"]) < int(b["city"]))
	for t2: Dictionary in cands:
		var left: int = points_left(cf, pid)
		if left <= 0:
			break
		var mode: String = "annex" if int(t2["cost"]) <= left else ("puppet" if int(t2["pcost"]) <= left else "")
		if mode == "":
			continue
		_cl_set(t2, pid, mode)
		cf["spent"][pid] = int(cf["spent"][pid]) + (int(t2["cost"]) if mode == "annex" else int(t2["pcost"]))





func _resolve_people(cf: Dictionary, real: bool) -> void :
	var lost: Dictionary = {}
	var sc: Dictionary = cf.get("score", {})
	for t: Dictionary in cf["terr"]:
		if not t.has("cl"):
			continue
		var cl: Array = (t["cl"] as Array).filter( func(e: Array) -> bool:
			var c: Country = gw.country_by_id(int(e[0]))
			return c != null and not c.eliminated and c.is_player)
		for e0: Array in t["cl"]:
			if not cl.has(e0):
				cf["spent"][int(e0[0])] = int(cf["spent"][int(e0[0])]) - (int(t["cost"]) if String(e0[1]) == "annex" else int(t["pcost"]))
		t.erase("cl")
		if cl.is_empty():
			continue
		var best: Array = cl[0]
		for e: Array in cl:
			var se: float = float(sc.get(int(e[0]), 0.0))
			var sb: float = float(sc.get(int(best[0]), 0.0))
			if se > sb or (se == sb and int(e[0]) < int(best[0])):
				best = e
		t["by"] = int(best[0])
		t["mode"] = String(best[1])
		if not real:
			t["fc"] = true
		for e2: Array in cl:
			if int(e2[0]) == int(best[0]):
				continue
			var o: int = int(e2[0])
			cf["spent"][o] = int(cf["spent"][o]) - (int(t["cost"]) if String(e2[1]) == "annex" else int(t["pcost"]))
			if not lost.has(o):
				lost[o] = []
			(lost[o] as Array).append(String(t["name"]))
	cf["phase"] = "bots"
	cf["turn"] = (cf.get("people", []) as Array).size()
	var again: Array = []
	for pid: int in cf.get("people", []):
		if not lost.has(pid):
			continue
		if not real:
			_ai_pick(cf, pid, false)
			continue
		_count("conf_contest_lost")
		if _min_free_cost(cf) <= points_left(cf, pid):
			again.append(pid)
			gw.say(gw.country_by_id(pid), Loc.mk("КОНФЕРЕНЦИЯ: спорные земли отошли тем, кто больше сделал для победы (%s) — очки возвращены, выберите из свободных", [", ".join(PackedStringArray(lost[pid]))]))
		else:
			gw.say(gw.country_by_id(pid), Loc.mk("Конференция: спорные земли отошли тем, кто больше сделал для победы: %s", [", ".join(PackedStringArray(lost[pid]))]))
	if not again.is_empty():
		cf["phase"] = "repick"
		cf["repick"] = again
		cf["done"] = []
		cf["until"] = gw.game_time + REPICK_T
		gw.offer_received.emit()
		dp.pending_changed.emit()



func _min_free_cost(cf: Dictionary) -> int:
	var m: int = 1 << 30
	for t: Dictionary in cf["terr"]:
		if int(t["by"]) == 0:
			m = mini(m, int(t["pcost"]))
	return m



func contest_winner(cf: Dictionary, t: Dictionary) -> int:
	var sc: Dictionary = cf.get("score", {})
	var best: int = -1
	for e: Array in t.get("cl", []):
		var c: Country = gw.country_by_id(int(e[0]))
		if c == null or c.eliminated or not c.is_player:
			continue
		if best < 0 or float(sc.get(int(e[0]), 0.0)) > float(sc.get(best, 0.0)) or (float(sc.get(int(e[0]), 0.0)) == float(sc.get(best, 0.0)) and int(e[0]) < best):
			best = int(e[0])
	return best




func _apply(cf: Dictionary) -> void :
	active.erase(cf)
	if hold_id == int(cf["id"]):
		hold_id = -1
	var d: Country = gw.country_by_id(int(cf["def"]))
	if d == null:
		return
	applying = true
	gw.capture_quiet = true
	var pre: PackedInt32Array = _owned_cells(d.id) if fill_orphans else PackedInt32Array()
	var annex: Dictionary = {}
	var groups: Dictionary = {}
	var order: Array = []
	for t: Dictionary in cf["terr"]:
		var cid: int = int(t["city"])
		if cid < 0 or cid >= gw.cities.size() or gw.cities[cid].country_id != d.id:
			continue
		var by: int = int(t["by"])
		var cb: Country = gw.country_by_id(by)
		if by == 0 or cb == null or cb.eliminated:
			continue
		if String(t["mode"]) == "puppet":
			if not groups.has(by):
				groups[by] = []
				order.append(by)
			(groups[by] as Array).append(cid)
		else:
			gw.capture_city(gw.cities[cid], by)
			annex[by] = int(annex.get(by, 0)) + 1
	var puppets: Array = []
	for gi in order.size():
		var over: int = int(order[gi])
		var ids: Array = groups[over]

		var rest: int = d.city_ids.size()
		var successor: bool = gi == order.size() - 1 and rest == ids.size()
		var nc: Country = null
		if successor:
			nc = _revive(d)
		elif gw.has_method("new_country_from"):
			nc = gw.new_country_from(ids)
		if nc == null:
			for cid2: int in ids:
				gw.capture_city(gw.cities[cid2], over)
			annex[over] = int(annex.get(over, 0)) + ids.size()
			_count("conf_puppet_fallback")
			continue
		dp.opinion[Diplomacy.key(nc.id, over)] = 40
		dp.make_subject(over, nc.id, "puppet", "conference")
		puppets.append([nc.id, over, ids.size()])
		_count("conf_puppets")
		gw.news_m(Loc.mk("НОВОЕ ГОСУДАРСТВО: %s — МАРИОНЕТКА %s", [Loc.name(nc.name).to_upper(), Loc.name(dp._name(over))]), "amber")
	if not pre.is_empty():
		_split_rest(cf, d, pre)
	gw.capture_quiet = false
	applying = false
	var returned: int = 0
	var revived: bool = false
	for pz: Array in puppets:
		if int(pz[0]) == d.id:
			revived = true
	if not revived:
		returned = d.city_ids.size()
		for pid: int in cf["parts"]:
			if dp.get_rel(d.id, pid) == Diplomacy.Rel.TRUCE or dp.at_war(d.id, pid):
				dp._set_rel(d.id, pid, Diplomacy.Rel.PEACE)
		peak.erase(d.id)
		cap0.erase(d.id)
	for pid2: int in cf["parts"]:
		contrib.erase(_ck(pid2, d.id))
	for pr2: Variant in cf.get("ally_war", []):

		var ax: int = int((pr2 as Array)[0])
		var ay: int = int((pr2 as Array)[1])
		var cx: Country = gw.country_by_id(ax)
		var cy: Country = gw.country_by_id(ay)
		if cx != null and cy != null and not cx.eliminated and not cy.eliminated and dp.get_rel(ax, ay) == Diplomacy.Rel.TRUCE:
			dp.truce_until.erase(Diplomacy.key(ax, ay))
			dp._set_rel(ax, ay, Diplomacy.Rel.WAR)
			_count("conf_ally_war_resumed")
			gw.news_m(Loc.mk("КОНФЕРЕНЦИЯ ОКОНЧЕНА: %s И %s ВОЮЮТ ДАЛЬШЕ", [Loc.name(dp._name(ax)), Loc.name(dp._name(ay))]), "alert_red")
	var an: int = 0
	for k: int in annex:
		an += int(annex[k])
	var res: Dictionary = {"t": gw.game_time, "def": d.id, "name": String(cf["name"]), "annex": annex, "puppets": puppets, "returned": returned, "parts": (cf["parts"] as Array).duplicate()}
	results.append(res)
	if results.size() > 12:
		results.pop_front()
	gw.news_m(Loc.mk("ИТОГИ КОНФЕРЕНЦИИ (%s): АННЕКСИЯ %d, МАРИОНЕТОК %d, ВОЗВРАЩЕНО %d", [String(cf["name"]).to_upper(), an, puppets.size(), returned]), "amber")
	var p: Country = gw.player
	if p != null and (cf["parts"] as Array).has(p.id):
		var mine: int = int(annex.get(p.id, 0))
		var mp: String = ""
		for pz2: Array in puppets:
			if int(pz2[1]) == p.id:
				mp = dp._cname(int(pz2[0]))
		gw.message.emit(Loc.msg(Loc.mk("Конференция: вам %d %s%s", [mine, Loc.n(mine, "город", "города", "городов"), (Loc.t(" + марионетка ") + mp) if mp != "" else ""])))
	_count("conf_done")
	dp.pending_changed.emit()
	gw.relations_changed.emit()
	gw.changed.emit()








var _own: = PackedByteArray()
var _mk: = PackedByteArray()


func _owned_cells(cid: int) -> PackedInt32Array:
	var out: = PackedInt32Array()
	var own: PackedByteArray = gw.data.owners
	var n: int = own.size()
	var i: int = own.find(cid)
	while i >= 0:
		out.append(i)
		i = own.find(cid, i + 1) if i + 1 < n else -1
	return out


func _split_rest(cf: Dictionary, d: Country, pre: PackedInt32Array) -> void :
	var data: WorldData = gw.data
	var W: int = data.w
	var cents: Array[Vector2i] = []
	var cids: Array[int] = []
	for t: Dictionary in cf["terr"]:
		var cid: int = int(t["city"])
		if cid >= 0 and cid < gw.cities.size():
			cents.append(gw.cities[cid].center)
			cids.append(cid)
	orphan_stats = {"cells": pre.size(), "moved": 0, "orphans": 0, "left": 0}
	if cents.is_empty():
		return
	var gainers: Dictionary = {}
	for cid2: int in cids:
		var oc: int = gw.cities[cid2].country_id
		if oc != d.id and oc > 0:
			gainers[oc] = true
	_own = data.owners
	_mk = PackedByteArray()
	_mk.resize(_own.size())
	var moved: int = 0
	var touched: Dictionary = {}



	var nk: int = cents.size()
	var to_k: = PackedInt32Array()
	to_k.resize(nk)
	for k0 in nk:
		to_k[k0] = gw.cities[cids[k0]].country_id
	var tfl: = PackedByteArray()
	tfl.resize(256)
	var row_end: int = -1
	var row_base: int = 0
	var sp_lo: = PackedInt64Array()
	var sp_hi: = PackedInt64Array()
	var sp_k: = PackedInt32Array()
	var sp_p: int = 0
	for i: int in pre:
		if i >= row_end:
			var y: int = i / W
			row_base = y * W
			row_end = row_base + W
			var spans: Array = []
			for k in nk:
				var lo: int = - (1 << 40)
				var hi: int = 1 << 40
				var ck: Vector2i = cents[k]
				for j in nk:
					if j == k:
						continue
					var cj: Vector2i = cents[j]

					var m: int = 2 * (cj.x - ck.x)
					var e: int = cj.x * cj.x - ck.x * ck.x + (y - cj.y) * (y - cj.y) - (y - ck.y) * (y - ck.y)
					var tie: bool = k < j
					if m > 0:
						hi = mini(hi, GameWorld._fdiv(e, m) if tie else GameWorld._cdiv(e, m) - 1)
					elif m < 0:
						lo = maxi(lo, GameWorld._cdiv( - e, - m) if tie else GameWorld._fdiv( - e, - m) + 1)
					elif e < 0 or (e == 0 and not tie):
						hi = lo - 1
					if lo > hi:
						break
				if lo <= hi:
					spans.append([lo, hi, k])
			spans.sort()
			sp_lo.resize(spans.size())
			sp_hi.resize(spans.size())
			sp_k.resize(spans.size())
			for q in spans.size():
				sp_lo[q] = int(spans[q][0])
				sp_hi[q] = int(spans[q][1])
				sp_k[q] = int(spans[q][2])
			sp_p = 0
		var x: int = i - row_base
		while x > sp_hi[sp_p]:
			sp_p += 1
		var to: int = to_k[sp_k[sp_p]]
		if to <= 0 or int(_own[i]) == to:
			continue
		tfl[int(_own[i])] = 1
		tfl[to] = 1
		_own[i] = to
		_mk[i] = 1
		moved += 1

	var orph: int = 0
	if not d.eliminated and not d.city_ids.is_empty() and not gainers.is_empty():
		var q: = PackedInt32Array()
		for cid3: int in d.city_ids:
			var cc: Vector2i = gw.cities[cid3].center
			if not data.inside(cc.x, cc.y):
				continue
			var ci: int = cc.y * W + cc.x
			if int(_own[ci]) == d.id and _mk[ci] != 2:
				_mk[ci] = 2
				q.append(ci)
		_flood(q, d.id, 2, W)
		for i2: int in pre:
			if int(_own[i2]) != d.id or _mk[i2] >= 2:
				continue
			_mk[i2] = 3
			var comp: PackedInt32Array = _flood(PackedInt32Array([i2]), d.id, 3, W)
			var cnt: Dictionary = {}
			for j: int in comp:
				for nb: int in [j - 1, j + 1, j - W, j + W]:
					if nb >= 0 and nb < _own.size() and gainers.has(int(_own[nb])):
						cnt[int(_own[nb])] = int(cnt.get(int(_own[nb]), 0)) + 1
			var to2: int = 0
			var bc: int = 0
			for g: int in cnt:
				if int(cnt[g]) > bc or (int(cnt[g]) == bc and g < to2):
					bc = int(cnt[g])
					to2 = g
			if to2 <= 0:

				var bd2: int = 1 << 30
				var cx2: int = i2 % W
				var cy2: int = i2 / W
				for k2 in cents.size():
					var oc2: int = gw.cities[cids[k2]].country_id
					var dd2: int = (cx2 - cents[k2].x) * (cx2 - cents[k2].x) + (cy2 - cents[k2].y) * (cy2 - cents[k2].y)
					if gainers.has(oc2) and dd2 < bd2:
						bd2 = dd2
						to2 = oc2
			if to2 <= 0:
				continue
			for j2: int in comp:
				_own[j2] = to2
				_mk[j2] = 1
			touched[to2] = true
			touched[d.id] = true
			orph += comp.size()
	if moved + orph > 0:
		data.owners = _own
		data.owners_dirty = true
		gw._checkpoints_dirty = true

		for f: Facility in gw.mil.facilities:
			if f.country_id != d.id:
				continue
			var h: Facility = f.parent if f.parent != null else f
			var hc: Vector2i = h.cell + h.size / 2
			if not data.inside(hc.x, hc.y):
				continue
			var hi: int = hc.y * W + hc.x
			if _mk[hi] == 1 and int(_own[hi]) != d.id and int(_own[hi]) > 0:
				f.country_id = int(_own[hi])
				f.queued.clear()
		for t2 in 256:
			if tfl[t2] != 0:
				touched[t2] = true
		var tk: Array = touched.keys()
		tk.sort()
		for c2: int in tk:
			gw.enclave_check(c2)
	_own = PackedByteArray()
	_mk = PackedByteArray()
	var left: int = 0
	if not d.eliminated:
		left = gw.data.owners.count(d.id)
	orphan_stats = {"cells": pre.size(), "moved": moved, "orphans": orph, "left": left}
	_count("conf_cells_moved", moved + orph)




func _flood(q: PackedInt32Array, cid: int, tag: int, W: int) -> PackedInt32Array:
	var n: int = _own.size()
	var h: int = 0
	while h < q.size():
		var j: int = q[h]
		h += 1
		var x: int = j % W

		var nb: int = j - 1 if x > 0 else -1
		if nb >= 0 and _mk[nb] < 2 and int(_own[nb]) == cid:
			_mk[nb] = tag
			q.append(nb)
		nb = j + 1 if x < W - 1 else -1
		if nb >= 0 and nb < n and _mk[nb] < 2 and int(_own[nb]) == cid:
			_mk[nb] = tag
			q.append(nb)
		nb = j - W
		if nb >= 0 and _mk[nb] < 2 and int(_own[nb]) == cid:
			_mk[nb] = tag
			q.append(nb)
		nb = j + W
		if nb < n and _mk[nb] < 2 and int(_own[nb]) == cid:
			_mk[nb] = tag
			q.append(nb)
	return q



func _revive(d: Country) -> Country:
	var id: int = d.id
	if dp.get("ally") != null:
		dp.ally.drop(id)
	for o: Country in gw.countries:
		if o.id == id:
			continue
		var k: String = Diplomacy.key(id, o.id)
		dp.rel.erase(k)
		dp.since.erase(k)
		dp.truce_until.erase(k)
		dp.opinion.erase(k)
		dp.treaties.erase(k)
		dp.peace_t.erase(k)
		for e: String in ["%d>%d" % [id, o.id], "%d>%d" % [o.id, id]]:
			dp.embargo.erase(e)
			dp.passage.erase(e)
			dp.war_goals.erase(e)
			dp.refusals.erase(e)
		o.at_war.erase(id)
		if gw.econ != null and gw.econ.trading(id, o.id):
			gw.econ.set_trade(id, o.id, false)
	d.at_war.clear()
	for i in range(dp.demands.size() - 1, -1, -1):
		if int(dp.demands[i]["from"]) == id or int(dp.demands[i]["to"]) == id:
			dp.demands.remove_at(i)
	for i2 in range(dp.t_offers.size() - 1, -1, -1):
		if int(dp.t_offers[i2]["from"]) == id or int(dp.t_offers[i2]["to"]) == id:
			dp.t_offers.remove_at(i2)
	for sid: int in dp.subjects_of(id):
		dp._free_subject(sid, true)
	dp.subjects.erase(id)
	dp.known.erase(id)
	peak.erase(id)
	cap0.erase(id)


	if gw.pstat != null:
		gw.pstat.forget(id)
	if dp.get("rq") != null:
		dp.rq.forget(id)
	if dp.get("rift") != null:
		dp.rift.forget(id)
	if gw.econ != null and gw.econ.trd != null:
		for o2: Country in gw.countries:
			gw.econ.trd.sanct.erase("%d>%d" % [id, o2.id])
			gw.econ.trd.sanct.erase("%d>%d" % [o2.id, id])
	if gw.get("drama") != null:
		gw.drama.hist.erase(id)
	var salt: int = 1 + Hash32.h2(id, int(gw.game_time), 4242) % 9000
	d.name = NameGen.country(gw.rng, gw.countries.filter( func(o: Country) -> bool: return o != d).map( func(o: Country) -> String: return o.name))
	if gw.has_method("reflag_country"):
		gw.reflag_country(d, salt)
	dp.reborn[id] = salt
	d.money = maxi(d.money, 1500)
	d.eliminated = false
	_count("conf_successor")
	return d




func pending(now: float) -> Array:
	var out: Array = []
	for o: Dictionary in offers:
		var d: Country = gw.country_by_id(int(o["def"]))
		if d == null or gw.player == null or (_offer_to(o) != gw.player.id and not _answerers(o).has(gw.player.id)):
			continue

		out.append({"id": "s%d" % int(o["id"]), "from": d.id, "kind": "surrender", "icon": "icon_dip_conf", 
			"text": Loc.t("КАПИТУЛЯЦИЯ: %s сдаётся — делим землю на конференции") % d.name, 
			"deadline": -1.0, "left": -1.0, "total": SURR_T, "noexp": true, 
			"options": [{"act": "accept", "label": Loc.t("ПРИНЯТЬ")}, {"act": "refuse", "label": Loc.t("ВОЕВАТЬ")}]})
	var cf: Dictionary = conf_for_player()
	if cf.is_empty():
		return out
	var p: Country = gw.player
	out.append({"id": "k%d" % int(cf["id"]), "from": int(cf["def"]), "kind": "conference", "icon": "icon_dip_conf", 
		"text": Loc.t("КОНФЕРЕНЦИЯ: %s капитулирует — делим землю (%d очк.)") % [String(cf["name"]), points_left(cf, p.id)], 
		"deadline": float(cf["until"]), "left": maxf(0.0, float(cf["until"]) - now), "total": CONF_T, 
		"options": [{"act": "open", "label": Loc.t("ОТКРЫТЬ")}]})
	return out


func save_state() -> Dictionary:
	return {"active": active.duplicate(true), "results": results.duplicate(true), "peak": peak.duplicate(), "cap0": cap0.duplicate(), 
		"contrib": contrib.duplicate(true), "dmg_last": _dmg_last.duplicate(), "id": _id, "counters": counters.duplicate(), 
		"offers": offers.duplicate(true), "surr_next": _surr_next.duplicate(), "ask_next": _ask_next.duplicate()}


static func _ik(d: Variant) -> Dictionary:
	var out: Dictionary = {}
	if d is Dictionary:
		for k: Variant in d:
			out[int(k)] = d[k]
	return out


func load_state(d: Dictionary) -> void :
	_id = int(d.get("id", 1))
	counters = d.get("counters", {})
	peak = {}
	for k: Variant in (d.get("peak", {}) as Dictionary):
		peak[int(k)] = int(d["peak"][k])
	cap0 = {}
	for k2: Variant in (d.get("cap0", {}) as Dictionary):
		cap0[int(k2)] = int(d["cap0"][k2])
	_dmg_last = {}
	for k3: Variant in (d.get("dmg_last", {}) as Dictionary):
		_dmg_last[int(k3)] = int(d["dmg_last"][k3])
	contrib = {}
	for k4: Variant in (d.get("contrib", {}) as Dictionary):
		var c: Dictionary = d["contrib"][k4]
		contrib[String(k4)] = {"cap": float(c.get("cap", 0.0)), "dmg": float(c.get("dmg", 0.0)), "aid": float(c.get("aid", 0.0))}
	results = d.get("results", [])
	offers = []
	for o: Variant in (d.get("offers", []) as Array):
		var od: Dictionary = o
		offers.append({"id": int(od.get("id", 0)), "def": int(od.get("def", 0)), "until": float(od.get("until", 0.0)), "why": String(od.get("why", "сдаётся"))})
		if od.has("to"):
			offers[offers.size() - 1]["to"] = int(od["to"])
	_surr_next = _ik(d.get("surr_next", {}))
	_ask_next = _ik(d.get("ask_next", {}))
	active = []
	for a: Variant in (d.get("active", []) as Array):
		var cf: Dictionary = a
		var dd: Country = gw.country_by_id(int(cf.get("def", 0)))
		if dd == null or dd.eliminated:
			continue
		var parts: Array = []
		for pv: Variant in (cf.get("parts", []) as Array):
			parts.append(int(pv))
		cf["parts"] = parts
		var order: Array = []
		for ov: Variant in (cf.get("order", parts) as Array):
			order.append(int(ov))
		cf["order"] = order
		for f: String in ["score", "brk", "share", "pts", "spent"]:
			cf[f] = _ik(cf.get(f, {}))
		for t: Dictionary in (cf.get("terr", []) as Array):
			for f2: String in ["city", "kind", "cost", "pcost", "by"]:
				t[f2] = int(t.get(f2, 0))
		cf["id"] = int(cf["id"])
		cf["def"] = int(cf["def"])
		cf["turn"] = int(cf.get("turn", 0))
		cf["total"] = int(cf.get("total", 0))
		active.append(cf)
