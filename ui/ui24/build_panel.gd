extends RefCounted





const U = preload("res://ui/ui24/econ_kit.gd")
const TAB_W: float = 50.0
const TAB_H: float = 46.0
const TAB_FONT: int = 10
const CELL_W: float = 54.0
const KEY_FONT: int = 9
const TAB_LABELS: Array = ["КАРТА", "ГОРОДА", "АВИА", "ПВО", "АРМИЯ", "ПОЛИТ.", "НЕДРА"]
const PAGE_TITLES: Array = ["Карта и время", "Города и экономика", "Дроны, ракеты, авиация", "Противовоздушная оборона", 
	"Наземная армия", "Дипломатия и торговля", "Добыча и ресурсы"]
const PAGE_SUBS: Array = ["Масштаб, режимы карты, значки", "Столица, города, заводы, энергия, порт", "Пуски, заводы, ОТРК, аэродром", 
	"ЗСУ, ЗРК, перехватчики, РЛС, РЭБ", "Казармы, штаб, окопы, оборона", "Отношения, договоры, ультиматумы, рынок", "Рудники, лесопилки, нефть, НПЗ"]

static var _cond: Array = []

static var widths: Dictionary = {}


static func condensed() -> Array:
	if _cond.is_empty():

		for src: FontVariation in [UiKit.f_bold, UiKit.f_reg]:
			var fv: = FontVariation.new()
			fv.base_font = src.base_font
			fv.variation_opentype = src.variation_opentype
			fv.spacing_glyph = -1
			_cond.append(fv)
	return _cond



static func fit(l: Label, w: float, fs: int) -> void :
	var px: float = 0.0
	var shown: String = l.text if l.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else Loc.t(l.text)
	for f: Font in [UiKit.f_bold] + condensed():
		px = f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		l.add_theme_font_override("font", f)
		if px <= w:
			break
	widths[l.text] = [px, w]



static func make_tab(icon_name: String, label: String, tab_w: float = TAB_W, keyboard_accessible: bool = false) -> Button:
	var b: = Button.new()
	b.custom_minimum_size = Vector2(tab_w, TAB_H)
	b.focus_mode = Control.FOCUS_ALL if keyboard_accessible else Control.FOCUS_NONE
	b.toggle_mode = true
	b.add_theme_stylebox_override("normal", UiKit.sb("wb_tab", 2, 2))
	b.add_theme_stylebox_override("hover", UiKit.sb("wb_tab", 2, 2))
	b.add_theme_stylebox_override("pressed", UiKit.sb("wb_tab_active", 2, 2))
	b.add_theme_stylebox_override("hover_pressed", UiKit.sb("wb_tab_active", 2, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic: TextureRect = U.icon(icon_name, 22.0)
	ic.name = "Icon"
	b.add_child(ic)
	var tl: Label = UiKit.lbl(label, TAB_FONT, UiKit.TEXT, 2, 2)
	tl.name = "TabName"
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.clip_text = true
	fit(tl, tab_w - 8.0, TAB_FONT + (1 if keyboard_accessible else 0))
	b.add_child(tl)
	tl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tl.offset_top = -17.0
	tl.offset_bottom = -4.0
	var place: = func() -> void :
		ic.position = Vector2(roundf((b.size.x - ic.size.x) * 0.5), 5.0)
	b.resized.connect(place)
	return b



static func style_tab(b: Button, on: bool) -> void :
	var ic: Control = b.get_node_or_null("Icon") as Control
	if ic != null:
		ic.modulate = Color(1, 1, 1) if on else Color(0.82, 0.82, 0.76)
	var tl: Label = b.get_node_or_null("TabName") as Label
	if tl != null:
		U.set_lbl(tl, tl.text, UiKit.TEXT if on else UiKit.MUTED)



static func set_key_badge(b: Button, n: int) -> void :
	if b == null or not is_instance_valid(b):
		return
	var bd: Label = b.get_node_or_null("KeyBadge") as Label
	if bd == null:
		if n <= 0:
			return
		bd = U.badge_label(n)
		bd.name = "KeyBadge"
		b.add_child(bd)
		bd.position = Vector2(b.custom_minimum_size.x - 10.0, -4.0)
	U.set_vis(bd, n > 0)
	if bd.text != str(n):
		bd.text = str(n)
