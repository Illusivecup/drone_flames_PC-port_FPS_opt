class_name AirSfx
extends RefCounted












const KAB_KIND: int = 3

const FAM: Dictionary = {
	"uav": ["air_uav", "jet_uav_loop", "jet_uav_pass"], 
	"cm": ["air_cm", "cruise_missile_loop", "cruise_missile_pass"], 
	"jet": ["air_jet", "attack_jet_loop", "jet_pass"], 
	"bomber": ["air_bomber", "bomber_loop", "bomber_pass"], 
}
const RUMBLE_KEY: String = "air_rumble"
const LOOP_K: float = 1.9
const FAR_MIN_K: float = 1.3
const PASS_K: float = 0.75
const DUCK_S: float = 2.5
const DUCK_DB: float = -9.0
const KAB_FALL_S: float = 3.2

var sfx: Sfx
var gw: GameWorld
var counts: Dictionary = {"pass": 0, "kab_fall": 0, "rumble_on": 0}
var near_k: Dictionary = {}
var rumble_k: float = INF
var _k: Dictionary = {}
var _duck: Dictionary = {}
var _kab_done: Dictionary = {}


func _init(owner: Sfx, world: GameWorld) -> void :
	sfx = owner
	gw = world


func stop() -> void :
	for f: String in FAM:
		Sfx.loop(String(FAM[f][0]), "", false)
	Sfx.loop(RUMBLE_KEY, "", false)
	_k.clear()
	_kab_done.clear()


func tick(dt: float) -> void :
	var mil: Military = gw.mil if is_instance_valid(gw) else null
	var paused: bool = mil == null or gw.time_scale <= 0.0 or not gw.is_inside_tree() or gw.get_tree().paused
	if paused:
		stop()
		return
	var best: Dictionary = {}
	var far: Array = [INF, Vector2.INF]
	var seen: Dictionary = {}
	for d: Drone in mil.drones:
		if d.state == Drone.State.DONE or not d.airborne() or (d.kind != 1 and d.kind != 2):
			continue
		_source("uav" if d.kind == 2 else "cm", "d%d" % d.id, d.pos, best, far, seen)
	if mil.air != null:
		for a: Aircraft in mil.air.aircraft:
			if a.type == Aircraft.Type.HELI or a.state == Aircraft.State.DEAD or not a.airborne():
				continue
			_source("bomber" if a.type == Aircraft.Type.BOMBER else "jet", "a%d" % a.id, a.pos, best, far, seen)
		_kabs(mil.air)
	for f: String in FAM:
		_duck[f] = maxf(0.0, float(_duck.get(f, 0.0)) - dt)
		var b: Array = best.get(f, [])
		var on: bool = not b.is_empty() and float(b[0]) < LOOP_K
		near_k[f] = float(b[0]) if on else INF
		Sfx.loop(String(FAM[f][0]), String(FAM[f][1]), on, b[1] if on else Vector2.INF, DUCK_DB if float(_duck[f]) > 0.0 else 0.0)
	var r_on: bool = float(far[0]) < float(Sfx.FAR_LOOPS["air_rumble_loop"][1])
	if r_on and rumble_k == INF:
		counts["rumble_on"] = int(counts["rumble_on"]) + 1
	rumble_k = float(far[0]) if r_on else INF
	Sfx.loop(RUMBLE_KEY, "air_rumble_loop", r_on, far[1] if r_on else Vector2.INF)
	if _k.size() > seen.size() + 32:
		for key: String in _k.keys():
			if not seen.has(key):
				_k.erase(key)



func _source(fam: String, key: String, pos: Vector2, best: Dictionary, far: Array, seen: Dictionary) -> void :
	var k: float = sfx._dist_k(pos)
	if k < 0.0:
		return
	seen[key] = true
	var b: Array = best.get(fam, [])
	if b.is_empty() or k < float(b[0]):
		best[fam] = [k, pos]
	if k >= FAR_MIN_K and k < float(far[0]):
		far[0] = k
		far[1] = pos
	var s: Array = _k.get(key, [k, k, false])
	var min_k: float = minf(float(s[1]), k)
	var passed: bool = bool(s[2])
	if not passed and min_k < PASS_K and k > float(s[0]) + 0.02:
		passed = true
		Sfx.play(String(FAM[fam][2]), pos)
		_duck[fam] = DUCK_S
		counts["pass"] = int(counts["pass"]) + 1
	elif passed and k > PASS_K * 2.0:
		passed = false
		min_k = k
	_k[key] = [k, min_k, passed]


func _kabs(air: Air) -> void :
	for d: Drone in air.kabs:
		if d.state == Drone.State.DONE or _kab_done.has(d.id) or d.speed <= 0.0:
			continue
		if d.pos.distance_to(d.target) / d.speed < KAB_FALL_S * maxf(gw.time_scale, 1.0):
			_kab_done[d.id] = true
			Sfx.play("kab_fall", d.target)
			counts["kab_fall"] = int(counts["kab_fall"]) + 1
	if _kab_done.size() > 256:
		var live: Dictionary = {}
		for d2: Drone in air.kabs:
			if _kab_done.has(d2.id):
				live[d2.id] = true
		_kab_done = live
