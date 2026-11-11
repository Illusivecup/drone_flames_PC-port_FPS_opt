class_name MpKit
extends RefCounted





const ROW_H: float = 56.0
const SLOT_H: float = 48.0

const SEV: Dictionary = {"info": UiKit.BLUE, "wait": UiKit.GOLD, "alarm": UiKit.RED, "ok": UiKit.GREEN}


static func _flat(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, r: int = 0) -> StyleBoxFlat:
	var s: = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(r)
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	return s



static func card_button(h: float) -> Button:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	var n: StyleBox = UiKit.sb("wb_panel_dark", 8, 2)
	var p: StyleBox = UiKit.sb("wb_panel", 8, 2)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func _hbox(parent: Control, sep: int = 8, pad: float = 10.0) -> HBoxContainer:
	var row: = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = pad
	row.offset_right = - pad
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", sep)
	parent.add_child(row)
	return row


static func _two_lines(parent: Control, top: String, sub: String, top_size: int = 13, top_col: Color = UiKit.TEXT) -> VBoxContainer:
	var v: = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 1)
	parent.add_child(v)
	var t: Label = UiKit.lbl(top, top_size, top_col, 3, 2)
	v.add_child(t)
	if sub != "":
		var s: Label = UiKit.lbl(sub, 10, UiKit.MUTED, 1, 1)
		v.add_child(s)
	return v


static func icon(n: String, x2: bool = false) -> TextureRect:
	var r: TextureRect = UiKit.icon_rect(n, 32.0 if x2 else 16.0)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r



static func spin(r: Control) -> void :
	r.pivot_offset = r.custom_minimum_size * 0.5
	var tw: Tween = r.create_tween().set_loops()
	for i in 4:
		tw.tween_interval(0.12)
		tw.tween_callback( func() -> void :
			if is_instance_valid(r):
				r.rotation_degrees = fmod(r.rotation_degrees + 90.0, 360.0))




static func room_row(parent: Control, host_nick: String, sub: String, n: int, max_n: int, ok: bool, on_tap: Callable) -> Button:
	var b: Button = card_button(ROW_H)
	parent.add_child(b)
	var row: HBoxContainer = _hbox(b)
	var badge: = HBoxContainer.new()
	badge.custom_minimum_size = Vector2(52, 0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_constant_override("separation", 4)
	row.add_child(badge)
	badge.add_child(icon("net_players"))
	var nl: Label = UiKit.lbl("%d/%d" % [n, max_n], 14, UiKit.GOLD, 3, 2)
	nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(nl)
	_two_lines(row, host_nick if host_nick != "" else "Комната", sub)
	if ok:
		var pill: = PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pill.add_theme_stylebox_override("panel", UiKit.sb("wb_btn_blue", 8, 2))
		pill.custom_minimum_size = Vector2(64, 30)
		var pl: Label = UiKit.lbl("ВОЙТИ", 11, UiKit.TEXT, 3, 2)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pill.add_child(pl)
		row.add_child(pill)
	else:
		b.modulate.a = 0.55
		row.add_child(icon("net_warn"))
	b.pressed.connect( func() -> void :
		UiKit.press_fx(b)
		on_tap.call())
	return b



static func placeholder(parent: Control, icon_name: String, title: String, sub: String, turning: bool = false, h: float = ROW_H) -> PanelContainer:
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 6))
	p.custom_minimum_size = Vector2(0, h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var v: = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var cc: = CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cc)
	var ic: TextureRect = icon(icon_name, true)
	if not turning:
		ic.modulate.a = 0.6
	cc.add_child(ic)
	if turning:
		spin(ic)
	var t: Label = UiKit.lbl(title, 12, UiKit.TEXT, 3, 2)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	if sub != "":
		var s: Label = UiKit.lbl(sub, 10, UiKit.MUTED, 1, 1)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	return p



static func section(parent: Control, text: String, icon_name: String = "", turning: bool = false, on_tap: Callable = Callable()) -> Button:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var l: Label = UiKit.lbl(text, 11, UiKit.GOLD, 3, 3)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var line: = ColorRect.new()
	line.color = Color(UiKit.GOLD, 0.35)
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	if icon_name == "":
		return null
	if on_tap.is_valid():
		var b: Button = UiKit.slot(icon_name, false, 44.0)
		b.pressed.connect(on_tap)
		row.add_child(b)
		if turning:
			spin(UiKit.slot_icon(b))
		return b
	var ic: TextureRect = icon(icon_name)
	row.add_child(ic)
	if turning:
		spin(ic)
	return null



static func tabs(parent: Control, items: Array, active: int, on_pick: Callable) -> HBoxContainer:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	for i in items.size():
		var it: Array = items[i]
		var b: Button = UiKit.big(String(it[1]), "stone", "", 44.0, 13)
		if i == active:
			for st: String in ["normal", "hover", "pressed", "hover_pressed"]:
				b.add_theme_stylebox_override(st, UiKit.sb("wb_tab_active", 12, 4))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t: Texture2D = UiKit.tex(String(it[0]))
		if t != null:
			b.icon = t
			b.expand_icon = false
			b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_constant_override("h_separation", 6)
		if it.size() > 2 and not bool(it[2]):
			b.modulate.a = 0.55
		var idx: int = i
		b.pressed.connect( func() -> void : on_pick.call(idx))
		row.add_child(b)
	return row



static func choice_card(parent: Control, icon_name: String, title: String, sub: String, on: bool, on_tap: Callable) -> Button:
	var b: Button = card_button(64.0)
	if on:

		var s: StyleBox = UiKit.sb("wb_slot_active", 8, 2)
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("hover", s)
		b.add_theme_stylebox_override("pressed", s)
	parent.add_child(b)
	var row: HBoxContainer = _hbox(b, 10, 12)
	row.add_child(icon(icon_name, true))
	_two_lines(row, title, sub, 13, UiKit.TEXT if on else UiKit.MUTED)
	if on and UiKit.tex("icon_ok") != null:
		row.add_child(UiKit.icon_rect("icon_ok", 16.0))
	b.pressed.connect( func() -> void :
		UiKit.press_fx(b)
		on_tap.call())
	return b



static func status_bar(parent: Control, text: String, sev: String = "alarm", icon_name: String = "", turning: bool = false, upper: bool = true) -> PanelContainer:
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 4))
	p.custom_minimum_size = Vector2(0, 36)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var stripe: = ColorRect.new()
	stripe.color = SEV.get(sev, UiKit.RED)
	stripe.custom_minimum_size = Vector2(4, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stripe)
	if icon_name != "":
		var ic: TextureRect = icon(icon_name)
		row.add_child(ic)
		if turning:
			spin(ic)
	var l: Label = UiKit.lbl(text.to_upper() if upper else text, 11, UiKit.TEXT, 2, 2)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	return p



static func slot_row(parent: Control, idx: int, nick: String, host: bool, you: bool, sub: String = "", waiting: bool = false, cos: Dictionary = {}, flag: String = "") -> PanelContainer:
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 2))
	p.custom_minimum_size = Vector2(0, SLOT_H)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var num: Label = UiKit.lbl("%d" % (idx + 1), 12, UiKit.DIM, 3, 2)
	num.custom_minimum_size = Vector2(14, 0)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(num)
	if nick == "":
		p.modulate.a = 0.8 if waiting else 0.7
		var e: Label = UiKit.lbl("ЖДЁМ ИГРОКА..." if waiting else "СВОБОДНО", 12, UiKit.MUTED if waiting else UiKit.DIM, 2, 2)
		e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(e)
		return p
	if host:
		row.add_child(icon("net_host"))
	if flag != "":
		var fp: PanelContainer = FlagEditor.flag_pic(flag, 24, 16, 1, 1)
		fp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(fp)
	if not cos.is_empty():
		p.custom_minimum_size.y = SLOT_H + 4
		banner_bg(p, cos.get("banner"))
		var a_tex: Texture2D = Account.get_avatar_texture(String(cos.get("avatar_b64", "")))
		row.add_child(avatar_framed(cos.get("frame"), 48.0, a_tex))
		var v: = VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 1)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(v)
		var nh: = HBoxContainer.new()
		nh.add_theme_constant_override("separation", 4)
		nh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(nh)
		var is_d: bool = Account.is_dev_name(nick) or bool(cos.get("is_dev", false))
		var nl: Label = UiKit.lbl(nick, 13, UiKit.GOLD if is_d else UiKit.TEXT, 3, 2)
		nh.add_child(nl)
		if is_d:
			nh.add_child(dev_badge_button(nick))
		var tc: String = Cosmetics.shown("title", cos.get("title"))
		if tc != "":
			var tl2: Control = title_label(tc, 10)
			v.add_child(tl2)
		elif sub != "":
			var sl: Label = UiKit.lbl(sub, 10, UiKit.MUTED, 1, 1)
			v.add_child(sl)
	else:
		_two_lines(row, nick, sub)
	if you:
		var tag: = PanelContainer.new()
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.add_theme_stylebox_override("panel", _flat(UiKit.GOLD, UiKit.OUTLINE, 1))
		var tl: Label = UiKit.lbl("ВЫ", 10, UiKit.OUTLINE, 3, 0)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.custom_minimum_size = Vector2(32, 18)
		tag.add_child(tl)
		row.add_child(tag)
	return p



static func code_block(parent: Control, code: String, on_copy: Callable) -> Button:
	var b: Button = card_button(72.0)
	parent.add_child(b)
	var row: HBoxContainer = _hbox(b, 10, 12)
	row.add_child(icon("net_code", true))
	var v: VBoxContainer = _two_lines(row, "", "")
	v.get_child(0).queue_free()
	var cap: Label = UiKit.lbl("КОД КОМНАТЫ", 10, UiKit.MUTED, 1, 1)
	cap.custom_minimum_size = Vector2(0, 14)
	v.add_child(cap)
	var cl: Label = UiKit.lbl("%s-%s" % [code.left(3), code.substr(3)], 26, UiKit.GOLD, 3, 3)
	v.add_child(cl)
	var cp: TextureRect = icon("net_copy", true)
	row.add_child(cp)
	b.pressed.connect( func() -> void :
		UiKit.press_fx(b)
		on_copy.call()
		UiKit.set_icon(cp, "icon_ok" if UiKit.tex("icon_ok") != null else "net_copy", 32.0)
		cap.text = "СКОПИРОВАНО"
		cap.add_theme_color_override("font_color", UiKit.GREEN)
		b.get_tree().create_timer(1.5).timeout.connect( func() -> void :
			if is_instance_valid(cp):
				UiKit.set_icon(cp, "net_copy", 32.0)
				cap.text = "КОД КОМНАТЫ"
				cap.add_theme_color_override("font_color", UiKit.MUTED)))
	return b



static func style_row(parent: Control, arch: int, on_tap: Callable) -> Button:
	var b: Button = card_button(60.0)
	parent.add_child(b)
	var row: HBoxContainer = _hbox(b, 10, 8)
	row.add_child(style_card(arch, 1))
	var v: VBoxContainer = _two_lines(row, "ВАШ ОБЛИК", "")
	(v.get_child(0) as Label).add_theme_font_size_override("font_size", 10)
	(v.get_child(0) as Label).add_theme_color_override("font_color", UiKit.MUTED)
	var nm: Label = UiKit.lbl(String(ArchStyle.NAMES[clampi(arch, 0, 3)]), 12, UiKit.GOLD, 3, 2)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.max_lines_visible = 2
	v.add_child(nm)
	var pill: = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", UiKit.sb("wb_btn_blue", 8, 2))
	pill.custom_minimum_size = Vector2(80, 36)
	var pl: Label = UiKit.lbl("ИЗМЕНИТЬ", 10, UiKit.TEXT, 3, 2)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(pl)
	row.add_child(pill)
	b.pressed.connect( func() -> void :
		UiKit.press_fx(b)
		on_tap.call())
	return b



const CLOSE_UP: Array = [Vector2(1, 0), Vector2(0, 16), Vector2(0, 8), Vector2(32, 14)]


static func style_card(arch: int, scale_i: int) -> TextureRect:
	var r: = TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = Vector2(68, 56) * scale_i
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ResourceLoader.exists("res://assets/sprites/style_cards31.png"):
		var at: = AtlasTexture.new()
		at.atlas = load("res://assets/sprites/style_cards31.png") as Texture2D
		var a: int = clampi(arch, 0, 3)
		at.region = Rect2(a * 68, 0, 68, 56)
		if scale_i <= 1:
			at.region = Rect2(a * 68 + int(CLOSE_UP[a].x), int(CLOSE_UP[a].y), 34, 28)
		r.texture = at
	return r






class Plate extends PanelContainer:
	var stripe: ColorRect
	var ic: TextureRect
	var title: Label
	var sub: Label
	var timer: Label
	var _key: String = ""
	var _want: String = ""
	var _want_t: float = 0.0
	var _shown_t: float = 0.0
	var _pulse: Tween = null
	var _spin: Tween = null

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 6, 4))
		custom_minimum_size = Vector2(0, 44)
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		stripe = ColorRect.new()
		stripe.custom_minimum_size = Vector2(4, 0)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(stripe)
		ic = UiKit.icon_rect("net_sync", 32.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var v: = VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(v)
		title = UiKit.lbl("", 12, UiKit.TEXT, 3, 2)
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(title)
		sub = UiKit.lbl("", 10, UiKit.MUTED, 1, 1)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(sub)
		timer = UiKit.lbl("", 14, UiKit.GOLD, 3, 2)
		timer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(timer)
		visible = false
		modulate.a = 0.0



	func set_state(st: Dictionary, delta: float) -> void :
		var k: String = String(st.get("key", ""))
		if k != _want:
			_want = k
			_want_t = 0.0
		_want_t += delta
		if visible:
			_shown_t += delta
		var go_k: String = _key
		if k != _key and _want_t >= (0.5 if k != "" else 0.0) and (_key == "" or _shown_t >= 1.0):
			go_k = k
		if go_k != _key:
			_key = go_k
			_shown_t = 0.0
			_switch(st if go_k == k else {})
		if _key != "" and _key == k:
			title.text = String(st.get("title", ""))
			sub.text = String(st.get("sub", ""))
			timer.text = String(st.get("timer", ""))
			timer.add_theme_color_override("font_color", UiKit.RED if bool(st.get("urgent", false)) else UiKit.GOLD)

	func _switch(st: Dictionary) -> void :
		if _pulse != null:
			_pulse.kill()
		if _spin != null:
			_spin.kill()
		ic.rotation_degrees = 0.0
		if st.is_empty():
			var tw: Tween = create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.25)
			tw.tween_callback( func() -> void : visible = false)
			return
		var col: Color = MpKit.SEV.get(String(st.get("sev", "info")), UiKit.BLUE)
		stripe.color = col
		stripe.modulate.a = 1.0
		UiKit.set_icon(ic, String(st.get("icon", "net_sync")), 32.0)
		ic.pivot_offset = ic.custom_minimum_size * 0.5
		title.add_theme_color_override("font_color", col.lerp(UiKit.TEXT, 0.35))
		visible = true
		create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
		match String(st.get("sev", "info")):
			"wait":
				_pulse = stripe.create_tween().set_loops()
				_pulse.tween_property(stripe, "modulate:a", 0.5, 0.6)
				_pulse.tween_property(stripe, "modulate:a", 1.0, 0.6)
			"alarm":
				_pulse = ic.create_tween().set_loops(4)
				_pulse.tween_property(ic, "modulate:a", 0.25, 0.25)
				_pulse.tween_property(ic, "modulate:a", 1.0, 0.25)
		if bool(st.get("spin", false)):
			_spin = ic.create_tween().set_loops()
			_spin.tween_interval(0.125)
			_spin.tween_callback( func() -> void : ic.rotation_degrees = fmod(ic.rotation_degrees + 90.0, 360.0))






static func field(parent: Control, caption: String, placeholder: String, kind: String = "text") -> Dictionary:
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	parent.add_child(v)
	var cap: Label = UiKit.lbl(caption, 11, UiKit.GOLD, 2, 2)
	v.add_child(cap)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	var e: = LineEdit.new()
	e.custom_minimum_size = Vector2(0, 44)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.placeholder_text = placeholder
	e.add_theme_font_size_override("font_size", 16)
	e.select_all_on_focus = false
	match kind:
		"email":
			e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
			e.max_length = 254
		"password":
			e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
			e.secret = true
			e.max_length = 128
		"nick":
			e.max_length = 32
	row.add_child(e)
	var f: Dictionary = {"edit": e, "cap": cap, "caption": caption, "row": row}
	if kind == "password":
		var eye: Button = UiKit.slot("acc_eye", false, 44.0)
		eye.tooltip_text = "Показать пароль"
		var flat: StyleBoxFlat = _flat(Color(0.07, 0.065, 0.05, 0.92), Color(0.36, 0.33, 0.25), 2)
		var flat_p: StyleBoxFlat = _flat(Color(0.12, 0.11, 0.08, 0.95), UiKit.GOLD, 2)
		for st: String in ["normal", "hover"]:
			eye.add_theme_stylebox_override(st, flat)
		for st2: String in ["pressed", "hover_pressed"]:
			eye.add_theme_stylebox_override(st2, flat_p)
		eye.pressed.connect( func() -> void :
			e.secret = not e.secret
			UiKit.slot_icon(eye).texture = UiKit.tex("acc_eye" if e.secret else "acc_eye_off"))
		row.add_child(eye)
	e.text_changed.connect( func(_t: String) -> void :
		if cap.text != caption:
			set_field_error(f, ""))
	return f



static func set_field_error(f: Dictionary, text: String) -> void :
	var cap: Label = f["cap"]
	var e: LineEdit = f["edit"]
	cap.text = text if text != "" else String(f["caption"])
	cap.add_theme_color_override("font_color", UiKit.RED if text != "" else UiKit.GOLD)
	if text != "":
		var red: StyleBoxFlat = _flat(Color(0.08, 0.07, 0.05, 0.95), UiKit.RED, 2)
		red.content_margin_left = 8
		red.content_margin_right = 8
		e.add_theme_stylebox_override("normal", red)
		e.add_theme_stylebox_override("focus", red)
	else:
		e.remove_theme_stylebox_override("normal")
		e.remove_theme_stylebox_override("focus")



static func avatar(px: float = 40.0) -> Control:
	var box: = Control.new()
	box.custom_minimum_size = Vector2(px, px)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fr: TextureRect = UiKit.icon_rect("acc_frame", px)
	box.add_child(fr)
	var p: TextureRect = UiKit.icon_rect("acc_pilot", px * 0.8)
	p.position = Vector2(px * 0.1, px * 0.1)
	box.add_child(p)
	return box




static func account_card(parent: Control, uname: String, sub: String, on_tap: Callable, busy: bool = false) -> Button:
	var b: Button = card_button(ROW_H)
	parent.add_child(b)
	var row: HBoxContainer = _hbox(b, 10, 10)
	row.add_child(avatar(40.0))
	_two_lines(row, uname, sub, 13, UiKit.TEXT)
	if busy:
		var ic: TextureRect = icon("net_sync")
		row.add_child(ic)
		spin(ic)
	elif UiKit.tex("wb_arrow_r") != null:
		var ar: TextureRect = UiKit.icon_rect("wb_arrow_r", 20.0)
		ar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ar)
	b.pressed.connect( func() -> void :
		UiKit.press_fx(b)
		on_tap.call())
	return b



static func stat_card(parent: Control, title: String, sub: String, value: String, dim: bool = false, icon_name: String = "") -> PanelContainer:
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 2))
	p.custom_minimum_size = Vector2(0, ROW_H)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	if icon_name != "":
		row.add_child(icon(icon_name, true))
	_two_lines(row, title, sub, 13, UiKit.MUTED if dim else UiKit.TEXT)
	var v: Label = UiKit.lbl(value, 13 if dim else 18, UiKit.DIM if dim else UiKit.GOLD, 3, 3)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	if dim:
		p.modulate.a = 0.6
	return p





static func avatar_framed(frame_code: Variant, px: float = 48.0, avatar_tex: Texture2D = null) -> Control:
	var box: = Control.new()
	box.custom_minimum_size = Vector2(px, px)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var code: String = Cosmetics.shown("frame", frame_code)
	if avatar_tex != null:
		var p: = TextureRect.new()
		p.texture = avatar_tex
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		p.custom_minimum_size = Vector2(px * 0.72, px * 0.72)
		p.size = p.custom_minimum_size
		p.position = Vector2(px * 0.14, px * 0.14)
		box.add_child(p)
	else:
		var p: TextureRect = UiKit.icon_rect("acc_pilot", px * 2.0 / 3.0)
		p.position = Vector2(px / 6.0, px / 6.0)
		box.add_child(p)
	var fr: TextureRect = UiKit.icon_rect(code if UiKit.tex(code) != null else "acc_frame", px)
	box.add_child(fr)
	return box


static var _dev_verified_popup: CanvasLayer = null

static func show_dev_verified_dialog(dev_name: String = "") -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	if _dev_verified_popup != null and is_instance_valid(_dev_verified_popup):
		_dev_verified_popup.queue_free()
		_dev_verified_popup = null

	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = 130
	tree.root.add_child(cl)
	_dev_verified_popup = cl

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.04, 0.08, 0.8)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	cl.add_child(bg)

	var close_dialog: Callable = func() -> void:
		UiKit.snd("ui_click")
		if _dev_verified_popup != null and is_instance_valid(_dev_verified_popup):
			_dev_verified_popup.queue_free()
			_dev_verified_popup = null

	bg.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_dialog.call()
	)

	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(cc)

	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.sb("wb_window", 16, 14))
	var win_w: float = 340.0
	if tree.root.get_viewport() != null:
		win_w = minf(340.0, tree.root.get_viewport().get_visible_rect().size.x - 32.0)
	panel.custom_minimum_size = Vector2(win_w, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	cc.add_child(panel)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var head_row: HBoxContainer = HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	head_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(head_row)

	var v_icon: TextureRect = TextureRect.new()
	var vt: Texture2D = UiKit.tex("mod_verified")
	v_icon.texture = vt if vt != null else UiKit.tex("icon_ok")
	v_icon.custom_minimum_size = Vector2(24, 24)
	v_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head_row.add_child(v_icon)

	var title_lbl: Label = UiKit.lbl("РАЗРАБОТЧИК DRONEFLAMES", 12, Color(0.3, 0.7, 1.0), 3, 2)
	head_row.add_child(title_lbl)

	var div: ColorRect = ColorRect.new()
	div.color = Color(UiKit.GOLD, 0.4)
	div.custom_minimum_size = Vector2(0, 2)
	vb.add_child(div)

	var who: String = ("Пользователь «%s» является " % dev_name) if dev_name != "" else "Это "
	var desc_text: String = who + "официальным разработчиком порта DroneFlames PC.\n\n"
	desc_text += "• Подтверждённый участник команды разработки\n"
	desc_text += "• Доступ к эксклюзивной косметике разработчика\n"
	desc_text += "• Официальная верификация учетной записи"
	var text_lbl: Label = UiKit.lbl(desc_text, 10, UiKit.TEXT)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(text_lbl)

	var close_btn: Button = UiKit.big("ЗАКРЫТЬ", "green", "", 36.0, 11)
	close_btn.pressed.connect(close_dialog)
	vb.add_child(close_btn)


static func dev_badge_button(dev_name: String = "") -> TextureButton:
	var tb: = TextureButton.new()
	var v_tex: Texture2D = UiKit.tex("mod_verified")
	tb.texture_normal = v_tex if v_tex != null else UiKit.tex("icon_ok")
	tb.custom_minimum_size = Vector2(16, 16)
	tb.ignore_texture_size = true
	tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tb.tooltip_text = "Разработчик порта DroneFlames"
	tb.pressed.connect(func() -> void:
		UiKit.snd("ui_click")
		show_dev_verified_dialog(dev_name)
	)
	return tb


static func toast(text: String) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = 140
	tree.root.add_child(cl)
	var tip: = PanelContainer.new()
	tip.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_gold", 8, 4))
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl: Label = UiKit.lbl(text, 12, UiKit.TEXT, 3, 3)
	tip.add_child(lbl)
	cl.add_child(tip)
	var vp_size: Vector2 = tree.root.get_viewport().get_visible_rect().size
	tip.position = Vector2((vp_size.x - 240) / 2.0, vp_size.y * 0.15)
	var tw: Tween = tip.create_tween()
	tw.tween_property(tip, "modulate:a", 1.0, 0.2).from(0.0)
	tw.tween_interval(2.2)
	tw.tween_property(tip, "modulate:a", 0.0, 0.4)
	tw.tween_callback(cl.queue_free)



static func banner_bg(parent: Control, banner_code: Variant) -> void :
	var code: String = Cosmetics.shown("banner", banner_code)
	var t: Texture2D = UiKit.tex(code)
	if t == null:
		return
	var clip: = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.offset_left = 2
	clip.offset_top = 2
	clip.offset_right = -2
	clip.offset_bottom = -2
	parent.add_child(clip)
	parent.move_child(clip, 0)
	var r: = TextureRect.new()
	r.texture = t
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(r)
	animate(r, UiKit.atlas_cosm_bn_anim, code)
	
	var update_layout: Callable = func() -> void:
		if not is_instance_valid(clip) or not is_instance_valid(r):
			return
		var ts: Vector2 = t.get_size()
		if ts.x <= 0 or ts.y <= 0:
			return
		var sc_x: float = maxf(2.0, clip.size.x / ts.x)
		var sc_y: float = maxf(2.0, clip.size.y / ts.y)
		var sc: float = maxf(sc_x, sc_y)
		r.size = (ts * sc).round()
		r.position = ((clip.size - r.size) * 0.5).round()
	
	clip.resized.connect(update_layout)
	update_layout.call()



static func title_label(code: String, size: int = 11, display_name: String = "") -> Control:
	var col: Color = Cosmetics.rarity_color(code)
	var it: Dictionary = Cosmetics.item(code)
	var title_text: String = display_name if display_name != "" else Cosmetics.name_of(code)
	var l: Control = rgb_label(title_text, size) if String(it.get("fx", "")) == "rgb" else UiKit.lbl(title_text, size, col, 3, 2)
	if String(it.get("rarity", "")) != "legendary":
		return l
	var p: = PanelContainer.new()
	var plate: String = {"dev": "tt_plate_dev", "cbt": "tt_plate_cbt"}.get(String(it.get("exclusive", "")), "tt_plate_legend")
	if String(it.get("fx", "")) == "rgb" and UiKit.tex("tt_plate_dev_rgb") != null:
		plate = "tt_plate_dev_rgb"
	var pt: Texture2D = UiKit.tex(plate)
	var sb: StyleBox
	var rgb_anim: bool = plate == "tt_plate_dev_rgb" and UiKit.atlas_cosm_tt != null and UiKit.atlas_cosm_tt.has("tt_plate_dev_rgb_anim")
	if rgb_anim:
		pt = UiKit.atlas_cosm_tt.region("tt_plate_dev_rgb_anim", 0)
	if pt != null:
		var st: = StyleBoxTexture.new()
		st.texture = pt
		st.set_texture_margin_all(12)
		st.content_margin_left = 8
		st.content_margin_right = 10
		st.content_margin_top = 5
		st.content_margin_bottom = 5
		var tile: bool = plate == "tt_plate_dev_rgb"
		st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE if tile else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE if tile else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb = st
	else:
		var fl: = StyleBoxFlat.new()
		fl.bg_color = Color("0b1430")
		fl.border_color = col
		fl.set_border_width_all(1)
		fl.content_margin_left = 4
		fl.content_margin_right = 6
		sb = fl
	p.add_theme_stylebox_override("panel", sb)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if rgb_anim and sb is StyleBoxTexture:
		animate_style(p, sb as StyleBoxTexture, UiKit.atlas_cosm_tt, "tt_plate_dev_rgb_anim")
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	if UiKit.tex(code) != null:
		var ic: TextureRect = UiKit.icon_rect(code, 16.0)
		row.add_child(ic)
		if UiKit.atlas_cosm_tt != null and int(UiKit.atlas_cosm_tt.info(code).get("frames", 1)) > 1:
			animate(ic, UiKit.atlas_cosm_tt, code)
	row.add_child(l)
	return p




static func player_card(parent: Control, uname: String, sub: String, cos: Dictionary, h: float = ROW_H, on_tap: Callable = Callable(), right: Control = null, is_dev: bool = false, avatar_b64: String = "") -> Control:
	var b: Control
	if on_tap.is_valid():
		var bt: Button = card_button(h)
		bt.pressed.connect( func() -> void :
			UiKit.press_fx(bt)
			on_tap.call())
		b = bt
	else:
		var pc: = PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 2))
		pc.custom_minimum_size = Vector2(0, h)
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b = pc
	parent.add_child(b)
	banner_bg(b, cos.get("banner"))
	var row: HBoxContainer = _hbox(b, 10, 8)
	var a_b64: String = avatar_b64
	if a_b64 == "" and uname.to_lower() == Account.username().to_lower():
		a_b64 = Account.avatar_b64
	var a_tex: Texture2D = Account.get_avatar_texture(a_b64)
	row.add_child(avatar_framed(cos.get("frame"), 48.0, a_tex))
	var v: = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var nh: = HBoxContainer.new()
	nh.add_theme_constant_override("separation", 4)
	nh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nh)
	var display_name: String = uname if uname != "" else Account.username()
	if display_name == "":
		display_name = "Игрок"
	var is_d: bool = is_dev or Account.is_dev_name(display_name) or (display_name.to_lower() == Account.username().to_lower() and Account.is_dev())
	var n: Label = UiKit.lbl(display_name, 16 if h > ROW_H else 13, UiKit.GOLD if is_d else UiKit.TEXT, 3, 3)
	nh.add_child(n)
	if is_d:
		nh.add_child(dev_badge_button(display_name))
	var tc: String = Cosmetics.shown("title", cos.get("title"))
	if tc != "":
		v.add_child(title_label(tc))
	if sub != "":
		var s: Label = UiKit.lbl(sub, 10, UiKit.MUTED, 1, 2)
		v.add_child(s)
	if right != null:
		row.add_child(right)
	return b




static func ranked_row(parent: Control, pl: Dictionary, host: bool, you: bool, state: String, tail: String) -> PanelContainer:
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 2))
	p.custom_minimum_size = Vector2(0, 52)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var a_tex: Texture2D = Account.get_avatar_texture(String(pl.get("avatar_b64", "")))
	row.add_child(avatar_framed(pl.get("frame"), 48.0, a_tex))
	var v: = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var nh: = HBoxContainer.new()
	nh.add_theme_constant_override("separation", 4)
	nh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nh)
	if host:
		nh.add_child(icon("net_host"))
	var pl_name: String = String(pl.get("name", ""))
	var nl: Label = UiKit.lbl(pl_name, 13, UiKit.DIM if state == "left" else (UiKit.GOLD if you else UiKit.TEXT), 3, 2)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nh.add_child(nl)
	if Account.is_dev_name(pl_name) or bool(pl.get("is_dev", false)):
		nh.add_child(dev_badge_button())
	if you:
		nh.add_child(UiKit.lbl("ВЫ", 10, UiKit.GOLD, 3, 2))
	if state == "left":
		nh.add_child(UiKit.lbl("УШЁЛ", 10, UiKit.RED, 3, 2))
	var tc: String = Cosmetics.shown("title", pl.get("title"))
	if tc != "":
		v.add_child(title_label(tc, 10))
	var rv: = VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rv)
	rv.add_child(UiKit.lbl(str(int(pl.get("rating", 1000))), 13, UiKit.GOLD, 3, 2))
	if tail != "":
		rv.add_child(UiKit.lbl(tail, 12, UiKit.GREEN if tail.begins_with("+") else UiKit.RED, 3, 2))
	match state:
		"ok":
			row.add_child(icon("icon_ok"))
		"wait":
			var s: TextureRect = icon("net_sync")
			row.add_child(s)
			spin(s)
	return p




static func rgb_label(text: String, size: int = 11) -> RichTextLabel:
	var r: = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ref: Label = UiKit.lbl(text, size, UiKit.TEXT, 3, 2)
	var f: Font = ref.get_theme_font("font")
	if f != null:
		r.add_theme_font_override("normal_font", f)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_constant_override("outline_size", ref.get_theme_constant("outline_size"))
	r.add_theme_color_override("font_outline_color", ref.get_theme_color("font_outline_color"))
	r.add_theme_color_override("font_shadow_color", ref.get_theme_color("font_shadow_color"))
	r.add_theme_constant_override("shadow_offset_x", ref.get_theme_constant("shadow_offset_x"))
	r.add_theme_constant_override("shadow_offset_y", ref.get_theme_constant("shadow_offset_y"))
	ref.free()


	r.text = "[rainbow freq=0.35 sat=0.55 val=1.0 speed=0.5]%s[/rainbow]" % text
	r.custom_minimum_size = Vector2(0, size + 4)
	return r




static func animate(r: TextureRect, atlas: SpriteAtlas, code: String) -> void :
	if atlas == null or not atlas.has(code):
		return
	var info: Dictionary = atlas.info(code)
	var n: int = int(info.get("frames", 1))
	if n <= 1:
		return
	var at: AtlasTexture = atlas.region(code, 0).duplicate()
	r.texture = at
	var tm: = Timer.new()
	tm.wait_time = 1.0 / maxf(1.0, float(info.get("fps", 8)))
	tm.autostart = true
	r.add_child(tm)
	var k: Array = [0]
	tm.timeout.connect( func() -> void :
		k[0] = (int(k[0]) + 1) % n
		at.region = atlas.rect(code, int(k[0])))




static func animate_style(host: Control, sb: StyleBoxTexture, atlas: SpriteAtlas, code: String) -> void :
	var info: Dictionary = atlas.info(code)
	var n: int = int(info.get("frames", 1))
	if n <= 1:
		return
	var at: AtlasTexture = atlas.region(code, 0).duplicate()
	sb.texture = at
	var tm: = Timer.new()
	tm.wait_time = 1.0 / maxf(1.0, float(info.get("fps", 8)))
	tm.autostart = true
	host.add_child(tm)
	var k: Array = [0]
	tm.timeout.connect( func() -> void :
		k[0] = (int(k[0]) + 1) % n
		at.region = atlas.rect(code, int(k[0]))
		sb.texture = at
		host.queue_redraw())
