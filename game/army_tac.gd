extends RefCounted









enum Phase{MARCH, BOUND, REGROUP, ASSAULT, FIREBASE, HOLD}
const HALT_STEP: float = 96.0
const SAMPLE: float = 32.0
const MAX_SAMPLES: int = 90
const COVER_R: int = 7
const CONTACT_R: float = 240.0
const ASSAULT_LINE: float = 110.0
const LEG_TIMEOUT: float = 18.0
const STORM_AT: float = 0.35
const RETREAT_AT: float = 0.4

var army: Army
var gw: GameWorld
var ops: Dictionary = {}
var craters: Dictionary = {}
var _t: float = 0.0


func _init(a: Army) -> void :
	army = a
	gw = a.gw





func cover_at(c: Vector2i) -> float:
	var d: WorldData = gw.data
	if not d.inside(c.x, c.y):
		return 1.0
	if gw.mil.fort_cells.has(c):
		return 0.45 if (gw.mil.fort_cells[c] as Facility).kind == Facility.Kind.TRENCH_H else 0.75
	if d.has_flag(c.x, c.y, WorldData.F_OCCUPIED):
		return 0.55
	if craters.has(c):
		return 0.7
	if gw.tree_at.has(c.y * d.w + c.x):
		return 0.7
	if d.has_flag(c.x, c.y, WorldData.F_CITY):
		return 0.85
	return 1.0



func unit_cover(p: Vector2) -> float:
	var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	var best: float = cover_at(c)
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		best = minf(best, cover_at(c + o))
	return best


func add_crater(p: Vector2) -> void :
	craters[Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))] = true



func _best_cover(p: Vector2) -> Array:
	var d: WorldData = gw.data
	var c0: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	var best: float = 1.0
	var bp: Vector2 = p
	var bd: int = 999
	for dy in range( - COVER_R, COVER_R + 1, 2):
		for dx in range( - COVER_R, COVER_R + 1, 2):
			var c: = c0 + Vector2i(dx, dy)
			if not d.inside(c.x, c.y) or Biome.is_water(d.get_biome(c.x, c.y)) or d.has_flag(c.x, c.y, WorldData.F_BRIDGE):
				continue
			var s: float = cover_at(c)
			var dd: int = dx * dx + dy * dy
			if s < best - 0.01 or (s < 1.0 and absf(s - best) <= 0.01 and dd < bd):
				best = s
				bd = dd
				bp = Vector2(c * GameWorld.CELL) + Vector2(2, 2)
	return [best, bp]



func _open_ground(pts: Array, lo: int, hi: int, pref: int) -> Vector2:
	var order: Array = [pref]
	for j in range(hi - 1, lo - 1, -1):
		if j != pref:
			order.append(j)
	for j: int in order:
		var p: Vector2 = pts[j][0]
		if _dry(p):
			return p
	var lp: Vector2 = gw.econ.land_point(pts[pref][0], 6)
	return lp


func _dry(p: Vector2) -> bool:
	var d: WorldData = gw.data
	var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	return d.inside(c.x, c.y) and not Biome.is_water(d.get_biome(c.x, c.y)) and not d.has_flag(c.x, c.y, WorldData.F_BRIDGE)




func _plan(path: PackedVector2Array, goal: Vector2, stop_d: float) -> Array:

	var pts: Array = []
	var carry: float = 0.0
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var seg: float = a.distance_to(b)
		var s: float = SAMPLE - carry
		while s <= seg:
			var q: Vector2 = a.lerp(b, s / maxf(seg, 0.001))
			pts.append([q, i])
			if q.distance_to(goal) <= stop_d:
				break
			s += SAMPLE
		if not pts.is_empty() and (pts[pts.size() - 1][0] as Vector2).distance_to(goal) <= stop_d:
			break
		carry = seg - (s - SAMPLE)
	if pts.is_empty():
		pts.append([path[path.size() - 1], path.size() - 1])
	var first: int = maxi(0, pts.size() - MAX_SAMPLES)
	var per: int = maxi(1, int(HALT_STEP / SAMPLE))
	var halts: Array = []
	var k: int = first
	while k < pts.size():
		var hi: int = mini(pts.size(), k + per)
		var best: Array = [2.0, Vector2.ZERO]
		var bi: int = hi - 1
		for j in range(k, hi):
			var bc: Array = _best_cover(pts[j][0])
			if float(bc[0]) < float(best[0]) - 0.01:
				best = bc
				bi = j
		var hp: Vector2 = best[1] if float(best[0]) < 1.0 else _open_ground(pts, k, hi, bi)
		halts.append({"p": hp, "i": int(pts[bi][1]), "cv": float(best[0])})
		k = hi

	var last: Array = pts[pts.size() - 1]
	var lc: Array = _best_cover(last[0])
	var lp: Vector2 = lc[1] if float(lc[0]) < 1.0 else _open_ground(pts, maxi(0, pts.size() - 3), pts.size(), pts.size() - 1)
	halts[halts.size() - 1] = {"p": lp, "i": int(last[1]), "cv": float(lc[0])}
	return halts




func start(home: Facility, members: Array[Unit], city: City, via: Vector2 = Vector2.INF) -> bool:
	if members.is_empty():
		return false
	var cen: Vector2 = _cen(members)
	var goal: = Vector2(city.center * GameWorld.CELL)
	var forced: bool = sea_pref and gw.ops != null and gw.ops.sea_force
	var path: PackedVector2Array = route(cen, goal, via, true) if not forced else PackedVector2Array()
	if gw.econ.nav_last_pending and not forced:
		return false
	if ( not gw.econ.nav_last_ok or sea_pref) and gw.naval != null:
		var nv: int = gw.naval.divert(home, members, city, goal, Naval.Mode.CITY, sea_pref)
		if nv == 1:
			return true
		if nv == 2:
			cen = Naval.centre(members)
			path = route(cen, goal, via)
	path = _legal(home, cen, goal, path)
	if path.size() < 2:
		return false
	var style: String = String(army.build_of(home)["style"])
	var support: bool = style == "support"
	var edge: float = float(city.radius * GameWorld.CELL)
	var stop_d: float = edge + ASSAULT_LINE
	if support:

		var reach: float = INF
		for u: Unit in members:
			if u.indirect():
				reach = minf(reach, float(Army.SPEC[u.type]["range"]))
		stop_d = maxf(edge + 150.0, (reach if reach < INF else 600.0) * 0.85)
	var halts: Array = _plan(path, goal, stop_d)
	var op: Dictionary = {"home": home, "c": home.country_id, "city": city.id, "goal": goal, "path": path, "halts": halts, 
		"leg": [-1, -1], "mv": -1, "phase": Phase.MARCH, "t": 0.0, "contact": -99.0, "smoke": 0.0, "req": 0.0, 
		"support": support, "style": style, "flare": 0.0, "foe": Vector2.INF}
	stop(home)
	ops[home] = op
	op["n_start"] = _strength(members)
	var k: int = 0
	for u: Unit in members:
		u.op_on = true
		u.op_hold = true
		u.op_move = false
		u.team = k % 2
		u.target_city = city.id
		u.target = null
		u.cover = 1.0
		k += 1
	_send(op, -1, _first_halt(op, cen))
	return true



func stop(home: Facility) -> void :
	if not ops.has(home):
		return
	for u: Unit in army.units:
		if u.home == home and u.op_on:
			_free(u)
	ops.erase(home)







const STALL_T: float = 90.0
const STALL_D: float = 20.0


func _storm_stalled(op: Dictionary, mem: Array[Unit], city: City, now: float) -> bool:
	if city == null:
		return false
	var best: float = INF
	for u: Unit in mem:
		if not u.indirect():
			best = minf(best, u.pos.distance_to(op["goal"]))
	if best == INF:
		return false
	if best < float(op.get("st_d", INF)) - STALL_D:
		op["st_d"] = best
		op["st_t"] = now
		return false
	if now - float(op.get("st_t", now)) < STALL_T or best <= float(city.radius * GameWorld.CELL) + ASSAULT_LINE * 2.0:
		return false
	var home: Facility = op["home"]
	var me: Country = gw.country_by_id(int(op["c"]))
	if me != null and me.is_player:
		gw.say(me, Loc.mk("Армия №%d: до г. %s не пройти по суше — штурм отменён", [home.army_no, Loc.name(city.name)]))
	stop(home)
	return true


func stop_country(country_id: int) -> void :
	for h: Facility in ops.keys():
		if int(ops[h]["c"]) == country_id:
			stop(h)


func _free(u: Unit) -> void :
	u.op_on = false
	u.op_hold = false
	u.op_move = false
	u.target_city = -1
	if u.alive() and u.state != Unit.State.DEAD:
		u.state = Unit.State.IDLE


func _members(op: Dictionary) -> Array[Unit]:
	var out: Array[Unit] = []
	var h: Facility = op["home"]
	for u: Unit in army.units:
		if u.home == h and u.op_on and u.alive():
			out.append(u)
	return out



func _send(op: Dictionary, team: int, k: int) -> void :
	var halts: Array = op["halts"]
	k = clampi(k, 0, halts.size() - 1)
	var path: PackedVector2Array = op["path"]
	var legs: Array = op["leg"]
	var j: int = 0
	var bounding: bool = int(op["phase"]) == Phase.BOUND
	for u: Unit in _members(op):
		if team >= 0 and u.team != team:
			continue

		var from_leg: int = int(legs[u.team])
		var lo: int = int(halts[from_leg - 1]["i"]) if from_leg >= 1 else 0
		var i1: int = int(halts[k]["i"])
		var i0: int = lo
		var bd: float = INF
		for i in range(lo, mini(i1 + 1, path.size())):
			var dd: float = path[i].distance_squared_to(u.pos)
			if dd < bd:
				bd = dd
				i0 = i
		var off: = Vector2(float(j % 3 - 1) * 9.0, float(j / 3) * 8.0 - 6.0)
		var dest: Vector2 = army.safe_point(halts[k]["p"], off)
		var p: = PackedVector2Array()
		for i in range(i0 + 1, i1):
			p.append(path[i])
		p.append(dest)
		if gw.econ._wet_path(PackedVector2Array([u.pos, p[0]])):


			var own: PackedVector2Array = gw.econ.army_path(u.pos, dest)
			if gw.econ.nav_last_ok and own.size() > 0:
				own[own.size() - 1] = dest
				p = own
		u.path = p
		u.pi = 0
		u.state = Unit.State.MOVE
		u.op_hold = true
		u.op_move = bounding and not u.indirect()
		u.cover = 1.0
		j += 1
	if team < 0:
		legs[0] = k
		legs[1] = k
	else:
		legs[team] = k
	op["t"] = 0.0








const FIRST_SKIP: float = 64.0
const MARCH_ROLL: float = 30.0


func _first_halt(op: Dictionary, cen: Vector2) -> int:
	op["fast"] = not bool(op["support"])
	var halts: Array = op["halts"]
	if not bool(op["fast"]) or halts.size() < 2:
		return 0
	var g: Vector2 = op["goal"]
	if (halts[0]["p"] as Vector2).distance_to(cen) < FIRST_SKIP or (halts[0]["p"] as Vector2).distance_to(g) > cen.distance_to(g):
		return 1
	return 0



func _near_end(op: Dictionary, r: float) -> float:
	var n: int = 0
	var ok: int = 0
	for u: Unit in _members(op):
		n += 1
		if u.pi >= u.path.size() or u.pos.distance_to(u.path[u.path.size() - 1]) <= r:
			ok += 1
	return float(ok) / float(maxi(1, n))



func _arrived(op: Dictionary, team: int) -> float:
	var n: int = 0
	var ok: int = 0
	for u: Unit in _members(op):
		if team >= 0 and u.team != team:
			continue
		n += 1
		if u.pi >= u.path.size():
			ok += 1
	return float(ok) / float(maxi(1, n))


func update(dt: float) -> void :
	_t += dt
	if _t < 0.5:
		return
	var step: float = _t
	_t = 0.0
	for h: Facility in ops.keys():
		_tick(ops[h], step)


func _tick(op: Dictionary, dt: float) -> void :
	var home: Facility = op["home"]
	var mem: Array[Unit] = _members(op)
	if mem.is_empty():
		ops.erase(home)
		return
	var area: bool = int(op["city"]) < 0
	var city: City = null if area else gw.cities[int(op["city"])]
	var c: int = int(op["c"])
	if not area and (city.country_id == c or not army._hostile(c, city.country_id)):
		stop(home)
		return
	op["t"] = float(op["t"]) + dt
	var now: float = gw.game_time
	var cen: = Vector2.ZERO
	var hit: bool = false
	for u: Unit in mem:
		cen += u.pos
		if now - u.hit_t < 4.0:
			hit = true
	cen /= float(mem.size())
	op["cen"] = cen
	var foe: Array = army.fire.nearest_spotted(c, cen, CONTACT_R)
	if not foe.is_empty() or hit:
		op["contact"] = now
		if not foe.is_empty():
			op["foe"] = foe[0]
	var contact: bool = now - float(op["contact"]) < 10.0
	if contact and not foe.is_empty() and now >= float(op["req"]):
		op["req"] = now + 9.0
		army.fire.request(home, c, foe[0], foe[1], cen)
	if contact and now >= float(op["flare"]) and gw.night != null and gw.night.night_factor() > 0.35:
		op["flare"] = now + 16.0
		army.fire.illuminate((op["foe"] as Vector2) if (op["foe"] as Vector2).is_finite() else cen)
	var halts: Array = op["halts"]
	var last: int = halts.size() - 1
	var legs: Array = op["leg"]
	var ph: int = int(op["phase"])



	var manual: bool = not area and gw.ops != null and gw.ops.manual(home)
	if manual and now < float(op.get("cover_until", -1.0)):
		return
	if (ph == Phase.BOUND or ph == Phase.MARCH) and not bool(op["support"]):
		if _strength(mem) < RETREAT_AT * float(op.get("n_start", 1.0)):
			if manual:
				_cover_back(op, mem)
				return
			_fall_back(op, mem, city)
			return
	match ph:
		Phase.MARCH:
			if contact and not bool(op["support"]):
				op["phase"] = Phase.BOUND

				for u: Unit in mem:
					if u.team == 1:
						u.path = PackedVector2Array()
						u.pi = 0
						u.op_move = false
				op["mv"] = 0
				_cross(op, mem, int(legs[0]))
				_send(op, 0, int(legs[0]))
				return
			if bool(op["support"]) and (contact or _ahead_of_assault(op)):
				return
			var nxt: bool = _arrived(op, -1) >= 0.6 or float(op["t"]) > LEG_TIMEOUT * 1.5
			if not nxt and bool(op.get("fast", false)) and int(legs[0]) < last and _near_end(op, MARCH_ROLL) >= 0.6:
				nxt = true
			if nxt:
				if int(legs[0]) >= last:
					op["phase"] = Phase.FIREBASE if bool(op["support"]) else Phase.REGROUP
					op["t"] = 0.0
				else:
					_send(op, -1, int(legs[0]) + 1)
		Phase.BOUND:
			var mv: int = int(op["mv"])
			if _arrived(op, mv) >= 0.6 or float(op["t"]) > LEG_TIMEOUT:
				var front: int = maxi(int(legs[0]), int(legs[1]))
				if not contact:
					op["phase"] = Phase.MARCH
					_send(op, -1, front)
					return
				if mini(int(legs[0]), int(legs[1])) >= last:
					op["phase"] = Phase.REGROUP
					op["t"] = 0.0
					return

				var o: int = 1 - mv
				var dest: int = mini(last, front + 1)
				op["mv"] = o
				_cross(op, mem, dest)
				_send(op, o, dest)
		Phase.REGROUP:
			if int(legs[0]) < last or int(legs[1]) < last:
				for tm in 2:
					if int(legs[tm]) < last:
						_send(op, tm, last)
				op["t"] = 0.0
				return
			if _arrived(op, -1) >= 0.75 or float(op["t"]) > 25.0:
				if area:
					_hold(op, mem)
					return

				op["wait"] = float(op.get("wait", 0.0)) + dt
				var frac: float = city.garrison / maxf(1.0, city.garrison_max)
				var cp: = Vector2(city.center * GameWorld.CELL)
				var limit: float = 120.0 if army.fire.can_reach(c, cp) else 45.0
				if manual:
					limit = MANUAL_HOLD
				if float(op["wait"]) < 0.0 or (frac > STORM_AT and float(op["wait"]) < limit):
					op["holding"] = true
					if now >= float(op["req"]):
						op["req"] = now + 9.0
						army.fire.request(home, c, cp, null, cen)
					return
				op["holding"] = false
				op["wait"] = 0.0
				_assault(op, mem, city)
		Phase.ASSAULT:
			var s_now: float = _strength(mem)
			if s_now > 0.0 and s_now < RETREAT_AT * float(op.get("n0", s_now)):
				_retreat(op, mem, city)
				return
			if not manual and _storm_stalled(op, mem, city, now):
				return

			if float(op["t"]) > 6.0:
				op["t"] = 0.0
				var goal: Vector2 = op["goal"]
				for u: Unit in mem:
					if not u.indirect() and u.state == Unit.State.IDLE and u.pi >= u.path.size() and u.target == null:
						u.target_city = city.id
						u.op_hold = false
						u.path = gw.econ.nav_path(u.pos, goal)
						u.pi = 0
						u.state = Unit.State.MOVE
		Phase.FIREBASE:
			if int(legs[0]) < last and _arrived(op, -1) >= 0.6:
				_send(op, -1, last)
			elif not area and city.garrison < 1.0 and float(op["t"]) > 6.0:

				_assault(op, mem, city)
		Phase.HOLD:

			if float(op["t"]) > 6.0:
				op["t"] = 0.0
				var slots: Dictionary = op.get("slots", {})
				for u: Unit in mem:
					if u.target != null or u.pi < u.path.size() or not slots.has(u.id):
						continue
					if u.pos.distance_to(slots[u.id]) > 24.0:
						_go(u, slots[u.id])



func _ahead_of_assault(op: Dictionary) -> bool:
	if not op.has("cen") or int(op["city"]) < 0:
		return false
	var goal: Vector2 = op["goal"]
	var mine: float = (op["cen"] as Vector2).distance_to(goal)
	for h: Facility in ops:
		var o: Dictionary = ops[h]
		if o == op or bool(o["support"]) or int(o["city"]) != int(op["city"]) or not o.has("cen"):
			continue
		if int(o["phase"]) != Phase.ASSAULT and (o["cen"] as Vector2).distance_to(goal) + 60.0 > mine:
			return true
	return false



func _cross(op: Dictionary, mem: Array[Unit], dest: int) -> void :
	var halts: Array = op["halts"]
	if float(halts[dest]["cv"]) < 0.8 or gw.game_time < float(op["smoke"]):
		return
	var thrower: Unit = null
	for u: Unit in mem:
		if (u.kit & Unit.KIT_SMOKE) != 0:
			thrower = u
			break
	if thrower == null:
		return
	op["smoke"] = gw.game_time + 24.0
	var foe: Vector2 = op["foe"]
	var a: Vector2 = op["cen"]
	var b: Vector2 = halts[dest]["p"]
	var mid: Vector2 = a.lerp(b, 0.55)
	var toward: Vector2 = (foe - mid).normalized() if foe.is_finite() else (b - a).normalized()
	army.throw_smoke(mid + toward * 18.0)
	army.throw_smoke(mid + toward * 18.0 + Vector2(toward.y, - toward.x) * 22.0)




func _retreat(op: Dictionary, mem: Array[Unit], city: City) -> void :
	var home: Facility = op["home"]
	op["retreats"] = int(op.get("retreats", 0)) + 1
	var me: Country = gw.country_by_id(int(op["c"]))
	var manual: bool = gw.ops != null and gw.ops.manual(home)
	if int(op["retreats"]) > 2 and not manual:
		if me != null and me.is_player:
			gw.say(me, Loc.mk("Армия №%d: штурм %s сорван, войска закрепляются", [home.army_no, Loc.name(city.name)]))
		stop(home)
		return
	var halts: Array = op["halts"]
	var hp: Vector2 = halts[halts.size() - 1]["p"]
	var k: int = 0
	for u: Unit in mem:
		if u.indirect():
			continue
		var dest: Vector2 = army.safe_point(hp, Vector2(float(k % 3 - 1) * 9.0, float(k / 3) * 8.0 - 6.0))
		u.path = gw.econ.nav_path(u.pos, dest)
		if u.path.is_empty():
			u.path = PackedVector2Array([dest])
		u.path[u.path.size() - 1] = dest
		u.pi = 0
		u.state = Unit.State.MOVE
		u.op_hold = true
		u.op_move = true
		u.target = null
		u.cover = 1.0
		k += 1
	op["phase"] = Phase.REGROUP
	op["t"] = 0.0
	op["wait"] = - COVER_PAUSE if manual else -20.0
	op["back_t"] = gw.game_time
	if me != null and me.is_player:
		gw.say(me, Loc.mk("Армия №%d: отход в укрытие — ждём огня по %s", [home.army_no, Loc.name(city.name)]))


const COVER_PAUSE: float = 12.0
const MANUAL_HOLD: float = 15.0




func _cover_back(op: Dictionary, mem: Array[Unit]) -> void :
	var halts: Array = op["halts"]
	var legs: Array = op["leg"]
	var back: int = maxi(0, mini(int(legs[0]), int(legs[1])) - 1)
	var hp: Vector2 = halts[back]["p"]
	var k: int = 0
	for u: Unit in mem:
		var dest: Vector2 = army.safe_point(hp, Vector2(float(k % 3 - 1) * 9.0, float(k / 3) * 8.0 - 6.0))
		u.path = gw.econ.nav_path(u.pos, dest)
		if u.path.is_empty():
			u.path = PackedVector2Array([dest])
		u.path[u.path.size() - 1] = dest
		u.pi = 0
		u.state = Unit.State.MOVE
		u.op_hold = true
		u.op_move = true
		u.cover = 1.0
		k += 1
	op["n_start"] = _strength(mem)
	op["cover_until"] = gw.game_time + COVER_PAUSE
	op["t"] = 0.0
	op["mv"] = 0
	op["phase"] = Phase.BOUND
	op["leg"] = [back, back]
	var me: Country = gw.country_by_id(int(op["c"]))
	if me != null and me.is_player and gw.game_time - float(op.get("cover_said", -999.0)) > 30.0:
		op["cover_said"] = gw.game_time
		gw.say(me, Loc.mk("Армия №%d: под сильным огнём — в укрытие, затем вперёд", [op["home"].army_no]))



func _strength(mem: Array[Unit]) -> float:
	var s: float = 0.0
	for u: Unit in mem:
		if not u.indirect() and u.alive():
			s += u.hp
	return s



func _fall_back(op: Dictionary, mem: Array[Unit], city: City) -> void :
	var home: Facility = op["home"]
	var halts: Array = op["halts"]
	var legs: Array = op["leg"]
	var back: int = maxi(0, mini(int(legs[0]), int(legs[1])) - 1)
	var hp: Vector2 = halts[back]["p"]
	var k: int = 0
	for u: Unit in mem:
		var dest: Vector2 = army.safe_point(hp, Vector2(float(k % 3 - 1) * 9.0, float(k / 3) * 8.0 - 6.0))
		u.path = gw.econ.nav_path(u.pos, dest)
		if u.path.is_empty():
			u.path = PackedVector2Array([dest])
		u.path[u.path.size() - 1] = dest
		u.pi = 0
		u.state = Unit.State.MOVE
		u.target = null
		k += 1
	var me: Country = gw.country_by_id(int(op["c"]))
	if me != null and me.is_player:
		gw.say(me, Loc.mk("Армия №%d: большие потери — отход в укрытие, наступление %s остановлено", [home.army_no, (Loc.t("на ") + Loc.name(city.name)) if city != null else ""]))
	stop(home)


func _assault(op: Dictionary, mem: Array[Unit], city: City) -> void :
	op["phase"] = Phase.ASSAULT
	var halts: Array = op["halts"]
	var path: PackedVector2Array = op["path"]
	var i0: int = int(halts[halts.size() - 1]["i"])
	var goal: Vector2 = op["goal"]
	var smoke: bool = false
	for u: Unit in mem:
		if (u.kit & Unit.KIT_SMOKE) != 0:
			smoke = true
	if smoke:
		var cen: Vector2 = op["cen"]
		var dir: Vector2 = (goal - cen).normalized()
		army.throw_smoke(cen + dir * 40.0)
		army.throw_smoke(cen + dir * 40.0 + Vector2(dir.y, - dir.x) * 24.0)
		army.throw_smoke(cen + dir * 40.0 - Vector2(dir.y, - dir.x) * 24.0)
	var k: int = 0
	op["n0"] = _strength(mem)
	for u: Unit in mem:
		if u.indirect():
			continue
		var p: = PackedVector2Array()
		for i in range(i0 + 1, path.size()):
			p.append(army.safe_point(path[i], Vector2(float(k % 4) * 6.0 - 9.0, float(k / 4) * 6.0)))
		if p.is_empty():
			p.append(goal)
		u.path = p
		u.pi = 0
		u.state = Unit.State.MOVE
		u.op_hold = false
		u.op_move = false
		k += 1
	var me: Country = gw.country_by_id(int(op["c"]))
	if me != null and me.is_player:
		gw.say(me, Loc.mk("Армия №%d: штурм — %s", [(op["home"] as Facility).army_no, Loc.name(city.name)]))
	if me != null and me.is_player:
		Sfx.play("ui_alert", op["cen"], -6.0)



func status(home: Facility) -> String:
	if not ops.has(home):
		return ""
	var op: Dictionary = ops[home]
	if int(op["city"]) < 0:
		return _area_status(op)
	var city: City = gw.cities[int(op["city"])]
	var contact: bool = gw.game_time - float(op["contact"]) < 10.0
	var smoke: String = Loc.t(" · ДЫМ") if gw.game_time < float(op["smoke"]) - 10.0 else ""
	match int(op["phase"]):
		Phase.MARCH:
			if bool(op["support"]):
				if army.fire.fired_recently(home):
					return Loc.t("ОГНЕВАЯ ПОДДЕРЖКА")
				return Loc.t("ВЫДВИГАЕТСЯ НА ОП") if _arrived(op, -1) < 0.6 else Loc.t("ОГНЕВАЯ ПОЗИЦИЯ")
			return Loc.t("МАРШ НА %s") % city.name.to_upper()
		Phase.BOUND:
			var mv: int = int(op["mv"])
			var moving: bool = _arrived(op, mv) < 0.7
			return (Loc.t("НАСТУПАЕТ: ПЕРЕБЕЖКА") if moving else Loc.t("НАСТУПАЕТ: В УКРЫТИИ")) + (Loc.t(" ПОД ОГНЁМ") if contact else "") + smoke
		Phase.REGROUP:
			if gw.game_time - float(op.get("back_t", -99.0)) < 15.0:
				return Loc.t("ОТХОД В УКРЫТИЕ")
			if bool(op.get("holding", false)):
				return Loc.t("НА РУБЕЖЕ: ЖДЁТ ОГНЯ ПО ГОРОДУ")
			return Loc.t("СБОР ПЕРЕД ШТУРМОМ")
		Phase.ASSAULT:
			if city.garrison <= 0.0 and not contact:
				return Loc.t("ЗАНИМАЕТ %s") % city.name.to_upper()
			return Loc.t("ШТУРМ: %s") % city.name.to_upper()
		Phase.FIREBASE:
			if army.fire.fired_recently(home):
				return Loc.t("ОГНЕВАЯ ПОДДЕРЖКА")
			return Loc.t("ОГНЕВАЯ ПОЗИЦИЯ") if _arrived(op, -1) >= 0.6 else Loc.t("ВЫДВИГАЕТСЯ НА ОП")
	return ""



func front(home: Facility) -> Array:
	if not ops.has(home) or not (ops[home] as Dictionary).has("cen"):
		return []
	return [ops[home]["cen"], ops[home]["goal"]]





var chain: PackedVector2Array = PackedVector2Array()


var sea_pref: bool = false





var route_free: bool = false


var _fp: GDScript = null




func _legal(home: Facility, a: Vector2, b: Vector2, path: PackedVector2Array) -> PackedVector2Array:
	if chain.size() > 0 or path.size() < 2 or not gw.econ.nav_last_ok or gw.diplo == null:
		return path
	if _fp == null:
		_fp = load("res://game/front_plan.gd")
	if not bool(_fp.call("closed_path", gw, home.country_id, path)):
		return path
	var lr: Dictionary = _fp.call("legal_route", gw, home.country_id, a, b)
	if bool(lr.get("busy", false)):
		gw.econ.nav_last_pending = true
		return PackedVector2Array()
	if not bool(lr.get("ok", false)):
		return PackedVector2Array()
	var ch: PackedVector2Array = lr["chain"]
	if ch.is_empty():
		return path
	chain = ch
	var p2: PackedVector2Array = route(a, b)
	chain = PackedVector2Array()
	return p2




func route(a: Vector2, b: Vector2, via: Vector2 = Vector2.INF, budget: bool = false) -> PackedVector2Array:
	budget = budget and not route_free
	if chain.size() > 0:
		var out: = PackedVector2Array()
		var cur: Vector2 = a
		for w: Vector2 in chain:
			out.append_array(gw.econ.army_path(cur, w))
			if out.size() > 0:
				cur = out[out.size() - 1]
		out.append_array(gw.econ.army_path(cur, b))
		return out
	if not via.is_finite():
		return gw.econ.army_path(a, b, budget)
	var p1: PackedVector2Array = gw.econ.army_path(a, via, budget)
	if gw.econ.nav_last_pending:
		return p1
	if p1.is_empty() or not gw.econ.nav_last_ok:
		return gw.econ.army_path(a, b, budget)
	p1.append_array(gw.econ.army_path(p1[p1.size() - 1], b, budget))
	return p1






func _cen(members: Array[Unit]) -> Vector2:
	if gw.ops != null:
		return gw.ops._centre(members)
	var c: = Vector2.ZERO
	for u: Unit in members:
		c += u.pos
	return c / float(maxi(1, members.size()))





func start_area(home: Facility, members: Array[Unit], goal: Vector2, via: Vector2 = Vector2.INF, defend: bool = false) -> bool:
	if members.is_empty():
		return false
	var cen: Vector2 = _cen(members)
	var forced: bool = sea_pref and gw.ops != null and gw.ops.sea_force
	var path: PackedVector2Array = route(cen, goal, via, true) if not forced else PackedVector2Array()
	if gw.econ.nav_last_pending and not forced:
		return false
	if ( not gw.econ.nav_last_ok or sea_pref) and gw.naval != null:
		var nv: int = gw.naval.divert(home, members, null, goal, Naval.Mode.DEFEND if defend else Naval.Mode.AREA, sea_pref)
		if nv == 1:
			return true
		if nv == 2:
			cen = Naval.centre(members)
			path = route(cen, goal, via)
	if path.size() >= 2:
		path = _legal(home, cen, goal, path)
		if path.size() < 2:
			return false
	if path.size() < 2:
		if cen.distance_to(goal) > 60.0:
			return false
		path = PackedVector2Array([cen, goal])
	var style: String = String(army.build_of(home)["style"])
	var support: bool = style == "support" and not defend
	var stop_d: float = 4.0
	if support:
		var reach: float = INF
		for u: Unit in members:
			if u.indirect():
				reach = minf(reach, float(Army.SPEC[u.type]["range"]))
		stop_d = (reach if reach < INF else 600.0) * 0.5
	var halts: Array = _plan(path, goal, stop_d)
	var dir: Vector2 = (goal - (path[maxi(0, path.size() - 4)] if path.size() > 4 else cen))
	dir = dir.normalized() if dir.length() > 1.0 else (goal - cen).normalized()
	var op: Dictionary = {"home": home, "c": home.country_id, "city": -1, "goal": goal, "path": path, "halts": halts, 
		"leg": [-1, -1], "mv": -1, "phase": Phase.MARCH, "t": 0.0, "contact": -99.0, "smoke": 0.0, "req": 0.0, 
		"support": support, "style": style, "flare": 0.0, "foe": Vector2.INF, "area": true, "defend": defend, "dir": dir}
	stop(home)
	ops[home] = op
	op["n_start"] = _strength(members)
	var k: int = 0
	for u: Unit in members:
		u.op_on = true
		u.op_hold = true
		u.op_move = false
		u.team = k % 2
		u.target_city = -1
		u.target = null
		u.cover = 1.0
		k += 1
	_send(op, -1, _first_halt(op, cen))
	return true




func _hold(op: Dictionary, mem: Array[Unit]) -> void :
	op["phase"] = Phase.HOLD
	op["t"] = 0.0
	var goal: Vector2 = op["goal"]
	var dir: Vector2 = op.get("dir", Vector2.RIGHT)
	var side: = Vector2( - dir.y, dir.x)
	var n: int = 0
	for u: Unit in mem:
		if not u.indirect():
			n += 1
	var w: float = clampf(float(n) * 11.0, 30.0, 120.0)
	var slots: Dictionary = {}
	var k: int = 0
	var g: int = 0
	for u: Unit in mem:
		var dest: Vector2
		if u.indirect():
			dest = goal - dir * 60.0 + side * float(g % 3 - 1) * 12.0
			g += 1
		else:
			var f: float = (float(k) / float(n - 1) - 0.5) if n > 1 else 0.0
			dest = goal + side * f * w
			k += 1
		var bc: Array = _best_cover(dest)
		if float(bc[0]) < 1.0 and (bc[1] as Vector2).distance_to(dest) < 20.0:
			dest = bc[1]
		dest = gw.econ.land_point(dest)
		if gw.diplo != null and gw.ops != null and not gw.diplo.may_cross(u.country_id, gw.ops._owner_at(dest)):
			dest = gw.econ.land_point(goal)
		slots[u.id] = dest
		_go(u, dest)
		u.op_hold = true
		u.op_move = false
	op["slots"] = slots


func _go(u: Unit, dest: Vector2) -> void :
	u.path = gw.econ.army_path(u.pos, dest) if u.pos.distance_to(dest) > 40.0 else PackedVector2Array([dest])
	if u.path.is_empty():
		u.path = PackedVector2Array([dest])
	u.path[u.path.size() - 1] = dest
	u.pi = 0
	u.state = Unit.State.MOVE
	u.cover = 1.0


func _area_status(op: Dictionary) -> String:
	var contact: bool = gw.game_time - float(op["contact"]) < 10.0
	var d: bool = bool(op.get("defend", false))
	match int(op["phase"]):
		Phase.MARCH:
			return Loc.t("ВЫДВИЖЕНИЕ НА РУБЕЖ") if d else Loc.t("ВЫДВИЖЕНИЕ")
		Phase.BOUND:
			return Loc.t("ПЕРЕБЕЖКА ПОД ОГНЁМ") if contact else Loc.t("ПЕРЕБЕЖКА")
		Phase.REGROUP:
			return Loc.t("ВЫХОД НА РУБЕЖ")
		Phase.HOLD:
			return Loc.t("РУБЕЖ: БОЙ") if contact else (Loc.t("ОБОРОНА РУБЕЖА") if d else Loc.t("ЗАКРЕПИЛИСЬ"))
		Phase.FIREBASE:
			return Loc.t("ОГНЕВАЯ ПОДДЕРЖКА") if army.fire.fired_recently(op["home"]) else Loc.t("ОГНЕВАЯ ПОЗИЦИЯ")
	return ""
