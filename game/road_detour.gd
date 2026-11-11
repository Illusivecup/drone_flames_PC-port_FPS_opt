extends RefCounted









const MAX_EXTRA: int = 40
const WIN: int = 10
const EXT: int = 3





static func plan(gw: GameWorld, rect: Rect2i, apply: bool) -> int:
	var r: int = _plan(gw, rect, apply, 2)
	if r == -2 or r == -4 or r == -5:
		r = _plan(gw, rect, apply, 1)
	return r


static func _plan(gw: GameWorld, rect: Rect2i, apply: bool, clr: int) -> int:
	var d: WorldData = gw.data
	var W: int = d.w
	var any: bool = false
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not d.inside(x, y):
				return -6
			var f: int = d.flags[y * W + x]
			if (f & WorldData.F_ROAD) != 0:
				if (f & (WorldData.F_CITY | WorldData.F_BRIDGE)) != 0:
					return -1
				any = true
	if not any:
		return 0
	var zone: Rect2i = rect.grow(clr)
	var cuts: Array = []
	var covered: Dictionary = {}
	for pi in gw.road_paths.size():
		var path: Array = gw.road_paths[pi]
		var i0: int = -1
		var i1: int = -1
		var on_fp: bool = false
		for k in path.size():
			var c: Vector2i = path[k]
			if zone.has_point(c):
				if i0 < 0:
					i0 = k
				i1 = k
				if rect.has_point(c):
					on_fp = true
					covered[c] = true
		if not on_fp:
			continue
		if i0 == 0 or i1 == path.size() - 1:
			return -2
		for e in EXT:
			var c0: Vector2i = path[i0 - 1]
			if i0 <= 1 or d.has_flag(c0.x, c0.y, WorldData.F_BRIDGE | WorldData.F_CITY):
				break
			i0 -= 1
		for e2 in EXT:
			var c1: Vector2i = path[i1 + 1]
			if i1 >= path.size() - 2 or d.has_flag(c1.x, c1.y, WorldData.F_BRIDGE | WorldData.F_CITY):
				break
			i1 += 1
		cuts.append([pi, i0, i1])
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if (d.flags[y * W + x] & WorldData.F_ROAD) != 0 and not covered.has(Vector2i(x, y)):
				return -3
	var dets: Array = []
	for cut: Array in cuts:
		var path2: Array = gw.road_paths[int(cut[0])]
		var skip: Dictionary = {}
		for k in range(int(cut[1]), int(cut[2]) + 1):
			skip[path2[k]] = true
		var det: Array[Vector2i] = _astar(gw, path2[int(cut[1]) - 1], path2[int(cut[2]) + 1], zone, skip)
		if det.is_empty():
			return -4
		if det.size() > int(cut[2]) - int(cut[1]) + 3 + MAX_EXTRA:
			return -5
		dets.append(det)
	if not apply:
		return cuts.size()

	var removed: Dictionary = {}
	var changed: Array[Vector2i] = []
	for j in cuts.size():
		var pi2: int = int(cuts[j][0])
		var i0b: int = int(cuts[j][1])
		var i1b: int = int(cuts[j][2])
		var old: Array = gw.road_paths[pi2]
		var det2: Array[Vector2i] = dets[j]
		var np: Array[Vector2i] = []
		for k in range(0, i0b):
			np.append(old[k])
		for k in range(1, det2.size() - 1):
			np.append(det2[k])
		for k in range(i1b + 1, old.size()):
			np.append(old[k])
		for k in range(i0b, i1b + 1):
			removed[old[k]] = true
		gw.road_paths[pi2] = np
		for k in range(1, det2.size() - 1):
			var c2: Vector2i = det2[k]
			var bb: int = d.get_biome(c2.x, c2.y)
			if bb != Biome.STREET and bb != Biome.ROAD:
				d.set_biome(c2.x, c2.y, Biome.ROAD)
			if not d.has_flag(c2.x, c2.y, WorldData.F_ROAD):
				d.add_flag(c2.x, c2.y, WorldData.F_ROAD)
				changed.append(c2)
			gw.remove_tree_at(c2)
	var used: Dictionary = {}
	for path3: Array in gw.road_paths:
		for c3: Vector2i in path3:
			if removed.has(c3):
				used[c3] = true
	var cells: Array = removed.keys()
	cells.sort()
	for c4: Vector2i in cells:
		if used.has(c4) or d.has_flag(c4.x, c4.y, WorldData.F_CITY | WorldData.F_BRIDGE):
			continue
		d.clear_flag(c4.x, c4.y, WorldData.F_ROAD)
		if d.get_biome(c4.x, c4.y) == Biome.ROAD:
			d.set_biome(c4.x, c4.y, _ground(d, c4))
		changed.append(c4)
	if gw.econ != null and gw.econ.nav != null:
		gw.econ.nav_open(changed)
	gw._checkpoints_dirty = true
	if gw.get("ai") != null and gw.ai.get("guard") != null:
		gw.ai.guard._g_sig = []
	return cuts.size()





static func _astar(gw: GameWorld, a: Vector2i, b: Vector2i, zone: Rect2i, skip: Dictionary) -> Array[Vector2i]:
	var d: WorldData = gw.data
	var W: int = d.w
	var none: Array[Vector2i] = []
	var win: Rect2i = zone.merge(Rect2i(a, Vector2i.ONE)).merge(Rect2i(b, Vector2i.ONE)).grow(WIN).intersection(Rect2i(1, 1, W - 2, d.h - 2))
	if not win.has_point(a) or not win.has_point(b):
		return none
	var rm: PackedByteArray = gw.rail.mask if gw.rail != null else PackedByteArray()
	var astar: = AStarGrid2D.new()
	astar.region = win
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	var fla: PackedByteArray = d.flags
	var bia: PackedByteArray = d.biome
	var ring: Rect2i = zone.grow(1)
	for y in range(win.position.y, win.end.y):
		for x in range(win.position.x, win.end.x):
			var q: = Vector2i(x, y)
			var i: int = y * W + x
			var fl: int = fla[i]
			var bi: int = bia[i]
			if zone.has_point(q):
				astar.set_point_solid(q, true)
				continue
			var cost: float
			if (fl & WorldData.F_ROAD) != 0 and not skip.has(q):
				cost = 1.0
			elif (fl & WorldData.F_OCCUPIED) != 0 or ((fl & WorldData.F_BRIDGE) != 0 and not skip.has(q)) or Biome.is_water(bi):
				astar.set_point_solid(q, true)
				continue
			else:
				cost = 2.5 if bi == Biome.ROAD or bi == Biome.STREET else Biome.road_cost(bi)
				if cost < 0.0:
					astar.set_point_solid(q, true)
					continue
				if i < rm.size() and rm[i] != 0:
					cost += 6.0
			if ring.has_point(q):
				cost += 1.5
			astar.set_point_weight_scale(q, cost)
	if astar.is_point_solid(a) or astar.is_point_solid(b):
		return none
	var path: Array[Vector2i] = astar.get_id_path(a, b)
	if path.is_empty():
		return none
	var out: Array[Vector2i] = [path[0]]
	for k in range(1, path.size()):
		var pv: Vector2i = path[k - 1]
		var c: Vector2i = path[k]
		if pv.x != c.x and pv.y != c.y:
			var m1: = Vector2i(c.x, pv.y)
			out.append(m1 if not astar.is_point_solid(m1) else Vector2i(pv.x, c.y))
		out.append(c)
	return out



static func _ground(d: WorldData, c: Vector2i) -> int:
	var cnt: Dictionary = {}
	for r in [1, 2, 3]:
		for dy in range( - r, r + 1):
			for dx in range( - r, r + 1):
				if maxi(absi(dx), absi(dy)) != r or not d.inside(c.x + dx, c.y + dy):
					continue
				var b: int = d.get_biome(c.x + dx, c.y + dy)
				if Biome.is_natural_land(b):
					cnt[b] = int(cnt.get(b, 0)) + 1
		if not cnt.is_empty():
			break
	var best: int = Biome.GRASS
	var bn: int = 0
	for b2: int in [Biome.SAND, Biome.GRASS, Biome.FOREST, Biome.PINE, Biome.STEPPE, Biome.HILLS, Biome.FIELD, Biome.BURNT]:
		if int(cnt.get(b2, 0)) > bn:
			bn = int(cnt.get(b2, 0))
			best = b2
	return best if best != Biome.FOREST and best != Biome.PINE else Biome.GRASS
