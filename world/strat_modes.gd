extends Node2D















const RV332 = preload("res://world/rail_view332.gd")
const PERIOD: float = 0.5
const PERIOD_LOGI: float = 0.25
const ORE_R: float = 30.0
const PIP_R: float = 8.0
const ORE_FAR_Z: float = 0.16
const INK: = Color(0.043, 0.06, 0.13)
const ROAD_COL: = Color("efe3c2")
const TRADE_COL: = Color(1.0, 0.82, 0.3)
const OWN_AD: = Color("4fe0d0")
const ALLY_AD: = Color("6fa8ff")
const FOE_AD: = Color("ff4a3a")

var gw: GameWorld
var _t: float = 99.0
var _z: float = -1.0
var _mode: int = -1
var _roads: PackedVector2Array = PackedVector2Array()
var _roads_n: int = -1
var _groups: Array[CanvasGroup] = []
var _fills: Array[Node2D] = []
var _legend: CanvasLayer = null
var _legend_box: PanelContainer = null
var _legend_mode: int = -1
var _top: Node2D
var stats_items: int = 0


func _ready() -> void :
	z_index = 0
	for i in 3:
		var g: = CanvasGroup.new()
		g.name = "StratAdFill%d" % i
		g.self_modulate = Color(1, 1, 1, 0.3)
		g.visible = false
		add_child(g)
		var n: = Node2D.new()
		var side: int = i
		n.draw.connect( func() -> void : _draw_fill(n, side))
		g.add_child(n)
		_groups.append(g)
		_fills.append(n)
	_top = Node2D.new()
	_top.name = "StratModesTop"
	_top.draw.connect(_draw_top)
	add_child(_top)


func _mode_now() -> int:
	var ml: Variant = gw.get("map_layer")
	if ml is MapModeLayer and (ml as MapModeLayer).focus_id >= 0:
		return GameWorld.MapMode.MY_LAND
	return int(gw.map_mode)



func tick(delta: float, k: float) -> void :
	if gw == null or gw.camera == null:
		return
	modulate.a = k
	var mode: int = _mode_now()
	var z: float = gw.camera.zoom.x
	_t += delta
	var per: float = PERIOD_LOGI if mode == GameWorld.MapMode.LOGISTICS else PERIOD
	if mode != _mode or _t >= per or not is_equal_approx(z, _z):
		var ad: bool = mode == GameWorld.MapMode.AD_COVER
		for g: CanvasGroup in _groups:
			g.visible = ad
		if ad:
			for n: Node2D in _fills:
				n.queue_redraw()
		_mode = mode
		_t = 0.0
		_z = z
		_top.queue_redraw()
	_legend_update(mode)


func hide_all() -> void :
	_legend_update(-1)
	_mode = -1


func _draw_top() -> void :
	stats_items = 0
	if gw == null or gw.camera == null or gw.data == null:
		return
	var z: float = maxf(gw.camera.zoom.x, 0.005)
	match _mode:
		GameWorld.MapMode.ORES:
			_ores(z)
		GameWorld.MapMode.LOGISTICS:
			_logistics(z)
		GameWorld.MapMode.MILITARY:
			_military(z)
		GameWorld.MapMode.ALLIANCES:
			_alliances(z)
		GameWorld.MapMode.AD_COVER:
			_ad_rings(z)



func _snap(wp: Vector2) -> Vector2:
	var cam: MapCamera = gw.camera
	return cam.screen_to_world(cam.world_to_screen(wp).round())


func _view(z: float, pad: float) -> Rect2:
	var cam: MapCamera = gw.camera
	return Rect2(cam.screen_to_world(Vector2.ZERO), cam.view_size() / z).grow(pad / z)




func _ores(z: float) -> void :
	if gw.econ == null:
		return
	var sc: float = 1.0 / z
	var pid: int = gw.player.id if gw.player != null else -1
	var view: Rect2 = _view(z, 16.0)
	var far: bool = z < ORE_FAR_Z
	var cell: float = ORE_R * clampf(ORE_FAR_Z / z, 1.0, 2.4) / z
	var bins: Dictionary = {}
	var res_i: Dictionary = {}
	for dp: Dictionary in gw.econ.deposits:
		if int(dp.get("left", 1)) <= 0:
			continue
		var c: Vector2i = dp["cell"]
		var wp: Vector2 = Vector2(c) * GameWorld.CELL + Vector2(2, 2)
		if not view.has_point(wp):
			continue
		var res: String = String(dp.get("res", "titanium"))
		if not res_i.has(res):
			res_i[res] = res_i.size()
		var mine: Facility = dp["mine"]
		var v: int = 1
		var faded: bool = false
		if mine == null:
			v = 0 if gw.data.get_owner_id(c.x, c.y) == pid else 1
		elif mine.country_id == pid:
			v = 2
		else:
			faded = true
		var key: = Vector3i(int(floorf(wp.x / cell)), int(floorf(wp.y / cell)), int(res_i[res]))
		var b: Array = bins.get(key, [Vector2.ZERO, 0, 9, 0, res])
		b[0] = (b[0] as Vector2) + wp
		b[1] = int(b[1]) + 1
		if not faded:
			b[2] = mini(int(b[2]), v)
		else:
			b[3] = int(b[3]) + 1
		bins[key] = b
	UiKit.ensure()
	var font: Font = UiKit.f_black if UiKit.f_black != null else ThemeDB.fallback_font

	var list: Array = bins.values()
	list.sort_custom( func(a: Array, b: Array) -> bool: return int(a[2]) > int(b[2]))
	for b: Array in list:
		var n: int = int(b[1])
		var p: Vector2 = _snap((b[0] as Vector2) / float(n))
		var v: int = int(b[2])
		var all_faded: bool = v == 9
		if far and all_faded and n == 1:
			continue
		var tx: Texture2D = EcoLayer.ore_tex(String(b[4]), 1 if all_faded else v)
		var a: float = 0.45 if all_faded else 1.0
		var ts: Vector2 = tx.get_size()
		_top.draw_texture_rect(tx, Rect2(p - (ts * 0.5).floor() * sc, ts * sc), false, Color(1, 1, 1, a))
		if n > 1 and z >= ORE_FAR_Z * 0.5:
			var txt: String = "×%d" % n
			_top.draw_set_transform(p + Vector2(6.0, 9.0) * sc, 0.0, Vector2(sc, sc))
			_top.draw_string_outline(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(INK, 0.95 * a))
			_top.draw_string(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.96, 0.86, a))
			_top.draw_set_transform(Vector2.ZERO)
		stats_items += 1





func _road_segments() -> PackedVector2Array:
	var paths: Array = gw.road_paths
	if paths.size() == _roads_n:
		return _roads
	_roads_n = paths.size()
	_roads = PackedVector2Array()
	for path: Array in paths:
		if path.size() < 2:
			continue
		var pts: = PackedVector2Array()
		for c: Vector2i in path:
			pts.append(Vector2(c) * GameWorld.CELL + Vector2(2, 2))
		pts = GameWorld.poly_simplify(pts, 6.0)
		for i in range(1, pts.size()):
			_roads.append(pts[i - 1])
			_roads.append(pts[i])
	return _roads


func _logistics(z: float) -> void :
	var sc: float = 1.0 / z
	var view: Rect2 = _view(z, 24.0)
	var segs: PackedVector2Array = _road_segments()
	if not segs.is_empty():
		_top.draw_multiline(segs, Color(INK, 0.55), 2.6 * sc)
		_top.draw_multiline(segs, Color(ROAD_COL, 0.8), 1.0 * sc)
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
			_top.draw_dashed_line(pa, pb, Color(INK, 0.5), 3.5 * sc, 8.0 * sc)
			_top.draw_dashed_line(pa, pb, Color(TRADE_COL, 0.9), 1.6 * sc, 8.0 * sc)
	var rail = gw.rail
	if rail != null:
		var ta: = PackedVector2Array()
		var tb: = PackedVector2Array()
		var casing: = PackedVector2Array()
		var undone: = PackedVector2Array()
		var dl: float = 5.0 * sc
		for e: Dictionary in rail.edges:
			if bool(e["dead"]):
				continue
			var c: Array = RV332._simplified(e)
			var pts: PackedVector2Array = c[1]
			var cum: PackedFloat32Array = c[2]
			if pts.size() < 2:
				continue
			var L: float = cum[cum.size() - 1]
			var bl: float = L * float(rail.built_frac(e))
			if bl > 0.5:
				var bp: PackedVector2Array = RV332._sub(pts, cum, 0.0, bl) if bl < L else pts
				for i in range(1, bp.size()):
					casing.append(bp[i - 1])
					casing.append(bp[i])
				RV332._ties(pts, cum, 0.0, bl, dl, ta, tb, view)
			if bl < L - 0.5:
				var up: PackedVector2Array = RV332._sub(pts, cum, bl, L)
				for i in range(1, up.size()):
					undone.append(up[i - 1])
					undone.append(up[i])
			stats_items += 1
		if not undone.is_empty():
			_top.draw_multiline(undone, Color(RV332.WORKS_COL, 0.6), 1.2 * sc)
		if not casing.is_empty():
			_top.draw_multiline(casing, RV332.CASING, 4.0 * sc)
		if not ta.is_empty():
			_top.draw_multiline(ta, RV332.TIE_A, 2.0 * sc)
		if not tb.is_empty():
			_top.draw_multiline(tb, RV332.TIE_B, 2.0 * sc)

		for st: Dictionary in rail.stations:
			var pp: Vector2 = st.get("p", Vector2.ZERO)
			if not view.has_point(pp) or (rail.adj.get(int(st["id"]), []) as Array).is_empty():
				continue
			var ruin: bool = float(st["ruin_t"]) >= 0.0
			if z >= 0.1:
				RV332.icon(self, gw.camera, "r332_station", pp, Vector2.ZERO, Color(1, 0.55, 0.5) if ruin else Color.WHITE)
			else:
				var q: Vector2 = _snap(pp)
				_top.draw_rect(Rect2(q - Vector2(2, 2) * sc, Vector2(5, 5) * sc), INK)
				_top.draw_rect(Rect2(q - Vector2(1, 1) * sc, Vector2(3, 3) * sc), Color("ff8a7a") if ruin else RV332.TIE_A)
		for tr: Dictionary in rail.trains:
			var p: Vector2 = rail.pos_at(tr, float(tr.get("s", 0.0)))
			if not view.has_point(p) or (gw.vision != null and not gw.vision.shows(int(tr.get("country", -1)), p)):
				continue
			var nm: String = RV332.badge_of(tr)
			var col: Color = Color("d8d2c4") if nm == "" else (Color("8fbf4a") if tr.has("ride") else Color("ffb43a"))
			_top.draw_circle(p, 3.0 * sc, INK)
			_top.draw_circle(p, 2.0 * sc, col)
	if gw.econ != null and gw.econ.ports != null:
		for s: Dictionary in gw.econ.ports.ships:
			var ps: Vector2 = s["pos"]
			if view.has_point(ps):
				_top.draw_circle(ps, 3.0 * sc, INK)
				_top.draw_circle(ps, 2.0 * sc, Color("bfe6f5"))




func _military(z: float) -> void :
	if gw.mil == null:
		return
	var sc: float = 1.0 / z
	var pid: int = gw.player.id if gw.player != null else 0
	var view: Rect2 = _view(z, 8.0)
	var cell: float = PIP_R / z
	var pips: Dictionary = {}
	var ml: Variant = gw.get("map_layer")
	var ad_cols: Dictionary = MapModeLayer.AD_COLORS
	var cats: Array = [MapIcons.CAT_MIL, MapIcons.CAT_AD, MapIcons.CAT_ARMY, MapIcons.CAT_LOGI, MapIcons.CAT_POWER]
	for f: Facility in gw.mil.facilities:
		if not gw.mil.alive(f):
			continue
		var own: bool = f.country_id == pid
		if not own and not MapIcons.known(gw, f):
			continue
		var p: Vector2 = f.mpos if f.moving else f.center_px()
		if ad_cols.has(f.kind):
			var r: float = 0.0
			if Defense.SPEC.has(f.kind):
				r = float(Defense.SPEC[f.kind]["range"])
			elif f.kind == Facility.Kind.AD_RADAR:
				r = Defense.RADAR_R
			elif f.kind == Facility.Kind.AD_EW:
				r = Defense.EW_R
			if r > 0.0 and view.grow(r).has_point(p):
				var col: Color = ad_cols[f.kind]
				var seg: int = clampi(int(r * z / 2.0), 10, 48)
				_top.draw_circle(p, r, Color(col, 0.07 if own else 0.05))
				_top.draw_arc(p, r, 0.0, TAU, seg, Color(INK, 0.7), 2.5 * sc)
				_top.draw_arc(p, r, 0.0, TAU, seg, Color(col, 0.9 if own else 0.65), 1.0 * sc)
				stats_items += 1
		if MapIcons.minor(f) or MapIcons.priority(f.kind) > 1 or not view.has_point(p):
			continue
		var cc: Color = MapIcons.category_color(f.kind)
		var ci: int = cats.find(cc)
		if ci < 0 or (cc == MapIcons.CAT_POWER and not own):
			continue
		var key: = Vector3i(int(floorf(p.x / cell)), int(floorf(p.y / cell)), ci + (0 if own else 10))
		if not pips.has(key):
			pips[key] = [p, cc, own, f.country_id]
	for pp: Array in pips.values():
		var q: Vector2 = _snap(pp[0])
		var own2: bool = pp[2]
		var rim: Color = INK
		if not own2:
			var c: Country = gw.country_by_id(int(pp[3]))
			rim = c.color.darkened(0.2) if c != null else INK
		_top.draw_rect(Rect2(q - Vector2(3, 3) * sc, Vector2(6, 6) * sc), rim)
		_top.draw_rect(Rect2(q - Vector2(2, 2) * sc, Vector2(4, 4) * sc), pp[1])
		stats_items += 1




func _alliances(z: float) -> void :
	var al = gw.diplo.ally if gw.diplo != null else null
	var ml: Variant = gw.get("map_layer")
	if al == null or not (ml is MapModeLayer):
		return
	UiKit.ensure()
	var font: Font = UiKit.f_title if UiKit.f_title != null else ThemeDB.fallback_font
	var cam: MapCamera = gw.camera
	var sc: float = 1.0 / z
	var vs: Vector2 = cam.view_size()
	var view: Rect2 = _view(z, 0.0)
	var avoid: Array = []
	if gw.labels != null:
		for r: Rect2 in gw.labels.name_rects:
			avoid.append(r)
	var placed: Array = []
	for a: Dictionary in al.list.values():
		var col: Color = al.color(a)
		var lt: Texture2D = UiKit.tex("ally_logo_%d" % int(a.get("logo", 0)))
		var pts: Array = []
		for cl: Array in (ml as MapModeLayer)._clusters(a["members"] as Array):
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
			if n > 0 and vis > 0:
				pts.append([sum / float(n), vis])
		if pts.is_empty():
			continue
		pts.sort_custom( func(x: Array, y: Array) -> bool: return int(x[1]) > int(y[1]))
		for i in range(1, pts.size()):
			if lt != null:
				var op: Vector2 = _snap(pts[i][0])
				_top.draw_set_transform(op, 0.0, Vector2(sc, sc))
				var er: = Rect2( - lt.get_size() * 0.5 - Vector2(3, 3), lt.get_size() + Vector2(6, 6))
				_top.draw_rect(er, Color(INK, 0.6))
				_top.draw_rect(er, Color(col, 0.85), false, 1.0)
				_top.draw_texture_rect(lt, Rect2(( - lt.get_size() * 0.5).round(), lt.get_size()), false, col)
				_top.draw_set_transform(Vector2.ZERO)
		var txt: String = Loc.name(String(a["name"])).to_upper()
		var fs: int = 10
		var lw: float = lt.get_size().x if lt != null else 0.0
		var maxw: float = vs.x * 0.42 - lw - 14.0
		while font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw and txt.length() > 4:
			txt = txt.left(txt.length() - 2) + "…"
		var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var box: = Rect2(Vector2( - (lw + 14.0 + tw) * 0.5, -11.0), Vector2(lw + 14.0 + tw, 22.0))
		var c0: Vector2 = cam.world_to_screen(pts[0][0])
		var best: Vector2 = c0
		var best_ov: float = INF
		for off: Vector2 in [Vector2(0, 26), Vector2(0, -26), Vector2(0, 46), Vector2(0, -46), Vector2(70, 0), Vector2(-70, 0), Vector2(0, 0)]:
			var q: Vector2 = c0 + off
			q.x = clampf(q.x, 6.0 - box.position.x, vs.x - 6.0 - box.end.x)
			var wq: Vector2 = cam.screen_to_world(q)
			var r2: = Rect2(wq + box.position * sc, box.size * sc)
			var ov: float = MapModeLayer._overlap(r2, avoid) + MapModeLayer._overlap(r2, placed) * 4.0
			if ov < best_ov:
				best_ov = ov
				best = q
			if ov <= 0.0:
				break
		var wp: Vector2 = cam.screen_to_world(best.round())
		placed.append(Rect2(wp + box.position * sc, box.size * sc))
		_top.draw_set_transform(wp, 0.0, Vector2(sc, sc))
		_top.draw_rect(box, Color(INK, 0.7))
		_top.draw_rect(box, Color(col, 0.95), false, 1.0)
		if lt != null:
			_top.draw_texture_rect(lt, Rect2(Vector2(box.position.x + 5.0, - lt.get_size().y * 0.5).round(), lt.get_size()), false, col)
		var at: = Vector2(box.position.x + lw + 9.0, 4.0).round()
		_top.draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, INK)
		_top.draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.lightened(0.45))
		_top.draw_set_transform(Vector2.ZERO)
		stats_items += 1





func _ad_sites() -> Array:
	var ml: Variant = gw.get("map_layer")
	if not (ml is MapModeLayer):
		return []
	var adc: Node = (ml as MapModeLayer).get_node_or_null("AdCover")
	if adc == null:
		return []
	var s: Variant = adc.get("_sites")
	return s if s is Array else []


func _draw_fill(n: Node2D, side: int) -> void :
	var col: Color = [OWN_AD, ALLY_AD, FOE_AD][side]
	for s: Array in _ad_sites():
		if int(s[2]) == side and Defense.SPEC.has(int(s[3])):
			n.draw_circle(s[0], float(s[1]), col)


func _ad_rings(z: float) -> void :
	var sc: float = 1.0 / z
	for s: Array in _ad_sites():
		var p: Vector2 = s[0]
		var r: float = s[1]
		var k: int = s[3]
		var seg: int = clampi(int(r * z / 2.0), 10, 64)
		if Defense.SPEC.has(k):
			var col: Color = [OWN_AD, ALLY_AD, FOE_AD][int(s[2])]
			_top.draw_arc(p, r, 0.0, TAU, seg, Color(INK, 0.75), 2.5 * sc)
			_top.draw_arc(p, r, 0.0, TAU, seg, Color(col, 0.95), 1.0 * sc)
		else:
			var col2: Color = AdCoverLayer.RADAR_COL if k == Facility.Kind.AD_RADAR else AdCoverLayer.EW_COL
			var n: int = clampi(int(TAU * r * z / 10.0), 8, 64)
			var step: float = TAU / float(n)
			for i in n:
				var a0: float = float(i) * step
				_top.draw_arc(p, r, a0, a0 + step * 0.55, 3, Color(col2, 0.85), 1.0 * sc)
		stats_items += 1




func _legend_update(mode: int) -> void :
	var on: bool = mode == GameWorld.MapMode.LOGISTICS or mode == GameWorld.MapMode.MILITARY
	if not on:
		if _legend_box != null:
			_legend_box.visible = false
		return
	if _legend_box == null or mode != _legend_mode:
		_build_legend(mode)
	_legend_box.visible = true
	_legend_box.position = legend_pos(_legend_box, gw)




static func legend_pos(box: Control, w: GameWorld) -> Vector2:
	var vs: Vector2 = box.get_viewport_rect().size
	box.reset_size()
	var sz: Vector2 = box.size
	var y: float = 96.0
	var mn: Node = w.get_parent() if w != null else null
	var h: Variant = mn.get("hud") if mn != null else null
	var chip: Variant = (h as Object).get("map_chip") if h is Object else null
	if chip is Control and is_instance_valid(chip) and (chip as Control).is_visible_in_tree():
		y = (chip as Control).get_global_rect().end.y + 3.0
	var x: float = roundf((vs.x - sz.x) * 0.5)
	var avoid: Array[Rect2] = []
	if h is Object:
		var pp: Variant = (h as Object).get("plan_panel")
		if pp is Control and is_instance_valid(pp) and (pp as Control).is_visible_in_tree():
			avoid.append((pp as Control).get_global_rect())
		var cb: Variant = (h as Object).get("cmd_btns")
		if cb is Array:
			for e: Variant in cb:
				var b: Variant = (e as Array)[0] if e is Array and not (e as Array).is_empty() else null
				if b is Control and is_instance_valid(b) and (b as Control).is_visible_in_tree():
					avoid.append((b as Control).get_global_rect())
	var y0: float = y
	for i: int in 6:
		var hit: bool = false
		for a: Rect2 in avoid:
			if a.intersects(Rect2(x, y, sz.x, sz.y).grow(2.0)):
				y = a.end.y + 3.0
				hit = true
		if not hit:
			break
	if y + sz.y > vs.y * 0.55:
		y = y0
	return Vector2(x, roundf(y))


func _build_legend(mode: int) -> void :
	_legend_mode = mode
	if _legend != null:
		_legend.queue_free()
	UiKit.ensure()
	_legend = CanvasLayer.new()
	_legend.name = "StratLegend"
	add_child(_legend)
	var pc: = PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0.043, 0.078, 0.188, 0.84)
	sb.border_color = Color(0.96, 0.93, 0.82, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	pc.add_theme_stylebox_override("panel", sb)
	var hb: = HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 3)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(hb)
	var items: Array = []
	if mode == GameWorld.MapMode.LOGISTICS:
		items = [["rail", Loc.t("ЖД")], ["station", Loc.t("станции")], ["road", Loc.t("дороги")], ["trade", Loc.t("торговля")]]
	else:
		items = [["ad", Loc.t("ПВО")], ["mil", Loc.t("базы")], ["army", Loc.t("войска")], ["foe", Loc.t("чужие")]]
	for it: Array in items:
		hb.add_child(_swatch(String(it[0])))
		var l: Label = UiKit.lbl(String(it[1]), 9, UiKit.TEXT, 1, 2)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.custom_minimum_size = Vector2(0, 18)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(l)
		var gap: = Control.new()
		gap.custom_minimum_size = Vector2(4, 0)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(gap)
	_legend.add_child(pc)
	_legend_box = pc


func _swatch(kind: String) -> Control:
	var c: = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(16, 18)
	c.draw.connect( func() -> void :
		var ctr: Vector2 = (c.size * 0.5).floor()
		match kind:
			"rail":
				c.draw_rect(Rect2(ctr + Vector2(-7, -2), Vector2(14, 4)), RV332.CASING)
				for i in 3:
					c.draw_rect(Rect2(ctr + Vector2(-6 + i * 4, -1), Vector2(4, 2)), RV332.TIE_A if i % 2 == 0 else RV332.TIE_B)
			"station":
				c.draw_rect(Rect2(ctr - Vector2(3, 3), Vector2(6, 6)), INK)
				c.draw_rect(Rect2(ctr - Vector2(2, 2), Vector2(4, 4)), RV332.TIE_A)
			"road":
				c.draw_line(ctr + Vector2(-7, 2), ctr + Vector2(7, -2), Color(INK, 0.7), 3.0)
				c.draw_line(ctr + Vector2(-7, 2), ctr + Vector2(7, -2), ROAD_COL, 1.0)
			"trade":
				for i in 3:
					c.draw_rect(Rect2(ctr + Vector2(-7 + i * 5, -1), Vector2(3, 2)), TRADE_COL)
			"ad":
				c.draw_circle(ctr, 5.5, Color(OWN_AD, 0.25))
				c.draw_arc(ctr, 5.5, 0.0, TAU, 16, OWN_AD, 1.0)
			"mil", "army":
				c.draw_rect(Rect2(ctr - Vector2(3, 3), Vector2(6, 6)), INK)
				c.draw_rect(Rect2(ctr - Vector2(2, 2), Vector2(4, 4)), MapIcons.CAT_MIL if kind == "mil" else MapIcons.CAT_ARMY)
			"foe":
				c.draw_rect(Rect2(ctr - Vector2(3, 3), Vector2(6, 6)), Color("c94a4a"))
				c.draw_rect(Rect2(ctr - Vector2(2, 2), Vector2(4, 4)), MapIcons.CAT_MIL)
		)
	return c
