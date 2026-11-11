class_name UiKit
extends RefCounted





static var atlas: SpriteAtlas
static var atlas2: SpriteAtlas
static var atlas3: SpriteAtlas
static var atlas4: SpriteAtlas
static var atlas5: SpriteAtlas
static var atlas6: SpriteAtlas
static var atlas7: SpriteAtlas
static var atlas8: SpriteAtlas
static var atlas9: SpriteAtlas
static var atlas10: SpriteAtlas
static var atlas11: SpriteAtlas
static var atlas12: SpriteAtlas
static var atlas13: SpriteAtlas
static var atlas14: SpriteAtlas
static var atlas15: SpriteAtlas
static var atlas16: SpriteAtlas
static var atlas17: SpriteAtlas
static var atlas18: SpriteAtlas
static var atlas19: SpriteAtlas
static var atlas20: SpriteAtlas
static var atlas_dip26: SpriteAtlas
static var atlas_navy1: SpriteAtlas
static var atlas_uran30ui: SpriteAtlas
static var atlas_navy30: SpriteAtlas
static var atlas_ui319: SpriteAtlas
static var atlas_net29: SpriteAtlas
static var atlas_acc1: SpriteAtlas
static var atlas_cosm_fr: SpriteAtlas
static var atlas_cosm_bn: SpriteAtlas
static var atlas_cosm_tt: SpriteAtlas
static var atlas_cosm_bn_anim: SpriteAtlas
static var font: FontFile
static var f_reg: FontVariation
static var f_bold: FontVariation
static var f_black: FontVariation
static var f_title: Font
static var _sfx: GDScript
static var _sfx_checked: bool = false

const TITLE: = Color("ffb13d")
const TEXT: = Color("fbf3e0")
const MUTED: = Color("cfc6a8")
const DIM: = Color("8f8a76")
const RED: = Color("ff6a4d")
const GREEN: = Color("a2e35f")
const BLUE: = Color("7cccff")
const GOLD: = Color("ffd75e")
const OUTLINE: = Color("1b120c")
const SHADOW: = Color(0.06, 0.04, 0.02, 0.85)


static func ensure() -> void :
	if atlas != null:
		return
	atlas = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui.png", "res://assets/sprites/atlas_ui.json")
	atlas2 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui2.png", "res://assets/sprites/atlas_ui2.json")
	atlas3 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui3.png", "res://assets/sprites/atlas_ui3.json")
	atlas4 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui4.png", "res://assets/sprites/atlas_ui4.json")
	atlas5 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui5.png", "res://assets/sprites/atlas_ui5.json")
	atlas6 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui6.png", "res://assets/sprites/atlas_ui6.json")
	atlas7 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui7.png", "res://assets/sprites/atlas_ui7.json")
	atlas8 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui8.png", "res://assets/sprites/atlas_ui8.json")
	atlas9 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui9.png", "res://assets/sprites/atlas_ui9.json")
	atlas10 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui10.png", "res://assets/sprites/atlas_ui10.json")
	atlas11 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui11.png", "res://assets/sprites/atlas_ui11.json")
	atlas12 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui12.png", "res://assets/sprites/atlas_ui12.json")
	atlas13 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui13.png", "res://assets/sprites/atlas_ui13.json")
	atlas14 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui14.png", "res://assets/sprites/atlas_ui14.json")
	atlas15 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui15.png", "res://assets/sprites/atlas_ui15.json")
	atlas16 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui16.png", "res://assets/sprites/atlas_ui16.json")
	atlas17 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui17.png", "res://assets/sprites/atlas_ui17.json")
	atlas18 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui18.png", "res://assets/sprites/atlas_ui18.json")
	atlas19 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui19.png", "res://assets/sprites/atlas_ui19.json", true)
	atlas20 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui20.png", "res://assets/sprites/atlas_ui20.json", true)
	atlas_dip26 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_dip26.png", "res://assets/sprites/atlas_dip26.json", true)
	atlas_navy1 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_navy1.png", "res://assets/sprites/atlas_navy1.json", true)
	atlas_uran30ui = SpriteAtlas.load_atlas("res://assets/sprites/atlas_uran30ui.png", "res://assets/sprites/atlas_uran30ui.json", true)
	atlas_navy30 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_navy30.png", "res://assets/sprites/atlas_navy30.json", true)
	atlas_net29 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_net29.png", "res://assets/sprites/atlas_net29.json", true)
	atlas_acc1 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_acc1.png", "res://assets/sprites/atlas_acc1.json", true)
	atlas_cosm_fr = SpriteAtlas.load_atlas("res://assets/sprites/atlas_cosm_fr.png", "res://assets/sprites/atlas_cosm_fr.json", true)
	atlas_cosm_bn = SpriteAtlas.load_atlas("res://assets/sprites/atlas_cosm_bn.png", "res://assets/sprites/atlas_cosm_bn.json", true)
	atlas_cosm_tt = SpriteAtlas.load_atlas("res://assets/sprites/atlas_cosm_tt.png", "res://assets/sprites/atlas_cosm_tt.json", true)
	atlas_cosm_bn_anim = SpriteAtlas.load_atlas("res://assets/sprites/atlas_cosm_bn_anim.png", "res://assets/sprites/atlas_cosm_bn_anim.json", true)
	atlas_ui319 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui319.png", "res://assets/sprites/atlas_ui319.json", true)
	font = load("res://assets/fonts/PressStart2P-Regular.ttf") as FontFile
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.generate_mipmaps = false
	var rub: FontFile = load("res://assets/fonts/Rubik-Variable.ttf") as FontFile
	rub.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	rub.hinting = TextServer.HINTING_LIGHT
	rub.generate_mipmaps = false
	var wght: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	f_reg = FontVariation.new()
	f_reg.base_font = rub
	f_reg.variation_opentype = {wght: 500}
	f_bold = FontVariation.new()
	f_bold.base_font = rub
	f_bold.variation_opentype = {wght: 700}
	f_black = FontVariation.new()
	f_black.base_font = rub
	f_black.variation_opentype = {wght: 850}
	f_black.spacing_space = 2
	f_bold.spacing_space = 1
	var ro: FontFile = load("res://assets/fonts/RussoOne-Regular.ttf") as FontFile
	if ro != null:
		ro.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		ro.generate_mipmaps = false
		f_title = ro
	else:
		f_title = f_black



	var sym: FontFile = load("res://assets/fonts/DFSymbols-Bold.ttf") as FontFile if ResourceLoader.exists("res://assets/fonts/DFSymbols-Bold.ttf") else null
	if sym != null:
		sym.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		sym.generate_mipmaps = false
		rub.fallbacks = [sym]
		if ro != null:
			ro.fallbacks = [sym]








const TAP_SFX: Dictionary = {"ui_click": true, "ui_tab": true, "ui_open": true, "ui_close": true, "ui_select": true, "ui_cancel": true}
const TAP_WINDOW_MS: int = 1500
static var _tap_n: int = 0
static var _tap_ms: int = -100000
static var _tap_done: int = -1
static var tap_skipped: int = 0


static func tap_begin() -> void :
	var now: int = Time.get_ticks_msec()
	if now - _tap_ms < 80:
		return
	_tap_n += 1
	_tap_ms = now



static func snd(id: String) -> void :
	if TAP_SFX.has(id) and Time.get_ticks_msec() - _tap_ms < TAP_WINDOW_MS:
		if _tap_done == _tap_n:
			tap_skipped += 1
			return
		_tap_done = _tap_n
	if not _sfx_checked:
		_sfx_checked = true
		if ResourceLoader.exists("res://core/sfx.gd"):
			_sfx = load("res://core/sfx.gd") as GDScript
	if _sfx != null:
		_sfx.call("ui", id)




static func _all() -> Array:
	return [atlas_ui319, atlas9, atlas, atlas2, atlas3, atlas4, atlas5, atlas6, atlas7, atlas8, atlas10, atlas11, atlas12, atlas13, atlas14, atlas15, atlas16, atlas17, atlas18, atlas19, atlas20, atlas_dip26, atlas_navy1, atlas_net29, atlas_acc1, atlas_navy30, atlas_uran30ui, atlas_cosm_fr, atlas_cosm_bn, atlas_cosm_tt]


static func has(sprite_name: String) -> bool:
	ensure()
	if Engine.get_main_loop() != null:
		var loop = Engine.get_main_loop()
		if "root" in loop and loop.root != null and loop.root.has_node("ModManager"):
			var mm = loop.root.get_node("ModManager")
			if mm != null and mm.has_method("get_custom_texture"):
				if mm.get_custom_texture(sprite_name) != null:
					return true
	if sprite_name.begins_with("d331_") or sprite_name.begins_with("r332_") or sprite_name.begins_with("u335_"):
		return _at(sprite_name) != null
	for at: SpriteAtlas in _all():
		if at.has(sprite_name):
			return true
	if sprite_name == "icon_refresh":
		return has("net_refresh")
	return sprite_name == "icon_play_big" or sprite_name == "icon_attack_jet"


static var _atk_icon: AtlasTexture = null


static func _attack_icon() -> AtlasTexture:
	if _atk_icon == null:


		var ui: SpriteAtlas = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui316.png", "res://assets/sprites/atlas_ui316.json", true)
		if ui.has("icon_attack"):
			_atk_icon = ui.region("icon_attack")
		else:
			var at: SpriteAtlas = SpriteAtlas.load_atlas("res://assets/sprites/atlas_air316.png", "res://assets/sprites/atlas_air316.json", true)
			_atk_icon = at.region("attack", 12) if at.has("attack") else null
	return _atk_icon


static var atlas_ally320: SpriteAtlas
static var atlas_dip331: SpriteAtlas
static var atlas_rail332: SpriteAtlas
static var atlas_ui335: SpriteAtlas


static func _at(sprite_name: String) -> SpriteAtlas:
	if sprite_name.begins_with("ally_") or sprite_name == "icon_map_alliance":
		if atlas_ally320 == null:
			atlas_ally320 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ally320.png", "res://assets/sprites/atlas_ally320.json", true)
		if atlas_ally320 != null and atlas_ally320.has(sprite_name):
			return atlas_ally320
	if sprite_name.begins_with("u335_"):
		if atlas_ui335 == null:
			atlas_ui335 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui335.png", "res://assets/sprites/atlas_ui335.json", true)
		return atlas_ui335 if atlas_ui335.has(sprite_name) else null
	if sprite_name.begins_with("r332_"):
		if atlas_rail332 == null:
			atlas_rail332 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_rail332.png", "res://assets/sprites/atlas_rail332.json", true)
		return atlas_rail332 if atlas_rail332.has(sprite_name) else null
	if sprite_name.begins_with("d331_"):
		if atlas_dip331 == null:
			atlas_dip331 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_dip331.png", "res://assets/sprites/atlas_dip331.json", true)
		return atlas_dip331 if atlas_dip331.has(sprite_name) else null
	if sprite_name.begins_with("net_") and atlas_net29 != null and atlas_net29.has(sprite_name):
		return atlas_net29
	if sprite_name.begins_with("acc_") and atlas_acc1 != null and atlas_acc1.has(sprite_name):
		return atlas_acc1
	if sprite_name.begins_with("fr_") and atlas_cosm_fr != null and atlas_cosm_fr.has(sprite_name):
		return atlas_cosm_fr
	if sprite_name.begins_with("bn_") and atlas_cosm_bn != null and atlas_cosm_bn.has(sprite_name):
		return atlas_cosm_bn
	if sprite_name.begins_with("tt_") and atlas_cosm_tt != null and atlas_cosm_tt.has(sprite_name):
		return atlas_cosm_tt
	for at: SpriteAtlas in _all():
		if at.has(sprite_name):
			return at
	return null


static var _custom_tex_cache: Dictionary = {}

static func tex(sprite_name: String) -> Texture2D:
	ensure()
	if Engine.get_main_loop() != null:
		var loop = Engine.get_main_loop()
		if "root" in loop and loop.root != null and loop.root.has_node("ModManager"):
			var mm = loop.root.get_node("ModManager")
			var ct = mm.get_custom_texture(sprite_name)
			if ct != null:
				return ct
	if sprite_name == "icon_play_big":
		return atlas7.region("icon_play")
	if sprite_name == "icon_attack_jet":
		return _attack_icon()
	if sprite_name == "icon_refresh":
		return tex("net_refresh")
	var at: SpriteAtlas = _at(sprite_name)
	if at == null:
		if _custom_tex_cache.has(sprite_name):
			return _custom_tex_cache[sprite_name]
		var p: String = "res://assets/sprites/" + sprite_name + ".png"
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is Texture2D:
				_custom_tex_cache[sprite_name] = res
				return res
		if FileAccess.file_exists(p):
			var fa: FileAccess = FileAccess.open(p, FileAccess.READ)
			if fa:
				var buf: PackedByteArray = fa.get_buffer(fa.get_length())
				fa.close()
				var img: Image = Image.new()
				if img.load_png_from_buffer(buf) == OK and not img.is_empty():
					var itex: Texture2D = ImageTexture.create_from_image(img)
					_custom_tex_cache[sprite_name] = itex
					return itex
		return null
	return at.region(sprite_name)



static func box(sprite_name: String, content: int = -1, dy: int = 0) -> StyleBox:
	ensure()
	var at: SpriteAtlas = _at(sprite_name)
	if at == null:
		return sb("wb_panel_dark", content)
	var s: = StyleBoxTexture.new()
	s.texture = at.region(sprite_name)
	var info: Dictionary = at.info(sprite_name)
	if info.has("slice"):
		var sl: Array = info["slice"]
		s.texture_margin_left = float(sl[0])
		s.texture_margin_top = float(sl[1])
		s.texture_margin_right = float(sl[2])
		s.texture_margin_bottom = float(sl[3])
	var cm: float = float(content) if content >= 0 else s.texture_margin_left
	s.content_margin_left = cm
	s.content_margin_right = cm
	s.content_margin_top = cm + dy
	s.content_margin_bottom = cm - dy
	return s



const _FALLBACK: Dictionary = {
	"wb_panel": ["575b47", "23251c", 2], "wb_panel_dark": ["34362c", "1d1f17", 2], 
	"wb_slot": ["2a2b27", "8a7350", 2], "wb_slot_pressed": ["1f201c", "7a6544", 2], 
	"wb_slot_active": ["c8483a", "f0937a", 2], "wb_slot_disabled": ["3a3b36", "55524a", 2], 
	"wb_tab": ["575b47", "23251c", 2], "wb_tab_active": ["c8483a", "f0937a", 2], 
	"wb_btn_green": ["5aa83c", "1d2a12", 2], "wb_btn_red": ["c8483a", "2a120e", 2], "wb_btn_blue": ["3c7ec8", "0f1e30", 2], 
	"wb_btn_gold": ["d39a2c", "2e1e08", 2], "wb_btn_stone": ["6a6e58", "23251c", 2], 
	"wb_btn_green_p": ["4a9030", "1d2a12", 2], "wb_btn_red_p": ["a83a2e", "2a120e", 2], "wb_btn_blue_p": ["2f6aaa", "0f1e30", 2], 
	"wb_btn_gold_p": ["b8861f", "2e1e08", 2], "wb_btn_stone_p": ["575b47", "23251c", 2], 
	"wb_card": ["2f3129", "8a7350", 2], "wb_tooltip": ["1f1712", "1f1712", 0], "wb_ribbon": ["c8483a", "ffcf5a", 2], 
	"wb_window": ["4d513f", "1d1f17", 3], "wb_bar_frame": ["1c1d18", "0e0f0b", 1], "wb_pill": ["24251f", "111209", 1], 
	"wb_topbar": ["4d513f", "1d1f17", 2], "wb_bar_green": ["8fdc4f", "8fdc4f", 0], "wb_bar_red": ["e8553f", "e8553f", 0], 
	"wb_bar_amber": ["ffb13d", "ffb13d", 0], "wb_bar_blue": ["6cc0f5", "6cc0f5", 0], 
}



static func sb(sprite_name: String, pad: float = -1.0, pad_y: float = -1.0, dy: float = 0.0) -> StyleBox:
	ensure()
	var s: StyleBox
	if atlas9.has(sprite_name):
		var st: = StyleBoxTexture.new()
		st.texture = atlas9.region(sprite_name)
		var info: Dictionary = atlas9.info(sprite_name)
		if info.has("slice"):
			var sl: Array = info["slice"]
			st.texture_margin_left = float(sl[0])
			st.texture_margin_top = float(sl[1])
			st.texture_margin_right = float(sl[2])
			st.texture_margin_bottom = float(sl[3])
		if sprite_name in ["wb_panel", "wb_topbar", "wb_window"]:

			st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
			st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		s = st
	else:
		var fb: Array = _FALLBACK.get(sprite_name, ["3a3c32", "1d1f17", 2])
		var sf: = StyleBoxFlat.new()
		sf.bg_color = Color(String(fb[0]))
		if sprite_name == "wb_tooltip":
			sf.bg_color.a = 0.86
		sf.border_color = Color(String(fb[1]))
		sf.set_border_width_all(int(fb[2]))
		sf.set_corner_radius_all(3)
		sf.content_margin_left = 6
		sf.content_margin_right = 6
		sf.content_margin_top = 6
		sf.content_margin_bottom = 6
		s = sf
	if pad >= 0.0:
		s.content_margin_left = pad
		s.content_margin_right = pad
		var py: float = pad_y if pad_y >= 0.0 else pad
		s.content_margin_top = py + dy
		s.content_margin_bottom = py - dy
	elif s is StyleBoxTexture:
		var t: StyleBoxTexture = s as StyleBoxTexture
		t.content_margin_left = t.texture_margin_left
		t.content_margin_right = t.texture_margin_right
		t.content_margin_top = t.texture_margin_top + dy
		t.content_margin_bottom = t.texture_margin_bottom - dy
	return s




static func make_theme() -> Theme:
	ensure()
	var t: = Theme.new()
	t.default_font = f_bold
	t.default_font_size = 10
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", SHADOW)
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_color("font_outline_color", "Label", OUTLINE)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_color("font_outline_color", "Button", OUTLINE)
	t.set_constant("outline_size", "Button", 3)
	t.set_constant("h_separation", "Button", 6)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("normal", "Button", sb("wb_btn_stone", 10, 6, -1))
	t.set_stylebox("hover", "Button", sb("wb_btn_stone", 10, 6, -1))
	t.set_stylebox("pressed", "Button", sb("wb_btn_stone_p", 10, 6, 1))
	t.set_stylebox("hover_pressed", "Button", sb("wb_btn_stone_p", 10, 6, 1))
	t.set_stylebox("disabled", "Button", sb("wb_btn_stone_p", 10, 6, 1))
	t.set_stylebox("panel", "PanelContainer", sb("wb_window", 12))
	t.set_stylebox("slider", "HSlider", sb("wb_bar_frame", 3))
	t.set_stylebox("grabber_area", "HSlider", sb("wb_bar_amber", 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", sb("wb_bar_amber", 2))
	var knob: Texture2D = tex("slider_knob")
	if knob != null:
		t.set_icon("grabber", "HSlider", knob)
		t.set_icon("grabber_highlight", "HSlider", knob)
		t.set_icon("grabber_disabled", "HSlider", knob)
	t.set_stylebox("focus", "HSlider", StyleBoxEmpty.new())

	var ln: = StyleBoxFlat.new()
	ln.bg_color = Color(0.07, 0.065, 0.05, 0.92)
	ln.border_color = Color(0.36, 0.33, 0.25)
	ln.set_border_width_all(2)
	ln.content_margin_left = 8
	ln.content_margin_right = 8
	t.set_stylebox("normal", "LineEdit", ln)
	var lf: = StyleBoxFlat.new()
	lf.bg_color = Color(0.08, 0.07, 0.05, 0.95)
	lf.border_color = GOLD
	lf.set_border_width_all(2)
	lf.content_margin_left = 8
	lf.content_margin_right = 8
	t.set_stylebox("focus", "LineEdit", lf)
	var lr: StyleBoxFlat = ln.duplicate()
	lr.border_color = Color(DIM, 0.6)
	t.set_stylebox("read_only", "LineEdit", lr)
	t.set_color("font_uneditable_color", "LineEdit", MUTED)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", DIM)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(GOLD, 0.35))
	return t




static func lbl(text: String, size: int = 10, col: Color = TEXT, weight: int = 1, outline: int = 0) -> Label:
	ensure()
	var l: = Label.new()
	l.text = text
	l.add_theme_font_override("font", [f_reg, f_bold, f_black, f_title][clampi(weight, 0, 3)])
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", OUTLINE)
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.add_theme_color_override("font_shadow_color", SHADOW)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l



static func title(text: String, size: int = 20, col: Color = TITLE) -> Label:
	var l: Label = lbl(text, size, col, 3, maxi(4, size / 4))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l




static func name_lbl(text: String, size: int = 10, col: Color = TEXT, weight: int = 1, outline: int = 0) -> Label:
	var l: Label = lbl(Loc.name(text), size, col, weight, outline)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return l



static func no_tr(c: Node) -> Node:
	c.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return c


static func icon_rect(icon_name: String, box_px: float = 32.0) -> TextureRect:
	var r: = TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_icon(r, icon_name, box_px)
	return r



static func set_icon(r: TextureRect, icon_name: String, box_px: float) -> void :
	var t: Texture2D = tex(icon_name) if icon_name != "" else null
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var k: float = 1.0
	if t != null:
		var m: float = maxf(t.get_size().x, t.get_size().y)

		k = maxf(1.0, floorf(box_px / maxf(m, 1.0) * 4.0) / 4.0)
		r.custom_minimum_size = (t.get_size() * k).round()
		r.size = r.custom_minimum_size
	r.pivot_offset = r.size * 0.5




static func _slot_styles(b: Button, toggle: bool) -> void :
	b.add_theme_stylebox_override("normal", sb("wb_slot", 4))
	b.add_theme_stylebox_override("hover", sb("wb_slot", 4))
	var pr: StyleBox = sb("wb_slot_active", 4) if toggle else sb("wb_slot_pressed", 4)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("hover_pressed", pr)
	b.add_theme_stylebox_override("disabled", sb("wb_slot_disabled", 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())



static func slot(icon_name: String, toggle: bool = false, px: float = 46.0) -> Button:
	ensure()
	var b: = Button.new()
	b.custom_minimum_size = Vector2(px, px)
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = toggle
	_slot_styles(b, toggle)
	var ic: TextureRect = icon_rect(icon_name, px - 10.0)
	ic.name = "Icon"
	b.add_child(ic)
	var center: = func() -> void :
		ic.position = ((b.size - ic.size) * 0.5).round() + Vector2(0, 1 if b.button_pressed or b.is_pressed() else 0)
		ic.pivot_offset = ic.size * 0.5
	b.resized.connect(center)
	b.toggled.connect( func(_on: bool) -> void : center.call())
	tap_snd(b)
	b.button_down.connect( func() -> void :
		var tw: Tween = ic.create_tween()
		tw.tween_property(ic, "scale", Vector2(0.82, 0.82), 0.05))
	b.button_up.connect( func() -> void :
		var tw: Tween = ic.create_tween()
		tw.tween_property(ic, "scale", Vector2(1.18, 1.18), 0.07).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(ic, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		center.call())
	return b


static func slot_icon(b: Button) -> TextureRect:
	return b.get_node_or_null("Icon") as TextureRect


static func set_slot_icon(b: Button, icon_name: String) -> void :
	var ic: TextureRect = slot_icon(b)
	if ic != null:
		set_icon(ic, icon_name, b.custom_minimum_size.x - 10.0)
		ic.position = ((b.size - ic.size) * 0.5).round()



static func big(text: String, colour: String = "stone", icon_name: String = "", h: float = 40.0, size: int = 13) -> Button:
	ensure()
	var b: = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_override("font", f_black)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_color_override("font_outline_color", OUTLINE)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_hover_pressed_color", TEXT)
	b.add_theme_stylebox_override("normal", sb("wb_btn_" + colour, 12, 4, -1))
	b.add_theme_stylebox_override("hover", sb("wb_btn_" + colour, 12, 4, -1))
	b.add_theme_stylebox_override("pressed", sb("wb_btn_" + colour + "_p", 12, 4, 1))
	b.add_theme_stylebox_override("hover_pressed", sb("wb_btn_" + colour + "_p", 12, 4, 1))
	b.add_theme_stylebox_override("disabled", sb("wb_btn_stone_p", 12, 4, 1))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if icon_name != "":
		var t: Texture2D = tex(icon_name)
		if t != null:
			b.icon = t
			b.expand_icon = false
	press_fx(b)
	return b





static var tap_snd_n: int = 0
static func tap_snd(bb: BaseButton) -> void :
	bb.pressed.connect( func() -> void :
		tap_snd_n += 1
		snd("ui_click"))




static func snd_if_held(bb: BaseButton, delay: float = 0.12) -> void :
	if not bb.is_inside_tree():
		return
	bb.get_tree().create_timer(delay).timeout.connect( func() -> void :
		if is_instance_valid(bb) and bb.is_pressed() and not bb.disabled:
			snd("ui_click"))







const SEL_DARK: = Color("0b1430")
static func draw_sel_frame(ci: CanvasItem, r: Rect2, core: Color, line: bool = true) -> void :
	var step: int = int(Time.get_ticks_msec() / 125) % 8
	var o: float = [0.0, 1.0, 2.0, 2.0, 2.0, 1.0, 0.0, 0.0][step]
	var hot: Color = core.lerp(Color.WHITE, [0.0, 0.25, 0.55, 0.7, 0.55, 0.25, 0.0, 0.0][step])
	var x0: float = floorf(r.position.x) - 4.0 - o
	var y0: float = floorf(r.position.y) - 4.0 - o
	var x1: float = ceilf(r.end.x) + 4.0 + o
	var y1: float = ceilf(r.end.y) + 4.0 + o
	var T: float = 3.0
	var L: float = floorf(clampf(minf(x1 - x0, y1 - y0) * 0.3, 8.0, 18.0))
	if line:
		var lc: = Color(hot, 0.55)
		ci.draw_rect(Rect2(x0 + L, y0 + 1.0, x1 - x0 - 2.0 * L, 1.0), lc)
		ci.draw_rect(Rect2(x0 + L, y1 - 2.0, x1 - x0 - 2.0 * L, 1.0), lc)
		ci.draw_rect(Rect2(x0 + 1.0, y0 + L, 1.0, y1 - y0 - 2.0 * L), lc)
		ci.draw_rect(Rect2(x1 - 2.0, y0 + L, 1.0, y1 - y0 - 2.0 * L), lc)
	for pass_i in 2:
		var g: float = 1.0 if pass_i == 0 else 0.0
		var col: Color = SEL_DARK if pass_i == 0 else hot
		var xa: float = x0 - g
		var ya: float = y0 - g
		var xb: float = x1 + g
		var yb: float = y1 + g
		var t2: float = T + 2.0 * g
		var l2: float = L + 2.0 * g
		ci.draw_rect(Rect2(xa, ya, l2, t2), col)
		ci.draw_rect(Rect2(xa, ya, t2, l2), col)
		ci.draw_rect(Rect2(xb - l2, ya, l2, t2), col)
		ci.draw_rect(Rect2(xb - t2, ya, t2, l2), col)
		ci.draw_rect(Rect2(xa, yb - t2, l2, t2), col)
		ci.draw_rect(Rect2(xa, yb - l2, t2, l2), col)
		ci.draw_rect(Rect2(xb - l2, yb - t2, l2, t2), col)
		ci.draw_rect(Rect2(xb - t2, yb - l2, t2, l2), col)



static func press_fx(b: Control) -> void :
	if not (b is BaseButton):
		return
	var bb: BaseButton = b as BaseButton
	tap_snd(bb)
	bb.button_down.connect( func() -> void :
		b.pivot_offset = b.size * 0.5
		var tw: Tween = b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.94, 0.94), 0.05))
	bb.button_up.connect( func() -> void :
		var tw: Tween = b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))



const TOUCH_MIN: float = 44.0
static func arrow(left: bool) -> Button:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(TOUCH_MIN, TOUCH_MIN)
	_slot_styles(b, false)
	var nm: String = "wb_arrow_l" if left else "wb_arrow_r"
	var t: Texture2D = tex(nm)
	if t != null:
		var ic: TextureRect = icon_rect(nm, 20.0)
		b.add_child(ic)
		b.resized.connect( func() -> void : ic.position = ((b.size - ic.size) * 0.5).round())
	else:
		b.text = "<" if left else ">"
	press_fx(b)
	return b


static func close_btn(px: float = 38.0) -> Button:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	_slot_styles(b, false)
	var t: Texture2D = tex("wb_close")
	if t == null:
		t = tex("icon_close")
	var ic: = TextureRect.new()
	ic.texture = t
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if t != null:
		var k: float = maxf(1.0, floorf((px - 12.0) / maxf(t.get_size().x, 1.0)))
		ic.size = t.get_size() * k
	b.add_child(ic)
	b.resized.connect( func() -> void : ic.position = ((b.size - ic.size) * 0.5).round())
	press_fx(b)
	if px < TOUCH_MIN:
		_touch_pad(b)
	return b




static func _touch_pad(b: Button) -> void :
	var hit: = Button.new()
	hit.name = "TouchPad"
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		hit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	hit.custom_minimum_size = Vector2(TOUCH_MIN, TOUCH_MIN)
	hit.size = hit.custom_minimum_size
	b.add_child(hit)
	b.resized.connect( func() -> void : hit.position = ((b.size - hit.size) * 0.5).round())
	hit.button_down.connect( func() -> void :
		if not b.disabled:
			b.button_down.emit())
	hit.button_up.connect( func() -> void :
		if not b.disabled:
			b.button_up.emit())
	hit.pressed.connect( func() -> void :
		if not b.disabled:
			b.pressed.emit())





static func key(icon_name: String, toggle: bool = false) -> Button:
	return slot(icon_name, toggle, 44.0)


static func tab(icon_name: String) -> Button:
	ensure()
	var b: = Button.new()
	b.custom_minimum_size = Vector2(48, 42)
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.add_theme_stylebox_override("normal", sb("wb_tab", 4, 3))
	b.add_theme_stylebox_override("hover", sb("wb_tab", 4, 3))
	b.add_theme_stylebox_override("pressed", sb("wb_tab_active", 4, 3))
	b.add_theme_stylebox_override("hover_pressed", sb("wb_tab_active", 4, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic: TextureRect = icon_rect(icon_name, 22.0)
	ic.name = "Icon"
	b.add_child(ic)
	b.resized.connect( func() -> void : ic.position = ((b.size - ic.size) * 0.5 + Vector2(0, 1)).round())
	return b



static func pop_in(c: Control, from_scale: float = 0.85, dur: float = 0.22) -> void :
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(from_scale, from_scale)
	c.modulate.a = 0.0
	var tw: Tween = c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.6)


static func slide_in(c: Control, offset: Vector2, dur: float = 0.25) -> void :
	var to: Vector2 = c.position
	c.position = to + offset
	c.modulate.a = 0.0
	var tw: Tween = c.create_tween().set_parallel(true)
	tw.tween_property(c, "position", to, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.7)






static func fit_lbl(l: Label, sizes: Array, wrap: bool = true, cond: bool = false) -> void :
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var f0: Font = l.get_theme_font("font")
	var fc: = FontVariation.new()
	fc.base_font = f0
	if f0 is FontVariation and (f0 as FontVariation).base_font != null:


		var fv0: FontVariation = f0
		fc.base_font = fv0.base_font
		fc.variation_opentype = fv0.variation_opentype
		fc.spacing_space = fv0.spacing_space
	fc.spacing_glyph = -1
	var apply: = func() -> void :
		var w: float = l.size.x
		if w <= 2.0:
			return
		var shown: String = l.atr(l.text) if l.can_auto_translate() else l.text
		var ol: float = float(l.get_theme_constant("outline_size"))
		var pick: int = int(sizes[sizes.size() - 1])
		var font: Font = f0
		var one: bool = false
		for f: Font in ([f0, fc] if cond else [f0]):
			for s: Variant in sizes:
				if f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, int(s)).x + ol <= w:
					pick = int(s)
					font = f
					one = true
					break
			if one:
				break
		var changed: bool = false
		if l.get_theme_font("font") != font:
			l.add_theme_font_override("font", font)
			changed = true
		if l.get_theme_font_size("font_size") != pick:
			l.add_theme_font_size_override("font_size", pick)
			changed = true
		var am: int = TextServer.AUTOWRAP_OFF if one or not wrap else TextServer.AUTOWRAP_WORD_SMART
		if l.autowrap_mode != am:
			l.autowrap_mode = am

			l.clip_text = am == TextServer.AUTOWRAP_OFF
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if am == TextServer.AUTOWRAP_OFF else TextServer.OVERRUN_NO_TRIMMING
			changed = true
		var par: Node = l.get_parent()
		if changed and par is Container:
			par.call_deferred("queue_sort")
	l.resized.connect(apply)
	l.set_meta("fit", apply)



static func refit(l: Label) -> void :
	if l != null and is_instance_valid(l) and l.has_meta("fit"):
		(l.get_meta("fit") as Callable).call()
