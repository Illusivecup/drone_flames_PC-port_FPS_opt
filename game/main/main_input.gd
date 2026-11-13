extends "res://game/main/main_strike.gd"


func _tap(pos: Vector2) -> void :
	_auto_card = null
	var wp: Vector2 = cam.screen_to_world(pos)

	var csh: Variant = hud.get("ui24_sheet")
	if csh != null and is_instance_valid(csh) and (csh as Object).has_method("world_tap") and bool(csh.world_tap(pos, wp)):
		return


	var ad: Variant = hud.get("army_dock")
	if ad != null and is_instance_valid(ad) and ad.is_placing() and world.player != null and not world.player.eliminated:
		ad.set_target(wp)
		return
	var ndk: Variant = hud.get("navy_dock")
	if ndk != null and is_instance_valid(ndk) and ndk.is_placing() and world.player != null and not world.player.eliminated:
		ndk.set_target(wp)
		return

	var aux: Variant = hud.get("army_ux")
	if mode == Mode.NONE and aux != null and is_instance_valid(aux) and aux.map_tap(pos, wp):
		return

	if mode == Mode.NONE and ndk != null and is_instance_valid(ndk) and ndk.has_method("map_tap") and world.player != null and not world.player.eliminated and ndk.map_tap(pos, wp):
		return

	var apn: Variant = hud.get("army_pennants")
	if mode == Mode.NONE and apn != null and is_instance_valid(apn) and apn.has_method("map_tap") and apn.map_tap(pos):
		return
	var cell: = Vector2i(floori(wp.x / GameWorld.CELL), floori(wp.y / GameWorld.CELL))
	if world.player != null and world.player.eliminated and mode != Mode.NONE:
		_set_mode(Mode.NONE)
		return


	if mode == Mode.NONE and world.get("labels") != null and world.player != null and not _tap_hits_object(pos, cell):
		var lcid: int = world.labels.country_at(pos)
		if lcid >= 0:
			if lcid == world.player.id:
				hud.open_economy()
			else:
				hud.dip_open = lcid
				hud._dip_scroll_to = lcid
				hud.open_diplomacy()
			UiKit.snd("ui_open")
			return
	if not world.data.inside(cell.x, cell.y):
		return


	if mode == Mode.NONE and _far_zoom() and world.player != null and follow == null and selected_fac == null:
		var oid: int = world.data.get_owner_id(cell.x, cell.y)
		var oc: Country = world.country_by_id(oid) if oid > 0 and oid != world.player.id else null
		var hf: Facility = world.mil.facility_at(cell)
		var own_hit: bool = _unit_hit(pos) != null or (hf != null and hf.country_id == world.player.id)
		if oc != null and not oc.eliminated and not own_hit and _dep_pin_hit(pos).is_empty():
			hud.dip_open = oid
			hud._dip_scroll_to = oid
			hud.open_diplomacy()
			UiKit.snd("ui_open")
			return

		if oid == world.player.id and cam.is_strategic() and not own_hit and hud.has_method("open_my_state"):
			hud.open_my_state()
			UiKit.snd("ui_open")
			return
	if not _pend.is_empty() and (not _confirming or Input.is_key_pressed(KEY_SHIFT)):
		_pend = {}
		hud.hide_confirm()
		if _ghost != null:
			_ghost.queue_redraw()
	if not _confirming and _confirm_mode(mode):

		_pend = {"kind": "tap", "wp": wp, "mode": mode}
		if mode == Mode.OPERATION and op_from != null:
			world.ops.preview_arrow = {"f": op_from, "to": wp, "kind": -1}
		elif mode == Mode.ORDER:
			world.ops.preview_order = {"kind": order_kind, "pos": wp}
		_show_pend()
		UiKit.snd("ui_select")
		return
	match mode:
		Mode.CAPITAL:
			var on_cap: Callable = func(r: Variant) -> void :
				var cap: City = r as City
				if cap != null:
					hud.show_toast(Loc.msg(Loc.mk("Столица основана: %s", [Loc.name(cap.name)])))
					UiKit.snd("ui_build")
					_set_mode(Mode.NONE)
					hud.refresh()
			if net.in_match:
				net.issue({"k": "cap", "cell": cell}, on_cap)
			else:
				on_cap.call(world.place_player_capital(cell))
		Mode.TOWN:
			var on_town: Callable = func(r: Variant) -> void :
				var t: City = r as City
				if t != null:
					hud.show_toast(Loc.msg(Loc.mk("Основан город %s (-%d)", [Loc.name(t.name), Military.town_cost(world.player.towns_founded - 1)])))
					var is_shift_town: bool = Input.is_key_pressed(KEY_SHIFT)
					_set_mode(Mode.TOWN if is_shift_town else Mode.NONE)
					hud.refresh()
			if net.in_match:
				net.issue({"k": "town", "cell": cell}, on_town)
			else:
				on_town.call(world.player_found_town(cell))
		Mode.STRIKE:
			if not net.in_match:
				world.strike(cell)
		Mode.SATELLITE:
			var sc: int = int(world.vision.satellite_cost())
			var whys: String = world.vision.satellite(wp)
			if whys != "":
				hud.show_toast(whys)
				UiKit.snd("ui_error")
				return
			UiKit.snd("radar_ping")
			hud.show_toast(Loc.msg(Loc.mk("Спутниковый снимок: -%d", [sc])))
		Mode.RAIL_ST:
			RB.station_go(self, cell)
		Mode.RAIL_LINE:
			RB.tap(self, wp)
		Mode.TRENCH_H, Mode.TEETH_H:
			hud.show_toast(Loc.msg(Loc.mk("Проведите пальцем линию — %s строится по ней", [(Loc.t("окоп") if mode == Mode.TRENCH_H else Loc.t("зубы дракона"))])))
		Mode.MOVE_ALL:
			_sim("ops", "start_all", [world.player.id, wp], func(r: Variant) -> void :
				var ra: Dictionary = r if r is Dictionary else {}
				var rs: Array = ra.get("reasons", [])
				if int(ra.get("started", 0)) > 0:
					hud.show_toast(Loc.n(int(ra["started"]), "Движение: %d армия", "Движение: %d армии", "Движение: %d армий") % int(ra["started"]) + ("" if rs.is_empty() else " · " + Loc.t(String(rs[0]))))
					overlay.ripple(wp, "intercept_cyan")
					_set_mode(Mode.NONE)
				else:
					hud.show_toast(String(rs[0]) if not rs.is_empty() else "Нет армий для движения")
					UiKit.snd("ui_error"))
		Mode.GARRISON:
			var gf: Facility = world.mil.facility_at(cell)
			if garrison_from == null or not world.mil.alive(garrison_from):
				_set_mode(Mode.NONE)
			elif gf == null or gf.country_id != world.player.id or not Army.is_trench(gf.kind):
				hud.show_toast("Тапните свой окоп или блиндаж")
			else:
				var gfrom: Facility = garrison_from
				_sim("army", "occupy", [gf, world.player.id, false, gfrom], func(r: Variant) -> void :
					var ng: int = int(r) if r != null else 0
					if ng > 0:
						hud.show_toast(Loc.n(ng, "Армия №%d: %d боец → %s", "Армия №%d: %d бойца → %s", "Армия №%d: %d бойцов → %s") % [gfrom.army_no, ng, Loc.t(Military.title_of(gf.kind)).to_lower()])
						overlay.ripple(gf.center_px(), "intercept_cyan")
						UiKit.snd("ui_select")
					else:
						hud.show_toast(Loc.msg(Army.occupy_m) if world.army.occupy_why != "" else Loc.t("Мест нет или свободных бойцов этой армии не осталось"))
						UiKit.snd("ui_error"))
		Mode.HOLD:
			_hold_mode_tap(wp)
		Mode.OPERATION:
			_op_start(wp)
		Mode.ORDER:
			var ok_k: int = order_kind
			_sim("ops", "order", [world.player.id, ok_k, wp], func(r: Variant) -> void :
				if _why(r) != "":
					hud.show_toast(_why(r))
					UiKit.snd("ui_error")
				else:
					hud.show_toast(Loc.msg(Loc.mk("Приказ: %s", [Loc.t(String(world.ops.order_info(ok_k).get("name", "")))])))
					overlay.ripple(wp, "alert_red")
					_set_mode(Mode.NONE))
		Mode.EXPEDITION:
			if exp_port == null:
				hud.show_toast("Нет порта")
				UiKit.snd("ui_error")
				return
			_sim("naval", "launch_expedition", [exp_port, cell], func(r: Variant) -> void :
				if _why(r) != "":
					hud.show_toast(_why(r))
					UiKit.snd("ui_error")
				else:
					hud.show_toast("Экспедиция вышла в море")
					overlay.ripple(wp, "amber")
					_set_mode(Mode.NONE))
		Mode.RECON:
			_sim("recon", "launch", [world.player.id, wp], func(r: Variant) -> void :
				if _why(r) != "":
					hud.show_toast(_why(r))
					UiKit.snd("ui_error")
				else:
					overlay.ripple(wp, "intercept_cyan")
					UiKit.snd("radar_ping")
					_set_mode(Mode.NONE))
		Mode.ATTACK:
			var tc: City = world.city_at_cell(cell)
			if tc == null:
				hud.show_toast("Тапните по городу")
				return
			if tc.country_id == world.player.id:
				hud.show_toast("Это ваш город")
				return
			if world.diplo.allied(world.player.id, tc.country_id):
				hud.show_toast("Это город союзника")
				return
			if not world.diplo.at_war(world.player.id, tc.country_id) and world.diplo.war_block_why(world.player.id, tc.country_id) != "":
				hud.show_toast("Война невозможна: войска на чужой земле")
				return
			if not world.diplo.at_war(world.player.id, tc.country_id) and _confirm_city != tc.id:
				_confirm_city = tc.id
				var oc: Country = world.country_by_id(tc.country_id)
				hud.show_toast(Loc.msg(Loc.mk("Это объявит войну: %s. Тап ещё раз", [(Loc.name(oc.name) if oc != null else "")])))
				overlay.ripple(Vector2(tc.center * GameWorld.CELL), "amber")
				return
			_confirm_city = -1
			_sim("army", "order_attack", [world.player.id, tc, attack_from], func(r: Variant) -> void :
				if r == null or int(r) == 0:
					hud.show_toast("Нет войск: постройте казармы")
				else:
					overlay.ripple(Vector2(tc.center * GameWorld.CELL), "alert_red")
					_set_mode(Mode.NONE))
		Mode.HYP_TARGET:
			_missile_tap(pos, wp)
		Mode.FACTORY, Mode.DRONEPORT, Mode.TEL, Mode.MFACTORY, Mode.REFINERY, Mode.POWER, Mode.AIRFIELD, Mode.FARM, Mode.CIV, Mode.MINE, Mode.BARRACKS, Mode.AD_MFG, Mode.AD_SPAAG, Mode.AD_SAM, Mode.AD_PATRIOT, Mode.AD_INT, Mode.AD_RADAR, Mode.AD_EW, Mode.DUGOUT, Mode.SAWMILL, Mode.OIL_RIG, Mode.PORT, Mode.SOLAR_FARM, Mode.NAVBASE, Mode.COASTAL_ASM, Mode.NPP, Mode.UMINE:
			var kind: int = BUILD_KIND[mode]
			if kind == Facility.Kind.MINE and not world.econ.deposit_near(cell, 3, ["uranium"]).is_empty():
				kind = Facility.Kind.URANIUM_MINE
			if kind == Facility.Kind.NAVAL_BASE and world.get("navy") != null:
				cell = _navy_snap(cell)
			var bcost: Dictionary = Economy.build_cost(kind)
			var pl: Country = world.player
			var shift_held: bool = Input.is_key_pressed(KEY_SHIFT)
			if not pl.has_res(bcost) and world.econ.has_method("can_substitute") and world.econ.can_substitute(bcost, pl):

				var placing: String = world.mil.place_why(kind, cell, pl, null, false)
				if placing != "":
					hud.show_toast(placing)
				elif net.in_match or _confirming or shift_held or (_sub_confirm.size() == 3 and int(_sub_confirm[0]) == kind and (_sub_confirm[1] as Vector2i).distance_to(cell) < 3.0 and Time.get_ticks_msec() - int(_sub_confirm[2]) < 8000):
					_sub_confirm = []
					_sim("", "cmd_build_sub", [kind, cell, pl], _on_built.bind(kind, shift_held))
				else:
					_sub_confirm = [kind, cell, Time.get_ticks_msec()]
					hud.show_toast(Loc.msg(Loc.mk("Не хватает: %s. Тапните ещё раз — %s", [pl.missing_res(bcost), world.econ.substitute_note(bcost, pl).to_lower()])))
					UiKit.snd("ui_error")
			else:
				_sim("mil", "build", [kind, cell, world.player], func(r: Variant) -> void :
					if r == null and not pl.has_res(bcost):
						_offer_buy(bcost)
					_on_built(r, kind, shift_held))
		Mode.MODULE:
			if module_port == null or not world.mil.alive(module_port):
				_set_mode(Mode.NONE)
				return
			var mk: int = module_kind
			var mport: Facility = module_port
			var shift_held: bool = Input.is_key_pressed(KEY_SHIFT)
			_sim("mil", "build", [mk, cell, world.player, mport], func(r: Variant) -> void :
				if r != null:
					hud.show_toast(Loc.msg(Loc.mk("Модуль: %s", [Loc.t(Military.title_of(mk))])))
					if not (repeat_building or shift_held or Input.is_key_pressed(KEY_SHIFT)):
						selected_fac = mport
						_set_mode(Mode.NONE)
					elif _ghost != null:
						_ghost.queue_redraw())
		Mode.TARGET:
			_plan_tap(pos, wp)
		Mode.CR_TARGET:
			if _missile_multi():
				_missile_tap(pos, wp)
			else:
				plan_target = wp.floor() + Vector2(0.5, 0.5)
				plan_has_target = true
				overlay.ripple(plan_target, "alert_red")
		Mode.MISSILE:
			_missile_tap(pos, wp)
		Mode.JET_KAB, Mode.JET_CAS:
			_jet_tap(pos, wp)
		Mode.SHIP_CR:
			_missile_tap(pos, wp)
		_:
			_select_tap(pos, wp, cell)



func _far_zoom() -> bool:
	return world.get("labels") != null and cam.zoom.x < 0.7



func _dep_pin_hit(pos: Vector2) -> Dictionary:
	var z: float = cam.zoom.x
	var ps: float = clampf(1.0 / z, 1.0, 4.0) * z
	var best: Dictionary = {}
	var bd: float = 14.0
	for dp: Dictionary in world.econ.deposits:
		if int(dp.get("left", 1)) <= 0:
			continue
		var c: Vector2i = dp["cell"]
		var sp: Vector2 = cam.world_to_screen(Vector2(c) * GameWorld.CELL + Vector2(2, -4)) - Vector2(0, 6) * ps
		var d: float = sp.distance_to(pos)
		if d < bd:
			bd = d
			best = dp
	return world.econ.deposit_at(best["cell"], 0) if not best.is_empty() else {}



func _tap_hits_object(pos: Vector2, cell: Vector2i) -> bool:
	if _unit_hit(pos) != null:
		return true
	if not world.data.inside(cell.x, cell.y):
		return false
	if world.mil.facility_at(cell) != null or world.city_at_cell(cell) != null:
		return true
	for un: Unit in world.army.units:
		if world.player != null and un.country_id == world.player.id and un.alive() and cam.world_to_screen(un.pos).distance_to(pos) < GRAB_R:
			return true
	return false



func _select_tap(pos: Vector2, wp: Vector2, cell: Vector2i) -> void :
	var u: Object = _unit_hit(pos)
	if u == null and world.get("recon") != null:
		u = world.recon.drone_at(wp, cam.zoom.x)
	if u != null:
		follow = u
		cam_lock = true
		selected_fac = null
		_follow_done_t = 0.0
		route_mode = false
		hud.set_key_pressed("route", false)
		hud.set_key_pressed("follow", true)
		return

	if world.vision != null:
		var mf: Facility = world.vision.marker_at(wp, cam.zoom.x)
		if mf != null:
			_deselect()
			selected_intel = mf
			UiKit.snd("ui_select")
			return


	var on_front: bool = hud.get("army_dock") != null and hud.army_dock.front_tap(pos)



	if on_front and world.player != null and follow == null and hud.army_dock.has_method("open_group_card"):
		var close_u: bool = false
		for un0: Unit in world.army.units:
			if un0.country_id == world.player.id and un0.alive() and un0.home != null and cam.world_to_screen(un0.pos).distance_to(pos) < GRAB_R * 0.6:
				close_u = true
				break
		if not close_u:
			var fgid: int = int(hud.army_dock.front_ov.hit(pos)) if hud.army_dock.get("front_ov") != null else -1
			if fgid >= 0:
				_deselect()
				hud.army_dock.open_group_card(fgid)
				return
		on_front = false



	var nb_land: bool = false
	if world.player != null and world.data.inside(cell.x, cell.y) and not Biome.is_water(world.data.get_biome(cell.x, cell.y)):
		var nbf: Facility = world.mil.facility_at(cell)
		nb_land = nbf != null and nbf.kind == Facility.Kind.NAVAL_BASE and nbf.country_id == world.player.id and world.mil.alive(nbf)
	if world.player != null and follow == null and world.get("navy") != null and hud.has_method("open_navy_dock") and not nb_land:
		var bs: Ship = null
		var bds: float = GRAB_R * 1.5
		for sh: Ship in world.navy.ships_of(world.player.id, true):
			var dsh: float = cam.world_to_screen(sh.pos).distance_to(pos)
			if dsh < bds:
				bds = dsh
				bs = sh
		if bs != null:
			_deselect()
			hud.open_navy_dock(bs)
			UiKit.snd("ui_select")
			return


	if world.player != null and follow == null and not on_front and _hold_hit(pos, wp):
		return

	if world.player != null and follow == null and not on_front:
		var bu: Unit = null
		var bdu: float = GRAB_R
		for un: Unit in world.army.units:
			if un.country_id != world.player.id or not un.alive() or un.home == null:
				continue
			var du: float = cam.world_to_screen(un.pos).distance_to(pos)
			if du < bdu:
				bdu = du
				bu = un
		if bu != null and preload("res://game/army_groups.gd").army_alive(world, bu.home) and hud.get("army_ux") != null:
			_deselect()
			hud.army_ux.open_army(bu.home.id)
			UiKit.snd("ui_select")
			return
		if bu != null and preload("res://game/army_groups.gd").army_alive(world, bu.home):
			_deselect()
			selected_fac = bu.home
			army_view = true
			UiKit.snd("ui_select")
			return

	var f: Facility = world.mil.facility_at(cell)
	if f != null and world.player != null and f.country_id == world.player.id and not on_front:
		_deselect()
		if f.kind == Facility.Kind.BARRACKS and world.mil.alive(f) and f.restore_t <= 0.0 and hud.get("army_ux") != null:
			hud.army_ux.open_bar(f.id)
			UiKit.snd("ui_select")
			return
		if f.kind == Facility.Kind.NAVAL_BASE and world.mil.alive(f) and hud.has_method("open_navy_yard"):
			hud.open_navy_yard(f)
			UiKit.snd("ui_select")
			return
		selected_fac = f
		return
	var ac: Aircraft = follow as Aircraft
	if ac != null and ac.state != Aircraft.State.DEAD:
		var pa: Vector2 = wp.floor() + Vector2(0.5, 0.5)
		_sim("mil.air", "order_patrol" if air_patrol_pending else "order_fly", [ac, pa], func(r: Variant) -> void :
			if _why(r) != "":
				hud.show_toast(_why(r))
			else:
				overlay.ripple(pa, "water_coast"))
		air_patrol_pending = false
		return
	var d: Drone = follow as Drone
	if d != null and d.state != Drone.State.DONE and d.state != Drone.State.DIVE:
		var p: Vector2 = wp.floor() + Vector2(0.5, 0.5)
		overlay.ripple(p, "amber")
		_sim("mil", "retarget", [d, p, route_mode], func(r: Variant) -> void :
			if _why(r) != "":
				hud.show_toast(_why(r)))
		return

	if selected_fac != null and Military.is_mobile(selected_fac.kind) and world.mil.alive(selected_fac):
		_sim("mil", "order_move", [selected_fac, cell], func(r: Variant) -> void :
			if _why(r) != "":
				hud.show_toast(_why(r))
			else:
				overlay.ripple(wp.floor() + Vector2(0.5, 0.5), "grass_light"))
		return

	if world.econ.has_method("deposit_at"):
		var rr: int = maxi(2, int(ceilf(GRAB_R / (GameWorld.CELL * cam.zoom.x))))

		var dep: Dictionary = _dep_pin_hit(pos) if _far_zoom() else world.econ.call("deposit_at", cell, rr)
		if not dep.is_empty():
			_deselect()
			selected_dep = dep
			UiKit.snd("ui_select")
			return


	var c: City = _city_tap(pos, cell, true)
	if c == null and cam.zoom.x >= 2.0 and _hold_tap(wp):
		return
	if c == null:
		c = _city_tap(pos, cell)
	if c == null and _hold_tap(wp):
		return
	if c != null:
		_deselect()
		selected_city = c.id
		UiKit.snd("ui_select")
	elif selected_city >= 0:
		_deselect()




func _city_tap(pos: Vector2, cell: Vector2i, label_only: bool = false) -> City:
	if world.city_at_cell(cell) == null and MapDeclutter303b.city_lab.is_empty():
		return null
	for e: Array in MapDeclutter303b.city_lab:
		var wc: Vector2 = e[0]
		var lr: Rect2 = e[1]
		if Rect2(cam.world_to_screen(wc) + lr.position, lr.size).grow(4.0).has_point(pos):
			for ct: City in world.cities:
				if Vector2(ct.center * GameWorld.CELL).distance_to(wc) < 1.0:
					return ct
	if label_only:
		return null
	var best: City = null
	var bd: float = maxf(26.0, 3.0 * GameWorld.CELL * cam.zoom.x)
	for ct2: City in world.cities:
		var d: float = cam.world_to_screen(Vector2(ct2.center * GameWorld.CELL) + Vector2(2.0, 2.0)).distance_to(pos)
		if d < bd:
			bd = d
			best = ct2
	return best



func focus_group(gid: int) -> void :
	_focus = {"gid": gid, "n": 3}





func _focus_tick() -> void :
	_focus["n"] = int(_focus["n"]) - 1
	if int(_focus["n"]) > 0:
		return
	var f: Dictionary = _focus
	_focus = {}
	if world == null or world.player == null or hud == null:
		return
	var p: = Vector2.INF
	if f.has("fid") or f.has("bar"):
		var fid: int = int(f.get("fid", f.get("bar", -1)))
		var fac: Facility = world.mil.facilities[fid] if fid >= 0 and fid < world.mil.facilities.size() else null
		if fac == null:
			return
		p = fac.center_px()
		if f.has("fid"):
			var s: = Vector2.ZERO
			var n: int = 0
			for u: Unit in world.army.units_of(fac):
				s += u.pos
				n += 1
			if n > 0:
				p = s / float(n)
	elif f.has("gid"):
		var g: Dictionary = AGroups303.by_id(world, world.player.id, int(f["gid"]))
		var s2: = Vector2.ZERO
		var n2: int = 0
		for fid2: int in g.get("fids", []):
			var fac2: Facility = AGroups303.fac(world, fid2)
			for u2: Unit in world.army.units_of(fac2):
				s2 += u2.pos
				n2 += 1
		if n2 == 0:
			return
		p = s2 / float(n2)
	if not p.is_finite():
		return
	var vs: Vector2 = cam.view_size()
	var top: float = float(cam.margin_top_px) + 10.0
	var bot: float = vs.y
	if hud.holder != null and hud.holder.is_visible_in_tree():
		bot = hud.holder.get_global_rect().position.y
	if hud.get("army_dock") != null and hud.army_dock.is_open:
		bot = minf(bot, float(hud.army_dock.bottom_top()))
	var sp: Vector2 = cam.world_to_screen(p)
	if sp.y > top + 30.0 and sp.y < bot - 30.0 and sp.x > 24.0 and sp.x < vs.x - 64.0:
		return
	var z: float = maxf(0.01, cam.zoom.x)
	var old: Vector2 = cam.position
	cam.position = p + Vector2(0.0, vs.y * 0.5 - (top + bot) * 0.5) / z
	cam._clamp()
	var to: Vector2 = cam.position
	cam.position = old
	cam_lock = false
	var tw: Tween = create_tween()
	tw.tween_property(cam, "position", to, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)



func _unit_hit(pos: Vector2) -> Object:
	if world.player == null:
		return null
	var best: Object = null
	var bd: float = GRAB_R
	for d: Drone in world.mil.drones:
		if d.country_id != world.player.id or d.state == Drone.State.PARKED or d.state == Drone.State.DONE:
			continue
		var dd: float = cam.world_to_screen(d.pos).distance_to(pos)
		if dd < bd:
			bd = dd
			best = d
	for a: Aircraft in world.mil.air.aircraft:
		if a.country_id != world.player.id or a.state == Aircraft.State.DEAD:
			continue
		var da: float = cam.world_to_screen(a.pos).distance_to(pos) - float(Air.SPEC[a.type]["sel"]) * 0.5
		if da < bd:
			bd = da
			best = a
	for m: Missile in world.mil.missiles:
		if m.country_id != world.player.id:
			continue
		var dm: float = cam.world_to_screen(m.screen_pos()).distance_to(pos)
		if dm < bd:
			bd = dm
			best = m
	return best


func _begin_press(pos: Vector2) -> void :
	if not _cam_plan.is_empty():
		_cam_stop()
	_press_pos = pos
	_press_ms = Time.get_ticks_msec()
	_moved = false

	_dtz = (mode == Mode.NONE and not Input.is_key_pressed(KEY_SHIFT)) and _press_ms - _last_tap_ms < 320 and _last_tap_pos.is_finite() and pos.distance_to(_last_tap_pos) < 50.0 and line_cells.is_empty() and not _on_plan_point(pos)
	if _dtz:
		_strat_tap = Vector2.INF
		_dtz_y0 = pos.y
		_dtz_z0 = cam.zoom.x
		_dtz_anchor = pos
		_drag_pt = -2
	else:
		_drag_pt = _press_hit(pos)


func _release_press(pos: Vector2) -> void :
	if _dtz:
		_dtz = false
		if not _moved and hud.get("army_dock") != null and hud.army_dock.front_dbl(pos):
			pass
		elif not _moved and cam.strat_k() > 0.5:
			cam.dive_to(pos)
		elif not _moved:
			cam.step_zoom(1, pos)
			_on_zoom(cam.zoom.x)
		else:
			cam.settle_zoom(_dtz_anchor, int(signf(cam.zoom.x - _dtz_z0)))
		_last_tap_ms = -10000
		_end_drag()
		return
	if not _moved and Time.get_ticks_msec() - _press_ms < 450:
		_last_tap_ms = Time.get_ticks_msec()
		_last_tap_pos = pos
		if cam.strat_k() > 0.5 and mode == Mode.NONE:
			_strat_tap = pos
			_strat_tap_ms = _last_tap_ms
			_strat_tap_w = cam.screen_to_world(pos)
		else:
			_tap(pos)
	_end_drag()


func _dtz_drag(pos: Vector2) -> void :
	if absf(pos.y - _dtz_y0) > 4.0:
		_moved = true

	cam.set_zoom_at(_dtz_z0 * pow(2.0, (pos.y - _dtz_y0) / 120.0), _dtz_anchor)
	_on_zoom(cam.zoom.x)


func _update_ops(delta: float) -> void :
	if world == null or world.mil == null or world.player == null:
		hud.hide_ops()
		if world != null and mode != Mode.NONE:
			_update_selection_banner()
		else:
			hud.set_selection("", "", "")
		return
	_update_selection_banner()
	if strike.active and _is_strike_mode(mode):
		_strike_update(delta)
		return
	if mode == Mode.TARGET:
		_plan_info = world.mil.plan_info(world.player, plan_wps, plan_target, plan_has_target, plan_jet)
		if plan_list.is_empty() and not _standing_on():
			plan_count = clampi(plan_count, 1, maxi(1, int(_plan_info["available"])))
		hud.show_plan(_plan_info, plan_has_target, plan_count, route_mode, plan_wps.size())
		if not plan_list.is_empty() or _standing_on():
			_last_mp = world.mil.multi_plan(world.player, _plan_targets(), plan_jet)
			hud.show_multi(_last_mp, plan_list.size() + (1 if plan_has_target else 0), _standing_on(), plan_count if _plan_uniform() else 0)
		else:
			_last_mp = {}
		_danger_t -= delta
		if _danger_t <= 0.0:
			_danger_t = 1.0
			_danger = world.mil.danger_cells(world.player.id) if world.mil.has_method("smart_of") and world.mil.smart_of(world.player.id) else []
		return
	if mode == Mode.JET_KAB or mode == Mode.JET_CAS:
		_jet_card()
		return
	if mode == Mode.CR_TARGET:
		var b: Aircraft = follow as Aircraft
		if b == null or b.state == Aircraft.State.DEAD:
			_set_mode(Mode.NONE)
			return
		if _missile_multi_card():
			return
		var have_cr: int = b.pylon_n if b.type == Aircraft.Type.FIGHTER else b.missiles
		plan_count = clampi(plan_count, 1, maxi(1, have_cr))
		_plan_info = {"available": have_cr}
		hud.show_cr_plan(b, plan_has_target, b.pos.distance_to(plan_target) if plan_has_target else 0.0, plan_count)
		return
	if mode == Mode.SHIP_CR:
		_ship_cr_card()
		return
	if mode == Mode.HYP_TARGET:
		var hb: Aircraft = follow as Aircraft
		if hb == null or hb.state == Aircraft.State.DEAD:
			_set_mode(Mode.NONE)
			return
		if not _missile_multi_card():
			hud.show_aircraft(hb, world.mil.air, world.player)
		return
	if mode == Mode.MISSILE and not strike.active:
		_plan_info = world.mil.missile_plan(world.player, plan_target, plan_has_target)
		if _missile_multi_card():
			return
		plan_count = clampi(plan_count, 1, maxi(1, int(_plan_info["available"])))
		hud.show_missile_plan(_plan_info, plan_has_target, plan_count)
		return
	if follow != null:
		var done: bool = (follow is Drone and (follow as Drone).state == Drone.State.DONE) or (follow is Missile and (follow as Missile).state == Missile.State.DONE) or (follow is Aircraft and (follow as Aircraft).state == Aircraft.State.DEAD) or (follow is Recon.RDrone and ((follow as Recon.RDrone).dead or (follow as Recon.RDrone).state == Recon.St.DONE))
		if done:
			_follow_done_t += delta
			if _follow_done_t > 2.5:
				_deselect()
		elif cam_lock:
			var p: Vector2 = Vector2.ZERO
			if follow is Drone:
				p = (follow as Drone).pos
			elif follow is Aircraft:
				p = (follow as Aircraft).pos
			elif follow is Recon.RDrone:
				p = (follow as Recon.RDrone).pos
			else:
				p = (follow as Missile).screen_pos()
			cam.center_on(p.round())
			_follow_late.call_deferred()
	if follow is Aircraft:
		hud.show_aircraft(follow as Aircraft, world.mil.air, world.player)
	elif follow is Drone:
		hud.show_telemetry(follow as Drone)
	elif follow is Missile:
		hud.show_missile_telemetry(follow as Missile)
	elif follow is Recon.RDrone:
		hud.show_recon(world.recon.info(follow as Recon.RDrone))
	elif selected_fac != null and bar_builds_fid >= 0 and selected_fac.id == bar_builds_fid and selected_fac.kind == Facility.Kind.BARRACKS:

		if not (hud.panel_kind == "builds" and hud.panel != null and is_instance_valid(hud.panel)):
			bar_builds_fid = -1
			selected_fac = null
		hud.hide_ops()
	elif selected_fac != null and not army_view and selected_fac.kind == Facility.Kind.BARRACKS and world.player != null and selected_fac.country_id == world.player.id\
	and world.mil.alive(selected_fac) and hud.get("army_ux") != null and is_instance_valid(hud.army_ux):

		var bf304: Facility = selected_fac
		selected_fac = null
		hud.hide_ops()
		hud.army_ux.open_bar(bf304.id)
	elif selected_fac != null:
		if army_view and selected_fac.kind == Facility.Kind.BARRACKS and world.mil.alive(selected_fac) and hud.has_method("show_army"):
			hud.show_army(selected_fac, world.mil, world.player)
		else:
			hud.show_facility(selected_fac, world.mil, world.player)
	elif selected_intel != null:
		hud.show_intel(selected_intel)
	elif not selected_dep.is_empty():
		hud.show_deposit(selected_dep)
	elif selected_city >= 0 and selected_city < world.cities.size():
		hud.show_city(world.cities[selected_city])
	elif mode == Mode.MODULE:
		hud.hide_ops()
	else:
		hud.hide_ops()


func _pend_ok() -> void :
	if _pend.is_empty():
		hud.hide_confirm()
		return
	var pd: Dictionary = _pend
	_pend = {}
	hud.hide_confirm()
	_confirming = true
	match String(pd["kind"]):
		"tap":
			_tap(cam.world_to_screen(pd["wp"]))
		"line":
			_build_line_now(int(BUILD_KIND[int(pd["mode"])]), pd["cells"])
		"rail":
			RB.go(self, pd)
		"op":
			_op_start(pd["wp"])
		"demolish":
			_demolish_now(pd["fac"])
	_confirming = false
	_plan_refresh()
	if _ghost != null:
		_ghost.queue_redraw()





func _dep_build() -> void :
	var p: Country = world.player
	if selected_dep.is_empty() or p == null:
		hud.show_toast("Залежь не выбрана")
		UiKit.snd("ui_error")
		return
	var rk: String = String(selected_dep.get("res", ""))
	var bm: int = Mode.OIL_RIG if rk == "oil" else (Mode.UMINE if rk == "uranium" else Mode.MINE)
	var kind: int = BUILD_KIND[bm]
	var dc: Vector2i = selected_dep["cell"]
	if selected_dep.get("taken_by") != null:
		hud.show_toast("Залежь уже добывается")
		UiKit.snd("ui_error")
		return

	var spot: = Vector2i(-1, -1)
	var why: String = ""
	for r in 4:
		for dy in range( - r, r + 1):
			for dx in range( - r, r + 1):
				if spot.x >= 0 or maxi(absi(dx), absi(dy)) != r:
					continue
				var c: Vector2i = dc + Vector2i(dx, dy)
				var w: String = world.mil.check_place(kind, Military.nw_for(kind, c), p, null, false)
				if w == "":
					spot = c
				elif why == "":
					why = w
	if spot.x < 0:
		hud.show_toast(why if why != "" else "Здесь нельзя строить")
		UiKit.snd("ui_error")
		return
	var bc: Dictionary = Economy.build_cost(kind)
	if not p.has_res(bc):
		if not (world.econ.has_method("can_substitute") and world.econ.can_substitute(bc, p)):
			hud.show_toast(Loc.msg(Loc.mk("Не хватает: %s", [p.missing_res(bc)])))
			UiKit.snd("ui_error")
			_offer_buy(bc)
			return
		if not (_sub_confirm.size() == 3 and int(_sub_confirm[0]) == kind and (_sub_confirm[1] as Vector2i) == spot and Time.get_ticks_msec() - int(_sub_confirm[2]) < 8000):
			_sub_confirm = [kind, spot, Time.get_ticks_msec()]
			hud.show_toast(Loc.msg(Loc.mk("Не хватает: %s. Нажмите ещё раз — %s", [p.missing_res(bc), world.econ.substitute_note(bc, p).to_lower()])))
			UiKit.snd("ui_error")
			return
	var n0: int = world.mil.facilities.size()
	_deselect()
	_set_mode(bm)
	var was: bool = _confirming
	_confirming = true
	_tap(cam.world_to_screen(Vector2(spot) * GameWorld.CELL + Vector2(2, 2)))
	_confirming = was
	if world.mil.facilities.size() > n0:
		if Hud.ores_open:
			hud.toggle_ores()
	else:
		_set_mode(Mode.NONE)


func _jets_own() -> Array:
	if world == null or world.player == null or world.mil == null:
		return []
	var air: Air = world.mil.air
	if air.has_method("attack_jets"):
		return air.call("attack_jets", world.player.id)
	var out: Array = []
	for a: Aircraft in air.aircraft:
		if a.type == Aircraft.Type.ATTACK and a.country_id == world.player.id and a.state != Aircraft.State.DEAD:
			out.append(a)
	return out



func has_attack_jet() -> bool:
	return not _jets_own().is_empty()


func _kab_reach() -> float:
	var air: Air = world.mil.air
	return float(air.call("kab_reach")) if air.has_method("kab_reach") else 420.0


func _kab_stock() -> int:
	var air: Air = world.mil.air
	return int(air.call("kab_stock", world.player.id)) if air.has_method("kab_stock") else 0



func jet_kab_avail(a: Aircraft) -> int:
	if a == null:
		return 0
	if a.type == Aircraft.Type.FIGHTER and a.pylon == 3 and world.mil.air.arsenal_enabled:
		return a.pylon_n
	if a.type != Aircraft.Type.ATTACK:
		return 0
	if a.state == Aircraft.State.PARKED:
		return maxi(a.kab, mini(JET_MAX_PTS, a.kab + _kab_stock()))
	return a.kab



func _jet_fuel_r(a: Aircraft) -> float:
	if a == null:
		return 0.0
	var fuel: float = float(Air.SPEC[a.type]["fuel"]) if a.state == Aircraft.State.PARKED else a.fuel
	var back: float = a.pos.distance_to(a.base.center_px()) if a.base != null and a.airborne() else 0.0
	return maxf(0.0, (fuel - Air.RESERVE_PX - back) * 0.5)



func _jet_pick(kab: bool) -> Aircraft:
	var best: Aircraft = null
	var bs: float = -1000000000.0
	var ref: Vector2 = cam.screen_to_world(cam.view_size() * 0.5)
	var candidates: Array = _jets_own()
	if kab and world != null and world.mil != null:
		candidates = []
		for candidate: Aircraft in world.mil.air.aircraft:
			if candidate.country_id == world.player.id and candidate.state != Aircraft.State.DEAD and (candidate.type == Aircraft.Type.ATTACK or (candidate.type == Aircraft.Type.FIGHTER and candidate.pylon == 3 and world.mil.air.arsenal_enabled)):
				candidates.append(candidate)
	for a: Aircraft in candidates:
		if a.state == Aircraft.State.DEAD:
			continue
		var s: float = (-500.0 if a.state == Aircraft.State.LAND or a.state == Aircraft.State.TAXI else 0.0) + (300.0 if a.airborne() and a.state != Aircraft.State.RTB else 0.0) - a.pos.distance_to(ref) * 0.05
		if kab:
			s += 100.0 * jet_kab_avail(a)
		else:
			s += 2.0 * int(a.get("nar"))
		if a.state == Aircraft.State.PARKED and a.service_t > 1.0:
			s -= 200.0
		if s > bs:
			bs = s
			best = a
	return best


func _jet_begin(a: Aircraft, m: int) -> void :
	if a == null:
		a = _jet_pick(m == Mode.JET_KAB)
	var kab_capable: bool = a != null and (a.type == Aircraft.Type.ATTACK or (a.type == Aircraft.Type.FIGHTER and a.pylon == 3 and world.mil.air.arsenal_enabled))
	if a == null or (m == Mode.JET_KAB and not kab_capable) or (m == Mode.JET_CAS and a.type != Aircraft.Type.ATTACK):
		hud.show_toast(Loc.msg(Loc.mk("Нет штурмовика: купите на аэродроме (%d)", [int(Air.SPEC[Aircraft.Type.ATTACK].get("cost", 5000))])) if Air.SPEC.has(Aircraft.Type.ATTACK) else "Нет штурмовика")
		UiKit.snd("ui_error")
		return
	if m == Mode.JET_KAB and jet_kab_avail(a) <= 0:
		hud.show_toast("Нет КАБ: производите на ракетном заводе")
		UiKit.snd("ui_error")
		return
	if m == Mode.JET_CAS and a.airborne() and int(a.get("nar")) <= 0:
		hud.show_toast("НАРы кончились — посадите штурмовик на аэродром")
	if strike.active:
		strike.end(_plan_targets(), false)
	_set_mode(m)
	jet316 = a
	follow = a
	jet_pts.clear()
	cam_lock = false
	hud.set_key_pressed("follow", false)
	if jet316_marks == null or not is_instance_valid(jet316_marks):
		jet316_marks = Jet316MarksScript.new()
		jet316_marks.setup(self)
		hud.add_child(jet316_marks)
		hud.move_child(jet316_marks, mini(1, hud.get_child_count() - 1))


func jet_plan_active() -> bool:
	return (mode == Mode.JET_KAB or mode == Mode.JET_CAS) and jet316 != null


func jet_plan_state() -> Dictionary:
	if not jet_plan_active():
		return {}
	var bad: Array = []
	var fr: float = _jet_fuel_r(jet316)
	for p: Vector2 in jet_pts:
		bad.append(jet316.pos.distance_to(p) > fr)
	var why: String = ""
	var air: Air = world.mil.air
	if not jet_pts.is_empty():
		if mode == Mode.JET_CAS and air.has_method("cas_why"):
			why = String(air.call("cas_why", world.player.id, jet316.id, jet_pts[0]))
		elif mode == Mode.JET_KAB and air.has_method("kab_strike_why"):
			why = String(air.call("kab_strike_why", world.player.id, jet316.id, jet_pts))
	return {"jet": jet316, "pts": jet_pts, "cas": mode == Mode.JET_CAS, "has": not jet_pts.is_empty(), "reach": _kab_reach(), "fuel_r": fr, "bad": bad, "why": why}


func _jet_tap(pos: Vector2, wp: Vector2) -> void :
	var p: Vector2 = wp.floor() + Vector2(0.5, 0.5)
	if mode == Mode.JET_CAS:
		jet_pts = [p]
		overlay.ripple(p, "alert_red")
		return
	for i in jet_pts.size():
		if cam.world_to_screen(jet_pts[i]).distance_to(pos) <= GRAB_R:
			jet_pts.remove_at(i)
			UiKit.snd("ui_close")
			return
	var cap: int = mini(JET_MAX_PTS, maxi(1, jet_kab_avail(jet316)))
	if jet_pts.size() >= cap:
		hud.show_toast(Loc.msg(Loc.mk("Целей не больше %d (КАБ на вылет)", [cap])))
		UiKit.snd("ui_error")
		return
	jet_pts.append(p)
	overlay.ripple(p, "alert_red")


func _jet_back() -> void :
	if not jet_pts.is_empty():
		jet_pts.pop_back()
	else:
		var a: Aircraft = jet316
		_set_mode(Mode.NONE)
		follow = a


func _jet_fire() -> void :
	var a: Aircraft = jet316
	if a == null or jet_pts.is_empty():
		hud.show_toast("Сначала выберите цель")
		return
	var pts: Array = jet_pts.duplicate()
	var cas: bool = mode == Mode.JET_CAS
	var cb: = func(r: Variant) -> void :
		var why: String = _why(r)
		if why != "":
			if r == null:
				hud.show_toast(why)
			UiKit.snd("ui_error")
			return
		hud.show_toast((Loc.msg(Loc.mk("Штурмовик №%d: поддержка — вылет", [a.id]))) if cas else (Loc.msg(Loc.mk("Штурмовик №%d: удар КАБ по %d целям", [a.id, pts.size()]))))
		if mode == Mode.JET_KAB or mode == Mode.JET_CAS:
			_set_mode(Mode.NONE)
		follow = a
	if cas:
		_sim("mil.air", "cas_support", [world.player.id, a.id, pts[0]], cb)
	else:
		_sim("mil.air", "kab_strike", [world.player.id, a.id, pts], cb)


func _jet_card() -> void :
	var a: Aircraft = jet316
	if a == null or a.state == Aircraft.State.DEAD:
		_set_mode(Mode.NONE)
		hud.show_toast("Самолёт потерян")
		return
	hud.show_jet_plan(a, mode == Mode.JET_CAS, jet_plan_state(), jet_kab_avail(a), _kab_stock())
