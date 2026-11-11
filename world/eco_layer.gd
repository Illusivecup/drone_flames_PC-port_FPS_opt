class_name EcoLayer
extends Node2D








const MD = preload("res://ui/ui24/map_declutter.gd")
var gw: GameWorld
var _t: float = 0.0
var _slow: float = 0.0
var _cam_key: Vector3 = Vector3.INF
var _ver: int = -1
var _anim: bool = false
var _map_mode: int = -1

const PIN_ALPHA_USED: float = 0.55
const PIN_ALPHA_NAME: float = 0.2
var _name_ver: int = -1
var _fo_last: bool = false


static func make(world: GameWorld) -> EcoLayer:
	var l: = EcoLayer.new()
	l.name = "Eco"
	l.gw = world
	return l


func _process(delta: float) -> void :
	if gw == null or gw.econ == null or gw.camera == null:
		return
	if _marks == null:
		_ensure_marks()
	_t += delta
	_slow += delta
	var cam: MapCamera = gw.camera
	var key: = Vector3(cam.position.x, cam.position.y, cam.zoom.x)
	var fo: bool = _ore_focus()
	var dirty: bool = key != _cam_key or int(gw.econ.draw_ver) != _ver or int(gw.map_mode) != _map_mode\
	or (gw.labels != null and gw.labels.name_ver != _name_ver) or fo != _fo_last
	_fo_last = fo
	_name_ver = gw.labels.name_ver if gw.labels != null else 0
	_map_mode = int(gw.map_mode)
	if dirty or (_anim and _t >= 1.0 / 20.0) or _slow >= 1.0:
		_cam_key = key
		_ver = int(gw.econ.draw_ver)
		_t = 0.0
		_slow = 0.0
		queue_redraw()


func _draw() -> void :
	MD.begin("pin")
	MD.begin("pin_dot")
	MD.tap_begin("pin")
	_anim = false
	var had_marks: bool = not _marks_list.is_empty()
	_marks_list.clear()
	if gw == null or gw.econ == null or gw.camera == null or gw.mil == null:
		return
	var at: SpriteAtlas = gw.atlas9
	if at == null or at.sprites.is_empty():
		return
	var cam: MapCamera = gw.camera
	var z: float = cam.zoom.x
	var view: = Rect2(cam.screen_to_world(Vector2.ZERO), cam.view_size() / z).grow(48.0 / z)
	var econ: Economy = gw.econ
	var badges: Array = []

	if z >= 0.5:
		var fr_rig: int = int(FxLayer.vt * 8.0)
		for f: Facility in gw.mil.facilities:
			if f.main_obj < 0 or not view.has_point(f.center_px()):
				continue
			var lvl: int = econ.level_of(f)
			if f.kind != Facility.Kind.OIL_RIG and f.kind != Facility.Kind.PORT and lvl <= 1:
				continue
			if not gw.mil.alive(f):
				continue
			if gw.vision != null and not gw.vision.fac_shown(f):
				continue
			var o: Vector2 = gw.obj_origin(f.main_obj)
			if f.kind == Facility.Kind.OIL_RIG and at.has("oil_rig_beam"):
				var n: int = int(at.info("oil_rig_beam")["frames"])
				var work: bool = econ.site_working(f)
				_spr(at, "oil_rig_beam", (fr_rig + f.id) % n if work else 0, o)
				_anim = _anim or work
			elif f.kind == Facility.Kind.PORT:
				_yard(at, f)
			for ex: Array in econ.extras_of(f):
				var nm: String = ex[0]
				if not at.has(nm):
					continue
				var e: Dictionary = at.info(nm)
				var cell: Vector2i = ex[1]
				var fr: int = int(ex[2])
				if int(e["frames"]) > 1 and int(e.get("fps", 0)) > 0:
					fr = int(FxLayer.vt * float(e["fps"]) + f.id) % int(e["frames"]) if econ.site_working(f) else 0
					_anim = true
				var tl: = Vector2(cell.x * GameWorld.CELL - int(e["ax"]), (cell.y + int(e["fd"])) * GameWorld.CELL - int(e["ay"]))
				_spr(at, nm, fr, tl)
			if lvl > 1:
				badges.append([o + Vector2(2, 2), lvl])

	if at.has("ship_cargo"):
		var foam: = Palette.c("water_foam")
		var sc: float = clampf(0.5 / z, 1.0, 2.0)
		for s: Dictionary in econ.ports.ships:
			_anim = true
			var p: Vector2 = (s["pos"] as Vector2).round()
			if not view.has_point(p):
				continue
			if int(s["stage"]) > 0:
				var tr: PackedVector2Array = s["trail"]
				var nn: int = tr.size()
				for i in nn:
					var age: float = float(nn - i)
					var dirv: Vector2 = Vector2.from_angle(float(s["heading"]))
					var side: Vector2 = dirv.orthogonal() * (1.5 + age * 0.7)
					var col: = Color(foam, 0.75 * (1.0 - age / float(nn + 1)))
					draw_rect(Rect2((tr[i] + side).round(), Vector2(1, 1)), col)
					draw_rect(Rect2((tr[i] - side).round(), Vector2(1, 1)), col)
					if i == nn - 1:
						draw_rect(Rect2((tr[i]).round() - Vector2(1, 0), Vector2(2, 1)), col)
			var es: Dictionary = at.info("ship_cargo")
			draw_set_transform(p, 0.0, Vector2(sc, sc))

			var hit: bool = gw.game_time - float(s.get("hit_t", -99.0)) < 0.25
			draw_texture_rect_region(at.texture, Rect2( - Vector2(float(es["ax"]), float(es["ay"])), Vector2(float(es["w"]), float(es["h"]))), at.rect("ship_cargo", int(s["frame"])), Color(1.9, 1.7, 1.5) if hit else Color(1.45, 1.4, 1.3))

			var hv: Vector2 = Vector2.from_angle(float(s["heading"]))
			if int(s["n"]) > 0:
				for ci in 3:
					draw_rect(Rect2((hv * (float(ci) * 2.5 - 2.5) - Vector2(1, 1)).round(), Vector2(2, 2)), [Color(0.85, 0.35, 0.2), Color(0.25, 0.55, 0.85), Color(0.9, 0.75, 0.25)][ci])
			if int(s["stage"]) > 0:
				draw_rect(Rect2((hv * 7.0).round() - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.8))
			draw_set_transform(Vector2.ZERO)

	var pin_sc: float = clampf(1.0 / z, 1.0, 4.0)
	if at.has("eco_lvl"):
		var eb: Dictionary = at.info("eco_lvl")
		for b: Array in badges:
			draw_set_transform(b[0] as Vector2, 0.0, Vector2(pin_sc, pin_sc))
			draw_texture_rect_region(at.texture, Rect2( - Vector2(float(eb["ax"]), float(eb["ay"])), Vector2(float(eb["w"]), float(eb["h"]))), at.rect("eco_lvl", clampi(int(b[1]) - 2, 0, 1)))
	var ores: bool = int(gw.map_mode) == GameWorld.MapMode.ORES


	var focus: bool = _ore_focus()
	if z < MD.LOD_FAR and not ores:
		_ore_clusters(cam, z, view, focus)
		_anim = _anim or focus
		if _marks != null:
			_marks.queue_redraw()
		draw_set_transform(Vector2.ZERO)
		return
	if had_marks and _marks != null:
		_marks.queue_redraw()
	var pid0: int = gw.player.id if gw.player != null else -1


	var lab: Array[Rect2] = []
	if not ores:
		lab = MD.label_rects(gw, cam)
	for dp: Dictionary in econ.deposits:
		var res: String = String(dp.get("res", "titanium"))
		var nm2: String = "dep_mark_" + res
		var pat: SpriteAtlas = at if at.has(nm2) else gw.atlas_uran30
		if pat == null or not pat.has(nm2) or int(dp.get("left", 1)) <= 0:
			continue
		var used: bool = dp["mine"] != null
		if used and z >= 1.0 and not ores:
			continue


		if used and not ores and gw.show_own_icons and gw.player != null and (dp["mine"] as Facility).country_id == gw.player.id:
			continue
		var cp: Vector2 = Vector2(dp["cell"] as Vector2i) * GameWorld.CELL + Vector2(2, -4)
		if not view.has_point(cp):
			continue
		var e2: Dictionary = pat.info(nm2)
		var psc: float = pin_sc * 1.25 if ores else pin_sc
		var pa: float = PIN_ALPHA_USED if used else 1.0
		if not ores and gw.labels != null and not gw.labels.name_rects.is_empty():
			var pr: = Rect2(cp - Vector2(float(e2["ax"]), float(e2["ay"])) * psc, Vector2(float(e2["w"]), float(e2["h"])) * psc)
			for nr: Rect2 in gw.labels.name_rects:
				if nr.intersects(pr):
					pa = minf(pa, PIN_ALPHA_NAME)
					break

		var psr: = Rect2(cam.world_to_screen(cp - Vector2(float(e2["ax"]), float(e2["ay"])) * psc), Vector2(float(e2["w"]), float(e2["h"])) * psc * z)
		if not ores and MD.kept(psr):
			pa = minf(pa, MD.KEEP_A)
		var mine_free: bool = not used and gw.data.get_owner_id((dp["cell"] as Vector2i).x, (dp["cell"] as Vector2i).y) == pid0
		if not ores and not (focus and mine_free) and (MD.hits(psr, lab) or MD.hits(psr, MD.pen_rects)):
			pa = minf(pa, PIN_ALPHA_NAME + 0.1)
		if focus and not ores and not mine_free:
			pa = minf(pa, 0.35)
		if MD.rec:
			MD.note("pin" if pa > 0.3 else "pin_faint", Rect2(cam.world_to_screen(cp - Vector2(float(e2["ax"]), float(e2["ay"])) * psc), Vector2(float(e2["w"]), float(e2["h"])) * psc * z))
		draw_set_transform(cp, 0.0, Vector2(psc, psc))
		if ores:
			_ore_halo(dp, e2, used)
		elif focus and mine_free:
			_focus_ring(Vector2( - float(e2["ax"]) + float(e2["w"]) * 0.5, - float(e2["ay"]) + float(e2["h"]) * 0.5), maxf(float(e2["w"]), float(e2["h"])) * 0.62)
		draw_texture_rect_region(pat.texture, Rect2( - Vector2(float(e2["ax"]), float(e2["ay"])), Vector2(float(e2["w"]), float(e2["h"]))), pat.rect(nm2, 0), 
			Color(1, 1, 1, pa))
	draw_set_transform(Vector2.ZERO)




const ORE_ICON: int = 15
const ORE_CL_R: float = 22.0
const ORE_STEP: float = 14.0


const ORE_GLYPH: Dictionary = {
	"titanium": ["...#...", "..###..", ".#####.", ".#####.", ".#####.", "..###..", "...#..."], 
	"metal": [".......", "..###..", ".#####.", ".......", "..###..", ".#####.", "......."], 
	"oil": ["...#...", "..###..", "..###..", ".#####.", ".#####.", ".#####.", "..###.."], 
	"precious": [".......", ".#####.", "#######", ".#####.", "..###..", "...#...", "......."], 
	"uranium": ["...#...", "..###..", "..###..", ".#.#.#.", ".##.##.", ".##.##.", "......."], 
}
static var _ore_tex: Dictionary = {}
var _marks: Node2D = null
var _marks_list: Array = []





static func ore_tex(res: String, variant: int) -> Texture2D:
	var key: String = "%s:%d" % [res, variant]
	if _ore_tex.has(key):
		return _ore_tex[key]
	var col: Color = MapModeLayer.ORE_COLORS.get(res, Color.WHITE)
	var ink: = Color(0.043, 0.078, 0.188)
	var n: int = ORE_ICON
	var img: = Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body: Color = Color("f4efe0") if variant != 2 else Color("2a3142")
	for y in range(1, n - 1):
		for x in range(1, n - 1):
			if (x == 1 or x == n - 2) and (y == 1 or y == n - 2):
				continue
			var edge: bool = x == 1 or y == 1 or x == n - 2 or y == n - 2
			var edge2: bool = x == 2 or y == 2 or x == n - 3 or y == n - 3
			if edge:
				img.set_pixel(x, y, Color("fff1c4") if variant == 0 else Color(0, 0, 0, 0))
			elif edge2:
				img.set_pixel(x, y, ink)
			else:
				img.set_pixel(x, y, body.darkened(0.12) if y == n - 4 else body)
	var g: Array = ORE_GLYPH.get(res, ORE_GLYPH["titanium"])
	var on: = {}
	for gy in 7:
		for gx in 7:
			if String(g[gy])[gx] == "#":
				on[Vector2i(4 + gx, 4 + gy)] = true
	for q: Vector2i in on:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var o: Vector2i = q + d
			if not on.has(o) and o.x >= 3 and o.y >= 3 and o.x <= n - 4 and o.y <= n - 4:
				img.set_pixelv(o, ink if variant != 2 else ink.lightened(0.05))
	for q2: Vector2i in on:
		var top: bool = not on.has(q2 + Vector2i(0, -1))
		img.set_pixelv(q2, col.lightened(0.35) if top else col)
	var t: = ImageTexture.create_from_image(img)
	_ore_tex[key] = t
	return t


func _ore_clusters(cam: MapCamera, z: float, view: Rect2, focus: bool) -> void :
	var pid: int = gw.player.id if gw.player != null else -1
	var items: Array = []
	for dp: Dictionary in gw.econ.deposits:
		if int(dp.get("left", 1)) <= 0:
			continue
		var cell: Vector2i = dp["cell"]
		var wp: Vector2 = Vector2(cell) * GameWorld.CELL + Vector2(2, 2)
		if not view.has_point(wp):
			continue
		var mine: Facility = dp["mine"]
		var v: int = 1
		if mine == null:
			v = 0 if gw.data.get_owner_id(cell.x, cell.y) == pid else 1
		elif mine.country_id == pid and gw.show_own_icons and gw.mil.alive(mine):
			v = 2
		else:
			continue
		items.append([[0, 2, 1][v], cam.world_to_screen(wp), String(dp.get("res", "titanium")), v, wp])
	items.sort_custom( func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]) if int(a[0]) != int(b[0]) else (a[1] as Vector2).x < (b[1] as Vector2).x)
	var cl: Array = []
	var clr: float = lerpf(ORE_CL_R * 1.5, ORE_CL_R, clampf((z - 0.25) / 0.2, 0.0, 1.0))
	for it: Array in items:
		var hit: Array = []
		for c: Array in cl:
			if String(c[1]) == String(it[2]) and (c[0] as Vector2).distance_to(it[1]) < clr and not (focus and (int(c[2]) == 0) != (int(it[3]) == 0)):
				hit = c
				break
		if hit.is_empty():
			cl.append([it[1], it[2], it[3], 1, it[4], 1 if int(it[3]) == 0 else 0])
		else:
			hit[3] = int(hit[3]) + 1
			hit[4] = (hit[4] as Vector2) + (it[4] as Vector2)
			hit[5] = int(hit[5]) + (1 if int(it[3]) == 0 else 0)
	var lab: Array[Rect2] = MD.label_rects(gw, cam)
	var placed: Array[Rect2] = []
	var half: float = float(ORE_ICON) * 0.5
	for c2: Array in cl:
		var sp: Vector2 = (c2[0] as Vector2).round()
		var spot: Vector2 = Vector2.INF
		for off: Vector2 in [Vector2.ZERO, Vector2(ORE_STEP, 0), Vector2( - ORE_STEP, 0), Vector2(0, - ORE_STEP), Vector2(0, ORE_STEP)]:
			var rr: = Rect2(sp + off - Vector2(half, half), Vector2(ORE_ICON, ORE_ICON)).grow(-1.0)
			if not MD.hits(rr, placed):
				spot = sp + off
				placed.append(rr)
				break
		if spot == Vector2.INF:
			continue
		var r: = Rect2(spot - Vector2(half, half), Vector2(ORE_ICON, ORE_ICON))
		var v2: int = int(c2[2])
		var a: float = 1.0 if v2 == 0 else MD.QUIET_A
		if focus and v2 != 0:
			a = 0.35
		if not (focus and v2 == 0) and (MD.hits(r, lab) or MD.hits(r, MD.pen_rects)):
			a = minf(a, 0.3)
		if MD.kept(r):
			a = minf(a, MD.KEEP_A)
		var n: int = int(c2[3])
		MD.note("pin_faint" if a <= 0.31 else "pin", r)
		if n >= 2 and a > 0.31:
			MD.tap_add("pin", r.grow(4.0), (c2[4] as Vector2) / float(n))
		_marks_list.append([cam.screen_to_world(spot), String(c2[1]), v2, a, n, focus and v2 == 0])




func _ore_focus() -> bool:
	if not Hud.ores_open or gw == null or gw.player == null:
		return false
	var mn: Node = gw.get_parent()
	var h: Variant = mn.get("hud") if mn != null else null
	var op: Variant = (h as Object).get("ore_panel") if h is Object else null
	return op is Control and (op as Control).visible




func _ensure_marks() -> void :
	if _marks != null and is_instance_valid(_marks):
		return
	_marks = Node2D.new()
	_marks.name = "OreMarks"
	gw.add_child(_marks)
	if gw.night != null and gw.night.get_parent() == gw:
		gw.move_child(_marks, gw.night.get_index() + 1)
	_marks.draw.connect(_draw_marks)


func _draw_marks() -> void :
	if gw == null or gw.camera == null:
		return
	var z: float = gw.camera.zoom.x
	var k: float = 1.0 / z
	var half: float = float(ORE_ICON) * 0.5
	var font: Font = UiKit.f_black if UiKit.f_black != null else ThemeDB.fallback_font
	var ink: = Color(0.043, 0.078, 0.188)
	for e: Array in _marks_list:
		var a: float = e[3]
		var v2: int = e[2]
		var n: int = e[4]
		_marks.draw_set_transform(e[0] as Vector2, 0.0, Vector2(k, k))
		if bool(e[5]):
			var t: float = 0.5 + 0.5 * sin(FxLayer.vt * 4.0)
			_marks.draw_arc(Vector2.ZERO, half + 2.5 + t * 2.0, 0.0, TAU, 20, Color(1.0, 0.94, 0.75, 0.45 + 0.4 * t), 1.5)
		_marks.draw_texture(ore_tex(String(e[1]), v2), - Vector2(half, half), Color(1, 1, 1, a))
		if n >= 2:
			var txt: String = str(n)
			var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			var br: = Rect2(Vector2(half - 4.0, - half - 3.0), Vector2(tw + 4.0, 10.0))
			_marks.draw_rect(br.grow(1.0), Color(ink, a))
			_marks.draw_rect(br, Color(0.96, 0.93, 0.82, a) if v2 != 2 else Color(0.62, 0.6, 0.55, a))
			_marks.draw_string(font, Vector2(br.position.x + 2.0, br.end.y - 1.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(ink, a))
	_marks.draw_set_transform(Vector2.ZERO)



func _focus_ring(c: Vector2, r: float) -> void :
	_anim = true
	var t: float = 0.5 + 0.5 * sin(FxLayer.vt * 4.0)
	draw_arc(c, r + 1.5 + t * 2.0, 0.0, TAU, 20, Color(1.0, 0.94, 0.75, 0.45 + 0.4 * t), 1.5)


func _spr(at: SpriteAtlas, nm: String, frame: int, top_left: Vector2) -> void :
	var r: Rect2 = at.rect(nm, frame)
	draw_texture_rect_region(at.texture, Rect2(top_left, r.size), r)



func _yard(at: SpriteAtlas, f: Facility) -> void :
	if not at.has("eco_cont"):
		return
	var c: Country = gw.country_by_id(f.country_id)
	if c == null:
		return
	var slots: PackedVector2Array = gw.econ.ports.yard_slots(f, at)
	var ns: int = slots.size()
	if ns == 0:
		return
	var units: int = roundi(float(gw.econ.ports.container_units(c)) / 36.0 * float(ns * 3))
	for i in ns:
		var lv: int = clampi((units - i + ns - 1) / ns, 0, 3)
		if lv <= 0:
			continue
		var col: int = (i * 7 + f.id * 3) % 4
		_spr(at, "eco_cont", (lv - 1) * 4 + col, slots[i] - Vector2(0, 9))


static var _halo: Dictionary = {}




static func halo_tex(res: String, used: bool, rad: float) -> Texture2D:
	var key: String = "%s:%d:%d" % [res, int(used), roundi(rad * 10.0)]
	if _halo.has(key):
		return _halo[key]
	var col: Color = MapModeLayer.ORE_COLORS.get(res, Color.WHITE)
	var dark: = Color(0.043, 0.078, 0.188)
	var n: int = ceili(rad + 1.5) * 2 + 2
	var img: = Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cc: = Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var d: float = (Vector2(x + 0.5, y + 0.5) - cc).length()
			if d > rad + 1.5:
				continue
			var c: Color = dark
			if d <= rad:
				c = dark.lerp(col.darkened(0.55), 0.95) if used else col
			if not used and d <= rad - 1.5:
				c = col.lightened(0.4)
			if not used and d <= rad - 2.5:
				c = col
			img.set_pixel(x, y, c)
	var t: = ImageTexture.create_from_image(img)
	_halo[key] = t
	return t




func _ore_halo(dp: Dictionary, e: Dictionary, used: bool) -> void :
	var col: Color = MapModeLayer.ORE_COLORS.get(String(dp.get("res", "titanium")), Color.WHITE)
	var w: float = float(e["w"])
	var h: float = float(e["h"])
	var c0: = Vector2( - float(e["ax"]) + w * 0.5, - float(e["ay"]) + h * 0.5)
	var rad: float = maxf(w, h) * 0.62
	var dark: = Color(0.043, 0.078, 0.188)
	var ht: Texture2D = halo_tex(String(dp.get("res", "titanium")), used, rad)
	draw_texture(ht, (c0 - ht.get_size() * 0.5).round())
	if used:
		var mine: Facility = dp["mine"]
		var oc: Country = gw.country_by_id(mine.country_id) if mine != null else null
		if oc != null:
			draw_rect(Rect2(c0 + Vector2(rad * 0.45, - rad - 1.0), Vector2(4, 4)), dark)
			draw_rect(Rect2(c0 + Vector2(rad * 0.45 + 1.0, - rad), Vector2(2, 2)), oc.color)
	var mx: float = maxf(1.0, float(dp.get("max", 1)))
	var k: float = clampf(float(dp.get("left", 0)) / mx, 0.0, 1.0)
	var bw: float = rad * 2.0
	var bp: = c0 + Vector2( - bw * 0.5, rad + 2.0)
	draw_rect(Rect2(bp - Vector2(1, 1), Vector2(bw + 2.0, 4.0)), dark)
	draw_rect(Rect2(bp, Vector2(bw * k, 2.0)), col.lightened(0.2) if not used else col.darkened(0.2))
