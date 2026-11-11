extends Control







const PK = preload("res://ui/ui24/path_kit.gd")
const U = preload("res://ui/ui24/arm_kit.gd")
const RV = preload("res://world/rail_view332.gd")
const M = preload("res://ui/ui24/army_store.gd")
const ArmyGroups = preload("res://game/army_groups.gd")
const FrontPlan = preload("res://game/front_plan.gd")
const MD = preload("res://ui/ui24/map_declutter.gd")

const FAR_ZOOM: float = 0.55
const DATA_T: float = 1.0
const CL_ON: float = 30.0
const CL_OFF: float = 64.0

var hud: Node
var gw: GameWorld
var dock: Node
var store: M
var ring: Texture2D
var _dash_t: float = 0.0
var _data_t: float = 0.0
var _rows: Array = []
var _ptaps: Array = []
var _on: bool = false


func mount(h: Node, d: Node) -> void :
	hud = h
	gw = h.gw
	dock = d
	store = M.new(gw)
	name = "ArmyPennants"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.root.add_child(self)
	h.root.move_child(self, mini(1, h.root.get_child_count() - 1))
	ring = UiKit.tex("sel_ring")
	var rb: Variant = load("res://ui/ui24/rail_back.gd")
	if rb is GDScript:
		(rb as GDScript).new().mount(h, self)


func _wanted() -> bool:
	if gw == null or gw.player == null or gw.player.eliminated or gw.ops == null or hud.main_node.get("cam") == null:
		return false
	if String(hud.get("panel_kind")) == "conference" and bool(hud.call("ui24_open_now")):
		return false
	if hud.get("army_ux") != null:
		return true
	return not gw.player.army_groups.is_empty() or (dock != null and dock.is_open and (dock.selecting or dock.placing != ""))


func _process(delta: float) -> void :
	var want: bool = _wanted()
	if not want:
		if _on:
			_on = false
			_rows.clear()
			OpsLayer.pennant_fids = {}
			queue_redraw()
		return
	_on = true
	_dash_t = fmod(_dash_t + delta * 12.0, 12.0)
	_data_t -= delta
	if _data_t <= 0.0:
		_data_t = DATA_T
		var sm: Dictionary = gw.ops.command_summary(gw.player.id)
		store.scan(sm)
		_rows = store.armies(sm, -1).filter( func(r: Dictionary) -> bool: return int(r["gid"]) >= 0)
	queue_redraw()


func _draw() -> void :
	MD.begin("pennant")
	MD.begin("pdot")
	MD.tap_begin("pennant")
	MD.pennants_on = false
	MD.pen_rects.clear()
	MD.named.clear()
	_ptaps.clear()
	if not _on or gw == null or gw.player == null or dock == null:
		return
	var cam: MapCamera = hud.main_node.cam
	var z: float = cam.zoom.x
	var pid: int = gw.player.id

	var per: Dictionary = {}
	for u: Unit in gw.army.units:
		if u.home == null or u.country_id != pid or not u.alive() or u.type == Unit.Type.FPV or u.reinf != 0:
			continue
		var e: Array = per.get(u.home.id, [Vector2.ZERO, 0, []])
		e[0] = (e[0] as Vector2) + u.pos
		e[1] = int(e[1]) + 1
		(e[2] as Array).append(u.pos)
		per[u.home.id] = e
	var open: bool = bool(dock.is_open)
	var active: int = int(dock.tab_gid) if open else -999
	var selecting: bool = open and bool(dock.selecting)
	var hi_fids: Dictionary = dock.checked if selecting else {}

	for g: Dictionary in gw.player.army_groups:
		var gcol: Color = U.color(int(g["color"]))
		for fid: int in g["fids"]:
			if (int(g["id"]) == active and not selecting) or hi_fids.has(fid):
				_rings(per.get(fid, []), cam, z, gcol)
	if selecting:
		for fid2: int in hi_fids:
			var f2: Facility = ArmyGroups.fac(gw, fid2)
			if f2 != null and f2.group_id < 0:
				_rings(per.get(fid2, []), cam, z, UiKit.GOLD)

	var rp: Variant = dock.get("route_pts")
	if open and rp is PackedVector2Array and (rp as PackedVector2Array).size() >= 2:
		var rcol: Color = UiKit.GOLD
		var rg: Dictionary = ArmyGroups.by_id(gw, pid, active) if active >= 0 and not selecting else {}
		if not rg.is_empty():
			rcol = U.color(int(rg["color"]))
		var sp: = PackedVector2Array()
		for q: Vector2 in (rp as PackedVector2Array):
			sp.append(cam.world_to_screen(q))
		PK.draw(self, sp, rcol, 4.0, Time.get_ticks_msec() * 0.001)
		var bw: Vector2 = dock.get("route_wp")
		if bw.is_finite():
			draw_circle(cam.world_to_screen(bw), 5.0, U.DARK)
			draw_circle(cam.world_to_screen(bw), 3.5, Color.WHITE)

	if open and String(dock.placing) != "" and (dock.target as Vector2).is_finite():
		var tp: Vector2 = cam.world_to_screen(dock.target)
		var gcol2: Color = UiKit.GOLD
		var gg: Dictionary = ArmyGroups.by_id(gw, pid, active) if active >= 0 and not selecting else {}
		if not gg.is_empty():
			gcol2 = U.color(int(gg["color"]))
		var pvd: Dictionary = dock.pv
		for en: Array in pvd.get("ends", []):
			var c: Vector2 = _center(per, int(en[0]), Vector2.INF)
			if c.is_finite():
				var ew: Vector2 = en[2] if en.size() > 2 else Vector2.INF
				if ew.is_finite():
					PK.draw(self, PackedVector2Array([cam.world_to_screen(c), cam.world_to_screen(ew), cam.world_to_screen(en[1])]), gcol2, 2.5, Time.get_ticks_msec() * 0.001, 1.0, {"trim": 5.0})
				else:
					PK.line(self, cam.world_to_screen(c), cam.world_to_screen(en[1]), gcol2, 2.5, Time.get_ticks_msec() * 0.001, 1.0, {"trim": 5.0})
		for sk: Array in pvd.get("skipped", []):
			var c2: Vector2 = _center(per, int(sk[2]) if sk.size() > 2 else -1, Vector2.INF)
			if c2.is_finite():
				PK.line(self, cam.world_to_screen(c2), tp, Color(0.6, 0.55, 0.5, 0.5), 1.5, 0.0, 1.0, {"arrow": false, "flow": false})
		_target(tp, gcol2)

	var aux: Variant = hud.get("army_ux")
	if aux != null and is_instance_valid(aux):
		_ux_draw(aux, cam, z, per)
		return
	if gw.player.army_groups.is_empty():
		OpsLayer.pennant_fids = {}
		return
	MD.pennants_on = true

	if z < FAR_ZOOM:
		OpsLayer.pennant_fids = {}
		var taken2: Array = []
		var names2: Array = MD.label_rects(gw, cam)
		var vs2: Vector2 = cam.view_size()
		var hud_blk: Array = [Rect2(0, -400, vs2.x, float(cam.margin_top_px) + 440.0), Rect2(0, vs2.y - float(cam.margin_bottom_px), vs2.x, 400.0)]
		if hud.has_method("blocked_rects"):
			hud_blk.append_array(hud.blocked_rects())
		for g2: Dictionary in gw.player.army_groups:
			var s: = Vector2.ZERO
			var n: int = 0
			for fid4: int in g2["fids"]:
				var e2: Array = per.get(fid4, [])
				if not e2.is_empty():
					s += (e2[0] as Vector2) / float(e2[1])
					n += 1
			if n == 0:
				continue
			var p: Vector2 = cam.world_to_screen(s / float(n))
			var p_at: Vector2 = p

			var kf: float = 2.0 if int(g2["id"]) == active else (1.6 if vs2.y - float(cam.margin_top_px) - float(cam.margin_bottom_px) >= 380.0 else 1.25)
			var lbl: String = "%d·%s ×%d" % [int(g2["id"]), Loc.name(String(g2["name"])).to_upper(), (g2["fids"] as PackedInt32Array).size()]
			var br: Rect2 = MD.pennant_rect(p, kf, lbl).grow(1.0)
			var stp: float = br.size.y + 2.0
			var sdx: float = br.size.x + 6.0



			var best_off: Vector2 = Vector2.ZERO
			var best_c: float = INF
			for off: Vector2 in [Vector2.ZERO, Vector2(0, stp), Vector2(0, - stp), Vector2( - sdx, 0), Vector2(0, 2.0 * stp), Vector2(0, -2.0 * stp), Vector2( - sdx, stp), Vector2( - sdx, - stp), Vector2(sdx, 0), Vector2(0, 3.0 * stp), Vector2(0, -3.0 * stp)]:
				var rq: = Rect2(br.position + off, br.size).grow(-1.0)
				var cst: float = off.length() * 0.25
				if MD.hits(rq, MD.pen_rects):
					cst += 300.0
				if MD.hits(rq, hud_blk):
					cst += 2000.0
				if MD.hits(rq, names2):
					cst += 60.0
				if cst < best_c:
					best_c = cst
					best_off = off
			p += best_off
			br.position += best_off
			for kr: Rect2 in MD.keep_out:
				if kr.intersects(br):
					var shx: float = kr.position.x - br.end.x
					p.x += shx
					br.position.x += shx
			taken2.append(br)
			MD.pen_rects.append(br)
			MD.note("pennant", br)
			_ptaps.append([br, int(g2["id"])])
			if p.distance_to(p_at) > 12.0:
				draw_line(p_at, p, U.DARK, 3.0)
				draw_line(p_at, p, U.color(int(g2["color"])).lightened(0.2), 1.0)
				draw_circle(p_at, 3.0, U.DARK)
				draw_circle(p_at, 2.0, U.color(int(g2["color"])))
			U.draw_pennant(self, p, kf, U.color(int(g2["color"])), String(g2["emblem"]), lbl)
			MD.named[int(g2["id"])] = true
		return





	var hid: Dictionary = {}
	var vr: Rect2 = get_viewport_rect().grow(40.0)
	var cl: Array = []
	var rows: Array = _rows.duplicate()
	rows.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a["no"]) < int(b["no"]))
	for r2: Dictionary in rows:
		var fid5: int = int(r2["fid"])
		var f5: Facility = ArmyGroups.fac(gw, fid5)
		if f5 == null or f5.group_id < 0:
			continue
		var g5: Dictionary = ArmyGroups.by_id(gw, pid, f5.group_id)
		if g5.is_empty():
			continue
		var at: Vector2 = cam.world_to_screen(_center(per, fid5, r2["pos"]))
		if not vr.has_point(at):
			continue
		hid[fid5] = true
		var gid5: int = int(g5["id"])
		var on: bool = gid5 == active
		var whole: bool = not on and not FrontPlan.front_of(g5).is_empty()
		var rad: float = CL_ON if on else CL_OFF
		var c0: Dictionary = {}
		for c: Dictionary in cl:
			if int(c["gid"]) == gid5 and (whole or (c["seed"] as Vector2).distance_to(at) <= rad):
				c0 = c
				break
		if c0.is_empty():
			c0 = {"gid": gid5, "g": g5, "sum": Vector2.ZERO, "n": 0, "seed": at, "no": int(r2["no"]), "fight": false, "march": false, "on": on, "whole": whole}
			cl.append(c0)
		c0["sum"] = (c0["sum"] as Vector2) + at
		c0["n"] = int(c0["n"]) + 1
		var act: String = String(r2["act"])
		if act == "fight":
			c0["fight"] = true
		elif act in ["move", "sea"]:
			c0["march"] = true
	cl.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["on"]) != bool(b["on"]):
			return bool(a["on"])
		if bool(a["fight"]) != bool(b["fight"]):
			return bool(a["fight"])
		return int(a["n"]) > int(b["n"]))
	var taken: Array = []
	for kr2: Rect2 in MD.keep_out:
		taken.append(kr2)
	taken.append_array(MD.label_rects(gw, cam))
	var dk: float = 0.3 if active >= 0 and not selecting else 0.12
	for c1: Dictionary in cl:
		var on1: bool = bool(c1["on"])
		var n1: int = int(c1["n"])
		var at1: Vector2 = ((c1["sum"] as Vector2) / float(n1)).round()
		var g1: Dictionary = c1["g"]
		var hot: bool = bool(c1["fight"])
		var tag: String = Loc.t(" бой") if hot else (Loc.t(" марш") if bool(c1["march"]) else "")
		var txt: String = ""
		if bool(c1["whole"]):
			txt = "%d·%s ×%d%s" % [int(c1["gid"]), Loc.name(String(g1["name"])).to_upper(), n1, Loc.t(" бой") if hot else ""]
		elif n1 == 1:
			txt = "%s%s" % [Loc.no(int(c1["no"])), tag]
		else:
			txt = "%s +%d%s" % [Loc.no(int(c1["no"])), n1 - 1, tag]
		var k: float = 1.25 if on1 else 1.0
		var fs: int = 11 if on1 else 10
		var foot0: Vector2 = at1 + Vector2(0, -6)
		var r0: Rect2 = MD.pennant_rect(foot0, k, txt, fs).grow(1.0)
		var w: float = r0.size.x
		var h: float = r0.size.y
		var placed: Vector2 = Vector2.INF
		var pr: Rect2
		for off: Vector2 in [Vector2.ZERO, Vector2(0, - h - 2), Vector2(w * 0.5 + 6, 0), Vector2( - w - 4, 0), Vector2(0, h + 2), Vector2(w * 0.5 + 6, - h - 2), Vector2( - w - 4, - h - 2), Vector2(0, -2 * h - 4), Vector2( - w - 4, h + 2)]:
			var rr: Rect2 = Rect2(r0.position + off, r0.size)
			var free: bool = true
			for t: Rect2 in taken:
				if t.intersects(rr):
					free = false
					break
			if free:
				placed = foot0 + off
				pr = rr
				taken.append(rr)
				break
		var col: Color = U.color(int(g1["color"]))
		if not on1:
			col = col.darkened(dk)
		if placed == Vector2.INF:
			MD.note("pdot", Rect2(at1 - Vector2(4, 4), Vector2(8, 8)))
			draw_circle(at1, 4.0, U.DARK)
			draw_circle(at1, 3.0, col)
			continue
		if placed.distance_to(foot0) > 1.0:
			draw_line(at1, placed, U.DARK, 3.0)
			draw_line(at1, placed, col.lightened(0.2), 1.0)
			draw_circle(at1, 2.5, col)
		MD.note("pennant", pr)
		MD.pen_rects.append(pr)
		if bool(c1["whole"]):
			MD.named[int(c1["gid"])] = true
		_ptaps.append([pr, int(c1["gid"])])
		U.draw_pennant(self, placed, k, col, String(g1["emblem"]), txt, fs, hot)
	OpsLayer.pennant_fids = hid




func map_tap(pos: Vector2) -> bool:
	var aux: Variant = hud.get("army_ux") if hud != null else null
	if aux != null and is_instance_valid(aux):

		var hb: Array = hit_at(pos)
		if not hb.is_empty():
			UiKit.snd("ui_select")
			if String(hb[0]) == "g":
				aux.open_group(int(hb[1]))
			else:
				aux.open_army(int(hb[1]))
			return true



	var bgid: int = -1
	var bd: float = INF
	for e: Array in _ptaps:
		var r: Rect2 = e[0]
		var tr: = Rect2(r.get_center() - Vector2(maxf(r.size.x, 44.0), maxf(r.size.y, 44.0)) * 0.5, Vector2(maxf(r.size.x, 44.0), maxf(r.size.y, 44.0)))
		if tr.has_point(pos) and (r.grow(2.0).has_point(pos) or not _own_unit_at(pos)):
			var d: float = r.get_center().distance_to(pos)
			if d < bd:
				bd = d
				bgid = int(e[1])
	if bgid >= 0 and dock != null and dock.has_method("open_group_card"):
		dock.open_group_card(bgid)
		return true
	var wp: Vector2 = MD.tap_at(pos)
	if not wp.is_finite() or hud == null or hud.main_node == null:
		return false
	var cam: MapCamera = hud.main_node.get("cam")
	if cam == null:
		return false
	var z2: float = MD.zoom_in_of(cam.zoom.x)
	if z2 <= cam.zoom.x + 0.01:
		return false
	cam.set_zoom_at(z2, pos)
	UiKit.snd("ui_select")
	return true



func _own_unit_at(pos: Vector2) -> bool:
	var cam: MapCamera = hud.main_node.get("cam") if hud != null and hud.main_node != null else null
	if cam == null or gw == null or gw.player == null:
		return false
	for u: Unit in gw.army.units:
		if u.country_id == gw.player.id and u.alive() and u.home != null and cam.world_to_screen(u.pos).distance_to(pos) < 12.0:
			return true
	return false





func _core_of(fid: int, e: Array, now: int) -> Array:
	var pts: Array = e[2]
	var nn: int = pts.size()
	var mean: Vector2 = (e[0] as Vector2) / float(maxi(1, nn))
	var c0: Array = _core.get(fid, [])
	if not c0.is_empty() and now - int(c0[2]) < CORE_MS and int(c0[4]) == nn and (c0[3] as Vector2).distance_to(mean) < 12.0:
		return c0
	var best: Vector2 = mean
	var bn: int = -1
	var bd: float = INF
	var step: int = maxi(1, nn / 24)
	var r2: float = CORE_R * CORE_R
	for i: int in range(0, nn, step):
		var q: Vector2 = pts[i]
		var cnt: int = 0
		for p2: Vector2 in pts:
			if q.distance_squared_to(p2) <= r2:
				cnt += 1
		var d: float = q.distance_squared_to(mean)
		if cnt > bn or (cnt == bn and d < bd):
			bn = cnt
			bd = d
			best = q


	if stick and not c0.is_empty():
		var pc: Vector2 = c0[0]
		var pn: int = 0
		var ps: = Vector2.ZERO
		for p4: Vector2 in pts:
			if pc.distance_squared_to(p4) <= r2:
				pn += 1
				ps += p4
		if pn > 0 and pn >= bn - maxi(3, int(ceil(float(bn) * 0.25))):
			best = ps / float(pn)
	var sum: = Vector2.ZERO
	var k: int = 0
	for p3: Vector2 in pts:
		if best.distance_squared_to(p3) <= r2:
			sum += p3
			k += 1
	var out: Array = [sum / float(k) if k > 0 else mean, maxi(1, k), now, mean, nn]
	_core[fid] = out
	return out


func _center(per: Dictionary, fid: int, fallback: Vector2) -> Vector2:
	var e: Array = per.get(fid, [])
	if e.is_empty():
		return fallback
	return (e[0] as Vector2) / float(e[1])


func _rings(e: Array, cam: MapCamera, z: float, col: Color) -> void :
	if e.is_empty() or ring == null:
		return
	var s: float = clampf(8.0 * z, 6.0, 16.0)
	var c: = Color(col.r, col.g, col.b, 0.85)
	for p: Vector2 in e[2]:
		var sp: Vector2 = cam.world_to_screen(p)
		draw_texture_rect(ring, Rect2(sp - Vector2(s, s) * 0.5 + Vector2(0, s * 0.2), Vector2(s, s)), false, c)


func _dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void :
	PK.line(self, a, b, col, w, Time.get_ticks_msec() * 0.001)


func _target(p: Vector2, col: Color) -> void :
	draw_arc(p, 15.0, 0.0, TAU, 28, Color(0.06, 0.04, 0.02, 0.8), 5.0)
	draw_arc(p, 15.0, 0.0, TAU, 28, col, 3.0)
	for a in 4:
		var v: Vector2 = Vector2.RIGHT.rotated(float(a) * PI * 0.5)
		draw_line(p + v * 9.0, p + v * 21.0, Color(0.06, 0.04, 0.02, 0.8), 4.0)
		draw_line(p + v * 9.0, p + v * 21.0, Color.WHITE, 2.0)
	draw_circle(p, 3.0, Color.WHITE)




const AS = preload("res://ui/ui24/army_state.gd")
const MAX_FULL: int = 6

const ANC_HOLD: float = 1.5
const KEY_HOLD: float = 1.2
const FIGHT_IN: float = 0.4
const FIGHT_OUT: float = 2.5
const FOLD_HOLD: float = 1.0
var stick: bool = true
var _pl: Dictionary = {}
var _pl_ms: int = 0
var _pl_gw: Object = null
var _core: Dictionary = {}
const CORE_R: float = 90.0
const CORE_MS: int = 200
var plate_log: Array = []
var plate_log_on: bool = false
var _hits: Array = []







func _ux_draw(ux: Node, cam: MapCamera, z: float, per: Dictionary) -> void :
	_hits.clear()
	var f: Font = UiKit.f_black
	var pid: int = gw.player.id
	var vr: Rect2 = get_viewport_rect()
	var top: float = float(cam.margin_top_px) + 8.0
	var bot: float = hud.holder.get_global_rect().position.y if hud.holder != null else vr.size.y
	var now: int = Time.get_ticks_msec()
	var view: String = String(ux.view)
	var cg: int = int(ux.cur_gid)
	var cf: int = int(ux.cur_fid)
	var hid: Dictionary = {}

	if view == "group" or (view == "place" and String(ux.place_kind) != "move_army"):
		var gg: Dictionary = ArmyGroups.by_id(gw, pid, cg)
		if not gg.is_empty():
			var gc: Color = U.color(int(gg["color"]))
			for fid: int in gg["fids"]:
				for sp: Vector2 in (per.get(fid, [Vector2.ZERO, 0, []]) as Array)[2]:
					var up: Vector2 = cam.world_to_screen(sp)
					draw_arc(up, clampf(5.0 * z, 4.0, 9.0), 0.0, TAU, 12, U.DARK, 3.0)
					draw_arc(up, clampf(5.0 * z, 4.0, 9.0), 0.0, TAU, 12, gc, 1.5)
	elif view == "army" or (view == "place" and String(ux.place_kind) == "move_army"):
		var af: Facility = ArmyGroups.fac(gw, cf)
		_mark(cam, f, per, cf, UiKit.GOLD, Loc.no(af.army_no if af != null else 0))
	elif view == "bar":
		var bf: Facility = ArmyGroups.fac(gw, cf)
		if bf != null:



			var c0: Vector2 = cam.world_to_screen(bf.center_px())
			var hv: Vector2 = Vector2(Military.SIZES.get(bf.kind, Vector2i(4, 4))) * float(GameWorld.CELL) * cam.zoom.x * 0.5
			hv = hv.max(Vector2(8.0, 8.0))
			UiKit.draw_sel_frame(self, Rect2(c0 - hv, hv * 2.0), UiKit.GOLD)
	if view == "pick":
		for fid2: int in ux.picked:
			var pf: Facility = ArmyGroups.fac(gw, fid2)
			_mark(cam, f, per, fid2, UiKit.GOLD, "✓" + Loc.no(pf.army_no if pf != null else 0))

	var pv: Dictionary = ux.preview
	if not pv.is_empty() and now < int(pv.get("until", 0)):
		for e: Array in pv["ok"]:
			var path: PackedVector2Array = e[1]
			if path.size() < 2:
				continue
			var spl: = PackedVector2Array()
			for q: Vector2 in path:
				spl.append(cam.world_to_screen(q))
			var sea: bool = bool(e[2])
			var rl: Dictionary = e[3] if e.size() > 3 else {}
			if not rl.is_empty():

				PK.draw(self, PackedVector2Array([spl[0], cam.world_to_screen(rl["p1"])]), UiKit.GREEN, 2.5, now * 0.001)
				PK.draw(self, PackedVector2Array([cam.world_to_screen(rl["p2"]), spl[spl.size() - 1]]), UiKit.GREEN, 2.5, now * 0.001)
				RV.preview_leg(self, cam, rl, now * 0.001, f)
				continue
			PK.draw(self, spl, Color("8fd2ff") if sea else UiKit.GREEN, 2.5, now * 0.001)
			if e.size() > 4 and bool(e[4]):
				var mid2: Vector2 = spl[spl.size() / 2]
				draw_string_outline(f, mid2 + Vector2(4, -4), Loc.t("ЖД ЗАПРЕЩЕНА"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, U.DARK)
				draw_string(f, mid2 + Vector2(4, -4), Loc.t("ЖД ЗАПРЕЩЕНА"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("b9b2a2"))
			if sea:
				var mid: Vector2 = spl[spl.size() / 2]
				draw_string_outline(f, mid + Vector2(4, -4), Loc.t("ДЕСАНТ"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, U.DARK)
				draw_string(f, mid + Vector2(4, -4), Loc.t("ДЕСАНТ"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8fd2ff"))
		for e2: Array in pv["bad"]:
			var c2: Vector2 = _center(per, int(e2[0]), Vector2.INF)
			if c2.is_finite():
				var p2: Vector2 = cam.world_to_screen(c2)
				draw_line(p2 + Vector2(-6, -6), p2 + Vector2(6, 6), UiKit.RED, 3.0)
				draw_line(p2 + Vector2(6, -6), p2 + Vector2(-6, 6), UiKit.RED, 3.0)
		var tp: Vector2 = cam.world_to_screen(pv["to"])
		var tc: Color = UiKit.GREEN if (pv.get("bad", []) as Array).is_empty() else (UiKit.RED if (pv.get("ok", []) as Array).is_empty() else UiKit.GOLD)
		draw_arc(tp, 14.0, 0.0, TAU, 28, U.DARK, 5.0)
		draw_arc(tp, 14.0, 0.0, TAU, 28, tc, 3.0)
		draw_circle(tp, 3.0, tc)



	var dt: float = clampf(float(now - _pl_ms) * 0.001, 0.0, 0.25) if _pl_ms > 0 else 0.0
	_pl_ms = now
	var hold: bool = stick
	var items: Array = []
	var seen: Dictionary = {}
	if _pl_gw != gw:
		_pl_gw = gw
		_pl.clear()
		_core.clear()
	for g: Dictionary in gw.player.army_groups:



		var s: = Vector2.ZERO
		var n: int = 0
		for fid3: int in g["fids"]:
			var e3: Array = per.get(fid3, [])
			if not e3.is_empty():
				var k3: Array = _core_of(fid3, e3, now)
				s += (k3[0] as Vector2) * float(k3[1])
				n += int(k3[1])
			hid[fid3] = true
		if n == 0:
			continue
		var gid: int = int(g["id"])
		seen[gid] = true
		var gs: Dictionary = ux.gst(gid).duplicate()
		var raw: String = String(gs.get("key", "idle"))
		var mm: Dictionary = _pl.get(gid, {})
		if mm.is_empty():
			mm = {"fid": -1, "wp": Vector2.INF, "key": raw, "kc": "", "kt": 0.0, "full": false, "ft": 0.0, "off": 0, "bt": 0.0, "ro": Vector2.INF, "co": Vector2.INF, "new": true}
			_pl[gid] = mm

		if raw == String(mm["key"]) or not hold:
			mm["key"] = raw
			mm["kc"] = ""
			mm["kt"] = 0.0
		else:
			if raw != String(mm["kc"]):
				mm["kc"] = raw
				mm["kt"] = 0.0
			mm["kt"] = float(mm["kt"]) + dt
			var need: float = FIGHT_IN if raw == "fight" else (FIGHT_OUT if String(mm["key"]) == "fight" else KEY_HOLD)
			if float(mm["kt"]) >= need:
				mm["key"] = raw
				mm["kc"] = ""
				mm["kt"] = 0.0
		gs["key"] = String(mm["key"])


		var mean: Vector2 = s / float(n)
		var fighting: bool = String(mm["key"]) == "fight"
		var best: int = -1
		var bsc: float = INF
		var csc: float = INF
		var cur: int = int(mm["fid"])
		for fid6: int in g["fids"]:
			if not per.has(fid6):
				continue
			var c6: Vector2 = (_core[fid6] as Array)[0]
			var sc: float = c6.distance_to(mean) + (240.0 if fighting and String(ux.ast(fid6).get("key", "")) != "fight" else 0.0)
			if fid6 == cur:
				csc = sc
			if sc < bsc:
				bsc = sc
				best = fid6
		if csc == INF or not hold:
			cur = best
			mm["bt"] = 0.0
		elif best != cur and bsc < csc - maxf(24.0, csc * 0.25):
			mm["bt"] = float(mm["bt"]) + dt
			if float(mm["bt"]) >= ANC_HOLD:
				cur = best
				mm["bt"] = 0.0
		else:
			mm["bt"] = 0.0
		mm["fid"] = cur
		var tw: Vector2 = (_core[cur] as Array)[0] if per.has(cur) and _core.has(cur) else mean
		var wp: Vector2 = mm["wp"]
		if not hold or not wp.is_finite() or wp.distance_to(tw) > 600.0:
			wp = tw
		else:
			wp = wp.lerp(tw, 1.0 - exp( - dt * 6.0))
		mm["wp"] = wp
		var p: Vector2 = cam.world_to_screen(wp)
		if p.y < top or p.y > bot or p.x < -20.0 or p.x > vr.size.x + 20.0:
			continue
		var sel: bool = gid == cg and view in ["group", "place"]
		var prio: int = (100000 if sel else 0) + (50000 if fighting else 0) + (20000 if hold and bool(mm["full"]) else 0) + mini(int(gs.get("n", 0)), 9999)
		items.append({"g": g, "p": p, "gs": gs, "sel": sel, "prio": prio, "m": mm, "gid": gid})
	for k0: Variant in _pl.keys():
		if not seen.has(k0):
			_pl.erase(k0)
	for k1: Variant in _core.keys():
		if not per.has(k1):
			_core.erase(k1)
	items.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a["prio"]) > int(b["prio"]) or (int(a["prio"]) == int(b["prio"]) and int(a["gid"]) < int(b["gid"])))
	var taken: Array = []
	for kr: Rect2 in MD.keep_out:
		taken.append(kr)
	var full_n: int = 0
	var far: bool = z < FAR_ZOOM + 0.15
	for it: Dictionary in items:
		var g2: Dictionary = it["g"]
		var gs2: Dictionary = it["gs"]
		var mm2: Dictionary = it["m"]
		var key: String = String(gs2.get("key", "idle"))
		var stx: Array = AS.ST[key]
		var col: Color = U.color(int(g2["color"]))
		var p3: Vector2 = it["p"]
		var sel2: bool = bool(it["sel"])
		var name: String = Loc.name(String(g2["name"])).to_upper()
		var word: String = String(stx[0])
		if word.find(name) >= 0 or name.find(String(stx[1])) >= 0:
			word = ""
		var nw: float = f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var ww: float = (f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 14.0) if word != "" else 0.0
		var bw: float = roundf(30.0 + maxf(nw, ww) + 8.0)
		var bh: float = 34.0 if word != "" else 24.0
		var offs: Array = [Vector2(0, -26), Vector2(0, -26 - bh - 6), Vector2(bw * 0.5 + 10, - bh * 0.5), Vector2( - bw * 0.5 - 10, - bh * 0.5), Vector2(0, -26 - 2.0 * (bh + 6))]
		var allowed: bool = sel2 or key == "fight" or ( not far and full_n < MAX_FULL)
		var r: = Rect2()
		var oi: int = -1
		if allowed:
			var order: Array = [clampi(int(mm2["off"]), 0, offs.size() - 1)]
			for i5: int in offs.size():
				if i5 != int(order[0]):
					order.append(i5)
			for i6: int in order:
				var rr: = Rect2((p3 + (offs[i6] as Vector2) - Vector2(bw * 0.5, bh)).round(), Vector2(bw, bh))
				if rr.position.y < top or rr.end.y > bot or rr.position.x < 2.0 or rr.end.x > vr.size.x - 2.0:
					continue
				var free: bool = true
				for t: Rect2 in taken:
					if t.grow(2.0).intersects(rr):
						free = false
						break
				if free:
					r = rr
					oi = i6
					break

		var full: bool = r.size.x > 0.0
		var was: bool = bool(mm2["full"])
		if full == was or not hold or bool(mm2["new"]) or not allowed or sel2:
			mm2["ft"] = 0.0
		else:
			mm2["ft"] = float(mm2["ft"]) + dt
			if float(mm2["ft"]) < FOLD_HOLD:
				full = was
				if full:
					oi = clampi(int(mm2["off"]), 0, offs.size() - 1)
					r = Rect2((p3 + (offs[oi] as Vector2) - Vector2(bw * 0.5, bh)).round(), Vector2(bw, bh))
			else:
				mm2["ft"] = 0.0
		mm2["new"] = false
		mm2["full"] = full
		if full:
			mm2["off"] = oi
			mm2["co"] = Vector2.INF
			full_n += 1
			taken.append(r)
			var ro: Vector2 = r.position - p3
			var ro0: Vector2 = mm2["ro"]
			if hold and ro0.is_finite() and ro0.distance_to(ro) < 240.0:
				ro = ro0.lerp(ro, 1.0 - exp( - dt * 14.0))
			mm2["ro"] = ro
			r = Rect2((p3 + ro).round(), r.size)
			var foot: = Vector2(r.get_center().x, r.end.y)
			draw_line(foot, p3, U.DARK, 3.0)
			draw_line(foot, p3, col, 1.0)
			draw_circle(p3, 4.0, U.DARK)
			draw_circle(p3, 3.0, col)
			draw_rect(r.grow(1.0), U.DARK)
			draw_rect(r, Color(0.09, 0.07, 0.05, 0.94))
			draw_rect(Rect2(r.position, Vector2(4, r.size.y)), col)
			if sel2:
				draw_rect(r.grow(2.0), UiKit.GOLD, false, 2.0)
			var ec: Vector2 = r.position + Vector2(18, r.size.y * 0.5)
			draw_circle(ec, 11.0, U.DARK)
			draw_circle(ec, 10.0, col.darkened(0.5))
			U.draw_emblem(self, String(g2["emblem"]), ec - Vector2(7, 7), 0.9, col.lightened(0.2))
			var tp1: Vector2 = r.position + Vector2(34, 15 if word != "" else 16)
			draw_string_outline(f, tp1, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, U.DARK)
			draw_string(f, tp1, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
			if word != "":
				var ic: Texture2D = U.tex(String(stx[3]))
				if ic != null:
					draw_texture_rect(ic, Rect2(r.position + Vector2(34, 18), Vector2(11, 11)), false)
				var tp2: Vector2 = r.position + Vector2(48, 28)
				draw_string_outline(f, tp2, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 4, U.DARK)
				draw_string(f, tp2, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, stx[2])
			var hp: float = float(gs2.get("hp", 0.0))
			draw_rect(Rect2(r.position + Vector2(4, r.size.y - 3), Vector2((r.size.x - 4) * hp, 3)), AS.hp_col(hp))
			_hits.append([Rect2(r.get_center() - Vector2(maxf(r.size.x, 44.0), maxf(r.size.y, 44.0)) * 0.5, Vector2(maxf(r.size.x, 44.0), maxf(r.size.y, 44.0))), "g", int(g2["id"])])
			if plate_log_on:
				plate_log.append([Engine.get_process_frames(), int(it["gid"]), key, true, int(mm2["fid"]), r.position, word])
		else:
			mm2["ro"] = Vector2.INF
			var cc: Vector2 = p3 + Vector2(0, -22)
			var rr2: = Rect2(cc - Vector2(15, 15), Vector2(30, 30))
			for k in 4:
				var hit2: bool = false
				for t2: Rect2 in taken:
					if t2.intersects(rr2):
						hit2 = true
						break
				if not hit2:
					break
				cc += Vector2(0, -32) if k % 2 == 0 else Vector2(32, 0)
				rr2 = Rect2(cc - Vector2(15, 15), Vector2(30, 30))
			taken.append(rr2)
			var co: Vector2 = cc - p3
			var co0: Vector2 = mm2["co"]
			if hold and co0.is_finite() and co0.distance_to(co) < 240.0:
				co = co0.lerp(co, 1.0 - exp( - dt * 14.0))
			mm2["co"] = co
			cc = (p3 + co).round()
			if cc.distance_to(p3) > 18.0:
				draw_line(cc, p3, U.DARK, 3.0)
				draw_line(cc, p3, col, 1.0)
			draw_circle(cc, 15.0, U.DARK)
			draw_arc(cc, 13.0, 0.0, TAU, 24, stx[2], 3.0)
			draw_circle(cc, 11.0, col.darkened(0.5))
			U.draw_emblem(self, String(g2["emblem"]), cc - Vector2(7, 7), 0.9, col.lightened(0.2))
			if key in ["fight", "march", "sea"]:
				var sw: String = String(stx[1])
				var sws: float = f.get_string_size(sw, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
				draw_string_outline(f, cc + Vector2( - sws * 0.5, 25), sw, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 4, U.DARK)
				draw_string(f, cc + Vector2( - sws * 0.5, 25), sw, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, stx[2])
			_hits.append([Rect2(cc - Vector2(22, 22), Vector2(44, 44)), "g", int(g2["id"])])
			if plate_log_on:
				plate_log.append([Engine.get_process_frames(), int(it["gid"]), key, false, int(mm2["fid"]), cc, ""])

	if not far:
		for fid4: int in per:
			var fac: Facility = ArmyGroups.fac(gw, fid4)
			if fac == null or fac.group_id >= 0:
				continue
			hid[fid4] = true
			var p4: Vector2 = cam.world_to_screen(_center(per, fid4, Vector2.INF))
			if p4.y < top or p4.y > bot or not vr.has_point(p4):
				continue
			var t4: String = Loc.no(fac.army_no)
			var w4: float = f.get_string_size(t4, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 10.0
			var r4: = Rect2((p4 + Vector2( - w4 * 0.5, -30.0)).round(), Vector2(roundf(w4), 18.0))
			var clash: bool = false
			for t3: Rect2 in taken:
				if t3.intersects(r4):
					clash = true
					break
			if clash:
				continue
			taken.append(r4)
			draw_rect(r4.grow(1.0), U.DARK)
			draw_rect(r4, Color(0.2, 0.18, 0.14, 0.92))
			draw_string(f, r4.position + Vector2(5, 13), t4, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
			_hits.append([Rect2(r4.get_center() - Vector2(22, 22), Vector2(44, 44)), "a", fid4])
	if view == "place":
		var hint: = Loc.t("Один палец — линия · два пальца — карта") if bool(ux.get("draw_on")) else Loc.t("Коснитесь цели · карту можно двигать")
		var hs2: Vector2 = f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var hp2: = Vector2(roundf((vr.size.x - hs2.x) * 0.5), bot - 12.0)
		draw_string_outline(f, hp2, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, U.DARK)
		draw_string(f, hp2, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiKit.GOLD)
	MD.pennants_on = true
	for h4: Array in _hits:
		MD.pen_rects.append(h4[0])
	OpsLayer.pennant_fids = hid


func _mark(cam: MapCamera, f: Font, per: Dictionary, fid: int, col: Color, label: String) -> void :
	var e: Array = per.get(fid, [])
	if e.is_empty():
		return
	var z: float = cam.zoom.x
	for sp: Vector2 in e[2]:
		var up: Vector2 = cam.world_to_screen(sp)
		draw_arc(up, clampf(6.0 * z, 5.0, 10.0), 0.0, TAU, 12, U.DARK, 3.0)
		draw_arc(up, clampf(6.0 * z, 5.0, 10.0), 0.0, TAU, 12, col, 1.5)
	var c: Vector2 = cam.world_to_screen((e[0] as Vector2) / float(e[1]))
	var tw: float = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var r: = Rect2((c + Vector2( - tw * 0.5 - 5, -40)).round(), Vector2(roundf(tw + 10), 18))
	draw_rect(r.grow(1.0), U.DARK)
	draw_rect(r, Color(0.35, 0.27, 0.05, 0.95))
	draw_string(f, r.position + Vector2(5, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)




func hit_at(pos: Vector2) -> Array:
	var best: Array = []
	var bd: float = INF
	for e: Array in _hits:
		var r: Rect2 = e[0]
		if r.has_point(pos):
			var d: float = r.get_center().distance_to(pos)
			if d < bd:
				bd = d
				best = [e[1], e[2]]
	if not best.is_empty() and bd > 12.0 and _own_unit_at(pos):
		return []
	return best
