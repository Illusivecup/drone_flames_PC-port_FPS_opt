class_name Nuclear
extends RefCounted



























const NPP_CAP: int = 40
const FUEL_S: float = 90.0
const FIRST_LOAD: float = 300.0
const CORE_HITS: int = 3
const U_MINE_RATE: float = 0.5
const U_PRICE: int = 110
const U_DEP: int = 240
const U_WEIGHT: float = 0.045
const U_MIN_DEP: int = 2
const U_RESERVE: int = 8
const TOWERS: Array = [Vector2i(8, 3), Vector2i(13, 3)]
const STYLE_SUFFIX: Array = ["", "_usa", "_west", "_asia"]
const AI_FROM: float = 540.0
const AI_MINE_FROM: float = 300.0
const AI_AD_R: float = 260.0
const FUND_WAIT: float = 120.0
const FUND_SKIP: float = 900.0





static func build_parts(gw: GameWorld, f: Facility, nw: Vector2i, country: Country) -> void :
	var suf: String = String(STYLE_SUFFIX[clampi(country.arch, 0, 3)]) if country != null else ""
	var core: String = "npp_core" + suf if gw.spr_index.has("npp_core" + suf) else "npp_core"
	var tower: String = "npp_tower" + suf if gw.spr_index.has("npp_tower" + suf) else "npp_tower"
	if not gw.spr_index.has(core):
		core = "power_plant"
	f.main_obj = gw.add_object(core, nw, GameWorld.KIND_BUILDING)
	f.obj_ids.append(f.main_obj)
	if gw.spr_index.has(tower):
		for off: Vector2i in TOWERS:
			var tid: int = gw.add_object(tower, nw + off, GameWorld.KIND_BUILDING)
			if tid >= 0:
				f.obj_ids.append(tid)
	f.u_fuel = FIRST_LOAD
	f.u_hits = 0



static func ambient(_gw: GameWorld, _f: Facility) -> void :
	pass




static func steam_points(gw: GameWorld, f: Facility) -> Array:
	var out: Array = []
	if output(gw, f) <= 0:
		return out
	for id in f.obj_ids:
		if id == f.main_obj or id < 0 or gw.obj_state[id] != 0:
			continue
		for p: Variant in _spr_info(gw, gw.spr_name[gw.obj_spr[id]]).get("steam", []):
			var q: Array = p
			out.append(gw.obj_origin(id) + Vector2(float(q[0]), float(q[1])))
	return out



static func refresh_look(gw: GameWorld, f: Facility) -> void :
	if f.main_obj < 0:
		return
	var nm: String = gw.spr_name[gw.obj_spr[f.main_obj]].trim_suffix("_dmg")
	var want: String = nm + "_dmg" if f.u_hits > 0 else nm
	if gw.spr_index.has(want):
		gw.set_obj_frame(f.main_obj, want, 0)


static func _spr_info(gw: GameWorld, nm: String) -> Dictionary:
	var at: Variant = gw.get("atlas_uran30")
	if at is SpriteAtlas and (at as SpriteAtlas).has(nm):
		return (at as SpriteAtlas).info(nm)
	return {}



static func beacon_px(gw: GameWorld, f: Facility) -> Vector2:
	if f.main_obj < 0:
		return f.center_px()
	var info: Dictionary = _spr_info(gw, gw.spr_name[gw.obj_spr[f.main_obj]])
	var b: Array = info.get("beacon", [])
	if b.is_empty():
		return f.center_px()
	var q: Array = b[0]
	return gw.obj_origin(f.main_obj) + Vector2(float(q[0]), float(q[1]))





static func parts(gw: GameWorld, f: Facility) -> Array:
	var core: bool = f.main_obj >= 0 and gw.obj_state[f.main_obj] == 0
	var towers: int = 0
	for id in f.obj_ids:
		if id != f.main_obj and id >= 0 and gw.obj_kind[id] == GameWorld.KIND_BUILDING and gw.obj_state[id] == 0:
			towers += 1
	return [core, towers]



static func output(gw: GameWorld, f: Facility) -> int:
	if f.restore_t > 0.0 or f.halted or f.u_fuel <= 0.0:
		return 0
	var p: Array = parts(gw, f)
	if not bool(p[0]):
		return 0
	var share: float = float(1 + int(p[1])) / float(1 + TOWERS.size())
	var hurt: float = 1.0 - 0.25 * float(clampi(f.u_hits, 0, CORE_HITS - 1))
	return roundi(float(NPP_CAP) * share * hurt)




static func burn(gw: GameWorld, dt: float) -> void :
	for f: Facility in gw.mil.facilities:
		if f.kind != Facility.Kind.NUCLEAR_PLANT or f.restore_t > 0.0 or f.halted:
			continue
		if f.main_obj < 0 or gw.obj_state[f.main_obj] != 0:
			continue
		var c: Country = gw.country_by_id(f.country_id)
		if c == null:
			continue
		if f.u_fuel > 0.0:
			f.u_fuel = maxf(0.0, f.u_fuel - dt)
		if f.u_fuel <= 0.0 and c.uranium >= 1:
			c.uranium -= 1
			f.u_fuel += FUEL_S
			if gw.econ != null:
				gw.econ.stat_res(c, "uranium", "npp", -1)
		elif f.u_fuel <= 0.0 and c.is_player and not bool(gw.econ._warned.get(f, false)):
			gw.econ._warned[f] = true
			gw.say(c, Loc.mk("АЭС остановлена: нет урана (шахта, рынок или импорт через порт)"))
		elif f.u_fuel > 0.0 and gw.econ._warned.has(f):
			gw.econ._warned.erase(f)



static func status(gw: GameWorld, f: Facility) -> String:
	if f.restore_t > 0.0:
		return Loc.t("СТРОИТСЯ / РЕМОНТ")
	var p: Array = parts(gw, f)
	if not bool(p[0]):
		return Loc.t("ГЛАВНЫЙ КОРПУС РАЗРУШЕН — 0")
	if f.u_fuel <= 0.0:
		return Loc.t("НЕТ УРАНА — АЭС СТОИТ")
	var out: PackedStringArray = PackedStringArray()
	out.append(Loc.t("+%d ЭНЕРГИИ") % output(gw, f))
	if int(p[1]) < TOWERS.size():
		out.append(Loc.t("ГРАДИРЕН %d/%d") % [int(p[1]), TOWERS.size()])
	if f.u_hits > 0:
		out.append(Loc.t("КОРПУС %d/%d") % [CORE_HITS - f.u_hits, CORE_HITS])
	out.append(Loc.t("ТОПЛИВО %d С") % int(f.u_fuel))
	return " · ".join(out)



static func fuel_minutes(gw: GameWorld, c: Country) -> float:
	var n: int = 0
	var loaded: float = 0.0
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.NUCLEAR_PLANT and f.country_id == c.id and f.restore_t <= 0.0:
			n += 1
			loaded += f.u_fuel
	if n == 0:
		return 0.0
	return (loaded + float(c.uranium) * FUEL_S) / float(n) / 60.0





static func on_impact(gw: GameWorld, pr: Protect, cell: Vector2i, kind: int, r: int) -> void :
	if kind == Protect.HIT_BALLISTIC or kind == Protect.HIT_HYPER:
		return
	for f: Facility in gw.mil.facilities:
		if f.kind != Facility.Kind.NUCLEAR_PLANT or f.main_obj < 0 or gw.obj_state[f.main_obj] != 0 or f.restore_t > 0.0:
			continue
		var rr: Rect2i = gw.object_rect(f.main_obj)
		var qx: int = clampi(cell.x, rr.position.x, rr.end.x - 1)
		var qy: int = clampi(cell.y, rr.position.y, rr.end.y - 1)
		if (qx - cell.x) * (qx - cell.x) + (qy - cell.y) * (qy - cell.y) > r * r:
			continue
		if f.u_hits >= CORE_HITS - 1:
			continue
		f.u_hits += 1
		refresh_look(gw, f)
		pr._spare.append({"c": cell, "ids": PackedInt32Array([f.main_obj]), "t": gw.game_time + Protect.SPARE_TTL})
		gw.say(f.country_id, Loc.mk("АЭС: попадание в корпус (%d/%d), мощность −25 %%. Нужна ПВО", [f.u_hits, CORE_HITS]))





static func ai_tick(gw: GameWorld, ai: AiBots, c: Country) -> bool:
	if c.is_player or c.capital_id < 0 or gw.econ == null:
		return false
	var now: float = gw.game_time
	var P: Dictionary = ai.persona_of(c)
	var reserve: int = ai.treasury_reserve(c, P)
	var npps: Array[Facility] = []
	for f: Facility in gw.mil.facilities:
		if f.country_id == c.id and f.kind == Facility.Kind.NUCLEAR_PLANT:
			npps.append(f)

	for f: Facility in npps:
		var p: Array = parts(gw, f)
		var broken: bool = not bool(p[0]) or int(p[1]) == 0 or f.u_hits >= CORE_HITS - 1
		if broken and gw.mil.can_restore(f) and gw.mil.fire_block_left(f) <= 0.0\
		and c.money >= Military.restore_cost(f) + gw.mil.restore_buy(f, c) + 300:
			if gw.mil.restore(f, c, true):
				ai._stat(c, "npp_restore")
				return true

	if not npps.is_empty():
		var keep: int = U_RESERVE * npps.size()
		if c.uranium < keep:
			_want(gw, c, keep)

		if _cover(gw, ai, c, npps, reserve):
			return true

	var mk: int = Facility.Kind.URANIUM_MINE
	var mkey: String = "%d:%d" % [c.id, mk]
	var fm: Facility = null
	if now >= AI_MINE_FROM and now >= float(ai._skip.get(mkey, -1.0)) and ai._count(c, mk) < (2 if not npps.is_empty() else 1) and _free_own_deposit(gw, c):
		var mcost: Dictionary = Economy.build_cost(mk)
		var mf: int = _fund_take(gw, c, int(mcost["money"]), reserve)
		if mf < int(mcost["money"]):
			return false
		var mrc: Dictionary = Economy.res_cost("build_%d" % mk)
		if c.has_res(mrc):
			fm = _place_umine(gw, c)
		else:
			gw.econ.ai_blocked(c, mrc)
		if fm == null:
			ai._skip[mkey] = now + 180.0
			ai._stat(c, "umine_skip")
		else:
			c.money += mf
			gw.econ.u_fund.erase(c.id)
	if fm != null:
		c.money -= int(Economy.build_cost(mk)["money"])
		gw.econ.pay_build(c, mk)
		ai._after_build(c, fm, P)
		ai._stat(c, "umine")
		if gw.diplo != null:
			gw.diplo.dlog(c.id, "урановая шахта", "уран %d, АЭС %d" % [c.uranium, npps.size()], 0.0, ["eco_umine"])
		return true



	var kind: int = Facility.Kind.NUCLEAR_PLANT
	var cost: Dictionary = Economy.build_cost(kind)
	var rc: Dictionary = Economy.res_cost("build_%d" % kind)
	var fund: int = int(gw.econ.u_fund.get(c.id, 0))
	if not ai_wants_npp(gw, ai, c, npps.size()):
		if fund > 0:
			c.money += fund
			gw.econ.u_fund.erase(c.id)
		return false
	fund = _fund_take(gw, c, int(cost["money"]), reserve)
	if fund < int(cost["money"]):
		return false
	var wkey: String = "%d:%d" % [c.id, kind]
	if not c.has_res(rc):


		if not ai._blocked.has(wkey):
			ai._blocked[wkey] = now
		if now - float(ai._blocked[wkey]) > FUND_WAIT:
			c.money += fund
			gw.econ.u_fund.erase(c.id)
			ai._blocked.erase(wkey)
			ai._skip[wkey] = now + FUND_SKIP
			ai._stat(c, "npp_fund_back")
			return false
	else:
		ai._blocked.erase(wkey)
	if not c.has_res(rc):
		gw.econ.ai_blocked(c, rc)
		if c.uranium < int(rc.get("uranium", 0)):
			_want(gw, c, int(rc.get("uranium", 0)) + U_RESERVE / 2)
		ai._stat(c, "npp_wait")
		return false
	c.money += fund
	gw.econ.u_fund.erase(c.id)
	var cap: City = gw.cities[c.capital_id]
	var f2: Facility = gw.mil.auto_place(kind, cap.center, c, cap.radius + 8, cap.radius + 90)
	if f2 == null and c.city_ids.size() > 1:
		var oc: City = gw.cities[c.city_ids[Hash32.h2(c.id, int(now), 302) % c.city_ids.size()]]
		f2 = gw.mil.auto_place(kind, oc.center, c, oc.radius + 8, oc.radius + 70)
	if f2 == null:
		gw.econ.u_fund[c.id] = mini(fund, c.money)
		c.money -= int(gw.econ.u_fund[c.id])
		ai._stat(c, "npp_no_site")
		return false
	c.money -= int(cost["money"])
	gw.econ.pay_build(c, kind)
	ai._after_build(c, f2, P)
	ai._stat(c, "npp")
	if gw.diplo != null:
		gw.diplo.dlog(c.id, "АЭС", "сеть %d/%d, уран %d" % [c.power_use, c.power_cap, c.uranium], float(NPP_CAP), ["eco_npp"])
	return true



static func ai_wants_npp(gw: GameWorld, ai: AiBots, c: Country, have: int) -> bool:
	if gw.game_time < AI_FROM or have >= (1 if c.power_use < 60 else 2):
		return false
	if gw.game_time < float(ai._skip.get("%d:%d" % [c.id, Facility.Kind.NUCLEAR_PLANT], -1.0)):
		return false
	if c.power_use < 18 or c.power_use + 8 <= c.power_cap:
		return false


	var need_u: int = int(Economy.BUILD_COST[Facility.Kind.NUCLEAR_PLANT]["uranium"])
	if c.uranium >= need_u or ai._count(c, Facility.Kind.URANIUM_MINE) > 0 or _free_own_deposit(gw, c):
		return true
	var sel: Country = gw.econ.best_seller(c, "uranium")
	if sel != null and gw.econ.surplus(sel, "uranium") >= need_u - c.uranium:
		return true
	var port: Facility = gw.econ.ports.port_of(c)
	return port != null and gw.econ.ports.ocean(port) and not gw.econ.ports.blocked(c)




static func _fund_take(gw: GameWorld, c: Country, target: int, reserve: int) -> int:
	var fund: int = int(gw.econ.u_fund.get(c.id, 0))
	if fund < target:
		var share: float = [0.2, 0.35, 0.5][GameConfig.diff_of(c)]
		var take: int = clampi(int(float(c.money - reserve / 2) * share), 0, target - fund)
		c.money -= take
		fund += take
		gw.econ.u_fund[c.id] = fund
	return fund




static func _place_umine(gw: GameWorld, c: Country) -> Facility:
	var mk: int = Facility.Kind.URANIUM_MINE
	for dp: Dictionary in gw.econ.deposits:
		if String(dp.get("res", "")) != "uranium" or dp["mine"] != null or int(dp.get("left", 0)) <= 0:
			continue
		var dc: Vector2i = dp["cell"]
		if gw.data.get_owner_id(dc.x, dc.y) != c.id:
			continue
		for r in 4:
			for dy in range( - r, r + 1):
				for dx in range( - r, r + 1):
					if maxi(absi(dx), absi(dy)) != r:
						continue
					var q: Vector2i = dc + Vector2i(dx, dy)
					if gw.mil.check_place(mk, Military.nw_for(mk, q), c, null, false) == "":
						return gw.mil.build(mk, q, c, null, true)
	return null


static func _want(gw: GameWorld, c: Country, n: int) -> void :
	var w: Dictionary = gw.econ.want.get(c.id, {})
	var wt: Dictionary = gw.econ.want_t.get(c.id, {})
	w["uranium"] = maxi(int(w.get("uranium", 0)), n)
	wt["uranium"] = gw.game_time
	gw.econ.want[c.id] = w
	gw.econ.want_t[c.id] = wt


static func _free_own_deposit(gw: GameWorld, c: Country) -> bool:
	for dp: Dictionary in gw.econ.deposits:
		if String(dp.get("res", "")) != "uranium" or dp["mine"] != null or int(dp.get("left", 0)) <= 0:
			continue
		var cell: Vector2i = dp["cell"]
		if gw.data.get_owner_id(cell.x, cell.y) == c.id:
			return true
	return false




static func _cover(gw: GameWorld, ai: AiBots, c: Country, npps: Array[Facility], reserve: int) -> bool:
	for f: Facility in npps:
		if f.restore_t > 0.0:
			continue
		var cp: Vector2 = f.center_px()
		var n: int = 0
		var has_pro: bool = false
		for a: Facility in gw.mil.facilities:
			if a.country_id != c.id or not Defense.is_ad(a.kind) or a.center_px().distance_to(cp) > AI_AD_R:
				continue
			n += 1
			has_pro = has_pro or a.kind == Facility.Kind.AD_PATRIOT
		if n >= 3 or (n >= 2 and (has_pro or GameConfig.diff_of(c) == 0)):
			continue
		var order: Array = [Facility.Kind.AD_SAM, Facility.Kind.AD_SPAAG] if n == 0 else [Facility.Kind.AD_PATRIOT, Facility.Kind.AD_SAM, Facility.Kind.AD_SPAAG]
		for kind: int in order:
			if n > 0 and not ai._ad_room(c, kind):
				continue
			var cost: Dictionary = Economy.build_cost(kind)
			if c.money < int(cost["money"]) + reserve / 2 or not c.has_res(Economy.res_cost("build_%d" % kind)):
				continue
			var nc: Vector2i = f.cell + f.size / 2
			var a2: Facility = gw.mil.auto_place(kind, nc, c, maxi(f.size.x, f.size.y) / 2 + 3, 50)
			if a2 == null:
				continue
			c.money -= int(cost["money"])
			gw.econ.pay_build(c, kind)
			ai._after_build(c, a2, ai.persona_of(c))
			ai._stat(c, "npp_ad")
			return true
	return false
