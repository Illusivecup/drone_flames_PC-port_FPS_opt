class_name FlyingCandyGd
extends Node2D
## GDScript-фолбэк «Летающей конфетки» — полная копия логики DfFlyingCandy (Rust).
## Используется, если нативное расширение df_rust не загрузилось:
## игра остаётся работоспособной без нативных библиотек.

var start: Vector2 = Vector2.ZERO
var end: Vector2 = Vector2.ZERO
var height: float = 14.0
var duration: float = 16.0
var phase: float = 0.0

var _vis_t: float = 0.0
var _finished: bool = false


func _ready() -> void:
	z_index = 60


func _process(delta: float) -> void:
	var ts: float = 1.0
	var p: Node = get_parent()
	if p != null:
		ts = float(p.get("time_scale")) if p.get("time_scale") != null else 1.0
	_vis_t += delta * ts
	if _vis_t > duration + 0.6:
		_finished = true
		queue_free()
		return
	var k: float = clampf(_vis_t / duration, 0.0, 1.0)
	var pos: Vector2 = start.lerp(end, k)
	var bob: float = sin(_vis_t * 2.4 + phase) * 1.8
	position = Vector2(pos.x, pos.y + bob - height)
	queue_redraw()


func _draw() -> void:
	var t: float = _vis_t
	var tilt: float = sin(t * 1.7 + phase) * 0.12
	_ellipse(Vector2(height * 0.9, height * 0.9), 10.0, 4.0, 0.0, Color(0, 0, 0, 0.18))
	var flutter: float = sin(t * 7.0 + phase) * 0.22
	_wrapper(-1.0, flutter)
	_wrapper(1.0, -flutter)
	_ellipse(Vector2.ZERO, 13.5, 8.5, tilt, Color(1.0, 0.55, 0.72, 1.0))
	_band(-6.0, -2.2, tilt, Color(1, 1, 1, 0.92))
	_band(2.2, 6.0, tilt, Color(1, 1, 1, 0.92))
	_ellipse(Vector2(-4.0, -3.0), 3.6, 2.2, tilt, Color(1, 1, 1, 0.55))


func visual_world_pos() -> Vector2:
	return position + Vector2(0.0, height)


func flight_done() -> bool:
	return _finished


func path_point(k: float) -> Vector2:
	return start.lerp(end, clampf(k, 0.0, 1.0))


func _ellipse(at: Vector2, rx: float, ry: float, rot: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 26:
		var a: float = TAU * float(i) / 26.0
		var p: Vector2 = Vector2(at.x + rx * cos(a), at.y + ry * sin(a))
		pts.append(_rot(p, rot, at))
	draw_colored_polygon(pts, col)


func _band(x1: float, x2: float, rot: float, col: Color) -> void:
	var xa: float = maxf(minf(x1, x2), -13.5)
	var xb: float = minf(maxf(x1, x2), 13.5)
	if xa >= xb:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 9:
		var x: float = xa + (xb - xa) * float(i) / 8.0
		var dy: float = 8.5 * sqrt(maxf(0.0, 1.0 - pow(x / 13.5, 2)))
		pts.append(Vector2(x, -dy))
	for i in range(8, -1, -1):
		var x: float = xa + (xb - xa) * float(i) / 8.0
		var dy: float = 8.5 * sqrt(maxf(0.0, 1.0 - pow(x / 13.5, 2)))
		pts.append(Vector2(x, dy))
	var rot_pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		rot_pts.append(_rot(p, rot, Vector2.ZERO))
	draw_colored_polygon(rot_pts, col)


func _wrapper(side: float, flutter: float) -> void:
	var tip_x: float = side * (13.5 - 1.0)
	var spread: float = 9.0 + flutter * 6.0
	var dy: float = 7.0 + flutter * 3.0
	var gold: Color = Color(1.0, 0.82, 0.35, 1.0)
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(tip_x, 0.0), Vector2(tip_x + side * spread, -dy), Vector2(tip_x + side * spread, dy),
	])
	draw_colored_polygon(pts, gold)
	var pts2: PackedVector2Array = PackedVector2Array([
		Vector2(tip_x - side * 1.5, 0.0),
		Vector2(tip_x + side * spread * 0.45, -dy * 0.45),
		Vector2(tip_x + side * spread * 0.45, dy * 0.45),
	])
	draw_colored_polygon(pts2, gold)


func _rot(p: Vector2, rot: float, around: Vector2) -> Vector2:
	if rot == 0.0:
		return p
	var d: Vector2 = p - around
	var s: float = sin(rot)
	var c: float = cos(rot)
	return around + Vector2(d.x * c - d.y * s, d.x * s + d.y * c)
