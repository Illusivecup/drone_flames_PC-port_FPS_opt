extends Control





const UP: = Color("ff6a4d")
const DOWN: = Color("a2e35f")
const FLAT: = Color("cfc6a8")
const WELL: = Color(0.0, 0.0, 0.0, 0.28)
const GRID: = Color(1.0, 1.0, 1.0, 0.08)

var hist: = PackedFloat32Array()
var dir: int = 0
var big: bool = false
var crisis: bool = false


func _init() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_data(h: PackedFloat32Array, d: int, cr: bool = false) -> void :
	if h == hist and d == dir and cr == crisis:
		return
	hist = h
	dir = d
	crisis = cr
	queue_redraw()


func _col() -> Color:
	return UP if dir > 0 else (DOWN if dir < 0 else FLAT)


func _draw() -> void :
	var tri_w: float = 7.0
	var area: = Rect2(Vector2(1, 1), Vector2(maxf(4.0, size.x - tri_w - 3.0), maxf(3.0, size.y - 2.0)))
	var scale_w: float = 0.0
	if big:
		scale_w = 24.0
		area.position.x += scale_w
		area.size.x -= scale_w
		draw_rect(Rect2(Vector2(scale_w, 0), Vector2(area.size.x + 2.0, size.y)), WELL)
		draw_rect(Rect2(Vector2(scale_w + 1.0, roundf(size.y * 0.5)), Vector2(area.size.x, 1)), GRID)
		area = area.grow(-2.0)
	var col: Color = _col()
	if crisis:
		draw_rect(Rect2(Vector2.ZERO, Vector2(2, size.y)), UP)
	var n: int = hist.size()
	if n < 2:
		var y: float = roundf(area.position.y + area.size.y * 0.5)
		var x: float = area.position.x
		while x < area.end.x:
			draw_rect(Rect2(Vector2(x, y), Vector2(2, 1)), FLAT * Color(1, 1, 1, 0.6))
			x += 4.0
	else:
		var lo: float = hist[0]
		var hi: float = hist[0]
		for v: float in hist:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		if hi - lo < 1.0:
			hi += 0.5
			lo -= 0.5
		var pts: = PackedVector2Array()
		for i in n:
			var px: float = area.position.x + area.size.x * float(i) / float(n - 1)
			var py: float = area.end.y - (hist[i] - lo) / (hi - lo) * area.size.y
			pts.append(Vector2(roundf(px) + 0.5, roundf(py) + 0.5))
		draw_polyline(pts, col * Color(1, 1, 1, 0.9), 2.0 if big else 1.0)
		var last: Vector2 = pts[n - 1]
		draw_rect(Rect2(last - Vector2(1.5, 1.5), Vector2(3, 3)), col)
		if big:
			draw_rect(Rect2(Vector2(area.position.x, area.position.y), Vector2(3, 1)), FLAT)
			draw_rect(Rect2(Vector2(area.position.x, area.end.y - 1.0), Vector2(3, 1)), FLAT)
			var f: Font = UiKit.f_bold
			var hs: String = str(roundi(hi))
			var ls: String = str(roundi(lo))
			draw_string(f, Vector2(scale_w - 3.0 - f.get_string_size(hs, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x, area.position.y + 7.0), hs, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, FLAT)
			draw_string(f, Vector2(scale_w - 3.0 - f.get_string_size(ls, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x, area.end.y + 1.0), ls, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, FLAT * Color(1, 1, 1, 0.75))

	var cx: float = size.x - tri_w * 0.5 - 1.0
	var cy: float = roundf(size.y * 0.5)
	if dir > 0:
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 3.5, cy + 2.5), Vector2(cx + 3.5, cy + 2.5), Vector2(cx, cy - 3.0)]), UP)
	elif dir < 0:
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 3.5, cy - 2.5), Vector2(cx + 3.5, cy - 2.5), Vector2(cx, cy + 3.0)]), DOWN)
	else:
		draw_rect(Rect2(Vector2(cx - 3.0, cy - 1.0), Vector2(6, 2)), FLAT)
