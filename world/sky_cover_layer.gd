extends Node2D
















const PERIOD: float = 0.5
const PIN_ZOOM: float = 0.45
const FADE_S: float = 0.6
const FLASH_S: float = 1.2
const GROUP: float = 34.0
const BADGE: float = 18.0
const AD_KINDS: Array = [Facility.Kind.AD_MFG, Facility.Kind.AD_SPAAG, Facility.Kind.AD_SAM, Facility.Kind.AD_PATRIOT, Facility.Kind.AD_INT, Facility.Kind.AD_RADAR, Facility.Kind.AD_EW]
const K: int = 4096

var gw: GameWorld
var dome: Sprite2D
var rim: Sprite2D
var _mats: Array[ShaderMaterial] = []
var _pins: Node2D
var _icon: Texture2D = null
var _t: float = 99.0
var _z: float = -1.0
var _px: float = -1.0
var _tint: float = -1.0
var _key: String = "-"
var _tex: Texture2D = null
var _dist_ok: bool = false
var _alpha: float = 0.0
var _want: float = 0.0
var _pairs: Array = []
var _sites: Array = []
var _kills: Dictionary = {}
var _flash: PackedFloat32Array = PackedFloat32Array()
var _flashing: bool = false
var _attached: bool = false
var stats_pairs: int = 0
var stats_pins: int = 0
var stats_flash: int = 0


static func make(world: GameWorld) -> Node2D:
	var l: Node2D = (load("res://world/sky_cover_layer.gd") as GDScript).new()
	l.name = "SkyCover"
	l.set("gw", world)
	return l



static func coverers(world: GameWorld, h: int) -> Array:
	if world == null or world.diplo == null:
		return []
	var sc: Variant = world.diplo.get("sky")
	if sc != null and (sc as Object).has_method("coverers_of"):
		return (sc as Object).call("coverers_of", h)
	return []


func _sprite(nm: String, m: int) -> Sprite2D:
	var s: = Sprite2D.new()
	s.name = nm
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat: = ShaderMaterial.new()
	mat.shader = load("res://world/sky_cover.gdshader") as Shader
	mat.set_shader_parameter("mode", m)
	s.material = mat
	s.visible = false
	_mats.append(mat)
	return s


func _ready() -> void :
	_flash.resize(9)
	dome = _sprite("SkyDome", 0)
	rim = _sprite("SkyRim", 1)
	_pins = Node2D.new()
	_pins.name = "SkyPins"
	_pins.draw.connect(_draw_pins)
	add_child(_pins)
	visible = false
	_attach.call_deferred()




func _attach() -> void :
	if _attached or gw == null:
		return
	if gw.territory != null and gw.territory_border != null:
		gw.territory.add_child(dome)
		gw.territory_border.add_child(rim)
	else:
		dome.scale = Vector2(GameWorld.CELL, GameWorld.CELL)
		rim.scale = dome.scale
		add_child(dome)
		add_child(rim)
	_attached = true



func read_pairs() -> Array:
	var out: Array = []
	if gw == null or gw.diplo == null:
		return out
	var sc: Variant = gw.diplo.get("sky")
	if sc != null and (sc as Object).get("sky") is Dictionary:
		for k: Variant in ((sc as Object).get("sky") as Dictionary):
			var c: int = int(k) / K
			var h: int = int(k) % K
			if c > 0 and h > 0 and c != h and gw.country_by_id(c) != null and gw.country_by_id(h) != null:
				out.append([c, h])
	elif gw.diplo.has_method("sky_pairs"):
		var raw: Variant = gw.diplo.call("sky_pairs")
		if typeof(raw) == TYPE_ARRAY:
			for p: Variant in raw:
				if typeof(p) == TYPE_ARRAY and (p as Array).size() >= 2 and int(p[0]) != int(p[1]):
					out.append([int(p[0]), int(p[1])])
	out.sort()
	return out


func _check_flash() -> void :
	var sc: Variant = gw.diplo.get("sky") if gw.diplo != null else null
	if sc == null or not ((sc as Object).get("sky") is Dictionary):
		return
	var d: Dictionary = (sc as Object).get("sky")
	var seen: Dictionary = {}
	for k: Variant in d:
		var n: int = int((d[k] as Dictionary).get("kills", 0))
		seen[int(k)] = n
		if n > int(_kills.get(int(k), n)):
			var h: int = int(k) % K
			if h >= 0 and h < 9:
				_flash[h] = 1.0
				_flashing = true
				stats_flash += 1
	_kills = seen


func _process(delta: float) -> void :
	if gw == null or gw.data == null or gw.camera == null:
		return
	_t += delta
	var z: float = gw.camera.zoom.x
	if _t >= PERIOD:
		_t = 0.0
		_pairs = read_pairs()
		stats_pairs = _pairs.size()
		var mode: int = int(gw.map_mode)
		var hide: bool = mode == GameWorld.MapMode.ORES or mode == GameWorld.MapMode.LOGISTICS or (gw.map_layer != null and gw.map_layer.focus_id >= 0)
		_want = 0.0 if (_pairs.is_empty() or hide) else 1.0
		if not _pairs.is_empty():
			_push_uniforms()
			if gw.territory_border != null and gw.territory_border.material is ShaderMaterial:
				var nc: Variant = (gw.territory_border.material as ShaderMaterial).get_shader_parameter("night_comp")
				if nc is Vector3:
					for m: ShaderMaterial in _mats:
						m.set_shader_parameter("night_comp", nc)
			_check_flash()
			_collect_pins()
		_pins.queue_redraw()
	if _alpha != _want:
		_alpha = move_toward(_alpha, _want, delta / FADE_S)
		for m: ShaderMaterial in _mats:
			m.set_shader_parameter("fade", _alpha)
		_pins.modulate.a = _alpha
	var on: bool = _alpha > 0.0
	visible = on
	dome.visible = on
	rim.visible = on
	if not on:
		return
	var px: float = 1.0 / maxf(z, 0.01)
	if not is_equal_approx(px, _px):
		_px = px
		var k: float = clampf((z - 0.3) / 0.7, 0.0, 1.0)
		for m: ShaderMaterial in _mats:
			m.set_shader_parameter("px_world", px)
			m.set_shader_parameter("tint", lerpf(0.2, 0.06, k))
			m.set_shader_parameter("lat_a", lerpf(0.3, 0.0, clampf(k * 1.4, 0.0, 1.0)))
	if _flashing:
		_flashing = false
		for i in 9:
			if _flash[i] > 0.0:
				_flash[i] = maxf(0.0, _flash[i] - delta / FLASH_S)
				_flashing = true
		for m: ShaderMaterial in _mats:
			m.set_shader_parameter("flash", _flash)
	if not is_equal_approx(z, _z):
		_z = z
		_pins.queue_redraw()


func _push_uniforms() -> void :
	if gw.territory_tex != _tex:
		_tex = gw.territory_tex
		dome.texture = _tex
		rim.texture = _tex
		for m: ShaderMaterial in _mats:
			m.set_shader_parameter("owner_tex", _tex)
			m.set_shader_parameter("world_size", Vector2(gw.data.w, gw.data.h))
		_dist_ok = false
	if not _dist_ok and gw.map_layer != null:
		var vps: Variant = gw.map_layer.get("_vps")
		if typeof(vps) == TYPE_ARRAY and (vps as Array).size() >= 3:
			for m: ShaderMaterial in _mats:
				m.set_shader_parameter("dist_tex", ((vps as Array)[2] as SubViewport).get_texture())
				m.set_shader_parameter("has_dist", true)
			_dist_ok = true
	var a: = PackedColorArray()
	var b: = PackedColorArray()
	a.resize(9)
	b.resize(9)
	for i in 9:
		a[i] = Color(0, 0, 0, 0)
		b[i] = Color(0, 0, 0, 0)
	var key: String = ""
	for p: Array in _pairs:
		var h: int = p[1]
		if h >= 9:
			continue
		var col: Color = col_of(gw, p[0])
		if a[h].a < 0.5:
			a[h] = col
		elif b[h].a < 0.5:
			b[h] = col
		key += "%d>%d|%s," % [p[0], h, col.to_html()]
	if key != _key:
		_key = key
		for m: ShaderMaterial in _mats:
			m.set_shader_parameter("cov_a", a)
			m.set_shader_parameter("cov_b", b)



static func col_of(world: GameWorld, cid: int) -> Color:
	var c: Country = world.country_by_id(cid)
	if c == null:
		return Color.WHITE
	var col: Color = c.color
	if col.get_luminance() < 0.42:
		col = col.lightened(0.42 - col.get_luminance())
	return Color(col, 1.0)



func _collect_pins() -> void :
	_sites.clear()
	if _pairs.is_empty() or gw.mil == null:
		return
	var hosts: Dictionary = {}
	for p: Array in _pairs:
		if not hosts.has(p[0]):
			hosts[p[0]] = []
		(hosts[p[0]] as Array).append(p[1])
	var pid: int = gw.player.id if gw.player != null else 0
	var vis: Vision = gw.vision
	for f: Facility in gw.mil.facilities:
		if not hosts.has(f.country_id) or not (f.kind in AD_KINDS) or not gw.mil.alive(f):
			continue
		var p: Vector2 = f.mpos if f.moving else f.center_px()
		var cell: = Vector2i(int(p.x) / GameWorld.CELL, int(p.y) / GameWorld.CELL)
		if not gw.data.inside(cell.x, cell.y) or not (gw.data.get_owner_id(cell.x, cell.y) in (hosts[f.country_id] as Array)):
			continue
		if f.country_id != pid and vis != null and vis.active() and not vis.friend(f.country_id):
			if not vis.known(f):
				continue
			if not vis.fac_shown(f):
				p = vis.last_pos(f)
		_sites.append([p, f.country_id])



func _draw_pins() -> void :
	stats_pins = 0
	if _sites.is_empty() or _z < PIN_ZOOM:
		return
	if _icon == null:
		_icon = UiKit.tex("d331_sky_16") if UiKit.has("d331_sky_16") else null
		if _icon == null:
			return
	var inv: float = 1.0 / maxf(_z, 0.01)
	var groups: Array = []
	for s: Array in _sites:
		var p: Vector2 = s[0]
		var hit: bool = false
		for g: Array in groups:
			if int(g[2]) == int(s[1]) and ((g[0] as Vector2) / float(g[1])).distance_to(p) * _z < GROUP:
				g[0] = (g[0] as Vector2) + p
				g[1] = int(g[1]) + 1
				hit = true
				break
		if not hit:
			groups.append([p, 1, int(s[1])])
	var font: Font = UiKit.f_black if UiKit.f_black != null else ThemeDB.fallback_font

	var names: Array = []
	if gw.labels != null and gw.labels.get("_clabels") is Array:
		var ca: Variant = gw.labels.get("_ca")
		for geo: Variant in (gw.labels.get("_clabels") as Array):
			var gd: Dictionary = geo
			if not gd.has("b") or not gd.has("p") or (ca is Dictionary and float((ca as Dictionary).get(int(gd.get("id", -1)), 0.0)) < 0.3):
				continue
			var bb: Rect2 = gd["b"]
			names.append(Rect2((gd["p"] as Vector2) + bb.position * inv, bb.size * inv))
	for g2: Array in groups:
		var at: Vector2 = (g2[0] as Vector2) / float(g2[1])
		for nr: Rect2 in names:
			if nr.grow(2.0 * inv).intersects(Rect2(at + Vector2(6.0, 2.0) * inv, Vector2(BADGE + 22.0, BADGE) * inv)):
				at.y = nr.end.y + 2.0 * inv
		var col: Color = col_of(gw, int(g2[2]))

		_pins.draw_set_transform(at, 0.0, Vector2(inv, inv))
		var r: = Rect2(Vector2(6.0, 2.0), Vector2(BADGE, BADGE))
		_pins.draw_rect(r.grow(1.0), Color(0.043, 0.06, 0.13, 0.92))
		_pins.draw_rect(r, col.darkened(0.25))
		_pins.draw_rect(r.grow(-1.0), Color(0.07, 0.1, 0.18, 0.95))
		_pins.draw_texture_rect(_icon, Rect2(r.position + Vector2(1.0, 1.0), Vector2(16, 16)), false)
		var n: int = g2[1]
		if n > 1:
			var tx: String = "×%d" % n
			var tp: = Vector2(r.end.x + 2.0, r.end.y - 2.0)
			_pins.draw_string_outline(font, tp, tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, Color(0.043, 0.06, 0.13, 0.95))
			_pins.draw_string(font, tp, tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col.lightened(0.35))
		stats_pins += 1
	_pins.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
