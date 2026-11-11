class_name LangPicker
extends CanvasLayer












signal done(code: String)


const SHOW_ES: bool = false
const LAYER_FIRST: int = 110
const LAYER_SHEET: int = 25
const CARD_H: float = 72.0
const MED: float = 44.0
const BG: String = "res://assets/sprites/lang_bg340.png"
const AMBER: = Color("e8a030")
const SMALL: = Color("c8c8a8")

const PLATE: Dictionary = {"ru": Color("5e4a3a"), "uk": Color("574463"), "en": Color("3f5a4e"), "es": Color("5a5236")}
const PLATE_ON: = Color("c8862a")

const TXT: Dictionary = {
	"ru": {"name": "Русский", "glyph": "Яя", "sample": "ПВО · ДРОНЫ · ГОРОДА", "title": "ЯЗЫК", "go": "ПРОДОЛЖИТЬ", "note": "Язык можно сменить в Настройках", "back": "НАЗАД"}, 
	"uk": {"name": "Українська", "glyph": "Її", "sample": "ППО · ДРОНИ · МІСТА", "title": "МОВА", "go": "ПРОДОВЖИТИ", "note": "Мову можна змінити в Налаштуваннях", "back": "НАЗАД"}, 
	"en": {"name": "English", "glyph": "Aa", "sample": "AIR DEFENSE · DRONES · CITIES", "title": "LANGUAGE", "go": "CONTINUE", "note": "You can change it later in Settings", "back": "BACK"}, 
	"es": {"name": "Español", "glyph": "Ññ", "sample": "DEFENSA AÉREA · DRONES · CIUDADES", "title": "IDIOMA", "go": "CONTINUAR", "note": "Puedes cambiarlo más tarde en Ajustes", "back": "ATRÁS"}, 
}

const NEAR_RU: PackedStringArray = ["be", "kk", "ky", "tg"]

var first: bool = true
var sel: String = "ru"
var root: Control
var panel: PanelContainer
var title_l: Label
var go: Button
var note: Label
var cards: Dictionary = {}
var _menus: Node = null
var _hidden: Control = null
var _logo: TextureRect = null
var _bg: TextureRect = null
var _cc: Control = null
var _closing: bool = false
var _t: float = 0.0
var _sm: Vector2 = Vector2.ZERO
var _logo_base: float = 0.0





static func langs() -> PackedStringArray:
	return PackedStringArray(["ru", "uk", "en", "es"]) if SHOW_ES else PackedStringArray(["ru", "uk", "en"])



static func device_lang(os_code: String = "") -> String:
	var c: String = (os_code if os_code != "" else OS.get_locale_language()).strip_edges().to_lower().replace("-", "_").get_slice("_", 0)
	if c == "ua":
		c = "uk"
	if langs().has(c):
		return c
	if NEAR_RU.has(c):
		return "ru"
	return "en"




static func needed(main: Node) -> bool:
	if GameConfig.lang != "":
		return false
	if OS.has_environment("DF_LANGPICK"):
		return OS.get_environment("DF_LANGPICK") != "0"
	if DisplayServer.get_name() == "headless" or OS.has_environment("DF_NO_OPENING") or OS.has_environment("DF_LANG"):
		return false
	if not OS.get_cmdline_user_args().is_empty() or OS.get_cmdline_args().has("--verify"):
		return false
	var tree: SceneTree = main.get_tree()
	return tree != null and tree.current_scene == main



static func first_run(main: Node) -> String:
	var p: LangPicker = LangPicker.new()
	p.name = "LangPicker"
	p.first = true
	main.add_child(p)
	var code: String = await p.done
	return code



static func open_from(menus: Node) -> void :
	var p: LangPicker = LangPicker.new()
	p.name = "LangPicker"
	p.first = false
	p._menus = menus
	var scr: Variant = menus.get("screen")
	if scr is Control and is_instance_valid(scr):
		p._hidden = scr
		p._hidden.visible = false
	menus.add_child(p)



static func row_title() -> String:
	var c: String = Loc.cur()
	var own: String = String((TXT.get(c, TXT["ru"]) as Dictionary)["title"])
	return own if c == "en" else own + " · LANGUAGE"



static func row_hint() -> String:
	return String((TXT.get(Loc.cur(), TXT["ru"]) as Dictionary)["name"])







func _ready() -> void :
	layer = LAYER_FIRST if first else LAYER_SHEET
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.ensure()
	sel = device_lang() if first else Loc.cur()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = UiKit.make_theme()
	root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(root)
	if first:
		_build_backdrop()
	else:
		var dim: = ColorRect.new()
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0, 0, 0, 0.55)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(dim)
	_cc = CenterContainer.new()
	_cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_cc)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.sb("wb_window", 16, 14))
	panel.custom_minimum_size = Vector2(330, 0)
	_cc.add_child(panel)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 9)
	panel.add_child(vb)

	var head: = HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(head)
	if UiKit.tex("net_globe") != null:
		var gl: TextureRect = UiKit.icon_rect("net_globe", 24.0)
		gl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(gl)
	title_l = UiKit.title(_tx("title"), 22)
	head.add_child(title_l)
	var div: = ColorRect.new()
	div.color = Color(UiKit.GOLD, 0.35)
	div.custom_minimum_size = Vector2(0, 2)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(div)
	for c: String in langs():
		vb.add_child(_card(c))

	if first:
		go = UiKit.big(_tx("go"), "green", "", 52.0, 16)
		go.pressed.connect(_confirm)
	else:
		go = UiKit.big(_tx("back"), "stone", "", 48.0, 15)
		go.pressed.connect(_close_sheet)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(go)
	if first:
		note = UiKit.lbl(_tx("note"), 11, SMALL, 1, 1)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(note)
	_paint(false)
	root.resized.connect(_layout)
	panel.resized.connect(_layout)
	_layout()
	panel.modulate.a = 0.0
	await get_tree().process_frame
	_layout()
	UiKit.pop_in(panel, 0.88, 0.26)
	UiKit.snd("ui_open")




func _build_backdrop() -> void :
	var sky: = TextureRect.new()
	var g: = Gradient.new()
	g.set_color(0, Color("0b0f1e"))
	g.set_color(1, Color("120e1a"))
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	sky.texture = gt
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sky)
	if ResourceLoader.exists(BG):
		_bg = TextureRect.new()
		_bg.texture = load(BG) as Texture2D
		_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bg.stretch_mode = TextureRect.STRETCH_SCALE
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_bg)
	_logo = TextureRect.new()
	_logo.texture = UiKit.tex("logo_df")
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_logo)




func _card(code: String) -> Control:
	var T: Dictionary = TXT[code]
	var b: = Button.new()
	b.name = "Lang_" + code
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, CARD_H)
	var st: StyleBox = UiKit.sb("wb_panel_dark", 8, 4)
	for k: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(k, st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row: = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12.0
	row.offset_right = -12.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	b.add_child(row)
	var med: = Control.new()
	med.custom_minimum_size = Vector2(MED, MED)
	med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	med.clip_contents = true
	med.mouse_filter = Control.MOUSE_FILTER_IGNORE
	med.draw.connect(_draw_med.bind(med, code))
	row.add_child(med)
	var gch: Label = UiKit.lbl(String(T["glyph"]), 22, UiKit.TEXT, 2, 1)
	gch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gch.set_anchors_preset(Control.PRESET_FULL_RECT)
	gch.offset_top = -1.0
	med.add_child(gch)
	var shine: = ColorRect.new()
	shine.color = Color(1.0, 0.97, 0.85, 0.0)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.size = Vector2(6, 80)
	shine.rotation = 0.5
	shine.position = Vector2(-30, -20)
	med.add_child(shine)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var nm: Label = UiKit.lbl(String(T["name"]), 19, UiKit.TEXT, 3, 3)
	col.add_child(nm)
	var smp: Label = UiKit.lbl(String(T["sample"]), 11, SMALL, 1, 1)
	smp.clip_text = true
	smp.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(smp)
	var ck: = TextureRect.new()
	ck.custom_minimum_size = Vector2(24, 24)
	ck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ck.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ck.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ck.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ck.texture = UiKit.tex("wb_check")
	ck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ck)
	var fr: = Panel.new()
	var fs: = StyleBoxFlat.new()
	fs.bg_color = Color(AMBER, 0.06)
	fs.border_color = AMBER
	fs.set_border_width_all(2)
	fs.anti_aliasing = false
	fr.add_theme_stylebox_override("panel", fs)
	fr.set_anchors_preset(Control.PRESET_FULL_RECT)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(fr)
	UiKit.press_fx(b)
	b.pressed.connect(_pick.bind(code))
	cards[code] = {"b": b, "med": med, "g": gch, "nm": nm, "smp": smp, "ck": ck, "shine": shine, "fr": fr}
	return b




func _draw_med(c: Control, code: String) -> void :
	var on: bool = code == sel
	var base: Color = PLATE_ON if on else (PLATE.get(code, Color("4a4a3a")) as Color)
	var hi: Color = base.lightened(0.32)
	var lo: Color = base.darkened(0.5)
	var w: float = c.size.x
	var h: float = c.size.y
	c.draw_rect(Rect2(0, 0, w, h), UiKit.OUTLINE)
	c.draw_rect(Rect2(1, 1, w - 2, h - 2), base)
	c.draw_rect(Rect2(1, 1, w - 2, 2), hi)
	c.draw_rect(Rect2(1, 1, 2, h - 2), hi)
	c.draw_rect(Rect2(1, h - 3, w - 2, 2), lo)
	c.draw_rect(Rect2(w - 3, 1, 2, h - 2), lo)
	for p: Vector2 in [Vector2(5, 5), Vector2(w - 7, 5), Vector2(5, h - 7), Vector2(w - 7, h - 7)]:
		c.draw_rect(Rect2(p, Vector2(2, 2)), lo)
		c.draw_rect(Rect2(p, Vector2(1, 1)), hi)



func _paint(anim: bool) -> void :
	for c: String in cards:
		var d: Dictionary = cards[c]
		var on: bool = c == sel
		var b: Button = _nd(d, "b")
		var med: Control = _nd(d, "med")
		var nm: Label = _nd(d, "nm")
		var smp: Label = _nd(d, "smp")
		var ck: TextureRect = _nd(d, "ck")
		var sh: ColorRect = _nd(d, "shine")
		var fr: Panel = _nd(d, "fr")
		if b == null or med == null or nm == null or smp == null or ck == null or sh == null or fr == null:
			continue
		med.queue_redraw()
		nm.add_theme_color_override("font_color", UiKit.TITLE if on else UiKit.TEXT)
		smp.add_theme_color_override("font_color", SMALL)
		ck.visible = on
		fr.visible = on
		b.modulate = Color.WHITE if on else Color(0.88, 0.88, 0.86)
		if on and anim:
			b.pivot_offset = b.size * 0.5
			b.scale = Vector2(1.035, 1.035)
			b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ck.pivot_offset = Vector2(12, 12)
			ck.scale = Vector2(0.2, 0.2)
			ck.create_tween().tween_property(ck, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			sh.position = Vector2(-30, -20)
			sh.color.a = 0.55
			var tw: Tween = sh.create_tween().set_parallel(true)
			tw.tween_property(sh, "position:x", 60.0, 0.35).set_trans(Tween.TRANS_SINE)
			tw.tween_property(sh, "color:a", 0.0, 0.35).set_delay(0.1)



func _nd(d: Dictionary, k: String) -> Object:
	var v: Variant = d.get(k)
	return v if is_instance_valid(v) else null


func _tx(key: String) -> String:
	return String((TXT.get(sel, TXT["ru"]) as Dictionary)[key])



func _pick(code: String) -> void :
	if _closing:
		return
	UiKit.snd("ui_select")
	var changed: bool = code != sel
	sel = code
	_paint(true)
	if changed:
		_retext()
	if not first and code != Loc.cur():
		Loc.set_lang(code)


func _retext() -> void :
	title_l.text = _tx("title")
	title_l.pivot_offset = title_l.size * 0.5
	title_l.scale = Vector2(0.85, 0.85)
	title_l.create_tween().tween_property(title_l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	go.text = _tx("go") if first else _tx("back")
	if note != null:
		note.text = _tx("note")



func _confirm() -> void :
	if _closing:
		return
	_closing = true
	Loc.set_lang(sel)
	var tw: Tween = create_tween().set_parallel(true)
	panel.pivot_offset = panel.size * 0.5
	tw.tween_property(panel, "scale", Vector2(0.94, 0.94), 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(root, "modulate:a", 0.0, 0.28).set_delay(0.06)
	await tw.finished
	done.emit(sel)
	queue_free()



func _close_sheet() -> void :
	if _closing:
		return
	_closing = true
	var mv: Variant = _menus
	queue_free()
	if is_instance_valid(mv) and _hidden != null and is_instance_valid(_hidden):
		var m: Object = mv
		m.call("show_settings", bool(m.get("_from_pause")))
	done.emit(Loc.cur())


func _process(delta: float) -> void :
	_t += delta
	if not first and not _closing:


		var scr: Variant = _menus.get("screen") if _menus != null and is_instance_valid(_menus) else null
		if scr != _hidden and scr is Control and is_instance_valid(scr) and String(_menus.get("current")) == "settings":
			_hidden = scr
			_hidden.visible = false
		elif _hidden == null or not is_instance_valid(_hidden) or scr != _hidden:
			_closing = true
			if _hidden != null and is_instance_valid(_hidden):
				_hidden.visible = true
			queue_free()
			return
	if _logo != null:
		_logo.position.y = _logo_base + roundf(sin(_t * 1.6) * 2.0)






func _layout() -> void :
	if root == null or panel == null:
		return
	var vw: Vector2 = root.size
	if vw.x <= 0.0:
		return
	_sm = _safe_tb()
	panel.custom_minimum_size.x = minf(330.0, vw.x - 16.0)
	var ph: float = panel.get_combined_minimum_size().y
	if not first:
		_cc.offset_top = maxf(_sm.x, vw.y - _sm.y - 16.0 - ph)
		_cc.offset_bottom = - _sm.y - 16.0 if ph < vw.y * 0.8 else - _sm.y
		return
	if _bg != null and _bg.texture != null:
		var ts: Vector2 = _bg.texture.get_size()
		var k: float = ceilf(maxf(vw.x / ts.x, vw.y / ts.y))
		_bg.size = ts * k
		_bg.position = Vector2(roundf((vw.x - ts.x * k) * 0.5), vw.y - ts.y * k)
	var lo: float = _sm.x + 8.0
	var hi: float = vw.y - _sm.y - 8.0 - ph
	var top: float = clampf(roundf(vw.y * 0.55 - ph * 0.5), lo, maxf(lo, hi))
	if _logo != null and _logo.texture != null:
		var ts2: Vector2 = _logo.texture.get_size()
		var cover: float = maxf(vw.x / Loading.SPLASH_SIZE.x, vw.y / Loading.SPLASH_SIZE.y)
		var k2: float = minf(Loading.SPLASH_K * cover, (vw.x * 0.7) / 150.0)
		var ly: float = maxf(_sm.x + 6.0, roundf(vw.y * 0.1 - ts2.y * k2 * 0.15))
		var room: float = top - 12.0 - ly
		if ts2.y * k2 > room:
			k2 = maxf(1.0, room / ts2.y)
			ly = maxf(_sm.x + 4.0, top - 12.0 - ts2.y * k2)
		if ly + ts2.y * k2 + 12.0 > top:
			top = minf(maxf(lo, hi), ly + ts2.y * k2 + 12.0)
		_logo.size = ts2
		_logo.scale = Vector2(k2, k2)
		_logo.position = Vector2(roundf((vw.x - ts2.x * k2) * 0.5 - 5.4 * k2), ly)
		_logo_base = ly
	_cc.offset_top = top
	_cc.offset_bottom = top + ph - vw.y


func _safe_tb() -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if win.x <= 0.0 or safe.size.x <= 0 or safe.size.y <= 0 or root == null or root.size.x <= 0.0:
		return Vector2.ZERO
	var s: float = root.size.x / win.x
	var t: float = maxf(0.0, float(safe.position.y) * s)
	var b: float = maxf(0.0, (win.y - float(safe.end.y)) * s)
	return Vector2.ZERO if t > 90.0 or b > 90.0 else Vector2(t, b)
