extends Control





const Hub = preload("res://game/strike_hub.gd")

var main: Node
var _tex: Dictionary = {}


func setup(m: Node) -> void :
	main = m
	name = "StrikeMarks"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func tick() -> void :
	var hub = main.strike
	var gw: GameWorld = main.world
	var want: bool = hub.active or not hub.pending.is_empty() or (gw != null and gw.strike_net != null and gw.strike_net.get("pending") is Array and not (gw.strike_net.get("pending") as Array).is_empty())
	if visible != want:
		visible = want
	if want:
		queue_redraw()


func _icon(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = UiKit.tex(n)
	return _tex[n]


func _draw() -> void :
	var hub = main.strike
	var cam: MapCamera = main.cam
	var gw: GameWorld = main.world
	if cam == null or gw == null:
		return
	var font: Font = UiKit.f_black if UiKit.f_black != null else ThemeDB.fallback_font
	if hub.active:
		for w: String in hub.plans:
			if w == hub.cur:
				continue
			for t: Dictionary in hub.plans[w]:
				_mark(cam.world_to_screen(t["pos"]), w, int(t["n"]), font, true, "")
		for t2: Dictionary in main._plan_targets():
			_mark(cam.world_to_screen(t2["pos"]) + Vector2(-15, -15), hub.cur, int(t2.get("n", 1)), font, false, "")
	if hub.active and hub.cur == "art" and gw.navy != null:
		_art_rings(cam, gw)
	var marks: Array = hub.pending_marks(gw)
	if gw.strike_net != null and gw.player != null:
		marks.append_array(gw.strike_net.call("pending_marks", gw, gw.player.id))
	for e: Array in marks:
		for t3: Dictionary in e[1]:
			_mark(cam.world_to_screen(t3["pos"]), String(e[0]), int(t3["n"]), font, true, "%d" % int(ceil(float(e[2]))))




func _mark(sp: Vector2, w: String, n: int, font: Font, full: bool, cd: String) -> void :
	if sp.x < -30.0 or sp.y < -30.0 or sp.x > size.x + 30.0 or sp.y > size.y + 30.0:
		return
	var col: Color = Hub.colour(w)
	var r: float = 12.0 if full else 10.0
	draw_circle(sp, r + 2.0, UiKit.OUTLINE)
	draw_circle(sp, r, Color(0.08, 0.06, 0.04, 0.88))
	draw_arc(sp, r - 1.0, 0.0, TAU, 28, col, 3.0 if full else 2.5, true)
	var tx: Texture2D = _icon(Hub.icon(w))
	if tx != null:
		var s: float = 16.0 if full else 14.0
		draw_texture_rect(tx, Rect2(sp - Vector2(s, s) * 0.5, Vector2(s, s)), false)
	if full:
		draw_line(sp + Vector2( - r - 5.0, 0), sp + Vector2( - r - 1.0, 0), col, 2.0)
		draw_line(sp + Vector2(r + 1.0, 0), sp + Vector2(r + 5.0, 0), col, 2.0)
	var t: String = cd if cd != "" else ("×%d" % n if n > 1 else "")
	if t != "" and font != null:
		var fs: int = 10
		var tw: float = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p: Vector2 = sp + Vector2( - tw * 0.5, r + 13.0)
		draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, UiKit.OUTLINE)
		draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.lightened(0.25) if cd == "" else UiKit.GOLD)





func _art_rings(cam: MapCamera, gw: GameWorld) -> void :
	var z: float = cam.zoom.x
	var col: Color = Hub.colour("art")
	var me: int = gw.player.id if gw.player != null else -1
	var own: Array[Ship] = []
	for s: Ship in gw.navy.ships:
		if s.c == me and s.alive() and s.has_mod("art"):
			own.append(s)
	for s2: Ship in own:
		var c: Vector2 = cam.world_to_screen(s2.pos)
		var a: float = 0.8 if int(s2.ammo.get("art", 0)) > 0 else 0.3
		var r: float = NavyArt.RANGE * z
		var segs: int = clampi(int(r / 6.0), 24, 160)
		for i in segs:
			if i % 2 == 0:
				draw_arc(c, r, TAU * float(i) / float(segs), TAU * float(i + 1) / float(segs), 3, Color(UiKit.OUTLINE, 0.55 * a), 4.5, true)
				draw_arc(c, r, TAU * float(i) / float(segs), TAU * float(i + 1) / float(segs), 3, Color(col, a), 2.5, true)
		draw_arc(c, NavyArt.MIN_R * z, 0.0, TAU, 32, Color(col, a * 0.45), 1.0, true)
		draw_circle(c, 3.0, Color(col, a))
	for t: Dictionary in main._plan_targets():
		var p: Vector2 = t["pos"]
		var best: Ship = null
		var bd: float = INF
		for s3: Ship in own:
			var d: float = s3.pos.distance_to(p)
			if d < bd and d >= NavyArt.MIN_R:
				bd = d
				best = s3
		var ok: bool = best != null and bd <= NavyArt.RANGE
		var cc: Color = col if ok else UiKit.RED
		var sp: float = NavyArt.spread_at(bd if best != null else 0.0) * z
		var c2: Vector2 = cam.world_to_screen(p)
		draw_circle(c2, sp, Color(cc, 0.14))
		draw_arc(c2, sp, 0.0, TAU, 40, Color(cc, 0.9), 1.5, true)
		if best != null and ok:
			var h: float = clampf(bd * 0.14, 40.0, 140.0)
			var pts: = PackedVector2Array()
			for k in 17:
				var u: float = float(k) / 16.0
				pts.append(cam.world_to_screen(best.pos.lerp(p, u) + Vector2(0, - h * 4.0 * u * (1.0 - u))))
			for k2 in 16:
				if k2 % 2 == 0:
					draw_line(pts[k2], pts[k2 + 1], Color(UiKit.OUTLINE, 0.5), 3.5, true)
					draw_line(pts[k2], pts[k2 + 1], Color(cc, 0.9), 2.0, true)
