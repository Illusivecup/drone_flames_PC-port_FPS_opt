extends RefCounted






const GAP: int = 13
const EXT: int = 25
const NEAR: int = 2 * EXT + GAP



static func reach(radius: int) -> int:
	return radius * 23 / 20 + 6




static func ctx(gw: GameWorld, at: Vector2i, scan: int, cid: int) -> Array:
	var out: Array = []
	var any_foreign: bool = false
	for oc: City in gw.cities:
		if oc.country_id == 0:
			continue
		var r: int = reach(oc.radius)
		if maxi(absi(oc.center.x - at.x), absi(oc.center.y - at.y)) > scan + r + GAP + EXT:
			continue
		var f: int = 0 if oc.country_id == cid else oc.country_id
		if f != 0:
			any_foreign = true
		out.append(PackedInt32Array([oc.center.x, oc.center.y, r, f, -1 if oc.claim_done else oc.claim_max * 72 / 100]))
	return out if any_foreign else []










static func may_claim(cx: Array, x: int, y: int, beyond: bool, nz: float = 0.0, me: int = 0) -> bool:
	var own_e: float = 1000000000.0
	var foe_e: float = 1000000000.0
	var foe: PackedInt32Array = PackedInt32Array()
	for e: PackedInt32Array in cx:
		var dx: float = float(x - e[0])
		var dy: float = float(y - e[1])
		var ed: float = sqrt(dx * dx + dy * dy) - float(e[2])
		if e[3] != 0:
			if ed < foe_e:
				foe_e = ed
				foe = e
		else:
			own_e = minf(own_e, ed)
	if beyond and foe_e >= float(NEAR):
		return false
	if foe_e < own_e - (nz if me < foe[3] else - nz):


		if foe_e < float(GAP):
			return false
		return foe[4] < 0 or maxi(absi(x - foe[0]), absi(y - foe[1])) > foe[4]
	return true



static func site_ok(gw: GameWorld, cell: Vector2i, cid: int, radius: int) -> bool:
	var d: WorldData = gw.data
	var lim: int = reach(radius) + GAP
	var l2: int = lim * lim
	for dy in range( - lim, lim + 1, 2):
		var y: int = cell.y + dy
		if y < 0 or y >= d.h:
			continue
		for dx in range( - lim, lim + 1, 2):
			var x: int = cell.x + dx
			if x < 0 or x >= d.w or dx * dx + dy * dy > l2:
				continue
			var o: int = d.owners[y * d.w + x]
			if o != 0 and o != cid:
				return false
	return true





const OWN_GAP: int = 32


static func own_ok(gw: GameWorld, cell: Vector2i, cid: int, radius: int) -> bool:
	for oc: City in gw.cities:
		if oc.country_id != cid:
			continue
		var need: float = float(radius + int(CityGen.params(oc.kind)["radius"]) + OWN_GAP)
		if Vector2(oc.center).distance_squared_to(Vector2(cell)) < need * need:
			return false
	return true




static func reopen_near(gw: GameWorld, city: City) -> void :
	for oc: City in gw.cities:
		if oc == city or oc.country_id == 0 or oc.country_id == city.country_id or not oc.claim_done:
			continue
		var lim: int = oc.claim_max + city.claim_max + 2 * EXT
		if maxi(absi(oc.center.x - city.center.x), absi(oc.center.y - city.center.y)) > lim:
			continue
		reopen(gw, oc)




static func reopen(gw: GameWorld, oc: City) -> void :
	oc.claim_done = false
	oc.frontier = [Vector3i(oc.center.x, oc.center.y, 0)]
	oc.visited = {oc.center.y * gw.data.w + oc.center.x: true}









const BRIDGE: int = 40




const SAG: float = 0.18
const WOB: float = 1.0
static var soft_on: bool = true
const T0: float = 0.15
const T1: float = 0.85



static func bridges(gw: GameWorld, city: City) -> Array:
	var out: Array = []
	if city.country_id == 0:
		return out
	for oc: City in gw.cities:
		if oc == city or oc.country_id != city.country_id:
			continue
		var gap: int = maxi(absi(oc.center.x - city.center.x), absi(oc.center.y - city.center.y)) - city.claim_max - oc.claim_max
		if gap > BRIDGE:
			continue
		var a: Vector2i = city.center
		var b: Vector2i = oc.center
		var la: int = city.claim_max
		var lb: int = oc.claim_max
		var pd: int = _pad(la, lb)
		out.append(PackedInt32Array([b.x, b.y, la, lb, mini(a.x - la, b.x - lb) - pd, mini(a.y - la, b.y - lb) - pd, maxi(a.x + la, b.x + lb) + pd, maxi(a.y + la, b.y + lb) + pd]))
	return out



static func _pad(la: int, lb: int) -> int:
	return maxi(la, lb) * 40 / 100 + 2 if soft_on else 0




static func in_bridge(br: Array, ax: int, ay: int, x: int, y: int, wob: float = 0.0) -> bool:
	var px: float = float(x - ax)
	var py: float = float(y - ay)
	for e: PackedInt32Array in br:
		if x < e[4] or y < e[5] or x > e[6] or y > e[7]:
			continue
		var dx: float = float(e[0] - ax)
		var dy: float = float(e[1] - ay)
		var la: float = float(e[2]) + (wob * WOB if soft_on else 0.0)
		var dl: float = float(e[3] - e[2])
		var lo: float = T0
		var hi: float = T1
		var k: float = dx + dl
		var m: float = px - la
		if k > 0.0:
			lo = maxf(lo, m / k)
		elif k < 0.0:
			hi = minf(hi, m / k)
		elif m > 0.0:
			continue
		k = dl - dx
		m = - px - la
		if k > 0.0:
			lo = maxf(lo, m / k)
		elif k < 0.0:
			hi = minf(hi, m / k)
		elif m > 0.0:
			continue
		k = dy + dl
		m = py - la
		if k > 0.0:
			lo = maxf(lo, m / k)
		elif k < 0.0:
			hi = minf(hi, m / k)
		elif m > 0.0:
			continue
		k = dl - dy
		m = - py - la
		if k > 0.0:
			lo = maxf(lo, m / k)
		elif k < 0.0:
			hi = minf(hi, m / k)
		elif m > 0.0:
			continue
		if lo <= hi:
			if not soft_on:
				return true

			for j in 5:
				var t: float = lo + (hi - lo) * float(j) * 0.25
				var r: float = (la + t * dl) * (1.0 - SAG * 4.0 * t * (1.0 - t))
				if absf(px - t * dx) <= r and absf(py - t * dy) <= r:
					return true
	return false






static func table(gw: GameWorld) -> Array:
	var n: int = gw.cities.size()
	var cx: = PackedInt32Array()
	var cy: = PackedInt32Array()
	var cc: = PackedInt32Array()
	var rr: = PackedInt32Array()
	var cm: = PackedInt32Array()
	var cd: = PackedInt32Array()
	cx.resize(n)
	cy.resize(n)
	cc.resize(n)
	rr.resize(n)
	cm.resize(n)
	cd.resize(n)
	for k in n:
		var oc: City = gw.cities[k]
		if oc.id != k:
			return []
		cx[k] = oc.center.x
		cy[k] = oc.center.y
		cc[k] = oc.country_id
		rr[k] = reach(oc.radius)
		cm[k] = oc.claim_max
		cd[k] = 1 if oc.claim_done else 0
	return [cx, cy, cc, rr, cm, cd]



static func tab_set(tab: Array, city: City) -> void :
	if tab.is_empty() or city.id >= (tab[0] as PackedInt32Array).size():
		return
	var cm: PackedInt32Array = tab[4]
	var cd: PackedInt32Array = tab[5]
	cm[city.id] = city.claim_max
	cd[city.id] = 1 if city.claim_done else 0
	tab[4] = cm
	tab[5] = cd



static func ctx_t(tab: Array, at: Vector2i, scan: int, cid: int) -> Array:
	var out: Array = []
	var any_foreign: bool = false
	var cx: PackedInt32Array = tab[0]
	var cy: PackedInt32Array = tab[1]
	var cc: PackedInt32Array = tab[2]
	var rr: PackedInt32Array = tab[3]
	var cm: PackedInt32Array = tab[4]
	var cd: PackedInt32Array = tab[5]
	var lim: int = scan + GAP + EXT
	for k in cx.size():
		var o: int = cc[k]
		if o == 0:
			continue
		var r: int = rr[k]
		if maxi(absi(cx[k] - at.x), absi(cy[k] - at.y)) > lim + r:
			continue
		var f: int = 0 if o == cid else o
		if f != 0:
			any_foreign = true
		out.append(PackedInt32Array([cx[k], cy[k], r, f, -1 if cd[k] != 0 else cm[k] * 72 / 100]))
	return out if any_foreign else []



static func bridges_t(tab: Array, city: City) -> Array:
	var out: Array = []
	if city.country_id == 0:
		return out
	var cx: PackedInt32Array = tab[0]
	var cy: PackedInt32Array = tab[1]
	var cc: PackedInt32Array = tab[2]
	var cm: PackedInt32Array = tab[4]
	var a: Vector2i = city.center
	var la: int = city.claim_max
	var me: int = city.country_id
	for k in cx.size():
		if cc[k] != me or k == city.id:
			continue
		var lb: int = cm[k]
		var bx: int = cx[k]
		var by: int = cy[k]
		if maxi(absi(bx - a.x), absi(by - a.y)) - la - lb > BRIDGE:
			continue
		var pd: int = _pad(la, lb)
		out.append(PackedInt32Array([bx, by, la, lb, mini(a.x - la, bx - lb) - pd, mini(a.y - la, by - lb) - pd, maxi(a.x + la, bx + lb) + pd, maxi(a.y + la, by + lb) + pd]))
	return out
