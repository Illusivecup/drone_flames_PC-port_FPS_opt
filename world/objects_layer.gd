class_name ObjectsLayer
extends Node2D


var gw: GameWorld
var chunk_cells: int = 32
var cw: int = 0
var ch: int = 0
var chunks: Array[ObjChunk] = []
var sway_enabled: bool = true
var _sway_t: float = 0.0
var _cursor: int = 0
var cover_ver: int = 0
const GUEST_BUDGET: int = 3
var _cull_box: Vector4i = Vector4i(-999, -999, -999, -999)


func setup(game_world: GameWorld) -> void :
	gw = game_world
	for c in chunks:



		c.gw = null
		c.ids = PackedInt32Array()
		remove_child(c)
		c.queue_free()
	chunks.clear()
	chunk_cells = 32 if gw.data.w <= 1024 else 64
	cw = (gw.data.w + chunk_cells - 1) / chunk_cells
	ch = (gw.data.h + chunk_cells - 1) / chunk_cells
	for j in ch:
		for i in cw:
			var node: = ObjChunk.new()
			node.gw = gw
			node.name = "C%d_%d" % [i, j]
			add_child(node)
			chunks.append(node)
	for j in ch:
		for i in cw:
			var c: ObjChunk = chunks[j * cw + i]
			c.idx = j * cw + i
			c.left = chunks[j * cw + i - 1] if i > 0 else null
			c.right = chunks[j * cw + i + 1] if i + 1 < cw else null
	_tops.clear()


func chunk_at_cell(x: int, y: int) -> ObjChunk:
	var cx: int = clampi(x / chunk_cells, 0, cw - 1)
	var cy: int = clampi(y / chunk_cells, 0, ch - 1)
	return chunks[cy * cw + cx]



func chunks_in_rect(r: Rect2i) -> Array[ObjChunk]:
	var out: Array[ObjChunk] = []
	var x0: int = clampi(r.position.x / chunk_cells, 0, cw - 1)
	var y0: int = clampi(r.position.y / chunk_cells, 0, ch - 1)
	var x1: int = clampi((r.position.x + r.size.x) / chunk_cells, 0, cw - 1)
	var y1: int = clampi((r.position.y + r.size.y) / chunk_cells, 0, ch - 1)
	for j in range(y0, y1 + 1):
		for i in range(x0, x1 + 1):
			out.append(chunks[j * cw + i])
	return out


func _process(delta: float) -> void :
	if gw == null or not visible or chunks.is_empty():
		return
	_sway_t += delta
	if _sway_t < 0.12:
		return
	_sway_t = 0.0

	var cam: MapCamera = gw.camera
	if cam == null:
		return
	var half: Vector2 = cam.view_size() * 0.5 / cam.zoom.x
	var tl: Vector2 = (cam.position - half) / 4.0
	var br: Vector2 = (cam.position + half) / 4.0

	# Chunk Frustum Culling
	var do_cull: bool = GameConfig.eff_chunk_culling()
	if do_cull:
		var x0: int = clampi(int(floorf(tl.x / float(chunk_cells))) - 1, 0, cw - 1)
		var y0: int = clampi(int(floorf(tl.y / float(chunk_cells))) - 1, 0, ch - 1)
		var x1: int = clampi(int(floorf(br.x / float(chunk_cells))) + 1, 0, cw - 1)
		var y1: int = clampi(int(floorf(br.y / float(chunk_cells))) + 1, 0, ch - 1)
		var box: Vector4i = Vector4i(x0, y0, x1, y1)
		if box != _cull_box:
			_cull_box = box
			for j in ch:
				for i in cw:
					var c: ObjChunk = chunks[j * cw + i]
					var in_v: bool = i >= x0 and i <= x1 and j >= y0 and j <= y1
					if c.visible != in_v:
						c.visible = in_v
	elif _cull_box != Vector4i(-999, -999, -999, -999):
		_cull_box = Vector4i(-999, -999, -999, -999)
		for c: ObjChunk in chunks:
			if not c.visible:
				c.visible = true

	var budget: int = GUEST_BUDGET
	for c: ObjChunk in chunks_in_rect(Rect2i(Vector2i(tl) - Vector2i(chunk_cells, chunk_cells), Vector2i(br - tl) + Vector2i(chunk_cells, chunk_cells) * 2)):
		if c.need_guests and budget > 0:
			budget -= 1
			c.need_guests = false
			c.sorted = false
			c.queue_redraw()

	var sway_mode: int = GameConfig.eff_tree_sway_mode()
	var sway_ok: bool = sway_enabled and sway_mode != 0
	if sway_mode == 1 and cam.zoom.x < 0.8:
		sway_ok = false
	if not sway_ok:
		return
	var vis: Array[ObjChunk] = chunks_in_rect(Rect2i(Vector2i(tl), Vector2i(br - tl)))
	if vis.is_empty():
		return
	for k in 3:
		_cursor = (_cursor + 1) % vis.size()
		var c: ObjChunk = vis[_cursor]
		c.phase += 1
		c.queue_redraw()
		if c.right != null and not c.right.guests.is_empty():
			c.right.queue_redraw()



func near_view(c: ObjChunk) -> bool:
	var cam: MapCamera = gw.camera if gw != null else null
	if cam == null:
		return false
	var i: int = c.idx % cw
	var j: int = c.idx / cw
	var half: Vector2 = cam.view_size() * 0.5 / cam.zoom.x
	var tl: Vector2 = (cam.position - half) / 4.0 / float(chunk_cells)
	var br: Vector2 = (cam.position + half) / 4.0 / float(chunk_cells)
	return i >= int(floor(tl.x)) - 1 and i <= int(floor(br.x)) + 1 and j >= int(floor(tl.y)) - 1 and j <= int(floor(br.y)) + 1




var _tops: Dictionary = {}
var _imgs: Dictionary = {}




func column_tops(s: int, ox: int, oy: int, x0: int, x1: int, base: int) -> PackedInt32Array:
	var rel: PackedInt32Array = _sprite_tops(s)
	var out: = PackedInt32Array()
	out.resize(x1 - x0)
	for i in x1 - x0:
		var c: int = x0 + i - ox
		var t: int = rel[c] if c >= 0 and c < rel.size() else -1
		out[i] = oy + t if t >= 0 else base
	return out


func _sprite_tops(s: int) -> PackedInt32Array:
	if _tops.has(s):
		return _tops[s]
	var gw2: GameWorld = gw
	var r: Rect2i = Rect2i(gw2.spr_rect[s])
	var out: = PackedInt32Array()
	out.resize(r.size.x)
	out.fill(-1)
	var tex: Texture2D = gw2.spr_tex[s]
	var img: Image = null
	if tex != null and not (tex is PlaceholderTexture2D):
		var k: int = tex.get_rid().get_id()
		if not _imgs.has(k):
			var im: Image = tex.get_image()
			if im != null and im.is_compressed():
				im.decompress()
			_imgs[k] = im
		img = _imgs[k]
	if img != null:
		for x in r.size.x:
			for y in r.size.y:
				if img.get_pixel(r.position.x + x, r.position.y + y).a > 0.5:
					out[x] = y
					break
	_tops[s] = out
	return out




func cover_span(x0: int, w: int, foot: int) -> PackedInt32Array:
	var out: = PackedInt32Array()
	if chunks.is_empty() or w <= 0:
		return out
	var cy: int = foot / GameWorld.CELL
	var c0: int = x0 / GameWorld.CELL
	var c1: int = (x0 + w - 1) / GameWorld.CELL
	var j: int = clampi(cy / chunk_cells, 0, ch - 1)
	var i0: int = clampi(c0 / chunk_cells - 1, 0, cw - 1)
	var i1: int = clampi(c1 / chunk_cells, 0, cw - 1)
	for jj in range(j, mini(j + 2, ch)):
		for ii in range(i0, i1 + 1):
			var m: Dictionary = chunks[jj * cw + ii].cover_map()
			if m.is_empty():
				continue
			for cx in range(c0, c1 + 1):
				if not m.has(cx):
					continue
				for e: Array in m[cx]:
					if int(e[2]) <= foot:
						continue
					var ex0: int = int(e[0])
					var tops: PackedInt32Array = e[3]
					for k in w:
						var xi: int = x0 + k - ex0
						if xi < 0 or xi >= tops.size():
							continue
						var t: int = tops[xi]
						if t >= int(e[2]):
							continue
						if out.is_empty():
							out.resize(w)
							out.fill(1 << 30)
						if t < out[k]:
							out[k] = t
	return out





func cover_top(x: int, foot: int) -> int:
	var best: int = 1 << 30
	if chunks.is_empty():
		return best
	var cx: int = x / GameWorld.CELL
	var cy: int = foot / GameWorld.CELL
	var i: int = clampi(cx / chunk_cells, 0, cw - 1)
	var j: int = clampi(cy / chunk_cells, 0, ch - 1)
	for jj in range(j, mini(j + 2, ch)):
		for ii in range(maxi(0, i - 1), mini(i + 1, cw - 1) + 1):
			var m: Dictionary = chunks[jj * cw + ii].cover_map()
			if not m.has(cx):
				continue
			for e: Array in m[cx]:
				if int(e[2]) <= foot or int(e[4]) >= best:
					continue
				var xi: int = x - int(e[0])
				if xi < 0 or xi >= int(e[1]) - int(e[0]):
					continue
				var t: int = (e[3] as PackedInt32Array)[xi]
				if t < best and t < int(e[2]):
					best = t
	return best
