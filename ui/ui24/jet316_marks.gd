extends Control




const CAS_R: float = Air.CAS_R

var main: Node


func setup(m: Node) -> void :
	main = m
	name = "Jet316Marks"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func tick() -> void :
	var want: bool = bool(main.call("jet_plan_active"))
	if visible != want:
		visible = want
	if want:
		queue_redraw()


func _draw() -> void :
	var cam: MapCamera = main.cam
	if cam == null:
		return
	var st: Dictionary = main.call("jet_plan_state")
	if st.is_empty():
		return
	var z: float = cam.zoom.x
	var font: Font = UiKit.f_black if UiKit.f_black != null else ThemeDB.fallback_font
	var jet: Aircraft = st.get("jet") as Aircraft
	var red: = Color(0.95, 0.3, 0.22)
	var gold: = Color(1.0, 0.82, 0.3)
	if jet != null and float(st.get("fuel_r", 0.0)) > 0.0:
		var jc: Vector2 = cam.world_to_screen(jet.pos)
		_dash_ring(jc, float(st["fuel_r"]) * z, Color(0.55, 0.85, 1.0, 0.55))
		draw_circle(jc, 5.0, Color(0.55, 0.85, 1.0, 0.9))
	if bool(st.get("cas", false)):
		if bool(st.get("has", false)):
			var c: Vector2 = cam.world_to_screen(st["pts"][0])
			draw_circle(c, CAS_R * z, Color(1.0, 0.55, 0.15, 0.16))
			draw_arc(c, CAS_R * z, 0.0, TAU, 48, Color(1.0, 0.6, 0.2, 0.9), 2.0)
			_cross(c, gold)
		return
	var reach: float = float(st.get("reach", 0.0))
	var pts: Array = st.get("pts", [])
	var prev: Vector2 = cam.world_to_screen(jet.pos) if jet != null else Vector2.INF
	for i in pts.size():
		var s: Vector2 = cam.world_to_screen(pts[i])
		var bad: bool = i < (st.get("bad", []) as Array).size() and bool(st["bad"][i])
		var col: Color = Color(0.6, 0.6, 0.6) if bad else red
		if prev != Vector2.INF:
			draw_dashed_line(prev, s, Color(0, 0, 0, 0.5), 4.0, 7.0)
			draw_dashed_line(prev, s, Color(col, 0.95), 2.0, 7.0)
		prev = s
		if reach > 0.0:
			draw_arc(s, reach * z, 0.0, TAU, 64, Color(col, 0.65), 2.0)
		draw_circle(s, 13.0, Color(0.08, 0.06, 0.05, 0.85))
		draw_arc(s, 13.0, 0.0, TAU, 24, col, 2.0)
		var t: String = "%d" % (i + 1)
		var sz: Vector2 = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		draw_string_outline(font, s + Vector2( - sz.x * 0.5, 5.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color.BLACK)
		draw_string(font, s + Vector2( - sz.x * 0.5, 5.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gold if not bad else Color(0.8, 0.8, 0.8))


func _cross(c: Vector2, col: Color) -> void :
	draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), col, 2.0)
	draw_line(c + Vector2(0, -8), c + Vector2(0, 8), col, 2.0)


func _dash_ring(c: Vector2, r: float, col: Color) -> void :
	if r < 8.0 or r > 6000.0:
		return
	var n: int = clampi(int(r / 9.0), 24, 160)
	for i in n:
		if i % 2 == 1:
			continue
		draw_arc(c, r, TAU * i / n, TAU * (i + 1) / n, 3, col, 1.5)
