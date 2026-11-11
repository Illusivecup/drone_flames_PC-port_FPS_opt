extends Node2D











const DARK: = Color("0b1430")
const FLASH: = Color("ffe08a")
const FLASH_HOT: = Color("fff6d8")
const TEXT: = Color("fbf3e0")

const DIG: Array = [[7, 5, 5, 5, 7], [2, 6, 2, 2, 7], [7, 1, 7, 4, 7], [7, 1, 3, 1, 7], [5, 5, 7, 1, 1], 
	[7, 4, 7, 1, 7], [7, 4, 7, 5, 7], [7, 1, 1, 2, 2], [7, 5, 7, 5, 7], [7, 5, 7, 1, 7]]

const HELM: Array = [14, 31, 31, 4, 14]

var gw: GameWorld
var _fl: Dictionary = {}
var _cd: Dictionary = {}
var sel: int = -1
var _ol: Dictionary = {}
var _img: Dictionary = {}
var draw_us: int = 0
var _had: bool = false
var _sel_drawn: bool = false


static func make(world: GameWorld) -> Node2D:
	var l: Node2D = (load("res://world/hold_layer.gd") as GDScript).new()
	l.name = "Hold"
	l.set("gw", world)
	l.z_index = 6
	return l


func _process(_d: float) -> void :
	if gw == null or gw.get("hold") == null:
		return



	var busy: bool = not (gw.hold.holds as Dictionary).is_empty() or not _fl.is_empty()
	if busy or _had or sel >= 0 or _sel_drawn:
		queue_redraw()
	_sel_drawn = sel >= 0
	_had = busy


func _draw() -> void :
	if gw == null or gw.get("hold") == null or gw.data == null:
		return
	var t0: int = Time.get_ticks_usec()
	if sel >= 0 and sel < gw.obj_spr.size() and gw.obj_state[sel] == 0:
		_brackets(sel)
	var hs: Dictionary = gw.hold.holds
	if hs.is_empty():
		_fl.clear()
		_cd.clear()
		return
	var ct: Transform2D = get_canvas_transform()
	var z: float = maxf(0.05, ct.get_scale().x)
	var vis: Rect2 = (ct.affine_inverse() * get_viewport_rect()).grow(40.0)
	var me: int = gw.player.id if gw.player != null else -1
	var seen: Dictionary = {}
	var placed: Array = []
	for oid: int in hs:
		if oid < 0 or oid >= gw.obj_spr.size() or gw.obj_state[oid] != 0:
			continue
		if oid < gw.obj_hidden.size() and gw.obj_hidden[oid] != 0:
			continue
		var h: Dictionary = hs[oid]
		var sid: int = ArchStyle.draw_sid(gw, oid)
		var o: Vector2 = ArchStyle.draw_origin(gw, oid)
		var sz: Vector2 = gw.spr_rect[sid].size
		var rr: = Rect2(o, sz)
		if not vis.intersects(rr):
			continue
		var cid: int = int(h["c"])
		if cid != me and gw.vision != null and gw.vision.active() and not gw.vision.shows(cid, rr.get_center()):
			continue
		var c: Country = gw.country_by_id(cid)
		var col: Color = c.color if c != null else Color.WHITE

		var ot: Variant = _outline(sid)
		if ot is Texture2D:
			draw_texture(ot as Texture2D, o - Vector2.ONE, col)
		else:
			draw_rect(Rect2(o - Vector2.ONE, sz + Vector2(2, 2)), col, false, 1.0)

		var ua: Array = h["u"]
		var sa: Array = h["s"]
		var hi: bool = bool(h["hi"])
		var n_in: int = 0
		for k in ua.size():
			var u: Unit = ua[k]
			if not u.alive() or u.pi < u.path.size() or u.pos.distance_to(sa[k]) > 3.0:
				continue
			n_in += 1
			seen[u.id] = true
			var fx: float = floorf(o.x + sz.x * (0.18 + 0.2 * float(k)))
			var row: float = (0.42 + 0.16 * float(k % 2)) if hi else (0.55 + 0.06 * float(k % 2))
			var fy: float = floorf(o.y + 2.0 + (sz.y - 2.0) * row)
			draw_rect(Rect2(fx - 1.0, fy - 1.0, 4.0, 5.0), DARK.lightened(0.15))
			draw_rect(Rect2(fx, fy + 1.0, 2.0, 3.0), DARK)
			draw_rect(Rect2(fx, fy, 2.0, 1.0), col)




			var cd_was: float = float(_cd.get(u.id, u.fire_cd))
			_cd[u.id] = u.fire_cd
			var left: int = int(_fl.get(u.id, 0))
			if u.fire_cd > cd_was + 0.05:
				left = 6
			if left > 0:
				var tx: float = gw.army._target_pos(u.target, u.pos).x if u.target != null else u.pos.x + 1.0
				var rt: bool = tx >= u.pos.x
				var q: float = maxf(1.0, roundf(1.2 / z))
				var mc: = Vector2(fx + (3.0 if rt else -1.0), fy + 1.5)
				var big: bool = left >= 4
				var gl: = FLASH
				gl.a = 0.35 if big else 0.18
				draw_rect(Rect2(mc - Vector2(2.5, 2.5) * q, Vector2(5, 5) * q), gl)
				draw_rect(Rect2(mc - Vector2(1.5, 0.5) * q, Vector2(3, 1) * q), FLASH)
				draw_rect(Rect2(mc - Vector2(0.5, 1.5) * q, Vector2(1, 3) * q), FLASH)
				if big:
					draw_rect(Rect2(mc + Vector2(-0.5 + (1.5 if rt else -2.5), -0.5) * q, Vector2(2, 1) * q), FLASH)
				draw_rect(Rect2(mc - Vector2(0.5, 0.5) * q, Vector2(1, 1) * q), FLASH_HOT)
				_fl[u.id] = left - 1
			else:
				_fl.erase(u.id)
		_badge(Vector2(o.x + sz.x * 0.5, o.y - 2.0), n_in, ua.size(), col, z, placed)
	for uid: int in _fl.keys():
		if not seen.has(uid):
			_fl.erase(uid)
	for uid2: int in _cd.keys():
		if not seen.has(uid2):
			_cd.erase(uid2)
	draw_us = Time.get_ticks_usec() - t0




func _badge(p: Vector2, n_in: int, n: int, col: Color, z: float, placed: Array) -> void :
	var s: float = maxf(1.0 / z, roundf(2.0 / z * 4.0) / 4.0)
	var w: float = 13.0
	var hgt: float = 9.0
	var x0: float = p.x - w * s * 0.5
	var y0: float = p.y - hgt * s
	var br: = Rect2(x0 - s, y0 - s, (w + 2.0) * s, (hgt + 3.0) * s)
	for guard in 6:
		var hit: bool = false
		for q: Rect2 in placed:
			if q.intersects(br):
				hit = true
				br.position.y = q.position.y - br.size.y - s
		if not hit:
			break
	y0 = br.position.y + s
	placed.append(br)
	draw_rect(Rect2(x0 - s, y0 - s, (w + 2.0) * s, (hgt + 2.0) * s), col)
	draw_rect(Rect2(x0, y0, w * s, hgt * s), DARK)
	draw_rect(Rect2(x0 + (w * 0.5 - 1.0) * s, y0 + hgt * s, 2.0 * s, s), col)
	for r in 5:
		var bits: int = HELM[r]
		for b in 5:
			if bits & (1 << (4 - b)):
				draw_rect(Rect2(x0 + (2.0 + b) * s, y0 + (2.0 + r) * s, s, s), col)
	var dg: int = clampi(n_in if n_in > 0 else n, 0, 9)
	var tc: Color = TEXT if n_in > 0 else TEXT.darkened(0.45)
	for r2 in 5:
		var bits2: int = DIG[dg][r2]
		for b2 in 3:
			if bits2 & (1 << (2 - b2)):
				draw_rect(Rect2(x0 + (8.0 + b2) * s, y0 + (2.0 + r2) * s, s, s), tc)




func _outline(sid: int) -> Variant:
	if _ol.has(sid):
		return _ol[sid]
	var res: Variant = null
	var tex: Texture2D = gw.spr_tex[sid] if sid < gw.spr_tex.size() else null
	if tex != null:
		var key: int = tex.get_instance_id()
		var img: Image = _img.get(key, null)
		if img == null and not _img.has(key):
			img = tex.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				img.convert(Image.FORMAT_RGBA8)
			_img[key] = img
		if img != null:
			var r: Rect2 = gw.spr_rect[sid]
			var w: int = int(r.size.x)
			var h: int = int(r.size.y)
			var px: int = int(r.position.x)
			var py: int = int(r.position.y)
			var out: = Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
			var op: = PackedByteArray()
			op.resize((w + 2) * (h + 2))
			for y in h:
				for x in w:
					if px + x < img.get_width() and py + y < img.get_height() and img.get_pixel(px + x, py + y).a > 0.5:
						op[(y + 1) * (w + 2) + x + 1] = 1
			for y2 in h + 2:
				for x2 in w + 2:
					if op[y2 * (w + 2) + x2] != 0:
						continue
					var near: bool = (x2 > 0 and op[y2 * (w + 2) + x2 - 1] != 0) or (x2 < w + 1 and op[y2 * (w + 2) + x2 + 1] != 0)\
					or (y2 > 0 and op[(y2 - 1) * (w + 2) + x2] != 0) or (y2 < h + 1 and op[(y2 + 1) * (w + 2) + x2] != 0)
					if near:
						out.set_pixel(x2, y2, Color.WHITE)
			res = ImageTexture.create_from_image(out)
	_ol[sid] = res
	return res






func _brackets(id: int) -> void :
	var sid: int = ArchStyle.draw_sid(gw, id)
	var r: = Rect2(ArchStyle.draw_origin(gw, id), gw.spr_rect[sid].size)
	var xf: Transform2D = get_global_transform_with_canvas()
	var sr: = Rect2(xf * r.position, Vector2.ZERO).expand(xf * r.end)
	draw_set_transform_matrix(xf.affine_inverse())
	UiKit.draw_sel_frame(self, sr, Color("7cdcff"))
	draw_set_transform_matrix(Transform2D.IDENTITY)
