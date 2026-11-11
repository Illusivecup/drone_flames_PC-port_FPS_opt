extends RefCounted






const GROUP_COLORS: Array[Color] = [Color("c0392b"), Color("7aad34"), Color("ffb000"), Color("7cc0f0"), 
	Color("a77bf0"), Color("e86aa8"), Color("f4f6f8"), Color("3cc8b0")]
const GROUP_COLOR_NAMES: Array[String] = ["Красный", "Зелёный", "Янтарь", "Небо", "Сирень", "Малина", "Снег", "Бирюза"]
const EMBLEMS: Array[String] = ["emb_star", "emb_shield", "emb_arrow", "emb_bird", "emb_wolf", "emb_tower", "emb_bolt", "emb_spade"]
const AMBER: = Color("ffb000")
const DARK: = Color("1b120c")


const FALLBACK: Dictionary = {
	"icon_act_fight_0": "icon_war", "icon_act_fight_1": "icon_war", 
	"icon_act_move_0": "icon_speed_fast", "icon_act_move_1": "icon_speed_fast", 
	"icon_act_idle": "icon_dugout", "icon_act_refill": "icon_restore", "icon_act_sea": "icon_ship", 
	"icon_act_dug": "icon_trench", 
	"icon_stance_manual": "icon_op_operation", "icon_stance_defend": "icon_defend", "icon_stance_attack": "icon_op_attack", 
	"icon_group_add": "icon_plus", "icon_multi_select": "icon_ok", "icon_rename": "icon_settings2", 
	"icon_strength": "icon_relations", "icon_goto_map": "icon_center", "icon_rel_war": "icon_war", "icon_rel_peace": "icon_peace", 
}

static var _a19: SpriteAtlas
static var _tried: bool = false


static func atlas19() -> SpriteAtlas:
	if not _tried:
		_tried = true
		_a19 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_ui19.png", "res://assets/sprites/atlas_ui19.json", true)
	return _a19


static func has19(n: String) -> bool:
	return atlas19().has(n)



static func native(n: String) -> bool:
	return has19(n) or UiKit.has(n)


static func tex(n: String) -> Texture2D:
	if n == "":
		return null
	if UiKit.has(n):
		return UiKit.tex(n)
	if has19(n):
		return atlas19().region(n)
	if FALLBACK.has(n):
		return UiKit.tex(String(FALLBACK[n]))
	return null



static func icon(n: String, box: float) -> TextureRect:
	var r: = TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(box, box)
	r.size = r.custom_minimum_size
	r.pivot_offset = r.size * 0.5
	r.texture = tex(n)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


static func color(i: int) -> Color:
	return GROUP_COLORS[clampi(i, 0, GROUP_COLORS.size() - 1)]




static func _star() -> PackedVector2Array:
	var p: = PackedVector2Array()
	for i in 10:
		var r: float = 7.5 if i % 2 == 0 else 3.2
		var a: float = - PI * 0.5 + float(i) * PI / 5.0
		p.append(Vector2(8, 8.6) + Vector2(cos(a), sin(a)) * r)
	return p


static func emblem_poly(emb: String) -> PackedVector2Array:
	match emb:
		"emb_star":
			return _star()
		"emb_shield":
			return PackedVector2Array([Vector2(2, 2), Vector2(14, 2), Vector2(14, 8), Vector2(8, 15), Vector2(2, 8)])
		"emb_arrow":
			return PackedVector2Array([Vector2(8, 1), Vector2(15, 8), Vector2(10.5, 8), Vector2(10.5, 15), Vector2(5.5, 15), Vector2(5.5, 8), Vector2(1, 8)])
		"emb_bird":
			return PackedVector2Array([Vector2(0, 4), Vector2(8, 9), Vector2(16, 4), Vector2(16, 8), Vector2(8, 14), Vector2(0, 8)])
		"emb_wolf":
			return PackedVector2Array([Vector2(2, 1), Vector2(6, 5), Vector2(10, 5), Vector2(14, 1), Vector2(15, 9), Vector2(8, 15), Vector2(1, 9)])
		"emb_tower":
			return PackedVector2Array([Vector2(2, 1), Vector2(5, 1), Vector2(5, 4), Vector2(7, 4), Vector2(7, 1), Vector2(9, 1), Vector2(9, 4), Vector2(11, 4), 
				Vector2(11, 1), Vector2(14, 1), Vector2(14, 6), Vector2(12.5, 6), Vector2(12.5, 15), Vector2(3.5, 15), Vector2(3.5, 6), Vector2(2, 6)])
		"emb_bolt":
			return PackedVector2Array([Vector2(10, 0), Vector2(2.5, 9), Vector2(7.5, 9), Vector2(5.5, 16), Vector2(14, 6), Vector2(9, 6), Vector2(12.5, 0)])
		"emb_spade":
			return PackedVector2Array([Vector2(8, 0.5), Vector2(15, 8), Vector2(12, 11.5), Vector2(9.2, 10), Vector2(10.5, 15.5), Vector2(5.5, 15.5), Vector2(6.8, 10), Vector2(4, 11.5), Vector2(1, 8)])
	return _star()


static func _xf(poly: PackedVector2Array, at: Vector2, k: float) -> PackedVector2Array:
	var o: = PackedVector2Array()
	for v: Vector2 in poly:
		o.append(at + v * k)
	return o



static func draw_emblem(ci: CanvasItem, emb: String, at: Vector2, k: float, col: Color) -> void :
	if k >= 0.99 and has19(emb):
		var nm: String = emb + "_32" if k >= 1.5 and has19(emb + "_32") else emb
		ci.draw_texture_rect(atlas19().region(nm), Rect2(at, Vector2(16, 16) * k), false, col)
		return
	var poly: PackedVector2Array = emblem_poly(emb)
	var o: float = maxf(1.0, k * 0.9)
	for d: Vector2 in [Vector2( - o, 0), Vector2(o, 0), Vector2(0, - o), Vector2(0, o), Vector2(o, o)]:
		ci.draw_colored_polygon(_xf(poly, at + d, k), DARK)
	ci.draw_colored_polygon(_xf(poly, at, k), col)

	var parts: Array = Geometry2D.intersect_polygons(poly, PackedVector2Array([Vector2(-1, 10), Vector2(17, 7), Vector2(17, 17), Vector2(-1, 17)]))
	var cut: PackedVector2Array = parts[0] if not parts.is_empty() else PackedVector2Array()
	if cut.size() >= 3:
		ci.draw_colored_polygon(_xf(cut, at, k), col.darkened(0.28))



static func draw_pennant(ci: CanvasItem, at: Vector2, k: float, col: Color, emb: String, label: String = "", fs: int = 11, hot: bool = false) -> void :
	var top: Vector2 = at - Vector2(0, 16) * k
	ci.draw_rect(Rect2(top + Vector2(-1, -1) * k, Vector2(2.2, 17.5) * k), DARK)
	ci.draw_rect(Rect2(top + Vector2(-0.4, 0) * k, Vector2(1.0, 16) * k), Color("d8c9a3"))
	var flag: = PackedVector2Array([Vector2(0.6, 0), Vector2(12, 0), Vector2(9, 4.75), Vector2(12, 9.5), Vector2(0.6, 9.5)])
	var outl: = PackedVector2Array([Vector2(-0.4, -1), Vector2(13.8, -1), Vector2(10.4, 4.75), Vector2(13.8, 10.5), Vector2(-0.4, 10.5)])
	ci.draw_colored_polygon(_xf(outl, top, k), DARK)
	ci.draw_colored_polygon(_xf(flag, top, k), col)
	ci.draw_colored_polygon(_xf(PackedVector2Array([Vector2(0.6, 6.5), Vector2(10.7, 6.5), Vector2(12, 9.5), Vector2(0.6, 9.5)]), top, k), col.darkened(0.25))
	ci.draw_rect(Rect2(top + Vector2(0.6, 0) * k, Vector2(11, 1) * k), col.lightened(0.3))
	var ek: float = k * 0.42
	var ec: Color = Color.WHITE if col.get_luminance() < 0.75 else DARK
	draw_emblem(ci, emb, top + Vector2(1.6, 1.2) * k, ek, ec)
	if label != "":
		var f: Font = UiKit.f_black
		var sz: Vector2 = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var p: Vector2 = top + Vector2(14.5 * k, 8.5 * k)
		var bg: = Rect2(p + Vector2(-2, - sz.y + 3), Vector2(sz.x + 4, sz.y))
		ci.draw_rect(bg, Color(0.45, 0.1, 0.06, 0.85) if hot else Color(0.08, 0.06, 0.04, 0.78))
		ci.draw_rect(Rect2(bg.position, Vector2(2, bg.size.y)), col)
		ci.draw_string_outline(f, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, DARK)
		ci.draw_string(f, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)



static func draw_tri(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void :
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2( - s - 1, - s * 0.5 - 1), c + Vector2(s + 1, - s * 0.5 - 1), c + Vector2(0, s * 0.6 + 1)]), DARK)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2( - s, - s * 0.5), c + Vector2(s, - s * 0.5), c + Vector2(0, s * 0.6)]), col)



static func emblem_rect(emb: String, col: Color, px: float, disc: bool = false) -> Control:
	var c: = Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.set_meta("emb", emb)
	c.set_meta("col", col)
	c.draw.connect( func() -> void :
		var e: String = String(c.get_meta("emb"))
		var cc: Color = c.get_meta("col")
		var k: float = c.size.x / 16.0
		if disc:
			c.draw_circle(c.size * 0.5, c.size.x * 0.5 + 1.0, DARK)
			c.draw_circle(c.size * 0.5, c.size.x * 0.5, cc.darkened(0.55))
			var ke: float = 1.0 if c.size.x >= 22.0 and has19(e) else k * 0.64
			draw_emblem(c, e, ((c.size - Vector2(16, 16) * ke) * 0.5).round(), ke, cc.lightened(0.15))
		else:
			draw_emblem(c, e, Vector2.ZERO, k, cc))
	return c


static func set_emblem(c: Control, emb: String, col: Color) -> void :
	c.set_meta("emb", emb)
	c.set_meta("col", col)
	c.queue_redraw()


static func set_tex_rect(r: TextureRect, n: String) -> void :
	r.texture = tex(n)
