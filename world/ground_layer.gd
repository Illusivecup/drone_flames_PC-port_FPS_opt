class_name GroundLayer
extends Node2D


var gw: GameWorld
var decals: Array = []


func _draw() -> void :
	if gw == null:
		return
	for d: Array in decals:
		var n: String = d[0]
		var fa: SpriteAtlas = gw.fx_atlas_of(n)
		var info: Dictionary = fa.info(n)
		var pos: Vector2 = Vector2(d[1]) - Vector2(float(info["ax"]), float(info["ay"]))
		draw_texture_rect_region(fa.texture, Rect2(pos, Vector2(float(info["w"]), float(info["h"]))), fa.rect(n))
	var wa: SpriteAtlas = gw.atlas
	for b: Bridge in gw.bridges:
		if b.kind != Bridge.Kind.RIVER:
			continue
		for i in b.cells.size():
			var c: Vector2i = b.cells[i]
			var horiz: bool = b.dirs[i] == 0
			var v: int = b.view(i)
			var n: String = "bridge_h" if horiz else "bridge_v"
			if v == 1:
				n = "bridge_h_broken" if horiz else "bridge_v_broken"
			elif v == 2:
				n = "scaffold_h" if horiz else "scaffold_v"
			draw_texture_rect_region(wa.texture, Rect2(Vector2(c.x * 4, c.y * 4), Vector2(4, 4)), wa.rect(n))
