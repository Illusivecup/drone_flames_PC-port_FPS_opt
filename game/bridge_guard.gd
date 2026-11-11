extends RefCounted





















var gw: GameWorld

const EVAL_DT: float = 90.0
const FLOW_R: float = 400.0
const FRONT_R: float = 3500.0
const STRUCK_T: float = 900.0
const D_KEYS: Array = [1, 2, 3]
const D_BR_AD: Array = [1, 2, 3]
const BR_GAP: Array = [360.0, 240.0, 150.0]
const AD_SHARE: float = 0.35
const AD_FREE: int = 4000
const COVER_K: float = 0.85
const SPACING: float = 48.0
const START_T: float = 420.0
const DIRS16: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(0.92388, 0.382683), Vector2(0.707107, 0.707107), Vector2(0.382683, 0.92388), Vector2(0.0, 1.0), Vector2(-0.382683, 0.92388), Vector2(-0.707107, 0.707107), Vector2(-0.92388, 0.382683), Vector2(-1.0, 0.0), Vector2(-0.92388, -0.382683), Vector2(-0.707107, -0.707107), Vector2(-0.382683, -0.92388), Vector2(0.0, -1.0), Vector2(0.382683, -0.92388), Vector2(0.707107, -0.707107), Vector2(0.92388, -0.382683)]

var placed: Dictionary = {}
var flow: Dictionary = {}
var stats: Dictionary = {}
var keys: Dictionary = {}
var _bought_t: Dictionary = {}

var _g_sig: Array = []
var _g_n: int = 0
var _g_edges: Array = []
var _g_by_br: Dictionary = {}
var _g_base: = PackedInt32Array()
var _g_bed: Array[Vector2i] = []


func _init(world: GameWorld) -> void :
	gw = world


func save_state() -> Dictionary:
	var p: Dictionary = {}
	for k: int in placed:
		p[str(k)] = int(placed[k])
	var fl: Dictionary = {}
	for k2: int in flow:
		fl[str(k2)] = float(flow[k2])
	var bt: Dictionary = {}
	for k3: int in _bought_t:
		bt[str(k3)] = float(_bought_t[k3])
	var ks: Dictionary = {}
	for k4: int in keys:
		ks[str(k4)] = (keys[k4] as Array).duplicate(true)
	return {"placed": p, "flow": fl, "bought_t": bt, "keys": ks}


func load_state(d: Dictionary) -> void :
	placed = {}
	var p: Dictionary = d.get("placed", {})
	for k: Variant in p:
		placed[int(str(k))] = int(p[k])
	flow = {}
	var fl: Dictionary = d.get("flow", {})
	for k2: Variant in fl:
		flow[int(str(k2))] = float(fl[k2])
	_bought_t = {}
	var bt: Dictionary = d.get("bought_t", {})
	for k3: Variant in bt:
		_bought_t[int(str(k3))] = float(bt[k3])
	keys = {}
	var ks: Dictionary = d.get("keys", {})
	for k4: Variant in ks:
		var e: Array = ks[k4]
		if e.size() != 3:
			continue
		var sg: Array = []
		for v: Variant in (e[1] as Array):
			sg.append(int(v))
		var lst: Array = []
		for r: Variant in (e[2] as Array):
			var ra: Array = r
			lst.append([int(ra[0]), float(ra[1]), float(ra[2]), String(ra[3]), bool(ra[4]) if ra.size() > 4 else (String(ra[3]).contains("удары") or String(ra[3]).contains("фронт"))])
		keys[int(str(k4))] = [float(e[0]), sg, lst]
	_g_sig = []
	_pc = []
	_jknown = {}


func _note(k: String, n: int = 1) -> void :
	stats[k] = int(stats.get(k, 0)) + n




func _sig() -> Array:
	var dead: int = 0
	if gw.rail != null:
		for e: Dictionary in gw.rail.edges:
			if bool(e.get("dead", false)):
				dead += 1
	return [gw.road_paths.size(), gw.rail.edges.size() if gw.rail != null else 0, dead, gw.cities.size(), gw.bridges.size()]


func _graph() -> void :
	var sig: Array = _sig()
	if sig == _g_sig:
		return
	_g_sig = sig
	_g_edges = []
	_g_by_br = {}
	var paths: Array = gw.road_paths
	var entr: Dictionary = {}
	for city: City in gw.cities:
		entr[city.entrance] = city.id
	_g_n = gw.cities.size()
	var junc: Dictionary = {}
	var ends: Array = []
	for path: Array in paths:
		if path.size() < 2:
			ends.append([-1, -1])
			continue
		var pe: Array = []
		for q: Vector2i in [path[0], path[path.size() - 1]]:
			if entr.has(q):
				pe.append(int(entr[q]))
				continue
			var ct: City = _city_near(q)
			if ct != null:
				pe.append(ct.id)
				continue
			if not junc.has(q):
				junc[q] = _g_n
				_g_n += 1
			pe.append(int(junc[q]))
		ends.append(pe)
	_scan(paths, junc)
	for pi in paths.size():
		var pe2: Array = ends[pi]
		if int(pe2[0]) < 0:
			continue

		var ev: Array = []
		var pc: Array = _pc[pi]
		var ks: PackedInt32Array = pc[0]
		var ids: PackedInt32Array = pc[1]
		for j in ks.size():
			ev.append(Vector3i(ks[j], 1, ids[j]))
		var last: int = (paths[pi] as Array).size() - 1
		for jq: Vector2i in pc[2]:
			var jc: Vector2i = (paths[pi] as Array)[jq.y]
			if jq.y > 0 and jq.y < last and junc.has(jc):
				ev.append(Vector3i(jq.y, 0, int(junc[jc])))
		ev.sort()
		var a: int = int(pe2[0])
		var brs: = PackedInt32Array()
		for e3: Vector3i in ev:
			if e3.y == 0:
				_edge(a, e3.z, brs, false)
				a = e3.z
				brs = PackedInt32Array()
			elif not brs.has(e3.z):
				brs.append(e3.z)
		_edge(a, int(pe2[1]), brs, false)
	if gw.rail != null:
		for e: Dictionary in gw.rail.edges:
			if bool(e.get("dead", false)):
				continue
			var sa: Dictionary = gw.rail.stations[int(e["a"])]
			var sb: Dictionary = gw.rail.stations[int(e["b"])]
			var rb: = PackedInt32Array()
			for br: Array in e.get("br", []):
				var bb: Bridge = br[0]
				if bb != null:
					rb.append(bb.id)
			_edge(int(sa["city"]), int(sb["city"]), rb, true)

	_g_base = PackedInt32Array()
	_g_base.resize(_g_n)
	for i in _g_n:
		_g_base[i] = i
	_g_bed = []
	for e2: Array in _g_edges:
		if (e2[2] as PackedInt32Array).is_empty():
			_union(_g_base, int(e2[0]), int(e2[1]))
	for i2 in _g_n:
		_g_base[i2] = _find(_g_base, i2)
	_g_by_br = {}
	for e4: Array in _g_edges:
		var brs4: PackedInt32Array = e4[2]
		if brs4.is_empty():
			continue
		var ra: int = _g_base[int(e4[0])]
		var rb2: int = _g_base[int(e4[1])]
		if ra == rb2:
			continue
		var bi: int = _g_bed.size()
		_g_bed.append(Vector2i(ra, rb2))
		for bid: int in brs4:
			var l: PackedInt32Array = _g_by_br.get(bid, PackedInt32Array())
			l.append(bi)
			_g_by_br[bid] = l
	_note("graph_builds")




var _pc: Array = []
var _jknown: Dictionary = {}
func _scan(paths: Array, junc: Dictionary) -> void :
	var d: WorldData = gw.data
	var old_n: int = _pc.size()
	for pi in range(old_n, paths.size()):
		var path: Array = paths[pi]
		var ks: = PackedInt32Array()
		var ids: = PackedInt32Array()
		var jh: Array[Vector2i] = []
		for k in path.size():
			var c: Vector2i = path[k]
			if d.has_flag(c.x, c.y, WorldData.F_BRIDGE):
				var b: Bridge = gw.bridge_at(c)
				if b != null:
					ks.append(k)
					ids.append(b.id)
			if _jknown.has(c):
				jh.append(Vector2i(pi, k))
		_pc.append([ks, ids, jh])
	var fresh: Dictionary = {}
	for q: Vector2i in junc:
		if not _jknown.has(q):
			fresh[q] = true
	if fresh.is_empty():
		return
	for pi2 in paths.size():
		var path2: Array = paths[pi2]
		var jh2: Array = _pc[pi2][2]
		for k2 in path2.size():
			if fresh.has(path2[k2]):
				jh2.append(Vector2i(pi2, k2))
	for q2: Vector2i in fresh:
		_jknown[q2] = true




func _city_near(q: Vector2i) -> City:
	var best: City = null
	var bd: int = 1 << 30
	for city: City in gw.cities:
		var dd: int = maxi(absi(city.center.x - q.x), absi(city.center.y - q.y))
		if dd <= city.claim_max / 2 + 4 and dd < bd:
			bd = dd
			best = city
	return best


func _edge(a: int, b: int, brs: PackedInt32Array, rail: bool) -> void :
	if a == b and brs.is_empty():
		return
	_g_edges.append([a, b, brs, rail])


static func _union(par: PackedInt32Array, a: int, b: int) -> void :
	var ra: int = _find(par, a)
	var rb: int = _find(par, b)
	if ra != rb:
		if ra < rb:
			par[rb] = ra
		else:
			par[ra] = rb




func _roots(skip: int) -> PackedInt32Array:
	var par: PackedInt32Array = _g_base.duplicate()
	var cut: PackedInt32Array = _g_by_br.get(skip, PackedInt32Array()) if skip >= 0 else PackedInt32Array()
	for bi in _g_bed.size():
		if not cut.is_empty() and cut.has(bi):
			continue
		_union(par, _g_bed[bi].x, _g_bed[bi].y)
	for i in _g_n:
		par[i] = _find(par, i)
	return par


static func _find(par: PackedInt32Array, i: int) -> int:
	var r: int = i
	while par[r] != r:
		r = par[r]
	while par[i] != r:
		var n: int = par[i]
		par[i] = r
		i = n
	return r





static func mid_px(b: Bridge) -> Vector2:
	var c: Vector2i = b.cells[b.cells.size() / 2]
	return Vector2(c.x * GameWorld.CELL + 2, c.y * GameWorld.CELL + 2)



func holds(b: Bridge, cid: int) -> bool:
	var d: WorldData = gw.data
	if b.cells.is_empty():
		return false
	var m: Vector2i = b.cells[b.cells.size() / 2]
	if d.get_owner_id(m.x, m.y) == cid:
		return true
	for c: Vector2i in [b.cells[0], b.cells[b.cells.size() - 1]]:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var q: = c + Vector2i(dx, dy)
				if d.inside(q.x, q.y) and d.get_owner_id(q.x, q.y) == cid:
					return true
	return false


func _down_n() -> int:
	var n: int = 0
	for b: Bridge in gw.bridges:
		if not b.passable():
			n += 1
	return n




func key_bridges(c: Country) -> Array:
	if c == null or c.capital_id < 0 or c.eliminated:
		return []
	var sig: Array = [c.city_ids.size(), _down_n(), c.at_war.size()] + _sig()
	var e: Array = keys.get(c.id, [])
	if e.size() == 3 and e[1] == sig and gw.game_time - float(e[0]) < EVAL_DT:
		return e[2]
	var out: Array = _evaluate(c)
	keys[c.id] = [gw.game_time, sig, out]
	_note("evals")
	return out


func _evaluate(c: Country) -> Array:
	_graph()
	if _g_edges.is_empty() or c.capital_id >= _g_n:
		return []
	var dp: Diplomacy = gw.diplo
	var cap: int = c.capital_id
	var full: PackedInt32Array = _roots(-1)
	var r0: int = full[cap]
	var own: Array[int] = []
	for cid: int in c.city_ids:
		if cid != cap and cid < _g_n and full[cid] == r0:
			own.append(cid)
	var partners: Array[int] = []
	for o: Country in gw.countries:
		if o == c or o.eliminated or o.capital_id < 0 or o.capital_id >= _g_n or dp == null or dp.at_war(c.id, o.id):
			continue
		if (dp.allied(c.id, o.id) or dp.has_treaty(c.id, o.id, "trade")) and full[o.capital_id] == r0:
			partners.append(o.capital_id)
	var foes: Array[Vector2] = []
	for fid: Variant in c.at_war.keys():
		var fc: Country = gw.country_by_id(int(fid))
		if fc == null:
			continue
		for fcid: int in fc.city_ids:
			foes.append(Vector2(gw.cities[fcid].center * GameWorld.CELL))
	var sup: Supply = gw.supply
	var out: Array = []
	for b: Bridge in gw.bridges:
		if not _g_by_br.has(b.id) or not holds(b, c.id):
			continue
		var p: Vector2 = mid_px(b)
		var n_tr: int = 0
		for t: Dictionary in gw.econ.trucks:
			if (t["pos"] as Vector2).distance_squared_to(p) < FLOW_R * FLOW_R:
				n_tr += 1
		var fl: float = float(flow.get(b.id, 0.0)) * 0.7 + float(n_tr) * 0.3
		flow[b.id] = fl
		var cut_own: int = 0
		var cut_tr: int = 0
		if not own.is_empty() or not partners.is_empty():
			var rr: PackedInt32Array = _roots(b.id)
			var rc: int = rr[cap]
			for oc: int in own:
				if rr[oc] != rc:
					cut_own += 1
			for pc: int in partners:
				if rr[pc] != rc:
					cut_tr += 1
		var imp: float = float(cut_own) + 0.8 * float(cut_tr) + minf(1.0, fl * 0.25)
		if cut_own == 0 and cut_tr == 0:
			imp = minf(imp, 0.5)
		if imp < 1.0:
			continue
		var front: float = 0.0
		for fp: Vector2 in foes:
			front = maxf(front, clampf(1.0 - fp.distance_to(p) / FRONT_R, 0.0, 1.0))
		var struck: float = 0.0
		if sup != null and sup._br_down_t.has(b.id) and gw.game_time - float(sup._br_down_t[b.id]) < STRUCK_T:
			var by: int = int(sup._br_by.get(b.id, 0))
			if by > 0 and by != c.id and (dp == null or not dp.allied(c.id, by)):
				struck = 1.0
		var sc: float = imp * (1.0 + front + struck)
		var why: String = "%d гор.%s%s%s" % [cut_own, (" · торговля %d" % cut_tr) if cut_tr > 0 else "", " · фронт" if front > 0.3 else "", " · удары" if struck > 0.0 else ""]
		out.append([b.id, sc, imp, why, front > 0.3 or struck > 0.0])
	out.sort_custom( func(x: Array, y: Array) -> bool: return float(x[1]) > float(y[1]) or (float(x[1]) == float(y[1]) and int(x[0]) < int(y[0])))
	var k: int = int(D_KEYS[GameConfig.diff_of(c)]) + (1 if not c.at_war.is_empty() else 0)
	if out.size() > k:
		out.resize(k)
	return out





func covered(c: Country, b: Bridge) -> bool:
	var p: Vector2 = mid_px(b)
	for f: Facility in gw.mil.facilities:
		if not Defense.SPEC.has(f.kind) or f.moving:
			continue
		if f.country_id != c.id and (gw.diplo == null or not gw.diplo.allied(c.id, f.country_id)):
			continue
		var r: float = float(Defense.SPEC[f.kind]["range"]) * COVER_K
		if f.center_px().distance_squared_to(p) <= r * r and gw.mil.alive(f):
			return true
	return false



func count_placed(c: Country) -> int:
	var n: int = 0
	for fid: int in placed:
		if fid >= 0 and fid < gw.mil.facilities.size():
			var f: Facility = gw.mil.facilities[fid]
			if f.country_id == c.id and Defense.is_ad(f.kind) and not gw.mil.is_demolished(f):
				n += 1
	return n






func want(c: Country, P: Dictionary, spent: Dictionary, extra: int) -> Array:
	if gw.game_time < START_T:
		return []
	var d: int = GameConfig.diff_of(c)
	var war: bool = not c.at_war.is_empty()
	var gap: float = float(BR_GAP[d]) * (1.25 - 0.25 * float(GameConfig.aggression)) * (1.2 - 0.4 * float(P.get("caution", 0.5)))
	if gw.game_time - float(_bought_t.get(c.id, -9999.0)) < gap:
		return []
	if count_placed(c) >= int(D_BR_AD[d]) + (1 if war else 0):
		return []
	var sp: Dictionary = spent.get(c.id, {})
	var tot: int = 0
	var ad: int = 0
	for k: String in sp:
		tot += int(sp[k])
		if k == "spaag" or k == "sam" or k == "patriot" or k == "bridge_ad":
			ad += int(sp[k])
	if ad > AD_FREE and float(ad) > float(tot) * AD_SHARE:
		_note("skip_share")
		return []
	for e: Array in key_bridges(c):
		var b: Bridge = gw.bridges[int(e[0])]
		if covered(c, b):
			_note("reuse")
			continue
		var kind: int = Facility.Kind.AD_SPAAG
		if war and extra >= 2 and bool(e[4]):
			kind = Facility.Kind.AD_SAM
		var urgent: bool = war and bool(e[4])
		return [b, kind, float(e[1]), urgent]
	return []





func place(c: Country, b: Bridge, kind: int) -> Facility:
	var mil: Military = gw.mil
	var d: WorldData = gw.data
	var p: Vector2 = mid_px(b)
	var bc: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	var reach: float = float(Defense.SPEC[kind]["range"]) * 0.7
	var k0: int = 0
	if c.capital_id >= 0:
		var to: Vector2 = Vector2(gw.cities[c.capital_id].center) - Vector2(bc)
		var bd: float = - INF
		for kk in DIRS16.size():
			var dd: float = DIRS16[kk].dot(to)
			if dd > bd:
				bd = dd
				k0 = kk
	var own_ad: Array[Vector2] = []
	for f: Facility in mil.facilities:
		if f.country_id == c.id and Defense.SPEC.has(f.kind) and not f.moving:
			own_ad.append(f.center_px())
	for r in range(5, 41, 3):
		if float(r * GameWorld.CELL) > reach:
			break
		for k in 16:
			var s: int = (k + 1) / 2 * (1 if k % 2 == 1 else -1)
			var dv: Vector2 = DIRS16[posmod(k0 + s, 16)]
			var q: Vector2i = bc + Vector2i(roundi(dv.x * float(r)), roundi(dv.y * float(r)))
			if not d.inside(q.x, q.y) or d.get_owner_id(q.x, q.y) != c.id:
				continue
			var nw: Vector2i = Military.nw_for(kind, q)
			var sz: Vector2i = Military.size_of(kind)
			if d.get_owner_id(nw.x, nw.y) != c.id or d.get_owner_id(nw.x + sz.x - 1, nw.y + sz.y - 1) != c.id:
				continue
			var qp: = Vector2(q * GameWorld.CELL) + Vector2(2, 2)
			var near: bool = false
			for ap: Vector2 in own_ad:
				if ap.distance_squared_to(qp) < SPACING * SPACING:
					near = true
					break
			if near:
				continue
			if mil.check_place(kind, nw, c, null, false) != "":
				continue
			var f2: Facility = mil.build(kind, q, c, null, true)
			if f2 != null:
				placed[f2.id] = b.id
				_bought_t[c.id] = gw.game_time
				_note("placed")
				_note("placed_" + ("sam" if kind == Facility.Kind.AD_SAM else "spaag"))
				if gw.diplo != null:
					gw.diplo.dlog(c.id, "ПВО у моста", "мост %d, %s" % [b.id, Military.title_of(kind)])
				return f2
	_note("no_spot")
	_bought_t[c.id] = gw.game_time - float(BR_GAP[GameConfig.diff_of(c)]) * 0.5
	return null
