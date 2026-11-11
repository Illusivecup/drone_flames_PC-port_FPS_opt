extends RefCounted










static var _x0: int = 0
static var _tops: PackedInt32Array = PackedInt32Array()



static func begin(gw: GameWorld, x0: int, w: int, foot: int) -> void :
	_x0 = x0
	_tops = gw.objects.cover_span(x0, w, foot) if gw != null and gw.objects != null else PackedInt32Array()


static func _top(x: int) -> int:
	var i: int = x - _x0
	return _tops[i] if i >= 0 and i < _tops.size() else 1 << 30




static func blit(ci: CanvasItem, tex: Texture2D, dst: Rect2, src: Rect2, mod: Color = Color.WHITE) -> void :
	if _tops.is_empty() or GameConfig.eff_simple_cover():
		ci.draw_texture_rect_region(tex, dst, src, mod)
		return
	var flip: bool = dst.size.x < 0.0
	var w: int = int(absf(dst.size.x))
	var h: int = int(dst.size.y)
	var lx: int = int(dst.position.x + (dst.size.x if flip else 0.0))
	var y0: int = int(dst.position.y)
	for k in w:
		var vh: int = clampi(_top(lx + k) - y0, 0, h)
		if vh <= 0:
			continue
		var sx: float = src.position.x + float(w - 1 - k if flip else k)
		if vh >= h:
			ci.draw_texture_rect_region(tex, Rect2(lx + k, y0, 1, h), Rect2(sx, src.position.y, 1, h), mod)
		else:
			ci.draw_texture_rect_region(tex, Rect2(lx + k, y0, 1, vh), Rect2(sx, src.position.y, 1, vh), mod)



static func blit_tex(ci: CanvasItem, tex: Texture2D, dst: Rect2, mod: Color = Color.WHITE) -> void :
	blit(ci, tex, dst, Rect2(Vector2.ZERO, Vector2(tex.get_size())), mod)



static func rect(ci: CanvasItem, r: Rect2, col: Color) -> void :
	if _tops.is_empty():
		ci.draw_rect(r, col)
		return
	var x0: int = int(floorf(r.position.x))
	var w: int = int(ceilf(r.size.x))
	var y0: int = int(floorf(r.position.y))
	var h: int = int(ceilf(r.size.y))
	for k in w:
		var vh: int = clampi(_top(x0 + k) - y0, 0, h)
		if vh > 0:
			ci.draw_rect(Rect2(x0 + k, y0, 1, vh), col)



static func end() -> void :
	if not _tops.is_empty():
		_tops = PackedInt32Array()
