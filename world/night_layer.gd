class_name NightLayer
extends Node2D





const DAY_LEN: float = 420.0
const NIGHT_TINT: = Color(0.42, 0.47, 0.74)

var gw: GameWorld
var lights: Node2D
var factor: float = 0.0
const MODE_NIGHT_K: float = 0.4
var grade: Color = Color.WHITE
var _cells: Dictionary = {}
var _last: float = -1.0



var _area: Array = []
var _glow: Texture2D

const AREA_MIN_R: float = 16.0
const AREA_MAX_N: int = 8
const LIFT_MAX: float = 0.6
const LIFT_TINT: = Color(1.0, 0.95, 0.84)
const LIGHT_SCREEN_R: float = 0.09


func _ready() -> void :
	var m: = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = m
	lights = Node2D.new()
	lights.name = "Lights"
	var am: = CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lights.material = am
	add_child(lights)
	lights.draw.connect(_draw_lights)

	var g: = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	_glow = gt



func night_factor() -> float:
	if not GameConfig.night or gw == null:
		return 0.0
	var ph: float = fmod(gw.game_time + DAY_LEN * 0.05, DAY_LEN) / DAY_LEN

	if ph < 0.55:
		return 0.0
	if ph < 0.65:
		return smoothstep(0.55, 0.65, ph)
	if ph < 0.9:
		return 1.0
	return 1.0 - smoothstep(0.9, 1.0, ph)


func clock_text() -> String:
	if gw == null:
		return ""
	var ph: float = fmod(gw.game_time + DAY_LEN * 0.05, DAY_LEN) / DAY_LEN
	var minutes: int = int(fmod(ph * 24.0 * 60.0 + 7.0 * 60.0, 24.0 * 60.0))
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func reset() -> void :
	_cells.clear()
	_stacks.clear()
	_bwin.clear()
	_lamps.clear()
	_win.clear()


func _process(_delta: float) -> void :
	if gw == null or gw.data == null:
		return
	factor = night_factor()
	if int(gw.map_mode) != GameWorld.MapMode.NORMAL:
		factor *= MODE_NIGHT_K
	var g_prev: Color = grade
	grade = ColorGrade.tint(self)
	if factor > 0.01 or _last > 0.01 or grade != Color.WHITE or g_prev != Color.WHITE:
		_area = _area_lights(_view()) if factor > 0.01 and gw.camera != null else []
		queue_redraw()
		lights.queue_redraw()
	_last = factor


func _view() -> Rect2:
	var cam: MapCamera = gw.camera
	var half: Vector2 = cam.view_size() * 0.5 / cam.zoom.x
	return Rect2(cam.position - half - Vector2(8, 8), half * 2.0 + Vector2(16, 16))


func _draw() -> void :
	if (factor <= 0.01 and grade == Color.WHITE) or gw.camera == null:
		return
	var view: Rect2 = _view()
	var tint: Color = grade.lerp(NIGHT_TINT, factor)
	if _area.is_empty():
		draw_rect(view, tint)
		_draw_dark(view)
		return
	var b: = Rect2(_area[0][0], Vector2.ZERO)
	for l: Array in _area:
		var r: float = float(l[1])
		b = b.merge(Rect2((l[0] as Vector2) - Vector2(r, r), Vector2(r, r) * 2.0))
	b = b.intersection(view)
	if b.size.x < 1.0 or b.size.y < 1.0:
		draw_rect(view, tint)
		_draw_dark(view)
		return

	_strip(Rect2(view.position.x, view.position.y, view.size.x, b.position.y - view.position.y), tint)
	_strip(Rect2(view.position.x, b.end.y, view.size.x, view.end.y - b.end.y), tint)
	_strip(Rect2(view.position.x, b.position.y, b.position.x - view.position.x, b.size.y), tint)
	_strip(Rect2(b.end.x, b.position.y, view.end.x - b.end.x, b.size.y), tint)
	_lift_grid(b, tint)
	_draw_dark(view)


func _strip(r: Rect2, col: Color) -> void :
	if r.size.x > 0.0 and r.size.y > 0.0:
		draw_rect(r, col)




func _lift_grid(b: Rect2, tint: Color) -> void :
	var min_r: float = INF
	for l: Array in _area:
		min_r = minf(min_r, float(l[1]))
	var s: float = maxf(min_r / 3.5, 0.5)
	var nx: int = clampi(ceili(b.size.x / s), 1, 40)
	var ny: int = clampi(ceili(b.size.y / s), 1, 40)
	var pts: = PackedVector2Array()
	var cols: = PackedColorArray()
	pts.resize((nx + 1) * (ny + 1))
	cols.resize((nx + 1) * (ny + 1))
	var lit: Color = tint * LIFT_TINT
	lit.a = 1.0
	var k: int = 0
	for j in ny + 1:
		var y: float = b.position.y + b.size.y * float(j) / float(ny)
		for i in nx + 1:
			var p: = Vector2(b.position.x + b.size.x * float(i) / float(nx), y)
			var lift: float = 0.0
			for l: Array in _area:
				var rr: float = float(l[1])
				var d2: float = p.distance_squared_to(l[0]) / (rr * rr)
				if d2 < 1.0:
					var q: float = 1.0 - d2
					lift += q * q * float(l[2])
			pts[k] = p
			cols[k] = tint.lerp(LIFT_TINT, minf(lift, 1.0) * LIFT_MAX) if lift > 0.0 else tint
			k += 1
	var idx: = PackedInt32Array()
	idx.resize(nx * ny * 6)
	var n: int = 0
	for j in ny:
		for i in nx:
			var a: int = j * (nx + 1) + i
			idx[n] = a
			idx[n + 1] = a + 1
			idx[n + 2] = a + nx + 1
			idx[n + 3] = a + 1
			idx[n + 4] = a + nx + 2
			idx[n + 5] = a + nx + 1
			n += 6
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)



func _area_lights(view: Rect2) -> Array:
	var out: Array = []
	if gw.army == null or gw.army.get("fire") == null or not gw.army.fire.has_method("light_points"):
		return out
	var cam: MapCamera = gw.camera
	var cap_r: float = cam.view_size().x * LIGHT_SCREEN_R / maxf(0.05, cam.zoom.x)
	for lp: Array in gw.army.fire.light_points():
		var r: float = float(lp[1])
		if r < AREA_MIN_R:
			continue
		r = minf(r, cap_r)
		var p: Vector2 = lp[0]
		var inten: float = clampf((lp[2] as Color).a, 0.0, 1.0)
		if inten > 0.02 and view.grow(r).has_point(p):
			out.append([p, r, inten])
	if gw.vfx != null and gw.vfx.blast != null:
		for bl: Array in gw.vfx.blast.area_lights():
			var br: float = minf(float(bl[1]), cap_r)
			if float(bl[2]) > 0.02 and view.grow(br).has_point(bl[0]):
				out.append([bl[0], br, float(bl[2])])
	if out.size() > AREA_MAX_N:
		var c: Vector2 = cam.position
		out.sort_custom( func(x: Array, y: Array) -> bool: return (x[0] as Vector2).distance_squared_to(c) < (y[0] as Vector2).distance_squared_to(c))
		out.resize(AREA_MAX_N)
	return out



func _sees(p: Vector2) -> bool:
	return gw.vision == null or gw.vision.sees(p)



func _soft(p: Vector2, r: float, col: Color) -> void :
	lights.draw_texture_rect(_glow, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, col)










const WIN_WARM: = Color(1.0, 0.78, 0.4)
const WIN_COOL: = Color(0.72, 0.82, 1.0)
const LAMP_HEAD: = Color(1.0, 0.74, 0.36)
const LAMP_POOL: = Color(0.95, 0.62, 0.26)
const BEACON_RED: = Color(1.0, 0.16, 0.1)
const LAMP_STEP: int = 5
const SIG_EVERY: float = 0.8
const BC_HOME: int = 0
const BC_HOUSE: int = 1
const BC_OFFICE: int = 2
const BC_SERVICE: int = 3
const BC_IND: int = 4

var _win: Dictionary = {}
var _wimgs: Dictionary = {}
var _bwin: Dictionary = {}
var _lamps: Dictionary = {}
var _stacks: Dictionary = {}
var _bea: PackedVector2Array = PackedVector2Array()
static var cost_us: int = 0



static func lit_share(bc: int, hour: int) -> float:
	var evening: bool = hour >= 17 and hour < 23
	var late: bool = hour >= 23 or hour < 1
	var deep: bool = hour >= 1 and hour < 5
	match bc:
		BC_HOME:
			return 0.42 if evening else (0.24 if late else (0.07 if deep else 0.16))
		BC_HOUSE:
			return 0.62 if evening else (0.25 if late else (0.06 if deep else 0.2))
		BC_OFFICE:
			return 0.3 if evening else (0.1 if late else 0.04)
		BC_SERVICE:
			return 0.4
	return 0.08


static func bclass(sprite_name: String) -> int:
	var n: String = sprite_name.get_slice("/", sprite_name.get_slice_count("/") - 1)
	n = n.get_slice(":", n.get_slice_count(":") - 1)
	if n.begins_with("house_") or n.begins_with("col_shack"):
		return BC_HOUSE
	if n.begins_with("khrushchevka") or n.begins_with("panel9") or n.begins_with("tower16") or n.begins_with("stalinka") or n.begins_with("highrise"):
		return BC_HOME
	if n.begins_with("hospital") or n.begins_with("police") or n.begins_with("fire_station"):
		return BC_SERVICE
	if n.begins_with("admin") or n.begins_with("school") or n.begins_with("business") or n.begins_with("glass_tower") or n.begins_with("rail_station") or n.begins_with("kiosk"):
		return BC_OFFICE
	return BC_IND


func _hour() -> int:
	var ph: float = fmod(gw.game_time + DAY_LEN * 0.05, DAY_LEN) / DAY_LEN
	return int(fmod(ph * 24.0 + 7.0, 24.0))


func _img_of(tex: Texture2D) -> Image:
	if tex == null or tex is PlaceholderTexture2D:
		return null
	var k: int = tex.get_rid().get_id()
	if not _wimgs.has(k):
		var im: Image = tex.get_image()
		if im != null and im.is_compressed():
			im.decompress()
		_wimgs[k] = im
	return _wimgs[k]





func _sprite_windows(s: int) -> PackedVector2Array:
	if _win.has(s):
		return _win[s]
	var out: = PackedVector2Array()
	_win[s] = out
	var img: Image = _img_of(gw.spr_tex[s])
	if img == null:
		return out
	var r: Rect2i = Rect2i(gw.spr_rect[s])
	var w: int = r.size.x
	var h: int = r.size.y
	var ox: int = r.position.x
	var oy: int = r.position.y
	var ay: int = clampi(int(gw.spr_anchor[s].y), 0, h)
	var tops: Array[int] = []
	for x in w:
		for y in h:
			if img.get_pixel(ox + x, oy + y).a > 0.78:
				tops.append(y)
				break
	if tops.is_empty():
		return out
	tops.sort()
	var y0: int = tops[tops.size() / 2] + gw.spr_fd[s] * GameWorld.CELL
	var y1: int = ay
	if y1 - y0 < 2:
		return out
	var cnt: Dictionary = {}
	for y in range(y0, y1):
		for x in w:
			var p: Color = img.get_pixel(ox + x, oy + y)
			if p.a > 0.78:
				var key: int = p.to_rgba32()
				cnt[key] = int(cnt.get(key, 0)) + 1
	var mode: int = 0
	var best: int = -1
	for key: int in cnt:
		if int(cnt[key]) > best:
			best = int(cnt[key])
			mode = key
	var mc: = Color.hex(mode)
	var ml: float = mc.get_luminance()
	for y in range(y0 + 1, y1 - 1):
		for x in range(1, w - 1):
			var p: Color = img.get_pixel(ox + x, oy + y)
			if p.a <= 0.78 or img.get_pixel(ox + x - 1, oy + y).a <= 0.78 or img.get_pixel(ox + x + 1, oy + y).a <= 0.78 or img.get_pixel(ox + x, oy + y + 1).a <= 0.78:
				continue
			var l: float = p.get_luminance()
			var glassy: bool = p.b > p.r + 0.08 and p.b > p.g and absf(l - ml) > 0.07
			if glassy or (l < ml * 0.62 and l < 0.47 and l > 0.18):
				out.append(Vector2(x, y))
	if out.size() < 2 and w >= 6 and w <= 14:
		var my: int = clampi((y0 + y1) / 2, y0, y1 - 1)
		for q: Vector2 in [Vector2(w / 2 - 2, my), Vector2(w / 2 + 1, my)]:
			if img.get_pixel(ox + int(q.x), oy + int(q.y)).a > 0.78 and not out.has(q):
				out.append(q)
	return out


func _city_rect(c: City) -> Rect2i:
	var r: int = c.radius + 2
	return Rect2i(c.center - Vector2i(r, r), Vector2i(r, r) * 2 + Vector2i.ONE)



func _city_buildings(c: City) -> PackedInt32Array:
	var out: = PackedInt32Array()
	var cr: Rect2i = _city_rect(c)
	var r2: int = (c.radius + 2) * (c.radius + 2)
	for ch: ObjChunk in gw.objects.chunks_in_rect(cr):
		for id in ch.ids:
			if gw.obj_kind[id] != GameWorld.KIND_BUILDING or gw.obj_state[id] != 0:
				continue
			if id < gw.obj_hidden.size() and gw.obj_hidden[id] != 0:
				continue
			var dx: int = gw.obj_x[id] - c.center.x
			var dy: int = gw.obj_y[id] - c.center.y
			if dx * dx + dy * dy <= r2:
				out.append(id)
	out.sort()
	return out


func _sig(c: City, ids: PackedInt32Array) -> int:
	var s: int = c.radius * 7919 + ids.size()
	for id in ids:
		var a: int = gw.obj_arch[id] if id < gw.obj_arch.size() else 0
		s = Hash32.h2(s, id * 4 + a, 99)
	return s


func _spr_drawn(id: int) -> int:
	var s: int = gw.obj_spr[id]
	if id < gw.obj_arch.size() and gw.obj_arch[id] != 0 and gw.obj_arch[id] < gw.arch_tab.size():
		var atb: PackedInt32Array = gw.arch_tab[gw.obj_arch[id]]
		if s < atb.size():
			s = atb[s]
	return s



func _scan(c: City, ids: PackedInt32Array) -> Dictionary:
	var wp: = PackedVector2Array()
	var wa: = PackedVector2Array()
	var wv: = PackedInt32Array()
	var beacons: = PackedVector2Array()
	var npp: Array[Rect2i] = []
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.NUCLEAR_PLANT:
			npp.append(Rect2i(f.cell, f.size))
	var ol: ObjectsLayer = gw.objects
	_tree_grid(c, ol)
	for id in ids:
		if not npp.is_empty() and npp.any( func(q: Rect2i) -> bool: return q.has_point(Vector2i(gw.obj_x[id], gw.obj_y[id]))):
			continue
		var bw: Array = _bwin_of(id, ol)
		wa.append_array(bw[1])
		wp.append_array(bw[2])
		wv.append_array(bw[3])
		if (bw[4] as Vector2).x >= 0.0:
			beacons.append(bw[4])

	var lk: int = c.radius * 100003 + c.center.x * 31 + c.center.y
	var le: Array = _lamps.get(c.id, [])
	if le.is_empty() or int(le[0]) != lk:
		le = [lk, _scan_lamps(c, ol)]
		_lamps[c.id] = le
	_tgrid = {}
	return {"wp": wp, "wv": wv, "lamps": le[1], "beacons": beacons, "dark": _dark_mesh(wa)}




func _bwin_of(id: int, ol: ObjectsLayer) -> Array:
	var s: int = _spr_drawn(id)
	var key: int = s * 1048576 + gw.obj_x[id] * 7 + gw.obj_y[id] * 131
	var e: Array = _bwin.get(id, [])
	if not e.is_empty() and int(e[0]) == key:
		return e
	var wa: = PackedVector2Array()
	var wp: = PackedVector2Array()
	var wv: = PackedInt32Array()
	var bea: = Vector2(-1, -1)
	var nm: String = gw.spr_name[s]
	var bc: int = bclass(nm)
	var a: Vector2 = gw.spr_anchor[s]
	var org: = Vector2(gw.obj_x[id] * GameWorld.CELL - a.x, (gw.obj_y[id] + gw.spr_fd[s]) * GameWorld.CELL - a.y)
	var base: int = (gw.obj_y[id] + gw.spr_fd[s]) * GameWorld.CELL
	if nm.ends_with("tv_tower") or nm.contains("glass_tower"):
		var tops: PackedInt32Array = ol._sprite_tops(s)
		var by: int = 1 << 20
		for x in tops.size():
			if tops[x] >= 0 and tops[x] < by:
				by = tops[x]
				bea = org + Vector2(x, by)
	var ctops: Dictionary = {}
	var front: Array = _front_trees(org, s, base)
	for lp: Vector2 in _sprite_windows(s):
		var p: Vector2 = org + lp
		var px: int = int(p.x)
		if not ctops.has(px):
			ctops[px] = ol.cover_top(px, base)
		if int(ctops[px]) <= int(p.y):
			continue
		if not front.is_empty() and _tree_covers(front, p):
			continue
		wa.append(p)
		var v: int = Hash32.h2(id * 64 + int(lp.x) / 2, int(lp.y), 4231) % 1000
		if v >= 700:
			continue
		wp.append(p)
		var cool: int = (1 << 20) if Hash32.h2(id, int(lp.y), 77) % 6 == 0 else 0
		wv.append(bc * 1000 + v + cool)
	e = [key, wa, wp, wv, bea]
	_bwin[id] = e
	return e



const TREE_BUCKET: int = 32
var _tgrid: Dictionary = {}


func _tree_grid(c: City, ol: ObjectsLayer) -> void :
	_tgrid = {}
	var cr: Rect2i = _city_rect(c).grow(4)
	for ch: ObjChunk in ol.chunks_in_rect(cr):
		for t in ch.ids:
			if gw.obj_kind[t] == GameWorld.KIND_BUILDING or gw.obj_state[t] != 0:
				continue
			if t < gw.obj_hidden.size() and gw.obj_hidden[t] != 0:
				continue
			if not cr.has_point(Vector2i(gw.obj_x[t], gw.obj_y[t])):
				continue
			var ts: int = gw.obj_spr[t]
			var im: Image = _img_of(gw.spr_tex[ts])
			if im == null:
				continue
			var tr: = Rect2(gw.obj_origin(t), gw.spr_rect[ts].size)
			var e: Array = [(gw.obj_y[t] + gw.spr_fd[ts]) * GameWorld.CELL, tr, Vector2i(gw.spr_rect[ts].position), im]
			for by in range(int(tr.position.y) / TREE_BUCKET, int(tr.end.y) / TREE_BUCKET + 1):
				for bx in range(int(tr.position.x) / TREE_BUCKET, int(tr.end.x) / TREE_BUCKET + 1):
					var k: = Vector2i(bx, by)
					if not _tgrid.has(k):
						_tgrid[k] = []
					(_tgrid[k] as Array).append(e)



func _front_trees(org: Vector2, s: int, base: int) -> Array:
	var out: Array = []
	var br: = Rect2(org, gw.spr_rect[s].size)
	for by in range(int(br.position.y) / TREE_BUCKET, int(br.end.y) / TREE_BUCKET + 1):
		for bx in range(int(br.position.x) / TREE_BUCKET, int(br.end.x) / TREE_BUCKET + 1):
			for e: Array in _tgrid.get(Vector2i(bx, by), []):
				if int(e[0]) > base and (e[1] as Rect2).intersects(br) and not out.has(e):
					out.append(e)
	return out


func _tree_covers(front: Array, p: Vector2) -> bool:
	for f: Array in front:
		var tr: Rect2 = f[1]
		if tr.has_point(p):
			var q: Vector2i = (f[2] as Vector2i) + Vector2i(p - tr.position)
			if (f[3] as Image).get_pixelv(q).a > 0.5:
				return true
	return false



func _scan_lamps(c: City, ol: ObjectsLayer) -> PackedVector2Array:
	var lamps: = PackedVector2Array()
	var d: WorldData = gw.data
	var cr: Rect2i = _city_rect(c)
	var r2: int = (c.radius + 1) * (c.radius + 1)
	for y in range(cr.position.y, cr.end.y):
		for x in range(cr.position.x, cr.end.x):
			if (x - c.center.x) * (x - c.center.x) + (y - c.center.y) * (y - c.center.y) > r2:
				continue
			if not d.inside(x, y) or not d.has_flag(x, y, WorldData.F_ROAD) or d.has_flag(x, y, WorldData.F_BRIDGE):
				continue
			var n: bool = d.inside(x, y - 1) and d.has_flag(x, y - 1, WorldData.F_ROAD)
			var so: bool = d.inside(x, y + 1) and d.has_flag(x, y + 1, WorldData.F_ROAD)
			var e: bool = d.inside(x + 1, y) and d.has_flag(x + 1, y, WorldData.F_ROAD)
			var wv2: bool = d.inside(x - 1, y) and d.has_flag(x - 1, y, WorldData.F_ROAD)
			var lp: = Vector2(-1, -1)
			if (e and wv2) and not (n and so):
				var k: int = posmod(x, LAMP_STEP * 2)
				if k == 0 and not n:
					lp = Vector2(x * GameWorld.CELL + 2, y * GameWorld.CELL)
				elif k == LAMP_STEP and not so:
					lp = Vector2(x * GameWorld.CELL + 2, y * GameWorld.CELL + GameWorld.CELL)
			elif (n and so) and not (e and wv2):
				var k2: int = posmod(y, LAMP_STEP * 2)
				if k2 == 0 and not wv2:
					lp = Vector2(x * GameWorld.CELL, y * GameWorld.CELL + 2)
				elif k2 == LAMP_STEP and not e:
					lp = Vector2(x * GameWorld.CELL + GameWorld.CELL, y * GameWorld.CELL + 2)
			if lp.x >= 0.0 and ol.cover_top(int(lp.x), int(lp.y)) > int(lp.y) - 3:
				lamps.append(lp)
	return lamps



func _dark_mesh(wa: PackedVector2Array) -> ArrayMesh:
	if wa.is_empty():
		return null
	var v: = PackedVector2Array()
	var uv: = PackedVector2Array()
	var cl: = PackedColorArray()
	var ix: = PackedInt32Array()
	for p: Vector2 in wa:
		_quad(v, uv, cl, ix, Rect2(p, Vector2.ONE), Color.WHITE, false)
	if v.is_empty() or ix.is_empty():
		return null
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = cl
	arr[Mesh.ARRAY_INDEX] = ix
	var m: = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m if m.get_surface_count() > 0 else null



func _draw_dark(view: Rect2) -> void :
	if factor <= 0.01:
		return
	for bp: Vector2 in _bea:
		draw_rect(Rect2(bp.round() + Vector2(-1, -1), Vector2(2, 2)), Color(0.25, 0.08, 0.08))
	if gw.camera.zoom.x < 0.75:
		return
	var mc: Color = Color.WHITE.lerp(Color(0.42, 0.44, 0.52), factor)
	for c: City in gw.cities:
		var e: Dictionary = _cells.get(c.id, {})
		if not e.has("sc"):
			continue
		var dark_m: Mesh = (e["sc"] as Dictionary).get("dark") as Mesh
		if dark_m == null or dark_m.get_surface_count() == 0:
			continue
		var rr: float = float(c.radius + 4) * GameWorld.CELL
		if view.grow(rr).has_point(Vector2(c.center * GameWorld.CELL)):
			draw_mesh(dark_m, _glow, Transform2D.IDENTITY, mc)


func _quad(v: PackedVector2Array, uv: PackedVector2Array, cl: PackedColorArray, ix: PackedInt32Array, r: Rect2, col: Color, tex: bool) -> void :
	var b: int = v.size()
	v.append_array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	if tex:
		uv.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	else:
		uv.append_array([Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.5)])
	cl.append_array([col, col, col, col])
	ix.append_array([b, b + 1, b + 2, b, b + 2, b + 3])



func _build_mesh(sc: Dictionary, hour: int, poor: bool) -> ArrayMesh:
	var v: = PackedVector2Array()
	var uv: = PackedVector2Array()
	var cl: = PackedColorArray()
	var ix: = PackedInt32Array()
	var share: Array[int] = []
	for bc in 5:
		share.append(int(lit_share(bc, hour) * 1000.0 / (3.0 if poor else 1.0)))
	var wp: PackedVector2Array = sc["wp"]
	var wv: PackedInt32Array = sc["wv"]
	for i in wp.size():
		var code: int = wv[i]
		var cool: bool = (code & (1 << 20)) != 0
		code &= (1 << 20) - 1
		if code % 1000 >= share[code / 1000]:
			continue
		var p: Vector2 = wp[i]
		_quad(v, uv, cl, ix, Rect2(p - Vector2.ONE, Vector2(3, 3)), Color(0.42, 0.27, 0.1, 0.42), false)
		_quad(v, uv, cl, ix, Rect2(p, Vector2.ONE), WIN_COOL if cool else WIN_WARM, false)
	var lamps: PackedVector2Array = sc["lamps"]
	for i in lamps.size():
		if poor and i % 3 != 0:
			continue
		var lp: Vector2 = lamps[i]
		_quad(v, uv, cl, ix, Rect2(lp - Vector2(7, 4), Vector2(14, 9)), Color(LAMP_POOL.r, LAMP_POOL.g, LAMP_POOL.b, 0.42), true)
		_quad(v, uv, cl, ix, Rect2(lp + Vector2(0, -3), Vector2.ONE), LAMP_HEAD, false)
		_quad(v, uv, cl, ix, Rect2(lp + Vector2(0, -2), Vector2(1, 2)), Color(0.45, 0.32, 0.16, 0.5), false)
	if v.is_empty() or ix.is_empty():
		return null
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = cl
	arr[Mesh.ARRAY_INDEX] = ix
	var m: = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m if m.get_surface_count() > 0 else null




func _city_lights(c: City, budget: Array) -> Dictionary:
	var e: Dictionary = _cells.get(c.id, {})
	var now: float = float(Time.get_ticks_msec()) * 0.001
	if e.is_empty() or (now - float(e.get("chk", 0.0)) > SIG_EVERY and int(e.get("ver", -1)) != gw.objects.cover_ver):
		if int(budget[0]) > 0:
			var ids: PackedInt32Array = _city_buildings(c)
			var sg: int = _sig(c, ids)
			e["chk"] = now
			e["ver"] = gw.objects.cover_ver
			if sg != int(e.get("sig", 0)) or not e.has("sc"):
				budget[0] = int(budget[0]) - 1
				e["sig"] = sg
				e["sc"] = _scan(c, ids)
				e["key"] = -1
			_cells[c.id] = e
	if e.is_empty() or not e.has("sc"):
		return e
	var poor: bool = gw.get("naval") != null and gw.naval != null and gw.naval.is_colony(c)
	var h: int = _hour()
	var key: int = 0
	for bc in 5:
		key = key * 1009 + int(lit_share(bc, h) * 1000.0)
	key = key * 2 + (1 if poor else 0)
	if int(e.get("key", -1)) != key:
		e["key"] = key
		e["mesh"] = _build_mesh(e["sc"], h, poor)
	return e



func _beacon_on() -> bool:
	if gw.time_scale <= 0.0 or gw.time_scale > 3.0:
		return true
	return fmod(gw.game_time, 2.4) < 1.3


func _beacon(p: Vector2, a: float) -> void :
	_bea.append(p)
	lights.draw_rect(Rect2(p.round() + Vector2(-1, -1), Vector2(2, 2)), Color(BEACON_RED.r, BEACON_RED.g, BEACON_RED.b, a))
	_soft(p, 4.0, Color(0.9, 0.1, 0.05, a * 0.35))



func _stack_lights(f: Facility) -> PackedVector2Array:
	var out: = PackedVector2Array()
	if f.main_obj < 0:
		return out
	var s: int = _spr_drawn(f.main_obj)
	var tops: PackedInt32Array = gw.objects._sprite_tops(s)
	var bx: int = -1
	var by: int = 1 << 20
	for x in tops.size():
		if tops[x] >= 0 and tops[x] < by:
			by = tops[x]
			bx = x
	if bx < 0:
		return out
	var a: Vector2 = gw.spr_anchor[s]
	var org: = Vector2(gw.obj_x[f.main_obj] * GameWorld.CELL - a.x, (gw.obj_y[f.main_obj] + gw.spr_fd[s]) * GameWorld.CELL - a.y)
	out.append(org + Vector2(bx, by))
	var bx2: int = -1
	for x in tops.size():
		if absi(x - bx) >= 3 and tops[x] >= 0 and tops[x] <= by + 2 and (bx2 < 0 or tops[x] < tops[bx2]):
			bx2 = x
	if bx2 >= 0:
		out.append(org + Vector2(bx2, tops[bx2]))
	var med: Array[int] = []
	for t in tops:
		if t >= 0:
			med.append(t)
	med.sort()
	var roof: int = med[med.size() / 2]
	if roof - by > 16:
		out.append(org + Vector2(bx, by + (roof - by) / 2))
		if bx2 >= 0:
			out.append(org + Vector2(bx2, by + (roof - by) / 2))
	return out


func _draw_lights() -> void :
	if factor <= 0.01 or gw.camera == null:
		return
	var t0: int = Time.get_ticks_usec()
	_bea.clear()
	_draw_lights2()
	cost_us = Time.get_ticks_usec() - t0


func _draw_lights2() -> void :
	var view: Rect2 = _view()
	var a: float = factor
	var lamp: = Color(1.0, 0.92, 0.65, a)
	var t: float = gw.game_time



	if gw.army != null and gw.army.get("fire") != null and gw.army.fire.has_method("light_points"):
		var zm: float = maxf(0.05, gw.camera.zoom.x)
		var drawn: Array = []
		for al: Array in _area:
			var ap: Vector2 = al[0]
			var near: bool = false
			for q: Vector2 in drawn:
				if q.distance_to(ap) < float(al[1]) * 0.6:
					near = true
					break
			if not near:
				drawn.append(ap)
				_soft(ap, float(al[1]) * 0.7, Color(1.0, 0.85, 0.6, 0.1 * float(al[2]) * a))
		for lp: Array in gw.army.fire.light_points():
			var lr: float = float(lp[1])
			if lr >= AREA_MIN_R:
				continue
			var lpos: Vector2 = lp[0]
			if not _sees(lpos):
				continue
			lr = minf(lr, 14.0 / zm)
			if view.grow(lr).has_point(lpos):
				var lc: Color = lp[2]
				_soft(lpos, lr, Color(lc.r, lc.g, lc.b, minf(lc.a, 0.6) * a))
	var budget: Array = [1]
	var bon: bool = _beacon_on()
	for c: City in gw.cities:
		var cp: = Vector2(c.center * GameWorld.CELL)
		var rr: float = float(c.radius + 4) * GameWorld.CELL
		if not view.grow(rr).has_point(cp):
			continue
		if not c.powered and t > c.flicker_until:
			continue
		if not c.powered and Hash32.h2(c.id, int(Time.get_ticks_msec() * 0.003), 5) % 2 == 0:
			continue
		if gw.camera.zoom.x >= 0.75:
			var cl: Dictionary = _city_lights(c, budget)
			var lm: Mesh = cl.get("mesh") as Mesh
			if lm != null and lm.get_surface_count() > 0:
				lights.draw_mesh(lm, _glow, Transform2D.IDENTITY, Color(1, 1, 1, a))
			if bon and cl.has("sc"):
				for bp: Vector2 in (cl["sc"]["beacons"] as PackedVector2Array):
					if view.has_point(bp):
						_beacon(bp, a)
			_soft(cp, rr * 0.8, Color(0.45, 0.3, 0.12, a * 0.16))
		else:

			_soft(cp, rr * 0.9, Color(0.55, 0.38, 0.14, a * 0.4))
			_soft(cp, rr * 0.4, Color(0.9, 0.7, 0.35, a * 0.25))
	for f: Facility in gw.mil.facilities:
		if f.main_obj < 0 or not view.has_point(f.center_px()) or not gw.mil.alive(f) or (gw.vision != null and not gw.vision.fac_shown(f)):
			continue
		if Military.uses_power(f.kind) and not gw.mil.has_power(f):
			continue
		var fp: Vector2 = f.center_px()
		if bon and (f.kind == Facility.Kind.POWER_PLANT or f.kind == Facility.Kind.REFINERY):
			var sk: Array = _stacks.get(f.id, [])
			if sk.is_empty() or int(sk[0]) != f.main_obj * 4096 + _spr_drawn(f.main_obj):
				sk = [f.main_obj * 4096 + _spr_drawn(f.main_obj), _stack_lights(f)]
				_stacks[f.id] = sk
			for bp2: Vector2 in (sk[1] as PackedVector2Array):
				_beacon(bp2, a)
		if f.kind == Facility.Kind.NUCLEAR_PLANT:
			var bp: Vector2 = Nuclear.beacon_px(gw, f)
			if bon:
				_beacon(bp, a)
			_soft(fp + Vector2(0, 6), 26.0, Color(0.55, 0.62, 0.7, a * 0.22))
			for sp: Variant in Nuclear.steam_points(gw, f):
				_soft((sp as Vector2) + Vector2(0, -10), 14.0, Color(0.7, 0.74, 0.8, a * 0.18))
		lights.draw_rect(Rect2(fp + Vector2(-1, -4), Vector2(2, 1)), lamp)
		lights.draw_rect(Rect2(fp + Vector2(f.size.x * 1.5, 0), Vector2(1, 1)), lamp)
	if gw.econ != null:
		for dp: Dictionary in gw.econ.deposits:
			if String(dp.get("res", "")) != "uranium" or int(dp.get("left", 0)) <= 0:
				continue
			var up: Vector2 = Vector2(dp["cell"] as Vector2i) * GameWorld.CELL + Vector2(2, 0)
			if view.has_point(up):
				_soft(up, 10.0, Color(0.55, 1.0, 0.3, a * 0.28))
				_soft(up, 4.0, Color(0.85, 1.0, 0.55, a * 0.35))
	if gw.kpp != null and BorderPosts.active():
		gw.kpp.draw_lights(self, lights, view, a)
	for fire: Dictionary in gw.fires:
		if float(fire["until"]) <= t:
			continue
		var fp2: Vector2 = fire["p"]
		if view.has_point(fp2):
			var fl: float = 0.8 + 0.2 * sin(FxLayer.vt * 9.0 + fp2.x)
			var st: Texture2D = gw.vfx.glow.get("_tex") if gw.vfx != null and gw.vfx.glow != null else null
			if st != null:
				var hr: float = roundf(14.0 * fl)
				lights.draw_texture_rect(st, Rect2((fp2 + Vector2(0, -3) - Vector2(hr, hr)).round(), Vector2(hr, hr) * 2.0), false, Color(0.95, 0.45, 0.12, a * 0.42 * fl))
				lights.draw_texture_rect(st, Rect2((fp2 + Vector2(0, -3) - Vector2(5, 5)).round(), Vector2(10, 10)), false, Color(1.0, 0.7, 0.3, a * 0.4 * fl))
			else:
				_soft(fp2 + Vector2(0, -2), 11.0, Color(0.9, 0.4, 0.1, a * 0.35 * fl))
				_soft(fp2 + Vector2(0, -2), 4.0, Color(1.0, 0.6, 0.2, a * 0.4 * fl))
	var blink: bool = int(Time.get_ticks_msec() / 500) % 2 == 0


	for ac: Aircraft in gw.mil.air.aircraft:
		if ac.state != Aircraft.State.DEAD and view.has_point(ac.pos) and (gw.vision == null or gw.vision.shows_air(ac.country_id, ac.pos)):
			lights.draw_rect(Rect2(ac.pos.round() + Vector2(-3, 0), Vector2(1, 1)), Color(1.0, 0.2, 0.15, a))
			lights.draw_rect(Rect2(ac.pos.round() + Vector2(3, 0), Vector2(1, 1)), Color(0.2, 1.0, 0.3, a))
			if blink:
				lights.draw_rect(Rect2(ac.pos.round() + Vector2(0, 2), Vector2(1, 1)), Color(1, 1, 1, a))
	for m: Missile in gw.mil.missiles:
		var sp: Vector2 = m.screen_pos()
		if view.has_point(sp) and (gw.vision == null or gw.vision.shows_air(m.country_id, sp)):
			_soft(sp, 7.0, Color(1.0, 0.6, 0.2, a * 0.4))
	for u: Unit in gw.army.units:
		if u.alive() and u.type == Unit.Type.TANK and view.has_point(u.pos) and (gw.vision == null or gw.vision.shows(u.country_id, u.pos)):
			lights.draw_rect(Rect2(u.pos.round() + Vector2.from_angle(u.heading) * 5.0, Vector2(1, 1)), lamp)
	for tr: Array in gw.mil.air.tracers:
		var p0: Vector2 = tr[0]
		var p1: Vector2 = tr[1]
		if not _sees(p0):
			continue
		lights.draw_line(p0, p1, Color(1.0, 0.7, 0.3, a * 0.6), 1.0)
