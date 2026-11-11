extends RefCounted








const FrontPlan = preload("res://game/front_plan.gd")

const TICK: float = 0.5
const HOME_R: float = 260.0
const FAR: float = 500.0
const JOIN_R: float = 120.0
const SQUAD_MAX: int = 4
const MERGE_R: float = 180.0
const GATHER_WAIT: float = 20.0
const GATHER_MAX: float = 30.0
const RETARGET: float = 3.0
const REPLAN_D: float = 120.0
const STUCK_T: float = 15.0
const BACK_R: float = 420.0
const NO_REGATHER: float = 300.0

var army: Army
var _acc: float = 0.0


func _init(a: Army) -> void :
	army = a


func tick(dt: float) -> void :
	_acc += dt
	if _acc < TICK - 0.0001:
		return
	_acc = 0.0
	var gw: GameWorld = army.gw
	if gw.ops == null:
		return

	var by: Dictionary = {}
	var homes: Array[Facility] = []
	for u: Unit in army.units:
		if u.home == null or not u.alive() or not u.ground():
			continue
		var c: Country = gw.country_by_id(u.country_id)
		if c == null or not c.is_player:
			if u.reinf != 0:


				_drop(u, Vector2.INF, "owner")
			continue
		if not by.has(u.home):
			by[u.home] = [] as Array[Unit]
			homes.append(u.home)
		(by[u.home] as Array[Unit]).append(u)
	for f: Facility in homes:
		_army_tick(f, by[f])


func _army_tick(f: Facility, mem: Array[Unit]) -> void :
	var gw: GameWorld = army.gw
	var lost: bool = not gw.mil.facilities.has(f) or f.country_id != mem[0].country_id or f.kind != Facility.Kind.BARRACKS
	var sea: bool = gw.naval != null and gw.naval.busy(f)
	var home: Vector2 = army.barracks_out(f)
	var core: Array[Unit] = []
	var at_home: Array[Unit] = []
	for u: Unit in mem:
		if u.reinf != 0 or u.post != null:
			continue
		if not u.op_on and u.pos.distance_to(home) <= HOME_R:
			at_home.append(u)
		else:
			core.append(u)
	if lost or core.is_empty():
		for u: Unit in mem:
			if u.reinf != 0:
				_drop(u, home if not lost and u.reinf == 2 else Vector2.INF, "army")
		return
	if sea:



		for u: Unit in mem:
			if u.reinf != 0:
				_drop(u, home, "sea")
		return
	var cen: Vector2 = gw.ops._centre(core)
	var dh: float = cen.distance_to(home)
	if dh < BACK_R:
		for u: Unit in mem:
			if u.reinf == 1:
				u.reinf = 0
	elif dh >= FAR and at_home.size() > core.size() * 2:




		for u: Unit in at_home:
			u.reinf_t = maxf(u.reinf_t, gw.game_time + TICK * 2.0)
	elif dh >= FAR:
		for u: Unit in at_home:
			if u.target_city < 0 and u.target == null and not _held(u) and gw.game_time >= u.reinf_t:
				u.reinf = 1
				u.reinf_t = gw.game_time
	for u: Unit in mem:
		if u.reinf == 1 and u.state == Unit.State.IDLE and u.target == null and u.pos.distance_to(home) > HOME_R + 40.0:
			u.reinf = 2
			u.reinf_v = 0.0
			u.reinf_t = -1.0
			u.still_t = 0.0
			u.reinf_s = gw.game_time
	_release(f, mem, home)
	_walk(f, mem, core, cen, home)


func _held(u: Unit) -> bool:
	var gw: GameWorld = army.gw
	return gw.hold != null and gw.hold.holds_unit(u)




func _release(f: Facility, mem: Array[Unit], home: Vector2) -> void :
	var gw: GameWorld = army.gw
	var ready: Array[Unit] = []
	var t0: float = INF
	for u: Unit in mem:
		if u.reinf == 1 and u.state == Unit.State.IDLE and u.pos.distance_to(home) <= HOME_R:
			ready.append(u)
			t0 = minf(t0, u.reinf_t)
	if ready.is_empty():
		return

	var lead: Unit = null
	var near_n: int = 0
	for u: Unit in mem:
		if u.reinf == 2 and u.pos.distance_to(home) <= MERGE_R:
			near_n += 1
			if lead == null:
				lead = u
	if lead != null and near_n < SQUAD_MAX:
		var take: int = mini(SQUAD_MAX - near_n, ready.size())
		for i in take:
			var u2: Unit = ready[i]
			u2.reinf = 2
			u2.reinf_v = 0.0
			u2.reinf_t = -1.0
			u2.still_t = 0.0
			u2.reinf_s = lead.reinf_s
		FrontPlan._stat("reinf_merged", take)
		ready = ready.slice(take)
		if ready.is_empty():
			return

	var due: float = _due(f)
	var waited: float = gw.game_time - t0
	if ready.size() < SQUAD_MAX and waited < GATHER_MAX and due <= GATHER_WAIT:
		return
	var sq: Array[Unit] = ready.slice(0, SQUAD_MAX)
	var v: float = INF
	v = 0.0
	for u: Unit in sq:
		u.reinf = 2
		u.reinf_v = v
		u.reinf_t = -1.0
		u.still_t = 0.0
		u.reinf_s = gw.game_time
	FrontPlan._stat("reinf_squads")
	FrontPlan._stat("reinf_units", sq.size())
	FrontPlan._stat("reinf_sq%d" % sq.size())




func _due(f: Facility) -> float:
	var gw: GameWorld = army.gw
	if f.halted or f.prod_type == 3 or not gw.mil.alive(f):
		return INF
	var boost: float = maxf(0.01, gw.ops.refill_boost(f))
	if f.producing and not f.queued.is_empty():
		var t: int = int(f.queued[0])
		var need: float = float(Army.SPEC[t]["time"]) * (Army.REFILL_SLOW if f.prod_refill else 1.0)
		return maxf(0.0, need - f.prod_t) / boost
	if (f.filled and not army.refill_on(f)) or army.wait_reason.has(f) or army.units_of(f).size() >= army.cap_of(f):
		return INF
	var t2: int = army._next_type(f)
	if t2 < 0:
		return INF
	return float(Army.SPEC[t2]["time"]) * (Army.REFILL_SLOW if f.filled else 1.0) / boost


func _walk(f: Facility, mem: Array[Unit], core: Array[Unit], cen: Vector2, home: Vector2) -> void :
	var gw: GameWorld = army.gw
	for u: Unit in mem:
		if u.reinf != 2:
			continue
		var near: bool = false
		for o: Unit in core:
			if o.pos.distance_squared_to(u.pos) < JOIN_R * JOIN_R:
				near = true
				break
		if near or u.pos.distance_to(cen) < JOIN_R:
			_join(f, u, cen)
			continue
		if u.still_t >= STUCK_T:
			_old_way(f, u, cen, "stuck")
			continue
		if gw.game_time < u.reinf_t:
			continue
		u.reinf_t = gw.game_time + RETARGET
		var dest: Vector2 = army.safe_point(_meet(f, cen), u.slot)
		if u.pi < u.path.size() and u.path[u.path.size() - 1].distance_to(dest) < REPLAN_D:
			continue
		var pth: PackedVector2Array = gw.econ.nav_path(u.pos, dest)
		if pth.is_empty() or not gw.econ.nav_last_ok or FrontPlan.closed_path(gw, u.country_id, pth):
			_old_way(f, u, cen, "noway")
			continue
		pth[pth.size() - 1] = dest
		u.path = pth

		var jn: int = 0
		var bd: float = INF
		for k in mini(5, pth.size()):
			var dd: float = pth[k].distance_squared_to(u.pos)
			if dd < bd:
				bd = dd
				jn = k
		u.pi = mini(jn + 1, pth.size() - 1) if pth.size() > 1 else 0
		u.op_move = true
		u.target_city = -1
		u.state = Unit.State.MOVE





func _meet(f: Facility, cen: Vector2) -> Vector2:
	var top: Dictionary = army.tac.ops.get(f, {})
	if top.is_empty() or not top.has("halts"):
		return cen
	var halts: Array = top["halts"]
	var legs: Array = top.get("leg", [-1, -1])
	if halts.is_empty() or legs.size() < 2:
		return cen
	var k: int = maxi(int(legs[0]), int(legs[1]))
	if k < 0:
		return cen
	var hp: Vector2 = (halts[clampi(k, 0, halts.size() - 1)] as Dictionary)["p"]
	return hp


func _join(f: Facility, u: Unit, cen: Vector2) -> void :
	var gw: GameWorld = army.gw
	u.reinf = 0
	u.reinf_v = 0.0
	u.op_move = false
	if gw.ops.list.has(f) and gw.ops.rejoin(u):
		FrontPlan._stat("reinf_joined")
		return
	var dest: Vector2 = army.safe_point(cen, u.slot)
	u.path = gw.econ.nav_path(u.pos, dest) if u.pos.distance_to(dest) > 40.0 else PackedVector2Array([dest])
	if u.path.is_empty():
		u.path = PackedVector2Array([dest])
	u.path[u.path.size() - 1] = dest
	u.pi = 0
	u.target_city = -1
	u.state = Unit.State.MOVE
	FrontPlan._stat("reinf_joined")




func _old_way(f: Facility, u: Unit, cen: Vector2, why: String) -> void :
	var gw: GameWorld = army.gw
	u.reinf = 0
	u.reinf_v = 0.0
	u.reinf_t = gw.game_time + NO_REGATHER
	u.op_move = false
	FrontPlan._stat("reinf_dropped")
	FrontPlan._stat("reinf_drop_" + why)
	if gw.ops.list.has(f) and gw.ops.rejoin(u):
		if FrontPlan.closed_path(gw, u.country_id, u.path):
			_not_closed(f, u)
		return

	var dest: Vector2 = army.safe_point(cen, u.slot)
	u.path = gw.econ.nav_path(u.pos, dest)
	if u.path.is_empty():
		u.path = PackedVector2Array([dest])
	u.pi = 0
	u.target_city = -1
	u.state = Unit.State.MOVE
	if FrontPlan.closed_path(gw, u.country_id, u.path):
		_not_closed(f, u)





func _not_closed(f: Facility, u: Unit) -> void :
	var gw: GameWorld = army.gw
	u.op_on = false
	u.op_hold = false
	u.op_move = false
	u.target_city = -1
	var dest: Vector2 = army.barracks_out(f) + u.slot
	var pth: PackedVector2Array = gw.econ.nav_path(u.pos, dest) if u.pos.distance_to(dest) > 40.0 else PackedVector2Array()
	if pth.is_empty() or FrontPlan.closed_path(gw, u.country_id, pth):
		u.path = PackedVector2Array()
		u.pi = 0
		u.state = Unit.State.IDLE
		return
	pth[pth.size() - 1] = dest
	u.path = pth
	u.pi = 0
	u.state = Unit.State.MOVE
	FrontPlan._stat("reinf_closed_home")



func _drop(u: Unit, home: Vector2, why: String) -> void :
	var was: int = u.reinf
	u.reinf = 0
	u.reinf_v = 0.0
	if was == 2:
		u.reinf_t = army.gw.game_time + NO_REGATHER
	if was != 2:
		return
	u.op_move = false
	if home.is_finite():
		var dest: Vector2 = home + u.slot
		u.path = army.gw.econ.nav_path(u.pos, dest)
		if u.path.is_empty():
			u.path = PackedVector2Array([dest])
		u.pi = 0
		u.state = Unit.State.MOVE
	FrontPlan._stat("reinf_dropped")
	FrontPlan._stat("reinf_drop_" + why)



func counts(f: Facility) -> Vector2i:
	var g: int = 0
	var w: int = 0
	for u: Unit in army.units:
		if u.home == f and u.alive():
			if u.reinf == 1:
				g += 1
			elif u.reinf == 2:
				w += 1
	return Vector2i(g, w)
