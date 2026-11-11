class_name FogLayer
extends Node2D





var gw: GameWorld
var _key: Vector4 = Vector4.INF
var _blink: bool = false
var _icons: Dictionary = {}
var cover: bool = false
var _cover_ver: int = -1
var _src: Dictionary = {}

const ICON: Dictionary = {
	Facility.Kind.DRONE_FACTORY: "icon_dronefactory", Facility.Kind.DRONE_PORT: "icon_droneport", Facility.Kind.TEL: "icon_tel", 
	Facility.Kind.MISSILE_FACTORY: "icon_missile_factory", Facility.Kind.REFINERY: "icon_refinery", Facility.Kind.POWER_PLANT: "icon_power", 
	Facility.Kind.AIRFIELD: "icon_airfield_b", Facility.Kind.FARM: "icon_farm", Facility.Kind.CIV_FACTORY: "icon_civ_factory", 
	Facility.Kind.MINE: "icon_mine", Facility.Kind.BARRACKS: "icon_barracks", Facility.Kind.AD_MFG: "icon_ad_mfg", 
	Facility.Kind.AD_SPAAG: "icon_ad_spaag", Facility.Kind.AD_SAM: "icon_ad_sam", Facility.Kind.AD_PATRIOT: "icon_ad_patriot", 
	Facility.Kind.AD_INT: "icon_int_drone", Facility.Kind.AD_RADAR: "icon_ad_radar", Facility.Kind.AD_EW: "icon_ad_ew", 
	Facility.Kind.SAWMILL: "icon_sawmill", Facility.Kind.OIL_RIG: "icon_oil_rig", Facility.Kind.PORT: "icon_port", 
	Facility.Kind.SOLAR: "icon_solar", Facility.Kind.RAIL_STATION: "icon_rail_station", 
	Facility.Kind.NUCLEAR_PLANT: "icon_npp", Facility.Kind.URANIUM_MINE: "icon_umine", 
}
const PIN_SCREEN: float = 0.5



const TINT_COL: = Color(0.3, 0.33, 0.42)
const TINT_A: float = 0.24
const TINT_A_MODES: float = 0.14
const TINT_SHADER: String = "\nshader_type canvas_item;\nrender_mode unshaded;\nuniform sampler2D owner_tex : filter_nearest;\nuniform vec2 owner_px = vec2(1.0);\nuniform vec2 grid_px = vec2(1.0);\nuniform int friend_mask = 0;\nuniform float strength = 0.24;\nuniform vec4 fog_col : source_color = vec4(0.30, 0.33, 0.42, 1.0);\nvoid fragment() {\n\tfloat seen = texture(TEXTURE, UV).r;\n\tvec2 ouv = UV * grid_px / owner_px;\n\tint o = int(texture(owner_tex, ouv).r * 255.0 + 0.5);\n\tfloat own = (o > 0 && o < 31 && ((friend_mask >> o) & 1) != 0) ? 1.0 : 0.0;\n\tCOLOR = vec4(fog_col.rgb, (1.0 - seen) * (1.0 - own) * strength);\n}\n"
















var _tint: Sprite2D
var _tint_tex: ImageTexture
var _tint_ver: int = -1
var _tint_mask: int = -1
var _tint_a: float = -1.0


static func make(world: GameWorld) -> FogLayer:
	var l: = FogLayer.new()
	l.name = "Fog"
	l.gw = world
	return l



static func make_cover(world: GameWorld) -> FogLayer:
	var l: = FogLayer.new()
	l.name = "FogCover"
	l.gw = world
	l.cover = true
	return l


func _process(_delta: float) -> void :
	if gw == null or gw.camera == null or gw.vision == null:
		return
	if cover:
		var v: int = gw.vision.ver if gw.vision.active() else -2
		if v != _cover_ver:
			_cover_ver = v
			queue_redraw()
		return
	_tint_update()
	var cam: MapCamera = gw.camera
	var b: bool = int(Time.get_ticks_msec() / 600) % 2 == 0
	var key: = Vector4(cam.position.x, cam.position.y, cam.zoom.x, float(gw.vision.ver))
	if key != _key or not gw.vision.reveals.is_empty() or (b != _blink and not gw.vision.markers().is_empty()):
		_key = key
		_blink = b
		queue_redraw()



func _tint_update() -> void :
	var v: Vision = gw.vision
	var on: bool = v.active() and v.img != null and gw.territory_tex != null and gw.data != null
	if not on:
		if _tint != null:
			_tint.visible = false
		_tint_ver = -1
		return
	if _tint == null:
		_tint = Sprite2D.new()
		_tint.name = "FogTint"
		_tint.centered = false
		_tint.show_behind_parent = true
		_tint.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_tint.scale = Vector2(Vision.GRID, Vision.GRID)
		var sh: = Shader.new()
		sh.code = TINT_SHADER
		var mat: = ShaderMaterial.new()
		mat.shader = sh
		_tint.material = mat
		add_child(_tint)
	_tint.visible = true
	var mat2: ShaderMaterial = _tint.material
	if v.vis_ver != _tint_ver:
		_tint_ver = v.vis_ver
		if _tint_tex == null or _tint_tex.get_width() != v.img.get_width() or _tint_tex.get_height() != v.img.get_height():
			_tint_tex = ImageTexture.create_from_image(v.img)
			_tint.texture = _tint_tex
			mat2.set_shader_parameter("grid_px", Vector2(v.img.get_width() * Vision.GRID, v.img.get_height() * Vision.GRID))
		else:
			_tint_tex.update(v.img)
		var mask: int = 0
		for c: Country in gw.countries:
			if c.id > 0 and c.id < 31 and v.friend(c.id):
				mask |= 1 << c.id
		if mask != _tint_mask:
			_tint_mask = mask
			mat2.set_shader_parameter("friend_mask", mask)
	if mat2.get_shader_parameter("owner_tex") != gw.territory_tex:
		mat2.set_shader_parameter("owner_tex", gw.territory_tex)
		mat2.set_shader_parameter("owner_px", Vector2(gw.data.w * GameWorld.CELL, gw.data.h * GameWorld.CELL))
	var a: float = TINT_A if int(gw.map_mode) == GameWorld.MapMode.NORMAL else TINT_A_MODES
	if a != _tint_a:
		_tint_a = a
		mat2.set_shader_parameter("strength", a)
		mat2.set_shader_parameter("fog_col", TINT_COL)


func icon_of(kind: int) -> AtlasTexture:
	if _icons.has(kind):
		return _icons[kind]
	var t: AtlasTexture = null
	var n: String = String(ICON.get(kind, "icon_target"))
	for nm: String in [n, "icon_strategic", "icon_target"]:
		if UiKit.has(nm):
			t = UiKit.tex(nm)
			break
	_icons[kind] = t
	return t


func _draw() -> void :
	if gw == null or gw.camera == null or gw.vision == null or not gw.vision.active():
		return
	if cover:
		_draw_cover()
		return
	var cam: MapCamera = gw.camera
	var z: float = cam.zoom.x
	var view: = Rect2(cam.screen_to_world(Vector2.ZERO), cam.view_size() / z).grow(40.0 / z)
	for rv: Dictionary in gw.vision.reveals:
		_scan(rv, z, view)
	var ms: Array = gw.vision.markers()
	if ms.is_empty():
		return
	var red: = Palette.c("alert_red")
	var dark: = Palette.c("ui_rubber")
	var fill: = Palette.c("ui_steel_dark")
	var s: float = (PIN_SCREEN + 0.25 * clampf(z - 1.0, 0.0, 1.0)) / z
	for m: Array in ms:
		var f: Facility = m[0]
		var p: Vector2 = m[1]
		if not view.has_point(p):
			continue

		if z >= 1.0 and not f.moving:
			_dashed(Rect2(Vector2(f.cell * GameWorld.CELL), Vector2(f.size * GameWorld.CELL)), Color(red, 0.85))

		draw_set_transform(p.round(), 0.0, Vector2(s, s))
		var card: = Rect2(-15, -38, 30, 30)
		draw_rect(card.grow(1), dark)
		draw_rect(card, red)
		draw_rect(card.grow(-2), fill)
		for k in 4:
			draw_rect(Rect2(-4 + k, -8 + k, 8 - 2 * k, 1), red)
		draw_rect(Rect2(-1, -4, 2, 1), dark)
		var t: AtlasTexture = icon_of(f.kind)
		if t != null:
			draw_texture_rect_region(t.atlas, Rect2(-12, -35, 24, 24), t.region)

		if _blink:
			draw_rect(Rect2(10, -38, 5, 5), Palette.c("amber"))
	draw_set_transform(Vector2.ZERO)


func _dashed(r: Rect2, col: Color) -> void :
	var x0: float = r.position.x
	var y0: float = r.position.y
	var x1: float = r.end.x - 1.0
	var y1: float = r.end.y - 1.0
	var x: float = x0
	while x <= x1:
		draw_rect(Rect2(x, y0, minf(2.0, x1 - x + 1.0), 1), col)
		draw_rect(Rect2(x, y1, minf(2.0, x1 - x + 1.0), 1), col)
		x += 4.0
	var y: float = y0
	while y <= y1:
		draw_rect(Rect2(x0, y, 1, minf(2.0, y1 - y + 1.0)), col)
		draw_rect(Rect2(x1, y, 1, minf(2.0, y1 - y + 1.0)), col)
		y += 4.0




func _scan(rv: Dictionary, z: float, view: Rect2) -> void :
	var c: Vector2 = (rv["c"] as Vector2).round()
	var r: float = float(rv["r"])
	if not view.grow(r).has_point(c):
		return
	var t: float = gw.game_time - float(rv["t0"])
	var left: float = float(rv["until"]) - gw.game_time
	var a: float = clampf(left / 3.0, 0.0, 1.0) * clampf(t / 0.4, 0.0, 1.0)
	var blue: = Palette.c("intercept_cyan")
	var w: float = maxf(1.0, 1.5 / z)
	var grow_k: float = clampf(t / 1.2, 0.0, 1.0)
	var rr: float = r * (1.0 - (1.0 - grow_k) * (1.0 - grow_k))
	draw_circle(c, rr, Color(blue, 0.16 * a))
	if t < 0.3:
		draw_circle(c, rr, Color(1, 1, 1, 0.45 * (1.0 - t / 0.3)))

	var step: float = 16.0 if z >= 0.5 else 32.0
	var y: float = - floorf(rr / step) * step
	while y <= rr:
		var hw: float = sqrt(maxf(0.0, rr * rr - y * y))
		var col: = Color(blue, (0.32 if int(absf(y) / step) % 2 == 0 else 0.16) * a)
		draw_line(c + Vector2( - hw, y), c + Vector2(hw, y), col, w)
		draw_line(c + Vector2(y, - hw), c + Vector2(y, hw), col, w)
		y += step

	if grow_k < 1.0:
		draw_arc(c, rr, 0.0, TAU, 64, Color(Palette.c("white"), 0.9 * a), w * 2.0)
	var seg: int = 32
	var rot: float = t * 0.25
	for k in seg:
		if k % 2 == 0:
			var a0: float = rot + TAU * float(k) / float(seg)
			draw_arc(c, rr, a0, a0 + TAU / float(seg), 4, Color(blue, 0.9 * a), w * 2.0)

	var ang: float = t * 2.2
	for k in 6:
		var aa: float = ang - float(k) * 0.07
		draw_line(c, c + Vector2.from_angle(aa) * rr, Color(blue, (0.55 - float(k) * 0.09) * a), w)

	var tk: float = 10.0 / maxf(z, 0.25)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var q: = c + Vector2(sx, sy) * rr * 0.72
			draw_line(q, q - Vector2(sx * tk, 0), Color(blue, 0.9 * a), w)
			draw_line(q, q - Vector2(0, sy * tk), Color(blue, 0.9 * a), w)




func _draw_cover() -> void :
	var tv: TerrainView = gw.terrain
	if tv == null or tv.tex == null:
		return
	for f: Facility in gw.vision.covers():
		var src: Rect2 = _src.get(f, Rect2())
		if src.size == Vector2.ZERO:
			src = _pick_src(f)
			_src[f] = src
		draw_texture_rect_region(tv.tex, Rect2(Vector2(f.cell * GameWorld.CELL), Vector2(f.size * GameWorld.CELL)), src)


func _pick_src(f: Facility) -> Rect2:
	var d: WorldData = gw.data
	var best: = Rect2(Vector2(f.cell), Vector2(f.size))
	var bn: int = -1
	for off: Vector2i in [Vector2i( - f.size.x - 1, 0), Vector2i(f.size.x + 1, 0), Vector2i(0, f.size.y + 1), Vector2i(0, - f.size.y - 1)]:
		var o: Vector2i = f.cell + off
		var n: int = 0
		for y in range(o.y, o.y + f.size.y, 2):
			for x in range(o.x, o.x + f.size.x, 2):
				if d.inside(x, y) and Biome.is_natural_land(d.get_biome(x, y)):
					n += 1
		if n > bn:
			bn = n
			best = Rect2(Vector2(o), Vector2(f.size))
	return best
