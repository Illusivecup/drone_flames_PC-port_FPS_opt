extends Node2D








const MapShader = preload("res://world/strat_map.gdshader")


const ST = preload("res://world/strat_terrain.gd")
const StratModes = preload("res://world/strat_modes.gd")
const LO_DT: float = 20.0
const SYNC_DT: float = 0.5
const KEEP: Array[String] = ["Labels", "Ops", "UnitsNight", "PendingGhost"]
const Z_MAP: int = 8
const Z_KEEP: int = 9
const Z_LABELS: int = 10
const HINT_S: float = 1.6

var gw: GameWorld
var mat: ShaderMaterial
var marks: Node2D
var lo_tex: ImageTexture = null
var _lo_dirty: bool = true
var _lo_t: float = 99.0
var _lo_task: int = -1
var _lo_src: Array = []
var _lo_out: Image = null
var modes: Node2D
var lo_ms: int = 0
var lo_bytes: int = 0
var _lo_t0: int = 0
var _mm: int = -1
var _k: float = 0.0
var _lifted: bool = false
var _full: bool = false
var _hidden: Array[CanvasItem] = []
var _saved: PackedByteArray = PackedByteArray()
var _keep: Array[CanvasItem] = []
var _keep_z: PackedInt32Array = PackedInt32Array()
var _sync_t: float = 99.0
var _war_key: PackedInt32Array = PackedInt32Array()
var _px: float = -1.0
var _hint_t: float = 0.0
var _hinted: bool = false
var _hint_first: bool = true
var _rect: Rect2 = Rect2()
var _data_id: int = 0
var stats_hidden: int = 0


static func make(world: GameWorld) -> Node2D:
	var l: Node2D = (load("res://world/strat_layer.gd") as GDScript).new()
	l.name = "Strat"
	l.set("gw", world)
	return l


func _ready() -> void :
	mat = ShaderMaterial.new()
	mat.shader = MapShader
	material = mat
	z_index = Z_MAP
	visible = false
	marks = Node2D.new()
	marks.name = "StratHint"
	marks.z_index = Z_LABELS + 1
	marks.z_as_relative = false
	marks.draw.connect(_draw_hint)
	add_child(marks)
	modes = StratModes.new()
	modes.name = "StratModes"
	modes.set("gw", gw)
	add_child(modes)
	mat.set_shader_parameter("pal", ST.palette())
	_war_key.resize(9)
	var tv: Variant = gw.get("terrain")
	if tv is TerrainView:
		(tv as TerrainView).cells_changed.connect( func(_c: Array) -> void : _lo_dirty = true)


func _exit_tree() -> void :
	if _lo_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_lo_task)
		_lo_task = -1


func _process(delta: float) -> void :
	if gw == null or gw.camera == null or gw.data == null:
		return
	var cam: MapCamera = gw.camera
	_lo_tick(delta, cam)
	var k: float = cam.strat_k()
	if lo_tex == null:
		k = 0.0
	if k <= 0.001:
		if visible or _lifted or _full:
			_leave()
		_hinted = false
		return

	var mm: int = int(gw.map_mode)
	var ml: Variant = gw.get("map_layer")
	if ml is MapModeLayer and (ml as MapModeLayer).focus_id >= 0:
		mm = GameWorld.MapMode.MY_LAND
	if mm != _mm:
		_mm = mm
		mat.set_shader_parameter("map_mode", mm)
	if not visible:
		visible = true
		_lift(true)
		_sync_t = 99.0
	if _k != k:
		_k = k
		mat.set_shader_parameter("fade", k)
	var px: float = 1.0 / maxf(cam.zoom.x, 0.001)
	if not is_equal_approx(px, _px):
		_px = px
		mat.set_shader_parameter("px_world", px)
	_sync_t += delta
	if _sync_t >= SYNC_DT:
		_sync_t = 0.0
		_sync()
	var full: bool = k >= 0.999
	if full and not _full:
		_hide_world()
		if not _hinted:
			_hinted = true
			_hint_t = HINT_S + (1.2 if _hint_first else 0.0)
	elif not full and _full:
		_show_world()
	if _full:
		for i in _hidden.size():
			var ci: CanvasItem = _hidden[i]
			if is_instance_valid(ci) and ci.visible:
				ci.visible = false
	modes.call("tick", delta, k)
	if _hint_t > 0.0:
		_hint_t = maxf(0.0, _hint_t - delta)
		if _hint_t <= 0.0:
			_hint_first = false
		marks.queue_redraw()
	var r: Rect2 = Rect2(Vector2.ZERO, cam.world_px).grow(maxf(cam.world_px.x, cam.world_px.y))
	if r != _rect:
		_rect = r
		queue_redraw()


func _draw() -> void :
	if lo_tex == null:
		return
	draw_rect(_rect, Color.WHITE)



func _leave() -> void :
	if _full:
		_show_world()
	_lift(false)
	visible = false
	_k = 0.0
	_mm = -1
	if modes != null:
		modes.call("hide_all")


func _lift(on: bool) -> void :
	if on == _lifted:
		return
	_lifted = on
	if on:
		_keep.clear()
		_keep_z.resize(0)
		for nm: String in KEEP:
			var n: Node = gw.get_node_or_null(NodePath(nm))
			if n is CanvasItem:
				_keep.append(n as CanvasItem)
				_keep_z.append((n as CanvasItem).z_index)
				(n as CanvasItem).z_index = Z_LABELS if nm == "Labels" else Z_KEEP
	else:
		for i in _keep.size():
			if is_instance_valid(_keep[i]):
				_keep[i].z_index = _keep_z[i]
		_keep.clear()


func _hide_world() -> void :
	_full = true
	_hidden.clear()
	_saved.resize(0)
	for ch: Node in gw.get_children():
		if ch == self or not (ch is CanvasItem) or KEEP.has(String(ch.name)):
			continue
		_hidden.append(ch as CanvasItem)
		_saved.append(1 if (ch as CanvasItem).visible else 0)
		(ch as CanvasItem).visible = false
	stats_hidden = _hidden.size()


func _show_world() -> void :
	_full = false
	for i in _hidden.size():
		if is_instance_valid(_hidden[i]):
			_hidden[i].visible = _saved[i] == 1
	_hidden.clear()


	gw.camera.zoom_changed.emit(gw.camera.zoom.x)

	var ml: Variant = gw.get("map_layer")
	if ml is MapModeLayer and (ml as MapModeLayer).overlay != null:
		(ml as MapModeLayer).overlay.visible = int(gw.map_mode) != GameWorld.MapMode.NORMAL or (ml as MapModeLayer).focus_id >= 0



func _sync() -> void :
	var tm: ShaderMaterial = gw.territory_border.material as ShaderMaterial if gw.territory_border != null else null
	if tm == null:
		return
	mat.set_shader_parameter("owner_tex", gw.territory_tex)
	mat.set_shader_parameter("terrain_idx", lo_tex)
	mat.set_shader_parameter("world_size", Vector2(gw.data.w, gw.data.h))
	for nm: String in ["colors", "ally_cols", "over_cols", "war_bits", "player_id"]:
		var v: Variant = tm.get_shader_parameter(nm)
		if v != null:
			mat.set_shader_parameter(nm, v)
	var sky: = PackedColorArray()
	sky.resize(9)
	sky.fill(Color(0, 0, 0, 0))
	var sl: Node = gw.get_node_or_null("SkyCover")
	if sl != null and sl.has_method("read_pairs"):
		for p: Array in (sl.call("read_pairs") as Array):
			var c: Country = gw.country_by_id(int(p[0]))
			var h: int = int(p[1])
			if c != null and h > 0 and h < 9:
				sky[h] = Color(c.color, 1.0)
	mat.set_shader_parameter("sky_cols", sky)






func _lo_tick(delta: float, cam: MapCamera) -> void :
	_lo_t += delta
	if _lo_task >= 0:
		if WorkerThreadPool.is_task_completed(_lo_task):
			WorkerThreadPool.wait_for_task_completion(_lo_task)
			_lo_task = -1
			if _lo_out != null:
				if lo_tex != null and lo_tex.get_size() == Vector2(_lo_out.get_size()):
					lo_tex.update(_lo_out)
				else:
					lo_tex = ImageTexture.create_from_image(_lo_out)
				lo_bytes = _lo_out.get_data_size()
				mat.set_shader_parameter("terrain_idx", lo_tex)
				mat.set_shader_parameter("idx_cells", float(gw.data.w) / float(_lo_out.get_width()))
				mat.set_shader_parameter("idx_levels", _lo_out.get_mipmap_count())
				print("[Strat] colour map %dx%d + %d mips in %d ms (worker), %d KB" % [_lo_out.get_width(), _lo_out.get_height(), _lo_out.get_mipmap_count(), lo_ms, lo_bytes / 1024])
			_lo_src = []
			_lo_out = null
		return
	if gw.data.get_instance_id() != _data_id:
		_data_id = gw.data.get_instance_id()
		_lo_dirty = true
		_lo_t = 99.0
		lo_tex = null
		if visible or _lifted or _full:
			_leave()
	if not _lo_dirty or (lo_tex != null and (_lo_t < LO_DT or cam.zoom.x > MapCamera.strat_top() + 0.1)):
		return
	var tv: Variant = gw.get("terrain")
	if not (tv is TerrainView) or (tv as TerrainView).image == null:
		return
	_lo_dirty = false
	_lo_t = 0.0
	var d: WorldData = gw.data
	_lo_src = [d.biome.duplicate(), d.height.duplicate(), d.w, d.h, d.lakes.duplicate(true), d.hills_thr]
	_lo_t0 = Time.get_ticks_msec()
	_lo_task = WorkerThreadPool.add_task(_lo_build, false, "strat_lo")


func _lo_build() -> void :
	var a: Array = _lo_src
	_lo_out = ST.build(a[0], a[1], int(a[2]), int(a[3]), a[4], int(a[5]))
	lo_ms = Time.get_ticks_msec() - _lo_t0




func _draw_hint() -> void :
	if _hint_t <= 0.0 or gw == null or gw.camera == null:
		return
	var cam: MapCamera = gw.camera
	var z: float = cam.zoom.x
	var a: float = clampf(_hint_t / 0.4, 0.0, 1.0) * clampf((HINT_S + (1.2 if _hint_first else 0.0) - _hint_t) / 0.25, 0.0, 1.0)
	var font: Font = UiKit.f_black if UiKit.f_black != null else ThemeDB.fallback_font
	var t1: String = Loc.t("СТРАТЕГИЧЕСКИЙ МАСШТАБ")
	var t2: String = Loc.t("двойной тап — к месту") if _hint_first else ""
	var w1: float = font.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var w2: float = font.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x if t2 != "" else 0.0
	var w: float = roundf(maxf(w1, w2) + 24.0)
	var h: float = 22.0 if t2 == "" else 36.0
	var vs: Vector2 = cam.view_size()
	var top: Vector2 = Vector2(roundf(vs.x * 0.5 - w * 0.5), roundf(vs.y - cam.margin_bottom_px - h - 14.0))
	marks.draw_set_transform(cam.screen_to_world(top), 0.0, Vector2(1.0 / z, 1.0 / z))
	var ink: = Color(0.043, 0.06, 0.13)
	marks.draw_rect(Rect2(-1, -1, w + 2, h + 2), Color(ink, 0.9 * a))
	marks.draw_rect(Rect2(0, 0, w, h), Color(0.09, 0.11, 0.17, 0.92 * a))
	marks.draw_rect(Rect2(0, 0, w, 1), Color(UiKit.GOLD, 0.9 * a))
	marks.draw_string(font, Vector2(roundf((w - w1) * 0.5), 16), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UiKit.GOLD, a))
	if t2 != "":
		marks.draw_string(font, Vector2(roundf((w - w2) * 0.5), 30), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.86, 0.82, a))
	marks.draw_set_transform(Vector2.ZERO)
