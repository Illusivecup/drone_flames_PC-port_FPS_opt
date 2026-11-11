class_name VfxGlow
extends Node2D



var vfx: Vfx
var _tex: Texture2D
var _drawn: bool = false


func _ready() -> void :
	var m: = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m

	var g: = Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.55, 0.8])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.28), Color(1, 1, 1, 0.0)])
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.width = 32
	gt.height = 32
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	_tex = gt
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void :
	var gw: GameWorld = vfx.gw if vfx != null else null
	if gw == null or gw.night == null:
		return
	var on: bool = gw.night.factor > 0.02 and not vfx.columns.is_empty()
	if on or _drawn:
		queue_redraw()
	_drawn = on


func _draw() -> void :
	var gw: GameWorld = vfx.gw
	if gw == null or gw.camera == null or gw.night == null:
		return
	var a: float = gw.night.factor
	if a <= 0.02:
		return
	var z: float = gw.camera.zoom.x
	var zb: float = clampf(0.8 / z, 1.0, 3.0)
	var view: Rect2 = vfx.air.view_rect()
	var t: float = gw.game_time
	for col: Dictionary in vfx.columns:
		if float(col["burn"]) <= t:
			continue
		var p: Vector2 = col["p"]
		var vis: float = vfx.air.column_vis(col)
		if vis <= 0.0:
			continue
		var r: float = (14.0 + 16.0 * float(col["pow"])) * zb
		if not view.grow(r).has_point(p):
			continue
		var fl: float = 0.85 + 0.15 * sin(FxLayer.vt * 7.0 + p.x * 0.1)
		if int(col.get("fid", -1)) == VfxTurret.WRECK_FID:

			var age: float = t - float(col["t0"])
			var fp: Vector2 = (p + Vector2(0, 6)).round()
			if age < 3.0:
				var r2: float = roundf(r * 0.6 * fl / 2.0) * 2.0
				draw_texture_rect(_tex, Rect2(fp - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(1.0, 0.6, 0.2, 0.15 * (1.0 - age / 3.0) * a * vis))
			var fs: float = 2.0 if fl > 0.93 else 1.0
			draw_rect(Rect2(fp - Vector2(fs, fs) * 0.5, Vector2(fs, fs)), Color(1.0, 0.7, 0.3, 0.8 * a * vis))
			continue
		var rr: float = roundf(r * fl / 4.0) * 4.0
		draw_texture_rect(_tex, Rect2(p - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color(1.0, 0.5, 0.16, 0.5 * a * vis))
		draw_texture_rect(_tex, Rect2(p - Vector2(rr, rr) * 0.4, Vector2(rr, rr) * 0.8), false, Color(1.0, 0.8, 0.4, 0.45 * a * vis))
