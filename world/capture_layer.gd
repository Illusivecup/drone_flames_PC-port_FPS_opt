extends Node2D



















const PAD: int = 3
const BULGE: float = 0.35
const Q: float = 4.0
const ZONE_T: float = 4.0
const DIR_T: float = 0.5
const EASE: float = 0.35
const DARK: = Color("0b1430")









const STYLE: int = 5
var style: int = STYLE
const SHADE_W: float = 2.5

var gw: GameWorld
var _t: float = 0.0
var _had: bool = false
var _st: Dictionary = {}


static func make(world: GameWorld) -> Node2D:
	var l: Node2D = (load("res://world/capture_layer.gd") as GDScript).new()
	l.name = "Capture"
	l.set("gw", world)
	l.z_index = 7
	return l


func _process(delta: float) -> void :
	_t += delta
	if gw == null:
		return
	var any: bool = false
	for city: City in gw.cities:
		var s: Variant = _st.get(city.id)
		var want: float = clampf(city.capture, 0.0, 1.0) if city.cap_by != 0 else 0.0
		if s == null:
			if want <= 0.0:
				continue
			s = {"p": 0.0, "zone_t": -99.0, "dir_t": -99.0, "dir": Vector2.ZERO, "bdir": Vector2.ZERO, "by": city.cap_by, "own": city.country_id}
			_st[city.id] = s
		var d: Dictionary = s
		if int(d["own"]) != city.country_id:
			_st.erase(city.id)
			continue
		if city.cap_by != 0:
			d["by"] = city.cap_by
		d["p"] = move_toward(float(d["p"]), want, EASE * delta)
		if float(d["p"]) <= 0.0 and want <= 0.0:
			_st.erase(city.id)
			continue
		any = true
	if any or _had:
		queue_redraw()
	_had = any


func _shown(city: City, cpx: Vector2, by: int) -> bool:
	if gw.vision == null:
		return true
	return gw.vision.shows(city.country_id, cpx) or gw.vision.shows(by, cpx)


func _draw() -> void :
	if gw == null or gw.camera == null or _st.is_empty():
		return
	var z: float = maxf(0.05, gw.camera.zoom.x)
	for cid: int in _st:
		var city: City = gw.cities[cid] if cid >= 0 and cid < gw.cities.size() else null
		if city == null or city.id != cid:
			continue
		var d: Dictionary = _st[cid]
		var by: int = int(d["by"])
		var cpx: Vector2 = Vector2(city.center * GameWorld.CELL)
		var rpx: float = float((city.radius + PAD) * GameWorld.CELL)
		if not gw._on_screen(cpx, rpx * z + 20.0) or not _shown(city, cpx, by):
			continue
		_update(city, d, by)
		if not d.has("keys"):
			continue
		_paint(city, d, by, z)






func _update(city: City, d: Dictionary, by: int) -> void :
	var resort: bool = false
	if _t - float(d["zone_t"]) >= ZONE_T:
		d["zone_t"] = _t
		d["bdir"] = _border_dir(city, by)
		resort = _zone(city, d)
	if _t - float(d["dir_t"]) >= DIR_T:
		d["dir_t"] = _t
		var nd: Vector2 = _unit_dir(city, by)
		if nd == Vector2.ZERO:
			nd = d["bdir"]
		if nd == Vector2.ZERO:
			nd = Vector2.LEFT
		var od: Vector2 = d["dir"]
		if od == Vector2.ZERO:
			d["dir"] = nd
			resort = true
		else:

			var cur: Vector2 = d.get("sdir", od)
			var ang: float = clampf(cur.angle_to(nd), -0.25, 0.25)
			var nxt: Vector2 = cur.rotated(ang)
			d["sdir"] = nxt
			if absf(nxt.angle_to(od)) > 0.12:
				d["dir"] = nxt
				resort = true
	if resort and d.has("cells"):
		_sort(city, d)



func _zone(city: City, d: Dictionary) -> bool:
	var data: WorldData = gw.data
	var R: int = city.radius + PAD
	var c0: Vector2i = city.center
	var cells: = PackedInt32Array()
	var r2: int = R * R
	for y in range(maxi(0, c0.y - R), mini(data.h, c0.y + R + 1)):
		var row: int = y * data.w
		for x in range(maxi(0, c0.x - R), mini(data.w, c0.x + R + 1)):
			var dx: int = x - c0.x
			var dy: int = y - c0.y
			if dx * dx + dy * dy > r2:
				continue
			if data.owners[row + x] != city.country_id or Biome.is_water(data.biome[row + x]):
				continue
			cells.append(x)
			cells.append(y)
	if d.has("cells") and (d["cells"] as PackedInt32Array) == cells:
		return false
	d["cells"] = cells
	return true









func _sort(city: City, d: Dictionary) -> void :
	var cells: PackedInt32Array = d["cells"]
	var n: int = cells.size() / 2
	var R: float = float(city.radius + PAD)
	var dir: Vector2 = d["dir"]
	var per: = Vector2( - dir.y, dir.x)
	var c0: = Vector2(city.center)
	var bul: float = BULGE * R
	var kmin: float = - R - bul - 1.0
	var nb: int = int((2.0 * R + bul + 3.0) * Q) + 1
	var bk: = PackedInt32Array()
	bk.resize(n)
	var cnt: = PackedInt32Array()
	cnt.resize(nb + 1)
	for i in n:
		var p: = Vector2(float(cells[i * 2]) + 0.5, float(cells[i * 2 + 1]) + 0.5) - c0
		var u: float = p.dot(dir)
		var v: float = p.dot(per) / R
		var b: int = clampi(int((u - bul * v * v - kmin) * Q), 0, nb - 1)
		bk[i] = b
		cnt[b + 1] += 1
	for b in range(1, nb + 1):
		cnt[b] += cnt[b - 1]
	var order: = PackedInt32Array()
	order.resize(n)
	for i in n:
		var b2: int = bk[i]
		order[cnt[b2]] = i
		cnt[b2] += 1
	var side: int = int(R) * 2 + 1
	var g0: Vector2i = city.center - Vector2i(int(R), int(R))
	var rank: = PackedInt32Array()
	rank.resize(side * side)
	rank.fill(-1)
	var keys: = PackedFloat32Array()
	keys.resize(n)
	var sx: = PackedInt32Array()
	sx.resize(n)
	var sy: = PackedInt32Array()
	sy.resize(n)
	var wcnt: = PackedInt32Array()
	wcnt.resize(n + 1)
	var dcnt: = PackedInt32Array()
	dcnt.resize(n + 1)
	var wash: = PackedVector2Array()
	var dith: = PackedVector2Array()
	var C: float = float(GameWorld.CELL)
	var ph: float = float(city.id) * 1.7
	const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	for j in n:
		var i2: int = order[j]
		var x: int = cells[i2 * 2]
		var y: int = cells[i2 * 2 + 1]
		keys[j] = kmin + (float(bk[i2]) + 0.5) / Q
		sx[j] = x
		sy[j] = y
		rank[(y - g0.y) * side + (x - g0.x)] = j
		wcnt[j] = wash.size() / 2
		dcnt[j] = dith.size() / 2
		var a: = Vector2(float(x) * C, (float(y) + 0.5) * C)
		var q: = Vector2(float(x) + 0.5, float(y) + 0.5) - c0
		var ang: float = q.angle()
		var rim: float = R - 5.0 + 1.6 * sin(ang * 3.0 + ph) + 1.0 * sin(ang * 7.0 + ph * 2.3)
		var fade: float = clampf((q.length() - rim) / 4.0, 0.0, 1.0)
		var by: int = BAYER[(y & 3) * 4 + (x & 3)]
		if float(by) >= fade * 16.0:
			wash.append(a)
			wash.append(a + Vector2(C, 0.0))
		if (x + y) % 2 == 0 and float(by) >= fade * 12.0:
			dith.append(a)
			dith.append(a + Vector2(C, 0.0))
	wcnt[n] = wash.size() / 2
	dcnt[n] = dith.size() / 2


	var hat: = PackedVector2Array()
	var hcnt: = PackedInt32Array()
	hcnt.resize(n + 1)
	var l0: = PackedVector2Array()
	var l1: = PackedVector2Array()
	var l2: = PackedVector2Array()
	var l3: = PackedVector2Array()
	var lcnt: = PackedInt32Array()
	lcnt.resize(4 * (n + 1))
	var ol: = PackedVector2Array()
	var onr: = PackedVector2Array()
	var ocnt: = PackedInt32Array()
	ocnt.resize(n + 1)
	for j in n:
		var x: int = sx[j]
		var y: int = sy[j]
		hcnt[j] = hat.size() / 2
		ocnt[j] = ol.size() / 2
		var a: = Vector2(float(x) * C, (float(y) + 0.5) * C)
		if posmod(x - y, 4) == 0:
			hat.append(a)
			hat.append(a + Vector2(C, 0.0))
		var by2: int = BAYER[(y & 3) * 4 + (x & 3)]
		lcnt[j] = l0.size() / 2
		lcnt[(n + 1) + j] = l1.size() / 2
		lcnt[2 * (n + 1) + j] = l2.size() / 2
		lcnt[3 * (n + 1) + j] = l3.size() / 2
		var b2: = a + Vector2(C, 0.0)
		if by2 < 3:
			l0.append(a);l0.append(b2)
		if by2 < 7:
			l1.append(a);l1.append(b2)
		if by2 < 11:
			l2.append(a);l2.append(b2)
		if by2 < 15:
			l3.append(a);l3.append(b2)
		var lx: int = x - g0.x
		var ly: int = y - g0.y
		var cx: float = float(x) * C
		var cy: float = float(y) * C
		if lx + 1 >= side or rank[ly * side + lx + 1] < 0:
			ol.append(Vector2(cx + C, cy));ol.append(Vector2(cx + C, cy + C));onr.append(Vector2(-1, 0))
		if lx <= 0 or rank[ly * side + lx - 1] < 0:
			ol.append(Vector2(cx, cy));ol.append(Vector2(cx, cy + C));onr.append(Vector2(1, 0))
		if ly + 1 >= side or rank[(ly + 1) * side + lx] < 0:
			ol.append(Vector2(cx, cy + C));ol.append(Vector2(cx + C, cy + C));onr.append(Vector2(0, -1))
		if ly <= 0 or rank[(ly - 1) * side + lx] < 0:
			ol.append(Vector2(cx, cy));ol.append(Vector2(cx + C, cy));onr.append(Vector2(0, 1))
	hcnt[n] = hat.size() / 2
	ocnt[n] = ol.size() / 2
	lcnt[n] = l0.size() / 2
	lcnt[2 * n + 1] = l1.size() / 2
	lcnt[3 * n + 2] = l2.size() / 2
	lcnt[4 * n + 3] = l3.size() / 2
	d["hat"] = hat
	d["hcnt"] = hcnt
	d["lv"] = [l0, l1, l2, l3]
	d["lcnt"] = lcnt
	d["ol"] = ol
	d["onr"] = onr
	d["ocnt"] = ocnt
	d["keys"] = keys
	d["sx"] = sx
	d["sy"] = sy
	d["rank"] = rank
	d["side"] = side
	d["g0"] = g0
	d["wash"] = wash
	d["wcnt"] = wcnt
	d["dith"] = dith
	d["dcnt"] = dcnt
	_sort_d(city, d, kmin)
	_sort_e(city, d)
	d.erase("cache_k")
	d.erase("cache_k2")




func _sort_d(city: City, d: Dictionary, kmin: float) -> void :
	var keys: PackedFloat32Array = d["keys"]
	var sx: PackedInt32Array = d["sx"]
	var sy: PackedInt32Array = d["sy"]
	var n: int = keys.size()
	var nb: int = int((keys[n - 1] - kmin + 6.0) * Q) + 2 if n > 0 else 1
	var bk: = PackedInt32Array()
	bk.resize(n)
	var cnt: = PackedInt32Array()
	cnt.resize(nb + 1)
	for j in n:
		var hsh: int = (sx[j] * 73856093) ^ (sy[j] * 19349663) ^ (city.id * 83492791)
		var jit: float = (float(posmod(hsh, 1000)) / 1000.0 - 0.5) * 5.0
		var b: int = clampi(int((keys[j] + jit - kmin + 3.0) * Q), 0, nb - 1)
		bk[j] = b
		cnt[b + 1] += 1
	for b in range(1, nb + 1):
		cnt[b] += cnt[b - 1]
	var order: = PackedInt32Array()
	order.resize(n)
	for j in n:
		order[cnt[bk[j]]] = j
		cnt[bk[j]] += 1
	var C: float = float(GameWorld.CELL)
	var ea: = PackedVector2Array()
	var eb: = PackedVector2Array()
	var ec: = PackedInt32Array()
	ec.resize(2 * (n + 1))
	for r in n:
		var j: int = order[r]
		ec[r] = ea.size() / 2
		ec[n + 1 + r] = eb.size() / 2
		var a: = Vector2(float(sx[j]) * C, (float(sy[j]) + 0.5) * C)
		if (sx[j] + sy[j]) % 2 == 0:
			ea.append(a);ea.append(a + Vector2(C, 0.0))
		else:
			eb.append(a);eb.append(a + Vector2(C, 0.0))
	ec[n] = ea.size() / 2
	ec[2 * n + 1] = eb.size() / 2
	d["d_a"] = ea
	d["d_b"] = eb
	d["d_c"] = ec




func _sort_e(city: City, d: Dictionary) -> void :
	var keys: PackedFloat32Array = d["keys"]
	var sx: PackedInt32Array = d["sx"]
	var sy: PackedInt32Array = d["sy"]
	var n: int = keys.size()
	var acc: Dictionary = {}
	for j in n:
		var sk: = Vector2i(sx[j] >> 2, sy[j] >> 2)
		var e: Variant = acc.get(sk)
		if e == null:
			e = [0.0, 0, PackedInt32Array()]
			acc[sk] = e
		var ea: Array = e
		ea[0] = float(ea[0]) + keys[j]
		ea[1] = int(ea[1]) + 1
		var pr: PackedInt32Array = ea[2]
		pr.append(j)
		ea[2] = pr
	var secs: Array = []
	for sk2: Vector2i in acc:
		var e2: Array = acc[sk2]
		secs.append([float(e2[0]) / float(e2[1]), sk2, e2[2]])
	secs.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))



	var C: float = float(GameWorld.CELL)
	var cc: Vector2 = Vector2(city.center)
	var fill: = PackedVector2Array()
	var fill_l: = PackedVector2Array()
	var xs: = PackedVector2Array()
	var rects: = PackedVector2Array()
	var rect_all: = PackedVector2Array()
	var ns: int = secs.size()
	var fc: = PackedInt32Array()
	var flc: = PackedInt32Array()
	var xc: = PackedInt32Array()
	var rcn: = PackedInt32Array()
	var cum: = PackedInt32Array()
	fc.resize(ns + 1)
	flc.resize(ns + 1)
	xc.resize(ns + 1)
	rcn.resize(ns + 1)
	cum.resize(ns + 1)
	for i in ns:
		fc[i] = fill.size() / 2
		flc[i] = fill_l.size() / 2
		xc[i] = xs.size() / 2
		rcn[i] = rects.size() / 8
		var sk3: Vector2i = secs[i][1]
		var cr: PackedInt32Array = secs[i][2]
		cum[i + 1] = cum[i] + cr.size()
		var sc: Vector2 = Vector2(sk3 * 4) + Vector2(2.0, 2.0)
		var lab: bool = absf(sc.x - cc.x) < 11.0 and absf(sc.y - cc.y) < 5.0
		for j2 in cr:
			var a: = Vector2(float(sx[j2]) * C, (float(sy[j2]) + 0.5) * C)
			if lab:
				fill_l.append(a);fill_l.append(a + Vector2(C, 0.0))
			else:
				fill.append(a);fill.append(a + Vector2(C, 0.0))
		var o: = Vector2(sk3 * 4) * C
		var w: float = 4.0 * C
		var fr: = PackedVector2Array([o, o + Vector2(w, 0), o + Vector2(w, 0), o + Vector2(w, w), o + Vector2(w, w), o + Vector2(0, w), o + Vector2(0, w), o])
		rect_all.append_array(fr)
		if cr.size() >= 14 and not lab:
			rects.append_array(fr)
			if true:
				var m1: float = 0.75 * C
				xs.append(o + Vector2(m1, m1));xs.append(o + Vector2(w - m1, w - m1))
				xs.append(o + Vector2(w - m1, m1));xs.append(o + Vector2(m1, w - m1))
	fc[ns] = fill.size() / 2
	flc[ns] = fill_l.size() / 2
	xc[ns] = xs.size() / 2
	rcn[ns] = rects.size() / 8
	d["e_fill"] = fill
	d["e_fill_l"] = fill_l
	d["e_x"] = xs
	d["e_rect"] = rects
	d["e_rall"] = rect_all
	d["e_fc"] = fc
	d["e_flc"] = flc
	d["e_xc"] = xc
	d["e_rc"] = rcn
	d["e_cum"] = cum



func _border_dir(city: City, by: int) -> Vector2:
	var data: WorldData = gw.data
	var c0: Vector2i = city.center
	var acc: = Vector2.ZERO
	var found: int = -1
	for r in range(maxi(1, city.radius / 2), 96):
		for i in range( - r, r + 1):
			for s4 in 4:
				var qx: int = c0.x + (i if s4 < 2 else ( - r if s4 == 2 else r))
				var qy: int = c0.y + (( - r if s4 == 0 else r) if s4 < 2 else i)
				if qx < 0 or qy < 0 or qx >= data.w or qy >= data.h:
					continue
				if data.owners[qy * data.w + qx] == by:
					acc += Vector2(float(qx - c0.x), float(qy - c0.y)).normalized()
		if acc != Vector2.ZERO:
			if found < 0:
				found = r
			if r >= found + 3:
				break
	if acc.length() < 0.01:
		var ac: Country = gw.country_by_id(by)
		if ac != null and ac.capital_id >= 0 and ac.capital_id < gw.cities.size():
			var to: Vector2 = Vector2(gw.cities[ac.capital_id].center - c0)
			return to.normalized() if to.length() > 0.5 else Vector2.ZERO
		return Vector2.ZERO
	return acc.normalized()



func _unit_dir(city: City, by: int) -> Vector2:
	if gw.army == null:
		return Vector2.ZERO
	var cpx: Vector2 = Vector2(city.center * GameWorld.CELL)
	var rr: float = float((city.radius + PAD) * GameWorld.CELL) + 24.0
	var acc: = Vector2.ZERO
	var n: int = 0
	for u: Unit in gw.army.units:
		if u.country_id != by or not u.alive():
			continue
		var o: Vector2 = u.pos - cpx
		if o.length_squared() > rr * rr:
			continue
		acc += o
		n += 1
	if n == 0:
		return Vector2.ZERO
	acc /= float(n)
	if acc.length() < rr * 0.3:
		return Vector2.ZERO
	return acc.normalized()




func _paint(city: City, d: Dictionary, by: int, z: float) -> void :
	var keys: PackedFloat32Array = d["keys"]
	var n: int = keys.size()
	if n == 0:
		return
	var p: float = clampf(float(d["p"]), 0.0, 1.0)
	var kc: int = clampi(roundi(p * float(n)), 0, n)
	if kc == 0:
		return
	var ac: Country = gw.country_by_id(by)
	var dc: Country = gw.country_by_id(city.country_id)
	var acol: Color = ac.color if ac != null else Palette.c("amber")
	var dcol: Color = dc.color if dc != null else Palette.c("concrete")
	var war: Color = Palette.c("fire_red")
	var pulse: float = 0.5 + 0.5 * sin(_t * 4.0)
	var C: float = float(GameWorld.CELL)

	var step: int = maxi(1, n / 150)
	var kq: int = clampi(((kc + step - 1) / step) * step, 1, n)
	if int(d.get("cache_k", -1)) != kq:
		d["cache_k"] = kq
		var f: int = n - kq
		var th: float = keys[f]
		var wcnt: PackedInt32Array = d["wcnt"]
		var dcnt: PackedInt32Array = d["dcnt"]
		d["c_wash"] = (d["wash"] as PackedVector2Array).slice(wcnt[f] * 2)
		var b1: int = keys.bsearch(th + 3.0, true)
		d["c_band"] = (d["dith"] as PackedVector2Array).slice(dcnt[f] * 2, dcnt[b1] * 2)
		d["c_edge"] = _edges(d, f, keys.bsearch(th + 2.0, true)) if kq < n else [PackedVector2Array(), PackedVector2Array()]
		d["c_full"] = kq >= n

		var hc: PackedInt32Array = d["hcnt"]
		d["c_hat"] = (d["hat"] as PackedVector2Array).slice(hc[f] * 2, hc[keys.bsearch(th + 8.0, true)] * 2)

		var sh: Array = []
		var lc: PackedInt32Array = d["lcnt"]
		for li in 4:
			var o: int = (3 - li) * (n + 1)
			var r0: int = keys.bsearch(th + SHADE_W * float(li), true)
			var r1: int = keys.bsearch(th + SHADE_W * float(li + 1), true)
			sh.append(((d["lv"] as Array)[3 - li] as PackedVector2Array).slice(lc[o + r0] * 2, lc[o + r1] * 2))
		d["c_shade"] = sh

		var oc: PackedInt32Array = d["ocnt"]
		d["c_ol_t"] = (d["ol"] as PackedVector2Array).slice(oc[f] * 2)
		d["c_on_t"] = (d["onr"] as PackedVector2Array).slice(oc[f])
		d["c_ol_u"] = (d["ol"] as PackedVector2Array).slice(0, oc[f] * 2)
	var k: float = 1.0 / z
	var u: float = maxf(k, 0.5)
	if style >= 4:
		_paint2(d, n, kq, acol, dcol, war, pulse, u, z)
		return
	if style == 1:
		var hat: PackedVector2Array = d["c_hat"]
		if hat.size() >= 2:
			draw_multiline(hat, Color(acol, 0.75), C)
		_front(d, acol, dcol, war, pulse, u, z, 1.0)
		return
	if style == 2:
		var tone: Color = Palette.c("smoke_dark").lerp(acol, 0.45)
		for li in 4:
			var arr: PackedVector2Array = (d["c_shade"] as Array)[li]
			if arr.size() >= 2:
				draw_multiline(arr, Color(tone, 0.6), C)
		_front(d, acol, dcol, war, pulse, u, z, 0.5)
		return
	if style == 3:
		_outline(d, acol, dcol, war, pulse, u, z)
		return

	var ash: Color = Palette.c("smoke_dark").lerp(acol, 0.55)
	var wash: PackedVector2Array = d["c_wash"]
	if wash.size() >= 2:
		draw_multiline(wash, Color(ash, 0.55), C)

	var band: PackedVector2Array = d["c_band"]
	if band.size() >= 2:
		draw_multiline(band, Color(acol, 0.6), C)


	_front(d, acol, dcol, war, pulse, u, z, 1.0)


func _front(d: Dictionary, acol: Color, dcol: Color, war: Color, pulse: float, u: float, z: float, wk: float) -> void :
	var e: Array = d["c_edge"]
	var pts: PackedVector2Array = e[0]
	if pts.size() < 2 or bool(d["c_full"]):
		return
	var nrm: PackedVector2Array = e[1]
	var cw: float = maxf(u, (3.0 if z < 0.7 else 2.0) * u * wk)
	var off_a: = PackedVector2Array()
	var off_d: = PackedVector2Array()
	off_a.resize(pts.size())
	off_d.resize(pts.size())
	for i in pts.size():
		var nv: Vector2 = nrm[i / 2]
		off_a[i] = pts[i] + nv * (u + cw * 0.5)
		off_d[i] = pts[i] - nv * (u + cw * 0.5)
	draw_multiline(off_d, Color(dcol.lerp(Color.WHITE, 0.15), 0.9), cw)
	draw_multiline(off_a, acol.lerp(war, 0.15 + 0.25 * pulse), cw)
	draw_multiline(pts, DARK, maxf(u, 2.0 * u * wk))




func _outline(d: Dictionary, acol: Color, dcol: Color, war: Color, pulse: float, u: float, z: float) -> void :
	var un: PackedVector2Array = d["c_ol_u"]
	if un.size() >= 2:
		draw_multiline(un, Color(dcol.lerp(Color.WHITE, 0.2), 0.75), u * (2.0 if z < 0.7 else 1.0))
	var tk: PackedVector2Array = d["c_ol_t"]
	var tn: PackedVector2Array = d["c_on_t"]
	if tk.size() >= 2:
		var cw: float = 4.0 * u
		var o_in: = PackedVector2Array()
		o_in.resize(tk.size())
		for i in tk.size():
			o_in[i] = tk[i] + tn[i / 2] * cw * 0.5
		draw_multiline(tk, DARK, 2.0 * u)
		draw_multiline(o_in, acol.lerp(war, 0.15 + 0.25 * pulse), cw)
	var e: Array = d["c_edge"]
	var pts: PackedVector2Array = e[0]
	if pts.size() >= 4 and not bool(d["c_full"]):
		var dots: = PackedVector2Array()
		for i in range(0, pts.size() - 1, 4):
			dots.append(pts[i])
			dots.append(pts[i + 1])
		draw_multiline(dots, DARK, 2.0 * u)






func _edges(d: Dictionary, f: int, hi: int) -> Array:
	var rank: PackedInt32Array = d["rank"]
	var side: int = d["side"]
	var g0: Vector2i = d["g0"]
	var sx: PackedInt32Array = d["sx"]
	var sy: PackedInt32Array = d["sy"]
	var pts: = PackedVector2Array()
	var nrm: = PackedVector2Array()
	var C: float = float(GameWorld.CELL)
	var h: float = 0.5
	for j in range(f, hi):
		var x: int = sx[j]
		var y: int = sy[j]
		var lx: int = x - g0.x
		var ly: int = y - g0.y
		var cx: float = float(x) * C
		var cy: float = float(y) * C
		var r: int = rank[ly * side + lx + 1] if lx + 1 < side else -1
		if r >= 0 and r < f:
			pts.append(Vector2(cx + C, cy - h));pts.append(Vector2(cx + C, cy + C + h));nrm.append(Vector2(-1, 0))
		r = rank[ly * side + lx - 1] if lx > 0 else -1
		if r >= 0 and r < f:
			pts.append(Vector2(cx, cy - h));pts.append(Vector2(cx, cy + C + h));nrm.append(Vector2(1, 0))
		r = rank[(ly + 1) * side + lx] if ly + 1 < side else -1
		if r >= 0 and r < f:
			pts.append(Vector2(cx - h, cy + C));pts.append(Vector2(cx + C + h, cy + C));nrm.append(Vector2(0, -1))
		r = rank[(ly - 1) * side + lx] if ly > 0 else -1
		if r >= 0 and r < f:
			pts.append(Vector2(cx - h, cy));pts.append(Vector2(cx + C + h, cy));nrm.append(Vector2(0, 1))
	return [pts, nrm]



func _paint2(d: Dictionary, n: int, kq: int, acol: Color, dcol: Color, war: Color, pulse: float, u: float, z: float) -> void :
	var C: float = float(GameWorld.CELL)
	var tone: Color = Palette.c("smoke_dark").lerp(acol, 0.5)
	var f: int = n - kq
	if int(d.get("cache_k2", -1)) != kq * 8 + style:
		d["cache_k2"] = kq * 8 + style
		if style == 4:
			var ec: PackedInt32Array = d["d_c"]
			var fl: int = mini(n, f + maxi(4, n / 30))
			d["c2_a"] = (d["d_a"] as PackedVector2Array).slice(ec[f] * 2)
			d["c2_b"] = (d["d_b"] as PackedVector2Array).slice(ec[n + 1 + f] * 2)
			d["c2_fa"] = (d["d_a"] as PackedVector2Array).slice(ec[f] * 2, ec[fl] * 2)
			d["c2_fb"] = (d["d_b"] as PackedVector2Array).slice(ec[n + 1 + f] * 2, ec[n + 1 + fl] * 2)
		elif style == 5:
			var cum: PackedInt32Array = d["e_cum"]
			var ns: int = cum.size() - 1

			var m: int = 0
			while m < ns and cum[ns] - cum[ns - m - 1] <= kq:
				m += 1
			var s0: int = ns - m
			var fc: PackedInt32Array = d["e_fc"]
			var flc: PackedInt32Array = d["e_flc"]
			d["c2_fill"] = (d["e_fill"] as PackedVector2Array).slice(fc[s0] * 2)
			d["c2_fill_l"] = (d["e_fill_l"] as PackedVector2Array).slice(flc[s0] * 2)
			d["c2_x"] = (d["e_x"] as PackedVector2Array).slice((d["e_xc"] as PackedInt32Array)[s0] * 2)
			d["c2_rect"] = (d["e_rect"] as PackedVector2Array).slice((d["e_rc"] as PackedInt32Array)[s0] * 8)
			d["c2_cont"] = (d["e_rall"] as PackedVector2Array).slice((s0 - 1) * 8, s0 * 8) if s0 > 0 else PackedVector2Array()
			var cs: = PackedVector2Array()
			if s0 > 0:
				cs = (d["e_fill"] as PackedVector2Array).slice(fc[s0 - 1] * 2, fc[s0] * 2)
				cs.append_array((d["e_fill_l"] as PackedVector2Array).slice(flc[s0 - 1] * 2, flc[s0] * 2))
			d["c2_conth"] = cs
		else:

			var keys: PackedFloat32Array = d["keys"]
			var th: float = keys[f]
			var lc: PackedInt32Array = d["lcnt"]
			var sh: Array = []
			for li in 4:
				var o: int = li * (n + 1)
				var r0: int = keys.bsearch(th + 3.0 * float(li), true) if li > 0 else f
				var r1: int = keys.bsearch(th + 3.0 * float(li + 1), true) if li < 3 else n
				sh.append(((d["lv"] as Array)[li] as PackedVector2Array).slice(lc[o + r0] * 2, lc[o + r1] * 2))
			d["c2_sh"] = sh
	if style == 4:
		draw_multiline(d["c2_a"], Color(tone, 0.7), C)
		draw_multiline(d["c2_b"], Color(tone, 0.4), C)
		var crest: Color = acol.lightened(0.55)
		draw_multiline(d["c2_fa"], Color(crest, 0.65 + 0.3 * pulse), C)
		draw_multiline(d["c2_fb"], Color(crest, 0.35 + 0.2 * pulse), C)
		return
	if style == 5:
		var tint: Color = acol.lerp(Palette.c("smoke"), 0.25)
		var fl: PackedVector2Array = d["c2_fill"]
		if fl.size() >= 2:
			draw_multiline(fl, Color(tint, 0.3), C)
		var fll: PackedVector2Array = d["c2_fill_l"]
		if fll.size() >= 2:
			draw_multiline(fll, Color(tint, 0.07), C)
		var xs: PackedVector2Array = d["c2_x"]
		if xs.size() >= 2:
			draw_multiline(xs, Color(acol.lightened(0.55), 0.6), u)
		var rc: PackedVector2Array = d["c2_rect"]
		if rc.size() >= 2:
			draw_multiline(rc, Color(acol.lightened(0.3), 0.45), u)
		var ct: PackedVector2Array = d["c2_conth"]
		if ct.size() >= 2:
			draw_multiline(ct, Color(acol, 0.12 + 0.2 * pulse), C)
		var cr: PackedVector2Array = d["c2_cont"]
		if cr.size() >= 2:
			var far: bool = z < 0.7
			draw_multiline(cr, Color(DARK, 0.85), (4.0 if far else 3.0) * u)
			draw_multiline(cr, acol.lightened(0.25).lerp(war, 0.3 * pulse), (2.5 if far else 1.5) * u)
		return

	var sh2: Array = d["c2_sh"]
	for li in 4:
		var arr: PackedVector2Array = sh2[li]
		if arr.size() >= 2:
			draw_multiline(arr, Color(tone, 0.72), C)
	var e: Array = d["c_edge"]
	var pts: PackedVector2Array = e[0]
	if pts.size() >= 2 and not bool(d["c_full"]):
		draw_multiline(pts, Color(DARK, 0.9), 1.5 * u)

		var nrm: PackedVector2Array = e[1]
		var ns2: int = pts.size() / 2
		for i in mini(40, ns2):
			var si: int = randi() % ns2
			var q: Vector2 = pts[si * 2].lerp(pts[si * 2 + 1], randf()) + nrm[si] * randf() * 3.0 * C
			var col: Color = Palette.c("fire_orange") if randf() < 0.5 else (Palette.c("fire_yellow") if randf() < 0.5 else Palette.c("smoke"))
			draw_rect(Rect2(q.snapped(Vector2(1, 1)), Vector2(2.0, 2.0) * maxf(1.0, u)), Color(col, 0.6 + 0.4 * randf()))
