extends RefCounted












const AM = preload("res://game/aftermath.gd")
const AWD = preload("res://world/air_wreck_draw.gd")
const CD = preload("res://world/cover_draw.gd")

static var _tex: Dictionary = {}


static var turret_blown: Callable = Callable()







static func _wreck_sprite(gw: GameWorld, type: int, uid: int, cid: int = -1) -> Array:
	var sn: String = String(Army.SPEC[type]["sprite"])
	var a314: SpriteAtlas = UnitsLayer.atlas314()
	if a314 != null:
		var k1: String = ""
		var kt: String = ""
		if type == Unit.Type.TANK or type == Unit.Type.IFV:
			var sch: String = VfxTurret.school(gw.country_by_id(cid))
			var base: String = ("tank_" if type == Unit.Type.TANK else "ifv_") + sch + "_L"
			k1 = base + "_wreck"
			var blown: bool = bool(turret_blown.call(uid, type)) if turret_blown.is_valid() else VfxTurret.blown(uid, type)
			if not blown and a314.has(base + "_turret_burnt"):
				kt = base + "_turret_burnt"
		elif type == Unit.Type.ARTY or type == Unit.Type.MLRS:
			k1 = sn + "_wreck"
		if k1 != "" and a314.has(k1):
			return [a314, k1, true, kt]
	var wn: String = "wreck_" + sn
	if gw.fx.atlas_of.has(wn):
		return [gw.fx.atlas_of[wn], wn, true, ""]
	for a: SpriteAtlas in [gw.atlas10, gw.atlas7]:
		if a != null and a.has(wn):
			return [a, wn, true, ""]
	if gw.atlas10 != null and gw.atlas10.has(sn):
		return [gw.atlas10, sn, false, ""]
	return [gw.atlas7, "tank", false, ""]



static var cost_us: int = 0


static func draw(l: CanvasItem, gw: GameWorld, view: Rect2, z: float) -> void :
	var us0: int = Time.get_ticks_usec()
	_draw_all(l, gw, view, z)
	cost_us = Time.get_ticks_usec() - us0


static func _draw_all(l: CanvasItem, gw: GameWorld, view: Rect2, z: float) -> void :
	var am: Variant = gw.aftermath
	if am == null:
		return
	var vt: float = FxLayer.vt
	var a314: SpriteAtlas = UnitsLayer.atlas314()
	if _scorch.is_empty():
		_build_scorch()
	_spread(gw, am.wrecks)
	var now: float = gw.game_time
	for w: Dictionary in am.wrecks:
		var p: Vector2 = _dpos.get(int(w["uid"]), (w["p"] as Vector2).round())
		if not view.has_point(p) or (gw.vision != null and not gw.vision.sees(p)):
			continue
		var cold: bool = now - float(w["t0"]) > COLD_T
		var h: int = Hash32.h2(int(w["uid"]), 7, 31)
		if int(w.get("k", 0)) > 0:
			AWD.draw_wreck(l, gw, w, p, cold, _scorch[h % _scorch.size()])
			continue
		var mst: int = mem_stage(w, now)
		var sa: float = 1.0 - 0.3 * float(mst)

		if a314 != null and a314.has("wreck_scorch"):
			_spr(l, a314, "wreck_scorch", h % maxi(1, int(a314.info("wreck_scorch").get("frames", 1))), p, Color(1, 1, 1, sa))
		else:
			var st: ImageTexture = _scorch[h % _scorch.size()]
			l.draw_texture(st, p - (Vector2(st.get_size()) * 0.5).floor() + Vector2(0, 1), Color(1, 1, 1, sa))
		var ws: Array = _wreck_sprite(gw, int(w["type"]), int(w["uid"]), int(w.get("c", -1)))
		var a: SpriteAtlas = ws[0]
		var n: String = ws[1]
		var info: Dictionary = a.info(n)
		var fr: int = int(w["frame"]) % maxi(1, int(info.get("frames", 1)))
		if bool(ws[2]):
			if a.has(n + "_shadow"):
				_spr(l, a, n + "_shadow", fr, p + Vector2(1, 1), Color.WHITE)
			var mt: ImageTexture = mossy(_cold(a, n), "%d:%s" % [a.get_instance_id(), n], mst) if mst > 0 else null
			if mt != null:
				var r1: Rect2 = a.rect(n, fr)
				l.draw_texture_rect_region(mt, Rect2(p - Vector2(float(info["ax"]), float(info["ay"])), r1.size), Rect2(r1.position - a.rect(n, 0).position, r1.size))
			else:
				_spr_c(l, a, n, fr, p, cold)
			var kt: String = ws[3]
			if kt != "":

				var ring: Array = a.info(kt.replace("_turret_burnt", "_turret")).get("ring", [])
				var ro: Vector2 = Vector2(ring[fr][0], ring[fr][1]) if fr < ring.size() else Vector2.ZERO
				_spr_c(l, a, kt, fr, p + ro, cold)
		else:

			var bt: ImageTexture = _burnt(a, n)
			if mst > 0:
				bt = mossy(bt, "%d:%s" % [a.get_instance_id(), n], mst)
			var r: Rect2 = a.rect(n, fr)
			var r0: Rect2 = a.rect(n, 0)
			var dst: = Rect2(p - Vector2(float(info["ax"]), float(info["ay"])), r.size)
			if a.has(n + "_shadow"):
				_spr(l, a, n + "_shadow", fr, p + Vector2(1, 1), Color(0, 0, 0, 0.45))
			if bt != null:
				l.draw_texture_rect_region(bt, dst, Rect2(r.position - r0.position, r.size))
			else:
				_spr(l, a, n, fr, p, Color(0.2, 0.16, 0.14))

			l.draw_rect(Rect2(p + Vector2(float(h % 11) - 5.0, 4.0 + float((h >> 4) % 2)), Vector2(2, 1)), Palette.c("rock_dark"))
			l.draw_rect(Rect2(p + Vector2(6.0 + float((h >> 6) % 2), float((h >> 8) % 7) - 3.0), Vector2(1, 1)), Palette.c("brick_dark"))
			l.draw_rect(Rect2(p + Vector2(-7.0 - float((h >> 9) % 2), float((h >> 11) % 5) - 2.0), Vector2(1, 1)), Palette.c("rock"))
		if mst > 0:
			tufts(l, p, h, mst)
	AWD.draw_sinks(l, gw, view)

	if _tex.is_empty():
		_build()
	for t: Dictionary in am.trucks:
		var tp: Vector2 = (t["pos"] as Vector2).round()
		if not view.has_point(tp) or (gw.vision != null and not gw.vision.sees(tp)):
			continue
		var d: Vector2 = t["dir"]
		var key: String
		var flip: bool = false
		if absf(d.x) >= absf(d.y):
			key = "e"
			flip = d.x < 0.0
		else:
			key = "s" if d.y > 0.0 else "n"
		var loaded: bool = int(t["st"]) == 2
		if a314 != null and a314.has("tow_truck_" + key):

			var tn: String = "tow_truck_" + key
			var ti: Dictionary = a314.info(tn)
			var trr: Rect2 = a314.rect(tn, mini(1 if loaded else 0, int(ti.get("frames", 1)) - 1))
			var ttl: Vector2 = tp - Vector2(float(ti["ax"]), float(ti["ay"]))
			var tdst: = Rect2(ttl, trr.size)
			if flip:
				tdst = Rect2(ttl + Vector2(trr.size.x, 0), Vector2( - trr.size.x, trr.size.y))
			CD.begin(gw, int(ttl.x) - 1, int(trr.size.x) + 3, int(ttl.y + trr.size.y) - 1)
			CD.blit(l, a314.texture, tdst, trr)
			var on2: bool = int(floorf(vt * 4.0 + float(int(t["id"]) % 4) * 0.25)) % 2 == 0
			for b2 in 2:
				CD.rect(l, Rect2(ttl + Vector2(floorf(trr.size.x * 0.5) - 1.0 + float(b2), -1), Vector2.ONE), Palette.c("amber") if on2 == (b2 == 0) else Palette.c("amber_dark"))
			CD.end()
			continue
		if a314 != null and a314.has("truck_tan"):
			var fi: Dictionary = a314.info("truck_tan")
			CD.begin(gw, int(tp.x) - 9, 19, int(tp.y - float(fi["ay"]) + a314.rect("truck_tan", 0).size.y) - 1)
			_tow314(l, a314, t, tp, d, loaded, vt, z)
			CD.end()
			continue
		var e: Array = _tex[key + ("1" if loaded else "0")]
		var tex: ImageTexture = e[0]
		var sz: Vector2 = Vector2(tex.get_size())
		var tl: Vector2 = tp - (sz * 0.5).floor()
		var dst: = Rect2(tl, sz)
		if flip:
			dst = Rect2(tl + Vector2(sz.x, 0), Vector2( - sz.x, sz.y))
		var shadow: = Color(0, 0, 0, 0.35)
		CD.begin(gw, int(tl.x) - 1, int(sz.x) + 3, int(tl.y + sz.y) - 1)
		CD.blit_tex(l, tex, Rect2(dst.position + Vector2(1, 1), dst.size), shadow)
		CD.blit_tex(l, tex, dst)

		var on: bool = int(floorf(vt * 4.0 + float(int(t["id"]) % 4) * 0.25)) % 2 == 0
		for b in 2:
			var bp: Vector2 = e[1 + b]
			if flip:
				bp.x = sz.x - 1.0 - bp.x
			var lit: bool = on == (b == 0)
			CD.rect(l, Rect2(tl + bp, Vector2.ONE), Palette.c("amber") if lit else Palette.c("amber_dark"))
			if lit and z >= 1.0:
				var g: = Palette.c("window_light")
				g.a = 0.35
				CD.rect(l, Rect2(tl + bp - Vector2(1, 1), Vector2(3, 3)), g)
		if int(t["st"]) == 1:

			var wp: Vector2 = tp + Vector2( - d.x, - d.y) * 5.0
			CD.rect(l, Rect2(wp.round(), Vector2.ONE), Palette.c("rock_light"))
			if fmod(vt * 2.0 + float(int(t["id"])) * 0.37, 1.0) < 0.15:
				CD.rect(l, Rect2((wp + Vector2(1, -1)).round(), Vector2.ONE), Palette.c("fire_core"))
		CD.end()
	_rebuilds(l, gw, view, z)





static func _tow314(l: CanvasItem, a: SpriteAtlas, t: Dictionary, tp: Vector2, d: Vector2, loaded: bool, vt: float, z: float) -> void :
	var fr: int = posmod(roundi(rad_to_deg(d.angle()) / 22.5), 16)
	if a.has("truck_tan_shadow"):
		_spr_cd(l, a, "truck_tan_shadow", fr, tp + Vector2(1, 1), Color(0, 0, 0, 0.45))
	_spr_cd(l, a, "truck_tan", fr, tp, Color.WHITE)
	var back: Vector2 = (tp - d * 3.0).round()
	if loaded:

		var k: = Color(0.16, 0.14, 0.13)
		CD.rect(l, Rect2(back + Vector2(-2, -3), Vector2(5, 3)), Palette.c("outline"))
		CD.rect(l, Rect2(back + Vector2(-2, -3), Vector2(5, 2)), k)
		CD.rect(l, Rect2(back + Vector2(-1, -3), Vector2(2, 1)), Palette.c("brick_dark"))
		CD.rect(l, Rect2(back + Vector2(2, -3), Vector2(1, 1)), Palette.c("rock"))
	else:

		var tail: Vector2 = (tp - d * 5.0).round()
		CD.rect(l, Rect2(tail + Vector2(0, -4), Vector2(1, 3)), Palette.c("fire_red"))
		CD.rect(l, Rect2(back + Vector2(0, -4), Vector2(1, 1)), Palette.c("fire_red"))
		CD.rect(l, Rect2(tail + Vector2(0, -1), Vector2(1, 1)), Palette.c("concrete_light"))
	var cab: Vector2 = (tp + d * 3.0).round() + Vector2(0, -4)
	var on: bool = int(floorf(vt * 4.0 + float(int(t["id"]) % 4) * 0.25)) % 2 == 0
	for b in 2:
		var bp: Vector2 = cab + Vector2(float(b) - 1.0 if b == 0 else 1.0, 0)
		var lit: bool = on == (b == 0)
		if lit and z >= 1.0:
			var g: = Palette.c("window_light")
			g.a = 0.4
			CD.rect(l, Rect2(bp - Vector2(1, 1), Vector2(3, 3)), g)
		CD.rect(l, Rect2(bp, Vector2.ONE), Palette.c("amber") if lit else Palette.c("amber_dark"))
	if int(t["st"]) == 1:
		var wp: Vector2 = (tp - d * 6.0).round()
		CD.rect(l, Rect2(wp, Vector2.ONE), Palette.c("rock_light"))
		if fmod(vt * 2.0 + float(int(t["id"])) * 0.37, 1.0) < 0.15:
			CD.rect(l, Rect2(wp + Vector2(1, -1), Vector2.ONE), Palette.c("fire_core"))



static func draw_night(l: CanvasItem, gw: GameWorld, view: Rect2, k: float) -> void :
	var am: Variant = gw.aftermath
	if am == null or am.trucks.is_empty() or k <= 0.02:
		return
	var vt: float = FxLayer.vt
	for t: Dictionary in am.trucks:
		var tp: Vector2 = (t["pos"] as Vector2).round()
		if not view.has_point(tp) or (gw.vision != null and not gw.vision.sees(tp)):
			continue
		var on: bool = int(floorf(vt * 4.0 + float(int(t["id"]) % 4) * 0.25)) % 2 == 0
		var g: = Palette.c("amber")
		g.a = 0.5 * clampf(k, 0.0, 1.0)
		var bp: Vector2 = tp + Vector2(1.0 if on else -1.0, -3.0)
		l.draw_rect(Rect2(bp - Vector2(1, 1), Vector2(3, 3)), g)
		g.a *= 0.4
		l.draw_rect(Rect2(bp - Vector2(3, 3), Vector2(7, 7)), g)



static func _rebuilds(l: CanvasItem, gw: GameWorld, view: Rect2, z: float) -> void :
	var ca: SpriteAtlas = gw.atlas_crane
	var net: = Palette.c("grass_dark")
	net.a = 0.75
	var net2: = Palette.c("forest")
	net2.a = 0.55
	for e: Array in gw.ruins:
		if e.size() < 4 or float(e[2]) < 0.0:
			continue
		var id: int = e[0]
		if id < 0 or id >= gw.obj_spr.size() or gw.obj_hidden[id] != 0:
			continue
		var o: Vector2 = gw.obj_origin(id)
		var sz: Vector2 = gw.spr_rect[gw.obj_spr[id]].size
		if not view.intersects(Rect2(o, sz)):
			continue

		var top: float = o.y + roundf(sz.y * 0.3)
		var hh: float = o.y + sz.y - 1.0 - top
		l.draw_rect(Rect2(o.x + 1, top, 1, hh), net)
		l.draw_rect(Rect2(o.x + sz.x - 2, top, 1, hh), net)
		var yy: float = top
		while yy < o.y + sz.y - 1.0:
			l.draw_rect(Rect2(o.x + 1, yy, sz.x - 2, 1), net)
			yy += 3.0
		var xx: float = o.x + 3.0
		while xx < o.x + sz.x - 2.0:
			l.draw_rect(Rect2(xx, top, 1, hh), net2)
			xx += 3.0
		if ca != null and ca.has("crane_s"):
			var big: float = maxf(sz.x, sz.y)
			var n: String = "crane_s" if big < 24.0 else ("crane_m" if big < 40.0 else "crane_l")
			var info: Dictionary = ca.info(n)
			var fr: int = (int(FxLayer.vt * float(info["fps"])) + id * 7) % int(info["frames"])
			_spr(l, ca, n, fr, o + Vector2(clampf(roundf(sz.x * 0.18), 3.0, 10.0), sz.y - 2.0), Color.WHITE)
		if z >= 1.2:
			var rr: Rect2i = gw.object_rect(id)
			var tot: float = 90.0 if rr.size.x * rr.size.y > 16 else 60.0
			var frac: float = 1.0 - clampf(float(e[2]) / tot, 0.0, 1.0)
			var bw: int = clampi(int(sz.x * 0.6), 10, 16)
			var x0: int = int(o.x) + (int(sz.x) - bw) / 2
			var y0: int = int(o.y) - 5
			l.draw_rect(Rect2(x0, y0, bw, 3), Palette.c("ui_rubber"))
			l.draw_rect(Rect2(x0 + 1, y0 + 1, bw - 2, 1), Palette.c("ui_steel_dark"))
			var fill: int = int(floorf(frac * float(bw - 2)))
			if fill > 0:
				l.draw_rect(Rect2(x0 + 1, y0 + 1, fill, 1), Palette.c("grass_light"))


const COLD_T: float = 40.0
const SPREAD_R: float = 6.0
static var _dpos: Dictionary = {}
static var _dsig: int = -1
static var _cold_c: Dictionary = {}




static func draw_pos(gw: GameWorld, w: Dictionary) -> Vector2:
	if gw.aftermath != null:
		_spread(gw, gw.aftermath.wrecks)
	return _dpos.get(int(w["uid"]), (w["p"] as Vector2).round())





static func _spread(gw: GameWorld, wrecks: Array) -> void :
	var sig: int = wrecks.size()
	for w: Dictionary in wrecks:
		sig = (sig * 31 + int(w["uid"])) & 2147483647
	if sig == _dsig:
		return
	_dsig = sig
	_dpos.clear()
	var grid: Dictionary = {}
	var am: Variant = gw.aftermath
	for w: Dictionary in wrecks:
		var p: Vector2 = (w["p"] as Vector2).round()
		var h: int = Hash32.h2(int(w["uid"]), 11, 5)
		if _near(grid, p):
			var found: bool = false
			for rad: float in [6.0, 8.0, 10.0]:
				for k in 8:
					var ang: float = float((k + h) % 8) * PI * 0.25
					var q: Vector2 = (p + Vector2.from_angle(ang) * rad).round()
					var qc: = Vector2i(floori(q.x / GameWorld.CELL), floori(q.y / GameWorld.CELL))
					if not _near(grid, q) and (am == null or am._free(qc)):
						p = q
						found = true
						break
				if found:
					break
		_dpos[int(w["uid"])] = p
		var b: = Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
		if not grid.has(b):
			grid[b] = []
		(grid[b] as Array).append(p)


static func _near(grid: Dictionary, p: Vector2) -> bool:
	var b: = Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for q: Vector2 in grid.get(b + Vector2i(dx, dy), []):
				if q.distance_to(p) < SPREAD_R:
					return true
	return false



static func _spr_c(l: CanvasItem, a: SpriteAtlas, n: String, fr: int, center: Vector2, cold: bool) -> void :
	if not cold:
		_spr(l, a, n, fr, center, Color.WHITE)
		return
	var tex: ImageTexture = _cold(a, n)
	if tex == null:
		_spr(l, a, n, fr, center, Color.WHITE)
		return
	var info: Dictionary = a.info(n)
	var r: Rect2 = a.rect(n, fr)
	var r0: Rect2 = a.rect(n, 0)
	l.draw_texture_rect_region(tex, Rect2(center - Vector2(float(info["ax"]), float(info["ay"])), r.size), Rect2(r.position - r0.position, r.size))


static func _cold(a: SpriteAtlas, n: String) -> ImageTexture:
	var key: String = "%d:%s" % [a.get_instance_id(), n]
	if _cold_c.has(key):
		return _cold_c[key]
	var tex: ImageTexture = null
	var img: Image = a.texture.get_image() if a.texture != null else null
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var r0: Rect2 = a.rect(n, 0)
		var nf: int = maxi(1, int(a.info(n).get("frames", 1)))
		var full: = Rect2i(Vector2i(r0.position), Vector2i(int(r0.size.x) * nf, int(r0.size.y))).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var sub: Image = img.get_region(full)
		sub.convert(Image.FORMAT_RGBA8)
		var c_hot: = Palette.c("brick_dark")
		var c_dim: = Palette.c("earth_dark")
		var hot: Dictionary = {}
		for nm: String in ["fire_red", "fire_orange", "amber_dark"]:
			hot[Palette.c(nm).to_html(false)] = 0
		for nm2: String in ["fire_core", "fire_yellow", "amber", "window_light", "fire_ember"]:
			hot[Palette.c(nm2).to_html(false)] = 1
		for y in sub.get_height():
			for x in sub.get_width():
				var c: Color = sub.get_pixel(x, y)
				if c.a < 0.5:
					continue
				var hx: String = c.to_html(false)
				if hot.has(hx):
					var o: Color = c_hot if int(hot[hx]) == 0 else c_dim
					sub.set_pixel(x, y, Color(o.r, o.g, o.b, c.a))
		tex = ImageTexture.create_from_image(sub)
	_cold_c[key] = tex
	return tex




const MEM_T: Array = [60.0, 180.0, 330.0]
static var _moss_c: Dictionary = {}



static func mem_stage(w: Dictionary, now: float) -> int:
	if not w.has("m") and not w.has("q"):
		return 0
	var since: float = float(w["m"] if w.has("m") else w["q"])
	var age: float = now - since
	var st: int = 0
	for t: float in MEM_T:
		if age >= t:
			st += 1
	return st




static func mossy(base: ImageTexture, key: String, st: int) -> ImageTexture:
	if base == null:
		return null
	var k: String = "%s:%d" % [key, st]
	if _moss_c.has(k):
		return _moss_c[k]
	var img: Image = base.get_image()
	if img == null or img.is_empty():
		_moss_c[k] = base
		return base
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var src: Image = img.duplicate()
	var w: int = img.get_width()
	var hgt: int = img.get_height()
	var moss: Array = [Palette.c("grass_deep"), Palette.c("grass_dark"), Palette.c("forest"), Palette.c("grass_dark")]
	var rusts: Array = [Palette.c("brick_dark"), Palette.c("earth"), Palette.c("brick"), Palette.c("earth_dark")]

	var c_top: = PackedInt32Array()
	var c_bot: = PackedInt32Array()
	c_top.resize(w)
	c_bot.resize(w)
	for x0 in w:
		c_top[x0] = -1
		c_bot[x0] = -1
		for y0 in hgt:
			if src.get_pixel(x0, y0).a >= 0.5:
				if c_top[x0] < 0:
					c_top[x0] = y0
				c_bot[x0] = y0

	var p_low: int = [0, 22, 40, 58][st]
	var p_mid: int = [0, 4, 12, 22][st]
	var p_top: int = [0, 8, 14, 20][st]
	var p_rust: int = [0, 30, 55, 75][st]
	for y in hgt:
		for x in w:
			var c: Color = src.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var span: float = float(maxi(1, c_bot[x] - c_top[x] + 1))
			var v: float = float(y - c_top[x]) / span
			var hh: int = Hash32.h2(x, y, 3193)
			var hc: int = Hash32.h2(x / 2, y / 2, 3199)
			var top: bool = y == 0 or src.get_pixel(x, y - 1).a < 0.5
			var lum: float = c.r * 0.3 + c.g * 0.55 + c.b * 0.15
			var side: bool = x == 0 or x == w - 1 or src.get_pixel(x - 1, y).a < 0.5 or src.get_pixel(x + 1, y).a < 0.5
			var chance: int = p_low if v > 0.67 else (p_top if top else (p_mid if side else 0))
			var roll: int = hh % 100 if v > 0.67 else hc % 100
			if roll < chance and lum > 0.06:
				var m: Color = moss[(hh >> 7) % moss.size()]
				if top and st >= 2 and (hh >> 3) % 4 == 0:
					m = Palette.c("grass")
				img.set_pixel(x, y, m)
			elif lum > 0.12 and (hh >> 9) % 100 < p_rust:
				img.set_pixel(x, y, rusts[(hh >> 4) % (2 if lum < 0.35 else 4)])
	if st >= 3:

		var placed: int = 0
		for x2 in range(3, w - 1, 13):
			for y2 in hgt:
				if src.get_pixel(x2, y2).a >= 0.5:
					if y2 > 0 and (Hash32.h2(x2, 0, 3194) % 3) != 0:
						img.set_pixel(x2, y2 - 1, Palette.c("fire_yellow") if placed % 2 == 0 else Palette.c("snow"))
						placed += 1
					break
	var t: = ImageTexture.create_from_image(img)
	_moss_c[k] = t
	return t




static func tufts(l: CanvasItem, p: Vector2, h: int, st: int) -> void :
	var g_l: = Palette.c("grass_light")
	var g: = Palette.c("grass")
	var g_d: = Palette.c("grass_dark")
	var n: int = 3 + st * 3
	for i in n:
		var hi: int = Hash32.h2(h, i, 3195)
		var q: Vector2 = p + Vector2(float(hi % 19) - 9.0, float((hi >> 5) % 7) - 1.0)
		l.draw_rect(Rect2(q, Vector2(1, 1)), g_d)
		l.draw_rect(Rect2(q + Vector2(0, -1), Vector2(1, 1)), g)
		if (hi >> 11) % 3 == 0:
			l.draw_rect(Rect2(q + Vector2(1, 0), Vector2(1, 1)), g)
	if st >= 2:

		for x in range(-7, 8):
			var hb: int = Hash32.h2(h, x + 40, 3200)
			if hb % (3 if st == 2 else 2) != 0:
				continue
			var tall: int = 1 + hb % 2
			var base: Vector2 = p + Vector2(float(x), 3.0 + float((hb >> 4) % 2))
			l.draw_rect(Rect2(base, Vector2(1, 1)), g_d)
			for k in tall:
				l.draw_rect(Rect2(base + Vector2(0, -1 - k), Vector2(1, 1)), g_d if k < tall - 1 else g)

		var side: float = 1.0 if (h >> 3) % 2 == 0 else -1.0
		var bp: Vector2 = p + Vector2(side * 8.0, 2.0)
		var th: int = 3 if st == 2 else 5
		l.draw_rect(Rect2(bp + Vector2(1, 1), Vector2(1, 1)), Color(0, 0, 0, 0.3))
		l.draw_rect(Rect2(bp + Vector2(0, - float(th) + 1.0), Vector2(1, th)), Palette.c("snow"))
		l.draw_rect(Rect2(bp + Vector2(0, -2), Vector2(1, 1)), Palette.c("outline"))
		var cr: int = 3 if st == 2 else 5
		var ct: Vector2 = bp + Vector2( - float(cr / 2), - float(th) - float(cr) + 2.0)
		l.draw_rect(Rect2(ct + Vector2(0, 1), Vector2(cr, cr - 1)), g_d)
		l.draw_rect(Rect2(ct + Vector2(1, 0), Vector2(cr - 2, 1)), g)
		l.draw_rect(Rect2(ct + Vector2(0, float(cr) - 1.0), Vector2(cr, 1)), Palette.c("grass_deep"))
		if st >= 3:
			l.draw_rect(Rect2(ct + Vector2(1, 1), Vector2(1, 1)), g)
			l.draw_rect(Rect2(ct + Vector2(float(cr) - 2.0, 2), Vector2(1, 1)), g_d)
	if st >= 3:
		var b: Vector2 = p + Vector2(-9.0 if (h >> 3) % 2 == 0 else 7.0, 1.0)
		l.draw_rect(Rect2(b + Vector2(0, -1), Vector2(3, 2)), Palette.c("forest"))
		l.draw_rect(Rect2(b + Vector2(1, -2), Vector2(1, 1)), g)
		l.draw_rect(Rect2(b + Vector2(0, 1), Vector2(3, 1)), Palette.c("forest_dark"))
		var fl: Array = [Palette.c("fire_yellow"), Palette.c("snow")]
		for i2 in 2:
			var hf: int = Hash32.h2(h, i2, 3201)
			l.draw_rect(Rect2(p + Vector2(float(hf % 21) - 10.0, float((hf >> 5) % 8) - 2.0), Vector2(1, 1)), fl[(hf >> 9) % fl.size()])


static var _burnt_c: Dictionary = {}
static var _scorch: Array = []





static func _burnt(a: SpriteAtlas, n: String) -> ImageTexture:
	var key: String = "%d:%s" % [a.get_instance_id(), n]
	if _burnt_c.has(key):
		return _burnt_c[key]
	var tex: ImageTexture = null
	var info: Dictionary = a.info(n)
	var img: Image = a.texture.get_image() if a.texture != null else null
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var r0: Rect2 = a.rect(n, 0)
		var nf: int = maxi(1, int(info.get("frames", 1)))
		var full: = Rect2i(Vector2i(r0.position), Vector2i(int(r0.size.x) * nf, int(r0.size.y)))
		full = full.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var sub: Image = img.get_region(full)
		sub.convert(Image.FORMAT_RGBA8)
		var c_black: = Palette.c("ui_rubber")
		var c_soot: = Palette.c("smoke_black")
		var c_rust_d: = Palette.c("earth_dark")
		var c_rust: = Palette.c("brick_dark")
		var c_steel: = Palette.c("rock_dark")
		var c_bare: = Palette.c("rock")
		for y in sub.get_height():
			for x in sub.get_width():
				var c: Color = sub.get_pixel(x, y)
				if c.a < 0.5:
					continue
				var lum: float = c.r * 0.3 + c.g * 0.55 + c.b * 0.15
				var hh: int = Hash32.h2(x, y, 4242)
				var o: Color
				if lum < 0.16:
					o = c_black
				elif lum < 0.3:
					o = c_soot if hh % 5 != 0 else c_black
				elif lum < 0.45:
					o = c_rust_d if (x + y) % 2 == 0 else c_soot
				elif lum < 0.6:
					o = c_steel if hh % 3 != 0 else c_rust_d
				else:
					o = c_bare if hh % 3 != 0 else c_steel
				if hh % 7 == 0 and lum >= 0.2:
					o = c_rust
				sub.set_pixel(x, y, Color(o.r, o.g, o.b, 1.0))
		tex = ImageTexture.create_from_image(sub)
	_burnt_c[key] = tex
	return tex



static func _build_scorch() -> void :
	var soot: = Palette.c("smoke_black")
	var earth: = Palette.c("earth_dark")
	for v in 3:
		var img: = Image.create(17, 11, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in 11:
			for x in 17:
				var dx: float = (float(x) - 8.0) / (7.5 + float(v))
				var dy: float = (float(y) - 5.0) / (4.5 + float(v % 2))
				var d: float = sqrt(dx * dx + dy * dy)
				var hh: int = Hash32.h2(x + v * 31, y, 977)
				d += float(hh % 7) * 0.035
				if d < 0.55:
					img.set_pixel(x, y, Color(soot.r, soot.g, soot.b, 0.62))
				elif d < 0.85 and (x + y) % 2 == 0:
					img.set_pixel(x, y, Color(soot.r, soot.g, soot.b, 0.5))
				elif d < 1.0 and hh % 4 == 0:
					img.set_pixel(x, y, Color(earth.r, earth.g, earth.b, 0.45))
		_scorch.append(ImageTexture.create_from_image(img))



static func _spr_cd(l: CanvasItem, a: SpriteAtlas, n: String, fr: int, center: Vector2, mod: Color) -> void :
	var info: Dictionary = a.info(n)
	var r: Rect2 = a.rect(n, fr)
	CD.blit(l, a.texture, Rect2(center - Vector2(float(info["ax"]), float(info["ay"])), r.size), r, mod)


static func _spr(l: CanvasItem, a: SpriteAtlas, n: String, fr: int, center: Vector2, mod: Color) -> void :
	var info: Dictionary = a.info(n)
	var r: Rect2 = a.rect(n, fr)
	l.draw_texture_rect_region(a.texture, Rect2(center - Vector2(float(info["ax"]), float(info["ay"])), r.size), r, mod)







const TRUCK0: Array = [
	".bb.....oo.", 
	"obhosssoCwo", 
	"obSssssoCCo", 
	"oSSSSSSSAAo", 
	".orro.orro.", 
	"..oo...oo..", 
]
const TRUCK1: Array = [
	".bbokkukoo.", 
	"obhkkkkkCwo", 
	"obSkukkkCCo", 
	"oSSSSSSSAAo", 
	".orro.orro.", 
	"..oo...oo..", 
]


static func _build() -> void :
	var cols: Dictionary = {"o": Palette.c("outline"), "C": Palette.c("concrete_light"), "A": Palette.c("amber"), "a": Palette.c("amber_dark"), "w": Palette.c("water_coast"), 
		"s": Palette.c("rock_light"), "S": Palette.c("rock_dark"), "r": Palette.c("ui_rubber"), "b": Palette.c("fire_red"), 
		"h": Palette.c("concrete_light"), "k": Color(0.16, 0.14, 0.13), "u": Palette.c("brick_dark")}
	for li in 2:
		var rows: Array = TRUCK0 if li == 0 else TRUCK1
		var w: int = String(rows[0]).length()
		var hgt: int = rows.size()
		var img: = Image.create(w, hgt, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in hgt:
			var row: String = rows[y]
			for x in w:
				var ch: String = row[x]
				if cols.has(ch):
					img.set_pixel(x, y, cols[ch])

		var bea: Array = [Vector2i(8, 0), Vector2i(9, 0)]
		_tex["e%d" % li] = [ImageTexture.create_from_image(img), Vector2(bea[0]), Vector2(bea[1])]

		var imn: Image = img.duplicate()
		imn.rotate_90(COUNTERCLOCKWISE)
		_tex["n%d" % li] = [ImageTexture.create_from_image(imn), Vector2(bea[0].y, w - 1 - bea[0].x), Vector2(bea[1].y, w - 1 - bea[1].x)]

		var ims: Image = img.duplicate()
		ims.rotate_90(CLOCKWISE)
		_tex["s%d" % li] = [ImageTexture.create_from_image(ims), Vector2(hgt - 1 - bea[0].y, bea[0].x), Vector2(hgt - 1 - bea[1].y, bea[1].x)]
