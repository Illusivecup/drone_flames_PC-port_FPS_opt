class_name AirDuel
extends RefCounted









const DETECT_R: float = 340.0
const LEASH_R: float = 700.0
const AAM_CONE: float = 0.9
const AAM_MIN_R: float = 80.0
const HEAD_ON_R: float = 140.0
const BREAK_R: float = 130.0
const CLOSE_R: float = 95.0
const GUN_R: float = 90.0
const GUN_CONE: float = 0.35
const GUN_HIT: int = 9
const AAM_HIT_AIR: int = 40
const AAM_HIT_BREAK: int = 22
const BREAK_TURN: float = 2.4
const FIGHT_TURN: float = 1.6
const PURSUIT_TURN: float = 1.25
const LEAD_MAX: float = 1.5

static var enabled: bool = true
static var vapor: Dictionary = {}

var air: Air
var stats: Dictionary = {"bursts": 0, "gun_kills": 0, "breaks": 0, "fights": 0, "pursuits": 0}


func _init(a: Air) -> void :
	air = a


static func is_attack(a: Aircraft) -> bool:
	return a.type == int(Aircraft.Type.get("ATTACK", -99))



static func aam_of(a: Aircraft) -> int:
	return a.missiles if dogfighter(a) else 0


static func dogfighter(a: Aircraft) -> bool:
	return a.type == Aircraft.Type.FIGHTER or is_attack(a)



static func on_task(a: Aircraft) -> bool:
	if a.sortie > 0 or a.auto_cr > 0 or a.auto_ai or (is_attack(a) and aam_of(a) <= 0):
		return true
	return ("kab_q" in a and not (a.get("kab_q") as Array).is_empty()) or ("cas" in a and int(a.get("cas")) > 0)




func aam_hit(t: Object, m: Dictionary) -> int:
	if not enabled or not (t is Aircraft) or not dogfighter(t as Aircraft):
		return Air.AAM_HIT
	var off: float = absf(wrapf((t as Aircraft).heading - float(m["heading"]), - PI, PI))
	return AAM_HIT_BREAK if off > PI / 3.0 else AAM_HIT_AIR



func can_shoot(a: Aircraft, t: Object) -> bool:
	if not enabled or not (t is Aircraft):
		return true
	var to: Vector2 = (t as Aircraft).pos - a.pos
	if to.length() < AAM_MIN_R or absf(wrapf(to.angle() - a.heading, - PI, PI)) > AAM_CONE:
		return false

	return to.length() <= HEAD_ON_R or absf(wrapf((t as Aircraft).heading - to.angle(), - PI, PI)) <= PI * 0.6


func _anchor(a: Aircraft) -> Vector2:
	return a.patrol_c if a.state == Aircraft.State.PATROL else a.dest



func _target(a: Aircraft) -> Aircraft:
	var best: Aircraft = null
	var bd: float = DETECT_R * DETECT_R
	var anc: Vector2 = _anchor(a)
	for t: Aircraft in air.aircraft:
		if t == a or t.state == Aircraft.State.DEAD or not t.airborne() or not air.mil.hostile(a.country_id, t.country_id):
			continue
		var d: float = t.pos.distance_squared_to(a.pos)
		if d < bd and t.pos.distance_to(anc) <= LEASH_R:
			bd = d
			best = t
	return best



func _threat(a: Aircraft) -> Dictionary:
	var best: Dictionary = {}
	var bd: float = BREAK_R
	for m: Dictionary in air.aams:
		if m["target"] != a or m.has("dp"):
			continue
		var d: float = (m["pos"] as Vector2).distance_to(a.pos)
		if d < bd:
			bd = d
			best = m
	return best



func steer(a: Aircraft, dt: float) -> bool:
	if not enabled or not dogfighter(a) or not a.airborne() or a.base == null or not Air.SPEC.has(a.type):
		return false
	if a.state != Aircraft.State.FLY and a.state != Aircraft.State.ORBIT and a.state != Aircraft.State.PATROL and a.state != Aircraft.State.RTB:
		return false
	var sp: Dictionary = Air.SPEC[a.type]
	var vmax: float = float(sp["speed"])
	var rate: float = float(sp["turn"]) * dt

	if a.fuel < a.pos.distance_to(air.spot_pos(a.base, a.spot)) + Air.RESERVE_PX + 200.0:
		return false
	var want: float = a.heading
	var k: float = 1.0
	var v: float = vmax
	var th: Dictionary = _threat(a)
	if not th.is_empty():

		var mh: float = float(th["heading"])
		var side: float = 1.0 if wrapf(a.heading - mh, - PI, PI) >= 0.0 else -1.0
		want = mh + side * PI * 0.5
		k = BREAK_TURN
		v = vmax * 1.1
		stats["breaks"] = int(stats["breaks"]) + 1
		vapor[a.id] = FxLayer.vt
	else:
		if a.state == Aircraft.State.RTB or on_task(a):
			return false
		var t: Aircraft = _target(a)
		if t == null:
			return false
		var to: Vector2 = t.pos - a.pos
		var d: float = to.length()
		var off: float = wrapf(to.angle() - a.heading, - PI, PI)
		if d > CLOSE_R or absf(off) < 0.3:

			var tv: Vector2 = Vector2.from_angle(t.heading) * t.speed
			var lead: Vector2 = t.pos + tv * clampf(d / Air.AAM_SPEED, 0.0, LEAD_MAX)
			want = (lead - a.pos).angle()
			k = PURSUIT_TURN
			stats["pursuits"] = int(stats["pursuits"]) + 1
		else:


			var side2: float = 1.0 if off >= 0.0 else -1.0
			if Hash32.h2(a.id * 31 + t.id, int(air.gw.game_time / 4.0), 316) % 4 == 0:
				side2 = - side2
			want = a.heading + side2 * PI * 0.5
			k = FIGHT_TURN
			v = vmax * 0.85
			stats["fights"] = int(stats["fights"]) + 1
			vapor[a.id] = FxLayer.vt
	a.h = move_toward(a.h, float(sp["h"]), 3.0 * dt)
	a.fuel -= maxf(a.speed, 6.0) * dt * (1.0 + 0.3 * (k - 1.0))
	air._turn(a, want, rate * k)
	a.speed = move_toward(a.speed, v, 12.0 * dt)
	a.pos += Vector2.from_angle(a.heading) * a.speed * dt
	return true




func scan() -> void :
	if not enabled:
		return
	for a: Aircraft in air.aircraft:
		if not dogfighter(a) or not a.airborne() or a.state == Aircraft.State.DEAD:
			continue

		if (roundi(air.gw.game_time * 2.0) + a.id) % 2 != 0:
			continue
		for t2: Aircraft in air.aircraft:
			if t2 == a or t2.state == Aircraft.State.DEAD or not t2.airborne() or not air.mil.hostile(a.country_id, t2.country_id):
				continue
			var to: Vector2 = t2.pos - a.pos
			if to.length() > GUN_R or absf(wrapf(to.angle() - a.heading, - PI, PI)) > GUN_CONE:
				continue
			stats["bursts"] = int(stats["bursts"]) + 1
			air.tracers.append([a.pos, t2.pos, air.gw.game_time + 0.2])
			air.tracers.append([a.pos + Vector2.from_angle(a.heading + PI * 0.5) * 2.0, t2.pos + Vector2(1, -1), air.gw.game_time + 0.12])
			Sfx.play("mg_burst", a.pos, -4.0)
			if air.gw.rng.chance(GUN_HIT):
				stats["gun_kills"] = int(stats["gun_kills"]) + 1
				air._shot_down(t2, "сбит огнём пушки")
			break
