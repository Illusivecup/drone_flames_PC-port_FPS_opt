extends PanelContainer








signal closed

const C_GOLD: = Color("ffd75e")
const PeaceConfS = preload("res://game/peace_conf.gd")
const C_EMPTY: = Color("3a3b33")
const C_WATER: = Color("1d3a52")
const C_LAND: = Color("5b6446")
const PAD: float = 8.0
const SEL_H: float = 77.0

var m: Node
var hud: Node
var gw: GameWorld
var dp: Diplomacy
var pc
var conf_id: int = -1
var def_id: int = -1
var me: int = 0
var vp: Vector2 = Vector2(360, 780)
var max_h: float = 560.0
var col: VBoxContainer
var scroll: ScrollContainer
var inner: VBoxContainer
var _cities: Array = []
var _tok_col: Array = []
var _bars: Dictionary = {}
var _rows: Dictionary = {}
var _sel: int = -1
var _shown: Dictionary = {}
var _timer_l: Label
var _pts_l: Label
var _sum_l: Label
var _confirm_b: Button
var _closing: bool = false
var _done: bool = false
var _tick: float = 0.0
var _fc: Dictionary = {}
var _fc_spent: Dictionary = {}
var rebuilds: int = 0




static func open_for(main: Node, conf_id: int) -> bool:
	var gw0: GameWorld = main.world
	if gw0 == null or gw0.diplo == null or gw0.diplo.conf == null or not gw0.diplo.conf.has_conf(conf_id):
		return false
	var h: Node = main.hud
	var scr: Script = load("res://ui/ui24/conference_sheet.gd") as Script
	var sh: PanelContainer = scr.new() as PanelContainer
	sh.call("setup", main, conf_id)
	h.close_panel()
	h.holder.add_child(sh)
	h.holder.move_child(sh, h.tab_row.get_index() + 1)
	h.panel = sh
	h.panel_kind = "conference"
	sh.call("fit", h.root.get_viewport_rect().size, h.tab_row.size.y + 6.0)
	h.ui24_open(sh)
	if h.dip_chip != null:
		h.dip_chip.visible = false
	sh.call("open_anim")
	return true


func setup(main: Node, cid: int) -> void :
	m = main
	hud = m.hud
	gw = m.world
	dp = gw.diplo
	pc = dp.conf
	conf_id = cid
	me = gw.player.id
	name = "ConferenceSheet"
	var cf: Dictionary = pc.get_conf(cid) if pc != null else {}
	def_id = int(cf.get("def", -1))
	if not cf.is_empty():
		for t: Dictionary in _sorted_terr(cf):
			_cities.append(int(t["city"]))
	tree_exiting.connect( func() -> void :
		_map_mode(false)
		if pc != null and pc.hold_id == conf_id:
			pc.hold_id = -1
		if hud != null and is_instance_valid(hud):
			hud.ui24_closed(self))
	if pc != null and not cf.is_empty():
		pc.hold_id = cid
	UiKit.ensure()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var st: StyleBox = UiKit.sb("wb_window", PAD, 6)
	st.expand_margin_left = 14.0
	st.expand_margin_right = 14.0
	st.expand_margin_bottom = 14.0
	st.content_margin_left = PAD
	st.content_margin_right = PAD
	st.content_margin_top = 10.0
	st.content_margin_bottom = 10.0 + float(hud._safe_margins().y)
	add_theme_stylebox_override("panel", st)
	col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	add_child(col)




func fit(viewport: Vector2, _tab_h: float) -> void :
	vp = viewport
	max_h = floorf(vp.y * 0.4)
	custom_minimum_size.x = vp.x


func compact() -> bool:
	return vp.y < 700.0


func scroll_area() -> ScrollContainer:
	return scroll if scroll != null and is_instance_valid(scroll) else null


func _cf() -> Dictionary:
	return pc.get_conf(conf_id) if pc != null else {}




func rebuild() -> void :
	rebuilds += 1
	for c: Node in col.get_children():
		col.remove_child(c)
		c.queue_free()
	_bars.clear()
	_rows.clear()
	scroll = null
	_sel_box = null
	_confirm_b = null
	var cf: Dictionary = _cf()
	if cf.is_empty() or pc.conf_for_player() != cf:
		_map_mode(false)
		_build_result()
		return
	_fc_spent = {}
	_fc = pc.forecast(cf, _fc_spent)
	_map_mode(true)
	_header(cf)
	if not _folded:
		_build_parts(cf)
		if _list_mode:
			_build_terr(cf)
		else:
			_build_sel(cf)
		_build_footer(cf)
	_push_states()
	_fit_scroll()


func _header(cf: Dictionary) -> void :
	var hr: = HBoxContainer.new()
	hr.name = "Head"
	hr.add_theme_constant_override("separation", 4)
	hr.custom_minimum_size.y = 44
	col.add_child(hr)
	if _folded:
		var ub: Button = _chev_btn(true)
		ub.pressed.connect( func() -> void : _tool("fold"))
		hr.add_child(ub)
	else:
		for tb: Array in [["КАРТА", "map"], ["СПИСОК", "list"]]:
			var act: String = String(tb[1])
			var on: bool = (act == "list") == _list_mode
			var b: Button = UiKit.big(String(tb[0]), "gold" if on else "stone", "", 44.0, 10)
			b.name = "Tab_" + act
			b.custom_minimum_size.x = 64
			b.pressed.connect( func() -> void :
				if (act == "list") != _list_mode:
					_tool("list"))
			hr.add_child(b)

	var pb: = HBoxContainer.new()
	pb.add_theme_constant_override("separation", 3)
	pb.alignment = BoxContainer.ALIGNMENT_CENTER
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hr.add_child(pb)
	pb.add_child(_icon("icon_dip_points", 16))
	_pts_l = UiKit.lbl("", 14, C_GOLD, 3, 3)
	_pts_l.name = "Pts"
	_pts_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pb.add_child(_pts_l)
	_timer_l = UiKit.lbl(_mmss(float(cf["until"]) - gw.game_time), 11, UiKit.MUTED, 2, 3)
	_timer_l.name = "Timer"
	_timer_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hr.add_child(_timer_l)
	if _folded:
		_confirm_b = UiKit.big("ПОДТВЕРДИТЬ", "green", "", 44.0, 11)
		_confirm_b.name = "Confirm"
		_btn_icon(_confirm_b, "icon_ok")
		_confirm_b.pressed.connect( func() -> void : _confirm())
		hr.add_child(_confirm_b)
	else:
		var db: Button = _chev_btn(false)
		db.pressed.connect( func() -> void : _tool("fold"))
		hr.add_child(db)
	_update_pts(cf)


func _update_pts(cf: Dictionary) -> void :
	if _pts_l != null and is_instance_valid(_pts_l) and not cf.is_empty():
		_pts_l.text = "%d / %d" % [pc.points_left(cf, me), int((cf["pts"] as Dictionary).get(me, 0))]



func _chev_btn(up: bool) -> Button:
	var b: Button = UiKit.big("", "stone", "", 44.0, 10)
	b.name = "Fold"
	b.custom_minimum_size = Vector2(44, 44)
	var c: = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(c)
	b.resized.connect( func() -> void :
		c.position = Vector2.ZERO
		c.size = b.size)
	c.draw.connect( func() -> void :
		var o: Vector2 = (c.size * 0.5).round() + Vector2(0, -1)
		for pass_i in 2:
			for i in 5:
				var y: float = (o.y + 3.0 - 2.0 * float(i)) if up else (o.y - 5.0 + 2.0 * float(i))
				for x: float in [o.x - 9.0 + 2.0 * float(i), o.x + 7.0 - 2.0 * float(i)]:
					if pass_i == 0:
						c.draw_rect(Rect2(x - 1.0, y - 1.0, 4.0, 4.0), UiKit.OUTLINE)
					else:
						c.draw_rect(Rect2(x, y, 2.0, 2.0), UiKit.TEXT))
	return b



func _sorted_terr(cf: Dictionary) -> Array:
	var arr: Array = (cf["terr"] as Array).duplicate()
	arr.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["cost"]) != int(b["cost"]):
			return int(a["cost"]) > int(b["cost"])
		return int(a["city"]) < int(b["city"]))
	return arr















const C_ANNEX: = Color("ffd75e")
const C_PUPPET: = Color("7cccff")
const C_FREE: = Color("f2ead2")
const LAYER_PATH: String = "res://world/conf_map_layer.gd"
const CD = preload("res://ui/ui24/conf_declutter.gd")
var _layer: Node2D = null
var _mm_on: bool = false
var _saved: Dictionary = {}
var _pill: Button = null
var _pill_x: Button = null
var _legend: PanelContainer = null
var _legend_w: float = 0.0
var _fit_wait: int = -1
var _folded: bool = false
var _list_mode: bool = false
var _sel_box: VBoxContainer = null
var map_taps: int = 0
var map_zoom_taps: int = 0


const CONF_FLOOR_Z: float = 0.125







static func _pin_cam(cam: MapCamera, pos: Vector2, z: float, mt: float, mb: float) -> void :
	if cam == null or not is_instance_valid(cam) or (mt <= 0.0 and mb <= 0.0):
		return
	var st: Dictionary = {"n": 0}
	var step: = func(_t: float) -> void :
		if int(st["n"]) < 0 or not is_instance_valid(cam):
			return
		if cam.is_held() or cam.is_settling() or absf(cam.zoom.x - z) > 0.0005:
			st["n"] = -1
			return
		cam.position = pos
		if absf(cam.margin_top_px - mt) <= 2.0 and absf(cam.margin_bottom_px - mb) <= 2.0:
			st["n"] = int(st["n"]) + 1
			if int(st["n"]) >= 3:
				cam.center_on(pos)
				st["n"] = -1
	cam.create_tween().tween_method(step, 0.0, 1.0, 1.5)


func _map_mode(on: bool) -> void :
	if on == _mm_on:
		return
	_mm_on = on
	var hud_ok: bool = hud != null and is_instance_valid(hud)
	if on:
		var cam: MapCamera = gw.camera
		_saved = {"gw": gw, "pos": cam.position if cam != null else Vector2.ZERO, "z": cam.zoom.x if cam != null else 1.0, 
			"tabs": hud.tab_row.visible, "lane": hud.lane.visible if hud.lane != null else true, 
			"labels": gw.labels.visible if gw.labels != null else true, 
			"mt": cam.margin_top_px if cam != null else 0.0, "mb": cam.margin_bottom_px if cam != null else 0.0}
		hud.tab_row.visible = false
		if cam != null:
			cam.floor_z = CONF_FLOOR_Z


		if hud.map_chip != null:
			hud.map_chip.visible = false
		if gw.labels != null:
			gw.labels.visible = false
		if gw.map_layer != null:
			gw.map_layer.focus_id = def_id
		_layer = (load(LAYER_PATH) as Script).new() as Node2D
		_layer.call("setup", gw, def_id, _cities)
		gw.add_child(_layer)
		_layer.call("build")
		_build_top()
		_fit_wait = 2
		CD.tag(m)
		CD.hold(self, true)
		return
	if gw != null and is_instance_valid(gw) and gw.camera != null:
		gw.camera.floor_z = 0.0
	var w0: Variant = _saved.get("gw", null)
	var same: bool = w0 != null and is_instance_valid(w0) and gw != null and is_instance_valid(gw) and w0 == gw\
	and m != null and is_instance_valid(m) and m.get("world") == gw
	if same:
		if gw.map_layer != null:
			gw.map_layer.focus_id = -1
		if gw.labels != null:
			gw.labels.visible = bool(_saved.get("labels", true))
		var cam2: MapCamera = gw.camera
		if cam2 != null:
			cam2.set_zoom_at(float(_saved.get("z", cam2.zoom.x)), cam2.view_size() * 0.5)
			cam2.center_on(_saved.get("pos", cam2.position))
			_pin_cam(cam2, _saved.get("pos", cam2.position), float(_saved.get("z", cam2.zoom.x)), 
				float(_saved.get("mt", cam2.margin_top_px)), float(_saved.get("mb", cam2.margin_bottom_px)))
			if m.has_method("_on_zoom"):
				m.call("_on_zoom", cam2.zoom.x)
	if _layer != null and is_instance_valid(_layer):
		_layer.call("close")
	_layer = null
	if hud_ok:
		hud.tab_row.visible = bool(_saved.get("tabs", true))
		if hud.lane != null:
			hud.lane.visible = bool(_saved.get("lane", true))
		if hud.map_chip != null and same:
			hud.map_chip.visible = int(gw.map_mode) != 0
	for c: Control in [_pill, _pill_x, _legend]:
		if c != null and is_instance_valid(c):
			c.queue_free()
	_pill = null
	_pill_x = null
	_legend = null
	CD.hold(self, false)




func _build_top() -> void :
	var cf: Dictionary = _cf()
	var txt: String = Loc.t("МИРНАЯ КОНФЕРЕНЦИЯ · %s") % Loc.name(String(cf.get("name", ""))).to_upper()
	_pill = UiKit.big(txt, "blue", "icon_dip_conf", 44.0, 10)
	_pill.name = "ConfPill"
	_pill.top_level = true
	_pill.add_theme_constant_override("h_separation", 6)
	var f: Font = UiKit.f_black if UiKit.f_black != null else ThemeDB.fallback_font
	var want: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 24.0 + 6.0 + 26.0
	if want > vp.x - 16.0 - 48.0:
		_pill.clip_text = true
		_pill.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_pill.custom_minimum_size.x = vp.x - 16.0 - 48.0


	_pill.button_mask = 0
	_pill.focus_mode = Control.FOCUS_NONE
	_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pill)
	_pill_x = UiKit.close_btn(44.0)
	_pill_x.name = "ConfPillX"
	_pill_x.top_level = true
	_pill_x.pressed.connect( func() -> void : close_sheet())
	add_child(_pill_x)
	_legend = PanelContainer.new()
	_legend.name = "ConfLegend"
	_legend.top_level = true
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls: = StyleBoxFlat.new()
	ls.bg_color = Color(UiKit.OUTLINE, 0.8)
	ls.content_margin_left = 6
	ls.content_margin_right = 6
	ls.content_margin_top = 3
	ls.content_margin_bottom = 3
	_legend.add_theme_stylebox_override("panel", ls)
	add_child(_legend)
	var fl: = HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 8)
	fl.add_theme_constant_override("v_separation", 2)
	fl.alignment = FlowContainer.ALIGNMENT_CENTER
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.add_child(fl)
	var chips: Array = [[2, C_ANNEX, "АННЕКСИЯ"], [3, C_PUPPET, "МАРИОНЕТКА"], [1, C_FREE, "ОСТАНЕТСЯ ИМ"]]
	for pid: int in (cf.get("parts", []) as Array):
		var oc: Country = gw.country_by_id(pid)
		if oc != null and pid != me:
			chips.append([4, oc.color, Loc.name(oc.name).to_upper()])
	_legend_w = 12.0
	for ch: Array in chips:
		var w: float = _legend_chip(fl, int(ch[0]), ch[1] as Color, String(ch[2]))
		_legend_w += w + 8.0
	_legend_w = minf(_legend_w - 8.0, vp.x - 16.0)
	_place_top()



func _legend_chip(fl: Container, style: int, c: Color, text: String) -> float:
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(hb)
	var sw: = Control.new()
	sw.custom_minimum_size = Vector2(14, 12)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sw.draw.connect( func() -> void :
		sw.draw_rect(Rect2(Vector2.ZERO, sw.size), UiKit.OUTLINE)
		var inr: = Rect2(Vector2.ONE, sw.size - Vector2(2, 2))
		sw.draw_rect(inr, Color("4a4c48"))
		for y in int(inr.size.y):
			for x in int(inr.size.x):
				var on: bool = true
				var cc: Color = c
				match style:
					1:
						on = x % 4 == 0 and (y + (x / 4) * 2) % 4 == 0
						if not on:
							cc = Color(c, 0.25)
							on = true
					3:
						cc = c if ((x + y) / 3) % 2 == 0 else c.lerp(Color.WHITE, 0.5)
					4:
						on = posmod(x - y, 4) < 2
				if on:
					sw.draw_rect(Rect2(inr.position + Vector2(x, y), Vector2.ONE), cc))
	hb.add_child(sw)
	var l: Label = UiKit.lbl(text, 9, UiKit.TEXT, 2, 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(l)
	return 17.0 + ceilf(l.get_minimum_size().x) + 2.0


func _place_top() -> void :
	if _pill == null or not is_instance_valid(_pill) or hud == null or not is_instance_valid(hud):
		return
	var y: float = roundf(hud.top_col.position.y + hud.top_col.size.y + 4.0)
	if _pill.size != _pill.get_combined_minimum_size():
		_pill.reset_size()
	var xw: float = 48.0 if _pill_x != null and is_instance_valid(_pill_x) else 0.0
	var pp: = Vector2(roundf((vp.x - _pill.size.x - xw) * 0.5), y)
	if _pill.position != pp:
		_pill.position = pp
	if xw > 0.0:
		var xp: = Vector2(pp.x + _pill.size.x + 4.0, pp.y + roundf((_pill.size.y - _pill_x.size.y) * 0.5))
		if _pill_x.position != xp:
			_pill_x.position = xp
	if _legend != null and is_instance_valid(_legend):
		var ls: = Vector2(_legend_w, _legend.get_combined_minimum_size().y)
		if _legend.size != ls:
			_legend.size = ls
		var lp: = Vector2(roundf((vp.x - _legend_w) * 0.5), roundf(pp.y + _pill.size.y + 3.0))
		if _legend.position != lp:
			_legend.position = lp



func _map_top() -> float:
	if _legend != null and is_instance_valid(_legend):
		return _legend.position.y + _legend.size.y + 6.0
	if _pill != null and is_instance_valid(_pill):
		return _pill.position.y + _pill.size.y + 6.0
	return 120.0



func _free_rect() -> Rect2:
	var vs: Vector2 = gw.camera.view_size()
	var top: float = _map_top()
	var bot: float = global_position.y - 8.0 if size.y > 1.0 else vs.y * 0.6
	return Rect2(Vector2(10.0, top), Vector2(vs.x - 20.0, maxf(60.0, bot - top)))



func _fit_camera() -> void :
	if _layer == null or not is_instance_valid(_layer):
		return
	var cam: MapCamera = gw.camera
	var r: Rect2 = _layer.call("bbox_world")
	var vs: Vector2 = cam.view_size()
	var free: Rect2 = _free_rect()
	var zf: float = minf(free.size.x / maxf(r.size.x, 1.0), free.size.y / maxf(r.size.y, 1.0)) * 0.95
	if zf < cam.min_zoom():


		var cr: = Rect2()
		var csv: Variant = _layer.get("cities")
		var cs: Array = csv if csv is Array else []
		for k: int in cs.size():
			var cw: Vector2 = _layer.call("city_world", k)
			cr = Rect2(cw, Vector2.ZERO) if k == 0 else cr.expand(cw)
		if cs.size() > 0:
			r = cr.grow(14.0 / cam.min_zoom())
			zf = minf(free.size.x / maxf(r.size.x, 1.0), free.size.y / maxf(r.size.y, 1.0)) * 0.95
	var z: float = cam.min_zoom()
	for zz: Variant in MapCamera.zs:
		if float(zz) <= zf and float(zz) <= 3.0:
			z = float(zz)
	cam.set_zoom_at(z, vs * 0.5)
	cam.center_on(r.get_center() - (free.get_center() - vs * 0.5) / z)
	if m.has_method("_on_zoom"):
		m.call("_on_zoom", cam.zoom.x)



func _focus_city(k: int) -> void :
	if _layer == null or not is_instance_valid(_layer) or k < 0:
		return
	var cam: MapCamera = gw.camera
	var free: Rect2 = _free_rect().grow(-20.0)
	var p: Vector2 = _layer.call("badge_screen", k)
	if free.has_point(p):
		return
	var vs: Vector2 = cam.view_size()
	var wpt: Vector2 = _layer.call("city_world", k)
	cam.center_on(wpt - (free.get_center() - vs * 0.5) / cam.zoom.x)




func world_tap(pos: Vector2, _wp: Vector2) -> bool:
	if _closing or _done or not _mm_on or _layer == null or not is_instance_valid(_layer):
		return false
	if pos.y < _map_top() - 4.0:
		return true
	_map_tap(pos)
	return true


func _map_tap(pos: Vector2) -> void :
	var cam: MapCamera = gw.camera
	var zmax: float = float(MapCamera.zs[MapCamera.zs.size() - 1])
	var k: int = int(_layer.call("pick_at", pos, cam.zoom.x >= zmax - 0.01))
	if k == -2:
		map_zoom_taps += 1
		cam.step_zoom(1, pos)
		if m.has_method("_on_zoom"):
			m.call("_on_zoom", cam.zoom.x)
		UiKit.snd("ui_select")
		return
	if k < 0:
		if _sel >= 0:
			_select(-1, true)
		return
	map_taps += 1
	if _folded:
		_folded = false
		_sel = k
		UiKit.snd("ui_select")
		rebuild()
		return
	_select(k, true)


func _tool(act: String) -> void :
	UiKit.snd("ui_click")
	match act:
		"fit":
			_fit_camera()
		"list":
			_list_mode = not _list_mode
			rebuild()
		"fold":
			_folded = not _folded
			rebuild()
		"zoom_in", "zoom_out":
			var cam: MapCamera = gw.camera
			cam.step_zoom(1 if act == "zoom_in" else -1, _free_rect().get_center())



func _push_states() -> void :
	var cf: Dictionary = _cf()
	if cf.is_empty():
		return
	var st: Array = []
	_tok_col = []
	for k in _cities.size():
		var cid: int = int(_cities[k])
		var t: Dictionary = _terr(cf, cid)
		var by: int = int(t.get("by", 0))
		var fcd: Dictionary = _fc.get(cid, {})
		var e: Dictionary = {"style": 1, "col": C_FREE, "badge": C_FREE}
		if by == me:
			var an: bool = String(t.get("mode", "")) == "annex"
			e = {"style": 2 if an else 3, "col": C_ANNEX if an else C_PUPPET, "badge": C_ANNEX if an else C_PUPPET}
		elif by != 0:
			var oc: Country = gw.country_by_id(by)
			var cc: Color = oc.color if oc != null else Color("8f8a76")
			e = {"style": 4, "col": cc, "badge": cc}
		elif not fcd.is_empty():
			var fcc: Country = gw.country_by_id(int(fcd["by"]))
			var cc2: Color = fcc.color if fcc != null else Color("8f8a76")
			e = {"style": 5, "col": cc2, "badge": cc2.darkened(0.3)}
		st.append(e)
		_tok_col.append(e["badge"])
	if _layer != null and is_instance_valid(_layer):
		_layer.call("set_states", st, _sel)
	for r: Variant in _rows.values():
		var rw: Control = (r as Dictionary)["row"]
		if is_instance_valid(rw):
			rw.propagate_call("queue_redraw")


func _select(k: int, from_map: bool, quiet: bool = false) -> void :
	var changed: bool = k != _sel
	_sel = k
	if not quiet:
		UiKit.snd("ui_select")
	_push_states()
	if _list_mode:
		for cid: int in _rows:
			var r: Control = (_rows[cid] as Dictionary)["row"]
			if is_instance_valid(r):
				r.modulate = Color(1.15, 1.12, 0.9) if _cities.find(cid) == k else Color.WHITE
		if from_map and k >= 0 and k < _cities.size():
			var rr: Control = (_rows.get(int(_cities[k]), {}) as Dictionary).get("row", null)
			if rr != null and is_instance_valid(rr) and scroll != null:
				scroll.ensure_control_visible(rr)
	elif changed:
		_fill_sel(_cf())
	if not from_map and k >= 0:
		_focus_city(k)


static func _f1(v: float) -> String:
	return Loc.dec("%.1f" % v)




func _build_sel(cf: Dictionary) -> void :
	_sel_box = VBoxContainer.new()
	_sel_box.name = "Sel"
	_sel_box.custom_minimum_size.y = SEL_H
	col.add_child(_sel_box)
	_fill_sel(cf)


func _fill_sel(cf: Dictionary) -> void :
	if _sel_box == null or not is_instance_valid(_sel_box):
		return
	for c: Node in _sel_box.get_children():
		_sel_box.remove_child(c)
		c.queue_free()
	_rows.clear()
	if cf.is_empty():
		return
	if _sel >= 0 and _sel < _cities.size():
		var t: Dictionary = _terr(cf, int(_cities[_sel]))
		if not t.is_empty():
			_sel_box.add_child(_terr_row(cf, t, _sel))
			return
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 6, 4))
	p.custom_minimum_size.y = SEL_H
	var v: = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var l1: Label = UiKit.lbl("Выберите территорию: коснитесь карты", 11, UiKit.TEXT, 2, 3)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l1)
	var l2: Label = UiKit.lbl("перетаскивание — сдвиг · щипок — масштаб", 9, UiKit.MUTED, 1)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l2)
	_sel_box.add_child(p)


func _confirm() -> void :
	NetSession.sim("diplo.conf", "confirm", [conf_id, me], func(r: Variant) -> void :
		if not is_instance_valid(self):
			return
		var why: String = Loc.t("Команда не выполнена") if r == null else String(r)
		if why != "":
			hud.show_toast(why)
			return
		UiKit.snd("ui_capture")
		_done = true
		rebuild())




func _build_parts(cf: Dictionary) -> void :
	var box: = VBoxContainer.new()
	box.name = "Parts"
	box.add_theme_constant_override("separation", 3)
	col.add_child(box)
	var order: Array = (cf["parts"] as Array).duplicate()
	var two: bool = order.size() >= 3
	var grid: = GridContainer.new()
	grid.columns = 2 if two else 1
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	box.add_child(grid)
	for pid: int in order:
		var c: Country = gw.country_by_id(pid)
		if c == null:
			continue
		var hb: = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 5)
		hb.custom_minimum_size.y = 20
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(hb)
		hb.add_child(_flag(c, Vector2(21, 14)))
		if not two:
			var nm: Label = UiKit.lbl(Loc.t("ВЫ") if pid == me else Loc.name(c.name).to_upper(), 10, C_GOLD if pid == me else UiKit.TEXT, 2, 3)
			nm.custom_minimum_size.x = 84 if vp.x < 400 else 112
			UiKit.fit_lbl(nm, [10, 9])
			hb.add_child(nm)
		var bar: Control = _points_bar(cf, pid, c.color)
		hb.add_child(bar)
		_bars[pid] = bar
		if not two:
			var sh: Label = UiKit.lbl(Loc.pct(roundi(float((cf["share"] as Dictionary).get(pid, 0.0)) * 100.0)), 10, UiKit.MUTED, 2, 3)
			sh.custom_minimum_size.x = 34
			sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			hb.add_child(sh)

	var b: Dictionary = (cf["brk"] as Dictionary).get(me, {})
	if not b.is_empty() and not compact():
		var why: Label = UiKit.lbl(Loc.t("Ваш вклад: города %d · урон %s · помощь %s · %d мин войны") % [roundi(float(b["cap"])), _k(float(b["dmg_raw"])), _k(float(b["aid_raw"])), roundi(float(b["t_raw"]) / 60.0)], 9, UiKit.MUTED, 1)
		why.clip_text = true
		why.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(why)



func _points_bar(cf: Dictionary, pid: int, colr: Color) -> Control:
	var c: = Control.new()
	c.custom_minimum_size = Vector2(80, 16)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shown[pid] = float(_spent(cf, pid))
	c.draw.connect( func() -> void :
		var cf2: Dictionary = _cf()
		if cf2.is_empty():
			return
		var tot: float = maxf(1.0, float((cf2["pts"] as Dictionary).get(pid, 0)))
		var sp: float = float(_shown.get(pid, 0.0))
		var w: float = c.size.x
		c.draw_rect(Rect2(Vector2.ZERO, c.size), UiKit.OUTLINE)
		c.draw_rect(Rect2(1, 1, w - 2, c.size.y - 2), C_EMPTY)
		var fw: float = roundf((w - 2.0) * clampf(1.0 - sp / tot, 0.0, 1.0))
		c.draw_rect(Rect2(1, 1, fw, c.size.y - 2), colr.darkened(0.15))
		c.draw_rect(Rect2(1, 1, fw, 2), colr.lightened(0.3))
		if sp > 0.0:
			var gx: float = 1.0 + fw
			var gw2: float = (w - 2.0) - fw
			c.draw_rect(Rect2(gx, 1, gw2, c.size.y - 2), Color(C_GOLD, 0.35))
		var f: Font = UiKit.f_bold
		var s: String = "%d / %d" % [roundi(tot - sp), roundi(tot)]
		var sz: Vector2 = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var pos: = Vector2(roundf((w - sz.x) * 0.5), roundf(c.size.y * 0.5 + 4.0))
		c.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, UiKit.OUTLINE)
		c.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiKit.TEXT))
	return c


func _spent(cf: Dictionary, pid: int) -> int:
	if pid != me and String(cf.get("phase", "")) == "people" and _fc_spent.has(pid):
		return int(_fc_spent[pid])
	var sp: int = int((cf["spent"] as Dictionary).get(pid, 0))
	if pid != me:
		for cid: int in _fc:
			if int(_fc[cid]["by"]) == pid:
				var t: Dictionary = _terr(cf, cid)
				sp += int(t["pcost"]) if String(_fc[cid]["mode"]) == "puppet" else int(t["cost"])
	return sp




func _new_scroll() -> void :
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(scroll)
	inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)


func _build_terr(cf: Dictionary) -> void :
	_new_scroll()
	var k: int = 0
	for t: Dictionary in _sorted_terr(cf):
		inner.add_child(_list_row(cf, t, k) if _list_mode else _terr_row(cf, t, k))
		k += 1



func _list_row(cf: Dictionary, t: Dictionary, k: int) -> Control:
	var cid: int = int(t["city"])
	var city: City = gw.cities[cid]
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 4, 3))
	var h1: = HBoxContainer.new()
	h1.add_theme_constant_override("separation", 5)
	p.add_child(h1)
	var chk: = Button.new()
	chk.name = "Check"
	chk.focus_mode = Control.FOCUS_NONE
	chk.custom_minimum_size = Vector2(44, 44)
	chk.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UiKit.press_fx(chk)
	var hc: = Control.new()
	hc.name = "H"
	hc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chk.add_child(hc)
	chk.resized.connect( func() -> void :
		hc.position = Vector2.ZERO
		hc.size = chk.size)
	hc.draw.connect( func() -> void :
		var cf2: Dictionary = _cf()
		var t2: Dictionary = _terr(cf2, cid) if not cf2.is_empty() else {}
		var on: bool = int(t2.get("by", 0)) == me and String(t2.get("mode", "")) == "annex"
		var c0: Vector2 = hc.size * 0.5
		hc.draw_rect(Rect2(c0 - Vector2(10, 10), Vector2(20, 20)), UiKit.OUTLINE)
		hc.draw_rect(Rect2(c0 - Vector2(8, 8), Vector2(16, 16)), Color("f2ead2") if on else Color("3a3b33"))
		if on:
			hc.draw_polyline(PackedVector2Array([c0 + Vector2(-5, 0), c0 + Vector2(-1, 4), c0 + Vector2(6, -5)]), UiKit.OUTLINE, 3.0))
	chk.pressed.connect( func() -> void : _pick_toggle(cid, "annex", chk))
	h1.add_child(chk)
	var num: = Button.new()
	num.focus_mode = Control.FOCUS_NONE
	num.flat = true
	num.custom_minimum_size = Vector2(26, 44)
	num.draw.connect( func() -> void :
		num.draw_circle(num.size * 0.5, 10.0, UiKit.OUTLINE)
		num.draw_circle(num.size * 0.5, 9.0, _claim_col(cid, k))
		num.draw_circle(num.size * 0.5, 6.0, C_GOLD if _sel == k else Color("f2ead2"))
		var f: Font = UiKit.f_bold
		var s: String = str(k + 1)
		var sz: Vector2 = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		num.draw_string(f, Vector2(roundf((num.size.x - sz.x) * 0.5), roundf(num.size.y * 0.5 + 4.0)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiKit.OUTLINE))
	num.pressed.connect( func() -> void : _select(k, false))
	h1.add_child(num)
	var nv: = VBoxContainer.new()
	nv.add_theme_constant_override("separation", 0)
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h1.add_child(nv)
	var nm: Label = UiKit.lbl(Loc.name(city.name).to_upper(), 11, UiKit.TEXT, 2, 3)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nv.add_child(nm)
	var kind_s: String = ["СТОЛИЦА", "ГОРОД", "ПОСЁЛОК"][clampi(city.kind, 0, 2)]
	if city.kind == City.Kind.CAPITAL or int(pc.cap0.get(def_id, -1)) == cid:
		kind_s = "СТОЛИЦА"
	var who: Label = UiKit.lbl("", 9, UiKit.MUTED, 2, 3)
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var sub: = HBoxContainer.new()
	sub.add_theme_constant_override("separation", 4)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nv.add_child(sub)
	sub.add_child(UiKit.lbl(kind_s, 9, UiKit.MUTED, 1))
	sub.add_child(_icon("icon_dip_points", 10))
	sub.add_child(UiKit.lbl(str(int(t["cost"])), 10, C_GOLD, 2, 3))
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.add_child(who)
	var pb: Button = _mode_btn(t, "puppet", true)
	pb.name = "Puppet"
	pb.size_flags_horizontal = Control.SIZE_SHRINK_END
	pb.custom_minimum_size = Vector2(108, 44)
	pb.pressed.connect( func() -> void : _pick_toggle(cid, "puppet", pb))
	h1.add_child(pb)
	_rows[cid] = {"row": p, "btns": {"annex": chk, "puppet": pb}, "who": who}
	_style_row(cf, t)
	return p



func _pick_toggle(cid: int, mode: String, b: Button) -> void :
	var cf: Dictionary = _cf()
	if cf.is_empty():
		return
	var t: Dictionary = _terr(cf, cid)
	var mine: bool = int(t.get("by", 0)) == me and String(t.get("mode", "")) == mode
	_pick(cid, "" if mine else mode, b)



func _terr_row(cf: Dictionary, t: Dictionary, k: int) -> Control:
	var cid: int = int(t["city"])
	var city: City = gw.cities[cid]
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 6, 4))
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	p.add_child(vb)
	var h1: = HBoxContainer.new()
	h1.add_theme_constant_override("separation", 5)
	vb.add_child(h1)
	var num: = Button.new()
	num.focus_mode = Control.FOCUS_NONE
	num.flat = true
	num.custom_minimum_size = Vector2(22, 22)
	num.mouse_filter = Control.MOUSE_FILTER_STOP
	num.draw.connect( func() -> void :
		num.draw_circle(num.size * 0.5, 10.0, UiKit.OUTLINE)
		num.draw_circle(num.size * 0.5, 9.0, _claim_col(cid, k))
		num.draw_circle(num.size * 0.5, 6.0, C_GOLD if _sel == k else Color("f2ead2"))
		var f: Font = UiKit.f_bold
		var s: String = str(k + 1)
		var sz: Vector2 = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		num.draw_string(f, Vector2(roundf((num.size.x - sz.x) * 0.5), roundf(num.size.y * 0.5 + 4.0)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiKit.OUTLINE))
	num.pressed.connect( func() -> void : _select(k, false))
	h1.add_child(num)
	var nm: Label = UiKit.lbl(Loc.name(city.name).to_upper(), 11, UiKit.TEXT, 2, 3)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h1.add_child(nm)
	var kind_s: String = ["СТОЛИЦА", "ГОРОД", "ПОСЁЛОК"][clampi(city.kind, 0, 2)]
	if city.kind == City.Kind.CAPITAL or int(pc.cap0.get(def_id, -1)) == cid:
		kind_s = "СТОЛИЦА"
	h1.add_child(UiKit.lbl(kind_s, 9, UiKit.MUTED, 1))
	var who: Label = UiKit.lbl("", 9, UiKit.MUTED, 2, 3)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	who.custom_minimum_size.x = 92
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h1.add_child(who)
	var h2: = HBoxContainer.new()
	h2.add_theme_constant_override("separation", 5)
	vb.add_child(h2)
	var btns: Dictionary = {}
	for mode: String in ["annex", "puppet", ""]:
		var b: Button = _mode_btn(t, mode)
		h2.add_child(b)
		btns[mode] = b
		b.pressed.connect( func() -> void : _pick(cid, mode, b))
	_rows[cid] = {"row": p, "btns": btns, "who": who}
	_style_row(cf, t)
	return p



func _claim_col(cid: int, k: int) -> Color:
	if k < _tok_col.size():
		return _tok_col[k]
	return Color("8f8a76")


func _mode_btn(t: Dictionary, mode: String, small: bool = false) -> Button:
	var ico: String = {"annex": "icon_dip_annex", "puppet": "icon_dip_puppet", "": "icon_dip_return"}[mode]
	var txt: String = {"annex": "АННЕКСИЯ", "puppet": "МАРИОНЕТКА", "": "ВЕРНУТЬ"}[mode]
	var cost: int = int(t["cost"]) if mode == "annex" else (int(t["pcost"]) if mode == "puppet" else 0)
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UiKit.press_fx(b)
	var hb: = HBoxContainer.new()
	hb.name = "H"
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 3)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	hb.add_child(_icon(ico + "_16" if small and UiKit.has(ico + "_16") else ico, 16.0 if small else 20.0))
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(v)
	var l: Label = UiKit.lbl(txt, 9, UiKit.TEXT, 2, 3)
	l.name = "L"
	v.add_child(l)
	if mode != "":
		var cl: = HBoxContainer.new()
		cl.add_theme_constant_override("separation", 1)
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(cl)
		cl.add_child(_icon("icon_dip_points", 10))
		var c2: Label = UiKit.lbl(str(cost), 10, C_GOLD, 2, 3)
		c2.name = "C"
		cl.add_child(c2)
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_top = -1.0
	hb.offset_bottom = -1.0
	return b



func _style_row(cf: Dictionary, t0: Dictionary) -> void :
	var t: Dictionary = _terr(cf, int(t0["city"]))
	var cid: int = int(t["city"])
	var r: Dictionary = _rows.get(cid, {})
	if r.is_empty():
		return
	var by: int = int(t["by"])
	var mode: String = String(t["mode"])
	var left: int = pc.points_left(cf, me)
	var mine_cost: int = 0
	if by == me:
		mine_cost = int(t["cost"]) if mode == "annex" else int(t["pcost"])
	var fcd: Dictionary = _fc.get(cid, {})
	for md: String in (r["btns"] as Dictionary):
		var b: Button = r["btns"][md]
		var chosen: bool = (by == me and md == mode) or (by == 0 and md == "" and fcd.is_empty())
		var need: int = int(t["cost"]) if md == "annex" else (int(t["pcost"]) if md == "puppet" else 0)
		var afford: bool = md == "" or need <= left + mine_cost
		var style: String = "gold" if chosen and md != "" else ("slot" if chosen else ("stone" if afford else "disabled"))
		var n: StyleBox
		var pr: StyleBox
		if style == "slot":
			n = UiKit.sb("wb_slot", 2)
			pr = UiKit.sb("wb_slot_pressed", 2)
		elif style == "disabled":
			n = UiKit.sb("wb_slot_disabled", 2)
			pr = n
		else:
			n = UiKit.sb("wb_btn_" + style, 2, 2, -1)
			pr = UiKit.sb("wb_btn_" + style + "_p", 2, 2, 1)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", n)
		b.add_theme_stylebox_override("pressed", pr)
		(b.get_node("H") as Control).modulate.a = 1.0 if afford else 0.45
	var who: Label = r["who"]
	var vs: Array = t.get("vs", [])
	if by == me and not vs.is_empty():
		var win: int = pc.contest_winner(cf, _terr_raw(cf, cid))
		who.text = Loc.t("СПОР: ЗА ВАМИ") if win == me else Loc.t("СПОР: УЙДЁТ К %s") % Loc.name(gw.country_by_id(win).name).to_upper()
		who.add_theme_color_override("font_color", C_GOLD if win == me else Color("e8a33c"))
	elif by == me:
		who.text = "ВАМ"
		who.add_theme_color_override("font_color", C_GOLD)
	elif by != 0 and not vs.is_empty():
		who.text = Loc.t("ЗАЯВИЛ %s") % Loc.name(gw.country_by_id(by).name).to_upper()
		who.add_theme_color_override("font_color", gw.country_by_id(by).color.lightened(0.3))
	elif by != 0:
		who.text = Loc.name(gw.country_by_id(by).name).to_upper()
		who.add_theme_color_override("font_color", gw.country_by_id(by).color.lightened(0.3))
	elif not fcd.is_empty():
		var fb: Country = gw.country_by_id(int(fcd["by"]))
		who.text = "→ " + Loc.name(fb.name).to_upper()
		who.add_theme_color_override("font_color", fb.color.lightened(0.25))
	else:
		who.text = "ОСТАНЕТСЯ ИМ"
		who.add_theme_color_override("font_color", UiKit.MUTED)


func _pick(cid: int, mode: String, b: Button) -> void :
	var cf: Dictionary = _cf()
	if cf.is_empty():
		return
	var t: Dictionary = _terr(cf, cid)
	if int(t.get("by", 0)) != me and mode == "":
		pass
	var before: int = int((cf["spent"] as Dictionary).get(me, 0))
	NetSession.sim("diplo.conf", "pick", [conf_id, cid, mode, me], func(r: Variant) -> void :
		if is_instance_valid(self) and is_instance_valid(b):
			_picked(Loc.t("Команда не выполнена") if r == null else String(r), cid, b, before))


func _picked(why: String, cid: int, b: Button, before: int) -> void :
	var cf: Dictionary = _cf()
	if cf.is_empty():
		return
	if why != "":
		hud.show_toast(why)
		_shake(b)
		UiKit.snd("ui_error")
		return
	UiKit.snd("ui_click")
	_chip_pop(b)
	var after: int = int((cf["spent"] as Dictionary).get(me, 0))
	if after != before:
		_float_delta(after - before)
	_fc_spent = {}
	_fc = pc.forecast(cf, _fc_spent)
	for t2: Dictionary in cf["terr"]:
		_style_row(cf, t2)
	_animate_bars(cf)
	_update_pts(cf)
	_select(_cities.find(cid), false, true)
	for r: Variant in _rows.values():
		var rw: Control = (r as Dictionary)["row"]
		if is_instance_valid(rw):
			rw.propagate_call("queue_redraw")
	_update_sum(cf)



func _animate_bars(cf: Dictionary) -> void :
	for pid: int in _bars:
		var to: float = float(_spent(cf, pid))
		var from: float = float(_shown.get(pid, to))
		if absf(to - from) < 0.01:
			continue
		var bar: Control = _bars[pid]
		var tw: Tween = create_tween()
		tw.tween_method( func(v: float) -> void :
			_shown[pid] = v
			if is_instance_valid(bar):
				bar.queue_redraw(), from, to, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)



func _float_delta(d: int) -> void :
	var bar: Control = _bars.get(me, null)
	if bar == null or not is_instance_valid(bar):
		return
	var l: Label = UiKit.lbl(("−%d" % d) if d > 0 else ("+%d" % - d), 12, C_GOLD if d > 0 else Color("a2e35f"), 2, 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.top_level = true
	l.global_position = bar.global_position + Vector2(bar.size.x * 0.5 - 10.0, -6.0)
	var tw: Tween = l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y - 18.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.15)
	tw.chain().tween_callback(l.queue_free)




func _build_footer(cf: Dictionary) -> void :
	_sum_l = null
	if _list_mode:
		_sum_l = UiKit.lbl("", 10, UiKit.TEXT, 2, 3)
		_sum_l.clip_text = true
		_sum_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(_sum_l)
	var hb: = HBoxContainer.new()
	hb.name = "Foot"
	hb.add_theme_constant_override("separation", 6)
	col.add_child(hb)
	var fb: Button = UiKit.big("ВСЕ", "stone", "", 44.0, 11)
	fb.name = "Map_fit"
	fb.custom_minimum_size.x = 74
	_btn_icon(fb, "icon_center")
	fb.pressed.connect( func() -> void : _tool("fit"))
	hb.add_child(fb)
	var rb: Button = UiKit.big("СБРОС", "stone", "", 44.0, 12)
	rb.name = "Reset"
	rb.custom_minimum_size.x = 84
	rb.pressed.connect( func() -> void :
		NetSession.sim("diplo.conf", "reset_picks", [conf_id, me], func(_r: Variant) -> void :
			if not is_instance_valid(self):
				return
			var cf2: Dictionary = _cf()
			if cf2.is_empty():
				return
			_fc_spent = {}
			_fc = pc.forecast(cf2, _fc_spent)
			for t: Dictionary in cf2["terr"]:
				_style_row(cf2, t)
			_animate_bars(cf2)
			_update_pts(cf2)
			_push_states()
			_update_sum(cf2)))
	hb.add_child(rb)
	_confirm_b = UiKit.big("ПОДТВЕРДИТЬ", "green", "", 44.0, 12)
	_confirm_b.name = "Confirm"
	_confirm_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_icon(_confirm_b, "icon_ok")
	_confirm_b.pressed.connect( func() -> void : _confirm())
	hb.add_child(_confirm_b)
	_update_sum(cf)


func _update_sum(cf: Dictionary) -> void :
	if _sum_l == null or not is_instance_valid(_sum_l):
		return
	var an: int = 0
	var pu: int = 0
	var back: int = 0
	for t0: Dictionary in cf["terr"]:
		var t: Dictionary = _terr(cf, int(t0["city"]))
		if int(t["by"]) == me:
			if String(t["mode"]) == "annex":
				an += 1
			else:
				pu += 1
		elif int(t["by"]) == 0 and not _fc.has(int(t["city"])):
			back += 1
	var parts: PackedStringArray = PackedStringArray()
	if an > 0:
		parts.append(Loc.t("аннексия %d") % an)
	if pu > 0:
		parts.append(Loc.t("марионетка из %d") % pu)
	if parts.is_empty():
		parts.append(Loc.t("ничего не выбрано"))
	_sum_l.text = Loc.t("Вам: %s · очков осталось %d%s") % [", ".join(parts), pc.points_left(cf, me), (Loc.t(" · вернётся им %d") % back) if back > 0 else ""]


func _build_result() -> void :
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 6)
	hr.custom_minimum_size.y = 40
	col.add_child(hr)
	hr.add_child(_icon("icon_dip_conf", 24))
	var t: Label = UiKit.lbl("ИТОГИ КОНФЕРЕНЦИИ", 16, UiKit.TITLE, 3, 4)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.clip_text = true
	hr.add_child(t)
	var cb: Button = UiKit.close_btn(UiKit.TOUCH_MIN)
	cb.pressed.connect( func() -> void : close_sheet())
	hr.add_child(cb)
	var res: Dictionary = {}
	for r: Dictionary in pc.results:
		if int(r["def"]) == def_id:
			res = r
	var cfw: Dictionary = pc.get_conf(conf_id)
	if res.is_empty() and not cfw.is_empty() and String(cfw.get("phase", "")) in ["people", "repick"]:

		var wl: Label = UiKit.lbl(Loc.t("Выбор принят — ждём: %s") % ", ".join(PackedStringArray(pc._people_left(cfw).map( func(x: int) -> String: return gw.country_by_id(x).name))), 11, UiKit.TEXT, 1)
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(wl)
	elif res.is_empty():
		col.add_child(UiKit.lbl("Конференция закончилась", 11, UiKit.MUTED, 1))
	else:
		var annex: Dictionary = res["annex"]
		for pid: Variant in res.get("parts", []):
			var c: Country = gw.country_by_id(int(pid))
			if c == null:
				continue
			var hb: = HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			hb.custom_minimum_size.y = 28
			col.add_child(hb)
			hb.add_child(_flag(c, Vector2(24, 16)))
			var nm: Label = UiKit.lbl(Loc.t("ВЫ") if c.id == me else Loc.name(c.name).to_upper(), 11, C_GOLD if c.id == me else UiKit.TEXT, 2, 3)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(nm)
			var n_an: int = int(annex.get(c.id, annex.get(str(c.id), 0)))
			if n_an > 0:
				hb.add_child(_icon("icon_dip_annex", 20))
				hb.add_child(UiKit.lbl("×%d" % n_an, 11, UiKit.TEXT, 2, 3))
			for pz: Variant in res["puppets"]:
				if int((pz as Array)[1]) == c.id:
					var pcn: Country = gw.country_by_id(int((pz as Array)[0]))
					hb.add_child(_icon("icon_dip_puppet", 20))
					if pcn != null:
						hb.add_child(_flag(pcn, Vector2(18, 12)))
						hb.add_child(UiKit.lbl(Loc.name(pcn.name).to_upper(), 10, pcn.color.lightened(0.3), 2, 3))
		if int(res.get("returned", 0)) > 0:
			col.add_child(UiKit.lbl(Loc.t("%s сохраняет %d %s") % [String(res["name"]), int(res["returned"]), Loc.n(int(res["returned"]), "город", "города", "городов")], 10, UiKit.MUTED, 1))
		for pz2: Variant in res["puppets"]:
			if int((pz2 as Array)[0]) == int(res["def"]):
				col.add_child(UiKit.lbl(Loc.t("На месте %s — новое государство") % String(res["name"]), 10, UiKit.MUTED, 1))
	var ok: Button = UiKit.big("НА КАРТУ", "green", "", 44.0, 12)
	ok.pressed.connect( func() -> void : close_sheet())
	col.add_child(ok)




func open_anim() -> void :
	rebuild()
	modulate.a = 0.0
	UiKit.snd("ui_open")
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)


func _fit_scroll() -> void :
	if scroll == null:
		return
	var lim: float = floorf(vp.y * (0.62 if _list_mode else 0.4))
	var fixed: float = 0.0
	var n: int = 0
	for c: Node in col.get_children():
		if c != scroll and c is Control and (c as Control).visible:
			fixed += (c as Control).get_combined_minimum_size().y
			n += 1
	fixed += float(n) * 5.0 + 20.0 + float(hud._safe_margins().y)
	scroll.custom_minimum_size.y = clampf(inner.get_combined_minimum_size().y, 60.0, maxf(60.0, lim - fixed))


func _back() -> void :
	close_sheet()
	if hud != null and hud.has_method("open_diplomacy"):
		hud.call_deferred("open_diplomacy")


func close_sheet() -> void :
	if _closing:
		return
	_closing = true
	_map_mode(false)
	if pc != null and pc.hold_id == conf_id:
		pc.hold_id = -1
	hud.ui24_closed(self)
	UiKit.snd("ui_close")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback( func() -> void :
		closed.emit()
		if hud.panel == self:
			hud.close_panel()
		else:
			queue_free())


func close() -> void :
	close_sheet()


func _process(delta: float) -> void :
	if _closing:
		return
	if _mm_on:
		_place_top()
		if _fit_wait > 0:
			_fit_wait -= 1
			if _fit_wait == 0 and size.y > 1.0:
				_fit_camera()
			elif _fit_wait == 0:
				_fit_wait = 1
	_tick += delta
	if _tick < 0.25:
		return
	_tick = 0.0
	if _mm_on:
		CD.tag(m)
	if gw.diplo != dp or gw.player == null:
		close_sheet()
		return
	var cf: Dictionary = _cf()
	if not _done and (cf.is_empty() or pc.conf_for_player() != cf):
		_done = true
		rebuild()
		return
	if _timer_l != null and is_instance_valid(_timer_l) and not cf.is_empty():
		_timer_l.text = _mmss(float(cf["until"]) - gw.game_time)




func _terr_raw(cf: Dictionary, cid: int) -> Dictionary:
	for t: Dictionary in cf.get("terr", []):
		if int(t["city"]) == cid:
			return t
	return {}


func _terr(cf: Dictionary, cid: int) -> Dictionary:
	for t: Dictionary in cf.get("terr", []):
		if int(t["city"]) == cid:
			if not t.has("cl"):
				return t

			var v: Dictionary = t.duplicate()
			var mine: String = PeaceConfS.claim_of(t, me)
			var others: Array = PeaceConfS.claimers(t).filter( func(x: int) -> bool: return x != me)
			v["by"] = me if mine != "" else int(others[0])
			v["mode"] = mine if mine != "" else PeaceConfS.claim_of(t, int(others[0]))
			v["vs"] = others
			return v
	return {}


func _icon(nm: String, box: float) -> TextureRect:
	var fb: Dictionary = {"icon_dip_conf": "icon_peace", "icon_dip_annex": "icon_plus", "icon_dip_puppet": "icon_treaty_alliance", 
		"icon_dip_return": "icon_minus", "icon_dip_points": "icon_score"}
	var r: TextureRect = UiKit.icon_rect(nm if UiKit.has(nm) else String(fb.get(nm, "icon_info")), box)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


func _flag(c: Country, sz: Vector2) -> Control:
	var p: = PanelContainer.new()
	var s: = StyleBoxFlat.new()
	s.bg_color = UiKit.OUTLINE
	s.set_content_margin_all(1)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fl: = TextureRect.new()
	fl.texture = FlagMaker.tex_for(c, sz)
	fl.custom_minimum_size = sz
	fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fl.stretch_mode = TextureRect.STRETCH_SCALE
	fl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(fl)
	return p


func _btn_icon(b: Button, icon_name: String) -> void :
	if UiKit.has(icon_name):
		b.icon = UiKit.tex(icon_name)
		b.expand_icon = false
		b.add_theme_constant_override("h_separation", 6)


func _chip_pop(b: Control) -> void :
	b.pivot_offset = b.size * 0.5
	var tw: Tween = b.create_tween()
	tw.tween_property(b, "scale", Vector2(1.1, 1.1), 0.05)
	tw.tween_property(b, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake(c: Control) -> void :
	var x0: float = c.position.x
	var tw: Tween = c.create_tween()
	for i in 3:
		tw.tween_property(c, "position:x", x0 + 3.0, 0.03)
		tw.tween_property(c, "position:x", x0 - 3.0, 0.03)
	tw.tween_property(c, "position:x", x0, 0.0)


static func _mmss(t: float) -> String:
	var s: int = maxi(0, ceili(t))
	return "%d:%02d" % [s / 60, s % 60]


static func _k(v: float) -> String:
	return Loc.dec(Loc.t("%.1fК") % (v / 1000.0)) if v >= 1000.0 else str(roundi(v))


static func _plural(n: int, one: String, few: String, many: String) -> String:
	var n10: int = n % 10
	var n100: int = n % 100
	if n10 == 1 and n100 != 11:
		return one
	if n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14):
		return few
	return many
