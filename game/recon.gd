class_name Recon
extends RefCounted














enum St{CLIMB, OUT, LOITER, BACK, LAND, DONE}

const COST: Dictionary = {"money": 150, "metal": 1}
const AI_COST_NO_METAL: int = 230
const RANGE: float = 4500.0
const SPEED: float = 48.0
const CRUISE_H: float = 10.0
const CLIMB_RATE: float = 3.0
const TURN: float = PI * 0.6
const LOITER_T: float = 25.0
const LOITER_R: float = 55.0
const VIEW_R: float = 150.0
const PORT_CD: float = 25.0
const PER_PORT: int = 1
const GUN_MUL: float = 0.5
const MSL_MUL: float = 0.6
const EW_CHANCE: int = 35
const JAM_T: float = 4.0
const REPORT_AT: float = 4.0
const AI_DT: float = 15.0
const AI_RESERVE: int = 600
const KILL_SCORE: int = 60

class RDrone:
	extends RefCounted
	var id: int = 0
	var country_id: int = 0
	var port_id: int = -1
	var state: int = 0
	var pos: Vector2 = Vector2.ZERO
	var home: Vector2 = Vector2.ZERO
	var target: Vector2 = Vector2.ZERO
	var heading: float = 0.0
	var speed: float = 0.0
	var h: float = 0.0
	var frame: int = 0
	var t0: float = 0.0
	var loiter_t: float = 0.0
	var loiter_a: float = 0.0
	var jam_t: float = 0.0
	var drift: float = 0.0
	var engaged: bool = false
	var dead: bool = false
	var why_back: String = ""
	var seen: Dictionary = {}
	var units_seen: int = 0
	var reported: bool = false
	var warned: bool = false
	var incidents: Dictionary = {}
	var scan_t: float = 0.0
	var ew_t: float = 0.0

	func airborne() -> bool:
		return h >= 1.0 and not dead and state != 5

	func update_frame() -> void :
		var deg: float = rad_to_deg(heading)
		if absf(wrapf(deg - frame * 22.5, -180.0, 180.0)) > 14.0:
			frame = posmod(roundi(deg / 22.5), 16)

var gw: GameWorld
var drones: Array = []
var shots: Array = []
var port_ready: Dictionary = {}
var launches: int = 0
var spent: int = 0
var lost: int = 0
var _next_id: int = 1
var _shot_id: int = 1
var _ad_next: Dictionary = {}
var _ai_t: float = 0.0
var _intel: Dictionary = {}
var _rng: = RandomNumberGenerator.new()


func _init(world: GameWorld) -> void :
	gw = world
	_rng.seed = (gw.settings.world_seed if gw.settings != null else 1) * 7919 + 17
	_ensure_layer()


func _ensure_layer() -> void :
	if gw == null or not gw.is_inside_tree():
		return
	var lay: Node = gw.get_node_or_null("ReconLayer")
	if lay == null:
		lay = ReconLayer.new()
		lay.name = "ReconLayer"
		gw.add_child(lay)
		if gw.units_air != null:
			gw.move_child(lay, gw.units_air.get_index() + 1)
	(lay as ReconLayer).gw = gw





func cost() -> Dictionary:
	return COST.duplicate()



func cost_text() -> String:
	return Loc.t("%d + металл %d") % [int(COST["money"]), int(COST.get("metal", 0))]



func has_ramp(port: Facility) -> bool:
	for m: Facility in port.modules:
		if m.kind == Facility.Kind.DP_RAMP and gw.mil.alive(m):
			return true
	return false



func _port_free(f: Facility) -> bool:
	return active_from(f) < cap_of(f) and gw.game_time >= float(port_ready.get(f.id, 0.0))



func cap_of(port: Facility) -> int:
	return PER_PORT + (1 if gw.mil.runways_of(port) > 0 else 0)


func active_from(port: Facility) -> int:
	var n: int = 0
	for d: RDrone in drones:
		if d.port_id == port.id and d.state != St.DONE:
			n += 1
	return n



func active_for(country_id: int) -> Array:
	var out: Array = []
	for d: RDrone in drones:
		if d.country_id == country_id and d.state != St.DONE and not d.dead:
			out.append(d)
	return out


func _ports(country_id: int) -> Array[Facility]:
	var out: Array[Facility] = []
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.DRONE_PORT and f.country_id == country_id and gw.mil.alive(f) and has_ramp(f):
			out.append(f)
	return out



func wait_for(country_id: int) -> float:
	var best: float = INF
	for f: Facility in _ports(country_id):
		if active_from(f) < cap_of(f):
			best = minf(best, maxf(0.0, float(port_ready.get(f.id, 0.0)) - gw.game_time))
	if best == INF:
		return -1.0 if _ports(country_id).is_empty() else 999.0
	return best



func port_for(country_id: int, pos: Vector2) -> Facility:
	var best: Facility = null
	var bd: float = INF
	for f: Facility in _ports(country_id):
		if not _port_free(f):
			continue
		var d: float = gw.mil.launch_point(f).distance_to(pos)
		if d <= RANGE and d < bd:
			bd = d
			best = f
	return best



func can_launch(country_id: int, pos: Vector2 = Vector2.INF) -> String:
	var c: Country = gw.country_by_id(country_id)
	if c == null:
		return Loc.t("НЕТ СТРАНЫ")
	var ports: Array[Facility] = _ports(country_id)
	if ports.is_empty():
		for f0: Facility in gw.mil.facilities:
			if f0.kind == Facility.Kind.DRONE_PORT and f0.country_id == country_id and gw.mil.alive(f0):
				return Loc.t("НУЖНА ПУСКОВАЯ РАМПА ДРОНОПОРТА")
		return Loc.t("НУЖЕН ДРОНОПОРТ")
	var free: Array[Facility] = []
	for f: Facility in ports:
		if active_from(f) < cap_of(f):
			free.append(f)
	if free.is_empty():
		return Loc.t("ВСЕ РАЗВЕДДРОНЫ В ВОЗДУХЕ")
	var ready: Array[Facility] = []
	for f: Facility in free:
		if gw.game_time >= float(port_ready.get(f.id, 0.0)):
			ready.append(f)
	if ready.is_empty():
		return Loc.t("РАЗВЕДДРОН ГОТОВИТСЯ: %d С") % ceili(wait_for(country_id))
	if pos.is_finite():
		var ok: bool = false
		for f: Facility in ready:
			if gw.mil.launch_point(f).distance_to(pos) <= RANGE:
				ok = true
				break
		if not ok:
			return Loc.t("ДАЛЬШЕ %.1f КМ ОТ ДРОНОПОРТА") % (RANGE / 1000.0)
	if not c.has_res(COST):
		return Loc.t("НЕ ХВАТАЕТ: %s") % c.missing_res(COST).to_upper()
	return ""



func launch(country_id: int, pos: Vector2) -> String:
	var why: String = can_launch(country_id, pos)
	if why != "":
		return why
	var c: Country = gw.country_by_id(country_id)
	var port: Facility = port_for(country_id, pos)
	if port == null:
		return Loc.t("НЕТ ДРОНОПОРТА")
	_pay(c, COST)
	return "" if _start(c, port, pos) != null else Loc.t("НЕТ ДРОНОПОРТА")


func _pay(c: Country, cost_d: Dictionary) -> void :
	c.pay_res(cost_d)
	spent += int(cost_d.get("money", 0))
	if gw.econ != null and gw.econ.has_method("stat_add"):
		gw.econ.stat_add(c, "spend", "intel", int(cost_d.get("money", 0)))
		for rk: String in cost_d:
			if rk != "money":
				gw.econ.stat_res(c, rk, "intel", - int(cost_d[rk]))


func _start(c: Country, port: Facility, pos: Vector2) -> RDrone:
	if port == null:
		return null
	var d: = RDrone.new()
	d.id = _next_id
	_next_id += 1
	d.country_id = c.id
	d.port_id = port.id
	d.home = gw.mil.launch_point(port)
	d.pos = d.home
	d.target = pos
	d.heading = (pos - d.home).angle()
	d.update_frame()
	d.t0 = gw.game_time
	d.state = St.CLIMB
	drones.append(d)
	port_ready[port.id] = gw.game_time + PORT_CD
	launches += 1
	Sfx.play("drone_launch", d.home, -6.0)
	if c.is_player:
		var dist: float = d.home.distance_to(pos)
		gw.say(c, Loc.mk("Разведдрон: −%d, цель %.1f км, ~%d с", [int(COST["money"]), dist / 1000.0, ceili(dist / SPEED)]))
	return d



func recall(d: RDrone) -> String:
	if d == null or d.dead or d.state >= St.BACK:
		return Loc.t("УЖЕ ВОЗВРАЩАЕТСЯ")
	_go_back(d, "recalled")
	return ""



func drone_at(p: Vector2, z: float) -> RDrone:
	var best: RDrone = null
	var bd: float = maxf(10.0, 16.0 / maxf(z, 0.05))
	for d: RDrone in drones:
		if d.dead or d.state == St.DONE or not visible(d):
			continue
		var dd: float = d.pos.distance_to(p)
		if dd < bd:
			bd = dd
			best = d
	return best



func visible(d: RDrone) -> bool:
	return gw.vision == null or gw.vision.shows_air(d.country_id, d.pos)



func info(d: RDrone) -> Dictionary:
	var c: Country = gw.country_by_id(d.country_id)
	var st: String = [Loc.t("ВЗЛЁТ"), Loc.t("К ЦЕЛИ"), Loc.t("НАД ЦЕЛЬЮ"), Loc.t("ВОЗВРАТ"), Loc.t("ПОСАДКА"), Loc.t("ЗАВЕРШЁН")][d.state]
	if d.jam_t > 0.0:
		st = Loc.t("ПОМЕХИ РЭБ")
	var eta: float = 0.0
	match d.state:
		St.CLIMB, St.OUT:
			eta = d.pos.distance_to(d.target) / SPEED
		St.LOITER:
			eta = LOITER_T - d.loiter_t
		St.BACK, St.LAND:
			eta = d.pos.distance_to(d.home) / SPEED
	var own: bool = gw.player != null and (d.country_id == gw.player.id)
	return {"title": Loc.t("РАЗВЕДДРОН"), "icon": "icon_recon_drone", "owner": c.name if c != null else "?", 
		"own": own, "state": st, "eta": eta, "found": d.seen.size() if own else 0, 
		"units": d.units_seen if own else 0, "why": back_text(d.why_back), "jam": d.jam_t > 0.0, "back": d.jam_t <= 0.0 and d.state == St.BACK, 
		"sub": Loc.t("Без оружия: обзор %d м, кружит %d с") % [int(VIEW_R), int(LOITER_T)]}



func has_intel(cid: int, enemy_id: int, max_age: float = 180.0) -> bool:
	var k: String = "%d>%d" % [cid, enemy_id]
	return _intel.has(k) and gw.game_time - float(_intel[k]) <= max_age




func update(dt: float) -> void :
	if drones.is_empty() and shots.is_empty():
		_ai(dt)
		return
	for k in range(drones.size() - 1, -1, -1):
		var d: RDrone = drones[k]
		if d.state == St.DONE or d.dead:
			_vision_off(d)
			drones.remove_at(k)
			continue
		_move(d, dt)
		if d.state == St.DONE or d.dead:
			continue
		_vision_on(d)
		d.scan_t -= dt
		if d.scan_t <= 0.0:
			d.scan_t = 0.5
			_scan(d)
		if d.airborne():
			_threats(d, dt)
	_update_shots(dt)
	_ai(dt)


func _vision_on(d: RDrone) -> void :
	if gw.vision == null or not gw.vision.has_method("add_temp_source"):
		return
	if d.airborne() and d.jam_t <= 0.0:
		gw.vision.add_temp_source("recon%d" % d.id, d.country_id, d.pos, VIEW_R, gw.game_time + 1.0)
	else:
		gw.vision.remove_temp_source("recon%d" % d.id)


func _vision_off(d: RDrone) -> void :
	if gw.vision != null and gw.vision.has_method("remove_temp_source"):
		gw.vision.remove_temp_source("recon%d" % d.id)


func _turn_to(d: RDrone, want: float, dt: float) -> void :
	d.heading = wrapf(d.heading + clampf(wrapf(want - d.heading, - PI, PI), - TURN * dt, TURN * dt), - PI, PI)


func _move(d: RDrone, dt: float) -> void :
	if d.jam_t > 0.0:
		d.jam_t -= dt
		d.heading = wrapf(d.heading + d.drift * dt, - PI, PI)
		d.pos += Vector2.from_angle(d.heading) * d.speed * dt
		d.update_frame()
		if d.jam_t <= 0.0 and d.state < St.BACK:
			_go_back(d, "jam")
		return
	match d.state:
		St.CLIMB:
			d.speed = minf(SPEED, d.speed + SPEED * 0.5 * dt)
			d.h = minf(CRUISE_H, d.h + CLIMB_RATE * dt)
			_turn_to(d, (d.target - d.pos).angle(), dt)
			d.pos += Vector2.from_angle(d.heading) * d.speed * dt
			if d.h >= CRUISE_H:
				d.state = St.OUT
		St.OUT:
			_turn_to(d, (d.target - d.pos).angle(), dt)
			d.pos += Vector2.from_angle(d.heading) * d.speed * dt
			if d.pos.distance_to(d.target) <= LOITER_R + 4.0:
				d.state = St.LOITER
				d.loiter_a = (d.pos - d.target).angle()
		St.LOITER:
			d.loiter_t += dt
			d.loiter_a = wrapf(d.loiter_a + SPEED / LOITER_R * dt, - PI, PI)
			var want: Vector2 = d.target + Vector2.from_angle(d.loiter_a) * LOITER_R
			var to: Vector2 = want - d.pos
			d.heading = to.angle() if to.length() > 0.5 else wrapf(d.loiter_a + PI * 0.5, - PI, PI)
			d.pos = d.pos.move_toward(want, SPEED * 1.5 * dt)
			if d.loiter_t >= REPORT_AT and not d.reported:
				d.reported = true
				_report(d, "")
			if d.loiter_t >= LOITER_T:
				_go_back(d, "")
		St.BACK:
			_turn_to(d, (d.home - d.pos).angle(), dt)
			d.pos += Vector2.from_angle(d.heading) * d.speed * dt
			if d.pos.distance_to(d.home) <= 40.0:
				d.state = St.LAND
		St.LAND:
			d.speed = maxf(10.0, d.speed - SPEED * 0.6 * dt)
			d.h = maxf(0.0, d.h - CLIMB_RATE * dt)
			var to2: Vector2 = d.home - d.pos
			if to2.length() > 1.0:
				d.heading = to2.angle()
			d.pos = d.pos.move_toward(d.home, d.speed * dt)
			if d.h <= 0.0 or d.pos.distance_to(d.home) < 1.0:
				_landed(d)
	d.update_frame()




const LOC_BACK: Dictionary = {"recalled": "отозван", "interceptor": "перехватчик", "jam": "помехи РЭБ", "ad_fire": "обстрел ПВО"}


static func back_text(why: String) -> String:
	return Loc.t(String(LOC_BACK.get(why, why)))


func _go_back(d: RDrone, why: String) -> void :
	if d.state >= St.BACK:
		return
	if d.state == St.LOITER or d.loiter_t > 0.0:
		_intel["%d>%d" % [d.country_id, _owner_at(d.target)]] = gw.game_time
	var early: bool = not d.reported
	d.reported = true
	d.state = St.BACK
	d.why_back = why
	var c: Country = gw.country_by_id(d.country_id)
	if c == null or not c.is_player:
		return
	if why == "":
		if early:
			_report(d, "")
	elif why == "recalled":
		gw.say(d.country_id, Loc.mk("Разведдрон отозван: %s", [found_text(d)]))
	elif early:
		gw.say(d.country_id, Loc.mk("Разведдрон: %s, возврат — %s", [back_text(why), found_text(d)]))
	else:
		gw.say(d.country_id, Loc.mk("Разведдрон: %s, возврат", [back_text(why)]))


func _landed(d: RDrone) -> void :
	d.state = St.DONE
	d.h = 0.0
	var port: Facility = _fac(d.port_id)
	var c: Country = gw.country_by_id(d.country_id)
	if port == null or not gw.mil.alive(port):
		lost += 1
		if c != null and c.is_player:
			gw.say(c, Loc.mk("Разведдрон потерян: дронопорт разрушен"))
		return
	if c != null and c.is_player:
		gw.say(c, Loc.mk("Разведдрон вернулся на базу"))


func _report(d: RDrone, _why: String) -> void :
	var c: Country = gw.country_by_id(d.country_id)
	if c == null or not c.is_player:
		return
	gw.say(c, Loc.mk("Разведдрон над целью: %s", [found_text(d)]))



func found_text(d: RDrone) -> String:
	var n: int = d.seen.size()
	if n == 0 and d.units_seen == 0:
		return Loc.t("ничего не обнаружено")
	var txt: String = Loc.t("обнаружено %d %s") % [n, plural(n, Loc.t("объект"), Loc.t("объекта"), Loc.t("объектов"))]
	if d.units_seen > 0:
		txt += Loc.t(", войска: %d") % d.units_seen
	return txt


static func plural(n: int, one: String, few: String, many: String) -> String:
	var m10: int = n % 10
	var m100: int = n % 100
	if m10 == 1 and m100 != 11:
		return one
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return few
	return many


func _fac(id: int) -> Facility:
	for f: Facility in gw.mil.facilities:
		if f.id == id:
			return f
	return null


func _owner_at(p: Vector2) -> int:
	var cx: int = int(p.x) / GameWorld.CELL
	var cy: int = int(p.y) / GameWorld.CELL
	if gw.data == null or not gw.data.inside(cx, cy):
		return 0
	return gw.data.get_owner_id(cx, cy)


func _friendly(a: int, b: int) -> bool:
	return a == b or (gw.diplo != null and gw.diplo.allied(a, b))



func _scan(d: RDrone) -> void :
	if not d.airborne() or d.jam_t > 0.0:
		return
	var r2: float = VIEW_R * VIEW_R
	for f: Facility in gw.mil.facilities:
		if f.parent != null or f.is_line() or _friendly(f.country_id, d.country_id) or d.seen.has(f.id):
			continue
		if f.center_px().distance_squared_to(d.pos) <= r2:
			d.seen[f.id] = true
			gw.mil.air.note_intel(d.country_id, f.id)
	var n: int = 0
	for u: Unit in gw.army.units:
		if u.alive() and not _friendly(u.country_id, d.country_id) and u.pos.distance_squared_to(d.pos) <= r2:
			n += 1
	d.units_seen = maxi(d.units_seen, n)

	var p: Country = gw.player
	if p != null and not d.warned and not _friendly(d.country_id, p.id) and _owner_at(d.pos) == p.id and visible(d):
		d.warned = true
		gw.message.emit(Loc.msg(Loc.mk("Вражеский разведдрон у г. %s", [_place_name(d.pos)])))


func _place_name(p: Vector2) -> String:
	var best: City = null
	var bd: float = INF
	for city: City in gw.cities:
		if city.country_id <= 0:
			continue
		var dd: float = Vector2(city.center * GameWorld.CELL).distance_squared_to(p)
		if dd < bd:
			bd = dd
			best = city
	return best.name if best != null else "?"



func _threats(d: RDrone, dt: float) -> void :
	var now: float = gw.game_time
	d.ew_t -= dt
	var ew_roll: bool = d.ew_t <= 0.0
	if ew_roll:
		d.ew_t = 1.0
	var def: Defense = gw.defense
	for f: Facility in gw.mil.facilities:
		var k: int = f.kind
		var is_ew: bool = k == Facility.Kind.AD_EW
		if not is_ew and not Defense.is_ad(k):
			continue
		if f.country_id == d.country_id or not gw.mil.alive(f) or f.moving:
			continue
		var fp: Vector2 = f.center_px()
		var d2: float = fp.distance_squared_to(d.pos)
		if is_ew:
			if ew_roll and d.jam_t <= 0.0 and gw.mil.hostile(f.country_id, d.country_id) and gw.mil.has_power(f)\
			and d2 <= Defense.EW_R * Defense.EW_R and Hash32.h2(d.id * 131 + f.id, int(now), 23) % 100 < EW_CHANCE:
				_jam(d)
			continue
		var sp: Dictionary = Defense.SPEC[k]
		if int(sp["mask"]) & Defense.T_DRONE == 0:
			continue
		var r: float = float(sp["range"])
		var det: float = float(sp["detect"])
		if d2 > r * r:
			continue
		var seen_by: bool = d2 <= det * det or def.covered(f.country_id, d.pos)
		if not seen_by:
			continue
		if not gw.mil.hostile(f.country_id, d.country_id):

			if not _friendly(f.country_id, d.country_id) and not d.incidents.has(f.country_id):
				d.incidents[f.country_id] = true
				if gw.diplo != null and gw.diplo.has_method("on_incident"):
					gw.diplo.on_incident(f.country_id, d.country_id, "drone", 1)
			continue
		if now < float(_ad_next.get(f.id, 0.0)):
			continue
		if (def.rule_mask(f.country_id, k) & Defense.R_RECON) == 0:
			continue
		if bool(sp.get("gun", false)):
			if not def.gun_ready(f) or not def.pay_shot(f):
				continue
			_ad_next[f.id] = now + float(sp["cd"])
			_gun(f, d, sp)
			def.mag_use(f)
		else:
			if f.ammo <= 0 or _incoming(d) > 0:
				continue
			f.alert_t = now + 10.0
			if k == Facility.Kind.AD_SAM and f.frame_i < 5:
				continue
			if not def.pay_shot(f):
				continue
			_ad_next[f.id] = now + float(sp["cd"])
			_launch(f, d, sp)
		if d.dead:
			return
		_engaged(d, f)


func _engaged(d: RDrone, f: Facility) -> void :
	if d.engaged:
		return
	d.engaged = true

	d.seen[f.id] = true
	if gw.vision != null and gw.vision.friend(d.country_id) and not gw.vision.friend(f.country_id):
		gw.vision.reveal(f.center_px(), 40.0, 5.0)
	if d.state < St.BACK:
		_go_back(d, "ad_fire")


func _jam(d: RDrone) -> void :
	d.jam_t = JAM_T
	d.drift = (1.0 if Hash32.h2(d.id, int(gw.game_time), 5) % 2 == 0 else -1.0) * 0.6
	gw.fx.spawn("spark_burst", d.pos.round(), 6)
	_vision_off(d)


func _incoming(d: RDrone) -> int:
	var n: int = 0
	for s: Dictionary in shots:
		if s["target"] == d:
			n += 1
	return n


func _gun(f: Facility, d: RDrone, sp: Dictionary) -> void :
	f.cd = maxf(f.cd, float(sp["cd"]))
	var gun: Vector2 = gw.defense._muzzle(f)
	f.turret = (d.pos - gun).angle()
	Sfx.play("aa_gun" if f.kind == Facility.Kind.AD_SPAAG else "mg_burst", gun)
	if gw._on_screen(gun, 80.0):
		gw.fx.spawn("muzzle_flash", gun.round(), 6)
	gw.mil.air.tracers.append([gun, d.pos, gw.game_time + 0.12])
	var hit: int = roundi(float(sp["hit"]) * GUN_MUL)
	if Hash32.h2(f.id * 7 + d.id, int(gw.game_time * 10.0), 61) % 100 < hit:
		_kill(d, f.country_id)


func _launch(f: Facility, d: RDrone, sp: Dictionary) -> void :
	f.cd = maxf(f.cd, float(sp["cd"]))
	f.ammo -= 1
	var start: Vector2 = gw.defense._muzzle(f)
	var kind: String = "int" if f.kind == Facility.Kind.AD_INT else "sam"
	var head: float = - PI * 0.5 if kind == "sam" else (d.pos - start).angle()
	shots.append({"pos": start, "heading": head, "target": d, "life": 9.0, "kind": kind, "c": f.country_id, 
		"hit": roundi(float(sp["hit"]) * MSL_MUL), "speed": float(sp["speed"]), "id": _shot_id, "boost": 0.5 if kind == "sam" else 0.0})
	_shot_id += 1
	Sfx.play("sam_launch" if kind == "sam" else "drone_launch", start, 0.0 if kind == "sam" else -4.0)
	if gw._on_screen(start, 80.0):
		gw.fx.spawn("launch_cloud" if kind == "sam" else "dust_s", start.round(), 5)
	if f.kind == Facility.Kind.AD_SAM:
		f.lid_t = 1.2


func _update_shots(dt: float) -> void :
	for k in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[k]
		s["life"] = float(s["life"]) - dt
		var t: RDrone = s["target"]
		var pos: Vector2 = s["pos"]
		if t.dead or not t.airborne() or float(s["life"]) <= 0.0:
			gw.fx.spawn("intercept_flash", pos.round(), 6)
			shots.remove_at(k)
			continue
		var to: Vector2 = t.pos - pos
		var turn: float = PI * (3.0 if s["kind"] == "sam" else 2.0) * dt
		if float(s["boost"]) > 0.0:
			s["boost"] = float(s["boost"]) - dt
		else:
			s["heading"] = wrapf(float(s["heading"]) + clampf(wrapf(to.angle() - float(s["heading"]), - PI, PI), - turn, turn), - PI, PI)
		var step: float = float(s["speed"]) * dt
		if to.length() <= step + 3.0:
			gw.fx.spawn("intercept_flash", t.pos.round(), 6)
			Sfx.play("intercept_pop", t.pos)
			if Hash32.h2(int(s["id"]), t.id, 13) % 100 < int(s["hit"]):
				_kill(t, int(s["c"]))
			shots.remove_at(k)
			continue
		s["pos"] = pos + Vector2.from_angle(float(s["heading"])) * step
		if s["kind"] == "sam" and int(float(s["life"]) * 25.0) % 2 == 0:
			gw.fx.spawn("trail_s", (s["pos"] as Vector2).round(), 5)


func _kill(d: RDrone, by: int) -> void :
	if d.dead:
		return
	d.dead = true
	d.state = St.DONE
	lost += 1
	_vision_off(d)
	gw.fx.spawn("explosion_s", d.pos.round(), 6)
	gw.fx.debris_burst(d.pos.round(), 3, false, true)
	Sfx.play("intercept_pop", d.pos)
	var shooter: Country = gw.country_by_id(by)
	if shooter != null:
		shooter.destroyed += KILL_SCORE
	var c: Country = gw.country_by_id(d.country_id)
	if c != null and c.is_player:
		gw.say(c, Loc.mk("Разведдрон сбит у г. %s", [_place_name(d.pos)]))
	elif shooter != null and shooter.is_player:
		gw.say(shooter, Loc.mk("ПВО: сбит вражеский разведдрон"))






func _ai(dt: float) -> void :
	_ai_t += dt
	if _ai_t < AI_DT:
		return
	_ai_t = 0.0
	for c: Country in gw.countries:
		if c.is_player or c.at_war.is_empty() or c.capital_id < 0:
			continue
		if not active_for(c.id).is_empty():
			continue
		var caution: float = 0.5
		var aggr: float = 0.5
		if gw.ai != null and gw.ai.has_method("persona_of"):
			var P: Dictionary = gw.ai.persona_of(c)
			caution = float(P.get("caution", 0.5))
			aggr = float(P.get("aggr", 0.5))
		var p: float = 0.12 + 0.3 * caution + 0.15 * aggr
		if _rng.randf() >= p:
			continue
		ai_launch(c)




func ai_launch(c: Country) -> String:
	if c.money < AI_RESERVE:
		return Loc.t("МАЛО ДЕНЕГ")
	var ports: Array[Facility] = []
	for f: Facility in _ports(c.id):
		if _port_free(f):
			ports.append(f)
	if ports.is_empty():
		return Loc.t("НЕТ ДРОНОПОРТА")
	var cands: Array = []
	for f: Facility in gw.mil.facilities:
		if f.parent != null or f.is_line() or not c.at_war.has(f.country_id) or not gw.mil.alive(f):
			continue
		var w: int = 3 if (Defense.is_ad(f.kind) or f.kind in [Facility.Kind.TEL, Facility.Kind.BARRACKS, Facility.Kind.AIRFIELD, Facility.Kind.DRONE_PORT, Facility.Kind.MISSILE_FACTORY]) else 1
		cands.append([f.center_px(), w])
	for city: City in gw.cities:
		if c.at_war.has(city.country_id):
			cands.append([Vector2(city.center * GameWorld.CELL), 2])
	var pool: Array = []
	var tot: int = 0
	for e: Array in cands:
		for f: Facility in ports:
			if gw.mil.launch_point(f).distance_to(e[0]) <= RANGE:
				pool.append(e)
				tot += int(e[1])
				break
	if pool.is_empty():
		return Loc.t("НЕТ ЦЕЛЕЙ")
	var roll: int = _rng.randi_range(0, tot - 1)
	var pick: Vector2 = pool[0][0]
	for e: Array in pool:
		roll -= int(e[1])
		if roll < 0:
			pick = e[0]
			break
	pick += Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-40.0, 40.0))
	var port: Facility = port_for(c.id, pick)
	if port == null:
		return Loc.t("ДАЛЕКО")
	if c.has_res(COST):
		_pay(c, COST)
	elif c.money >= AI_COST_NO_METAL + AI_RESERVE:
		_pay(c, {"money": AI_COST_NO_METAL})
	else:
		return Loc.t("НЕ ХВАТАЕТ")
	return "" if _start(c, port, pick) != null else Loc.t("НЕТ ДРОНОПОРТА")








func save_state() -> Dictionary:
	var pr: Dictionary = {}
	for k: int in port_ready:
		pr[str(k)] = float(port_ready[k])
	var fl: Array = []
	for d: RDrone in drones:
		var e: Dictionary = {}
		for pn: String in _DRONE_F:
			var v: Variant = d.get(pn)
			e[pn] = v.duplicate() if v is Dictionary else v
		fl.append(e)
	var sh: Array = []
	for s: Dictionary in shots:
		var e2: Dictionary = s.duplicate()
		e2["target"] = (s["target"] as RDrone).id if s["target"] is RDrone else -1
		sh.append(e2)
	var adn: Dictionary = {}
	for k2: int in _ad_next:
		adn[str(k2)] = float(_ad_next[k2])
	return {"port_ready": pr, "launches": launches, "spent": spent, "lost": lost, "next_id": _next_id, "intel": _intel.duplicate(), "ai_t": _ai_t, 
		"flights": fl, "shots": sh, "shot_id": _shot_id, "ad_next": adn, "rng_seed": _rng.seed, "rng_state": _rng.state}



const _DRONE_F: Array = ["id", "country_id", "port_id", "state", "pos", "home", "target", "heading", "speed", "h", "frame", "t0", 
	"loiter_t", "loiter_a", "jam_t", "drift", "engaged", "dead", "why_back", "seen", "units_seen", "reported", "warned", "incidents", 
	"scan_t", "ew_t"]


func load_state(d: Dictionary) -> void :
	drones.clear()
	shots.clear()
	port_ready.clear()
	var pr: Dictionary = d.get("port_ready", {})
	for k in pr:
		port_ready[int(str(k))] = float(pr[k])
	launches = int(d.get("launches", 0))
	spent = int(d.get("spent", 0))
	lost = int(d.get("lost", 0))
	_next_id = maxi(1, int(d.get("next_id", 1)))
	_intel = (d.get("intel", {}) as Dictionary).duplicate()
	_ai_t = float(d.get("ai_t", 0.0))

	_ad_next.clear()
	var adn: Dictionary = d.get("ad_next", {})
	for k2 in adn:
		_ad_next[int(str(k2))] = float(adn[k2])
	_shot_id = maxi(1, int(d.get("shot_id", 1)))
	if d.has("rng_seed"):
		_rng.seed = int(d["rng_seed"])
		_rng.state = int(d["rng_state"])
	var by_id: Dictionary = {}
	for e: Variant in d.get("flights", []):
		if not (e is Dictionary):
			continue
		var rd: = RDrone.new()
		for pn: String in _DRONE_F:
			if (e as Dictionary).has(pn):
				var v: Variant = (e as Dictionary)[pn]
				rd.set(pn, (v as Dictionary).duplicate() if v is Dictionary else v)
		drones.append(rd)
		by_id[rd.id] = rd
	for e2: Variant in d.get("shots", []):
		if not (e2 is Dictionary) or not by_id.has(int((e2 as Dictionary).get("target", -1))):
			continue
		var s: Dictionary = (e2 as Dictionary).duplicate()
		s["target"] = by_id[int(s["target"])]
		shots.append(s)
	_ensure_layer()
