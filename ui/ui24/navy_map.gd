extends Control










const U = preload("res://ui/ui24/arm_kit.gd")
const MD = preload("res://ui/ui24/map_declutter.gd")
const PK = preload("res://ui/ui24/path_kit.gd")
const FAR_ZOOM: float = 0.55
const HULL_S: Array = [17, 21, 27]
const C_OWN: = Color("5cb6ff")
const C_ALLY: = Color("62d68e")
const C_NEUTRAL: = Color("d9cfb2")
const C_WAR: = Color("ff5a42")
const MARK: Array[String] = ["ship_marker_light", "ship_marker_medium", "ship_marker_heavy"]

var hud: Node
var gw: GameWorld
var dock: Node
var _dash: float = 0.0
var _on: bool = false
var _pen_hits: Array = []
var _fleet_no: Dictionary = {}
var _was_merged: Dictionary = {}


func mount(h: Node, d: Node) -> void :
	hud = h
	gw = h.gw
	dock = d
	name = "NavyMap"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.root.add_child(self)
	h.root.move_child(self, mini(1, h.root.get_child_count() - 1))


func _process(delta: float) -> void :
	var nv: Navy = gw.get("navy") as Navy if gw != null else null
	var want: bool = nv != null and gw.player != null and hud.main_node.get("cam") != null\
	and (bool(dock.is_open) or not nv.ships.is_empty())
	if want != _on or want:
		_on = want
		_dash = fmod(_dash + delta * 12.0, 12.0)
		queue_redraw()



func pennant_at(sp: Vector2) -> int:
	for e: Array in _pen_hits:
		if (e[0] as Rect2).has_point(sp):
			return int(e[1])
	return 0


func _rel_col(c: int) -> Color:
	var me: int = gw.player.id
	if c == me:
		return C_OWN
	var dp: Diplomacy = gw.diplo
	if gw.navy._hostile(me, c) or (dp != null and dp.at_war(me, c)):
		return C_WAR
	if dp != null and (dp.allied(me, c) or (dp.has_method("subject_of") and (dp.subject_of(c) == me or dp.subject_of(me) == c))):
		return C_ALLY
	return C_NEUTRAL


func _draw() -> void :
	_pen_hits.clear()
	if not _on:
		return
	var nv: Navy = gw.navy
	var main: Node = hud.main_node
	var cam: MapCamera = main.cam
	var z: float = cam.zoom.x
	var open: bool = bool(dock.is_open)
	var vr: Rect2 = get_viewport_rect().grow(40.0)
	var me: int = gw.player.id
	var mine: Array[Ship] = nv.ships_of(me, true)
	var hi: Dictionary = {}
	if open:
		if dock.mode == "ship":
			hi[int(dock.sel_sid)] = true
		elif dock.selecting:
			hi = dock.checked
		else:
			for s0: Ship in mine:
				if int(dock.tab_fid) > 0 and s0.fleet == int(dock.tab_fid):
					hi[s0.id] = true
				elif int(dock.tab_fid) == -1 and int(dock.call("_fleet_key", s0)) == 0:
					hi[s0.id] = true
			if int(dock.sel_sid) != 0:
				hi[int(dock.sel_sid)] = true
	var fcol: Dictionary = {}
	var fname: Dictionary = {}
	_fleet_no.clear()
	for fl: Dictionary in dock.fleets():
		fcol[int(fl["id"])] = dock.fleet_color(fl)
		fname[int(fl["id"])] = Loc.uname(String(fl.get("name", "")))
		_fleet_no[int(fl["id"])] = _fleet_no.size() + 1
	var placing: String = String(dock.placing) if open else ""

	for s: Ship in mine:
		if hi.has(s.id):
			var sp: Vector2 = cam.world_to_screen(s.pos)
			if vr.has_point(sp):
				var r: float = clampf((14.0 + 6.0 * float(s.hull)) * z, 9.0, 34.0)
				var c: Color = fcol.get(s.fleet, UiKit.GOLD)
				draw_arc(sp, r + 1.5, 0.0, TAU, 32, Color(0.06, 0.04, 0.02, 0.7), 4.0)
				draw_arc(sp, r, 0.0, TAU, 32, c, 2.0)
			if placing == "":
				var o: Dictionary = s.ord if s.fleet == 0 else (dock.fleet(s.fleet).get("order", {}) as Dictionary)
				var k: String = String(o.get("k", ""))
				if k in ["move", "patrol", "hunt", "escort"] and o.get("pos") is Vector2 and s.state == Ship.State.SAIL:
					var gp: Vector2 = cam.world_to_screen(o["pos"])
					PK.line(self, sp, gp, Color("7cc0f0", 0.85), 2.0, _now(), 1.0, {"trim": 2.0})

	if int(main.get("mode")) == int(main.Mode.SHIP_CR):
		_cr_overlay(nv, main, cam, z, mine)

	if placing != "":
		var rp: PackedVector2Array = dock.route_pts
		if rp.size() >= 2:
			var pts: = PackedVector2Array()
			for q: Vector2 in rp:
				pts.append(cam.world_to_screen(q))
			PK.draw(self, pts, Color("7cc0f0"), 4.0, _now())
		var t: Vector2 = dock.target
		if t.is_finite():
			var tp: Vector2 = cam.world_to_screen(t)
			var strike: bool = placing in ["asm", "cm", "hunt"]
			var col: Color = UiKit.RED if strike else Color("7cc0f0")
			var wp: Vector2 = dock.route_wp
			for e: Array in (dock.pv as Dictionary).get("ends", []):
				var s2: Ship = nv.ship(int(e[0]))
				if s2 == null:
					continue
				var a: Vector2 = cam.world_to_screen(s2.pos)
				if wp.is_finite():
					PK.draw(self, PackedVector2Array([a, cam.world_to_screen(wp), tp]), col, 2.5, _now(), 1.0, {"trim": 16.0})
				else:
					PK.line(self, a, tp, col, 2.5, _now(), 1.0, {"trim": 16.0})
			if placing in ["patrol", "hunt", "escort"]:
				var rr: float = (2500.0 if placing == "hunt" else 300.0) * z
				draw_arc(tp, rr, 0.0, TAU, 64, Color(col.r, col.g, col.b, 0.55), 2.0)
			_target(tp, col)

	var now: int = Time.get_ticks_msec()
	var qm: Array = dock.quick_marks
	for i in range(qm.size() - 1, -1, -1):
		var age: float = float(now - int(qm[i][1])) / 1000.0
		if age > 1.4:
			qm.remove_at(i)
			continue

	_markers(nv, cam, z, vr, mine, hi, fcol, fname)



func _markers(nv: Navy, cam: MapCamera, z: float, vr: Rect2, mine: Array[Ship], hi: Dictionary, fcol: Dictionary, fname: Dictionary) -> void :
	MD.begin("navy")
	var a: SpriteAtlas = gw.get("atlas_navy1") as SpriteAtlas
	if a == null or not a.has(MARK[0]):
		return
	var me: int = gw.player.id
	var seen: Array = []
	for s: Ship in nv.ships:
		if not s.alive():
			continue
		if s.c != me and gw.vision != null and not gw.vision.shows_ship(s.c, s.pos):
			continue
		var p: Vector2 = cam.world_to_screen(s.pos)
		if vr.has_point(p):
			seen.append([s, p])
	if z < FAR_ZOOM:

		var acc: Dictionary = {}
		var rest: Array = []
		var chosen: Array = []
		for e: Array in seen:
			var s1: Ship = e[0]
			if hi.has(s1.id):
				chosen.append(e)
			elif s1.c == me and s1.fleet != 0 and fcol.has(s1.fleet):
				var g: Array = acc.get(s1.fleet, [Vector2.ZERO, 0])
				g[0] = (g[0] as Vector2) + (e[1] as Vector2)
				g[1] = int(g[1]) + 1
				acc[s1.fleet] = g
			else:
				rest.append(e)

		var cl: Array = []
		for e2: Array in rest:
			var s2: Ship = e2[0]
			var col: Color = _rel_col(s2.c)
			var p2: Vector2 = e2[1]
			var put: bool = false
			for c: Array in cl:
				if (c[2] as Color) == col and ((c[0] as Vector2) / float(int(c[1]))).distance_to(p2) < 26.0:
					c[0] = (c[0] as Vector2) + p2
					c[1] = int(c[1]) + 1
					c[3] = maxi(int(c[3]), s2.hull)
					put = true
					break
			if not put:
				cl.append([p2, 1, col, s2.hull])
		for c2: Array in cl:
			var at: Vector2 = ((c2[0] as Vector2) / float(int(c2[1]))).round() + Vector2(0, -3)
			_badge(a, at, int(c2[3]), c2[2], 1.0, 0, Color.WHITE, -1.0, "×%d" % int(c2[1]) if int(c2[1]) > 1 else "")
		for fid: int in acc:
			var g2: Array = acc[fid]
			var at2: Vector2 = ((g2[0] as Vector2) / float(int(g2[1]))).round()
			_fleet_pen(a, at2, fcol[fid], "%s ×%d" % [String(fname[fid]).to_upper(), int(g2[1])], fid)
		for e4: Array in chosen:
			var s4: Ship = e4[0]
			_badge(a, ((e4[1] as Vector2) - Vector2(0, 6)).round(), s4.hull, _rel_col(s4.c), 1.0, int(_fleet_no.get(s4.fleet, 0)) if s4.fleet != 0 else 0, fcol.get(s4.fleet, Color.WHITE), -1.0, "", true)
		return


	if z < 1.0:
		var fl_pts: Dictionary = {}
		for e5: Array in seen:
			var s5: Ship = e5[0]
			if s5.c == me and s5.fleet != 0 and fcol.has(s5.fleet):
				var lst: Array = fl_pts.get(s5.fleet, [])
				lst.append(e5)
				fl_pts[s5.fleet] = lst
		var merged: Dictionary = {}
		for fid2: int in fl_pts:
			var lst2: Array = fl_pts[fid2]
			if lst2.size() < 2:
				continue
			var bb: = Rect2((lst2[0][1] as Vector2), Vector2.ZERO)
			var any_hi: bool = false
			var sum: = Vector2.ZERO
			for e6: Array in lst2:
				bb = bb.expand(e6[1] as Vector2)
				sum += e6[1] as Vector2
				any_hi = any_hi or hi.has((e6[0] as Ship).id)
			var lim: float = 110.0 if _was_merged.has(fid2) else 90.0
			if any_hi or bb.size.x > lim or bb.size.y > lim:
				continue
			merged[fid2] = true
			_fleet_pen(a, (sum / float(lst2.size())).round(), fcol[fid2], "%s ×%d" % [String(fname[fid2]).to_upper(), lst2.size()], fid2)
		var keep: Array = []
		var grp: Array = []
		for e7: Array in seen:
			var s7: Ship = e7[0]
			if s7.fleet != 0 and merged.has(s7.fleet) and s7.c == me:
				continue
			if s7.c == me or hi.has(s7.id):
				keep.append(e7)
				continue
			var col7: Color = _rel_col(s7.c)
			var joined: bool = false
			for gq: Array in grp:
				if (gq[2] as Color) == col7 and ((gq[0] as Vector2) / float(int(gq[1]))).distance_to(e7[1]) < 18.0:
					gq[0] = (gq[0] as Vector2) + (e7[1] as Vector2)
					gq[1] = int(gq[1]) + 1
					gq[3] = maxi(int(gq[3]), s7.hull)
					joined = true
					break
			if not joined:
				grp.append([e7[1], 1, col7, s7.hull, e7])
		for gq2: Array in grp:
			if int(gq2[1]) == 1:
				keep.append(gq2[4])
			else:
				_badge(a, ((gq2[0] as Vector2) / float(int(gq2[1]))).round() + Vector2(0, -6), int(gq2[3]), gq2[2], 1.0, 0, Color.WHITE, -1.0, "×%d" % int(gq2[1]))
		_was_merged = merged
		seen = keep

	var k: float = 2.0 if z >= 2.0 else 1.0
	var bw: float = 15.0 * k
	var bh: float = 13.0 * k
	seen.sort_custom( func(x: Array, y: Array) -> bool:
		var hx: bool = hi.has((x[0] as Ship).id)
		var hy: bool = hi.has((y[0] as Ship).id)
		if hx != hy:
			return hx
		return (x[1] as Vector2).y > (y[1] as Vector2).y)
	var taken: Array = MD.label_rects(gw, cam)
	for e3: Array in seen:
		var s3: Ship = e3[0]
		var p3: Vector2 = e3[1]
		var lift: float = float(HULL_S[clampi(s3.hull, 0, 2)]) * 0.55 * z + 3.0
		var tip: Vector2 = (p3 - Vector2(0, lift)).round()
		var chip: bool = s3.c == me and s3.fleet != 0 and fcol.has(s3.fleet)
		var ww: float = bw + (7.0 if chip else 0.0)
		var placed: Vector2 = Vector2.INF
		for off: Vector2 in [Vector2.ZERO, Vector2(ww + 2, 0), Vector2( - ww - 2, 0), Vector2(0, - bh - 4), Vector2(ww + 2, - bh - 4), Vector2( - ww - 2, - bh - 4), Vector2(0, -2 * bh - 8)]:
			var q: Vector2 = tip + off
			var rr: = Rect2(q + Vector2( - bw * 0.5 - 1, - bh - 4), Vector2(ww + 2, bh + 5))
			var free: bool = true
			for t: Rect2 in taken:
				if t.intersects(rr):
					free = false
					break
			if free:
				placed = q
				taken.append(rr)
				break
		var col3: Color = _rel_col(s3.c)
		if placed == Vector2.INF:
			draw_circle(p3, 3.5, U.DARK)
			draw_circle(p3, 2.5, col3)
			continue
		if placed.distance_to(tip) > 1.0:
			draw_line(p3, placed, U.DARK, 3.0)
			draw_line(p3, placed, col3.lightened(0.25), 1.0)
		var hpf: float = s3.hp / maxf(1.0, s3.hp_max) if s3.hp < s3.hp_max else -1.0
		_badge(a, placed, s3.hull, col3, k, int(_fleet_no.get(s3.fleet, 0)) if chip else 0, fcol.get(s3.fleet, Color.WHITE), hpf, "", hi.has(s3.id))



func _badge(a: SpriteAtlas, tip: Vector2, hull: int, col: Color, k: float, chip_no: int, chip_col: Color, hpf: float, tail: String, on: bool = false) -> void :
	var nm: String = MARK[clampi(hull, 0, 2)]
	var inf: Dictionary = a.info(nm)
	var w: float = float(inf["w"]) * k
	var h: float = float(inf["h"]) * k
	var o: Vector2 = tip - Vector2(float(inf["ax"]), float(inf["ay"])) * k
	var dst: = Rect2(o.round(), Vector2(w, h))
	var ka: float = MD.KEEP_A if not on and MD.kept(dst) else 1.0
	MD.note("navy" if ka > 0.5 else "navy_faint", dst)
	if on:
		draw_rect(dst.grow(2.0), Color(UiKit.GOLD, 0.9), false, 2.0)
	draw_texture_rect_region(a.texture, dst, a.rect(nm, 0), Color(col, ka))
	draw_texture_rect_region(a.texture, dst, a.rect(nm, 1), Color(1, 1, 1, ka))
	if ka < 1.0:
		return
	if chip_no > 0:
		var cr: = Rect2(Vector2(dst.end.x - 2.0, dst.position.y - 1.0), Vector2(10, 11) * maxf(1.0, k * 0.75))
		draw_rect(cr.grow(1.0), U.DARK)
		draw_rect(cr, chip_col)
		var txt: String = str(chip_no)
		var fs: int = 9 if k < 2.0 else 11
		var tw: float = UiKit.f_black.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tc: Color = U.DARK if chip_col.get_luminance() > 0.55 else Color.WHITE
		draw_string(UiKit.f_black, Vector2(cr.get_center().x - tw * 0.5, cr.end.y - 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
	if hpf >= 0.0:
		var br: = Rect2(Vector2(dst.position.x + 1.0, dst.position.y - 4.0), Vector2(w - 2.0, 3.0))
		draw_rect(br.grow(1.0), U.DARK)
		draw_rect(Rect2(br.position, Vector2(br.size.x * clampf(hpf, 0.0, 1.0), br.size.y)), Palette.c("amber") if hpf > 0.5 else Color(0.9, 0.22, 0.15))
	if tail != "":
		var p: Vector2 = Vector2(dst.end.x + 2.0, dst.position.y + h * 0.5 + 4.0)
		draw_string_outline(UiKit.f_black, p, tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, U.DARK)
		draw_string(UiKit.f_black, p, tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)



func _fleet_pen(a: SpriteAtlas, foot: Vector2, col: Color, label: String, fid: int) -> void :
	if not a.has("fleet_pennant"):
		U.draw_pennant(self, foot, 1.4, col, "emb_arrow", label)
		return
	var inf: Dictionary = a.info("fleet_pennant")
	var k: float = 2.0
	var o: Vector2 = (foot - Vector2(float(inf["ax"]), float(inf["ay"])) * k).round()
	var dst: = Rect2(o, Vector2(float(inf["w"]), float(inf["h"])) * k)
	var lw0: float = UiKit.f_black.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	if MD.kept(Rect2(dst.position, Vector2(dst.size.x + lw0 + 8.0, dst.size.y))):

		for kr: Rect2 in MD.keep_out:
			if kr.intersects(Rect2(dst.position, Vector2(dst.size.x + lw0 + 8.0, dst.size.y))):
				dst.position.x = minf(dst.position.x, kr.position.x - dst.size.x - lw0 - 10.0)
	var vw: float = get_viewport_rect().size.x
	if dst.position.x + dst.size.x + lw0 + 10.0 > vw:
		dst.position.x = vw - dst.size.x - lw0 - 10.0
	for t in 4:
		var me_r: = Rect2(dst.position, Vector2(dst.size.x + lw0 + 8.0, dst.size.y))
		var hit: bool = false
		for e: Array in _pen_hits:
			var o2: Rect2 = (e[0] as Rect2).grow(-8.0)
			if o2.intersects(me_r):
				dst.position.y = o2.end.y + 2.0
				hit = true
		if not hit:
			break
	var foot2: Vector2 = dst.position + Vector2(float(inf["ax"]), float(inf["ay"])) * k
	if foot2.distance_to(foot) > 3.0:
		draw_line(foot, foot2, U.DARK, 3.0)
		draw_line(foot, foot2, col.lightened(0.25), 1.0)
		draw_circle(foot, 2.5, col)
	draw_texture_rect_region(a.texture, dst, a.rect("fleet_pennant", 0), col)
	draw_texture_rect_region(a.texture, dst, a.rect("fleet_pennant", 1))
	var lw: float = UiKit.f_black.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var lp: Vector2 = Vector2(dst.end.x + 2.0, dst.position.y + 12.0)
	draw_rect(Rect2(lp + Vector2(-2, -10), Vector2(lw + 6, 13)), Color(U.DARK, 0.78))
	draw_rect(Rect2(lp + Vector2(-2, -10), Vector2(2, 13)), col)
	draw_string(UiKit.f_black, lp + Vector2(2, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	_pen_hits.append([Rect2(dst.position, Vector2(dst.size.x + lw + 8.0, dst.size.y)).grow(8.0), fid])
	MD.note("navy", Rect2(dst.position, Vector2(dst.size.x + lw + 8.0, dst.size.y)))


func _cr_overlay(nv: Navy, main: Node, cam: MapCamera, z: float, mine: Array[Ship]) -> void :
	var rr: float = Navy.CM_RANGE * z
	for s: Ship in mine:
		if not s.has_mod("vls"):
			continue
		var sp: Vector2 = cam.world_to_screen(s.pos)
		var have: bool = int(s.ammo.get("cm", 0)) > 0
		if rr < 2400.0:
			draw_arc(sp, rr, 0.0, TAU, 96, Color(C_WAR if have else UiKit.MUTED, 0.22), 6.0)
			draw_arc(sp, rr, 0.0, TAU, 96, Color(C_WAR if have else UiKit.MUTED, 0.75), 1.5)
		draw_arc(sp, clampf(20.0 * z, 10.0, 30.0), 0.0, TAU, 28, U.DARK, 4.0)
		draw_arc(sp, clampf(20.0 * z, 10.0, 30.0), 0.0, TAU, 28, UiKit.GOLD if have else UiKit.MUTED, 2.0)
	var mp: Dictionary = main.get("_last_mp") if main.get("_last_mp") is Dictionary else {}
	var done: Dictionary = {}
	for e: Array in mp.get("plan", []):
		var s2: Ship = nv.ship(int(e[0]))
		if s2 == null:
			continue
		var key: String = "%d|%s" % [s2.id, str(e[1])]
		if done.has(key):
			continue
		done[key] = true
		PK.line(self, cam.world_to_screen(s2.pos), cam.world_to_screen(e[1]), C_WAR, 2.5, _now(), 1.0, {"trim": 10.0})


func _now() -> float:
	return Time.get_ticks_msec() * 0.001


func _target(p: Vector2, col: Color) -> void :
	var dk: = Color(0.06, 0.04, 0.02, 0.8 * col.a)
	var wh: = Color(1, 1, 1, col.a)
	draw_arc(p, 15.0, 0.0, TAU, 28, dk, 5.0)
	draw_arc(p, 15.0, 0.0, TAU, 28, col, 3.0)
	for a in 4:
		var v: Vector2 = Vector2.RIGHT.rotated(float(a) * PI * 0.5)
		draw_line(p + v * 9.0, p + v * 21.0, dk, 4.0)
		draw_line(p + v * 9.0, p + v * 21.0, wh, 2.0)
	draw_circle(p, 3.0, wh)
