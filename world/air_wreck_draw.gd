extends RefCounted











const AW = preload("res://game/air_wreck.gd")
const AM = preload("res://game/aftermath.gd")
const AD = preload("res://world/aftermath_draw.gd")


static func _ac_sprite(gw: GameWorld, src: int) -> Array:
	if src == Aircraft.Type.ATTACK:
		var a316: SpriteAtlas = UnitsLayer.atlas316()
		if a316 != null and a316.has("attack_nokab"):
			return [a316, "attack_nokab"]
		return [gw.atlas5, "fighter"]
	if Air.SPEC.has(src):
		return [gw.atlas5, String(Air.SPEC[src]["sprite"])]
	return [gw.atlas5, "fighter"]


static func _drone_sprite(gw: GameWorld, kind: int) -> Array:
	if kind == 1:
		if gw.atlas_cm28 != null and gw.atlas_cm28.has("cm"):
			return [gw.atlas_cm28, "cm"]
		return [gw.atlas5, "cruise"]
	if kind == 2 and gw.atlas12 != null and gw.atlas12.has("uav_jet"):
		return [gw.atlas12, "uav_jet"]
	return [gw.atlas2, "uav_delta"]


static func _spr(l: CanvasItem, a: SpriteAtlas, n: String, fr: int, center: Vector2, mod: Color) -> void :
	var info: Dictionary = a.info(n)
	var nf: int = maxi(1, int(info.get("frames", 1)))
	var r: Rect2 = a.rect(n, posmod(fr, nf))
	l.draw_texture_rect_region(a.texture, Rect2(center - Vector2(float(info["ax"]), float(info["ay"])), r.size), r, mod)



static func draw_falls(l: CanvasItem, gw: GameWorld, view: Rect2) -> void :
	var am: Variant = gw.aftermath
	if am == null or am.air == null or am.air.falls.is_empty():
		return
	var now: float = gw.game_time
	var vt: float = FxLayer.vt
	var sh: = Color(0, 0, 0, 0.35)
	for f: Dictionary in am.air.falls:
		var r: Array = AW.at(f, now)
		var p: Vector2 = (r[0] as Vector2).round()
		var gp: Vector2 = (r[1] as Vector2).round()
		var u: float = r[2]
		if not view.has_point(p) and not view.has_point(gp):
			continue
		var kf: int = f["k"]
		var spin: int = int(f["spin"])
		var id: int = f["id"]
		match kf:
			AW.F_PLANE, AW.F_HELI, AW.F_DIVE:
				var s: Array = _drone_sprite(gw, int(f["src"])) if kf == AW.F_DIVE else _ac_sprite(gw, int(f["src"]))
				var a: SpriteAtlas = s[0]
				var n: String = s[1]

				var rate: float = 14.0 if kf == AW.F_HELI else (6.0 + 10.0 * u if kf == AW.F_PLANE else 4.0 + 6.0 * u)
				var fr: int = int(f["fr"]) + spin * int((now - float(f["t0"])) * rate)
				if a.has(n + "_shadow"):
					_spr(l, a, n + "_shadow", fr, gp + Vector2(1, 1), sh)

				var age: float = now - float(f["t0"])
				var prev: Vector2 = p
				for i in range(1, 9):
					var tb: float = float(f["t0"]) + maxf(0.0, age - float(i) * 0.04)
					var q: Vector2 = (AW.at(f, tb)[0] as Vector2).round()
					var sc: = Color(0.18, 0.16, 0.15, 0.85 - float(i) * 0.07)
					l.draw_rect(Rect2(q, Vector2(1, 1) if i < 4 else Vector2(2, 2)), sc)
					if i == 2:
						prev = q
				var back: Vector2 = (prev - p)
				back = back.normalized() if back.length() > 0.1 else Vector2(-1, -1).normalized()
				var dark: float = 1.0 - 0.35 * u
				_spr(l, a, n, fr, p, Color(dark, dark * 0.88, dark * 0.84))

				var ph: int = int(vt * 14.0 + float(id)) % 3
				var tail: Vector2 = (p + back * (2.0 if kf == AW.F_DIVE else 3.0)).round()
				var fo: = Vector2(float(ph % 2), float((ph + 1) % 2))
				l.draw_rect(Rect2(tail - Vector2(1, 1) + fo * 0.0, Vector2(3, 3) if kf != AW.F_DIVE else Vector2(2, 2)), Palette.c("fire_orange"))
				l.draw_rect(Rect2(tail - fo * 0.0, Vector2(1, 1)), Palette.c("fire_core"))
				l.draw_rect(Rect2(tail + back.round() + fo - Vector2(1, 0), Vector2(1, 1)), Palette.c("fire_yellow"))
				if kf != AW.F_DIVE:
					l.draw_rect(Rect2(tail + back.round() * 2.0 - fo, Vector2(1, 1)), Palette.c("fire_red"))
			AW.F_WING:

				var ph2: int = int((now - float(f["t0"])) * 9.0) % 4
				var col: Color = Palette.c("ui_steel_light")
				var e: Color = Palette.c("outline")
				l.draw_rect(Rect2(gp + Vector2(1, 1), Vector2(2, 1)), sh)
				match ph2:
					0:
						l.draw_rect(Rect2(p + Vector2(-2, 0), Vector2(4, 1)), col)
						l.draw_rect(Rect2(p + Vector2(-2, 1), Vector2(4, 1)), e)
					1:
						l.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(1, 1)), col)
						l.draw_rect(Rect2(p, Vector2(1, 1)), col)
						l.draw_rect(Rect2(p + Vector2(1, 1), Vector2(1, 1)), e)
					2:
						l.draw_rect(Rect2(p + Vector2(0, -2), Vector2(1, 4)), col)
					_:
						l.draw_rect(Rect2(p + Vector2(1, -1), Vector2(1, 1)), col)
						l.draw_rect(Rect2(p, Vector2(1, 1)), col)
						l.draw_rect(Rect2(p + Vector2(-1, 1), Vector2(1, 1)), e)
			AW.F_FRAG:
				var big: bool = int(f["r"]) > 0
				l.draw_rect(Rect2(gp, Vector2(1, 1)), sh)
				l.draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3) if big else Vector2(2, 2)), Palette.c("outline"))
				l.draw_rect(Rect2(p - Vector2(0, 0), Vector2(1, 1)), Palette.c("fire_yellow") if int(vt * 10.0 + float(id)) % 2 == 0 else Palette.c("fire_orange"))
				if big:
					l.draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, 1)), Palette.c("fire_orange"))
			_:
				l.draw_rect(Rect2(p, Vector2(1, 1)), Palette.c("rock_dark") if id % 2 == 0 else Palette.c("fire_orange"))



static func draw_wreck(l: CanvasItem, gw: GameWorld, w: Dictionary, p: Vector2, cold: bool, scorch: ImageTexture) -> void :
	var wk: int = int(w["k"])
	var h: int = Hash32.h2(int(w["uid"]), 318, 7)
	var now: float = gw.game_time
	var mst: int = AD.mem_stage(w, now)
	var sm: = Color(1, 1, 1, 1.0 - 0.3 * float(mst))
	if scorch != null:
		l.draw_texture(scorch, p - (Vector2(scorch.get_size()) * 0.5).floor() + Vector2(0, 1), sm)
		if wk == AW.WK_PLANE:
			l.draw_texture(scorch, p - (Vector2(scorch.get_size()) * 0.5).floor() + Vector2(4 - (h % 9), 2), sm)
	var k: = Color(0.16, 0.14, 0.13)
	var rust: Color = Palette.c("brick_dark")
	var steel: Color = Palette.c("rock")
	if wk == AW.WK_DEBRIS:

		var flip: bool = h % 2 == 0
		var dv: = Vector2(1, 0) if flip else Vector2(1, 1)
		for i in 7:
			var q: Vector2 = (p + dv * float(i - 3)).round()
			l.draw_rect(Rect2(q + Vector2(0, 1), Vector2(1, 1)), Palette.c("outline"))
			l.draw_rect(Rect2(q, Vector2(1, 1)), k if i < 6 else steel)
		l.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(1, 1)), rust)
		for b in 4:
			l.draw_rect(Rect2(p + Vector2(float((h >> (b * 3)) % 13) - 6.0, float((h >> (b * 2 + 5)) % 7) - 3.0), Vector2(1, 1)), steel if b % 2 == 0 else k)
	else:
		var s: Array = _drone_sprite(gw, int(w.get("src", 0))) if wk == AW.WK_DRONE else _ac_sprite(gw, int(w.get("src", 0)))
		var a: SpriteAtlas = s[0]
		var n: String = s[1]
		var fr: int = int(w["frame"])
		var bt: ImageTexture = AD._burnt(a, n) if a != null else null
		if mst > 0 and bt != null:
			bt = AD.mossy(bt, "%d:%s" % [a.get_instance_id(), n], mst)
		var info: Dictionary = a.info(n)
		var nf: int = maxi(1, int(info.get("frames", 1)))
		var r: Rect2 = a.rect(n, posmod(fr, nf))
		var r0: Rect2 = a.rect(n, 0)
		var tl: Vector2 = p - Vector2(float(info["ax"]), float(info["ay"]))
		if bt != null:
			if wk == AW.WK_PLANE and r.size.x >= 8:

				var hx: float = floorf(r.size.x * 0.5)
				l.draw_texture_rect_region(bt, Rect2(tl, Vector2(hx, r.size.y)), Rect2(r.position - r0.position, Vector2(hx, r.size.y)))
				var sh: Vector2 = Vector2(1, 2) if h % 2 == 0 else Vector2(1, -2)
				l.draw_texture_rect_region(bt, Rect2(tl + Vector2(hx, 0) + sh, Vector2(r.size.x - hx, r.size.y)), Rect2(r.position - r0.position + Vector2(hx, 0), Vector2(r.size.x - hx, r.size.y)))
			else:
				l.draw_texture_rect_region(bt, Rect2(tl, r.size), Rect2(r.position - r0.position, r.size))
		else:
			_spr(l, a, n, fr, p, Color(0.2, 0.16, 0.14))

		var wp: Vector2 = p + Vector2(float(h % 13) - 6.0, 4.0 + float((h >> 4) % 3))
		l.draw_rect(Rect2(wp, Vector2(3, 1)), steel)
		l.draw_rect(Rect2(wp + Vector2(0, 1), Vector2(3, 1)), Palette.c("outline"))
		l.draw_rect(Rect2(p + Vector2(6.0 + float((h >> 6) % 3), float((h >> 8) % 7) - 3.0), Vector2(1, 1)), rust)
		l.draw_rect(Rect2(p + Vector2(-7.0 - float((h >> 9) % 2), float((h >> 11) % 5) - 2.0), Vector2(1, 1)), steel)
	if mst > 0:
		AD.tufts(l, p, h, mst)

	var em: float = float(w.get("em", -1.0))
	var hot: bool = not cold and (em < 0.0 or now - em < 6.0)
	if hot:
		var ph: int = int(FxLayer.vt * 6.0 + float(h % 5)) % 3
		l.draw_rect(Rect2(p + Vector2(float(ph) - 1.0, -1), Vector2(1, 1)), Palette.c("fire_yellow"))
		l.draw_rect(Rect2(p + Vector2(1.0 - float(ph), 0), Vector2(1, 1)), Palette.c("fire_orange"))
	if em >= 0.0 and now - em < AM.EMERG_T:
		_emerg(l, gw, w, p, now - em, h)



static func _emerg(l: CanvasItem, gw: GameWorld, w: Dictionary, p: Vector2, t: float, h: int) -> void :
	var la: SpriteAtlas = gw.life_atlas
	if la == null or not la.has("fire_truck_e") or not la.has("ambulance_e"):
		return
	var side: float = 1.0 if h % 2 == 0 else -1.0
	var k: float = 1.0
	if t < 3.0:
		k = t / 3.0
	elif t > AM.EMERG_T - 3.0:
		k = (AM.EMERG_T - t) / 3.0
	var roll: float = (1.0 - k) * 24.0
	var tp: Vector2 = (p + Vector2(side * (9.0 + roll), 3.0)).round()
	var ap: Vector2 = (p + Vector2(side * (9.0 + roll), -5.0)).round()
	var flip: bool = side > 0.0
	if t > AM.EMERG_T - 3.0:
		flip = not flip
	for e: Array in [["fire_truck_e", tp], ["ambulance_e", ap]]:
		var nm: String = e[0]
		var q: Vector2 = e[1]
		var info: Dictionary = la.info(nm)
		var r: Rect2 = la.rect(nm, 0)
		var tl: Vector2 = q - Vector2(float(info["ax"]), float(info["ay"]))
		var dst: = Rect2(tl, r.size)
		if flip:
			dst = Rect2(tl + Vector2(r.size.x, 0), Vector2( - r.size.x, r.size.y))
		l.draw_texture_rect_region(la.texture, Rect2(dst.position + Vector2(1, 1), dst.size), r, Color(0, 0, 0, 0.35))
		l.draw_texture_rect_region(la.texture, dst, r)
		var on: bool = int(FxLayer.vt * 4.0 + (0.5 if nm == "ambulance_e" else 0.0)) % 2 == 0
		l.draw_rect(Rect2(q + Vector2(0, - float(info["ay"]) - 1.0), Vector2(1, 1)), Palette.c("water_coast") if on else Palette.c("fire_orange") if nm == "fire_truck_e" else Palette.c("snow"))
	if t > 1.0 and t < 8.0:

		var from: Vector2 = tp + Vector2( - side * 3.0, -2.0)
		var n: int = 7
		for i in n:
			var u: float = fmod(float(i) / float(n) + FxLayer.vt * 1.5, 1.0)
			var q2: Vector2 = from.lerp(p + Vector2(0, -1), u) + Vector2(0, - sin(u * PI) * 4.0)
			l.draw_rect(Rect2(q2.round(), Vector2(1, 1)), Palette.c("water_foam"))




const SINK_T: float = 3.5
const BUBBLE_T: float = 8.0
const OIL_T: float = 24.0
const MAX_SINKS: int = 24

static var sinks: Array = []
static var _slick: Array = []





static func _build_slicks() -> void :
	var core: = Palette.c("outline")
	var sheen: Array = [Palette.c("ui_steel_mid"), Palette.c("amber_dark"), Palette.c("roof_green"), Palette.c("rock_deep"), Palette.c("water_deep")]
	for rx: float in [3.0, 5.0, 7.0, 10.0]:
		for v in 2:
			var ry: float = maxf(2.0, rx * 0.55)
			var w: int = int(rx * 2.0) + 5
			var hgt: int = int(ry * 2.0) + 5
			var img: = Image.create(w, hgt, false, Image.FORMAT_RGBA8)
			img.fill(Color(0, 0, 0, 0))
			var cx: float = float(w) * 0.5 - 0.5
			var cy: float = float(hgt) * 0.5 - 0.5
			for y in hgt:
				for x in w:
					var dx: float = (float(x) - cx) / rx
					var dy: float = (float(y) - cy) / ry
					var ang: float = atan2(dy, dx)
					var wob: float = 1.0 + 0.18 * sin(ang * 3.0 + float(v) * 2.1) + 0.1 * sin(ang * 5.0 + 1.3 + float(v))
					var d: float = sqrt(dx * dx + dy * dy) / wob
					var hh: int = Hash32.h2(x + v * 50, y + int(rx) * 7, 3204)
					if d < 0.78:
						if hh % 5 != 0:
							img.set_pixel(x, y, Color(core, 0.42 if d < 0.5 else 0.32))
					elif d < 1.0:
						var run: int = Hash32.h2(int((ang + PI) * 3.0), v + int(rx), 3205)
						if run % 5 != 0:
							img.set_pixel(x, y, Color(sheen[run % sheen.size()], 0.85))
			_slick.append(ImageTexture.create_from_image(img))


static func add_sink(gw: GameWorld, p: Vector2, wk: int, src: int, fr: int) -> void :
	if sinks.size() >= MAX_SINKS:
		sinks.pop_front()
	sinks.append({"p": p.round(), "t0": gw.game_time, "wk": wk, "src": src, "fr": fr, "h": Hash32.h2(int(p.x), int(p.y), 3206) & 65535})



static func _sink_sprite(gw: GameWorld, s: Dictionary) -> Array:
	var wk: int = s["wk"]
	if wk <= 0:
		if int(s["src"]) < 0 or int(s["src"]) >= Army.SPEC.size():
			return [null, ""]
		var ws: Array = AD._wreck_sprite(gw, int(s["src"]), -1)
		return [ws[0], ws[1]]
	if wk == AW.WK_DRONE:
		return _drone_sprite(gw, int(s["src"]))
	if wk == AW.WK_PLANE or wk == AW.WK_HELI:
		return _ac_sprite(gw, int(s["src"]))
	return [null, ""]




static func draw_sinks(l: CanvasItem, gw: GameWorld, view: Rect2) -> void :
	if sinks.is_empty():
		return
	var now: float = gw.game_time
	var foam: = Palette.c("water_foam")
	for k in range(sinks.size() - 1, -1, -1):
		var s: Dictionary = sinks[k]
		var age: float = now - float(s["t0"])
		if age > OIL_T or age < 0.0:
			sinks.remove_at(k)
			continue
		var p: Vector2 = s["p"]
		if not view.has_point(p):
			continue
		var h: int = s["h"]


		var u: float = clampf(age / OIL_T, 0.0, 1.0)
		var oa: float = 1.0 - u * u
		if _slick.is_empty():
			_build_slicks()
		var si: int = mini(3, int(sqrt(u) * 4.0))
		var st: ImageTexture = _slick[si * 2 + h % 2]
		l.draw_texture(st, (p - (Vector2(st.get_size()) * 0.5).floor()).round(), Color(1, 1, 1, oa))

		if age < SINK_T:
			var sp: Array = _sink_sprite(gw, s)
			var a: SpriteAtlas = sp[0]
			var n: String = sp[1]
			var v: float = age / SINK_T
			if a != null and a.has(n):
				var info: Dictionary = a.info(n)
				var nf: int = maxi(1, int(info.get("frames", 1)))
				var r: Rect2 = a.rect(n, posmod(int(s["fr"]), nf))
				var r0: Rect2 = a.rect(n, 0)
				var bt: ImageTexture = AD._burnt(a, n)
				var tl: Vector2 = (p - Vector2(float(info["ax"]), float(info["ay"]))).round()
				var sunk: float = floorf(r.size.y * v)
				var vis: float = r.size.y - sunk
				if vis >= 1.0:
					var tint: = Color(0.8, 0.88, 1.0)
					if bt != null:
						l.draw_texture_rect_region(bt, Rect2(tl + Vector2(0, sunk), Vector2(r.size.x, vis)), Rect2(r.position - r0.position, Vector2(r.size.x, vis)), tint)
					else:
						l.draw_texture_rect_region(a.texture, Rect2(tl + Vector2(0, sunk), Vector2(r.size.x, vis)), Rect2(r.position, Vector2(r.size.x, vis)), tint)

					var wl: float = tl.y + r.size.y
					for x in int(r.size.x) + 2:
						if (x + int(FxLayer.vt * 8.0)) % 3 != 0:
							l.draw_rect(Rect2(Vector2(tl.x - 1.0 + float(x), wl), Vector2(1, 1)), foam)
			else:

				if v < 0.7:
					l.draw_rect(Rect2(p + Vector2(-1, -1.0 + floorf(v * 3.0)), Vector2(3, 2.0 - floorf(v * 2.0))), Palette.c("outline"))
				l.draw_rect(Rect2(p + Vector2(-2, 1), Vector2(5, 1)), foam)

		if age < BUBBLE_T:
			var nb: int = 4 if age < BUBBLE_T * 0.5 else 2
			for b in nb:
				var hb: int = Hash32.h2(h, b, 3196)
				var ph: float = fmod(age * (1.4 + float(hb % 5) * 0.2) + float(hb % 97) / 97.0, 1.0)
				var bq: Vector2 = p + Vector2(float(hb % 9) - 4.0, 1.0 - ph * 5.0)
				if ph < 0.85:
					l.draw_rect(Rect2(bq.round(), Vector2(1, 1)), foam)
				else:
					l.draw_rect(Rect2(bq.round() + Vector2(-1, 0), Vector2(1, 1)), foam)
					l.draw_rect(Rect2(bq.round() + Vector2(1, 0), Vector2(1, 1)), foam)
