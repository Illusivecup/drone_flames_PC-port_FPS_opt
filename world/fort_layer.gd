class_name FortLayer
extends Node2D




var gw: GameWorld
const N8: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]


var _dig_t: float = 0.0
var _dig_had: bool = false




func _process(delta: float) -> void :
	_dig_t -= delta
	if _dig_t > 0.0 or gw == null or gw.mil == null:
		return
	_dig_t = 0.25
	var busy: bool = not _dig_cells().is_empty()
	if not busy:
		for f: Facility in gw.mil.facilities:
			if f.kind == Facility.Kind.DUGOUT and _build_left(f) > 0.0:
				busy = true
				break
	if busy or _dig_had:
		queue_redraw()
	_dig_had = busy



func _dig_cells() -> Dictionary:
	var dc: Variant = gw.mil.get("dig_cells")
	return dc if dc is Dictionary else {}


func _build_left(f: Facility) -> float:
	var v: Variant = f.get("build_t")
	return float(v) if v != null else 0.0


static func _mil_const(n: String, def: float) -> float:
	return float((Military as Script).get_script_constant_map().get(n, def))




func _draw_dig() -> void :
	var dc: Dictionary = _dig_cells()
	var tape: = Palette.c("sand_light")
	var earth: = Palette.c("earth")
	var pit: = Palette.c("ui_rubber")
	var stake: = Palette.c("wood")
	var conc: = Palette.c("concrete_dark")
	var amber: = Palette.c("amber")
	var dark: = Palette.c("outline")
	for cell: Vector2i in dc:
		var f: Facility = dc[cell]
		if f == null or (gw.vision != null and not gw.vision.fac_shown(f) and not gw.vision.friend(f.country_id)):
			continue
		var o: = Vector2(cell * GameWorld.CELL)
		var teeth: bool = f.kind == Facility.Kind.TEETH_H or f.kind == Facility.Kind.TEETH_V
		var cur: bool = false
		var pend: Variant = f.get("pending")
		if pend is Array and not (pend as Array).is_empty() and (pend as Array)[0] == cell:
			cur = true
		if cur:
			var per: float = _mil_const("TEETH_CELL_T" if teeth else "DIG_CELL_T", 1.5)
			var k: float = 1.0 - clampf(_build_left(f) / maxf(per, 0.01), 0.0, 1.0)
			draw_rect(Rect2(o, Vector2(4, 4)), earth)
			if teeth:
				draw_rect(Rect2(o + Vector2(1, 3 - roundf(2.0 * k)), Vector2(2, 1 + roundf(2.0 * k))), Palette.c("concrete_light"))
			else:
				var s: float = 1.0 + roundf(2.0 * k)
				draw_rect(Rect2(o + Vector2(2, 2) - Vector2(s, s) * 0.5, Vector2(s, s)).abs(), pit)
			draw_rect(Rect2(o + Vector2(0, -1), Vector2(4, 1)), Palette.c("amber"))
			continue


		draw_rect(Rect2(o, Vector2(4, 4)), Color(earth, 0.45))
		if teeth:
			draw_rect(Rect2(o + Vector2(1, 1), Vector2(2, 2)), Color(conc, 0.8))
		else:
			draw_rect(Rect2(o + Vector2(1, 2), Vector2(2, 1)), Color(pit, 0.5))
		draw_rect(Rect2(o + Vector2(0, -1), Vector2(2, 1)), amber if cell.x % 2 == 0 else dark)
		draw_rect(Rect2(o + Vector2(2, -1), Vector2(2, 1)), dark if cell.x % 2 == 0 else amber)
		draw_rect(Rect2(o + Vector2(0, 4), Vector2(4, 1)), Color(tape, 0.6))
		if Hash32.h2(cell.x, cell.y, 7) % 4 == 0:
			draw_rect(Rect2(o + Vector2(3, -2), Vector2(1, 3)), stake)
	for f: Facility in gw.mil.facilities:
		if f.kind != Facility.Kind.DUGOUT or _build_left(f) <= 0.0:
			continue
		if gw.vision != null and not gw.vision.fac_shown(f):
			continue
		var r: = Rect2(Vector2(f.cell * GameWorld.CELL), Vector2(f.size * GameWorld.CELL))
		var x: float = r.position.x
		while x < r.end.x:
			draw_rect(Rect2(x, r.position.y - 1, 2, 1), tape)
			draw_rect(Rect2(x, r.end.y, 2, 1), tape)
			x += 4.0
		var y: float = r.position.y
		while y < r.end.y:
			draw_rect(Rect2(r.position.x - 1, y, 1, 2), tape)
			draw_rect(Rect2(r.end.x, y, 1, 2), tape)
			y += 4.0
		var k2: float = 1.0 - clampf(_build_left(f) / _mil_const("DUGOUT_T", 10.0), 0.0, 1.0)
		if gw.mil.has_method("dig_progress"):
			k2 = float(gw.mil.call("dig_progress", f))
		var bw: float = minf(r.size.x, 24.0)
		var bp: = Vector2(r.get_center().x - bw * 0.5, r.position.y - 5.0)
		draw_rect(Rect2(bp, Vector2(bw, 3)), Palette.c("ui_rubber"))
		draw_rect(Rect2(bp + Vector2(1, 1), Vector2(bw - 2.0, 1)), Palette.c("ui_steel_dark"))
		draw_rect(Rect2(bp + Vector2(1, 1), Vector2(floorf((bw - 2.0) * k2), 1)), Palette.c("amber"))


func _draw() -> void :
	if gw == null or gw.mil == null:
		return
	_draw_dig()
	var fc: Dictionary = gw.mil.fort_cells
	if fc.is_empty():
		return
	var earth: = Palette.c("earth_dark")
	var rim: = Palette.c("earth")
	var pit: = Palette.c("ui_rubber")
	var bag: = Palette.c("sand")
	var bag2: = Palette.c("sand_dark")
	var wood: = Palette.c("wood")
	var c_hi: = Palette.c("concrete_light")
	var c_mid: = Palette.c("concrete")
	var c_lo: = Palette.c("concrete_dark")
	var shade: = Palette.c("rock_deep")
	for cell: Vector2i in fc:
		var f: Facility = fc[cell]
		if gw.vision != null and not gw.vision.fac_shown(f):
			continue
		var o: = Vector2(cell * GameWorld.CELL)
		if f.kind == Facility.Kind.TRENCH_H:
			var m: int = 0
			for i in 8:
				var q: Vector2i = cell + N8[i]
				if fc.has(q) and (fc[q] as Facility).kind == Facility.Kind.TRENCH_H:
					m |= 1 << i
			draw_rect(Rect2(o, Vector2(4, 4)), rim)
			draw_rect(Rect2(o + Vector2(1, 1), Vector2(2, 2)), pit)
			if m & 1:
				draw_rect(Rect2(o + Vector2(1, 0), Vector2(2, 1)), pit)
			if m & 2:
				draw_rect(Rect2(o + Vector2(3, 1), Vector2(1, 2)), pit)
			if m & 4:
				draw_rect(Rect2(o + Vector2(1, 3), Vector2(2, 1)), pit)
			if m & 8:
				draw_rect(Rect2(o + Vector2(0, 1), Vector2(1, 2)), pit)
			if m & 16 and not (m & 1) and not (m & 2):
				draw_rect(Rect2(o + Vector2(3, 0), Vector2(1, 1)), pit)
			if m & 32 and not (m & 2) and not (m & 4):
				draw_rect(Rect2(o + Vector2(3, 3), Vector2(1, 1)), pit)
			if m & 64 and not (m & 4) and not (m & 8):
				draw_rect(Rect2(o + Vector2(0, 3), Vector2(1, 1)), pit)
			if m & 128 and not (m & 8) and not (m & 1):
				draw_rect(Rect2(o, Vector2(1, 1)), pit)

			var h: int = Hash32.h2(cell.x, cell.y, 31)
			if not (m & 1):
				draw_rect(Rect2(o + Vector2(0, -1), Vector2(4, 1)), bag if h % 2 == 0 else bag2)
				draw_rect(Rect2(o + Vector2(1 + h % 2, -1), Vector2(1, 1)), bag2)
			if not (m & 4):
				draw_rect(Rect2(o + Vector2(0, 4), Vector2(4, 1)), earth)
			if h % 5 == 0:
				draw_rect(Rect2(o + Vector2(1, 1), Vector2(1, 1)), wood)
		else:
			var hp: float = float(f.cell_hp.get(cell, Military.TEETH_HP))
			var up: float = -1.0 if (cell.x + cell.y) % 2 == 1 else 0.0
			var p: Vector2 = o + Vector2(0, up)
			draw_rect(Rect2(p + Vector2(2, 3), Vector2(2, 1)), shade)
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(1, 1)), c_hi)
			draw_rect(Rect2(p + Vector2(0, 2), Vector2(1, 1)), c_hi)
			draw_rect(Rect2(p + Vector2(1, 2), Vector2(1, 1)), c_mid)
			draw_rect(Rect2(p + Vector2(2, 2), Vector2(1, 1)), c_lo)
			if hp < Military.TEETH_HP * 0.5:
				draw_rect(Rect2(p + Vector2(1, 1), Vector2(1, 1)), c_lo)
