extends "res://ui/hud/hud_ops.gd"



func _card(key: String, icon: String, title: String, sub: String, rows: bool, bars: bool, fac: bool) -> void :
	if key != "strike_hub" and ops_panel.get_child_count() > 1:
		for i in ops_panel.get_child_count():
			var oc: Control = ops_panel.get_child(i) as Control
			if oc != null and oc.visible != (i == 0):
				oc.visible = i == 0
	var fresh: bool = not ops_panel.visible or key != _ops_key
	ops_panel.visible = true
	ops_row.visible = rows
	if fresh and not key.begins_with("jet316"):
		_jet_row(false)
	fac_row.visible = fac
	if ops_comp != null and is_instance_valid(ops_comp) and not key.begins_with("army"):
		ops_comp.visible = false
		ops_foot.visible = false
	for b: Array in ops_bars:
		(b[0] as Control).visible = bars
	if not fac:
		_fac_sig = ""
		ops_detail.visible = false
	if ops_title.text != title:
		ops_title.text = title
	if key.begins_with("city"):
		ops_title.mouse_filter = Control.MOUSE_FILTER_STOP
		ops_title.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ops_title.tooltip_text = "Нажмите, чтобы переименовать город (F2)"
	else:
		ops_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ops_title.mouse_default_cursor_shape = Control.CURSOR_ARROW
		ops_title.tooltip_text = ""
	ops_sub.visible = sub != ""
	if ops_sub.text != sub:
		ops_sub.text = sub
	if fresh or ops_icon.texture == null:
		_ops_key = key
		UiKit.set_icon(ops_icon, icon if icon != "" else "icon_info", 32.0)
		var pnl: Control = ops_panel
		pnl.modulate.a = 0.0
		var tw: Tween = pnl.create_tween()
		tw.tween_property(pnl, "modulate:a", 1.0, 0.16)
		UiKit.snd("ui_open")


func show_plan(info: Dictionary, has_target: bool, count: int, route_mode: bool, _wp_n: int) -> void :
	var jet: bool = bool(info.get("jet", false))
	_card("plan_drone", "icon_jet_uav" if jet else "icon_launch", Loc.t("Пуск реактивных БПЛА") if jet else Loc.t("Пуск дронов"), Loc.t("Быстрые, дальние, взлетают с ВПП") if jet else Loc.t("Ударные БПЛА с вашего дронопорта"), true, false, true)
	ops_detail.visible = false
	var standing: bool = gw.mil.has_method("standing_of") and gw.player != null and bool(gw.mil.standing_of(gw.player.id).get("on", false))
	_fill_acts("plan_kinds", [
		_act("ДРОНЫ", "icon_launch", "plan_kind_0", true, 0 if jet else 1, "%d" % int(info.get("delta", 0))), 
		_act("РЕАКТИВН.", "icon_jet_uav", "plan_kind_1", true, 1 if jet else 0, "%d" % int(info.get("jets", 0))), 
		_act(Loc.t("АВТОПУСК\nВКЛ") if standing else Loc.t("АВТОПУСК\nВЫКЛ"), 
			"icon_route", "plan_standing", has_target or standing, 1 if standing else 0), 
		_act(Loc.t("УМНЫЕ БПЛА\nВКЛ") if gw.mil.has_method("smart_of") and gw.player != null and gw.mil.smart_of(gw.player.id) else Loc.t("УМНЫЕ БПЛА\nВЫКЛ"), 
			"icon_recon_scan", "smart_toggle", gw.mil.has_method("smart_of"), 1 if gw.mil.has_method("smart_of") and gw.player != null and gw.mil.smart_of(gw.player.id) else 0), 
		_act("СБРОС\nЦЕЛЕЙ", "icon_close", "plan_reset", has_target), 
	])
	var port: Facility = info["airfield"]
	var avail: int = int(info["available"])
	var ok: bool = false
	if port == null:
		_set_info("НЕТ ДРОНОПОРТА: ВОЕННОЕ › ДРОНОПОРТ", true)
	elif int(info["launchers"]) == 0:
		_set_info(Loc.t("НЕТ ВПП: ТАП ПО ДРОНОПОРТУ › ВПП") if jet else Loc.t("НЕТ ПУСКОВОЙ: ТАП ПО ДРОНОПОРТУ › РАМПА ИЛИ ВПП"), true)
	elif not has_target:
		_set_info(Loc.t("МАРШРУТ: ТАП ПО КАРТЕ = ТОЧКА") if route_mode else Loc.t("ТАП ПО КАРТЕ = ЦЕЛЬ"), false)
	else:
		var length: float = float(info["length"])
		var head: String = Loc.t("ЦЕЛЬ %.1f КМ · ПОЛЁТ %s\n") % [length / 1000.0, _mmss(Military.GROUND_ETA + length / (Military.JET_CRUISE if jet else Military.CRUISE))]
		if info.has("smart"):
			head += smart_line(info["smart"]) + "\n"
		if not bool(info["in_range"]):
			_set_info(head + Loc.t("ВНЕ ДАЛЬНОСТИ: МАКС %.1f КМ") % (float(info.get("range", Military.RANGE_PX)) / 1000.0), true)
		elif avail == 0:
			var nd: float = float(info["next_drone"])
			if nd >= 0.0:
				_set_info(head + Loc.t("ДРОН БУДЕТ ЧЕРЕЗ %s") % _mmss(nd), true)
			elif jet:
				_set_info(head + Loc.t("НЕТ РЕАКТИВНЫХ: ДРОННЫЙ ЗАВОД › ТИП «РЕАКТИВН.»"), true)
			elif bool(info["has_factory"]):
				_set_info(head + Loc.t("ЗАВОД ЖДЁТ: НУЖНЫ ДЕНЬГИ ИЛИ МЕСТО"), true)
			else:
				_set_info(head + Loc.t("НЕТ ДРОНОВ: ПОСТРОЙТЕ ДРОННЫЙ ЗАВОД"), true)
		else:
			var tip: String = Loc.t("ТАП = ТОЧКА, ТАП ПО ТОЧКЕ = УБРАТЬ") if route_mode else Loc.t("ГОТОВО %d · ТАП ПО ЦЕЛИ = +1, НОВАЯ ТОЧКА = ЕЩЁ ЦЕЛЬ") % avail
			_set_info(head + tip, false)
			ok = true
	ops_count.text = "x%d" % count
	ops_launch.disabled = not ok



func show_strike_multi(key: String, icon: String, title: String, sub: String, mp: Dictionary, n_targets: int, per: int) -> void :
	_card(key, icon, title, sub, true, false, false)
	show_multi(mp, n_targets, false, per, "РАКЕТ")
	if int(mp.get("available", 0)) == 0 and String(mp.get("why", "")) != "":
		_set_info(String(mp["why"]).to_upper(), true)


func show_missile_plan(info: Dictionary, has_target: bool, count: int) -> void :
	_card("plan_missile", "icon_target", "Ракетный удар", "Баллистические ракеты ОТРК", true, false, false)
	var ok: bool = false
	if not bool(info["has_tel"]):
		_set_info("НЕТ ОТРК: ВОЕННОЕ › ОТРК", true)
	elif not has_target:
		_set_info("ТАП ПО КАРТЕ = ЦЕЛЬ", false)
	else:
		var head: String = Loc.t("ЦЕЛЬ %.1f КМ · ПОЛЁТ %s\n") % [float(info["dist"]) / 1000.0, _mmss(float(info["flight"]))]
		if bool(info["too_close"]):
			_set_info(head + Loc.t("СЛИШКОМ БЛИЗКО: МИН %.1f КМ") % (Military.MISSILE_MIN / 1000.0), true)
		elif not bool(info["in_range"]):
			_set_info(head + Loc.t("ВНЕ ДАЛЬНОСТИ: МАКС %.1f КМ") % (Military.MISSILE_RANGE / 1000.0), true)
		elif int(info["available"]) == 0:
			_set_info(head + Loc.t("НЕТ РАКЕТ: ИДЁТ ПЕРЕЗАРЯДКА"), true)
		else:
			_set_info(head + Loc.t("РАКЕТ ГОТОВО %d") % int(info["available"]), false)
			ok = true
	ops_count.text = "x%d" % count
	ops_launch.disabled = not ok


func show_telemetry(d: Drone) -> void :
	var names: Dictionary = {Drone.State.PARKED: "НА СТОЯНКЕ", Drone.State.WAIT: "ОЧЕРЕДЬ НА ПУСК", Drone.State.TAXI: "К ПУСКОВОЙ", Drone.State.HOLD: "НА ПУСКОВОЙ", Drone.State.ROLL: "ВЗЛЁТ", Drone.State.BOOST: "СТАРТ С РАМПЫ", Drone.State.FLY: "ПОЛЁТ", Drone.State.DIVE: "ПИКИРОВАНИЕ", Drone.State.DONE: "ЦЕЛЬ ПОРАЖЕНА"}
	var st_name: String = String(names.get(d.state, ""))
	if d.state == Drone.State.DONE and d.end_reason == Drone.End.CRASH:
		st_name = Loc.t("УПАЛ: НЕТ ТОПЛИВА")
	elif d.state == Drone.State.DONE and d.end_reason == Drone.End.DESTROYED:
		st_name = Loc.t("УНИЧТОЖЕН")
	var cr: bool = d.kind == 1
	var dname: String = Loc.t("Крылатая ракета") if cr else (Loc.t("Реактивный БПЛА") if d.kind == 2 else Loc.t("Ударный БПЛА"))
	_card("drone%d" % d.id, "icon_cr_launch" if cr else ("icon_jet_uav" if d.kind == 2 else "icon_launch"), "%s %s" % [dname, Loc.no(d.id)], st_name, false, true, false)
	var rem: float = 0.0 if d.state == Drone.State.DONE else d.remaining_len()
	var eta: float = rem / maxf(d.speed, Military.CRUISE)
	if d.state < Drone.State.BOOST:
		eta += Military.GROUND_ETA
	_set_info(Loc.t("ДО ЦЕЛИ %.1f КМ · %s") % [rem / 1000.0, _mmss(eta)], false)
	_set_bar(0, clampf(d.flown / maxf(d.route_len, 1.0), 0.0, 1.0), "res_drone")
	_set_bar(1, 1.0 - d.flown / maxf(d.range_px, 1.0), "res_fuel")


func show_missile_telemetry(m: Missile) -> void :
	var st: String = Loc.t("ЗАЖИГАНИЕ")
	if m.state == Missile.State.DONE:
		st = Loc.t("ЦЕЛЬ ПОРАЖЕНА")
	elif m.state == Missile.State.FLIGHT:
		st = Loc.t("ПИКИРОВАНИЕ") if m.u() > 0.75 else (Loc.t("АПОГЕЙ") if absf(m.u() - 0.5) < 0.08 else Loc.t("ПОЛЁТ"))
	_card("missile%d" % m.id, "icon_m_hyper" if m.hyper else "icon_m_ballistic", "%s %s" % [Loc.t("Гиперзвуковая ракета") if m.hyper else Loc.t("Баллистическая ракета"), Loc.no(m.id)], st, false, true, false)
	_set_info(Loc.t("ВЫСОТА %d КМ · М %.1f · %s") % [roundi(m.alt_km()), 0.0 if m.state == Missile.State.DONE else m.mach(), _mmss(m.time_left())], false)
	_set_bar(0, m.u(), "res_missile")
	_set_bar(1, m.alt_km() / maxf(m.apex_km, 1.0), "res_level")


func _fac_icon(kind: int) -> String:
	for k: String in BUILD_KIND_OF:
		if int(BUILD_KIND_OF[k]) == kind:
			return key_icon(k)
	return {Facility.Kind.DP_RAMP: "icon_ramp", Facility.Kind.DP_RUNWAY: "icon_dprunway", Facility.Kind.DP_STORE: "icon_store", Facility.Kind.SOLAR: "icon_solar", Facility.Kind.TRENCH_V: "icon_trench", Facility.Kind.TEETH_V: "icon_teeth"}.get(kind, "icon_info")



func show_facility(f: Facility, mil: Military, player: Country) -> void :
	# Mod hooks draw their custom cards after the normal HUD update. Skip the
	# vanilla card for their facilities, otherwise it is replaced every frame:
	# buttons never stay under the pointer and the card-open sound repeats.
	if f != null and (f.get_meta("is_airborne_base", false) or f.get_meta("is_tank_factory", false)
		or f.get_meta("is_vdv_hq", false) or f.get_meta("is_nuclear_silo", false)
		or f.get_meta("is_thermo", false) or f.get_meta("is_iskander_tel", false)
		or f.army_build == "iskander_tel" or f.army_build == "thermo_battery"
		or f.get_meta("mod_facility", false)):
		return
	var alive: bool = mil.alive(f)
	_card("fac%d" % f.id, _fac_icon(f.kind), (Loc.t("Казармы армии №%d") % f.army_no) if f.kind == Facility.Kind.BARRACKS and f.army_no > 0 else Loc.t(Military.title_of(f.kind)), "" if f.kind == Facility.Kind.BARRACKS else _sentence(String(Military.PURPOSE.get(f.kind, ""))), false, 
		alive and gw.econ.has_method("deep_card") and Economy.is_deep(f.kind) and not f.deposit.is_empty(), true)
	var info: String = ""
	var detail: String = ""
	var acts: Array = []
	var bar_lite: bool = false
	if f.restore_t > 0.0:
		info = (Loc.t("СТРОИТСЯ %s") if mil.get("constructing") is Dictionary and (mil.constructing as Dictionary).has(f.id) else Loc.t("ВОССТАНОВЛЕНИЕ %s")) % _mmss(f.restore_t)
	elif not alive:
		info = Loc.t("РАЗРУШЕН")
		var rc: int = Military.restore_cost(f)
		if mil.can_restore(f):
			acts.append(_act(Loc.t("ВОССТАН.\n%d") % rc, "icon_restore", "fac_restore", player.money >= rc))
	else:
		match f.kind:
			Facility.Kind.POLICE_STATION:
				var count: int = gw.army.police_count(f)
				info = "МАШИНЫ %d/4 · %s" % [count, "ПАТРУЛЬ" if f.police_patrol else "ОЖИДАНИЕ"]
				detail = "Патрулируют свою территорию и защищаются от войск стран, с которыми идёт война."
				acts.append(_act("ОСТАНОВИТЬ" if f.police_patrol else "ПАТРУЛЬ", "icon_barracks", "police_patrol", true))
			Facility.Kind.DRONE_PORT:
				var cap: int = 0
				for k in f.spots.size():
					if mil.alive(f.spot_owner[k] as Facility):
						cap += 1
				info = Loc.t("УРОВЕНЬ %d · ДРОНОВ %d/%d · ПУСКОВЫХ %d") % [mil.port_level(f), mil.parked_at(f), cap, mil.port_launchers(f).size()]
				acts.append(_act(Loc.t("РАМПА\n%d") % Military.COST_RAMP, "icon_ramp", "mod_ramp", player.money >= Military.COST_RAMP))
				acts.append(_act(Loc.t("ВПП\n%d") % Military.COST_DP_RUNWAY, "icon_dprunway", "mod_runway", player.money >= Military.COST_DP_RUNWAY))
				acts.append(_act(Loc.t("СКЛАД\n%d") % Military.COST_STORE, "icon_store", "mod_store", player.money >= Military.COST_STORE))
				_solar_act(f, mil, player, acts)
				detail = Loc.t("Рампа — быстрый пуск с ускорителем, ВПП — взлёт с разбега, склад — +4 места.")
			Facility.Kind.TEL:
				var stock: int = player.missile_stock[Military.MT_BALLISTIC]
				if f.moving:
					info = Loc.t("В ПУТИ · РАКЕТ %d/2") % f.missiles
				else:
					var rl: String = Loc.t(" · ЗАРЯЖАНИЕ %s") % _mmss(f.reload_t) if f.reload_t > 0.0 else ""
					info = Loc.t("РАКЕТ %d/2 · НА СКЛАДЕ %d%s") % [f.missiles, stock, rl]
				acts.append(_act("УДАР", "icon_target", "missile", f.missiles > 0 and not f.moving))
				detail = Loc.t("Ракеты делает ракетный завод (тип «Баллист.»). Тап по своей земле — переезд.")
			Facility.Kind.MISSILE_FACTORY:
				var t: int = f.prod_type
				var st: String = Loc.t("ГОТОВО ЧЕРЕЗ %s") % _mmss(float(Military.MT_TIME[t]) - f.prod_t) if f.producing else Loc.t("ОЖИДАНИЕ: НУЖНЫ ДЕНЬГИ ИЛИ МЕСТО")
				if not mil.has_carrier(player, t):
					st = Loc.t("НЕТ НОСИТЕЛЯ: НУЖНА АВИАЦИЯ")
				if not mil.has_power(f):
					st = Loc.t("НЕТ ПИТАНИЯ — ПРОИЗВОДСТВО СТОИТ")
				info = Loc.t("ДЕЛАЕТ: %s · %s") % [Loc.t(String(Military.MT_NAMES[t])), st]
				for k in Military.MT_NAMES.size():
					acts.append(_act(String(MT_SHORT[k]), String(Military.MT_ICONS[k]), "mtype_%d" % k, bool(Military.MT_READY[k]), 1 if k == t else 0, "%d" % player.missile_stock[k]))
				_solar_act(f, mil, player, acts)
				detail = Loc.t("%s — %s. Цена %d, %d с, на складе %d из %d. Цифра на кнопке — запас на складе. «+Солнце» — резервное питание завода.") % [_sentence(Loc.t(String(Military.MT_NAMES[t]))), String(MT_PURPOSE[t]), int(Military.MT_COST[t]), int(Military.MT_TIME[t]), player.missile_stock[t], int(Military.MT_CAP[t])]
			Facility.Kind.REFINERY:
				info = Loc.t("%s · ПРОДАНО НА %d") % [_rate_line(f, player), player.fuel_sold]
				if player.oil <= 0:
					info += Loc.t("\nНЕТ НЕФТИ: НЕФТЕВЫШКА ИЛИ ПОКУПКА")
				detail = Loc.t("Перерабатывает нефть в топливо, топливо продаётся само по мировой цене. ") + _upgrade_act(f, player, acts)
				_solar_act(f, mil, player, acts)
			Facility.Kind.POWER_PLANT:
				info = Loc.t("СЕТЬ: %d / %d (+%d ОТ ЭТОЙ ТЭЦ)") % [player.power_use, player.power_cap, Military.PLANT_CAP]
			Facility.Kind.NUCLEAR_PLANT:
				info = Loc.t("%s\nСЕТЬ %d / %d · УРАН %d (НА %d МИН)") % [Nuclear.status(gw, f), player.power_use, player.power_cap, player.uranium, int(Nuclear.fuel_minutes(gw, player))]
				if mil.can_restore(f):
					var nrc: int = Military.restore_cost(f) + mil.restore_buy(f, player)
					acts.append(_act(Loc.t("РЕМОНТ\n%d") % nrc, "icon_restore", "fac_restore", player.money >= nrc))
				acts.append(_act("РЫНОК", "icon_relations", "trade", true))
				detail = Loc.t("Сетки и бетон АЭС не защищают: держите рядом ЗРК и ПРО. Корпус выдерживает 2 удара дронов или КР (−25 %% мощности каждый), баллистика рушит его сразу. Без урана (1 на %d с) АЭС стоит. Разрушена — блэкаут, ремонт %d с; ремонт целой АЭС останавливает её на 90 с.") % [int(Nuclear.FUEL_S), int(Military.CRIT_RESTORE[Facility.Kind.NUCLEAR_PLANT])]
			Facility.Kind.SOLAR:
				info = Loc.t("РЕЗЕРВ ДЛЯ: %s") % (Loc.t(Military.title_of(f.parent.kind)).to_upper() if f.parent != null else "-")
			Facility.Kind.AIRFIELD:
				var based: Array[Aircraft] = mil.air.based_at(f)
				var nb: int = 0
				for ac: Aircraft in based:
					if ac.type == Aircraft.Type.BOMBER:
						nb += 1
				info = Loc.t("САМОЛЁТОВ %d/%d · БОМБАРДИРОВЩИК %d/1 · ТИТАН %d") % [based.size() - nb, Air.AIR_CAP, nb, player.titanium]
				var anames: Array = ["БОМБАРД.", "ИСТРЕБ.", "ВЕРТОЛЁТ", "ШТУРМОВИК"]
				for t2: int in [Aircraft.Type.BOMBER, Aircraft.Type.FIGHTER, Aircraft.Type.HELI, Aircraft.Type.ATTACK]:
					var cost: int = int(Air.SPEC[t2]["cost"])
					acts.append(_act("%s\n%d" % [anames[t2], cost], ["icon_bomber", "icon_fighter", "icon_heli", "icon_attack_jet"][t2], ["buy_bomber", "buy_fighter", "buy_heli", "buy_attack"][t2], player.money >= cost and player.titanium >= int(Air.TITANIUM.get(t2, 0))))
				detail = Loc.t("Бомбардировщик несёт крылатые ракеты, истребитель — ракеты «воздух-воздух» и подвес, вертолёт патрулирует. Штурмовик: 4 КАБ (делает ракетный завод), НАРы, пушка, 2 ракеты «воздух-воздух». Нужен титан.")
			Facility.Kind.DRONE_FACTORY:
				var jt: bool = f.prod_type == 1
				var cost_d: Dictionary = mil.drone_cost(false)
				var cost_j: Dictionary = mil.drone_cost(true)
				var nm_now: String = Loc.t("РЕАКТИВНЫЙ") if f.prod_jet else Loc.t("ДРОН")
				var ttl: float = Military.JET_PROD_TIME if f.prod_jet else Military.PROD_TIME
				info = Loc.t("%s ЧЕРЕЗ %s") % [nm_now, _mmss(ttl - f.prod_t)] if f.producing else Loc.t("ОЖИДАНИЕ")
				if not f.producing:
					var miss: String = player.missing_res(cost_j if jt else cost_d)
					if miss != "":
						info = Loc.t("НЕ ХВАТАЕТ: %s") % miss.to_upper()
					elif mil.stock_count(player.id) >= mil.drone_capacity(player.id):
						info = Loc.t("НЕТ МЕСТА: ДРОНОПОРТ ЗАПОЛНЕН (+СКЛАД ИЛИ ДРОНОПОРТ)")
				if not mil.has_power(f):
					info = Loc.t("НЕТ ПИТАНИЯ — ПРОИЗВОДСТВО СТОИТ")
				info += Loc.t(" · МЕСТ %d/%d") % [mil.stock_count(player.id), mil.drone_capacity(player.id)]
				acts.append(_act(Loc.t("ДРОН\n%d") % int(cost_d["money"]), "icon_launch", "dtype_0", true, 0 if jt else 1))
				acts.append(_act(Loc.t("РЕАКТИВН.\n%d") % int(cost_j["money"]), "icon_jet_uav", "dtype_1", true, 1 if jt else 0))
				_solar_act(f, mil, player, acts)
				detail = Loc.t("Дрон — дешёвый, медленный, взлетает с рампы. Реактивный — в 2,5 раза быстрее и дальше, бьёт сильнее, не по зубам пулемётам и дронам-перехватчикам, но нужна ВПП дронопорта.%s") % ((Loc.t("\nРесурсы: ") + _res_line(cost_j if jt else cost_d)) if (cost_j if jt else cost_d).size() > 1 else "")
			Facility.Kind.DP_RAMP:
				var left: float = f.ready_at - gw.game_time
				info = Loc.t("ПЕРЕЗАРЯДКА %s") % _mmss(left) if left > 0.0 else Loc.t("ГОТОВА К ПУСКУ")
			Facility.Kind.DP_RUNWAY:
				info = Loc.t("РЕМОНТ %s") % _mmss(f.repair_t) if not f.craters.is_empty() else Loc.t("ГОТОВА К ВЗЛЁТУ")
			Facility.Kind.DP_STORE:
				info = Loc.t("+4 МЕСТА ДЛЯ ДРОНОВ")
			Facility.Kind.FARM:
				info = _rate_line(f, player)
				if gw.econ.has_method("can_upgrade") and gw.econ.can_upgrade(f):
					detail = _upgrade_act(f, player, acts)
			Facility.Kind.CIV_FACTORY:
				info = _rate_line(f, player)
				acts.append(_act("ТОРГОВЛЯ", "icon_trade", "trade", true))
				if gw.econ.has_method("can_upgrade") and gw.econ.can_upgrade(f):
					detail = _upgrade_act(f, player, acts)
			Facility.Kind.URANIUM_MINE:
				var usi: Dictionary = gw.econ.site_info(f)
				info = Loc.t("%s · ЗАПАС %s") % [_rate_line(f, player).get_slice("\n", 0), Economy.reserve_text(int(usi["left"]), int(usi["max"]))]
				if String(usi["status"]) != "":
					info += "\n" + String(usi["status"])
				if not mil.has_power(f):
					info = Loc.t("НЕТ ПИТАНИЯ — ДОБЫЧА СТОИТ")
				acts.append(_act("РЫНОК", "icon_relations", "trade", true))
				detail = Loc.t("Уран — топливо АЭС (1 на %d с работы, %d на постройку). Излишки дорого продаются: рынок, соседи, порт.") % [int(Nuclear.FUEL_S), int(Economy.BUILD_COST[Facility.Kind.NUCLEAR_PLANT]["uranium"])]
			Facility.Kind.MINE, Facility.Kind.SAWMILL, Facility.Kind.OIL_RIG:
				var si: Dictionary = gw.econ.site_info(f)
				var rk: String = String(si["res"])
				info = _rate_line(f, player).get_slice("\n", 0)
				if int(si["left"]) >= 0:
					info += Loc.t(" · ЗАПАС %s") % Economy.reserve_text(int(si["left"]), int(si["max"]))
				if f.kind == Facility.Kind.SAWMILL:
					info += Loc.t(" · ДЕРЕВЬЕВ %d") % int(si["trees"])
				if String(si["status"]) != "":
					info += "\n" + String(si["status"])
				if not mil.has_power(f):
					info = Loc.t("НЕТ ПИТАНИЯ — ДОБЫЧА СТОИТ")
				if f.kind != Facility.Kind.SAWMILL and gw.econ.has_method("deep_card"):
					detail = _deep_card(f, player, acts)
				else:
					detail = _upgrade_act(f, player, acts)
					if si.has("next_rate") and int(si["next_rate"]) > int(si["rate"]):
						detail += Loc.t(" Добыча станет +%d/мин.") % (int(si["next_rate"]) * 6)
			Facility.Kind.PORT, Facility.Kind.PORT_CRANE:
				var pf: Facility = f if f.kind == Facility.Kind.PORT else (f.parent if f.parent != null else f)
				var pi: Dictionary = gw.econ.ports.info(pf)
				info = Loc.t("КОРАБЛЕЙ %d/%d · КРАНОВ %d · КОНТЕЙНЕРОВ %d%s") % [int(pi["ships"]), int(pi["ships_max"]), int(pi["cranes"]), int(pi["containers"]), "" if bool(pi["ocean"]) else Loc.t(" · ЗАМКНУТОЕ МОРЕ")]
				info += Loc.t("\nЭКСПОРТ %s · ВЫРУЧКА %d") % [Loc.t("ВКЛ") if bool(pi["export_on"]) else Loc.t("ВЫКЛ"), int(pi["exported"])]
				if pi.has("segments"):
					info += Loc.t("\nПРИЧАЛЫ %d/%d") % [int(pi["segments"]), int(pi.get("segments_max", 8))]
					var nsa: int = int(pi.get("next_segment_at", -1))
					if nsa > 0:

						info += Loc.t(" · ПРИЧАЛ СТРОИТСЯ") if int(pi.get("trade_value", 0)) >= nsa else Loc.t(" · НОВЫЙ ПРИ ОБОРОТЕ %d") % nsa
				if f.kind == Facility.Kind.PORT:
					var cc: Dictionary = Economy.build_cost(Facility.Kind.PORT_CRANE)
					acts.append(_act(Loc.t("КРАН\n%d") % int(cc["money"]), "icon_port_crane", "mod_crane", player.has_res(cc) and int(pi["cranes"]) < 3))
					acts.append(_act("ЭКСПОРТ", "icon_trade", "port_export", true, 1 if bool(pi["export_on"]) else 0))
					if gw.get("naval") != null:
						var npi: Dictionary = gw.naval.port_info(f)
						acts.append(_act(Loc.t("КОЛОНИЯ\n%d") % int((npi.get("cost", {}) as Dictionary).get("money", 0)), "icon_ship" if UiKit.has("icon_ship") else "icon_port", "expedition", String(npi.get("ready", "")) == ""))
						info += Loc.t("\nКОЛОНИИ %d/%d%s") % [int(npi.get("colonies", 0)), int(npi.get("cap", 1)), (" · " + String(npi.get("ready", "")).to_upper()) if String(npi.get("ready", "")) != "" else ""]
					acts.append(_act("РЫНОК", "icon_relations", "trade", true))
				detail = Loc.t("Корабли сами продают излишки и привозят нехватку. Кран: +1 причал, +10 груза.")
			Facility.Kind.BARRACKS:

				var ab: Dictionary = gw.army.army_brief(f) if gw.army.has_method("army_brief") else {}
				var ai: Dictionary = gw.army.army_info(f)
				var stop: bool = f.prod_type == 3
				var n: int = int(ab.get("n", ai["n"]))
				var op: Dictionary = gw.ops.of(f) if gw.get("ops") != null else {}
				var no: int = int(ab.get("no", ai["no"]))
				var stn: int = gw.ops.stance_of(f) if gw.ops.has_method("stance_of") else 0
				info = "%s %s · %d/%d · %s" % [Loc.no(no) if no > 0 else Loc.t("НОВАЯ"), String(ab.get("build_name", ai["name"])), n, int(ab.get("cap", ai["cap"])), String(Operations.AutoCmd.STANCE_NAMES[stn])]
				var doing: String = String(ab.get("order_text", ""))
				if not op.is_empty():
					doing = "%s: %s" % [String(op.get("name", "")), String(op.get("state_text", ""))]
				if doing == "" and n > 0:
					doing = String(ai["state"])
				if doing != "":
					info += "\n" + doing
				var land: Dictionary = gw.naval.landing_info(f) if gw.get("naval") != null and gw.naval.has_method("landing_info") else {}
				if String(land.get("line", "")) != "":
					info += Loc.t("\nДЕСАНТ: ") + String(land["line"])
				detail = Loc.t("НАБОР ОСТАНОВЛЕН") if stop else String(ab.get("refill_text", ""))
				acts.append(_act(Loc.t("АРМИЯ №%d") % no if no > 0 else Loc.t("АРМИЯ"), String(ab.get("build_icon", "icon_infantry")) if UiKit.has(String(ab.get("build_icon", ""))) else "icon_infantry", "army_card", true))
				if not _tut_on():


					info = Loc.t("АРМИЯ №%d · %s · %d/%d") % [no, String(ab.get("build_name", ai["name"])).to_upper(), n, int(ab.get("cap", ai["cap"]))] if no > 0 else Loc.t("АРМИЯ ФОРМИРУЕТСЯ · %d/%d") % [n, int(ab.get("cap", ai["cap"]))]
					acts.append(_act("ЕЩЁ…", "icon_menu", "build_pick", true))
					bar_lite = true
				else:
					acts.append(_act("ДВИЖЕНИЕ", "icon_op_operation", "operation", n > 0))
					if land.get("pos") is Vector2:
						acts.append(_act("К ЛОДКАМ", "icon_ship" if UiKit.has("icon_ship") else "icon_port", "to_boats", true))
					else:
						acts.append(_act("ЗАНЯТЬ\nОКОПЫ", "icon_trench", "garrison", n > 0))
					if not op.is_empty():
						acts.append(_act("ОТМЕНИТЬ", "icon_close", "op_cancel", true))
					else:
						acts.append(_act("ОТХОД", "icon_op_retreat", "op_retreat", n > 0))
					if gw.ops.has_method("stance_of"):
						acts.append(_act(Loc.t("РЕЖИМ:\n") + String(Operations.AutoCmd.STANCE_NAMES[stn]), "icon_move" if stn == 0 else String(Operations.AutoCmd.STANCE_ICONS[stn]), "stance_cycle", true, 1 if stn > 0 else 0))
					acts.append(_act("ЕЩЁ…", "icon_menu", "build_pick", true))
			Facility.Kind.AD_MFG, Facility.Kind.AD_SPAAG, Facility.Kind.AD_SAM, Facility.Kind.AD_PATRIOT, Facility.Kind.AD_INT:
				var sp: Dictionary = Defense.SPEC[f.kind]
				var r: String = Loc.t("РАДИУС %d М") % int(float(sp["range"]))
				var ms: Dictionary = gw.defense.site_state(f)
				r += Loc.t(" · ЗАРЯД %d/%d") % [int(ms["left"]), int(ms["cap"])]
				r += Loc.t(" · ВЫСТРЕЛ: РАКЕТА СО СКЛАДА") if bool(ms["stock"]) else Loc.t(" · ВЫСТРЕЛ %d") % int(ms["shot_cost"])
				if float(sp["range"]) > float(sp["detect"]) and not gw.defense.covered(f.country_id, f.center_px()):
					r += Loc.t(" · НУЖНА РЛС")
				info = r + Loc.t("\nВ МИРЕ: САМОЛЁТЫ — ПОСЛЕ %d М ВГЛУБЬ") % int(Defense.PEACE_DEPTH)
				if player != null and f.country_id == player.id and gw.defense.has_method("preset_of"):
					acts.append(_act(Loc.t("ЦЕЛИ ПВО\n%s") % String(AD_PRESET_SHORT.get(gw.defense.preset_of(player), "")), "u335_ad_rules", "ad_rules", true))
			Facility.Kind.TRENCH_H, Facility.Kind.DUGOUT:
				var occ: Array[Unit] = gw.army.occupants(f)
				var cap2: int = gw.army.capacity(f)
				var inn: int = 0
				for u2: Unit in occ:
					if u2.entrenched:
						inn += 1
				info = Loc.t("ЗАНЯТО %d/%d · ИДУТ %d · ЗАЩИТА x3") % [inn, cap2, occ.size() - inn]
				if mil.has_method("is_built") and not mil.is_built(f):
					info = Loc.t("СТРОИТСЯ %d%% · ЕЩЁ %d С · ") % [roundi(float(mil.dig_progress(f)) * 100.0), ceili(float(mil.dig_eta(f)))] + info
				if f.is_line():
					info += Loc.t(" · %d М") % (f.cells.size() * GameWorld.CELL)
				acts.append(_act("ЗАНЯТЬ", "icon_occupy", "occupy", occ.size() < cap2))
				acts.append(_act("ОСТАВИТЬ", "", "leave", occ.size() > 0))
			Facility.Kind.TEETH_H:
				var hp: float = 0.0
				for c2: Vector2i in f.cells:
					hp += float(f.cell_hp.get(c2, Military.TEETH_HP))
				info = Loc.t("%d М · ПРОЧНОСТЬ %d%% · ТЕХНИКА НЕ ПРОЙДЁТ") % [f.cells.size() * GameWorld.CELL, int(100.0 * hp / maxf(1.0, Military.TEETH_HP * f.cells.size()))]
			Facility.Kind.COASTAL_ASM:
				info = Loc.t("РЛС %d М · ПУСК %d М · ПКР %d/%d") % [int(Navy.COAST_DETECT), int(Navy.COAST_RANGE), f.ammo, Navy.COAST_AMMO]
				if f.ammo < Navy.COAST_AMMO:
					info += Loc.t(" · +1 ЧЕРЕЗ %d С") % ceili(maxf(0.0, Navy.COAST_RELOAD - f.reload_t))
				info += Loc.t("\nБЬЁТ ТОЛЬКО ПО КОРАБЛЯМ СТРАН В ВОЙНЕ")
			Facility.Kind.AD_RADAR:
				info = (Loc.t("ОБЗОР %d М: ПВО ВИДИТ ДАЛЬШЕ") % int(Defense.RADAR_R)) if mil.has_power(f) else Loc.t("НЕТ ПИТАНИЯ — РЛС ОТКЛЮЧЕНА")
			Facility.Kind.AD_EW:
				info = (Loc.t("ПОДАВЛЕНИЕ %d М: ДРОНЫ И FPV") % int(Defense.EW_R)) if mil.has_power(f) else Loc.t("НЕТ ПИТАНИЯ — РЭБ ОТКЛЮЧЕН")
	if alive and player != null and f.country_id == player.id:
		var n335: String = ArmyBudget.site_line(gw, f)
		if n335 != "":
			info = n335 + ("" if info == "" else "\n" + info)
	if alive and f.kind != Facility.Kind.BARRACKS and mil.has_method("can_halt") and mil.can_halt(f):
		var halted: bool = bool(f.get("halted"))
		acts.append(_act(Loc.t("ПУСК", "production") if halted else Loc.t("ПАУЗА\nЦЕХА"), 
			"icon_play" if halted else "icon_halt", "fac_halt", true, 1 if halted else 0))
		if halted:
			info = Loc.t("ПАУЗА · ПРОИЗВОДСТВО ОСТАНОВЛЕНО") + ("" if info == "" else " · " + info)
	if alive and gw.get("protect") != null and player != null and f.country_id == player.id and gw.protect.eligible(f):
		_protect_acts(f, player, acts)
		var pl: String = gw.protect.card_line(f)
		if pl != "":
			info += ("\n" if info != "" else "") + pl
	if player != null and f.country_id == player.id and mil.has_method("demolish_why") and not bar_lite:

		var dref: int = mil.demolish_refund(f)
		var dact: Dictionary = _act(Loc.t("РАЗРУШИТЬ") + ("\n+%d" % dref if dref > 0 else ""), "icon_demolish" if UiKit.has("icon_demolish") else "icon_close", "fac_demolish", mil.demolish_why(player, f) == "")
		dact["red"] = true
		acts.append(dact)
	_set_info(info, not alive)
	ops_detail.visible = detail != ""
	if ops_detail.text != detail:
		ops_detail.text = detail
	_fill_acts("fac%d" % f.id, acts)


func _army_rows() -> void :
	if ops_comp != null and is_instance_valid(ops_comp):
		return
	var vb: VBoxContainer = ops_panel.get_child(0) as VBoxContainer
	ops_comp = HFlowContainer.new()
	ops_comp.add_theme_constant_override("h_separation", 8)
	ops_comp.add_theme_constant_override("v_separation", 2)
	ops_comp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(ops_comp)
	vb.move_child(ops_comp, 1)
	ops_foot = HBoxContainer.new()
	ops_foot.add_theme_constant_override("separation", 6)
	vb.add_child(ops_foot)
	vb.move_child(ops_foot, fac_row.get_index() + 1)
	_foot_l = UiKit.lbl("", 10, UiKit.MUTED, 1)
	_foot_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_foot_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_foot_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ops_foot.add_child(_foot_l)
	var bb: Button = UiKit.big("КАЗАРМЫ", "stone", "icon_barracks", 44.0, 10)
	bb.custom_minimum_size = Vector2(112, 44)
	bb.pressed.connect( func() -> void : action.emit("army_barracks"))
	HoldTip.tip(bb, "КАЗАРМЫ — здание этой армии: сборка, пополнение, снос")
	ops_foot.add_child(bb)


func show_army(f: Facility, mil: Military, player: Country) -> void :
	_army_rows()
	var ab: Dictionary = gw.army.army_brief(f)
	var no: int = int(ab.get("no", f.army_no))
	var g: Dictionary = ArmyGroups303.group_of(gw, player.id, f.id) if player != null else {}
	var sub: String = Loc.t("БЕЗ ГРУППЫ")
	if not g.is_empty():
		var gt: String = Loc.gtag(int(g["id"]), String(g["name"]))
		sub = gt if not gt.contains("·") else Loc.t("ГРУППА %d·%s") % [int(g["id"]), gt.substr(gt.find("·") + 1)]
	var bic: String = String(ab.get("build_icon", ""))
	_card("army%d" % f.id, bic if bic != "" and UiKit.has(bic) else "icon_barracks", Loc.t("АРМИЯ №%d · %s") % [no, String(ab.get("build_name", "")).to_upper()], sub, false, false, true)
	ops_comp.visible = true
	ops_foot.visible = true
	var n: int = int(ab.get("n", 0))
	var hpf: float = float(ab.get("hp_frac", 0.0))

	var comp: Array = ab.get("comp", [])
	var sig: String = "%d|" % f.id
	for e: Dictionary in comp:
		sig += "%s:%d/%d;" % [e["icon"], int(e["have"]), int(e["want"])]
	sig += "|%d/%d|%d" % [n, int(ab.get("cap", 12)), roundi(hpf * 100.0)]
	if sig != _comp_sig:
		_comp_sig = sig
		for c in ops_comp.get_children():
			c.queue_free()
		for e2: Dictionary in comp:
			var cell: = HBoxContainer.new()
			cell.add_theme_constant_override("separation", 2)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ic: TextureRect = UiKit.icon_rect(String(e2["icon"]), 16.0)
			if int(e2["have"]) == 0:
				ic.modulate = Color(1, 1, 1, 0.45)
			cell.add_child(ic)
			var cl: Label = UiKit.lbl("%d/%d" % [int(e2["have"]), int(e2["want"])], 11, UiKit.TEXT if int(e2["have"]) >= int(e2["want"]) else UiKit.GOLD, 2, 2)
			cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell.add_child(cl)
			HoldTip.tip(cell, Loc.t("%s: %d из %d") % [String(e2["type_name"]).capitalize(), int(e2["have"]), int(e2["want"])])
			ops_comp.add_child(cell)
		var tl: Label = UiKit.lbl(Loc.t("%d/%d · СИЛА %d%%") % [n, int(ab.get("cap", 12)), roundi(hpf * 100.0)], 10, UiKit.GREEN if hpf >= 0.75 else (UiKit.GOLD if hpf >= 0.4 else UiKit.RED), 2, 2)
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ops_comp.add_child(tl)

	var op: Dictionary = gw.ops.of(f) if gw.get("ops") != null else {}
	var doing: String = String(ab.get("order_text", ""))
	if not op.is_empty():
		doing = "%s: %s" % [String(op.get("name", "")), String(op.get("state_text", ""))]
	if doing == "" and n > 0:
		doing = String(ab.get("state", ""))
	var info: String = Loc.t("СЕЙЧАС: ") + (doing if doing != "" else Loc.t("нет бойцов"))
	var posts: int = int(ab.get("posts", 0))
	var foot: int = 0
	for e3: Dictionary in comp:
		if int(e3["type"]) in [Unit.Type.INFANTRY, Unit.Type.ATGM, Unit.Type.ASSAULT]:
			foot += int(e3["have"])
	foot = maxi(foot, posts)
	if posts > 0:
		info += Loc.t("\nВ ОКОПАХ: %d/%d") % [posts, foot]
	var land: Dictionary = ab.get("landing", {})
	if String(land.get("line", "")) != "":
		info += Loc.t("\nДЕСАНТ: ") + String(land["line"])
	var sup335: String = ArmyBudget.army_line(gw, f)
	if sup335 != "":
		info += "\n" + sup335
	_set_info(info, false)
	ops_detail.visible = false
	var stn: int = gw.ops.stance_of(f) if gw.ops.has_method("stance_of") else 0
	var acts: Array = []
	acts.append(_act("ДВИЖЕНИЕ", "icon_op_operation", "operation", n > 0))
	if land.get("pos") is Vector2:
		acts.append(_act("К ЛОДКАМ", "icon_ship" if UiKit.has("icon_ship") else "icon_port", "to_boats", true))
	elif posts > 0 and posts * 2 >= foot:
		var ta: Dictionary = _act("ИЗ\nОКОПОВ", "icon_occupy", "army_trench_out", true)
		ta["flip"] = true
		acts.append(ta)
	else:
		acts.append(_act("В ОКОПЫ", "icon_occupy", "army_trench_in", n > 0))
	if not op.is_empty():
		acts.append(_act("ОТМЕНИТЬ", "icon_close", "op_cancel", true))
	else:
		acts.append(_act("ОТХОД", "icon_op_retreat", "op_retreat", n > 0))
	acts.append(_act(Loc.t("РЕЖИМ:\n") + String(Operations.AutoCmd.STANCE_NAMES[stn]), "icon_move" if stn == 0 else String(Operations.AutoCmd.STANCE_ICONS[stn]), "stance_cycle", true, 1 if stn > 0 else 0))
	if not g.is_empty():
		acts.append(_act("ГРУППА", String(g.get("emblem", "icon_group_add")) if UiKit.has(String(g.get("emblem", ""))) else "icon_group_add", "army_group", true))
	else:
		acts.append(_act("В ГРУППУ", "icon_group_add", "army_group", true))
	_fill_acts("army%d" % f.id, acts)
	var rt: String = String(ab.get("refill_text", ""))
	if f.prod_type == 3:
		rt = Loc.t("НАБОР ОСТАНОВЛЕН")
	if _foot_l.text != rt:
		_foot_l.text = rt



func _protect_acts(f: Facility, player: Country, acts: Array) -> void :
	var pi: Dictionary = gw.protect.info(f)
	for it: Array in [["net", "icon_prot_net"], ["conc", "icon_prot_conc"]]:
		var what: String = String(it[0])
		var st: String = String(pi[what + "_state"])
		var broken: bool = st == "torn" or st == "broken"
		var cost: Dictionary = pi["repair_%s_cost" % what] if broken else pi["next_%s_cost" % what]
		var lab: String = gw.protect.act_label(f, what)
		var on: bool = st != "building" and not cost.is_empty() and player.has_res(cost)
		var price: String = "" if st == "building" else (Loc.t("МАКС") if cost.is_empty() else str(int(cost.get("money", 0))))
		acts.append(_act(lab + ("\n" + price if price != "" else ""), "icon_restore" if broken else String(it[1]), "prot:" + what, on, 1 if int(pi[what + "_lvl"]) > 0 and not broken else 0))




func _deep_card(f: Facility, player: Country, acts: Array) -> String:
	var dc: Dictionary = gw.econ.call("deep_card", f)
	if ops_title.text != String(dc["title"]):
		ops_title.text = String(dc["title"])
	var b1: Control = ops_bars[1][0]
	if b1.visible != bool(dc["busy"]):
		b1.visible = bool(dc["busy"])
	if not f.deposit.is_empty():
		_set_bar(0, float(dc["frac"]), String(dc["icon"]))
	if bool(dc["busy"]):
		_set_bar(1, float(dc["progress"]), "res_level")
		acts.append(_act(Loc.t("ИДЁТ\n%s") % _mmss(float(dc["eta"])), "icon_upgrade", "fac_upgrade", false))
		return String(dc["detail"])
	if player == null or f.country_id != player.id:
		return String(dc["detail"])
	var up: String = _upgrade_act(f, player, acts)
	var at_max: bool = gw.econ.has_method("upgrade_cost") and (gw.econ.call("upgrade_cost", f) as Dictionary).is_empty()
	return String(dc["detail"]) + ("" if up == "" or at_max else " " + up)




func _rate_line(f: Facility, p: Country) -> String:
	var s: Dictionary = EconRates.site_now(gw, f, p)
	var res: String = String(s["res"])
	var n: float = float(s["n"])
	var why: String = String(s["why"])
	var parts: PackedStringArray = PackedStringArray()
	var nm: String = String(Economy.RES_NAMES.get(res, res))
	if String(s["use_res"]) != "" and res != "":
		parts.append(Loc.t("%s %s → %s %s/МИН") % [String(Economy.RES_NAMES.get(String(s["use_res"]), "")), EconRates.fmt( - float(s["use"])) if float(s["use"]) > 0.0 else "0", nm, EconRates.fmt(n) if n > 0.0 else "0"])
	elif res != "":
		parts.append(Loc.t("%s %s/МИН") % [nm, EconRates.fmt(n) if n > 0.0 else "0"])
	if float(s["money"]) > 0.0:
		parts.append(Loc.t("ДОХОД +%d/МИН") % roundi(float(s["money"])))
	if res != "" and p != null:
		parts.append(Loc.t("НА СКЛАДЕ %d") % int(p.get(res)))
	var line: String = " · ".join(parts)
	if why != "":
		line += (Loc.t("\nСЕЙЧАС 0: ") if n <= 0.0 else "\n") + Loc.t(why).to_upper()
	return line



func _upgrade_act(f: Facility, player: Country, acts: Array) -> String:
	if not gw.econ.has_method("upgrade_cost"):
		return ""
	var lv: int = int(gw.econ.call("level_of", f))
	var uc: Dictionary = gw.econ.call("upgrade_cost", f)
	if uc.is_empty():
		acts.append(_act(Loc.t("УР %d\nМАКС") % lv, "icon_upgrade", "fac_upgrade", false))
		return Loc.t("Максимальный уровень.")
	acts.append(_act(Loc.t("УР %d→%d\n%d") % [lv, lv + 1, int(uc.get("money", 0))], "icon_upgrade", "fac_upgrade", player.has_res(uc), -1, "%d" % lv))
	var miss: String = player.missing_res(uc)
	var nx: int = EconRates.next_per_min(gw, f) if f.kind != Facility.Kind.SAWMILL else -1
	return Loc.t("Улучшение до уровня %d: %s.%s%s") % [lv + 1, Economy.cost_text(uc), (Loc.t(" Выпуск станет +%d/мин.") % nx) if nx > 0 else "", (Loc.t(" Не хватает: ") + miss + ".") if miss != "" else ""]


func _solar_act(f: Facility, mil: Military, player: Country, acts: Array) -> void :
	if not mil.has_solar(f):
		var c: int = Military.cost_of(Facility.Kind.SOLAR)
		acts.append(_act(Loc.t("+СОЛНЦЕ\n%d") % c, "icon_solar", "mod_solar", player.money >= c))



func show_aircraft(a: Aircraft, air: Air, player: Country) -> void :
	var names: Dictionary = {Aircraft.State.PARKED: "НА СТОЯНКЕ", Aircraft.State.TAXI: "РУЛЁЖКА", Aircraft.State.ROLL: "ВЗЛЁТ", Aircraft.State.LIFT: "ВЗЛЁТ", Aircraft.State.FLY: "ПОЛЁТ", Aircraft.State.ORBIT: "БАРРАЖИРУЕТ", Aircraft.State.HOVER: "ВИСИТ", Aircraft.State.PATROL: "ПАТРУЛЬ", Aircraft.State.RTB: "НА БАЗУ", Aircraft.State.LAND: "ПОСАДКА", Aircraft.State.DEAD: "ПОТЕРЯН"}
	var lvl: String = Loc.t(" · УР %d") % a.level if a.type == Aircraft.Type.FIGHTER else ""
	var icon: String = ["icon_bomber", "icon_fighter", "icon_heli", "icon_attack_jet"][clampi(a.type, 0, 3)]
	_card("air%d" % a.id, icon, "%s %s%s" % [Air.name_of(a), Loc.no(a.id), lvl], String(names.get(a.state, "")), false, true, true)
	var fmax: float = float(Air.SPEC[a.type]["fuel"])
	var ammo: String = ""
	var amax: int = 1
	match a.type:
		Aircraft.Type.BOMBER:
			ammo = Loc.t(" · КР %d/%d") % [a.missiles, Air.BOMBER_CR]
			amax = Air.BOMBER_CR
		Aircraft.Type.ATTACK:
			ammo = Loc.t(" · КАБ %d · НАР %d · В-В %d") % [a.kab, a.nar, a.missiles]
			amax = 2
		Aircraft.Type.FIGHTER:
			ammo = Loc.t(" · РАКЕТ В-В %d/%d") % [a.missiles, int(Air.FIGHTER_AAM[a.level])]
			amax = int(Air.FIGHTER_AAM[a.level])
		Aircraft.Type.HELI:
			ammo = Loc.t(" · ПУШКА")
	var svc: String = Loc.t(" · ЗАПРАВКА") if a.state == Aircraft.State.PARKED and a.service_t > 1.0 else ""
	if a.type == Aircraft.Type.FIGHTER and a.pylon > 0:
		ammo += Loc.t(" · ПОДВЕС %s %d") % [Loc.t(Air.PYLON_NAMES[a.pylon]), a.pylon_n]
	var an: String = air.auto_note(a) if air.has_method("auto_note") else ""
	_set_info(Loc.t("ТОПЛИВО %d%%%s%s%s") % [roundi(100.0 * a.fuel / fmax), ammo, svc, ("\n" + an) if an != "" else ""], a.fuel < fmax * 0.2 or an != "")
	_set_bar(0, a.fuel / fmax, "res_fuel")
	_set_bar(1, float(a.missiles) / float(maxi(amax, 1)) if a.type != Aircraft.Type.HELI else 1.0, "res_jet")
	var acts: Array = []
	if a.airborne():
		acts.append(_act("ПОСАДКА", "icon_land", "air_land", a.state != Aircraft.State.RTB and a.state != Aircraft.State.LAND))
	if a.type == Aircraft.Type.HELI:
		acts.append(_act("ПАТРУЛЬ", "icon_patrol", "air_patrol", a.state != Aircraft.State.DEAD))
	if a.type == Aircraft.Type.FIGHTER and a.level < 3:
		acts.append(_act(Loc.t("УЛУЧШИТЬ\n%d") % Air.UPGRADE_COST, "icon_upgrade", "air_upgrade", a.state == Aircraft.State.PARKED and player.money >= Air.UPGRADE_COST))
	if a.type == Aircraft.Type.BOMBER:
		acts.append(_act("ПУСК КР", "icon_cr_launch", "air_cr", a.airborne() and a.missiles > 0))
	if a.type == Aircraft.Type.ATTACK:

		var kav: int = int(main_node.call("jet_kab_avail", a)) if main_node != null and main_node.has_method("jet_kab_avail") else a.kab
		acts.append(_act("УДАР КАБ", "icon_m_kab", "air_kab", a.state != Aircraft.State.DEAD and kav > 0, -1, "%d" % kav))
		acts.append(_act("ПОДДЕРЖКА", "icon_attack_jet", "air_cas", a.state != Aircraft.State.DEAD and (a.nar > 0 or a.state == Aircraft.State.PARKED), -1, "%d" % a.nar))
	if a.type == Aircraft.Type.FIGHTER:
		if a.state == Aircraft.State.PARKED:
			acts.append(_act("2 КРЫЛАТЫЕ", "icon_m_cruise", "pylon_1", true, 1 if a.pylon == 1 else 0))
			acts.append(_act("ГИПЕРЗВУК", "icon_m_hyper", "pylon_2", true, 1 if a.pylon == 2 else 0))
			if air.arsenal_enabled:
				acts.append(_act("2 КАБ", "icon_m_kab", "pylon_3", true, 1 if a.pylon == 3 else 0))
		elif a.pylon == 1:
			acts.append(_act("ПУСК КР", "icon_cr_launch", "air_cr", a.airborne() and a.pylon_n > 0, -1, "%d" % a.pylon_n))
		elif a.pylon == 2:
			acts.append(_act("ГИПЕРЗВУК", "icon_m_hyper", "air_hyp", a.airborne() and a.pylon_n > 0, -1, "%d" % a.pylon_n))
		elif a.pylon == 3 and air.arsenal_enabled:
			acts.append(_act("УДАР КАБ", "icon_m_kab", "air_kab", a.airborne() and a.pylon_n > 0, -1, "%d" % a.pylon_n))
	ops_detail.visible = a.type == Aircraft.Type.FIGHTER and a.state == Aircraft.State.PARKED
	ops_detail.text = "Подвес выбирается на стоянке: крылатые ракеты или гиперзвук (склад ракетного завода)." + (" Доступны также 2 КАБ для удара по земле." if air.arsenal_enabled else "")
	_fill_acts("air%d" % a.id, acts)


func show_cr_plan(a: Aircraft, has_target: bool, dist: float, count: int) -> void :
	_card("plan_cr%d" % a.id, "icon_cr_launch", "Пуск крылатых ракет", "%s %s" % [Air.name_of(a), Loc.no(a.id)], true, false, false)
	var ok: bool = false
	if not has_target:
		_set_info("ТАП ПО КАРТЕ = ЦЕЛЬ", false)
	else:
		var head: String = Loc.t("ЦЕЛЬ %.1f КМ · ПОЛЁТ %s\n") % [dist / 1000.0, _mmss(dist / Air.CR_SPEED)]
		if dist > Air.CR_RANGE:
			_set_info(head + Loc.t("ВНЕ ДАЛЬНОСТИ: МАКС %.1f КМ") % (Air.CR_RANGE / 1000.0), true)
		elif (a.pylon_n if a.type == Aircraft.Type.FIGHTER else a.missiles) <= 0:
			_set_info(head + Loc.t("НЕТ КРЫЛАТЫХ РАКЕТ"), true)
		else:
			_set_info(head + Loc.t("НА БОРТУ %d") % (a.pylon_n if a.type == Aircraft.Type.FIGHTER else a.missiles), false)
			ok = true
	ops_count.text = "x%d" % count
	ops_launch.disabled = not ok




func show_jet_plan(a: Aircraft, cas: bool, st: Dictionary, kav: int, stock: int) -> void :
	_card("jet316%s%d" % ["c" if cas else "k", a.id], "icon_attack_jet" if cas else "icon_m_kab", Loc.t("Авиаподдержка") if cas else Loc.t("Удар КАБ"), Loc.t("Штурмовик №%d · %s") % [a.id, Loc.t("НАР %d · ПУШКА") % a.nar if cas else Loc.t("КАБ %d · СКЛАД %d") % [kav, stock]], true, false, false)
	_jet_row(true)
	var pts: Array = st.get("pts", [])
	var bad: Array = st.get("bad", [])
	var nbad: int = 0
	for v: Variant in bad:
		nbad += 1 if bool(v) else 0
	var why: String = String(st.get("why", ""))
	var ok: bool = not pts.is_empty() and nbad == 0 and why == ""
	if why != "" and nbad == 0:
		_set_info(why.to_upper(), true)
	elif cas:
		if pts.is_empty():
			_set_info("ТАП ПО РАЙОНУ: 2 ЗАХОДА — НАРЫ И ПУШКА ПО ВРАГУ (~90 М)", false)
		elif nbad > 0:
			_set_info(Loc.t("ДАЛЕКО: НЕ ХВАТИТ ТОПЛИВА ВЕРНУТЬСЯ (ДО %.1f КМ)") % (float(st.get("fuel_r", 0.0)) / 1000.0), true)
		else:
			var d: float = a.pos.distance_to(pts[0])
			_set_info(Loc.t("РАЙОН %.1f КМ · ПОДЛЁТ ~%s%s") % [d / 1000.0, _mmss(d / maxf(1.0, float(Air.SPEC[a.type].get("speed", 60.0)))), Loc.t("\nНАРОВ НЕТ — ТОЛЬКО ПУШКА") if a.nar <= 0 and a.airborne() else ""], a.nar <= 0 and a.airborne())
	else:
		var cap: int = mini(4, maxi(1, kav))
		if pts.is_empty():
			_set_info(Loc.t("ТАПЫ ПО ЦЕЛЯМ: ДО %d (1 КАБ НА ЦЕЛЬ). СБРОС С %.1f КМ — САМОЛЁТ ЛЕТИТ К ЦЕЛИ") % [cap, float(st.get("reach", 420.0)) / 1000.0], kav <= 0)
		elif nbad > 0:
			_set_info(Loc.t("ЦЕЛИ %d/%d · %d ДАЛЕКО: ТОПЛИВА ДО %.1f КМ — УБЕРИТЕ (ТАП ПО НОМЕРУ)") % [pts.size(), cap, nbad, float(st.get("fuel_r", 0.0)) / 1000.0], true)
		else:
			var far: float = 0.0
			for p: Vector2 in pts:
				far = maxf(far, a.pos.distance_to(p))
			_set_info(Loc.t("ЦЕЛИ %d/%d · СБРОС ЗА %d М ОТ ЦЕЛИ\nДО ДАЛЬНЕЙ ЦЕЛИ %.1f КМ · КАБ СБИВАЮТ ТОЛЬКО ЗЕНИТНЫЕ ПУШКИ") % [pts.size(), cap, int(st.get("reach", 420.0)), far / 1000.0], false)
	ops_count.text = "%d/%d" % [pts.size(), 1 if cas else mini(4, maxi(1, kav))]
	ops_launch.text = "УДАР"
	ops_launch.set_meta("strike_word", true)
	ops_launch.disabled = not ok



func _jet_row(jet: bool) -> void :
	if ops_row == null or ops_row.get_child_count() < 4:
		return
	(ops_row.get_child(0) as Control).visible = not jet
	(ops_row.get_child(2) as Control).visible = not jet
	if not jet and bool(ops_launch.get_meta("strike_word", false)):
		ops_launch.text = "ПУСК"
		ops_launch.set_meta("strike_word", false)



func show_deposit(dep: Dictionary) -> void :
	var rk: String = String(dep.get("res", ""))
	var nm: String = String(Economy.RES_NAMES.get(rk, rk))
	_card("dep%s" % str(dep.get("cell", "")), _res_icon(rk), Loc.t("Залежь: %s") % nm.to_lower(), Loc.t("Малая залежь") if bool(dep.get("small", false)) else Loc.t("Месторождение"), false, false, true)
	var info: String = Loc.t("ЗАПАС %s") % Economy.reserve_text(int(dep.get("left", 0)), int(dep.get("max", dep.get("left", 0))))
	var oid: int = int(dep.get("owner", 0))
	var own: bool = gw.player != null and oid == gw.player.id
	var oc: Country = gw.country_by_id(oid) if oid > 0 else null
	info += " · " + (Loc.t("ВАША ЗЕМЛЯ") if own else (Loc.t("ЗЕМЛЯ: %s") % Loc.name(oc.name).to_upper() if oc != null else Loc.t("НИЧЬЯ ЗЕМЛЯ")))
	if dep.get("taken_by") != null:
		info += Loc.t(" · УЖЕ ДОБЫВАЕТСЯ")
	_set_info(info, false)
	var hint: String = String(gw.econ.call("deposit_hint", dep, gw.player)) if gw.econ.has_method("deposit_hint") and gw.player != null else ""
	ops_detail.visible = hint != ""
	ops_detail.text = hint
	var acts: Array = []
	if own and dep.get("taken_by") == null:
		var kind: int = Facility.Kind.OIL_RIG if rk == "oil" else (Facility.Kind.URANIUM_MINE if rk == "uranium" else Facility.Kind.MINE)
		var bc: Dictionary = Economy.build_cost(kind)
		acts.append(_act("%s\n%d" % [Loc.t("НЕФТЕВЫШКА") if rk == "oil" else (Loc.t("УРАН.ШАХТА") if rk == "uranium" else Loc.t("РУДНИК")), int(bc.get("money", 0))], "icon_oil_rig" if rk == "oil" else ("icon_umine" if rk == "uranium" else "icon_mine"), "dep_build", true))
	_fill_acts("dep", acts)



func show_intel(f: Facility) -> void :
	var oc: Country = gw.country_by_id(f.country_id)
	_card("intel%d" % f.id, _fac_icon(f.kind), Loc.t("Разведданные: %s") % Loc.t(Military.title_of(f.kind)), Loc.name(oc.name) if oc != null else "", false, false, true)
	var ago: float = gw.game_time - float(gw.vision.last_seen(f))
	var alive: bool = gw.vision.fac_shown(f) and gw.mil.alive(f)
	_set_info((Loc.t("ВИДНО СЕЙЧАС") if gw.vision.fac_shown(f) else Loc.t("ПОСЛЕДНИЙ РАЗ ВИДЕЛИ %s НАЗАД") % _mmss(ago)) + ("" if alive or not gw.vision.fac_shown(f) else Loc.t(" · РАЗРУШЕН")), false)
	ops_detail.visible = true
	ops_detail.text = _sentence(String(Military.PURPOSE.get(f.kind, ""))) + Loc.t(". Отметка стоит там, где объект видели последний раз; мобильные комплексы могли уехать.")
	_fill_acts("intel%d" % f.id, [_act("РАКЕТНЫЙ\nУДАР", "icon_target", "intel_strike", true), _act("РАЗВЕДДРОН", "icon_recon_drone", "recon", true)])



func show_recon(inf: Dictionary) -> void :
	_card("recon", String(inf.get("icon", "icon_recon_drone")), String(inf.get("title", "РАЗВЕДДРОН")).capitalize(), String(inf.get("owner", "")), false, false, true)
	var own: bool = bool(inf.get("own", false))
	var t: String = "%s · %s" % [String(inf.get("state", "")), _mmss(float(inf.get("eta", 0.0)))]
	if own:
		t += Loc.t(" · НАЙДЕНО %d") % int(inf.get("found", 0))
	_set_info(t, bool(inf.get("jam", false)))
	ops_detail.visible = true
	ops_detail.text = String(inf.get("sub", "")) + ("\n" + String(inf.get("why", "")) if String(inf.get("why", "")) != "" else "")
	_fill_acts("recon", [_act("ОТОЗВАТЬ", "icon_restore", "recon_recall", own and not bool(inf.get("back", false)))] if own else [])



var _city_rename_dialog: Control = null

func show_city(c: City) -> void :
	var co: Country = gw.country_by_id(c.country_id)
	var kinds: Array = ["Столица", "Город", "Посёлок"]
	_card("city%d" % c.id, "icon_capital" if c.kind == City.Kind.CAPITAL else "icon_city", Loc.name(c.name), "%s · %s" % [Loc.t(String(kinds[clampi(c.kind, 0, 2)])), Loc.name(co.name) if co != null else ""], false, false, true)
	var info: String = Loc.t("УРОВЕНЬ %d · %s") % [c.level, Loc.t("СВЕТ ЕСТЬ") if c.powered else Loc.t("БЕЗ СВЕТА")]
	if gw.get("naval") != null and gw.naval.is_colony(c):
		info += "\n" + Loc.t(String(gw.naval.colony_info(c).get("text", Loc.t("КОЛОНИЯ")))).to_upper()
	if gw.rail != null:
		info += "\n" + String(gw.rail.city_text(c.id)).to_upper()
		var tw: int = int(gw.rail.urban.tower_count(c.id))
		if tw > 0:
			info += Loc.t(" · ВЫСОТОК %d") % tw
	_set_info(info, not c.powered)
	if gw.rail != null and co != null:
		ops_detail.visible = true
		ops_detail.text = String(gw.rail.dev_text(co.id))
	_fill_acts("city_acts_%d" % c.id, [
		_act("ИЗМЕНИТЬ\nНАЗВАНИЕ", "icon_rename", "city_rename", true)
	])


func show_city_rename_dialog(c: City) -> void :
	if c == null or gw == null or root == null:
		return
	if _city_rename_dialog != null and is_instance_valid(_city_rename_dialog):
		_city_rename_dialog.queue_free()
		_city_rename_dialog = null

	var co: Country = gw.country_by_id(c.country_id)
	var bg: = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.04, 0.1, 0.72)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bg)
	_city_rename_dialog = bg

	var cc: = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(cc)

	var panel: = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.sb("wb_window", 16, 14))
	var win_w: float = minf(460.0, root.size.x - 30.0)
	panel.custom_minimum_size = Vector2(win_w, 0)
	cc.add_child(panel)

	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	# Header row
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	vb.add_child(hr)

	var islot: = PanelContainer.new()
	islot.add_theme_stylebox_override("panel", UiKit.sb("wb_slot", 3))
	islot.custom_minimum_size = Vector2(36, 36)
	islot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(islot)

	var icc: = CenterContainer.new()
	islot.add_child(icc)
	var ic: TextureRect = UiKit.icon_rect("icon_capital" if c.kind == City.Kind.CAPITAL else "icon_city", 24.0)
	icc.add_child(ic)

	var tcol: = VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 1)
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(tcol)

	var title_lbl: Label = UiKit.lbl("ПЕРЕИМЕНОВАНИЕ ГОРОДА", 13, UiKit.TITLE, 3, 2)
	tcol.add_child(title_lbl)

	var kinds: Array = ["Столица", "Город", "Посёлок"]
	var sub_txt: String = "%s · %s" % [Loc.t(String(kinds[clampi(c.kind, 0, 2)])), Loc.name(co.name) if co != null else ""]
	var sub_lbl: Label = UiKit.lbl(sub_txt, 10, UiKit.MUTED, 1)
	tcol.add_child(sub_lbl)

	var close_b: Button = UiKit.close_btn(36.0)
	var close_dlg = func() -> void :
		UiKit.snd("ui_close")
		if _city_rename_dialog != null and is_instance_valid(_city_rename_dialog):
			_city_rename_dialog.queue_free()
			_city_rename_dialog = null
	close_b.pressed.connect(close_dlg)
	hr.add_child(close_b)

	# Description
	var tip_lbl: Label = UiKit.lbl("Введите новое название для города:", 11, UiKit.TEXT, 2, 2)
	vb.add_child(tip_lbl)

	# Input row (LineEdit + Random button)
	var ir: = HBoxContainer.new()
	ir.add_theme_constant_override("separation", 6)
	vb.add_child(ir)

	var le: = LineEdit.new()
	le.text = c.name
	le.placeholder_text = "Название города"
	le.max_length = 24
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size = Vector2(0, 42)
	le.add_theme_font_override("font", UiKit.f_bold)
	le.add_theme_font_size_override("font_size", 14)
	le.add_theme_color_override("font_color", UiKit.TEXT)
	le.add_theme_color_override("caret_color", UiKit.GOLD)
	for st: String in ["normal", "focus", "read_only"]:
		le.add_theme_stylebox_override(st, UiKit.sb("wb_slot" if st != "focus" else "wb_slot_pressed", 8, 4))
	ir.add_child(le)

	var rand_btn: Button = UiKit.big("🎲", "stone", "", 42.0, 14)
	rand_btn.custom_minimum_size.x = 44
	rand_btn.tooltip_text = "Случайное название"
	rand_btn.pressed.connect(func() -> void :
		var r: = Rng.new(randi())
		var arch: int = co.arch if co != null else 0
		var taken: Array = gw.cities.map(func(o: City) -> String: return o.name)
		var gen_n: String = NameGen.city(r, arch, taken)
		le.text = gen_n
		le.grab_focus()
		le.select_all()
		UiKit.snd("ui_select")
	)
	ir.add_child(rand_btn)

	# Buttons row (Cancel / Save)
	var br: = HBoxContainer.new()
	br.add_theme_constant_override("separation", 8)
	br.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(br)

	var cancel_b: Button = UiKit.big("ОТМЕНА", "stone", "", 38.0, 12)
	cancel_b.custom_minimum_size.x = 90
	cancel_b.pressed.connect(close_dlg)
	br.add_child(cancel_b)

	var do_save: Callable = func() -> void :
		var new_n: String = le.text.strip_edges()
		if new_n == "":
			UiKit.snd("ui_error")
			return
		if main_node != null and main_node.get("net") != null and bool(main_node.net.get("in_match")):
			main_node.call("_sim", "", "cmd_city_rename", [c.id, new_n])
		else:
			gw.cmd_city_rename(c.id, new_n)
		c.name = new_n
		show_city(c)
		city_label_drop(c.id)
		_sync_city_labels()
		show_toast(Loc.msg(Loc.mk("Город переименован: %s", [new_n])))
		UiKit.snd("ui_build")
		if _city_rename_dialog != null and is_instance_valid(_city_rename_dialog):
			_city_rename_dialog.queue_free()
			_city_rename_dialog = null

	var save_b: Button = UiKit.big("СОХРАНИТЬ", "gold", "", 38.0, 12)
	save_b.custom_minimum_size.x = 110
	save_b.pressed.connect(do_save)
	br.add_child(save_b)

	le.text_submitted.connect(func(_t: String) -> void : do_save.call())

	# Dismiss handlers
	bg.gui_input.connect(func(ev: InputEvent) -> void :
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_dlg.call()
	)

	le.gui_input.connect(func(ev: InputEvent) -> void :
		if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
			close_dlg.call()
	)

	UiKit.pop_in(panel, 0.9, 0.16)
	le.call_deferred("grab_focus")
	le.call_deferred("select_all")

func _hold_inject() -> void :
	if army_ux == null or not is_instance_valid(army_ux) or String(army_ux.get("view")) != "army" or gw == null or gw.get("hold") == null:
		return
	var sh: Variant = army_ux.get("sheet")
	if sh == null or not is_instance_valid(sh):
		return
	if _hold_btn != null and is_instance_valid(_hold_btn) and (sh as Node).is_ancestor_of(_hold_btn):
		return
	var tb: Button = null
	for b: Node in (sh as Node).find_children("*", "Button", true, false):
		if b.has_meta("out"):
			tb = b as Button
			break
	if tb == null:
		return
	var fid: int = int(army_ux.get("cur_fid"))
	_hold_btn = army_ux._verb(tb.get_parent(), "icon_city", "ЗАНЯТЬ ДОМ", func() -> void :
		if main_node != null and main_node.has_method("hold_begin"):
			main_node.hold_begin(fid), false, "ЗАНЯТЬ ДОМ — тапните дом или высотку (у себя, у врага в войне, у союзника или с правом прохода): до 4 бойцов (стрелки, ПТУР, штурмовики) займут его; урон по ним −60…70 %")
	tb.get_parent().move_child(_hold_btn, tb.get_index() + 1)


func hide_ops() -> void :
	if ops_panel.visible:
		ops_panel.visible = false
	_fac_sig = ""
	_ops_key = ""
