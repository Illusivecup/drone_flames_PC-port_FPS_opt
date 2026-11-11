class_name AdCoverLayer
extends Node2D







const SM334 = preload("res://world/strat_modes.gd")
const OWN_COL: = Color("4fe0d0")
const ALLY_COL: = Color("6fa8ff")
const FOE_COL: = Color("ff4a3a")
const RADAR_COL: = Color("9bc53d")
const EW_COL: = Color("c08cff")
const FILL_A: float = 0.3
const RIM: = Color(0.04, 0.06, 0.12, 0.85)
const PERIOD: float = 0.5

var gw: GameWorld
var _groups: Array[CanvasGroup] = []
var _fills: Array[Node2D] = []
var _rings: Node2D
var _sites: Array = []
var _t: float = 99.0
var _z: float = -1.0
var _on: bool = false
var _legend: CanvasLayer = null
var _legend_box: PanelContainer = null


func _ready() -> void :
	for i in 3:
		var g: = CanvasGroup.new()
		g.name = "AdFill%d" % i
		g.self_modulate = Color(1, 1, 1, FILL_A)
		add_child(g)
		var n: = Node2D.new()
		var side: int = i
		n.draw.connect( func() -> void : _draw_fill(n, side))
		g.add_child(n)
		_groups.append(g)
		_fills.append(n)
	_rings = Node2D.new()
	_rings.name = "AdRings"
	_rings.draw.connect( func() -> void : _draw_rings())
	add_child(_rings)
	visible = false


func _process(delta: float) -> void :
	if gw == null or gw.mil == null or gw.camera == null:
		return
	var on: bool = int(gw.map_mode) == GameWorld.MapMode.AD_COVER and (gw.map_layer == null or gw.map_layer.focus_id < 0)
	if on != _on:
		_on = on
		visible = on
		_t = 99.0
	_legend_update(on)
	if not on:
		return
	_t += delta
	var z: float = gw.camera.zoom.x
	if _t < PERIOD and is_equal_approx(z, _z):
		return
	_t = 0.0
	_z = z
	_collect()
	for n: Node2D in _fills:
		n.queue_redraw()
	_rings.queue_redraw()


func _collect() -> void :
	_sites.clear()
	var pid: int = gw.player.id if gw.player != null else 0
	var vis: Vision = gw.vision
	for f: Facility in gw.mil.facilities:
		var k: int = f.kind
		var r: float = 0.0
		if Defense.SPEC.has(k):
			r = float(Defense.SPEC[k]["range"])
		elif k == Facility.Kind.AD_RADAR:
			r = Defense.RADAR_R
		elif k == Facility.Kind.AD_EW:
			r = Defense.EW_R
		if r <= 0.0 or not gw.mil.alive(f):
			continue
		var side: int = 0
		var p: Vector2 = f.mpos if f.moving else f.center_px()
		if f.country_id != pid:
			if vis != null and vis.active() and not vis.friend(f.country_id):
				if not vis.known(f):
					continue
				side = 2
				if not vis.fac_shown(f):
					p = vis.last_pos(f)
			else:
				side = 1 if vis != null and vis.active() else 2
		_sites.append([p, r, side, k])


func _draw_fill(n: Node2D, side: int) -> void :
	var col: Color = [OWN_COL, ALLY_COL, FOE_COL][side]
	for s: Array in _sites:
		if int(s[2]) == side and Defense.SPEC.has(int(s[3])):
			n.draw_circle(s[0], float(s[1]), col)


func _draw_rings() -> void :
	var sc: float = 1.0 / maxf(_z, 0.01)
	for s: Array in _sites:
		var p: Vector2 = s[0]
		var r: float = s[1]
		var k: int = s[3]
		var seg: int = clampi(int(r * _z / 3.0), 48, 160)
		if Defense.SPEC.has(k):
			var col: Color = [OWN_COL, ALLY_COL, FOE_COL][int(s[2])]
			_rings.draw_arc(p, r, 0.0, TAU, seg, RIM, 3.0 * sc)
			_rings.draw_arc(p, r, 0.0, TAU, seg, Color(col, 0.95), 1.5 * sc)
			_rings.draw_circle(p, 2.5 * sc, RIM)
			_rings.draw_circle(p, 1.5 * sc, col)
		else:
			_dashed(p, r, RADAR_COL if k == Facility.Kind.AD_RADAR else EW_COL, sc, int(s[2]) == 2)



func _dashed(p: Vector2, r: float, col: Color, sc: float, foe: bool) -> void :
	var circ: float = TAU * r * _z
	var n: int = clampi(int(circ / 20.0), 12, 240)
	var step: float = TAU / float(n)
	for i in n:
		var a0: float = float(i) * step
		var a1: float = a0 + step * 0.55
		_rings.draw_arc(p, r, a0, a1, 4, Color(FOE_COL, 0.7) if foe else RIM, 3.0 * sc)
		_rings.draw_arc(p, r, a0, a1, 4, Color(col, 0.9), 1.5 * sc)



func _legend_update(on: bool) -> void :
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
	_legend.name = "AdLegend"
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
	var vb: = VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	pc.add_child(vb)
	for row: Array in [[[OWN_COL, "ваша", false], [ALLY_COL, "союзники", false], [FOE_COL, "чужая (разведано)", false]], 
			[[RADAR_COL, "РЛС", true], [EW_COL, "РЭБ", true]]]:
		var hb: = HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_theme_constant_override("separation", 3)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		for it: Array in row:
			hb.add_child(_swatch(it[0], bool(it[2])))
			var l: Label = UiKit.lbl(String(it[1]), 9, UiKit.TEXT, 1, 2)
			l.custom_minimum_size = Vector2(0, 18)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hb.add_child(l)
			var gap: = Control.new()
			gap.custom_minimum_size = Vector2(4, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(gap)
		vb.add_child(hb)
	_legend.add_child(pc)
	_legend_box = pc


func _swatch(col: Color, dashed: bool) -> Control:
	var c: = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(14, 18)
	c.draw.connect( func() -> void :
		var ctr: Vector2 = c.size * 0.5
		if dashed:
			for i in 4:
				var a0: float = float(i) * TAU / 4.0
				c.draw_arc(ctr, 5.0, a0, a0 + TAU / 8.0, 4, col, 1.5)
		else:
			c.draw_circle(ctr, 5.5, Color(col, FILL_A + 0.15))
			c.draw_arc(ctr, 5.5, 0.0, TAU, 16, col, 1.5)
		)
	return c
