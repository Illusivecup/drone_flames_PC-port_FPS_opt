extends VBoxContainer






const Hub = preload("res://game/strike_hub.gd")
const HT = preload("res://ui/ui24/hold_tip.gd")
const CELL: = Vector2(50, 48)
const HOLD_T: float = 0.8

static var folded: bool = false

var main: Node
var hub
var _rail: Dictionary = {}
var _body: VBoxContainer
var _fold_row: HBoxContainer
var _title: Label
var _sub: Label
var _info: Label
var _warn: Label
var _extras: GridContainer
var _ex_btn: Dictionary = {}
var _cnt: Label
var _minus: Button
var _plus: Button
var _back: Button
var _sync: Array[Button] = []
var _fire: Button
var _fire2: Button
var _fold_lbl: Label
var _fold_ic: TextureRect
var _fill: Array = []
var _war: bool = false
var _t: float = 0.0
var _cur_mp: Dictionary = {}
var _sig: String = ""
var _last_pts: int = -1



func on_open() -> void :
	_last_pts = -1
	set_folded(false)


func setup(m: Node) -> void :
	main = m
	hub = m.strike
	name = "StrikeSheet"
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	var top: = HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(top)
	top.add_child(_build_rail())
	top.add_child(_build_right())
	_body.add_child(_build_bottom(false))
	_fold_row = _build_folded()
	add_child(_fold_row)
	_apply_fold()




func _build_rail() -> Control:
	var g: = GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	g.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for w: String in Hub.active_w_ids(main.world if main != null else null):
		var b: = Button.new()
		b.custom_minimum_size = CELL
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		UiKit._slot_styles(b, true)
		var ic: TextureRect = UiKit.icon_rect(Hub.icon(w), 26.0)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		var txt: String = Hub.short(w)
		var fs: int = 9
		if UiKit.f_bold != null:
			while fs > 6 and UiKit.f_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x > CELL.x - 4.0:
				fs -= 1
		var nm: Label = UiKit.lbl(txt, fs, UiKit.TEXT, 2, 3)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.clip_text = true
		b.add_child(nm)
		var rd: Label = UiKit.lbl("0", 10, UiKit.GOLD, 2, 3)
		rd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(rd)
		var bar: = ColorRect.new()
		bar.color = Hub.colour(w)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bar)
		var pt: = PanelContainer.new()
		var ps: = StyleBoxFlat.new()
		ps.bg_color = Hub.colour(w)
		ps.border_color = UiKit.OUTLINE
		ps.set_border_width_all(1)
		ps.set_corner_radius_all(2)
		ps.content_margin_left = 3
		ps.content_margin_right = 3
		pt.add_theme_stylebox_override("panel", ps)
		pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ptl: Label = UiKit.lbl("", 9, UiKit.OUTLINE, 2)
		pt.add_child(ptl)
		pt.visible = false
		b.add_child(pt)
		var lay: = func() -> void :
			var dy: float = 1.0 if b.button_pressed else 0.0
			ic.position = Vector2(roundf((b.size.x - ic.size.x) * 0.5), 4.0 + dy)
			nm.position = Vector2(1, b.size.y - 18.0 + dy)
			nm.size = Vector2(b.size.x - 2.0, 14)
			rd.position = Vector2(b.size.x - 28.0, 1.0)
			rd.size = Vector2(25, 14)
			bar.position = Vector2(5, b.size.y - 5.0)
			bar.size = Vector2(b.size.x - 10.0, 2)
			pt.position = Vector2(3, 3)
		b.resized.connect(lay)
		b.toggled.connect( func(_on: bool) -> void : lay.call())
		b.pressed.connect( func() -> void :
			b.set_pressed_no_signal(hub.cur == w)
			if hub.cur != w:
				main.strike_pick(w))
		UiKit.press_fx(b)
		HT.key(b, "w_" + w)
		g.add_child(b)
		_rail[w] = {"b": b, "ic": ic, "rd": rd, "pt": pt, "ptl": ptl, "nm": nm, "bar": bar}
	return g


func _build_right() -> Control:
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head: = HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var tc: = VBoxContainer.new()
	tc.add_theme_constant_override("separation", 0)
	tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tc)
	_title = UiKit.lbl("", 13, UiKit.TITLE, 3, 3)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tc.add_child(_title)
	_sub = UiKit.lbl("", 9, UiKit.MUTED, 1)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.max_lines_visible = 2
	_sub.add_theme_constant_override("line_spacing", -2)
	tc.add_child(_sub)
	var fb: Button = _chev_btn(true)
	fb.pressed.connect( func() -> void :
		folded = true
		_apply_fold())
	head.add_child(fb)
	var cl: Button = UiKit.close_btn(42.0)
	cl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cl.pressed.connect( func() -> void :
		UiKit.snd("ui_close")
		main.strike_close())
	head.add_child(cl)
	_info = UiKit.lbl("", 10, UiKit.TEXT, 2, 2)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.max_lines_visible = 3
	col.add_child(_info)
	_extras = GridContainer.new()
	_extras.columns = 2
	_extras.add_theme_constant_override("h_separation", 4)
	_extras.add_theme_constant_override("v_separation", 4)
	col.add_child(_extras)
	for e: Array in [["route", "МАРШРУТ"], ["plan_standing", "АВТОПУСК"], ["smart_toggle", "УМНЫЕ БПЛА"]]:
		var xb: Button = UiKit.big(String(e[1]), "stone", "", 44.0, 10)
		xb.toggle_mode = true
		xb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xb.custom_minimum_size.x = 0
		var act: String = String(e[0])
		xb.pressed.connect( func() -> void :
			main._on_action(act)
			_ex_sync())
		var xl: String = String(e[1])
		HT.tip(xb, func() -> String: return "%s: %s — %s" % [xl, Loc.t("ВКЛ") if xb.button_pressed else Loc.t("ВЫКЛ"), HT.line(act)])
		for stn: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var sbx: StyleBox = xb.get_theme_stylebox(stn)
			if sbx != null:
				sbx = sbx.duplicate()
				sbx.content_margin_left = 3.0
				sbx.content_margin_right = 3.0
				xb.add_theme_stylebox_override(stn, sbx)
		_extras.add_child(xb)
		_ex_btn[act] = xb
	for ab in [["isk_he", Loc.t("ФУГАС"), "he"], ["isk_cluster", Loc.t("КАССЕТА"), "cluster"]]:
		var tb: Button = UiKit.big(String(ab[1]), "stone", "", 44.0, 10)
		tb.toggle_mode = true
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size.x = 0
		var am_t: String = String(ab[2])
		tb.pressed.connect(func() -> void:
			if main.world != null:
				main.world.set_meta("iskander_strike_ammo", am_t)
			_ex_sync())
		for stn: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var sbx: StyleBox = tb.get_theme_stylebox(stn)
			if sbx != null:
				sbx = sbx.duplicate()
				sbx.content_margin_left = 3.0
				sbx.content_margin_right = 3.0
				tb.add_theme_stylebox_override(stn, sbx)
		_extras.add_child(tb)
		_ex_btn[String(ab[0])] = tb
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	col.add_child(row)
	var minus: Button = UiKit.big("−", "stone", "", 44.0, 16)
	minus.custom_minimum_size.x = 44
	minus.pressed.connect( func() -> void : main._on_action("plan_minus"))
	HT.tip(minus, "МЕНЬШЕ — на одну единицу меньше на каждую цель")
	row.add_child(minus)
	_minus = minus
	_cnt = UiKit.lbl("×1", 13, UiKit.GOLD, 3, 3)
	_cnt.custom_minimum_size = Vector2(34, 0)
	_cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_cnt)
	var plus: Button = UiKit.big("+", "stone", "", 44.0, 16)
	plus.custom_minimum_size.x = 44
	plus.pressed.connect( func() -> void : main._on_action("plan_plus"))
	HT.tip(plus, "БОЛЬШЕ — на одну единицу больше на каждую цель")
	row.add_child(plus)
	_plus = plus
	_back = UiKit.big("НАЗАД", "stone", "", 44.0, 11)
	_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back.pressed.connect( func() -> void : main._on_action("plan_back"))
	HT.tip(_back, "НАЗАД — убрать последнюю поставленную цель")
	row.add_child(_back)
	return col


func _build_bottom(_compact: bool) -> Control:
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warn = UiKit.lbl("", 9, UiKit.RED, 2, 2)
	_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warn.max_lines_visible = 2
	_warn.visible = false
	vb.add_child(_warn)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	vb.add_child(row)
	for i in 2:
		var sb: Button = UiKit.big(Loc.t("ПРИЛЁТ\nВМЕСТЕ") if i == 0 else Loc.t("СРАЗУ"), "stone", "", 48.0, 9)
		sb.toggle_mode = true
		sb.custom_minimum_size.x = 64
		sb.add_theme_stylebox_override("pressed", UiKit.sb("wb_btn_gold_p", 12, 4, 1))
		sb.add_theme_stylebox_override("hover_pressed", UiKit.sb("wb_btn_gold_p", 12, 4, 1))
		sb.pressed.connect( func() -> void :
			Hub.sync_arrive = i == 0
			_sync_sync())
		HT.tip(sb, Loc.t("ПРИЛЁТ ВМЕСТЕ — оружие стартует с задержкой, чтобы всё прилетело одновременно") if i == 0 else Loc.t("СРАЗУ — каждое оружие стартует, как только готово"))
		row.add_child(sb)
		_sync.append(sb)
	_fire = _fire_btn(48.0)
	_fire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_fire)
	_sync_sync()
	return vb


func _build_folded() -> HBoxContainer:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var slot: = PanelContainer.new()
	slot.add_theme_stylebox_override("panel", UiKit.sb("wb_slot", 3))
	slot.custom_minimum_size = Vector2(44, 44)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(slot)
	var cc: = CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cc)
	_fold_ic = UiKit.icon_rect("icon_target", 28.0)
	cc.add_child(_fold_ic)
	_fold_lbl = UiKit.lbl("", 10, UiKit.TEXT, 2, 2)
	_fold_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fold_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fold_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fold_lbl.max_lines_visible = 2
	row.add_child(_fold_lbl)
	_fire2 = _fire_btn(44.0)
	_fire2.custom_minimum_size.x = 104
	row.add_child(_fire2)
	var ub: Button = _chev_btn(false)
	ub.pressed.connect( func() -> void :
		folded = false
		_apply_fold())
	row.add_child(ub)
	return row



func _chev_btn(down: bool) -> Button:
	var b: Button = UiKit.big("", "stone", "", 42.0, 10)
	b.custom_minimum_size = Vector2(44, 42)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var c: = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(c)
	b.resized.connect( func() -> void :
		c.size = b.size
		c.queue_redraw())
	c.draw.connect( func() -> void :
		var m: Vector2 = c.size * 0.5 + Vector2(0, -1)
		var s: float = 7.0
		var pts: = PackedVector2Array([m + Vector2( - s, -3 if down else 3), m + Vector2(0, 4 if down else -4), m + Vector2(s, -3 if down else 3)])
		c.draw_polyline(pts, UiKit.OUTLINE, 6.0)
		c.draw_polyline(pts, UiKit.TEXT, 3.0))
	return b



func _fire_btn(h: float) -> Button:
	var b: Button = UiKit.big("УДАР", "green", "", h, 14)
	var clip: = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(clip)
	var fill: = Panel.new()
	fill.add_theme_stylebox_override("panel", UiKit.sb("wb_btn_gold", 12, 4))
	fill.modulate = Color(1, 1, 1, 0.55)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(fill)
	clip.size = Vector2(0, h)
	b.resized.connect( func() -> void :
		clip.size = Vector2(clip.size.x, b.size.y)
		fill.size = b.size)
	_fill.append([clip, fill])
	b.button_down.connect( func() -> void :
		if not _war or b.disabled:
			return
		var tw: Tween = b.create_tween()
		tw.tween_property(clip, "size:x", b.size.x, HOLD_T).set_trans(Tween.TRANS_LINEAR)
		tw.tween_callback( func() -> void :
			if is_instance_valid(b) and b.is_pressed() and b.is_visible_in_tree():
				clip.size.x = 0.0
				main.strike_fire())
		b.set_meta("tw", tw))
	b.button_up.connect( func() -> void :
		var tw0: Variant = b.get_meta("tw") if b.has_meta("tw") else null
		if tw0 is Tween and (tw0 as Tween).is_valid():
			(tw0 as Tween).kill()
		if clip.size.x > 0.0:
			var back: Tween = b.create_tween()
			back.tween_property(clip, "size:x", 0.0, 0.12))
	b.pressed.connect( func() -> void :
		if not _war:
			main.strike_fire())
	return b


func set_folded(on: bool) -> void :
	folded = on
	_apply_fold()


func _apply_fold() -> void :
	_body.visible = not folded
	_fold_row.visible = folded
	_sig = ""


func _sync_sync() -> void :
	for i in _sync.size():
		_sync[i].set_pressed_no_signal((i == 0) == Hub.sync_arrive)


func _ex_sync() -> void :
	var p: Country = main.world.player
	if p == null:
		return
	if _ex_btn.has("route"):
		(_ex_btn["route"] as Button).set_pressed_no_signal(bool(main.route_mode))
	if _ex_btn.has("plan_standing"):
		(_ex_btn["plan_standing"] as Button).set_pressed_no_signal(bool(main._standing_on()))
	var mil = main.world.mil
	if _ex_btn.has("smart_toggle"):
		(_ex_btn["smart_toggle"] as Button).set_pressed_no_signal(mil.has_method("smart_of") and bool(mil.smart_of(p.id)))
	for k9: String in ["route", "plan_standing", "smart_toggle"]:
		if _ex_btn.has(k9):
			var b9: Button = _ex_btn[k9]
			_set_btn(b9, "%s\n%s" % [{"route": Loc.t("МАРШРУТ"), "plan_standing": Loc.t("АВТОПУСК"), "smart_toggle": Loc.t("УМНЫЕ БПЛА")}[k9], Loc.t("ВКЛ") if b9.button_pressed else Loc.t("ВЫКЛ")])

	var cur_ammo: String = String(main.world.get_meta("iskander_strike_ammo", "he"))
	if _ex_btn.has("isk_he"):
		var bhe: Button = _ex_btn["isk_he"]
		bhe.set_pressed_no_signal(cur_ammo == "he")
		_set_btn(bhe, "%s\n%s" % [Loc.t("ФУГАС"), Loc.t("ВКЛ") if cur_ammo == "he" else Loc.t("ВЫКЛ")])
	if _ex_btn.has("isk_cluster"):
		var bcl: Button = _ex_btn["isk_cluster"]
		bcl.set_pressed_no_signal(cur_ammo == "cluster")
		_set_btn(bcl, "%s\n%s" % [Loc.t("КАССЕТА"), Loc.t("ВКЛ") if cur_ammo == "cluster" else Loc.t("ВЫКЛ")])




func _set_txt(l: Label, t: String) -> void :
	if l.text != t:
		l.text = t



func refresh(delta: float) -> void :
	var gw: GameWorld = main.world
	if gw == null or gw.player == null:
		return
	var cur: String = hub.cur
	var cur_t: Array = main._plan_targets()
	var rdy: Dictionary = hub.ready_all(gw)
	_t -= delta
	var tsig: String = "%s|%d|%d" % [cur, cur_t.size(), Hub.n_of(cur_t)]
	if _t <= 0.0 or tsig != _sig:
		_t = 0.25
		_sig = tsig
		_cur_mp = Hub.plan(gw, cur, cur_t) if not cur_t.is_empty() else {}
		var av: int = int((rdy.get(cur, [0, ""]) as Array)[0])
		if cur == "ship" or cur == "art" or cur == "bomber" or cur == "hyper" or cur == "thermo" or cur == "nuke" or cur == "iskander":
			main._plan_info = {"available": av}

	var all_n: int = 0
	var n_w: int = 0
	var all_t: Array = []
	for w: String in _rail:
		var r: Dictionary = _rail[w]
		var ts: Array = cur_t if w == cur else hub.plans.get(w, [])
		var npt: int = ts.size()
		var nn: int = Hub.n_of(ts)
		if npt > 0:
			all_n += nn
			n_w += 1
			all_t.append_array(ts)
		var ready: int = int((rdy.get(w, [0, ""]) as Array)[0])
		var b: Button = r["b"]
		if b.button_pressed != (w == cur):
			b.set_pressed_no_signal(w == cur)
			b.resized.emit()
		elif absf((r["nm"] as Label).size.x - b.size.x) > 0.5:
			b.resized.emit()
		_set_txt(r["rd"], str(ready) if ready < 100 else "99+")
		(r["rd"] as Label).add_theme_color_override("font_color", UiKit.GOLD if ready > 0 else UiKit.DIM)
		var dim: bool = ready == 0 and npt == 0
		var mc: Color = Color(0.55, 0.55, 0.55, 0.85) if dim else Color.WHITE
		if (r["ic"] as TextureRect).modulate != mc:
			(r["ic"] as TextureRect).modulate = mc
			(r["nm"] as Label).modulate = mc
		(r["pt"] as Control).visible = npt > 0
		_set_txt(r["ptl"], "%d·%d" % [npt, nn] if nn != npt else str(npt))


	if _last_pts >= 0 and all_t.size() > _last_pts and not folded and get_viewport_rect().size.y < 720.0:
		set_folded(true)
	_last_pts = all_t.size()

	var cr: Array = rdy.get(cur, [0, ""])
	_set_txt(_title, Hub.title(cur).to_upper())
	_title.add_theme_color_override("font_color", Hub.colour(cur).lightened(0.15))
	var sub: String = (Loc.t("ГОТОВО: %d · %s") % [int(cr[0]), Loc.t(String(Hub.W_INFO[cur]["sub"]))]).to_upper() if int(cr[0]) > 0 else (Loc.t("НЕ ГОТОВО · %s") % Loc.t(String(Hub.W_INFO[cur]["sub"]))).to_upper()
	if cur == "bomber" and gw.mil.air.cr_q_left(gw.player.id) > 0:
		var qp: Array = gw.mil.air.cr_q_progress(gw.player.id)
		sub = Loc.t("ОЧЕРЕДЬ КР: %d/%d ВЫПУЩЕНО") % [int(qp[0]), int(qp[1])]
	_set_txt(_sub, sub)
	var info: String = ""
	var bad: bool = false
	if int(cr[0]) == 0 and cur_t.is_empty():
		info = String(cr[1]).to_upper() if String(cr[1]) != "" else Loc.t("НЕТ ГОТОВЫХ СРЕДСТВ")
		bad = true
	elif cur_t.is_empty():
		info = Loc.t("МАРШРУТ: ТАП ПО КАРТЕ = ТОЧКА") if bool(main.route_mode) else Loc.t("ТАП ПО КАРТЕ = ЦЕЛЬ\nЕЩЁ ТАП ПО ТОЧКЕ = +1")
	else:
		var asg: int = int(_cur_mp.get("assigned", 0))
		var tot: int = int(_cur_mp.get("total", Hub.n_of(cur_t)))
		info = Loc.t("ЦЕЛЕЙ %d · %s %d ИЗ %d") % [cur_t.size(), Loc.t(String(Hub.W_INFO[cur]["unit"])).to_upper(), asg, tot]
		var et: float = Hub.eta(gw, cur, _cur_mp) if asg > 0 else 0.0
		if et > 0.0:
			info += Loc.t(" · ПРИЛЁТ %s") % _mmss(et)
		for pt: Dictionary in _cur_mp.get("per_target", []):
			var rs: String = String(pt.get("reason", ""))
			if rs != "":
				info += "\n" + rs.to_upper()
				bad = bad or int(pt.get("got", pt.get("launch", 0))) == 0
				break
		if asg == 0:
			bad = true
			if String(_cur_mp.get("why", "")) != "" and info.find("\n") < 0:
				info += "\n" + String(_cur_mp["why"]).to_upper()
		if bool(main.route_mode):
			info += Loc.t("\nМАРШРУТ: ТАП = ТОЧКА, ТАП ПО ТОЧКЕ = УБРАТЬ")
	_set_txt(_info, info)
	_info.add_theme_color_override("font_color", UiKit.RED if bad else UiKit.TEXT)
	var drone: bool = cur == "drone" or cur == "jet"
	var is_isk: bool = cur == "iskander"
	if _extras.visible != (drone or is_isk):
		_extras.visible = (drone or is_isk)
	for dk: String in ["route", "plan_standing", "smart_toggle"]:
		if _ex_btn.has(dk):
			(_ex_btn[dk] as Button).visible = drone
	for tk: String in ["isk_he", "isk_cluster"]:
		if _ex_btn.has(tk):
			(_ex_btn[tk] as Button).visible = is_isk
	if drone or is_isk:
		_ex_sync()
	if cur == "thermo" or cur == "nuke" or cur == "iskander":
		var av_mod: int = int((rdy.get(cur, [0, ""]) as Array)[0])
		var tot_mod: int = Hub.n_of(cur_t)
		if _plus != null:
			_plus.disabled = (tot_mod >= av_mod or av_mod <= 0)
		if _minus != null:
			_minus.disabled = (main.plan_count <= 1 and (cur_t.is_empty() or tot_mod <= cur_t.size()))
		if av_mod > 0 and main.plan_count > av_mod:
			main.plan_count = av_mod
	_set_txt(_cnt, "×%d" % int(main.plan_count))
	_back.disabled = cur_t.is_empty()

	var notes: Array = Hub.war_notes(gw, all_t)
	var wt: String = "\n".join(PackedStringArray(notes)).to_upper()
	_set_txt(_warn, wt)
	if _warn.visible != (wt != "" and not folded):
		_warn.visible = wt != "" and not folded
	_war = wt != ""
	var ft: String = (Loc.t("УДАР · ВОЙНА") if _war else Loc.t("УДАР")) + (" ×%d" % all_n if all_n > 0 else "")
	for fb: Button in [_fire, _fire2]:
		_set_btn(fb, ft)
		fb.disabled = all_n == 0
		var col: String = "red" if _war else "green"
		if String(fb.get_meta("col", "")) != col:
			fb.set_meta("col", col)
			fb.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_" + col, 12, 4, -1))
			fb.add_theme_stylebox_override("hover", UiKit.sb("wb_btn_" + col, 12, 4, -1))
			fb.add_theme_stylebox_override("pressed", UiKit.sb("wb_btn_" + col + "_p", 12, 4, 1))
			fb.add_theme_stylebox_override("hover_pressed", UiKit.sb("wb_btn_" + col + "_p", 12, 4, 1))

	if folded:
		if String(_fold_ic.get_meta("ic", "")) != Hub.icon(cur):
			UiKit.set_icon(_fold_ic, Hub.icon(cur), 28.0)
			_fold_ic.set_meta("ic", Hub.icon(cur))
		var ft2: String = Loc.t("%s · %d ЦЕЛ.") % [Hub.short(cur), cur_t.size()]
		if n_w > 1:
			ft2 = Loc.t("ОРУЖИЙ %d · ЦЕЛЕЙ %d") % [n_w, all_t.size()]
		if _war:
			ft2 += Loc.t("\nУДАР НАЧНЁТ ВОЙНУ")
		_set_txt(_fold_lbl, ft2)


func _set_btn(b: Button, t: String) -> void :
	if b.text != t:
		b.text = t


static func _mmss(sec: float) -> String:
	var t: int = maxi(0, int(ceil(sec)))
	return "%d:%02d" % [t / 60, t % 60]
