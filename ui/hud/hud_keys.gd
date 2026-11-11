extends "res://ui/hud/hud_army.gd"




func open_command() -> void :
	if cmd_sheet != null and is_instance_valid(cmd_sheet):
		cmd_sheet.open_or_refresh()
		return
	_open_command_old()




func _open_command_old() -> void :
	var vb: VBoxContainer = _window("Командный центр", "command")
	panel_kind = "command"
	_cc_dirty = false
	_cc_cd.clear()
	var p: Country = gw.player
	if p == null or gw.get("ops") == null or not gw.ops.has_method("command_summary"):
		return
	var sm: Dictionary = gw.ops.command_summary(p.id)
	_cc_sig = _cc_signature(sm)
	var wars: Array = sm.get("at_war", [])
	vb.add_child(UiKit.lbl(Loc.t("ВОЙНА: %s") % ", ".join(PackedStringArray(wars)) if not wars.is_empty() else Loc.t("Войны нет"), 10, UiKit.RED if not wars.is_empty() else UiKit.MUTED, 2))
	if gw.ops.has_method("strength") and not wars.is_empty():
		var sg: Dictionary = gw.ops.strength(p.id, -1)
		var cells: int = clampi(roundi(float(sg.get("ratio", 0.5)) * 8.0), 0, 8)
		var good: bool = float(sg.get("ratio", 0.5)) >= 0.5
		var srow: = HBoxContainer.new()
		srow.add_theme_constant_override("separation", 3)
		vb.add_child(srow)
		srow.add_child(UiKit.lbl("НАШИ", 10, UiKit.GREEN, 2, 2))
		for ci in 8:
			var cr: = ColorRect.new()
			cr.custom_minimum_size = Vector2(12, 10)
			cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cr.color = UiKit.GREEN if ci < cells else UiKit.RED
			srow.add_child(cr)
		srow.add_child(UiKit.lbl("ВРАГ", 10, UiKit.RED, 2, 2))
		vb.add_child(UiKit.lbl("%s%s" % [String(sg.get("label", "")), Loc.t(" · на фронте") if bool(sg.get("front", false)) else Loc.t(" · всего")], 10, UiKit.GREEN if good else UiKit.RED, 2, 2))

	for th: Dictionary in sm.get("threats", []).slice(0, 4):
		var tr: HBoxContainer = _rowbox(vb)
		var tl: Label = UiKit.lbl("⚠ " + String(th.get("text", "")), 10, UiKit.RED, 2)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tr.add_child(tl)
		var tp: Vector2 = th.get("pos", Vector2.ZERO)
		tr.add_child(_small_btn("К МЕСТУ", "cc_pos:%d:%d" % [int(tp.x), int(tp.y)], true, "stone"))

	vb.add_child(UiKit.lbl("АРМИИ", 11, UiKit.TITLE, 2, 2))
	var armies: Array = sm.get("armies", [])
	if armies.is_empty():
		vb.add_child(UiKit.lbl("Нет казарм: постройте во вкладке «Армия».", 10, UiKit.MUTED, 1))
	for a: Dictionary in armies:
		var pc: = PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 6, 4))
		vb.add_child(pc)
		var col: = VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		pc.add_child(col)
		var hr: = HBoxContainer.new()
		hr.add_theme_constant_override("separation", 6)
		col.add_child(hr)
		var op: Dictionary = a.get("op", {})
		var head: String = "%s %s · %d/%d · %d%%" % [Loc.no(int(a["no"])) if int(a["no"]) > 0 else Loc.t("Новая"), String(a["name"]), int(a["n"]), int(a["cap"]), roundi(float(a["hp_frac"]) * 100.0)]
		var hl: Label = UiKit.lbl(head, 10, UiKit.TEXT, 2, 2)
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hr.add_child(hl)
		hr.add_child(_small_btn("К АРМИИ", "cc_go:%d" % int(a["fid"]), true, "blue"))
		var doing: String = ("%s: %s" % [String(op.get("name", "")), String(op.get("state_text", ""))]) if not op.is_empty() else String(a.get("doing", ""))
		if doing != "":
			var dl: Label = UiKit.lbl(doing, 9, UiKit.GOLD, 1)
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(dl)
		var sr: = HBoxContainer.new()
		sr.add_theme_constant_override("separation", 4)
		col.add_child(sr)
		for si in 3:
			var on: bool = int(a["stance"]) == si
			var sb: Button = _small_btn(String(Operations.AutoCmd.STANCE_NAMES[si]), "cc_st:%d:%d" % [int(a["fid"]), si], true, ("green" if si == 1 else ("red" if si == 2 else "blue")) if on else "stone")
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sb.add_theme_font_size_override("font_size", 10)
			sr.add_child(sb)
	if armies.size() > 1:
		var ar: = HBoxContainer.new()
		ar.add_theme_constant_override("separation", 4)
		vb.add_child(ar)
		ar.add_child(UiKit.lbl("ВСЕ:", 10, UiKit.TITLE, 2))
		for si2 in 3:
			var b2: Button = _small_btn(String(Operations.AutoCmd.STANCE_NAMES[si2]), "cc_all:%d" % si2, true, "stone")
			b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b2.add_theme_font_size_override("font_size", 10)
			ar.add_child(b2)

	vb.add_child(UiKit.lbl("ПРИКАЗЫ КОМАНДИРА", 11, UiKit.TITLE, 2, 2))
	var orow: = HBoxContainer.new()
	orow.add_theme_constant_override("separation", 6)
	vb.add_child(orow)
	for o: Dictionary in sm.get("orders", []):
		var oc: = VBoxContainer.new()
		oc.add_theme_constant_override("separation", 0)
		oc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		orow.add_child(oc)
		var ob: Button = _small_btn(String(o.get("name", "")), "order_%d" % int(o["kind"]), true, "red")
		ob.add_theme_font_size_override("font_size", 10)
		oc.add_child(ob)
		var cl: Label = UiKit.lbl("", 9, UiKit.GOLD, 1)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		oc.add_child(cl)
		_cc_cd.append([cl, int(o["kind"])])
	var ao: bool = bool(sm.get("auto_orders", false))
	vb.add_child(_small_btn(Loc.t("АВТО-ПРИКАЗЫ: %s") % (Loc.t("ВКЛ") if ao else Loc.t("ВЫКЛ")), "cc_auto_orders", true, "green" if ao else "stone"))

	vb.add_child(UiKit.lbl("РАКЕТНЫЕ ВОЙСКА", 11, UiKit.TITLE, 2, 2))
	var mrow: = HFlowContainer.new()
	mrow.add_theme_constant_override("h_separation", 8)
	vb.add_child(mrow)
	for mm: Dictionary in sm.get("missiles", []):
		if int(mm.get("stock", 0)) <= 0 and int(mm.get("ready", 0)) <= 0:
			continue
		var mh: = HBoxContainer.new()
		mh.add_child(UiKit.icon_rect(String(mm.get("icon", "icon_m_ballistic")), 16.0))
		mh.add_child(UiKit.lbl(Loc.t("%s %d (готово %d)") % [Loc.t(String(mm.get("name", ""))), int(mm.get("stock", 0)), int(mm.get("ready", 0))], 9, UiKit.TEXT, 1))
		mrow.add_child(mh)
	var ast: int = int(sm.get("auto_strike", 0))
	vb.add_child(_small_btn(Loc.t("АВТОУДАРЫ: %s") % Loc.t(String(Operations.AutoCmd.STRIKE_NAMES[ast])), "cc_auto_strike", true, "red" if ast > 0 else "stone"))
	var hint: Label = UiKit.lbl("Автоудары бьют только по разведанным целям врага (метки в тумане войны), 1 ракета каждого типа остаётся в запасе.", 9, UiKit.MUTED, 1)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hint)

	var bl: Array = sm.get("bombers", [])
	if not bl.is_empty():
		vb.add_child(UiKit.lbl("БОМБАРДИРОВЩИКИ И ШТУРМОВИКИ", 11, UiKit.TITLE, 2, 2))
		for bb: Dictionary in bl:
			var atk: bool = int(bb.get("type", -1)) == Aircraft.Type.ATTACK
			vb.add_child(UiKit.lbl((Loc.t("Штурмовик №%d · %s · КАБ %d") if atk else Loc.t("№%d · %s · КР %d")) % [int(bb.get("id", 0)), String(bb.get("state_name", "")), int(bb.get("kab_left" if atk else "cr_left", 0))], 9, UiKit.TEXT, 1))
	var ak: bool = bool(sm.get("auto_kab", false))
	vb.add_child(_small_btn(Loc.t("АВТО-КАБ: %s") % (Loc.t("ВКЛ") if ak else Loc.t("ВЫКЛ")), "cc_auto_kab", true, "green" if ak else "stone"))

	var dr: Dictionary = sm.get("drones", {})
	vb.add_child(UiKit.lbl(Loc.t("ДРОНЫ: на складе %d · реактивных %d · в воздухе %d") % [int(dr.get("stock", 0)), int(dr.get("jets", 0)), int(dr.get("in_air", 0))], 10, UiKit.TEXT, 2))
	var ad: bool = bool(sm.get("auto_drones", false))
	vb.add_child(_small_btn(Loc.t("АВТО-ДРОНЫ: %s") % (Loc.t("ВКЛ") if ad else Loc.t("ВЫКЛ")), "cc_auto_drones", true, "green" if ad else "stone"))
	if gw.mil.has_method("smart_of"):
		var sm_on: bool = gw.mil.smart_of(gw.player.id)
		vb.add_child(_small_btn(Loc.t("УМНЫЕ БПЛА: %s") % (Loc.t("ВКЛ") if sm_on else Loc.t("ВЫКЛ")), "cc_smart", true, "green" if sm_on else "stone"))
		var sl: Label = UiKit.lbl("Умные БПЛА облетают места, где дронов сбивали зенитки, мобильные группы и перехватчики, и повторяют удачный маршрут. От ЗРК не уклоняются.", 9, UiKit.MUTED, 1)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(sl)
	_cc_tick_labels()


func _cc_signature(sm: Dictionary) -> String:
	var sig: String = "%s|%s|%s|%s|%d|" % [str(sm.get("at_war", [])), sm.get("auto_orders", false), sm.get("auto_strike", 0), sm.get("auto_drones", false), (sm.get("threats", []) as Array).size()]
	for a: Dictionary in sm.get("armies", []):
		var op: Dictionary = a.get("op", {})
		sig += "%d:%d:%d:%d:%s;" % [int(a["fid"]), int(a["n"]), int(a["stance"]), roundi(float(a["hp_frac"]) * 10.0), String(op.get("state_text", ""))]
	for mm: Dictionary in sm.get("missiles", []):
		sig += "%d/%d," % [int(mm.get("stock", 0)), int(mm.get("ready", 0))]
	var dr: Dictionary = sm.get("drones", {})
	for bb: Dictionary in sm.get("bombers", []):
		sig += "%d:%s:%d," % [int(bb.get("id", 0)), String(bb.get("state_name", "")), int(bb.get("kab_left", 0))]
	return sig + str(dr) + str(sm.get("auto_kab", false))


func _cc_tick_labels() -> void :
	if gw.player == null:
		return
	for e: Array in _cc_cd:
		if is_instance_valid(e[0]):
			var left: float = gw.ops.cooldown_left(gw.player.id, int(e[1]))
			(e[0] as Label).text = (Loc.t("ещё %d с") % ceili(left)) if left > 0.0 else Loc.t("готов")


func _cc_process(delta: float) -> void :
	if panel_kind != "command" or panel == null or not is_instance_valid(panel) or gw.player == null:
		return
	_cc_rebuild_t -= delta
	if _cc_dirty and _cc_rebuild_t <= 0.0 and not _finger_down():
		_cc_rebuild_t = 1.5
		_open_command_old()
		return
	_cc_t -= delta
	if _cc_t > 0.0:
		return
	_cc_t = 1.0
	_cc_tick_labels()
	var sm: Dictionary = gw.ops.command_summary(gw.player.id)
	if _cc_signature(sm) != _cc_sig:
		_cc_dirty = true





func _build_rail_more() -> void :
	var mk: Button = UiKit.slot("icon_menu", false, 44.0)
	mk.visible = false
	mk.set_meta("rail_rank", 10)
	mk.pressed.connect( func() -> void :
		var now: int = Time.get_ticks_msec()
		rail_more_ms = 0 if now < rail_more_ms else now + 8000)
	root.add_child(mk)
	var bl: Label = UiKit.lbl("", 10, UiKit.GOLD, 3, 3)
	bl.position = Vector2(4, 1)
	mk.add_child(bl)
	var nl: Label = UiKit.lbl("ЕЩЁ", 9, UiKit.TEXT, 3, 2)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.custom_minimum_size = Vector2(44, 0)
	nl.position = Vector2(0, 32)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mk.add_child(nl)
	for e: Array in cmd_btns:
		(e[0] as Button).pressed.connect( func() -> void : rail_more_ms = 0)
	cmd_btns.append([mk, bl, "rail_more"])




func _build_jet_fly() -> void :
	jet_fly = PanelContainer.new()
	jet_fly.name = "JetFly"
	jet_fly.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 4, 3))
	jet_fly.mouse_filter = Control.MOUSE_FILTER_STOP
	jet_fly.visible = false
	root.add_child(jet_fly)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	jet_fly.add_child(hb)
	for it: Array in [["jet_kab", "icon_m_kab", "КАБ"], ["jet_cas", "icon_attack_jet", "НАР"]]:
		var key: String = String(it[0])
		var b: Button = UiKit.slot(String(it[1]), true, 48.0)
		b.pressed.connect( func() -> void :
			_jet_fly_close()
			action.emit(key))
		hb.add_child(b)
		var nl: Label = UiKit.lbl(String(it[2]), 9, UiKit.TEXT, 3, 2)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.custom_minimum_size = Vector2(48, 0)
		nl.position = Vector2(0, 36)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nl)
		if key == "jet_kab":
			_jet_stock_lbl = UiKit.lbl("", 10, UiKit.GOLD, 3, 3)
			_jet_stock_lbl.position = Vector2(4, 1)
			b.add_child(_jet_stock_lbl)
		keys[key] = b
		HoldTip.tip(b, HoldTip.act_line(key))


func _jet_fly_toggle() -> void :
	var jk: Button = keys.get("jet_menu") as Button
	var jm: String = _jet_mode_key()
	if jm != "":
		_jet_fly_close()
		action.emit(jm)
		return
	if jet_fly.visible:
		_jet_fly_close()
		return
	if _jet_stock_lbl != null and main_node != null and main_node.has_method("_kab_stock"):
		_jet_stock_lbl.text = str(int(main_node.call("_kab_stock")))
	jet_fly.visible = true
	jet_fly.reset_size()
	_jet_fly_ms = Time.get_ticks_msec() + 6000
	if jk != null:
		jk.set_pressed_no_signal(true)



func _jet_mode_key() -> String:
	for k: String in ["jet_kab", "jet_cas"]:
		var b: Button = keys.get(k) as Button
		if b != null and b.button_pressed:
			return k
	return ""


func _jet_fly_close() -> void :
	if jet_fly != null and jet_fly.visible:
		jet_fly.visible = false


func _jet_fly_process() -> void :
	var jk: Button = keys.get("jet_menu") as Button
	if jet_fly == null or jk == null:
		return
	var jet_mode: bool = _jet_mode_key() != ""
	if jet_fly.visible:
		if _jet_stock_lbl != null and main_node != null and main_node.has_method("_kab_stock"):
			var st: String = str(int(main_node.call("_kab_stock")))
			if _jet_stock_lbl.text != st:
				_jet_stock_lbl.text = st
		var gone: bool = not jk.is_visible_in_tree() or rail_hidden or Time.get_ticks_msec() > _jet_fly_ms
		if not gone and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var mp: Vector2 = root.get_global_mouse_position()
			gone = not jet_fly.get_global_rect().grow(4.0).has_point(mp) and not jk.get_global_rect().grow(4.0).has_point(mp)
		if gone:
			_jet_fly_close()
		else:
			var tab_row: bool = rail_tab != null and rail_tab.visible and absf(rail_tab.position.y + 4.0 - jk.position.y) < 30.0
			var want: = Vector2(jk.position.x - 8.0 - jet_fly.size.x - (18.0 if tab_row else 0.0), jk.position.y + (jk.size.y - jet_fly.size.y) * 0.5)
			want = want.round()
			if jet_fly.position.distance_squared_to(want) > 0.25:
				jet_fly.position = want
	var on: bool = jet_fly.visible or jet_mode
	if jk.button_pressed != on:
		jk.set_pressed_no_signal(on)




func _build_rail_tab() -> void :
	rail_tab = Button.new()
	rail_tab.name = "RailTab"
	rail_tab.flat = true
	rail_tab.focus_mode = Control.FOCUS_NONE
	rail_tab.custom_minimum_size = Vector2(56, 44)
	rail_tab.size = Vector2(56, 44)
	rail_tab.visible = false
	for st: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		rail_tab.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	rail_tab.draw.connect(_rail_tab_draw)
	rail_tab.button_down.connect(rail_tab.queue_redraw)
	rail_tab.button_up.connect(rail_tab.queue_redraw)
	rail_tab.pressed.connect( func() -> void : set_rail_hidden( not rail_hidden))
	UiKit.tap_snd(rail_tab)
	root.add_child(rail_tab)
	rail_hidden = _rail_pref_load()
	_rail_slide = 1.0 if rail_hidden else 0.0
	rail_dx = RAIL_SLIDE_PX * _rail_slide


func set_rail_hidden(on: bool) -> void :
	rail_hidden = on
	_jet_fly_close()
	if ores_open and on:
		toggle_ores()
	_rail_pref_save(on)


static func _rail_hint_seen() -> bool:
	var cf: = ConfigFile.new()
	if cf.load(Save.prefs_path) == OK and bool(cf.get_value("prefs", "rail_hint", false)):
		return true
	if cf.load(Save.prefs_path) != OK:
		cf = ConfigFile.new()
	cf.set_value("prefs", "rail_hint", true)
	cf.save(Save.prefs_path)
	return false


static func _rail_pref_load() -> bool:
	var cf: = ConfigFile.new()
	if cf.load(Save.prefs_path) != OK:
		return false
	return bool(cf.get_value("prefs", "rail_hidden", false))


static func _rail_pref_save(on: bool) -> void :
	var cf: = ConfigFile.new()
	if cf.load(Save.prefs_path) != OK:
		cf = ConfigFile.new()
	cf.set_value("prefs", "rail_hidden", on)
	cf.save(Save.prefs_path)


func _rail_tab_process(delta: float) -> void :
	if rail_tab == null:
		return
	var hide_now: bool = rail_hidden and not _tut_on()
	var tgt: float = 1.0 if hide_now else 0.0
	if _rail_slide != tgt:
		_rail_slide = move_toward(_rail_slide, tgt, delta / 0.18)
		var e: float = _rail_slide * _rail_slide * (3.0 - 2.0 * _rail_slide)
		rail_dx = roundf(RAIL_SLIDE_PX * e)
		if _rail_docked() and army_dock.has_method("_restack_cmd"):
			army_dock.call("_restack_cmd")

	var lx: float = INF
	var by: float = - INF
	var any: bool = false
	var keys_r: Array = []
	for e2: Array in cmd_btns:
		keys_r.append(e2[0])
	if ore_btn != null:
		keys_r.append(ore_btn)
	for c: Variant in keys_r:
		var b: Control = c as Control
		if b != null and b.visible:
			any = true
			if b.position.x > lx - 8.0 or lx == INF:
				lx = b.position.x if lx == INF else maxf(lx, b.position.x)
			by = maxf(by, b.position.y + b.size.y)
	var show: bool = any and not _spect
	if rail_tab.visible != show:
		rail_tab.visible = show
		if show and not hide_now and not _tut_on() and not _rail_hint_seen():
			show_toast("Колонку команд справа можно свернуть кнопкой под ней")
	if not show:
		return

	var x: float = minf(lx - 6.0, root.size.x - rail_tab.size.x)
	var want: = Vector2(roundf(x), roundf(by + 4.0))
	if rail_tab.position.distance_squared_to(want) > 0.25:
		rail_tab.position = want
	var parked: bool = lx >= root.size.x - 20.0
	if bool(rail_tab.get_meta("parked", false)) != parked or bool(rail_tab.get_meta("hid", false)) != hide_now:
		rail_tab.set_meta("parked", parked)
		rail_tab.set_meta("hid", hide_now)
		rail_tab.queue_redraw()





func _rail_tab_draw() -> void :
	var parked: bool = bool(rail_tab.get_meta("parked", false))
	var hid: bool = bool(rail_tab.get_meta("hid", false))
	var down: bool = rail_tab.is_pressed()
	var r: Rect2
	if parked:
		r = Rect2(Vector2(rail_tab.size.x - 22.0, 2.0), Vector2(30.0, 40.0))
	else:
		r = Rect2(Vector2(roundf((rail_tab.size.x - 34.0) * 0.5), 3.0), Vector2(34.0, 20.0))
	if down:
		r.position.y += 1.0
	rail_tab.draw_style_box(UiKit.sb("wb_slot_pressed" if down else "wb_slot"), r)
	_rail_tab_chevron(rail_tab, Vector2(r.position.x + (11.0 if parked else 17.0), r.position.y + r.size.y * 0.5), not hid, parked)



static func _rail_tab_chevron(ci: CanvasItem, c: Vector2, right: bool, tall: bool) -> void :
	var col: = Color(UiKit.MUTED, 0.95 if tall else 0.8)
	var sh: = Color(UiKit.OUTLINE, 0.85)
	var n: int = 4 if tall else 3
	var x0: float = roundf(c.x - float(n + 1) * 0.5)
	var y0: float = roundf(c.y)
	for pass_i in 2:
		var d: float = 1.0 if pass_i == 0 else 0.0
		for i in n:
			var x: float = x0 + (float(i) if right else float(n - 1 - i)) + d
			var k: float = float(n - 1 - i)
			ci.draw_rect(Rect2(Vector2(x, y0 - 2.0 - k + d), Vector2(2, 2)), sh if pass_i == 0 else col)
			ci.draw_rect(Rect2(Vector2(x, y0 + k + d), Vector2(2, 2)), sh if pass_i == 0 else col)



func _rail_docked() -> bool:
	return army_dock != null and is_instance_valid(army_dock) and army_dock.visible and bool(army_dock.is_open)






func _rail_ry() -> float:
	var ry: float = clampf(root.size.y * 0.4, 150.0, maxf(150.0, holder.position.y - 60.0))
	return ry


func _rail_put(b: Control, pos: Vector2) -> void :
	pos.x += rail_dx
	if b.position.distance_squared_to(pos) > 0.25:
		b.position = pos






func _rail_layout() -> void :
	if _rail_docked() or root == null:
		return
	var want: Array = []
	var more_b: Button = null
	var more_l: Label = null
	for e: Array in cmd_btns:
		var k: String = String(e[2])
		if k == "rail_more":
			more_b = e[0]
			more_l = e[1]
			continue
		if bool(rail_cand.get(k, false)):
			(e[0] as Control).set_meta("rail_key", k)
			want.append(e[0])
	if ore_btn != null and bool(rail_cand.get("ore", false)):
		ore_btn.set_meta("rail_key", "ore")
		want.append(ore_btn)
	if want.is_empty():
		return
	want.sort_custom( func(a: Control, b: Control) -> bool: return int(a.get_meta("rail_rank", 9)) < int(b.get_meta("rail_rank", 9)))
	var top_lim: float = maxf(_win_top(), top_col.position.y + top_col.size.y) + 6.0
	var bot: float = holder.position.y - 4.0 - 46.0
	var cap: int = maxi(2, floori((bot - top_lim + 6.0) / 50.0))
	var fold: Dictionary = {}
	if want.size() > cap:
		var drop: int = want.size() - (cap - 1)
		for k2: String in ["repair_all", "ore", "order_2", "battle_cam", "order_1", "command", "jet_menu", "order_0"]:
			if drop <= 0:
				break
			for c: Variant in want:
				if String((c as Control).get_meta("rail_key", "")) == k2:
					fold[k2] = true
					drop -= 1
					break
	if rail_fold != fold:
		rail_fold = fold
	rail_more_on = not fold.is_empty()
	var open_all: bool = Time.get_ticks_msec() < rail_more_ms or (ores_open and fold.has("ore"))
	var col: Array = []
	var side: Array = []
	for c2: Variant in want:
		var b: Control = c2 as Control
		var folded: bool = fold.has(String(b.get_meta("rail_key", "")))
		var vis: bool = not folded or open_all
		if b.visible != vis:
			b.visible = vis
		if folded:
			side.append(b)
		else:
			col.append(b)
	if rail_more_on and more_b != null:
		col.append(more_b)
		if not more_b.visible:
			more_b.visible = true
		var mt: String = "" if open_all else str(fold.size())
		if more_l != null and more_l.text != mt:
			more_l.text = mt
	var top: float = _rail_ry() - 100.0
	top = maxf(top_lim, minf(top, bot - 50.0 * float(col.size()) + 6.0))
	for c3: Variant in col:
		var b2: Control = c3 as Control
		_rail_put(b2, Vector2(root.size.x - b2.size.x - 4.0, top))
		top += 50.0
	if open_all:
		var y2: float = top - 50.0 * float(side.size())
		for c4: Variant in side:
			var b3: Control = c4 as Control
			_rail_put(b3, Vector2(root.size.x - b3.size.x - 54.0, y2))
			y2 += 50.0



func _rail_cd(b: Button, bl: Label, frac: float, txt: String) -> void :
	if b.modulate != Color.WHITE:
		b.modulate = Color.WHITE
	if bl.text != txt:
		bl.text = txt
	var sh: ColorRect = b.get_node_or_null("CdShade") as ColorRect
	if sh == null:
		return
	var h: float = roundf(38.0 * clampf(frac, 0.0, 1.0))
	if sh.visible != (h > 0.0):
		sh.visible = h > 0.0
	if absf(sh.size.y - h) > 0.5:
		sh.size = Vector2(38, h)
		sh.position = Vector2(3, 41.0 - h)


func _build_cmd() -> void :
	for it: Array in [["order_0", "icon_order_arty", "АРТУДАР"], ["jet_menu", "icon_attack_jet", "АВИА"], ["order_1", "icon_order_smoke", "ДЫМ"], ["order_2", "icon_aid", "ГОСПИТ."], ["repair_all", "icon_upgrade", "РЕМОНТ"], ["battle_cam", "icon_battle_cam", "БОЙ"], ["command", "icon_op_operation", "ШТАБ"]]:
		var key: String = String(it[0])
		var b: Button = UiKit.slot(String(it[1]), key.begins_with("order_") or key.begins_with("jet_"), 44.0)
		b.visible = false
		if key == "jet_menu":
			b.pressed.connect( func() -> void : _jet_fly_toggle())
		else:
			b.pressed.connect( func() -> void : action.emit(key))
		root.add_child(b)
		b.set_meta("rail_rank", RAIL_RANK.get(key, 9))
		if key.begins_with("order_") or key == "repair_all":


			var sh: = ColorRect.new()
			sh.name = "CdShade"
			sh.color = Color(0.05, 0.04, 0.03, 0.66)
			sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sh.position = Vector2(3, 3)
			sh.size = Vector2(38, 38)
			sh.visible = false
			b.add_child(sh)
		var bl: Label = UiKit.lbl("", 10, UiKit.GOLD, 3, 3)
		bl.position = Vector2(4, 1)
		if key.begins_with("order_"):
			bl.add_theme_color_override("font_color", UiKit.TEXT)
			bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bl.custom_minimum_size = Vector2(44, 0)
			bl.position = Vector2(0, 10)
		b.add_child(bl)
		var nl: Label = UiKit.lbl(String(it[2]), 9, UiKit.TEXT, 3, 2)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.custom_minimum_size = Vector2(44, 0)
		nl.position = Vector2(0, 32)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nl)
		keys[key] = b
		cmd_btns.append([b, bl, key])
		HoldTip.tip(b, HoldTip.act_line(key))
	_build_rail_more()
	_build_jet_fly()
	_build_rail_tab()
	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 6, 2))
	prompt_panel.visible = false
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(prompt_panel)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	prompt_panel.add_child(hb)
	prompt_icon = UiKit.icon_rect("icon_op_operation", 20.0)
	prompt_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(prompt_icon)
	prompt_lbl = UiKit.lbl("", 9, UiKit.TEXT, 2)
	prompt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_lbl.max_lines_visible = 4
	prompt_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	prompt_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt_lbl.custom_minimum_size = Vector2(170, 0)
	prompt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(prompt_lbl)
	var go: Button = _small_btn("ДА", "prompt_go", true, "green")
	go.custom_minimum_size = Vector2(56, 44)
	prompt_go_btn = go
	hb.add_child(go)
	var x: Button = UiKit.close_btn(44.0)
	x.pressed.connect( func() -> void : action.emit("prompt_no"))
	hb.add_child(x)




func _build_plan() -> void :
	plan_panel = PanelContainer.new()
	plan_panel.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 6, 5))
	plan_panel.visible = false
	plan_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	plan_panel.custom_minimum_size = Vector2(176, 0)
	root.add_child(plan_panel)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	plan_panel.add_child(vb)
	var hb: = Button.new()
	hb.flat = true
	hb.focus_mode = Control.FOCUS_NONE
	hb.custom_minimum_size = Vector2(0, 36)
	hb.gui_input.connect(_plan_head_input)
	hb.pressed.connect( func() -> void :
		if _plan_moved:
			_plan_moved = false
			return
		plan_state = (plan_state + 1) % 3
		plan_open = plan_state == 2
		_plan_list_t = 12.0
		_plan_war_open = true
		_plan_sig = ""
		_plan_t = 0.0
		UiKit.snd("ui_click"))
	var hrow: = HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 8)
	vb.add_child(hrow)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(hb)
	var px: Button = UiKit.close_btn(32.0)
	plan_panel.set_meta("x_btn", px)
	px.pressed.connect( func() -> void :

		plan_closed = true
		plan_state = 0
		plan_open = false
		_plan_sig = ""
		_plan_t = 0.0
		plan_panel.visible = false
		show_toast("План развития скрыт — вернуть: ЭКОНОМИКА или Настройки")
		UiKit.snd("ui_close"))
	hrow.add_child(px)
	plan_head = UiKit.lbl("ПЛАН", 10, UiKit.TITLE, 2, 2)
	plan_head.set_anchors_preset(Control.PRESET_FULL_RECT)
	plan_head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plan_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(plan_head)
	var gr: = HBoxContainer.new()
	gr.add_theme_constant_override("separation", 5)
	vb.add_child(gr)
	plan_panel.set_meta("goal_row", gr)
	plan_icon = UiKit.icon_rect("icon_farm", 24.0)
	plan_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	gr.add_child(plan_icon)
	plan_goal = UiKit.lbl("", 9, UiKit.TEXT, 1)
	plan_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plan_goal.custom_minimum_size = Vector2(140, 0)
	gr.add_child(plan_goal)
	plan_go = UiKit.big("ПОКАЗАТЬ", "green", "", 30.0, 10)
	plan_go.pressed.connect( func() -> void : action.emit("plan_go:" + _plan_key))
	vb.add_child(plan_go)
	plan_scroll = ScrollContainer.new()
	plan_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(plan_scroll)
	plan_list = VBoxContainer.new()
	plan_list.add_theme_constant_override("separation", 1)
	plan_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan_scroll.add_child(plan_list)



func _plan_head_input(ev: InputEvent) -> void :
	var hb: Control = plan_head.get_parent() as Control
	var host: Control = plan_panel.get_parent() as Control
	if host == null:
		return
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (ev as InputEventMouseButton).pressed:
			_plan_drag = 1
			_plan_moved = false
			_plan_drag_from = _plan_ev_pos(ev as InputEventMouse, hb, host)
			_plan_drag_org = plan_panel.position
		else:
			if _plan_drag == 2:
				GameConfig.plan_pos = plan_panel.position
				Save.save_prefs()
			_plan_drag = 0
	elif ev is InputEventMouseMotion and _plan_drag > 0:
		var d: Vector2 = _plan_ev_pos(ev as InputEventMouse, hb, host) - _plan_drag_from
		if _plan_drag == 1 and d.length() > 10.0:
			_plan_drag = 2
			_plan_moved = true
		if _plan_drag == 2:
			plan_panel.position = _plan_clamp(_plan_drag_org + d)




func _plan_ev_pos(ev: InputEventMouse, hb: Control, host: Control) -> Vector2:
	return host.get_global_transform_with_canvas().affine_inverse() * (hb.get_global_transform_with_canvas() * ev.position)



func _plan_clamp(p: Vector2) -> Vector2:
	var top: float = top_col.position.y + top_col.size.y + 4.0 if top_col != null else 4.0
	var sz: Vector2 = plan_panel.size
	return Vector2(roundf(clampf(p.x, 4.0, maxf(4.0, root.size.x - sz.x - 4.0))), roundf(clampf(p.y, top, maxf(top, holder.position.y - sz.y - 6.0))))



func plan_set_drag_pos(p: Vector2) -> void :
	GameConfig.plan_pos = p


func _plan_process(delta: float) -> void :
	if plan_panel == null:
		return
	EconGuide.plan_visible = GameConfig.hints and not plan_closed
	var p: Country = gw.player
	var g = gw.get("guide")
	var busy_ui: bool = ops_panel.visible or sel_card.visible or (panel != null and is_instance_valid(panel)) or (confirm_panel != null and confirm_panel.visible) or ui24_open_now()
	var tut_on: bool = get_parent() != null and get_parent().get("tutorial") != null and bool(get_parent().tutorial.get("active"))
	var want: bool = GameConfig.hints and not plan_closed and p != null and not p.eliminated and g != null and not busy_ui and not armies_open and not tut_on

	var at_war: bool = p != null and not p.at_war.is_empty()
	if at_war != _plan_was_war:
		_plan_was_war = at_war
		_plan_war_open = false
		if at_war and plan_state != 0:
			plan_state = 0
			plan_open = false
			_plan_sig = ""
	_plan_t -= delta
	if plan_state == 2 and want:

		_plan_list_t -= delta
		if _plan_list_t <= 0.0:
			plan_state = 1
			plan_open = false
			_plan_sig = ""
			_plan_t = 0.0


	var top_y: float = maxf(_qa_stack_bottom, top_col.position.y + top_col.size.y + 4.0)
	var room: float = holder.position.y - 8.0 - top_y
	var ores_on: bool = ore_panel != null and ore_panel.visible
	var eff: int = plan_state
	if ores_on or room < 120.0:
		eff = 0
	if want and _plan_t <= 0.0:
		_plan_t = 1.0
		var goals: Array = g.goals(p)
		var cur: Dictionary = {}
		var nd: int = 0
		for x: Dictionary in goals:
			if bool(x.get("done", false)):
				nd += 1
			elif cur.is_empty():
				cur = x
		if cur.is_empty():
			want = false
			plan_panel.set_meta("finished", true)
		else:
			var sig: String = "%d|%s|%d|%d" % [nd, String(cur.get("id", "")), eff, int(room / 20.0)]
			if sig != _plan_sig:
				_plan_sig = sig

				plan_head.text = (Loc.t("ПЛАН РАЗВИТИЯ %d из %d  ▶") if eff == 0 else Loc.t("ПЛАН РАЗВИТИЯ %d/%d %s")) % ([nd, goals.size()] if eff == 0 else [nd, goals.size(), ["▶", "▼", "▲"][eff]])
				plan_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				(plan_panel.get_meta("x_btn") as Control).visible = eff > 0
				(plan_panel.get_meta("goal_row") as Control).visible = eff > 0
				plan_panel.custom_minimum_size.x = 176.0 if eff > 0 else 0.0
				(plan_head.get_parent() as Control).custom_minimum_size = Vector2(plan_head.get_minimum_size().x + 6.0 if eff == 0 else 0.0, 36.0)
				plan_goal.text = "%s\n%s" % [String(cur.get("title", "")).to_upper(), String(cur.get("why", ""))]
				var it: Texture2D = UiKit.tex(String(cur.get("icon", "")))
				if it != null:
					plan_icon.texture = it
				_plan_key = String(cur.get("key", ""))
				plan_go.visible = _plan_key != "" and eff > 0
				for ch: Node in plan_list.get_children():
					plan_list.remove_child(ch)
					ch.queue_free()
				var show_list: bool = plan_open and eff == 2
				plan_scroll.visible = show_list
				if show_list:
					for x2: Dictionary in goals:
						var done: bool = bool(x2.get("done", false))
						var l: Label = UiKit.lbl(("✓ " if done else "• ") + String(x2.get("title", "")) + ("" if done or int(x2.get("reward", 0)) <= 0 else "  +%d" % int(x2.get("reward", 0))), 9, UiKit.GREEN if done else (UiKit.GOLD if x2 == cur else UiKit.MUTED), 1)
						plan_list.add_child(l)

					var cap: float = maxf(48.0, room - 160.0)
					plan_scroll.custom_minimum_size = Vector2(0.0, minf(plan_list.get_combined_minimum_size().y, cap))
				else:
					plan_scroll.custom_minimum_size = Vector2.ZERO
				plan_panel.reset_size()
				plan_panel.reset_size.call_deferred()
	elif bool(plan_panel.get_meta("finished", false)):
		want = false
	if want and _plan_drag != 2:
		var pos: Vector2 = Vector2(4.0, top_y)
		if GameConfig.plan_pos.x >= 0.0:
			pos = GameConfig.plan_pos
			pos.y = maxf(pos.y, top_y)
		pos = _plan_clamp(pos)
		if ores_on and Rect2(pos, plan_panel.size).intersects(ore_panel.get_global_rect().grow(4.0)):

			var ab: float = ore_panel.position.y - plan_panel.size.y - 6.0
			var bl: float = ore_panel.position.y + ore_panel.size.y + 6.0
			if ab >= top_col.position.y + top_col.size.y + 4.0:
				pos.y = ab
			elif bl + plan_panel.size.y <= holder.position.y - 6.0:
				pos.y = bl
			else:
				want = false
		if want and plan_panel.position.distance_to(pos) > 0.5:
			plan_panel.position = pos
	if plan_panel.visible != want:
		plan_panel.visible = want
		if want:
			plan_panel.reset_size()
