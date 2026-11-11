class_name ReportScreen
extends RefCounted






static var target: int = -1
static var reasons: Dictionary = {}
static var comment: String = ""
static var from_chat: bool = false
static var armed: bool = false
static var busy: bool = false
static var result: Dictionary = {}
static var show_msgs: bool = false
static var _arm_gen: int = 0

var mn: Menus
var net: NetSession


func _init(menus: Menus) -> void :
	mn = menus
	net = menus.net



static func start(cid: int, chat: bool) -> void :
	target = cid
	reasons = {}
	comment = ""
	from_chat = chat
	armed = false
	busy = false
	result = {}
	show_msgs = false


func build(vb: VBoxContainer) -> void :
	vb.add_theme_constant_override("separation", 6)
	mn._label(vb, "ПАРТИЯ ИДЁТ ДАЛЬШЕ", 10, UiKit.MUTED)
	if target < 0:
		_pick(vb)
	else:
		_form(vb)
	var br: HBoxContainer = mn._bottom_row()
	var back: Button = mn._button(br, "ГОТОВО" if bool(result.get("ok", false)) else "НАЗАД", "stone", "")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if target >= 0 and not bool(result.get("ok", false)):

		back.size_flags_stretch_ratio = 0.6
		_send_btn = mn._button(br, "", "red", "")
		_send_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_send_btn.add_theme_font_size_override("font_size", 11)
		_send_btn.pressed.connect(_on_send)
		_paint_send()
	back.pressed.connect( func() -> void :
		if busy:
			return
		if target >= 0 and not from_chat and not bool(result.get("ok", false)):
			target = -1
			reasons = {}
			result = {}
			mn.show_report()
		elif from_chat:
			mn.request.emit("resume")
		else:
			mn.show_pause())




func _pick(vb: VBoxContainer) -> void :
	MpKit.section(vb, "НА КОГО")
	var any: bool = false
	for i in net.slots.size():
		if i == net.local_slot:
			continue
		var cid: int = i + 1
		var c: Country = net.gw.country_by_id(cid)
		if c == null:
			continue
		any = true
		var sl: Dictionary = net.slots[i]
		var done: bool = Reports.sent.has(Reports.key(net, net.chat.seat_of_slot(i)))
		var sub: String = c.name.to_upper()
		if bool(sl.get("left", false)):
			sub += " · ВЫШЕЛ"
		_row(vb, c, String(sl.get("name", "?")), sub, "УЖЕ ОТПРАВЛЕНО" if done else "", not done, func() -> void :
			target = cid
			mn.show_report())
	if not any:
		mn._label(vb, "ДРУГИХ ИГРОКОВ В ПАРТИИ НЕТ", 10, UiKit.MUTED)
	var gap: = Control.new()
	gap.custom_minimum_size.y = 8
	vb.add_child(gap)
	_row(vb, null, "СЕРВЕР / СОЕДИНЕНИЕ", "ПИНГ, ЛАГИ, РАЗРЫВЫ", "", true, func() -> void :
		target = 0
		mn.show_report())


func _row(vb: VBoxContainer, c: Country, title: String, sub: String, tag: String, on: bool, tap: Callable) -> void :
	var b: Button = MpKit.card_button(52.0)
	b.disabled = not on
	if not on:
		b.modulate.a = 0.55
	vb.add_child(b)
	var row: HBoxContainer = MpKit._hbox(b, 10, 10)
	if c != null:
		row.add_child(_flag(c))
	else:
		row.add_child(MpKit.icon("net_globe", true))
	MpKit._two_lines(row, title, sub, 13, UiKit.TEXT)
	if tag != "":
		row.add_child(UiKit.lbl(tag, 9, UiKit.MUTED, 1))
	b.pressed.connect( func() -> void :
		UiKit.snd("ui_click")
		tap.call())


func _flag(c: Country) -> Control:
	if c.flag_spec != "":
		return FlagEditor.flag_pic(c.flag_spec, 24, 16, 1, 1)
	var t: = TextureRect.new()
	t.texture = c.flag_tex
	t.custom_minimum_size = Vector2(24, 16)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t




func _form(vb: VBoxContainer) -> void :
	var on_player: bool = target > 0
	var c: Country = net.gw.country_by_id(target) if on_player else null
	var sl: int = net.chat.slot_of(target) if on_player else -1
	var nick: String = String(net.slots[sl].get("name", "?")) if sl >= 0 else "СЕРВЕР / СОЕДИНЕНИЕ"
	var head: = PanelContainer.new()
	head.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 4))
	head.custom_minimum_size.y = 40
	vb.add_child(head)
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	head.add_child(hr)
	hr.add_child(_flag(c) if c != null else MpKit.icon("net_globe", true))
	var hl: Label = UiKit.lbl(("ЖАЛОБА НА %s" % nick) if on_player else "ЖАЛОБА НА СЕРВЕР / СОЕДИНЕНИЕ", 12, UiKit.TITLE, 2, 3)
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hl.clip_text = true
	hl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(hl)
	var locked: bool = busy or bool(result.get("ok", false))
	MpKit.section(vb, "ПРИЧИНА · МОЖНО НЕСКОЛЬКО")
	for it: Array in (Reports.USER_REASONS if on_player else Reports.SERVER_REASONS):
		_check(vb, String(it[0]), String(it[1]), String(it[2]), locked)
	var f: Dictionary = MpKit.field(vb, "ПОДРОБНЕЕ", "Что случилось (необязательно)", "text")
	var e: LineEdit = f["edit"]
	e.max_length = Reports.COMMENT_MAX
	e.text = comment
	e.editable = not locked
	var cnt: Label = UiKit.lbl("", 9, UiKit.DIM, 1)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(cnt)
	var upd: = func() -> void :
		cnt.text = "%d/%d" % [e.text.length(), Reports.COMMENT_MAX] if e.text.length() >= 250 else ""
	upd.call()
	e.text_changed.connect( func(t: String) -> void :
		comment = t
		upd.call()
		armed = false
		_paint_send())
	if reasons.has("other") and comment.strip_edges().length() < Reports.OTHER_MIN:
		MpKit.set_field_error(f, "ДЛЯ «ДРУГОЕ» ОПИШИТЕ СИТУАЦИЮ")
	if on_player:
		_evidence(vb)
	else:
		mn._label(vb, "ПРИЛОЖИМ ДАННЫЕ СЕТИ: ПИНГ, ПОТЕРИ, РАССИНХРОНЫ", 10, UiKit.MUTED)
	var pad: = Control.new()
	pad.custom_minimum_size.y = 24
	vb.add_child(pad)
	if not result.is_empty():
		MpKit.status_bar(vb, String(result["why"]), "ok" if bool(result["ok"]) else "alarm")
	if bool(result.get("ok", false)) and on_player:
		var muted: bool = net.chat.muted.has(target)
		var mb: Button = mn._button(vb, "ЗАГЛУШЁН" if muted else "ЗАГЛУШИТЬ ИГРОКА", "stone", "")
		mb.disabled = muted
		mb.pressed.connect( func() -> void :
			net.chat.muted[target] = true
			mn.show_report())
		return


var _send_btn: Button


func _ready_to_send() -> bool:
	return not reasons.is_empty() and not (reasons.has("other") and comment.strip_edges().length() < Reports.OTHER_MIN)


func _paint_send() -> void :
	if _send_btn == null or not is_instance_valid(_send_btn):
		return
	_send_btn.disabled = busy or not _ready_to_send()
	if busy:
		_send_btn.text = "ОТПРАВКА…"
	elif reasons.is_empty():
		_send_btn.text = "ВЫБЕРИТЕ ПРИЧИНУ"
	else:
		_send_btn.text = "ЕЩЁ ТАП — ОТПРАВИТЬ" if armed else "ОТПРАВИТЬ ЖАЛОБУ"


func _on_send() -> void :
	if busy or not _ready_to_send():
		return
	if not armed:
		armed = true
		_arm_gen += 1
		var g: int = _arm_gen
		_paint_send()
		mn.get_tree().create_timer(3.0).timeout.connect( func() -> void :
			if g == _arm_gen and armed and not busy:
				armed = false
				_paint_send())
		return
	armed = false
	busy = true
	_paint_send()
	UiKit.snd("ui_click")
	var r: Dictionary
	if target > 0:
		r = await Reports.send_user(net, target, reasons.keys(), comment)
	else:
		r = await Reports.send_server(net, reasons.keys(), comment)
	busy = false
	if int(r.get("code", 0)) == 409:
		r["ok"] = true
	result = r
	if mn.current == "report":
		mn.show_report()


func _check(vb: VBoxContainer, code: String, title: String, sub: String, locked: bool) -> void :
	var on: bool = reasons.has(code)
	var b: Button = MpKit.card_button(48.0 if sub == "" else 56.0)
	if on:
		var st: StyleBox = UiKit.sb("wb_slot_active", 8, 2)
		for k: String in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(k, st)
	b.disabled = locked
	vb.add_child(b)
	var row: HBoxContainer = MpKit._hbox(b, 10, 10)
	var box: = Panel.new()
	var bs: = StyleBoxFlat.new()
	bs.bg_color = UiKit.GOLD if on else Color(0, 0, 0, 0.35)
	bs.border_color = UiKit.OUTLINE if on else UiKit.MUTED
	bs.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", bs)
	box.custom_minimum_size = Vector2(20, 20)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if on and UiKit.tex("icon_ok") != null:
		var ok: TextureRect = UiKit.icon_rect("icon_ok", 16.0)
		ok.position = Vector2(2, 2)
		box.add_child(ok)
	row.add_child(box)
	MpKit._two_lines(row, title, sub, 12, UiKit.TEXT if on else UiKit.MUTED)
	b.pressed.connect( func() -> void :
		UiKit.snd("ui_select")
		if reasons.has(code):
			reasons.erase(code)
		else:
			reasons[code] = true
		armed = false
		result = {}
		mn.show_report())


func _evidence(vb: VBoxContainer) -> void :
	var n: int = net.chat.evidence_theirs(target)
	var all: Array = net.chat.evidence(target)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)
	var l: Label = UiKit.lbl(("ПРИЛОЖЕНО %d СООБЩ. ИЗ ЧАТА (ОТ ИГРОКА %d) · ПОДПИСАНЫ СЕРВЕРОМ" % [all.size(), n]) if not all.is_empty() else "СООБЩЕНИЙ ОТ ИГРОКА НЕТ", 10, UiKit.MUTED, 1)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	if all.is_empty():
		return
	var sb: Button = UiKit.big("СКРЫТЬ" if show_msgs else "ПОКАЗАТЬ", "stone", "", 44.0, 10)
	sb.custom_minimum_size = Vector2(96, 44)
	sb.pressed.connect( func() -> void :
		show_msgs = not show_msgs
		mn.show_report())
	hb.add_child(sb)
	if n == 0:
		mn._label(vb, "ОТ ИГРОКА — 0, ТОЛЬКО ВАШИ", 9, UiKit.DIM)
	if show_msgs:
		var box: = VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		vb.add_child(box)
		var me_seat: int = net.chat.my_seat()
		for env: Dictionary in all:
			var mine: bool = int(env.get("from_seat", 0)) == me_seat
			var ml: Label = UiKit.lbl(("ВЫ: " if mine else "ИГРОК: ") + String(env.get("data", "")), 10, UiKit.TEXT if not mine else UiKit.MUTED, 1)
			ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(ml)
