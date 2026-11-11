extends RefCounted


























const DT: float = 10.0
const RAMP_FROM: float = 180.0
const RAMP_FULL: float = 900.0
const GRACE_OLD: float = 720.0



const PCT: Dictionary = {
	Facility.Kind.AD_SAM: 0.03, Facility.Kind.AD_PATRIOT: 0.03, Facility.Kind.AD_SPAAG: 0.02, Facility.Kind.AD_MFG: 0.02, 
	Facility.Kind.AD_INT: 0.02, Facility.Kind.AD_RADAR: 0.015, Facility.Kind.AD_EW: 0.015, 
	Facility.Kind.TEL: 0.03, Facility.Kind.COASTAL_ASM: 0.025, 
	Facility.Kind.AIRFIELD: 0.012, Facility.Kind.DRONE_PORT: 0.01, Facility.Kind.DP_RAMP: 0.01, Facility.Kind.DP_RUNWAY: 0.01, 
	Facility.Kind.DP_STORE: 0.01, Facility.Kind.DRONE_FACTORY: 0.01, Facility.Kind.MISSILE_FACTORY: 0.01, 
	Facility.Kind.BARRACKS: 0.01, Facility.Kind.NAVAL_BASE: 0.01, 
}
const PCT_AIR: float = 0.02
const PCT_SHIP: float = 0.012
const DRONE_MIN: float = 4.0
const PCT_MISSILE: float = 0.006



const FREE_MIN: float = 300.0
const FREE_FULL: int = 3
const FREE_ZERO: int = 9

const CLASS_OF: Dictionary = {
	Facility.Kind.AD_SAM: "ad", Facility.Kind.AD_PATRIOT: "ad", Facility.Kind.AD_SPAAG: "ad", Facility.Kind.AD_MFG: "ad", Facility.Kind.AD_INT: "ad", 
	Facility.Kind.AD_RADAR: "ad", Facility.Kind.AD_EW: "ad", Facility.Kind.TEL: "strike", Facility.Kind.COASTAL_ASM: "strike", 
	Facility.Kind.MISSILE_FACTORY: "strike", Facility.Kind.AIRFIELD: "air", Facility.Kind.DRONE_PORT: "drones", Facility.Kind.DP_RAMP: "drones", 
	Facility.Kind.DP_RUNWAY: "drones", Facility.Kind.DP_STORE: "drones", Facility.Kind.DRONE_FACTORY: "drones", 
	Facility.Kind.BARRACKS: "army", Facility.Kind.NAVAL_BASE: "navy", 
}
const CLASSES: Array[String] = ["ad", "strike", "air", "drones", "army", "navy"]
const LOC_CLASS: Dictionary = {"ad": "ПВО", "strike": "Ракеты", "air": "Авиация", "drones": "Дроны", "army": "Армия", "navy": "Флот"}

const PRI: Dictionary = {
	Facility.Kind.AD_PATRIOT: 90, Facility.Kind.AD_SAM: 85, Facility.Kind.AD_RADAR: 80, Facility.Kind.AD_SPAAG: 75, Facility.Kind.AD_MFG: 70, 
	Facility.Kind.AD_INT: 65, Facility.Kind.AD_EW: 60, Facility.Kind.BARRACKS: 55, Facility.Kind.TEL: 50, Facility.Kind.COASTAL_ASM: 45, 
	Facility.Kind.AIRFIELD: 40, Facility.Kind.DRONE_PORT: 35, Facility.Kind.MISSILE_FACTORY: 30, Facility.Kind.DRONE_FACTORY: 30, 
}
const PRI_AIR: Dictionary = {Aircraft.Type.FIGHTER: 42, Aircraft.Type.HELI: 38, Aircraft.Type.ATTACK: 36, Aircraft.Type.BOMBER: 25}
const PRI_CAPITAL: int = 20
const PRI_FRONT: int = 20
const CAP_R: float = 1600.0
const FRONT_R: float = 2400.0
const REACT_K: float = 0.1
const REACT_T: float = 30.0
const REACT_GAP: float = 20.0
const CUSHION_MIN: float = 3.0
const INCOME_K: float = 0.1
const WARN_GAP: float = 150.0
const WARN_MIN: float = 5.0

const SERIES_FREE: Dictionary = {Facility.Kind.TEL: 5, Facility.Kind.AD_SAM: 5, Facility.Kind.AD_PATRIOT: 4, Facility.Kind.COASTAL_ASM: 4, 
	Facility.Kind.AD_SPAAG: 8, Facility.Kind.AD_INT: 8}
const SERIES_STEP: float = 0.08
const SERIES_MAX: float = 2.0
const HEAT_COOL: float = 120.0


const SK_DRONE: int = 900
const SK_JET: int = 901
const SERIES_FREE_DRONE: Dictionary = {SK_DRONE: 12, SK_JET: 6}
const HEAT_COOL_K: Dictionary = {SK_DRONE: 20.0, SK_JET: 34.0}

const SAT_HALF: float = 240.0


const SAT_W_MONEY: float = 120000.0
const SAT_C_MONEY: float = 15000.0
const SAT_W_MIN: float = 0.65
const SAT_W_MAX: float = 1.35
const SAT_C_MIN: float = 0.5
const SAT_C_MAX: float = 1.5
const MULT_MIN: float = 0.45
const MULT_MAX: float = 1.9

const MAT_FUEL_VEH: float = 0.12
const MAT_FUEL_AIR: float = 0.5
const MAT_METAL_SITE: float = 0.15
const SHORT_T: float = 70.0

const SUP_DT: float = 5.0
const CUT_DELAY: float = 60.0
const CUT_RAMP: float = 240.0
const CUT_MIN: float = 0.4
const SHORT_MIN: float = 0.75
const FILL_STEP: int = 2000
const SUP_KINDS: Array = [Facility.Kind.AD_SAM, Facility.Kind.AD_PATRIOT, Facility.Kind.AD_SPAAG, Facility.Kind.AD_MFG, Facility.Kind.AD_INT, 
	Facility.Kind.TEL, Facility.Kind.COASTAL_ASM]

var econ
var gw: GameWorld

var acc: Dictionary = {}
var mat_acc: Dictionary = {}
var inc_ema: Dictionary = {}
var earned0: Dictionary = {}
var mb_air: Dictionary = {}
var react: Dictionary = {}
var react_t: Dictionary = {}
var warn_t: Dictionary = {}
var short_until: Dictionary = {}
var heat: Dictionary = {}
var sat_w: Dictionary = {}
var sat_c: Dictionary = {}
var cut_u: Dictionary = {}
var cut_f: Dictionary = {}
var occ: Dictionary = {}
var grace_until: float = 0.0
var stats: Dictionary = {}
var _t: float = 0.0
var _st: float = 0.0
var _sat_t: float = 0.0

var comp: PackedInt32Array = PackedInt32Array()
var comp_ver: int = -1
var _job: Dictionary = {}
var _refs_u: Array = []
var _refs_f: Array = []
var _tmemo: Dictionary = {}
var _old_note: bool = false


func _init(e) -> void :
	econ = e
	gw = e.gw
	if not gw.city_captured.is_connected(_on_capture):
		gw.city_captured.connect(_on_capture)


func _stat(k: String, n: int = 1) -> void :
	stats[k] = int(stats.get(k, 0)) + n




const SAVED: Array[String] = ["acc", "mat_acc", "inc_ema", "earned0", "mb_air", "react", "react_t", "warn_t", "short_until", "heat", 
	"sat_w", "sat_c", "cut_u", "cut_f", "occ", "grace_until", "stats", "_t", "_st", "_sat_t"]


func save_state() -> Dictionary:
	var out: Dictionary = {}
	for k: String in SAVED:
		out[k] = Save.enc(get(k))
	return out



func load_state(d: Dictionary, had: bool) -> void :
	for k: String in SAVED:
		if d.has(k):
			var v: Variant = Save.dec(d[k])
			if typeof(v) == typeof(get(k)):
				set(k, v)
	for dk: String in ["acc", "inc_ema", "earned0", "react_t", "warn_t", "short_until", "cut_u", "cut_f", "mb_air", "occ", "mat_acc"]:
		var src: Dictionary = get(dk)
		var fixed: Dictionary = {}
		for key: Variant in src:
			fixed[int(key) if (key is String and String(key).is_valid_int()) or key is float else key] = src[key]
		set(dk, fixed)
	if not had:
		grace_until = gw.game_time + GRACE_OLD
		_old_note = true
		for c: Country in gw.countries:
			earned0[c.id] = c.earned
	comp = PackedInt32Array()
	comp_ver = -1
	_tmemo = {}
	_job = {}
	_refs_u = []
	_refs_f = []




func update(dt: float) -> void :
	_apply_slow(dt)
	_fill_step()
	_t += dt
	if _t >= DT:
		_t -= DT
		_step()
	_st += dt
	if _st >= SUP_DT:
		_st -= SUP_DT
		_supply_tick()
	_sat_t += dt
	if _sat_t >= DT:
		_sat_t -= DT
		_sat_decay(DT)


func ramp() -> float:
	var r: float = clampf((gw.game_time - RAMP_FROM) / (RAMP_FULL - RAMP_FROM), 0.0, 1.0)
	if gw.game_time < grace_until:
		r *= clampf(1.0 - (grace_until - gw.game_time) / GRACE_OLD, 0.0, 1.0)
	return r



func fac_upkeep(f: Facility) -> float:
	if not PCT.has(f.kind) or not gw.mil.alive(f):
		return 0.0
	if f.mb or (f.parent != null and f.parent.mb):
		return 0.0
	if gw.diplo != null and gw.diplo.get("sky") != null and (gw.diplo.sky.fac as Dictionary).has(f.id):
		return 0.0
	return float(Military.cost_of(f.kind)) * float(PCT[f.kind])


func air_upkeep(a: Aircraft) -> float:
	if a.state == Aircraft.State.DEAD or mb_air.has(a.id):
		return 0.0
	return float(int(Air.SPEC.get(a.type, {}).get("cost", 0))) * PCT_AIR


static func _ship_money(s) -> int:
	return int(Navy.cost_of(s.hull, s.mods).get("money", 0))




func tally(cid: int) -> Dictionary:
	var cls: Dictionary = {}
	for k: String in CLASSES:
		cls[k] = [0.0, 0, 0]
	var mil: Military = gw.mil
	var sites: int = 0
	var mbn: int = 0
	var rn: int = 0
	for f: Facility in mil.facilities:
		if f.country_id != cid or not PCT.has(f.kind) or not mil.alive(f):
			continue
		var e: Array = cls[CLASS_OF[f.kind]]
		e[0] = float(e[0]) + fac_upkeep(f)
		if f.parent == null:
			e[1] = int(e[1]) + 1
		if f.mb:
			e[2] = int(e[2]) + 1
			mbn += 1
			if react.has("f%d" % f.id):
				rn += 1
		elif SUP_KINDS.has(f.kind) or f.kind == Facility.Kind.AD_RADAR or f.kind == Facility.Kind.AD_EW:
			sites += 1
	var ea: Array = cls["air"]
	var n_air: int = 0
	for a: Aircraft in mil.air.aircraft:
		if a.country_id != cid or a.state == Aircraft.State.DEAD:
			continue
		ea[0] = float(ea[0]) + air_upkeep(a)
		ea[1] = int(ea[1]) + 1
		if mb_air.has(a.id):
			ea[2] = int(ea[2]) + 1
			mbn += 1
			if react.has("a%d" % a.id):
				rn += 1
		else:
			n_air += 1
	var ed: Array = cls["drones"]
	ed[0] = float(ed[0]) + float(_drones_paid(cid)) * DRONE_MIN
	var es: Array = cls["strike"]
	var c: Country = gw.country_by_id(cid)
	if c != null:
		for t in c.missile_stock.size():
			es[0] = float(es[0]) + float(c.missile_stock[t]) * float(Military.MT_COST[t]) * PCT_MISSILE
	if gw.get("navy") != null:
		var en: Array = cls["navy"]
		for s: Ship in gw.navy.ships:
			if s.c == cid and s.hp > 0.0:
				en[0] = float(en[0]) + float(_ship_money(s)) * PCT_SHIP
				en[1] = int(en[1]) + 1
	var veh: int = 0
	for u: Unit in gw.army.units:
		if u.country_id == cid and u.alive() and u.vehicle():
			veh += 1
	var tot: float = 0.0
	for k2: String in CLASSES:
		tot += float(cls[k2][0])
	var free: float = minf(tot, allowance(c))
	return {"money": tot - free, "free": free, "gross": tot, "cls": cls, "fuel": float(veh) * MAT_FUEL_VEH + float(n_air) * MAT_FUEL_AIR, "metal": float(sites) * MAT_METAL_SITE, 
		"mb": mbn, "react": rn}



func allowance(c: Country) -> float:
	if c == null:
		return 0.0
	return FREE_MIN * clampf(float(FREE_ZERO - c.city_ids.size()) / float(FREE_ZERO - FREE_FULL), 0.0, 1.0)



func _drones_paid(cid: int) -> int:
	var n: int = 0
	var mil: Military = gw.mil
	for f: Facility in mil.facilities:
		if f.country_id != cid or not mil.alive(f) or f.mb:
			continue
		if f.kind == Facility.Kind.DRONE_PORT:
			n += mil.parked_at(f)
		elif f.kind == Facility.Kind.DRONE_FACTORY and f.producing:
			n += 1
	return n


func _step() -> void :
	_prune_occ()
	var r: float = ramp()
	if _old_note:
		_old_note = false
		for c0: Country in gw.countries:
			if not c0.eliminated and c0.capital_id >= 0:
				gw.say(c0, Loc.mk("Новое: военное требует содержания (% цены в минуту). Для этого сохранения оно включается плавно за {m} мин; если денег не хватит — лишнее само уйдёт на консервацию", {"m": roundi(GRACE_OLD / 60.0)}))
	for c: Country in gw.countries:
		if c.eliminated or c.capital_id < 0:
			continue
		var inc: int = maxi(0, c.earned - int(earned0.get(c.id, c.earned)))
		earned0[c.id] = c.earned
		var ema: float = float(inc_ema.get(c.id, float(inc) * 60.0 / DT))
		inc_ema[c.id] = ema + (float(inc) * 60.0 / DT - ema) * INCOME_K
		_react_done(c)
		var tl: Dictionary = tally(c.id)
		var due_f: float = float(acc.get(c.id, 0.0)) + float(tl["money"]) * r * DT / 60.0
		var due: int = int(due_f)
		acc[c.id] = due_f - float(due)
		if due > 0:
			var pay: int = mini(due, maxi(0, c.money))
			c.money -= pay
			econ.stat_add(c, "spend", "upkeep", pay)
			_stat("paid", pay)
			if pay < due and gw.game_time >= grace_until:
				_mothball_one(c)
		_materials(c, tl, r)
		if pay_ok(c, tl):
			_reactivate_one(c, tl)
		_warn(c, tl)



func pay_ok(c: Country, tl: Dictionary) -> bool:
	return int(tl["mb"]) - int(tl["react"]) > 0 and gw.game_time - float(react_t.get(c.id, -999.0)) >= REACT_GAP




func _front_cities(c: Country) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for eid: Variant in c.at_war:
		var e: Country = gw.country_by_id(int(eid))
		if e == null:
			continue
		for cid: int in e.city_ids:
			out.append(Vector2(gw.cities[cid].center * GameWorld.CELL))
	return out


func _pri_at(c: Country, base: int, p: Vector2, front: Array[Vector2]) -> int:
	var s: int = base
	if c.capital_id >= 0 and Vector2(gw.cities[c.capital_id].center * GameWorld.CELL).distance_to(p) <= CAP_R:
		s += PRI_CAPITAL
	for q: Vector2 in front:
		if q.distance_to(p) <= FRONT_R:
			s += PRI_FRONT
			break
	return s



func _cands(c: Country, mothballed: bool) -> Array:
	var out: Array = []
	var front: Array[Vector2] = _front_cities(c)
	var mil: Military = gw.mil
	for f: Facility in mil.facilities:
		if f.country_id != c.id or f.parent != null or not PRI.has(f.kind) or not mil.alive(f) or f.mb != mothballed:
			continue
		if not mothballed and fac_upkeep(f) <= 0.0:
			continue
		var up: float = float(Military.cost_of(f.kind)) * float(PCT[f.kind])
		for mf: Facility in f.modules:
			if PCT.has(mf.kind) and mil.alive(mf):
				up += float(Military.cost_of(mf.kind)) * float(PCT[mf.kind])
		out.append([_pri_at(c, int(PRI[f.kind]), f.center_px(), front), up, "f%d" % f.id, f])
	for a: Aircraft in mil.air.aircraft:
		if a.country_id != c.id or a.state == Aircraft.State.DEAD or mb_air.has(a.id) != mothballed:
			continue
		if not mothballed and a.state != Aircraft.State.PARKED:
			continue
		var ap: Vector2 = a.base.center_px() if a.base != null else a.pos
		out.append([_pri_at(c, int(PRI_AIR.get(a.type, 30)), ap, front), float(int(Air.SPEC[a.type]["cost"])) * PCT_AIR, "a%d" % a.id, a])
	return out


func _mothball_one(c: Country) -> void :
	var cs: Array = _cands(c, false)
	if cs.is_empty():
		return
	cs.sort_custom( func(x: Array, y: Array) -> bool:
		if int(x[0]) != int(y[0]):
			return int(x[0]) < int(y[0])
		if float(x[1]) != float(y[1]):
			return float(x[1]) > float(y[1])
		return String(x[2]) < String(y[2]))
	var e: Array = cs[0]
	_set_mb(e[3], true)
	_stat("mothballed")
	_stat("mb_c%d" % c.id)
	if _say_ok(c, "mb"):
		gw.say(c, Loc.mk("Консервация: {what} — не хватает денег на содержание", {"what": _title(e[3])}))


func _reactivate_one(c: Country, tl: Dictionary) -> void :
	var cs: Array = _cands(c, true)
	var best: Array = []
	for e: Array in cs:
		if react.has(String(e[2])):
			continue
		if best.is_empty() or int(e[0]) > int(best[0]) or (int(e[0]) == int(best[0]) and String(e[2]) < String(best[2])):
			best = e
	if best.is_empty():
		return
	var price: int = _price_of(best[3])
	var cost: int = int(float(price) * REACT_K)
	var up_after: float = float(tl["money"]) + float(best[1])
	if c.money < cost + int(up_after * CUSHION_MIN) or float(inc_ema.get(c.id, 0.0)) < up_after * ramp():
		return
	c.money -= cost
	econ.stat_add(c, "spend", "upkeep", cost)
	react[String(best[2])] = gw.game_time + REACT_T
	react_t[c.id] = gw.game_time
	_stat("reactivated")


func _react_done(c: Country) -> void :
	if react.is_empty():
		return
	for k: String in react.keys():
		if gw.game_time < float(react[k]):
			continue
		var o: Object = _obj(k)
		if o is Facility and (o as Facility).country_id != c.id:
			continue
		if o is Aircraft and (o as Aircraft).country_id != c.id:
			continue
		react.erase(k)
		if o == null:
			continue
		_set_mb(o, false)
		if _say_ok(c, "re"):
			gw.say(c, Loc.mk("Снова в строю: {what}", {"what": _title(o)}))


func _obj(k: String) -> Object:
	var id: int = int(k.substr(1))
	if k.begins_with("f"):
		return gw.mil.facilities[id] if id >= 0 and id < gw.mil.facilities.size() else null
	for a: Aircraft in gw.mil.air.aircraft:
		if a.id == id:
			return a
	return null


func _set_mb(o: Object, on: bool) -> void :
	if o is Facility:
		var f: Facility = o
		f.mb = on
		if on:
			f.queued.clear()
			if f.kind == Facility.Kind.DRONE_FACTORY or f.kind == Facility.Kind.MISSILE_FACTORY:
				pass
	elif o is Aircraft:
		var a: Aircraft = o
		if on:
			mb_air[a.id] = true
		else:
			mb_air.erase(a.id)


func _price_of(o: Object) -> int:
	if o is Facility:
		return Military.cost_of((o as Facility).kind)
	if o is Aircraft:
		return int(Air.SPEC[(o as Aircraft).type]["cost"])
	return 0


func _title(o: Object) -> String:
	if o is Facility:
		return Military.title_of((o as Facility).kind)
	if o is Aircraft:
		return String(Air.SPEC[(o as Aircraft).type]["name"])
	return ""



const SAY_GAP: float = 30.0
func _say_ok(c: Country, kind: String) -> bool:
	var k: String = "%s%d" % [kind, c.id]
	if gw.game_time - float(warn_t.get(k, -999.0)) < SAY_GAP:
		return false
	warn_t[k] = gw.game_time
	return true



func grounded(a: Aircraft) -> bool:
	return mb_air.has(a.id) or (a.base != null and a.base.mb)


func _warn(c: Country, tl: Dictionary) -> void :
	var fc: Dictionary = forecast(c, tl)
	var left: float = float(fc["minutes_left"])
	if left < 0.0 or left > WARN_MIN or gw.game_time - float(warn_t.get(c.id, -999.0)) < WARN_GAP:
		return
	warn_t[c.id] = gw.game_time
	gw.say(c, Loc.mk("Казна: содержание армии −{n}/мин, денег хватит на ~{m} мин — дальше консервация", {"n": roundi(float(fc["upkeep_min"])), "m": maxi(1, roundi(left))}))



func forecast(c: Country, tl: Dictionary = {}) -> Dictionary:
	if tl.is_empty():
		tl = tally(c.id)
	var up: float = float(tl["money"]) * ramp()
	var inc: float = float(inc_ema.get(c.id, 0.0))
	var net: float = inc - up
	var left: float = -1.0
	if net < 0.0:
		left = float(maxi(0, c.money)) / - net
	return {"income_min": roundi(inc), "upkeep_min": roundi(up), "upkeep_full": roundi(float(tl["money"])), "net_min": roundi(net), 
		"minutes_left": left, "mothballed": int(tl["mb"])}




func _materials(c: Country, tl: Dictionary, r: float) -> void :
	var m: Dictionary = mat_acc.get(c.id, {})
	var short: bool = false
	for res: String in ["fuel", "metal"]:
		var x: float = float(m.get(res, 0.0)) + float(tl[res]) * r * DT / 60.0
		var n: int = int(x)
		m[res] = x - float(n)
		if n <= 0:
			continue
		var have: int = int(c.get(res))
		var take: int = mini(n, have)
		if take > 0:
			c.set(res, have - take)
			econ.stat_res(c, res, "army", - take)
		var lack: int = n - take
		if lack > 0 and res == "fuel" and c.oil > 0:
			var o: int = mini(lack, c.oil)
			c.oil -= o
			econ.stat_res(c, "oil", "army", - o)
			lack -= o
		if lack > 0:
			var unit: int = econ.foreign_buy_price(res, c.id) if res != "fuel" else maxi(1, econ.market_price("fuel") * 2)
			if c.money >= unit * lack + 200:
				c.money -= unit * lack
				econ.stat_add(c, "spend", "upkeep", unit * lack)
				_stat("mat_bought", lack)
			else:
				short = true
	mat_acc[c.id] = m
	if short:
		short_until[c.id] = gw.game_time + SHORT_T
		_stat("short")


func is_short(cid: int) -> bool:
	return gw.game_time < float(short_until.get(cid, -1.0))




func _heat_now(cid: int, kind: int) -> float:
	var e: Array = heat.get("%d:%d" % [cid, kind], [])
	if e.is_empty():
		return 0.0
	return maxf(0.0, float(e[0]) - (gw.game_time - float(e[1])) / float(HEAT_COOL_K.get(kind, HEAT_COOL)))



func series_mult(cid: int, kind: int) -> float:
	var fr: int = int(SERIES_FREE.get(kind, SERIES_FREE_DRONE.get(kind, -1)))
	if fr < 0:
		return 1.0
	var n: int = floori(_heat_now(cid, kind) + 0.0001)
	return minf(SERIES_MAX, 1.0 + SERIES_STEP * float(maxi(0, n - fr + 1)))


func note_buy(cid: int, kind: int) -> void :
	if not SERIES_FREE.has(kind) and not SERIES_FREE_DRONE.has(kind):
		return
	heat["%d:%d" % [cid, kind]] = [_heat_now(cid, kind) + 1.0, gw.game_time]



func series_info(cid: int, kind: int) -> Dictionary:
	var h: float = _heat_now(cid, kind)
	var m: float = series_mult(cid, kind)
	var free: int = int(SERIES_FREE.get(kind, SERIES_FREE_DRONE.get(kind, 0)))
	var cool: float = maxf(0.0, (h - float(free - 1)) * float(HEAT_COOL_K.get(kind, HEAT_COOL))) if free > 0 else 0.0
	var base: int = Military.COST_DRONE if kind == SK_DRONE else (Military.COST_JET if kind == SK_JET else Military.cost_of(kind))
	return {"heat": h, "mult": m, "price": roundi(float(base) * m), "base": base, "free": free, "cool_s": cool, "series": free > 0}




func _sat_decay(dt: float) -> void :
	var k: float = pow(0.5, dt / SAT_HALF)
	for d: Dictionary in [sat_w, sat_c]:
		for key: Variant in d.keys():
			var v: float = float(d[key]) * k
			if absf(v) < 1.0:
				d.erase(key)
			else:
				d[key] = v



func world_k(res: String) -> float:
	return _k_of(float(sat_w.get(res, 0.0)), SAT_W_MONEY, SAT_W_MIN, SAT_W_MAX)


static func _k_of(p: float, ref: float, lo: float, hi: float) -> float:
	if p >= 0.0:
		return maxf(lo, 1.0 / (1.0 + p / ref))
	return minf(hi, 1.0 - p / ref)




func own_k(cid: int, res: String) -> float:
	return _own_k_of(float(sat_c.get("%d:%s" % [cid, res], 0.0)))


static func _own_k_of(p: float) -> float:
	return _k_of(p, SAT_C_MONEY, SAT_C_MIN, SAT_C_MAX)



func sell_k(cid: int, res: String) -> float:
	return minf(1.0, own_k(cid, res)) if cid > 0 else 1.0



func buy_k(cid: int, res: String) -> float:
	return maxf(1.0, own_k(cid, res)) if cid > 0 else 1.0



func note_trade(cid: int, res: String, n: int, unit: int) -> void :
	if n == 0:
		return
	var v: float = float(n * maxi(1, unit))
	sat_w[res] = float(sat_w.get(res, 0.0)) + v
	var key: String = "%d:%s" % [cid, res]
	sat_c[key] = float(sat_c.get(key, 0.0)) + v
	_stat("sold" if n > 0 else "bought", absi(n))



func sale_preview(c: Country, res: String, n: int, base_unit: int) -> Dictionary:
	var wk: float = world_k(res)
	var ok: float = sell_k(c.id, res)
	var unit0: int = maxi(1, roundi(float(base_unit) * ok))
	var v: float = float(n * unit0)
	var ok2: float = _own_k_of(float(sat_c.get("%d:%s" % [c.id, res], 0.0)) + v)
	var avg: float = float(base_unit) * (ok + ok2) * 0.5
	var wk2: float = _k_of(float(sat_w.get(res, 0.0)) + v, SAT_W_MONEY, SAT_W_MIN, SAT_W_MAX)
	return {"unit_now": unit0, "unit_avg": roundi(avg), "total": roundi(avg * float(n)), "drop_pct": roundi((1.0 - ok2 * wk2 / maxf(0.01, ok * wk)) * 100.0), 
		"own_k": ok, "world_k": wk}





func _fill_step() -> void :
	if econ.nav == null or econ.nav_solid_b.is_empty():
		return
	if _job.is_empty():
		if comp_ver == econ.nav_solid_ver and not comp.is_empty():
			return
		var lab: = PackedInt32Array()
		lab.resize(econ.nav_solid_b.size())
		_job = {"ver": econ.nav_solid_ver, "solid": econ.nav_solid_b.duplicate(), "lab": lab, "i": 0, "stack": PackedInt32Array(), "next": 1, 
			"w": econ.nav.region.size.x}
	var solid: PackedByteArray = _job["solid"]
	var lab2: PackedInt32Array = _job["lab"]
	var st: PackedInt32Array = _job["stack"]
	var w: int = int(_job["w"])
	var n: int = solid.size()
	var i: int = int(_job["i"])
	var nx: int = int(_job["next"])
	var budget: int = FILL_STEP
	while budget > 0:
		if st.is_empty():
			var skip: int = 0
			while i < n and (solid[i] != 0 or lab2[i] != 0):
				i += 1
				skip += 1
				if skip >= 2048:
					break
			budget -= skip / 16 + 1
			if i >= n:
				break
			if solid[i] != 0 or lab2[i] != 0:
				continue
			lab2[i] = nx
			nx += 1
			st.append(i)
		var q: int = st[st.size() - 1]
		st.resize(st.size() - 1)
		budget -= 1
		var l: int = lab2[q]
		var x: int = q % w
		if x > 0 and solid[q - 1] == 0 and lab2[q - 1] == 0:
			lab2[q - 1] = l
			st.append(q - 1)
		if x < w - 1 and solid[q + 1] == 0 and lab2[q + 1] == 0:
			lab2[q + 1] = l
			st.append(q + 1)
		if q >= w and solid[q - w] == 0 and lab2[q - w] == 0:
			lab2[q - w] = l
			st.append(q - w)
		if q + w < n and solid[q + w] == 0 and lab2[q + w] == 0:
			lab2[q + w] = l
			st.append(q + w)
	_job["i"] = i
	_job["next"] = nx
	_job["stack"] = st
	_job["lab"] = lab2
	if st.is_empty() and i >= n:
		comp = lab2
		comp_ver = int(_job["ver"])
		_job = {}
		_stat("fills")



func comp_at(p: Vector2) -> int:
	if comp.is_empty() or econ.nav == null:
		return 0
	var q: Vector2i = econ._nav_cell(p)
	var w: int = econ.nav.region.size.x
	var i: int = q.y * w + q.x
	if i >= 0 and i < comp.size() and comp[i] != 0:
		return comp[i]
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var q2: Vector2i = q + o
		if q2.x < 0 or q2.y < 0 or q2.x >= w or q2.y >= econ.nav.region.size.y:
			continue
		var j: int = q2.y * w + q2.x
		if comp[j] != 0:
			return comp[j]
	return 0



func _sources(c: Country) -> Dictionary:
	var out: Dictionary = {}
	for o: Country in gw.countries:
		if o.eliminated or (o.id != c.id and (gw.diplo == null or not gw.diplo.allied(c.id, o.id))):
			continue
		for cid: int in o.city_ids:
			var city: City = gw.cities[cid]
			var k: int = comp_at(Vector2(city.entrance * GameWorld.CELL))
			if k == 0:
				k = comp_at(Vector2(city.center * GameWorld.CELL))
			if k != 0:
				out[k] = true
	for f: Facility in gw.mil.facilities:
		if f.country_id == c.id and (f.kind == Facility.Kind.PORT or f.kind == Facility.Kind.NAVAL_BASE) and gw.mil.alive(f):
			if f.kind == Facility.Kind.PORT and gw.econ.ports.blocked(c):
				continue
			var k2: int = comp_at(f.center_px())
			if k2 != 0:
				out[k2] = true
	return out


func _supply_tick() -> void :
	if comp.is_empty():
		return
	var now: float = gw.game_time
	var src: Dictionary = {}
	for c: Country in gw.countries:
		if not c.eliminated and c.capital_id >= 0:
			src[c.id] = _sources(c)
	var keep_u: Dictionary = {}
	_refs_u = []
	for u: Unit in gw.army.units:
		if not u.alive() or not u.ground() or not src.has(u.country_id):
			continue
		var k: int = comp_at(u.pos)
		if k == 0 or (src[u.country_id] as Dictionary).has(k):
			continue
		keep_u[u.id] = true
		if not cut_u.has(u.id):
			cut_u[u.id] = now
		_refs_u.append([u, float(cut_u[u.id])])
	for uid: Variant in cut_u.keys():
		if not keep_u.has(uid):
			cut_u.erase(uid)
	var keep_f: Dictionary = {}
	_refs_f = []
	for f: Facility in gw.mil.facilities:
		if not SUP_KINDS.has(f.kind) or not src.has(f.country_id) or not gw.mil.alive(f) or f.mb:
			continue
		var p: Vector2 = f.mpos if f.moving else f.center_px()
		var k2: int = comp_at(p)
		if k2 == 0 or (src[f.country_id] as Dictionary).has(k2):
			continue
		keep_f[f.id] = true
		if not cut_f.has(f.id):
			cut_f[f.id] = now
		_refs_f.append([f, float(cut_f[f.id])])
	for fid: Variant in cut_f.keys():
		if not keep_f.has(fid):
			cut_f.erase(fid)

	for c2: Country in gw.countries:
		if not is_short(c2.id):
			continue
		for u2: Unit in gw.army.units:
			if u2.country_id == c2.id and u2.alive() and u2.ground() and not cut_u.has(u2.id):
				_refs_u.append([u2, - float(short_until[c2.id])])
		for f2: Facility in gw.mil.facilities:
			if f2.country_id == c2.id and SUP_KINDS.has(f2.kind) and gw.mil.alive(f2) and not f2.mb and not cut_f.has(f2.id):
				_refs_f.append([f2, - float(short_until[c2.id])])



func _rate(since: float) -> float:
	if since < 0.0:
		return SHORT_MIN
	var t: float = gw.game_time - since - CUT_DELAY
	if t <= 0.0:
		return 1.0
	return maxf(CUT_MIN, 1.0 - (1.0 - CUT_MIN) * t / CUT_RAMP)


func _apply_slow(dt: float) -> void :
	for e: Array in _refs_u:
		var u: Unit = e[0]
		var k: float = _rate(float(e[1]))
		if k < 1.0 and u.alive() and u.fire_cd > 0.0:
			u.fire_cd += dt * (1.0 - k)
	for e2: Array in _refs_f:
		var f: Facility = e2[0]
		var k2: float = _rate(float(e2[1]))
		if k2 >= 1.0:
			continue
		if f.cd > 0.0:
			f.cd += dt * (1.0 - k2)
		if f.kind == Facility.Kind.TEL:
			if f.reload_t > 0.0:
				f.reload_t += dt * (1.0 - k2)
		elif f.reload_t > 0.0:
			f.reload_t = maxf(0.0, f.reload_t - dt * (1.0 - k2))



func unit_supply(u: Unit) -> int:
	if cut_u.has(u.id):
		return 2 if _rate(float(cut_u[u.id])) < 1.0 else 1
	return 3 if is_short(u.country_id) else 0


func site_supply(f: Facility) -> int:
	if cut_f.has(f.id):
		return 2 if _rate(float(cut_f[f.id])) < 1.0 else 1
	return 3 if is_short(f.country_id) and SUP_KINDS.has(f.kind) else 0



func army_supply(cid: int) -> Dictionary:
	var n: int = 0
	var cut: int = 0
	var slow: int = 0
	for u: Unit in gw.army.units:
		if u.country_id != cid or not u.alive() or not u.ground():
			continue
		n += 1
		var s: int = unit_supply(u)
		if s == 1 or s == 2:
			cut += 1
		if s == 2:
			slow += 1
	var sc: int = 0
	for fid: Variant in cut_f:
		var fi: int = int(fid)
		if fi >= 0 and fi < gw.mil.facilities.size() and gw.mil.facilities[fi].country_id == cid:
			sc += 1
	return {"units": n, "cut": cut, "slow": slow, "sites_cut": sc, "short": is_short(cid)}



func army_cut_count(cid: int) -> Array:
	var d: Dictionary = army_supply(cid)
	return [int(d["cut"]), int(d["units"])]




func _on_capture(city: City, old: int) -> void :
	if city == null:
		return
	if gw.diplo != null and gw.diplo.get("conf") != null and bool(gw.diplo.conf.applying):
		occ.erase(city.id)
		return
	var nw: int = city.country_id
	var e: Array = occ.get(city.id, [])

	var origin: int = (int(e[3]) if e.size() > 3 else int(e[1])) if not e.is_empty() and int(e[0]) == old else old
	if ( not e.is_empty() and int(e[1]) == nw) or nw == origin or nw == city.founder_id:
		occ.erase(city.id)
		_stat("liberated")
		return
	if gw.diplo != null and gw.diplo.at_war(nw, old):
		occ[city.id] = [nw, old, gw.game_time, origin]
		_stat("occupied")
	else:
		occ.erase(city.id)


func _occ_live(cid: int, rec: Array) -> bool:
	var city_ok: bool = int(rec[0]) == cid
	if not city_ok:
		return false
	var fo: Country = gw.country_by_id(int(rec[1]))
	return fo != null and not fo.eliminated and gw.diplo != null and gw.diplo.at_war(cid, int(rec[1]))



func occupied(cell: Vector2i, c: Country) -> bool:
	if occ.is_empty() or c == null:
		return false
	var any: bool = false
	for k: Variant in occ:
		if _occ_live(c.id, occ[k]) and gw.cities[int(k)].country_id == c.id:
			any = true
			break
	if not any:
		return false
	var best: int = -1
	var bd: int = 1 << 30
	for cid: int in c.city_ids:
		var cc: Vector2i = gw.cities[cid].center
		var dd: int = (cc.x - cell.x) * (cc.x - cell.x) + (cc.y - cell.y) * (cc.y - cell.y)
		if dd < bd or (dd == bd and cid < best):
			bd = dd
			best = cid
	return best >= 0 and occ.has(best) and _occ_live(c.id, occ[best])



func occupied_why(kind: int, nw: Vector2i, sz: Vector2i, c: Country) -> String:
	if Military.is_field_work(kind) or kind == Facility.Kind.DUGOUT:
		return ""
	var mid: Vector2i = nw + sz / 2
	if gw.data.inside(mid.x, mid.y) and gw.data.get_owner_id(mid.x, mid.y) == c.id and occupied(mid, c):
		return Loc.t("Оккупированная земля: строить можно после мира")
	return ""


func _prune_occ() -> void :
	for k: Variant in occ.keys():
		var rec: Array = occ[k]
		var ci: int = int(k)
		if ci < 0 or ci >= gw.cities.size() or gw.cities[ci].country_id != int(rec[0]) or not _occ_live(int(rec[0]), rec):
			occ.erase(k)






const AI_SHARE: Array = [0.35, 0.45, 0.55]
const PILE_MIN: float = 25.0
func ai_ok(c: Country, kind: int, extra_money_min: float = -1.0) -> bool:
	var add: float = extra_money_min
	if add < 0.0:
		if not PCT.has(kind):
			return true
		add = float(Military.cost_of(kind)) * float(PCT[kind])
	var tl: Dictionary = _tally_ai(c.id)
	if int(tl["mb"]) > 0:
		return false
	var up: float = float(tl["money"]) + add
	var inc: float = float(inc_ema.get(c.id, 0.0))
	return up <= inc * float(AI_SHARE[GameConfig.diff_of(c)]) or float(c.money) >= up * PILE_MIN



func ai_ok_sink(c: Country, id: String, arg: Variant) -> bool:
	match id:
		"fighter", "heli", "bomber":
			return ai_ok(c, -1, float(int(Air.SPEC[int(arg)]["cost"])) * PCT_AIR)
		"bridge_ad":
			return ai_ok(c, int((arg as Array)[1]))
	if arg is int and PCT.has(int(arg)):
		return ai_ok(c, int(arg))
	return true



func ai_reserve(c: Country) -> int:
	return int(float(_tally_ai(c.id)["money"]) * ramp() * 3.0)



func _tally_ai(cid: int) -> Dictionary:
	var e: Array = _tmemo.get(cid, [])
	if not e.is_empty() and float(e[0]) == gw.game_time:
		return e[1]
	var tl: Dictionary = tally(cid)
	if not econ.ui_time():
		_tmemo[cid] = [gw.game_time, tl]
	return tl
