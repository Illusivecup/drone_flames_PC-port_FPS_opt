class_name EconFxLayer
extends Node2D










const MIN_ZOOM: float = 0.6
const MAX_FLOATS: int = 6
const FLOAT_LIFE: float = 1.2
const FAC_COOLDOWN: float = 6.0
const RISE: float = 14.0
const STAGGER: float = 2.2
const OUTLINE: = Color(0.043, 0.078, 0.188)
const RED: = Color("e8402a")
const AMBER: = Color("ffb000")
const GREY: = Color("8f8a76")
const GOLD: = Color("ffd34d")
const WHITE: = Color("fbf3e0")
const MODES: Array = [GameWorld.MapMode.NORMAL, GameWorld.MapMode.MY_LAND, GameWorld.MapMode.LOGISTICS]

var gw: GameWorld
var _now: float = 0.0
var _probs: Array = []
var _probs_t: float = 0.0
var _probs_sig: int = 0
var _floats: Array = []
var _queue: Array = []
var _cool: Dictionary = {}
var _last_tick: float = -1.0
var _trade_tot: int = -1
var _fuel_tot: int = -1
var _key: Vector3 = Vector3.INF
var _tex: Dictionary = {}
var shown: int = 0


static func make(world: GameWorld) -> EconFxLayer:
	var l: = EconFxLayer.new()
	l.name = "EconFx"
	l.gw = world
	return l


func _process(delta: float) -> void :
	_now += delta
	if gw == null or gw.econ == null or gw.camera == null or gw.player == null or gw.get("guide") == null:
		if not _floats.is_empty() or not _probs.is_empty():
			_floats.clear()
			_queue.clear()
			_probs.clear()
			queue_redraw()
		return
	var dirty: bool = false

	var et: float = float(gw.econ._t)
	if _last_tick >= 0.0 and et < _last_tick - 0.001:
		_on_tick()
	_last_tick = et
	for k in range(_queue.size() - 1, -1, -1):
		_queue[k][0] = float(_queue[k][0]) - delta
		if float(_queue[k][0]) <= 0.0:
			if _floats.size() < MAX_FLOATS:
				_floats.append(_queue[k][1])
				shown += 1
			_queue.remove_at(k)
	for k2 in range(_floats.size() - 1, -1, -1):
		_floats[k2]["t"] = float(_floats[k2]["t"]) + delta
		if float(_floats[k2]["t"]) >= FLOAT_LIFE:
			_floats.remove_at(k2)
		dirty = true
	_probs_t -= delta
	if _probs_t <= 0.0:
		_probs_t = 1.0
		_probs = gw.guide.problems(gw.player) + _r335_badges()
		var sig: int = _probs.size() + _r335_army.size() * 1000
		for ab0: Dictionary in _r335_army:
			sig = sig * 31 + int((ab0["pos"] as Vector2).x) * 3 + int((ab0["pos"] as Vector2).y)
		for pr: Dictionary in _probs:
			sig = sig * 31 + int(pr["fid"]) * 7 + String(pr["kind"]).length()
		if sig != _probs_sig:
			_probs_sig = sig
			dirty = true
	var cam: MapCamera = gw.camera
	var key: = Vector3(cam.position.x, cam.position.y, cam.zoom.x)
	if key != _key:
		_key = key
		dirty = true
	if dirty:
		queue_redraw()


func _view() -> Rect2:
	var cam: MapCamera = gw.camera
	return Rect2(cam.screen_to_world(Vector2.ZERO), cam.view_size() / cam.zoom.x)


func _on_tick() -> void :
	var p: Country = gw.player
	var guide: EconGuide = gw.guide
	var fuel_tot: int = guide._total(p, "res_in", "fuel:refinery")
	var fuel_new: int = maxi(0, fuel_tot - _fuel_tot) if _fuel_tot >= 0 else 0
	_fuel_tot = fuel_tot
	var trade_tot: int = guide._total(p, "income", "trade") + guide._total(p, "income", "export")
	var trade_new: int = maxi(0, trade_tot - _trade_tot) if _trade_tot >= 0 else 0
	_trade_tot = trade_tot
	if not GameConfig.econ_fx or gw.camera.zoom.x < MIN_ZOOM or not MODES.has(int(gw.map_mode)):
		return
	var view: Rect2 = _view().grow(-8.0)
	var refs: Array = []
	for f: Facility in gw.mil.facilities:
		if f.country_id == p.id and f.kind == Facility.Kind.REFINERY and not f.halted and gw.mil.alive(f) and gw.mil.has_power(f):
			refs.append(f)
	var cands: Array = []
	for f: Facility in gw.mil.facilities:
		if f.country_id != p.id or f.halted or f.parent != null or not view.has_point(f.center_px()) or not gw.mil.alive(f):
			continue
		if _now - float(_cool.get(f.id, -100.0)) < FAC_COOLDOWN:
			continue
		var a: Array = _amount(f, fuel_new / maxi(1, refs.size()))
		if not a.is_empty():
			cands.append([f, a])
	cands.shuffle()
	var room: int = MAX_FLOATS - _floats.size() - _queue.size()
	if trade_new > 0 and room > 0:
		var port: Facility = gw.econ.ports.port_of(p)
		var at: Vector2 = port.center_px() if port != null else Vector2(gw.cities[p.capital_id].center * GameWorld.CELL) if p.capital_id >= 0 else Vector2.INF
		if at.is_finite() and view.has_point(at):
			_queue.append([randf_range(0.0, STAGGER), {"p": at, "t": 0.0, "txt": "+%d" % trade_new, "icon": "res_money", "col": GOLD}])
			room -= 1
	for i in mini(room, cands.size()):
		var f2: Facility = cands[i][0]
		var a2: Array = cands[i][1]
		_cool[f2.id] = _now
		var top: = Vector2(f2.center_px().x, float(f2.cell.y * GameWorld.CELL))
		if f2.main_obj >= 0:
			top.y = minf(top.y, gw.obj_origin(f2.main_obj).y + 4.0)
		_queue.append([randf_range(0.0, STAGGER), {"p": top, "t": 0.0, "txt": String(a2[0]), "icon": String(a2[1]), "col": a2[2]}])



func _amount(f: Facility, fuel_share: int) -> Array:
	var econ: Economy = gw.econ
	match f.kind:
		Facility.Kind.FARM:
			return ["+%d" % ceili(Economy.FARM_FOOD * econ.level_mul(f)), "res_food", WHITE]
		Facility.Kind.CIV_FACTORY:
			if gw.mil.has_power(f):
				return ["+%d" % int(Economy.CIV_MONEY * econ.level_mul(f)), "res_money", GOLD]
		Facility.Kind.MINE, Facility.Kind.OIL_RIG, Facility.Kind.SAWMILL, Facility.Kind.URANIUM_MINE:
			var n: int = int(econ._site_of(f).get("rate", 0))
			if n > 0:
				return ["+%d" % n, EconGuide.res_icon(econ.out_res(f)), WHITE]
		Facility.Kind.REFINERY:
			if fuel_share > 0 and gw.mil.has_power(f):
				return ["+%d" % fuel_share, "res_fuel", WHITE]
	return []


func _icon(nm: String) -> Texture2D:
	if not _tex.has(nm):
		_tex[nm] = UiKit.tex(nm) if UiKit.has(nm) else null
	return _tex[nm]


func _draw() -> void :
	if gw == null or gw.camera == null or gw.mil == null or gw.player == null:
		return
	var z: float = gw.camera.zoom.x
	if z < MIN_ZOOM or not MODES.has(int(gw.map_mode)):
		return
	var sc: float = 1.0 / z
	var view: Rect2 = _view().grow(16.0)
	UiKit.ensure()
	var font: Font = UiKit.f_bold if UiKit.f_bold != null else ThemeDB.fallback_font
	var nf: int = gw.mil.facilities.size()


	var ma: float = 0.0
	if gw.show_own_icons:
		ma = 1.0 - clampf((z - MapIcons.FADE_FROM) / (MapIcons.FADE_TO - MapIcons.FADE_FROM), 0.0, 1.0)
	for pr: Dictionary in _probs:
		var fid: int = int(pr["fid"])
		if fid < 0 or fid >= nf:
			continue
		var f: Facility = gw.mil.facilities[fid]
		var anchor: = Vector2(float((f.cell.x + f.size.x) * GameWorld.CELL) - 2.0, float(f.cell.y * GameWorld.CELL))
		var off: = Vector2.ZERO
		if f.main_obj >= 0:
			anchor.y = minf(anchor.y, gw.obj_origin(f.main_obj).y + 3.0)
		if ma > 0.3:
			anchor = f.center_px()
			if f.main_obj >= 0:
				anchor.y = minf(anchor.y, gw.obj_origin(f.main_obj).y + 3.0)
			off = Vector2(9.0, -19.0)
		if not view.has_point(anchor):
			continue
		draw_set_transform(anchor, 0.0, Vector2(sc, sc))
		_badge(String(pr["kind"]), off)
	for ab: Dictionary in _r335_army:
		var ap: Vector2 = ab["pos"]
		if view.has_point(ap):
			draw_set_transform(ap, 0.0, Vector2(sc, sc))
			_badge("cut", Vector2(0.0, -16.0))
	if GameConfig.econ_fx:
		for fl: Dictionary in _floats:
			var k: float = clampf(float(fl["t"]) / FLOAT_LIFE, 0.0, 1.0)
			var a: float = clampf(k / 0.12, 0.0, 1.0) * (1.0 - smoothstep(0.55, 1.0, k))
			var p: Vector2 = fl["p"]
			if not view.has_point(p):
				continue
			draw_set_transform(p, 0.0, Vector2(sc, sc))
			var y: float = -4.0 - 22.0 * ma - RISE * (1.0 - pow(1.0 - k, 2.0))
			var txt: String = fl["txt"]
			var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			var ic: Texture2D = _icon(String(fl["icon"]))
			var iw: float = 9.0 if ic != null else 0.0
			var x0: float = - (tw + iw + 1.0) * 0.5
			if ic != null:
				draw_rect(Rect2(Vector2(x0 - 1.0, y - 8.0), Vector2(11, 11)), Color(OUTLINE, 0.55 * a))
				draw_texture_rect(ic, Rect2(Vector2(x0, y - 7.0), Vector2(9, 9)), false, Color(1, 1, 1, a))
			var tp: = Vector2(x0 + iw + 1.0, y + 1.0)
			draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(OUTLINE, 0.9 * a))
			draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(fl["col"] as Color, a))
	draw_set_transform(Vector2.ZERO)




var _r335_army: Array = []


func _r335_badges() -> Array:
	var out: Array = []
	_r335_army = []
	var p: Country = gw.player
	if p == null or gw.econ == null or gw.econ.get("upk") == null:
		return out
	var upk = gw.econ.upk
	for f: Facility in gw.mil.facilities:
		if f.country_id != p.id or f.parent != null:
			continue
		if f.mb and gw.mil.alive(f):
			out.append({"fid": f.id, "kind": "mb"})
		elif (upk.cut_f as Dictionary).has(f.id) and gw.mil.alive(f):
			out.append({"fid": f.id, "kind": "cut"})
	var acc: Dictionary = {}
	for u: Unit in gw.army.units:
		if u.country_id != p.id or not u.alive() or u.home == null or not (upk.cut_u as Dictionary).has(u.id):
			continue
		var e: Array = acc.get(u.home.id, [Vector2.ZERO, 0])
		acc[u.home.id] = [(e[0] as Vector2) + u.pos, int(e[1]) + 1]
	for k: Variant in acc:
		var e2: Array = acc[k]
		_r335_army.append({"pos": (e2[0] as Vector2) / float(maxi(1, int(e2[1])))})
	return out



func _badge(kind: String, o: Vector2 = Vector2.ZERO) -> void :
	var col: Color = RED
	if kind == "halted":
		col = GREY
	elif kind == "full" or kind == "idle":
		col = AMBER
	elif kind == "mb":
		col = Color("6f8fb0")
	elif kind == "cut":
		col = Color("ff7a1f")
	var r: = Rect2(o.x - 4.5, o.y - 4.5, 9, 9)
	draw_rect(r.grow(1.5), OUTLINE)
	draw_rect(r, col)
	draw_rect(Rect2(r.position, Vector2(9, 1)), col.lightened(0.35))
	if kind == "mb":
		for yy: float in [-2.5, -0.5, 1.5]:
			draw_rect(Rect2(o.x - 2.5, o.y + yy, 5, 1), WHITE)
		return
	if kind == "cut":
		draw_rect(Rect2(o.x - 3.5, o.y - 1.5, 3, 2), WHITE)
		draw_rect(Rect2(o.x + 0.5, o.y + 0.5, 3, 2), WHITE)
		draw_rect(Rect2(o.x - 0.5, o.y - 3.5, 1, 1), OUTLINE)
		return
	if kind == "halted":
		draw_rect(Rect2(o.x - 2.5, o.y - 2.5, 2, 5), WHITE)
		draw_rect(Rect2(o.x + 0.5, o.y - 2.5, 2, 5), WHITE)
	else:
		var g: Color = OUTLINE if col == AMBER else WHITE
		draw_rect(Rect2(o.x - 1.0, o.y - 3.0, 2, 4), g)
		draw_rect(Rect2(o.x - 1.0, o.y + 2.0, 2, 1.5), g)
