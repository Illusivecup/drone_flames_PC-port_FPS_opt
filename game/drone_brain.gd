class_name DroneBrain
extends RefCounted








const BY_POINT: int = 0
const BY_LONG: int = 1
const BY_EW: int = 2
const BY_AIR: int = 3
const BY_NET: int = 4
const FLANK_FAILS: int = 4
const EXPLORE_REST: float = 180.0

const CS: float = 80.0
const HALF_LIFE: float = 240.0
const POINT_R: float = 220.0
const POINT_W: float = 1.0
const EW_R: float = 150.0
const EW_W: float = 0.5
const SEED_W: float = 0.45
const SEED_R_MAX: float = 300.0
const TABOO_W: float = 0.8
const TABOO_R: float = 90.0
const TABOO_END: float = 260.0
const LVL_MAX: float = 4.0
const K_DANGER: float = 8.0
const RANGE_USE: float = 0.88
const BUCKET: float = 300.0
const DROP_STREAK: float = 2.0
const MAX_WPS: int = 4
const MIN_GAIN: float = 0.95
const POINT_KINDS: Array = [Facility.Kind.AD_MFG, Facility.Kind.AD_SPAAG, Facility.Kind.AD_INT]

var gw: GameWorld
var danger: Dictionary = {}
var routes: Dictionary = {}
var smart: Dictionary = {}
var stats: Dictionary = {}
var ver: int = 0
var _cache: Dictionary = {}
var _prune_t: float = 0.0

var _c0: Vector2i = Vector2i.ZERO
var _nx: int = 0
var _ny: int = 0
var _dang: PackedFloat32Array = PackedFloat32Array()

const SKIP: Array = ["_cache", "_c0", "_nx", "_ny", "_dang"]


class Heap:
	var k: PackedFloat32Array = PackedFloat32Array()
	var v: PackedInt32Array = PackedInt32Array()

	func size() -> int:
		return v.size()

	func push(key: float, val: int) -> void :
		k.append(key)
		v.append(val)
		var i: int = v.size() - 1
		while i > 0:
			var p: int = (i - 1) >> 1
			if k[p] <= k[i]:
				break
			var tk: float = k[p]
			k[p] = k[i]
			k[i] = tk
			var tv: int = v[p]
			v[p] = v[i]
			v[i] = tv
			i = p

	func pop() -> int:
		var top: int = v[0]
		var last: int = v.size() - 1
		k[0] = k[last]
		v[0] = v[last]
		k.resize(last)
		v.resize(last)
		var i: int = 0
		while true:
			var l: int = i * 2 + 1
			if l >= last:
				break
			var r: int = l + 1
			var m: int = l if (r >= last or k[l] <= k[r]) else r
			if k[i] <= k[m]:
				break
			var tk: float = k[m]
			k[m] = k[i]
			k[i] = tk
			var tv: int = v[m]
			v[m] = v[i]
			v[i] = tv
			i = m
		return top


func _init(world: GameWorld) -> void :
	gw = world




func smart_of(cid: int) -> bool:
	if smart.has(cid):
		return bool(smart[cid])
	var c: Country = gw.country_by_id(cid)
	return c != null and not c.is_player


func set_smart(cid: int, on: bool) -> void :
	smart[cid] = on


func stat(cid: int) -> Dictionary:
	if not stats.has(cid):
		stats[cid] = {"hit": 0, "point": 0, "long": 0, "ew": 0, "drops": 0, "plans": 0, "reuse": 0}
	return stats[cid]


static func _ck(c: Vector2i) -> int:
	return (c.y + 2048) * 8192 + (c.x + 2048)


static func _kc(k: int) -> Vector2i:
	return Vector2i(k % 8192 - 2048, k / 8192 - 2048)


static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CS), floori(p.y / CS))


func key_of(cid: int, target: Vector2) -> String:
	return "%d:%d:%d" % [cid, floori(target.x / BUCKET), floori(target.y / BUCKET)]




static func _lvl_e(e: Variant, now: float) -> float:
	if e == null:
		return 0.0
	var a: Array = e
	return float(a[0]) * pow(0.5, maxf(0.0, now - float(a[1])) / HALF_LIFE)


func level_at(cid: int, p: Vector2) -> float:
	var dm: Dictionary = danger.get(cid, {})
	return _lvl_e(dm.get(_ck(cell_of(p))), gw.game_time)


func _add_disc(cid: int, p: Vector2, r: float, w: float) -> void :
	if not danger.has(cid):
		danger[cid] = {}
	var dm: Dictionary = danger[cid]
	var now: float = gw.game_time
	var rc: int = ceili(r / CS) + 1
	var pc: Vector2i = cell_of(p)
	for dy in range( - rc, rc + 1):
		for dx in range( - rc, rc + 1):
			var c: = pc + Vector2i(dx, dy)
			var dd: float = ((Vector2(c) + Vector2(0.5, 0.5)) * CS).distance_to(p)
			if dd > r:
				continue
			var k: int = _ck(c)
			var lv: float = _lvl_e(dm.get(k), now) + w * (1.0 - 0.6 * dd / r)
			dm[k] = [minf(LVL_MAX, lv), now]


func _prune() -> void :
	var now: float = gw.game_time
	if now - _prune_t < 30.0:
		return
	_prune_t = now
	for cid: Variant in danger:
		var dm: Dictionary = danger[cid]
		for k: Variant in dm.keys():
			if _lvl_e(dm[k], now) < 0.03:
				dm.erase(k)
	for rk: Variant in routes.keys():
		if now - float((routes[rk] as Dictionary).get("t", now)) > 1800.0:
			routes.erase(rk)
	if _cache.size() > 64:
		_cache.clear()



func infer_killer(d: Drone) -> int:
	if gw.defense == null:
		return BY_POINT
	for s: Dictionary in gw.defense.shots:
		if s["target"] == d and (s["pos"] as Vector2).distance_to(d.pos) <= float(s.get("speed", 150.0)) * 0.35 + 6.0:
			return BY_POINT if String(s["kind"]) == "int" else BY_LONG
	return BY_POINT



func note_loss(d: Drone, by: int) -> void :
	if d == null or d.smart_noted or (d.kind != 0 and d.kind != 2):
		return
	d.smart_noted = true
	var st: Dictionary = stat(d.country_id)
	match by:
		BY_NET:
			st["point"] = int(st["point"]) + 1
			st["net"] = int(st.get("net", 0)) + 1
		BY_POINT:
			_add_disc(d.country_id, d.pos, POINT_R, POINT_W)
			st["point"] = int(st["point"]) + 1
		BY_EW:
			_add_disc(d.country_id, d.pos, EW_R, EW_W)
			st["ew"] = int(st["ew"]) + 1
		_:
			st["long"] = int(st["long"]) + 1
	ver += 1
	_mem_event(d, false, by)
	_prune()



func note_hit(d: Drone) -> void :
	if d == null or d.smart_noted or (d.kind != 0 and d.kind != 2):
		return
	d.smart_noted = true
	var st: Dictionary = stat(d.country_id)
	st["hit"] = int(st["hit"]) + 1
	ver += 1
	_mem_event(d, true, -1)


func _mem_event(d: Drone, hit: bool, by: int) -> void :
	if d.smart_key == "" or not routes.has(d.smart_key):
		return
	var mem: Dictionary = routes[d.smart_key]
	mem["t"] = gw.game_time
	if hit:
		mem["tw"] = int(mem["tw"]) + 1
	elif by == BY_POINT or by == BY_EW or by == BY_NET:
		mem["tl"] = int(mem["tl"]) + 1
	else:
		mem["ts"] = int(mem["ts"]) + 1
	if hit:
		mem["dsw"] = 0
	if d.smart_ver != int(mem["ver"]) or not bool(mem["has"]):
		return


	var at_target: bool = by == BY_NET or (by == BY_POINT and d.pos.distance_to(d.target) < TABOO_END)
	if not hit and (at_target or gw.game_time < float(mem.get("rest", -1.0))):
		return
	if hit:
		mem["wins"] = int(mem["wins"]) + 1
		mem["streak"] = 0.0
	elif by == BY_POINT or by == BY_EW:
		mem["streak"] = float(mem["streak"]) + (1.0 if by == BY_POINT else 0.5)
		if float(mem["streak"]) >= DROP_STREAK:
			var bad: Array = mem["bad"]
			var poly: Array = [mem["from"]]
			poly.append_array(mem["wps"])
			poly.append(mem["target"])
			bad.append(poly)
			while bad.size() > 2:
				bad.pop_front()
			mem["has"] = false
			mem["ver"] = int(mem["ver"]) + 1
			mem["drops"] = int(mem["drops"]) + 1
			mem["flip"] = int(mem["flip"]) + 1
			var st: Dictionary = stat(d.country_id)
			st["drops"] = int(st["drops"]) + 1
			mem["dsw"] = int(mem.get("dsw", 0)) + 1
			if int(mem["dsw"]) >= FLANK_FAILS:

				mem["rest"] = gw.game_time + EXPLORE_REST
				mem["dsw"] = 0
				(mem["bad"] as Array).clear()
				st["rests"] = int(st.get("rests", 0)) + 1


func _new_mem(target: Vector2) -> Dictionary:
	return {"has": false, "wps": [], "from": Vector2.ZERO, "target": target, "ver": 0, "wins": 0, "streak": 0.0, 
		"tw": 0, "tl": 0, "ts": 0, "bad": [], "flip": 0, "drops": 0, "t": gw.game_time}




static func poly_len(from: Vector2, wps: Array, target: Vector2) -> float:
	var s: float = 0.0
	var p: Vector2 = from
	for q: Variant in wps:
		s += p.distance_to(q)
		p = q
	return s + p.distance_to(target)




static func src_code(s: String) -> String:
	return String({"память": "memory", "новый": "new", "прямой": "direct"}.get(s, s))



func choose(cid: int, from: Vector2, target: Vector2, rng: float, commit: bool) -> Dictionary:
	var key: String = key_of(cid, target)
	var mem: Dictionary = routes.get(key, {})
	var lim: float = rng * RANGE_USE
	var wps: Array[Vector2] = []
	var source: String = "direct"
	var reuse: bool = false
	var rest: bool = not mem.is_empty() and gw.game_time < float(mem.get("rest", -1.0))
	if rest:
		reuse = true
	elif not mem.is_empty() and bool(mem["has"]) and (mem["from"] as Vector2).distance_to(from) <= 600.0:
		for q: Variant in mem["wps"]:
			wps.append(q)
		if poly_len(from, wps, target) <= maxf(lim, from.distance_to(target)):
			reuse = true
		else:
			wps.clear()
	if rest:
		source = "direct"
	elif reuse:
		source = "memory" if int(mem["wins"]) > 0 else ("direct" if wps.is_empty() else "new")
	else:
		wps = _plan_cached(cid, from, target, lim, mem)
		source = "direct" if wps.is_empty() else "new"
	var out: Dictionary = {"wps": wps, "source": source, "key": key, "ver": int(mem.get("ver", 0)), "len": poly_len(from, wps, target), 
		"danger": route_danger(cid, from, wps, target)}
	if commit:
		var st: Dictionary = stat(cid)
		if rest:
			mem["has"] = true
			mem["wps"] = []
			mem["from"] = from
			st["direct"] = int(st.get("direct", 0)) + 1
		elif reuse:
			st["reuse"] = int(st["reuse"]) + 1
		else:
			if mem.is_empty():
				mem = _new_mem(target)
				routes[key] = mem
			mem["has"] = true
			mem["wps"] = wps.duplicate()
			mem["from"] = from
			mem["target"] = target
			mem["ver"] = int(mem["ver"]) + 1
			mem["wins"] = 0
			mem["streak"] = 0.0
			st["plans"] = int(st["plans"]) + 1
		mem["t"] = gw.game_time
		out["ver"] = int(mem["ver"])
	out["mem"] = mem
	return out


func _plan_cached(cid: int, from: Vector2, target: Vector2, lim: float, mem: Dictionary) -> Array[Vector2]:
	var ck: String = "%d|%s|%d|%d|%d|%d|%d|%d" % [cid, key_of(cid, target), roundi(from.x / 20.0), roundi(from.y / 20.0), 
		roundi(target.x / 20.0), roundi(target.y / 20.0), ver * 1000 + int(mem.get("ver", 0)), int(gw.game_time / 5.0)]
	if _cache.has(ck):
		return (_cache[ck] as Array[Vector2]).duplicate()
	var r: Array[Vector2] = plan(cid, from, target, lim, mem)
	if _cache.size() > 64:
		_cache.clear()
	_cache[ck] = r.duplicate()
	return r




func _extra(cid: int, from: Vector2, target: Vector2, mem: Dictionary) -> Dictionary:
	var ex: Dictionary = {}
	var c: Country = gw.country_by_id(cid)
	if c != null and c.is_player and not gw.net_driven:
		for f: Facility in gw.mil.facilities:
			if not POINT_KINDS.has(f.kind) or not gw.mil.alive(f) or not gw.mil.hostile(cid, f.country_id):
				continue
			if gw.vision != null and not gw.vision.known(f):
				continue
			var p: Vector2 = gw.vision.last_pos(f) if gw.vision != null else f.center_px()
			var r: float = minf(SEED_R_MAX, float(Defense.SPEC[f.kind]["range"]))
			_disc_max(ex, p, r, SEED_W, true)
	for poly: Variant in (mem.get("bad", []) as Array):
		var a: Array = poly
		for i in range(a.size() - 1):
			var p0: Vector2 = a[i]
			var p1: Vector2 = a[i + 1]
			var n: int = maxi(1, ceili(p0.distance_to(p1) / (CS * 0.5)))
			for s in n + 1:
				var q: Vector2 = p0.lerp(p1, float(s) / float(n))
				if q.distance_to(from) < TABOO_END or q.distance_to(target) < TABOO_END:
					continue
				_disc_max(ex, q, TABOO_R, TABOO_W, false)
	return ex


static func _disc_max(ex: Dictionary, p: Vector2, r: float, w: float, add: bool) -> void :
	var rc: int = ceili(r / CS) + 1
	var pc: Vector2i = cell_of(p)
	for dy in range( - rc, rc + 1):
		for dx in range( - rc, rc + 1):
			var c: = pc + Vector2i(dx, dy)
			if ((Vector2(c) + Vector2(0.5, 0.5)) * CS).distance_to(p) > r:
				continue
			var k: int = _ck(c)
			ex[k] = float(ex.get(k, 0.0)) + w if add else maxf(float(ex.get(k, 0.0)), w)


func _dl(p: Vector2) -> float:
	var c: Vector2i = cell_of(p) - _c0
	if c.x < 0 or c.y < 0 or c.x >= _nx or c.y >= _ny:
		return 0.0
	return _dang[c.y * _nx + c.x]


func _seg_cost(a: Vector2, b: Vector2, kd: float) -> float:
	var l: float = a.distance_to(b)
	var n: int = maxi(1, ceili(l / (CS * 0.5)))
	var s: float = 0.0
	for i in n:
		s += 1.0 + kd * _dl(a.lerp(b, (float(i) + 0.5) / float(n)))
	return s * l / float(n)


func _poly_cost(pts: Array[Vector2], kd: float) -> float:
	var s: float = 0.0
	for i in range(pts.size() - 1):
		s += _seg_cost(pts[i], pts[i + 1], kd)
	return s




func plan(cid: int, from: Vector2, target: Vector2, lim: float, mem: Dictionary = {}) -> Array[Vector2]:
	var none: Array[Vector2] = []
	var direct: float = from.distance_to(target)
	var margin: float = clampf((lim - direct) * 0.5, 0.0, 1600.0)
	if margin < CS * 0.75:
		return none
	var ex: Dictionary = _extra(cid, from, target, mem)
	var mw: float = float(gw.data.w * GameWorld.CELL)
	var mh: float = float(gw.data.h * GameWorld.CELL)
	var lo: = Vector2(maxf(0.0, minf(from.x, target.x) - margin), maxf(0.0, minf(from.y, target.y) - margin))
	var hi: = Vector2(minf(mw - 1.0, maxf(from.x, target.x) + margin), minf(mh - 1.0, maxf(from.y, target.y) + margin))
	lo = lo.min(from.min(target))
	hi = hi.max(from.max(target))
	_c0 = cell_of(lo)
	var c1: Vector2i = cell_of(hi)
	_nx = c1.x - _c0.x + 1
	_ny = c1.y - _c0.y + 1
	var n: int = _nx * _ny
	_dang = PackedFloat32Array()
	_dang.resize(n)
	var ok: = PackedByteArray()
	ok.resize(n)
	var dm: Dictionary = danger.get(cid, {})
	var now: float = gw.game_time
	var any: bool = false
	for y in _ny:
		for x in _nx:
			var wc: = Vector2i(_c0.x + x, _c0.y + y)
			var ctr: Vector2 = (Vector2(wc) + Vector2(0.5, 0.5)) * CS
			var i: int = y * _nx + x
			var k: int = _ck(wc)
			var lv: float = _lvl_e(dm.get(k), now) + float(ex.get(k, 0.0))
			_dang[i] = 1.0 - exp( - lv)
			if _dang[i] > 0.02:
				any = true
			ok[i] = 1 if from.distance_to(ctr) + ctr.distance_to(target) <= lim + CS * 0.5 else 0
	var bad: Array = mem.get("bad", [])
	if not any and bad.is_empty():
		_dang = PackedFloat32Array()
		return none
	var sc: Vector2i = cell_of(from) - _c0
	var gc: Vector2i = cell_of(target) - _c0
	var si: int = sc.y * _nx + sc.x
	var gi: int = gc.y * _nx + gc.x
	ok[si] = 1
	ok[gi] = 1
	var direct_pts: Array[Vector2] = [from, target]
	var best: Array[Vector2] = none
	for kd: float in [K_DANGER, K_DANGER * 0.5, K_DANGER * 0.25]:
		var cells: PackedInt32Array = _astar(si, gi, ok, kd, target)
		if cells.is_empty():
			continue
		var pts: Array[Vector2] = [from]
		for j in range(1, cells.size() - 1):
			pts.append((Vector2(_c0 + Vector2i(cells[j] %_nx, cells[j] / _nx)) + Vector2(0.5, 0.5)) * CS)
		pts.append(target)
		pts = _simplify(pts, kd)
		var wps: Array[Vector2] = pts.slice(1, pts.size() - 1)
		if poly_len(from, wps, target) > lim:
			continue
		if _poly_cost(pts, kd) < _poly_cost(direct_pts, kd) * MIN_GAIN:
			best = wps
		break

	if not bad.is_empty() and _similar_any(from, best, target, bad):
		var fl: Array[Vector2] = _flank(from, target, lim, bad, int(mem.get("flip", 0)))
		if not fl.is_empty() or best.is_empty():
			best = fl
	_dang = PackedFloat32Array()
	return best


func _astar(si: int, gi: int, ok: PackedByteArray, kd: float, target: Vector2) -> PackedInt32Array:
	var n: int = ok.size()
	var g: = PackedFloat32Array()
	g.resize(n)
	g.fill(INF)
	var par: = PackedInt32Array()
	par.resize(n)
	par.fill(-1)
	var closed: = PackedByteArray()
	closed.resize(n)
	var h: = Heap.new()
	g[si] = 0.0
	h.push(0.0, si)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var tc: Vector2 = target / CS
	while h.size() > 0:
		var cur: int = h.pop()
		if closed[cur] != 0:
			continue
		closed[cur] = 1
		if cur == gi:
			break
		var cx: int = cur % _nx
		var cy: int = cur / _nx
		for dv: Vector2i in dirs:
			var x: int = cx + dv.x
			var y: int = cy + dv.y
			if x < 0 or y < 0 or x >= _nx or y >= _ny:
				continue
			var ni: int = y * _nx + x
			if ok[ni] == 0 or closed[ni] != 0:
				continue
			var step: float = CS * (1.41421356 if dv.x != 0 and dv.y != 0 else 1.0)
			var ng: float = g[cur] + step * (1.0 + kd * 0.5 * (_dang[cur] + _dang[ni]))
			if ng < g[ni]:
				g[ni] = ng
				par[ni] = cur
				var hx: float = (float(_c0.x + x) + 0.5 - tc.x) * CS
				var hy: float = (float(_c0.y + y) + 0.5 - tc.y) * CS
				h.push(ng + sqrt(hx * hx + hy * hy), ni)
	if par[gi] < 0 and gi != si:
		return PackedInt32Array()
	var out: = PackedInt32Array()
	var c: int = gi
	var guard: int = 0
	while c >= 0 and guard < n:
		out.append(c)
		c = par[c]
		guard += 1
	out.reverse()
	return out




func _simplify(pts: Array[Vector2], kd: float) -> Array[Vector2]:
	var cum: = PackedFloat32Array()
	cum.resize(pts.size())
	for i in range(1, pts.size()):
		cum[i] = cum[i - 1] + _seg_cost(pts[i - 1], pts[i], kd)
	var out: Array[Vector2] = [pts[0]]
	var i: int = 0
	var last: int = pts.size() - 1
	while i < last:
		var j: int = last
		while j > i + 1:
			if _seg_cost(pts[i], pts[j], kd) <= (cum[j] - cum[i]) * 1.03 + 1.0:
				break
			j -= 1
		out.append(pts[j])
		i = j
	while out.size() > MAX_WPS + 2:
		var bk: int = 1
		var bd: float = INF
		for k in range(1, out.size() - 1):
			var dc: float = _seg_cost(out[k - 1], out[k + 1], kd) - _seg_cost(out[k - 1], out[k], kd) - _seg_cost(out[k], out[k + 1], kd)
			if dc < bd:
				bd = dc
				bk = k
		out.remove_at(bk)
	return out


func _similar_any(from: Vector2, wps: Array[Vector2], target: Vector2, bad: Array) -> bool:
	var pts: Array[Vector2] = [from]
	pts.append_array(wps)
	pts.append(target)
	for poly: Variant in bad:
		if _similar(pts, poly as Array, from, target):
			return true
	return false



static func _similar(pts: Array[Vector2], poly: Array, from: Vector2, target: Vector2) -> bool:
	var s: float = 0.0
	var n: int = 0
	var total: float = 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	for k in range(1, 10):
		var q: Vector2 = _along(pts, total * float(k) / 10.0)
		if q.distance_to(from) < TABOO_END or q.distance_to(target) < TABOO_END:
			continue
		var bd: float = INF
		for i in range(poly.size() - 1):
			bd = minf(bd, q.distance_to(Geometry2D.get_closest_point_to_segment(q, poly[i], poly[i + 1])))
		s += bd
		n += 1
	return n == 0 or s / float(n) < 100.0


static func _along(pts: Array[Vector2], d: float) -> Vector2:
	var left: float = d
	for i in range(pts.size() - 1):
		var l: float = pts[i].distance_to(pts[i + 1])
		if left <= l:
			return pts[i].lerp(pts[i + 1], left / maxf(l, 0.001))
		left -= l
	return pts[pts.size() - 1]



func _flank(from: Vector2, target: Vector2, lim: float, bad: Array, flip: int) -> Array[Vector2]:
	var none: Array[Vector2] = []
	var dir: Vector2 = target - from
	var dist: float = dir.length()
	if dist < 1.0:
		return none
	var perp: Vector2 = dir.orthogonal() / dist
	var sides: Array = [1.0, -1.0] if flip % 2 == 1 else [-1.0, 1.0]
	var mw: float = float(gw.data.w * GameWorld.CELL)
	var mh: float = float(gw.data.h * GameWorld.CELL)
	for frac: float in [0.45, 0.35, 0.25]:
		for sd: float in sides:
			var mid: Vector2 = from.lerp(target, 0.5) + perp * sd * dist * frac
			if mid.x < 0.0 or mid.y < 0.0 or mid.x > mw or mid.y > mh:
				continue
			var w: Array[Vector2] = [mid]
			if poly_len(from, w, target) > lim or _similar_any(from, w, target, bad):
				continue
			return w
	return none



func route_danger(cid: int, from: Vector2, wps: Array[Vector2], target: Vector2) -> float:
	var dm: Dictionary = danger.get(cid, {})
	var now: float = gw.game_time
	var worst: float = 0.0
	var pts: Array[Vector2] = [from]
	pts.append_array(wps)
	pts.append(target)
	for i in range(pts.size() - 1):
		var n: int = maxi(1, ceili(pts[i].distance_to(pts[i + 1]) / (CS * 0.5)))
		for s in n + 1:
			worst = maxf(worst, _lvl_e(dm.get(_ck(cell_of(pts[i].lerp(pts[i + 1], float(s) / float(n))))), now))
	return 1.0 - exp( - worst)



func cells_of(cid: int) -> Array:
	var out: Array = []
	var now: float = gw.game_time
	var dm: Dictionary = danger.get(cid, {})
	for k: Variant in dm:
		var lv: float = _lvl_e(dm[k], now)
		if lv >= 0.05:
			out.append({"pos": (Vector2(_kc(int(k))) + Vector2(0.5, 0.5)) * CS, "r": CS * 0.5, "level": 1.0 - exp( - lv), "kind": "loss"})
	var c: Country = gw.country_by_id(cid)
	if c != null and c.is_player:
		var ex: Dictionary = _extra(cid, Vector2(-1000000.0, -1000000.0), Vector2(-1000000.0, -1000000.0), {})
		for k2: Variant in ex:
			out.append({"pos": (Vector2(_kc(int(k2))) + Vector2(0.5, 0.5)) * CS, "r": CS * 0.5, "level": 1.0 - exp( - float(ex[k2])), "kind": "seen"})
	return out


func save_state() -> Dictionary:
	return Save.dump(self, SKIP)


func load_state(d: Dictionary) -> void :
	Save.fill(self, d, SKIP)
	_cache.clear()
