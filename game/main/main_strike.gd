extends "res://game/main/main_core.gd"


func _end_drag() -> void :
	if _drag_pt == -12:
		_drag_pt = -2
		if _moved and hud.get("navy_dock") != null:
			hud.navy_dock.route_drag_end()
		return
	if _drag_pt == -10:
		_drag_pt = -2
		if _moved and hud.get("army_dock") != null:
			hud.army_dock.route_drag_end()
		return
	if _drag_pt == -9:
		_drag_pt = -2
		if _moved and hud.get("army_dock") != null:
			hud.army_dock.plan_drag_end()
		return
	if _drag_pt == -8:
		_drag_pt = -2
		if _moved and op_from != null and not world.ops.preview_arrow.is_empty():
			var to: Vector2 = world.ops.preview_arrow["to"]
			if GameConfig.confirm_actions:
				var of: Facility = op_from
				if mode != Mode.OPERATION:
					_set_mode(Mode.OPERATION)
				op_from = of
				world.ops.preview_arrow = {"f": of, "to": to, "kind": -1}
				_pend = {"kind": "op", "wp": to, "mode": Mode.OPERATION}
				_show_pend()
				return
			_op_start(to)
		elif mode != Mode.OPERATION:
			op_from = null
		if world.get("ops") != null:
			world.ops.preview_arrow = {}
		return
	if _drag_pt == -13:
		_drag_pt = -2
		if _moved:
			RB.drag_end(self)
		return
	if _drag_pt == -7:
		var cells: Array[Vector2i] = line_cells.duplicate()
		line_cells.clear()
		_drag_pt = -2
		_set_mode(mode)
		if cells.size() >= 2 and world.player != null:
			if GameConfig.confirm_actions and not Input.is_key_pressed(KEY_SHIFT):
				_pend = {"kind": "line", "cells": cells, "mode": mode}
				_show_pend()
			else:
				if not _pend.is_empty():
					_pend_cancel()
				_build_line_now(int(BUILD_KIND[mode]), cells)
		return
	if (_drag_pt == -3 or _drag_pt == -4) and _moved:
		var d: Drone = follow as Drone
		if d != null:
			var p: Vector2 = _drag_drone_pos.floor() + Vector2(0.5, 0.5)
			overlay.ripple(p, "amber")
			_sim("mil", "retarget", [d, p, _drag_pt == -4], func(r: Variant) -> void :
				if _why(r) != "":
					hud.show_toast(_why(r)))
	_drag_pt = -2



func _missile_multi_card() -> bool:
	if mode == Mode.SHIP_CR:
		_ship_cr_card()
		return true
	if not _missile_multi() or not plan_has_target or (plan_list.is_empty() and mode != Mode.HYP_TARGET):
		return false
	_last_mp = _missile_mp()
	var n_t: int = plan_list.size() + 1
	var per: int = plan_count if _plan_uniform() else 0
	match mode:
		Mode.MISSILE:
			hud.show_strike_multi("plan_mm", "icon_target", "Ракетный удар", "Все ОТРК · баллистические", _last_mp, n_t, per)
		Mode.HYP_TARGET:
			hud.show_strike_multi("plan_mh", "icon_m_hyper", "Гиперзвуковой удар", "Все истребители с подвесом", _last_mp, n_t, per)
		_:
			hud.show_strike_multi("plan_mc", "icon_cr_launch", "Пуск крылатых ракет", "Все носители КР", _last_mp, n_t, per)
	return true



func _missile_multi_launch() -> bool:
	if mode == Mode.SHIP_CR:
		_ship_cr_launch()
		return true
	if not _missile_multi() or not plan_has_target or (plan_list.is_empty() and mode != Mode.HYP_TARGET):
		return false
	var m0: int = mode
	var on_r: Callable = func(r: Variant) -> void :
		if r is Dictionary and int((r as Dictionary).get("launched", 0)) > 0:
			_await_missile = m0 != Mode.CR_TARGET
			_deselect()
			_set_mode(Mode.NONE)
	if mode == Mode.MISSILE:
		_sim("mil", "launch_missiles_multi", [world.player, _plan_targets()], on_r)
	else:
		_sim("mil.air", "multi_launch", [world.player, _plan_targets(), mode == Mode.HYP_TARGET], on_r)
	return true


func _drag_or_pan(pos: Vector2, rel: Vector2) -> void :
	if _drag_pt == -9:
		hud.army_dock.plan_drag(cam.screen_to_world(_press_pos), cam.screen_to_world(pos))
		return
	if _drag_pt == -10:
		hud.army_dock.route_drag(cam.screen_to_world(_press_pos), cam.screen_to_world(pos))
		return
	if _drag_pt == -12:
		hud.navy_dock.route_drag(cam.screen_to_world(_press_pos), cam.screen_to_world(pos))
		return
	if _drag_pt == -8 and op_from != null:
		world.ops.preview_arrow = {"f": op_from, "to": cam.screen_to_world(pos), "kind": -1}
		var pv: Dictionary = world.ops.preview(op_from, cam.screen_to_world(pos), -1)
		hud.set_hint(String(pv.get("text", "")).to_upper())
		return
	if _drag_pt == -13:
		RB.drag(self, pos)
		return
	if _drag_pt == -7:
		_extend_line(pos)
		return
	if _drag_pt == -5:
		var p0: Vector2 = cam.screen_to_world(_press_pos).floor() + Vector2(0.5, 0.5)
		_drag_pt = _insert_index(p0)
		plan_wps.insert(_drag_pt, p0)
	elif _drag_pt == -6:
		_drag_pt = -4 if Time.get_ticks_msec() - _press_ms >= LINE_HOLD_MS else -2
	if _drag_pt != -2:
		var p: Vector2 = cam.screen_to_world(pos).floor() + Vector2(0.5, 0.5)
		if _drag_pt == -3 or _drag_pt == -4:
			_drag_drone_pos = p
		elif _drag_pt == -1:
			plan_target = p
		elif _drag_pt < plan_wps.size():
			plan_wps[_drag_pt] = p
		return
	if cam_lock:
		cam_lock = false
		hud.set_key_pressed("follow", false)
	cam.pan_screen(rel)


func _do_launch() -> void :
	if not plan_has_target:
		hud.show_toast("Сначала выберите цель")
		return
	if _missile_multi_launch():
		return
	if mode == Mode.CR_TARGET:
		var b: Aircraft = follow as Aircraft
		if b != null:
			_sim("mil.air", "launch_cruise", [b, plan_target, plan_count], func(r: Variant) -> void :
				if r != null and int(r) > 0:
					hud.show_toast(Loc.msg(Loc.mk("Пуск крылатых ракет: %d", [int(r)])))
					_set_mode(Mode.NONE)
					cam_lock = false
					follow = b)
		return
	if mode == Mode.MISSILE:
		_sim("mil", "launch_missiles", [world.player, plan_target, plan_count], func(r: Variant) -> void :
			var n: int = int(r) if r != null else 0
			if n == 0:
				return
			hud.show_toast(Loc.msg(Loc.mk("Ракетный удар: %d. Подъём ракеты...", [n])))
			_deselect()
			_await_missile = true
			_set_mode(Mode.NONE))
		return
	if not plan_list.is_empty() and world.mil.has_method("launch_multi_ex"):
		_sim("mil", "launch_multi_ex", [world.player, _plan_targets(), plan_jet], func(r: Variant) -> void :
			if r is Dictionary and int((r as Dictionary).get("launched", 0)) > 0:
				_set_mode(Mode.NONE))
		return
	_sim("mil", "launch", [world.player, plan_wps, plan_target, plan_count, plan_jet], func(r: Variant) -> void :
		var ds: Array = r if r is Array else []
		if ds.is_empty():
			return
		hud.show_toast(Loc.msg(Loc.mk("Пуск: %d БПЛА", [ds.size()])))
		_set_mode(Mode.NONE)
		follow = ds[0]
		cam_lock = false
		hud.set_key_pressed("follow", false)
		_follow_done_t = 0.0)






func _follow_late() -> void :
	if not cam_lock or follow == null or not is_instance_valid(cam):
		return
	var p: Vector2 = Vector2.INF
	if follow is Drone:
		p = (follow as Drone).pos
	elif follow is Aircraft:
		p = (follow as Aircraft).pos
	elif follow is Recon.RDrone:
		p = (follow as Recon.RDrone).pos
	elif follow is Missile:
		p = (follow as Missile).screen_pos()
	if p.is_finite():
		cam.center_on(p.round())


func ship_cr_begin(focus: Ship = null) -> void :
	if not _has_capital():
		_set_mode(mode)
		return
	var nd: Variant = hud.get("navy_dock")
	if nd != null and is_instance_valid(nd) and bool(nd.is_open):
		nd.close()
	_deselect()
	route_mode = false
	strike_open("ship")
	if focus != null and focus.alive():
		cam_lock = false
		cam.center_on(focus.pos)



func ship_art_begin(focus: Ship = null) -> void :
	if not _has_capital():
		_set_mode(mode)
		return
	var nd: Variant = hud.get("navy_dock")
	if nd != null and is_instance_valid(nd) and bool(nd.is_open):
		nd.close()
	_deselect()
	route_mode = false
	strike_open("art")
	if focus != null and focus.alive():
		cam_lock = false
		cam.center_on(focus.pos)


func _ship_cr_card() -> void :
	_last_mp = _missile_mp()
	var mp: Dictionary = _last_mp
	var av: int = int(mp.get("available", 0))
	_plan_info = {"available": maxi(1, av)}
	var n_t: int = plan_list.size() + (1 if plan_has_target else 0)
	var per: int = plan_count if (_plan_uniform() or plan_list.is_empty()) and plan_has_target else 0
	hud.show_strike_multi("plan_ms", "icon_cr_launch", "Удар КР с кораблей", Loc.t("Кораблей с УВП: %d · КР: %d") % [int(mp.get("ships", 0)), av], mp, n_t, per)
	var t: String = ""
	var bad: bool = av == 0
	if av == 0:
		t = String(mp.get("why", "")).to_upper()
	elif not plan_has_target:
		t = Loc.t("ТАП ПО ЦЕЛИ НА СУШЕ: ДО %.1f КМ ОТ КОРАБЛЯ\nЕЩЁ ТАП ПО ТОЧКЕ = +1 РАКЕТА") % (Navy.CM_RANGE / 1000.0)
	else:
		t = Loc.t("ЦЕЛЕЙ %d · РАКЕТ %d · ДОЛЕТЯТ %d · ГОТОВО %d") % [n_t, int(mp["total"]), int(mp["assigned"]), av]
		var sh: Array = mp.get("shooters", [])
		if not sh.is_empty():
			t += Loc.t("\nПУСК: ") + ", ".join(PackedStringArray(sh.slice(0, 2))).to_upper() + (" +%d" % (sh.size() - 2) if sh.size() > 2 else "")
		for pt: Dictionary in mp.get("per_target", []):
			if String(pt.get("reason", "")) != "":
				t += "\n" + String(pt["reason"]).to_upper()
				bad = bad or int(pt.get("got", 0)) == 0
				break
	hud._set_info(t, bad)
	hud.ops_launch.disabled = int(mp.get("assigned", 0)) == 0 or not plan_has_target

	var notes: PackedStringArray = []
	for e: Dictionary in mp.get("peace", []):
		notes.append(String(e["note"]).to_upper())
	if _cr_warn == null or not is_instance_valid(_cr_warn):
		var info: Label = hud.get("ops_info") as Label
		if info == null:
			return
		_cr_warn = UiKit.lbl("", 10, UiKit.RED, 2, 2)
		_cr_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_cr_warn.name = "ShipCrWarn"
		info.get_parent().add_child(_cr_warn)
		info.get_parent().move_child(_cr_warn, info.get_index() + 1)
	var wt: String = "\n".join(notes)
	if _cr_warn.text != wt:
		_cr_warn.text = wt
	_cr_warn.visible = not notes.is_empty()


func _ship_cr_launch() -> void :
	if not plan_has_target:
		return
	_sim("", "cmd_static", [world.player, "ship_cr", "launch", [_plan_targets()]], func(rv: Variant) -> void :
		_ship_cr_done(rv if rv is Dictionary else {}))


func _ship_cr_done(r: Dictionary) -> void :
	if int(r.get("launched", 0)) <= 0:
		hud.show_toast("КР не ушли: нет кораблей с ракетами в досягаемости")
		UiKit.snd("ui_error")
		return
	var wars: Array = r.get("wars", [])
	hud.show_toast(Loc.msg(Loc.mk("Пуск КР с кораблей: %d (кораблей: %d)%s", [int(r["launched"]), int(r["ships"]), (Loc.t(" · война: ") + ", ".join(PackedStringArray(wars))) if not wars.is_empty() else ""])))
	_deselect()
	_set_mode(Mode.NONE)




func strike_open(wid: String) -> void :
	if not _has_capital() or world.player == null:
		_set_mode(mode)
		return
	if strike.active and _is_strike_mode(mode):
		strike_pick(wid, true)
		return
	if strike.active:
		strike.end([], true)
	_deselect()
	if mode != Mode.NONE:
		_set_mode(Mode.NONE)
	strike.begin(world)
	if strike_ui == null or not is_instance_valid(strike_ui):
		strike_ui = StrikeSheetScript.new()
		strike_ui.setup(self)
	if strike_marks == null or not is_instance_valid(strike_marks):
		strike_marks = StrikeMarksScript.new()
		strike_marks.setup(self)
		hud.add_child(strike_marks)
		hud.move_child(strike_marks, mini(1, hud.get_child_count() - 1))
	if strike_ui.has_method("on_open"):
		strike_ui.call("on_open")
	_strike_enter(wid)
	if strike.restored():
		hud.show_toast("Цели прошлого удара восстановлены")




func strike_pick(wid: String, force: bool = false) -> void :
	if not strike.active:
		strike_open(wid)
		return
	if wid == strike.cur:
		return
	var rd: Array = strike.ready_all(world).get(wid, [0, ""])
	if not force and int(rd[0]) <= 0 and (strike.plans.get(wid, []) as Array).is_empty():
		hud.show_toast("%s: %s" % [StrikeHubScript.title(wid), String(rd[1]) if String(rd[1]) != "" else Loc.t("нет готовых средств")])
		UiKit.snd("ui_error")
		return
	strike.stash(strike.cur, _plan_targets())
	_strike_enter(wid)


func _strike_enter(wid: String) -> void :
	strike.cur = wid
	plan_jet = wid == "jet"
	_strike_sw = true
	_set_mode(int(STRIKE_MODE[wid]))
	_strike_sw = false
	plan_list.clear()
	plan_wps.clear()
	plan_has_target = false
	plan_count = 1
	route_mode = false
	_drag_pt = -2
	_plan_info = {}
	_last_mp = {}
	if wid == "bomber" or wid == "hyper":
		follow = null
		cam_lock = false
	var ts: Array = strike.take(wid)
	for i in ts.size():
		var t: Dictionary = ts[i]
		if i < ts.size() - 1:
			plan_list.append(t)
		else:
			plan_target = t["pos"]
			plan_has_target = true
			plan_count = int(t["n"])
			plan_wps.assign(t.get("wps", []))
	if wid == "thermo" or wid == "nuke":
		var rdy_map: Dictionary = strike.ready_all(world)
		var av_w: int = int((rdy_map.get(wid, [0, ""]) as Array)[0])
		_plan_info = {"available": av_w}
		var cur_tot: int = 0
		var valid_list: Array = []
		for t: Dictionary in plan_list:
			var tn: int = int(t["n"])
			if cur_tot + tn <= av_w:
				valid_list.append(t)
				cur_tot += tn
			elif cur_tot < av_w:
				t["n"] = av_w - cur_tot
				valid_list.append(t)
				cur_tot = av_w
		plan_list = valid_list
		if plan_has_target:
			if cur_tot >= av_w:
				if plan_list.is_empty():
					plan_count = maxi(1, av_w)
				else:
					plan_has_target = false
					plan_count = 1
			else:
				plan_count = clampi(plan_count, 1, av_w - cur_tot)
	hud.set_hint(Loc.t("%s: ТАП ПО КАРТЕ = ЦЕЛЬ") % Loc.t(StrikeHubScript.title(wid)).to_upper())


func strike_close() -> void :
	_set_mode(Mode.NONE)
	_deselect()
	hud.hide_ops()



func _strike_update(delta: float) -> void :
	if mode == Mode.TARGET:
		_plan_info = world.mil.plan_info(world.player, plan_wps, plan_target, plan_has_target, plan_jet)
		if plan_list.is_empty() and not _standing_on():
			plan_count = clampi(plan_count, 1, maxi(1, int(_plan_info["available"])))
		if not plan_list.is_empty() or _standing_on():
			_last_mp = world.mil.multi_plan(world.player, _plan_targets(), plan_jet)
		else:
			_last_mp = {}
		_danger_t -= delta
		if _danger_t <= 0.0:
			_danger_t = 1.0
			_danger = world.mil.danger_cells(world.player.id) if world.mil.has_method("smart_of") and world.mil.smart_of(world.player.id) else []
	elif mode == Mode.MISSILE:
		if strike.active and (strike.cur == "thermo" or strike.cur == "nuke" or strike.cur == "iskander"):
			_plan_info = StrikeHubScript.plan_single(world, strike.cur, plan_target, plan_has_target)
			var av_m: int = int(_plan_info.get("available", 0))
			if plan_list.is_empty():
				plan_count = clampi(plan_count, 1, maxi(1, av_m))
		else:
			_plan_info = world.mil.missile_plan(world.player, plan_target, plan_has_target)
	var op: PanelContainer = hud.ops_panel
	if strike_ui.get_parent() != op:
		if strike_ui.get_parent() != null:
			strike_ui.get_parent().remove_child(strike_ui)
		op.add_child(strike_ui)
	hud._card("strike_hub", "", "", "", false, false, false)
	for i in op.get_child_count():
		var c: Control = op.get_child(i) as Control
		var want: bool = c == strike_ui
		if c != null and c.visible != want:
			c.visible = want
	strike_ui.refresh(delta)



func strike_fire() -> void :
	if not strike.active or world.player == null:
		return
	var all: Dictionary = {}
	for w: String in strike.plans:
		if not (strike.plans[w] as Array).is_empty():
			all[w] = strike.plans[w]
	var cur_t: Array = _plan_targets()
	if not cur_t.is_empty():
		all[strike.cur] = cur_t
	if all.is_empty():
		hud.show_toast("Сначала отметьте цели на карте")
		UiKit.snd("ui_error")
		return
	if net.in_match:
		_sim("", "cmd_strike", [world.player, all, StrikeHubScript.sync_arrive], func(rv: Variant) -> void :
			_strike_done(all, rv if rv is Dictionary else {"now": {}, "later": {}, "failed": all.keys(), "text": "", "drones": []}))
		return
	_strike_done(all, strike.fire(world, all, StrikeHubScript.sync_arrive))


func _strike_done(all: Dictionary, r: Dictionary) -> void :
	var went: int = (r["now"] as Dictionary).size() + (r["later"] as Dictionary).size()
	var failed: PackedStringArray = []
	for w2: String in r["failed"]:
		failed.append(StrikeHubScript.short(w2))
	if went == 0:
		hud.show_toast("Удар не состоялся: нет готовых средств в досягаемости")
		UiKit.snd("ui_error")
		return
	var single: String = String(all.keys()[0]) if all.size() == 1 else ""
	strike.end([], true)
	_set_mode(Mode.NONE)
	_deselect()
	if single == "drone" or single == "jet":
		var lds: Array = r.get("drones", strike.last_drones)
		if not lds.is_empty():
			hud.show_toast(Loc.msg(Loc.mk("Пуск: %d БПЛА", [lds.size()])))
			follow = lds[0]
			cam_lock = false
			hud.set_key_pressed("follow", false)
			_follow_done_t = 0.0
	elif single == "tel" or single == "hyper" or single == "iskander":
		_await_missile = true
	elif single == "":
		hud.show_toast(Loc.t(String(r["text"])) + ((Loc.msg(Loc.mk(" · не ушли: %s", [", ".join(failed)]))) if not failed.is_empty() else ""))



func _on_plan_point(pos: Vector2) -> bool:
	if not (mode == Mode.TARGET or _missile_multi()) or not plan_has_target or route_mode:
		return false
	if cam.world_to_screen(plan_target).distance_to(pos) <= GRAB_R:
		return true
	for t: Dictionary in plan_list:
		if cam.world_to_screen(t["pos"]).distance_to(pos) <= GRAB_R:
			return true
	return false



func _plan_per_all() -> void :
	for t: Dictionary in plan_list:
		t["n"] = plan_count



func _plan_back() -> void :
	if not plan_has_target:
		_set_mode(Mode.NONE)
		return
	plan_wps.clear()
	if plan_list.is_empty():
		plan_has_target = false
		plan_count = 1
	else:
		var t: Dictionary = plan_list.pop_back()
		plan_target = t["pos"]
		plan_count = int(t["n"])
		plan_wps.assign(t.get("wps", []))
	hud.show_toast("Последняя цель убрана")


func _plan_uniform() -> bool:
	for t: Dictionary in plan_list:
		if int(t["n"]) != plan_count:
			return false
	return not plan_list.is_empty()


func _standing_on() -> bool:
	return world.player != null and world.mil.has_method("standing_of") and bool(world.mil.standing_of(world.player.id).get("on", false))



func _op_start(to: Vector2) -> void :
	var f: Facility = op_from
	if f == null or not world.mil.alive(f):
		_set_mode(Mode.NONE)
		return
	world.ops.preview_arrow = {}
	_sim("ops", "start", [f, -1, to], func(r: Variant) -> void :
		if _why(r) != "":
			hud.show_toast(_why(r))
			UiKit.snd("ui_error")
			return
		var op: Dictionary = world.ops.of(f)
		hud.show_toast(Loc.msg(Loc.mk("Движение: %s", [Loc.t(String(op.get("name", "")))])))
		UiKit.snd("ui_build")
		overlay.ripple(to, "intercept_cyan")
		op_from = null
		_set_mode(Mode.NONE)
		selected_fac = f)



func _battle_cam() -> void :
	if world.get("battle_watch") == null:
		return
	var plan: Array = world.battle_watch.cam_plan()
	if plan.is_empty():
		var fr: Dictionary = world.battle_watch.player_front() if world.battle_watch.has_method("player_front") else {}
		if fr.is_empty():
			hud.show_toast("Сейчас нигде не воюют")
			return
		cam_lock = false
		cam.center_on(fr["pos"])
		hud.show_toast(String(fr.get("label", "Фронт")))
		return
	_deselect()
	_cam_plan = plan
	_cam_home = cam.screen_to_world(cam.view_size() * 0.5)
	_cam_home_z = cam.zoom.x
	_cam_next_step()
	hud.show_toast(String((plan[0] as Dictionary).get("label", "")))


func _cam_next_step() -> void :
	_cam_t = 0.0
	_cam_from = cam.screen_to_world(cam.view_size() * 0.5)
	_cam_from_z = cam.zoom.x
	if _cam_plan.is_empty():
		return
	var st: Dictionary = _cam_plan[0]
	if float(st.get("speed", 0.0)) == 1.0 and _speed_i > 0 and not _paused:
		_cam_speed_keep = _speed_i
		_speed_i = 0
		_apply_speed()
	if String(st.get("kind", "")) == "impact" or String(st.get("kind", "")) == "incoming":
		hud.show_toast(String(st.get("label", "")))


func _cam_stop() -> void :
	_cam_plan.clear()
	if _cam_speed_keep >= 0:
		_speed_i = _cam_speed_keep
		_cam_speed_keep = -1
		_apply_speed()


func _cam_tick(delta: float) -> void :
	if _cam_plan.is_empty():
		return
	var st: Dictionary = _cam_plan[0]
	if bool(st.get("follow", false)) and world.battle_watch.has_method("follow"):
		_cam_follow_t -= delta
		if _cam_follow_t <= 0.0:
			_cam_follow_t = 0.25
			st["pos"] = world.battle_watch.follow(st["pos"])
	var to: Vector2 = st["pos"] if (st["pos"] as Vector2).is_finite() else _cam_home
	var tz: float = float(st["zoom"]) if float(st["zoom"]) > 0.0 else _cam_home_z
	_cam_t += delta
	var fly: float = 0.7
	var k: float = clampf(_cam_t / fly, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	cam.set_zoom_at(lerpf(_cam_from_z, tz, k), cam.view_size() * 0.5)
	cam.center_on(_cam_from.lerp(to, k))
	_on_zoom(cam.zoom.x)
	if _cam_t >= fly + float(st.get("hold_s", 2.0)):
		_cam_plan.pop_front()
		if _cam_plan.is_empty():
			_cam_stop()
		else:
			_cam_next_step()



func _prompt_tick(delta: float) -> void :
	_prompt_t -= delta
	if _prompt_t > 0.0 or world.get("ops") == null or world.player == null:
		return
	_prompt_t = 1.0
	var pr: Dictionary = world.ops.next_prompt()
	if not pr.is_empty():
		hud.show_prompt(pr)


func _offer_buy(cost: Dictionary) -> void :
	if world.player == null or not world.econ.has_method("buy_shortfall"):
		return
	var res_only: Dictionary = cost.duplicate()
	res_only.erase("money")
	if res_only.is_empty() or world.player.has_res(res_only):
		return
	_short_cost = cost.duplicate()
	hud.show_prompt({"text": Loc.t("Не хватает: %s. Купить на рынке?") % world.player.missing_res(res_only), "action": "buy_short", "icon": "icon_trade"})


func _prompt_act(pr: Dictionary) -> void :
	var act: String = String(pr.get("action", ""))
	if act == "buy_short":
		if world.player != null and not _short_cost.is_empty():
			_sim("econ", "buy_shortfall", [world.player, _short_cost], func(r: Variant) -> void :
				UiKit.snd("ui_build" if r is Dictionary and bool((r as Dictionary).get("ok", false)) else "ui_error"))
		_short_cost = {}
		return
	var pos: Vector2 = pr.get("pos", Vector2.INF)
	var f: Facility = null
	var fid: int = int(pr.get("fid", -1))
	if fid >= 0 and fid < world.mil.facilities.size():
		f = world.mil.facilities[fid]
		if f.country_id != world.player.id or not world.mil.alive(f):
			f = null
	if pos.is_finite():
		cam_lock = false
		cam.center_on(pos)
	match act:
		"look":
			pass
		"op_retreat":
			if f != null:
				_sim("ops", "start", [f, 2, Vector2.ZERO], func(r: Variant) -> void : hud.show_toast(_or_ok(_why(r), "Отход")))
		"op_defend":
			if f != null and pos.is_finite():
				_sim("ops", "start", [f, 1, pos], func(r: Variant) -> void : hud.show_toast(_or_ok(_why(r), "Оборона")))
		"order_arty", "order_smoke", "order_ew":
			var k: int = ["order_arty", "order_smoke", "order_ew"].find(act)
			if pos.is_finite():
				_sim("ops", "order", [world.player.id, k, pos], func(r: Variant) -> void : hud.show_toast(_or_ok(_why(r), "Приказ: %s" % String(world.ops.order_info(k).get("name", "")))))
			else:
				order_kind = k
				_set_mode(Mode.ORDER)
		"select_barracks":
			if f != null:
				_deselect()
				selected_fac = f


func _or_ok(why: String, ok: String) -> String:
	return why if why != "" else ok



func _dip11(nm: String) -> void :
	var dp: Diplomacy = world.diplo
	var me: int = world.player.id
	var a: PackedStringArray = nm.split(":")
	var why: String = ""
	var ok_text: String = ""
	var m: String = ""
	var args: Array = []
	match a[0]:
		"treaty":
			hud.dip_hint_treaty = ""
			m = "propose_treaty"
			args = [me, int(a[1]), a[2]]
			ok_text = Loc.t("Подписано: %s") % String((Diplomacy.TREATY_INFO.get(a[2], {}) as Dictionary).get("name", a[2]))
		"untreaty":
			m = "cancel_treaty"
			args = [me, int(a[1]), a[2]]
			ok_text = Loc.t("Договор расторгнут")
		"embargo":
			m = "set_embargo"
			args = [me, int(a[1]), a[2] == "1"]
			ok_text = Loc.t("Эмбарго введено") if a[2] == "1" else Loc.t("Эмбарго снято")
		"aid":
			m = "give_aid"
			args = [me, int(a[1]), 500]
			ok_text = Loc.t("Помощь отправлена: отношения растут")
		"dem":
			var opts: Array = dp.demand_options(me, int(a[1]))
			var i: int = int(a[2])
			if i < 0 or i >= opts.size():
				why = Loc.t("Требование устарело")
			else:
				var o: Dictionary = opts[i]
				var prm: Dictionary = (o.get("params", {}) as Dictionary).duplicate()
				prm["conseq"] = a[3]
				m = "demand"
				args = [me, int(a[1]), String(o["kind"]), prm]
				var dc: Country = world.country_by_id(int(a[1]))
				ok_text = Loc.t("%s уступает требованию") % (Loc.name(dc.name) if dc != null else Loc.t("Страна"))
		"pend":
			m = "answer_as"
			args = [me, String(a[1]), String(a[2])]
	if m != "":
		_sim("diplo", m, args, func(r: Variant) -> void : _dip_done(_why(r), ok_text))
		return
	_dip_done(why, ok_text)


func _dip_done(why: String, ok_text: String) -> void :
	if why != "":
		hud.show_toast(why)
		UiKit.snd("ui_error")
	elif ok_text != "":
		hud.show_toast(ok_text)
	hud.open_diplomacy()


func _dip_action(nm: String) -> void :
	var parts: PackedStringArray = nm.split(":")
	var other: int = int(parts[1])
	var me: int = world.player.id
	match parts[2]:
		"war":
			_sim("diplo", "declare_war", [me, other], func(_r: Variant) -> void : hud.open_diplomacy())
		"truce":
			_sim("diplo", "propose", [me, other, Diplomacy.Rel.TRUCE], func(r: Variant) -> void :
				hud.show_toast("Перемирие заключено" if r == true else "Отказ: перемирие пока не нужно")
				hud.open_diplomacy())
		"peace":
			_sim("diplo", "propose", [me, other, Diplomacy.Rel.PEACE], func(r: Variant) -> void :
				hud.show_toast("Мир заключён" if r == true else "Отказ: мир пока не нужен")
				hud.open_diplomacy())
		"ally":
			_sim("diplo", "propose", [me, other, Diplomacy.Rel.ALLIANCE], func(r: Variant) -> void :
				if r == true:
					hud.show_toast("Союз заключён")
				hud.open_diplomacy())
		"break":
			_sim("diplo", "break_alliance", [me, other], func(_r: Variant) -> void : hud.open_diplomacy())



func _cycle_army() -> void :
	if world.player == null:
		return
	var list: Array[Unit] = []
	for u: Unit in world.army.units:
		if u.country_id == world.player.id and u.alive() and u.type != Unit.Type.FPV:
			list.append(u)
	if list.is_empty():
		hud.show_toast("Нет войск: постройте казармы")
		return
	list.sort_custom( func(a: Unit, b: Unit) -> bool: return a.state > b.state)
	_army_i = (_army_i + 1) % list.size()
	cam_lock = false
	cam.center_on(list[_army_i].pos.round())
	if cam.zoom.x < 2.0:
		cam.set_zoom_at(MapCamera.zk(2.0), cam.view_size() * 0.5)
		_on_zoom(2.0)



func _extend_line(pos: Vector2) -> void :
	var w: Vector2 = cam.screen_to_world(pos)
	var c: = Vector2i(floori(w.x / GameWorld.CELL), floori(w.y / GameWorld.CELL))
	if line_cells.is_empty():
		line_cells.append(c)
		return
	var last: Vector2i = line_cells[line_cells.size() - 1]
	var steps: int = maxi(absi(c.x - last.x), absi(c.y - last.y))
	for i in range(1, steps + 1):
		var q: = Vector2i(roundi(lerpf(last.x, c.x, float(i) / steps)), roundi(lerpf(last.y, c.y, float(i) / steps)))
		if line_cells.size() >= Military.LINE_MAX:
			break
		if q != line_cells[line_cells.size() - 1] and not line_cells.has(q):
			line_cells.append(q)
	var kind: int = BUILD_KIND[mode]
	hud.set_hint(Loc.n(line_cells.size(), "%s: %d КЛЕТКА, %d", "%s: %d КЛЕТКИ, %d", "%s: %d КЛЕТОК, %d") % [
		Loc.t("ОКОП") if kind == Facility.Kind.TRENCH_H else Loc.t("ЗУБЫ"), line_cells.size(), Military.line_cost(kind, line_cells.size())])
