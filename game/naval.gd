class_name Naval
extends RefCounted














const EXP_COST: Dictionary = {"money": 1500, "food": 60}
const EXP_CD: float = 150.0
const EXP_SPEED: float = 18.0
const EXP_MAX_SEA: float = 7000.0
const EXP_HP: float = 200.0
const COLONY_CAP_MAX: int = 4
const COLONY_CLAIM: float = 0.72
const COLONY_CLAIM_DRY: float = 0.5
const FOREIGN_GAP: int = 70
const COAST_R: int = 8
const SUPPLY_DT: float = 10.0
const LANDLINK_DT: float = 30.0

const BOAT_SPEED: float = 10.0
const BOAT_HP: float = 160.0
const BOAT_FOOT: int = 4
const BOAT_GAP: float = 2.0
const BOARD_T: float = 3.0
const LAND_MAX_SEA: float = 4200.0
const EMBARK_R: float = 70.0
const FIRE_DT: float = 0.25
const BEACH_R: int = 40
const STRIKE_DMG: float = 220.0
const FPV_HIT: int = 55
const FPV_DMG: float = 70.0



const PICK_SPEED: float = 30.0
const PICK_MAX_SEA: float = 9000.0
const PICK_R: int = 30

enum Stage{MARCH, BOARD, SAIL, LAND}
enum Mode{CITY, AREA, DEFEND, RETREAT}
const STAGE_TEXT: Array = ["к берегу, посадка на лодки", "посадка на лодки", "десант в море", "высадка"]

var gw: GameWorld
var expeditions: Array = []
var landings: Array = []
var colonies: Dictionary = {}
var next_exp: Dictionary = {}
var beached: Array = []
var sunk: Dictionary = {}
var drowned: Dictionary = {}
var sunk_by: Dictionary = {}
var ai_next: Dictionary = {}
var ai_towns: Dictionary = {}
var _id: int = 1
var _fire_acc: float = 0.0
var _supply_t: float = 0.0
var _guns: Array = []
var _guns_t: float = -99.0
var _cd: Dictionary = {}
var _plan_cache: Dictionary = {}
var _resuming: bool = false
var _warned: Dictionary = {}
var _snd_t: float = 0.0


func _init(world: GameWorld) -> void :
	gw = world


func _ports() -> Ports:
	return gw.econ.ports if gw.econ != null else null




func is_colony(city: City) -> bool:
	return city != null and colonies.has(city.id)


func supplied(city: City) -> bool:
	return city != null and colonies.has(city.id) and bool(colonies[city.id]["supplied"])



func colony_info(city: City) -> Dictionary:
	if not is_colony(city):
		return {"colony": false, "supplied": false, "claim": city.claim_max if city != null else 0, "text": ""}
	var sup: bool = supplied(city)
	var why: String = Loc.t("СНАБЖЕНИЕ ЕСТЬ") if sup else Loc.t("НЕТ СНАБЖЕНИЯ: нужен свой порт на этом море")
	return {"colony": true, "supplied": sup, "claim": city.claim_max, "text": Loc.t("КОЛОНИЯ · %s") % [why]}


func colony_count(c: Country) -> int:
	if c == null:
		return 0
	var n: int = 0
	for cid in c.city_ids:
		if colonies.has(cid):
			n += 1
	for e: Dictionary in expeditions:
		if int(e["c"]) == c.id and int(e["stage"]) == 0:
			n += 1
	return n



func colony_cap(c: Country) -> int:
	if c == null:
		return 0
	var home_n: int = 0
	for cid in c.city_ids:
		if not colonies.has(cid):
			home_n += 1
	return clampi(1 + home_n / 2, 1, COLONY_CAP_MAX)


func exp_busy(c: Country) -> bool:
	for e: Dictionary in expeditions:
		if int(e["c"]) == c.id and int(e["stage"]) == 0:
			return true
	return false




func port_info(port: Facility) -> Dictionary:
	var c: Country = gw.country_by_id(port.country_id) if port != null else null
	var out: Dictionary = {"busy": false, "eta": 0.0, "cooldown": 0.0, "colonies": colony_count(c), "cap": colony_cap(c), "cost": EXP_COST.duplicate(), "ready": ""}
	if c == null:
		out["ready"] = Loc.t("Нет порта")
		return out
	for e: Dictionary in expeditions:
		if int(e["c"]) == c.id and int(e["stage"]) == 0:
			out["busy"] = true
			out["eta"] = _left_len(e["path"], int(e["i"]), e["pos"]) / EXP_SPEED
	out["cooldown"] = maxf(0.0, float(next_exp.get(c.id, 0.0)) - gw.game_time)
	out["ready"] = _ready_why(port, c)
	out["short_res"] = String(out["ready"]) != "" and _ready_why(port, c, true) == ""
	return out



func can_expedition(port: Facility, cell: Vector2i) -> String:
	return String(expedition_preview(port, cell)["why"])



func expedition_preview(port: Facility, cell: Vector2i) -> Dictionary:
	var out: Dictionary = {"ok": false, "why": "", "text": "", "eta": 0.0, "km": 0.0, "path": PackedVector2Array(), "site": cell}
	var c: Country = gw.country_by_id(port.country_id) if port != null else null
	if c == null:
		out["why"] = Loc.t("Нужен свой порт")
		return out
	var why: String = _ready_why(port, c)
	if why == "":
		why = _site_why(c, cell)
	var route: Array = []
	if why == "":
		route = _exp_route(port, cell)
		why = String(route[0])
	var cost_t: String = Loc.t("%d + еда %d") % [int(EXP_COST["money"]), int(EXP_COST["food"])]
	if why != "":
		out["why"] = why
		out["text"] = Loc.t("КОЛОНИЯ")
		return out
	var path: PackedVector2Array = route[1]
	var ln: float = _plen(path)
	out["ok"] = true
	out["path"] = path
	out["km"] = ln / 1000.0
	out["eta"] = ln / EXP_SPEED
	out["text"] = Loc.t("КОЛОНИЯ: %s · %.1f км морем · ~%d мин · колонии %d/%d") % [cost_t, ln / 1000.0, maxi(1, roundi(ln / EXP_SPEED / 60.0)), colony_count(c), colony_cap(c)]
	return out



func launch_expedition(port: Facility, cell: Vector2i) -> String:
	var pv: Dictionary = expedition_preview(port, cell)
	if not bool(pv["ok"]):
		return String(pv["why"])
	var c: Country = gw.country_by_id(port.country_id)
	c.pay_res(EXP_COST)
	if gw.econ != null:
		gw.econ.stat_add(c, "spend", "expedition", int(EXP_COST["money"]))
	var path: PackedVector2Array = pv["path"]
	var e: Dictionary = {"id": _id, "c": c.id, "port": port, "cell": cell, "path": path, "i": 0, "pos": path[0], "heading": (path[mini(1, path.size() - 1)] - path[0]).angle(), 
		"frame": 0, "hp": EXP_HP, "stage": 0, "trail": PackedVector2Array(), "trail_t": 0.0, "body": _ports()._body_at(_sea_q(path[path.size() - 1])), "t0": gw.game_time}
	_id += 1
	expeditions.append(e)
	next_exp[c.id] = gw.game_time + EXP_CD
	if c.is_player:
		gw.say(c, Loc.mk("Экспедиция вышла из порта: ~%d мин до берега", [maxi(1, roundi(float(pv["eta"]) / 60.0))]))
	if gw._on_screen(path[0], 80.0):
		Sfx.play("ship_horn", path[0])
	return ""


func _ready_why(port: Facility, c: Country, skip_res: bool = false) -> String:
	if port == null or port.kind != Facility.Kind.PORT or not gw.mil.alive(port) or port.country_id != c.id:
		return Loc.t("Нужен свой порт")
	var pr: Ports = _ports()
	if pr == null or (pr._port_state(port)["berth"] as Vector2i).x < 0:
		return Loc.t("Порт без выхода к морю")
	if exp_busy(c):
		return Loc.t("Экспедиция уже в пути")
	if colony_count(c) >= colony_cap(c):
		return Loc.t("Лимит колоний %d/%d: нужно больше своих городов") % [colony_count(c), colony_cap(c)]
	var cd: float = float(next_exp.get(c.id, 0.0)) - gw.game_time
	if cd > 0.0:
		return Loc.t("Новая экспедиция через %d с") % ceili(cd)
	if ( not GameConfig.creative or not c.is_player) and not skip_res:
		if not c.has_res(EXP_COST):
			return Loc.t("Не хватает: %s") % [c.missing_res(EXP_COST)]
	return ""




func _site_why(c: Country, cell: Vector2i) -> String:
	var d: WorldData = gw.data
	if not d.inside(cell.x, cell.y):
		return Loc.t("Нужна свободная суша у берега")

	var own: int = d.get_owner_id(cell.x, cell.y)
	if own != 0 and own != c.id:
		return Loc.t("Чужая территория")
	if own == c.id:
		return Loc.t("Своя земля: здесь строят обычный город")
	if not Biome.is_natural_land(d.get_biome(cell.x, cell.y)):
		return Loc.t("Вода: выберите сушу у берега") if Biome.is_water(d.get_biome(cell.x, cell.y)) else Loc.t("Нужна свободная суша у берега")
	for e: Dictionary in expeditions:
		var ec: Vector2i = e["cell"]
		if int(e["stage"]) == 0 and absi(ec.x - cell.x) + absi(ec.y - cell.y) < GameWorld.MIN_CITY_DIST + 20:
			return Loc.t("Сюда уже плывут колонисты")
	for oc: City in gw.cities:
		var dd: int = absi(oc.center.x - cell.x) + absi(oc.center.y - cell.y)
		if dd < GameWorld.MIN_CITY_DIST or (oc.country_id != c.id and maxi(absi(oc.center.x - cell.x), absi(oc.center.y - cell.y)) < FOREIGN_GAP):
			return Loc.t("Слишком близко к городу") if oc.country_id == c.id else Loc.t("Рядом чужой город")
	if _near_land_of(c.id, cell, GameWorld.TOWN_REACH):
		return Loc.t("Своя земля рядом: здесь строят обычный город")
	if not GameWorld.BORDER_GAP.site_ok(gw, cell, c.id, 21):
		return Loc.t("Рядом чужая граница")
	if not GameWorld.BORDER_GAP.own_ok(gw, cell, c.id, 21):
		return Loc.t("Слишком близко к своему городу")
	var vp: Dictionary = gw.can_found_city(cell, City.Kind.VILLAGE)
	if not bool(vp["ok"]):
		return String(vp["reason"])
	return ""



func _exp_route(port: Facility, cell: Vector2i) -> Array:
	var pr: Ports = _ports()
	var st: Dictionary = pr._port_state(port)
	var berth: Vector2i = st["berth"]
	var body: int = int(st["body"])
	var q: Vector2i = _sea_near(Vector2(cell * GameWorld.CELL), COAST_R, body)
	if q.x < 0:
		if _sea_near(Vector2(cell * GameWorld.CELL), COAST_R, 0).x >= 0:
			return [Loc.t("Не доплыть: другое море"), PackedVector2Array()]
		return [Loc.t("Далеко от моря: выберите место у берега"), PackedVector2Array()]
	var path: PackedVector2Array = pr._path(berth, q)
	if path.size() < 2:
		return [Loc.t("Нет морского пути"), PackedVector2Array()]
	var ln: float = _plen(path)
	if ln > EXP_MAX_SEA:
		return [Loc.t("Слишком далеко: %.1f км морем (макс. %.0f)") % [ln / 1000.0, EXP_MAX_SEA / 1000.0], PackedVector2Array()]
	return ["", path]


func _near_land_of(country_id: int, cell: Vector2i, reach: int) -> bool:
	var d: WorldData = gw.data
	for dy in range( - reach, reach + 1, 3):
		for dx in range( - reach, reach + 1, 3):
			var q: = cell + Vector2i(dx, dy)
			if d.inside(q.x, q.y) and d.get_owner_id(q.x, q.y) == country_id:
				return true
	return false











func plan(country_id: int, from: Vector2, to: Vector2, speed: float = 8.0, retreat: bool = false, sea_only: bool = false) -> Dictionary:
	var key: String = "%d:%d:%d:%d:%d:%d:%d" % [country_id, floori(from.x / 48.0), floori(from.y / 48.0), floori(to.x / 24.0), floori(to.y / 24.0), 1 if retreat else 0, 1 if sea_only else 0]
	var ce: Array = _plan_cache.get(key, [])
	var res: Dictionary
	if not ce.is_empty() and absf(gw.game_time - float(ce[0])) < 8.0:
		res = ce[1]
	else:
		res = _plan(country_id, from, to, retreat, sea_only)
		if not (gw.net_driven and not gw.net_sim):
			if _plan_cache.size() > 48:
				_plan_cache.clear()
			_plan_cache[key] = [gw.game_time, res]
		else:
			res = res.duplicate()
	if bool(res.get("ok", false)):
		res["eta"] = maxf(float(res["land1"]) / maxf(1.0, speed), float(res.get("pick_len", 0.0)) / PICK_SPEED) + float(res["land2"]) / maxf(1.0, speed) + float(res["sea_len"]) / BOAT_SPEED + BOARD_T + 6.0
	return res




func busy(home: Facility) -> bool:
	if _rt() != null and _rt().busy(home):
		return true
	return not of(home).is_empty()


func _rt():
	return gw.rail.troops if gw.rail != null else null



func at_sea(home: Facility) -> bool:
	if _rt() != null and _rt().riding(home):
		return true
	var L: Dictionary = of(home)
	return not L.is_empty() and int(L["stage"]) != Stage.MARCH


func of(home: Facility) -> Dictionary:
	if home == null:
		return {}
	for L: Dictionary in landings:
		if L["home"] == home:
			return L
	return {}







func landing_info(who: Variant) -> Dictionary:
	if who is Facility:
		return _landing_info(who as Facility)
	var cid: int = (who as Country).id if who is Country else (int(who) if who is int else -1)
	var best: Dictionary = {}
	for L: Dictionary in landings:
		if int(L["c"]) != cid:
			continue
		var li: Dictionary = _landing_info(L["home"])
		if not li.is_empty() and (best.is_empty() or int(li["eta_s"]) < int(best["eta_s"])):
			best = li
	return best


func _landing_info(home: Facility) -> Dictionary:
	var L: Dictionary = of(home)
	if L.is_empty():
		return {}
	var alive: int = 0
	var eta: float = 0.0
	var troops: int = 0
	for b: Dictionary in L["boats"]:
		if not bool(b["sunk"]):
			alive += 1
			eta = maxf(eta, maxf(0.0, float(b["delay"])) + _left_len(L["sea"], int(b["i"]), b["pos"]) / BOAT_SPEED)
			if not bool(b.get("out", false)):
				for u: Unit in b["u"]:
					if u.alive():
						troops += 1
	var st: int = int(L["stage"])
	if st == Stage.MARCH or st == Stage.BOARD:
		var mem: Array = _alive_march(L)
		troops = mem.size()
		var walk: float = 0.0
		if st == Stage.MARCH and not mem.is_empty():
			walk = centre(mem).distance_to(L["embark"]) / 7.0
			var fy: Dictionary = L.get("ferry", {})
			if not fy.is_empty():
				walk = maxf(walk, _left_len(L["pick"], int(fy["i"]), fy["pos"]) / PICK_SPEED)
		eta = walk + (BOARD_T if st == Stage.MARCH else maxf(0.0, BOARD_T - float(L["t"]))) + _plen(L["sea"]) / BOAT_SPEED
	var txt: Array = Loc.mk(String(STAGE_TEXT[st]))
	var line: String = ""
	if st == Stage.SAIL:
		txt = Loc.mk("десант в море: %d лод., высадка ~%d с", [alive, ceili(eta)])
		line = Loc.t("%d лод. · высадка ~%d с · потери %d") % [alive, ceili(eta), int(L["lost"])]
	elif st == Stage.LAND:
		line = Loc.t("высадка · потери %d") % int(L["lost"])
	elif st == Stage.MARCH and L.has("ferry") and int(L["ferry"]["i"]) < (L["pick"] as PackedVector2Array).size():
		txt = Loc.mk("катера с базы идут за армией")
		line = Loc.t("катера идут за армией · высадка ~%d с") % ceili(eta)
	else:
		line = Loc.t("%d бойц. к лодкам · высадка ~%d с") % [troops, ceili(eta)]
	return {"stage": st, "text": Loc.msg(txt), "text_m": txt, "boats": (L["boats"] as Array).size(), "boats_alive": alive, "eta": eta, "lost": int(L["lost"]), "pos": front(home), 
		"eta_s": ceili(eta), "losses": int(L["lost"]), "troops": troops, "fid": home.id, "line": line}


func status_text(home: Facility) -> Variant:
	if _rt() != null and _rt().busy(home):
		return _rt().status_text(home)
	var li: Dictionary = landing_info(home)
	return li.get("text_m", "")



func front(home: Facility) -> Vector2:
	var L: Dictionary = of(home)
	if L.is_empty():
		return _rt().front(home) if _rt() != null else Vector2.INF
	if int(L["stage"]) == Stage.MARCH:
		var mem: Array = _alive_march(L)
		return centre(mem) if not mem.is_empty() else L["embark"]
	for b: Dictionary in L["boats"]:
		if not bool(b["sunk"]):
			return b["pos"]
	return L["beach"]



func aboard_of(home: Facility) -> Array:
	var out: Array = _rt().aboard_of(home) if _rt() != null else []
	for L: Dictionary in landings:
		if L["home"] != home:
			continue
		for b: Dictionary in L["boats"]:
			if not bool(b["sunk"]) and not bool(b.get("out", false)):
				for u: Unit in b["u"]:
					if u.alive():
						out.append(u)
	return out


func aboard_n(country_id: int) -> int:
	var n: int = _rt().aboard_n(country_id) if _rt() != null else 0
	for L: Dictionary in landings:
		if int(L["c"]) != country_id:
			continue
		for b: Dictionary in L["boats"]:
			if not bool(b["sunk"]) and not bool(b.get("out", false)):
				n += (b["u"] as Array).size()
	return n



func add_counts(counts: Dictionary) -> void :
	if _rt() != null:
		_rt().add_counts(counts)
	for L: Dictionary in landings:
		var h: Facility = L["home"]
		for b: Dictionary in L["boats"]:
			if bool(b["sunk"]) or bool(b.get("out", false)):
				continue
			for u: Unit in b["u"]:
				if u.alive() and u.type != Unit.Type.FPV:
					counts[h] = int(counts.get(h, 0)) + 1







func divert(home: Facility, members: Array[Unit], city: City, goal: Vector2, mode: int, sea: bool = false) -> int:
	if _resuming or home == null or members.is_empty():
		return 0
	var cur: Dictionary = of(home)
	if not cur.is_empty() and int(cur["stage"]) != Stage.MARCH:
		return 1
	var by_land: Array[Unit] = []
	var by_sea: Array[Unit] = []
	var known: Array = []
	for u: Unit in members:
		var ok: int = -1
		for kn: Array in known:
			if u.pos.distance_squared_to(kn[0]) < 48.0 * 48.0:
				ok = int(kn[1])
				break
		if sea:
			ok = 0
		if ok < 0:
			gw.econ.army_path(u.pos, goal)
			ok = 1 if gw.econ.nav_last_ok or gw.econ.nav_last_pending else 0
			known.append([u.pos, ok])
		if ok == 1:
			by_land.append(u)
		else:
			by_sea.append(u)
	if not by_land.is_empty() and by_land.size() >= by_sea.size():
		members.assign(by_land)
		return 2
	if by_sea.is_empty():
		return 0
	members = by_sea
	var cen: Vector2 = centre(members)
	var spd: float = INF
	for u: Unit in members:
		spd = minf(spd, float(Army.SPEC[u.type]["speed"]))
	var pl: Dictionary = plan(home.country_id, cen, goal, spd if spd < INF else 8.0, mode == Mode.RETREAT, sea)
	if not bool(pl.get("ok", false)):
		return 0
	if not cur.is_empty():
		landings.erase(cur)
	gw.army.tac.stop(home)
	var mem: Array = []
	mem.assign(members)
	var L: Dictionary = {"id": _id, "c": home.country_id, "home": home, "city": city.id if city != null else -1, "goal": goal, "mode": mode, 
		"stage": Stage.MARCH, "t": 0.0, "t0": gw.game_time, "embark": pl["embark"], "beach": pl["beach"], "sea": pl["sea"], "members": mem, 
		"boats": [], "lost": 0, "march_max": float(pl["land1"]) / maxf(4.0, spd) * 1.6 + 30.0}
	var pick: PackedVector2Array = pl.get("pick", PackedVector2Array())
	if pick.size() >= 2:

		var nb: int = 0
		var nf: int = 0
		for u: Unit in members:
			if u.vehicle() or u.type == Unit.Type.IFV:
				nb += 1
			else:
				nf += 1
		nb += ceili(float(nf) / float(BOAT_FOOT))
		var hd0: float = (pick[1] - pick[0]).angle()
		L["pick"] = pick.duplicate()
		L["ferry"] = {"pos": pick[0], "heading": hd0, "frame": posmod(roundi(rad_to_deg(hd0) / 22.5), 16), "i": 1, "n": clampi(nb, 1, 12), 
			"trail": PackedVector2Array(), "trail_t": 0.0}
		L["march_max"] = maxf(float(L["march_max"]), _plen(pick) / PICK_SPEED * 1.3 + 30.0)
	var cw: Country = gw.country_by_id(home.country_id)
	if cw != null and not cw.is_player:
		L["grp"] = "%d:%d:%d" % [home.country_id, L["city"], roundi(gw.game_time * 10.0)]
	_id += 1
	landings.append(L)
	var k: int = 0
	for u: Unit in members:
		u.op_on = true
		u.op_hold = true
		u.op_move = false
		u.target_city = -1
		u.target = null
		var dest: Vector2 = gw.army.safe_point(L["embark"], Vector2(float(k % 4) * 8.0 - 12.0, float(k / 4) * 8.0 - 8.0))
		_walk(u, dest)
		k += 1
	var c: Country = gw.country_by_id(home.country_id)
	if c != null and c.is_player:
		gw.say(c, Loc.mk("Армия №%d: через море — %s, на лодки (~%d мин)", [home.army_no, Loc.t("к берегу") if mode == Mode.RETREAT else (Loc.t("катера с базы идут за армией") if L.has("pick") else Loc.t("к морской базе")), maxi(1, roundi(float(pl["eta"]) / 60.0))]))
	return 1



func on_cancel(home: Facility) -> void :
	if _rt() != null:
		_rt().on_cancel(home)
	var L: Dictionary = of(home)
	if L.is_empty() or int(L["stage"]) != Stage.MARCH:
		return
	for u: Unit in _alive_march(L):
		u.op_on = false
		u.op_hold = false
		if u.pi >= u.path.size():
			u.state = Unit.State.IDLE
	landings.erase(L)




func update(dt: float) -> void :
	_fire_acc += dt
	_snd_t -= dt
	for k in range(landings.size() - 1, -1, -1):
		if k < landings.size():
			_tick_landing(landings[k], dt)
	for k in range(expeditions.size() - 1, -1, -1):
		_tick_exp(expeditions[k], dt)
	if _fire_acc >= FIRE_DT:
		var fdt: float = _fire_acc
		_fire_acc = 0.0
		if not landings.is_empty() or not expeditions.is_empty():
			_coast_fire(fdt)
	_supply_t += dt
	if _supply_t >= SUPPLY_DT:
		_supply_t = 0.0
		_supply()
	for k in range(beached.size() - 1, -1, -1):
		if gw.game_time > float(beached[k][2]):
			beached.remove_at(k)


func _alive_march(L: Dictionary) -> Array:
	var out: Array = []
	var h: Facility = L["home"]
	for u: Unit in L["members"]:
		if u.alive() and u.home == h and u.op_on:
			out.append(u)
	return out


func _walk(u: Unit, dest: Vector2) -> void :
	u.path = gw.econ.nav_path(u.pos, dest) if u.pos.distance_to(dest) > 30.0 else PackedVector2Array([dest])
	if u.path.is_empty():
		u.path = PackedVector2Array([dest])
	u.pi = 0
	u.state = Unit.State.MOVE


func _tick_landing(L: Dictionary, dt: float) -> void :
	L["t"] = float(L["t"]) + dt
	var st: int = int(L["stage"])
	if st == Stage.MARCH:
		var mem: Array = _alive_march(L)
		if mem.is_empty():
			landings.erase(L)
			return
		var emb: Vector2 = L["embark"]
		var near: int = 0
		for u: Unit in mem:
			if u.pos.distance_to(emb) <= EMBARK_R:
				near += 1
			elif u.pi >= u.path.size() and u.target == null:
				_walk(u, gw.army.safe_point(emb, Vector2(float(u.id % 4) * 8.0 - 12.0, float(u.id % 3) * 8.0 - 8.0)))
		var t: float = float(L["t"])
		var fy: Dictionary = L.get("ferry", {})
		var docked: bool = true
		if not fy.is_empty():

			var pk: PackedVector2Array = L["pick"]
			_sail(fy, pk, PICK_SPEED, dt)
			docked = int(fy["i"]) >= pk.size()
		L["ready"] = near >= ceili(float(mem.size()) * 0.8) and docked
		if not docked:
			pass
		elif (bool(L["ready"]) and _wave_ready(L)) or (t > float(L["march_max"]) and near > 0):
			_board(L, mem)
		elif t > float(L["march_max"]) * 1.6:
			on_cancel(L["home"])
		return
	if st == Stage.BOARD:
		if float(L["t"]) >= BOARD_T:
			L["stage"] = Stage.SAIL
			L["t"] = 0.0
		return
	if st == Stage.SAIL:
		var path: PackedVector2Array = L["sea"]
		var going: int = 0
		for b: Dictionary in L["boats"]:
			if bool(b["sunk"]) or bool(b["done"]):
				continue
			going += 1
			if float(b["delay"]) > 0.0:
				b["delay"] = float(b["delay"]) - dt
				continue
			_sail(b, path, BOAT_SPEED, dt)
			if int(b["i"]) >= path.size():
				b["done"] = true
		if going == 0:
			var any: bool = false
			for b2: Dictionary in L["boats"]:
				if not bool(b2["sunk"]):
					any = true
			if not any:
				_say(L, Loc.msg(Loc.mk("Армия №%d: десант потоплен", [(L["home"] as Facility).army_no])))
				landings.erase(L)
				return
			L["stage"] = Stage.LAND
			L["t"] = 0.0
			_unload(L)
		_warn(L)
		return




func _wave_ready(L: Dictionary) -> bool:
	var g: String = String(L.get("grp", ""))
	if g == "":
		return true
	for L2: Dictionary in landings:
		if not is_same(L2, L) and String(L2.get("grp", "")) == g and int(L2["stage"]) == Stage.MARCH and not bool(L2.get("ready", false)):
			return false
	return true



func _sail(b: Dictionary, path: PackedVector2Array, spd: float, dt: float) -> void :
	var i: int = int(b["i"])
	if i >= path.size():
		return
	var pos: Vector2 = b["pos"]
	var to: Vector2 = path[i] - pos
	var step: float = spd * dt
	if to.length() <= step:
		b["pos"] = path[i]
		b["i"] = i + 1
	else:
		b["pos"] = pos + to.normalized() * step
		var hd: float = float(b["heading"])
		hd += clampf(wrapf(to.angle() - hd, - PI, PI), - dt * 1.8, dt * 1.8)
		b["heading"] = hd
	b["frame"] = posmod(roundi(rad_to_deg(float(b["heading"])) / 22.5), 16)
	b["trail_t"] = float(b["trail_t"]) + dt
	if float(b["trail_t"]) >= 0.4:
		b["trail_t"] = 0.0
		var tr: PackedVector2Array = b["trail"]
		tr.append(b["pos"])
		if tr.size() > 8:
			tr.remove_at(0)
		b["trail"] = tr


func _board(L: Dictionary, mem: Array) -> void :
	var emb: Vector2 = L["embark"]
	var go: Array = []
	for u: Unit in mem:
		if u.pos.distance_to(emb) <= EMBARK_R * 1.8 and u.post == null:
			go.append(u)
		else:
			u.op_on = false
			u.op_hold = false
	if go.is_empty():
		landings.erase(L)
		return
	var path: PackedVector2Array = L["sea"]
	var p0: Vector2 = path[0]
	var hd: float = (path[mini(1, path.size() - 1)] - p0).angle() if path.size() > 1 else 0.0
	var boats: Array = []
	var foot: Array = []
	for u: Unit in go:
		if u.vehicle() or u.type == Unit.Type.IFV:
			boats.append(_boat([u], true, hd, p0))
		else:
			foot.append(u)
	for k in range(0, foot.size(), BOAT_FOOT):
		boats.append(_boat(foot.slice(k, k + BOAT_FOOT), false, hd, p0))
	for k in boats.size():
		(boats[k] as Dictionary)["delay"] = float(k) * BOAT_GAP
	for u: Unit in go:
		gw.army.units.erase(u)
		u.path = PackedVector2Array()
		u.pi = 0
		u.target = null
		u.state = Unit.State.IDLE
		u.pos = p0
	L["boats"] = boats
	L["members"] = []
	L["stage"] = Stage.BOARD
	L["t"] = 0.0
	if gw._on_screen(p0, 80.0):
		Sfx.play("ship_horn", p0, -6.0)
	_say(L, Loc.msg(Loc.mk("Армия №%d: посадка на лодки (%d), отплытие", [(L["home"] as Facility).army_no, boats.size()])))


func _boat(us: Array, veh: bool, hd: float, p0: Vector2) -> Dictionary:
	return {"u": us, "veh": veh, "pos": p0, "heading": hd, "frame": posmod(roundi(rad_to_deg(hd) / 22.5), 16), "hp": BOAT_HP * (1.3 if veh else 1.0), 
		"i": 1, "delay": 0.0, "done": false, "sunk": false, "out": false, "trail": PackedVector2Array(), "trail_t": 0.0, "hit_t": -99.0}


func _unload(L: Dictionary) -> void :
	var beach: Vector2 = L["beach"]
	var h: Facility = L["home"]
	var landed: Array[Unit] = []
	var k: int = 0
	for b: Dictionary in L["boats"]:
		if bool(b["sunk"]):
			continue
		b["out"] = true
		beached.append([b["pos"], float(b["heading"]), gw.game_time + 10.0, int(L["c"]), bool(b["veh"])])
		for u: Unit in b["u"]:
			if not u.alive():
				continue
			var off: = Vector2(float(k % 4) * 8.0 - 12.0, float(k / 4) * 8.0 - 8.0)
			u.pos = gw.econ.land_point(gw.army.safe_point(beach, off), 8)
			u.path = PackedVector2Array()
			u.pi = 0
			u.state = Unit.State.IDLE
			u.op_on = false
			u.op_hold = false
			u.op_move = false
			u.cover = 1.0
			u.still_t = 0.0
			gw.army.units.append(u)
			landed.append(u)
			k += 1
	if gw._on_screen(beach, 80.0):
		gw.fx.spawn("dust_s", beach.round(), 5)
	landings.erase(L)
	if landed.is_empty():
		return
	_resuming = true
	var tac = gw.army.tac
	var ok: bool = false
	var c: int = int(L["c"])
	match int(L["mode"]):
		Mode.CITY:
			var cid: int = int(L["city"])
			if cid >= 0 and cid < gw.cities.size():
				var city: City = gw.cities[cid]
				if city.country_id != c and gw.army._hostile(c, city.country_id):
					ok = tac.start(h, landed, city)
		Mode.AREA, Mode.DEFEND:

			if int(L["mode"]) == Mode.AREA:
				var gp: Vector2 = L["goal"]
				for cy: City in gw.cities:
					if cy.country_id != c and gw.army._hostile(c, cy.country_id) and gp.distance_to(Vector2(cy.center * GameWorld.CELL)) <= float(cy.radius * GameWorld.CELL) + 120.0:
						ok = tac.start(h, landed, cy)
						break
			if not ok:
				ok = tac.start_area(h, landed, L["goal"], Vector2.INF, int(L["mode"]) == Mode.DEFEND)
		Mode.RETREAT:
			var home: Vector2 = gw.army.barracks_out(h)
			for u: Unit in landed:
				u.op_on = true
				u.op_move = true
				_walk(u, home + u.slot)
			ok = true
	if not ok:
		var dir: Vector2 = (Vector2(L["goal"]) - beach).normalized()
		tac.start_area(h, landed, gw.econ.land_point(beach + dir * 40.0), Vector2.INF, true)
	_resuming = false
	if gw.ops != null and gw.ops.has_method("on_landed"):
		gw.ops.on_landed(h, landed, beach)


	if gw.diplo != null and gw.ops != null:
		var bo: int = gw.ops._owner_at(beach)
		if bo > 0 and bo != c and not gw.diplo.at_war(c, bo) and not gw.diplo.may_cross(c, bo):
			gw.diplo.close_land(c, bo)
	var cc: Country = gw.country_by_id(c)
	if cc != null and cc.is_player:
		gw.say(cc, Loc.mk("Армия №%d высадилась: %d ед.%s", [h.army_no, landed.size(), (Loc.t(", потери в море %d") % int(L["lost"])) if int(L["lost"]) > 0 else ""]))
	if gw.battle_watch != null:
		gw.battle_watch.note(beach, 3.0, "Высадка", c)


func _say(L: Dictionary, text: String) -> void :
	var c: Country = gw.country_by_id(int(L["c"]))
	if c != null and c.is_player:
		gw.say(c, text)



func _warn(L: Dictionary) -> void :
	var p: Country = gw.player
	if p == null or _warned.has(int(L["id"])) or not gw.army._hostile(int(L["c"]), p.id):
		return
	var b0: Vector2 = front(L["home"])
	if not b0.is_finite():
		return
	var seen: bool = gw.vision == null or gw.vision.sees(b0)
	var bc: Vector2 = L["beach"]
	var cc: = Vector2i(floori(bc.x / GameWorld.CELL), floori(bc.y / GameWorld.CELL))
	var mine: bool = gw.data.inside(cc.x, cc.y) and _near_land_of(p.id, cc, 40)
	if seen or (mine and b0.distance_to(bc) < 600.0):
		_warned[int(L["id"])] = true
		var foe: Country = gw.country_by_id(int(L["c"]))
		gw.message.emit(Loc.msg(Loc.mk("Вражеский десант (%s) идёт к берегу!", [Loc.name(foe.name) if foe != null else "?"])))
		Sfx.play("ui_alert", Vector2.INF, -6.0)




func _tick_exp(e: Dictionary, dt: float) -> void :
	var path: PackedVector2Array = e["path"]
	_sail(e, path, EXP_SPEED, dt)
	if int(e["i"]) < path.size():
		return
	if int(e["stage"]) == 1:
		expeditions.erase(e)
		return
	_arrive(e)


func _arrive(e: Dictionary) -> void :
	var c: Country = gw.country_by_id(int(e["c"]))
	expeditions.erase(e)
	if c == null or c.eliminated:
		return
	var site: Vector2i = _site_near(c, e["cell"])
	var city: City = null
	if site.x >= 0:
		gw.set_meta("poor_city", true)
		city = gw.found_city(site, c, City.Kind.TOWN)
		gw.remove_meta("poor_city")
	if city == null:

		c.add_money(int(EXP_COST["money"]) / 2)
		var back: = PackedVector2Array(e["path"])
		back.reverse()
		e["path"] = back
		e["i"] = 0
		e["stage"] = 1
		expeditions.append(e)
		if c.is_player:
			gw.say(c, Loc.mk("Экспедиция: место занято, корабль возвращается (+%d)", [int(EXP_COST["money"]) / 2]))
		return
	colonies[city.id] = {"base": city.claim_max, "supplied": true, "body": int(e["body"]), "t0": gw.game_time, "land": false, "land_t": -99.0}
	city.claim_max = maxi(12, roundi(float(city.claim_max) * COLONY_CLAIM))
	beached.append([e["pos"], float(e["heading"]), gw.game_time + 20.0, c.id, false, true])
	if c.is_player:
		gw.say(c, Loc.mk("Основана колония %s", [Loc.name(city.name)]))
		Sfx.ui("ui_capture")
	gw.news_m(Loc.mk("%s ОСНОВЫВАЕТ КОЛОНИЮ %s", [Loc.name(c.name).to_upper(), Loc.name(city.name).to_upper()]), "amber")
	if gw.ai != null:
		gw.ai._stat(c, "colonies")





func _site_near(c: Country, cell: Vector2i) -> Vector2i:
	if _site_why(c, cell) == "" and not _covers_deposit(cell):
		return cell
	var dep: Dictionary = _colony_deposit(cell)
	if not dep.is_empty():
		var dc: Vector2i = dep["cell"]
		var cands: Array = []
		for r in [27, 31, 24, 35]:
			for a in range(0, 360, 20):
				var q0: Vector2i = dc + Vector2i(roundi(cos(deg_to_rad(a)) * r), roundi(sin(deg_to_rad(a)) * r))
				cands.append([Vector2(q0).distance_to(Vector2(cell)) + float(r - 27) * 0.5, q0])
		cands.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
		var tries: int = 0
		for cd: Array in cands:
			var q1: Vector2i = cd[1]
			if _site_why(c, q1) != "":
				continue
			tries += 1
			if not _covers_deposit(q1):
				return q1
			if tries > 14:
				break
	for r in [6, 12, 18, 24]:
		for a in range(0, 360, 45):
			var q: Vector2i = cell + Vector2i(roundi(cos(deg_to_rad(a)) * r), roundi(sin(deg_to_rad(a)) * r))
			if _site_why(c, q) == "" and not _covers_deposit(q):
				return q
	if _site_why(c, cell) == "":
		return cell
	for r in [6, 12, 18]:
		for a in range(0, 360, 45):
			var q2: Vector2i = cell + Vector2i(roundi(cos(deg_to_rad(a)) * r), roundi(sin(deg_to_rad(a)) * r))
			if _site_why(c, q2) == "":
				return q2
	return Vector2i(-1, -1)




func _colony_deposit(cell: Vector2i) -> Dictionary:
	if gw.econ == null:
		return {}
	var best: Dictionary = {}
	var bd: int = 41
	for dp: Dictionary in gw.econ.deposits:
		if dp["mine"] != null:
			continue
		var dc: Vector2i = dp["cell"]
		var dd: int = maxi(absi(dc.x - cell.x), absi(dc.y - cell.y))
		if dd < bd and gw.data.get_owner_id(dc.x, dc.y) == 0:
			bd = dd
			best = dp
	return best




func _covers_deposit(site: Vector2i) -> bool:
	if gw.econ == null:
		return false
	var near: Array = []
	for dp: Dictionary in gw.econ.deposits:
		var dc: Vector2i = dp["cell"]
		if dp["mine"] == null and maxi(absi(dc.x - site.x), absi(dc.y - site.y)) <= 44:
			near.append(dp)
	if near.is_empty():
		return false
	var plan: Dictionary = gw.can_found_city(site, City.Kind.TOWN)
	if not bool(plan["ok"]):
		plan = gw.can_found_city(site, City.Kind.VILLAGE)
		if not bool(plan["ok"]):
			return false
	var cs: Dictionary = {}
	for q: Vector2i in plan["cells"]:
		cs[q] = true
	for dp: Dictionary in near:
		var dc2: Vector2i = dp["cell"]
		var sz: Vector2i = Military.size_of(Facility.Kind.OIL_RIG if String(dp.get("res", "")) == "oil" else Facility.Kind.MINE)
		var nw: Vector2i = Military.nw_for(Facility.Kind.OIL_RIG if String(dp.get("res", "")) == "oil" else Facility.Kind.MINE, dc2)
		for y in range(nw.y - 2, nw.y + sz.y + 2):
			for x in range(nw.x - 2, nw.x + sz.x + 2):
				if cs.has(Vector2i(x, y)):
					return true
	return false



func _supply() -> void :
	var pr: Ports = _ports()
	if pr == null:
		return
	for cid: int in colonies.keys():
		if cid < 0 or cid >= gw.cities.size():
			colonies.erase(cid)
			continue
		var city: City = gw.cities[cid]
		var col: Dictionary = colonies[cid]
		var c: Country = gw.country_by_id(city.country_id)
		if c == null:
			continue
		var sup: bool = false
		for f: Facility in gw.mil.facilities:
			if f.kind == Facility.Kind.PORT and f.country_id == c.id and gw.mil.alive(f) and int(pr._port_state(f)["body"]) == int(col["body"]) and int(col["body"]) > 0:
				sup = true
				break
		if not sup:
			if gw.game_time - float(col["land_t"]) > LANDLINK_DT:
				col["land_t"] = gw.game_time
				col["land"] = _land_link(city, c)
			sup = bool(col["land"])
		if sup == bool(col["supplied"]):
			continue
		col["supplied"] = sup
		var base: int = int(col["base"])
		if sup:
			var want: int = maxi(12, roundi(float(base) * COLONY_CLAIM))
			if want > city.claim_max:
				city.claim_max = want
				city.claim_done = false
				city.frontier = [Vector3i(city.center.x, city.center.y, 0)]
				city.visited = {city.center.y * gw.data.w + city.center.x: true}
		else:
			city.claim_max = mini(city.claim_max, maxi(10, roundi(float(base) * COLONY_CLAIM_DRY)))
		if c.is_player:
			gw.say(c, (Loc.t("Колония %s снова снабжается") if sup else Loc.t("Колония %s без снабжения: нужен свой порт на этом море")) % city.name)


func _land_link(city: City, c: Country) -> bool:
	var best: City = null
	var bd: int = 1 << 30
	for id in c.city_ids:
		if colonies.has(id):
			continue
		var oc: City = gw.cities[id]
		var dd: int = (oc.center - city.center).length_squared()
		if dd < bd:
			bd = dd
			best = oc
	if best == null:
		return false
	gw.econ.nav_path(Vector2(city.center * GameWorld.CELL), Vector2(best.center * GameWorld.CELL))
	return gw.econ.nav_last_ok



func grows(city: City) -> bool:
	if not colonies.has(city.id) or bool(colonies[city.id]["supplied"]):
		return true
	return int(gw.game_time / GameWorld.EXPAND_DT) % 2 == 0






func ai_think(c: Country, P: Dictionary) -> void :
	var now: float = gw.game_time
	var tn: Array = ai_towns.get(c.id, [-1, now])
	if int(tn[0]) != c.city_ids.size():
		tn = [c.city_ids.size(), now]
		ai_towns[c.id] = tn
	if now < 360.0 or now < float(ai_next.get(c.id, 0.0)):
		return
	ai_next[c.id] = now + 110.0 + float(c.id % 5) * 9.0
	var pr: Ports = _ports()
	if pr == null:
		return
	var port: Facility = pr.port_of(c)
	if port == null or _ready_why(port, c) != "":
		return
	var reserve: int = gw.ai.treasury_reserve(c, P) + 600 if gw.ai != null else 2000
	if c.money < int(EXP_COST["money"]) + reserve or c.food < int(EXP_COST["food"]) + 80:
		return
	var want: float = 0.25 + 0.45 * float(P.get("trade", 0.5)) + 0.3 * float(P.get("sneaky", 0.5)) - 0.35 * float(P.get("caution", 0.5))
	var dr: Variant = gw.get("drama")
	if dr != null:
		want += 0.45 * float(dr.bias(c, "colony"))
	if gw.army.fire.rf() > want:
		return
	if dr != null and _drama_colony(c, port, int(dr.colony_target(c))):
		return
	var full: bool = now - float(tn[1]) > 420.0 and c.city_ids.size() >= 3
	var sites: Array = []
	var pc: Vector2 = port.center_px()
	for dp: Dictionary in gw.econ.deposits:
		var dc: Vector2i = dp["cell"]
		if dp["mine"] != null or int(dp.get("left", 0)) < 150 or gw.data.get_owner_id(dc.x, dc.y) != 0:
			continue
		var dd: float = Vector2(dc * GameWorld.CELL).distance_to(pc)
		if dd > EXP_MAX_SEA * 0.6:
			continue
		sites.append([float(gw.econ.market_price(String(dp.get("res", "metal")))) * 40.0 - dd, dc])
	sites.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var tries: int = 0
	for s: Array in sites:
		var dc2: Vector2i = s[1]
		if _near_land_of(c.id, dc2, GameWorld.TOWN_REACH):
			continue
		tries += 1
		if tries > 4:
			break
		for r in [12, 18]:
			for a in range(0, 360, 60):
				var q: Vector2i = dc2 + Vector2i(roundi(cos(deg_to_rad(a)) * r), roundi(sin(deg_to_rad(a)) * r))
				if launch_expedition(port, q) == "":
					return
	if not full:
		return

	var body: int = int(pr._port_state(port)["body"])
	var rr: = Rng.new(int(now) + c.id * 31)
	for t in 40:
		var q2: = Vector2i(rr.range_ab(2, pr._w - 3), rr.range_ab(2, pr._h - 3))
		if pr._body_at(q2) != body:
			continue
		var lp: Vector2 = gw.econ.land_point(pr.cell_px(q2), 6)
		var cell: = Vector2i(floori(lp.x / GameWorld.CELL), floori(lp.y / GameWorld.CELL))
		var inl: Vector2i = cell + (cell - q2 * Ports.K).sign() * 10
		if launch_expedition(port, inl) == "":
			return





func _drama_colony(c: Country, port: Facility, to: int) -> bool:
	var tc: Country = gw.country_by_id(to)
	if tc == null or tc.eliminated:
		return false
	var pc: Vector2 = port.center_px()
	var near: Array = []
	for cid in tc.city_ids:
		near.append([Vector2(gw.cities[cid].center * GameWorld.CELL).distance_to(pc), cid])
	near.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))
	var tries: int = 0
	for e: Array in near.slice(0, 2):
		var cc: Vector2i = gw.cities[int(e[1])].center
		var a0: int = int(gw.game_time / 30.0) % 8 * 45
		for k in 8:
			var ang: float = deg_to_rad(float(a0 + k * 45))
			var rr: float = float(FOREIGN_GAP + 8) / maxf(absf(cos(ang)), absf(sin(ang)))
			var q: = cc + Vector2i(roundi(cos(ang) * rr), roundi(sin(ang) * rr))
			if not gw.data.inside(q.x, q.y) or gw.data.get_owner_id(q.x, q.y) != 0 or not Biome.is_natural_land(gw.data.get_biome(q.x, q.y)):
				continue
			tries += 1
			if tries > 16:
				return false
			if launch_expedition(port, q) == "":
				return true
	return false






func _coast_fire(dt: float) -> void :
	var now: float = gw.game_time
	if now - _guns_t > 2.0:
		_guns_t = now
		_guns.clear()
		for f: Facility in gw.mil.facilities:
			if (f.kind == Facility.Kind.AD_MFG or f.kind == Facility.Kind.AD_SPAAG) and gw.mil.alive(f) and not f.moving:
				_guns.append([f, 100.0 if f.kind == Facility.Kind.AD_MFG else 210.0, 6.0 if f.kind == Facility.Kind.AD_MFG else 9.0, 1.1 if f.kind == Facility.Kind.AD_MFG else 0.9, 30 if f.kind == Facility.Kind.AD_MFG else 50])
	for L: Dictionary in landings:
		var st: int = int(L["stage"])
		if st != Stage.BOARD and st != Stage.SAIL:
			continue
		for b: Dictionary in L["boats"]:
			if bool(b["sunk"]) or bool(b["done"]):
				continue
			_shoot_at(b, int(L["c"]), L, now)
	for e: Dictionary in expeditions:
		_shoot_at(e, int(e["c"]), {}, now)


func _shoot_at(b: Dictionary, c: int, L: Dictionary, now: float) -> void :
	var p: Vector2 = b["pos"]
	var army: Army = gw.army
	for o: Unit in army._near(p, 240.0):
		if not o.alive() or not o.ground() or o.indirect() or not army._hostile(o.country_id, c):
			continue
		var d: float = o.pos.distance_to(p)
		var sp: Dictionary = Army.SPEC[o.type]
		if (o.kit & Unit.KIT_FPV) != 0 and o.fpv_cd <= 0.0 and d <= Army.FPV_R:
			var oc: Country = gw.country_by_id(o.country_id)
			if oc != null and oc.doctrine_fpv:
				o.fpv_cd = Army.FPV_CD
				var hit: bool = army.fire.ri(100) < FPV_HIT
				_hit(b, FPV_DMG if hit else 0.0, o.country_id, L, "fpv")
				if bool(b.get("sunk", false)):
					return
				continue
		if o.fire_cd > 0.0 or d > float(sp["range"]):
			continue
		o.fire_cd = float(sp["cd"]) * army.fire.rfr(0.9, 1.2)
		o.heading = (p - o.pos).angle()
		o.update_frame()

		var acc: float = 0.35 if o.type == Unit.Type.ATGM else 0.45
		var k: float = 1.0 if o.type == Unit.Type.TANK else (0.8 if o.type == Unit.Type.ATGM else (0.6 if o.type == Unit.Type.IFV else 0.5))
		if gw._on_screen(o.pos, 30.0):
			gw.fx.spawn("muzzle_flash" if o.type != Unit.Type.ATGM else "atgm_launch", (o.pos + Vector2.from_angle(o.heading) * 4.0).round(), 6)
		var hit2: bool = army.fire.rf() < acc
		_hit(b, float(sp["dmg"]) * k if hit2 else 0.0, o.country_id, L, "atgm" if o.type == Unit.Type.ATGM else ("tank" if o.type == Unit.Type.TANK else "gun"))
		if bool(b.get("sunk", false)):
			return
	for g: Array in _guns:
		var f: Facility = g[0]
		if not gw.mil.alive(f) or not army._hostile(f.country_id, c) or f.center_px().distance_to(p) > float(g[1]):
			continue
		var key: String = "f%d" % f.id
		if now < float(_cd.get(key, 0.0)):
			continue
		_cd[key] = now + float(g[3])
		_hit(b, float(g[2]) if army.fire.ri(100) < int(g[4]) else 0.0, f.country_id, L, "gun")
		if bool(b.get("sunk", false)):
			return
	if gw.mil.air != null:
		for a: Aircraft in gw.mil.air.aircraft:
			if a.type != Aircraft.Type.HELI or not a.airborne() or a.state == Aircraft.State.DEAD or not army._hostile(a.country_id, c):
				continue
			if a.pos.distance_to(p) > 130.0:
				continue
			var key2: String = "a%d" % a.id
			if now < float(_cd.get(key2, 0.0)):
				continue
			_cd[key2] = now + 1.0
			_hit(b, 10.0 if army.fire.ri(100) < 60 else 0.0, a.country_id, L, "gun")
			if bool(b.get("sunk", false)):
				return



func _hit(b: Dictionary, dmg: float, by: int, L: Dictionary, what: String) -> void :
	var p: Vector2 = b["pos"]
	var on: bool = gw._on_screen(p, 40.0)
	if dmg <= 0.0:
		if on:
			gw.fx.spawn("splash", (p + Vector2(randf_range(-7.0, 7.0), randf_range(-5.0, 5.0))).round(), 5)
		return
	b["hp"] = float(b["hp"]) - dmg
	b["hit_t"] = gw.game_time
	if on:
		gw.fx.spawn("atgm_hit" if what == "atgm" or what == "fpv" or what == "strike" or what == "shell" else "hit_small", p.round(), 6)
	if _snd_t <= 0.0:
		_snd_t = 0.35
		Sfx.play("atgm_hit" if what == "atgm" else ("mg_burst" if what == "gun" or what == "tank" else "expl_small"), p, -8.0)
	if float(b["hp"]) <= 0.0:
		sunk_by[what] = int(sunk_by.get(what, 0)) + 1
		_sink(b, by, L)


func _sink(b: Dictionary, by: int, L: Dictionary) -> void :
	if bool(b.get("sunk", false)):
		return
	b["sunk"] = true
	var p: Vector2 = b["pos"]
	gw.fx.spawn("explosion_m" if bool(b.get("veh", false)) else "explosion_s", p.round(), 6)
	gw.fx.spawn("splash", (p + Vector2(3, 1)).round(), 5)
	Sfx.play("expl_big" if bool(b.get("veh", false)) else "expl_small", p, -4.0)
	var att: Country = gw.country_by_id(by)
	if L.is_empty():

		expeditions.erase(b)
		var oc: Country = gw.country_by_id(int(b["c"]))
		if oc != null and oc.is_player:
			gw.say(oc, Loc.mk("Экспедиционный корабль потоплен"))
		if att != null and att.is_player:
			gw.say(att, Loc.mk("Потоплен корабль колонистов (%s)", [Loc.name(oc.name) if oc != null else "?"]))
		if att != null:
			att.destroyed += int(EXP_COST["money"])
		return
	var n: int = 0
	for u: Unit in b["u"]:
		if not u.alive():
			continue
		n += 1
		u.pos = p
		u.hp = 0.0
		u.state = Unit.State.DEAD
		u.dead_t = gw.game_time
		if att != null and by != u.country_id:
			att.destroyed += int(Army.SPEC[u.type]["cost"]) + (100 if u.type == Unit.Type.TANK else 0)
	var c: int = int(L["c"])
	L["lost"] = int(L["lost"]) + n
	sunk[c] = int(sunk.get(c, 0)) + 1
	drowned[c] = int(drowned.get(c, 0)) + n
	if gw.battle_watch != null:
		gw.battle_watch.note(p, 4.0, "", c)
	var cc: Country = gw.country_by_id(c)
	if cc != null and cc.is_player:
		gw.say(cc, Loc.mk("Армия №%d: лодка потоплена, потеряно %d ед.", [(L["home"] as Facility).army_no, n]))
	elif att != null and att.is_player:
		gw.say(att, Loc.mk("Вражеская лодка потоплена: −%d ед.", [n]))



func on_strike(p: Vector2, r_px: float, by: int) -> void :
	_blast(p, r_px, STRIKE_DMG, by, true)



func on_shell(p: Vector2, r: float, dmg: float, by: int) -> void :
	_blast(p, r, dmg, by, false)


func _blast(p: Vector2, r: float, dmg: float, by: int, strike: bool) -> void :
	if landings.is_empty() and expeditions.is_empty():
		return
	for L: Dictionary in landings.duplicate():
		if int(L["stage"]) < Stage.BOARD or not (strike or gw.army._hostile(by, int(L["c"]))):
			continue

		var near: Dictionary = {}
		var nd: float = r + 4.0
		for b: Dictionary in L["boats"]:
			if bool(b["sunk"]) or bool(b["done"]):
				continue
			var d0: float = (b["pos"] as Vector2).distance_to(p)
			if d0 <= nd:
				nd = d0
				near = b
		for b: Dictionary in L["boats"]:
			if bool(b["sunk"]) or bool(b["done"]):
				continue
			var d: float = (b["pos"] as Vector2).distance_to(p)
			if strike:
				if b == near:
					_hit(b, dmg, by, L, "strike")
				elif d <= r + 10.0:
					_hit(b, dmg * 0.3, by, L, "strike")
			elif d <= r + 4.0:
				_hit(b, dmg * 1.5, by, L, "shell")
			elif d <= r * 2.2:
				_hit(b, dmg * 0.3, by, L, "shell")
	for e: Dictionary in expeditions.duplicate():
		if not (strike or gw.army._hostile(by, int(e["c"]))):
			continue
		if (e["pos"] as Vector2).distance_to(p) <= r + 6.0:
			_hit(e, dmg * (1.2 if not strike else 1.0), by, {}, "strike" if strike else "shell")



func spotted_for(cid: int, eyes: Array) -> Array:
	var out: Array = []
	for L: Dictionary in landings:
		if int(L["stage"]) != Stage.SAIL and int(L["stage"]) != Stage.BOARD or not gw.army._hostile(cid, int(L["c"])):
			continue
		for b: Dictionary in L["boats"]:
			if bool(b["sunk"]) or bool(b["done"]):
				continue
			var p: Vector2 = b["pos"]
			for ey: Array in eyes:
				if p.distance_squared_to(ey[0]) <= float(ey[1]) * 1.7:
					var lead: Vector2 = p + Vector2.from_angle(float(b["heading"])) * BOAT_SPEED * (0.0 if float(b["delay"]) > 0.0 else 2.0)
					out.append([lead, null, bool(ey[2])])
					break
	return out




func _sea_q(p: Vector2) -> Vector2i:
	var k: float = float(Ports.K * GameWorld.CELL)
	return Vector2i(floori(p.x / k), floori(p.y / k))



func _sea_near(p: Vector2, r: int, body: int = 0) -> Vector2i:
	var pr: Ports = _ports()
	pr.ensure_sea()
	var c: Vector2i = _sea_q(p)
	var best: = Vector2i(-1, -1)
	var bd: int = 1 << 30
	for dy in range( - r, r + 1):
		for dx in range( - r, r + 1):
			var dd: int = dx * dx + dy * dy
			if dd >= bd:
				continue
			var b: int = pr._body_at(c + Vector2i(dx, dy))
			if b == 0 or (body > 0 and b != body):
				continue
			bd = dd
			best = c + Vector2i(dx, dy)
	return best





var _lm: PackedInt32Array = PackedInt32Array()
var _lm_ver: int = -1





static func _lm_runs(sol: PackedByteArray, W: int, H: int) -> PackedInt32Array:
	var out: = PackedInt32Array()
	out.resize(W * H)
	var rs: = PackedInt32Array()
	var re: = PackedInt32Array()
	var ry: = PackedInt32Array()
	var par: = PackedInt32Array()
	var prev0: int = 0
	var prev1: int = 0
	for y in H:
		var base: int = y * W
		var end: int = base + W
		var cur0: int = rs.size()
		var x: int = base
		while x < end:
			var a: int = sol.find(0, x)
			if a < 0 or a >= end:
				break
			var b: int = sol.find(1, a)
			if b < 0 or b > end:
				b = end
			par.append(rs.size())
			rs.append(a - base)
			re.append(b - base - 1)
			ry.append(y)
			x = b
		var cur1: int = rs.size()
		var p: int = prev0
		for r in range(cur0, cur1):
			while p < prev1 and re[p] < rs[r]:
				p += 1
			var q: int = p
			while q < prev1 and rs[q] <= re[r]:
				var ra: int = q
				while par[ra] != ra:
					par[ra] = par[par[ra]]
					ra = par[ra]
				var rb: int = r
				while par[rb] != rb:
					par[rb] = par[par[rb]]
					rb = par[rb]
				if ra < rb:
					par[rb] = ra
				elif rb < ra:
					par[ra] = rb
				q += 1
		prev0 = cur0
		prev1 = cur1
	var lab: = PackedInt32Array()
	lab.resize(rs.size())
	var nid: int = 0
	for r2 in rs.size():
		var rt: int = r2
		while par[rt] != rt:
			rt = par[rt]
		if lab[rt] == 0:
			nid += 1
			lab[rt] = nid
		var l: int = lab[rt]
		var b2: int = ry[r2] * W
		for xx in range(rs[r2], re[r2] + 1):
			out[b2 + xx] = l
	return out


func _land_id(p: Vector2) -> int:
	var e: Economy = gw.econ
	if e == null or e.nav == null:
		return 0
	var sz: Vector2i = e.nav.region.size
	if _lm_ver != e.nav_solid_ver or _lm.size() != sz.x * sz.y:
		_lm_ver = e.nav_solid_ver
		if e.nav_solid_b.size() == sz.x * sz.y:
			_lm = _lm_runs(e.nav_solid_b, sz.x, sz.y)
		else:
			_lm = PackedInt32Array()
			_lm.resize(sz.x * sz.y)
			var nid: int = 0
			var st: PackedInt32Array = PackedInt32Array()
			for y in sz.y:
				for x in sz.x:
					var i0: int = y * sz.x + x
					if _lm[i0] != 0 or e.nav.is_point_solid(Vector2i(x, y)):
						continue
					nid += 1
					_lm[i0] = nid
					st.resize(0)
					st.append(i0)
					while not st.is_empty():
						var i: int = st[st.size() - 1]
						st.resize(st.size() - 1)
						var cx: int = i % sz.x
						var cy: int = i / sz.x
						for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
							var nx: int = cx + o.x
							var ny: int = cy + o.y
							if nx < 0 or ny < 0 or nx >= sz.x or ny >= sz.y:
								continue
							var j: int = ny * sz.x + nx
							if _lm[j] == 0 and not e.nav.is_point_solid(Vector2i(nx, ny)):
								_lm[j] = nid
								st.append(j)
	var c: Vector2i = e._nearest_open(e._nav_cell(p))
	return _lm[c.y * sz.x + c.x]


func _plan(country_id: int, from: Vector2, to: Vector2, retreat: bool = false, sea_only: bool = false) -> Dictionary:
	var out: Dictionary = {"ok": false, "why": Loc.t("Нет пути ни по суше, ни морем"), "land": false}
	var pr: Ports = _ports()
	var e: Economy = gw.econ
	if pr == null or e == null or e.nav == null:
		return out
	pr.ensure_sea()
	var p1: PackedVector2Array = e.army_path(from, to)
	if e.nav_last_pending and not sea_only:
		out["why"] = Operations.PENDING
		out["land"] = true
		return out
	if e.nav_last_ok and not sea_only:
		out["why"] = ""
		out["land"] = true
		return out
	var tip: Vector2 = p1[p1.size() - 1] if not p1.is_empty() else from

	var bases: Array = []
	if not retreat:
		if gw.get("navy") != null:
			for f: Facility in gw.navy.bases_of(country_id):
				var bq: Vector2i = gw.navy.berth_q(f)
				if bq.x >= 0:
					bases.append([bq, pr._body_at(bq), f.center_px(), _land_id(e.land_point(pr.cell_px(bq), 10))])
		if bases.is_empty():
			out["why"] = Loc.t("Нужна морская база: десант грузится только на ней")
			return out
	var beaches: Array = _beaches(country_id, to, sea_only)
	if beaches.is_empty():
		out["why"] = Loc.t("Нет берега у цели для высадки")
		return out
	var tries: int = 0
	for bc: Array in beaches:
		tries += 1
		if tries > 4:
			break
		var body: int = int(bc[3])
		var qa: = Vector2i(-1, -1)
		if retreat:
			qa = _sea_near(tip, 6, body)
			if qa.x < 0:
				qa = _sea_near(from, 30, body)
			if qa.x < 0:
				out["why"] = Loc.t("Нет своего берега на этом море")
				continue
		var pick: = PackedVector2Array()
		if not retreat:


			var lf: int = _land_id(from)
			var bd: float = INF
			var any_b: bool = false
			for bs: Array in bases:
				if int(bs[1]) != body:
					continue
				any_b = true
				if lf > 0 and int(bs[3]) == lf and from.distance_to(bs[2]) < bd:
					bd = from.distance_to(bs[2])
					qa = bs[0]
			if not any_b:
				out["why"] = Loc.t("Нужна морская база на этом море")
				continue
			if qa.x < 0:
				var qp: Vector2i = _sea_near(from, PICK_R, body)
				if qp.x < 0:
					out["why"] = Loc.t("Нет моря у войск: катерам не подойти")
					continue
				var pd: float = INF
				for bs2: Array in bases:
					if int(bs2[1]) != body:
						continue
					var pp: PackedVector2Array = pr._path(bs2[0], qp) if bs2[0] != qp else PackedVector2Array([pr.cell_px(qp), pr.cell_px(qp) + Vector2(1, 0)])
					var pl: float = _plen(pp) if pp.size() >= 2 else INF
					if pl < pd:
						pd = pl
						pick = pp
				if pick.size() < 2 or pd > PICK_MAX_SEA:
					out["why"] = Loc.t("Морская база слишком далеко: катерам не дойти")
					continue
				qa = qp
		var emb: Vector2 = e.land_point(pr.cell_px(qa), 10)
		var l1: PackedVector2Array = e.nav_path(from, emb)
		if not e.nav_last_ok:
			out["why"] = Loc.t("Не дойти до своего берега") if retreat else (Loc.t("Не дойти до берега к катерам") if not pick.is_empty() else Loc.t("Не дойти до морской базы"))
			continue
		var sea: PackedVector2Array = pr._path(qa, bc[2])
		if sea.size() < 2:
			out["why"] = Loc.t("Нет морского пути")
			continue
		var sl: float = _plen(sea)
		if sl > LAND_MAX_SEA:
			out["why"] = Loc.t("Слишком далеко морем: %.1f км (макс. %.1f)") % [sl / 1000.0, LAND_MAX_SEA / 1000.0]
			continue
		var beach: Vector2 = bc[1]
		var l2: PackedVector2Array = e.nav_path(beach, to)
		if not e.nav_last_ok:
			if beach.distance_to(to) > 400.0:
				continue
			l2 = PackedVector2Array([to])
		var whole: = PackedVector2Array([from])
		whole.append_array(l1)
		whole.append_array(sea)
		whole.append(beach)
		whole.append_array(l2)
		return {"ok": true, "why": "", "land": false, "embark": emb, "beach": beach, "sea": sea, "land1": _plen(l1) + from.distance_to(l1[0] if not l1.is_empty() else emb), 
			"sea_len": sl, "land2": _plen(l2) + beach.distance_to(l2[0] if not l2.is_empty() else to), "path": whole, "eta": 0.0, 
			"pick": pick, "pick_len": _plen(pick)}
	return out



func _beaches(country_id: int, to: Vector2, near: bool = false) -> Array:
	var pr: Ports = _ports()
	var e: Economy = gw.econ
	var c0: Vector2i = _sea_q(to)
	var raw: Array = []
	for dy in range( - BEACH_R, BEACH_R + 1):
		for dx in range( - BEACH_R, BEACH_R + 1):
			var q: = c0 + Vector2i(dx, dy)
			var b: int = pr._body_at(q)
			if b == 0:
				continue
			var coast: bool = false
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: = q + o
				if n.x >= 0 and n.y >= 0 and n.x < pr._w and n.y < pr._h and ( not e.nav.is_point_solid(n) or e.blocked.has(n)):
					coast = true
					break
			if coast:
				raw.append([dx * dx + dy * dy, q, b])
	raw.sort_custom( func(a: Array, b2: Array) -> bool: return int(a[0]) < int(b2[0]))
	var out: Array = []
	var taken: Array = []
	for r: Array in raw:
		var q2: Vector2i = r[1]
		var far: bool = true
		for t: Vector2i in taken:
			if (t - q2).length_squared() < 9:
				far = false
				break
		if not far:
			continue
		taken.append(q2)
		var lp: Vector2 = e.land_point(pr.cell_px(q2), 10)
		if lp == pr.cell_px(q2):
			continue
		var foes: int = 0

		var under: float = 0.0
		for city: City in gw.cities:
			if not gw.army._hostile(country_id, city.country_id):
				continue
			var cr: float = float(city.radius * GameWorld.CELL) * 1.5 + 120.0
			var dc: float = lp.distance_to(Vector2(city.center * GameWorld.CELL))
			if dc < cr:
				under = maxf(under, 600.0 * (1.0 - dc / cr))
		for u: Unit in gw.army._near(lp, 200.0):
			if u.alive() and u.ground() and gw.army._hostile(country_id, u.country_id) and u.pos.distance_to(lp) < 200.0:
				foes += 1
		out.append([sqrt(float(r[0])) * 16.0 + ((float(foes) * 90.0 + under) if not near else lp.distance_to(to) * 0.25), lp, q2, int(r[2])])
		if out.size() >= 10:
			break
	out.sort_custom( func(a: Array, b2: Array) -> bool: return float(a[0]) < float(b2[0]))
	return out




static func _plen(p: PackedVector2Array) -> float:
	var s: float = 0.0
	for i in range(1, p.size()):
		s += p[i - 1].distance_to(p[i])
	return s


static func _left_len(p: PackedVector2Array, i: int, pos: Vector2) -> float:
	if i >= p.size():
		return 0.0
	var s: float = pos.distance_to(p[i])
	for k in range(i + 1, p.size()):
		s += p[k - 1].distance_to(p[k])
	return s


static func centre(mem: Array) -> Vector2:
	var c: = Vector2.ZERO
	for u: Unit in mem:
		c += u.pos
	return c / float(maxi(1, mem.size()))


func save_state() -> Dictionary:
	return Save.dump(self, ["_guns", "_guns_t", "_cd", "_plan_cache", "_resuming", "_fire_acc", "_snd_t", "_lm", "_lm_ver"])


func load_state(d: Dictionary) -> void :
	Save.fill(self, d, ["_guns", "_guns_t", "_cd", "_plan_cache", "_resuming", "_fire_acc", "_snd_t", "_lm", "_lm_ver"])
	_plan_cache.clear()
	_lm_ver = -1
	_guns.clear()
	_guns_t = -99.0
	if gw.ops != null and gw.ops.has_method("naval_loaded"):
		gw.ops.naval_loaded()
