class_name ReconLayer
extends Node2D





const PK = preload("res://ui/ui24/path_kit.gd")

var gw: GameWorld
var _had: bool = false


func _process(_delta: float) -> void :
	if gw == null or gw.get("recon") == null:
		return
	var busy: bool = not gw.recon.drones.is_empty() or not gw.recon.shots.is_empty()
	if busy or _had:
		queue_redraw()
	_had = busy


func _draw() -> void :
	if gw == null or gw.get("recon") == null or gw.camera == null:
		return
	var rc: Recon = gw.recon
	var z: float = gw.camera.zoom.x
	var cyan: = Palette.c("intercept_cyan")
	var a13: SpriteAtlas = gw.atlas13
	var has13: bool = a13 != null and a13.has("uav_recon")
	var sel: Object = gw.selected_drone()
	var w: float = maxf(1.0, 1.5 / z)
	for d: Recon.RDrone in rc.drones:
		if d.dead or d.state == Recon.St.DONE or not rc.visible(d):
			continue
		var own: bool = gw.vision == null or gw.vision.friend(d.country_id)
		var p: Vector2 = d.pos.round()
		if own and d.airborne():
			_scan(d, z, w, cyan)
		if z >= 1.0:
			var hh: float = maxf(1.0, roundf(d.h))
			if has13:
				_spr(a13, "uav_recon_shadow", d.frame, p + Vector2(hh, hh))
				_outlined(a13, "uav_recon", "uav_recon_shadow", d.frame, p)
			elif gw.atlas2 != null and gw.atlas2.has("uav_delta"):
				_spr(gw.atlas2, "uav_delta_shadow", d.frame, p + Vector2(hh, hh))
				_outlined(gw.atlas2, "uav_delta", "uav_delta_shadow", d.frame, p)
			if d == sel:
				_brackets(p, 10)
		else:

			var col: Color = cyan if own else Palette.c("alert_red")
			var s: float = 4.0 / z
			var pts: = PackedVector2Array([p + Vector2(0, - s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2( - s, 0)])
			draw_colored_polygon(pts, Palette.c("ui_rubber"))
			var s2: float = 2.6 / z
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, - s2), p + Vector2(s2, 0), p + Vector2(0, s2), p + Vector2( - s2, 0)]), col)
			if d == sel:
				draw_arc(p, 7.0 / z, 0.0, TAU, 16, Palette.c("amber"), w)
	if z >= 0.5 and gw.atlas6 != null and gw.atlas6.has("sam"):
		for sh: Dictionary in rc.shots:
			if gw.vision != null and not gw.vision.shows_air(int(sh.get("c", -1)), sh["pos"]):
				continue
			var fr: int = posmod(roundi(rad_to_deg(float(sh["heading"])) / 22.5), 16)
			var nm: String = "sam" if sh["kind"] == "sam" else "int_drone"
			if gw.atlas6.has(nm):
				_outlined(gw.atlas6, nm, nm + "_shadow", fr, (sh["pos"] as Vector2).round())




func _scan(d: Recon.RDrone, z: float, w: float, cyan: Color) -> void :
	var c: Vector2 = d.pos.round()
	var r: float = Recon.VIEW_R
	var t: float = gw.game_time - d.t0
	var over: bool = d.state == Recon.St.LOITER
	var jam: bool = d.jam_t > 0.0
	var col: Color = Palette.c("amber") if jam else cyan
	if over:
		draw_circle(c, r, Color(col, 0.1))
	var seg: int = 28
	var rot: float = t * 0.3
	for k in seg:
		if k % 2 == 0:
			var a0: float = rot + TAU * float(k) / float(seg)
			draw_arc(c, r, a0, a0 + TAU / float(seg), 3, Color(col, 0.85 if over else 0.4), w * (1.5 if over else 1.0))
	if over and not jam:
		var ang: float = t * 2.0
		for k in 5:
			draw_line(c, c + Vector2.from_angle(ang - float(k) * 0.08) * r, Color(col, 0.6 - float(k) * 0.1), w)

	var to: Vector2 = d.target if d.state <= Recon.St.OUT else (d.home if d.state >= Recon.St.BACK else Vector2.INF)
	if to.is_finite():
		var v: Vector2 = to - c
		var L: float = v.length()
		if L > 8.0:
			var dir: Vector2 = v / L
			PK.line(self, c + dir * 10.0, to, Color(col, 0.55), 1.5, gw.game_time, 1.0 / maxf(z, 0.25), {"trim": 6.0})
		if d.state <= Recon.St.OUT:
			var tk: float = 6.0 / maxf(z, 0.25)
			draw_arc(to, Recon.LOITER_R, 0.0, TAU, 32, Color(col, 0.3), w)
			draw_line(to - Vector2(tk, 0), to + Vector2(tk, 0), Color(col, 0.7), w)
			draw_line(to - Vector2(0, tk), to + Vector2(0, tk), Color(col, 0.7), w)


func _spr(a: SpriteAtlas, n: String, fr: int, center: Vector2) -> void :
	var info: Dictionary = a.info(n)
	var r: Rect2 = a.rect(n, fr)
	draw_texture_rect_region(a.texture, Rect2(center - Vector2(float(info["ax"]), float(info["ay"])), r.size), r)


func _outlined(a: SpriteAtlas, n: String, shadow: String, fr: int, c: Vector2) -> void :
	var info: Dictionary = a.info(shadow)
	var r: Rect2 = a.rect(shadow, fr)
	var tl: Vector2 = c - Vector2(float(info["ax"]), float(info["ay"]))
	var dark: = Color(0.35, 0.38, 0.5)
	for o: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_texture_rect_region(a.texture, Rect2(tl + o, r.size), r, dark)
	_spr(a, n, fr, c)


func _brackets(c: Vector2, r: int) -> void :
	var col: Color = Palette.c("amber")
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var q: = c + Vector2(sx * r, sy * r)
			draw_rect(Rect2(q.x - (0.0 if sx < 0 else 1.0), q.y - (0.0 if sy < 0 else 1.0), 1, 1), col)
			draw_rect(Rect2(q.x - sx * 1.0 - (0.0 if sx < 0 else 1.0), q.y - (0.0 if sy < 0 else 1.0), 1, 1), col)
			draw_rect(Rect2(q.x - (0.0 if sx < 0 else 1.0), q.y - sy * 1.0 - (0.0 if sy < 0 else 1.0), 1, 1), col)
