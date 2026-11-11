class_name Missile
extends RefCounted






enum State{IGNITE, FLIGHT, DONE}

const IGNITE_TIME: float = 0.6

var id: int = 0
var country_id: int = 0
var tel: Facility
var state: int = State.IGNITE
var launch: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var dist: float = 0.0
var flight_time: float = 1.0
var apex: float = 100.0
var alt0: float = 0.0
var apex_km: float = 30.0
var t: float = 0.0
var frame: int = 12
var trail_acc: float = 0.0
var last_screen: Vector2 = Vector2.ZERO
var prev_screen: Vector2 = Vector2.ZERO
var hyper: bool = false
var whistled: bool = false


func u() -> float:
	return clampf((t - IGNITE_TIME) / flight_time, 0.0, 1.0)


func ground() -> Vector2:
	var k: float = u()
	return launch.lerp(target, k * k * (3.0 - 2.0 * k))


func alt() -> float:
	var k: float = u()
	return 4.0 * apex * k * (1.0 - k) + alt0 * (1.0 - k)



func screen_pos() -> Vector2:
	return ground() - Vector2(0.0, alt())


func time_left() -> float:
	return maxf(0.0, IGNITE_TIME + flight_time - t)


func alt_km() -> float:
	var k: float = u()
	return apex_km * 4.0 * k * (1.0 - k)



func mach() -> float:
	if state == State.IGNITE:
		return 0.0
	var k: float = u()
	if hyper:
		return lerpf(5.0, 8.0, minf(1.0, k * 3.0))
	if k < 0.25:
		return lerpf(0.3, 5.5, k / 0.25)
	if k < 0.5:
		return lerpf(5.5, 5.0, (k - 0.25) / 0.25)
	return lerpf(5.0, 6.5, (k - 0.5) / 0.5)
