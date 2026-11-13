extends "res://game/main/main_base.gd"



func _snd(fn: String, args: Array) -> void :
	if ResourceLoader.exists("res://core/sfx.gd"):
		(load("res://core/sfx.gd") as GDScript).callv(fn, args)
func _navy_snap(cell: Vector2i) -> Vector2i:
	if world.get("navy") == null or world.player == null:
		return cell
	var key: String = "%d:%d:%d" % [cell.x, cell.y, int(world.game_time / 5.0)]
	if not _snap_c.has(key):
		if _snap_c.size() > 64:
			_snap_c.clear()
		_snap_c[key] = world.navy.resolve_site(cell, world.player)
	var c2: Vector2i = _snap_c[key]
	world.navy.fit_variant(c2, world.player, false)
	return c2



func _army_back() -> bool:
	if _spick != null and is_instance_valid(_spick) and bool(_spick.get("is_open")):
		_spick.call("close")
		return true
	var ad: Variant = hud.get("army_dock") if hud != null else null
	if ad != null and is_instance_valid(ad) and bool(ad.is_open) and ad.has_method("exit_mode"):
		ad.exit_mode()
		return true
	var nd: Variant = hud.get("navy_dock") if hud != null else null
	if nd != null and is_instance_valid(nd) and bool(nd.is_open):
		nd.exit_mode()
		return true
	return false


func _set_mode(m: int) -> void :
	if strike.active and not _strike_sw and not _is_strike_mode(m):
		strike.end(_plan_targets(), false)
	mode = m
	if not _pend.is_empty() and not _confirming:
		_pend = {}
		hud.hide_confirm()
	hud.set_key_pressed("capital", m == Mode.CAPITAL)
	hud.set_key_pressed("town", m == Mode.TOWN)
	hud.set_key_pressed("strike", m == Mode.STRIKE)
	for k: String in BUILD_KEYS:
		hud.set_key_pressed(k, m == int(BUILD_KEYS[k]))
	hud.set_key_pressed("launch", m == Mode.TARGET)
	hud.set_key_pressed("missile", m == Mode.MISSILE)
	hud.set_key_pressed("ship_cr", m == Mode.SHIP_CR)
	if m != Mode.SHIP_CR and _cr_warn != null:
		_cr_warn.visible = false
	hud.set_key_pressed("attack", m == Mode.ATTACK)
	hud.set_key_pressed("rail_st", m == Mode.RAIL_ST)
	hud.set_key_pressed("rail_line", m == Mode.RAIL_LINE)
	hud.set_key_pressed("satellite", m == Mode.SATELLITE)
	hud.set_key_pressed("recon", m == Mode.RECON)
	for ok: int in 3:
		hud.set_key_pressed("order_%d" % ok, m == Mode.ORDER and order_kind == ok)
	if m != Mode.OPERATION and world.get("ops") != null:
		world.ops.preview_arrow = {}
	if m != Mode.ORDER and world.get("ops") != null:
		world.ops.preview_order = {}
	if m != Mode.ATTACK:
		attack_from = null
	if m != Mode.TARGET and m != Mode.MISSILE and m != Mode.CR_TARGET:
		_clear_plan()
	if m != Mode.JET_KAB and m != Mode.JET_CAS:
		jet_pts.clear()
	hud.set_key_pressed("jet_kab", m == Mode.JET_KAB)
	hud.set_key_pressed("jet_cas", m == Mode.JET_CAS)
	if m != Mode.NONE and m != Mode.MODULE:
		selected_fac = null
	hud.set_key_pressed("route", route_mode)
	match m:
		Mode.CAPITAL:
			hud.set_hint("ВЫБЕРИТЕ МЕСТО ДЛЯ СТОЛИЦЫ")
		Mode.TOWN:
			hud.set_hint(Loc.t("ГОРОД %d: СВОБОДНАЯ ЗЕМЛЯ ДО 360 М ОТ СТРАНЫ") % Military.town_cost(world.player.towns_founded if world.player != null else 0))
		Mode.STRIKE:
			hud.set_hint("ТЕСТОВЫЙ УДАР: НАЖМИТЕ НА ЦЕЛЬ")
		Mode.FACTORY, Mode.DRONEPORT, Mode.TEL, Mode.MFACTORY, Mode.REFINERY, Mode.POWER, Mode.AIRFIELD, Mode.SAWMILL, Mode.OIL_RIG, Mode.PORT, Mode.SOLAR_FARM, Mode.NAVBASE, Mode.NPP, Mode.UMINE:
			var kind: int = BUILD_KIND[m]
			var bc1: Dictionary = Economy.build_cost(kind)
			if world.player != null and world.mil.has_method("price_of") and bc1.has("money"):
				bc1 = bc1.duplicate()
				bc1["money"] = world.mil.price_of(kind, world.player)
			hud.set_hint("%s (%s): %s" % [Military.title_of(kind).to_upper(), Economy.cost_text(bc1).to_upper(), _where(m)])
		Mode.MODULE:
			hud.set_hint(Loc.t("%s, %d: РЯДОМ (ДО %d М)") % [Loc.t(Military.title_of(module_kind)).to_upper(), Military.cost_of(module_kind), Military.MODULE_R * GameWorld.CELL])
		Mode.TARGET:
			hud.set_hint("ЦЕЛЬ И ТОЧКИ МОЖНО ПЕРЕТАСКИВАТЬ")
		Mode.MOVE_ALL:
			hud.set_hint("ДВИЖЕНИЕ ВСЕХ АРМИЙ: ТАП ПО ЦЕЛИ (СВОЯ ЗЕМЛЯ — ОБОРОНА, ЧУЖАЯ — НАСТУПЛЕНИЕ)")
		Mode.GARRISON:
			hud.set_hint(Loc.t("ЗАНЯТЬ: ТАП ПО СВОИМ ОКОПАМ И БЛИНДАЖАМ — АРМИЯ №%d. ВЫХОД — ✕ СЛЕВА") % (garrison_from.army_no if garrison_from != null else 0))
		Mode.HOLD:
			hud.set_hint(Loc.t("ТАПНИТЕ ДОМ (СВОЙ, ВРАГА, СОЮЗНИКА) — АРМИЯ №%d") % (hold_from.army_no if hold_from != null else 0))
		Mode.OPERATION:
			hud.set_hint("ДВИЖЕНИЕ: ПРОВЕДИТЕ ПАЛЬЦЕМ ОТ КАЗАРМЫ К ЦЕЛИ (ИЛИ ТАП ПО ЦЕЛИ)")
		Mode.ORDER:
			var oi: Dictionary = world.ops.order_info(order_kind)
			hud.set_hint(Loc.t("%s (%s): ТАП ПО МЕСТУ") % [Loc.t(String(oi.get("name", ""))).to_upper(), Loc.t(String(oi.get("cost_text", ""))).to_upper()])
		Mode.RECON:
			hud.set_hint("РАЗВЕДДРОН: ТАП ПО ТОЧКЕ ДО 4.5 КМ ОТ ДРОНОПОРТА")
		Mode.EXPEDITION:
			hud.set_hint("КОЛОНИЯ: ТАП ПО СВОБОДНОМУ БЕРЕГУ")
		Mode.SATELLITE:
			hud.set_hint(Loc.t("СПУТНИК: ТАП ПО ЛЮБОЙ ТОЧКЕ — СНИМОК %d. НАХОДИТ ПОСТРОЙКИ И ВОЙСКА") % int(world.vision.satellite_cost()))
		Mode.MISSILE:
			hud.set_hint("РАКЕТНЫЙ УДАР: ТАПЫ ПО ЦЕЛЯМ, ЗАТЕМ ПУСК")
		Mode.CR_TARGET:
			hud.set_hint("КРЫЛАТЫЕ РАКЕТЫ: ТАП ПО ЦЕЛИ")
		Mode.JET_KAB:
			hud.set_hint("УДАР КАБ: ТАПЫ ПО 1–4 ЦЕЛЯМ, ЗАТЕМ «УДАР». ТАП ПО ЦЕЛИ — УБРАТЬ")
		Mode.JET_CAS:
			hud.set_hint("ПОДДЕРЖКА: ТАП ПО РАЙОНУ — ШТУРМОВИК ОТРАБОТАЕТ НАРАМИ И ПУШКОЙ")
		Mode.HYP_TARGET:
			hud.set_hint("ГИПЕРЗВУК: ТАПЫ ПО ЦЕЛЯМ, ЗАТЕМ ПУСК")
		Mode.SHIP_CR:
			hud.set_hint("КР С КОРАБЛЕЙ: ТАПЫ ПО ЦЕЛЯМ (ЕЩЁ ТАП = +1), ЗАТЕМ ПУСК")
		Mode.ATTACK:
			hud.set_hint(Loc.t("НАСТУПЛЕНИЕ: ТАП ПО ЧУЖОМУ ГОРОДУ") if attack_from == null else Loc.t("АТАКА ИЗ КАЗАРМ: ТАП ПО ГОРОДУ"))
		Mode.RAIL_ST, Mode.RAIL_LINE:
			hud.set_hint(RB.hint(self, m))
		Mode.TRENCH_H, Mode.TEETH_H:
			hud.set_hint(Loc.t("%s: ВЕДИТЕ ПАЛЬЦЕМ ПО СВОЕЙ ЗЕМЛЕ (%d/КЛЕТКА). КАРТА - ДВУМЯ ПАЛЬЦАМИ") % [Loc.t("ОКОП") if m == Mode.TRENCH_H else Loc.t("ЗУБЫ ДРАКОНА"), Military.cost_of(BUILD_KIND[m])])
		Mode.POLICE_STATION, Mode.FARM, Mode.CIV, Mode.MINE, Mode.BARRACKS, Mode.AD_MFG, Mode.AD_SPAAG, Mode.AD_SAM, Mode.AD_PATRIOT, Mode.AD_INT, Mode.AD_RADAR, Mode.AD_EW, Mode.DUGOUT, Mode.COASTAL_ASM:
			var kind2: int = BUILD_KIND[m]
			var bc2: Dictionary = Economy.build_cost(kind2)
			if world.player != null and world.mil.has_method("price_of") and bc2.has("money"):
				bc2 = bc2.duplicate()
				bc2["money"] = world.mil.price_of(kind2, world.player)
			hud.set_hint("%s (%s): %s" % [Military.title_of(kind2).to_upper(), Economy.cost_text(bc2).to_upper(), _where(m)])
		_:
			hud.set_hint("")
	_sel_hint = ""


func _where(m: int) -> String:
	match m:
		Mode.MINE:
			return Loc.t("НА ЗАЛЕЖЬ РУДЫ (ЗНАЧОК НА КАРТЕ); НА УРАНЕ — УРАНОВАЯ ШАХТА %d") % Military.cost_of(Facility.Kind.URANIUM_MINE)
		Mode.OIL_RIG:
			return Loc.t("НА НЕФТЬ (ЧЁРНЫЙ ЗНАЧОК)")
		Mode.SAWMILL:
			return Loc.t("РЯДОМ С ЛЕСОМ")
		Mode.PORT:
			return Loc.t("НА БЕРЕГУ МОРЯ")
		Mode.NAVBASE:
			return Loc.t("СВОЙ БЕРЕГ У ГЛУБОКОЙ ВОДЫ: ПРИЧАЛЫ В МОРЕ")
	return Loc.t("НАЖМИТЕ НА СВОЮ ЗЕМЛЮ")
func _speed_picker() -> void :
	if _spick == null or not is_instance_valid(_spick):
		_spick = (load("res://ui/ui24/speed_pick.gd") as GDScript).new()
		_spick.call("mount", hud)
	if bool(_spick.get("is_open")):
		_spick.call("close")
	else:
		_spick.call("open")


func set_speed_i(i: int) -> void :
	_speed_i = clampi(i, 0, SPEEDS.size() - 1)
	_paused = false
	_apply_speed()


func _apply_speed() -> void :
	if net != null and net.in_match:
		world.time_scale = float(net.speed)
		hud.set_speed_text("x%d" % net.speed)

		hud.set_speed_dot(UiKit.RED if net.speed_why == "lag" else (UiKit.GOLD if GameConfig.mp_speed == 0 and net.my_want > net.speed else Color(0, 0, 0, 0)))
		return
	world.time_scale = 0.0 if _paused else float(SPEEDS[_speed_i])
	var spd: float = float(SPEEDS[_speed_i])
	hud.set_speed_text("II" if _paused else ("x0.5" if spd < 1.0 else "x%d" % int(spd)))


func _on_zoom(z: float) -> void :
	(world.territory_border.material as ShaderMaterial).set_shader_parameter("border_px", clampf(2.0 / z, 1.0, 4.0))
	(world.territory.material as ShaderMaterial).set_shader_parameter("fill_scale", maxf(1.0, 1.0 / z))
	world.objects.visible = z >= 0.5
	world.objects.sway_enabled = z >= 1.0 and GameConfig.performance_mode != 0 and GameConfig.performance_mode != 3



func _has_capital() -> bool:
	if world.player == null or world.player.capital_id < 0:
		hud.show_toast("Сначала основайте столицу")
		return false
	return true


func _deselect() -> void :
	selected_dep = {}
	selected_city = -1
	selected_intel = null
	air_patrol_pending = false
	follow = null
	cam_lock = false
	selected_fac = null
	army_view = false
	bar_builds_fid = -1
	route_mode = false
	if hud != null:
		hud.set_key_pressed("follow", false)
		hud.set_key_pressed("route", false)


func _clear_plan() -> void :
	plan_list.clear()
	plan_wps.clear()
	plan_has_target = false
	plan_count = 1
	if mode != Mode.NONE:
		route_mode = false
	_drag_pt = -2




func drop_cards_for_sheet() -> void :
	if mode != Mode.NONE:
		_set_mode(Mode.NONE)
	_deselect()
	if hud != null:
		hud.hide_ops()



func plan_state() -> Dictionary:
	return {"active": mode == Mode.TARGET or mode == Mode.MISSILE or mode == Mode.CR_TARGET or mode == Mode.HYP_TARGET or mode == Mode.SHIP_CR, "kind": "missile" if mode == Mode.MISSILE else ("cruise" if mode == Mode.CR_TARGET and follow != null else ("hyper" if mode == Mode.HYP_TARGET or mode == Mode.SHIP_CR or mode == Mode.CR_TARGET else "drone")), "info": _plan_info, "wps": plan_wps, "target": plan_target, "has_target": plan_has_target, "drag": _drag_pt, "drag_drone": _drag_drone_pos if (_drag_pt == -3 or _drag_pt == -4) and _moved else null, "multi": _plan_targets_ov() if mode == Mode.TARGET else (_plan_targets() if _missile_multi() else []), "danger": _danger if mode == Mode.TARGET else []}



func _plan_targets_ov() -> Array:
	var out: Array = _plan_targets()
	var pt: Array = _last_mp.get("per_target", [])
	for i in out.size():
		var t: Dictionary = out[i]
		if i < pt.size() and (pt[i] as Dictionary).has("smart"):
			t["smart"] = pt[i]["smart"]
		elif i == out.size() - 1 and _plan_info.has("smart") and (t["wps"] as Array).is_empty():
			t["smart"] = _plan_info["smart"]
	return out


func follow_drone() -> Object:
	return follow


func plan_active() -> bool:
	return mode == Mode.TARGET or mode == Mode.MISSILE or mode == Mode.CR_TARGET



func _plan_hit(pos: Vector2, radius: float) -> int:
	var best: int = -2
	var bd: float = radius
	if plan_has_target:
		var d0: float = cam.world_to_screen(plan_target).distance_to(pos)
		if d0 <= bd:
			bd = d0
			best = -1
	if mode == Mode.TARGET:
		for i in plan_wps.size():
			var d: float = cam.world_to_screen(plan_wps[i]).distance_to(pos)
			if d <= bd:
				bd = d
				best = i
	return best



func _press_hit(pos: Vector2) -> int:
	var fad: Variant = hud.get("army_dock")
	if fad != null and is_instance_valid(fad) and fad.has_method("plan_drawing") and fad.plan_drawing():
		return -9
	if fad != null and is_instance_valid(fad) and fad.has_method("route_grab") and fad.route_grab(pos):
		return -10
	var fnd: Variant = hud.get("navy_dock")
	if fnd != null and is_instance_valid(fnd) and fnd.route_grab(pos):
		return -12
	if mode == Mode.OPERATION and op_from != null:
		return -8

	if mode == Mode.NONE and selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS and world.player != null and selected_fac.country_id == world.player.id and world.get("ops") != null:
		if cam.world_to_screen(selected_fac.center_px()).distance_to(pos) <= maxf(GRAB_R * 1.6, float(selected_fac.size.x * GameWorld.CELL) * cam.zoom.x * 0.6):
			op_from = selected_fac
			return -8
	if mode == Mode.RAIL_LINE and RB.press(self, pos):
		return -13
	if mode == Mode.TRENCH_H or mode == Mode.TEETH_H:
		line_cells.clear()
		var w: Vector2 = cam.screen_to_world(pos)
		line_cells.append(Vector2i(floori(w.x / GameWorld.CELL), floori(w.y / GameWorld.CELL)))
		return -7
	if mode == Mode.TARGET or mode == Mode.MISSILE:
		var h: int = _plan_hit(pos, GRAB_R)


		if h == -2 and mode == Mode.TARGET and plan_has_target and plan_wps.size() < Military.MAX_WAYPOINTS and RouteOverlay.dist_to_line(pos, overlay.plan_line) <= 12.0:
			return -5
		return h
	var d: Drone = follow as Drone
	if mode == Mode.NONE and d != null and d.state != Drone.State.DONE and d.state != Drone.State.DIVE:
		if cam.world_to_screen(d.target).distance_to(pos) <= GRAB_R:
			_drag_drone_pos = d.target
			return -3
		if RouteOverlay.dist_to_line(pos, overlay.follow_line) <= 12.0:
			_drag_drone_pos = cam.screen_to_world(pos)
			return -6
	return -2


func _plan_tap(pos: Vector2, wp: Vector2) -> void :
	var p: Vector2 = wp.floor() + Vector2(0.5, 0.5)
	if route_mode and plan_has_target:
		var hit: int = _plan_hit(pos, GRAB_R)
		if hit >= 0:
			plan_wps.remove_at(hit)
		elif hit == -1:
			return
		elif plan_wps.size() >= Military.MAX_WAYPOINTS:
			hud.show_toast(Loc.msg(Loc.mk("Не больше %d точек маршрута", [Military.MAX_WAYPOINTS])))
		else:
			plan_wps.insert(_insert_index(p), p)
		return
	if (mode == Mode.TARGET or _missile_multi()) and plan_has_target:
		var is_mod_weapon: bool = strike.active and (strike.cur == "thermo" or strike.cur == "nuke" or strike.cur == "iskander")
		var av_check: int = int(_missile_mp().get("available", 0)) if is_mod_weapon else 999
		var cur_tot: int = 0
		if is_mod_weapon:
			for t0: Dictionary in _plan_targets():
				cur_tot += int(t0["n"])

		if cam.world_to_screen(plan_target).distance_to(pos) <= GRAB_R:
			if is_mod_weapon and cur_tot >= av_check:
				var w_name: String = "залпы" if strike.cur == "thermo" else ("ракеты «Искандер»" if strike.cur == "iskander" else "МБР")
				hud.show_toast(Loc.msg(Loc.mk("Все %s распределены: %d", [w_name, av_check])))
				UiKit.snd("ui_error")
				return
			plan_count += 1
			overlay.ripple(plan_target, "alert_red")
			return
		for t: Dictionary in plan_list:
			if cam.world_to_screen(t["pos"]).distance_to(pos) <= GRAB_R:
				if is_mod_weapon and cur_tot >= av_check:
					var w_name: String = "залпы" if strike.cur == "thermo" else ("ракеты «Искандер»" if strike.cur == "iskander" else "МБР")
					hud.show_toast(Loc.msg(Loc.mk("Все %s распределены: %d", [w_name, av_check])))
					UiKit.snd("ui_error")
					return
				t["n"] = int(t["n"]) + 1
				overlay.ripple(t["pos"], "alert_red")
				return
		if is_mod_weapon and cur_tot >= av_check:
			var w_name: String = "залпы" if strike.cur == "thermo" else ("ракеты «Искандер»" if strike.cur == "iskander" else "МБР")
			hud.show_toast(Loc.msg(Loc.mk("Все %s распределены: %d", [w_name, av_check])))
			UiKit.snd("ui_error")
			return
		plan_list.append({"pos": plan_target, "n": plan_count, "wps": plan_wps.duplicate()})
		plan_wps.clear()


		plan_count = 1
	plan_target = p
	plan_has_target = true
	overlay.ripple(p, "alert_red")



func _missile_multi() -> bool:
	if mode == Mode.MISSILE or mode == Mode.HYP_TARGET or mode == Mode.SHIP_CR:
		return true
	if mode == Mode.CR_TARGET:
		var b: Aircraft = follow as Aircraft
		if b == null:
			return strike.active
		return true
	return false



func _missile_mp() -> Dictionary:
	if mode == Mode.MISSILE:
		if strike.active and (strike.cur == "thermo" or strike.cur == "nuke" or strike.cur == "iskander"):
			return StrikeHubScript.plan(world, strike.cur, _plan_targets())
		return world.mil.missile_multi_plan(world.player, _plan_targets())
	if mode == Mode.SHIP_CR:
		if strike.active and strike.cur == "art":
			return world.navy.art.plan(world.player.id, _plan_targets())
		return NavyStrike.plan(world, world.player.id, _plan_targets())
	return world.mil.air.multi_plan(world.player, _plan_targets(), mode == Mode.HYP_TARGET)



func _missile_tap(pos: Vector2, wp: Vector2) -> void :
	var is_mod_weapon: bool = strike.active and (strike.cur == "thermo" or strike.cur == "nuke" or strike.cur == "iskander")
	var av: int = int(_missile_mp().get("available", 0))
	if is_mod_weapon and av <= 0:
		var w_name: String = "залпов «Солнцепёк»" if strike.cur == "thermo" else ("ракет «Искандер»" if strike.cur == "iskander" else "снаряжённых шахт МБР")
		hud.show_toast(Loc.msg(Loc.mk("Нет готовых %s для пуска", [w_name])))
		UiKit.snd("ui_error")
		return
	if plan_has_target and not route_mode:
		var tot: int = 0
		for t: Dictionary in _plan_targets():
			tot += int(t["n"])
		if tot >= av:
			var w_name: String = "ракеты"
			if strike.active:
				if strike.cur == "thermo":
					w_name = "залпы"
				elif strike.cur == "iskander":
					w_name = "ракеты «Искандер»"
				elif strike.cur == "nuke":
					w_name = "МБР"
			hud.show_toast(Loc.msg(Loc.mk("Все %s распределены: %d", [w_name, av])))
			UiKit.snd("ui_error")
			return
	var n_pts: int = plan_list.size()
	_plan_tap(pos, wp)
	if plan_list.size() > n_pts:
		plan_count = 1





func _insert_index(p: Vector2) -> int:
	var pts: Array[Vector2] = []
	var from: Variant = _plan_info.get("from")
	pts.append(from if from is Vector2 and _plan_info.get("airfield") != null else p)
	pts.append_array(plan_wps)
	pts.append(plan_target)
	var best: int = plan_wps.size()
	var bd: float = INF
	for i in range(pts.size() - 1):
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		var d: float = q.distance_squared_to(p)
		if d < bd:
			bd = d
			best = i
	return best


func _on_missile_launched(m: Missile) -> void :
	if _await_missile and world.player != null and m.country_id == world.player.id:
		_await_missile = false
		follow = m
		cam_lock = false
		hud.set_key_pressed("follow", false)
		_follow_done_t = 0.0



func _update_selection_banner() -> void :
	var title: String = ""
	var icon: String = ""
	if mode != Mode.NONE:
		var key: String = ""
		for k: String in BUILD_KEYS:
			if int(BUILD_KEYS[k]) == mode:
				key = k
		if key == "":
			key = String(MODE_KEY.get(mode, ""))
		if mode == Mode.MODULE:
			title = Military.title_of(module_kind)
			icon = hud._fac_icon(module_kind)
		elif mode == Mode.CR_TARGET:
			title = Loc.t("Пуск крылатых ракет")
			icon = "icon_cr_launch"
		elif mode == Mode.JET_KAB or mode == Mode.JET_CAS:
			title = Loc.t("Удар КАБ") if mode == Mode.JET_KAB else Loc.t("Авиаподдержка")
			icon = "icon_target" if mode == Mode.JET_KAB else "icon_fighter"
		elif mode == Mode.HYP_TARGET:
			title = Loc.t("Гиперзвуковой удар")
			icon = "icon_m_hyper"
		elif mode == Mode.EXPEDITION:
			title = Loc.t("Колония")
			icon = "icon_ship"
		elif mode == Mode.HOLD:
			title = Loc.t("Занять дом · армия №%d") % (hold_from.army_no if hold_from != null else 0)
			icon = "icon_city"
		elif mode == Mode.ORDER:
			var oi2: Dictionary = world.ops.order_info(order_kind)
			title = String(oi2.get("name", "Приказ"))
			icon = String(oi2.get("icon", ""))
		elif key != "":
			title = String(hud.key_title(key)[0])
			icon = hud.key_icon(key)
	elif follow is Drone:
		var d: Drone = follow as Drone
		title = "%s %d" % [Loc.t("Крылатая ракета") if d.kind == 1 else (Loc.t("Реактивный БПЛА") if d.kind == 2 else Loc.t("БПЛА")), d.id]
		icon = "icon_cr_launch" if d.kind == 1 else ("icon_jet_uav" if d.kind == 2 else "icon_launch")
	elif follow is Recon.RDrone:
		title = Loc.t("Разведдрон")
		icon = "icon_recon_drone"
	elif follow is Missile:
		title = "%s %d" % [Loc.t("Гиперзвук") if (follow as Missile).hyper else Loc.t("Ракета"), (follow as Missile).id]
		icon = "icon_m_hyper" if (follow as Missile).hyper else "icon_m_ballistic"
	elif follow is Aircraft:
		var ac: Aircraft = follow as Aircraft
		title = "%s %d" % [Air.name_of(ac), ac.id]
		icon = ["icon_bomber", "icon_fighter", "icon_heli"][clampi(ac.type, 0, 2)]
	elif selected_fac != null:
		title = Military.title_of(selected_fac.kind)
		icon = hud._fac_icon(selected_fac.kind)
	elif selected_intel != null:
		title = Loc.t("Разведданные: %s") % Loc.t(Military.title_of(selected_intel.kind))
		icon = hud._fac_icon(selected_intel.kind)
	elif not selected_dep.is_empty():
		pass
	elif selected_city >= 0 and selected_city < world.cities.size():
		title = world.cities[selected_city].name
		icon = "icon_capital" if world.cities[selected_city].kind == City.Kind.CAPITAL else "icon_city"
	hud.set_selection(title, "", icon)


func _own_units() -> Array:
	var list: Array = []
	if world.player == null:
		return list
	for d: Drone in world.mil.drones:
		if d.country_id == world.player.id and d.state != Drone.State.PARKED and d.state != Drone.State.DONE:
			list.append(d)
	for m: Missile in world.mil.missiles:
		if m.country_id == world.player.id:
			list.append(m)
	return list


func _cycle_follow() -> void :
	var list: Array = _own_units()
	if list.is_empty():
		_deselect()
		hud.show_toast("Нет дронов и ракет в полёте")
	elif follow != null and not cam_lock and list.has(follow):
		cam_lock = true
	else:
		var i: int = list.find(follow)
		follow = list[i + 1] if i + 1 < list.size() else (null if i >= 0 else list[0])
		cam_lock = follow != null
		_follow_done_t = 0.0
		selected_fac = null
	hud.set_key_pressed("follow", cam_lock)
func _res_go(nm: String) -> void :
	if world.player == null:
		return
	if nm.begins_with("dep_go:"):
		var xy: PackedStringArray = nm.substr(7).split(",")
		if xy.size() < 2:
			return
		var cell: = Vector2i(int(xy[0]), int(xy[1]))
		_deselect()
		cam_lock = false
		if cam.zoom.x < 1.0:
			cam.set_zoom_at(MapCamera.zk(2.0), cam.view_size() * 0.5)
		cam.center_on(Vector2(cell * GameWorld.CELL))
		var dep: Dictionary = world.econ.deposit_at(cell, 1)
		if not dep.is_empty():
			selected_dep = dep
	else:
		var fid: int = int(nm.substr(7))
		var f: Facility = null
		for g: Facility in world.mil.facilities:
			if g.id == fid:
				f = g
				break
		if f == null or f.country_id != world.player.id:
			hud.show_toast("Этой постройки больше нет")
			return
		_deselect()
		cam_lock = false
		if cam.zoom.x < 1.0:
			cam.set_zoom_at(MapCamera.zk(2.0), cam.view_size() * 0.5)
		cam.center_on(f.center_px())
		if f.kind == Facility.Kind.BARRACKS and world.mil.alive(f) and f.restore_t <= 0.0 and hud.get("army_ux") != null:
			hud.army_ux.open_bar(f.id)
		else:
			selected_fac = f
	UiKit.snd("ui_select")
	if not _res_go_told:
		_res_go_told = true
		hud.show_toast("Назад к списку — кнопка «Склад» вверху")


func _confirm_mode(m: int) -> bool:
	if not GameConfig.confirm_actions:
		return false
	if Input.is_key_pressed(KEY_SHIFT) and (BUILD_KIND.has(m) or m == Mode.MODULE):
		return false
	if m == Mode.TRENCH_H or m == Mode.TEETH_H:
		return false
	if m == Mode.RAIL_ST:
		return true
	return BUILD_KIND.has(m) or m in [Mode.CAPITAL, Mode.TOWN, Mode.SATELLITE, Mode.OPERATION, Mode.ORDER, Mode.RECON, Mode.ATTACK, Mode.MODULE, Mode.MOVE_ALL, Mode.EXPEDITION]


func _build_line_now(kind: int, cells: Array[Vector2i]) -> void :
	_sim("mil", "build_line", [kind, cells, world.player], func(r: Variant) -> void :
		if r != null:
			hud.show_toast(Loc.n(cells.size(), "%s: копают %d клетку", "%s: копают %d клетки", "%s: копают %d клеток") % [Loc.t("Окоп") if kind == Facility.Kind.TRENCH_H else Loc.t("Зубы дракона"), cells.size()]))



func _pend_text() -> String:
	var m: int = int(_pend.get("mode", mode))
	if String(_pend.get("kind", "")) == "rail":
		return RB.pend_text(self, _pend)
	if m == Mode.RAIL_ST and _pend.has("wp"):
		return RB.station_text(self, _pend["wp"])
	match String(_pend.get("kind", "")):
		"demolish":
			var dfc: Facility = _pend["fac"]
			var dback: int = world.mil.demolish_refund(dfc)
			var dn: int = world.army.units_of(dfc).size() if dfc.kind == Facility.Kind.BARRACKS else 0
			return Loc.t("Разрушить: %s?%s%s") % [Loc.t(Military.title_of(dfc.kind)), Loc.t(" Вернём %d") % dback if dback > 0 else Loc.t(" Без возврата"), Loc.t(" · армия (%d) распустится") % dn if dn > 0 else ""]
		"line":
			var k: int = int(BUILD_KIND[m])
			return Loc.n((_pend["cells"] as Array).size(), "%s: %d клетка · %d", "%s: %d клетки · %d", "%s: %d клеток · %d") % [Loc.t("Окоп") if k == Facility.Kind.TRENCH_H else Loc.t("Зубы дракона"), (_pend["cells"] as Array).size(), Military.cost_of(k) * (_pend["cells"] as Array).size()]
		"op":
			var pv: Dictionary = world.ops.preview(op_from, _pend["wp"], -1) if op_from != null else {}
			return Loc.t("Движение: %s") % Loc.t(String(pv.get("text", "")))
	if BUILD_KIND.has(m) or m == Mode.MODULE:
		var kind: int = module_kind if m == Mode.MODULE else int(BUILD_KIND[m])
		if kind == Facility.Kind.MINE and _pend.has("wp") and world.get("econ") != null:
			var cell_pt: = Vector2i(floori((_pend["wp"] as Vector2).x / GameWorld.CELL), floori((_pend["wp"] as Vector2).y / GameWorld.CELL))
			if not world.econ.deposit_near(cell_pt, 3, ["uranium"]).is_empty():
				kind = Facility.Kind.URANIUM_MINE
		var bc: Dictionary = Economy.build_cost(kind)
		if world.player != null and world.mil.has_method("price_of") and m != Mode.MODULE:
			var sp335: int = world.mil.price_of(kind, world.player)
			if sp335 != int(bc.get("money", 0)) and bc.has("money"):
				bc = bc.duplicate()
				bc["money"] = sp335
		var t: String = "%s · %s" % [Military.title_of(kind), Economy.cost_text(bc)]
		var ser335: String = (preload("res://ui/ui24/army_budget.gd")).series_line(world, kind) if m != Mode.MODULE and _pend_why() == "" else ""
		if ser335 != "":
			t += "\n" + ser335
		if world.player != null and not world.player.has_res(bc) and world.econ.has_method("can_substitute") and world.econ.can_substitute(bc, world.player):
			t += " · " + world.econ.substitute_note(bc, world.player).to_lower()
		if m != Mode.MODULE and _pend.has("wp") and world.mil.has_method("detour_note"):

			var dwp: Vector2 = _pend["wp"]
			var dnote: String = world.mil.detour_note(kind, Military.nw_for(kind, Vector2i(floori(dwp.x / GameWorld.CELL), floori(dwp.y / GameWorld.CELL))))
			if dnote != "" and _pend_why() == "":
				t += "\n" + dnote
		return t
	match m:
		Mode.CAPITAL:
			return Loc.t("Основать столицу здесь")
		Mode.TOWN:
			return Loc.t("Основать город · %d") % Military.town_cost(world.player.towns_founded if world.player != null else 0)
		Mode.SATELLITE:
			return Loc.t("Спутниковый снимок · %d") % int(world.vision.satellite_cost())
		Mode.RECON:
			return Loc.t("Разведдрон сюда")
		Mode.EXPEDITION:
			var wpe: Vector2 = _pend["wp"]
			var pv3: Dictionary = world.naval.expedition_preview(exp_port, Vector2i(floori(wpe.x / GameWorld.CELL), floori(wpe.y / GameWorld.CELL))) if exp_port != null else {}
			return String(pv3.get("text", "Колония"))
		Mode.ORDER:
			var oi: Dictionary = world.ops.order_info(order_kind)
			return "%s · %s" % [String(oi.get("name", "")), String(oi.get("cost_text", ""))]
		Mode.ATTACK:
			return Loc.t("Наступление на этот город")
		Mode.MOVE_ALL:
			var pa: Dictionary = world.ops.preview_all(world.player.id, _pend["wp"])
			return Loc.t("Все армии: %s") % Loc.t(String(pa.get("text", "")))
		Mode.OPERATION:
			var pv2: Dictionary = world.ops.preview(op_from, _pend["wp"], -1) if op_from != null else {}
			return Loc.t("Движение: %s") % Loc.t(String(pv2.get("text", "")))
	return Loc.t("Подтвердить")


func _show_pend() -> void :
	var why: String = _pend_why()
	var txt: String = _pend_text()
	var ok: bool = why == ""
	var pm: int = int(_pend.get("mode", mode))
	if ok and String(_pend.get("kind", "")) == "tap" and world.player != null and (pm == Mode.OPERATION or pm == Mode.MOVE_ALL):

		var pv: Dictionary = {}
		if pm == Mode.OPERATION and op_from != null:
			pv = world.ops.preview(op_from, _pend["wp"], -1)
		elif pm == Mode.MOVE_ALL:
			pv = world.ops.preview_all(world.player.id, _pend["wp"])
		if not pv.is_empty() and not bool(pv.get("ok", true)):
			ok = false
	hud.show_confirm(txt + ("\n✕ " + why if why != "" and not txt.contains(why) else ""), ok)
	if _ghost != null:
		_ghost.queue_redraw()



func _pend_why() -> String:
	if String(_pend.get("kind", "")) == "rail" and world.player != null:
		return RB.pend_why(self, _pend)
	var m: int = int(_pend.get("mode", mode))
	if m == Mode.CAPITAL and _pend.has("wp"):
		var C: float = float(GameWorld.CELL)
		var cell: Vector2i = Vector2i(floori((_pend["wp"] as Vector2).x / C), floori((_pend["wp"] as Vector2).y / C))
		if world.get("data") != null and not world.data.inside(cell.x, cell.y):
			return Loc.t("За пределами карты")
		var pl: Dictionary = world.can_found_city(cell, City.Kind.CAPITAL, true)
		if not bool(pl.get("ok", false)):
			return Loc.t("Неподходящее место для столицы (вода или препятствия)")
		return ""
	if String(_pend.get("kind", "")) != "tap" or world.player == null:
		return ""
	if m == Mode.RAIL_ST:
		return RB.station_why(self, _pend["wp"])
	if m == Mode.EXPEDITION and exp_port != null:
		var wpx: Vector2 = _pend["wp"]
		return String(world.naval.can_expedition(exp_port, Vector2i(floori(wpx.x / GameWorld.CELL), floori(wpx.y / GameWorld.CELL))))
	if not (BUILD_KIND.has(m) or m == Mode.MODULE):
		return ""
	var kind: int = module_kind if m == Mode.MODULE else int(BUILD_KIND[m])
	var C: float = float(GameWorld.CELL)
	var wp: Vector2 = _pend["wp"]
	var cell: = Vector2i(floori(wp.x / C), floori(wp.y / C))
	if kind == Facility.Kind.MINE and world.get("econ") != null and not world.econ.deposit_near(cell, 3, ["uranium"]).is_empty():
		kind = Facility.Kind.URANIUM_MINE
	if kind == Facility.Kind.NAVAL_BASE and world.get("navy") != null:
		cell = _navy_snap(cell)
	return String(world.mil.check_place(kind, Military.nw_for(kind, cell), world.player, module_port if m == Mode.MODULE else null, false))



func _demolish_now(f: Facility) -> void :
	if f == null or world.player == null:
		return
	var nm: String = Military.title_of(f.kind)
	var at: Vector2 = f.center_px() if not f.is_line() or not f.cells.is_empty() else Vector2.INF
	_sim("mil", "demolish", [world.player, f], func(r: Variant) -> void : _demolished(r, nm, at))



func _demolished(r: Variant, nm: String, at: Vector2) -> void :
	if _why(r) != "":
		hud.show_toast(_why(r))
		UiKit.snd("ui_error")
		return
	if selected_fac != null and world.mil.is_demolished(selected_fac):
		_deselect()
	for nmv: String in ["module_port", "op_from", "garrison_from", "attack_from", "exp_port", "_auto_card", "selected_intel"]:
		var rf: Variant = get(nmv)
		if rf is Facility and world.mil.is_demolished(rf as Facility):
			set(nmv, null)
	if at.is_finite():
		world.fx.spawn("dust_s", at, 6)
	Sfx.play("ui_build", at if at.is_finite() else cam.position)
	var back: int = world.mil.last_demolish_refund
	hud.show_toast(Loc.msg(Loc.mk("Разрушено: %s%s", [nm, " · +%d" % back if back > 0 else ""])))
	_plan_refresh()



func _plan_refresh() -> void :
	if world.get("guide") != null and world.guide.has_method("invalidate"):
		world.guide.invalidate()
	hud._plan_t = 0.0
	hud._plan_sig = ""


func _pend_cancel() -> void :
	_pend = {}
	hud.hide_confirm()
	if world.get("ops") != null:
		world.ops.preview_arrow = {}
		world.ops.preview_order = {}
	if _ghost != null:
		_ghost.queue_redraw()


func _ghost_why(kind: int, nw: Vector2i) -> String:
	var key: Array = [kind, nw, world.econ.get("_nav_ver"), world.rail.edges.size() if world.rail != null else 0, world.mil.facilities.size(), world.player.money, world.player.wood]
	if key == _gw_key and Time.get_ticks_msec() - _gw_t < 3000:
		return _gw_why
	_gw_key = key
	_gw_t = Time.get_ticks_msec()
	_gw_why = world.mil.check_place(kind, nw, world.player, null, false)
	return _gw_why



func _draw_ghost() -> void :
	var m: int = int(_pend.get("mode", mode))
	if world.player == null and mode != Mode.CAPITAL and m != Mode.CAPITAL:
		return
	if world.player != null:
		_ghost_own_rings()
	if RB.draw(self, _ghost):
		return
	var shift_active: bool = Input.is_key_pressed(KEY_SHIFT)
	var wp: Vector2 = Vector2.INF
	if not _pend.is_empty():
		if shift_active and (BUILD_KIND.has(m) or m == Mode.MODULE):
			_pend_cancel()
			var hovered_shift: Control = get_viewport().gui_get_hovered_control()
			if hovered_shift != null:
				return
			wp = cam.screen_to_world(get_viewport().get_mouse_position())
		else:
			wp = _pend["wp"]
	elif (shift_active or repeat_building) and (BUILD_KIND.has(m) or m == Mode.MODULE or m == Mode.CAPITAL or m == Mode.TOWN):
		var hovered: Control = get_viewport().gui_get_hovered_control()
		if hovered != null:
			return
		wp = cam.screen_to_world(get_viewport().get_mouse_position())
	else:
		return

	var C: float = float(GameWorld.CELL)
	var cell: = Vector2i(floori(wp.x / C), floori(wp.y / C))
	if world != null and world.data != null and not world.data.inside(cell.x, cell.y):
		return

	var ok_col: = Color(0.35, 1.0, 0.45, 0.45)
	var bad_col: = Color(1.0, 0.3, 0.25, 0.45)
	if not _pend.is_empty():
		match String(_pend["kind"]):
			"demolish":
				var gf: Facility = _pend["fac"]
				if gf.is_line():
					for c: Vector2i in gf.cells + gf.pending:
						_ghost.draw_rect(Rect2(Vector2(c) * C, Vector2(C, C)), Color(1.0, 0.3, 0.25, 0.5))
				else:
					_ghost.draw_rect(Rect2(Vector2(gf.cell) * C, Vector2(gf.size) * C), Color(1.0, 0.3, 0.25, 0.35))
					_ghost.draw_rect(Rect2(Vector2(gf.cell) * C, Vector2(gf.size) * C), Color(1.0, 0.3, 0.25, 0.9), false, 1.0)
				return
			"line":
				for c: Vector2i in _pend["cells"]:
					_ghost.draw_rect(Rect2(Vector2(c) * C, Vector2(C, C)), Color(1.0, 0.85, 0.3, 0.45))
				return
			"op":
				return

	if BUILD_KIND.has(m) or m == Mode.MODULE:
		var kind: int = module_kind if m == Mode.MODULE else int(BUILD_KIND[m])
		if kind == Facility.Kind.MINE and world.get("econ") != null and not world.econ.deposit_near(cell, 3, ["uranium"]).is_empty():
			kind = Facility.Kind.URANIUM_MINE
		if kind == Facility.Kind.NAVAL_BASE and world.get("navy") != null:
			cell = _navy_snap(cell)
		var nw: Vector2i = Military.nw_for(kind, cell)
		var sz: Vector2i = Military.size_of(kind)
		var why: String = _ghost_why(kind, nw) if m != Mode.MODULE and Military.detours(kind) else world.mil.check_place(kind, nw, world.player, module_port if m == Mode.MODULE else null, false)
		var r: = Rect2(Vector2(nw) * C, Vector2(sz) * C)
		var spr_ok: bool = false
		if kind == Facility.Kind.NAVAL_BASE and world.get("atlas_navy1") is SpriteAtlas:

			var na: SpriteAtlas = world.atlas_navy1
			var vs: String = Navy.variant_sprite(Navy.cur)
			if na.has(vs):
				var ni: Dictionary = na.info(vs)
				var nr: Rect2 = na.rect(vs, 0)
				var org: Vector2 = Vector2(r.position.x, r.end.y) - Vector2(float(ni.get("ax", 0)), float(ni.get("ay", nr.size.y)))
				_ghost.draw_rect(r, Color(ok_col, 0.14) if why == "" else Color(bad_col, 0.2))
				_ghost.draw_texture_rect_region(na.texture, Rect2(org, nr.size), nr, Color(0.72, 1.0, 0.78, 0.66) if why == "" else Color(1.0, 0.48, 0.42, 0.66))
				spr_ok = true
		elif world != null and world.get("spr_index") != null and Military.SPRITES.has(kind):
			var sp_name: String = String(Military.SPRITES[kind])
			if world.spr_index.has(sp_name):
				var sid: int = int(world.spr_index[sp_name])
				if sid >= 0 and sid < world.spr_tex.size() and sid < world.spr_rect.size() and sid < world.spr_anchor.size() and sid < world.spr_fd.size():
					var sr: Rect2 = world.spr_rect[sid]
					var sa: Vector2 = world.spr_anchor[sid]
					var s_fd: int = world.spr_fd[sid]
					var stex: Texture2D = world.spr_tex[sid]
					if stex != null:
						var spos: Vector2 = Vector2(nw.x * C - sa.x, (nw.y + s_fd) * C - sa.y)
						_ghost.draw_rect(r, Color(ok_col, 0.18) if why == "" else Color(bad_col, 0.22))
						_ghost.draw_texture_rect_region(stex, Rect2(spos, sr.size), Rect2(sr.position.x, sr.position.y, sr.size.x, sr.size.y), Color(0.72, 1.0, 0.78, 0.72) if why == "" else Color(1.0, 0.48, 0.42, 0.72))
						spr_ok = true
		if not spr_ok:
			_ghost.draw_rect(r, ok_col if why == "" else bad_col)
		if kind == Facility.Kind.NAVAL_BASE and r.get_center().distance_to(wp) > C * 3.0:

			_ghost.draw_line(wp, r.get_center(), Color(1, 1, 1, 0.7), 2.0 / cam.zoom.x)
			_ghost.draw_circle(wp, 4.0 / cam.zoom.x, Color(1, 1, 1, 0.8))
		var edge: Color = (Color(0.75, 1.0, 0.8) if why == "" else Color(1.0, 0.55, 0.5))
		_ghost.draw_rect(r, edge, false, 2.0 / cam.zoom.x)
		if m != Mode.MODULE:
			_ghost_cover(kind, r.get_center())
		return
	var rad: float = 40.0
	match m:
		Mode.CAPITAL, Mode.TOWN:
			rad = float(GameWorld.CELL) * (34.0 if m == Mode.CAPITAL else 20.0)
			if m == Mode.CAPITAL:
				var why_cap: String = ""
				if not _pend.is_empty():
					why_cap = _pend_why()
				else:
					var pl: Dictionary = world.can_found_city(cell, City.Kind.CAPITAL, true)
					if not bool(pl.get("ok", false)):
						why_cap = Loc.t("Неподходящее место для столицы (вода или препятствия)")
				var cap_ok: bool = why_cap == ""
				var cap_fill: Color = Color(0.2, 0.9, 0.35, 0.22) if cap_ok else Color(0.9, 0.25, 0.2, 0.22)
				var cap_ring: Color = Color(0.2, 0.95, 0.35, 0.95) if cap_ok else Color(0.95, 0.3, 0.2, 0.95)
				_ghost.draw_circle(wp, rad, cap_fill)
				_ghost.draw_arc(wp, rad, 0.0, TAU, 64, cap_ring, 2.5 / cam.zoom.x)
				var k_cap: float = 12.0 / cam.zoom.x
				_ghost.draw_line(wp - Vector2(k_cap, 0), wp + Vector2(k_cap, 0), cap_ring, 2.0 / cam.zoom.x)
				_ghost.draw_line(wp - Vector2(0, k_cap), wp + Vector2(0, k_cap), cap_ring, 2.0 / cam.zoom.x)
				return
			else:
				_ghost.draw_circle(wp, rad, Color(0.35, 1.0, 0.45, 0.12))
		Mode.SATELLITE:
			rad = 220.0
		Mode.RECON:
			rad = 150.0
		Mode.ORDER:
			rad = float(world.ops.order_info(order_kind).get("radius", 60.0))
	_ghost.draw_arc(wp, rad, 0.0, TAU, 48, Color(1.0, 0.85, 0.3, 0.9), 2.0 / cam.zoom.x)
	var k: float = 10.0 / cam.zoom.x
	_ghost.draw_line(wp - Vector2(k, 0), wp + Vector2(k, 0), Color(1, 0.85, 0.3), 2.0 / cam.zoom.x)
	_ghost.draw_line(wp - Vector2(0, k), wp + Vector2(0, k), Color(1, 0.85, 0.3), 2.0 / cam.zoom.x)





func _ghost_cover(kind: int, c: Vector2) -> void :
	var z: float = cam.zoom.x
	var ring: Dictionary = RouteOverlay.cover_ring(kind)
	var rr: float = float(ring["r"])
	var col: Color = ring["col"]
	if rr <= 0.0:
		col = Palette.c("amber")
		match kind:
			Facility.Kind.TEL:
				rr = Military.MISSILE_RANGE
			Facility.Kind.DRONE_PORT:
				rr = Military.RANGE_PX
			Facility.Kind.COASTAL_ASM:
				rr = Navy.COAST_RANGE
	if rr <= 0.0:
		return


	_ghost.draw_arc(c, rr - 5.0 / z, 0.0, TAU, 128, Color(col, 0.18), 10.0 / z)
	_ghost.draw_arc(c, rr, 0.0, TAU, 128, Color(Palette.c("ui_rubber"), 0.85), 3.0 / z)
	_ghost.draw_arc(c, rr, 0.0, TAU, 128, col, 1.0 / z)




func _ghost_own_rings() -> void :
	if not BUILD_KIND.has(mode):
		return
	var kind: int = int(BUILD_KIND[mode])
	var ring: Dictionary = RouteOverlay.cover_ring(kind)
	var rr: float = float(ring["r"])
	if rr <= 0.0:
		return
	var col: Color = ring["col"]
	var z: float = cam.zoom.x
	for f: Facility in world.mil.facilities:
		if f.kind == kind and f.country_id == world.player.id and world.mil.alive(f):
			_ghost.draw_arc(f.center_px(), rr, 0.0, TAU, 96, Color(Palette.c("ui_rubber"), 0.35), 3.0 / z)
			_ghost.draw_arc(f.center_px(), rr, 0.0, TAU, 96, Color(col, 0.4), 1.0 / z)


func _is_strike_mode(m: int) -> bool:
	return m == Mode.TARGET or m == Mode.MISSILE or m == Mode.SHIP_CR or m == Mode.CR_TARGET or m == Mode.HYP_TARGET


func _plan_targets() -> Array:
	var out: Array = []
	for t: Dictionary in plan_list:
		out.append({"pos": t["pos"], "n": int(t["n"]), "wps": t.get("wps", [])})
	if plan_has_target:
		out.append({"pos": plan_target, "n": plan_count, "wps": plan_wps.duplicate()})
	return out










func _hold_tap(wp: Vector2) -> bool:
	if world.get("hold") == null or world.player == null or world.player.eliminated or follow != null or cam.zoom.x < 1.0:
		return false
	var oid: int = int(world.hold.building_at(wp))
	if oid < 0 or not bool(world.hold.may_hold(world.player.id, int(world.hold.owner_of(oid)))):
		return false
	_deselect()
	(load("res://ui/ui24/hold_card.gd") as GDScript).call("open", hud, oid)
	UiKit.snd("ui_select")
	return true



func _hold_hit(pos: Vector2, wp: Vector2) -> bool:
	if world.get("hold") == null or cam.zoom.x < 1.0:
		return false
	var hs: Dictionary = world.hold.holds
	if hs.is_empty():
		return false
	var oid: int = -1
	for un: Unit in world.army.units:
		if un.country_id == world.player.id and un.alive() and cam.world_to_screen(un.pos).distance_to(pos) < GRAB_R:
			var o2: int = int(world.hold._uh.get(un.id, -1))
			if o2 >= 0:
				oid = o2
				break
	if oid < 0:
		var b: int = int(world.hold.building_at(wp))
		if b >= 0 and hs.has(b) and int(hs[b]["c"]) == world.player.id:
			oid = b
	if oid < 0 or not hs.has(oid):
		return false
	_deselect()
	(load("res://ui/ui24/hold_card.gd") as GDScript).call("open", hud, oid)
	UiKit.snd("ui_select")
	return true



func hold_begin(fid: int) -> void :
	var f: Facility = AGroups303.fac(world, fid)
	if f == null or world.player == null or f.country_id != world.player.id:
		return
	if int(world.hold.free_count(f)) <= 0:
		hud.show_toast(Loc.msg(Loc.mk("Армия №%d: нет свободной пехоты (стрелки, ПТУР, штурмовики)", [f.army_no])))
		UiKit.snd("ui_error")
		return
	var aux: Variant = hud.get("army_ux")
	if aux != null and is_instance_valid(aux):
		aux.close_view()
	_deselect()
	hold_from = f
	_set_mode(Mode.HOLD)
	UiKit.snd("ui_select")


func _hold_mode_tap(wp: Vector2) -> void :
	if hold_from == null or hold_from.country_id != world.player.id:
		_set_mode(Mode.NONE)
		return
	var oid: int = int(world.hold.building_at(wp, true))
	if oid < 0:
		_set_mode(Mode.NONE)
		return
	if bool(world.hold.is_ruin(oid)):
		hud.show_toast("Дом разрушен — в руины не зайти")
		UiKit.snd("ui_error")
		return
	if not bool(world.hold.may_hold(world.player.id, int(world.hold.owner_of(oid)))):
		hud.show_toast("Мирная чужая страна: занять дом можно у себя, у врага, у союзника или с правом прохода")
		UiKit.snd("ui_error")
		return
	var hf: Facility = hold_from
	var r: Rect2i = world.object_rect(oid)
	var at: Vector2 = Vector2((r.position + Vector2i(r.size.x / 2, r.size.y)) * GameWorld.CELL)
	_sim("hold", "occupy", [oid, hf, world.player.id], func(res: Variant) -> void :
		if res is String:
			hud.show_toast(String(res))
			UiKit.snd("ui_error")
		else:
			hud.show_toast(Loc.msg(Loc.mk("Армия №%d: %d бойц. занимают дом", [hf.army_no, int(res)])))
			overlay.ripple(at, "intercept_cyan")
			UiKit.snd("ui_select")
			if mode == Mode.HOLD and int(world.hold.free_count(hf)) == 0:
				_set_mode(Mode.NONE))


func _sim(path: String, method: String, args: Array, cb: Callable = Callable()) -> void :
	net.call_sim(path, method, args, cb)




func _why(r: Variant) -> String:
	if r == null:
		return "Команда не выполнена"
	return String(r) if r is String else ""



func _on_built(r: Variant, kind: int, shift_was_pressed: bool = false) -> void :
	var f: Facility = r as Facility
	if f == null:
		if _why(r) != "":
			hud.show_toast(_why(r))
			UiKit.snd("ui_error")
		return
	hud.show_toast(Loc.msg(Loc.mk("Построено: %s", [Loc.t(Military.title_of(kind))])))
	UiKit.snd("ui_build")
	var is_shift: bool = shift_was_pressed or Input.is_key_pressed(KEY_SHIFT)
	var keep_mode: int = mode if (repeat_building or is_shift) and BUILD_KIND.has(mode) and int(BUILD_KIND[mode]) == kind else Mode.NONE
	_set_mode(keep_mode)
	if keep_mode == Mode.NONE:
		if kind == Facility.Kind.DRONE_PORT or kind == Facility.Kind.MISSILE_FACTORY or kind == Facility.Kind.AIRFIELD or kind == Facility.Kind.BARRACKS or kind == Facility.Kind.PORT or kind == Facility.Kind.DRONE_FACTORY:
			selected_fac = f
			_auto_card = f
			_auto_card_t = 15.0
	if _ghost != null:
		_ghost.queue_redraw()
