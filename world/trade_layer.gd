class_name TradeLayer
extends Node2D






const ICON_ZOOM: float = 1.0
const REDRAW: float = 1.0 / 12.0

var gw: GameWorld
var _t: float = 0.0
var _cam_key: Vector3 = Vector3.INF
var _had: bool = false
var _tex: Dictionary = {}


static func make(world: GameWorld) -> TradeLayer:
	var l: = TradeLayer.new()
	l.name = "Trade"
	l.gw = world
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return l


func _process(delta: float) -> void :
	if gw == null or gw.camera == null or gw.get("supply") == null:
		return
	_t += delta
	var sp: Supply = gw.supply
	var cam: MapCamera = gw.camera
	var key: = Vector3(cam.position.x, cam.position.y, cam.zoom.x)
	var busy: bool = not sp.zones.is_empty() or not sp.blockades.is_empty() or _bridges_busy() or (cam.zoom.x >= ICON_ZOOM and ( not gw.econ.ports.ships.is_empty() or not gw.econ.trucks.is_empty()))
	if (busy and (_t >= REDRAW or key != _cam_key)) or (_had and not busy):
		_t = 0.0
		_cam_key = key
		queue_redraw()
	_had = busy


func _bridges_busy() -> bool:
	for b: Bridge in gw.bridges:
		if b.state == Bridge.State.REBUILDING:
			return true
	return false


func _icon(nm: String) -> Texture2D:
	if not _tex.has(nm):
		_tex[nm] = UiKit.tex(nm) if UiKit.has(nm) else null
	return _tex[nm]


func _draw() -> void :
	if gw == null or gw.camera == null or gw.get("supply") == null or gw.econ == null:
		return
	var sp: Supply = gw.supply
	var cam: MapCamera = gw.camera
	var z: float = cam.zoom.x
	var view: = Rect2(cam.screen_to_world(Vector2.ZERO), cam.view_size() / z).grow(80.0 / z)
	var now: float = gw.game_time
	var k: float = 1.0 / z
	var font: Font = UiKit.f_bold if UiKit.f_bold != null else ThemeDB.fallback_font
	_zones(sp, view, k, now)
	_blockades(sp, view, k, now, font)
	_pontoons(sp, view, now)
	_jams(view, k, now, font)
	if z >= ICON_ZOOM:
		_cargo(view, k)
	draw_set_transform(Vector2.ZERO)



func _zones(sp: Supply, view: Rect2, k: float, now: float) -> void :
	var red: = Palette.c("alert_red")
	var amb: = Palette.c("amber")
	for zd: Dictionary in sp.danger_zones():
		var p: Vector2 = zd["pos"]
		var r: float = float(zd["r"])
		if not view.grow(r).has_point(p):
			continue
		var lv: float = float(zd["level"])
		var col: Color = amb.lerp(red, clampf(lv, 0.0, 1.0))
		var a: float = 0.16 + 0.26 * lv

		for i in 40:
			var a0: float = TAU * float(i) / 40.0 + now * 0.02
			draw_arc(p, r, a0, a0 + TAU / 40.0 * 0.55, 4, Color(col, a), maxf(1.0, 1.5 * k))

		if lv < 0.3:
			continue
		var step: float = maxf(36.0, 20.0 * k)
		var ha: float = 0.05 + 0.07 * lv
		var y: float = p.y - r
		while y <= p.y + r:
			var x: float = p.x - r
			while x <= p.x + r:
				var q2: = Vector2(x, y)
				if q2.distance_to(p) < r - 4.0 and view.has_point(q2):
					draw_line(q2, q2 + Vector2(4, -4) * maxf(1.0, k), Color(col, ha), maxf(1.0, k))
				x += step
			y += step



func _blockades(sp: Supply, view: Rect2, k: float, now: float, font: Font) -> void :
	var red: = Palette.c("alert_red")
	for key: String in sp.blockades:
		var bk: Dictionary = sp.blockades[key]
		var p: Vector2 = bk["pos"]
		if not view.grow(400.0).has_point(p):
			continue
		var r: float = 300.0
		var pulse: float = 0.55 + 0.25 * sin(now * 3.0)
		for i in 30:
			var a0: float = TAU * float(i) / 30.0
			draw_arc(p, r, a0, a0 + TAU / 30.0 * 0.6, 5, Color(red, pulse), maxf(1.0, 2.5 * k))
		draw_arc(p, r * 0.18, 0.0, TAU, 24, Color(red, 0.35 + 0.2 * pulse), maxf(1.0, 1.5 * k))
		draw_set_transform(p + Vector2(0, -34.0 * k), 0.0, Vector2(k, k))
		var txt: String = Loc.t("БЛОКАДА · %s") % Loc.t(String(bk.get("name", ""))).to_upper()
		var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_rect(Rect2(Vector2( - tw * 0.5 - 5.0, -12.0), Vector2(tw + 10.0, 15.0)), Color(0.08, 0.03, 0.03, 0.85))
		draw_rect(Rect2(Vector2( - tw * 0.5 - 5.0, -12.0), Vector2(tw + 10.0, 15.0)), Color(red, 0.95), false, 1.0)
		draw_string(font, Vector2( - tw * 0.5, 0.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.86, 0.8))
		draw_set_transform(Vector2.ZERO)




func _pontoons(sp: Supply, view: Rect2, now: float) -> void :
	var olive: = Palette.c("forest_dark")
	var plank: = Palette.c("wood_light")
	var dark: = Palette.c("outline")
	for b: Bridge in gw.bridges:
		if b.pont <= 0:
			continue
		var pl: PackedVector2Array = sp.pont_line(b)
		if not view.has_point(pl[0]) and not view.has_point(pl[1]):
			continue
		var ln: float = pl[0].distance_to(pl[1])
		var dirv: Vector2 = (pl[1] - pl[0]) / maxf(1.0, ln)
		var side: Vector2 = dirv.orthogonal()
		var prog: float = 1.0 if b.pont == 2 else clampf(b.pont_t / Supply.PONTOON_BUILD, 0.0, 1.0)
		var upto: float = ln * prog
		var d: float = 0.0
		var i: int = 0
		while d <= upto:
			var c: Vector2 = (pl[0] + dirv * d).round()

			draw_rect(Rect2(c - side * 2.0 - Vector2(1, 1), Vector2(2, 2)), dark)
			draw_rect(Rect2(c + side * 2.0 - Vector2(1, 1), Vector2(2, 2)), dark)
			draw_rect(Rect2(c - side * 2.0 - Vector2(1, 1), Vector2(1, 1)), olive)
			draw_rect(Rect2(c + side * 2.0 - Vector2(1, 1), Vector2(1, 1)), olive)
			for s in range(-1, 2):
				draw_rect(Rect2((c + side * float(s)).round(), Vector2(1, 1)), plank if (i + s) % 2 == 0 else Palette.c("wood"))
			d += 3.0
			i += 1
		if b.pont == 1:
			var tip: Vector2 = pl[0] + dirv * upto
			for w in 3:
				var q: Vector2 = (tip - dirv * float(2 + w * 3) + side * float((w % 2) * 2 - 1) * 3.0).round()
				draw_rect(Rect2(q, Vector2(1, 2)), Palette.c("grass_dark"))
				draw_rect(Rect2(q - Vector2(0, 1), Vector2(1, 1)), Palette.c("sand_light"))
			if int(now * 6.0) % 2 == 0:
				draw_rect(Rect2(tip.round(), Vector2(1, 1)), Palette.c("fire_yellow"))
		elif b.pont_hp < Supply.PONTOON_HP:

			var m: Vector2 = pl[0].lerp(pl[1], 0.5).round()
			draw_rect(Rect2(m - Vector2(2, 2), Vector2(4, 4)), Color(dark, 0.8))



func _jams(view: Rect2, k: float, now: float, font: Font) -> void :
	var heads: Dictionary = {}
	var blink: bool = int(now * 2.5) % 2 == 0
	for t: Dictionary in gw.econ.trucks:
		if not t.has("jam"):
			continue
		var p: Vector2 = (t["pos"] as Vector2).round()
		var bid: int = int(t["jam"])
		var e: Array = heads.get(bid, [p, 0, INF])
		e[1] = int(e[1]) + 1
		if float(t.get("jam_t", 0.0)) < float(e[2]):
			e[0] = p
			e[2] = float(t.get("jam_t", 0.0))
		if gw.vision != null and not gw.vision.shows(int(t.get("from", -1)), p):
			continue
		heads[bid] = e
		if not view.has_point(p):
			continue
		var back: Vector2 = - Vector2.from_angle(float(t.get("heading", 0.0)))
		var side: Vector2 = back.orthogonal()
		draw_rect(Rect2((p + back * 3.0 + side).round(), Vector2(1, 1)), Palette.c("alert_red"))
		draw_rect(Rect2((p + back * 3.0 - side).round(), Vector2(1, 1)), Palette.c("alert_red"))
		if blink:
			draw_rect(Rect2((p - back * 3.0 + side).round(), Vector2(1, 1)), Palette.c("amber"))
			draw_rect(Rect2((p - back * 3.0 - side).round(), Vector2(1, 1)), Palette.c("amber"))
	for bid2: int in heads:
		var e2: Array = heads[bid2]
		var hp: Vector2 = e2[0]
		if not view.has_point(hp):
			continue
		draw_set_transform(hp + Vector2(0, -8.0 * maxf(1.0, k)), 0.0, Vector2(k, k) * 1.35)

		var tri: = PackedVector2Array([Vector2(0, -12), Vector2(7, 0), Vector2(-7, 0)])
		draw_colored_polygon(tri, Palette.c("outline"))
		var tri2: = PackedVector2Array([Vector2(0, -10), Vector2(5.5, -1), Vector2(-5.5, -1)])
		draw_colored_polygon(tri2, Palette.c("amber"))
		draw_rect(Rect2(Vector2(-0.5, -8), Vector2(1.5, 4)), Palette.c("outline"))
		draw_rect(Rect2(Vector2(-0.5, -3), Vector2(1.5, 1.5)), Palette.c("outline"))
		if int(e2[1]) >= 2:
			var txt: String = "×%d" % int(e2[1])
			draw_string_outline(font, Vector2(9, -2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0.04, 0.05, 0.08, 0.95))
			draw_string(font, Vector2(9, -2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Palette.c("amber"))
		draw_set_transform(Vector2.ZERO)





func _hidden_truck(tp: Vector2) -> bool:
	if gw.objects == null:
		return false
	var x0: int = int(tp.x) - 4
	var tops: PackedInt32Array = gw.objects.cover_span(x0, 9, int(tp.y) + 4)
	if tops.is_empty():
		return false
	for t: int in tops:
		if t > int(tp.y) - 2:
			return false
	return true


func _cargo(view: Rect2, k: float) -> void :
	var sc: float = clampf(k * 1.6, 0.5, 1.2)
	for s: Dictionary in gw.econ.ports.ships:
		if int(s["n"]) <= 0:
			continue
		var p: Vector2 = (s["pos"] as Vector2).round()
		if not view.has_point(p):
			continue
		var ic: Texture2D = _icon(String(Economy.RES_ICONS.get(String(s["res"]), "")))
		if ic == null:
			continue
		var oc: Country = gw.country_by_id(int(s["owner"]))
		var edge: Color = (Palette.c("amber") if oc == gw.player else oc.color_light) if oc != null else Palette.c("ui_steel")
		draw_set_transform(p + Vector2(0, -11.0 * maxf(1.0, sc)), 0.0, Vector2(sc, sc))
		draw_rect(Rect2(Vector2(-6, -6), Vector2(12, 12)), Color(0.05, 0.06, 0.09, 0.82))
		draw_rect(Rect2(Vector2(-6, -6), Vector2(12, 12)), edge, false, 1.0)
		draw_rect(Rect2(Vector2(-1, 6), Vector2(2, 2)), Color(0.05, 0.06, 0.09, 0.82))
		draw_texture_rect(ic, Rect2(Vector2(-4.5, -4.5), Vector2(9, 9)), false)
		if s.has("turned"):
			draw_rect(Rect2(Vector2(-6, -6), Vector2(12, 12)), Palette.c("alert_red"), false, 1.0)

	var st: float = sc * 0.8
	for t: Dictionary in gw.econ.trucks:
		if int(t["from"]) == int(t["to"]) or int(t.get("n", 0)) <= 0 or t.has("jam"):
			continue
		var tp: Vector2 = (t["pos"] as Vector2).round()
		if not view.has_point(tp) or (gw.vision != null and not gw.vision.shows(int(t["from"]), tp)):
			continue
		if _hidden_truck(tp):
			continue
		var tic: Texture2D = _icon(String(Economy.RES_ICONS.get(String(t["res"]), "")))
		if tic == null:
			continue
		var tc: Country = gw.country_by_id(int(t["from"]))
		var te: Color = (Palette.c("amber") if tc == gw.player else tc.color_light) if tc != null else Palette.c("ui_steel")
		draw_set_transform(tp + Vector2(0, -9.0 * maxf(1.0, st)), 0.0, Vector2(st, st))
		draw_rect(Rect2(Vector2(-6, -6), Vector2(12, 12)), Color(0.05, 0.06, 0.09, 0.82))
		draw_rect(Rect2(Vector2(-6, -6), Vector2(12, 12)), te, false, 1.0)
		draw_texture_rect(tic, Rect2(Vector2(-4.5, -4.5), Vector2(9, 9)), false)
	draw_set_transform(Vector2.ZERO)
