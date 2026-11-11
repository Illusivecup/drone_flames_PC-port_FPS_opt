extends RefCounted





const FALLBACK: Dictionary = {
	"icon_dip_pending": "icon_ultimatum", "icon_rel_war": "icon_war_declare", "icon_rel_war_24": "icon_war_declare", 
	"icon_rel_peace": "icon_peace", "icon_rel_truce": "icon_truce", "icon_strength": "icon_score", "icon_goto_map": "icon_center", 
	"icon_map_ores": "icon_mine", "icon_build_assault": "icon_barracks", "icon_inventory": "icon_store", "icon_stats": "icon_score", 
	"icon_hint": "icon_tutorial", "icon_scarce": "icon_info", "icon_r_titanium": "res_titanium", "icon_r_metal": "res_metal", 
	"icon_r_wood": "res_wood", "icon_r_oil": "res_oil", "icon_r_precious": "res_precious", "icon_timer_ring_0": "", 
	"icon_r_uranium": "res_uranium", "icon_npp": "icon_power", "icon_umine": "icon_mine", 
}


static func tex(icon_name: String, fallback: String = "") -> Texture2D:
	var t: Texture2D = UiKit.tex(icon_name)
	if t != null:
		return t
	var fb: String = fallback if fallback != "" else String(FALLBACK.get(icon_name, ""))
	return UiKit.tex(fb) if fb != "" else null



static func icon(icon_name: String, box_px: float, fallback: String = "") -> TextureRect:
	var r: = TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_icon(r, icon_name, box_px, fallback)
	return r


static func set_icon(r: TextureRect, icon_name: String, box_px: float, fallback: String = "") -> void :
	var t: Texture2D = tex(icon_name, fallback)
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var k: float = 1.0
	if t != null:
		var m: float = maxf(t.get_size().x, t.get_size().y)
		k = maxf(1.0, floorf(box_px / maxf(m, 1.0) * 4.0) / 4.0)
		if k > 2.0:
			k = floorf(k)
		r.custom_minimum_size = (t.get_size() * k).round()
	else:
		r.custom_minimum_size = Vector2(box_px, box_px)
	r.size = r.custom_minimum_size
	r.pivot_offset = r.size * 0.5



static func num(v: int) -> String:
	var s: String = str(absi(v))
	var out: String = ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("−" if v < 0 else "") + s + out


static func signed(v: int) -> String:
	return ("+" if v > 0 else "") + num(v)



static func mmss(sec: float) -> String:
	var s: int = maxi(0, int(sec))
	return "%d:%02d" % [s / 60, s % 60]



static func badge_label(n: int) -> Label:
	var l: Label = UiKit.lbl(str(n), 9, UiKit.TEXT, 2, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st: = StyleBoxFlat.new()
	st.bg_color = Color("d8382a")
	st.border_color = UiKit.OUTLINE
	st.set_border_width_all(1)
	st.set_corner_radius_all(7)
	l.add_theme_stylebox_override("normal", st)
	l.custom_minimum_size = Vector2(14, 14)
	l.size = Vector2(14, 14)
	return l



static func set_lbl(l: Label, text: String, col: Color) -> void :
	if l == null or not is_instance_valid(l):
		return
	if l.text != text:
		l.text = text
		if l.has_meta("fit"):
			UiKit.refit(l)
	if not l.has_theme_color_override("font_color") or l.get_theme_color("font_color") != col:
		l.add_theme_color_override("font_color", col)


static func set_vis(c: CanvasItem, on: bool) -> void :
	if c != null and is_instance_valid(c) and c.visible != on:
		c.visible = on
