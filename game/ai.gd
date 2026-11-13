class_name AiBots
extends RefCounted







const Cad344: = preload("res://game/cad344.gd")

var gw: GameWorld
var _t: Dictionary = {}


func _init(world: GameWorld) -> void :
	gw = world
	sense = SenseS.new(world)
	guard = BridgeGuardS.new(world)


const SenseS = preload("res://game/strike_sense.gd")
var sense = null
const BridgeGuardS = preload("res://game/bridge_guard.gd")
var guard = null






var personas: Dictionary = {}
var stats: Dictionary = {}
var _skip: Dictionary = {}
var _blocked: Dictionary = {}
var _take_t: Dictionary = {}




func persona_of(c: Country) -> Dictionary:
	if c == null or c.is_player:
		var n: Dictionary = AiPersona.NEUTRAL.duplicate()
		n["name"] = Loc.t("ИГРОК")
		return n
	if not personas.has(c.id):
		_assign_personas()
	return AiPersona.traits(String(personas.get(c.id, "trader")))



func _assign_personas() -> void :
	var sd: int = gw.data.world_seed if gw.data != null else 1
	var hard: Array = ["militarist", "adventurer"]
	var soft: Array = ["trader", "cautious"]
	if Hash32.h2(sd, 1, 404) % 2 == 1:
		hard.reverse()
	if Hash32.h2(sd, 2, 404) % 2 == 1:
		soft.reverse()
	var bag: Array = [hard[0], soft[0], hard[1], soft[1]] if Hash32.h2(sd, 3, 404) % 2 == 0 else [soft[0], hard[0], soft[1], hard[1]]
	var k: int = 0
	for c: Country in gw.countries:
		if c.is_player:
			continue
		if not personas.has(c.id):
			personas[c.id] = bag[k % bag.size()]
		k += 1


func _stat(c: Country, key: String, n: int = 1) -> void :
	var st: Dictionary = stats.get(c.id, {})
	st[key] = int(st.get(key, 0)) + n
	stats[c.id] = st



func _threat(c: Country) -> float:
	var thr: float = 0.0
	if not c.at_war.is_empty():
		return 1.0
	var dp: Diplomacy = gw.diplo
	var my: float = maxf(1.0, dp.strength(c.id))
	for o: Country in gw.countries:
		if o == c or o.eliminated or o.capital_id < 0 or dp.allied(c.id, o.id):
			continue
		var ratio: float = dp.strength(o.id) / my
		if dp.relation(c.id, o.id) < -20 and ratio > 1.2:
			thr = maxf(thr, clampf((ratio - 1.0) * 0.6, 0.2, 0.8))
		if dp._has_demand(o.id, c.id):
			thr = maxf(thr, 0.6)


	var co: Dictionary = dp.coalition
	if not co.is_empty():
		var lid: int = int(co.get("leader", -1))
		if lid != c.id and lid > 0 and not dp.allied(c.id, lid) and (dp.neighbours(c.id, lid) or (co.get("members", []) as Array).has(c.id)):
			thr = maxf(thr, ARMS_RACE_THR)
	if gw.drama != null:
		thr = maxf(thr, clampf(gw.drama.bias(c, "arms"), 0.0, ARMS_RACE_THR))
	return thr


const ARMS_RACE_THR: float = 0.6



func _targets(c: Country, P: Dictionary) -> Array:
	var diff: int = GameConfig.diff_of(c)
	var n: int = c.city_ids.size()
	var thr: float = _threat(c)
	var aggr: float = float(P["aggr"])
	var caut: float = float(P["caution"])
	var trade: float = float(P["trade"])
	var sneaky: float = float(P["sneaky"])
	var eco: float = 1.0 + trade * 0.3
	var rich: int = clampi(c.money / 6000, 0, 3)
	var mil: float = 0.35 + aggr * 0.6 + thr * 0.5
	var dfn: float = 0.25 + caut * 0.7 + thr * 0.6

	var basics: bool = _count(c, Facility.Kind.FARM) > 0 and _count(c, Facility.Kind.SAWMILL) > 0 and _count(c, Facility.Kind.CIV_FACTORY) > 0
	if not basics or gw.game_time < 150.0:
		mil *= 0.25
		dfn *= 0.25
	var t: Array = [
		[Facility.Kind.FARM, 1 + n / 3 + (1 if gw.army.count_units(c.id) > 8 else 0), 1.3 * eco], 
		[Facility.Kind.SAWMILL, 1 + n / 4, 1.2 * eco], 
		[Facility.Kind.CIV_FACTORY, 1 + n / 3 + (1 if trade > 0.7 else 0), (1.0 + trade * 0.5) * eco], 
		[Facility.Kind.MINE, 1 + n / 3 + diff, 1.1 * eco], 
		[Facility.Kind.OIL_RIG, 1 + n / 5, 0.9 * eco], 
		[Facility.Kind.PORT, 1, (0.4 + trade * 0.8) * eco], 
		[Facility.Kind.DRONE_FACTORY, 1, mil], 
		[Facility.Kind.DRONE_PORT, 1, mil], 
		[Facility.Kind.DP_RAMP, 1 + diff / 2 + (1 if aggr > 0.5 else 0), mil * 0.9], 
		[Facility.Kind.BARRACKS, 1 + (1 if aggr > 0.7 else 0) + (1 if diff == 2 else 0) + (1 if thr > 0.6 else 0) + (rich if aggr > 0.4 else rich / 2), 0.5 + aggr * 0.6 + thr * 0.6], 
		[Facility.Kind.AD_MFG, 1 + diff + (2 if caut > 0.7 else 0) + (rich if caut > 0.5 else 0), dfn], 
		[Facility.Kind.AD_SPAAG, [0, 1, 2][diff] + (1 if caut > 0.7 else 0), dfn], 
	]


	if gw.game_time > float(Navy.BASE_AT[clampi(diff, 0, 2)]) and gw.get("navy") != null and gw.navy._land_ok(c) and gw.navy.wants_navy(c):
		t.append([Facility.Kind.NAVAL_BASE, 1, 0.75 + 0.25 * float(diff) + aggr * 0.3 + thr * 0.3 + 0.1 * float(rich)])
	if gw.game_time > 240.0:
		t.append([Facility.Kind.REFINERY, 1, 0.6 * eco])
		t.append([Facility.Kind.PORT_CRANE, 2 if trade > 0.7 else 1, (0.3 + trade * 0.5) * eco])
	if _count(c, Facility.Kind.DRONE_PORT) > 0 and gw.mil.stock_count(c.id) >= gw.mil.drone_capacity(c.id) - 1:
		t.append([Facility.Kind.DP_STORE, 1 + (1 if aggr > 0.7 else 0), maxf(mil, 0.4) * 0.8])
	if diff >= 1 or aggr > 0.7:
		t.append([Facility.Kind.MISSILE_FACTORY, 1, 0.3 + aggr * 0.5 + sneaky * 0.2])
		t.append([Facility.Kind.TEL, [0, 1, 2][diff] + (1 if aggr > 0.7 else 0) + (rich / 2 if aggr > 0.4 else 0), 0.3 + aggr * 0.5])
		t.append([Facility.Kind.AIRFIELD, 1, 0.3 + aggr * 0.3 + caut * 0.2])
		t.append([Facility.Kind.AD_RADAR, 1, dfn])
		t.append([Facility.Kind.AD_EW, 1, dfn * 0.8])
	if (aggr > 0.5 or sneaky > 0.7) and diff >= 1:
		t.append([Facility.Kind.DP_RUNWAY, 1, mil * 0.7])
	if (diff >= 1 and caut > 0.4) or thr > 0.5:
		t.append([Facility.Kind.AD_SAM, 1, dfn])
	if diff == 2 or (caut > 0.7 and diff >= 1):
		t.append([Facility.Kind.AD_PATRIOT, 1, dfn * 0.8])
	if diff == 2:
		t.append([Facility.Kind.AD_INT, 1, dfn * 0.6])
	return t


func _build(c: Country, cont: bool = false) -> void :
	var cap: City = gw.cities[c.capital_id]
	if not cont and Nuclear.ai_tick(gw, self, c):
		return

	if not cont and c.power_use > c.power_cap:
		var pc: int = Military.cost_of(Facility.Kind.POWER_PLANT)
		var prc: Dictionary = Economy.res_cost("build_%d" % Facility.Kind.POWER_PLANT)
		if ( not c.has_res(prc) or c.money < pc) and _solar(c, cap):
			return
		if not c.has_res(prc):
			gw.econ.ai_blocked(c, prc)
			if gw.econ.can_substitute(Economy.build_cost(Facility.Kind.POWER_PLANT), c):
				if gw.mil.auto_place(Facility.Kind.POWER_PLANT, cap.center, c, cap.radius + 6, cap.radius + 80) != null:
					gw.econ.pay_substituted(c, Economy.build_cost(Facility.Kind.POWER_PLANT))
					_stat(c, "subst")
		elif c.money >= pc:
			if gw.mil.auto_place(Facility.Kind.POWER_PLANT, cap.center, c, cap.radius + 6, cap.radius + 80) != null:
				c.money -= pc
				gw.econ.pay_build(c, Facility.Kind.POWER_PLANT)
		return
	var P: Dictionary = persona_of(c)
	var now: float = gw.game_time
	var scored: Array = []
	for e: Array in _targets(c, P):
		var kind: int = e[0]
		var want: int = int(e[1])
		var have: int = _count(c, kind)
		if have >= want or want <= 0:
			continue
		if Defense.is_ad(kind) and not _ad_room(c, kind):
			continue
		if gw.econ.upk != null and not gw.econ.upk.ai_ok(c, kind):
			continue
		if now < float(_skip.get("%d:%d" % [c.id, kind], -1.0)):
			continue
		scored.append([float(e[2]) * float(want - have) / float(want) + float(Hash32.h2(c.id, kind, int(now / 60.0)) % 10) * 0.005, kind])
	scored.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var reserve: int = 150 + int(float(P["caution"]) * 200.0)
	var first: bool = not cont
	for s: Array in scored:
		var kind: int = int(s[1])
		var cost: int = gw.mil.price_of(kind, c)
		if c.money < cost + reserve:
			if first:
				_saving[c.id] = cost + reserve
				return
			continue
		first = false
		var bkey: String = "%d:%d" % [c.id, kind]
		var rc: Dictionary = Economy.res_cost("build_%d" % kind)
		var sub: bool = false
		if not c.has_res(rc):
			gw.econ.ai_blocked(c, rc)
			if not _blocked.has(bkey):
				_blocked[bkey] = now
			var patience: float = float(P["sub_wait"]) * [1.5, 1.0, 0.7][GameConfig.diff_of(c)]
			var full: Dictionary = Economy.build_cost(kind)
			if now - float(_blocked[bkey]) < patience or not gw.econ.can_substitute(full, c)\
			or c.money < int(gw.econ.substitute_cost(full, c)["money"]) + reserve:
				continue
			sub = true
		_saving.erase(c.id)
		var f: Facility = _place(c, kind, cap)
		if f == null and _place_wait:
			_place_wait = false
			_cont_b[c.id] = now
			return
		if f == null:
			_skip[bkey] = now + 90.0
			_stat(c, "skips")
			_cont_b[c.id] = now
			return
		_blocked.erase(bkey)
		if sub:
			gw.econ.pay_substituted(c, Economy.build_cost(kind))
			_stat(c, "subst")
		else:
			gw.mil.pay_series(c, kind)
			gw.econ.pay_build(c, kind)
		_after_build(c, f, P)
		return




func _solar(c: Country, cap: City) -> bool:
	for kind: int in [Facility.Kind.SOLAR_FARM, Facility.Kind.SOLAR]:
		if kind == Facility.Kind.SOLAR_FARM and _count(c, kind) >= 3:
			continue
		var cost: int = Military.cost_of(kind)
		if c.money < cost + 150 or not c.has_res(Economy.res_cost("build_%d" % kind)):
			continue
		var f: Facility = _place(c, kind, cap)
		if f != null:
			c.money -= cost
			gw.econ.pay_build(c, kind)
			_after_build(c, f, persona_of(c))
			return true
	return false


func _after_build(c: Country, f: Facility, P: Dictionary) -> void :
	var st: Dictionary = stats.get(c.id, {})
	var b: Dictionary = st.get("built", {})
	b[f.kind] = int(b.get(f.kind, 0)) + 1
	st["built"] = b
	stats[c.id] = st
	match f.kind:
		Facility.Kind.MISSILE_FACTORY:
			match String(P.get("id", "")):
				"cautious":
					f.prod_type = Military.MT_SAM
				"adventurer":
					f.prod_type = Military.MT_CRUISE if gw.mil.has_kind(c.id, Facility.Kind.AIRFIELD) else Military.MT_BALLISTIC
				_:
					f.prod_type = Military.MT_BALLISTIC
		Facility.Kind.BARRACKS:
			_army_build(c, f, P)



func _army_build(c: Country, f: Facility, P: Dictionary) -> void :
	var builds: Array = P.get("builds", ["mix"])
	var k: int = 0
	for o: Facility in gw.mil.facilities:
		if o != f and o.kind == Facility.Kind.BARRACKS and o.country_id == c.id and o.army_build != "":
			k += 1
	var id: String = String(builds[k % builds.size()])
	if gw.econ.scarce_of(c).has("titanium") and c.titanium < 40 and (id == "armor" or id == "support"):
		id = "assault" if float(P["aggr"]) > 0.5 else "at"
	gw.army.set_build(f, id)




func _take_neutral(c: Country) -> void :
	var now: float = gw.game_time
	if now < float(_take_t.get(c.id, 120.0 + float(c.id) * 10.0)):
		return
	_take_t[c.id] = now + 75.0
	if c.city_ids.size() >= mini(8, int(D_TOWNS[GameConfig.diff_of(c)])) or c.money < Military.town_cost(c.towns_founded) + 500:
		return
	var lack: Array = gw.econ.scarce_of(c)
	if lack.is_empty():
		return
	var cap: City = gw.cities[c.capital_id]
	var best: Dictionary = {}
	var bd: float = INF
	var searches: int = 0
	for dp: Dictionary in gw.econ.deposits:
		var dc: Vector2i = dp["cell"]
		if dp["mine"] != null or (int(dp.get("left", 0)) < 150 and not GameConfig.infinite_res()) or not lack.has(String(dp.get("res", ""))):
			continue
		if gw.data.get_owner_id(dc.x, dc.y) != 0 or not _near_own_city(c, dc, GameWorld.TOWN_REACH + 4):
			continue
		searches += 1
		if searches > EXPAND_TRIES:
			break
		var reach: int = gw.diplo._dist_to_land(dc, c.id, GameWorld.TOWN_REACH - 12)
		if reach < 0:
			continue
		var d: float = Vector2(dc).distance_to(Vector2(cap.center))
		if d < bd:
			bd = d
			best = dp
	if best.is_empty():
		return
	var bc: Vector2i = best["cell"]
	for r in [14, 18, 22, 10, 26]:
		for a in range(0, 360, 45):
			var p: Vector2i = bc + Vector2i(roundi(cos(deg_to_rad(a)) * r), roundi(sin(deg_to_rad(a)) * r))
			if not gw.data.inside(p.x, p.y):
				continue
			var o: int = gw.data.get_owner_id(p.x, p.y)
			if o != 0 and o != c.id:
				continue
			var close: bool = false
			for oc: City in gw.cities:
				if absi(oc.center.x - p.x) + absi(oc.center.y - p.y) < GameWorld.MIN_CITY_DIST:
					close = true
					break
			if close or not _site_free(c, p):
				continue
			if gw.cad344 != null and not gw.cad344.plan_free(p, City.Kind.TOWN):
				_take_t[c.id] = now
				gw.cad344.take_cont[c.id] = true
				return
			var pl5: Dictionary = gw.can_found_city(p, City.Kind.TOWN) if gw.cad344 == null else gw.cad344.can_found_ai(p, City.Kind.TOWN)
			if not bool(pl5["ok"]) or preload("res://game/ad_relocate.gd").war_blocked(gw, p, c, int(pl5["radius"])):
				continue
			if gw.purchase_town(p, c, pl5) != null:
				_stat(c, "towns")
				gw.news_m(Loc.mk("%s ЗАНИМАЕТ МЕСТОРОЖДЕНИЕ (%s): НОВЫЙ ГОРОД", [Loc.name(c.name).to_upper(), String(Economy.RES_NAMES.get(String(best["res"]), "")).to_lower()]), "amber")
				return


func save_state() -> Dictionary:
	return {"personas": personas.duplicate(), "stats": stats.duplicate(true), "skip": _skip.duplicate(), "blocked": _blocked.duplicate(), 
		"take_t": _take_t.duplicate(), "t": _t.duplicate(), 
		"recon_wait": _recon_wait.duplicate(), "blind": _blind.duplicate(), "spend_cd": _spend_cd.duplicate(), 
		"spent": spent.duplicate(true), "saving": _saving.duplicate(), "cr_t": _cr_t.duplicate(), "off_t": _off_t.duplicate(), "bguard": guard.save_state(), 
		"cont_b": _cont_b.duplicate(), "cont_s": _cont_s.duplicate(true), "town_t": _town_t.duplicate(), "cont_a": _cont_a.duplicate(true), "air332": _air_job.duplicate(true)}


func load_state(d: Dictionary) -> void :
	personas = {}
	var pp: Dictionary = d.get("personas", {})
	for k: Variant in pp:
		personas[int(k)] = String(pp[k])
	stats = {}
	var st: Dictionary = d.get("stats", {})
	for k: Variant in st:
		stats[int(k)] = st[k]
	_skip = d.get("skip", {})
	_blocked = d.get("blocked", {})
	_take_t = {}
	var tt: Dictionary = d.get("take_t", {})
	for k: Variant in tt:
		_take_t[int(k)] = float(tt[k])
	_t = {}
	var t0: Dictionary = d.get("t", {})
	for k: Variant in t0:
		_t[int(k)] = float(t0[k])
	_recon_wait = (d.get("recon_wait", {}) as Dictionary).duplicate()
	_blind = (d.get("blind", {}) as Dictionary).duplicate()
	_spend_cd = (d.get("spend_cd", {}) as Dictionary).duplicate()
	spent = {}
	var sp: Dictionary = d.get("spent", {})
	for k: Variant in sp:
		spent[int(k)] = (sp[k] as Dictionary).duplicate()
	_saving = {}
	var sv: Dictionary = d.get("saving", {})
	for k: Variant in sv:
		_saving[int(k)] = int(sv[k])
	_cr_t = {}
	var ct: Dictionary = d.get("cr_t", {})
	for k: Variant in ct:
		_cr_t[int(k)] = float(ct[k])
	_off_t = {}
	var ot: Dictionary = d.get("off_t", {})
	for k: Variant in ot:
		_off_t[int(k)] = float(ot[k])
	guard.load_state(d.get("bguard", {}))
	_cont_b = {}
	var cb: Dictionary = d.get("cont_b", {})
	for k: Variant in cb:
		_cont_b[int(k)] = float(cb[k])
	_cont_s = {}
	var cs: Dictionary = d.get("cont_s", {})
	for k: Variant in cs:
		_cont_s[int(k)] = (cs[k] as Array).duplicate()
	_air_job = {}
	var aj: Dictionary = d.get("air332", {})
	for k: Variant in aj:
		_air_job[int(k)] = (aj[k] as Array).duplicate(true)
	_cont_a = {}
	var ca: Dictionary = d.get("cont_a", {})
	for k: Variant in ca:
		_cont_a[int(k)] = (ca[k] as Array).duplicate()
	_town_t = {}
	var tt2: Dictionary = d.get("town_t", {})
	for k: Variant in tt2:
		_town_t[int(k)] = float(tt2[k])


func update(_dt: float) -> void :
	for c: Country in gw.countries:
		if c.is_player or c.eliminated or c.capital_id < 0:
			continue
		if not _t.has(c.id):
			_t[c.id] = gw.game_time + float(c.id) * 1.7
		var nt: float = float(_t[c.id])
		var cad: Cad344 = gw.cad344
		if gw.game_time < nt:
			if cad != null:
				if cad.ai_ph.has(c.id):
					while cad.ai_ph.has(c.id) and cad.take_ai_slot():
						_think_step(c)
					continue
				if cad.exp_cont.has(c.id) or cad.take_cont.has(c.id):
					if cad.take_ai_slot():
						if cad.exp_cont.has(c.id):
							cad.exp_cont.erase(c.id)
							_grow_land(c)
						else:
							cad.take_cont.erase(c.id)
							_take_neutral(c)
					continue
				if not _go_due(c) or not cad.take_ai_slot():
					continue
			_go_on(c)
			continue
		_cont_b.erase(c.id)
		_cont_s.erase(c.id)
		_t[c.id] = gw.game_time + GameConfig.ai_think_dt(c) * GameConfig.ai_pace(gw.game_time)
		if cad != null:
			cad.ai_ph[c.id] = 0
			while cad.ai_ph.has(c.id) and cad.take_ai_slot():
				_think_step(c)
			continue
		_think(c)



func _go_due(c: Country) -> bool:
	var now: float = gw.game_time
	return (_cont_b.has(c.id) and float(_cont_b[c.id]) < now) or (_cont_s.has(c.id) and float(_cont_s[c.id][0]) < now)\
	or (_cont_a.has(c.id) and float(_cont_a[c.id][0]) < now)



func _think_step(c: Country) -> void :
	var cad: Cad344 = gw.cad344
	var ph: int = int(cad.ai_ph[c.id])
	if ph + 1 >= THINK_PARTS:
		cad.ai_ph.erase(c.id)
	else:
		cad.ai_ph[c.id] = ph + 1
	_think_part(c, ph, true)






var _cont_b: Dictionary = {}
var _cont_s: Dictionary = {}
var _cont_a: Dictionary = {}
var _place_wait: bool = false


func _go_on(c: Country) -> void :
	var now: float = gw.game_time
	if _cont_b.has(c.id):
		if float(_cont_b[c.id]) < now:
			_cont_b.erase(c.id)
			_build(c, true)
	elif _cont_s.has(c.id) and float(_cont_s[c.id][0]) < now:
		var e: Array = _cont_s[c.id]
		_cont_s.erase(c.id)
		_spend_surplus(c, persona_of(c), int(e[1]))
	elif _cont_a.has(c.id) and float(_cont_a[c.id][0]) < now:
		_attack_next(c)




func _attack_next(c: Country) -> void :
	var e: Array = _cont_a[c.id]
	var ids: Array = e[2]
	var cid: int = int(e[1])
	var city: City = gw.cities[cid] if cid >= 0 and cid < gw.cities.size() else null
	while not ids.is_empty():
		var fid: int = int(ids[0])
		ids.remove_at(0)
		var h: Facility = null
		for f: Facility in gw.mil.facilities:
			if f.id == fid:
				h = f
				break
		if city == null or not c.at_war.has(city.country_id) or h == null or h.country_id != c.id or not gw.mil.alive(h) or _rg.has(h):
			continue
		if h.group_id >= 0 and FrontPlan.holds_fac(gw, h):
			continue
		if gw.naval != null and gw.naval.busy(h):
			continue
		gw.army.order_attack(c.id, city, h)
		break
	if ids.is_empty():
		_cont_a.erase(c.id)
	else:
		_cont_a[c.id] = [gw.game_time, cid, ids]


func _count(c: Country, kind: int) -> int:
	var n: int = 0
	for f: Facility in gw.mil.facilities:
		if f.country_id == c.id and f.kind == kind:
			n += 1
	return n


func _think(c: Country) -> void :
	for ph in THINK_PARTS:
		_think_part(c, ph)




const THINK_PARTS: int = 8


func _think_part(c: Country, ph: int, split: bool = false) -> void :
	match ph:
		0:
			_repair(c)
			if gw.get("navy") != null:
				gw.navy.ai_think(c)
		1:
			_grow_land(c)
		2:
			_build(c)
		3:
			_aviation(c)
			_take_neutral(c)
		4:
			var P: Dictionary = persona_of(c)
			if gw.naval != null:
				gw.naval.ai_think(c, P)
			_spend_surplus(c, P)
			_missile_mix(c, P)
			for f: Facility in gw.mil.facilities:
				if f.country_id == c.id and (f.halted or f.stance != 0):
					f.halted = false
					f.stance = 0
				if f.kind == Facility.Kind.BARRACKS and f.country_id == c.id and f.army_build == "":
					_army_build(c, f, P)
		5:
			var P5: Dictionary = persona_of(c)
			if not c.at_war.is_empty():
				_war(c)
				if split:
					gw.cad344.war_br[c.id] = true
				else:
					_rear_guard(c)
					_guard_bridges(c, P5)
			else:


				var foe: Country = _tension_foe(c, P5)
				if foe != null:
					_fortify(c, foe, false)
		6:
			if split and gw.cad344.war_br.has(c.id):
				gw.cad344.war_br.erase(c.id)
				_rear_guard(c)
				_guard_bridges(c, persona_of(c))
		7:
			_fronts(c, persona_of(c))



var _tens: Dictionary = {}
func _tension_foe(c: Country, P: Dictionary) -> Country:
	var e: Array = _tens.get(c.id, [-1.0, -1])
	if gw.game_time < float(e[0]):
		return gw.country_by_id(int(e[1])) if int(e[1]) >= 0 else null
	var dp: Diplomacy = gw.diplo
	var mass: Dictionary = {}
	for cid in c.city_ids:
		var city: City = gw.cities[cid]
		for o: Variant in gw.army._near(Vector2(city.center * GameWorld.CELL), float(city.radius * GameWorld.CELL) + 500.0):
			var u: Unit = o
			if u.country_id != c.id and u.alive() and u.ground():
				mass[u.country_id] = int(mass.get(u.country_id, 0)) + 1
	var best: Country = null
	var bv: int = 0
	var low: int = -45 if float(P["caution"]) > 0.6 else -60
	for o: Country in gw.countries:
		if o == c or o.eliminated or o.capital_id < 0 or dp.allied(c.id, o.id):
			continue
		var v: int = 0
		if dp._has_demand(o.id, c.id) or dp._has_demand(c.id, o.id):
			v += 3
		var r: int = dp.relation(c.id, o.id)
		if r < low:
			v += 2 + (1 if r < -80 else 0)
		if int(mass.get(o.id, 0)) >= 6:
			v += 3
		if v > bv:
			bv = v
			best = o
	_tens[c.id] = [gw.game_time + 10.0, best.id if best != null else -1]
	if best != null:
		_stat(c, "r22b_tense")
	return best


func _repair(c: Country) -> void :
	for f: Facility in gw.mil.facilities:
		if f.country_id == c.id and gw.mil.can_restore(f) and f.ruined_at >= 0.0 and gw.game_time - f.ruined_at > 40.0 and c.money >= Military.restore_cost(f) + 300:
			gw.mil.restore(f, c)
			return


func _place(c: Country, kind: int, cap: City) -> Facility:
	var mil: Military = gw.mil
	if kind == Facility.Kind.DP_RAMP or kind == Facility.Kind.DP_RUNWAY or kind == Facility.Kind.DP_STORE or kind == Facility.Kind.SOLAR:
		for port: Facility in mil.facilities:
			if port.country_id != c.id or not mil.alive(port):
				continue
			if kind == Facility.Kind.SOLAR:

				if (port.kind != Facility.Kind.DRONE_FACTORY and port.kind != Facility.Kind.DRONE_PORT) or mil.has_power(port):
					continue
			elif port.kind != Facility.Kind.DRONE_PORT:
				continue
			if true:
				for r in range(4, Military.MODULE_R, 3):
					for a in range(0, 360, 30):
						var p: Vector2i = port.cell + port.size / 2 + Vector2i(roundi(cos(deg_to_rad(a)) * r), roundi(sin(deg_to_rad(a)) * r))
						if mil.check_place(kind, Military.nw_for(kind, p), c, port, false) == "":
							return mil.build(kind, p, c, port, true)
		return null
	if Economy.is_eco_site(kind):
		var fe: Facility = gw.econ.ai_place(c, kind)
		if fe == null and ((kind == Facility.Kind.PORT and gw.econ.ports.site_pending(c)) or (kind == Facility.Kind.NAVAL_BASE and gw.get("navy") != null and gw.navy.site_pending(c))):
			_place_wait = true
		return fe

	if gw.guide != null and EconGuide.SMART_KINDS.has(kind):
		var sc: Vector2i = gw.guide.smart_cell_ai(c, kind)
		if sc.x < 0 and gw.guide.smart_pending(c, kind):
			_place_wait = true
			return null
		if sc.x >= 0:
			var f0: Facility = mil.build(kind, sc, c, null, true)
			if f0 != null:
				return f0
	if kind == Facility.Kind.AIRFIELD or kind == Facility.Kind.DRONE_PORT:
		return _air_place(c, kind)

	var center: Vector2i = cap.center
	if not Defense.is_ad(kind) and kind != Facility.Kind.AD_RADAR and kind != Facility.Kind.AD_EW and c.city_ids.size() > 1:
		var h: int = Hash32.h2(c.id, int(gw.game_time), kind) % c.city_ids.size()
		center = gw.cities[c.city_ids[h]].center
	var r0: int = gw.cities[c.capital_id].radius + 4
	if kind >= Facility.Kind.AD_SPAAG and kind <= Facility.Kind.AD_INT:
		var ac: City = _ad_city(c)
		if ac == null:
			return null
		center = ac.center
		r0 = ac.radius + 4
	return mil.auto_place(kind, center, c, r0, r0 + 50)







const AIR_SAFE_SMALL: float = 180.0
const AIR_SAFE_BIG: float = 240.0


static func air_safe() -> float:
	return lerpf(AIR_SAFE_SMALL, AIR_SAFE_BIG, Defense.map_k)





const DP_SAFE_K: float = 0.5


static func air_safe_for(kind: int) -> float:
	return air_safe() * (DP_SAFE_K if kind == Facility.Kind.DRONE_PORT else 1.0)




func foreign_px(cid: int, p: Vector2, lim: float) -> float:
	var dt: WorldData = gw.data
	var ow: PackedByteArray = dt.owners
	var dw: int = dt.w
	var dh: int = dt.h
	var dirs: PackedVector2Array = _fdirs()
	var best: float = lim
	for k in 48:
		var dir: Vector2 = dirs[k]
		var s: float = 0.0
		while s < best:
			var q: Vector2 = p + dir * s
			var cx: int = floori(q.x / GameWorld.CELL)
			var cy: int = floori(q.y / GameWorld.CELL)
			if cx < 0 or cy < 0 or cx >= dw or cy >= dh:
				best = s
				break
			var o: int = ow[cy * dw + cx]
			if o > 0 and o != cid:
				best = s
				break
			s += 8.0
	return best



static var _FDIR: PackedVector2Array = PackedVector2Array()


static func _fdirs() -> PackedVector2Array:
	if _FDIR.is_empty():
		for k in 48:
			_FDIR.append(Vector2.from_angle(TAU * float(k) / 48.0))
	return _FDIR



func _foreign_near(cid: int, p: Vector2, r: float) -> bool:
	var dt: WorldData = gw.data
	var ow: PackedByteArray = dt.owners
	var dw: int = dt.w
	var dh: int = dt.h
	var dirs: PackedVector2Array = _fdirs()
	for k in 48:
		var dir: Vector2 = dirs[k]
		var s: float = 0.0
		while s < r:
			var q: Vector2 = p + dir * s
			var cx: int = floori(q.x / GameWorld.CELL)
			var cy: int = floori(q.y / GameWorld.CELL)
			if cx < 0 or cy < 0 or cx >= dw or cy >= dh:
				return true
			var o: int = ow[cy * dw + cx]
			if o > 0 and o != cid:
				return true
			s += 8.0
	return false







const AIR_FD_N: int = 1
const AIR_CP: int = 24
const AIR_JOB_MAX_S: float = 60.0
var _air_job: Dictionary = {}


func _air_place(c: Country, kind: int) -> Facility:
	var mil: Military = gw.mil
	var safe: float = air_safe_for(kind)
	var now: float = gw.game_time
	var j: Array = _air_job.get(c.id, [])
	if j.size() != 7 or int(j[0]) != kind or now - float(j[1]) > AIR_JOB_MAX_S:
		j = [kind, now, c.city_ids.duplicate(), [], [], 0, -1]
		_air_job[c.id] = j
	var ids: Array = j[2]
	var fds: Array = j[3]
	if fds.size() < ids.size():
		for n in AIR_FD_N:
			if fds.size() >= ids.size():
				break
			var cid0: int = int(ids[fds.size()])
			fds.append(foreign_px(c.id, Vector2(gw.cities[cid0].center * GameWorld.CELL), safe + 400.0) + (1.0 if cid0 == c.capital_id else 0.0))
		if fds.size() < ids.size():
			_place_wait = true
			return null
	var cs: Array = []
	for k in ids.size():
		var ct: City = gw.cities[int(ids[k])]
		if ct.country_id != c.id:
			continue
		var fd: float = float(fds[k])
		if fd + float(ct.radius + 50) * GameWorld.CELL >= safe:
			cs.append([fd, ct])
	cs.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]) or (float(x[0]) == float(y[0]) and (x[1] as City).id < (y[1] as City).id))
	var done: Array = j[4]
	var budget: int = AIR_CP
	for e: Array in cs:
		var ct2: City = e[1]
		if done.has(ct2.id):
			continue
		var r0: int = ct2.radius + 4
		var pi0: int = int(j[5]) if int(j[6]) == ct2.id else 0
		for q in range(pi0, 17 * 18):
			var r: int = r0 + (q / 18) * 3
			var a: int = (q % 18) * 20
			var p: Vector2i = ct2.center + Vector2i(roundi(cos(deg_to_rad(a)) * r), roundi(sin(deg_to_rad(a)) * r))
			if not gw.data.inside(p.x, p.y) or gw.data.get_owner_id(p.x, p.y) != c.id:
				continue
			if budget <= 0:
				j[5] = q
				j[6] = ct2.id
				_place_wait = true
				return null
			budget -= 1
			if mil.check_place(kind, Military.nw_for(kind, p), c, null, false) == "" and not _foreign_near(c.id, Vector2(p * GameWorld.CELL), safe):
				_air_job.erase(c.id)
				_stat(c, "r332_air_site")
				return mil.build(kind, p, c, null, true)
		done.append(ct2.id)
		j[5] = 0
	_air_job.erase(c.id)
	_stat(c, "r332_air_nosite")
	return null




func air_route_ok(c: Country, from: Vector2, to: Vector2, r: float) -> bool:
	var dt: WorldData = gw.data
	var n: int = maxi(1, ceili(from.distance_to(to) / 8.0))
	for i in range(0, n + 1):
		var q: Vector2 = from.lerp(to, float(i) / float(n))
		var cx: int = floori(q.x / GameWorld.CELL)
		var cy: int = floori(q.y / GameWorld.CELL)
		if not dt.inside(cx, cy):
			return false
		var o: int = dt.get_owner_id(cx, cy)
		if o > 0 and o != c.id and not _air_legal(c.id, o):
			return false
	if r <= 0.0:
		return true
	var ring: float = r + 24.0
	for k in 16:
		var dir: = Vector2.from_angle(TAU * float(k) / 16.0)
		var s: float = 8.0
		while s <= ring:
			var q2: Vector2 = to + dir * s
			var x2: int = floori(q2.x / GameWorld.CELL)
			var y2: int = floori(q2.y / GameWorld.CELL)
			if not dt.inside(x2, y2):
				return false
			var o2: int = dt.get_owner_id(x2, y2)
			if o2 > 0 and o2 != c.id and not _air_legal(c.id, o2):
				return false
			s += 8.0
	return true


func _owner_at(p: Vector2) -> int:
	var cx: int = floori(p.x / GameWorld.CELL)
	var cy: int = floori(p.y / GameWorld.CELL)
	return gw.data.get_owner_id(cx, cy) if gw.data.inside(cx, cy) else -1


func _air_legal(a: int, b: int) -> bool:
	var dp: Diplomacy = gw.diplo
	return dp == null or dp.at_war(a, b) or dp.allied(a, b) or dp.has_passage(a, b) or (dp.ally != null and dp.ally.same(a, b))




func _enemies(c: Country) -> Array[Country]:
	var out: Array[Country] = []
	for id: int in c.at_war.keys():
		var e: Country = gw.country_by_id(id)
		if e != null and not e.eliminated and e.capital_id >= 0:
			out.append(e)
	return out


func _war(c: Country) -> void :
	var foes: Array[Country] = _enemies(c)
	if foes.is_empty():
		return
	var cap: Vector2 = Vector2(gw.cities[c.capital_id].center * GameWorld.CELL)

	var foe: Country = foes[0]
	var bd: float = INF
	for e: Country in foes:
		var d: float = Vector2(gw.cities[e.capital_id].center * GameWorld.CELL).distance_to(cap)
		if d < bd:
			bd = d
			foe = e

	var go: bool = _intel_ok(c, foe, persona_of(c))
	_redirect(c, foe)


	var soft: bool = foe.is_player and gw.diplo.war_time(c.id, foe.id) < SOFT_WAR
	var hold: bool = soft and gw.game_time < float(_victim_t.get(foe.id, -1.0))
	if go and not hold:
		_soft = soft
		var s0: int = gw.mil.parked_count(c.id) + gw.mil.missiles_ready(c.id) * 100
		var cr0: float = float(_cr_t.get(c.id, 0.0))
		_drones(c, foe, cap)
		_missiles(c, foe)
		_air_strike(c, foe)
		_soft = false
		if soft and (gw.mil.parked_count(c.id) + gw.mil.missiles_ready(c.id) * 100 < s0 or float(_cr_t.get(c.id, 0.0)) > maxf(cr0, gw.game_time + 20.0)):
			_victim_t[foe.id] = gw.game_time + float(SOFT_GAP[GameConfig.diff_of(c)])
	else:
		_hold_kab(c)
	_fortify(c, foe)
	if go:
		_offensive(c, foe)
	else:
		_stat(c, "off_intel")


var _pick_f: Facility = null




const AI_RESTRIKE: float = 60.0
const CITY_SPOT_T: float = 600.0
const CITY_GAP: float = 45.0
var _hit_f: Dictionary = {}
var _hit_spots: Dictionary = {}
var _pick_cls: String = ""
var _pick_pt: Vector2 = Vector2.INF
const SOFT_WAR: float = 300.0
const SOFT_GAP: Array = [90.0, 60.0, 45.0]
var _victim_t: Dictionary = {}
var _soft: bool = false



func _pick_target(c: Country, foe: Country, from: Vector2, max_d: float, cls: String = "") -> Vector2:
	var best: = Vector2.INF
	var bs: float = -1.0
	var cooled: int = 0
	_pick_f = null
	_pick_pt = Vector2.INF
	_pick_cls = cls
	_pick_risk = 0.0
	_pick_br = false
	_pick_hold = -1
	_pick_alts.clear()
	var v_tr: int = 0
	var v_dup: int = 0
	var strike: bool = cls != "" and sense != null
	var assault: Dictionary = _assault_cities(c) if strike else {}
	for f: Facility in gw.mil.facilities:
		if (f.country_id != foe.id and gw.diplo.sky_target(c.id, f) != foe.id) or f.parent != null or not gw.mil.alive(f) or f.moving:
			continue
		var p: Vector2 = f.center_px()
		var d: float = p.distance_to(from)
		if d > max_d:
			continue

		if not gw.mil.can_strike_target(f, c.id) or gw.game_time - float(_hit_f.get("%d>%d" % [c.id, f.id], -1000000000.0)) < AI_RESTRIKE:
			cooled += 1
			continue
		if gw.diplo != null and gw.diplo.has_method("react_restrained") and gw.diplo.react_restrained(c.id, foe.id, f.kind):
			continue
		var risk: float = 0.0
		if strike:



			risk = sense.ad_risk(c, from, p, cls)
			if sense.inbound_at(c, p, float(maxi(f.size.x, f.size.y)) * GameWorld.CELL * 0.5 + 12.0) >= SenseS.need(risk):
				cooled += 1
				v_dup += 1
				continue
			if sense.aim_veto(c.id, p, cls) != "":
				v_tr += 1
				continue
		var w: float = 1.0
		match f.kind:
			Facility.Kind.POWER_PLANT:
				w = 5.0
			Facility.Kind.REFINERY, Facility.Kind.MISSILE_FACTORY, Facility.Kind.DRONE_FACTORY:
				w = 3.5
			Facility.Kind.AIRFIELD, Facility.Kind.DRONE_PORT, Facility.Kind.BARRACKS:
				w = 3.0
			Facility.Kind.CIV_FACTORY, Facility.Kind.MINE, Facility.Kind.FARM:
				w = 2.0
			Facility.Kind.PORT:
				w = 2.4
		if strike and _assault_near(assault, p) and (f.kind == Facility.Kind.BARRACKS or Defense.is_ad(f.kind) or f.kind == Facility.Kind.TEL or f.kind == Facility.Kind.DRONE_PORT):
			w += 1.5

		var sc: float = w * 1000.0 * SenseS.value_k(risk) - d * 0.1 + float(Hash32.h2(c.id, f.id, int(gw.game_time / 30.0)) % 300)
		if strike and gw.diplo.trace_on:
			_pick_alts.append([sc, Loc.t("%s %.1f/р%.1f") % [String(Military.TITLES.get(f.kind, "?")), w, risk]])
		if sc > bs:
			bs = sc
			best = p
			_pick_f = f
			_pick_risk = risk
			_pick_w = w
	if strike and gw.hold != null:




		var big: bool = cls == "missile" or cls == "air"
		for he: Array in gw.hold.strike_spots(c.id):
			if int(he[2]) != foe.id or not gw.hold.hit_ok(c.id, int(he[3]), cls):
				continue
			var hw: float = float(he[7]) if big else float(he[4])
			if big and int(he[5]) == c.id:
				continue
			var hp: Vector2 = he[0]
			var hd: float = hp.distance_to(from)
			if hw <= 0.0 or hd > max_d:
				continue
			var hr: float = sense.ad_risk(c, from, hp, cls)
			if cls == "drone" and hr >= float(gw.hold.D_DRONE_RISK[gw.hold.diff_i(c.id)]):
				continue
			if sense.inbound_at(c, hp, 24.0) >= SenseS.need(hr):
				v_dup += 1
				continue
			if gw.hold.strike_veto(c.id, hp, cls) != "":
				v_tr += 1
				continue
			var hs: float = hw * 1000.0 * SenseS.value_k(hr) - hd * 0.1 + float(Hash32.h2(c.id, int(he[3]), int(gw.game_time / 30.0)) % 300)
			if gw.diplo.trace_on:
				_pick_alts.append([hs, Loc.t("дом с гарнизоном %d %.1f/р%.1f") % [int(he[1]), hw, hr]])
			if hs > bs:
				bs = hs
				best = hp
				_pick_f = null
				_pick_risk = hr
				_pick_w = hw
				_pick_hold = int(he[3])
	if gw.get("supply") != null:

		var bp: Array = gw.supply.ai_bridge_pick(c, foe, from, max_d)
		var brisk: float = sense.ad_risk(c, from, bp[1], cls) if strike and not bp.is_empty() else 0.0
		if not bp.is_empty() and float(bp[0]) * SenseS.value_k(brisk) > bs * 0.45:
			gw.supply.ai_bridge_used(c)
			_pick_f = null
			_pick_pt = bp[1]
			_pick_w = float(bp[0]) / 1000.0
			_pick_risk = brisk
			_pick_br = true
			_pick_hold = -1
			return bp[1]
	if strike and (v_tr > 0 or v_dup > 0):
		sense.log(c, Loc.t("удар %s: целей отклонено %d") % [cls, v_tr + v_dup], Loc.t("свои / не враги у цели %d, уже летит своё / союзное %d") % [v_tr, v_dup], float(v_tr + v_dup), "s_veto")
	if best == Vector2.INF and cooled > 0:
		return best
	if best == Vector2.INF:


		var spots: Array = []
		var last: float = -1000000000.0
		for e: Array in _hit_spots.get(c.id, []):
			if gw.game_time - float(e[1]) < CITY_SPOT_T:
				spots.append(e[0])
			if e.size() > 2 and String(e[2]) == cls:
				last = maxf(last, float(e[1]))
		if gw.game_time - last < CITY_GAP:
			return best
		for cid in foe.city_ids:
			if Vector2(gw.cities[cid].center * GameWorld.CELL).distance_to(from) <= max_d:


				for k29 in 4:
					var p2: Vector2 = gw.mil.city_aim(gw.cities[cid], c.id, spots, int(gw.game_time / 30.0) + k29 * 7)
					if p2 == Vector2.INF or p2.distance_to(from) > max_d:
						break
					if strike and (sense.aim_veto(c.id, p2, cls) != "" or sense.inbound_at(c, p2, Military.STRIKE_SPOT_R) > 0):
						continue
					_pick_pt = p2
					_pick_risk = sense.ad_risk(c, from, p2, cls) if strike else 0.0
					_pick_w = 0.5
					return p2
	_pick_pt = best
	return best


var _pick_risk: float = 0.0
var _pick_w: float = 0.0
var _pick_br: bool = false
var _pick_hold: int = -1
var _pick_alts: Array = []





func _redirect(c: Country, foe: Country) -> void :
	if sense == null:
		return
	for d: Drone in gw.mil.drones:
		if d.country_id != c.id or d.kind == 1 or d.state == Drone.State.PARKED or d.state == Drone.State.DIVE or d.state == Drone.State.DONE:
			continue
		var tf: Facility = gw.mil.target_fac(d.target)
		var cell: = Vector2i(floori(d.target.x / GameWorld.CELL), floori(d.target.y / GameWorld.CELL))
		var own: int = tf.country_id if tf != null else (gw.data.get_owner_id(cell.x, cell.y) if gw.data.inside(cell.x, cell.y) else 0)
		var why: String = ""
		var ha: int = int(gw.hold.hold_aim(c.id, d.target)) if gw.hold != null else -1
		if ha == 0:
			why = Loc.t("гарнизон ушёл из дома")
		elif own > 0 and not c.at_war.has(own) and not (ha == 1 and own == c.id):
			why = Loc.t("цель теперь не вражеская (%s)") % gw.diplo._cname(own)
		else:
			why = gw.hold.strike_veto(c.id, d.target, "drone") if ha == 1 else sense.aim_veto(c.id, d.target, "drone")
		if why == "":
			continue
		var from: Vector2 = d.pos if d.state >= Drone.State.BOOST else gw.mil.launch_point(d.airfield)
		var left: float = (d.range_px - d.flown) if d.state >= Drone.State.BOOST else d.range_px
		var p: Vector2 = _pick_target(c, foe, from, left * 0.85, "drone")
		if p != Vector2.INF and gw.mil.retarget(d, p, false) == "":
			_stat(c, "drone_redirect")
			sense.log(c, Loc.t("дрон перенацелен"), why, 0.0, "s_redirect")



func _assault_cities(c: Country) -> Dictionary:
	var out: Dictionary = {}
	for u: Unit in gw.army.units:
		if u.target_city >= 0 and u.alive() and (u.country_id == c.id or gw.diplo.allied(c.id, u.country_id)):
			out[u.target_city] = true
	return out


func _assault_near(assault: Dictionary, p: Vector2) -> bool:
	for cid: int in assault.keys():
		if cid < gw.cities.size() and Vector2(gw.cities[cid].center * GameWorld.CELL).distance_to(p) < float(gw.cities[cid].radius * GameWorld.CELL) + 700.0:
			return true
	return false



func _log_strike(c: Country, cls: String, n: int, t: Vector2) -> void :
	if sense == null or gw.diplo == null or not gw.diplo.trace_on:
		return
	var what: String = Loc.t("мост") if _pick_br else (Loc.t("дом с гарнизоном") if _pick_hold >= 0 else (String(Military.TITLES.get(_pick_f.kind, "объект")) if _pick_f != null else Loc.t("город")))
	_pick_alts.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var alts: PackedStringArray = PackedStringArray()
	for i in mini(3, _pick_alts.size()):
		alts.append(String(_pick_alts[i][1]))
	sense.log(c, Loc.t("удар %s ×%d → %s") % [cls, n, what], Loc.t("ценность %.1f, ПВО-риск %.2f (x%.2f); лучшие: %s") % [_pick_w, _pick_risk, SenseS.value_k(_pick_risk), ", ".join(alts)], _pick_w * SenseS.value_k(_pick_risk), "s_launch")



func _note_hit(c: Country) -> void :
	var now: float = gw.game_time
	if _pick_hold >= 0 and gw.hold != null:
		gw.hold.note_hit(c.id, _pick_hold, _pick_cls)
		return
	if _pick_f != null:
		_hit_f["%d>%d" % [c.id, _pick_f.id]] = now
		if _hit_f.size() > 256:
			for k: Variant in _hit_f.keys():
				if now - float(_hit_f[k]) >= AI_RESTRIKE:
					_hit_f.erase(k)
	elif _pick_pt != Vector2.INF:
		var a: Array = _hit_spots.get(c.id, [])
		a.append([_pick_pt, now, _pick_cls])
		while a.size() > 64 or ( not a.is_empty() and now - float(a[0][1]) >= CITY_SPOT_T):
			a.pop_front()
		_hit_spots[c.id] = a


func _drones(c: Country, foe: Country, cap: Vector2) -> void :
	var mil: Military = gw.mil
	var have: int = mil.parked_count(c.id)
	var min_n: int = [3, 2, 1][GameConfig.diff_of(c)]
	if have < min_n:
		return
	var port: Facility = mil.best_port(c, cap)
	if port == null:
		return
	var from: Vector2 = mil.launch_point(port)
	var t: Vector2 = _pick_target(c, foe, from, Military.RANGE_PX * 0.9, "drone")
	if t == Vector2.INF:
		return

	var thr: int = gw.diplo.cross_block(c.id, from, t)
	if thr > 0 and not gw.diplo.ai_want_passage(c.id, thr, foe.id):
		_stat(c, "drone_no_pass")
		return
	var n_max: int = [2, 4, 6][GameConfig.diff_of(c)] + (1 if float(persona_of(c)["aggr"]) > 0.7 else 0)
	var n: int = mini(have, n_max)
	if sense != null:



		var want: int = clampi(1 + floori(_pick_risk * 1.5), 1, maxi(1, mini(n_max, mil.drone_capacity(c.id))))
		if _pick_risk >= 1.0 and have < want:
			_stat(c, "drone_mass")
			sense.log(c, Loc.t("дроны ждут: %d из %d") % [have, want], Loc.t("у цели ПВО-риск %.2f") % _pick_risk, _pick_risk, "s_wait")
			return
		n = mini(n, want)
	if _soft:
		n = mini(n, 2)
	var wps: Array[Vector2] = []

	var mid: Vector2 = from.lerp(t, 0.5) + (t - from).orthogonal().normalized() * float(Hash32.h2(c.id, int(gw.game_time), 3) % 400 - 200)
	if from.distance_to(mid) + mid.distance_to(t) < Military.RANGE_PX * 0.95\
	and gw.diplo.path_block(c.id, PackedVector2Array([from, mid, t])) <= 0:
		wps.append(mid)
	var sent: int = mil.launch(c, wps, t, n).size()


	var jets: int = 2 if sense == null else clampi(n - sent, 0, 2)
	if jets > 0:
		sent += mil.launch(c, wps, t, jets, true).size()
	if sent > 0:
		_log_strike(c, Loc.t("БПЛА"), sent, t)
		_note_hit(c)


func _missiles(c: Country, foe: Country) -> void :
	var mil: Military = gw.mil
	if mil.missiles_ready(c.id) <= 0:
		return
	for f: Facility in mil.facilities:
		if f.kind != Facility.Kind.TEL or f.country_id != c.id or not mil.alive(f) or f.missiles <= 0 or not f.queued.is_empty():
			continue
		var t: Vector2 = _pick_target(c, foe, f.center_px(), Military.MISSILE_RANGE, "missile")
		if t != Vector2.INF and f.center_px().distance_to(t) >= Military.MISSILE_MIN:
			if mil.launch_missiles(c, t, 1) > 0:
				_log_strike(c, Loc.t("БР"), 1, t)
				_note_hit(c)
			return




const ASSAULT_DELAY: float = 150.0
const OFFENSIVE_GAP: float = 40.0
var _off_t: Dictionary = {}



const OFFENSIVE_GAP_SEA: float = 90.0
const SEA_WAVES: int = 3
const SEA_GIVEUP: float = 900.0
var _sea_w: Dictionary = {}
var _sea_skip: Dictionary = {}
var _reach: Dictionary = {}
var _futile: Dictionary = {}



func _land_reach(c: Country, from: Vector2, city: City) -> bool:
	var k: String = "%d>%d" % [c.id, city.id]
	var e: Array = _reach.get(k, [])
	if e.size() == 2 and gw.game_time - float(e[1]) < 60.0:
		return bool(e[0])
	gw.econ.nav_path(from, Vector2(city.center * GameWorld.CELL))
	var ok: bool = gw.econ.nav_last_ok
	_reach[k] = [ok, gw.game_time]
	return ok




func _sea_need(c: Country, city: City) -> int:
	var cap: int = 0
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.BARRACKS and f.country_id == c.id and gw.mil.alive(f):
			cap += gw.army.cap_of(f)
	return clampi(10 + roundi(city.garrison_max / 100.0), 6, maxi(6, roundi(float(cap) * 0.85)))



func war_futile(cid: int, foe_id: int) -> bool:
	return gw.game_time - float(_futile.get("%d>%d" % [cid, foe_id], -999.0)) < 120.0


func _assault_wait(c: Country, foe: Country) -> bool:
	if not foe.is_player or gw.diplo.war_time(c.id, foe.id) >= ASSAULT_DELAY:
		return false
	var log: Array = gw.diplo.wars_log
	for i in range(log.size() - 1, -1, -1):
		var e: Array = log[i]
		if (int(e[1]) == c.id and int(e[2]) == foe.id) or (int(e[1]) == foe.id and int(e[2]) == c.id):
			return int(e[1]) != foe.id
	return true


func _offensive(c: Country, foe: Country) -> void :
	if _assault_wait(c, foe) or gw.game_time < float(_off_t.get(c.id, -1.0)):
		return
	if c.food <= 0:


		_stat(c, "off_starving")
		if sense != null:
			sense.log(c, Loc.t("наступление отложено"), Loc.t("армия голодает (еда %d)") % c.food, 0.0, "a_starve")
		_off_t[c.id] = gw.game_time + OFFENSIVE_GAP
		return


	var idle: Array[Unit] = []
	var at_idle: Array[Unit] = []
	var res: Facility = _reserve_home(c)
	for u0: Unit in gw.army.idle_units(c.id):
		if u0.home != null and (u0.home == res or _rg.has(u0.home)):
			continue
		if u0.home == null or u0.home.army_build != "at":
			idle.append(u0)
		else:
			at_idle.append(u0)
	var need: int = [6, 5, 4][GameConfig.diff_of(c)] + roundi(3.0 * GameConfig.early_damp(gw.game_time))
	if idle.size() + at_idle.size() < need:
		_stat(c, "off_few")
		return
	var land_short: bool = idle.size() < need
	var n_main: int = idle.size()
	if idle.is_empty():
		idle = at_idle.duplicate()
	var cen: = Vector2.ZERO
	for u: Unit in idle:
		cen += u.pos
	cen /= float(idle.size())
	var best: City = null
	var bd: float = INF

	var goal: Dictionary = gw.diplo.war_goals.get("%d>%d" % [c.id, foe.id], {})
	if not goal.is_empty():
		cen = Vector2(Vector2i(goal["cell"]) * GameWorld.CELL)
	var now: float = gw.game_time
	var skipped: int = 0
	var pass_blk: int = 0
	for cid in foe.city_ids:
		var city: City = gw.cities[cid]
		if now < float(_sea_skip.get("%d>%d" % [c.id, cid], -1.0)):
			skipped += 1
			continue
		var d0: float = Vector2(city.center * GameWorld.CELL).distance_to(cen)
		if d0 >= 5000.0:
			continue

		var thr: int = gw.diplo.cross_block(c.id, cen, Vector2(city.center * GameWorld.CELL))
		if thr > 0 and not gw.diplo.ai_want_passage(c.id, thr, foe.id):
			pass_blk += 1
			continue

		var d: float = d0 * (0.7 if city.kind == City.Kind.VILLAGE else 1.0) + (0.0 if not goal.is_empty() else city.garrison * 1.2 + (700.0 if city.kind == City.Kind.CAPITAL else 0.0))
		if gw.hold != null and goal.is_empty():
			d += float(gw.hold.held_in_city(cid, foe.id)) * 40.0
		if d < bd:
			bd = d
			best = city
	if best == null and pass_blk > 0:


		_stat(c, "off_no_pass")
		if gw.diplo.passage_pending(c.id):
			_off_t[c.id] = now + 15.0
		else:
			_futile["%d>%d" % [c.id, foe.id]] = now
			_off_t[c.id] = now + OFFENSIVE_GAP * 3.0
		return
	if best == null and skipped > 0:
		_futile["%d>%d" % [c.id, foe.id]] = now
		_off_t[c.id] = now + OFFENSIVE_GAP
		return
	if best != null:
		var wk: String = "%d>%d" % [c.id, best.id]
		var sea: bool = not _land_reach(c, cen, best)
		_stat(c, "off_sea" if sea else "off_land")
		var with_at: bool = false
		if sea:



			var ns: int = _sea_need(c, best)
			with_at = n_main < ns and n_main + at_idle.size() >= ns
			if n_main < ns and not with_at:
				_stat(c, "sea_mass")
				_off_t[c.id] = now + 15.0
				return
			if int(_sea_w.get(wk, 0)) >= SEA_WAVES:
				_sea_w.erase(wk)
				_sea_skip[wk] = now + SEA_GIVEUP
				_stat(c, "sea_giveup")
				_off_t[c.id] = now + 5.0
				return
		elif land_short:
			_stat(c, "off_few")
			_off_t[c.id] = now + 15.0
			return
		var sent: int = _attack_wo(c, best, res)
		if with_at:
			var hs: Dictionary = {}
			for u1: Unit in at_idle:
				if u1.home != null:
					hs[u1.home] = true
			for h: Facility in hs:
				sent += gw.army.order_attack(c.id, best, h)
			_stat(c, "sea_with_at")
		if sea and sent > 0:
			_sea_w[wk] = int(_sea_w.get(wk, 0)) + 1
			_stat(c, "sea_wave")
		_off_t[c.id] = now + ((OFFENSIVE_GAP_SEA if sea else OFFENSIVE_GAP) if sent > 0 else OFFENSIVE_GAP * 0.5)




const RG_R: float = 380.0
const RG_HOLD: float = 30.0
const RG_MIN: int = 4
var _rg_seen: Dictionary = {}
var _rg: Dictionary = {}





func _reserve_home(c: Country) -> Facility:
	if GameConfig.diff_of(c) < 2 and float(persona_of(c)["caution"]) <= 0.6 and not _capital_danger(c):
		return null
	var hs: Array[Facility] = []
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.BARRACKS and f.country_id == c.id and gw.mil.alive(f):
			if f.army_build == "at" and gw.army.units_of(f).size() >= 3:
				return null
			hs.append(f)
	if hs.size() < (4 if float(persona_of(c)["aggr"]) > 0.7 else 3):
		return null
	var cp: Vector2 = Vector2(gw.cities[c.capital_id].center * GameWorld.CELL)
	var best: Facility = null
	var bd: float = INF
	for f: Facility in hs:
		var d: float = f.center_px().distance_squared_to(cp)
		if d < bd:
			bd = d
			best = f
	return best




const CAP_DANGER_R: float = 1200.0
const CAP_DANGER_N: int = 4
func _capital_danger(c: Country) -> bool:
	if c.capital_id < 0 or c.at_war.is_empty():
		return false
	var cap: City = gw.cities[c.capital_id]
	var cp: Vector2 = Vector2(cap.center * GameWorld.CELL)
	var r: float = float(cap.radius * GameWorld.CELL) + CAP_DANGER_R
	var n: int = 0
	for o: Variant in gw.army._near(cp, r):
		var u: Unit = o
		if u.alive() and u.ground() and c.at_war.has(u.country_id) and u.pos.distance_squared_to(cp) <= r * r and gw.army.fire.sees(c.id, u):
			n += 1
			if n >= CAP_DANGER_N:
				if sense != null:
					sense.log(c, Loc.t("резерв у столицы"), Loc.t("враг у столицы: %d+") % n, float(n), "a_reserve")
				return true
	return false




func _attack_wo(c: Country, city: City, res: Facility) -> int:
	var hs: Dictionary = {}
	for u: Unit in gw.army.units:
		if u.country_id == c.id and u.home != null and u.alive() and u.type != Unit.Type.FPV:
			hs[u.home] = true
	var sent: int = 0
	var later: Array = []
	for h: Facility in hs:
		if h == res or h.army_build == "at" or _rg.has(h) or not gw.mil.facilities.has(h):
			continue
		if h.group_id >= 0 and FrontPlan.holds_fac(gw, h):
			continue
		if gw.naval != null and gw.naval.busy(h):
			continue
		if sent > 0 or not later.is_empty():
			later.append(h.id)
			continue
		sent += gw.army.order_attack(c.id, city, h)
		if sent <= 0:
			later.append(-1)
	later.erase(-1)
	if not later.is_empty():
		_cont_a[c.id] = [gw.game_time, city.id, later]
	return sent + later.size()



func _city_threat(c: Country, city: City) -> Array:
	var cp: Vector2 = Vector2(city.center * GameWorld.CELL)
	var r: float = float(city.radius * GameWorld.CELL) + RG_R
	var ne: int = 0
	var no: int = 0
	var s: = Vector2.ZERO
	var who: int = -1
	for o: Variant in gw.army._near(cp, r):
		var u: Unit = o
		if not u.alive() or not u.ground() or u.pos.distance_squared_to(cp) > r * r:
			continue
		if u.country_id == c.id:
			if u.target_city < 0 and u.type != Unit.Type.FPV:
				no += 1
		elif c.at_war.has(u.country_id) and gw.army.fire.sees(c.id, u):
			ne += 1
			s += u.pos
			who = u.country_id
	return [ne, s / float(maxi(1, ne)), no, who]






func _rear_guard(c: Country) -> void :
	var tac: Army.ArmyTac = gw.army.tac
	var now: float = gw.game_time
	for h: Facility in _rg.keys():
		if h.country_id != c.id and gw.mil.facilities.has(h):
			_rg.erase(h)
			continue
		if h.country_id != c.id:
			continue
		var cid: int = int(_rg[h][0])
		var gone: bool = not c.city_ids.has(cid) or not tac.ops.has(h)
		if not gone and now - float(_rg[h][1]) > RG_HOLD and int(_city_threat(c, gw.cities[cid])[0]) == 0:
			tac.stop(h)
			gone = true
		if gone:
			_rg.erase(h)
	var city: City = null
	var th: Array = []
	var bv: float = 0.0
	var fronts: Dictionary = {}
	for cid in c.city_ids:
		var t: Array = _city_threat(c, gw.cities[cid])
		if int(t[0]) < int(D_RG_MIN[GameConfig.diff_of(c)]):
			continue
		if cid != c.capital_id:
			var fid: int = int(t[3])
			if not fronts.has(fid):
				var fr: Dictionary = {}
				var foe: Country = gw.country_by_id(fid)
				if foe != null:
					for e: Array in _front_cities(c, foe, true):
						fr[(e[0] as City).id] = true
				fronts[fid] = fr
			if (fronts[fid] as Dictionary).has(cid):
				continue
		var v: float = float(t[0]) - float(t[2]) * 0.7 + (1.0 if cid == c.capital_id else 0.0)
		if v > bv:
			bv = v
			city = gw.cities[cid]
			th = t
	if city == null:
		_rg_seen.erase(c.id)
		return
	_stat(c, "r22_rg_alarm")


	var seen: Array = _rg_seen.get(c.id, [-1, 0.0, false])
	if int(seen[0]) != city.id:
		var dl: float = float(D_RG_DELAY[GameConfig.diff_of(c)]) + gw.rng.roll() * 10.0
		seen = [city.id, now + dl, GameConfig.diff_of(c) == 0 and gw.rng.roll() < 0.33]
		_rg_seen[c.id] = seen
	if now < float(seen[1]) or bool(seen[2]):
		_stat(c, "r22b_rg_wait")
		return
	var have: int = int(th[2])
	var groups: Dictionary = {}
	for u: Unit in gw.army.units:
		if u.country_id != c.id or u.home == null or not u.alive() or not u.ground() or u.type == Unit.Type.FPV:
			continue
		if u.post != null or u.state == Unit.State.SIEGE:
			continue
		if not groups.has(u.home):
			groups[u.home] = [] as Array[Unit]
		(groups[u.home] as Array[Unit]).append(u)
	var attackers: int = 0
	for h: Facility in groups:
		if _rg.has(h):
			if int(_rg[h][0]) == city.id:
				have += (groups[h] as Array[Unit]).size()
		elif tac.ops.has(h) and not bool(tac.ops[h].get("area", false)):
			attackers += 1
	var need: float = float(th[0]) * [0.8, 1.0, 1.5][GameConfig.diff_of(c)]
	if float(have) >= need:
		return
	var tp: Vector2 = th[1]
	var cand: Array = []
	for h: Facility in groups:
		if _rg.has(h) or not gw.mil.facilities.has(h) or (gw.naval != null and gw.naval.busy(h)):
			continue
		var mem: Array[Unit] = groups[h]
		var cen: = Vector2.ZERO
		for u: Unit in mem:
			cen += u.pos
		cen /= float(mem.size())
		var d: float = cen.distance_to(tp)
		if tac.ops.has(h):
			var op: Dictionary = tac.ops[h]
			if GameConfig.diff_of(c) < 2 or bool(op.get("area", false)) or attackers < 2 or int(op.get("city", -1)) < 0:
				continue
			if d > 2500.0 or d > cen.distance_to(Vector2(gw.cities[int(op["city"])].center * GameWorld.CELL)):
				continue
			cand.append([d + 600.0, h, true])
		else:
			var busy: bool = false
			for u: Unit in mem:
				if u.target_city >= 0:
					busy = true
					break
			cand.append([d + (600.0 if busy else 0.0), h, false])
	cand.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var goal: Vector2 = gw.econ.land_point(tp.lerp(Vector2(city.center * GameWorld.CELL), 0.3))
	var n: int = 0
	for e: Array in cand:
		if n >= (2 if GameConfig.diff_of(c) >= 2 else 1) or float(have) >= need:
			break
		var h2: Facility = e[1]
		var mem2: Array[Unit] = groups[h2]
		if bool(e[2]):
			attackers -= 1
			if attackers < 1:
				break
		if tac.start_area(h2, mem2, goal, Vector2.INF, true):
			_rg[h2] = [city.id, now]
			have += mem2.size()
			n += 1
			_stat(c, "r22_rg_recall" if bool(e[2]) else "r22_rg_send")






func _aviation(c: Country) -> void :
	var air: Air = gw.mil.air
	var af: Facility = null
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.AIRFIELD and f.country_id == c.id and gw.mil.alive(f):
			af = f
			break
	if af == null:
		return
	var diff: int = GameConfig.diff_of(c)
	var P: Dictionary = persona_of(c)
	var want_h: int = [1, 1, 2][diff] + (1 if float(P["caution"]) > 0.7 else 0)
	var want_f: int = [0, 1, 2][diff] + (1 if not c.at_war.is_empty() else 0) + (1 if float(P["aggr"]) > 0.7 else 0)
	var nh: int = air.count(c.id, Aircraft.Type.HELI)
	var nf: int = air.count(c.id, Aircraft.Type.FIGHTER)
	if nh < want_h and c.money >= int(Air.SPEC[Aircraft.Type.HELI]["cost"]) + 400:
		air.buy(af, Aircraft.Type.HELI, c)
	elif nf < want_f and c.money >= int(Air.SPEC[Aircraft.Type.FIGHTER]["cost"]) + 600:
		air.buy(af, Aircraft.Type.FIGHTER, c)
	if c.fuel < 10:
		c.fuel += 6
	var cap: Vector2 = Vector2(gw.cities[c.capital_id].center * GameWorld.CELL)
	var foe_p: = Vector2.INF
	var foes: Array[Country] = _enemies(c)
	if not foes.is_empty():
		foe_p = Vector2(gw.cities[foes[0].capital_id].center * GameWorld.CELL)
	for a: Aircraft in air.aircraft:
		if a.country_id != c.id or a.state != Aircraft.State.PARKED or a.service_t > 0.5:
			continue
		var fmax: float = float(Air.SPEC[a.type]["fuel"])
		if a.fuel < fmax * 0.6:
			continue
		var h: int = Hash32.h2(a.id, int(gw.game_time), 7)
		var base: Vector2 = a.pos


		if a.type == Aircraft.Type.HELI:
			for j in c.city_ids.size():
				var cid: int = c.city_ids[(h + j) % c.city_ids.size()]
				var cp: Vector2 = Vector2(gw.cities[cid].center * GameWorld.CELL)
				if air_route_ok(c, base, cp, Air.HELI_PATROL_R):
					air.order_patrol(a, cp)
					break
		elif a.type == Aircraft.Type.FIGHTER:
			if foe_p != Vector2.INF and h % 3 != 0:
				var fp: Vector2 = cap.lerp(foe_p, 0.55)
				var fo: int = _owner_at(fp)
				if fo <= 0 or fo == c.id or _air_legal(c.id, fo):
					air.order_fly(a, fp)
					continue
			for j in 4:
				var hj: int = Hash32.h2(h, j, 11)
				var p: Vector2 = cap + Vector2(float(hj % 600) - 300.0, float((hj >> 8) % 600) - 300.0)
				if j == 3:
					p = cap
				if air_route_ok(c, base, p, Air.ORBIT_R):
					air.order_fly(a, p)
					break




const AIR_STRIKE_GAP: Array = [140.0, 110.0, 80.0]
var _cr_t: Dictionary = {}





func _missile_mix(c: Country, P: Dictionary) -> void :
	var mil: Military = gw.mil
	var fs: Array[Facility] = []
	for f: Facility in mil.facilities:
		if f.kind == Facility.Kind.MISSILE_FACTORY and f.country_id == c.id and not f.producing and mil.alive(f):
			fs.append(f)
	if fs.is_empty():
		return
	var air: Air = mil.air
	var nf: int = air.count(c.id, Aircraft.Type.FIGHTER)
	var nb: int = air.count(c.id, Aircraft.Type.BOMBER)
	var pid: String = String(P.get("id", ""))
	var want: Array = [[Military.MT_BALLISTIC, 4.0]]
	if pid == "cautious":
		want.append([Military.MT_SAM, 6.0])
	if nf > 0:
		want.append([Military.MT_AA, 4.0])
	if (nf > 0 or nb > 0) and pid != "cautious":
		want.append([Military.MT_CRUISE, 8.0 if pid == "adventurer" else 4.0])
	if nf > 0 and (float(P["sneaky"]) > 0.5 or float(P["aggr"]) > 0.6):
		want.append([Military.MT_HYPER, 2.0])
	if air.count(c.id, Aircraft.Type.ATTACK) > 0:
		want.append([Military.MT_KAB, 4.0])
	var best: int = Military.MT_BALLISTIC
	var br: float = INF
	for e: Array in want:
		var t: int = int(e[0])
		var r: float = float(c.missile_stock[t]) / float(e[1]) - (0.01 if t == Military.MT_KAB else 0.0)
		if r < br:
			br = r
			best = t
	for f: Facility in fs:
		if f.prod_type != best:
			mil.set_prod_type(f, best)





func _air_strike(c: Country, foe: Country) -> void :
	var now: float = gw.game_time
	if now < float(_cr_t.get(c.id, 0.0)):
		return
	var air: Air = gw.mil.air
	if air == null or (c.missile_stock[Military.MT_CRUISE] <= 0 and c.missile_stock[Military.MT_HYPER] <= 0 and not _has_cr_load(c)):
		return
	var af: Facility = null
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.AIRFIELD and f.country_id == c.id and gw.mil.alive(f):
			af = f
			break
	if af == null:
		return
	var P: Dictionary = persona_of(c)
	var hyper: bool = (c.missile_stock[Military.MT_HYPER] > 0 or _has_cr_load(c, true)) and (float(P["sneaky"]) > 0.5 or float(P["aggr"]) > 0.6)
	var reach: float = (Air.HYPER_RANGE if hyper else Air.CR_RANGE) + 1500.0
	var t: Vector2 = _pick_target(c, foe, af.center_px(), reach, "air")
	_cr_t[c.id] = now + 15.0
	if t == Vector2.INF:
		return
	var ok: bool = gw.mil.ai_missile_strike(c, t, true) if hyper else gw.mil.ai_cruise_strike(c, t)
	if not ok and hyper:
		ok = gw.mil.ai_cruise_strike(c, t)
	if ok:
		_log_strike(c, Loc.t("КР/гипер"), 1, t)
		_note_hit(c)
		_stat(c, "air_strike")
		_cr_t[c.id] = now + float(AIR_STRIKE_GAP[GameConfig.diff_of(c)]) * (1.3 - 0.5 * float(P["aggr"]))



func _has_cr_load(c: Country, hyper: bool = false) -> bool:
	for a: Aircraft in gw.mil.air.aircraft:
		if a.country_id != c.id or a.state == Aircraft.State.DEAD:
			continue
		if hyper:
			if a.type == Aircraft.Type.FIGHTER and a.pylon == 2 and a.pylon_n > 0:
				return true
		elif (a.type == Aircraft.Type.BOMBER and a.payload == 0 and a.missiles > 0) or (a.type == Aircraft.Type.FIGHTER and a.pylon == 1 and a.pylon_n > 0):
			return true
	return false












const FORT_TR_WAR: Array = [26, 39, 65]
const FORT_TR_MIN: Array = [13, 26, 26]
const FORT_TR_PEACE: Array = [13, 13, 26]
const FORT_TEETH: Array = [11, 22, 44]
const FORT_ARMY_SHARE: float = 0.9
const FORT_RESERVE: Array = [300, 800]
const FORT_FWD: int = 34
const FORT_TEETH_GAP: float = 45.0
const FORT_RETRY: float = 40.0


func _fortify(c: Country, foe: Country, war: bool = true) -> void :
	if war:
		c.army_defend = true
	var fronts: Array = _front_cities(c, foe, war)
	if fronts.is_empty():
		return
	var dif: int = GameConfig.diff_of(c)
	var t_cap: int = int(FORT_TR_PEACE[dif])
	var e_cap: int = 0
	if war:


		t_cap = clampi(int(float(gw.army.count_units(c.id)) * FORT_ARMY_SHARE), int(FORT_TR_MIN[dif]), int(FORT_TR_WAR[dif]))
		e_cap = int(FORT_TEETH[dif])
	var tr_all: int = 0
	var te_all: int = 0
	var per: Dictionary = {}
	for f: Facility in gw.mil.facilities:
		if f.country_id != c.id or not Military.is_field_work(f.kind):
			continue
		var teeth: bool = Military.is_teeth(f.kind)
		for q: Vector2i in f.cells + f.pending:
			if teeth:
				te_all += 1
			else:
				tr_all += 1
			for e: Array in fronts:
				var city: City = e[0]
				if Vector2(q).distance_to(Vector2(city.center)) < float(maxi(city.radius, city.claim_max) + FORT_FWD):
					var a: Array = per.get(city.id, [0, 0])
					a[1 if teeth else 0] = int(a[1 if teeth else 0]) + 1
					per[city.id] = a
					break
	var n: int = fronts.size()
	var t_want: int = maxi(13, ceili(float(t_cap) / float(n)))
	var e_want: int = maxi(11, ceili(float(e_cap) / float(n))) if e_cap > 0 else 0
	for e: Array in fronts:
		var city: City = e[0]
		var key: String = "%d:fort%d" % [c.id, city.id]
		if gw.game_time < float(_spend_cd.get(key, -1.0)):
			continue
		var a: Array = per.get(city.id, [0, 0])
		var tr_ok: bool = int(a[0]) < t_want and tr_all < t_cap
		var te_ok: bool = war and int(a[1]) < e_want and te_all < e_cap and gw.game_time >= float(_spend_cd.get("%d:teeth" % c.id, -1.0))
		if not tr_ok and not te_ok:
			continue


		var teeth: bool = te_ok and ( not tr_ok or int(a[1]) * 13 < int(a[0]) * 11)
		var room: int = (e_cap - te_all) if teeth else (t_cap - tr_all)
		if _fort_line(c, city, e[1], teeth, int(a[1] if teeth else a[0]), int(FORT_RESERVE[0 if war else 1]), room):
			return
		room = (t_cap - tr_all) if teeth else (e_cap - te_all)
		if te_ok and tr_ok and _fort_line(c, city, e[1], not teeth, int(a[0] if teeth else a[1]), int(FORT_RESERVE[0 if war else 1]), room):
			return
		if c.money >= Military.line_cost(Facility.Kind.TEETH_H, 13) + int(FORT_RESERVE[0 if war else 1]):
			_spend_cd[key] = gw.game_time + FORT_RETRY
	if war:
		_dugout(c, fronts[0])





const FORT_MASS: int = 4
func _front_cities(c: Country, foe: Country, war: bool) -> Array:
	var lst: Array = []
	for cid in c.city_ids:
		var city: City = gw.cities[cid]
		var bd: float = INF
		var bp: = Vector2.ZERO
		for fid in foe.city_ids:
			var dd: float = Vector2(gw.cities[fid].center).distance_squared_to(Vector2(city.center))
			if dd < bd:
				bd = dd
				bp = Vector2(gw.cities[fid].center)
		var cen: = Vector2.ZERO
		var nm: int = 0
		var cp: Vector2 = Vector2(city.center * GameWorld.CELL)
		for o: Variant in gw.army._near(cp, float(maxi(city.radius, city.claim_max) * GameWorld.CELL) + 700.0):
			var u: Unit = o
			if u.country_id == foe.id and u.alive() and u.ground():
				cen += u.pos
				nm += 1
		if nm >= FORT_MASS:
			var mp: Vector2 = cen / float(nm) / float(GameWorld.CELL)
			if mp.distance_squared_to(Vector2(city.center)) > 1.0:
				bp = mp
				bd = minf(bd, mp.distance_squared_to(Vector2(city.center)) * 0.25)
		if bd < INF and bd > 1.0:
			lst.append([city, (bp - Vector2(city.center)).normalized(), sqrt(bd)])
	if lst.is_empty():
		return lst
	lst.sort_custom( func(x: Array, y: Array) -> bool: return float(x[2]) < float(y[2]))
	var out: Array = lst.slice(0, [1, 1, 2][GameConfig.diff_of(c)] if war else 1)
	if war and GameConfig.diff_of(c) >= 2:
		for e: Array in lst:

			if (e[0] as City).id == c.capital_id and not out.has(e) and float(e[2]) < float(lst[0][2]) * 1.6:
				out.append(e)
	return out






func _fort_line(c: Country, city: City, dir: Vector2, teeth: bool, have: int, reserve: int, room: int = 99) -> bool:
	var kind: int = Facility.Kind.TEETH_H if teeth else Facility.Kind.TRENCH_H
	var n: int = 11 if teeth else 13
	if c.money < Military.line_cost(kind, n) + reserve:
		_stat(c, "fort_money")
		return false
	var cells: Array[Vector2i] = []
	if teeth:
		cells = _road_teeth(c, city, dir)
	if cells.is_empty():
		cells = _line_spot(c, city, dir, teeth, have, n)
	if cells.size() < 2:
		_stat(c, "fort_nospot")
		return false
	if room < 3:
		return false
	if cells.size() > room:
		var cut: int = (cells.size() - room) / 2
		cells = cells.slice(cut, cut + room)
	var m0: int = c.money
	if gw.mil.build_line(kind, cells, c) == null:
		_stat(c, "fort_refused")
		return false
	_stat(c, "r22_teeth" if teeth else "r22_trench", (m0 - c.money) / maxi(1, Military.line_cost(kind, 1)))
	if teeth:
		_spend_cd["%d:teeth" % c.id] = gw.game_time + FORT_TEETH_GAP
	return true






func _line_spot(c: Country, city: City, dir: Vector2, teeth: bool, have: int, n: int) -> Array[Vector2i]:
	var side: Vector2 = dir.orthogonal()
	var h: int = Hash32.h2(c.id, city.id, int(gw.game_time / 30.0))
	var slots: Array = [0.0, 13.0, -13.0, 26.0, -26.0, 39.0, -39.0]
	var first: int = (have / n) % slots.size()
	var r0: float = float(city.radius) + 6.0
	var far: float = float(maxi(city.radius, city.claim_max) + FORT_FWD) + (0.0 if teeth else -6.0) + float(h % 3)
	var half: int = n / 2
	for si in slots.size():
		var shift: float = float(slots[(first + si) % slots.size()]) + float(h % 3) - 1.0
		var dist: float = far
		while dist >= r0:
			var cells: Array[Vector2i] = []
			var ok: int = 0
			for k in range( - half, n - half):
				var zig: float = 0.0 if teeth else (1.0 if (k / 2) % 2 == 0 else 0.0)
				var p: Vector2 = Vector2(city.center) + dir * (dist + zig) + side * (float(k) + shift)
				var q: = Vector2i(roundi(p.x), roundi(p.y))
				if not cells.is_empty() and cells[cells.size() - 1] == q:
					continue
				cells.append(q)
				if gw.mil.line_cell_ok(q, c) and not gw.mil.enemy_near(c, Vector2(q * GameWorld.CELL) + Vector2(2, 2)):
					ok += 1
			if ok >= n - 3:
				return cells
			dist -= 3.0
	return [] as Array[Vector2i]





func _road_teeth(c: Country, city: City, dir: Vector2) -> Array[Vector2i]:
	var d: WorldData = gw.data
	var mil: Military = gw.mil
	var cc: Vector2 = Vector2(city.center)
	var r0: float = float(city.radius) + 4.0
	var r1: float = float(maxi(city.radius, city.claim_max) + 12)
	var mine: Array[Vector2i] = []
	for f: Facility in mil.facilities:
		if f.country_id == c.id and Military.is_teeth(f.kind):
			mine.append_array(f.cells)
			mine.append_array(f.pending)
	var cand: Array = []
	var ri: int = ceili(r1)
	for y in range(city.center.y - ri, city.center.y + ri + 1):
		for x in range(city.center.x - ri, city.center.x + ri + 1):
			var v: = Vector2(float(x) - cc.x, float(y) - cc.y)
			var l2: float = v.length_squared()
			if l2 < r0 * r0 or l2 > r1 * r1:
				continue
			var l: float = sqrt(l2)
			var dt: float = v.dot(dir) / l
			if dt < 0.57:
				continue
			if not d.inside(x, y) or not d.has_flag(x, y, WorldData.F_ROAD) or d.get_owner_id(x, y) != c.id:
				continue
			cand.append([l + 12.0 * dt, Vector2i(x, y)])
	if cand.is_empty():
		return [] as Array[Vector2i]
	cand.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var tried: int = 0
	for e: Array in cand:
		var p: Vector2i = e[1]
		var near: bool = false
		for q: Vector2i in mine:
			if absi(q.x - p.x) <= 9 and absi(q.y - p.y) <= 9:
				near = true
				break
		if near:
			continue
		tried += 1
		if tried > 8:
			break

		var tg: = Vector2.ZERO
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				if (dx != 0 or dy != 0) and d.inside(p.x + dx, p.y + dy) and d.has_flag(p.x + dx, p.y + dy, WorldData.F_ROAD):
					var w: = Vector2(dx, dy)
					tg += w if w.dot(dir) >= 0.0 else - w
		if tg.length_squared() < 0.5:
			tg = dir
		var side: Vector2 = tg.normalized().orthogonal()
		var cells: Array[Vector2i] = []
		var ok: int = 0
		for k in range(-5, 6):
			var q2: = Vector2i(roundi(float(p.x) + side.x * float(k)), roundi(float(p.y) + side.y * float(k)))
			if not cells.is_empty() and cells[cells.size() - 1] == q2:
				continue
			cells.append(q2)
			if mil.line_cell_ok(q2, c) and not mil.enemy_near(c, Vector2(q2 * GameWorld.CELL) + Vector2(2, 2)):
				ok += 1
		if ok >= 8 and mil.line_cell_ok(p, c):
			return cells
	return [] as Array[Vector2i]



func _dugout(c: Country, front: Array) -> void :
	var key: String = "%d:dugout" % c.id
	if gw.game_time < float(_spend_cd.get(key, -1.0)):
		return
	_spend_cd[key] = gw.game_time + 60.0
	if _count(c, Facility.Kind.DUGOUT) >= [1, 2, 3][GameConfig.diff_of(c)]:
		return
	var cost: int = Military.cost_of(Facility.Kind.DUGOUT)
	var rc: Dictionary = Economy.res_cost("build_%d" % Facility.Kind.DUGOUT)
	if c.money < cost + 800 or not c.has_res(rc):
		return
	var best: City = front[0]
	var p: Vector2 = Vector2(best.center) + (front[1] as Vector2) * float(best.radius + 4)
	var f: Facility = gw.mil.auto_place(Facility.Kind.DUGOUT, Vector2i(roundi(p.x), roundi(p.y)), c, 0, 14)
	if f != null:
		c.money -= cost
		gw.econ.pay_build(c, Facility.Kind.DUGOUT)
		_after_build(c, f, persona_of(c))
		_stat(c, "r22_dugout")




const INTEL_AGE: float = 180.0
const RECON_WAIT: float = 25.0
const BLIND_T: float = 120.0
var _recon_wait: Dictionary = {}
var _blind: Dictionary = {}




func scout_habit(P: Dictionary) -> float:
	return clampf(0.3 + 0.6 * float(P["caution"]) + 0.3 * float(P["sneaky"]), 0.0, 1.0)






func _intel_ok(c: Country, foe: Country, P: Dictionary) -> bool:
	var rc: Recon = gw.recon
	if rc == null:
		return true
	var now: float = gw.game_time
	var key: String = "%d>%d" % [c.id, foe.id]
	var caut: float = float(P["caution"])
	if rc.has_intel(c.id, foe.id, INTEL_AGE * (1.0 - 0.3 * caut)):
		if _recon_wait.has(key):
			_recon_wait.erase(key)
			_stat(c, "strike_scouted")
		return true
	if now < float(_blind.get(key, -1.0)):
		return true
	if _recon_wait.has(key):
		if now < float(_recon_wait[key]):
			return false
		_recon_wait.erase(key)
		_blind[key] = now + BLIND_T * (1.0 - 0.5 * caut)
		_stat(c, "strike_wait_timeout")
		return true

	if float(Hash32.h2(c.id, foe.id, int(now / 120.0)) % 100) >= scout_habit(P) * 100.0:
		_blind[key] = (floorf(now / 120.0) + 1.0) * 120.0
		_stat(c, "strike_blind")
		return true
	var why: String = _scout(c, foe)
	if why == "" or why == "up":

		_recon_wait[key] = now + _scout_eta + RECON_WAIT * (0.6 + 0.8 * caut)
		if why == "":
			_stat(c, "recon_sent")
		return false
	_blind[key] = now + BLIND_T
	_stat(c, "strike_no_scout")
	return true




var _scout_eta: float = 0.0


func _scout(c: Country, foe: Country) -> String:
	var rc: Recon = gw.recon
	for d: Recon.RDrone in rc.active_for(c.id):
		var tc: = Vector2i(floori(d.target.x / GameWorld.CELL), floori(d.target.y / GameWorld.CELL))
		if gw.data.inside(tc.x, tc.y) and gw.data.get_owner_id(tc.x, tc.y) == foe.id:
			_scout_eta = d.pos.distance_to(d.target) / Recon.SPEED + Recon.LOITER_T
			return "up"
	if c.money < Recon.AI_RESERVE:
		return Loc.t("МАЛО ДЕНЕГ")
	var t: = Vector2.INF
	for f: Facility in gw.mil.facilities:
		if f.kind != Facility.Kind.DRONE_PORT or f.country_id != c.id or not gw.mil.alive(f):
			continue
		t = _pick_target(c, foe, gw.mil.launch_point(f), Recon.RANGE * 0.95)
		if t != Vector2.INF and rc.port_for(c.id, t) != null:
			break
		t = Vector2.INF
	if t == Vector2.INF:
		var why: String = rc.can_launch(c.id)
		return why if why != "" else Loc.t("ДАЛЕКО")
	if not c.has_res(Recon.COST) and not _buy_missing(c, Recon.COST, Recon.AI_RESERVE):
		return Loc.t("НЕ ХВАТАЕТ")
	var port: Facility = rc.port_for(c.id, t)
	_scout_eta = gw.mil.launch_point(port).distance_to(t) / Recon.SPEED + Recon.LOITER_T + 5.0
	return rc.launch(c.id, t)



func _hold_kab(c: Country) -> void :
	var air: Air = gw.mil.air
	if air == null:
		return
	var until: float = gw.game_time + GameConfig.ai_think_dt(c) * GameConfig.ai_pace(gw.game_time) + 1.0
	air.kab_next[c.id] = maxf(float(air.kab_next.get(c.id, 0.0)), until)










const SPEND_FROM_T: float = 300.0



const D_AD_COUNTRY: Array = [5, 8, 12]
const D_AD_CITY: Array = [2, 3, 4]
const D_AD_MFG: Array = [2, 3, 5]
const D_PATRIOT: Array = [0, 1, 2]
const D_PROTECT: Array = [1, 2, 3]
const D_PROT_LVL: Array = [1, 2, 3]
const D_TOWNS: Array = [7, 10, 12]
const D_SPEND: Array = [2, 3, 4]
const D_BARRACKS: Array = [4, 6, 6]
const D_RG_DELAY: Array = [45.0, 30.0, 20.0]
const D_RG_MIN: Array = [5, 4, 3]
const MAX_BARRACKS: int = 6
const MAX_UNITS: int = 60
var _spend_cd: Dictionary = {}
var spent: Dictionary = {}
var _saving: Dictionary = {}



func treasury_reserve(c: Country, P: Dictionary) -> int:
	return 1500 + int(2500.0 * float(P["caution"])) + (1500 if not c.at_war.is_empty() else 0) + int(_saving.get(c.id, 0))\
	+ (gw.econ.upk.ai_reserve(c) if gw.econ.upk != null else 0)


func _spent(c: Country, what: String, n: int) -> void :
	var d: Dictionary = spent.get(c.id, {})
	d[what] = int(d.get(what, 0)) + n
	spent[c.id] = d



func _ad_n(c: Country) -> int:
	var n: int = 0
	for f: Facility in gw.mil.facilities:
		if f.country_id == c.id and f.kind >= Facility.Kind.AD_SPAAG and f.kind <= Facility.Kind.AD_INT and not guard.placed.has(f.id):
			n += 1
	return n



func _ad_room(c: Country, kind: int) -> bool:
	var d: int = GameConfig.diff_of(c)
	if kind == Facility.Kind.AD_MFG:
		return _count(c, kind) < int(D_AD_MFG[d])
	if kind == Facility.Kind.AD_PATRIOT and _count(c, kind) >= int(D_PATRIOT[d]):
		return false
	if kind >= Facility.Kind.AD_SPAAG and kind <= Facility.Kind.AD_INT:
		return _ad_n(c) < mini(int(D_AD_COUNTRY[d]), int(D_AD_CITY[d]) * maxi(1, c.city_ids.size()))
	return true



func _ad_city(c: Country) -> City:
	var per: Dictionary = {}
	for f: Facility in gw.mil.facilities:
		if f.country_id != c.id or f.kind < Facility.Kind.AD_SPAAG or f.kind > Facility.Kind.AD_INT or guard.placed.has(f.id):
			continue
		var bd: int = 1 << 30
		var bc: int = -1
		for cid in c.city_ids:
			var cc: Vector2i = gw.cities[cid].center
			var dd: int = absi(cc.x - f.cell.x) + absi(cc.y - f.cell.y)
			if dd < bd:
				bd = dd
				bc = cid
		per[bc] = int(per.get(bc, 0)) + 1
	var cap_n: int = int(D_AD_CITY[GameConfig.diff_of(c)])
	var best: City = null
	var bs: int = 1 << 30
	for cid in c.city_ids:
		var k: int = int(per.get(cid, 0))
		if k >= cap_n:
			continue
		var sc: int = k - (1 if cid == c.capital_id else 0)
		if sc < bs:
			bs = sc
			best = gw.cities[cid]
	return best


func _spend_surplus(c: Country, P: Dictionary, left: int = -1) -> void :
	if gw.game_time < SPEND_FROM_T or c.capital_id < 0 or c.eliminated:
		return
	var reserve: int = treasury_reserve(c, P)
	var acts: int = 0
	var max_acts: int = int(D_SPEND[GameConfig.diff_of(c)]) + clampi((c.money - 15000) / 5000, 0, 4)
	if left >= 0:
		max_acts = left
	while acts < max_acts and c.money > reserve + 500:
		var opts: Array = _sinks(c, P)
		if opts.is_empty():
			return
		opts.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		var done: bool = false
		var tried: bool = false
		for o: Array in opts:
			if c.money - int(o[2]) < reserve:
				continue
			if tried:
				_cont_s[c.id] = [gw.game_time, max_acts - acts]
				return
			tried = true
			var before: int = c.money
			var ok: bool = _do_sink(c, P, o, reserve)
			if not ok and _place_wait:
				_place_wait = false
				_cont_s[c.id] = [gw.game_time, max_acts - acts]
				return
			_spend_cd["%d:%s" % [c.id, String(o[1])]] = gw.game_time + (float(o[4]) if ok else 90.0)
			if ok:
				_spent(c, String(o[1]), before - c.money)
				done = true
				break
		if not done:
			return
		acts += 1
		if c.money < reserve * 2:
			return
		if acts < max_acts:
			_cont_s[c.id] = [gw.game_time, max_acts - acts]
			return



func _sinks(c: Country, P: Dictionary) -> Array:
	var out: Array = []
	var aggr: float = float(P["aggr"])
	var caut: float = float(P["caution"])
	var trade: float = float(P["trade"])
	var war: bool = not c.at_war.is_empty()
	var w: float = 1.0 if war else 0.0
	var thr: float = _threat(c)
	var n: int = c.city_ids.size()


	var extra: int = clampi((c.money - 5000) / 2500, 0, 16)
	var now: float = gw.game_time
	var add: = func(score: float, id: String, cost: int, arg: Variant, cd: float) -> void :
		if now >= float(_spend_cd.get("%d:%s" % [c.id, id], -1.0)):
			out.append([score, id, cost, arg, cd])

	var up: Facility = _upgrade_pick(c)
	if up != null:
		add.call(1.1 + trade * 0.5, "upgrade", int(gw.econ.upgrade_cost(up).get("money", 0)), up, 15.0)
	var free_pw: int = c.power_cap - c.power_use
	if free_pw < 2:
		add.call(1.6, "power", Military.cost_of(Facility.Kind.POWER_PLANT), Facility.Kind.POWER_PLANT, 40.0)
	if _count(c, Facility.Kind.CIV_FACTORY) < 2 + n / 2 + (1 if trade > 0.7 else 0) + roundi(float(extra) * trade / 3.0) and free_pw >= 1:
		add.call(0.8 + trade * 0.6, "civ", Military.cost_of(Facility.Kind.CIV_FACTORY), Facility.Kind.CIV_FACTORY, 40.0)
	if c.food < 60 and gw.army.count_units(c.id) > 6 and _count(c, Facility.Kind.FARM) < n + 2:
		add.call(1.2, "farm", Military.cost_of(Facility.Kind.FARM), Facility.Kind.FARM, 40.0)

	var want_bar: int = 1 + roundi(aggr * 3.0) + (1 if war else 0) + (1 if GameConfig.diff_of(c) == 2 else 0) + extra
	if _count(c, Facility.Kind.BARRACKS) < mini(want_bar, int(D_BARRACKS[GameConfig.diff_of(c)])) and gw.army.count_units(c.id) < MAX_UNITS:
		add.call(0.6 + aggr * 0.8 + w * 0.6 + thr * 0.4, "barracks", Military.cost_of(Facility.Kind.BARRACKS), Facility.Kind.BARRACKS, 45.0)
	if _count(c, Facility.Kind.AD_SPAAG) < 1 + roundi(caut * 3.0) + (1 if war else 0) + extra / 2 + (extra * n) / 24 and _ad_room(c, Facility.Kind.AD_SPAAG):
		add.call(0.3 + caut * 0.7 + thr * 0.5, "spaag", Military.cost_of(Facility.Kind.AD_SPAAG), Facility.Kind.AD_SPAAG, 40.0)
	if _count(c, Facility.Kind.AD_SAM) < roundi(caut * 2.0) + (1 if war else 0) + extra / 2 + (extra * n) / 36 and _ad_room(c, Facility.Kind.AD_SAM):
		add.call(0.25 + caut * 0.6 + thr * 0.5, "sam", Military.cost_of(Facility.Kind.AD_SAM), Facility.Kind.AD_SAM, 60.0)
	if _count(c, Facility.Kind.AD_PATRIOT) < (1 if caut > 0.6 or extra >= 1 else 0) + (1 if extra >= 3 else 0) + (1 if caut > 0.6 and extra >= 5 else 0) + (1 if extra >= 8 else 0) + (1 if extra >= 11 else 0) and _ad_room(c, Facility.Kind.AD_PATRIOT):
		add.call(0.2 + caut * 0.4 + thr * 0.4, "patriot", Military.cost_of(Facility.Kind.AD_PATRIOT), Facility.Kind.AD_PATRIOT, 90.0)

	var bw: Array = guard.want(c, P, spent, extra)
	if not bw.is_empty():
		add.call(0.35 + caut * 0.4 + thr * 0.4 + w * 0.4 + minf(1.0, float(bw[2]) / 4.0) * 0.3, "bridge_ad", Military.cost_of(int(bw[1])), bw, 60.0)
	if (war or caut > 0.6) and _count(c, Facility.Kind.AD_RADAR) < 1:
		add.call(0.3 + caut * 0.4, "radar", Military.cost_of(Facility.Kind.AD_RADAR), Facility.Kind.AD_RADAR, 90.0)
	if (war or caut > 0.6) and _count(c, Facility.Kind.AD_EW) < 1:
		add.call(0.25 + caut * 0.3, "ew", Military.cost_of(Facility.Kind.AD_EW), Facility.Kind.AD_EW, 90.0)

	if aggr > 0.4 or war or extra >= 3:
		if _count(c, Facility.Kind.MISSILE_FACTORY) < 1:
			add.call(0.3 + aggr * 0.4 + w * 0.3, "mfactory", Military.cost_of(Facility.Kind.MISSILE_FACTORY), Facility.Kind.MISSILE_FACTORY, 60.0)
		elif _count(c, Facility.Kind.TEL) < 1 + roundi(aggr * 2.0) + (1 if war else 0) + extra / 2:
			add.call(0.2 + aggr * 0.5 + w * 0.4, "tel", Military.cost_of(Facility.Kind.TEL), Facility.Kind.TEL, 60.0)

	var afs: int = _count(c, Facility.Kind.AIRFIELD)
	var want_af: int = (1 if war or aggr > 0.4 or caut > 0.6 or extra >= 1 else 0) + (1 if extra >= 4 else 0)
	if afs < want_af:
		add.call(0.4 + aggr * 0.3 + caut * 0.2 + w * 0.3 + (0.3 if afs == 0 else 0.0), "airfield", Military.cost_of(Facility.Kind.AIRFIELD), Facility.Kind.AIRFIELD, 90.0)
	if afs > 0:
		var air: Air = gw.mil.air
		if air.count(c.id, Aircraft.Type.FIGHTER) < 1 + roundi(aggr * 2.0) + (1 if war else 0) + extra / 2:
			add.call(0.35 + aggr * 0.4 + w * 0.4, "fighter", int(Air.SPEC[Aircraft.Type.FIGHTER]["cost"]), Aircraft.Type.FIGHTER, 30.0)
		if air.count(c.id, Aircraft.Type.HELI) < 1 + roundi(caut * 2.0) + extra / 4:
			add.call(0.25 + caut * 0.4, "heli", int(Air.SPEC[Aircraft.Type.HELI]["cost"]), Aircraft.Type.HELI, 30.0)

		var want_b: int = (1 + (1 if aggr > 0.6 else 0)) if war else 0
		if air.count(c.id, Aircraft.Type.BOMBER) < want_b:
			add.call(0.5 + aggr * 0.5 + w * 0.5, "bomber", int(Air.SPEC[Aircraft.Type.BOMBER]["cost"]), Aircraft.Type.BOMBER, 120.0)

	var ports: Ports = gw.econ.ports
	var port: Facility = ports.port_of(c)
	if port == null:
		if trade > 0.4 or not gw.econ.scarce_of(c).is_empty():
			add.call(0.4 + trade * 0.6, "port", Military.cost_of(Facility.Kind.PORT), Facility.Kind.PORT, 300.0)
	elif ports.crane_count(port) < mini(Ports.MAX_CRANES, 1 + roundi(trade * 2.0)):
		add.call(0.3 + trade * 0.5, "crane", Military.cost_of(Facility.Kind.PORT_CRANE), Facility.Kind.PORT_CRANE, 60.0)

	for o: Country in gw.countries:
		if o == c or o.eliminated or o.capital_id < 0 or gw.diplo.at_war(c.id, o.id):
			continue
		if gw.diplo.allied(c.id, o.id) and not o.at_war.is_empty() and o.money < 2000:
			add.call(0.6 + caut * 0.3 + trade * 0.2, "aid", 1500, o, 120.0)
			break
		if extra >= 2 and o.money < 3000 and gw.diplo.get_opinion(c.id, o.id) >= 30:
			add.call(0.3 + trade * 0.3, "aid", 2000, o, 120.0)
			break


	if (n < mini(8 + extra, int(D_TOWNS[GameConfig.diff_of(c)])) or now >= float(EXP_EARLY[clampi(GameConfig.expand_i, 0, 2)])) and c.money > 8000:
		var app: float = appetite(c)
		add.call((0.45 + trade * 0.4 + aggr * 0.1 + float(extra) * 0.1) * app, "town", Military.town_cost(c.towns_founded), null, (90.0 if extra < 2 else 45.0) / app)

	if extra >= 1 and gw.protect != null:
		var pp: Array = _protect_pick(c, extra, caut)
		if not pp.is_empty():
			add.call(0.3 + caut * 0.5 + trade * 0.3 + float(extra) * 0.05, "protect", 1500, pp, 15.0)

	if extra >= 2 and aggr > 0.5 and Facility.Kind.has("DRONE_FACTORY") and _count(c, Facility.Kind.DRONE_FACTORY) < 1 + extra / 3:
		add.call(0.3 + aggr * 0.5 + w * 0.3, "dfactory", Military.cost_of(Facility.Kind.DRONE_FACTORY), Facility.Kind.DRONE_FACTORY, 90.0)

	for res: String in ["titanium", "metal", "oil", "precious"]:
		var cap_n: int = gw.econ.res_cap(c, res)
		if int(c.get(res)) + gw.econ.inbound(c, res) < int(cap_n * (0.4 if extra >= 4 else 0.3)):
			add.call(0.35 + trade * 0.3, "stock_" + res, gw.econ.foreign_buy_price(res) * mini(30, cap_n / 2), res, 60.0)
	return out


func _do_sink(c: Country, P: Dictionary, o: Array, reserve: int) -> bool:
	var id: String = String(o[1])
	if gw.econ.upk != null and not gw.econ.upk.ai_ok_sink(c, id, o[3]):
		return false
	match id:
		"upgrade":
			var f: Facility = o[3]
			var uc: Dictionary = gw.econ.upgrade_cost(f)
			if uc.is_empty() or ( not c.has_res(uc) and not _buy_missing(c, uc, reserve)):
				return false
			return gw.econ.upgrade(f, c) == ""
		"aid":
			var amount: int = mini(int(o[2]), c.money - reserve)
			return amount >= 100 and gw.diplo.give_aid(c.id, (o[3] as Country).id, amount) == ""
		"fighter", "heli", "bomber":
			return _buy_aircraft(c, int(o[3]), reserve)
		"protect":
			var pf: Facility = (o[3] as Array)[0]
			var what: String = String((o[3] as Array)[1])
			var inf: Dictionary = gw.protect.info(pf)
			var pc: Dictionary = inf["next_net_cost" if what == "net" else "next_conc_cost"]
			if pc.is_empty() or c.money - int(pc.get("money", 0)) < reserve or ( not c.has_res(pc) and not _buy_missing(c, pc, reserve)):
				return false
			return gw.protect.upgrade(pf, what, c) == ""
	if id.begins_with("stock_"):
		return _stock_up(c, String(o[3]), reserve)
	if id == "town":
		return _expand(c)
	if id == "bridge_ad":
		return _buy_bridge_ad(c, P, o[3], reserve)
	return _build_extra(c, int(o[3]), P, reserve)



func _buy_bridge_ad(c: Country, P: Dictionary, bw: Array, reserve: int) -> bool:
	var bk: int = int(bw[1])
	if c.money - Military.cost_of(bk) < reserve:
		return false
	var bcost: Dictionary = Economy.build_cost(bk)
	if not c.has_res(bcost) and not _buy_missing(c, bcost, reserve):
		return false
	var bf: Facility = guard.place(c, bw[0], bk)
	if bf == null:
		return false
	gw.mil.pay_series(c, bk)
	gw.econ.pay_build(c, bk)
	_after_build(c, bf, P)
	return true





func _guard_bridges(c: Country, P: Dictionary) -> void :
	var bw: Array = guard.want(c, P, spent, clampi((c.money - 5000) / 2500, 0, 16))
	if bw.is_empty() or not bool(bw[3]):
		return
	var before: int = c.money
	if _buy_bridge_ad(c, P, bw, 300 + int(500.0 * float(P["caution"]))):
		_spent(c, "bridge_ad", before - c.money)


func _build_extra(c: Country, kind: int, P: Dictionary, reserve: int) -> bool:
	var cost: Dictionary = Economy.build_cost(kind)
	if not c.has_res(cost) and not _buy_missing(c, cost, reserve):
		return false
	var f: Facility = _place(c, kind, gw.cities[c.capital_id])
	if f == null:
		return false
	gw.mil.pay_series(c, kind)
	gw.econ.pay_build(c, kind)
	_after_build(c, f, P)
	return true


func _buy_aircraft(c: Country, type: int, reserve: int) -> bool:
	var air: Air = gw.mil.air
	var af: Facility = null
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.AIRFIELD and f.country_id == c.id and gw.mil.alive(f) and air._free_spot(f, type == Aircraft.Type.BOMBER) != -2:
			af = f
			break
	if af == null:
		return false
	var cost: Dictionary = Economy.res_cost("aircraft_%d" % type)
	cost["money"] = int(Air.SPEC[type]["cost"])
	if not c.has_res(cost) and not _buy_missing(c, cost, reserve):
		return false
	return air.buy(af, type, c) == ""



func _stock_up(c: Country, res: String, reserve: int) -> bool:
	var econ: Economy = gw.econ

	var n: int = mini(mini(30, int(econ.res_cap(c, res) * 0.45) - int(c.get(res)) - econ.inbound(c, res)), econ.room_for(c, res))
	if n < 5:
		return false
	if econ.ports.has_port(c) and c.money - econ.foreign_buy_price(res) * n >= reserve:
		if econ.ports.import_order(c, res, n) == "":
			return true
	var seller: Country = econ._best_seller(c, res)
	if seller != null and c.money - econ.market_price(res) * n >= reserve:
		return econ.buy(c, seller, res, n) == ""
	return false




func _buy_missing(c: Country, cost: Dictionary, reserve: int) -> bool:
	var econ: Economy = gw.econ
	var bill: int = 0
	var lack: Dictionary = {}
	for r: String in cost:
		if r == "money":
			continue
		var l: int = int(cost[r]) - int(c.get(r))
		if l <= 0:
			continue
		if l > econ.res_cap(c, r) - int(c.get(r)):
			return false
		lack[r] = l
		bill += econ.foreign_buy_price(r) * l
	if lack.is_empty():
		return true
	if c.money - bill - int(cost.get("money", 0)) < reserve:
		return false
	c.money -= bill
	econ.stat_add(c, "spend", "import", bill)
	for r: String in lack:
		c.set(r, int(c.get(r)) + int(lack[r]))
		econ.stat_res(c, r, "import", int(lack[r]))
	return true




func _expand(c: Country) -> bool:
	var d: WorldData = gw.data
	var cands: Array = []
	var reach: int = GameWorld.TOWN_REACH - 12
	for dp: Dictionary in gw.econ.deposits:
		var dc: Vector2i = dp["cell"]
		if dp["mine"] != null or (int(dp.get("left", 0)) < 150 and not GameConfig.infinite_res()) or d.get_owner_id(dc.x, dc.y) != 0:
			continue
		if not _near_own_city(c, dc, reach + 16):
			continue
		for a in range(0, 360, 60):
			cands.append([1000.0 + float(gw.econ.market_price(String(dp.get("res", "metal")))), dc + Vector2i(roundi(cos(deg_to_rad(a)) * 14.0), roundi(sin(deg_to_rad(a)) * 14.0))])
	for cid in c.city_ids:
		var city: City = gw.cities[cid]
		for r in range(city.claim_max + 16, city.claim_max + 60, 14):
			for a2 in range(0, 360, 40):
				cands.append([500.0 - float(r), city.center + Vector2i(roundi(cos(deg_to_rad(a2)) * r), roundi(sin(deg_to_rad(a2)) * r))])

	for cd0: Array in cands:
		var q0: Vector2i = cd0[1]
		var own8: int = 0
		for a3 in range(0, 360, 45):
			var s3: Vector2i = q0 + Vector2i(roundi(cos(deg_to_rad(a3)) * 20.0), roundi(sin(deg_to_rad(a3)) * 20.0))
			if d.inside(s3.x, s3.y) and d.get_owner_id(s3.x, s3.y) == c.id:
				own8 += 1
		cd0[0] = float(cd0[0]) + EXP_HOLE * float(own8)
	cands.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var tries: int = 0
	for cd: Array in cands:
		var q: Vector2i = cd[1]
		if not d.inside(q.x, q.y) or not Biome.is_natural_land(d.get_biome(q.x, q.y)) or d.get_owner_id(q.x, q.y) != 0:
			continue
		var close: bool = false
		for oc: City in gw.cities:
			if absi(oc.center.x - q.x) + absi(oc.center.y - q.y) < GameWorld.MIN_CITY_DIST:
				close = true
				break
		if close:
			continue

		tries += 1
		if tries > EXPAND_TRIES:
			return false
		if not GameWorld.BORDER_GAP.own_ok(gw, q, c.id, _town_r()) or gw.diplo._dist_to_land(q, c.id, reach) < 0 or not GameWorld.BORDER_GAP.site_ok(gw, q, c.id, _town_r()):
			continue
		if gw.cad344 != null and not gw.cad344.plan_free(q, City.Kind.TOWN):
			gw.cad344.exp_cont[c.id] = true
			return false
		var pl6: Dictionary = gw.can_found_city(q, City.Kind.TOWN) if gw.cad344 == null else gw.cad344.can_found_ai(q, City.Kind.TOWN)
		if not bool(pl6["ok"]) or preload("res://game/ad_relocate.gd").war_blocked(gw, q, c, int(pl6["radius"])):
			continue
		if gw.purchase_town(q, c, pl6) != null:
			_stat(c, "towns")
			gw.diplo.dlog(c.id, "новый город", "городов %d, казна %d" % [c.city_ids.size(), c.money])
			return true
	return false


const EXPAND_TRIES: int = 40



func _town_r() -> int:
	return int(CityGen.params(City.Kind.TOWN)["radius"])




func _site_free(c: Country, p: Vector2i) -> bool:
	return GameWorld.BORDER_GAP.own_ok(gw, p, c.id, _town_r()) and GameWorld.BORDER_GAP.site_ok(gw, p, c.id, _town_r())







const EXP_EARLY: Array = [900.0, 600.0, 0.0]
const EXP_GATE: Array = [3000, 1200, 800]
const EXP_PER: Array = [150, 60, 30]
const EXP_GAP: Array = [300.0, 150.0, 70.0]
const EXP_FAIL: float = 240.0
const EXP_HOLE: float = 70.0
var _town_t: Dictionary = {}







const SATE_N: int = 12
const LEAD_K: float = 1.6
const APP_COAL: float = 0.7
const APP_MIN: float = 0.12
func appetite(c: Country) -> float:
	var n: int = c.city_ids.size()
	if n <= SATE_N or gw.game_time < float(EXP_EARLY[clampi(GameConfig.expand_i, 0, 2)]):
		return 1.0
	var tot: int = 0
	var k: int = 0
	for o: Country in gw.countries:
		if o.id != c.id and not o.eliminated and o.capital_id >= 0:
			tot += o.city_ids.size()
			k += 1
	var f: float = float(SATE_N) / float(n)
	var lead: float = float(n) / maxf(6.0, float(tot) / maxf(1.0, float(k)))
	if lead > LEAD_K:
		f *= LEAD_K / lead
	if not gw.diplo.coalition.is_empty() and int(gw.diplo.coalition["leader"]) == c.id:
		f *= APP_COAL
	return clampf(f, APP_MIN, 1.0)


func _grow_land(c: Country) -> void :
	var e: int = clampi(GameConfig.expand_i, 0, 2)
	var now: float = gw.game_time
	var n: int = c.city_ids.size()
	if c.capital_id < 0 or c.eliminated or n < 6 or now < float(EXP_EARLY[e]) or now < float(_town_t.get(c.id, 0.0)):
		return
	if not c.at_war.is_empty() and _threat(c) > 0.6:
		_town_t[c.id] = now + 60.0
		return
	if c.money < int(EXP_GATE[e]) + int(EXP_PER[e]) * (n - 6):
		_town_t[c.id] = now + 20.0
		return
	var ok: bool = _expand(c)
	if gw.cad344 != null and gw.cad344.exp_cont.has(c.id):
		return
	_town_t[c.id] = now + (float(EXP_GAP[e]) * (1.0 + 0.04 * float(n - 6)) / (appetite(c) * _drama_expand(c)) if ok else EXP_FAIL)
	if ok:
		_spent(c, "town", Military.town_cost(c.towns_founded - 1))



func _drama_expand(c: Country) -> float:
	return clampf(1.0 + 0.6 * gw.drama.bias(c, "expand"), 0.7, 1.6) if gw.drama != null else 1.0



func _near_own_city(c: Country, cell: Vector2i, pad: int) -> bool:
	for cid in c.city_ids:
		var city: City = gw.cities[cid]
		if maxi(absi(city.center.x - cell.x), absi(city.center.y - cell.y)) <= city.claim_max + pad:
			return true
	return false




func _protect_pick(c: Country, extra: int, caut: float) -> Array:
	var dk: int = GameConfig.diff_of(c)
	var net_to: int = mini(mini(Protect.NET_MAX, 1 + extra / 3), int(D_PROT_LVL[dk]))
	var conc_to: int = mini(mini(3, (extra + roundi(caut * 2.0)) / 3), int(D_PROT_LVL[dk]))
	var best: Array = []
	var bl: int = 99
	for f: Facility in _protect_keys(c):
		var inf: Dictionary = gw.protect.info(f)
		if String(inf["net_state"]) != "ok" and int(inf["net_lvl"]) > 0 or String(inf["conc_state"]) != "ok" and int(inf["conc_lvl"]) > 0:
			continue
		var nl: int = int(inf["net_lvl"])
		var cl: int = int(inf["conc_lvl"])
		if nl < net_to and nl * 2 < bl:
			bl = nl * 2
			best = [f, "net"]
		if cl < conc_to and cl * 2 + 1 < bl:
			bl = cl * 2 + 1
			best = [f, "conc"]
	return best




func _protect_keys(c: Country) -> Array[Facility]:
	var capc: = Vector2(gw.cities[c.capital_id].center)
	var best: Dictionary = {}
	for f: Facility in gw.mil.facilities:
		if f.country_id != c.id or not gw.protect.eligible(f) or not gw.mil.alive(f):
			continue
		var slot: int = -1
		if f.kind == Facility.Kind.REFINERY:
			slot = 0
		elif f.kind == Facility.Kind.POWER_PLANT:
			slot = 1
		elif f.kind == Facility.Kind.DRONE_FACTORY or f.kind == Facility.Kind.MISSILE_FACTORY or f.kind == Facility.Kind.CIV_FACTORY:
			slot = 2
		if slot < 0:
			continue
		var sc: float = Vector2(f.cell).distance_squared_to(capc) + (10000000.0 if f.kind == Facility.Kind.CIV_FACTORY else 0.0)
		if not best.has(slot) or sc < float(best[slot][1]):
			best[slot] = [f, sc]
	var out: Array[Facility] = []
	for k in 3:
		if best.has(k) and out.size() < int(D_PROTECT[GameConfig.diff_of(c)]):
			out.append(best[k][0])
	return out



func _upgrade_pick(c: Country) -> Facility:
	var econ: Economy = gw.econ
	var best: Facility = null
	var bs: float = 0.0
	for f: Facility in gw.mil.facilities:
		if f.country_id != c.id or not Economy.UPG_RES.has(f.kind) or f.level >= Economy.MAX_LEVEL or not gw.mil.alive(f):
			continue
		var low: bool = econ.has_method("deep_low") and econ.deep_low(f)
		if float(f.upg_t) > 0.0 or ( not f.deposit.is_empty() and int(f.deposit.get("left", 0)) < 200 and not low and not GameConfig.infinite_res()):
			continue
		var r: String = econ.out_res(f)
		var sc: float = float(econ.need(c, r) + 10) * float(econ.market_price(r) if r != "" else 20) / float(f.level) * (3.0 if low else 1.0)
		if sc > bs:
			bs = sc
			best = f
	return best




const FrontPlan = preload("res://game/front_plan.gd")





func _fronts(c: Country, P: Dictionary) -> void :
	var foe: Country = null
	if not c.at_war.is_empty():
		var foes: Array[Country] = _enemies(c)
		var cap: Vector2 = Vector2(gw.cities[c.capital_id].center * GameWorld.CELL)
		var bd: float = INF
		for e: Country in foes:
			var d: float = Vector2(gw.cities[e.capital_id].center * GameWorld.CELL).distance_to(cap)
			if d < bd:
				bd = d
				foe = e
	else:
		foe = _tension_foe(c, P)
	FrontPlan.ai_think(gw, c, P, foe, _reserve_home(c), _rg)
