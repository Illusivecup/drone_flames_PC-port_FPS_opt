class_name MapIcons
extends Node2D









const MD = preload("res://ui/ui24/map_declutter.gd")
const BOX: float = 16.0
const ICON: float = 12.0
const FIELD_GRID: float = 44.0
const FADE_FROM: float = 1.0
const FADE_TO: float = 2.0
const OUTLINE: = Color(0.043, 0.078, 0.188)
const BG: = Color(0.118, 0.122, 0.11, 0.94)

const CAT_MIL: = Color("e8402a")
const CAT_AD: = Color("9ff2f0")
const CAT_ECO: = Color("ffb000")
const CAT_POWER: = Color("ffe08a")
const CAT_ARMY: = Color("9bc53d")
const CAT_LOGI: = Color("7cc0f0")

var gw: GameWorld
var _key: Vector3 = Vector3.INF
var _t: float = 0.0
var _nf: int = -1
var _tex: Dictionary = {}



static func known(world: GameWorld, f: Facility) -> bool:
	var v: Variant = world.get("vision")
	if v is Object and (v as Object).has_method("known"):
		return bool((v as Object).call("known", f))
	return true


static func category_color(kind: int) -> Color:
	match kind:
		Facility.Kind.DRONE_FACTORY, Facility.Kind.DRONE_PORT, Facility.Kind.AIRFIELD, Facility.Kind.TEL, \
		Facility.Kind.MISSILE_FACTORY, Facility.Kind.DP_RAMP, Facility.Kind.DP_RUNWAY, Facility.Kind.DP_STORE:
			return CAT_MIL
		Facility.Kind.AD_MFG, Facility.Kind.AD_SPAAG, Facility.Kind.AD_SAM, Facility.Kind.AD_PATRIOT, \
		Facility.Kind.AD_INT, Facility.Kind.AD_RADAR, Facility.Kind.AD_EW:
			return CAT_AD
		Facility.Kind.POWER_PLANT, Facility.Kind.SOLAR, Facility.Kind.SOLAR_FARM, Facility.Kind.NUCLEAR_PLANT:
			return CAT_POWER
		Facility.Kind.BARRACKS, Facility.Kind.TRENCH_H, Facility.Kind.TRENCH_V, Facility.Kind.TEETH_H, \
		Facility.Kind.TEETH_V, Facility.Kind.DUGOUT:
			return CAT_ARMY
		Facility.Kind.PORT, Facility.Kind.PORT_CRANE, Facility.Kind.RAIL_STATION:
			return CAT_LOGI
	return CAT_ECO




static func minor(f: Facility) -> bool:
	if Military.is_field_work(f.kind) or Military.is_module(f.kind):
		return true
	match f.kind:
		Facility.Kind.MINE, Facility.Kind.FARM, Facility.Kind.SAWMILL, Facility.Kind.OIL_RIG, Facility.Kind.CIV_FACTORY, \
		Facility.Kind.SOLAR, Facility.Kind.SOLAR_FARM, Facility.Kind.REFINERY, Facility.Kind.PORT_CRANE, Facility.Kind.RAIL_STATION, Facility.Kind.URANIUM_MINE:
			return true
		Facility.Kind.BARRACKS:
			return f.group_id >= 0
	return false


static func priority(kind: int) -> int:
	match kind:
		Facility.Kind.DRONE_PORT, Facility.Kind.AIRFIELD, Facility.Kind.MISSILE_FACTORY, Facility.Kind.DRONE_FACTORY:
			return 0
		Facility.Kind.BARRACKS, Facility.Kind.TEL, Facility.Kind.POWER_PLANT, Facility.Kind.PORT, Facility.Kind.REFINERY, Facility.Kind.NUCLEAR_PLANT:
			return 1
		Facility.Kind.AD_SAM, Facility.Kind.AD_PATRIOT, Facility.Kind.AD_INT, Facility.Kind.AD_RADAR, Facility.Kind.AD_MFG:
			return 2
		Facility.Kind.TRENCH_H, Facility.Kind.TRENCH_V, Facility.Kind.TEETH_H, Facility.Kind.TEETH_V:
			return 6
		Facility.Kind.DP_RAMP, Facility.Kind.DP_RUNWAY, Facility.Kind.DP_STORE, Facility.Kind.SOLAR, Facility.Kind.PORT_CRANE:
			return 7
	return 4


func force() -> void :
	_key = Vector3.INF


func _process(delta: float) -> void :
	if gw == null or gw.camera == null or gw.mil == null:
		return
	_t += delta
	var cam: MapCamera = gw.camera
	var key: = Vector3(cam.position.x, cam.position.y, cam.zoom.x)
	var nf: int = gw.mil.facilities.size() + (gw.labels.name_ver * 4096 if gw.labels != null else 0) + MD.keep_ver * 7919
	if key != _key or nf != _nf or _t >= 0.5:
		_key = key
		_nf = nf
		_t = 0.0
		queue_redraw()


func _icon(kind: int) -> Texture2D:
	var nm: String = Military.icon_of(kind)
	if not _tex.has(nm):
		var t: Texture2D = UiKit.tex(nm) if UiKit.has(nm) else null
		if t == null and gw != null:

			var an: Variant = gw.get("atlas_navy1")
			if an is SpriteAtlas and (an as SpriteAtlas).has(nm):
				t = (an as SpriteAtlas).region(nm)
		_tex[nm] = t
	return _tex[nm]


func _draw() -> void :
	MD.begin("icon")
	if gw == null or gw.camera == null or gw.mil == null or gw.data == null:
		return
	var military: bool = int(gw.map_mode) == GameWorld.MapMode.MILITARY
	if not gw.show_own_icons and not military:
		return
	var cam: MapCamera = gw.camera
	var z: float = cam.zoom.x
	var alpha: float = 1.0 - clampf((z - FADE_FROM) / (FADE_TO - FADE_FROM), 0.0, 1.0)
	if alpha <= 0.02:
		return
	var pid: int = gw.player.id if gw.player != null else 0
	var vs: Vector2 = cam.view_size()
	var screen: = Rect2(Vector2.ZERO, vs).grow(BOX)
	var sel: Facility = gw.selected_facility()
	var items: Array = []
	var fields: Dictionary = {}
	for f: Facility in gw.mil.facilities:
		var own: bool = f.country_id == pid
		if not own and not (military and f.country_id > 0 and known(gw, f)):
			continue
		if own and not gw.show_own_icons:
			continue
		if not own and f != sel and gw.vision != null and gw.vision.active() and gw.vision.friend(f.country_id):
			continue
		var k: int = f.kind
		if Military.is_module(k) or k == Facility.Kind.PORT_CRANE:
			if f.parent != null and gw.mil.alive(f.parent):
				continue
		var tip: Vector2
		if Military.is_field_work(k):
			if f.cells.is_empty():
				continue
			var cc: Vector2i = f.cells[f.cells.size() / 2]
			tip = Vector2(cc * GameWorld.CELL) + Vector2(2, 2)
		elif f.moving:
			tip = f.mpos
		else:
			tip = f.center_px()

			if z >= 0.5 and f.main_obj >= 0:
				tip.y = minf(tip.y, gw.obj_origin(f.main_obj).y + 3.0)
		var sp: Vector2 = cam.world_to_screen(tip)
		if not screen.has_point(sp):
			continue
		var pr: int = priority(k)
		if f == sel:
			pr = -1
		if Military.is_field_work(k):
			var gk: = Vector3i(floori(sp.x / FIELD_GRID), floori(sp.y / FIELD_GRID), f.country_id * 4 + (1 if Military.is_teeth(k) else 0))
			if fields.has(gk):
				(fields[gk] as Array)[3] = int((fields[gk] as Array)[3]) + 1
				continue
			var it: Array = [pr, tip, f, 1]
			fields[gk] = it
			items.append(it)
		else:
			items.append([pr, tip, f, 1])
	items.sort_custom( func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]) if int(a[0]) != int(b[0]) else (a[2] as Facility).id < (b[2] as Facility).id)




	var placed: Array[Rect2] = []
	var drawn: Array = []
	var sc: float = 1.0 / z
	var lv: int = MD.lod(z)
	MD.tap_begin("icon")
	UiKit.ensure()
	var font: Font = UiKit.f_bold if UiKit.f_bold != null else ThemeDB.fallback_font
	var labs: Array[Rect2] = MD.label_rects(gw, cam)
	for it: Array in items:
		var f2: Facility = it[2]
		var own2: bool = f2.country_id == pid
		var mn: bool = f2 != sel and minor(f2)
		if mn and lv >= 1 and f2.kind == Facility.Kind.BARRACKS:
			continue
		if mn and lv == 2 and Military.is_field_work(f2.kind):
			continue
		if lv == 0 and f2 != sel and not f2.deposit.is_empty() and (f2.kind == Facility.Kind.MINE or f2.kind == Facility.Kind.OIL_RIG) and gw.mil.alive(f2):
			continue
		var dot: bool = mn and lv == 0
		var bs: float = 6.0 if dot else (BOX - 4.0 if mn else (BOX if own2 else BOX - 2.0))
		var sp2: Vector2 = cam.world_to_screen(it[1] as Vector2)
		var rr: = Rect2(sp2 + Vector2(-3.0, -6.0), Vector2(6.0, 6.0)) if dot else Rect2(sp2 - Vector2(bs * 0.5, bs + 4.0), Vector2(bs, bs + 4.0)).grow(1.0)
		var hit: int = -1
		for qi in placed.size():
			if placed[qi].intersects(rr):
				hit = qi
				break
		if hit >= 0:
			var host: Array = drawn[hit]
			if not bool(host[4]) and not dot and ((host[0] as Array)[2] as Facility).country_id == f2.country_id:
				(host[0] as Array)[3] = int((host[0] as Array)[3]) + int(it[3])
			continue
		placed.append(rr)
		var a2: float = alpha * _under_name(it[1] as Vector2, bs, sc) * (MD.QUIET_A if mn or not own2 else 1.0)
		if MD.kept(rr):
			a2 = minf(a2, MD.KEEP_A)
		if mn and (MD.hits(rr, labs) or MD.hits(rr, MD.pen_rects)):
			a2 = minf(a2, MD.KEEP_A)
		MD.note("icon_faint" if a2 <= MD.KEEP_A + 0.01 else ("icon_dot" if dot else "icon"), rr)
		drawn.append([it, rr, bs, a2, dot])
	for d: Array in drawn:
		var it2: Array = d[0]
		var f3: Facility = it2[2]
		draw_set_transform((it2[1] as Vector2), 0.0, Vector2(sc, sc))
		if bool(d[4]):
			_dot(f3, float(d[3]))
		else:
			_marker(f3, float(d[2]), f3.country_id == pid, int(it2[3]), f3 == sel, float(d[3]), font)
			if int(it2[3]) >= 3 and lv < 2 and float(d[3]) > MD.KEEP_A:
				MD.tap_add("icon", d[1], it2[1])
	draw_set_transform(Vector2.ZERO)



func _dot(f: Facility, a: float) -> void :
	var c: Color = category_color(f.kind)
	draw_rect(Rect2(-3.0, -7.0, 6.0, 6.0), Color(OUTLINE, a))
	draw_rect(Rect2(-2.0, -6.0, 4.0, 4.0), Color(c, a) if gw.mil.alive(f) else Color(0.55, 0.55, 0.55, a))




func _under_name(tip: Vector2, bs: float, sc: float) -> float:
	var lab: LabelsLayer = gw.labels
	if lab == null or lab.name_rects.is_empty():
		return 1.0
	var r: = Rect2(tip - Vector2(bs * 0.5, bs + 4.0) * sc, Vector2(bs, bs + 4.0) * sc)
	for nr: Rect2 in lab.name_rects:
		if nr.intersects(r):
			return 0.25
	return 1.0



func _marker(f: Facility, bs: float, own: bool, count: int, selected: bool, alpha: float, font: Font) -> void :
	var c: Country = gw.country_by_id(f.country_id)
	var ccol: Color = c.color if c != null else Color.WHITE
	var frame: Color = Color.WHITE if selected else category_color(f.kind)
	if not selected and not f.deposit.is_empty() and (f.kind == Facility.Kind.MINE or f.kind == Facility.Kind.OIL_RIG):
		frame = MapModeLayer.ORE_COLORS.get(String(f.deposit.get("res", "")), frame)
	var alive: bool = gw.mil.alive(f)
	var r: = Rect2(Vector2( - bs * 0.5, - bs - 4.0), Vector2(bs, bs))
	var o: = Color(OUTLINE, alpha)

	var tri: = PackedVector2Array([Vector2(-4, -4.5), Vector2(4, -4.5), Vector2(0, 0.5)])
	var tri_o: = PackedVector2Array([Vector2(-5.5, -4.5), Vector2(5.5, -4.5), Vector2(0, 2.0)])
	draw_colored_polygon(tri_o, o)
	draw_colored_polygon(tri, Color(ccol, alpha))

	_rrect(r.grow(2.0), o)
	_rrect(r.grow(1.0), Color(frame, alpha))
	draw_rect(r, Color(BG, BG.a * alpha))

	draw_rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x, 2.0), Color(ccol, alpha))
	var ic: Texture2D = _icon(f.kind)
	var isz: float = minf(ICON if own else ICON - 2.0, bs - 4.0)
	var ir: = Rect2(r.position + (Vector2(bs, bs - 2.0) - Vector2(isz, isz)) * 0.5, Vector2(isz, isz))
	if ic != null:
		var mod: = Color(1, 1, 1, alpha) if alive else Color(0.55, 0.55, 0.55, alpha)
		draw_texture_rect(ic, ir, false, mod)
	if not alive:
		var red: = Color(0.91, 0.25, 0.165, alpha)
		draw_line(ir.position, ir.end, red, 2.0)
		draw_line(Vector2(ir.end.x, ir.position.y), Vector2(ir.position.x, ir.end.y), red, 2.0)
	if count > 1:
		var txt: String = "%d" % count
		var bp: = Vector2(r.end.x - 1.0, r.position.y + 1.0)
		var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var br: = Rect2(bp - Vector2(tw * 0.5 + 2.0, 5.0), Vector2(tw + 4.0, 10.0))
		_rrect(br.grow(1.0), o)
		draw_rect(br, Color(frame, alpha))
		draw_string(font, Vector2(br.position.x + 2.0, br.end.y - 1.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(OUTLINE, alpha))



func _rrect(r: Rect2, col: Color) -> void :
	draw_rect(Rect2(r.position.x + 1.0, r.position.y, r.size.x - 2.0, r.size.y), col)
	draw_rect(Rect2(r.position.x, r.position.y + 1.0, 1.0, r.size.y - 2.0), col)
	draw_rect(Rect2(r.end.x - 1.0, r.position.y + 1.0, 1.0, r.size.y - 2.0), col)
