extends Node2D









const CELL: int = 4
const EMBER_T: float = 40.0
const FLAME_T: float = 14.0
const SMOKE_T: float = 50.0
const MAX_EMBERS: int = 48
const MAX_FLAMES: int = 10
const MAX_SMOKE: int = 14

const C_ASH: = Color8(140, 140, 136)
const C_ASH2: = Color8(94, 97, 104)
const C_CHAR: = Color8(30, 28, 28)
const C_BARK: = Color8(74, 54, 34)
const C_SPROUT: = Color8(155, 197, 61)
const C_SPROUT2: = Color8(122, 173, 52)
const C_LEAF: = Color8(90, 143, 44)
const C_LEAF_D: = Color8(63, 110, 36)
const C_LEAF_L: = Color8(155, 197, 61)
const C_TRUNK: = Color8(107, 79, 48)
const C_EMBER: = [Color8(255, 138, 30), Color8(226, 85, 27), Color8(154, 46, 22)]
const C_FLAME_O: = Color8(226, 85, 27)
const C_FLAME_Y: = Color8(255, 196, 58)
const C_SMOKE: = Color(0.42, 0.42, 0.44, 0.55)


class Fire:
	extends Node2D
	var layer: Node2D

	func _draw() -> void :
		layer.call("draw_fire", self)


class Blk:
	extends Node2D
	var layer: Node2D
	var bk: int = 0
	var v: int = -1

	func _draw() -> void :
		layer.call("draw_block", self)


const BLK: int = 16
const MAKE_PER_FRAME: int = 8

var gw: GameWorld
var fire: Fire
var live: Dictionary = {}
var _ver: int = -1
var _fresh_t: float = 0.0
var _fire_t: float = 0.0
var _gc: int = 0
var _fresh: Array = []
var stats_cells: int = 0
var stats_us: int = 0


static func make(world: GameWorld) -> Node2D:
	var l: Node2D = (load("res://world/nature_layer.gd") as GDScript).new()
	l.name = "Nature"
	l.set("gw", world)
	return l


func _ready() -> void :
	fire = Fire.new()
	fire.layer = self
	fire.name = "NatureFire"
	add_child(fire)


func _view() -> Rect2:
	var cam: MapCamera = gw.camera
	var half: Vector2 = cam.view_size() * 0.5 / cam.zoom.x
	return Rect2(cam.position - half, half * 2.0)


func _process(delta: float) -> void :
	var nat: Object = gw.nature if gw != null else null
	if nat == null or gw.camera == null or gw.data == null:
		visible = false
		return
	var blk: Dictionary = nat.get("blk")
	visible = gw.camera.zoom.x >= 0.99 and not blk.is_empty()
	if not visible:
		return
	var v: Rect2 = _view().grow(64.0)
	var bx0: int = maxi(0, int(v.position.x) / (BLK * CELL))
	var by0: int = maxi(0, int(v.position.y) / (BLK * CELL))
	var bx1: int = int(v.end.x) / (BLK * CELL)
	var by1: int = int(v.end.y) / (BLK * CELL)
	var bver: Dictionary = nat.get("bver")
	var made: int = 0
	var nv: int = int(nat.get("ver"))

	if (by1 - by0 + 1) * (bx1 - bx0 + 1) < blk.size():
		for by in range(by0, by1 + 1):
			for bx in range(bx0, bx1 + 1):
				made = _touch(by * 65536 + bx, blk, bver, made)
	else:
		for bk: int in blk:
			var bx2: int = bk % 65536
			var by2: int = bk / 65536
			if bx2 >= bx0 and bx2 <= bx1 and by2 >= by0 and by2 <= by1:
				made = _touch(bk, blk, bver, made)

	_gc += 1
	if _gc >= 30 or nv != _ver:
		_gc = 0
		_ver = nv
		for bk: int in live.keys():
			var bx3: int = bk % 65536
			var by3: int = bk / 65536
			if not blk.has(bk) or bx3 < bx0 - 3 or bx3 > bx1 + 3 or by3 < by0 - 3 or by3 > by1 + 3:
				(live[bk] as Node).queue_free()
				live.erase(bk)
	_fresh_t -= delta
	if _fresh_t <= 0.0:
		_fresh_t = 1.0
		_collect_fresh(nat, blk, bx0, by0, bx1, by1)
	_fire_t -= delta
	if _fire_t <= 0.0 and not _fresh.is_empty():
		_fire_t = 0.12
		fire.queue_redraw()


func _touch(bk: int, blk: Dictionary, bver: Dictionary, made: int) -> int:
	if not blk.has(bk):
		return made
	var c: Blk = live.get(bk)
	if c == null:
		if made >= MAKE_PER_FRAME:
			return made
		c = Blk.new()
		c.layer = self
		c.bk = bk
		add_child(c)
		move_child(c, 0)
		live[bk] = c
		made += 1
	var bv: int = int(bver.get(bk, 0))
	if c.v != bv:
		c.v = bv
		c.queue_redraw()
	return made


func _collect_fresh(nat: Object, blk: Dictionary, bx0: int, by0: int, bx1: int, by1: int) -> void :
	_fresh.clear()
	var cells: Dictionary = nat.get("cells")
	var now: float = gw.game_time
	var w: int = gw.data.w
	for bk: int in live:
		var bx: int = bk % 65536
		var by: int = bk / 65536
		if bx < bx0 or bx > bx1 or by < by0 or by > by1 or not blk.has(bk):
			continue
		for i: int in blk[bk]:
			var r: Array = cells.get(i, [])
			if r.is_empty() or int(r[1]) != 0 or now - float(r[0]) >= SMOKE_T:
				continue
			_fresh.append([i % w, i / w, float(r[0]), Hash32.h2(i % w, i / w, 919)])


func draw_block(ci: Blk) -> void :
	var t0: int = Time.get_ticks_usec()
	var nat: Object = gw.nature
	if nat == null:
		return
	var cells: Dictionary = nat.get("cells")
	var blk: Dictionary = nat.get("blk")
	if not blk.has(ci.bk):
		return
	var w: int = gw.data.w
	var n: int = 0
	for i: int in blk[ci.bk]:
		var r: Array = cells.get(i, [])
		if r.is_empty():
			continue
		var x: int = i % w
		var y: int = i / w
		var st: int = int(r[1])
		var h: int = Hash32.h2(x, y, 919)
		var px: = Vector2(x * CELL, y * CELL)
		var tree: bool = gw.tree_at.has(i)
		n += 1
		if st == 0:
			_ash(ci, px, h, tree)
		else:
			_tufts(ci, px, x, y, h, st >= 2)
			if st >= 2 and _forest(int(r[2])) and not tree and ((h >> 6) & 3) != 0:
				_sapling(ci, px + Vector2(float((h >> 9) & 1), float((h >> 10) & 1)), h)
	stats_cells = n
	stats_us = Time.get_ticks_usec() - t0


static func _forest(b: int) -> bool:
	return b == Biome.FOREST or b == Biome.PINE


func _px(ci: CanvasItem, p: Vector2, c: Color) -> void :
	ci.draw_rect(Rect2(p, Vector2.ONE), c)




func _ash(ci: CanvasItem, p: Vector2, h: int, tree: bool) -> void :
	_px(ci, p + Vector2(h & 3, (h >> 2) & 3), C_ASH if (h & 16) != 0 else C_ASH2)
	if (h & 32) != 0:
		_px(ci, p + Vector2((h >> 6) & 3, (h >> 8) & 3), C_ASH2)
	if tree:
		return
	var k: int = (h >> 12) % 10
	if k == 0:
		var o: = p + Vector2(1 + ((h >> 16) & 1), 1)
		ci.draw_rect(Rect2(o, Vector2(2, 2)), C_CHAR)
		_px(ci, o, C_BARK)
	elif k == 1:
		var o2: = p + Vector2(0, 1 + ((h >> 17) & 1))
		ci.draw_rect(Rect2(o2, Vector2(4, 1)), C_CHAR)
		_px(ci, o2 + Vector2(1 + ((h >> 18) & 1), 0), C_BARK)




func _tufts(ci: CanvasItem, p: Vector2, x: int, y: int, h: int, young: bool) -> void :
	var hc: int = Hash32.h2(x >> 1, y >> 1, 523)
	var dense: bool = young or (hc % 3) != 0
	if not dense:
		if (h & 3) == 0:
			ci.draw_rect(Rect2(p + Vector2((h >> 2) & 1, 2), Vector2(2, 1)), C_ASH2)
		return
	var o: = p + Vector2((h >> 4) & 1, (h >> 5) & 1)
	_px(ci, o + Vector2(1, 0), C_SPROUT)
	_px(ci, o + Vector2(0, 1), C_SPROUT2)
	_px(ci, o + Vector2(2, 1), C_LEAF if young else C_SPROUT2)
	if young and (h & 64) != 0:
		_px(ci, o + Vector2(1, 1), C_LEAF_D)



func _sapling(ci: CanvasItem, p: Vector2, h: int) -> void :
	var o: = p + Vector2(0, -1)
	_px(ci, o + Vector2(1, 0), C_LEAF_L)
	ci.draw_rect(Rect2(o + Vector2(0, 1), Vector2(3, 1)), C_LEAF)
	_px(ci, o + Vector2(0, 1), C_LEAF_L)
	_px(ci, o + Vector2(2, 1), C_LEAF_D)
	_px(ci, o + Vector2(1, 2), C_LEAF_D if (h & 1) != 0 else C_LEAF)
	_px(ci, o + Vector2(1, 3), C_TRUNK)



func draw_fire(ci: CanvasItem) -> void :
	if _fresh.is_empty() or gw.camera == null:
		return
	var now: float = gw.game_time
	var v: Rect2 = _view()
	var ne: int = 0
	var nf: int = 0
	var ns: int = 0
	var tick: float = float(Time.get_ticks_msec()) * 0.001
	for e: Array in _fresh:
		var p: = Vector2(float(e[0]) * CELL, float(e[1]) * CELL)
		if not v.has_point(p):
			continue
		var age: float = now - float(e[2])
		var h: int = int(e[3])
		var sel: int = (h >> 20) & 63
		if age < EMBER_T and sel % 5 == 0 and ne < MAX_EMBERS and randf() > age / EMBER_T * 0.8:
			ne += 1
			var c: Color = C_EMBER[randi() % 3] if age < EMBER_T * 0.5 else C_EMBER[1 + randi() % 2]
			ci.draw_rect(Rect2(p + Vector2((h >> 3) & 3, (h >> 5) & 3), Vector2.ONE), c)
		if age < FLAME_T and sel % 13 == 0 and nf < MAX_FLAMES:
			nf += 1
			var fh: int = 1 + int(randf() * 2.0 * (1.0 - age / FLAME_T)) + 1
			var fp: = p + Vector2(1 + ((h >> 7) & 1), 3 - fh)
			ci.draw_rect(Rect2(fp, Vector2(1, fh)), C_FLAME_O)
			ci.draw_rect(Rect2(fp + Vector2(0, fh - 1), Vector2.ONE), C_FLAME_Y)
		if age < SMOKE_T and sel % 17 == 1 and ns < MAX_SMOKE:
			ns += 1
			var a: float = (1.0 - age / SMOKE_T) * C_SMOKE.a
			var ph: float = fmod(tick * 3.0 + float(h & 15), 6.0)
			for k in 3:
				var yy: float = fmod(ph + float(k) * 2.0, 6.0)
				var c2: = Color(C_SMOKE.r, C_SMOKE.g, C_SMOKE.b, a * (1.0 - yy / 6.0))
				ci.draw_rect(Rect2(p + Vector2(1.0 + floorf(sin(yy + float(h & 7)) * 1.0), 1.0 - floorf(yy) * 2.0), Vector2.ONE), c2)
	if ne == 0 and nf == 0 and ns == 0 and now - _oldest() > SMOKE_T:
		_fresh.clear()


func _oldest() -> float:
	var t: float = -1000000000.0
	for e: Array in _fresh:
		t = maxf(t, float(e[2]))
	return t
