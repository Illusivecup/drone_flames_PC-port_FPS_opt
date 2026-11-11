class_name Air
extends RefCounted





const SPEC: Dictionary = {
	Aircraft.Type.BOMBER: {"name": "Бомбардировщик", "cost": 12000, "speed": 30.0, "turn": PI / 6.0, "fuel": 9000.0, "h": 12.0, "sprite": "bomber", "sel": 18}, 
	Aircraft.Type.FIGHTER: {"name": "Истребитель", "cost": 3000, "speed": 48.0, "turn": PI / 2.0, "fuel": 5000.0, "h": 10.0, "sprite": "fighter", "sel": 11}, 
	Aircraft.Type.HELI: {"name": "Вертолёт", "cost": 1800, "speed": 16.0, "turn": PI * 0.8, "fuel": 3600.0, "h": 6.0, "sprite": "heli", "sel": 11}, 
	Aircraft.Type.ATTACK: {"name": "Штурмовик", "cost": 5000, "speed": 40.0, "turn": PI / 2.2, "fuel": 4200.0, "h": 9.0, "sprite": "attack", "sel": 13}, 
}
const UPGRADE_COST: int = 1500
const FIGHTER_AAM: Array = [0, 2, 4, 6]
const BOMBER_CR: int = 30
const AIR_CAP: int = 6
const FUEL_PER_UNIT: float = 300.0
const SERVICE_TIME: float = 8.0
const RESERVE_PX: float = 500.0
const ORBIT_R: float = 40.0
const ROLL_ACC: float = 10.0
const LIFT_FRAC: float = 0.7
const CR_RANGE: float = 4000.0
const CR_SPEED: float = 40.0
const CR_GAP: float = 0.9
const CR_LINE_TOL: float = 0.2
const CR_LINE_MAX: float = 10.0
const CR_DROP: float = 0.7
const AAM_SPEED: float = 95.0
const AAM_RANGE: float = 260.0
const AAM_HIT: int = 85
const AAM_LIFE: float = 6.0
const GUN_R: float = 60.0
const GUN_CD: float = 0.6
const GUN_HIT: int = 40
const HELI_PATROL_R: float = 70.0
const TITANIUM: Dictionary = {Aircraft.Type.BOMBER: 60, Aircraft.Type.FIGHTER: 20, Aircraft.Type.HELI: 10, Aircraft.Type.ATTACK: 30}
const PYLON_N: Array = [0, 2, 1, 2]
const PYLON_MT: Array = [-1, 1, 4, 3]
const PYLON_NAMES: Array = ["ПУСТО", "2 КР", "ГИПЕРЗВУК", "2 КАБ"]
const HYPER_RANGE: float = 5000.0






const KAB_KIND: int = 3
const KAB_MAX: int = 6
const KAB_COST: int = 80
const KAB_METAL: int = 1
const KAB_STANDOFF: float = 360.0
const KAB_RANGE: float = 420.0
const ATTACK_KAB: int = 4
const ATTACK_NAR: int = 16
const ATTACK_AAM: int = 2
const NAR_COST: int = 5
const NAR_SPEED: float = 170.0
const NAR_R: float = 7.0
const NAR_DMG: float = 40.0
const NAR_SALVO: int = 2
const NAR_GAP: float = 0.45
const CAS_R: float = 90.0
const CAS_RUN: float = 150.0
const CAS_PASSES: int = 2
const ATK_GUN_R: float = 120.0
const ATK_GUN_CD: float = 0.3
const ATK_GUN_HIT: int = 45
const ATK_GUN_DMG: float = 18.0
const KAB_SPEED: float = 46.0
const KAB_SALVO: int = 2
const KAB_GAP: float = 1.5
const KAB_R_CELLS: int = 4
const KAB_R_PX: float = 18.0
const KAB_SCATTER: float = 6.0
const KAB_SCATTER_EW: float = 34.0
const KAB_AD_MULT: float = 0.4
const KAB_GUN_MULT: float = 0.2
const KAB_GUN_TRIES: int = 2
const BOMBER_AD_MULT: float = 0.6
const KAB_PATTERN: Array = [Vector2(0, 0), Vector2(9, 3), Vector2(-9, -3), Vector2(3, -9), Vector2(-3, 9), Vector2(0, 0)]
const KAB_AUTO_GAP: float = 35.0
const KAB_AUTO_SCAN: int = 24
const KAB_AI_GAP: float = 50.0
const KAB_FRONT_R: float = 1600.0
const KAB_SIGHT_R: float = 700.0
const KAB_TRAIL_STEP: float = 7.0
const AUTO_MIN_FUEL: float = 1500.0
const KAB_TRAIL_LIFE: float = 1.6

var gw: GameWorld
var mil: Military
var aircraft: Array[Aircraft] = []
var duel: AirDuel
var aams: Array = []
var tracers: Array = []
var _next_id: int = 1
var _aam_id: int = 1
var _scan_t: float = 0.0
var _cr_queue: Array = []
var kabs: Array[Drone] = []
var kab_trail: PackedVector2Array = PackedVector2Array()
var kab_trail_t: PackedFloat32Array = PackedFloat32Array()
var auto_kab: Dictionary = {}
var kab_next: Dictionary = {}
var kab_stats: Dictionary = {}
var _kab_t: float = 0.0
var recon_kills: int = 0
var recon_shots: int = 0
var kab_wait_msg: Dictionary = {}
var resumed: int = 0
var cr_next: Dictionary = {}
var cr_scrambles: int = 0
const AI_CR_GAP: float = 30.0
var ai_cr_next: Dictionary = {}
var ai_cr_stats: Dictionary = {}
var auto_why: Dictionary = {}
var arsenal_enabled: bool = false


func _init(world: GameWorld, m: Military) -> void :
	gw = world
	mil = m
	duel = AirDuel.new(self)


static func spec(type: int) -> Dictionary:
	return SPEC[type]


static func name_of(a: Aircraft) -> String:
	return Loc.t(String(SPEC[a.type]["name"]))


func count(country_id: int, type: int) -> int:
	var n: int = 0
	for a: Aircraft in aircraft:
		if a.country_id == country_id and a.type == type and a.state != Aircraft.State.DEAD:
			n += 1
	return n


func based_at(af: Facility) -> Array[Aircraft]:
	var out: Array[Aircraft] = []
	for a: Aircraft in aircraft:
		if a.base == af and a.state != Aircraft.State.DEAD:
			out.append(a)
	return out




func _o(af: Facility) -> Vector2:
	return af.origin_px()


func spot_pos(af: Facility, spot: int) -> Vector2:
	if spot < 0:
		return _o(af) + Vector2(30, 8)
	return _o(af) + Vector2(Military.AF_SPOTS[spot])


func _free_spot(af: Facility, bomber: bool) -> int:
	var used: Dictionary = {}
	for a: Aircraft in based_at(af):
		used[a.spot] = true
	if bomber:
		return -1 if not used.has(-1) else -2
	var n: int = 0
	for k in Military.AF_SPOTS.size():
		if used.has(k):
			n += 1
	if n >= AIR_CAP:
		return -2
	for k in Military.AF_SPOTS.size():
		if not used.has(k):
			return k
	return -2



func buy(af: Facility, type: int, country: Country) -> String:
	if af == null or af.kind != Facility.Kind.AIRFIELD or not mil.alive(af) or af.country_id != country.id:
		return Loc.t("Нужен целый аэродром")
	var cost: int = int(SPEC[type]["cost"])
	if country.money < cost:
		return Loc.t("Не хватает денег: нужно %d") % cost
	var rc: Dictionary = Economy.res_cost("aircraft_%d" % type)
	if not country.has_res(rc):
		return Loc.t("Не хватает: %s (рудник или торговля)") % country.missing_res(rc)
	var spot: int = _free_spot(af, type == Aircraft.Type.BOMBER)
	if spot == -2:
		return Loc.t("На аэродроме нет места")
	country.money -= cost
	country.pay_res(rc)
	gw.econ.stat_add(country, "spend", "aircraft", cost)
	for r: String in rc:
		gw.econ.stat_res(country, r, "aircraft", - int(rc[r]))
	var a: = Aircraft.new()
	a.id = _next_id
	_next_id += 1
	a.type = type
	a.country_id = country.id
	a.base = af
	a.spot = spot
	a.pos = spot_pos(af, spot)
	a.fuel = float(SPEC[type]["fuel"])
	a.service_t = SERVICE_TIME
	if type == Aircraft.Type.ATTACK:
		a.nar = ATTACK_NAR
	aircraft.append(a)
	gw.fx.spawn("build_spark", a.pos, 6)
	return ""


func upgrade(a: Aircraft, country: Country) -> String:
	if a.type != Aircraft.Type.FIGHTER or a.level >= 3:
		return Loc.t("Максимальный уровень")
	if a.state != Aircraft.State.PARKED:
		return Loc.t("Улучшение только на аэродроме")
	if country.money < UPGRADE_COST:
		return Loc.t("Не хватает денег: нужно %d") % UPGRADE_COST
	country.money -= UPGRADE_COST
	a.level += 1
	a.service_t = SERVICE_TIME
	return ""





func order_fly(a: Aircraft, p: Vector2) -> String:
	if a.state == Aircraft.State.DEAD:
		return Loc.t("Потерян")
	if a.state == Aircraft.State.PARKED and a.fuel < 600.0:
		return Loc.t("Мало топлива: идёт заправка")
	if a.state == Aircraft.State.PARKED and gw.econ != null and gw.econ.upk != null and gw.econ.upk.grounded(a):
		return Loc.t("На консервации: нет денег на содержание")
	a.resume = 0
	a.dest = p
	match a.state:
		Aircraft.State.PARKED:
			_take_off(a)
		Aircraft.State.TAXI, Aircraft.State.ROLL, Aircraft.State.LIFT:
			pass
		_:
			a.state = Aircraft.State.FLY
	return ""


func order_patrol(a: Aircraft, c: Vector2) -> String:
	if a.type != Aircraft.Type.HELI:
		return Loc.t("Патруль - только для вертолётов")
	var why: String = order_fly(a, c)
	if why != "":
		return why
	a.patrol_c = c
	if a.state == Aircraft.State.FLY:
		a.state = Aircraft.State.PATROL
	else:
		a.after_land = Aircraft.State.PATROL
	return ""


func order_land(a: Aircraft) -> void :
	if a.airborne() and a.state != Aircraft.State.LAND:
		a.state = Aircraft.State.RTB
		a.after_land = -1


func _take_off(a: Aircraft) -> void :
	a.service_t = 0.0
	if a.type == Aircraft.Type.HELI:
		a.state = Aircraft.State.LIFT
		return
	var o: Vector2 = _o(a.base)
	if a.spot < 0:
		a.taxi = [o + Vector2(Military.AF_START_X, Military.AF_ROLL_Y)]
	else:
		a.taxi = [Vector2(a.pos.x, o.y + Military.AF_TAXI_Y), o + Vector2(Military.AF_START_X, Military.AF_TAXI_Y), o + Vector2(Military.AF_START_X, Military.AF_ROLL_Y)]
	a.state = Aircraft.State.TAXI



func launch_cruise(a: Aircraft, target: Vector2, n: int) -> int:
	if a.type == Aircraft.Type.HELI or a.type == Aircraft.Type.ATTACK or not a.airborne():
		gw.message.emit(Loc.t("Пуск КР - только в воздухе") if a.type != Aircraft.Type.ATTACK else Loc.t("У штурмовика нет КР"))
		return 0
	var fighter: bool = a.type == Aircraft.Type.FIGHTER
	if not fighter and a.payload == 1:
		gw.message.emit(Loc.msg(Loc.mk("На бомбардировщике КАБ: смените загрузку на КР")))
		return 0
	if fighter and a.pylon != 1:
		gw.message.emit(Loc.msg(Loc.mk("На подвесе нет крылатых ракет")))
		return 0
	if a.pos.distance_to(target) > CR_RANGE:
		gw.message.emit(Loc.msg(Loc.mk("Цель дальше %.1f км", [CR_RANGE / 1000.0])))
		return 0
	if gw.diplo != null and gw.diplo.strike_block_at(a.country_id, target) != "":
		return 0
	var k: int = mini(n, a.pylon_n if fighter else a.missiles)
	if k <= 0:
		gw.message.emit(Loc.msg(Loc.mk("Нет крылатых ракет: нужен ракетный завод")))
		return 0
	if a.cr_pend <= 0:
		a.cr_aim = target
	for i in k:
		_cr_queue.append([gw.game_time + i * CR_GAP, a, target])
	a.cr_pend += k
	if fighter:
		a.pylon_n -= k
	else:
		a.missiles -= k
	return k



func launch_hyper(a: Aircraft, target: Vector2) -> bool:
	if a.type != Aircraft.Type.FIGHTER or not a.airborne():
		gw.message.emit(Loc.msg(Loc.mk("Пуск - только с истребителя в воздухе")))
		return false
	if a.pylon != 2 or a.pylon_n <= 0:
		gw.message.emit(Loc.msg(Loc.mk("На подвесе нет гиперзвуковой ракеты")))
		return false
	if a.pos.distance_to(target) > HYPER_RANGE:
		gw.message.emit(Loc.msg(Loc.mk("Цель дальше %.1f км", [HYPER_RANGE / 1000.0])))
		return false
	if gw.diplo != null and gw.diplo.strike_block_at(a.country_id, target) != "":
		return false
	a.pylon_n -= 1
	mil.launch_hyper(a.country_id, a.pos, target, a.h)
	return true



func set_pylon(a: Aircraft, p: int) -> String:
	if a.type != Aircraft.Type.FIGHTER:
		return Loc.t("Подвес - только у истребителя")
	if a.state != Aircraft.State.PARKED:
		return Loc.t("Смена подвеса только на аэродроме")
	if p < 0 or p >= PYLON_N.size() or (p == 3 and not arsenal_enabled):
		return Loc.t("Нет такого подвеса")
	var c: Country = gw.country_by_id(a.country_id)
	if a.pylon > 0 and a.pylon_n > 0:
		c.missile_stock[int(PYLON_MT[a.pylon])] += a.pylon_n
	a.pylon = p
	a.pylon_n = 0
	a.service_t = 1.0
	return ""


func _release_cruise(a: Aircraft, target: Vector2) -> void :
	if a.state == Aircraft.State.DEAD:
		return
	var d: = Drone.new()
	d.id = mil._next_drone_id
	mil._next_drone_id += 1
	d.kind = 1
	d.country_id = a.country_id
	d.state = Drone.State.FLY



	var side: float = 4.0 if a.cr_pend % 2 == 0 else -4.0
	d.pos = a.pos - Vector2.from_angle(a.heading) * 9.0 + Vector2.from_angle(a.heading + PI * 0.5) * side
	d.heading = a.heading
	d.speed = a.speed * 0.85
	d.h = a.h - 1.0
	d.boost_t = - CR_DROP
	d.cruise_speed = CR_SPEED
	d.turn_rate = PI * 0.5
	d.cruise_h = 3.0
	d.route = [target]
	d.target = target
	d.range_px = CR_RANGE + 600.0
	d.route_len = a.pos.distance_to(target)
	d.airfield = null
	mil.drones.append(d)




func update(dt: float) -> void :
	_update_kabs(dt)
	_kab_t += dt
	if _kab_t >= 2.0:
		_kab_t = 0.0
		_auto_kab_tick()
		_auto_cr_tick()
		if not cr_q.is_empty():
			_q_peace_drop()
		if not cr_q.is_empty():
			_q_tick()
	_release_tick()
	for a: Aircraft in aircraft:
		if a.state == Aircraft.State.DEAD:
			continue
		_step(a, dt)
		if a.auto_cr > 0:
			_auto_cr_step(a)
		if a.sortie > 0:
			_sortie(a)
		if a.cas > 0:
			_cas_step(a, dt)
		a.update_frame()
	_scan_t += dt
	if _scan_t >= 0.5:
		_scan_t = 0.0
		_engage()
		duel.scan()
		_heli_sound()
	_update_aams(dt)
	_update_nars(dt)
	var live_tracers: int = 0
	for k in range(tracers.size()):
		if gw.game_time <= float(tracers[k][2]):
			if live_tracers != k:
				tracers[live_tracers] = tracers[k]
			live_tracers += 1
	if live_tracers != tracers.size():
		tracers.resize(live_tracers)
	for k in range(aircraft.size() - 1, -1, -1):
		if aircraft[k].state == Aircraft.State.DEAD and gw.game_time > aircraft[k].service_t:
			aircraft.remove_at(k)






func _release_tick() -> void :
	var now: float = gw.game_time
	var done: Dictionary = {}
	var i: int = 0
	while i < _cr_queue.size():
		var q: Array = _cr_queue[i]
		var a: Aircraft = q[1]
		if a == null or a.state == Aircraft.State.DEAD or not a.airborne():
			_cr_queue.remove_at(i)
			if a != null:
				a.cr_pend = maxi(0, a.cr_pend - 1)
			continue
		if done.has(a) or now < float(q[0]):
			i += 1
			continue
		done[a] = true
		var tgt: Vector2 = q[2]
		var off: float = absf(wrapf((tgt - a.pos).angle() - a.heading, - PI, PI))
		if a.cr_aim != tgt:
			a.cr_aim = tgt
		if off > CR_LINE_TOL and now < float(q[0]) + CR_LINE_MAX:
			i += 1
			continue
		_release_cruise(a, tgt)
		_cr_queue.remove_at(i)
		a.cr_pend = maxi(0, a.cr_pend - 1)
		for e: Array in _cr_queue:
			if e[1] == a:
				e[0] = maxf(float(e[0]), now + CR_GAP)



func _heli_sound() -> void :
	var lp: Vector2 = Sfx.listener()
	var best: Vector2 = Vector2.INF
	var bd: float = INF
	if lp.is_finite():
		for a: Aircraft in aircraft:
			if a.type == Aircraft.Type.HELI and a.state != Aircraft.State.DEAD and a.airborne() and a.pos.distance_squared_to(lp) < bd:
				bd = a.pos.distance_squared_to(lp)
				best = a.pos
	Sfx.loop("heli", "heli_loop", best.is_finite(), best)


func _turn(a: Aircraft, want: float, rate: float) -> void :
	var diff: float = wrapf(want - a.heading, - PI, PI)
	a.heading = wrapf(a.heading + clampf(diff, - rate, rate), - PI, PI)


func _step(a: Aircraft, dt: float) -> void :
	var sp: Dictionary = SPEC[a.type]
	var vmax: float = float(sp["speed"])
	var turn: float = float(sp["turn"]) * dt
	var o: Vector2 = _o(a.base) if a.base != null else Vector2.ZERO
	match a.state:
		Aircraft.State.PARKED:
			_service(a, dt)
		Aircraft.State.TAXI:
			if a.taxi.is_empty():
				if a.after_land == 99:
					_parked(a)
					return
				a.state = Aircraft.State.ROLL
				a.speed = 0.0
				a.heading = 0.0
				gw.fx.spawn("dust_s", a.pos.round() - Vector2(8, 0), 5)
				return
			var to: Vector2 = a.taxi[0] - a.pos
			if to.length() < 0.3:
				a.pos = a.taxi[0]
				a.taxi.remove_at(0)
				return
			_turn(a, to.angle(), PI * dt)
			a.pos += to.normalized() * minf(10.0 * dt, to.length())
		Aircraft.State.ROLL:
			a.heading = 0.0
			a.speed = minf(a.speed + ROLL_ACC * dt, vmax)
			if a.speed > vmax * LIFT_FRAC:
				a.h = minf(a.h + 3.0 * dt, float(sp["h"]))
			a.pos.x += a.speed * dt
			if a.pos.x >= o.x + Military.AF_END_X:
				Sfx.play("jet_flyby", a.pos)
				a.state = Aircraft.State.FLY if a.after_land != Aircraft.State.PATROL else Aircraft.State.PATROL
				a.after_land = -1
		Aircraft.State.LIFT:
			a.h = minf(a.h + 3.0 * dt, float(sp["h"]))
			if a.h >= float(sp["h"]):
				a.state = Aircraft.State.FLY if a.after_land != Aircraft.State.PATROL else Aircraft.State.PATROL
				a.after_land = -1
		Aircraft.State.FLY, Aircraft.State.ORBIT, Aircraft.State.HOVER, Aircraft.State.PATROL, Aircraft.State.RTB:
			if not duel.steer(a, dt):
				_fly(a, dt, vmax, turn)
		Aircraft.State.LAND:
			_land(a, dt)


func _fly(a: Aircraft, dt: float, vmax: float, turn: float) -> void :
	var sp: Dictionary = SPEC[a.type]
	a.h = move_toward(a.h, float(sp["h"]), 3.0 * dt)
	var heli: bool = a.type == Aircraft.Type.HELI
	var tgt: Vector2 = a.dest
	if a.state == Aircraft.State.PATROL:
		a.patrol_ang += dt * vmax / HELI_PATROL_R
		tgt = a.patrol_c + Vector2.from_angle(a.patrol_ang) * HELI_PATROL_R
	elif a.state == Aircraft.State.RTB:
		tgt = spot_pos(a.base, a.spot) if heli else _o(a.base) + Vector2(-50.0, Military.AF_ROLL_Y)
	var to: Vector2 = tgt - a.pos
	var dist: float = to.length()

	var burn: float = maxf(a.speed, 6.0) * dt
	a.fuel -= burn
	if a.fuel <= 0.0:
		_shot_down(a, "кончилось топливо")
		return
	var home: float = a.pos.distance_to(spot_pos(a.base, a.spot))
	if a.state != Aircraft.State.RTB and a.fuel < home + RESERVE_PX:
		_mark_resume(a)
		a.state = Aircraft.State.RTB
		if gw.country_by_id(a.country_id).is_player:
			gw.say(gw.country_by_id(a.country_id), Loc.mk("%s %d: мало топлива, возврат на базу", [name_of(a), a.id]))
		return
	if a.state == Aircraft.State.RTB and dist < (6.0 if heli else 14.0):
		a.state = Aircraft.State.LAND
		return
	if heli:
		if a.state == Aircraft.State.FLY or a.state == Aircraft.State.HOVER:
			if dist < 3.0:
				a.state = Aircraft.State.HOVER
				a.speed = move_toward(a.speed, 0.0, 20.0 * dt)
				return
			a.state = Aircraft.State.FLY
		_turn(a, to.angle(), turn)
		a.speed = minf(vmax, dist * 2.0)
		a.pos += to / maxf(dist, 0.001) * minf(a.speed * dt, dist)
		return

	if a.state == Aircraft.State.FLY and dist < ORBIT_R:
		a.state = Aircraft.State.ORBIT
	var want: float = to.angle()
	if a.cr_pend > 0 and a.state != Aircraft.State.LAND:


		want = (a.cr_aim - a.pos).angle()
		_turn_soft(a, want, turn, dt)
		a.speed = move_toward(a.speed, vmax * 0.9, 6.0 * dt)
		a.pos += Vector2.from_angle(a.heading) * a.speed * dt
		return
	if a.state == Aircraft.State.ORBIT:
		var tang: float = (a.pos - tgt).angle() + PI * 0.5
		var radial: float = (dist - ORBIT_R) / ORBIT_R
		want = tang + clampf(radial, -0.8, 0.8)
		_turn_soft(a, want, turn * 1.5, dt)
	else:
		if a.cas == 2:
			want = _cas_line(a)

		_turn_soft(a, want, turn * (2.2 if a.state == Aircraft.State.RTB and a.kab_rel_t > gw.game_time - 8.0 else 1.0), dt)

	var hard: bool = absf(wrapf(want - a.heading, - PI, PI)) > 0.7
	a.speed = move_toward(a.speed, vmax * (TURN_SLOW if hard else 1.0), (6.0 if hard else 10.0) * dt)
	a.pos += Vector2.from_angle(a.heading) * a.speed * dt




const TURN_EASE: float = 2.6
const TURN_SLOW: float = 0.85
const CAS_LEAD: float = 70.0
func _turn_soft(a: Aircraft, want: float, rate: float, dt: float) -> void :
	var diff: float = wrapf(want - a.heading, - PI, PI)
	var r: float = minf(rate, maxf(absf(diff) * TURN_EASE * dt, rate * 0.2))
	a.heading = wrapf(a.heading + clampf(diff, - r, r), - PI, PI)




func _cas_line(a: Aircraft) -> float:
	var s: float = (a.pos - a.cas_p).dot(a.cas_dir)
	var aim: Vector2 = a.cas_p + a.cas_dir * (s + CAS_LEAD)
	return (aim - a.pos).angle()


func _land(a: Aircraft, dt: float) -> void :
	if a.type == Aircraft.Type.HELI:
		var to: Vector2 = spot_pos(a.base, a.spot) - a.pos
		a.pos += to.limit_length(8.0 * dt)
		a.h = maxf(0.0, a.h - 3.0 * dt)
		if a.h <= 0.0:
			_parked(a)
		return

	var o: Vector2 = _o(a.base)
	_turn(a, (Vector2(o.x + 70.0, o.y + Military.AF_ROLL_Y) - a.pos).angle(), PI * dt)
	a.speed = move_toward(a.speed, 14.0, 8.0 * dt)
	a.pos += Vector2.from_angle(a.heading) * a.speed * dt
	a.h = maxf(0.0, a.h - 4.0 * dt)
	if a.h <= 0.0 and a.pos.x >= o.x + 60.0:
		a.pos.y = o.y + Military.AF_ROLL_Y
		var sp: Vector2 = spot_pos(a.base, a.spot)
		if a.spot < 0:
			a.taxi = [sp]
		else:
			a.taxi = [Vector2(a.pos.x, o.y + Military.AF_TAXI_Y), Vector2(sp.x, o.y + Military.AF_TAXI_Y), sp]
		a.state = Aircraft.State.TAXI
		a.after_land = 99


func _parked(a: Aircraft) -> void :
	a.state = Aircraft.State.PARKED
	a.h = 0.0
	a.speed = 0.0
	a.pos = spot_pos(a.base, a.spot)
	a.heading = 0.0
	a.service_t = SERVICE_TIME
	a.after_land = -1



func _service(a: Aircraft, dt: float) -> void :
	a.flares_used = 0
	if a.service_t > 0.0:
		a.service_t -= dt
		return
	var c: Country = gw.country_by_id(a.country_id)
	var fmax: float = float(SPEC[a.type]["fuel"])
	if a.fuel < fmax - 1.0 and c.fuel > 0:
		var units: int = mini(c.fuel, int(ceil((fmax - a.fuel) / FUEL_PER_UNIT)))
		c.fuel -= units
		gw.econ.stat_res(c, "fuel", "aircraft", - units)
		a.fuel = minf(fmax, a.fuel + units * FUEL_PER_UNIT)
	if a.type == Aircraft.Type.ATTACK:
		_rearm_attack(a, c)
	elif a.type == Aircraft.Type.BOMBER and a.missiles < BOMBER_CR:
		var k: int = mini(BOMBER_CR - a.missiles, c.missile_stock[Military.MT_CRUISE])
		c.missile_stock[Military.MT_CRUISE] -= k
		a.missiles += k
	elif a.type == Aircraft.Type.FIGHTER and a.missiles < int(FIGHTER_AAM[a.level]):
		var k2: int = mini(int(FIGHTER_AAM[a.level]) - a.missiles, c.missile_stock[Military.MT_AA])
		c.missile_stock[Military.MT_AA] -= k2
		a.missiles += k2
	if a.type == Aircraft.Type.FIGHTER and a.pylon > 0 and a.pylon_n < int(PYLON_N[a.pylon]):
		var mt: int = int(PYLON_MT[a.pylon])
		var k3: int = mini(int(PYLON_N[a.pylon]) - a.pylon_n, c.missile_stock[mt])
		c.missile_stock[mt] -= k3
		a.pylon_n += k3

	if a.resume > 0 and a.fuel >= fmax * 0.95 and (a.type != Aircraft.Type.FIGHTER\
	or a.missiles >= int(FIGHTER_AAM[a.level]) or c.missile_stock[Military.MT_AA] <= 0):
		var r: int = a.resume
		var why: String = order_patrol(a, a.resume_p) if r == 2 else order_fly(a, a.resume_p)
		if why == "":
			resumed += 1
			return
		a.resume = r
	a.service_t = 1.0



func _mark_resume(a: Aircraft) -> void :
	if a.sortie > 0 or a.auto_cr > 0 or a.cas > 0 or a.type == Aircraft.Type.BOMBER:
		return
	if a.state == Aircraft.State.PATROL:
		a.resume = 2
		a.resume_p = a.patrol_c
	elif a.state == Aircraft.State.ORBIT or a.state == Aircraft.State.FLY or a.state == Aircraft.State.HOVER:
		a.resume = 1
		a.resume_p = a.dest





func _air_targets(country_id: int, p: Vector2, r: float, low_only: bool) -> Array:
	var out: Array = []
	for d: Drone in mil.drones:
		if d.airborne() and mil.hostile(country_id, d.country_id) and d.pos.distance_to(p) <= r:
			out.append(d)
	if not low_only:
		for a: Aircraft in aircraft:
			if a.airborne() and a.state != Aircraft.State.DEAD and mil.hostile(country_id, a.country_id) and a.pos.distance_to(p) <= r:
				out.append(a)
	return out


func _targeted(t: Object) -> bool:
	for m: Dictionary in aams:
		if m["target"] == t:
			return true
	return false


func _engage() -> void :
	for a: Aircraft in aircraft:
		if not a.airborne() or a.state == Aircraft.State.DEAD:
			continue
		if a.type == Aircraft.Type.ATTACK:
			if a.missiles > 0:
				_engage_fighter(a)
		elif a.type == Aircraft.Type.FIGHTER and a.missiles > 0:
			_engage_fighter(a)
			if a.missiles <= 0 and a.pylon_n <= 0 and a.state != Aircraft.State.RTB and a.state != Aircraft.State.LAND:
				_mark_resume(a)
				if a.resume > 0:
					a.state = Aircraft.State.RTB
					if gw.country_by_id(a.country_id).is_player:
						gw.say(gw.country_by_id(a.country_id), Loc.mk("%s %d: ракеты кончились, перезарядка", [name_of(a), a.id]))
		elif a.type == Aircraft.Type.HELI:
			_engage_heli(a)


func _engage_fighter(a: Aircraft) -> void :
	for t: Object in _air_targets(a.country_id, a.pos, AAM_RANGE, false):
		if a.missiles <= 0:
			break
		if _targeted(t) or not duel.can_shoot(a, t):
			continue
		a.missiles -= 1
		aams.append({"pos": a.pos, "heading": a.heading, "target": t, "life": AAM_LIFE, "id": _aam_id, "c": a.country_id})
		_aam_id += 1
		gw.fx.spawn("trail_s", a.pos.round(), 5)
		Sfx.play("sam_launch", a.pos, -4.0)

	for rt: Object in _recon_targets(a.country_id, a.pos, AAM_RANGE):
		if a.missiles <= 0 or a.state == Aircraft.State.LAND:
			break
		if _targeted(rt):
			continue
		a.missiles -= 1
		aams.append({"pos": a.pos, "heading": a.heading, "target": rt, "life": AAM_LIFE, "id": _aam_id, "c": a.country_id})
		recon_shots += 1
		var rdv: Recon.RDrone = rt as Recon.RDrone
		if rdv.state < Recon.St.BACK:
			gw.recon._go_back(rdv, "interceptor")
		_aam_id += 1
		gw.fx.spawn("trail_s", a.pos.round(), 5)
		Sfx.play("sam_launch", a.pos, -4.0)


func _engage_heli(a: Aircraft) -> void :
	a.fire_cd -= 0.5
	if a.fire_cd > 0.0:
		return
	var ts: Array = _air_targets(a.country_id, a.pos, GUN_R, true)
	if ts.is_empty():

		var rts: Array = _recon_targets(a.country_id, a.pos, GUN_R)
		if not rts.is_empty():
			var rd: Object = rts[0]
			a.fire_cd = GUN_CD
			tracers.append([a.pos, rd.get("pos"), gw.game_time + 0.15])
			Sfx.play("mg_burst", a.pos)
			recon_shots += 1
			if Hash32.h2(a.id, int(gw.game_time * 10.0), 37) % 100 < roundi(GUN_HIT * Recon.GUN_MUL):
				_kill_recon(rd, a.country_id)
		return
	var d: Drone = ts[0]
	a.fire_cd = GUN_CD
	tracers.append([a.pos, d.pos, gw.game_time + 0.15])
	Sfx.play("mg_burst", a.pos)
	if Hash32.h2(a.id, int(gw.game_time * 10.0), 33) % 100 < GUN_HIT:
		_kill_drone(d, DroneBrain.BY_POINT)


func _update_aams(dt: float) -> void :
	for k in range(aams.size() - 1, -1, -1):
		var m: Dictionary = aams[k]
		m["life"] = float(m["life"]) - dt
		var t: Object = m["target"]
		var tp: Vector2 = Vector2.INF
		if t is Drone and (t as Drone).state != Drone.State.DONE:
			tp = (t as Drone).pos
		elif t is Aircraft and (t as Aircraft).state != Aircraft.State.DEAD:
			tp = (t as Aircraft).pos
		elif t is Recon.RDrone and (t as Recon.RDrone).airborne():
			tp = (t as Recon.RDrone).pos
		var pos: Vector2 = m["pos"]
		if m.has("dp"):
			tp = m["dp"]
		elif t is Aircraft and tp != Vector2.INF and not m.has("fl") and pos.distance_to(tp) <= FLARE_R:
			m["fl"] = 1
			if flare_try(t as Aircraft):
				m["dp"] = flare_point(t as Aircraft)
				tp = m["dp"]
		if tp == Vector2.INF or float(m["life"]) <= 0.0:
			gw.fx.spawn("explosion_s", pos.round(), 6)
			Sfx.play("intercept_pop", pos, -6.0)
			aams.remove_at(k)
			continue
		var to: Vector2 = tp - pos
		var want: float = to.angle()
		m["heading"] = wrapf(float(m["heading"]) + clampf(wrapf(want - float(m["heading"]), - PI, PI), - PI * 2.0 * dt, PI * 2.0 * dt), - PI, PI)
		var step: float = AAM_SPEED * dt
		if to.length() <= step + 2.0:
			gw.fx.spawn("explosion_s", tp.round(), 6)
			Sfx.play("intercept_pop", tp)
			if not m.has("dp") and Hash32.h2(int(m["id"]), 5, 71) % 100 < (roundi(AAM_HIT * Recon.MSL_MUL) if t is Recon.RDrone else duel.aam_hit(t, m)):
				if t is Drone:
					_kill_drone(t as Drone, DroneBrain.BY_AIR)
				elif t is Recon.RDrone:
					_kill_recon(t, int(m["c"]))
				else:
					_shot_down(t as Aircraft, "сбит")
			aams.remove_at(k)
			continue
		m["pos"] = pos + Vector2.from_angle(float(m["heading"])) * step
		if int(m["life"] * 20.0) % 2 == 0:
			gw.fx.spawn("trail_s", (m["pos"] as Vector2).round(), 5)



func _recon_targets(country_id: int, p: Vector2, r: float) -> Array:
	var out: Array = []
	var rc: Variant = gw.get("recon")
	if rc == null:
		return out
	for d: Recon.RDrone in (rc as Recon).drones:
		if d.airborne() and mil.hostile(country_id, d.country_id) and d.pos.distance_squared_to(p) <= r * r:
			out.append(d)
	return out



func _kill_recon(t: Object, by: int) -> void :
	var d: Recon.RDrone = t as Recon.RDrone
	if d == null or d.dead:
		return
	recon_kills += 1
	gw.recon._kill(d, by)


func _kill_drone(d: Drone, by: int = -1) -> void :
	if d.state == Drone.State.DONE:
		return
	d.state = Drone.State.DONE
	d.end_reason = Drone.End.DESTROYED
	if gw.battle_watch != null:
		gw.battle_watch.note(d.pos, 2.0, "Перехват", d.country_id)
	gw.fx.spawn("explosion_s", d.pos.round(), 6)
	gw.fx.debris_burst(d.pos.round(), 3, false, true)
	Sfx.play("intercept_pop", d.pos)
	if gw.aftermath != null and d.kind != KAB_KIND and d.airborne():
		gw.aftermath.air.drone(d, by)
	if d.kind == KAB_KIND:
		kab_gun_tries.erase(d.id)
		_kab_stat(d.country_id, 2)
		return
	if mil.brain != null:
		mil.brain.note_loss(d, by if by >= 0 else mil.brain.infer_killer(d))
	if gw.country_by_id(d.country_id).is_player:
		gw.say(gw.country_by_id(d.country_id), Loc.mk("%s сбит", [Loc.t("КР") if d.kind == 1 else Loc.t("БПЛА %d") % d.id]))


func _shot_down(a: Aircraft, why: String) -> void :
	if a.state == Aircraft.State.DEAD:
		return
	a.state = Aircraft.State.DEAD
	a.service_t = gw.game_time + 0.1
	_q_unbook(a)
	if gw.battle_watch != null:
		gw.battle_watch.note(a.pos, 3.0, "Воздушный бой", a.country_id)
	gw.fx.spawn("explosion_m", a.pos.round(), 6)
	Sfx.play("expl_big", a.pos, -3.0)
	gw.fx.debris_burst(a.pos.round(), 5, false)
	if gw.aftermath != null:
		gw.aftermath.air.plane(a)
	if gw.country_by_id(a.country_id).is_player:
		gw.say(gw.country_by_id(a.country_id), Loc.mk("%s %d потерян: %s", [name_of(a), a.id, Loc.mk(why)]))



func on_strike(p: Vector2, r_px: float) -> void :
	for a: Aircraft in aircraft:
		if a.state != Aircraft.State.DEAD and not a.airborne() and a.pos.distance_to(p) <= r_px + 6.0:
			_shot_down(a, "уничтожен на земле")






func set_payload(a: Aircraft, p: int) -> String:
	if a == null or a.type != Aircraft.Type.BOMBER:
		return Loc.t("Загрузка - только у бомбардировщика")
	if a.state != Aircraft.State.PARKED:
		return Loc.t("Смена загрузки только на аэродроме")
	if p == 1:
		return Loc.t("КАБ теперь несёт штурмовик")
	p = clampi(p, 0, 1)
	if a.payload == p:
		return ""
	var c: Country = gw.country_by_id(a.country_id)
	if a.payload == 0 and a.missiles > 0 and c != null:
		c.missile_stock[Military.MT_CRUISE] += a.missiles
		a.missiles = 0
	if a.payload == 1 and a.kab > 0 and c != null:

		var back: int = a.kab * KAB_COST
		c.money += back
		c.metal += a.kab * KAB_METAL
		gw.econ.stat_add(c, "spend", "aircraft", - back)
		gw.econ.stat_res(c, "metal", "aircraft", a.kab * KAB_METAL)
		if c.is_player:
			gw.say(c, Loc.mk("КАБ сняты (%d): +%d, металл +%d", [a.kab, back, a.kab * KAB_METAL]))
		a.kab = 0
	a.payload = p
	a.service_t = 1.0
	return ""


static func payload_name(a: Aircraft) -> String:
	return Loc.t("КАБ") if a.payload == 1 else Loc.t("КР")




func launch_kab(a: Aircraft, target: Vector2, n: int) -> int:
	return _launch_kab(a, target, n, false)


func _launch_kab(a: Aircraft, target: Vector2, n: int, auto: bool) -> int:
	var c: Country = gw.country_by_id(a.country_id) if a != null else null
	var rel: Vector2 = _release_point(a.pos, target) if a != null else target
	var why: String = _kab_why(a, target, rel) if a != null else Loc.t("Нет самолёта")
	if why == "" and n <= 0:
		why = Loc.t("Нет КАБ")
	if why != "":
		if c != null and c.is_player and not auto:
			gw.say(c, why)
		return 0
	var k: int = mini(n, _kab_payload(a))
	a.kab_q.clear()
	for i in k:
		a.kab_q.append(target)
	a.cas = 0
	a.sortie = 1
	a.sortie_target = target
	a.sortie_release = rel
	a.sortie_n = k
	a.sortie_i = 0
	a.sortie_auto = auto
	if a.state == Aircraft.State.PARKED:
		order_fly(a, rel)
	else:
		a.dest = rel
		if a.airborne():
			a.state = Aircraft.State.FLY
	if c != null and c.is_player and not auto:
		gw.say(c, Loc.mk("КАБ: вылет, %d шт., до точки сброса %.1f км", [k, a.pos.distance_to(rel) / 1000.0]))
	return k



func _release_point(from: Vector2, target: Vector2) -> Vector2:
	var d: float = from.distance_to(target)
	if d <= KAB_STANDOFF:
		return from
	return target + (from - target) / d * KAB_STANDOFF



func _kab_reach(a: Aircraft) -> float:
	var home: Vector2 = spot_pos(a.base, a.spot) if a.base != null else a.pos
	var back: float = a.pos.distance_to(home)
	return maxf(0.0, (a.fuel - RESERVE_PX - 120.0 - back) * 0.5) + KAB_STANDOFF


func _kab_why(a: Aircraft, target: Vector2, rel: Vector2) -> String:
	if a == null or a.state == Aircraft.State.DEAD:
		return Loc.t("Самолёт потерян")
	if gw.diplo != null and gw.diplo.strike_block_at(a.country_id, target, false) != "":
		return Diplomacy.STRIKE_BLOCK_TXT
	if a.type != Aircraft.Type.ATTACK and not (a.type == Aircraft.Type.FIGHTER and a.pylon == 3 and arsenal_enabled):
		return Loc.t("КАБ — нужен штурмовик или истребитель с подвесом КАБ")
	if _kab_payload(a) <= 0:
		return Loc.t("Нет КАБ: идёт снаряжение на аэродроме") if a.state == Aircraft.State.PARKED else Loc.t("КАБ кончились")
	if a.state == Aircraft.State.LAND or (a.state == Aircraft.State.TAXI and a.after_land == 99):
		return Loc.t("Штурмовик заходит на посадку")
	if a.sortie > 0 and a.sortie_n > 0 and a.sortie == 2:
		return Loc.t("Идёт сброс")
	if a.state == Aircraft.State.PARKED and a.fuel < 600.0:
		return Loc.t("Мало топлива: идёт заправка")
	var home: Vector2 = spot_pos(a.base, a.spot) if a.base != null else a.pos
	var need: float = a.pos.distance_to(rel) + rel.distance_to(home) + RESERVE_PX + 120.0
	if need > a.fuel:
		if a.state == Aircraft.State.PARKED and need <= float(SPEC[a.type]["fuel"]):
			return Loc.t("Не хватает топлива: идёт заправка")
		return Loc.t("Цель слишком далеко: топлива на %.1f км") % (_kab_reach(a) / 1000.0)
	return ""




func _kab_risk(country_id: int, rel: Vector2, target: Vector2, ui: bool = true) -> Array:
	var c: Country = gw.country_by_id(country_id)
	var v: Vision = gw.vision
	var fog: bool = ui and c != null and c.is_player and v != null and v.active()
	var radar_on_rel: bool = false
	var sams: Array = []
	var at_tgt: int = 0
	var ew: bool = false
	for f: Facility in mil.facilities:
		var k: int = f.kind
		if k != Facility.Kind.AD_SAM and k != Facility.Kind.AD_PATRIOT and k != Facility.Kind.AD_SPAAG and k != Facility.Kind.AD_INT\
		and k != Facility.Kind.AD_RADAR and k != Facility.Kind.AD_EW:
			continue
		if not mil.hostile(country_id, f.country_id):
			continue
		var p: Vector2 = f.center_px()
		if fog:
			if not v.known(f) or (v.fac_shown(f) and not mil.alive(f)):
				continue
			p = v.last_pos(f)
		elif not mil.alive(f):
			continue
		if k == Facility.Kind.AD_RADAR:
			if p.distance_to(rel) <= Defense.RADAR_R:
				radar_on_rel = true
			continue
		if k == Facility.Kind.AD_EW:
			if p.distance_to(target) <= Defense.EW_R + 20.0:
				ew = true
			continue
		var sp: Dictionary = Defense.SPEC[k]
		if int(sp["mask"]) & Defense.T_JET and p.distance_to(rel) <= float(sp["range"]) + ORBIT_R:
			sams.append([p, float(sp["range"]), float(sp["detect"])])
		if p.distance_to(target) <= float(sp["range"]):
			at_tgt += 1
	var lvl: int = 0
	for s: Array in sams:
		lvl = maxi(lvl, 2 if radar_on_rel or (s[0] as Vector2).distance_to(rel) <= float(s[2]) + ORBIT_R else 1)
	var parts: PackedStringArray = []
	parts.append([Loc.t("РИСК НИЗКИЙ"), Loc.t("РИСК СРЕДНИЙ: ЗРК рядом, без РЛС"), Loc.t("РИСК ВЫСОКИЙ: ЗРК и РЛС у точки сброса")][lvl])
	if at_tgt > 0:
		parts.append(Loc.t("ПВО у цели: %d") % at_tgt)
	if ew:
		parts.append(Loc.t("РЭБ: разброс"))
	if fog:
		parts.append(Loc.t("по разведданным"))
	return [lvl, ", ".join(parts)]


func _kab_stat(country_id: int, i: int) -> void :
	var e: Array = kab_stats.get(country_id, [0, 0, 0])
	e[i] = int(e[i]) + 1
	kab_stats[country_id] = e




func _rearm_attack(a: Aircraft, c: Country) -> void :
	if c == null:
		return
	if a.kab < ATTACK_KAB and c.missile_stock[Military.MT_KAB] > 0:
		var k: int = mini(ATTACK_KAB - a.kab, c.missile_stock[Military.MT_KAB])
		c.missile_stock[Military.MT_KAB] -= k
		a.kab += k
	if a.nar < ATTACK_NAR:
		var n: int = mini(ATTACK_NAR - a.nar, c.money / NAR_COST)
		c.money -= n * NAR_COST
		a.nar += n
	if a.missiles < ATTACK_AAM and c.missile_stock[Military.MT_AA] > 0:
		var m: int = mini(ATTACK_AAM - a.missiles, c.missile_stock[Military.MT_AA])
		c.missile_stock[Military.MT_AA] -= m
		a.missiles += m




func _sortie(a: Aircraft) -> void :
	if a.state == Aircraft.State.DEAD:
		a.sortie = 0
		return
	var going_home: bool = a.state == Aircraft.State.RTB or a.state == Aircraft.State.LAND
	if a.sortie == 1:
		if going_home or (a.airborne() and a.dest != a.sortie_release):
			a.sortie = 0
			a.kab_q.clear()
			if gw.country_by_id(a.country_id).is_player and not going_home:
				gw.say(gw.country_by_id(a.country_id), Loc.mk("%s %d: удар КАБ отменён", [name_of(a), a.id]))
			return
		if not a.airborne() or a.kab_q.is_empty():
			return
		if a.pos.distance_to(a.kab_q[0]) <= KAB_RANGE:
			if gw.hold != null and not gw.country_by_id(a.country_id).is_player and int(gw.hold.hold_aim(a.country_id, a.kab_q[0])) == 0:
				a.sortie = 0
				a.kab_q.clear()
				order_land(a)
				return
			a.sortie = 2
			a.kab_rel_t = maxf(a.kab_rel_t, gw.game_time)
		return
	if going_home:
		a.sortie = 0
		a.kab_q.clear()
		return
	if gw.game_time < a.kab_rel_t:
		return
	if not a.kab_q.is_empty() and _kab_payload(a) > 0:
		var t: Vector2 = a.kab_q[0]
		if a.pos.distance_to(t) > KAB_RANGE + 10.0:
			a.sortie = 1
			a.sortie_release = _release_point(a.pos, t)
			a.dest = a.sortie_release
			a.state = Aircraft.State.FLY
			return
		a.sortie_target = t
		_release_kab(a, a.sortie_i)
		a.sortie_i += 1
		a.sortie_n -= 1
		a.kab_q.remove_at(0)
		a.kab_rel_t = gw.game_time + KAB_GAP
		Sfx.play("jet_flyby", a.pos, -6.0)
	if a.kab_q.is_empty() or _kab_payload(a) <= 0:
		a.sortie = 0
		a.kab_q.clear()
		order_land(a)
		if gw.country_by_id(a.country_id).is_player:
			gw.say(gw.country_by_id(a.country_id), Loc.mk("%s %d: КАБ сброшены (%d), возврат на базу", [name_of(a), a.id, a.sortie_i]))


func _release_kab(a: Aircraft, idx: int) -> void :
	var tgt: Vector2 = a.sortie_target
	var hs: int = absi(Hash32.h2(a.id * 37 + idx, int(gw.game_time * 10.0), 913))
	var sc: float = KAB_SCATTER_EW if _ew_at(a.country_id, tgt) else KAB_SCATTER
	var aim: Vector2 = tgt + Vector2(KAB_PATTERN[idx % KAB_PATTERN.size()]) + Vector2.from_angle(float(hs % 3600) * TAU / 3600.0) * sc * sqrt(float((hs >> 12) % 1000) / 1000.0)
	var d: = Drone.new()
	d.id = mil._next_drone_id
	mil._next_drone_id += 1
	d.kind = KAB_KIND
	d.country_id = a.country_id
	d.state = Drone.State.FLY
	d.pos = a.pos + Vector2.from_angle(a.heading + PI * 0.5) * (3.0 if idx % 2 == 0 else -3.0)
	d.heading = (aim - d.pos).angle()
	d.speed = KAB_SPEED
	d.cruise_speed = KAB_SPEED
	d.h = maxf(2.0, a.h - 1.0)
	d.dive_h0 = d.h
	d.cruise_h = d.h
	d.target = aim
	d.route = [aim]
	d.route_len = maxf(1.0, d.pos.distance_to(aim))
	d.range_px = d.route_len + 60.0
	d.update_frame()
	kabs.append(d)
	_consume_kab(a)
	_kab_stat(a.country_id, 0)


func _kab_payload(a: Aircraft) -> int:
	if a == null:
		return 0
	if a.type == Aircraft.Type.FIGHTER and a.pylon == 3 and arsenal_enabled:
		return a.pylon_n
	return a.kab if a.type == Aircraft.Type.ATTACK else 0


func _consume_kab(a: Aircraft) -> void:
	if a.type == Aircraft.Type.FIGHTER and a.pylon == 3 and arsenal_enabled:
		a.pylon_n = maxi(0, a.pylon_n - 1)
	else:
		a.kab = maxi(0, a.kab - 1)



func _ew_at(country_id: int, p: Vector2) -> bool:
	for f: Facility in mil.facilities:
		if f.kind == Facility.Kind.AD_EW and mil.alive(f) and mil.hostile(f.country_id, country_id) and mil.has_power(f)\
		and f.center_px().distance_squared_to(p) <= (Defense.EW_R + 20.0) * (Defense.EW_R + 20.0):
			return true
	return false


func _update_kabs(dt: float) -> void :
	var drop: int = 0
	while drop < kab_trail_t.size() and gw.game_time - kab_trail_t[drop] > KAB_TRAIL_LIFE:
		drop += 1
	if drop > 0:
		kab_trail = kab_trail.slice(drop)
		kab_trail_t = kab_trail_t.slice(drop)
	for k in range(kabs.size() - 1, -1, -1):
		var d: Drone = kabs[k]
		if d.state == Drone.State.DONE:
			kabs.remove_at(k)
			continue
		var to: Vector2 = d.target - d.pos
		var dist: float = to.length()
		var step: float = d.speed * dt
		if dist <= step + 0.5:
			kabs.remove_at(k)
			_kab_impact(d)
			continue
		d.heading = to.angle()
		d.pos += to / dist * step
		d.flown += step
		d.h = d.dive_h0 * clampf((dist - step) / d.route_len, 0.0, 1.0)
		d.update_frame()
		d.trail_acc += step
		if d.trail_acc >= KAB_TRAIL_STEP:
			d.trail_acc = 0.0
			kab_trail.append(d.pos.round())
			kab_trail_t.append(gw.game_time)
		if not d.lifted and (dist - step) / d.speed < 1.8:
			d.lifted = true


func _kab_impact(d: Drone) -> void :
	kab_gun_tries.erase(d.id)
	d.state = Drone.State.DONE
	d.end_reason = Drone.End.HIT
	d.h = 0.0
	var p: Vector2 = d.target
	d.pos = p
	_kab_stat(d.country_id, 1)
	var cell: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	gw.fx.spawn("explosion_m", p.round(), 6)
	gw.fx.debris_burst(p.round(), 6, false)
	Sfx.play("expl_big", p, -4.0)
	if gw.camera != null and gw._on_screen(p, 100.0):
		gw.camera.shake(true)
	if gw.protect != null:
		gw.protect.on_impact(p, Protect.HIT_KAB, d.country_id)
	gw._delay(0.12, gw._apply_strike.bind(cell, KAB_R_CELLS, "crater_m", KAB_R_PX, d.country_id))
	if gw.vfx != null:
		gw.vfx.on_impact(p, 1)
	if gw.battle_watch != null:
		gw.battle_watch.impact(p, "Удар КАБ", d.country_id)








const FLARE_N: Dictionary = {Aircraft.Type.BOMBER: 3, Aircraft.Type.FIGHTER: 2, Aircraft.Type.HELI: 2, Aircraft.Type.ATTACK: 3}
const FLARE_DECOY: Dictionary = {Aircraft.Type.BOMBER: 25, Aircraft.Type.FIGHTER: 35, Aircraft.Type.HELI: 30, Aircraft.Type.ATTACK: 35}
const FLARE_R: float = 40.0
static var flare_fx: Array = []
var flare_stats: Array = [0, 0]



func flare_try(a: Aircraft) -> bool:
	if a.state == Aircraft.State.DEAD or not a.airborne() or a.flares_used >= int(FLARE_N.get(a.type, 0)):
		return false
	a.flares_used += 1
	flare_stats[0] = int(flare_stats[0]) + 1
	for k in range(flare_fx.size() - 1, -1, -1):
		if FxLayer.vt - float(flare_fx[k][2]) > 2.0 or FxLayer.vt < float(flare_fx[k][2]):
			flare_fx.remove_at(k)
	if flare_fx.size() < 24:
		flare_fx.append([a.pos, a.heading, FxLayer.vt])
	if a.type != Aircraft.Type.BOMBER or flare_stats[0] %2 == 0:
		Sfx.play("intercept_pop", a.pos, -12.0)
	var ok: bool = gw.rng.chance(int(FLARE_DECOY.get(a.type, 0)))
	if ok:
		flare_stats[1] = int(flare_stats[1]) + 1
	return ok



static func flare_point(a: Aircraft) -> Vector2:
	return a.pos - Vector2.from_angle(a.heading) * 16.0 + Vector2(0.0, 8.0)


static func ad_hit(t: Object, hit: int, gun: bool = false) -> int:
	if t is Drone and (t as Drone).low:
		return int(hit * (Navy.CM_LOW_GUN if gun else Navy.CM_LOW_HIT))
	if t is Drone and (t as Drone).kind == KAB_KIND:
		return int(hit * (KAB_GUN_MULT if gun else KAB_AD_MULT))
	if t is Aircraft and (t as Aircraft).type == Aircraft.Type.BOMBER and not gun:
		return int(hit * BOMBER_AD_MULT)
	return hit




const CR_SCRAMBLE_GAP: float = 40.0
const CR_FIRE_FRAC: float = 0.85
const CR_LOITER: float = 60.0






func _auto_cr_tick() -> void :
	var now: float = gw.game_time
	for c: Country in gw.countries:
		if not c.is_player or c.eliminated or c.capital_id < 0 or c.at_war.is_empty():
			continue
		if mil.auto_strike_of(c.id) <= 0 or now < float(cr_next.get(c.id, 0.0)):
			continue
		cr_next[c.id] = now + 4.0
		if auto_cr_scramble(c):
			cr_next[c.id] = now + CR_SCRAMBLE_GAP



func _cr_load(a: Aircraft) -> int:
	if a.type == Aircraft.Type.BOMBER:
		return a.missiles if a.payload == 0 else 0
	if a.type == Aircraft.Type.FIGHTER and a.pylon > 0:
		return a.pylon_n
	return 0


func _cr_reach_of(a: Aircraft) -> float:
	return HYPER_RANGE if a.type == Aircraft.Type.FIGHTER and a.pylon == 2 else CR_RANGE




func auto_cr_scramble(c: Country) -> bool:
	var ready: Array[Aircraft] = []
	var flying: Array[Aircraft] = []
	var parked: int = 0
	var total: int = 0
	var cr_total: int = c.missile_stock[Military.MT_CRUISE]
	var hy_total: int = c.missile_stock[Military.MT_HYPER]
	for a: Aircraft in aircraft:
		if a.country_id != c.id or a.state == Aircraft.State.DEAD or a.type == Aircraft.Type.HELI:
			continue
		if a.auto_cr > 0:
			return false
		var ld: int = _cr_load(a)
		if a.type == Aircraft.Type.FIGHTER and a.pylon == 2:
			hy_total += ld
		else:
			cr_total += ld
		if a.type == Aircraft.Type.FIGHTER:
			total += 1
		if a.state != Aircraft.State.PARKED:
			if a.airborne() and a.state != Aircraft.State.LAND and ld > 0:
				flying.append(a)
			continue
		if a.type == Aircraft.Type.FIGHTER:
			parked += 1


		if ld > 0 and a.sortie == 0 and a.service_t <= 1.0 and a.fuel >= AUTO_MIN_FUEL:
			ready.append(a)



	if total >= 2 and parked < 2:
		for k in range(ready.size() - 1, -1, -1):
			if ready[k].type == Aircraft.Type.FIGHTER:
				ready.remove_at(k)
	if ready.is_empty():
		return false
	var cap: = Vector2(gw.cities[c.capital_id].center * GameWorld.CELL)
	var list: Array = Operations.AutoCmd.targets(gw, c, mil.auto_strike_of(c.id), cap)
	var b_total: int = mil.missiles_ready(c.id) + c.missile_stock[Military.MT_BALLISTIC]
	var why: String = "НЕТ РАЗВЕДАННЫХ ЦЕЛЕЙ" if list.is_empty() else ("НЕТ КР НА СКЛАДЕ" if cr_total < 2 and hy_total < 2 else "ЦЕЛИ ДАЛЬШЕ ЗАПАСА ТОПЛИВА")
	var tel_skip: int = 0
	for i in mini(KAB_AUTO_SCAN, list.size()):
		var f: Facility = list[i][1]
		var p: Vector2 = list[i][2]
		if b_total >= 2:
			var tel_n: int = 0
			for t: Facility in mil.tels_for(c, p):
				tel_n += maxi(0, t.missiles - t.queued.size())
			if tel_n > 0:
				tel_skip += 1
				continue
		var covered: bool = false
		for fa: Aircraft in flying:
			if fa.pos.distance_to(p) <= _cr_reach_of(fa) * 0.95:
				covered = true
				break
		if covered:
			continue
		var best: Aircraft = null
		var best_fire: Vector2 = Vector2.ZERO
		var bd: float = INF
		for a: Aircraft in ready:
			var hyper: bool = a.type == Aircraft.Type.FIGHTER and a.pylon == 2
			if (hy_total if hyper else cr_total) < 2:
				continue
			var rr: float = _cr_reach_of(a) * CR_FIRE_FRAC
			var d: float = a.pos.distance_to(p)
			var fire: Vector2 = a.pos + (p - a.pos) / maxf(d, 1.0) * minf(d * 0.5, 260.0)
			if d > rr:
				fire = p + (a.pos - p) / d * rr
			if a.pos.distance_to(fire) * 2.0 + RESERVE_PX + 400.0 > a.fuel:
				continue
			if d < bd:
				bd = d
				best = a
				best_fire = fire
		if best == null:
			continue
		var load: int = _cr_load(best)
		if order_fly(best, best_fire) != "":
			continue
		best.auto_cr = load
		best.auto_cr_dest = best_fire
		best.auto_cr_t = gw.game_time + 25.0 + best.pos.distance_to(best_fire) / float(SPEC[best.type]["speed"]) + CR_LOITER



		best.auto_ai = true
		best.auto_tgt = p
		best.auto_n = 2
		mil.struck[f.id] = gw.game_time
		cr_scrambles += 1
		mil.auto_log.append([gw.game_time, f.id, f.kind, "вылет: %s" % [name_of(best)]])
		if mil.auto_log.size() > 20:
			mil.auto_log.pop_front()
		gw.say(c, Loc.mk("АВТОУДАР: %s %d — вылет на рубеж пуска, цель %s", [name_of(best), best.id, Military.title_of(f.kind)]))
		auto_why.erase("cr:%d" % c.id)
		return true
	if tel_skip > 0 and tel_skip >= mini(KAB_AUTO_SCAN, list.size()):
		why = "ЦЕЛИ БЬЮТ ОТРК"
	auto_why["cr:%d" % c.id] = [why, gw.game_time]
	return false



func _auto_cr_step(a: Aircraft) -> void :
	if a.state == Aircraft.State.DEAD:
		a.auto_cr = 0
		_q_unbook(a)
		return
	if not a.airborne():
		if a.state == Aircraft.State.PARKED and gw.game_time > a.auto_cr_t:
			a.auto_cr = 0
			_q_unbook(a)
		return
	if a.state == Aircraft.State.RTB or a.state == Aircraft.State.LAND or a.dest != a.auto_cr_dest:
		a.auto_cr = 0
		_q_unbook(a)
		return
	var qfired: int = 0
	if a.auto_ai and not gw.country_by_id(a.country_id).is_player and not mil.strike_worth(a.auto_tgt, a.country_id):
		a.auto_cr_t = -1.0
	elif a.auto_ai and _cr_load(a) >= a.auto_cr and a.pos.distance_to(a.auto_tgt) <= _cr_reach_of(a) * 0.95:
		if a.cr_q_job:
			qfired = _q_fire(a)
		else:
			_ai_fire(a, a.auto_tgt, a.auto_n if a.auto_n > 0 else 2)
	var fired: bool = _cr_load(a) < a.auto_cr
	if fired or gw.game_time > a.auto_cr_t:
		a.auto_cr = 0
		a.auto_ai = false
		_q_unbook(a)
		a.auto_n = 0
		order_land(a)
		var c: Country = gw.country_by_id(a.country_id)
		if c.is_player:
			if qfired > 0:
				var pr: Array = cr_q_progress(c.id)
				gw.say(c, Loc.t("%s %d: пуск %d КР · очередь %d/%d%s") % [name_of(a), a.id, qfired, int(pr[0]), int(pr[1]), 
					Loc.t(", возврат на перезарядку") if int(pr[0]) < int(pr[1]) else Loc.t(", удар выполнен")])
			else:
				gw.say(c, Loc.mk("%s %d: %s, возврат на базу", [name_of(a), a.id, Loc.t("пуск выполнен") if fired else Loc.t("целей нет")]))





func _ai_load(a: Aircraft, hyper: bool) -> int:
	if hyper:
		return a.pylon_n if a.type == Aircraft.Type.FIGHTER and a.pylon == 2 else 0
	if a.type == Aircraft.Type.BOMBER:
		return a.missiles if a.payload == 0 else 0
	if a.type == Aircraft.Type.FIGHTER and a.pylon == 1:
		return a.pylon_n
	return 0


func _ai_fire(a: Aircraft, target: Vector2, n: int = 2) -> bool:
	var hyper: bool = a.type == Aircraft.Type.FIGHTER and a.pylon == 2
	var ok: bool = launch_hyper(a, target) if hyper else launch_cruise(a, target, mini(n, _ai_load(a, false))) > 0
	if ok:
		var s: Array = ai_cr_stats.get(a.country_id, [0, 0, 0, 0])
		s[1 if hyper else 0] = int(s[1 if hyper else 0]) + 1
		ai_cr_stats[a.country_id] = s
	return ok







func ai_air_strike(c: Country, target: Vector2, hyper: bool) -> bool:
	if c == null or c.eliminated:
		return false
	var now: float = gw.game_time
	if now < float(ai_cr_next.get(c.id, 0.0)):
		return false
	var reach: float = HYPER_RANGE if hyper else CR_RANGE
	var tf: Facility = mil.target_fac(target)
	if not mil.can_strike_target(tf, c.id, "air"):
		var alt: Facility = mil.spread_target(c.id, tf, target, 1200.0, "air")
		if alt == null:
			return false
		tf = alt
		target = alt.center_px()
	var ready: Array[Aircraft] = []
	for a: Aircraft in aircraft:
		if a.country_id != c.id or a.state == Aircraft.State.DEAD or a.type == Aircraft.Type.HELI or a.auto_cr > 0 or a.sortie > 0:
			continue
		var ld: int = _ai_load(a, hyper)
		if ld <= 0:
			continue
		if a.airborne() and a.state != Aircraft.State.LAND and a.state != Aircraft.State.RTB and a.pos.distance_to(target) <= reach * 0.95:
			if _ai_fire(a, target):
				mil.note_strike(tf, c.id, "air")
				ai_cr_next[c.id] = now + AI_CR_GAP
				return true
		if a.state == Aircraft.State.PARKED and a.service_t <= 1.0 and a.fuel >= AUTO_MIN_FUEL:
			ready.append(a)
	var best: Aircraft = null
	var best_fire: = Vector2.ZERO
	var bd: float = INF
	for a: Aircraft in ready:
		var rr: float = reach * CR_FIRE_FRAC
		var d: float = a.pos.distance_to(target)
		var fire: Vector2 = a.pos + (target - a.pos) / maxf(d, 1.0) * minf(d * 0.5, 260.0)
		if d > rr:
			fire = target + (a.pos - target) / d * rr
		if a.pos.distance_to(fire) * 2.0 + RESERVE_PX + 400.0 > a.fuel:
			continue
		if d < bd:
			bd = d
			best = a
			best_fire = fire
	if best == null:
		if ready.is_empty():
			_ai_arm(c, hyper)
		return false
	if order_fly(best, best_fire) != "":
		return false
	best.auto_cr = _ai_load(best, hyper)
	best.auto_cr_dest = best_fire
	best.auto_cr_t = now + 25.0 + best.pos.distance_to(best_fire) / float(SPEC[best.type]["speed"]) + CR_LOITER
	best.auto_ai = true
	best.auto_tgt = target
	mil.note_strike(tf, c.id, "air")
	ai_cr_next[c.id] = now + AI_CR_GAP
	var s: Array = ai_cr_stats.get(c.id, [0, 0, 0, 0])
	s[2] = int(s[2]) + 1
	ai_cr_stats[c.id] = s
	return true




func _ai_arm(c: Country, hyper: bool) -> void :
	var mt: int = Military.MT_HYPER if hyper else Military.MT_CRUISE
	if c.missile_stock[mt] <= 0:
		return
	for a: Aircraft in aircraft:
		if a.country_id != c.id or a.state != Aircraft.State.PARKED:
			continue
		var done: bool = false
		if a.type == Aircraft.Type.FIGHTER and a.pylon_n == 0 and a.pylon != (2 if hyper else 1):
			done = set_pylon(a, 2 if hyper else 1) == ""
		elif not hyper and a.type == Aircraft.Type.BOMBER and a.payload == 1 and c.missile_stock[mt] >= 4:
			done = set_payload(a, 0) == ""
		if done:
			var s: Array = ai_cr_stats.get(c.id, [0, 0, 0, 0])
			s[3] = int(s[3]) + 1
			ai_cr_stats[c.id] = s
			return




func set_auto_kab(country_id: int, on: bool) -> void :
	auto_kab[country_id] = on
	kab_next[country_id] = 0.0


func auto_kab_of(country_id: int) -> bool:
	return bool(auto_kab.get(country_id, false))



func bomber_summary(country_id: int) -> Array:
	var out: Array = []
	for a: Aircraft in aircraft:
		if a.country_id != country_id or (a.type != Aircraft.Type.BOMBER and a.type != Aircraft.Type.ATTACK) or a.state == Aircraft.State.DEAD:
			continue
		var sn: String = Loc.t("НА БАЗЕ")
		match a.state:
			Aircraft.State.TAXI, Aircraft.State.ROLL, Aircraft.State.LIFT:
				sn = Loc.t("ПОСАДКА") if a.after_land == 99 else Loc.t("ВЗЛЁТ")
			Aircraft.State.RTB:
				sn = Loc.t("ВОЗВРАТ")
			Aircraft.State.LAND:
				sn = Loc.t("ПОСАДКА")
			Aircraft.State.FLY, Aircraft.State.ORBIT:
				sn = Loc.t("В ВОЗДУХЕ")
		if a.sortie == 1:
			sn = Loc.t("К ЦЕЛИ") if a.airborne() else Loc.t("ВЗЛЁТ")
		elif a.sortie == 2:
			sn = Loc.t("СБРОС")
		if a.cas > 0:
			sn = Loc.t("ПОДДЕРЖКА")
		out.append({"id": a.id, "type": a.type, "payload": Loc.t("КАБ") if a.type == Aircraft.Type.ATTACK else payload_name(a), "payload_i": 1 if a.type == Aircraft.Type.ATTACK else a.payload, "nar": a.nar, "state": a.state, "state_name": sn, 
			"kab_left": a.kab, "cr_left": a.missiles, "sortie": a.sortie, "fuel_frac": a.fuel / float(SPEC[a.type]["fuel"]), "note": auto_note(a)})
	return out




func auto_note(a: Aircraft) -> String:
	if a == null or a.state != Aircraft.State.PARKED or a.type == Aircraft.Type.HELI:
		return ""
	var c: Country = gw.country_by_id(a.country_id)
	if c == null or c.eliminated:
		return ""
	if _cr_carrier(a) and cr_q_left(c.id) > 0:
		var pr: Array = cr_q_progress(c.id)
		var st: String = Loc.t("ОБСЛУЖИВАНИЕ") if a.service_t > 1.0 else (Loc.t("ПЕРЕЗАРЯДКА") if _cr_load(a) < (BOMBER_CR if a.type == Aircraft.Type.BOMBER else 2) and c.missile_stock[Military.MT_CRUISE] > 0 else (Loc.t("НЕТ ТОПЛИВА") if a.fuel < AUTO_MIN_FUEL else Loc.t("ВЫЛЕТ")))
		return Loc.t("ОЧЕРЕДЬ КР %d/%d: %s") % [int(pr[0]), int(pr[1]), st]
	var kab_mode: bool = a.type == Aircraft.Type.ATTACK
	if kab_mode and not auto_kab_of(c.id):
		return ""
	if not kab_mode and (mil.auto_strike_of(c.id) <= 0 or (a.type == Aircraft.Type.FIGHTER and a.pylon == 0)):
		return ""
	var why: String = ""
	var fmax: float = float(SPEC[a.type]["fuel"])
	if c.at_war.is_empty():
		why = Loc.t("НЕТ ВОЙНЫ")
	elif a.service_t > 1.0:
		why = Loc.t("ОБСЛУЖИВАНИЕ")
	elif a.fuel < AUTO_MIN_FUEL or (a.fuel < fmax * 0.5 and c.fuel <= 0):
		why = Loc.t("НЕТ ТОПЛИВА (НУЖЕН НПЗ)")
	elif kab_mode and a.kab < 2:
		why = Loc.t("НЕТ КАБ (РАКЕТНЫЙ ЗАВОД)") if c.missile_stock[Military.MT_KAB] < 2 else Loc.t("СНАРЯЖЕНИЕ КАБ")
	elif not kab_mode and _cr_load(a) <= 0:
		why = Loc.t("НЕТ РАКЕТ НА СКЛАДЕ")
	else:
		var flying_same: bool = false
		for o: Aircraft in aircraft:
			if o != a and o.country_id == c.id and o.type == a.type and o.state != Aircraft.State.DEAD and o.state != Aircraft.State.PARKED:
				flying_same = true
		var e: Array = auto_why.get(("kab:%d" if kab_mode else "cr:%d") % c.id, [])
		if kab_mode and flying_same and c.is_player and count(c.id, Aircraft.Type.ATTACK) >= 2:
			why = Loc.t("В РЕЗЕРВЕ")
		elif not e.is_empty() and gw.game_time - float(e[1]) < 30.0:
			why = Loc.t(String(e[0]))
		else:
			why = Loc.t("ЖДЁТ ЦЕЛЬ")
	return Loc.t("АВТО: %s") % [why]


func _auto_kab_tick() -> void :
	var now: float = gw.game_time
	for c: Country in gw.countries:
		if c.eliminated or c.capital_id < 0 or c.at_war.is_empty():
			continue
		if now < float(kab_next.get(c.id, 0.0)):
			continue
		if c.is_player:
			if not auto_kab_of(c.id):
				continue
			kab_next[c.id] = now + 6.0
			if _auto_sortie(c, false):
				kab_next[c.id] = now + KAB_AUTO_GAP
		else:
			kab_next[c.id] = now + 8.0
			_ai_kab(c)


func _persona(c: Country) -> Dictionary:
	if gw.ai != null and gw.ai.has_method("persona_of"):
		return gw.ai.persona_of(c)
	return {"aggr": 0.5, "caution": 0.5}




func _ai_kab(c: Country) -> void :
	var P: Dictionary = _persona(c)
	var aggr: float = float(P.get("aggr", 0.5))
	var af: Facility = null
	for f: Facility in mil.facilities:
		if f.kind == Facility.Kind.AIRFIELD and f.country_id == c.id and mil.alive(f):
			af = f
			break
	if af == null:
		return

	var jc: int = int(SPEC[Aircraft.Type.ATTACK]["cost"])
	var nj: int = count(c.id, Aircraft.Type.ATTACK)
	if (nj == 0 and (((aggr >= 0.35 or GameConfig.diff_of(c) >= 2) and c.money >= jc + 3000) or c.money >= jc * 3))\
	or (nj == 1 and c.money >= jc * 4 and aggr >= 0.5):
		buy(af, Aircraft.Type.ATTACK, c)
	if _auto_sortie(c, true):
		kab_next[c.id] = gw.game_time + KAB_AI_GAP * (1.3 - aggr * 0.6)
	elif _ai_cas(c):
		kab_next[c.id] = gw.game_time + KAB_AI_GAP * (1.3 - aggr * 0.6)





func _auto_sortie(c: Country, ai: bool) -> bool:
	var ready: Array[Aircraft] = []
	var parked: int = 0
	var total: int = 0
	for a: Aircraft in aircraft:
		if a.country_id != c.id or a.type != Aircraft.Type.ATTACK or a.state == Aircraft.State.DEAD:
			continue
		total += 1
		if a.state != Aircraft.State.PARKED:
			continue
		parked += 1
		if a.kab >= 2 and a.service_t <= 1.0 and a.fuel >= AUTO_MIN_FUEL:
			ready.append(a)
	if ready.is_empty() or ( not ai and total >= 2 and parked < 2):
		return false
	var careful: bool = not ai or float(_persona(c).get("caution", 0.5)) > 0.6
	var list: Array = _kab_targets(c, ai, ready[0].pos)
	var risky: int = 0
	auto_why["kab:%d" % c.id] = ["НЕТ ЦЕЛЕЙ У ФРОНТА" if list.is_empty() else "ЦЕЛИ ДАЛЬШЕ ЗАПАСА ТОПЛИВА", gw.game_time]
	for i in mini(KAB_AUTO_SCAN, list.size()):
		var e: Array = list[i]
		var p: Vector2 = e[1]
		var best: Aircraft = null
		for a: Aircraft in ready:
			if _kab_why(a, p, _release_point(a.pos, p)) == "" and (best == null or a.pos.distance_to(p) < best.pos.distance_to(p)):
				best = a
		if best == null:
			continue
		if (careful or e.size() > 4) and int(_kab_risk(c.id, _release_point(best.pos, p), p, false)[0]) >= (int(gw.hold.D_KAB_LVL[gw.hold.diff_i(c.id)]) if e.size() > 4 else 2):
			risky += 1
			continue
		if _launch_kab(best, p, best.kab, true) > 0:
			var f: Facility = e[3]
			if f != null:
				mil.struck[f.id] = gw.game_time
				mil.note_strike(f, c.id, "kab")
			elif e.size() > 4 and gw.hold != null:
				gw.hold.note_hit(c.id, int(e[4]), "kab")
			mil.auto_log.append([gw.game_time, f.id if f != null else -1, f.kind if f != null else -1, "КАБ"])
			if mil.auto_log.size() > 20:
				mil.auto_log.pop_front()
			if c.is_player:
				gw.say(c, Loc.mk("АВТО-КАБ: вылет — %s", [String(e[2])]))
			auto_why.erase("kab:%d" % c.id)
			return true
	if risky > 0:
		auto_why["kab:%d" % c.id] = ["ЦЕЛИ ПОД ЗРК С РЛС", gw.game_time]
	if c.is_player and risky > 0 and gw.game_time >= float(kab_wait_msg.get(c.id, 0.0)):
		kab_wait_msg[c.id] = gw.game_time + 180.0
		gw.say(c, Loc.mk("АВТО-КАБ: цели под ЗРК с РЛС — ждём"))
	return false



func _ai_cas(c: Country) -> bool:
	var jet: Aircraft = null
	for a: Aircraft in aircraft:
		if a.country_id == c.id and a.type == Aircraft.Type.ATTACK and a.state == Aircraft.State.PARKED and a.nar >= 8\
		and a.service_t <= 1.0 and a.fuel >= AUTO_MIN_FUEL:
			jet = a
			break
	if jet == null:
		return false
	var own_units: Array[Vector2] = []
	for u: Unit in gw.army.units:
		if u.country_id == c.id and u.alive() and u.ground():
			own_units.append(u.pos)
	for g: Dictionary in Operations.AutoCmd.enemy_groups(gw, c):
		var gp: Vector2 = g["pos"]
		if int(g["n"]) < 3 or not _near_any(gp, own_units, 400.0):
			continue
		if cas_support(c.id, jet.id, gp) == "":
			return true
	return false





func _kab_targets(c: Country, ai: bool, from: Vector2) -> Array:
	var out: Array = []
	var own_units: Array[Vector2] = []
	for u: Unit in gw.army.units:
		if u.country_id == c.id and u.alive() and u.ground():
			own_units.append(u.pos)
	var groups: Array = Operations.AutoCmd.enemy_groups(gw, c)
	for g: Dictionary in groups:
		var gp: Vector2 = g["pos"]
		var n: int = int(g["n"])
		var near_army: bool = _near_any(gp, own_units, 500.0)
		if ai and gw.hold != null and int(gw.hold.diff_i(c.id)) < 2:
			n -= int(gw.hold.garrison_near(c.id, gp, Operations.AutoCmd.CLUSTER))
		if n < 3 or not (bool(g["own"]) or g["city"] != null or near_army):
			continue
		if ai and not _ai_sees(c, gp, own_units):
			continue
		out.append([3000.0 + n * 150.0 + (800.0 if bool(g["own"]) or g["city"] != null else 0.0) - gp.distance_to(from) * 0.05, gp, Loc.t("войска противника (%d)") % n, null])
	var now: float = gw.game_time
	for f: Facility in mil.facilities:
		if f.parent != null or not c.at_war.has(f.country_id) or not mil.alive(f):
			continue
		var w: float = float(Operations.AutoCmd.MIL_W.get(f.kind, 0.0))
		if ai and w <= 0.0:
			w = float(Operations.AutoCmd.ECO_W.get(f.kind, 0.0))
		if w <= 0.0 or now - float(mil.struck.get(f.id, -999.0)) < Operations.AutoCmd.STRUCK_MEMO:
			continue
		if ai and not mil.can_strike_target(f, c.id, "kab"):
			continue
		var p: Vector2 = f.center_px()
		if ai:
			if not _ai_sees(c, p, own_units):
				continue
		else:
			if f.moving or not sim_knows(c, f, own_units):
				continue
			if not _near_front(c, p, own_units):
				continue
		out.append([w * 500.0 - p.distance_to(from) * 0.05, p, Military.title_of(f.kind), f])
	if ai and gw.hold != null and gw.ai != null and gw.ai.sense != null:



		for he: Array in gw.hold.strike_spots(c.id):
			var hp: Vector2 = he[0]
			if not gw.hold.hit_ok(c.id, int(he[3]), "kab") or gw.ai.sense.inbound_at(c, hp, 24.0) > 0 or gw.hold.strike_veto(c.id, hp, "kab") != "":
				continue
			out.append([3000.0 + float(he[4]) * 300.0 - hp.distance_to(from) * 0.05, hp, Loc.t("дом с гарнизоном (%d)") % int(he[1]), null, int(he[3])])
	out.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	return out


func _near_any(p: Vector2, pts: Array[Vector2], r: float) -> bool:
	var r2: float = r * r
	for q: Vector2 in pts:
		if q.distance_squared_to(p) <= r2:
			return true
	return false



func _near_front(c: Country, p: Vector2, own_units: Array[Vector2]) -> bool:
	for cid in c.city_ids:
		var ct: City = gw.cities[cid]
		if Vector2(ct.center * GameWorld.CELL).distance_to(p) - float(ct.radius * GameWorld.CELL) <= KAB_FRONT_R:
			return true
	return _near_any(p, own_units, 700.0)



func front_sees(c: Country, p: Vector2, own_units: Array[Vector2]) -> bool:
	return _ai_sees(c, p, own_units)




var intel: Dictionary = {}


func note_intel(cid: int, fid: int) -> void :
	if not intel.has(cid):
		intel[cid] = {}
	(intel[cid] as Dictionary)[fid] = gw.game_time



func sim_knows(c: Country, f: Facility, own_units: Array[Vector2]) -> bool:
	if _ai_sees(c, f.center_px(), own_units):
		return true
	return not mil.is_mobile(f.kind) and (intel.get(c.id, {}) as Dictionary).has(f.id)


func own_ground(c: Country) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for u: Unit in gw.army.units:
		if u.country_id == c.id and u.alive() and u.ground():
			out.append(u.pos)
	return out



func _ai_sees(c: Country, p: Vector2, own_units: Array[Vector2]) -> bool:
	for cid in c.city_ids:
		var ct: City = gw.cities[cid]
		if Vector2(ct.center * GameWorld.CELL).distance_to(p) - float(ct.radius * GameWorld.CELL) <= KAB_SIGHT_R:
			return true
	if _near_any(p, own_units, KAB_SIGHT_R * 0.6):
		return true
	for f: Facility in mil.facilities:
		if f.country_id == c.id and f.parent == null and f.center_px().distance_squared_to(p) <= KAB_SIGHT_R * KAB_SIGHT_R:
			return true
	return false




func _multi_load(a: Aircraft, hyper: bool) -> int:
	return _ai_load(a, hyper)





func multi_plan(c: Country, targets: Array, hyper: bool) -> Dictionary:
	var out: Dictionary = {"ok": false, "total": 0, "available": 0, "assigned": 0, "carriers": 0, "per_target": [], "plan": [], "why": ""}
	if c == null:
		return out
	var reach: float = HYPER_RANGE if hyper else CR_RANGE
	var left: Dictionary = {}
	var bound: Dictionary = {}
	for a: Aircraft in aircraft:
		if a.country_id != c.id or a.state == Aircraft.State.DEAD or a.type == Aircraft.Type.HELI or a.auto_cr > 0 or a.sortie > 0:
			continue
		var ld: int = _multi_load(a, hyper)
		if ld <= 0:
			continue
		var air_ok: bool = a.airborne() and a.state != Aircraft.State.LAND and a.state != Aircraft.State.RTB
		var park_ok: bool = a.state == Aircraft.State.PARKED and a.service_t <= 1.0 and a.fuel >= float(SPEC[a.type]["fuel"]) * 0.7
		if air_ok or park_ok:
			left[a] = ld
			out["available"] = int(out["available"]) + ld


	var q_room: int = 0 if hyper else q_room_of(c, left)
	out["available"] = int(out["available"]) + q_room
	var used: Dictionary = {}
	for e: Array in Military._strike_pts(targets):
		var p: Vector2 = e[0]
		var n: int = int(e[1])
		out["total"] = int(out["total"]) + n
		var got: int = 0
		if gw.diplo != null and gw.diplo.strike_block_at(c.id, p, false) != "":
			(out["per_target"] as Array).append({"ok": false, "reason": Diplomacy.STRIKE_BLOCK_TXT, "n": 0, "got": 0, "pos": p, "queued": 0})
			out["why"] = Diplomacy.STRIKE_BLOCK_TXT
			continue
		while got < n:
			var best: Aircraft = null
			var bs: float = INF
			for a: Aircraft in left:
				if int(left[a]) <= 0:
					continue
				var d: float = a.pos.distance_to(p)
				var s: float = d
				if a.state == Aircraft.State.PARKED:
					if bound.has(a) and bound[a] != p:
						continue
					var rr: float = reach * CR_FIRE_FRAC
					var fire: Vector2 = p + (a.pos - p) / maxf(d, 1.0) * minf(d, rr)
					if a.pos.distance_to(fire) * 2.0 + RESERVE_PX + 400.0 > a.fuel:
						continue
					s += 100000.0 if not bound.has(a) else 0.0
				elif d > reach * 0.95:
					continue
				if s < bs:
					bs = s
					best = a
			if best == null:
				break
			var k: int = mini(n - got, int(left[best]))
			left[best] = int(left[best]) - k
			if best.state == Aircraft.State.PARKED:
				bound[best] = p
			(out["plan"] as Array).append([best, p, k, best.state == Aircraft.State.PARKED])
			used[best] = true
			got += k
		(out["per_target"] as Array).append({"ok": got == n, "reason": "" if got == n else (Loc.t("Нет носителя в досягаемости") if got == 0 else Loc.t("Не хватает ракет")), "n": n, "got": got, "pos": p, "queued": 0})
		out["assigned"] = int(out["assigned"]) + got
	if not hyper:
		var room: int = q_room
		for a2: Aircraft in left:
			room += int(left[a2])
		var qn: int = 0
		for pt: Dictionary in out["per_target"]:
			var miss: int = int(pt["n"]) - int(pt["got"])
			var k2: int = mini(miss, room)
			if k2 <= 0:
				continue
			room -= k2
			qn += k2
			pt["queued"] = k2
			pt["got"] = int(pt["got"]) + k2
			pt["ok"] = int(pt["got"]) == int(pt["n"])
			if bool(pt["ok"]):
				pt["reason"] = ""
		out["queued"] = qn
		out["assigned"] = int(out["assigned"]) + qn
		if qn > 0:
			for pt2: Dictionary in out["per_target"]:
				if String(pt2["reason"]) == "":
					pt2["reason"] = Loc.t("Очередь %d КР: следующими вылетами после перезарядки") % qn
					break
	out["carriers"] = used.size()
	out["ok"] = int(out["assigned"]) > 0
	if int(out["available"]) == 0:
		out["why"] = Loc.t("Нет гиперзвуковых ракет на подвесе") if hyper else Loc.t("Нет крылатых ракет на носителях")
	return out



func multi_launch(c: Country, targets: Array, hyper: bool) -> Dictionary:
	var mp: Dictionary = multi_plan(c, targets, hyper)
	var res: Dictionary = {"launched": 0, "per": [], "carriers": int(mp["carriers"]), "text": ""}
	for pt: Dictionary in mp["per_target"]:
		(res["per"] as Array).append(int(pt["got"]))
	var flying: int = 0
	var fly_k: Dictionary = {}
	var q_extra: Dictionary = {}
	var now_k: int = 0
	var fresh: bool = c != null and not hyper and cr_q_progress(c.id)[0] >= cr_q_progress(c.id)[1]
	for e: Array in mp["plan"]:
		var a: Aircraft = e[0]
		var p: Vector2 = e[1]
		var k: int = int(e[2])
		if bool(e[3]):
			var d: float = a.pos.distance_to(p)
			var rr: float = (HYPER_RANGE if hyper else CR_RANGE) * CR_FIRE_FRAC
			var fire: Vector2 = a.pos + (p - a.pos) / maxf(d, 1.0) * minf(d * 0.5, 260.0)
			if d > rr:
				fire = p + (a.pos - p) / d * rr
			if order_fly(a, fire) != "":
				if not hyper:
					fly_k[p] = int(fly_k.get(p, 0))
					q_extra[p] = int(q_extra.get(p, 0)) + k
				continue
			a.auto_cr = _multi_load(a, hyper)
			a.auto_cr_dest = fire
			a.auto_cr_t = gw.game_time + 25.0 + a.pos.distance_to(fire) / float(SPEC[a.type]["speed"]) + CR_LOITER
			a.auto_ai = true
			a.auto_tgt = p
			a.auto_n = k
			if not hyper:
				a.cr_q_job = true
				fly_k[p] = int(fly_k.get(p, 0)) + k
			flying += 1
			res["launched"] = int(res["launched"]) + k
		elif hyper:
			for i in k:
				if launch_hyper(a, p):
					res["launched"] = int(res["launched"]) + 1
		else:
			var k0: int = launch_cruise(a, p, k)
			res["launched"] = int(res["launched"]) + k0
			now_k += k0
	var queued: int = 0
	if c != null and not hyper:

		var tot: int = now_k
		for pt: Dictionary in mp["per_target"]:
			var p2: Vector2 = pt["pos"]
			var fk: int = int(fly_k.get(p2, 0))
			var qk: int = int(pt.get("queued", 0)) + int(q_extra.get(p2, 0))
			tot += fk + qk
			queued += qk
			if fk + qk > 0:
				cr_q.append([c.id, p2, fk + qk, fk, fk + qk])
		var pr: Array = cr_q_progress(c.id)
		cr_prog[c.id] = [now_k, tot] if fresh else [int(pr[0]) + now_k, int(pr[1]) + tot]
		res["queued"] = queued
	if int(res["launched"]) > 0 or queued > 0:
		res["text"] = Loc.t("%s: %d по %d целям, носителей %d%s%s") % [Loc.t("Гиперзвук") if hyper else Loc.t("Крылатые ракеты"), int(res["launched"]), (res["per"] as Array).filter( func(g: int) -> bool: return g > 0).size(), int(res["carriers"]), (Loc.t(" (вылет: %d)") % flying) if flying > 0 else "", 
			(Loc.t(" · очередь %d: после перезарядки") % queued) if queued > 0 else ""]
		res["launched"] = int(res["launched"]) + queued
	else:
		res["text"] = String(mp["why"]) if String(mp["why"]) != "" else Loc.t("Нет носителя в досягаемости")
	if c != null and c.is_player and not bool(gw.get_meta("strike_quiet", false)):
		gw.say(c, String(res["text"]))
	return res








var cr_q: Array = []
var cr_prog: Dictionary = {}
var cr_q_stats: Array = [0, 0, 0]



func cr_q_progress(cid: int) -> Array:
	return cr_prog.get(cid, [0, 0])



func cr_q_left(cid: int) -> int:
	var n: int = 0
	for e: Array in cr_q:
		if int(e[0]) == cid:
			n += int(e[2])
	return n


func _cr_carrier(a: Aircraft) -> bool:
	return a.state != Aircraft.State.DEAD and ((a.type == Aircraft.Type.BOMBER and a.payload == 0) or (a.type == Aircraft.Type.FIGHTER and a.pylon == 1))




func q_room_of(c: Country, ready: Dictionary) -> int:
	var has: bool = false
	var n: int = c.missile_stock[Military.MT_CRUISE]
	for a: Aircraft in aircraft:
		if a.country_id != c.id or not _cr_carrier(a):
			continue
		has = true
		if not ready.has(a):
			n += _ai_load(a, false)
	if not has:
		return 0
	return maxi(0, n - cr_q_left(c.id))


func _q_entry(cid: int, p: Vector2) -> Array:
	for e: Array in cr_q:
		if int(e[0]) == cid and e[1] == p:
			return e
	return []



func _q_unbook(a: Aircraft) -> void :
	if not a.cr_q_job:
		return
	a.cr_q_job = false
	var e: Array = _q_entry(a.country_id, a.auto_tgt)
	if not e.is_empty():
		e[3] = maxi(0, int(e[3]) - a.auto_n)




func _q_fire(a: Aircraft) -> int:
	_q_peace_drop()
	var cid: int = a.country_id
	var fired: int = 0
	var e: Array = _q_entry(cid, a.auto_tgt)
	if not e.is_empty():
		e[3] = maxi(0, int(e[3]) - a.auto_n)
		var k: int = launch_cruise(a, a.auto_tgt, mini(mini(a.auto_n, int(e[2])), _cr_load(a)))
		e[2] = int(e[2]) - k
		fired += k
	a.cr_q_job = false
	a.auto_n = 0
	var order: Array = []
	for e2: Array in cr_q:
		if int(e2[0]) == cid and int(e2[2]) - int(e2[3]) > 0 and a.pos.distance_to(e2[1]) <= _cr_reach_of(a) * 0.95:
			order.append(e2)
	order.sort_custom( func(x: Array, y: Array) -> bool: return a.pos.distance_squared_to(x[1]) < a.pos.distance_squared_to(y[1]))
	for e3: Array in order:
		var ld: int = _cr_load(a)
		if ld <= 0:
			break
		var k3: int = launch_cruise(a, e3[1], mini(ld, int(e3[2]) - int(e3[3])))
		e3[2] = int(e3[2]) - k3
		fired += k3
	_q_note(cid, fired)
	return fired






func _q_peace_drop() -> void :
	if gw.diplo == null or gw.data == null:
		return
	for k in range(cr_q.size() - 1, -1, -1):
		var e: Array = cr_q[k]
		var cid: int = int(e[0])
		var p: Vector2 = e[1]
		var cl: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
		if not gw.data.inside(cl.x, cl.y):
			continue
		var o: int = gw.data.get_owner_id(cl.x, cl.y)
		if o <= 0 or o == cid or gw.diplo.at_war(cid, o):
			continue
		if not (gw.diplo.truce_on(cid, o) or gw.diplo.calm_on(cid, o)):
			continue
		var left: int = int(e[2])
		cr_q.remove_at(k)
		cr_q_stats[2] = int(cr_q_stats[2]) + 1
		var pr: Array = cr_q_progress(cid)
		cr_prog[cid] = [int(pr[0]), maxi(int(pr[0]), int(pr[1]) - left)]
		var c: Country = gw.country_by_id(cid)
		if c != null and c.is_player:
			gw.say(c, Loc.mk("Очередь КР: %d ракет отменено — мир с %s", [left, Loc.name(gw.diplo._cname(o))]))


func _q_note(cid: int, fired: int) -> void :
	if fired <= 0:
		return
	cr_q_stats[1] = int(cr_q_stats[1]) + fired
	var pr: Array = cr_q_progress(cid)
	cr_prog[cid] = [mini(int(pr[0]) + fired, int(pr[1])), int(pr[1])]
	for k in range(cr_q.size() - 1, -1, -1):
		if int(cr_q[k][2]) <= 0:
			cr_q.remove_at(k)




func _q_tick() -> void :
	var cids: Dictionary = {}
	for e: Array in cr_q:
		cids[int(e[0])] = true
	for cid: int in cids:
		var c: Country = gw.country_by_id(cid)
		var carriers: Array[Aircraft] = []
		var aboard: int = 0
		if c != null and not c.eliminated:
			for a: Aircraft in aircraft:
				if a.country_id == cid and _cr_carrier(a):
					carriers.append(a)
					aboard += _cr_load(a)
		var booked: int = 0
		for e0: Array in cr_q:
			if int(e0[0]) == cid:
				booked += int(e0[3])
		if c == null or c.eliminated or carriers.is_empty() or (aboard == 0 and booked == 0 and c.missile_stock[Military.MT_CRUISE] <= 0):
			var left: int = cr_q_left(cid)
			for k in range(cr_q.size() - 1, -1, -1):
				if int(cr_q[k][0]) == cid:
					cr_q.remove_at(k)
			cr_q_stats[2] = int(cr_q_stats[2]) + 1
			cr_prog[cid] = [int(cr_q_progress(cid)[0]), int(cr_q_progress(cid)[0])]
			if c != null and c.is_player and not c.eliminated:
				gw.say(c, Loc.mk("Очередь КР отменена (%d): %s", [left, Loc.t("нет носителей КР") if carriers.is_empty() else Loc.t("нет ракет - нужен ракетный завод")]))
			continue
		for a: Aircraft in carriers:
			if a.auto_cr > 0 or a.sortie > 0 or a.cas > 0 or a.cr_pend > 0 or _cr_load(a) <= 0:
				continue
			if a.airborne():
				if a.state != Aircraft.State.FLY and a.state != Aircraft.State.ORBIT:
					continue
				var fired: int = 0
				for e1: Array in cr_q:
					var free: int = int(e1[2]) - int(e1[3])
					if int(e1[0]) != cid or free <= 0 or a.pos.distance_to(e1[1]) > _cr_reach_of(a) * 0.95 or _cr_load(a) <= 0:
						continue
					var k1: int = launch_cruise(a, e1[1], mini(free, _cr_load(a)))
					e1[2] = int(e1[2]) - k1
					fired += k1
				_q_note(cid, fired)
				continue
			if a.state != Aircraft.State.PARKED or a.service_t > 1.0 or a.fuel < AUTO_MIN_FUEL:
				continue
			var full: int = BOMBER_CR if a.type == Aircraft.Type.BOMBER else int(PYLON_N[1])
			if _cr_load(a) < full and c.missile_stock[Military.MT_CRUISE] > 0:
				continue
			var best: Array = []
			var bd: float = INF
			var bfire: Vector2 = Vector2.ZERO
			for e2: Array in cr_q:
				if int(e2[0]) != cid or int(e2[2]) - int(e2[3]) <= 0:
					continue
				var p: Vector2 = e2[1]
				var d: float = a.pos.distance_to(p)
				var rr: float = _cr_reach_of(a) * CR_FIRE_FRAC
				var fire: Vector2 = a.pos + (p - a.pos) / maxf(d, 1.0) * minf(d * 0.5, 260.0)
				if d > rr:
					fire = p + (a.pos - p) / d * rr
				if a.pos.distance_to(fire) * 2.0 + RESERVE_PX + 400.0 > a.fuel:
					continue
				if d < bd:
					bd = d
					best = e2
					bfire = fire
			if best.is_empty() or order_fly(a, bfire) != "":
				continue
			var kb: int = mini(int(best[2]) - int(best[3]), _cr_load(a))
			best[3] = int(best[3]) + kb
			a.auto_cr = _cr_load(a)
			a.auto_cr_dest = bfire
			a.auto_cr_t = gw.game_time + 25.0 + a.pos.distance_to(bfire) / float(SPEC[a.type]["speed"]) + CR_LOITER
			a.auto_ai = true
			a.auto_tgt = best[1]
			a.auto_n = kb
			a.cr_q_job = true
			cr_q_stats[0] = int(cr_q_stats[0]) + 1
			if c.is_player:
				var pr: Array = cr_q_progress(cid)
				gw.say(c, Loc.mk("%s %d: вылет по очереди КР (%d/%d выпущено)", [name_of(a), a.id, int(pr[0]), int(pr[1])]))






var nars: Array = []
var kab_gun_tries: Dictionary = {}
var cas_stats: Array = [0, 0, 0]


func _jet(country_id: int, a_id: int) -> Aircraft:
	for a: Aircraft in aircraft:
		if a.id == a_id and a.country_id == country_id and a.state != Aircraft.State.DEAD:
			return a
	return null



func attack_jets(country_id: int) -> Array[Aircraft]:
	var out: Array[Aircraft] = []
	for a: Aircraft in aircraft:
		if a.country_id == country_id and a.type == Aircraft.Type.ATTACK and a.state != Aircraft.State.DEAD:
			out.append(a)
	return out


func kab_stock(country_id: int) -> int:
	var c: Country = gw.country_by_id(country_id)
	return c.missile_stock[Military.MT_KAB] if c != null and c.missile_stock.size() > Military.MT_KAB else 0



static func kab_reach() -> float:
	return KAB_RANGE



func _kab_route_px(a: Aircraft, targets: Array) -> float:
	var p: Vector2 = a.pos
	var total: float = 0.0
	for t: Vector2 in targets:
		var rel: Vector2 = _release_point(p, t)
		total += p.distance_to(rel)
		p = rel
	var home: Vector2 = spot_pos(a.base, a.spot) if a.base != null else a.pos
	return total + p.distance_to(home) + RESERVE_PX + 120.0



func kab_strike_why(country_id: int, a_id: int, targets: Array) -> String:
	var a: Aircraft = _jet(country_id, a_id)
	if a == null:
		return Loc.t("Самолёт потерян")
	var fighter_kab: bool = a.type == Aircraft.Type.FIGHTER and a.pylon == 3 and arsenal_enabled
	if a.type != Aircraft.Type.ATTACK and not fighter_kab:
		return Loc.t("КАБ — нужен штурмовик или истребитель с подвесом КАБ")
	var capacity: int = int(PYLON_N[3]) if fighter_kab else ATTACK_KAB
	if targets.is_empty() or targets.size() > capacity:
		return Loc.t("Выберите от 1 до %d целей") % capacity
	for t: Variant in targets:
		if not t is Vector2:
			return Loc.t("Неверная цель")
		if gw.diplo != null and gw.diplo.strike_block_at(country_id, t as Vector2, false) != "":
			return Diplomacy.STRIKE_BLOCK_TXT
	var have: int = _kab_payload(a)
	if a.state == Aircraft.State.PARKED and a.type == Aircraft.Type.ATTACK:
		have = mini(ATTACK_KAB, a.kab + kab_stock(country_id))
	if have <= 0:
		return Loc.t("Нет КАБ: нужен ракетный завод (тип КАБ)")
	if targets.size() > have:
		return Loc.t("На борту только %d КАБ") % have
	if a.state == Aircraft.State.LAND or (a.state == Aircraft.State.TAXI and a.after_land == 99):
		return Loc.t("Штурмовик заходит на посадку")
	if a.sortie == 2:
		return Loc.t("Идёт сброс")
	if a.state == Aircraft.State.PARKED and a.fuel < 600.0:
		return Loc.t("Мало топлива: идёт заправка")
	var need: float = _kab_route_px(a, targets.slice(0, mini(targets.size(), have)))
	if need > a.fuel:
		if a.state == Aircraft.State.PARKED and need <= float(SPEC[a.type]["fuel"]):
			return Loc.t("Не хватает топлива: идёт заправка")
		return Loc.t("Цели слишком далеко: не хватит топлива")
	return ""




func kab_strike(country_id: int, a_id: int, targets: Array) -> String:
	var c: Country = gw.country_by_id(country_id)
	var why: String = kab_strike_why(country_id, a_id, targets)
	if why != "":
		if c != null and c.is_player:
			gw.say(c, why)
		return why
	var a: Aircraft = _jet(country_id, a_id)
	if a.state == Aircraft.State.PARKED and a.type == Aircraft.Type.ATTACK:
		_rearm_attack(a, c)
	var k: int = mini(targets.size(), _kab_payload(a))
	a.kab_q.clear()
	for i in k:
		a.kab_q.append(targets[i])
	a.cas = 0
	a.auto_cr = 0
	a.sortie = 1
	a.sortie_target = a.kab_q[0]
	a.sortie_release = _release_point(a.pos, a.kab_q[0])
	a.sortie_n = k
	a.sortie_i = 0
	a.sortie_auto = not (c != null and c.is_player)
	if a.state == Aircraft.State.PARKED:
		order_fly(a, a.sortie_release)
	else:
		a.resume = 0
		a.dest = a.sortie_release
		if a.airborne():
			a.state = Aircraft.State.FLY
	if c != null and c.is_player:
		gw.say(c, Loc.mk("%s %d: удар КАБ, целей %d", [name_of(a), a.id, k]))
	return ""



func cas_why(country_id: int, a_id: int, p: Vector2) -> String:
	var a: Aircraft = _jet(country_id, a_id)
	if a == null:
		return Loc.t("Самолёт потерян")
	if a.type != Aircraft.Type.ATTACK:
		return Loc.t("Поддержка - только штурмовиком")
	if gw.diplo != null and gw.diplo.strike_block_at(country_id, p, false) != "":
		return Diplomacy.STRIKE_BLOCK_TXT
	if a.state == Aircraft.State.LAND or (a.state == Aircraft.State.TAXI and a.after_land == 99):
		return Loc.t("Штурмовик заходит на посадку")
	if a.state == Aircraft.State.PARKED and a.fuel < 600.0:
		return Loc.t("Мало топлива: идёт заправка")
	var home: Vector2 = spot_pos(a.base, a.spot) if a.base != null else a.pos
	var need: float = a.pos.distance_to(p) + CAS_RUN * 2.0 * CAS_PASSES + p.distance_to(home) + RESERVE_PX + 120.0
	if need > a.fuel:
		if a.state == Aircraft.State.PARKED and need <= float(SPEC[a.type]["fuel"]):
			return Loc.t("Не хватает топлива: идёт заправка")
		return Loc.t("Слишком далеко: не хватит топлива")
	return ""




func cas_support(country_id: int, a_id: int, p: Vector2) -> String:
	var c: Country = gw.country_by_id(country_id)
	var why: String = cas_why(country_id, a_id, p)
	if why != "":
		if c != null and c.is_player:
			gw.say(c, why)
		return why
	var a: Aircraft = _jet(country_id, a_id)
	a.sortie = 0
	a.kab_q.clear()
	a.auto_cr = 0
	a.cas = 1
	a.cas_p = p
	a.cas_pass = CAS_PASSES
	if a.state == Aircraft.State.PARKED:
		order_fly(a, p)
	else:
		a.resume = 0
		a.dest = p
		if a.airborne():
			a.state = Aircraft.State.FLY
	if c != null and c.is_player:
		gw.say(c, Loc.mk("%s %d: вылет на поддержку", [name_of(a), a.id]))
	return ""


func _cas_end(a: Aircraft, why: String) -> void :
	a.cas = 0
	var c: Country = gw.country_by_id(a.country_id)
	if why != "" and c != null and c.is_player:
		gw.say(c, "%s %d: %s" % [name_of(a), a.id, why])


func _cas_step(a: Aircraft, dt: float) -> void :
	if a.state == Aircraft.State.DEAD or a.state == Aircraft.State.RTB or a.state == Aircraft.State.LAND:
		a.cas = 0
		return
	if not a.airborne():
		return
	a.fire_cd -= dt
	a.gun_cd -= dt
	if a.cas == 1:
		if a.dest != a.cas_p:
			_cas_end(a, Loc.t("поддержка отменена"))
			return
		if a.pos.distance_to(a.cas_p) <= CAS_RUN + 30.0:
			a.cas = 2
			a.cas_dir = (a.cas_p - a.pos).normalized() if a.pos.distance_to(a.cas_p) > 1.0 else Vector2.from_angle(a.heading)
			a.dest = a.cas_p + a.cas_dir * CAS_RUN
			a.state = Aircraft.State.FLY
		return
	var endp: Vector2 = a.cas_p + a.cas_dir * CAS_RUN
	if a.dest != endp:
		_cas_end(a, Loc.t("поддержка отменена"))
		return
	var fwd: Vector2 = Vector2.from_angle(a.heading)
	if a.pos.distance_to(a.cas_p) <= CAS_R + 50.0 and fwd.dot(a.cas_dir) > 0.6:
		if a.fire_cd <= 0.0 and a.nar > 0:
			a.fire_cd = NAR_GAP
			for i in mini(NAR_SALVO, a.nar):
				var aim: Vector2 = _cas_aim(a) + Vector2(gw.rng.range_ab(-6, 6), gw.rng.range_ab(-6, 6))
				var from: Vector2 = a.pos + fwd.orthogonal() * (2.5 if i == 0 else -2.5)
				nars.append({"p": from, "t": aim, "c": a.country_id, "h": (aim - from).angle(), "z": a.h})
				a.nar -= 1
				cas_stats[0] = int(cas_stats[0]) + 1
			Sfx.play("rpg_fire", a.pos, -4.0)
		if a.gun_cd <= 0.0:
			var u: Unit = _gun_target(a)
			if u != null:
				a.gun_cd = ATK_GUN_CD
				cas_stats[1] = int(cas_stats[1]) + 1
				tracers.append([a.pos, u.pos, gw.game_time + 0.15])
				tracers.append([a.pos + fwd.orthogonal() * 1.5, u.pos + Vector2(2, 1), gw.game_time + 0.12])
				Sfx.play("mg_burst", a.pos)
				if gw.rng.chance(ATK_GUN_HIT):
					cas_stats[2] = int(cas_stats[2]) + 1
					gw.army._damage(u, ATK_GUN_DMG, a.country_id)
	if a.pos.distance_to(endp) < ORBIT_R + 6.0 or (a.pos - a.cas_p).dot(a.cas_dir) > CAS_RUN - 10.0:
		a.cas_pass -= 1
		if a.cas_pass <= 0 or a.nar <= 0:
			a.cas = 0
			order_land(a)
			_cas_end(a, Loc.t("поддержка выполнена, возврат на базу"))
			return
		a.cas_dir = - a.cas_dir
		a.dest = a.cas_p + a.cas_dir * CAS_RUN



func _cas_aim(a: Aircraft) -> Vector2:
	var ahead: Vector2 = a.pos + Vector2.from_angle(a.heading) * 70.0
	var best: Vector2 = a.cas_p
	var bd: float = INF
	for u: Unit in gw.army._near(a.cas_p, CAS_R):
		if not u.alive() or not mil.hostile(a.country_id, u.country_id) or u.pos.distance_to(a.cas_p) > CAS_R:
			continue
		var d: float = u.pos.distance_squared_to(ahead)
		if d < bd:
			bd = d
			best = u.pos
	return best


func _gun_target(a: Aircraft) -> Unit:
	var fwd: Vector2 = Vector2.from_angle(a.heading)
	var best: Unit = null
	var bd: float = ATK_GUN_R * ATK_GUN_R
	for u: Unit in gw.army._near(a.pos, ATK_GUN_R):
		if not u.alive() or not mil.hostile(a.country_id, u.country_id):
			continue
		var to: Vector2 = u.pos - a.pos
		var d: float = to.length_squared()
		if d < bd and to.dot(fwd) > 0.0:
			bd = d
			best = u
	return best


func _update_nars(dt: float) -> void :
	for k in range(nars.size() - 1, -1, -1):
		var r: Dictionary = nars[k]
		var p: Vector2 = r["p"]
		var t: Vector2 = r["t"]
		var to: Vector2 = t - p
		var step: float = NAR_SPEED * dt
		if to.length() <= step + 0.5:
			nars.remove_at(k)
			_nar_impact(t, int(r["c"]))
			continue
		r["p"] = p + to.normalized() * step
		r["z"] = maxf(0.0, float(r["z"]) - dt * 12.0)


func _nar_impact(p: Vector2, by: int) -> void :
	gw.fx.spawn("explosion_s", p.round(), 6)
	if gw._on_screen(p, 60.0):
		gw.fx.debris_burst(p.round(), 2, false)
	Sfx.play("expl_small", p, -6.0)
	for u: Unit in gw.army._near(p, NAR_R + 3.0):
		if u.alive() and u.country_id != by and u.pos.distance_to(p) <= NAR_R + 3.0:
			cas_stats[2] = int(cas_stats[2]) + 1
			gw.army._damage(u, NAR_DMG if u.pos.distance_to(p) <= NAR_R * 0.6 else NAR_DMG * 0.5, by)
	for a2: Aircraft in aircraft:
		if a2.state != Aircraft.State.DEAD and not a2.airborne() and a2.country_id != by and a2.pos.distance_to(p) <= NAR_R:
			_shot_down(a2, "уничтожен на земле")




func after_load() -> void :
	for c: Country in gw.countries:
		while c.missile_stock.size() < Military.MT_CAP.size():
			c.missile_stock.append(0)
	for a: Aircraft in aircraft:
		if a.type == Aircraft.Type.BOMBER and (a.payload == 1 or a.kab > 0):
			var c2: Country = gw.country_by_id(a.country_id)
			if c2 != null:
				c2.missile_stock[Military.MT_KAB] += a.kab
			a.kab = 0
			a.payload = 0
			a.sortie = 0
			a.kab_q.clear()
