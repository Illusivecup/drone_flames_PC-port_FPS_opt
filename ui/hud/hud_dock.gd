extends "res://ui/hud/hud_keys.gd"



func _build_confirm() -> void :
	confirm_panel = PanelContainer.new()
	confirm_panel.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 6, 6))
	confirm_panel.visible = false
	confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(confirm_panel)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	confirm_panel.add_child(hb)
	confirm_lbl = UiKit.lbl("", 10, UiKit.TEXT, 2)
	confirm_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_lbl.custom_minimum_size = Vector2(150, 0)
	confirm_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(confirm_lbl)
	var ok: Button = _small_btn("✓ ДА (E)", "pend_ok", true, "green")
	ok.custom_minimum_size = Vector2(88, 44)
	hb.add_child(ok)
	confirm_ok = ok
	var x: Button = UiKit.close_btn(40.0)
	x.pressed.connect( func() -> void : action.emit("pend_cancel"))
	hb.add_child(x)


func show_confirm(text: String, ok: bool = true) -> void :
	confirm_lbl.text = text
	confirm_lbl.add_theme_color_override("font_color", UiKit.TEXT if ok else UiKit.RED)
	confirm_ok.disabled = not ok
	confirm_ok.modulate = Color.WHITE if ok else Color(1, 1, 1, 0.45)
	var was: bool = confirm_panel.visible
	confirm_panel.visible = true
	confirm_panel.custom_minimum_size = Vector2(minf(340.0, root.size.x - 12.0), 0)
	confirm_panel.reset_size()
	if not was:
		UiKit.pop_in(confirm_panel, 0.92, 0.15)


func hide_confirm() -> void :
	if confirm_panel != null:
		confirm_panel.visible = false


func show_prompt(pr: Dictionary) -> void :
	prompt_data = pr
	prompt_lbl.text = String(pr.get("text", ""))
	var act: String = String(pr.get("action", ""))
	prompt_go_btn.text = {"op_defend": "ОБОРОНА", "op_retreat": "ОТВЕСТИ", "look": "ПОКАЗАТЬ", "order_arty": "ОГОНЬ", "order_smoke": "ДЫМ", "order_ew": "ГОСПИТ.", "buy_short": "КУПИТЬ"}.get(act, "ДА")
	var warn: bool = bool(pr.get("warn", false))
	prompt_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	prompt_panel.add_theme_stylebox_override("panel", UiKit.sb("wb_btn_red_p" if warn else "wb_card", 6, 2))
	var ic: Texture2D = UiKit.tex(String(pr.get("icon", "icon_op_operation")))
	if ic != null:
		prompt_icon.texture = ic
	prompt_panel.visible = true
	prompt_panel.reset_size()
	_prompt_until = Time.get_ticks_msec() / 1000.0 + (16.0 if bool(pr.get("warn", false)) else 12.0)
	UiKit.pop_in(prompt_panel, 0.9, 0.18)
	UiKit.snd("ui_war" if bool(pr.get("warn", false)) else "ui_open")


func hide_prompt() -> void :
	prompt_panel.visible = false
	prompt_data = {}






func _rail_covered() -> bool:
	if ui24_open_now() and ui24_sheet != army_dock:
		return true
	return cmd_sheet != null and is_instance_valid(cmd_sheet) and bool(cmd_sheet.call("is_open"))


func _cmd_process(delta: float) -> void :
	if cmd_btns.is_empty():
		return
	var p: Country = gw.player
	var busy_ui: bool = ops_panel.visible or (panel != null and is_instance_valid(panel)) or _rail_covered()
	var war: bool = p != null and not p.eliminated and not p.at_war.is_empty() and gw.get("ops") != null
	_cmd_t -= delta
	if _cmd_t <= 0.0:
		_cmd_t = 0.5
		_cam_ok = gw.get("battle_watch") != null and p != null and ( not gw.battle_watch.hot_spot().is_empty() or not gw.battle_watch.last_impact().is_empty())
		_ruin = gw.mil.ruined_own(p.id) if p != null and not p.eliminated and gw.mil.has_method("ruined_own") else [0, 0]
		_jet_has = main_node != null and main_node.has_method("has_attack_jet") and bool(main_node.call("has_attack_jet"))


	var now_ms: int = Time.get_ticks_msec()
	if _cam_ok:
		_cam_hold_ms = now_ms + 8000
	if int(_ruin[0]) > 0:
		_ruin_hold_ms = now_ms + 5000
	var docked: bool = _rail_docked()
	var appeared: bool = false
	for e: Array in cmd_btns:
		var b: Button = e[0]
		var key: String = String(e[2])
		var show: bool = not busy_ui and ((now_ms < _cam_hold_ms) if key == "battle_cam" else (p != null and p.capital_id >= 0 if key == "command" else ((now_ms < _ruin_hold_ms) if key == "repair_all" else war)))
		if key.begins_with("jet_"):
			show = show and _jet_has
		if _spect:
			show = false
		if key == "rail_more":
			show = not busy_ui and not _spect and rail_more_on
			if b.visible != show:
				b.visible = show
			continue
		rail_cand[key] = show
		if show and rail_fold.has(key) and (docked or now_ms >= rail_more_ms):
			show = false
		if b.visible != show:
			b.visible = show
			appeared = appeared or show
		if not show:
			continue
		if key == "battle_cam" or key == "command" or key.begins_with("jet_"):
			continue
		if key == "repair_all":

			var ok_money: bool = p != null and int(_ruin[0]) > 0 and p.money >= mini(int(_ruin[1]), 1)
			_rail_cd(b, e[1] as Label, 0.0 if ok_money else 1.0, str(int(_ruin[0])) if int(_ruin[0]) > 0 else "")
			continue
		var k: int = int(key.right(1))
		var cd: float = gw.ops.cooldown_left(p.id, k)
		var cd_max: float = float(Operations.ORDERS[clampi(k, 0, Operations.ORDERS.size() - 1)]["cd"])
		if not is_instance_valid(e[1]):
			continue
		_rail_cd(b, e[1] as Label, cd / maxf(1.0, cd_max), (Loc.t("%d с") % ceili(cd)) if cd > 0.0 else "")


	if appeared and docked and army_dock.has_method("_restack_cmd"):
		army_dock.call("_restack_cmd")
	_rail_layout()
	_rail_tab_process(delta)
	_jet_fly_process()
	if prompt_panel.visible:
		var stale: bool = gw.get("ops") != null and gw.ops.has_method("prompt_valid") and not prompt_data.is_empty() and not bool(gw.ops.prompt_valid(prompt_data))
		if Time.get_ticks_msec() / 1000.0 > _prompt_until or p == null or stale:
			hide_prompt()
		else:
			prompt_panel.reset_size()



func _update_dip_chip() -> void :
	if gw.diplo != null and gw.diplo != _dip_obj and gw.diplo.has_signal("pending_changed"):
		_dip_obj = gw.diplo
		_dip_obj.pending_changed.connect(_on_pending_changed)
		_dip_sig = ""
	var list: Array = gw.diplo.pending_for_player() if gw.diplo != null and gw.diplo.has_method("pending_for_player") and gw.player != null else []
	var busy_ui: bool = panel != null and is_instance_valid(panel)


	var vis: bool = not list.is_empty() and not busy_ui and (lane == null or not is_instance_valid(lane))
	if dip_chip.visible != vis:
		dip_chip.visible = vis
	if list.is_empty():
		return
	var it: Dictionary = list[0]
	var dem: bool = false
	for x: Dictionary in list:
		if String(x.get("kind", "")) == "demand":
			it = x
			dem = true
			break
	var t: String = Loc.t("%s · %d с") % [Loc.t("УЛЬТИМАТУМ") if dem else Loc.t("ДИПЛОМАТИЯ"), int(float(it.get("left", 0.0)))]
	if int(float(it.get("left", 0.0))) <= 0:
		t = Loc.t("УЛЬТИМАТУМ") if dem else Loc.t("ДИПЛОМАТИЯ")
	if not dip_chip.has_meta("dem") or bool(dip_chip.get_meta("dem")) != dem:
		dip_chip.set_meta("dem", dem)
		var col: String = "red" if dem else "blue"
		dip_chip.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_" + col, 12, 4, -1))
		dip_chip.add_theme_stylebox_override("hover", UiKit.sb("wb_btn_" + col, 12, 4, -1))
		dip_chip.add_theme_stylebox_override("pressed", UiKit.sb("wb_btn_" + col + "_p", 12, 4, 1))
	if list.size() > 1:
		t += "  (+%d)" % (list.size() - 1)
	dip_chip.text = t


func _on_pending_changed() -> void :
	var list: Array = gw.diplo.pending_for_player() if gw.player != null else []
	var sig: String = ""
	for x: Dictionary in list:
		sig += String(x.get("id", "")) + ","
	if sig != _dip_sig:
		var grew: bool = false
		for x0: Dictionary in list:
			if not _dip_sig.contains(String(x0.get("id", "")) + ","):
				grew = true
		_dip_sig = sig
		if grew and not list.is_empty():
			var top: Dictionary = list[0]
			for x2: Dictionary in list:
				if String(x2.get("kind", "")) == "demand":
					top = x2
					break
			if String(top.get("kind", "")) == "demand":
				action.emit("demand_arrived")
				UiKit.snd("ui_open")
			elif list.any(pending_urgent):
				UiKit.snd("ui_open")

	_dip_t = 0.0
	if panel_kind == "diplomacy" and panel != null and is_instance_valid(panel):
		_dip_dirty = true
