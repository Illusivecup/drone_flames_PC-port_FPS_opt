extends Control






const U = preload("res://ui/ui24/arm_kit.gd")
const M = preload("res://ui/ui24/army_store.gd")
const Row = preload("res://ui/ui24/army_row.gd")
const ArmyGroups = preload("res://game/army_groups.gd")
const HT = preload("res://ui/ui24/hold_tip.gd")

signal changed

var hud: Node
var gw: GameWorld
var store: M
var dock: VBoxContainer
var bp: Control = null
var is_open: bool = false
var _rt: float = 0.0
var pv: Dictionary = {}
var panel: PanelContainer
var handle: Button
var grab_c: Control
var sum_l: Label
var sum_r: Label
var expanded: bool = false
var toast: Callable
var col_top: float = -1.0
var pop_anchor: Control
var head: HBoxContainer
var strip_sc: ScrollContainer
var strip: HBoxContainer
var sel_btn: Button
var sel_head: HBoxContainer
var sel_lbl: Label
var sel_all: Button
var filt_row: HBoxContainer
var filt_btns: Dictionary = {}
var tot_a: Label
var tot_b: Label
var list_sc: ScrollContainer
var list: VBoxContainer
var empty_lbl: Label
var rows: Dictionary = {}
var bar: HBoxContainer
var sbar: HBoxContainer
var bar_btns: Dictionary = {}
var place_box: HBoxContainer
var place_t1: Label
var place_t2: Label
var place_ic: TextureRect
var scrim: Control
var pop: PanelContainer
var sheet: PanelContainer
var sheet_refs: Dictionary = {}
var sheet_state: Dictionary = {}
var confirm: PanelContainer
var confirm_refs: Dictionary = {}
var tab_gid: int = -1
var flt: String = "all"
var selecting: bool = false
var checked: Dictionary = {}
var sel_fid: int = -1
var placing: String = ""
var target: Vector2 = Vector2.INF
var retreat_arm: float = 0.0
var _sm: Dictionary = {}
var _vis_rows: Array = []
var _strip_sig: String = ""
var _chips: Dictionary = {}
var _holds: Array = []
var _ft: float = 0.0
var _mt: float = 0.0
var fight_phase: int = 0
var move_phase: int = 0
var anim_on: bool = true
var _new_chip_gid: int = -1
const ROWS_PER_REFRESH: int = 6
var kb_override: float = -1.0
var cover_y: float = INF


static func pl(n: int, one: String, few: String, many: String) -> String:
	var m10: int = n % 10
	var m100: int = n % 100
	if m10 == 1 and m100 != 11:
		return "%d %s" % [n, one]
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return "%d %s" % [n, few]
	return "%d %s" % [n, many]




func mount(h: Node) -> void :
	hud = h
	gw = h.gw
	store = M.new(gw)
	name = "ArmyDock"


	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.root.add_child(self)
	process_priority = 100
	panel = PanelContainer.new()
	var psb: StyleBox = UiKit.sb("wb_panel", 6, 4)
	psb.content_margin_bottom = 5.0 + h._safe_margins().y
	panel.add_theme_stylebox_override("panel", psb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	dock = VBoxContainer.new()
	dock.add_theme_constant_override("separation", 4)
	panel.add_child(dock)
	_attach_panel()
	_build_handle()
	_build_head()
	_build_filter()
	_build_list()
	_build_bars()
	_build_place()
	visible = false
	if not h.action.is_connected(_on_hud_action):
		h.action.connect(_on_hud_action)
	call_deferred("_mount_front_overlay")



func _attach_panel() -> void :
	var host: Variant = hud.get("build_panel")
	if host is Control and is_instance_valid(host) and (host as Control).has_method("set_sheet"):
		bp = host
		return
	bp = null
	var tr: Control = hud.tab_row
	var par: Node = tr.get_parent() if tr != null else null
	if par == null:
		par = hud.holder
	if panel.get_parent() != par:
		if panel.get_parent() != null:
			panel.get_parent().remove_child(panel)
		par.add_child(panel)
		if tr != null and tr.get_parent() == par:
			par.move_child(panel, tr.get_index() + 1)


func _host_show(on: bool) -> void :
	if bp != null and is_instance_valid(bp):
		bp.call("set_sheet", panel if on else null)
		if on:
			panel.visible = true
	else:
		if panel.get_parent() == null:
			_attach_panel()
		panel.visible = on



func open_dock(gid: int = -999) -> void :
	if gw.player == null or gw.player.eliminated:
		return
	var aux: Variant = hud.get("army_ux")
	if not internal and aux != null and is_instance_valid(aux):
		aux.open_from_dock(gid)
		return
	if not is_open:
		UiKit.snd("ui_open")
		var pg: Variant = hud.get("_page")
		if pg is int and int(pg) != 4 and hud.has_method("select_page"):
			hud.select_page(4)
	is_open = true
	visible = true
	hud.armies_open = true
	hud.set_key_pressed("armies", true)
	hud.ui24_open(self)
	_host_show(true)
	if gid != -999:
		tab_gid = gid if gid < 0 or not store.by_id(gid).is_empty() else -1
		flt = "all"
	refresh()
	if gid != -999:
		_scroll_strip_to(tab_gid)
	_restack_cmd()



	for c: Variant in [panel, hud.holder, hud.tab_row, bp]:
		if c is Control and is_instance_valid(c) and not (c as Control).item_rect_changed.is_connected(_on_host_moved):
			(c as Control).item_rect_changed.connect(_on_host_moved)



func close() -> void :
	internal = false
	if not is_open and not visible:
		return
	is_open = false
	placing = ""
	target = Vector2.INF
	pv = {}
	selecting = false
	checked.clear()
	retreat_arm = 0.0
	_hide_confirm()
	close_sheet()
	close_pop()
	_host_show(false)
	visible = false
	hud.ui24_closed(self)
	hud.armies_open = false
	hud.set_key_pressed("armies", false)



func reset() -> void :
	close()
	for r: Node in rows.values():
		r.queue_free()
	rows.clear()
	tab_gid = -1
	sel_fid = -1
	flt = "all"
	expanded = false
	_strip_sig = ""


func toggle() -> void :
	if is_open:
		close()
		UiKit.snd("ui_close")
	else:
		open_dock()



func _on_hud_action(nm: String) -> void :
	if nm.begins_with("page_") and nm.substr(5).is_valid_int():
		var pg: int = int(nm.substr(5))
		if pg != _page_cur:
			_page_prev = _page_cur
			_page_cur = pg
	if is_open and nm.begins_with("page_"):
		close()



func is_placing() -> bool:
	return is_open and placing != "" and visible




func scroll_area() -> ScrollContainer:
	if not is_open or not visible:
		return null
	var mp: Vector2 = get_viewport().get_mouse_position()
	if strip_sc != null and strip_sc.is_visible_in_tree() and strip_sc.get_global_rect().has_point(mp):
		return strip_sc
	return list_sc if list_sc != null and list_sc.is_visible_in_tree() else null



func scroll_areas() -> Array:
	var out: Array = []
	if is_open and visible:
		for sc: ScrollContainer in [list_sc, strip_sc]:
			if sc != null and sc.is_visible_in_tree():
				out.append(sc)
	return out



func blocked_rects() -> Array:
	var out: Array = []
	if not visible:
		return out
	for c: Control in [panel, confirm, pop, sheet]:
		if c != null and is_instance_valid(c) and c.is_visible_in_tree():
			out.append(c.get_global_rect().grow(2.0))
	return out



func bottom_top() -> float:
	if bp != null and is_instance_valid(bp) and bp.get("tab_row") is Control:
		return (bp.get("tab_row") as Control).get_global_rect().position.y
	if hud.tab_row != null and hud.tab_row.is_visible_in_tree():
		return hud.tab_row.get_global_rect().position.y
	return panel.get_global_rect().position.y if panel.is_visible_in_tree() else get_viewport_rect().size.y



func _build_handle() -> void :
	handle = Button.new()
	handle.focus_mode = Control.FOCUS_NONE
	handle.custom_minimum_size = Vector2(0, 18)
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		handle.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	dock.add_child(handle)
	var hb: = HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.add_child(hb)
	sum_l = UiKit.lbl("", 9, UiKit.MUTED, 2, 2)
	sum_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sum_l.size_flags_stretch_ratio = 1.0
	hb.add_child(sum_l)
	var grab: = Control.new()
	grab.custom_minimum_size = Vector2(44, 20)
	grab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grab.draw.connect( func() -> void :
		var r: = Rect2(Vector2(4, 7), Vector2(36, 6))
		grab.draw_rect(r.grow(1), UiKit.OUTLINE)
		grab.draw_rect(r, Color("b9ae8c") if not expanded else UiKit.GOLD))
	hb.add_child(grab)
	grab_c = grab
	sum_r = UiKit.lbl("", 9, UiKit.MUTED, 2, 2)
	sum_r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sum_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sum_r)
	var drag: Array = [Vector2.ZERO, false]
	handle.gui_input.connect( func(e: InputEvent) -> void :
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				drag[0] = e.position
				drag[1] = false
			elif not bool(drag[1]):
				set_expanded( not expanded)
		elif e is InputEventMouseMotion and (e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
			var dy: float = e.position.y - (drag[0] as Vector2).y
			if absf(dy) > 18.0 and not bool(drag[1]):
				drag[1] = true
				set_expanded(dy < 0.0))


func set_expanded(on: bool) -> void :
	expanded = on
	refresh()
	if grab_c != null:
		grab_c.queue_redraw()




func _build_head() -> void :
	head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	head.custom_minimum_size = Vector2(0, 44)
	dock.add_child(head)
	back_btn = UiKit.arrow(true)
	back_btn.name = "ArmyBack"
	back_btn.pressed.connect(exit_mode)
	HT.key(back_btn, "dock_back")
	head.add_child(back_btn)
	strip_sc = ScrollContainer.new()
	strip_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	strip_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip_sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_sc.custom_minimum_size = Vector2(0, 47)
	head.add_child(strip_sc)
	var sm: = MarginContainer.new()
	sm.add_theme_constant_override("margin_top", 3)
	sm.add_theme_constant_override("margin_right", 6)
	strip_sc.add_child(sm)
	strip = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 6)
	sm.add_child(strip)
	sel_head = HBoxContainer.new()
	sel_head.add_theme_constant_override("separation", 6)
	sel_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_head.visible = false
	head.add_child(sel_head)
	sel_lbl = UiKit.lbl("Выбрано: 0", 16, UiKit.TITLE, 3, 4)
	sel_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sel_head.add_child(sel_lbl)
	sel_all = UiKit.big("ВСЕ", "stone", "", 44.0, 11)
	sel_all.custom_minimum_size.x = 70
	sel_all.pressed.connect(_select_all)
	sel_head.add_child(sel_all)
	sel_btn = UiKit.slot("icon_multi_select", true, 44.0)
	HT.key(sel_btn, "dock_select")
	sel_btn.toggled.connect( func(on: bool) -> void :
		if on != selecting:
			set_selecting(on))
	head.add_child(sel_btn)
	if not U.native("icon_multi_select"):
		UiKit.set_slot_icon(sel_btn, "icon_ok")


func _build_filter() -> void :
	filt_row = HBoxContainer.new()
	filt_row.add_theme_constant_override("separation", 4)
	filt_row.custom_minimum_size = Vector2(0, 44)
	dock.add_child(filt_row)
	for k: String in ["all", "fight", "move", "idle"]:
		var b: = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 0.8 if k == "all" else 1.0
		var hb: = HBoxContainer.new()
		hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 3)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		if k != "all":
			hb.add_child(U.icon(String(M.ACT_ICON[k]), 16))
		var l: Label = UiKit.lbl("0", 10, UiKit.TEXT, 2, 3)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(l)
		var key: String = k
		b.pressed.connect( func() -> void :
			flt = key
			refresh())
		UiKit.press_fx(b)
		filt_row.add_child(b)
		filt_btns[k] = [b, l]



func _build_list() -> void :
	list_sc = ScrollContainer.new()
	list_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	dock.add_child(list_sc)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_sc.add_child(list)
	empty_lbl = UiKit.lbl("", 10, UiKit.MUTED, 1, 2)
	empty_lbl.custom_minimum_size = Vector2(0, 44)
	empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_lbl.visible = false
	dock.add_child(empty_lbl)


func _bar_btn(parent: HBoxContainer, key: String, icon_n: String, text: String, colour: String, tri: bool) -> void :
	var b: Button = UiKit.big("", colour, "", 44.0, 9)
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb: = VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_top = 3
	vb.offset_bottom = -2
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)
	var ic: TextureRect = U.icon(icon_n, 18)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ic)
	var lr: = HBoxContainer.new()
	lr.alignment = BoxContainer.ALIGNMENT_CENTER
	lr.add_theme_constant_override("separation", 2)
	lr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lr)
	var lb: Label = UiKit.lbl(text, 9, UiKit.TEXT, 2, 3)
	lr.add_child(lb)
	if tri:
		var t: = Control.new()
		t.custom_minimum_size = Vector2(7, 8)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.draw.connect( func() -> void : U.draw_tri(t, Vector2(3.5, 4), 3.0, UiKit.TEXT))
		lr.add_child(t)
	var badge: Label = _badge()
	b.add_child(badge)
	b.resized.connect( func() -> void : badge.position = Vector2(b.size.x - badge.size.x + 3, -5))
	b.pressed.connect( func() -> void : _on_bar(key, b))
	HT.key(b, {"s_move": "move", "s_mode": "mode", "cancel": "cancel_sel"}.get(key, key))
	parent.add_child(b)
	bar_btns[key] = {"b": b, "ic": ic, "lb": lb, "badge": badge}



func _fight_pill() -> Control:
	var pc: = PanelContainer.new()
	var s: = StyleBoxFlat.new()
	s.bg_color = Color("b8321f")
	s.border_color = UiKit.OUTLINE
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 2
	s.content_margin_right = 3
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	pc.add_theme_stylebox_override("panel", s)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 1)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)
	var ic: TextureRect = U.icon("icon_act_fight_0", 12)
	hb.add_child(ic)
	var l: Label = UiKit.lbl("0", 9, Color.WHITE, 2, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(l)
	pc.set_meta("lbl", l)
	pc.visible = false
	return pc


func _badge() -> Label:
	var l: Label = UiKit.lbl("", 9, Color.WHITE, 2, 0)
	var s: = StyleBoxFlat.new()
	s.bg_color = Color("d23a2a")
	s.border_color = UiKit.OUTLINE
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	l.add_theme_stylebox_override("normal", s)
	l.custom_minimum_size = Vector2(16, 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.visible = false
	return l


func _build_bars() -> void :
	bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	dock.add_child(bar)
	_bar_btn(bar, "move", "icon_move", "ДВИЖЕНИЕ", "gold", false)
	_bar_btn(bar, "mode", "icon_stance_attack", "РЕЖИМ", "stone", true)
	_bar_btn(bar, "defend", "icon_stance_defend", "ДЕРЖАТЬ", "stone", false)
	_bar_btn(bar, "trench", "icon_occupy", "ОКОПЫ", "stone", true)
	_bar_btn(bar, "retreat", "icon_op_retreat", "ОТХОД", "stone", false)
	_bar_btn(bar, "front", "icon_op_defend", "ФРОНТ", "stone", true)
	sbar = HBoxContainer.new()
	sbar.add_theme_constant_override("separation", 4)
	sbar.visible = false
	dock.add_child(sbar)
	_bar_btn(sbar, "to_group", "icon_group_add", "В ГРУППУ", "gold", true)
	_bar_btn(sbar, "s_move", "icon_move", "ДВИЖЕНИЕ", "stone", false)
	_bar_btn(sbar, "s_mode", "icon_stance_attack", "РЕЖИМ", "stone", true)
	_bar_btn(sbar, "cancel", "icon_close", "ОТМЕНА", "stone", false)


func _build_place() -> void :
	place_box = HBoxContainer.new()
	place_box.add_theme_constant_override("separation", 8)
	place_box.custom_minimum_size = Vector2(0, 48)
	place_box.visible = false
	dock.add_child(place_box)
	place_back = UiKit.arrow(true)
	place_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	place_back.pressed.connect(exit_mode)
	place_box.add_child(place_back)
	var sl: = PanelContainer.new()
	sl.add_theme_stylebox_override("panel", UiKit.sb("wb_slot_active", 4))
	sl.custom_minimum_size = Vector2(44, 44)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	place_box.add_child(sl)
	place_ic = U.icon("icon_move", 28)
	place_ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sl.add_child(place_ic)
	var vb: = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place_box.add_child(vb)
	place_t1 = UiKit.lbl("", 12, UiKit.TITLE, 2, 3)
	vb.add_child(place_t1)
	place_t1.clip_text = true
	place_t1.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	place_t2 = UiKit.lbl("", 10, UiKit.TEXT, 1, 2)
	vb.add_child(place_t2)
	place_t2.clip_text = true
	place_t2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var cb: Button = UiKit.big("ОТМЕНА", "stone", "", 44.0, 11)
	cb.custom_minimum_size.x = 92
	cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cb.pressed.connect(cancel_place)
	place_box.add_child(cb)




func _strip_signature() -> String:
	var s: String = "%d|%s|%d|" % [tab_gid, selecting, Loc.gen]
	for g: Dictionary in store.groups:
		s += "%d:%s:%d:%s;" % [int(g["id"]), String(g["name"]), int(g["color"]), String(g["emblem"])]
	return s + str( not store.armies(_sm, -2).is_empty())


func _rebuild_strip() -> void :
	for ch: Node in strip.get_children():
		ch.queue_free()
	_chips.clear()
	_holds = _holds.filter( func(h: Array) -> bool: return is_instance_valid(h[0]) and not strip.is_ancestor_of(h[0]))
	_chip(-1)
	for g: Dictionary in store.groups:
		_chip(int(g["id"]))
	if not store.armies(_sm, -2).is_empty():
		_chip(-2)
	var add: Button = UiKit.slot("icon_group_add", false, 44.0)
	if not U.native("icon_group_add"):
		UiKit.set_slot_icon(add, "icon_plus")
	add.pressed.connect( func() -> void :
		var fids: = PackedInt32Array()
		for fid: int in checked.keys():
			fids.append(fid)
		open_sheet("new", -1, fids))
	strip.add_child(add)


func _chip(gid: int) -> void :
	var g: Dictionary = store.by_id(gid) if gid >= 0 else {}
	var active: bool = gid == tab_gid
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var nsb: StyleBox = UiKit.sb("wb_card" if active else "wb_btn_stone", 6, 3)
	var psb: StyleBox = UiKit.sb("wb_card" if active else "wb_btn_stone_p", 6, 3)
	for st: String in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, nsb)
	for st2: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st2, psb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var hb: = HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 6
	hb.offset_right = -6
	hb.add_theme_constant_override("separation", 5)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	var col: Color = U.color(int(g["color"])) if not g.is_empty() else UiKit.MUTED
	if not g.is_empty():
		hb.add_child(U.emblem_rect(String(g["emblem"]), col, 24, true))
	elif gid == -2:
		hb.add_child(U.icon("icon_infantry", 24))
	var vb: = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", -1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var nm: String = Loc.t("ВСЕ") if gid == -1 else (Loc.t("БЕЗ ГРУППЫ") if gid == -2 else Loc.gtag(gid, String(g["name"])))
	var nl: Label = UiKit.lbl(nm, 11, UiKit.GOLD if active else UiKit.TEXT, 2, 3)
	vb.add_child(nl)
	var sub: Label = UiKit.lbl("", 9, UiKit.MUTED, 2, 2)
	vb.add_child(sub)
	var nw: float = UiKit.f_black.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var sw: float = UiKit.f_black.get_string_size("00 армий", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	b.custom_minimum_size.x = ceilf((6.0 + 24.0 + 5.0 if gid != -1 else 8.0) + maxf(nw, sw) + 4.0 + 8.0)
	if not g.is_empty():
		var band: = ColorRect.new()
		band.color = col
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(band)
		b.resized.connect( func() -> void :
			band.position = Vector2(5, b.size.y - 6)
			band.size = Vector2(b.size.x - 10, 3))
	var badge: Control = _fight_pill()
	b.add_child(badge)
	badge.position = Vector2(2, 27)
	if active and gid >= 0:
		var tri: = Control.new()
		tri.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tri.size = Vector2(8, 8)
		tri.draw.connect( func() -> void : U.draw_tri(tri, Vector2(4, 3), 3.0, UiKit.GOLD))
		b.add_child(tri)
		b.resized.connect( func() -> void :
			tri.position = Vector2(b.size.x - 11, 4))
	strip.add_child(b)
	_chips[gid] = {"b": b, "sub": sub, "badge": badge}
	var id: int = gid
	_hold_wire(b, func() -> void : _chip_tap(id, b), func() -> void :
		if id >= 0:
			open_sheet("edit", id, PackedInt32Array()))
	if gid == _new_chip_gid:
		_new_chip_gid = -1
		b.ready.connect( func() -> void : UiKit.pop_in(b, 0.6, 0.26), CONNECT_ONE_SHOT)



func _hold_wire(b: Button, tap: Callable, long_cb: Callable) -> void :
	var h: Array = [b, -1.0, false, long_cb]
	_holds.append(h)
	b.button_down.connect( func() -> void :
		h[1] = 0.0
		h[2] = false)
	b.button_up.connect( func() -> void : h[1] = -1.0)
	b.pressed.connect( func() -> void :
		if not bool(h[2]):
			tap.call())
	UiKit.press_fx(b)


func set_tab(gid: int) -> void :
	tab_gid = gid
	flt = "all"
	refresh()
	_scroll_strip_to(gid)


func _scroll_strip_to(gid: int) -> void :
	await get_tree().process_frame
	await get_tree().process_frame
	if not _chips.has(gid):
		return
	var bv: Variant = _chips[gid]["b"]
	if not is_instance_valid(bv) or not is_instance_valid(strip_sc):
		return
	var b: Button = bv
	var x0: float = b.position.x
	var x1: float = x0 + b.size.x
	if x1 > strip_sc.scroll_horizontal + strip_sc.size.x:
		strip_sc.scroll_horizontal = int(x1 - strip_sc.size.x + 8)
	elif x0 < strip_sc.scroll_horizontal:
		strip_sc.scroll_horizontal = int(maxf(0.0, x0 - 8))




func tab_rows() -> Array:
	return store.armies(_sm, tab_gid)


func refresh() -> void :
	if gw.player == null or gw.ops == null or not is_open:
		return
	_rt = 1.0
	_sm = gw.ops.command_summary(gw.player.id)
	store.scan(_sm)
	if tab_gid >= 0 and store.by_id(tab_gid).is_empty():
		tab_gid = -1
	if sel_fid >= 0 and _row_by_fid(sel_fid).is_empty():
		sel_fid = -1
	for fid0: int in checked.keys():
		if _row_by_fid(fid0).is_empty():
			checked.erase(fid0)
	var sig: String = _strip_signature()
	if sig != _strip_sig:
		_strip_sig = sig
		_rebuild_strip()
	for gid: int in _chips:
		var rg: Array = store.armies(_sm, gid)
		var tg: Dictionary = store.totals(rg)
		if is_instance_valid(_chips[gid]["sub"]):
			(_chips[gid]["sub"] as Label).text = (Loc.n(rg.size(), "%d армия", "%d армии", "%d армий") % (rg.size()))
		var nf: int = int((tg["counts"] as Dictionary)["fight"])
		var bd: Control = _chips[gid]["badge"]
		bd.visible = nf > 0 and gid != -1
		(bd.get_meta("lbl") as Label).text = str(nf)
	var all_rows: Array = tab_rows()
	var t: Dictionary = store.totals(all_rows)
	var cnt: Dictionary = t["counts"]
	for k: String in filt_btns:
		var b: Button = filt_btns[k][0]
		var l: Label = filt_btns[k][1]
		var n: int = all_rows.size() if k == "all" else int(cnt[k])
		l.text = (Loc.t("ВСЕ %d") % n) if k == "all" else "%s %d" % [{"fight": Loc.t("В БОЮ"), "move": Loc.t("ИДУТ"), "idle": Loc.t("СТОЯТ")}[k], n]
		var on: bool = flt == k
		var c: String = "gold" if on else "stone"
		for st: String in ["normal", "hover"]:
			b.add_theme_stylebox_override(st, UiKit.sb("wb_btn_" + c, 6, 3, -1))
		for st2: String in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st2, UiKit.sb("wb_btn_" + c + "_p", 6, 3, 1))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var dim: bool = n == 0 and k != "all"
		l.add_theme_color_override("font_color", UiKit.DIM if dim else (UiKit.RED if k == "fight" and n > 0 and not on else UiKit.TEXT))
		b.modulate = Color(1, 1, 1, 0.6) if dim else Color.WHITE
	sum_l.text = Loc.t("%s · сила %d%%") % [(Loc.n(int(t["troops"]), "%d боец", "%d бойца", "%d бойцов") % (int(t["troops"]))), roundi(float(t["hp"]) * 100.0)]
	sum_r.text = Loc.t("в бою %d · идут %d · ждут %d") % [int(cnt["fight"]), int(cnt["move"]), int(cnt["idle"])]
	sum_r.add_theme_color_override("font_color", UiKit.RED if int(cnt["fight"]) > 0 else UiKit.MUTED)
	_vis_rows = all_rows.filter( func(r: Dictionary) -> bool: return M.pass_filter(r, flt))
	var seen: Dictionary = {}
	var i: int = 0
	var made: int = 0
	for r: Dictionary in _vis_rows:
		var fid: int = int(r["fid"])
		var row: Row = rows.get(fid)
		if row == null:
			if made >= ROWS_PER_REFRESH:
				_rt = 0.0
				continue
			made += 1
			row = Row.new()
			row.tapped.connect(_on_row_tap)
			row.long_pressed.connect(_on_row_long)
			row.mode_tapped.connect(_on_row_mode)
			list.add_child(row)
			rows[fid] = row
		row.visible = true
		list.move_child(row, i)
		row.set_data(r, tab_gid == -1, selecting, checked.has(fid), fid == sel_fid)
		seen[fid] = true
		i += 1
	for fid2: int in rows.keys():
		if not seen.has(fid2):
			var gone: bool = _row_by_fid(fid2).is_empty()
			if gone:
				(rows[fid2] as Node).queue_free()
				rows.erase(fid2)
			else:
				(rows[fid2] as Control).visible = false
	if empty_lbl != null:
		empty_lbl.visible = _vis_rows.is_empty()
		empty_lbl.text = Loc.t("Нет армий — постройте казармы (вкладка АРМИЯ)") if (_sm.get("armies", []) as Array).is_empty() else (Loc.t("В группе нет армий: выберите армии во «ВСЕ» и «В ГРУППУ»") if tab_gid >= 0 and all_rows.is_empty() else Loc.t("Нет армий с таким состоянием"))

	var vp: Vector2 = get_viewport_rect().size
	var rh: float = 52.0
	var want_h: float
	if expanded:
		var fixed: float = 46.0 + 9.0 + 24.0 + 48.0 + 48.0 + 48.0 + 5.0 + hud._safe_margins().y
		want_h = floorf((vp.y * 0.62 - fixed) / rh) * rh - 4.0
	else:
		want_h = (3.2 if vp.y >= 740.0 else 2.25) * rh - 4.0
	list_sc.custom_minimum_size.y = minf(want_h, maxf(1.0, float(_vis_rows.size())) * rh - 4.0) if not _vis_rows.is_empty() else 0.0
	_refresh_bar(all_rows)
	changed.emit()


func _refresh_bar(all_rows: Array) -> void :
	var sel_n: int = checked.size()
	bar.visible = not selecting and placing == ""
	sbar.visible = selecting and placing == ""
	if bar_btns.has("front"):
		(bar_btns["front"]["b"] as Button).visible = tab_gid >= 0
	if bar_btns.has("defend"):
		(bar_btns["defend"]["b"] as Button).visible = tab_gid < 0
	head.visible = placing == ""
	filt_row.visible = placing == "" and not selecting and expanded
	handle.visible = placing == ""
	list_sc.visible = placing == "" and not _vis_rows.is_empty()
	if empty_lbl != null:
		empty_lbl.visible = empty_lbl.visible and placing == ""
	place_box.visible = placing != ""
	strip_sc.visible = not selecting
	sel_head.visible = selecting
	sel_lbl.text = Loc.t("Выбрано: %d") % sel_n
	if sel_btn.button_pressed != selecting:
		sel_btn.set_pressed_no_signal(selecting)
	var mv: Dictionary = bar_btns["move"]
	(mv["badge"] as Label).text = str(all_rows.size())
	(mv["badge"] as Label).visible = all_rows.size() > 0
	(mv["badge"] as Label).add_theme_color_override("font_color", Color.WHITE)
	var maj: int = _majority_stance(all_rows)
	U.set_tex_rect(bar_btns["mode"]["ic"], String(M.STANCE_ICON[maj]))
	U.set_tex_rect(bar_btns["s_mode"]["ic"], String(M.STANCE_ICON[maj]))
	var rt: Dictionary = bar_btns["retreat"]
	if is_instance_valid(rt["lb"]):
		(rt["lb"] as Label).text = Loc.t("ЕЩЁ РАЗ") if retreat_arm > 0.0 else Loc.t("ОТХОД")
	var smv: Dictionary = bar_btns["s_move"]
	(smv["badge"] as Label).text = str(sel_n)
	(smv["badge"] as Label).visible = sel_n > 0
	for k: String in ["to_group", "s_move", "s_mode"]:
		(bar_btns[k]["b"] as Button).disabled = sel_n == 0


func _majority_stance(rs: Array) -> int:
	var c: Array[int] = [0, 0, 0]
	for r: Dictionary in rs:
		c[int(r["stance"])] += 1
	var best: int = 0
	for i in 3:
		if c[i] > c[best]:
			best = i
	return best




func _on_row_tap(fid: int) -> void :
	if selecting:
		if checked.has(fid):
			checked.erase(fid)
		else:
			checked[fid] = true
		refresh()
		return
	if sel_fid == fid:
		hud.action.emit("arm_sel:%d" % fid)
		return
	sel_fid = fid
	var r: Dictionary = _row_by_fid(fid)
	if not r.is_empty():
		hud.main_node.cam_lock = false
		hud.main_node.cam.center_on(army_center(fid, r["pos"]))
	refresh()


func _on_row_long(fid: int) -> void :
	if not selecting:
		set_selecting(true)
	checked[fid] = true
	refresh()


func _on_row_mode(fid: int, chip: Control) -> void :
	var r: Dictionary = _row_by_fid(fid)
	if r.is_empty():
		return
	var items: Array = []
	for s in 3:
		var sv: int = s
		items.append({"icon": String(M.STANCE_ICON[s]), "text": String(M.STANCE_TEXT[s]), "sub": ["приказы только от вас", "держат район казарм", "сами идут на врага"][s], 
			"on": int(r["stance"]) == s, "cb": func() -> void : set_stance(PackedInt32Array([fid]), sv)})
	popover(chip, Loc.t("РЕЖИМ АРМИИ №%d") % int(r["no"]), items)


func _row_by_fid(fid: int) -> Dictionary:
	for r: Dictionary in store.armies(_sm, -1):
		if int(r["fid"]) == fid:
			return r
	return {}



func _cmd(mod: String, fn: String, args: Array, done: Callable = Callable()) -> void :
	NetSession.sim("", "cmd_static", [gw.player, mod, fn, args], func(r: Variant) -> void :
		if is_instance_valid(self) and done.is_valid():
			done.call(r))


static func _res(r: Variant) -> Dictionary:
	return r if r is Dictionary else {"ok": 0, "skipped": []}


func set_stance(fids: PackedInt32Array, s: int) -> void :
	var who: String = ""
	if fids.size() == 1:
		var f: Facility = ArmyGroups.fac(gw, fids[0])
		who = Loc.t("Армия №%d") % (f.army_no if f != null else 0)
	elif tab_gid >= 0 and not selecting:
		who = Loc.t("Группа «%s»") % Loc.uname(String(store.by_id(tab_gid).get("name", "")))
	_cmd("groups", "set_stance", [fids, s, who], func(r: Variant) -> void :
		if r is String and String(r) != "":
			_toast(String(r))
		refresh())



func army_center(fid: int, fallback: Vector2) -> Vector2:
	var s: = Vector2.ZERO
	var n: int = 0
	for u: Unit in gw.army.units:
		if u.home != null and u.home.id == fid and u.alive() and u.reinf == 0:
			s += u.pos
			n += 1
	return s / float(n) if n > 0 else fallback


func set_selecting(on: bool) -> void :
	selecting = on
	if not on:
		checked.clear()
	close_pop()
	refresh()


func _select_all() -> void :
	var all_on: bool = true
	for r: Dictionary in _vis_rows:
		if not checked.has(int(r["fid"])):
			all_on = false
	for r2: Dictionary in _vis_rows:
		if all_on:
			checked.erase(int(r2["fid"]))
		else:
			checked[int(r2["fid"])] = true
	refresh()


func checked_fids() -> PackedInt32Array:
	var o: = PackedInt32Array()
	for r: Dictionary in tab_rows():
		if checked.has(int(r["fid"])):
			o.append(int(r["fid"]))
	return o




func target_label() -> String:
	if tab_gid >= 0:
		var g: Dictionary = store.by_id(tab_gid)
		return Loc.t("Группа %d — %s") % [int(g["id"]), Loc.uname(String(g["name"]))]
	return Loc.t("Все армии") if tab_gid == -1 else Loc.t("Армии без группы")


func _on_bar(key: String, b: Button) -> void :
	var rs: Array = tab_rows()
	var fids: = PackedInt32Array()
	for r: Dictionary in rs:
		fids.append(int(r["fid"]))
	match key:
		"move":
			start_place("move")
		"defend":
			start_place("defend")
		"mode", "s_mode":
			var tgt: PackedInt32Array = fids if key == "mode" else checked_fids()
			var items: Array = []
			var cur: int = _majority_stance(rs)
			for s in 3:
				var sv: int = s
				items.append({"icon": String(M.STANCE_ICON[s]), "text": String(M.STANCE_TEXT[s]), "sub": Loc.t("для %s") % (Loc.n(tgt.size(), "%d армии", "%d армий", "%d армий") % (tgt.size())), 
					"on": s == cur and key == "mode", "cb": func() -> void : set_stance(tgt, sv)})
			popover(b, Loc.t("РЕЖИМ: %s") % [(target_label().to_upper() if key == "mode" else Loc.t("ВЫБРАННЫЕ"))], items)
		"retreat":
			if retreat_arm > 0.0:
				retreat_arm = 0.0
				_cmd("groups", "order_fids", [fids, "retreat", Vector2.INF, target_label()], func(r: Variant) -> void :
					var res: Dictionary = _res(r)
					if int(res["ok"]) == 0:
						var sk: Array = res["skipped"]
						_toast((Loc.t("Отход: %s") % [_reason(sk[0])]) if not sk.is_empty() else Loc.t("Отход: нет армий")))
			else:
				retreat_arm = 3.0
			refresh()
		"trench":
			trench_menu(b, fids)
		"front":
			if tab_gid >= 0:
				group_menu(tab_gid, b)
		"to_group":
			open_to_group_menu(b)
		"s_move":
			start_place("move")
		"cancel":
			set_selecting(false)


func open_to_group_menu(anchor: Control) -> void :
	var fids: PackedInt32Array = checked_fids()
	var items: Array = []
	for g: Dictionary in store.groups:
		var gid: int = int(g["id"])
		items.append({"emb": String(g["emblem"]), "col": int(g["color"]), "text": "%d · %s" % [gid, Loc.gname(String(g["name"])).to_upper()], 
			"sub": Loc.t("сейчас %s") % [(Loc.n((g["fids"] as PackedInt32Array).size(), "%d армия", "%d армии", "%d армий") % ((g["fids"] as PackedInt32Array).size()))], "on": false, 
			"cb": func() -> void :
				_cmd("groups", "add", [gid, fids], func(_r: Variant) -> void : refresh())
				_toast(Loc.t("%s → группа «%s»") % [(Loc.n(fids.size(), "%d армия", "%d армии", "%d армий") % (fids.size())), Loc.uname(String(g["name"]))])
				set_selecting(false)
				set_tab(gid)})
	items.append({"icon": "icon_group_add", "text": "НОВАЯ ГРУППА", "sub": Loc.t("из %s") % (Loc.n(fids.size(), "%d армии", "%d армий", "%d армий") % (fids.size())), "on": false, "gold": true, 
		"cb": func() -> void : open_sheet("new", -1, fids)})
	items.append({"icon": "icon_close", "text": "УБРАТЬ ИЗ ГРУПП", "sub": "станут «без группы»", "on": false, 
		"cb": func() -> void :
			_cmd("groups", "remove", [fids], func(_r: Variant) -> void : refresh())
			set_selecting(false)})
	popover(anchor, Loc.t("ДОБАВИТЬ %s В…") % (Loc.n(fids.size(), "%d АРМИЮ", "%d АРМИИ", "%d АРМИЙ") % (fids.size())), items, 232.0)




func start_place(kind: String) -> void :
	placing = kind
	target = Vector2.INF
	close_pop()
	var n: int = checked.size() if selecting else tab_rows().size()
	U.set_tex_rect(place_ic, "icon_move" if kind == "move" else "icon_stance_defend")
	place_t1.text = "%s · %s" % [Loc.t("ДВИЖЕНИЕ") if kind == "move" else Loc.t("ДЕРЖАТЬ ТОЧКУ"), (target_label() if not selecting else Loc.t("выбранные")).to_upper()]
	place_t2.text = (Loc.t("Коснитесь цели на карте · %s") if kind == "move" else Loc.t("Коснитесь точки обороны · %s")) % (Loc.n(n, "%d армия", "%d армии", "%d армий") % (n))
	pv = {}
	hud.action.emit("cancel_select")
	refresh()


func cancel_place() -> void :
	placing = ""
	target = Vector2.INF
	pv = {}
	front_trail = PackedVector2Array()
	route_pts = PackedVector2Array()
	route_wp = Vector2.INF
	_hide_confirm()
	refresh()


func order_rows() -> Array:
	if selecting:
		var o: Array = []
		for r: Dictionary in tab_rows():
			if checked.has(int(r["fid"])):
				o.append(r)
		return o
	return tab_rows()



func set_target(p: Vector2) -> void :
	if placing == "":
		return
	if placing == "front" or placing == "plan":
		_front_target(p)
		return
	target = p
	route_pts = PackedVector2Array()
	route_wp = Vector2.INF
	var rs: Array = order_rows()
	pv = store.order_preview(rs, placing, p)
	var mins: int = maxi(1, roundi(float(pv.get("mins", 0.0))))
	var g: Dictionary = store.by_id(tab_gid) if tab_gid >= 0 and not selecting else {}
	_show_confirm(g, rs.size(), pv, mins)
	UiKit.snd("ui_select")
	changed.emit()


func _reason(s: Array) -> String:
	var r: String = String(s[1])
	return r.left(1).to_lower() + r.substr(1)


func _show_confirm(g: Dictionary, n: int, pvd: Dictionary, mins: int) -> void :
	_hide_confirm()
	confirm = PanelContainer.new()
	confirm.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 6))
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(confirm)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	confirm.add_child(hb)
	if not g.is_empty():
		hb.add_child(U.emblem_rect(String(g["emblem"]), U.color(int(g["color"])), 30, true))
	else:
		hb.add_child(U.icon("icon_move", 30))
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var kinds: Dictionary = pvd.get("kinds", {})
	var what: String = "оборона точки"
	if placing == "move":
		what = Loc.t("наступление") if kinds.size() == 1 and kinds.has(Operations.Kind.ATTACK) else (Loc.t("оборона рубежа") if kinds.size() == 1 and kinds.has(Operations.Kind.DEFEND) else Loc.t("движение"))
	var who: String = target_label() if not selecting else Loc.t("Выбранные армии")
	var l1: Label = UiKit.lbl("%s → %s%s" % [who, what, Loc.t(" по маршруту") if route_wp.is_finite() else ""], 11, UiKit.TITLE, 2, 3)
	l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(l1)
	var nok: int = int(pvd["ok"])
	vb.add_child(UiKit.lbl((Loc.t("Пойдут %d из %d · в пути ~%d мин") % [nok, n, mins]) if nok > 0 else Loc.t("Никто не пойдёт (0 из %d)") % n, 10, UiKit.TEXT if nok > 0 else UiKit.RED, 1, 2))
	var sk: Array = pvd["skipped"]
	if not sk.is_empty():
		var parts: PackedStringArray = []
		for s: Array in sk.slice(0, 3):
			parts.append("%s (%s)" % [Loc.no(int(s[0])), _reason(s)])
		if sk.size() > 3:
			parts.append(Loc.t("ещё %d") % (sk.size() - 3))
		var l3: Label = UiKit.lbl(Loc.t("Не пойдут: %s") % [", ".join(parts)], 9, UiKit.RED, 2, 2)
		l3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l3)
	var ok: Button = UiKit.big("ДА", "green", "", 44.0, 14)
	ok.custom_minimum_size = Vector2(66, 44)
	ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_confirm_order)
	ok.disabled = nok == 0
	hb.add_child(ok)
	confirm_refs = {"ok": ok}
	var c: PanelContainer = confirm
	c.ready.connect( func() -> void : UiKit.pop_in(c, 0.9, 0.18), CONNECT_ONE_SHOT)


func _confirm_order() -> void :
	if placing == "" or not target.is_finite() or gw.player == null:
		cancel_place()
		return
	var fids: = PackedInt32Array()
	for r: Dictionary in order_rows():
		fids.append(int(r["fid"]))
	var who: String = Loc.t("Выбранные") if selecting else target_label()
	var tgt: Vector2 = target
	var kind: String = placing
	_cmd("groups", "order_fids", [fids, placing, target, who, route_wp], func(r: Variant) -> void : _ordered(_res(r), kind, tgt))


func _ordered(res: Dictionary, placing: String, target: Vector2) -> void :
	var sk: Array = res["skipped"]
	if int(res["ok"]) == 0:
		var f0: Facility = ArmyGroups.fac(gw, int(sk[0][0])) if not sk.is_empty() else null
		_toast((Loc.t("Приказ не выполнен: №%d %s") % [f0.army_no if f0 != null else 0, _reason(sk[0])]) if not sk.is_empty() else Loc.t("Нет армий для приказа"))
		UiKit.snd("ui_error")
		return
	if hud.main_node.get("overlay") != null:
		hud.main_node.overlay.ripple(target, "alert_red" if placing == "move" else "amber")
	if selecting:
		selecting = false
		checked.clear()
	cancel_place()


func _toast(t: String) -> void :
	if toast.is_valid():
		toast.call(t)
	else:
		hud.show_toast(t)


func _hide_confirm() -> void :
	if confirm != null and is_instance_valid(confirm):
		confirm.queue_free()
	confirm = null




func popover(anchor: Control, title: String, items: Array, w: float = 214.0) -> void :
	close_pop()
	scrim = Control.new()
	scrim.position = Vector2.ZERO
	scrim.size = get_viewport_rect().size
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect( func(e: InputEvent) -> void :
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close_pop())
	add_child(scrim)
	pop = PanelContainer.new()
	pop.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 6, 6))
	pop.custom_minimum_size = Vector2(w, 0)
	pop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pop)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pop.add_child(vb)
	var tl: Label = UiKit.lbl(title, 10, UiKit.TITLE, 2, 3)
	vb.add_child(tl)
	for it: Dictionary in items:
		var on: bool = bool(it.get("on", false))
		var b: Button = UiKit.big("", "gold" if bool(it.get("gold", false)) else ("green" if on else "stone"), "", 44.0, 10)
		b.custom_minimum_size = Vector2(0, 44)
		var hb: = HBoxContainer.new()
		hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = 8
		hb.offset_right = -8
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		if it.has("emb"):
			hb.add_child(U.emblem_rect(String(it["emb"]), U.color(int(it["col"])), 24, true))
		else:
			var pic: TextureRect = U.icon(String(it.get("icon", "")), 22)
			pic.flip_v = bool(it.get("flip", false))
			hb.add_child(pic)
		var tv: = VBoxContainer.new()
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", -1)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tv)
		tv.add_child(UiKit.lbl(String(it["text"]), 11, UiKit.TEXT, 2, 3))
		if String(it.get("sub", "")) != "":
			tv.add_child(UiKit.lbl(String(it["sub"]), 9, UiKit.TEXT if on else UiKit.MUTED, 1, 2))
		if on:
			hb.add_child(U.icon("wb_check", 16))
		var cb: Callable = it["cb"]
		b.pressed.connect( func() -> void :
			close_pop()
			cb.call())
		vb.add_child(b)
	var ar: Rect2 = anchor.get_global_rect()
	var p: PanelContainer = pop
	var vp: Vector2 = get_viewport_rect().size
	var sz: Vector2 = p.get_combined_minimum_size()
	p.size = sz
	var x: float = clampf(ar.get_center().x - sz.x * 0.5, 4.0, vp.x - sz.x - 4.0)
	var y: float = ar.position.y - sz.y - 6.0
	if y < 90.0:
		y = ar.end.y + 6.0
	p.position = Vector2(roundf(x), roundf(y))
	pop_anchor = anchor
	UiKit.pop_in(p, 0.9, 0.16)


func _place_pop() -> void :
	if pop == null or not is_instance_valid(pop) or pop_anchor == null or not is_instance_valid(pop_anchor):
		return
	var ar: Rect2 = pop_anchor.get_global_rect()
	var vp: Vector2 = get_viewport_rect().size
	var sz: Vector2 = pop.size
	var x: float = clampf(ar.get_center().x - sz.x * 0.5, 4.0, vp.x - sz.x - 4.0)
	var y: float = ar.position.y - sz.y - 6.0
	if y < 60.0:
		y = ar.end.y + 6.0
	pop.position = Vector2(roundf(x), roundf(y))


func close_pop() -> void :
	if pop != null and is_instance_valid(pop):
		pop.queue_free()
	if scrim != null and is_instance_valid(scrim):
		scrim.queue_free()
	pop = null
	scrim = null




func open_sheet(mode: String, gid: int, fids: PackedInt32Array) -> void :
	close_pop()
	close_sheet()
	if mode == "new" and store.groups.size() >= ArmyGroups.MAX_GROUPS:
		_toast(Loc.t("Не больше %d групп: расформируйте лишнюю") % ArmyGroups.MAX_GROUPS)
		UiKit.snd("ui_error")
		return
	if mode == "edit" and store.by_id(gid).is_empty():
		return
	var g: Dictionary = store.by_id(gid) if gid >= 0 else {}
	var used: Dictionary = {}
	for gg: Dictionary in store.groups:
		used[int(gg["color"])] = true
	var col: int = 2
	for i in 8:
		if not used.has((i + 2) % 8):
			col = (i + 2) % 8
			break
	sheet_state = {"mode": mode, "gid": gid, "fids": fids, 
		"name": Loc.uname(String(g["name"]) if not g.is_empty() else store.default_name()), 
		"src": String(g["name"]) if not g.is_empty() else store.default_name(), 
		"color": int(g["color"]) if not g.is_empty() else col, 
		"emblem": String(g["emblem"]) if not g.is_empty() else "emb_star"}
	scrim = Control.new()
	scrim.position = Vector2.ZERO
	scrim.size = get_viewport_rect().size
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.32)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.add_child(dim)
	sheet = PanelContainer.new()
	var ssb: StyleBox = UiKit.sb("wb_window", 10, 10)
	ssb.content_margin_bottom = 14.0 + hud._safe_margins().y
	sheet.add_theme_stylebox_override("panel", ssb)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	sheet.add_child(vb)

	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 6)
	vb.add_child(hr)
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tv)
	var t: Label = UiKit.lbl(Loc.t("Новая группа") if mode == "new" else Loc.t("Группа %d") % gid, 18, UiKit.TITLE, 3, 4)
	tv.add_child(t)
	var nsub: int = fids.size() if mode == "new" else (g["fids"] as PackedInt32Array).size()
	tv.add_child(UiKit.lbl((Loc.n(nsub, "%d армия", "%d армии", "%d армий") % (nsub)) + (Loc.t(" · выбраны в списке") if mode == "new" else Loc.t(" · удерживайте вкладку, чтобы изменить")), 9, UiKit.MUTED, 1, 2))
	var x: Button = UiKit.close_btn(44.0)
	x.pressed.connect(close_sheet)
	hr.add_child(x)

	var pr: = HBoxContainer.new()
	pr.add_theme_constant_override("separation", 10)
	vb.add_child(pr)
	var pv: = PanelContainer.new()
	pv.add_theme_stylebox_override("panel", UiKit.sb("wb_slot", 2))
	pv.custom_minimum_size = Vector2(60, 60)
	pr.add_child(pv)
	var pen: = Control.new()
	pen.custom_minimum_size = Vector2(56, 56)
	pen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pen.draw.connect( func() -> void :
		U.draw_pennant(pen, Vector2(14, 52), 2.9, U.color(int(sheet_state["color"])), String(sheet_state["emblem"])))
	pv.add_child(pen)
	var nv: = VBoxContainer.new()
	nv.add_theme_constant_override("separation", 3)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pr.add_child(nv)
	var nlh: = HBoxContainer.new()
	nv.add_child(nlh)
	var nl: Label = UiKit.lbl("НАЗВАНИЕ", 10, UiKit.TITLE, 2, 3)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nlh.add_child(nl)
	var cnt: Label = UiKit.lbl("", 9, UiKit.MUTED, 2, 2)
	nlh.add_child(cnt)
	var le: = LineEdit.new()
	le.text = String(sheet_state["name"])
	le.max_length = M.NAME_MAX
	le.custom_minimum_size = Vector2(0, 44)
	le.add_theme_font_override("font", UiKit.f_black)
	le.add_theme_font_size_override("font_size", 15)
	le.add_theme_color_override("font_color", UiKit.TEXT)
	le.add_theme_color_override("caret_color", UiKit.GOLD)
	le.add_theme_color_override("font_placeholder_color", UiKit.DIM)
	le.add_theme_constant_override("caret_width", 2)
	le.placeholder_text = "до 12 букв"
	for st: String in ["normal", "focus", "read_only"]:
		le.add_theme_stylebox_override(st, UiKit.sb("wb_slot" if st != "focus" else "wb_slot_pressed", 10, 6))
	le.right_icon = U.tex("icon_rename")
	le.text_changed.connect( func(s: String) -> void :
		sheet_state["name"] = s
		_sheet_refresh())
	nv.add_child(le)

	vb.add_child(UiKit.lbl("ЦВЕТ", 10, UiKit.TITLE, 2, 3))
	var cr: = HBoxContainer.new()
	cr.add_theme_constant_override("separation", 6)
	cr.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(cr)
	var sw: Array = []
	for i2 in 8:
		var b: = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(36, 36)
		var fill: = ColorRect.new()
		fill.color = U.color(i2)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(fill)
		var ck: TextureRect = U.icon("wb_check", 14)
		b.add_child(ck)
		b.resized.connect( func() -> void :
			fill.position = Vector2(6, 6)
			fill.size = b.size - Vector2(12, 12)
			ck.position = ((b.size - ck.size) * 0.5).round())
		var ci: int = i2
		b.pressed.connect( func() -> void :
			sheet_state["color"] = ci
			_sheet_refresh()
			_bump(b))
		UiKit.press_fx(b)
		cr.add_child(b)
		sw.append([b, ck])

	vb.add_child(UiKit.lbl("ЭМБЛЕМА", 10, UiKit.TITLE, 2, 3))
	var er: = HBoxContainer.new()
	er.add_theme_constant_override("separation", 2)
	er.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(er)
	var eb: Array = []
	for e: String in U.EMBLEMS:
		var b2: = Button.new()
		b2.focus_mode = Control.FOCUS_NONE
		b2.custom_minimum_size = Vector2(40, 44)
		var em: Control = U.emblem_rect(e, Color.WHITE, 32)
		b2.add_child(em)
		b2.resized.connect( func() -> void : em.position = ((b2.size - Vector2(32, 32)) * 0.5).round())
		var en: String = e
		b2.pressed.connect( func() -> void :
			sheet_state["emblem"] = en
			_sheet_refresh()
			_bump(b2))
		UiKit.press_fx(b2)
		er.add_child(b2)
		eb.append([b2, em, e])

	var br: = HBoxContainer.new()
	br.add_theme_constant_override("separation", 8)
	vb.add_child(br)
	if mode == "edit":
		var dis: Button = _hold_button("РАСФОРМИРОВАТЬ", func() -> void :
			_cmd("groups", "disband", [gid], func(_r: Variant) -> void : refresh())
			close_sheet()
			set_tab(-1))
		br.add_child(dis)
	else:
		var cc: Button = UiKit.big("ОТМЕНА", "stone", "", 44.0, 12)
		cc.custom_minimum_size.x = 110
		cc.pressed.connect(close_sheet)
		br.add_child(cc)
	var ok: Button = UiKit.big(Loc.t("СОЗДАТЬ") if mode == "new" else Loc.t("ГОТОВО"), "green", "", 44.0, 13)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_sheet_done)
	br.add_child(ok)
	var hint: Label = UiKit.lbl("Одна армия — в одной группе. Группа получает приказы одной кнопкой.", 9, UiKit.MUTED, 1, 2)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = get_viewport_rect().size.x - 24.0
	vb.add_child(hint)
	sheet_refs = {"pen": pen, "cnt": cnt, "sw": sw, "eb": eb, "ok": ok, "le": le}
	_sheet_refresh()
	var vp: Vector2 = get_viewport_rect().size
	var s: PanelContainer = sheet
	s.custom_minimum_size.x = vp.x
	s.reset_size()
	var h: float = minf(s.get_combined_minimum_size().y, vp.y * 0.62)
	s.size = Vector2(vp.x, h)
	var y: float = vp.y - h
	s.position = Vector2(0, y + 24)
	s.modulate.a = 0.0
	var tw: Tween = s.create_tween().set_parallel(true)
	tw.tween_property(s, "position:y", y, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 1.0, 0.18)
	tw.finished.connect( func() -> void : s.set_meta("settled", true))
	UiKit.snd("ui_open")




func _place_sheet() -> void :
	if sheet == null or not is_instance_valid(sheet) or not sheet.has_meta("settled"):
		return
	var vp: Vector2 = get_viewport_rect().size
	var le: LineEdit = sheet_refs.get("le")
	var typing: bool = le != null and is_instance_valid(le) and le.has_focus()
	var kb: float = 0.0
	if typing:
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			var win: Vector2 = Vector2(DisplayServer.window_get_size())
			kb = float(DisplayServer.virtual_keyboard_get_height()) * (vp.x / maxf(win.x, 1.0))
		if kb_override >= 0.0:
			kb = kb_override
	var y: float = maxf(4.0, vp.y - kb - sheet.size.y + (hud._safe_margins().y + 14.0 - 6.0 if kb > 0.0 else 0.0))
	sheet.position.y = roundf(lerpf(sheet.position.y, y, 0.5)) if absf(sheet.position.y - y) > 1.0 else y


func _bump(c: Control) -> void :
	c.pivot_offset = c.size * 0.5
	var tw: Tween = c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.12, 1.12), 0.07)
	tw.tween_property(c, "scale", Vector2.ONE, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _sheet_refresh() -> void :
	if sheet_refs.is_empty():
		return
	var col: Color = U.color(int(sheet_state["color"]))
	(sheet_refs["pen"] as Control).queue_redraw()
	(sheet_refs["cnt"] as Label).text = "%d/%d" % [String(sheet_state["name"]).length(), M.NAME_MAX]
	for i in 8:
		var e: Array = sheet_refs["sw"][i]
		var on: bool = i == int(sheet_state["color"])
		_slot_style(e[0], on)
		(e[1] as TextureRect).visible = on
	for e2: Array in sheet_refs["eb"]:
		var on2: bool = String(e2[2]) == String(sheet_state["emblem"])
		_slot_style(e2[0], on2)
		U.set_emblem(e2[1], String(e2[2]), col if on2 else Color("cfc6a8"))
	(sheet_refs["ok"] as Button).disabled = String(sheet_state["name"]).strip_edges() == ""


func _slot_style(b: Button, on: bool) -> void :
	var s: StyleBox = UiKit.sb("wb_slot_active" if on else "wb_slot", 2)
	for st: String in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())



func _hold_button(text: String, done: Callable) -> Button:
	var b: Button = UiKit.big(text, "red", "", 44.0, 11)
	b.custom_minimum_size.x = 150
	var fill: = ColorRect.new()
	fill.color = Color(1, 0.85, 0.6, 0.35)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.size = Vector2(0, 0)
	b.add_child(fill)
	var tw_ref: Array = [null]
	b.button_down.connect( func() -> void :
		fill.position = Vector2(4, 4)
		fill.size = Vector2(0, b.size.y - 8)
		var tw: Tween = fill.create_tween()
		tw.tween_property(fill, "size:x", b.size.x - 8, 0.8)
		tw.tween_callback( func() -> void :
			if b.button_pressed:
				done.call())
		tw_ref[0] = tw)
	b.button_up.connect( func() -> void :
		if tw_ref[0] != null and (tw_ref[0] as Tween).is_valid():
			(tw_ref[0] as Tween).kill()
		fill.size.x = 0)
	return b


func _sheet_done() -> void :
	var st: Dictionary = sheet_state
	if st.has("src") and String(st["name"]) == Loc.uname(String(st["src"])):
		st["name"] = String(st["src"])
	if String(st["mode"]) == "new":
		_cmd("groups", "create", [String(st["name"]), int(st["color"]), String(st["emblem"]), st["fids"]], func(r: Variant) -> void :
			_created(r if r is Dictionary else {}))
	else:
		_cmd("groups", "edit", [int(st["gid"]), String(st["name"]), int(st["color"]), String(st["emblem"])], func(_r: Variant) -> void : refresh())
		close_sheet()
		refresh()


func _created(g: Dictionary) -> void :
	if g.is_empty():
		_toast(Loc.t("Не больше %d групп: расформируйте лишнюю") % ArmyGroups.MAX_GROUPS)
		UiKit.snd("ui_error")
		return
	_new_chip_gid = int(g["id"])
	close_sheet()
	selecting = false
	checked.clear()
	set_tab(int(g["id"]))
	_toast(Loc.t("Создана группа «%s»: %s") % [Loc.uname(String(g["name"])), 
		(Loc.n((g["fids"] as PackedInt32Array).size(), "%d армия", "%d армии", "%d армий") % ((g["fids"] as PackedInt32Array).size()))])


func close_sheet() -> void :
	if sheet != null and is_instance_valid(sheet):
		var le: Variant = sheet_refs.get("le")
		if le is LineEdit and is_instance_valid(le):
			(le as LineEdit).release_focus()
		sheet.queue_free()
	sheet = null
	sheet_refs = {}
	close_pop()




func _on_host_moved() -> void :
	if is_open and visible:
		_restack_cmd()





func _restack_cmd() -> void :

	var vis: Array = []
	var more_b: Button = null
	var more_l: Label = null
	var cand_cd: Dictionary = hud.get("rail_cand") if hud.get("rail_cand") != null else {}
	for e: Array in hud.cmd_btns:
		var b: Button = e[0]
		if String(e[2]) == "rail_more":
			more_b = b
			more_l = e[1]
			continue
		if b.visible or (bool(cand_cd.get(String(e[2]), false)) and not bool(hud._rail_covered())):
			b.set_meta("rail_key", String(e[2]))
			vis.append(b)
	if hud.ore_btn != null and (hud.ore_btn.visible or (bool(cand_cd.get("ore", false)) and not bool(hud._rail_covered()))):
		hud.ore_btn.set_meta("rail_key", "ore")
		vis.append(hud.ore_btn)
	if vis.is_empty():
		if more_b != null and more_b.visible:
			more_b.visible = false
		return



	vis.sort_custom( func(a: Button, b: Button) -> bool: return int(a.get_meta("rail_rank", 9)) < int(b.get_meta("rail_rank", 9)))
	var top: float = hud._win_top() + 4.0
	for c: Variant in [hud.dip_chip, hud.map_chip, hud.prompt_panel]:
		if c is Control and is_instance_valid(c) and (c as Control).visible:
			top = maxf(top, (c as Control).get_global_rect().end.y + 4.0)
	var ln: Variant = hud.get("lane")
	if ln is Control and is_instance_valid(ln) and (ln as Control).has_method("bottom") and (ln as Control).is_visible_in_tree():
		top = maxf(top, float((ln as Control).call("bottom")) + 16.0)
	if col_top >= 0.0:
		top = maxf(top, col_top + 4.0)
	var bot: float = bottom_top() - 4.0
	if confirm != null and is_instance_valid(confirm):
		bot = minf(bot, confirm.position.y - 4.0)
	bot = minf(bot, cover_y - 4.0)
	var per: int = _rail_per_stable(maxi(1, floori((bot - top) / 50.0)), vis)


	var fold: Dictionary = {}
	var more_on: bool = more_b != null and ceili(float(vis.size()) / float(maxi(1, per))) > 2
	if more_on:
		var open_all: bool = Time.get_ticks_msec() < int(hud.rail_more_ms) or bool(hud.get("ores_open"))
		if not open_all:
			var drop: int = vis.size() - (2 * per - 1)
			for k: String in ["repair_all", "ore", "order_2", "jet_menu", "battle_cam", "order_1", "order_0", "command"]:
				if drop <= 0:
					break
				for b3: Variant in vis:
					if String((b3 as Control).get_meta("rail_key", "")) == k:
						fold[k] = true
						drop -= 1
						break
		var keep: Array = []
		for b4: Variant in vis:
			var bb: Control = b4 as Control
			var folded_k: bool = fold.has(String(bb.get_meta("rail_key", "")))
			if bb.visible == folded_k:
				bb.visible = not folded_k
			if not folded_k:
				keep.append(bb)
		vis = keep
		vis.append(more_b)
		if not more_b.visible:
			more_b.visible = true
		var mt: String = "" if open_all else str(fold.size())
		if more_l != null and more_l.text != mt:
			more_l.text = mt
	elif more_b != null and more_b.visible:
		more_b.visible = false
	if hud.rail_fold != fold:
		hud.rail_fold = fold
	hud.rail_more_on = more_on

	var ncol: int = ceili(float(vis.size()) / float(maxi(1, per)))
	per = ceili(float(vis.size()) / float(maxi(1, ncol)))
	var vw: float = get_viewport_rect().size.x
	var cap_col: Array[int] = []
	for ci in ncol:
		cap_col.append(vis.size() / ncol + (1 if ci < vis.size() % ncol else 0))
	for i in vis.size():
		var row: int = vis.size() - 1 - i
		var col: int = 0
		while col < ncol - 1 and row >= cap_col[col]:
			row -= cap_col[col]
			col += 1
		var b2: Button = vis[i]
		var want: = Vector2(vw - b2.size.x - 4.0 - float(col) * 50.0 + float(hud.get("rail_dx") if hud.get("rail_dx") != null else 0.0), bot - 50.0 * float(row + 1) + 4.0)
		if b2.position.distance_squared_to(want) > 0.25:
			b2.position = want


var _rail_per: int = -1
var _rail_keys: String = ""
var _rail_want: int = -1
var _rail_want_ms: int = 0






func _rail_per_stable(per_now: int, vis: Array) -> int:
	var ks: String = ""
	for b: Variant in vis:
		ks += str(int((b as Control).get_meta("rail_rank", 9)))
	var now_ms: int = Time.get_ticks_msec()
	if _rail_per < 0 or ks != _rail_keys:
		_rail_keys = ks
		_rail_per = per_now
		_rail_want = per_now
		return per_now
	if per_now == _rail_per:
		_rail_want = per_now
		return _rail_per
	if per_now != _rail_want:
		_rail_want = per_now
		_rail_want_ms = now_ms
	var wait_ms: int = 500 if per_now < _rail_per else 1200
	if now_ms - _rail_want_ms >= wait_ms and not bool(hud._finger_down()):
		_rail_per = per_now
	return _rail_per


func _process(delta: float) -> void :
	if not visible or not is_open:
		return
	if gw.player == null or gw.player.eliminated:
		close()
		return
	_restack_cmd()
	_place_pop()
	_place_sheet()
	for h: Array in _holds:
		if float(h[1]) >= 0.0 and is_instance_valid(h[0]):
			if not (h[0] as Button).button_pressed:
				h[1] = -1.0
				continue
			h[1] = float(h[1]) + delta
			if float(h[1]) >= 0.45 and not bool(h[2]):
				h[2] = true
				(h[3] as Callable).call()
	if retreat_arm > 0.0:
		retreat_arm -= delta
		if retreat_arm <= 0.0:
			refresh()
	if confirm != null and is_instance_valid(confirm):
		var vp: Vector2 = get_viewport_rect().size
		confirm.custom_minimum_size.x = vp.x - 12.0
		confirm.size.x = vp.x - 12.0
		confirm.position = Vector2(6, roundf(bottom_top() - confirm.size.y - 6.0))

	_rt -= delta
	if _rt <= 0.0 and not hud._finger_down() and (sheet == null or not is_instance_valid(sheet)) and (pop == null or not is_instance_valid(pop)):
		refresh()
	if not anim_on:
		return
	_ft += delta
	_mt += delta
	var upd: bool = false
	if _ft >= 0.25:
		_ft = 0.0
		fight_phase = 1 - fight_phase
		upd = true
	if _mt >= 0.333:
		_mt = 0.0
		move_phase = 1 - move_phase
		upd = true
	if upd:
		for r: Row in rows.values():
			if r.visible:
				r.anim(fight_phase, move_phase)




const FrontPlan = preload("res://game/front_plan.gd")
var front_ov: Control = null
var front_pv: Dictionary = {}
var plan_pv: Dictionary = {}
var _plan_drag: PackedVector2Array = PackedVector2Array()
var front_trail: PackedVector2Array = PackedVector2Array()
var _fd_ms: int = 0
var _fd_gap: int = 120
var _fd_press: int = -1


func _mount_front_overlay() -> void :
	if front_ov != null and is_instance_valid(front_ov):
		return
	var s: Variant = load("res://ui/ui24/front_overlay.gd")
	if not (s is GDScript):
		return
	front_ov = (s as GDScript).new()
	front_ov.mount(hud, self)



func _chip_tap(gid: int, chip: Control) -> void :
	if gid >= 0 and gid == tab_gid and not selecting and placing == "":
		group_menu(gid, chip)
		return
	set_tab(gid)



func group_menu(gid: int, anchor: Control) -> void :
	var g: Dictionary = store.by_id(gid)
	if g.is_empty() or gw.player == null:
		return
	var pid: int = gw.player.id
	var fr: Dictionary = FrontPlan.front_of(g)
	var pln: Dictionary = FrontPlan.plan_of(g)
	var items: Array = []
	var fsub: String = (Loc.t("сейчас: %s · %.1f км") % [Loc.name(String(FrontPlan._cname(gw, int(fr["foe"])))), float(fr["len"]) / 1000.0]) if not fr.is_empty() else Loc.t("встать вдоль границы с соседом")
	items.append({"icon": "icon_stance_defend", "text": Loc.t("ФРОНТ") if fr.is_empty() else Loc.t("ФРОНТ: ЗАНОВО"), "sub": fsub, "on": false, 
		"cb": func() -> void : start_front("front")})
	items.append({"icon": "icon_op_attack", "text": Loc.t("ПЛАН АТАКИ") if pln.is_empty() else Loc.t("ПЛАН: ЗАНОВО"), 
		"sub": Loc.t("стрелка от фронта вглубь врага") if not fr.is_empty() else Loc.t("сначала назначьте ФРОНТ"), "on": false, 
		"cb": func() -> void :
			if FrontPlan.front_of(store.by_id(gid)).is_empty():
				_toast("Сначала назначьте группе ФРОНТ")
				UiKit.snd("ui_error")
				return
			start_front("plan")})
	if not pln.is_empty() and int(pln["state"]) != FrontPlan.St.RUN and gw.player.at_war.has(int(pln["foe"])):
		items.append({"icon": "icon_op_attack", "text": "В АТАКУ СЕЙЧАС", "sub": "наступать по плану", "on": false, "gold": true, 
			"cb": func() -> void :
				_cmd("front", "attack_now", [gid], func(r: Variant) -> void :
					if r is String and String(r) != "":
						_toast(String(r))
						UiKit.snd("ui_error")
					refresh())})
	if not pln.is_empty():
		items.append({"icon": "icon_close", "text": "ОТМЕНИТЬ ПЛАН", "sub": Loc.t("армии вернутся на фронт") if FrontPlan.running(g) else Loc.t("стрелка будет стёрта"), "on": false, 
			"cb": func() -> void :
				_cmd("front", "cancel_plan", [gid], func(_r: Variant) -> void : refresh())})
	elif not fr.is_empty():
		items.append({"icon": "icon_close", "text": "СНЯТЬ ФРОНТ", "sub": "армии остановятся на месте", "on": false, 
			"cb": func() -> void :
				_cmd("front", "clear_front", [gid], func(_r: Variant) -> void : refresh())})
	items.append({"icon": "icon_stance_defend", "text": "ДЕРЖАТЬ ТОЧКУ", "sub": "встать и держать место на карте", "on": false, 
		"cb": func() -> void : start_place("defend")})
	var auto: bool = bool(g.get("auto", false))
	items.append({"icon": "icon_doctrine", "text": "АВТО-ФРОНТ", "sub": "штаб сам ведёт фронт и план в войне", "on": auto, 
		"cb": func() -> void :
			_cmd("front", "set_auto", [gid, not auto], func(_r: Variant) -> void : refresh())})
	popover(anchor, Loc.t("ГРУППА %d · %s") % [gid, Loc.gname(String(g["name"])).to_upper()], items, 248.0)




func start_front(kind: String) -> void :
	if tab_gid < 0:
		return
	if selecting:
		set_selecting(false)
	placing = kind
	target = Vector2.INF
	pv = {}
	front_pv = {}
	plan_pv = {}
	_plan_drag = PackedVector2Array()
	close_pop()
	_hide_confirm()
	U.set_tex_rect(place_ic, "icon_stance_defend" if kind == "front" else "icon_op_attack")
	place_t1.text = "%s · %s" % [Loc.t("ФРОНТ") if kind == "front" else Loc.t("ПЛАН АТАКИ"), target_label().to_upper()]
	place_t2.text = Loc.t("Тап или линия пальцем") if kind == "front" else Loc.t("Ведите пальцем от фронта вглубь врага")
	if kind == "plan" and not FrontPlan.plan_of(store.by_id(tab_gid)).is_empty():
		place_t2.text = "Стрелка заменит план"
	hud.action.emit("cancel_select")
	refresh()
	front_trail = PackedVector2Array()
	if kind == "front":

		_toast("Тап — фронт: у границы по ней, внутри страны — через точку к врагу. Палец — свой фронт. Карта — двумя пальцами")



func plan_drawing() -> bool:
	return is_open and visible and (placing == "plan" or placing == "front")


func _front_target(p: Vector2) -> void :
	var pid: int = gw.player.id
	if placing == "front":
		front_pv = FrontPlan.front_from_tap(gw, pid, tab_gid, p)
		var fpass: int = int(front_pv.get("pass", 0))
		_front_confirm(bool(front_pv.get("ok", false)), String(front_pv.get("text", "")) if bool(front_pv.get("ok", false)) else String(front_pv.get("why", "")), 
			(Loc.t("Нужен проход через %s — по «ДА» запросим") % Loc.name(FrontPlan._cname(gw, fpass))) if fpass > 0 else Loc.t("Армии встанут вдоль линии, поддержка сзади"), func() -> void :
				var fp: Dictionary = front_pv
				var gid: int = tab_gid
				cancel_place()
				front_pv = {}

				hud.main_node._sim("ops", "front_tap", [pid, gid, p], func(r: Variant) -> void :
					var why: String = String(r) if r is String else ("" if r != null else Loc.t("Фронт не назначен"))
					if why != "":
						_toast(why)
					elif fpass > 0:
						_ask_passage(fpass, int(fp.get("foe", 0)))
					refresh())
				refresh())
	else:
		_plan_drag = PackedVector2Array()
		plan_pv = FrontPlan.plan_check(gw, pid, tab_gid, Vector2.INF, p, Vector2.INF, true)
		_plan_confirm()
	UiKit.snd("ui_select")
	changed.emit()




func plan_drag(from_w: Vector2, to_w: Vector2) -> void :
	if not plan_drawing():
		return
	if placing == "front":
		_front_drag(from_w, to_w)
		return
	_hide_confirm()
	if _plan_drag.is_empty():
		_plan_drag.append(from_w)
	if _plan_drag[_plan_drag.size() - 1].distance_to(to_w) > 6.0:
		_plan_drag.append(to_w)
	var mid: = Vector2.INF
	if _plan_drag.size() >= 3:
		var half: float = FrontPlan.poly_len(_plan_drag) * 0.5
		var acc: float = 0.0
		for i in range(1, _plan_drag.size()):
			acc += _plan_drag[i - 1].distance_to(_plan_drag[i])
			if acc >= half:
				mid = _plan_drag[i]
				break
	if mid.is_finite():

		mid = mid * 2.0 - (from_w + to_w) * 0.5
	plan_pv = FrontPlan.plan_check(gw, gw.player.id, tab_gid, from_w, to_w, mid, true)


func plan_drag_end() -> void :
	if plan_drawing() and placing == "front":
		_front_drag_end()
		return
	if not plan_drawing() or plan_pv.is_empty():
		return
	_plan_confirm()




func _front_drag(from_w: Vector2, to_w: Vector2) -> void :
	_hide_confirm()



	var pms: int = int(hud.main_node.get("_press_ms")) if hud != null and hud.get("main_node") != null else -1
	if pms != _fd_press:
		_fd_press = pms
		front_trail = PackedVector2Array()
	if front_trail.is_empty():
		front_trail.append(from_w)
		front_pv = {}
	if front_trail[front_trail.size() - 1].distance_to(to_w) > 6.0:
		front_trail.append(to_w)
	var now: int = Time.get_ticks_msec()
	if now - _fd_ms > _fd_gap and FrontPlan.poly_len(front_trail) >= FrontPlan.DRAW_MIN:
		_fd_ms = now
		front_pv = FrontPlan.front_from_line(gw, gw.player.id, tab_gid, front_trail)
		_fd_gap = clampi((Time.get_ticks_msec() - now) * 4, 120, 400)



func _front_drag_end() -> void :
	var pts: PackedVector2Array = front_trail.duplicate()
	if FrontPlan.poly_len(pts) < 40.0:
		front_trail = PackedVector2Array()
		return
	var pid: int = gw.player.id
	var gid: int = tab_gid
	front_pv = FrontPlan.front_from_line(gw, pid, gid, pts)
	var ok: bool = bool(front_pv.get("ok", false))
	var fpass: int = int(front_pv.get("pass", 0))
	var l2: String = (Loc.t("Нужен проход через %s — по «ДА» запросим") % Loc.name(FrontPlan._cname(gw, fpass))) if fpass > 0 else\
	(Loc.t("Армии встанут на линии, поддержка сзади · %d участка") % int(front_pv.get("parts", 1)) if int(front_pv.get("parts", 1)) > 1 else Loc.t("Армии встанут на линии, поддержка сзади"))
	if not ok:
		l2 = "Нарисуйте линию заново или коснитесь границы"
	_front_confirm(ok, String(front_pv.get("text", "")) if ok else String(front_pv.get("why", "")), l2, func() -> void :
		var foe: int = int(front_pv.get("foe", 0))
		cancel_place()
		front_pv = {}
		front_trail = PackedVector2Array()
		hud.main_node._sim("ops", "front_draw", [pid, gid, pts], func(r: Variant) -> void :
			var why: String = String(r) if r is String else ("" if r != null else Loc.t("Фронт не назначен"))
			if why != "":
				_toast(why)
				UiKit.snd("ui_error")
			elif fpass > 0:
				_ask_passage(fpass, foe)
			refresh())
		refresh())
	UiKit.snd("ui_select")
	changed.emit()


func _plan_confirm() -> void :
	var ok: bool = bool(plan_pv.get("ok", false))
	var pid: int = gw.player.id
	var warn: String = String(plan_pv.get("warn", ""))
	var ppass: int = int(plan_pv.get("pass", 0))
	var l2: String = (Loc.t("Пойдут сразу после «ДА»: идёт война") if bool(plan_pv.get("war", false)) else Loc.t("Группа ждёт войны и пойдёт сама")) if ok else Loc.t("Нарисуйте стрелку заново")
	if ok and warn != "":
		l2 = Loc.t("Внимание: %s%s") % [warn, Loc.t(" — по «ДА» запросим") if ppass > 0 else ""]


	var gid0: int = tab_gid
	var old_pl: Dictionary = FrontPlan.plan_of(store.by_id(gid0))
	var old_run: bool = FrontPlan.running(store.by_id(gid0))
	var alt: Array = []
	if not old_pl.is_empty():
		l2 = (Loc.t("Заменит текущий план группы · %s") % [l2]) if ok else Loc.t("У группы уже есть план. Нарисуйте новую стрелку — она заменит старую")
		alt = ["ОТМЕНИТЬ СТАРЫЙ ПЛАН", func() -> void :
			cancel_place()
			plan_pv = {}
			_cmd("front", "cancel_plan", [gid0], func(_r: Variant) -> void : refresh())
			UiKit.snd("ui_select")
			refresh()]
	_front_confirm(ok, String(plan_pv.get("text", "")) if ok else String(plan_pv.get("why", "")), l2, func() -> void :
		var chk: Dictionary = plan_pv
		cancel_place()
		plan_pv = {}
		if ppass > 0:
			_ask_passage(ppass, int(chk.get("foe", 0)))
		var gid: int = tab_gid
		var go: = func() -> void :
			_cmd("front", "set_plan", [gid, chk], func(r: Variant) -> void :
				if r == true and bool(chk.get("war", false)):
					_cmd("front", "attack_now", [gid], func(r2: Variant) -> void :
						if r2 is String and String(r2) != "":
							_toast(String(r2))
						refresh())
				refresh())
		if old_run:
			_cmd("front", "cancel_plan", [gid0, true], func(_r: Variant) -> void : go.call())
		else:
			go.call()
		refresh(), alt)



func _ask_passage(grantor: int, vs: int) -> void :
	NetSession.sim("diplo", "request_passage", [gw.player.id, grantor, vs], func(rv: Variant) -> void :
		if is_instance_valid(self):
			_passage_said(grantor, String(rv) if rv is String else ("" if rv != null else Loc.t("Команда не выполнена"))))


func _passage_said(grantor: int, r: String) -> void :
	_toast((Loc.t("Проход через %s получен") % Loc.name(FrontPlan._cname(gw, grantor))) if r == "" else Loc.t("Проход через %s: %s") % [Loc.name(FrontPlan._cname(gw, grantor)), r.to_lower()])



func _front_confirm(ok: bool, line1: String, line2: String, cb: Callable, alt: Array = []) -> void :
	_hide_confirm()
	var vw: float = get_viewport_rect().size.x - 12.0
	confirm = PanelContainer.new()
	confirm.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 6))
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm.custom_minimum_size = Vector2(vw, 0)
	add_child(confirm)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	confirm.add_child(hb)
	var g: Dictionary = store.by_id(tab_gid)
	if not g.is_empty():
		hb.add_child(U.emblem_rect(String(g["emblem"]), U.color(int(g["color"])), 30, true))
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var tw: float = vw - 16.0 - (38.0 if not g.is_empty() else 0.0) - 74.0
	var l1: Label = UiKit.lbl(line1, 11, UiKit.TITLE if ok else UiKit.RED, 2, 3)
	l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l1.custom_minimum_size.x = tw
	vb.add_child(l1)
	var l2: Label = UiKit.lbl(line2, 10, UiKit.TEXT, 1, 2)
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.custom_minimum_size.x = tw
	vb.add_child(l2)
	var b: Button = UiKit.big("ДА", "green", "", 44.0, 14)
	b.custom_minimum_size = Vector2(66, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not ok
	b.pressed.connect(cb)
	hb.add_child(b)
	confirm_refs = {"ok": b}
	if alt.size() >= 2:
		var ab: Button = UiKit.big(String(alt[0]), "stone", "icon_close", 44.0, 11)
		ab.custom_minimum_size = Vector2(0, 44)
		ab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		ab.pressed.connect(alt[1] as Callable)
		vb.add_child(ab)
		confirm_refs["alt"] = ab
	var c: PanelContainer = confirm
	c.ready.connect( func() -> void :
		c.reset_size()
		UiKit.pop_in(c, 0.9, 0.18), CONNECT_ONE_SHOT)




var back_btn: Button
var place_back: Button
var _page_prev: int = -1
var _page_cur: int = -1
var route_pts: PackedVector2Array = PackedVector2Array()
var route_wp: Vector2 = Vector2.INF
const ROUTE_GRAB_PX: float = 70.0
const ROUTE_BEND_MIN: float = 40.0




func exit_mode() -> void :
	if not is_open:
		return
	var back_to: int = _page_prev if _page_cur == 4 and _page_prev >= 0 and _page_prev != 4 else -1
	if placing != "":
		cancel_place()
	front_pv = {}
	plan_pv = {}
	_plan_drag = PackedVector2Array()
	close()
	UiKit.snd("ui_close")
	hud.action.emit("cancel_select")
	if back_to >= 0 and hud.has_method("select_page"):
		hud.select_page(back_to)



func route_drawing() -> bool:
	return is_open and visible and (placing == "move" or placing == "defend")




func route_grab(sp: Vector2) -> bool:
	var uxd: Variant = hud.get("army_ux")
	if uxd != null and is_instance_valid(uxd) and uxd.has_method("drawing") and uxd.route_grab(sp):
		return true
	if not route_drawing():
		return false
	var cam: MapCamera = hud.main_node.cam
	for r: Dictionary in order_rows():
		var fid: int = int(r["fid"])
		for p: Vector2 in [army_center(fid, r["pos"]), r["pos"]]:
			if cam.world_to_screen(p).distance_to(sp) <= ROUTE_GRAB_PX:
				return true
	return false


func route_drag(from_w: Vector2, to_w: Vector2) -> void :
	var uxd: Variant = hud.get("army_ux")
	if uxd != null and is_instance_valid(uxd) and uxd.has_method("drawing") and uxd.drawing():
		uxd.route_drag(from_w, to_w)
		return
	if not route_drawing():
		return
	if route_pts.is_empty():
		_hide_confirm()
		target = Vector2.INF
		pv = {}
		route_wp = Vector2.INF
		route_pts.append(from_w)
	if route_pts[route_pts.size() - 1].distance_to(to_w) > 6.0:
		route_pts.append(to_w)
	changed.emit()




func route_drag_end() -> void :
	var uxd: Variant = hud.get("army_ux")
	if uxd != null and is_instance_valid(uxd) and uxd.has_method("drawing") and uxd.drawing():
		uxd.route_drag_end()
		return
	if not route_drawing() or route_pts.size() < 2:
		route_pts = PackedVector2Array()
		return
	var a: Vector2 = route_pts[0]
	var b: Vector2 = route_pts[route_pts.size() - 1]
	if a.distance_to(b) < 24.0:
		route_pts = PackedVector2Array()
		return
	route_wp = Vector2.INF
	var bd: float = ROUTE_BEND_MIN
	for p: Vector2 in route_pts:
		var d: float = p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
		if d > bd:
			bd = d
			route_wp = p
	target = b
	var rs: Array = order_rows()
	pv = store.order_preview(rs, placing, b, route_wp)
	var g: Dictionary = store.by_id(tab_gid) if tab_gid >= 0 and not selecting else {}
	_show_confirm(g, rs.size(), pv, maxi(1, roundi(float(pv.get("mins", 0.0)))))
	UiKit.snd("ui_select")
	changed.emit()




var _ftap: Array = [-1, -10000]




func front_tap(pos: Vector2) -> bool:
	if front_ov == null or not is_instance_valid(front_ov):
		return false
	var gid: int = int(front_ov.hit(pos))
	_ftap = [gid, Time.get_ticks_msec()]
	return gid >= 0




func front_dbl(pos: Vector2) -> bool:
	if front_ov == null or not is_instance_valid(front_ov) or int(_ftap[0]) < 0:
		return false
	if Time.get_ticks_msec() - int(_ftap[1]) > 450 or int(front_ov.hit(pos)) != int(_ftap[0]):
		return false
	var gid: int = int(_ftap[0])
	_ftap = [-1, -10000]
	front_ov.open_menu(gid)
	return true



func open_group_from_map(gid: int) -> void :
	if store.by_id(gid).is_empty():
		return
	var aux0: Variant = hud.get("army_ux")
	if aux0 != null and is_instance_valid(aux0):
		aux0.open_group(gid)
		return
	UiKit.snd("ui_select")
	if placing != "":
		return
	open_dock(gid)
	set_tab(gid)
	await get_tree().process_frame
	await get_tree().process_frame
	if _chips.has(gid) and is_open:
		group_menu(gid, _chips[gid]["b"])








func trench_menu(anchor: Control, fids: PackedInt32Array) -> void :
	if gw.player == null:
		return
	var pid: int = gw.player.id
	var gid: int = tab_gid
	var ti: Dictionary = ArmyGroups.trench_info(gw, pid, fids, gid)
	var who: String = target_label()
	var items: Array = []
	var slots: int = int(ti["slots"])
	var foot: int = int(ti["foot"])
	var inn: int = int(ti["in"])
	items.append({"icon": "icon_occupy", "text": "В ОКОПЫ", "gold": slots > 0 and foot > 0, 
		"sub": (Loc.t("свободных мест рядом: %d · пехоты: %d") % [slots, foot]) if foot > 0 else Loc.t("свободной пехоты нет"), 
		"cb": func() -> void :
			var f2: String = "trench_in" if gid >= 0 else "trench_in_fids"
			_cmd("groups", f2, [gid] if gid >= 0 else [fids, who], func(r: Variant) -> void :
				var d: Dictionary = r if r is Dictionary else {}
				if String(d.get("why", "")) != "":
					_toast(String(d["why"]))
					UiKit.snd("ui_error")
				refresh())})
	items.append({"icon": "icon_occupy", "flip": true, "text": "ИЗ ОКОПОВ", 
		"sub": (Loc.t("в окопах: %d · вернутся к приказу") % inn) if inn > 0 else Loc.t("в окопах никого нет"), 
		"cb": func() -> void :
			var f3: String = "trench_out" if gid >= 0 else "trench_out_fids"
			_cmd("groups", f3, [gid] if gid >= 0 else [fids, who], func(r: Variant) -> void :
				var d2: Dictionary = r if r is Dictionary else {}
				if String(d2.get("why", "")) != "":
					_toast(String(d2["why"]))
				refresh())})
	if slots == 0 and foot > 0:
		items.append({"icon": "icon_trench", "text": "ВЫРЫТЬ ОКОП", "sub": "ведите пальцем у фронта, потом «В ОКОПЫ»", 
			"cb": func() -> void :
				close()
				hud.action.emit("trench")})
	popover(anchor, Loc.t("ОКОПЫ · %s") % [who.to_upper()], items, 252.0)




func open_group_card(gid: int, fid: int = -1) -> void :
	if gw.player == null or gw.player.eliminated:
		return
	var aux1: Variant = hud.get("army_ux")
	if aux1 != null and is_instance_valid(aux1):
		if gid >= 0:
			aux1.open_group(gid)
		elif fid >= 0:
			aux1.open_army(fid)
		else:
			aux1.open_list()
		return
	if placing != "":
		return
	if gid >= 0 and store.by_id(gid).is_empty():
		gid = -1
	UiKit.snd("ui_select")
	open_dock(gid)
	if selecting:
		set_selecting(false)
	set_tab(gid)
	if gid >= 0 and hud.main_node != null and hud.main_node.has_method("focus_group"):
		hud.main_node.focus_group(gid)
	if fid >= 0:
		sel_fid = fid
		if gid == -2:
			checked.clear()
			checked[fid] = true
			set_selecting(true)
			checked[fid] = true
		refresh()




var internal: bool = false




func front_flow(gid: int, kind: String) -> void :
	internal = true
	open_dock(gid)
	tab_gid = gid
	flt = "all"
	refresh()
	start_front(kind)



func rename_flow(gid: int) -> void :
	internal = true
	open_dock(gid)
	tab_gid = gid
	refresh()
	open_sheet("edit", gid, PackedInt32Array())
