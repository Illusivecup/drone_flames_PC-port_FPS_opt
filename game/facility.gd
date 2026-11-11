class_name Facility
extends RefCounted



enum Kind{DRONE_FACTORY, AIRFIELD, DRONE_PORT, DP_RAMP, DP_RUNWAY, DP_STORE, TEL, MISSILE_FACTORY, REFINERY, POWER_PLANT, SOLAR, FARM, CIV_FACTORY, MINE, BARRACKS, AD_MFG, AD_SPAAG, AD_SAM, AD_PATRIOT, AD_INT, AD_RADAR, AD_EW, TRENCH_H, TRENCH_V, TEETH_H, TEETH_V, DUGOUT, SAWMILL, OIL_RIG, PORT, PORT_CRANE, RAIL_STATION, SOLAR_FARM, NAVAL_BASE, COASTAL_ASM, URANIUM_MINE, NUCLEAR_PLANT, POLICE_STATION}

var id: int = 0
var kind: int = Kind.DRONE_FACTORY
var police_patrol: bool = false
var country_id: int = 0
var cell: Vector2i = Vector2i.ZERO
var size: Vector2i = Vector2i.ONE
var obj_ids: PackedInt32Array = PackedInt32Array()
var main_obj: int = -1
var parent: Facility = null
var restore_t: float = 0.0


var producing: bool = false
var prod_t: float = 0.0
var flash_until: float = -1.0


var spots: PackedVector2Array = PackedVector2Array()
var spot_owner: Array = []
var parked: Array = []
var modules: Array = []


var reserved: Object = null
var ready_at: float = 0.0
var craters: PackedVector2Array = PackedVector2Array()
var repair_t: float = 0.0
var runway_free_at: float = 0.0


var missiles: int = 2
var reload_t: float = 0.0
var erect_t: float = -1.0
var queued: Array = []
var lower_t: float = 0.0
var lower_sprite: String = ""
var moving: bool = false
var mpos: Vector2 = Vector2.ZERO
var mdest: Vector2 = Vector2.ZERO
var flip: bool = false
var dust_t: float = 0.0
var warned_empty: bool = false
var mpath: Array[Vector2] = []
var home_nw: Vector2i = Vector2i.ZERO


var prod_type: int = 0
var prod_jet: bool = false


var powered: bool = true
var was_alive: bool = true
var fx: Array = []
var arc_next: float = 0.0
var ruined_at: float = -1.0
var fuel_t: float = 0.0


var hp: float = 100.0
var ammo: int = 4
var cd: float = 0.0
var turret: float = 0.0
var alert_t: float = 0.0
var frame_t: float = 0.0
var frame_i: int = 0
var lid_t: float = 0.0
var deposit: Dictionary = {}
var level: int = 1
var upg_t: float = 0.0

var cells: Array[Vector2i] = []
var cell_hp: Dictionary = {}


var army_build: String = ""
var army_no: int = 0
var post_off: bool = false


var halted: bool = false
var stance: int = 0



var auto_refill: bool = true
var filled: bool = false
var prod_refill: bool = false



var pending: Array[Vector2i] = []
var build_t: float = 0.0

var group_id: int = -1

var variant: int = 0


var u_fuel: float = 0.0
var u_hits: int = 0
var u_part: float = 0.0


var mag: int = -1
var mag_t: float = 0.0


var mb: bool = false


func is_line() -> bool:
	return kind == Kind.TRENCH_H or kind == Kind.TEETH_H


func origin_px() -> Vector2:
	return Vector2(cell * 4)


func center_px() -> Vector2:
	return Vector2(cell * 4) + Vector2(size * 4) * 0.5


func runway_ok() -> bool:
	return craters.is_empty()


func is_launcher() -> bool:
	return kind == Kind.DP_RAMP or kind == Kind.DP_RUNWAY
