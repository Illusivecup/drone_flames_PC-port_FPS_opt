extends RefCounted








const RV = preload("res://world/rail_view332.gd")
const OK_COL: = Color(0.45, 1.0, 0.5)
const BAD_COL: = Color(1.0, 0.35, 0.3)
const START_COL: = Color("ffc23a")
const SNAP_SCR: float = 30.0

static var sid: int = -1
static var end_wp: Vector2 = Vector2.INF
static var plan: Dictionary = {}
static var _st_key: Array = []
static var _st_site: Array = []


static func reset() -> void :
	sid = -1
	end_wp = Vector2.INF
	plan = {}


static func _cell(wp: Vector2) -> Vector2i:
	return Vector2i(floori(wp.x / GameWorld.CELL), floori(wp.y / GameWorld.CELL))


static func _mins(s: float) -> String:
	var t: int = ceili(s)
	return "%d:%02d" % [t / 60, t % 60]


static func hint(main: Node, m: int) -> String:
	var R: Rail = main.world.rail
	if m == main.Mode.RAIL_ST:
		return Loc.t("ВОКЗАЛ (%s): ТАП ПО СВОЕЙ ЗЕМЛЕ — СТАНЦИЯ ДЛЯ ПОЕЗДОВ И ЭШЕЛОНОВ") % Economy.cost_text(station_cost()).to_upper()
	if sid >= 0 and sid < R.stations.size():
		return Loc.t("Ж/Д ПУТЬ ОТ %s: ВЕДИТЕ ИЛИ ТАП ДО ТОЧКИ НА СВОЕЙ ЗЕМЛЕ") % R.st_name(sid).to_upper()
	return "Ж/Д ПУТЬ: ВЕДИТЕ ПАЛЬЦЕМ ОТ СВОЕГО ВОКЗАЛА К ТОЧКЕ (ИЛИ ТАП ПО ВОКЗАЛУ)"


static func station_cost() -> Dictionary:
	var c: Dictionary = Rail.MAN_ST_RES.duplicate()
	c["money"] = Rail.MAN_ST_COST
	return c



static func _station_at(main: Node, pos: Vector2) -> int:
	var w: GameWorld = main.world
	var r: float = maxf(SNAP_SCR / maxf(main.cam.zoom.x, 0.01), 14.0)
	return w.rail.station_near(w.player.id, main.cam.screen_to_world(pos) + Vector2(0, -4), r)



static func press(main: Node, pos: Vector2) -> bool:
	if main.world.player == null:
		return false
	var s: int = _station_at(main, pos)
	if s < 0:
		return false
	sid = s
	end_wp = Vector2.INF
	plan = {}
	return true


static func drag(main: Node, pos: Vector2) -> void :
	end_wp = main.cam.screen_to_world(pos)
	var R: Rail = main.world.rail
	var d: float = (R.stations[sid]["p"] as Vector2).distance_to(end_wp)
	var est: int = roundi(Rail.MAN_PX_COST * d * 1.25 / 10.0) * 10
	var lim: bool = d > float(Rail.MAN_MAX_CELLS * GameWorld.CELL)
	main.hud.set_hint((Loc.t("Ж/Д ПУТЬ: %d М ПО ПРЯМОЙ · ОТ %d · ОТПУСТИТЕ — МАРШРУТ И ЦЕНА") % [roundi(d), est]) if not lim else Loc.t("Ж/Д ПУТЬ: ДАЛЬШЕ %d М НЕЛЬЗЯ") % (Rail.MAN_MAX_CELLS * GameWorld.CELL))


static func drag_end(main: Node) -> void :
	if sid < 0 or not end_wp.is_finite():
		return
	_plan_to(main, end_wp)



static func tap(main: Node, wp: Vector2) -> void :
	var s: int = _station_at(main, main.cam.world_to_screen(wp))
	if s >= 0 and (sid < 0 or s == sid):
		sid = s
		end_wp = Vector2.INF
		plan = {}
		main.hud.set_hint(hint(main, main.mode))
		UiKit.snd("ui_select")
		return
	if sid < 0:
		main.hud.show_toast("Сначала тап по своему вокзалу (или ведите от него)")
		UiKit.snd("ui_error")
		return
	end_wp = wp
	_plan_to(main, wp)


static func _plan_to(main: Node, wp: Vector2) -> void :
	var w: GameWorld = main.world
	plan = w.rail.man_plan(w.player, sid, _cell(wp))
	main.hud.set_hint(hint(main, main.mode))
	main._pend = {"kind": "rail", "sid": sid, "to": _cell(wp), "mode": main.mode}
	main._show_pend()
	UiKit.snd("ui_select" if String(plan.get("why", "")) == "" else "ui_error")


static func pend_why(_main: Node, _pd: Dictionary) -> String:
	return String(plan.get("why", ""))


static func pend_text(main: Node, pd: Dictionary) -> String:
	var R: Rail = main.world.rail
	if not plan.has("pts"):
		return Loc.t("Ж/Д путь от %s") % R.st_name(int(pd.get("sid", sid)))
	var cost: Dictionary = {"money": int(plan["money"]), "metal": int(plan["metal"]), "wood": int(plan["wood"])}
	var nb: int = int(plan.get("bridges", 0))
	var to: String = (Loc.t("к вокзалу %s") % R.st_name(int(plan["b"]))) if int(plan["b"]) >= 0 else Loc.t("новый вокзал")
	var km: String = Loc.dec(Loc.t("%.1f км") % (float(plan["len"]) / 1000.0))

	return Loc.t("Ж/Д путь %s → %s\nстройка %s%s\n%s") % [km, to, _mins(float(plan["time"])), (Loc.t(" · мост") if nb == 1 else (Loc.t(" · мостов: %d") % nb if nb > 1 else "")), Economy.cost_text(cost)]



static func station_site(main: Node, wp: Vector2) -> Array:
	var w: GameWorld = main.world
	var key: Array = [_cell(wp), w.rail.stations.size(), w.player.money, w.player.wood, w.player.metal]
	if key != _st_key:
		_st_key = key
		_st_site = w.rail.man_station_site(w.player, _cell(wp))
	return _st_site


static func station_why(main: Node, wp: Vector2) -> String:
	var why: String = String(station_site(main, wp)[0])
	var p: Country = main.world.player
	if why == "" and p.money < Rail.MAN_ST_COST:
		why = Loc.t("Не хватает денег: нужно %d") % Rail.MAN_ST_COST
	elif why == "" and not p.has_res(Rail.MAN_ST_RES):
		why = Loc.t("Не хватает: %s") % p.missing_res(Rail.MAN_ST_RES)
	return why


static func station_text(_main: Node, _wp: Vector2) -> String:
	return Loc.t("Вокзал · стройка %d мин\n%s") % [ceili(Rail.MAN_ST_TIME / 60.0), Economy.cost_text(station_cost())]



static func station_go(main: Node, cell: Vector2i) -> void :
	main._sim("rail", "build_station", [main.world.player, cell], func(r: Variant) -> void :
		var why: String = main._why(r)
		if why != "":
			main.hud.show_toast(why)
			UiKit.snd("ui_error")
			return
		UiKit.snd("ui_build")
		main._set_mode(main.Mode.NONE))



static func go(main: Node, pd: Dictionary) -> void :
	var s: int = int(pd.get("sid", -1))
	var to: Vector2i = pd.get("to", Vector2i(-1, -1))
	main._sim("rail", "build_line", [main.world.player, s, to], func(r: Variant) -> void :
		var why: String = main._why(r)
		if why != "":
			main.hud.show_toast(why)
			UiKit.snd("ui_error")
			return
		UiKit.snd("ui_build")
		reset()
		main._set_mode(main.Mode.NONE))





static func draw(main: Node, ci: Node2D) -> bool:
	var pd: Dictionary = main._pend
	var m: int = int(pd.get("mode", main.mode))
	if m != main.Mode.RAIL_ST and m != main.Mode.RAIL_LINE:
		return false
	var w: GameWorld = main.world
	var R: Rail = w.rail
	var z: float = maxf(main.cam.zoom.x, 0.05)
	var me: int = w.player.id

	if m == main.Mode.RAIL_LINE:
		for st: Dictionary in R.stations:
			var s2: int = int(st["id"])
			if R._station_country(s2) != me:
				continue
			var p: Vector2 = st["p"]
			var on: bool = s2 == sid
			ci.draw_arc(p + Vector2(0, -4), maxf(14.0, SNAP_SCR / z), 0.0, TAU, 40, Color(0.04, 0.05, 0.08, 0.6), 3.5 / z)
			ci.draw_arc(p + Vector2(0, -4), maxf(14.0, SNAP_SCR / z), 0.0, TAU, 40, Color(START_COL if on else Color("f3ead9"), 0.95 if on else 0.6), (2.0 if on else 1.2) / z)
	if String(pd.get("kind", "")) == "rail" and plan.has("pts"):
		_draw_line(ci, plan["pts"], String(plan.get("why", "")) == "", z)
		if int(plan["b"]) < 0 and plan.has("nw"):
			_draw_foot(ci, plan["nw"], String(plan.get("why", "")) == "")
		return true
	if String(pd.get("kind", "")) == "rail":
		if end_wp.is_finite():
			_x(ci, end_wp, z)
		return true
	if m == main.Mode.RAIL_LINE and sid >= 0 and end_wp.is_finite() and main._drag_pt == -13:
		var a: Vector2 = R.stations[sid]["p"]
		var far: bool = a.distance_to(end_wp) > float(Rail.MAN_MAX_CELLS * GameWorld.CELL)
		var col: Color = BAD_COL if far else START_COL
		ci.draw_dashed_line(a, end_wp, Color(0.04, 0.05, 0.08, 0.7), 4.0 / z, 7.0 / z)
		ci.draw_dashed_line(a, end_wp, col, 2.0 / z, 7.0 / z)
		var sn: int = R.station_near(me, end_wp, Rail.MAN_SNAP_PX, sid)
		ci.draw_circle(end_wp, 3.0 / z, col)
		if sn >= 0:
			ci.draw_arc((R.stations[sn]["p"] as Vector2) + Vector2(0, -4), maxf(16.0, SNAP_SCR / z) + 3.0 / z, 0.0, TAU, 40, OK_COL, 2.0 / z)
		return true
	if m == main.Mode.RAIL_ST and String(pd.get("kind", "")) == "tap":
		var wp: Vector2 = pd["wp"]
		var site: Array = station_site(main, wp)
		var ok: bool = station_why(main, wp) == ""
		var nw: Vector2i = site[1] if (site[1] as Vector2i).x >= 0 else _cell(wp) - Vector2i(Rail.STATION_FW / 2, 1)
		_draw_foot(ci, nw, ok)
	return true


static func _draw_foot(ci: Node2D, nw: Vector2i, ok: bool) -> void :
	var C: float = float(GameWorld.CELL)
	var col: Color = OK_COL if ok else BAD_COL
	var r: = Rect2(Vector2(nw) * C, Vector2(Rail.STATION_FW, Rail.STATION_FD) * C)
	ci.draw_rect(r, Color(col, 0.35))
	ci.draw_rect(r, Color(col, 0.9), false, 1.0)

	var y: float = (float(nw.y + Rail.STATION_FD) + 0.5) * C
	ci.draw_line(Vector2(float(nw.x - 2) * C, y), Vector2(float(nw.x + Rail.STATION_FW + 2) * C, y), Color(col, 0.8), 1.0)



static func _draw_line(ci: Node2D, pts: PackedVector2Array, ok: bool, z: float) -> void :
	if pts.size() < 2:
		return
	var thin: = PackedVector2Array()
	for i in range(0, pts.size(), 3):
		thin.append(pts[i])
	thin.append(pts[pts.size() - 1])
	ci.draw_polyline(thin, Color(0.04, 0.05, 0.08, 0.75), maxf(3.0, 6.0 / z))
	var dl: float = maxf(4.0, 7.0 / z)
	var a: = PackedVector2Array()
	var b: = PackedVector2Array()
	var acc: float = 0.0
	var k: int = 0
	for i in range(1, thin.size()):
		var p0: Vector2 = thin[i - 1]
		var p1: Vector2 = thin[i]
		var seg: float = p0.distance_to(p1)
		var t: float = 0.0
		while t < seg:
			var e: float = minf(seg, t + dl - acc)
			var q0: Vector2 = p0.lerp(p1, t / seg)
			var q1: Vector2 = p0.lerp(p1, e / seg)
			if k % 2 == 0:
				a.append(q0)
				a.append(q1)
			else:
				b.append(q0)
				b.append(q1)
			acc += e - t
			t = e
			if acc >= dl - 0.001:
				acc = 0.0
				k += 1
	var w2: float = maxf(1.5, 3.0 / z)
	if not a.is_empty():
		ci.draw_multiline(a, RV.TIE_A if ok else Color(1.0, 0.8, 0.75), w2)
	if not b.is_empty():
		ci.draw_multiline(b, RV.TIE_B if ok else BAD_COL, w2)


static func _x(ci: Node2D, p: Vector2, z: float) -> void :
	var r: float = 6.0 / z
	for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
		ci.draw_line(p - d * r, p + d * r, Color(0.04, 0.05, 0.08, 0.8), 4.0 / z)
		ci.draw_line(p - d * r, p + d * r, BAD_COL, 2.0 / z)
