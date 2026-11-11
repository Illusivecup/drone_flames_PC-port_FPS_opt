class_name Aircraft
extends RefCounted



enum Type{BOMBER, FIGHTER, HELI, ATTACK}
enum State{PARKED, TAXI, ROLL, LIFT, FLY, ORBIT, HOVER, PATROL, RTB, LAND, DEAD}

var id: int = 0
var type: int = Type.FIGHTER
var country_id: int = 0
var base: Facility
var spot: int = -1
var state: int = State.PARKED
var pos: Vector2 = Vector2.ZERO
var heading: float = 0.0
var speed: float = 0.0
var h: float = 0.0
var frame: int = 0
var dest: Vector2 = Vector2.ZERO
var taxi: Array[Vector2] = []
var fuel: float = 0.0
var missiles: int = 0
var level: int = 1
var service_t: float = 0.0
var patrol_c: Vector2 = Vector2.ZERO
var patrol_ang: float = 0.0
var fire_cd: float = 0.0
var after_land: int = -1
var pylon: int = 0
var pylon_n: int = 0

var payload: int = 0
var kab: int = 0
var sortie: int = 0
var sortie_target: Vector2 = Vector2.ZERO
var sortie_release: Vector2 = Vector2.ZERO
var sortie_n: int = 0
var sortie_i: int = 0
var sortie_auto: bool = false
var kab_rel_t: float = 0.0


var auto_cr: int = 0
var auto_cr_t: float = 0.0
var auto_cr_dest: Vector2 = Vector2.ZERO

var auto_ai: bool = false
var auto_tgt: Vector2 = Vector2.ZERO


var resume: int = 0
var auto_n: int = 0
var resume_p: Vector2 = Vector2.ZERO
var flares_used: int = 0

var kab_q: Array[Vector2] = []
var nar: int = 0
var cas: int = 0
var cas_p: Vector2 = Vector2.ZERO
var cas_pass: int = 0
var cas_dir: Vector2 = Vector2.RIGHT
var gun_cd: float = 0.0


var cr_pend: int = 0
var cr_aim: Vector2 = Vector2.ZERO


var cr_q_job: bool = false


func airborne() -> bool:
	return h >= 1.0


func update_frame() -> void :
	var deg: float = rad_to_deg(heading)
	if absf(wrapf(deg - frame * 22.5, -180.0, 180.0)) > 14.0:
		frame = posmod(roundi(deg / 22.5), 16)
