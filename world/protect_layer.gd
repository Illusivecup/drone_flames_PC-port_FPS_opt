class_name ProtectLayer
extends Node2D







const NET_PERIOD: Array = [6, 6, 5, 4]
const BLOCK_H: Array = [0, 4, 5, 7]
const SCAF_STEP: int = 6
const MESH_COLOR: String = "ui_steel_dark"
const ROPE_COLOR: String = "concrete_light"
const MESH_A: Array = [0.0, 0.45, 0.5, 0.55]
const CURTAIN_A: float = 0.22

var gw: GameWorld
var front: bool = true
var _t: float = 0.0
var _sig: int = -1
static var _cache: Dictionary = {}


static func ensure(world: GameWorld) -> void :
	if world == null or world.objects == null or not world.objects.is_inside_tree():
		return
	for fr: bool in [false, true]:
		var nm: String = "ProtectFront" if fr else "ProtectBack"
		var l: ProtectLayer = world.get_node_or_null(nm) as ProtectLayer
		if l == null:
			l = ProtectLayer.new()
			l.name = nm
			l.front = fr
			l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			world.add_child(l)
		l.gw = world
		var oi: int = world.objects.get_index()
		world.move_child(l, oi + 1 if fr else oi)
		l._sig = -1
		l.queue_redraw()



static func canopy_h(world: GameWorld, f: Facility) -> int:
	var fh: int = f.size.y * GameWorld.CELL
	var sh: int = fh + 12
	if f.main_obj >= 0 and f.main_obj < world.obj_spr.size():
		sh = int(world.spr_rect[world.obj_spr[f.main_obj]].size.y)
	return clampi(roundi(float(sh - fh) * 0.75), 6, 20)


func _pr() -> Protect:
	if gw == null:
		return null
	return gw.get("protect") as Protect


func _shown(f: Facility) -> bool:
	if gw.vision == null:
		return true
	if not gw.vision.shows(f.country_id, f.center_px()):
		return false
	return f.main_obj < 0 or f.main_obj >= gw.obj_hidden.size() or gw.obj_hidden[f.main_obj] == 0


func _process(delta: float) -> void :
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	var pr: Protect = _pr()
	if pr == null:
		if _sig != 0:
			_sig = 0
			queue_redraw()
		return
	var sig: int = pr.ver * 7919 + 13
	var busy: bool = false
	for fid: int in pr.st:
		var f: Facility = pr.fac(fid)
		if f == null or not _shown(f):
			continue
		sig = (sig * 31 + fid + 1) & 1073741823
		var s: Dictionary = pr.st[fid]
		if int(s["ns"]) == Protect.S_BUILDING or int(s["cs"]) == Protect.S_BUILDING:
			busy = true
	if busy or sig != _sig:
		_sig = sig
		queue_redraw()


func _draw() -> void :
	var pr: Protect = _pr()
	if pr == null:
		return


	var order: Array[Facility] = []
	for fid: int in pr.st:
		var f0: Facility = pr.fac(fid)
		if f0 != null:
			order.append(f0)
	order.sort_custom( func(a: Facility, b: Facility) -> bool:
		return a.cell.y + a.size.y < b.cell.y + b.size.y or (a.cell.y + a.size.y == b.cell.y + b.size.y and a.cell.x < b.cell.x))
	for f: Facility in order:
		var fid: int = f.id
		if not gw.mil.alive(f) or not _shown(f):
			continue
		var s: Dictionary = pr.st[fid]
		var o: Vector2 = f.origin_px()
		var fw: int = f.size.x * GameWorld.CELL
		var fh: int = f.size.y * GameWorld.CELL
		var hh: int = canopy_h(gw, f)
		var cs: int = int(s["cs"])
		var cl: int = int(s["cl"])
		if cs == Protect.S_OK or cs == Protect.S_BROKEN:
			var dmg: int = 3 if cs == Protect.S_BROKEN else 0
			if dmg == 0 and int(s["cm"]) > 0 and int(s["cc"]) < int(s["cm"]):
				dmg = 1 if int(s["cc"]) * 2 >= int(s["cm"]) else 2
			if dmg == 0 and int(s["cc"]) == 0 and bool(s["ch"]):
				dmg = 2
			var bh: int = int(BLOCK_H[cl])
			draw_texture(_conc_tex(fw, fh, cl, dmg, front), o + Vector2(-7, - bh - 3))
		elif cs == Protect.S_BUILDING and front:
			_draw_conc_build(o, fw, fh, cl, 1.0 - float(s["ct"]) / maxf(0.01, float(s["cT"])))
		var ns: int = int(s["ns"])
		if ns == Protect.S_OK or ns == Protect.S_BROKEN:
			draw_texture(_net_tex(fw, fh, hh, int(s["nl"]), ns == Protect.S_BROKEN, front), o + Vector2(-1, - hh - 1))
		elif ns == Protect.S_BUILDING and front:
			_draw_net_build(o, fw, fh, hh, 1.0 - float(s["nt"]) / maxf(0.01, float(s["nT"])))




func _bar(p: Vector2, w: int, k: float) -> void :
	draw_rect(Rect2(p, Vector2(w, 3)), Palette.c("outline"))
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(w - 2, 1)), Palette.c("ui_rubber"))
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(roundi(float(w - 2) * clampf(k, 0.0, 1.0)), 1)), Palette.c("amber"))


func _scaffold(o: Vector2, fw: int, fh: int, h: int) -> void :
	var pole: = Palette.c("wood_light")
	var plank: = Palette.c("wood")
	var dark: = Palette.c("outline")
	var y1: float = o.y + fh

	var xs: Array[int] = []
	var x: int = 0
	while x < fw:
		xs.append(x)
		x += SCAF_STEP
	xs.append(fw - 1)
	for xi: int in xs:
		draw_rect(Rect2(o.x + xi, y1 - h, 1, h), pole)
		draw_rect(Rect2(o.x + xi + 1, y1 - h + 1, 1, h - 1), Color(dark, 0.35))

	for yy in range(int(y1) - h + 1, int(y1), 4):
		draw_rect(Rect2(o.x, yy, fw, 1), plank)
	for k in xs.size() - 1:
		var a: int = xs[k]
		var b: int = xs[k + 1]
		var steps: int = b - a
		for i in steps:
			var py: float = y1 - 1 - roundi(float(i) * float(h - 2) / float(maxi(1, steps)))
			draw_rect(Rect2(o.x + a + i, py, 1, 1), Color(plank, 0.8))

	for sx: float in [o.x, o.x + fw - 1]:
		draw_rect(Rect2(sx, o.y - h, 1, h), pole)
		draw_rect(Rect2(sx, o.y - h, 1, fh), Color(plank, 0.9))
	draw_rect(Rect2(o.x, o.y - h, fw, 1), Color(plank, 0.9))


func _draw_net_build(o: Vector2, fw: int, fh: int, h: int, k: float) -> void :
	_scaffold(o, fw, fh, h)

	var n: Color = Color(Palette.c("smoke_light"), 0.55)
	var cw: int = roundi(float(fw) * clampf(k, 0.0, 1.0))
	for yy in range(0, fh, 3):
		draw_rect(Rect2(o.x, o.y - h + yy, cw, 1), n)
	_bar(Vector2(o.x + 2, o.y - h - 5), fw - 4, k)


func _draw_conc_build(o: Vector2, fw: int, fh: int, lvl: int, k: float) -> void :
	var tape: = Palette.c("amber")
	var y1: float = o.y + fh + 1

	for xx in range(-4, fw + 4, 2):
		draw_rect(Rect2(o.x + xx, y1 + 1, 1, 1), tape)
	for yy in range(0, fh, 2):
		draw_rect(Rect2(o.x - 4, o.y + yy, 1, 1), tape)
		draw_rect(Rect2(o.x + fw + 3, o.y + yy, 1, 1), tape)
	var bh: int = int(BLOCK_H[lvl])
	var n: int = (fw + 8) / 4
	var done: int = roundi(float(n) * clampf(k, 0.0, 1.0))
	for i in done:
		_block_direct(Vector2(o.x - 4 + i * 4, y1 + 2 - bh), bh)

	var pole: = Palette.c("wood_light")
	draw_rect(Rect2(o.x - 4, y1 - 9, 1, 9), pole)
	draw_rect(Rect2(o.x - 1, y1 - 9, 1, 9), pole)
	draw_rect(Rect2(o.x - 5, y1 - 9, 6, 1), Palette.c("wood"))
	_bar(Vector2(o.x + 2, y1 + 4), fw - 4, k)


func _block_direct(p: Vector2, bh: int) -> void :
	draw_rect(Rect2(p, Vector2(3, bh)), Palette.c("concrete"))
	draw_rect(Rect2(p, Vector2(3, 1)), Palette.c("concrete_light"))
	draw_rect(Rect2(p + Vector2(0, bh), Vector2(3, 1)), Palette.c("outline"))




static func _h(a: int, b: int, c: int) -> int:
	var x: int = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	x = (x ^ (x >> 13)) * 1274126177
	return absi(x ^ (x >> 16))


static func _put(im: Image, x: int, y: int, c: Color) -> void :
	if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
		im.set_pixel(x, y, c)



static func _net_tex(fw: int, fh: int, h: int, lvl: int, torn: bool, fr: bool) -> Texture2D:
	var key: String = "n:%d:%d:%d:%d:%s:%s" % [fw, fh, h, lvl, torn, fr]
	if _cache.has(key):
		return _cache[key]
	var w: int = fw + 2
	var ht: int = fh + h + 3
	var im: = Image.create(w, ht, false, Image.FORMAT_RGBA8)
	var mesh: = Palette.c(MESH_COLOR)
	var rope: = Palette.c(ROPE_COLOR)
	var pole: = Palette.c("ui_steel_light")
	var shade: = Palette.c("outline")
	var p: int = int(NET_PERIOD[lvl])
	var x0: int = 1
	var x1: int = fw
	var poles: Array[int] = [x0, x1]
	if lvl >= 2:
		poles.append((x0 + x1) / 2)
	if not fr:

		for px: int in poles:
			var top: int = 1
			if torn and px == x1:
				top = 1 + h / 2
			for y in range(top, h + 2):
				_put(im, px, y, pole)
				_put(im, px + 1, y, Color(shade, 0.45))
		var tex0: = ImageTexture.create_from_image(im)
		_cache[key] = tex0
		return tex0

	for y in range(1, fh + 1):
		for x in range(x0, x1 + 1):
			var edge: bool = y == 1 or y == fh or x == x0 or x == x1
			var on: bool = posmod(x + y, p) == 0 or posmod(x - y, p) == 0
			if not edge and not on:
				continue
			if torn:
				var u: float = float(x - x0) / float(maxi(1, x1 - x0))
				var v: float = float(y - 1) / float(maxi(1, fh - 1))
				var keep: float = minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
				var corner: bool = (u + v * 0.8 < 0.34) or (u > 0.78 and v > 0.62)
				if not corner and keep + float(_h(x / 2, y / 2, 5) % 30) / 100.0 > 0.12:
					continue
				if edge and (_h(x / 3, y / 3, 9) % 2 == 0 or not corner):
					continue
			if edge:
				_put(im, x, y, Color(rope, 0.95))
			else:
				_put(im, x, y, Color(mesh, float(MESH_A[lvl])))
	if lvl >= 3 and not torn:
		for x in range(x0 + 1, x1):
			_put(im, x, 2, Color(rope, 0.7))
			_put(im, x, fh - 1, Color(rope, 0.7))

	var c_top: int = fh + 1
	var c_bot: int = fh + h - 1
	if not torn:
		for y in range(c_top, c_bot + 1):
			for x in range(x0, x1 + 1):
				if posmod(x + y, p) == 0 or posmod(x - y, p) == 0:
					_put(im, x, y, Color(mesh, CURTAIN_A))
		for x in range(x0, x1 + 1):
			_put(im, x, c_bot + 1, Color(rope, 0.8))
	else:

		var nstr: int = maxi(3, fw / 7)
		for k in nstr:
			var sx: int = x0 + 2 + (k * (x1 - x0 - 4)) / maxi(1, nstr - 1)
			var ln: int = 3 + _h(k, fw, 11) % maxi(2, h - 3)
			var dirx: int = -1 if _h(k, fh, 13) % 2 == 0 else 1
			for i in ln:
				var xx: int = sx + dirx * (i / 3)
				_put(im, xx, c_top + i, Color(rope, 0.85))
				if i % 2 == 0:
					_put(im, xx + dirx, c_top + i, Color(mesh, 0.6))
		for i in mini(h + 2, fh):
			_put(im, x1 - 2 - i / 2, c_top + i * h / maxi(1, fh), Color(rope, 0.75))

	for px: int in poles:
		var top2: int = fh
		if torn and px == x0:
			top2 = fh + h / 2
			_put(im, px - 1, top2 - 1, pole)
			_put(im, px - 2, top2 - 2, pole)
		for y in range(top2, fh + h + 1):
			_put(im, px, y, pole)
		_put(im, px, top2, Palette.c("white"))
		_put(im, px + 1, fh + h + 1, Color(shade, 0.5))
	var tex: = ImageTexture.create_from_image(im)
	_cache[key] = tex
	return tex




static func _conc_tex(fw: int, fh: int, lvl: int, dmg: int, fr: bool) -> Texture2D:
	var key: String = "c:%d:%d:%d:%d:%s" % [fw, fh, lvl, dmg, fr]
	if _cache.has(key):
		return _cache[key]
	var bh: int = int(BLOCK_H[lvl])
	var ox: int = 7
	var oy: int = bh + 3
	var im: = Image.create(fw + 14, fh + bh + 9, false, Image.FORMAT_RGBA8)
	var blocks: Array = []
	if fr:
		for yy in range(3, fh + 1, 4):
			blocks.append([ox - 5, oy + yy])
			blocks.append([ox + fw + 1, oy + yy])
		for xx in range(-5, fw + 2, 5):
			blocks.append([ox + xx, oy + fh + 3])
	else:
		for xx in range(-5, fw + 2, 5):
			blocks.append([ox + xx, oy - 1])
	var i: int = 0
	for b: Array in blocks:
		i += 1
		_block(im, int(b[0]), int(b[1]), bh, lvl, dmg, _h(int(b[0]), int(b[1]), fw * 7 + fh))
	var tex: = ImageTexture.create_from_image(im)
	_cache[key] = tex
	return tex


static func _block(im: Image, x: int, yb: int, bh: int, lvl: int, dmg: int, hs: int) -> void :
	var light: = Palette.c("concrete_light")
	var mid: = Palette.c("concrete")
	var dark: = Palette.c("concrete_dark")
	var out: = Palette.c("outline")
	var r: int = hs % 100
	if dmg >= 3:
		if r < 50:

			_put(im, x + hs % 3, yb, dark)
			_put(im, x + 1 + (hs >> 3) % 3, yb - 1, mid)
			_put(im, x + (hs >> 5) % 4, yb, light)
			_put(im, x + 3, yb, Color(out, 0.6))
			return
		bh = maxi(2, bh - 1 - (hs >> 5) % 3)
	var top: int = yb - bh + 1
	for y in range(top - 1, yb + 2):
		for xx in range(-1, 5):
			_put(im, x + xx, y, Color(out, 0.55 if y > top - 1 and y < yb + 1 else 0.35))
	for y in range(top, yb + 1):
		for xx in 4:
			var c: Color = mid
			if y <= top + (1 if bh >= 5 else 0):
				c = light
			elif xx == 3 or y == yb:
				c = dark
			_put(im, x + xx, y, c)
	if lvl >= 3 and bh >= 6:
		for xx in 4:
			_put(im, x + xx, top + 3, dark)
	var crack: bool = (dmg == 1 and r < 40) or (dmg == 2 and r < 75) or dmg >= 3
	if crack:
		_put(im, x + 1, top + 1, out)
		_put(im, x + 2, top + 2, out)
		_put(im, x + (1 if hs % 2 == 0 else 2), mini(yb - 1, top + 3), out)
		_put(im, x + 3, top, Color(out, 0.9))
		_put(im, x + 3, top + 1, Color(out, 0.6))
