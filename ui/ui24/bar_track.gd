extends Control




var frac: float = 0.0:
	set(v):
		var nv: float = clampf(v, 0.0, 1.0)
		if absf(nv - frac) > 0.0005:
			frac = nv
			queue_redraw()
var fill_name: String = "wb_bar_green":
	set(v):
		if v != fill_name:
			fill_name = v
			_fill = UiKit.sb(v, 0)
			queue_redraw()
var ticks: int = 0
var min_px: float = 2.0
var _frame: StyleBox
var _fill: StyleBox


func _init() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = UiKit.sb("wb_bar_frame", 0)
	_fill = UiKit.sb(fill_name, 0)


func tween_to(tw: Tween, target: float, dur: float = 0.3) -> void :
	tw.tween_property(self, "frac", clampf(target, 0.0, 1.0), dur).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _draw() -> void :
	if _frame != null:
		draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	var inner: = Rect2(Vector2(2, 2), size - Vector2(4, 4))
	if ticks > 1:
		for i: int in range(1, ticks):
			var x: float = roundf(inner.position.x + inner.size.x * float(i) / float(ticks))
			draw_rect(Rect2(x, inner.position.y, 1, inner.size.y), Color(1, 1, 1, 0.09))
	if frac > 0.0 and _fill != null:
		var w: float = maxf(min_px, roundf(inner.size.x * frac))
		draw_style_box(_fill, Rect2(inner.position, Vector2(w, inner.size.y)))
