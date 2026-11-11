extends RefCounted









const SS = preload("res://game/save_slots.gd")

static var sel: int = -1
static var open_n: int = -1
static var pick_key: Dictionary = {}
static var del_n: int = -1
static var _arm_t: int = 0
static var _icons: Dictionary = {}

const MASKS: Dictionary = {
	"disk": ["oooooooooo..", "oaawwwwwaao.", "oaawwwwcaaao", "oaawwwwcaaao", "oaawwwwwaaao", "oaaaaaaaaaao", 
		"oacccccccbao", "oacwwwwwwcao", "oacwddddwcao", "oacwwwwwwcao", "oacwddddwcao", "oooooooooooo"], 
	"folder": ["............", ".oooo.......", "obbbbooooo..", "obbbbbbbbbo.", "obooooooooooo", "obcaaaaaaaaco", 
		"oboaaaaaaaao", "obcaaaaaaaao", "oboaaaaaaaco", "occaaaaaaaco", "oooooooooooo", "............"], 
	"bin": ["....oooo....", "....owwo....", "oooooooooooo", "obbbbbbbbbbo", "oooooooooooo", ".oacacacaco.", 
		".oacacacaco.", ".oacacacaco.", ".oacacacaco.", ".oacacacaco.", ".oaaaaaaaao.", "..oooooooo.."], 
	"bolt": ["......oooo..", ".....owwo...", "....owwo....", "...owwo.....", "..owwwoooo..", ".owwwwwwwo..", 
		".oooowwwo...", "....owwo....", "...owwo.....", "..owwo......", "..owo.......", "..oo........"], 
	"plus": ["............", "....oooo....", "....owwo....", "....owwo....", ".ooooowwoooo", ".owwwwwwwwwo", 
		".owwwwwwwwwo", ".oooowwooooo", "....owwo....", "....owwo....", "....oooo....", "............"], 
}
const ICOL: Dictionary = {
	"disk": {"o": "1b120c", "a": "3f6fb0", "b": "7cccff", "c": "263f6a", "w": "fbf3e0", "d": "8f8a76"}, 
	"folder": {"o": "1b120c", "a": "ffd75e", "b": "c08a2c", "c": "a86e1c", "w": "fbf3e0"}, 
	"bin": {"o": "1b120c", "a": "cfc6a8", "b": "fbf3e0", "c": "8f8a76", "w": "fbf3e0"}, 
	"bolt": {"o": "1b120c", "w": "ffd75e"}, 
	"plus": {"o": "1b120c", "w": "ffd75e"}, 
}


static func icon(name: String, px: float = 24.0) -> TextureRect:
	if not _icons.has(name):
		var rows: Array = MASKS[name]
		var pal: Dictionary = ICOL[name]
		var img: = Image.create(12, 12, false, Image.FORMAT_RGBA8)
		for y in 12:
			var r: String = rows[y]
			for x in mini(12, r.length()):
				var ch: String = r[x]
				if ch != "." and pal.has(ch):
					img.set_pixel(x, y, Color(String(pal[ch])))
		_icons[name] = ImageTexture.create_from_image(img)
	var tr: = TextureRect.new()
	tr.texture = _icons[name]
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return tr



static func icon_tex(name: String) -> Texture2D:
	var k: String = name + "@2"
	if not _icons.has(k):
		icon(name)
		var img: Image = (_icons[name] as ImageTexture).get_image()
		img.resize(24, 24, Image.INTERPOLATE_NEAREST)
		_icons[k] = ImageTexture.create_from_image(img)
	return _icons[k]





static func dur(s: float) -> String:
	var m: int = int(s / 60.0)
	if m < 1:
		return Loc.t("< 1 МИН")
	if m < 60:
		return Loc.t("%d МИН") % m
	return Loc.t("%d Ч %02d МИН") % [m / 60, m % 60]



static func when (h: Dictionary, bare_today: bool = false) -> String:
	var dt: String = String(h.get("date_text", ""))
	if dt.length() < 16:
		return ""
	var day: String = dt.substr(0, 10)
	var hm: String = dt.substr(11, 5)
	var today: String = Time.get_datetime_string_from_system(false, true).substr(0, 10)
	var yd: String = Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60 - 86400, true).substr(0, 10)
	if day == today:
		return hm if bare_today else Loc.t("СЕГОДНЯ %s") % hm
	if day == yd:
		return Loc.t("ВЧЕРА %s") % hm
	return "%s.%s %s" % [day.substr(8, 2), day.substr(5, 2), hm]


static func _place(h: Dictionary) -> String:
	var pl: int = int(h.get("place", 0))
	if pl <= 0:
		return ""
	return Loc.t("%d-Е ИЗ %d") % [pl, int(h.get("n_countries", 0))] if int(h.get("n_countries", 0)) > 0 else Loc.t("%d-Е МЕСТО") % pl


static func _map_line(h: Dictionary) -> String:
	if not h.has("map_type"):
		return Loc.t("СОХРАНЕНИЕ %s") % String(h.get("version", "")).to_upper()
	var t: int = clampi(int(h["map_type"]), 0, MAP_NOUN.size() - 1)
	var z: int = clampi(int(h.get("size_i", 1)), 0, 2)
	var a: Array = [Loc.t(String((SIZE_ADJ[MAP_GENDER[t]] as Array)[z]) + " " + String(MAP_NOUN[t]))]
	if bool(h.get("cb_on", false)):
		a.append(Loc.t("СВОИ ВРАГИ"))
	else:
		a.append(Loc.t(String(GameConfig.DIFF_NAMES[clampi(int(h.get("difficulty", 1)), 0, GameConfig.DIFF_NAMES.size() - 1)])))
	if bool(h.get("creative", false)):
		a.append(Loc.t("ТВОРЧ."))
	return " · ".join(a)



const MAP_NOUN: Array = ["КАРТА", "АРХИПЕЛАГ", "ОСТРОВА", "МАТЕРИКИ"]
const MAP_GENDER: Array = [0, 1, 2, 2]
const SIZE_ADJ: Array = [["МАЛАЯ", "СРЕДНЯЯ", "БОЛЬШАЯ"], ["МАЛЫЙ", "СРЕДНИЙ", "БОЛЬШОЙ"], ["МАЛЫЕ", "СРЕДНИЕ", "БОЛЬШИЕ"]]

const LOC_MAP_LINE: Array = ["МАЛАЯ КАРТА", "СРЕДНЯЯ КАРТА", "БОЛЬШАЯ КАРТА", "МАЛЫЙ АРХИПЕЛАГ", "СРЕДНИЙ АРХИПЕЛАГ", 
	"БОЛЬШОЙ АРХИПЕЛАГ", "МАЛЫЕ ОСТРОВА", "СРЕДНИЕ ОСТРОВА", "БОЛЬШИЕ ОСТРОВА", "МАЛЫЕ МАТЕРИКИ", "СРЕДНИЕ МАТЕРИКИ", "БОЛЬШИЕ МАТЕРИКИ"]


static func _tier(h: Dictionary) -> String:
	var t: int = int(h.get("tier", -1))
	if t < 0:
		return ""
	return Loc.t(String(PowerStatus.TIER_SHORT[clampi(t, 0, PowerStatus.TIER_SHORT.size() - 1)]))




static func _flag(h: Dictionary, w: int, hh: int) -> Control:
	var code: String = String(h.get("flag", ""))
	if code != "" and not FlagMaker.decode(code).is_empty():
		return FlagEditor.flag_pic(code, w, hh, 1, 1)
	var p: = PanelContainer.new()
	var s: = StyleBoxFlat.new()
	s.bg_color = h.get("color", UiKit.DIM) if h.get("color") is Color else UiKit.DIM
	s.border_color = UiKit.OUTLINE
	s.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(w + 2, hh + 2)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


static func _thumb(n: int, h: Dictionary, px: float) -> Control:
	var c: = Control.new()
	c.custom_minimum_size = Vector2(px + 4.0, px + 4.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pic: Control = _thumb_pic(n, h, px)
	c.add_child(pic)
	c.add_child(_badge(n))
	return c


static func _badge(n: int) -> PanelContainer:
	var bp: = PanelContainer.new()
	var bs: = StyleBoxFlat.new()
	bs.bg_color = UiKit.OUTLINE
	bs.content_margin_left = 4
	bs.content_margin_right = 4
	bs.content_margin_top = 0
	bs.content_margin_bottom = 1
	bp.add_theme_stylebox_override("panel", bs)
	bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp.position = Vector2(0, 0)
	bp.add_child(_lbl("%d" % n, 11, UiKit.TEXT, 3, 0))
	return bp


static func _thumb_pic(n: int, h: Dictionary, px: float) -> Control:
	var p: = PanelContainer.new()
	var s: = StyleBoxFlat.new()
	s.bg_color = UiKit.OUTLINE
	s.set_content_margin_all(2)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tr: = TextureRect.new()
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: Texture2D = SS.thumb_tex(n)
	if t == null:
		t = UiKit.tex(String(GameConfig.MAP_TYPE_ICONS[clampi(int(h.get("map_type", 0)), 0, 3)]))
		tr.modulate = Color(0.75, 0.75, 0.75)
	tr.texture = t
	p.add_child(tr)
	return p


static func _hbox(sep: int = 6) -> HBoxContainer:
	var r: = HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _vbox(sep: int = 2) -> VBoxContainer:
	var r: = VBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _lbl(text: String, size: int, col: Color, weight: int = 2, outline: int = 1) -> Label:
	var l: Label = UiKit.lbl(text, size, col, weight, outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


static func _chip(text: String, col: Color) -> PanelContainer:
	var p: = PanelContainer.new()
	var s: = StyleBoxFlat.new()
	s.bg_color = Color(col.darkened(0.72), 0.95)
	s.border_color = col
	s.set_border_width_all(1)
	s.content_margin_left = 5
	s.content_margin_right = 5
	s.content_margin_top = 0
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(_lbl(text, 9, col, 3, 1))
	return p



static func _card_btn(h: float, lit: bool = false) -> Button:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	var n0: StyleBox = UiKit.sb("wb_panel" if lit else "wb_panel_dark", 8, 2)
	var pr: StyleBox = UiKit.sb("wb_panel", 8, 2)
	for st: String in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, n0)
	for st2: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st2, pr)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	UiKit.press_fx(b)
	return b


static func _fill(b: Control, l: float = 8.0, r: float = 8.0, t: float = 6.0, bt: float = 6.0) -> HBoxContainer:
	var row: HBoxContainer = _hbox(8)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = l
	row.offset_right = - r
	row.offset_top = t
	row.offset_bottom = - bt
	b.add_child(row)
	return row


static func _main_node(mn: Menus) -> Node:
	return mn.get_parent()






static func main_strip(mn: Menus, col: VBoxContainer, has_save: bool) -> void :
	sel = -1
	open_n = -1
	del_n = -1
	var used: int = 0
	for i: Dictionary in SS.all():
		if i["state"] != "empty":
			used += 1
	if used == 0:
		return
	var si: Dictionary = Save.save_info() if has_save else {}
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	var st: StyleBox = UiKit.sb("wb_pill", 10, 3)
	for s: String in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UiKit.press_fx(b)
	var row: HBoxContainer = _fill(b, 12.0, 8.0, 0.0, 0.0)
	row.add_theme_constant_override("separation", 6)
	if not si.is_empty():
		row.add_child(_flag(si, 18, 12))
		var nm: Label = _lbl("%s · %s" % [Loc.name(String(si.get("country", ""))).to_upper(), dur(float(si.get("elapsed", si.get("game_time", 0.0))))], 11, UiKit.TEXT, 2, 2)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		UiKit.fit_lbl(nm, [11, 10], false, true)
	else:
		var sp: = Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sp)
	var go: Label = _lbl("СОХРАНЕНИЯ" if not si.is_empty() else Loc.t("СОХРАНЕНИЯ · %d") % used, 11, UiKit.GOLD, 3, 2)
	row.add_child(go)
	var ar: TextureRect = UiKit.icon_rect("wb_arrow_r", 16.0)
	ar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ar)
	b.pressed.connect( func() -> void : mn.show_saves(false))
	col.add_child(b)




static func build(mn: Menus, vb: VBoxContainer, from_pause: bool) -> void :
	vb.add_theme_constant_override("separation", 6)
	var live: int = Save.slot if from_pause and not GameConfig.no_save else -1
	var cont: int = SS.continue_slot()
	var hint: String = Loc.t("Текущая партия сохранится перед загрузкой другой.") if from_pause else Loc.t("Сохраняется само: каждую минуту и при выходе.")
	mn._label(vb, hint, 10, UiKit.MUTED)
	for i: Dictionary in SS.all():
		var n: int = int(i["n"])
		if i["state"] == "empty":
			_empty_card(mn, vb, n, from_pause)
		else:
			_slot_card(mn, vb, i, from_pause, n == live, n == cont and not from_pause)
	var row: HBoxContainer = mn._bottom_row()
	var exchange: Button = UiKit.big("ОБМЕН ФАЙЛОМ", "blue", "", 44.0, 12)
	exchange.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exchange.tooltip_text = "Импортировать файл можно в пустой слот. Экспорт копирует выбранное сохранение в отдельный файл."
	exchange.pressed.connect(func() -> void:
		var target: int = SS.first_empty_slot()
		if target < 0:
			mn._mp_toast("Для импорта освободите один слот сохранения")
			return
		var dialog: FileDialog = _file_dialog(mn, FileDialog.FILE_MODE_OPEN_FILE)
		dialog.title = "Импорт сохранения в слот %d" % target
		dialog.file_selected.connect(func(path: String) -> void:
			var error: String = SS.import_file(path, target)
			mn._mp_toast("Сохранение импортировано в слот %d" % target if error == "" else error)
			if error == "":
				_refresh(mn, from_pause))
		dialog.popup_centered_ratio(0.75))
	row.add_child(exchange)
	var folder: Button = UiKit.big("ПАПКА", "stone", "", 44.0, 12)
	folder.tooltip_text = "Открыть папку с файлами сохранений для отправки или копирования."
	folder.pressed.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SS.DIR))
		OS.shell_open(ProjectSettings.globalize_path(SS.DIR)))
	row.add_child(folder)
	var back: Button = UiKit.big("НАЗАД", "stone", "", 44.0, 14)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect( func() -> void :
		open_n = -1
		del_n = -1
		if from_pause:
			mn.show_pause()
		else:
			mn.show_main())
	row.add_child(back)


static func _empty_card(mn: Menus, vb: VBoxContainer, n: int, from_pause: bool) -> void :
	var b: Button = _card_btn(52.0)
	b.set_meta("slot", n)
	b.self_modulate = Color(1, 1, 1, 0.7)
	vb.add_child(b)
	var row: HBoxContainer = _fill(b, 10.0, 8.0)
	var num: Label = _lbl("%d" % n, 20, UiKit.DIM, 3, 2)
	num.custom_minimum_size = Vector2(26, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(num)
	var t: Label = _lbl("ПУСТОЙ СЛОТ", 12, UiKit.MUTED, 2, 1)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	if from_pause:
		b.disabled = true
		return
	row.add_child(icon("plus", 20.0))
	row.add_child(_lbl("НОВАЯ ПАРТИЯ", 11, UiKit.GOLD, 3, 2))
	b.pressed.connect( func() -> void :
		sel = n
		GameConfig.no_save = false
		mn.show_setup())


static func _slot_card(mn: Menus, vb: VBoxContainer, i: Dictionary, from_pause: bool, live: bool, cont: bool) -> void :
	var n: int = int(i["n"])
	var h: Dictionary = i["head"]
	var st: String = i["state"]
	var open: bool = open_n == n
	var wrap: = PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", UiKit.sb("wb_panel" if open else "wb_panel_dark", 8, 2))
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(wrap)
	var col: VBoxContainer = _vbox(6)
	wrap.add_child(col)
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.custom_minimum_size = Vector2(0, 70)
	b.set_meta("slot", n)
	for s: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	UiKit.tap_snd(b)
	col.add_child(b)
	var row: HBoxContainer = _fill(b, 2.0, 2.0, 2.0, 2.0)
	if st == "bad":
		var wb: = PanelContainer.new()
		var s2: = StyleBoxFlat.new()
		s2.bg_color = Color(0.22, 0.05, 0.03)
		s2.border_color = UiKit.OUTLINE
		s2.set_border_width_all(2)
		wb.add_theme_stylebox_override("panel", s2)
		wb.custom_minimum_size = Vector2(60, 60)
		wb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var wi: TextureRect = UiKit.icon_rect("net_warn", 28.0)
		wi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		wb.add_child(wi)
		var wc: = Control.new()
		wc.custom_minimum_size = Vector2(60, 60)
		wc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		wc.add_child(wb)
		wc.add_child(_badge(n))
		row.add_child(wc)
	else:
		row.add_child(_thumb(n, h, 56.0))
	var tx: VBoxContainer = _vbox(1)
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tx)
	var r1: HBoxContainer = _hbox(5)
	tx.add_child(r1)
	if st != "bad":
		r1.add_child(_flag(h, 18, 12))
	var nm: Label = _lbl((Loc.t("СЛОТ %d ПОВРЕЖДЁН") % n) if st == "bad" else Loc.name(String(h.get("country", "?"))).to_upper(), 14, UiKit.RED if st == "bad" else UiKit.TITLE, 3, 3)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(nm)
	UiKit.fit_lbl(nm, [14, 13, 12], false, true)
	if live:
		r1.add_child(_chip("ИДЁТ", UiKit.GREEN))
	elif cont:
		r1.add_child(_chip("ПРОДОЛЖИТЬ", UiKit.GREEN))
	if st == "bad":
		var bl: Label = _lbl("Файлы не читаются. Удалите слот — остальные целы.", 10, UiKit.MUTED, 1, 1)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tx.add_child(bl)
	else:
		var r2: HBoxContainer = _hbox(4)
		tx.add_child(r2)
		if st == "ended":
			var win: bool = int(i["end"]) == SS.END_WIN
			r2.add_child(_chip(Loc.t("ПОБЕДА") if win else Loc.t("ПОРАЖЕНИЕ"), UiKit.GREEN if win else UiKit.RED))
		var tier: String = _tier(h)
		var pl: String = _place(h) if st != "ended" else ""
		var l2: Label = _lbl(" · ".join([tier, pl].filter( func(x: String) -> bool: return x != "")), 10, UiKit.GOLD, 2, 1)
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r2.add_child(l2)
		UiKit.fit_lbl(l2, [10], false, true)
		var r3: HBoxContainer = _hbox(4)
		tx.add_child(r3)
		var ti: TextureRect = UiKit.icon_rect("si_time", 12.0)
		ti.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r3.add_child(ti)
		r3.add_child(_lbl(dur(float(h.get("elapsed", h.get("game_time", 0.0)))), 10, UiKit.TEXT, 2, 1))
		var wl: Label = _lbl("· " + when (h), 10, UiKit.MUTED, 1, 1)
		wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r3.add_child(wl)
		var l4: Label = _lbl(_map_line(h), 10, UiKit.DIM, 1, 1)
		tx.add_child(l4)
		UiKit.fit_lbl(l4, [10], false, true)
	var ar: TextureRect = UiKit.icon_rect("wb_arrow_r", 18.0)
	ar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if open and ar.texture != null:
		var ai: Image = ar.texture.get_image()
		ai.rotate_90(CLOCKWISE)
		ar.texture = ImageTexture.create_from_image(ai)
	row.add_child(ar)
	b.pressed.connect( func() -> void :
		open_n = -1 if open_n == n else n
		del_n = -1
		_refresh(mn, from_pause))
	if open:
		_details(mn, col, i, from_pause, live)


static func _refresh(mn: Menus, from_pause: bool) -> void :
	var ks: int = mn._scroll.scroll_vertical if mn._scroll != null and is_instance_valid(mn._scroll) else 0
	mn.show_saves(from_pause, true)
	if mn._scroll != null and is_instance_valid(mn._scroll):
		mn._scroll.set_deferred("scroll_vertical", ks)



static func _details(mn: Menus, col: VBoxContainer, i: Dictionary, from_pause: bool, live: bool) -> void :
	var n: int = int(i["n"])
	var rows: Array = i["rows"]
	var st: String = i["state"]
	var key: String = String(pick_key.get(n, ""))
	var skip0: bool = live and rows.size() > 0
	if not rows.is_empty() and ( not rows.any( func(r: Dictionary) -> bool: return String(r["key"]) == key) or (skip0 and key == String((rows[0] as Dictionary)["key"]))):
		key = String((rows[1 if skip0 and rows.size() > 1 else 0] as Dictionary)["key"])
	if skip0 and rows.size() == 1:
		key = ""
	if del_n == n:
		_confirm_delete(mn, col, i, from_pause)
		return
	if st == "ended":
		var el: Label = _lbl("Партия окончена — загрузите точку до конца.", 10, UiKit.MUTED, 1, 1)
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(el)
	if st != "bad" and not rows.is_empty():
		var g0: float = float(((rows[0] as Dictionary)["h"] as Dictionary).get("game_time", 0.0))
		var box: VBoxContainer = _vbox(4)
		col.add_child(box)
		for r: Dictionary in rows:
			var rk: String = String(r["key"])
			var rh: Dictionary = r["h"]
			var on: bool = rk == key
			var first: bool = r == rows[0]
			var now_row: bool = first and skip0
			var rb: = Button.new()
			rb.focus_mode = Control.FOCUS_NONE
			rb.custom_minimum_size = Vector2(0, 44)
			var rs: = StyleBoxFlat.new()
			rs.bg_color = Color(0.16, 0.14, 0.08, 0.95) if on else Color(0.07, 0.07, 0.05, 0.75)
			rs.border_color = UiKit.GOLD if on else UiKit.OUTLINE
			rs.set_border_width_all(2)
			for sname: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				rb.add_theme_stylebox_override(sname, rs)
			rb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			rb.mouse_filter = Control.MOUSE_FILTER_PASS
			rb.disabled = now_row
			UiKit.tap_snd(rb)
			box.add_child(rb)
			var rr: HBoxContainer = _fill(rb, 8.0, 10.0, 0.0, 0.0)
			rr.add_child(_radio(on, now_row))
			rr.add_child(icon("disk", 18.0) if rk == "main" or rk == "bak" else _clock())
			var nm: String = Loc.t("СЕЙЧАС") if now_row else (Loc.t("ПОСЛЕДНЯЯ") if first else (Loc.t("АВТО") if rk.begins_with("a") else Loc.t("СОХРАНЕНИЕ")))
			var ln: Label = _lbl(nm, 12, UiKit.TITLE if on else (UiKit.DIM if now_row else UiKit.TEXT), 3, 2)
			rr.add_child(ln)
			var back: float = g0 - float(rh.get("game_time", 0.0))
			var bt: String = (Loc.t("−%d СЕК") % maxi(1, int(back))) if back < 60.0 else ("−" + dur(back))
			var mid: Label = _lbl("" if first else bt, 10, UiKit.GOLD if on else UiKit.MUTED, 2, 1)
			mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rr.add_child(mid)
			var wl: Label = _lbl( when (rh, true), 10, UiKit.MUTED, 1, 1)
			rr.add_child(wl)
			rb.pressed.connect( func() -> void :
				pick_key[n] = rk
				_refresh(mn, from_pause))
	var act: HBoxContainer = _hbox(8)
	col.add_child(act)
	if st != "bad":
		var export_btn: Button = UiKit.big("ЭКСПОРТ", "blue", "", 44.0, 11)
		export_btn.tooltip_text = "Сохранить последнюю точку слота в отдельный файл для отправки."
		export_btn.pressed.connect(func() -> void:
			var dialog: FileDialog = _file_dialog(mn, FileDialog.FILE_MODE_SAVE_FILE)
			dialog.title = "Экспорт слота %d" % n
			dialog.current_file = "DroneFlames_slot_%d.dfsave" % n
			dialog.file_selected.connect(func(path: String) -> void:
				var error: String = SS.export_file(n, path)
				mn._mp_toast("Сохранение экспортировано" if error == "" else error))
			dialog.popup_centered_ratio(0.75))
		act.add_child(export_btn)
	var del: Button = UiKit.big("", "stone", "", 44.0, 12)
	del.icon = icon_tex("bin")
	del.expand_icon = false
	del.custom_minimum_size.x = 52.0
	del.tooltip_text = "Удалить слот"
	del.disabled = live
	act.add_child(del)
	del.pressed.connect( func() -> void :
		del_n = n
		_refresh(mn, from_pause))
	if st != "bad":
		var go_t: String = Loc.t("ЗАГРУЗИТЬ") if from_pause else Loc.t("ИГРАТЬ")
		var go: Button = UiKit.big(go_t, "green", "mi_play", 44.0, 14)
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		act.add_child(go)
		var k2: String = key
		go.disabled = key == ""
		if live:
			go.text = "ОТКАТИТЬСЯ"
		go.pressed.connect( func() -> void : _load(mn, n, k2, from_pause))
	else:
		var why: Label = _lbl("Загрузить нечего", 10, UiKit.MUTED, 1, 1)
		why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		act.add_child(why)
	if live:
		var ll: Label = _lbl(Loc.t("Откатиться некуда: автосохранение появится через минуту.") if key == "" else Loc.t("Это идущая партия — удалить её можно из главного меню."), 10, UiKit.MUTED, 1, 1)
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(ll)


static func _file_dialog(mn: Menus, file_mode: int) -> FileDialog:
	var dialog: FileDialog = FileDialog.new()
	dialog.file_mode = file_mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.dfsave", "DroneFlames save")
	dialog.add_filter("*.save", "DroneFlames save")
	dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	else:
		dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	mn.add_child(dialog)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.file_selected.connect(func(_path: String) -> void: dialog.queue_free(), CONNECT_ONE_SHOT)
	return dialog



static func _radio(on: bool, dim: bool) -> Control:
	var p: = PanelContainer.new()
	var s: = StyleBoxFlat.new()
	s.bg_color = UiKit.GOLD if on else Color(0, 0, 0, 0.35)
	s.border_color = UiKit.OUTLINE if on else (UiKit.DIM if not dim else Color(UiKit.DIM, 0.4))
	s.set_border_width_all(2)
	s.set_corner_radius_all(7)
	s.corner_detail = 3
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(14, 14)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


static func _clock() -> TextureRect:
	var t: TextureRect = UiKit.icon_rect("si_time", 18.0)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


static func _confirm_delete(mn: Menus, col: VBoxContainer, i: Dictionary, from_pause: bool) -> void :
	var n: int = int(i["n"])
	var h: Dictionary = i["head"]
	var p: = PanelContainer.new()
	var s: = StyleBoxFlat.new()
	s.bg_color = Color(0.2, 0.05, 0.03, 0.95)
	s.border_color = UiKit.RED
	s.set_border_width_all(2)
	s.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(p)
	var v: VBoxContainer = _vbox(6)
	p.add_child(v)
	var who: String = (Loc.t("слот %d") % n) if i["state"] == "bad" else "«%s»" % Loc.name(String(h.get("country", ""))).to_upper()
	var t: Label = _lbl(Loc.t("УДАЛИТЬ %s?") % who.to_upper(), 13, UiKit.RED, 3, 2)
	v.add_child(t)
	UiKit.fit_lbl(t, [13, 12, 11], true, true)
	var pts: int = (i["rows"] as Array).size()
	var body: String = Loc.t("Пропадут все точки сохранения слота. Отменить нельзя.") if i["state"] == "bad"\
	else Loc.t("%s игры и %d %s сохранения пропадут. Отменить нельзя.") % [dur(float(h.get("elapsed", 0.0))).to_lower(), pts, Loc.n(pts, "точка", "точки", "точек", "count")]
	var bl: Label = _lbl(body, 10, UiKit.TEXT, 1, 1)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(bl)
	var r: HBoxContainer = _hbox(8)
	v.add_child(r)
	var no: Button = UiKit.big("ОТМЕНА", "stone", "", 44.0, 13)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(no)
	no.pressed.connect( func() -> void :
		del_n = -1
		_refresh(mn, from_pause))
	var yes: Button = UiKit.big("УДАЛИТЬ", "red", "", 44.0, 13)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(yes)
	yes.pressed.connect( func() -> void :
		SS.delete(n)
		UiKit.snd("ui_close")
		del_n = -1
		open_n = -1
		pick_key.erase(n)
		_refresh(mn, from_pause))


static func _load(mn: Menus, n: int, key: String, from_pause: bool) -> void :
	var m: Node = _main_node(mn)
	if from_pause and m != null and Save.can_save(m):
		Save.save_game(m)
	open_n = -1
	del_n = -1
	Save.want = [n, key]
	mn.request.emit("load_save")





static func setup_block(mn: Menus, vb: VBoxContainer) -> void :
	var infos: Array = SS.all()
	if sel < 0:
		sel = 0 if GameConfig.no_save else SS.default_pick()
	GameConfig.no_save = sel == 0
	Save.pick = sel if sel > 0 else 0
	mn._sep(vb, 4)
	mn._section(vb, "СОХРАНЕНИЕ")
	var row: HBoxContainer = _hbox(6)
	vb.add_child(row)
	for k in SS.N + 1:
		var n: int = k + 1 if k < SS.N else 0
		var on: bool = sel == n
		var b: = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key_st: String = "wb_slot_active" if on else "wb_slot"
		for s: String in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(s, UiKit.sb(key_st, 4))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		UiKit.tap_snd(b)
		row.add_child(b)
		var v: VBoxContainer = _vbox(1)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(v)
		if n == 0:
			var bi: TextureRect = icon("bolt", 22.0)
			bi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(bi)
		else:
			var inf: Dictionary = infos[n - 1]
			var num: Label = _lbl("%d" % n, 15, UiKit.TITLE if on else UiKit.TEXT, 3, 3)
			num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(num)
			if inf["state"] == "empty":
				var e: Label = _lbl("ПУСТО", 9, UiKit.DIM, 2, 1)
				e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				v.add_child(e)
			elif inf["state"] == "bad":
				var e2: Label = _lbl("СБОЙ", 9, UiKit.RED, 2, 1)
				e2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				v.add_child(e2)
			else:
				var f: Control = _flag(inf["head"], 15, 10)
				f.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				v.add_child(f)
		var nn: int = n
		b.pressed.connect( func() -> void :
			sel = nn
			_arm_t = 0
			var ks: int = mn._scroll.scroll_vertical
			mn.show_setup()
			mn._scroll.set_deferred("scroll_vertical", ks))
	if sel == 0:
		var p: = PanelContainer.new()
		var s3: = StyleBoxFlat.new()
		s3.bg_color = Color(0.2, 0.05, 0.03, 0.92)
		s3.border_color = UiKit.RED
		s3.set_border_width_all(2)
		s3.set_content_margin_all(8)
		p.add_theme_stylebox_override("panel", s3)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(p)
		var v2: VBoxContainer = _vbox(4)
		p.add_child(v2)
		var hr: HBoxContainer = _hbox(6)
		v2.add_child(hr)
		hr.add_child(icon("bolt", 20.0))
		hr.add_child(_lbl("БЕЗ СОХРАНЕНИЙ — ОДНА ЖИЗНЬ", 13, UiKit.RED, 3, 2))
		var nl: Array = ["Ни автосохранений, ни «ПРОДОЛЖИТЬ» для этой партии.", 
			"Выход в меню или закрытие игры — конец партии.", 
			"Игру свернули, а телефон её выгрузил — партия потеряна.", 
			"Партии в слотах это не тронет."]
		for ti: int in nl.size():
			var t: String = String(nl[ti])
			var l: Label = _lbl("• " + t, 10, UiKit.TEXT if ti < nl.size() - 1 else UiKit.MUTED, 1, 1)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v2.add_child(l)
	else:
		var inf2: Dictionary = infos[sel - 1]
		var txt: String = Loc.t("Слот %d свободен — партия будет сохраняться сюда.") % sel
		var c: Color = UiKit.MUTED
		if inf2["state"] == "bad":
			txt = Loc.t("Слот %d повреждён — его файлы заменит новая партия.") % sel
		elif inf2["state"] != "empty":
			txt = Loc.t("В слоте %d — %s (%s). Новая партия её заменит.") % [sel, Loc.name(String((inf2["head"] as Dictionary).get("country", ""))).to_upper(), dur(float((inf2["head"] as Dictionary).get("elapsed", 0.0))).to_lower()]
			c = UiKit.GOLD
		mn._label(vb, txt, 10, c)




static func setup_footer(mn: Menus, go: Button) -> void :
	var replace: bool = sel > 0 and SS.info(sel)["state"] in ["ok", "ended"]
	var line: = HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var par: Node = go.get_parent()
	par.get_parent().add_child(line)
	par.get_parent().move_child(line, par.get_index())
	if sel == 0:
		line.add_child(icon("bolt", 14.0))
		line.add_child(_lbl("БЕЗ СОХРАНЕНИЙ", 10, UiKit.RED, 3, 1))
	else:
		line.add_child(icon("disk", 14.0))
		line.add_child(_lbl((Loc.t("ЗАМЕНИТ СЛОТ %d") if replace else Loc.t("СОХРАНЕНИЕ В СЛОТ %d")) % sel, 10, UiKit.GOLD if replace else UiKit.MUTED, 2, 1))
	if not replace:
		return
	for c: Dictionary in go.pressed.get_connections():
		go.pressed.disconnect(c["callable"])
	var label0: String = go.text
	var gw_ref: WeakRef = weakref(go)
	go.pressed.connect( func() -> void :
		var now: int = Time.get_ticks_msec()
		if _arm_t > now:
			_arm_t = 0
			mn.request.emit("start")
			return
		_arm_t = now + 3000
		UiKit.snd("ui_select")
		go.text = Loc.t("ЗАМЕНИТЬ СЛОТ %d?") % sel
		go.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_red", 12, 4, -1))
		go.add_theme_stylebox_override("hover", UiKit.sb("wb_btn_red", 12, 4, -1))
		go.get_tree().create_timer(3.0).timeout.connect( func() -> void :
			var g2: Button = gw_ref.get_ref() as Button
			if g2 != null and _arm_t > 0 and Time.get_ticks_msec() >= _arm_t:
				g2.text = label0
				g2.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_green", 12, 4, -1))
				g2.add_theme_stylebox_override("hover", UiKit.sb("wb_btn_green", 12, 4, -1))))





static func pause_row(mn: Menus, vb: VBoxContainer) -> void :
	var m: Node = _main_node(mn)
	if GameConfig.no_save:
		var p: = PanelContainer.new()
		var s: = StyleBoxFlat.new()
		s.bg_color = Color(0.2, 0.05, 0.03, 0.92)
		s.border_color = UiKit.RED
		s.set_border_width_all(2)
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 5
		s.content_margin_bottom = 6
		p.add_theme_stylebox_override("panel", s)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(p)
		var r: HBoxContainer = _hbox(6)
		p.add_child(r)
		r.add_child(icon("bolt", 20.0))
		var v: VBoxContainer = _vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(v)
		v.add_child(_lbl("БЕЗ СОХРАНЕНИЙ", 12, UiKit.RED, 3, 2))
		var l: Label = _lbl("Выход в меню или закрытие игры завершит партию.", 10, UiKit.TEXT, 1, 1)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		return
	var row: HBoxContainer = _hbox(8)
	vb.add_child(row)
	var sv: Button = UiKit.big("СОХРАНИТЬ", "stone", "", 44.0, 12)
	sv.icon = icon_tex("disk")
	sv.expand_icon = false
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sv)
	var ld: Button = UiKit.big("ЗАГРУЗИТЬ", "stone", "", 44.0, 12)
	ld.icon = icon_tex("folder")
	ld.expand_icon = false
	ld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ld)
	var st: Label = mn._label(vb, _pause_status(), 10, UiKit.MUTED)
	var why: String = Save.why_not(m)
	if why != "":
		sv.disabled = true
		st.text = Loc.t(why)
	sv.pressed.connect( func() -> void :
		var ok: bool = Save.save_game(m)
		UiKit.snd("ui_select" if ok else "ui_error")
		sv.text = Loc.t("СОХРАНЕНО") if ok else Loc.t("НЕ ВЫШЛО")
		sv.add_theme_color_override("font_color", UiKit.GREEN if ok else UiKit.RED)
		st.text = _pause_status() if ok else Loc.t("Не удалось записать файл — места мало?")
		var sref: WeakRef = weakref(sv)
		sv.get_tree().create_timer(1.6).timeout.connect( func() -> void :
			var s2: Button = sref.get_ref() as Button
			if s2 != null:
				s2.text = "СОХРАНИТЬ"
				s2.remove_theme_color_override("font_color")))
	ld.pressed.connect( func() -> void :
		open_n = Save.slot
		del_n = -1
		mn.show_saves(true))


static func _pause_status() -> String:
	var r: Array = SS.rows(Save.slot)
	if r.is_empty() or Save._fresh:
		return Loc.t("Слот %d · партия ещё не сохранялась") % Save.slot
	return Loc.t("Слот %d · сохранено %s") % [Save.slot, when ((r[0] as Dictionary)["h"]).to_lower()]



static func quit_button(mn: Menus, vb: VBoxContainer) -> void :
	var b: Button = UiKit.big("ЗАВЕРШИТЬ ПАРТИЮ", "red", "", 44.0, 14)
	vb.add_child(b)
	b.pressed.connect( func() -> void :
		var now: int = Time.get_ticks_msec()
		if _arm_t > now:
			_arm_t = 0
			mn.request.emit("main_menu")
			return
		_arm_t = now + 3000
		UiKit.snd("ui_select")
		b.text = "ТОЧНО? ПАРТИЯ ПРОПАДЁТ"
		var bref: WeakRef = weakref(b)
		b.get_tree().create_timer(3.0).timeout.connect( func() -> void :
			var b2: Button = bref.get_ref() as Button
			if b2 != null and Time.get_ticks_msec() >= _arm_t:
				b2.text = "ЗАВЕРШИТЬ ПАРТИЮ"))
