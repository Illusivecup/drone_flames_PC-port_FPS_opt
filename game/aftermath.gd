extends RefCounted
























const MAX_WRECKS: int = 300
const TRUCKS_PER: int = 4
const MAX_TRUCKS: int = 20
const SENDS_PER_TICK: int = 2
const TRUCK_SPEED: float = 14.0
const LOAD_T: float = 4.0
const NOTE_GAP: float = 30.0
const SCAN_DT: float = 0.25
const CITY_DT: float = 1.0
const HOT_T: float = 30.0
const HOT_HIT: float = 12.0
const REPAIR_QUIET: float = 90.0
const NO_WAY_T: float = 60.0

var gw: GameWorld
var wrecks: Array = []
var trucks: Array = []
var notes: Dictionary = {}
var stats: Dictionary = {"wrecks": 0, "scrap": 0, "dropped": 0, "no_way": 0}
var _seen: Dictionary = {}
var _scan_t: float = 0.0
var _city_t: float = 0.0
var _next: int = 1
var _rr: int = 0
var air: RefCounted
const AIR_HOT_R: int = 40






const MEM_AREA: int = 32
const MEM_CITY_R: int = 2
const MEM_MAX: int = 24
const EMERG_T: float = 20.0


func _init(world: GameWorld) -> void :
	gw = world
	air = preload("res://game/air_wreck.gd").new(world)


func update(dt: float) -> void :
	air.update(dt)
	_scan_t += dt
	if _scan_t >= SCAN_DT:
		_scan_t = 0.0
		_scan()
	_city_t += dt
	if _city_t >= CITY_DT:
		_city_t = 0.0
		_cities()
		_dispatch()
		_notes()
	if not trucks.is_empty():
		_plan_step()
		_drive(dt)




func _scan() -> void :
	if gw.army == null:
		return
	var now: float = gw.game_time
	for u: Unit in gw.army.units:
		if u.state != Unit.State.DEAD or not u.vehicle() or u.hp > 0.0 or _seen.has(u.id):
			continue
		_seen[u.id] = u.dead_t
		if not _land(u.pos):
			_sink(u.pos, -1, u.type, u.frame)
			continue
		var c: Country = gw.country_by_id(u.country_id)
		var foes: Array = []
		if c != null:
			for k: Variant in c.at_war:
				foes.append(int(k))
		foes.sort()
		wrecks.append({"uid": u.id, "p": u.pos.round(), "type": u.type, "frame": u.frame, "c": u.country_id, "foes": foes, "st": 0, "t0": u.dead_t, "nw": -1.0})
		stats["wrecks"] = int(stats["wrecks"]) + 1
	if wrecks.size() > MAX_WRECKS:


		var ev: int = -1
		for k in wrecks.size():
			if int(wrecks[k]["st"]) == 0 and not wrecks[k].has("m") and not wrecks[k].has("q"):
				ev = k
				break
		if ev < 0:
			for k2 in wrecks.size():
				if int(wrecks[k2]["st"]) == 0 and not wrecks[k2].has("m"):
					ev = k2
					break
		if ev >= 0:
			wrecks.remove_at(ev)
			stats["dropped"] = int(stats["dropped"]) + 1
	for id: Variant in _seen.keys():
		if now - float(_seen[id]) > 3.0:
			_seen.erase(id)


func _land(p: Vector2) -> bool:
	var cx: int = floori(p.x / GameWorld.CELL)
	var cy: int = floori(p.y / GameWorld.CELL)
	if not gw.data.inside(cx, cy):
		return false
	return not Biome.is_water(gw.data.get_biome(cx, cy)) or gw.data.has_flag(cx, cy, WorldData.F_BRIDGE)






func add_air_wreck(p: Vector2, wk: int, c: int, src: int, fr: int, uid: int) -> void :
	wrecks.append({"uid": uid, "p": p, "type": -1, "frame": fr, "c": c, "foes": [], "st": 0, "t0": gw.game_time, "nw": -1.0, "k": wk, "src": src, "em": -1.0})
	stats["wrecks"] = int(stats["wrecks"]) + 1
	stats["air"] = int(stats.get("air", 0)) + 1


func _air_held(w: Dictionary) -> bool:
	var p: Vector2 = w["p"]
	var r: float = float(AIR_HOT_R * GameWorld.CELL)
	for c: City in gw.cities:
		if city_hot(c) and Vector2(c.center * GameWorld.CELL).distance_squared_to(p) <= r * r:
			return true
	return false



func held(w: Dictionary) -> bool:
	if int(w.get("k", 0)) > 0:
		return _air_held(w)
	var c: int = int(w["c"])
	for f: Variant in w["foes"]:
		if gw.diplo.at_war(c, int(f)):
			return true
	return false


func _collector(w: Dictionary) -> int:
	var p: Vector2 = w["p"]
	var cx: int = floori(p.x / GameWorld.CELL)
	var cy: int = floori(p.y / GameWorld.CELL)
	var o: int = gw.data.get_owner_id(cx, cy) if gw.data.inside(cx, cy) else 0
	var oc: Country = gw.country_by_id(o)
	if oc != null and not oc.city_ids.is_empty():
		return o
	return 0


func _dispatch() -> void :
	if wrecks.is_empty():
		return
	var now: float = gw.game_time
	var out: Dictionary = {}
	for t: Dictionary in trucks:
		out[int(t["c"])] = int(out.get(int(t["c"]), 0)) + 1

	var queue: Dictionary = {}
	var gone: Array = []
	for w: Dictionary in wrecks:
		if int(w["st"]) != 0:
			continue
		if not _land(w["p"]):
			gone.append(w)
			_sink(w["p"], int(w.get("k", 0)), int(w.get("src", w["type"])), int(w["frame"]))
			continue
		if held(w):
			continue
		if w.has("m"):
			if _mem_site(w["p"]):
				continue
			w.erase("m")
		if int(w.get("k", 0)) > 0:

			if float(w["em"]) < 0.0:
				w["em"] = now
				stats["emerg"] = int(stats.get("emerg", 0)) + 1
				continue
			if now - float(w["em"]) < EMERG_T:
				continue
		var cid: int = _collector(w)
		if cid == 0:
			if not w.has("q"):
				w["q"] = now
			continue
		if gw.diplo.at_war(cid, int(w["c"])) and int(w["c"]) != cid:
			continue
		if _memorial(w, now):
			continue
		if not queue.has(cid):
			queue[cid] = []
		(queue[cid] as Array).append(w)
	for w2: Dictionary in gone:
		wrecks.erase(w2)
	if queue.is_empty():
		return


	var ids: Array = queue.keys()
	ids.sort()
	var start: int = 0
	for k in ids.size():
		if int(ids[k]) > _rr:
			start = k
			break
	var sent: int = 0
	var tries: int = 0
	var pos: Dictionary = {}
	var k2: int = start
	while sent < SENDS_PER_TICK and trucks.size() < MAX_TRUCKS and tries < ids.size() * 2:
		var cid2: int = ids[k2 % ids.size()]
		k2 += 1
		tries += 1
		var q: Array = queue[cid2]
		var qi: int = int(pos.get(cid2, 0))
		if qi >= q.size() or int(out.get(cid2, 0)) >= TRUCKS_PER:
			continue
		var w3: Dictionary = q[qi]
		pos[cid2] = qi + 1
		_rr = cid2
		var home: Vector2 = _home(cid2, w3["p"])
		w3["st"] = 1


		var d0: Vector2 = (w3["p"] as Vector2) - home
		trucks.append({"id": _next, "c": cid2, "home": home, "wp": PackedVector2Array(), "wi": 0, "st": -1, "t": 0.0, "w": int(w3["uid"]), 
			"type": int(w3["type"]), "frame": int(w3["frame"]), "pos": home, "dir": d0.normalized() if d0.length() > 0.01 else Vector2.RIGHT, 
			"plan": _plan_new(home, w3["p"])})
		_next += 1
		out[cid2] = int(out.get(cid2, 0)) + 1
		sent += 1
		stats["peak"] = maxi(int(stats.get("peak", 0)), trucks.size())




func _memorial(w: Dictionary, now: float) -> bool:
	var k: int = int(w.get("k", 0))
	if k != 0 and k != 1 and k != 2:
		return false
	var uid: int = int(w["uid"])
	var h: int = Hash32.h2(uid, 319, 5)
	if h % 2 != 0 or not _mem_site(w["p"]):
		return false
	var p: Vector2 = w["p"]
	var ax: int = floori(p.x / float(GameWorld.CELL * MEM_AREA))
	var ay: int = floori(p.y / float(GameWorld.CELL * MEM_AREA))
	var cap: int = 1 + (Hash32.h2(ax, ay, 3190) % 2)
	var n_all: int = 0
	var n_area: int = 0
	for w2: Dictionary in wrecks:
		if w2.has("m"):
			n_all += 1
			var q: Vector2 = w2["p"]
			if floori(q.x / float(GameWorld.CELL * MEM_AREA)) == ax and floori(q.y / float(GameWorld.CELL * MEM_AREA)) == ay:
				n_area += 1
	if n_all >= MEM_MAX or n_area >= cap:
		return false
	w["m"] = now
	stats["memorial"] = int(stats.get("memorial", 0)) + 1
	return true


func _mem_site(p: Vector2) -> bool:
	var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	if not gw.data.inside(c.x, c.y):
		return false
	var b: int = gw.data.get_biome(c.x, c.y)
	if Biome.is_water(b) or (b >= Biome.ROAD and b <= Biome.PLAZA) or b == Biome.INDUSTRIAL:
		return false
	if gw.data.has_flag(c.x, c.y, WorldData.F_CITY | WorldData.F_ROAD | WorldData.F_BRIDGE | WorldData.F_OCCUPIED):
		return false
	for city: City in gw.cities:
		var r: int = city.radius + MEM_CITY_R
		if absi(city.center.x - c.x) <= r and absi(city.center.y - c.y) <= r:
			return false
	return true




func clear_site(city: City) -> void :
	var r: int = city.radius + 2
	var box: = Rect2(Vector2((city.center - Vector2i(r, r)) * GameWorld.CELL), Vector2(float((2 * r + 1) * GameWorld.CELL), float((2 * r + 1) * GameWorld.CELL)))
	for k in range(wrecks.size() - 1, -1, -1):
		var w: Dictionary = wrecks[k]
		if int(w["st"]) == 0 and box.has_point(w["p"]):
			wrecks.remove_at(k)
			stats["site"] = int(stats.get("site", 0)) + 1
	if gw.vfx != null:
		gw.vfx.clear_area(box)



func _sink(p: Vector2, wk: int, src: int, fr: int) -> void :
	if gw.vfx != null:
		preload("res://world/air_wreck_draw.gd").add_sink(gw, p, wk, src, fr)



func _home(cid: int, p: Vector2) -> Vector2:
	var c: Country = gw.country_by_id(cid)
	var best: Vector2 = p
	var bd: float = INF
	if c == null:
		return best
	for id in c.city_ids:
		if id < 0 or id >= gw.cities.size():
			continue
		var e: Vector2 = Vector2(gw.cities[id].entrance * GameWorld.CELL) + Vector2(2, 2)
		var d: float = e.distance_squared_to(p)
		if d < bd:
			bd = d
			best = e
	return best






func _way(a: Vector2, b: Vector2) -> PackedVector2Array:
	if _clear(a, b):
		return PackedVector2Array([b])
	var coarse: = PackedVector2Array([b])
	if _cell_dist(a, b) > LEG_MAX:
		coarse = gw.econ.nav_path(a, b)
		if not gw.econ.nav_last_ok or coarse.is_empty():
			return PackedVector2Array()
		coarse[coarse.size() - 1] = b
	var out: = PackedVector2Array()
	var from: Vector2 = a
	for qi in coarse.size():
		var q: Vector2 = coarse[qi]
		if qi < coarse.size() - 1 and not _free(_cell(q)):
			var sq: Vector2 = _snap(q)
			if sq == Vector2.INF:
				continue
			q = sq
		if _clear(from, q):
			out.append(q)
		else:
			var leg: PackedVector2Array = _leg(from, q)
			if leg.is_empty():
				return PackedVector2Array()
			out.append_array(leg)
		from = q
	stats["legs"] = int(stats.get("legs", 0)) + coarse.size()
	return out


const LEG_MAX: int = 16
const LEG_PAD: int = 10
const CHEAP_PER_TICK: int = 12


func _plan_new(a: Vector2, b: Vector2) -> Dictionary:
	return {"a": a, "b": b, "co": PackedVector2Array(), "ci": -1, "out": PackedVector2Array(), "from": a}






func _plan_step() -> void :
	var heavy: int = 1
	var cheap: int = CHEAP_PER_TICK
	for k in range(trucks.size()):
		var t: Dictionary = trucks[k]
		if int(t["st"]) != -1:
			continue
		var pl: Dictionary = t["plan"]
		var a: Vector2 = pl["a"]
		var b: Vector2 = pl["b"]
		if int(pl["ci"]) < 0:
			if cheap <= 0:
				return
			cheap -= 1
			if _clear(a, b):
				_plan_done(t, PackedVector2Array([b]))
				continue
			if _cell_dist(a, b) <= LEG_MAX:
				pl["co"] = PackedVector2Array([b])
			elif not bool(pl.get("nav", false)):


				var n: int = ceili(float(_cell_dist(a, b)) / float(LEG_MAX))
				var ch: = PackedVector2Array()
				for i in range(1, n + 1):
					ch.append(a.lerp(b, float(i) / float(n)))
				pl["co"] = ch
			else:
				if heavy <= 0:
					return
				heavy -= 1
				var co: PackedVector2Array = gw.econ.nav_path(a, b)
				if not gw.econ.nav_last_ok or co.is_empty():
					_plan_fail(k)
					return
				co[co.size() - 1] = b
				pl["co"] = co
			pl["ci"] = 0
		var co2: PackedVector2Array = pl["co"]
		while int(pl["ci"]) < co2.size():
			var q: Vector2 = co2[int(pl["ci"])]
			var from: Vector2 = pl["from"]
			if int(pl["ci"]) < co2.size() - 1 and not _free(_cell(q)):
				var sq: Vector2 = _snap(q)
				if sq == Vector2.INF:
					pl["ci"] = int(pl["ci"]) + 1
					continue
				q = sq
			if cheap <= 0:
				return
			cheap -= 1
			var o: PackedVector2Array = pl["out"]
			if _clear(from, q):
				o.append(q)
			else:
				if heavy <= 0:
					return
				heavy -= 1
				var leg: PackedVector2Array = _leg(from, q)
				if leg.is_empty():
					if bool(pl.get("nav", false)) or _cell_dist(a, b) <= LEG_MAX:
						_plan_fail(k)
					else:
						var np: Dictionary = _plan_new(a, b)
						np["nav"] = true
						t["plan"] = np
					return
				o.append_array(leg)
			pl["out"] = o
			pl["from"] = q
			pl["ci"] = int(pl["ci"]) + 1
		_plan_done(t, pl["out"])
		return



func _snap(p: Vector2) -> Vector2:
	var c: Vector2i = _cell(p)
	for r in range(1, 5):
		for dy in range( - r, r + 1):
			for dx in range( - r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q: = c + Vector2i(dx, dy)
				if _free(q):
					return Vector2(q * GameWorld.CELL) + Vector2(GameWorld.CELL * 0.5, GameWorld.CELL * 0.5)
	return Vector2.INF


func _plan_done(t: Dictionary, wp: PackedVector2Array) -> void :
	if wp.is_empty():


		var pl: Dictionary = t.get("plan", {})
		wp = PackedVector2Array([pl.get("b", t["home"])])
	t["wp"] = wp
	t["wi"] = 0
	t["st"] = 0
	t.erase("plan")
	var d0: Vector2 = wp[0] - (t["home"] as Vector2)
	if d0.length() > 0.01:
		t["dir"] = d0.normalized()


func _plan_fail(k: int) -> void :
	var t: Dictionary = trucks[k]
	stats["no_way"] = int(stats["no_way"]) + 1
	for w: Dictionary in wrecks:
		if int(w["uid"]) == int(t["w"]):
			w["st"] = 0
			if float(w["nw"]) < 0.0:
				w["nw"] = gw.game_time
			elif gw.game_time - float(w["nw"]) > NO_WAY_T:
				wrecks.erase(w)
			break
	trucks.remove_at(k)


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))


func _cell_dist(a: Vector2, b: Vector2) -> int:
	var d: Vector2i = (_cell(a) - _cell(b)).abs()
	return maxi(d.x, d.y)




func _free(c: Vector2i) -> bool:
	var d: WorldData = gw.data
	if not d.inside(c.x, c.y):
		return false
	var i: int = c.y * d.w + c.x
	var fl: int = d.flags[i]
	if Biome.is_water(d.biome[i]) and (fl & WorldData.F_BRIDGE) == 0:
		return false
	if (fl & WorldData.F_ROAD) != 0:
		return true
	return (fl & WorldData.F_OCCUPIED) == 0 or gw.tree_at.has(i)


func _clear(a: Vector2, b: Vector2) -> bool:
	var n: int = maxi(1, int(a.distance_to(b)))
	for k in range(1, n + 1):
		if not _free(_cell(a.lerp(b, float(k) / float(n)))):
			return false
	return true



func _leg(a: Vector2, b: Vector2) -> PackedVector2Array:
	var ca: Vector2i = _cell(a)
	var cb: Vector2i = _cell(b)
	var lo: = Vector2i(mini(ca.x, cb.x), mini(ca.y, cb.y)) - Vector2i(LEG_PAD, LEG_PAD)
	var hi: = Vector2i(maxi(ca.x, cb.x), maxi(ca.y, cb.y)) + Vector2i(LEG_PAD + 1, LEG_PAD + 1)
	lo = lo.max(Vector2i.ZERO)
	hi = hi.min(Vector2i(gw.data.w, gw.data.h))
	var g: = AStarGrid2D.new()
	g.region = Rect2i(lo, hi - lo)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	var d: WorldData = gw.data
	for y in range(lo.y, hi.y):
		for x in range(lo.x, hi.x):
			var c: = Vector2i(x, y)
			if not _free(c):
				g.set_point_solid(c, true)
			elif (d.flags[y * d.w + x] & WorldData.F_ROAD) == 0:
				g.set_point_weight_scale(c, 2.5)
	g.set_point_solid(ca, false)
	g.set_point_solid(cb, false)
	var ids: Array[Vector2i] = g.get_id_path(ca, cb)
	stats["fine"] = int(stats.get("fine", 0)) + 1
	if ids.is_empty() or ids[ids.size() - 1] != cb:
		return PackedVector2Array()
	var out: = PackedVector2Array()
	var half: = Vector2(GameWorld.CELL * 0.5, GameWorld.CELL * 0.5)
	for k in range(1, ids.size() - 1):
		if ids[k] - ids[k - 1] != ids[k + 1] - ids[k]:
			out.append(Vector2(ids[k] * GameWorld.CELL) + half)
	out.append(b)
	return out


func _drive(dt: float) -> void :
	for k in range(trucks.size() - 1, -1, -1):
		var t: Dictionary = trucks[k]
		var st: int = t["st"]
		if st < 0:
			continue
		if st == 1:
			t["t"] = float(t["t"]) + dt
			if float(t["t"]) >= LOAD_T:
				_take(int(t["w"]))
				var back: = PackedVector2Array()
				var wp: PackedVector2Array = t["wp"]
				for j in range(wp.size() - 2, -1, -1):
					back.append(wp[j])
				back.append(t["home"])
				t["wp"] = back
				t["wi"] = 0
				t["st"] = 2
			continue
		var wp2: PackedVector2Array = t["wp"]
		var wi: int = t["wi"]
		var pos: Vector2 = t["pos"]
		var step: float = TRUCK_SPEED * dt
		while step > 0.0 and wi < wp2.size():
			var to: Vector2 = wp2[wi] - pos
			var l: float = to.length()
			if l <= step:
				pos = wp2[wi]
				step -= l
				wi += 1
			else:
				pos += to / l * step
				t["dir"] = to / l
				step = 0.0
		t["pos"] = pos
		t["wi"] = wi
		if wi < wp2.size():
			continue
		if st == 0:
			t["st"] = 1
			t["t"] = 0.0
		else:
			_deliver(int(t["c"]))
			trucks.remove_at(k)


func _take(uid: int) -> void :
	for k in wrecks.size():
		if int(wrecks[k]["uid"]) == uid:
			wrecks.remove_at(k)
			return


func _deliver(cid: int) -> void :
	var c: Country = gw.country_by_id(cid)
	if c == null:
		return
	c.metal += 1
	stats["scrap"] = int(stats["scrap"]) + 1
	var nt: Array = notes.get(cid, [0, - NOTE_GAP])
	nt[0] = int(nt[0]) + 1
	notes[cid] = nt


func _notes() -> void :
	var now: float = gw.game_time
	for cid: Variant in notes.keys():
		var nt: Array = notes[cid]
		if int(nt[0]) > 0 and now - float(nt[1]) >= NOTE_GAP:
			gw.say(int(cid), Loc.mk("Металлолом: +%d металла (эвакуация техники)", [int(nt[0])]))
			nt[0] = 0
			nt[1] = now




func _cities() -> void :
	var now: float = gw.game_time
	var fights: Array = []
	if gw.army != null:
		for u: Unit in gw.army.units:
			if u.state == Unit.State.FIGHT or u.state == Unit.State.SIEGE:
				fights.append(u)
	for c: City in gw.cities:
		var hot: bool = c.siege_by != 0 or (c.hit_t > 0.0 and now - c.hit_t < HOT_HIT) or now - c.strike_t < HOT_HIT
		if c.siege_by != 0:
			c.war_by = c.siege_by
		if not hot and not fights.is_empty():
			var r: float = float((c.radius + 2) * GameWorld.CELL)
			var cp: = Vector2(c.center * GameWorld.CELL)
			for u: Unit in fights:
				if u.pos.distance_squared_to(cp) < r * r:
					hot = true
					if u.country_id != c.country_id:
						c.war_by = u.country_id
					break
		if hot:
			c.war_t = now



func city_hot(c: City) -> bool:
	return c != null and (c.siege_by != 0 or gw.game_time - c.war_t < HOT_T)




func repair_ok(c: City) -> bool:
	if c == null:
		return true
	if c.siege_by != 0:
		return false
	var q: float = gw.game_time - c.war_t
	if q > REPAIR_QUIET:
		return true
	return q > HOT_T and c.war_by > 0 and not gw.diplo.at_war(c.country_id, c.war_by)



static func build_cap(c: City) -> int:
	return [3, 2, 1][clampi(c.kind, 0, 2)] if c != null else 1




func save_state() -> Dictionary:
	return {"v": 1, "wrecks": wrecks, "trucks": trucks, "notes": notes, "stats": stats, "seen": _seen, "scan_t": _scan_t, "city_t": _city_t, "next": _next, "rr": _rr, 
		"air": air.save_state()}


func load_state(d: Dictionary) -> void :
	wrecks.clear()
	trucks.clear()
	for wv: Variant in d.get("wrecks", []):
		if not (wv is Dictionary):
			continue
		var w: Dictionary = wv
		var foes: Array = []
		for f: Variant in w.get("foes", []):
			foes.append(int(f))
		wrecks.append({"uid": int(w.get("uid", 0)), "p": Vector2(w.get("p", Vector2.ZERO)), "type": int(w.get("type", 0)), "frame": int(w.get("frame", 0)), 
			"c": int(w.get("c", 0)), "foes": foes, "st": int(w.get("st", 0)), "t0": float(w.get("t0", 0.0)), "nw": float(w.get("nw", -1.0))})
		if w.has("k"):
			var wl: Dictionary = wrecks[wrecks.size() - 1]
			wl["k"] = int(w["k"])
			wl["src"] = int(w.get("src", -1))
			wl["em"] = float(w.get("em", -1.0))
		if w.has("m"):
			wrecks[wrecks.size() - 1]["m"] = float(w["m"])
		if w.has("q"):
			wrecks[wrecks.size() - 1]["q"] = float(w["q"])
	var claimed: Dictionary = {}
	for tv: Variant in d.get("trucks", []):
		if not (tv is Dictionary):
			continue
		var t: Dictionary = tv
		var wp: PackedVector2Array = PackedVector2Array(t.get("wp", PackedVector2Array()))
		trucks.append({"id": int(t.get("id", 0)), "c": int(t.get("c", 0)), "home": Vector2(t.get("home", Vector2.ZERO)), "wp": wp, "wi": int(t.get("wi", 0)), 
			"st": int(t.get("st", 0)), "t": float(t.get("t", 0.0)), "w": int(t.get("w", 0)), "type": int(t.get("type", 0)), "frame": int(t.get("frame", 0)), 
			"pos": Vector2(t.get("pos", Vector2.ZERO)), "dir": Vector2(t.get("dir", Vector2.RIGHT))})
		claimed[int(t.get("w", 0))] = true
		var tl: Dictionary = trucks[trucks.size() - 1]
		if int(tl["st"]) < 0:

			var wpos: Vector2 = Vector2.INF
			for w4: Dictionary in wrecks:
				if int(w4["uid"]) == int(tl["w"]):
					wpos = w4["p"]
			if wpos == Vector2.INF:
				trucks.pop_back()
				claimed.erase(int(tl["w"]))
			else:
				tl["plan"] = _plan_new(tl["home"], wpos)
	for w2: Dictionary in wrecks:
		if int(w2["st"]) == 1 and not claimed.has(int(w2["uid"])):
			w2["st"] = 0
	notes = {}
	var nd: Variant = d.get("notes", {})
	if nd is Dictionary:
		for k: Variant in nd:
			var a: Array = nd[k]
			notes[int(k)] = [int(a[0]), float(a[1])]
	var sd: Variant = d.get("stats", {})
	if sd is Dictionary:
		for k2: Variant in sd:
			stats[String(k2)] = int(sd[k2])
	_seen = {}
	var se: Variant = d.get("seen", {})
	if se is Dictionary:
		for k3: Variant in se:
			_seen[int(k3)] = float(se[k3])
	_scan_t = float(d.get("scan_t", 0.0))
	_city_t = float(d.get("city_t", 0.0))
	_next = int(d.get("next", 1))
	_rr = int(d.get("rr", 0))
	var ad: Variant = d.get("air", {})
	air.load_state(ad if ad is Dictionary else {})
