extends Control






const U = preload("res://ui/ui24/arm_kit.gd")
const CHIP: float = 50.0
const GAP: float = 3.0

var hud: Node
var main: Node
var scrim: Control
var panel: PanelContainer
var chips: Array = []
var is_open: bool = false


func mount(h: Node) -> void :
	hud = h
	main = h.main_node
	name = "SpeedPick"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	h.root.add_child(self)
	z_index = 50


static func _label_col(spd: float) -> Color:
	if spd < 1.0:
		return Color("c9c4b8")
	if spd <= 1.0:
		return Color.WHITE
	if spd <= 2.0:
		return Color("bdf2ff")
	if spd <= 5.0:
		return Color("62e0f0")
	if spd <= 10.0:
		return Color("ffe066")
	return Color("ffb347")


static func speed_text(spd: float) -> String:
	return "x½" if spd < 1.0 else "x%d" % int(spd)


func open() -> void :
	for c: Node in get_children():
		c.queue_free()
	chips.clear()
	var ns: Variant = main.get("net")
	if ns != null and bool(ns.in_match):
		_open_net(ns)
		return
	visible = true
	is_open = true
	scrim = Control.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect( func(e: InputEvent) -> void :
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close())
	add_child(scrim)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 4, 4))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var vw: float = get_viewport_rect().size.x
	var speeds: Array = main.SPEEDS
	var order: Array = range(speeds.size())
	order.sort_custom( func(a: int, b: int) -> bool: return float(speeds[a]) < float(speeds[b]))
	var per_row: int = clampi(int(floorf((vw - 12.0 - 8.0 + GAP) / (CHIP + GAP))), 3, order.size())
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	panel.add_child(vb)

	var hd: = HBoxContainer.new()
	hd.add_theme_constant_override("separation", 6)
	vb.add_child(hd)
	var hg: = Control.new()
	hg.custom_minimum_size = Vector2(26, 40)
	hg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hg.draw.connect( func() -> void : _hourglass(hg))
	hd.add_child(hg)
	var tl: Label = UiKit.lbl("СКОРОСТЬ ВРЕМЕНИ", 12, UiKit.TITLE, 3, 4)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hd.add_child(tl)
	var x: Button = UiKit.close_btn(44.0)
	x.pressed.connect( func() -> void :
		UiKit.snd("ui_close")
		close())
	hd.add_child(x)
	var grid: = GridContainer.new()
	grid.columns = per_row
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	vb.add_child(grid)
	var cur: int = int(main.get("_speed_i"))
	var paused: bool = bool(main.get("_paused"))
	for i: int in order:
		var spd: float = float(speeds[i])
		var b: = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(CHIP, CHIP)
		UiKit._slot_styles(b, true)
		var on: bool = i == cur and not paused
		if on:
			var fr: = Control.new()
			fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fr.draw.connect( func() -> void :
				var r: = Rect2(Vector2.ZERO, fr.size).grow(-1.0)
				fr.draw_rect(r, U.DARK, false, 4.0)
				fr.draw_rect(r.grow(-1.0), UiKit.GOLD, false, 2.0))
			b.add_child(fr)
		var l: Label = UiKit.lbl(speed_text(spd), 14 if spd < 10.0 else 13, _label_col(spd), 3, 4)
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		var si: int = i
		b.pressed.connect( func() -> void : _pick(si))
		UiKit.press_fx(b)
		grid.add_child(b)
		chips.append([b, i])
	panel.ready.connect(_place, CONNECT_ONE_SHOT)
	_place.call_deferred()





func _open_net(ns: Object, animate: bool = true) -> void :
	visible = true
	is_open = true
	scrim = Control.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect( func(e: InputEvent) -> void :
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close())
	add_child(scrim)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 6, 6))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.custom_minimum_size = Vector2(_net_w(), 0)
	panel.add_child(vb)
	var auto: bool = GameConfig.mp_speed == 1
	var spd: int = int(ns.speed)
	var why: String = String(ns.speed_why)

	var hd: = HBoxContainer.new()
	hd.add_theme_constant_override("separation", 6)
	vb.add_child(hd)
	var hg: = Control.new()
	hg.custom_minimum_size = Vector2(26, 40)
	hg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hg.draw.connect( func() -> void : _hourglass(hg))
	hd.add_child(hg)
	var off: bool = GameConfig.mp_speed == 2
	var tl: Label = UiKit.lbl(Loc.t("СКОРОСТЬ · ВЫКЛ") if off else (Loc.t("СКОРОСТЬ · АВТО") if auto else Loc.t("СКОРОСТЬ · ПО СОГЛАСИЮ")), 12, UiKit.TITLE, 3, 4)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hd.add_child(tl)
	var cur: Label = UiKit.lbl("x%d" % spd, 14, _label_col(float(spd)), 3, 4)
	cur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hd.add_child(cur)
	var x: Button = UiKit.close_btn(44.0)
	x.pressed.connect( func() -> void :
		UiKit.snd("ui_close")
		close())
	hd.add_child(x)
	var lag_txt: String = Loc.t("ВАШЕ УСТРОЙСТВО НЕ УСПЕВАЕТ") if String(ns.speed_who) == NetConfig.nick() else Loc.t("НЕ УСПЕВАЕТ %s") % String(ns.speed_who).to_upper()
	if off:
		MpKit.status_bar(vb, "УСКОРЕНИЕ ВЫКЛЮЧЕНО ХОСТОМ", "info", "net_wait", false, false)
		_note(vb, "МЕНЯЕТСЯ ТОЛЬКО ПРИ СОЗДАНИИ ПАРТИИ", UiKit.MUTED)
	elif auto:
		if why == "lag":
			MpKit.status_bar(vb, lag_txt, "alarm", "net_signal_weak", false, false)
		elif why == "start":
			MpKit.status_bar(vb, "x1, ПОКА НЕ У ВСЕХ ЕСТЬ СТОЛИЦА", "info", "net_wait", false, false)
		elif why.begins_with("auto:") and why.length() > 5:
			var who: String = String(ns.speed_who)
			MpKit.status_bar(vb, "x1: %s%s" % [why.substr(5), (Loc.t(" У %s") % who.to_upper()) if who != "" else ""], "wait", "net_pause", false, false)
		elif spd > 1:
			MpKit.status_bar(vb, "ТИХО — УСКОРЯЕМСЯ", "ok", "net_sync", true, false)
		else:
			MpKit.status_bar(vb, "ТИХО — СКОРО x2", "ok", "net_sync", true, false)
		_note(vb, "ВАШ ЛИМИТ СКОРОСТИ", UiKit.MUTED)
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", int(GAP) + 3)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_child(row)
		for s2: int in NetConfig.MP_SPEEDS:
			var b: Button = _chip(s2, CHIP, s2 == int(ns.my_want), s2 == spd)
			var w: int = s2
			b.pressed.connect( func() -> void :
				UiKit.snd("ui_select")
				ns.set_want(w)
				if w > int(ns.speed) and main.has_method("net_toast"):
					main.net_toast("ЛИМИТ x%d · ИДЁТ x%d%s" % [w, int(ns.speed), (" (%s)" % String(ns.speed_who).to_upper()) if String(ns.speed_who) != "" else ""])
				close())
			row.add_child(b)
		_note(vb, "x2 ЧЕРЕЗ 20 С ТИШИНЫ, x3 ЧЕРЕЗ 60 С", UiKit.MUTED)
		_note(vb, "СОБЫТИЕ У ЛЮБОГО ИГРОКА — СРАЗУ x1", UiKit.MUTED)
	else:
		_note(vb, "ВАШ ВЫБОР", UiKit.MUTED)
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", int(GAP) + 3)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_child(row)
		for s2: int in NetConfig.MP_SPEEDS:
			var b: Button = _chip(s2, CHIP, s2 == int(ns.my_want), s2 == spd)
			var w: int = s2
			b.pressed.connect( func() -> void :
				UiKit.snd("ui_select")
				ns.set_want(w)
				if w > int(ns.speed) and main.has_method("net_toast"):
					main.net_toast("ВЫ ЗА x%d · ИДЁТ x%d%s" % [w, int(ns.speed), (" (%s)" % String(ns.speed_who).to_upper()) if String(ns.speed_who) != "" else ""])
				close())
			row.add_child(b)
		var ws: Array = ns.wants
		for i in (ns.slots as Array).size():
			if not ns._live(i):
				continue
			var w2: int = int(ws[i]) if i < ws.size() else 1
			_player_row(vb, i, String((ns.slots[i] as Dictionary).get("name", "?")), i == int(ns.local_slot), w2, why == "want" and w2 == spd)
		if why == "lag":
			MpKit.status_bar(vb, Loc.t("ЗАМЕДЛЕНО: %s") % [lag_txt], "alarm", "net_signal_weak", false, false)
		elif why == "start":
			_note(vb, "x1, ПОКА НЕ У ВСЕХ ЕСТЬ СТОЛИЦА", UiKit.MUTED)
	if animate:
		panel.ready.connect(_place, CONNECT_ONE_SHOT)
		_place.call_deferred()
	else:
		_place_still.call_deferred()



func refresh_net() -> void :
	var ns: Variant = main.get("net")
	if not is_open or ns == null or not bool(ns.in_match):
		return
	for c: Node in get_children():
		c.queue_free()
	chips.clear()
	_open_net(ns, false)


func _place_still() -> void :
	if panel == null or not is_instance_valid(panel):
		return
	panel.reset_size()
	var vp: Vector2 = get_viewport_rect().size
	var k: Control = hud.keys.get("speed") as Control
	var kr: Rect2 = k.get_global_rect() if k != null and k.is_visible_in_tree() else Rect2(Vector2(8, vp.y - 160), Vector2(46, 46))
	var top_y: float = kr.position.y
	var tr: Control = hud.get("tab_row") as Control
	if tr != null and tr.is_visible_in_tree():
		top_y = minf(top_y, tr.get_global_rect().position.y)
	panel.position = Vector2(clampf(kr.position.x - 4.0, 6.0, vp.x - panel.size.x - 6.0), top_y - panel.size.y - 6.0).round()


func _net_w() -> float:
	return minf(380.0, get_viewport_rect().size.x - 24.0)



func _chip(spd: int, px: float, framed: bool, runs: bool) -> Button:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	UiKit._slot_styles(b, true)
	if px < CHIP:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fr: = Control.new()
	fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fr.draw.connect( func() -> void :
		var r: = Rect2(Vector2.ZERO, fr.size).grow(-1.0)
		if framed:
			fr.draw_rect(r, U.DARK, false, 4.0)
			fr.draw_rect(r.grow(-1.0), UiKit.GOLD, false, 2.0)
		if runs:
			fr.draw_rect(Rect2(Vector2(6.0, fr.size.y - 6.0), Vector2(fr.size.x - 12.0, 3.0)), UiKit.GOLD))
	b.add_child(fr)
	var l: Label = UiKit.lbl("x%d" % spd, 14 if px >= CHIP else 11, _label_col(float(spd)), 3, 4)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	if px >= CHIP:
		UiKit.press_fx(b)
	return b



func _player_row(vb: VBoxContainer, i: int, nick: String, me: bool, w: int, holds: bool) -> void :
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(0, 24)
	vb.add_child(row)
	var ic: String = "net_you" if me else ("net_host" if i == 0 else "")
	if ic != "":
		row.add_child(MpKit.icon(ic))
	else:
		var sp: = Control.new()
		sp.custom_minimum_size = Vector2(16, 16)
		row.add_child(sp)
	var nl: Label = UiKit.lbl(Loc.t("ВЫ") if me else nick.to_upper(), 11, UiKit.GOLD if holds else UiKit.TEXT, 2, 2)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(nl)
	var wl: Label = UiKit.lbl("x%d" % w, 12, _label_col(float(w)), 3, 2)
	wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(wl)
	if holds:
		var tag: = PanelContainer.new()
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.add_theme_stylebox_override("panel", MpKit._flat(UiKit.GOLD, Color(), 0, 3))
		var tg: Label = UiKit.lbl("ДЕРЖИТ", 10, UiKit.OUTLINE, 3, 0)
		tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tg.custom_minimum_size = Vector2(58, 18)
		tag.add_child(tg)
		row.add_child(tag)


func _note(vb: VBoxContainer, t: String, col: Color) -> void :
	var l: Label = UiKit.lbl(t, 10, col, 2, 2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(l)


func _place() -> void :
	if panel == null or not is_instance_valid(panel):
		return
	panel.reset_size()
	var vp: Vector2 = get_viewport_rect().size
	var k: Control = hud.keys.get("speed") as Control
	var kr: Rect2 = k.get_global_rect() if k != null and k.is_visible_in_tree() else Rect2(Vector2(8, vp.y - 160), Vector2(46, 46))
	var top_y: float = kr.position.y
	var tr: Control = hud.get("tab_row") as Control
	if tr != null and tr.is_visible_in_tree():
		top_y = minf(top_y, tr.get_global_rect().position.y)
	var p: = Vector2(clampf(kr.position.x - 4.0, 6.0, vp.x - panel.size.x - 6.0), top_y - panel.size.y - 6.0)
	panel.position = p.round()
	UiKit.pop_in(panel, 0.9, 0.16)


func _pick(i: int) -> void :
	UiKit.snd("ui_select")
	if main.has_method("set_speed_i"):
		main.set_speed_i(i)
	close()


func close() -> void :
	if not is_open:
		return
	is_open = false
	visible = false
	for c: Node in get_children():
		c.queue_free()
	chips.clear()


func _unhandled_key_input(e: InputEvent) -> void :
	if is_open and e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()



func _hourglass(c: Control) -> void :
	var s: float = 2.0
	var o: Vector2 = (c.size * 0.5 - Vector2(6, 9) * s).round()
	var wood: = Color("8a5a2b")
	var wood_l: = Color("c08a4a")
	var glass: = Color("e8f4f8")
	var sand: = Color("f0b84a")
	var dk: Color = U.DARK
	var px: = func(x: float, y: float, w: float, h: float, col: Color) -> void :
		c.draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(w, h) * s), col)
	px.call(0, 0, 12, 3, dk)
	px.call(1, 1, 10, 1, wood_l)
	px.call(0, 15, 12, 3, dk)
	px.call(1, 16, 10, 1, wood_l)
	px.call(1, 2, 10, 1, wood)
	px.call(1, 15, 10, 1, wood)

	var widths: Array = [8, 8, 6, 4, 2, 2, 4, 6, 8, 8, 8, 8]
	for r in 12:
		var w: float = float(widths[r])
		var y: float = 3.0 + float(r)
		var x0: float = 6.0 - w * 0.5
		px.call(x0 - 1.0, y, w + 2.0, 1, dk)
		px.call(x0, y, w, 1, glass)
		if (r >= 2 and r <= 4) or r >= 8:
			px.call(x0 + (1.0 if r < 8 else 0.0), y, maxf(0.0, w - (2.0 if r < 8 else 0.0)), 1, sand)
	px.call(5.5, 8, 1, 4, sand)
