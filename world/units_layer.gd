class_name UnitsLayer
extends Node2D





var gw: GameWorld
var air: bool = false
var _had: bool = false





var night_pass: bool = false
const NIGHT_BOOST: float = 0.6
const BORDER_NIGHT: float = 1.0
const BADGE_ZOOM: float = 0.8
const BADGE_DT: float = 0.12
const BADGE_R: float = 44.0
const OUTLINE_OFFS: Array = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
const PLATE: = Color(0.02, 0.03, 0.07, 0.42)
const FLAT_SHADER: = "shader_type canvas_item;\nvarying vec4 vcol;\nvoid vertex() {\n\tvcol = COLOR;\n}\nvoid fragment() {\n\tCOLOR = vec4(vcol.rgb, texture(TEXTURE, UV).a * vcol.a);\n}\n"
static var _flat: Shader = null
var _outline: Node2D = null
var _comp: = Vector3.ONE
var _km: Color = Color.WHITE
var _vu: Array[Unit] = []
var _nv: int = 0
var _sa: SpriteAtlas = null
var _sn: String = ""
var _big: int = 0

static var _u314: SpriteAtlas = null
static var _u314_tried: bool = false
const _SQ9: Dictionary = {Unit.Type.INFANTRY: "sq9_infantry", Unit.Type.ATGM: "sq9_atgm", Unit.Type.ASSAULT: "sq9_assault", Unit.Type.MORTAR: "sq9_mortar"}

var _bx: = PackedFloat32Array()
var _by: = PackedFloat32Array()
var _btop: = PackedFloat32Array()
var _bn: = PackedInt32Array()
var _bc: = PackedInt32Array()
var _bsel: = PackedByteArray()
var _bgr: = PackedInt32Array()
var _nb: int = 0



var _pcx: = PackedFloat32Array()
var _pcy: = PackedFloat32Array()
var _pcc: = PackedInt32Array()
var _pn: int = 0
var _sk: = PackedInt32Array()
var _vpts: = PackedVector4Array()
var _badge_t: float = 0.0
var _last_z: float = -1.0
var _last_nf: float = -1.0


func _ready() -> void :
	if air:
		return
	if _flat == null:
		_flat = Shader.new()
		_flat.code = FLAT_SHADER
	_outline = Node2D.new()
	_outline.name = "UnitOutline"
	_outline.show_behind_parent = true
	var m: = ShaderMaterial.new()
	m.shader = _flat
	_outline.material = m
	add_child(_outline)
	_outline.draw.connect(_draw_outline)


func _process(_delta: float) -> void :
	if gw == null or gw.mil == null:
		return
	var mil: Military = gw.mil
	var busy: bool = not mil.missiles.is_empty() or not mil.trail_t.is_empty() or not mil.air.aams.is_empty() or not mil.air.tracers.is_empty()\
	or gw.army.busy() or not gw.econ.trucks.is_empty() or not gw.defense.shots.is_empty() or not gw.army.shells.is_empty() or not gw.army.rockets.is_empty()
	if not mil.air.kabs.is_empty() or not mil.air.kab_trail.is_empty() or not mil.air.nars.is_empty():
		busy = true
	if not air and _sel_army() != null:
		busy = true
	if not busy:
		for a: Aircraft in mil.air.aircraft:
			if a.state != Aircraft.State.PARKED or a.service_t > 0.0:
				busy = true
				break
	if not busy:
		for d: Drone in mil.drones:
			if d.state != Drone.State.PARKED:
				busy = true
				break
	if not busy:
		for f: Facility in mil.facilities:
			if f.producing or f.moving or not f.craters.is_empty() or gw.game_time < f.flash_until or f.restore_t > 0.0 or f.reload_t > 0.0 or f.lower_t > 0.0:
				busy = true
				break
	if not air and gw.diplo != null and gw.diplo.sky != null and not gw.diplo.sky.trip.trips.is_empty():
		busy = true
	if not air and _pre_frame():
		busy = true
	if not air and gw.aftermath != null and ( not gw.aftermath.wrecks.is_empty() or not gw.aftermath.trucks.is_empty() or _rebuilding()):
		busy = true
	if air and gw.aftermath != null and not gw.aftermath.air.falls.is_empty():
		busy = true
	if busy or _had:
		queue_redraw()
		if _outline != null:
			_outline.queue_redraw()
	_had = busy


const MD = preload("res://ui/ui24/map_declutter.gd")
const AD = preload("res://world/aftermath_draw.gd")
const CD = preload("res://world/cover_draw.gd")
const AWD = preload("res://world/air_wreck_draw.gd")



func _view(m: float) -> Rect2:
	var z: float = gw.camera.zoom.x
	var half: Vector2 = gw.camera.view_size() * 0.5 / z
	return Rect2(gw.camera.position - half, half * 2.0).grow(m)



func _rebuilding() -> bool:
	for e: Array in gw.ruins:
		if e.size() >= 4 and float(e[2]) >= 0.0:
			return true
	return false


func _draw() -> void :
	if gw == null or gw.mil == null or gw.camera == null:
		return
	var mil: Military = gw.mil
	var a: SpriteAtlas = gw.atlas2
	var z: float = gw.camera.zoom.x
	if night_pass:
		if _km.a > 0.02 and z >= 0.5:
			AD.draw_night(self, gw, _view(24.0), _km.a / NIGHT_BOOST)
			_ground_units(z)
		_draw_badges(z)
		return
	if not air and _sel_army() != null:
		_army_sel(z, false)
	if z < 0.5:
		return
	if not air:
		for f: Facility in mil.facilities:
			if f.craters.is_empty() and not f.moving:
				continue
			if not _see_fac(f):
				continue
			for c: Vector2 in f.craters:
				_spr(gw.fx_atlas, "crater_m", 0, c)
			if f.moving:
				_vehicle(f)
		_trips(z)
		_cranes(mil)
		AD.draw(self, gw, _view(24.0), z)
		_ground_units(z)
		for d: Drone in mil.drones:
			var gp: Vector2 = d.pos.round()
			if not _see_air(d.country_id, d.pos):
				continue
			if d.kind == 1:
				if z >= 1.0:
					if _cm_ok():
						_spr(gw.atlas_cm28, "cm_shadow", d.frame, gp + Vector2(roundf(d.h), roundf(d.h)), Color(1, 1, 1, 0.7))
					else:
						_spr(gw.atlas5, "cruise_shadow", d.frame, gp + Vector2(roundf(d.h), roundf(d.h)))
				if d.boost_t < 0.0:


					var fall: Vector2 = Vector2(0.0, roundf(clampf((Air.CR_DROP + d.boost_t) / Air.CR_DROP, 0.0, 1.0) * 3.0))
					if _cm_ok():
						_spr(gw.atlas_cm28, "cm", d.frame, gp + fall, Color(0.85, 0.85, 0.9))
					else:
						_spr(gw.atlas5, "cruise", d.frame, gp + fall)
				continue

			var ja: bool = d.kind == 2 and gw.atlas12.has("uav_jet")
			var da: SpriteAtlas = gw.atlas12 if ja else a
			var dn: String = "uav_jet" if ja else "uav_delta"
			if not d.airborne():
				if d.state == Drone.State.PARKED or d.state == Drone.State.WAIT:
					_spr(da, dn + "_shadow", 0, gp + Vector2(1, 1))
					_spr(da, dn + "_parked", 0, gp)
				else:
					_spr(da, dn + "_shadow", d.frame, gp + Vector2(1, 1))
					_spr(da, dn + ("_cold" if ja else ""), d.frame, gp)
			elif z >= 1.0:
				var hh: float = _shadow_h(d)
				_spr(da, dn + "_shadow", d.frame, gp + Vector2(hh, hh))
		var a5: SpriteAtlas = gw.atlas5
		for ac: Aircraft in mil.air.aircraft:
			if ac.state == Aircraft.State.DEAD or not _see_air(ac.country_id, ac.pos):
				continue
			var n: String = _ac_name(ac)
			var aa: SpriteAtlas = _ac_atlas(ac)
			var ap: Vector2 = ac.pos.round()
			if not ac.airborne():
				_spr(aa, _ac_shadow(ac), ac.frame, ap + Vector2(1, 1))
				_spr(aa, n, ac.frame, ap)
				if ac.type == Aircraft.Type.HELI:
					_spr(a5, "heli_rotor", 0, ap)
				if ac == gw.selected_drone():
					_brackets(ap, int(Air.SPEC[ac.type]["sel"]))
			elif z >= 1.0:
				var sh: float = roundf(ac.h)
				_spr(aa, _ac_shadow(ac), ac.frame, ap + Vector2(sh, sh), Color(1, 1, 1, 0.5))
		if z >= 1.0:
			_kab_shadows()
		if z >= 1.0:
			for m: Missile in mil.missiles:
				if not _see_air(m.country_id, m.screen_pos()):
					continue
				_spr(gw.atlas3, "missile_shadow", m.frame, m.ground().round() + Vector2(1, 1))
		return
	_trail()
	if z >= 1.0:
		var sel: Object = gw.selected_drone()
		for d: Drone in mil.drones:
			if not _see_air(d.country_id, d.pos):
				continue
			if d.kind == 1:
				if d.boost_t >= 0.0 and d.boost_t < 1.5 and d.state == Drone.State.FLY:
					_fx(gw.fx_atlas2, "booster_flame_loop", (d.pos - Vector2.from_angle(d.heading) * 5.0).round())
				if d.boost_t < 0.0:
					continue
				if _cm_ok():
					_spr(gw.atlas_cm28, "cm", d.frame, d.pos.round())
				else:
					_spr(gw.atlas5, "cruise", d.frame, d.pos.round())
				if d == sel:
					_brackets(d.pos.round())
				continue
			if d.airborne():
				if d.state == Drone.State.BOOST and d.boost_t < Military.BOOST_TIME:
					_fx(gw.fx_atlas2, "booster_flame_loop", (d.pos - Vector2.from_angle(d.heading) * 6.0).round())
				if d.kind == 2 and gw.atlas12.has("uav_jet"):
					_outlined(gw.atlas12, "uav_jet", "uav_jet_shadow", d.frame, d.pos.round())
				else:
					_outlined(a, "uav_delta", "uav_delta_shadow", d.frame, d.pos.round())
				if d == sel:
					_brackets(d.pos.round())
		for ac: Aircraft in mil.air.aircraft:
			if ac.state == Aircraft.State.DEAD or not ac.airborne() or not _see_air(ac.country_id, ac.pos):
				continue
			var n2: String = _ac_name(ac)
			var p2: Vector2 = ac.pos.round()
			_outlined(_ac_atlas(ac), n2, _ac_shadow(ac), ac.frame, p2)
			if ac.type == Aircraft.Type.HELI:
				_spr(gw.atlas5, "heli_rotor", int(FxLayer.vt * 12.0) % 4, p2)
			if ac == sel:
				_brackets(p2, int(Air.SPEC[ac.type]["sel"]))
		if not Air.flare_fx.is_empty():
			_flares()
		if gw.aftermath != null and not gw.aftermath.air.falls.is_empty():
			AWD.draw_falls(self, gw, _view(24.0))
		var fa: SpriteAtlas = atlas314()
		var fpv_new: bool = fa != null and fa.has("fpv_spin")
		var spin: bool = int(FxLayer.vt * 12.0) % 2 == 1
		for u: Unit in gw.army.units:
			if u.type == Unit.Type.FPV and u.alive() and _see_air(u.country_id, u.pos):
				if fpv_new:
					_spr(fa, "fpv_shadow", u.frame, u.pos.round() + Vector2(3, 3))
					_spr(fa, "fpv_spin" if spin else "fpv", u.frame, u.pos.round())
				else:
					_spr(gw.atlas7, "fpv_shadow", u.frame, u.pos.round() + Vector2(3, 3))
					_spr(gw.atlas7, "fpv", u.frame, u.pos.round())
		_army_air()
		for sh: Dictionary in gw.defense.shots:
			if not _see_air(int(sh.get("c", -1)), sh["pos"]):
				continue
			var fr2: int = posmod(roundi(rad_to_deg(float(sh["heading"])) / 22.5), 16)
			var nm: String = "sam" if sh["kind"] == "sam" else "int_drone"
			_outlined(gw.atlas6, nm, nm + "_shadow", fr2, (sh["pos"] as Vector2).round())
		for rk: Dictionary in gw.army.rockets:
			if not _see(int(rk.get("c", -1)), rk["pos"]):
				continue
			var fr3: int = posmod(roundi(rad_to_deg(float(rk["heading"])) / 22.5), 16)
			var rn: String = String(rk["kind"])
			if gw.atlas8.has(rn):
				_spr(gw.atlas8, rn, fr3, (rk["pos"] as Vector2).round())
		for s2: Dictionary in gw.army.shells:
			var k: float = clampf(float(s2["t"]) / float(s2["dur"]), 0.0, 1.0)
			var sp2: Vector2 = (s2["from"] as Vector2).lerp(s2["to"], k)
			if not _see(int(s2.get("c", -1)), sp2):
				continue
			var back: Vector2 = ((s2["to"] as Vector2) - (s2["from"] as Vector2)).normalized() * 3.0
			draw_line(sp2 - back, sp2, Palette.c("fire_yellow"), 1.0)
		_kab_air()
		_nars()
		AirDuelLayer.draw(self, gw, func(q: Vector2) -> bool: return _see_air(-1, q))
		for m2: Dictionary in mil.air.aams:
			if not _see_air(int(m2.get("c", -1)), m2["pos"]):
				continue
			var fr: int = posmod(roundi(rad_to_deg(float(m2["heading"])) / 22.5), 16)
			_spr(gw.atlas5, "aam", fr, (m2["pos"] as Vector2).round())
		for tr: Array in mil.air.tracers:
			if not _see(-1, tr[0]):
				continue
			var p0: Vector2 = (tr[0] as Vector2).round() + Vector2(0.5, 0.5)
			var p1: Vector2 = (tr[1] as Vector2).round() + Vector2(0.5, 0.5)
			draw_line(p0, p0.lerp(p1, 0.55), Palette.c("window_light"), 1.0)
			draw_line(p0.lerp(p1, 0.7), p1, Palette.c("fire_yellow"), 1.0)
		for m: Missile in mil.missiles:
			var sp: Vector2 = m.screen_pos().round()
			if not _see_air(m.country_id, sp):
				continue
			var back: Vector2 = - Vector2.from_angle(deg_to_rad(m.frame * 22.5))
			if m.state == Missile.State.FLIGHT or m.t > 0.1:
				_fx(gw.fx_atlas2, "missile_flame_loop", (sp + back * 6.0).round())
			_outlined(gw.atlas3, "missile", "missile_shadow", m.frame, sp)
			if m == sel:
				_brackets(sp)
	_bars(mil)



func _trail() -> void :
	var mil: Military = gw.mil
	if mil.trail_pts.is_empty():
		return
	var a: SpriteAtlas = gw.fx_atlas2
	var info: Dictionary = a.info("trail_puff")
	var nf: int = int(info["frames"])
	var fps: float = float(info["fps"])
	var anc: = Vector2(float(info["ax"]), float(info["ay"]))
	var fog: bool = gw.vision != null and gw.vision.active()
	if fog and _trail_own.size() > mil.trail_pts.size() * 2 + 64:
		var keep: Dictionary = {}
		for q: Vector2 in mil.trail_pts:
			if _trail_own.has(q):
				keep[q] = _trail_own[q]
		_trail_own = keep
	for i in mil.trail_pts.size():
		if fog and not _trail_vis(mil.trail_pts[i]):
			continue
		var fr: int = mini(nf - 1, int((gw.game_time - mil.trail_t[i]) * fps))
		var r: Rect2 = a.rect("trail_puff", fr)
		var pos: Vector2 = mil.trail_pts[i] - anc
		var size: Vector2 = r.size
		var fl: int = mil.trail_flip[i]
		if fl & 1:
			pos.x += size.x
			size.x = - size.x
		if fl & 2:
			pos.y += size.y
			size.y = - size.y
		draw_texture_rect_region(a.texture, Rect2(pos, size), r)




var _trail_own: Dictionary = {}


func _trail_vis(p: Vector2) -> bool:
	var v: Vision = gw.vision
	if v.sees_air(p):
		return true
	if _trail_own.has(p):
		return bool(_trail_own[p])
	var own: bool = false
	var bd: float = 120.0 * 120.0
	for m: Missile in gw.mil.missiles:
		var d: float = m.screen_pos().distance_squared_to(p)
		if d < bd:
			bd = d
			own = v.friend(m.country_id)
	_trail_own[p] = own
	return own





func _vehicle(f: Facility) -> void :
	var a: SpriteAtlas = gw.atlas3 if f.kind == Facility.Kind.TEL else gw.atlas6
	var n: String = gw.mil.vehicle_sprite(f)
	if not a.has(n) and gw.atlas_navy1 != null and gw.atlas_navy1.has(n):
		a = gw.atlas_navy1
	if not a.has(n):
		return
	var info: Dictionary = a.info(n)
	var dir: int = gw.mil.drive_dir_of(f)

	var gc: Vector2 = f.mpos - Vector2(0.0, float(info["fd"]) * 2.0)
	if dir == 1 or dir == 3:
		var n2: String = n + ("_s" if dir == 1 else "_n")
		if a.has(n2):
			n = n2
			info = a.info(n2)
	var r: Rect2 = a.rect(n, 0)
	var tl: Vector2 = (gc + Vector2( - float(info["fw"]) * 2.0 - float(info["ax"]), float(info["fd"]) * 2.0 - float(info["ay"]))).round()

	tl.y -= float(int(gw.game_time * 6.0) % 2)
	var size: Vector2 = r.size
	var west: bool = dir == 2 or ((dir == 1 or dir == 3) and n == gw.mil.vehicle_sprite(f) and f.flip)
	if west:
		size.x = - size.x
	draw_texture_rect_region(a.texture, Rect2(tl, size), r)
	if f.kind == Facility.Kind.AD_SPAAG and info.has("turret"):

		var tp: Vector2 = Vector2(float(info["turret"][0]), float(info["turret"][1]))
		if west:
			tp.x = r.size.x - 1.0 - tp.x
		_spr(gw.atlas6, "ad_spaag_turret", [0, 4, 8, 12][dir], (tl + tp).round())
	if f == gw.selected_drone() or f == gw.selected_facility():
		_brackets(f.mpos.round() + Vector2(0, -8))





const TRIP_GAP: float = 11.0
var _ttrail: Dictionary = {}


func _trips(z: float) -> void :
	var tr = gw.diplo.sky.trip if gw.diplo != null and gw.diplo.sky != null else null
	if tr == null or tr.trips.is_empty():
		_ttrail.clear()
		return
	var a3: SpriteAtlas = atlas314()
	var ta: SpriteAtlas = a3 if a3 != null and a3.has("truck") else gw.atlas7
	for fid: int in _ttrail.keys():
		if not tr.trips.has(fid):
			_ttrail.erase(fid)
	for fid: int in tr.trips:
		var f: Facility = tr._fac(fid)
		if f == null or not _see_fac(f):
			continue
		var ph: int = int(tr.trips[fid]["ph"])
		if ph == 1 and f.moving:
			var tl: PackedVector2Array = _ttrail.get(fid, PackedVector2Array())
			if tl.is_empty() or tl[tl.size() - 1].distance_to(f.mpos) >= 3.0:
				tl.append(f.mpos)
				if tl.size() > 24:
					tl.remove_at(0)
				_ttrail[fid] = tl
			var ahead: Vector2 = _along(f.mpos, f.mpath, TRIP_GAP)
			var behind: Vector2 = _back(tl, f.mpos, TRIP_GAP)
			if behind.distance_to(f.mpos) < TRIP_GAP * 0.8:
				var fw: Vector2 = (ahead - f.mpos).normalized() if ahead.distance_to(f.mpos) > 1.0 else Vector2.RIGHT
				behind = f.mpos - fw * TRIP_GAP
			for q: Array in [[behind, f.mpos], [ahead, f.mpos]]:
				var tp: Vector2 = q[0]
				if tp.distance_to(f.mpos) < 4.0 or ta == null or not ta.has("truck"):
					continue
				var dv: Vector2 = (f.mpos - tp) if q[0] == behind else (tp - f.mpos)
				var fr: int = posmod(roundi(rad_to_deg(dv.angle()) / 22.5), 16)
				_spr(ta, "truck_shadow", fr, tp.round() + Vector2(1, 1), _km)
				_spr(ta, "truck", fr, tp.round(), _km)
		elif ph != 1 and z >= 1.0:
			var tot: float = float(tr.PACK_T) if ph == 0 else float(gw.diplo.sky.DEPLOY_T)
			var k: float = clampf(1.0 - float(tr.left(fid)) / maxf(0.1, tot), 0.0, 1.0)
			var p0: Vector2 = (f.center_px() + Vector2(-7.0, - float(f.size.y) * 2.0 - 7.0)).round()
			draw_rect(Rect2(p0, Vector2(14, 2)), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(p0, Vector2(roundf(14.0 * k), 2)), (Palette.c("amber") if ph == 0 else Palette.c("intercept_cyan")) * _km)



static func _along(p: Vector2, path: Array[Vector2], d: float) -> Vector2:
	var at: Vector2 = p
	var left: float = d
	for q: Vector2 in path:
		var seg: float = at.distance_to(q)
		if seg >= left:
			return at + (q - at) / seg * left
		left -= seg
		at = q
	return at



static func _back(tl: PackedVector2Array, p: Vector2, d: float) -> Vector2:
	var at: Vector2 = p
	var left: float = d
	for i in range(tl.size() - 1, -1, -1):
		var q: Vector2 = tl[i]
		var seg: float = at.distance_to(q)
		if seg >= left and seg > 0.0:
			return at + (q - at) / seg * left
		left -= seg
		at = q
	return at


func _shadow_h(d: Drone) -> float:
	var hh: float = roundf(d.h)
	if d.state == Drone.State.FLY and d.h >= Military.CRUISE_H:

		hh -= float(int((gw.game_time + d.id * 0.7) / 2.0) % 2)
	return maxf(1.0, hh)


func _spr(a: SpriteAtlas, n: String, fr: int, center: Vector2, mod: Color = Color.WHITE) -> void :
	var info: Dictionary = a.info(n)
	var r: Rect2 = a.rect(n, fr)
	draw_texture_rect_region(a.texture, Rect2(center - Vector2(float(info["ax"]), float(info["ay"])), r.size), r, mod)



func _cm_ok() -> bool:
	return gw.atlas_cm28 != null and gw.atlas_cm28.has("cm") and gw.atlas_cm28.has("cm_shadow")



func _fx(a: SpriteAtlas, n: String, center: Vector2) -> void :
	var info: Dictionary = a.info(n)
	var fr: int = int(FxLayer.vt * float(info["fps"])) % int(info["frames"])
	_spr(a, n, fr, center)



func _outlined(a: SpriteAtlas, n: String, shadow: String, fr: int, c: Vector2) -> void :
	var info: Dictionary = a.info(shadow)
	var r: Rect2 = a.rect(shadow, fr)
	var tl: Vector2 = c - Vector2(float(info["ax"]), float(info["ay"]))
	var dark: = Color(0.35, 0.38, 0.5)
	for o: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_texture_rect_region(a.texture, Rect2(tl + o, r.size), r, dark)
	_spr(a, n, fr, c)



func _brackets(c: Vector2, r: int = 8) -> void :
	var col: Color = Palette.c("amber")
	var x0: float = c.x - r
	var y0: float = c.y - r
	var x1: float = c.x + r - 1
	var y1: float = c.y + r - 1
	for p: Vector2 in [Vector2(x0, y0), Vector2(x1, y0), Vector2(x0, y1), Vector2(x1, y1)]:
		var sx: float = 1.0 if p.x == x0 else -1.0
		var sy: float = 1.0 if p.y == y0 else -1.0
		draw_rect(Rect2(p.x, p.y, 1, 1), col)
		draw_rect(Rect2(p.x + sx, p.y, 1, 1), col)
		draw_rect(Rect2(p.x, p.y + sy, 1, 1), col)




func _bar(x0: int, y0: int, w: int, frac: float, flash: int, col: String = "amber") -> void :
	draw_rect(Rect2(x0, y0, w, 3), Palette.c("ui_rubber"))
	var inner: int = w - 2
	if flash >= 0:
		draw_rect(Rect2(x0 + 1, y0 + 1, inner, 1), Palette.c("amber") if flash == 0 else Palette.c("white"))
		return
	draw_rect(Rect2(x0 + 1, y0 + 1, inner, 1), Palette.c("ui_steel_dark"))
	var fill: int = int(floor(clampf(frac, 0.0, 1.0) * inner))
	if fill > 0:
		draw_rect(Rect2(x0 + 1, y0 + 1, fill, 1), Palette.c(col))
		draw_rect(Rect2(x0 + fill, y0 + 1, 1, 1), Palette.c("window_light"))


func _bar_over(f: Facility, frac: float, flash: int, col: String = "amber") -> void :
	if f.main_obj < 0:
		return
	var o: Vector2 = gw.obj_origin(f.main_obj)
	if f.kind == Facility.Kind.TEL:
		o.y += 12.0
	var sw: int = int(gw.spr_rect[gw.obj_spr[f.main_obj]].size.x)
	var w: int = clampi(sw, 12, 32)
	_bar(int(o.x) + (sw - w) / 2, int(o.y) - 6, w, frac, flash, col)





func _cranes(mil: Military) -> void :
	var a: SpriteAtlas = gw.atlas_crane
	if a == null or not a.has("crane_s"):
		return
	for f: Facility in mil.facilities:
		if f.restore_t <= 0.0 or f.parent != null or f.main_obj < 0 or f.is_line() or not _see_fac(f):
			continue
		var sz: = Vector2(f.size * GameWorld.CELL)
		var big: float = maxf(sz.x, sz.y)
		var n: String = "crane_s" if big < 24.0 else ("crane_m" if big < 40.0 else "crane_l")
		var info: Dictionary = a.info(n)
		var fr: int = (int(FxLayer.vt * float(info["fps"])) + f.id * 7) % int(info["frames"])
		var foot: Vector2 = f.origin_px() + Vector2(clampf(roundf(sz.x * 0.18), 3.0, 10.0), sz.y - 2.0)
		_spr(a, n, fr, foot)


func _bars(mil: Military) -> void :
	for f: Facility in mil.facilities:
		if not _see_fac(f):
			continue
		if f.restore_t > 0.0:

			var tot: float = float(Military.CRIT_RESTORE[f.kind]) if mil.constructing.has(f.id) and Military.CRIT_RESTORE.has(f.kind) else mil.restore_time(f)
			_bar_over(f, 1.0 - f.restore_t / maxf(f.restore_t, tot), -1, "grass_light")
			continue
		if not f.craters.is_empty():
			var ro: Vector2 = gw.obj_origin(f.main_obj)
			var rw: int = 64 if f.kind == Facility.Kind.DP_RUNWAY else 120
			_bar(int(ro.x) + rw / 2 - 16, int(ro.y) - 6, 32, 1.0 - f.repair_t / Military.RUNWAY_REPAIR, -1)
			continue
		if not mil.alive(f):
			continue
		if f.kind == Facility.Kind.DRONE_FACTORY or f.kind == Facility.Kind.MISSILE_FACTORY:
			var flashing: bool = gw.game_time < f.flash_until
			if not f.producing and not flashing:
				continue
			var flash: int = -1
			if flashing:
				flash = int((f.flash_until - gw.game_time) / 0.08) % 2
			_bar_over(f, f.prod_t / mil.prod_time_of(f), flash)
		elif f.kind == Facility.Kind.TEL and f.reload_t > 0.0:
			_bar_over(f, 1.0 - f.reload_t / Military.TEL_RELOAD, -1)



func _ground_units(z: float) -> void :
	var a7: SpriteAtlas = gw.atlas7
	var a3: SpriteAtlas = atlas314()
	var ta: SpriteAtlas = a3 if a3 != null and a3.has("truck") else a7
	for t: Dictionary in gw.econ.trucks:
		var tp: Vector2 = (t["pos"] as Vector2).round()
		if not _see(int(t.get("from", -1)), tp):
			continue
		var tn: String = "truck"
		if ta != a7 and VfxTurret.school(gw.country_by_id(int(t.get("from", -1)))) == "b" and ta.has("truck_tan"):
			tn = "truck_tan"

		var ti: Dictionary = ta.info(tn)
		var tr: Rect2 = ta.rect(tn, int(t["frame"]))
		var ttl: Vector2 = tp - Vector2(float(ti["ax"]), float(ti["ay"]))
		CD.begin(gw, int(ttl.x) - 1, int(tr.size.x) + 3, int(ttl.y + tr.size.y) - 1)
		var si: Dictionary = ta.info(tn + "_shadow")
		var sr: Rect2 = ta.rect(tn + "_shadow", int(t["frame"]))
		CD.blit(self, ta.texture, Rect2(tp + Vector2(1, 1) - Vector2(float(si["ax"]), float(si["ay"])), sr.size), sr, _km)
		CD.blit(self, ta.texture, Rect2(ttl, tr.size), tr, _km)
		CD.end()
	var sel: Object = gw.selected_drone()
	for i in _nv:
		var u: Unit = _vu[i]
		var p: Vector2 = u.pos.round()
		if u.type == Unit.Type.POLICE:
			draw_set_transform(p, u.heading, Vector2.ONE)
			draw_rect(Rect2(-5, -3, 11, 7), Color("17212e"))
			draw_rect(Rect2(-4, -2, 9, 5), Color("e4e7db"))
			draw_rect(Rect2(-1, -2, 3, 5), Color("345580"))
			draw_rect(Rect2(-1, -2, 1, 2), Color("ed5745"))
			draw_rect(Rect2(1, -2, 1, 2), Color("4c8fe5"))
			draw_set_transform(Vector2.ZERO)
			continue
		_unit_sprite(u)
		var ua: SpriteAtlas = _sa
		var n: String = _sn
		if u.dug and not u.entrenched:

			draw_rect(Rect2(p + Vector2(-4, 1), Vector2(8, 3)), Palette.c("earth") * _km)
			draw_rect(Rect2(p + Vector2(-3, 2), Vector2(6, 2)), Palette.c("earth_dark") * _km)
			draw_rect(Rect2(p + Vector2(-4, 4), Vector2(8, 1)), Palette.c("sand_dark") * _km)
		if not u.entrenched and not u.dug:
			_spr(ua, n + "_shadow", u.frame, p + Vector2(1, 1), _km)
		_spr(ua, n, u.frame, p, _km)

		var oc: Country = gw.country_by_id(u.country_id)

		var my: float = 7.0 if _big == 2 else (6.0 if _big == 1 and u.type == Unit.Type.ARTY else 5.0)
		if oc != null:
			var mw: float = (6.0 if _big == 2 else 4.0) if u.type == Unit.Type.TANK else (4.0 if _big == 2 else 3.0)
			draw_rect(Rect2(p + Vector2( - floorf(mw * 0.5), my), Vector2(mw, 1)), (Palette.c("amber") if oc == gw.player else oc.color_light) * _km)
		if z >= 1.0:

			if u.hp < u.max_hp:
				var w: int = (10 if _big == 2 else 8) if u.type == Unit.Type.TANK else (8 if _big == 2 else 6)
				var by: float = -11.0 if _big == 2 else -8.0
				draw_rect(Rect2(p + Vector2( - w / 2, by), Vector2(w, 1)), Palette.c("ui_rubber") * _km)
				draw_rect(Rect2(p + Vector2( - w / 2, by), Vector2(maxf(1.0, w * u.hp / u.max_hp), 1)), (oc.color_light if oc != null else Color.WHITE) * _km)
		if u == sel and not night_pass:
			_brackets(p, 9 if _big == 2 else 7)
	var a6: SpriteAtlas = gw.atlas6
	for f: Facility in gw.mil.facilities:
		if f.kind != Facility.Kind.AD_SPAAG or f.main_obj < 0 or not gw.mil.alive(f) or not _see_fac(f):
			continue
		var info: Dictionary = a6.info("ad_spaag_hull")
		var tc: Vector2 = gw.obj_origin(f.main_obj) + Vector2(float(info["turret"][0]), float(info["turret"][1]))
		_spr(a6, "ad_spaag_turret", posmod(roundi(rad_to_deg(f.turret) / 22.5), 16), tc.round(), _km)



static func atlas314() -> SpriteAtlas:
	if not _u314_tried:
		_u314_tried = true
		var a: = SpriteAtlas.load_atlas("res://assets/sprites/atlas_units314.png", "res://assets/sprites/atlas_units314.json", true)
		_u314 = a if a.has("tank_a_L") else null
	return _u314




func _u314_name(u: Unit) -> String:
	match u.type:
		Unit.Type.TANK:
			return "tank_b_L" if VfxTurret.school(gw.country_by_id(u.country_id)) == "b" else "tank_a_L"
		Unit.Type.IFV:
			return "ifv_b_L" if VfxTurret.school(gw.country_by_id(u.country_id)) == "b" else "ifv_a_L"
		Unit.Type.ARTY:
			return "howitzer_tan" if VfxTurret.school(gw.country_by_id(u.country_id)) == "b" else "howitzer"
		Unit.Type.MLRS:
			var mn: String = "mlrs_fire" if u.salvo > 0 else "mlrs"
			return mn + "_tan" if VfxTurret.school(gw.country_by_id(u.country_id)) == "b" else mn
		Unit.Type.INFANTRY:
			return "sq9_rpg" if u.id % 2 == 0 else "sq9_infantry"
	return String(_SQ9.get(u.type, ""))



func _unit_sprite(u: Unit) -> void :
	var a3: SpriteAtlas = atlas314()
	if a3 != null:
		var k3: String = _u314_name(u)
		if k3 != "" and a3.has(k3):
			_sa = a3
			_sn = k3
			_big = 2 if (u.type == Unit.Type.TANK or u.type == Unit.Type.IFV or u.type == Unit.Type.MLRS) else 1
			return
	_big = 0
	_sa = gw.atlas7
	_sn = "tank"
	if u.type == Unit.Type.INFANTRY:
		_sn = "infantry"
		if u.id % 2 == 0 and gw.atlas8.has("rpg_squad"):
			_sa = gw.atlas8
			_sn = "rpg_squad"
	elif u.type == Unit.Type.ATGM:
		_sa = gw.atlas8
		_sn = "atgm_team"
	elif u.type >= Unit.Type.ASSAULT:

		_sn = String(Army.SPEC[u.type]["sprite"])
		if gw.atlas10.has(_sn):
			_sa = gw.atlas10
			if u.type == Unit.Type.MLRS and u.salvo > 0 and gw.atlas10.has("mlrs_fire"):
				_sn = "mlrs_fire"
		else:
			_sn = "tank" if u.vehicle() else "infantry"






func _pre_frame() -> bool:
	var cam: MapCamera = gw.camera
	if cam == null or gw.army == null:
		return false
	var z: float = cam.zoom.x
	var want: bool = false
	if night_pass:
		var nf: float = gw.night.factor if gw.night != null else 0.0
		_km = Color(1, 1, 1, NIGHT_BOOST * nf)
		_sync_border(nf)
		if absf(nf - _last_nf) > 0.01:
			_last_nf = nf
			want = true
	if z != _last_z:
		_last_z = z
		want = true
	_nv = 0
	if z < 0.5 and not night_pass:
		return want
	var half: Vector2 = cam.view_size() * 0.5 / z
	var view: = Rect2(cam.position - half, half * 2.0).grow(24.0 if not night_pass else half.x * 0.5)
	var hd: Variant = gw.get("hold")
	for u: Unit in gw.army.units:
		if not u.alive() or u.type == Unit.Type.FPV or not view.has_point(u.pos) or not _see(u.country_id, u.pos):
			continue
		if hd != null and hd.inside(u):
			continue
		if _nv >= _vu.size():
			_vu.resize(_vu.size() * 2 + 32)
		_vu[_nv] = u
		_nv += 1
	if night_pass:
		_badge_t -= get_process_delta_time()
		if _badge_t <= 0.0 or want:
			_badge_t = BADGE_DT
			_cluster(z)
			want = want or z < BADGE_ZOOM
	return want




func _cluster(z: float) -> void :
	var rr: float = BADGE_R / maxf(z, 0.05)
	var r2: float = rr * rr
	var sa: Facility = _sel_army()
	_nb = 0
	_sk.resize(_pn)
	_sk.fill(-1)
	for i in _nv:
		var u: Unit = _vu[i]
		var k: int = -1
		var sj: int = -1
		var sd: float = r2
		for s0 in _pn:
			if _pcc[s0] == u.country_id:
				var sx: float = u.pos.x - _pcx[s0]
				var sy: float = u.pos.y - _pcy[s0]
				if sx * sx + sy * sy <= sd:
					sd = sx * sx + sy * sy
					sj = s0
		if sj >= 0:
			k = _sk[sj]
		for j in (0 if k >= 0 or sj >= 0 else _nb):
			if _bc[j] == u.country_id:
				var dx: float = u.pos.x - _bx[j] / float(_bn[j])
				var dy: float = u.pos.y - _by[j] / float(_bn[j])
				if dx * dx + dy * dy <= r2:
					k = j
					break
		if k < 0:
			if _nb >= _bx.size():
				var ns: int = _bx.size() * 2 + 16
				_bx.resize(ns)
				_by.resize(ns)
				_btop.resize(ns)
				_bn.resize(ns)
				_bc.resize(ns)
				_bsel.resize(ns)
				_bgr.resize(ns)
			k = _nb
			_nb += 1
			_bx[k] = 0.0
			_by[k] = 0.0
			_bn[k] = 0
			_bc[k] = u.country_id
			_btop[k] = u.pos.y
			_bsel[k] = 0
			_bgr[k] = 0
			if sj >= 0:
				_sk[sj] = k
		_bx[k] += u.pos.x
		_by[k] += u.pos.y
		_bn[k] += 1
		_btop[k] = minf(_btop[k], u.pos.y)
		if sa != null and u.home == sa:
			_bsel[k] = 1
		if u.home != null and u.home.group_id >= 0 and u.country_id == (gw.player.id if gw.player != null else -1):
			_bgr[k] += 1
	_pn = _nb
	_pcx.resize(_nb)
	_pcy.resize(_nb)
	_pcc.resize(_nb)
	for j3 in _nb:
		_pcx[j3] = _bx[j3] / float(_bn[j3])
		_pcy[j3] = _by[j3] / float(_bn[j3])
		_pcc[j3] = _bc[j3]
	if gw.vfx == null:
		return
	var pid: int = gw.player.id if gw.player != null else -1
	_vpts.resize(_nb)
	for j2 in _nb:
		_vpts[j2] = Vector4(_bx[j2] / float(_bn[j2]), _by[j2] / float(_bn[j2]), rr, 1.0 if _bc[j2] == pid else 0.0)
	gw.vfx.army_pts = _vpts



func _draw_outline() -> void :
	if gw == null or gw.camera == null or _nv == 0 or gw.camera.zoom.x < 0.5:
		return
	var ka: float = _km.a
	if ka <= 0.02:
		return
	var plate: = Color(PLATE, PLATE.a * ka)
	for i in _nv:
		var u: Unit = _vu[i]
		if u.entrenched:
			continue
		var p: Vector2 = u.pos.round()
		var hw: float = 6.0 if u.vehicle() else 4.0
		var y0: float = p.y + (3.0 if u.vehicle() else 1.0)
		_outline.draw_rect(Rect2(p.x - hw + 1.0, y0, hw * 2.0 - 2.0, 4.0), plate)
		_outline.draw_rect(Rect2(p.x - hw, y0 + 1.0, hw * 2.0, 2.0), plate)
	for i2 in _nv:
		var u2: Unit = _vu[i2]
		if u2.type == Unit.Type.POLICE:
			continue
		var oc: Country = gw.country_by_id(u2.country_id)
		if oc == null:
			continue
		_unit_sprite(u2)
		var info: Dictionary = _sa.info(_sn)
		var r: Rect2 = _sa.rect(_sn, u2.frame)
		var tl: Vector2 = u2.pos.round() - Vector2(float(info["ax"]), float(info["ay"]))
		var col: = Color(oc.color_light, ka)
		for o: Vector2 in OUTLINE_OFFS:
			_outline.draw_texture_rect_region(_sa.texture, Rect2(tl + o, r.size), r, col)




func _draw_badges(z: float) -> void :
	MD.begin("badge")
	if z >= BADGE_ZOOM or _nb == 0:
		return
	var font: Font = UiKit.f_title if UiKit.f_title != null else ThemeDB.fallback_font
	var k: float = 1.0 / maxf(z, 0.05)
	var far: bool = z < 0.5
	var ba: float = clampf((BADGE_ZOOM - z) / 0.15, 0.0, 1.0)
	var dark: Color = Palette.c("outline")
	var txt_col: = Color(0.96, 0.95, 0.9, ba)
	for j in _nb:
		if far and _bsel[j] == 1:
			continue
		if MD.pennants_on and _bgr[j] * 2 >= _bn[j]:
			continue
		var c: Country = gw.country_by_id(_bc[j])
		if c == null:
			continue
		var n: int = _bn[j]
		var cx: float = _bx[j] / float(n)
		var cy: float = _by[j] / float(n) if far else _btop[j] - 6.0
		var txt: String = str(n)
		var tw: float = roundf(font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x)
		var w: float = tw + 14.0
		var h: float = 12.0
		var r: = Rect2( - roundf(w * 0.5), - h * 0.5 if far else - h - 3.0, w, h)
		var col: Color = c.color_light
		var bsr: = Rect2(gw.camera.world_to_screen(Vector2(cx, cy)) + r.position, r.size)
		if MD.kept(bsr):
			continue
		MD.note("badge", bsr)
		var ba2: float = ba * (MD.QUIET_A if gw.player == null or _bc[j] != gw.player.id else 1.0)
		txt_col.a = ba2
		draw_set_transform(Vector2(cx, cy), 0.0, Vector2(k, k))
		draw_rect(r.grow(1.0), Color(dark, 0.95 * ba2))
		draw_rect(r, Color(0.06, 0.07, 0.1, 0.9 * ba2))
		draw_rect(Rect2(r.position.x + 2.0, r.position.y + 2.0, 7.0, h - 4.0), Color(col, ba2))
		draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), Color(col, ba2))
		if not far:
			draw_rect(Rect2(-2.0, r.end.y + 1.0, 5.0, 1.0), Color(dark, 0.95 * ba2))
			draw_rect(Rect2(-1.0, r.end.y + 1.0, 3.0, 1.0), Color(col, ba2))
			draw_rect(Rect2(0.0, r.end.y + 2.0, 1.0, 1.0), Color(col, ba2))
		draw_string(font, Vector2(r.position.x + 11.0, r.end.y - 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, txt_col)
	draw_set_transform(Vector2.ZERO)




func _sync_border(nf: float) -> void :
	var tb: Sprite2D = gw.territory_border
	if tb == null or not (tb.material is ShaderMaterial) or gw.night == null:
		return
	var t: Color = gw.night.grade.lerp(NightLayer.NIGHT_TINT, nf)
	var comp: = Vector3(1.0, 1.0, 1.0).lerp(Vector3(1.0 / maxf(t.r, 0.05), 1.0 / maxf(t.g, 0.05), 1.0 / maxf(t.b, 0.05)), BORDER_NIGHT)
	if comp.is_equal_approx(_comp):
		return
	_comp = comp
	var m: ShaderMaterial = tb.material
	m.set_shader_parameter("night_comp", comp)
	m.set_shader_parameter("night_k", nf)




func _army_air() -> void :
	var a10: SpriteAtlas = gw.atlas10
	var af: Army.ArmyFire = gw.army.fire
	for d: Unit in af.recon:
		if not d.alive() or not _see_air(d.country_id, d.pos):
			continue
		var dp: Vector2 = d.pos.round()
		var ra: SpriteAtlas = atlas314()
		if ra != null and ra.has("recon_drone") and int(ra.info("recon_drone").get("frames", 0)) >= 32:

			var rk: int = posmod(roundi(rad_to_deg(d.heading) / 22.5), 16)
			_spr(ra, "recon_drone_shadow", rk, dp + Vector2(6, 6), Color(1, 1, 1, 0.4))
			_spr(ra, "recon_drone", rk * 2 + int(FxLayer.vt * 14.0 + d.id) % 2, dp)
		elif a10.has("recon_drone"):
			var si: Dictionary = a10.info("recon_drone_shadow")
			draw_texture_rect_region(a10.texture, Rect2(dp + Vector2(6, 6) - Vector2(float(si["ax"]), float(si["ay"])), a10.rect("recon_drone_shadow").size), a10.rect("recon_drone_shadow"), Color(1, 1, 1, 0.4))
			_spr(a10, "recon_drone", int(gw.game_time * 14.0 + d.id) % 2, dp)
		else:
			_spr(gw.atlas7, "fpv_shadow", 0, dp + Vector2(6, 6))
			_spr(gw.atlas7, "fpv", 0, dp)
		if int(gw.game_time * 2.0 + d.id) % 2 == 0:
			draw_rect(Rect2(dp + Vector2(0, -2), Vector2(1, 1)), Palette.c("alert_red"))
	var smoke: = Palette.c("smoke_light")
	var smoke2: = Palette.c("smoke")
	for s: Dictionary in af.shells:
		var sp: Vector2 = af.shell_pos(s).round()
		if not _see(int(s.get("c", -1)), sp):
			continue
		var k: int = int(s["k"])
		if k == 2:
			var pts: PackedVector2Array = s["pts"]
			var n: int = pts.size()
			for i in n:
				var age: float = float(n - i) / float(maxi(1, n))
				var c: Color = smoke if age < 0.5 else smoke2
				c.a = 0.85 * (1.0 - age * 0.8)
				var w: float = 2.0 + floorf(age * 2.0)
				draw_rect(Rect2(pts[i].round() - Vector2(w * 0.5, w * 0.5), Vector2(w, w)), c)
			var tt: float = clampf(float(s["t"]) / float(s["dur"]), 0.0, 1.0)
			var nxt: Dictionary = s.duplicate()
			nxt["t"] = minf(float(s["dur"]), float(s["t"]) + 0.03)
			var hd: float = (af.shell_pos(nxt) - af.shell_pos(s)).angle()
			if a10.has("mlrs_rocket"):
				_spr(a10, "mlrs_rocket", posmod(roundi(rad_to_deg(hd) / 22.5), 16), sp)
			draw_rect(Rect2(sp - Vector2.from_angle(hd).round() * 3.0, Vector2(1, 1)), Palette.c("fire_yellow"))
			if tt < 0.15:
				draw_rect(Rect2(sp - Vector2(1, 1), Vector2(2, 2)), Palette.c("fire_core"))
		elif k == 0:
			draw_rect(Rect2(sp, Vector2(1, 1)), Palette.c("ui_rubber"))
			draw_rect(Rect2(sp + Vector2(0, -1), Vector2(1, 1)), Palette.c("ui_steel_light"))
		else:

			var kk: float = float(s["t"]) / float(s["dur"])
			if kk < 0.2 or kk > 0.85:
				var dir: Vector2 = ((s["to"] as Vector2) - (s["from"] as Vector2)).normalized()
				draw_line(sp - dir * 3.0, sp, Palette.c("fire_yellow"), 1.0)
	for g: Dictionary in gw.army.grenades:
		if not _see(-1, g["to"]):
			continue
		var gk: float = clampf(float(g["t"]) / float(g["dur"]), 0.0, 1.0)
		var gp: Vector2 = ((g["from"] as Vector2).lerp(g["to"], gk) + Vector2(0, -10.0 * 4.0 * gk * (1.0 - gk))).round()
		draw_rect(Rect2(gp, Vector2(1, 1)), Palette.c("ui_rubber"))
	for f: Dictionary in af.flares:
		var st: Array = af.flare_state(f)
		var fp: Vector2 = (st[0] as Vector2).round()
		var b: float = float(st[2])
		var col: Color = Palette.c("white") if int(st[3]) == 0 else Palette.c("alert_red")
		var halo: Color = Palette.c("fire_core") if int(st[3]) == 0 else Palette.c("fire_orange")
		halo.a = 0.35 * b
		draw_circle(fp + Vector2(0.5, 0.5), 3.0, halo)
		col.a = b
		draw_rect(Rect2(fp, Vector2(1, 1)), col)

		var tc: Color = smoke
		tc.a = 0.4 * b
		draw_line(fp + Vector2(0.5, 1.0), fp + Vector2(0.5, 7.0), tc, 1.0)





func _sel_army() -> Facility:
	var sa: Variant = gw.get("selected_army")
	return sa as Facility if sa is Facility else null





func _army_sel(z: float, _unused: bool) -> void :
	var sa: Facility = _sel_army()
	var pts: = PackedVector2Array()
	for u: Unit in gw.army.units:
		if u.home == sa and u.alive() and u.type != Unit.Type.FPV and _see(u.country_id, u.pos):
			pts.append(u.pos.round())
	if pts.is_empty():
		return
	var c: Country = gw.country_by_id(sa.country_id)
	var col: Color = c.color_light if c != null else Palette.c("amber")
	var dark: Color = Palette.c("outline")
	var cen: = Vector2.ZERO
	for p: Vector2 in pts:
		cen += p
	cen /= float(pts.size())
	var k: float = 1.0 / maxf(z, 0.05)
	var no: int = int(sa.get("army_no")) if sa.get("army_no") != null else 0
	var txt: String = "№%d" % no if no > 0 else Loc.t("АРМИЯ")
	if z < 0.5:
		_army_pin(cen, k, col, "%s · %d" % [txt, pts.size()])
		return

	var top: float = INF
	for p: Vector2 in pts:
		top = minf(top, p.y)
	if pts.size() >= 3:
		var hull: PackedVector2Array = Geometry2D.convex_hull(pts)
		var grown: Array = Geometry2D.offset_polygon(hull, 9.0, Geometry2D.JOIN_ROUND)
		if grown.size() == 1:
			var poly: PackedVector2Array = grown[0]
			var bb: = Rect2(poly[0], Vector2.ZERO)
			for q: Vector2 in poly:
				bb = bb.expand(q)
			if bb.size.x < 420.0 and bb.size.y < 420.0:
				top = bb.position.y + 9.0
				draw_colored_polygon(poly, Color(col, 0.07))
				var n: int = poly.size()
				for i in n:
					var a: Vector2 = poly[i]
					var b: Vector2 = poly[(i + 1) % n]
					var L: float = a.distance_to(b)
					var s: float = 0.0
					while s < L:
						var e: float = minf(L, s + 4.0 * k)
						draw_line(a.lerp(b, s / L), a.lerp(b, e / L), Color(col, 0.55), 1.0 * k)
						s += 7.0 * k

	var hd: Variant = gw.get("hold")
	var pin: Dictionary = {}
	if hd != null:
		for u2: Unit in gw.army.units:
			if u2.home == sa and u2.alive() and hd.inside(u2):
				pin[u2.pos.round()] = true
	for p: Vector2 in pts:
		if pin.has(p):
			continue
		draw_set_transform(p + Vector2(0, 3), 0.0, Vector2(1.0, 0.55))
		draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 16, dark, 2.5)
		draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 16, col, 1.0)
		draw_set_transform(Vector2.ZERO)

	_army_tag(Vector2(cen.x, top - 12.0), k, col, txt, 9)


func _army_tag(p: Vector2, k: float, col: Color, txt: String, fs: int) -> void :
	var font: Font = UiKit.f_title if UiKit.f_title != null else ThemeDB.fallback_font
	var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_set_transform(p, 0.0, Vector2(k, k))
	var r: = Rect2( - tw * 0.5 - 4.0, - fs - 1.0, tw + 8.0, fs + 5.0)
	draw_rect(r.grow(1.0), Palette.c("outline"))
	draw_rect(r, Color(col.darkened(0.55), 0.92))
	draw_rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x, 2.0), col)
	draw_string(font, Vector2( - tw * 0.5, 0.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f2efe6"))
	draw_set_transform(Vector2.ZERO)



func _army_pin(p: Vector2, k: float, col: Color, txt: String) -> void :
	draw_set_transform(p, 0.0, Vector2(k, k))
	draw_circle(Vector2.ZERO, 4.0, Palette.c("outline"))
	draw_circle(Vector2.ZERO, 2.5, col)
	for i in 5:
		draw_rect(Rect2(-5 + i, -9 + i, 10 - 2 * i, 1), Palette.c("outline") if i == 4 else col)
	draw_set_transform(Vector2.ZERO)
	_army_tag(p + Vector2(0, -10.0 * k), k, col, txt, 11)








const FLARE_ANG: Array = [0.5, -0.5, 0.9, -0.9, 1.3, -1.3, 1.7, -1.7]
const FLARE_LIFE: float = 1.5



func _flare_at(p0: Vector2, dir: Vector2, sp: float, t: float) -> Vector2:
	return p0 + dir * sp * (1.0 - exp(-2.6 * t)) / 2.6 + Vector2(0.0, 7.0 * t * t)


func _flares() -> void :
	var cy: Color = Palette.c("fire_yellow")
	var co: Color = Palette.c("fire_orange")
	var cs: Color = Palette.c("smoke_light")
	for e: Array in Air.flare_fx:
		var age: float = floorf((FxLayer.vt - float(e[2])) * 15.0) / 15.0
		if age < 0.0 or age > FLARE_LIFE + 0.45 or not _see(-1, e[0]):
			continue
		var p0: Vector2 = e[0]
		var back: float = float(e[1]) + PI
		if age < 0.2:
			draw_circle(p0.round(), 9.0 - age * 30.0, Color(cy, 0.35))
			draw_circle(p0.round(), 5.0 - age * 15.0, Color(Color.WHITE, 0.6))
			draw_rect(Rect2(p0.round() - Vector2(1, 1), Vector2(3, 3)), Color.WHITE)
		for i in FLARE_ANG.size():
			var dir: Vector2 = Vector2.from_angle(back + float(FLARE_ANG[i]))
			var sp: float = 58.0 - 5.0 * float(i / 2)

			var prev: Vector2 = Vector2.INF
			for tk in 9:
				var a2: float = minf(age, FLARE_LIFE) - 0.07 * float(tk)
				if a2 < 0.0:
					break
				var q: Vector2 = _flare_at(p0, dir, sp, a2).round()
				var fade: float = clampf(1.0 - (age - a2) / 0.9, 0.0, 1.0) * (1.0 - float(tk) / 10.0)
				if prev.is_finite() and fade > 0.0:
					var sc: Color = cs
					sc.a = 0.6 * fade
					draw_line(prev + Vector2(0.5, 0.5), q + Vector2(0.5, 0.5), sc, 1.0 if tk < 3 else 2.0)
				prev = q
			if age > FLARE_LIFE:
				continue
			var qc: Vector2 = _flare_at(p0, dir, sp, age).round()
			var u: float = age / FLARE_LIFE
			var fl: bool = (int(age * 15.0) + i) % 3 == 0
			if u < 0.55:
				draw_circle(qc + Vector2(0.5, 0.5), 5.5 if fl else 4.5, Color(cy, 0.16))
				draw_rect(Rect2(qc - Vector2(2, 2), Vector2(5, 5)), Color(cy, 0.3 if fl else 0.45))
				draw_rect(Rect2(qc - Vector2(1, 1), Vector2(3, 3)), Color(cy, 0.85))
				draw_rect(Rect2(qc, Vector2(2, 2)) if i < 4 else Rect2(qc, Vector2.ONE), Color.WHITE)
			elif u < 0.85:
				draw_rect(Rect2(qc - Vector2(1, 0), Vector2(3, 1)), Color(co, 0.7))
				draw_rect(Rect2(qc - Vector2(0, 1), Vector2(1, 3)), Color(co, 0.7))
				draw_rect(Rect2(qc, Vector2.ONE), Color.WHITE if fl else cy)
			else:
				draw_rect(Rect2(qc, Vector2.ONE), Color(co, 1.0 - (u - 0.85) / 0.15))


func _see(cid: int, p: Vector2) -> bool:
	return gw.vision == null or gw.vision.shows(cid, p)



static var _a316: SpriteAtlas = null
static var _a316_tried: bool = false


static func atlas316() -> SpriteAtlas:
	if not _a316_tried:
		_a316_tried = true
		if ResourceLoader.exists("res://assets/sprites/atlas_air316.png"):
			var a: = SpriteAtlas.load_atlas("res://assets/sprites/atlas_air316.png", "res://assets/sprites/atlas_air316.json", true)
			_a316 = a if a.has("attack") and a.has("attack_shadow") else null
	return _a316


func _ac_atlas(ac: Aircraft) -> SpriteAtlas:
	if ac.type == Aircraft.Type.ATTACK and atlas316() != null:
		return _a316
	return gw.atlas5


func _ac_name(ac: Aircraft) -> String:
	if ac.type == Aircraft.Type.ATTACK:
		if atlas316() == null:
			return "fighter"
		return "attack" if ac.kab > 0 or not _a316.has("attack_nokab") else "attack_nokab"
	return String(Air.SPEC[ac.type]["sprite"])


func _ac_shadow(ac: Aircraft) -> String:
	if ac.type == Aircraft.Type.ATTACK:
		return "attack_shadow" if atlas316() != null else "fighter_shadow"
	return String(Air.SPEC[ac.type]["sprite"]) + "_shadow"



func _nars() -> void :
	var nl: Array = gw.mil.air.nars
	if nl.is_empty():
		return
	var a: SpriteAtlas = atlas316()
	var smoke: Color = Palette.c("white")
	for r: Dictionary in nl:
		var p: Vector2 = r["p"]
		if not _see_air(int(r["c"]), p):
			continue
		var h: float = float(r["h"])
		var dir: Vector2 = Vector2.from_angle(h)
		for i in 4:
			var c: Color = smoke
			c.a = 0.55 - i * 0.12
			draw_rect(Rect2((p - dir * (4.0 + i * 3.0)).round() - Vector2(0.5, 0.5), Vector2(2, 2) if i < 2 else Vector2(1, 1)), c)

		var tail: Vector2 = (p - dir * 3.0).round()
		draw_rect(Rect2(tail - Vector2(1, 1), Vector2(3, 3)), Color(Palette.c("fire_orange"), 0.55 if (int(FxLayer.vt * 20.0) % 2) == 0 else 0.35))
		draw_rect(Rect2(tail, Vector2.ONE), Palette.c("fire_yellow"))
		if a != null and a.has("nar"):
			_spr(a, "nar", posmod(roundi(rad_to_deg(h) / 22.5), 16), p.round())
		else:
			draw_line(p - dir * 2.0, p + dir * 1.5, Palette.c("fire_yellow"), 1.0)



func _see_air(cid: int, p: Vector2) -> bool:
	return gw.vision == null or gw.vision.shows_air(cid, p)


func _see_fac(f: Facility) -> bool:
	return gw.vision == null or gw.vision.fac_shown(f)



func _kab_shadows() -> void :
	var col: Color = Palette.c("black")
	col.a = 0.4
	for d: Drone in gw.mil.air.kabs:
		if d.state == Drone.State.DONE or not _see_air(d.country_id, d.pos):
			continue
		var sp: Vector2 = (d.pos + Vector2(d.h, d.h)).round() + Vector2(0.5, 0.5)
		var dir: Vector2 = Vector2.from_angle(d.heading)
		draw_line(sp - dir * 2.5, sp + dir * 2.5, col, 2.0)




func _kab_air() -> void :
	var air_: Air = gw.mil.air
	var tc: Color = Palette.c("white")
	for i in air_.kab_trail.size():
		var age: float = gw.game_time - air_.kab_trail_t[i]
		var c: Color = tc
		c.a = clampf(0.75 * (1.0 - age / Air.KAB_TRAIL_LIFE), 0.0, 0.75)
		if not _see_air(-1, air_.kab_trail[i]):
			continue
		var sz: float = 2.0 if age < Air.KAB_TRAIL_LIFE * 0.5 else 1.0
		draw_rect(Rect2(air_.kab_trail[i] - Vector2(sz * 0.5, sz * 0.5), Vector2(sz, sz)), c)
	var body: Color = Palette.c("ui_steel_light")
	var nose: Color = Palette.c("fire_yellow")
	var out: Color = Palette.c("outline")
	var ka: SpriteAtlas = atlas316()
	for d: Drone in air_.kabs:
		if d.state == Drone.State.DONE or not _see_air(d.country_id, d.pos):
			continue
		if ka != null and ka.has("kab"):
			_spr(ka, "kab", posmod(roundi(rad_to_deg(d.heading) / 22.5), 16), d.pos.round())
			continue
		var p: Vector2 = d.pos.round() + Vector2(0.5, 0.5)
		var dir: Vector2 = Vector2.from_angle(d.heading)
		var nrm: Vector2 = Vector2( - dir.y, dir.x)
		draw_line(p - dir * 2.5 - nrm * 2.0, p - dir * 2.5 + nrm * 2.0, out, 2.0)
		draw_line(p - dir * 3.5, p + dir * 3.5, out, 3.0)
		draw_line(p - dir * 2.5, p + dir * 2.5, body, 1.0)
		draw_line(p + dir * 1.5, p + dir * 2.5, nose, 1.0)
