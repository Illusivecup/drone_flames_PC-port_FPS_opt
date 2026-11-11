extends Button




const U = preload("res://ui/ui24/arm_kit.gd")
const M = preload("res://ui/ui24/army_store.gd")

signal tapped(fid: int)
signal long_pressed(fid: int)
signal mode_tapped(fid: int, chip: Control)

var fid: int = -1
var data: Dictionary = {}
var rail: ColorRect
var check_box: PanelContainer
var check_ic: TextureRect
var slot_pc: PanelContainer
var build_ic: TextureRect
var gmark: Control
var no_lbl: Label
var name_lbl: Label
var hp: Control
var hp_lbl: Label
var act_ic: TextureRect
var act_lbl: Label
var chip: Button
var chip_ic: TextureRect
var chip_lbl: Label
var chip_face: Panel
var _chip_col: String = "stone"
var _hold: float = -1.0
var _long_fired: bool = false
var _checked: bool = false
var _sel: bool = false
var _hp_v: float = 1.0
var _hp_tw: Tween
var ck_tw: Tween


func _init() -> void :
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, 48)
	clip_contents = false
	_style(false)
	var hb: = HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 7
	hb.offset_right = -4
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hb)
	rail = ColorRect.new()
	rail.color = UiKit.RED
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.position = Vector2(2, 3)
	add_child(rail)
	resized.connect( func() -> void : rail.size = Vector2(3, size.y - 6))

	check_box = PanelContainer.new()
	check_box.add_theme_stylebox_override("panel", UiKit.sb("wb_slot", 2))
	check_box.custom_minimum_size = Vector2(24, 24)
	check_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	check_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check_box.visible = false
	hb.add_child(check_box)
	var ch_hold: = Control.new()
	ch_hold.custom_minimum_size = Vector2(18, 18)
	ch_hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check_box.add_child(ch_hold)
	check_ic = U.icon("wb_check", 16)
	check_ic.position = Vector2(1, 1)
	ch_hold.add_child(check_ic)

	slot_pc = PanelContainer.new()
	slot_pc.add_theme_stylebox_override("panel", UiKit.sb("wb_slot", 3))
	slot_pc.custom_minimum_size = Vector2(36, 36)
	slot_pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot_pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(slot_pc)
	build_ic = U.icon("icon_build_assault", 24)
	build_ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot_pc.add_child(build_ic)
	gmark = U.emblem_rect("emb_star", Color.WHITE, 14, true)
	gmark.position = Vector2(24, 23)
	gmark.size = Vector2(14, 14)
	gmark.top_level = false
	slot_pc.add_child(gmark)
	gmark.set_anchors_preset(Control.PRESET_TOP_LEFT)
	slot_pc.sort_children.connect( func() -> void :
		gmark.position = Vector2(slot_pc.size.x - 13, slot_pc.size.y - 13)
		gmark.size = Vector2(14, 14))

	var nc: = VBoxContainer.new()
	nc.add_theme_constant_override("separation", 3)
	nc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nc.alignment = BoxContainer.ALIGNMENT_CENTER
	nc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(nc)
	var nr: = HBoxContainer.new()
	nr.add_theme_constant_override("separation", 5)
	nr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nc.add_child(nr)
	no_lbl = UiKit.lbl("№1", 12, UiKit.TEXT, 2, 3)
	nr.add_child(no_lbl)
	name_lbl = UiKit.lbl("ШТУРМ", 10, UiKit.MUTED, 1, 2)
	name_lbl.clip_text = true
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nr.add_child(name_lbl)
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 5)
	hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nc.add_child(hr)
	hp = Control.new()
	hp.custom_minimum_size = Vector2(60, 7)
	hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.draw.connect(_draw_hp)
	hr.add_child(hp)
	hp_lbl = UiKit.lbl("12/12", 9, UiKit.TEXT, 2, 2)
	hr.add_child(hp_lbl)

	var ac: = VBoxContainer.new()
	ac.custom_minimum_size = Vector2(58, 0)
	ac.add_theme_constant_override("separation", 0)
	ac.alignment = BoxContainer.ALIGNMENT_CENTER
	ac.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(ac)
	act_ic = U.icon("icon_act_idle", 22)
	act_ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ac.add_child(act_ic)
	act_lbl = UiKit.lbl("СТОЯТ", 11, UiKit.MUTED, 2, 3)
	act_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ac.add_child(act_lbl)


	chip = Button.new()
	chip.focus_mode = Control.FOCUS_NONE
	chip.custom_minimum_size = Vector2(88, 0)
	chip.size_flags_vertical = Control.SIZE_FILL
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		chip.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	hb.add_child(chip)
	chip_face = Panel.new()
	chip_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chip_face.offset_top = 5
	chip_face.offset_bottom = -5
	chip.add_child(chip_face)
	chip.button_down.connect( func() -> void :
		chip_face.add_theme_stylebox_override("panel", _chip_sb("wb_btn_" + _chip_col + "_p")))
	UiKit.tap_snd(chip)
	chip.button_up.connect( func() -> void : chip_face.add_theme_stylebox_override("panel", _chip_sb("wb_btn_" + _chip_col)))
	var ch: = HBoxContainer.new()
	ch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ch.offset_left = 7
	ch.offset_right = -5
	ch.offset_top = 5
	ch.offset_bottom = -5
	ch.add_theme_constant_override("separation", 3)
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(ch)
	chip_ic = U.icon("icon_stance_attack", 16)
	ch.add_child(chip_ic)
	chip_lbl = UiKit.lbl("АТАКА", 9, UiKit.TEXT, 2, 3)
	chip_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.add_child(chip_lbl)
	var tri: = Control.new()
	tri.custom_minimum_size = Vector2(7, 8)
	tri.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tri.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tri.draw.connect( func() -> void : U.draw_tri(tri, Vector2(3.5, 4), 3.0, UiKit.TEXT))
	ch.add_child(tri)
	chip.pressed.connect( func() -> void : mode_tapped.emit(fid, chip))
	button_down.connect( func() -> void :
		_hold = 0.0
		_long_fired = false)
	button_up.connect( func() -> void : _hold = -1.0)
	pressed.connect( func() -> void :
		if not _long_fired:
			tapped.emit(fid))


func _style(sel: bool) -> void :
	var n: StyleBox = UiKit.sb("wb_card" if sel else "wb_panel_dark", 4, 2)
	var p: StyleBox = UiKit.sb("wb_card", 4, 2)
	for st: String in ["normal", "hover", "disabled"]:
		add_theme_stylebox_override(st, n)
	for st2: String in ["pressed", "hover_pressed"]:
		add_theme_stylebox_override(st2, p)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _process(delta: float) -> void :
	if _hold >= 0.0:
		if not button_pressed:
			_hold = -1.0
			return
		_hold += delta
		if _hold >= 0.4 and not _long_fired:
			_long_fired = true
			long_pressed.emit(fid)


func _draw_hp() -> void :
	var r: = Rect2(Vector2.ZERO, hp.size)
	hp.draw_rect(r.grow(1), UiKit.OUTLINE)
	hp.draw_rect(r, Color("2a2b22"))
	var col: Color = UiKit.GREEN if _hp_v > 0.66 else (UiKit.GOLD if _hp_v > 0.34 else UiKit.RED)
	var w: float = roundf(r.size.x * clampf(_hp_v, 0.0, 1.0))
	hp.draw_rect(Rect2(Vector2.ZERO, Vector2(w, r.size.y)), col)
	hp.draw_rect(Rect2(Vector2.ZERO, Vector2(w, 2)), col.lightened(0.35))
	for i in range(1, 6):
		hp.draw_rect(Rect2(Vector2(roundf(r.size.x * float(i) / 6.0), 0), Vector2(1, r.size.y)), Color(0, 0, 0, 0.35))


func set_hp(v: float, animate: bool) -> void :
	if _hp_tw != null and _hp_tw.is_valid():
		_hp_tw.kill()
	if not animate:
		_hp_v = v
		hp.queue_redraw()
		return
	_hp_tw = create_tween()
	_hp_tw.tween_method( func(x: float) -> void :
		_hp_v = x
		hp.queue_redraw(), _hp_v, v, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)



func set_data(r: Dictionary, show_group: bool, selecting: bool, checked: bool, selected: bool) -> void :
	var first: bool = data.is_empty()
	data = r
	fid = int(r["fid"])
	no_lbl.text = Loc.no(int(r["no"]))
	name_lbl.text = String(r["name"])
	U.set_tex_rect(build_ic, String(M.BUILD_ICON.get(String(r["build"]), "icon_build_assault")))
	gmark.visible = show_group and int(r["gid"]) >= 0
	if gmark.visible:
		U.set_emblem(gmark, String(r["gemb"]), U.color(int(r["gcol"])))
	var frac: float = float(r["n"]) / float(maxi(1, int(r["cap"])))
	hp_lbl.text = "%d/%d" % [int(r["n"]), int(r["cap"])]
	hp_lbl.add_theme_color_override("font_color", UiKit.RED if frac < 0.5 else UiKit.TEXT)
	set_hp(frac, not first)
	var act: String = String(r["act"])
	U.set_tex_rect(act_ic, String(M.ACT_ICON.get(act, "icon_act_idle")))
	act_lbl.text = Loc.t(String(M.ACT_TEXT.get(act, "")))
	act_lbl.add_theme_color_override("font_color", UiKit.RED if act == "fight" else (UiKit.GOLD if act in ["move", "sea"] else (Color("b9c76a") if act == "dug" else UiKit.MUTED)))
	rail.visible = act == "fight"
	var st: int = int(r["stance"])
	chip_lbl.text = Loc.t(String(M.STANCE_CHIP[st]))
	U.set_tex_rect(chip_ic, String(M.STANCE_ICON[st]))
	var c: String = "stone"
	_chip_col = c
	chip_face.add_theme_stylebox_override("panel", _chip_sb("wb_btn_" + c))
	chip.visible = not selecting
	var was: bool = check_box.visible
	check_box.visible = selecting
	set_checked(checked, was and selecting)
	if selected != _sel or first:
		_sel = selected
		_style(selected)


func _chip_sb(nm: String) -> StyleBox:
	return UiKit.sb(nm, 4, 2)



func set_checked(on: bool, animate: bool) -> void :
	var changed: bool = on != _checked
	_checked = on
	check_ic.visible = on
	if on and changed and animate:
		check_ic.pivot_offset = check_ic.size * 0.5
		check_ic.scale = Vector2(0.6, 0.6)
		var tw: Tween = check_ic.create_tween()
		tw.tween_property(check_ic, "scale", Vector2(1.3, 1.3), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(check_ic, "scale", Vector2.ONE, 0.04)
		ck_tw = tw



func anim(fight_phase: int, move_phase: int) -> void :
	var act: String = String(data.get("act", ""))
	if act == "fight":
		if U.has19("icon_act_fight_1"):
			act_ic.texture = U.tex("icon_act_fight_%d" % fight_phase)
		else:
			act_ic.modulate = Color(1.45, 1.25, 1.1) if fight_phase == 1 else Color.WHITE
			act_ic.scale = Vector2(1.12, 1.12) if fight_phase == 1 else Vector2.ONE
			act_ic.pivot_offset = act_ic.size * 0.5
	elif act in ["move", "sea"]:
		if U.has19("icon_act_move_1") and act == "move":
			act_ic.texture = U.tex("icon_act_move_%d" % move_phase)
		else:
			act_ic.modulate = Color(1.25, 1.2, 1.0) if move_phase == 1 else Color.WHITE
