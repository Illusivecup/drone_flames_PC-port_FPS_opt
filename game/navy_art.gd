class_name NavyArt
extends RefCounted



















const NavyStrike = preload("res://game/navy_strike.gd")

const RANGE: float = 1000.0
const MIN_R: float = 110.0
const SALVO: int = 4
const RIPPLE: float = 0.4
const RELOAD: float = 16.0
const SPREAD0: float = 26.0
const SPREAD_K: float = 0.05
const DMG: float = 30.0
const BLAST: float = 14.0
const SAFE_PAD: float = 45.0
const SHELL_V: float = 300.0
const CALL_R: float = 240.0
const THINK: float = 1.0
const AI_TRIP_R: float = 2600.0
const TRIP_T: float = 240.0
const TRIP_GAP: float = 30.0
const ANSWER_T: float = 45.0
const FAC_KINDS: Array = [Facility.Kind.COASTAL_ASM, Facility.Kind.AD_SAM, Facility.Kind.AD_SPAAG, Facility.Kind.AD_PATRIOT, 
	Facility.Kind.AD_RADAR, Facility.Kind.TEL, Facility.Kind.BARRACKS, Facility.Kind.DRONE_PORT, Facility.Kind.DUGOUT]




const INLAND_MAX: float = 400.0
const AI_FITS: Array = [["gun", "ciws", "art"], ["gun", "ciws", "sam", "art"], ["gun", "ciws", "sam", "ash", "art", "vls"]]

var nv: Navy
var gw: GameWorld
var cd: Dictionary = {}
var q: Array = []
var trip_at: Dictionary = {}
var on_call: Dictionary = {}
var stats: Dictionary = {"salvos": 0, "shells": 0, "auto": 0, "manual": 0, "calls": 0, "answered": 0, "trips": 0, "fac": 0, "city": 0, 
	"hits": 0, "ff": 0, "hold": 0, "out": 0, "lost": 0}
var _t: float = 0.0
var _calls: Dictionary = {}
var _land: Array = []
var _bk: Dictionary = {}
var _bk_ok: bool = false
var vis_hits: Array = []
var vis_salvo: Array = []
var _inl_src: = PackedInt32Array()
var ai_why: Dictionary = {}
const BK: float = 512.0


func _init(navy: Navy) -> void :
	nv = navy
	gw = navy.gw



func inland(p: Vector2) -> float:
	var pr: Ports = nv._ports()
	if _inl_src.is_empty():
		_build_inland(pr)
	var q: Vector2i = nv._q(p)
	if q.x < 0 or q.y < 0 or q.x >= pr._w or q.y >= pr._h:
		return INF
	var j: int = _inl_src[q.y * pr._w + q.x]
	if j < 0:
		return INF
	if pr._body_at(q) != 0:
		return 0.0
	return maxf(0.0, p.distance_to(pr.cell_px(Vector2i(j % pr._w, j / pr._w))) - float(Ports.K * GameWorld.CELL) * 0.5)


func coast_ok(p: Vector2) -> bool:
	return inland(p) <= INLAND_MAX




func _build_inland(pr: Ports) -> void :
	pr.ensure_sea()
	var W: int = pr._w
	var H: int = pr._h
	var n: int = W * H
	_inl_src.resize(n)
	_inl_src.fill(-1)
	var cap: float = INLAND_MAX / float(Ports.K * GameWorld.CELL) + 2.0

	var okb: Dictionary = {}
	for b: Variant in pr.body_size:
		if int(pr.body_size[b]) >= Ports.MIN_SEA:
			okb[int(b)] = true
	var nav: = PackedByteArray()
	nav.resize(n)
	var bd: PackedInt32Array = pr.body
	for i in n:
		var b0: int = bd[i]
		if b0 > 0 and okb.has(b0):
			nav[i] = 1

	var q: = PackedInt32Array()
	for i in n:
		if nav[i] == 0:
			continue
		_inl_src[i] = i
		var x1: int = i % W
		if (x1 > 0 and nav[i - 1] == 0) or (x1 < W - 1 and nav[i + 1] == 0) or (i >= W and nav[i - W] == 0) or (i + W < n and nav[i + W] == 0):
			q.append(i)
	var qi: int = 0
	while qi < q.size():
		var j: int = q[qi]
		qi += 1
		var src: int = _inl_src[j]
		var sx: int = src % W
		var sy: int = src / W
		var x0: int = j % W
		var y0: int = j / W
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var x: int = x0 + dx
				var y: int = y0 + dy
				if (dx == 0 and dy == 0) or x < 0 or y < 0 or x >= W or y >= H:
					continue
				var k: int = y * W + x
				if _inl_src[k] >= 0:
					continue
				var ex: float = float(x - sx)
				var ey: float = float(y - sy)
				if ex * ex + ey * ey > cap * cap:
					continue
				_inl_src[k] = src
				q.append(k)


static func spread_at(d: float) -> float:
	return SPREAD0 + SPREAD_K * d


static func per_salvo(s: Ship) -> int:
	return SALVO * s.count_mod("art")



static func salvos_left(s: Ship) -> int:
	var k: int = per_salvo(s)
	return int(s.ammo.get("art", 0)) / k if k > 0 else 0


func _friend(c: int, o: int) -> bool:
	return o == c or (gw.diplo != null and gw.diplo.allied(c, o))


func _owner_at(p: Vector2) -> int:
	var cx: int = floori(p.x / GameWorld.CELL)
	var cy: int = floori(p.y / GameWorld.CELL)
	return gw.data.get_owner_id(cx, cy) if gw.data.inside(cx, cy) else 0


func _land_ok(p: Vector2) -> bool:
	var cx: int = floori(p.x / GameWorld.CELL)
	var cy: int = floori(p.y / GameWorld.CELL)
	return gw.data.inside(cx, cy) and Biome.is_natural_land(gw.data.get_biome(cx, cy)) or _owner_at(p) > 0



func blockers(c: int, p: Vector2, r: float) -> int:
	if gw.army == null:
		return 0
	var n: int = 0
	var r2: float = r * r
	for u: Unit in (_near_units(p, r) if _bk_ok else gw.army.units):
		if u.alive() and u.ground() and u.pos.distance_squared_to(p) <= r2 and not nv._hostile(c, u.country_id):
			n += 1
	return n


func danger_r(d: float) -> float:
	return spread_at(d) + BLAST + SAFE_PAD




func tick(dt: float) -> void :
	var now: float = gw.game_time
	if not q.is_empty():
		_fire_due(now)
	if not _land.is_empty():
		_count_impacts(now)
	_t += dt
	if _t < THINK:
		return
	_t = 0.0
	_bk_ok = false
	for k in range(nv.ships.size()):
		var s: Ship = nv.ships[k]
		if not s.alive() or not s.has_mod("art") or s.refit != "":
			continue
		var co: Country = gw.country_by_id(s.c)
		if co == null or co.at_war.is_empty():
			continue
		if int(s.ammo.get("art", 0)) < 1 or now < float(cd.get(s.id, 0.0)) or not _auto_ok(s):
			continue
		var aim: Variant = _pick(s)
		if aim != null:
			_order_salvo(s, aim, false)
	_bk_ok = false
	_bk.clear()
	if not _calls.is_empty() and int(now) % 30 == 0:
		for key: String in _calls.keys():
			if now - float(_calls[key][0]) > ANSWER_T * 2.0:
				_calls.erase(key)




func _auto_ok(s: Ship) -> bool:
	var c: Country = gw.country_by_id(s.c)
	if c == null:
		return false
	var o: Dictionary = s.ord
	var hold: bool = bool(o.get("hold", false))
	if s.fleet != 0:
		var f: Dictionary = nv.fl.fleet(s.fleet)
		o = f.get("order", {})
		hold = hold or bool(f.get("hold", false))
	if hold:
		return false
	var k: String = String(o.get("k", ""))
	if not c.is_player:
		return k != "return"
	return k == "" or k == "stop" or k == "patrol" or k == "blockade"





func _pick(s: Ship) -> Variant:
	var now: float = gw.game_time
	var c: int = s.c
	var reach2: float = (RANGE + CALL_R) * (RANGE + CALL_R)
	var en: Array[Unit] = []
	var fr: Array[Unit] = []
	for u: Unit in _near_units(s.pos, RANGE + CALL_R):
		if not u.alive() or not u.ground() or u.pos.distance_squared_to(s.pos) > reach2:
			continue
		if nv._hostile(c, u.country_id):
			var d: float = u.pos.distance_to(s.pos)
			if d >= MIN_R and d <= RANGE and coast_ok(u.pos):
				en.append(u)
		elif _friend(c, u.country_id):
			fr.append(u)
	var best: Unit = null
	var bs: float = 0.0
	var cr2: float = CALL_R * CALL_R
	var towns: Array = _friend_towns(c, s.pos, RANGE + CALL_R)
	for e: Unit in en:
		var called: bool = false
		for f: Unit in fr:
			if f.pos.distance_squared_to(e.pos) <= cr2:
				called = true
				break
		if not called:
			called = _at_town(e.pos, towns)
		if not called:
			continue
		var key: String = "%d:%d:%d" % [c, floori(e.pos.x / 300.0), floori(e.pos.y / 300.0)]
		if not _calls.has(key):
			_calls[key] = [now, false]
			stats["calls"] = int(stats["calls"]) + 1
		var sc: float = 1.0 if e.entrenched else 1.5
		for e2: Unit in en:
			if e2 != e and e2.pos.distance_squared_to(e.pos) <= 45.0 * 45.0:
				sc += 1.0
		if sc > bs and blockers(c, e.pos, danger_r(e.pos.distance_to(s.pos))) == 0:
			bs = sc
			best = e
	if best != null:
		var k2: String = "%d:%d:%d" % [c, floori(best.pos.x / 300.0), floori(best.pos.y / 300.0)]
		if _calls.has(k2) and not bool(_calls[k2][1]):
			_calls[k2][1] = true
			stats["answered"] = int(stats["answered"]) + 1
		on_call[s.id] = true
		return best.pos
	var co: Country = gw.country_by_id(c)
	if co == null:
		return null


	var bf: Facility = null
	var bd: float = INF
	for f2: Facility in gw.mil.facilities:
		if f2.parent != null or not FAC_KINDS.has(f2.kind) or not nv._hostile(c, f2.country_id):
			continue
		var fp: Vector2 = f2.center_px()
		var d2: float = fp.distance_to(s.pos)
		if d2 < MIN_R or d2 > RANGE or not gw.mil.alive(f2) or not coast_ok(fp):
			continue
		if f2.kind == Facility.Kind.COASTAL_ASM:
			d2 *= 0.4
		if d2 < bd and blockers(c, fp, danger_r(d2)) == 0:
			bd = d2
			bf = f2
	if bf != null:
		stats["fac"] = int(stats["fac"]) + 1
		on_call[s.id] = false
		return bf.center_px()
	if co.is_player:
		return null
	for u2: Unit in fr:
		if u2.country_id != c or u2.target_city < 0 or u2.target_city >= gw.cities.size():
			continue
		var city: City = gw.cities[u2.target_city]
		var cp: Vector2 = Vector2(city.center * GameWorld.CELL)
		var d3: float = cp.distance_to(s.pos)
		if d3 >= MIN_R and d3 <= RANGE and nv._hostile(c, city.country_id) and coast_ok(cp) and blockers(c, cp, danger_r(d3)) == 0:
			stats["city"] = int(stats["city"]) + 1
			on_call[s.id] = false
			return cp
	return null



func _order_salvo(s: Ship, aim: Vector2, manual: bool, t0: float = -1.0) -> int:
	var n: int = mini(per_salvo(s), int(s.ammo.get("art", 0)))
	if n <= 0:
		return 0
	var now: float = gw.game_time
	var start: float = maxf(now, t0)
	s.ammo["art"] = int(s.ammo["art"]) - n
	cd[s.id] = start + RELOAD
	var sp: float = spread_at(s.pos.distance_to(aim))
	for i in n:
		q.append([start + float(i) * RIPPLE, s.id, aim, sp, manual, i, n])
	vis_salvo.append([start, aim, sp, s.c])
	if vis_salvo.size() > 16:
		vis_salvo.remove_at(0)
	stats["salvos"] = int(stats["salvos"]) + 1
	stats["manual" if manual else "auto"] = int(stats["manual" if manual else "auto"]) + 1
	nv._ev({"k": "art", "ship": s.id, "c": s.c, "pos": s.pos, "tp": aim, "n": n, "victim": _owner_at(aim), "manual": manual})
	return n


func _fire_due(now: float) -> void :
	var i: int = 0
	while i < q.size():
		var e: Array = q[i]
		if now < float(e[0]):
			i += 1
			continue
		q.remove_at(i)
		var s: Ship = nv.ship(int(e[1]))
		if s == null or not s.alive():
			stats["lost"] = int(stats["lost"]) + 1
			continue
		var aim: Vector2 = e[2]
		var d: float = s.pos.distance_to(aim)
		if d > RANGE * 1.08:
			stats["out"] = int(stats["out"]) + 1
			s.ammo["art"] = int(s.ammo.get("art", 0)) + 1
			continue
		if blockers(s.c, aim, float(e[3]) + BLAST + SAFE_PAD) > 0:
			stats["hold"] = int(stats["hold"]) + 1
			s.ammo["art"] = int(s.ammo.get("art", 0)) + 1
			continue
		_shell(s, aim, float(e[3]), int(e[5]) if e.size() >= 7 else 0, int(e[6]) if e.size() >= 7 else 1)



func _shell(s: Ship, aim: Vector2, spread: float, i: int = 0, n: int = 1) -> void :


	var walk: float = (float(i) / float(maxi(1, n - 1)) - 0.5) * 2.0 if n > 1 else 0.0
	var a: float = gw.rng.roll() * TAU
	var r: float = spread * 0.9 * sqrt(gw.rng.roll())
	var to: Vector2 = aim + (aim - s.pos).normalized() * walk * spread * 0.25 + Vector2.from_angle(a) * r
	var d: float = s.pos.distance_to(to)
	var dur: float = clampf(d / SHELL_V, 1.2, 4.5)
	gw.army.fire.shells.append({"k": 1, "from": s.pos, "to": to, "t": 0.0, "dur": dur, "h": clampf(d * 0.14, 40.0, 140.0), 
		"dmg": DMG, "r": BLAST, "c": s.c, "pts": PackedVector2Array(), "whistle": false, "trail": 0.0, "nv": s.id})
	stats["shells"] = int(stats["shells"]) + 1
	_land.append([gw.game_time + dur, to, s.c])
	s.art_t = gw.game_time
	s.art_aim = (to - s.pos).angle()

	if gw._on_screen(s.pos, 80.0):
		var mz: Vector2 = s.pos + Vector2.from_angle(s.art_aim) * 5.0
		gw.fx.spawn("arty_flash" if gw.fx.atlas_of.has("arty_flash") else "muzzle_flash", mz.round(), 6)
		Sfx.play("artillery_fire", s.pos, -3.0)



func _count_impacts(now: float) -> void :
	var i: int = 0
	while i < _land.size():
		var e: Array = _land[i]
		if now < float(e[0]):
			i += 1
			continue
		_land.remove_at(i)
		var p: Vector2 = e[1]
		var c: int = int(e[2])
		vis_hits.append([float(e[0]), p, c])
		if vis_hits.size() > 48:
			vis_hits.remove_at(0)
		var r2: float = (BLAST + 3.0) * (BLAST + 3.0)
		for u: Unit in gw.army.units:
			if u.alive() and u.ground() and u.pos.distance_squared_to(p) <= r2:
				if nv._hostile(c, u.country_id):
					stats["hits"] = int(stats["hits"]) + 1
				else:
					stats["ff"] = int(stats["ff"]) + 1





func ai_fit(c: Country, hull: int, base: Array) -> Array:
	var n: int = 0
	var na: int = 0
	for s: Ship in nv.ships:
		if s.c == c.id and s.alive():
			n += 1
			if s.has_mod("art"):
				na += 1
	for o: Dictionary in nv.prod:
		if int(o["c"]) == c.id:
			var k: int = int(o["n"]) - int(o["done"])
			n += k
			if (o.get("mods", []) as Array).has("art"):
				na += k
	if n < 1 or na * 2 > n:
		return base
	return AI_FITS[clampi(hull, 0, 2)]





func ai(c: Country) -> void :
	var now: float = gw.game_time
	for s: Ship in nv.ships:
		if s.c != c.id or not s.alive() or not s.has_mod("art"):
			continue
		if s.ord.has("art"):
			var tp: Vector2 = s.ord["art"]
			var low: bool = int(s.ammo.get("art", 0)) < per_salvo(s) or s.hp < s.hp_max * 0.5
			var there: bool = String(s.ord.get("k", "")) != "move"
			var idle: bool = now > float(cd.get(s.id, -999.0)) + 24.0
			if low or now - float(s.ord.get("art_t", now)) > TRIP_T or (there and idle and now - float(s.ord.get("art_t", now)) > 30.0 and not _fight_at(c.id, tp)):
				if float(cd.get(s.id, -999.0)) - RELOAD < float(s.ord.get("art_t", now)):
					trip_at[s.id] = now + 90.0
				var home: Facility = nv.fl._home(s)
				if low and home != null:
					nv.fl.ship_order(s, "return", nv.berth_px(home))
				else:
					s.ord.erase("art")
					s.ord["k"] = "stop"
			continue
		if c.at_war.is_empty() or s.refit != "" or s.hp < s.hp_max * 0.6 or salvos_left(s) < 2:
			ai_why[s.id] = "peace / refit / hurt / no shells"
			continue
		if now - float(trip_at.get(s.id, -999.0)) < TRIP_GAP or String(s.ord.get("k", "")) == "return":
			continue
		var duty: String = String((nv.fl.fleet(s.fleet).get("order", {}) as Dictionary).get("k", "")) if s.fleet != 0 else String(s.ord.get("k", ""))
		if duty == "escort" or duty == "blockade":
			ai_why[s.id] = "fleet duty: " + duty
			continue
		if _pick_ready(s):
			ai_why[s.id] = "busy here"
			continue
		var tp2: Variant = _trip_target(c.id, s, gw.game_time < float(cd.get(s.id, -999.0)) + 14.0)
		trip_at[s.id] = now
		if tp2 == null:
			ai_why[s.id] = "no fight in reach"
			continue
		var lp: Variant = _fire_spot(s, tp2)
		if lp == null:
			ai_why[s.id] = "no sea spot in range of %s" % str(tp2)
			continue
		ai_why[s.id] = "trip to %s" % str(lp)
		if nv.fl.ship_order(s, "move", lp) == "":
			s.ord["art"] = tp2
			s.ord["art_t"] = now
			stats["trips"] = int(stats["trips"]) + 1




func _near_units(p: Vector2, r: float) -> Array:
	if gw.net_driven and not gw.net_sim:


		var cx0: int = floori((p.x - r) / BK)
		var cx1: int = floori((p.x + r) / BK)
		var cy0: int = floori((p.y - r) / BK)
		var cy1: int = floori((p.y + r) / BK)
		var o: Array = []
		for u: Unit in gw.army.units:
			if u.alive() and u.ground():
				var bx: int = floori(u.pos.x / BK)
				var by: int = floori(u.pos.y / BK)
				if bx >= cx0 and bx <= cx1 and by >= cy0 and by <= cy1:
					o.append(u)
		return o
	if not _bk_ok:
		_bk.clear()
		for u: Unit in gw.army.units:
			if u.alive() and u.ground():
				var kk: = Vector2i(floori(u.pos.x / BK), floori(u.pos.y / BK))
				if not _bk.has(kk):
					_bk[kk] = []
				(_bk[kk] as Array).append(u)
		_bk_ok = true
	var out: Array = []
	for cy in range(floori((p.y - r) / BK), floori((p.y + r) / BK) + 1):
		for cx in range(floori((p.x - r) / BK), floori((p.x + r) / BK) + 1):
			var a: Array = _bk.get(Vector2i(cx, cy), [])
			if not a.is_empty():
				out.append_array(a)
	return out



func _pick_ready(s: Ship) -> bool:
	return gw.game_time < float(cd.get(s.id, -999.0)) + 14.0 and bool(on_call.get(s.id, false))



func _friend_towns(c: int, p: Vector2, r: float) -> Array:
	var out: Array = []
	for city: City in gw.cities:
		if city.country_id <= 0 or not _friend(c, city.country_id):
			continue
		var cp: Vector2 = Vector2(city.center * GameWorld.CELL)
		var cr: float = float(city.radius * GameWorld.CELL)
		if cp.distance_to(p) <= r + cr:
			out.append([cp, cr])
	return out


func _at_town(p: Vector2, towns: Array) -> bool:
	for t: Array in towns:
		var rr: float = float(t[1]) + CALL_R
		if p.distance_squared_to(t[0]) <= rr * rr:
			return true
	return false



func _fight_at(c: int, p: Vector2) -> bool:
	var own: Array[Unit] = []
	var en: Array[Unit] = []
	var r2: float = (400.0 + CALL_R) * (400.0 + CALL_R)
	for u: Unit in gw.army.units:
		if not u.alive() or not u.ground() or u.pos.distance_squared_to(p) > r2:
			continue
		if u.country_id == c:
			own.append(u)
		elif nv._hostile(c, u.country_id):
			en.append(u)
	var cr2: float = CALL_R * CALL_R
	for a: Unit in own:
		for b: Unit in en:
			if a.pos.distance_squared_to(b.pos) <= cr2:
				return true
	return false





func _trip_target(c: int, s: Ship, calls_only: bool = false) -> Variant:
	var r2: float = (AI_TRIP_R + CALL_R) * (AI_TRIP_R + CALL_R)
	var buck: Dictionary = {}
	var own: Array[Unit] = []
	for u: Unit in gw.army.units:
		if not u.alive() or not u.ground() or u.pos.distance_squared_to(s.pos) > r2:
			continue
		if u.country_id == c:
			own.append(u)
		elif nv._hostile(c, u.country_id):
			var k: = Vector2i(floori(u.pos.x / 300.0), floori(u.pos.y / 300.0))
			if not buck.has(k):
				buck[k] = []
			(buck[k] as Array).append(u)
	var best: Variant = null
	var bd: float = AI_TRIP_R
	var cr2: float = CALL_R * CALL_R
	for a: Unit in own:
		var da: float = a.pos.distance_to(s.pos)
		if da >= bd:
			continue
		var k0: = Vector2i(floori(a.pos.x / 300.0), floori(a.pos.y / 300.0))
		var hit: Unit = null
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				for b: Unit in buck.get(k0 + Vector2i(dx, dy), []):
					if b.pos.distance_squared_to(a.pos) <= cr2 and coast_ok(b.pos):
						hit = b
						break
				if hit != null:
					break
			if hit != null:
				break
		if hit != null:
			bd = da
			best = hit.pos
	if best != null:
		return best

	for a2: Unit in own:
		if a2.target_city < 0 or a2.target_city >= gw.cities.size():
			continue
		var city: City = gw.cities[a2.target_city]
		var cp: Vector2 = Vector2(city.center * GameWorld.CELL)
		var dc: float = cp.distance_to(s.pos)
		if dc < bd and nv._hostile(c, city.country_id) and a2.pos.distance_to(cp) <= float(city.radius * GameWorld.CELL) + 500.0 and coast_ok(cp):
			bd = dc
			best = cp
	if best != null:
		return best

	var towns: Array = _friend_towns(c, s.pos, AI_TRIP_R)
	if not towns.is_empty():
		for kb: Vector2i in buck:
			for b2: Unit in buck[kb]:
				var d2: float = b2.pos.distance_to(s.pos)
				if d2 < bd and _at_town(b2.pos, towns) and coast_ok(b2.pos):
					bd = d2
					best = b2.pos
	if best != null:
		return best
	if calls_only:
		return null
	var bd2: float = AI_TRIP_R
	for f: Facility in gw.mil.facilities:
		if f.parent != null or not FAC_KINDS.has(f.kind) or not nv._hostile(c, f.country_id):
			continue
		var fp: Vector2 = f.center_px()
		var d3: float = fp.distance_to(s.pos)
		if d3 < bd2 and gw.mil.alive(f) and coast_ok(fp) and _by_sea(fp, nv._body_px(s.pos)):
			bd2 = d3
			best = fp
	return best



func _by_sea(p: Vector2, body: int) -> bool:
	for r: float in [200.0, 400.0, 600.0]:
		for k in 8:
			if nv._body_px(p + Vector2.from_angle(TAU * float(k) / 8.0) * r) == body:
				return true
	return false



func _fire_spot(s: Ship, tp: Vector2) -> Variant:
	var body: int = nv._body_px(s.pos)
	if body <= 0:
		return null
	var away: Vector2 = (s.pos - tp).normalized()
	for frac: float in [0.7, 0.55, 0.4]:
		for rot: float in [0.0, 0.6, -0.6, 1.2, -1.2]:
			var q0: Vector2i = nv._sea_near(tp + away.rotated(rot) * RANGE * frac, 8, body)
			if q0.x < 0:
				continue
			var lp: Vector2 = nv._ports().cell_px(q0)
			if lp.distance_to(tp) <= RANGE * 0.85 and lp.distance_to(tp) >= MIN_R * 1.5 and not _coast_cover(s.c, lp):
				return lp
	return null



func _coast_cover(c: int, p: Vector2) -> bool:
	var r2: float = Navy.COAST_RANGE * 0.95 * Navy.COAST_RANGE * 0.95
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.COASTAL_ASM and nv._hostile(c, f.country_id) and f.center_px().distance_squared_to(p) <= r2 and gw.mil.alive(f):
			return true
	return false







func plan(cid: int, targets: Array) -> Dictionary:
	var out: Dictionary = {"ok": false, "total": 0, "available": 0, "assigned": 0, "ships": 0, "in_range": 0, 
		"per_target": [], "plan": [], "shooters": [], "peace": [], "why": ""}
	if cid <= 0:
		out["why"] = Loc.t("Нет флота")
		return out
	var free: Dictionary = {}
	var next: Dictionary = {}
	var shp: Dictionary = {}
	var now: float = gw.game_time
	for s: Ship in nv.ships:
		if s.c != cid or not s.alive() or not s.has_mod("art"):
			continue
		out["ships"] = int(out["ships"]) + 1
		var k: int = salvos_left(s)
		if k > 0:
			free[s.id] = k
			shp[s.id] = s
			next[s.id] = maxf(now, float(cd.get(s.id, 0.0)))
			out["available"] = int(out["available"]) + k
	if not targets.is_empty():
		var cur: Vector2 = (targets[targets.size() - 1] as Dictionary)["pos"]
		for id0: int in free:
			var d0: float = (shp[id0] as Ship).pos.distance_to(cur)
			if d0 <= RANGE and d0 >= MIN_R and coast_ok(cur):
				out["in_range"] = int(out["in_range"]) + int(free[id0])
	var used: Dictionary = {}
	var peace: Dictionary = {}
	for t: Dictionary in targets:
		var p: Vector2 = t["pos"]
		var n: int = int(t["n"])
		out["total"] = int(out["total"]) + n
		var own: int = _owner_at(p)
		var reason: String = ""
		var got: int = 0
		var eta: float = 0.0
		var sp_r: float = 0.0
		if not _land_ok(p):
			reason = Loc.t("Батарея бьёт только по суше")
		elif not coast_ok(p):
			reason = Loc.t("Далеко от берега: батарея бьёт до %d м от воды") % int(INLAND_MAX)
		elif own > 0 and own != cid and NavyStrike.blocked(gw, cid, own) != "":
			reason = Loc.t("Нельзя: %s") % [NavyStrike.blocked(gw, cid, own)]
		if reason == "":
			for i in n:
				var best: int = -1
				var bt: float = INF
				for id1: int in free:
					if int(free[id1]) <= 0:
						continue
					var d1: float = (shp[id1] as Ship).pos.distance_to(p)
					if d1 > RANGE or d1 < MIN_R:
						continue
					var t1: float = float(next[id1]) + d1 / SHELL_V
					if t1 < bt:
						bt = t1
						best = id1
				if best < 0:
					break
				free[best] = int(free[best]) - 1
				(out["plan"] as Array).append([best, p, float(next[best])])
				eta = maxf(eta, bt - now)
				sp_r = maxf(sp_r, spread_at((shp[best] as Ship).pos.distance_to(p)))
				next[best] = float(next[best]) + RELOAD
				used[best] = true
				got += 1
			if got > 0 and own > 0 and own != cid and not nv._hostile(cid, own) and not peace.has(own):
				peace[own] = true
				(out["peace"] as Array).append({"id": own, "name": NavyStrike._cname(gw, own), "note": NavyStrike.war_note(gw, cid, own)})
			if got == 0:
				reason = Loc.t("Нет корабля с батареей в %.1f км (ближе %d м нельзя)") % [RANGE / 1000.0, int(MIN_R)]
			elif got < n:
				reason = Loc.t("Не хватает залпов в досягаемости")
			elif blockers(cid, p, sp_r + BLAST + SAFE_PAD) > 0:
				reason = Loc.t("Свои в зоне разлёта: огонь ждёт")
		(out["per_target"] as Array).append({"ok": got == n, "reason": reason, "n": n, "got": got, "pos": p, "spread": sp_r, "eta": eta})
		out["assigned"] = int(out["assigned"]) + got
	for id2: int in used:
		(out["shooters"] as Array).append((shp[id2] as Ship).name)
	out["ok"] = int(out["assigned"]) > 0
	if int(out["ships"]) == 0:
		out["why"] = Loc.t("Нет кораблей с артбатареей: верфь › модуль «Артбатарея»")
	elif int(out["available"]) == 0:
		out["why"] = Loc.t("Нет снарядов: пополните у морской базы")
	return out





func strike(cid: int, targets: Array) -> Dictionary:
	var res: Dictionary = {"launched": 0, "ships": 0, "shells": 0, "wars": []}
	var clean: Array = []
	for t: Variant in targets:
		if t is Dictionary and (t as Dictionary).get("pos") is Vector2:
			clean.append({"pos": (t as Dictionary)["pos"], "n": clampi(int((t as Dictionary).get("n", 1)), 1, 24)})
	if clean.size() > 12:
		clean = clean.slice(0, 12)
	var mp: Dictionary = plan(cid, clean)
	for e: Dictionary in mp["peace"]:
		var why: String = NavyStrike.ensure_war(gw, cid, int(e["id"]))
		if why != "":
			nv._say(cid, why)
		else:
			(res["wars"] as Array).append(String(e["name"]))
	var who: Dictionary = {}
	for a: Array in mp["plan"]:
		var s: Ship = nv.ship(int(a[0]))
		if s == null:
			continue
		var own: int = _owner_at(a[1])
		if own > 0 and own != cid and not nv._hostile(cid, own):
			continue
		var n: int = _order_salvo(s, a[1], true, float(a[2]))
		if n > 0:
			res["launched"] = int(res["launched"]) + 1
			res["shells"] = int(res["shells"]) + n
			who[s.id] = true
	res["ships"] = who.size()
	return res




func save() -> Dictionary:
	return {"cd": cd, "q": q, "trip_at": trip_at, "stats": stats, "_t": _t, "on_call": on_call}


func load(d: Dictionary) -> void :
	cd = {}
	var c0: Variant = d.get("cd", {})
	if c0 is Dictionary:
		for k: Variant in c0:
			cd[int(k)] = float(c0[k])
	trip_at = {}
	var t0: Variant = d.get("trip_at", {})
	if t0 is Dictionary:
		for k2: Variant in t0:
			trip_at[int(k2)] = float(t0[k2])
	q = []
	for e: Variant in d.get("q", []):
		if e is Array and (e as Array).size() >= 5 and (e as Array)[2] is Vector2:
			var ee: Array = e
			q.append([float(ee[0]), int(ee[1]), ee[2], float(ee[3]), bool(ee[4]), int(ee[5]) if ee.size() >= 7 else 0, int(ee[6]) if ee.size() >= 7 else 1])
	var st: Variant = d.get("stats", {})
	if st is Dictionary:
		for k3: Variant in st:
			stats[k3] = st[k3]
	_t = float(d.get("_t", 0.0))
	on_call = {}
	var oc: Variant = d.get("on_call", {})
	if oc is Dictionary:
		for k4: Variant in oc:
			on_call[int(k4)] = bool(oc[k4])
	_calls.clear()
	_land.clear()
