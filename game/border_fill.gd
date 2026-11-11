extends RefCounted
















const BG: GDScript = preload("res://game/border_gap.gd")
const R: int = 36
const DEEP: int = 9
const MARGIN: int = 5
const POCKET: int = 6000
const REACH_EXT: int = 16
const INF: int = 1 << 28
const TILE: int = 64
const BAY_R: int = 6
const BAY_MOUTH: int = 20
const STRAIT: int = 24
const MID_FILL: int = 6
const SEAL_CELLS: int = 600





static func scan(own: PackedByteArray, bio: PackedByteArray, w: int, h: int, o: int, cities: Array, bn: PackedByteArray = PackedByteArray(), lakes: Array = [], war: PackedInt32Array = PackedInt32Array()) -> Array:
	if own.find(o, 0) < 0:
		return []


	var tw: int = (w + TILE - 1) / TILE
	var th: int = (h + TILE - 1) / TILE
	var tm: = PackedByteArray()
	tm.resize(tw * th)
	var ex: = PackedInt32Array()
	ex.resize(4 * tw * th)
	var a: int = own.find(o, 0)
	while a >= 0:
		var y: int = a / w
		var tx: int = (a - y * w) / TILE
		var t: int = (y / TILE) * tw + tx
		var end: int = mini((y + 1) * w, y * w + (tx + 1) * TILE)
		var xl: int = own.rfind(o, end - 1) - y * w
		if tm[t] == 0:
			tm[t] = 1
			ex[4 * t] = a - y * w
			ex[4 * t + 1] = y
			ex[4 * t + 2] = xl
			ex[4 * t + 3] = y
		else:
			ex[4 * t] = mini(ex[4 * t], a - y * w)
			ex[4 * t + 2] = maxi(ex[4 * t + 2], xl)
			ex[4 * t + 3] = y
		a = own.find(o, end)
	var tg: = PackedByteArray()
	tg.resize(tw * th)
	for ty in th:
		for tx2 in tw:
			if tm[ty * tw + tx2] == 0:
				continue
			for dy in range(maxi(0, ty - 1), mini(th, ty + 2)):
				for dx in range(maxi(0, tx2 - 1), mini(tw, tx2 + 2)):
					tg[dy * tw + dx] = 1
	var parts: Array = []
	var seen: = PackedByteArray()
	seen.resize(tw * th)
	for t0 in tw * th:
		if tg[t0] == 0 or seen[t0] != 0:
			continue
		var q: = PackedInt32Array([t0])
		seen[t0] = 1
		var hd: int = 0
		var bx0: int = w
		var by0: int = h
		var bx1: int = -1
		var by1: int = -1
		while hd < q.size():
			var t2: int = q[hd]
			hd += 1
			var cx: int = t2 % tw
			var cy: int = t2 / tw
			if tm[t2] != 0:
				bx0 = mini(bx0, ex[4 * t2])
				by0 = mini(by0, ex[4 * t2 + 1])
				bx1 = maxi(bx1, ex[4 * t2 + 2])
				by1 = maxi(by1, ex[4 * t2 + 3])
			for dy2 in range(maxi(0, cy - 1), mini(th, cy + 2)):
				for dx2 in range(maxi(0, cx - 1), mini(tw, cx + 2)):
					var n: int = dy2 * tw + dx2
					if tg[n] != 0 and seen[n] == 0:
						seen[n] = 1
						q.append(n)
		var mg: int = 2 * R + 8
		var r: Array = _box(own, bio, w, h, o, cities, bn, lakes, war, maxi(0, bx0 - mg), maxi(0, by0 - mg), mini(w - 1, bx1 + mg), mini(h - 1, by1 + mg))
		if not r.is_empty():
			parts.append(r)
	if parts.size() <= 1:
		return [] if parts.is_empty() else parts[0]

	var cells: = PackedInt32Array()
	var starts: = PackedInt32Array()
	var tos: = PackedInt32Array()
	var k: int = 0
	var more: bool = true
	while more:
		more = false
		starts.append(cells.size())
		for pr: Array in parts:
			var pc: PackedInt32Array = pr[0]
			var ps: PackedInt32Array = pr[1]
			var pt: PackedInt32Array = pr[2]
			if k < ps.size():
				more = true
				var e: int = ps[k + 1] if k + 1 < ps.size() else pc.size()
				cells.append_array(pc.slice(ps[k], e))
				tos.append_array(pt.slice(ps[k], e))
		k += 1
	starts.resize(starts.size() - 1)
	return [cells, starts, tos]



static func _box(own: PackedByteArray, bio: PackedByteArray, w: int, h: int, o: int, cities: Array, bn: PackedByteArray, lakes: Array, war: PackedInt32Array, x0: int, y0: int, x1: int, y1: int) -> Array:
	x0 &= ~ 1
	y0 &= ~ 1
	var bW: int = (x1 - x0 + 1) / 2
	var bH: int = (y1 - y0 + 1) / 2
	if bW < 4 or bH < 4:
		return []
	var nb: int = bW * bH

	var dO: = PackedInt32Array()
	var dX: = PackedInt32Array()
	var dB: = PackedInt32Array()
	var dS: = PackedInt32Array()
	dS.resize(nb)
	var lX: = PackedInt32Array()
	lX.resize(nb)
	dO.resize(nb)
	dX.resize(nb)
	dB.resize(nb)
	var fr: = PackedByteArray()
	fr.resize(nb)
	var ocean: int = Biome.OCEAN
	for by in bH:
		var g0: int = (y0 + 2 * by) * w + x0
		var b0: int = by * bW
		for bx in bW:
			var g: int = g0 + 2 * bx
			var k: int = b0 + bx
			var o1: int = own[g]
			var o2: int = own[g + 1]
			var o3: int = own[g + w]
			var o4: int = own[g + w + 1]
			if o1 == 0 and o2 == 0 and o3 == 0 and o4 == 0:

				dO[k] = INF
				dX[k] = INF
				var s1: bool = bio[g] <= ocean
				var s2: bool = bio[g + 1] <= ocean
				var s3: bool = bio[g + w] <= ocean
				var s4: bool = bio[g + w + 1] <= ocean
				dS[k] = 0 if (s1 or s2 or s3 or s4) else INF
				if s1 and s2 and s3 and s4:
					dB[k] = 0
				else:
					dB[k] = INF
					fr[k] = 1
				continue
			dO[k] = 0 if (o1 == o or o2 == o or o3 == o or o4 == o) else INF
			dX[k] = 0 if ((o1 != 0 and o1 != o) or (o2 != 0 and o2 != o) or (o3 != 0 and o3 != o) or (o4 != 0 and o4 != o)) else INF
			lX[k] = o1 if (o1 != 0 and o1 != o) else (o2 if (o2 != 0 and o2 != o) else (o3 if (o3 != 0 and o3 != o) else o4))
			dS[k] = 0 if (bio[g] <= ocean or bio[g + 1] <= ocean or bio[g + w] <= ocean or bio[g + w + 1] <= ocean) else INF
			var f1: bool = o1 == 0 and bio[g] > ocean
			var f2: bool = o2 == 0 and bio[g + 1] > ocean
			var f3: bool = o3 == 0 and bio[g + w] > ocean
			var f4: bool = o4 == 0 and bio[g + w + 1] > ocean
			if f1 or f2 or f3 or f4:
				dB[k] = INF
				fr[k] = 1
			else:
				dB[k] = 0
	_dt(dO, bW, bH)
	_dtl(dX, lX, bW, bH)
	_dt(dB, bW, bH)
	_dt(dS, bW, bH)

	var rb: int = 3 * R / 2
	var eB: = PackedInt32Array()
	eB.resize(nb)
	for k2 in nb:
		eB[k2] = 0 if dB[k2] > rb else INF
	_dt(eB, bW, bH)

	var mark: = PackedByteArray()
	mark.resize(nb)
	var q: = PackedInt32Array()
	for bx2 in bW:
		for k3: int in [bx2, (bH - 1) * bW + bx2]:
			if fr[k3] != 0 and mark[k3] == 0:
				mark[k3] = 1
				q.append(k3)
	for by2 in range(1, bH - 1):
		for k4: int in [by2 * bW, by2 * bW + bW - 1]:
			if fr[k4] != 0 and mark[k4] == 0:
				mark[k4] = 1
				q.append(k4)
	_flood4(q, mark, fr, bW, bH, 1)
	for k5 in nb:
		if fr[k5] == 0 or mark[k5] != 0:
			continue
		var comp: = PackedInt32Array([k5])
		mark[k5] = 2
		_flood4(comp, mark, fr, bW, bH, 2)
		if comp.size() * 4 > POCKET:
			for k6: int in comp:
				mark[k6] = 3




	var rs: int = 3 * BAY_R
	var eS: = PackedInt32Array()
	eS.resize(nb)
	for k9 in nb:
		eS[k9] = 0 if dO[k9] > rs else INF
	_dt(eS, bW, bH)
	for k10 in nb:
		if mark[k10] != 1 or dO[k10] == 0 or eS[k10] <= rs:
			continue
		var bq: = PackedInt32Array([k10])
		mark[k10] = 5
		var hb: int = 0
		var e_o: int = 0
		var e_m: int = 0
		var e_x: int = 0
		var e_s: int = 0
		while hb < bq.size():
			var kb: int = bq[hb]
			hb += 1
			var xb: int = kb % bW
			for nk: int in [kb - 1 if xb > 0 else -1, kb + 1 if xb < bW - 1 else -1, kb - bW, kb + bW]:
				if nk < 0 or nk >= nb:
					e_m += 1
				elif mark[nk] == 5:
					pass
				elif dO[nk] == 0:
					e_o += 1
				elif mark[nk] == 1 and eS[nk] > rs:
					mark[nk] = 5
					bq.append(nk)
				elif fr[nk] != 0:
					e_m += 1
				elif dX[nk] == 0:
					e_x += 1
				else:
					e_s += 1
		var bay: bool = e_m * 100 <= (e_o + e_m + e_x + e_s) * BAY_MOUTH and e_o >= e_x
		for kb2: int in bq:
			mark[kb2] = 4 if bay else 6


	var r2: int = 3 * STRAIT / 4
	var eA: = PackedInt32Array()
	eA.resize(nb)
	for k11 in nb:
		eA[k11] = 0 if mini(dO[k11], dX[k11]) > r2 else INF
	_dt(eA, bW, bH)

	var my: Array = []
	var cs: Array = []
	for e: PackedInt32Array in cities:
		var lim: int = e[2] + BG.GAP + 2
		if e[3] == o:
			my.append(PackedInt32Array([e[0], e[1], e[4] * 13 / 10 + REACH_EXT]))
			if e[0] + lim + 200 >= x0 and e[0] - lim - 200 <= x1 and e[1] + lim + 200 >= y0 and e[1] - lim - 200 <= y1:
				cs.append(e)
		elif e[0] + lim >= x0 and e[0] - lim <= x1 and e[1] + lim >= y0 and e[1] - lim <= y1:
			cs.append(e)

	var thr: int = 16 * (rb + MARGIN)
	var near: int = 16 * (3 * R / 2 + 3)
	var other: int = 16 * (3 * R / 2 + 9)
	var sea_near: int = 16 * 3 * 7
	var deep: int = 16 * DEEP
	var gap: float = float(BG.GAP)
	var cw: int = 2 * bW
	var ch: int = 2 * bH
	var cand: = PackedByteArray()
	cand.resize(cw * ch)
	var cf: = PackedByteArray()
	cf.resize(cw * ch)
	var fl: = PackedInt32Array()
	var hbn: bool = bn.size() == w * h
	for by3 in range(1, bH - 1):
		for bx3 in range(1, bW - 1):
			var k7: int = by3 * bW + bx3
			if fr[k7] == 0:
				continue
			var pocket: bool = mark[k7] == 2 or mark[k7] == 4
			if not pocket and (dO[k7] > 3 * R / 2 + 6 or eB[k7] * 16 + 16 * 4 <= thr):
				continue
			for sub in 4:
				var sx: int = sub & 1
				var sy: int = sub >> 1
				var cx: int = x0 + 2 * bx3 + sx
				var cy: int = y0 + 2 * by3 + sy
				var gi2: int = cy * w + cx
				if own[gi2] != 0 or bio[gi2] <= ocean:
					continue
				var kh: int = k7 + (1 if sx == 1 else -1)
				var kv: int = k7 + (bW if sy == 1 else - bW)
				var kd: int = kv + (1 if sx == 1 else -1)
				var vo: int = 9 * dO[k7] + 3 * dO[kh] + 3 * dO[kv] + dO[kd]
				var vx: int = 9 * dX[k7] + 3 * dX[kh] + 3 * dX[kv] + dX[kd]
				var sh: int = 0
				if hbn and vx < INF:





					sh = 24 * dn(bn, w, h, cx, cy, MID_FILL)
					if o > lX[k7]:
						sh = - sh
				if vo - vx > sh:



					var f: int = lX[k7]
					if f > 0 and vo <= other and vx <= near and not war.has(f) and (bio[gi2] >= Biome.RIVER or _lake(lakes, cx, cy) or (vo + vx <= 24 * STRAIT and eA[k7] > r2)):
						if 9 * eB[k7] + 3 * eB[kh] + 3 * eB[kv] + eB[kd] > thr and not _near_foe(cs, f, cx, cy):
							var lf: int = (2 * by3 + sy) * cw + 2 * bx3 + sx
							cf[lf] = f
							fl.append(lf)
					continue
				if bio[gi2] < Biome.RIVER and not pocket and not (vx < INF and vo + vx <= 24 * STRAIT and eA[k7] > r2) and not _lake(lakes, cx, cy):
					continue
				if not pocket:
					if vo > near:
						continue
					var ebi: int = 9 * eB[k7] + 3 * eB[kh] + 3 * eB[kv] + eB[kd]
					if ebi <= thr:
						continue




					var nbr: bool = vx <= other
					if ebi <= thr + deep and not nbr:
						if 9 * dS[k7] + 3 * dS[kh] + 3 * dS[kv] + dS[kd] > sea_near:
							continue
						if bio[gi2] < Biome.RIVER:
							continue
					var ok: bool = nbr
					if not ok:
						for t: PackedInt32Array in my:

							var rr: int = t[2] + (dn(bn, w, h, cx, cy, 10) if hbn else 0)
							if (cx - t[0]) * (cx - t[0]) + (cy - t[1]) * (cy - t[1]) <= rr * rr:
								ok = true
								break
					if not ok:
						continue

				var own_e: float = 1000000000.0
				var foe_e: float = 1000000000.0
				for c: PackedInt32Array in cs:
					var lim2: int = c[2] + BG.GAP + 2
					if c[3] != o and maxi(absi(cx - c[0]), absi(cy - c[1])) > lim2:
						continue
					var dx: float = float(cx - c[0])
					var dy: float = float(cy - c[1])
					var ed: float = sqrt(dx * dx + dy * dy) - float(c[2])
					if c[3] == o:
						own_e = minf(own_e, ed)
					else:
						foe_e = minf(foe_e, ed)
				if foe_e < gap and foe_e < own_e:
					continue
				cand[(2 * by3 + sy) * cw + 2 * bx3 + sx] = 1

	var cells: = PackedInt32Array()
	var starts: = PackedInt32Array()
	var cur: = PackedInt32Array()
	var dirs: PackedInt32Array = PackedInt32Array([-1, 1, - cw, cw, - cw - 1, - cw + 1, cw - 1, cw + 1])
	var gdirs: PackedInt32Array = PackedInt32Array([-1, 1, - w, w, - w - 1, - w + 1, w - 1, w + 1])
	for lc in cand.size():
		if cand[lc] == 0:
			continue
		var gi3: int = (y0 + lc / cw) * w + x0 + lc % cw
		for k8 in 8:
			if own[gi3 + gdirs[k8]] == o:
				cand[lc] = 2
				cur.append(lc)
				break
	while not cur.is_empty():
		starts.append(cells.size())
		var nxt: = PackedInt32Array()
		for lc2: int in cur:
			cells.append((y0 + lc2 / cw) * w + x0 + lc2 % cw)
			for d2: int in dirs:
				var nb2: int = lc2 + d2
				if cand[nb2] == 1:
					cand[nb2] = 2
					nxt.append(nb2)
		cur = nxt
	if not cells.is_empty():
		var seal: PackedInt32Array = _seal(own, bio, w, o, cand, cw, ch, x0, y0, cells)
		if not seal.is_empty():
			starts.append(cells.size())
			cells.append_array(seal)
	var tos: = PackedInt32Array()
	tos.resize(cells.size())
	tos.fill(o)
	if not fl.is_empty():

		var fcur: = PackedInt32Array()
		for lc4: int in fl:
			if cand[lc4] != 0:
				continue
			var gi4: int = (y0 + lc4 / cw) * w + x0 + lc4 % cw
			for k8b in 8:
				if own[gi4 + gdirs[k8b]] == cf[lc4]:
					cand[lc4] = 7
					fcur.append(lc4)
					break
		var fcells: = PackedInt32Array()
		var fst: = PackedInt32Array()
		var ftos: = PackedInt32Array()
		while not fcur.is_empty():
			fst.append(fcells.size())
			var fnx: = PackedInt32Array()
			for lc5: int in fcur:
				fcells.append((y0 + lc5 / cw) * w + x0 + lc5 % cw)
				ftos.append(cf[lc5])
				for d3: int in dirs:
					var n5: int = lc5 + d3
					if cand[n5] == 0 and cf[n5] == cf[lc5]:
						cand[n5] = 7
						fnx.append(n5)
			fcur = fnx
		if not fcells.is_empty():
			var mc: = PackedInt32Array()
			var ms: = PackedInt32Array()
			var mt: = PackedInt32Array()
			for rk in maxi(starts.size(), fst.size()):
				ms.append(mc.size())
				if rk < starts.size():
					var e1: int = starts[rk + 1] if rk + 1 < starts.size() else cells.size()
					mc.append_array(cells.slice(starts[rk], e1))
					mt.append_array(tos.slice(starts[rk], e1))
				if rk < fst.size():
					var e2: int = fst[rk + 1] if rk + 1 < fst.size() else fcells.size()
					mc.append_array(fcells.slice(fst[rk], e2))
					mt.append_array(ftos.slice(fst[rk], e2))
			cells = mc
			starts = ms
			tos = mt
	return [] if cells.is_empty() else [cells, starts, tos]





static func _seal(own: PackedByteArray, bio: PackedByteArray, w: int, o: int, cand: PackedByteArray, cw: int, ch: int, x0: int, y0: int, cells: PackedInt32Array) -> PackedInt32Array:
	var out: = PackedInt32Array()
	var ocean: int = Biome.OCEAN
	var lim: int = cw * (ch - 1)
	for g: int in cells:
		var lc: int = (g / w - y0) * cw + g % w - x0
		for d: int in [-1, 1, - cw, cw]:
			var s0: int = lc + d
			if s0 < cw or s0 >= lim or cand[s0] >= 2 or own[(y0 + s0 / cw) * w + x0 + s0 % cw] == o:
				continue
			var q: = PackedInt32Array([s0])
			cand[s0] = 3
			var hd: int = 0
			var open: bool = false
			while hd < q.size() and not open:
				var c: int = q[hd]
				hd += 1
				var sx: int = c % cw
				if sx == 0 or sx == cw - 1 or c < cw or c >= lim or q.size() > SEAL_CELLS:
					open = true
					break
				for d2: int in [-1, 1, - cw, cw]:
					var n: int = c + d2
					var cn: int = cand[n]
					if cn == 3:
						open = true
						break
					if cn >= 2 or own[(y0 + n / cw) * w + x0 + n % cw] == o:
						continue
					cand[n] = 3
					q.append(n)
			if open:
				continue
			for c2: int in q:
				cand[c2] = 4
				var g2: int = (y0 + c2 / cw) * w + x0 + c2 % cw
				if own[g2] == 0 and bio[g2] > ocean:
					out.append(g2)
	return out



static func _lake(lakes: Array, x: int, y: int) -> bool:
	for e: Array in lakes:
		var r: Rect2i = e[0]
		if x >= r.position.x and y >= r.position.y and x < r.end.x and y < r.end.y:
			if (e[1] as PackedByteArray)[(y - r.position.y) * r.size.x + (x - r.position.x)] == 1:
				return true
	return false



static func _dtl(d: PackedInt32Array, lab: PackedInt32Array, bw: int, bh: int) -> void :
	var e: int = bw - 1
	var v: int
	var l: int
	var t: int
	var k: int
	var u: int
	for x in range(1, bw):
		v = d[x]
		if v != 0:
			t = d[x - 1] + 3
			if t < v:
				d[x] = t
				lab[x] = lab[x - 1]
	for y in range(1, bh):
		var row: int = y * bw
		v = d[row]
		if v != 0:
			l = lab[row]
			u = row - bw
			t = d[u] + 3
			if t < v:
				v = t
				l = lab[u]
			t = d[u + 1] + 4
			if t < v:
				v = t
				l = lab[u + 1]
			d[row] = v
			lab[row] = l
		for k1 in range(row + 1, row + e):
			v = d[k1]
			if v == 0:
				continue
			l = lab[k1]
			t = d[k1 - 1] + 3
			if t < v:
				v = t
				l = lab[k1 - 1]
			u = k1 - bw
			t = d[u] + 3
			if t < v:
				v = t
				l = lab[u]
			t = d[u - 1] + 4
			if t < v:
				v = t
				l = lab[u - 1]
			t = d[u + 1] + 4
			if t < v:
				v = t
				l = lab[u + 1]
			d[k1] = v
			lab[k1] = l
		k = row + e
		v = d[k]
		if v != 0:
			l = lab[k]
			t = d[k - 1] + 3
			if t < v:
				v = t
				l = lab[k - 1]
			u = k - bw
			t = d[u] + 3
			if t < v:
				v = t
				l = lab[u]
			t = d[u - 1] + 4
			if t < v:
				v = t
				l = lab[u - 1]
			d[k] = v
			lab[k] = l
	var last: int = (bh - 1) * bw
	for k2 in range(last + bw - 2, last - 1, -1):
		v = d[k2]
		if v != 0:
			t = d[k2 + 1] + 3
			if t < v:
				d[k2] = t
				lab[k2] = lab[k2 + 1]
	for y2 in range(bh - 2, -1, -1):
		var row2: int = y2 * bw
		k = row2 + e
		v = d[k]
		if v != 0:
			l = lab[k]
			u = k + bw
			t = d[u] + 3
			if t < v:
				v = t
				l = lab[u]
			t = d[u - 1] + 4
			if t < v:
				v = t
				l = lab[u - 1]
			d[k] = v
			lab[k] = l
		for k3 in range(row2 + e - 1, row2, -1):
			v = d[k3]
			if v == 0:
				continue
			l = lab[k3]
			t = d[k3 + 1] + 3
			if t < v:
				v = t
				l = lab[k3 + 1]
			u = k3 + bw
			t = d[u] + 3
			if t < v:
				v = t
				l = lab[u]
			t = d[u + 1] + 4
			if t < v:
				v = t
				l = lab[u + 1]
			t = d[u - 1] + 4
			if t < v:
				v = t
				l = lab[u - 1]
			d[k3] = v
			lab[k3] = l
		v = d[row2]
		if v != 0:
			l = lab[row2]
			t = d[row2 + 1] + 3
			if t < v:
				v = t
				l = lab[row2 + 1]
			u = row2 + bw
			t = d[u] + 3
			if t < v:
				v = t
				l = lab[u]
			t = d[u + 1] + 4
			if t < v:
				v = t
				l = lab[u + 1]
			d[row2] = v
			lab[row2] = l




static func _dt(d: PackedInt32Array, bw: int, bh: int) -> void :
	var t: int
	var v: int
	var e: int = bw - 1
	var k: int
	for x in range(1, bw):
		v = d[x]
		if v != 0:
			t = d[x - 1] + 3
			if t < v:
				d[x] = t
	for y in range(1, bh):
		var row: int = y * bw
		v = d[row]
		if v != 0:
			t = mini(d[row - bw] + 3, d[row - bw + 1] + 4)
			if t < v:
				d[row] = t
		for k1 in range(row + 1, row + e):
			v = d[k1]
			if v != 0:
				var u: int = k1 - bw
				t = mini(mini(d[k1 - 1], d[u]) + 3, mini(d[u - 1], d[u + 1]) + 4)
				if t < v:
					d[k1] = t
		k = row + e
		v = d[k]
		if v != 0:
			t = mini(mini(d[k - 1], d[k - bw]) + 3, d[k - bw - 1] + 4)
			if t < v:
				d[k] = t
	var last: int = (bh - 1) * bw
	for k2 in range(last + bw - 2, last - 1, -1):
		v = d[k2]
		if v != 0:
			t = d[k2 + 1] + 3
			if t < v:
				d[k2] = t
	for y2 in range(bh - 2, -1, -1):
		var row2: int = y2 * bw
		k = row2 + e
		v = d[k]
		if v != 0:
			t = mini(d[k + bw] + 3, d[k + bw - 1] + 4)
			if t < v:
				d[k] = t
		for k3 in range(row2 + e - 1, row2, -1):
			v = d[k3]
			if v != 0:
				var u2: int = k3 + bw
				t = mini(mini(d[k3 + 1], d[u2]) + 3, mini(d[u2 + 1], d[u2 - 1]) + 4)
				if t < v:
					d[k3] = t
		v = d[row2]
		if v != 0:
			t = mini(mini(d[row2 + 1], d[row2 + bw]) + 3, d[row2 + bw + 1] + 4)
			if t < v:
				d[row2] = t



static func _flood4(q: PackedInt32Array, mark: PackedByteArray, fr: PackedByteArray, bw: int, bh: int, tag: int) -> void :
	var hd: int = 0
	var n: int = bw * bh
	while hd < q.size():
		var k: int = q[hd]
		hd += 1
		var x: int = k % bw
		for nb: int in [k - 1 if x > 0 else -1, k + 1 if x < bw - 1 else -1, k - bw, k + bw]:
			if nb >= 0 and nb < n and mark[nb] == 0 and fr[nb] != 0:
				mark[nb] = tag
				q.append(nb)





static func n3(bn: PackedByteArray, w: int, h: int, x: int, y: int) -> int:
	var x3: int = (x * 3) % (2 * w)
	var y3: int = (y * 3) % (2 * h)
	if x3 >= w:
		x3 = 2 * w - 1 - x3
	if y3 >= h:
		y3 = 2 * h - 1 - y3
	var x7: int = (x * 7) % (2 * w)
	var y7: int = (y * 7) % (2 * h)
	if x7 >= w:
		x7 = 2 * w - 1 - x7
	if y7 >= h:
		y7 = 2 * h - 1 - y7
	return ((int(bn[y * w + x]) - 128) * 10 + (int(bn[y3 * w + x3]) - 128) * 5 + (int(bn[y7 * w + x7]) - 128)) / 16


const WARP: int = 10




static func dn(bn: PackedByteArray, w: int, h: int, x: int, y: int, amp: int) -> int:
	return clampi(n3(bn, w, h, x, y) * amp * 3 / 128, - amp, amp)







static func warp_capture(own: PackedByteArray, old: PackedByteArray, fl: PackedByteArray, w: int, h: int, bn: PackedByteArray, lo: PackedInt32Array, hi: PackedInt32Array, y0: int, old_id: int, new_id: int) -> int:
	var n: int = lo.size()
	if n == 0 or bn.size() != w * h:
		return 0
	var changed: int = 0
	for ry in range( - WARP, n + WARP):
		var y: int = y0 + ry
		if y < 1 or y >= h - 1:
			continue

		var a0: int = 1 << 30
		var a1: int = - (1 << 30)
		var b0: int = 1 << 30
		var b1: int = - (1 << 30)
		var full0: int = 1 << 30
		var full1: int = - (1 << 30)
		for k in range(maxi(0, ry - WARP), mini(n, ry + WARP + 1)):
			if lo[k] > hi[k]:
				continue
			a0 = mini(a0, lo[k])
			a1 = maxi(a1, lo[k])
			b0 = mini(b0, hi[k])
			b1 = maxi(b1, hi[k])
			if k == 0 or k == n - 1 or lo[k - 1] > hi[k - 1] or lo[k + 1] > hi[k + 1] or ry - WARP < 0 or ry + WARP >= n:
				full0 = mini(full0, lo[k])
				full1 = maxi(full1, hi[k])
		if a0 > a1 and full0 > full1:
			continue
		var rngs: Array = [[a0 - WARP, a1 + WARP], [b0 - WARP, b1 + WARP]]
		if full0 <= full1:
			rngs = [[mini(a0, full0) - WARP, maxi(b1, full1) + WARP]]
		var last: int = - (1 << 30)
		for rg: Array in rngs:
			for x in range(maxi(maxi(1, int(rg[0])), last + 1), mini(w - 1, int(rg[1]) + 1)):
				last = x
				var i: int = y * w + x
				if old[i] != old_id or (fl[i] & WorldData.F_CITY) != 0:
					continue
				var qx: int = x + dn(bn, w, h, x, y, WARP)
				var qy: int = y + dn(bn, w, h, w - 1 - x, h - 1 - y, WARP)
				var k2: int = qy - y0
				var inside: bool = k2 >= 0 and k2 < n and qx >= lo[k2] and qx <= hi[k2]
				var want: int = new_id if inside else old_id
				if own[i] != want:
					own[i] = want
					changed += 1
	return changed


const MID_W: float = 10.0








static func xfer(own: PackedByteArray, bio: PackedByteArray, w: int, h: int, o: int, bn: PackedByteArray, war: PackedInt32Array, cities: Array) -> Array:
	var i0: int = own.find(o, 0)
	if i0 < 0 or bn.size() != w * h:
		return []
	var yA: int = maxi(1, i0 / w)
	var yB: int = mini(h - 2, own.rfind(o) / w)
	var ocean: int = Biome.OCEAN
	var ring: = PackedByteArray()
	ring.resize(w * h)
	var cur: = PackedInt32Array()
	var out_cur: = PackedInt32Array()
	for y in range(yA, yB + 1):
		var row: int = y * w
		var a: int = own.find(o, row)
		if a < 0 or a >= row + w:
			continue
		var b: int = own.rfind(o, row + w - 1)
		for i in range(maxi(a, row + 2), mini(b, row + w - 3) + 1):
			if own[i] != o or y < 2 or y > h - 3:
				continue
			var edge: bool = false
			for n: int in [i - 1, i + 1, i - w, i + w]:
				var f: int = own[n]
				if f == o or war.has(f):
					continue
				if f == 0 and bio[n] <= ocean:
					continue
				edge = true
				if f == 0 and ring[n] == 0:
					ring[n] = 101
					out_cur.append(n)
			if edge:
				ring[i] = 1
				cur.append(i)
	var band_in: Array = [cur]
	var band_out: Array = [out_cur]
	for r in range(2, WARP + 1):
		var nxt: = PackedInt32Array()
		for i2: int in cur:
			for n2: int in [i2 - 1, i2 + 1, i2 - w, i2 + w]:
				if n2 > 2 * w and n2 < w * (h - 2) and ring[n2] == 0 and own[n2] == o:
					ring[n2] = r
					nxt.append(n2)
		band_in.append(nxt)
		cur = nxt
		var onx: = PackedInt32Array()
		for i3: int in out_cur:
			for n3i: int in [i3 - 1, i3 + 1, i3 - w, i3 + w]:
				if n3i > 2 * w and n3i < w * (h - 2) and ring[n3i] == 0 and own[n3i] == 0 and bio[n3i] > ocean:
					ring[n3i] = 100 + r
					onx.append(n3i)
		band_out.append(onx)
		out_cur = onx
	var foes: Array = []
	for e: PackedInt32Array in cities:
		if e[3] != o:
			foes.append(e)
	var cells: = PackedInt32Array()
	var tos: = PackedInt32Array()
	var froms: = PackedInt32Array()
	var starts: = PackedInt32Array()
	for r2 in WARP:
		starts.append(cells.size())
		for side in 2:
			var rc: PackedInt32Array = band_in[r2] if side == 0 else band_out[r2]
			for p: int in rc:
				var x: int = p % w
				var y2: int = p / w
				var qx: int = clampi(x + dn(bn, w, h, x, y2, WARP), 0, w - 1)
				var qy: int = clampi(y2 + dn(bn, w, h, w - 1 - x, h - 1 - y2, WARP), 0, h - 1)
				var t: int = own[qy * w + qx]
				if side == 0:
					if t == o or war.has(t) or (t == 0 and bio[qy * w + qx] <= ocean):
						continue
				else:
					if t != o:
						continue
					var near_foe: bool = false
					for fe: PackedInt32Array in foes:
						var dx: float = float(x - fe[0])
						var dy: float = float(y2 - fe[1])
						if sqrt(dx * dx + dy * dy) - float(fe[2]) < float(BG.GAP):
							near_foe = true
							break
					if near_foe:
						continue
				cells.append(p)
				tos.append(t)
				froms.append(o if side == 0 else 0)
	return [] if cells.is_empty() else [cells, tos, starts, froms]









static func smooth(own: PackedByteArray, bio: PackedByteArray, w: int, h: int, o: int, war: PackedInt32Array, cities: Array = []) -> Array:
	var i0: int = own.find(o, 0)
	if i0 < 0:
		return []
	var yA: int = maxi(2, i0 / w - 1)
	var yB: int = mini(h - 3, own.rfind(o) / w + 1)
	var ocean: int = Biome.OCEAN
	var cells: = PackedInt32Array()
	var tos: = PackedInt32Array()
	var froms: = PackedInt32Array()
	var cnt: = PackedInt32Array()
	cnt.resize(256)
	for y in range(yA, yB + 1):
		var row: int = y * w

		var xa: int = w
		var xb: int = -1
		for r2: int in [row - w, row, row + w]:
			var fa: int = own.find(o, r2)
			if fa < 0 or fa >= r2 + w:
				continue
			xa = mini(xa, fa - r2)
			xb = maxi(xb, own.rfind(o, r2 + w - 1) - r2)
		if xb < 0:
			continue
		for i in range(row + maxi(2, xa - 1), row + mini(w - 3, xb + 1) + 1):
			var c: int = own[i]
			if c != o and c != 0:
				continue
			if c == o and own[i - 1] == o and own[i + 1] == o and own[i - w] == o and own[i + w] == o:
				continue
			if c == 0 and bio[i] < Biome.RIVER:
				continue
			var t: int = edge_rule(own, bio, w, i, o, war, cnt)
			if t < 0:
				continue
			if c == 0 and not cities.is_empty() and _near_foe(cities, o, i % w, i / w):
				continue
			cells.append(i)
			tos.append(t)
			froms.append(c)
	return [] if cells.is_empty() else [cells, tos, froms]










static func edge_rule(own: PackedByteArray, bio: PackedByteArray, w: int, i: int, o: int, war: PackedInt32Array, cnt: PackedInt32Array) -> int:
	var c: int = own[i]
	var n_o: int = 0
	for n: int in [i - 1, i + 1, i - w, i + w, i - w - 1, i - w + 1, i + w - 1, i + w + 1]:
		if own[n] == o:
			n_o += 1
	var ocean: int = Biome.OCEAN
	var dry: bool = bio[i] > Biome.RIVER
	if c == 0:
		if bio[i] < Biome.RIVER or n_o < 3:
			return -1
		if n_o >= 5:
			return o
		var a: int = 0
		for dy in range(-2, 3):
			var r: int = i + dy * w
			for dx in range(-2, 3):
				if own[r + dx] == o:
					a += 1
		return o if a >= 15 else -1
	if c != o or n_o > 6:
		return -1
	if n_o <= 3:
		cnt.fill(0)
		for n2: int in [i - 1, i + 1, i - w, i + w, i - w - 1, i - w + 1, i + w - 1, i + w + 1]:
			var on: int = own[n2]
			if on == 0 and bio[n2] <= ocean and dry:
				continue
			cnt[on] += 1
		var best: int = -1
		var bc: int = 3
		for n3i: int in [i - 1, i + 1, i - w, i + w, i - w - 1, i - w + 1, i + w - 1, i + w + 1]:
			var k: int = own[n3i]
			if k != o and cnt[k] > bc:
				best = k
				bc = cnt[k]
		if best >= 0 and not (best != 0 and (war.has(best) or n_o > 2)):
			return best

	var a2: int = 0
	cnt.fill(0)
	for dy2 in range(-2, 3):
		var r2: int = i + dy2 * w
		for dx2 in range(-2, 3):
			var g: int = r2 + dx2
			if g == i:
				continue
			var og: int = own[g]
			if og == o or (og == 0 and dry and bio[g] <= ocean):
				a2 += 1
			else:
				cnt[og] += 1
	if a2 > 9:
		return -1
	var t: int = -1
	for n4: int in [i - 2 * w - 2, i - 2 * w + 2, i + 2 * w - 2, i + 2 * w + 2, i - 1, i + 1, i - w, i + w, i - w - 1, i - w + 1, i + w - 1, i + w + 1, i - 2, i + 2, i - 2 * w, i + 2 * w]:
		var k2: int = own[n4]
		if k2 != o and cnt[k2] >= 12:
			t = k2
			break
	if t < 0 or (t != 0 and war.has(t)):
		return -1

	var ring: PackedInt32Array = PackedInt32Array([i - w - 1, i - w, i - w + 1, i + 1, i + w + 1, i + w, i + w - 1, i - 1])
	var runs: int = 0
	for q in 8:
		if own[ring[q]] != o and own[ring[(q + 1) % 8]] == o:
			runs += 1
	return t if runs == 1 else -1



static func _near_foe(cities: Array, o: int, x: int, y: int) -> bool:
	var own_e: float = 1000000000.0
	var foe_e: float = 1000000000.0
	for c: PackedInt32Array in cities:
		var lim: int = c[2] + BG.GAP + 2
		if maxi(absi(x - c[0]), absi(y - c[1])) > lim:
			continue
		var dx: float = float(x - c[0])
		var dy: float = float(y - c[1])
		var ed: float = sqrt(dx * dx + dy * dy) - float(c[2])
		if c[3] == o:
			own_e = minf(own_e, ed)
		else:
			foe_e = minf(foe_e, ed)
	return foe_e < float(BG.GAP) and foe_e < own_e
