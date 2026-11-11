extends Node2D














const AMBIG: int = -2
const BADGE_R: float = 10.0
const HIT_R: float = 18.0
const RING_R: float = 10.0
const BLOCK: int = 8

var gw: GameWorld
var def_id: int = -1
var cities: Array = []
var labels: Array = []
var caps: Array = []
var states: Array = []
var sel: int = -1
var tint: Sprite2D
var build_ms: int = 0
var cells: Array = []
var _reg: = PackedByteArray()
var _ox: int = 0
var _oy: int = 0
var _bw: int = 0
var _bh: int = 0
var _pal_img: Image
var _pal_tex: ImageTexture
var _cam_key: = Vector3.INF
var _pulse_t: float = 0.0
var _bbox: = Rect2()


func setup(world: GameWorld, d_id: int, city_ids: Array) -> void :
	gw = world
	def_id = d_id
	cities = city_ids.duplicate()
	name = "ConfMap"
	for cid: int in cities:
		var c: City = gw.cities[cid]
		labels.append(Loc.name(c.name).to_upper())
		caps.append(c.kind == City.Kind.CAPITAL)
		states.append({"style": 1, "col": Color("f2ead2"), "badge": Color("f2ead2")})




func build() -> void :
	var t0: int = Time.get_ticks_msec()
	var d: WorldData = gw.data
	var W: int = d.w
	var H: int = d.h
	var own: PackedByteArray = d.owners
	var x0: int = W
	var y0: int = H
	var x1: int = -1
	var y1: int = -1
	var cents: Array[Vector2i] = []
	for cid: int in cities:
		var cc: City = gw.cities[cid]
		cents.append(cc.center)
		x0 = mini(x0, cc.center.x)
		y0 = mini(y0, cc.center.y)
		x1 = maxi(x1, cc.center.x)
		y1 = maxi(y1, cc.center.y)
		var r: int = int(cc.claim_max * 1.4) + 6
		for y in range(maxi(0, cc.center.y - r), mini(H, cc.center.y + r + 1), 2):
			var row: int = y * W
			for x in range(maxi(0, cc.center.x - r), mini(W, cc.center.x + r + 1), 2):
				if own[row + x] == def_id:
					x0 = mini(x0, x)
					y0 = mini(y0, y)
					x1 = maxi(x1, x)
					y1 = maxi(y1, y)



	var occ: = PackedInt32Array()
	var oi: int = own.find(def_id)
	while oi >= 0:
		var ox: int = oi % W
		var oy: int = oi / W
		x0 = mini(x0, ox)
		y0 = mini(y0, oy)
		x1 = maxi(x1, ox)
		y1 = maxi(y1, oy)
		occ.append(oi)
		oi = own.find(def_id, oi + 1) if oi + 1 < own.size() else -1
	_ox = maxi(0, x0 - 3)
	_oy = maxi(0, y0 - 3)
	var occ_b: Dictionary = {}
	for v: int in occ:
		occ_b[Vector2i((v % W - _ox) / BLOCK, (v / W - _oy) / BLOCK)] = true
	_bw = mini(W, x1 + 4) - _ox
	_bh = mini(H, y1 + 4) - _oy
	_reg.resize(_bw * _bh)
	_reg.fill(0)
	cells.resize(cities.size())
	cells.fill(0)
	var n: int = cents.size()
	var rad: float = float(BLOCK) * 0.75
	var bx0: int = _bw
	var by0: int = _bh
	var bx1: int = -1
	var by1: int = -1
	for qy in range(0, _bh, BLOCK):
		for qx in range(0, _bw, BLOCK):
			if not occ_b.has(Vector2i(qx / BLOCK, qy / BLOCK)):
				continue
			var bc: = Vector2(float(_ox + qx) + float(BLOCK) * 0.5, float(_oy + qy) + float(BLOCK) * 0.5)
			var dl: = PackedFloat32Array()
			dl.resize(n)
			var dmin: float = INF
			for k in n:
				dl[k] = bc.distance_to(Vector2(cents[k]))
				dmin = minf(dmin, dl[k])
			var cand: = PackedInt32Array()
			for k2 in n:
				if dl[k2] <= dmin + 2.0 * rad:
					cand.append(k2)
			for py in range(qy, mini(qy + BLOCK, _bh)):
				var cy: int = _oy + py
				var row2: int = cy * W
				for px in range(qx, mini(qx + BLOCK, _bw)):
					var cx: int = _ox + px
					if own[row2 + cx] != def_id:
						continue
					var best: int = 0
					var bd: int = 1 << 30
					for k3 in cand:
						var c4: Vector2i = cents[k3]
						var dd: int = (cx - c4.x) * (cx - c4.x) + (cy - c4.y) * (cy - c4.y)
						if dd < bd:
							bd = dd
							best = k3
					_reg[py * _bw + px] = mini(best + 1, 255)
					cells[best] = int(cells[best]) + 1
					bx0 = mini(bx0, px)
					by0 = mini(by0, py)
					bx1 = maxi(bx1, px)
					by1 = maxi(by1, py)
	var cs: float = float(GameWorld.CELL)
	if bx1 >= 0:
		_bbox = Rect2(Vector2(_ox + bx0, _oy + by0) * cs, Vector2(bx1 - bx0 + 1, by1 - by0 + 1) * cs)
	else:
		_bbox = Rect2(Vector2(_ox, _oy) * cs, Vector2(maxi(1, _bw), maxi(1, _bh)) * cs)
	for k4 in n:
		_bbox = _bbox.expand((Vector2(cents[k4]) + Vector2(0.5, 0.5)) * cs)
	var img: = Image.create_from_data(maxi(1, _bw), maxi(1, _bh), false, Image.FORMAT_R8, _reg if _reg.size() > 0 else PackedByteArray([0]))
	var rtex: = ImageTexture.create_from_image(img)
	_pal_img = Image.create(maxi(1, n), 1, false, Image.FORMAT_RGBA8)
	_pal_tex = ImageTexture.create_from_image(_pal_img)
	tint = Sprite2D.new()
	tint.name = "ConfTint"
	tint.centered = false
	tint.texture = rtex
	tint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tint.position = Vector2(_ox, _oy) * cs
	tint.scale = Vector2(cs, cs)
	var mat: = ShaderMaterial.new()
	mat.shader = load("res://world/conf_map.gdshader") as Shader
	mat.set_shader_parameter("region_tex", rtex)
	mat.set_shader_parameter("pal_tex", _pal_tex)
	mat.set_shader_parameter("rsize", Vector2(maxi(1, _bw), maxi(1, _bh)))
	mat.set_shader_parameter("npal", n)
	tint.material = mat
	gw.add_child(tint)
	if gw.territory_border != null:
		gw.move_child(tint, gw.territory_border.get_index() + 1)
	_push_states()
	build_ms = Time.get_ticks_msec() - t0


func close() -> void :
	if tint != null and is_instance_valid(tint):
		tint.queue_free()
	tint = null
	queue_free()



func set_states(st: Array, selected: int) -> void :
	states = st
	sel = selected
	_push_states()


func _push_states() -> void :
	if _pal_img == null:
		return
	for k in mini(states.size(), _pal_img.get_width()):
		var s: Dictionary = states[k]
		var c: Color = s["col"]
		_pal_img.set_pixel(k, 0, Color(c.r, c.g, c.b, float(int(s["style"])) / 255.0))
	_pal_tex.update(_pal_img)
	if tint != null and is_instance_valid(tint):
		(tint.material as ShaderMaterial).set_shader_parameter("sel", sel + 1)
	queue_redraw()



func bbox_world() -> Rect2:
	return _bbox


func city_world(k: int) -> Vector2:
	return (Vector2(gw.cities[int(cities[k])].center) + Vector2(0.5, 0.5)) * float(GameWorld.CELL)


func badge_screen(k: int) -> Vector2:
	return gw.camera.world_to_screen(city_world(k)) if k >= 0 and k < cities.size() else Vector2.INF



func region_at(wp: Vector2) -> int:
	var cx: int = floori(wp.x / float(GameWorld.CELL)) - _ox
	var cy: int = floori(wp.y / float(GameWorld.CELL)) - _oy
	if cx < 0 or cy < 0 or cx >= _bw or cy >= _bh:
		return -1
	return int(_reg[cy * _bw + cx]) - 1




func pick_at(sp: Vector2, force: bool) -> int:
	var cam: MapCamera = gw.camera
	var best: int = -1
	var bd: float = INF
	var second: float = INF
	for k in cities.size():
		var dd: float = cam.world_to_screen(city_world(k)).distance_to(sp)
		if dd < bd:
			second = bd
			bd = dd
			best = k
		elif dd < second:
			second = dd
	if bd <= HIT_R:
		if not force and second <= HIT_R and second - bd < 8.0:
			return AMBIG
		return best
	var k0: int = region_at(cam.screen_to_world(sp))
	if k0 < 0 or force:
		return k0
	for i in 8:
		var q: Vector2 = sp + Vector2(RING_R, 0.0).rotated(TAU * float(i) / 8.0)
		var kq: int = region_at(cam.screen_to_world(q))
		if kq >= 0 and kq != k0:
			return AMBIG
	return k0


func _process(delta: float) -> void :
	if gw == null or gw.camera == null:
		return
	var cam: MapCamera = gw.camera
	var key: = Vector3(cam.position.x, cam.position.y, cam.zoom.x)
	if key != _cam_key:
		if tint != null and is_instance_valid(tint) and key.z != _cam_key.z:
			(tint.material as ShaderMaterial).set_shader_parameter("px_world", 1.0 / maxf(0.01, key.z))
		_cam_key = key
		queue_redraw()
	if sel >= 0:
		_pulse_t += delta
		if _pulse_t >= 0.125:
			_pulse_t = 0.0
			var p: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 * 4.0)
			if tint != null and is_instance_valid(tint):
				(tint.material as ShaderMaterial).set_shader_parameter("pulse", p)
			queue_redraw()




const C_DARK: = Color("1b120c")
const C_TEXT: = Color("fbf3e0")


func _draw() -> void :
	if gw == null or gw.camera == null or cities.is_empty():
		return
	UiKit.ensure()
	var cam: MapCamera = gw.camera
	var z: float = maxf(0.01, cam.zoom.x)
	var sc: float = 1.0 / z
	var f: Font = UiKit.f_bold if UiKit.f_bold != null else ThemeDB.fallback_font
	var vs: Vector2 = cam.view_size()
	var view: = Rect2(Vector2.ZERO, vs).grow(40.0)
	var order: Array = []
	if sel >= 0 and sel < cities.size():
		order.append(sel)
	for k in cities.size():
		if k != sel:
			order.append(k)
	var disks: Array = []
	var spos: Dictionary = {}
	for k: int in order:
		var p: Vector2 = cam.world_to_screen(city_world(k)).round()
		if view.has_point(p):
			spos[k] = p
			var r: float = BADGE_R + (2.0 if k == sel else 0.0)
			disks.append(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0))

	var placed: Array = []
	var fs: int = 10 if z >= 1.0 else 9
	for k: int in order:
		if not spos.has(k):
			continue
		var p2: Vector2 = spos[k]
		var nm: String = String(labels[k])
		var fsz: int = fs + (1 if k == sel else 0)
		var tw: float = f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var rr: = Rect2(p2 + Vector2( - tw * 0.5 - 2.0, BADGE_R + 2.0), Vector2(tw + 4.0, float(fsz) + 3.0))
		var ok: bool = k == sel
		if not ok:
			ok = true
			for q: Rect2 in placed:
				if q.intersects(rr):
					ok = false
					break
			if ok:
				for q2: Rect2 in disks:
					if q2.intersects(rr) and not q2.has_point(p2):
						ok = false
						break
		if not ok:
			continue
		placed.append(rr)
		var tp: = Vector2(roundf(p2.x - tw * 0.5), roundf(rr.position.y + float(fsz)))
		draw_set_transform(cam.screen_to_world(tp), 0.0, Vector2(sc, sc))
		draw_string_outline(f, Vector2.ZERO, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 4, C_DARK)
		draw_string(f, Vector2.ZERO, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color("fff1c8") if k == sel else C_TEXT)

	for i in range(order.size() - 1, -1, -1):
		var k2: int = order[i]
		if not spos.has(k2):
			continue
		_badge(k2, spos[k2], f, sc, cam)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _badge(k: int, p: Vector2, f: Font, sc: float, cam: MapCamera) -> void :
	draw_set_transform(cam.screen_to_world(p), 0.0, Vector2(sc, sc))
	var s: Dictionary = states[k] if k < states.size() else {"style": 1, "badge": Color("f2ead2")}
	var bc: Color = s["badge"]
	var style: int = int(s["style"])
	var r: float = BADGE_R + (2.0 if k == sel else 0.0)
	if k == sel:
		var pa: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 * 4.0)
		draw_circle(Vector2.ZERO, r + 5.0, C_DARK)
		draw_circle(Vector2.ZERO, r + 4.0, Color("fff4d6").lerp(Color("ffd75e"), pa))
	draw_circle(Vector2.ZERO, r + 1.0, C_DARK)
	draw_circle(Vector2.ZERO, r, bc)
	if style == 3:
		draw_arc(Vector2.ZERO, r - 3.0, 0.0, TAU, 20, bc.lightened(0.55), 2.0)
	elif style == 4 or style == 5:
		draw_line(Vector2( - r * 0.7, r * 0.7), Vector2(r * 0.7, - r * 0.7), Color(C_DARK, 0.55 if style == 4 else 0.3), 2.0)
	if bool(caps[k]):
		draw_rect(Rect2(-5, - r - 5, 10, 4), C_DARK)
		draw_rect(Rect2(-4, - r - 4, 8, 2), Color("ffd75e"))
	var num: String = str(k + 1)
	var fsz: int = 10 if num.length() < 2 else 9
	var tw: float = f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	var lum: float = bc.r * 0.299 + bc.g * 0.587 + bc.b * 0.114
	var tc: Color = C_DARK if lum > 0.55 else C_TEXT
	var tp: = Vector2(roundf( - tw * 0.5), roundf(float(fsz) * 0.4))
	if tc == C_TEXT:
		draw_string_outline(f, tp, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 3, C_DARK)
	draw_string(f, tp, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, tc)
