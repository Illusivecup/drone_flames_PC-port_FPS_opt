class_name EconGuide
extends RefCounted







const CACHE_MS: int = 1000
const AVAIL_MS: int = 15000
const REWARD: Dictionary = {"farm": 200, "civ": 250, "power": 200, "mine": 300, "sawmill": 200, "oil_rig": 250, 
	"refinery": 300, "port": 400, "trade": 200, "town": 300, "defence": 300, 
	"fort": 250, "upgrade": 300, "grid": 250, "treaty": 300, "dport": 350, "town2": 400, "net": 300, "army2": 300, "titanium": 300, 
	"ent6": 300, "lvl3": 400, "town3": 500, "treaty2": 300, "conc": 400, "town4": 600, "ent10": 500}


const ACTION_KEYS: Array = ["dip_best", "upg_best", "net_best", "dp_ramp"]

const KEY_KIND: Dictionary = {
	"factory": Facility.Kind.DRONE_FACTORY, "droneport": Facility.Kind.DRONE_PORT, "tel": Facility.Kind.TEL, 
	"mfactory": Facility.Kind.MISSILE_FACTORY, "refinery": Facility.Kind.REFINERY, "power": Facility.Kind.POWER_PLANT, 
	"airfield": Facility.Kind.AIRFIELD, "farm": Facility.Kind.FARM, "civ": Facility.Kind.CIV_FACTORY, "mine": Facility.Kind.MINE, 
	"barracks": Facility.Kind.BARRACKS, "ad_mfg": Facility.Kind.AD_MFG, "ad_spaag": Facility.Kind.AD_SPAAG, 
	"ad_sam": Facility.Kind.AD_SAM, "ad_patriot": Facility.Kind.AD_PATRIOT, "ad_int": Facility.Kind.AD_INT, 
	"ad_radar": Facility.Kind.AD_RADAR, "ad_ew": Facility.Kind.AD_EW, "dugout": Facility.Kind.DUGOUT, 
	"sawmill": Facility.Kind.SAWMILL, "oil_rig": Facility.Kind.OIL_RIG, "port": Facility.Kind.PORT, 
	"solar_farm": Facility.Kind.SOLAR_FARM, 
}
const AD_KINDS: Array = [Facility.Kind.AD_MFG, Facility.Kind.AD_SPAAG, Facility.Kind.AD_SAM, Facility.Kind.AD_PATRIOT, Facility.Kind.AD_INT]
const ORE_TITLE: Dictionary = {"metal": "металл", "titanium": "титан", "precious": "драгметаллы"}
const ONE_OFF_MONEY: Array = ["build", "plan", "tribute", "aid", "subst", "upgrade"]
const EXTRA_NAMES: Dictionary = {"money": "деньги", "drones": "дроны", "missiles": "ракеты", "power": "энергия"}
const EXTRA_ICONS: Dictionary = {"money": "res_money", "drones": "res_drone", "missiles": "res_missile", "power": "res_power"}



static var plan_visible: bool = true


const TUTORIAL_PAID: Array = ["farm", "civ", "defence"]

var gw: GameWorld
var claimed: Dictionary = {}
var incl: Dictionary = {}
var _in_goals: bool = false
var _cache: Dictionary = {}
var _check_ms: int = -100000


func _init(world: GameWorld) -> void :
	gw = world




func invalidate() -> void :
	_cache.clear()
	_goal_sig = ""


var _goal_sig: String = ""



func _sig(p: Country) -> String:
	return "%d|%d|%d|%d|%d" % [p.id, p.capital_id, gw.mil.facilities.size(), p.city_ids.size(), claimed.size()]


func _cached(key: String, ms: int, fn: Callable) -> Variant:
	var now: int = Time.get_ticks_msec() if GameWorld.lab_tick < 0 else int(gw.game_time * 1000.0)
	var e: Array = _cache.get(key, [])
	if not e.is_empty() and now - int(e[0]) < ms:
		return e[1]
	var v: Variant = fn.call()
	_cache[key] = [now, v]
	return v




func _own(p: Country, kind: int) -> Array:
	var out: Array = []
	for f: Facility in gw.mil.facilities:
		if f.country_id == p.id and f.kind == kind and gw.mil.alive(f):
			out.append(f)
	return out


func _any(p: Country, kinds: Array) -> bool:
	for k: int in kinds:
		if not _own(p, k).is_empty():
			return true
	return false


func _works(f: Facility) -> bool:
	return gw.mil.alive(f) and not f.halted and ( not Military.uses_power(f.kind) or gw.mil.has_power(f))


func res_name(res: String) -> String:
	if EXTRA_NAMES.has(res):
		return Loc.t(String(EXTRA_NAMES[res]))
	return Loc.t(String(Economy.RES_NAMES.get(res, res)).to_lower())


static func res_icon(res: String) -> String:
	if EXTRA_ICONS.has(res):
		return String(EXTRA_ICONS[res])
	return String(Economy.RES_ICONS.get(res, "icon_info"))


func _io(res: String, n: int) -> Dictionary:
	return {"res": res, "per_min": n, "name": res_name(res), "icon": res_icon(res)}



func _in(st: Dictionary, res: String, src: String) -> int:
	return int((st["res_in"].get(res, {}) as Dictionary).get(src, 0))


func _out(st: Dictionary, res: String, src: String) -> int:
	return int((st["res_out"].get(res, {}) as Dictionary).get(src, 0))



const ONE_OFF: Array = ["surplus", "build", "subst", "tribute", "aid", "trade", "export", "upgrade"]


func _out_all(st: Dictionary, res: String, skip: Array = ONE_OFF) -> int:
	var n: int = 0
	var d: Dictionary = st["res_out"].get(res, {})
	for k: String in d:
		if not skip.has(k):
			n += int(d[k])
	return n


func _total(p: Country, kind: String, key: String) -> int:
	var st: Dictionary = gw.econ._stat_of(p.id)
	return int((st["total"].get(kind, {}) as Dictionary).get(key, 0))


func _lack(p: Country, cost: Dictionary) -> String:
	var m: String = p.missing_res(cost)
	return "" if m == "" else Loc.t(" Не хватает: %s.") % m


func _cap_city(p: Country) -> City:
	return gw.cities[p.capital_id] if p.capital_id >= 0 and p.capital_id < gw.cities.size() else null



func _best_ore(p: Country) -> String:
	for r: String in ["metal", "titanium", "precious"]:
		var mined: bool = false
		for f: Facility in _own(p, Facility.Kind.MINE):
			if String(f.deposit.get("res", "")) == r:
				mined = true
		if not mined and gw.econ._has_free_deposit(p, [r]):
			return r
	for r2: String in ["metal", "titanium", "precious"]:
		if gw.econ._has_free_deposit(p, [r2]):
			return r2
	return ""


func _has_trade(p: Country) -> bool:
	for k: Variant in gw.econ.trade.keys():
		var parts: PackedStringArray = str(k).split(":")
		if parts.size() == 2 and (int(parts[0]) == p.id or int(parts[1]) == p.id):
			return true
	return _total(p, "income", "trade") > 0 or _total(p, "spend", "trade") > 0 or _total(p, "income", "export") > 0 or _total(p, "spend", "import") > 0


func _coast_ok(p: Country) -> bool:
	return bool(_cached("coast%d" % p.id, AVAIL_MS, func() -> bool: return gw.econ.ports.has_port(p) or gw.econ.ports.find_site(p).x >= 0))


func _forest_ok(p: Country) -> bool:
	return bool(_cached("forest%d" % p.id, AVAIL_MS, func() -> bool: return _forest_site_exists(p)))


func _forest_site_exists(p: Country) -> bool:
	for cid in p.city_ids:
		var city: City = gw.cities[cid]
		for r in range(city.radius + 6, city.radius + 46, 6):
			for a in range(0, 360, 30):
				var q: Vector2i = city.center + Vector2i(roundi(cos(deg_to_rad(a)) * r), roundi(sin(deg_to_rad(a)) * r))
				if not gw.data.inside(q.x, q.y) or gw.data.get_owner_id(q.x, q.y) != p.id:
					continue
				if gw.econ.count_trees(q, Economy.SAW_R, 2) >= Economy.SAW_MIN_TREES and gw.mil.check_place(Facility.Kind.SAWMILL, Military.nw_for(Facility.Kind.SAWMILL, q), p, null, false) == "":
					return true
	return false






func goals(p: Country) -> Array:
	if p == null:
		return []
	var sg: String = _sig(p)
	if sg != _goal_sig:
		_goal_sig = sg
		_cache.erase("goals%d" % p.id)
	return _cached("goals%d" % p.id, CACHE_MS, func() -> Array: return _goals_safe(p))


func _goals_safe(p: Country) -> Array:
	_in_goals = true
	var out: Array = _goals(p)
	_in_goals = false
	return out





func _opt(p: Country, id: String, applies: bool) -> bool:
	if applies and p == gw.player:
		incl[id] = true
	return applies or incl.has(id) or claimed.has(id)


func _skip(out: Array, id: String, title: String, why: String, icon: String) -> void :
	out.append({"id": id, "title": title, "why": why, "icon": icon, "key": "", "done": true, "current": false, 
		"reward": 0, "cost": "", "ok": false, "msg": "", "skip": true})



func _cur_id(p: Country) -> String:
	if _in_goals or p == null:
		return ""
	return String(current_goal(p).get("id", ""))



func progress(p: Country) -> Array:
	var gs: Array = goals(p)
	var n: int = 0
	for g: Dictionary in gs:
		if bool(g["done"]):
			n += 1
	return [n, gs.size()]



func current_goal(p: Country) -> Dictionary:
	for g: Dictionary in goals(p):
		if bool(g["current"]):
			return g
	return {}




func _goal(out: Array, p: Country, id: String, title: String, why: String, icon: String, key: String, ok: bool, msg: String, placed: bool = false) -> void :
	var cost: Dictionary = {}
	if KEY_KIND.has(key):
		cost = Economy.build_cost(int(KEY_KIND[key]))
	elif key == "town":
		cost = {"money": Military.COST_TOWN}
	var done: bool = ok or placed or (p == gw.player and claimed.has(id))
	if not done and not cost.is_empty():
		why += _lack(p, cost)
	var rw: int = 0 if GameConfig.tutorial and TUTORIAL_PAID.has(id) else int(REWARD.get(id, 0))
	out.append({"id": id, "title": title, "why": why, "icon": icon, "key": key, "done": done, "current": false, 
		"reward": rw, "cost": Economy.cost_text(cost), "ok": ok, "msg": msg})


func _goals(p: Country) -> Array:
	var out: Array = []
	var econ: Economy = gw.econ
	_goal(out, p, "capital", Loc.t("Столица"), Loc.t("Тап по свободной земле: вырастет город, рядом сама встанет ТЭЦ и малые залежи руды."), 
		"icon_capital", "capital", p.capital_id >= 0, Loc.t("Столица основана"))
	if p.capital_id < 0:
		(out[0] as Dictionary)["current"] = true
		return out
	var farm_ok: bool = false
	for f: Facility in _own(p, Facility.Kind.FARM):
		farm_ok = farm_ok or _works(f)
	_goal(out, p, "farm", Loc.t("Колхоз: еда"), Loc.t("Самый дешёвый доход: +%d еды и +%d денег в минуту. Еда кормит армию, излишки продаются.") % [Economy.FARM_FOOD * 6, Economy.FARM_MONEY * 6], 
		"icon_farm", "farm", farm_ok, Loc.t("Колхоз построен"), not _own(p, Facility.Kind.FARM).is_empty())
	var civ_ok: bool = false
	for f2: Facility in _own(p, Facility.Kind.CIV_FACTORY):
		civ_ok = civ_ok or _works(f2)
	_goal(out, p, "civ", Loc.t("Завод товаров: деньги"), Loc.t("Главный доход: +%d денег в минуту и товары на продажу. Берёт 1 энергию — сеть сейчас %d/%d.") % [Economy.CIV_MONEY * 6, p.power_use, p.power_cap], 
		"icon_civ_factory", "civ", civ_ok, Loc.t("Завод товаров работает"), not _own(p, Facility.Kind.CIV_FACTORY).is_empty())
	var sources: int = _own(p, Facility.Kind.POWER_PLANT).size() + _own(p, Facility.Kind.SOLAR_FARM).size()
	var solar: bool = p.money < Military.cost_of(Facility.Kind.POWER_PLANT) + 300
	_goal(out, p, "power", Loc.t("Энергия: вторая станция"), Loc.t("Каждый завод, рудник и НПЗ берёт 1 энергию, город 1–2. Сеть %d/%d — нужен запас: ТЭЦ +%d, солнечная станция +%d (дешевле).") % [p.power_use, p.power_cap, Military.PLANT_CAP, Military.SOLAR_FARM_CAP], 
		"icon_solar" if solar else "icon_power", "solar_farm" if solar else "power", sources >= 2, Loc.t("Сеть усилена"))

	var ore: String = _best_ore(p)
	var mines: Array = _own(p, Facility.Kind.MINE)
	if not _opt(p, "mine", ore != "" or not mines.is_empty()):
		_skip(out, "mine", Loc.t("Рудник: пропуск"), Loc.t("На вашей земле нет залежей руды: металл и титан — покупкой или новым городом."), "icon_mine")
	else:
		var mine_ok: bool = false
		var mine_placed: bool = false
		for f3: Facility in mines:
			mine_ok = mine_ok or (_works(f3) and not f3.deposit.is_empty())
			mine_placed = mine_placed or not f3.deposit.is_empty()
		var r: String = ore if ore != "" else (String((mines[0] as Facility).deposit.get("res", "metal")) if not mines.is_empty() else "metal")
		_goal(out, p, "mine", Loc.t("Рудник: %s") % Loc.t(String(ORE_TITLE.get(r, "руда"))), Loc.t("Поставьте рудник прямо на значок залежи: +%d в минуту и +%d денег. %s") % [int(Economy.MINE_RATE.get(r, 2)) * 6, Economy.MINE_MONEY * 6, String(Economy.DEP_USE.get(r, ""))], 
			"icon_mine", "mine", mine_ok, Loc.t("Рудник работает"), mine_placed)
	var saws: Array = _own(p, Facility.Kind.SAWMILL)
	if not _opt(p, "sawmill", not saws.is_empty() or _forest_ok(p)):
		_skip(out, "sawmill", Loc.t("Лесопилка: пропуск"), Loc.t("Рядом нет леса: дерево — покупкой."), "icon_sawmill")
	else:
		var saw_ok: bool = false
		for f4: Facility in saws:
			saw_ok = saw_ok or (_works(f4) and String(econ._site_of(f4)["status"]) != "forest_cut")
		_goal(out, p, "sawmill", Loc.t("Лесопилка: дерево"), Loc.t("Дерево нужно почти для всех построек (у вас %d). Лесопилка у леса даёт до +%d в минуту, лес отрастает.") % [p.wood, Economy.SAW_WOOD_MAX * 6], 
			"icon_sawmill", "sawmill", saw_ok, Loc.t("Лесопилка работает"), not saws.is_empty())

	var rigs: Array = _own(p, Facility.Kind.OIL_RIG)
	var refs: Array = _own(p, Facility.Kind.REFINERY)
	var oil_here: bool = _opt(p, "oil_rig", econ._has_free_deposit(p, ["oil"]) or not rigs.is_empty())
	if not oil_here:
		_skip(out, "oil_rig", Loc.t("Нефтевышка: пропуск"), Loc.t("На вашей земле нет нефти."), "icon_oil_rig")
	else:
		var rig_ok: bool = false
		var rig_placed: bool = false
		for f5: Facility in rigs:
			rig_ok = rig_ok or (_works(f5) and not f5.deposit.is_empty())
			rig_placed = rig_placed or not f5.deposit.is_empty()
		_goal(out, p, "oil_rig", Loc.t("Нефтевышка: нефть"), Loc.t("Нефть — сырьё для НПЗ. Вышка на чёрном значке залежи даёт +%d нефти в минуту.") % (Economy.RIG_OIL * 6), 
			"icon_oil_rig", "oil_rig", rig_ok, Loc.t("Нефтевышка работает"), rig_placed)
	if not _opt(p, "refinery", oil_here or not refs.is_empty()):
		_skip(out, "refinery", Loc.t("НПЗ: пропуск"), Loc.t("Нет нефти — НПЗ не нужен."), "icon_refinery")
	else:
		var ref_ok: bool = false
		for f6: Facility in refs:
			ref_ok = ref_ok or _works(f6)
		ref_ok = ref_ok and (p.oil > 0 or _total(p, "res_in", "fuel:refinery") > 0)
		_goal(out, p, "refinery", Loc.t("НПЗ: топливо и деньги"), Loc.t("Нефть → топливо (+%d в минуту на полной загрузке): излишки продаются сами, запас заправляет авиацию. На постройку нужна нефть %d.") % [int(60.0 / Military.FUEL_DT), int(Economy.BUILD_COST[Facility.Kind.REFINERY]["oil"])], 
			"icon_refinery", "refinery", ref_ok, Loc.t("НПЗ даёт топливо"), not refs.is_empty())
	var sc: Array = econ.scarce_of(p)
	var sc_txt: String = ""
	if not sc.is_empty():
		var names: PackedStringArray = PackedStringArray()
		for r2: String in sc:
			names.append(res_name(r2))
		sc_txt = Loc.t(" В вашем регионе нет: %s — это придётся покупать.") % ", ".join(names)
	if _coast_ok(p) or claimed.has("port"):
		_goal(out, p, "port", Loc.t("Порт: экспорт и импорт"), Loc.t("Порт сам вывозит излишки за рубеж, привозит нехватку и даёт +склад.%s") % [sc_txt], 
			"icon_port", "port", econ.ports.has_port(p), Loc.t("Порт построен"))
	else:
		_goal(out, p, "trade", Loc.t("Торговля с соседом"), Loc.t("Выхода к морю нет: заключите торговое соглашение — излишки уйдут соседу сами, нехватку можно купить.%s") % [sc_txt], 
			"icon_trade", "dip_best" if best_neighbour(p) >= 0 else "trade", _has_trade(p), Loc.t("Торговля налажена"))
	_goal(out, p, "town", Loc.t("Новый город"), Loc.t("Город (%d) расширяет землю — новые залежи и лес, +%d денег в минуту. Ставьте рядом со значком руды.") % [Military.COST_TOWN, Military.INCOME_TOWN * 6], 
		"icon_city", "town", p.city_ids.size() >= 2, Loc.t("Основан новый город"))
	var has_bar: bool = not _own(p, Facility.Kind.BARRACKS).is_empty()
	var has_ad: bool = _any(p, AD_KINDS)
	var ad_key: String = "ad_spaag" if p.money >= Military.cost_of(Facility.Kind.AD_SPAAG) + 300 else "ad_mfg"
	_goal(out, p, "defence", Loc.t("Защита: казармы и ПВО"), Loc.t("Казармы — армия до 12 бойцов, ПВО сбивает вражеские дроны. Боты начинают войну по выбору не раньше 10–12 минуты."), 
		"icon_barracks" if not has_bar else Military.icon_of(int(KEY_KIND[ad_key])), "barracks" if not has_bar else ad_key, has_bar and has_ad, Loc.t("Оборона готова"))
	_mid_goals(out, p)
	for g: Dictionary in out:
		if not bool(g["done"]):
			g["current"] = true
			break
	return out



func update(_dt: float) -> void :
	if gw.net_driven:
		return
	var now: int = Time.get_ticks_msec() if GameWorld.lab_tick < 0 else int(gw.game_time * 1000.0)
	if now - _check_ms < 1000:
		return
	_check_ms = now
	var p: Country = gw.player
	if p == null or p.eliminated or p.capital_id < 0:
		return
	_cache.erase("goals%d" % p.id)
	var paid: bool = false
	for g: Dictionary in goals(p):
		var id: String = g["id"]
		if bool(g["ok"]) and not claimed.has(id):
			claimed[id] = true
			var rw: int = int(g["reward"])
			if rw > 0:
				p.money += rw
				gw.econ.stat_add(p, "income", "plan", rw)
				gw.message.emit(Loc.msg(Loc.mk("План: %s +%d", [String(g["msg"]), rw])))
			paid = true
	if paid:
		_cache.clear()






func _mid_goals(out: Array, p: Country) -> void :
	var mil: Military = gw.mil
	var econ: Economy = gw.econ
	var trench: int = 0
	for f: Facility in mil.facilities:
		if f.country_id == p.id and (f.kind == Facility.Kind.TRENCH_H or f.kind == Facility.Kind.TRENCH_V) and mil.alive(f):
			trench += f.cells.size()
	var dug: bool = not _own(p, Facility.Kind.DUGOUT).is_empty()
	_goal(out, p, "fort", Loc.t("Окоп или блиндаж"), Loc.t("Ведите пальцем окоп у границы с соседом: пехота в укрытии получает втрое меньше урона, блиндаж ещё и лечит. Боты нападают с 10–12 минуты."), 
		"icon_trench", "trench" if trench < 8 else "dugout", trench >= 8 or dug, Loc.t("Рубеж обороны готов"))
	var lv2: bool = false
	var lv3: bool = false
	for f2: Facility in mil.facilities:
		if f2.country_id == p.id and Economy.UPG_RES.has(f2.kind) and mil.alive(f2):
			lv2 = lv2 or f2.level >= 2
			lv3 = lv3 or f2.level >= 3
	_goal(out, p, "upgrade", Loc.t("Улучшение: уровень 2"), Loc.t("Улучшенный рудник, колхоз или завод даёт выпуск ×%.1f без новой энергии и места. Тап — к лучшему кандидату, кнопка «УР» в карточке.") % float(Economy.LEVEL_MUL[2]), 
		"icon_upgrade", "upg_best", lv2, Loc.t("Первое улучшение"))
	var sources: int = _own(p, Facility.Kind.POWER_PLANT).size() + _own(p, Facility.Kind.SOLAR_FARM).size()
	var free: int = p.power_cap - p.power_use

	_goal(out, p, "grid", Loc.t("Энергия: третья станция"), Loc.t("Запас сети %d. Удар по ТЭЦ не должен гасить заводы, а новым заводам нужна энергия: ТЭЦ +%d или солнечная +%d.") % [free, Military.PLANT_CAP, Military.SOLAR_FARM_CAP], 
		"icon_power", _power_key(p), sources >= 3, Loc.t("Сеть с запасом"))
	_goal(out, p, "town2", Loc.t("Третий город"), Loc.t("+%d очков, +%d денег в минуту, новая земля и залежи. Ставьте у свободной залежи, пока её не занял сосед.") % [Match.city_points(City.Kind.TOWN), Military.INCOME_TOWN * 6], 
		"icon_city", "town", p.city_ids.size() >= 3, Loc.t("Основан третий город"))
	var ent: int = _ent_count(p)
	_goal(out, p, "ent6", Loc.t("Предприятия: %d/6") % mini(ent, 6), Loc.t("Каждый колхоз, завод товаров, рудник или лесопилка — +25 очков и постоянный доход. Деньги на счету очков не дают."), 
		_ent_icon(p), _ent_key(p), ent >= 6, Loc.t("Шесть предприятий"))
	var nb: int = best_neighbour(p)
	var treaties: int = 0
	for o: Country in gw.countries:
		if o.id != p.id and gw.diplo.has_treaty(p.id, o.id, "trade"):
			treaties += 1
	if not _opt(p, "treaty", nb >= 0 or treaties > 0):
		_skip(out, "treaty", Loc.t("Договор: пропуск"), Loc.t("Сейчас договор подписать не с кем."), "icon_treaty_trade")
	else:
		_goal(out, p, "treaty", Loc.t("Торговый договор"), Loc.t("Договор с соседом: излишки уходят ему сами (доход = очки), нехватку он продаёт дешевле, отношения растут — меньше ультиматумов."), 
			"icon_treaty_trade", "dip_best", treaties >= 1, Loc.t("Договор подписан"))
	var ramp: bool = false
	var ports: Array = _own(p, Facility.Kind.DRONE_PORT)
	for port: Facility in ports:
		for m: Facility in port.modules:
			if m.kind == Facility.Kind.DP_RAMP and mil.alive(m):
				ramp = true
	var dfac: bool = not _own(p, Facility.Kind.DRONE_FACTORY).is_empty()
	var dkey: String = "factory" if not dfac else ("droneport" if ports.is_empty() else "dp_ramp")
	var dicon: String = "icon_ramp" if dkey == "dp_ramp" else ("icon_droneport" if dkey == "droneport" else Military.icon_of(Facility.Kind.DRONE_FACTORY))
	_goal(out, p, "dport", Loc.t("Дроны: завод, дронопорт, рампа"), Loc.t("Ударные дроны и разведдрон: завод дронов их делает, дронопорт хранит, с рампы они взлетают."), 
		dicon, dkey, ramp and dfac, Loc.t("Дроны готовы к вылету"))
	var nt: Facility = net_target(p)
	var netted: bool = false
	var concd: bool = false
	if gw.protect != null:
		for f3: Facility in mil.facilities:
			if f3.country_id == p.id and (f3.kind == Facility.Kind.POWER_PLANT or f3.kind == Facility.Kind.REFINERY) and mil.alive(f3):
				var pi: Dictionary = gw.protect.info(f3)

				if String(pi.get("net_state", "none")) == "ok" or (String(pi.get("net_state", "none")) == "building" and int(pi.get("net_lvl", 0)) >= 2):
					netted = true
				if String(pi.get("conc_state", "none")) == "ok":
					concd = true
	if not _opt(p, "net", nt != null or netted):
		_skip(out, "net", Loc.t("Сетка: пропуск"), Loc.t("Нет ТЭЦ или НПЗ, которые нужно прикрыть."), "res_defense")
	else:
		_goal(out, p, "net", Loc.t("Сетка над ТЭЦ"), Loc.t("ТЭЦ и НПЗ — первые цели вражеских дронов. Антидроновая сетка ловит 35–65 % ударных дронов (не ракеты)."), 
			"res_defense", "net_best", netted, Loc.t("Сетка натянута"))
	_goal(out, p, "lvl3", Loc.t("Улучшение: уровень 3"), Loc.t("Уровень 3 — выпуск ×%.1f: больше дохода и очков с того же места. Тап — к объекту 2-го уровня, кнопка «УР».") % float(Economy.LEVEL_MUL[3]), 
		"icon_upgrade", "upg_best", lv3, Loc.t("Первый объект 3-го уровня"))
	_goal(out, p, "town3", Loc.t("Четвёртый город"), Loc.t("Ещё +%d очков и доход. Колония за морем тоже считается: порт → «КОЛОНИЯ».") % Match.city_points(City.Kind.TOWN), 
		"icon_city", "town", p.city_ids.size() >= 4, Loc.t("Основан четвёртый город"))
	_goal(out, p, "army2", Loc.t("Вторая армия"), Loc.t("Две полные казармы держат рубеж, пока вы отвечаете на удар. Режим «ОБОРОНА» — армия сама встаёт у городов."), 
		"icon_barracks", "barracks", _own(p, Facility.Kind.BARRACKS).size() >= 2, Loc.t("Две армии"))
	var ti_mine: Facility = null
	for f4: Facility in _own(p, Facility.Kind.MINE):
		if String(f4.deposit.get("res", "")) == "titanium" and (ti_mine == null or f4.level < ti_mine.level):
			ti_mine = f4

	var ti_key: String = "trade"
	var ti_how: String = Loc.t("покупка на рынке («КУПИТЬ НЕХВАТКУ»)")
	if ti_mine != null and _upg_ok(ti_mine) and p.has_res(econ.upgrade_cost(ti_mine)):
		ti_key = "upg_best"
		ti_how = Loc.t("улучшите свой титановый рудник")
	elif ti_mine == null and econ._has_free_deposit(p, ["titanium"]):
		ti_key = "mine"
		ti_how = Loc.t("рудник на голубой залежи")
	elif ti_mine != null:
		ti_how = Loc.t("рудник работает; быстрее — покупка")
	_goal(out, p, "titanium", Loc.t("Запас титана: 40"), Loc.t("Титан нужен ракетам, танкам и самолётам (у вас %d): %s.") % [p.titanium, ti_how], 
		"res_titanium", ti_key, p.titanium >= 40, Loc.t("Запас титана"))
	if not _opt(p, "treaty2", treaties >= 1 and (nb >= 0 or treaties >= 2)):
		_skip(out, "treaty2", Loc.t("Второй договор: пропуск"), Loc.t("Больше подписать не с кем."), "icon_treaty_trade")
	else:
		_goal(out, p, "treaty2", Loc.t("Второй договор"), Loc.t("Ещё один покупатель для излишков: торговля идёт в доход, доход — в очки."), 
			"icon_treaty_trade", "dip_best", treaties >= 2, Loc.t("Два торговых договора"))
	_goal(out, p, "conc", Loc.t("Бетон над ТЭЦ"), Loc.t("Бетон гасит крылатые и баллистические ракеты (сетка — нет). Потерянная ТЭЦ останавливает все заводы и доход."), 
		"res_defense", "net_best", concd, Loc.t("Бетон залит"))
	_goal(out, p, "town4", Loc.t("Пятый город"), Loc.t("Пять городов — заметный отрыв по очкам (+%d за город) и доходу.") % Match.city_points(City.Kind.TOWN), 
		"icon_city", "town", p.city_ids.size() >= 5, Loc.t("Основан пятый город"))
	_goal(out, p, "ent10", Loc.t("Предприятия: %d/10") % mini(ent, 10), Loc.t("Десять предприятий — +250 очков и доход, который сам растит счёт."), 
		_ent_icon(p), _ent_key(p), ent >= 10, Loc.t("Десять предприятий"))



func _upg_ok(f: Facility) -> bool:
	return gw.econ.can_upgrade(f) and (f.deposit.is_empty() or int(f.deposit.get("left", 0)) >= 200)


func _ent_count(p: Country) -> int:
	var n: int = 0
	for f: Facility in gw.mil.facilities:
		if f.country_id == p.id and Economy.is_enterprise(f.kind) and gw.mil.alive(f):
			n += 1
	return n




func _ent_key(p: Country) -> String:
	if gw.econ._has_free_deposit(p, Economy.ORE_TYPES) and p.power_cap - p.power_use >= 1:
		return "mine"
	if gw.econ._has_free_deposit(p, ["oil"]):
		return "oil_rig"
	if p.power_cap - p.power_use >= 1:
		return "civ"
	return "farm"


func _ent_icon(p: Country) -> String:
	return Military.icon_of(int(KEY_KIND[_ent_key(p)]))



func best_neighbour(p: Country) -> int:
	if p == null or p.capital_id < 0 or gw.diplo == null:
		return -1
	var dp: Diplomacy = gw.diplo
	var best: int = -1
	var bs: float = - INF
	for o: Country in gw.countries:
		if o.id == p.id or o.eliminated or o.capital_id < 0 or dp.at_war(p.id, o.id) or dp.embargo_between(p.id, o.id) or dp.has_treaty(p.id, o.id, "trade"):
			continue
		var sc: float = float(dp.relation(o.id, p.id)) - dp._dist_caps(p, o) / 100.0
		if dp.ai_treaty_reason(o.id, p.id, "trade") == "":
			sc += 1000.0
		if dp.neighbours(p.id, o.id):
			sc += 50.0
		if sc > bs:
			bs = sc
			best = o.id
	return best





func upgrade_target(p: Country) -> Facility:
	if p == null:
		return null
	var econ: Economy = gw.econ
	var gid: String = _cur_id(p)
	var best: Facility = null
	var bs: float = - INF
	for pass_i in 2:
		for f: Facility in gw.mil.facilities:
			if f.country_id != p.id or not _upg_ok(f):
				continue
			if pass_i == 0 and gid == "titanium" and String(f.deposit.get("res", "")) != "titanium":
				continue
			var r: String = econ.out_res(f)
			var sc: float = float(econ.market_price(r) if r != "" else 20) / float(f.level)
			var uc: Dictionary = econ.upgrade_cost(f)
			if not uc.is_empty() and p.has_res(uc):
				sc += 1000.0
			if gid == "lvl3" and f.level >= 2:
				sc += 3000.0
			if f.kind == Facility.Kind.FARM or f.kind == Facility.Kind.CIV_FACTORY:
				sc -= 300.0
			if sc > bs:
				bs = sc
				best = f
		if best != null:
			break
	return best




func net_target(p: Country) -> Facility:
	if p == null or gw.protect == null:
		return null
	var best: Facility = null
	if _cur_id(p) == "conc":
		for fc: Facility in gw.mil.facilities:
			if fc.country_id != p.id or not gw.mil.alive(fc) or not gw.protect.eligible(fc):
				continue
			if fc.kind != Facility.Kind.POWER_PLANT and fc.kind != Facility.Kind.REFINERY:
				continue
			if String(gw.protect.info(fc).get("conc_state", "none")) == "ok":
				continue
			if best == null or (fc.kind == Facility.Kind.POWER_PLANT and best.kind != Facility.Kind.POWER_PLANT):
				best = fc
		if best != null:
			return best
	for f: Facility in gw.mil.facilities:
		if f.country_id != p.id or not gw.mil.alive(f) or not gw.protect.eligible(f):
			continue
		if f.kind != Facility.Kind.POWER_PLANT and f.kind != Facility.Kind.REFINERY:
			continue
		if int(gw.protect.info(f).get("net_lvl", 0)) > 0:
			continue
		if best == null or (f.kind == Facility.Kind.POWER_PLANT and best.kind != Facility.Kind.POWER_PLANT):
			best = f
	return best



func ramp_port(p: Country) -> Facility:
	if p == null:
		return null
	var first: Facility = null
	for port: Facility in _own(p, Facility.Kind.DRONE_PORT):
		if first == null:
			first = port
		var has: bool = false
		for m: Facility in port.modules:
			if m.kind == Facility.Kind.DP_RAMP and gw.mil.alive(m):
				has = true
		if not has:
			return port
	return first






func best_site(p: Country, key: String) -> Vector2:
	if p == null or p.capital_id < 0:
		return Vector2.INF
	var c: Vector2i = _site_cell(p, key)
	return Vector2.INF if c.x < 0 else Vector2(c * GameWorld.CELL) + Vector2(2, 2)


func _site_cell(p: Country, key: String) -> Vector2i:
	match key:
		"mine":
			if _cur_id(p) == "titanium":
				var ti: Vector2i = _deposit_site(p, Facility.Kind.MINE, ["titanium"])
				if ti.x >= 0:
					return ti
			return _deposit_site(p, Facility.Kind.MINE, Economy.ORE_TYPES)
		"trench":
			return _trench_site(p)
		"oil_rig":
			return _deposit_site(p, Facility.Kind.OIL_RIG, ["oil"])
		"sawmill":
			return _sawmill_site(p)
		"port":
			return gw.econ.ports.find_site(p)
		"town":
			return _town_site(p)
	if not KEY_KIND.has(key):
		return Vector2i(-1, -1)
	var kind: int = KEY_KIND[key]
	if SMART_KINDS.has(kind):
		var sc: Vector2i = smart_cell(p, kind)
		if sc.x >= 0:
			return sc
	if kind == Facility.Kind.TEL or kind == Facility.Kind.AIRFIELD or kind == Facility.Kind.DUGOUT or kind == Facility.Kind.REFINERY or Defense.is_ad(kind) or kind == Facility.Kind.AD_RADAR or kind == Facility.Kind.AD_EW:
		return _ring_site(p, kind, 2, 50)
	return _ring_site(p, kind, 4, 60)



const SMART_KINDS: Array = [Facility.Kind.CIV_FACTORY, Facility.Kind.FARM, Facility.Kind.POWER_PLANT, Facility.Kind.SOLAR_FARM, 
	Facility.Kind.REFINERY, Facility.Kind.DRONE_FACTORY, Facility.Kind.MISSILE_FACTORY, Facility.Kind.BARRACKS]
const SMART_CHECK: int = 14












func smart_cell(p: Country, kind: int) -> Vector2i:
	var job: Dictionary = _sc_begin(p, kind)
	if job.is_empty():
		return Vector2i(-1, -1)
	_sc_run(job, 1 << 30)
	return _sc_end(job)






const SC_STEP: int = 900
var _sc_jobs: Dictionary = {}


func smart_cell_ai(p: Country, kind: int) -> Vector2i:
	var job: Dictionary = _sc_jobs.get(p.id, {})
	if not job.is_empty() and (int(job["kind"]) != kind or gw.game_time - float(job["t0"]) > 30.0):
		job = {}
	if job.is_empty():
		job = _sc_begin(p, kind)
		if job.is_empty():
			_sc_jobs.erase(p.id)
			return Vector2i(-1, -1)
		_sc_jobs[p.id] = job
	elif float(job["last"]) == gw.game_time:
		return Vector2i(-1, -1)
	job["last"] = gw.game_time
	if not _sc_run(job, SC_STEP):
		return Vector2i(-1, -1)
	_sc_jobs.erase(p.id)
	return _sc_end(job)


func smart_pending(p: Country, kind: int) -> bool:
	return _sc_jobs.has(p.id) and int(_sc_jobs[p.id]["kind"]) == kind



func _sc_begin(p: Country, kind: int) -> Dictionary:
	if p == null or p.capital_id < 0 or p.city_ids.is_empty():
		return {}
	var d: WorldData = gw.data
	var mil: Military = gw.mil
	var half: int = maxi(Military.size_of(kind).x, Military.size_of(kind).y) / 2 + 1
	var cap: City = _cap_city(p)

	var rigs: Array[Vector2] = []
	if kind == Facility.Kind.REFINERY:
		for f: Facility in _own(p, Facility.Kind.OIL_RIG):
			rigs.append(Vector2(f.cell + f.size / 2))
		if rigs.is_empty():
			for dp: Dictionary in gw.econ.deposits:
				var dc: Vector2i = dp["cell"]
				if String(dp.get("res", "")) == "oil" and dp["mine"] == null and d.get_owner_id(dc.x, dc.y) == p.id:
					rigs.append(Vector2(dc))
	var load_c: = Vector2(cap.center)
	if kind == Facility.Kind.POWER_PLANT or kind == Facility.Kind.SOLAR_FARM:
		var acc: = Vector2(cap.center) * 3.0
		var wsum: float = 3.0
		for f2: Facility in mil.facilities:
			if f2.country_id == p.id and Military.uses_power(f2.kind) and mil.alive(f2):
				acc += Vector2(f2.cell + f2.size / 2)
				wsum += 1.0
		for cid in p.city_ids:
			if cid != p.capital_id:
				acc += Vector2(gw.cities[cid].center)
				wsum += 1.0
		load_c = acc / wsum
	var away: = Vector2.ZERO
	if kind == Facility.Kind.DRONE_FACTORY or kind == Facility.Kind.MISSILE_FACTORY:
		var bd: float = INF
		for o: Country in gw.countries:
			if o.id != p.id and not o.eliminated and o.capital_id >= 0:
				var oc: = Vector2(gw.cities[o.capital_id].center)
				var dd: float = oc.distance_to(Vector2(cap.center))
				if dd < bd and dd > 1.0:
					bd = dd
					away = (Vector2(cap.center) - oc).normalized()
	var scc: Array = []
	for cid0 in p.city_ids:
		var c0: City = gw.cities[cid0]
		scc.append([Vector2(c0.center), float(c0.radius + half), float(int(CityGen.params(c0.kind)["step"]) + 1)])
	var centres: Array = []
	for cid in p.city_ids:
		centres.append([gw.cities[cid].center, gw.cities[cid]])
	for rp: Vector2 in rigs:
		centres.append([Vector2i(rp), null])
	var cells0: Array[Vector2i] = []
	return {"p": p, "kind": kind, "half": half, "cap": cap, "rigs": rigs, "load_c": load_c, "away": away, "scc": scc, 
		"capg": float(cap.radius + half + int(CityGen.params(cap.kind)["step"]) + 1), "centres": centres, "ci": 0, "r": -1, 
		"keys": PackedVector2Array(), "cells": cells0, "seen": {}, "t0": gw.game_time, "last": -1.0}



func _sc_run(job: Dictionary, budget: int) -> bool:
	var d: WorldData = gw.data
	var p: Country = job["p"]
	var kind: int = job["kind"]
	var half: int = job["half"]
	var cap: City = job["cap"]
	var rigs: Array[Vector2] = job["rigs"]
	var load_c: Vector2 = job["load_c"]
	var away: Vector2 = job["away"]
	var keys: PackedVector2Array = job["keys"]
	var cells: Array[Vector2i] = job["cells"]
	var seen: Dictionary = job["seen"]
	var centres: Array = job["centres"]
	_sc_cities = job["scc"]
	_sc_cap_gap = float(job["capg"])
	var ci: int = job["ci"]
	var r: int = job["r"]
	var used: int = 0
	while ci < centres.size():
		var e: Array = centres[ci]
		var ctr: Vector2i = e[0]
		var city: City = e[1]
		var r_lo: int = (city.radius + half + 1) if city != null else half + 3
		var r_hi: int = r_lo + (36 if city != null else 20)
		if r < 0:
			r = r_lo
		while r < r_hi:
			if used >= budget:
				job["ci"] = ci
				job["r"] = r
				job["keys"] = keys
				return false
			var n_ang: int = clampi(roundi(TAU * float(r) / 5.0), 16, 64)
			used += n_ang
			for k in n_ang:
				var a: float = TAU * float(k) / float(n_ang)
				var q: Vector2i = ctr + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
				if seen.has(q) or not d.inside(q.x, q.y) or d.get_owner_id(q.x, q.y) != p.id or Biome.is_water(d.get_biome(q.x, q.y)):
					continue
				seen[q] = true
				var sc: float = _site_score(p, kind, q, half, cap, rigs, load_c, away)
				if sc > - INF:
					keys.append(Vector2(sc, float(cells.size())))
					cells.append(q)
			r += 3
		ci += 1
		r = -1
	job["ci"] = ci
	job["r"] = r
	job["keys"] = keys
	return true



func _sc_end(job: Dictionary) -> Vector2i:
	var p: Country = job["p"]
	var kind: int = job["kind"]
	var half: int = job["half"]
	var keys: PackedVector2Array = job["keys"]
	var cells: Array[Vector2i] = job["cells"]
	var mil: Military = gw.mil
	keys.sort()
	var best: = Vector2i(-1, -1)
	var bs: float = - INF
	var checked: int = 0
	var tried: int = 0
	for i in range(keys.size() - 1, -1, -1):
		if checked >= SMART_CHECK or tried >= SMART_CHECK * 4:
			break
		tried += 1
		var q2: Vector2i = cells[int(keys[i].y)]
		if mil.check_place(kind, Military.nw_for(kind, q2), p, null, false) != "":
			continue
		checked += 1
		var s2: float = keys[i].x + _road_bonus(q2, half) - (30.0 if not gw.econ.deposit_near(q2, half + 2).is_empty() else 0.0)
		if s2 > bs:
			bs = s2
			best = q2
	return best


var _sc_cities: Array = []
var _sc_cap_gap: float = 0.0



func _site_score(p: Country, kind: int, q: Vector2i, half: int, cap: City, rigs: Array[Vector2], load_c: Vector2, away: Vector2) -> float:
	var qv: = Vector2(q)
	var sc: float = 0.0

	var near_gap: float = INF
	for e: Array in _sc_cities:
		var gap: float = qv.distance_to(e[0]) - float(e[1])
		if gap < float(e[2]):
			sc -= (float(e[2]) - gap) * 14.0
		near_gap = minf(near_gap, gap - float(e[2]))
	var cap_gap: float = qv.distance_to(Vector2(cap.center)) - _sc_cap_gap
	match kind:
		Facility.Kind.REFINERY:
			var dr: float = INF
			for rp: Vector2 in rigs:
				dr = minf(dr, qv.distance_to(rp))
			sc -= (dr * 2.5) if dr < INF else maxf(0.0, cap_gap) * 1.5
			sc -= maxf(0.0, 6.0 - near_gap) * 4.0
		Facility.Kind.CIV_FACTORY:
			sc -= maxf(0.0, cap_gap) * 2.0 + maxf(0.0, near_gap) * 1.5
		Facility.Kind.POWER_PLANT, Facility.Kind.SOLAR_FARM:
			sc -= qv.distance_to(load_c) * 1.6 + maxf(0.0, near_gap) * 0.8
		Facility.Kind.FARM:
			sc -= maxf(0.0, near_gap) * 1.2
			var b: int = gw.data.get_biome(q.x, q.y)
			if b == Biome.FOREST or b == Biome.PINE:
				sc -= 12.0
		Facility.Kind.DRONE_FACTORY, Facility.Kind.MISSILE_FACTORY:
			sc -= maxf(0.0, cap_gap) * 1.6
			if away != Vector2.ZERO:
				sc += (qv - Vector2(cap.center)).normalized().dot(away) * 18.0
		_:
			sc -= maxf(0.0, near_gap) * 1.5
	return sc



func _road_bonus(q: Vector2i, half: int) -> float:
	var d: WorldData = gw.data
	var best: float = 0.0
	for r in [half + 3, half + 6]:
		for dy in range( - r, r + 1, 2):
			for dx in range( - r, r + 1, 2):
				if maxi(absi(dx), absi(dy)) < half:
					continue
				var x: int = q.x + dx
				var y: int = q.y + dy
				if d.inside(x, y) and d.has_flag(x, y, WorldData.F_ROAD) and not d.has_flag(x, y, WorldData.F_CITY):
					return 25.0 if r == half + 3 else 10.0
		best = 0.0
	return best



func _ring_site(p: Country, kind: int, r0: int, r1: int) -> Vector2i:
	var cap: City = _cap_city(p)
	if cap == null:
		return Vector2i(-1, -1)
	var a0: int = (cap.center.x * 7 + cap.center.y * 13) % 360
	for r in range(cap.radius + r0, cap.radius + r1, 2):
		for k in range(0, 360, 15):
			var a: float = deg_to_rad(float(a0 + k))
			var q: Vector2i = cap.center + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			if gw.data.inside(q.x, q.y) and gw.data.get_owner_id(q.x, q.y) == p.id and gw.mil.check_place(kind, Military.nw_for(kind, q), p, null, false) == "":
				return q
	return Vector2i(-1, -1)



func _deposit_site(p: Country, kind: int, types: Array) -> Vector2i:
	var econ: Economy = gw.econ
	var mined: Dictionary = {}
	for f: Facility in _own(p, kind):
		mined[String(f.deposit.get("res", ""))] = true
	var cap: City = _cap_city(p)
	var best: = Vector2i(-1, -1)
	var bs: float = - INF
	for dp: Dictionary in econ.deposits:
		if dp["mine"] != null or int(dp.get("left", 0)) <= 0 or not types.has(String(dp.get("res", ""))):
			continue
		var cell: Vector2i = dp["cell"]
		if gw.data.get_owner_id(cell.x, cell.y) != p.id:
			continue
		var res: String = String(dp["res"])
		var sc: float = float(econ.need(p, res) + 1) * float(econ.market_price(res)) + (2000.0 if not mined.has(res) else 0.0) + (500.0 if res == "metal" else 0.0)\
		+ float(dp.get("left", 0)) * 0.2 - (cell.distance_to(cap.center) if cap != null else 0.0)
		if sc > bs and gw.mil.check_place(kind, Military.nw_for(kind, cell), p, null, false) == "":
			bs = sc
			best = cell
	return best




func _trench_site(p: Country) -> Vector2i:
	var cap: City = _cap_city(p)
	if cap == null:
		return Vector2i(-1, -1)
	var foe: City = null
	var fd: float = INF
	for c: City in gw.cities:
		if c.country_id == p.id or c.country_id <= 0:
			continue
		var d: float = Vector2(c.center).distance_to(Vector2(cap.center))
		if d < fd:
			fd = d
			foe = c
	var dirs: Array = []
	if foe != null:
		dirs.append((Vector2(foe.center) - Vector2(cap.center)).normalized())
	for a in range(0, 360, 45):
		dirs.append(Vector2.from_angle(deg_to_rad(float(a))))
	var d0: WorldData = gw.data
	for dv: Vector2 in dirs:
		var last: = Vector2i(-1, -1)
		for s in range(cap.radius + 4, cap.radius + 260, 3):
			var q: Vector2i = cap.center + Vector2i(roundi(dv.x * s), roundi(dv.y * s))
			if not d0.inside(q.x, q.y):
				break
			if d0.get_owner_id(q.x, q.y) != p.id:
				break
			last = q
		if last.x < 0:
			continue
		var back: Vector2i = last - Vector2i(roundi(dv.x * 10.0), roundi(dv.y * 10.0))
		for r in [0, 4, 8, 12]:
			for a2 in range(0, 360, 45):
				var q2: Vector2i = back + Vector2i(roundi(cos(deg_to_rad(a2)) * r), roundi(sin(deg_to_rad(a2)) * r))
				if d0.inside(q2.x, q2.y) and d0.get_owner_id(q2.x, q2.y) == p.id and gw.mil.check_place(Facility.Kind.TRENCH_H, Military.nw_for(Facility.Kind.TRENCH_H, q2), p, null, false) == "":
					return q2
				if r == 0:
					break
	return Vector2i(-1, -1)



func _sawmill_site(p: Country) -> Vector2i:
	var econ: Economy = gw.econ
	var bp: = Vector2i(-1, -1)
	var bt: int = Economy.SAW_MIN_TREES - 1
	for cid in p.city_ids:
		var city: City = gw.cities[cid]
		for r in range(city.radius + 6, city.radius + 46, 6):
			for a in range(0, 360, 30):
				var q: Vector2i = city.center + Vector2i(roundi(cos(deg_to_rad(a)) * r), roundi(sin(deg_to_rad(a)) * r))
				if not gw.data.inside(q.x, q.y) or gw.data.get_owner_id(q.x, q.y) != p.id:
					continue
				var t: int = econ.count_trees(q, Economy.SAW_R, 2)
				if t > bt and gw.mil.check_place(Facility.Kind.SAWMILL, Military.nw_for(Facility.Kind.SAWMILL, q), p, null, false) == "":
					bt = t
					bp = q
	return bp





func _near_city_of(p: Country, cell: Vector2i, pad: int) -> bool:
	for cid in p.city_ids:
		var city: City = gw.cities[cid]
		if maxi(absi(city.center.x - cell.x), absi(city.center.y - cell.y)) <= city.claim_max + pad:
			return true
	return false


func _town_site(p: Country) -> Vector2i:
	var d: WorldData = gw.data
	var cands: Array = []
	for dp: Dictionary in gw.econ.deposits:
		if dp["mine"] != null or int(dp.get("left", 0)) <= 0:
			continue
		var dc: Vector2i = dp["cell"]
		if d.get_owner_id(dc.x, dc.y) != 0 or not _near_city_of(p, dc, GameWorld.TOWN_REACH + 16):
			continue
		for a in range(0, 360, 45):
			var q: Vector2i = dc + Vector2i(roundi(cos(deg_to_rad(a)) * 28.0), roundi(sin(deg_to_rad(a)) * 28.0))
			cands.append([1000.0 + float(gw.econ.market_price(String(dp.get("res", "metal")))), q])
	for cid in p.city_ids:
		var city: City = gw.cities[cid]
		for r in range(city.claim_max + 18, city.claim_max + 70, 12):
			for a2 in range(0, 360, 30):
				var q2: Vector2i = city.center + Vector2i(roundi(cos(deg_to_rad(a2)) * r), roundi(sin(deg_to_rad(a2)) * r))
				cands.append([500.0 - float(r), q2])
	var ok: Array = []
	for cd: Array in cands:
		var q3: Vector2i = cd[1]
		if not d.inside(q3.x, q3.y) or not Biome.is_natural_land(d.get_biome(q3.x, q3.y)):
			continue
		var o: int = d.get_owner_id(q3.x, q3.y)
		if o != 0 and o != p.id:
			continue
		var near: bool = false
		for oc: City in gw.cities:
			if absi(oc.center.x - q3.x) + absi(oc.center.y - q3.y) < GameWorld.MIN_CITY_DIST:
				near = true
				break
		if not near:
			ok.append(cd)
	ok.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var tries: int = 0
	for cd2: Array in ok:
		var q4: Vector2i = cd2[1]
		tries += 1
		if tries > 40:
			break
		if d.get_owner_id(q4.x, q4.y) != p.id and not gw._near_own_land(q4, GameWorld.TOWN_REACH):
			continue
		if not GameWorld.BORDER_GAP.site_ok(gw, q4, p.id, 21) or not GameWorld.BORDER_GAP.own_ok(gw, q4, p.id, 21):
			continue
		if bool(gw.can_found_city(q4, City.Kind.TOWN)["ok"]) and (gw.naval == null or not gw.naval._covers_deposit(q4)):
			return q4
	return Vector2i(-1, -1)









func flows(p: Country) -> Dictionary:
	if p == null:
		return {}
	return _cached("flows%d" % p.id, CACHE_MS, func() -> Dictionary: return _flows(p))


func _flows(p: Country) -> Dictionary:
	var econ: Economy = gw.econ
	var st: Dictionary = econ.stats(p)
	var out: Dictionary = {}

	var inc: Array = []
	var spd: Array = []
	var net: int = 0
	for pair: Array in [["income", inc, 1], ["spend", spd, -1]]:
		var d: Dictionary = st.get(pair[0], {})
		for k: String in d:
			var v: int = int(d[k])
			if v <= 0:
				continue
			(pair[1] as Array).append({"name": String(Economy.STAT_NAMES.get(k, "План развития" if k == "plan" else k)), "key": k, "per_min": v})
			net += v * int(pair[2])
	var regular: int = net
	for it: Dictionary in inc:
		if ONE_OFF_MONEY.has(String(it["key"])):
			regular -= int(it["per_min"])
	for it2: Dictionary in spd:
		if ONE_OFF_MONEY.has(String(it2["key"])):
			regular += int(it2["per_min"])
	inc.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a["per_min"]) > int(b["per_min"]))
	spd.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a["per_min"]) > int(b["per_min"]))
	out["money"] = {"net_per_min": net, "regular_per_min": regular, "income": inc, "spend": spd, "stock": p.money}

	var off: int = 0
	for f: Facility in gw.mil.facilities:
		if f.country_id == p.id and Military.uses_power(f.kind) and gw.mil.alive(f) and not f.halted and not gw.mil.has_power(f):
			off += 1
	var dark: int = 0
	for cid in p.city_ids:
		if not gw.cities[cid].powered:
			dark += 1
	var free: int = p.power_cap - p.power_use
	var pst: String = "ok"
	var ptx: String = Loc.t("Сеть %d/%d: свободно %d энергии (заводу, руднику, НПЗ нужно по 1).") % [p.power_use, p.power_cap, free]
	if off > 0 or dark > 0 or free < 0:
		pst = "bad"
		var lost: PackedStringArray = PackedStringArray()
		if off > 0:
			lost.append(Loc.t("зданий: %d") % off)
		if dark > 0:
			lost.append(Loc.t("городов: %d") % dark)
		ptx = Loc.t("Сеть перегружена %d/%d: без света %s — постройте ТЭЦ или солнечную станцию.") % [p.power_use, p.power_cap, ", ".join(lost) if not lost.is_empty() else Loc.t("часть потребителей")]
	elif free == 0:
		pst = "warn"
		ptx = Loc.t("Сеть на пределе %d/%d: следующий завод останется без света — нужна ещё станция.") % [p.power_use, p.power_cap]
	out["power"] = {"use": p.power_use, "cap": p.power_cap, "status": pst, "text": ptx, "off": off, "dark": dark}

	var units: int = gw.army.count_units(p.id)
	var farms: Array = _own(p, Facility.Kind.FARM)
	var fprod: int = _in(st, "food", "farm")
	var feat: int = maxi(_out(st, "food", "army"), (units + 2) / 3 * int(60.0 / Economy.TICK) if units > 0 else 0)
	var frate: int = econ.res_rate(p, "food")
	var fst: String = "ok"
	var ftx: String = Loc.t("Еды хватает: +%d в минуту, армия ест %d.") % [fprod, feat]
	var fworking: int = 0
	for f2: Facility in farms:
		if _works(f2):
			fworking += 1
	if farms.is_empty() and units == 0:
		fst = "none"
		ftx = Loc.t("Колхозов нет: еда понадобится армии, а колхоз ещё и приносит деньги.")
	elif units > 0 and p.food <= 0 and fprod < feat:
		fst = "bad"
		ftx = Loc.t("Армия голодает: еды нет — постройте колхоз или купите еду в торговле.")
	elif not farms.is_empty() and fworking == 0:
		fst = "warn"
		ftx = Loc.t("Колхозы на паузе — еда не растёт.")
	elif frate < 0:
		fst = "warn"
		ftx = Loc.t("Еда убывает (%d в минуту): запаса на ~%d мин — нужен ещё колхоз.") % [frate, maxi(0, p.food / maxi(1, - frate))]
	elif p.food >= econ.res_cap(p, "food"):
		ftx = Loc.t("Склад еды полон: излишки продаются за полцены.")
	out["food"] = {"per_min": frate, "stock": p.food, "status": fst, "text": ftx}
	var chains: Array = []
	var ch_food: Dictionary = _chain("food", Loc.t("Колхоз → еда → армия"), "icon_farm", farms.size(), "farm" if fst != "ok" else "")
	ch_food["status"] = fst
	ch_food["text"] = ftx
	ch_food["outputs"] = [_io("food", fprod), _io("money", int((st["income"] as Dictionary).get("farm", 0)))]
	if feat > 0:
		ch_food["inputs"] = [_io("food", feat)]
	chains.append(ch_food)
	var ch_pow: Dictionary = _chain("power", Loc.t("ТЭЦ, АЭС и солнце → сеть"), "icon_power", _own(p, Facility.Kind.POWER_PLANT).size() + _own(p, Facility.Kind.SOLAR_FARM).size() + _own(p, Facility.Kind.NUCLEAR_PLANT).size(), "")
	ch_pow["status"] = pst
	ch_pow["text"] = ptx
	if pst != "ok":
		ch_pow["fix_key"] = "power" if p.money >= Military.cost_of(Facility.Kind.POWER_PLANT) else "solar_farm"
	chains.append(ch_pow)
	chains.append(_chain_goods(p, st))
	for r: String in ["metal", "titanium", "precious"]:
		var c: Dictionary = _chain_ore(p, st, r)
		if not c.is_empty():
			chains.append(c)
	var uc: Dictionary = _chain_uranium(p, st)
	if not uc.is_empty():
		chains.append(uc)
	chains.append(_chain_wood(p, st))
	var oc: Dictionary = _chain_oil(p, st)
	if not oc.is_empty():
		chains.append(oc)
	chains.append(_chain_trade(p, st))
	var dc: Dictionary = _chain_drones(p, st)
	if not dc.is_empty():
		chains.append(dc)
	var mc: Dictionary = _chain_missiles(p, st)
	if not mc.is_empty():
		chains.append(mc)
	out["chains"] = chains
	return out



func _chain_uranium(p: Country, st: Dictionary) -> Dictionary:
	var econ: Economy = gw.econ
	var mines: Array = _own(p, Facility.Kind.URANIUM_MINE)
	var npps: Array = _own(p, Facility.Kind.NUCLEAR_PLANT)
	var free_dep: bool = econ._has_free_deposit(p, ["uranium"])
	if mines.is_empty() and npps.is_empty() and not free_dep and p.uranium <= 0:
		return {}
	var ch: Dictionary = _chain("uranium", Loc.t("Урановая шахта → уран → АЭС"), "icon_r_uranium", mines.size(), "")
	ch["outputs"] = [_io("uranium", _in(st, "uranium", "umine"))]
	var use: int = _out_all(st, "uranium")
	if use > 0:
		ch["inputs"] = [_io("uranium", use)]
	var mins: float = Nuclear.fuel_minutes(gw, p)
	var need_u: int = int(Economy.BUILD_COST[Facility.Kind.NUCLEAR_PLANT]["uranium"])
	if not npps.is_empty() and mins <= 0.05:
		ch["status"] = "bad"
		ch["text"] = Loc.t("АЭС стоит без урана — купите уран в торговле или через порт%s.") % (Loc.t(", или поставьте шахту на залежь") if free_dep else "")
		ch["fix_key"] = "mine" if free_dep and mines.is_empty() else "trade"
	elif not npps.is_empty() and mins < 6.0:
		ch["status"] = "warn"
		ch["text"] = Loc.t("Урана на %d мин работы АЭС — пополните запас.") % int(mins)
		ch["fix_key"] = "mine" if free_dep and mines.is_empty() else "trade"
	elif mines.is_empty() and free_dep:
		ch["text"] = Loc.t("На вашей земле залежь урана (зелёный значок): урановая шахта даёт топливо АЭС и дорогой товар.")
		ch["fix_key"] = "mine"
	elif npps.is_empty() and p.uranium >= need_u:
		ch["status"] = "ok"
		ch["text"] = Loc.t("Урана хватает на АЭС (%d): +%d энергии, но ей нужна ПВО.") % [p.uranium, Nuclear.NPP_CAP]
		ch["fix_key"] = "npp"
	else:
		ch["status"] = "ok"
		ch["text"] = Loc.t("Уран %d%s.") % [p.uranium, (Loc.t(" · АЭС на %d мин") % int(mins)) if not npps.is_empty() else Loc.t(" · излишки дорого продаются")]
	return ch


func _chain(id: String, name: String, icon: String, count: int, fix: String) -> Dictionary:
	return {"id": id, "name": name, "icon": icon, "status": "none", "text": "", "inputs": [], "outputs": [], "count": count, "fix_key": fix}



func _get_key(p: Country, res: String) -> String:
	if res == "oil":
		return "oil_rig" if gw.econ._has_free_deposit(p, ["oil"]) else "trade"
	if res == "wood":
		return "sawmill"
	if Economy.ORE_TYPES.has(res):
		return "mine" if gw.econ._has_free_deposit(p, [res]) else "trade"
	if res == "food":
		return "farm"
	return "trade"



func _sell_key(p: Country) -> String:
	return "trade" if gw.econ.ports.has_port(p) or not _coast_ok(p) else "port"


func _power_key(p: Country) -> String:
	return "power" if p.money >= Military.cost_of(Facility.Kind.POWER_PLANT) else "solar_farm"


func _chain_goods(p: Country, st: Dictionary) -> Dictionary:
	var civs: Array = _own(p, Facility.Kind.CIV_FACTORY)
	var ch: Dictionary = _chain("goods", Loc.t("Завод товаров → товары + деньги"), "icon_civ_factory", civs.size(), "")
	ch["outputs"] = [_io("goods", _in(st, "goods", "civ")), _io("money", int((st["income"] as Dictionary).get("civ", 0)))]
	var on: int = 0
	var unpowered: int = 0
	var halted: int = 0
	for f: Facility in civs:
		if f.halted:
			halted += 1
		elif not gw.mil.has_power(f):
			unpowered += 1
		else:
			on += 1
	if civs.is_empty():
		ch["text"] = Loc.t("Заводов товаров нет — это главный доход страны: +%d денег в минуту.") % (Economy.CIV_MONEY * 6)
		ch["fix_key"] = "civ"
	elif on == 0 and unpowered > 0:
		ch["status"] = "bad"
		ch["text"] = Loc.t("Завод товаров стоит без питания — постройте ТЭЦ или солнечную станцию.")
		ch["fix_key"] = _power_key(p)
	elif on == 0:
		ch["status"] = "warn"
		ch["text"] = Loc.t("Завод товаров на паузе — денег не приносит.")
	elif unpowered > 0:
		ch["status"] = "warn"
		ch["text"] = Loc.t("%d из %d заводов без питания — нужна ещё станция.") % [unpowered, civs.size()]
		ch["fix_key"] = _power_key(p)
	elif p.goods >= gw.econ.res_cap(p, "goods"):
		ch["status"] = "warn"
		ch["text"] = Loc.t("Склад товаров полон: излишки уходят за полцены — продайте их или постройте порт.")
		ch["fix_key"] = _sell_key(p)
	else:
		ch["status"] = "ok"
		ch["text"] = Loc.t("Работает: +%d денег в минуту.") % int((st["income"] as Dictionary).get("civ", 0))
	return ch


func _chain_ore(p: Country, st: Dictionary, res: String) -> Dictionary:
	var econ: Economy = gw.econ
	var mines: Array = []
	for f: Facility in _own(p, Facility.Kind.MINE):
		if String(f.deposit.get("res", "")) == res:
			mines.append(f)
	var prod: int = _in(st, res, "mine")
	var use: int = _out_all(st, res)
	var stock: int = int(p.get(res))
	var free_dep: bool = econ._has_free_deposit(p, [res])
	var scarce: bool = econ.scarce_of(p).has(res)
	var demand: float = float(econ.demand(p).get(res, 0.0))
	if mines.is_empty() and res == "precious" and not free_dep and demand <= 0.0 and use == 0:
		return {}
	var ch: Dictionary = _chain(res, Loc.t("Рудник → %s") % Loc.t(String(ORE_TITLE[res])), Economy.RES_ICONS_BIG.get(res, "icon_mine"), mines.size(), "")
	ch["outputs"] = [_io(res, prod)]
	if use > 0:
		ch["inputs"] = [_io(res, use)]
	var nm: String = res_name(res)
	if mines.is_empty():
		if (demand > 0.0 or econ.need(p, res) > 0) and stock < maxi(5, int(demand * 2.0)):
			ch["status"] = "bad"
			ch["text"] = Loc.t("Не хватает: %s (%d) — %s.") % [nm, stock, Loc.t("поставьте рудник на свободную залежь") if free_dep else Loc.t("купите в торговле или через порт")]
			ch["fix_key"] = _get_key(p, res)
		elif free_dep:
			ch["text"] = Loc.t("На вашей земле свободная залежь: %s — поставьте на неё рудник.") % nm
			ch["fix_key"] = "mine"
		elif scarce:
			ch["text"] = Loc.t("В вашем регионе нет залежей: %s — покупайте в торговле или через порт.") % nm
			ch["fix_key"] = "trade"
		else:
			ch["text"] = Loc.t("Рудника нет: ищите залежь (%s) у границ и основайте рядом город.") % nm
			ch["fix_key"] = "town"
		return ch
	var working: int = 0
	var no_power: int = 0
	var empty: int = 0
	var full: int = 0
	var halted: int = 0
	var left: int = 0
	for f2: Facility in mines:
		var si: Dictionary = econ.site_info(f2)
		var s: String = String(si["code"])
		left += maxi(0, int(si["left"]))
		if f2.halted:
			halted += 1
		elif not gw.mil.has_power(f2) or s == "no_power":
			no_power += 1
		elif s == "depleted" or s == "no_deposit":
			empty += 1
		elif s == "store_full":
			full += 1
		else:
			working += 1
	if working == 0:
		if no_power > 0:
			ch["status"] = "bad"
			ch["text"] = Loc.t("Рудник стоит без питания — постройте ТЭЦ или солнечную станцию.")
			ch["fix_key"] = _power_key(p)
		elif empty > 0:
			ch["status"] = "bad"
			ch["text"] = Loc.t("Залежь исчерпана — поставьте рудник на другую залежь или покупайте %s.") % nm
			ch["fix_key"] = _get_key(p, res)
		elif full > 0:
			ch["status"] = "warn"
			ch["text"] = Loc.t("Склад полон (%d) — продайте излишки в торговле или постройте порт.") % stock
			ch["fix_key"] = _sell_key(p)
		else:
			ch["status"] = "warn"
			ch["text"] = Loc.t("Рудник на паузе — добычи нет.")
		return ch
	if no_power > 0:
		ch["status"] = "warn"
		ch["text"] = Loc.t("%d рудник(а) без питания — нужна ещё станция.") % no_power
		ch["fix_key"] = _power_key(p)
	elif use > prod and stock < use * 2:
		ch["status"] = "warn"
		ch["text"] = Loc.t("Расход (%d) больше добычи (%d) — ещё рудник, улучшение или покупка.") % [use, prod]
		ch["fix_key"] = _get_key(p, res)
	elif left < 120:
		ch["status"] = "warn"
		ch["text"] = Loc.t("Залежь кончается: осталось %d — найдите новую.") % left
		ch["fix_key"] = _get_key(p, res)
	else:
		ch["status"] = "ok"
		ch["text"] = Loc.t("Добыча +%d в минуту, запас %d.") % [prod, stock]
	return ch


func _chain_wood(p: Country, st: Dictionary) -> Dictionary:
	var econ: Economy = gw.econ
	var saws: Array = _own(p, Facility.Kind.SAWMILL)
	var ch: Dictionary = _chain("wood", Loc.t("Лесопилка → дерево"), "icon_sawmill", saws.size(), "")
	var prod: int = _in(st, "wood", "sawmill")
	var use: int = _out_all(st, "wood")
	ch["outputs"] = [_io("wood", prod)]
	if use > 0:
		ch["inputs"] = [_io("wood", use)]
	if saws.is_empty():
		ch["status"] = "warn" if p.wood < 40 else "none"
		ch["text"] = Loc.t("Лесопилки нет: дерево (у вас %d) нужно почти везде — ставьте у леса.") % p.wood
		ch["fix_key"] = "sawmill"
		return ch
	var working: int = 0
	var cut: int = 0
	var full: int = 0
	for f: Facility in saws:
		var s: String = String(econ._site_of(f)["status"])
		if f.halted:
			continue
		if s == "forest_cut":
			cut += 1
		elif s == "store_full":
			full += 1
		else:
			working += 1
	if working == 0 and cut > 0:


		var wcap: int = econ.res_cap(p, "wood")
		var short: bool = econ.need(p, "wood") > 0 and p.wood < wcap
		ch["status"] = "bad" if short else "warn"
		ch["text"] = Loc.t("Лес вокруг лесопилки вырублен — поставьте новую у леса (пни отрастают за 8 мин).") if short else Loc.t("Лес у лесопилки вырублен; дерева пока хватает (%d/%d). Новую лесопилку — у леса.") % [p.wood, wcap]
		ch["fix_key"] = "sawmill"
	elif working == 0 and full > 0:
		ch["status"] = "warn"
		ch["text"] = Loc.t("Склад дерева полон — продайте излишки.")
		ch["fix_key"] = _sell_key(p)
	elif working == 0:
		ch["status"] = "warn"
		ch["text"] = Loc.t("Лесопилка на паузе.")
	else:
		ch["status"] = "ok"
		ch["text"] = Loc.t("Рубка +%d в минуту, запас %d.") % [prod, p.wood]
	return ch


func _chain_oil(p: Country, st: Dictionary) -> Dictionary:
	var econ: Economy = gw.econ
	var rigs: Array = _own(p, Facility.Kind.OIL_RIG)
	var refs: Array = _own(p, Facility.Kind.REFINERY)
	var free_dep: bool = econ._has_free_deposit(p, ["oil"])
	var ch: Dictionary = _chain("oil", Loc.t("Нефть → НПЗ → топливо"), "icon_refinery", rigs.size() + refs.size(), "")
	var oprod: int = _in(st, "oil", "oil_rig")
	var ouse: int = _out(st, "oil", "refinery")
	var fprod: int = _in(st, "fuel", "refinery")
	var sale: int = int((st["income"] as Dictionary).get("fuel_sale", 0))
	ch["outputs"] = [_io("oil", oprod), _io("fuel", fprod), _io("money", sale)]
	if ouse > 0:
		ch["inputs"] = [_io("oil", ouse)]
	if rigs.is_empty() and refs.is_empty():
		if free_dep:
			ch["text"] = Loc.t("Нефтяная залежь на вашей земле: нефтевышка → НПЗ → топливо (продаётся само).")
			ch["fix_key"] = "oil_rig"
		elif econ.scarce_of(p).has("oil"):
			ch["text"] = Loc.t("Нефти в вашем регионе нет: НПЗ возможен только на покупной нефти.")
			ch["fix_key"] = "trade"
		else:
			ch["text"] = Loc.t("Нефти нет: ищите чёрный значок залежи у границ.")
		return ch
	if refs.is_empty():
		if p.oil >= econ.res_cap(p, "oil"):
			ch["status"] = "warn"
			ch["text"] = Loc.t("Нефть копится (%d/%d): постройте НПЗ — топливо дороже сырой нефти.") % [p.oil, econ.res_cap(p, "oil")]
		else:
			ch["status"] = "ok"
			ch["text"] = Loc.t("Нефть +%d в минуту. Дальше — НПЗ (на постройку нужна нефть 20).") % oprod
		ch["fix_key"] = "refinery"
		return ch
	var on: int = 0
	var unpowered: int = 0
	for f: Facility in refs:
		if f.halted:
			continue
		if gw.mil.has_power(f):
			on += 1
		else:
			unpowered += 1
	var full_use: int = int(60.0 / Military.FUEL_DT) * on
	if on == 0 and unpowered > 0:
		ch["status"] = "bad"
		ch["text"] = Loc.t("НПЗ стоит без питания — постройте ТЭЦ или солнечную станцию.")
		ch["fix_key"] = _power_key(p)
	elif on == 0:
		ch["status"] = "warn"
		ch["text"] = Loc.t("НПЗ на паузе.")
	elif p.oil < 1 and oprod <= 0:
		ch["status"] = "bad"
		ch["text"] = Loc.t("НПЗ стоит: нет нефти — постройте нефтевышку или купите нефть.")
		ch["fix_key"] = _get_key(p, "oil")
	elif p.oil < 3 and ouse < full_use * 3 / 4:
		ch["status"] = "warn"
		ch["text"] = Loc.t("Нефти мало: НПЗ может перерабатывать %d в минуту, вышки дают %d — ещё вышка или закупка.") % [full_use, oprod]
		ch["fix_key"] = _get_key(p, "oil")
	else:
		ch["status"] = "ok"
		if sale > 0:
			ch["text"] = Loc.t("Топливо +%d в минуту, продажа излишков +%d денег.") % [fprod, sale]
		else:
			ch["text"] = Loc.t("Топливо +%d в минуту копится в резерв авиации (%d), сверх него продаётся само.") % [fprod, Military.FUEL_RESERVE]
	return ch


func _chain_trade(p: Country, st: Dictionary) -> Dictionary:
	var econ: Economy = gw.econ
	var n: int = 0
	for k: Variant in econ.trade.keys():
		var parts: PackedStringArray = str(k).split(":")
		if parts.size() == 2 and (int(parts[0]) == p.id or int(parts[1]) == p.id):
			n += 1
	var port: bool = econ.ports.has_port(p)
	var ch: Dictionary = _chain("trade", Loc.t("Торговля и порт"), "icon_port" if port else "icon_trade", n + (1 if port else 0), "")
	var inc: Dictionary = st["income"]
	var spd: Dictionary = st["spend"]
	var earn: int = int(inc.get("trade", 0)) + int(inc.get("export", 0))
	var pay: int = int(spd.get("trade", 0)) + int(spd.get("import", 0))
	ch["outputs"] = [_io("money", earn)]
	if pay > 0:
		ch["inputs"] = [_io("money", pay)]
	var full: PackedStringArray = PackedStringArray()
	for r: String in Economy.TRADE_RES:
		if int(p.get(r)) >= econ.res_cap(p, r):
			full.append(res_name(r))
	var short: Array = econ.shortages(p)
	var sc: Array = econ.scarce_of(p)
	if n == 0 and not port:
		if not full.is_empty():
			ch["status"] = "warn"

			var fl: String = ", ".join(full.slice(0, 2)) + (" +%d" % (full.size() - 2) if full.size() > 2 else "")
			ch["text"] = Loc.t("Продайте излишки: %s (склад полон).") % fl
			ch["fix_key"] = "port" if _coast_ok(p) else "trade"
		elif not short.is_empty():
			ch["status"] = "warn"
			ch["text"] = Loc.t("Не хватает: %s %d — купите в окне торговли.") % [res_name(String(short[0][0])), int(short[0][1])]
			ch["fix_key"] = "trade"
		else:
			var names: PackedStringArray = PackedStringArray()
			for r2: String in sc:
				names.append(res_name(r2))
			ch["text"] = (Loc.t("В вашем регионе нет: %s — это покупают. ") % ", ".join(names) if not names.is_empty() else "") + Loc.t("Договор с соседом сам продаёт излишки.")
			ch["fix_key"] = "trade"
		return ch
	if not short.is_empty():
		ch["status"] = "warn"
		ch["text"] = Loc.t("Не хватает: %s %d — купите в окне торговли.") % [res_name(String(short[0][0])), int(short[0][1])]
		ch["fix_key"] = "trade"
	else:
		ch["status"] = "ok"
		ch["text"] = Loc.t("Договоров: %d%s. Доход от торговли +%d в минуту.") % [n, Loc.t(", порт вывозит излишки") if port else "", earn]
	return ch


func _chain_drones(p: Country, st: Dictionary) -> Dictionary:
	var mil: Military = gw.mil
	var fs: Array = _own(p, Facility.Kind.DRONE_FACTORY)
	if fs.is_empty():
		return {}
	var ch: Dictionary = _chain("drones", Loc.t("Металл → дронный завод → дроны"), "icon_dronefactory", fs.size(), "")
	var spent: int = int((st["spend"] as Dictionary).get("drones", 0))
	ch["inputs"] = [_io("metal", _out(st, "metal", "drones"))]
	if _out(st, "titanium", "drones") > 0:
		(ch["inputs"] as Array).append(_io("titanium", _out(st, "titanium", "drones")))
	if spent > 0:
		(ch["inputs"] as Array).append(_io("money", spent))
	ch["outputs"] = [_io("drones", roundi(float(spent) / float(Military.COST_DRONE)))]
	var on: int = 0
	var unpowered: int = 0
	for f: Facility in fs:
		if f.halted:
			continue
		if mil.has_power(f):
			on += 1
		else:
			unpowered += 1
	var cap: int = mil.drone_capacity(p.id)
	var stock: int = mil.stock_count(p.id)
	var cost: Dictionary = mil.drone_cost(false)
	if on == 0 and unpowered > 0:
		ch["status"] = "bad"
		ch["text"] = Loc.t("Дронный завод без питания — постройте ТЭЦ или солнечную станцию.")
		ch["fix_key"] = _power_key(p)
	elif on == 0:
		ch["status"] = "warn"
		ch["text"] = Loc.t("Дронный завод на паузе.")
	elif _own(p, Facility.Kind.DRONE_PORT).is_empty():
		ch["status"] = "bad"
		ch["text"] = Loc.t("Дронам некуда садиться — постройте дронопорт.")
		ch["fix_key"] = "droneport"
	elif stock >= cap:
		ch["status"] = "warn"
		ch["text"] = Loc.t("Дронопорты полны (%d/%d): запускайте дроны или добавьте склад / дронопорт.") % [stock, cap]
		ch["fix_key"] = "droneport"
	elif not p.has_res(cost):
		ch["status"] = "bad"
		ch["text"] = Loc.t("Завод ждёт: не хватает %s — %s.") % [p.missing_res(cost), Loc.t("рудник на залежи металла или покупка") if p.metal < int(cost.get("metal", 0)) else Loc.t("нужны деньги")]
		ch["fix_key"] = _get_key(p, "metal") if p.metal < int(cost.get("metal", 0)) else ""
	else:
		ch["status"] = "ok"
		ch["text"] = Loc.t("Дрон каждые %d с, в запасе %d/%d.") % [int(Military.PROD_TIME), stock, cap]
	return ch


func _chain_missiles(p: Country, st: Dictionary) -> Dictionary:
	var mil: Military = gw.mil
	var fs: Array = _own(p, Facility.Kind.MISSILE_FACTORY)
	if fs.is_empty():
		return {}
	var ch: Dictionary = _chain("missiles", Loc.t("Титан → ракетный завод → ракеты"), "icon_missile_factory", fs.size(), "")
	var spent: int = int((st["spend"] as Dictionary).get("missiles", 0))
	ch["inputs"] = [_io("titanium", _out(st, "titanium", "missiles")), _io("metal", _out(st, "metal", "missiles"))]
	if spent > 0:
		(ch["inputs"] as Array).append(_io("money", spent))
	var worst: String = ""
	var wst: String = "ok"
	var made: float = 0.0
	for f: Facility in fs:
		var t: int = f.prod_type
		made += 60.0 / float(Military.MT_TIME[t]) if f.producing else 0.0
		var rc: Dictionary = Economy.res_cost("missile_%d" % t)
		rc["money"] = int(Military.MT_COST[t])
		var tn: String = String(Military.MT_NAMES[t]).to_lower()
		if f.halted:
			if wst == "ok":
				wst = "warn"
				worst = Loc.t("Ракетный завод на паузе.")
			continue
		if not mil.has_power(f):
			wst = "bad"
			worst = Loc.t("Ракетный завод без питания — постройте ТЭЦ или солнечную станцию.")
			ch["fix_key"] = _power_key(p)
		elif f.producing:
			continue
		elif p.missile_stock[t] >= int(Military.MT_CAP[t]):
			if wst == "ok":
				wst = "warn"
				worst = Loc.t("Склад ракет (%s) полон: %d — запускайте или смените тип.") % [tn, p.missile_stock[t]]
		elif not mil.has_carrier(p, t):
			if wst == "ok":
				wst = "warn"
				worst = Loc.t("Ракетам (%s) нужен носитель — самолёт на аэродроме.") % tn
				ch["fix_key"] = "airfield"
		elif not p.has_res(rc):
			wst = "bad"
			var ti_short: bool = p.titanium < int(rc.get("titanium", 0))
			worst = Loc.t("Завод ждёт: не хватает %s — %s.") % [p.missing_res(rc), Loc.t("рудник на залежи титана или покупка") if ti_short else Loc.t("добыча или покупка")]
			ch["fix_key"] = _get_key(p, "titanium") if ti_short else _get_key(p, "metal")
	ch["outputs"] = [_io("missiles", roundi(made))]
	ch["status"] = wst
	ch["text"] = worst if worst != "" else Loc.t("Работает: в запасе %d ракет.") % (p.missile_stock[0] + p.missile_stock[1] + p.missile_stock[2] + p.missile_stock[3] + p.missile_stock[4])
	return ch






func problems(p: Country) -> Array:
	if p == null:
		return []
	return _cached("probs%d" % p.id, CACHE_MS, func() -> Array: return _problems(p))


func _problems(p: Country) -> Array:
	var out: Array = []
	var mil: Military = gw.mil
	var econ: Economy = gw.econ
	for f: Facility in mil.facilities:
		if f.country_id != p.id or f.parent != null or not mil.alive(f):
			continue
		var kind: String = ""
		var icon: String = ""
		var text: String = ""
		if f.halted and mil.can_halt(f):
			kind = "halted"
			icon = "icon_pause"
			text = Loc.t("Производство на паузе")
		elif Military.uses_power(f.kind) and not mil.has_power(f):
			kind = "no_power"
			icon = "res_power"
			text = Loc.t("Нет питания: постройте ТЭЦ или солнечную станцию")
		else:
			match f.kind:
				Facility.Kind.MINE, Facility.Kind.OIL_RIG, Facility.Kind.SAWMILL:
					var s: String = String(econ._site_of(f)["status"])
					if s == "depleted" or s == "no_deposit":
						kind = "no_deposit"
						icon = Military.icon_of(f.kind)
						text = Loc.t("Залежь исчерпана — нужна новая")
					elif s == "forest_cut":
						kind = "no_input"
						icon = "res_wood"
						text = Loc.t("Лес вокруг вырублен")
					elif s == "store_full":
						kind = "full"
						icon = "icon_store"
						text = Loc.t("Склад полон: продайте излишки")
				Facility.Kind.REFINERY:
					var rig_on: bool = false
					for r: Facility in _own(p, Facility.Kind.OIL_RIG):
						rig_on = rig_on or econ.site_working(r)
					if p.oil < 1 and not rig_on and econ.inbound(p, "oil") <= 0:
						kind = "no_input"
						icon = "res_oil"
						text = Loc.t("НПЗ стоит: нет нефти")
				Facility.Kind.DRONE_FACTORY:
					if not f.producing:
						var cost: Dictionary = mil.drone_cost(f.prod_type == 1)
						if _own(p, Facility.Kind.DRONE_PORT).is_empty():
							kind = "idle"
							icon = "icon_droneport"
							text = Loc.t("Нужен дронопорт")
						elif mil.stock_count(p.id) >= mil.drone_capacity(p.id):
							kind = "full"
							icon = "icon_store"
							text = Loc.t("Дронопорты полны")
						elif not p.has_res(cost):
							kind = "no_input"
							icon = res_icon("metal" if p.metal < int(cost.get("metal", 0)) else "money")
							text = Loc.t("Не хватает: %s") % p.missing_res(cost)
				Facility.Kind.MISSILE_FACTORY:
					if not f.producing:
						var t: int = f.prod_type
						var rc: Dictionary = Economy.res_cost("missile_%d" % t)
						rc["money"] = int(Military.MT_COST[t])
						if p.missile_stock[t] >= int(Military.MT_CAP[t]):
							kind = "full"
							icon = "icon_store"
							text = Loc.t("Склад ракет полон")
						elif not mil.has_carrier(p, t):
							kind = "idle"
							icon = "icon_airfield_b"
							text = Loc.t("Нужен самолёт-носитель")
						elif not p.has_res(rc):
							kind = "no_input"
							icon = res_icon("titanium" if p.titanium < int(rc.get("titanium", 0)) else "money")
							text = Loc.t("Не хватает: %s") % p.missing_res(rc)
		if kind != "":
			out.append({"fid": f.id, "pos": f.center_px(), "kind": kind, "icon": icon, "text": text, "title": Military.title_of(f.kind)})
	return out





func tip(p: Country, urgent: bool = true) -> String:
	if p == null or p.capital_id < 0:
		return ""
	if urgent:
		var fl: Dictionary = flows(p)
		if String((fl.get("power", {}) as Dictionary).get("status", "")) == "bad":
			return String(fl["power"]["text"])
		for ch: Dictionary in fl.get("chains", []):
			if String(ch["status"]) == "bad":
				return String(ch["text"])
		return ""
	var g: Dictionary = current_goal(p)
	if g.is_empty():
		return ""
	var pr: Array = progress(p)
	return Loc.t("План %d/%d — %s: %s") % [int(pr[0]) + 1, int(pr[1]), String(g["title"]), String(g["why"])]




func save_state() -> Dictionary:
	return {"claimed": claimed.keys(), "incl": incl.keys()}


func load_state(d: Dictionary) -> void :
	_goal_sig = ""
	_check_ms = -100000
	claimed.clear()
	for k: Variant in d.get("claimed", []):
		claimed[str(k)] = true
	incl.clear()
	for k2: Variant in d.get("incl", []):
		incl[str(k2)] = true
	_cache.clear()
