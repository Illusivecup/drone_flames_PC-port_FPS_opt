extends RefCounted











const STANCE_NAMES: Array = ["ЖДУТ", "ДЕРЖАТ", "НАСТУПАЮТ"]
const STANCE_TITLES: Array = ["Ждут приказа", "Держат район", "Наступают сами"]
const STANCE_ICONS: Array = ["icon_op_retreat", "icon_op_defend", "icon_op_attack"]
const STRIKE_NAMES: Array = ["ВЫКЛ", "ВОЕННЫЕ", "ВСЁ"]
const ARMY_DT: float = 2.0
const ORDER_DT: float = 3.0
const STRIKE_DT: float = 2.0
const STRIKE_GAP: float = 25.0
const DRONE_GAP: float = 30.0
const STRUCK_MEMO: float = 90.0
const MONEY_RESERVE: int = 300
const THREAT_R: float = 400.0
const DEF_REACH: float = 2400.0
const MIN_ARMY: int = 3
const HEAL_BELOW: float = 0.45
const ATTACK_HP: float = 0.7
const ATTACK_N: int = 6
const RETARGET_GAP: float = 20.0
const TRY_GAP: float = 15.0
const CLUSTER: float = 200.0

const MIL_W: Dictionary = {
	Facility.Kind.TEL: 5.0, Facility.Kind.AD_PATRIOT: 4.6, Facility.Kind.AD_SAM: 4.5, Facility.Kind.AIRFIELD: 4.2, 
	Facility.Kind.MISSILE_FACTORY: 4.0, Facility.Kind.AD_RADAR: 3.6, Facility.Kind.DRONE_PORT: 3.5, Facility.Kind.AD_INT: 3.2, 
	Facility.Kind.DRONE_FACTORY: 3.0, Facility.Kind.BARRACKS: 2.6, Facility.Kind.AD_SPAAG: 2.5, Facility.Kind.AD_EW: 2.4, 
	Facility.Kind.AD_MFG: 1.5, 
}

const FrontPlan = preload("res://game/front_plan.gd")
const ECO_W: Dictionary = {Facility.Kind.POWER_PLANT: 4.4, Facility.Kind.REFINERY: 3.8, Facility.Kind.CIV_FACTORY: 2.6, Facility.Kind.SOLAR_FARM: 2.0}




static func tick(gw: GameWorld) -> void :
	var ops: Operations = gw.ops
	FrontPlan.tick(gw)
	var mil: Military = gw.mil
	var now: float = gw.game_time
	for c: Country in gw.countries:
		if not c.is_player or c.eliminated or c.capital_id < 0:
			continue
		var k: String = str(c.id)
		if now >= float(ops.auto_next.get("a" + k, 0.0)):
			ops.auto_next["a" + k] = now + ARMY_DT
			armies(gw, c)
		if c.at_war.is_empty():
			continue
		if bool(ops.auto_orders.get(c.id, false)) and now >= float(ops.auto_next.get("o" + k, 0.0)):
			ops.auto_next["o" + k] = now + ORDER_DT
			orders(gw, c)
		if int(mil.auto_strike.get(c.id, 0)) > 0 and now >= float(mil.strike_next.get(c.id, 0.0)):
			mil.strike_next[c.id] = now + STRIKE_DT
			if strike(gw, c):
				mil.strike_next[c.id] = now + STRIKE_GAP
		if bool(mil.auto_drones.get(c.id, false)) and now >= float(mil.drone_next.get(c.id, 0.0)):
			mil.drone_next[c.id] = now + STRIKE_DT * 2.5
			if drones(gw, c):
				mil.drone_next[c.id] = now + DRONE_GAP






static func enemy_groups(gw: GameWorld, c: Country) -> Array:
	var cells: Dictionary = {}
	for u: Unit in gw.army.units:
		if not u.alive() or not u.ground() or not c.at_war.has(u.country_id):
			continue
		if not _sees(gw, c, u.pos):
			continue
		var key: = Vector2i(floori(u.pos.x / CLUSTER), floori(u.pos.y / CLUSTER))
		var e: Array = cells.get(key, [Vector2.ZERO, 0])
		e[0] = (e[0] as Vector2) + u.pos
		e[1] = int(e[1]) + 1
		cells[key] = e
	var out: Array = []
	for key: Vector2i in cells:
		var e2: Array = cells[key]
		var p: Vector2 = (e2[0] as Vector2) / float(e2[1])
		var city: City = null
		var bd: float = INF
		for cid in c.city_ids:
			var ct: City = gw.cities[cid]
			var d: float = Vector2(ct.center * GameWorld.CELL).distance_to(p) - float(ct.radius * GameWorld.CELL)
			if d < THREAT_R and d < bd:
				bd = d
				city = ct
		out.append({"pos": p, "n": int(e2[1]), "own": gw.ops._owner_at(p) == c.id, "city": city, "d_city": bd})
	return out


static func armies(gw: GameWorld, c: Country) -> void :
	var groups: Array = []
	var got: bool = false
	for f: Facility in gw.mil.facilities:
		if f.kind != Facility.Kind.BARRACKS or f.country_id != c.id or f.stance <= 0 or not gw.mil.alive(f):
			continue
		if not got:
			got = true
			groups = enemy_groups(gw, c)
		_army_think(gw, c, f, groups)


static func _army_think(gw: GameWorld, c: Country, f: Facility, groups: Array) -> void :
	if f.group_id >= 0 and FrontPlan.holds_fac(gw, f):
		return
	var ops: Operations = gw.ops
	if ops.auto_next.has("h%d" % f.id):
		return
	var stay: bool = ops.auto_next.has("k%d" % f.id)
	var now: float = gw.game_time
	var op: Dictionary = ops.list.get(f, {})
	if not op.is_empty() and not bool(op.get("stance", false)):
		return
	var mem: Array[Unit] = ops._army(f)
	if mem.is_empty():
		return
	var hp: float = 0.0
	var mhp: float = 0.0
	var smem: Array[Unit] = ops.strength_units(f)
	for u: Unit in smem:
		hp += u.hp
		mhp += u.max_hp
	var hpf: float = hp / maxf(1.0, mhp)
	var kind: int = int(op.get("kind", -1))
	if kind == Operations.Kind.RETREAT:
		return
	var home: Vector2 = gw.army.barracks_out(f)
	var cen: Vector2 = ops._centre(mem)
	var bpos: Vector2 = f.center_px()

	var best: Dictionary = {}
	var bs: float = - INF
	for g: Dictionary in groups:
		if not bool(g["own"]) and g["city"] == null:
			continue
		var d: float = (g["pos"] as Vector2).distance_to(bpos)
		if d > DEF_REACH:
			continue
		var s: float = float(g["n"]) * 300.0 - d + (600.0 if g["city"] != null else 0.0)
		if s > bs:
			bs = s
			best = g
	var city_attack: bool = kind == Operations.Kind.ATTACK and int(op.get("city", -1)) >= 0
	if not best.is_empty() and city_attack and (best["city"] == null or int(best["n"]) < 3):
		best = {}
	if not best.is_empty():
		if mem.size() < MIN_ARMY or hpf < 0.35:
			if cen.distance_to(home) > 100.0:
				_start(gw, f, Operations.Kind.RETREAT, home)
			return
		var tgt: Vector2 = best["pos"]
		var k: int = Operations.Kind.ATTACK
		var city: City = best["city"]
		if city != null and float(best["d_city"]) > 0.0:

			var cp: = Vector2(city.center * GameWorld.CELL)
			tgt = cp + (tgt - cp).normalized() * (float(city.radius * GameWorld.CELL) + 30.0)
			k = Operations.Kind.DEFEND
		if not op.is_empty() and (op["target"] as Vector2).distance_to(tgt) < 200.0:
			return
		if not op.is_empty() and now - float(op["t0"]) < RETARGET_GAP:
			return
		if now < float(ops.auto_next.get("t%d" % f.id, 0.0)):
			return
		if _start(gw, f, k, tgt) != "":
			ops.auto_next["t%d" % f.id] = now + TRY_GAP
		return

	if hpf < HEAL_BELOW and cen.distance_to(home) > 100.0 and not city_attack and not stay:
		_start(gw, f, Operations.Kind.RETREAT, home)
		return
	if f.stance == 2 and not c.at_war.is_empty():
		if not op.is_empty():
			_note(gw, c, f, "")
			if kind == Operations.Kind.DEFEND and now - float(op["t0"]) > 30.0 and smem.size() >= mini(ATTACK_N, Army.BARRACKS_CAP)\
			and hpf >= ATTACK_HP and now >= float(ops.auto_next.get("t%d" % f.id, 0.0)):


				if not _attack(gw, c, f, groups):
					ops.auto_next["t%d" % f.id] = now + TRY_GAP
			return

		var need: int = mini(ATTACK_N, Army.BARRACKS_CAP)
		if smem.size() < need:
			_note(gw, c, f, Loc.t("АТАКА: ждём %d бойцов") % need)
			return
		if hpf < ATTACK_HP:
			_note(gw, c, f, Loc.t("АТАКА: сначала лечимся"))
			return
		if now < float(ops.auto_next.get("t%d" % f.id, 0.0)):
			return
		if not _attack(gw, c, f, groups):
			ops.auto_next["t%d" % f.id] = now + TRY_GAP
			_note(gw, c, f, Loc.t("АТАКА: нет целей в досягаемости"))
		else:
			_note(gw, c, f, "")
		return
	if f.stance == 2:
		_note(gw, c, f, attack_reason(gw, c, f))



	var keep: bool = not c.at_war.is_empty() and bpos.distance_to(cen) <= DEF_REACH and ops._owner_at(cen) == c.id
	if not op.is_empty():
		if now - float(op["t0"]) > 30.0 and not keep:
			_start(gw, f, Operations.Kind.RETREAT, home)
		return
	if not stay and not keep and cen.distance_to(home) > 300.0 and now >= float(ops.auto_next.get("t%d" % f.id, 0.0)):
		if _start(gw, f, Operations.Kind.RETREAT, home) != "":
			ops.auto_next["t%d" % f.id] = now + TRY_GAP



static func _note(gw: GameWorld, c: Country, f: Facility, why: String) -> void :
	var k: String = "n%d" % f.id
	var prev: String = String(gw.ops.auto_next.get(k, ""))
	if prev == why or (why != "" and prev.get_slice(" (", 0) == why.get_slice(" (", 0)):
		return
	gw.ops.auto_next[k] = why
	if why != "" and c.is_player:
		gw.say(c, Loc.mk("Армия №%d — %s", [f.army_no, why]))



static func attack_reason(gw: GameWorld, c: Country, f: Facility) -> String:
	if c == null or c.at_war.is_empty():
		return Loc.t("АТАКА: войны нет — армия ждёт у казарм")
	var mem: Array[Unit] = gw.ops.strength_units(f)
	var need: int = mini(ATTACK_N, Army.BARRACKS_CAP)
	if mem.size() < need:
		return Loc.t("АТАКА: ждём %d бойцов (есть %d)") % [need, mem.size()]
	return ""






static func _attack(gw: GameWorld, c: Country, f: Facility, groups: Array) -> bool:
	var bpos: Vector2 = f.center_px()
	var cand: Array = []
	for city: City in gw.cities:
		if not c.at_war.has(city.country_id) or gw.diplo.allied(c.id, city.country_id):
			continue
		var cp: = Vector2(city.center * GameWorld.CELL)
		var d: float = cp.distance_to(bpos)
		if d > Operations.MAX_RANGE * 0.97:
			continue
		var sc: float = d + city.garrison * 3.0 + (900.0 if city.kind == City.Kind.CAPITAL else 0.0)

		var goal: Dictionary = gw.diplo.war_goals.get("%d>%d" % [c.id, city.country_id], {})
		if not goal.is_empty() and Vector2(Vector2i(goal["cell"]) * GameWorld.CELL).distance_to(cp) < float(city.radius * GameWorld.CELL) + 200.0:
			sc -= 1500.0
		cand.append([sc, cp])
	cand.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var sea: = Vector2.INF
	for i in mini(4, cand.size()):
		var chk: Dictionary = gw.ops._check(f, Operations.Kind.ATTACK, cand[i][1], Vector2.INF)
		if not bool(chk["ok"]):
			continue
		if chk.has("naval"):
			if not sea.is_finite():
				sea = cand[i][1]
			continue
		if _start(gw, f, Operations.Kind.ATTACK, cand[i][1]) == "":
			return true

	var best: = Vector2.INF
	var bd: float = Operations.MAX_RANGE * 0.9
	for g: Dictionary in groups:
		var p: Vector2 = g["pos"]
		if bool(g["own"]) or p.distance_to(bpos) > bd:
			continue
		bd = p.distance_to(bpos)
		best = p
	if best.is_finite() and _start(gw, f, Operations.Kind.ATTACK, best) == "":
		return true
	return sea.is_finite() and _start(gw, f, Operations.Kind.ATTACK, sea) == ""


static func _start(gw: GameWorld, f: Facility, kind: int, tgt: Vector2) -> String:
	gw.ops._from_auto = true
	var why: String = gw.ops.start(f, kind, tgt)
	gw.ops._from_auto = false
	if why == "" and gw.ops.list.has(f):
		gw.ops.list[f]["stance"] = true
	return why





static func orders(gw: GameWorld, c: Country) -> void :
	var ops: Operations = gw.ops
	var spotted: Array = gw.army.fire.spotted.get(c.id, [])
	if ops.cooldown_left(c.id, Operations.Order.ARTY) <= 0.0:
		var best: = Vector2.INF
		var bn: int = 2
		for e: Array in spotted:
			if not (e[1] is Unit):
				continue
			var n: int = 0
			for e2: Array in spotted:
				if e2[1] is Unit and (e2[0] as Vector2).distance_squared_to(e[0]) < 45.0 * 45.0:
					n += 1
			if n > bn:
				bn = n
				best = e[0]
		if best.is_finite() and _afford(gw, c, Operations.Order.ARTY, best):
			ops.order(c.id, Operations.Order.ARTY, best)
			return
	if ops.cooldown_left(c.id, Operations.Order.SMOKE) <= 0.0:
		for f2: Facility in gw.army.tac.ops:
			var top: Dictionary = gw.army.tac.ops[f2]
			if int(top["c"]) != c.id or not top.has("cen"):
				continue
			var ph: int = int(top["phase"])
			var foe: Vector2 = top["foe"]
			if (ph == 1 or (ph == 2 and bool(top.get("holding", false)))) and foe.is_finite() and gw.game_time - float(top["contact"]) < 6.0:
				var sp: Vector2 = (top["cen"] as Vector2).lerp(foe, 0.45)
				if _afford(gw, c, Operations.Order.SMOKE, sp):
					ops.order(c.id, Operations.Order.SMOKE, sp)
					return
	if ops.cooldown_left(c.id, Operations.Order.MEDIC) <= 0.0:

		var hs: Vector2 = ops.medic_spot(c.id)
		if hs.is_finite() and _afford(gw, c, Operations.Order.MEDIC, hs):
			ops.order(c.id, Operations.Order.MEDIC, hs)


static func _afford(gw: GameWorld, c: Country, kind: int, p: Vector2) -> bool:
	var chk: Dictionary = gw.ops.order_check(c.id, kind, p)
	return bool(chk["ok"]) and c.money - int((chk["cost"] as Dictionary).get("money", 0)) >= MONEY_RESERVE





static func targets(gw: GameWorld, c: Country, mode: int, from: Vector2) -> Array:




	var mil: Military = gw.mil
	var now: float = gw.game_time
	var out: Array = []
	var own_units: Array[Vector2] = mil.air.own_ground(c)
	for f: Facility in mil.facilities:
		if f.parent != null or ( not c.at_war.has(f.country_id) and gw.diplo.sky_target(c.id, f) <= 0):
			continue
		var w: float = float(MIL_W.get(f.kind, 0.0))
		if w <= 0.0 and mode >= 2:
			w = float(ECO_W.get(f.kind, 0.0))
		if w <= 0.0:
			continue
		if now - float(mil.struck.get(f.id, -999.0)) < STRUCK_MEMO:
			continue
		if not mil.alive(f) or f.moving:
			continue
		var p: Vector2 = f.center_px()
		if not mil.air.sim_knows(c, f, own_units):
			continue
		out.append([w * 1000.0 - p.distance_to(from) * 0.05, f, p])
	out.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	return out





static func strike(gw: GameWorld, c: Country) -> bool:
	var mil: Military = gw.mil
	var air: Air = mil.air
	var mode: int = int(mil.auto_strike.get(c.id, 0))
	var cap: = Vector2(gw.cities[c.capital_id].center * GameWorld.CELL)
	var list: Array = targets(gw, c, mode, cap)
	var b_total: int = mil.missiles_ready(c.id) + c.missile_stock[Military.MT_BALLISTIC]
	var cr_total: int = c.missile_stock[Military.MT_CRUISE]
	var hy_total: int = c.missile_stock[Military.MT_HYPER]
	var flying: Array[Aircraft] = []
	for a: Aircraft in air.aircraft:
		if a.country_id != c.id or a.state == Aircraft.State.DEAD:
			continue
		if a.type == Aircraft.Type.BOMBER:
			cr_total += a.missiles
		elif a.type == Aircraft.Type.FIGHTER and a.pylon == 1:
			cr_total += a.pylon_n
		elif a.type == Aircraft.Type.FIGHTER and a.pylon == 2:
			hy_total += a.pylon_n
		if a.airborne() and a.state != Aircraft.State.LAND:
			flying.append(a)
	if b_total < 2 and cr_total < 2 and hy_total < 2:
		return false
	for i in mini(8, list.size()):
		var f: Facility = list[i][1]
		var p: Vector2 = list[i][2]
		var big: bool = float(MIL_W.get(f.kind, 0.0)) >= 4.5
		var how: String = ""
		if b_total >= 2:
			var ready: int = 0
			for t: Facility in mil.tels_for(c, p):
				ready += maxi(0, t.missiles - t.queued.size())
			var n: int = mini(mini(ready, b_total - 1), 2 if big and b_total >= 4 else 1)
			if n > 0 and mil.launch_missiles(c, p, n) > 0:
				how = Loc.t("баллистическая ракета") if n == 1 else Loc.t("%d баллистические ракеты") % n
		if how == "" and cr_total >= 2:
			for a: Aircraft in flying:
				var load: int = a.missiles if a.type == Aircraft.Type.BOMBER else (a.pylon_n if a.pylon == 1 else 0)
				if load <= 0 or a.pos.distance_to(p) > Air.CR_RANGE * 0.95:
					continue
				var n2: int = mini(mini(load, cr_total - 1), 2)
				if n2 > 0 and air.launch_cruise(a, p, n2) > 0:
					how = Loc.t("крылатая ракета") if n2 == 1 else Loc.t("%d крылатые ракеты") % n2
					break
		if how == "" and hy_total >= 2:
			for a2: Aircraft in flying:
				if a2.type == Aircraft.Type.FIGHTER and a2.pylon == 2 and a2.pylon_n > 0 and a2.pos.distance_to(p) <= Air.HYPER_RANGE * 0.95:
					if air.launch_hyper(a2, p):
						how = Loc.t("гиперзвуковая ракета")
						break
		if how != "":
			mil.struck[f.id] = gw.game_time
			mil.auto_log.append([gw.game_time, f.id, f.kind, how])
			if mil.auto_log.size() > 20:
				mil.auto_log.pop_front()
			gw.say(c, Loc.mk("АВТОУДАР: %s — %s", [how, Military.title_of(f.kind)]))
			return true
	return false




static func drones(gw: GameWorld, c: Country) -> bool:
	var mil: Military = gw.mil
	var have: int = 0
	var jets: int = 0
	for f: Facility in mil.facilities:
		if f.kind == Facility.Kind.DRONE_PORT and f.country_id == c.id and mil.alive(f):
			have += mil.parked_at(f, 0)
			jets += mil.parked_at(f, 2)
	if have < 2 and jets < 2:
		return false
	var cap: = Vector2(gw.cities[c.capital_id].center * GameWorld.CELL)
	var list: Array = targets(gw, c, 1, cap)
	for i in mini(8, list.size()):
		var f2: Facility = list[i][1]
		var p: Vector2 = list[i][2]
		var port: Facility = mil.best_port(c, p)
		if port == null or mil.port_launchers(port).is_empty():
			return false
		var d: float = mil.launch_point(port).distance_to(p)
		var wps: Array[Vector2] = []
		var sent: int = 0
		if have >= 2 and d <= Military.RANGE_PX * 0.9:
			sent += mil.launch(c, wps, p, mini(3, have - 1)).size()
		if jets >= 2 and d <= Military.JET_RANGE * 0.9 and mil.runways_of(port) > 0:
			sent += mil.launch(c, wps, p, 1, true).size()
		if sent > 0:
			mil.struck[f2.id] = gw.game_time
			gw.say(c, Loc.mk("АВТО-ДРОНЫ: %d в полёте — %s", [sent, Military.title_of(f2.kind)]))
			return true
	return false





static func summary(gw: GameWorld, country_id: int) -> Dictionary:
	var c: Country = gw.country_by_id(country_id)
	var out: Dictionary = {"armies": [], "orders": [], "missiles": [], "drones": {"stock": 0, "jets": 0, "in_air": 0}, 
		"auto_orders": false, "auto_strike": 0, "auto_drones": false, "threats": [], "at_war": []}
	out["bombers"] = []
	out["auto_kab"] = false
	if c == null:
		return out
	var ops: Operations = gw.ops
	var mil: Military = gw.mil
	var per: Dictionary = {}
	for u: Unit in gw.army.units:
		if u.home == null or u.country_id != country_id or not u.alive() or u.type == Unit.Type.FPV or u.reinf != 0:
			continue
		var e: Array = per.get(u.home, [0, 0.0, 0.0])
		e[0] = int(e[0]) + 1
		e[1] = float(e[1]) + u.hp
		e[2] = float(e[2]) + u.max_hp
		per[u.home] = e
	var armies: Array = []
	var jets: int = 0
	var stock: int = 0
	for f: Facility in mil.facilities:
		if f.country_id != country_id:
			continue
		if f.kind == Facility.Kind.DRONE_PORT and mil.alive(f):
			stock += mil.parked_at(f, 0)
			jets += mil.parked_at(f, 2)
		if f.kind != Facility.Kind.BARRACKS or not mil.alive(f):
			continue
		var e2: Array = per.get(f, [0, 0.0, 0.0])
		armies.append({"fid": f.id, "no": f.army_no, "name": String(gw.army.build_of(f)["name"]), "n": int(e2[0]), "cap": Army.BARRACKS_CAP, 
			"hp_frac": float(e2[1]) / maxf(1.0, float(e2[2])) if int(e2[0]) > 0 else 0.0, "stance": f.stance, "op": ops.of(f), "pos": f.center_px(), "doing": ops.doing_text(f)})
	armies.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a["no"]) < int(b["no"]))
	out["armies"] = armies
	for k in Operations.ORDERS.size():
		var s: Dictionary = Operations.ORDERS[k]
		var left: float = ops.cooldown_left(country_id, k)
		out["orders"].append({"kind": k, "name": s["name"], "icon": s["icon"], "cd_left": left, "ready": left <= 0.0})

	var loaded: Array[int] = [mil.missiles_ready(country_id), 0, 0, 0, 0, 0]
	for a: Aircraft in mil.air.aircraft:
		if a.country_id != country_id or a.state == Aircraft.State.DEAD:
			continue
		if a.type == Aircraft.Type.BOMBER:
			loaded[Military.MT_CRUISE] += a.missiles
		elif a.type == Aircraft.Type.FIGHTER:
			loaded[Military.MT_AA] += a.missiles
			if a.pylon == 1:
				loaded[Military.MT_CRUISE] += a.pylon_n
			elif a.pylon == 2:
				loaded[Military.MT_HYPER] += a.pylon_n
		elif a.type == Aircraft.Type.ATTACK:
			loaded[Military.MT_AA] += a.missiles
			loaded[Military.MT_KAB] += a.kab
	for t in Military.MT_NAMES.size():
		out["missiles"].append({"type": t, "name": Military.MT_NAMES[t], "icon": Military.MT_ICONS[t], "stock": c.missile_stock[t], "ready": loaded[t]})
	var in_air: int = 0
	var threats: Array = []
	for d: Drone in mil.drones:
		if d.state == Drone.State.DONE or not d.airborne():
			continue
		if d.country_id == country_id and d.kind != 1:
			in_air += 1
		elif c.at_war.has(d.country_id) and ops._owner_at(d.target) == country_id and threats.size() < 8 and _sees_air(gw, c, d.pos):
			threats.append({"text": Loc.t("КР летит на %s") % _place(gw, d.target) if d.kind == 1 else Loc.t("Дрон летит на %s") % _place(gw, d.target), "pos": d.pos})
	out["drones"] = {"stock": stock, "jets": jets, "in_air": in_air}
	for m: Missile in mil.missiles:
		if c.at_war.has(m.country_id) and ops._owner_at(m.target) == country_id and threats.size() < 10:
			threats.append({"text": Loc.t("Ракета на %s: %d с") % [_place(gw, m.target), ceili(m.time_left())], "pos": m.target})
	if not c.at_war.is_empty():
		for g: Dictionary in enemy_groups(gw, c):
			if (bool(g["own"]) or g["city"] != null) and threats.size() < 12:
				var city: City = g["city"]
				threats.append({"text": (Loc.t("Враг у %s: %d") % [BattleWatch.genitive(city.name), int(g["n"])]) if city != null else Loc.t("Враг на нашей земле: %d") % int(g["n"]), "pos": g["pos"]})
	out["threats"] = threats
	out["auto_orders"] = bool(ops.auto_orders.get(country_id, false))
	out["auto_strike"] = int(mil.auto_strike.get(country_id, 0))
	out["auto_drones"] = bool(mil.auto_drones.get(country_id, false))
	out["bombers"] = mil.air.bomber_summary(country_id)
	out["auto_kab"] = mil.air.auto_kab_of(country_id)
	for id: int in c.at_war.keys():
		var o: Country = gw.country_by_id(id)
		if o != null and not o.eliminated:
			out["at_war"].append(o.name)
	return out




static func _sees(gw: GameWorld, c: Country, p: Vector2) -> bool:
	if c.is_player and not gw.net_driven and gw.vision != null and gw.vision.active():
		return gw.vision.sees(p)
	return true


static func _sees_air(gw: GameWorld, c: Country, p: Vector2) -> bool:
	if c.is_player and not gw.net_driven and gw.vision != null and gw.vision.active():
		return gw.vision.sees_air(p) or gw.vision.sees(p)
	return true



static func _place(gw: GameWorld, p: Vector2) -> String:
	var best: String = Loc.t("наши объекты")
	var bd: float = 900.0
	for city: City in gw.cities:
		var d: float = Vector2(city.center * GameWorld.CELL).distance_to(p) - float(city.radius * GameWorld.CELL)
		if d < bd:
			bd = d
			best = city.name
	return best
