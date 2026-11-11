extends RefCounted

















enum {F_PLANE, F_HELI, F_DIVE, F_WING, F_FRAG, F_BIT}

const WK_PLANE: int = 1
const WK_HELI: int = 2
const WK_DRONE: int = 3
const WK_DEBRIS: int = 4
const DIVE_GUN: int = 70
const DIVE_MSL: int = 15
const FRAGS: int = 6
const MAX_FALLS: int = 80

var gw: GameWorld
var falls: Array = []
var stats: Dictionary = {"plane": 0, "heli": 0, "burst": 0, "dive": 0, "ball": 0, "impact": 0, "hit": 0, "wreck": 0}
var gun: bool = false
var _next: int = 1
var _fx_t: float = 0.0


func _init(world: GameWorld) -> void :
	gw = world


func _r() -> float:
	return gw.rng.roll()


func _add(f: Dictionary) -> void :
	if falls.size() >= MAX_FALLS:
		return
	f["id"] = _next
	_next += 1
	falls.append(f)


func _clamp(p: Vector2) -> Vector2:
	var w: float = float(gw.data.w * GameWorld.CELL - 4)
	var h: float = float(gw.data.h * GameWorld.CELL - 4)
	return Vector2(clampf(p.x, 4.0, w), clampf(p.y, 4.0, h)).round()



func plane(a: Aircraft) -> void :
	var heli: bool = a.type == Aircraft.Type.HELI
	var wk: int = WK_HELI if heli else WK_PLANE
	if not a.airborne() or a.h < 1.0:
		_wreck(a.pos.round(), wk, a.country_id, a.type, a.frame)
		return
	var g0: Vector2 = a.pos + Vector2(a.h, a.h)
	var dir: Vector2 = Vector2.from_angle(a.heading)
	var dur: float = (1.8 + _r() * 0.8) if heli else (2.6 + _r() * 1.4)
	var run: float = (6.0 + _r() * 8.0) if heli else maxf(a.speed, 20.0) * dur * (0.45 + _r() * 0.25)
	var side: float = (_r() - 0.5) * run * 0.5
	var g: Vector2 = _clamp(g0 + dir * run + Vector2( - dir.y, dir.x) * side)
	_add({"k": F_HELI if heli else F_PLANE, "c": a.country_id, "src": a.type, "fr": a.frame, "p0": a.pos, "g0": g0, "g": g, 
		"t0": gw.game_time, "dur": dur, "r": 2, "wk": wk, "spin": (1 if _r() < 0.5 else -1)})
	stats["heli" if heli else "plane"] = int(stats["heli" if heli else "plane"]) + 1




func drone(d: Drone, by: int) -> void :
	var hit_gun: bool = gun or by == DroneBrain.BY_POINT
	var g0: Vector2 = d.pos + Vector2(d.h, d.h)
	var dir: Vector2 = Vector2.from_angle(d.heading)
	if gw.rng.chance(DIVE_GUN if hit_gun else DIVE_MSL):
		var dur: float = 1.4 + _r() * 1.0
		var g: Vector2 = _clamp(g0 + dir * maxf(d.speed, 15.0) * dur * (0.4 + _r() * 0.3))
		_add({"k": F_DIVE, "c": d.country_id, "src": d.kind, "fr": d.frame, "p0": d.pos, "g0": g0, "g": g, "t0": gw.game_time, "dur": dur, 
			"r": 2 if d.kind == 1 else 1, "wk": WK_DRONE, "spin": (1 if _r() < 0.5 else -1)})
		var wg: Vector2 = _clamp(g0 + dir * (4.0 + _r() * 8.0) + Vector2( - dir.y, dir.x) * (_r() - 0.5) * 16.0)
		_add({"k": F_WING, "c": d.country_id, "src": d.kind, "fr": d.frame, "p0": d.pos, "g0": g0, "g": wg, "t0": gw.game_time, "dur": dur + 1.2 + _r(), 
			"r": 0, "wk": 0, "spin": (1 if _r() < 0.5 else -1)})
		stats["dive"] = int(stats["dive"]) + 1
		return
	for i in 3:
		var bg: Vector2 = _clamp(g0 + Vector2.from_angle(_r() * TAU) * (3.0 + _r() * 9.0) + dir * 4.0)
		_add({"k": F_BIT, "c": d.country_id, "src": d.kind, "fr": i, "p0": d.pos, "g0": g0, "g": bg, "t0": gw.game_time, "dur": 1.6 + _r() * 1.4, 
			"r": 0, "wk": 0, "spin": 1})
	stats["burst"] = int(stats["burst"]) + 1





func ballistic(m: Missile, at: Vector2) -> void :
	var g0: Vector2 = m.ground()
	for i in FRAGS:
		var big: bool = i < 2
		var g: Vector2 = _clamp(g0 + Vector2.from_angle(_r() * TAU) * ((6.0 + _r() * 30.0) if big else (4.0 + _r() * 44.0)))
		_add({"k": F_FRAG, "c": m.country_id, "src": -1, "fr": i, "p0": at, "g0": g0, "g": g, "t0": gw.game_time, 
			"dur": 2.6 + _r() * 2.2 + (0.0 if big else 0.8), "r": 1 if big else 0, "wk": WK_DEBRIS if i == 0 else 0, "spin": (1 if i % 2 == 0 else -1)})
	stats["ball"] = int(stats["ball"]) + 1



static func at(f: Dictionary, now: float) -> Array:
	var u: float = clampf((now - float(f["t0"])) / maxf(0.01, float(f["dur"])), 0.0, 1.0)
	var g0: Vector2 = f["g0"]
	var gt: Vector2 = g0.lerp(f["g"], u)
	var off: Vector2 = (f["p0"] as Vector2) - g0
	return [gt + off * (1.0 - u * u), gt, u]


func update(_dt: float) -> void :
	if falls.is_empty():
		return
	var now: float = gw.game_time
	_fx_t += _dt
	var puff: bool = _fx_t >= 0.12
	if puff:
		_fx_t = 0.0
	for k in range(falls.size() - 1, -1, -1):
		var f: Dictionary = falls[k]
		if now - float(f["t0"]) >= float(f["dur"]):
			falls.remove_at(k)
			_impact(f)
		elif puff:
			_trail(f, now)



func _trail(f: Dictionary, now: float) -> void :
	var kf: int = f["k"]
	if kf == F_BIT or kf == F_WING:
		return
	if now - float(f["t0"]) < 0.3:
		return
	var p: Vector2 = at(f, now - 0.3)[0]
	if gw.fx == null or not gw._on_screen(p, 60.0):
		return
	var j: = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
	var sm: AnimatedSprite2D = gw.fx.spawn("smoke_pop" if gw.fx.atlas_of.has("smoke_pop") else "trail_puff", (p + j).round(), 5)
	if sm != null and kf != F_FRAG:
		sm.modulate = Color(0.32, 0.29, 0.27, 0.9)
	if kf == F_PLANE or kf == F_HELI or (kf == F_FRAG and int(f["fr"]) < 2):
		if randf() < 0.6:
			gw.fx.spawn("hit_small" if gw.fx.atlas_of.has("hit_small") else "explosion_s", (p + j * 0.5).round(), 6)


func _impact(f: Dictionary) -> void :
	var g: Vector2 = f["g"]
	var cell: = Vector2i(floori(g.x / GameWorld.CELL), floori(g.y / GameWorld.CELL))
	if not gw.data.inside(cell.x, cell.y):
		return
	var water: bool = Biome.is_water(gw.data.get_biome(cell.x, cell.y))
	var kf: int = f["k"]
	stats["impact"] = int(stats["impact"]) + 1
	if gw.fx != null:
		if water:
			gw.fx.spawn("splash", g, 4)
			if gw.aftermath != null:
				gw.aftermath._sink(g, int(f["wk"]) if int(f["wk"]) > 0 else WK_DEBRIS, int(f["src"]), int(f["fr"]))
		elif kf == F_PLANE or kf == F_HELI:
			gw.fx.spawn("explosion_l" if int(f["src"]) == Aircraft.Type.BOMBER else "explosion_m", g, 6)
			gw.fx.debris_burst(g, 6, false)
			Sfx.play("expl_big", g, -2.0)
		elif kf == F_DIVE:
			gw.fx.spawn("explosion_m" if int(f["src"]) == 1 else "explosion_s", g, 6)
			gw.fx.debris_burst(g, 3, false, true)
			Sfx.play("expl_small", g, -3.0)
		elif kf == F_FRAG and int(f["r"]) > 0:
			gw.fx.spawn("explosion_s", g, 6)
			gw.fx.debris_burst(g, 2, false, true)
		else:
			gw.fx.spawn("dust_s", g, 4)
	if water:
		return
	var r: int = f["r"]
	if r > 0:
		gw._apply_strike(cell, r, "crater_m" if r >= 2 else "crater_s", 6.0 * r, 0)
		stats["hit"] = int(stats["hit"]) + 1
		if gw.fx != null:
			var until: float = gw.game_time + (40.0 if r >= 2 else 20.0)
			gw.fx.spawn("fire_small", g + Vector2(0, -1), 4, until, true)
			gw.fx.spawn("smoke_black_loop", g + Vector2(0, -10), 5, until, true)
			if kf == F_PLANE:
				gw.fx.spawn("fire_small", g + Vector2(3, 1), 4, until - 8.0, true)
	if int(f["wk"]) > 0:
		_wreck(g, int(f["wk"]), int(f["c"]), int(f["src"]), int(f["fr"]))




func _wreck(p: Vector2, wk: int, c: int, src: int, fr: int) -> void :
	var am: Variant = gw.aftermath
	if am == null or not am._land(p):
		return
	var cx: int = floori(p.x / GameWorld.CELL)
	var cy: int = floori(p.y / GameWorld.CELL)
	var o: int = gw.data.get_owner_id(cx, cy)
	var oc: Country = gw.country_by_id(o)
	var col: int = o if oc != null and not oc.city_ids.is_empty() else c
	am.add_air_wreck(p.round(), wk, col, src, fr, - _next)
	_next += 1
	stats["wreck"] = int(stats["wreck"]) + 1


func save_state() -> Dictionary:
	return {"v": 1, "falls": falls, "stats": stats, "next": _next, "fx_t": _fx_t}


func load_state(d: Dictionary) -> void :
	falls.clear()
	for fv: Variant in d.get("falls", []):
		if not (fv is Dictionary):
			continue
		var f: Dictionary = fv
		falls.append({"id": int(f.get("id", 0)), "k": int(f.get("k", 0)), "c": int(f.get("c", 0)), "src": int(f.get("src", -1)), "fr": int(f.get("fr", 0)), 
			"p0": Vector2(f.get("p0", Vector2.ZERO)), "g0": Vector2(f.get("g0", Vector2.ZERO)), "g": Vector2(f.get("g", Vector2.ZERO)), 
			"t0": float(f.get("t0", 0.0)), "dur": float(f.get("dur", 1.0)), "r": int(f.get("r", 0)), "wk": int(f.get("wk", 0)), "spin": int(f.get("spin", 1))})
	var sd: Variant = d.get("stats", {})
	if sd is Dictionary:
		for k2: Variant in sd:
			stats[String(k2)] = int(sd[k2])
	_next = int(d.get("next", 1))
	_fx_t = float(d.get("fx_t", 0.0))
