extends Control







const U = preload("res://ui/ui24/arm_kit.gd")
const M = preload("res://ui/ui24/army_store.gd")
const Row = preload("res://ui/ui24/army_row.gd")
const HT = preload("res://ui/ui24/hold_tip.gd")
const TOGGLES: Array = [
	["auto_orders", "АВТО-ПРИКАЗЫ", "cc_auto_orders", "Штаб сам даёт артудар, дым и госпиталь"], 
	["auto_strike", "АВТОУДАРЫ", "cc_auto_strike", "Ракеты по разведанным целям, 1 каждой в запасе"], 
	["auto_kab", "АВТО-КАБ", "cc_auto_kab", "Штурмовики сами бьют КАБ по фронту"], 
	["auto_drones", "АВТО-ДРОНЫ", "cc_auto_drones", "Дроны со склада летят по видимым целям"], 
	["smart", "УМНЫЕ БПЛА", "cc_smart", "Облетают зенитки; от ЗРК не уклоняются"], 
	["refill", "ПОПОЛНЕНИЕ", "", "Казармы восполняют потери всех армий"], 
]

var hud: Node
var gw: GameWorld
var dock: Node
var sheet: PanelContainer
var body: VBoxContainer
var sc: ScrollContainer
var refs: Dictionary = {}
var open_groups: Dictionary = {}
var help_on: bool = false

const TOGGLE_FX: Dictionary = {
	"auto_orders": ["штаб ведёт сам", "вручную"], 
	"auto_kab": ["бомбят у фронта", "вручную"], 
	"auto_drones": ["летят по целям", "на складе"], 
}
var auto_open: bool = true
var _sig: String = ""
var _dirty_t: float = 0.0
var _heads: Dictionary = {}
var _t: float = 0.0
var _str_v: float = 0.5
var _sweeps: Array = []


func mount(h: Node, d: Node) -> void :
	hud = h
	gw = h.gw
	dock = d
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.root.add_child(self)
	name = "CmdSheet"
	process_priority = 101
	visible = false


func is_open() -> bool:
	return sheet != null and is_instance_valid(sheet) and sheet.visible





var _cache_key: String = ""


func _cache_sig() -> String:
	return "%d|%s|%s|%d" % [gw.player.get_instance_id(), str(get_viewport_rect().size), str(hud._safe_margins()), Loc.gen]


func _show_cached() -> bool:
	if sheet == null or not is_instance_valid(sheet) or sheet.visible or _cache_key != _cache_sig():
		return false
	var sm: Dictionary = gw.ops.command_summary(gw.player.id)
	dock.store.scan(sm)
	if _structure(sm) != _sig:
		return false
	visible = true
	hud.ui24_open(self)
	sheet.visible = true
	refs.erase("dirty")
	_t = 1.0
	_tick(sm)
	var y: float = get_viewport_rect().size.y - sheet.size.y
	sheet.position = Vector2(0, y + 24)
	sheet.modulate.a = 0.0
	var tw: Tween = sheet.create_tween().set_parallel(true)
	tw.tween_property(sheet, "position:y", y, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(sheet, "modulate:a", 1.0, 0.18)
	UiKit.snd("ui_open")
	return true



func scroll_area() -> ScrollContainer:
	return sc if is_open() and sc != null and is_instance_valid(sc) else null



func scroll_areas() -> Array:
	return [sc] if is_open() and sc != null and is_instance_valid(sc) else []


func blocked_rects() -> Array:
	return [sheet.get_global_rect().grow(2.0)] if is_open() else []


func open() -> void :
	if gw.player == null or gw.player.eliminated or gw.ops == null:
		return
	var was_open: bool = is_open()
	if not was_open and _show_cached():
		return
	_drop_sheet()
	visible = true
	hud.ui24_open(self)
	_heads.clear()
	_cache_key = _cache_sig()
	var vp: Vector2 = get_viewport_rect().size
	var war: bool = not gw.player.at_war.is_empty()
	var sm: Dictionary = gw.ops.command_summary(gw.player.id)
	dock.store.scan(sm)
	_sig = _structure(sm)
	refs = {}
	_sweeps.clear()
	sheet = PanelContainer.new()
	var ssb: StyleBox = UiKit.sb("wb_window", 10, 8)
	ssb.content_margin_bottom = 8.0 + hud._safe_margins().y
	sheet.add_theme_stylebox_override("panel", ssb)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	sheet.add_child(vb)

	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	vb.add_child(hr)
	hr.add_child(U.icon("icon_op_operation", 28))
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tv)
	tv.add_child(UiKit.lbl("Штаб", 18, UiKit.TITLE, 3, 4))
	var armies: Array = sm.get("armies", [])
	var troops: int = 0
	for a: Dictionary in armies:
		troops += int(dock.store.view(a)["n"])
	refs["sub"] = UiKit.lbl("%s · %s" % [(Loc.n(armies.size(), "%d армия", "%d армии", "%d армий") % (armies.size())), (Loc.n(troops, "%d боец", "%d бойца", "%d бойцов") % (troops))], 9, UiKit.MUTED, 1, 2)
	tv.add_child(refs["sub"])
	var x: Button = UiKit.close_btn(44.0)
	x.pressed.connect(close)
	hr.add_child(x)
	sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sc)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	_war_strip(sm, war)
	if war:
		_threats(sm)
	_toggles(sm)
	if war:
		_orders(sm)
	_armies(sm)
	_info(sm)

	var w: float = vp.x
	sheet.custom_minimum_size.x = w
	var inner_h: float = body.get_combined_minimum_size().y
	var h: float = minf(inner_h + 44.0 + 6.0 + 16.0 + hud._safe_margins().y, floorf(vp.y * 0.62))
	sc.custom_minimum_size.y = h - 44.0 - 6.0 - 16.0 - hud._safe_margins().y
	sheet.size = Vector2(w, h)
	var y: float = vp.y - h
	if was_open:
		sheet.position = Vector2(0, y)
		return
	sheet.position = Vector2(0, y + 24)
	sheet.modulate.a = 0.0
	var tw: Tween = sheet.create_tween().set_parallel(true)
	tw.tween_property(sheet, "position:y", y, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(sheet, "modulate:a", 1.0, 0.18)
	UiKit.snd("ui_open")


func _drop_sheet() -> void :
	if sheet != null and is_instance_valid(sheet):
		sheet.queue_free()
	sheet = null
	refs = {}
	_sweeps.clear()



func close() -> void :
	var was: bool = is_open()
	if sheet != null and is_instance_valid(sheet):
		sheet.visible = false
	visible = false
	dock.cover_y = INF
	hud.ui24_closed(self)
	if was:
		UiKit.snd("ui_close")



func open_or_refresh() -> void :
	if is_open():
		_refresh_toggles()
		_tick()
	else:
		open()



func _structure(sm: Dictionary) -> String:
	var s: String = "%s|%d|" % [str(gw.player.at_war.keys()), (sm.get("orders", []) as Array).size()]
	for g: Dictionary in dock.store.groups:
		s += "%d:%s:%d:%s:%d;" % [int(g["id"]), String(g["name"]), int(g["color"]), String(g["emblem"]), (g["fids"] as PackedInt32Array).size()]
	return s + str(dock.store.armies(sm, -2).is_empty())


func _section(text: String, right: Control = null) -> void :
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	body.add_child(hb)
	var l: Label = UiKit.lbl(text, 10, UiKit.TITLE, 2, 3)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.fit_lbl(l, [10, 9])
	hb.add_child(l)
	if right != null:
		hb.add_child(right)




func _war_strip(sm: Dictionary, war: bool) -> void :
	var pc: = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 6))
	body.add_child(pc)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	pc.add_child(vb)
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 6)
	vb.add_child(hr)
	hr.add_child(U.icon("icon_rel_war" if war else "icon_rel_peace", 20))
	if not war:
		var pl: Label = UiKit.lbl("МИР · войн нет", 12, UiKit.GREEN, 2, 3)
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hr.add_child(pl)
		var ph: Label = UiKit.lbl("Приказы командира и угрозы появятся с началом войны", 9, UiKit.MUTED, 1, 2)
		ph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ph.custom_minimum_size.x = 1.0
		vb.add_child(ph)
		return
	var wl: Label = UiKit.lbl("ВОЙНА:", 12, UiKit.RED, 2, 3)
	hr.add_child(wl)


	var foes: Array = []
	for id: Variant in gw.player.at_war.keys():
		var c2: Country = gw.country_by_id(int(id))
		if c2 != null and not c2.eliminated:
			foes.append(c2)
	var room: float = get_viewport_rect().size.x - 20.0 - 16.0 - 20.0 - 6.0 - UiKit.f_black.get_string_size("ВОЙНА:", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x - 6.0 - 4.0
	var shown: int = 0
	for i: int in foes.size():
		var c3: Country = foes[i]
		var w: float = 24.0 + 6.0 + UiKit.f_black.get_string_size(c3.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 6.0
		var more: float = 34.0 if i < foes.size() - 1 else 0.0
		if shown > 0 and w + more > room:
			break
		hr.add_child(hud._flag(c3))
		var nl: Label = UiKit.lbl(Loc.name(c3.name), 12, UiKit.TEXT, 2, 3)
		if shown == 0:
			nl.clip_text = true
			nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			nl.custom_minimum_size.x = minf(w - 36.0, maxf(20.0, room - 30.0 - more))
		hr.add_child(nl)
		room -= w
		shown += 1
	if shown < foes.size():
		hr.add_child(UiKit.lbl("+%d" % (foes.size() - shown), 12, UiKit.RED, 2, 3))
	var sp: = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(sp)
	var sg: Dictionary = gw.ops.strength(gw.player.id, -1)
	var ratio: float = float(sg.get("ratio", 0.5))
	var sr: = HBoxContainer.new()
	sr.add_theme_constant_override("separation", 6)
	vb.add_child(sr)
	sr.add_child(U.icon("icon_strength", 16))
	var lo: Label = UiKit.lbl(Loc.t("НАШИ %d%%") % roundi(ratio * 100.0), 10, UiKit.GREEN, 2, 3)
	sr.add_child(lo)
	var bar: = Control.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.draw.connect( func() -> void :
		var r: = Rect2(Vector2.ZERO, bar.size)
		bar.draw_rect(r.grow(1), UiKit.OUTLINE)
		var gx: float = roundf(r.size.x * _str_v)
		bar.draw_rect(Rect2(0, 0, gx, r.size.y), Color("8fdc4f"))
		bar.draw_rect(Rect2(gx, 0, r.size.x - gx, r.size.y), Color("e8553f"))
		bar.draw_rect(Rect2(0, 0, gx, 3), Color("c3f08f"))
		bar.draw_rect(Rect2(gx, 0, r.size.x - gx, 3), Color("ff8e78"))
		bar.draw_rect(Rect2(roundf(r.size.x * 0.5) - 1, -3, 2, r.size.y + 6), UiKit.TEXT))
	sr.add_child(bar)
	var le: Label = UiKit.lbl(Loc.t("%d%% ВРАГ") % roundi((1.0 - ratio) * 100.0), 10, UiKit.RED, 2, 3)
	sr.add_child(le)
	var lab: Label = UiKit.lbl("%s · %s" % [String(sg.get("label", "")), Loc.t("на фронте") if bool(sg.get("front", false)) else Loc.t("все войска")], 9, UiKit.GREEN if ratio >= 0.5 else UiKit.RED, 2, 2)
	vb.add_child(lab)
	refs["str"] = [bar, lo, le, lab]
	var tw: Tween = bar.create_tween()
	_str_v = 0.5
	tw.tween_method( func(v: float) -> void :
		_str_v = v
		bar.queue_redraw(), 0.5, ratio, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _threats(sm: Dictionary) -> void :
	var rows: Array = []
	for i in 2:
		var hb: = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		body.add_child(hb)
		var l: Label = UiKit.lbl("", 10, UiKit.RED, 2, 2)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(U.icon("icon_scarce", 18))
		hb.add_child(l)
		var b: Button = UiKit.slot("icon_goto_map", false, 44.0)
		b.pressed.connect( func() -> void :
			var p: Vector2 = b.get_meta("pos", Vector2.INF)
			if p.is_finite():
				close()
				hud.main_node.cam_lock = false
				hud.main_node.cam.center_on(p))
		hb.add_child(b)
		rows.append([hb, l, b])
	refs["threats"] = rows
	_fill_threats(sm)


func _fill_threats(sm: Dictionary) -> void :
	var th: Array = sm.get("threats", [])
	var rows: Array = refs.get("threats", [])
	for i in rows.size():
		var e: Array = rows[i]
		var on: bool = i < th.size()
		(e[0] as Control).visible = on
		if on:
			(e[1] as Label).text = String((th[i] as Dictionary).get("text", ""))
			(e[2] as Button).set_meta("pos", (th[i] as Dictionary).get("pos", Vector2.INF))




func _orders(sm: Dictionary) -> void :
	_section("ПРИКАЗЫ КОМАНДИРА")
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	body.add_child(hb)
	for o: Dictionary in sm.get("orders", []):
		var k: int = int(o["kind"])
		var b: Button = UiKit.big("", "stone", "", 56.0, 10)
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(b)
		var row: = HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 6
		row.offset_right = -4
		row.add_theme_constant_override("separation", 5)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var ib: = Control.new()
		ib.custom_minimum_size = Vector2(34, 34)
		ib.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ib)
		var ic: TextureRect = U.icon(String(o.get("icon", "")), 30)
		ic.position = Vector2(2, 2)
		ib.add_child(ic)
		var sw: = Control.new()
		sw.set_anchors_preset(Control.PRESET_FULL_RECT)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ib.add_child(sw)
		sw.draw.connect( func() -> void : _draw_sweep(sw, k))
		_sweeps.append([sw, k])
		var tv: = VBoxContainer.new()
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", 0)
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tv)
		var nm: String = String(o.get("name", ""))
		if nm == "ГОСПИТАЛЬ":
			nm = "ГОСПИТ."
		tv.add_child(UiKit.lbl(nm, 10, UiKit.TEXT, 2, 3))
		var st: Label = UiKit.lbl("", 9, UiKit.GREEN, 2, 2)
		tv.add_child(st)
		refs["ord_%d" % k] = [b, st, ic]

		b.pressed.connect( func() -> void :
			if gw.ops.cooldown_left(gw.player.id, k) <= 0.0:
				close()
			hud.action.emit("order_%d" % k))
	_tick_orders()


func _cd(k: int) -> Array:
	var left: float = gw.ops.cooldown_left(gw.player.id, k)
	return [left, float(Operations.ORDERS[k]["cd"])]


func _draw_sweep(c: Control, k: int) -> void :
	var cd: Array = _cd(k)
	var left: float = float(cd[0])
	if left <= 0.0:
		return
	var frac: float = clampf(left / maxf(1.0, float(cd[1])), 0.0, 1.0)
	var ctr: Vector2 = c.size * 0.5
	var r: float = c.size.x * 0.5
	var pts: = PackedVector2Array([ctr])
	var a0: float = - PI * 0.5
	var n: int = 24
	for i in n + 1:
		var a: float = a0 + TAU * (1.0 - frac) + TAU * frac * float(i) / float(n)
		pts.append(ctr + Vector2(cos(a), sin(a)) * (r + 1.0))
	c.draw_colored_polygon(pts, Color(0.05, 0.04, 0.03, 0.62))
	c.draw_arc(ctr, r - 1.0, a0, a0 + TAU * (1.0 - frac), 24, U.AMBER, 2.0)


func _tick_orders() -> void :
	for k in 3:
		if not refs.has("ord_%d" % k):
			continue
		var e: Array = refs["ord_%d" % k]
		var cd: Array = _cd(k)
		var left: float = float(cd[0])
		var st: Label = e[1]
		st.text = (Loc.t("через %d с") % ceili(left)) if left > 0.0 else Loc.t("ГОТОВ")
		st.add_theme_color_override("font_color", UiKit.GOLD if left > 0.0 else UiKit.GREEN)
		(e[2] as TextureRect).modulate = Color(0.75, 0.75, 0.75) if left > 0.0 else Color.WHITE





func _armies(sm: Dictionary) -> void :
	_section("АРМИИ ПО ГРУППАМ · тап — открыть в «Армиях»")
	var store = dock.store
	var gids: Array = []
	for g: Dictionary in store.groups:
		gids.append(int(g["id"]))
	if not store.armies(sm, -2).is_empty():
		gids.append(-2)
	var list: = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	body.add_child(list)
	refs["alist"] = list
	for gid: int in gids:
		var rows: Array = store.armies(sm, gid)
		list.add_child(_group_head(gid, rows, store.totals(rows)))


func _group_head(gid: int, rows: Array, t: Dictionary) -> Button:
	var g: Dictionary = dock.store.by_id(gid) if gid >= 0 else {}
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	var on: bool = false
	var s: StyleBox = UiKit.sb("wb_btn_stone", 6, 3)
	var sp: StyleBox = UiKit.sb("wb_btn_stone_p", 6, 3)
	for st: String in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, s)
	for st2: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st2, sp)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size.y = 48
	var hb: = HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 7
	hb.offset_right = -8
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	if not g.is_empty():
		hb.add_child(U.emblem_rect(String(g["emblem"]), U.color(int(g["color"])), 26, true))
	else:
		hb.add_child(U.icon("icon_infantry", 26))
	var tv: = VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", -1)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tv)
	tv.add_child(UiKit.lbl(Loc.gtag(gid, String(g["name"])) if not g.is_empty() else Loc.t("БЕЗ ГРУППЫ"), 11, UiKit.TEXT, 2, 3))
	var subl: Label = UiKit.lbl("", 9, UiKit.MUTED, 1, 2)
	tv.add_child(subl)
	var pills: Array = []
	for k: String in ["fight", "move", "idle"]:
		var ph: = HBoxContainer.new()
		ph.add_theme_constant_override("separation", 1)
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ph)
		ph.add_child(U.icon(String(M.ACT_ICON[k]), 16))
		var nl: Label = UiKit.lbl("0", 11, UiKit.RED if k == "fight" else UiKit.TEXT, 2, 3)
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ph.add_child(nl)
		pills.append([ph, nl, k])
	_heads[gid] = [subl, pills]
	_fill_head(gid, rows, t)
	var tri: = Control.new()
	tri.custom_minimum_size = Vector2(10, 10)
	tri.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tri.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tri.rotation = - PI * 0.5
	tri.pivot_offset = Vector2(5, 5)
	tri.draw.connect( func() -> void : U.draw_tri(tri, Vector2(5, 5), 4.0, UiKit.TEXT))
	hb.add_child(tri)
	b.pressed.connect( func() -> void :
		close()
		dock.open_dock(gid))
	UiKit.press_fx(b)
	return b


func _fill_head(gid: int, rows: Array, t: Dictionary) -> void :
	var e: Array = _heads.get(gid, [])
	if e.is_empty():
		return
	if is_instance_valid(e[0]):
		(e[0] as Label).text = Loc.t("%s · %d бойц. · %d%%") % [(Loc.n(rows.size(), "%d армия", "%d армии", "%d армий") % (rows.size())), int(t["troops"]), roundi(float(t["hp"]) * 100.0)]
	var cnt: Dictionary = t["counts"]
	for pe: Array in e[1]:
		var n: int = int(cnt[String(pe[2])])
		(pe[0] as Control).visible = n > 0
		(pe[1] as Label).text = str(n)



func _tick(sm_in: Dictionary = {}) -> void :
	if not is_open() or gw.player == null:
		return
	var sm: Dictionary = sm_in
	if sm.is_empty():
		sm = gw.ops.command_summary(gw.player.id)
		dock.store.scan(sm)
	if _structure(sm) != _sig:
		refs["dirty"] = true
	var armies: Array = sm.get("armies", [])
	var troops: int = 0
	for a: Dictionary in armies:
		troops += int(a["n"])
	if refs.has("sub"):
		if is_instance_valid(refs["sub"]):
			(refs["sub"] as Label).text = "%s · %s" % [(Loc.n(armies.size(), "%d армия", "%d армии", "%d армий") % (armies.size())), (Loc.n(troops, "%d боец", "%d бойца", "%d бойцов") % (troops))]
	if refs.has("str"):
		var sg: Dictionary = gw.ops.strength(gw.player.id, -1)
		var ratio: float = float(sg.get("ratio", 0.5))
		var e: Array = refs["str"]
		_str_v = ratio
		(e[0] as Control).queue_redraw()
		if is_instance_valid(e[1]):
			(e[1] as Label).text = Loc.t("НАШИ %d%%") % roundi(ratio * 100.0)
		if is_instance_valid(e[2]):
			(e[2] as Label).text = Loc.t("%d%% ВРАГ") % roundi((1.0 - ratio) * 100.0)
		if is_instance_valid(e[3]):
			(e[3] as Label).text = "%s · %s" % [String(sg.get("label", "")), Loc.t("на фронте") if bool(sg.get("front", false)) else Loc.t("все войска")]
		(e[3] as Label).add_theme_color_override("font_color", UiKit.GREEN if ratio >= 0.5 else UiKit.RED)
	_fill_threats(sm)
	_tick_orders()
	for gid: int in _heads:
		var rows: Array = dock.store.armies(sm, gid)
		_fill_head(gid, rows, dock.store.totals(rows))
	_refresh_toggles()



func _refill_state() -> Array:
	var on: int = 0
	var n: int = 0
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.BARRACKS and f.country_id == gw.player.id and gw.mil.alive(f):
			n += 1
			if f.auto_refill:
				on += 1
	return [on, n]



func _toggle_refill() -> void :
	var rf: Array = _refill_state()
	if int(rf[1]) == 0:
		hud.show_toast("Нет казарм")
		return
	var want: bool = int(rf[0]) < int(rf[1])
	NetSession.sim("", "cmd_refill_all", [gw.player, want], func(_r: Variant) -> void :
		gw.message.emit(Loc.t("Пополнение армий: %s") % (Loc.t("включено для всех") if want else Loc.t("выключено"))))


func _rebuild_keep_scroll() -> void :
	var y: int = sc.scroll_vertical if sc != null else 0
	open()
	if not is_open():
		return
	sheet.modulate.a = 1.0
	sc.set_deferred("scroll_vertical", y)




func _toggle_state(key: String, sm: Dictionary) -> Array:
	match key:
		"auto_strike":
			var v: int = int(sm.get("auto_strike", 0))
			return [v > 0, String(Operations.AutoCmd.STRIKE_NAMES[v]) if v > 0 else Loc.t("ВЫКЛ")]
		"smart":
			var on: bool = gw.mil.has_method("smart_of") and bool(gw.mil.smart_of(gw.player.id))
			return [on, Loc.t("ВКЛ — облетают ПВО") if on else Loc.t("ВЫКЛ — напрямую")]
		"refill":
			var rf: Array = _refill_state()
			return [int(rf[0]) > 0, Loc.t("ВЫКЛ") if int(rf[0]) == 0 else (Loc.t("ВСЕ АРМИИ") if int(rf[0]) == int(rf[1]) else Loc.t("%d ИЗ %d") % [int(rf[0]), int(rf[1])])]
	var b: bool = bool(sm.get(key, false))
	var fx: Array = (TOGGLE_FX.get(key, ["", ""]) as Array)
	return [b, (Loc.t("ВКЛ") if b else Loc.t("ВЫКЛ")) + ((" — " + Loc.t(String(fx[0 if b else 1]))) if String(fx[0 if b else 1]) != "" else "")]


func _toggles(sm: Dictionary) -> void :
	var n_on: int = 0
	for t0: Array in TOGGLES:
		if bool(_toggle_state(String(t0[0]), sm)[0]):
			n_on += 1
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 6)
	body.add_child(hr)
	var hb0: = Button.new()
	hb0.focus_mode = Control.FOCUS_NONE
	hb0.custom_minimum_size = Vector2(0, 44)
	hb0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st0: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		hb0.add_theme_stylebox_override(st0, StyleBoxEmpty.new())
	hr.add_child(hb0)
	var hh: = HBoxContainer.new()
	hh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hh.add_theme_constant_override("separation", 6)
	hh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb0.add_child(hh)
	var tri: = Control.new()
	tri.custom_minimum_size = Vector2(10, 10)
	tri.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tri.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tri.pivot_offset = Vector2(5, 5)
	tri.rotation = 0.0 if auto_open else - PI * 0.5
	tri.draw.connect( func() -> void : U.draw_tri(tri, Vector2(5, 5), 4.0, UiKit.TITLE))
	hh.add_child(tri)
	var al: Label = UiKit.lbl("АВТОМАТИКА", 10, UiKit.TITLE, 2, 3)
	al.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hh.add_child(al)
	var cl: Label = UiKit.lbl(Loc.t("вкл %d из %d") % [n_on, TOGGLES.size()], 9, UiKit.GREEN if n_on > 0 else UiKit.MUTED, 2, 2)
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hh.add_child(cl)
	hb0.pressed.connect( func() -> void :
		auto_open = not auto_open
		_rebuild_keep_scroll())
	var ib: Button = UiKit.big("i", "gold" if help_on else "stone", "", 44.0, 14)
	ib.custom_minimum_size = Vector2(44, 44)
	HT.key(ib, "cmd_i", Loc.t("ВКЛ") if help_on else Loc.t("ВЫКЛ"))
	ib.pressed.connect( func() -> void :
		help_on = not help_on
		auto_open = true
		_rebuild_keep_scroll())
	hr.add_child(ib)
	if not auto_open:
		return
	var grid: = GridContainer.new()
	grid.columns = 1 if help_on else 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	for t: Array in TOGGLES:
		var key: String = String(t[0])
		var stt: Array = _toggle_state(key, sm)
		var on: bool = bool(stt[0])
		var b: = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 58 if help_on else 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var s: StyleBox = UiKit.sb("wb_panel_dark", 6, 3)
		for st: String in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, s)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var hb: = HBoxContainer.new()
		hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = 7
		hb.offset_right = -6
		hb.add_theme_constant_override("separation", 4)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		var tv: = VBoxContainer.new()
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", 0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tv)
		var nm: Label = UiKit.lbl(String(t[1]), 10, UiKit.TEXT, 2, 3)
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tv.add_child(nm)
		var sl: Label = UiKit.lbl(String(stt[1]), 9, UiKit.GREEN if on else UiKit.DIM, 2, 2)
		sl.clip_text = true
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tv.add_child(sl)
		if help_on:
			var hl: Label = UiKit.lbl(String(t[3]), 9, UiKit.MUTED, 1, 2)
			hl.clip_text = true
			tv.add_child(hl)
			b.custom_minimum_size.y = 54
		var tg: TextureRect = U.icon("wb_toggle_on" if on else "wb_toggle_off", 40)
		tg.custom_minimum_size = Vector2(40, 22)
		hb.add_child(tg)
		var act: String = String(t[2])
		var tname: String = String(t[1])
		var tline: String = String(t[3])
		HT.tip(b, func() -> String:
			var s9: Array = _toggle_state(key, gw.ops.command_summary(gw.player.id))
			return "%s: %s — %s" % [tname, String(s9[1]).get_slice(" — ", 0), tline])
		b.pressed.connect( func() -> void :
			if act != "":
				hud.action.emit(act)
			else:
				_toggle_refill()
			tg.pivot_offset = tg.size * 0.5
			var tw: Tween = tg.create_tween()
			tw.tween_property(tg, "scale", Vector2(1.12, 1.12), 0.07)
			tw.tween_property(tg, "scale", Vector2.ONE, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			get_tree().create_timer(0.15).timeout.connect(_refresh_toggles))
		grid.add_child(b)
		refs["tg_" + key] = [tg, sl]


func _refresh_toggles() -> void :
	if not is_open():
		return
	var sm: Dictionary = gw.ops.command_summary(gw.player.id)
	for t: Array in TOGGLES:
		var key: String = String(t[0])
		if not refs.has("tg_" + key):
			continue
		var stt: Array = _toggle_state(key, sm)
		var e: Array = refs["tg_" + key]
		U.set_tex_rect(e[0], "wb_toggle_on" if bool(stt[0]) else "wb_toggle_off")
		(e[1] as Label).text = String(stt[1])
		(e[1] as Label).add_theme_color_override("font_color", UiKit.GREEN if bool(stt[0]) else UiKit.DIM)


func _info(sm: Dictionary) -> void :
	var fl: = HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 4)
	body.add_child(fl)
	for mm: Dictionary in sm.get("missiles", []):
		if int(mm.get("stock", 0)) <= 0 and int(mm.get("ready", 0)) <= 0:
			continue
		fl.add_child(_pill(String(mm.get("icon", "")), Loc.t("%s: %d · готово %d") % [String(mm.get("name", "")).left(1) + String(mm.get("name", "")).substr(1).to_lower(), int(mm.get("stock", 0)), int(mm.get("ready", 0))]))
	var dr: Dictionary = sm.get("drones", {})
	fl.add_child(_pill("icon_fpv", Loc.t("дроны: склад %d · в воздухе %d") % [int(dr.get("stock", 0)), int(dr.get("in_air", 0))]))


func _pill(icon_n: String, text: String) -> PanelContainer:
	var pc: = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.sb("wb_pill", 5, 2))
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	pc.add_child(hb)
	hb.add_child(U.icon(icon_n, 14))
	var l: Label = UiKit.lbl(text, 9, UiKit.TEXT, 2, 2)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(l)
	return pc




func _process(delta: float) -> void :
	if not is_open():
		return
	if gw.player == null or gw.player.eliminated:
		close()
		return
	if hud.panel != null and is_instance_valid(hud.panel):
		close()
		return
	dock.cover_y = sheet.position.y

	for e0: Array in hud.cmd_btns:
		(e0[0] as Button).visible = false
	if hud.ore_btn != null:
		hud.ore_btn.visible = false
		hud.ore_panel.visible = false
	if hud.plan_panel != null:
		hud.plan_panel.visible = false
	for e: Array in _sweeps:
		if is_instance_valid(e[0]):
			(e[0] as Control).queue_redraw()
	_dirty_t -= delta
	if bool(refs.get("dirty", false)) and _dirty_t <= 0.0 and not hud._finger_down():
		_dirty_t = 1.5
		_rebuild_keep_scroll()
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	_tick()
