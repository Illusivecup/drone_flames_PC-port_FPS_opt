extends "res://game/military/mil_build.gd"




func parked_count(country_id: int) -> int:
	var n: int = 0
	for f: Facility in facilities:
		if f.kind == Facility.Kind.DRONE_PORT and f.country_id == country_id and alive(f):
			n += parked_at(f)
	return n


func stock_count(country_id: int) -> int:
	var n: int = parked_count(country_id)
	for f: Facility in facilities:
		if f.country_id == country_id and f.kind == Facility.Kind.DRONE_FACTORY and f.producing and alive(f):
			n += 1
	return n


func next_drone_in(country_id: int) -> float:
	var best: float = -1.0
	for f: Facility in facilities:
		if f.country_id == country_id and f.kind == Facility.Kind.DRONE_FACTORY and f.producing and alive(f):
			var left: float = (JET_PROD_TIME if f.prod_jet else PROD_TIME) - f.prod_t
			if best < 0.0 or left < best:
				best = left
	return best


func parked_at(port: Facility, kind: int = -1) -> int:
	var n: int = 0
	for i in port.parked.size():
		var d: Drone = port.parked[i]
		if d != null and d.state == Drone.State.PARKED and _spot_ok(port, i) and (kind < 0 or d.kind == kind):
			n += 1
	return n


func runways_of(port: Facility) -> int:
	var n: int = 0
	for l: Facility in port_launchers(port):
		if l.kind == Facility.Kind.DP_RUNWAY:
			n += 1
	return n



func launch_point(port: Facility) -> Vector2:
	var ls: Array[Facility] = port_launchers(port)
	if ls.is_empty():
		return port.center_px()
	return _launcher_exit(ls[0])


func _launcher_exit(l: Facility) -> Vector2:
	if l.kind == Facility.Kind.DP_RAMP:
		return local_px(l.main_obj, _info("dp_ramp")["rail1"]) + Vector2(16, 0)
	var info: Dictionary = _info("dp_runway")
	return gw.obj_origin(l.main_obj) + Vector2(float(info["end_x"]), float(info["roll_y"]))



func best_port(country: Country, toward: Vector2) -> Facility:
	var best: Facility = null
	var best_score: int = -1
	var bd: float = INF
	for f: Facility in facilities:
		if f.kind != Facility.Kind.DRONE_PORT or f.country_id != country.id or not alive(f) or f.mb:
			continue
		var score: int = (2 if parked_at(f) > 0 else 0) + (1 if not port_launchers(f).is_empty() else 0)
		var dd: float = launch_point(f).distance_squared_to(toward)
		if score > best_score or (score == best_score and dd < bd):
			best = f
			best_score = score
			bd = dd
	return best


static func path_length(from: Vector2, pts: Array[Vector2]) -> float:
	var s: float = 0.0
	var p: Vector2 = from
	for q: Vector2 in pts:
		s += p.distance_to(q)
		p = q
	return s



func retarget(d: Drone, p: Vector2, add_waypoint: bool) -> String:
	if d.state == Drone.State.DIVE or d.state == Drone.State.DONE or d.state == Drone.State.PARKED:
		return Loc.t("Этому дрону цель уже не изменить")
	var pts: Array[Vector2] = []
	if add_waypoint:
		if d.route.size() > MAX_WAYPOINTS:
			return Loc.t("Не больше %d точек маршрута") % MAX_WAYPOINTS
		pts = d.route.duplicate()
		var best: int = pts.size() - 1
		var bd: float = INF
		var prev: Vector2 = d.pos
		for i in pts.size():
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, prev, pts[i])
			if q.distance_squared_to(p) < bd:
				bd = q.distance_squared_to(p)
				best = i
			prev = pts[i]
		pts.insert(best, p)
	else:
		pts = [p]
	if gw.diplo != null and gw.diplo.strike_block_at(d.country_id, pts[pts.size() - 1], false) != "":
		return Diplomacy.STRIKE_BLOCK_TXT
	var from: Vector2 = d.pos
	var left: float = d.range_px - d.flown
	if d.state < Drone.State.BOOST:
		from = launch_point(d.airfield)
		left = d.range_px
	if path_length(from, pts) > left:
		return Loc.t("Не хватит топлива: до %.1f км") % (left / 1000.0)
	d.route = pts
	d.target = pts[pts.size() - 1]
	d.smart_key = ""
	d.route_len = d.flown + path_length(from, pts)
	d.route_ver += 1
	return ""




func _update_drones(dt: float) -> void :
	for k in range(drones.size() - 1, -1, -1):
		var d: Drone = drones[k]
		match d.state:
			Drone.State.WAIT:
				_wait(d)
			Drone.State.TAXI:
				_taxi(d, dt)
			Drone.State.HOLD:
				_hold(d, dt)
			Drone.State.ROLL:
				_roll(d, dt)
			Drone.State.BOOST:
				_boost(d, dt)
			Drone.State.FLY, Drone.State.DIVE:
				_fly(d, dt)
		if d.state != Drone.State.DIVE:
			d.update_frame()
		if d.state == Drone.State.DONE:
			_own_drone_end(d)
			drones.remove_at(k)



func _wait(d: Drone) -> void :
	if not alive(d.airfield) or not has_power(d.airfield):
		return
	var best: Facility = null
	for l: Facility in port_launchers(d.airfield):
		if l.reserved == null and gw.game_time >= l.ready_at and (l.kind != Facility.Kind.DP_RUNWAY or l.runway_ok()) and (d.kind != 2 or l.kind == Facility.Kind.DP_RUNWAY):
			best = l
			break
	if best == null:
		return
	best.reserved = d
	d.launcher = best
	if d.spot >= 0 and d.airfield.parked[d.spot] == d:
		d.airfield.parked[d.spot] = null
	d.spot = -1
	d.taxi = [_launcher_entry(best)]
	d.state = Drone.State.TAXI


func _launcher_entry(l: Facility) -> Vector2:
	if l.kind == Facility.Kind.DP_RAMP:
		var info: Dictionary = _info("dp_ramp")
		return local_px(l.main_obj, info["rail0"]) + Vector2(0.0, float(info["h0"]))
	var ri: Dictionary = _info("dp_runway")
	return gw.obj_origin(l.main_obj) + Vector2(float(ri["start_x"]), float(ri["roll_y"]))


func _release(l: Facility, gap: float) -> void :
	if l != null:
		l.reserved = null
		l.ready_at = gw.game_time + gap



func _turn_to(d: Drone, want: float, max_step: float) -> float:
	var diff: float = wrapf(want - d.heading, - PI, PI)
	d.heading = wrapf(d.heading + clampf(diff, - max_step, max_step), - PI, PI)
	return wrapf(want - d.heading, - PI, PI)


func _taxi(d: Drone, dt: float) -> void :
	if d.launcher == null or not alive(d.launcher):
		_release(d.launcher, 0.0)
		d.launcher = null
		d.state = Drone.State.WAIT
		return
	if d.taxi.is_empty():
		d.state = Drone.State.HOLD
		d.wait_t = RAMP_HOLD if d.launcher.kind == Facility.Kind.DP_RAMP else HOLD_PAUSE
		if d.launcher.kind == Facility.Kind.DP_RAMP:
			var info: Dictionary = _info("dp_ramp")
			d.pos = local_px(d.launcher.main_obj, info["rail0"])
			d.h = float(info["h0"])
		return
	var tgt: Vector2 = d.taxi[0]
	var to: Vector2 = tgt - d.pos
	var dist: float = to.length()
	if dist < 0.05:
		d.pos = tgt
		d.taxi.remove_at(0)
		return
	if absf(_turn_to(d, to.angle(), GROUND_TURN * 2.0 * dt)) > 0.35:
		return
	d.pos += to / dist * minf(GROUND_SPEED * dt, dist)


func _hold(d: Drone, dt: float) -> void :
	if d.launcher == null or not alive(d.launcher):
		_crash(d, Drone.End.DESTROYED)
		return
	d.wait_t -= dt
	_turn_to(d, 0.0, GROUND_TURN * dt)
	if d.wait_t > 0.0 or absf(d.heading) > 0.02:
		return
	d.heading = 0.0
	d.speed = 0.0
	if d.launcher.kind == Facility.Kind.DP_RAMP:
		if not d.launcher.runway_ok():
			return
		d.state = Drone.State.BOOST
		d.boost_t = 0.0
		d.rail_s = 0.0
		gw.fx.spawn("ramp_blast", d.pos.round(), 6)
		gw.camera_shake_tiny(d.pos)
		_release(d.launcher, RAMP_RELOAD)
		Sfx.play("drone_launch", d.pos)
	else:
		if not d.launcher.runway_ok():
			return
		d.state = Drone.State.ROLL
		_dust(d)
		Sfx.play("drone_launch", d.pos, -6.0)
		_release(d.launcher, RUNWAY_GAP)


func _boost(d: Drone, dt: float) -> void :
	var info: Dictionary = _info("dp_ramp")
	d.boost_t += dt
	if d.boost_t < BOOST_TIME:
		d.speed += BOOST_ACC * dt
	var step: float = d.speed * dt
	var r0: Vector2 = local_px(d.launcher.main_obj, info["rail0"])
	var r1: Vector2 = local_px(d.launcher.main_obj, info["rail1"])
	var rail_len: float = r0.distance_to(r1)
	var before: Vector2 = d.pos
	if d.rail_s < rail_len:
		d.rail_s += step
		var k: float = clampf(d.rail_s / rail_len, 0.0, 1.0)
		d.pos = r0.lerp(r1, k)
		d.h = lerpf(float(info["h0"]), float(info["h1"]), k)
	else:
		d.pos.x += step
		d.h = minf(d.h + BOOST_CLIMB * dt, CRUISE_H)
	d.flown += step
	if d.boost_t < BOOST_TIME:
		d.trail_acc += d.pos.distance_to(before)
		while d.trail_acc >= TRAIL_STEP:
			d.trail_acc -= TRAIL_STEP
			gw.fx.spawn("trail_s", (d.pos - Vector2(5, 0)).round(), 5)
	elif d.rail_s >= rail_len:
		d.state = Drone.State.FLY


func _roll(d: Drone, dt: float) -> void :
	if not d.lifted and not d.launcher.runway_ok():
		_crash(d, Drone.End.DESTROYED)
		return
	d.speed = minf(d.speed + ROLL_ACC * dt * (2.5 if d.kind == 2 else 1.0), JET_CRUISE if d.kind == 2 else CRUISE)
	if not d.lifted and d.speed >= LIFT_SPEED:
		d.lifted = true
		_dust(d)
	if d.lifted:
		d.h = minf(d.h + CLIMB * dt, CRUISE_H)
	d.pos.x += d.speed * dt
	d.flown += d.speed * dt
	var ri: Dictionary = _info("dp_runway")
	if d.pos.x >= gw.obj_origin(d.launcher.main_obj).x + float(ri["end_x"]):
		d.state = Drone.State.FLY


func _fly(d: Drone, dt: float) -> void :
	var tgt: Vector2 = d.route[0]
	var to: Vector2 = tgt - d.pos
	var dist: float = to.length()
	var last: bool = d.route.size() == 1
	if d.kind == 1 and d.state == Drone.State.FLY and d.boost_t < 1.5:



		var was: float = d.boost_t
		d.boost_t += dt
		if was < 0.0:
			d.h = maxf(2.0, d.h - 5.0 * dt)
			d.speed = maxf(12.0, d.speed - 6.0 * dt)
			var st0: float = d.speed * dt
			d.pos += Vector2.from_angle(d.heading) * st0
			d.flown += st0
			if d.boost_t >= 0.0:
				d.speed += 8.0
				var tail: Vector2 = d.pos - Vector2.from_angle(d.heading) * 4.0
				gw.fx.spawn("muzzle_flash" if gw.fx.atlas_of.has("muzzle_flash") else "trail_s", tail.round(), 7)
				gw.fx.spawn("trail_puff" if gw.fx.atlas_of.has("trail_puff") else "trail_s", (tail - Vector2.from_angle(d.heading) * 3.0).round(), 5)
				Sfx.play("missile_cruise_launch", d.pos)
			return
	if d.state == Drone.State.FLY:
		d.h = move_toward(d.h, d.cruise_h, CLIMB * dt)
		if last and dist <= DIVE_DIST:
			d.state = Drone.State.DIVE
			d.dive_h0 = d.h
		else:
			if not last and (dist < 16.0 or (dist < 48.0 and absf(wrapf(to.angle() - d.heading, - PI, PI)) > PI * 0.5)):
				d.route.remove_at(0)
				return
			if d.speed > d.cruise_speed:
				d.speed = maxf(d.cruise_speed, d.speed - SLOW_DOWN * dt)
			else:
				d.speed = minf(d.speed + ROLL_ACC * dt * (3.0 if d.kind != 0 else 1.0), d.cruise_speed)
			if d.kind == 2:
				d.trail_acc += d.speed * dt
				if d.trail_acc >= 14.0:
					d.trail_acc = 0.0
					gw.fx.spawn("trail_s", (d.pos - Vector2.from_angle(d.heading) * 7.0).round(), 5)
			var rate: float = d.turn_rate * (2.0 if last and dist < 90.0 else 1.0)
			_turn_to(d, to.angle(), rate * dt)
			var step: float = d.speed * dt
			d.pos += Vector2.from_angle(d.heading) * step
			d.flown += step
			if d.flown >= d.range_px:
				_crash(d, Drone.End.CRASH)
			return
	if dist > 0.5:
		d.heading = to.angle()
	d.speed = minf(d.speed + DIVE_ACC * dt, maxf(DIVE_SPEED, d.speed))
	var st: float = minf(d.speed * dt, dist)
	if dist > 0.0:
		d.pos += to / dist * st
	d.flown += st
	var rem: float = dist - st
	d.h = minf(d.dive_h0, ceilf(maxf(d.dive_h0, 1.0) * rem / DIVE_DIST))
	if rem <= 0.5:
		d.pos = tgt
		d.h = 0.0
		d.state = Drone.State.DONE
		d.end_reason = Drone.End.HIT
		var prot: Dictionary = gw.protect.on_impact(tgt, [Protect.HIT_DRONE, Protect.HIT_CRUISE, Protect.HIT_JET][clampi(d.kind, 0, 2)], d.country_id) if gw.protect != null else {}
		if bool(prot.get("caught", false)):
			brain.note_loss(d, DroneBrain.BY_NET)
		else:
			brain.note_hit(d)
		if gw.battle_watch != null:
			gw.battle_watch.impact(tgt, ["Удар БПЛА", "Удар КР", "Удар реактивного БПЛА"][clampi(d.kind, 0, 2)], d.country_id)
		if d.kind == 2:
			gw.strike_big(Vector2i(floori(tgt.x / GameWorld.CELL), floori(tgt.y / GameWorld.CELL)), d.country_id)
		else:
			gw.strike(Vector2i(floori(tgt.x / GameWorld.CELL), floori(tgt.y / GameWorld.CELL)), d.country_id)
		if gw.vfx != null:
			gw.vfx.on_impact(tgt, 2 if d.kind == 2 else 1)


func _crash(d: Drone, why: int) -> void :
	if d.launcher != null and d.launcher.reserved == d:
		_release(d.launcher, RAMP_RELOAD)
	d.state = Drone.State.DONE
	d.end_reason = why
	if why == Drone.End.CRASH and d.has_meta("ew_lost"):
		brain.note_loss(d, DroneBrain.BY_EW)
	d.h = 0.0
	gw.fx.spawn("explosion_s", d.pos.round(), 6)
	gw.fx.debris_burst(d.pos.round(), 2, false)
	_scar(d.pos)
	Sfx.play("expl_small", d.pos, -3.0)
	if gw.country_by_id(d.country_id).is_player:
		gw.say(gw.country_by_id(d.country_id), Loc.t("БПЛА упал: кончилось топливо") if why == Drone.End.CRASH else Loc.t("БПЛА уничтожен на земле"))


func _scar(p: Vector2) -> void :
	var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	if gw.data.inside(c.x, c.y) and not Biome.is_water(gw.data.get_biome(c.x, c.y)):
		gw.ground.decals.append(["crater_s", p.round()])
		gw.ground.queue_redraw()


func _dust(d: Drone) -> void :
	gw.fx.spawn("dust_s", d.pos.round() - Vector2.from_angle(d.heading) * 6.0, 5)




func missiles_ready(country_id: int) -> int:
	var n: int = 0
	for f: Facility in facilities:
		if f.kind == Facility.Kind.TEL and f.country_id == country_id and alive(f) and not f.moving:
			n += maxi(0, f.missiles - f.queued.size())
	return n


func _tel_nozzle(f: Facility, sprite: String) -> Array[Vector2]:
	var info: Dictionary = _info(sprite)
	var nz: Vector2 = local_px(f.main_obj, info["nozzle"])
	var top: Vector2 = local_px(f.main_obj, info["top"])
	return [nz, top]



func tels_for(country: Country, target: Vector2) -> Array[Facility]:
	var out: Array[Facility] = []
	for f: Facility in facilities:
		if f.kind != Facility.Kind.TEL or f.country_id != country.id or not alive(f) or f.moving or f.mb:
			continue
		var dd: float = f.center_px().distance_to(target)
		if dd > MISSILE_RANGE or dd < MISSILE_MIN:
			continue
		out.append(f)
	out.sort_custom( func(a: Facility, b: Facility) -> bool: return a.center_px().distance_squared_to(target) < b.center_px().distance_squared_to(target))
	return out


func missile_plan(country: Country, target: Vector2, has_target: bool) -> Dictionary:
	var info: Dictionary = {"tel": null, "from": Vector2.ZERO, "dist": 0.0, "in_range": false, "available": missiles_ready(country.id), "flight": 0.0, "has_tel": has_kind(country.id, Facility.Kind.TEL), "too_close": false}
	var best: Facility = null
	var bd: float = INF
	for f: Facility in facilities:
		if f.kind == Facility.Kind.TEL and f.country_id == country.id and alive(f) and not f.moving:
			var dd: float = f.center_px().distance_to(target) if has_target else 0.0
			if dd < bd:
				bd = dd
				best = f
	info["tel"] = best
	if best == null:
		return info
	info["from"] = best.center_px()
	var geo: Array = launch_geometry(best)
	info["launch"] = geo[0]
	info["alt0"] = geo[1]
	if has_target:
		info["dist"] = bd
		info["in_range"] = bd <= MISSILE_RANGE and bd >= MISSILE_MIN
		info["too_close"] = bd < MISSILE_MIN
		info["flight"] = ERECT_TIME + Missile.IGNITE_TIME + flight_time_for(bd)
	return info



func launch_geometry(f: Facility) -> Array:
	var nt: Array[Vector2] = _tel_nozzle(f, "tel2" if f.missiles >= 2 else "tel1")
	var ground_y: float = float((f.cell.y + f.size.y) * GameWorld.CELL) - 2.0
	return [Vector2(nt[0].x, ground_y), ground_y - (nt[0].y + nt[1].y) * 0.5]


static func flight_time_for(dist: float) -> float:
	return 8.0 + dist / 110.0


static func apex_for(dist: float) -> float:
	return clampf(dist * 0.32, 80.0, 260.0)


static func hyper_time_for(dist: float) -> float:
	return HYPER_T0 + dist / HYPER_V



func launch_hyper(country_id: int, from: Vector2, target: Vector2, h: float) -> Missile:
	var m: = Missile.new()
	m.id = _next_missile_id
	_next_missile_id += 1
	m.country_id = country_id
	m.hyper = true
	m.state = Missile.State.FLIGHT
	m.t = Missile.IGNITE_TIME
	m.launch = from
	m.target = target
	m.dist = from.distance_to(target)
	m.flight_time = hyper_time_for(m.dist)
	m.apex = clampf(m.dist * 0.1, 25.0, 90.0)
	m.apex_km = 28.0
	m.alt0 = h
	m.prev_screen = m.screen_pos()
	m.last_screen = m.prev_screen
	missiles.append(m)
	gw.fx.spawn("tel_flash", (from - Vector2(0, h)).round(), 6)
	Sfx.play("hyper_launch", from)
	if gw.country_by_id(country_id).is_player:
		gw.say(gw.country_by_id(country_id), Loc.mk("Гиперзвуковая ракета: полёт %d с", [int(ceil(m.time_left()))]))
		gw.missile_launched.emit(m)
	return m



static func _strike_pts(targets: Array) -> Array:
	var out: Array = []
	for e: Variant in targets:
		if e is Vector2:
			out.append([e, 1])
		elif e is Dictionary:
			out.append([(e as Dictionary).get("pos", Vector2.ZERO), clampi(int((e as Dictionary).get("n", 1)), 1, MULTI_N_MAX)])
	return out






func missile_multi_plan(country: Country, targets: Array) -> Dictionary:
	var out: Dictionary = {"ok": false, "total": 0, "available": 0, "assigned": 0, "tels": 0, "per_target": [], "plan": [], "why": ""}
	if country == null:
		return out
	var free: Dictionary = {}
	var avail: int = 0
	for f: Facility in facilities:
		if f.kind == Facility.Kind.TEL and f.country_id == country.id and alive(f) and not f.moving:
			var k: int = maxi(0, f.missiles - f.queued.size())
			if k > 0:
				free[f] = k
				avail += k
	out["available"] = avail
	var used: Dictionary = {}
	var sbw: String = ""
	for e: Array in _strike_pts(targets):
		var p: Vector2 = e[0]
		var n: int = int(e[1])
		out["total"] = int(out["total"]) + n
		var got: int = 0
		var tl: Dictionary = {}
		if gw.diplo != null and gw.diplo.strike_block_at(country.id, p, false) != "":
			sbw = Diplomacy.STRIKE_BLOCK_TXT
			(out["per_target"] as Array).append({"ok": false, "reason": sbw, "n": n, "got": 0, "tels": 0, "pos": p})
			continue
		for i in n:
			var best: Facility = null
			var bd: float = INF
			for f: Facility in free:
				if int(free[f]) <= 0:
					continue
				var d: float = f.center_px().distance_to(p)
				if d > MISSILE_RANGE or d < MISSILE_MIN:
					continue
				if best == null or int(free[f]) > int(free[best]) or (int(free[f]) == int(free[best]) and d < bd):
					best = f
					bd = d
			if best == null:
				break
			free[best] = int(free[best]) - 1
			(out["plan"] as Array).append([best, p])
			tl[best] = true
			used[best] = true
			got += 1
		var why: String = ""
		if got < n:
			why = Loc.t("Вне дальности ОТРК") if tels_for(country, p).is_empty() else Loc.t("Не хватает ракет")
		(out["per_target"] as Array).append({"ok": got == n, "reason": why, "n": n, "got": got, "tels": tl.size(), "pos": p})
		out["assigned"] = int(out["assigned"]) + got
	out["tels"] = used.size()
	out["ok"] = int(out["assigned"]) > 0
	if sbw != "" and int(out["assigned"]) == 0:
		out["why"] = sbw
	elif avail == 0:
		out["why"] = Loc.t("Нет ракет: идёт перезарядка") if has_kind(country.id, Facility.Kind.TEL) else Loc.t("Нет ОТРК")
	return out




func launch_missiles_multi(country: Country, targets: Array) -> Dictionary:
	var mp: Dictionary = missile_multi_plan(country, targets)
	var res: Dictionary = {"launched": 0, "per": [], "tels": int(mp["tels"]), "text": ""}
	for pt: Dictionary in mp["per_target"]:
		(res["per"] as Array).append(int(pt["got"]))
	for e: Array in mp["plan"]:
		(e[0] as Facility).queued.append(e[1])
		res["launched"] = int(res["launched"]) + 1
	var n_pts: int = 0
	for g: int in res["per"]:
		n_pts += 1 if g > 0 else 0
	if int(res["launched"]) > 0:
		res["text"] = Loc.t("Ракетный удар: %d по %d целям, ОТРК: %d") % [int(res["launched"]), n_pts, int(res["tels"])]
	else:
		res["text"] = String(mp["why"]) if String(mp["why"]) != "" else Loc.t("Нет ракет в зоне досягаемости")
	if country != null and country.is_player and not bool(gw.get_meta("strike_quiet", false)):
		gw.say(country, String(res["text"]))
	return res


func _tel_sprite(f: Facility, frame: int) -> void :
	if f.main_obj < 0:
		return
	if f.missiles >= 2:
		gw.set_obj_frame(f.main_obj, "tel2", frame)
	elif f.missiles == 1:
		gw.set_obj_frame(f.main_obj, "tel1", frame)
	else:
		gw.set_obj_frame(f.main_obj, "tel0", 0)


func _fire(f: Facility, target: Vector2) -> void :
	var sprite: String = "tel2" if f.missiles >= 2 else "tel1"
	var nt: Array[Vector2] = _tel_nozzle(f, sprite)
	var ground_y: float = float((f.cell.y + f.size.y) * GameWorld.CELL) - 2.0
	var m: = Missile.new()
	m.id = _next_missile_id
	_next_missile_id += 1
	m.country_id = f.country_id
	m.tel = f
	m.launch = Vector2(nt[0].x, ground_y)
	m.target = target
	m.dist = m.launch.distance_to(target)
	m.flight_time = flight_time_for(m.dist)
	m.apex = apex_for(m.dist)
	m.apex_km = clampf(m.dist / 1000.0 * 9.0, 8.0, 50.0)
	m.alt0 = ground_y - (nt[0].y + nt[1].y) * 0.5
	m.prev_screen = m.screen_pos()
	m.last_screen = m.prev_screen
	missiles.append(m)
	f.missiles -= 1
	f.erect_t = -1.0
	f.lower_sprite = "tel2e" if f.missiles >= 1 else "tel1e"
	f.lower_t = Missile.IGNITE_TIME + 0.4 + BOOM_LOWER
	gw.set_obj_frame(f.main_obj, f.lower_sprite, 6)
	gw.fx.spawn("tel_flash", nt[0].round(), 6)
	gw.fx.spawn("launch_cloud", Vector2(nt[0].x, ground_y).round(), 5)
	gw.camera_shake_launch(m.launch)
	Sfx.play("missile_launch", m.launch)
	if gw.country_by_id(f.country_id).is_player:
		gw.say(gw.country_by_id(f.country_id), Loc.mk("Пуск ракеты: полёт %d с", [int(ceil(m.time_left()))]))
		gw.missile_launched.emit(m)




func _own_drone_end(d: Drone) -> void :
	if gw.player == null or d.country_id != gw.player.id or gw.protect == null or d.end_reason == Drone.End.HIT:
		return
	if d.flown < 40.0 or d.kind > 2:
		return
	gw.protect.own_lost([Protect.HIT_DRONE, Protect.HIT_CRUISE, Protect.HIT_JET][clampi(d.kind, 0, 2)])


func _update_missiles(dt: float) -> void :
	if gw.player != null:
		for mo: Variant in _own_m.keys():
			if not missiles.has(mo):
				_own_m.erase(mo)
				var om: Missile = mo as Missile
				if om != null and not om.has_meta("hit") and gw.protect != null:
					gw.protect.own_lost(Protect.HIT_HYPER if om.hyper else Protect.HIT_BALLISTIC)
		for m0: Missile in missiles:
			if m0.country_id == gw.player.id and not _own_m.has(m0):
				_own_m[m0] = true

	var drop: int = 0
	while drop < trail_t.size() and gw.game_time - trail_t[drop] > PUFF_LIFE:
		drop += 1
	if drop > 0:
		trail_pts = trail_pts.slice(drop)
		trail_t = trail_t.slice(drop)
		trail_flip = trail_flip.slice(drop)
	for k in range(missiles.size() - 1, -1, -1):
		var m: Missile = missiles[k]
		m.t += dt
		if m.state == Missile.State.IGNITE and m.t >= Missile.IGNITE_TIME:
			m.state = Missile.State.FLIGHT
		var sp: Vector2 = m.screen_pos()
		var v: Vector2 = sp - m.prev_screen
		if v.length() > 0.05:
			m.frame = posmod(roundi(rad_to_deg(v.angle()) / 22.5), 16)

		if m.state == Missile.State.FLIGHT:
			m.trail_acc += v.length()
			var back: Vector2 = - v.normalized() if v.length() > 0.001 else Vector2.DOWN
			var n: int = 0
			while m.trail_acc >= PUFF_STEP and n < 8:
				m.trail_acc -= PUFF_STEP
				trail_pts.append((sp + back * (5.0 + m.trail_acc)).round())
				trail_t.append(gw.game_time)
				trail_flip.append(Hash32.h2(m.id, trail_pts.size(), 77) & 3)
				n += 1
		m.prev_screen = sp
		if not m.whistled and m.time_left() < 1.8:
			m.whistled = true
			Sfx.play("missile_whistle", m.target)
		if m.u() >= 1.0:
			m.state = Missile.State.DONE
			m.set_meta("hit", true)
			missiles.remove_at(k)
			if gw.protect != null:
				gw.protect.on_impact(m.target, Protect.HIT_HYPER if m.hyper else Protect.HIT_BALLISTIC, m.country_id)
			if gw.battle_watch != null:
				gw.battle_watch.impact(m.target, "Ракетный удар", m.country_id)
			gw.strike_big(Vector2i(floori(m.target.x / GameWorld.CELL), floori(m.target.y / GameWorld.CELL)), m.country_id)
			if gw.vfx != null:
				gw.vfx.on_impact(m.target, 2)




func tel_sprite_name(f: Facility) -> String:
	return "tel2" if f.missiles >= 2 else ("tel1" if f.missiles == 1 else "tel0")




static func is_mobile(kind: int) -> bool:
	return kind == Facility.Kind.TEL or kind == Facility.Kind.AD_MFG or kind == Facility.Kind.AD_SPAAG or kind == Facility.Kind.AD_SAM\
	or kind == Facility.Kind.AD_PATRIOT or kind == Facility.Kind.AD_RADAR or kind == Facility.Kind.AD_EW or kind == Facility.Kind.COASTAL_ASM


static func roams(kind: int) -> bool:
	return kind == Facility.Kind.AD_MFG or kind == Facility.Kind.AD_SPAAG or kind == Facility.Kind.COASTAL_ASM



func own_near(cid: int, c: Vector2i, max_px: float) -> Vector2i:
	return _own_near_core(gw.data.owners, gw.data.w, gw.data.h, cid, c, max_px)



static func _own_near_core(owners: PackedByteArray, w: int, h: int, cid: int, c: Vector2i, max_px: float) -> Vector2i:
	if c.x >= 0 and c.y >= 0 and c.x < w and c.y < h and owners[c.y * w + c.x] == cid:
		return c
	var rmax: int = ceili(max_px / float(GameWorld.CELL))
	var r: int = ROAM_STEP
	while r <= rmax:
		var n: int = maxi(8, ceili(TAU * float(r) / float(ROAM_STEP)))
		for k in n:
			var a: float = TAU * float(k) / float(n)
			var x: int = c.x + roundi(cos(a) * float(r))
			var y: int = c.y + roundi(sin(a) * float(r))
			if x >= 0 and y >= 0 and x < w and y < h and owners[y * w + x] == cid:
				return Vector2i(x, y)
		r += ROAM_STEP
	return Vector2i(-1, -1)






func _roam_check() -> void :
	var d: WorldData = gw.data
	_roam_tick += 1
	for fid: int in _roam_jobs.keys():
		var jb: Dictionary = _roam_jobs[fid]
		if not gw.job_ready(int(jb["task"])):
			continue
		WorkerThreadPool.wait_for_task_completion(int(jb["task"]))
		_roam_jobs.erase(fid)
		var fj: Facility = jb["f"]
		var box: Array = jb["box"]
		if box.is_empty() or fj.moving or not alive(fj) or fj.cell != jb["cell"]:
			continue
		var res: Dictionary = box[0]
		if res.has("anchor"):
			_roam_anchor[fid] = res["anchor"]
			continue
		var path: Array[Vector2i] = res.get("path", [] as Array[Vector2i])
		if path.is_empty():
			_roam_wait[fid] = gw.game_time + 30.0
			continue
		_drive_path(fj, path, fj.origin_px() + Vector2(fj.size.x * 2.0, fj.size.y * 4.0))
		var cp: Country = gw.country_by_id(fj.country_id)
		if cp != null and cp.is_player:
			gw.say(cp, Loc.mk("%s: граница отошла дальше 2,5 км — возвращается", [title_of(fj.kind)]))
	var snap: Array = []
	for f: Facility in facilities:
		if not roams(f.kind) or f.moving or (f.id + _roam_tick) % 3 != 0 or _roam_jobs.has(f.id) or not alive(f):
			continue
		var c: Vector2i = f.cell + f.size / 2
		if not d.inside(c.x, c.y) or d.owners[c.y * d.w + c.x] == f.country_id:
			_roam_anchor.erase(f.id)
			continue
		var an: Variant = _roam_anchor.get(f.id)
		if an is Vector2i and d.owners[(an as Vector2i).y * d.w + (an as Vector2i).x] == f.country_id\
		and Vector2(an - c).length() * float(GameWorld.CELL) <= ROAM_MAX + 64.0:
			continue
		if gw.game_time < float(_roam_wait.get(f.id, -1.0)):
			continue
		_roam_anchor.erase(f.id)

		var alt: Array[Vector2i] = [f.home_nw + f.size / 2]
		var cc: Country = gw.country_by_id(f.country_id)
		var bd: float = INF
		var hc: Vector2i = Vector2i(-1, -1)
		for cid2 in (cc.city_ids if cc != null else PackedInt32Array()):
			var ct: City = gw.cities[cid2]
			var hp: Vector2i = ct.center + Vector2i(0, ct.radius + 4)
			if Vector2(hp - c).length() < bd:
				bd = Vector2(hp - c).length()
				hc = hp
		alt.append(hc)
		var from: Vector2 = f.origin_px() + Vector2(f.size.x * 2.0, f.size.y * 4.0)
		var fc: = Vector2i(floori(from.x / GameWorld.CELL), floori(from.y / GameWorld.CELL) - 1)
		var box2: Array = []
		if snap.is_empty():



			snap = [d.owners.duplicate(), d.flags.duplicate(), d.biome.duplicate()]
		var job: Callable = _roam_job.bind(box2, snap[0], snap[1], snap[2], d.w, d.h, f.country_id, fc, c, Rect2i(f.cell, f.size), alt, int(_roam_try.get(f.id, 0)))
		_roam_try[f.id] = int(_roam_try.get(f.id, 0)) + 1
		_roam_jobs[f.id] = {"task": WorkerThreadPool.add_task(job, false, "roam_return"), "box": box2, "f": f, "cell": f.cell}




static func _roam_job(box: Array, owners: PackedByteArray, flags: PackedByteArray, biome: PackedByteArray, w: int, h: int, 
		cid: int, fc: Vector2i, c: Vector2i, own: Rect2i, alt: Array[Vector2i], n0: int) -> void :
	var nb: Vector2i = _own_near_core(owners, w, h, cid, c, ROAM_MAX + 64.0)
	if nb.x >= 0:
		box.append({"anchor": nb})
		return
	var tries: Array[Vector2i] = [_own_near_core(owners, w, h, cid, c, ROAM_MAX * 1.6)]
	tries.append_array(alt)
	for k in tries.size():
		var t: Vector2i = tries[(n0 + k) % tries.size()]
		if t.x < 0 or t.y < 0 or t.x >= w or t.y >= h or owners[t.y * w + t.x] != cid or Biome.is_water(biome[t.y * w + t.x]):
			continue
		box.append({"path": _path_core(owners, flags, biome, w, h, fc, t, cid, own, true)})
		return
	box.append({"path": [] as Array[Vector2i]})



func drain_roam() -> void :
	for fid: int in _roam_jobs:
		WorkerThreadPool.wait_for_task_completion(int(_roam_jobs[fid]["task"]))
	_roam_jobs.clear()


func vehicle_sprite(f: Facility) -> String:
	return tel_sprite_name(f) if f.kind == Facility.Kind.TEL else String(SPRITES[f.kind])


func order_move(f: Facility, cell: Vector2i) -> String:
	if not is_mobile(f.kind) or not alive(f):
		return Loc.t("Комплекс не может ехать")
	if f.erect_t >= 0.0 or f.lower_t > 0.0:
		return Loc.t("Идёт пуск - переезд позже")
	var d: WorldData = gw.data
	var roam: bool = roams(f.kind)
	if not d.inside(cell.x, cell.y):
		return Loc.t("Только по своей территории")
	if not roam and gw.econ.upk != null and gw.econ.upk.occupied(cell, gw.country_by_id(f.country_id)):
		return Loc.t("Оккупированная земля: только после мира")
	if d.get_owner_id(cell.x, cell.y) != f.country_id:
		if not roam:
			return Loc.t("Только по своей территории")
		if Biome.is_water(d.get_biome(cell.x, cell.y)) and not d.has_flag(cell.x, cell.y, WorldData.F_BRIDGE):
			return Loc.t("Нельзя в воду")
		if own_near(f.country_id, cell, ROAM_MAX).x < 0:
			return Loc.t("Дальше 2,5 км от границы нельзя")
	if Biome.is_water(d.get_biome(cell.x, cell.y)) and not d.has_flag(cell.x, cell.y, WorldData.F_BRIDGE):
		return Loc.t("Нельзя в воду")
	var from: Vector2 = f.mpos if f.moving else f.origin_px() + Vector2(f.size.x * 2.0, f.size.y * 4.0)
	var fc: = Vector2i(floori(from.x / GameWorld.CELL), floori(from.y / GameWorld.CELL) - 1)
	var own: = Rect2i(f.cell, f.size) if not f.moving else Rect2i(fc, Vector2i.ONE)
	var path: Array[Vector2i] = _tel_path(fc, cell, f.country_id, own, roam)
	if path.is_empty():
		return Loc.t("Нет проезда") if roam else Loc.t("Нет проезда по своей земле")
	_drive_path(f, path, from)
	return ""



func _drive_path(f: Facility, path: Array[Vector2i], from: Vector2) -> void :
	var d: WorldData = gw.data
	var pts: Array[Vector2] = []
	for k in range(1, path.size()):

		if k < path.size() - 1 and path[k] - path[k - 1] == path[k + 1] - path[k]:
			continue
		pts.append(Vector2(path[k] * GameWorld.CELL) + Vector2(2, 3))
	if not f.moving:
		f.home_nw = f.cell

		for y in range(f.cell.y, f.cell.y + f.size.y):
			for x in range(f.cell.x, f.cell.x + f.size.x):
				d.clear_flag(x, y, WorldData.F_OCCUPIED)
		unpave(gw, Rect2i(f.cell, f.size))
		gw.remove_object(f.main_obj)
		f.obj_ids = PackedInt32Array()
		f.main_obj = -1
		f.mpos = from
		f.moving = true
		f.queued.clear()
		for h: Array in f.fx:
			gw.fx.stop_h(h)
		f.fx.clear()
	f.mpath = pts
	f.mdest = pts[pts.size() - 1] if not pts.is_empty() else from


func _tel_path(a: Vector2i, b: Vector2i, country_id: int, own: Rect2i, roam: bool = false) -> Array[Vector2i]:
	var d: WorldData = gw.data
	return _path_core(d.owners, d.flags, d.biome, d.w, d.h, a, b, country_id, own, roam)



static func _path_core(owners: PackedByteArray, flags: PackedByteArray, biome: PackedByteArray, w: int, h: int, 
		a: Vector2i, b: Vector2i, country_id: int, own: Rect2i, roam: bool) -> Array[Vector2i]:
	var margin: int = 24
	var x0: int = maxi(0, mini(a.x, b.x) - margin)
	var y0: int = maxi(0, mini(a.y, b.y) - margin)
	var x1: int = mini(w - 1, maxi(a.x, b.x) + margin)
	var y1: int = mini(h - 1, maxi(a.y, b.y) + margin)
	var astar: = AStarGrid2D.new()
	astar.region = Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i: int = y * w + x
			var fl: int = flags[i]
			var cost: float = 2.5
			if owners[i] != country_id and not roam:
				cost = -1.0
			elif (fl & WorldData.F_BRIDGE) != 0 or (fl & WorldData.F_ROAD) != 0:
				cost = 1.0
			elif Biome.is_water(biome[i]):
				cost = -1.0
			elif (fl & WorldData.F_OCCUPIED) != 0 and not own.has_point(Vector2i(x, y)):
				cost = -1.0
			else:
				var bb: int = biome[i]
				if bb == Biome.FOREST or bb == Biome.PINE:
					cost = 4.0
				elif bb == Biome.ROCK or bb == Biome.SNOW:
					cost = 8.0
			if cost < 0.0:
				astar.set_point_solid(Vector2i(x, y), true)
			else:
				astar.set_point_weight_scale(Vector2i(x, y), cost)
	astar.set_point_solid(a, false)
	astar.set_point_solid(b, false)
	return astar.get_id_path(a, b)


func _drive_tel(f: Facility, dt: float) -> void :
	if f.mpath.is_empty():
		_park_tel(f, true)
		return
	var tgt: Vector2 = f.mpath[0]
	var to: Vector2 = tgt - f.mpos
	var dist: float = to.length()
	if dist < 0.3:
		f.mpos = tgt
		f.mpath.remove_at(0)
		return
	var tm: float = AdTripS.TRIP_MUL if gw.diplo != null and gw.diplo.sky != null and gw.diplo.sky.trip.trips.has(f.id) else 1.0
	f.mpos += to / dist * minf(TEL_SPEED * (1.8 if f.kind == Facility.Kind.AD_MFG else 1.0) * tm * dt, dist)
	_drive_heading(f)
	f.cell = Vector2i(floori(f.mpos.x / GameWorld.CELL), floori(f.mpos.y / GameWorld.CELL)) - Vector2i(f.size.x / 2, f.size.y)
	f.dust_t -= dt
	if f.dust_t <= 0.0:
		f.dust_t = 0.45
		var back: Vector2 = [Vector2(-14.0, -2.0), Vector2(0.0, -18.0), Vector2(14.0, -2.0), Vector2(0.0, 10.0)][drive_dir_of(f)]
		gw.fx.spawn("dust_s", (f.mpos + back).round(), 4)



func drive_dir_of(f: Facility) -> int:
	return int(drive_dir.get(f.id, 2 if f.flip else 0))




func _drive_heading(f: Facility) -> void :
	var ahead: Vector2 = f.mpos
	var left: float = DRIVE_LOOK
	for q: Vector2 in f.mpath:
		var seg: float = ahead.distance_to(q)
		if seg >= left:
			ahead += (q - ahead) / seg * left
			left = 0.0
			break
		left -= seg
		ahead = q
	var v: Vector2 = ahead - f.mpos
	if v.length() < 1.0:
		return
	var ang: float = v.angle()
	var want: int = posmod(roundi(ang / (PI * 0.5)), 4)
	var cur: int = int(drive_dir.get(f.id, -1))
	if cur >= 0 and cur != want and absf(angle_difference(float(cur) * PI * 0.5, ang)) < deg_to_rad(45.0 + DRIVE_HYST):
		want = cur
	drive_dir[f.id] = want
	if want == 0 or want == 2:
		f.flip = want == 2



func _park_tel(f: Facility, intact: bool) -> void :
	var c: = Vector2i(floori(f.mpos.x / GameWorld.CELL), floori(f.mpos.y / GameWorld.CELL) - 1)
	var nw: Vector2i = nw_for(f.kind, c)
	var country: Country = gw.country_by_id(f.country_id)
	var found: bool = false
	for r in 13:
		for dy in range( - r, r + 1):
			for dx in range( - r, r + 1):
				if found or maxi(absi(dx), absi(dy)) != r:
					continue
				if check_place(f.kind, nw + Vector2i(dx, dy), country, null, false, roams(f.kind)) == "":
					nw += Vector2i(dx, dy)
					found = true
	if not found:
		nw = f.home_nw
	f.cell = nw
	f.moving = false
	drive_dir.erase(f.id)
	var d: WorldData = gw.data
	for y in range(nw.y - 4, nw.y + f.size.y + 1):
		for x in range(nw.x - 1, nw.x + f.size.x + 1):
			if d.inside(x, y):
				gw.remove_tree_at(Vector2i(x, y))
	for y in range(nw.y, nw.y + f.size.y):
		for x in range(nw.x, nw.x + f.size.x):
			if d.inside(x, y):
				d.add_flag(x, y, WorldData.F_OCCUPIED)
	f.main_obj = gw.add_object(vehicle_sprite(f), nw, GameWorld.KIND_BUILDING)
	f.obj_ids = PackedInt32Array([f.main_obj])
	gw.set_obj_frame(f.main_obj, vehicle_sprite(f), 0)
	f.frame_i = 0
	if not intact:
		gw.obj_state[f.main_obj] = 1
		gw._mark_obj_chunk(f.main_obj)
		f.missiles = 0
		f.reload_t = 0.0
	elif country.is_player:
		gw.say(country, Loc.mk("%s на позиции", [Loc.t("ОТРК") if f.kind == Facility.Kind.TEL else title_of(f.kind)]))





func sim_path(pos: Vector2, heading: float, route: Array[Vector2], max_len: float = 6000.0) -> PackedVector2Array:
	var out: = PackedVector2Array([pos])
	if route.is_empty():
		return out
	var p: Vector2 = pos
	var h: float = heading
	var i: int = 0
	var flown: float = 0.0
	var step: float = 6.0
	var dt: float = step / CRUISE
	for it in 1500:
		var tgt: Vector2 = route[i]
		var to: Vector2 = tgt - p
		var dist: float = to.length()
		var last: bool = i == route.size() - 1
		if last and dist <= DIVE_DIST:
			out.append(tgt)
			break
		if not last and (dist < 16.0 or (dist < 48.0 and absf(wrapf(to.angle() - h, - PI, PI)) > PI * 0.5)):
			i += 1
			continue
		var rate: float = AIR_TURN * (2.0 if last and dist < 90.0 else 1.0)
		var diff: float = wrapf(to.angle() - h, - PI, PI)
		h += clampf(diff, - rate * dt, rate * dt)
		p += Vector2.from_angle(h) * step
		flown += step
		if it % 2 == 0:
			out.append(p)
		if flown > max_len:
			break
	return out



func drone_preview(d: Drone) -> PackedVector2Array:
	if d.preview_ver != d.route_ver or gw.game_time - d.preview_at > 0.25:
		var start: Vector2 = d.pos
		var h: float = d.heading
		if d.state < Drone.State.BOOST:
			start = launch_point(d.airfield)
			h = 0.0
		d.preview = sim_path(start, h, d.route, d.range_px - d.flown + 200.0)
		if d.state < Drone.State.BOOST:
			d.preview.insert(0, d.pos)
		d.preview_at = gw.game_time
		d.preview_ver = d.route_ver
	return d.preview






func on_strike(cell: Vector2i, r_px: float = 14.0) -> void :
	var p: = Vector2(cell.x * GameWorld.CELL + 2, cell.y * GameWorld.CELL + 2)
	air.on_strike(p, r_px)
	_crit_hit(p, r_px)

	var rc: int = maxi(1, int(r_px / GameWorld.CELL * 0.6))
	var rt: int = maxi(1, int(r_px / GameWorld.CELL))
	for dy in range( - rt, rt + 1):
		for dx in range( - rt, rt + 1):
			var q: = cell + Vector2i(dx, dy)
			if fort_cells.has(q) and (dx * dx + dy * dy <= rc * rc or (dx * dx + dy * dy <= rt * rt and is_teeth((fort_cells[q] as Facility).kind))):
				remove_line_cell(fort_cells[q], q)
	for k in range(drones.size() - 1, -1, -1):
		var d: Drone = drones[k]
		if d.h > 2.0 or d.pos.distance_to(p) > r_px:
			continue
		if d.spot >= 0 and d.airfield.parked[d.spot] == d:
			d.airfield.parked[d.spot] = null
		if d.launcher != null and d.launcher.reserved == d:
			_release(d.launcher, 0.0)
		d.state = Drone.State.DONE
		d.end_reason = Drone.End.DESTROYED
		gw.fx.spawn("explosion_s", d.pos.round(), 6)
		gw.fx.debris_burst(d.pos.round(), 2, false)
		_scar(d.pos)
		drones.remove_at(k)
	for f: Facility in facilities:
		if f.kind == Facility.Kind.TEL and f.moving and f.mpos.distance_to(p) <= r_px + 10.0:
			_park_tel(f, false)
			gw.fx.spawn("explosion_s", f.mpos.round(), 6)
	if gw.diplo != null and gw.diplo.sky != null and not gw.diplo.sky.trip.trips.is_empty():
		gw.diplo.sky.trip.on_strike(p, r_px)
	for f: Facility in facilities:
		var rw: = Rect2()
		if f.kind == Facility.Kind.AIRFIELD:
			rw = Rect2(f.origin_px() + AF_RUNWAY.position, AF_RUNWAY.size)
		elif f.kind == Facility.Kind.DP_RUNWAY:
			rw = Rect2(gw.obj_origin(f.main_obj), Vector2(64, 12))
		else:
			continue
		if not rw.grow(r_px * 0.5).has_point(p):
			continue
		var c: = Vector2(clampf(p.x, rw.position.x + 6.0, rw.end.x - 6.0), clampf(p.y, rw.position.y + 5.0, rw.end.y - 5.0))
		f.craters.append(c.round())
		f.repair_t = RUNWAY_REPAIR
		if gw.country_by_id(f.country_id).is_player:
			gw.say(gw.country_by_id(f.country_id), Loc.mk("ВПП повреждена — ремонт %d с", [int(RUNWAY_REPAIR)]))
