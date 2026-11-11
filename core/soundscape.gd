class_name Soundscape
extends RefCounted












const GRID_X: int = 12
const GRID_Y: int = 22
const SAMPLE_DT: float = 0.75
const WAR_DT: float = 0.5
const MAX_BEDS: int = 4
const FIRE_WIN: float = 8.0
const STALE_T: float = 12.0
const FOG_W: float = 0.3
const CLOSE_K: float = 1.05
const BED_K: float = 1.8
const RAMP_UP: float = 0.035
const RAMP_DN: float = 0.05
const CLOSE_UP: float = 0.1
const CLOSE_DN: float = 0.15
const NATURE_BEDS: Dictionary = {
	"birds": ["birds_day_loop", 0.0], "crickets": ["crickets_night_loop", -1.0], "wind": ["ambient_wind_loop", -3.0], 
	"surf": ["surf_loop", 0.0], "river": ["river_loop", -1.0], "town": ["town_hum_loop", -1.0], 
	"industry": ["industry_hum_loop", -2.0], 
}
const INDUSTRY: Array = [Facility.Kind.REFINERY, Facility.Kind.POWER_PLANT, Facility.Kind.CIV_FACTORY, 
	Facility.Kind.DRONE_FACTORY, Facility.Kind.MISSILE_FACTORY, Facility.Kind.AD_MFG, Facility.Kind.MINE, 
	Facility.Kind.SAWMILL, Facility.Kind.OIL_RIG]

var sfx: Sfx
var gw: GameWorld
var weights: Dictionary = {}
var war: bool = false
var intensity: float = 0.0
var front: Vector2 = Vector2.INF
var d_front: float = INF
var front_vis: bool = false
var near: float = 0.0
var heat: float = 0.0
var fire: float = 0.0
var tick_us: int = 0
var sample_us: int = 0
var war_us: int = 0
var _sample_t: float = 0.0
var _war_t: float = 0.0
var _boom_t: float = 3.0
var booms: int = 0
var navy: NavySfx = null
var air: AirSfx = null


func _init(owner: Sfx, world: GameWorld) -> void :
	sfx = owner
	gw = world
	navy = NavySfx.new(owner, world)
	air = AirSfx.new(owner, world)


func stop() -> void :
	if navy != null:
		navy.stop()
	if air != null:
		air.stop()
	for key: String in NATURE_BEDS:
		sfx.bed(key, String(NATURE_BEDS[key][0]), Sfx.SILENT_DB)
	for key2: String in ["cannonade", "battle_mid", "battle_close"]:
		sfx.bed(key2, "", Sfx.SILENT_DB)


func tick(dt: float) -> void :
	if not is_instance_valid(gw) or gw.data == null or not gw.is_inside_tree():
		stop()
		return
	var cam: Camera2D = sfx._listener_cam()
	if cam == null:
		return
	var us: int = Time.get_ticks_usec()
	Sfx.speed = gw.time_scale
	_sample_t -= dt
	if _sample_t <= 0.0:
		_sample_t = SAMPLE_DT
		var u0: int = Time.get_ticks_usec()
		_sample(cam)
		sample_us = Time.get_ticks_usec() - u0
	_war_t -= dt
	if _war_t <= 0.0:
		_war_t = WAR_DT
		var u1: int = Time.get_ticks_usec()
		_war_update(cam)
		war_us = Time.get_ticks_usec() - u1
	_apply(dt, cam)
	if navy != null:
		navy.tick(dt)
	if air != null:
		air.tick(dt)
	tick_us = Time.get_ticks_usec() - us



func _sample(cam: Camera2D) -> void :
	var z: float = maxf(cam.zoom.x, 0.01)
	var vs: Vector2 = cam.get_viewport_rect().size / z
	var tl: Vector2 = cam.position - vs * 0.5
	var d: WorldData = gw.data
	var cell: float = float(GameWorld.CELL)
	var n: int = 0
	var sea: int = 0
	var shore: int = 0
	var river: int = 0
	var nat: float = 0.0
	var mount: float = 0.0
	var town: int = 0
	var ind: int = 0
	for j in GRID_Y:
		var y: int = floori((tl.y + (j + 0.5) / GRID_Y * vs.y) / cell)
		for i in GRID_X:
			var x: int = floori((tl.x + (i + 0.5) / GRID_X * vs.x) / cell)
			if not d.inside(x, y):
				continue
			n += 1
			var b: int = d.get_biome(x, y)
			if d.has_flag(x, y, WorldData.F_CITY):
				town += 1
				continue
			match b:
				Biome.DEEP, Biome.OCEAN:
					sea += 1
				Biome.SHALLOW, Biome.COAST:
					shore += 1
				Biome.RIVER:
					river += 1
				Biome.SAND:
					shore += 1
					nat += 0.3
				Biome.GRASS, Biome.FIELD, Biome.GARDEN, Biome.STEPPE:
					nat += 1.0
				Biome.FOREST, Biome.PINE:
					nat += 1.3
				Biome.HILLS:
					nat += 0.7
					mount += 0.5
				Biome.ROCK, Biome.SNOW:
					mount += 1.0
				Biome.STREET, Biome.YARD, Biome.PLAZA:
					town += 1
				Biome.INDUSTRIAL:
					ind += 1
	var fac: int = 0
	if gw.mil != null:
		var r: = Rect2(tl - vs * 0.15, vs * 1.3)
		for f: Facility in gw.mil.facilities:
			if INDUSTRY.has(f.kind) and r.has_point(f.center_px()) and gw.mil.alive(f):
				fac += 1
	var fn: float = maxf(1.0, float(n))
	var zf: float = clampf((1.0 - z) / 0.75, 0.0, 1.0)
	var close: float = 1.0 - 0.75 * zf
	var night: float = gw.night.night_factor() if gw.night != null else 0.0
	var natf: float = clampf(nat / fn * 1.3, 0.0, 1.0)
	var water: float = float(sea + shore) / fn
	var land: float = 1.0 - (float(sea + shore + river) / fn)
	weights = {
		"birds": natf * (1.0 - night) * close * (1.0 - clampf(float(town) / fn * 1.5, 0.0, 0.8)), 
		"crickets": natf * night * close * (1.0 - clampf(float(town) / fn * 1.5, 0.0, 0.8)), 
		"wind": clampf(0.15 + mount / fn * 1.2 + float(sea) / fn * 0.3 + zf * 0.55, 0.0, 1.0), 
		"surf": clampf(minf(water, land) * 2.5 + float(shore) / fn * 2.0, 0.0, 1.0) * (1.0 - 0.6 * zf) if n > 0 else 0.0, 
		"river": clampf(float(river) / fn * 14.0, 0.0, 1.0) * close, 
		"town": clampf(float(town) / fn * 2.2, 0.0, 1.0) * (1.0 - 0.6 * zf) * (1.0 - 0.35 * night), 
		"industry": clampf(float(ind) / fn * 5.0 + float(fac) * 0.3, 0.0, 1.0) * (1.0 - 0.8 * zf), 
	}






func _war_update(cam: Camera2D) -> void :
	var p: Country = gw.player
	war = false
	if p != null:
		if not p.eliminated:
			war = not p.at_war.is_empty()
		else:
			for c: Country in gw.countries:
				if not c.eliminated and not c.at_war.is_empty():
					war = true
					break
	var acc: = Vector2.ZERO
	var wsum: float = 0.0
	var dmin: float = INF
	var dvis: bool = false
	var total: float = 0.0
	var close_w: float = 0.0
	heat = 0.0
	if war:
		for e: Array in sfx.fire_events(FIRE_WIN):
			var pos: Vector2 = e[2]
			var vis: bool = bool(e[3])
			var w: float = float(e[1]) * (1.0 if vis else FOG_W)
			var k: float = sfx._dist_k(pos)
			total += w
			var ww: float = w / (0.5 + maxf(k, 0.0))
			acc += pos * ww
			wsum += ww
			if vis and k <= CLOSE_K:
				close_w += float(e[1])
			if k < dmin:
				dmin = k
				dvis = vis
		var bw: BattleWatch = gw.battle_watch
		if bw != null:
			for kc: Vector2i in bw.cells:
				var c: Array = bw.cells[kc]
				if gw.game_time - float(c[1]) > STALE_T:
					continue
				var h: float = bw.heat_at(kc)
				if h < 1.0:
					continue
				var pos2: Vector2 = Vector2(float(c[2]), float(c[3])) / float(c[4]) if float(c[4]) > 0.0 else (Vector2(kc) + Vector2(0.5, 0.5)) * BattleWatch.CELL_PX
				var vis2: bool = sfx._visible(pos2, false)
				var hw: float = h * (1.0 if vis2 else FOG_W)
				heat += hw
				var k2: float = sfx._dist_k(pos2)
				var ww2: float = hw * 0.2 / (0.5 + maxf(k2, 0.0))
				acc += pos2 * ww2
				wsum += ww2
				if k2 < dmin:
					dmin = k2
					dvis = vis2
	fire = total / FIRE_WIN
	var target: float = 0.0
	if war and (fire > 0.02 or heat > 1.0):
		target = clampf(0.55 * tanh(fire / 1.5) + 0.45 * tanh(heat / 20.0), 0.0, 1.0)
	intensity = move_toward(intensity, target, RAMP_UP if target > intensity else RAMP_DN)
	if wsum > 0.0:
		front = acc / wsum
	elif intensity <= 0.01:
		front = Vector2.INF
	d_front = dmin if dmin < INF else (sfx._dist_k(front) if front.is_finite() and intensity > 0.01 else INF)
	front_vis = dvis if dmin < INF else front_vis

	var z: float = cam.zoom.x
	var close_t: float = clampf(close_w / FIRE_WIN / 1.2, 0.0, 1.0) * clampf((z - 0.35) / 0.4, 0.0, 1.0)
	near = move_toward(near, close_t, CLOSE_UP if close_t > near else CLOSE_DN)


func _db(w: float) -> float:
	return linear_to_db(w) if w > 0.04 else Sfx.SILENT_DB


func _apply(dt: float, cam: Camera2D) -> void :


	var calm: float = (1.0 - 0.85 * near) * (1.0 - 0.45 * intensity)
	var keys: Array = weights.keys()
	keys.sort_custom( func(a: String, b: String) -> bool: return float(weights[a]) > float(weights[b]))
	var max_beds: int = MAX_BEDS if intensity < 0.3 else 2
	for i in keys.size():
		var key: String = keys[i]
		var w: float = float(weights[key]) if i < max_beds else 0.0
		if key != "wind" and key != "surf":
			w *= calm
		var db: float = _db(w)
		sfx.bed(key, String(NATURE_BEDS[key][0]), db + float(NATURE_BEDS[key][1]) if db > Sfx.SILENT_DB else Sfx.SILENT_DB)


	var zf: float = clampf((1.0 - cam.zoom.x) / 0.75, 0.0, 1.0)
	var can_db: float = Sfx.SILENT_DB
	var mid_db: float = Sfx.SILENT_DB
	var close_db: float = _db(near * (0.4 + 0.6 * intensity)) - 2.0 if near > 0.04 else Sfx.SILENT_DB
	if war and intensity > 0.03 and d_front < INF:
		var df: float = d_front
		var fog: float = 0.0 if front_vis else -8.0
		if df <= BED_K:
			can_db = _db(intensity) - maxf(0.0, df - 1.0) * 10.0 + fog + 2.0 * zf - 7.0 * near
			if front_vis and df <= 1.2 and near < 0.5:
				mid_db = _db(intensity * (1.0 - near * 2.0)) - 6.0 - maxf(0.0, df - 1.0) * 8.0
		if df > 1.0:
			_boom_t -= dt
			if _boom_t <= 0.0:
				_boom_t = randf_range(3.0, 9.0) / (0.3 + intensity) * Sfx._speed_mult()
				var src: Vector2 = front + Vector2(randf_range(-150.0, 150.0), randf_range(-150.0, 150.0))
				var ids: Array = ["far_boom", "far_boom", "expl_far", "artillery_far"]
				Sfx.far(String(ids[randi() % ids.size()]), src, -10.0 - 6.0 * (1.0 - intensity) - clampf((df - 1.0) * 1.5, 0.0, 12.0) + fog)
				booms += 1
	sfx.bed("cannonade", "cannonade_loop", can_db, front)
	sfx.bed("battle_mid", "ambient_battle_loop", mid_db, front)
	sfx.bed("battle_close", "battle_close_loop", close_db, front)



func state() -> Dictionary:
	var w: Dictionary = {}
	for k: String in weights:
		w[k] = snappedf(float(weights[k]), 0.01)
	return {"war": war, "intensity": snappedf(intensity, 0.01), "heat": snappedf(heat, 0.1), "fire": snappedf(fire, 0.01), 
		"front_vis": front_vis, "d_front": snappedf(d_front, 0.01) if d_front < INF else -1.0, "near": snappedf(near, 0.01), 
		"weights": w, "booms": booms, "tick_us": tick_us, "sample_us": sample_us, "war_us": war_us, 
		"navy": navy.state() if navy != null else {}}
