class_name WorldGen2
extends RefCounted










const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const ST: int = 4
const FP: int = 256

const SIN4096: Array[int] = [0, 71, 143, 214, 286, 357, 428, 499, 570, 641, 711, 782, 852, 921, 991, 1060, 1129, 1198, 1266, 1334, 1401, 1468, 1534, 1600, 1666, 1731, 1796, 1860, 1923, 1986, 2048, 2110, 2171, 2231, 2290, 2349, 2408, 2465, 2522, 2578, 2633, 2687, 2741, 2793, 2845, 2896, 2946, 2996, 3044, 3091, 3138, 3183, 3228, 3271, 3314, 3355, 3396, 3435, 3474, 3511, 3547, 3582, 3617, 3650, 3681, 3712, 3742, 3770, 3798, 3824, 3849, 3873, 3896, 3917, 3937, 3956, 3974, 3991, 4006, 4021, 4034, 4046, 4056, 4065, 4074, 4080, 4086, 4090, 4094, 4095, 4096]

const FX_RAPID: int = 1
const FX_FALL: int = 2
const FX_FALL_EDGE: int = 3
const FX_POOL: int = 4
const FX_FALL_H: int = 5

static var last_ms: int = 0



static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x: int = int(sqrt(float(n)))
	while x * x > n:
		x -= 1
	while (x + 1) * (x + 1) <= n:
		x += 1
	return x



static func isin(deg: int) -> int:
	var d: int = posmod(deg, 360)
	if d <= 90:
		return SIN4096[d]
	if d <= 180:
		return SIN4096[180 - d]
	if d <= 270:
		return - SIN4096[d - 180]
	return - SIN4096[360 - d]


static func icos(deg: int) -> int:
	return isin(deg + 90)



static func inorm(v: Vector2i) -> Vector2i:
	var l: int = isqrt(v.x * v.x + v.y * v.y)
	if l == 0:
		return Vector2i(FP, 0)
	return Vector2i(v.x * FP / l, v.y * FP / l)


static func idist(a: Vector2i, b: Vector2i) -> int:
	var dx: int = a.x - b.x
	var dy: int = a.y - b.y
	return isqrt(dx * dx + dy * dy)


static func rivers(world: WorldData, s: WorldSettings, hills_thr: int, snow_thr: int) -> void :
	var t0: int = Time.get_ticks_msec()
	if s.rivers <= 0 and s.lakes <= 0:
		return
	var w: int = world.w
	var cw: int = w / ST
	var ch: int = world.h / ST
	var rng: = Rng.new(s.world_seed + 4242)

	var sources: Array[Vector2i] = []
	var min_d: int = maxi(8, cw / 14)
	var src_low: int = mini(hills_thr - 14, world.sea_level + (255 - world.sea_level) / 3)
	for tries in s.rivers * 60:
		if sources.size() >= s.rivers:
			break
		var p: = Vector2i(rng.range_ab(2, cw - 3), rng.range_ab(2, ch - 3))
		var v: int = world.height[(p.y * ST + 2) * w + p.x * ST + 2]
		if v < src_low or v >= snow_thr:
			continue
		var ok: bool = true
		for q in sources:
			if absi(q.x - p.x) + absi(q.y - p.y) < min_d:
				ok = false
				break
		if ok:
			sources.append(p)
	var dist: = PackedInt32Array()
	dist.resize(cw * ch)
	dist.fill(1 << 20)
	var queue: Array[Vector2i] = []
	for y in ch:
		for x in cw:
			if Biome.is_water(world.biome[(y * ST + 2) * w + x * ST + 2]):
				dist[y * cw + x] = 0
				queue.append(Vector2i(x, y))
	var head: int = 0
	while head < queue.size():
		var q: Vector2i = queue[head]
		head += 1
		var dq: int = dist[q.y * cw + q.x] + 1
		for d in DIRS4:
			var nb: Vector2i = q + d
			if nb.x < 0 or nb.y < 0 or nb.x >= cw or nb.y >= ch:
				continue
			if dist[nb.y * cw + nb.x] > dq:
				dist[nb.y * cw + nb.x] = dq
				queue.append(nb)

	var paths: Array = []
	var falls: Array = []
	for src in sources:
		if dist[src.y * cw + src.x] < 8:
			continue
		var path: Array[Vector2i] = [src]
		var cur: Vector2i = src
		var seen: Dictionary = {src: true}
		var flat_run: int = 0
		for step in 2000:
			var cd: int = dist[cur.y * cw + cur.x]
			if cd == 0:
				break
			var best: = Vector2i(-1, -1)
			var bv: int = 1 << 30
			for d in DIRS4:
				var nb: Vector2i = cur + d
				if nb.x < 0 or nb.y < 0 or nb.x >= cw or nb.y >= ch or seen.has(nb):
					continue
				var nd: int = dist[nb.y * cw + nb.x]
				if nd > cd or (nd == cd and flat_run >= 3):
					continue
				var nv: int = world.height[(nb.y * ST + 2) * w + nb.x * ST + 2] + (Hash32.h2(nb.x / 3, nb.y / 3, s.world_seed + step / 6) & 127) + (40 if nd == cd else 0)
				if nv < bv:
					bv = nv
					best = nb
			if best.x < 0:
				break
			flat_run = flat_run + 1 if dist[best.y * cw + best.x] == cd else 0
			path.append(best)
			seen[best] = true
			cur = best

		var last_rock: int = -1
		for i in path.size():
			var qb: int = world.biome[(path[i].y * ST + 2) * w + path[i].x * ST + 2]
			if qb == Biome.ROCK or qb == Biome.SNOW:
				last_rock = i
		var fall: Array = []
		if last_rock >= 0:
			if last_rock + 1 < path.size():
				fall = [path[last_rock], path[last_rock + 1]]
			path = path.slice(last_rock + 1)
		if path.size() >= 6:
			paths.append(path)
			falls.append(fall)


	var order: Array = range(paths.size())
	order.sort_custom( func(a: int, b: int) -> bool: return (paths[a] as Array).size() > (paths[b] as Array).size() or ((paths[a] as Array).size() == (paths[b] as Array).size() and a < b))
	var owner_map: Dictionary = {}
	var rivs: Array = []
	for oi: int in order:
		var path: Array = paths[oi]
		var cut: int = path.size()
		var jr: int = -1
		var ji: int = -1
		for i in path.size():
			if i < 3:
				continue
			var c: Vector2i = path[i]
			for nb: Vector2i in [c, c + Vector2i(1, 0), c + Vector2i(-1, 0), c + Vector2i(0, 1), c + Vector2i(0, -1)]:
				if owner_map.has(nb):
					var o: Array = owner_map[nb]
					cut = i + 1
					jr = int(o[0])
					ji = int(o[1])
					break
			if jr >= 0:
				break
		var p2: Array = path.slice(0, cut)
		var ri: int = rivs.size()
		for i in p2.size():
			if not owner_map.has(p2[i]):
				owner_map[p2[i]] = [ri, i]
		rivs.append({"path": p2, "join_r": jr, "join_i": ji, "fall": falls[oi]})

	var end_flow: = PackedInt32Array()
	end_flow.resize(rivs.size())
	var adds: Array = []
	adds.resize(rivs.size())
	for r in rivs.size():
		adds[r] = []
	for r in range(rivs.size() - 1, -1, -1):
		var rv: Dictionary = rivs[r]
		var n: int = (rv["path"] as Array).size()
		var flow: = PackedInt32Array()
		flow.resize(n)
		var extra: int = 0
		for i in n:
			for a: Array in adds[r]:
				if int(a[0]) == i:
					extra += int(a[1])
			flow[i] = 1 + i + extra
		rv["flow"] = flow
		end_flow[r] = flow[n - 1]
		if int(rv["join_r"]) >= 0:
			(adds[int(rv["join_r"])] as Array).append([int(rv["join_i"]), end_flow[r]])

	var lakes_made: int = 0
	var max_lakes: int = maxi(2, w / 256 + 1)
	if s.lakes >= 0:
		max_lakes = s.lakes
	for r in rivs.size():
		if lakes_made >= max_lakes:
			break
		var path: Array = rivs[r]["path"]
		if path.size() < 40 or int(rivs[r]["join_r"]) >= 0 and path.size() < 55:
			continue
		var k: int = path.size() * (35 + (Hash32.h2(r, 7, s.world_seed) & 15)) / 100
		var c: Vector2i = path[k]
		var cell: = Vector2i(c.x * ST + 2, c.y * ST + 2)
		var hv: int = world.height[cell.y * w + cell.x]
		if hv >= hills_thr - 6 or dist[c.y * cw + c.x] < 6:
			continue
		_carve_lake(world, cell, 9 + (Hash32.h2(r, 9, s.world_seed) % 6), s.world_seed + r * 31)
		lakes_made += 1
	if s.lakes > lakes_made:
		lakes_made += _free_lakes(world, s, dist, cw, ch, s.lakes - lakes_made, hills_thr)

	for r in rivs.size():
		var rv: Dictionary = rivs[r]
		var pts: Array = _smooth_path(rv["path"], rv["flow"], s.world_seed + r * 101, int(rv["join_r"]) >= 0)
		if pts.is_empty():
			continue
		if int(rv["join_r"]) >= 0:
			_link_to_water(world, pts)
		_mark_rapids(world, pts)
		_stamp_path(world, pts)
		var fall: Array = rv["fall"]
		if not fall.is_empty():
			_mark_fall(world, pts, fall)
		if int(rv["join_r"]) < 0 and end_flow[r] >= 60:
			_delta(world, pts, s.world_seed + r * 53)
	last_ms = Time.get_ticks_msec() - t0
	print("[WorldGen2] rivers %d, lakes %d, fx cells %d in %d ms" % [rivs.size(), lakes_made, world.fx_cells.size(), last_ms])




static func _free_lakes(world: WorldData, s: WorldSettings, dist: PackedInt32Array, cw: int, ch: int, want: int, hills_thr: int) -> int:
	var rng: = Rng.new(s.world_seed + 8383)
	var w: int = world.w
	var made: int = 0
	var spots: Array[Vector2i] = []
	for e: Array in world.lakes:
		spots.append(((e[0] as Rect2i).get_center()) / ST)
	var min_d: int = maxi(14, cw / 6)
	for tries in want * 80:
		if made >= want:
			break
		var c: = Vector2i(rng.range_ab(3, cw - 4), rng.range_ab(3, ch - 4))
		if dist[c.y * cw + c.x] < 7:
			continue
		var cell: = Vector2i(c.x * ST + 2, c.y * ST + 2)
		var i: int = cell.y * w + cell.x
		var b: int = world.biome[i]
		if Biome.is_water(b) or b == Biome.ROCK or b == Biome.SNOW or world.height[i] >= hills_thr - 6:
			continue
		var ok: bool = true
		for q: Vector2i in spots:
			if absi(q.x - c.x) + absi(q.y - c.y) < min_d:
				ok = false
				break
		if not ok:
			continue
		spots.append(c)
		_carve_lake(world, cell, 7 + (Hash32.h2(c.x, c.y, s.world_seed) % 7), s.world_seed + c.x * 131 + c.y)
		made += 1
	return made





static func _smooth_path(path: Array, flow: PackedInt32Array, sd: int, is_trib: bool) -> Array:
	var ctrl: Array[Vector2i] = []
	var cflow: = PackedInt32Array()
	for i in path.size():
		if i % 3 == 0 or i == path.size() - 1:
			var q: Vector2i = path[i]
			ctrl.append(q * (ST * FP) + Vector2i(2 * FP, 2 * FP))
			cflow.append(flow[i])
	var out: Array = []
	var n: int = ctrl.size()
	if n < 2:
		return out
	var raw: Array[Vector2i] = []
	var rflow: = PackedInt32Array()
	for i in n - 1:
		var p0: Vector2i = ctrl[maxi(0, i - 1)]
		var p1: Vector2i = ctrl[i]
		var p2: Vector2i = ctrl[i + 1]
		var p3: Vector2i = ctrl[mini(n - 1, i + 2)]
		var seg: int = maxi(2, idist(p1, p2) * 2 / FP)
		var c1: Vector2i = p2 - p0
		var c2: Vector2i = p0 * 2 - p1 * 5 + p2 * 4 - p3
		var c3: Vector2i = p1 * 3 - p0 - p2 * 3 + p3
		for k in seg:
			var t: int = k * FP / seg
			var t2: int = t * t / FP
			var t3: int = t2 * t / FP
			var px: int = (2 * p1.x + c1.x * t / FP + c2.x * t2 / FP + c3.x * t3 / FP) / 2
			var py: int = (2 * p1.y + c1.y * t / FP + c2.y * t2 / FP + c3.y * t3 / FP) / 2
			raw.append(Vector2i(px, py))
			rflow.append(cflow[i] + (cflow[i + 1] - cflow[i]) * k / seg)
	raw.append(ctrl[n - 1])
	rflow.append(cflow[n - 1])

	var arc: int = 0
	var total: int = raw.size()
	for i in total:
		if i > 0:
			arc += idist(raw[i], raw[i - 1])
		var nrm0: Vector2i = inorm(raw[mini(total - 1, i + 2)] - raw[maxi(0, i - 2)])
		var nrm: = Vector2i( - nrm0.y, nrm0.x)
		var fl: int = rflow[i]
		var wl: int = 16 * FP + mini(fl, 120) * FP / 10
		var u: int = arc * FP / wl
		var ui: int = u / FP
		var f: int = u - ui * FP
		f = f * f * (3 * FP - 2 * f) / (FP * FP)
		var a0: int = (115 + (Hash32.h2(ui, 0, sd) & 1023) * FP / 1860) * (1 if ui % 2 == 0 else -1)
		var a1: int = (115 + (Hash32.h2(ui + 1, 0, sd) & 1023) * FP / 1860) * (1 if (ui + 1) % 2 == 0 else -1)
		var u2: int = arc * FP / maxi(1, wl * 37 / 100)
		var ui2: int = u2 / FP
		var f2: int = u2 - ui2 * FP
		f2 = f2 * f2 * (3 * FP - 2 * f2) / (FP * FP)
		var b0: int = (Hash32.h2(ui2, 3, sd) & 1023) * FP / 511 - FP
		var b1: int = (Hash32.h2(ui2 + 1, 3, sd) & 1023) * FP / 511 - FP
		var amp: int = 2 * FP + mini(fl, 150) * FP * 3 / 100
		var taper: int = mini(FP, (total - 1 - i) * FP / 24) * mini(FP, i * FP / 10) / FP
		var m: int = a0 + (a1 - a0) * f / FP + (b0 + (b1 - b0) * f2 / FP) * 3 / 10
		var off: int = m * amp / FP * taper / FP
		var width: int = clampi(307 + isqrt(fl * FP * FP) * 42 / 100, 333, 6 * FP)
		out.append([raw[i] + nrm * off / FP, width])

	if not is_trib and total >= 3:
		var last: Vector2i = out[total - 1][0]
		var dir: Vector2i = inorm(last - (out[total - 3][0] as Vector2i))
		var wl2: int = out[total - 1][1]
		for k in range(1, 9):
			out.append([last + dir * k / 2, wl2 + k * 20])
	return out


static func _stamp_path(world: WorldData, pts: Array) -> void :
	var prev: = Vector2i(-99999, -99999)
	var half: int = FP / 2
	for e: Array in pts:
		var p: Vector2i = e[0]
		var wd: int = e[1]
		var cc: = Vector2i(p.x >> 8, p.y >> 8)
		if prev.x > -99999 and cc.x != prev.x and cc.y != prev.y:
			_set_water(world, prev.x, cc.y)
		prev = cc
		var r: int = wd / 2
		var ri: int = (r + FP - 1) / FP
		var lim: int = r * r + 9830
		for oy in range( - ri, ri + 1):
			for ox in range( - ri, ri + 1):
				var dx: int = (cc.x + ox) * FP + half - p.x
				var dy: int = (cc.y + oy) * FP + half - p.y
				if dx * dx + dy * dy <= lim or (ox == 0 and oy == 0):
					_set_water(world, cc.x + ox, cc.y + oy)




static func _link_to_water(world: WorldData, pts: Array) -> void :
	var last: Array = pts[pts.size() - 1]
	var p: Vector2i = last[0]
	var c: = Vector2i(p.x >> 8, p.y >> 8)
	var best: = Vector2i(-1, -1)
	var bd: int = 1 << 20
	for dy in range(-9, 10):
		for dx in range(-9, 10):
			var q: = c + Vector2i(dx, dy)
			if not world.inside(q.x, q.y):
				continue
			var d: int = dx * dx + dy * dy
			if d < bd and Biome.is_water(world.biome[q.y * world.w + q.x]):
				bd = d
				best = q
	if best.x < 0:
		return
	var tgt: Vector2i = best * FP + Vector2i(FP / 2, FP / 2)
	var dir_in: Vector2i = inorm(p - (pts[maxi(0, pts.size() - 6)][0] as Vector2i))
	var dpt: int = idist(p, tgt)
	var ctl: Vector2i = p + dir_in * mini(3 * FP, dpt / 2) / FP
	var steps: int = maxi(2, dpt * 2 / FP)
	for k in range(1, steps + 1):
		var t: int = k * FP / steps
		var a: Vector2i = p + (ctl - p) * t / FP
		var b: Vector2i = ctl + (tgt - ctl) * t / FP
		pts.append([a + (b - a) * t / FP, int(last[1])])



static func _delta(world: WorldData, pts: Array, sd: int) -> void :
	var n: int = pts.size()
	if n < 60:
		return
	for side: int in [-1, 1]:
		var k: int = n - 52 - (Hash32.h2(side + 3, 1, sd) % 16)
		var p: Vector2i = pts[k][0]
		var dir: Vector2i = inorm((pts[mini(n - 1, k + 6)][0] as Vector2i) - (pts[maxi(0, k - 6)][0] as Vector2i))
		dir = _rot(dir, side * (22 + Hash32.h2(side + 5, 2, sd) % 12))
		var cells: Array[Vector2i] = []
		var reached: bool = false
		for step in 90:
			p += dir / 2
			if ((step / 8 + sd) % 5) < 3:
				dir = _rot(dir, - side)
			var cc: = Vector2i(p.x >> 8, p.y >> 8)
			if not world.inside(cc.x, cc.y):
				break
			var b: int = world.biome[cc.y * world.w + cc.x]
			if b <= Biome.COAST and step > 6:
				reached = true
				break
			if not cells.is_empty() and cc.x != cells[cells.size() - 1].x and cc.y != cells[cells.size() - 1].y:
				cells.append(Vector2i(cells[cells.size() - 1].x, cc.y))
			cells.append(cc)
			if step < 84 and step % 3 != 0:
				cells.append(cc + Vector2i(1 if absi(dir.y) > absi(dir.x) else 0, 1 if absi(dir.x) >= absi(dir.y) else 0))
		if not reached:
			continue
		for c: Vector2i in cells:
			_set_water(world, c.x, c.y)


static func _rot(v: Vector2i, deg: int) -> Vector2i:
	var c: int = icos(deg)
	var s: int = isin(deg)
	return inorm(Vector2i((v.x * c - v.y * s) / 4096, (v.x * s + v.y * c) / 4096))




static func _carve_lake(world: WorldData, c: Vector2i, rad: int, sd: int) -> void :
	var blobs: Array = [[c.x, c.y, rad * (62 + (Hash32.h2(1, 1, sd) % 20)) / 100, rad * (50 + (Hash32.h2(1, 2, sd) % 20)) / 100]]
	var nb: int = 3 + Hash32.h2(2, 0, sd) % 3
	var ang: int = Hash32.h2(2, 1, sd) % 360
	for k in nb:

		var a: int = ang + k * 360 / nb + (Hash32.h2(k, 3, sd) % 50) - 25
		var dd: int = rad * (45 + Hash32.h2(k, 4, sd) % 35) / 100
		var ox: int = icos(a) * dd / 4096
		var oy: int = isin(a) * dd * 3 / 4 / 4096
		blobs.append([c.x + ox, c.y + oy, maxi(3, rad * (30 + Hash32.h2(k, 5, sd) % 30) / 100), maxi(2, rad * (25 + Hash32.h2(k, 6, sd) % 25) / 100)])
	var R: int = rad * 2 + 4
	var rect: = Rect2i(c.x - R, c.y - R, R * 2 + 1, R * 2 + 1).intersection(Rect2i(0, 0, world.w, world.h))
	var mask: = PackedByteArray()
	mask.resize(rect.size.x * rect.size.y)
	var any: bool = false
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var i: int = y * world.w + x
			var b: int = world.biome[i]
			if b == Biome.ROCK or b == Biome.SNOW or b <= Biome.OCEAN:
				continue
			var best: int = 1 << 40
			var best_rim: int = 1 << 40
			for bl: Array in blobs:
				var rx: int = int(bl[2])
				var ry: int = int(bl[3])
				var dx: int = (x - int(bl[0])) * 1000 / rx
				var dy: int = (y - int(bl[1])) * 1000 / ry
				best = mini(best, dx * dx + dy * dy)
				var dx2: int = (x - int(bl[0])) * 1000 / (rx + 2)
				var dy2: int = (y - int(bl[1])) * 1000 / (ry + 2)
				best_rim = mini(best_rim, dx2 * dx2 + dy2 * dy2)
			var mi: int = (y - rect.position.y) * rect.size.x + (x - rect.position.x)
			if best < 1000000:
				var depth: int = (1000000 - best) * 10 / 1000000
				world.biome[i] = Biome.SHALLOW if depth >= 3 else Biome.COAST
				world.height[i] = maxi(0, world.sea_level - 2 - depth)
				mask[mi] = 1
				any = true
			elif best_rim < 1000000 and not Biome.is_water(b) and (Hash32.h2(x, y, sd + 77) & 255) < 30:
				world.biome[i] = Biome.COAST
				world.height[i] = maxi(0, world.sea_level - 2)
				mask[mi] = 2
	if any:
		world.lakes.append([rect, mask])



static func _mark_rapids(world: WorldData, pts: Array) -> void :
	var n: int = pts.size()
	if n < 20:
		return
	var hs: = PackedInt32Array()
	hs.resize(n)
	for i in n:
		var p: Vector2i = pts[i][0]
		var cx: int = p.x >> 8
		var cy: int = p.y >> 8
		hs[i] = -1
		if world.inside(cx, cy):
			var ii: int = cy * world.w + cx
			if not Biome.is_water(world.biome[ii]):
				hs[i] = world.height[ii]
	var made: int = 0
	var i: int = 8
	var upl: int = world.hills_thr - 16
	while i < n - 8 and made < 3:
		var a: int = hs[i - 8]
		var b: int = hs[i + 8]
		if a >= 0 and b >= 0 and a - b >= 8 and a >= upl:

			for k in range(i - 2, mini(n, i + 4)):
				var p: Vector2i = pts[k][0]
				var r: int = maxi(FP / 2, int(pts[k][1]) / 2 - FP / 3)
				var ri: int = (r + FP - 1) / FP
				var cc: = Vector2i(p.x >> 8, p.y >> 8)
				for oy in range( - ri, ri + 1):
					for ox in range( - ri, ri + 1):
						var dx: int = (cc.x + ox) * FP + FP / 2 - p.x
						var dy: int = (cc.y + oy) * FP + FP / 2 - p.y
						if dx * dx + dy * dy <= r * r and world.inside(cc.x + ox, cc.y + oy):
							world.fx_cells[(cc.y + oy) * world.w + cc.x + ox] = FX_RAPID
			made += 1
			i += 40
		else:
			i += 2







static func _mark_fall(world: WorldData, pts: Array, fall: Array) -> void :
	var w: int = world.w
	var p0: Vector2i = pts[0][0]
	var c0: = Vector2i(p0.x >> 8, p0.y >> 8)
	var best: = Vector2i(0, -1)
	var best_n: int = -1
	for d: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		var n: int = 1 if d.y == -1 else 0
		for k in range(1, 8):
			var q: Vector2i = c0 + d * k
			if not world.inside(q.x, q.y):
				break
			var b: int = world.biome[q.y * w + q.x]
			if b == Biome.ROCK or b == Biome.SNOW or b == Biome.HILLS:
				n += 2
			elif b == Biome.PINE or b == Biome.FOREST:
				n += 1
			elif Biome.is_water(b):
				n -= 2
		if n > best_n:
			best_n = n
			best = d
	if best_n < 4:
		return
	var code: int = FX_FALL if best.x == 0 else FX_FALL_H
	var side: = Vector2i(1, 0) if best.x == 0 else Vector2i(0, 1)

	for k in mini(5, pts.size()):
		var q: Vector2i = pts[k][0]
		var c: = Vector2i(q.x >> 8, q.y >> 8)
		for o: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var cc: Vector2i = c + o
			if world.inside(cc.x, cc.y) and Biome.is_water(world.biome[cc.y * w + cc.x]):
				world.fx_cells[cc.y * w + cc.x] = FX_POOL
	var laid: int = 0
	var last: = c0
	for k in range(1, 9):
		var c: Vector2i = c0 + best * k
		if not world.inside(c.x, c.y) or not world.inside(c.x + side.x, c.y + side.y):
			break
		var i: int = c.y * w + c.x
		if Biome.is_water(world.biome[i]):
			continue
		world.fx_cells[i] = code
		var i2: int = (c.y + side.y) * w + c.x + side.x
		if not Biome.is_water(world.biome[i2]):
			world.fx_cells[i2] = code
		laid += 1
		last = c
		if laid >= 7:
			break
	if laid > 0:
		for o in 2:
			var e: Vector2i = last + best + side * o
			if world.inside(e.x, e.y) and not Biome.is_water(world.biome[e.y * w + e.x]):
				world.fx_cells[e.y * w + e.x] = FX_FALL_EDGE


static func _set_water(world: WorldData, x: int, y: int) -> void :
	if not world.inside(x, y):
		return
	var i: int = y * world.w + x
	if Biome.is_water(world.biome[i]):
		return
	world.biome[i] = Biome.RIVER
	world.height[i] = maxi(0, world.sea_level - 3)
