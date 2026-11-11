class_name OpsLayer
extends Node2D







const PK = preload("res://ui/ui24/path_kit.gd")
const MD = preload("res://ui/ui24/map_declutter.gd")
const AGroups = preload("res://game/army_groups.gd")
const AKit = preload("res://ui/ui24/arm_kit.gd")

var gw: GameWorld
var _t: float = 0.0


static var pennant_fids: Dictionary = {}


static func make(world: GameWorld) -> OpsLayer:
	var l: = OpsLayer.new()
	l.name = "Ops"
	l.gw = world
	l.z_index = 7
	return l


func _process(delta: float) -> void :
	_t += delta
	if gw == null or gw.ops == null:
		return
	var o: Operations = gw.ops
	if not o.list.is_empty() or not o.zones.is_empty() or not o.preview_arrow.is_empty() or not o.preview_order.is_empty() or _had:
		queue_redraw()
	_had = not o.list.is_empty() or not o.zones.is_empty() or not o.preview_arrow.is_empty() or not o.preview_order.is_empty()


var _had: bool = false


func _k() -> float:
	return 1.0 / maxf(0.05, gw.camera.zoom.x) if gw.camera != null else 1.0


func _draw() -> void :
	MD.begin("ops")
	if gw == null or gw.ops == null or gw.camera == null:
		return
	var o: Operations = gw.ops
	var k: float = _k()
	var pid: int = gw.player.id if gw.player != null else -1
	for z: Dictionary in o.zones:
		_zone(z, k)
	var bun: Dictionary = _bundles(o, pid)
	for pass_i in 2:
		for f: Facility in o.list:
			var op: Dictionary = o.list[f]
			var c: Country = gw.country_by_id(int(op["c"]))
			if c == null:
				continue
			var own: bool = int(op["c"]) == pid or (gw.vision != null and gw.vision.friend(int(op["c"])))
			if op.has("fp") and int(op["kind"]) != Operations.Kind.RETREAT and (own or int(op["kind"]) == Operations.Kind.DEFEND):
				continue
			var bf: Array = bun.get(f, [])
			var follower: bool = not bf.is_empty() and (bf[0] as PackedVector2Array).size() >= 2
			if own and not op.has("fp"):
				if follower != (pass_i == 0):
					continue
			elif pass_i == 0:
				continue
			if own and op.has("fp"):
				_fp_retreat(op, c, k)
			elif own:
				_op_arrow(op, c, k, bf[0] if follower else PackedVector2Array(), int(bf[1]) if not bf.is_empty() else 1)
			elif gw.vision == null or gw.vision.sees(op["front"]):
				_enemy_arrow(op, c, k)
	if not o.preview_arrow.is_empty():
		_preview_arrow(o, k)
	if not o.preview_order.is_empty():
		_preview_order(o, k)







func _bundles(o: Operations, pid: int) -> Dictionary:
	var groups: Dictionary = {}
	for f: Facility in o.list:
		var op: Dictionary = o.list[f]
		if int(op["c"]) != pid or op.has("fp") or int(op["kind"]) == Operations.Kind.RETREAT:
			continue
		var tg: Vector2 = op["target"]
		var key: String = "%d:%d:%d" % [int(op["kind"]), floori(tg.x / 160.0), floori(tg.y / 160.0)]
		var g: Array = groups.get(key, [])
		g.append(f)
		groups[key] = g
	var out: Dictionary = {}
	for key2: String in groups:
		var g2: Array = groups[key2]
		if g2.size() < 2:
			continue
		var lead: Facility = null
		var bd: float = INF
		for f2: Facility in g2:
			var op2: Dictionary = o.list[f2]
			var d: float = (op2["front"] as Vector2).distance_to(op2["target"])
			if d < bd:
				bd = d
				lead = f2
		var lr: PackedVector2Array = _rest(o.list[lead])
		for f3: Facility in g2:
			out[f3] = [PackedVector2Array() if f3 == lead else lr, g2.size()]
	return out



static func _rest(op: Dictionary) -> PackedVector2Array:
	var path: PackedVector2Array = op["path"]
	if path.size() < 2:
		path = PackedVector2Array([op["from"], op["target"]])
	var front: Vector2 = op["front"]
	var cut: int = _nearest_idx(path, front)
	var rest: = PackedVector2Array([front])
	for i in range(cut + 1, path.size()):
		rest.append(path[i])
	return rest


static func _closest_on(path: PackedVector2Array, p: Vector2) -> Vector2:
	var best: Vector2 = path[0]
	var bd: float = INF
	for i in range(1, path.size()):
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, path[i - 1], path[i])
		var d: float = q.distance_squared_to(p)
		if d < bd:
			bd = d
			best = q
	return best


func _op_arrow(op: Dictionary, c: Country, k: float, lead_rest: PackedVector2Array = PackedVector2Array(), badge: int = 1) -> void :
	var kind: int = int(op["kind"])
	var path: PackedVector2Array = op["path"]
	if path.size() < 2:
		path = PackedVector2Array([op["from"], op["target"]])
	var col: Color = c.color_light


	var quiet: bool = false
	var fq: Variant = op.get("f")
	if fq is Facility and (fq as Facility).group_id >= 0 and gw.player != null and int(op["c"]) == gw.player.id:
		var gq: Dictionary = AGroups.by_id(gw, gw.player.id, (fq as Facility).group_id)
		if not gq.is_empty():
			col = AKit.color(int(gq["color"])).lightened(0.12)
			quiet = MD.sel_gid >= 0 and MD.sel_gid != (fq as Facility).group_id
	if kind == Operations.Kind.RETREAT:
		col = col.lerp(Palette.c("ui_steel_light"), 0.55)


	if (fq is Facility and gw.rail != null and gw.rail.troops != null and gw.rail.troops.busy(fq as Facility)) or int(gw.map_mode) == GameWorld.MapMode.LOGISTICS:
		quiet = true
	if quiet:
		col.a = 0.55
	var front: Vector2 = op["front"]

	var cut: int = _nearest_idx(path, front)
	var done: = PackedVector2Array()
	for i in range(0, cut + 1):
		done.append(path[i])
	done.append(front)
	var rest: = PackedVector2Array([front])
	for i in range(cut + 1, path.size()):
		rest.append(path[i])

	var stub: bool = lead_rest.size() >= 2
	if stub:
		rest = PackedVector2Array([front, _closest_on(lead_rest, front)])


	var on_train: bool = fq is Facility and gw.rail != null and gw.rail.troops != null and gw.rail.troops.riding(fq as Facility)
	if on_train:
		var s2p: Vector2 = gw.rail.troops.alight_pos(fq as Facility)
		if s2p.is_finite():
			rest = PackedVector2Array([s2p])
			for i in range(_nearest_idx(path, s2p) + 1, path.size()):
				rest.append(path[i])
			if rest.size() < 2:
				rest.append(op["target"])
	var w: float = (4.5 if gw.camera.zoom.x >= 1.0 else 3.5) * k * (0.6 if stub else 1.0) * (0.6 if quiet else 1.0)
	var dim: = Color(col.r, col.g, col.b, 0.35)
	if gw.selected_facility() == op.get("f"):
		_poly(done, dim, w * 0.7, k, false)
	_poly(rest, col, w, k, true)
	if not stub:
		_chevrons(rest, col.lightened(0.5), k, kind == Operations.Kind.RETREAT)
	var sm: PackedVector2Array = PK.smooth(rest, 9.0 * k)
	var end: Vector2 = sm[sm.size() - 1]
	var dir: Vector2 = (end - sm[maxi(0, sm.size() - 2)]).normalized() if sm.size() >= 2 else Vector2.RIGHT
	if dir == Vector2.ZERO:
		dir = (end - front).normalized() if end != front else Vector2.RIGHT
	if stub:
		draw_circle(end, 3.5 * k, Palette.c("ui_rubber"))
		draw_circle(end, 2.2 * k, col)
	elif kind == Operations.Kind.DEFEND:
		_defence_line(end, dir, col, k)
	else:
		_head(end, dir, col, k * 0.75)
		if badge > 1:
			_label(end - dir * 26.0 * k + Vector2(0, -12.0 * k), "×%d" % badge, col, k, -1.0, 1.0, 10)
	if (op.get("wp", Vector2.INF) as Vector2).is_finite():
		var wp: Vector2 = op["wp"]
		draw_circle(wp, 4.0 * k, Palette.c("ui_rubber"))
		draw_circle(wp, 2.5 * k, col)
	if not on_train:
		_front_marker(front, _dir_at(path, cut), col, k)


	var f: Facility = op["f"]
	var sel: bool = gw.selected_facility() == f
	if not sel and gw.camera.zoom.x < LABEL_MIN_ZOOM:
		return
	if not sel and pennant_fids.has(f.id):
		return
	var txt: String
	if sel:
		txt = "№%d %s · %s" % [f.army_no, Loc.t(String(Operations.KIND_SHORT[kind])), Loc.msg(op["state"])]
		if float(op["losses"]) >= 0.15:
			txt += Loc.t(" · потери %d%%") % roundi(float(op["losses"]) * 100.0)
	else:
		txt = "№%d %s" % [f.army_no, Loc.t(String(Operations.KIND_SHORT[kind]))]
		var tag: String = _short_state(op["state"])
		if tag != "":
			txt += (" " if tag.ends_with("%") else " · ") + tag
	var start: Vector2 = f.center_px()
	var away: Vector2 = start - front
	away = away.normalized() if away.length() > 1.0 else Vector2.DOWN
	_label(start + away * 20.0 * k + Vector2(0, 6.0 * k), txt, col, k, float(op["progress"]), 1.0 if sel else 0.75, 9)




func _fp_retreat(op: Dictionary, c: Country, k: float) -> void :
	var front: Vector2 = op["front"]
	var to: Vector2 = op["target"]
	var path: PackedVector2Array = op["path"]
	if path.size() >= 2:
		to = path[path.size() - 1]
	var dir: Vector2 = (to - front).normalized() if to.distance_to(front) > 1.0 else Vector2.DOWN
	var L: float = minf(40.0 * k, front.distance_to(to))
	var col: Color = c.color_light.lerp(Palette.c("ui_steel_light"), 0.55)
	col.a = 0.7
	var b: Vector2 = front + dir * L
	draw_line(front, b, Palette.c("ui_rubber"), 3.5 * k)
	draw_line(front, b, col, 2.0 * k)
	var n: = Vector2( - dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([b + dir * 5.0 * k, b - dir * 2.0 * k + n * 4.0 * k, b - dir * 2.0 * k - n * 4.0 * k]), col)


func _enemy_arrow(op: Dictionary, c: Country, k: float) -> void :
	var path: PackedVector2Array = op["path"]
	var front: Vector2 = op["front"]
	var dir: Vector2 = _dir_at(path, _nearest_idx(path, front)) if path.size() >= 2 else Vector2.RIGHT
	if int(op["kind"]) == Operations.Kind.RETREAT:
		dir = ((op["target"] as Vector2) - front).normalized()
	var col: Color = c.color_light
	var a: Vector2 = front - dir * 50.0 * k
	var b: Vector2 = front + dir * 45.0 * k
	_poly(PackedVector2Array([a, b]), col, 5.0 * k, k, true)
	_head(b, dir, col, k)
	_front_marker(front, dir, col, k)


func _defence_line(p: Vector2, dir: Vector2, col: Color, k: float) -> void :
	var side: = Vector2( - dir.y, dir.x)
	var half: float = 34.0
	var a: Vector2 = p - side * half
	var b: Vector2 = p + side * half
	draw_line(a, b, Palette.c("ui_rubber"), 6.0 * k)
	draw_line(a, b, col, 3.5 * k)

	var n: int = 6
	for i in n:
		var q: Vector2 = a.lerp(b, (float(i) + 0.5) / float(n))
		var tri: = PackedVector2Array([q - side * 3.0 * k, q + side * 3.0 * k, q + dir * 5.0 * k])
		draw_colored_polygon(tri, col)


func _head(p: Vector2, dir: Vector2, col: Color, k: float) -> void :
	var n: = Vector2( - dir.y, dir.x)
	var tip: Vector2 = p + dir * 6.0 * k
	var tri: = PackedVector2Array([tip, tip - dir * 15.0 * k + n * 9.0 * k, tip - dir * 15.0 * k - n * 9.0 * k])
	var out: = PackedVector2Array([tip + dir * 2.0 * k, tip - dir * 16.5 * k + n * 11.0 * k, tip - dir * 16.5 * k - n * 11.0 * k])
	draw_colored_polygon(out, Palette.c("ui_rubber"))
	draw_colored_polygon(tri, col)


func _front_marker(p: Vector2, dir: Vector2, col: Color, k: float) -> void :
	var side: = Vector2( - dir.y, dir.x)
	var pulse: float = 1.0 + 0.15 * sin(_t * 5.0)
	draw_line(p - side * 9.0 * k * pulse, p + side * 9.0 * k * pulse, Palette.c("ui_rubber"), 5.0 * k)
	draw_line(p - side * 8.0 * k * pulse, p + side * 8.0 * k * pulse, col.lightened(0.3), 2.5 * k)




func _chevrons(path: PackedVector2Array, col: Color, k: float, slow: bool) -> void :

	PK.flow(self, PK.smooth(path, 9.0 * k), col, 4.0, _t * (0.55 if slow else 1.0), k, 0.9, 14.0 * k)


func _poly(pts: PackedVector2Array, col: Color, w: float, k: float, outline: bool) -> void :
	if pts.size() < 2:
		return
	var sp: PackedVector2Array = PK.smooth(pts, 9.0 * k)
	if outline:
		draw_polyline(sp, Color(Palette.c("ui_rubber"), col.a), w + 2.5 * k, true)
	draw_polyline(sp, col, w, true)
	if w >= 3.0 * k:
		draw_polyline(sp, Color(col.lightened(0.45), 0.5 * col.a), w * 0.34, true)


const LABEL_MIN_ZOOM: float = 0.6




static func _short_state(st: Variant) -> String:
	if not Loc.is_msg(st):
		return _short_legacy(String(st))
	var pc: int = Operations.state_pct(st)
	match Operations.state_kind(st):
		"refill":
			return ("%d%%" % pc) if pc >= 0 else ""
		"assault":
			return Loc.t("штурм")
		"fight", "fight_line":
			return Loc.t("бой")
		"fire":
			return Loc.t("огонь")
		"wait_fire":
			return Loc.t("ждём огня")
		"gather":
			return Loc.t("сбор")
		"dug":
			return Loc.t("закрепились")
		"hold":
			return Loc.t("рубеж")
		"march":
			return Loc.t("марш")
		"losses":
			return (Loc.t("потери %d%%") % pc) if pc >= 0 else ""
	return ""


static func _short_legacy(st: String) -> String:
	var pct: int = st.find("%")
	if st.begins_with("у казарм"):
		var sp: int = st.rfind(" ", pct)
		return st.substr(sp + 1, pct - sp) if pct > 0 and sp >= 0 else ""
	if st.begins_with("штурм"):
		return Loc.t("штурм")
	if st.begins_with("бой"):
		return Loc.t("бой")
	if st.begins_with("огонь"):
		return Loc.t("огонь")
	if st.find("ждём огня") >= 0:
		return Loc.t("ждём огня")
	if st.begins_with("сбор"):
		return Loc.t("сбор")
	if st.begins_with("закреп"):
		return Loc.t("закрепились")
	if st.begins_with("держим"):
		return Loc.t("рубеж")
	if st.begins_with("выдвиж") or st.begins_with("перебеж"):
		return Loc.t("марш")
	if st.begins_with("потери") and pct > 0:
		return Loc.t("потери %s") % st.substr(7, pct - 6)
	return ""


func _label(p: Vector2, txt: String, col: Color, k: float, progress: float = -1.0, alpha: float = 1.0, fs: int = 9) -> void :
	var font: Font = UiKit.f_bold if UiKit.f_bold != null else ThemeDB.fallback_font
	var sz: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var r: = Rect2(Vector2( - sz.x * 0.5 - 3.0, - sz.y - 2.0), Vector2(sz.x + 6.0, sz.y + (6.0 if progress >= 0.0 else 3.0)))

	if gw.camera != null:
		var cam: MapCamera = gw.camera
		var vs: Vector2 = cam.view_size()
		var mt: float = float(cam.get("margin_top_px")) if cam.get("margin_top_px") != null else 0.0
		var mb: float = float(cam.get("margin_bottom_px")) if cam.get("margin_bottom_px") != null else 0.0
		var sp: Vector2 = cam.world_to_screen(p)
		var lo: = Vector2(4.0 - r.position.x, mt + 4.0 - r.position.y)
		var hi: = Vector2(vs.x - 4.0 - r.end.x, vs.y - mb - 4.0 - r.end.y)
		if hi.x >= lo.x:
			sp.x = clampf(sp.x, lo.x, hi.x)
		if hi.y >= lo.y:
			sp.y = clampf(sp.y, lo.y, hi.y)
		p = cam.screen_to_world(sp)
	if MD.rec and gw.camera != null:
		MD.note("ops", Rect2(gw.camera.world_to_screen(p) + r.position * k * gw.camera.zoom.x, r.size * k * gw.camera.zoom.x))
	draw_set_transform(p, 0.0, Vector2(k, k))
	draw_rect(r, Color(0.05, 0.06, 0.05, 0.6 * alpha))
	draw_rect(r, Color(col, 0.7 * alpha), false, 1.0)
	draw_string(font, Vector2( - sz.x * 0.5, -4.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Palette.c("white"), 0.95 * alpha))
	if progress >= 0.0:
		var bar: = Rect2(r.position + Vector2(3.0, r.size.y - 4.0), Vector2(r.size.x - 6.0, 2.0))
		draw_rect(bar, Color(0, 0, 0, 0.5 * alpha))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(progress, 0.0, 1.0), 2.0)), Color(col, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _nearest_idx(path: PackedVector2Array, p: Vector2) -> int:
	var best: int = 0
	var bd: float = INF
	for i in path.size():
		var d: float = path[i].distance_squared_to(p)
		if d < bd:
			bd = d
			best = i
	return best


static func _dir_at(path: PackedVector2Array, i: int) -> Vector2:
	if path.size() < 2:
		return Vector2.RIGHT
	var a: int = clampi(i, 0, path.size() - 2)
	var d: Vector2 = path[a + 1] - path[a]
	return d.normalized() if d.length() > 0.001 else Vector2.RIGHT




func _zone(z: Dictionary, k: float) -> void :
	var p: Vector2 = z["pos"]
	var c: int = int(z["c"])
	if gw.player != null and c != gw.player.id and gw.vision != null and not gw.vision.shows(c, p):
		return
	var r: float = float(z["r"])
	var now: float = gw.game_time
	match int(z["k"]):
		Operations.Order.SMOKE:
			var life: float = clampf((float(z["until"]) - now) / 3.0, 0.0, 1.0)
			_ellipse(p, r, Color(Palette.c("smoke_light"), 0.12 * life), true, k)
			_ellipse(p, r, Color(Palette.c("smoke"), 0.35 * life), false, k)
		Operations.Order.EW:
			var life2: float = clampf((float(z["until"]) - now) / 3.0, 0.0, 1.0) * clampf((now - float(z["t0"])) / 0.6, 0.0, 1.0)
			var cy: Color = Palette.c("intercept_cyan")
			_ellipse(p, r, Color(cy, 0.07 * life2), true, k)

			_ellipse(p, r, Color(Palette.c("ui_rubber"), 0.5 * life2), false, k, 3.5)
			_ellipse(p, r, Color(cy, 0.9 * life2), false, k, 2.0)
			_ellipse(p + Vector2(0, - r * 0.18), r * 0.78, Color(cy, 0.35 * life2), false, k)
			_ellipse(p + Vector2(0, - r * 0.34), r * 0.48, Color(cy, 0.3 * life2), false, k)
			for j in 3:
				var a0: float = _t * 1.3 + float(j) * TAU / 3.0
				_arc_e(p, r, a0, 0.5, Color(Palette.c("white"), 0.7 * life2), k)
			if fmod(_t * 3.0, 1.0) < 0.5:
				var q: Vector2 = p + Vector2.from_angle(_t * 7.3) * Vector2(1.0, 0.72) * r * 0.9
				draw_circle(q, 1.5 * k, Color(Palette.c("white"), 0.8 * life2))
		Operations.Order.ARTY:
			var red: Color = Palette.c("alert_red")
			var warn: bool = now < float(z["t0"]) + Operations.WARN_T
			var a1: float = (0.65 + 0.35 * sin(_t * 10.0)) if warn else 0.9
			_ellipse(p, r, Color(red, 0.07 * a1), true, k)
			_target_ring(p, r, k, Palette.c("fire_yellow") if warn else red, a1)





func _target_ring(p: Vector2, r: float, k: float, accent: Color, a: float) -> void :
	var dark: = Color(Palette.c("outline"), 0.85 * a)
	var white: = Color(Palette.c("white"), a)
	_ellipse(p, r, dark, false, k, 5.0)
	_ellipse(p, r, Color(accent, a), false, k, 2.0)
	_dashed_ellipse(p, r, white, k, 2.0)
	var ri: float = maxf(r - 7.0 * k, r * 0.6)
	_ellipse(p, ri, Color(Palette.c("outline"), 0.6 * a), false, k, 3.0)
	_ellipse(p, ri, Color(white, 0.8 * a), false, k, 1.0)
	for d: Vector2 in [Vector2(1, 0), Vector2(0, 1)]:
		draw_line(p - d * 10.0 * k, p + d * 10.0 * k, dark, 4.0 * k)
	for d2: Vector2 in [Vector2(1, 0), Vector2(0, 1)]:
		draw_line(p - d2 * 9.0 * k, p - d2 * 2.5 * k, white, 2.0 * k)
		draw_line(p + d2 * 2.5 * k, p + d2 * 9.0 * k, white, 2.0 * k)
	draw_rect(Rect2(p - Vector2(1, 1) * k, Vector2(2, 2) * k), Color(accent, a))


func _ellipse(p: Vector2, r: float, col: Color, fill: bool, k: float, w: float = 1.0) -> void :
	draw_set_transform(p, 0.0, Vector2(1.0, 0.72))
	if fill:
		draw_circle(Vector2.ZERO, r, col)
	else:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, col, w * k / 0.86)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _arc_e(p: Vector2, r: float, a0: float, span: float, col: Color, k: float) -> void :
	draw_set_transform(p, 0.0, Vector2(1.0, 0.72))
	draw_arc(Vector2.ZERO, r, a0, a0 + span, 12, col, 2.0 * k)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _dashed_ellipse(p: Vector2, r: float, col: Color, k: float, w: float = 1.5) -> void :
	draw_set_transform(p, 0.0, Vector2(1.0, 0.72))
	var n: int = 24
	var rot: float = _t * 0.6
	for i in n:
		var a: float = rot + float(i) / float(n) * TAU
		draw_arc(Vector2.ZERO, r, a, a + TAU / float(n) * 0.55, 4, col, w * k)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)




func _preview_arrow(o: Operations, k: float) -> void :
	var pa: Dictionary = o.preview_arrow
	var f: Facility = pa.get("f")
	if f == null:
		return
	var to: Vector2 = pa.get("to", Vector2.INF)
	if not to.is_finite():
		return
	var res: Dictionary = o.preview(f, to, int(pa.get("kind", -1)), pa.get("wp", Vector2.INF))
	var col: Color = Palette.c(String(res["colour"]))
	var path: PackedVector2Array = res["path"]
	var ok: bool = bool(res["ok"])
	col.a = 0.9 if ok else 0.7
	_poly(path, col, 4.0 * k, k, true)
	if ok:
		_chevrons(path, col.lightened(0.5), k, false)
	var end: Vector2 = path[path.size() - 1] if not path.is_empty() else to
	var dir: Vector2 = _dir_at(path, path.size() - 2)
	if ok and int(res["kind"]) == Operations.Kind.DEFEND:
		_defence_line(end, dir, col, k)
	elif ok:
		_head(end, dir, col, k)
	else:
		var x: float = 5.0 * k
		draw_line(to - Vector2(x, x), to + Vector2(x, x), Palette.c("alert_red"), 2.0 * k)
		draw_line(to - Vector2(x, - x), to + Vector2(x, - x), Palette.c("alert_red"), 2.0 * k)
	_label(to + Vector2(0, -18.0 * k), Loc.t(String(res["text"])), 
		col if ok else Palette.c("alert_red"), k)


func _preview_order(o: Operations, k: float) -> void :
	var po: Dictionary = o.preview_order
	var kind: int = int(po.get("kind", 0))
	var p: Vector2 = po.get("pos", Vector2.INF)
	if not p.is_finite() or gw.player == null:
		return
	var chk: Dictionary = o.order_check(gw.player.id, kind, p)
	var r: float = float(Operations.ORDERS[kind]["r"])
	var col: Color = Palette.c(["alert_red", "smoke_light", "intercept_cyan"][kind]) if bool(chk["ok"]) else Palette.c("ui_steel_mid")
	_ellipse(p, r, Color(col, 0.12), true, k)
	if kind == Operations.Order.ARTY and bool(chk["ok"]):
		_target_ring(p, r, k, col, 0.95)
	else:
		_ellipse(p, r, Color(Palette.c("ui_rubber"), 0.5), false, k, 3.5)
		_dashed_ellipse(p, r, Color(col, 0.95), k, 2.0)
	if kind == Operations.Order.ARTY and o.has_method("arty_anchor"):


		var an: Vector2 = o.arty_anchor(gw.player.id, p)
		var far: bool = bool(chk.get("too_far", false))
		var rc: Color = Palette.c("alert_red") if far else Color(Palette.c("intercept_cyan"), 0.55)
		if an.is_finite():
			for i9 in 48:
				var a9: float = _t * 0.2 + float(i9) / 48.0 * TAU
				draw_arc(an, Operations.ARTY_REACH, a9, a9 + TAU / 48.0 * 0.55, 4, Color(rc, 0.75 if far else 0.45), 2.0 * k)
			if far:
				draw_line(an, an + (p - an).limit_length(Operations.ARTY_REACH), Color(rc, 0.6), 1.5 * k)
		if far:
			_ellipse(p, r, Color(Palette.c("alert_red"), 0.22), true, k)
	var txt: String = Loc.t(String(Operations.ORDERS[kind]["name"])) if bool(chk["ok"]) else Loc.t(String(chk["why"]))
	_label(p + Vector2(0, - r * 0.72 - 6.0 * k), txt, col if bool(chk["ok"]) else Palette.c("alert_red"), k)
