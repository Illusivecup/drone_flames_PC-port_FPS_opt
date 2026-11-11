class_name VfxGround
extends Node2D






const APRON: Dictionary = {
	Facility.Kind.REFINERY: 2, Facility.Kind.POWER_PLANT: 2, Facility.Kind.CIV_FACTORY: 2, Facility.Kind.DRONE_FACTORY: 2, 
	Facility.Kind.MISSILE_FACTORY: 2, Facility.Kind.MINE: 2, Facility.Kind.SAWMILL: 2, Facility.Kind.OIL_RIG: 1, 
	Facility.Kind.BARRACKS: 2, Facility.Kind.FARM: 1, Facility.Kind.DRONE_PORT: 1, Facility.Kind.AIRFIELD: 1, 
	Facility.Kind.AD_MFG: 1, Facility.Kind.AD_SAM: 1, Facility.Kind.AD_PATRIOT: 1, Facility.Kind.AD_RADAR: 1, Facility.Kind.AD_EW: 1, 
	Facility.Kind.SOLAR: 1, Facility.Kind.RAIL_STATION: 1, 
}
const PATH_MAX: int = 16
const MAX_NODES: int = 64

class GroundChunk:
	extends Node2D
	var layer: VfxGround
	var idx: int = 0
	var sig: int = 0
	var seen_t: float = 0.0

	func _draw() -> void :
		layer.draw_chunk(self)


class MarksNode:
	extends Node2D
	var layer: VfxGround

	func _draw() -> void :
		layer.draw_marks(self)


var vfx: Vfx
var aprons: Node2D
var marks_node: MarksNode
var _nodes: Dictionary = {}
var _fac_of: Dictionary = {}
var _fac_n: int = -1
var _fac_t: float = 0.0
var _paths: Dictionary = {}
var _cursor: int = 0
var _marks_key: int = -1
var _marks_t: float = 0.0
var _px: Rect2 = Rect2()
var _dirt: Array[Rect2] = []
var _real_t: float = 0.0
var _chk_t: float = 0.0


func _ready() -> void :
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	aprons = Node2D.new()
	aprons.name = "Aprons"
	add_child(aprons)
	marks_node = MarksNode.new()
	marks_node.name = "Marks"
	marks_node.layer = self
	add_child(marks_node)
	if vfx.has("px"):
		_px = vfx.atlas.rect("px")
	for k in 3:
		if vfx.has("dirt_%d" % k):
			_dirt.append(vfx.atlas.rect("dirt_%d" % k))


func reset() -> void :
	for n: Node in _nodes.values():
		n.queue_free()
	_nodes.clear()
	_fac_of.clear()
	_fac_n = -1
	_paths.clear()
	_marks_key = -1


func _process(delta: float) -> void :
	var gw: GameWorld = vfx.gw if vfx != null else null
	if gw == null or gw.camera == null or gw.objects == null or gw.objects.chunks.is_empty() or vfx.tex == null:
		return
	var us: int = Time.get_ticks_usec()
	_real_t += delta

	_fac_t -= delta
	if gw.mil.facilities.size() != _fac_n or _fac_t <= 0.0:
		_fac_t = 3.0
		_fac_n = gw.mil.facilities.size()
		_fac_of.clear()
		for f: Facility in gw.mil.facilities:
			if f.main_obj >= 0 and APRON.has(f.kind):
				_fac_of[f.main_obj] = f


	var cam: MapCamera = gw.camera
	aprons.visible = cam.zoom.x >= 0.45
	if aprons.visible:
		var half: Vector2 = cam.view_size() * 0.5 / cam.zoom.x
		var gs: int = gw.objects.chunk_cells * 2
		var tl: = Vector2i(((cam.position - half) / 4.0 - Vector2(4, 4)) / float(gs))
		var br: = Vector2i(((cam.position + half) / 4.0 + Vector2(4, 4)) / float(gs))
		var ng: Vector2i = Vector2i((gw.objects.cw + 1) / 2, (gw.objects.ch + 1) / 2)
		var vis: Array[int] = []
		for gy in range(maxi(0, tl.y), mini(ng.y - 1, br.y) + 1):
			for gx in range(maxi(0, tl.x), mini(ng.x - 1, br.x) + 1):
				vis.append(gy * 4096 + gx)
		var made: int = 0
		for key: int in vis:
			var gc: GroundChunk = _nodes.get(key)
			if gc == null:
				if made >= 2:
					continue
				made += 1
				gc = GroundChunk.new()
				gc.layer = self
				gc.idx = key
				gc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				aprons.add_child(gc)
				_nodes[key] = gc
				gc.sig = _gsig(key)
				gc.queue_redraw()
			gc.seen_t = _real_t
		_chk_t -= delta
		if not vis.is_empty() and _chk_t <= 0.0:
			_chk_t = 0.2
			_cursor = (_cursor + 1) % vis.size()
			var gc2: GroundChunk = _nodes.get(vis[_cursor])
			if gc2 != null:
				var sg: int = _gsig(gc2.idx)
				if sg != gc2.sig:
					gc2.sig = sg
					gc2.queue_redraw()
	if _nodes.size() > MAX_NODES:
		var oldest: int = -1
		var ot: float = INF
		for key: int in _nodes:
			var g: GroundChunk = _nodes[key]
			if g.seen_t < ot:
				ot = g.seen_t
				oldest = key
		if oldest >= 0:
			(_nodes[oldest] as Node).queue_free()
			_nodes.erase(oldest)

	_marks_t -= delta
	if _marks_t <= 0.0 or vfx.marks_ver != _marks_key:
		_marks_t = 2.0
		var key: int = vfx.marks_ver * 7919
		for m: Array in vfx.marks:
			key += int(vfx.mark_alpha(m) * 4.0)
		for sc: Array in vfx.scars:
			key += vfx.scar_stage(sc) * 3
		if key != _marks_key:
			_marks_key = key
			marks_node.queue_redraw()
	Vfx.cost("ground", Time.get_ticks_usec() - us)



func _group(key: int) -> Array[ObjChunk]:
	var ol: ObjectsLayer = vfx.gw.objects
	var out: Array[ObjChunk] = []
	var gx: int = (key % 4096) * 2
	var gy: int = (key / 4096) * 2
	for y in range(gy, mini(gy + 2, ol.ch)):
		for x in range(gx, mini(gx + 2, ol.cw)):
			out.append(ol.chunks[y * ol.cw + x])
	return out


func _gsig(key: int) -> int:
	var s: int = 17
	for oc: ObjChunk in _group(key):
		s = (s * 131 + _sig(oc)) & 2147483647
	return s


func _sig(oc: ObjChunk) -> int:
	var gw: GameWorld = vfx.gw
	var s: int = oc.ids.size()
	var hid: bool = gw.obj_hidden.size() >= gw.obj_state.size()
	for id in oc.ids:
		s = (s * 31 + gw.obj_state[id] + (gw.obj_hidden[id] * 3 if hid else 0) + id) & 2147483647
	return s


func _rect(ci: CanvasItem, r: Rect2, c: Color) -> void :
	ci.draw_texture_rect_region(vfx.tex, r, _px, c)


func draw_chunk(ck: GroundChunk) -> void :


	if vfx == null or not is_instance_valid(vfx):
		return
	var gw: GameWorld = vfx.gw
	if gw == null or not is_instance_valid(gw) or gw.objects == null or not is_instance_valid(gw.objects) or gw.objects.chunks.is_empty():
		return
	for oc: ObjChunk in _group(ck.idx):
		_draw_oc(ck, oc)


func _draw_oc(ck: GroundChunk, oc: ObjChunk) -> void :
	var gw: GameWorld = vfx.gw
	var hid: bool = gw.obj_hidden.size() >= gw.obj_state.size()

	for id in oc.ids:
		if gw.obj_state[id] == 2 or (hid and gw.obj_hidden[id] != 0):
			continue
		var fv: Variant = _fac_of.get(id)
		if fv == null or not is_instance_valid(fv):
			continue
		var f: Facility = fv
		if f.main_obj == id and APRON.has(f.kind):
			_apron(ck, f, gw.object_rect(id))

	var shade: = Color(0.0, 0.03, 0.02, 0.2)
	var shade2: = Color(0.0, 0.03, 0.02, 0.11)
	for id in oc.ids:
		var st: int = gw.obj_state[id]
		if gw.obj_kind[id] != GameWorld.KIND_BUILDING or st == 2 or (hid and gw.obj_hidden[id] != 0):
			continue
		var r: Rect2i = gw.object_rect(id)
		var x0: float = r.position.x * 4.0
		var y1: float = r.end.y * 4.0
		var w: float = r.size.x * 4.0
		if st == 1:

			var sc: String = "scorch_mb" if r.size.x * r.size.y <= 16 else "scorch_la"
			if vfx.has(sc):
				var info: Dictionary = vfx.atlas.info(sc)
				var c: = Vector2(x0 + w * 0.5, (r.position.y + r.size.y * 0.5) * 4.0)
				ck.draw_texture_rect_region(vfx.tex, Rect2(c - Vector2(float(info["ax"]), float(info["ay"])), vfx.atlas.rect(sc).size), vfx.atlas.rect(sc), Color(1, 1, 1, 0.85))
			continue

		_rect(ck, Rect2(x0 - 1.0, y1, w + 3.0, 1.0), shade)
		_rect(ck, Rect2(x0 + 1.0, y1 + 1.0, w + 2.0, 1.0), shade2)
		_rect(ck, Rect2(x0 + w, r.position.y * 4.0 + 3.0, 2.0, r.size.y * 4.0 - 3.0), shade2)




func _apron(ck: CanvasItem, f: Facility, r: Rect2i) -> void :
	if _dirt.is_empty():
		return
	var gw: GameWorld = vfx.gw
	var d: WorldData = gw.data
	var ring: int = int(APRON.get(f.kind, 1))
	var g: Rect2i = r.grow(ring)
	for y in range(g.position.y, g.end.y):
		for x in range(g.position.x, g.end.x):
			if r.has_point(Vector2i(x, y)) or not d.inside(x, y):
				continue
			var dist: int = maxi(maxi(r.position.x - x, x - (r.end.x - 1)), maxi(r.position.y - y, y - (r.end.y - 1)))
			var p: float = 0.88 if dist <= 1 else 0.42
			if y >= r.end.y:
				p += 0.1
			var h: int = Hash32.h2(x, y, 1919)
			if float(h % 100) >= p * 100.0:
				continue
			if not _dirt_ok(d, x, y):
				continue
			_dirt_cell(ck, x, y, h, 0.95 if dist <= 1 else 0.7)
	for c: Vector2 in _path(f, r):
		var h2: int = Hash32.h2(int(c.x), int(c.y), 1920)
		if h2 % 100 < 80:
			_dirt_cell(ck, int(c.x), int(c.y), h2, 0.8)


func _dirt_ok(d: WorldData, x: int, y: int) -> bool:
	if d.has_flag(x, y, WorldData.F_ROAD | WorldData.F_OCCUPIED):
		return false
	var b: int = d.get_biome(x, y)
	return not Biome.is_water(b) and b != Biome.ROAD and b != Biome.STREET and b != Biome.SNOW


func _dirt_cell(ci: CanvasItem, x: int, y: int, h: int, a: float) -> void :
	var src: Rect2 = _dirt[h % _dirt.size()]
	var sub: = Rect2(src.position + Vector2(float((h >> 8) % 2) * 4.0, float((h >> 9) % 2) * 4.0), Vector2(4, 4))
	ci.draw_texture_rect_region(vfx.tex, Rect2(Vector2(x * 4, y * 4), Vector2(4, 4)), sub, Color(1, 1, 1, a))


func _path(f: Facility, r: Rect2i) -> PackedVector2Array:
	if _paths.has(f.id):
		return _paths[f.id]
	var d: WorldData = vfx.gw.data
	var best: = PackedVector2Array()
	var starts: Array = [[Vector2i(r.position.x + r.size.x / 2, r.end.y), Vector2i(0, 1)], 
		[Vector2i(r.position.x - 1, r.position.y + r.size.y - 1), Vector2i(-1, 0)], 
		[Vector2i(r.end.x, r.position.y + r.size.y - 1), Vector2i(1, 0)], 
		[Vector2i(r.position.x + r.size.x / 2, r.position.y - 1), Vector2i(0, -1)]]
	for s: Array in starts:
		var c: Vector2i = s[0]
		var dir: Vector2i = s[1]
		var cells: = PackedVector2Array()
		var ok: bool = false
		for k in PATH_MAX:
			if not d.inside(c.x, c.y):
				break
			if d.has_flag(c.x, c.y, WorldData.F_ROAD):
				ok = true
				break
			if not _dirt_ok(d, c.x, c.y):
				break
			cells.append(Vector2(c))
			c += dir
		if ok and (best.is_empty() or cells.size() < best.size()):
			best = cells
	_paths[f.id] = best
	return best


func draw_marks(ci: CanvasItem) -> void :
	var gw: GameWorld = vfx.gw
	if gw == null:
		return


	if _scar_tex.is_empty():
		_build_scars()
	for sc: Array in vfx.scars:
		if gw.vision == null or gw.vision.sees(sc[1]):
			_draw_scar(ci, String(sc[0]), vfx.scar_stage(sc), sc[1], 1.0)
	for m2: Array in vfx.marks:
		if m2.size() > 5 and bool(m2[5]) and bool(m2[4]):
			var a2: float = vfx.mark_alpha(m2)
			if a2 < 1.0:
				var n2: String = m2[0]
				_draw_scar(ci, "l" if n2.ends_with("_l") else ("m" if n2.ends_with("_m") else "s"), 0, m2[1], 1.0 - a2)

	for pass_i in 2:
		for m: Array in vfx.marks:
			if not bool(m[4]):
				continue
			var n: String = m[0]
			var own: bool = n.begins_with("scorch")
			if own != (pass_i == 0):
				continue
			var a: float = vfx.mark_alpha(m)
			if a <= 0.0:
				continue
			var at: SpriteAtlas = vfx.atlas if own else gw.fx_atlas_of(n)
			if not at.sprites.has(n):
				continue
			var info: Dictionary = at.info(n)
			var src: Rect2 = at.rect(n)
			ci.draw_texture_rect_region(at.texture, Rect2((Vector2(m[1]) - Vector2(float(info["ax"]), float(info["ay"]))).round(), src.size), src, Color(1, 1, 1, a * (0.85 if own else 1.0)))








static var _scar_tex: Dictionary = {}


static func _build_scars() -> void :
	var sizes: Dictionary = {"s": Vector2i(8, 8), "m": Vector2i(12, 12), "l": Vector2i(28, 18)}
	var earth_d: = Palette.c("earth_dark")
	var earth: = Palette.c("earth")
	var earth_l: = Palette.c("earth_light")
	var g_l: = Palette.c("grass_light")
	var g: = Palette.c("grass")
	var g_d: = Palette.c("grass_dark")
	var g_deep: = Palette.c("grass_deep")
	var forest: = Palette.c("forest")
	var fl_y: = Palette.c("fire_yellow")
	var fl_w: = Palette.c("snow")
	var fl_r: = Palette.c("roof_red")
	for sz: String in sizes:
		var wh: Vector2i = sizes[sz]
		var rx: float = float(wh.x) * 0.5 - 0.5
		var ry: float = float(wh.y) * 0.5 - 0.5
		for st in 3:
			var img: = Image.create(wh.x, wh.y, false, Image.FORMAT_RGBA8)
			img.fill(Color(0, 0, 0, 0))
			for y in wh.y:
				for x in wh.x:
					var dx: float = (float(x) - rx) / (rx + 0.5)
					var dy: float = (float(y) - ry) / (ry + 0.5)
					var hh: int = Hash32.h2(x + st * 97, y + sz.unicode_at(0), 3191)
					var d: float = sqrt(dx * dx + dy * dy) + float(hh % 3) * 0.02
					var o: = Color(0, 0, 0, 0)
					var upper: bool = dy < 0.0


					var rim_w: float = 0.22 if sz == "l" else 0.3

					var ang: float = atan2(dy, dx) + PI
					var seg: int = int(ang / TAU * 7.0 + float(Hash32.h2(st, sz.unicode_at(0), 3202) % 5) * 0.13)
					var hs: int = Hash32.h2(seg, st + sz.unicode_at(0) * 3, 3203)
					if d < 1.0 - rim_w:
						var wall: bool = upper and d > 0.55 - rim_w * 0.5
						if st == 0:
							o = earth_d if wall else (earth if hh % 4 != 0 else earth_d)
							if not wall and hh % 5 == 0:
								o = g_l
							elif not wall and hh % 7 == 1:
								o = g
						elif st == 1:
							o = forest if wall else (g_deep if hh % 5 != 0 else g_d)
						else:

							var hc: int = Hash32.h2(x / 2, y / 2 + st * 13, 3197 + sz.unicode_at(0))
							o = g_d if wall else (g_d if hc % 3 == 0 else Color(0, 0, 0, 0))
							if wall and hc % 3 == 1:
								o = g_deep
					elif d < 1.0:
						if st == 0:
							o = (earth_l if upper else earth_d) if hh % 4 != 0 else g_d
						elif st == 1:
							o = g_l if upper else g_d
							if hs % 4 == 0:
								o = earth if hh % 3 != 0 else g_d
						else:

							o = (g_l if upper else g_d) if hs % 3 != 0 else Color(0, 0, 0, 0)
					elif d < 1.15 and st == 0 and hh % 5 == 0:
						o = earth
					if o.a > 0.0:
						img.set_pixel(x, y, o)

			if st >= 1 and sz != "s":
				var n_fl: int = 1 if sz == "m" else 3
				for k in n_fl:
					var hk: int = Hash32.h2(k, sz.unicode_at(0), 777)
					var ang: float = float(hk % 360) * PI / 180.0
					var fx: int = clampi(int(rx + cos(ang) * rx * 0.72), 1, wh.x - 2)
					var fy: int = clampi(int(ry + sin(ang) * ry * 0.72), 1, wh.y - 2)
					if st == 1:
						img.set_pixel(fx, fy, g_l)
					else:
						img.set_pixel(fx, fy + 1, g)
						img.set_pixel(fx, fy, [fl_y, fl_w, fl_r][(hk >> 4) % 3])
				if sz == "l" and st == 2:

					var bx: int = int(rx) + 2
					var by: int = int(ry)
					for q: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]:
						img.set_pixel(bx + q.x, by + q.y, forest)
					img.set_pixel(bx, by - 1, g)
					img.set_pixel(bx + 1, by - 1, g_l)
			_scar_tex["%s%d" % [sz, st]] = ImageTexture.create_from_image(img)


static func _draw_scar(ci: CanvasItem, sz: String, st: int, p: Vector2, a: float) -> void :
	var t: ImageTexture = _scar_tex.get("%s%d" % [sz, st])
	if t == null or a <= 0.0:
		return
	var s: Vector2 = Vector2(t.get_size())
	ci.draw_texture(t, (p - (s * 0.5).floor()).round(), Color(1, 1, 1, a))
