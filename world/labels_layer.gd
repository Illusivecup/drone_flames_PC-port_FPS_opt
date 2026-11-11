class_name LabelsLayer
extends Node2D

























const OUTLINE: = Color(0.043, 0.06, 0.13)
const MapDeclutterRec = preload("res://ui/ui24/map_declutter.gd")
const CN_FULL: float = 0.55
const CN_GONE: float = 0.8
const CN_MIN_FS: int = 11
const CN_MARGIN: float = 5.0
const CN_CAP: float = 0.72
const SAFE_RIGHT: float = 56.0
const SAFE_PAD: float = 4.0
const SAFE_TOP_EXTRA: float = 40.0
const SEARCH_BUDGET_US: int = 3000
const CITY_FADE: Array = [[0.55, 0.75], [0.65, 0.88], [0.8, 1.0]]
const MARK_FADE: = Vector2(0.4, 0.5)
const MAX_CITY: int = 30
const STRAT_MAX_CITY: int = 12
const HIT_MIN_H: float = 44.0
const HIT_MIN_W: float = 64.0
const StatusMark = preload("res://world/status_mark.gd")
const SkyLayer = preload("res://world/sky_cover_layer.gd")
const FLAG_SC: float = 2.0
const REGION_DT: float = 2.0
const REGION_IDLE: float = 12.0
const REGION_GRID: int = 192
const ROWS_PER_STEP: int = 16
const FADE_SPEED: float = 8.0
const BIG: int = 1 << 28

var gw: GameWorld

var stats_layout_us: int = 0
var stats_draw_us: int = 0
var stats_region_us: int = 0
var stats_labels: int = 0
var stats_passes: int = 0
var stats_searches: int = 0
var stats_search_us: int = 0
var dbg_fb: Dictionary = {}

var _data_id: int = 0
var _rg_stage: int = -1
var _rg_y: int = 0
var _rg_s: int = 4
var _rg_w: int = 0
var _rg_h: int = 0
var _rg_g: = PackedByteArray()
var _rg_l: = PackedByteArray()
var _rg_d: = PackedInt32Array()

var _run_ll: = PackedInt32Array()
var _run_lr: = PackedInt32Array()
var _run_ol: = PackedInt32Array()
var _run_or: = PackedInt32Array()
var _acc: Dictionary = {}
var _rg_dirty: bool = true
var _rg_t: float = 99.0
var _regions: Dictionary = {}
var _fit_cache: Dictionary = {}
var _cons_cache: Dictionary = {}
var _seen: Dictionary = {}

var _lay_key: = Vector3.INF
var _lay_mode: int = -1
var _lay_t: float = 0.0
var _relayout: bool = false
var _cn_sig: String = ""
var _vis_mask: int = 0
var _cam_prev: = Vector3.INF
var _clabels: Array = []
var _cl_last: Dictionary = {}
var _xlabels: Array = []
var _ca: Dictionary = {}
var _ct: Dictionary = {}
var _xa: Dictionary = {}
var _xt: Dictionary = {}
var _ma: float = 0.0
var _mt: float = 0.0
var _hits: Array = []
var _lines: Dictionary = {}
var _fv: Dictionary = {}
var _z: float = 1.0
var _blink_t: float = 0.0
var _blink_on: bool = true
var _has_unpowered: bool = false
var _tex: Dictionary = {}

var _blk: Array = []


var name_rects: Array[Rect2] = []
var name_ver: int = 0
var _boot: bool = true
var _boot_t: float = 0.0
var _boot_rg: float = 0.0


static func make(world: GameWorld) -> LabelsLayer:
	var l: = LabelsLayer.new()
	l.name = "Labels"
	l.gw = world
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(l)
	return l



func territory_changed() -> void :
	_rg_dirty = true



func force() -> void :
	_lay_key = Vector3.INF
	if _rg_stage < 0:
		_region_start()
	while _rg_stage >= 0:
		_region_step()
	_layout()
	for k: int in _ct:
		_ca[k] = _ct[k]
	for k: int in _xt:
		_xa[k] = _xt[k]
	_ma = _mt
	queue_redraw()





func country_at(screen_pos: Vector2) -> int:
	if gw == null or gw.camera == null:
		return -1
	if absf(gw.camera.zoom.x - _z) > 0.0001:
		_layout()
	for h: Array in _hits:
		var id: int = h[2]
		if float(_ca.get(id, 0.0)) < 0.35 or float(_ct.get(id, 0.0)) < 0.5:
			continue
		var sp: Vector2 = gw.camera.world_to_screen(h[0] as Vector2)
		var r: Rect2 = h[1]
		if Rect2(sp + r.position, r.size).has_point(screen_pos):
			return id
	return -1



func country_label_center(id: int) -> Vector2:
	for h: Array in _hits:
		if int(h[2]) == id and float(_ct.get(id, 0.0)) >= 0.5:
			var r: Rect2 = h[1]
			return gw.camera.world_to_screen(h[0] as Vector2) + r.get_center()
	return Vector2(-1, -1)





func knows(c: Country) -> bool:
	return c != null and not c.eliminated



func _contacted(c: Country) -> bool:
	if c.is_player or gw.player == null or gw.vision == null or not gw.vision.active():
		return true
	return gw.vision.friend(c.id) or (gw.diplo != null and gw.diplo.persona_known(c.id))


func _reset() -> void :
	_data_id = gw.data.get_instance_id()
	_regions = {}
	_seen = {}
	_ca = {}
	_ct = {}
	_xa = {}
	_xt = {}
	_clabels = []
	_xlabels = []
	_hits = []
	_rg_stage = -1
	_rg_dirty = true
	_rg_t = 99.0
	_lay_key = Vector3.INF
	_cl_last = {}
	_fit_cache = {}
	_acc = {}
	_boot = true
	_boot_t = 0.0
	_boot_rg = 0.0


func _process(delta: float) -> void :
	if gw == null or gw.camera == null or gw.data == null:
		return
	if gw.data.get_instance_id() != _data_id:
		_reset()
	_region_tick(delta)
	if _boot:
		_boot_pass(delta)
	var cam: MapCamera = gw.camera
	var z: float = cam.zoom.x
	_lay_t += delta
	var sp: Vector2 = cam.position * z
	var moved: float = Vector2(_lay_key.x, _lay_key.y).distance_to(sp) if _lay_key.x != INF else INF
	var redraw: bool = false

	var ck: = Vector3(cam.position.x, cam.position.y, z)
	if ck != _cam_prev:
		_cam_prev = ck
		if _visible_mask() != _vis_mask:
			_relayout = true
	if z != _lay_key.z or moved > 24.0 or _lay_t >= 0.5 or _relayout or int(gw.map_mode) != _lay_mode:
		_layout()
		redraw = true

	var k: float = minf(1.0, delta * FADE_SPEED)
	for id: int in _ct:
		var a: float = float(_ca.get(id, 0.0))
		var t: float = float(_ct[id])
		if absf(a - t) > 0.004:
			_ca[id] = a + (t - a) * k if absf(t - a) > 0.02 else t
			redraw = true
	for id: int in _xt:
		var a2: float = float(_xa.get(id, 0.0))
		var t2: float = float(_xt[id])
		if absf(a2 - t2) > 0.004:
			_xa[id] = a2 + (t2 - a2) * k if absf(t2 - a2) > 0.02 else t2
			redraw = true
	if absf(_ma - _mt) > 0.004:
		_ma = _ma + (_mt - _ma) * k if absf(_mt - _ma) > 0.02 else _mt
		redraw = true
	if _has_unpowered:
		_blink_t += delta
		if _blink_t >= 0.4:
			_blink_t = 0.0
			_blink_on = not _blink_on
			redraw = true
	if redraw:
		queue_redraw()





func _boot_pass(delta: float) -> void :
	_boot_t += delta
	_boot_rg -= delta
	if _boot_t > 4.0:
		_boot = false
		return
	if _regions.is_empty() or _rg_dirty:
		if _boot_rg > 0.0:
			return
		_boot_rg = 0.25
		if not _regions.is_empty():



			if _rg_stage < 0:
				_region_start()
		else:
			if _rg_stage < 0:
				_region_start()
			while _rg_stage >= 0:
				_region_step()
		if _regions.is_empty():
			return
	_layout()
	var shown: bool = false
	for k: int in _ct:
		_ca[k] = _ct[k]
		shown = shown or float(_ct[k]) > 0.0
	for k2: int in _xt:
		_xa[k2] = _xt[k2]
	_ma = _mt
	queue_redraw()
	if shown and not _relayout:
		_boot = false





func _blocked() -> Array:
	var out: Array = []
	var main: Node = gw.get_parent()
	var hud: Variant = main.get("hud") if main != null else null
	if not (hud is Object) or not is_instance_valid(hud):
		return out
	var h: Object = hud
	if h.has_method("blocked_rects"):
		for r: Variant in (h.call("blocked_rects") as Array):
			if r is Rect2:
				out.append(r)
		return out
	for nm: String in ["plan_panel", "war_banner"]:
		var c: Variant = h.get(nm)
		if c is Control and (c as Control).is_visible_in_tree():
			out.append((c as Control).get_global_rect().grow(2.0))
	return out




static func _off_safe(r: Rect2, scr: Rect2, csafe: Rect2) -> bool:
	return scr.intersects(r) and not csafe.encloses(r)




static func _fit_dx(r: Rect2, cx: float, scr: Rect2, csafe: Rect2) -> float:
	if not scr.intersects(r) or r.size.x > csafe.size.x or cx < csafe.position.x or cx > csafe.end.x:
		return 0.0
	var dx: float = 0.0
	if r.end.x > csafe.end.x:
		dx = csafe.end.x - r.end.x
	elif r.position.x < csafe.position.x:
		dx = csafe.position.x - r.position.x
	return dx if absf(dx) <= r.size.x * 0.6 else 0.0




func _region_tick(delta: float) -> void :
	_rg_t += delta
	if _rg_stage < 0:
		if (_rg_dirty and _rg_t >= REGION_DT) or _rg_t >= REGION_IDLE:
			_region_start()
		return
	var t0: int = Time.get_ticks_usec()
	_region_step()
	stats_region_us = maxi(stats_region_us, Time.get_ticks_usec() - t0)


func _region_start() -> void :
	var d: WorldData = gw.data
	_rg_s = maxi(1, ceili(float(maxi(d.w, d.h)) / float(REGION_GRID)))
	_rg_w = maxi(1, d.w / _rg_s)
	_rg_h = maxi(1, d.h / _rg_s)
	var n: int = _rg_w * _rg_h
	if _rg_g.size() != n:
		_rg_g.resize(n)
		_rg_l.resize(n)
		_rg_d.resize(n)
		_run_ll.resize(n)
		_run_lr.resize(n)
		_run_ol.resize(n)
		_run_or.resize(n)
	_rg_stage = 0
	_rg_y = 0
	_rg_dirty = false
	_rg_t = 0.0
	_acc = {}




func _region_step() -> void :
	var d: WorldData = gw.data
	if d.owners.size() != d.w * d.h or d.biome.size() != d.w * d.h:
		_rg_stage = -1
		return
	var W: int = _rg_w
	var H: int = _rg_h
	var g: PackedByteArray = _rg_g
	var l: PackedByteArray = _rg_l
	var D: PackedInt32Array = _rg_d
	match _rg_stage:
		0:
			var o: PackedByteArray = d.owners
			var bio: PackedByteArray = d.biome
			var s: int = _rg_s
			var half: int = s / 2
			var y1: int = mini(_rg_y + ROWS_PER_STEP, H)
			for y in range(_rg_y, y1):
				var srow: int = mini(y * s + half, d.h - 1) * d.w
				var row: int = y * W
				for x in W:
					var si: int = srow + mini(x * s + half, d.w - 1)
					var v: int = o[si]
					g[row + x] = v
					l[row + x] = v if bio[si] > Biome.COAST else 0
			_rg_y = y1
			if _rg_y >= H:
				_rg_stage = 1
				_rg_y = 0
		1:
			var y1: int = mini(_rg_y + ROWS_PER_STEP, H)
			for y in range(_rg_y, y1):
				var row: int = y * W
				for x in W:
					var i: int = row + x
					var v: int = l[i]
					if v == 0 or x == 0 or y == 0 or x == W - 1 or y == H - 1\
					or l[i - 1] != v or l[i + 1] != v or l[i - W] != v or l[i + W] != v:
						D[i] = 0
						continue
					D[i] = mini(mini(D[i - 1] + 3, D[i - W] + 3), mini(D[i - W - 1] + 4, D[i - W + 1] + 4))
			_rg_y = y1
			if _rg_y >= H:
				_rg_stage = 2
				_rg_y = H - 1
		2:
			var y0: int = maxi(_rg_y - ROWS_PER_STEP, -1)
			var y: int = _rg_y
			while y > y0:
				var row: int = y * W
				var x: int = W - 1
				while x >= 0:
					var i: int = row + x
					if D[i] != 0:
						D[i] = mini(D[i], mini(mini(D[i + 1] + 3, D[i + W] + 3), mini(D[i + W + 1] + 4, D[i + W - 1] + 4)))
					x -= 1
				y -= 1
			_rg_y = y0
			if _rg_y < 0:
				_rg_stage = 3
				_rg_y = 0
		3:
			var ll: PackedInt32Array = _run_ll
			var lr: PackedInt32Array = _run_lr
			var ol: PackedInt32Array = _run_ol
			var orr: PackedInt32Array = _run_or
			var y1: int = mini(_rg_y + ROWS_PER_STEP, H)
			for y in range(_rg_y, y1):
				var row: int = y * W
				var a: int = 0
				var b: int = 0
				ll[row] = 0
				ol[row] = 0
				for x in range(1, W):
					var i: int = row + x
					a = a + 1 if l[i] != 0 and l[i] == l[i - 1] else 0
					b = b + 1 if g[i] != 0 and g[i] == g[i - 1] else 0
					ll[i] = a
					ol[i] = b
				a = 0
				b = 0
				lr[row + W - 1] = 0
				orr[row + W - 1] = 0
				var x2: int = W - 2
				while x2 >= 0:
					var i2: int = row + x2
					a = a + 1 if l[i2] != 0 and l[i2] == l[i2 + 1] else 0
					b = b + 1 if g[i2] != 0 and g[i2] == g[i2 + 1] else 0
					lr[i2] = a
					orr[i2] = b
					x2 -= 1
			_rg_y = y1
			if _rg_y >= H:
				_rg_stage = 4
				_rg_y = 0
		4:
			var y1: int = mini(_rg_y + ROWS_PER_STEP, H)
			var last: int = -1
			var ent: Array = []
			for y in range(_rg_y, y1):
				var row: int = y * W
				for x in W:
					var i: int = row + x
					var v: int = g[i]
					if v == 0:
						continue
					if v != last:
						last = v
						if not _acc.has(v):
							_acc[v] = [[], [], 0.0, 0.0]
						ent = _acc[v]
					(ent[1] as Array).append(i)
					if l[i] != 0:
						(ent[0] as Array).append(i)
						ent[2] = float(ent[2]) + float(x)
						ent[3] = float(ent[3]) + float(y)
			_rg_y = y1
			if _rg_y >= H:
				_rg_stage = 5
		5:
			_region_finish()
			_rg_stage = -1
			stats_passes += 1
			_lay_key = Vector3.INF


func _region_finish() -> void :
	var W: int = _rg_w
	var D: PackedInt32Array = _rg_d
	var out: Dictionary = {}
	for c: Country in gw.countries:
		if c.eliminated or not _acc.has(c.id):
			continue
		var ent: Array = _acc[c.id]
		var land: = PackedInt32Array(ent[0] as Array)
		var own: = PackedInt32Array(ent[1] as Array)
		var src: PackedInt32Array = land if not land.is_empty() else own
		var cx: float = 0.0
		var cy: float = 0.0
		if not land.is_empty():
			cx = float(ent[2]) / float(land.size())
			cy = float(ent[3]) / float(land.size())
		else:
			for i in own:
				cx += float(i % W)
				cy += float(i / W)
			cx /= float(own.size())
			cy /= float(own.size())
		var best: float = -1000000000.0
		var bi: int = -1
		for i2 in src:
			var dc: float = Vector2(float(i2 % W) - cx, float(i2 / W) - cy).length()
			var sc: float = float(D[i2]) / 3.0 - 0.25 * dc
			if sc > best:
				best = sc
				bi = i2
		var x0: int = W
		var y0: int = BIG
		var x1: int = 0
		var y1: int = 0
		for i3 in own:
			x0 = mini(x0, i3 % W)
			x1 = maxi(x1, i3 % W)
			y0 = mini(y0, i3 / W)
			y1 = maxi(y1, i3 / W)
		var s: float = float(_rg_s * GameWorld.CELL)
		out[c.id] = {"pole": Vector2i(bi % W, bi / W), "n": own.size() * _rg_s * _rg_s, "land": land, "own": own, 
			"bb": Rect2(float(x0) * s, float(y0) * s, float(x1 - x0 + 1) * s, float(y1 - y0 + 1) * s)}
	_regions = out
	_acc = {}
	_fit_cache = {}
	_cons_cache = {}

	if gw.vision != null and gw.vision.active():
		for city: City in gw.cities:
			if city.country_id > 0 and not _seen.has(city.country_id) and gw.vision.sees(Vector2(city.center * GameWorld.CELL)):
				_seen[city.country_id] = true



func _cell_world(i: int) -> Vector2:
	var s: float = float(_rg_s)
	return Vector2((float(i % _rg_w) + 0.5) * s, (float(i / _rg_w) + 0.5) * s) * GameWorld.CELL







func _search(id: int, nl: int, nr: int, nu: int, nd: int, land: bool, cons: bool, rect: Rect2, safe: Rect2, placed: Array) -> int:
	var t0: int = Time.get_ticks_usec()
	stats_searches += 1
	var reg: Dictionary = _regions[id]
	var cells: PackedInt32Array = reg["land"] if land else reg["own"]
	var G: PackedByteArray = _rg_l if land else _rg_g
	var RL: PackedInt32Array = _run_ll if land else _run_ol
	var RR: PackedInt32Array = _run_lr if land else _run_or
	var D: PackedInt32Array = _rg_d
	var W: int = _rg_w
	var H: int = _rg_h
	var pole: Vector2i = reg["pole"]
	var m3: int = 3 * mini(mini(nl, nr), mini(nu, nd))
	var vmax: int = maxi(nu, nd)
	var cam: MapCamera = gw.camera
	var best_sc: float = -1000000000.0
	var best: int = -1

	var wx0: int = 0
	var wy0: int = 0
	var wx1: int = W - 1
	var wy1: int = H - 1
	if cons:
		var cw: float = float(_rg_s * GameWorld.CELL)
		var lo: Vector2 = cam.screen_to_world(safe.position - rect.position) / cw
		var hi: Vector2 = cam.screen_to_world(safe.end - rect.end) / cw
		wx0 = maxi(0, floori(lo.x - 0.5))
		wy0 = maxi(0, floori(lo.y - 0.5))
		wx1 = mini(W - 1, ceili(hi.x - 0.5))
		wy1 = mini(H - 1, ceili(hi.y - 0.5))
		if wx1 < wx0 or wy1 < wy0:
			stats_search_us += Time.get_ticks_usec() - t0
			return -1
	for i in cells:
		if land and D[i] < m3:
			continue
		var x: int = i % W
		var y: int = i / W
		if x < wx0 or x > wx1 or y < wy0 or y > wy1 or y - nu < 0 or y + nd >= H:
			continue
		var slack: int = BIG
		var ok: bool = true
		for yy in range(y - nu, y + nd + 1):
			var j: int = yy * W + x
			if G[j] != id:
				ok = false
				break
			var sl: int = mini(RL[j] - nl, RR[j] - nr)
			if sl < 0:
				ok = false
				break
			slack = mini(slack, sl)
		if not ok:
			continue

		var sc: float = minf(float(slack), 2.0) * 0.5 - 0.3 * Vector2(x - pole.x, y - pole.y).length()
		if land:
			sc += minf(float(D[i]) / 3.0 - float(vmax), 2.0) * 0.5
		if sc <= best_sc:
			continue
		if cons:
			var r: = Rect2(cam.world_to_screen(_cell_world(i)) + rect.position, rect.size)
			if not safe.encloses(r) or _hits_any(r.grow(3.0), placed):
				continue
		best_sc = sc
		best = i
	stats_search_us += Time.get_ticks_usec() - t0
	return best




func _font_title(spacing: int) -> Font:
	if not _fv.has(spacing):
		UiKit.ensure()
		var base: Font = UiKit.f_title if UiKit.f_title != null else ThemeDB.fallback_font
		var fv: = FontVariation.new()
		fv.base_font = base
		fv.spacing_glyph = spacing
		_fv[spacing] = fv
	return _fv[spacing]


func _line(txt: String, font: Font, fs: int) -> TextLine:
	var key: String = "%s|%d|%d" % [txt, font.get_instance_id(), fs]
	if _lines.has(key):
		return _lines[key]
	if _lines.size() > 600:
		_lines.clear()
	var tl: = TextLine.new()
	tl.add_string(txt, font, fs)
	_lines[key] = tl
	return tl


func _icon(nm: String) -> Texture2D:
	if not _tex.has(nm):
		_tex[nm] = UiKit.tex(nm) if UiKit.has(nm) else null
	return _tex[nm]


static func _overlap(r: Rect2, rects: Array) -> float:
	var s: float = 0.0
	for o: Rect2 in rects:
		if r.intersects(o):
			s += r.intersection(o).get_area()
	return s


static func _hits_any(r: Rect2, rects: Array) -> bool:
	for o: Rect2 in rects:
		if r.intersects(o):
			return true
	return false



func _layout() -> void :
	var t0: int = Time.get_ticks_usec()
	var cam: MapCamera = gw.camera
	var z: float = cam.zoom.x
	_z = z
	_lay_key = Vector3(cam.position.x * z, cam.position.y * z, z)
	_lay_mode = int(gw.map_mode)
	_lay_t = 0.0
	_relayout = false
	UiKit.ensure()
	var vs: Vector2 = cam.view_size()
	var wide: Rect2 = Rect2(Vector2.ZERO, vs).grow(maxf(vs.x, vs.y) * 0.35)
	var political: bool = _lay_mode == GameWorld.MapMode.POLITICAL
	var cn_a: float = 1.0 if political else 1.0 - smoothstep(CN_FULL, CN_GONE, z)
	if _lay_mode == GameWorld.MapMode.ALLIANCES:
		cn_a *= 0.55
	var pins: Array = _pin_rects(z, wide)
	_vis_mask = _visible_mask()
	_blk = _blocked()
	var placed_c: Array = _country_layout(cam, z, vs, cn_a)
	_name_rects(z)

	var cities_on: Array = []
	var placed: Array = []
	if cn_a > 0.3:
		placed.append_array(placed_c)
	placed.append_array(_blk)
	placed.append_array(_marker_rects(z, wide))


	var scr: = Rect2(Vector2.ZERO, vs)
	var ctop: float = cam.margin_top_px + SAFE_PAD
	var csafe: = Rect2(SAFE_PAD, ctop, maxf(0.0, vs.x - SAFE_RIGHT - SAFE_PAD * 2.0), maxf(0.0, vs.y - ctop - cam.margin_bottom_px - SAFE_PAD))
	var ranked: Array = []
	var pid: int = gw.player.id if gw.player != null else -1
	_mt = 1.0 - smoothstep(MARK_FADE.x, MARK_FADE.y, z)
	_has_unpowered = false
	var sk: float = cam.strat_k()
	for city: City in gw.cities:
		if city.country_id <= 0:
			_xt[city.id] = 0.0
			continue
		var cp: Vector2 = cam.world_to_screen(Vector2(city.center * GameWorld.CELL))
		var fade: Array = CITY_FADE[clampi(city.kind, 0, 2)]
		var a: float = smoothstep(float(fade[0]), float(fade[1]), z)
		if sk > 0.0 and city.kind != City.Kind.VILLAGE:
			a = maxf(a, sk)
		var c2: Country = gw.country_by_id(city.country_id)
		if a <= 0.0 or not wide.has_point(cp) or not (knows(c2) or gw.vision == null or gw.vision.sees(Vector2(city.center * GameWorld.CELL))):
			_xt[city.id] = 0.0
			if _mt > 0.0 and wide.has_point(cp) and (knows(c2) or gw.vision == null or gw.vision.sees(Vector2(city.center * GameWorld.CELL))):
				cities_on.append(city)
			continue
		var pr: int = city.kind * 10 + (0 if city.country_id == pid else 5)
		ranked.append([pr, - city.buildings, city.id, city, a])
		cities_on.append(city)
	ranked.sort()
	_xlabels = []
	var font: Font = UiKit.f_black if UiKit.f_black != null else ThemeDB.fallback_font
	var n_shown: int = 0
	for e: Array in ranked:
		var city2: City = e[3]
		var cap: bool = city2.kind == City.Kind.CAPITAL
		var fs: int = _city_fs(city2)
		var tl: TextLine = _line(Loc.name(city2.name), font, fs)
		var ts: Vector2 = tl.get_size()
		var lead: float = 0.0
		if cap:
			lead = 13.0 + 9.0 * FLAG_SC + 3.0
		else:
			lead = 8.0
		var w: float = lead + ts.x
		var cp2: Vector2 = cam.world_to_screen(Vector2(city2.center * GameWorld.CELL))
		var rz: float = float(city2.radius) * GameWorld.CELL * z * 0.25

		var off_y: float = - rz - 18.0
		var r: = Rect2(cp2 + Vector2( - w * 0.5, off_y), Vector2(w, ts.y)).grow(1.0)
		var dx: float = _fit_dx(r, cp2.x, scr, csafe)
		r.position.x += dx
		var show: bool = n_shown < (STRAT_MAX_CITY if sk > 0.0 else MAX_CITY)
		if show and (_hits_any(r, placed) or _hits_any(r, pins) or _off_safe(r, scr, csafe)):
			var r2: = Rect2(cp2 + Vector2( - w * 0.5, rz + 6.0), Vector2(w, ts.y)).grow(1.0)
			var dx2: float = _fit_dx(r2, cp2.x, scr, csafe)
			r2.position.x += dx2
			if not _hits_any(r2, placed) and not _hits_any(r2, pins) and not _off_safe(r2, scr, csafe):
				off_y = rz + 6.0
				r = r2
				dx = dx2
			elif not (cap and not _hits_any(r, placed) and not _off_safe(r, scr, csafe)):
				show = false
		_xt[city2.id] = float(e[4]) if show else 0.0
		if show:
			placed.append(r)
			n_shown += 1
		if show or float(_xa.get(city2.id, 0.0)) > 0.01:
			_xlabels.append({"city": city2, "fs": fs, "y": off_y, "w": w, "lead": lead, "ts": ts, "dx": dx})
			if not city2.powered:
				_has_unpowered = true
	stats_labels = _clabels.size() + n_shown
	set_meta("far_cities", cities_on)
	stats_layout_us = Time.get_ticks_usec() - t0


func _city_fs(city: City) -> int:
	match city.kind:
		City.Kind.CAPITAL:
			return 13
		City.Kind.TOWN:
			return 11 if city.buildings >= 60 or city.radius >= 16 else 10
	return 9



func _pin_rects(z: float, wide: Rect2) -> Array:
	var out: Array = []
	if gw.econ == null:
		return out
	var ps: float = clampf(1.0 / z, 1.0, 4.0) * z
	for dp: Dictionary in gw.econ.deposits:
		if int(dp.get("left", 1)) <= 0:
			continue
		if dp.get("mine") != null and z >= 1.0:
			continue
		var sp: Vector2 = gw.camera.world_to_screen(Vector2(dp["cell"] as Vector2i) * GameWorld.CELL + Vector2(2, -4))
		if wide.has_point(sp):
			out.append(Rect2(sp - Vector2(6, 14) * ps, Vector2(12, 16) * ps))
	return out



func _marker_rects(z: float, wide: Rect2) -> Array:
	var out: Array = []
	if gw.mil == null or gw.player == null or not gw.show_own_icons or z >= MapIcons.FADE_TO:
		return out
	var pid: int = gw.player.id
	for f: Facility in gw.mil.facilities:
		if f.country_id != pid or Military.is_field_work(f.kind) or Military.is_module(f.kind):
			continue
		var tip: Vector2 = f.mpos if f.moving else f.center_px()
		if z >= 0.5 and f.main_obj >= 0:
			tip.y = minf(tip.y, gw.obj_origin(f.main_obj).y + 3.0)
		var sp: Vector2 = gw.camera.world_to_screen(tip)
		if wide.has_point(sp):
			out.append(Rect2(sp - Vector2(10, 22), Vector2(20, 22)))
	return out







func _visible_mask() -> int:
	if _regions.is_empty() or _rg_g.size() != _rg_w * _rg_h:
		return 0
	var cam: MapCamera = gw.camera
	var safe: Rect2 = _safe_rect(cam, cam.view_size())
	var cw: float = float(_rg_s * GameWorld.CELL)
	var lo: Vector2 = cam.screen_to_world(safe.position) / cw
	var hi: Vector2 = cam.screen_to_world(safe.end) / cw
	var x0: int = maxi(0, ceili(lo.x - 0.5))
	var y0: int = maxi(0, ceili(lo.y - 0.5))
	var x1: int = mini(_rg_w - 1, floori(hi.x - 0.5))
	var y1: int = mini(_rg_h - 1, floori(hi.y - 0.5))
	if x1 < x0 or y1 < y0:
		return 0
	var g: PackedByteArray = _rg_g
	var W: int = _rg_w
	var step: int = maxi(1, int(14.0 / (cw * cam.zoom.x)))
	var mask: int = 0
	for y in range(y0, y1 + 1):
		var row: int = y * W
		var edge_row: bool = y - y0 < 3 or y1 - y < 3
		if edge_row or (y - y0) % step == 0:
			var xs: int = 1 if edge_row else step
			var x: int = x0
			while x <= x1:
				var v: int = g[row + x]
				if v > 0 and v < 63:
					mask |= 1 << v
				x += xs
		if not edge_row:
			for x2: int in [x0, x0 + 1, x0 + 2, x1 - 2, x1 - 1, x1]:
				if x2 >= x0 and x2 <= x1:
					var v2: int = g[row + x2]
					if v2 > 0 and v2 < 63:
						mask |= 1 << v2
	return mask




func _safe_rect(cam: MapCamera, vs: Vector2) -> Rect2:
	var top: float = cam.margin_top_px + SAFE_TOP_EXTRA
	return Rect2(SAFE_PAD, top, maxf(0.0, vs.x - SAFE_RIGHT - SAFE_PAD * 2.0), maxf(0.0, vs.y - top - cam.margin_bottom_px - SAFE_PAD))



static func _cn_ladder(z: float) -> Array:
	var top: int = clampi(roundi(lerpf(14.0, 16.0, clampf((z - 0.25) / 0.15, 0.0, 1.0))), 14, 16)
	var out: Array = []
	for f: int in [top, top - 2, 12, CN_MIN_FS]:
		if f >= CN_MIN_FS and (out.is_empty() or f < int(out[out.size() - 1])):
			out.append(f)
	return out


static func _cn_spacing(fs: int) -> int:
	return 2 if fs >= 14 else 1






const LOC_TAG: Dictionary = {"war": "ВОЙНА", "ally": "СОЮЗ", "vassal": "ВАССАЛ", "puppet": "МАРИОНЕТКА"}


static func tag_text(tag: String) -> String:
	return Loc.t(String(LOC_TAG.get(tag, tag)))


func _cn_geom(c: Country, fs: int, tag: String) -> Dictionary:
	var tl: TextLine = _line(Loc.name(c.name).to_upper(), _font_title(_cn_spacing(fs)), fs)
	var ts: Vector2 = tl.get_size()
	var cap: float = roundf(float(fs) * CN_CAP)
	var ow: float = 5.0 if fs >= 14 else 4.0
	var tx: float = roundf( - ts.x * 0.5)
	var ty: float = roundf(cap * 0.5) - roundf(tl.get_line_ascent())
	var fw: float = 9.0 * FLAG_SC
	var fh: float = 6.0 * FLAG_SC
	var flag: = Rect2(tx - ow - 3.0 - fw, - roundf(fh * 0.5), fw, fh)
	var b: = Rect2(tx - ow, - roundf(cap * 0.5) - ow, ts.x + ow * 2.0, cap + ow * 2.0)
	b = b.merge(flag.grow(2.0))
	var stb: = Rect2()
	var st: int = StatusMark.tier(gw, c.id)
	if st > 0:
		stb = Rect2(tx + ts.x + ow + 2.0, -6.0, 12.0, 12.0)
		b = b.merge(stb.grow(1.0))
	var sk: Array = SkyLayer.coverers(gw, c.id).slice(0, 2)
	var skb: = Rect2()
	if not sk.is_empty():
		var wsk: float = 22.0 + float(sk.size()) * 17.0
		skb = Rect2(roundf( - wsk * 0.5), - roundf(cap * 0.5) - ow - 23.0, wsk, 20.0)
		b = b.merge(skb.grow(1.0))
	var chip: = Rect2()
	if tag != "":
		var t3: Vector2 = _line(tag_text(tag), _font_city(), 9).get_size()
		chip = Rect2(roundf( - t3.x * 0.5) - 4.0, roundf(cap * 0.5) + ow, roundf(t3.x) + 8.0, 11.0)
		b = b.merge(chip.grow(1.0))
	return {"fs": fs, "tag": tag, "tx": tx, "ty": ty, "ow": ow, "flag": flag, "chip": chip, "b": b, "w": ts.x, "st": st, "stb": stb, "sk": sk, "skb": skb}


func _font_city() -> Font:
	return UiKit.f_black if UiKit.f_black != null else ThemeDB.fallback_font





func _fit(id: int, geo: Dictionary, land: bool, z: float, safe: Rect2, placed: Array, t0: int) -> int:
	var ppc: float = float(_rg_s * GameWorld.CELL) * z
	var r: Rect2 = (geo["b"] as Rect2).grow(CN_MARGIN)
	var nl: int = maxi(0, ceili( - r.position.x / ppc - 0.5))
	var nr: int = maxi(0, ceili(r.end.x / ppc - 0.5))
	var nu: int = maxi(0, ceili( - r.position.y / ppc - 0.5))
	var nd: int = maxi(0, ceili(r.end.y / ppc - 0.5))
	var key: String = "%d|%d|%d|%d|%d|%d" % [id, int(land), nl, nr, nu, nd]
	var i: int = -1
	if _fit_cache.has(key):
		i = _fit_cache[key]
	else:
		if Time.get_ticks_usec() - t0 > SEARCH_BUDGET_US:
			return -2
		i = _search(id, nl, nr, nu, nd, land, false, Rect2(), safe, placed)
		_fit_cache[key] = i
	if i < 0:
		return -1
	var b: Rect2 = geo["b"]
	var sr: = Rect2(gw.camera.world_to_screen(_cell_world(i)) + b.position, b.size)
	if safe.encloses(sr) and not _hits_any(sr.grow(3.0), placed):
		return i
	var reg: Dictionary = _regions[id]
	var view: = Rect2(gw.camera.screen_to_world(safe.position), safe.size / z)
	if not view.intersects(reg["bb"] as Rect2):
		return -1
	var ck: String = "%s|%s|%s|%s" % [key, str(_lay_key), str(safe), str(placed)]
	if _cons_cache.has(ck):
		return _cons_cache[ck]
	if Time.get_ticks_usec() - t0 > SEARCH_BUDGET_US:
		return -2
	if _cons_cache.size() > 300:
		_cons_cache.clear()
	var i2: int = _search(id, nl, nr, nu, nd, land, true, b, safe, placed)
	_cons_cache[ck] = i2
	return i2



func _name_rects(z: float) -> void :
	var out: Array[Rect2] = []
	for e: Dictionary in _clabels:
		if float(_ct.get(int(e["id"]), 0.0)) <= 0.0:
			continue
		var b: Rect2 = e["b"]
		out.append(Rect2((e["p"] as Vector2) + b.position / z, b.size / z).grow(2.0 / z))
	if out != name_rects:
		name_rects = out
		name_ver += 1




func _country_layout(cam: MapCamera, z: float, vs: Vector2, cn_a: float) -> Array:
	var safe: Rect2 = _safe_rect(cam, vs)
	var ladder: Array = _cn_ladder(z)
	var placed_c: Array = _blk.duplicate()
	var pid: int = gw.player.id if gw.player != null else -1


	var sig: String = "%s|%s|%d|%.3f|%s" % [str(_lay_key), str(safe), stats_passes, cn_a, str(_blk)]
	for c0: Country in gw.countries:
		sig += "%d%d%d" % [int(_contacted(c0)), int(pid > 0 and gw.diplo != null and gw.diplo.at_war(pid, c0.id)), int(pid > 0 and gw.diplo != null and gw.diplo.allied(pid, c0.id))]
		sig += gw.diplo.subject_kind(c0.id) if gw.diplo != null and gw.diplo.has_method("subject_kind") else ""
		sig += "s%d" % StatusMark.tier(gw, c0.id)
		sig += "k%s" % str(SkyLayer.coverers(gw, c0.id))
	if sig == _cn_sig:
		for e0: Dictionary in _clabels:
			if float(_ct.get(int(e0["id"]), 0.0)) > 0.0:
				var b0: Rect2 = e0["b"]
				placed_c.append(Rect2(cam.world_to_screen(e0["p"] as Vector2) + b0.position, b0.size))
		return placed_c
	_cn_sig = sig
	_clabels = []
	_hits = []
	var order: Array = []
	for c: Country in gw.countries:
		if c.eliminated or not _regions.has(c.id):
			_cn_hide(c.id)
			continue
		var pr: int = 2
		if c.id == pid:
			pr = 0
		elif pid > 0 and gw.diplo != null and gw.diplo.at_war(pid, c.id):
			pr = 1
		order.append([pr, - int(_regions[c.id]["n"]), c.id, c])
	order.sort()
	var t0: int = Time.get_ticks_usec()
	for e: Array in order:
		var c2: Country = e[3]
		if cn_a <= 0.0 or not knows(c2):
			_cn_hide(c2.id)
			continue
		var reg: Dictionary = _regions[c2.id]
		var tag: String = ""
		if c2.id != pid and pid > 0 and gw.diplo != null:
			if gw.diplo.at_war(pid, c2.id):
				tag = "war"
			elif gw.diplo.allied(pid, c2.id):
				tag = "ally"
			if tag != "war" and gw.diplo.has_method("subject_kind") and gw.diplo.subject_kind(c2.id) != "":
				tag = "vassal" if gw.diplo.subject_kind(c2.id) == "vassal" else "puppet"
		var a_c: float = cn_a * (1.0 if _contacted(c2) else 0.8)

		var prev: Dictionary = _cl_last.get(c2.id, {})
		if not prev.is_empty() and float(prev.get("z", -1.0)) == z and String(prev["tag"]) == tag and int(prev.get("st", 0)) == StatusMark.tier(gw, c2.id) and str(prev.get("sk", [])) == str(SkyLayer.coverers(gw, c2.id).slice(0, 2)) and _fb_valid(c2.id, prev, safe, placed_c):
			_cn_show(prev, a_c, placed_c)
			continue

		var start: int = ladder.size() - 1
		var room: float = sqrt(float(reg["n"])) * GameWorld.CELL * z * 1.15
		for k in ladder.size():
			if float(_cn_geom(c2, int(ladder[k]), tag)["b"].size.x) <= room:
				start = k
				break
		var geo: Dictionary = {}
		var at: int = -1
		var pending: bool = false
		for k2 in range(start, ladder.size()):
			var g2: Dictionary = _cn_geom(c2, int(ladder[k2]), tag)
			var i: int = _fit(c2.id, g2, true, z, safe, placed_c, t0)
			if i == -2:
				pending = true
				break
			if i >= 0:
				geo = g2
				at = i
				break
		var g3: Dictionary = _cn_geom(c2, int(ladder[ladder.size() - 1]), tag)
		if at < 0 and not pending:

			var i3: int = _fit(c2.id, g3, false, z, safe, placed_c, t0)
			pending = i3 == -2
			if i3 >= 0:
				geo = g3
				at = i3
		var fb: = Vector2.INF
		if at < 0 and not pending:


			fb = _fallback(c2.id, g3, safe, placed_c)
		if pending:
			_relayout = true
			_cn_sig = ""
			if _cl_last.has(c2.id) and _fb_valid(c2.id, _cl_last[c2.id], safe, placed_c):
				_cn_show(_cl_last[c2.id], a_c, placed_c)
				continue

			pending = false
			fb = _fallback(c2.id, g3, safe, placed_c)
		if at < 0 and fb != Vector2.INF:
			g3["id"] = c2.id
			g3["z"] = z
			g3["p"] = fb
			g3["fb"] = true
			_cn_show(g3, a_c, placed_c)
			continue
		if at < 0:
			_cn_hide(c2.id)
			continue
		geo["id"] = c2.id
		geo["p"] = _cell_world(at)
		geo["z"] = z
		_cn_show(geo, a_c, placed_c)
	return placed_c



func _fb_valid(id: int, e: Dictionary, safe: Rect2, placed: Array) -> bool:
	var b: Rect2 = e["b"]
	var sp: Vector2 = gw.camera.world_to_screen(e["p"] as Vector2)
	var r: = Rect2(sp + b.position, b.size)
	if not safe.encloses(r) or _hits_any(r.grow(3.0), placed):
		return false
	var cell: = Vector2i((e["p"] as Vector2) / float(GameWorld.CELL))
	return gw.data.inside(cell.x, cell.y) and gw.data.get_owner_id(cell.x, cell.y) == id





func _fallback(id: int, geo: Dictionary, safe: Rect2, placed: Array) -> Vector2:
	var ck: String = "fb|%d|%s|%s|%s|%d" % [id, str(_lay_key), str(safe), str(placed), int(geo["fs"])]
	if _cons_cache.has(ck):
		return _cons_cache[ck]
	var t0: int = Time.get_ticks_usec()
	stats_searches += 1
	var cam: MapCamera = gw.camera
	var reg: Dictionary = _regions[id]
	var D: PackedInt32Array = _rg_d
	var ctr: Vector2 = safe.get_center()
	var cand: Array = []
	for i in (reg["own"] as PackedInt32Array):
		var sp: Vector2 = cam.world_to_screen(_cell_world(i))
		if not safe.has_point(sp):
			continue
		cand.append([float(D[i]) / 3.0 - 0.01 * sp.distance_to(ctr) + (2.0 if _rg_l[i] == id else 0.0), i])
	cand.sort_custom( func(p: Array, q: Array) -> bool: return float(p[0]) > float(q[0]))
	var out: = Vector2.INF
	var b: Rect2 = geo["b"]
	var h: float = b.size.y + 4.0
	var tries: int = 0
	if b.size.x > safe.size.x or b.size.y > safe.size.y:
		cand = []
	var tried: Array = []
	for e: Array in cand:
		if out != Vector2.INF or tries >= 64:
			break
		var base: Vector2 = cam.world_to_screen(_cell_world(int(e[1])))
		var near: bool = false
		for q: Vector2 in tried:
			if q.distance_squared_to(base) < 100.0:
				near = true
				break
		if near:
			continue
		tried.append(base)
		tries += 1
		for dy: float in [0.0, - h, h]:
			var c: Vector2 = base + Vector2(0.0, dy)
			var r: = Rect2(c + b.position, b.size)
			var sh: = Vector2(clampf(r.position.x, safe.position.x, safe.end.x - r.size.x) - r.position.x, 
				clampf(r.position.y, safe.position.y, safe.end.y - r.size.y) - r.position.y)
			c += sh
			r.position += sh
			var w: Vector2 = cam.screen_to_world(c)
			var cell: = Vector2i(w / float(GameWorld.CELL))
			if dy != 0.0 and not (gw.data.inside(cell.x, cell.y) and gw.data.get_owner_id(cell.x, cell.y) == id):
				continue
			if _hits_any(r.grow(3.0), placed):
				continue
			out = w
			break
	if _cons_cache.size() > 300:
		_cons_cache.clear()
	_cons_cache[ck] = out
	dbg_fb[id] = [cand.size(), tries]
	stats_search_us += Time.get_ticks_usec() - t0
	return out


func _cn_show(geo: Dictionary, a: float, placed_c: Array) -> void :
	var id: int = geo["id"]
	var b: Rect2 = geo["b"]
	var sp: Vector2 = gw.camera.world_to_screen(geo["p"] as Vector2)
	placed_c.append(Rect2(sp + b.position, b.size))
	_clabels.append(geo)
	_cl_last[id] = geo
	_ct[id] = a
	var gy: float = maxf(0.0, (HIT_MIN_H - b.size.y) * 0.5)
	var gx: float = maxf(0.0, (HIT_MIN_W - b.size.x) * 0.5)
	_hits.append([geo["p"], b.grow_individual(gx, gy, gx, gy), id])



func _cn_hide(id: int) -> void :
	_ct[id] = 0.0
	if _cl_last.has(id) and float(_ca.get(id, 0.0)) > 0.02:
		_clabels.append(_cl_last[id])




func _draw() -> void :
	if gw == null or gw.camera == null:
		return
	var t0: int = Time.get_ticks_usec()
	var sc: = Vector2(1.0 / _z, 1.0 / _z)
	var ci: RID = get_canvas_item()



	if _ma > 0.02:
		for city: City in (get_meta("far_cities", []) as Array):
			var nm: String = "marker_capital" if city.kind == City.Kind.CAPITAL else ("marker_city" if city.kind == City.Kind.TOWN else "marker_village")
			var mt: Texture2D = _icon(nm)
			if mt == null:
				continue
			draw_set_transform(Vector2(city.center * GameWorld.CELL), 0.0, sc)
			draw_texture(mt, ( - mt.get_size() * 0.5).round(), Color(1, 1, 1, _ma))
			if not city.powered and _blink_on and not (gw.city_power != null and gw.city_power.shows(city, _z)):
				var pw: Texture2D = _icon("res_power")
				if pw != null:
					draw_texture(pw, Vector2(6, -14), Color(UiKit.RED, _ma))

	var font: Font = UiKit.f_black if UiKit.f_black != null else ThemeDB.fallback_font
	var xs: Array = []
	MapDeclutterRec.begin("city")
	MapDeclutterRec.city_lab.clear()
	for e: Dictionary in _xlabels:
		var city2: City = e["city"]
		var a: float = float(_xa.get(city2.id, 0.0))
		if a <= 0.02:
			continue
		var ts: Vector2 = e["ts"]
		var w: float = e["w"]
		var x0: float = roundf( - w * 0.5 + float(e.get("dx", 0.0)))
		var y0: float = roundf(float(e["y"]) + (1.0 - a) * 6.0)
		xs.append([city2, gw.country_by_id(city2.country_id), a, _line(Loc.name(city2.name), font, int(e["fs"])), x0, y0, y0 + roundf(ts.y * 0.5), w, float(e["lead"])])
		if a > 0.3:

			var pl: = Rect2(Vector2(x0 - 2.0, y0 - (16.0 if not city2.powered else 1.0)), Vector2(w + 6.0, ts.y + (17.0 if not city2.powered else 2.0)))
			MapDeclutterRec.city_lab.append([Vector2(city2.center * GameWorld.CELL), pl])
			if MapDeclutterRec.rec and a > 0.5:
				MapDeclutterRec.note("city", Rect2(gw.camera.world_to_screen(Vector2(city2.center * GameWorld.CELL)) + Vector2(x0, y0), Vector2(w, ts.y)))

	for x: Array in xs:
		var city3: City = x[0]
		var c3: Country = x[1]
		if c3 == null:
			continue
		var a3: float = x[2]
		draw_set_transform(Vector2(city3.center * GameWorld.CELL), 0.0, sc)
		if city3.kind == City.Kind.CAPITAL:
			draw_rect(Rect2(float(x[4]) + 13.0, float(x[6]) - 6.0, 9.0 * FLAG_SC, 6.0 * FLAG_SC).grow(1.0), Color(OUTLINE, 0.9 * a3))
		else:
			var pip: = Rect2(float(x[4]) + 1.0, float(x[6]) - 2.0, 4.0, 4.0)
			draw_rect(pip.grow(1.0), Color(OUTLINE, 0.9 * a3))
			draw_rect(pip, Color(c3.color.lightened(0.2), a3))

	var star: Texture2D = _icon("marker_capital")
	var pwr: Texture2D = _icon("res_power")
	for x: Array in xs:
		var city4: City = x[0]
		var a4: float = x[2]
		var cap: bool = city4.kind == City.Kind.CAPITAL
		if not cap and (city4.powered or not _blink_on):
			continue
		draw_set_transform(Vector2(city4.center * GameWorld.CELL), 0.0, sc)
		if cap and star != null:
			draw_texture(star, Vector2(float(x[4]), float(x[6]) - 6.0), Color(1, 1, 1, a4))
		if not city4.powered and _blink_on and pwr != null and not (gw.city_power != null and gw.city_power.shows(city4, _z)):
			draw_texture(pwr, Vector2(float(x[4]) + float(x[7]) + 3.0, float(x[5]) + 1.0), Color(UiKit.RED, a4))

	for x: Array in xs:
		var city5: City = x[0]
		var c5: Country = x[1]
		if city5.kind != City.Kind.CAPITAL or c5 == null or c5.flag_tex == null:
			continue
		draw_set_transform(Vector2(city5.center * GameWorld.CELL), 0.0, sc)
		draw_texture_rect(FlagMaker.tex_for(c5, Vector2(9.0 * FLAG_SC, 6.0 * FLAG_SC)), Rect2(float(x[4]) + 13.0, float(x[6]) - 6.0, 9.0 * FLAG_SC, 6.0 * FLAG_SC), false, Color(1, 1, 1, float(x[2])))

	for pass_i in 2:
		for x: Array in xs:
			var city6: City = x[0]
			var a6: float = x[2]
			var tl: TextLine = x[3]
			draw_set_transform(Vector2(city6.center * GameWorld.CELL), 0.0, sc)
			var tp: = Vector2(float(x[4]) + float(x[8]), float(x[5]))
			if pass_i == 0:
				tl.draw_outline(ci, tp, 4, Color(OUTLINE, 0.9 * a6))
			else:
				tl.draw(ci, tp, Color(UiKit.GOLD if city6.kind == City.Kind.CAPITAL else UiKit.TEXT, a6))

	var cs: Array = []
	for e2: Dictionary in _clabels:
		var id: int = e2["id"]
		var a2: float = float(_ca.get(id, 0.0))
		var c2: Country = gw.country_by_id(id)
		if a2 <= 0.02 or c2 == null:
			continue
		var fs: int = e2["fs"]
		cs.append([c2, a2, e2, _line(Loc.name(c2.name).to_upper(), _font_title(_cn_spacing(fs)), fs), _name_col(c2)])
	for k: Array in cs:
		var a7: float = k[1]
		var e3: Dictionary = k[2]
		draw_set_transform(e3["p"] as Vector2, 0.0, sc)
		var fr: Rect2 = e3["flag"]
		draw_rect(fr.grow(2.0), Color(OUTLINE, 0.92 * a7))
		draw_rect(fr.grow(1.0), Color(k[4] as Color, a7))
		if String(e3["tag"]) != "":
			var bx: Rect2 = e3["chip"]
			draw_rect(bx.grow(1.0), Color(OUTLINE, 0.92 * a7))
			draw_rect(bx, Color(UiKit.RED if String(e3["tag"]) == "war" else (Color("d9a630") if String(e3["tag"]) in ["vassal", "puppet"] else Color("9bc53d")), 0.95 * a7))
	for k2: Array in cs:
		var c8: Country = k2[0]
		if c8.flag_tex == null:
			continue
		draw_set_transform((k2[2] as Dictionary)["p"] as Vector2, 0.0, sc)
		var fr8: Rect2 = (k2[2] as Dictionary)["flag"]
		draw_texture_rect(FlagMaker.tex_for(c8, fr8.size), fr8, false, Color(1, 1, 1, float(k2[1])))
	for k5: Array in cs:
		var e5: Dictionary = k5[2]
		if int(e5.get("st", 0)) > 0:
			var bt: Texture2D = _icon(StatusMark.badge(int(e5["st"]), true))
			if bt != null:
				draw_set_transform(e5["p"] as Vector2, 0.0, sc)
				draw_texture_rect(bt, e5["stb"] as Rect2, false, Color(1, 1, 1, float(k5[1])))
	for k6: Array in cs:
		var e6: Dictionary = k6[2]
		var sk6: Array = e6.get("sk", [])
		if sk6.is_empty():
			continue
		var a6: float = float(k6[1])
		var rb: Rect2 = e6["skb"]
		draw_set_transform(e6["p"] as Vector2, 0.0, sc)
		draw_rect(rb.grow(1.0), Color(OUTLINE, 0.92 * a6))
		draw_rect(rb, Color(SkyLayer.col_of(gw, int(sk6[0])).darkened(0.15), a6))
		draw_rect(rb.grow(-1.0), Color(0.07, 0.1, 0.18, 0.95 * a6))
		var di: Texture2D = _icon("d331_sky_16")
		if di != null:
			draw_texture_rect(di, Rect2(rb.position + Vector2(3.0, 2.0), Vector2(16, 16)), false, Color(1, 1, 1, a6))
		var fx: float = rb.position.x + 21.0
		for cid6: Variant in sk6:
			var cc6: Country = gw.country_by_id(int(cid6))
			var fr6: = Rect2(fx, rb.position.y + 5.0, 15.0, 10.0)
			draw_rect(fr6.grow(1.0), Color(OUTLINE, a6))
			if cc6 != null and cc6.flag_tex != null:
				draw_texture_rect(FlagMaker.tex_for(cc6, fr6.size), fr6, false, Color(1, 1, 1, a6))
			elif cc6 != null:
				draw_rect(fr6, Color(cc6.color, a6))
			fx += 17.0
	for pass_j in 4:
		for k3: Array in cs:
			var c9: Country = k3[0]
			var a9: float = k3[1]
			var e4: Dictionary = k3[2]
			var tl2: TextLine = k3[3]
			draw_set_transform(e4["p"] as Vector2, 0.0, sc)
			var tp2: = Vector2(float(e4["tx"]), float(e4["ty"]))
			match pass_j:
				0:
					tl2.draw_outline(ci, tp2, int(e4["ow"]), Color(OUTLINE, 0.92 * a9))
				1:
					tl2.draw_outline(ci, tp2, 2, Color(c9.color_dark.darkened(0.3), a9))
				2:
					tl2.draw(ci, tp2, Color(k3[4] as Color, a9))
				3:
					var tag2: String = e4["tag"]
					if tag2 != "":
						var tl3: TextLine = _line(tag_text(tag2), font, 9)
						var t4: Vector2 = tl3.get_size()
						var bx2: Rect2 = e4["chip"]
						tl3.draw(ci, Vector2(bx2.position.x + 4.0, bx2.position.y + roundf((11.0 - t4.y) * 0.5)), Color(UiKit.TEXT, a9))
	draw_set_transform(Vector2.ZERO)
	stats_draw_us = Time.get_ticks_usec() - t0



func _name_col(c: Country) -> Color:
	var col: Color = c.color
	if col.get_luminance() < 0.45:
		col = col.lightened(0.45 - col.get_luminance())
	return col
