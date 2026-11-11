class_name VfxClouds
extends Node2D






const CLOUD_MAX_A: float = 0.72
const SHADOW_A: float = 0.1
const DRIFT_K: float = 0.7

static var _noise: Texture2D = null

var vfx: Vfx
var _mat: ShaderMaterial
var _drift: Vector2 = Vector2.ZERO
var _rect: Rect2 = Rect2()
var _pts: PackedVector4Array = PackedVector4Array()
const MAX_PTS: int = 8
var _mat_sh: ShaderMaterial
var _dim: float = 1.0
var _hot: = Vector2.INF
var _hot_t: float = 0.0
var _own_t: float = 0.0
const LAND_STEP: int = 8
const OWN_K: float = 0.4
const WAR_K: float = 0.6
var _land_img: = Image.create(1, 1, false, Image.FORMAT_L8)
var _land_b: = PackedByteArray()
var _land_war: = PackedByteArray()
var _land_tex: ImageTexture = null


func _ready() -> void :
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://world/vfx_clouds.gdshader") as Shader
	var nt: Texture2D = noise_tex()
	_mat.set_shader_parameter("cloud_tex", nt)
	_mat.set_shader_parameter("cloud_lin", nt)
	material = _mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_pts.resize(MAX_PTS)
	_mat_sh = ShaderMaterial.new()
	var sh: = Shader.new()
	sh.code = _mat.shader.code.replace("render_mode unshaded;", "render_mode unshaded;" + String.chr(10) + "#define SHADOW_ONLY")
	_mat_sh.shader = sh
	_mat_sh.set_shader_parameter("cloud_tex", nt)
	_mat_sh.set_shader_parameter("cloud_lin", nt)
	_drift = Vector2(float(Hash32.h2(7, 11, 3) % 4096), float(Hash32.h2(5, 9, 1) % 4096))




static func noise_tex() -> Texture2D:
	if _noise == null:
		var path: String = "res://assets/sprites/vfx19_clouds.png"
		if ResourceLoader.exists(path):
			_noise = load(path) as Texture2D
		else:
			var img: = Image.load_from_file(ProjectSettings.globalize_path(path))
			if img != null and not img.is_empty():
				_noise = ImageTexture.create_from_image(img)
	return _noise


func _process(delta: float) -> void :
	var gw: GameWorld = vfx.gw if vfx != null else null
	if gw == null or gw.camera == null or gw.data == null:
		return
	visible = GameConfig.clouds and _noise != null
	if not visible:
		return
	var us: int = Time.get_ticks_usec()
	var cam: MapCamera = gw.camera
	var z: float = cam.zoom.x
	_drift += Vfx.wind * DRIFT_K * delta * FxLayer.cosmetic_scale(maxf(gw.time_scale, 0.0))
	_drift = Vector2(fposmod(_drift.x, 4096.0), fposmod(_drift.y, 4096.0))
	var half: Vector2 = cam.view_size() * 0.5 / z
	var r: = Rect2(cam.position - half - Vector2(16, 16), half * 2.0 + Vector2(32, 32))
	if r != _rect:
		_rect = r
		queue_redraw()
	var ca: float = CLOUD_MAX_A * clampf((0.75 - z) / 0.25, 0.0, 1.0)
	var dim_t: float = 0.2 if vfx.focus_dim else 1.0
	if _dim != dim_t:
		_dim = move_toward(_dim, dim_t, delta * 3.0)
		_mat.set_shader_parameter("dim", _dim)
	var m: ShaderMaterial = _mat if ca > 0.003 else _mat_sh
	if material != m:
		material = m
	m.set_shader_parameter("drift", _drift)
	m.set_shader_parameter("cloud_a", ca)
	m.set_shader_parameter("shadow_a", SHADOW_A * (1.0 - 0.4 * gw.night.factor if gw.night != null else 1.0))
	if ca > 0.003:
		_own_t -= delta
		if _own_t <= 0.0:
			_own_t = 1.0
			_owner_uniforms(gw)
		_clear_points(gw, cam, half)
	Vfx.cost("clouds", Time.get_ticks_usec() - us)




func _owner_uniforms(gw: GameWorld) -> void :
	var d: WorldData = gw.data
	if gw.player == null or d.owners.size() != d.w * d.h:
		_mat.set_shader_parameter("land_px", Vector2.ZERO)
		return
	var mw: int = maxi(1, d.w / LAND_STEP)
	var mh: int = maxi(1, d.h / LAND_STEP)
	if _land_b.size() != mw * mh:
		_land_b.resize(mw * mh)
	var pid: int = gw.player.id
	if _land_war.size() != 64:
		_land_war.resize(64)
	_land_war.fill(0)
	for cid: Variant in gw.player.at_war:
		if int(cid) > 0 and int(cid) < 64:
			_land_war[int(cid)] = 1
	var o: PackedByteArray = d.owners
	var h: int = LAND_STEP / 2
	for my in mh:
		var row: int = (my * LAND_STEP + h) * d.w
		for mx in mw:
			var id: int = o[row + mx * LAND_STEP + h]
			var k: float = 1.0
			if id == pid:
				k = OWN_K
			elif id > 0 and id < 64 and _land_war[id] == 1:
				k = WAR_K
			_land_b[my * mw + mx] = int(k * 255.0)
	_land_img.set_data(mw, mh, false, Image.FORMAT_L8, _land_b)
	if _land_tex == null or _land_tex.get_width() != mw or _land_tex.get_height() != mh:
		_land_tex = ImageTexture.create_from_image(_land_img)
		_mat.set_shader_parameter("land_tex", _land_tex)
	else:
		_land_tex.update(_land_img)
	_mat.set_shader_parameter("land_px", Vector2(mw * LAND_STEP * GameWorld.CELL, mh * LAND_STEP * GameWorld.CELL))





func _clear_points(gw: GameWorld, cam: MapCamera, half: Vector2) -> void :
	var n: int = 0
	var z: float = maxf(cam.zoom.x, 0.05)
	for fp: Vector2 in vfx.focus_pts:
		if n >= 2:
			break
		_pts[n] = Vector4(fp.x, fp.y, z / 150.0, 0.0)
		n += 1
	var sel: Facility = gw.selected_facility()
	if sel != null:
		var sp: Vector2 = sel.center_px()
		_pts[n] = Vector4(sp.x, sp.y, 1.0 / maxf(160.0, 90.0 / z), 0.1)
		n += 1
	var pl: Country = gw.player
	if pl != null and pl.capital_id >= 0 and pl.capital_id < gw.cities.size():
		var cap: City = gw.cities[pl.capital_id]
		var cc: = Vector2(cap.center * GameWorld.CELL)
		_pts[n] = Vector4(cc.x, cc.y, 1.0 / (float(cap.radius + 22) * GameWorld.CELL), 0.05)
		n += 1
	var view: = Rect2(cam.position - half, half * 2.0).grow(half.x * 0.3)
	for ap: Vector4 in vfx.army_pts:
		if n >= MAX_PTS - 3:
			break
		if ap.w > 0.5 and view.has_point(Vector2(ap.x, ap.y)):
			_pts[n] = Vector4(ap.x, ap.y, 1.0 / maxf(ap.z * 1.6, 70.0 / z), 0.12)
			n += 1
	_hot_t -= get_process_delta_time()
	if _hot_t <= 0.0:
		_hot_t = 0.5
		_hot = Vector2.INF
		if gw.battle_watch != null and pl != null and not pl.at_war.is_empty():
			var hs: Dictionary = gw.battle_watch.hot_spot()
			if hs.has("pos"):
				_hot = hs["pos"]
	if _hot != Vector2.INF and n < MAX_PTS - 2:
		_pts[n] = Vector4(_hot.x, _hot.y, z / 120.0, 0.1)
		n += 1
	if gw.ops != null and pl != null:
		for f: Variant in gw.ops.list:
			if n >= MAX_PTS - 2:
				break
			var fac: Facility = f as Facility
			if fac == null or fac.country_id != pl.id:
				continue
			var op: Dictionary = gw.ops.list[f]
			if op.get("front") is Vector2:
				var fr: Vector2 = op["front"]
				if view.has_point(fr):
					_pts[n] = Vector4(fr.x, fr.y, z / 100.0, 0.15)
					n += 1
	_pts[n] = Vector4(cam.position.x, cam.position.y, 1.0 / maxf(half.x * 0.6, 1.0), 0.5)
	n += 1
	if pl != null and n < MAX_PTS:

		var taken: int = 0
		var last_d: float = -1.0
		while n < MAX_PTS and taken < 4:
			var best: City = null
			var bd: float = INF
			for cid in pl.city_ids:
				if cid < 0 or cid >= gw.cities.size() or cid == pl.capital_id:
					continue
				var c: City = gw.cities[cid]
				var d: float = Vector2(c.center * GameWorld.CELL).distance_squared_to(cam.position)
				if d > last_d and d < bd:
					bd = d
					best = c
			if best == null:
				break
			last_d = bd
			var bp: = Vector2(best.center * GameWorld.CELL)
			_pts[n] = Vector4(bp.x, bp.y, 1.0 / (float(best.radius + 14) * GameWorld.CELL), 0.12)
			n += 1
			taken += 1
	_mat.set_shader_parameter("clear_pts", _pts)
	_mat.set_shader_parameter("clear_n", n)


func _draw() -> void :
	draw_rect(_rect, Color.WHITE)
