class_name Supply
extends RefCounted










signal incident(kind: String, attacker: int, victim: int, commodity: String, pos: Vector2, info: Dictionary)
signal prices_changed

const COMMODITIES: Array[String] = ["oil", "fuel", "metal", "titanium", "wood", "food", "goods", "precious", "uranium"]
const NAME_RU: Dictionary = {"oil": "Нефть", "fuel": "Топливо", "metal": "Металл", "titanium": "Титан", "wood": "Дерево", 
	"food": "Еда", "goods": "Товары", "precious": "Драгметаллы", "uranium": "Уран"}
const GEN_RU: Dictionary = {"oil": "нефти", "fuel": "топлива", "metal": "металла", "titanium": "титана", "wood": "древесины", 
	"food": "продовольствия", "goods": "товаров", "precious": "драгметаллов", "uranium": "урана"}
const TICK: float = 2.0
const RISK_HALF: float = 150.0
const HIST_DT: float = 10.0
const HIST_N: int = 60
const PRICE_K: float = 0.9
const IMPORT_K: float = 0.45
const CRISIS_ON: float = 0.65
const CRISIS_OFF: float = 0.35
const CRISIS_HOLD: float = 30.0
const CRISIS_MAX: int = 2
const LANE_MAX: int = 2
const MERCH_HOLD: float = 0.45
const LANE_CRISIS: float = 0.7
const ZONE_R: float = 380.0
const ZONE_HALF: float = 110.0
const ZONE_AVOID: float = 0.35
const ZONE_W: float = 7.0
const REROUTE_DT: float = 6.0
const REROUTE_GAP: float = 30.0
const MERCH_DT: float = 2.0
const MERCH_MAX: int = 60
const MERCH_PER_TICK: int = 1
const DEP_MIN: float = 14.0
const DEP_MAX: float = 90.0
const GRP_DELAY: float = 2.5
const LANE_W: float = 24.0
const SEP_DT: float = 0.5
const SEP_AHEAD: float = 80.0
const SEP_HOLD: float = 50.0
const SEP_GROUP: float = 30.0
const SEP_LAT: float = 16.0
const SEP_WAIT: float = 25.0
const LAND_DT: float = 4.0
const LAND_MAX: int = 24
const LAND_LANES: int = 2
const LAND_PATH_T: float = 300.0
const SLOW_DETOUR: float = 1.3
const PONTOON_DELAY: float = 22.0
const PONTOON_BUILD: float = 18.0
const PONTOON_GAP: float = 5.0
const PONTOON_HP: int = 2
const PONTOON_MAX: int = 40
const JAM_GIVEUP: float = 170.0
const JAM_N: int = 2
const NEWS_GAP: float = 45.0
const NEWS_RES_GAP: float = 150.0
const BLOCK_R: float = 900.0
const TURN_R: float = 1400.0
const ESCORT_R: float = 800.0
const BR_GAP: Array = [320.0, 240.0, 180.0]
const PROD: Array = [Facility.Kind.FARM, Facility.Kind.CIV_FACTORY, Facility.Kind.MINE, Facility.Kind.OIL_RIG, Facility.Kind.SAWMILL]
const ADD: Dictionary = {"convoy_sunk": 0.1, "neutral_sunk": 0.16, "port_hit": 0.1, "bridge_destroyed": 0.12, "jam": 0.06, 
	"blockade_start": 0.14, "turned": 0.03, "oil_hit": 0.06, "pontoon_sunk": 0.04}

var gw: GameWorld
var raw: Dictionary = {}
var lane: Dictionary = {}
var port_r: Dictionary = {}
var zones: Array = []
var hist: Dictionary = {}
var crisis: Dictionary = {}
var blockades: Dictionary = {}
var stats: Dictionary = {}
var why: Dictionary = {}
var res_k: Dictionary = {}
var ilog: Array = []
var spills: Array = []
var pcache: Dictionary = {}
var sea_ver: int = 0
var strike_by: int = 0
var perf: Dictionary = {"last_us": 0, "max_us": 0, "sum_us": 0, "n": 0}
var _hot: Dictionary = {}
var _imp: Dictionary = {}
var _need: Dictionary = {}
var _mult: Dictionary = {}
var _news_t: float = -999.0
var _news_res: Dictionary = {}
var _news_base: Dictionary = {}
var _t: float = 0.0
var _ht: float = 0.0
var _zt: float = 0.0
var _mt: float = 0.0
var _at: float = 0.0
var _ct: float = 0.0
var _weighted: Dictionary = {}
var _cut: Dictionary = {}
var _flip: Dictionary = {}
var _lt: float = 0.0
var _lpath: Dictionary = {}


const LB_BUDGET: int = 1200
var _lb_st: int = -1
var _lb_key: String = ""
var _lb_ab: Array = []
var _lb_ca: Vector2i
var _lb_cb: Vector2i
var _lb_pa: Vector2
var _lb_pb: Vector2
var _lb_ids: Array[Vector2i] = []
var _lb_i: int = 0
var _lb_out: = PackedVector2Array()
var _lb_dry: = PackedVector2Array()
var _lb_prev: Vector2
var _lb_used: Dictionary = {}
var _lb_t: float = -999.0
var _lb_fr: int = -1
var _lb_us: int = 0


const NET_OPS: int = 400
var _net_ops: int = 0


func _t_ok(lim: int) -> bool:
	if gw.net_driven or GameWorld.lab_tick >= 0:
		_net_ops += 1
		return _net_ops <= NET_OPS
	return Time.get_ticks_usec() < lim


func _over() -> bool:
	return _net_ops >= NET_OPS if gw.net_driven or GameWorld.lab_tick >= 0 else _lb_us >= LB_BUDGET



var _pg: AStarGrid2D = null
var _pg_row: int = -1
var _pg_ver: int = -1
var _pg_t: float = -999.0
var _lb_task: int = -1
var _lb_box: Array = []

var _alt_c: int = -1
var _alt_cand: Dictionary = {}
var _alt_scan: Array = []
var _alt_i: int = 0
var _alt_cells: Array = []
var _cut_dirty: bool = true
var _cut_sig: Array = []
var _cmemo: Dictionary = {}
var _fired: Dictionary = {}
var _port_hit_t: Dictionary = {}
var _br_pick: Dictionary = {}
var _br_by: Dictionary = {}
var _br_down_t: Dictionary = {}
var _jam_noted: Dictionary = {}
var _alt: Dictionary = {}
var _ai_blk: Dictionary = {}
var _sw: Dictionary = {}
var _wjob: Dictionary = {}
var _zsig: Array = []
var _next_dep: Dictionary = {}
var _sep_t: float = 0.0


func _init(world: GameWorld) -> void :
	gw = world
	for c: String in COMMODITIES:
		hist[c] = PackedFloat32Array()
		res_k[c] = 1.0




func risk(commodity: String) -> float:
	return clampf(float(raw.get(commodity, 0.0)), 0.0, 1.0)


func route_risk(a_cid: int, b_cid: int) -> float:
	var r: float = float(lane.get(Diplomacy.key(a_cid, b_cid), 0.0))
	r += 0.5 * maxf(float(port_r.get(a_cid, 0.0)), float(port_r.get(b_cid, 0.0)))
	if blockaded(a_cid) or blockaded(b_cid):
		r += 0.5
	return clampf(r, 0.0, 1.0)



func price_mult(cid: int, commodity: String) -> float:
	var m: float = 1.0 + PRICE_K * risk(commodity) * float(res_k.get(commodity, 1.0))
	if cid > 0 and (_need.get(cid, {}) as Dictionary).has(commodity):
		m += IMPORT_K * float(_imp.get(cid, 0.0))
	return m


func crises() -> Array:
	var out: Array = []
	for k: String in crisis:
		out.append((crisis[k] as Dictionary).duplicate())
	return out


func history(commodity: String) -> PackedFloat32Array:
	return hist.get(commodity, PackedFloat32Array())


func danger_zones() -> Array:
	var out: Array = []
	for z: Dictionary in zones:
		if float(z["level"]) >= 0.15:
			out.append({"pos": z["pos"], "r": z["r"], "level": clampf(float(z["level"]), 0.0, 1.0)})
	return out



func reason_of(commodity: String) -> String:
	var w: Array = why.get(commodity, [])
	return Loc.t(String(w[0])) if not w.is_empty() and risk(commodity) >= 0.08 else ""


func blockaded(cid: int) -> bool:
	if blockades.is_empty() or gw.econ == null or gw.econ.ports == null:
		return false
	var any: bool = false
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.PORT and f.country_id == cid and gw.mil.alive(f):
			if not port_blockaded(f):
				return false
			any = true
	return any


func port_blockaded(f: Facility) -> bool:
	if f == null or blockades.is_empty():
		return false
	for k: String in blockades:
		if int(blockades[k]["port"]) == f.id:
			return true
	return false




func update(dt: float) -> void :
	if dt <= 0.0 or gw.econ == null:
		return
	var t0: int = Time.get_ticks_usec()
	var now: float = gw.game_time
	for k in range(spills.size() - 1, -1, -1):
		if now - float(spills[k]["t0"]) > 42.0:
			spills.remove_at(k)
	_t += dt
	if _t >= TICK:
		_tick(_t)
		_t = 0.0
		_pmax("tick", t0)
	_ht += dt
	if _ht >= HIST_DT:
		_ht = 0.0
		var t1: int = Time.get_ticks_usec()
		_sample()
		_pmax("sample", t1)
	_zt += dt
	if _zt >= REROUTE_DT:
		_zt = 0.0
		var t2: int = Time.get_ticks_usec()
		_reroute_tick()
		_pmax("reroute", t2)
	_sep_t += dt
	if _sep_t >= SEP_DT:
		_sep_t = 0.0
		var t5: int = Time.get_ticks_usec()
		_separate()
		_pmax("sep", t5)
	if not _wjob.is_empty():
		var t4: int = Time.get_ticks_usec()
		_wjob_step()
		_pmax("rjob", t4)
	_mt += dt
	if _mt >= MERCH_DT:
		_mt = 0.0
		var t3: int = Time.get_ticks_usec()
		_merch_tick()
		_pmax("merch", t3)
	if _lb_st >= 0:
		var t5: int = Time.get_ticks_usec()
		_lb_step()
		_pmax("land_slice", t5)
	if _alt_c >= 0:
		var t6: int = Time.get_ticks_usec()
		_alt_step()
		_pmax("alt_slice", t6)
	_lt += dt
	if _lt >= LAND_DT:
		_lt = 0.0
		var t4: int = Time.get_ticks_usec()
		_land_tick()
		_pmax("land", t4)
	var us: int = Time.get_ticks_usec() - t0
	if us > 30:
		perf["last_us"] = us
		perf["max_us"] = maxi(int(perf["max_us"]), us)
		perf["sum_us"] = int(perf["sum_us"]) + us
		perf["n"] = int(perf["n"]) + 1


func _pmax(part: String, t0: int) -> void :
	var us: int = Time.get_ticks_usec() - t0
	perf[part] = maxi(int(perf.get(part, 0)), us)


func _tick(tdt: float) -> void :
	var k: float = pow(0.5, tdt / RISK_HALF)
	for c: String in raw.keys():
		raw[c] = float(raw[c]) * k
	for d: Dictionary in [lane, port_r]:
		for key: Variant in d.keys():
			d[key] = float(d[key]) * k
			if float(d[key]) < 0.005:
				d.erase(key)
	var kz: float = pow(0.5, tdt / ZONE_HALF)
	for i in range(zones.size() - 1, -1, -1):
		var z: Dictionary = zones[i]
		if z.has("blk"):
			continue
		z["level"] = float(z["level"]) * kz
		if float(z["level"]) < 0.08:
			zones.remove_at(i)
	_blockade_tick()
	_pontoon_tick(tdt)
	_ct += tdt
	if _cut_dirty or _ct >= 60.0:
		_ct = 0.0
		_recut()
	_market_tick()
	_crisis_tick(tdt)
	_at += tdt
	if _at >= 20.0:
		_at = 0.0
		_ai_tick()



func _market_tick() -> void :
	var e: Economy = gw.econ
	var stock: Dictionary = {}
	var cap: Dictionary = {}
	_imp.clear()
	_need.clear()
	for c: Country in gw.countries:
		if c.eliminated or c.capital_id < 0:
			continue
		var nd: Dictionary = {}
		for r: String in COMMODITIES:
			stock[r] = float(stock.get(r, 0.0)) + float(int(c.get(r)))
			cap[r] = float(cap.get(r, 0.0)) + float(e.res_cap(c, r))
			if Economy.TRADE_RES.has(r) and e.need(c, r) > 0:
				nd[r] = true
		_need[c.id] = nd
		var ir: float = float(port_r.get(c.id, 0.0))
		if blockaded(c.id):
			ir += 0.6
		for key: Variant in lane:
			var ab: PackedStringArray = String(key).split(":")
			if ab.size() == 2 and (int(ab[0]) == c.id or int(ab[1]) == c.id):
				ir = maxf(ir, float(lane[key]))
		_imp[c.id] = clampf(ir, 0.0, 1.0)
	var changed: bool = false
	for r2: String in COMMODITIES:
		var fill: float = float(stock.get(r2, 0.0)) / maxf(1.0, float(cap.get(r2, 1.0)))
		res_k[r2] = clampf(1.5 - fill, 0.6, 1.4)
		var m: float = price_mult(-1, r2)
		if absf(m - float(_mult.get(r2, 1.0))) >= 0.02:
			_mult[r2] = m
			changed = true
		_price_news(r2, m)
	if changed:
		prices_changed.emit()


func _price_news(r: String, m: float) -> void :
	var base: float = float(_news_base.get(r, 1.0))
	var now: float = gw.game_time
	if m < base:
		_news_base[r] = maxf(1.0, m)
		return
	if m - base < 0.25 or now - _news_t < NEWS_GAP or now - float(_news_res.get(r, -999.0)) < NEWS_RES_GAP:
		return
	var w: String = reason_of(r)
	if w == "":
		return
	_news_t = now
	_news_res[r] = now
	_news_base[r] = m
	stats["price_news"] = int(stats.get("price_news", 0)) + 1
	gw.news.emit("%s +%d%% · %s" % [String(NAME_RU[r]), roundi((m - 1.0) * 100.0), w], "amber")


func _sample() -> void :
	var now: float = gw.game_time
	for r: String in COMMODITIES:
		var h: PackedFloat32Array = hist.get(r, PackedFloat32Array())
		var p: float = float(gw.econ.market_price(r))
		h.append(p)
		if h.size() > HIST_N:
			h = h.slice(h.size() - HIST_N)
		hist[r] = h
		if h.size() >= 7 and now - float(_sw.get(r, -999.0)) >= 60.0:
			var old: float = h[h.size() - 7]
			if old > 0.0 and absf(p - old) / old >= 0.15:
				_sw[r] = now
				stats["swings"] = int(stats.get("swings", 0)) + 1


func _crisis_tick(tdt: float) -> void :
	var now: float = gw.game_time
	for r: String in COMMODITIES:
		var key: String = "c:" + r
		var v: float = risk(r)
		if crisis.has(key):
			(crisis[key] as Dictionary)["level"] = v
			if v < CRISIS_OFF:
				var cr: Dictionary = crisis[key]
				crisis.erase(key)
				note("crisis_end", 0, 0, r, cr.get("pos", Vector2.ZERO), {"key": key, "len": now - float(cr["since"])})
				_news(Loc.msg(Loc.mk("Кризис %s отступает", [Loc.mk(String(GEN_RU[r]))])), "grass_light", true)
			continue
		if v >= CRISIS_ON and _ncrisis("c:") < CRISIS_MAX:
			_hot[key] = float(_hot.get(key, 0.0)) + tdt
			if float(_hot[key]) >= CRISIS_HOLD:
				_hot.erase(key)
				var w: Array = why.get(r, ["", Vector2.ZERO, now])
				var reg: String = _region(w[1])
				crisis[key] = {"commodity": r, "region": reg, "route": "", "level": v, "reason_ru": String(w[0]), "since": now, "pos": w[1]}
				note("crisis_start", 0, 0, r, w[1], {"key": key, "level": v, "reason_ru": String(w[0])})
				_news(Loc.msg(Loc.mk("Кризис %s в регионе%s", [Loc.mk(String(GEN_RU[r])), (" · " + Loc.t(String(w[0]))) if String(w[0]) != "" else ""])), "alert_red", true)
				stats["crises"] = int(stats.get("crises", 0)) + 1
		else:
			_hot.erase(key)
	for lk: Variant in lane.keys():
		var key2: String = "l:" + String(lk)
		var v2: float = float(lane[lk])
		if crisis.has(key2):
			continue
		if v2 >= LANE_CRISIS and _ncrisis("l:") < LANE_MAX:
			var ab: PackedStringArray = String(lk).split(":")
			var a: Country = gw.country_by_id(int(ab[0]))
			var b: Country = gw.country_by_id(int(ab[1]))
			if a == null or b == null:
				continue
			crisis[key2] = {"commodity": "", "region": "%s — %s" % [a.name, b.name], "route": String(lk), "level": clampf(v2, 0.0, 1.0), 
				"reason_ru": "сорваны поставки", "since": now, "pos": Vector2(gw.cities[a.capital_id].center * GameWorld.CELL) if a.capital_id >= 0 else Vector2.ZERO}
			note("crisis_start", 0, 0, "", crisis[key2]["pos"], {"key": key2, "route": String(lk), "level": v2, "reason_ru": "сорваны поставки"})
			_news(Loc.msg(Loc.mk("Торговый кризис: %s — %s · сорваны поставки", [a.name, b.name])), "alert_red", true)
			stats["crises"] = int(stats.get("crises", 0)) + 1
	for key3: String in crisis.keys():
		if key3.begins_with("l:"):
			var v3: float = float(lane.get(key3.substr(2), 0.0))
			(crisis[key3] as Dictionary)["level"] = clampf(v3, 0.0, 1.0)
			if v3 < CRISIS_OFF:
				var cr2: Dictionary = crisis[key3]
				crisis.erase(key3)
				note("crisis_end", 0, 0, "", cr2.get("pos", Vector2.ZERO), {"key": key3, "route": key3.substr(2), "len": now - float(cr2["since"])})


func _ncrisis(prefix: String) -> int:
	var n: int = 0
	for k: String in crisis:
		if k.begins_with(prefix):
			n += 1
	return n


func _news(text: String, col: String, force: bool = false) -> void :
	if gw.game_time - _news_t < (20.0 if force else NEWS_GAP):
		return
	_news_t = gw.game_time
	stats["news"] = int(stats.get("news", 0)) + 1
	gw.news.emit(text, col)



func _region(p: Vector2) -> String:
	var best: String = ""
	var bd: float = INF
	for c: Country in gw.countries:
		if c.eliminated or c.capital_id < 0:
			continue
		var d: float = Vector2(gw.cities[c.capital_id].center * GameWorld.CELL).distance_to(p)
		if d < bd:
			bd = d
			best = c.name
	return best




func note(kind: String, attacker: int, victim: int, commodity: String, pos: Vector2, info: Dictionary = {}) -> void :
	stats[kind] = int(stats.get(kind, 0)) + 1
	ilog.append([gw.game_time, kind, attacker, victim, commodity])
	if ilog.size() > 80:
		ilog.pop_front()
	incident.emit(kind, attacker, victim, commodity, pos, info)


func _add(commodity: String, amt: float, why_ru: String, pos: Vector2) -> void :
	if amt <= 0.0 or not COMMODITIES.has(commodity):
		return
	var r: float = float(raw.get(commodity, 0.0))
	raw[commodity] = minf(1.5, r + amt * (1.0 - 0.45 * clampf(r, 0.0, 1.0)))
	if why_ru != "":
		why[commodity] = [why_ru, pos, gw.game_time]


func _lane_add(a: int, b: int, amt: float) -> void :
	if a <= 0 or b <= 0 or a == b:
		return
	var key: String = Diplomacy.key(a, b)
	lane[key] = minf(1.2, float(lane.get(key, 0.0)) + amt)


func _zone(pos: Vector2, lvl: float, w: String) -> void :
	for z: Dictionary in zones:
		if not z.has("blk") and (z["pos"] as Vector2).distance_to(pos) < float(z["r"]) * 0.7:
			z["level"] = minf(1.2, float(z["level"]) + lvl)
			z["pos"] = (z["pos"] as Vector2).lerp(pos, 0.3)
			return
	zones.append({"pos": pos, "r": ZONE_R, "level": lvl, "why": w})
	if zones.size() > 24:
		var wi: int = -1
		var wl: float = INF
		for i in zones.size():
			if not (zones[i] as Dictionary).has("blk") and float(zones[i]["level"]) < wl:
				wl = float(zones[i]["level"])
				wi = i
		if wi >= 0:
			zones.remove_at(wi)



func on_convoy_sunk(cs: Dictionary, by: int, value: int) -> void :
	var owner: int = int(cs.get("owner", 0))
	var res: String = String(cs.get("res", ""))
	var n: int = int(cs.get("n", 0))
	var pos: Vector2 = cs.get("pos", Vector2.ZERO)
	var neutral: bool = by > 0 and owner > 0 and by != owner and gw.get("navy") != null and not gw.navy._hostile(by, owner)
	var kind: String = "neutral_sunk" if neutral else "convoy_sunk"
	spills.append({"pos": pos, "t0": gw.game_time, "res": res if n > 0 else "oil", "sd": int(cs.get("id", 0)), "n": n})
	if n > 0:
		_add(res, float(ADD[kind]), "атаки на конвои", pos)
	for r: String in COMMODITIES:
		if r != res:
			_add(r, 0.01, "", pos)
	_zone(pos, 0.5, "конвой потоплен")
	var fr: int = int(cs.get("from", 0))
	var to: int = int(cs.get("to", 0))
	if fr > 0 and to > 0:
		_lane_add(fr, to, 0.15)
	port_r[owner] = minf(1.2, float(port_r.get(owner, 0.0)) + 0.08)
	if bool(cs.get("m", false)):
		stats["merch_sunk"] = int(stats.get("merch_sunk", 0)) + 1
	note(kind, by, owner, res, pos, {"value": value, "convoy": int(cs.get("id", 0)), "from": fr, "to": to, "kind": String(cs.get("kind", "")), "n": n})




func on_convoy_fired(cs: Dictionary, by: int) -> void :
	var owner: int = int(cs.get("owner", 0))
	if by <= 0 or owner <= 0 or by == owner or gw.get("navy") == null or gw.navy._hostile(by, owner):
		return
	var key: String = "%d>%d" % [by, owner]
	if gw.game_time - float(_fired.get(key, -999.0)) < 5.0:
		return
	_fired[key] = gw.game_time
	stats["neutral_fired"] = int(stats.get("neutral_fired", 0)) + 1
	var pos: Vector2 = cs.get("pos", Vector2.ZERO)
	for s: Ship in gw.navy.ships:
		if s.alive() and s.c == owner and s.pos.distance_to(pos) <= ESCORT_R:
			if not gw.diplo.at_war(owner, by):
				gw.diplo.declare_war(owner, by, "огонь по конвою под охраной")
				if not gw.diplo.at_war(owner, by):
					return
				stats["escort_wars"] = int(stats.get("escort_wars", 0)) + 1
				var me: Country = gw.player
				if me != null and by == me.id:
					gw.message.emit(Loc.msg(Loc.mk("Конвой был под охраной: эскорт открыл ответный огонь — ВОЙНА")))
			return




func may_sink_neutral(c: int, victim: int, s: Ship) -> bool:
	if s == null or victim <= 0 or victim == c or gw.diplo == null or gw.diplo.allied(c, victim):
		return false
	if s.fleet != 0 and gw.get("navy") != null:
		return bool(gw.navy.fl.fleet(s.fleet).get("sink_n", false))
	return bool(s.ord.get("sink_n", false))



func on_strike(p: Vector2, r_px: float, by: int) -> void :
	var now: float = gw.game_time
	for f: Facility in gw.mil.facilities:
		var k: int = f.kind
		if k != Facility.Kind.PORT and k != Facility.Kind.REFINERY and k != Facility.Kind.OIL_RIG:
			continue
		if f.center_px().distance_to(p) > r_px + 30.0 or f.country_id == by:
			continue
		if k == Facility.Kind.PORT:
			if now - float(_port_hit_t.get(f.id, -999.0)) < 15.0:
				continue
			_port_hit_t[f.id] = now
			port_r[f.country_id] = minf(1.2, float(port_r.get(f.country_id, 0.0)) + 0.2)
			_add("goods", float(ADD["port_hit"]), "удары по портам", p)
			_add("oil", 0.04, "удары по портам", p)
			note("port_hit", by, f.country_id, "goods", p, {"port": f.id})
		else:
			_add("oil" if k == Facility.Kind.OIL_RIG else "fuel", float(ADD["oil_hit"]), "удары по нефтянке", p)
	for b: Bridge in gw.bridges:
		if b.pont > 0 and pont_line(b)[0].lerp(pont_line(b)[1], 0.5).distance_to(p) <= r_px + 10.0:
			_pont_hit(b, by)




func on_bridge_destroyed(b: Bridge, k: int) -> void :
	var by: int = strike_by
	var rehit: bool = b.rehit or gw.game_time - float(_br_down_t.get(b.id, -999.0)) < b.rebuild_time()
	_br_by[b.id] = by
	_br_down_t[b.id] = gw.game_time
	if rehit:
		b.pont = 0
		b.pont_t = 0.0
		b.pont_hp = 0
		stats["bridge_rehit"] = int(stats.get("bridge_rehit", 0)) + 1
		return
	b.pont = 0
	b.pont_t = 0.0
	b.pont_hp = 0
	_jam_noted.erase(b.id)
	_cut_dirty = true
	var pos: Vector2 = b.center_px()
	var own: int = _bridge_owner(b)
	var trade: bool = false
	var res: String = "goods"
	var pairs: Dictionary = {}
	for t: Dictionary in gw.econ.trucks:
		if int(t["from"]) != int(t["to"]) and (t["pos"] as Vector2).distance_to(pos) < 700.0:
			trade = true
			res = String(t["res"])
			pairs[Diplomacy.key(int(t["from"]), int(t["to"]))] = [int(t["from"]), int(t["to"])]
	for pk: String in pairs:
		_lane_add(int(pairs[pk][0]), int(pairs[pk][1]), 0.12)
	_add(res, float(ADD["bridge_destroyed"]) * (1.0 if trade else 0.35), "разрушен мост", pos)
	note("bridge_destroyed", by, own, res, pos, {"bridge": b.id, "trade": trade, "kind": b.kind})


func on_bridge_rebuilt(b: Bridge) -> void :
	b.pont = 0
	b.pont_t = 0.0
	_jam_noted.erase(b.id)
	_cut_dirty = true
	stats["bridges_rebuilt"] = int(stats.get("bridges_rebuilt", 0)) + 1


func _pont_ok(b: Bridge) -> bool:
	return b.kind != Bridge.Kind.RAIL and b.cells.size() <= PONTOON_MAX and b.state == Bridge.State.REBUILDING




func _pontoon_tick(tdt: float) -> void :
	for b: Bridge in gw.bridges:
		if not _pont_ok(b) or b.pont == 2:
			continue
		b.pont_t += tdt
		if b.pont == 0 and b.pont_t >= PONTOON_DELAY and b.left() > PONTOON_BUILD + 15.0:
			b.pont = 1
			b.pont_t = 0.0
		elif b.pont == 1 and b.pont_t >= PONTOON_BUILD:
			b.pont = 2
			b.pont_hp = PONTOON_HP
			b.pont_next = 0.0
			gw.econ.bridge_state(b.cells, true)
			_cut_dirty = true
			var own: int = _bridge_owner(b)
			note("pontoon_built", 0, own, "", b.center_px(), {"bridge": b.id})
			if gw.player != null and own == gw.player.id:
				gw.message.emit(Loc.msg(Loc.mk("Сапёры навели понтонную переправу у разрушенного моста")))


func _pont_hit(b: Bridge, by: int) -> void :
	b.pont_hp -= 1
	var c: Vector2 = pont_line(b)[0].lerp(pont_line(b)[1], 0.5)
	if b.pont_hp > 0 and b.pont == 2:
		return
	var was_up: bool = b.pont == 2
	b.pont = 0
	b.pont_t = 0.0
	b.pont_hp = 0
	if was_up and not b.passable():
		gw.econ.bridge_state(b.cells, false)
		if gw.army != null:
			gw.army.on_pontoon_sunk(b, by)
	_cut_dirty = true
	_add("goods", float(ADD["pontoon_sunk"]), "разрушена переправа", c)
	stats["pontoon_sunk"] = int(stats.get("pontoon_sunk", 0)) + 1
	if gw._on_screen(c, 60.0):
		gw.fx.spawn("splash", c.round(), 6)
		gw.fx.debris_burst(c.round(), 4, false)
	_br_by[b.id] = by



func pont_line(b: Bridge) -> PackedVector2Array:
	var a: Vector2 = Vector2(b.cells[0] * GameWorld.CELL) + Vector2(2, 2)
	var e: Vector2 = Vector2(b.cells[b.cells.size() - 1] * GameWorld.CELL) + Vector2(2, 2)
	var d: Vector2 = (e - a).normalized() if e != a else Vector2.RIGHT
	var o: Vector2 = d.orthogonal() * 8.0
	return PackedVector2Array([a - d * 5.0 + o, e + d * 5.0 + o])


func _bridge(id: int) -> Bridge:
	if id >= 0 and id < gw.bridges.size() and gw.bridges[id].id == id:
		return gw.bridges[id]
	for b: Bridge in gw.bridges:
		if b.id == id:
			return b
	return null


func _broken_at(p: Vector2) -> Bridge:
	var d: WorldData = gw.data
	var c: = Vector2i(int(p.x) / GameWorld.CELL, int(p.y) / GameWorld.CELL)
	for o: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = c + o
		if d.inside(q.x, q.y) and d.has_flag(q.x, q.y, WorldData.F_BRIDGE):
			var b: Bridge = gw.bridge_cells.get(q.y * d.w + q.x, null)
			if b != null and not b.passable():
				return b
	return null





func truck_tick(t: Dictionary, dt: float) -> int:
	var path: PackedVector2Array = t["path"]
	var i: int = int(t["i"])
	if t.has("jam"):
		var b: Bridge = _bridge(int(t["jam"]))
		if b == null or b.passable():
			t.erase("jam")
			t["chk"] = -1
			return 0
		if b.pont == 2 and gw.game_time >= b.pont_next and _head(t, b):
			b.pont_next = gw.game_time + PONTOON_GAP
			_onto_pontoon(t, b)
			t.erase("jam")
			t["brk"] = -1
			t["pass"] = b.id
			stats["pontoon_trucks"] = int(stats.get("pontoon_trucks", 0)) + 1
			return 0
		if gw.game_time - float(t.get("jam_t", gw.game_time)) > JAM_GIVEUP:
			_send_home(t)
			return 2
		return 1
	if i >= path.size():
		return 0
	if int(t.get("chk", -1)) != i:
		t["chk"] = i
		t["brk"] = -1
		for j in range(i, mini(i + 3, path.size())):
			var bb: Bridge = _broken_at(path[j])
			if bb != null and bb.id != int(t.get("pass", -1)):
				t["brk"] = bb.id
				t["brj"] = j
				break
	var bid: int = int(t.get("brk", -1))
	if bid < 0:
		return 0
	var b2: Bridge = _bridge(bid)
	if b2 == null or b2.passable():
		t["brk"] = -1
		return 0
	var j2: int = int(t.get("brj", i))
	var pos: Vector2 = t["pos"]
	var bank: Vector2 = path[j2 - 1] if j2 - 1 >= i and j2 >= 1 else pos
	var q: int = 0
	for o: Dictionary in gw.econ.trucks:
		if int(o.get("jam", -1)) == bid and (o["pos"] as Vector2).distance_to(bank) < 60.0:
			q += 1
	if pos.distance_to(bank) <= Economy.TRUCK_SPEED * dt + 2.0 + 6.0 * float(q) or j2 <= i:
		t["jam"] = bid
		t["jam_t"] = gw.game_time
		_jammed(b2, t)
		return 1
	return 0


func _head(t: Dictionary, b: Bridge) -> bool:
	var jt: float = float(t.get("jam_t", 0.0))
	for o: Dictionary in gw.econ.trucks:
		if o != t and int(o.get("jam", -1)) == b.id and float(o.get("jam_t", 0.0)) < jt and (o["pos"] as Vector2).distance_to(t["pos"]) < 80.0:
			return false
	return true



func _onto_pontoon(t: Dictionary, b: Bridge) -> void :
	var path: PackedVector2Array = t["path"]
	var pl: PackedVector2Array = pont_line(b)
	var o: Vector2 = pl[0] - (Vector2(b.cells[0] * GameWorld.CELL) + Vector2(2, 2) - (pl[1] - pl[0]).normalized() * 5.0)
	var box: = Rect2(Vector2(b.cells[0] * GameWorld.CELL), Vector2.ZERO)
	for c: Vector2i in b.cells:
		box = box.expand(Vector2(c * GameWorld.CELL))
	box = box.grow(5.0)
	for k in range(int(t["i"]), mini(int(t["i"]) + 60, path.size())):
		if box.has_point(path[k]):
			path[k] = path[k] + o
	t["path"] = path


func _send_home(t: Dictionary) -> void :
	var e: Economy = gw.econ
	e.refund(t, false)
	var s: Country = gw.country_by_id(int(t.get("from", 0)))
	var res: String = String(t.get("res", ""))
	var n: int = int(t.get("n", 0))
	if s != null and n > 0 and Economy.TRADE_RES.has(res):
		s.set(res, int(s.get(res)) + n)
		e.stat_res(s, res, "trade", n)
	stats["jam_giveup"] = int(stats.get("jam_giveup", 0)) + 1
	var r: Country = gw.country_by_id(int(t.get("to", 0)))
	if (s != null and s.is_player) or (r != null and r.is_player):
		gw.say2(s, r, Loc.mk("Мост разрушен: груз (%s %d) не доставлен, деньги возвращены", [Loc.t(String(Economy.RES_NAMES.get(res, res)).to_lower()), n]))


func _jammed(b: Bridge, t: Dictionary) -> void :
	var n: int = 0
	for o: Dictionary in gw.econ.trucks:
		if int(o.get("jam", -1)) == b.id:
			n += 1
	if n < JAM_N or _jam_noted.has(b.id):
		return
	_jam_noted[b.id] = true
	var pos: Vector2 = b.center_px()
	var res: String = String(t.get("res", "goods"))
	_lane_add(int(t.get("from", 0)), int(t.get("to", 0)), 0.2)
	_add(res, float(ADD["jam"]), "пробки на мостах", pos)
	var city: String = _city_near(pos)
	note("jam", int(_br_by.get(b.id, 0)), int(t.get("to", 0)), res, pos, {"bridge": b.id, "n": n, "city": city, "from": int(t.get("from", 0))})
	_news(Loc.t("Пробка на мосту у %s · грузы стоят") % city if city != "" else Loc.t("Пробка у разрушенного моста · грузы стоят"), "amber")


func _city_near(p: Vector2) -> String:
	var best: String = ""
	var bd: float = 900.0
	for cy: City in gw.cities:
		var d: float = Vector2(cy.center * GameWorld.CELL).distance_to(p)
		if d < bd:
			bd = d
			best = cy.name
	return best




func cut_off(f: Facility) -> bool:
	if _cut.is_empty() or not _cut.has(f.id):
		return false
	if int(_cut[f.id]) >= 2:
		return true
	var k: bool = not bool(_flip.get(f.id, false))
	_flip[f.id] = k
	return k



func cut_level(f: Facility) -> int:
	return int(_cut.get(f.id, 0)) if not _cut.is_empty() else 0


func _recut() -> void :
	_cut_dirty = false
	var before: int = _cut.size()
	var old: Dictionary = _cut
	_cut = {}
	var broken: Array = []
	var sig: Array = []
	for b: Bridge in gw.bridges:
		if b.kind != Bridge.Kind.RAIL and not b.passable():
			broken.append([b.center_px(), b.pont == 2, b.id])
			sig.append(b.id)
	if sig != _cut_sig:
		_cut_sig = sig
		_cmemo.clear()
	if broken.is_empty() or gw.econ.nav == null:
		return
	var e: Economy = gw.econ
	var n_player: int = 0
	var n_slow_p: int = 0
	var slow0: int = 0
	for v: Variant in old.values():
		if int(v) == 1:
			slow0 += 1
	var memo: Dictionary = _cmemo
	var fresh: int = 0
	for f: Facility in gw.mil.facilities:
		if not PROD.has(f.kind) or not gw.mil.alive(f):
			continue
		var fp: Vector2 = f.center_px()
		var near: Array = []
		var nd: float = 900.0
		for bq: Array in broken:
			var dd: float = fp.distance_to(bq[0])
			if dd < nd:
				nd = dd
				near = bq
		if near.is_empty():
			continue
		var c: Country = gw.country_by_id(f.country_id)
		if c == null or c.capital_id < 0:
			continue
		var cap: Vector2 = Vector2(gw.cities[c.capital_id].entrance * GameWorld.CELL)
		var ca: Vector2i = e._nearest_open(e._nav_cell(fp))
		var cb: Vector2i = e._nearest_open(e._nav_cell(cap))
		var mk: = Vector4i(ca.x / 3, ca.y / 3, c.id, int(near[2]) + 1)
		if not memo.has(mk) and fresh >= 2:
			if old.has(f.id):
				_cut[f.id] = old[f.id]
			_cut_dirty = true
			continue
		if not memo.has(mk):


			var lv: int = 0
			if ca != cb:
				var straight: float = Vector2(ca).distance_to(Vector2(cb))
				var bc: Vector2i = e._nav_cell(near[0])
				var via: float = Vector2(ca).distance_to(Vector2(bc)) + Vector2(bc).distance_to(Vector2(cb))
				if via <= straight * 1.25 + 5.0 and not bool(near[1]):
					var ids: Array[Vector2i] = e.nav.get_id_path(ca, cb, false)
					var dab: Vector2i = (bc - ca).abs()
					var dbc: Vector2i = (cb - bc).abs()
					var via_c: float = float(maxi(dab.x, dab.y) + maxi(dbc.x, dbc.y))
					if ids.is_empty() or float(ids.size()) > maxf(straight * 2.5, straight + 125.0):
						lv = 2
					elif float(ids.size()) > via_c * SLOW_DETOUR + 4.0:
						lv = 1
			memo[mk] = lv
			fresh += 1
		if int(memo[mk]) == 0:
			continue
		if _city_port(c, fp):
			continue
		var lvl: int = mini(int(memo[mk]), 1) if bool(near[1]) else int(memo[mk])
		_cut[f.id] = lvl
		if c == gw.player:
			if lvl >= 2:
				n_player += 1
			else:
				n_slow_p += 1
	var slow1: int = 0
	for v2: Variant in _cut.values():
		if int(v2) == 1:
			slow1 += 1
	stats["cut_max"] = maxi(int(stats.get("cut_max", 0)), _cut.size() - slow1)
	stats["slow_max"] = maxi(int(stats.get("slow_max", 0)), slow1)
	if _cut.size() - slow1 > before - slow0:
		stats["cut_events"] = int(stats.get("cut_events", 0)) + 1
	if slow1 > slow0:
		stats["slow_events"] = int(stats.get("slow_events", 0)) + 1
	if n_player > 0 and _cut.size() - slow1 > before - slow0:
		gw.message.emit(Loc.msg(Loc.mk("Мост разрушен: %d объект(а) за рекой отрезаны — нет порта в городе", [n_player])))
	elif n_slow_p > 0 and slow1 > slow0:
		gw.message.emit(Loc.msg(Loc.mk("Мост разрушен: %d объект(а) за рекой — объезд, выпуск −50%%", [n_slow_p])))


func _city_port(c: Country, fp: Vector2) -> bool:
	var city: City = null
	var bd: float = INF
	for cid: int in c.city_ids:
		var cy: City = gw.cities[cid]
		var d: float = Vector2(cy.center * GameWorld.CELL).distance_to(fp)
		if d < bd and d <= float(cy.claim_max + 10) * GameWorld.CELL:
			bd = d
			city = cy
	if city == null:
		return false
	var cc: Vector2 = Vector2(city.center * GameWorld.CELL)
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.PORT and f.country_id == c.id and gw.mil.alive(f) and f.center_px().distance_to(cc) <= float(city.claim_max + 12) * GameWorld.CELL:
			return true
	return false




func _blockers() -> Array:
	var out: Array = []
	var nv: Navy = gw.get("navy") as Navy
	if nv == null:
		return out
	for fl: Dictionary in nv.fl.fleets:
		var o: Dictionary = fl.get("order", {})
		if String(o.get("k", "")) == "blockade":
			out.append(["f%d" % int(fl["id"]), int(fl["c"]), o, nv.fl.members(fl)])
	for s: Ship in nv.ships:
		if s.alive() and s.fleet == 0 and String(s.ord.get("k", "")) == "blockade":
			var one: Array[Ship] = [s]
			out.append(["s%d" % s.id, s.c, s.ord, one])
	return out


func _fac(id: int) -> Facility:
	for f: Facility in gw.mil.facilities:
		if f.id == id:
			return f
	return null


func _blockade_tick() -> void :
	var seen: Dictionary = {}
	for e: Array in _blockers():
		var key: String = e[0]
		var o: Dictionary = e[2]
		var port: Facility = _fac(int(o.get("port", -1)))
		var berth: Vector2 = o.get("pos", Vector2.ZERO)
		var on: bool = port != null and gw.mil.alive(port) and port.country_id == int(o.get("victim", -1)) and port.country_id != int(e[1])
		if on:
			on = false
			for s: Ship in e[3]:
				if s.alive() and s.pos.distance_to(berth) <= BLOCK_R:
					on = true
					break
		if not on:
			continue
		seen[key] = true
		if not blockades.has(key):
			var vc: Country = gw.country_by_id(port.country_id)
			var ac: Country = gw.country_by_id(int(e[1]))
			blockades[key] = {"c": int(e[1]), "victim": port.country_id, "port": port.id, "pos": berth, "since": gw.game_time, 
				"name": vc.name if vc != null else ""}
			zones.append({"pos": berth, "r": ZONE_R * 1.3, "level": 0.8, "why": "блокада", "blk": key})
			port_r[port.country_id] = minf(1.2, float(port_r.get(port.country_id, 0.0)) + 0.3)
			for r: String in COMMODITIES:
				_add(r, float(ADD["blockade_start"]) * (1.0 if r == "goods" or r == "oil" else 0.35), "блокада порта %s" % (vc.name if vc != null else ""), berth)
			note("blockade_start", int(e[1]), port.country_id, "", berth, {"port": port.id, "key": key})
			_news(Loc.msg(Loc.mk("БЛОКАДА ПОРТА %s · флот %s", [(vc.name if vc != null else "").to_upper(), ac.name if ac != null else "?"])), "alert_red", true)
			if vc != null and vc.is_player:
				gw.say(vc, Loc.mk("Ваш порт заблокирован флотом %s: суда разворачиваются", [Loc.name(ac.name) if ac != null else "?"]))
	for k: String in blockades.keys():
		if not seen.has(k):
			var bk: Dictionary = blockades[k]
			blockades.erase(k)
			for i in range(zones.size() - 1, -1, -1):
				if String((zones[i] as Dictionary).get("blk", "")) == k:
					zones.remove_at(i)
			note("blockade_end", int(bk["c"]), int(bk["victim"]), "", bk["pos"], {"port": int(bk["port"]), "len": gw.game_time - float(bk["since"])})
			_news(Loc.msg(Loc.mk("Блокада порта %s снята", [String(bk["name"])])), "grass_light")
	for k2: String in blockades:
		_enforce(blockades[k2])


func _enforce(bk: Dictionary) -> void :
	var pr: Ports = gw.econ.ports
	var c: int = int(bk["c"])
	var victim: int = int(bk["victim"])
	var berth: Vector2 = bk["pos"]
	for cs: Dictionary in pr.ships:
		if cs.has("turned"):
			continue
		var st: int = int(cs["stage"])
		var kind: String = String(cs["kind"])
		var inbound: bool = (st == 1 and int(cs["to"]) == victim and (kind == "trade" or kind == "import")) or (st == 2 and bool(cs.get("back", false)) and int(cs["owner"]) == victim)
		if not inbound:
			continue
		var owner: int = int(cs["owner"])
		if owner == c or (gw.get("navy") != null and gw.navy._hostile(c, owner)):
			continue
		if (cs["pos"] as Vector2).distance_to(berth) > TURN_R:
			continue
		_turn(cs, bk)



func _turn(cs: Dictionary, bk: Dictionary) -> void :
	var e: Economy = gw.econ
	var pr: Ports = e.ports
	var kind: String = String(cs["kind"])
	var res: String = String(cs["res"])
	var n: int = int(cs["n"])
	var victim: Country = gw.country_by_id(int(bk["victim"]))
	if kind == "trade" and int(cs["stage"]) == 1:
		e.refund(cs, false)
		var s: Country = gw.country_by_id(int(cs["from"]))
		if s != null and n > 0:
			s.set(res, int(s.get(res)) + n)
			e.stat_res(s, res, "trade", n)
	elif victim != null and n > 0:
		var back: int = int(cs["price"]) if kind == "import" and int(cs["stage"]) == 1 else e.foreign_buy_price(res) * n
		victim.money += back
		e.stat_add(victim, "spend", "import", - back)
	cs["n"] = 0
	cs["turned"] = true
	cs["back"] = false
	var path: PackedVector2Array = cs["path"]
	var here: = Vector2i(int((cs["pos"] as Vector2).x) / (Ports.K * GameWorld.CELL), int((cs["pos"] as Vector2).y) / (Ports.K * GameWorld.CELL))
	var goal: Vector2 = path[0]
	var np: PackedVector2Array = pr._path(here, Vector2i(int(goal.x) / (Ports.K * GameWorld.CELL), int(goal.y) / (Ports.K * GameWorld.CELL)))
	if np.is_empty():
		np = path.slice(0, mini(int(cs["i"]) + 1, path.size()))
		np.reverse()
	cs["path"] = np
	cs["i"] = 0
	cs["stage"] = 2
	stats["turned"] = int(stats.get("turned", 0)) + 1
	if victim != null:
		port_r[victim.id] = minf(1.2, float(port_r.get(victim.id, 0.0)) + 0.05)
	if n > 0:
		_add(res, float(ADD["turned"]), "блокада порта %s" % String(bk["name"]), bk["pos"])
	var me: Country = gw.player
	if me != null and n > 0 and (int(cs["owner"]) == me.id or int(bk["victim"]) == me.id or int(cs["from"]) == me.id):
		gw.message.emit(Loc.msg(Loc.mk("Блокада: судно с грузом (%s %d) развернулось, деньги возвращены", [Loc.t(String(Economy.RES_NAMES.get(res, res)).to_lower()), n])))







func _merch_tick() -> void :
	var e: Economy = gw.econ
	var pr: Ports = e.ports
	if pr == null or pr.ships.size() >= MERCH_MAX:
		return
	var out: Dictionary = {}
	for cs: Dictionary in pr.ships:
		if String(cs["kind"]) == "trade" and int(cs["stage"]) < 2:
			var k: String = "%d>%d" % [int(cs["from"]), int(cs["to"])]
			out[k] = int(out.get(k, 0)) + 1
	var sent: int = 0
	var keys: Array = e.trade.keys()
	var off: int = int(gw.game_time / MERCH_DT) % maxi(1, keys.size())
	var navy_foe: Dictionary = {}
	if gw.get("navy") != null:
		for c: Country in gw.countries:
			for foe: int in c.at_war:
				if not gw.navy.ships_of(foe).is_empty():
					navy_foe[c.id] = true
					break
	for j in keys.size():
		var ab: PackedStringArray = String(keys[(j + off) % keys.size()]).split(":")
		var a: Country = gw.country_by_id(int(ab[0]))
		var b: Country = gw.country_by_id(int(ab[1]))
		if a == null or b == null or a.eliminated or b.eliminated or not pr.can_sail(a, b):
			continue
		for dir in 2:
			var s: Country = a if dir == 0 else b
			var r: Country = b if dir == 0 else a
			var wl: int = want_lanes(s, r)
			if navy_foe.has(s.id) or navy_foe.has(r.id):
				wl = maxi(1, wl / 2)
			if int(out.get("%d>%d" % [s.id, r.id], 0)) >= wl:
				continue
			if route_risk(s.id, r.id) >= MERCH_HOLD:
				stats["merch_held"] = int(stats.get("merch_held", 0)) + 1
				continue

			var dk: String = "%d>%d" % [s.id, r.id]
			if gw.game_time < float(_next_dep.get(dk, -1.0)):
				continue
			if _merchant(s, r):
				var lead: Dictionary = pr.ships[pr.ships.size() - 1]
				var trip: float = pr.sea_dist(s, r) / Ports.SHIP_SPEED
				var jit: float = 0.75 + 0.5 * float(Hash32.h2(s.id, r.id, int(gw.game_time)) % 100) / 100.0
				_next_dep[dk] = gw.game_time + clampf(trip / (float(wl) * 2.0), DEP_MIN, DEP_MAX) * jit
				sent += 1

				if wl >= 3 and Hash32.h2(s.id, r.id, int(lead["id"])) % 3 == 0 and pr.ships.size() < MERCH_MAX and _merchant(s, r):
					var mate: Dictionary = pr.ships[pr.ships.size() - 1]
					mate["grp"] = int(lead["id"])
					mate["t"] = float(mate["t"]) + GRP_DELAY
					_lane_offset(mate, 1)
					stats["merch_groups"] = int(stats.get("merch_groups", 0)) + 1
					sent += 1
				if sent >= MERCH_PER_TICK or pr.ships.size() >= MERCH_MAX:
					return






func _lane_offset(cs: Dictionary, lane: int = 0) -> void :
	if not cs.has("base"):
		cs["base"] = cs["path"]
	cs["lane"] = lane
	var path: PackedVector2Array = cs["base"]
	var n: int = path.size()
	if n < 8:
		return
	var off: float = - LANE_W * float(1 + lane)
	var pr: Ports = gw.econ.ports
	var out: = PackedVector2Array(path)
	var cpx: float = float(Ports.K * GameWorld.CELL)
	for i in range(3, n - 3):
		var d: Vector2 = (path[i + 2] - path[i - 2]).normalized()
		var ramp: float = minf(1.0, minf(float(i - 2), float(n - 3 - i)) / 3.0)
		var q: Vector2 = path[i] + d.orthogonal() * off * ramp
		var qc: = Vector2i(int(q.x / cpx), int(q.y / cpx))
		if pr.sea.region.has_point(qc) and not pr.sea.is_point_solid(qc):
			out[i] = q
	cs["path"] = out



func relane(cs: Dictionary) -> void :
	if not cs.has("base"):
		return
	var b: PackedVector2Array = cs["base"]
	var rb: = PackedVector2Array()
	for i in range(b.size() - 1, -1, -1):
		rb.append(b[i])
	cs["base"] = rb
	cs["path"] = rb
	_lane_offset(cs, int(cs.get("lane", 0)))






func _separate() -> void :
	var ships: Array = gw.econ.ports.ships
	var grid: Dictionary = {}
	for i in ships.size():
		var cs: Dictionary = ships[i]
		if int(cs["stage"]) == 0:
			continue
		var k: = Vector2i((cs["pos"] as Vector2) / 64.0)
		if not grid.has(k):
			grid[k] = []
		(grid[k] as Array).append(i)
	for i in ships.size():
		var a: Dictionary = ships[i]
		a["spf"] = 1.0
		if int(a["stage"]) == 0:
			continue
		var path: PackedVector2Array = a["path"]
		var pa: Vector2 = a["pos"]
		if path.is_empty() or pa.distance_to(path[path.size() - 1]) < 70.0 or pa.distance_to(path[0]) < 30.0:
			continue
		var hd: = Vector2.from_angle(float(a["heading"]))
		var k0: = Vector2i(pa / 64.0)
		var f: float = 1.0
		var amin: float = INF
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				for j: int in grid.get(k0 + Vector2i(dx, dy), []):
					if j == i:
						continue
					var b: Dictionary = ships[j]
					var rel: Vector2 = (b["pos"] as Vector2) - pa
					var ahead: float = rel.dot(hd)
					if ahead <= 0.0 or ahead > SEP_AHEAD or absf(rel.cross(hd)) > SEP_LAT:
						continue
					var hb: = Vector2.from_angle(float(b["heading"]))
					if hb.dot(hd) < -0.3:
						continue
					if int(a["id"]) < int(b["id"]) and ( - rel).dot(hb) > 0.0 and absf(( - rel).cross(hb)) <= SEP_LAT:
						continue
					var hold: float = SEP_GROUP if int(a.get("grp", -1)) == int(b["id"]) else SEP_HOLD
					f = minf(f, clampf((ahead - hold) / (SEP_AHEAD - hold), 0.0, 1.0))
					amin = minf(amin, ahead)
		if f < 0.05:
			a["held"] = float(a.get("held", 0.0)) + SEP_DT
			if float(a["held"]) > SEP_WAIT * 2.0:
				f = 0.6
			elif float(a["held"]) > SEP_WAIT:
				f = clampf((amin - 24.0) / 30.0, 0.0, 0.5)
		else:
			a["held"] = 0.0
		a["spf"] = f



func want_lanes(s: Country, r: Country) -> int:
	var v: float = float(s.city_ids.size() + r.city_ids.size()) + float(s.trade_income + r.trade_income) / 20000.0
	return clampi(1 + int(v / 4.0), 1, 4)


func _merchant(s: Country, r: Country) -> bool:
	var e: Economy = gw.econ
	if s.is_player and e.export_off.has(s.id):
		return false
	var best: String = ""
	var bv: float = 0.0
	for res: String in Economy.TRADE_RES:
		var spare: int = e.surplus(s, res)
		var room: int = e.room_for(r, res)
		var needed: bool = e.need(r, res) > e.inbound(r, res)
		if spare < 4 or room < 4 or (r.is_player and not needed) or e.trd.res_blocked(s.id, r.id, res):
			continue
		var v: float = float(mini(spare, room)) * float(e.market_price(res)) * (2.0 if needed else 1.0)
		if v > bv:
			bv = v
			best = res
	if best == "":
		return false
	var unit: int = maxi(1, roundi(e.market_price(best) * gw.diplo.trade_mul(r.id, s.id)))
	var n: int = clampi(mini(e.surplus(s, best) / 2, e.room_for(r, best)), 3, 12)
	n = mini(n, (r.money - (300 if r.is_player else 900)) / unit)
	if n < 3:
		return false
	var price: int = unit * n
	s.set(best, int(s.get(best)) - n)
	e.stat_res(s, best, "trade", - n)
	r.money -= price
	e.stat_add(r, "spend", "trade", price)
	if not e.ports.send_trade(s, r, best, n, price):
		s.set(best, int(s.get(best)) + n)
		e.stat_res(s, best, "trade", n)
		r.money += price
		e.stat_add(r, "spend", "trade", - price)
		return false
	var ms: Dictionary = e.ports.ships[e.ports.ships.size() - 1]
	ms["m"] = true
	_lane_offset(ms)
	stats["merchants"] = int(stats.get("merchants", 0)) + 1
	return true






func _land_tick() -> void :
	var e: Economy = gw.econ
	if e == null or e.nav == null or e.trade.is_empty():
		return
	var n: int = 0
	var out: Dictionary = {}
	for t: Dictionary in e.trucks:
		if int(t["from"]) != int(t["to"]):
			n += 1
			if bool(t.get("m", false)):
				var k: String = "%d>%d" % [int(t["from"]), int(t["to"])]
				out[k] = int(out.get(k, 0)) + 1
	if n >= LAND_MAX:
		return
	var keys: Array = e.trade.keys()
	var off: int = int(gw.game_time / LAND_DT) % keys.size()
	var astar: int = 0
	var tries: int = 0
	for j in keys.size():
		var key: String = String(keys[(j + off) % keys.size()])
		var ab: PackedStringArray = key.split(":")
		var a: Country = gw.country_by_id(int(ab[0]))
		var b: Country = gw.country_by_id(int(ab[1]))
		if a == null or b == null or a.eliminated or b.eliminated or a.capital_id < 0 or b.capital_id < 0:
			continue
		var lp: Array = _lpath.get(key, [])

		if lp.is_empty() or gw.game_time - float(lp[0]) > LAND_PATH_T + float(Hash32.h2(a.id, b.id, 7) % 90):
			if _lb_st < 0 and astar == 0 and gw.game_time - _lb_t >= 1.0:
				astar = 1
				_lb_start(key, a, b)
			if lp.is_empty():
				continue
		var route: PackedVector2Array = lp[1]
		if route.size() < 2:
			continue
		for dir in 2:
			var s: Country = a if dir == 0 else b
			var r: Country = b if dir == 0 else a
			var lanes: int = 1 if (s.is_player or r.is_player) else mini(LAND_LANES, want_lanes(s, r))
			if int(out.get("%d>%d" % [s.id, r.id], 0)) >= lanes or route_risk(s.id, r.id) >= MERCH_HOLD:
				continue
			var p2: PackedVector2Array = route
			var start: Vector2 = lp[2]
			if dir == 1:
				p2 = PackedVector2Array()
				for i in range(route.size() - 1, -1, -1):
					p2.append(route[i])
				start = Vector2(gw.cities[b.capital_id].entrance * GameWorld.CELL)
			tries += 1
			if _caravan(s, r, p2, start) or tries >= 3:
				return


func _lb_start(key: String, a: Country, b: Country) -> void :
	var e: Economy = gw.econ
	_lb_key = key
	_lb_ab = [a.id, b.id]
	_lb_pa = Vector2(gw.cities[a.capital_id].entrance * GameWorld.CELL)
	_lb_pb = Vector2(gw.cities[b.capital_id].entrance * GameWorld.CELL)
	_lb_ca = e._nearest_open(e._nav_cell(_lb_pa))
	_lb_cb = e._nearest_open(e._nav_cell(_lb_pb))
	_lb_st = 0



func _lb_step() -> void :
	if _lb_st < 0:
		return
	var fr: int = gw.net_tick if gw.net_driven else (GameWorld.lab_tick if GameWorld.lab_tick >= 0 else Engine.get_process_frames())
	if fr != _lb_fr:
		_lb_fr = fr
		_lb_us = 0
		_net_ops = 0
	if _over():
		return
	var e: Economy = gw.econ
	if e == null or e.nav == null:
		_lb_st = -1
		return
	var t0: int = Time.get_ticks_usec()
	var lim: int = t0 + LB_BUDGET - _lb_us
	if _lb_st == 0:
		if _lb_task >= 0:
			if not gw.job_ready(_lb_task):
				_lb_us += Time.get_ticks_usec() - t0
				return
			WorkerThreadPool.wait_for_task_completion(_lb_task)
			_lb_task = -1
			_lb_ids.clear()
			if not _lb_box.is_empty():
				_lb_ids.assign(_lb_box[0])
			_lb_box = []
			if _lb_ids.is_empty() or _lb_ids[_lb_ids.size() - 1] != _lb_cb:
				_lb_finish(PackedVector2Array())
			else:
				_lb_st = 1
				_lb_i = 1
				_lb_out = PackedVector2Array()
				_lb_used = {}
		elif _pg_copy(e, lim):
			_lb_box = []
			_lb_task = WorkerThreadPool.add_task(Supply._lb_worker.bind(_pg, _lb_ca, _lb_cb, _lb_box), false, "caravan route")
	elif _lb_st == 1:
		var k: float = float(Economy.NAV_K * GameWorld.CELL)
		while _lb_i < _lb_ids.size() and _t_ok(lim):
			var q: Vector2i = _lb_ids[_lb_i]
			_lb_i += 1
			var br: Bridge = e._bridge_in(q)
			if br != null and _lb_used.has(br):
				continue
			if br != null:
				var prev: Vector2 = _lb_out[_lb_out.size() - 1] if not _lb_out.is_empty() else _lb_pa
				var nxt: Vector2 = _lb_pb
				for j in range(_lb_i, _lb_ids.size()):
					if e._bridge_in(_lb_ids[j]) != br:
						nxt = Vector2(_lb_ids[j]) * k + Vector2(k * 0.5, k * 0.5)
						break
				var deck: PackedVector2Array = e._deck_points(br, prev)
				if deck.size() >= 2 and nxt.distance_squared_to(deck[deck.size() - 1]) < nxt.distance_squared_to(deck[0]):
					_lb_used[br] = true
					_lb_out.append_array(deck)
					continue
			_lb_out.append(e._land_center(q))
		if _lb_i >= _lb_ids.size():
			_lb_out.append(_lb_pb)
			_lb_st = 2
			_lb_i = 0
			_lb_prev = _lb_pa
			_lb_dry = PackedVector2Array()
	else:
		while _lb_i < _lb_out.size() and _t_ok(lim):
			e._dry_leg(_lb_prev, _lb_out[_lb_i], _lb_dry, 0)
			_lb_prev = _lb_out[_lb_i]
			_lb_i += 1
		if _lb_i >= _lb_out.size():
			var path: PackedVector2Array = _lb_dry
			var a: Country = gw.country_by_id(int(_lb_ab[0]))
			var b: Country = gw.country_by_id(int(_lb_ab[1]))
			if a != null and b != null and e.ports.can_sail(a, b) and e.ports.sea_dist(a, b) < e._plen(_lb_pa, path) * 0.8:
				path = PackedVector2Array()
			_lb_finish(path)
	_lb_us += Time.get_ticks_usec() - t0
	stats["lb_max_us"] = maxi(int(stats.get("lb_max_us", 0)), _lb_us)




static func _lb_worker(g: AStarGrid2D, ca: Vector2i, cb: Vector2i, box: Array) -> void :
	box.append(g.get_id_path(ca, cb, true))





func _pg_copy(e: Economy, lim: int) -> bool:
	var nav: AStarGrid2D = e.nav
	if _pg == null or _pg.region != nav.region:
		_pg = AStarGrid2D.new()
		_pg.region = nav.region
		_pg.cell_size = nav.cell_size
		_pg.diagonal_mode = nav.diagonal_mode
		_pg.default_compute_heuristic = nav.default_compute_heuristic
		_pg.default_estimate_heuristic = nav.default_estimate_heuristic
		_pg.update()
		_pg_row = 0
		_pg_ver = e._nav_ver
		_pg_t = gw.game_time
		return false
	if _pg_row < 0 and e._nav_ver != _pg_ver and gw.game_time - _pg_t > 60.0:
		_pg_row = 0
		_pg_ver = e._nav_ver
		_pg_t = gw.game_time
	if _pg_row < 0:
		return true
	var r: Rect2i = nav.region
	while _pg_row < r.size.y and _t_ok(lim):
		var y: int = r.position.y + _pg_row
		for x in range(r.position.x, r.end.x):
			var q: = Vector2i(x, y)
			var so: bool = nav.is_point_solid(q)
			_pg.set_point_solid(q, so)
			if not so:
				_pg.set_point_weight_scale(q, nav.get_point_weight_scale(q))
		_pg_row += 1
	if _pg_row >= r.size.y:
		_pg_row = -1
		return true
	return false



func _lb_wait() -> void :
	if _lb_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_lb_task)
		_lb_task = -1
	_lb_box = []



func drain() -> void :
	_lb_wait()
	_lb_st = -1
	_pg = null
	_pg_row = -1


func _notification(what: int) -> void :
	if what == NOTIFICATION_PREDELETE and _lb_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_lb_task)


func _lb_finish(path: PackedVector2Array) -> void :
	_lpath[_lb_key] = [gw.game_time, path, _lb_pa]
	_lb_st = -1
	_lb_t = gw.game_time
	_lb_ids = []
	_lb_out = PackedVector2Array()
	_lb_dry = PackedVector2Array()
	_lb_used = {}


func _caravan(s: Country, r: Country, path: PackedVector2Array, start: Vector2) -> bool:
	var e: Economy = gw.econ
	if s.is_player and e.export_off.has(s.id):
		return false
	if gw.diplo.at_war(s.id, r.id) or gw.diplo.embargo_between(s.id, r.id):
		return false
	var best: String = ""
	var bv: float = 0.0
	for res: String in Economy.TRADE_RES:
		var spare: int = e.surplus(s, res)
		var room: int = e.room_for(r, res)
		var needed: bool = e.need(r, res) > e.inbound(r, res)
		if spare < 4 or room < 4 or (r.is_player and not needed) or e.trd.res_blocked(s.id, r.id, res):
			continue
		var v: float = float(mini(spare, room)) * float(e.market_price(res)) * (2.0 if needed else 1.0)
		if v > bv:
			bv = v
			best = res
	if best == "":
		return false
	var unit: int = maxi(1, roundi(e.market_price(best) * gw.diplo.trade_mul(r.id, s.id)))
	var n: int = clampi(mini(e.surplus(s, best) / 2, e.room_for(r, best)), 3, Economy.TRUCK_LOAD)
	n = mini(n, (r.money - (300 if r.is_player else 900)) / unit)
	if n < 3:
		return false
	var price: int = unit * n
	s.set(best, int(s.get(best)) - n)
	e.stat_res(s, best, "trade", - n)
	r.money -= price
	e.stat_add(r, "spend", "trade", price)
	e.trucks.append({"from": s.id, "to": r.id, "res": best, "n": n, "path": PackedVector2Array(path), "i": 0, "pos": start, "heading": 0.0, "frame": 0, "id": e._truck_id, "price": price, "m": true})
	e._truck_id += 1
	stats["caravans"] = int(stats.get("caravans", 0)) + 1
	return true




func _reroute_tick() -> void :
	var pr: Ports = gw.econ.ports
	if pr == null or pr.sea == null:
		return

	var want: Dictionary = {}
	var cs_px: float = float(Ports.K * GameWorld.CELL)
	var sig: Array = []
	for z0: Dictionary in zones:
		if float(z0["level"]) >= ZONE_AVOID:
			sig.append([Vector2i((z0["pos"] as Vector2) / 32.0), roundi(minf(float(z0["level"]), 1.0) * 4.0)])
	if sig == _zsig:
		_ships_reroute(cs_px)
		return
	_zsig = sig

	var zl: Array = []
	for z: Dictionary in zones:
		if float(z["level"]) >= ZONE_AVOID:
			zl.append([z["pos"], float(z["r"]), roundf(minf(float(z["level"]), 1.0) * 4.0) / 4.0])
	_wjob = {"zones": zl, "zi": 0, "want": {}, "ph": 0, "keys": [], "ki": 0, "dirty": false}




func _wjob_step() -> void :
	var pr: Ports = gw.econ.ports
	if pr == null or pr.sea == null:
		_wjob = {}
		return
	var cs_px: float = float(Ports.K * GameWorld.CELL)
	var want: Dictionary = _wjob["want"]
	match int(_wjob["ph"]):
		0:
			var zl: Array = _wjob["zones"]
			var zi: int = int(_wjob["zi"])
			if zi >= zl.size():
				_wjob["ph"] = 1
				_wjob["keys"] = _weighted.keys()
				_wjob["ki"] = 0
				return
			var zp: Vector2 = zl[zi][0]
			var lv: float = float(zl[zi][2])
			var rc: int = int(float(zl[zi][1]) / cs_px)
			var c0: = Vector2i(int(zp.x / cs_px), int(zp.y / cs_px))
			var wv0: float = 1.0 + ZONE_W * minf(lv, 1.0)
			for y in range(c0.y - rc, c0.y + rc + 1):
				var dy: int = y - c0.y
				var hw: int = int(sqrt(float(rc * rc - dy * dy)))
				for x in range(c0.x - hw, c0.x + hw + 1):
					var q: = Vector2i(x, y)
					if pr.sea.region.has_point(q) and float(want.get(q, 1.0)) < wv0:
						want[q] = wv0
			_wjob["zi"] = zi + 1
		1:
			var keys: Array = _wjob["keys"]
			var ki: int = int(_wjob["ki"])
			var end: int = mini(ki + 600, keys.size())
			for i in range(ki, end):
				var q2: Vector2i = keys[i]
				if not want.has(q2):
					_wjob["dirty"] = true
					if not pr.sea.is_point_solid(q2):
						pr.sea.set_point_weight_scale(q2, 1.0)
					_weighted.erase(q2)
			_wjob["ki"] = end
			if end >= keys.size():
				_wjob["ph"] = 2
				_wjob["keys"] = want.keys()
				_wjob["ki"] = 0
		2:
			var keys2: Array = _wjob["keys"]
			var ki2: int = int(_wjob["ki"])
			var end2: int = mini(ki2 + 600, keys2.size())
			for i2 in range(ki2, end2):
				var q3: Vector2i = keys2[i2]
				var wv: float = float(want[q3])
				if absf(float(_weighted.get(q3, 1.0)) - wv) > 0.01 and not pr.sea.is_point_solid(q3):
					_wjob["dirty"] = true
					pr.sea.set_point_weight_scale(q3, wv)
					_weighted[q3] = wv
			_wjob["ki"] = end2
			if end2 >= keys2.size():
				if not bool(_wjob["dirty"]):
					_wjob = {}
					return
				_wjob["ph"] = 3
				_wjob["keys"] = pcache.keys()
				_wjob["ki"] = 0
		3:

			var keys3: Array = _wjob["keys"]
			var ki3: int = int(_wjob["ki"])
			var end3: int = mini(ki3 + 30, keys3.size())
			for i3 in range(ki3, end3):
				if not pcache.has(keys3[i3]):
					continue
				var pp: PackedVector2Array = pcache[keys3[i3]][2]
				for j in range(0, pp.size(), 3):
					if _weighted.has(Vector2i(int(pp[j].x / cs_px), int(pp[j].y / cs_px))):
						pcache.erase(keys3[i3])
						break
			_wjob["ki"] = end3
			if end3 >= keys3.size():
				_wjob = {}



func _ships_reroute(cs_px: float) -> void :
	if _weighted.is_empty():
		return
	var pr: Ports = gw.econ.ports
	var now: float = gw.game_time
	var budget: int = 1
	for cs: Dictionary in pr.ships:
		var st: int = int(cs["stage"])
		if st == 0 or now - float(cs.get("rr", -999.0)) < REROUTE_GAP:
			continue
		if budget <= 0:
			return
		var path: PackedVector2Array = cs["path"]
		var i: int = int(cs["i"])
		var pos: Vector2 = cs["pos"]
		if _in_zone(pos, 0.0):
			continue
		var hit: bool = false
		for j in range(i, mini(i + 60, path.size()), 3):
			if _in_zone(path[j], 0.0):
				hit = true
				break
		if not hit:
			continue
		cs["rr"] = now
		budget -= 1
		var here: = Vector2i(int(pos.x / cs_px), int(pos.y / cs_px))
		var end: Vector2 = path[path.size() - 1]
		var np: PackedVector2Array = pr._path(here, Vector2i(int(end.x / cs_px), int(end.y / cs_px)))
		if np.size() < 2:
			continue
		var bad: bool = false
		for j2 in range(0, mini(60, np.size()), 3):
			if _in_zone(np[j2], 0.0):
				bad = true
				break
		if bad:
			continue
		cs["path"] = np
		cs["i"] = 0
		if cs.has("base"):
			cs["base"] = np
			_lane_offset(cs, int(cs.get("lane", 0)))
		var oc: Country = gw.country_by_id(int(cs["owner"]))
		stats["reroutes"] = int(stats.get("reroutes", 0)) + 1
		if oc != null and not oc.is_player:
			stats["reroutes_ai"] = int(stats.get("reroutes_ai", 0)) + 1


func _in_zone(p: Vector2, pad: float) -> bool:
	for z: Dictionary in zones:
		if float(z["level"]) >= ZONE_AVOID and (z["pos"] as Vector2).distance_to(p) <= float(z["r"]) + pad:
			return true
	return false





func _ai_tick() -> void :
	var e: Economy = gw.econ
	for c: Country in gw.countries:
		if c.is_player or c.eliminated or c.capital_id < 0 or not e.ports.has_port(c):
			continue
		var hit: bool = blockaded(c.id) or float(port_r.get(c.id, 0.0)) >= 0.6
		if not hit or gw.game_time - float(_alt.get(c.id, -999.0)) < 150.0:
			continue
		var n: int = 0
		for f: Facility in gw.mil.facilities:
			if f.kind == Facility.Kind.PORT and f.country_id == c.id and gw.mil.alive(f):
				n += 1
		if n >= 3 or c.money < Military.cost_of(Facility.Kind.PORT) + 1500 or _alt_c >= 0:
			continue
		_alt[c.id] = gw.game_time
		_alt_c = c.id
		_alt_i = 0
		_alt_scan = []
		return





func _alt_step() -> void :
	var c: Country = gw.country_by_id(_alt_c)
	if c == null or c.eliminated or c.capital_id < 0:
		_alt_c = -1
		return
	var fr: int = gw.net_tick if gw.net_driven else (GameWorld.lab_tick if GameWorld.lab_tick >= 0 else Engine.get_process_frames())
	if fr != _lb_fr:
		_lb_fr = fr
		_lb_us = 0
		_net_ops = 0
	if _over():
		return
	var t0: int = Time.get_ticks_usec()
	var lim: int = t0 + LB_BUDGET - _lb_us
	var d: WorldData = gw.data
	var sig: int = 0
	for cid: int in c.city_ids:
		sig = sig * 31 + cid * 7 + gw.cities[cid].claim_max
	var ce: Array = _alt_cand.get(c.id, [])
	if ce.is_empty() or int(ce[0]) != sig:

		if _alt_scan.is_empty():
			_alt_scan = [0, -99999]
			_alt_cells = []
		while _t_ok(lim):
			var j: int = int(_alt_scan[0])
			if j >= c.city_ids.size():
				_alt_cand[c.id] = [sig, _alt_cells]
				_alt_scan = []
				break
			var city: City = gw.cities[c.city_ids[j]]
			var r: int = city.claim_max + 4
			var y: int = int(_alt_scan[1])
			if y == -99999:
				y = city.center.y - r
			if y >= city.center.y + r:
				_alt_scan = [j + 1, -99999]
				continue
			for x in range(city.center.x - r, city.center.x + r, 3):
				if not d.inside(x, y) or d.get_owner_id(x, y) != c.id or Biome.is_water(d.get_biome(x, y)):
					continue
				for q: Vector2i in [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4), Vector2i(6, 0), Vector2i(-6, 0), Vector2i(0, 5), Vector2i(0, -5)]:
					if d.inside(x + q.x, y + q.y) and Biome.is_water(d.get_biome(x + q.x, y + q.y)):
						_alt_cells.append(Vector2i(x, y))
						break
			_alt_scan = [j, y + 3]
		_lb_us += Time.get_ticks_usec() - t0
		return
	var cells: Array = ce[1]
	while _alt_i < cells.size() and _t_ok(lim):
		var cen: Vector2i = cells[_alt_i]
		_alt_i += 1
		if alt_avoid(c, cen) or d.get_owner_id(cen.x, cen.y) != c.id:
			continue
		if gw.mil.check_place(Facility.Kind.PORT, Military.nw_for(Facility.Kind.PORT, cen), c, null, false) == "":
			if gw.mil.build(Facility.Kind.PORT, cen, c, null, true) != null:
				stats["alt_ports"] = int(stats.get("alt_ports", 0)) + 1
			_alt_c = -1
			break
	if _alt_c >= 0 and _alt_i >= cells.size():
		_alt_c = -1
	_lb_us += Time.get_ticks_usec() - t0
	stats["alt_max_us"] = maxi(int(stats.get("alt_max_us", 0)), Time.get_ticks_usec() - t0)



func alt_avoid(c: Country, cell: Vector2i) -> bool:
	if not _alt.has(c.id) or gw.game_time - float(_alt[c.id]) > 120.0:
		return false
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.PORT and f.country_id == c.id and gw.mil.alive(f) and (f.cell - cell).length_squared() < 110 * 110:
			return true
	return false




func ai_bridge_pick(c: Country, foe: Country, from: Vector2, max_d: float) -> Array:
	if gw.diplo != null and gw.diplo.has_method("react_restrained") and gw.diplo.react_restrained(c.id, foe.id, -1, "bridge"):
		return []
	var now: float = gw.game_time
	stats["ai_bridge_looks"] = int(stats.get("ai_bridge_looks", 0)) + 1
	if now - float(_br_pick.get(c.id, -999.0)) < float(BR_GAP[GameConfig.diff_of(c)]):
		return []
	var P: Dictionary = gw.ai.persona_of(c) if gw.ai != null else {}
	var w: float = 1.4 + 1.2 * float(P.get("aggr", 0.5)) + 0.6 * float(P.get("sneaky", 0.3)) - 0.6 * float(P.get("caution", 0.3))
	var cap: Vector2 = Vector2(gw.cities[foe.capital_id].center * GameWorld.CELL) if foe.capital_id >= 0 else Vector2.INF
	var best: Bridge = null
	var bs: float = -1.0
	for b: Bridge in gw.bridges:
		if b.kind == Bridge.Kind.RAIL or not b.passable() or now - float(_br_down_t.get(b.id, -999.0)) < 300.0:
			continue
		var p: Vector2 = b.center_px()
		var d: float = p.distance_to(from)
		if d > max_d:
			continue
		if _bridge_owner(b) != foe.id:
			continue
		var use: int = 0
		for t: Dictionary in gw.econ.trucks:
			if (int(t["from"]) == foe.id or int(t["to"]) == foe.id) and (t["pos"] as Vector2).distance_to(p) < 600.0:
				use += 1
		var near_cap: bool = cap.is_finite() and p.distance_to(cap) < 1500.0
		var in_city: bool = near_cap
		if not in_city:
			for cid: int in foe.city_ids:
				if Vector2(gw.cities[cid].center * GameWorld.CELL).distance_to(p) < float(gw.cities[cid].claim_max) * GameWorld.CELL + 200.0:
					in_city = true
					break
		if use == 0 and not in_city:
			continue
		var sc: float = w * 1000.0 + float(use) * 150.0 + (200.0 if near_cap else 0.0) - d * 0.1 + float(Hash32.h2(c.id, b.id, int(now / 60.0)) % 300)
		if sc > bs and gw.ai != null and gw.ai.get("sense") != null and gw.ai.sense.bridge_veto(c, b) != "":
			continue
		if sc > bs:
			bs = sc
			best = b
	if best == null:
		return []
	return [bs, best.center_px(), best.id]



func _bridge_owner(b: Bridge) -> int:
	for c: Vector2i in [b.cells[b.cells.size() / 2], b.cells[0], b.cells[b.cells.size() - 1]]:
		var o: int = gw.data.get_owner_id(c.x, c.y)
		if o > 0:
			return o
	return 0



func war_trade_target(c: Country) -> bool:
	if c.at_war.is_empty() or gw.econ == null:
		return false
	var p: Facility = gw.econ.ports.port_of(c)
	if p == null:
		return false
	var pp: Vector2 = p.center_px()
	for cs: Dictionary in gw.econ.ports.ships:
		if c.at_war.has(int(cs["owner"])) and (cs["pos"] as Vector2).distance_to(pp) < 4000.0:
			return true
	return false



func ai_bridge_used(c: Country) -> void :
	_br_pick[c.id] = gw.game_time
	stats["ai_bridge_strikes"] = int(stats.get("ai_bridge_strikes", 0)) + 1





const BLK_MAX: float = 300.0
const BLK_REST: float = 240.0
func ai_blockade_want(c: Country, mem: Array, home: Vector2) -> Dictionary:
	if mem.size() < 2 or gw.get("navy") == null:
		return {}
	var nv: Navy = gw.navy
	var now: float = gw.game_time
	var st: Array = _ai_blk.get(c.id, [-1.0, -1, -1.0])
	if now < float(st[2]):
		return {}
	var P: Dictionary = gw.ai.persona_of(c) if gw.ai != null else {}
	var drive: float = 1.2 * float(P.get("aggr", 0.5)) + 0.15 * float(GameConfig.diff_of(c)) - 0.8 * float(P.get("caution", 0.3))
	if drive < 0.5:
		return {}
	if float(st[0]) >= 0.0 and now - float(st[0]) > BLK_MAX:
		_ai_blk[c.id] = [-1.0, -1, now + BLK_REST]
		return {}
	var lead: Ship = mem[0]
	var body: int = nv._body_px(lead.pos)
	var best: Facility = null
	var bd: float = 7000.0
	for f: Facility in gw.mil.facilities:
		if f.kind != Facility.Kind.PORT or not gw.mil.alive(f) or not nv._hostile(c.id, f.country_id):
			continue
		if gw.diplo != null and gw.diplo.has_method("react_restrained") and gw.diplo.react_restrained(c.id, f.country_id, -1, "blockade"):
			continue
		var bp: Vector2 = f.center_px()
		var q: Vector2i = nv._sea_near(bp, 14, body)
		if q.x < 0:
			continue
		var d: float = bp.distance_to(home)
		if d >= bd:
			continue
		var guards: int = 0
		for e: Ship in nv.ships:
			if e.alive() and e.c == f.country_id and e.pos.distance_to(bp) < 1500.0:
				guards += 1
		if guards * 2 > mem.size() or (mem.size() < 3 and guards > 0):
			continue
		bd = d
		best = f
	if best == null:
		_ai_blk[c.id] = [-1.0, -1, -1.0]
		return {}
	if int(st[1]) != best.id:
		_ai_blk[c.id] = [now, best.id, -1.0]
	return {"k": "blockade", "pos": best.center_px()}




func save_state() -> Dictionary:
	var bl: Dictionary = {}
	for k: String in blockades:
		bl[k] = (blockades[k] as Dictionary).duplicate()
	return {"v": 1, "raw": raw.duplicate(), "lane": lane.duplicate(), "port_r": port_r.duplicate(), "zones": zones.duplicate(true), 
		"hist": hist.duplicate(), "crisis": crisis.duplicate(true), "blockades": bl, "stats": stats.duplicate(), "why": why.duplicate(true), 
		"br_by": _br_by.duplicate(), "ai_blk": _ai_blk.duplicate(true), "alt": _alt.duplicate()}


func load_state(d: Dictionary) -> void :
	raw = _fdict(d.get("raw", {}))
	lane = _fdict(d.get("lane", {}))
	port_r = {}
	var pr: Variant = d.get("port_r", {})
	if pr is Dictionary:
		for k: Variant in pr:
			port_r[int(k)] = clampf(float(pr[k]), 0.0, 1.2)
	zones.clear()
	var zs: Variant = d.get("zones", [])
	if zs is Array:
		for z: Variant in zs:
			if z is Dictionary and (z as Dictionary).get("pos") is Vector2:
				zones.append(z)
	var h: Variant = d.get("hist", {})
	for c: String in COMMODITIES:
		var v: Variant = (h as Dictionary).get(c) if h is Dictionary else null
		hist[c] = v if v is PackedFloat32Array else PackedFloat32Array()
	crisis = (d.get("crisis", {}) as Dictionary).duplicate(true) if d.get("crisis", {}) is Dictionary else {}
	blockades = (d.get("blockades", {}) as Dictionary).duplicate(true) if d.get("blockades", {}) is Dictionary else {}
	stats = (d.get("stats", {}) as Dictionary).duplicate() if d.get("stats", {}) is Dictionary else {}
	why = (d.get("why", {}) as Dictionary).duplicate(true) if d.get("why", {}) is Dictionary else {}
	_br_by = (d.get("br_by", {}) as Dictionary).duplicate() if d.get("br_by", {}) is Dictionary else {}
	_ai_blk = (d.get("ai_blk", {}) as Dictionary).duplicate(true) if d.get("ai_blk", {}) is Dictionary else {}
	_alt = (d.get("alt", {}) as Dictionary).duplicate() if d.get("alt", {}) is Dictionary else {}
	for k2: String in why.keys():
		if not (why[k2] is Array) or (why[k2] as Array).size() < 3:
			why.erase(k2)
	pcache.clear()
	_zsig = []
	_wjob = {}
	_weighted.clear()
	_cut.clear()
	_cut_dirty = true
	_lb_wait()
	_alt_c = -1
	_alt_cand.clear()
	_lb_st = -1
	_lpath.clear()
	_hot.clear()
	spills.clear()


static func _fdict(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		for k: Variant in v:
			out[String(k)] = clampf(float(v[k]), 0.0, 1.5)
	return out
