extends Control






const AL = preload("res://game/alliances.gd")

var hud: Node
var gw: GameWorld
var aid: int = -1
var edit: bool = false
var st: Dictionary = {}
var refs: Dictionary = {}
var sheet: PanelContainer
var _name_i: int = 0
var _sent: bool = false
const LOGO_2X: float = 34.0
const LOGO_BIG: float = 51.0


static func open(h: Node, world: GameWorld, alliance_id: int, is_edit: bool = false) -> Control:
	var s: Control = (load("res://ui/ui24/ally_sheet.gd") as Script).new()
	s.hud = h
	s.gw = world
	s.aid = alliance_id
	s.edit = is_edit
	s.name = "AllySheet"
	(h.get("root") as Control).add_child(s)
	s.call("_build")
	return s


func _build() -> void :
	UiKit.ensure()
	var a: Dictionary = gw.diplo.ally.get_a(aid)
	if a.is_empty():
		queue_free()
		return
	st = {"name": String(a["name"]), "ci": int(a["ci"]), "logo": int(a["logo"])}
	_name_i = maxi(0, AL.NAMES.find(String(a["name"])))
	var vp: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = vp
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var small: bool = vp.y < 700.0
	sheet = PanelContainer.new()
	var ssb: StyleBox = UiKit.sb("wb_window", 10, 8 if small else 10)
	var sm: Vector2 = hud.call("_safe_margins") if hud.has_method("_safe_margins") else Vector2.ZERO
	ssb.content_margin_bottom = 10.0 + sm.y
	sheet.add_theme_stylebox_override("panel", ssb)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4 if small else 7)
	sheet.add_child(vb)

	var hr: = HBoxContainer.new()
	vb.add_child(hr)
	var tl: Label = UiKit.lbl(Loc.t("АЛЬЯНС") if edit else Loc.t("НОВЫЙ АЛЬЯНС"), 16 if small else 18, UiKit.TITLE, 3, 4)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tl)
	var x: Button = UiKit.close_btn(40.0 if small else 44.0)
	x.pressed.connect(_done)
	hr.add_child(x)
	var mem: PackedStringArray = PackedStringArray()
	for m: int in (a["members"] as Array):
		mem.append(gw.country_by_id(m).name)
	var ml: Label = UiKit.lbl((Loc.t("Участники: %s") if edit else Loc.t("Участники: %s · вы основатель")) % ", ".join(mem), 9, UiKit.MUTED, 1, 2)
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.custom_minimum_size.x = vp.x - 24.0
	vb.add_child(ml)

	var pv: = PanelContainer.new()
	pv.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 6, 4))
	vb.add_child(pv)
	var ph: = HBoxContainer.new()
	ph.add_theme_constant_override("separation", 8)
	ph.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_child(ph)
	var plogo: TextureRect = UiKit.icon_rect("ally_logo_0", LOGO_BIG)
	ph.add_child(plogo)
	var pname: Label = UiKit.lbl("", 15 if small else 17, UiKit.TEXT, 3, 4)
	pname.clip_text = true
	pname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(pname)

	vb.add_child(UiKit.lbl("ЗНАК", 10, UiKit.TITLE, 2, 3))
	var lg: = GridContainer.new()
	lg.columns = 5
	lg.add_theme_constant_override("h_separation", 6)
	lg.add_theme_constant_override("v_separation", 6)
	vb.add_child(lg)
	var cw: float = floorf((vp.x - 20.0 - 4.0 * 6.0) / 5.0)
	var lb: Array = []
	for i in AL.LOGOS:
		var b: = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(cw, 44.0 if small else 48.0)
		b.tooltip_text = String(AL.LOGO_NAMES[i])
		var ic: TextureRect = UiKit.icon_rect("ally_logo_%d" % i, LOGO_2X)
		b.add_child(ic)
		b.resized.connect( func() -> void : ic.position = ((b.size - ic.size) * 0.5).round())
		var li: int = i
		b.pressed.connect( func() -> void :
			st["logo"] = li
			_refresh())
		UiKit.press_fx(b)
		lg.add_child(b)
		lb.append([b, ic])

	vb.add_child(UiKit.lbl("ЦВЕТ", 10, UiKit.TITLE, 2, 3))
	var sww: float = floorf((vp.x - 20.0 - 7.0 * 5.0) / 8.0)
	var cr: = GridContainer.new()
	cr.columns = 8 if sww >= 44.0 else 4
	if cr.columns == 4:
		sww = floorf((vp.x - 20.0 - 3.0 * 5.0) / 4.0)
	cr.add_theme_constant_override("h_separation", 5)
	cr.add_theme_constant_override("v_separation", 5)
	vb.add_child(cr)
	var sw: Array = []
	for i2 in AL.COLOR_N:
		var b2: = Button.new()
		b2.focus_mode = Control.FOCUS_NONE
		b2.custom_minimum_size = Vector2(sww, 44.0)
		var fill: = ColorRect.new()
		fill.color = AL.COLORS[i2]
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b2.add_child(fill)
		var ck: TextureRect = UiKit.icon_rect("wb_check", 14)
		b2.add_child(ck)
		b2.resized.connect( func() -> void :
			fill.position = Vector2(5, 7)
			fill.size = b2.size - Vector2(10, 14)
			ck.position = ((b2.size - ck.size) * 0.5).round())
		var cii: int = i2
		b2.pressed.connect( func() -> void :
			st["ci"] = cii
			_refresh())
		UiKit.press_fx(b2)
		cr.add_child(b2)
		sw.append([b2, ck])

	var nh: = HBoxContainer.new()
	nh.add_theme_constant_override("separation", 6)
	vb.add_child(UiKit.lbl("НАЗВАНИЕ", 10, UiKit.TITLE, 2, 3))
	vb.add_child(nh)
	var le: = LineEdit.new()
	le.text = String(st["name"])
	le.max_length = AL.NAME_MAX
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size = Vector2(0, 44)
	le.add_theme_font_override("font", UiKit.f_black)
	le.add_theme_font_size_override("font_size", 14)
	le.add_theme_color_override("font_color", UiKit.TEXT)
	le.add_theme_color_override("caret_color", UiKit.GOLD)
	for s2: String in ["normal", "focus", "read_only"]:
		var fb: = StyleBoxFlat.new()
		fb.bg_color = Color(0.09, 0.1, 0.09)
		fb.border_color = UiKit.GOLD if s2 == "focus" else Color(0.45, 0.42, 0.33)
		fb.set_border_width_all(2)
		fb.set_corner_radius_all(3)
		fb.content_margin_left = 10
		fb.content_margin_right = 10
		le.add_theme_stylebox_override(s2, fb)
	le.text_changed.connect( func(s3: String) -> void :
		st["name"] = s3
		_refresh())
	nh.add_child(le)
	var rnd: Button = UiKit.big("ДРУГОЕ", "blue", "", 44.0, 10)
	rnd.custom_minimum_size.x = 84
	rnd.pressed.connect( func() -> void :
		_name_i = (_name_i + 1) % AL.NAMES.size()
		st["name"] = String(AL.NAMES[_name_i])
		le.text = String(st["name"])
		_refresh())
	nh.add_child(rnd)
	var ok: Button = UiKit.big(Loc.t("СОХРАНИТЬ") if edit else Loc.t("ОСНОВАТЬ"), "green", "", 44.0 if small else 46.0, 13)
	ok.pressed.connect(_done)
	vb.add_child(ok)
	refs = {"le": le, "lb": lb, "sw": sw, "ok": ok, "plogo": plogo, "pname": pname}
	_refresh()
	sheet.custom_minimum_size.x = vp.x
	_place()
	_place.call_deferred()
	UiKit.snd("ui_open")


func _place() -> void :
	if not is_instance_valid(sheet):
		return
	var vp: Vector2 = get_viewport_rect().size
	sheet.reset_size()
	sheet.size = Vector2(vp.x, sheet.get_combined_minimum_size().y)
	sheet.position = Vector2(0, maxf(0.0, vp.y - sheet.size.y))


func _refresh() -> void :
	var colr: Color = AL.COLORS[int(st["ci"])]
	for i in AL.LOGOS:
		var e: Array = refs["lb"][i]
		var on: bool = i == int(st["logo"])
		var s: StyleBox = UiKit.sb("wb_slot_active" if on else "wb_slot", 2)
		for k: String in ["normal", "hover", "pressed", "hover_pressed"]:
			(e[0] as Button).add_theme_stylebox_override(k, s)
		(e[0] as Button).add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		(e[1] as TextureRect).modulate = colr if on else Color(0.82, 0.8, 0.74)
	for i2 in AL.COLOR_N:
		var e2: Array = refs["sw"][i2]
		var on2: bool = i2 == int(st["ci"])
		var s2: StyleBox = UiKit.sb("wb_slot_active" if on2 else "wb_slot", 2)
		for k2: String in ["normal", "hover", "pressed", "hover_pressed"]:
			(e2[0] as Button).add_theme_stylebox_override(k2, s2)
		(e2[0] as Button).add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		(e2[1] as Control).visible = on2
	UiKit.set_icon(refs["plogo"], "ally_logo_%d" % int(st["logo"]), LOGO_BIG)
	(refs["plogo"] as TextureRect).modulate = colr
	(refs["pname"] as Label).text = String(st["name"]).strip_edges().to_upper()
	(refs["pname"] as Label).add_theme_color_override("font_color", colr.lightened(0.25))
	(refs["ok"] as Button).disabled = String(st["name"]).strip_edges() == ""


func _done() -> void :
	if _sent:
		return
	_sent = true
	var nm: String = String(st["name"]).strip_edges()
	if nm == "":
		nm = String(gw.diplo.ally.get_a(aid).get("name", "Альянс"))
	var le: Variant = refs.get("le")
	if le is LineEdit and is_instance_valid(le):
		(le as LineEdit).release_focus()
	var h: Node = hud
	NetSession.sim("diplo", "alliance_style", [gw.player.id, aid, nm, int(st["ci"]), int(st["logo"])], func(r: Variant) -> void :
		if h != null and is_instance_valid(h) and r is String and String(r) != "":
			h.call("show_toast", String(r))
		elif h != null and is_instance_valid(h):
			h.call("show_toast", Loc.t("Альянс «%s» основан") % nm if not edit else Loc.t("Альянс «%s»") % nm))
	queue_free()
