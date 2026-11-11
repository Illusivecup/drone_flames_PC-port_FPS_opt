class_name RouteOverlay
extends Node2D








const PK = preload("res://ui/ui24/path_kit.gd")
const MD = preload("res://ui/ui24/map_declutter.gd")
const Hub = preload("res://game/strike_hub.gd")

var gw: GameWorld
var main_node: Node
var _t: float = 0.0
var _had: bool = false
var ripples: Array = []
var plan_line: PackedVector2Array = PackedVector2Array()
var follow_line: PackedVector2Array = PackedVector2Array()
var dbg_dots: int = 0
var dbg_fights: int = 0
var dbg_army_us: int = 0

const DOT_Z0: float = 0.42
const DOT_Z1: float = 0.58
var _fx_t: float = -1.0
var _fx_z: float = -1.0
var _fx_w: = PackedVector3Array()


func ripple(world_p: Vector2, col: String = "amber") -> void :
	ripples.append([world_p, _t, col])


var _cam_sig: = Vector3.ZERO


func _process(delta: float) -> void :
	_t += delta
	for k in range(ripples.size() - 1, -1, -1):
		if _t - float(ripples[k][1]) > 0.7:
			ripples.remove_at(k)
	var busy: bool = not ripples.is_empty()
	if gw != null and gw.mil != null and main_node != null:
		busy = busy or bool(main_node.call("plan_active")) or main_node.call("follow_drone") != null or not gw.mil.missiles.is_empty() or not gw.mil.air.aircraft.is_empty()\
		or not gw.army.arrows.is_empty() or gw.selected_facility() != null or not gw.army.units.is_empty()\
		or (main_node.get("line_cells") is Array and not (main_node.get("line_cells") as Array).is_empty())
		if not busy:
			for d: Drone in gw.mil.drones:
				if d.airborne():
					busy = true
					break


	if gw != null and gw.camera != null:
		var cs: = Vector3(gw.camera.position.x, gw.camera.position.y, gw.camera.zoom.x)
		if cs != _cam_sig:
			_cam_sig = cs
			busy = true
		if not busy and gw.mil != null:
			for f: Facility in gw.mil.facilities:
				if f.moving:
					busy = true
					break
	if busy or _had:
		queue_redraw()
	_had = busy


func _draw() -> void :
	plan_line = PackedVector2Array()
	follow_line = PackedVector2Array()
	if gw == null or gw.camera == null or gw.mil == null or main_node == null:
		return
	var cam: MapCamera = gw.camera
	var st: Dictionary = main_node.call("plan_state")
	var pid: int = gw.player.id if gw.player != null else -1
	var sel: Object = main_node.call("follow_drone")
	var fd: Drone = sel as Drone
	var fm: Missile = sel as Missile



	MD.begin("trail")
	MD.begin("air")
	if cam.zoom.x >= MD.LOD_FAR:
		var lead: Dictionary = {}
		for od: Drone in gw.mil.drones:
			if od != fd and od.country_id == pid and od.airborne() and not od.route.is_empty():
				var tk: Vector2i = Vector2i((od.target / 64.0).round())
				var cur: Drone = lead.get(tk)


				if cur == null or (od.remaining_len() < cur.remaining_len() if od.kind == 1 else od.remaining_len() > cur.remaining_len()):
					lead[tk] = od
		for tk2: Vector2i in lead:
			var ld: Drone = lead[tk2] as Drone
			var wp0: PackedVector2Array = gw.mil.drone_preview(ld)
			if ld.kind == 1:
				wp0 = _cut_head(wp0, 12.0)
			var tl0: PackedVector2Array = _to_screen(wp0)
			_line(tl0, Color(Palette.c("ui_steel_light"), 0.7), 1.0, false)
			if MD.rec and tl0.size() > 1:
				var bb: = Rect2(tl0[0], Vector2.ZERO)
				for q: Vector2 in tl0:
					bb = bb.expand(q)
				MD.note("trail", bb)
	if bool(st["active"]) and String(st["kind"]) in ["missile", "cruise", "hyper"]:

		var mm: Array = st.get("multi", [])
		for i in range(mm.size()):
			var tp0: Vector2 = mm[i]["pos"]
			if i < mm.size() - 1:
				_cross(_scr(tp0), false, false)
			if mm.size() > 1 or int(mm[i]["n"]) > 1:
				var tc: Color = Color.WHITE if i < mm.size() - 1 else (Hub.colour(main_node.strike.cur) if (main_node != null and main_node.get("strike") != null and bool(main_node.strike.active)) else Color("ffd166"))
				_tag(_scr(tp0), "#%d ×%d" % [i + 1, int(mm[i]["n"])], tc)
		if bool(st["has_target"]) and String(st["kind"]) == "hyper":
			_cross(_scr(st["target"]), false, true)
	if bool(st["active"]) and String(st["kind"]) == "cruise":
		var bb: Aircraft = sel as Aircraft
		if bb != null and bool(st["has_target"]):
			_route(PackedVector2Array([bb.pos, st["target"]]), Air.CR_RANGE)
			_cross(_scr(st["target"]), bb.pos.distance_to(st["target"]) > Air.CR_RANGE, true)
	elif bool(st["active"]) and String(st["kind"]) == "missile":
		var mi: Dictionary = st["info"]
		if bool(st["has_target"]):
			if mi.get("tel") != null and mi.has("launch"):
				_arc(mi["launch"], st["target"], 0.0, not bool(mi.get("in_range", false)), null, float(mi.get("alt0", 0.0)))
			_cross(_scr(st["target"]), not bool(mi.get("in_range", false)), true)
	elif bool(st["active"]) and String(st["kind"]) == "drone":
		var info: Dictionary = st["info"]
		var wps: Array[Vector2] = st["wps"]
		var has_t: bool = bool(st["has_target"])

		var multi: Array = st.get("multi", [])
		var rng: float = float(info.get("range", Military.RANGE_PX))
		if info.get("airfield") != null and has_t:
			var from: Vector2 = info["from"]
			var k: int = 0
			for dc: Dictionary in st.get("danger", []):
				var lv: float = clampf(float(dc.get("level", 0.0)), 0.0, 1.0) * (0.5 if String(dc.get("kind", "")) == "seen" else 1.0)
				var rr: float = float(dc.get("r", 40.0)) * gw.camera.zoom.x
				draw_rect(Rect2(_scr(dc["pos"]) - Vector2(rr, rr), Vector2(rr, rr) * 2.0), Color(1.0, 0.2, 0.15, 0.22 * lv))
			for t: Dictionary in multi:
				k += 1
				var pts: = PackedVector2Array([from])
				var smt: Dictionary = t.get("smart", {})
				var use_smart: bool = bool(smt.get("on", false)) and bool(smt.get("ok", false)) and (t.get("wps", []) as Array).is_empty()
				if use_smart:
					pts = PackedVector2Array(smt["route"])
				else:
					for wp: Vector2 in t.get("wps", []):
						pts.append(wp)
					pts.append(t["pos"])
				var cur: bool = k == multi.size()
				if cur:
					plan_line = _to_screen(pts)
				_route(pts, rng, cur)
				var tp: Vector2 = t["pos"]
				var far: bool = from.distance_to(tp) > rng
				_cross(_scr(tp), far, cur)
				if multi.size() > 1 or int(t["n"]) > 1 or use_smart:
					var lab: String = "#%d ×%d" % [k, int(t["n"])]
					if use_smart:
						lab += Loc.t({"memory": " ПАМЯТЬ", "new": " ОБХОД"}.get(DroneBrain.src_code(String(smt.get("source", ""))), ""))
					var lp: Vector2 = _scr(tp) + Vector2(14, -12)
					var lw: float = UiKit.f_black.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
					var vw: Vector2 = get_viewport_rect().size
					if lp.x + lw > vw.x - 4.0:
						lp.x = _scr(tp).x - 10.0 - lw
					lp.y = clampf(lp.y, 14.0, vw.y - 4.0)
					draw_string(UiKit.f_black, lp + Vector2(1, 1), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.8))
					draw_string(UiKit.f_black, lp, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.c("amber"))
		for i in wps.size():
			_diamond(_scr(wps[i]), int(st["drag"]) == i, cam.zoom.x < 1.0)
	if fm != null and fm.state != Missile.State.DONE:
		_arc(fm.launch, fm.target, fm.u(), false, fm)
		if not (fm.time_left() < 3.0 and int(_t / 0.125) % 2 == 1):
			_cross(_scr(fm.target), true, false)
	if fd != null and fd.state != Drone.State.DONE and fd.state != Drone.State.PARKED:
		var p2: PackedVector2Array = gw.mil.drone_preview(fd)
		follow_line = _to_screen(p2)
		_route(p2, fd.range_px - fd.flown + (gw.mil.launch_point(fd.airfield).distance_to(fd.pos) if fd.state < Drone.State.BOOST else 0.0), true)
		var eta: float = fd.remaining_len() / maxf(fd.speed, Military.CRUISE)
		var hidden_now: bool = (fd.state == Drone.State.FLY or fd.state == Drone.State.DIVE) and eta < 3.0 and int(_t / 0.125) % 2 == 1
		for i in range(fd.route.size() - 1):
			_diamond(_scr(fd.route[i]), false, cam.zoom.x < 1.0)
		if not hidden_now:
			_cross(_scr(fd.target), false, false)
		var dp: Variant = st.get("drag_drone")
		if dp is Vector2:
			_cross(_scr(dp), false, true)

	var ac: Aircraft = sel as Aircraft
	if ac != null and ac.state != Aircraft.State.DEAD and ac.state != Aircraft.State.PARKED:
		var blue: Color = Palette.c("water_coast")
		if ac.state == Aircraft.State.PATROL:
			var c: Vector2 = _scr(ac.patrol_c) + Vector2(0.5, 0.5)
			var r: float = Air.HELI_PATROL_R * cam.zoom.x
			draw_arc(c, r, 0.0, TAU, 48, Palette.c("ui_rubber"), 3.0)
			draw_arc(c, r, 0.0, TAU, 48, blue, 1.0)
		elif ac.state != Aircraft.State.RTB and ac.state != Aircraft.State.LAND and ac.cas != 2:

			var a2: Vector2 = _scr(ac.pos)
			var b2: Vector2 = _scr(ac.dest)
			if a2.distance_to(b2) > 14.0:
				draw_dashed_line(a2.move_toward(b2, 10.0), b2.move_toward(a2, 7.0), Color(blue, 0.45), 1.0, 5.0)
			var dd: Vector2 = _scr(ac.dest) + Vector2(0.5, 0.5)
			draw_arc(dd, 5.0, 0.0, TAU, 20, Palette.c("ui_rubber"), 3.0)
			draw_arc(dd, 5.0, 0.0, TAU, 20, blue, 1.0)
		if ac.type == Aircraft.Type.FIGHTER and ac.airborne():
			draw_arc(_scr(ac.pos) + Vector2(0.5, 0.5), Air.AAM_RANGE * cam.zoom.x, 0.0, TAU, 64, Palette.c("ui_steel_light"), 1.0)

	var sf: Facility = gw.selected_facility()
	for f: Facility in gw.mil.facilities:
		if f.moving and f.country_id == pid:
			var pts: = PackedVector2Array([f.mpos])
			pts.append_array(PackedVector2Array(f.mpath))
			var sp: PackedVector2Array = _to_screen(pts)
			PK.draw(self, sp, Palette.c("grass_light"), 2.0, _t, 1.0, {"flow": f == sf, "trim": 6.0})
			var dp: Vector2 = _scr(f.mdest)
			draw_arc(dp + Vector2(0.5, 0.5), 5.0, 0.0, TAU, 20, Palette.c("ui_rubber"), 3.0)
			draw_arc(dp + Vector2(0.5, 0.5), 5.0, 0.0, TAU, 20, Palette.c("grass_light"), 1.0)

	if sf != null:
		_sel_brackets(sf, cam)

	if sf != null and gw.mil.alive(sf):
		if sf.army_build == "thermo_battery" or bool(sf.get_meta("is_thermo", false)):
			var cc: Vector2 = _scr(sf.center_px()) + Vector2(0.5, 0.5)
			var r_max: float = 640.0 * cam.zoom.x
			var r_min: float = 90.0 * cam.zoom.x
			var col_t: Color = Color(1.0, 0.55, 0.2)
			draw_arc(cc, r_max, 0.0, TAU, 96, Palette.c("ui_rubber"), 3.0)
			draw_arc(cc, r_max, 0.0, TAU, 96, col_t, 1.2)
			draw_line(cc, cc + Vector2.from_angle(_t * 1.5) * r_max, Color(col_t.r, col_t.g, col_t.b, 0.45), 1.0)
			draw_arc(cc, r_min, 0.0, TAU, 48, Palette.c("ui_rubber"), 2.0)
			draw_arc(cc, r_min, 0.0, TAU, 48, Color(1.0, 0.25, 0.2, 0.8), 1.0)
		else:
			var ring: Dictionary = cover_ring(sf.kind)
			var rr: float = float(ring["r"])
			var col: Color = ring["col"]
			if rr > 0.0:
				var cc: Vector2 = _scr(sf.center_px()) + Vector2(0.5, 0.5)
				var r2: float = rr * cam.zoom.x
				draw_arc(cc, r2, 0.0, TAU, 96, Palette.c("ui_rubber"), 3.0)
				draw_arc(cc, r2, 0.0, TAU, 96, col, 1.0)
				draw_line(cc, cc + Vector2.from_angle(_t * 1.5) * r2, Color(col.r, col.g, col.b, 0.5), 1.0)

	if main_node != null and main_node.get("strike") != null and bool(main_node.strike.active) and main_node.strike.cur == "thermo":
		for f: Facility in gw.mil.facilities:
			if f != null and is_instance_valid(f) and f.country_id == pid and (f.army_build == "thermo_battery" or bool(f.get_meta("is_thermo", false))) and gw.mil.alive(f):
				var cc: Vector2 = _scr(f.center_px()) + Vector2(0.5, 0.5)
				var r_max: float = 640.0 * cam.zoom.x
				var r_min: float = 90.0 * cam.zoom.x
				var col_t: Color = Color(1.0, 0.55, 0.2)
				draw_arc(cc, r_max, 0.0, TAU, 96, Palette.c("ui_rubber"), 3.0)
				draw_arc(cc, r_max, 0.0, TAU, 96, col_t, 1.2)
				draw_line(cc, cc + Vector2.from_angle(_t * 1.5) * r_max, Color(col_t.r, col_t.g, col_t.b, 0.45), 1.0)
				draw_arc(cc, r_min, 0.0, TAU, 48, Palette.c("ui_rubber"), 2.0)
				draw_arc(cc, r_min, 0.0, TAU, 48, Color(1.0, 0.25, 0.2, 0.8), 1.0)
				var targets: Array = st.get("multi", [])
				if targets.is_empty() and bool(st.get("has_target", false)):
					targets = [{"pos": st["target"], "n": 1}]
				for t_dict in targets:
					var tp: Vector2 = t_dict["pos"]
					var dist: float = f.center_px().distance_to(tp)
					var in_rng: bool = dist >= 90.0 and dist <= 640.0
					var lcol: Color = Color(0.25, 0.95, 0.4, 0.85) if in_rng else Color(1.0, 0.25, 0.2, 0.85)
					draw_dashed_line(cc, _scr(tp), lcol, 1.2, 6.0)
	var t9: int = Time.get_ticks_usec()
	_army_overlay(cam)
	dbg_army_us = Time.get_ticks_usec() - t9
	_line_preview(cam)
	_route_draw(cam)
	if cam.zoom.x < 1.0:
		_markers(cam.zoom.x)
	_ripples()




func _army_overlay(cam: MapCamera) -> void :
	var a: Army = gw.army
	dbg_dots = 0
	dbg_fights = 0
	var vs: Vector2 = get_viewport_rect().size
	for ar: Dictionary in a.arrows:
		var age: float = gw.game_time - float(ar["t"])
		var alpha: float = clampf(1.0 - (age - 4.0) / 2.0, 0.0, 1.0)
		var c: Country = gw.country_by_id(int(ar["c"]))
		var col: Color = Palette.c("alert_red") if c != null and c == gw.player else (c.color_light if c != null else Color.WHITE)
		col.a = alpha
		var p0: Vector2 = _scr(ar["from"])
		var p1: Vector2 = _scr(ar["to"])
		var grow: float = clampf(age / 0.6, 0.0, 1.0)
		var tip: Vector2 = p0.lerp(p1, grow)
		var dir: Vector2 = (p1 - p0).normalized()
		var n: = Vector2( - dir.y, dir.x)
		var shadow: = Color(0, 0, 0, 0.5 * alpha)
		draw_line(p0, tip - dir * 8.0, shadow, 7.0)
		draw_line(p0, tip - dir * 8.0, col, 4.0)
		var head: = PackedVector2Array([tip, tip - dir * 12.0 + n * 8.0, tip - dir * 12.0 - n * 8.0])
		draw_colored_polygon(head, col)
	var pid: int = gw.player.id if gw.player != null else -1
	for city: City in gw.cities:
		if city.siege_by == 0 and city.garrison >= city.garrison_max - 0.5:
			continue
		var sp: Vector2 = _scr(Vector2(city.center * GameWorld.CELL)) + Vector2(-16, - float(city.radius) * GameWorld.CELL * cam.zoom.x * 0.25 - 26.0)
		if sp.x < -40 or sp.y < -40 or sp.x > vs.x + 40 or sp.y > vs.y + 40:
			continue
		draw_rect(Rect2(sp, Vector2(32, 4)), Palette.c("ui_rubber"))
		draw_rect(Rect2(sp + Vector2(1, 1), Vector2(30.0 * city.garrison / maxf(1.0, city.garrison_max), 2)), Palette.c("grass_light"))




	var dk: float = clampf((cam.zoom.x - DOT_Z0) / (DOT_Z1 - DOT_Z0), 0.0, 1.0)
	if dk < 1.0:
		_fights(cam, 1.0 - dk)
	if cam.zoom.x < 1.0 and dk > 0.0:
		for u: Unit in a.units:
			if not u.alive() or u.type == Unit.Type.FPV:
				continue
			if gw.vision != null and not gw.vision.shows(u.country_id, u.pos):
				continue
			var c2: Country = gw.country_by_id(u.country_id)
			var q: Vector2 = _scr(u.pos)
			if q.x < -4 or q.y < -4 or q.x > vs.x + 4 or q.y > vs.y + 4:
				continue
			dbg_dots += 1
			draw_rect(Rect2(q - Vector2(2, 2), Vector2(4, 4)), Color(Palette.c("ui_rubber"), dk))
			var uc: Color = Palette.c("amber") if u.country_id == pid else (c2.color_light if c2 != null else Color.WHITE)
			draw_rect(Rect2(q - Vector2(1, 1), Vector2(2, 2)), Color(uc, dk))





func _fights(cam: MapCamera, k: float) -> void :
	var z: float = maxf(cam.zoom.x, 0.05)
	if _t >= _fx_t or absf(z - _fx_z) > 0.08:
		_fx_t = _t + 0.25
		_fx_z = z
		_fx_w = PackedVector3Array()
		var rr: float = 36.0 / z
		var half: Vector2 = cam.view_size() * 0.5 / z
		var view: = Rect2(cam.position - half, half * 2.0).grow(half.x * 0.5)
		var now: float = gw.game_time
		for u: Unit in gw.army.units:
			if not u.alive() or u.type == Unit.Type.FPV or (u.state != Unit.State.FIGHT and now - u.hit_t > 3.0) or not view.has_point(u.pos):
				continue
			if gw.vision != null and not gw.vision.shows(u.country_id, u.pos):
				continue
			var hit: int = -1
			for j in _fx_w.size():
				var c: Vector3 = _fx_w[j]
				if Vector2(c.x / c.z, c.y / c.z).distance_squared_to(u.pos) <= rr * rr:
					hit = j
					break
			if hit < 0:
				_fx_w.append(Vector3(u.pos.x, u.pos.y, 1.0))
			else:
				_fx_w[hit] = _fx_w[hit] + Vector3(u.pos.x, u.pos.y, 1.0)
	var pa: float = k * (0.82 + 0.18 * sin(_t * 4.0))
	var dkc: = Color(Palette.c("ui_rubber"), 0.9 * pa)
	var fc: = Color(Color("ff8a3d"), pa)
	for c2: Vector3 in _fx_w:
		var q: Vector2 = _scr(Vector2(c2.x / c2.z, c2.y / c2.z)) + Vector2(13.5, -7.5)
		var s: float = 3.0 if c2.z < 6.0 else 4.0
		if MD.kept(Rect2(q - Vector2(s + 2.0, s + 2.0), Vector2(s + 2.0, s + 2.0) * 2.0)):
			continue
		var g1: Vector2 = q + Vector2( - s + 1.5, s - 1.5)
		var g2: Vector2 = q + Vector2(s - 1.5, s - 1.5)
		for pass_i in 2:
			var cc: Color = dkc if pass_i == 0 else fc
			var w: float = 4.0 if pass_i == 0 else 2.0
			draw_line(q + Vector2( - s, s), q + Vector2(s, - s), cc, w)
			draw_line(q + Vector2(s, s), q + Vector2( - s, - s), cc, w)
			draw_line(g1 + Vector2(-1.5, -1.5), g1 + Vector2(1.5, 1.5), cc, w)
			draw_line(g2 + Vector2(-1.5, 1.5), g2 + Vector2(1.5, -1.5), cc, w)
		dbg_fights += 1


func _scr(w: Vector2) -> Vector2:
	return gw.camera.world_to_screen(w).floor()



func _cut_head(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var left: float = d
	for i in range(1, pts.size()):
		var sl: float = pts[i - 1].distance_to(pts[i])
		if sl >= left:
			var out: = PackedVector2Array([pts[i - 1].lerp(pts[i], left / maxf(sl, 0.001))])
			out.append_array(pts.slice(i))
			return out
		left -= sl
	return PackedVector2Array()


func _to_screen(pts: PackedVector2Array) -> PackedVector2Array:
	var out: = PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = gw.camera.world_to_screen(pts[i]).floor() + Vector2(0.5, 0.5)
	return out




func _line(spts: PackedVector2Array, col: Color, w: float, outline: bool) -> void :
	if spts.size() < 2:
		return
	if outline:
		draw_polyline(spts, Palette.c("ui_rubber"), w + 2.0)
	draw_polyline(spts, col, w)



func _route(path: PackedVector2Array, limit: float, pulses: bool = true) -> void :
	if path.size() < 2:
		return
	var thick: bool = gw.camera.zoom.x >= 2.0
	var w: float = 2.0 if thick else 1.0
	var ok: = PackedVector2Array()
	var over: = PackedVector2Array()
	var acc: float = 0.0
	ok.append(path[0])
	for i in range(1, path.size()):
		var seg: float = path[i - 1].distance_to(path[i])
		if acc + seg <= limit:
			ok.append(path[i])
		else:
			if over.is_empty():
				var cut: Vector2 = path[i - 1].lerp(path[i], clampf((limit - acc) / maxf(seg, 0.001), 0.0, 1.0))
				ok.append(cut)
				over.append(cut)
			over.append(path[i])
		acc += seg
	var sok: PackedVector2Array = _to_screen(ok)
	var ww: float = 3.5 if thick else 2.5
	PK.draw(self, sok, Palette.c("amber"), ww, _t, 1.0, {"arrow": over.size() < 2, "flow": pulses, "trim": 6.0})
	if over.size() >= 2:
		PK.draw(self, _to_screen(over), Palette.c("alert_red"), ww, _t, 1.0, {"flow": false, "trim": 6.0})



func _pulses(spts: PackedVector2Array, thick: bool) -> void :
	var gap: float = 22.0
	var off: float = fposmod(_t * 30.0, gap)
	var s: float = 0.0
	var next: float = off
	var vr: = Rect2(Vector2(-4, -4), get_viewport_rect().size + Vector2(8, 8))
	var sz: float = 3.0 if thick else 2.0
	for i in range(1, spts.size()):
		var a: Vector2 = spts[i - 1]
		var b: Vector2 = spts[i]
		var seg: float = a.distance_to(b)
		while next <= s + seg:
			var p: Vector2 = a.lerp(b, (next - s) / maxf(seg, 0.001)).floor()
			if vr.has_point(p):
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(sz + 2.0, sz + 2.0)), Palette.c("ui_rubber"))
				draw_rect(Rect2(p, Vector2(sz, sz)), Palette.c("window_light"))
			next += gap
		s += seg



func _arc(from: Vector2, to: Vector2, k0: float, red: bool, m: Missile = null, lift: float = 12.0) -> void :
	var apex: float = Military.apex_for(from.distance_to(to))
	var alt0: float = lift
	var a: Vector2 = from
	if m != null:
		apex = m.apex
		alt0 = m.alt0
		a = m.launch


	var z: float = gw.camera.zoom.x
	var sa: Vector2 = gw.camera.world_to_screen(a)
	var sb: Vector2 = gw.camera.world_to_screen(to)
	var h_scr: float = apex * z if m != null else clampf(maxf(apex * z, sa.distance_to(sb) * 0.28), 18.0, 260.0)
	var l_scr: float = alt0 * z
	var pts: = PackedVector2Array()
	var ground: = PackedVector2Array()
	var n: int = 48
	for i in range(n + 1):
		var k: float = lerpf(k0, 1.0, float(i) / n)
		var g: Vector2 = sa.lerp(sb, k * k * (3.0 - 2.0 * k))
		pts.append(g - Vector2(0.0, 4.0 * h_scr * k * (1.0 - k) + l_scr * (1.0 - k)))
		if m == null:
			ground.append(g)
	PK.arc(self, pts, ground, Palette.c("alert_red") if red else Color("ff7a3d"), _t, red)




func _dia(p: Vector2, r: int, col: Color) -> void :
	for dy in range( - r, r + 1):
		var w: int = r - absi(dy)
		draw_rect(Rect2(p.x - w, p.y + dy, 2 * w + 1, 1), col)



func _diamond(p: Vector2, big: bool, zoomed_out: bool = false) -> void :
	if big:
		_dia(p, 4, Palette.c("ui_rubber"))
		_dia(p, 3, Palette.c("text"))
		_dia(p, 1, Palette.c("amber"))
	elif zoomed_out:
		_dia(p, 4, Palette.c("ui_rubber"))
		_dia(p, 3, Palette.c("amber"))
		_dia(p, 1, Palette.c("text"))
	else:
		_dia(p, 3, Palette.c("ui_rubber"))
		_dia(p, 2, Palette.c("amber"))
		_dia(p, 0, Palette.c("text"))





func _cross(p: Vector2, all_red: bool, breathe: bool) -> void :
	var col: Color = Palette.c("alert_red") if all_red else Color("ff8a4a")
	if not all_red and main_node != null and main_node.get("strike") != null and bool(main_node.strike.active):
		col = Hub.colour(main_node.strike.cur)
	PK.reticle(self, p + Vector2(0.5, 0.5), col, _t if breathe else 0.0, 8.0 if breathe else 7.0)



func _tag(p: Vector2, txt: String, col: Color) -> void :
	var vw: Vector2 = get_viewport_rect().size
	var lw: float = UiKit.f_black.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var lp: Vector2 = p + Vector2(14, -12)
	if lp.x + lw > vw.x - 4.0:
		lp.x = p.x - 14.0 - lw
	lp.y = clampf(lp.y, 14.0, vw.y - 4.0)
	draw_string_outline(UiKit.f_black, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.85))
	draw_string(UiKit.f_black, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)



func _ripples() -> void :


	for rp: Array in ripples:
		var cn: String = String(rp[2])
		var col: Color = Color("ff5a42") if cn == "alert_red" else (Color("ffd166") if cn == "amber" else Color("9ff5ee"))
		PK.tap_mark(self, _scr(rp[0]) + Vector2(0.5, 0.5), col, _t - float(rp[1]))



func _markers(z: float) -> void :
	var player_id: int = gw.player.id if gw.player != null else -1
	var vr: = Rect2(Vector2(-4, -4), get_viewport_rect().size + Vector2(8, 8))
	var vis: Vision = gw.vision
	for m: Missile in gw.mil.missiles:
		if vis != null and not vis.shows_air(m.country_id, m.ground()):
			continue
		var mp: Vector2 = _scr(m.screen_pos())
		if vr.has_point(mp):
			MD.note("air", Rect2(mp - Vector2(2, 2), Vector2(5, 5)))
			draw_rect(Rect2(mp.x - 2, mp.y - 2, 5, 5), Palette.c("outline"))
			draw_rect(Rect2(mp.x - 1, mp.y - 1, 3, 3), Palette.c("fire_yellow"))
	_kab_markers(vr, player_id)
	for ac: Aircraft in gw.mil.air.aircraft:
		if not ac.airborne() or ac.state == Aircraft.State.DEAD:
			continue
		if vis != null and not vis.shows_air(ac.country_id, ac.pos):
			continue
		var ap: Vector2 = _scr(ac.pos)
		if vr.has_point(ap):
			var col: Color = Palette.c("water_coast") if ac.country_id == player_id else Palette.c("alert_red")
			_dia(ap, 3, Palette.c("outline"))
			_dia(ap, 2, col)

	var packs: Array = []
	for d0: Drone in gw.mil.drones:
		if not d0.airborne():
			continue
		if vis != null and not vis.shows_air(d0.country_id, d0.pos):
			continue
		var p0: Vector2 = _scr(d0.pos)
		if not vr.has_point(p0):
			continue
		var own0: bool = d0.country_id == player_id
		var joined: bool = false
		for pk: Array in packs:
			if ((pk[2] as Drone).country_id == player_id) == own0 and (pk[0] as Vector2).distance_to(p0) < 9.0:
				pk[1] = int(pk[1]) + 1
				joined = true
				break
		if not joined:
			packs.append([p0, 1, d0])
	for pk2: Array in packs:
		var d: Drone = pk2[2]
		var p: Vector2 = pk2[0]
		MD.note("air", Rect2(p - Vector2(2, 2), Vector2(5, 5)))
		if int(pk2[1]) > 1:
			var tx: String = "×%d" % int(pk2[1])
			draw_string_outline(UiKit.f_black, p + Vector2(4, -3), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0, 0, 0, 0.85))
			draw_string(UiKit.f_black, p + Vector2(4, -3), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Palette.c("text") if d.country_id == player_id else Color("ff8a7a"))
		var core: Color = Palette.c("text") if d.country_id == player_id else Palette.c("alert_red")
		if z >= 0.5:
			draw_rect(Rect2(p.x - 2, p.y - 2, 5, 5), Palette.c("outline"))
			draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), core)
			var v: Vector2 = Vector2.from_angle(d.heading)
			var nose: = Vector2(roundf(v.x * 1.4), roundf(v.y * 1.4)).clamp(Vector2(-1, -1), Vector2(1, 1))
			draw_rect(Rect2(p + nose * 2.0, Vector2.ONE), Palette.c("amber"))
		else:
			draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), Palette.c("outline"))
			draw_rect(Rect2(p.x, p.y, 1, 1), core)



func _kab_markers(vr: Rect2, player_id: int) -> void :
	for d: Drone in gw.mil.air.kabs:
		if gw.vision != null and not gw.vision.shows_air(d.country_id, d.pos):
			continue
		var p: Vector2 = _scr(d.pos).floor()
		if vr.has_point(p):
			draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), Palette.c("outline"))
			draw_rect(Rect2(p.x, p.y, 1, 1), Palette.c("amber") if d.country_id == player_id else Palette.c("alert_red"))




static func cover_ring(kind: int) -> Dictionary:
	if Defense.SPEC.has(kind):
		return {"r": float(Defense.SPEC[kind]["range"]), "col": Palette.c("intercept_cyan")}
	if kind == Facility.Kind.AD_RADAR:
		return {"r": Defense.RADAR_R, "col": Palette.c("grass_light")}
	if kind == Facility.Kind.AD_EW:
		return {"r": Defense.EW_R, "col": Palette.c("water_coast")}
	return {"r": 0.0, "col": Color.WHITE}



static func dist_to_line(p: Vector2, line: PackedVector2Array) -> float:
	var best: float = INF
	for i in range(1, line.size()):
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, line[i - 1], line[i])
		best = minf(best, q.distance_to(p))
	return best



func _sel_brackets(f: Facility, cam: MapCamera) -> void :
	var c: Vector2 = _scr(f.mpos if f.moving else f.center_px())
	var sz: Vector2 = Vector2(Military.SIZES.get(f.kind, Vector2i(4, 4))) * float(GameWorld.CELL) * cam.zoom.x
	if f.is_line():
		sz = Vector2(10, 10)


	UiKit.draw_sel_frame(self, Rect2(c - sz * 0.5, sz), Color("ffd75e"))


func _line_preview(cam: MapCamera) -> void :
	var lcv: Variant = main_node.get("line_cells") if main_node != null else null
	if not (lcv is Array) or gw.player == null:
		return
	var lc: Array = lcv
	if lc.is_empty():
		return
	var z: float = cam.zoom.x
	var ok: = Color(Palette.c("grass_light"), 0.75)
	var bad: = Color(Palette.c("alert_red"), 0.75)
	for c: Vector2i in lc:
		var p: Vector2 = _scr(Vector2(c * GameWorld.CELL))
		var good: bool = gw.mil.line_cell_ok(c, gw.player)
		draw_rect(Rect2(p, Vector2(4.0 * z, 4.0 * z)), ok if good else bad)
	var last: Vector2i = lc[lc.size() - 1]
	var lp: Vector2 = _scr(Vector2(last * GameWorld.CELL) + Vector2(2, 2))
	draw_arc(lp, 6.0, 0.0, TAU, 16, Palette.c("ui_rubber"), 3.0)
	draw_arc(lp, 6.0, 0.0, TAU, 16, Palette.c("amber"), 1.0)




func _route_draw(cam: MapCamera) -> void :
	var hud: Variant = main_node.get("hud") if main_node != null else null
	var ux: Variant = hud.get("army_ux") if hud != null else null
	if ux == null or not is_instance_valid(ux) or not bool(ux.get("draw_on")) or String(ux.get("view")) != "place":
		return
	var raw: PackedVector2Array = ux.get("draw_pts")
	var wps: PackedVector2Array = ux.get("draw_wps")
	var col: Color = Color("8fd2ff") if bool(ux.get("place_sea")) else UiKit.GOLD
	if raw.size() >= 2 and wps.is_empty():
		var sp: = PackedVector2Array()
		for q: Vector2 in raw:
			sp.append(cam.world_to_screen(q))
		PK.draw(self, sp, col, 4.0, _t)
	for i in wps.size():
		var c: Vector2 = cam.world_to_screen(wps[i])
		draw_circle(c, 6.0, Color(0.05, 0.06, 0.08))
		draw_circle(c, 4.0, col if i < wps.size() - 1 else UiKit.GREEN)
