extends RefCounted











const DARK: = Color(0.06, 0.045, 0.03, 0.82)
const CACHE_MAX: int = 384

static var _sm: Dictionary = {}
static var _ln: Dictionary = {}
static var _dr: Dictionary = {}



static func _bucket(step: float) -> float:
	return pow(2.0, roundf(log(maxf(step, 0.01)) / log(2.0) * 4.0) / 4.0)



static func smooth(pts: PackedVector2Array, step: float = 10.0) -> PackedVector2Array:
	var n: int = pts.size()
	if n < 3:
		return pts
	var st0: float = _bucket(step)
	var key: int = hash([pts, st0])
	var hit: Variant = _sm.get(key)
	if hit != null:
		return hit


	pts = simplify(pts, st0 * 0.8)
	n = pts.size()
	if n < 3:
		_sm[key] = pts
		return pts
	var total: float = 0.0
	for i in range(1, n):
		total += pts[i - 1].distance_to(pts[i])
	var st: float = maxf(st0, total / 16.0)
	var rs: = PackedVector2Array([pts[0]])
	var acc: float = 0.0
	for i in range(1, n):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var seg: float = a.distance_to(b)
		if seg <= 0.0001:
			continue
		var t: float = st - acc
		while t <= seg:
			rs.append(a.lerp(b, t / seg))
			t += st
		acc = seg - (t - st)
	if rs[rs.size() - 1].distance_to(pts[n - 1]) > 0.5:
		rs.append(pts[n - 1])
	var cur: PackedVector2Array = rs
	if rs.size() >= 3:
		for _p in (2 if rs.size() <= 9 else 1):
			var nx: = PackedVector2Array([cur[0]])
			for i in range(cur.size() - 1):
				var p: Vector2 = cur[i]
				var q: Vector2 = cur[i + 1]
				nx.append(p.lerp(q, 0.25))
				nx.append(p.lerp(q, 0.75))
			nx.append(cur[cur.size() - 1])
			cur = nx
	if _sm.size() > CACHE_MAX:
		_sm.clear()
	_sm[key] = cur
	return cur




static func simplify(pts: PackedVector2Array, eps: float) -> PackedVector2Array:
	var n: int = pts.size()
	if n < 3:
		return pts
	var a: = PackedVector2Array([pts[0]])
	for i in range(1, n - 1):
		if pts[i].distance_to(a[a.size() - 1]) < eps:
			continue
		a.append(pts[i])
	if pts[n - 1].distance_to(a[a.size() - 1]) < eps and a.size() > 1:
		a[a.size() - 1] = pts[n - 1]
	else:
		a.append(pts[n - 1])

	var changed: bool = true
	var guard: int = 0
	while changed and a.size() >= 3 and guard < 8:
		changed = false
		guard += 1
		var b: = PackedVector2Array([a[0]])
		for i in range(1, a.size() - 1):
			var u: Vector2 = (a[i] - b[b.size() - 1]).normalized()
			var v: Vector2 = (a[i + 1] - a[i]).normalized()
			if u.dot(v) < -0.42:
				changed = true
				continue
			b.append(a[i])
		b.append(a[a.size() - 1])
		a = b
	if a.size() < 3:
		return a
	var keep: = PackedByteArray()
	keep.resize(a.size())
	keep[0] = 1
	keep[a.size() - 1] = 1
	var stack: Array = [[0, a.size() - 1]]
	while not stack.is_empty():
		var se: Array = stack.pop_back()
		var i0: int = se[0]
		var i1: int = se[1]
		var best: int = -1
		var bd: float = eps
		for i in range(i0 + 1, i1):
			var d: float = Geometry2D.get_closest_point_to_segment(a[i], a[i0], a[i1]).distance_to(a[i])
			if d > bd:
				bd = d
				best = i
		if best >= 0:
			keep[best] = 1
			stack.append([i0, best])
			stack.append([best, i1])
	var out: = PackedVector2Array()
	for i in a.size():
		if keep[i] == 1:
			out.append(a[i])
	return out



static func slice(pts: PackedVector2Array, cum: PackedFloat32Array, d0: float, d1: float) -> PackedVector2Array:
	var out: = PackedVector2Array()
	if pts.size() < 2 or d1 <= d0:
		return out

	var i0: int = maxi(1, cum.bsearch(d0, true)) if cum.size() == pts.size() else 1
	for i in range(i0, pts.size()):
		var a0: float = cum[i - 1]
		var a1: float = cum[i]
		if a1 < d0:
			continue
		if a0 > d1:
			break
		var seg: float = maxf(0.0001, a1 - a0)
		if out.is_empty():
			out.append(pts[i - 1].lerp(pts[i], clampf((d0 - a0) / seg, 0.0, 1.0)))
		if a1 >= d1:
			out.append(pts[i - 1].lerp(pts[i], clampf((d1 - a0) / seg, 0.0, 1.0)))
			break
		out.append(pts[i])
	return out


static func lengths(pts: PackedVector2Array) -> PackedFloat32Array:
	var key: int = hash(pts)
	var hit: Variant = _ln.get(key)
	if hit != null and (hit as PackedFloat32Array).size() == pts.size():
		return hit
	var cum: = PackedFloat32Array()
	cum.resize(pts.size())
	var acc: float = 0.0
	for i in pts.size():
		if i > 0:
			acc += pts[i - 1].distance_to(pts[i])
		cum[i] = acc
	if _ln.size() > CACHE_MAX:
		_ln.clear()
	_ln[key] = cum
	return cum



static func _entry(rel: PackedVector2Array, w: float, k: float, sm: bool, trim_in: float, arrow: bool) -> Dictionary:
	var key: int = hash([rel, w, _bucket(k), sm, trim_in, arrow])
	var hit: Variant = _dr.get(key)
	if hit != null:
		return hit
	var pts: PackedVector2Array = smooth(rel, 9.0 * k) if sm else rel
	var cum: PackedFloat32Array = lengths(pts)
	var L: float = cum[cum.size() - 1]
	var trim: float = trim_in * k
	if trim > 0.0 and L > trim * 2.0:
		pts = slice(pts, cum, 0.0, L - trim)
		cum = lengths(pts)
		L = cum[cum.size() - 1]
	var head_l: float = (5.0 + w * 2.2) * k
	var body: PackedVector2Array = slice(pts, cum, 0.0, maxf(0.0, L - head_l * 0.6)) if arrow and L > head_l * 1.5 else pts
	if body.size() < 2:
		body = pts
	var tip: Vector2 = pts[pts.size() - 1]
	var dir: = Vector2.ZERO
	if arrow:
		var back: PackedVector2Array = slice(pts, cum, maxf(0.0, L - head_l), L)
		dir = (tip - back[0]).normalized() if back.size() >= 2 and back[0] != tip else (tip - pts[pts.size() - 2]).normalized()
	var box: = Rect2(pts[0], Vector2.ZERO)
	for p: Vector2 in pts:
		box = box.expand(p)
	var e: Dictionary = {"pts": pts, "cum": cum, "L": L, "body": body, "tip": tip, "dir": dir, "box": box, "head_l": head_l}
	if _dr.size() > CACHE_MAX:
		_dr.clear()
	_dr[key] = e
	return e






static func draw(ci: CanvasItem, pts_in: PackedVector2Array, col: Color, w: float, t: float, k: float = 1.0, opts: Dictionary = {}) -> void :
	if pts_in.size() < 2:
		return
	var p0: Vector2 = pts_in[0]
	var rel: PackedVector2Array = Transform2D(0.0, - p0) * pts_in
	var arrow: bool = bool(opts.get("arrow", true))
	var e: Dictionary = _entry(rel, w, k, bool(opts.get("smooth", true)), float(opts.get("trim", 0.0)), arrow)
	var L: float = e["L"]
	if L < 1.0 * k:
		return

	var vr: Rect2 = ci.get_global_transform_with_canvas().affine_inverse() * Rect2(Vector2.ZERO, ci.get_viewport_rect().size)
	var box: Rect2 = (e["box"] as Rect2)
	if not vr.grow((w + 24.0) * k).intersects(Rect2(box.position + p0, box.size)):
		return
	var a: float = float(opts.get("alpha", 1.0))
	var ww: float = w * k
	var head_l: float = e["head_l"]
	var body: PackedVector2Array = e["body"]
	var dk: = Color(DARK, DARK.a * a)
	ci.draw_set_transform(p0)
	ci.draw_polyline(body, dk, ww + 3.0 * k, true)
	ci.draw_polyline(body, Color(col, col.a * a), ww, true)
	if w >= 2.5:
		ci.draw_polyline(body, Color(col.lightened(0.45), 0.55 * a), maxf(1.0 * k, ww * 0.34))
	if bool(opts.get("flow", true)):
		flow(ci, e["pts"], col, w, t, k, a, head_l * 0.6 if arrow else 0.0, e["cum"])
	if arrow:
		head(ci, e["tip"], e["dir"], col, w, k, a)
	ci.draw_set_transform(Vector2.ZERO)
	for p: Vector2 in opts.get("dots", PackedVector2Array()):
		ci.draw_circle(p, (w * 0.5 + 3.5) * k, dk)
		ci.draw_circle(p, (w * 0.5 + 2.0) * k, Color(col, a))
		ci.draw_circle(p, maxf(1.0, w * 0.3) * k, Color(1, 1, 1, 0.9 * a))




static func flow(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float, t: float, k: float = 1.0, a: float = 1.0, stop: float = 0.0, cum_in: PackedFloat32Array = PackedFloat32Array()) -> void :
	if pts.size() < 2:
		return
	var cum: PackedFloat32Array = cum_in if cum_in.size() == pts.size() else lengths(pts)
	var L: float = cum[cum.size() - 1]
	if L < 30.0 * k:
		return
	var gap: float = clampf(L * 0.5, 70.0 * k, 160.0 * k)
	var tail: float = 26.0 * k
	var hd: float = fmod(t * 55.0 * k, gap)
	var lc: Color = col.lightened(0.7)
	var wl: float = maxf(1.0 * k, w * k * 0.75)
	while hd < L - stop:
		_comet(ci, pts, cum, maxf(0.0, hd - tail), hd, lc, a * 0.75, wl)
		hd += gap




static func _comet(ci: CanvasItem, pts: PackedVector2Array, cum: PackedFloat32Array, d0: float, d1: float, lc: Color, a: float, wl: float) -> void :
	if d1 - d0 < 1.0:
		return
	ci.draw_polyline_colors(PackedVector2Array([_at(pts, cum, d0), _at(pts, cum, d1)]), PackedColorArray([Color(lc, 0.0), Color(lc, a)]), wl, true)



static func _at(pts: PackedVector2Array, cum: PackedFloat32Array, d: float) -> Vector2:
	var i: int = clampi(cum.bsearch(d, true), 1, pts.size() - 1)
	var a0: float = cum[i - 1]
	return pts[i - 1].lerp(pts[i], clampf((d - a0) / maxf(0.0001, cum[i] - a0), 0.0, 1.0))



static func head(ci: CanvasItem, tip: Vector2, dir: Vector2, col: Color, w: float, k: float = 1.0, a: float = 1.0) -> void :
	if dir == Vector2.ZERO:
		return
	var n: = Vector2( - dir.y, dir.x)
	var l: float = (5.0 + w * 2.2) * k
	var hw: float = (3.0 + w * 1.4) * k
	var o: float = 1.6 * k
	ci.draw_colored_polygon(PackedVector2Array([tip + dir * o * 1.4, tip - dir * (l + o) + n * (hw + o), tip - dir * (l + o) - n * (hw + o)]), Color(DARK, DARK.a * a))
	ci.draw_colored_polygon(PackedVector2Array([tip, tip - dir * l + n * hw, tip - dir * l - n * hw]), Color(col, col.a * a))
	ci.draw_colored_polygon(PackedVector2Array([tip - dir * l * 0.35, tip - dir * l + n * hw * 0.55, tip - dir * l * 0.8]), Color(col.lightened(0.45), 0.6 * a))



static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float, t: float, k: float = 1.0, opts: Dictionary = {}) -> void :
	var o: Dictionary = opts.duplicate()
	o["smooth"] = false
	draw(ci, PackedVector2Array([a, b]), col, w, t, k, o)




static func arc(ci: CanvasItem, pts: PackedVector2Array, ground: PackedVector2Array, hot: Color, t: float, red: bool) -> void :
	if pts.size() < 2:
		return
	if ground.size() >= 2:
		ci.draw_polyline(ground, Color(0, 0, 0, 0.28), 3.0, true)
		ci.draw_polyline(ground, Color(1, 1, 1, 0.22), 1.0, true)
	var cols: = PackedColorArray()
	var cold: Color = Color(hot.lerp(Color("f3e2b0"), 0.55), 0.75)
	for i in pts.size():
		var f: float = float(i) / float(pts.size() - 1)
		cols.append(cold.lerp(hot, f * f))
	ci.draw_polyline(pts, DARK, 5.5, true)
	ci.draw_polyline_colors(pts, cols, 3.0, true)
	ci.draw_polyline(pts, Color(1, 1, 1, 0.28), 1.0, true)
	if not red:
		var cum: PackedFloat32Array = lengths(pts)
		var L: float = cum[cum.size() - 1]
		var hd: float = fmod(t * 90.0, maxf(60.0, L * 0.6))
		while hd < L:
			_comet(ci, pts, cum, maxf(0.0, hd - 30.0), hd, Color(1, 0.95, 0.8), 0.7, 2.5)
			hd += maxf(60.0, L * 0.6)




static func reticle(ci: CanvasItem, p: Vector2, col: Color, t: float, r0: float = 9.0) -> void :
	var r: float = r0 + sin(t * 4.0) * 1.2
	ci.draw_arc(p, r, 0.0, TAU, 28, DARK, 4.0, true)
	ci.draw_arc(p, r, 0.0, TAU, 28, col, 2.0, true)
	for i in 4:
		var v: Vector2 = Vector2.RIGHT.rotated(float(i) * PI * 0.5 + PI * 0.25)
		ci.draw_line(p + v * (r - 3.0), p + v * (r + 5.0), DARK, 4.0)
		ci.draw_line(p + v * (r - 2.0), p + v * (r + 4.0), Color.WHITE, 2.0)
	ci.draw_circle(p, 2.5, DARK)
	ci.draw_circle(p, 1.5, col.lightened(0.4))




const TAP_PIX: Array = [[6, 0], [5, 1], [6, 1], [7, 1], [6, 2], [6, 7], [5, 8], [6, 8], [7, 8], [5, 9], [6, 9], [7, 9]]
static func tap_mark(ci: CanvasItem, at: Vector2, col: Color, age: float, dur: float = 0.65) -> void :
	if age < 0.0 or age > dur:
		return
	var f: float = age / dur
	var a: float = 1.0 if f < 0.55 else 1.0 - (f - 0.55) / 0.45
	var px: float = 4.0 if age < 0.09 else 3.0
	var org: Vector2 = (at - Vector2(6.5, 9.5) * px).round()
	var dk: = Color(0.05, 0.04, 0.03, 0.6 * a)
	var rects: Array[Rect2] = []
	for e: Array in TAP_PIX:
		rects.append(Rect2(org + Vector2(float(e[0]), float(e[1])) * px, Vector2(px, px)))

	var c0: Vector2 = org + Vector2(6.5, 14.0 - minf(f * 2.0, 1.0)) * px
	var r: float = 10.0 * px
	var arcs: Array = [[PI + 0.95, PI + 1.42], [TAU - 1.42, TAU - 0.95]]
	for ar: Array in arcs:
		ci.draw_arc(c0, r, float(ar[0]), float(ar[1]), 12, dk, px + 2.0, true)
	for rr: Rect2 in rects:
		ci.draw_rect(rr.grow(1.0), dk)
	for ar2: Array in arcs:
		ci.draw_arc(c0, r, float(ar2[0]), float(ar2[1]), 12, Color(col, a), px, true)
	for rr2: Rect2 in rects:
		ci.draw_rect(rr2, Color(col, a))
