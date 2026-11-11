class_name Rail
extends RefCounted









const DEV_DT: float = 5.0

const DEV_LEVELS: Array = [0, 6000, 15000, 30000, 60000]
const DEV_NAMES: Array = ["АГРАРНАЯ", "РАЗВИВАЮЩАЯСЯ", "ИНДУСТРИАЛЬНАЯ", "РАЗВИТАЯ", "ПРОЦВЕТАЮЩАЯ"]
const ENT_POINTS: int = 300
const MAX_LINK: int = 280
const TRAIN_SPEED: float = 22.0
const TRAIN_ACC: float = 6.0
const CAR_GAP: float = 10.0
const MAX_TRAINS: int = 24
const COSMETIC_PER_COUNTRY: int = 2
const CUT_REPAIR: float = 120.0
const STATION_REPAIR: float = 60.0
const STATION_SPRITE: String = "rail_station"
const STATION_FW: int = 6
const STATION_FD: int = 2
const FAIL_COOLDOWN: float = 150.0



const BUILD_MIN: float = 180.0
const BUILD_MAX: float = 240.0
const BUILD_DELAY: float = 15.0
const STUCK_TRUCK: float = 90.0
const TRUCK_RETRY: float = 6.0
const INTL_K: float = 1.8




const MAN_ST_COST: int = 600
const MAN_ST_RES: Dictionary = {"wood": 10, "metal": 5}
const MAN_ST_TIME: float = 60.0
const MAN_PX_COST: float = 1.6
const MAN_BR_COST: int = 250
const MAN_BR_PX: float = 6.0
const MAN_BR_TIME: float = 40.0
const MAN_METAL_PX: float = 40.0
const MAN_MAX_CELLS: int = 280
const MAN_MIN_CELLS: int = 24
const MAN_CAP: int = 2
const MAN_SNAP_PX: float = 48.0
const MAN_ST_GAP: float = 100.0
const PRIO_K: float = 0.5
const PRIO_BARRACKS: float = 160.0
const PRIO_FRONT: float = 300.0
const RailTroops = preload("res://game/rail_troops.gd")
static var build_instant: bool = false
static var test_dev_floor: int = 0
const WAGON: Dictionary = {"titanium": "rail_wagon_open", "metal": "rail_wagon_open", "precious": "rail_wagon_open", 
	"oil": "rail_wagon_tank", "fuel": "rail_wagon_tank", "wood": "rail_wagon_wood", "food": "rail_wagon_box", "goods": "rail_wagon_box"}

var gw: GameWorld
var mask: PackedByteArray = PackedByteArray()
var stations: Array = []
var city_station: Dictionary = {}
var edges: Array = []
var adj: Dictionary = {}
var trains: Array = []
var dev_level: Dictionary = {}
var dev_pts: Dictionary = {}
var cosmetic: bool = true
var urban: Urban
var layer: RailLayer
var train_layer: TrainLayer
var lights: Node2D
var _t: float = 0.0
var _check_t: float = 0.0
var _cos_t: float = 0.0
var _train_id: int = 1
var _fail: Dictionary = {}
var _rr: int = 0
var _job: Dictionary = {}
var perf: Dictionary = {}
var no_rail: Dictionary = {}
var troops = null
var stats: Dictionary = {}



func pt(label: String, t0_us: int) -> void :
	var ms: float = float(Time.get_ticks_usec() - t0_us) / 1000.0
	if ms > float(perf.get(label, 0.0)):
		perf[label] = snappedf(ms, 0.01)


func _init(world: GameWorld) -> void :
	gw = world
	mask.resize(gw.data.w * gw.data.h)
	urban = Urban.new(gw, self)
	troops = RailTroops.new(self)
	layer = gw.get_node_or_null("RailLayer") as RailLayer
	if layer == null:
		layer = RailLayer.new()
		layer.name = "RailLayer"
		gw.add_child(layer)
		gw.move_child(layer, gw.ground.get_index() + 1)
	layer.setup(self)
	train_layer = gw.get_node_or_null("TrainLayer") as TrainLayer
	if train_layer == null:
		train_layer = TrainLayer.new()
		train_layer.name = "TrainLayer"
		gw.add_child(train_layer)
		gw.move_child(train_layer, gw.units_ground.get_index())
	train_layer.rail = self
	if gw.night != null and gw.night.lights != null:
		lights = gw.night.lights.get_node_or_null("InfraLights") as Node2D
		if lights == null:
			lights = Node2D.new()
			lights.name = "InfraLights"
			lights.use_parent_material = true
			gw.night.lights.add_child(lights)
		for cn: Dictionary in lights.draw.get_connections():
			lights.draw.disconnect(cn["callable"])
		lights.draw.connect(_draw_lights)







func send(from_city_id: int, to_city_id: int, res: String, n: int, on_arrive: Callable, on_lost: Callable = Callable(), job: Dictionary = {}) -> bool:
	var sa: int = _trade_station(from_city_id, to_city_id)
	var sb: int = _trade_station(to_city_id, from_city_id)
	if sa < 0 or sb < 0 or sa == sb:
		return false
	var route: Array = _route(sa, sb, true)
	if route.is_empty():
		return false
	if not can_spawn(false):
		return false
	stats["cargo_sent"] = int(stats.get("cargo_sent", 0)) + n
	var cars: = PackedStringArray(["rail_loco"])
	var wn: int = clampi(n / 8 + 1, 2, 6)
	for k in wn:
		cars.append(String(WAGON.get(res, "rail_wagon_box")))
	var tr: Dictionary = _spawn(route, cars, false)
	tr["res"] = res
	tr["n"] = n
	tr["from_city"] = from_city_id
	tr["to_city"] = to_city_id
	tr["on_arrive"] = on_arrive
	tr["on_lost"] = on_lost
	tr["job"] = job
	return true



func has_link(from_city_id: int, to_city_id: int) -> bool:
	var sa: int = _trade_station(from_city_id, to_city_id)
	var sb: int = _trade_station(to_city_id, from_city_id)
	return sa >= 0 and sb >= 0 and sa != sb and not _route(sa, sb, true).is_empty()






func _trade_station(city_id: int, other_id: int) -> int:
	if city_id < 0 or city_id >= gw.cities.size():
		return -1
	var sid: int = int(city_station.get(city_id, -1))
	if sid >= 0 and _has_built(sid):
		return sid
	var cid: int = gw.cities[city_id].country_id
	var to: = Vector2(gw.cities[other_id].center) if other_id >= 0 and other_id < gw.cities.size() else Vector2(gw.cities[city_id].center)
	var best: int = sid
	var bd: float = INF
	for st: Dictionary in stations:
		var s2: int = int(st["id"])
		if _station_country(s2) != cid or float(st["ruin_t"]) >= 0.0 or not _has_built(s2):
			continue
		var d: float = Vector2(gw.cities[int(st["city"])].center).distance_to(to)
		if d < bd:
			bd = d
			best = s2
	return best


func _has_built(sid: int) -> bool:
	for eid: int in adj.get(sid, []):
		var e: Dictionary = edges[eid]
		if not bool(e["dead"]) and float(e.get("bt", 0.0)) <= 0.0:
			return true
	return false



func can_spawn(troop: bool) -> bool:
	if trains.size() < MAX_TRAINS + (2 if troop else 0):
		return true
	return _drop_cosmetic()



static func build_time(len_px: float) -> float:
	return clampf(BUILD_MIN + (len_px - 400.0) / 40.0, BUILD_MIN, BUILD_MAX)



func built_frac(e: Dictionary) -> float:
	var bt: float = float(e.get("bt", 0.0))
	if bt <= 0.0:
		return 1.0
	return clampf((gw.game_time - float(e.get("b0", 0.0))) / bt, 0.0, 1.0)



func building_n(cid: int, intl: int = -1) -> int:
	var n: int = 0
	for e: Dictionary in edges:
		if bool(e["dead"]) or float(e.get("bt", 0.0)) <= 0.0 or e.has("man"):
			continue
		var x: int = _station_country(int(e["a"]))
		var y: int = _station_country(int(e["b"]))
		if (x == cid or y == cid) and (intl < 0 or (intl == 1) == (x != y)):
			n += 1
	return n



func build_cap(cid: int) -> int:
	return 2 if level_of(cid) >= 3 else 1




func _intl_ok(a: int, b: int) -> bool:
	var dp: Diplomacy = gw.diplo
	if dp.at_war(a, b) or dp.embargo_between(a, b) or dp.embargo_between(b, a):
		return false
	if gw.econ.trading(a, b) or dp.allied(a, b) or (dp.ally != null and dp.ally.same(a, b)):
		return true
	if gw.econ.trd != null:
		for k: Dictionary in gw.econ.trd.contracts:
			if String(k.get("state", "")) == "on" and ((int(k["s"]) == a and int(k["b"]) == b) or (int(k["s"]) == b and int(k["b"]) == a)):
				return true
	return dp.get_opinion(a, b) >= 0 and dp.get_opinion(b, a) >= 0



func _build_tick() -> void :
	for e: Dictionary in edges:
		if bool(e["dead"]) or float(e.get("bt", 0.0)) <= 0.0:
			continue
		var s: PackedVector2Array = e["s"]
		var fr: float = built_frac(e)
		var k1: int = clampi(int(fr * float(s.size() - 1)), 0, s.size() - 1)
		var k0: int = clampi(int(e.get("bk", 0)), 0, s.size() - 1)
		if fr >= 1.0:
			e["bt"] = 0.0
			e["bk"] = s.size() - 1
			layer.mark_edge(int(e["id"]))
			stats["built"] = int(stats.get("built", 0)) + 1
			var ca: Country = gw.country_by_id(_station_country(int(e["a"])))
			var cb: Country = gw.country_by_id(_station_country(int(e["b"])))
			var txt: String = Loc.t("Железная дорога открыта: %s — %s") % [st_name(int(e["a"])), st_name(int(e["b"]))]
			if ca != null and ca.is_player:
				gw.say(ca, txt)
			if cb != null and cb != ca and cb.is_player:
				gw.say(cb, txt)
			if gw._on_screen(s[s.size() - 1], 80.0):
				Sfx.play("train_horn", s[s.size() - 1], -8.0)
			continue


		if k1 != k0 and s[k0].distance_to(s[k1]) >= 64.0:
			var r: = Rect2(s[k0], Vector2.ZERO).expand(s[k1])
			for i in range(mini(k0, k1), maxi(k0, k1) + 1, 8):
				r = r.expand(s[i])
			layer.mark_rect(r.grow(14.0))
			e["bk"] = k1
		if gw._on_screen(s[k1], 60.0):
			gw.fx.spawn("build_spark", s[k1].round() + Vector2(0, -2), 6)



func _to_truck(tr: Dictionary) -> bool:
	var job: Dictionary = tr.get("job", {})
	var e: Economy = gw.econ
	var k: int = -1
	for i in e.rail_jobs.size():
		if is_same(e.rail_jobs[i], job):
			k = i
			break
	if k < 0:
		return false
	var r: Country = gw.country_by_id(int(job.get("to", 0)))
	if r == null or r.capital_id < 0:
		return false
	var a: Vector2 = pos_at(tr, float(tr["s"]))
	var b: Vector2 = Vector2(gw.cities[r.capital_id].entrance * GameWorld.CELL)
	var land: PackedVector2Array = e.land_path(a, b)
	if land.is_empty():
		return false
	e.rail_jobs.remove_at(k)
	var t: Dictionary = job.duplicate()
	t.merge({"path": land, "i": 0, "pos": a, "heading": 0.0, "frame": 0, "id": e._truck_id, "from_rail": true}, true)
	e._truck_id += 1
	e.trucks.append(t)
	stats["cargo_truck"] = int(stats.get("cargo_truck", 0)) + int(job.get("n", 0))
	var s: Country = gw.country_by_id(int(job.get("from", 0)))
	if (s != null and s.is_player) or r.is_player:
		gw.say2(s, r, Loc.mk("Ж/Д перебита: груз (%s %d) перегружен на грузовик", [String(Economy.RES_NAMES.get(String(job.get("res", "")), "")).to_lower(), int(job.get("n", 0))]))
	return true




func set_rail_ok(c: Country, fids: PackedInt32Array, on: bool) -> String:
	if c == null:
		return Loc.t("Нет страны")
	var n: int = 0
	for fid: int in fids:
		var f: Facility = _fac(fid)
		if f == null or f.kind != Facility.Kind.BARRACKS or f.country_id != c.id:
			continue
		if on:
			no_rail.erase(fid)
		else:
			no_rail[fid] = true
			if troops != null:
				troops.on_forbid(f)
		n += 1
	if n == 0:
		return Loc.t("Нет армий")
	return ""



func _fac(fid: int) -> Facility:
	var fl: Array = gw.mil.facilities
	if fid >= 0 and fid < fl.size() and fl[fid] != null and (fl[fid] as Facility).id == fid:
		return fl[fid]
	for f: Facility in fl:
		if f.id == fid:
			return f
	return null


func rail_ok(fid: int) -> bool:
	return not no_rail.has(fid)



func hash_nums() -> PackedFloat64Array:
	var out: = PackedFloat64Array()
	out.append(float(trains.size()))
	var ss: int = 0
	for tr: Dictionary in trains:
		ss = (ss * 31 + int(float(tr["s"]) * 4.0) + int(tr["id"])) & 2147483647
	out.append(float(ss))
	out.append(float(edges.size()))
	out.append(float(no_rail.size()))
	out.append(float(stations.size()))
	if troops != null:
		out.append_array(troops.hash_nums())
	return out


func has_rail(c: Vector2i) -> bool:
	if not gw.data.inside(c.x, c.y):
		return false
	var i: int = c.y * gw.data.w + c.x
	return i < mask.size() and mask[i] != 0


func city_linked(city_id: int) -> bool:
	var sid: int = int(city_station.get(city_id, -1))
	return sid >= 0 and not (adj.get(sid, []) as Array).is_empty()



func city_text(city_id: int) -> String:
	var sid: int = int(city_station.get(city_id, -1))
	if sid < 0:
		return Loc.t("Ж/Д: нет")
	var lines: int = 0
	var broken: bool = float(stations[sid]["ruin_t"]) >= 0.0
	for eid: int in adj.get(sid, []):
		var e: Dictionary = edges[eid]
		if bool(e["dead"]):
			continue
		lines += 1
		if float(e.get("bt", 0.0)) > 0.0:
			return Loc.t("Ж/Д: строится %d %%") % roundi(built_frac(e) * 100.0)
		if _edge_blocked(e):
			broken = true
	if lines == 0:
		return Loc.t("Ж/Д: вокзал, линий нет")
	if broken:
		return Loc.t("Ж/Д: повреждена, ремонт")
	return Loc.n(lines, "Ж/Д: подключено (%d линия)", "Ж/Д: подключено (%d линии)", "Ж/Д: подключено (%d линий)") % lines


func level_of(country_id: int) -> int:
	return int(dev_level.get(country_id, 0))


func points_of(country_id: int) -> int:
	return int(dev_pts.get(country_id, 0))



func next_threshold(country_id: int) -> int:
	var l: int = level_of(country_id)
	return int(DEV_LEVELS[l + 1]) if l + 1 < DEV_LEVELS.size() else -1



func dev_text(country_id: int) -> String:
	var l: int = level_of(country_id)
	var nx: int = next_threshold(country_id)
	var s: String = Loc.t("РАЗВИТИЕ %d/%d · %s") % [l, DEV_LEVELS.size() - 1, Loc.t(String(DEV_NAMES[l]))]
	if nx > 0:
		s += " · %d / %d" % [points_of(country_id), nx]
	return s



static func level_unlocks(level: int) -> String:
	match level:
		1:
			return Loc.t("железная дорога: столица и ближайший город")
		2:
			return Loc.t("ж/д во все города, высотки, новые кварталы")
		3:
			return Loc.t("ж/д в сёла и к торговым партнёрам, стеклянные небоскрёбы")
		4:
			return Loc.t("телебашня в столице, деловые центры")
	return ""


func station_count(country_id: int) -> int:
	var n: int = 0
	for st: Dictionary in stations:
		var c: City = gw.cities[int(st["city"])]
		if c.country_id == country_id and city_linked(c.id):
			n += 1
	return n


func train_count(country_id: int) -> int:
	var n: int = 0
	for tr: Dictionary in trains:
		if int(tr["country"]) == country_id:
			n += 1
	return n



func bridge_owner(b: Bridge) -> int:
	if b.cells.is_empty():
		return 0
	for c: Vector2i in [b.cells[0], b.cells[b.cells.size() - 1]]:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var q: = c + Vector2i(dx, dy)
				if gw.data.inside(q.x, q.y) and gw.data.get_owner_id(q.x, q.y) > 0:
					return gw.data.get_owner_id(q.x, q.y)
	return 0


func layer_dirty() -> void :
	if layer != null:
		layer.mark_all_bridges()




func update(dt: float) -> void :
	var t0: int = Time.get_ticks_usec()
	_t += dt
	if _t >= DEV_DT:
		_t = 0.0
		_dev_tick()
		pt("dev_tick", t0)
	_check_t += dt
	if _check_t >= 2.0:
		_check_t = 0.0
		_repair_tick()
	_cos_t += dt
	if _cos_t >= 7.0:
		_cos_t = 0.0
		_cosmetic_tick()
	_poll_job()
	urban.poll()
	var t1: int = Time.get_ticks_usec()
	_move_trains(dt)
	troops.update(dt)
	pt("trains", t1)
	t1 = Time.get_ticks_usec()
	layer.tick(dt)
	pt("raster", t1)
	pt("rail_update", t0)


func _dev_tick() -> void :
	var t_lv: int = Time.get_ticks_usec()
	var up: Array = []
	var enterprises: Dictionary = {}
	for f: Facility in gw.mil.facilities:
		if Economy.is_enterprise(f.kind) and gw.mil.alive(f):
			enterprises[f.country_id] = int(enterprises.get(f.country_id, 0)) + 1
	for c: Country in gw.countries:
		if c.eliminated:
			continue
		var ent: int = int(enterprises.get(c.id, 0))
		var pts: int = c.earned + ENT_POINTS * ent
		dev_pts[c.id] = pts
		var lvl: int = 0
		for k in DEV_LEVELS.size():
			if pts >= int(DEV_LEVELS[k]):
				lvl = k
		lvl = maxi(lvl, test_dev_floor)
		var old: int = int(dev_level.get(c.id, 0))
		if lvl > old:
			dev_level[c.id] = lvl
			up.append([c, lvl])
	for u: Array in up:
		var c: Country = u[0]
		var lvl: int = u[1]
		if c.is_player:
			gw.say(c, Loc.mk("Развитие %d: %s", [lvl, level_unlocks(lvl)]))
		if lvl >= 3:
			gw.news_m(Loc.mk("%s: ЭКОНОМИКА НА ПОДЪЁМЕ — %s", [Loc.name(c.name).to_upper(), Loc.mk(String(DEV_NAMES[lvl]))]), "amber")
	pt("dev_levels", t_lv)

	var n: int = gw.countries.size()
	for k in n:
		var c2: Country = gw.countries[(_rr + k) % n]
		if c2.eliminated or level_of(c2.id) < 1:
			continue
		var tb: int = Time.get_ticks_usec()
		if _build_for(c2):
			pt("rail_build", tb)
			_rr = (_rr + k + 1) % n
			return
	var tu: int = Time.get_ticks_usec()
	urban.tick()
	pt("urban", tu)




func _build_for(c: Country) -> bool:
	if not _job.is_empty():
		return false
	var dom_busy: bool = building_n(c.id, 0) >= build_cap(c.id)
	var lvl: int = level_of(c.id)
	if c.capital_id < 0:
		return false
	var cap: City = gw.cities[c.capital_id]
	if cap.country_id != c.id:
		return false

	var want: Array[City] = []
	for cid in c.city_ids:
		var ct: City = gw.cities[cid]
		if ct.kind == City.Kind.VILLAGE and lvl < 3:
			continue
		want.append(ct)



	var linked: Array[City] = []
	for ct: City in want:
		if _own_linked(ct):
			linked.append(ct)
	if linked.is_empty():
		linked.append(cap)
	var limit: int = 2 if lvl == 1 else 999
	var on_net: int = 0
	for ct: City in want:
		if _own_linked(ct):
			on_net += 1
	if on_net < limit and not dom_busy:


		var prio: Dictionary = _prio_towns(c, want)
		var best: City = null
		var best_from: City = null
		var bd: float = INF
		for ct: City in want:
			if ct == cap and linked.size() == 1 and linked[0] == cap and not _own_linked(cap):
				continue
			if _own_linked(ct):
				continue
			for lc: City in linked:
				if lc == ct or _failed(lc.id, ct.id):
					continue
				var d: float = Vector2(ct.center).distance_to(Vector2(lc.center))
				var sc: float = d * (PRIO_K if prio.has(ct.id) else 1.0)
				if sc < bd and d <= MAX_LINK:
					bd = sc
					best = ct
					best_from = lc
		if best != null:
			if not _link(best_from, best, true):
				_fail["%d:%d" % [mini(best_from.id, best.id), maxi(best_from.id, best.id)]] = gw.game_time + FAIL_COOLDOWN
			return true
	if lvl >= 4 and not dom_busy:

		for ct2: City in want:
			if ct2.kind == City.Kind.VILLAGE or not city_linked(ct2.id):
				continue
			var sid2: int = int(city_station[ct2.id])
			var near: Array = []
			for o2: City in want:
				if o2 != ct2 and city_linked(o2.id) and not _failed(ct2.id, o2.id):
					near.append([Vector2(ct2.center).distance_to(Vector2(o2.center)), o2.id])
			near.sort()
			if near.size() < 2 or float(near[1][0]) > MAX_LINK * 0.8:
				continue
			var o3: City = gw.cities[int(near[1][1])]
			var sid3: int = int(city_station[o3.id])
			if _route_len(sid2, sid3) < float(near[1][0]) * 4.0 * 2.2:
				continue
			if not _link(ct2, o3, true):
				_fail["%d:%d" % [mini(ct2.id, o3.id), maxi(ct2.id, o3.id)]] = gw.game_time + FAIL_COOLDOWN * 4.0
			return true
	if lvl >= 2 and building_n(c.id, 1) == 0:

		for o: Country in gw.countries:
			if o == c or o.eliminated or o.id < c.id or level_of(o.id) < 2 or gw.diplo.at_war(c.id, o.id):
				continue
			if not _intl_ok(c.id, o.id) or building_n(o.id, 1) > 0:
				continue
			if _intl_exists(c.id, o.id):
				continue
			var pa: City = null
			var pb: City = null
			var bd2: float = INF
			for a: int in c.city_ids:
				if not city_linked(a):
					continue
				for b: int in o.city_ids:
					if not city_linked(b) or _failed(a, b):
						continue
					var d2: float = Vector2(gw.cities[a].center).distance_to(Vector2(gw.cities[b].center))
					if d2 < bd2:
						bd2 = d2
						pa = gw.cities[a]
						pb = gw.cities[b]
			if pa != null and bd2 <= MAX_LINK * INTL_K:
				if not _link(pa, pb, true):
					_fail["%d:%d" % [mini(pa.id, pb.id), maxi(pa.id, pb.id)]] = gw.game_time + FAIL_COOLDOWN * 4.0
				return true
	return false



func _own_linked(ct: City) -> bool:
	var sid: int = int(city_station.get(ct.id, -1))
	if sid < 0:
		return false
	for eid: int in adj.get(sid, []):
		var e: Dictionary = edges[eid]
		if bool(e["dead"]):
			continue
		var o: int = int(e["b"]) if int(e["a"]) == sid else int(e["a"])
		if _station_country(o) == ct.country_id:
			return true
	return false




func _prio_towns(c: Country, want: Array[City]) -> Dictionary:
	var out: Dictionary = {}
	var bar: Array[Vector2] = []
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.BARRACKS and f.country_id == c.id and gw.mil.alive(f):
			bar.append(Vector2(f.cell))
	var foe: Array[Vector2] = []
	for ct: City in gw.cities:
		if ct.country_id > 0 and ct.country_id != c.id and gw.diplo.at_war(c.id, ct.country_id):
			foe.append(Vector2(ct.center))
	for ct2: City in want:
		var p: = Vector2(ct2.center)
		for b: Vector2 in bar:
			if p.distance_to(b) <= PRIO_BARRACKS:
				out[ct2.id] = true
				break
		if out.has(ct2.id):
			continue
		for q: Vector2 in foe:
			if p.distance_to(q) <= PRIO_FRONT:
				out[ct2.id] = true
				break
	return out



func _route_len(sa: int, sb: int) -> float:
	var r: Array = _route(sa, sb, true)
	if r.is_empty():
		return INF
	var l: float = 0.0
	for k in r.size() - 1:
		l += float(edges[int(r[k][1])]["len"])
	return l


func _failed(a: int, b: int) -> bool:
	return float(_fail.get("%d:%d" % [mini(a, b), maxi(a, b)], -1.0)) > gw.game_time


func _intl_exists(ca: int, cb: int) -> bool:
	for e: Dictionary in edges:
		if bool(e["dead"]):
			continue
		var x: int = _station_country(int(e["a"]))
		var y: int = _station_country(int(e["b"]))
		if (x == ca and y == cb) or (x == cb and y == ca):
			return true
	return false


func _station_country(sid: int) -> int:
	var st: Dictionary = stations[sid]
	if st.has("man"):
		var sc: Vector2i = st["cell"]
		var o: int = gw.data.get_owner_id(sc.x, sc.y) if gw.data.inside(sc.x, sc.y) else 0
		if o > 0:
			return o
	return gw.cities[int(st["city"])].country_id



func _link(a: City, b: City, async: bool = false) -> bool:
	var sa: int = int(city_station.get(a.id, -1))
	var sb: int = int(city_station.get(b.id, -1))
	if sa >= 0 and sb >= 0:
		for eid: int in adj.get(sa, []):
			var e: Dictionary = edges[eid]
			if not bool(e["dead"]) and (int(e["a"]) == sb or int(e["b"]) == sb):
				return true
	var t0: int = Time.get_ticks_usec()
	var d: WorldData = gw.data

	var job: Dictionary = {"w": d.w, "h": d.h, "biome": d.biome.duplicate(), "flags": d.flags.duplicate(), "owners": d.owners.duplicate(), "mask": mask.duplicate(), 
		"allowed": [a.country_id, b.country_id], "a": a.id, "b": b.id, "sa": sa, "sb": sb, 
		"cell_a": stations[sa]["cell"] if sa >= 0 else Vector2i(-1, -1), "cell_b": stations[sb]["cell"] if sb >= 0 else Vector2i(-1, -1), 
		"city_a": [a.center, a.radius, a.country_id], "city_b": [b.center, b.radius, b.country_id], 
		"log": [], "pts": PackedVector2Array(), "data_id": d.get_instance_id(), "task": -1}
	pt("link_start", t0)
	if async:
		job["task"] = WorkerThreadPool.add_task(_line_worker.bind(job), false, "rail line")
		_job = job
		return true
	_line_worker(job)
	return _finish_line(job)



func _line_worker(job: Dictionary) -> void :
	var t0: int = Time.get_ticks_msec()
	var W: int = job["w"]
	for side: String in ["a", "b"]:
		if (job["cell_" + side] as Vector2i).x >= 0:
			continue
		var me: Array = job["city_" + side]
		var other: Array = job["city_" + ("b" if side == "a" else "a")]
		var spot: Vector2i = _station_spot(job, me[0], int(me[1]), int(me[2]), Vector2(other[0] - me[0]))
		if spot.x < 0:
			(job["log"] as Array).append("[Rail] no station spot near %s" % [me[0]])
			return
		job["cell_" + side] = spot

		var fl: PackedByteArray = job["flags"]
		for y in range(spot.y, spot.y + STATION_FD):
			for x in range(spot.x, spot.x + STATION_FW):
				fl[y * W + x] = fl[y * W + x] | WorldData.F_OCCUPIED
	var ca: Vector2i = job["cell_a"]
	var cb: Vector2i = job["cell_b"]
	job["p_sa"] = _station_p(ca)
	job["p_sb"] = _station_p(cb)
	job["pa"] = _track_end(ca, job["p_sb"])
	job["pb"] = _track_end(cb, job["p_sa"])
	var cells: Array[Vector2i] = _find_path(job)
	if cells.is_empty():
		return
	var raw: = PackedVector2Array()
	raw.append(job["p_sa"])
	for c: Vector2i in cells:
		raw.append(Vector2(c * GameWorld.CELL) + Vector2(2, 2))
	raw.append(job["p_sb"])
	var simp: PackedVector2Array = GameWorld.poly_simplify(raw, 3.0)
	var pts: PackedVector2Array = _resample(_chaikin(simp, 2), 1.0)
	if not _poly_clear(pts, job) or not _man_ok(pts, job):
		pts = _resample(GameWorld.poly_simplify(raw, 0.8), 1.0)
		if not _poly_clear(pts, job) or not _man_ok(pts, job):
			pts = _resample(raw, 1.0)
			if not _man_ok(pts, job):
				pts = PackedVector2Array()
	job["pts"] = pts
	job["ms"] = Time.get_ticks_msec() - t0



func _finish_line(job: Dictionary) -> bool:
	for line: String in job["log"]:
		print(line)
	var a: City = gw.cities[int(job["a"])]
	var b: City = gw.cities[int(job["b"])]
	var pts: PackedVector2Array = job["pts"]
	if int(job["data_id"]) != gw.data.get_instance_id():
		return false
	if pts.size() < 2:
		print("[Rail] no path %s -> %s" % [a.name, b.name])
		return false

	var sid: Array = [int(job["sa"]), int(job["sb"])]
	var live: Dictionary = _live()
	for k in 2:
		var city: City = a if k == 0 else b
		if sid[k] >= 0:
			continue
		if city_station.has(city.id):
			return false
		var cell: Vector2i = job["cell_a" if k == 0 else "cell_b"]
		if not _station_ok_in(live, cell, city.country_id):
			return false
	for k in 2:
		if sid[k] < 0:
			var city2: City = a if k == 0 else b
			sid[k] = _place_station(city2, job["cell_a" if k == 0 else "cell_b"])
	if not _poly_clear(pts, live):
		print("[Rail] line %s - %s blocked meanwhile" % [a.name, b.name])
		return false
	var e2: Dictionary = _make_edge(sid[0], sid[1], pts)
	if e2.is_empty():
		return false
	print("[Rail] line %s - %s: %d px, %d bridges, worker %d ms" % [a.name, b.name, int(e2["len"]), (e2["br"] as Array).size(), int(job.get("ms", 0))])
	var c: Country = gw.country_by_id(a.country_id)
	if build_instant:
		if c != null and c.is_player:
			gw.say(c, Loc.mk("Железная дорога: %s — %s", [Loc.name(a.name), Loc.name(b.name)]))
		return true

	e2["b0"] = gw.game_time
	e2["bt"] = build_time(float(e2["len"]))
	e2["bk"] = 0
	layer.mark_edge(int(e2["id"]))
	var cb: Country = gw.country_by_id(b.country_id)
	var txt: String = Loc.t("Стройка Ж/Д: %s — %s · ~%d мин") % [a.name, b.name, ceili(float(e2["bt"]) / 60.0)]
	if c != null and c.is_player:
		gw.say(c, txt)
	if cb != null and cb != c and cb.is_player:
		gw.say(cb, txt)
	return true



func _poll_job() -> void :
	if _job.is_empty() or not gw.job_ready(int(_job["task"])):
		return
	WorkerThreadPool.wait_for_task_completion(int(_job["task"]))
	var job: Dictionary = _job
	_job = {}
	var t0: int = Time.get_ticks_usec()
	if not _finish_line(job):
		var x: int = int(job["a"])
		var y: int = int(job["b"])
		var cd: float = FAIL_COOLDOWN * 8.0 if bool(job.get("water_gap", false)) else FAIL_COOLDOWN
		_fail["%d:%d" % [mini(x, y), maxi(x, y)]] = gw.game_time + cd
	pt("rail_apply", t0)


func drain() -> void :
	if not _job.is_empty():
		WorkerThreadPool.wait_for_task_completion(int(_job["task"]))
		_job = {}
	urban.drain()



func _ensure_station(city: City, toward: City) -> int:
	if city_station.has(city.id):
		return int(city_station[city.id])
	var best: Vector2i = _station_spot(_live(), city.center, city.radius, city.country_id, Vector2(toward.center - city.center))
	if best.x < 0:
		return -1
	return _place_station(city, best)



func _live() -> Dictionary:
	var d: WorldData = gw.data
	return {"w": d.w, "h": d.h, "biome": d.biome, "flags": d.flags, "owners": d.owners, "mask": mask}



static func _station_spot(arr: Dictionary, center: Vector2i, radius: int, country_id: int, toward: Vector2) -> Vector2i:
	var dir: Vector2 = toward.normalized()
	var best: = Vector2i(-1, -1)
	var bs: float = INF
	for r in range(radius + 2, radius + 16, 2):
		for a in range(0, 360, 12):
			var v: = Vector2.from_angle(deg_to_rad(a))
			var c: Vector2i = center + Vector2i(roundi(v.x * r), roundi(v.y * r)) - Vector2i(STATION_FW / 2, 1)
			var score: float = float(r) * 1.0 - v.dot(dir) * 14.0
			if score >= bs or not _station_ok_in(arr, c, country_id):
				continue
			bs = score
			best = c
		if best.x >= 0 and r > radius + 6:
			break
	return best


func _place_station(city: City, best: Vector2i, man: bool = false) -> int:
	var d: WorldData = gw.data
	var obj: int = gw.add_object(STATION_SPRITE, best, GameWorld.KIND_BUILDING) if gw.spr_index.has(STATION_SPRITE) else -1
	ArchStyle.mark(gw, obj, city.country_id)
	for y in range(best.y, best.y + STATION_FD):
		for x in range(best.x, best.x + STATION_FW):
			d.add_flag(x, y, WorldData.F_OCCUPIED)
			gw.remove_tree_at(Vector2i(x, y))
			d.set_biome(x, y, Biome.PLAZA)
	var sid: int = stations.size()
	var ty: int = best.y + STATION_FD
	var p: Vector2 = _station_p(best)

	var stub: = PackedVector2Array()
	for x in range((best.x - 2) * GameWorld.CELL, (best.x + STATION_FW + 2) * GameWorld.CELL + 1):
		stub.append(Vector2(x, p.y))
	for x in range(best.x - 2, best.x + STATION_FW + 2):
		_mark(Vector2i(x, ty), 1)
		gw.remove_tree_at(Vector2i(x, ty))
	stations.append({"id": sid, "city": city.id, "cell": best, "p": p, "obj": obj, "ruin_t": -1.0, "stub": stub, "row": ty})
	if man:
		var mst: Dictionary = stations[sid]
		mst["man"] = true
		mst["b0"] = gw.game_time
		mst["bt"] = MAN_ST_TIME
		if obj >= 0:
			gw.obj_state[obj] = 1
			gw._mark_obj_chunk(obj)
	else:
		city_station[city.id] = sid
	adj[sid] = []
	layer.add_item({"type": 1, "s": stub, "n": _normals(stub), "sid": sid})
	return sid


static func _station_p(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + STATION_FW * 0.5) * GameWorld.CELL, (cell.y + STATION_FD) * GameWorld.CELL + 2)


static func _track_end(cell: Vector2i, toward: Vector2) -> Vector2i:
	var row: int = cell.y + STATION_FD
	return Vector2i(cell.x - 2, row) if toward.x < _station_p(cell).x else Vector2i(cell.x + STATION_FW + 1, row)


static func _station_ok_in(arr: Dictionary, c: Vector2i, country_id: int) -> bool:
	var W: int = arr["w"]
	var H: int = arr["h"]
	var biome: PackedByteArray = arr["biome"]
	var flags: PackedByteArray = arr["flags"]
	var owners: PackedByteArray = arr["owners"]
	var msk: PackedByteArray = arr["mask"]
	if c.x - 3 < 0 or c.y - 1 < 0 or c.x + STATION_FW + 3 > W or c.y + STATION_FD + 2 > H:
		return false
	for y in range(c.y - 1, c.y + STATION_FD + 2):
		for x in range(c.x - 3, c.x + STATION_FW + 3):
			var i: int = y * W + x
			if owners[i] != country_id or biome[i] <= Biome.RIVER:
				return false
			var inner: bool = y >= c.y and y <= c.y + STATION_FD and x >= c.x - 2 and x < c.x + STATION_FW + 2
			if inner and ((flags[i] & (WorldData.F_OCCUPIED | WorldData.F_CITY | WorldData.F_BRIDGE)) != 0 or msk[i] != 0):
				return false
			if inner and (biome[i] == Biome.ROCK or biome[i] == Biome.SNOW):
				return false
			if inner and y < c.y + STATION_FD and x >= c.x and x < c.x + STATION_FW and (flags[i] & WorldData.F_ROAD) != 0:
				return false
	return true




func _find_path(job: Dictionary) -> Array[Vector2i]:
	var a: Vector2i = job["pa"]
	var b: Vector2i = job["pb"]
	var allowed: Array = job["allowed"]
	var W: int = job["w"]
	var H: int = job["h"]
	var biome: PackedByteArray = job["biome"]
	var flags: PackedByteArray = job["flags"]
	var owners: PackedByteArray = job["owners"]
	var msk: PackedByteArray = job["mask"]
	var strict: int = int(job.get("strict", 0))
	var blk: Rect2i = job.get("block", Rect2i())
	var out: Array[Vector2i] = []
	if biome.size() != W * H or flags.size() != W * H or owners.size() != W * H or msk.size() != W * H:
		(job["log"] as Array).append("[Rail] snapshot size mismatch %d %d %d %d (%dx%d)" % [biome.size(), flags.size(), owners.size(), msk.size(), W, H])
		return out
	for margin: int in [30, 90]:
		var x0: int = maxi(1, mini(a.x, b.x) - margin)
		var y0: int = maxi(1, mini(a.y, b.y) - margin)
		var x1: int = mini(W - 2, maxi(a.x, b.x) + margin)
		var y1: int = mini(H - 2, maxi(a.y, b.y) + margin)
		var astar: = AStarGrid2D.new()
		astar.region = Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		astar.update()
		for y in range(y0, y1 + 1):
			var row: int = y * W
			for x in range(x0, x1 + 1):
				var i: int = row + x
				var fl: int = flags[i]
				var cost: float = _rail_cost(biome[i])
				if msk[i] != 0:
					cost = 1.0
				elif (fl & WorldData.F_OCCUPIED) != 0 or cost < 0.0:
					astar.set_point_solid(Vector2i(x, y), true)
					continue
				elif (fl & WorldData.F_CITY) != 0:
					cost = 90.0
				elif (fl & WorldData.F_BRIDGE) != 0:
					cost = 60.0
				elif (fl & WorldData.F_ROAD) != 0:
					cost = 5.0
				var o: int = owners[i]
				if strict > 0 and ((o != strict and biome[i] > Biome.RIVER) or (o != 0 and o != strict)):
					astar.set_point_solid(Vector2i(x, y), true)
					continue
				if blk.has_point(Vector2i(x, y)):
					astar.set_point_solid(Vector2i(x, y), true)
					continue
				if o != 0 and not allowed.has(o):
					cost += 8.0
				astar.set_point_weight_scale(Vector2i(x, y), cost)
		astar.set_point_solid(a, false)
		astar.set_point_solid(b, false)
		out = astar.get_id_path(a, b)
		if out.is_empty():
			continue

		var run: int = 0
		var longest: int = 0
		for p: Vector2i in out:
			if biome[p.y * W + p.x] <= Biome.RIVER:
				run += 1
				longest = maxi(longest, run)
			else:
				run = 0
		if longest > GameWorld.MAX_SEA_BRIDGE:
			job["water_gap"] = true
			(job["log"] as Array).append("[Rail] water gap %d cells: no line" % longest)
			out.clear()
		return out
	return out


static func _rail_cost(b: int) -> float:
	match b:
		Biome.GRASS, Biome.FIELD, Biome.STEPPE, Biome.SAND, Biome.BURNT, Biome.CRATER, Biome.ROAD:
			return 1.0
		Biome.FOREST, Biome.PINE:
			return 1.8
		Biome.HILLS:
			return 3.5
		Biome.ROCK:
			return 8.0
		Biome.SNOW:
			return 10.0
		Biome.YARD, Biome.PLAZA, Biome.GARDEN, Biome.INDUSTRIAL, Biome.STREET:
			return 12.0
		Biome.RIVER:
			return 9.0
		Biome.SHALLOW, Biome.COAST:
			return 14.0
		Biome.OCEAN, Biome.DEEP:
			return 20.0
	return -1.0



func _make_edge(sa: int, sb: int, pts: PackedVector2Array) -> Dictionary:
	var d: WorldData = gw.data
	var eid: int = edges.size()
	var w: = PackedByteArray()
	w.resize(pts.size())
	var cell_set: Dictionary = {}
	var cell_list: = PackedInt32Array()
	for k in pts.size():
		var c: = Vector2i(floori(pts[k].x / GameWorld.CELL), floori(pts[k].y / GameWorld.CELL))
		if not d.inside(c.x, c.y):
			continue
		var i: int = c.y * d.w + c.x
		if Biome.is_water(d.biome[i]):
			w[k] = 1
		if not cell_set.has(i):
			cell_set[i] = true
			cell_list.append(i)

	var br: Array = []
	var k0: int = -1
	for k in pts.size() + 1:
		var wet: bool = k < pts.size() and w[k] == 1
		if wet and k0 < 0:
			k0 = k
		elif not wet and k0 >= 0:
			var bcells: Array[Vector2i] = []
			var seen: Dictionary = {}
			for j in range(k0, k):
				var c2: = Vector2i(floori(pts[j].x / GameWorld.CELL), floori(pts[j].y / GameWorld.CELL))
				if not seen.has(c2):
					seen[c2] = true
					bcells.append(c2)
			var b: = Bridge.new()
			b.id = gw.bridges.size()
			b.kind = Bridge.Kind.RAIL
			b.cells = bcells
			b.dirs.resize(bcells.size())
			b.pts = pts.slice(maxi(0, k0 - 2), mini(pts.size(), k + 2))
			gw.bridges.append(b)
			br.append([b, float(k0) - 3.0, float(k) + 3.0])
			k0 = -1
	var e: Dictionary = {"id": eid, "a": sa, "b": sb, "s": pts, "n": _normals(pts), "w": w, "len": float(pts.size() - 1), 
		"cells": cell_list, "br": br, "cuts": [], "dead": false}
	edges.append(e)
	(adj[sa] as Array).append(eid)
	(adj[sb] as Array).append(eid)
	var cleared: Dictionary = {}
	for i: int in cell_list:
		mask[i] = mini(255, mask[i] + 1)
		var c3: = Vector2i(i % d.w, i / d.w)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var q: = c3 + Vector2i(dx, dy)
				var qi: int = q.y * d.w + q.x
				if not cleared.has(qi):
					cleared[qi] = true
					gw.remove_tree_at(q)
	layer.add_item({"type": 0, "s": pts, "n": e["n"], "w": w, "edge": eid})
	return e


func _poly_clear(pts: PackedVector2Array, job: Dictionary) -> bool:
	var W: int = job["w"]
	var H: int = job["h"]
	var flags: PackedByteArray = job["flags"]
	var msk: PackedByteArray = job["mask"]
	for k in range(0, pts.size(), 2):
		var c: = Vector2i(floori(pts[k].x / GameWorld.CELL), floori(pts[k].y / GameWorld.CELL))
		if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
			return false
		var i: int = c.y * W + c.x
		if (flags[i] & WorldData.F_OCCUPIED) != 0 and msk[i] == 0:
			return false
	return true


func _mark(c: Vector2i, v: int) -> void :
	if gw.data.inside(c.x, c.y):
		var i: int = c.y * gw.data.w + c.x
		mask[i] = clampi(mask[i] + v, 0, 255)


static func _chaikin(p: PackedVector2Array, iters: int) -> PackedVector2Array:
	var cur: PackedVector2Array = p
	for it in iters:
		if cur.size() < 3:
			return cur
		var nx: = PackedVector2Array()
		nx.append(cur[0])
		for i in cur.size() - 1:
			var a: Vector2 = cur[i]
			var b: Vector2 = cur[i + 1]
			if i > 0:
				nx.append(a.lerp(b, 0.25))
			if i < cur.size() - 2:
				nx.append(a.lerp(b, 0.75))
		nx.append(cur[cur.size() - 1])
		cur = nx
	return cur



static func _resample(p: PackedVector2Array, step: float) -> PackedVector2Array:
	var out: = PackedVector2Array()
	if p.is_empty():
		return out
	out.append(p[0])
	var carry: float = 0.0
	for i in p.size() - 1:
		var a: Vector2 = p[i]
		var b: Vector2 = p[i + 1]
		var seg: float = a.distance_to(b)
		if seg <= 0.0001:
			continue
		var t: float = step - carry
		while t <= seg:
			out.append(a.lerp(b, t / seg))
			t += step
		carry = seg - (t - step)
	if out[out.size() - 1].distance_to(p[p.size() - 1]) > step * 0.3:
		out.append(p[p.size() - 1])
	return out


static func _normals(p: PackedVector2Array) -> PackedVector2Array:
	var n: = PackedVector2Array()
	n.resize(p.size())
	for k in p.size():
		var a: Vector2 = p[maxi(0, k - 2)]
		var b: Vector2 = p[mini(p.size() - 1, k + 2)]
		var t: Vector2 = (b - a).normalized()
		n[k] = Vector2( - t.y, t.x)
	return n


func _remove_edge(eid: int) -> void :
	var e: Dictionary = edges[eid]
	if bool(e["dead"]):
		return
	e["dead"] = true
	for i: int in e["cells"]:
		mask[i] = maxi(0, mask[i] - 1)
	for bb: Array in e["br"]:
		var b: Bridge = bb[0]
		b.state = Bridge.State.INTACT
		b.cells = []
	for sid: int in [int(e["a"]), int(e["b"])]:
		(adj[sid] as Array).erase(eid)
	layer.remove_edge_items(eid)
	for k in range(trains.size() - 1, -1, -1):
		for m: Array in trains[k]["marks"]:
			if int(m[1]) == eid:


				if String(trains[k].get("res", "")) != "" and not trains[k].has("ride") and (_to_truck(trains[k]) or _cargo_home(trains[k])):
					trains.remove_at(k)
					break
				_lose(trains[k])
				trains.remove_at(k)
				break



func _cargo_home(tr: Dictionary) -> bool:
	var job: Dictionary = tr.get("job", {})
	var e: Economy = gw.econ
	var k: int = -1
	for i in e.rail_jobs.size():
		if is_same(e.rail_jobs[i], job):
			k = i
			break
	if k < 0:
		return false
	e.rail_jobs.remove_at(k)
	e.refund(job, false)
	var s: Country = gw.country_by_id(int(job.get("from", 0)))
	var res: String = String(job.get("res", ""))
	var n: int = int(job.get("n", 0))
	if s != null and n > 0 and Economy.TRADE_RES.has(res):
		s.set(res, int(s.get(res)) + n)
		e.stat_res(s, res, "trade", n)
	stats["cargo_home"] = int(stats.get("cargo_home", 0)) + n
	var r: Country = gw.country_by_id(int(job.get("to", 0)))
	if (s != null and s.is_player) or (r != null and r.is_player):
		gw.say2(s, r, Loc.mk("Ж/Д перекладывается: груз (%s %d) вернулся отправителю, деньги возвращены", [Loc.t(String(Economy.RES_NAMES.get(res, res)).to_lower()), n]))
	return true









func reroute_around(rect: Rect2i, apply: bool = true) -> bool:
	var d: WorldData = gw.data
	var C: float = float(GameWorld.CELL)
	var W: int = d.w
	var zone: Rect2i = rect.grow(1)
	var lead: int = 16
	var plans: Array = []
	var fp_idx: = PackedInt32Array()
	for y in range(maxi(0, rect.position.y), mini(d.h, rect.end.y)):
		for x in range(maxi(0, rect.position.x), mini(W, rect.end.x)):
			fp_idx.append(y * W + x)
	for e: Dictionary in edges:
		if bool(e["dead"]):
			continue
		var on_cells: bool = false
		for fi: int in fp_idx:
			if (e["cells"] as PackedInt32Array).has(fi):
				on_cells = true
				break
		if not on_cells:
			continue
		var s: PackedVector2Array = e["s"]
		var n: int = s.size()
		var k_in: int = -1
		var k_out: int = -1
		var on_fp: bool = false
		for k in n:
			var c: = Vector2i(floori(s[k].x / C), floori(s[k].y / C))
			if zone.has_point(c):
				if k_in < 0:
					k_in = k
				k_out = k
				if rect.has_point(c):
					on_fp = true
		if not on_fp:
			continue


		var best: Array = []
		var best_cos: float = -2.0
		for lead_k: int in [lead, lead * 2, lead * 7 / 2]:
			var pl1: Array = _reroute_plan(e, s, k_in, k_out, lead_k, rect, zone)
			if pl1.is_empty():
				continue
			if best.is_empty() or float(pl1[3]) > best_cos + 0.05:
				best = pl1
				best_cos = float(pl1[3])
			if best_cos >= 0.75:
				break
		if best.is_empty():
			return false
		plans.append([e, best[0], best[1], best[2]])

	var cover: Dictionary = {}
	for pl0: Array in plans:
		for i0: int in (pl0[0] as Dictionary)["cells"]:
			cover[i0] = int(cover.get(i0, 0)) + 1
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if d.inside(x, y) and mask[y * W + x] > int(cover.get(y * W + x, 0)):
				return false
	if not apply or plans.is_empty():
		return true
	for pl: Array in plans:
		var e: Dictionary = pl[0]
		var ka: int = pl[1]
		var kb: int = pl[2]
		var piece: PackedVector2Array = pl[3]
		var eid: int = int(e["id"])
		var so: PackedVector2Array = e["s"]
		var span_old: float = float(kb - ka)
		var span_new: float = float(piece.size() - 1)
		var delta: int = piece.size() - (kb - ka + 1)
		var ns: PackedVector2Array = so.slice(0, ka)
		ns.append_array(piece)
		ns.append_array(so.slice(kb + 1))
		var wz: = PackedByteArray()
		wz.resize(piece.size())
		wz.fill(0)
		var nwf: PackedByteArray = (e["w"] as PackedByteArray).slice(0, ka)
		nwf.append_array(wz)
		nwf.append_array((e["w"] as PackedByteArray).slice(kb + 1))
		for i: int in e["cells"]:
			mask[i] = maxi(0, mask[i] - 1)
		var cell_set: Dictionary = {}
		var cell_list: = PackedInt32Array()
		for k in ns.size():
			var c: = Vector2i(floori(ns[k].x / C), floori(ns[k].y / C))
			if not d.inside(c.x, c.y):
				continue
			var i2: int = c.y * W + c.x
			if not cell_set.has(i2):
				cell_set[i2] = true
				cell_list.append(i2)
				mask[i2] = mini(255, mask[i2] + 1)
				if k >= ka and k < ka + piece.size():
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							if d.inside(c.x + dx, c.y + dy):
								gw.remove_tree_at(c + Vector2i(dx, dy))
		for ct: Array in e["cuts"]:
			var cs: float = float(ct[0])
			if cs > float(kb):
				ct[0] = cs + float(delta)
			elif cs >= float(ka):
				ct[0] = float(ka) + (cs - float(ka)) * span_new / maxf(1.0, span_old)
			ct[2] = ns[clampi(int(ct[0]), 0, ns.size() - 1)]
		for bb: Array in e["br"]:
			if float(bb[1]) > float(kb):
				bb[1] = float(bb[1]) + float(delta)
				bb[2] = float(bb[2]) + float(delta)
		var el_old: float = float(e["len"])
		e["s"] = ns
		e["n"] = _normals(ns)
		e["w"] = nwf
		e["len"] = float(ns.size() - 1)
		e["cells"] = cell_list

		for t in range(trains.size() - 1, -1, -1):
			var tr: Dictionary = trains[t]
			var ms: Array = []
			for m: Array in tr["marks"]:
				if int(m[1]) == eid:
					ms.append(m)
			if ms.is_empty():
				continue
			ms.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
			var pts: PackedVector2Array = tr["pts"]
			var st: float = float(tr["s"])
			var ok: bool = true
			for m: Array in ms:
				var r0: float = float(m[0])
				if r0 != floorf(r0) or absf(float(m[3]) - el_old) > 0.01:
					ok = false
					break
				var ra: int = int(r0) + (ka if bool(m[2]) else int(el_old) - kb)
				var rb: int = ra + (kb - ka)
				if ra < 0 or rb > pts.size() - 1:
					ok = false
					break
				var seg: PackedVector2Array = piece if bool(m[2]) else _reversed(piece)
				var p_old: Vector2 = pts[clampi(roundi(st), 0, pts.size() - 1)]
				var np: PackedVector2Array = pts.slice(0, ra)
				np.append_array(seg)
				np.append_array(pts.slice(rb + 1))
				pts = np
				if st > float(rb):
					st += float(delta)
				elif st >= float(ra):
					var bj: int = 0
					var bd: float = INF
					for j in seg.size():
						var dd: float = seg[j].distance_squared_to(p_old)
						if dd < bd:
							bd = dd
							bj = j
					st = float(ra + bj)
				for m2: Array in tr["marks"]:
					if float(m2[0]) > r0:
						m2[0] = float(m2[0]) + float(delta)
				m[3] = float(e["len"])
			if not ok:
				_lose(tr)
				trains.remove_at(t)
				continue
			tr["pts"] = pts
			tr["L"] = float(pts.size() - 1)
			tr["s"] = clampf(st, 0.0, float(tr["L"]))
		layer.remove_edge_items(eid)
		layer.add_item({"type": 0, "s": ns, "n": e["n"], "w": nwf, "edge": eid})
	return true




func _reroute_plan(e: Dictionary, s: PackedVector2Array, k_in: int, k_out: int, lead: int, rect: Rect2i, zone: Rect2i) -> Array:
	var d: WorldData = gw.data
	var C: float = float(GameWorld.CELL)
	var W: int = d.w
	var n: int = s.size()

	var k_lo: int = 0
	var k_hi: int = n - 1
	var sta: Dictionary = stations[int(e["a"])]
	var stb: Dictionary = stations[int(e["b"])]
	var r_a: Rect2i = Rect2i(sta["cell"], Vector2i(STATION_FW, STATION_FD)).grow(2)
	var r_b: Rect2i = Rect2i(stb["cell"], Vector2i(STATION_FW, STATION_FD)).grow(2)
	while k_lo < n - 1 and r_a.has_point(Vector2i(floori(s[k_lo].x / C), floori(s[k_lo].y / C))):
		k_lo += 1
	while k_hi > 0 and r_b.has_point(Vector2i(floori(s[k_hi].x / C), floori(s[k_hi].y / C))):
		k_hi -= 1
	var ka: int = maxi(k_lo, k_in - lead)
	var kb: int = mini(k_hi, k_out + lead)
	var ra: int = maxi(k_lo, ka - 8)
	var rb: int = mini(k_hi, kb + 8)
	if k_in - ka < 4 or kb - k_out < 4:
		return []
	var wf: PackedByteArray = e["w"]
	for k in range(ra, rb + 1):
		if wf[k] == 1:
			return []
	for bb: Array in e["br"]:
		if float(bb[1]) <= float(rb) and float(bb[2]) >= float(ra):
			return []
	var ca: = Vector2i(floori(s[ka].x / C), floori(s[ka].y / C))
	var cb: = Vector2i(floori(s[kb].x / C), floori(s[kb].y / C))
	var win: Rect2i = zone.merge(Rect2i(ca, Vector2i.ONE)).merge(Rect2i(cb, Vector2i.ONE)).grow(6).intersection(Rect2i(1, 1, W - 2, d.h - 2))
	var astar: = AStarGrid2D.new()
	astar.region = win
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	var fla: PackedByteArray = d.flags
	var bia: PackedByteArray = d.biome
	var mka: PackedByteArray = mask
	var blk: int = WorldData.F_OCCUPIED | WorldData.F_BRIDGE
	for y in range(win.position.y, win.end.y):
		var row: int = y * W
		for x in range(win.position.x, win.end.x):
			var i: int = row + x
			var fl: int = fla[i]
			var bi: int = bia[i]
			if bi <= Biome.RIVER or (fl & blk) != 0 or (x >= zone.position.x and x < zone.end.x and y >= zone.position.y and y < zone.end.y):
				astar.set_point_solid(Vector2i(x, y), true)
				continue
			var cost: float = _rail_cost(bi)
			if cost < 0.0:
				astar.set_point_solid(Vector2i(x, y), true)
				continue
			if (fl & WorldData.F_CITY) != 0 and mka[i] == 0:
				cost = 90.0
			elif (fl & WorldData.F_ROAD) != 0:
				cost = 5.0
			if cost != 1.0:
				astar.set_point_weight_scale(Vector2i(x, y), cost)
	if not win.has_point(ca) or not win.has_point(cb) or astar.is_point_solid(ca) or astar.is_point_solid(cb):
		return []
	var path: Array[Vector2i] = astar.get_id_path(ca, cb)
	if path.size() < 2 or path.size() > (kb - ka) / GameWorld.CELL + 40:
		return []
	var raw: = PackedVector2Array([s[ka]])
	for j in range(1, path.size() - 1):
		raw.append(Vector2(path[j] * GameWorld.CELL) + Vector2(2, 2))
	raw.append(s[kb])
	var fpx: = Rect2(Vector2(rect.position) * C, Vector2(rect.size) * C).grow(3.0)
	for eps: float in [8.0, 6.0, 4.0, 2.0, 0.0]:
		var ctrl: = PackedVector2Array([s[ra]])
		ctrl.append_array(GameWorld.poly_simplify(raw, eps) if eps > 0.0 else raw)
		ctrl.append(s[rb])
		var piece: PackedVector2Array = _resample(_chaikin(ctrl, 3) if eps > 0.0 else ctrl, 1.0)
		if piece.size() >= 3 and piece[piece.size() - 1].distance_to(piece[piece.size() - 2]) < 0.5:
			piece.remove_at(piece.size() - 2)
		var clear: bool = piece.size() >= 2
		for p: Vector2 in piece:
			var pc: = Vector2i(floori(p.x / C), floori(p.y / C))
			var pi: int = pc.y * W + pc.x
			if fpx.has_point(p) or not d.inside(pc.x, pc.y) or bia[pi] <= Biome.RIVER or ((fla[pi] & WorldData.F_OCCUPIED) != 0 and mka[pi] == 0):
				clear = false
				break
		if not clear:
			continue
		var tmp: PackedVector2Array = s.slice(maxi(0, ra - 8), ra)
		tmp.append_array(piece)
		tmp.append_array(s.slice(rb + 1, mini(n, rb + 9)))
		var worst: float = 1.0
		for k in range(4, tmp.size() - 4, 2):
			worst = minf(worst, (tmp[k] - tmp[k - 4]).normalized().dot((tmp[k + 4] - tmp[k]).normalized()))
		return [ra, rb, piece, worst]
	return []




func _edge_usable(e: Dictionary) -> bool:
	if bool(e["dead"]) or float(e.get("bt", 0.0)) > 0.0:
		return false
	var ca: int = _station_country(int(e["a"]))
	var cb: int = _station_country(int(e["b"]))
	return ca == cb or not gw.diplo.at_war(ca, cb)


func _edge_blocked(e: Dictionary) -> bool:
	for c: Array in e["cuts"]:
		if float(c[1]) > gw.game_time:
			return true
	for bb: Array in e["br"]:
		if not (bb[0] as Bridge).passable():
			return true
	return false



func _route(sa: int, sb: int, allow_damaged: bool) -> Array:
	var dist: Dictionary = {sa: 0.0}
	var prev: Dictionary = {}
	var open: Array = [sa]
	while not open.is_empty():
		var bi: int = 0
		for i in open.size():
			if float(dist[open[i]]) < float(dist[open[bi]]):
				bi = i
		var u: int = open[bi]
		open.remove_at(bi)
		if u == sb:
			break
		for eid: int in adj.get(u, []):
			var e: Dictionary = edges[eid]
			if not _edge_usable(e):
				continue
			var cost: float = float(e["len"])
			if _edge_blocked(e):
				if not allow_damaged:
					continue
				cost += 20000.0
			var v: int = int(e["b"]) if int(e["a"]) == u else int(e["a"])
			var nd: float = float(dist[u]) + cost
			if not dist.has(v) or nd < float(dist[v]):
				dist[v] = nd
				prev[v] = [u, eid]
				if not open.has(v):
					open.append(v)
	if not dist.has(sb) or sa == sb:
		return []
	var out: Array = []
	var cur: int = sb
	out.append([sb, -1])
	while cur != sa:
		var pv: Array = prev[cur]
		out.push_front([int(pv[0]), int(pv[1])])
		cur = int(pv[0])
	return out





func _spawn(route: Array, cars: PackedStringArray, cos: bool) -> Dictionary:
	var sa: int = int(route[0][0])
	var tr: Dictionary = {"id": _train_id, "cars": cars, "cosmetic": cos, "res": "", "n": 0, "from_city": -1, "to_city": -1, 
		"on_arrive": Callable(), "on_lost": Callable(), "v": 0.0, "wait": 0.0, "country": _station_country(sa), "horn": false}
	_train_id += 1
	tr["origin"] = sa
	_set_route(tr, route)
	tr["s"] = minf(float(cars.size()) * CAR_GAP, float(tr["L"]) * 0.5)
	trains.append(tr)
	Sfx.play("train_horn", (tr["pts"] as PackedVector2Array)[0], -4.0)
	return tr



func _set_route(tr: Dictionary, route: Array) -> void :
	var pts: = PackedVector2Array()
	var marks: Array = []
	for k in route.size() - 1:
		var st: int = int(route[k][0])
		var e: Dictionary = edges[int(route[k][1])]
		var fwd: bool = int(e["a"]) == st
		var s: PackedVector2Array = e["s"]
		var seg: PackedVector2Array = s if fwd else _reversed(s)
		marks.append([float(maxi(0, pts.size() - 1)), int(e["id"]), fwd, float(e["len"]), st])
		if not pts.is_empty():
			seg = seg.slice(1)
		pts.append_array(seg)
	tr["pts"] = pts
	tr["marks"] = marks
	tr["L"] = float(pts.size() - 1)
	tr["dest"] = int(route[route.size() - 1][0])


static func _reversed(p: PackedVector2Array) -> PackedVector2Array:
	var out: = PackedVector2Array()
	out.resize(p.size())
	var n: int = p.size()
	for i in n:
		out[i] = p[n - 1 - i]
	return out



func _block_ahead(tr: Dictionary, s: float) -> float:
	var best: float = INF
	for m: Array in tr["marks"]:
		var e: Dictionary = edges[int(m[1])]
		var r0: float = float(m[0])
		var fwd: bool = bool(m[2])
		var el: float = float(m[3])
		if r0 > s + 400.0:
			break
		if bool(e["dead"]):
			best = minf(best, maxf(r0, s))
			continue
		for c: Array in e["cuts"]:
			if float(c[1]) <= gw.game_time:
				continue
			var rd: float = r0 + (float(c[0]) if fwd else el - float(c[0])) - 6.0
			if rd >= s - 2.0:
				best = minf(best, rd)
		for bb: Array in e["br"]:
			var b: Bridge = bb[0]
			if b.passable():
				continue
			var lo: float = float(bb[1]) if fwd else el - float(bb[2])
			var rd2: float = r0 + lo - 4.0
			if rd2 >= s - 2.0:
				best = minf(best, rd2)
	return best


func _move_trains(dt: float) -> void :
	if trains.is_empty():
		Sfx.loop("train", "", false)
		return
	var lp: Vector2 = Sfx.listener()
	var near: Vector2 = Vector2.INF
	var nd: float = INF
	for k in range(trains.size() - 1, -1, -1):
		var tr: Dictionary = trains[k]

		var ca: int = _station_country(int(tr["origin"]))
		var cb: int = _station_country(int(tr["dest"]))
		if ca != cb and gw.diplo.at_war(ca, cb):
			_lose(tr)
			trains.remove_at(k)
			continue
		if float(tr.get("hold", 0.0)) > 0.0:
			tr["hold"] = float(tr["hold"]) - dt
			continue
		var s: float = tr["s"]
		var L: float = tr["L"]
		var stop_at: float = minf(L, _block_ahead(tr, s))
		var v: float = tr["v"]
		var room: float = stop_at - s
		var vmax: float = TRAIN_SPEED
		if room < 30.0:
			vmax = maxf(0.0, TRAIN_SPEED * room / 30.0)
		v = minf(vmax, v + TRAIN_ACC * dt) if v < vmax else vmax
		s = minf(s + v * dt, maxf(s, stop_at))
		tr["v"] = v
		tr["s"] = s
		if s >= L - 0.5:
			_arrive(tr)
			trains.remove_at(k)
			continue
		if v < 0.5 and stop_at < L:
			tr["wait"] = float(tr["wait"]) + dt
			tr["stuck"] = float(tr.get("stuck", 0.0)) + dt
			if float(tr["wait"]) > 4.0:
				tr["wait"] = 0.0
				_try_reroute(tr)
			if tr.has("ride") and float(tr["stuck"]) >= RailTroops.WAIT_MAX:
				troops.on_stuck(tr)
				trains.remove_at(k)
				continue
			if String(tr.get("res", "")) != "" and float(tr["stuck"]) >= STUCK_TRUCK and float(tr["stuck"]) - float(tr.get("truck_t", 0.0)) >= TRUCK_RETRY:
				tr["truck_t"] = float(tr["stuck"])
				if _to_truck(tr):
					trains.remove_at(k)
					continue
		else:
			tr["wait"] = 0.0
			tr["stuck"] = 0.0
		if v > 1.0 and lp.is_finite():
			var hp: Vector2 = pos_at(tr, s)
			var dd: float = hp.distance_squared_to(lp)
			if dd < nd:
				nd = dd
				near = hp
	Sfx.loop("train", "train_roll_loop", near.is_finite(), near)



func _try_reroute(tr: Dictionary) -> void :
	var marks: Array = tr["marks"]
	var s: float = tr["s"]
	var k: int = 0
	for i in marks.size():
		if float(marks[i][0]) <= s:
			k = i
	var mk: Array = marks[k]
	if float(mk[0]) < 0.0:
		return
	var last_st: int = int(mk[4])
	var alt: Array = _route(last_st, int(tr["dest"]), false)
	if alt.size() < 2 or int(alt[0][1]) == int(mk[1]):
		return
	var r0: float = float(mk[0])
	var old: PackedVector2Array = tr["pts"]
	var piece: PackedVector2Array = _reversed(old.slice(int(r0), int(s) + 1))
	var tail: float = maxf(r0, s - float((tr["cars"] as PackedStringArray).size()) * CAR_GAP)
	_set_route(tr, alt)
	var np: PackedVector2Array = piece.duplicate()
	var rest: PackedVector2Array = tr["pts"]
	np.append_array(rest.slice(1))
	var shift: float = float(piece.size() - 1)
	for m: Array in tr["marks"]:
		m[0] = float(m[0]) + shift

	var el: float = float(mk[3])
	var pos_old: float = s - r0
	var local: float = pos_old if bool(mk[2]) else el - pos_old
	var fwd_new: bool = not bool(mk[2])
	(tr["marks"] as Array).push_front([ - (local if fwd_new else el - local), int(mk[1]), fwd_new, el, last_st])
	tr["pts"] = np
	tr["L"] = float(np.size() - 1)
	tr["s"] = s - tail
	tr["v"] = 0.0


func pos_at(tr: Dictionary, d: float) -> Vector2:
	var pts: PackedVector2Array = tr["pts"]
	var n: int = pts.size()
	if n == 0:
		return Vector2.ZERO
	var dd: float = clampf(d, 0.0, float(n - 1))
	var i: int = mini(int(dd), n - 2)
	if i < 0:
		return pts[0]
	return pts[i].lerp(pts[i + 1], dd - float(i))


func _arrive(tr: Dictionary) -> void :
	if tr.has("ride"):
		troops.on_arrive(tr)
	if String(tr.get("res", "")) != "" and not bool(tr.get("cosmetic", true)):
		stats["cargo_arrived"] = int(stats.get("cargo_arrived", 0)) + int(tr.get("n", 0))
	var cb: Callable = tr["on_arrive"]
	if cb.is_valid():
		cb.call()
	var p: Vector2 = pos_at(tr, float(tr["L"]))
	if not bool(tr["cosmetic"]):
		Sfx.play("train_horn", p, -8.0)


func _lose(tr: Dictionary) -> void :
	if tr.has("ride"):
		troops.on_lost(tr)
	if String(tr.get("res", "")) != "" and not bool(tr.get("cosmetic", true)):
		stats["cargo_lost"] = int(stats.get("cargo_lost", 0)) + int(tr.get("n", 0))
	var cb: Callable = tr["on_lost"]
	if cb.is_valid():
		cb.call()


func _drop_cosmetic() -> bool:
	for k in range(trains.size() - 1, -1, -1):
		if bool(trains[k]["cosmetic"]):
			trains.remove_at(k)
			return true
	return false



func _cosmetic_tick() -> void :
	if not cosmetic or trains.size() >= MAX_TRAINS - 4:
		return
	var per: Dictionary = {}
	for tr: Dictionary in trains:
		if bool(tr["cosmetic"]):
			per[int(tr["country"])] = int(per.get(int(tr["country"]), 0)) + 1
	for c: Country in gw.countries:
		if c.eliminated or int(per.get(c.id, 0)) >= mini(COSMETIC_PER_COUNTRY, maxi(1, level_of(c.id) - 1)):
			continue
		var own: Array = []
		for st: Dictionary in stations:
			if _station_country(int(st["id"])) == c.id and not (adj.get(int(st["id"]), []) as Array).is_empty() and float(st["ruin_t"]) < 0.0 and float(st.get("bt", 0.0)) <= 0.0:
				own.append(int(st["id"]))
		if own.size() < 2:
			continue
		var h: int = Hash32.h2(c.id, int(gw.game_time), 913)
		var a: int = own[h % own.size()]
		var b: int = own[(h / 7 + 1 + (h % (own.size() - 1))) % own.size()]
		if a == b:
			continue
		var route: Array = _route(a, b, false)
		if route.is_empty():
			continue
		var cars: = PackedStringArray(["rail_loco"])
		var pas: bool = (h >> 9) % 2 == 0
		var wn: int = 3 + (h >> 11) % 3
		var mix: Array = ["rail_wagon_box", "rail_wagon_tank", "rail_wagon_open", "rail_wagon_wood"]
		for i in wn:
			cars.append("rail_wagon_pass" if pas else String(mix[(h >> (13 + i)) % mix.size()]))
		_spawn(route, cars, true)
		return





func on_strike(cell: Vector2i, r: int, by: int = 0) -> void :
	var p: = Vector2(cell * GameWorld.CELL) + Vector2(2, 2)
	var rp: float = float(r * GameWorld.CELL) + 5.0
	for k in range(trains.size() - 1, -1, -1):
		var tr: Dictionary = trains[k]
		var hit: bool = false
		var cars: PackedStringArray = tr["cars"]
		for ci in cars.size():
			var cp: Vector2 = pos_at(tr, float(tr["s"]) - float(ci) * CAR_GAP)
			if cp.distance_to(p) <= rp:
				hit = true
				gw.fx.spawn("explosion_s", cp.round(), 6)
				gw.fx.debris_burst(cp.round(), 3, false)
		if hit:
			for ci2 in cars.size():
				if ci2 % 2 == 0:
					var cp2: Vector2 = pos_at(tr, float(tr["s"]) - float(ci2) * CAR_GAP)
					gw.fx.spawn("fire_small", cp2.round() + Vector2(0, -1), 3, gw.game_time + 12.0, true)
			if not bool(tr["cosmetic"]):
				var own: Country = gw.country_by_id(int(tr["country"]))
				if own != null and own.is_player and not tr.has("ride"):
					gw.say(own, Loc.mk("Поезд уничтожен — груз потерян"))
			if tr.has("ride"):
				troops.on_hit(tr, p, rp, by)
				tr.erase("ride")
			_lose(tr)
			trains.remove_at(k)
	var d: WorldData = gw.data
	var any: bool = false
	for e: Dictionary in edges:
		if bool(e["dead"]):
			continue
		var s: PackedVector2Array = e["s"]
		var best: int = -1
		var bd: float = rp * rp
		for i in range(0, s.size(), 2):
			var dd: float = s[i].distance_squared_to(p)
			if dd < bd:
				bd = dd
				best = i
		if best < 0:
			continue
		if float(e.get("bt", 0.0)) > 0.0 and float(best) > built_frac(e) * float(s.size() - 1):
			e["b0"] = float(e.get("b0", 0.0)) + BUILD_DELAY
			continue
		if (e["w"] as PackedByteArray)[best] == 1:
			continue
		var dup: bool = false
		for c: Array in e["cuts"]:
			if absf(float(c[0]) - float(best)) < 10.0 and float(c[1]) > gw.game_time:
				c[1] = gw.game_time + CUT_REPAIR
				dup = true
		if not dup:
			(e["cuts"] as Array).append([float(best), gw.game_time + CUT_REPAIR, s[best]])
		any = true
	if any:
		layer.mark_rect(Rect2(p - Vector2(rp + 8, rp + 8), Vector2(rp * 2 + 16, rp * 2 + 16)))
		var o: int = d.get_owner_id(cell.x, cell.y) if d.inside(cell.x, cell.y) else 0
		if gw.player != null and o == gw.player.id:
			gw.message.emit(Loc.msg(Loc.mk("Ж/Д путь повреждён — ремонт %d с", [int(CUT_REPAIR)])))


func _repair_tick() -> void :
	var t: float = gw.game_time
	_build_tick()
	for e: Dictionary in edges:
		var cuts: Array = e["cuts"]
		for k in range(cuts.size() - 1, -1, -1):
			var c: Array = cuts[k]
			if float(c[1]) <= t:
				var p: Vector2 = c[2]
				gw.fx.spawn("build_spark", p, 6)
				cuts.remove_at(k)
				layer.mark_rect(Rect2(p - Vector2(12, 12), Vector2(24, 24)))
			elif float(c[1]) - t < CUT_REPAIR - 3.0 and Hash32.h2(int(t), int(c[0]), 3) % 3 == 0:
				gw.fx.spawn("build_spark", (c[2] as Vector2) + Vector2(randi_range(-2, 2), randi_range(-2, 2)), 6)

	for st: Dictionary in stations:
		if float(st.get("bt", 0.0)) > 0.0:
			if t >= float(st.get("b0", 0.0)) + float(st["bt"]):
				_station_done(st)
			continue
		var obj: int = st["obj"]
		if obj < 0:
			continue
		if gw.obj_state[obj] == 1:
			if float(st["ruin_t"]) < 0.0:
				st["ruin_t"] = t
			elif t - float(st["ruin_t"]) >= STATION_REPAIR:
				var c: Country = gw.country_by_id(_station_country(int(st["id"])))
				if c != null and c.money >= 60:
					c.money -= 60
					gw.obj_state[obj] = 0
					gw._mark_obj_chunk(obj)
					gw.fx.spawn("build_spark", gw.obj_origin(obj) + Vector2(10, 4), 6)
					st["ruin_t"] = -1.0
		elif float(st["ruin_t"]) >= 0.0:
			st["ruin_t"] = -1.0

	var d: WorldData = gw.data
	for e2: Dictionary in edges:
		if bool(e2["dead"]):
			continue
		var cells: PackedInt32Array = e2["cells"]
		var step: int = 3
		for k2 in range(0, cells.size(), step):
			var i: int = cells[k2]
			if (d.flags[i] & WorldData.F_OCCUPIED) != 0 and not _station_cell(i):
				print("[Rail] line %d blocked by a building - relaying" % int(e2["id"]))
				_remove_edge(int(e2["id"]))


				var ca: int = int(stations[int(e2["a"])]["city"])
				var cb: int = int(stations[int(e2["b"])]["city"])
				_fail["%d:%d" % [mini(ca, cb), maxi(ca, cb)]] = gw.game_time + FAIL_COOLDOWN
				break


func _station_cell(i: int) -> bool:
	var d: WorldData = gw.data
	var c: = Vector2i(i % d.w, i / d.w)
	for st: Dictionary in stations:
		var r: = Rect2i(st["cell"], Vector2i(STATION_FW, STATION_FD))
		if r.grow_individual(2, 1, 2, 1).has_point(c):
			return true
	return false




func _draw_lights() -> void :
	if gw.night == null or gw.night.factor <= 0.01 or gw.camera == null:
		return
	var a: float = gw.night.factor
	var view: Rect2 = gw.night._view()
	var far: bool = gw.camera.zoom.x < 0.75
	var head: = Color(1.0, 0.95, 0.7, a)
	var glow: = Color(0.6, 0.5, 0.25, a * 0.5)
	for tr: Dictionary in trains:
		var s: float = tr["s"]
		var hp: Vector2 = pos_at(tr, s)
		if not view.has_point(hp):
			continue
		var dir: Vector2 = (pos_at(tr, s + 2.0) - pos_at(tr, s - 2.0)).normalized()
		lights.draw_circle(hp + dir * 6.0, 3.0, glow)
		lights.draw_rect(Rect2((hp + dir * 4.0).round(), Vector2(1, 1)), head)
		if not far and (tr["cars"] as PackedStringArray).has("rail_wagon_pass"):
			for ci in range(1, (tr["cars"] as PackedStringArray).size()):
				var cp: Vector2 = pos_at(tr, s - float(ci) * CAR_GAP)
				lights.draw_rect(Rect2(cp.round() + Vector2(-1, -1), Vector2(3, 1)), Color(1.0, 0.85, 0.5, a * 0.8))
	for st: Dictionary in stations:
		var sp: Vector2 = st["p"]
		if not view.has_point(sp):
			continue
		var ct: City = gw.cities[int(st["city"])]
		if not ct.powered or float(st["ruin_t"]) >= 0.0 or float(st.get("bt", 0.0)) > 0.0:
			continue
		lights.draw_circle(sp + Vector2(0, -4), 7.0, Color(0.55, 0.42, 0.18, a * 0.3))
		for x in range(-12, 13, 8):
			lights.draw_rect(Rect2(sp + Vector2(x, -1), Vector2(1, 1)), Color(1.0, 0.9, 0.6, a))
	urban.draw_lights(lights, view, a, far)




func save_state() -> Dictionary:
	var items: Array = []
	for it: Dictionary in layer.items:
		if int(it["type"]) != 2 and not bool(it.get("dead", false)):
			var c: Dictionary = {"type": it["type"], "s": it["s"], "n": it["n"]}
			for k: String in ["w", "edge", "sid"]:
				if it.has(k):
					c[k] = it[k]
			items.append(c)
	var u: Dictionary = Save.dump(urban, ["_job"])
	if not urban._job.is_empty() and urban._job.get("city") is City:

		var cid: int = (urban._job["city"] as City).id
		var st: Dictionary = u.get("stage", {})
		if st.has(cid):
			st[cid] = maxi(0, int(st[cid]) - 1)
	return {"r": Save.dump(self, ["_job", "perf", "troops"]), "u": u, "items": items, "rt": troops.save_state()}




func load_state(d: Dictionary) -> void :
	Save.fill(self, d.get("r", {}), ["troops"])
	Save.fill(urban, d.get("u", {}))
	troops.load_state(d.get("rt", {}))
	_job = {}
	var e: Economy = gw.econ
	var jobs: Array = e.rail_jobs.duplicate()
	for tr: Dictionary in trains:
		tr["on_arrive"] = Callable()
		tr["on_lost"] = Callable()

	for exact: bool in [true, false]:
		for tr: Dictionary in trains:
			if bool(tr.get("cosmetic", true)) or String(tr.get("res", "")) == "" or (tr["on_arrive"] as Callable).is_valid():
				continue
			var fc: int = _city_owner(int(tr.get("from_city", -1)))
			var tc: int = _city_owner(int(tr.get("to_city", -1)))
			for sh: Dictionary in jobs:
				if String(sh["res"]) != String(tr["res"]) or int(sh["n"]) != int(tr["n"]):
					continue
				if exact and (int(sh["from"]) != fc or int(sh["to"]) != tc):
					continue
				var job: Dictionary = sh
				tr["job"] = job
				tr["on_arrive"] = func() -> void : e._rail_done(job, true)
				tr["on_lost"] = func() -> void : e._rail_done(job, false)
				jobs.erase(sh)
				break
	for sh2: Dictionary in jobs:
		e._rail_done(sh2, false)
	layer.setup(self)
	for it: Dictionary in d.get("items", []):
		layer.add_item(it.duplicate())
	layer_dirty()


func _city_owner(city_id: int) -> int:
	return gw.cities[city_id].country_id if city_id >= 0 and city_id < gw.cities.size() else -1





func st_name(sid: int) -> String:
	if sid < 0 or sid >= stations.size():
		return "?"
	var st: Dictionary = stations[sid]
	if st.has("name"):
		return String(st["name"])
	var cid: int = int(st["city"])
	return gw.cities[cid].name if cid >= 0 and cid < gw.cities.size() else "?"



func station_up(sid: int) -> bool:
	var st: Dictionary = stations[sid]
	return float(st["ruin_t"]) < 0.0 and float(st.get("bt", 0.0)) <= 0.0



func man_building_n(cid: int) -> int:
	var n: int = 0
	for e: Dictionary in edges:
		if not bool(e["dead"]) and float(e.get("bt", 0.0)) > 0.0 and int(e.get("man", 0)) == cid:
			n += 1
	return n



func station_near(cid: int, p: Vector2, r: float, skip: int = -1) -> int:
	var best: int = -1
	var bd: float = r
	for st: Dictionary in stations:
		var sid: int = int(st["id"])
		if sid == skip or (cid >= 0 and _station_country(sid) != cid):
			continue
		var d: float = (st["p"] as Vector2).distance_to(p)
		if d < bd:
			bd = d
			best = sid
	return best



func _occupied_why(c: Country, cell: Vector2i) -> String:
	var upk = gw.econ.get("upk") if gw.econ != null else null
	if upk != null and upk.occupied(cell, c):
		return Loc.t("Оккупированная земля: строить можно после мира")
	return ""




func man_station_site(c: Country, cell: Vector2i) -> Array:
	var none: = Vector2i(-1, -1)
	if c == null or c.eliminated:
		return [Loc.t("Нет страны"), none, -1]
	var d: WorldData = gw.data
	if not d.inside(cell.x, cell.y):
		return [Loc.t("За краем карты"), none, -1]
	if Biome.is_water(d.get_biome(cell.x, cell.y)):
		return [Loc.t("Нельзя строить на воде"), none, -1]
	if d.get_owner_id(cell.x, cell.y) != c.id:
		return [Loc.t("Вокзал — только на своей земле"), none, -1]
	var ow: String = _occupied_why(c, cell)
	if ow != "":
		return [ow, none, -1]
	var live: Dictionary = _live()
	var base: Vector2i = cell - Vector2i(STATION_FW / 2, 1)
	var best: Vector2i = none
	for r in 5:
		for dy in range( - r, r + 1):
			for dx in range( - r, r + 1):
				if best.x < 0 and maxi(absi(dx), absi(dy)) == r and _station_ok_in(live, base + Vector2i(dx, dy), c.id):
					best = base + Vector2i(dx, dy)
		if best.x >= 0:
			break
	if best.x < 0:
		return [Loc.t("Нет места: нужна ровная площадка без домов, дорог, путей и воды"), none, -1]
	if station_near(-1, _station_p(best), MAN_ST_GAP) >= 0:
		return [Loc.t("Рядом уже есть вокзал"), none, -1]
	var city: int = -1
	var bd: float = INF
	for cid: int in c.city_ids:
		var ct: City = gw.cities[cid]
		if ct.country_id != c.id:
			continue
		var dd: float = Vector2(ct.center).distance_to(Vector2(best))
		if dd < bd:
			bd = dd
			city = cid
	if city < 0:
		return [Loc.t("Нужен свой город"), none, -1]
	return ["", best, city]






func man_plan(c: Country, sid: int, to: Vector2i) -> Dictionary:
	var out: Dictionary = {"why": "", "a": sid, "b": -1}
	if c == null or c.eliminated:
		out["why"] = Loc.t("Нет страны")
		return out
	if sid < 0 or sid >= stations.size() or _station_country(sid) != c.id:
		out["why"] = Loc.t("Начните у своего вокзала")
		return out
	var sa: Dictionary = stations[sid]
	if float(sa["ruin_t"]) >= 0.0:
		out["why"] = Loc.t("Вокзал разрушен — дождитесь ремонта")
		return out
	if man_building_n(c.id) >= MAN_CAP:
		out["why"] = Loc.t("Уже строятся %d линии — дождитесь одной") % MAN_CAP
		return out
	var d: WorldData = gw.data
	if not d.inside(to.x, to.y):
		out["why"] = Loc.t("За краем карты")
		return out
	var C: int = GameWorld.CELL
	var sb: int = station_near(c.id, Vector2(to * C) + Vector2(2, 2), MAN_SNAP_PX, sid)
	var cell_b: = Vector2i(-1, -1)
	if sb >= 0:
		for eid: int in adj.get(sid, []):
			var e: Dictionary = edges[eid]
			if not bool(e["dead"]) and (int(e["a"]) == sb or int(e["b"]) == sb):
				out["why"] = Loc.t("Эти вокзалы уже связаны")
				return out
		cell_b = stations[sb]["cell"]
		out["b"] = sb
	else:
		var site: Array = man_station_site(c, to)
		if String(site[0]) != "":
			out["why"] = String(site[0])
			return out
		cell_b = site[1]
		out["nw"] = cell_b
		out["city"] = int(site[2])
	var dist: float = (sa["p"] as Vector2).distance_to(_station_p(cell_b))
	if dist > float(MAN_MAX_CELLS * C):
		out["why"] = Loc.t("Слишком далеко: до %d м по прямой") % (MAN_MAX_CELLS * C)
		return out
	if dist < float(MAN_MIN_CELLS * C):
		out["why"] = Loc.t("Слишком близко к вокзалу")
		return out
	var job: Dictionary = _live()
	job.merge({"allowed": [c.id], "strict": c.id, "cell_a": sa["cell"], "cell_b": cell_b, "log": [], "pts": PackedVector2Array(), 
		"block": Rect2i(cell_b, Vector2i(STATION_FW, STATION_FD)) if sb < 0 else Rect2i()})
	_line_worker(job)
	var pts: PackedVector2Array = job["pts"]
	if pts.size() < 2:
		out["why"] = Loc.t("Не проложить: только по своей земле, в обход городов и построек (мост — до %d клеток воды)") % GameWorld.MAX_SEA_BRIDGE
		return out
	for k2 in range(0, pts.size(), 16):
		var ow2: String = _occupied_why(c, Vector2i(floori(pts[k2].x / C), floori(pts[k2].y / C)))
		if ow2 != "":
			out["why"] = ow2
			return out
	var water: int = 0
	var bridges: int = 0
	var wet0: bool = false
	for k in pts.size():
		var q: = Vector2i(floori(pts[k].x / C), floori(pts[k].y / C))
		var wet: bool = d.inside(q.x, q.y) and Biome.is_water(d.get_biome(q.x, q.y))
		if wet:
			water += 1
			if not wet0:
				bridges += 1
		wet0 = wet
	var L: float = float(pts.size() - 1)
	var money: int = roundi((MAN_PX_COST * L + MAN_BR_PX * float(water)) / 10.0) * 10 + MAN_BR_COST * bridges
	var metal: int = ceili(L / MAN_METAL_PX) + 5 * bridges
	var wood: int = 0
	if sb < 0:
		money += MAN_ST_COST
		metal += int(MAN_ST_RES["metal"])
		wood += int(MAN_ST_RES["wood"])
	out.merge({"pts": pts, "len": L, "bridges": bridges, "water": water, "money": money, "metal": metal, "wood": wood, 
		"time": build_time(L) + MAN_BR_TIME * float(mini(bridges, 2))})
	var rc: Dictionary = {"metal": metal, "wood": wood}
	if c.money < money:
		out["why"] = Loc.t("Не хватает денег: нужно %d") % money
	elif not c.has_res(rc):
		out["why"] = Loc.t("Не хватает: %s") % c.missing_res(rc)
	return out




func _man_ok(pts: PackedVector2Array, job: Dictionary) -> bool:
	var strict: int = int(job.get("strict", 0))
	if strict <= 0:
		return true
	var blk: Rect2i = job.get("block", Rect2i())
	var W: int = job["w"]
	var H: int = job["h"]
	var biome: PackedByteArray = job["biome"]
	var owners: PackedByteArray = job["owners"]
	for k in pts.size():
		var c: = Vector2i(floori(pts[k].x / GameWorld.CELL), floori(pts[k].y / GameWorld.CELL))
		if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H or blk.has_point(c):
			return false
		var i: int = c.y * W + c.x
		var o: int = owners[i]
		if (o != strict and biome[i] > Biome.RIVER) or (o != 0 and o != strict):
			return false
	return true


func _man_pay(c: Country, money: int, rc: Dictionary) -> void :
	c.money -= money
	c.pay_res(rc)
	if gw.econ != null:
		gw.econ.stat_add(c, "spend", "build", money)
		for res: String in rc:
			if int(rc[res]) > 0:
				gw.econ.stat_res(c, res, "build", - int(rc[res]))



func _man_station(c: Country, nw: Vector2i, city_id: int) -> int:
	var ct: City = gw.cities[city_id]
	var n: int = 2
	for st: Dictionary in stations:
		if int(st["city"]) == city_id and st.has("man"):
			n += 1
	var sid: int = _place_station(ct, nw, true)
	stations[sid]["name"] = "%s-%d" % [ct.name, n]
	stats["man_st"] = int(stats.get("man_st", 0)) + 1
	return sid


func _station_done(st: Dictionary) -> void :
	st["bt"] = 0.0
	var obj: int = int(st["obj"])
	if obj >= 0:
		gw.obj_state[obj] = 0
		gw._mark_obj_chunk(obj)
		gw.fx.spawn("build_spark", gw.obj_origin(obj) + Vector2(10, 4), 6)
	var c: Country = gw.country_by_id(_station_country(int(st["id"])))
	if c != null and c.is_player:
		gw.say(c, Loc.mk("Вокзал построен: %s", [st_name(int(st["id"]))]))




func build_station(c: Country, cell: Vector2i) -> String:
	var site: Array = man_station_site(c, cell)
	if String(site[0]) != "":
		return String(site[0])
	if c.money < MAN_ST_COST:
		return Loc.t("Не хватает денег: нужно %d") % MAN_ST_COST
	if not c.has_res(MAN_ST_RES):
		return Loc.t("Не хватает: %s") % c.missing_res(MAN_ST_RES)
	_man_pay(c, MAN_ST_COST, MAN_ST_RES)
	var sid: int = _man_station(c, site[1], int(site[2]))
	gw.say(c, Loc.mk("Стройка вокзала %s: %d мин", [st_name(sid), ceili(MAN_ST_TIME / 60.0)]))
	return ""





func build_line(c: Country, sid: int, to: Vector2i) -> String:
	var pl: Dictionary = man_plan(c, sid, to)
	if String(pl["why"]) != "":
		return String(pl["why"])
	_man_pay(c, int(pl["money"]), {"metal": int(pl["metal"]), "wood": int(pl["wood"])})
	var sb: int = int(pl["b"])
	if sb < 0:
		sb = _man_station(c, pl["nw"], int(pl["city"]))
	var e: Dictionary = _make_edge(sid, sb, pl["pts"])
	e["man"] = c.id
	e["b0"] = gw.game_time
	e["bt"] = float(pl["time"])
	e["bk"] = 0
	layer.mark_edge(int(e["id"]))
	stats["man_lines"] = int(stats.get("man_lines", 0)) + 1
	print("[Rail] hand-built line %s - %s: %d px, %d bridges, %.0f s, %d" % [st_name(sid), st_name(sb), int(e["len"]), (e["br"] as Array).size(), float(e["bt"]), int(pl["money"])])
	gw.say(c, Loc.mk("Стройка Ж/Д: %s — %s, %d мин", [st_name(sid), st_name(sb), ceili(float(e["bt"]) / 60.0)]))
	return ""
