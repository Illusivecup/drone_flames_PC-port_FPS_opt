class_name DecalLayer
extends Node2D








const CHUNK: int = 32
const MAKE_PER_FRAME: int = 2
const T_GRASS: Array = ["tuft_g0", "tuft_g1", "tuft_g2", "tuft_g3"]
const T_FOREST: Array = ["tuft_f0", "tuft_f1", "tuft_f2"]
const T_DRY: Array = ["tuft_s0", "tuft_s1", "tuft_s2"]
const FLOWERS: Array = ["pink", "yellow", "white", "purple"]
const B_GRASS: Array = ["bush_s0", "bush_s1", "bush_s4", "bush_s1", "bush_s3"]
const B_FOREST: Array = ["bush_s2", "bush_s5", "bush_s3", "bush_s2", "bush_s1"]
const B_PINE: Array = ["bush_t0", "bush_s2", "bush_t0"]
const B_STEPPE: Array = ["dry_bush", "dry_bush", "bush_y0"]
const B_HILLS: Array = ["rock_s", "dry_bush", "bush_y0"]
const REEDS: Array = ["reed_a", "reed_b", "reed_c"]
const SCREE: Array = ["scree_a", "scree_b", "rock_s", "pebble_b"]


class Chunk:
	extends Node2D
	var layer: DecalLayer
	var cx: int = 0
	var cy: int = 0

	func _draw() -> void :
		layer.draw_chunk(self)


var gw: GameWorld
var tier: int = 0
var min_zoom: float = 2.0
var tex: Texture2D
var spr: Dictionary = {}
var cw: int = 0
var ch: int = 0
var chunks: Array = []
var live: Dictionary = {}
var _data: WorldData
var stats_drawn: int = 0
var stats_decals: int = 0
var stats_us: int = 0


static func make(world: GameWorld, tier_i: int) -> DecalLayer:
	var l: = DecalLayer.new()
	l.name = "Decals%d" % tier_i
	l.gw = world
	l.tier = tier_i
	l.min_zoom = 2.0 if tier_i == 0 else 1.0
	return l


func _ready() -> void :
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var a: SpriteAtlas = Flora.load_atlas()
	tex = a.texture
	for n: String in a.sprites:
		var s: Dictionary = a.sprites[n]
		spr[n] = [Rect2(float(s["x"]), float(s["y"]), float(s["w"]), float(s["h"])), float(s["ay"])]
	if gw.terrain != null and not gw.terrain.cells_changed.is_connected(_on_cells):
		gw.terrain.cells_changed.connect(_on_cells)


func _reset() -> void :
	for c: Node in live.values():
		c.queue_free()
	live.clear()
	chunks.clear()
	_data = gw.data
	if _data == null:
		return
	cw = (_data.w + CHUNK - 1) / CHUNK
	ch = (_data.h + CHUNK - 1) / CHUNK
	chunks.resize(cw * ch)


func _process(_d: float) -> void :
	if gw == null or gw.data == null or spr.is_empty():
		visible = false
		return
	if gw.data != _data:
		_reset()
	var cam: MapCamera = gw.camera
	if cam == null:
		visible = false
		return
	var z: float = cam.zoom.x
	visible = z >= min_zoom - 0.01 and GameConfig.ground_detail
	if not visible:
		return
	var half: Vector2 = cam.view_size() * 0.5 / z
	var tl: Vector2 = (cam.position - half) / 4.0
	var br: Vector2 = (cam.position + half) / 4.0
	var x0: int = clampi(int(tl.x) / CHUNK - 1, 0, cw - 1)
	var y0: int = clampi(int(tl.y) / CHUNK - 1, 0, ch - 1)
	var x1: int = clampi(int(br.x) / CHUNK + 1, 0, cw - 1)
	var y1: int = clampi(int(br.y) / CHUNK + 1, 0, ch - 1)
	var made: int = 0
	for j in range(y0, y1 + 1):
		for i in range(x0, x1 + 1):
			if chunks[j * cw + i] == null and made < MAKE_PER_FRAME:
				var c: = Chunk.new()
				c.layer = self
				c.cx = i
				c.cy = j
				add_child(c)
				chunks[j * cw + i] = c
				live[j * cw + i] = c
				made += 1

	if Engine.get_process_frames() % 30 == 0 and live.size() > (x1 - x0 + 5) * (y1 - y0 + 5):
		for k: int in live.keys():
			var i: int = k % cw
			var j: int = k / cw
			if i < x0 - 2 or i > x1 + 2 or j < y0 - 2 or j > y1 + 2:
				(live[k] as Node).queue_free()
				live.erase(k)
				chunks[k] = null


func _on_cells(cells: Array) -> void :
	if chunks.is_empty():
		return
	var seen: Dictionary = {}
	for c: Vector2i in cells:
		var k: int = clampi(c.y / CHUNK, 0, ch - 1) * cw + clampi(c.x / CHUNK, 0, cw - 1)
		if seen.has(k):
			continue
		seen[k] = true
		if chunks[k] != null:
			(chunks[k] as Node2D).queue_redraw()


func _put(ci: CanvasItem, n: String, x: int, y: int, r: int) -> void :
	var e: Array = spr[n]
	var src: Rect2 = e[0]
	var pos: = Vector2(float(x * 4 + (r & 3)), float(y * 4 + 3 + ((r >> 2) & 1)) - float(e[1]))
	if (r >> 5) & 1:
		ci.draw_texture_rect_region(tex, Rect2(pos + Vector2(src.size.x, 0.0), Vector2( - src.size.x, src.size.y)), src)
	else:
		ci.draw_texture_rect_region(tex, Rect2(pos, src.size), src)


func draw_chunk(ci: Chunk) -> void :
	var t0: int = Time.get_ticks_usec()
	var d: WorldData = gw.data
	if d == null or d != _data:
		return
	var tv: TerrainView = gw.terrain
	var w: int = d.w
	var rnd: PackedByteArray = tv._rnd
	if rnd.size() != 65536:
		return
	var oa: int = 37 + tier * 101
	var ob: int = 151 + tier * 59
	var n: int = 0
	var x0: int = ci.cx * CHUNK
	var y0: int = ci.cy * CHUNK
	var bio: PackedByteArray = d.biome
	var flags: PackedByteArray = d.flags
	for y in range(y0, mini(d.h, y0 + CHUNK)):
		for x in range(x0, mini(w, x0 + CHUNK)):
			var i: int = y * w + x
			if flags[i] != 0:
				continue
			var b: int = bio[i]
			var p: int = rnd[(((y + oa) & 255) << 8) | ((x * 3 + ob) & 255)]
			var r2: int = rnd[(((y * 5 + ob) & 255) << 8) | ((x + oa) & 255)] | (rnd[(((y + 77) & 255) << 8) | ((x * 7 + 3) & 255)] << 8)
			if b <= Biome.RIVER:
				if tier == 1 and p < 22 and b != Biome.RIVER and d.lake_at(x, y) == 1 and _adj_land(d, x, y):
					_put(ci, "lily_a" if (r2 & 1) == 0 else "lily_b", x, y, r2)
					n += 1
				continue
			if not Biome.is_natural_land(b) or gw.tree_at.has(i):
				continue
			if tier == 1:
				if b != Biome.SAND and b != Biome.HILLS and p < 46 and _adj_fresh(d, x, y):
					_put(ci, REEDS[r2 % 3], x, y, r2)
					n += 1
					continue
				if p < 40 and b != Biome.SAND and _adj_rock(d, x, y):
					_put(ci, SCREE[r2 % SCREE.size()], x, y, r2)
					n += 1
					continue
				if p >= 26:
					continue
				var bush_ch: int = 0
				var names: Array = B_GRASS
				match b:
					Biome.GRASS:
						bush_ch = 2 + maxi(0, tv._noise_at(1, x, y) - 150) / 6
					Biome.FOREST:
						bush_ch = 20
						names = B_FOREST
					Biome.PINE:
						bush_ch = 11
						names = B_PINE
					Biome.STEPPE:
						bush_ch = 5
						names = B_STEPPE
					Biome.HILLS:
						bush_ch = 8
						names = B_HILLS
				if p < bush_ch:
					_put(ci, names[r2 % names.size()], x, y, r2)
					n += 1
				continue

			match b:
				Biome.GRASS:
					if p >= 72:
						continue
					var big: int = tv._noise_at(0, x, y)
					var mid: int = tv._noise_at(1, x, y)
					var fl: int = (maxi(0, big - 130) / 5 + maxi(0, mid - 170) / 4) * 2 / 3
					if p < fl:
						var col: String = FLOWERS[((mid >> 5) + (big >> 6) + (r2 & 1)) % FLOWERS.size()]
						_put(ci, "flower_%s_%s" % [col, "a" if (r2 & 2) == 0 else "b"], x, y, r2)
						n += 1
					elif p < fl + 3 + maxi(0, 150 - big) / 6 + (mid & 15) * 2 / 3:
						_put(ci, T_GRASS[r2 % T_GRASS.size()], x, y, r2)
						n += 1
					elif p < fl + 4 + maxi(0, 150 - big) / 6 + (mid & 15) * 2 / 3:
						_put(ci, "pebble_a" if (r2 & 1) == 0 else "pebble_c", x, y, r2)
						n += 1
				Biome.FOREST, Biome.PINE:
					if p < 20:
						_put(ci, T_FOREST[r2 % T_FOREST.size()], x, y, r2)
						n += 1
					elif p < 23 and b == Biome.FOREST:
						_put(ci, "flower_white_b" if (r2 & 1) == 0 else "flower_yellow_b", x, y, r2)
						n += 1
				Biome.STEPPE:
					if p < 4 + maxi(0, tv._noise_at(1, x, y) - 120) / 9:
						_put(ci, T_DRY[r2 % T_DRY.size()], x, y, r2)
						n += 1
					elif p >= 200 and p < 202:
						_put(ci, "pebble_b" if (r2 & 1) == 0 else "pebble_a", x, y, r2)
						n += 1
					elif p >= 202 and p < 204:
						_put(ci, "flower_yellow_b", x, y, r2)
						n += 1
				Biome.HILLS:
					if p < 6:
						_put(ci, "pebble_b" if (r2 & 1) == 0 else "pebble_a", x, y, r2)
						n += 1
					elif p < 12:
						_put(ci, T_DRY[r2 % T_DRY.size()], x, y, r2)
						n += 1
				Biome.SAND:
					if p < 3:
						_put(ci, "shell_a", x, y, r2)
						n += 1
					elif p < 4:
						_put(ci, "pebble_c", x, y, r2)
						n += 1
					elif p < 5:
						_put(ci, "drift_a", x, y, r2)
						n += 1
	stats_drawn += 1
	stats_decals += n
	stats_us += Time.get_ticks_usec() - t0


static func _adj_land(d: WorldData, x: int, y: int) -> bool:
	for k in 4:
		var qx: int = x + (1 if k == 0 else (-1 if k == 1 else 0))
		var qy: int = y + (1 if k == 2 else (-1 if k == 3 else 0))
		if d.inside(qx, qy) and d.biome[qy * d.w + qx] > Biome.RIVER:
			return true
	return false


static func _adj_fresh(d: WorldData, x: int, y: int) -> bool:
	for k in 4:
		var qx: int = x + (1 if k == 0 else (-1 if k == 1 else 0))
		var qy: int = y + (1 if k == 2 else (-1 if k == 3 else 0))
		if not d.inside(qx, qy):
			continue
		var qb: int = d.biome[qy * d.w + qx]
		if qb == Biome.RIVER or (qb <= Biome.COAST and not d.lakes.is_empty() and d.lake_at(qx, qy) != 0):
			return true
	return false


static func _adj_rock(d: WorldData, x: int, y: int) -> bool:
	for k in 4:
		var qx: int = x + (1 if k == 0 else (-1 if k == 1 else 0))
		var qy: int = y + (1 if k == 2 else (-1 if k == 3 else 0))
		if d.inside(qx, qy):
			var qb: int = d.biome[qy * d.w + qx]
			if qb == Biome.ROCK or qb == Biome.SNOW:
				return true
	return false
