extends RefCounted














const BOARD_R: float = 640.0
const ALIGHT_R: float = 900.0
const MIN_RAIL: float = 360.0
const GAIN: float = 0.8
const BOARD_T: float = 4.0
const UNLOAD_T: float = 3.0
const WALK_K: float = 1.3
const WAIT_MAX: float = 10.0
const EMBARK_R: float = 56.0
const FOOT_CAR: int = 4
const MAX_CARS: int = 12
const CHK_DT: float = 2.0
const HIT_MID_K: float = 0.5
const HIT_FAR_K: float = 0.15
const CAR_TROOP: String = "rail_wagon_troop"
const CAR_FLAT: String = "rail_wagon_flat"

enum Stage{MARCH, BOARD, RIDE}

var rail
var gw: GameWorld
var rides: Array = []
var stats: Dictionary = {}
var foot_until: Dictionary = {}
const FOOT_T: float = 90.0
var _id: int = 1


func _init(r) -> void :
	rail = r
	gw = r.gw


func _count(k: String, n: int = 1) -> void :
	stats[k] = int(stats.get(k, 0)) + n




func of(home: Facility) -> Dictionary:
	if home == null:
		return {}
	for r: Dictionary in rides:
		if r["home"] == home:
			return r
	return {}



func busy(home: Facility) -> bool:
	return not of(home).is_empty()



func riding(home: Facility) -> bool:
	var r: Dictionary = of(home)
	return not r.is_empty() and int(r["stage"]) != Stage.MARCH


func aboard_of(home: Facility) -> Array:
	var out: Array = []
	var r: Dictionary = of(home)
	if r.is_empty() or int(r["stage"]) == Stage.MARCH:
		return out
	for u: Unit in r["units"]:
		if u.alive():
			out.append(u)
	return out


func aboard_n(country_id: int) -> int:
	var n: int = 0
	for r: Dictionary in rides:
		if int(r["c"]) == country_id and int(r["stage"]) != Stage.MARCH:
			for u: Unit in r["units"]:
				if u.alive():
					n += 1
	return n



func add_counts(counts: Dictionary) -> void :
	for r: Dictionary in rides:
		if int(r["stage"]) == Stage.MARCH:
			continue
		var h: Facility = r["home"]
		for u: Unit in r["units"]:
			if u.alive() and u.type != Unit.Type.FPV:
				counts[h] = int(counts.get(h, 0)) + 1


func _st_name(sid: int) -> String:
	return rail.st_name(sid)




func status_text(home: Facility) -> Variant:
	var r: Dictionary = of(home)
	if r.is_empty():
		return ""
	if int(r["stage"]) == Stage.MARCH:
		return Loc.mk("к вокзалу, дальше поездом (~%d мин)", [maxi(1, ceili(float(r.get("eta", 60.0)) / 60.0))])
	var tr: Dictionary = _train(r)
	var eta: int = 0
	if not tr.is_empty():
		eta = ceili((float(tr["L"]) - float(tr["s"])) / Rail.TRAIN_SPEED + maxf(0.0, float(tr.get("hold", 0.0))))
	return Loc.mk("едет поездом, прибытие ~%d с", [maxi(1, eta)])



func info(home: Facility) -> Dictionary:
	var r: Dictionary = of(home)
	if r.is_empty():
		return {}
	var n: int = aboard_of(home).size() if int(r["stage"]) != Stage.MARCH else _alive_march(r).size()
	var tr: Dictionary = _train(r)
	var eta: float = 0.0
	if not tr.is_empty():
		eta = (float(tr["L"]) - float(tr["s"])) / Rail.TRAIN_SPEED + maxf(0.0, float(tr.get("hold", 0.0)))
	var line: String = (Loc.t("к вокзалу %s") % _st_name(int(r["s1"]))) if int(r["stage"]) == Stage.MARCH else (Loc.t("до %s · ~%d с") % [_st_name(int(r["s2"])), maxi(1, ceili(eta))])
	return {"stage": int(r["stage"]), "text": Loc.msg(status_text(home)), "eta_s": ceili(eta), "troops": n, "from": _st_name(int(r["s1"])), 
		"to": _st_name(int(r["s2"])), "pos": front(home), "line": line}



func alight_pos(home: Facility) -> Vector2:
	var r: Dictionary = of(home)
	return _plat(int(r["s2"])) if not r.is_empty() else Vector2.INF



func front(home: Facility) -> Vector2:
	var r: Dictionary = of(home)
	if r.is_empty():
		return Vector2.INF
	if int(r["stage"]) == Stage.MARCH:
		var mem: Array = _alive_march(r)
		return Naval.centre(mem) if not mem.is_empty() else _plat(int(r["s1"]))
	var tr: Dictionary = _train(r)
	return rail.pos_at(tr, float(tr["s"])) if not tr.is_empty() else (r.get("pos", Vector2.INF) as Vector2)


func _plat(sid: int) -> Vector2:
	return rail.stations[sid]["p"] if sid >= 0 and sid < rail.stations.size() else Vector2.INF


func _train(r: Dictionary) -> Dictionary:
	var id: int = int(r.get("train", -1))
	if id < 0:
		return {}
	for tr: Dictionary in rail.trains:
		if int(tr["id"]) == id:
			return tr
	return {}





func _allowed(c: int, o: int) -> bool:
	if o == c:
		return true
	var dp: Diplomacy = gw.diplo
	if dp == null or dp.at_war(c, o):
		return false
	return dp.allied(c, o) or dp.has_passage(c, o) or (dp.ally != null and dp.ally.same(c, o))


func _edge_ok(c: int, e: Dictionary) -> bool:
	if bool(e["dead"]) or float(e.get("bt", 0.0)) > 0.0 or rail._edge_blocked(e):
		return false
	return _allowed(c, rail._station_country(int(e["a"]))) and _allowed(c, rail._station_country(int(e["b"])))


func _station_up(sid: int) -> bool:
	return rail.station_up(sid)



func _has_ok_edge(c: int, sid: int) -> bool:
	for eid: int in rail.adj.get(sid, []):
		if _edge_ok(c, rail.edges[eid]):
			return true
	return false



func _dists(c: int, sa: int) -> Array:
	var dist: Dictionary = {sa: 0.0}
	var prev: Dictionary = {}
	var done: Dictionary = {}
	var open: Array = [sa]
	while not open.is_empty():
		var bi: int = 0
		for i in open.size():
			if float(dist[open[i]]) < float(dist[open[bi]]) or (float(dist[open[i]]) == float(dist[open[bi]]) and int(open[i]) < int(open[bi])):
				bi = i
		var u: int = open[bi]
		open.remove_at(bi)
		done[u] = true
		for eid: int in rail.adj.get(u, []):
			var e: Dictionary = rail.edges[eid]
			if not _edge_ok(c, e):
				continue
			var v: int = int(e["b"]) if int(e["a"]) == u else int(e["a"])
			if done.has(v):
				continue
			var nd: float = float(dist[u]) + float(e["len"])
			if not dist.has(v) or nd < float(dist[v]):
				dist[v] = nd
				prev[v] = [u, eid]
				if not open.has(v):
					open.append(v)
	return [dist, prev]


static func _path_of(prev: Dictionary, sa: int, sb: int) -> Array:
	var out: Array = [[sb, -1]]
	var cur: int = sb
	var guard: int = 0
	while cur != sa and guard < 4096:
		var pv: Array = prev[cur]
		out.push_front([int(pv[0]), int(pv[1])])
		cur = int(pv[0])
		guard += 1
	return out






func plan(f: Facility, cen: Vector2, target: Vector2, kind: int, spd: float, march_len: float) -> Dictionary:
	if f == null or kind == Operations.Kind.RETREAT or rail.stations.is_empty():
		return {}
	if float(foot_until.get(f.id, -1.0)) > gw.game_time:
		return {}
	var c: int = f.country_id
	spd = maxf(1.0, spd)
	var march_eta: float = march_len / spd
	var near1: Array = []
	var near2: Array = []
	for st: Dictionary in rail.stations:
		var sid: int = int(st["id"])
		var cty: int = rail._station_country(sid)
		var p: Vector2 = st["p"]
		if cty == c and _station_up(sid) and p.distance_to(cen) <= BOARD_R and _has_ok_edge(c, sid):
			near1.append([p.distance_to(cen), sid])
		if _allowed(c, cty) and p.distance_to(target) <= ALIGHT_R:
			near2.append([p.distance_to(target), sid])
	if near1.is_empty() or near2.is_empty():
		return {}
	near1.sort()
	near2.sort()
	var best: Dictionary = {}
	for k in mini(3, near1.size()):
		var s1: int = int(near1[k][1])
		if (rail.adj.get(s1, []) as Array).is_empty():
			continue
		var dp: Array = _dists(c, s1)
		var dist: Dictionary = dp[0]
		for e2: Array in near2:
			var s2: int = int(e2[1])
			if s2 == s1 or not dist.has(s2):
				continue
			var rl: float = float(dist[s2])
			var p1: Vector2 = _plat(s1)
			var p2: Vector2 = _plat(s2)
			var eta: float = p1.distance_to(cen) * WALK_K / spd + BOARD_T + rl / Rail.TRAIN_SPEED + UNLOAD_T + p2.distance_to(target) * WALK_K / spd
			if best.is_empty() or eta < float(best["eta"]) - 0.001:
				best = {"s1": s1, "s2": s2, "p1": p1, "p2": p2, "rail_len": rl, "eta": eta, "march_eta": march_eta, "prev": dp[1]}
	if best.is_empty() or float(best["rail_len"]) < MIN_RAIL or float(best["eta"]) > march_eta * GAIN:
		return {}
	if not _foot_ok(cen, best["p1"]) or not _foot_ok(best["p2"], target):
		return {}
	var route: Array = _path_of(best["prev"], int(best["s1"]), int(best["s2"]))
	best.erase("prev")
	var pts: = PackedVector2Array()
	for k2 in route.size() - 1:
		var st0: int = int(route[k2][0])
		var e: Dictionary = rail.edges[int(route[k2][1])]
		var s: PackedVector2Array = e["s"]
		var fwd: bool = int(e["a"]) == st0
		var n: int = s.size()
		for i in range(0, n, 6):
			pts.append(s[i] if fwd else s[n - 1 - i])
		pts.append(s[n - 1] if fwd else s[0])
	best["pts"] = pts
	var path: = PackedVector2Array([cen, best["p1"]])
	path.append_array(pts)
	path.append(best["p2"])
	path.append(target)
	best["path"] = path
	if rail.no_rail.has(f.id):
		best["denied"] = true
		return best
	best["ok"] = true
	return best





func start(f: Facility, mem: Array[Unit], city: City, goal: Vector2, kind: int, pl: Dictionary) -> bool:
	if f == null or mem.is_empty() or not bool(pl.get("ok", false)):
		return false
	var s1: int = int(pl["s1"])
	var s2: int = int(pl["s2"])
	if s1 < 0 or s1 >= rail.stations.size() or s2 < 0 or s2 >= rail.stations.size():
		return false
	var cur: Dictionary = of(f)
	if not cur.is_empty():
		if int(cur["stage"]) != Stage.MARCH:
			return false
		rides.erase(cur)
	gw.army.tac.stop(f)
	var mode: int = Naval.Mode.AREA
	if kind == Operations.Kind.DEFEND:
		mode = Naval.Mode.DEFEND
	elif city != null:
		mode = Naval.Mode.CITY
	var spd: float = INF
	for u: Unit in mem:
		spd = minf(spd, float(Army.SPEC[u.type]["speed"]))
	var p1: Vector2 = _plat(s1)
	var walk: float = Naval.centre(mem).distance_to(p1) * WALK_K / maxf(4.0, spd if spd < INF else 8.0)
	var r: Dictionary = {"id": _id, "c": f.country_id, "home": f, "kind": kind, "mode": mode, "city": city.id if city != null else -1, "goal": goal, 
		"stage": Stage.MARCH, "t": 0.0, "t0": gw.game_time, "s1": s1, "s2": s2, "members": [], "units": [], "car": [], "train": -1, 
		"pos": p1, "march_max": walk * 1.6 + 30.0, "chk_t": 0.0, "lost": 0, "eta": float(pl.get("eta", 0.0))}
	(r["members"] as Array).assign(mem)
	_id += 1
	rides.append(r)
	_count("rides")
	var k: int = 0
	for u: Unit in mem:
		u.op_on = true
		u.op_hold = true
		u.op_move = false
		u.target_city = -1
		u.target = null
		_walk(u, _slot(p1, k))
		k += 1
	return true




func bot_ride(f: Facility, mem: Array[Unit], city: City) -> bool:
	if f == null or mem.is_empty() or city == null or busy(f):
		return false
	var goal: = Vector2(city.center * GameWorld.CELL)
	var cen: Vector2 = Naval.centre(mem)
	var spd: float = INF
	for u: Unit in mem:
		spd = minf(spd, float(Army.SPEC[u.type]["speed"]))
	if spd == INF:
		return false
	var pl: Dictionary = plan(f, cen, goal, Operations.Kind.ATTACK, spd, cen.distance_to(goal) * WALK_K)
	if not bool(pl.get("ok", false)):
		return false
	if start(f, mem, city, goal, Operations.Kind.ATTACK, pl):
		_count("bot_rides")
		return true
	return false




func _foot_ok(a: Vector2, b: Vector2) -> bool:
	if a.distance_to(b) <= 30.0:
		return true
	var p: PackedVector2Array = gw.econ.nav_path(a, b)
	return not p.is_empty() and gw.econ.nav_last_ok



func _slot(p: Vector2, k: int) -> Vector2:
	return gw.army.safe_point(p, Vector2(float(k % 6) * 6.0 - 15.0, 7.0 + float(k / 6) * 6.0))


func _walk(u: Unit, dest: Vector2) -> void :
	u.path = gw.econ.nav_path(u.pos, dest) if u.pos.distance_to(dest) > 30.0 else PackedVector2Array([dest])
	if u.path.is_empty():
		u.path = PackedVector2Array([dest])
	u.pi = 0
	u.state = Unit.State.MOVE


func _alive_march(r: Dictionary) -> Array:
	var out: Array = []
	var h: Facility = r["home"]
	for u: Unit in r["members"]:
		if u.alive() and u.home == h and u.op_on:
			out.append(u)
	return out



func on_cancel(home: Facility) -> void :
	var r: Dictionary = of(home)
	if r.is_empty():
		return
	if int(r["stage"]) != Stage.MARCH:


		if not bool(r.get("stop", false)):
			r["stop"] = true
			if home.country_id == int(r["c"]):
				_say(r, Loc.msg(Loc.mk("Армия №%d в поезде: сойдёт на вокзале %s и останется там", [home.army_no, _st_name(int(r["s2"]))])))
		return
	for u: Unit in _alive_march(r):
		u.op_on = false
		u.op_hold = false
		if u.pi >= u.path.size():
			u.state = Unit.State.IDLE
	rides.erase(r)




func on_forbid(home: Facility) -> void :
	var r: Dictionary = of(home)
	if r.is_empty() or int(r["stage"]) != Stage.MARCH:
		return
	var mem: Array = _alive_march(r)
	if mem.is_empty():
		rides.erase(r)
		return
	_walk_on(r, mem, Loc.t("ЖД запрещена"))



func on_owner(home: Facility, new_id: int) -> void :
	var r: Dictionary = of(home)
	if r.is_empty():
		return
	r["c"] = new_id
	var tr: Dictionary = _train(r)
	if not tr.is_empty():
		tr["country"] = new_id




func update(dt: float) -> void :
	for k in range(rides.size() - 1, -1, -1):
		if k >= rides.size():
			continue
		var r: Dictionary = rides[k]
		r["t"] = float(r["t"]) + dt
		if int(r["stage"]) == Stage.MARCH:
			_tick_march(r, dt)
		else:
			_tick_ride(r, dt)


func _route_now(r: Dictionary) -> Array:
	var s1: int = int(r["s1"])
	var s2: int = int(r["s2"])
	if not _station_up(s1):
		return []
	var dp: Array = _dists(int(r["c"]), s1)
	if not (dp[0] as Dictionary).has(s2):
		return []
	return _path_of(dp[1], s1, s2)


func _tick_march(r: Dictionary, dt: float) -> void :
	var mem: Array = _alive_march(r)
	if mem.is_empty():
		rides.erase(r)
		return
	r["chk_t"] = float(r["chk_t"]) + dt
	if float(r["chk_t"]) >= CHK_DT:
		r["chk_t"] = 0.0
		if _route_now(r).is_empty():
			_walk_on(r, mem, Loc.t("вокзал разрушен") if not _station_up(int(r["s1"])) else Loc.t("путь перебит"))
			return
	var p1: Vector2 = _plat(int(r["s1"]))
	var near: int = 0
	var k: int = 0
	for u: Unit in mem:
		if u.pos.distance_to(p1) <= EMBARK_R:
			near += 1
		elif u.pi >= u.path.size() and u.target == null:
			_walk(u, _slot(p1, k))
		k += 1
	var t: float = float(r["t"])
	if near >= ceili(float(mem.size()) * 0.8) or (t > float(r["march_max"]) and near > 0):
		_board(r, mem)
	elif t > float(r["march_max"]) * 1.6:
		_walk_on(r, mem, Loc.t("не дошли до вокзала"))



func _walk_on(r: Dictionary, mem: Array, why: String) -> void :
	rides.erase(r)
	foot_until[(r["home"] as Facility).id] = gw.game_time + FOOT_T
	_count("walk_back")
	var landed: Array[Unit] = []
	landed.assign(mem)
	_say(r, Loc.msg(Loc.mk("Армия №%d: %s — идём пешком", [(r["home"] as Facility).army_no, why])))
	_resume(r, landed, Naval.centre(mem))


func _board(r: Dictionary, mem: Array) -> void :
	var p1: Vector2 = _plat(int(r["s1"]))
	var go: Array[Unit] = []
	for u: Unit in mem:
		if u.pos.distance_to(p1) <= EMBARK_R * 1.8 and u.post == null:
			go.append(u)
		else:
			u.op_on = false
			u.op_hold = false
	if go.is_empty():
		rides.erase(r)
		return
	var route: Array = _route_now(r)
	if route.size() < 2:
		_walk_on(r, mem, Loc.t("путь перебит"))
		return

	var foot: Array[Unit] = []
	var veh: Array[Unit] = []
	for u: Unit in go:
		if u.vehicle() or u.type == Unit.Type.IFV:
			veh.append(u)
		else:
			foot.append(u)
	var cars: = PackedStringArray(["rail_loco"])
	var units: Array = []
	var car: Array = []
	for i in foot.size():
		if i % FOOT_CAR == 0:
			cars.append(CAR_TROOP)
		units.append(foot[i])
		car.append(cars.size() - 1)
	for u2: Unit in veh:
		cars.append(CAR_FLAT)
		units.append(u2)
		car.append(cars.size() - 1)
	if cars.size() > MAX_CARS + 1:
		cars = cars.slice(0, MAX_CARS + 1)
		for i2 in car.size():
			car[i2] = mini(int(car[i2]), MAX_CARS)
	if not rail.can_spawn(true):
		_walk_on(r, mem, Loc.t("все поезда заняты"))
		return
	var tr: Dictionary = rail._spawn(route, cars, false)
	tr["ride"] = int(r["id"])
	tr["hold"] = BOARD_T
	tr["country"] = int(r["c"])
	for u3: Unit in units:
		gw.army.units.erase(u3)
		u3.path = PackedVector2Array()
		u3.pi = 0
		u3.target = null
		u3.state = Unit.State.IDLE
		u3.pos = p1
	r["units"] = units
	r["car"] = car
	r["members"] = []
	r["train"] = int(tr["id"])
	r["stage"] = Stage.RIDE
	r["t"] = 0.0
	_count("boarded")
	_count("boarded_units", units.size())
	var eta: float = float(tr["L"]) / Rail.TRAIN_SPEED + BOARD_T
	_say(r, Loc.msg(Loc.mk("Армия №%d: посадка на поезд — %s → %s (~%d с)", [(r["home"] as Facility).army_no, _st_name(int(r["s1"])), _st_name(int(r["s2"])), ceili(eta)])))


func _tick_ride(r: Dictionary, dt: float = 0.0) -> void :
	var tr: Dictionary = _train(r)
	if tr.is_empty():
		_unload(r, r.get("pos", _plat(int(r["s2"]))), "", {})
		return
	r["chk_t"] = float(r.get("chk_t", 0.0)) + dt
	if float(r["chk_t"]) >= CHK_DT:
		r["chk_t"] = 0.0
		if not _ahead_ok(r, tr):



			_count("closed_unload")
			var s0: float = tr["s"]
			for k in range(rail.trains.size() - 1, -1, -1):
				if is_same(rail.trains[k], tr):
					rail.trains.remove_at(k)
			_unload(r, rail.pos_at(tr, s0), Loc.t("проезд закрыт — высадка"), tr, true)
			return
	var s: float = tr["s"]
	r["pos"] = rail.pos_at(tr, s)
	var units: Array = r["units"]
	var car: Array = r["car"]
	for i in units.size():
		var u: Unit = units[i]
		if u.alive():
			u.pos = rail.pos_at(tr, s - float(car[i]) * Rail.CAR_GAP)





func on_arrive(tr: Dictionary) -> void :
	var r: Dictionary = _ride_of(tr)
	if r.is_empty():
		return
	_count("arrived")
	_unload(r, _plat(int(r["s2"])), "", tr)



func on_lost(tr: Dictionary) -> void :
	var r: Dictionary = _ride_of(tr)
	if r.is_empty():
		return
	_unload(r, rail.pos_at(tr, float(tr["s"])), Loc.t("эшелон остановлен"), tr)



func on_stuck(tr: Dictionary) -> void :
	var r: Dictionary = _ride_of(tr)
	if r.is_empty():
		return
	_count("cut_unload")
	_unload(r, rail.pos_at(tr, float(tr["s"])), Loc.t("путь перебит, высадка у разрыва"), tr)




func on_hit(tr: Dictionary, p: Vector2, rp: float, by: int) -> void :
	var r: Dictionary = _ride_of(tr)
	if r.is_empty():
		return
	_count("hit")
	var s: float = tr["s"]
	var units: Array = r["units"]
	var car: Array = r["car"]
	var att: Country = gw.country_by_id(by)
	var dead: int = 0


	var hit_c: int = -1
	var hd: float = INF
	for ci in (tr["cars"] as PackedStringArray).size():
		var dc: float = rail.pos_at(tr, s - float(ci) * Rail.CAR_GAP).distance_to(p)
		if dc < hd:
			hd = dc
			hit_c = ci
	for i in units.size():
		var u: Unit = units[i]
		if not u.alive():
			continue
		var cp: Vector2 = rail.pos_at(tr, s - float(car[i]) * Rail.CAR_GAP)
		u.pos = cp
		var dmg: float = u.max_hp * HIT_FAR_K
		if int(car[i]) == hit_c:
			dmg = u.hp + 1.0
		elif absi(int(car[i]) - hit_c) == 1:
			dmg = u.max_hp * HIT_MID_K
		u.hp -= dmg
		if u.hp <= 0.0:
			u.hp = 0.0
			u.state = Unit.State.DEAD
			u.dead_t = gw.game_time
			dead += 1
			if att != null and by != u.country_id:
				att.destroyed += int(Army.SPEC[u.type]["cost"]) + (100 if u.type == Unit.Type.TANK else 0)
	r["lost"] = int(r["lost"]) + dead
	_count("killed", dead)
	if att != null and att.is_player and by != int(r["c"]):
		gw.say(att, Loc.mk("Удар по воинскому эшелону: −%d ед.", [dead]))
	_unload(r, rail.pos_at(tr, s), Loc.t("удар по эшелону, потери %d — высадка") % dead, tr, true)




func _ahead_ok(r: Dictionary, tr: Dictionary) -> bool:
	var c: int = int(r["c"])
	if not _allowed(c, rail._station_country(int(r["s2"]))):
		return false
	var s: float = tr["s"]
	for mk: Array in tr["marks"]:
		if float(mk[0]) + float(mk[3]) < s:
			continue
		var eid: int = int(mk[1])
		if eid < 0 or eid >= rail.edges.size():
			continue
		var e: Dictionary = rail.edges[eid]
		if not _allowed(c, rail._station_country(int(e["a"]))) or not _allowed(c, rail._station_country(int(e["b"]))):
			return false
	return true


func _ride_of(tr: Dictionary) -> Dictionary:
	var id: int = int(tr.get("ride", -1))
	for r: Dictionary in rides:
		if int(r["id"]) == id:
			return r
	return {}




func _unload(r: Dictionary, p: Vector2, why: String, tr: Dictionary, by_car: bool = false) -> void :
	rides.erase(r)
	var h: Facility = r["home"]
	if why != "":
		foot_until[h.id] = gw.game_time + FOOT_T
	var landed: Array[Unit] = []
	var units: Array = r["units"]
	var car: Array = r["car"]
	var s: float = float(tr.get("s", 0.0))
	var k: int = 0
	for i in units.size():
		var u: Unit = units[i]
		if not u.alive():
			continue
		var base: Vector2 = p
		if by_car and not tr.is_empty():
			base = rail.pos_at(tr, s - float(car[i]) * Rail.CAR_GAP)
		var off: = Vector2(float(k % 6) * 6.0 - 15.0, 7.0 + float(k / 6) * 6.0)
		if by_car:
			off = Vector2(float(k % 2) * 6.0 - 3.0, 6.0)
		u.pos = gw.econ.land_point(gw.army.safe_point(base, off), 8)
		u.path = PackedVector2Array()
		u.pi = 0
		u.state = Unit.State.IDLE
		u.op_on = false
		u.op_hold = false
		u.op_move = false
		u.cover = 1.0
		u.still_t = 0.0
		u.target = null
		gw.army.units.append(u)
		landed.append(u)
		k += 1
	_count("unloaded", landed.size())
	if why != "":
		_say(r, Loc.msg(Loc.mk("Армия №%d: %s", [h.army_no, why])))
	elif not landed.is_empty():
		_say(r, Loc.msg(Loc.mk("Армия №%d прибыла поездом: %d ед.", [h.army_no, landed.size()])))
	if landed.is_empty():
		return
	if gw._on_screen(p, 80.0):
		gw.fx.spawn("dust_s", p.round(), 5)
	if not bool(r.get("stop", false)):
		_resume(r, landed, p)
	var c: int = int(r["c"])
	var o: int = gw.ops._owner_at(p) if gw.ops != null else 0
	if o > 0 and o != c and gw.diplo != null and not gw.diplo.may_cross(c, o):
		gw.diplo.close_land(c, o)




func _resume(r: Dictionary, landed: Array[Unit], p: Vector2) -> void :
	var h: Facility = r["home"]
	var goal: Vector2 = r["goal"]
	var why: String = Loc.t("Казармы разрушены")
	if gw.ops != null:
		var was: bool = gw.ops._quiet
		gw.ops._quiet = true
		why = gw.ops.start(h, int(r["kind"]), goal)
		gw.ops._quiet = was
	if why == "" or why == gw.ops.PENDING:
		return

	var dir: Vector2 = (goal - p).normalized()
	gw.army.tac.start_area(h, landed, gw.econ.land_point(p + dir * 40.0), Vector2.INF, true)


func _say(r: Dictionary, text: String) -> void :
	var c: Country = gw.country_by_id(int(r["c"]))
	if c != null and c.is_player:
		gw.say(c, text)




func save_state() -> Dictionary:
	return {"rides": rides, "id": _id, "stats": stats.duplicate(), "foot": foot_until.duplicate()}


func load_state(d: Dictionary) -> void :
	rides = []
	for r: Variant in d.get("rides", []):
		if r is Dictionary and (r as Dictionary).get("home") is Facility:
			var rr: Dictionary = r
			for key: String in ["members", "units", "car"]:
				var a: Array = []
				for v: Variant in rr.get(key, []):
					if key == "car" or v is Unit:
						a.append(v)
				rr[key] = a
			rides.append(rr)
	_id = int(d.get("id", 1))
	stats = (d.get("stats", {}) as Dictionary).duplicate()
	foot_until = {}
	var fu: Dictionary = d.get("foot", {})
	for k: Variant in fu:
		foot_until[int(k)] = float(fu[k])



func hash_nums() -> PackedFloat64Array:
	var out: = PackedFloat64Array()
	out.append(float(rides.size()))
	for r: Dictionary in rides:
		out.append(float(int(r["id"]) * 10 + int(r["stage"])))
		out.append(float((r["units"] as Array).size()))
	return out
