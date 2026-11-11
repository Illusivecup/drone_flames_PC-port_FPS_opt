extends RefCounted









const BADGE_ZOOM: float = 1.4
const TIE_A: = Color("f3ead9")
const TIE_B: = Color("b02e3c")
const CASING: = Color(0.09, 0.06, 0.08, 0.95)
const WORKS_COL: = Color("ffc23a")
const CUT_COL: = Color("ff4a3d")
const DASH_PX: float = 7.0

static var _at: SpriteAtlas = null
static var _simp: Dictionary = {}


static func atlas() -> SpriteAtlas:
	if _at == null:
		_at = SpriteAtlas.load_atlas("res://assets/sprites/atlas_rail332.png", "res://assets/sprites/atlas_rail332.json", true)
	return _at




static func icon(ci: CanvasItem, cam: MapCamera, name: String, wp: Vector2, off: Vector2 = Vector2.ZERO, col: Color = Color.WHITE, k: int = 1) -> void :
	var at: SpriteAtlas = atlas()
	if at == null or not at.has(name):
		return
	var inf: Dictionary = at.info(name)
	var z: float = maxf(cam.zoom.x, 0.01)
	var sp: Vector2 = (cam.world_to_screen(wp) + off).round() - Vector2(float(inf["ax"]), float(inf["ay"])) * float(k)
	ci.draw_texture_rect_region(at.texture, Rect2(cam.screen_to_world(sp), Vector2(float(inf["w"]), float(inf["h"])) * float(k) / z), at.rect(name), col)



static func icon_screen(ci: CanvasItem, name: String, sp: Vector2, col: Color = Color.WHITE) -> void :
	var at: SpriteAtlas = atlas()
	if at == null or not at.has(name):
		return
	var inf: Dictionary = at.info(name)
	var p: Vector2 = sp.round() - Vector2(float(inf["ax"]), float(inf["ay"]))
	ci.draw_texture_rect_region(at.texture, Rect2(p, Vector2(float(inf["w"]), float(inf["h"]))), at.rect(name), col)


static func badge_of(tr: Dictionary) -> String:
	if tr.has("ride"):
		return "r332_c_troops"
	var res: String = String(tr.get("res", ""))
	if res == "" or bool(tr.get("cosmetic", true)):
		return ""
	return "r332_c_" + res





static func works(ci: CanvasItem, rail, view: Rect2) -> void :
	var at: SpriteAtlas = atlas()
	if at == null or not at.has("rail_work"):
		return
	var gw: GameWorld = rail.gw
	var inf: Dictionary = at.info("rail_work")
	var o: = Vector2(float(inf["ax"]), float(inf["ay"]))
	var sz: = Vector2(float(inf["w"]), float(inf["h"]))
	for e: Dictionary in rail.edges:
		if bool(e["dead"]) or float(e.get("bt", 0.0)) <= 0.0:
			continue
		var s: PackedVector2Array = e["s"]
		var n: int = s.size()
		var k: int = clampi(int(rail.built_frac(e) * float(n - 1)), 0, n - 1)
		var p: Vector2 = s[k]
		if not view.has_point(p):
			continue
		if gw.vision != null and not gw.vision.shows(rail._station_country(int(e["a"])), p):
			continue
		var dir: Vector2 = s[mini(n - 1, k + 4)] - s[maxi(0, k - 4)]
		var fr: int = posmod(roundi(rad_to_deg(dir.angle()) / 22.5), 16)
		var pr: Vector2 = (p + dir.normalized() * 3.0).round()
		if at.has("rail_work_shadow"):
			ci.draw_texture_rect_region(at.texture, Rect2(pr - o + Vector2(1, 1), sz), at.rect("rail_work_shadow", fr))
		ci.draw_texture_rect_region(at.texture, Rect2(pr - o, sz), at.rect("rail_work", fr))



static func badges(ci: CanvasItem, rail, view: Rect2, cam: MapCamera) -> void :
	if cam.zoom.x < BADGE_ZOOM:
		return
	var gw: GameWorld = rail.gw
	var k: int = 2 if cam.zoom.x >= 2.0 else 1
	var lift: float = 9.0 + 2.0 * cam.zoom.x + 6.0 * float(k - 1)
	for tr: Dictionary in rail.trains:
		var nm: String = badge_of(tr)
		if nm == "":
			continue
		var p: Vector2 = rail.pos_at(tr, float(tr["s"]))
		if not view.has_point(p) or (gw.vision != null and not gw.vision.shows(int(tr.get("country", -1)), p)):
			continue
		icon(ci, cam, nm, p, Vector2(0, - lift), Color.WHITE, k)




static func _simplified(e: Dictionary) -> Array:
	var id: int = int(e["id"])
	var s: PackedVector2Array = e["s"]
	var c: Array = _simp.get(id, [])
	if c.is_empty() or int(c[0]) != s.size():
		var pts: PackedVector2Array = GameWorld.poly_simplify(s, 1.2)
		var cum: = PackedFloat32Array()
		var acc: float = 0.0
		cum.append(0.0)
		for i in range(1, pts.size()):
			acc += pts[i - 1].distance_to(pts[i])
			cum.append(acc)
		c = [s.size(), pts, cum]
		_simp[id] = c
	return c



static func _ties(pts: PackedVector2Array, cum: PackedFloat32Array, d0: float, d1: float, dl: float, a: PackedVector2Array, b: PackedVector2Array, view: Rect2) -> void :
	var i: int = 0
	var d: float = floorf(d0 / dl) * dl
	var k: int = int(d / dl)
	while d < d1:
		var e: float = minf(d + dl, d1)
		var s0: float = maxf(d, d0)
		while i < pts.size() - 2 and cum[i + 1] < s0:
			i += 1
		var p0: Vector2 = _at_len(pts, cum, s0, i)
		var p1: Vector2 = _at_len(pts, cum, e, i)
		if view.has_point(p0) or view.has_point(p1):
			if k % 2 == 0:
				a.append(p0)
				a.append(p1)
			else:
				b.append(p0)
				b.append(p1)
		d += dl
		k += 1


static func _at_len(pts: PackedVector2Array, cum: PackedFloat32Array, l: float, i0: int) -> Vector2:
	var i: int = i0
	while i < pts.size() - 2 and cum[i + 1] < l:
		i += 1
	var seg: float = maxf(0.0001, cum[i + 1] - cum[i])
	return pts[i].lerp(pts[i + 1], clampf((l - cum[i]) / seg, 0.0, 1.0))


static func _sub(pts: PackedVector2Array, cum: PackedFloat32Array, d0: float, d1: float) -> PackedVector2Array:
	var out: = PackedVector2Array()
	out.append(_at_len(pts, cum, d0, 0))
	for i in pts.size():
		if cum[i] > d0 and cum[i] < d1:
			out.append(pts[i])
	out.append(_at_len(pts, cum, d1, 0))
	return out


static func logistics(ci: CanvasItem, gw: GameWorld, z: float, view: Rect2) -> void :
	var rail = gw.rail
	if rail == null:
		return
	var cam: MapCamera = gw.camera
	var sc: float = 1.0 / maxf(z, 0.01)
	var t: float = gw.game_time
	var ta: = PackedVector2Array()
	var tb: = PackedVector2Array()
	var heads: Array = []
	var cuts: Array = []
	var dl: float = DASH_PX * sc
	for e: Dictionary in rail.edges:
		if bool(e["dead"]):
			continue
		var c: Array = _simplified(e)
		var pts: PackedVector2Array = c[1]
		var cum: PackedFloat32Array = c[2]
		if pts.size() < 2:
			continue
		var bb: = Rect2(pts[0], Vector2.ZERO)
		for q: Vector2 in pts:
			bb = bb.expand(q)
		if not bb.grow(8.0 * sc).intersects(view):
			continue
		var L: float = cum[cum.size() - 1]
		var fr: float = rail.built_frac(e)
		var bl: float = L * fr
		if bl > 0.5:
			var bp: PackedVector2Array = _sub(pts, cum, 0.0, bl) if fr < 1.0 else pts
			ci.draw_polyline(bp, CASING, 5.0 * sc)
			_ties(pts, cum, 0.0, bl, dl, ta, tb, view.grow(dl))
		if fr < 1.0:
			var up: PackedVector2Array = _sub(pts, cum, bl, L)
			ci.draw_polyline(up, Color(0.09, 0.06, 0.08, 0.45), 3.0 * sc)
			var dots: = PackedVector2Array()
			_ties(pts, cum, bl, L, dl * 0.6, dots, PackedVector2Array(), view.grow(dl))
			if not dots.is_empty():
				ci.draw_multiline(dots, Color(WORKS_COL, 0.85), 1.5 * sc)
			heads.append([_at_len(pts, cum, bl, 0), fr])
		for cu: Array in e["cuts"]:
			if float(cu[1]) > t:
				cuts.append([cu[2], float(cu[1]) - t])
		for br: Array in e["br"]:
			var b: Bridge = br[0]
			if not b.passable() and not b.cells.is_empty():
				var mid: int = clampi(int((float(br[1]) + float(br[2])) * 0.5), 0, (e["s"] as PackedVector2Array).size() - 1)
				cuts.append([(e["s"] as PackedVector2Array)[mid], - maxf(1.0, b.left())])
	if not ta.is_empty():
		ci.draw_multiline(ta, TIE_A, 3.0 * sc)
	if not tb.is_empty():
		ci.draw_multiline(tb, TIE_B, 3.0 * sc)
	UiKit.ensure()
	var font: Font = UiKit.f_title if UiKit.f_title != null else ThemeDB.fallback_font

	for h: Array in heads:
		var hp: Vector2 = h[0]
		if not view.has_point(hp):
			continue
		icon(ci, cam, "r332_works", hp)
		_label(ci, font, hp, Vector2(7, 4), "%d%%" % roundi(float(h[1]) * 100.0), WORKS_COL, sc)

	for cu2: Array in cuts:
		var cp: Vector2 = cu2[0]
		if not view.has_point(cp):
			continue
		var r: float = 4.0 * sc
		for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
			ci.draw_line(cp - d * r, cp + d * r, CASING, 4.0 * sc)
			ci.draw_line(cp - d * r, cp + d * r, CUT_COL, 2.0 * sc)
		var lt: String = (Loc.t("ремонт %d с") % ceili(float(cu2[1]))) if float(cu2[1]) >= 0.0 else (Loc.t("мост %d с") % ceili( - float(cu2[1])) if float(cu2[1]) < -0.5 else Loc.t("мост"))
		_label(ci, font, cp, Vector2(7, 4), lt, CUT_COL, sc)

	for st: Dictionary in rail.stations:
		var pp: Vector2 = st.get("p", Vector2.ZERO)
		if not view.has_point(pp) or ((rail.adj.get(int(st["id"]), []) as Array).is_empty() and not st.has("man")):
			continue
		icon(ci, cam, "r332_station", pp, Vector2.ZERO, Color(1, 0.55, 0.5) if float(st["ruin_t"]) >= 0.0 else Color.WHITE)

	for tr: Dictionary in rail.trains:
		var p: Vector2 = rail.pos_at(tr, float(tr.get("s", 0.0)))
		if not view.has_point(p) or (gw.vision != null and not gw.vision.shows(int(tr.get("country", -1)), p)):
			continue
		var nm: String = badge_of(tr)
		if nm == "":
			ci.draw_circle(p, 3.0 * sc, CASING)
			ci.draw_circle(p, 2.0 * sc, Color("d8d2c4"))
			continue
		ci.draw_circle(p, 4.0 * sc, CASING)
		ci.draw_circle(p, 3.0 * sc, Color("8fbf4a") if tr.has("ride") else Color("ffb43a"))
		icon(ci, cam, nm, p, Vector2(0, -11))


static func _label(ci: CanvasItem, font: Font, wp: Vector2, off: Vector2, txt: String, col: Color, sc: float) -> void :
	ci.draw_set_transform(wp, 0.0, Vector2(sc, sc))
	ci.draw_string_outline(font, off, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, Color(0.04, 0.05, 0.08, 0.95))
	ci.draw_string(font, off, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
	ci.draw_set_transform(Vector2.ZERO)





static func _offset(sp: PackedVector2Array, d: float) -> PackedVector2Array:
	var out: = PackedVector2Array()
	var n: int = sp.size()
	for i in n:
		var t: Vector2 = (sp[mini(n - 1, i + 1)] - sp[maxi(0, i - 1)]).normalized()
		out.append(sp[i] + Vector2(t.y, - t.x) * d)
	return out




static func preview_leg(ci: CanvasItem, cam: MapCamera, pl: Dictionary, t: float, font: Font) -> void :
	var pts: PackedVector2Array = pl.get("pts", PackedVector2Array())
	if pts.size() < 2:
		return
	var sp: = PackedVector2Array()
	for q: Vector2 in pts:
		sp.append(cam.world_to_screen(q))
	sp = GameWorld.poly_simplify(sp, 1.0)


	var near: bool = cam.zoom.x >= 1.0
	var al: float = 0.8 if near else 1.0
	if near:
		sp = _offset(sp, 9.0)
	ci.draw_polyline(sp, Color(CASING, 0.55 * al), 6.0 if near else 7.0)
	var cum: = PackedFloat32Array([0.0])
	var acc: float = 0.0
	for i in range(1, sp.size()):
		acc += sp[i - 1].distance_to(sp[i])
		cum.append(acc)
	var ta: = PackedVector2Array()
	var tb: = PackedVector2Array()
	var sh: float = fmod(t * 14.0, DASH_PX * 2.0)
	_ties(sp, cum, 0.0, acc, DASH_PX, ta, tb, Rect2(-1000000.0, -1000000.0, 2000000.0, 2000000.0))
	if sh > DASH_PX:
		var tmp: PackedVector2Array = ta
		ta = tb
		tb = tmp
	if not ta.is_empty():
		ci.draw_multiline(ta, Color(TIE_A, al), 3.0 if near else 4.0)
	if not tb.is_empty():
		ci.draw_multiline(tb, Color(TIE_B, al), 3.0 if near else 4.0)
	icon_screen(ci, "r332_station", cam.world_to_screen(pl["p1"]))
	icon_screen(ci, "r332_station", cam.world_to_screen(pl["p2"]))
	var mid: Vector2 = _at_len(sp, cum, acc * 0.5, 0)
	var mins: int = maxi(1, ceili(float(pl.get("eta", 0.0)) / 60.0))
	var txt: String = Loc.t("ПОЕЗД ~%d МИН") % mins
	var at: = mid + Vector2(8, -6)
	icon_screen(ci, "r332_c_troops", mid + Vector2(0, -12))
	ci.draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, Color(0.04, 0.05, 0.08, 0.95))
	ci.draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ffd9a0"))




const CUT_ZOOM: float = 1.0




static func station_works(ci: CanvasItem, rail, view: Rect2, z: float) -> void :
	var gw: GameWorld = rail.gw
	var net: = Palette.c("grass_dark")
	net.a = 0.75
	var ca: SpriteAtlas = gw.atlas_crane
	for st: Dictionary in rail.stations:
		var bt: float = float(st.get("bt", 0.0))
		if bt <= 0.0:
			continue
		var o: Vector2 = Vector2(st["cell"] as Vector2i) * float(GameWorld.CELL)
		var sz: = Vector2(Rail.STATION_FW, Rail.STATION_FD) * float(GameWorld.CELL)
		if not view.intersects(Rect2(o - Vector2(4, 24), sz + Vector2(8, 28))):
			continue
		if gw.vision != null and not gw.vision.shows(rail._station_country(int(st["id"])), o):
			continue
		var top: float = o.y - 4.0
		var hh: float = sz.y + 3.0
		ci.draw_rect(Rect2(o.x, top, 1, hh), net)
		ci.draw_rect(Rect2(o.x + sz.x - 1, top, 1, hh), net)
		var yy: float = top
		while yy < top + hh:
			ci.draw_rect(Rect2(o.x, yy, sz.x, 1), net)
			yy += 3.0
		if ca != null and ca.has("crane_s"):
			var info: Dictionary = ca.info("crane_s")
			var fr: int = (int(FxLayer.vt * float(info["fps"])) + int(st["id"]) * 7) % int(info["frames"])
			var r: Rect2 = ca.rect("crane_s", fr)
			ci.draw_texture_rect_region(ca.texture, Rect2(o + Vector2(4, sz.y - 2.0) - Vector2(float(info["ax"]), float(info["ay"])), r.size), r)
		if z >= 1.2:
			var frac: float = clampf((gw.game_time - float(st.get("b0", 0.0))) / bt, 0.0, 1.0)
			var bw: int = 16
			var x0: int = int(o.x + (sz.x - float(bw)) * 0.5)
			var y0: int = int(top) - 4
			ci.draw_rect(Rect2(x0, y0, bw, 3), Palette.c("ui_rubber"))
			ci.draw_rect(Rect2(x0 + 1, y0 + 1, bw - 2, 1), Palette.c("ui_steel_dark"))
			var fill: int = int(floorf(frac * float(bw - 2)))
			if fill > 0:
				ci.draw_rect(Rect2(x0 + 1, y0 + 1, fill, 1), Palette.c("grass_light"))



static func cut_labels(ci: CanvasItem, rail, view: Rect2, cam: MapCamera) -> void :
	var z: float = cam.zoom.x
	if z < CUT_ZOOM:
		return
	var gw: GameWorld = rail.gw
	var t: float = gw.game_time
	var sc: float = 1.0 / maxf(z, 0.01)
	UiKit.ensure()
	var font: Font = UiKit.f_title if UiKit.f_title != null else ThemeDB.fallback_font
	var seen: Dictionary = {}
	for e: Dictionary in rail.edges:
		if bool(e["dead"]):
			continue
		var own: int = rail._station_country(int(e["a"]))
		for cu: Array in e["cuts"]:
			if float(cu[1]) <= t:
				continue
			var cp: Vector2 = cu[2]
			if not view.has_point(cp) or (gw.vision != null and not gw.vision.shows(own, cp)):
				continue
			ci.draw_arc(cp, 8.0 * sc, 0.0, TAU, 20, CASING, 3.0 * sc)
			ci.draw_arc(cp, 8.0 * sc, 0.0, TAU, 20, CUT_COL, 1.5 * sc)
			_cross(ci, cp, sc)
			_label(ci, font, cp, Vector2(10, 4), Loc.t("ремонт %d с") % ceili(float(cu[1]) - t), CUT_COL, sc)
		for br: Array in e["br"]:
			var b: Bridge = br[0]
			if b.passable() or b.cells.is_empty() or seen.has(b.id):
				continue
			seen[b.id] = true
			var bp: Vector2 = b.center_px()
			if not view.has_point(bp) or (gw.vision != null and not gw.vision.shows(own, bp)):
				continue
			_label(ci, font, bp, Vector2(7, -6), Loc.t("ж/д мост %d с") % ceili(b.left()), CUT_COL, sc)


static func _cross(ci: CanvasItem, cp: Vector2, sc: float) -> void :
	var r: float = 5.0 * sc
	for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
		ci.draw_line(cp - d * r, cp + d * r, CASING, 4.0 * sc)
		ci.draw_line(cp - d * r, cp + d * r, CUT_COL, 2.0 * sc)



static func busy(rail) -> bool:
	var t: float = rail.gw.game_time
	for st: Dictionary in rail.stations:
		if float(st.get("bt", 0.0)) > 0.0:
			return true
	for e: Dictionary in rail.edges:
		if bool(e["dead"]):
			continue
		for cu: Array in e["cuts"]:
			if float(cu[1]) > t:
				return true
		for br: Array in e["br"]:
			if not (br[0] as Bridge).passable():
				return true
	return false
