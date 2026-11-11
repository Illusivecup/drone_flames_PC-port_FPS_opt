class_name MapModeLayer
extends Node2D












const ORE_COLORS: Dictionary = {"titanium": Color("5fd8ff"), "metal": Color("ff8a4a"), "oil": Color("c08cff"), "precious": Color("ffd23a"), "uranium": Color("8cf03c")}
const DIST_MIN_DT: float = 0.25
const LOGI_DT: float = 1.5
const SM334 = preload("res://world/strat_modes.gd")
const RV332 = preload("res://world/rail_view332.gd")
const AD_COLORS: Dictionary = {
	Facility.Kind.AD_MFG: Color("9ff2f0"), Facility.Kind.AD_SPAAG: Color("7cc0f0"), Facility.Kind.AD_SAM: Color("ffb000"), 
	Facility.Kind.AD_PATRIOT: Color("ff7a1f"), Facility.Kind.AD_INT: Color("e8e0ff"), Facility.Kind.AD_RADAR: Color("9bc53d"), 
	Facility.Kind.AD_EW: Color("c08cff"), 
}

var gw: GameWorld
var overlay: Sprite2D
var icons: MapIcons
var _vps: Array[SubViewport] = []
var _mats: Array[ShaderMaterial] = []
var _tex: Texture2D = null
var _dirty: bool = true
var _stage: int = -1
var _since: float = 0.0
var _has_dist: bool = false
var _full: bool = true
var _drect: Rect2i = Rect2i()
var _fly: Rect2i = Rect2i()
var _stale: Vector4 = Vector4(-1, -1, -1, -1)
const DIST_PAD: int = 10
var _px: float = -1.0
var _mode: int = -1
var _pid: int = -1
var _ncol: int = -1
var _war_key: String = "?"
var _war_t: float = 0.0
var _flags_img: Image
var _flags_tex: ImageTexture
var _rail_img: Image
var _rail_tex: ImageTexture
var _logi_t: float = 99.0
var _draw_t: float = 0.0
var _draw_z: float = -1.0


var focus_id: int = -1

var _legend: CanvasLayer = null
var _legend_box: PanelContainer = null
const LEGEND_ROWS: Array = [["titanium", "metal", "oil"], ["precious", "uranium"]]


static func make(world: GameWorld) -> MapModeLayer:
	var l: = MapModeLayer.new()
	l.name = "MapModes"
	l.gw = world
	return l


func _ready() -> void :
	overlay = Sprite2D.new()
	overlay.name = "MapModeOverlay"
	overlay.centered = false
	overlay.scale = Vector2(4, 4)
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var om: = ShaderMaterial.new()
	om.shader = load("res://world/map_mode.gdshader") as Shader
	overlay.material = om
	overlay.visible = false
	gw.add_child(overlay)
	gw.move_child(overlay, gw.territory_border.get_index())
	var eco: Node = gw.get_node_or_null("Eco")
	if eco != null:
		gw.move_child(self, eco.get_index() + 1)
	icons = MapIcons.new()
	icons.name = "MapIcons"
	icons.gw = gw
	gw.add_child(icons)
	if gw.top != null:
		gw.move_child(icons, gw.top.get_index())
	var sh: Shader = load("res://world/territory_dist.gdshader") as Shader
	for i in 3:
		var vp: = SubViewport.new()
		vp.name = "BorderDist%d" % i
		vp.disable_3d = true
		vp.transparent_bg = false
		vp.size = Vector2i(2, 2)
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		var r: = ColorRect.new()
		r.color = Color.WHITE
		r.position = Vector2.ZERO
		r.size = Vector2(2, 2)
		var m: = ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("pass", i)
		r.material = m
		vp.add_child(r)
		add_child(vp)
		_vps.append(vp)
		_mats.append(m)
	var adc: Node2D = (load("res://world/ad_cover_layer.gd") as GDScript).new()
	adc.name = "AdCover"
	adc.set("gw", gw)
	add_child(adc)
	if gw.has_signal("relations_changed"):
		gw.relations_changed.connect( func() -> void : _war_key = "?")



func territory_changed(rect: Rect2i = Rect2i()) -> void :
	_dirty = true
	if rect.has_area():
		_drect = _drect.merge(rect) if _drect.has_area() else rect
	else:
		_full = true
	_stale_upd()
	if gw != null and gw.labels != null:
		gw.labels.territory_changed()





func _stale_upd() -> void :
	if gw == null or gw.data == null or gw.territory == null or gw.territory_border == null:
		return
	var whole: = Rect2i(Vector2i.ZERO, Vector2i(gw.data.w, gw.data.h))
	var r: Rect2i = _fly
	if _full:
		r = whole
	elif _drect.has_area():
		var g: Rect2i = _drect.grow(DIST_PAD).intersection(whole)
		r = r.merge(g) if r.has_area() else g
	var v: = Vector4(r.position.x, r.position.y, r.end.x, r.end.y) if r.has_area() else Vector4.ZERO
	if v != _stale:
		_stale = v
		for spr: Sprite2D in [gw.territory, gw.territory_border]:
			(spr.material as ShaderMaterial).set_shader_parameter("stale_box", v)


func _setup(tex: Texture2D) -> void :
	_tex = tex
	_has_dist = false
	_stage = -1
	_dirty = true
	var sz: = Vector2i(gw.data.w, gw.data.h)
	var ws: = Vector2(sz)
	for i in 3:
		_vps[i].size = sz
		(_vps[i].get_child(0) as ColorRect).size = ws
		_mats[i].set_shader_parameter("world_size", ws)
	_mats[0].set_shader_parameter("src", tex)
	_mats[1].set_shader_parameter("src", _vps[0].get_texture())
	_mats[2].set_shader_parameter("src", _vps[1].get_texture())
	var om: ShaderMaterial = overlay.material
	overlay.texture = tex
	om.set_shader_parameter("owner_tex", tex)
	om.set_shader_parameter("world_size", ws)
	for spr: Sprite2D in [gw.territory, gw.territory_border]:
		var m2: ShaderMaterial = spr.material
		m2.set_shader_parameter("dist_tex", _vps[2].get_texture())
		m2.set_shader_parameter("has_dist", false)
	_flags_img = null
	_rail_img = null
	_ncol = -1
	_war_key = "?"


func _mats_all() -> Array:
	return [gw.territory.material, gw.territory_border.material, overlay.material]


func _set_all(param: String, v: Variant) -> void :
	for m: ShaderMaterial in _mats_all():
		m.set_shader_parameter(param, v)


func _process(delta: float) -> void :
	if gw == null or gw.data == null or gw.territory_tex == null:
		return
	if gw.territory_tex != _tex:
		_setup(gw.territory_tex)

	_since += delta
	if _stage >= 0:
		_stage += 1
		if _stage <= 2:
			_vps[_stage].render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			_stage = -1
			_fly = Rect2i()
			_stale_upd()
			if not _has_dist:
				_has_dist = true
				for spr: Sprite2D in [gw.territory, gw.territory_border]:
					(spr.material as ShaderMaterial).set_shader_parameter("has_dist", true)
	elif _dirty and _since >= DIST_MIN_DT:
		_dirty = false
		_since = 0.0
		_stage = 0
		_begin_chain()
		_vps[0].render_target_update_mode = SubViewport.UPDATE_ONCE

	var cam: MapCamera = gw.camera
	var z: float = cam.zoom.x if cam != null else 1.0
	var px: float = 1.0 / maxf(z, 0.01)
	if not is_equal_approx(px, _px):
		_px = px
		_set_all("px_world", px)
	var mode: int = GameWorld.MapMode.MY_LAND if focus_id >= 0 else int(gw.map_mode)
	if mode != _mode:
		_mode = mode
		_set_all("map_mode", mode)
		overlay.visible = mode != GameWorld.MapMode.NORMAL
		_logi_t = 99.0
		_draw_t = 99.0
		icons.force()
	var pid: int = focus_id if focus_id >= 0 else (gw.player.id if gw.player != null else 0)
	if pid != _pid:
		_pid = pid
		_set_all("player_id", pid)
	if gw.countries.size() != _ncol:
		_ncol = gw.countries.size()
		var cols: = PackedColorArray()
		cols.resize(9)
		for c: Country in gw.countries:
			if c.id < 9:
				cols[c.id] = c.color
		(overlay.material as ShaderMaterial).set_shader_parameter("colors", cols)
		_war_key = "?"
	_war_t += delta
	if _war_t >= 1.0 or _war_key == "?":
		_war_t = 0.0
		_sync_war()
		_sync_ally()
	_legend_update(mode)
	if mode == GameWorld.MapMode.LOGISTICS:
		_logi_t += delta
		if _logi_t >= LOGI_DT:
			_logi_t = 0.0
			_upload_logistics()

	_draw_t += delta
	var period: float = 1.0 / 15.0 if mode == GameWorld.MapMode.LOGISTICS else 0.5
	if mode != GameWorld.MapMode.NORMAL and mode != GameWorld.MapMode.MY_LAND and mode != GameWorld.MapMode.ORES:
		if _draw_t >= period or not is_equal_approx(z, _draw_z):
			_draw_t = 0.0
			_draw_z = z
			queue_redraw()
	elif _draw_z >= 0.0:
		_draw_z = -1.0
		queue_redraw()





func _legend_update(mode: int) -> void :
	var on: bool = mode == GameWorld.MapMode.ORES and focus_id < 0
	if not on:
		if _legend_box != null:
			_legend_box.visible = false
		return
	if _legend_box == null:
		_build_legend()
	_legend_box.visible = true
	_legend_box.position = SM334.legend_pos(_legend_box, gw)


func _build_legend() -> void :
	UiKit.ensure()
	_legend = CanvasLayer.new()
	_legend.name = "OreLegend"
	add_child(_legend)
	var pc: = PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0.043, 0.078, 0.188, 0.84)
	sb.border_color = Color(0.96, 0.93, 0.82, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 5
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	pc.add_theme_stylebox_override("panel", sb)
	var vb: = VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	pc.add_child(vb)
	for row: Array in LEGEND_ROWS:
		var hb: = HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_theme_constant_override("separation", 3)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		for res: String in row:
			hb.add_child(_swatch(res, 0))
			var l: Label = UiKit.lbl(String(Economy.RES_SHORT.get(res, res)), 9, UiKit.TEXT, 1, 2)
			l.custom_minimum_size = Vector2(0, 18)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hb.add_child(l)
			var gap: = Control.new()
			gap.custom_minimum_size = Vector2(4, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(gap)
		vb.add_child(hb)
	var hb2: = HBoxContainer.new()
	hb2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb2.add_theme_constant_override("separation", 3)
	hb2.alignment = BoxContainer.ALIGNMENT_CENTER
	for it: Array in [[1, "свободна"], [2, "добывается"]]:
		hb2.add_child(_swatch("", int(it[0])))
		var l2: Label = UiKit.lbl(String(it[1]), 8, UiKit.MUTED, 1, 2)
		l2.custom_minimum_size = Vector2(0, 14)
		l2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb2.add_child(l2)
	vb.add_child(hb2)
	_legend.add_child(pc)
	_legend_box = pc




func _swatch(res: String, kind: int) -> Control:
	var c: = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(16, 18) if kind == 0 else Vector2(12, 14)
	var w: GameWorld = gw
	c.draw.connect( func() -> void :
		var col: Color = ORE_COLORS.get(res, Color("c8c4b8"))
		var tx: Texture2D = EcoLayer.halo_tex(res if res != "" else "_", kind == 2, 8.68 if kind == 0 else 5.0)
		var ctr: Vector2 = c.size * 0.5
		c.draw_texture(tx, (ctr - tx.get_size() * 0.5).round())
		if kind != 0 or w == null:
			return
		var nm: String = "dep_mark_" + res
		var at: SpriteAtlas = w.atlas9 if w.atlas9 != null and w.atlas9.has(nm) else w.atlas_uran30
		if at != null and at.has(nm):
			var r: Rect2 = at.rect(nm, 0)
			c.draw_texture_rect_region(at.texture, Rect2((ctr - Vector2(5.5, 7.5)).round(), r.size), r)
		)
	return c



var _ally_key: String = "?"


func _sync_ally() -> void :
	var al = gw.diplo.ally if gw.diplo != null else null
	var cols: = PackedColorArray()
	cols.resize(9)
	cols.fill(Color(0, 0, 0, 0))
	if al != null:
		for c: Country in gw.countries:
			if c.id < 9 and not c.eliminated:
				var a: Dictionary = al.of_country(c.id)
				if not a.is_empty():
					cols[c.id] = al.color(a)
	var key: String = str(cols)
	if key == _ally_key:
		return
	_ally_key = key
	for mt: ShaderMaterial in _mats_all():
		mt.set_shader_parameter("ally_cols", cols)


func _sync_war() -> void :
	var bits: = PackedInt32Array()
	bits.resize(9)
	for c: Country in gw.countries:
		if c.id >= 9:
			continue
		var b: int = 0
		for k: Variant in c.at_war:
			var o: int = int(k)
			if o > 0 and o < 9 and bool(c.at_war[k]):
				b |= 1 << o
		bits[c.id] = b
	var key: String = str(bits)
	if key == _war_key:
		return
	_war_key = key
	for spr: Sprite2D in [gw.territory, gw.territory_border]:
		(spr.material as ShaderMaterial).set_shader_parameter("war_bits", bits)
	_mats[0].set_shader_parameter("war_bits", bits)
	_dirty = true
	_full = true





func _begin_chain() -> void :
	var whole: = Rect2i(Vector2i.ZERO, Vector2i(gw.data.w, gw.data.h))
	var r: Rect2i = whole
	if not _full and _has_dist and _drect.has_area():
		r = _drect.grow(DIST_PAD).intersection(whole)
	_full = false
	_drect = Rect2i()
	_fly = r
	_stale_upd()
	dist_px += r.get_area()
	for i in 3:
		var cr: = _vps[i].get_child(0) as ColorRect
		cr.position = Vector2(r.position)
		cr.size = Vector2(r.size)
		_mats[i].set_shader_parameter("rect_origin", Vector2(r.position))
		_mats[i].set_shader_parameter("rect_size", Vector2(r.size))


var dist_px: int = 0


func _upload_logistics() -> void :
	var d: WorldData = gw.data
	var n: int = d.w * d.h
	var om: ShaderMaterial = overlay.material
	if d.flags.size() != n:
		return
	if _flags_img == null:
		_flags_img = Image.create_from_data(d.w, d.h, false, Image.FORMAT_L8, d.flags)
		_flags_tex = ImageTexture.create_from_image(_flags_img)
		om.set_shader_parameter("flags_tex", _flags_tex)
	else:
		_flags_img.set_data(d.w, d.h, false, Image.FORMAT_L8, d.flags)
		_flags_tex.update(_flags_img)
	var mask: PackedByteArray = gw.rail.mask if gw.rail != null else PackedByteArray()
	if mask.size() != n:
		mask = PackedByteArray()
		mask.resize(n)
	if _rail_img == null:
		_rail_img = Image.create_from_data(d.w, d.h, false, Image.FORMAT_L8, mask)
		_rail_tex = ImageTexture.create_from_image(_rail_img)
		om.set_shader_parameter("rail_tex", _rail_tex)
	else:
		_rail_img.set_data(d.w, d.h, false, Image.FORMAT_L8, mask)
		_rail_tex.update(_rail_img)
	om.set_shader_parameter("has_logi", true)




func _draw() -> void :
	if gw == null or gw.data == null or gw.camera == null:
		return
	var z: float = gw.camera.zoom.x
	match GameWorld.MapMode.MY_LAND if focus_id >= 0 else int(gw.map_mode):
		GameWorld.MapMode.POLITICAL:
			if gw.labels == null:
				_draw_names(z)
		GameWorld.MapMode.LOGISTICS:
			_draw_logistics(z)
		GameWorld.MapMode.MILITARY:
			_draw_military(z)
		GameWorld.MapMode.ALLIANCES:
			_draw_alliances(z)







func _draw_alliances(z: float) -> void :
	var al = gw.diplo.ally if gw.diplo != null else null
	if al == null:
		return
	UiKit.ensure()
	var font: Font = UiKit.f_title if UiKit.f_title != null else ThemeDB.fallback_font
	var cam: MapCamera = gw.camera
	var sc: float = 1.0 / z
	var vs: Vector2 = cam.view_size()
	var view: = Rect2(cam.screen_to_world(Vector2.ZERO), vs * sc)
	var top: float = vs.y * 0.3
	var mn: Node = gw.get_parent()
	var h: Variant = mn.get("hud") if mn != null else null
	var chip: Variant = (h as Object).get("map_chip") if h is Object else null
	if chip is Control and is_instance_valid(chip) and (chip as Control).visible:
		var cc: Control = chip
		var cb: Vector2 = cc.get_canvas_transform() * (cc.global_position + Vector2(0.0, cc.size.y))
		top = maxf(top, cb.y + 8.0)
	var bottom: float = vs.y * 0.76
	var avoid: Array = _city_label_rects(z)
	if gw.labels != null:
		for e: Dictionary in (gw.labels.get("_clabels") as Array):
			if e.has("p") and e.has("b"):
				var bb: Rect2 = e["b"]
				avoid.append(Rect2((e["p"] as Vector2) + bb.position * sc, bb.size * sc))
	var placed: Array = []
	for a: Dictionary in al.list.values():
		var col: Color = al.color(a)
		var lt: Texture2D = UiKit.tex("ally_logo_%d" % int(a.get("logo", 0)))
		var best_p: Vector2 = Vector2.INF
		var best_n: int = 0
		var others: Array = []
		for cl: Array in _clusters(a["members"] as Array):
			var sum: = Vector2.ZERO
			var n: int = 0
			var vis: int = 0
			for m: int in cl:
				for cid in gw.country_by_id(m).city_ids:
					var cp: = Vector2(gw.cities[cid].center * GameWorld.CELL)
					sum += cp
					n += 1
					if view.has_point(cp):
						vis += 1
			if n == 0 or vis == 0:
				continue
			var p: Vector2 = sum / float(n)
			if vis > best_n:
				if best_p.is_finite():
					others.append(best_p)
				best_n = vis
				best_p = p
			else:
				others.append(p)
		if not best_p.is_finite():
			continue

		for op: Vector2 in others:
			if lt != null:
				draw_set_transform(op, 0.0, Vector2(sc, sc))
				var er: = Rect2( - lt.get_size() * 0.5 - Vector2(3, 3), lt.get_size() + Vector2(6, 6))
				draw_rect(er, Color(0.04, 0.06, 0.12, 0.55))
				draw_rect(er, Color(col, 0.8), false, 1.0)
				draw_texture_rect(lt, Rect2(( - lt.get_size() * 0.5).round(), lt.get_size()), false, col)
		var fs: int = 11
		var txt: String = Loc.name(String(a["name"])).to_upper()
		var lw: float = lt.get_size().x if lt != null else 0.0
		var maxw: float = vs.x * 0.45 - lw - 14.0
		while font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw and txt.length() > 4:
			txt = txt.left(txt.length() - 2) + "…"
		var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var box: = Rect2(Vector2( - (lw + 14.0 + tw) * 0.5, -12.0), Vector2(lw + 14.0 + tw, 24.0))
		var best: Vector2 = cam.world_to_screen(best_p)
		var best_ov: float = INF
		for off: Vector2 in ALLY_OFFSETS:
			var q: Vector2 = cam.world_to_screen(best_p) + off * 0.6
			q.x = clampf(q.x, 6.0 - box.position.x, vs.x - 6.0 - box.end.x)
			q.y = clampf(q.y, top - box.position.y, bottom - box.end.y)
			var wq: Vector2 = cam.screen_to_world(q)
			var r2: = Rect2(wq + box.position * sc, box.size * sc)
			var ov: float = _overlap(r2, avoid) + _overlap(r2, placed) * 4.0
			if ov < best_ov:
				best_ov = ov
				best = q
			if ov <= 0.0:
				break
		var wp: Vector2 = cam.screen_to_world(best)
		placed.append(Rect2(wp + box.position * sc, box.size * sc))
		draw_set_transform(wp, 0.0, Vector2(sc, sc))
		draw_rect(box, Color(0.04, 0.06, 0.12, 0.62))
		draw_rect(box, Color(col, 0.9), false, 1.0)
		if lt != null:
			draw_texture_rect(lt, Rect2(Vector2(box.position.x + 5.0, - lt.get_size().y * 0.5).round(), lt.get_size()), false, col)
		var at: = Vector2(box.position.x + lw + 9.0, 4.0).round()
		draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0.04, 0.06, 0.12))
		draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.lightened(0.45))
	draw_set_transform(Vector2.ZERO)


const ALLY_OFFSETS: Array = [Vector2(0, 0), Vector2(0, -50), Vector2(0, 50), Vector2(0, -90), Vector2(0, 90), 
	Vector2(90, 0), Vector2(-90, 0), Vector2(0, -130), Vector2(0, 130), Vector2(110, -60), Vector2(-110, -60)]



func _clusters(mem: Array) -> Array:
	var left: Array = []
	for m: int in mem:
		var c: Country = gw.country_by_id(m)
		if c != null and not c.eliminated and not c.city_ids.is_empty():
			left.append(m)
	var out: Array = []
	while not left.is_empty():
		var cl: Array = [left.pop_front()]
		var i: int = 0
		while i < cl.size():
			for j in range(left.size() - 1, -1, -1):
				if gw.diplo.neighbours(int(cl[i]), int(left[j])):
					cl.append(left[j])
					left.remove_at(j)
			i += 1
		out.append(cl)
	return out



func _draw_names(z: float) -> void :
	UiKit.ensure()
	var font: Font = UiKit.f_title if UiKit.f_title != null else ThemeDB.fallback_font
	var sc: float = 1.0 / z
	var lab: Array = _city_label_rects(z)
	var names: Array = []
	for c: Country in gw.countries:
		if c.eliminated or c.city_ids.is_empty():
			continue
		var sum: = Vector2.ZERO
		var wsum: float = 0.0
		for cid in c.city_ids:
			var city: City = gw.cities[cid]
			var wt: float = 1.0
			sum += Vector2(city.center * GameWorld.CELL) * wt
			wsum += wt
		var p: Vector2 = sum / maxf(wsum, 1.0)
		var fs0: int = 18 if c == gw.player else 16
		var txt: String = Loc.name(c.name).to_upper()


		var best: Array = []
		var best_ov: float = INF
		for fs: int in [fs0, fs0 - 4]:
			var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			for off: Vector2 in NAME_OFFSETS:
				var q: Vector2 = p + off * sc
				var r: = Rect2(q + Vector2( - tw * 0.5 - 4.0, - fs * 0.9) * sc, Vector2(tw + 8.0, fs * 1.15) * sc)
				var ov: float = _overlap(r, lab) + _overlap(r, names) * 2.0
				if ov < best_ov:
					best_ov = ov
					best = [q, fs, tw, r]
				if ov <= 0.0:
					break
			if best_ov <= 0.0:
				break
		var bq: Vector2 = best[0]
		var bfs: int = best[1]
		var btw: float = best[2]
		names.append(best[3])
		var al: float = 1.0 if best_ov <= 0.0 else 0.7
		draw_set_transform(bq, 0.0, Vector2(sc, sc))
		var at: = Vector2( - btw * 0.5, 0)
		draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, 6, Color(c.color.darkened(0.55), 0.95 * al))
		draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, 3, Color(0.04, 0.06, 0.12, al))
		draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(Color("f2efe6"), al))
	draw_set_transform(Vector2.ZERO)



const NAME_OFFSETS: Array = [Vector2(0, 0), Vector2(0, 26), Vector2(0, -26), Vector2(0, 46), Vector2(0, -46), 
	Vector2(60, 12), Vector2(-60, 12), Vector2(0, 70), Vector2(0, -70), Vector2(80, -30), Vector2(-80, -30)]



static func _overlap(r: Rect2, rects: Array) -> float:
	var s: float = 0.0
	for o: Rect2 in rects:
		if r.intersects(o):
			s += r.intersection(o).get_area()
	return s




func _city_label_rects(z: float) -> Array:
	var out: Array = []
	var far: bool = z < 0.5
	var lf: Font = UiKit.f_black if UiKit.f_black != null else ThemeDB.fallback_font
	var cam: MapCamera = gw.camera
	var view: = Rect2(cam.screen_to_world(Vector2.ZERO), cam.view_size() / z).grow(200.0 / z)
	for city: City in gw.cities:
		var cp: = Vector2(city.center * GameWorld.CELL)
		if not view.has_point(cp):
			continue
		var cap: bool = city.kind == City.Kind.CAPITAL
		if not (cap or (z >= 0.5 and city.kind == City.Kind.TOWN) or z >= 1.0):
			if far:
				out.append(Rect2(cp - Vector2(8, 8) / z, Vector2(16, 16) / z))
			continue
		var fsz: int = 11 if cap else 9
		var sz: Vector2 = lf.get_string_size(city.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz)
		sz.y = maxf(sz.y, lf.get_height(fsz))
		var flag: bool = far or cap
		var off_y: float = 8.0 if far else - float(city.radius) * GameWorld.CELL * z * 0.25 - 18.0
		var lp: = Vector2( - sz.x * 0.5 + (9.0 if flag else 0.0), off_y)
		var r: = Rect2(lp - Vector2(20, 2), sz + Vector2(24, 4))
		out.append(Rect2(cp + r.position / z, r.size / z))
		if far:
			out.append(Rect2(cp - Vector2(8, 8) / z, Vector2(16, 16) / z))
	return out


func _draw_logistics(z: float) -> void :
	var sc: float = 1.0 / z
	var view: = Rect2(gw.camera.screen_to_world(Vector2.ZERO), gw.camera.view_size() * sc).grow(24.0 * sc)

	if gw.econ != null:
		for key: String in gw.econ.trade:
			var ab: PackedStringArray = key.split(":")
			if ab.size() < 2:
				continue
			var ca: Country = gw.country_by_id(int(ab[0]))
			var cb: Country = gw.country_by_id(int(ab[1]))
			if ca == null or cb == null or ca.capital_id < 0 or cb.capital_id < 0:
				continue
			var pa: = Vector2(gw.cities[ca.capital_id].center * GameWorld.CELL)
			var pb: = Vector2(gw.cities[cb.capital_id].center * GameWorld.CELL)
			draw_dashed_line(pa, pb, Color(1.0, 0.82, 0.3, 0.75), 2.0 * sc, 7.0 * sc)

		for t: Dictionary in gw.econ.trucks:
			var p: Vector2 = t["pos"]
			if view.has_point(p):
				_dot(p, sc, Color("ffe08a"), 3.0)
		if gw.econ.ports != null:
			for s: Dictionary in gw.econ.ports.ships:
				var ps: Vector2 = s["pos"]
				if view.has_point(ps):
					_dot(ps, sc, Color("bfe6f5"), 4.0)
	if gw.rail != null:

		RV332.logistics(self, gw, z, view)


func _dot(p: Vector2, sc: float, col: Color, r: float) -> void :
	draw_circle(p, (r + 1.0) * sc, Color(0.04, 0.06, 0.12))
	draw_circle(p, r * sc, col)



func _draw_military(z: float) -> void :
	if gw.mil == null:
		return
	var sc: float = 1.0 / z
	var pid: int = gw.player.id if gw.player != null else 0
	for f: Facility in gw.mil.facilities:
		if not AD_COLORS.has(f.kind) or not gw.mil.alive(f):
			continue
		if f.country_id != pid and not MapIcons.known(gw, f):
			continue
		var r: float = 0.0
		if Defense.SPEC.has(f.kind):
			r = float(Defense.SPEC[f.kind]["range"])
		elif f.kind == Facility.Kind.AD_RADAR:
			r = Defense.RADAR_R
		elif f.kind == Facility.Kind.AD_EW:
			r = Defense.EW_R
		if r <= 0.0:
			continue
		var p: Vector2 = f.mpos if f.moving else f.center_px()
		var col: Color = AD_COLORS[f.kind]
		var own: bool = f.country_id == pid
		draw_circle(p, r, Color(col, 0.08 if own else 0.06))
		draw_arc(p, r, 0.0, TAU, 128, Color(0.04, 0.06, 0.12, 0.85), 4.0 * sc)
		draw_arc(p, r, 0.0, TAU, 128, Color(col, 0.95 if own else 0.75), 2.0 * sc)
		if not own:
			var c: Country = gw.country_by_id(f.country_id)
			if c != null:
				draw_arc(p, r - 3.0 * sc, 0.0, TAU, 96, Color(c.color, 0.6), 1.0 * sc)
