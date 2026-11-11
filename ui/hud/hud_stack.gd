extends "res://ui/hud/hud_kit.gd"

const ORE_FILTERS: Array[String] = ["", "metal", "titanium", "precious", "oil", "uranium"]
var _ore_filter: String = ""


func _select_page(p: int, show_tip: bool) -> void :
	if ops_panel != null and ops_panel.visible and not bottom_panel.visible and not _tab_quiet:
		action.emit("cancel_select")
	var changed: bool = p != _page
	_page = p
	for i in pages.size():
		var g: Control = pages[i]
		g.visible = i == p
		if i == p and changed:
			g.position = Vector2(14, 0)
			g.modulate.a = 0.0
			var tw: Tween = g.create_tween().set_parallel(true)
			tw.tween_property(g, "position", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(g, "modulate:a", 1.0, 0.14)
	for i in tabs.size():
		tabs[i].set_pressed_no_signal(i == p)
		BuildPanel.style_tab(tabs[i], i == p)


	var n: int = (PAGE_DEFS[p][1] as Array).size()
	if _left_grid != null:
		_left_grid.columns = 2
	if _keys_stack != null:
		_keys_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_fit_keys_stack.call_deferred()
	if show_tip:
		show_tip(String(PAGE_TITLES[p]), String(PAGE_SUBS[p]))
	if not _tab_quiet:
		action.emit("page_%d" % p)


func select_page(p: int) -> void :
	for i in tabs.size():
		tabs[i].set_pressed_no_signal(i == p)
	_select_page(p, false)




func _build_selection() -> void :
	sel_card = PanelContainer.new()
	sel_card.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 6, 7))
	sel_card.mouse_filter = Control.MOUSE_FILTER_STOP
	sel_card.visible = false
	sel_card.custom_minimum_size = Vector2(74, 0)
	root.add_child(sel_card)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	sel_card.add_child(vb)
	var slot: = PanelContainer.new()
	slot.add_theme_stylebox_override("panel", UiKit.sb("wb_slot_active", 4))
	slot.custom_minimum_size = Vector2(52, 52)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(slot)
	var cc: = CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cc)
	sel_icon = UiKit.icon_rect("", 42.0)
	cc.add_child(sel_icon)
	sel_name = UiKit.lbl("", 9, UiKit.TEXT, 2, 3)
	sel_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sel_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sel_name.custom_minimum_size = Vector2(62, 0)
	sel_name.max_lines_visible = 3
	vb.add_child(sel_name)
	var x: Button = UiKit.close_btn(40.0)
	x.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	x.pressed.connect( func() -> void :
		UiKit.snd("ui_cancel")
		action.emit("cancel_select"))
	vb.add_child(x)



func set_selection(title: String, _sub: String, icon: String = "") -> void :
	var key: String = title + "|" + icon
	if key == _sel_key:
		return
	var was: bool = _sel_key != ""
	_sel_key = key if title != "" else ""
	if title == "":
		if sel_card.visible:
			var tw: Tween = sel_card.create_tween()
			tw.tween_property(sel_card, "position:x", -90.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tw.tween_callback( func() -> void : sel_card.visible = false)
		return
	UiKit.set_icon(sel_icon, icon if icon != "" else "icon_info", 42.0)
	sel_name.text = Loc.t(title).to_upper()

	var sfn: Font = sel_name.get_theme_font("font")
	var sw: float = 62.0
	for wd: String in sel_name.text.split(" ", false):
		sw = maxf(sw, ceilf(sfn.get_string_size(wd, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x) + 4.0)
	sel_name.custom_minimum_size.x = minf(sw, 112.0)
	if ops_panel.visible:
		return
	sel_card.visible = true
	sel_card.reset_size()
	var y: float = clampf(root.size.y * 0.4, 150.0, maxf(150.0, holder.position.y - sel_card.size.y - 10.0))
	sel_card.position = Vector2(4, y)
	if not was or sel_card.position.x < 0.0:
		sel_card.position.x = -90.0
		var tw2: Tween = sel_card.create_tween()
		tw2.tween_property(sel_card, "position:x", 4.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		UiKit.pop_in(sel_card, 0.92, 0.15)
	UiKit.snd("ui_select")




func _build_ores() -> void :
	ore_btn = UiKit.slot("icon_mine", true, 44.0)
	ore_btn.tooltip_text = ""
	ore_btn.set_meta("rail_rank", 2)
	ore_btn.pressed.connect( func() -> void : toggle_ores())
	HoldTip.tip(ore_btn, HoldTip.act_line("ores"))
	root.add_child(ore_btn)
	ore_badge = UiKit.lbl("0", 10, UiKit.GOLD, 3, 3)
	ore_badge.position = Vector2(4, 1)
	ore_btn.add_child(ore_badge)
	var onl: Label = UiKit.lbl("ЗАЛЕЖИ", 9, UiKit.TEXT, 3, 2)
	onl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	onl.custom_minimum_size = Vector2(44, 0)
	onl.position = Vector2(0, 32)
	onl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ore_btn.add_child(onl)
	ore_panel = PanelContainer.new()
	ore_panel.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 6, 7))
	ore_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ore_panel.visible = false
	root.add_child(ore_panel)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	ore_panel.add_child(vb)
	var hr: = HBoxContainer.new()
	vb.add_child(hr)
	var t: Label = UiKit.lbl("Свободные залежи", 11, UiKit.TITLE, 3, 3)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(t)
	var x: Button = UiKit.close_btn(30.0)
	x.pressed.connect( func() -> void : toggle_ores())
	hr.add_child(x)
	var filter: OptionButton = OptionButton.new()
	filter.name = "OreResourceFilter"
	filter.custom_minimum_size = Vector2(176, 30)
	filter.add_item(Loc.t("Все ресурсы"))
	for resource: String in ORE_FILTERS.slice(1):
		filter.add_item(Loc.t(String(Economy.RES_SHORT.get(resource, resource))))
	filter.select(maxi(0, ORE_FILTERS.find(_ore_filter)))
	filter.item_selected.connect(func(index: int) -> void:
		_ore_filter = ORE_FILTERS[clampi(index, 0, ORE_FILTERS.size() - 1)]
		_refresh_ores()
	)
	vb.add_child(filter)
	var sc: = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(176, 60)
	vb.add_child(sc)
	ore_scroll = sc
	ore_list = VBoxContainer.new()
	ore_list.add_theme_constant_override("separation", 3)
	ore_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(ore_list)



func _build_mapchip() -> void :
	map_chip = UiKit.big("", "blue", "", 30.0, 9)
	map_chip.visible = false
	map_chip.pressed.connect( func() -> void : action.emit("map_mode:0"))
	root.add_child(map_chip)
	if gw.has_signal("map_mode_changed"):
		gw.map_mode_changed.connect(_on_map_mode)
	dip_chip = UiKit.big("", "red", "", 30.0, 9)
	dip_chip.visible = false
	dip_chip.pressed.connect( func() -> void : action.emit("diplomacy"))
	root.add_child(dip_chip)
	set_key_pressed.call_deferred("own_icons", bool(gw.get("show_own_icons")))


func _on_map_mode(m: int) -> void :
	map_chip.visible = m != 0
	map_chip.text = Loc.t("КАРТА: %s   ✕") % Loc.t(String(GameWorld.MAP_MODE_NAMES[m]))
	if m != 0:
		UiKit.pop_in(map_chip, 0.9, 0.15)
	if panel_kind == "map_modes" and panel != null and is_instance_valid(panel):
		open_map_modes()




func _layout_top_stack() -> void :
	var y: float = top_col.position.y + top_col.size.y + 4.0
	var win: bool = panel != null and is_instance_valid(panel)
	if win and prompt_panel.visible:
		prompt_panel.visible = false
		_prompt_under_win = true
	elif not win and _prompt_under_win:
		_prompt_under_win = false
		if not prompt_data.is_empty():
			prompt_panel.visible = true
	var has_lane: bool = lane != null and is_instance_valid(lane)
	if has_lane:

		if dip_chip != null and dip_chip.visible:
			dip_chip.visible = false
		y = _win_top()
		if float(lane.get("dock_bottom")) < 0.0:
			y = maxf(y, float(lane.call("bottom")) + 4.0)
	elif win and toast_panel.visible:
		toast_panel.move_to_front()
		toast_panel.position = Vector2(roundf((root.size.x - toast_panel.size.x) * 0.5), roundf(holder.position.y - toast_panel.size.y - 6.0))
	for ch: Control in [map_chip, dip_chip, toast_panel, prompt_panel]:
		if ch == null or not ch.visible or (win and ch == toast_panel):
			continue
		if ch is Button:
			ch.reset_size()


		var pl: float = _ui29_pill_x(ch, y)
		if pl >= 0.0 and not _ui29_beside_ok(ch, y, pl):
			y = maxf(y, _ui29_pill_rect().end.y + 4.0)
			pl = -1.0
		var want: = Vector2(roundf((root.size.x - ch.size.x) * 0.5), roundf(y))
		want.x = _qa_clear_rail(ch, y, want.x, pl)
		if ch.position.distance_to(want) > 0.5:
			ch.position = want
		y += ch.size.y + 4.0
	_qa_stack_bottom = y
	if war_banner != null:
		war_banner.self_modulate.a = 0.0 if win else 1.0
		war_banner.offset_top = y + 2.0
		war_banner.offset_bottom = y + 34.0
		war_banner.offset_right = -58.0





func _qa_clear_rail(ch: Control, y: float, x: float, left: float = -1.0) -> float:
	var r: float = _qa_rail_r(ch, y)
	var l0: float = left if left >= 0.0 else 4.0
	if ch == prompt_panel and prompt_lbl != null:
		var other: float = ch.size.x - prompt_lbl.custom_minimum_size.x
		var lw: float = clampf(r - l0 - other, 90.0, 200.0)
		if absf(prompt_lbl.custom_minimum_size.x - lw) > 0.5:
			prompt_lbl.custom_minimum_size.x = lw
			ch.reset_size()
	if left >= 0.0:
		x = maxf(x, l0)
	if x + ch.size.x > r:
		x = maxf(l0, r - ch.size.x)
	return x



func _qa_rail_r(ch: Control, y: float) -> float:
	var r: float = root.size.x - 4.0
	if not armies_open:
		var rail: Array = []
		for e: Array in cmd_btns:
			rail.append(e[0])
		if ore_btn != null:
			rail.append(ore_btn)
		for c: Variant in rail:
			if not is_instance_valid(c):
				continue
			var b: Control = c as Control
			if b != null and b.visible:
				var br: Rect2 = b.get_global_rect()
				if br.position.y < y + ch.size.y + 4.0 and br.end.y > y - 4.0:
					r = minf(r, br.position.x - 4.0)
	return r



func _ui29_pill_rect() -> Rect2:
	if lane == null or not is_instance_valid(lane) or not lane.is_visible_in_tree():
		return Rect2()
	var pb: Variant = lane.get("_inbox_btn")
	if pb is Control and is_instance_valid(pb) and (pb as Control).visible:
		return (pb as Control).get_global_rect()
	return Rect2()



func _ui29_pill_x(ch: Control, y: float) -> float:
	var pr: Rect2 = _ui29_pill_rect()
	if pr.size.x <= 0.0 or y >= pr.end.y + 2.0 or y + ch.size.y <= pr.position.y:
		return -1.0
	return pr.end.x + 4.0




func _ui29_beside_ok(ch: Control, y: float, left: float) -> bool:
	var r: float = _qa_rail_r(ch, y)
	if ch == prompt_panel and prompt_lbl != null:
		var other: float = ch.size.x - prompt_lbl.custom_minimum_size.x
		var lw: float = r - left - other
		if lw < 110.0:
			return false
		var f: Font = prompt_lbl.get_theme_font("font")
		var fs: int = prompt_lbl.get_theme_font_size("font_size")
		var hgt: float = f.get_multiline_string_size(prompt_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, minf(lw, 200.0) - 2.0, fs).y
		return hgt <= f.get_height(fs) * 3.0 + 1.0
	return ch.size.x <= r - left



func open_map_modes() -> void :
	var vb: VBoxContainer = _window("Режимы карты", "map_modes")
	panel_kind = "map_modes"
	var cur: int = int(gw.get("map_mode"))
	for i in GameWorld.MAP_MODE_NAMES.size():
		if i == GameWorld.MapMode.ALLIANCES and not GameConfig.alliances:
			continue
		var b: = Button.new()
		b.add_theme_stylebox_override("normal", UiKit.sb("wb_slot_red" if i == cur else "wb_panel_dark", 6, 4))
		b.add_theme_stylebox_override("hover", UiKit.sb("wb_slot_red" if i == cur else "wb_panel_dark", 6, 4))
		b.add_theme_stylebox_override("pressed", UiKit.sb("wb_slot_red", 6, 4))
		b.custom_minimum_size = Vector2(0, 44)
		var mi: int = i
		b.pressed.connect( func() -> void :
			UiKit.snd("ui_click")
			action.emit("map_mode:%d" % mi))
		vb.add_child(b)
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 6
		row.offset_right = -6
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var ic: Control = UiKit.icon_rect(String(GameWorld.MAP_MODE_ICONS[i]), 30.0)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var col: = VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)
		var info: Array = GameWorld.MAP_MODE_INFO[i]
		var t: Label = UiKit.lbl(String(GameWorld.MAP_MODE_NAMES[i]), 12, UiKit.GOLD if i == cur else UiKit.TEXT, 2, 2)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(t)
		var d: Label = UiKit.lbl(String(info[1]), 9, UiKit.MUTED, 1, 1)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(d)
	var on: bool = bool(gw.get("show_own_icons"))
	var tb: Button = _small_btn(Loc.t("ЗНАЧКИ МОИХ ПОСТРОЕК: %s") % (Loc.t("ВКЛ") if on else Loc.t("ВЫКЛ")), "own_icons", true, "green" if on else "stone")
	vb.add_child(tb)



func toggle_ores() -> void :
	ores_open = not ores_open
	ore_btn.set_pressed_no_signal(ores_open)
	ore_panel.visible = ores_open
	_ore_sig = ""
	if ores_open:
		_refresh_ores()
		UiKit.pop_in(ore_panel, 0.9, 0.18)
	UiKit.snd("ui_open" if ores_open else "ui_close")


func _free_deposits() -> Array:
	var out: Array = []
	if gw == null or gw.player == null or gw.econ == null:
		return out
	var pid: int = gw.player.id
	var cap: Vector2 = Vector2(gw.cities[gw.player.capital_id].center) if gw.player.capital_id >= 0 else Vector2.ZERO
	for dp: Dictionary in gw.econ.deposits:
		var c: Vector2i = dp["cell"]
		if dp.get("mine") != null or int(dp.get("left", 0)) <= 0:
			continue
		if gw.data.get_owner_id(c.x, c.y) != pid:
			continue
		out.append([dp, Vector2(c).distance_to(cap)])
	out.sort_custom( func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	return out


func _refresh_ores() -> void :
	var list: Array = _free_deposits()
	ore_badge.text = str(list.size())
	if not ore_panel.visible:
		return
	var sig: String = _ore_filter + ";"
	for it: Array in list:
		sig += "%s:%s:%d;" % [str((it[0] as Dictionary)["cell"]), str((it[0] as Dictionary).get("res", "")), int((it[0] as Dictionary).get("left", 0))]
	if sig == _ore_sig:
		return
	_ore_sig = sig
	for ch in ore_list.get_children():
		ch.queue_free()
	var shown: Array = []
	for it: Array in list:
		if _ore_filter == "" or String((it[0] as Dictionary).get("res", "")) == _ore_filter:
			shown.append(it)
	if shown.is_empty():
		var msg: String = "Все залежи на вашей земле уже добываются. Расширяйте границы городами." if list.is_empty() else "Нет свободных залежей выбранного ресурса."
		var e: Label = UiKit.lbl(Loc.t(msg), 10, UiKit.MUTED, 1)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size = Vector2(170, 0)
		ore_list.add_child(e)
		return
	for it: Array in shown:
		var dp: Dictionary = it[0]
		var rk: String = String(dp.get("res", ""))
		var c: Vector2i = dp["cell"]
		var b: Button = UiKit.big("", "stone", "", 38.0, 10)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = UiKit.tex(_res_icon(rk))
		b.expand_icon = false
		b.text = Loc.t("%s %s · %.1f км") % [String(Economy.RES_SHORT.get(rk, rk)).to_lower().capitalize(), Economy.reserve_text(int(dp.get("left", 0))), float(it[1]) * GameWorld.CELL / 1000.0]
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect( func() -> void : action.emit("goto_dep:%d:%d" % [c.x, c.y]))
		ore_list.add_child(b)
	_fix_scroll_input.call_deferred(ore_list)



func _on_world_message(text: String) -> void :
	if gw.ui_mute:
		return
	if gw.player != null and gw.player.eliminated:
		return


	if lane != null and is_instance_valid(lane) and Time.get_ticks_msec() - UiKit._tap_ms > 800:
		lane.call("ambient", text, CalmScript.level(text))
		return
	show_toast(text, false)




func _race_fit(opts: Array) -> String:
	var sv: Control = race_lbl.get_parent() as Control
	if top_name == null or sv == null or top_name.size.x < 8.0:
		return String(opts[0])
	var rf: Font = race_lbl.get_theme_font("font")
	var ol: float = float(race_lbl.get_theme_constant("outline_size"))
	var sw: float = score_lbl.get_combined_minimum_size().x
	var cond: Array = BuildPanel.condensed()
	var nf: Font = cond[0] if not cond.is_empty() else top_name.get_theme_font("font")
	var need: float = nf.get_string_size(top_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + float(top_name.get_theme_constant("outline_size"))
	var room0: float = top_name.size.x + sv.size.x
	for o: Variant in opts:
		var t: String = String(o).to_upper()
		var w: float = maxf(sw, rf.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + ol)
		if room0 - w >= need:
			return String(o)
	return String(opts[opts.size() - 1])


func _race_refit() -> void :
	if race_lbl == null or not race_lbl.visible or not race_lbl.has_meta("opts"):
		return
	var t: String = _race_fit(race_lbl.get_meta("opts")).to_upper()
	if race_lbl.text != t:
		race_lbl.text = t



func show_toast(text: String, reply: bool = true) -> void :
	if lane != null and is_instance_valid(lane):
		lane.call("push", "msg", {"title": text, "ttl": 2.2 + clampf((text.length() - 40) * 0.03, 0.0, 2.0), "prio": 0, "reply": reply})
		return
	toast_label.text = text
	toast_label.custom_minimum_size = Vector2(minf(300.0, 30.0 + text.length() * 6.5), 0)
	toast_panel.visible = true
	toast_panel.reset_size()
	_layout_top_stack()
	UiKit.slide_in(toast_panel, Vector2(0, -12), 0.2)
	toast_until = Time.get_ticks_msec() / 1000.0 + 2.6 + clampf((text.length() - 40) * 0.04, 0.0, 3.0)



func _perf_process(delta: float) -> void :
	if not GameConfig.perf_hud:
		if perf_lbl != null:
			perf_lbl.visible = false
		return
	if perf_lbl == null:
		perf_lbl = UiKit.lbl("", 9, UiKit.GOLD, 2, 2)
		perf_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(perf_lbl)
	perf_lbl.visible = true
	perf_lbl.position = Vector2(6.0, holder.position.y - perf_lbl.size.y - 2.0)
	_perf_t -= delta
	if _perf_t > 0.0:
		return
	_perf_t = 0.5
	var mem: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	perf_lbl.text = Loc.t("FPS %d · %.1f мс · %d МБ · x%s") % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, roundi(mem), str(gw.time_scale)]



func _adv_dup(tip: String) -> bool:
	if toast_panel != null and toast_panel.visible:
		return true
	if plan_panel == null or not plan_panel.visible or plan_state == 0:
		return false
	var plan_words: PackedStringArray = plan_goal.text.to_lower().replace(",", " ").replace(".", " ").replace(":", " ").split(" ", false)
	var hits: int = 0
	for w: String in tip.to_lower().replace(",", " ").replace(".", " ").replace(":", " ").split(" ", false):
		if w.length() >= 5 and plan_words.has(w):
			hits += 1
	return hits >= 2


func set_hint(text: String) -> void :
	hint.text = text
	if lane != null and is_instance_valid(lane):
		hint_panel.visible = false
		if text == "":
			lane.call("remove_kind", "hint")
		else:
			lane.call("push", "hint", {"title": text, "ttl": 1000000000.0, "icon": "icon_hint", "prio": -1})
		return
	var on: bool = text != ""
	if on and not hint_panel.visible:
		hint_panel.visible = true
		UiKit.pop_in(hint_panel, 0.9, 0.18)
	hint_panel.visible = on


func set_key_pressed(nm: String, on: bool) -> void :
	if keys.has(nm):
		(keys[nm] as Button).set_pressed_no_signal(on)



func set_speed_dot(c: Color) -> void :
	if _speed_dot == null or not is_instance_valid(_speed_dot):
		var k: Button = keys.get("speed") as Button
		if k == null:
			return
		_speed_dot = ColorRect.new()
		_speed_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_speed_dot.custom_minimum_size = Vector2(4, 4)
		_speed_dot.size = Vector2(4, 4)
		_speed_dot.position = Vector2(38, 6)
		k.add_child(_speed_dot)
	_speed_dot.color = c
	_speed_dot.visible = c.a > 0.0


func set_speed_text(t: String) -> void :
	speed_badge.text = t if t != "II" else ""
	UiKit.set_slot_icon(keys["pause"] as Button, "icon_play" if t == "II" else "icon_pause")
	(key_labels["pause"] as Label).text = "ИГРАТЬ" if t == "II" else "ПАУЗА"


func refresh() -> void :
	var p: Country = gw.player
	if p == null:
		top_name.text = "НОВАЯ СТРАНА"
		top_flag.texture = null
	else:
		if top_name.text != Loc.name(p.name).to_upper():
			top_name.text = Loc.name(p.name).to_upper()
			UiKit.refit(top_name)
		top_flag.texture = FlagMaker.tex_for(p, top_flag.custom_minimum_size)
	res_panel.visible = p != null
	if keys.has("capital"):
		(keys["capital"] as Button).disabled = p != null and p.capital_id >= 0
	_city_keys()
	_sync_city_labels()




func _sync_city_labels() -> void :
	for id: int in city_labels.keys():
		if id >= gw.cities.size():
			for n: Node in city_labels[id]:
				n.queue_free()
			city_labels.erase(id)
	for city: City in gw.cities:
		if city_labels.has(city.id):
			continue
		var c: Country = gw.country_by_id(city.country_id)
		var cap: bool = city.kind == City.Kind.CAPITAL
		var lb: Label = UiKit.name_lbl(city.name, 11 if cap else 9, 
			UiKit.GOLD if cap else UiKit.TEXT, 2, 3)
		labels_root.add_child(lb)
		var mk: = TextureRect.new()
		var mname: String = "marker_capital" if cap else ("marker_city" if city.kind == City.Kind.TOWN else "marker_village")
		mk.texture = UiKit.tex(mname)
		mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels_root.add_child(mk)
		var fl: = TextureRect.new()
		fl.texture = FlagMaker.tex_for(c, Vector2(15, 10))
		fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fl.stretch_mode = TextureRect.STRETCH_SCALE
		fl.size = Vector2(15, 10)
		fl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels_root.add_child(fl)
		var pw: = TextureRect.new()
		pw.texture = UiKit.tex("res_power")
		pw.modulate = UiKit.RED
		pw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pw.visible = false
		labels_root.add_child(pw)
		city_labels[city.id] = [lb, mk, fl, pw]

func ui24_open(sheet: Control) -> void :
	if ui24_sheet != null and ui24_sheet != sheet and is_instance_valid(ui24_sheet) and ui24_sheet.has_method("close"):
		ui24_sheet.call("close")
	ui24_sheet = sheet



	if sheet != null and ops_panel != null and ops_panel.visible and main_node != null and main_node.has_method("drop_cards_for_sheet"):
		main_node.drop_cards_for_sheet()
	_qa_tab_follow(sheet)
	if bottom_panel != null and sheet != null:
		if root.size.x < 700:
			bottom_panel.visible = false
	if help_tips != null and sheet != null:
		help_tips.call_deferred("attach_help", sheet)



func _qa_tab_follow(sheet: Control) -> void :
	var s: Script = sheet.get_script() as Script if sheet != null else null
	var path: String = s.resource_path if s != null else ""
	var p: int = -1
	if path.ends_with("econ_hub.gd"):
		p = 1
	elif path.ends_with("dip_sheet.gd"):
		p = 5
	elif path.ends_with("cmd_sheet.gd") or path.ends_with("army_dock.gd") or path.ends_with("army_sheet.gd"):
		p = 4
	elif path.ends_with("navy_yard.gd") or path.ends_with("navy_dock.gd"):
		p = 6
	elif path.ends_with("conference_sheet.gd"):
		p = 5
	elif path.ends_with("ad_rules_sheet.gd"):
		p = 3
	if p < 0 or p == _page or p >= pages.size() or _spect:
		return
	_tab_quiet = true
	_select_page(p, false)
	_tab_quiet = false

func ui24_closed(sheet: Control) -> void :
	if ui24_sheet == sheet:
		ui24_sheet = null
	if bottom_panel != null:
		bottom_panel.visible = true

func blocked_rects() -> Array:
	_blk.clear()
	for c: Control in [plan_panel, prompt_panel, toast_panel, dip_chip, map_chip, top_col, confirm_panel, sel_card, ops_panel, armies_bar, news_panel]:
		if c != null and is_instance_valid(c) and c.is_visible_in_tree():
			_blk.append(c.get_global_rect().grow(2.0))
	if war_banner != null and war_banner.visible and war_banner.self_modulate.a > 0.0:
		_blk.append(war_banner.get_global_rect().grow(2.0))
	if ui24_open_now() and ui24_sheet.is_visible_in_tree():
		_blk.append(ui24_sheet.get_global_rect().grow(2.0))
	_blk.append_array(_econ_blocked())
	return _blk


func set_net_mode(on: bool) -> void :
	_net_on = on
	for nm: String in ["pause"]:
		var b: Control = keys.get(nm) as Control
		if b != null and is_instance_valid(b) and b.get_parent() is Control and b.get_parent() != root:
			(b.get_parent() as Control).visible = not on



func _city_keys() -> void :
	if _spect or not keys.has("capital") or not keys.has("npp"):
		return
	var p: Country = gw.player if gw != null else null
	var has_cap: bool = p != null and p.capital_id >= 0
	var cc: Control = (keys["capital"] as Control).get_parent() as Control
	var nc: Control = (keys["npp"] as Control).get_parent() as Control
	if cc.visible == has_cap or nc.visible != has_cap:
		cc.visible = not has_cap
		nc.visible = has_cap
		_fit_keys_stack.call_deferred()


func _apply_spectator(on: bool) -> void :
	_spect = on
	_city_keys.call_deferred()
	if tab_row != null:
		tab_row.visible = not on
	for nm: String in keys:
		var b: Control = keys[nm] as Control
		if b == null or not is_instance_valid(b):
			continue
		var cell: Control = b.get_parent() as Control
		if cell is VBoxContainer and cell != root:
			cell.visible = ( not on) or nm == "speed" or (nm == "pause" and not _net_on)
	for pg: Variant in pages:
		for cell2: Node in (pg as Node).get_children():
			if cell2 is Control:
				(cell2 as Control).visible = not on
	if on and war_banner != null:
		war_banner.visible = false
		war_until = 0.0


func _place_city_labels() -> void :
	if gw.get("labels") != null:
		labels_root.visible = false
		return
	var cam: MapCamera = gw.camera
	var z: float = cam.zoom.x
	var far: bool = z < 0.5
	var placed: Array[Rect2] = []
	var order: Array[City] = gw.cities.duplicate()
	order.sort_custom( func(a: City, b: City) -> bool: return a.kind < b.kind)
	for city: City in order:
		if not city_labels.has(city.id):
			continue
		var arr: Array = city_labels[city.id]
		var lb: Label = arr[0]
		var mk: TextureRect = arr[1]
		var fl: TextureRect = arr[2]
		var pw: TextureRect = arr[3]
		var sp: Vector2 = cam.world_to_screen(Vector2(city.center * GameWorld.CELL))
		if sp.x < -120.0 or sp.y < -60.0 or sp.x > root.size.x + 120.0 or sp.y > root.size.y + 60.0:
			lb.visible = false
			mk.visible = false
			fl.visible = false
			pw.visible = false
			continue
		var show_label: bool = city.kind == City.Kind.CAPITAL or (z >= 0.5 and city.kind == City.Kind.TOWN) or z >= 1.0
		lb.visible = show_label
		mk.visible = far
		fl.visible = show_label and (far or city.kind == City.Kind.CAPITAL)
		var ms: Vector2 = mk.texture.get_size()
		mk.position = (sp - ms * 0.5).round()
		var off_y: float = 8.0 if far else - float(city.radius) * GameWorld.CELL * z * 0.25 - 18.0
		if lb.size.x <= 1.0:
			lb.reset_size()
		lb.position = (sp + Vector2( - lb.size.x * 0.5 + (9.0 if fl.visible else 0.0), off_y)).round()
		fl.position = (lb.position + Vector2(-18, (lb.size.y - 10.0) * 0.5)).round()
		pw.visible = not city.powered and (lb.visible or far) and int(Time.get_ticks_msec() / 400) % 2 == 0
		pw.position = (lb.position + Vector2(lb.size.x + 3, 2)).round() if lb.visible else (sp + Vector2(6, -14)).round()
		var rect: = Rect2(lb.position - Vector2(20, 1), lb.size + Vector2(22, 2))
		if show_label:
			for pr: Rect2 in placed:
				if pr.intersects(rect):
					lb.visible = false
					if city.kind != City.Kind.CAPITAL:
						fl.visible = false
					break
			if lb.visible:
				placed.append(rect)


func city_labels_reset() -> void :


	if lane != null and is_instance_valid(lane) and lane.has_method("clear_all"):
		lane.call("clear_all")
	for id: int in city_labels.keys():
		for n: Node in city_labels[id]:
			n.queue_free()
	city_labels.clear()


func city_label_drop(id: int) -> void :
	if city_labels.has(id):
		for n: Node in city_labels[id]:
			n.queue_free()
		city_labels.erase(id)
	_sync_city_labels()



func set_keys_folded(on: bool) -> void :
	keys_collapsed = on
	if _fold_pad == null and holder != null:
		_fold_pad = Control.new()
		_fold_pad.custom_minimum_size = Vector2(0, 4.0 + _safe_margins().y)
		_fold_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fold_pad.visible = false
		holder.add_child(_fold_pad)
	if on:
		show_tip("ПАНЕЛЬ СВЁРНУТА", "Тап по вкладке — снова открыть")
	else:
		tip_pc.visible = false


func _fit_keys_stack() -> void :
	if _keys_stack != null and _page >= 0 and _page < pages.size():
		var h: float = (pages[_page] as Control).get_combined_minimum_size().y
		var tgt: float = maxf(54.0, h if root.size.x < 700 else 54.0)
		if absf(_keys_stack.custom_minimum_size.y - tgt) > 0.5:
			_keys_stack.custom_minimum_size.y = tgt



func _econ_blocked() -> Array:
	var out: Array = []
	if lane != null and is_instance_valid(lane):
		out.append_array(lane.call("blocked_rects"))
	return out
