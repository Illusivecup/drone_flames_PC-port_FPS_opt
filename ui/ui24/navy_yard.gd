extends Control











const U = preload("res://ui/ui24/arm_kit.gd")
const MOD_ICON: Dictionary = {"gun": "icon_mod_gun", "ciws": "icon_mod_ciws", "sam": "icon_mod_sam", "ash": "icon_mod_ash", "vls": "icon_mod_vls", "art": "icon_mod_art"}
const HULL_ICON: Array[String] = ["icon_hull_light", "icon_hull_medium", "icon_hull_heavy"]
const HULL_SPR: Array[String] = ["ship_light", "ship_medium", "ship_heavy"]
const AMMO_NAME: Dictionary = {"asm": "ПКР", "cm": "КР", "sam": "ЗУР", "ciws": "ЗАК", "decoy": "ловушки", "art": "снар."}
const N_MAX: int = 5

var hud: Node
var gw: GameWorld
var base: Facility = null
var panel: PanelContainer
var vb: VBoxContainer
var head_sub: Label
var q_box: VBoxContainer
var q_sc: ScrollContainer
var q_rows: Array = []
var _q_sig: String = ""
var hull_btns: Array = []
var preview: Control
var slot_grid: GridContainer
var slot_btns: Array = []
var slot_head: Label
var n_lbl: Label
var tot_lbl: Label
var tot_flow: HFlowContainer
var _tot_sig: String = ""
var ammo_lbl: Label
var why_lbl: Label
var go_btn: Button
var minus_btn: Button
var plus_btn: Button
var pop: PanelContainer
var scrim: Control
var sc: ScrollContainer
var hull: int = 1
var mods: Array = []
var count: int = 1
var _t: float = 0.0
var _t2: float = 0.0
var _player: Object = null
const RAIL_W: float = 48.0
var rail_sc: ScrollContainer
var rail_vb: VBoxContainer
var rail_btns: Array = []
var _rail_sig: String = ""


func _nt(n: String) -> Texture2D:
	var a: Variant = gw.get("atlas_navy1")
	if a is SpriteAtlas and (a as SpriteAtlas).has(n):
		return (a as SpriteAtlas).region(n)
	return U.tex(n)


func _icon(n: String, px: float) -> TextureRect:
	var r: = TextureRect.new()
	r.texture = _nt(n)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func money_text(cost: Dictionary) -> String:
	return Economy.cost_text(cost) if cost.size() > 0 else Loc.t("бесплатно")


static func mmss(t: float) -> String:
	var s: int = maxi(0, ceili(t))
	return "%d:%02d" % [s / 60, s % 60]




func mount(h: Node) -> void :
	hud = h
	gw = h.gw
	name = "NavyYard"
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.root.add_child(self)
	process_priority = 102
	visible = false
	panel = PanelContainer.new()
	var psb: StyleBox = UiKit.sb("wb_window", 8, 6)
	psb.content_margin_bottom = 6.0 + h._safe_margins().y
	panel.add_theme_stylebox_override("panel", psb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	panel.add_child(vb)
	_build_head()
	q_box = VBoxContainer.new()
	q_box.add_theme_constant_override("separation", 3)
	q_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL


	q_sc = ScrollContainer.new()
	q_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	q_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	q_sc.add_child(q_box)
	vb.add_child(q_sc)
	var mid: = HBoxContainer.new()
	mid.add_theme_constant_override("separation", 5)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(mid)
	_build_rail(mid)
	sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(sc)
	var body: = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	_build_hulls(body)
	_build_slots(body)
	_build_footer()
	var tr: Control = h.tab_row
	var par: Node = tr.get_parent() if tr != null else h.holder
	par.add_child(panel)
	if tr != null and tr.get_parent() == par:
		par.move_child(panel, tr.get_index() + 1)


func _build_head() -> void :
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	vb.add_child(hr)
	hr.add_child(_icon("icon_navbase", 30))
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tv)
	tv.add_child(UiKit.lbl("Верфь", 17, UiKit.TITLE, 3, 4))
	head_sub = UiKit.lbl("", 9, UiKit.MUTED, 1, 2)
	head_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head_sub.max_lines_visible = 2
	head_sub.add_theme_constant_override("line_spacing", -2)
	tv.add_child(head_sub)
	var fb: Button = UiKit.big("", "stone", "", 44.0, 10)
	fb.custom_minimum_size = Vector2(64, 44)
	fb.tooltip_text = "Флот"
	var fv: = VBoxContainer.new()
	fv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fv.alignment = BoxContainer.ALIGNMENT_CENTER
	fv.add_theme_constant_override("separation", 0)
	fv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fb.add_child(fv)
	var fi: TextureRect = _icon("icon_fleet", 20)
	fi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fv.add_child(fi)
	var fl: Label = UiKit.lbl("ФЛОТ", 9, UiKit.TEXT, 2, 3)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fv.add_child(fl)
	fb.pressed.connect( func() -> void :
		if hud.has_method("open_navy_dock"):
			hud.open_navy_dock(null))
	hr.add_child(fb)
	var x: Button = UiKit.close_btn(44.0)
	x.pressed.connect(close)
	hr.add_child(x)




func _build_rail(parent: Control) -> void :
	rail_sc = ScrollContainer.new()
	rail_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	rail_sc.custom_minimum_size = Vector2(RAIL_W, 0)
	rail_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail_sc.visible = false
	parent.add_child(rail_sc)
	rail_vb = VBoxContainer.new()
	rail_vb.add_theme_constant_override("separation", 4)
	rail_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail_sc.add_child(rail_vb)



func yards() -> Array[Facility]:
	var out: Array[Facility] = []
	if gw.player == null or gw.get("navy") == null:
		return out
	out = gw.navy.bases_of(gw.player.id, false)
	out.sort_custom( func(a: Facility, b: Facility) -> bool: return a.id < b.id)
	return out


func yard_no(f: Facility) -> int:
	return yards().find(f) + 1


func _rail_item(f: Facility, no: int) -> Array:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(RAIL_W, 50)
	b.tooltip_text = Loc.t("Верфь %d") % no
	var cv: = VBoxContainer.new()
	cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", -1)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cv)
	var tl: Label = UiKit.lbl("ВЕРФЬ", 9, UiKit.MUTED, 1, 2)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(tl)
	var nl: Label = UiKit.lbl(str(no), 15, UiKit.TEXT, 3, 3)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(nl)
	var sl: Label = UiKit.lbl("", 9, UiKit.MUTED, 2, 2)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.clip_text = true
	cv.add_child(sl)
	b.pressed.connect( func() -> void : go_yard(f))
	UiKit.press_fx(b)
	return [b, f, nl, sl]



func _fit_narrow(narrow: bool) -> void :
	for h in mini(3, hull_btns.size()):
		var cv: Node = (hull_btns[h][1] as Control).get_parent()
		if cv == null or cv.get_child_count() < 3 or not (cv.get_child(2) is Label):
			continue
		var hs: Dictionary = Navy.hull_spec(h)
		var sl: Label = cv.get_child(2)
		sl.text = (Loc.t("%d ПР · %d сл") % [int(hs["hp"]), int(hs["slots"])]) if narrow else (Loc.t("%d ПР · %d уз · %d сл") % [int(hs["hp"]), roundi(float(hs["speed"])), int(hs["slots"])])
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for e: Array in slot_btns:
		for k in [2, 3]:
			if k < e.size() and e[k] is Label:
				(e[k] as Label).clip_text = true
				(e[k] as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS



func yard_state(f: Facility) -> Array:
	if not gw.mil.alive(f):
		return ["РАЗБИТА", UiKit.RED]
	var q: Array = gw.navy.queue_of(f)
	if q.is_empty():
		return ["пусто", UiKit.DIM]
	var left: int = 0
	for o: Dictionary in q:
		left += int(o["n"]) - int(o["done"])
	return ["%s ×%d" % [mmss(float((q[0] as Dictionary)["t"])), left], UiKit.GOLD]


func _refresh_rail() -> void :
	if rail_sc == null:
		return
	var ys: Array[Facility] = yards()
	var was: bool = rail_sc.visible
	rail_sc.visible = ys.size() >= 2
	if was != rail_sc.visible or _rail_sig == "":
		_fit_narrow(rail_sc.visible)
	if not rail_sc.visible:
		return
	var sig: String = ""
	for f: Facility in ys:
		sig += "%d;" % f.id
	if sig != _rail_sig:
		_rail_sig = sig
		for ch: Node in rail_vb.get_children():
			rail_vb.remove_child(ch)
			ch.queue_free()
		rail_btns.clear()
		for i in ys.size():
			var e: Array = _rail_item(ys[i], i + 1)
			rail_vb.add_child(e[0])
			rail_btns.append(e)
	for e: Array in rail_btns:
		var b: Button = e[0]
		var on: bool = e[1] == base
		for st: String in ["normal", "hover"]:
			b.add_theme_stylebox_override(st, UiKit.sb("wb_slot_active" if on else "wb_panel_dark", 2, 2))
		for st2: String in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st2, UiKit.sb("wb_slot_active", 2, 2))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var stt: Array = yard_state(e[1])
		(e[3] as Label).text = String(stt[0])
		(e[3] as Label).add_theme_color_override("font_color", stt[1])
		(e[2] as Label).add_theme_color_override("font_color", UiKit.GOLD if on else UiKit.TEXT)




func go_yard(f: Facility) -> void :
	if f == null or gw.player == null or f.country_id != gw.player.id:
		return
	if f != base:
		open(f)
	_refresh_rail()
	var m: Node = hud.main_node
	if m == null or m.get("cam") == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var top_y: float = maxf(110.0, float(hud.call("_win_top")) if hud.has_method("_win_top") else 110.0)
	var sheet_top: float = panel.global_position.y if panel.visible else vp.y * 0.5
	var vis_c: float = (top_y + maxf(top_y + 40.0, sheet_top)) * 0.5
	var w1: Vector2 = m.cam.screen_to_world(Vector2(vp.x * 0.5, vp.y * 0.5))
	var w2: Vector2 = m.cam.screen_to_world(Vector2(vp.x * 0.5, vis_c))
	m.set("follow", null)
	m.set("cam_lock", false)
	m.cam.center_on(f.center_px() + (w1 - w2))


func _section(parent: Control, text: String) -> Label:
	var l: Label = UiKit.lbl(text, 10, UiKit.TITLE, 2, 3)
	parent.add_child(l)
	return l


func _build_hulls(body: VBoxContainer) -> void :
	_section(body, "КОРПУС")
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	body.add_child(hb)
	for h in 3:
		var hs: Dictionary = Navy.hull_spec(h)
		var b: = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 100)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv: = VBoxContainer.new()
		cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cv.offset_left = 4
		cv.offset_right = -4
		cv.offset_top = 3
		cv.offset_bottom = -3
		cv.add_theme_constant_override("separation", 0)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cv)
		var spr: = Control.new()
		spr.custom_minimum_size = Vector2(0, 38)
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hk: int = h
		spr.draw.connect( func() -> void : _draw_ship(spr, hk, [], spr.size * 0.5 + Vector2(0, 2), 1.0))
		cv.add_child(spr)
		var nl: Label = UiKit.lbl(Loc.t(String(hs["name"])).to_upper(), 11, UiKit.TEXT, 2, 3)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(nl)
		var sl: Label = UiKit.lbl(Loc.t("%d ПР · %d уз · %d сл") % [int(hs["hp"]), roundi(float(hs["speed"])), int(hs["slots"])], 9, UiKit.MUTED, 1, 2)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.clip_text = true
		cv.add_child(sl)
		var cl: Label = UiKit.lbl("%d · %s" % [int((hs["cost"] as Dictionary).get("money", 0)), mmss(float(hs["time"]))], 9, UiKit.GOLD, 2, 2)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.clip_text = true
		cv.add_child(cl)
		b.pressed.connect( func() -> void : set_hull(hk))
		UiKit.press_fx(b)
		hb.add_child(b)
		hull_btns.append([b, spr])



func _draw_ship(ci: Control, h: int, fit: Array, at: Vector2, k: float) -> void :
	var a: Variant = gw.get("atlas_navy1")
	var key: String = HULL_SPR[clampi(h, 0, 2)]
	if not (a is SpriteAtlas) or not (a as SpriteAtlas).has(key):
		var t: Texture2D = _nt(HULL_ICON[clampi(h, 0, 2)])
		if t != null:
			ci.draw_texture_rect(t, Rect2(at - Vector2(24, 24) * k * 0.5, Vector2(24, 24) * k), false)
		return
	var at2: SpriteAtlas = a
	var dir: int = 0
	var inf: Dictionary = at2.info(key)
	var r: Rect2 = at2.rect(key, dir)
	var org: Vector2 = (at - Vector2(float(inf.get("ax", r.size.x * 0.5)), float(inf.get("ay", r.size.y * 0.5))) * k).round()
	if at2.has(key + "_shadow"):
		ci.draw_texture_rect(at2.region(key + "_shadow", dir), Rect2(org + Vector2(1, 2) * k, r.size * k), false, Color(0, 0, 0, 0.35))
	ci.draw_texture_rect(at2.region(key, dir), Rect2(org, r.size * k), false)
	var slots: Array = inf.get("slots", [])
	if slots.is_empty() or fit.is_empty():
		return
	var ds: Array = slots[dir] if dir < slots.size() else []
	var order: Array = []
	for i in mini(fit.size(), ds.size()):
		if String(fit[i]) != "":
			order.append(i)
	order.sort_custom( func(x: int, y: int) -> bool: return float(ds[x][1]) < float(ds[y][1]))
	for i2: int in order:
		var mk: String = "mod_" + String(fit[i2])
		if not at2.has(mk):
			continue
		var mi: Dictionary = at2.info(mk)
		var mr: Rect2 = at2.rect(mk, dir)
		var p: Vector2 = at + Vector2(float(ds[i2][0]), float(ds[i2][1])) * k - Vector2(float(mi.get("ax", 4)), float(mi.get("ay", 4))) * k
		ci.draw_texture_rect(at2.region(mk, dir), Rect2(p.round(), mr.size * k), false)


func _build_slots(body: VBoxContainer) -> void :
	slot_head = _section(body, "МОДУЛИ")
	preview = Control.new()
	preview.custom_minimum_size = Vector2(0, 72)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.clip_contents = true
	preview.draw.connect( func() -> void :
		var r: = Rect2(Vector2.ZERO, preview.size)
		preview.draw_rect(r, Color(0.09, 0.2, 0.27, 0.9))
		for i in 6:
			var y: float = 10.0 + float(i) * 11.0
			preview.draw_rect(Rect2(Vector2(8.0 + float((i * 37) % 60), y), Vector2(14, 1)), Color(0.35, 0.55, 0.65, 0.5))
			preview.draw_rect(Rect2(Vector2(preview.size.x - 70.0 + float((i * 23) % 40), y + 4.0), Vector2(10, 1)), Color(0.35, 0.55, 0.65, 0.5))
		_draw_ship(preview, hull, mods, preview.size * 0.5, 2.0 if hull < 2 else 1.0 + float(int(preview.size.y >= 110.0))))
	slot_grid = GridContainer.new()
	slot_grid.columns = 2
	slot_grid.add_theme_constant_override("h_separation", 5)
	slot_grid.add_theme_constant_override("v_separation", 5)
	body.add_child(slot_grid)
	body.add_child(preview)
	for i in 6:
		var b: = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hb: = HBoxContainer.new()
		hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = 6
		hb.offset_right = -6
		hb.add_theme_constant_override("separation", 6)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		var ic: TextureRect = _icon("icon_mod_gun", 24)
		hb.add_child(ic)
		var tv: = VBoxContainer.new()
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", -1)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tv)
		var nl: Label = UiKit.lbl("", 10, UiKit.TEXT, 2, 3)
		nl.clip_text = true
		tv.add_child(nl)
		var sl: Label = UiKit.lbl("", 9, UiKit.MUTED, 1, 2)
		sl.clip_text = true
		tv.add_child(sl)
		var tri: = Control.new()
		tri.custom_minimum_size = Vector2(8, 8)
		tri.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tri.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tri.draw.connect( func() -> void : U.draw_tri(tri, Vector2(4, 4), 3.0, UiKit.TEXT))
		hb.add_child(tri)
		var si: int = i
		b.pressed.connect( func() -> void : _slot_menu(si, b))
		UiKit.press_fx(b)
		slot_grid.add_child(b)
		slot_btns.append([b, ic, nl, sl])


func _build_footer() -> void :
	var fr: = HBoxContainer.new()
	fr.add_theme_constant_override("separation", 6)
	vb.add_child(fr)
	minus_btn = UiKit.big("−", "stone", "", 44.0, 18)
	minus_btn.custom_minimum_size = Vector2(44, 44)
	minus_btn.pressed.connect( func() -> void : set_count(count - 1))
	fr.add_child(minus_btn)
	n_lbl = UiKit.lbl("×1", 16, UiKit.TITLE, 3, 4)
	n_lbl.custom_minimum_size = Vector2(34, 0)
	n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fr.add_child(n_lbl)
	plus_btn = UiKit.big("+", "stone", "", 44.0, 18)
	plus_btn.custom_minimum_size = Vector2(44, 44)
	plus_btn.pressed.connect( func() -> void : set_count(count + 1))
	fr.add_child(plus_btn)
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", -1)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	fr.add_child(tv)
	tot_lbl = UiKit.lbl("", 10, UiKit.GOLD, 2, 3)
	tot_lbl.visible = false
	tv.add_child(tot_lbl)
	tot_flow = HFlowContainer.new()
	tot_flow.add_theme_constant_override("h_separation", 3)
	tot_flow.add_theme_constant_override("v_separation", 2)
	tot_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(tot_flow)
	ammo_lbl = UiKit.lbl("", 9, UiKit.MUTED, 1, 2)
	ammo_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ammo_lbl.custom_minimum_size.x = 1.0
	tv.add_child(ammo_lbl)
	why_lbl = UiKit.lbl("", 9, UiKit.RED, 2, 2)
	why_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why_lbl.custom_minimum_size.x = 1.0
	why_lbl.visible = false
	vb.add_child(why_lbl)
	go_btn = UiKit.big("В ПРОИЗВОДСТВО", "green", "", 46.0, 14)
	go_btn.pressed.connect(_order)
	vb.add_child(go_btn)



func _fill_total(tot: Dictionary, t: float) -> void :
	var sig: String = str(tot) + "|" + str(roundi(t))
	if sig == _tot_sig:
		return
	_tot_sig = sig
	for c: Node in tot_flow.get_children():
		c.queue_free()
	var items: Array = []
	if int(tot.get("money", 0)) > 0:
		items.append(["res_money", str(int(tot["money"])), UiKit.GOLD])
	for k: String in tot:
		if k != "money" and int(tot[k]) > 0:
			items.append([String(Economy.RES_ICONS.get(k, "res_metal")), str(int(tot[k])), UiKit.TEXT])
	items.append(["", mmss(t), UiKit.TEXT])
	for it: Array in items:
		var pc: = PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UiKit.sb("wb_pill", 4, 1))
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hb: = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 2)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_child(hb)
		if String(it[0]) != "":
			hb.add_child(_icon(String(it[0]), 12))
		else:
			var clk: = Control.new()
			clk.custom_minimum_size = Vector2(10, 12)
			clk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			clk.draw.connect( func() -> void :
				clk.draw_circle(Vector2(5, 6), 4.5, U.DARK)
				clk.draw_circle(Vector2(5, 6), 3.5, Color("e8dcc0"))
				clk.draw_line(Vector2(5, 6), Vector2(5, 3.5), U.DARK, 1.0)
				clk.draw_line(Vector2(5, 6), Vector2(7, 6), U.DARK, 1.0))
			hb.add_child(clk)
		var l: Label = UiKit.lbl(String(it[1]), 10, it[2], 2, 3)
		hb.add_child(l)
		tot_flow.add_child(pc)




func is_open() -> bool:
	return visible and panel.visible


func open(f: Facility) -> void :
	if gw.player == null or gw.player.eliminated or f == null or gw.get("navy") == null:
		return
	if base != f or _player != gw.player:
		base = f
		_player = gw.player
		set_hull(hull if mods.size() == int(Navy.hull_spec(hull)["slots"]) else 1, mods.is_empty())
	visible = true
	hud.ui24_open(self)
	panel.visible = true
	var vp: Vector2 = get_viewport_rect().size
	var tab_h: float = hud.tab_row.size.y if hud.tab_row != null else 52.0
	var small: bool = vp.y < 700.0
	panel.custom_minimum_size = Vector2(0, floorf(vp.y * (0.7 if small else 0.62)) - tab_h)
	for e: Array in hull_btns:
		(e[0] as Control).custom_minimum_size.y = 72.0 if small else 100.0
		(e[1] as Control).custom_minimum_size.y = 24.0 if small else 38.0
	preview.custom_minimum_size.y = 58.0 if vp.y < 700.0 else 78.0
	_q_sig = ""
	_refresh(true)
	_refresh_rail()
	panel.modulate.a = 0.0
	var tw: Tween = panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.12)
	UiKit.snd("ui_open")



func close() -> void :
	if not visible:
		return
	_close_pop()
	visible = false
	panel.visible = false
	hud.ui24_closed(self)


func scroll_area() -> ScrollContainer:
	if not is_open():
		return null
	var qv: Variant = q_sc
	if is_instance_valid(qv) and (qv as ScrollContainer).is_visible_in_tree() and (qv as ScrollContainer).get_global_rect().has_point(get_viewport().get_mouse_position()):
		return qv as ScrollContainer
	var sv: Variant = sc
	return (sv as ScrollContainer) if is_instance_valid(sv) else null


func blocked_rects() -> Array:
	return [panel.get_global_rect().grow(2.0)] if is_open() else []




func set_hull(h: int, reset_fit: bool = true) -> void :
	hull = clampi(h, 0, 2)
	if reset_fit or mods.size() != int(Navy.hull_spec(hull)["slots"]):
		mods = []
		var pre: Array = Navy.PRESETS[hull]
		for i in int(Navy.hull_spec(hull)["slots"]):
			mods.append(String(pre[i]) if i < pre.size() else "")
	_refresh(true)


func set_count(n: int) -> void :
	count = clampi(n, 1, N_MAX)
	_refresh(false)


func set_mod(slot: int, m: String) -> void :
	if slot < 0 or slot >= mods.size():
		return
	mods[slot] = m
	_refresh(true)


func fit() -> Array:
	var out: Array = []
	for m: Variant in mods:
		if String(m) != "":
			out.append(String(m))
	return out



func mod_why(slot: int, m: String) -> String:
	var mx: int = int(Navy.MODS[m]["max"][hull])
	if mx == 0:
		return "только на крейсере"
	var n: int = 0
	for i in mods.size():
		if i != slot and String(mods[i]) == m:
			n += 1
	return "" if n < mx else Loc.t("не больше %d") % mx


func _slot_menu(slot: int, anchor: Control) -> void :
	var items: Array = []
	for m: String in Navy.MOD_ORDER:
		var sp: Dictionary = Navy.MODS[m]
		var why: String = mod_why(slot, m)
		var am: String = ("%d %s · " % [int(sp["n"]), Loc.t(String(AMMO_NAME.get(String(sp["ammo"]), "")))]) if sp.has("ammo") else ""
		items.append({"icon": String(MOD_ICON[m]), "text": Loc.t(String(sp["name"])).to_upper(), "sub": why if why != "" else Loc.t("%s%s · +%d с") % [am, money_text(sp["cost"]), roundi(float(sp["time"]))], 
			"on": String(mods[slot]) == m, "off": why != "", "cb": func() -> void : set_mod(slot, m)})
	items.append({"icon": "icon_close", "text": "ПУСТО", "sub": "без модуля", "on": String(mods[slot]) == "", "cb": func() -> void : set_mod(slot, "")})
	_popover(anchor, Loc.t("СЛОТ %d · %s") % [slot + 1, String(Navy.hull_spec(hull)["name"]).to_upper()], items)


func _popover(anchor: Control, title: String, items: Array) -> void :
	_close_pop()
	scrim = Control.new()
	scrim.position = Vector2.ZERO
	scrim.size = get_viewport_rect().size
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect( func(e: InputEvent) -> void :
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_close_pop())
	add_child(scrim)
	pop = PanelContainer.new()
	pop.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 6, 6))
	pop.custom_minimum_size = Vector2(minf(250.0, get_viewport_rect().size.x - 12.0), 0)
	pop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pop)
	var pv: = VBoxContainer.new()
	pv.add_theme_constant_override("separation", 3)
	pop.add_child(pv)
	pv.add_child(UiKit.lbl(title, 10, UiKit.TITLE, 2, 3))
	for it: Dictionary in items:
		var on: bool = bool(it.get("on", false))
		var off: bool = bool(it.get("off", false))
		var b: Button = UiKit.big("", "green" if on else "stone", "", 44.0, 10)
		b.custom_minimum_size = Vector2(0, 44)
		b.disabled = off
		var hb: = HBoxContainer.new()
		hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = 8
		hb.offset_right = -8
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		var ic: TextureRect = _icon(String(it["icon"]), 22)
		ic.modulate = Color(1, 1, 1, 0.45) if off else Color.WHITE
		hb.add_child(ic)
		var tv: = VBoxContainer.new()
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", -1)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tv)
		tv.add_child(UiKit.lbl(String(it["text"]), 11, UiKit.DIM if off else UiKit.TEXT, 2, 3))
		var sl: Label = UiKit.lbl(String(it.get("sub", "")), 9, UiKit.RED if off else (UiKit.TEXT if on else UiKit.MUTED), 1, 2)
		sl.clip_text = true
		tv.add_child(sl)
		var cb: Callable = it["cb"]
		b.pressed.connect( func() -> void :
			_close_pop()
			cb.call())
		pv.add_child(b)
	var ar: Rect2 = anchor.get_global_rect()
	var vp: Vector2 = get_viewport_rect().size
	var sz: Vector2 = pop.get_combined_minimum_size()
	pop.size = sz
	var y: float = ar.position.y - sz.y - 6.0
	if y < 60.0:
		y = minf(ar.end.y + 6.0, vp.y - sz.y - 4.0)
	pop.position = Vector2(roundf(clampf(ar.get_center().x - sz.x * 0.5, 4.0, vp.x - sz.x - 4.0)), roundf(maxf(4.0, y)))
	UiKit.pop_in(pop, 0.9, 0.16)


func _close_pop() -> void :
	if pop != null and is_instance_valid(pop):
		pop.queue_free()
	if scrim != null and is_instance_valid(scrim):
		scrim.queue_free()
	pop = null
	scrim = null


func _order() -> void :
	if base == null or gw.get("navy") == null:
		return
	NetSession.sim("navy", "order", [base, hull, fit(), count], func(r: Variant) -> void :
		if not is_instance_valid(self):
			return
		var why: String = "Команда не выполнена" if r == null else String(r)
		if why != "":
			hud.show_toast(why)
			UiKit.snd("ui_error")
			return
		UiKit.snd("ui_build")
		_q_sig = ""
		_refresh(false))




func _refresh(fit_changed: bool) -> void :
	if base == null or gw.get("navy") == null:
		return
	var p: Country = gw.player
	for h in 3:
		var b: Button = hull_btns[h][0]
		var on: bool = h == hull
		for st: String in ["normal", "hover"]:
			b.add_theme_stylebox_override(st, UiKit.sb("wb_slot_active" if on else "wb_panel_dark", 4, 3))
		for st2: String in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st2, UiKit.sb("wb_slot_active", 4, 3))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		(hull_btns[h][1] as Control).queue_redraw()
	var n_slots: int = int(Navy.hull_spec(hull)["slots"])
	slot_head.text = Loc.t("МОДУЛИ · %d %s · %s") % [n_slots, Loc.n(n_slots, "слот", "слота", "слотов", "count"), String(Navy.hull_spec(hull)["name"]).to_lower()]
	for i in 6:
		var e: Array = slot_btns[i]
		var b2: Button = e[0]
		b2.visible = i < n_slots
		if i >= n_slots:
			continue
		var m: String = String(mods[i])
		(e[1] as TextureRect).texture = _nt(String(MOD_ICON.get(m, "icon_close")))
		(e[1] as TextureRect).modulate = Color.WHITE if m != "" else Color(1, 1, 1, 0.4)
		var sp: Dictionary = Navy.MODS.get(m, {})
		if is_instance_valid(e[2]):
			(e[2] as Label).text = ("%d · %s" % [i + 1, Loc.t(String(sp.get("name", ""))).to_upper()]) if m != "" else Loc.t("%d · ПУСТО") % (i + 1)
		if is_instance_valid(e[3]):
			(e[3] as Label).text = ("%d %s" % [int(sp["n"]), Loc.t(String(AMMO_NAME.get(String(sp["ammo"]), "")))]) if sp.has("ammo") else (Loc.t("авто-огонь 260 м") if m == "gun" else (Loc.t("тап — выбрать модуль") if m == "" else ""))
	if fit_changed:
		preview.queue_redraw()
	var f: Array = fit()
	var one: Dictionary = Navy.cost_of(hull, f)
	var tot: Dictionary = {}
	Navy._add(tot, one, count)
	n_lbl.text = "×%d" % count
	minus_btn.disabled = count <= 1
	plus_btn.disabled = count >= N_MAX
	var t1: float = Navy.build_time(hull, f)
	tot_lbl.text = "%s · %s" % [money_text(tot), mmss(t1 * float(count))]
	_fill_total(tot, t1 * float(count))
	var am: Dictionary = Navy.ammo_full(hull, f)
	var parts: PackedStringArray = []
	for k: String in ["asm", "cm", "sam", "decoy", "art"]:
		if int(am.get(k, 0)) > 0:
			parts.append("%s %d" % [AMMO_NAME[k], int(am[k])])
	ammo_lbl.text = (Loc.t("боекомплект: %s") % [" · ".join(parts)]) if not parts.is_empty() else Loc.t("без ракет")
	var why: String = gw.navy._order_why(base, hull, f, count) if gw.navy.has_method("_order_why") else Navy.fit_why(hull, f)
	if why == "" and f.is_empty():
		why = "Поставьте хотя бы один модуль"
	go_btn.disabled = why != ""
	why_lbl.text = why
	why_lbl.visible = why != ""
	_refresh_queue()
	_refresh_head()


func _refresh_head() -> void :
	var inf: Dictionary = gw.navy.base_info(base) if gw.navy.has_method("base_info") else {}
	var docked: int = (inf.get("docked", []) as Array).size()
	var sup: String = Loc.t("снабжение есть") if bool(inf.get("alive", true)) else Loc.t("база разрушена — верфь стоит")
	var no: int = yard_no(base) if yards().size() >= 2 else 0
	head_sub.text = (Loc.t("Верфь %d · ") % no if no > 0 else "") + Loc.t("%s · у причала %d · приписано %d") % [sup, docked, int(inf.get("home_ships", 0))]
	head_sub.add_theme_color_override("font_color", UiKit.MUTED if bool(inf.get("alive", true)) else UiKit.RED)


func _refresh_queue() -> void :
	var q: Array = gw.navy.queue_of(base)




	var sig: String = "q%d;" % q.size()
	for o: Dictionary in q:
		sig += "%d:%d:%d:%d;" % [int(o["hull"]), int(o["n"]), int(o["done"]), (o["mods"] as Array).size()]
	var stale: bool = q_rows.size() != q.size()
	if not stale:
		for i in q.size():
			if not is_same((q_rows[i] as Array)[0], q[i]):
				stale = true
				break
	if sig != _q_sig or stale:
		_q_sig = sig
		for ch: Node in q_box.get_children():
			q_box.remove_child(ch)
			ch.queue_free()
		q_rows.clear()
		if not q.is_empty():
			q_box.add_child(UiKit.lbl(Loc.t("ОЧЕРЕДЬ ВЕРФИ · %d") % q.size(), 10, UiKit.TITLE, 2, 3))
		for i in q.size():
			q_box.add_child(_q_row(q[i], i))
		_fit_queue(q.size())
	var up: bool = gw.mil.alive(base)
	for i in q_rows.size():
		var e: Array = q_rows[i]
		var o2: Dictionary = e[0]
		var tt: float = Navy.build_time(int(o2["hull"]), o2["mods"])

		var on: bool = up and i < Navy.SLIPWAYS
		var frac: float = 1.0 - clampf(float(o2["t"]) / maxf(1.0, tt), 0.0, 1.0) if on else 0.0
		(e[1] as Control).set_meta("v", frac)
		(e[1] as Control).queue_redraw()
		var nm: String = String(Navy.hull_spec(int(o2["hull"]))["name"])
		if is_instance_valid(e[2]):
			(e[2] as Label).text = (Loc.t("%s ×%d · готово %d") % [nm, int(o2["n"]), int(o2["done"])]) if int(o2["n"]) > 1 else nm
		if is_instance_valid(e[3]):
			(e[3] as Label).text = mmss(float(o2["t"])) if on else (Loc.t("стоит") if not up else Loc.t("ждёт"))



func _fit_queue(n: int) -> void :
	if q_sc == null:
		return
	q_sc.visible = n > 0
	var need: float = q_box.get_combined_minimum_size().y
	var vp: Vector2 = get_viewport_rect().size
	var cap: float = floorf(vp.y * (0.15 if vp.y < 700.0 else 0.2))
	q_sc.custom_minimum_size.y = minf(need, maxf(cap, 110.0))


func _q_row(o: Dictionary, i: int) -> Control:
	var pc: = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 6, 2))
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	pc.add_child(hb)
	hb.add_child(_icon(HULL_ICON[clampi(int(o["hull"]), 0, 2)], 24))
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(tv)
	var nl: Label = UiKit.lbl("", 10, UiKit.TEXT, 2, 3)
	nl.clip_text = true
	tv.add_child(nl)
	var bar: = Control.new()
	bar.custom_minimum_size = Vector2(0, 7)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect( func() -> void :
		var r: = Rect2(Vector2.ZERO, bar.size)
		bar.draw_rect(r.grow(1), UiKit.OUTLINE)
		bar.draw_rect(r, Color("2a2b22"))
		var w: float = roundf(r.size.x * float(bar.get_meta("v", 0.0)))
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(w, r.size.y)), UiKit.GOLD)
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(w, 2)), UiKit.GOLD.lightened(0.35)))
	tv.add_child(bar)
	var tl: Label = UiKit.lbl("", 10, UiKit.GOLD, 2, 3)
	tl.custom_minimum_size = Vector2(36, 0)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(tl)
	var x: Button = UiKit.close_btn(44.0)
	x.tooltip_text = "Отменить заказ (деньги за непостроенные вернутся)"
	x.pressed.connect( func() -> void :
		var qq: Array = gw.navy.queue_of(base)
		var k: int = -1
		for j in qq.size():
			if is_same(qq[j], o):
				k = j
				break
		if k < 0:
			hud.show_toast("Заказ уже выполнен: корабль в ФЛОТ › БЕЗ ГРУППЫ")
			_q_sig = ""
			_refresh_queue()
			return


		x.disabled = true
		NetSession.sim("navy", "cancel", [base, k, Navy.order_key(o)], func(r: Variant) -> void :
			if not is_instance_valid(self):
				return
			var why: String = "Команда не выполнена" if r == null else String(r)
			hud.show_toast(why if why != "" else "Заказ отменён: деньги за непостроенные вернулись")
			_q_sig = ""
			_refresh(false)))
	hb.add_child(x)
	q_rows.append([o, bar, nl, tl])
	return pc


func _process(delta: float) -> void :
	if not visible:
		return
	if gw.player == null or gw.player.eliminated or gw.player != _player or base == null or base.country_id != gw.player.id or bool(hud.ops_panel.visible):
		close()
		return
	if hud.panel != null and is_instance_valid(hud.panel):
		close()
		return
	for e: Variant in hud.cmd_btns:
		var cb: Control = (e as Array)[0]
		if cb != null and cb.visible:
			cb.visible = false
	_t -= delta
	if _t <= 0.0:
		_t = 0.25
		_refresh_queue()
		_refresh_rail()
	_t2 -= delta
	if _t2 <= 0.0 and not hud._finger_down():
		_t2 = 1.0
		_refresh(false)
