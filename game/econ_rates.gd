extends RefCounted





const PER_MIN: float = 60.0 / Economy.TICK

const MAKERS: Dictionary = {
	"food": [Facility.Kind.FARM], "goods": [Facility.Kind.CIV_FACTORY], "metal": [Facility.Kind.MINE], 
	"titanium": [Facility.Kind.MINE], "precious": [Facility.Kind.MINE], "oil": [Facility.Kind.OIL_RIG], 
	"wood": [Facility.Kind.SAWMILL], "uranium": [Facility.Kind.URANIUM_MINE], 
	"fuel": [Facility.Kind.OIL_RIG, Facility.Kind.REFINERY], 
}
const DEPOSIT_RES: Array = ["metal", "titanium", "precious", "oil", "uranium"]

const PLURAL: Dictionary = {
	Facility.Kind.FARM: "КОЛХОЗЫ", Facility.Kind.CIV_FACTORY: "ЗАВОДЫ", Facility.Kind.MINE: "РУДНИКИ", 
	Facility.Kind.OIL_RIG: "ВЫШКИ", Facility.Kind.SAWMILL: "ЛЕСОПИЛКИ", Facility.Kind.URANIUM_MINE: "ШАХТЫ", 
	Facility.Kind.REFINERY: "НПЗ", Facility.Kind.NUCLEAR_PLANT: "АЭС", Facility.Kind.BARRACKS: "КАЗАРМЫ", 
	Facility.Kind.AIRFIELD: "АЭРОДРОМЫ", Facility.Kind.DRONE_FACTORY: "ЗАВОДЫ ДРОНОВ", 
	Facility.Kind.MISSILE_FACTORY: "РАКЕТНЫЕ ЗАВОДЫ", Facility.Kind.PORT: "ПОРТЫ", 
}

const SRC: Dictionary = {
	"farm": ["Колхозы", "icon_farm", Facility.Kind.FARM], "civ": ["Заводы товаров", "icon_civ_factory", Facility.Kind.CIV_FACTORY], 
	"mine": ["Рудники", "icon_mine", Facility.Kind.MINE], "oil_rig": ["Нефтевышки", "icon_oil_rig", Facility.Kind.OIL_RIG], 
	"sawmill": ["Лесопилки", "icon_sawmill", Facility.Kind.SAWMILL], "umine": ["Урановые шахты", "icon_umine", Facility.Kind.URANIUM_MINE], 
	"refinery": ["НПЗ", "icon_refinery", Facility.Kind.REFINERY], "npp": ["АЭС", "icon_npp", Facility.Kind.NUCLEAR_PLANT], 
	"army": ["Армия", "icon_barracks", Facility.Kind.BARRACKS], "aircraft": ["Авиация", "icon_airfield", Facility.Kind.AIRFIELD], 
	"drones": ["Дроны", "icon_dronefactory", Facility.Kind.DRONE_FACTORY], "missiles": ["Ракеты", "icon_missile_factory", Facility.Kind.MISSILE_FACTORY], 
	"build": ["Стройка", "icon_factory", -1], "upgrade": ["Улучшения", "icon_upgrade", -1], "repair": ["Ремонт", "icon_restore", -1], 
	"trade": ["Торговля", "icon_trade", -1], "export": ["Экспорт (порт)", "icon_export", Facility.Kind.PORT], 
	"import": ["Импорт (порт)", "icon_port", Facility.Kind.PORT], "surplus": ["Излишки: склад полон", "icon_sell", -1], 
	"fuel_sale": ["Продажа топлива", "icon_sell", -1], "intel": ["Разведка", "icon_recon", -1], "aid": ["Помощь", "icon_aid", -1], 
	"subst": ["Замена ресурсов", "icon_substitute", -1], "tribute": ["Уступки", "icon_dip_demand", -1], "plan": ["План развития", "icon_hint", -1], 
}

const NOTE: Dictionary = {"fuel_sale": "всё сверх резерва авиации — по мировой цене", "surplus": "склад полон — продано за полцены", 
	"build": "новые постройки", "upgrade": "улучшения построек", "repair": "ремонт", "trade": "сделки и поставки", 
	"export": "корабли из порта", "drones": "производство дронов", "missiles": "производство ракет", "aircraft": "покупка самолётов", 
	"army": "набор и техника", "intel": "разведка", "aid": "помощь союзникам", "subst": "замена нехватки", "tribute": "уступки"}

const EATERS: Dictionary = {"oil": "refinery", "uranium": "npp", "food": "army", "fuel": "aircraft"}


static func level_mul(f: Facility) -> float:
	return float(Economy.LEVEL_MUL[clampi(f.level, 1, Economy.MAX_LEVEL)])



static func state_of(gw: GameWorld, f: Facility) -> String:
	if f.restore_t > 0.0:
		return "building"
	if not gw.mil.alive(f):
		return "ruined"
	if f.kind == Facility.Kind.NUCLEAR_PLANT and f.u_hits > 0:
		return "damaged"
	for id: int in f.obj_ids:
		if id >= 0 and id < gw.obj_kind.size() and gw.obj_kind[id] == GameWorld.KIND_BUILDING and gw.obj_state[id] != 0:
			return "damaged"
	return "ok"


static func state_text(gw: GameWorld, f: Facility, st: String) -> String:
	match st:
		"building":
			var mc: Variant = gw.mil.get("constructing")
			return Loc.t("строится") if mc is Dictionary and (mc as Dictionary).has(f.id) else Loc.t("ремонт")
		"ruined":
			return Loc.t("разрушено")
		"damaged":
			return Loc.t("повреждено")
	return Loc.t("цело")


static func _cut(gw: GameWorld, f: Facility) -> int:
	var s: Variant = gw.get("supply")
	if s == null or not (s as Object).has_method("cut_level"):
		return 0
	return int((s as Object).call("cut_level", f))




static func site(gw: GameWorld, f: Facility, c: Country = null) -> Dictionary:
	var e: Economy = gw.econ
	var mil: Military = gw.mil
	if c == null:
		c = gw.country_by_id(f.country_id)
	var out: Dictionary = {"res": "", "n": 0.0, "full": 0.0, "why": "", "money": 0.0, "use_res": "", "use": 0.0, "use_full": 0.0, "state": state_of(gw, f)}
	var lm: float = level_mul(f)
	var mul: float = 1.0 if c == null or c.is_player else GameConfig.ai_income_mul(c)
	match f.kind:
		Facility.Kind.FARM:
			out["res"] = "food"
			out["full"] = float(ceili(Economy.FARM_FOOD * lm)) * PER_MIN
			out["money"] = float(int(Economy.FARM_MONEY * mul * lm)) * PER_MIN
		Facility.Kind.CIV_FACTORY:
			out["res"] = "goods"
			out["full"] = float(ceili(Economy.CIV_GOODS * lm)) * PER_MIN
			out["money"] = float(int(Economy.CIV_MONEY * mul * lm)) * PER_MIN
		Facility.Kind.MINE:
			out["res"] = String(f.deposit.get("res", "titanium")) if not f.deposit.is_empty() else ""
			out["full"] = float(ceili(float(int(Economy.MINE_RATE.get(String(out["res"]), 2))) * lm)) * PER_MIN
			out["money"] = float(int(Economy.MINE_MONEY * mul)) * PER_MIN
		Facility.Kind.OIL_RIG:
			out["res"] = "oil"
			out["full"] = float(ceili(float(Economy.RIG_OIL) * lm)) * PER_MIN
		Facility.Kind.URANIUM_MINE:
			out["res"] = "uranium"
			out["full"] = Nuclear.U_MINE_RATE * PER_MIN
			out["money"] = float(int(Economy.MINE_MONEY * mul)) * PER_MIN
		Facility.Kind.SAWMILL:
			out["res"] = "wood"
			var st0: Dictionary = e._site.get(f, {})
			var trees: int = int(st0.get("trees", 0))
			if trees <= 0:
				trees = e.count_trees(f.cell + f.size / 2, Economy.SAW_R, 2)
			out["full"] = 0.0 if trees <= 0 else float(ceili(float(mini(Economy.SAW_WOOD_MAX, 1 + trees / 15)) * lm)) * PER_MIN
		Facility.Kind.REFINERY:
			out["res"] = "fuel"
			out["use_res"] = "oil"
			out["full"] = float(e.level_of(f)) * 60.0 / Military.FUEL_DT
			out["use_full"] = out["full"]
		Facility.Kind.NUCLEAR_PLANT:
			out["use_res"] = "uranium"
			out["use_full"] = 60.0 / Nuclear.FUEL_S
		_:
			return out

	var st: String = String(out["state"])
	if st == "building" or st == "ruined":
		out["why"] = state_text(gw, f, st)
		out["money"] = 0.0
		return out
	if f.halted:
		out["why"] = Loc.t("пауза")
		out["money"] = 0.0
		return out
	var k: float = 1.0
	var cut: int = _cut(gw, f) if f.kind != Facility.Kind.REFINERY and f.kind != Facility.Kind.NUCLEAR_PLANT else 0
	if cut >= 2:
		out["why"] = Loc.t("мост разрушен")
		out["money"] = 0.0
		return out
	if cut == 1:
		k = 0.5
		out["money"] = float(out["money"]) * 0.5
		out["why"] = Loc.t("объезд: −50 %")
	match f.kind:
		Facility.Kind.FARM:
			out["n"] = float(out["full"]) * k
		Facility.Kind.CIV_FACTORY:
			if not mil.has_power(f):
				out["why"] = Loc.t("нет питания")
				out["money"] = 0.0
				return out
			out["n"] = float(out["full"]) * k
		Facility.Kind.MINE, Facility.Kind.OIL_RIG, Facility.Kind.SAWMILL, Facility.Kind.URANIUM_MINE:
			if f.kind != Facility.Kind.OIL_RIG and f.kind != Facility.Kind.SAWMILL and not mil.has_power(f):
				out["why"] = Loc.t("нет питания")
				out["money"] = 0.0
				return out
			var s2: Dictionary = e._site.get(f, {})
			if s2.is_empty():
				out["why"] = Loc.t("запуск")
				return out
			var why2: String = String(s2.get("status", ""))
			if f.kind == Facility.Kind.URANIUM_MINE:
				out["n"] = float(out["full"]) * k if why2 == "" else 0.0
			else:
				out["n"] = float(int(s2.get("rate", 0))) * PER_MIN * k
			if why2 != "" and why2 != "detour":
				out["why"] = Economy.site_text(why2).to_lower()
			if float(out["n"]) <= 0.0:
				out["money"] = 0.0
		Facility.Kind.REFINERY:
			if not mil.has_power(f):
				out["why"] = Loc.t("нет питания")
				return out
			out["n"] = out["full"]
			out["use"] = out["full"]
			if c != null and c.oil < e.level_of(f):
				out["why"] = Loc.t("мало нефти")
				out["low_oil"] = true
		Facility.Kind.NUCLEAR_PLANT:
			if f.u_fuel <= 0.0 and (c == null or c.uranium < 1):
				out["why"] = Loc.t("нет урана")
				return out
			out["use"] = out["use_full"]
	return out



static func refinery_share(gw: GameWorld, c: Country, f: Facility) -> float:
	var st: Dictionary = gw.econ.stats(c)
	var made: int = int((st["res_in"].get("fuel", {}) as Dictionary).get("refinery", 0))
	var lv: int = 0
	for g: Facility in gw.mil.facilities:
		if g.country_id == c.id and g.kind == Facility.Kind.REFINERY and gw.mil.alive(g) and not g.halted and gw.mil.has_power(g):
			lv += gw.econ.level_of(g)
	return 0.0 if lv <= 0 else float(made) * float(gw.econ.level_of(f)) / float(lv)



static func site_now(gw: GameWorld, f: Facility, c: Country = null) -> Dictionary:
	if c == null:
		c = gw.country_by_id(f.country_id)
	var s: Dictionary = site(gw, f, c)
	if f.kind == Facility.Kind.REFINERY and bool(s.get("low_oil", false)) and c != null:
		var n: float = minf(float(s["full"]), refinery_share(gw, c, f))
		s["n"] = n
		s["use"] = n
		if n >= float(s["full"]) - 0.01:
			s["why"] = ""
	return s


static func nearest_city(gw: GameWorld, c: Country, f: Facility) -> String:
	if c == null:
		return ""
	var at: Vector2i = f.cell + f.size / 2
	var best: String = ""
	var bd: int = 1 << 30
	for cid: int in c.city_ids:
		if cid < 0 or cid >= gw.cities.size():
			continue
		var city: City = gw.cities[cid]
		var d: int = (city.center - at).length_squared()
		if d < bd:
			bd = d
			best = city.name
	return best



static func own(gw: GameWorld, c: Country, kind: int, res: String = "") -> Array:
	var out: Array = []
	for f: Facility in gw.mil.facilities:
		if f.country_id != c.id or f.kind != kind:
			continue
		if kind == Facility.Kind.MINE and res != "" and String(f.deposit.get("res", "")) != res:
			continue
		out.append(f)
	out.sort_custom( func(a: Facility, b: Facility) -> bool: return a.id < b.id)
	return out


static func number_of(gw: GameWorld, c: Country, f: Facility) -> int:
	var n: int = 0
	for g: Facility in gw.mil.facilities:
		if g.country_id == c.id and g.kind == f.kind and g.id <= f.id:
			n += 1
	return n




static func producers(gw: GameWorld, c: Country, res: String, kind: int) -> Array:
	var rows: Array = []
	var mres: String = res if kind == Facility.Kind.MINE else ""
	var fs: Array = own(gw, c, kind, mres)
	for i: int in fs.size():
		var f: Facility = fs[i]
		var s: Dictionary = site_now(gw, f, c)
		var st: String = String(s["state"])
		rows.append({"f": f, "id": f.id, "no": i + 1, "title": "%s №%d" % [Military.title_of(kind), i + 1], "near": nearest_city(gw, c, f), 
			"level": f.level, "state": st, "state_text": state_text(gw, f, st), "why": String(s["why"]), "n": float(s["n"]), 
			"full": float(s["full"]), "res": String(s["res"]), "use": float(s["use"]), "use_res": String(s["use_res"]), "icon": Military.icon_of(kind)})
	rows.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		var pa: int = _prob(a)
		var pb: int = _prob(b)
		if pa != pb:
			return pa > pb
		if absf(float(a["n"]) - float(b["n"])) > 0.01:
			return float(a["n"]) > float(b["n"])
		return int(a["id"]) < int(b["id"]))
	return rows


static func _prob(r: Dictionary) -> int:
	var st: String = String(r["state"])
	if st == "ruined":
		return 3
	if float(r.get("n", 0.0)) <= 0.0 and String(r.get("why", "")) != "":
		return 2
	if st == "damaged" or String(r.get("why", "")) != "":
		return 1
	return 0


static func total(rows: Array, field: String = "n") -> float:
	var t: float = 0.0
	for r: Dictionary in rows:
		t += float(r.get(field, 0.0))
	return t



static func deposits(gw: GameWorld, c: Country, res: String) -> Array:
	var out: Array = []
	var inf: bool = GameConfig.infinite_res()
	for dp: Dictionary in gw.econ.deposits:
		if String(dp.get("res", "")) != res:
			continue
		var cell: Vector2i = dp["cell"]
		if gw.data.get_owner_id(cell.x, cell.y) != c.id:
			continue
		var mf: Variant = dp.get("mine")
		var left: int = int(dp.get("left", 0))
		var mx: int = int(dp.get("max", left))
		var st: String = "free"
		if left <= 0 and not inf:
			st = "empty"
		elif mf != null and mf is Facility and gw.mil.facilities.has(mf):
			st = "busy"
		out.append({"dp": dp, "cell": cell, "left": left, "max": mx, "mine": mf if st == "busy" else null, "state": st, "small": bool(dp.get("small", false))})
	out.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		var o: Dictionary = {"free": 0, "busy": 1, "empty": 2}
		if int(o[a["state"]]) != int(o[b["state"]]):
			return int(o[a["state"]]) < int(o[b["state"]])
		return int(a["left"]) > int(b["left"]))
	return out



static func balance(gw: GameWorld, c: Country, res: String) -> Dictionary:
	var st: Dictionary = gw.econ.stats(c)
	var bi: Dictionary = (st["res_in"].get(res, {}) as Dictionary).duplicate()
	var bo: Dictionary = (st["res_out"].get(res, {}) as Dictionary).duplicate()
	var ti: int = 0
	var to: int = 0
	for k: Variant in bi:
		ti += int(bi[k])
	for k2: Variant in bo:
		to += int(bo[k2])
	return {"in": bi, "out": bo, "tin": ti, "tout": to, "window": int(st.get("window_s", 60))}






static func consumers(gw: GameWorld, c: Country, res: String) -> Array:
	var out: Array = []
	var bal: Dictionary = balance(gw, c, res)
	var bo: Dictionary = bal["out"]
	var done: Dictionary = {}
	var eat: String = String(EATERS.get(res, ""))
	if eat == "refinery" or eat == "npp":
		var kind: int = Facility.Kind.REFINERY if eat == "refinery" else Facility.Kind.NUCLEAR_PLANT
		var rows: Array = []
		var fs: Array = own(gw, c, kind)
		for i: int in fs.size():
			var f: Facility = fs[i]
			var s: Dictionary = site_now(gw, f, c)
			var st: String = String(s["state"])
			rows.append({"f": f, "id": f.id, "title": "%s №%d" % [Military.title_of(kind), i + 1], "near": nearest_city(gw, c, f), "level": f.level, 
				"state": st, "state_text": state_text(gw, f, st), "why": String(s["why"]), "n": float(s["use"]), "icon": Military.icon_of(kind)})
		if not rows.is_empty():
			out.append({"key": eat, "name": String(SRC[eat][0]), "icon": String(SRC[eat][1]), "kind": kind, "n": total(rows), "rows": rows})
			done[eat] = true
	elif eat == "army":
		var per: Dictionary = {}
		var loose: int = 0
		var n_all: int = 0
		for u: Unit in gw.army.units:
			if u.country_id != c.id or not u.alive() or u.type == Unit.Type.FPV:
				continue
			n_all += 1
			if u.home != null and u.home.country_id == c.id:
				per[u.home.id] = int(per.get(u.home.id, 0)) + 1
			else:
				loose += 1
		var sea: int = gw.naval.aboard_n(c.id) if gw.get("naval") != null and gw.naval.has_method("aboard_n") else 0
		n_all += sea
		var rows2: Array = []
		var bs: Array = own(gw, c, Facility.Kind.BARRACKS)
		for f2: Facility in bs:
			var k2: int = int(per.get(f2.id, 0))
			var st2: String = state_of(gw, f2)
			rows2.append({"f": f2, "id": f2.id, "title": (Loc.t("Армия №%d") % f2.army_no) if f2.army_no > 0 else Loc.t("Казармы"), "near": nearest_city(gw, c, f2), 
				"level": 0, "state": st2, "state_text": state_text(gw, f2, st2), "why": "", "n": -1.0, "extra": Loc.t("бойцов %d") % k2, "icon": "icon_barracks"})
		var need: int = (n_all + 2) / 3
		if n_all > 0 or not rows2.is_empty():
			var g: Dictionary = {"key": "army", "name": Loc.t("Армия"), "icon": "icon_barracks", "kind": Facility.Kind.BARRACKS, 
				"n": float(need) * PER_MIN if n_all > 0 else 0.0, "rows": rows2, "note": Loc.t("бойцов %d · 1 еда на 3 бойцов за 10 с") % n_all}
			if loose + sea > 0:
				g["note"] = String(g["note"]) + Loc.t(" · в пути/на море %d") % (loose + sea)
			out.append(g)
			done["army"] = true
	elif eat == "aircraft":
		var rows3: Array = []
		var afs: Array = own(gw, c, Facility.Kind.AIRFIELD)
		var planes: int = 0
		for i3: int in afs.size():
			var af: Facility = afs[i3]
			var nb: int = gw.mil.air.based_at(af).size() if gw.mil.get("air") != null else 0
			planes += nb
			var st3: String = state_of(gw, af)
			rows3.append({"f": af, "id": af.id, "title": "%s №%d" % [Military.title_of(af.kind), i3 + 1], "near": nearest_city(gw, c, af), "level": 0, 
				"state": st3, "state_text": state_text(gw, af, st3), "why": "", "n": -1.0, "extra": Loc.t("самолётов %d") % nb, "icon": "icon_airfield"})
		if not rows3.is_empty():
			out.append({"key": "aircraft", "name": Loc.t("Авиация: заправка"), "icon": "icon_airfield", "kind": Facility.Kind.AIRFIELD, 
				"n": float(int(bo.get("aircraft", 0))), "rows": rows3, "note": Loc.t("самолётов %d · топливо берут на земле") % planes})
			done["aircraft"] = true

	var keys: Array = bo.keys()
	keys.sort_custom( func(a: Variant, b: Variant) -> bool: return int(bo[a]) > int(bo[b]))
	for key: Variant in keys:
		var ks: String = String(key)
		if done.has(ks) or int(bo[ks]) <= 0:
			continue
		var info: Array = SRC.get(ks, [String(Economy.STAT_NAMES.get(ks, ks)), "icon_info", -1])
		var g2: Dictionary = {"key": ks, "name": String(info[0]), "icon": String(info[1]), "kind": int(info[2]), "n": float(int(bo[ks])), "rows": []}
		if int(info[2]) >= 0 and ks != "export" and ks != "import":
			var fs2: Array = own(gw, c, int(info[2]))
			for i4: int in fs2.size():
				var f4: Facility = fs2[i4]
				var st4: String = state_of(gw, f4)
				(g2["rows"] as Array).append({"f": f4, "id": f4.id, "title": "%s №%d" % [Military.title_of(f4.kind), i4 + 1], "near": nearest_city(gw, c, f4), 
					"level": f4.level if Economy.kind_upgradable(f4.kind) else 0, "state": st4, "state_text": state_text(gw, f4, st4), "why": "", "n": -1.0, 
					"icon": Military.icon_of(f4.kind)})
		out.append(g2)
	out.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return float(a["n"]) > float(b["n"]))
	return out



static func fmt(v: float, signed: bool = true) -> String:
	var a: float = absf(v)
	var s: String = ("%d" % roundi(a)) if absf(a - roundf(a)) < 0.05 or a >= 10.0 else Loc.dec("%.1f" % a)
	if not signed:
		return s
	if v > 0.0001:
		return "+" + s
	if v < -0.0001:
		return "−" + s
	return s



static func build_yield(gw: GameWorld, c: Country, kind: int) -> String:
	var mul: float = 1.0 if c == null or c.is_player else GameConfig.ai_income_mul(c)
	match kind:
		Facility.Kind.FARM:
			return Loc.t("еда +%d/мин · доход +%d/мин") % [ceili(Economy.FARM_FOOD * 1.0) * 6, int(Economy.FARM_MONEY * mul) * 6]
		Facility.Kind.CIV_FACTORY:
			return Loc.t("товары +%d/мин · доход +%d/мин · нужно питание") % [ceili(Economy.CIV_GOODS * 1.0) * 6, int(Economy.CIV_MONEY * mul) * 6]
		Facility.Kind.MINE:
			return Loc.t("металл +%d · титан +%d · драгмет. +%d /мин — по залежи") % [int(Economy.MINE_RATE["metal"]) * 6, int(Economy.MINE_RATE["titanium"]) * 6, int(Economy.MINE_RATE["precious"]) * 6]
		Facility.Kind.OIL_RIG:
			return Loc.t("нефть +%d/мин") % (Economy.RIG_OIL * 6)
		Facility.Kind.SAWMILL:
			return Loc.t("дерево до +%d/мин — по лесу вокруг") % (Economy.SAW_WOOD_MAX * 6)
		Facility.Kind.REFINERY:
			var r: int = roundi(60.0 / Military.FUEL_DT)
			return Loc.t("нефть −%d → топливо +%d/мин · нужно питание") % [r, r]
		Facility.Kind.URANIUM_MINE:
			return Loc.t("уран +%s/мин · нужно питание") % fmt(Nuclear.U_MINE_RATE * PER_MIN, false)
		Facility.Kind.POWER_PLANT:
			return Loc.t("энергия +%d") % Military.PLANT_CAP
		Facility.Kind.SOLAR_FARM:
			return Loc.t("энергия +%d") % Military.SOLAR_FARM_CAP
		Facility.Kind.NUCLEAR_PLANT:
			return Loc.t("энергия +%d · уран −1 за %d с") % [Nuclear.NPP_CAP, int(Nuclear.FUEL_S)]
	return ""



static func next_per_min(gw: GameWorld, f: Facility) -> int:
	if f.level >= Economy.MAX_LEVEL:
		return -1
	var nm: float = float(Economy.LEVEL_MUL[f.level + 1])
	match f.kind:
		Facility.Kind.FARM:
			return ceili(Economy.FARM_FOOD * nm) * 6
		Facility.Kind.CIV_FACTORY:
			return ceili(Economy.CIV_GOODS * nm) * 6
		Facility.Kind.REFINERY:
			return (f.level + 1) * roundi(60.0 / Military.FUEL_DT)
		Facility.Kind.SAWMILL:
			var t: int = int((gw.econ._site.get(f, {}) as Dictionary).get("trees", 0))
			if t <= 0:
				t = gw.econ.count_trees(f.cell + f.size / 2, Economy.SAW_R, 2)
			return 0 if t <= 0 else ceili(float(mini(Economy.SAW_WOOD_MAX, 1 + t / 15)) * nm) * 6
	return -1
