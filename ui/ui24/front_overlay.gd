extends Control











const U = preload("res://ui/ui24/arm_kit.gd")
const FrontPlan = preload("res://game/front_plan.gd")
const MD = preload("res://ui/ui24/map_declutter.gd")
const ArmyGroups = preload("res://game/army_groups.gd")

const DATA_T: float = 0.5
const TICK_GAP: float = 7.0
const DARK: = Color("1b120c")
const BAD: = Color(0.62, 0.58, 0.52)

var hud: Node
var gw: GameWorld
var dock: Node
var _t: float = 0.0
var _data_t: float = 0.0
var _items: Array = []
var _on: bool = false
var _rects: Array = []
var _own_rects: int = 0
var _sel_any: bool = false
var _ak: float = 1.0
const LP_MS: float = 500.0
const GHOST_MS: float = 2600.0
var _hits: Array = []
var _lp_ms: int = -1
var _lp_gid: int = -1
var _lp_prog: float = -1.0
var _lp_fired: int = -1
var _lp_pos: Vector2 = Vector2.ZERO
var _flash: Array = [-1, 0]
const PENNANT_FAR: float = 0.55





const LANE_D: float = 20.0
const QUIET_GREY: float = 0.15
var dbg: Dictionary = {}
var _dbg_us: Array = []
var _named: Dictionary = {}


const SHARED_COL: = Color("6f685b")
const FAN_PX: float = 9.0
var _sel_key: int = -3


func mount(h: Node, d: Node) -> void :
	hud = h
	gw = h.gw
	dock = d
	name = "FrontOverlay"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.root.add_child(self)

	var pn: Variant = h.get("army_pennants")
	var at: int = mini(1, h.root.get_child_count() - 1)
	if pn is Control and is_instance_valid(pn) and (pn as Control).get_parent() == h.root:
		at = (pn as Control).get_index()
	h.root.move_child(self, at)


func _cam() -> MapCamera:
	return hud.main_node.get("cam") if hud != null and hud.main_node != null else null


func _process(delta: float) -> void :
	if gw == null or gw.player == null or gw.player.eliminated or _cam() == null\
	or (String(hud.get("panel_kind")) == "conference" and bool(hud.call("ui24_open_now"))):
		if _on:
			_on = false
			_items.clear()
			queue_redraw()
		return
	_t += delta
	MD.sel_gid = int(dock.get("tab_gid")) if dock != null and bool(dock.get("is_open")) and not bool(dock.get("selecting")) else -1
	var sk: int = int(dock.get("tab_gid")) if dock != null and bool(dock.get("is_open")) else -2
	if sk != _sel_key:
		_sel_key = sk
		_data_t = 0.0
	_data_t -= delta
	if _data_t <= 0.0:
		_data_t = DATA_T
		_rebuild()
	_poll_press()
	var prev: bool = _placing() != ""
	var want: bool = not _items.is_empty() or prev
	if want or _on:
		_on = want
		queue_redraw()


func _placing() -> String:
	if dock == null or not bool(dock.get("is_open")):
		return ""
	var p: String = String(dock.get("placing"))
	return p if p == "front" or p == "plan" else ""




func _rebuild() -> void :
	_items.clear()
	var pc: Country = gw.player
	for g: Dictionary in pc.army_groups:
		var fr: Dictionary = FrontPlan.front_of(g)
		if fr.is_empty():
			continue
		var col: Color = U.color(int(g["color"]))
		var sl: Array = []
		var sd: Dictionary = FrontPlan.slots_peek(pc, g)
		for fid: int in sd:
			var f: Facility = ArmyGroups.fac(gw, fid)
			if f == null:
				continue
			var s: Array = sd[fid]
			var mem: Array[Unit] = gw.ops._army(f)
			var hp: float = 0.0
			var mhp: float = 0.0
			for u: Unit in mem:
				hp += u.hp
				mhp += u.max_hp
			var cen: Vector2 = gw.ops._centre(mem) if not mem.is_empty() else f.center_px()

			sl.append([s[0], int(s[2]), cen.distance_to(s[0]) < 60.0 and not FrontPlan.running(g), hp / maxf(1.0, mhp), f.army_no, 
				FrontPlan.why_of.has(fid) and not FrontPlan._fp_on(gw.ops.list.get(f, {}))])

		var pl0: Dictionary = FrontPlan.plan_of(g) if FrontPlan.plan_stale(gw, pc, g) == "" else {}
		var gh: Dictionary = g.get("done_arrow", {})
		if not gh.is_empty() and float(Time.get_ticks_msec() - int(gh["ms"])) > GHOST_MS:
			g.erase("done_arrow")
			gh = {}
		_items.append({"pts": fr.get("vis", fr["pts"]), "nrm": fr.get("vnrm", fr["nrm"]), "col": col, "name": Loc.gtag(int(g["id"]), String(g["name"])), 

			"emb": String(g["emblem"]), "own": true, "gid": int(g["id"]), "slots": sl, "plan": pl0, "run": FrontPlan.running(g) and not pl0.is_empty(), "ghost": gh, 
			"active": bool(dock.get("is_open")) and int(dock.get("tab_gid")) == int(g["id"])})
	_split_parts()
	_merge()
	for c: Country in gw.countries:
		if c == pc or c.eliminated or not pc.at_war.has(c.id) or c.army_groups.is_empty():
			continue
		for g2: Dictionary in c.army_groups:
			var fr2: Dictionary = FrontPlan.front_of(g2)
			if fr2.is_empty():
				continue
			var pts: PackedVector2Array = fr2.get("vis", fr2["pts"])
			var nrm: PackedVector2Array = fr2.get("vnrm", fr2["nrm"])
			var cur: = PackedVector2Array()
			var curn: = PackedVector2Array()
			for i in pts.size():
				if gw.ops._visible(pts[i], c.id):
					cur.append(pts[i])
					curn.append(nrm[i])
				elif cur.size() >= 2:
					_items.append({"pts": cur, "nrm": curn, "col": c.color, "name": Loc.name(c.name).to_upper(), "emb": "", "own": false, "gid": -1, "slots": [], "plan": {}, "active": false, "cid": c.id})
					cur = PackedVector2Array()
					curn = PackedVector2Array()
				else:
					cur.clear()
					curn.clear()
			if cur.size() >= 2:
				_items.append({"pts": cur, "nrm": curn, "col": c.color, "name": Loc.name(c.name).to_upper(), "emb": "", "own": false, "gid": -1, "slots": [], "plan": {}, "active": false, "cid": c.id})






func _split_parts() -> void :
	var out: Array = []
	for it: Dictionary in _items:
		var pts: PackedVector2Array = it["pts"]
		var nrm: PackedVector2Array = it["nrm"]
		var prs: Array = FrontPlan.split_parts(pts)
		if prs.size() <= 1 or nrm.size() != pts.size():
			out.append(it)
			continue
		var first: bool = true
		for pr: Array in prs:
			if int(pr[1]) - int(pr[0]) < 1:
				continue
			var it2: Dictionary = it.duplicate()
			it2["pts"] = pts.slice(int(pr[0]), int(pr[1]) + 1)
			it2["nrm"] = nrm.slice(int(pr[0]), int(pr[1]) + 1)
			if not first:
				it2["slots"] = []
				it2["plan"] = {}
				it2["ghost"] = {}
			first = false
			out.append(it2)
	_items = out


func _lanes() -> void :
	var own: Array = []
	for it: Dictionary in _items:
		if bool(it["own"]):
			own.append(it)
	own.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["active"]) != bool(b["active"]):
			return bool(a["active"])
		return int(a["gid"]) < int(b["gid"]))
	var grid: Dictionary = {}
	for it: Dictionary in own:
		var pts: PackedVector2Array = it["pts"]
		var taken: Dictionary = {}
		var near: int = 0
		for p: Vector2 in pts:
			var c0: = Vector2i(floori(p.x / LANE_D), floori(p.y / LANE_D))
			var hit: bool = false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					for ln: int in grid.get(c0 + Vector2i(dx, dy), []):
						taken[ln] = true
						hit = true
			if hit:
				near += 1
		var lane: int = 0
		if near * 6 >= pts.size():
			while taken.has(lane):
				lane += 1
		it["lane"] = mini(lane, 3)
		for p2: Vector2 in pts:
			var c2: = Vector2i(floori(p2.x / LANE_D), floori(p2.y / LANE_D))
			var a: Array = grid.get(c2, [])
			if not a.has(lane):
				a.append(lane)
			grid[c2] = a








func _merge() -> void :
	var own: Array = []
	var sel: Dictionary = {}
	for it: Dictionary in _items:
		if bool(it["own"]):
			if bool(it["active"]) and sel.is_empty():
				sel = it
			else:
				own.append(it)
	own.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a["gid"]) < int(b["gid"]))
	var grid: Dictionary = {}
	for k in own.size():
		for p: Vector2 in (own[k]["pts"] as PackedVector2Array):
			var c: = Vector2i(floori(p.x / LANE_D), floori(p.y / LANE_D))
			var a: Array = grid.get(c, [])
			if a.is_empty() or int(a[a.size() - 1]) != k:
				a.append(k)
				grid[c] = a
	var sgrid: Dictionary = {}
	if not sel.is_empty():
		sel["runs"] = [{"pts": sel["pts"], "nrm": sel["nrm"], "mem": [], "shared": false, "lane": 0}]
		for p2: Vector2 in (sel["pts"] as PackedVector2Array):
			sgrid[Vector2i(floori(p2.x / LANE_D), floori(p2.y / LANE_D))] = true
	for k2 in own.size():
		var it2: Dictionary = own[k2]
		var pts: PackedVector2Array = it2["pts"]
		var nrm: PackedVector2Array = it2["nrm"]
		var n: int = pts.size()
		var drawn: = PackedByteArray()
		drawn.resize(n)
		var mem: Array = []
		mem.resize(n)
		var near_sel: int = 0
		for i in n:
			var c0: = Vector2i(floori(pts[i].x / LANE_D), floori(pts[i].y / LANE_D))
			var hold: Dictionary = {k2: true}
			var first: bool = true
			var ns: bool = false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var cc: Vector2i = c0 + Vector2i(dx, dy)
					for j: int in grid.get(cc, []):
						hold[j] = true
						if j < k2:
							first = false
					if sgrid.has(cc):
						ns = true
			if ns:
				near_sel += 1
			drawn[i] = 1 if first else 0
			var ks: Array = hold.keys()
			ks.sort()
			var cols: = PackedColorArray()
			for j2: int in ks:
				cols.append(own[j2]["col"])
			mem[i] = cols
		var lane: int = 1 if not sel.is_empty() and near_sel * 6 >= n else 0
		var runs: Array = []
		var i0: int = -1
		for i2 in n + 1:
			var on: bool = i2 < n and drawn[i2] == 1
			if on and i0 < 0:
				i0 = i2
			elif not on and i0 >= 0:
				_add_runs(runs, pts, nrm, mem, maxi(0, i0 - 1), mini(n - 1, i2), lane)
				i0 = -1
		it2["runs"] = runs



func _add_runs(runs: Array, pts: PackedVector2Array, nrm: PackedVector2Array, mem: Array, a: int, b: int, lane: int) -> void :
	if b - a < 1:
		return
	var s0: int = a
	for i in range(a + 1, b + 2):
		var cut: bool = i > b or ((mem[i] as PackedColorArray).size() > 1) != ((mem[s0] as PackedColorArray).size() > 1)
		if not cut:
			continue
		var e: int = mini(i, b)
		if e > s0:
			runs.append({"pts": pts.slice(s0, e + 1), "nrm": nrm.slice(s0, e + 1), "mem": mem.slice(s0, e + 1), 
				"shared": (mem[s0] as PackedColorArray).size() > 1, "lane": lane})
		s0 = e




func _name_run(cam: MapCamera, it: Dictionary, sp: PackedVector2Array) -> Array:
	if not it.has("runs"):
		return [sp, it["nrm"], int(it.get("lane", 0))]
	var best: Dictionary = {}
	for rn: Dictionary in it["runs"]:
		if not bool(rn["shared"]) and (best.is_empty() or (rn["pts"] as PackedVector2Array).size() > (best["pts"] as PackedVector2Array).size()):
			best = rn
	if best.is_empty():
		return []
	return [_to_screen(cam, best["pts"]), best["nrm"], int(best["lane"])]






func _fans(cam: MapCamera) -> Dictionary:
	var out: Dictionary = {}
	var cl: Array = []
	for it: Dictionary in _items:
		var pl: Dictionary = it["plan"]
		if not bool(it["own"]) or pl.is_empty():
			continue
		if not (int(pl.get("state", 0)) == FrontPlan.St.RUN or bool(it["active"]) or gw.player.at_war.has(int(pl.get("foe", -1)))):
			continue
		var tip: Vector2 = cam.world_to_screen(FrontPlan.curve(pl, 1.0))
		var d: Vector2 = (tip - cam.world_to_screen(FrontPlan.curve(pl, 0.9))).normalized()
		cl.append([int(pl.get("city", -1)), int(it["gid"]), tip, d, cam.world_to_screen(FrontPlan.curve(pl, 0.0))])
	var used: Dictionary = {}
	for i in cl.size():
		if used.has(i):
			continue
		var grp: Array = [cl[i]]
		for j in range(i + 1, cl.size()):
			if not used.has(j) and ((int(cl[i][0]) >= 0 and int(cl[i][0]) == int(cl[j][0])) or (cl[i][2] as Vector2).distance_to(cl[j][2]) < 14.0):
				grp.append(cl[j])
				used[j] = true
		if grp.size() < 2:
			continue
		var dm: = Vector2.ZERO
		for e: Array in grp:
			dm += e[3] as Vector2
		dm = dm.normalized() if dm.length() > 0.01 else Vector2.DOWN
		var pv: = Vector2( - dm.y, dm.x)
		grp.sort_custom( func(a: Array, b: Array) -> bool:
			var pa: float = ((a[4] as Vector2) - (a[2] as Vector2)).dot(pv)
			var pb: float = ((b[4] as Vector2) - (b[2] as Vector2)).dot(pv)
			return pa < pb if absf(pa - pb) > 0.5 else int(a[1]) < int(b[1]))
		for k in grp.size():
			var tw: float = 0.0
			for e2: Array in grp:
				if e2 != grp[k] and (e2[4] as Vector2).distance_to(grp[k][4]) < 24.0:
					tw = 1.0
			var o: Vector2 = pv * (float(k) - float(grp.size() - 1) * 0.5) * FAN_PX
			out[int(grp[k][1])] = Vector3(o.x, o.y, tw)
	return out




func _draw() -> void :
	var t0: int = Time.get_ticks_usec()
	_draw_all()
	if MD.rec:
		_dbg_us.append(Time.get_ticks_usec() - t0)
		if _dbg_us.size() > 40:
			_dbg_us.pop_front()
		var srt: Array = _dbg_us.duplicate()
		srt.sort()
		dbg["draw_us"] = srt[srt.size() / 2]


func _draw_all() -> void :
	MD.begin("front")
	_named.clear()
	_own_rects = 0
	if MD.rec:
		dbg["labels"] = []
		dbg["arrow_w"] = []
		dbg["bands"] = []
		dbg["tips"] = []
	if not _on:
		return
	var cam: MapCamera = _cam()
	if cam == null:
		return
	var z: float = cam.zoom.x
	var vr: Rect2 = get_viewport_rect().grow(60.0)
	_rects.clear()
	for kr: Rect2 in MD.keep_out:
		_rects.append(kr)
	var nkeep: int = _rects.size()
	_rects.append_array(MD.label_rects(gw, cam))
	_rects.append_array(MD.pen_rects)
	_hits.clear()
	_sel_any = false
	for it0: Dictionary in _items:
		_sel_any = _sel_any or bool(it0["active"])
	var fan: Dictionary = _fans(cam)
	for it: Dictionary in _items:
		var pl: Dictionary = it["plan"]
		if bool(it["own"]) and not pl.is_empty():

			var act0: bool = bool(it["active"])
			var lv: int = 2 if act0 else (1 if not _sel_any else 0)
			var acol: Color = it["col"] if lv > 0 else (it["col"] as Color).lerp(Color(0.56, 0.54, 0.5), QUIET_GREY)
			var runp: bool = int(pl.get("state", 0)) == FrontPlan.St.RUN
			if runp or lv == 2 or gw.player.at_war.has(int(pl.get("foe", -1))):
				_arrow(cam, pl, acol, String(it["emb"]), "", runp, float(pl.get("s", 0.0)), 1.0 if lv == 2 else (0.9 if lv == 1 else 0.7), lv, fan.get(int(it["gid"]), Vector3.ZERO))
			var ap: = PackedVector2Array()
			for i9 in 17:
				ap.append(FrontPlan.curve(pl, float(i9) / 16.0))
			_hits.append([int(it["gid"]), _to_screen(cam, ap), 16.0])
		var gh: Dictionary = it.get("ghost", {})
		if bool(it["own"]) and not gh.is_empty() and pl.is_empty():

			var ga: float = 1.0 - clampf(float(Time.get_ticks_msec() - int(gh["ms"])) / GHOST_MS, 0.0, 1.0)
			_arrow(cam, gh, it["col"] if bool(gh["ok"]) else BAD, String(it["emb"]), Loc.t("ЦЕЛЬ ВЗЯТА") if bool(gh["ok"]) else "", false, 0.0, ga * ga, 1)
	var order: Array = _items.duplicate()
	order.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(bool(a["own"])) + int(bool(a["active"])) < int(bool(b["own"])) + int(bool(b["active"])))
	var names: Array = []
	for it2: Dictionary in order:
		var sp: PackedVector2Array = _to_screen(cam, it2["pts"])
		if sp.size() < 2 or not vr.intersects(_bbox(sp)):
			continue
		var own: bool = bool(it2["own"])
		if own and it2.has("runs"):
			for rn: Dictionary in it2["runs"]:
				_front(_to_screen(cam, rn["pts"]), rn["nrm"], SHARED_COL if bool(rn["shared"]) else it2["col"], own, bool(it2["active"]), 1.0, int(rn["lane"]), rn["mem"] if bool(rn["shared"]) else [])
		else:
			_front(sp, it2["nrm"], it2["col"], own, bool(it2["active"]), 1.0, int(it2.get("lane", 0)))
		if own:
			_hits.append([int(it2["gid"]), sp, 14.0])
		if own:
			var nr: Array = _name_run(cam, it2, sp)
			if not nr.is_empty():
				names.push_front([nr[0], it2, nr[1], nr[2]])
		elif z >= 0.4:
			names.append([sp, it2, it2["nrm"], 0])
	names.sort_custom( func(a: Array, b: Array) -> bool: return int(bool(a[1]["own"])) + int(bool(a[1]["active"])) > int(bool(b[1]["own"])) + int(bool(b[1]["active"])))
	for nm: Array in names:
		var it3: Dictionary = nm[1]


		var nk: Variant = int(it3["gid"]) if bool(it3["own"]) else "c%d" % int(it3.get("cid", -1))
		if _named.has(nk) or (bool(it3["own"]) and MD.named.has(int(it3["gid"]))):
			continue
		if _name_free(nm[0], nm[2], String(it3["name"]) if bool(it3["own"]) else Loc.t("ФРОНТ · %s") % [String(it3["name"])], (it3["col"] as Color) if bool(it3["own"]) else (it3["col"] as Color).lerp(Color(0.8, 0.78, 0.74), 0.3), z, int(nm[3])):
			_named[nk] = true
			if MD.rec:
				(dbg["labels"] as Array).append(str(nk))
	for it4: Dictionary in order:
		if bool(it4["own"]):
			_counters(cam, it4, z)
	if MD.rec:
		for i9 in range(maxi(nkeep, _rects.size() - _own_rects), _rects.size()):
			MD.note("front", _rects[i9])
	_legend(cam)
	_press_cue()

	var pm: String = _placing()
	if pm == "front":
		var fp: Dictionary = dock.get("front_pv")
		if bool(fp.get("ok", false)):
			var a: float = 0.55 + 0.45 * absf(sin(_t * 5.0))
			var col: Color = _dock_col()
			var fvp: PackedVector2Array = fp.get("vis", fp["pts"])
			var fvn: PackedVector2Array = fp.get("vnrm", fp["nrm"])
			for pr: Array in FrontPlan.split_parts(fvp):
				if int(pr[1]) > int(pr[0]):
					_front(_to_screen(cam, fvp.slice(int(pr[0]), int(pr[1]) + 1)), fvn.slice(int(pr[0]), int(pr[1]) + 1), col, true, true, a)
		var trail: Variant = dock.get("front_trail")
		if trail is PackedVector2Array and (trail as PackedVector2Array).size() >= 2:
			draw_polyline(_to_screen(cam, trail), Color(1, 1, 1, 0.55), 2.0)
	elif pm == "plan":
		var pp: Dictionary = dock.get("plan_pv")
		if not pp.is_empty() and (pp.get("a") as Vector2).is_finite() and (pp.get("b") as Vector2).is_finite():
			var ok: bool = bool(pp.get("ok", false))
			_arrow(cam, pp, _dock_col() if ok else BAD, _dock_emb(), "", false, 0.0, 0.6 + 0.35 * absf(sin(_t * 4.0)) if ok else 0.75, 2)


func _dock_col() -> Color:
	var g: Dictionary = ArmyGroups.by_id(gw, gw.player.id, int(dock.get("tab_gid")))
	return U.color(int(g["color"])) if not g.is_empty() else UiKit.GOLD


func _dock_emb() -> String:
	var g: Dictionary = ArmyGroups.by_id(gw, gw.player.id, int(dock.get("tab_gid")))
	return String(g["emblem"]) if not g.is_empty() else "emb_star"


func _to_screen(cam: MapCamera, pts: PackedVector2Array) -> PackedVector2Array:
	var out: = PackedVector2Array()
	out.resize(pts.size())
	var z: float = cam.zoom.x
	var o: Vector2 = cam.view_size() * 0.5 - cam.position * z
	for i in pts.size():
		out[i] = (pts[i] * z + o).round()
	return out


func _bbox(sp: PackedVector2Array) -> Rect2:
	var r: = Rect2(sp[0], Vector2.ZERO)
	for p: Vector2 in sp:
		r = r.expand(p)
	return r





func _front(sp: PackedVector2Array, nrm: PackedVector2Array, col: Color, own: bool, hot: bool, alpha: float, lane: int = 0, mem: Array = []) -> void :
	var n: int = sp.size()
	if n < 2:
		return
	var z: float = _cam().zoom.x if _cam() != null else 1.0
	var bw: float = roundf(clampf(2.0 + 6.0 * z, 4.0, 8.0)) if own else roundf(clampf(1.0 + 4.0 * z, 3.0, 5.0))


	var quiet: int = 0 if hot or not own or alpha < 0.999 else (2 if _sel_any else 1)
	if quiet == 1:
		bw = roundf(clampf(2.0 + 4.0 * z, 3.0, 6.0))
	elif quiet == 2:
		bw = roundf(clampf(1.0 + 2.0 * z, 2.0, 3.0))
		col = col.lerp(Color(0.56, 0.54, 0.5), QUIET_GREY)
		alpha *= 0.8
	var half: float = bw * 0.5 + float(lane) * (roundf(clampf(2.0 + 6.0 * z, 4.0, 8.0)) + 8.0)


	var shifted: = PackedVector2Array()
	for i0 in n:
		shifted.append((sp[i0] - nrm[mini(i0, nrm.size() - 1)] * (half + 2.0)).round())
	sp = shifted
	if MD.rec and dbg.has("bands"):
		(dbg["bands"] as Array).append(sp)
	var glow: = Color(col.r, col.g, col.b, (0.3 if hot else (0.2 if quiet == 0 else 0.1)) * alpha)
	if quiet < 2:
		draw_polyline(sp, glow, bw + (12.0 if quiet == 0 else 6.0))

	var dots: = PackedVector2Array()
	var lc: Color = col.lightened(0.35)
	for i in n:
		var nv: Vector2 = nrm[i]
		var off: float = half + (6.0 if i % 2 == 0 else 4.0)
		var sgn: float = 1.0 if i % 2 == 0 else -1.0
		var p: Vector2 = (sp[i] + nv * off * sgn).round()
		dots.append(p)
		dots.append(p + Vector2(2, 0))
	if quiet == 0:
		draw_multiline(dots, Color(lc.r, lc.g, lc.b, 0.6 * alpha), 2.0)

	var dark_t: = PackedVector2Array()
	var col_t: = PackedVector2Array()
	var acc: float = 0.0
	var tl: float = (6.0 + 2.0 * clampf(z, 0.0, 1.0)) if own else 4.0
	if quiet > 0:
		tl = 4.0 if quiet == 1 else 3.0
	var gap: float = TICK_GAP + (2.0 if quiet == 0 else (8.0 if quiet == 1 else 12.0))
	var mix: bool = not mem.is_empty()
	for i2 in range(1, n):
		var a: Vector2 = sp[i2 - 1]
		var b: Vector2 = sp[i2]
		var seg: float = a.distance_to(b)
		if seg < 0.01:
			continue
		var t: float = gap - acc
		while t <= seg:
			var u: float = t / seg
			var p2: Vector2 = a.lerp(b, u)
			var nv2: Vector2 = nrm[i2 - 1].lerp(nrm[i2], u).normalized()
			dark_t.append((p2 + nv2 * half).round())
			dark_t.append((p2 + nv2 * (half + tl + 1.0)).round())
			col_t.append((p2 + nv2 * half).round())
			col_t.append((p2 + nv2 * (half + tl)).round())
			t += gap
		acc = seg - (t - gap)
	if not dark_t.is_empty():
		draw_multiline(dark_t, Color(DARK.r, DARK.g, DARK.b, 0.95 * alpha), (5.0 if quiet < 2 else 4.0) if own else 4.0)
		draw_multiline(col_t, Color(col.r, col.g, col.b, alpha), (3.0 if quiet < 2 else 2.0) if own else 2.0)
	draw_polyline(sp, Color(DARK.r, DARK.g, DARK.b, 0.95 * alpha), bw + (4.0 if quiet < 2 else 2.0))
	draw_polyline(sp, Color(col.r, col.g, col.b, alpha), bw)
	if mix:
		_chips(sp, mem, bw, quiet, alpha)
	if quiet < 2 and not mix:
		var core: Color = col.lightened(0.7 if quiet == 0 else 0.45)
		draw_polyline(sp, Color(core.r, core.g, core.b, alpha), maxf(2.0 if quiet == 0 else 1.0, bw - 4.0))




func _chips(sp: PackedVector2Array, mem: Array, bw: float, quiet: int, alpha: float) -> void :
	var per: float = 60.0 if quiet < 2 else 84.0
	var cw: float = 4.0 if quiet < 2 else 3.0
	var th: float = bw + (2.0 if quiet < 2 else 1.0)
	var dk: = Color(DARK.r, DARK.g, DARK.b, 0.95 * alpha)
	var nxt: float = per * 0.5
	var run_l: float = 0.0
	for i in range(1, sp.size()):
		var a: Vector2 = sp[i - 1]
		var b: Vector2 = sp[i]
		var sl: float = a.distance_to(b)
		if sl < 0.01:
			continue
		var tv: Vector2 = (b - a) / sl
		while nxt <= run_l + sl:
			var hc: PackedColorArray = mem[mini(i - 1, mem.size() - 1)]
			var ln: float = cw * float(hc.size())
			var s0: Vector2 = a.lerp(b, (nxt - run_l) / sl) - tv * (ln * 0.5)
			draw_line(s0 - tv * 1.5, s0 + tv * (ln + 1.5), dk, th + 2.0)
			for k in hc.size():
				var hk: Color = hc[k]
				draw_line(s0 + tv * (cw * float(k) + 0.5), s0 + tv * (cw * float(k + 1) - 0.5), Color(hk.r, hk.g, hk.b, alpha), th)
			nxt += per
		run_l += sl





func _name_free(sp: PackedVector2Array, nrm: PackedVector2Array, text: String, col: Color, z: float, lane: int = 0) -> bool:
	for at: float in [0.5, 0.32, 0.68, 0.18, 0.82]:
		if _name_along(sp, nrm, text, col, z, at, lane):
			return true
	return false


func _free(r: Rect2) -> bool:
	for q: Rect2 in _rects:
		if q.intersects(r):
			return false
	return true




func _name_along(sp: PackedVector2Array, nrm: PackedVector2Array, text: String, col: Color, z: float, at: float = 0.5, lane: int = 0) -> bool:
	var f: Font = UiKit.f_black
	var fs: int = 10 if z < 0.9 else 11
	var back: float = 17.0 + float(lane) * 7.0
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var n: int = sp.size()
	var cum: = PackedFloat32Array([0.0])
	for i in range(1, n):
		cum.append(cum[i - 1] + sp[i - 1].distance_to(sp[i]))
	var T: float = cum[n - 1]
	if T < tw + 40.0:
		return false
	var mid: float = clampf(T * at, tw * 0.5 + 20.0, T - tw * 0.5 - 20.0)
	var flip: bool = (sp[n - 1] - sp[0]).x < 0.0

	var box: = Rect2()
	var first: bool = true
	for k: float in [-0.5, 0.0, 0.5]:
		var s0: float = clampf(mid + tw * k * (-1.0 if flip else 1.0), 0.0, T)
		var j0: int = clampi(cum.bsearch(s0), 1, n - 1)
		var u0: float = clampf((s0 - cum[j0 - 1]) / maxf(0.001, cum[j0] - cum[j0 - 1]), 0.0, 1.0)
		var q0: Vector2 = sp[j0 - 1].lerp(sp[j0], u0) - nrm[j0 - 1].lerp(nrm[j0], u0).normalized() * back
		if first:
			box = Rect2(q0, Vector2.ZERO)
			first = false
		else:
			box = box.expand(q0)
	box = box.grow(float(fs) * 0.7)
	if not _free(box):
		return false
	_rects.append(box)
	_own_rects += 1
	var x: float = - tw * 0.5
	for ci in text.length():
		var cs: String = text[ci]
		var cw: float = f.get_string_size(cs, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var s: float = mid + (x + cw * 0.5) * (-1.0 if flip else 1.0)
		var j: int = cum.bsearch(s)
		j = clampi(j, 1, n - 1)
		var seg: float = maxf(0.001, cum[j] - cum[j - 1])
		var u: float = clampf((s - cum[j - 1]) / seg, 0.0, 1.0)
		var p: Vector2 = sp[j - 1].lerp(sp[j], u)
		var tv: Vector2 = (sp[j] - sp[j - 1]).normalized()
		if flip:
			tv = - tv
		var nv: Vector2 = nrm[j - 1].lerp(nrm[j], u).normalized()
		var pos: Vector2 = p - nv * back
		draw_set_transform(pos, tv.angle(), Vector2.ONE)
		var o: = Vector2( - cw * 0.5, float(fs) * 0.38)
		draw_string_outline(f, o, cs, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, DARK)
		draw_string(f, o, cs, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.lightened(0.55))
		x += cw
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true




func _counters(cam: MapCamera, it: Dictionary, z: float) -> void :
	var sl: Array = it["slots"]
	if sl.is_empty():
		return
	var col: Color = it["col"]
	var f: Font = UiKit.f_black




	if z < 0.4 or bool(it.get("run", false)):
		return
	var order: Array = sl.duplicate()
	order.sort_custom( func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]))
	var quiet: bool = not bool(it["active"]) and (z < 2.0 or _sel_any)
	for s: Array in order:
		if bool(s[2]) and z >= PENNANT_FAR:
			continue
		if quiet and not (s.size() > 5 and bool(s[5])):
			continue
		var p: Vector2 = cam.world_to_screen(s[0]).round()
		var sup: bool = int(s[1]) == 1
		var sz: = Vector2(20, 11) if not sup else Vector2(16, 9)
		var r: = Rect2(p - sz * 0.5, sz)
		if not _free(r.grow(1.0)):
			continue
		_rects.append(r.grow(1.0))
		_own_rects += 1
		_box(r.position, r.size, col, bool(s[2]))
		var no: String = str(int(s[4]))
		draw_string_outline(f, r.position + Vector2(5, sz.y - 2), no, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, DARK)
		draw_string(f, r.position + Vector2(5, sz.y - 2), no, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
		if s.size() > 5 and bool(s[5]):

			var br: = Rect2(r.position + Vector2(sz.x + 1, 0), Vector2(8, sz.y))
			draw_rect(br.grow(1.0), DARK)
			draw_rect(br, Color("d8402c"))
			draw_string(f, br.position + Vector2(2, sz.y - 2), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
			_rects.append(br.grow(1.0))
			_own_rects += 1
		var hp: float = clampf(float(s[3]), 0.0, 1.0)
		draw_rect(Rect2(r.position + Vector2(0, sz.y + 1), Vector2(sz.x, 3)), DARK)
		draw_rect(Rect2(r.position + Vector2(1, sz.y + 2), Vector2((sz.x - 2) * hp, 1)), Color("a2e35f") if hp > 0.6 else (Color("ffb000") if hp > 0.3 else Color("ff6a4d")))


func _box(pos: Vector2, sz: Vector2, col: Color, filled: bool) -> void :
	draw_rect(Rect2(pos - Vector2(1, 1), sz + Vector2(2, 2)), DARK)
	draw_rect(Rect2(pos, sz), col.darkened(0.45) if filled else Color(0.1, 0.08, 0.06, 0.55))
	draw_rect(Rect2(pos, Vector2(3, sz.y)), col)
	if filled:
		draw_rect(Rect2(pos + Vector2(3, 0), Vector2(sz.x - 3, 1)), col.lightened(0.2))
	else:
		draw_rect(Rect2(pos, sz), col, false, 1.0)








const ARW_BODY: Array = [3.0, 4.0, 6.0]
const ARW_HEAD_W: Array = [11.0, 13.0, 18.0]
const ARW_HEAD_L: Array = [9.0, 11.0, 15.0]


func _arrow(cam: MapCamera, pl: Dictionary, col: Color, emb: String, label: String, run: bool, s: float, alpha: float, lv: int = 2, fan: Vector3 = Vector3.ZERO) -> void :
	var N: int = 28
	var wp: = PackedVector2Array()
	for i in N + 1:
		wp.append(FrontPlan.curve(pl, float(i) / float(N)))
	var sp: PackedVector2Array = _to_screen(cam, wp)
	if fan != Vector3.ZERO:
		for i5 in sp.size():
			var ft: float = float(i5) / float(N)
			sp[i5] = (sp[i5] + Vector2(fan.x, fan.y) * (fan.z + (1.0 - fan.z) * ft * ft)).round()
	var cum: float = 0.0
	for i2 in range(1, sp.size()):
		cum += sp[i2 - 1].distance_to(sp[i2])
	if cum < 12.0:
		return
	lv = clampi(lv, 0, 2)
	var bw: float = ARW_BODY[lv]
	var hw: float = ARW_HEAD_W[lv]
	var hl: float = minf(ARW_HEAD_L[lv], cum * 0.4)
	var j0: int = 0
	var js: int = clampi(roundi(clampf(s, 0.0, 1.0) * float(N)), 0, N) if run else -1

	var rest: float = 0.0
	for k2 in range(j0 + 1, sp.size()):
		rest += sp[k2 - 1].distance_to(sp[k2])
	if rest < hl + 4.0:
		hl = maxf(6.0, rest * 0.6)
	var body: = PackedVector2Array([sp[j0]])
	var acc: float = 0.0
	var head_base: Vector2 = sp[sp.size() - 1]
	for i3 in range(j0 + 1, sp.size()):
		var seg: float = sp[i3 - 1].distance_to(sp[i3])
		if acc + seg >= rest - hl:
			var u: float = clampf((rest - hl - acc) / maxf(0.001, seg), 0.0, 1.0)
			head_base = sp[i3 - 1].lerp(sp[i3], u)
			body.append(head_base)
			break
		acc += seg
		body.append(sp[i3])
	var tip: Vector2 = sp[sp.size() - 1]
	var dir_end: Vector2 = (tip - head_base).normalized()
	if dir_end == Vector2.ZERO:
		dir_end = (tip - sp[maxi(0, sp.size() - 2)]).normalized()
	var hn: = Vector2( - dir_end.y, dir_end.x)
	if MD.rec and dbg.has("tips"):
		(dbg["tips"] as Array).append(tip)
	var dk: = Color(DARK.r, DARK.g, DARK.b, 0.92 * alpha)
	var cc: = Color(col.r, col.g, col.b, (0.95 if lv == 2 else 0.85) * alpha)
	if body.size() >= 2:
		draw_polyline(body, dk, bw + 3.0)

	var hb2: Vector2 = head_base - dir_end * 1.5
	draw_primitive(PackedVector2Array([hb2 + hn * (hw * 0.5 + 2.0), tip + dir_end * 2.5, hb2 - hn * (hw * 0.5 + 2.0)]), PackedColorArray([dk, dk, dk]), PackedVector2Array())
	if body.size() >= 2:
		if js >= 0 and js < body.size() - 1:
			draw_polyline(body, Color(cc.r, cc.g, cc.b, cc.a * 0.55), bw)
			if js >= 1:
				draw_polyline(body.slice(0, js + 1), cc, bw)
		else:
			draw_polyline(body, cc, bw)
		if lv == 2:
			var lt: Color = col.lightened(0.5)
			draw_polyline(body, Color(lt.r, lt.g, lt.b, 0.8 * alpha), maxf(1.0, bw - 4.0))
	draw_primitive(PackedVector2Array([head_base + hn * hw * 0.5, tip, head_base - hn * hw * 0.5]), PackedColorArray([cc, cc, cc]), PackedVector2Array())
	if MD.rec:
		(dbg["arrow_w"] as Array).append(bw)

	if run and lv >= 1 and body.size() >= 2:
		var ch: = PackedVector2Array()
		var phase: float = fmod(_t * 22.0, 20.0)
		var a2: float = 0.0
		for j4 in range(1, body.size()):
			var seg2: float = body[j4 - 1].distance_to(body[j4])
			var t2: float = phase - a2
			while t2 <= seg2 and t2 >= 0.0:
				var c0: Vector2 = body[j4 - 1].lerp(body[j4], t2 / maxf(0.001, seg2))
				var tv: Vector2 = (body[j4] - body[j4 - 1]).normalized()
				var nv2: = Vector2( - tv.y, tv.x)
				var ww: float = maxf(1.5, bw * 0.4)
				ch.append((c0 - tv * 2.0 + nv2 * ww).round())
				ch.append((c0 + tv * 1.0).round())
				ch.append((c0 + tv * 1.0).round())
				ch.append((c0 - tv * 2.0 - nv2 * ww).round())
				t2 += 20.0
			a2 += seg2
			phase = fmod(phase - seg2, 20.0)
			if phase < 0.0:
				phase += 20.0
		if not ch.is_empty():
			draw_multiline(ch, Color(1, 1, 1, 0.6 * alpha), 1.0)

	if emb != "" and rest > 50.0:
		var ep: Vector2 = sp[j0]
		var r: float = 7.0 if lv == 2 else 5.5
		draw_circle(ep, r + 1.5, Color(DARK.r, DARK.g, DARK.b, alpha))
		draw_circle(ep, r, Color(col.darkened(0.35).r, col.darkened(0.35).g, col.darkened(0.35).b, alpha))
		var ek: float = r * 1.25 / 16.0
		U.draw_emblem(self, emb, (ep - Vector2(8, 8) * ek).round(), ek, Color(1, 1, 1, alpha))
	if label != "":
		var f: Font = UiKit.f_black
		var tsz: Vector2 = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var lp: Vector2 = (tip + Vector2(8, -6)).round()
		var lr: = Rect2(lp + Vector2(-2, - tsz.y + 2), tsz + Vector2(4, 2))
		if _free(lr):
			_rects.append(lr)
			_own_rects += 1
			draw_string_outline(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, Color(DARK.r, DARK.g, DARK.b, alpha))
			draw_string(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(col.lightened(0.55).r, col.lightened(0.55).g, col.lightened(0.55).b, alpha))





func _legend(cam: MapCamera) -> void :
	if dock == null or bool(dock.get("is_open")) or bool(hud.call("ui24_open_now")):
		return
	var mn: Node = hud.main_node
	var stk: Variant = mn.get("strike") if mn != null else null
	if (stk != null and bool(stk.get("active"))) or (hud.get("ops_panel") is Control and (hud.get("ops_panel") as Control).visible):
		return
	var es: Array = []
	var seen: Dictionary = {}
	for it: Dictionary in _items:
		if bool(it["own"]) and not seen.has(int(it["gid"])):
			seen[int(it["gid"])] = true
			es.append(it)
	if es.size() < 3:
		return
	es.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a["gid"]) < int(b["gid"]))
	var f: Font = UiKit.f_black
	var vs: Vector2 = cam.view_size()
	var w: float = 6.0
	for it2: Dictionary in es:
		w += 13.0 + f.get_string_size(str(int(it2["gid"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 7.0
	var box: = Rect2(8.0, vs.y - float(cam.margin_bottom_px) - 26.0, w, 20.0)
	var blk: Array = MD.keep_out.duplicate()
	if hud.has_method("blocked_rects"):
		blk.append_array(hud.blocked_rects())
	if MD.hits(box, blk):
		return
	draw_rect(box.grow(1.0), Color(DARK.r, DARK.g, DARK.b, 0.9))
	draw_rect(box, Color(0.16, 0.15, 0.1, 0.86))
	draw_rect(Rect2(box.position, Vector2(box.size.x, 1)), Color(0.42, 0.38, 0.24, 0.9))
	var x: float = box.position.x + 5.0
	for it3: Dictionary in es:
		var col: Color = it3["col"]
		var no: String = str(int(it3["gid"]))
		draw_rect(Rect2(x - 1, box.position.y + 4, 12, 12), DARK)
		draw_rect(Rect2(x, box.position.y + 5, 10, 10), col)
		draw_string_outline(f, Vector2(x + 13.0, box.position.y + 14.0), no, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, DARK)
		draw_string(f, Vector2(x + 13.0, box.position.y + 14.0), no, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		x += 13.0 + f.get_string_size(no, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 7.0
	if MD.rec:
		dbg["legend"] = es.size()






func hit(pos: Vector2) -> int:
	if not _on or _placing() != "":
		return -1
	var best: int = -1
	var bd: float = INF
	for h: Array in _hits:
		var sp: PackedVector2Array = h[1]
		for i in range(1, sp.size()):
			var d: float = Geometry2D.get_closest_point_to_segment(pos, sp[i - 1], sp[i]).distance_to(pos)
			if d <= float(h[2]) and d < bd:
				bd = d
				best = int(h[0])
	return best




func _poll_press() -> void :
	_lp_prog = -1.0
	var mn: Node = hud.main_node if hud != null else null
	if mn == null or dock == null or String(dock.get("placing")) != "":
		return
	var tv: Variant = mn.get("_touches")
	var down: bool = bool(mn.get("_mouse_down")) or (tv is Dictionary and (tv as Dictionary).size() == 1)
	if not down or bool(mn.get("_moved")) or bool(mn.get("_dtz")):
		_lp_ms = -1
		return
	var pms: int = int(mn.get("_press_ms"))
	var age: float = float(Time.get_ticks_msec() - pms)
	if pms == _lp_fired or age > LP_MS + 400.0:
		return
	if pms != _lp_ms:
		_lp_ms = pms
		_lp_pos = mn.get("_press_pos")
		_lp_gid = hit(_lp_pos)
	if _lp_gid < 0:
		return
	_lp_prog = clampf(age / LP_MS, 0.0, 1.0)
	if _lp_prog >= 1.0:
		_lp_fired = pms
		_lp_prog = -1.0
		open_menu(_lp_gid)


func open_menu(gid: int) -> void :
	_flash = [gid, Time.get_ticks_msec()]
	if dock != null and dock.has_method("open_group_from_map"):
		dock.open_group_from_map(gid)



func _press_cue() -> void :
	var fg: int = -1
	var fa: float = 0.0
	if _lp_prog >= 0.0 and _lp_gid >= 0:
		fg = _lp_gid
		fa = 0.25 + 0.6 * _lp_prog
	elif int(_flash[0]) >= 0:
		var fl: float = float(Time.get_ticks_msec() - int(_flash[1])) / 350.0
		if fl < 1.0:
			fg = int(_flash[0])
			fa = 0.85 * (1.0 - fl)
		else:
			_flash = [-1, 0]
	if fg < 0:
		return
	for h: Array in _hits:
		if int(h[0]) == fg:
			draw_polyline(h[1], Color(1, 1, 1, fa * (0.75 + 0.25 * sin(_t * 18.0))), 6.0)
	if _lp_prog >= 0.0:
		var a0: float = - PI * 0.5
		draw_arc(_lp_pos, 20.0, 0.0, TAU, 32, Color(DARK.r, DARK.g, DARK.b, 0.7), 6.0)
		draw_arc(_lp_pos, 20.0, a0, a0 + TAU * _lp_prog, 32, UiKit.GOLD, 4.0)
