class_name Hud
extends "res://ui/hud/hud_lane.gd"





func setup(m: Node, world: GameWorld) -> void :
	main_node = m
	gw = world
	UiKit.ensure()
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.make_theme()
	add_child(root)
	labels_root = Control.new()
	labels_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	labels_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(labels_root)
	_build_top()
	_build_bottom()
	WidthGuard.watch(holder, root)
	WidthGuard.watch(top_col, root)
	_build_selection()
	_build_ores()
	_build_mapchip()
	_build_cmd()
	_build_confirm()
	_build_plan()
	_build_armies()
	_build_toast()
	busy = Control.new()
	gw.changed.connect(refresh)
	if not Loc.bus.changed.is_connected(_lang_refresh):
		Loc.bus.changed.connect(_lang_refresh)
	gw.message.connect(_on_world_message)

func _lang_refresh() -> void :
	if gw != null and is_instance_valid(gw) and top_name != null and is_instance_valid(top_name):
		refresh()
		_race_t = 0.0
	for nm: String in key_labels:
		var l: Variant = key_labels[nm]
		var src: String = String((KEY_INFO.get(nm, [""]) as Array)[0])
		if not is_instance_valid(l):
			continue
		var kl: Label = l
		if src in KEY_CTX:
			kl.text = _key_text(src)
		BuildPanel.fit(kl, BuildPanel.CELL_W, BuildPanel.KEY_FONT)

const KEY_CTX: Array = ["ЗАВОД", "ДОКИ"]

static func _l345_pot() -> Array:
	return [Loc.t("ЗАВОД", "key"), Loc.t("ДОКИ", "key"), Loc.t("ПРЕДЛОЖЕНИЯ", "offer"), Loc.t("ДИВИЗИЯ", "group"), Loc.t("РЕЗЕРВ", "group"), 
		Loc.t("БРИГАДА", "group"), Loc.t("ПОЛК", "group"), Loc.t("КОРПУС", "group"), Loc.t("БАТАЛЬОН", "group"), 
		Loc.t("ГВАРДИЯ", "group"), Loc.t("ШТУРМ", "group"), Loc.t("ТАНКИ", "group"), Loc.t("ТЫЛ", "group")]

func _key_text(src: String) -> String:
	return Loc.tc(src, "key") if src in KEY_CTX else src




func _build_top() -> void :
	var st: float = _safe_margins().x
	var col: = VBoxContainer.new()
	top_col = col
	col.set_anchors_preset(Control.PRESET_TOP_WIDE)
	col.add_theme_constant_override("separation", -6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	var bar: = PanelContainer.new()
	var bsb: StyleBox = UiKit.sb("wb_topbar", 8, 3)
	bsb.content_margin_top = st + 4.0
	bar.add_theme_stylebox_override("panel", bsb)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bar.gui_input.connect(func(ev: InputEvent) -> void:
		var mb: = ev as InputEventMouseButton
		var st_touch: = ev as InputEventScreenTouch
		if (mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed) or (st_touch != null and not st_touch.pressed):
			UiKit.snd("ui_click")
			open_my_state())
	col.add_child(bar)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	bar.add_child(hb)
	top_flag = TextureRect.new()
	top_flag.custom_minimum_size = Vector2(24, 16)
	top_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_flag.stretch_mode = TextureRect.STRETCH_SCALE
	top_flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top_flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(top_flag)
	top_badge = CenterContainer.new()
	top_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_badge.visible = false
	hb.add_child(top_badge)
	top_name = UiKit.lbl("", 13, UiKit.TEXT, 2, 3)
	top_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.fit_lbl(top_name, [13, 12, 11, 10], false, true)
	top_name.resized.connect( func() -> void : _race_refit.call_deferred())
	top_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(top_name)

	for tc: Control in [top_flag, top_name]:
		tc.mouse_filter = Control.MOUSE_FILTER_STOP
		tc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tc.gui_input.connect( func(ev: InputEvent) -> void :
			var mb: = ev as InputEventMouseButton
			var st_touch: = ev as InputEventScreenTouch
			if (mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed) or (st_touch != null and not st_touch.pressed):
				UiKit.snd("ui_click")
				open_my_state())
	var tr: TextureRect = UiKit.icon_rect("res_score", 16.0)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(tr)

	var sv: = VBoxContainer.new()
	sv.add_theme_constant_override("separation", -2)
	sv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sv.mouse_filter = Control.MOUSE_FILTER_STOP
	sv.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sv.gui_input.connect( func(ev: InputEvent) -> void :
		if (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
			UiKit.snd("ui_click")
			action.emit("scores"))
	hb.add_child(sv)
	score_lbl = UiKit.lbl("0", 12, UiKit.GOLD, 2, 3)
	score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.add_child(score_lbl)
	race_lbl = UiKit.lbl("", 9, UiKit.MUTED, 1, 2)
	race_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	race_lbl.visible = false
	sv.add_child(race_lbl)
	clock_lbl = UiKit.lbl("", 11, UiKit.MUTED, 1, 2)
	clock_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clock_lbl.custom_minimum_size = Vector2(36, 0)
	clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(clock_lbl)
	var mb: Button = UiKit.slot("icon_menu", false, 40.0)
	mb.pressed.connect( func() -> void : action.emit("menu"))
	hb.add_child(mb)

	res_panel = PanelContainer.new()
	res_panel.add_theme_stylebox_override("panel", UiKit.sb("wb_pill", 8, 3))
	res_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	res_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	res_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	res_panel.gui_input.connect( func(ev: InputEvent) -> void :
		var mb_ev: = ev as InputEventMouseButton
		var st_ev: = ev as InputEventScreenTouch
		if (mb_ev != null and mb_ev.button_index == MOUSE_BUTTON_LEFT and not mb_ev.pressed) or (st_ev != null and not st_ev.pressed):
			UiKit.snd("ui_click")
			open_inventory())
	res_panel.visible = false
	col.add_child(res_panel)
	var rb: = HBoxContainer.new()
	rb.add_theme_constant_override("separation", 7)
	rb.mouse_filter = Control.MOUSE_FILTER_PASS
	res_panel.add_child(rb)
	for pair: Array in RES_KEYS:
		var key_name: String = String(pair[0])
		var cell: = HBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		rb.add_child(cell)
		var ic: TextureRect = UiKit.icon_rect(String(pair[1]), 15.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.add_child(ic)
		var l: Label = UiKit.lbl("0", 10, UiKit.TEXT, 2, 2)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.add_child(l)
		res_labels[pair[0]] = l

		cell.gui_input.connect(func(ev: InputEvent) -> void:
			var mb_ev: = ev as InputEventMouseButton
			var st_ev: = ev as InputEventScreenTouch
			if (mb_ev != null and mb_ev.button_index == MOUSE_BUTTON_LEFT and not mb_ev.pressed) or (st_ev != null and not st_ev.pressed):
				UiKit.snd("ui_click")
				if key_name == "money":
					open_hub(2)
				elif key_name == "power":
					open_hub(0)
				else:
					open_inventory()
		)

	var chip: = HBoxContainer.new()
	chip.add_theme_constant_override("separation", 2)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rb.add_child(chip)
	var sic: TextureRect = UiKit.icon_rect("icon_inventory" if UiKit.has("icon_inventory") else "icon_store", 18.0)
	sic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sic.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.add_child(sic)
	var sl: Label = UiKit.lbl("СКЛАД", 10, UiKit.GOLD, 2, 2)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.add_child(sl)
	res_labels["store"] = sl
	chip.gui_input.connect(func(ev: InputEvent) -> void:
		var mb_ev: = ev as InputEventMouseButton
		var st_ev: = ev as InputEventScreenTouch
		if (mb_ev != null and mb_ev.button_index == MOUSE_BUTTON_LEFT and not mb_ev.pressed) or (st_ev != null and not st_ev.pressed):
			UiKit.snd("ui_click")
			open_inventory()
	)

	news_panel = _tooltip_panel()
	news_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	news_panel.visible = false
	col.add_child(news_panel)
	news_label = UiKit.lbl("", 10, UiKit.TEXT, 1)
	news_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	news_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	news_label.custom_minimum_size = Vector2(300, 0)
	news_panel.add_child(news_label)
	hint_panel = _tooltip_panel()
	hint_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint_panel.visible = false
	col.add_child(hint_panel)
	hint = UiKit.lbl("", 10, UiKit.TITLE, 2)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(290, 0)
	hint_panel.add_child(hint)

	advisor = PanelContainer.new()
	advisor.add_theme_stylebox_override("panel", UiKit.sb("wb_tooltip", 8, 6))
	advisor.mouse_filter = Control.MOUSE_FILTER_STOP
	advisor.visible = false
	advisor.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(advisor)
	var ah: = HBoxContainer.new()
	ah.add_theme_constant_override("separation", 6)
	advisor.add_child(ah)
	var aic: TextureRect = UiKit.icon_rect("icon_hint" if UiKit.has("icon_hint") else "icon_tutorial", 22.0)
	aic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ah.add_child(aic)
	advisor_lbl = UiKit.lbl("", 10, UiKit.TEXT, 1, 2)
	advisor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	advisor_lbl.custom_minimum_size = Vector2(270, 0)
	ah.add_child(advisor_lbl)
	advisor.gui_input.connect( func(ev: InputEvent) -> void :
		if (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
			advisor.visible = false)
	war_banner = UiKit.title("", 24, UiKit.RED)
	war_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	war_banner.offset_top = 190
	war_banner.offset_left = 10
	war_banner.offset_right = -10
	war_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	war_banner.visible = false
	root.add_child(war_banner)




func _cell(nm: String, icon: String, toggle: bool) -> VBoxContainer:
	var cell: = VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size = Vector2(BuildPanel.CELL_W, 0)
	var ic_name: String = icon if UiKit.has(icon) else String(EconKit.FALLBACK.get(icon, icon))
	var b: Button = UiKit.slot(ic_name, toggle, 46.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect( func() -> void :
		_show_tip_for(nm)
		if nm == "ultimatum":
			_ultimatum_key()
			return
		action.emit(nm))
	cell.add_child(b)
	keys[nm] = b
	var info: Array = KEY_INFO.get(nm, [nm.to_upper(), "", ""])
	var l: Label = UiKit.lbl(_key_text(String(info[0])), BuildPanel.KEY_FONT, UiKit.TEXT, 2, 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(BuildPanel.CELL_W, 0)
	l.clip_text = true
	BuildPanel.fit(l, BuildPanel.CELL_W, BuildPanel.KEY_FONT)
	cell.add_child(l)
	key_labels[nm] = l
	return cell


func _build_bottom() -> void :
	var sb: float = _safe_margins().y
	holder = VBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_constant_override("separation", 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	_build_ops()
	var gap: = Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(gap)
	tab_row = HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_theme_constant_override("separation", 1)
	tab_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tab_row)
	bottom_panel = PanelContainer.new()
	var psb: StyleBox = UiKit.sb("wb_panel", 8, 7)
	psb.content_margin_bottom = 7.0 + sb
	bottom_panel.add_theme_stylebox_override("panel", psb)
	bottom_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(bottom_panel)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_panel.add_child(row)
	_left_grid = GridContainer.new()
	_left_grid.columns = 2
	_left_grid.add_theme_constant_override("v_separation", 2)
	_left_grid.add_theme_constant_override("h_separation", 2)
	row.add_child(_left_grid)
	_left_grid.add_child(_cell("pause", "icon_pause", false))
	_left_grid.add_child(_cell("speed", "icon_speed", false))
	speed_badge = UiKit.lbl("x1", 10, UiKit.GOLD, 2, 3)
	speed_badge.position = Vector2(26, 28)
	(keys["speed"] as Button).add_child(speed_badge)
	var div: = TextureRect.new()
	div.texture = UiKit.tex("wb_divider")
	div.custom_minimum_size = Vector2(6, 0)
	div.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	div.stretch_mode = TextureRect.STRETCH_SCALE
	div.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if div.texture == null:
		var cr: = ColorRect.new()
		cr.color = Color("2a2c22")
		cr.custom_minimum_size = Vector2(2, 0)
		row.add_child(cr)
	else:
		row.add_child(div)

	var arrow_l: = Button.new()
	arrow_l.text = "<"
	arrow_l.custom_minimum_size = Vector2(24, 46)
	arrow_l.focus_mode = Control.FOCUS_NONE
	arrow_l.add_theme_stylebox_override("normal", UiKit.sb("wb_slot", 2, 2))
	arrow_l.add_theme_stylebox_override("hover", UiKit.sb("wb_slot", 2, 2))
	arrow_l.add_theme_stylebox_override("pressed", UiKit.sb("wb_slot_pressed", 2, 2))
	arrow_l.add_theme_font_size_override("font_size", 13)
	row.add_child(arrow_l)

	var sc: = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 56)
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(sc)

	var stack: = Control.new()
	_keys_stack = stack
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.custom_minimum_size = Vector2(0, 56)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(stack)

	var arrow_r: = Button.new()
	arrow_r.text = ">"
	arrow_r.custom_minimum_size = Vector2(24, 46)
	arrow_r.focus_mode = Control.FOCUS_NONE
	arrow_r.add_theme_stylebox_override("normal", UiKit.sb("wb_slot", 2, 2))
	arrow_r.add_theme_stylebox_override("hover", UiKit.sb("wb_slot", 2, 2))
	arrow_r.add_theme_stylebox_override("pressed", UiKit.sb("wb_slot_pressed", 2, 2))
	arrow_r.add_theme_font_size_override("font_size", 13)
	row.add_child(arrow_r)

	arrow_l.pressed.connect(func() -> void:
		sc.scroll_horizontal = maxi(0, sc.scroll_horizontal - 120)
		UiKit.snd("ui_click")
	)
	arrow_r.pressed.connect(func() -> void:
		sc.scroll_horizontal = sc.scroll_horizontal + 120
		UiKit.snd("ui_click")
	)

	var desktop_tabs: bool = root.size.x >= 900.0
	var desktop_tab_labels: Array[String] = ["КАРТА", "ГОРОДА", "УДАРЫ", "ПВО", "АРМИЯ", "ДИПЛОМАТИЯ", "ФЛОТ"]
	var tab_width: float = 108.0 if desktop_tabs else BuildPanel.TAB_W
	for p in PAGE_DEFS.size():
		var def: Array = PAGE_DEFS[p]
		var tab_label: String = desktop_tab_labels[p] if desktop_tabs else String(TAB_SHORT[p])
		var tb: Button = BuildPanel.make_tab(String(def[0]), tab_label, tab_width, desktop_tabs)
		tb.tooltip_text = "%s · %s %d" % [Loc.t(String(PAGE_TITLES[p])), Loc.t("Клавиша"), p + 1]
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect( func() -> void : _on_tab_tap(p))
		var num_badge: = Label.new()
		num_badge.text = str(p + 1)
		num_badge.add_theme_font_size_override("font_size", 9)
		num_badge.add_theme_color_override("font_color", UiKit.GOLD)
		num_badge.position = Vector2(4, 2)
		num_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tb.add_child(num_badge)
		tab_row.add_child(tb)
		tabs.append(tb)
		var grid: = GridContainer.new()
		grid.columns = 30
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.set_anchors_preset(Control.PRESET_FULL_RECT)
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 2)
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for it: Array in def[1]:
			grid.add_child(_cell(String(it[0]), String(it[1]), bool(it[2])))
		stack.add_child(grid)
		pages.append(grid)

	tip_pc = _tooltip_panel()
	tip_pc.visible = false
	root.add_child(tip_pc)
	tip_box = VBoxContainer.new()
	tip_box.add_theme_constant_override("separation", 2)
	tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_pc.add_child(tip_box)
	tip_title = UiKit.title("", 16)
	tip_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_box.add_child(tip_title)
	tip_cost = HFlowContainer.new()
	tip_cost.alignment = FlowContainer.ALIGNMENT_CENTER
	tip_cost.add_theme_constant_override("h_separation", 8)
	tip_cost.add_theme_constant_override("v_separation", 2)
	tip_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_box.add_child(tip_cost)
	tip_yield = UiKit.lbl("", 11, UiKit.GREEN, 2, 3)
	tip_yield.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_yield.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_yield.visible = false
	tip_box.add_child(tip_yield)
	tip_sub = UiKit.lbl("", 11, UiKit.TEXT, 1, 3)
	tip_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_box.add_child(tip_sub)
	tip_warn = UiKit.lbl("", 10, UiKit.GOLD, 2, 3)
	tip_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_box.add_child(tip_warn)
	_select_page(0, false)




func _build_toast() -> void :
	toast_panel = _tooltip_panel()
	toast_panel.visible = false
	root.add_child(toast_panel)
	toast_label = UiKit.lbl("", 11, UiKit.TEXT, 2, 2)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel.add_child(toast_label)

	lane = NotifLaneScript.new()
	lane.name = "NotifLane"
	lane.call("attach", self)
	lane.connect("action", _on_lane_action)
	tap_guard = TapGuardScript.new()
	tap_guard.name = "TapGuard"
	get_tree().root.add_child.call_deferred(tap_guard)
	help_tips = HelpTipsScript.new()
	help_tips.call("mount", self)


func _ally_poll() -> void :
	if gw == null or gw.player == null or gw.player.eliminated or gw.diplo == null or gw.diplo.get("ally") == null:
		return
	if ally_sheet != null and is_instance_valid(ally_sheet):
		return
	var aid: int = gw.diplo.ally.needs_style(gw.player.id)

	var ak: String = "%d@%.1f" % [aid, float(gw.diplo.ally.get_a(aid).get("founded", 0.0))]
	if aid >= 0 and not _ally_asked.has(ak):
		_ally_asked[ak] = true
		open_ally_sheet(aid, false)


func open_ally_sheet(aid: int, edit: bool) -> void :
	if ally_sheet != null and is_instance_valid(ally_sheet):
		ally_sheet.queue_free()
	ally_sheet = AllySheetS.open(self, gw, aid, edit)


func _process(delta: float) -> void :
	_t += delta
	var now: float = Time.get_ticks_msec() / 1000.0
	_hold_inject()
	_ally_t -= delta
	if _ally_t <= 0.0:
		_ally_t = 0.5
		_ally_poll()
	_res_t -= delta
	if gw != null and gw.player != null and gw.mil != null and _res_t <= 0.0:
		_res_t = 0.2
		var p: Country = gw.player
		if p.eliminated != _spect:
			_apply_spectator(p.eliminated)
		_set_res("money", short_num(p.money), p.money)
		_set_res("drones", str(gw.mil.parked_count(p.id)), -1)
		_set_res("missiles", str(gw.mil.missiles_ready(p.id)), -1)
		_set_res("power", "%d/%d" % [p.power_use, p.power_cap], -1)
		_warn_col("power", p.power_use > p.power_cap)
		_set_res("food", str(p.food), -1)
		_warn_col("food", p.food <= 0 and gw.army.count_units(p.id) > 0)
		var short: String = _shortage(p)
		_set_res("store", ((Loc.t("НЕТ ") if short != "" and int(p.get(short)) <= 0 else Loc.t("МАЛО ")) + String({"titanium": Loc.t("ТИТАНА"), "metal": Loc.t("МЕТАЛЛА"), "wood": Loc.t("ДЕРЕВА"), "oil": Loc.t("НЕФТИ"), "precious": Loc.t("ДРАГМЕТ."), "uranium": Loc.t("УРАНА")}.get(short, Loc.t("СЫРЬЯ")))) if short != "" else Loc.t("СКЛАД"), -1)
		_warn_col("store", short != "")
		if panel_kind == "inventory" and int(_t * 5.0) % 10 == 0:

			var sig: String = ""
			for it: Array in STORE:
				sig += str(p.get(String(it[0]))) + ","
			if sig != _inv_sig:
				_inv_sig = sig
				_inv_update(p)

		_adv_t -= 0.2
		if _adv_t <= 0.0:
			_adv_t = 25.0
			if GameConfig.hints and gw.econ.has_method("next_tip") and not (panel != null and is_instance_valid(panel)):
				var tip: String = String(gw.econ.call("next_tip", p))
				if tip != "" and tip != _adv_last and not _adv_dup(tip):
					_adv_last = tip
					advisor_lbl.text = tip
					advisor.visible = true
					UiKit.pop_in(advisor, 0.9, 0.2)
					_adv_until = now + 9.0
		if advisor.visible and (now > _adv_until or not GameConfig.hints or (panel != null and is_instance_valid(panel))):
			advisor.visible = false

		var reqs: Array = gw.econ.requests_for(p.id)
		if reqs.size() > _req_seen and not reqs.is_empty():
			var rq: Dictionary = reqs[reqs.size() - 1]
			var oc: Country = gw.country_by_id(int(rq["from"]))
			if oc != null:
				push_news(Loc.msg(Loc.mk("%s хочет купить %s %d — ТОРГОВЛЯ", [Loc.name(oc.name), String(Economy.RES_NAMES.get(String(rq["res"]), "")).to_lower(), int(rq["n"])])), "amber")
		_req_seen = reqs.size()
		score_lbl.text = str(p.score)
		_race_t -= 0.2
		if _race_t <= 0.0 and gw.session != null and gw.session.has_method("race_info"):
			_race_t = 2.0
			var ri: Dictionary = gw.session.race_info()
			var rt: String = String(ri.get("text", ""))
			var tgt: int = int(ri.get("target", 0))
			race_lbl.remove_meta("opts")
			if tgt > 0:
				var lk: String = Loc.dec("%.1f" % (float(ri.get("leader_score", 0)) / 1000.0))
				var who: String = Loc.t("вы лидер") if bool(ri.get("leader_is_player", false)) else Loc.t("лидер")
				rt = Loc.t("%s %s/%d тыс.") % [who, lk, roundi(tgt / 1000.0)]
				race_lbl.set_meta("opts", [rt, "%s %s/%d" % [who, lk, roundi(tgt / 1000.0)], who])
				rt = _race_fit(race_lbl.get_meta("opts"))
			race_lbl.visible = bool(ri.get("on", true)) and rt != ""
			race_lbl.text = rt.to_upper()
			var pct: float = float(ri.get("pct", 0.0))
			race_lbl.add_theme_color_override("font_color", UiKit.GREEN if bool(ri.get("leader_is_player", false)) else (UiKit.RED if pct >= 0.8 else (UiKit.GOLD if pct >= 0.6 else UiKit.MUTED)))
	if gw != null and gw.night != null:
		clock_lbl.text = gw.night.clock_text()
	_news_tick()
	if war_banner.visible and now > war_until:
		var tw: Tween = war_banner.create_tween()
		tw.tween_property(war_banner, "modulate:a", 0.0, 0.3)
		tw.tween_callback( func() -> void : war_banner.visible = false)
		war_until = now + 100.0
	if toast_panel.visible and now > toast_until:
		toast_panel.visible = false
	if tip_pc.visible:
		_place_tip()
		if now > _tip_until:
			tip_pc.modulate.a = maxf(0.0, tip_pc.modulate.a - delta * 3.0)
			if tip_pc.modulate.a <= 0.0:
				tip_pc.visible = false

	var k: float = 1.0 + 0.18 * sin(_t * 5.0)
	for nm: String in keys:
		var b: Button = keys[nm]
		if b.toggle_mode and b.is_visible_in_tree():
			var ic: TextureRect = UiKit.slot_icon(b)
			if ic != null:
				ic.modulate = Color(k, k, k) if b.button_pressed else Color.WHITE
	if panel != null and is_instance_valid(panel) and panel.has_meta("scroll"):
		var sc: ScrollContainer = panel.get_meta("scroll")
		var room: float = holder.position.y - win_reserve - (_win_top() - 4.0) - 96.0
		var want_h: float = minf((panel.get_meta("inner") as Control).get_combined_minimum_size().y, maxf(120.0, room))
		if absf(sc.custom_minimum_size.y - want_h) > 4.0:
			sc.custom_minimum_size.y = want_h
	_shrink_t -= delta
	if _shrink_t <= 0.0:
		_shrink_t = 0.3
		for win: Control in [panel, dialog, toast_panel]:

			if win != null and is_instance_valid(win) and win.size.y > win.get_combined_minimum_size().y + 6.0:
				win.reset_size()
	var want_card: bool = _sel_key != "" and not ops_panel.visible and not (confirm_panel != null and confirm_panel.visible)


	if sel_card.visible != want_card and (want_card or sel_card.position.x >= 0.0 or _sel_key != ""):
		sel_card.visible = want_card
		if want_card:
			sel_card.reset_size()
			sel_card.position.x = -90.0
			var tw3: Tween = sel_card.create_tween()
			tw3.tween_property(sel_card, "position:x", 4.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_cmd_process(delta)

	if bottom_panel != null and ops_panel != null:
		var fold: bool = keys_collapsed and not _tut_on()
		var want_bp: bool = not ops_panel.visible and not ui24_open_now() and not fold
		if bottom_panel.visible != want_bp:
			bottom_panel.visible = want_bp
		if _fold_pad != null and _fold_pad.visible != (fold and not ops_panel.visible):
			_fold_pad.visible = fold and not ops_panel.visible
	_cc_process(delta)
	_plan_process(delta)
	_perf_process(delta)
	_armies_process(delta)
	_econ_process(delta)
	if confirm_panel != null and confirm_panel.visible:
		confirm_panel.reset_size()
		var cy: float = holder.position.y - confirm_panel.size.y - 8.0
		if ops_panel.visible:
			cy = minf(cy, ops_panel.global_position.y - confirm_panel.size.y - 6.0)
		confirm_panel.position = Vector2(roundf((root.size.x - confirm_panel.size.x) * 0.5), roundf(cy))
	if panel_kind == "diplomacy" and panel != null and is_instance_valid(panel) and gw.diplo != null and gw.diplo.has_method("pending_for_player"):
		_dip_live_t -= delta
		_dip_rebuild_t -= delta
		if _dip_dirty and _dip_rebuild_t <= 0.0 and not _finger_down():

			_dip_dirty = false
			_dip_rebuild_t = 1.5
			open_diplomacy()
		if _dip_live_t <= 0.0:
			_dip_live_t = 1.0
			for tl: Array in _dip_timers:
				if is_instance_valid(tl[0]):
					(tl[0] as Label).text = Loc.t("%d с") % maxi(0, int(float(tl[1]) - gw.game_time)) if float(tl[1]) >= 0.0 else "∞"
	_dip_t -= delta
	if dip_chip != null and _dip_t <= 0.0:
		_dip_t = 0.5
		_update_dip_chip()
	_layout_top_stack()
	_fit_ad_rules_window()
	if gw.player != null and gw.player.eliminated and hint.text == "":
		set_hint("НАБЛЮДЕНИЕ: ВАША СТРАНА ВЫБЫЛА")

	if ore_btn != null:
		var busy_ui: bool = ops_panel.visible or (panel != null and is_instance_valid(panel)) or _rail_covered()
		var ore_vis: bool = gw != null and gw.player != null and not busy_ui and not _spect
		rail_cand["ore"] = ore_vis
		if ore_vis and rail_fold.has("ore") and (_rail_docked() or (Time.get_ticks_msec() >= rail_more_ms and not ores_open)):
			ore_vis = false
		if ore_btn.visible != ore_vis:
			ore_btn.visible = ore_vis
		ore_panel.visible = ores_open and ore_btn.visible
		var ry: float = _rail_ry()
		_rail_layout()
		if army_dock != null and army_dock.visible and bool(army_dock.is_open) and army_dock.has_method("_restack_cmd"):
			army_dock._restack_cmd()
		ore_panel.position = Vector2(root.size.x - ore_panel.size.x - 52.0, clampf(ry - 80.0, 120.0, maxf(120.0, holder.position.y - ore_panel.size.y - 6.0)))
		if ore_panel.visible:
			var lh: float = clampf(ore_list.get_combined_minimum_size().y, 40.0, 260.0)
			if absf(ore_scroll.custom_minimum_size.y - lh) > 0.5:
				ore_scroll.custom_minimum_size.y = lh
				ore_panel.reset_size()
		_ore_t -= delta
		if _ore_t <= 0.0:
			_ore_t = 2.0
			_refresh_ores()
	if sel_card.visible and sel_card.position.x >= 0.0:

		var want: float = clampf(root.size.y * 0.4, 150.0, maxf(150.0, holder.position.y - sel_card.size.y - 10.0))
		sel_card.position.y = lerpf(sel_card.position.y, want, minf(1.0, delta * 12.0))
	if gw == null or gw.camera == null:
		return
	_place_city_labels()


func _scroll_under(p: Vector2) -> ScrollContainer:
	var cands: Array = []
	if panel != null and is_instance_valid(panel) and panel.visible and panel.has_meta("scroll"):
		cands.append(panel.get_meta("scroll"))
	if ore_scroll != null and ore_panel.visible:
		cands.append(ore_scroll)
	if ui24_open_now() and ui24_sheet.has_method("scroll_area"):
		var u24: Variant = ui24_sheet.call("scroll_area")
		if u24 is ScrollContainer:
			cands.append(u24)
	if armies_bar != null and armies_bar.visible and armies_bar.get_child_count() > 0 and armies_bar.get_child(0) is ScrollContainer:
		cands.append(armies_bar.get_child(0))
	for scv: Variant in cands:
		if not is_instance_valid(scv) or not (scv is ScrollContainer):
			continue
		var sc: ScrollContainer = scv
		if sc.is_visible_in_tree() and sc.get_global_rect().has_point(p):
			return sc
	if tap_guard != null:
		return tap_guard.call("scroll_at", p)
	return null


func _input(event: InputEvent) -> void :
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
		UiKit.tap_begin()
	if event is InputEventScreenTouch or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and event.device != InputEvent.DEVICE_ID_EMULATION):
		if event.is_pressed() and tip_pc != null and tip_pc.visible and Time.get_ticks_msec() / 1000.0 - _tip_shown > 0.3:
			_tip_until = 0.0
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).index == 0:
		if event.is_pressed():
			_tap_btn = _button_under()

			var tp: Vector2 = (event as InputEventScreenTouch).position
			if jet_fly != null and jet_fly.visible and not jet_fly.get_global_rect().grow(4.0).has_point(tp):
				var jk2: Control = keys.get("jet_menu") as Control
				if jk2 == null or not jk2.get_global_rect().grow(4.0).has_point(tp):
					_jet_fly_close()
			_tap_from = (event as InputEventScreenTouch).position
			_tap_moved = false
		else:
			_tap_btn = null
			_tap_moved = false
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == 0 and not _tap_moved:
		if (event as InputEventScreenDrag).position.distance_to(_tap_from) > 10.0:
			_tap_moved = true
			_cancel_tap()
	if event is InputEventScreenTouch:
		var st: = event as InputEventScreenTouch
		if st.index != 0:
			return
		if st.pressed:
			_sd_sc = _scroll_under(st.position)
			_sd_start = st.position
			_sd_moved = false
			if _sd_sc != null:
				_sd_origin = Vector2(_sd_sc.scroll_horizontal, _sd_sc.scroll_vertical)
		else:
			if _sd_moved:
				get_viewport().set_input_as_handled()
			_sd_sc = null
			_sd_moved = false
	elif event is InputEventScreenDrag and _sd_sc != null:
		var sd: = event as InputEventScreenDrag
		if sd.index != 0 or not is_instance_valid(_sd_sc):
			return
		var d: Vector2 = sd.position - _sd_start
		var horiz: bool = _sd_sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
		if not _sd_moved and (absf(d.x) if horiz else absf(d.y)) > 10.0:
			_sd_moved = true
			_cancel_tap()
		if _sd_moved:
			if horiz:
				_sd_sc.scroll_horizontal = int(_sd_origin.x - d.x)
			else:
				_sd_sc.scroll_vertical = int(_sd_origin.y - d.y)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and _sd_eat_release:
		var mb: = event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION and not mb.pressed:
			_sd_eat_release = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _sd_moved:
		if (event as InputEventMouseMotion).device == InputEvent.DEVICE_ID_EMULATION:
			get_viewport().set_input_as_handled()
