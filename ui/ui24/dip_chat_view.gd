extends VBoxContainer





const QUICK: Array = ["Мир?", "Союз?", "Прекратите огонь", "Нужна помощь", "Согласен", "Нет", "Спасибо"]
const C_MINE_BG: = Color("2c3a22")
const C_MINE_RIM: = Color("4caf3a")
const C_THEIR_BG: = Color("22262b")
const C_THEIR_RIM: = Color("3a86d6")
const C_RED: = Color("ff6a4d")
const C_AMB: = Color("ffb000")

var s
var pg
var chat: DipChat
var cid: int = -1
var list: VBoxContainer
var edit: LineEdit
var send_btn: Button
var cnt: Label
var quick_row: Control
var _kb: float = -1.0
var _base_h: float = 0.0
var _cd_shown: int = -1
static var debug_kb: float = 0.0


func setup(sheet, page, c: int) -> void :
	s = sheet
	pg = page
	cid = c
	chat = s.m.net.chat
	name = "ChatBottom"
	add_theme_constant_override("separation", 4)
	list = s.inner
	chat.set_open(cid)
	var why: String = chat.why_closed(cid)
	_status_line(why)
	if why == "":
		quick_row = _quick()
		add_child(quick_row)
		add_child(_input_row())
	else:
		var p: Label = UiKit.lbl("ЧАТ ЗАКРЫТ", 10, UiKit.MUTED, 2, 3)
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.custom_minimum_size.y = 44
		p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(p)
	_fill()
	chat.changed.connect(_on_changed)
	if float(pg.chat_base_h) <= 0.0:
		pg.chat_base_h = s.max_h
	_base_h = float(pg.chat_base_h)
	tree_exiting.connect( func() -> void :
		if chat.open_cid == cid and not bool(pg.chat_on):
			chat.set_open(-1))


func _on_changed(c: int) -> void :
	if c == cid and is_instance_valid(list):
		chat.set_open(cid)
		_fill()


func _status_line(why: String) -> void :
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	add_child(hb)
	var txt: String = ""
	var col: Color = UiKit.MUTED
	if why == "left":
		txt = "ИГРОК ВЫШЕЛ — СТРАНОЙ УПРАВЛЯЕТ ИИ"
		col = C_AMB
	elif not chat.online():
		txt = "ЛОКАЛЬНАЯ СЕТЬ · БЕЗ ФИЛЬТРА И ПРОВЕРКИ"
	var l: Label = UiKit.lbl(txt, 10, col, 2, 3)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(l)
	var mute: bool = chat.muted.has(cid)
	var mb: Button = UiKit.big("ЗАГЛУШЁН" if mute else "ЗАГЛУШИТЬ", "stone", "", 44.0, 10)
	mb.custom_minimum_size = Vector2(104, 44)
	mb.pressed.connect( func() -> void :
		UiKit.snd("ui_click")
		if chat.muted.has(cid):
			chat.muted.erase(cid)
		else:
			chat.muted[cid] = true
		mb.text = "ЗАГЛУШЁН" if chat.muted.has(cid) else "ЗАГЛУШИТЬ"
		_fill())
	hb.add_child(mb)
	if chat.online():
		var rb: Button = UiKit.big("ЖАЛОБА", "stone", "", 44.0, 10)
		rb.custom_minimum_size = Vector2(84, 44)
		rb.pressed.connect( func() -> void :
			UiKit.snd("ui_click")
			var m: Node = s.m
			s.close_sheet()
			m.call("open_report", cid))
		hb.add_child(rb)


func _quick() -> Control:
	var wrap: = Control.new()
	wrap.custom_minimum_size.y = 46
	var sc: = ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	wrap.add_child(sc)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	sc.add_child(hb)
	for q: String in QUICK:
		var b: Button = UiKit.big(q.to_upper(), "stone", "", 44.0, 10)
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect( func() -> void : _send(q))
		hb.add_child(b)

	var g: = Gradient.new()
	g.set_color(0, Color(0.16, 0.17, 0.12, 0.0))
	g.set_color(1, Color(0.16, 0.17, 0.12, 0.95))
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.width = 32
	gt.height = 4
	var fade: = TextureRect.new()
	fade.texture = gt
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.anchor_left = 1.0
	fade.anchor_right = 1.0
	fade.anchor_bottom = 1.0
	fade.offset_left = -32.0
	wrap.add_child(fade)
	sc.get_h_scroll_bar().value_changed.connect( func(v: float) -> void :
		fade.visible = v < sc.get_h_scroll_bar().max_value - sc.size.x - 2.0)
	return wrap


func _input_row() -> Control:
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	edit = LineEdit.new()
	edit.max_length = DipChat.MAX_LEN
	edit.placeholder_text = "Сообщение…"
	edit.custom_minimum_size.y = 44
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 12)
	edit.text = String(pg.chat_draft)
	edit.caret_column = edit.text.length()
	edit.text_changed.connect( func(t: String) -> void :
		pg.chat_draft = t
		_upd())
	edit.text_submitted.connect( func(t: String) -> void : _send(t))
	hb.add_child(edit)
	cnt = UiKit.lbl("", 8, UiKit.DIM, 1)
	cnt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hb.add_child(cnt)
	send_btn = UiKit.big("ОТПРАВИТЬ", "gold", "", 44.0, 10)
	send_btn.custom_minimum_size = Vector2(96, 44)
	send_btn.pressed.connect( func() -> void :
		if edit.text.strip_edges() == "":
			edit.release_focus()
			DisplayServer.virtual_keyboard_hide()
		else:
			_send(edit.text))
	hb.add_child(send_btn)
	if bool(pg.chat_focus):
		edit.call_deferred("grab_focus")
	edit.focus_entered.connect( func() -> void : pg.chat_focus = true)
	edit.focus_exited.connect( func() -> void :
		if edit.is_inside_tree():
			pg.chat_focus = false)
	_upd()
	return hb


func _send(t: String) -> void :
	if t.strip_edges() == "" or chat.cooldown() > 0.0 or chat.why_closed(cid) != "":
		return
	UiKit.snd("ui_click")
	chat.send(cid, t)
	if edit != null and t == edit.text:
		edit.text = ""
		pg.chat_draft = ""
	_upd()


func _upd() -> void :
	if edit == null:
		return
	var n: int = edit.text.length()
	cnt.text = "%d/%d" % [n, DipChat.MAX_LEN] if n >= 150 else ""
	cnt.add_theme_color_override("font_color", C_RED if n >= DipChat.MAX_LEN else UiKit.DIM)
	var cd: float = chat.cooldown()
	send_btn.disabled = edit.text.strip_edges() == "" or cd > 0.0
	_cd_shown = ceili(cd)
	send_btn.text = Loc.t("ОТПРАВИТЬ") if cd <= 0.0 else str(ceili(cd))


func _process(_dt: float) -> void :
	if send_btn != null and ceili(chat.cooldown()) != _cd_shown:
		_upd()
	_keyboard()



func _keyboard() -> void :
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var win_h: float = float(DisplayServer.window_get_size().y)
	var kb_px: float = float(DisplayServer.virtual_keyboard_get_height()) if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0.0
	var kb: float = kb_px * vp.get_visible_rect().size.y / maxf(1.0, win_h)
	if debug_kb > 0.0 and edit != null and edit.has_focus():
		kb = debug_kb
	if absf(kb - _kb) < 1.0:
		return
	_kb = kb


	var holder: Control = s.hud.holder
	if not bool(pg.chat_lifted):
		pg.chat_hold_off = holder.offset_bottom
		pg.chat_lifted = true
	var lift: float = maxf(0.0, kb - float(s.hud._safe_margins().y)) if kb > 0.0 else 0.0
	holder.offset_bottom = float(pg.chat_hold_off) - lift
	s.max_h = maxf(160.0, _base_h - lift)
	if quick_row != null:
		quick_row.visible = kb <= 0.0
	s._fit_scroll()
	_to_end()


func _fill() -> void :
	if not is_instance_valid(list):
		return
	for c: Node in list.get_children():
		list.remove_child(c)
		c.queue_free()
	var h: Array = chat.hist.get(cid, [])
	if h.is_empty():
		var e: Label = UiKit.lbl("Сообщений пока нет. Напишите первым — или выберите фразу ниже.", 10, UiKit.MUTED, 1)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.custom_minimum_size.y = 60
		list.add_child(e)
		return
	if chat.muted.has(cid):
		var hidden: int = h.filter( func(m: Dictionary) -> bool: return not bool(m["mine"])).size()
		var ml: Label = UiKit.lbl(Loc.t("ИГРОК ЗАГЛУШЁН · СКРЫТО %d") % hidden, 9, UiKit.MUTED, 2, 3)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(ml)
	var prev_t: float = -1000000000.0
	var prev_mine: int = -1
	for m: Dictionary in h:
		var mine: bool = bool(m["mine"])
		if not mine and chat.muted.has(cid):
			continue
		var t: float = float(m["t"])
		if t - prev_t >= 60.0:
			var tl: Label = UiKit.lbl(_clock(t), 8, UiKit.DIM, 1)
			tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			list.add_child(tl)
		elif prev_mine != int(mine):
			var gap: = Control.new()
			gap.custom_minimum_size.y = 4
			list.add_child(gap)
		prev_t = t
		prev_mine = int(mine)
		list.add_child(_bubble(m))
	_to_end()


func _bubble(m: Dictionary) -> Control:
	var mine: bool = bool(m["mine"])
	var row: = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	var pc: = PanelContainer.new()
	var st: = StyleBoxFlat.new()
	var state: String = String(m["state"])
	st.bg_color = C_MINE_BG if mine else C_THEIR_BG
	st.border_color = C_RED if state == "fail" else (C_MINE_RIM if mine else C_THEIR_RIM)
	st.set_border_width_all(2)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 5
	st.content_margin_bottom = 5
	pc.add_theme_stylebox_override("panel", st)
	if state == "sending":
		pc.modulate.a = 0.6
	row.add_child(pc)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	pc.add_child(vb)
	var rt: = RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.add_theme_font_size_override("normal_font_size", 11)
	rt.add_theme_color_override("default_color", UiKit.TEXT)
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var safe: String = String(m["text"]).replace("[", "[lb]")
	rt.text = safe.replace("****", "[color=#8f8a76]****[/color]")
	var w: float = maxf(160.0, (s.size.x if s.size.x > 0.0 else 360.0) * 0.78)
	var font: Font = rt.get_theme_default_font()
	var tw: float = font.get_string_size(String(m["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 4.0 if font != null else w
	rt.custom_minimum_size.x = minf(w, maxf(24.0, tw))
	vb.add_child(rt)
	var note: String = ""
	var ncol: Color = UiKit.DIM
	if state == "sending":
		note = "ОТПРАВКА…"
	elif state == "fail":
		note = String(m["why"])
		ncol = C_RED
	elif mine and bool(m.get("masked", false)):
		note = "ЧАСТЬ ТЕКСТА СКРЫТА"
	if note != "":
		var nl: Label = UiKit.lbl(note, 8, ncol, 1)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(nl)
	if state == "fail":
		var br: = HBoxContainer.new()
		br.add_theme_constant_override("separation", 6)
		vb.add_child(br)
		var id: int = int(m["id"])
		if not bool(m.get("no_retry", false)):
			var rb: Button = UiKit.big("ПОВТОРИТЬ", "stone", "", 44.0, 10)
			rb.pressed.connect( func() -> void : chat.retry(cid, id))
			br.add_child(rb)
		var db: Button = UiKit.big("УБРАТЬ", "stone", "", 44.0, 10)
		db.pressed.connect( func() -> void : chat.drop(cid, id))
		br.add_child(db)
	return row


func _to_end() -> void :
	var sc: ScrollContainer = s.scroll
	if sc == null or not is_instance_valid(sc):
		return
	get_tree().process_frame.connect( func() -> void :
		if is_instance_valid(sc):
			sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value), CONNECT_ONE_SHOT)


static func _clock(t: float) -> String:
	var n: int = int(t)
	return "%d:%02d" % [n / 60, n % 60]
