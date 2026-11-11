class_name Ship
extends RefCounted



enum Hull{LIGHT, MEDIUM, HEAVY}
enum State{IDLE, SAIL, SINK}

var id: int = 0
var c: int = 0
var hull: int = Hull.LIGHT
var mods: Array[String] = []
var name: String = ""
var base: Facility = null
var pos: Vector2 = Vector2.ZERO
var heading: float = 0.0
var speed: float = 0.0
var hp: float = 100.0
var hp_max: float = 100.0
var state: int = State.IDLE
var path: PackedVector2Array = PackedVector2Array()
var pi: int = 0
var ammo: Dictionary = {}
var fires: Array = []
var tgt: int = 0
var order_tgt: int = 0
var gun_cd: float = 0.0
var refit: String = ""
var refit_t: float = 0.0
var sink_t: float = 0.0
var hit_t: float = -99.0
var trail: PackedVector2Array = PackedVector2Array()
var trail_t: float = 0.0
var think_t: float = 0.0
var auto: bool = true
var kills: int = 0
var shot_t: float = -99.0
var aim: float = 0.0
var pd_t: float = -99.0

var fleet: int = 0
var ord: Dictionary = {}
var rf_load: Dictionary = {}
var fresh: bool = false

var spd_cap: float = INF
var vls_t: float = -99.0
var ash_t: float = -99.0
var ciws_busy: float = 0.0
var sam_busy: float = 0.0
var art_t: float = -99.0
var art_aim: float = 0.0

const FIELDS: Array = ["id", "c", "hull", "mods", "name", "base", "pos", "heading", "speed", "hp", "hp_max", "state", "path", "pi", 
	"ammo", "fires", "tgt", "order_tgt", "gun_cd", "refit", "refit_t", "sink_t", "trail", "trail_t", "think_t", "auto", "kills", "fleet", "ord", "rf_load", "fresh"]


func alive() -> bool:
	return state != State.SINK


func has_mod(m: String) -> bool:
	return mods.has(m)


func count_mod(m: String) -> int:
	return mods.count(m)


func dir16() -> int:
	return posmod(roundi(rad_to_deg(heading) / 22.5), 16)


func to_dict() -> Dictionary:
	var d: Dictionary = {}
	for n: String in FIELDS:
		d[n] = get(n)
	return d


static func from_dict(d: Dictionary) -> Ship:
	var s: = Ship.new()
	for n: String in FIELDS:
		if not d.has(n):
			continue
		var v: Variant = d[n]
		if n == "mods":
			s.mods.clear()
			for m: Variant in (v as Array):
				s.mods.append(String(m))
		elif n == "base":
			s.base = v as Facility if v is Facility else null
		else:
			s.set(n, v)
	return s
