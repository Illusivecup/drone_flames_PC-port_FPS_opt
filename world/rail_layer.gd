class_name RailLayer
extends Node2D





const CK: int = 128
const PASSES: int = 5

var rail: Rail
var items: Array = []
var chunks: Dictionary = {}
var chunk_items: Dictionary = {}
var _dirty: Dictionary = {}
var _bridges_dirty: bool = true
var _br_t: float = 0.0
var _sea_seen: int = 0
var _sig: Dictionary = {}
var col: Dictionary = {}


func setup(r: Rail) -> void :
	rail = r
	items.clear()
	chunks.clear()
	chunk_items.clear()
	_dirty.clear()
	_sig.clear()
	_sea_seen = 0
	_bridges_dirty = true
	for n: String in ["rock", "rock_dark", "rock_deep", "rock_light", "earth", "earth_dark", "wood", "wood_light", "concrete_light", 
			"concrete", "concrete_dark", "asphalt", "asphalt_dark", "water_deep", "ui_steel", "ui_steel_light", "ui_steel_dark", "smoke_black", "snow_shade", 
			"earth_light", "white", "fire_red", "sand_dark"]:
		col[n] = Palette.c(n)
	queue_redraw()


func add_item(it: Dictionary) -> void :
	var s: PackedVector2Array = it["s"]
	if s.size() < 2:
		return
	it["dead"] = false
	if not it.has("bb"):
		_bridge_samples(it)

	var ranges: Dictionary = {}
	for k in s.size():
		var p: Vector2 = s[k]
		for oy: int in [-8, 8]:
			for ox: int in [-8, 8]:
				var key: = Vector2i(floori((p.x + ox) / CK), floori((p.y + oy) / CK))
				if ranges.has(key):
					var r: Vector2i = ranges[key]
					ranges[key] = Vector2i(mini(r.x, k), maxi(r.y, k))
				else:
					ranges[key] = Vector2i(k, k)
	it["ranges"] = ranges
	var idx: int = items.size()
	items.append(it)
	for key: Vector2i in ranges:
		if not chunk_items.has(key):
			chunk_items[key] = []
		(chunk_items[key] as Array).append(idx)
		_dirty[key] = true



func _bridge_samples(it: Dictionary) -> void :
	var s: PackedVector2Array = it["s"]
	var bb: = PackedInt32Array()
	var bc: = PackedInt32Array()
	bb.resize(s.size())
	bc.resize(s.size())
	bb.fill(-1)
	var brs: Array = []
	if int(it["type"]) == 0:
		var e: Dictionary = rail.edges[int(it["edge"])]
		var w: PackedByteArray = it["w"]
		for j in (e["br"] as Array).size():
			var ent: Array = e["br"][j]
			var b: Bridge = ent[0]
			brs.append(b)
			for k in range(maxi(0, int(ent[1])), mini(s.size(), int(ent[2]) + 1)):
				if w[k] == 1:
					bb[k] = j
					bc[k] = b.cell_at_px(s[k])
	elif int(it["type"]) == 2:
		var b2: Bridge = it["bridge"]
		brs.append(b2)
		for k in s.size():
			bb[k] = 0
			bc[k] = b2.cell_at_px(s[k])
	it["bb"] = bb
	it["bc"] = bc
	it["brs"] = brs


func remove_edge_items(eid: int) -> void :
	for i in items.size():
		var it: Dictionary = items[i]
		if int(it["type"]) == 0 and int(it.get("edge", -1)) == eid and not bool(it["dead"]):
			it["dead"] = true
			for key: Vector2i in it["ranges"]:
				_dirty[key] = true



func mark_edge(eid: int) -> void :
	for it: Dictionary in items:
		if int(it["type"]) == 0 and int(it.get("edge", -1)) == eid and not bool(it["dead"]):
			for key: Vector2i in it["ranges"]:
				_dirty[key] = true


func mark_rect(r: Rect2) -> void :
	for y in range(floori(r.position.y / CK), floori(r.end.y / CK) + 1):
		for x in range(floori(r.position.x / CK), floori(r.end.x / CK) + 1):
			var key: = Vector2i(x, y)
			if chunk_items.has(key):
				_dirty[key] = true


func mark_all_bridges() -> void :
	_bridges_dirty = true


func tick(dt: float) -> void :
	_br_t += dt
	if _bridges_dirty and _br_t >= 0.2:
		_br_t = 0.0
		_bridges_dirty = false
		_sync_bridges()
	if _dirty.is_empty():
		return
	var n: int = 0
	var added: bool = false
	for key: Vector2i in _dirty.keys():
		if not chunks.has(key):
			added = true
		_raster(key)
		_dirty.erase(key)
		n += 1
		if n >= 3:
			break
	if added:
		queue_redraw()



func _sync_bridges() -> void :
	var gw: GameWorld = rail.gw
	while _sea_seen < gw.bridges.size():
		var b: Bridge = gw.bridges[_sea_seen]
		_sea_seen += 1
		if b.kind == Bridge.Kind.SEA and b.pts.size() >= 2:
			var s: PackedVector2Array = Rail._resample(b.pts, 1.0)
			add_item({"type": 2, "s": s, "n": Rail._normals(s), "bridge": b})
	for i in items.size():
		var it: Dictionary = items[i]
		if bool(it["dead"]):
			continue
		for b2: Bridge in it["brs"]:
			var sig: int = b2.state * 100000
			if b2.state == Bridge.State.REBUILDING:
				for c in b2.cells.size():
					sig += b2.view(c) * (c + 1) * 7
			var oid: int = b2.get_instance_id()
			if int(_sig.get(oid, -1)) != sig:
				_sig[oid] = sig
				for key: Vector2i in it["ranges"]:
					_dirty[key] = true


func _draw() -> void :
	for key: Vector2i in chunks:
		draw_texture((chunks[key] as Array)[1], Vector2(key * CK))


func _raster(key: Vector2i) -> void :
	var img: Image
	if chunks.has(key):
		img = (chunks[key] as Array)[0]
		img.fill(Color(0, 0, 0, 0))
	else:
		img = Image.create(CK, CK, false, Image.FORMAT_RGBA8)
	var org: = Vector2(key * CK)
	var list: Array = chunk_items.get(key, [])
	var t: float = rail.gw.game_time
	for ps in PASSES:
		for ii: int in list:
			var it: Dictionary = items[ii]
			if bool(it["dead"]):
				continue
			var r: Vector2i = (it["ranges"] as Dictionary).get(key, Vector2i(0, -1))
			match int(it["type"]):
				0, 1:
					_rail_pass(img, org, it, r, ps, t)
				2:
					_road_bridge_pass(img, org, it, r, ps)
	if chunks.has(key):
		((chunks[key] as Array)[1] as ImageTexture).update(img)
	else:
		chunks[key] = [img, ImageTexture.create_from_image(img)]


func _put(img: Image, q: Vector2, c: Color) -> void :
	var x: int = floori(q.x)
	var y: int = floori(q.y)
	if x >= 0 and y >= 0 and x < CK and y < CK:
		img.set_pixel(x, y, c)


func _box(img: Image, q: Vector2, r: int, c: Color) -> void :
	img.fill_rect(Rect2i(floori(q.x) - r, floori(q.y) - r, r * 2 + 1, r * 2 + 1), c)




func _rail_pass(img: Image, org: Vector2, it: Dictionary, r: Vector2i, ps: int, t: float) -> void :
	var s: PackedVector2Array = it["s"]
	var nn: PackedVector2Array = it["n"]
	var bb: PackedInt32Array = it["bb"]
	var bc: PackedInt32Array = it["bc"]
	var brs: Array = it["brs"]
	var cuts: Array = []
	var kb: float = INF
	if int(it["type"]) == 0:
		var e0: Dictionary = rail.edges[int(it["edge"])]
		for c: Array in e0["cuts"]:
			if float(c[1]) > t:
				cuts.append(float(c[0]))
		if float(e0.get("bt", 0.0)) > 0.0:
			kb = rail.built_frac(e0) * float(s.size() - 1)
	if kb < INF and ps != 4:
		_works_pass(img, org, it, r, ps, kb)
		if float(r.x) > kb:
			return
		r = Vector2i(r.x, mini(r.y, floori(kb)))
	if ps == 4:
		for cs: float in cuts:
			var k: int = clampi(int(cs), 0, s.size() - 1)
			if k < r.x - 8 or k > r.y + 8:
				continue
			var q: Vector2 = s[k] - org
			var n: Vector2 = nn[k]
			_box(img, q, 2, col["earth_dark"])
			_box(img, q, 1, col["smoke_black"])
			var tg: = Vector2(n.y, - n.x)
			_put(img, q + n * 3.0 + tg * 2.0, col["concrete_light"])
			_put(img, q + n * 3.5 + tg * 3.0, col["concrete_light"])
			_put(img, q - n * 3.0 - tg * 2.0, col["concrete_light"])
			_put(img, q - n * 3.5 - tg * 1.0, col["rock_light"])
		return
	for k in range(r.x, r.y + 1):
		var q: Vector2 = s[k] - org
		var n: Vector2 = nn[k]
		var bi: int = bb[k]
		var view: int = 0
		if bi >= 0:
			view = (brs[bi] as Bridge).view(bc[k])
		match ps:
			0:
				if bi >= 0:
					_box(img, q + Vector2(3, 5), 2, col["water_deep"])
					if k % 12 == 0:
						for j in range(-4, 5):
							_put(img, q + n * float(j) + Vector2(0, 1), col["rock_dark"])
						img.fill_rect(Rect2i(floori(q.x) - 1, floori(q.y) + 1, 2, 5), col["rock_dark"])
						img.fill_rect(Rect2i(floori(q.x) + 1, floori(q.y) + 2, 1, 4), col["rock_deep"])
			1:
				if bi < 0:
					_box(img, q, 2, col["rock_dark"])
				elif view == 0:
					_box(img, q, 2, col["rock_deep"])
				elif view == 2:
					_box(img, q, 1, col["wood"])
			2:
				if bi < 0:
					_box(img, q, 1, col["rock"])
					if k % 3 == 0:
						for j in range(-2, 3):
							_put(img, q + n * float(j), col["earth"])
				elif view == 0:
					_put(img, q + n * 2.6, col["ui_steel_light"])
					_put(img, q - n * 2.6, col["ui_steel"])
					if k % 3 == 0:
						for j in range(-1, 2):
							_put(img, q + n * float(j), col["wood"])
					if k % 4 == 0:
						_put(img, q + n * 2.0, col["ui_steel_dark"])
				elif view == 2 and k % 3 == 0:
					_put(img, q + n * 2.0, col["wood_light"])
					_put(img, q - n * 2.0, col["wood_light"])
			3:
				if bi >= 0 and view != 0:
					continue
				var cut: bool = false
				for cs: float in cuts:
					if absf(float(k) - cs) < 4.0:
						cut = true
						break
				if cut:
					continue
				_put(img, q + n * 1.5, col["concrete_light"])
				_put(img, q - n * 1.5, col["concrete"])





const SLEEPERS: float = 14.0


func _works_pass(img: Image, org: Vector2, it: Dictionary, r: Vector2i, ps: int, kb: float) -> void :
	var s: PackedVector2Array = it["s"]
	var nn: PackedVector2Array = it["n"]
	var bb: PackedInt32Array = it["bb"]
	for k in range(maxi(r.x, ceili(kb)), r.y + 1):
		var q: Vector2 = s[k] - org
		var n: Vector2 = nn[k]
		var lay: bool = float(k) - kb <= SLEEPERS
		if bb[k] >= 0:
			if ps == 0 and k % 12 == 0:
				for j in range(-4, 5):
					_put(img, q + n * float(j) + Vector2(0, 1), col["rock_dark"])
				img.fill_rect(Rect2i(floori(q.x) - 1, floori(q.y) + 1, 2, 5), col["rock_dark"])
			continue
		match ps:
			1:
				_box(img, q, 2, col["earth_dark"] if lay else col["earth"])
			2:
				if lay:
					_box(img, q, 1, col["rock"])
					if k % 3 == 0:
						for j in range(-2, 3):
							_put(img, q + n * float(j), col["wood"])
				else:
					_box(img, q, 1, col["earth_light"])
					if k % 4 == 0:
						_put(img, q + n * 2.0, col["sand_dark"])
						_put(img, q - n * 2.0, col["sand_dark"])
			3:
				if not lay and k % 24 == 12:
					_put(img, q + n * 4.0, col["white"])
					_put(img, q + n * 4.0 + Vector2(0, -1), col["fire_red"])
					_put(img, q - n * 4.0, col["white"])
					_put(img, q - n * 4.0 + Vector2(0, -1), col["fire_red"])




func _road_bridge_pass(img: Image, org: Vector2, it: Dictionary, r: Vector2i, ps: int) -> void :
	if ps == 4:
		return
	var s: PackedVector2Array = it["s"]
	var nn: PackedVector2Array = it["n"]
	var bc: PackedInt32Array = it["bc"]
	var b: Bridge = it["bridge"]
	if b.cells.is_empty():
		return
	for k in range(r.x, r.y + 1):
		var q: Vector2 = s[k] - org
		var n: Vector2 = nn[k]
		var view: int = b.view(bc[k])
		match ps:
			0:
				_box(img, q + Vector2(3, 5), 2, col["water_deep"])
				if k % 14 == 7:

					for j in range(-5, 6):
						_put(img, q + n * float(j) + Vector2(0, 1), col["concrete"])
						_put(img, q + n * float(j) + Vector2(0, 2), col["concrete_dark"])
					img.fill_rect(Rect2i(floori(q.x) - 1, floori(q.y) + 2, 3, 6), col["concrete"])
					img.fill_rect(Rect2i(floori(q.x) + 1, floori(q.y) + 3, 1, 5), col["concrete_dark"])
			1:
				if view == 0:
					_box(img, q, 3, col["rock_dark"])
				elif view == 2:
					_box(img, q, 2, col["wood"])
			2:
				if view == 0:
					_box(img, q, 2, col["concrete"])
					_box(img, q, 1, col["asphalt"])
				elif view == 2 and k % 3 == 0:
					_put(img, q + n * 2.0, col["wood_light"])
					_put(img, q - n * 2.0, col["wood_light"])
					_put(img, q, col["wood_light"])
			3:
				if view == 0:
					_put(img, q - n * 3.0, col["concrete_light"])
					_put(img, q + n * 3.0, col["snow_shade"])
					if k % 8 < 3:
						_put(img, q, col["concrete_light"])
