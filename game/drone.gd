class_name Drone
extends RefCounted


enum State{PARKED, WAIT, TAXI, HOLD, ROLL, BOOST, FLY, DIVE, DONE}
enum End{NONE, HIT, CRASH, DESTROYED}

var id: int = 0
var country_id: int = 0
var airfield: Facility
var launcher: Facility
var boost_t: float = 0.0
var rail_s: float = 0.0
var trail_acc: float = 0.0
var spot: int = -1
var state: int = State.PARKED
var end_reason: int = End.NONE
var pos: Vector2 = Vector2.ZERO
var heading: float = 0.0
var speed: float = 0.0
var h: float = 0.0
var frame: int = 0
var wait_t: float = 0.0
var lifted: bool = false
var dive_h0: float = 8.0
var taxi: Array[Vector2] = []
var route: Array[Vector2] = []
var target: Vector2 = Vector2.ZERO
var route_len: float = 0.0
var flown: float = 0.0
var range_px: float = 0.0
var kind: int = 0
var low: bool = false
var cruise_speed: float = 24.0
var turn_rate: float = PI * 0.25
var cruise_h: float = 8.0
var route_ver: int = 0
var preview: PackedVector2Array = PackedVector2Array()
var preview_at: float = -100.0
var preview_ver: int = -1
var smart_key: String = ""
var smart_ver: int = -1
var smart_noted: bool = false



func update_frame() -> void :
	var deg: float = rad_to_deg(heading)
	if absf(wrapf(deg - frame * 22.5, -180.0, 180.0)) > 14.0:
		frame = posmod(roundi(deg / 22.5), 16)


func airborne() -> bool:
	return h >= 1.0


func remaining_len() -> float:
	var s: float = 0.0
	var p: Vector2 = pos
	for q: Vector2 in route:
		s += p.distance_to(q)
		p = q
	return s
