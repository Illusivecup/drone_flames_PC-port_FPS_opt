class_name TrainLayer
extends Node2D



var rail: Rail
var _had: bool = false
const RV = preload("res://world/rail_view332.gd")


func _process(_delta: float) -> void :
	if rail == null:
		return
	var any: bool = not rail.trains.is_empty() or _works_on() or RV.busy(rail)
	if any or _had:
		queue_redraw()
	_had = any


func _draw() -> void :
	if rail == null or rail.gw.camera == null:
		return
	var gw: GameWorld = rail.gw
	var cam: MapCamera = gw.camera
	var half: Vector2 = cam.view_size() * 0.5 / cam.zoom.x
	var view: = Rect2(cam.position - half - Vector2(12, 12), half * 2.0 + Vector2(24, 24))
	var at: SpriteAtlas = gw.atlas11
	var ok: bool = at != null and at.has("rail_loco")
	var at0: SpriteAtlas = at
	var ok0: bool = ok
	for tr: Dictionary in rail.trains:
		var cars: PackedStringArray = tr["cars"]
		var sat: SpriteAtlas = ArchStyle.train_atlas(gw, int(tr.get("country", -1)))
		at = at0
		ok = ok0
		var s: float = tr["s"]
		for ci in range(cars.size() - 1, -1, -1):
			var d: float = s - float(ci) * Rail.CAR_GAP
			var p: Vector2 = rail.pos_at(tr, d)
			if not view.has_point(p) or (gw.vision != null and not gw.vision.shows(int(tr.get("country", -1)), p)):
				continue
			var dir: Vector2 = rail.pos_at(tr, d + 3.0) - rail.pos_at(tr, d - 3.0)
			var fr: int = posmod(roundi(rad_to_deg(dir.angle()) / 22.5), 16)
			var n: String = cars[ci]
			var n2: String = "r2_" + n.trim_prefix("rail_")
			if sat != null and sat.has(n):
				at = sat
				ok = true
			elif RV.atlas().has(n2):
				at = RV.atlas()
				n = n2
				ok = true
			elif not at0.has(n) and RV.atlas().has(n):
				at = RV.atlas()
				ok = true
			elif at != at0:
				at = at0
				ok = ok0
			if ok and at.has(n):
				var inf: Dictionary = at.info(n)
				var o: = Vector2(float(inf["ax"]), float(inf["ay"]))
				var pr: Vector2 = p.round()
				if at.has(n + "_shadow"):
					draw_texture_rect_region(at.texture, Rect2(pr - o + Vector2(1, 1), Vector2(float(inf["w"]), float(inf["h"]))), at.rect(n + "_shadow", fr))
				draw_texture_rect_region(at.texture, Rect2(pr - o, Vector2(float(inf["w"]), float(inf["h"]))), at.rect(n, fr))
				if n == "r2_loco" and at.has("r2_loco_stripe"):
					var oc: Country = gw.country_by_id(int(tr.get("country", -1)))
					if oc != null:
						draw_texture_rect_region(at.texture, Rect2(pr - o, Vector2(float(inf["w"]), float(inf["h"]))), at.rect("r2_loco_stripe", fr), oc.color)
			else:
				var c: Color = Palette.c("roof_green") if ci == 0 else Palette.c("brick")
				draw_set_transform(p, dir.angle())
				draw_rect(Rect2(-4, -1.5, 8, 3), c)
				draw_set_transform(Vector2.ZERO, 0.0)
	RV.station_works(self, rail, view, cam.zoom.x)
	RV.works(self, rail, view)
	RV.badges(self, rail, view, cam)
	RV.cut_labels(self, rail, view, cam)



func _works_on() -> bool:
	for e: Dictionary in rail.edges:
		if float(e.get("bt", 0.0)) > 0.0 and not bool(e["dead"]):
			return true
	return false


func _exit_tree() -> void :
	Sfx.loop("train", "", false)
