class_name NavyLayer
extends Node2D







const HULL_KEYS: Array = ["ship_light", "ship_medium", "ship_heavy"]
const S: Array = [17, 21, 27]
const MAPS: Array = [
	[
		"..OOOOOOOOOO...", 
		".OHHHHHHHHHHOO.", 
		"OHdHHWWWHHdHHHO", 
		".OHHHHHHHHHHOO.", 
		"..OOOOOOOOOO...", 
	], 
	[
		"...OOOOOOOOOOOOO...", 
		"..OHHHHHHHHHHHHHOO.", 
		".OHdHHHWWWWHHdHHHOO", 
		".OHdHHHWWWWHHdHHHOO", 
		"..OHHHHHHHHHHHHHOO.", 
		"...OOOOOOOOOOOOO...", 
	], 
	[
		"....OOOOOOOOOOOOOOOOOO...", 
		"..OOHHHHHHHHHHHHHHHHHHOO.", 
		".OHHdHvvHHWWWWWHHdHHdHHHO", 
		"OHHdddHHHHWWWWWHHddHHHHHO", 
		".OHHdHvvHHWWWWWHHdHHdHHHO", 
		"..OOHHHHHHHHHHHHHHHHHHOO.", 
		"....OOOOOOOOOOOOOOOOOO...", 
	], 
]
const PAL: Dictionary = {"O": "outline", "H": "ui_steel", "W": "concrete_light", "d": "ui_steel_dark", "v": "rock_dark"}

var gw: GameWorld
var _tex: Array = []
var _at: SpriteAtlas = null
var _fx: SpriteAtlas = null
var _a30: SpriteAtlas = null
var _art_top: Node2D = null
var _t: float = 0.0
var _cam_key: Vector3 = Vector3.INF
var _had: bool = false
var _glow_node: Node2D = null
var _glow_tex: Texture2D = null

const P_DARK: int = 0
const P_WHITE: int = 1
const P_FIRE: int = 2
const SINK_BLASTS: Array = [0.15, 1.6, 3.2]
var _d28: Texture2D = null
var _pf_y: PackedInt32Array = PackedInt32Array()
var _kz: float = 1.0


static func make(world: GameWorld) -> NavyLayer:
	var l: = NavyLayer.new()
	l.name = "Navy"
	l.gw = world
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return l


func _ready() -> void :
	for h in 3:
		var rows: Array[String] = []
		rows.assign(MAPS[h])
		_tex.append(NavalLayer._strip(rows, PAL, int(S[h])))
	var a: Variant = gw.get("atlas_navy1")
	if a is SpriteAtlas and not (a as SpriteAtlas).sprites.is_empty():
		_at = a
	var f: Variant = gw.get("fx_atlas_navy")
	if f is SpriteAtlas and not (f as SpriteAtlas).sprites.is_empty():
		_fx = f
	var a30: SpriteAtlas = SpriteAtlas.load_atlas("res://assets/sprites/atlas_navy30.png", "res://assets/sprites/atlas_navy30.json", true)
	if a30.has("mod_art"):
		_a30 = a30
	var pa: SpriteAtlas = SpriteAtlas.load_atlas("res://assets/sprites/det28_navyfx.png", "res://assets/sprites/det28_navyfx.json", true)
	if pa.has("puff_dark") and pa.has("puff_white") and pa.has("puff_fire"):
		_d28 = pa.texture
		_pf_y = PackedInt32Array([int(pa.info("puff_dark")["y"]), int(pa.info("puff_white")["y"]), int(pa.info("puff_fire")["y"])])


	var g: = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.width = 32
	gt.height = 32
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	_glow_tex = gt
	_glow_node = Node2D.new()
	_glow_node.name = "NavyGlow"
	_glow_node.z_index = 1
	var am: = CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_node.material = am
	add_child(_glow_node)
	_glow_node.draw.connect(_draw_glow)
	_art_top = Node2D.new()
	_art_top.name = "NavyArtTop"
	_art_top.z_index = 5
	add_child(_art_top)
	_art_top.draw.connect(_draw_art_top)


func _process(delta: float) -> void :
	if gw == null or gw.navy == null or gw.camera == null:
		return
	_t += delta
	var nv: Navy = gw.navy
	var busy: bool = not nv.ships.is_empty() or not nv.msl.is_empty() or not nv.cm_boost.is_empty() or not nv.slicks.is_empty() or not nv.wrecks.is_empty() or (gw.supply != null and not gw.supply.spills.is_empty())
	var cam: MapCamera = gw.camera
	var key: = Vector3(cam.position.x, cam.position.y, cam.zoom.x)
	if (busy and (_t >= 1.0 / 20.0 or key != _cam_key)) or (_had and not busy):
		_t = 0.0
		_cam_key = key
		queue_redraw()
		if _glow_node != null:
			_glow_node.queue_redraw()
		if _art_top != null:
			_art_top.queue_redraw()
	_had = busy


func _shows(country_id: int, p: Vector2) -> bool:
	return gw.vision == null or gw.vision.shows(country_id, p)



func _shows_ship(country_id: int, p: Vector2) -> bool:
	return gw.vision == null or gw.vision.shows_ship(country_id, p)


func _draw() -> void :
	if gw == null or gw.navy == null or gw.camera == null or _tex.is_empty():
		return
	var nv: Navy = gw.navy
	var cam: MapCamera = gw.camera
	var z: float = cam.zoom.x
	var view: = Rect2(cam.screen_to_world(Vector2.ZERO), cam.view_size() / z).grow(60.0 / z)
	var sc: float = clampf(0.6 / z, 1.0, 2.5)
	var kz: float = clampf(1.0 / z, 1.0, 2.2)
	_kz = kz
	var now: float = gw.game_time
	var me: int = gw.player.id if gw.player != null else -1

	var oil: = Palette.c("outline")
	var k0: int = 0
	for sl: Array in nv.slicks:
		k0 += 1
		var p0: Vector2 = (sl[0] as Vector2).round()
		if not view.has_point(p0):
			continue
		var a: float = clampf((float(sl[1]) - now) / 30.0, 0.0, 1.0)
		if _fx != null and _fx.has("oil_slick"):
			_blit(_fx, "oil_slick", (int(p0.x) * 7 + int(p0.y)) % 3, p0, Color(1, 1, 1, a * 0.85))
		else:
			for k in 5:
				var o: = Vector2(float((k * 37) % 11) - 5.0, float((k * 23) % 7) - 3.0) * 1.6
				draw_rect(Rect2((p0 + o).round() - Vector2(3, 1), Vector2(6 + k % 3 * 2, 2 + k % 2)), Color(oil, a * 0.45))
	if gw.supply != null and not gw.supply.spills.is_empty():
		_draw_spills(view, now)
	var foam: = Palette.c("water_foam")
	var fire: = Palette.c("amber")
	_draw_wrecks(nv, view, now, kz, foam)
	for s: Ship in nv.ships:
		var p: Vector2 = s.pos.round()
		if not view.has_point(p) or (s.c != me and not _shows_ship(s.c, p)):
			continue
		var list: float = clampf(s.sink_t / Navy.SINK_T, 0.0, 1.0) if s.state == Ship.State.SINK else 0.0
		var flash: bool = now - s.hit_t < 0.25
		var key: String = String(HULL_KEYS[s.hull])
		if _at != null and _at.has(key):
			_ship_art(s, p, key, list, flash, now)
		else:
			_wake(s, foam)
			_ship(s, p, sc, 1.0 - list * 0.85, list, flash)
			var fwd: = Vector2.from_angle(s.heading)
			for fr: Array in s.fires:
				var off: Vector2 = fr[0]
				var fp: Vector2 = p + (fwd * off.x + fwd.orthogonal() * off.y) * sc
				draw_rect(Rect2(fp.round() - Vector2(1, 1), Vector2(2, 2) * sc), Color(fire, 0.6 + 0.4 * sin(now * 13.0 + off.x)))
				for j in 3:
					var age: float = fposmod(now * 0.8 + float(j) / 3.0 + off.x * 0.1, 1.0)
					draw_rect(Rect2((fp + Vector2(age * 6.0, - age * 10.0) * sc).round(), Vector2(2, 2) * sc * (1.0 + age)), Color(0.15, 0.14, 0.13, 0.5 * (1.0 - age)))

		if not s.fires.is_empty() and _d28 != null:
			_smoke_column(p, s.fires.size(), s.id, 1.0, now, kz)
		elif not s.fires.is_empty():
			var nf: int = s.fires.size()
			for j in 10:
				var g3: float = fposmod(now * 0.25 + float(j) * 0.1 + float(s.id) * 0.13, 1.0)
				var q5: Vector2 = p + Vector2(g3 * 20.0 + sin(now + float(j)) * 2.0, - g3 * (50.0 + 12.0 * float(nf))) * kz
				var r5: float = (3.0 + g3 * 10.0) * kz
				draw_rect(Rect2(q5 - Vector2(r5, r5) * 0.5, Vector2(r5, r5)), Color(0.07, 0.07, 0.07, 0.7 * (1.0 - g3)))

		if s.alive() and (s.c == me or now - s.hit_t < 6.0) and s.hp < s.hp_max:
			var w: float = 14.0
			var bp: Vector2 = p + Vector2( - w * 0.5, - float(S[s.hull]) * 0.55 - 3.0)
			draw_rect(Rect2(bp, Vector2(w, 2.0)), Color(0, 0, 0, 0.6))
			var r: float = s.hp / maxf(1.0, s.hp_max)
			draw_rect(Rect2(bp, Vector2(w * r, 2.0)), Palette.c("amber") if r > 0.5 else Color(0.85, 0.2, 0.15))

	for m: Dictionary in nv.msl:
		var mp: Vector2 = (m["pos"] as Vector2).round()
		if not view.has_point(mp):
			continue
		var hd: float = float(m["heading"])
		var dirv: = Vector2.from_angle(hd)
		_missile_trail(m, mp, dirv, now, kz)
		if _fx != null and _fx.has("asm_missile"):
			_blit(_fx, "asm_missile", (int(now * 12.0) % 2) * 16 + _dir16(hd), mp)
		else:
			draw_line(mp - dirv * 4.0, mp, Palette.c("concrete_light"), 1.0)
			draw_rect(Rect2(mp - dirv * 5.0 - Vector2(0.5, 0.5), Vector2(1.5, 1.5)), Color(fire, 0.9))
	_draw_vis(nv, view, now, kz)
	_draw_cm_boost(nv, view, now, kz)
	_draw_cm_spray(nv, view, now, kz)
	if _art_top == null:
		_draw_art_shells(view, kz)





func _missile_trail(m: Dictionary, mp: Vector2, dirv: Vector2, now: float, kz: float) -> void :
	var tr: PackedVector2Array = m.get("trail", PackedVector2Array())
	var nt: int = tr.size()
	var prev: Vector2 = mp - dirv * 4.0
	for j in range(nt - 1, -1, -1):
		var age: float = float(nt - j) / float(maxi(1, nt))
		var q: Vector2 = tr[j] + Vector2(sin(float(j) * 1.7 + now * 2.0) * age * 1.5, - age * 5.0)
		draw_line(prev + Vector2(1, 1) * kz, q + Vector2(1, 1) * kz, Color(0.08, 0.1, 0.16, 0.22 * (1.0 - age)), (1.2 + age * 3.0) * kz)
		draw_line(prev, q, Color(0.9, 0.9, 0.88, 0.75 * (1.0 - age)), (1.2 + age * 3.0) * kz)
		if j % 2 == 0:
			var r: float = (1.0 + age * 3.0) * kz
			draw_rect(Rect2(q + Vector2(fposmod(float(j) * 3.3, 3.0) - 1.5, -1.0) * kz - Vector2(r, r) * 0.5, Vector2(r, r)), Color(1, 1, 1, 0.35 * (1.0 - age)))
		prev = q
	var fl: float = 0.6 + 0.4 * sin(now * 47.0 + float(m["id"]))
	draw_rect(Rect2(mp - dirv * 5.0 - Vector2(1.5, 1.5) * kz, Vector2(3, 3) * kz), Color(1.0, 0.7, 0.25, fl))
	draw_rect(Rect2(mp - dirv * 4.0 - Vector2(0.75, 0.75) * kz, Vector2(1.5, 1.5) * kz), Color(1, 1, 0.85, 1.0))
	for j in 3:
		var sp: Vector2 = mp + Vector2(0, 2.5) - dirv * (2.0 + float(j) * 3.0) + dirv.orthogonal() * sin(now * 31.0 + float(j)) * 2.0
		draw_rect(Rect2(sp.round(), Vector2(1, 1) * kz), Color(Palette.c("water_foam"), 0.8 - float(j) * 0.2))


func _draw_vis(nv: Navy, view: Rect2, now: float, kz: float = 1.0) -> void :
	for v: Dictionary in nv.vis:
		var f: float = clampf((now - float(v["t0"])) / maxf(0.05, float(v["t1"]) - float(v["t0"])), 0.0, 1.0)
		if now > float(v["t1"]):
			continue
		var src: Ship = nv.ship(int(v["from"]))
		var p0: Vector2 = src.pos if src != null else v["p0"]
		var p1: Vector2 = v["p"]
		if v.has("msl"):
			for m: Dictionary in nv.msl:
				if int(m["id"]) == int(v["msl"]):
					p1 = m["pos"]
					break
		elif v.has("drone") and v["drone"] is Drone:
			p1 = (v["drone"] as Drone).pos
		v["p"] = p1
		if not view.has_point(p0) and not view.has_point(p1):
			continue
		var dirv: Vector2 = (p1 - p0).normalized()
		var kind: String = String(v["k"])
		if kind == "burst" and _d28 != null:
			_burst(p0, f, bool(v.get("big", false)), kz)
			continue
		if kind == "burst":
			var big: bool = bool(v.get("big", false))
			for j in 10:
				var a: float = TAU * float(j) / 10.0 + float(j) * 0.37
				var r0: float = f * (16.0 if big else 9.0) * kz
				draw_line(p0 + Vector2.from_angle(a) * r0 * 0.4, p0 + Vector2.from_angle(a) * r0, Color(1.0, 0.85, 0.4, 1.0 - f), 1.0 * kz)
			continue
		if kind == "splash" and _d28 != null:
			_splash(p0, f, kz)
			continue
		if kind == "splash":
			var h: float = 22.0 * sin(PI * minf(1.0, f * 1.3)) * kz
			for j in 5:
				var x: float = (float(j) - 2.0) * 1.6 * kz
				draw_line(p0 + Vector2(x, 0), p0 + Vector2(x * 1.6, - h * (1.0 - absf(float(j) - 2.0) * 0.25)), Color(0.92, 0.96, 1.0, 0.85 * (1.0 - f)), 1.2 * kz)
			draw_rect(Rect2(p0 - Vector2(5, 1) * kz * (1.0 + f), Vector2(10, 2) * kz * (1.0 + f)), Color(Palette.c("water_foam"), 0.7 * (1.0 - f)))
			continue
		if kind == "flares":
			var t: float = now - float(v["t0"])
			var hd0: float = float(v.get("hd", 0.0)) + PI
			for j in 6:
				var a2: float = hd0 + (float(j) - 2.5) * 0.35
				for tail in 4:
					var tt: float = maxf(0.0, t - float(tail) * 0.06)
					var q3: Vector2 = p0 + Vector2.from_angle(a2) * 34.0 * tt + Vector2(0, -18.0 * tt + 14.0 * tt * tt)
					var al: float = (1.0 - f) * (1.0 - float(tail) * 0.25)
					var rr3: float = (2.0 if tail == 0 else 1.0) * kz
					draw_rect(Rect2(q3 - Vector2(rr3, rr3) * 0.5, Vector2(rr3, rr3)), Color(1.0, 0.95 - float(tail) * 0.2, 0.7 - float(tail) * 0.2, al))
			continue
		if kind == "vls":
			var rise: float = 30.0 * (1.0 - pow(1.0 - minf(1.0, f * 1.6), 2.0)) * kz
			var top: Vector2 = p0 + Vector2(0, - rise)
			draw_line(p0, top, Color(1, 1, 1, 0.75 * (1.0 - f)), 2.0 * kz)
			draw_rect(Rect2(top - Vector2(1.5, 1.5) * kz, Vector2(3, 3) * kz), Color(1.0, 0.8, 0.35, 1.0 - f * 0.5))
			for j in 6:
				var r4: float = (3.0 + f * 9.0) * kz
				var q4: Vector2 = p0 + Vector2(cos(float(j) * 1.1) * f * 10.0, - float(j) * 2.0) * kz
				draw_rect(Rect2(q4 - Vector2(r4, r4) * 0.5, Vector2(r4, r4)), Color(0.95, 0.95, 0.95, 0.5 * (1.0 - f)))
			continue
		if kind == "ciws":
			var side: Vector2 = dirv.orthogonal()
			var crisp: bool = _d28 != null
			for j in 16:
				var g: float = fposmod((now - float(v["t0"])) * 6.0 + float(j) * 0.0625, 1.0)
				var q: Vector2 = p0.lerp(p1, g) + side * sin(now * 23.0 + float(j) * 0.9) * 3.0 * (1.0 - g)
				if crisp:
					if j % 4 == 3:
						continue
					q = p0.lerp(p1, g) + side * sin(float(j) * 2.3 + float(v["t0"]) * 7.0) * 2.0 * (1.0 - g)
					draw_line(q - dirv * 3.0 * kz, q, Color(1.0, 0.55, 0.15, 0.55), 1.0 * kz)
					draw_line(q, q + dirv * 3.0 * kz, Color(1.0, 0.95, 0.6, 1.0), 1.0 * kz)
					continue
				draw_line(q, q + dirv * 6.0, Color(1.0, 0.92, 0.5, 0.95), 1.4 * kz)
				if _fx != null and _fx.has("ciws_tracer") and j % 2 == 0:
					_blit(_fx, "ciws_tracer", _dir16(dirv.angle()), q, Color(1, 1, 1, 0.9))
			draw_rect(Rect2(p0 + dirv * 4.0 - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1.0, 0.95, 0.6, 0.6 + 0.4 * sin(now * 50.0)))
		else:
			var q2: Vector2 = p0.lerp(p1, f) + Vector2(0, -12.0 * sin(PI * f))
			var prev2: Vector2 = q2
			for j in 12:
				var g2: float = maxf(0.0, f - float(j + 1) * 0.045)
				var qq: Vector2 = p0.lerp(p1, g2) + Vector2(0, -12.0 * sin(PI * g2) - float(j) * 0.5)
				draw_line(prev2, qq, Color(1, 1, 1, 0.85 - float(j) * 0.065), (1.5 + float(j) * 0.25) * kz)
				prev2 = qq
			draw_rect(Rect2(q2 - Vector2(2.5, 2.5) * kz, Vector2(5, 5) * kz), Color(1.0, 0.8, 0.3, 0.55))
			draw_rect(Rect2(q2 - Vector2(1, 1) * kz, Vector2(2, 2) * kz), Color(1, 1, 0.9, 1.0))
			var hd2: float = (p0.lerp(p1, minf(1.0, f + 0.05)) + Vector2(0, -12.0 * sin(PI * minf(1.0, f + 0.05))) - q2).angle()
			if _fx != null and _fx.has("sam_interceptor"):
				_blit(_fx, "sam_interceptor", (int(now * 12.0) % 2) * 16 + _dir16(hd2), q2)
			else:
				draw_rect(Rect2(q2 - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 0.9))




func _draw_wrecks(nv: Navy, view: Rect2, now: float, kz: float, foam: Color) -> void :
	var at: SpriteAtlas = gw.get("atlas9") as SpriteAtlas
	for wk: Dictionary in nv.wrecks:
		var p: Vector2 = (wk["pos"] as Vector2).round()
		if not view.has_point(p):
			continue
		var f: float = clampf((now - float(wk["t0"])) / Navy.WRECK_T, 0.0, 1.0)
		var hv: Vector2 = Vector2.from_angle(float(wk["heading"]))

		var a: float = clampf(1.0 - (f - 0.15) / 0.55, 0.0, 1.0)
		if a > 0.0:
			if at != null and at.has("ship_cargo"):
				var inf: Dictionary = at.info("ship_cargo")
				var rc: Rect2 = at.rect("ship_cargo", int(wk["frame"]))
				draw_set_transform(p + Vector2(0, f * 4.0), 0.0, Vector2(1.0, 1.0 - 0.45 * minf(1.0, f * 2.0)))
				draw_texture_rect_region(at.texture, Rect2( - Vector2(float(inf["ax"]), float(inf["ay"])), rc.size), rc, Color(0.75, 0.7, 0.65, a))
				draw_set_transform(Vector2.ZERO)
			else:
				draw_line(p - hv * 6.0, p + hv * 6.0, Color(0.6, 0.5, 0.4, a), 3.0)

		if f < 0.55:
			var fl: float = 0.6 + 0.4 * sin(now * 15.0 + float(wk["t0"]))
			draw_rect(Rect2(p + Vector2(-1, -2) * kz, Vector2(2, 2) * kz), Color(1.0, 0.6, 0.2, fl * (1.0 - f / 0.55)))
			for j in 6:
				var g: float = fposmod(now * 0.3 + float(j) / 6.0, 1.0)
				var q: Vector2 = p + Vector2(g * 10.0, - g * 26.0) * kz
				var r: float = (2.0 + g * 5.0) * kz
				draw_rect(Rect2(q - Vector2(r, r) * 0.5, Vector2(r, r)), Color(0.12, 0.12, 0.12, 0.5 * (1.0 - g) * (1.0 - f / 0.55)))

		if f > 0.3:
			var rr: float = (f - 0.3) * 14.0 * kz
			for j in 10:
				var ang: float = TAU * float(j) / 10.0 + float(wk["t0"])
				draw_rect(Rect2((p + Vector2.from_angle(ang) * rr).round(), Vector2(1, 1) * kz), Color(foam, 0.7 * (1.0 - f)))
			for j in 4:
				var b: float = fposmod(now * 1.3 + float(j) * 0.37, 1.0)
				draw_rect(Rect2((p + Vector2(float(j) * 2.0 - 3.0, - b * 3.0)).round(), Vector2(1, 1)), Color(1, 1, 1, 0.6 * (1.0 - f)))

		for j in 7:
			var dir: Vector2 = Vector2.from_angle(float(j) * 0.9 + float(wk["t0"]))
			var q2: Vector2 = p + dir * (2.0 + f * 12.0) + hv * sin(now * 0.7 + float(j)) * 0.8
			draw_rect(Rect2(q2.round(), Vector2(1 + j % 2, 1)), Color(0.45, 0.32, 0.2, 0.9 * (1.0 - f * 0.6)) if j % 3 != 0 else Color(0.85, 0.35, 0.2, 0.8 * (1.0 - f)))




func _draw_cm_boost(nv: Navy, view: Rect2, now: float, kz: float) -> void :
	var me: int = gw.player.id if gw.player != null else -1
	var a5: SpriteAtlas = gw.atlas5
	var fly_t: float = Navy.CM_RISE + Navy.CM_TURN
	for e: Dictionary in nv.cm_boost:
		var p0: Vector2 = e["p0"]
		if not view.has_point(p0) or (int(e["c"]) != me and not _shows(int(e["c"]), p0)):
			continue
		var t: float = now - float(e["t0"])
		var tm: float = minf(t, fly_t)

		var n: int = int(tm / 0.05)
		for j in n:
			var ts: float = float(j) * 0.05
			var age: float = t - ts
			var al: float = clampf(1.0 - age / Navy.CM_SMOKE, 0.0, 1.0)
			if al <= 0.0:
				continue
			var q: Vector2 = Navy.cm_path(e, ts)[0] + Vector2(sin(float(j) * 1.3) * age * 2.5, - age * 3.0)
			var r: float = (1.5 + age * 3.5) * kz
			if _d28 != null:
				_puff(P_WHITE, r * 0.55 + 1.0, (1.0 - al) * 0.9, q, Color(1, 1, 1, 0.92))
				continue
			draw_rect(Rect2(q - Vector2(r, r) * 0.5 + Vector2(1, 1) * kz, Vector2(r, r)), Color(0.08, 0.1, 0.16, 0.12 * al))
			draw_rect(Rect2(q - Vector2(r, r) * 0.5, Vector2(r, r)), Color(0.93, 0.93, 0.9, 0.55 * al))
		if t >= fly_t:
			continue

		if t < 0.5:
			var kc: float = t / 0.5
			for j in 6:
				var rc: float = (4.0 + kc * 8.0) * kz
				var qc: Vector2 = p0 + Vector2(cos(float(j) * 1.05) * kc * 9.0, sin(float(j) * 1.05) * kc * 4.0)
				draw_rect(Rect2(qc - Vector2(rc, rc) * 0.5, Vector2(rc, rc)), Color(1.0, 0.92, 0.8, 0.45 * (1.0 - kc)))
		var ph: Array = Navy.cm_path(e, t)
		var mp: Vector2 = ph[0]
		var hd: float = float(ph[1])
		var dirv: Vector2 = Vector2.from_angle(hd)

		var gp: Vector2 = p0.lerp(p0 + Vector2.from_angle(float(e["hd"])) * Navy.CM_OUT, clampf((t - Navy.CM_RISE) / Navy.CM_TURN, 0.0, 1.0))
		var fl: float = 0.7 + 0.3 * sin(now * 53.0 + float(e["t0"]) * 7.0)

		var fq: Vector2 = mp - dirv * 4.5
		draw_rect(Rect2((fq - dirv * (2.5 + 2.0 * fl) - Vector2(0.75, 0.75) * kz).round(), Vector2(1.5, 1.5) * kz), Color(1.0, 0.35, 0.12, 0.85 * fl))
		draw_rect(Rect2((fq - dirv * 1.5 - Vector2(1.25, 1.25) * kz).round(), Vector2(2.5, 2.5) * kz), Color(1.0, 0.68, 0.18, 0.95))
		draw_rect(Rect2((fq - Vector2(0.75, 0.75) * kz).round(), Vector2(1.5, 1.5) * kz), Color(1.0, 1.0, 0.88, 1.0))
		var cm: SpriteAtlas = gw.atlas_cm28
		if cm != null and cm.has("cm") and cm.has("cm_shadow"):
			_blit(cm, "cm_shadow", _dir16(float(e["hd"])), gp + Vector2(2, 2), Color(1, 1, 1, 0.6))
			_blit(cm, "cm", _dir16(hd), mp)
		elif a5 != null and a5.has("cruise"):
			if a5.has("cruise_shadow"):
				_blit(a5, "cruise_shadow", _dir16(float(e["hd"])), gp + Vector2(2, 2), Color(1, 1, 1, 0.6))
			_blit(a5, "cruise", _dir16(hd), mp)
		else:
			draw_line(mp - dirv * 4.0, mp + dirv * 2.0, Palette.c("concrete_light"), 2.0)



func _draw_cm_spray(nv: Navy, view: Rect2, now: float, kz: float) -> void :
	if gw.mil == null:
		return
	var me: int = gw.player.id if gw.player != null else -1
	var foam: Color = Palette.c("water_foam")
	for d: Drone in gw.mil.drones:
		if not d.low or d.state != Drone.State.FLY or not view.has_point(d.pos):
			continue
		if d.country_id != me and not _shows(d.country_id, d.pos):
			continue
		if nv._body_px(d.pos) <= 0:
			continue
		var bk: Vector2 = - Vector2.from_angle(d.heading)
		var sd: Vector2 = bk.orthogonal()
		for j in 5:
			var g: float = float(j) * 3.0 + fposmod(now * 40.0, 3.0)
			var a: float = 0.7 * (1.0 - float(j) / 5.0)
			var w: float = 0.5 + float(j) * 0.6
			for sgn: float in [-1.0, 1.0]:
				var q: Vector2 = d.pos + Vector2(1, 2) + bk * (3.0 + g) + sd * w * sgn
				draw_rect(Rect2(q.round(), Vector2(1, 1) * kz), Color(foam, a))




func _puff(tone: int, r: float, diss: float, p: Vector2, col: Color) -> void :
	var k: float = maxf(1.0, ceilf(r / 7.5))
	var si: int = clampi(roundi(r / k) - 2, 0, 5)
	var di: int = clampi(int(diss * 3.0), 0, 2)
	var src: = Rect2(float(1 + (di * 6 + si) * 16), float(_pf_y[tone]), 16.0, 16.0)
	draw_texture_rect_region(_d28, Rect2((p - Vector2(8.0, 8.0) * k).round(), Vector2(16.0, 16.0) * k), src, col)




func _smoke_column(p: Vector2, nf: int, sid: int, k: float, now: float, kz: float) -> void :
	if k <= 0.02:
		return
	var n: int = 10 if kz < 1.3 else 8
	var big: float = 1.0 if kz < 1.3 else 1.3
	var c: float = fposmod(now * 0.2 + float(sid) * 0.13, 1.0)
	var jm: int = ceili((1.0 - c) * float(n)) - 1
	var hgt: float = 50.0 + 12.0 * float(mini(nf, 4))
	var wide: float = 0.85 + 0.15 * float(mini(nf, 3))
	for i in n:
		var j: int = posmod(jm - i, n)
		var g: float = fposmod(c + float(j) / float(n), 1.0)
		var sway: float = sin(now * 0.9 + float(j) * 1.7 + float(sid)) * 2.0 * g
		var q: Vector2 = p + Vector2(g * g * 24.0 + sway, -5.0 - g * hgt) * kz
		var a: float = k * (1.0 if g < 0.85 else (1.0 - g) / 0.15)
		_puff(P_FIRE if g < 0.1 else P_DARK, minf((1.4 + g * 7.0) * wide * big, 7.4 * big) * kz, maxf(0.0, (g - 0.45) / 0.55), q, Color(1, 1, 1, a))




func _sink_fx(s: Ship, p: Vector2, list: float, d: int, inf: Dictionary, now: float) -> void :
	var kz: float = _kz
	var st: float = s.sink_t
	if _fx != null and _fx.has("ship_fire") and list < 0.6:
		var slots: Variant = inf.get("slots", [])
		if slots is Array and d < (slots as Array).size():
			var row: Array = (slots as Array)[d]
			for k in mini(2, row.size()):
				var off: = Vector2(float(row[k][0]), float(row[k][1])) * (1.0 - list * 0.7) + Vector2(0, list * 5.0)
				_blit(_fx, "ship_fire", int(now * 10.0 + float(k) * 3.0) % 6, p + off, Color(1, 1, 1, 1.0 - list / 0.6))
	_smoke_column(p, 3, s.id, clampf(1.15 - list * 1.1, 0.0, 1.0), now, kz)
	if _fx != null and _fx.has("explosion_sea"):
		var hv: = Vector2.from_angle(s.heading)
		for b in SINK_BLASTS.size():
			var e: float = st - float(SINK_BLASTS[b])
			if e >= 0.0 and e < 0.6:
				_blit(_fx, "explosion_sea", mini(7, int(e * 13.0)), p + hv * (6.0 - 6.0 * float(b)) + Vector2(0, 2))
	if list > 0.35 and list < 0.95:
		var ka: float = minf(1.0, (list - 0.35) / 0.15) * minf(1.0, (0.95 - list) / 0.15)
		for j in 4:
			var g: float = fposmod(now * 0.7 + float(j) * 0.25 + float(s.id) * 0.1, 1.0)
			var q: Vector2 = p + Vector2(sin(float(j) * 2.1) * 5.0 + g * 3.0, -2.0 - g * 14.0) * kz
			_puff(P_WHITE, (1.5 + g * 3.0) * kz, g, q, Color(1, 1, 1, 0.9 * ka))



func _burst(p0: Vector2, f: float, big: bool, kz: float) -> void :
	var rr: float = (16.0 if big else 10.0) * kz
	if f < 0.18:
		var fs: float = (3.0 if big else 2.0) * kz * (1.0 - f / 0.18 * 0.5)
		draw_rect(Rect2((p0 - Vector2(fs, fs)).round(), Vector2(fs, fs) * 2.0), Color(1.0, 1.0, 0.9, 1.0))
	_puff(P_DARK, (1.5 + f * (4.0 if big else 2.5)) * kz, f, p0 + Vector2(0, - f * 6.0) * kz, Color(1, 1, 1, 0.85 * (1.0 - f * 0.5)))
	var eo: float = 1.0 - (1.0 - f) * (1.0 - f)
	var hot: = Color(1.0, 0.95, 0.65)
	var mid: = Color(1.0, 0.6, 0.2)
	var cold: = Color(0.75, 0.22, 0.12)
	for j in (10 if big else 7):
		var a: float = TAU * float(j) / (10.0 if big else 7.0) + float(j) * 0.61
		var sp: float = 0.6 + 0.4 * fposmod(float(j) * 0.37, 1.0)
		var q: Vector2 = p0 + Vector2.from_angle(a) * rr * sp * eo + Vector2(0, 10.0 * f * f) * kz
		var c: Color = hot.lerp(mid, minf(1.0, f * 2.0)) if f < 0.5 else mid.lerp(cold, (f - 0.5) * 2.0)
		draw_rect(Rect2(q.round(), Vector2(1, 1) * kz * (2.0 if j % 3 == 0 and f < 0.4 else 1.0)), Color(c, 1.0 - f * f))



func _splash(p0: Vector2, f: float, kz: float) -> void :
	var h: float = 18.0 * sin(PI * minf(1.0, f * 1.3)) * kz
	var foam: Color = Palette.c("water_foam")
	for j in 10:
		var a: float = TAU * float(j) / 10.0
		var q: Vector2 = p0 + Vector2(cos(a) * (3.0 + f * 9.0), sin(a) * (1.5 + f * 4.0)) * kz
		draw_rect(Rect2(q.round(), Vector2(1, 1) * kz), Color(foam, 0.85 * (1.0 - f)))
	if h > 0.5:
		for j in 3:
			var q2: Vector2 = p0 + Vector2((float(j) - 1.0) * 1.5 * kz, - h * (0.25 + 0.35 * float(j)))
			_puff(P_WHITE, (2.6 - float(j) * 0.5 + f * 1.5) * kz, f * 1.2, q2, Color(1, 1, 1, 0.95))
	for j in 6:
		var a2: float = - PI * 0.5 + (float(j) - 2.5) * 0.42
		var t: float = f * 1.2
		var q3: Vector2 = p0 + Vector2(cos(a2) * 14.0 * t, sin(a2) * 26.0 * t + 34.0 * t * t) * kz
		if q3.y < p0.y + 1.0:
			draw_rect(Rect2(q3.round(), Vector2(1, 1) * kz), Color(0.92, 0.97, 1.0, 0.9 * (1.0 - f)))


static func _dir16(a: float) -> int:
	return posmod(roundi(a / TAU * 16.0), 16)



func _blit(at: SpriteAtlas, sprite: String, frame: int, p: Vector2, col: Color = Color.WHITE) -> void :
	var inf: Dictionary = at.info(sprite)
	var nf: int = maxi(1, int(inf.get("frames", 1)))
	var rc: Rect2 = at.rect(sprite, clampi(frame, 0, nf - 1))
	var anc: = Vector2(float(inf.get("ax", rc.size.x * 0.5)), float(inf.get("ay", rc.size.y * 0.5)))
	draw_texture_rect_region(at.texture, Rect2((p - anc).round(), rc.size), rc, col)


static func _pt(inf: Dictionary, key: String, d: int) -> Vector2:
	var arr: Variant = inf.get(key, [])
	if arr is Array and d < (arr as Array).size() and (arr as Array)[d] is Array and ((arr as Array)[d] as Array).size() >= 2:
		return Vector2(float(arr[d][0]), float(arr[d][1]))
	return Vector2.ZERO



func _ship_art(s: Ship, p: Vector2, key: String, list: float, flash: bool, now: float) -> void :
	var d: int = s.dir16()
	var inf: Dictionary = _at.info(key)
	var tint: = Color(1.6, 1.4, 1.2) if flash else Color.WHITE
	if s.state == Ship.State.SINK:
		var sk: String = key + "_sink"
		if _at.has(sk):
			var stage: int = mini(4, int(list * 5.0))
			_blit(_at, sk, stage * 8 + posmod(roundi(float(d) / 2.0), 8), p)
		else:
			_blit(_at, key, d, p + Vector2(0, list * 2.0), Color(1, 1, 1, 1.0 - list * 0.85))
		if _d28 != null:
			_sink_fx(s, p, list, d, inf, now)
		return
	if _fx != null and s.speed > 1.0:
		if _fx.has("wake"):
			_blit(_fx, "wake", (int(now * 8.0 + float(s.id)) % 4) * 16 + d, p + _pt(inf, "stern", d), Color(1, 1, 1, clampf(s.speed / 10.0, 0.3, 1.0)))
		if _fx.has("bow_spray") and s.speed > 3.0:
			_blit(_fx, "bow_spray", (int(now * 10.0) % 2) * 16 + d, p + _pt(inf, "bow", d))
	elif not s.trail.is_empty():
		_wake(s, Palette.c("water_foam"))
	if _at.has(key + "_shadow"):
		_blit(_at, key + "_shadow", d, p + Vector2(1, 1), Color(0, 0, 0, 0.35))
	var hk: String = key + "_dmg" if s.hp < s.hp_max * 0.5 and _at.has(key + "_dmg") else key
	_owner_mark(s, p, float(inf.get("length_px", 28)))
	_blit(_at, hk, d, p, tint)

	var slots: Variant = inf.get("slots", [])
	var pts: Array = []
	if slots is Array and d < (slots as Array).size():
		var row: Array = (slots as Array)[d]
		for i in mini(row.size(), s.mods.size()):
			pts.append([float(row[i][1]), i, Vector2(float(row[i][0]), float(row[i][1]))])
	pts.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var firing: bool = now - s.shot_t < 0.25
	var ad: int = _dir16(s.aim) if firing else d
	for e: Array in pts:
		var m: String = s.mods[int(e[1])]
		var mk: String = "mod_" + m
		var ma: SpriteAtlas = _at if _at.has(mk) else _a30
		if ma == null or not ma.has(mk):
			continue
		var turret: bool = m == "gun" or m == "ciws"
		var st: int = 1 if firing and turret and (m == "gun" or int(now * 15.0) % 2 == 0) else 0
		if m == "art":
			st = 1 if now - s.art_t < 0.22 else 0
			_blit(ma, mk, st * 16 + (_dir16(s.art_aim) if now - s.art_t < 4.0 else d), p + (e[2] as Vector2), tint)
			if now - s.art_t < 1.8 and _d28 != null:
				var ga: float = (now - s.art_t) / 1.8
				_puff(P_WHITE, 2.0 + ga * 5.0, ga, p + (e[2] as Vector2) + Vector2.from_angle(s.art_aim) * (5.0 + ga * 4.0) + Vector2(ga * 3.0, - ga * 6.0), Color(1, 1, 1, 0.8 * (1.0 - ga)))
			continue
		if m == "vls":
			st = 1 if now - s.vls_t < 1.5 else 0
		elif m == "ash":
			st = 1 if now - s.ash_t < 0.6 else 0
		elif m == "sam":
			st = 1 if s.sam_busy - now > Navy.SAM_BUSY * 0.5 else 0
		_blit(ma, mk, st * 16 + (ad if turret else d), p + (e[2] as Vector2), tint)

	if not s.fires.is_empty() and slots is Array and d < (slots as Array).size():
		var row2: Array = (slots as Array)[d]
		for k in s.fires.size():
			var sp: Vector2 = p + (Vector2(float(row2[k % row2.size()][0]), float(row2[k % row2.size()][1])) if not row2.is_empty() else Vector2.ZERO)
			if _d28 != null and _kz < 1.3:
				var gk: float = fposmod(now * 1.1 + float(k) * 0.37, 1.0)
				_puff(P_FIRE, 1.5 + gk * 2.5, gk, sp + Vector2(gk * 2.0, -3.0 - gk * 7.0), Color.WHITE)
			elif _d28 == null and _fx != null and _fx.has("ship_smoke"):
				_blit(_fx, "ship_smoke", int(now * 8.0 + float(k) * 3.0) % 8, sp + Vector2(0, -2), Color(1, 1, 1, 0.8))
			if _fx != null and _fx.has("ship_fire"):
				_blit(_fx, "ship_fire", int(now * 10.0 + float(k) * 2.0) % 6, sp)




func _owner_mark(s: Ship, p: Vector2, length: float) -> void :
	var me: int = gw.player.id if gw.player != null else -1
	var oc: Country = gw.country_by_id(s.c)
	var col: Color = Palette.c("amber") if s.c == me else (oc.color_light if oc != null else Color.WHITE)
	var bw: float = clampf(length * 0.45, 10.0, 22.0)
	var y: float = absf(sin(s.heading)) * length * 0.5 + 3.0
	var r: = Rect2((p + Vector2( - bw * 0.5, y)).round(), Vector2(bw, 1.0))
	draw_rect(r.grow(1.0), Color(0.05, 0.07, 0.1, 0.55))
	draw_rect(r, col)


func _ship(s: Ship, p: Vector2, sc: float, alpha: float, list: float, flash: bool) -> void :
	var tint: = Color(1.6, 1.4, 1.2, alpha) if flash else Color(1, 1, 1, alpha)
	var fr: int = s.dir16()
	var tex: Texture2D = _tex[s.hull]
	var cs: int = int(S[s.hull])
	var src: = Rect2(fr * cs, 0, cs, cs)
	var half: Vector2 = src.size * 0.5

	draw_set_transform(p + Vector2(0, list * 2.0), 0.0, Vector2(sc, sc * (1.0 - list * 0.35)))
	draw_texture_rect_region(tex, Rect2( - half + Vector2(1, 1), src.size), src, Color(0, 0, 0, 0.28 * alpha))
	draw_texture_rect_region(tex, Rect2( - half, src.size), src, tint)
	var c: Country = gw.country_by_id(s.c)
	if c != null:
		var back: Vector2 = - Vector2.from_angle(float(fr) * PI / 8.0) * (src.size.x * 0.32)
		draw_rect(Rect2(back.round() - Vector2(0, 1), Vector2(1, 2)), Color(c.color, alpha))
	draw_set_transform(Vector2.ZERO)


func _wake(s: Ship, foam: Color) -> void :
	var tr: PackedVector2Array = s.trail
	var nn: int = tr.size()
	if nn == 0:
		return
	var dirv: Vector2 = Vector2.from_angle(s.heading)
	var w0: float = 1.0 + float(s.hull) * 0.5
	for i in nn:
		var age: float = float(nn - i)
		var side: Vector2 = dirv.orthogonal() * (w0 + age * 0.7)
		var col: = Color(foam, 0.7 * (1.0 - age / float(nn + 1)))
		draw_rect(Rect2((tr[i] + side).round(), Vector2(1, 1)), col)
		draw_rect(Rect2((tr[i] - side).round(), Vector2(1, 1)), col)




func _draw_glow() -> void :
	if gw == null or gw.navy == null or gw.camera == null or gw.night == null or _glow_tex == null:
		return
	var a: float = clampf(gw.night.factor, 0.0, 1.0)
	if a <= 0.05:
		return
	var nv: Navy = gw.navy
	var cam: MapCamera = gw.camera
	var z: float = maxf(0.05, cam.zoom.x)
	var view: = Rect2(cam.screen_to_world(Vector2.ZERO), cam.view_size() / z).grow(40.0)
	var now: float = gw.game_time
	var me: int = gw.player.id if gw.player != null else -1
	var warm: = Color(1.0, 0.62, 0.25)
	for s: Ship in nv.ships:
		if not view.has_point(s.pos) or (s.c != me and not _shows_ship(s.c, s.pos)):
			continue
		var nf: int = s.fires.size()
		if nf > 0:
			var fl: float = 0.85 + 0.15 * sin(now * 9.0 + float(s.id))
			_glow(s.pos + Vector2(0, -3), (10.0 + 4.0 * float(nf)) * fl, Color(warm, 0.55 * a * fl), z)
			_glow(s.pos + Vector2(0, -3), 4.0, Color(1.0, 0.85, 0.5, 0.6 * a), z)
		if s.state == Ship.State.SINK:
			var k: float = 1.0 - clampf(s.sink_t / Navy.SINK_T, 0.0, 1.0)
			_glow(s.pos, 16.0 * k, Color(warm, 0.5 * a * k), z)
		if now - s.shot_t < 0.15:
			_glow(s.pos, 7.0, Color(1.0, 0.9, 0.6, 0.6 * a), z)
		if now - s.vls_t < 1.2:
			_glow(s.pos + Vector2(0, -8), 14.0, Color(1.0, 0.8, 0.45, 0.6 * a * (1.0 - (now - s.vls_t) / 1.2)), z)
		if now - s.art_t < 0.25:
			_glow(s.pos + Vector2.from_angle(s.art_aim) * 5.0, 10.0, Color(1.0, 0.85, 0.5, 0.7 * a), z)
	for m: Dictionary in nv.msl:
		var mp: Vector2 = m["pos"]
		if view.has_point(mp):
			_glow(mp, 5.0, Color(1.0, 0.75, 0.35, 0.75 * a), z)
	for e: Dictionary in nv.cm_boost:
		var tb: float = now - float(e["t0"])
		if tb < Navy.CM_RISE + Navy.CM_TURN and view.has_point(e["p0"]):
			_glow(Navy.cm_path(e, tb)[0], 8.0, Color(1.0, 0.75, 0.4, 0.8 * a), z)
	if gw.army != null and gw.army.fire != null:
		for sh: Dictionary in gw.army.fire.shells:
			if sh.has("nv") and view.has_point(sh["to"]):
				_glow(_art_arc(sh, float(sh["t"])), 4.0, Color(1.0, 0.8, 0.45, 0.6 * a), z)
	for v: Dictionary in nv.vis:
		if now > float(v["t1"]):
			continue
		var kind: String = String(v["k"])
		var vp: Vector2 = v.get("p", v.get("p0", Vector2.ZERO))
		if kind == "burst":
			var f: float = clampf((now - float(v["t0"])) / maxf(0.05, float(v["t1"]) - float(v["t0"])), 0.0, 1.0)
			_glow(v.get("p0", vp), 14.0 + 10.0 * f, Color(1.0, 0.8, 0.45, 0.7 * a * (1.0 - f)), z)
		elif kind == "ciws":
			var src: Ship = nv.ship(int(v["from"]))
			if src != null:
				_glow(src.pos, 5.0, Color(1.0, 0.9, 0.55, (0.4 + 0.3 * sin(now * 50.0)) * a), z)
			_glow(vp, 4.0, Color(1.0, 0.9, 0.55, 0.45 * a), z)
		elif kind == "flares":
			var t: float = now - float(v["t0"])
			_glow(v.get("p0", vp) + Vector2(0, -12.0 * t), 12.0, Color(1.0, 0.92, 0.7, 0.5 * a * clampf(1.0 - t / 2.0, 0.0, 1.0)), z)
		elif kind == "sam":
			_glow(vp, 4.0, Color(1.0, 0.95, 0.8, 0.6 * a), z)

	for e: Dictionary in nv.events:
		var k2: String = String(e.get("k", ""))
		if k2 != "hit" and k2 != "intercepted" and k2 != "sink" and k2 != "convoy_sunk":
			continue
		var age: float = now - float(e.get("t", -99.0))
		var life: float = 1.2 if k2 == "intercepted" else 2.0
		if age < 0.0 or age > life or not (e.get("pos") is Vector2) or not view.has_point(e["pos"]):
			continue
		var big: float = 0.6 if k2 == "intercepted" else 1.0
		var q: float = 1.0 - age / life
		_glow(e["pos"], (16.0 + 18.0 * big) * (0.6 + 0.4 * q), Color(1.0, 0.7, 0.35, 0.8 * a * q * big), z)


func _glow(p: Vector2, r: float, col: Color, z: float) -> void :
	r = minf(r, 40.0 / z)
	if r <= 0.5 or col.a <= 0.01:
		return
	_glow_node.draw_texture_rect(_glow_tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, col)




const SPILL_OIL_T: float = 38.0
const SPILL_DEBRIS_T: float = 30.0





func _draw_spills(view: Rect2, now: float) -> void :
	_spill_built = 0
	var oil: = Palette.c("outline")
	var foam: = Palette.c("water_foam")
	for sp: Dictionary in gw.supply.spills:
		var p0: Vector2 = sp["pos"]
		if not view.grow(40.0).has_point(p0):
			continue
		var age: float = now - float(sp["t0"])
		var res: String = String(sp["res"])
		var sd: int = int(sp["sd"]) * 7919 + 13
		var oily: bool = res == "oil" or res == "fuel" or res == ""
		var drift: = Vector2.from_angle(float(sd % 628) / 100.0) * age * 0.35
		var c0: Vector2 = p0 + drift

		if age < 3.0:
			var rr: float = 3.0 + age * 5.0
			for k in 14:
				var a: float = TAU * float(k) / 14.0
				draw_rect(Rect2((c0 + Vector2.from_angle(a) * rr).round(), Vector2(1, 1)), Color(foam, 0.8 * (1.0 - age / 3.0)))

		var t_oil: float = SPILL_OIL_T if oily else 20.0
		if age < t_oil:
			var grow: float = (1.0 - exp( - age / 9.0))
			var rmax: float = 22.0 if oily else 8.0
			var R: float = 2.0 + rmax * grow
			var fade: float = clampf((t_oil - age) / 12.0, 0.0, 1.0)


			var rq: int = maxi(1, int(R / 2.0))
			draw_texture(_spill_tex(sd, oily, rq), c0.round() - Vector2(rq * 2, rq * 2), Color(1, 1, 1, fade))
			if oily:
				var sheen: Array = [Color(0.55, 0.35, 0.75), Color(0.25, 0.65, 0.7), Color(0.75, 0.65, 0.3)]
				for k3 in 18:
					var h2: int = (sd * 31 + k3 * 40503) & 65535
					var a2: float = float(h2 % 628) / 100.0
					var q: Vector2 = c0 + Vector2.from_angle(a2) * R * (0.7 + 0.25 * float((h2 >> 6) % 10) / 10.0)
					draw_rect(Rect2(q.round(), Vector2(1 + (k3 % 2), 1)), Color(sheen[k3 % 3], 0.85 * fade))
		if oily:
			continue

		if age >= SPILL_DEBRIS_T:
			continue
		var fd: float = clampf((SPILL_DEBRIS_T - age) / 8.0, 0.0, 1.0)
		var n: int = 7 if res == "wood" else 6
		for k4 in n:
			var h3: int = (sd * 17 + k4 * 92821) & 65535
			var a3: float = float(h3 % 628) / 100.0
			var v: float = 0.6 + 1.6 * float((h3 >> 5) % 10) / 10.0
			var dist: float = v * 8.0 * (1.0 - exp( - age / 8.0)) + 2.0
			var q2: Vector2 = (c0 + Vector2.from_angle(a3) * dist).round()
			var bob: bool = int(now * 2.0 + float(k4)) % 3 == 0
			match res:
				"wood":
					var horiz: bool = (h3 & 1) == 0
					var sz: = Vector2(4, 1) if horiz else Vector2(1, 4)
					draw_rect(Rect2(q2, sz), Color(Palette.c("wood"), fd))
					draw_rect(Rect2(q2, Vector2(1, 1)), Color(Palette.c("wood_light"), fd))
					if bob:
						draw_rect(Rect2(q2 + (Vector2(0, 1) if horiz else Vector2(1, 0)), Vector2(1, 1)), Color(foam, 0.5 * fd))
				"metal", "titanium", "precious":
					if k4 >= 4 and age > 12.0:
						continue
					draw_rect(Rect2(q2 - Vector2(1, 1), Vector2(3, 2)), Color(Palette.c("outline"), 0.8 * fd))
					draw_rect(Rect2(q2 - Vector2(1, 1), Vector2(2, 1)), Color(Palette.c("rock_light") if res != "precious" else Palette.c("amber"), fd))
					draw_rect(Rect2(q2 + Vector2(-1, 0), Vector2(1, 1)), Color(Palette.c("brick_dark"), fd))
				_:
					var big: bool = (h3 & 2) == 0
					var b: = Vector2(3, 3) if big else Vector2(2, 2)
					draw_rect(Rect2(q2 - Vector2(1, 1), b), Color(Palette.c("outline"), 0.85 * fd))
					draw_rect(Rect2(q2 - Vector2(1, 1), b - Vector2(1, 1)), Color(Palette.c("sand_dark") if res != "food" else Palette.c("wood_light"), fd))
					if bob:
						draw_rect(Rect2(q2 + Vector2(-1, b.y - 1), Vector2(b.x, 1)), Color(foam, 0.45 * fd))


var _spill_cache: Dictionary = {}
var _spill_built: int = 0



func _spill_tex(sd: int, oily: bool, rq: int) -> ImageTexture:
	var key: String = "%d:%d:%d" % [sd, 1 if oily else 0, rq]
	var t: Variant = _spill_cache.get(key)
	if t is ImageTexture:
		return t
	if _spill_built >= 2:

		for r2 in range(rq - 1, 0, -1):
			var t2: Variant = _spill_cache.get("%d:%d:%d" % [sd, 1 if oily else 0, r2])
			if t2 is ImageTexture:
				return t2
	_spill_built += 1
	if _spill_cache.size() > 96:
		_spill_cache.clear()
	var R: float = float(rq * 2)
	var blobs: Array = []
	for k2 in 7:
		var h: int = (sd + k2 * 2654435761) & 65535
		var ang: float = float(h % 628) / 100.0
		var dd: float = R * 0.5 * float((h >> 4) % 100) / 100.0
		var br: float = R * (0.4 + 0.3 * float((h >> 8) % 10) / 10.0)
		blobs.append([Vector2.from_angle(ang) * dd * Vector2(1.3, 0.8), br])
	var oil: = Palette.c("outline")
	var tone: = Color(oil, 0.68 if oily else 0.22)
	var edge: = Color(oil, 0.4 if oily else 0.12)
	var nc: int = rq * 2
	var img: = Image.create((nc + 1) * 2, (nc + 1) * 2, false, Image.FORMAT_RGBA8)
	for gy in nc + 1:
		for gx in nc + 1:
			var q0: = Vector2( - R + gx * 2, - R + gy * 2)
			var inside: float = 99.0
			for bl: Array in blobs:
				var dv: Vector2 = (q0 - (bl[0] as Vector2)) * Vector2(0.8, 1.25)
				inside = minf(inside, dv.length() - float(bl[1]))
			var col: Color = Color(0, 0, 0, 0)
			if inside < -1.5:
				col = tone
			elif inside < 0.5 and ((gx * 7 + gy * 13 + sd) % 3) != 0:
				col = edge
			if col.a > 0.0:
				img.fill_rect(Rect2i(gx * 2, gy * 2, 2, 2), col)
	var tex: = ImageTexture.create_from_image(img)
	_spill_cache[key] = tex
	return tex





func _draw_art_shells(view: Rect2, kz: float) -> void :
	if gw.army == null or gw.army.fire == null or gw.army.fire.shells.is_empty():
		return
	var hot: = Palette.c("fire_yellow")
	var core: = Palette.c("fire_core")
	var smk: = Palette.c("smoke_light")
	for sh: Dictionary in gw.army.fire.shells:
		if not sh.has("nv"):
			continue
		var t: float = float(sh["t"])
		var p: Vector2 = _art_arc(sh, t)
		if not view.has_point(p) or not _shows(int(sh["c"]), p):
			continue
		var prev: Vector2 = p
		for i in range(1, 12):
			var tt: float = t - float(i) * 0.05
			if tt <= 0.0:
				break
			var q: Vector2 = _art_arc(sh, tt)
			var fa: float = 1.0 - float(i) / 12.0
			draw_line(prev, q, Color(hot if i <= 2 else smk, (0.9 if i <= 2 else 0.55) * fa), maxf(1.0, kz * (1.6 - float(i) * 0.05)))
			prev = q
		var k: float = clampf(t / maxf(0.01, float(sh["dur"])), 0.0, 1.0)
		var g: Vector2 = (sh["from"] as Vector2).lerp(sh["to"], k)
		draw_rect(Rect2(g.round() - Vector2(1, 0), Vector2(2, 1)), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(p.round() - Vector2(1.5, 1.5) * kz, Vector2(3, 3) * kz), Color(0.1, 0.07, 0.05, 0.85))
		draw_rect(Rect2(p.round() - Vector2(1, 1) * kz, Vector2(2, 2) * kz), hot)
		draw_rect(Rect2(p.round() - Vector2(0.5, 0.5) * kz, Vector2(1, 1) * kz), core)


static func _art_arc(sh: Dictionary, t: float) -> Vector2:
	var k: float = clampf(t / maxf(0.01, float(sh["dur"])), 0.0, 1.0)
	return (sh["from"] as Vector2).lerp(sh["to"], k) + Vector2(0, - float(sh["h"]) * 4.0 * k * (1.0 - k))







func _draw_art_top() -> void :
	if gw == null or gw.navy == null or gw.camera == null or gw.navy.get("art") == null:
		return
	var art: NavyArt = gw.navy.art
	var cam: MapCamera = gw.camera
	var z: float = maxf(0.05, cam.zoom.x)
	var view: = Rect2(cam.screen_to_world(Vector2.ZERO), cam.view_size() / z).grow(40.0)
	var kz: float = clampf(1.0 / z, 1.0, 2.6)
	var far: bool = z < 0.35
	var now: float = gw.game_time
	var n: Node2D = _art_top
	var hot: = Color("ffc23d")
	var ora: = Color("ff7a1f")
	var core: = Color("fff1a8")
	var smk: = Palette.c("smoke_light")

	for e: Array in art.vis_salvo:
		var age: float = now - float(e[0])
		if age < 0.0 or age > 1.0 or not view.has_point(e[1]) or not _shows(int(e[3]), e[1]):
			continue
		var k: float = 1.0 - age
		var rr: float = float(e[2]) * (0.92 + 0.08 * k)
		n.draw_arc(e[1], rr, 0.0, TAU, 48, Color(0.05, 0.03, 0.02, 0.45 * k), 3.2 * kz, false)
		n.draw_arc(e[1], rr, 0.0, TAU, 48, Color(ora, 0.9 * k), 1.6 * kz, false)
		for q in 4:
			var d: = Vector2.from_angle(float(q) * PI * 0.5)
			n.draw_line(e[1] + d * rr * 0.75, e[1] + d * rr * 1.1, Color(hot, 0.9 * k), 1.4 * kz)

	if gw.army != null and gw.army.fire != null:
		var drawn: int = 0
		for sh: Dictionary in gw.army.fire.shells:
			if not sh.has("nv") or drawn >= 40:
				continue
			var t: float = float(sh["t"])
			var p: Vector2 = _art_arc(sh, t)
			if not view.has_point(p) or not _shows(int(sh["c"]), p):
				continue
			drawn += 1
			if not far:
				var prev: Vector2 = p
				for i in range(1, 15):
					var tt: float = t - float(i) * 0.035
					if tt <= 0.0:
						break
					var q2: Vector2 = _art_arc(sh, tt)
					var fa: float = 1.0 - float(i) / 15.0
					if i <= 5:
						n.draw_line(prev, q2, Color(hot.lerp(ora, float(i) / 5.0), 0.95 * fa), maxf(1.5, 2.6 * kz))
					else:
						n.draw_line(prev, q2, Color(smk, 0.6 * fa), maxf(1.0, 1.8 * kz))
					prev = q2
			n.draw_circle(p, 6.0 * kz, Color(hot, 0.18))
			n.draw_circle(p, 3.4 * kz, Color(ora, 0.6))
			n.draw_circle(p, 2.0 * kz, hot)
			n.draw_circle(p, 1.0 * kz, core)

	var shown: int = 0
	for k3 in range(art.vis_hits.size() - 1, -1, -1):
		var h: Array = art.vis_hits[k3]
		var a: float = now - float(h[0])
		var hp: Vector2 = h[1]
		if a < 0.0 or a > 2.2 or not view.has_point(hp) or not _shows(int(h[2]), hp):
			continue
		shown += 1
		if shown > 24:
			break
		var sd: int = int(hp.x * 7.0 + hp.y * 13.0)
		if a < 0.14:
			var f: float = a / 0.14
			n.draw_circle(hp, (6.0 + 20.0 * f) * minf(kz, 1.6), Color(core, 0.95 * (1.0 - f)))
		if a < 0.6:
			var g: float = a / 0.6
			var fr: float = 4.0 + 11.0 * sqrt(g)
			n.draw_circle(hp + Vector2(0, -2.0 * g), fr, Color(ora, 0.85 * (1.0 - g)))
			n.draw_circle(hp + Vector2(0, -2.5 * g), fr * 0.55, Color(hot, 0.9 * (1.0 - g)))
		if far:
			continue
		for j in 3:
			var ph: float = float((sd + j * 37) % 100) / 100.0
			var off: = Vector2(float((sd >> (j + 1)) % 9) - 4.0, float((sd >> (j + 3)) % 5) - 2.0)
			var dust: bool = j == 0
			var aj: float = a - 0.08 * float(j)
			if aj <= 0.0:
				continue
			var life: float = 1.6 + 0.4 * ph
			if aj > life:
				continue
			var u: float = aj / life
			var rad: float = (2.5 + 7.0 * sqrt(u)) * (1.2 if dust else 1.0)
			var col: Color = Color(0.55, 0.46, 0.33) if dust else Color(0.22, 0.21, 0.2)
			n.draw_circle(hp + off + Vector2(2.0 * u, - (4.0 + 10.0 * u) * (0.6 if dust else 1.0)), rad, Color(col, 0.6 * (1.0 - u)))
