class_name Vfx
extends RefCounted













const ATLAS_PNG: = "res://assets/sprites/atlas_vfx19.png"
const ATLAS_JSON: = "res://assets/sprites/atlas_vfx19.json"
const MAX_COLUMNS: Array = [5, 9, 12]
const MAX_PARTS: Array = [100, 200, 300]




const MARK_CAP: int = 180
const LIFE_SCORCH: float = 420.0
const LIFE_CRATER: float = 600.0
const LIFE_WRECK: float = 900.0



const SCAR_CAP: int = 200
const SCAR_T1: float = 60.0
const SCAR_T2: float = 600.0



const LIFE_KEEP: float = 300.0
const QUIET_R: float = 64.0
const SMOULDER: float = 240.0
const MERGE_R: float = 40.0


static var wind: Vector2 = Vector2(6.0, 1.5)

static var cost_us: int = 0
static var cost_parts: Dictionary = {}


static func cost(key: String, us: int) -> void :
	cost_us += us
	cost_parts[key] = int(cost_parts.get(key, 0)) + us

var gw: GameWorld
var atlas: SpriteAtlas
var tex: Texture2D
var marks: Array = []
var scars: Array = []
var marks_ver: int = 0
var columns: Array = []
var ground: VfxGround
var clouds: VfxClouds
var air: VfxAir
var glow: VfxGlow
var blast: VfxBlast


var units_night: UnitsLayer


var focus_pts: = PackedVector2Array()
var focus_dim: bool = false


var army_pts: = PackedVector4Array()
var _seen_t: float = 0.0
var _fire_t: float = 0.0


static func make(world: GameWorld) -> Vfx:
	var v: = Vfx.new()
	v.gw = world
	v._load_atlas()
	v.ground = VfxGround.new()
	v.ground.name = "VfxGround"
	v.ground.vfx = v
	v._insert(v.ground, "Ground", 1)
	v.clouds = VfxClouds.new()
	v.clouds.name = "VfxClouds"
	v.clouds.vfx = v
	v._insert(v.clouds, "TerritoryBorder", 0)
	v.air = VfxAir.new()
	v.air.name = "VfxAir"
	v.air.vfx = v
	v._insert(v.air, "Eco", 0)
	v.glow = VfxGlow.new()
	v.glow.name = "VfxGlow"
	v.glow.vfx = v
	v._insert(v.glow, "Night", 1)
	v.blast = VfxBlast.new()
	v.blast.name = "VfxBlast"
	v.blast.vfx = v
	v._insert(v.blast, "Fx", 1)
	v.units_night = UnitsLayer.new()
	v.units_night.name = "UnitsNight"
	v.units_night.gw = world
	v.units_night.night_pass = true
	v._insert(v.units_night, "VfxGlow", 1)
	v.set_meta("fauna", (load("res://world/fauna_layer.gd") as GDScript).call("make", world))


	for nm: String in ["MapIcons", "Top"]:
		var nd: Node = world.get_node_or_null(nm)
		if nd != null and nd.get_index() < v.units_night.get_index():
			world.move_child(nd, v.units_night.get_index() - 1)
	return v





func set_focus(points: Array, dim: bool = false) -> void :
	focus_pts.resize(0)
	for p: Variant in points:
		if p is Vector2:
			focus_pts.append(p)
	focus_dim = dim



func _insert(n: Node, anchor: String, after: int) -> void :
	gw.add_child(n)
	var a: Node = gw.get_node_or_null(anchor)
	if a != null:
		gw.move_child(n, a.get_index() + after if after > 0 else a.get_index())


func _load_atlas() -> void :
	atlas = SpriteAtlas.load_atlas(ATLAS_PNG, ATLAS_JSON, true)
	if atlas.sprites.is_empty() and FileAccess.file_exists(ATLAS_JSON):

		var img: = Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PNG))
		if img != null and not img.is_empty():
			atlas.texture = ImageTexture.create_from_image(img)
			atlas.sprites = (JSON.parse_string(FileAccess.get_file_as_string(ATLAS_JSON)) as Dictionary)["sprites"]
	tex = atlas.texture


func has(n: String) -> bool:
	return atlas.sprites.has(n)


static func level() -> int:
	return clampi(GameConfig.fx_level, 0, 2)



func reset() -> void :
	marks.clear()
	scars.clear()
	marks_ver += 1
	columns.clear()
	focus_pts.resize(0)
	focus_dim = false
	army_pts.resize(0)
	if air != null:
		air.reset()
	if ground != null:
		ground.reset()
	if blast != null:
		blast.reset()






func on_impact(p: Vector2, size: int) -> void :
	if gw == null or gw.data == null:
		return
	var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	if not gw.data.inside(c.x, c.y):
		return
	DmgStages.on_impact(gw, p, size)
	if has_meta("fauna"):
		(get_meta("fauna") as Node).call("blast", p, size)
	var water: bool = Biome.is_water(gw.data.get_biome(c.x, c.y)) and not gw.data.has_flag(c.x, c.y, WorldData.F_BRIDGE)
	if not water and (size > 0 or (c.x + c.y) % 2 == 0):
		var v: String = "a" if (c.x * 7 + c.y * 13) % 2 == 0 else "b"
		add_mark("scorch_%s%s" % [["s", "m", "l"][clampi(size, 0, 2)], v], p.round())
		if size == 1 and _kab_at(p):
			add_mark("crater_l", p.round())
	if air != null:
		air.impact(p, size, water)





var _kab_n: int = 0


func _kab_hits() -> int:
	if gw.mil == null or gw.mil.air == null:
		return 0
	var n: int = 0
	for e: Variant in gw.mil.air.kab_stats.values():
		if e is Array and (e as Array).size() > 1:
			n += int(e[1])
	return n


func _kab_at(_p: Vector2) -> bool:
	var n: int = _kab_hits()
	if n > _kab_n:
		_kab_n = n
		return true
	return false



func on_burn(f: Facility) -> void :
	if f == null or f.is_line():
		return
	if blast != null:
		blast.on_ruin(f)
	var k: int = f.kind
	var oil: bool = k == Facility.Kind.REFINERY or k == Facility.Kind.OIL_RIG or k == Facility.Kind.PORT
	var big: bool = oil or k == Facility.Kind.POWER_PLANT or k == Facility.Kind.NUCLEAR_PLANT or k == Facility.Kind.MISSILE_FACTORY or k == Facility.Kind.DRONE_FACTORY or k == Facility.Kind.CIV_FACTORY
	var burn: float = Military.REFINERY_BURN + 40.0 if oil else (70.0 if big else 40.0)
	add_column(f.center_px() + Vector2(0, - float(f.size.y) * 1.0), 1.0 if oil else (0.8 if big else 0.5), burn, oil, f.id)



func add_column(p: Vector2, pw: float, burn: float, oil: bool = false, fid: int = -1) -> void :
	var t: float = gw.game_time
	for col: Dictionary in columns:
		if (col["p"] as Vector2).distance_to(p) < MERGE_R:
			col["pow"] = minf(1.0, maxf(float(col["pow"]), pw) + 0.12)
			col["burn"] = maxf(float(col["burn"]), t + burn)
			col["end"] = maxf(float(col["end"]), t + burn + SMOULDER)
			col["oil"] = bool(col["oil"]) or oil
			return
	var cap: int = int(MAX_COLUMNS[level()])
	if columns.size() >= cap:

		var wi: int = 0
		var ws: float = INF
		for i in columns.size():
			var cc: Dictionary = columns[i]
			var s: float = float(cc["pow"]) + (2.0 if float(cc["burn"]) > t else 0.0)
			if s < ws:
				ws = s
				wi = i
		if ws > pw + 2.0:
			return
		columns.remove_at(wi)
	columns.append({"p": p.round(), "t0": t, "burn": t + burn, "end": t + burn + SMOULDER, "pow": pw, "oil": oil, "acc": 0.0, "fid": fid})


func add_mark(n: String, p: Vector2) -> void :
	var life: float = LIFE_SCORCH
	if n.begins_with("crater"):
		life = LIFE_CRATER
	elif n.begins_with("wreck"):
		life = LIFE_WRECK
	var seen: bool = not n.begins_with("wreck") or gw.vision == null or gw.vision.sees(p)
	var keep: bool = n.begins_with("crater") and scar_ok(p)
	if keep:
		life = LIFE_KEEP
	if n.begins_with("crater") or n.begins_with("scorch"):
		for m0: Array in marks:
			if m0.size() > 5 and bool(m0[5]) and (m0[1] as Vector2).distance_squared_to(p) < QUIET_R * QUIET_R:
				m0[2] = maxf(float(m0[2]), gw.game_time - float(m0[3]) * 0.3)
	marks.append([n, p, gw.game_time, life, seen, keep])
	while marks.size() > MARK_CAP:
		if marks[0].size() > 5 and bool(marks[0][5]):
			_add_scar(String(marks[0][0]), marks[0][1], gw.game_time)
		marks.remove_at(0)
	marks_ver += 1



func mark_alpha(m: Array) -> float:
	var u: float = (gw.game_time - float(m[2])) / float(m[3])
	if u < 0.4:
		return 1.0
	return clampf(ceilf((1.0 - u) / 0.6 * 4.0) / 4.0, 0.0, 1.0)




func tick(dt_game: float) -> void :
	var t: float = gw.game_time

	var ang: float = 0.3 + 0.75 * sin(t / 233.0) + 0.35 * sin(t / 97.0 + 1.3)
	wind = Vector2.from_angle(ang) * (7.0 + 3.0 * sin(t / 151.0))

	if dt_game <= 0.0:
		return

	for k in range(columns.size() - 1, -1, -1):
		var col: Dictionary = columns[k]
		if t > float(col["end"]):
			columns.remove_at(k)

	_seen_t -= dt_game
	if _seen_t <= 0.0:
		_seen_t = 2.0
		var ch: bool = false
		for m: Array in marks:
			if not bool(m[4]) and (gw.vision == null or gw.vision.sees(m[1])):
				m[4] = true
				ch = true
		if ch:
			marks_ver += 1

	_fire_t -= dt_game
	if _fire_t <= 0.0:
		_fire_t = 0.5
		for col: Dictionary in columns:
			if int(col["fid"]) >= 0 and float(col["burn"]) > t:
				var f: Facility = _fac(int(col["fid"]))
				if f == null or gw.mil.alive(f):
					col["burn"] = t
					col["end"] = minf(float(col["end"]), t + 30.0)
		for fire: Dictionary in gw.fires:
			var left: float = float(fire["until"]) - t
			if left > 1.0 and not fire.has("vfx"):
				fire["vfx"] = true
				add_column((fire["p"] as Vector2) + Vector2(0, -3), 0.45 if int(fire["city"]) >= 0 else 0.35, left)






func sim_tick() -> void :
	var t: float = gw.game_time
	if gw.ground != null and not gw.ground.decals.is_empty():
		for d: Array in gw.ground.decals:
			if gw.aftermath != null and String(d[0]) == "wreck_hull":
				continue
			add_mark(String(d[0]), Vector2(d[1]))
		gw.ground.decals.clear()
		gw.ground.queue_redraw()
	var drop: bool = false
	for k in range(marks.size() - 1, -1, -1):
		if t - float(marks[k][2]) > float(marks[k][3]):
			if marks[k].size() > 5 and bool(marks[k][5]):
				_add_scar(String(marks[k][0]), marks[k][1], float(marks[k][2]) + float(marks[k][3]))
			marks.remove_at(k)
			drop = true
	if drop:
		marks_ver += 1
	for fire: Dictionary in gw.fires:
		if not fire.has("sc") and float(fire["until"]) - t > 1.0:
			fire["sc"] = true
			var fp: Vector2 = fire["p"]
			add_mark("scorch_m%s" % ("a" if (int(fp.x) + int(fp.y)) % 2 == 0 else "b"), fp.round() + Vector2(0, 2))
	_kab_n = _kab_hits()



func scar_ok(p: Vector2) -> bool:
	if gw == null or gw.data == null:
		return false
	var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	if not gw.data.inside(c.x, c.y):
		return false
	var b: int = gw.data.get_biome(c.x, c.y)
	if Biome.is_water(b) or (b >= Biome.ROAD and b <= Biome.PLAZA) or b == Biome.INDUSTRIAL:
		return false
	if gw.data.has_flag(c.x, c.y, WorldData.F_CITY | WorldData.F_ROAD | WorldData.F_BRIDGE):
		return false
	return gw.city_at_cell(c) == null


func _add_scar(n: String, p: Vector2, t0: float) -> void :
	var sz: String = "l" if n.ends_with("_l") else ("m" if n.ends_with("_m") else "s")
	scars.append([sz, Vector2(p), t0])
	while scars.size() > SCAR_CAP:
		scars.remove_at(0)
	marks_ver += 1



func scar_stage(sc: Array) -> int:
	var age: float = gw.game_time - float(sc[2])
	return 0 if age < SCAR_T1 else (1 if age < SCAR_T2 else 2)




func clear_area(box: Rect2) -> void :
	var n0: int = marks.size() + scars.size()
	for k in range(marks.size() - 1, -1, -1):
		if box.has_point(marks[k][1]):
			marks.remove_at(k)
	for k2 in range(scars.size() - 1, -1, -1):
		if box.has_point(scars[k2][1]):
			scars.remove_at(k2)
	if marks.size() + scars.size() != n0:
		marks_ver += 1


func _fac(fid: int) -> Facility:
	for f: Facility in gw.mil.facilities:
		if f.id == fid:
			return f
	return null




func save_state() -> Dictionary:
	var ms: Array = []
	for m: Array in marks:
		ms.append([m[0], m[1], m[2], m[3], m[5] if m.size() > 5 else false])
	var cs: Array = []
	for c: Dictionary in columns:
		cs.append([c["p"], c["t0"], c["burn"], c["end"], c["pow"], c["oil"], c["fid"]])
	return {"marks": ms, "cols": cs, "scars": scars.duplicate(true)}


func load_state(d: Dictionary) -> void :
	marks.clear()
	for m: Array in d.get("marks", []):
		if m.size() >= 4:
			var keep: bool = bool(m[4]) if m.size() > 4 else (String(m[0]).begins_with("crater") and scar_ok(Vector2(m[1])))
			marks.append([String(m[0]), Vector2(m[1]), float(m[2]), float(m[3]), gw.vision == null or gw.vision.sees(Vector2(m[1])), keep])
	scars.clear()
	for sc: Variant in d.get("scars", []):
		if sc is Array and (sc as Array).size() >= 3:
			scars.append([String(sc[0]), Vector2(sc[1]), float(sc[2])])
	marks_ver += 1
	columns.clear()
	for c: Array in d.get("cols", []):
		if c.size() >= 7:
			columns.append({"p": Vector2(c[0]), "t0": float(c[1]), "burn": float(c[2]), "end": float(c[3]), "pow": float(c[4]), "oil": bool(c[5]), "acc": 0.0, "fid": int(c[6])})
