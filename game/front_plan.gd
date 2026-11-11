extends RefCounted






















const ArmyGroups = preload("res://game/army_groups.gd")

enum St{ARMED, RUN}

const STEP: float = 16.0
const SCAN: int = 3
const SETBACK: float = 110.0
const AI_SETBACK: float = 36.0
const AI_SUP_BACK: float = 150.0
const AI_LINE_GAP: float = 110.0
const SUP_BACK: float = 230.0
const SHORT_HYST: float = 160.0
const SHORT_FRONT: float = 480.0
const MIN_GAP: float = 34.0
const FRONT_MAX: float = 2600.0
const STRETCH_MIN: float = 480.0
const STRETCH_PER: float = 230.0
const BORDER_R: float = 170.0
const WET_TAP: float = 24.0
const SCAN_R: float = 1700.0
const REFRESH: float = 45.0
const THINK: float = 2.0
const RESEND: float = 12.0
const SLOT_TOL: float = 40.0
const PLAN_MIN: float = 60.0
const PLAN_MAX_K: float = 0.85
const LEG: float = 600.0
const HOLD_RETREAT: float = 0.75
const AI_HOLD_RETREAT: float = 0.5
const REJOIN_HP: float = 0.7
const STORM_RETREAT: float = 0.5
const AI_STORM_RETREAT: float = 0.7
const FINAL_T: float = 480.0
const LEG_T: float = 150.0
const ARRIVE: float = 70.0
const ARRIVE_SHARE: float = 0.5
const LINE_GAP: float = 60.0
const OBJ_R: float = 200.0
const STALL_T: float = 90.0
const AI_STALL_T: float = 30.0
const AI_DT: float = 15.0
const AI_SHARE: Array = [0.5, 0.6, 0.7]
const AI_REPLAN: Array = [60.0, 40.0, 30.0]
const AI_CALM: float = 180.0
const AI_WAR_SHARE: float = 0.8
const AI_MIN_ATT: int = 1
const AI_LEG: float = 1000.0
const AI_ARRIVE: float = 0.5
const SUP_STYLES: Array = ["support"]

const STORM_RATIO: float = 2.0
const STORM_TRIES: int = 2
const STORM_REINF: float = 1.25
const SIEGE_SHORT: float = 200.0
const SIEGE_T: float = 240.0
const SIEGE_HEAL: float = 0.4
const WAVE_GAP: float = 60.0
const AVOID_T: float = 600.0

const SECTOR_R: float = 1100.0
const BREAK_DEPTH: float = 60.0
const CITY_THREAT_R: float = 260.0
const RELIEF_RETREAT: float = 0.85
const REACT_MAX: int = 3
const REACT_CALM: float = 30.0
const REACT_MAX_T: float = 300.0
const DIG_HOLD_T: float = 30.0
const DIG_CELLS: int = 9
const DIG_RESERVE: int = 800
const AI_REACT_DELAY: Array = [45.0, 30.0, 20.0]

static var ai_on: bool = true
static var ai_plans: bool = true
static var _next: Dictionary = {}
static var _slots: Dictionary = {}
static var _retry: Dictionary = {}
static var why_of: Dictionary = {}
static var _ai_t: Dictionary = {}
static var stats: Dictionary = {}
static var _react: Dictionary = {}
static var _threat_t: Dictionary = {}




static func front_of(g: Dictionary) -> Dictionary:
	var f: Variant = g.get("front", {})
	return f if f is Dictionary else {}


static func plan_of(g: Dictionary) -> Dictionary:
	var p: Variant = g.get("plan", {})
	return p if p is Dictionary else {}


static func running(g: Dictionary) -> bool:
	var p: Dictionary = plan_of(g)
	return not p.is_empty() and int(p.get("state", 0)) == St.RUN


static func _stat(k: String, n: int = 1) -> void :
	stats[k] = int(stats.get(k, 0)) + n


static func _key(cid: int, gid: int) -> String:
	return "%d:%d" % [cid, gid]


static func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))


static func owner_at(gw: GameWorld, p: Vector2) -> int:
	var c: Vector2i = _cell(p)
	return gw.data.get_owner_id(c.x, c.y) if gw.data.inside(c.x, c.y) else -1



static func holds_fac(gw: GameWorld, f: Facility) -> bool:
	if f == null or f.group_id < 0:
		return false
	var g: Dictionary = ArmyGroups.by_id(gw, f.country_id, f.group_id)
	return not g.is_empty() and not front_of(g).is_empty()


static func _style(gw: GameWorld, f: Facility) -> String:
	return String(gw.army.build_of(f).get("style", "mix"))


static func is_support(gw: GameWorld, f: Facility) -> bool:
	return SUP_STYLES.has(_style(gw, f))



static func members(gw: GameWorld, cid: int, g: Dictionary) -> Array[Facility]:
	var out: Array[Facility] = []
	for fid: int in g.get("fids", PackedInt32Array()):
		var f: Facility = ArmyGroups.fac(gw, fid)
		if not ArmyGroups.valid_member(gw, cid, f):
			continue
		if gw.naval != null and gw.naval.busy(f):
			continue
		if gw.ops._army(f).size() < 2:
			continue
		out.append(f)
	return out



static func centre(gw: GameWorld, cid: int, g: Dictionary) -> Vector2:
	var s: = Vector2.ZERO
	var n: int = 0
	for fid: int in g.get("fids", PackedInt32Array()):
		var f: Facility = ArmyGroups.fac(gw, fid)
		if not ArmyGroups.valid_member(gw, cid, f):
			continue
		var mem: Array[Unit] = gw.ops._army(f)
		s += gw.ops._centre(mem) if not mem.is_empty() else f.center_px()
		n += 1
	return s / float(n) if n > 0 else Vector2.INF






static func _scan(gw: GameWorld, cid: int, foe: int, at: Vector2, r: float) -> Dictionary:
	var d: WorldData = gw.data
	var w: int = d.w
	var h: int = d.h
	var ow: PackedByteArray = d.owners
	var c0: Vector2i = _cell(at)
	var rc: int = ceili(r / float(GameWorld.CELL))
	var m2: int = SCAN * 3
	var x0: int = clampi(c0.x - rc, m2, w - 1 - m2)
	var x1: int = clampi(c0.x + rc, m2, w - 1 - m2)
	var y0: int = clampi(c0.y - rc, m2, h - 1 - m2)
	var y1: int = clampi(c0.y + rc, m2, h - 1 - m2)
	if ow.size() < w * h or x1 <= x0 or y1 <= y0:
		return {"foe": -1, "pts": []}
	var off: Array[int] = [SCAN, - SCAN, SCAN * w, - SCAN * w]
	var dv: Array[Vector2] = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	var half: float = float(SCAN * GameWorld.CELL) * 0.5
	var by: Dictionary = {}
	var best_o: int = -1
	var best_d: float = INF
	for y in range(y0, y1 + 1, SCAN):
		var row: int = y * w
		for x in range(x0, x1 + 1, SCAN):
			var i: int = row + x
			if ow[i] != cid:
				continue
			for k in 4:
				var o: int = ow[i + off[k]]
				if o == 0:
					o = ow[i + off[k] * 2]
					if o == 0:
						o = ow[i + off[k] * 3]
				if o == cid or o == 0 or (foe >= 0 and o != foe):
					continue
				var p: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5) * float(GameWorld.CELL) + dv[k] * half
				if not by.has(o):
					by[o] = []
				(by[o] as Array).append(p)
				if foe < 0:
					var dd: float = p.distance_squared_to(at)
					if dd < best_d:
						best_d = dd
						best_o = o
				break
	var pick: int = foe if foe >= 0 else best_o
	return {"foe": pick if by.has(pick) else -1, "pts": by.get(pick, [])}




static func _chain(raw: Array, at: Vector2, ref: PackedVector2Array = PackedVector2Array()) -> PackedVector2Array:
	var out: = PackedVector2Array()
	var n: int = raw.size()
	if n < 3:
		return out
	var link: float = float(SCAN * GameWorld.CELL) * 1.95
	var l2: float = link * link
	var grid: Dictionary = {}
	for i in n:
		var p: Vector2 = raw[i]
		var k: = Vector2i(floori(p.x / link), floori(p.y / link))
		if not grid.has(k):
			grid[k] = PackedInt32Array()
		var arr: PackedInt32Array = grid[k]
		arr.append(i)
		grid[k] = arr
	var start: int = 0
	var bd: float = INF
	for i2 in n:
		var dd: float = (raw[i2] as Vector2).distance_squared_to(at)
		if dd < bd:
			bd = dd
			start = i2
	if ref.size() >= 2:
		start = _ref_start(raw, grid, link, l2, ref, start)
	var far: Array = _bfs(raw, grid, link, l2, start)
	var e1: int = int(far[0])
	var res: Array = _bfs(raw, grid, link, l2, e1)
	var e2: int = int(res[0])
	var par: PackedInt32Array = res[1]
	var path: Array = []
	var cur: int = e2
	var guard: int = 0
	while cur >= 0 and guard < n + 2:
		path.append(raw[cur])
		cur = par[cur]
		guard += 1
	if path.size() < 3:
		return out

	var sm: = PackedVector2Array()
	for i3 in path.size():
		var s: = Vector2.ZERO
		var c: int = 0
		for j in range(maxi(0, i3 - 2), mini(path.size(), i3 + 3)):
			s += path[j]
			c += 1
		sm.append(s / float(c))
	sm[0] = path[0]
	sm[sm.size() - 1] = path[path.size() - 1]
	return resample(sm, STEP)



static func _bfs(raw: Array, grid: Dictionary, link: float, l2: float, from: int) -> Array:
	var n: int = raw.size()
	var par: = PackedInt32Array()
	par.resize(n)
	par.fill(-2)
	par[from] = -1
	var q: = PackedInt32Array([from])
	var qi: int = 0
	var last: int = from
	while qi < q.size():
		var i: int = q[qi]
		qi += 1
		last = i
		var p: Vector2 = raw[i]
		var k: = Vector2i(floori(p.x / link), floori(p.y / link))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var cell: Variant = grid.get(k + Vector2i(dx, dy))
				if cell == null:
					continue
				for j: int in (cell as PackedInt32Array):
					if par[j] != -2 or (raw[j] as Vector2).distance_squared_to(p) > l2:
						continue
					par[j] = i
					q.append(j)
	return [last, par]



static func resample(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	var out: = PackedVector2Array()
	if pts.size() < 2:
		return pts.duplicate()
	out.append(pts[0])
	var carry: float = 0.0
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var seg: float = a.distance_to(b)
		var t: float = step - carry
		while t <= seg:
			out.append(a.lerp(b, t / seg))
			t += step
		carry = seg - (t - step)
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > step * 0.35:
		out.append(pts[pts.size() - 1])
	return out


static func poly_len(pts: PackedVector2Array) -> float:
	var s: float = 0.0
	for i in range(1, pts.size()):
		s += pts[i - 1].distance_to(pts[i])
	return s



static func _clip(pts: PackedVector2Array, at: Vector2, L: float) -> PackedVector2Array:
	var n: int = pts.size()
	if n < 2:
		return pts
	var cum: = PackedFloat32Array()
	cum.resize(n)
	cum[0] = 0.0
	var ia: int = 0
	var bd: float = INF
	for i in n:
		if i > 0:
			cum[i] = cum[i - 1] + pts[i - 1].distance_to(pts[i])
		var dd: float = pts[i].distance_squared_to(at)
		if dd < bd:
			bd = dd
			ia = i
	var T: float = cum[n - 1]
	if T <= L:
		return pts
	var a: float = clampf(cum[ia] - L * 0.5, 0.0, T - L)
	var b: float = a + L
	var out: = PackedVector2Array()
	for i2 in n:
		if cum[i2] >= a and cum[i2] <= b:
			out.append(pts[i2])
	return out



static func _normals(gw: GameWorld, cid: int, foe: int, pts: PackedVector2Array) -> PackedVector2Array:
	var n: int = pts.size()
	var raw: = PackedVector2Array()
	var prev: = Vector2.ZERO
	for i in n:
		var t: Vector2 = pts[mini(i + 2, n - 1)] - pts[maxi(i - 2, 0)]
		t = t.normalized() if t.length() > 0.01 else Vector2.RIGHT
		var nv: = Vector2( - t.y, t.x)
		var vote: int = 0
		for dd: float in [10.0, 22.0, 40.0]:
			var o1: int = owner_at(gw, pts[i] + nv * dd)
			var o2: int = owner_at(gw, pts[i] - nv * dd)
			if o1 == foe:
				vote += 1
			elif o1 == cid:
				vote -= 1
			if o2 == foe:
				vote -= 1
			elif o2 == cid:
				vote += 1
		if vote < 0 or (vote == 0 and prev != Vector2.ZERO and nv.dot(prev) < 0.0):
			nv = - nv
		raw.append(nv)
		prev = nv
	var out: = PackedVector2Array()
	for i2 in n:
		var s: = Vector2.ZERO
		for j in range(maxi(0, i2 - 3), mini(n, i2 + 4)):
			s += raw[j] if raw[j].dot(raw[i2]) >= 0.0 else - raw[j]
		out.append(s.normalized() if s.length() > 0.01 else raw[i2])
	return out




static func border_geo(gw: GameWorld, cid: int, foe: int, at: Vector2, max_len: float, scan_r: float = SCAN_R, allow_short: bool = true, ref: PackedVector2Array = PackedVector2Array()) -> Dictionary:
	var sc: Dictionary = _scan(gw, cid, foe, at, scan_r)
	var raw: Array = sc["pts"]
	if int(sc["foe"]) < 0 or raw.is_empty():
		return {"ok": false, "why": Loc.t("Нет общей границы рядом")}
	var fo: int = int(sc["foe"])
	var ch: PackedVector2Array = _chain(raw, at, ref) if raw.size() >= 3 else PackedVector2Array()
	var cat: Vector2 = at
	if ch.size() >= 3 and ref.size() >= 2:
		cat = nearest_on(ch, ref[ref.size() / 2])
	if ch.size() >= 3:
		ch = _clip(ch, cat, max_len)
		if ref.size() >= 2 and _flipped(ch, ref):
			ch.reverse()
	if ch.size() < 3 or poly_len(ch) < SHORT_FRONT:
		if not allow_short:
			return {"ok": false, "why": Loc.t("Граница слишком короткая")}
		return _short_geo(gw, cid, fo, raw, ch)
	return {"ok": true, "foe": fo, "pts": ch, "nrm": _normals(gw, cid, fo, ch), "len": poly_len(ch), "cat": cat}




static func _short_geo(gw: GameWorld, cid: int, fo: int, raw: Array, ch: PackedVector2Array) -> Dictionary:
	var cen: = Vector2.ZERO
	for q: Vector2 in raw:
		cen += q
	cen /= float(raw.size())
	var nv: = Vector2.ZERO
	for a in range(0, 360, 20):
		var d: = Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a)))
		for r: float in [16.0, 32.0, 56.0]:
			var o: int = owner_at(gw, cen + d * r)
			if o == fo:
				nv += d
			elif o == cid:
				nv -= d * 0.5
	if nv.length() < 0.01:
		var fc: Country = gw.country_by_id(fo)
		nv = (Vector2(gw.cities[fc.capital_id].center * GameWorld.CELL) - cen) if fc != null and fc.capital_id >= 0 else Vector2.RIGHT
	nv = nv.normalized()
	var tv: = Vector2( - nv.y, nv.x)
	var pts: = PackedVector2Array()
	var nrm: = PackedVector2Array()
	var n: int = ceili(SHORT_FRONT / STEP)
	for i in n + 1:
		pts.append(cen + tv * (float(i) / float(n) - 0.5) * SHORT_FRONT)
		nrm.append(nv)
	return {"ok": true, "foe": fo, "pts": pts, "nrm": nrm, "len": SHORT_FRONT, "short": true}




const VIS_PUSH: float = 3.0
const VIS_MAX: float = 150.0
const VIS_MARGIN: float = 4.0




static func _edge_scan(gw: GameWorld, cid: int, at: Vector2, r: float) -> Array:
	var d: WorldData = gw.data
	var w: int = d.w
	var h: int = d.h
	var ow: PackedByteArray = d.owners
	var c0: Vector2i = _cell(at)
	var rc: int = ceili(r / float(GameWorld.CELL))
	var x0: int = clampi(c0.x - rc, SCAN, w - 1 - SCAN)
	var x1: int = clampi(c0.x + rc, SCAN, w - 1 - SCAN)
	var y0: int = clampi(c0.y - rc, SCAN, h - 1 - SCAN)
	var y1: int = clampi(c0.y + rc, SCAN, h - 1 - SCAN)
	var out: Array = []
	if ow.size() < w * h:
		return out
	var off: Array[int] = [SCAN, - SCAN, SCAN * w, - SCAN * w]
	for y in range(y0, y1 + 1, SCAN):
		for x in range(x0, x1 + 1, SCAN):
			var i: int = y * w + x
			if ow[i] != cid:
				continue
			for k in 4:
				var j: int = i + off[k]
				if ow[j] != cid and (ow[j] > 0 or not Biome.is_water(d.biome[j])):
					out.append(Vector2(float(x) + 0.5, float(y) + 0.5) * float(GameWorld.CELL))
					break
	return out






static func with_vis(gw: GameWorld, cid: int, fr: Dictionary) -> void :
	var pts: PackedVector2Array = fr["pts"]
	var nrm: PackedVector2Array = fr["nrm"]
	var vk: String = String(fr.get("kind", "border"))
	if vk == "drawn" or (vk == "line" and pts.size() >= 2):


		var vp: PackedVector2Array = pts
		var vn0: = PackedVector2Array()
		if vk == "line":
			var lp: Array = []
			for pp: PackedVector2Array in land_parts(gw, cid, pts, 0):
				lp.append(smooth_part(gw, cid, pp, 0))
			vp = join_parts(lp) if not lp.is_empty() else pts
			for q0: Vector2 in vp:
				vn0.append(nrm[0])
		fr["vis"] = vp
		fr["vnrm"] = nrm if vk == "drawn" else vn0
		return
	if pts.size() < 2:
		fr["vis"] = pts
		fr["vnrm"] = nrm
		return
	var src: PackedVector2Array = pts
	var sn: PackedVector2Array = nrm
	if bool(fr.get("short", false)):
		var cen: Vector2 = (pts[0] + pts[pts.size() - 1]) * 0.5
		var raw: Array = _edge_scan(gw, cid, cen, SHORT_FRONT * 0.75)
		if raw.size() >= 3:
			var ch: PackedVector2Array = _chain(raw, cen)
			if ch.size() >= 3:
				ch = _clip(ch, cen, SHORT_FRONT)
				src = ch
				sn = PackedVector2Array()
				for q: Vector2 in ch:
					sn.append(nrm[0])
	var pushed: = PackedVector2Array()
	var pn: = PackedVector2Array()
	for i in src.size():
		var n0: Vector2 = sn[mini(i, sn.size() - 1)]
		var q: Vector2 = _onto_own(gw, cid, src[i], n0)
		if q.is_finite():
			pushed.append(q)
			pn.append(n0)
	if pushed.size() < 2:
		fr["vis"] = pts
		fr["vnrm"] = nrm
		return

	var sm: = PackedVector2Array()
	for i2 in pushed.size():
		var a: = Vector2.ZERO
		var k: int = 0
		for j in range(maxi(0, i2 - 2), mini(pushed.size(), i2 + 3)):
			a += pushed[j]
			k += 1
		var q2: Vector2 = _onto_own(gw, cid, a / float(k), pn[i2])
		sm.append(q2 if q2.is_finite() else pushed[i2])
	var vis: PackedVector2Array = resample(sm, STEP * 0.5)
	var vn: = PackedVector2Array()
	var keep: = PackedVector2Array()
	for i3 in vis.size():
		var t: Vector2 = vis[mini(i3 + 1, vis.size() - 1)] - vis[maxi(i3 - 1, 0)]
		t = t.normalized() if t.length() > 0.01 else Vector2.RIGHT
		var nv: = Vector2( - t.y, t.x)
		var ref: Vector2 = pn[clampi(roundi(float(i3) / float(maxi(1, vis.size() - 1)) * float(pn.size() - 1)), 0, pn.size() - 1)]
		if nv.dot(ref) < 0.0:
			nv = - nv
		var q3: Vector2 = vis[i3] if line_ok(gw, cid, vis[i3], 1) else _onto_own(gw, cid, vis[i3], nv)
		if q3.is_finite():
			keep.append(q3)
			vn.append(nv)


	if keep.size() >= 2:
		var vparts: Array = []
		var nparts: Array = []
		var lens: Array = []
		for pr: Array in split_parts(keep):
			var a0: int = int(pr[0])
			var b0: int = int(pr[1])
			if b0 - a0 < 1:
				continue
			var seg: PackedVector2Array = smooth_part(gw, cid, keep.slice(a0, b0 + 1), 1)
			var snv: = PackedVector2Array()
			for i4 in seg.size():
				var ii: int = clampi(a0 + roundi(float(i4) / float(maxi(1, seg.size() - 1)) * float(b0 - a0)), a0, b0)
				snv.append(vn[ii])
			vparts.append(seg)
			nparts.append(snv)
			lens.append(poly_len(seg))
		var kept: Array = _drop_stubs(vparts)
		var k2: = PackedVector2Array()
		var n2: = PackedVector2Array()
		for i5 in vparts.size():
			if kept.has(vparts[i5]):
				k2.append_array(vparts[i5])
				n2.append_array(nparts[i5])
		if k2.size() >= 2:
			keep = k2
			vn = n2
	if keep.size() < 2 or poly_len(keep) < minf(float(fr.get("len", 0.0)), SHORT_FRONT) * 0.4:


		var fb: Array = land_parts(gw, cid, pts, 1)
		if not fb.is_empty():
			keep = join_parts(fb)
			vn = PackedVector2Array()
			for q6: Vector2 in keep:
				var bi6: int = 0
				var bd6: float = INF
				for i6 in range(0, pts.size()):
					var d6: float = pts[i6].distance_squared_to(q6)
					if d6 < bd6:
						bd6 = d6
						bi6 = i6
				vn.append(nrm[mini(bi6, nrm.size() - 1)])
			_stat("vis_fallback")
	fr["vis"] = keep if keep.size() >= 2 else pts
	fr["vnrm"] = vn if keep.size() >= 2 else nrm




static func _onto_own(gw: GameWorld, cid: int, p: Vector2, n: Vector2) -> Vector2:
	var q: Vector2 = p
	var d: float = 0.0
	while d <= VIS_MAX:
		if owner_at(gw, q) == cid and owner_at(gw, q - n * VIS_MARGIN) == cid and line_ok(gw, cid, q, 1) and line_ok(gw, cid, q - n * VIS_MARGIN * 0.5, 1):
			return q - n * VIS_MARGIN * 0.5
		q -= n * VIS_PUSH
		d += VIS_PUSH
	return Vector2.INF


static func _cname(gw: GameWorld, id: int) -> String:
	var c: Country = gw.country_by_id(id)
	return c.name if c != null else "?"




const GAP_JOIN: float = 44.0
const PART_MIN: float = 110.0
const PART_SHARE: float = 0.15
const JUMP: float = 30.0
const DRAW_MIN: float = 64.0
const SNAP_R: float = 40.0
const DRAW_MAX: float = 4000.0
const DRAW_DEPTH: float = 22.0
const DRAW_SUP: float = 120.0
const REF_R: float = 320.0
const KEEP_MOVE: float = 14.0
const NEAR_B: float = 500.0
static var _ally_ok: bool = false





static func line_ok(gw: GameWorld, cid: int, p: Vector2, mode: int) -> bool:
	var c: Vector2i = _cell(p)
	var d: WorldData = gw.data
	if not d.inside(c.x, c.y) or Biome.is_water(d.get_biome(c.x, c.y)) or d.has_flag(c.x, c.y, WorldData.F_BRIDGE):
		return false
	if mode == 0:
		return true
	var o: int = d.get_owner_id(c.x, c.y)
	return o == cid or (mode == 2 and hold_land(gw, cid, o))




static func hold_land(gw: GameWorld, cid: int, o: int) -> bool:
	return o == cid or (o > 0 and gw.diplo != null and (gw.diplo.allied(cid, o) or gw.diplo.has_passage(cid, o) or gw.diplo.ally.same(cid, o)))






static func drawn_parts(gw: GameWorld, cid: int, pts: PackedVector2Array) -> Array:
	var parts: Array = []
	if pts.size() < 2:
		return parts
	var offs: Array[Vector2i] = _snap_offs()
	var okc: Dictionary = {}
	var dense: PackedVector2Array = resample(pts, 8.0)
	var cur: = PackedVector2Array()
	var gap: int = 0
	for q: Vector2 in dense:
		var s: Vector2 = _snap_to(gw, cid, q, offs, okc)
		if not s.is_finite():
			if not cur.is_empty():
				gap += 1
			continue
		if gap > 0 and float(gap + 1) * 8.0 > GAP_JOIN:
			if cur.size() >= 2:
				parts.append(cur)
			cur = PackedVector2Array()
		gap = 0
		if cur.is_empty() or cur[cur.size() - 1].distance_squared_to(s) > 4.0:
			cur.append(s)
	if cur.size() >= 2:
		parts.append(cur)
	return _drop_stubs(parts)




static func _cell_ok(gw: GameWorld, cid: int, x: int, y: int, okc: Dictionary) -> bool:
	var d: WorldData = gw.data
	if not d.inside(x, y) or Biome.is_water(d.get_biome(x, y)) or d.has_flag(x, y, WorldData.F_BRIDGE):
		return false
	var o: int = d.get_owner_id(x, y)
	if o == cid:
		return true
	if not okc.has(o):
		okc[o] = hold_land(gw, cid, o)
	return bool(okc[o])



static func _snap_offs() -> Array[Vector2i]:
	var offs: Array[Vector2i] = []
	var rc: int = ceili(SNAP_R / float(GameWorld.CELL))
	for oy in range( - rc, rc + 1, 2):
		for ox in range( - rc, rc + 1, 2):
			if ox * ox + oy * oy <= rc * rc and (ox != 0 or oy != 0):
				offs.append(Vector2i(ox, oy))
	offs.sort_custom( func(a: Vector2i, b: Vector2i) -> bool:
		var la: int = a.x * a.x + a.y * a.y
		var lb: int = b.x * b.x + b.y * b.y
		return la < lb if la != lb else (a.y < b.y if a.y != b.y else a.x < b.x))
	return offs




static func _snap_to(gw: GameWorld, cid: int, q: Vector2, offs: Array[Vector2i], okc: Dictionary) -> Vector2:
	var c0: Vector2i = _cell(q)
	if _cell_ok(gw, cid, c0.x, c0.y, okc):
		return q

	var d: WorldData = gw.data
	var w: int = d.w
	var h: int = d.h
	var bio: PackedByteArray = d.biome
	var own: PackedByteArray = d.owners
	var fl: PackedByteArray = d.flags
	for o: Vector2i in offs:
		var x: int = c0.x + o.x
		var y: int = c0.y + o.y
		if x < 0 or y < 0 or x >= w or y >= h:
			continue
		var i: int = y * w + x
		if bio[i] <= Biome.RIVER or (fl[i] & WorldData.F_BRIDGE) != 0:
			continue
		var ow: int = own[i]
		if ow != cid:
			if ow <= 0:
				continue
			if not okc.has(ow):
				okc[ow] = hold_land(gw, cid, ow)
			if not bool(okc[ow]):
				continue
		return (Vector2(x, y) + Vector2(0.5, 0.5)) * float(GameWorld.CELL)
	return Vector2.INF



static func _draw_why(gw: GameWorld, cid: int, src: PackedVector2Array, kept: float) -> String:
	var n: int = 0
	var wet: int = 0
	var ok: int = 0
	var shut: Dictionary = {}
	var okc: Dictionary = {}
	var d: WorldData = gw.data
	for q: Vector2 in resample(src, 8.0):
		n += 1
		var c: Vector2i = _cell(q)
		if not d.inside(c.x, c.y) or Biome.is_water(d.get_biome(c.x, c.y)):
			wet += 1
		elif _cell_ok(gw, cid, c.x, c.y, okc):
			ok += 1
		else:
			var o: int = d.get_owner_id(c.x, c.y)
			shut[o] = int(shut.get(o, 0)) + 1
	var so: int = -1
	var sn: int = 0
	for o2: int in shut:
		if int(shut[o2]) > sn:
			sn = int(shut[o2])
			so = o2
	if ok == 0 and sn == 0:
		return Loc.t("Линия на воде — ведите по суше: своей, союзной или где есть право прохода")
	if sn > wet and sn * 2 >= n - ok:
		var who: String = Loc.t("Ничейная земля") if so <= 0 else Loc.t("Земля %s") % _cname(gw, so)
		return Loc.t("%s закрыта: нет союза и права прохода — ведите по своей или союзной земле, у границы") % who
	if kept > 1.0:
		return Loc.t("На доступной земле только %d м линии (нужно от %d м) — ведите дальше по суше") % [roundi(kept), roundi(DRAW_MIN)]
	return Loc.t("Линия на воде — ведите по суше: своей, союзной или где есть право прохода")




static func _far_foe(gw: GameWorld, cid: int, at: Vector2) -> Array:
	var c: Country = gw.country_by_id(cid)
	var best: int = -1
	var bp: Vector2 = Vector2.INF
	var bd: float = INF
	for o: Country in gw.countries:
		if o.id == cid or o.eliminated or hold_land(gw, cid, o.id):
			continue
		for ci: int in o.city_ids:
			if ci < 0 or ci >= gw.cities.size():
				continue
			var cp: Vector2 = Vector2(gw.cities[ci].center * GameWorld.CELL)
			var dd: float = cp.distance_to(at) * (0.4 if c != null and c.at_war.has(o.id) else 1.0)
			if dd < bd:
				bd = dd
				best = o.id
				bp = cp
	return [best, bp]





static func land_parts(gw: GameWorld, cid: int, pts: PackedVector2Array, mode: int) -> Array:
	var parts: Array = []
	if pts.size() < 2:
		return parts
	var dense: PackedVector2Array = resample(pts, 8.0)
	var cur: = PackedVector2Array()
	var gap: = PackedVector2Array()
	for q: Vector2 in dense:
		if line_ok(gw, cid, q, mode):
			if not gap.is_empty():
				if not cur.is_empty() and float(gap.size() + 1) * 8.0 <= GAP_JOIN:
					cur.append_array(gap)
				else:
					if cur.size() >= 2:
						parts.append(cur)
					cur = PackedVector2Array()
				gap = PackedVector2Array()
			cur.append(q)
		elif not cur.is_empty():
			gap.append(q)
	if cur.size() >= 2:
		parts.append(cur)
	return _drop_stubs(parts)


static func _drop_stubs(parts: Array) -> Array:
	var longest: float = 0.0
	var li: int = -1
	for i in parts.size():
		var l: float = poly_len(parts[i])
		if l > longest:
			longest = l
			li = i
	var out: Array = []
	for i2 in parts.size():
		var l2: float = poly_len(parts[i2])
		if i2 == li or (l2 >= PART_MIN and l2 >= longest * PART_SHARE):
			out.append(parts[i2])
	return out



static func smooth_part(gw: GameWorld, cid: int, part: PackedVector2Array, mode: int) -> PackedVector2Array:
	var p: PackedVector2Array = resample(part, STEP)
	for k in 2:
		var sm: = PackedVector2Array()
		for i in p.size():
			if i == 0 or i == p.size() - 1:
				sm.append(p[i])
				continue
			var s: = Vector2.ZERO
			var n: int = 0
			for j in range(maxi(0, i - 2), mini(p.size(), i + 3)):
				s += p[j]
				n += 1
			var q: Vector2 = s / float(n)
			sm.append(q if line_ok(gw, cid, q, mode) else p[i])
		p = sm
	return p



static func join_parts(parts: Array) -> PackedVector2Array:
	var out: = PackedVector2Array()
	for pp: PackedVector2Array in parts:
		out.append_array(pp)
	return out



static func split_parts(pts: PackedVector2Array) -> Array:
	var out: Array = []
	if pts.is_empty():
		return out
	var s: int = 0
	for i in range(1, pts.size()):
		if pts[i - 1].distance_to(pts[i]) > JUMP:
			out.append([s, i - 1])
			s = i
	out.append([s, pts.size() - 1])
	return out



static func part_normals(pts: PackedVector2Array, sgn: float) -> PackedVector2Array:
	var out: = PackedVector2Array()
	out.resize(pts.size())
	for pr: Array in split_parts(pts):
		var a: int = int(pr[0])
		var b: int = int(pr[1])
		for i in range(a, b + 1):
			var t: Vector2 = pts[mini(i + 2, b)] - pts[maxi(i - 2, a)]
			t = t.normalized() if t.length() > 0.01 else Vector2.RIGHT
			out[i] = Vector2( - t.y, t.x) * sgn
	return out



static func line_moved(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if a.size() < 2 or b.is_empty():
		return INF
	var s: float = 0.0
	var n: int = 0
	for i in range(0, b.size(), 2):
		s += nearest_on(a, b[i]).distance_to(b[i])
		n += 1
	return s / float(maxi(1, n))



static func _flipped(ch: PackedVector2Array, ref: PackedVector2Array) -> bool:
	if ch.size() < 2 or ref.size() < 2:
		return false
	var a0: Vector2 = ch[0]
	var a1: Vector2 = ch[ch.size() - 1]
	var r0: Vector2 = ref[0]
	var r1: Vector2 = ref[ref.size() - 1]
	return a0.distance_to(r1) + a1.distance_to(r0) < a0.distance_to(r0) + a1.distance_to(r1)





static func _ref_start(raw: Array, grid: Dictionary, link: float, l2: float, ref: PackedVector2Array, fallback: int) -> int:
	var n: int = raw.size()
	var rs: PackedVector2Array = resample(ref, 48.0)
	var mid: Vector2 = ref[ref.size() / 2]
	var lab: = PackedInt32Array()
	lab.resize(n)
	lab.fill(-1)
	var comp: int = 0
	var score: Dictionary = {}
	var best_i: Dictionary = {}
	var r2: float = REF_R * REF_R
	for i in n:
		if lab[i] >= 0:
			continue
		var res: Array = _bfs(raw, grid, link, l2, i)
		var par: PackedInt32Array = res[1]
		var sc: int = 0
		var cnt: int = 0
		var bi: int = i
		var bd: float = INF
		for j in n:
			if par[j] == -2 or lab[j] >= 0:
				continue
			lab[j] = comp
			cnt += 1
			var q: Vector2 = raw[j]
			for r: Vector2 in rs:
				if r.distance_squared_to(q) < r2:
					sc += 1
					break
			var dd: float = q.distance_squared_to(mid)
			if dd < bd:
				bd = dd
				bi = j
		score[comp] = sc * 4 + mini(cnt, 60)
		best_i[comp] = [bi, bd]
		comp += 1
		if comp > 64:
			break
	var pick: int = -1
	var ps: int = 0
	var pd: float = INF
	for k: int in score:
		var s: int = int(score[k])
		var d: float = float(best_i[k][1])
		if s > ps or (s == ps and s > 0 and d < pd):
			ps = s
			pd = d
			pick = k
	if pick < 0:
		return fallback
	_stat("front_ref_pick")
	return int(best_i[pick][0])





static func front_from_line(gw: GameWorld, cid: int, gid: int, raw: PackedVector2Array, sgn0: float = 0.0, foe0: int = -1) -> Dictionary:
	var g: Dictionary = ArmyGroups.by_id(gw, cid, gid)
	if g.is_empty():
		return {"ok": false, "why": Loc.t("Нет такой группы")}
	if (g["fids"] as PackedInt32Array).is_empty():
		return {"ok": false, "why": Loc.t("В группе нет армий")}
	var c: Country = gw.country_by_id(cid)
	if c == null or raw.size() < 2:
		return {"ok": false, "why": Loc.t("Нарисуйте линию пальцем")}
	var src: PackedVector2Array = resample(raw, 12.0)
	if src.size() > 400:
		src = resample(raw, poly_len(raw) / 399.0)
	var L0: float = poly_len(src)
	if L0 < DRAW_MIN:
		return {"ok": false, "why": Loc.t("Слишком короткая линия — ведите дальше")}
	if L0 > DRAW_MAX:
		return {"ok": false, "why": Loc.t("Слишком длинная линия: до %.1f км") % (DRAW_MAX / 1000.0)}
	var geo: Dictionary = _drawn_geo(gw, cid, src, sgn0, foe0)
	if not bool(geo.get("ok", false)):
		return geo
	var fo: int = int(geo["foe"])
	var gp: PackedVector2Array = geo["pts"]
	geo["kind"] = "drawn"
	geo["raw"] = src
	geo["at"] = gp[gp.size() / 2]
	geo["want"] = float(geo["len"])
	var n2: int = 0
	var n1: int = 0
	for f: Facility in members(gw, cid, g):
		if is_support(gw, f):
			n2 += 1
		else:
			n1 += 1
	if n1 == 0:
		n1 = n2
		n2 = 0
	geo["n1"] = n1
	geo["n2"] = n2
	var blk: int = 0
	var mid: Vector2 = gp[gp.size() / 2]
	var nchk: int = 0
	for fm: Facility in members(gw, cid, g):
		if nchk >= 4:
			break
		nchk += 1
		var m0: Array[Unit] = gw.ops._army(fm)
		var b0: int = gw.diplo.path_block(cid, gw.econ.nav_path(gw.ops._centre(m0) if not m0.is_empty() else fm.center_px(), mid))
		if b0 > 0 and b0 != fo:
			blk = b0
			break
	geo["pass"] = blk
	var war: bool = c.at_war.has(fo)
	var np: int = int(geo.get("parts", 1))

	var hosts: Dictionary = {}
	for qh: Vector2 in gp:
		var oh: int = owner_at(gw, qh)
		hosts[oh] = int(hosts.get(oh, 0)) + 1
	var hb: int = cid
	for oh2: int in hosts:
		if oh2 > 0 and int(hosts[oh2]) > int(hosts.get(hb, 0)):
			hb = oh2
	var lbl: String = Loc.t("СВОЙ ФРОНТ") if hb == cid else Loc.t("ФРОНТ НА ЗЕМЛЕ %s") % _cname(gw, hb).to_upper()
	geo["text"] = Loc.t("%s: %s %s · %.1f км · %d в линии%s%s") % [lbl, Loc.t("враг") if war else Loc.t("против"), _cname(gw, fo), float(geo["len"]) / 1000.0, n1, 
		(Loc.t(" + %d поддержка") % n2) if n2 > 0 else "", (Loc.t(" · %d участка") % np) if np > 1 else ""]
	_stat("front_drawn_preview")
	return geo




static func _drawn_geo(gw: GameWorld, cid: int, src: PackedVector2Array, sgn0: float, foe0: int) -> Dictionary:
	var c: Country = gw.country_by_id(cid)
	var nd: int = 0
	var dry: int = 0
	for qd: Vector2 in resample(src, 8.0):
		nd += 1
		var cd: Vector2i = _cell(qd)
		if gw.data.inside(cd.x, cd.y) and not Biome.is_water(gw.data.get_biome(cd.x, cd.y)):
			dry += 1
	if dry * 5 < nd:
		return {"ok": false, "why": _draw_why(gw, cid, src, 0.0)}
	var parts: Array = drawn_parts(gw, cid, src)
	var offs: Array[Vector2i] = _snap_offs()
	var okc: Dictionary = {}
	var sm: Array = []
	var L: float = 0.0
	for pp: PackedVector2Array in parts:
		var q: PackedVector2Array = smooth_part(gw, cid, pp, 2)


		var q2: = PackedVector2Array()
		for v: Vector2 in resample(q, 8.0):
			var sv: Vector2 = _snap_to(gw, cid, v, offs, okc)
			if sv.is_finite() and (q2.is_empty() or q2[q2.size() - 1].distance_squared_to(sv) > 4.0):
				q2.append(sv)
		q = q2
		if q.size() >= 2:
			sm.append(q)
			L += poly_len(q)
	if L < DRAW_MIN:
		return {"ok": false, "why": _draw_why(gw, cid, src, L)}
	var pts: PackedVector2Array = join_parts(sm)
	var sgn: float = sgn0
	var foe: int = foe0
	if sgn == 0.0 or foe <= 0:
		var nl: PackedVector2Array = part_normals(pts, 1.0)
		var score: Array = [0.0, 0.0]
		var foes: Array = [{}, {}]
		for i in range(0, pts.size(), 2):
			for k in 2:
				var sg: float = 1.0 if k == 0 else -1.0
				for dd: float in [60.0, 160.0, 320.0, 640.0, 1000.0]:
					var o: int = owner_at(gw, pts[i] + nl[i] * sg * dd)
					if o <= 0 or hold_land(gw, cid, o):
						continue
					var wt: float = (3.0 if c != null and c.at_war.has(o) else 1.0) * (1.0 if dd < 400.0 else 0.5)
					score[k] = float(score[k]) + wt
					(foes[k] as Dictionary)[o] = float((foes[k] as Dictionary).get(o, 0.0)) + wt
					break
		var kk: int = 0 if float(score[0]) >= float(score[1]) else 1
		if sgn0 != 0.0:
			kk = 0 if sgn0 > 0.0 else 1
		var fd: Dictionary = foes[kk]
		if fd.is_empty():
			fd = foes[1 - kk]
			if fd.is_empty() and foe0 <= 0:


				var ff: Array = _far_foe(gw, cid, pts[pts.size() / 2])
				if int(ff[0]) <= 0:
					return {"ok": false, "why": Loc.t("Рядом нет чужих стран — фронт держать не против кого")}
				var fm: Vector2 = pts[pts.size() / 2]
				var tm: Vector2 = (pts[mini(pts.size() / 2 + 2, pts.size() - 1)] - pts[maxi(pts.size() / 2 - 2, 0)]).normalized()
				kk = 0 if Vector2( - tm.y, tm.x).dot((ff[1] as Vector2) - fm) >= 0.0 else 1
				fd = {int(ff[0]): 1.0}
				_stat("front_drawn_far")
		sgn = 1.0 if kk == 0 else -1.0
		if foe <= 0:
			var bw: float = -1.0
			for o2: int in fd:
				if float(fd[o2]) > bw:
					bw = float(fd[o2])
					foe = o2
	return {"ok": true, "foe": foe, "pts": pts, "nrm": part_normals(pts, sgn), "len": L, "parts": sm.size(), "sgn": sgn}







static var _side: int = -1



static func side_of(gw: GameWorld, cid: int, fr: Dictionary) -> int:
	var h: int = int(fr.get("host", -1))
	if h > 0 and h != cid and gw.diplo != null and gw.diplo.allied(cid, h):
		return h
	return cid




static func ally_front_from_tap(gw: GameWorld, cid: int, g: Dictionary, host: int, p: Vector2) -> Dictionary:
	var nf: int = (g["fids"] as PackedInt32Array).size()
	var stretch: float = clampf(STRETCH_PER * float(nf), STRETCH_MIN, FRONT_MAX)
	var c: Country = gw.country_by_id(cid)
	var hc: Country = gw.country_by_id(host)
	if c == null or hc == null:
		return {"ok": false, "why": Loc.t("Нет такой страны")}
	var cands: Array = []
	for e: int in c.at_war.keys():
		if e != host and not gw.diplo.allied(host, e):
			cands.append(e)
	for e2: int in hc.at_war.keys():
		if e2 != cid and not cands.has(e2):
			cands.append(e2)
	var near: Dictionary = _scan(gw, host, -1, p, BORDER_R * 2.0)
	var n0: int = int(near["foe"])
	if n0 > 0 and n0 != cid and not gw.diplo.allied(cid, n0) and not cands.has(n0):
		cands.append(n0)
	var best: Dictionary = {}
	var bd: float = INF
	for e3: int in cands:
		var geo0: Dictionary = border_geo(gw, host, e3, p, stretch, stretch * 0.6 + BORDER_R)
		if not geo0.get("ok", false):
			continue
		var dd: float = nearest_on(geo0["pts"], p).distance_to(p)
		if dd < bd:
			bd = dd
			best = geo0
	if best.is_empty():
		return {"ok": false, "why": Loc.t("У союзника %s нет границы с врагом рядом") % _cname(gw, host)}
	var fo: int = int(best["foe"])
	best["kind"] = "stretch"
	best["at"] = p
	best["want"] = stretch
	best["host"] = host
	with_vis(gw, host, best)
	var n2: int = 0
	var n1: int = 0
	for f: Facility in members(gw, cid, g):
		if is_support(gw, f):
			n2 += 1
		else:
			n1 += 1
	if n1 == 0:
		n1 = n2
		n2 = 0
	best["n1"] = n1
	best["n2"] = n2
	var gp: PackedVector2Array = best["pts"]
	var mid: Vector2 = gp[gp.size() / 2]
	var blk: int = 0
	var nchk: int = 0
	for fm: Facility in members(gw, cid, g):
		if nchk >= 4:
			break
		nchk += 1
		var m0: Array[Unit] = gw.ops._army(fm)
		var b0: int = gw.diplo.path_block(cid, gw.econ.nav_path(gw.ops._centre(m0) if not m0.is_empty() else fm.center_px(), mid))
		if b0 > 0 and b0 != fo:
			blk = b0
			break
	best["pass"] = blk
	var war: bool = c.at_war.has(fo)
	best["text"] = Loc.t("ФРОНТ У СОЮЗНИКА %s: %s %s · %.1f км · %d в линии%s") % [_cname(gw, host), Loc.t("враг") if war else Loc.t("граница с"), _cname(gw, fo), 
		float(best["len"]) / 1000.0, n1, (Loc.t(" + %d поддержка") % n2) if n2 > 0 else ""]
	_stat("front_ally_preview")
	return best




static func front_from_tap(gw: GameWorld, cid: int, gid: int, p: Vector2) -> Dictionary:
	var g: Dictionary = ArmyGroups.by_id(gw, cid, gid)
	if g.is_empty():
		return {"ok": false, "why": Loc.t("Нет такой группы")}
	var nf: int = (g["fids"] as PackedInt32Array).size()
	if nf == 0:
		return {"ok": false, "why": Loc.t("В группе нет армий")}
	var o: int = owner_at(gw, p)
	var foreign: bool = o > 0 and o != cid
	if foreign and gw.diplo.allied(cid, o):
		var ag: Dictionary = ally_front_from_tap(gw, cid, g, o, p)
		if bool(ag.get("ok", false)):
			return ag
		return _tap_line(gw, cid, gid, g, p, -1)
	var rival: bool = foreign and not hold_land(gw, cid, o)
	if foreign and not rival:




		return _tap_line(gw, cid, gid, g, p, -1)

	var tc: Vector2i = _cell(p)
	if not gw.data.inside(tc.x, tc.y) or Biome.is_water(gw.data.get_biome(tc.x, tc.y)):
		var dry: bool = false
		var rr: int = int(WET_TAP / float(GameWorld.CELL))
		for oy in range( - rr, rr + 1):
			for ox in range( - rr, rr + 1):
				if not dry and gw.data.inside(tc.x + ox, tc.y + oy) and not Biome.is_water(gw.data.get_biome(tc.x + ox, tc.y + oy)):
					dry = true
		if not dry:
			return {"ok": false, "why": Loc.t("Здесь вода — коснитесь суши: своей, союзной или где есть право прохода")}
	var stretch: float = clampf(STRETCH_PER * float(nf), STRETCH_MIN, FRONT_MAX)
	var kind: String = "stretch"
	var at: Vector2 = p
	var want: float = stretch
	var geo: Dictionary = {"ok": false}

	var near: Dictionary = _scan(gw, cid, o if rival else -1, p, BORDER_R)
	if int(near["foe"]) > 0 and (near["pts"] as Array).size() >= 2:
		geo = border_geo(gw, cid, int(near["foe"]), p, stretch, stretch * 0.6 + BORDER_R)

	if not geo.get("ok", false) and rival:
		var cen: Vector2 = centre(gw, cid, g)
		at = cen if cen.is_finite() else p
		kind = "border"
		want = FRONT_MAX
		geo = border_geo(gw, cid, o, at, FRONT_MAX)
		if not geo.get("ok", false):
			geo = border_geo(gw, cid, o, p, FRONT_MAX)
			at = p
		if not geo.get("ok", false):
			return _tap_line(gw, cid, gid, g, p, o)
	if not geo.get("ok", false):
		return _tap_line(gw, cid, gid, g, p, -1)
	var fo: int = int(geo["foe"])
	if gw.diplo.allied(cid, fo):
		return {"ok": false, "why": Loc.t("Это союзник: фронт — против соседа или врага")}
	geo["kind"] = kind
	geo["at"] = at
	geo["want"] = want
	with_vis(gw, cid, geo)
	var n2: int = 0
	var n1: int = 0
	for f: Facility in members(gw, cid, g):
		if is_support(gw, f):
			n2 += 1
		else:
			n1 += 1
	if n1 == 0:
		n1 = n2
		n2 = 0
	geo["n1"] = n1
	geo["n2"] = n2

	var blk: int = 0
	var gp: PackedVector2Array = geo["pts"]
	var mid: Vector2 = gp[gp.size() / 2]
	var nchk: int = 0
	for fm: Facility in members(gw, cid, g):
		if nchk >= 4:
			break
		nchk += 1
		var m0: Array[Unit] = gw.ops._army(fm)
		var b0: int = gw.diplo.path_block(cid, gw.econ.nav_path(gw.ops._centre(m0) if not m0.is_empty() else fm.center_px(), mid))
		if b0 > 0 and b0 != fo:
			blk = b0
			break
	geo["pass"] = blk
	var fc: Country = gw.country_by_id(cid)
	var war: bool = fc != null and fc.at_war.has(fo)
	geo["text"] = Loc.t("%s %s · %.1f км · %d в линии%s") % [Loc.t("ФРОНТ:") if kind == "border" else Loc.t("УЧАСТОК:"), (Loc.t("граница с %s") % [_cname(gw, fo)]) if not war else (Loc.t("враг %s") % [_cname(gw, fo)]), 
		float(geo["len"]) / 1000.0, n1, (Loc.t(" + %d поддержка") % n2) if n2 > 0 else ""]
	return geo







static func _tap_line(gw: GameWorld, cid: int, gid: int, g: Dictionary, p: Vector2, o: int) -> Dictionary:
	var d: WorldData = gw.data
	var at: Vector2 = p
	var foe: int = -1
	var tgt: Vector2 = Vector2.INF
	if o > 0 and o != cid and not hold_land(gw, cid, o):
		var cen: Vector2 = centre(gw, cid, g)
		if not cen.is_finite():
			return {"ok": false, "why": Loc.t("Нет общей границы с %s") % _cname(gw, o)}
		var dist: float = cen.distance_to(p)
		var last: Vector2 = Vector2.INF
		var k: int = 0
		while float(k) * 40.0 <= dist and k < 400:
			var q: Vector2 = cen.lerp(p, float(k) * 40.0 / maxf(dist, 1.0))
			if line_ok(gw, cid, q, 2):
				last = q
			k += 1
		if not last.is_finite():
			return {"ok": false, "why": Loc.t("Нет общей границы с %s — и рядом с армиями нет своей земли") % _cname(gw, o)}
		var back: Vector2 = last.move_toward(cen, 80.0)
		at = back if line_ok(gw, cid, back, 2) else last
		foe = o
		tgt = p
	else:
		var c0: Vector2i = _cell(p)
		if not d.inside(c0.x, c0.y) or Biome.is_water(d.get_biome(c0.x, c0.y)) or d.has_flag(c0.x, c0.y, WorldData.F_BRIDGE):
			return {"ok": false, "why": Loc.t("Здесь вода — коснитесь суши: своей, союзной или где есть право прохода")}
		if not line_ok(gw, cid, p, 2):
			var ow: int = owner_at(gw, p)
			return {"ok": false, "why": Loc.t("%s закрыта: нет союза и права прохода") % (Loc.t("Ничейная земля") if ow <= 0 else Loc.t("Земля %s") % _cname(gw, ow))}
		var ff: Array = _far_foe(gw, cid, p)
		if int(ff[0]) <= 0:
			return {"ok": false, "why": Loc.t("Рядом нет чужих стран — фронт держать не против кого")}
		foe = int(ff[0])
		tgt = ff[1]
	var dv: Vector2 = tgt - at
	dv = dv.normalized() if dv.length() > 1.0 else Vector2.RIGHT
	var nf: int = (g["fids"] as PackedInt32Array).size()
	var L: float = minf(clampf(STRETCH_PER * float(nf), STRETCH_MIN, FRONT_MAX), DRAW_MAX * 0.9)
	var why: String = ""
	for ln: float in [L, L * 0.5]:
		for a: float in [0.0, 25.0, -25.0, 50.0, -50.0, 75.0, -75.0]:
			var tr: Vector2 = Vector2(dv.y, - dv.x).rotated(deg_to_rad(a))
			var stroke: = PackedVector2Array([at - tr * ln * 0.5, at + tr * ln * 0.5])
			var sg: float = 1.0 if Vector2( - tr.y, tr.x).dot(dv) >= 0.0 else -1.0
			var src: PackedVector2Array = resample(stroke, 12.0)
			var dg: Dictionary = _drawn_geo(gw, cid, src, sg, foe)
			if not bool(dg.get("ok", false)):
				if why == "":
					why = String(dg.get("why", ""))
				continue
			var geo: Dictionary = front_from_line(gw, cid, gid, stroke, sg, foe)
			if bool(geo.get("ok", false)):
				_stat("front_tap_line")
			return geo
	return {"ok": false, "why": why if why != "" else Loc.t("Здесь не встать фронтом — коснитесь суши у себя или у союзника")}



static func set_front(gw: GameWorld, cid: int, gid: int, geo: Dictionary, quiet: bool = false) -> bool:
	var g: Dictionary = ArmyGroups.by_id(gw, cid, gid)
	if g.is_empty() or not bool(geo.get("ok", false)):
		return false
	g["front"] = {"foe": int(geo["foe"]), "kind": String(geo.get("kind", "border")), "pts": (geo["pts"] as PackedVector2Array).duplicate(), 
		"nrm": (geo["nrm"] as PackedVector2Array).duplicate(), "len": float(geo["len"]), "at": geo.get("at", (geo["pts"] as PackedVector2Array)[0]), 
		"want": float(geo.get("want", FRONT_MAX)), "t": gw.game_time, "rt": gw.game_time, "short": bool(geo.get("short", false)), 
		"take": gw.game_time}
	for fid0: int in g.get("fids", PackedInt32Array()):
		_retry.erase(fid0)
	if int(geo.get("host", -1)) > 0:
		g["front"]["host"] = int(geo["host"])
	if geo.get("raw") is PackedVector2Array:
		g["front"]["raw"] = (geo["raw"] as PackedVector2Array).duplicate()
		g["front"]["sgn"] = float(geo.get("sgn", 1.0))
	with_vis(gw, side_of(gw, cid, g["front"]), g["front"])
	var pl: Dictionary = plan_of(g)
	if not pl.is_empty() and int(pl["state"]) != St.RUN:
		pl["a"] = nearest_on(g["front"]["pts"], pl["a"])
	_slots.erase(_key(cid, gid))
	_next[_key(cid, gid)] = 0.0
	_stat("front_set")
	var c: Country = gw.country_by_id(cid)
	var n: int = hold(gw, c, g)
	if c != null and c.is_player and not quiet:
		gw.say(c, Loc.mk("Группа «%s»: ФРОНТ — %s, %d %s выдвигаются", [String(g["name"]), Loc.name(_cname(gw, int(geo["foe"]))), n, Operations._armies_word(n)]))
		Sfx.play("ui_alert", Vector2.INF, -8.0)
	return true



static func clear_front(gw: GameWorld, cid: int, gid: int) -> void :
	var g: Dictionary = ArmyGroups.by_id(gw, cid, gid)
	if g.is_empty():
		return
	g["front"] = {}
	g["plan"] = {}
	_slots.erase(_key(cid, gid))
	_release(gw, cid, g)
	var c: Country = gw.country_by_id(cid)
	if c != null and c.is_player:
		gw.say(c, Loc.mk("Группа «%s»: фронт снят", [String(g["name"])]))



static func _release(gw: GameWorld, cid: int, g: Dictionary) -> void :
	var ops: Operations = gw.ops
	var c: Country = gw.country_by_id(cid)
	for fid: int in g.get("fids", PackedInt32Array()):
		var f: Facility = ArmyGroups.fac(gw, fid)
		if f == null or not ops.list.has(f) or not (ops.list[f] as Dictionary).has("fp"):
			continue
		if int(ops.list[f]["kind"]) == Operations.Kind.RETREAT:
			continue
		var op: Dictionary = ops.list[f]
		ops._release(op, true)
		ops.list.erase(f)



static func nearest_on(pts: PackedVector2Array, p: Vector2) -> Vector2:
	var best: Vector2 = p
	var bd: float = INF
	for i in range(1, pts.size()):
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, pts[i - 1], pts[i])
		var d: float = q.distance_squared_to(p)
		if d < bd:
			bd = d
			best = q
	if pts.size() == 1:
		return pts[0]
	return best






static func slots_peek(c: Country, g: Dictionary) -> Dictionary:
	if c == null or front_of(g).is_empty():
		return {}
	var e: Array = _slots.get(_key(c.id, int(g["id"])), [])
	return e[1] if e.size() >= 2 else {}




static func slots(gw: GameWorld, c: Country, g: Dictionary) -> Dictionary:
	var fr: Dictionary = front_of(g)
	if fr.is_empty() or c == null:
		return {}
	var mem: Array[Facility] = members(gw, c.id, g)
	var msig: String = "%d|" % int(float(fr["t"]) * 10.0)
	for f: Facility in mem:
		msig += "%d," % f.id
	var sig: String = msig + "|%d" % int(float(fr.get("rt", 0.0)) * 10.0)
	var k: String = _key(c.id, int(g["id"]))



	var ro: bool = gw.net_driven and not gw.net_sim
	var e: Array = _slots.get(k, [])
	if e.size() >= 2 and String(e[0]) == sig:
		return e[1]

	var keep: Dictionary = (e[1] as Dictionary) if e.size() >= 3 and String(e[2]) == msig else {}
	if keep.is_empty() and e.size() >= 3 and String(e[2]).begins_with("%d|" % int(float(fr["t"]) * 10.0)):
		keep = e[1]
		_stat("slots_keep_part")
	var out: Dictionary = {}
	var pts: PackedVector2Array = fr["pts"]
	var nrm: PackedVector2Array = fr["nrm"]
	if pts.size() < 2 or mem.is_empty():
		if not ro:
			_slots[k] = [sig, out]
		return out
	var first: Array[Facility] = []
	var sup: Array[Facility] = []
	for f2: Facility in mem:
		if is_support(gw, f2):
			sup.append(f2)
		else:
			first.append(f2)
	if first.is_empty():
		first = sup
		sup = []
	var own: bool = String(fr.get("kind", "border")) != "line"

	_side = side_of(gw, c.id, fr)
	_avoid = _bad_spots(gw, k, ro)
	var drawn: bool = String(fr.get("kind", "")) == "drawn"
	_ally_ok = drawn
	_line_slots(gw, c, first, pts, nrm, DRAW_DEPTH if drawn else ((SETBACK if c.is_player else AI_SETBACK) if own else 24.0), own, 0, out, keep)
	_line_slots(gw, c, sup, pts, nrm, DRAW_SUP if drawn else ((SUP_BACK if c.is_player else AI_SUP_BACK) if own else 130.0), own, 1, out, keep)
	_ally_ok = false
	_side = -1
	_avoid = []
	if not ro:
		_slots[k] = [sig, out, msig]
	_stat("slots_calc")
	return out


static func _line_slots(gw: GameWorld, c: Country, fs: Array[Facility], pts: PackedVector2Array, nrm: PackedVector2Array, depth: float, own: bool, line: int, out: Dictionary, keep: Dictionary = {}) -> void :
	var n: int = fs.size()
	if n == 0:
		return
	var axis: Vector2 = (pts[pts.size() - 1] - pts[0]).normalized()
	var cen: Dictionary = {}
	for f: Facility in fs:
		var mem: Array[Unit] = gw.ops._army(f)
		cen[f] = gw.ops._centre(mem) if not mem.is_empty() else f.center_px()
	var sorted: Array[Facility] = fs.duplicate()
	if keep.size() > 0:


		var on: int = 0
		for kv: int in keep:
			var ke: Array = keep[kv]
			if ke.size() > 3 and int(ke[2]) == line:
				on = maxi(on, int(ke[3]) + 1)
		var a0: Vector2 = pts[0]
		var al: float = maxf(1.0, (pts[pts.size() - 1] - a0).dot(axis))
		var idx: Dictionary = {}
		for f2: Facility in fs:
			var kn: bool = keep.has(f2.id) and (keep[f2.id] as Array).size() > 3 and int(keep[f2.id][2]) == line and on > 0
			idx[f2] = (float(keep[f2.id][3]) + 0.5) / float(on) if kn else clampf(((cen[f2] as Vector2) - a0).dot(axis) / al, 0.0, 1.0)
		sorted.sort_custom( func(a: Facility, b: Facility) -> bool: return float(idx[a]) < float(idx[b]))
	else:
		sorted.sort_custom( func(a: Facility, b: Facility) -> bool: return (cen[a] as Vector2).dot(axis) < (cen[b] as Vector2).dot(axis))
	var cum: = PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		var sg0: float = pts[i - 1].distance_to(pts[i])
		cum.append(cum[i - 1] + (0.0 if sg0 > JUMP else sg0))
	var T: float = cum[cum.size() - 1]
	var j: int = 0
	var taken: Array = []
	for i2 in n:
		var s: float = (float(i2) + 0.5) / float(n) * T
		while j < pts.size() - 2 and cum[j + 1] < s:
			j += 1
		var seg: float = maxf(0.001, cum[j + 1] - cum[j])
		var u: float = clampf((s - cum[j]) / seg, 0.0, 1.0) if cum[j + 1] > cum[j] else 1.0
		var q: Vector2 = pts[j].lerp(pts[j + 1], u)
		var nv: Vector2 = nrm[j].lerp(nrm[j + 1], u).normalized()
		var tv: Vector2 = (pts[j + 1] - pts[j]).normalized()
		var sp: Vector2 = _pick(gw, _side if _side > 0 else c.id, q, nv, tv, depth, own, taken)
		taken.append(sp)
		out[sorted[i2].id] = [sp, nv, line, float(i2)]




static func _pick(gw: GameWorld, cid: int, q: Vector2, nv: Vector2, tv: Vector2, depth: float, own: bool, taken: Array = []) -> Vector2:
	var tac = gw.army.tac
	var d: WorldData = gw.data
	var best: = Vector2.INF
	var bs: float = INF
	for dd: float in [0.0, 12.0, 24.0, -10.0]:
		for dt: float in [0.0, -14.0, 14.0, -28.0, 28.0]:
			var p: Vector2 = q + tv * dt - nv * (depth + dd)
			var cl: Vector2i = _cell(p)
			if not d.inside(cl.x, cl.y) or not gw.ops._dry(p) or d.has_flag(cl.x, cl.y, WorldData.F_BRIDGE):
				continue
			var o: int = d.get_owner_id(cl.x, cl.y)
			if own and o != cid and not (_ally_ok and hold_land(gw, cid, o)):
				continue
			var close: bool = false
			for tp: Vector2 in taken:
				if tp.distance_squared_to(p) < MIN_GAP * MIN_GAP:
					close = true
					break
			for bp: Vector2 in _avoid:
				if bp.distance_squared_to(p) < BAD_R * BAD_R:
					close = true
					break
			if close:
				continue
			var cov: float = float(tac.cover_at(cl))
			var hgt: float = float(d.height[cl.y * d.w + cl.x]) / 255.0 if d.height.size() == d.w * d.h else 0.0
			var sc: float = cov * 10.0 - hgt * 1.5 + absf(dt) * 0.02 + absf(dd) * 0.03
			if sc < bs:
				bs = sc
				best = p
	if best.is_finite():
		return best
	for k in range(1, 6):
		var p2: Vector2 = q - nv * depth * (1.0 - float(k) * 0.18)
		if gw.ops._dry(p2) and ( not own or owner_at(gw, p2) == cid or (_ally_ok and hold_land(gw, cid, owner_at(gw, p2)))):
			return p2


	for back: float in [1.5, 2.2, 3.0, 4.0]:
		for dt2: float in [0.0, -60.0, 60.0, -130.0, 130.0]:
			var p3: Vector2 = q + tv * dt2 - nv * maxf(depth, 40.0) * back
			var c3: Vector2i = _cell(p3)
			var nb: bool = false
			for bp2: Vector2 in _avoid:
				nb = nb or bp2.distance_squared_to(p3) < BAD_R * BAD_R
			if not nb and d.inside(c3.x, c3.y) and ( not own or d.get_owner_id(c3.x, c3.y) == cid or (_ally_ok and hold_land(gw, cid, d.get_owner_id(c3.x, c3.y)))) and gw.ops._dry(p3)\
			and not d.has_flag(c3.x, c3.y, WorldData.F_BRIDGE):
				_stat("slot_deep")
				return p3
	return gw.econ.land_point(q - nv * 8.0, 30)





static func tick(gw: GameWorld) -> void :
	if gw == null or gw.ops == null or gw.mil == null:
		return
	_check_world(gw)
	var t0: int = Time.get_ticks_usec()
	_tick(gw)
	_evict(gw)
	tick_us += Time.get_ticks_usec() - t0


static var tick_us: int = 0


static func _tick(gw: GameWorld) -> void :
	var now: float = gw.game_time
	for c: Country in gw.countries:
		if c.eliminated or c.army_groups.is_empty():
			continue
		var pk: String = "p%d" % c.id
		if now >= float(_next.get(pk, -1.0)):
			_next[pk] = now + THINK
			ArmyGroups.prune(gw, c.id)
			if c.is_player:
				for g0: Dictionary in c.army_groups:
					if bool(g0.get("auto", false)):
						auto_think(gw, c, g0)
		for g: Dictionary in c.army_groups:
			if front_of(g).is_empty():
				continue
			var k: String = _key(c.id, int(g["id"]))
			if now < float(_next.get(k, -1.0)):
				continue
			_next[k] = now + THINK + float(int(g["id"]) % 4) * 0.13
			think(gw, c, g)


static func think(gw: GameWorld, c: Country, g: Dictionary) -> void :
	var fr: Dictionary = front_of(g)
	if int(fr.get("host", -1)) > 0 and side_of(gw, c.id, fr) == c.id:
		_stat("front_ally_lost")
		clear_front(gw, c.id, int(g["id"]))
		return
	var now: float = gw.game_time
	if now - float(fr.get("rt", 0.0)) > REFRESH:
		refresh(gw, c, g)
		if front_of(g).is_empty():
			return
	var pl: Dictionary = plan_of(g)
	if not pl.is_empty():
		var stale: String = plan_stale(gw, c, g)
		if stale != "":
			_end_plan(gw, c, g, stale)
			pl = {}
	if not pl.is_empty():
		var foe: int = int(pl["foe"])
		var war: bool = c.at_war.has(foe) and not gw.diplo.truce_on(c.id, foe)
		if int(pl["state"]) == St.RUN:
			if not war:
				_pause(gw, c, g, Loc.t("перемирие — войска возвращаются на фронт"), 0.0)
			else:
				_run(gw, c, g)
				return
		elif war and now >= float(pl.get("wait", 0.0)):
			var at: Array = _attackers(gw, c, g)
			if (at[0] as Array).size() >= (1 if c.is_player else AI_MIN_ATT):
				_begin(gw, c, g)
				_run(gw, c, g)
				return
			pl["wait"] = now + 20.0
			_stat("plan_wait_few")
		elif not war and c.is_player:
			_nag_no_war(gw, c, g, pl, foe)
	hold(gw, c, g, {}, _defend_sector(gw, c, g))


const NAG_T: float = 90.0







static func _nag_no_war(gw: GameWorld, c: Country, g: Dictionary, pl: Dictionary, foe: int) -> void :
	var now: float = gw.game_time
	if not pl.has("nag"):
		pl["nag"] = now + NAG_T
		return
	if now < float(pl["nag"]):
		return
	pl["nag"] = now + NAG_T
	_stat("plan_nag")
	gw.say(c, Loc.mk("Группа «%s» стоит у границы: %s", [String(g["name"]), wait_why(gw, c.id, foe)]))



static func wait_why(gw: GameWorld, cid: int, foe: int) -> String:
	var c: Country = gw.country_by_id(cid)
	if c == null or gw.diplo == null:
		return ""
	if gw.diplo.truce_on(cid, foe):
		return Loc.t("перемирие с %s — план атаки ждёт конца перемирия") % _cname(gw, foe)
	if not c.at_war.has(foe):
		return Loc.t("нет войны с %s — план атаки начнётся, когда будет война (ПОЛИТ. → объявить войну)") % _cname(gw, foe)
	return ""




static func refresh(gw: GameWorld, c: Country, g: Dictionary) -> void :
	var fr: Dictionary = front_of(g)
	fr["rt"] = gw.game_time
	_refresh_geo(gw, c, g)
	if front_of(g).is_empty():
		return
	with_vis(gw, side_of(gw, c.id, front_of(g)), front_of(g))


static func _refresh_geo(gw: GameWorld, c: Country, g: Dictionary) -> void :
	var fr: Dictionary = front_of(g)
	var kind: String = String(fr.get("kind", "border"))
	var foe: int = int(fr["foe"])
	if kind == "drawn":

		var rw: Variant = fr.get("raw")
		if rw is PackedVector2Array and (rw as PackedVector2Array).size() >= 2:
			var dg: Dictionary = _drawn_geo(gw, c.id, rw, float(fr.get("sgn", 1.0)), foe)
			var op0: PackedVector2Array = fr["pts"]
			if bool(dg.get("ok", false)) and (line_moved(op0, dg["pts"]) >= KEEP_MOVE or absi((dg["pts"] as PackedVector2Array).size() - op0.size()) > 2):
				fr["pts"] = dg["pts"]
				fr["nrm"] = dg["nrm"]
				fr["len"] = dg["len"]
				_stat("front_drawn_recut")
			elif not bool(dg.get("ok", false)):


				var lg: int = 0
				for q0: Vector2 in op0:
					if line_ok(gw, c.id, q0, 2):
						lg += 1
				if lg * 3 < op0.size():
					_stat("front_drawn_lost")
					clear_front(gw, c.id, int(g["id"]))
		return
	var pts: PackedVector2Array = fr["pts"]
	var at: Vector2 = pts[pts.size() / 2] if pts.size() > 0 else fr.get("at", Vector2.ZERO)
	if fr.get("at") is Vector2:



		at = fr["at"]
	if kind == "line":
		if c.at_war.has(foe):
			if c.is_player:
				_line_to_border(gw, c, g)
			return
		at = fr.get("at", at)
	var fc: Country = gw.country_by_id(foe)
	if fc == null or fc.eliminated:
		if c.is_player and fc != null and int(fr.get("host", -1)) <= 0:


			_stat("front_foe_gone")
			clear_front(gw, c.id, int(g["id"]))
		return
	var want: float = float(fr.get("want", FRONT_MAX))


	var ref: PackedVector2Array = fr["pts"] if kind != "line" else PackedVector2Array()
	var scan_at: Vector2 = ref[ref.size() / 2] if ref.size() >= 2 else at
	var geo: Dictionary = border_geo(gw, side_of(gw, c.id, fr), foe, scan_at, want, maxf(BORDER_R, want * 0.6) + 300.0, true, ref)
	if not geo.get("ok", false):
		return



	var opts: PackedVector2Array = fr["pts"]
	var gpts: PackedVector2Array = geo["pts"]
	if kind != "line" and float(geo["len"]) <= SHORT_FRONT + 1.0 and float(fr.get("len", 0.0)) <= SHORT_FRONT + 1.0 and opts.size() >= 2 and gpts.size() >= 2:
		var oc: Vector2 = (opts[0] + opts[opts.size() - 1]) * 0.5
		var nc: Vector2 = (gpts[0] + gpts[gpts.size() - 1]) * 0.5
		var on: Vector2 = (fr["nrm"] as PackedVector2Array)[0]
		var nn: Vector2 = (geo["nrm"] as PackedVector2Array)[0]
		if oc.distance_to(nc) < SHORT_HYST and on.dot(nn) > 0.9:
			_stat("front_keep_short")
			return
	if not bool(geo.get("short", false)) and opts.size() >= 2 and line_moved(opts, gpts) < KEEP_MOVE and absf(float(geo["len"]) - float(fr.get("len", 0.0))) < 48.0:
		_stat("front_keep_same")
		return
	fr["pts"] = geo["pts"]
	fr["nrm"] = geo["nrm"]
	fr["len"] = geo["len"]
	fr["short"] = bool(geo.get("short", false))
	if geo.get("cat") is Vector2 and not bool(geo.get("short", false)):
		fr["at"] = geo["cat"]
	if kind == "line":
		fr["kind"] = "border"

	_stat("front_refresh")



static func slot_of(gw: GameWorld, f: Facility) -> Vector2:
	if f == null or f.group_id < 0:
		return Vector2.INF
	var c: Country = gw.country_by_id(f.country_id)
	var g: Dictionary = ArmyGroups.by_id(gw, f.country_id, f.group_id)
	if c == null or g.is_empty() or front_of(g).is_empty():
		return Vector2.INF
	var sl: Dictionary = slots(gw, c, g)
	return sl[f.id][0] if sl.has(f.id) else Vector2.INF







static func legal_route(gw: GameWorld, cid: int, a: Vector2, b: Vector2) -> Dictionary:
	var path: PackedVector2Array = gw.econ.nav_path(a, b)
	if not gw.econ.nav_last_ok or path.size() < 2:
		return {"ok": true, "chain": PackedVector2Array()}
	var rest: PackedVector2Array = _past_closed(gw, cid, path)
	if rest.size() < 2 or gw.diplo.path_block(cid, rest) == 0:
		return {"ok": true, "chain": PackedVector2Array()}
	_stat("pass_block")
	if not way_budget(gw):
		return {"ok": false, "busy": true}
	var ch: PackedVector2Array = _local_chain(gw, cid, rest)
	if ch.is_empty():
		_stat("pass_noway")
		return {"ok": false}
	var tac = gw.army.tac
	var old: PackedVector2Array = tac.chain
	tac.chain = ch
	var p2: PackedVector2Array = tac.route(a, b)
	var lok: bool = gw.econ.nav_last_ok
	tac.chain = old
	if not lok or p2.size() < 2 or gw.diplo.path_block(cid, _past_closed(gw, cid, p2)) > 0:
		_stat("pass_noway")
		return {"ok": false}
	_stat("pass_detour")
	return {"ok": true, "chain": ch}


const WAY_PER_S: int = 4
static var _wb_s: int = -1
static var _wb_n: int = 0


static func way_budget(gw: GameWorld) -> bool:
	if gw.net_driven and not gw.net_sim:
		return true
	var s: int = floori(gw.game_time)
	if s != _wb_s:
		_wb_s = s
		_wb_n = 0
	if _wb_n >= WAY_PER_S:
		return false
	_wb_n += 1
	return true


const EVICT_DT: float = 10.0
static var _evict_t: float = -1.0




static func _evict(gw: GameWorld) -> void :
	if gw.game_time < _evict_t:
		return
	_evict_t = gw.game_time + EVICT_DT
	var dp: Diplomacy = gw.diplo
	if dp == null:
		return
	var n: int = 0
	for u: Unit in gw.army.units:
		if u.home == null or u.post != null or not u.alive() or not u.ground() or u.state != Unit.State.IDLE:
			continue
		if u.pi < u.path.size() or gw.ops.list.has(u.home) or gw.army.tac.ops.has(u.home):
			continue
		var c: Country = gw.country_by_id(u.country_id)
		if c == null or c.is_player or dp.may_cross(u.country_id, owner_at(gw, u.pos)):
			continue
		if gw.naval != null and gw.naval.busy(u.home):
			continue
		var dest: Vector2 = gw.army.barracks_out(u.home) + u.slot
		if not dp.may_cross(u.country_id, owner_at(gw, dest)):
			continue
		var pth: PackedVector2Array = gw.econ.nav_path(u.pos, dest)
		if pth.is_empty() or not gw.econ.nav_last_ok:
			continue
		pth[pth.size() - 1] = dest
		u.op_on = false
		u.path = pth
		u.pi = 0
		u.state = Unit.State.MOVE
		n += 1
	if n > 0:
		_stat("evict_units", n)




static func closed_path(gw: GameWorld, cid: int, path: PackedVector2Array) -> bool:
	return gw.diplo != null and gw.diplo.path_block(cid, _past_closed(gw, cid, path)) > 0



static func _past_closed(gw: GameWorld, cid: int, path: PackedVector2Array) -> PackedVector2Array:
	if path.is_empty() or gw.diplo == null:
		return path
	var i0: int = 0
	while i0 < path.size() and not gw.diplo.may_cross(cid, owner_at(gw, path[i0])):
		i0 += 1
	return path.slice(i0) if i0 > 0 else path




static func _line_to_border(gw: GameWorld, c: Country, g: Dictionary) -> void :
	var fr: Dictionary = front_of(g)
	var pts: PackedVector2Array = fr["pts"]
	var mid: Vector2 = pts[pts.size() / 2]
	var want: float = maxf(float(fr.get("len", STRETCH_MIN)), STRETCH_MIN)
	var geo: Dictionary = border_geo(gw, c.id, int(fr["foe"]), mid, want, maxf(BORDER_R, want * 0.6) + 300.0, false, pts)
	if not bool(geo.get("ok", false)) or nearest_on(geo["pts"], mid).distance_to(mid) >= NEAR_B:
		return
	fr["pts"] = geo["pts"]
	fr["nrm"] = geo["nrm"]
	fr["len"] = geo["len"]
	fr["kind"] = "border"
	fr["at"] = geo["cat"]
	fr["want"] = want
	fr["short"] = false
	_stat("line_to_border")




static func hold(gw: GameWorld, c: Country, g: Dictionary, only: Dictionary = {}, busy: Dictionary = {}) -> int:
	if c == null:
		return 0
	var sl: Dictionary = slots(gw, c, g)
	var ops: Operations = gw.ops
	var now: float = gw.game_time
	var sent: int = 0
	var was_quiet: bool = ops._quiet
	ops._quiet = true


	var take: float = float(front_of(g).get("take", - INF)) if c.is_player else - INF
	var stuck: Array = []
	var gk: String = _key(c.id, int(g["id"]))
	var ways: int = 0
	var mates: bool = now >= float(_mates_t.get(gk, -1.0))
	if mates:
		_mates_t[gk] = now + MATES_DT
	for fid: int in sl:
		if ( not only.is_empty() and not only.has(fid)) or busy.has(fid):
			continue
		var f: Facility = ArmyGroups.fac(gw, fid)
		if not ArmyGroups.valid_member(gw, c.id, f):
			continue
		var s: Array = sl[fid]
		var p: Vector2 = s[0]
		var op: Dictionary = ops.list.get(f, {})
		if float(ops.auto_next.get("h%d" % fid, - INF)) >= take:
			continue
		if not op.is_empty():
			if not op.has("fp") and not bool(op.get("stance", false)):
				if int(op["kind"]) == Operations.Kind.RETREAT or not (bool(op.get("front_take", false)) or float(op.get("t0", INF)) < take):
					continue
				_stat("front_take")
			elif int(op["kind"]) == Operations.Kind.RETREAT and not (bool(op.get("stance", false)) and _hp_share(gw, f) >= REJOIN_HP):
				continue
			elif int(op["kind"]) == Operations.Kind.DEFEND and (op["target"] as Vector2).distance_to(p) < SLOT_TOL:
				_face(gw, f, s[1])
				_dig_in(gw, c, f, p, s[1])
				if mates:
					_stragglers(gw, f, op)
				continue
			elif int(op["kind"]) == Operations.Kind.DEFEND and op.has("fp") and (op["target"] as Vector2).distance_to(p) < MARCH_TOL\
			and (op["front"] as Vector2).distance_to(op["target"]) > MARCH_FAR:
				continue
		elif _posted(gw, f, p):
			continue
		if now < float(_retry.get(fid, -1.0)):
			if why_of.has(fid) and now - float(_stuck_t.get(fid, now)) >= STUCK_AGE and not _fp_on(op):
				stuck.append([f.army_no, String(why_of[fid]), fid])
			continue
		var why: String = ops.start(f, Operations.Kind.DEFEND, p)
		if why != "":


			_last_block = 0
			var wf: Array = _way_fail.get(fid, [])
			var dt: Dictionary = {}
			if wf.size() == 2 and (wf[0] as Vector2).distance_to(p) < SLOT_TOL and now < float(wf[1]):
				pass
			elif ways >= WAY_BUDGET:
				_retry[fid] = now + 1.0
				continue
			else:
				ways += 1
				var t0: int = Time.get_ticks_usec()
				dt = _detour(gw, c.id, f, p, s[1])
				_stat("way_us", Time.get_ticks_usec() - t0)
				if dt.is_empty():
					_way_fail[fid] = [p, now + WAY_FAIL_T]
			if not dt.is_empty():
				gw.army.tac.chain = dt["chain"]
				var why2: String = ops.start(f, Operations.Kind.DEFEND, p, dt["wp"])
				gw.army.tac.chain = PackedVector2Array()
				if why2 == "":
					_stat("hold_detour")
				why = why2 if why2 == "" else why
			elif (_last_block > 0 or not ops._dry(p) or not gw.diplo.may_cross(c.id, owner_at(gw, p))) and _mark_bad(gw, gk, fid, p):

				_retry[fid] = now + 2.0
				why_of.erase(fid)
				continue
		if why == "":
			_tag(gw, f, int(g["id"]), true)
			_face(gw, f, s[1])

			ops.list[f]["retreat_at"] = maxf(float(ops.list[f].get("retreat_at", 0.5)), HOLD_RETREAT if c.is_player else AI_HOLD_RETREAT)
			why_of.erase(fid)
			_stuck_t.erase(fid)
			sent += 1
		else:
			_retry[fid] = now + RESEND
			why_of[fid] = why
			if not _stuck_t.has(fid):
				_stuck_t[fid] = now
			if now - float(_stuck_t[fid]) >= STUCK_AGE and not _fp_on(op):
				stuck.append([f.army_no, why, fid])
			_stat("hold_refused")
	ops._quiet = was_quiet
	if c.is_player:
		_note_stuck(gw, g, stuck, c)
	if sent > 0:
		_stat("hold_orders", sent)
	return sent




const WAY_BUDGET: int = 2
const WAY_FAIL_T: float = 45.0
static var _way_fail: Dictionary = {}
const BAD_R: float = 90.0
const BAD_T: float = 240.0
static var _last_block: int = 0
static var _bad: Dictionary = {}
static var _bad_n: Dictionary = {}
static var _avoid: Array = []




static func _mark_bad(gw: GameWorld, gk: String, fid: int, p: Vector2) -> bool:
	var now: float = gw.game_time
	var bn: Array = _bad_n.get(fid, [0, 0.0])
	if now > float(bn[1]):
		bn = [0, now + 120.0]
	if int(bn[0]) >= 2:
		return false
	bn[0] = int(bn[0]) + 1
	_bad_n[fid] = bn
	var lst: Array = _bad.get(gk, [])
	if lst.size() >= 12:
		lst.pop_front()
	lst.append([p, now + BAD_T])
	_bad[gk] = lst
	_slots.erase(gk)
	_stat("slot_bad")
	return true


static func _bad_spots(gw: GameWorld, gk: String, ro: bool = false) -> Array:
	var out: Array = []
	var lst: Array = _bad.get(gk, [])
	var keep: Array = []
	for e: Array in lst:
		if float(e[1]) > gw.game_time:
			keep.append(e)
			out.append(e[0])
	if keep.size() != lst.size() and not ro:
		_bad[gk] = keep
	return out


const MATES_DT: float = 6.0
const MARCH_TOL: float = 170.0
const MARCH_FAR: float = 420.0
const STRAY_D: float = 250.0
const STUCK_REPEAT: float = 180.0
const STUCK_AGE: float = 24.0
static var _stuck_t: Dictionary = {}
static var _mates_t: Dictionary = {}
static var _stuck_said: Dictionary = {}






static func _detour(gw: GameWorld, cid: int, f: Facility, p: Vector2, nv: Vector2) -> Dictionary:
	var ops: Operations = gw.ops
	var tac = gw.army.tac
	var chk: Dictionary = ops._check(f, Operations.Kind.DEFEND, p, Vector2.INF)
	_last_block = int(chk.get("blocker", 0)) if not bool(chk["ok"]) else 0
	if bool(chk["ok"]) or int(chk.get("blocker", 0)) <= 0:
		return {}
	var from: Vector2 = ops._from(f)
	var d: Vector2 = p - from
	var L: float = d.length()
	if L < 1.0:
		return {}
	var ch: PackedVector2Array = _local_chain(gw, cid, chk["path"])
	if ch.size() > 0:
		tac.chain = ch
		var pc: PackedVector2Array = tac.route(from, p)
		var lok: bool = gw.econ.nav_last_ok
		tac.chain = PackedVector2Array()
		if lok and pc.size() > 1 and gw.diplo.path_block(cid, pc) == 0 and _path_len(pc) <= Operations.max_path():
			_stat("detour_chain")
			return {"wp": ch[ch.size() / 2], "chain": ch}
	var side: Vector2 = d.orthogonal() / L
	var mid: Vector2 = (from + p) * 0.5
	var gen: Array = []
	for k: float in [260.0, 520.0, 900.0]:
		gen.append(p - nv * k)
	for sg: float in [-1.0, 1.0]:
		for k2: float in [0.25, 0.5, 0.8]:
			gen.append(mid + side * sg * L * k2)
	var ok: Array = []
	for w: Vector2 in gen:
		var cl: Vector2i = _cell(w)
		if not gw.data.inside(cl.x, cl.y) or not ops._dry(w) or not gw.diplo.may_cross(cid, gw.data.get_owner_id(cl.x, cl.y)):
			continue
		ok.append([from.distance_to(w) + w.distance_to(p), w])
	ok.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i in mini(2, ok.size()):
		var w2: Vector2 = ok[i][1]
		var path: PackedVector2Array = tac.route(from, p, w2)
		if path.is_empty() or not gw.econ.nav_last_ok:
			continue
		if gw.diplo.path_block(cid, path) == 0 and _path_len(path) <= Operations.max_path():
			return {"wp": w2, "chain": PackedVector2Array()}
	_stat("detour_none")
	return {}


const WAY_PAD: float = 280.0
const WAY_MAX: int = 48






static func _local_chain(gw: GameWorld, cid: int, path: PackedVector2Array) -> PackedVector2Array:
	var out: = PackedVector2Array()
	var nav: AStarGrid2D = gw.econ.nav
	if nav == null or path.size() < 2:
		return out
	var dp: Diplomacy = gw.diplo
	var d: WorldData = gw.data
	var okc: Dictionary = {}
	var a: = Vector2.INF
	var b: = Vector2.INF
	var prev: = Vector2.INF
	var closed: bool = false
	for i in range(1, path.size()):
		var n: int = maxi(1, int(path[i - 1].distance_to(path[i]) / 8.0))
		for k in n + 1:
			var q: Vector2 = path[i - 1].lerp(path[i], float(k) / float(n))
			var c: Vector2i = _cell(q)
			var o: int = d.get_owner_id(c.x, c.y) if d.inside(c.x, c.y) else 0
			if not okc.has(o):
				okc[o] = dp.may_cross(cid, o)
			if not bool(okc[o]):
				if not closed:
					a = prev
				closed = true
				b = Vector2.INF
			elif closed and not b.is_finite():
				b = q
			prev = q
	if not a.is_finite() or not b.is_finite():
		return out
	var k0: float = nav.cell_size.x
	var K: int = int(k0) / GameWorld.CELL
	var cen: Vector2 = (a + b) * 0.5
	var half: int = mini(WAY_MAX, ceili((a.distance_to(b) * 0.5 + WAY_PAD) / k0))
	var cc: = Vector2i(int(cen.x / k0), int(cen.y / k0))
	var reg: = Rect2i(cc - Vector2i(half, half), Vector2i(half * 2 + 1, half * 2 + 1)).intersection(nav.region)
	if reg.size.x < 3 or reg.size.y < 3:
		return out
	var g: = AStarGrid2D.new()
	g.region = reg
	g.cell_size = nav.cell_size
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	var shut: = PackedByteArray()
	shut.resize(256)
	for oc: Country in gw.countries:
		if oc.id > 0 and oc.id < 256 and not dp.may_cross(cid, oc.id):
			shut[oc.id] = 1
	var ow: PackedByteArray = d.owners
	var W: int = d.w
	var h2: int = K / 2
	for y in range(reg.position.y, reg.end.y):
		var r0: int = (y * K) * W
		var r1: int = (y * K + h2) * W
		var r2: int = (y * K + K - 1) * W
		for x in range(reg.position.x, reg.end.x):
			var q2: = Vector2i(x, y)
			var x0: int = x * K
			if nav.is_point_solid(q2) or shut[ow[r1 + x0 + h2]] == 1 or shut[ow[r0 + x0]] == 1 or shut[ow[r2 + x0 + K - 1]] == 1:
				g.set_point_solid(q2)
	var ca: = Vector2i(int(a.x / k0), int(a.y / k0))
	var cb: = Vector2i(int(b.x / k0), int(b.y / k0))
	if not reg.has_point(ca) or not reg.has_point(cb):
		return out
	g.set_point_solid(ca, false)
	g.set_point_solid(cb, false)
	var ids: Array[Vector2i] = g.get_id_path(ca, cb)
	_stat("detour_local")
	if ids.size() < 2:
		return out
	out.append(a)
	var last_dir: = Vector2i.ZERO
	for j in range(1, ids.size() - 1):
		var dir: Vector2i = ids[j + 1] - ids[j]
		if dir != last_dir or j % 4 == 0:
			out.append(Vector2(ids[j]) * k0 + Vector2(k0, k0) * 0.5)
		last_dir = dir
	out.append(b)
	return out


static func _path_len(path: PackedVector2Array) -> float:
	var s: float = 0.0
	for i in range(1, path.size()):
		s += path[i - 1].distance_to(path[i])
	return s




static func _stragglers(gw: GameWorld, f: Facility, op: Dictionary) -> void :
	if gw.army.tac.ops.get(f, {}).is_empty():
		return
	var tgt: Vector2 = op["target"]
	var wv: Variant = op.get("wp", Vector2.INF)
	var wp: Vector2 = wv if wv is Vector2 else Vector2.INF
	var n: int = 0
	for u: Unit in gw.army.units:
		if u.home != f or u.op_on or u.post != null or not u.alive() or not u.ground() or u.state != Unit.State.IDLE or u.reinf != 0:
			continue
		if u.pos.distance_to(tgt) < STRAY_D:
			continue
		if not gw.ops.rejoin(u):
			break
		n += 1
		if wp.is_finite() and u.path.size() > 0 and u.pos.distance_to(wp) > 60.0:
			var dest: Vector2 = u.path[u.path.size() - 1]
			var pth: PackedVector2Array = gw.army.tac.route(u.pos, dest, wp)
			if pth.size() > 0:
				pth[pth.size() - 1] = dest
				u.path = pth
				u.pi = 0
	if n > 0:
		_stat("front_rejoin", n)




static func _note_stuck(gw: GameWorld, g: Dictionary, stuck: Array, c: Country = null) -> void :
	var k: String = "%d:%d" % [c.id if c != null else 0, int(g["id"])]
	if stuck.is_empty():
		_stuck_said.erase(k)
		return
	stuck.sort_custom( func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var sig: String = ""
	for e: Array in stuck:
		sig += "%d:%s;" % [int(e[0]), String(e[1])]
	var prev: Array = _stuck_said.get(k, [])
	var fresh: bool = prev.size() < 3
	if not fresh:
		for e3: Array in stuck:
			fresh = fresh or not (prev[2] as Dictionary).has(int(e3[2]))
	if prev.size() == 3 and gw.game_time - float(prev[1]) < (30.0 if fresh else STUCK_REPEAT):
		return
	var told: Dictionary = {}
	for e4: Array in stuck:
		told[int(e4[2])] = true
	_stuck_said[k] = [sig, gw.game_time, told]
	var why0: String = String(stuck[0][1])
	var nos: Array = []
	for e2: Array in stuck:
		if String(e2[1]) == why0:
			nos.append(Loc.no(int(e2[0])))
	var who: String = (Loc.t("Армия %s") % [String(nos[0])]) if nos.size() == 1 else (Loc.t("Армии %s") % [", ".join(PackedStringArray(nos))])
	var more: int = stuck.size() - nos.size()
	var to340: Country = c
	if to340 == null:
		to340 = gw.player
	gw.say(to340, Loc.mk("«%s»: %s %s выйти на фронт — %s%s", [String(g["name"]), who, Loc.t("не может") if nos.size() == 1 else Loc.t("не могут"), _lc(why0), 
		(Loc.t(" (ещё %d — в карточке армии)") % more) if more > 0 else ""]))
	_stat("front_stuck_note")



static func _fp_on(op: Dictionary) -> bool:
	var fp_on: bool = not op.is_empty() and op.has("fp") and int(op["kind"]) != Operations.Kind.RETREAT
	return fp_on


static func _lc(t: String) -> String:
	return t.left(1).to_lower() + t.substr(1) if t.length() > 1 else t



static func idle_why(gw: GameWorld, f: Facility) -> String:
	if f == null or not holds_fac(gw, f):
		return ""
	var why: String = String(why_of.get(f.id, ""))
	if why != "":
		return Loc.t("не может выйти на фронт — %s") % [_lc(why)]
	var mem: Array[Unit] = gw.ops._army(f)
	if mem.size() < 2:
		return Loc.t("формируется — выйдет на фронт с 2 бойцами")
	var c: Country = gw.country_by_id(f.country_id)
	var sl: Dictionary = slots(gw, c, ArmyGroups.by_id(gw, f.country_id, f.group_id)) if c != null else {}
	if sl.has(f.id) and gw.ops._centre(mem).distance_to(sl[f.id][0]) < 120.0:
		return Loc.t("держим позицию")
	return Loc.t("выходит на позицию")







static func _defend_sector(gw: GameWorld, c: Country, g: Dictionary) -> Dictionary:
	var busy: Dictionary = {}
	var gid: int = int(g["id"])
	var now: float = gw.game_time
	var ops: Operations = gw.ops
	for fid: int in _react.keys():
		var r: Dictionary = _react[fid]
		if int(r["gid"]) != gid:
			continue
		var f0: Facility = ArmyGroups.fac(gw, fid)
		var op0: Dictionary = ops.list.get(f0, {}) if f0 != null else {}
		if f0 == null or f0.group_id != gid or op0.is_empty() or not op0.has("react") or now - float(r["seen"]) > REACT_CALM or now - float(r["t"]) > REACT_MAX_T:
			_react.erase(fid)
			continue
		busy[fid] = true
	if c.at_war.is_empty():
		return busy
	var fr: Dictionary = front_of(g)
	var pts: PackedVector2Array = fr["pts"]
	if pts.size() < 2:
		return busy
	var box: = Rect2(pts[0], Vector2.ZERO)
	for q: Vector2 in pts:
		box = box.expand(q)
	box = box.grow(SECTOR_R)
	var depth: float = (SETBACK if c.is_player else AI_SETBACK) + BREAK_DEPTH
	var cells: Dictionary = {}
	for u: Unit in gw.army.units:
		if not u.alive() or not u.ground() or not c.at_war.has(u.country_id) or not box.has_point(u.pos):
			continue
		if owner_at(gw, u.pos) != c.id or not gw.army.fire.sees(c.id, u):
			continue
		var dl: float = nearest_on(pts, u.pos).distance_to(u.pos)
		if dl > SECTOR_R:
			continue
		var city_near: bool = false
		for ci: int in c.city_ids:
			var ct0: City = gw.cities[ci]
			if Vector2(ct0.center * GameWorld.CELL).distance_to(u.pos) < float(ct0.radius * GameWorld.CELL) + CITY_THREAT_R:
				city_near = true
				break
		if dl < depth and not city_near:
			continue
		var key: = Vector2i(floori(u.pos.x / 200.0), floori(u.pos.y / 200.0))
		var e: Array = cells.get(key, [Vector2.ZERO, 0])
		e[0] = (e[0] as Vector2) + u.pos
		e[1] = int(e[1]) + 1
		cells[key] = e
	var tk: String = _key(c.id, gid)
	if cells.is_empty():
		_threat_t.erase(tk)
		return busy
	if not _threat_t.has(tk):
		_threat_t[tk] = now
	if not c.is_player and now - float(_threat_t[tk]) < float(AI_REACT_DELAY[GameConfig.diff_of(c)]):
		return busy
	var threats: Array = []
	for key2: Vector2i in cells:
		var e2: Array = cells[key2]
		if int(e2[1]) < 2:
			continue
		var tp: Vector2 = (e2[0] as Vector2) / float(e2[1])
		var city: City = null
		var bd: float = INF
		for ci2: int in c.city_ids:
			var ct: City = gw.cities[ci2]
			var d: float = Vector2(ct.center * GameWorld.CELL).distance_to(tp) - float(ct.radius * GameWorld.CELL)
			if d < CITY_THREAT_R and d < bd:
				bd = d
				city = ct
		threats.append([float(e2[1]) + (100.0 if city != null else 0.0), tp, int(e2[1]), city])
	threats.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var mem: Array[Facility] = members(gw, c.id, g)
	var cap_n: int = maxi(1, mem.size() / 2) if c.is_player else 1
	var was_quiet: bool = ops._quiet
	ops._quiet = true
	for th: Array in threats:
		var tp2: Vector2 = th[1]
		var city2: City = th[3]

		var have: int = 0
		for fid2: int in _react:
			var r2: Dictionary = _react[fid2]
			if int(r2["gid"]) == gid and (r2["pos"] as Vector2).distance_to(tp2) < 350.0:
				r2["seen"] = now
				have += 1


		var cap_t: int = mem.size() if (city2 != null and c.is_player) else cap_n
		var need: int = (ceili(float(int(th[2])) / 5.0) if city2 != null else clampi(ceili(float(int(th[2])) / 6.0), 1, REACT_MAX)) - have
		if not c.is_player:
			need = mini(need, 1 - have)
		if need <= 0 or busy.size() >= cap_t:
			continue
		var cand: Array[Facility] = []
		for f: Facility in mem:
			if busy.has(f.id):
				continue
			if city2 == null and is_support(gw, f):
				continue
			var op: Dictionary = ops.list.get(f, {})
			if not op.is_empty() and ( not op.has("fp") or int(op["kind"]) == Operations.Kind.RETREAT):
				continue
			if c.is_player and float(ops.auto_next.get("h%d" % f.id, - INF)) >= float(fr.get("take", - INF)):
				continue
			cand.append(f)
		var cpos: Dictionary = {}
		for f2: Facility in cand:
			var m2: Array[Unit] = ops._army(f2)
			cpos[f2] = ops._centre(m2) if not m2.is_empty() else f2.center_px()
		cand.sort_custom( func(a: Facility, b: Facility) -> bool: return (cpos[a] as Vector2).distance_squared_to(tp2) < (cpos[b] as Vector2).distance_squared_to(tp2))
		for f3: Facility in cand:
			if need <= 0 or busy.size() >= cap_t:
				break
			if (cpos[f3] as Vector2).distance_to(tp2) > 1600.0:
				break
			var kind: int = Operations.Kind.ATTACK
			var to: Vector2 = tp2
			if city2 != null:

				var ccp: = Vector2(city2.center * GameWorld.CELL)
				to = gw.econ.land_point(ccp + (tp2 - ccp).normalized() * float(city2.radius * GameWorld.CELL) * 0.5)
				kind = Operations.Kind.DEFEND
			if ops.start(f3, kind, to) == "":
				_tag(gw, f3, gid, kind == Operations.Kind.DEFEND)
				ops.list[f3]["react"] = true
				if city2 != null:
					ops.list[f3]["retreat_at"] = maxf(float(ops.list[f3].get("retreat_at", 0.5)), RELIEF_RETREAT)
				_react[f3.id] = {"gid": gid, "t": now, "seen": now, "pos": tp2}
				busy[f3.id] = true
				need -= 1
				_stat("react_city" if city2 != null else "react_break")
	ops._quiet = was_quiet
	return busy






static func _dig_in(gw: GameWorld, c: Country, f: Facility, p: Vector2, nv: Vector2) -> void :
	if not c.is_player:
		_ai_dig(gw, c, f, p, nv)
		return
	var now: float = gw.game_time
	if ArmyGroups.stay_out(gw, c.id, f):
		return
	var top: Variant = gw.army.tac.ops.get(f)
	if not (top is Dictionary) or int((top as Dictionary).get("phase", 0)) != 5:
		_held.erase(f.id)
		return
	if not _held.has(f.id):
		_held[f.id] = now
		return
	if now - float(_held[f.id]) < DIG_HOLD_T:
		return
	var tr: Facility = _trench_near(gw, c, p)
	if tr == null:
		if now < float(_dig_t.get(f.id, -1.0)) or c.money < Military.line_cost(Facility.Kind.TRENCH_H, DIG_CELLS) + DIG_RESERVE:
			return
		_dig_t[f.id] = now + 60.0
		var tv: = Vector2( - nv.y, nv.x)
		var cells: Array[Vector2i] = []
		for k in range( - DIG_CELLS / 2, DIG_CELLS - DIG_CELLS / 2):
			var q: Vector2 = p + tv * float(k * GameWorld.CELL) + nv * 6.0
			var cl: = Vector2i(floori(q.x / GameWorld.CELL), floori(q.y / GameWorld.CELL))
			if not cells.has(cl):
				cells.append(cl)
		if gw.mil.build_line(Facility.Kind.TRENCH_H, cells, c, false, true) != null:
			_stat("dig_trench")
		return
	if gw.mil.alive(tr) and gw.army.occupants(tr).size() < gw.army.capacity(tr):
		gw.army.front_dig = true
		var dn: int = gw.army.occupy(tr, c.id, false, f)
		gw.army.front_dig = false
		if dn > 0:
			_stat("dig_occupy")







const AI_DIG_HOLD_T: float = 60.0
const AI_DIG_GAP: float = 45.0
const AI_TRENCH_CAP: Array = [3, 5, 8]
const AI_DIG_RESERVE: int = 1500


static func _ai_dig(gw: GameWorld, c: Country, f: Facility, p: Vector2, nv: Vector2) -> void :
	if not GameConfig.autodig_on(c):
		return
	var top: Variant = gw.army.tac.ops.get(f)
	if not (top is Dictionary) or int((top as Dictionary).get("phase", 0)) != 5:
		return
	var g: Dictionary = ArmyGroups.by_id(gw, c.id, f.group_id)
	if g.is_empty() or running(g):
		return
	var tr: Facility = _trench_near(gw, c, p)
	if tr == null:
		var op: Dictionary = gw.ops.list.get(f, {})
		var qt: float = float(op.get("quiet_t", -1.0))
		if qt < 0.0 or gw.game_time - qt < AI_DIG_HOLD_T:
			return
		if gw.game_time < float(g.get("dig_t", -1.0)) or c.money < Military.line_cost(Facility.Kind.TRENCH_H, DIG_CELLS) + AI_DIG_RESERVE:
			return
		var have: int = 0
		var sl: Dictionary = slots(gw, c, g)
		for fid2: int in sl:
			if _trench_near(gw, c, sl[fid2][0]) != null:
				have += 1
		if have >= int(AI_TRENCH_CAP[GameConfig.diff_of(c)]):
			_stat("ai_dig_cap")
			return
		g["dig_t"] = gw.game_time + AI_DIG_GAP
		var tv: = Vector2( - nv.y, nv.x)
		var cells: Array[Vector2i] = []
		for k in range( - DIG_CELLS / 2, DIG_CELLS - DIG_CELLS / 2):
			var q: Vector2 = p + tv * float(k * GameWorld.CELL) + nv * 6.0
			var cl: = Vector2i(floori(q.x / GameWorld.CELL), floori(q.y / GameWorld.CELL))
			if not cells.has(cl):
				cells.append(cl)
		if gw.mil.build_line(Facility.Kind.TRENCH_H, cells, c, false, true) != null:
			_stat("ai_dig_trench")
		return
	if gw.mil.alive(tr) and gw.army.occupants(tr).size() < gw.army.capacity(tr):
		if gw.army.occupy(tr, c.id, false, f) > 0:
			_stat("ai_dig_occupy")


static var _held: Dictionary = {}
static var _dig_t: Dictionary = {}


static func _trench_near(gw: GameWorld, c: Country, p: Vector2) -> Facility:
	var cl: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	for dy in range(-8, 9, 2):
		for dx in range(-8, 9, 2):
			var q: = cl + Vector2i(dx, dy)
			var lf: Variant = gw.mil.fort_cells.get(q, gw.mil.dig_cells.get(q, null))
			if lf is Facility and (lf as Facility).country_id == c.id and (lf as Facility).kind == Facility.Kind.TRENCH_H:
				return lf
	return null



static func _posted(gw: GameWorld, f: Facility, p: Vector2) -> bool:
	var dug: bool = false
	for u: Unit in gw.army.units:
		if u.home == f and u.alive() and u.post != null and u.pos.distance_to(p) < 120.0:
			dug = true
			break
	if not dug:
		return false


	var free: Array[Unit] = gw.ops._army(f)
	return free.size() < 2 or gw.ops._centre(free).distance_to(p) < 250.0


static func _tag(gw: GameWorld, f: Facility, gid: int, defend: bool) -> void :
	var op: Dictionary = gw.ops.list.get(f, {})
	if op.is_empty():
		return
	op["fp"] = gid
	if defend:
		op["said"] = "hold"



static func _face(gw: GameWorld, f: Facility, dir: Vector2) -> void :
	var top: Variant = gw.army.tac.ops.get(f)
	if top is Dictionary and int((top as Dictionary).get("phase", 0)) != 5 and dir.length() > 0.5:
		(top as Dictionary)["dir"] = dir





static func curve(pl: Dictionary, t: float) -> Vector2:
	var a: Vector2 = pl["a"]
	var b: Vector2 = pl["b"]
	var m: Vector2 = pl.get("m", Vector2.INF)
	if not m.is_finite():
		return a.lerp(b, t)
	var u: float = 1.0 - t
	return a * u * u + m * 2.0 * u * t + b * t * t


static func tangent(pl: Dictionary, t: float) -> Vector2:
	var d: Vector2 = curve(pl, minf(1.0, t + 0.02)) - curve(pl, maxf(0.0, t - 0.02))
	return d.normalized() if d.length() > 0.001 else Vector2.RIGHT


static func plan_len(pl: Dictionary) -> float:
	var s: float = 0.0
	var prev: Vector2 = curve(pl, 0.0)
	for i in range(1, 17):
		var p: Vector2 = curve(pl, float(i) / 16.0)
		s += prev.distance_to(p)
		prev = p
	return s





static func plan_check(gw: GameWorld, cid: int, gid: int, a: Vector2, b: Vector2, m: Vector2 = Vector2.INF, replace: bool = false) -> Dictionary:
	var g: Dictionary = ArmyGroups.by_id(gw, cid, gid)
	var out: Dictionary = {"ok": false, "why": "", "a": a, "m": m, "b": b, "foe": -1, "len": 0.0, "text": "", "war": false}
	if g.is_empty():
		out["why"] = Loc.t("Нет такой группы")
		return out
	var fr: Dictionary = front_of(g)
	if fr.is_empty():
		out["why"] = Loc.t("Сначала назначьте группе ФРОНТ")
		return out
	if running(g) and not replace:
		out["why"] = Loc.t("План уже выполняется")
		return out
	var pts: PackedVector2Array = fr["pts"]
	a = nearest_on(pts, a if a.is_finite() else b)
	b = gw.econ.land_point(b)
	out["a"] = a
	out["b"] = b
	if m.is_finite() and Geometry2D.get_closest_point_to_segment(m, a, b).distance_to(m) < a.distance_to(b) * 0.12:
		m = Vector2.INF
	out["m"] = m
	var o: int = owner_at(gw, b)
	if o <= 0 or o == cid:
		out["why"] = Loc.t("Конец стрелки — на земле противника")
		return out
	if gw.diplo.allied(cid, o):
		out["why"] = Loc.t("Это союзник")
		return out
	out["foe"] = o
	var L: float = plan_len(out)
	out["len"] = L
	if L < PLAN_MIN:
		out["why"] = Loc.t("Слишком короткая стрелка")
		return out
	var mx: float = Operations.MAX_RANGE * PLAN_MAX_K
	if L > mx:
		out["why"] = Loc.t("Слишком далеко: до %.1f км") % (mx / 1000.0)
		return out
	var c: Country = gw.country_by_id(cid)
	var war: bool = c != null and c.at_war.has(o) and not gw.diplo.truce_on(cid, o)
	out["war"] = war
	out["ok"] = true
	out["text"] = Loc.t("ПЛАН АТАКИ → %s · %.1f км · %s") % [_cname(gw, o), L / 1000.0, Loc.t("война идёт: можно сразу") if war else Loc.t("начнётся с войной")]

	var route: PackedVector2Array = gw.econ.nav_path(a, b)
	out["sea"] = not gw.econ.nav_last_ok
	out["pass"] = 0
	if not bool(out["sea"]):
		var cen: Vector2 = centre(gw, cid, g)
		var to_a: PackedVector2Array = gw.econ.nav_path(cen, a) if cen.is_finite() else PackedVector2Array()
		var blk: int = gw.diplo.path_block(cid, to_a)
		if blk <= 0:
			blk = gw.diplo.path_block(cid, route)
		if blk > 0 and blk != o:
			out["pass"] = blk
	out["warn"] = Loc.t("через море — десант, большие потери") if bool(out["sea"]) else ((Loc.t("нужен проход через %s") % _cname(gw, int(out["pass"]))) if int(out["pass"]) > 0 else "")
	return out


static func set_plan(gw: GameWorld, cid: int, gid: int, chk: Dictionary, quiet: bool = false) -> bool:
	var g: Dictionary = ArmyGroups.by_id(gw, cid, gid)
	if g.is_empty() or not bool(chk.get("ok", false)):
		return false
	if not (g.get("storms") is Dictionary):
		g["storms"] = {}
	g["plan"] = {"foe": int(chk["foe"]), "a": chk["a"], "m": chk["m"], "b": chk["b"], "state": St.ARMED, "s": 0.0, "leg_t": -1.0, 
		"t": gw.game_time, "wait": 0.0, "ends": {}, "storms": g["storms"]}
	g["plan"]["city"] = _target_city(gw, int(chk["foe"]), chk["b"])
	g["plan"]["war0"] = bool(chk.get("war", false))
	g.erase("done_arrow")
	_stat("plan_set")
	var c: Country = gw.country_by_id(cid)
	if c != null and c.is_player and not quiet:
		gw.say(c, Loc.mk("Группа «%s»: ПЛАН АТАКИ на %s — %s", [String(g["name"]), Loc.name(_cname(gw, int(chk["foe"]))), Loc.t("можно наступать") if bool(chk.get("war", false)) else Loc.t("ждёт войны")]))
	return true


static func cancel_plan(gw: GameWorld, cid: int, gid: int, quiet: bool = false) -> void :
	var g: Dictionary = ArmyGroups.by_id(gw, cid, gid)
	if g.is_empty() or plan_of(g).is_empty():
		return
	var was: bool = running(g)
	g["plan"] = {}
	_slots.erase(_key(cid, gid))
	var c: Country = gw.country_by_id(cid)
	if was:
		_back_to_front(gw, c, g)
	if c != null and c.is_player and not quiet:
		gw.say(c, Loc.mk("Группа «%s»: план атаки отменён%s", [String(g["name"]), Loc.t(", войска возвращаются на фронт") if was else ""]))



static func attack_now(gw: GameWorld, cid: int, gid: int) -> String:
	var g: Dictionary = ArmyGroups.by_id(gw, cid, gid)
	var pl: Dictionary = plan_of(g)
	if pl.is_empty():
		return Loc.t("Сначала нарисуйте ПЛАН АТАКИ")
	if running(g):
		return Loc.t("План уже выполняется")
	var c: Country = gw.country_by_id(cid)
	var foe: int = int(pl["foe"])
	if c == null or not c.at_war.has(foe):
		return Loc.t("Нет войны с %s: план начнётся с войной") % _cname(gw, foe)
	if gw.diplo.truce_on(cid, foe):
		return Loc.t("Перемирие с %s") % _cname(gw, foe)
	pl["wait"] = 0.0
	_begin(gw, c, g)
	_run(gw, c, g)
	return ""


static func _begin(gw: GameWorld, c: Country, g: Dictionary) -> void :
	var pl: Dictionary = plan_of(g)
	pl["state"] = St.RUN
	pl["s"] = 0.0
	pl["leg_t"] = -1.0
	pl["ends"] = {}
	pl["t_run"] = gw.game_time
	pl["ran"] = true
	_stat("plan_start")
	if c.is_player:
		gw.say(c, Loc.mk("Группа «%s»: НАСТУПЛЕНИЕ по плану на %s", [String(g["name"]), Loc.name(_cname(gw, int(pl["foe"])))]))
		Sfx.play("ui_alert", Vector2.INF, -6.0)
	else:
		var foe: Country = gw.country_by_id(int(pl["foe"]))
		if foe != null and foe.is_player:
			gw.say(foe, Loc.mk("%s наступает по плану: смотрите стрелку на карте", [Loc.name(c.name)]))



static func _pause(gw: GameWorld, c: Country, g: Dictionary, why: String, wait: float) -> void :
	var pl: Dictionary = plan_of(g)
	pl["state"] = St.ARMED
	pl["s"] = 0.0
	pl["leg_t"] = -1.0
	pl["ends"] = {}
	pl["wait"] = gw.game_time + wait
	_stat("plan_pause")
	_stat("pause_truce" if wait <= 0.0 else "pause_stall")
	_back_to_front(gw, c, g)
	if c.is_player:
		gw.say(c, Loc.mk("Группа «%s»: %s", [String(g["name"]), why]))


static func _back_to_front(gw: GameWorld, c: Country, g: Dictionary) -> void :
	if c == null:
		return
	for fid: int in g.get("fids", PackedInt32Array()):
		_retry.erase(fid)
	_slots.erase(_key(c.id, int(g["id"])))
	hold(gw, c, g)



static func _strength_of(gw: GameWorld, f: Facility) -> float:
	var hp: float = 0.0
	for u: Unit in gw.ops.strength_units(f):
		hp += u.hp
	return hp


static func _hp_share(gw: GameWorld, f: Facility) -> float:
	var hp: float = 0.0
	var mhp: float = 0.0
	for u: Unit in gw.ops.strength_units(f):
		hp += u.hp
		mhp += u.max_hp
	return hp / mhp if mhp > 0.0 else 0.0



static func _attackers(gw: GameWorld, c: Country, g: Dictionary) -> Array:
	var first: Array[Facility] = []
	var sup: Array[Facility] = []
	for f: Facility in members(gw, c.id, g):
		var st: String = _style(gw, f)
		if not c.is_player and st == "at":
			continue
		if SUP_STYLES.has(st):
			sup.append(f)
		else:
			first.append(f)
	if first.is_empty():
		first = sup
		sup = []
	return [first, sup]


static func _run(gw: GameWorld, c: Country, g: Dictionary) -> void :
	var pl: Dictionary = plan_of(g)
	var ops: Operations = gw.ops
	var now: float = gw.game_time
	var L: float = maxf(1.0, plan_len(pl))
	var step: float = clampf((LEG if c.is_player else AI_LEG) / L, 0.12, 1.0)
	var at: Array = _attackers(gw, c, g)
	var first: Array[Facility] = at[0]
	var sup: Array[Facility] = at[1]

	var stay: Dictionary = {}
	for f0: Facility in members(gw, c.id, g):
		if not first.has(f0) and not sup.has(f0):
			stay[f0.id] = true
	if not stay.is_empty():
		hold(gw, c, g, stay)
	if float(pl["leg_t"]) < 0.0:
		pl["s"] = minf(1.0, step)
		if (1.0 - float(pl["s"])) * L < LEG * 0.6:
			pl["s"] = 1.0
		_leg(gw, c, g, first, sup)
		return
	var ends: Dictionary = pl.get("ends", {})
	var active: int = 0
	var arrived: int = 0
	var lagging: Array[Facility] = []
	var restorm: Dictionary = {}
	for f: Facility in first:
		var op: Dictionary = ops.list.get(f, {})
		var fb: bool = not op.is_empty() and bool(op.get("fell_back", false))
		if not op.is_empty() and (int(op["kind"]) == Operations.Kind.RETREAT or fb):



			var fit: bool = _hp_share(gw, f) >= REJOIN_HP if not fb else _strength_of(gw, f) >= REJOIN_HP * float(op.get("peak", 1.0))
			if op.has("fp") and fit and now >= float(_retry.get(f.id, -1.0)):
				var e8: Array = ends.get(f.id, [])
				if not e8.is_empty() and int(e8[1]) >= 0:
					restorm[int(e8[1])] = true
				else:
					lagging.append(f)
				active += 1
			continue
		var mem: Array[Unit] = ops._army(f)
		if mem.is_empty():
			continue
		active += 1
		var e: Array = ends.get(f.id, [])
		if e.is_empty():
			lagging.append(f)
			continue
		var cidx: int = int(e[1])
		if cidx >= 0:
			var city: City = gw.cities[cidx]
			if city.country_id == c.id or not c.at_war.has(city.country_id):
				arrived += 1
			elif op.is_empty() or int(op["kind"]) == Operations.Kind.RETREAT or bool(op.get("fell_back", false)):
				restorm[cidx] = true
			continue
		var cen: Vector2 = ops._centre(mem)
		var top: Variant = gw.army.tac.ops.get(f)
		var holding: bool = top is Dictionary and int((top as Dictionary).get("phase", 0)) == 5
		if cen.distance_to(e[0]) < ARRIVE or holding:
			arrived += 1
		elif op.is_empty():
			lagging.append(f)
	if pl.has("siege"):

		var sg: Dictionary = pl["siege"]
		var sc: City = gw.cities[int(sg["city"])]
		if sc.country_id == c.id or not c.at_war.has(sc.country_id):
			pl.erase("siege")
			_done(gw, c, g, first)
			return
		var fit: Array[Facility] = []
		var near: int = 0
		for f11: Facility in first:
			var op11: Dictionary = ops.list.get(f11, {})
			if not op11.is_empty() and int(op11["kind"]) == Operations.Kind.RETREAT:
				continue
			if _hp_share(gw, f11) < SIEGE_HEAL:

				if ops.start(f11, Operations.Kind.RETREAT, Vector2.ZERO) == "":
					_tag(gw, f11, int(g["id"]), false)
				continue
			if true:
				fit.append(f11)
				var m11: Array[Unit] = ops._army(f11)
				if not m11.is_empty() and ops._centre(m11).distance_to(sg["at"]) < 260.0:
					near += 1
		var dec2: String = storm_check(gw, c, pl, sc, fit)
		var e12: Array = (pl.get("storms", {}) as Dictionary).get(sc.id, [0, 0.0, -999.0])
		if dec2 == "storm" and near * 2 >= maxi(1, fit.size()) and now - float(e12[2]) >= WAVE_GAP:
			pl.erase("siege")
			_leg(gw, c, g, fit, sup)
			return
		if dec2 == "skip" or now - float(sg["t"]) > SIEGE_T:
			var av: Dictionary = g.get("avoid", {})
			av[sc.id] = now + AVOID_T
			g["avoid"] = av
			_stat("siege_bypass")
			_done(gw, c, g, first, sg["at"])
			return
		return
	if active == 0:
		if now - float(pl["leg_t"]) > 30.0:
			_pause(gw, c, g, Loc.t("атака захлебнулась — перегруппировка на фронте"), STALL_T if c.is_player else AI_STALL_T)
		return
	var need: int = maxi(1, ceili((ARRIVE_SHARE if c.is_player else AI_ARRIVE) * float(active)))

	var leg_t: float = LEG_T
	if float(pl["s"]) >= 0.999:
		for e7: Variant in ends.values():
			var ci7: int = int((e7 as Array)[1])
			if ci7 >= 0 and gw.cities[ci7].country_id != c.id and c.at_war.has(gw.cities[ci7].country_id):
				leg_t = FINAL_T
				break
	if arrived >= need or now - float(pl["leg_t"]) > leg_t:
		if float(pl["s"]) >= 0.999:
			_done(gw, c, g, first)
			return
		pl["s"] = minf(1.0, float(pl["s"]) + step)
		if (1.0 - float(pl["s"])) * L < LEG * 0.6:
			pl["s"] = 1.0
		_leg(gw, c, g, first, sup)
		return

	for rc: int in restorm:
		var rcity: City = gw.cities[rc]
		var wave2: Array[Facility] = []
		for f9: Facility in first:
			var e9: Array = ends.get(f9.id, [])
			if not e9.is_empty() and int(e9[1]) == rc and _hp_share(gw, f9) >= SIEGE_HEAL:
				wave2.append(f9)
		if wave2.is_empty():
			continue
		var final2: bool = Vector2(rcity.center * GameWorld.CELL).distance_to(pl["b"]) < float(rcity.radius * GameWorld.CELL) + OBJ_R
		var dec3: String = storm_check(gw, c, pl, rcity, wave2)
		if c.is_player and not gw.ops.auto_orders_of(c.id) and not bool(g.get("auto", false)):
			dec3 = "storm"
		var e13: Array = (pl.get("storms", {}) as Dictionary).get(rc, [0, 0.0, -999.0])
		if dec3 == "storm" and now - float(e13[2]) < WAVE_GAP:
			continue
		if dec3 == "storm":
			_wave(gw, c, pl, rcity, wave2)
			lagging.append_array(wave2)
		elif final2:
			pl["s"] = 1.0
			_siege(gw, c, g, first, sup, rcity)
			if dec3 == "skip":
				pl["siege"]["t"] = - INF
			return
		else:
			var sk: Dictionary = pl.get("skip", {})
			sk[rc] = true
			pl["skip"] = sk
			_stat("storm_bypass")
			for f10: Facility in wave2:
				ends.erase(f10.id)
				lagging.append(f10)

	var was_quiet: bool = ops._quiet
	ops._quiet = true
	for f5: Facility in lagging:
		if now < float(_retry.get(f5.id, -1.0)):
			continue
		var e5: Array = ends.get(f5.id, [])
		var to: Vector2 = e5[0] if not e5.is_empty() else gw.econ.land_point(curve(pl, float(pl["s"])))
		var why: String = ops.start(f5, Operations.Kind.ATTACK, to)
		if why == "":
			_tag(gw, f5, int(g["id"]), false)
			if not e5.is_empty() and int(e5[1]) >= 0:
				ops.list[f5]["retreat_at"] = 2.0 if (c.is_player and not gw.ops.auto_orders_of(c.id) and not bool(g.get("auto", false))) else maxf(float(ops.list[f5].get("retreat_at", 0.5)), STORM_RETREAT if c.is_player else AI_STORM_RETREAT)
			if e5.is_empty():
				ends[f5.id] = [to, -1]
		else:
			_retry[f5.id] = now + RESEND
			why_of[f5.id] = why
	ops._quiet = was_quiet


static func _dps(u: Unit) -> float:
	var sp: Dictionary = Army.SPEC[u.type]
	return float(sp["dmg"]) / float(sp["cd"]) if float(sp["cd"]) > 0.0 else 0.0



static func _our_power(gw: GameWorld, fs: Array) -> float:
	var hp: float = 0.0
	var dps: float = 0.0
	for f: Facility in fs:
		for u: Unit in gw.ops._army(f):
			hp += u.hp
			dps += _dps(u)
	return hp * dps



static func _city_power(gw: GameWorld, c: Country, city: City) -> float:
	var cp: = Vector2(city.center * GameWorld.CELL)
	var r: float = float(city.radius * GameWorld.CELL) + 300.0
	var cap: bool = city.kind == City.Kind.CAPITAL
	var hp: float = city.garrison
	var dps: float = Army.GARRISON_DMG * (1.5 if cap else 1.0) / (0.7 if cap else 1.2)
	for o: Variant in gw.army._near(cp, r):
		var u: Unit = o
		if u.alive() and u.ground() and u.country_id != c.id and c.at_war.has(u.country_id) and u.pos.distance_to(cp) <= r:
			hp += u.hp
			dps += _dps(u)
	return hp * dps




static func storm_check(gw: GameWorld, c: Country, pl: Dictionary, city: City, fs: Array) -> String:
	var st: Dictionary = pl.get("storms", {})
	var e: Array = st.get(city.id, [0, 0.0, -999.0])
	if gw.game_time - float(e[2]) > AVOID_T:
		e = [0, 0.0, -999.0]
	var ours: float = _our_power(gw, fs)
	if int(e[0]) >= STORM_TRIES and ours < float(e[1]) * STORM_REINF:
		return "skip"
	return "storm" if ours >= maxf(1.0, _city_power(gw, c, city)) * STORM_RATIO else "wait"



static func _wave(gw: GameWorld, c: Country, pl: Dictionary, city: City, fs: Array) -> void :
	var st: Dictionary = pl.get("storms", {})
	var e: Array = st.get(city.id, [0, 0.0, -999.0])
	if gw.game_time - float(e[2]) < WAVE_GAP:
		return
	if gw.game_time - float(e[2]) > AVOID_T:
		e = [0, 0.0, -999.0]
	st[city.id] = [int(e[0]) + 1, _our_power(gw, fs), gw.game_time]
	pl["storms"] = st
	_stat("storm_wave")




static func _siege(gw: GameWorld, c: Country, g: Dictionary, first: Array[Facility], sup: Array[Facility], city: City) -> void :
	var pl: Dictionary = plan_of(g)
	var ops: Operations = gw.ops
	var now: float = gw.game_time
	var cp: = Vector2(city.center * GameWorld.CELL)
	var T: Vector2 = tangent(pl, 1.0)
	var side: = Vector2( - T.y, T.x)

	var want_d: float = float(city.radius * GameWorld.CELL) + SIEGE_SHORT
	var ph: Vector2 = pl["a"]
	for i0 in range(20, -1, -1):
		var q0: Vector2 = curve(pl, float(i0) / 20.0)
		if q0.distance_to(cp) >= want_d:
			ph = q0
			break
	ph = gw.econ.land_point(ph, 12)
	if not pl.has("siege"):
		pl["siege"] = {"city": city.id, "t": now, "at": ph}
		_stat("siege")
	pl["leg_t"] = now
	pl["ends"] = {}
	var ends: Dictionary = pl["ends"]
	var nf: int = first.size()
	var was_quiet: bool = ops._quiet
	ops._quiet = true
	var k: int = 0
	for f: Facility in first:
		var off: float = (float(k) - float(nf - 1) * 0.5) * 50.0
		k += 1
		if ops.list.has(f) and int(ops.list[f]["kind"]) == Operations.Kind.RETREAT:
			continue
		var e: Vector2 = gw.econ.land_point(ph + side * off)
		if ops.start(f, Operations.Kind.DEFEND, e) == "":
			_tag(gw, f, int(g["id"]), true)
			_face(gw, f, T)
			ends[f.id] = [e, -1]
	for f2: Facility in sup:
		if ops.list.has(f2) and int(ops.list[f2]["kind"]) == Operations.Kind.RETREAT:
			continue

		if ops.start(f2, Operations.Kind.ATTACK, cp) == "":
			_tag(gw, f2, int(g["id"]), false)
	ops._quiet = was_quiet




static func _leg(gw: GameWorld, c: Country, g: Dictionary, first: Array[Facility], sup: Array[Facility]) -> void :
	var new_leg: bool = true
	var pl: Dictionary = plan_of(g)
	var ops: Operations = gw.ops
	var now: float = gw.game_time
	var s: float = float(pl["s"])
	var L: float = maxf(1.0, plan_len(pl))
	var P: Vector2 = curve(pl, s)
	var T: Vector2 = tangent(pl, s)
	var side: = Vector2( - T.y, T.x)
	var prev: Vector2 = curve(pl, maxf(0.0, s - LEG / L))
	if new_leg:
		pl["leg_t"] = now
		pl["ends"] = {}
		pl["legs"] = int(pl.get("legs", 0)) + 1
		_stat("plan_legs")
	var ends: Dictionary = pl["ends"]
	var nf: int = first.size()
	var fr: Dictionary = front_of(g)
	var gap: float = clampf(float(fr.get("len", 600.0)) / maxf(1.0, float(nf)), 40.0, LINE_GAP if c.is_player else AI_LINE_GAP)
	var sorted: Array[Facility] = first.duplicate()
	var cen: Dictionary = {}
	for f: Facility in sorted:
		var mem: Array[Unit] = ops._army(f)
		cen[f] = ops._centre(mem) if not mem.is_empty() else f.center_px()
	sorted.sort_custom( func(a: Facility, b: Facility) -> bool: return (cen[a] as Vector2).dot(side) < (cen[b] as Vector2).dot(side))

	var objs: Array = []
	for city: City in gw.cities:
		if city.country_id == c.id or city.country_id <= 0 or not c.at_war.has(city.country_id):
			continue
		var cp: = Vector2(city.center * GameWorld.CELL)
		var rr: float = float(city.radius * GameWorld.CELL) + OBJ_R
		if Geometry2D.get_closest_point_to_segment(cp, prev - side * gap * float(nf) * 0.5, P + side * gap * float(nf) * 0.5).distance_to(cp) < rr\
		or Geometry2D.get_closest_point_to_segment(cp, prev, P).distance_to(cp) < rr:
			objs.append(city)
	var taken: Dictionary = {}
	var skipd: Dictionary = pl.get("skip", {})
	var manual: bool = c.is_player and not gw.ops.auto_orders_of(c.id) and not bool(g.get("auto", false))

	var fcity: City = null
	var fbd: float = INF
	for c3: City in objs:
		var d3: float = Vector2(c3.center * GameWorld.CELL).distance_to(pl["b"])
		if d3 < float(c3.radius * GameWorld.CELL) + OBJ_R and d3 < fbd:
			fbd = d3
			fcity = c3
	objs.sort_custom( func(a: City, b: City) -> bool: return a != fcity and b == fcity)
	for city2: City in objs:
		if skipd.has(city2.id):
			continue
		var cp2: = Vector2(city2.center * GameWorld.CELL)

		var want: int = maxi(2, ceili(float(nf) * 0.5)) if city2.kind != City.Kind.VILLAGE and nf >= 3 else mini(2, nf)
		var final: bool = city2 == fcity
		if final:
			want = nf
		var cand: Array[Facility] = []
		for f3: Facility in sorted:
			if not taken.has(f3.id):
				cand.append(f3)
		cand.sort_custom( func(a: Facility, b: Facility) -> bool: return (cen[a] as Vector2).distance_squared_to(cp2) < (cen[b] as Vector2).distance_squared_to(cp2))




		var keep: int = 1 if fcity != null and not final else 0
		if manual and not final:
			keep = 1
		var wave: Array = cand.slice(0, maxi(0, mini(want, cand.size() - keep)))
		if wave.is_empty():
			if keep > 0:
				_stat("way_kept_for_target")
			continue
		if not final:
			wave.append_array(sup)
		var dec: String = storm_check(gw, c, pl, city2, wave if final else cand)
		_stat("dec_%s_%s" % ["final" if final else "way", dec])
		if manual and dec != "storm":


			var wn: Dictionary = pl.get("warned", {})
			if not wn.has(city2.id):
				wn[city2.id] = true
				pl["warned"] = wn
				gw.say(c, Loc.mk("Группа «%s» штурмует %s: силы меньше гарнизона — ожидаются большие потери", [String(g["name"]), Loc.name(city2.name)]))
			_stat("manual_storm")
			dec = "storm"
		if dec != "storm":
			if final:
				pl["s"] = 1.0
				var first_siege: bool = not pl.has("siege")
				_siege(gw, c, g, first, sup, city2)
				if dec == "skip":
					pl["siege"]["t"] = - INF
				if first_siege and c.is_player:
					gw.say(c, Loc.mk("Группа «%s»: мало сил для штурма %s (гарнизон %d%%) — ждут у города, нужна поддержка или ещё армии", [String(g["name"]), Loc.name(city2.name), roundi(city2.garrison / maxf(1.0, city2.garrison_max) * 100.0)]))
				return
			skipd[city2.id] = true
			pl["skip"] = skipd
			_stat("storm_bypass")
			if c.is_player:
				gw.say(c, Loc.mk("Группа «%s»: город %s на пути обойдён — мало сил для штурма", [String(g["name"]), Loc.name(city2.name)]))
			continue
		_wave(gw, c, pl, city2, wave)
		if pl.has("siege") and int(pl["siege"]["city"]) == city2.id:
			pl.erase("siege")
		for i in wave.size():
			if first.has(wave[i]):
				taken[(wave[i] as Facility).id] = city2
	var was_quiet: bool = ops._quiet
	ops._quiet = true
	var k: int = 0
	for f2: Facility in sorted:
		var off: float = (float(k) - float(nf - 1) * 0.5) * gap
		k += 1
		if ops.list.has(f2) and int(ops.list[f2]["kind"]) == Operations.Kind.RETREAT:
			continue
		if not new_leg and now < float(_retry.get(f2.id, -1.0)):
			continue
		var why: String = ""
		var cidx: int = -1
		if taken.has(f2.id):
			var ct: City = taken[f2.id]
			cidx = ct.id
			var cur: Dictionary = ops.list.get(f2, {})
			if not cur.is_empty() and int(cur["kind"]) == Operations.Kind.ATTACK and int(cur.get("city", -1)) == ct.id:
				ends[f2.id] = [Vector2(ct.center * GameWorld.CELL), cidx]
				continue
			why = ops.start(f2, Operations.Kind.ATTACK, Vector2(ct.center * GameWorld.CELL))
			if why == "":
				ends[f2.id] = [Vector2(ct.center * GameWorld.CELL), cidx]
				ops.list[f2]["retreat_at"] = 2.0 if manual else maxf(float(ops.list[f2].get("retreat_at", 0.5)), STORM_RETREAT if c.is_player else AI_STORM_RETREAT)
		if cidx < 0 or why != "":
			var e: Vector2 = gw.econ.land_point(P + side * off)
			why = ops.start(f2, Operations.Kind.ATTACK, e)
			if why != "":
				e = gw.econ.land_point(P + side * off * 0.5)
				why = ops.start(f2, Operations.Kind.ATTACK, e)
			if why == "":
				ends[f2.id] = [e, -1]
		if why == "":
			_tag(gw, f2, int(g["id"]), false)
			why_of.erase(f2.id)
		else:
			_retry[f2.id] = now + RESEND
			why_of[f2.id] = why
			_stat("leg_refused")

	var ns: int = sup.size()
	var sb: float = clampf(s - SUP_BACK / L, 0.0, 1.0)
	var PS: Vector2 = curve(pl, sb)
	var TS: Vector2 = tangent(pl, sb)
	var sideS: = Vector2( - TS.y, TS.x)
	var j: int = 0
	for f4: Facility in sup:
		var off2: float = (float(j) - float(ns - 1) * 0.5) * gap * 1.3
		j += 1
		if ops.list.has(f4) and int(ops.list[f4]["kind"]) == Operations.Kind.RETREAT:
			continue
		var e2: Vector2 = gw.econ.land_point(PS + sideS * off2)
		var why2: String = ops.start(f4, Operations.Kind.DEFEND, e2)
		if why2 == "":
			_tag(gw, f4, int(g["id"]), true)
			_face(gw, f4, TS)
	ops._quiet = was_quiet



static func _target_city(gw: GameWorld, foe: int, b: Vector2) -> int:
	var best: int = -1
	var bd: float = INF
	for city: City in gw.cities:
		if city.country_id != foe:
			continue
		var d: float = Vector2(city.center * GameWorld.CELL).distance_to(b)
		if d < float(city.radius * GameWorld.CELL) + OBJ_R and d < bd:
			bd = d
			best = city.id
	return best





static func plan_stale(gw: GameWorld, c: Country, g: Dictionary) -> String:
	var pl: Dictionary = plan_of(g)
	if pl.is_empty() or c == null:
		return ""
	if (g.get("fids", PackedInt32Array()) as PackedInt32Array).is_empty():
		return "no_armies"
	var foe: int = int(pl["foe"])
	var fc: Country = gw.country_by_id(foe)
	if fc == null or fc.eliminated:
		return "foe_gone"
	if not pl.has("city"):
		pl["city"] = _target_city(gw, foe, pl["b"])
	var ci: int = int(pl["city"])
	if ci >= 0 and ci < gw.cities.size():
		if gw.cities[ci].country_id != foe:
			return "taken" if gw.cities[ci].country_id == c.id or gw.diplo.allied(c.id, gw.cities[ci].country_id) else "owner_changed"
	else:
		var o: int = owner_at(gw, pl["b"])
		if o == c.id or (o > 0 and gw.diplo.allied(c.id, o)):
			return "taken"
	var war: bool = c.at_war.has(foe) and not gw.diplo.truce_on(c.id, foe)
	if not war and (bool(pl.get("ran", false)) or bool(pl.get("war0", false))):
		return "war_over" if not c.at_war.has(foe) else "truce"
	return ""




const LOC_STALE: Dictionary = {"no_armies": "в группе нет армий", "foe_gone": "противник разгромлен", "taken": "цель взята", 
	"owner_changed": "цель сменила владельца", "war_over": "война окончена", "truce": "перемирие"}


static func _end_plan(gw: GameWorld, c: Country, g: Dictionary, why: String) -> void :
	var pl: Dictionary = plan_of(g)
	_stat("plan_stale")
	if why == "taken" and int(pl["state"]) == St.RUN:
		_done(gw, c, g, _attackers(gw, c, g)[0])
		return
	_ghost(g, pl, why == "taken")
	var was: bool = int(pl["state"]) == St.RUN
	g["plan"] = {}
	g["next_plan"] = gw.game_time + float(AI_REPLAN[GameConfig.diff_of(c)])
	_slots.erase(_key(c.id, int(g["id"])))
	if was:
		_back_to_front(gw, c, g)
	if c.is_player:
		gw.say(c, Loc.mk("Группа «%s»: план атаки снят — %s", [String(g["name"]), Loc.t(String(LOC_STALE.get(why, why)))]))



static func _ghost(g: Dictionary, pl: Dictionary, ok: bool) -> void :
	if pl.is_empty():
		return
	g["done_arrow"] = {"a": pl["a"], "m": pl["m"], "b": pl["b"], "ms": Time.get_ticks_msec(), "ok": ok}



static func _done(gw: GameWorld, c: Country, g: Dictionary, first: Array[Facility], at: Vector2 = Vector2.INF) -> void :
	var pl: Dictionary = plan_of(g)
	var b: Vector2 = pl["b"] if not at.is_finite() else at
	var T: Vector2 = tangent(pl, 1.0)
	var side: = Vector2( - T.y, T.x)
	var W: float = clampf(float(first.size()) * 160.0 + 200.0, 400.0, FRONT_MAX * 0.5)
	var pts: = PackedVector2Array()
	var nrm: = PackedVector2Array()
	var n: int = maxi(3, ceili(W / STEP))
	for i in n + 1:
		pts.append(b + side * (float(i) / float(n) - 0.5) * W)
		nrm.append(T)
	var foe: int = int(pl["foe"])
	var fkind: String = "line"
	var fat: Vector2 = b
	if c.is_player:


		var geo2: Dictionary = border_geo(gw, c.id, foe, b, W, maxf(BORDER_R, W * 0.6) + 300.0, false, pts)
		if bool(geo2.get("ok", false)) and nearest_on(geo2["pts"], b).distance_to(b) < NEAR_B:
			pts = geo2["pts"]
			nrm = geo2["nrm"]
			W = float(geo2["len"])
			fkind = "border"
			fat = geo2["cat"]
			_stat("plan_done_border")
		else:
			var lp: Array = []
			var lw: float = 0.0
			for pp: PackedVector2Array in land_parts(gw, c.id, pts, 0):
				var sp0: PackedVector2Array = smooth_part(gw, c.id, pp, 0)
				lp.append(sp0)
				lw += poly_len(sp0)
			if not lp.is_empty():
				pts = join_parts(lp)
				nrm = PackedVector2Array()
				for q1: Vector2 in pts:
					nrm.append(T)
				W = maxf(lw, STEP)
			_stat("plan_done_line")
	g["front"] = {"foe": foe, "kind": fkind, "pts": pts, "nrm": nrm, "len": W, "at": fat, "want": maxf(W, float(front_of(g).get("want", W))), 
		"t": gw.game_time, "rt": gw.game_time, "take": float(front_of(g).get("take", - INF))}
	with_vis(gw, c.id, g["front"])
	_ghost(g, pl, not at.is_finite())
	g["plan"] = {}
	g["next_plan"] = gw.game_time + float(AI_REPLAN[GameConfig.diff_of(c)])
	_slots.erase(_key(c.id, int(g["id"])))
	for fid: int in g.get("fids", PackedInt32Array()):
		_retry.erase(fid)
	_stat("plan_done")
	hold(gw, c, g)
	if c.is_player:
		gw.say(c, Loc.mk("Группа «%s»: план выполнен — новый фронт", [String(g["name"])]))
		Sfx.play("ui_capture", Vector2.INF, -8.0)





static func set_auto(gw: GameWorld, cid: int, gid: int, on: bool) -> void :
	var g: Dictionary = ArmyGroups.by_id(gw, cid, gid)
	if g.is_empty():
		return
	g["auto"] = on
	_ai_t.erase("g%d:%d" % [cid, gid])
	var c: Country = gw.country_by_id(cid)
	if c != null and c.is_player:
		gw.say(c, Loc.mk("Группа «%s»: АВТО-ФРОНТ %s", [String(g["name"]), Loc.t("включён") if on else Loc.t("выключен")]))



static func _war_foe(gw: GameWorld, c: Country, near: Vector2) -> Country:
	var best: Country = null
	var bd: float = INF
	for id: int in c.at_war.keys():
		var e: Country = gw.country_by_id(id)
		if e == null or e.eliminated or e.capital_id < 0:
			continue
		var d: float = INF
		for cid in e.city_ids:
			d = minf(d, Vector2(gw.cities[cid].center * GameWorld.CELL).distance_to(near))
		if d < bd:
			bd = d
			best = e
	return best




static func auto_think(gw: GameWorld, c: Country, g: Dictionary) -> void :
	var k: String = "g%d:%d" % [c.id, int(g["id"])]
	if gw.game_time < float(_ai_t.get(k, -1.0)):
		return
	_ai_t[k] = gw.game_time + AI_DT
	if c.at_war.is_empty() or running(g):
		return
	var cen: Vector2 = centre(gw, c.id, g)
	if not cen.is_finite():
		return
	var foe: Country = _war_foe(gw, c, cen)
	if foe == null:
		return
	var fr: Dictionary = front_of(g)
	if fr.is_empty() or int(fr["foe"]) != foe.id:
		var geo: Dictionary = border_geo(gw, c.id, foe.id, cen, clampf(STRETCH_PER * float((g["fids"] as PackedInt32Array).size()) * 1.5, STRETCH_MIN, FRONT_MAX))
		if not geo.get("ok", false):
			return
		geo["kind"] = "border"
		geo["at"] = cen
		geo["want"] = float(geo["len"])
		set_front(gw, c.id, int(g["id"]), geo)
		_stat("auto_front")
		return
	if plan_of(g).is_empty() and gw.game_time >= float(g.get("next_plan", 0.0)):
		var chk: Dictionary = auto_plan(gw, c, g, foe)
		if bool(chk.get("ok", false)):
			set_plan(gw, c.id, int(g["id"]), chk)
			_stat("auto_plan")




static func auto_plan(gw: GameWorld, c: Country, g: Dictionary, foe: Country) -> Dictionary:
	var fr: Dictionary = front_of(g)
	if fr.is_empty():
		return {"ok": false}
	var pts: PackedVector2Array = fr["pts"]
	var goal: Dictionary = gw.diplo.war_goals.get("%d>%d" % [c.id, foe.id], {})
	var cand: Array = []
	for cid in foe.city_ids:
		var city: City = gw.cities[cid]
		var cp: = Vector2(city.center * GameWorld.CELL)
		var a: Vector2 = nearest_on(pts, cp)
		var d: float = a.distance_to(cp)
		if d > Operations.MAX_RANGE * PLAN_MAX_K * 0.9:
			continue
		if gw.game_time < float((g.get("avoid", {}) as Dictionary).get(cid, -1.0)):
			continue
		var sc: float = d + city.garrison * 1.5 + (900.0 if city.kind == City.Kind.CAPITAL else 0.0) - (300.0 if city.kind == City.Kind.VILLAGE else 0.0)
		if not goal.is_empty() and Vector2(Vector2i(goal["cell"]) * GameWorld.CELL).distance_to(cp) < float(city.radius * GameWorld.CELL) + 200.0:
			sc -= 1500.0
		cand.append([sc, a, cp])
	cand.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for i in mini(4, cand.size()):
		var a2: Vector2 = cand[i][1]
		var b2: Vector2 = cand[i][2]

		var dl: float = a2.distance_to(b2)
		if dl < 320.0 and dl > 1.0:
			var b3: Vector2 = b2 + (b2 - a2) / dl * (320.0 - dl)
			if owner_at(gw, b3) == foe.id and gw.ops._dry(b3):
				b2 = b3
		var chk: Dictionary = plan_check(gw, c.id, int(g["id"]), a2, b2)
		if bool(chk.get("ok", false)) and not bool(chk.get("sea", false)) and int(chk.get("pass", 0)) <= 0:
			return chk
		_stat("auto_plan_route_skip")
	return {"ok": false}








static func ai_think(gw: GameWorld, c: Country, P: Dictionary, foe: Country, reserve: Facility, skip: Dictionary) -> void :
	_check_world(gw)
	var now: float = gw.game_time
	if now < float(_ai_t.get(c.id, -1.0)):
		return
	_ai_t[c.id] = now + AI_DT + float(c.id % 5) * 0.7
	var g: Dictionary = {}
	for g0: Dictionary in c.army_groups:
		if bool(g0.get("ai", false)):
			g = g0
			break
	if not ai_on:
		if not g.is_empty():
			_release(gw, c.id, g)
			ArmyGroups.disband(gw, c.id, int(g["id"]))
		return
	var war: bool = foe != null and c.at_war.has(foe.id)
	_stat("ai_think")
	if not g.is_empty():


		var ff: int = int(front_of(g).get("foe", -1))
		if ff >= 0 and not c.at_war.has(ff) and (gw.diplo.allied(c.id, ff) or gw.diplo.truce_on(c.id, ff)):
			_release(gw, c.id, g)
			ArmyGroups.disband(gw, c.id, int(g["id"]))
			_stat("ai_front_friend")
			g = {}
	if foe == null or (foe != null and gw.diplo.allied(c.id, foe.id)):
		if not g.is_empty() and not running(g):
			if now - float(g.get("calm", now)) > AI_CALM:
				_release(gw, c.id, g)
				ArmyGroups.disband(gw, c.id, int(g["id"]))
				_stat("ai_front_drop")
			elif not g.has("calm"):
				g["calm"] = now
		return
	if not g.is_empty():
		g.erase("calm")
		if (g["fids"] as PackedInt32Array).is_empty() and not running(g):
			ArmyGroups.disband(gw, c.id, int(g["id"]))
			g = {}

	var hs: Array[Facility] = []
	var total: int = 0
	for f: Facility in gw.mil.facilities:
		if f.kind != Facility.Kind.BARRACKS or f.country_id != c.id or not gw.mil.alive(f):
			continue
		total += 1
		if f == reserve or skip.has(f) or (gw.naval != null and gw.naval.busy(f)):
			continue
		if gw.army.units_of(f).size() < 3:
			continue
		var top: Variant = gw.army.tac.ops.get(f)
		if f.group_id < 0 and top is Dictionary and not bool((top as Dictionary).get("area", false)):
			continue
		hs.append(f)
	if total < 2:
		_stat("ai_few_barracks")
		return
	var fcap: = Vector2(gw.cities[foe.capital_id].center * GameWorld.CELL)
	var mycap: = Vector2(gw.cities[c.capital_id].center * GameWorld.CELL)

	var share: float = AI_WAR_SHARE if war else float(AI_SHARE[GameConfig.diff_of(c)]) * (0.85 + 0.3 * float(P.get("caution", 0.5)))
	var want: int = clampi(roundi(float(total) * share), 2, total)
	hs.sort_custom( func(a: Facility, b: Facility) -> bool: return a.center_px().distance_squared_to(fcap) < b.center_px().distance_squared_to(fcap))
	var fids: = PackedInt32Array()
	var n_at: int = 0
	for f2: Facility in hs:
		if fids.size() >= want:
			break
		if f2.army_build == "at":
			if n_at >= maxi(1, want / 3):
				continue
			n_at += 1
		fids.append(f2.id)
	if g.is_empty():
		if fids.size() < 2:
			_stat("ai_few_armies")
			return
		var anchor: Vector2 = mycap.lerp(fcap, 0.5)
		var geo: Dictionary = border_geo(gw, c.id, foe.id, anchor, FRONT_MAX, SCAN_R, false)
		if not geo.get("ok", false):
			geo = border_geo(gw, c.id, foe.id, mycap, FRONT_MAX, SCAN_R, false)
		if not geo.get("ok", false):
			_stat("ai_no_border")
			return
		g = ArmyGroups.create(gw, c.id, "Фронт", c.id % ArmyGroups.N_COLORS, "emb_star", fids)
		if g.is_empty():
			return
		g["ai"] = true
		g["auto"] = true
		geo["kind"] = "border"
		geo["at"] = (geo["pts"] as PackedVector2Array)[(geo["pts"] as PackedVector2Array).size() / 2]
		geo["want"] = FRONT_MAX
		set_front(gw, c.id, int(g["id"]), geo, true)
		_stat("ai_front")
	else:
		var add: = PackedInt32Array()
		for fid: int in fids:
			if not (g["fids"] as PackedInt32Array).has(fid):
				add.append(fid)
		var have: int = (g["fids"] as PackedInt32Array).size()
		if not add.is_empty() and have < want:
			ArmyGroups.add(gw, c.id, int(g["id"]), add.slice(0, want - have))
		var fr: Dictionary = front_of(g)
		if (fr.is_empty() or int(fr["foe"]) != foe.id) and not running(g):
			var geo2: Dictionary = border_geo(gw, c.id, foe.id, mycap.lerp(fcap, 0.5), FRONT_MAX, SCAN_R, false)
			if not geo2.get("ok", false):
				geo2 = border_geo(gw, c.id, foe.id, mycap, FRONT_MAX, SCAN_R, false)
			if geo2.get("ok", false):
				geo2["kind"] = "border"
				geo2["at"] = (geo2["pts"] as PackedVector2Array)[(geo2["pts"] as PackedVector2Array).size() / 2]
				geo2["want"] = FRONT_MAX
				g["plan"] = {}
				set_front(gw, c.id, int(g["id"]), geo2, true)
			else:
				_release(gw, c.id, g)
				ArmyGroups.disband(gw, c.id, int(g["id"]))
				return

	var plan_now: bool = ai_plans and (war or float(P.get("aggr", 0.5)) >= 0.5 or GameConfig.diff_of(c) >= 2)
	if plan_now and plan_of(g).is_empty() and now >= float(g.get("next_plan", 0.0)) and not front_of(g).is_empty():
		var chk: Dictionary = auto_plan(gw, c, g, foe)
		if bool(chk.get("ok", false)):
			set_plan(gw, c.id, int(g["id"]), chk, true)
			_stat("ai_plan")
		else:
			g["next_plan"] = now + 60.0





static func carry(d: Dictionary, out: Dictionary) -> void :
	var fr: Variant = d.get("front", {})
	if fr is Dictionary and not (fr as Dictionary).is_empty():
		var f: Dictionary = fr
		var pts: Variant = f.get("pts")
		var nrm: Variant = f.get("nrm")
		if pts is PackedVector2Array and nrm is PackedVector2Array and (pts as PackedVector2Array).size() >= 2 and (pts as PackedVector2Array).size() == (nrm as PackedVector2Array).size():
			var k: String = String(f.get("kind", "border"))
			out["front"] = {"foe": int(f.get("foe", -1)), "kind": k if k in ["border", "stretch", "line", "drawn"] else "border", "pts": pts, "nrm": nrm, 
				"len": float(f.get("len", poly_len(pts))), "at": f.get("at", (pts as PackedVector2Array)[0]) if f.get("at") is Vector2 else (pts as PackedVector2Array)[0], 
				"want": float(f.get("want", FRONT_MAX)), "t": float(f.get("t", 0.0)), "rt": float(f.get("rt", 0.0)), "short": bool(f.get("short", false)), 
				"take": float(f.get("take", f.get("t", 0.0)))}
			if int(f.get("host", -1)) > 0:
				out["front"]["host"] = int(f["host"])
			if f.get("raw") is PackedVector2Array and (f["raw"] as PackedVector2Array).size() >= 2:
				out["front"]["raw"] = f["raw"]
				out["front"]["sgn"] = 1.0 if float(f.get("sgn", 1.0)) >= 0.0 else -1.0
			elif k == "drawn":
				out["front"]["kind"] = "line"
			var vv: Variant = f.get("vis")
			var vnv: Variant = f.get("vnrm")
			if vv is PackedVector2Array and vnv is PackedVector2Array and (vv as PackedVector2Array).size() >= 2 and (vv as PackedVector2Array).size() == (vnv as PackedVector2Array).size():
				out["front"]["vis"] = vv
				out["front"]["vnrm"] = vnv
			else:
				out["front"]["rt"] = -999.0
	var pl: Variant = d.get("plan", {})
	if out.has("front") and pl is Dictionary and not (pl as Dictionary).is_empty():
		var p: Dictionary = pl
		if p.get("a") is Vector2 and p.get("b") is Vector2:
			var ends: Dictionary = {}
			var re: Variant = p.get("ends", {})
			if re is Dictionary:
				for kk: Variant in re:
					var e: Variant = re[kk]
					if e is Array and (e as Array).size() == 2 and (e as Array)[0] is Vector2:
						ends[int(kk)] = [(e as Array)[0], int((e as Array)[1])]
			out["plan"] = {"foe": int(p.get("foe", -1)), "a": p["a"], "m": p.get("m", Vector2.INF) if p.get("m") is Vector2 else Vector2.INF, "b": p["b"], 
				"state": clampi(int(p.get("state", 0)), 0, 1), "s": clampf(float(p.get("s", 0.0)), 0.0, 1.0), "leg_t": float(p.get("leg_t", -1.0)), 
				"t": float(p.get("t", 0.0)), "wait": float(p.get("wait", 0.0)), "ends": ends, "legs": int(p.get("legs", 0))}
			if p.has("city"):
				out["plan"]["city"] = int(p["city"])
			for kb: String in ["ran", "war0"]:
				if bool(p.get(kb, false)):
					out["plan"][kb] = true
	for b: String in ["auto", "ai"]:
		if bool(d.get(b, false)):
			out[b] = true
	if d.has("next_plan"):
		out["next_plan"] = float(d["next_plan"])
	if d.has("dig_t"):
		out["dig_t"] = float(d["dig_t"])

	var pl2: Dictionary = out.get("plan", {})
	var raw: Variant = d.get("plan", {})
	if not pl2.is_empty() and raw is Dictionary:
		for k4: String in ["storms", "skip"]:
			var v: Variant = (raw as Dictionary).get(k4)
			if v is Dictionary:
				var o2: Dictionary = {}
				for kk: Variant in v:
					o2[int(kk)] = (v as Dictionary)[kk] if k4 == "storms" and (v as Dictionary)[kk] is Array and ((v as Dictionary)[kk] as Array).size() == 3 else true
				pl2[k4] = o2
		var sgv: Variant = (raw as Dictionary).get("siege")
		if sgv is Dictionary and (sgv as Dictionary).get("at") is Vector2:
			pl2["siege"] = {"city": int((sgv as Dictionary).get("city", -1)), "t": float((sgv as Dictionary).get("t", 0.0)), "at": (sgv as Dictionary)["at"]}
			if int(pl2["siege"]["city"]) < 0:
				pl2.erase("siege")
	var gst: Variant = d.get("storms")
	if gst is Dictionary:
		var o4: Dictionary = {}
		for k6: Variant in gst:
			if (gst as Dictionary)[k6] is Array and ((gst as Dictionary)[k6] as Array).size() == 3:
				o4[int(k6)] = (gst as Dictionary)[k6]
		out["storms"] = o4
		if out.has("plan"):
			(out["plan"] as Dictionary)["storms"] = o4
	var av: Variant = d.get("avoid")
	if av is Dictionary:
		var o3: Dictionary = {}
		for k5: Variant in av:
			o3[int(k5)] = float((av as Dictionary)[k5])
		out["avoid"] = o3


static var _world_id: int = 0
static var _last_t: float = -1.0



static func _check_world(gw: GameWorld) -> void :
	var wid: int = gw.get_instance_id()
	if wid != _world_id or gw.game_time < _last_t - 1.0:
		reset()
		_world_id = wid
	_last_t = gw.game_time



static func reset() -> void :
	_held.clear()
	_dig_t.clear()
	_react.clear()
	_threat_t.clear()
	_last_t = -1.0
	_next.clear()
	_slots.clear()
	_retry.clear()
	why_of.clear()
	_ai_t.clear()
	_mates_t.clear()
	_stuck_said.clear()
	_bad.clear()
	_bad_n.clear()
	_way_fail.clear()
	_stuck_t.clear()
	_evict_t = -1.0
	_wb_s = -1



static func status(gw: GameWorld, cid: int, g: Dictionary) -> String:
	var fr: Dictionary = front_of(g)
	if fr.is_empty():
		return ""
	var pl: Dictionary = plan_of(g)
	var fname: String = _cname(gw, int(fr["foe"]))
	if pl.is_empty():
		return Loc.t("ФРОНТ: %s · %.1f км") % [fname, float(fr["len"]) / 1000.0]
	if int(pl["state"]) == St.RUN:
		return Loc.t("НАСТУПЛЕНИЕ: %d%% пути") % roundi(float(pl["s"]) * 100.0)
	var c: Country = gw.country_by_id(cid)
	var war: bool = c != null and c.at_war.has(int(pl["foe"]))
	if war and gw.diplo != null and gw.diplo.truce_on(cid, int(pl["foe"])):
		return Loc.t("ПЛАН АТАКИ на %s · перемирие — ждёт") % _cname(gw, int(pl["foe"]))
	if war and float(pl.get("wait", 0.0)) > gw.game_time + 1.0:
		return Loc.t("ПЛАН АТАКИ на %s · перегруппировка, атака через %d с") % [_cname(gw, int(pl["foe"])), ceili(float(pl["wait"]) - gw.game_time)]
	return Loc.t("ПЛАН АТАКИ на %s · %s") % [_cname(gw, int(pl["foe"])), Loc.t("можно наступать") if war else Loc.t("ждёт войны")]
