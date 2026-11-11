extends "res://ui/hud/hud_dock.gd"


func _set_res(key: String, txt: String, value: int) -> void :
	var l: Label = res_labels[key]
	if l.text == txt:
		return
	l.text = txt
	if value >= 0 and _res_prev.has(key):
		var up: bool = value > int(_res_prev[key])
		l.modulate = Color(0.75, 1.4, 0.75) if up else Color(1.5, 0.75, 0.7)
		var tw: Tween = l.create_tween()
		tw.tween_property(l, "modulate", Color.WHITE, 0.5)
	if value >= 0:
		_res_prev[key] = value




func open_new_world(current: WorldSettings) -> void :
	if dialog != null:
		dialog.queue_free()
	dlg_settings = current.duplicate() as WorldSettings
	dlg_settings.world_seed = randi() % 100000000
	var vb: VBoxContainer = _window("Новый мир")
	dialog = panel
	panel = null
	_slider(vb, "СУША %", "land_percent", 15, 85)
	_slider(vb, "КОНТИНЕНТЫ", "continents", 1, 8)
	_slider(vb, "ОСТРОВА", "islands", 0, 100)
	_slider(vb, "РЕКИ", "rivers", 0, 60)
	_slider(vb, "ГОРЫ", "mountains", 0, 100)
	_slider(vb, "ЛЕСА", "forests", 0, 100)
	var ok: Button = UiKit.big("СОЗДАТЬ", "green")
	vb.add_child(ok)
	ok.pressed.connect( func() -> void :
		var s: WorldSettings = dlg_settings
		dialog.queue_free()
		dialog = null
		main_node.call("start_world", s))





func _build_ops() -> void :
	var wrap: = MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 6)
	wrap.add_theme_constant_override("margin_right", 6)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(wrap)
	ops_panel = PanelContainer.new()
	var ops_sb: StyleBox = UiKit.sb("wb_window", 10, 9)
	ops_sb.content_margin_bottom += 7.0
	ops_panel.add_theme_stylebox_override("panel", ops_sb)
	ops_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ops_panel.visible = false
	wrap.add_child(ops_panel)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	ops_panel.add_child(vb)
	var head: = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	vb.add_child(head)
	var islot: = PanelContainer.new()
	islot.add_theme_stylebox_override("panel", UiKit.sb("wb_slot", 3))
	islot.custom_minimum_size = Vector2(40, 40)
	islot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	islot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(islot)
	var icc: = CenterContainer.new()
	icc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	islot.add_child(icc)
	ops_icon = UiKit.icon_rect("", 32.0)
	icc.add_child(ops_icon)
	var tcol: = VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 1)
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tcol)
	ops_title = UiKit.lbl("", 14, UiKit.TITLE, 3, 3)
	ops_title.clip_text = true
	ops_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ops_title.gui_input.connect(func(ev: InputEvent) -> void :
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			if _ops_key.begins_with("city"):
				action.emit("city_rename"))
	tcol.add_child(ops_title)
	ops_sub = UiKit.lbl("", 10, UiKit.MUTED, 1)
	ops_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tcol.add_child(ops_sub)
	ops_close = UiKit.close_btn(42.0)
	ops_close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ops_close.pressed.connect( func() -> void :
		UiKit.snd("ui_close")
		action.emit("cancel_select"))
	head.add_child(ops_close)
	ops_info = UiKit.lbl("", 11, UiKit.TEXT, 2, 2)
	ops_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(ops_info)
	for pair: Array in [["res_drone", "wb_bar_blue"], ["res_fuel", "wb_bar_amber"]]:
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var ic: TextureRect = UiKit.icon_rect(String(pair[0]), 16.0)
		row.add_child(ic)
		var frame: = PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UiKit.sb("wb_bar_frame", 2))
		frame.custom_minimum_size = Vector2(0, 12)
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(frame)
		var fill: = Panel.new()
		fill.add_theme_stylebox_override("panel", UiKit.sb(String(pair[1]), 0))
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(fill)
		vb.add_child(row)
		ops_bars.append([row, frame, fill, ic])
	ops_row = HBoxContainer.new()
	ops_row.add_theme_constant_override("separation", 5)
	vb.add_child(ops_row)
	var minus: Button = UiKit.big("−", "stone", "", 40.0, 16)
	minus.custom_minimum_size.x = 42
	minus.pressed.connect( func() -> void : action.emit("plan_minus"))
	ops_row.add_child(minus)
	ops_count = UiKit.lbl("x1", 14, UiKit.GOLD, 3, 3)
	ops_count.custom_minimum_size = Vector2(34, 0)
	ops_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ops_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ops_row.add_child(ops_count)
	var plus: Button = UiKit.big("+", "stone", "", 40.0, 16)
	plus.custom_minimum_size.x = 42
	plus.pressed.connect( func() -> void : action.emit("plan_plus"))
	ops_row.add_child(plus)
	var sp: = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ops_row.add_child(sp)
	ops_launch = UiKit.big("ПУСК", "green", "", 40.0, 14)
	ops_launch.custom_minimum_size.x = 96
	ops_launch.pressed.connect( func() -> void : action.emit("plan_launch"))
	ops_row.add_child(ops_launch)
	var cancel: Button = UiKit.big("НАЗАД", "stone", "", 40.0, 12)
	cancel.custom_minimum_size.x = 86
	cancel.pressed.connect( func() -> void : action.emit("plan_back"))
	ops_row.add_child(cancel)
	fac_row = HFlowContainer.new()
	fac_row.add_theme_constant_override("h_separation", 4)
	fac_row.add_theme_constant_override("v_separation", 4)
	vb.add_child(fac_row)
	ops_detail = UiKit.lbl("", 9, UiKit.MUTED, 1)
	ops_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(ops_detail)


func _set_info(text: String, warn: bool) -> void :
	var key: String = text + ("!" if warn else "")
	if key == _info_key:
		return
	_info_key = key
	ops_info.text = text
	ops_info.add_theme_color_override("font_color", UiKit.RED if warn else UiKit.TEXT)


func _set_bar(i: int, frac: float, icon: String = "") -> void :
	var frame: PanelContainer = ops_bars[i][1]
	var fill: Panel = ops_bars[i][2]
	if icon != "":
		UiKit.set_icon(ops_bars[i][3] as TextureRect, icon, 16.0)
	var inner: float = maxf(0.0, frame.size.x - 4.0)
	fill.position = Vector2(2, 2)
	fill.size = Vector2(floorf(inner * clampf(frac, 0.0, 1.0)), maxf(2.0, frame.size.y - 4.0))



func show_multi(mp: Dictionary, n_targets: int, standing: bool, per: int = 0, what: String = "ДРОНОВ") -> void :
	var total: int = int(mp.get("total", 0))
	var avail: int = int(mp.get("available", 0))
	var bad: PackedStringArray = PackedStringArray()
	for pt: Dictionary in mp.get("per_target", []):
		if not bool(pt.get("ok", true)):
			bad.append(String(pt.get("reason", "")))
	var t: String = Loc.t("ЦЕЛЕЙ %d · ×%d НА ЦЕЛЬ · ВСЕГО %d · ГОТОВО %d") % [n_targets, per, total, avail] if per > 0 else Loc.t("ЦЕЛЕЙ %d · %s %d · ГОТОВО %d") % [n_targets, what, total, avail]
	if standing:
		t += Loc.t("\nАВТОПУСК: КАЖДЫЙ НОВЫЙ ДРОН ПО ЭТИМ ЦЕЛЯМ")
	if not bad.is_empty():
		t += "\n" + bad[0].to_upper()
	_set_info(t, not bad.is_empty() or avail == 0)
	ops_count.text = "x%d" % (per if per > 0 else total)
	ops_launch.disabled = avail == 0 or n_targets == 0


func _fill_acts(sig_base: String, acts: Array) -> void :
	var sig: String = sig_base + "|"
	for a: Dictionary in acts:
		sig += "%s%s%s%s;" % [a["t"], a["on"], a["sel"], a["badge"]]
	if sig == _fac_sig:
		return
	_fac_sig = sig
	for c in fac_row.get_children():
		c.queue_free()
	for a: Dictionary in acts:
		var act: String = String(a["a"])
		if String(a["i"]) != "":
			if bool(a.get("red", false)) and fac_row.get_child_count() > 0:
				var gap: = Control.new()
				gap.custom_minimum_size = Vector2(22, 0)
				gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				fac_row.add_child(gap)
			var cell: = VBoxContainer.new()
			cell.add_theme_constant_override("separation", 0)
			cell.custom_minimum_size = Vector2(52, 0)
			var b: Button = UiKit.slot(String(a["i"]), int(a["sel"]) >= 0, 40.0)
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			if bool(a.get("red", false)):
				b.self_modulate = Color(1.0, 0.55, 0.5)
			b.disabled = not bool(a["on"])
			if bool(a.get("flip", false)) and UiKit.slot_icon(b) != null:
				UiKit.slot_icon(b).flip_v = true
			if int(a["sel"]) >= 0:
				b.set_pressed_no_signal(int(a["sel"]) == 1)
			b.pressed.connect( func() -> void : action.emit(act))
			_act_tip(b, act, String(a["t"]), int(a["sel"]))
			cell.add_child(b)
			if String(a["badge"]) != "":
				var bd: Label = UiKit.lbl(String(a["badge"]), 10, UiKit.GOLD, 3, 3)
				bd.position = Vector2(30, 26)
				b.add_child(bd)
			var txt: String = String(a["t"])
			var l: Label = UiKit.lbl(txt, 9, (UiKit.RED if bool(a.get("red", false)) else UiKit.TEXT) if bool(a["on"]) else UiKit.DIM, 2, 3)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.custom_minimum_size = Vector2(52, 0)
			l.mouse_filter = Control.MOUSE_FILTER_PASS
			l.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not b.disabled:
					b.emit_signal("pressed")
			)
			cell.add_child(l)
			fac_row.add_child(cell)
		else:
			var colour: String = "gold" if int(a["sel"]) == 1 else "stone"
			var tb: Button = UiKit.big(String(a["t"]), colour, "", 38.0, 11)
			tb.custom_minimum_size.x = 70
			tb.disabled = not bool(a["on"])
			tb.pressed.connect( func() -> void : action.emit(act))
			_act_tip(tb, act, String(a["t"]), int(a["sel"]))
			fac_row.add_child(tb)




func _act_tip(b: Control, act: String, shown: String, sel: int) -> void :
	var ln: String = Loc.t(HoldTip.act_line(act))
	if ln == "":
		return
	var st: String = ""
	if act == "stance_cycle" and shown.find("\n") > 0:
		st = shown.get_slice("\n", 1)
	elif sel >= 0 and act in ["smart_toggle", "plan_standing"]:
		st = Loc.t("ВКЛ") if sel == 1 else Loc.t("ВЫКЛ")
	if st != "":
		var i: int = ln.find(" — ")
		ln = "%s: %s%s" % [ln.left(i), st, ln.substr(i)]
	HoldTip.tip(b, ln)
