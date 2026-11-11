class_name VfxAir
extends Node2D










enum {K_SMOKE, K_WISP, K_CHIMNEY, K_STEAM, K_DUST, K_BFLY, K_LEAF, K_POLLEN, K_RIPPLE, K_FISH, K_FIRE, K_BILLOW}

const PUFFS: Array = [3, 5, 7, 9, 11, 13, 16, 20, 24]
const WISPS: Array = [4, 6, 8, 11]

const AMB_MAX: Dictionary = {K_BFLY: [0, 4, 6], K_LEAF: [0, 5, 7], K_POLLEN: [0, 5, 8], K_RIPPLE: [1, 3, 4]}
const FLOCKS_MAX: Array = [1, 2, 3]
const BFLY_COLS: Array = [Color("f4f6f8"), Color("ffe08a"), Color("ff9a3d"), Color("f29ac0"), Color("9ff2f0")]
const LEAF_COLS: Array = [Color("9bc53d"), Color("c8dc5a"), Color("7aad34"), Color("ffc23d"), Color("e8812c")]
const OIL_BASE: = Color(0.16, 0.14, 0.13)
const OIL_TOP: = Color(0.4, 0.38, 0.36)
const ASH_BASE: = Color(0.24, 0.22, 0.21)
const ASH_TOP: = Color(0.7, 0.68, 0.64)
const CHIMNEY_COL: = Color(0.72, 0.7, 0.67)
const STEAM_COL: = Color(0.97, 0.98, 1.0)
const DUST_COL: = Color(0.62, 0.52, 0.38)
const TRAIL_MAX: int = 40
const TRAIL_PTS: int = 36

var vfx: Vfx
var gw: GameWorld

var n: int = 0
var cap: int = 300
var pk: = PackedInt32Array()
var px: = PackedFloat32Array()
var py: = PackedFloat32Array()
var ox: = PackedFloat32Array()
var oy: = PackedFloat32Array()
var vx: = PackedFloat32Array()
var vy: = PackedFloat32Array()
var age: = PackedFloat32Array()
var life: = PackedFloat32Array()
var s0: = PackedFloat32Array()
var s1: = PackedFloat32Array()
var ph: = PackedFloat32Array()
var pc: = PackedColorArray()
var pc2: = PackedColorArray()
var flocks: Array = []
var rings: Array = []
var trails: Dictionary = {}
var emitters: Array = []
var _emit_t: float = 0.0
var _trail_t: float = 0.0
var _bird_t: float = 6.0
var _fish_t: float = 3.0
var _ct: float = 0.0
var _view: Rect2 = Rect2()
var _zoom: float = 1.0
var _r_puff: Array[Rect2] = []
var _r_wisp: Array[Rect2] = []
var _rng: = RandomNumberGenerator.new()
var _drawn: bool = false
var _kc: = PackedInt32Array()
var _pidx: = PackedInt32Array()
var _widx: = PackedInt32Array()
var _seg: = PackedVector2Array()
var _segc: = PackedColorArray()


const SMOKE_CLEAR: float = 0.3
const SMOKE_OLD: float = 0.8
const SMOKE_FAR_COL: = Color(0.78, 0.76, 0.72)
var _clr: = PackedVector3Array()
var _ncl: int = 0


func _ready() -> void :
	gw = vfx.gw
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 190019
	cap = int(Vfx.MAX_PARTS[2])
	pk.resize(cap)
	px.resize(cap)
	py.resize(cap)
	ox.resize(cap)
	oy.resize(cap)
	vx.resize(cap)
	vy.resize(cap)
	age.resize(cap)
	life.resize(cap)
	s0.resize(cap)
	s1.resize(cap)
	ph.resize(cap)
	pc.resize(cap)
	pc2.resize(cap)
	_kc.resize(K_BILLOW + 1)
	_pidx.resize(80)
	_widx.resize(80)
	for dd in 80:
		for i in PUFFS.size():
			if int(PUFFS[i]) <= maxi(dd, 3):
				_pidx[dd] = i
		for i in WISPS.size():
			if int(WISPS[i]) <= maxi(dd, 4):
				_widx[dd] = i
	for d: int in PUFFS:
		_r_puff.append(vfx.atlas.rect("puff_%d" % d) if vfx.has("puff_%d" % d) else Rect2())
	for d: int in WISPS:
		_r_wisp.append(vfx.atlas.rect("wisp_%d" % d) if vfx.has("wisp_%d" % d) else Rect2())


func reset() -> void :
	n = 0
	flocks.clear()
	rings.clear()
	trails.clear()
	emitters.clear()


func view_rect() -> Rect2:
	return _view




func _add(k: int, p: Vector2, v: Vector2, lf: float, a: float, b: float, c: Color, c2: Color) -> int:
	var lim: int = int(Vfx.MAX_PARTS[Vfx.level()])
	if n >= lim:
		return -1
	var i: int = n
	n += 1
	pk[i] = k
	px[i] = p.x
	py[i] = p.y
	ox[i] = 0.0
	oy[i] = 0.0
	vx[i] = v.x
	vy[i] = v.y
	age[i] = 0.0
	life[i] = lf
	s0[i] = a
	s1[i] = b
	ph[i] = _rng.randf() * TAU
	pc[i] = c
	pc2[i] = c2
	return i





func impact(p: Vector2, size: int, water: bool) -> void :
	if not _view.grow(80.0).has_point(p):
		_scare(p, 260.0)
		return
	if _zoom >= 0.75 and size >= 1 and not water:
		rings.append([p, _ct, size, false])
		var cnt: int = [0, 5, 8][size] * (Vfx.level() + 1) / 2
		for k in cnt:
			var ang: float = TAU * float(k) / float(maxi(cnt, 1)) + _rng.randf() * 0.5
			var sp: float = (14.0 if size == 1 else 24.0) * _rng.randf_range(0.8, 1.2)
			_add(K_DUST, p + Vector2.from_angle(ang) * 3.0, Vector2.from_angle(ang) * Vector2(sp, sp * 0.6), _rng.randf_range(1.0, 1.6), 4.0, 9.0 + 3.0 * size, DUST_COL, DUST_COL)
	if size >= 2 and _zoom >= 0.5:
		rings.append([p, _ct, 3, water])
	_scare(p, 260.0)

	if _zoom >= 1.0 and Vfx.level() >= 1 and flocks.size() < int(FLOCKS_MAX[Vfx.level()]) + 1:
		var c: = Vector2i(int(p.x) / 4, int(p.y) / 4)
		for k in 10:
			var q: Vector2i = c + Vector2i(_rng.randi_range(-12, 12), _rng.randi_range(-12, 12))
			if gw.data.inside(q.x, q.y) and gw.tree_at.has(q.y * gw.data.w + q.x):
				var away: Vector2 = (Vector2(q * 4) - p).normalized()
				if away == Vector2.ZERO:
					away = Vector2.RIGHT
				_new_flock(Vector2(q * 4), away * 46.0, _rng.randi_range(5, 8), 2.0, 1.0)
				break





func billow(p: Vector2, cls: int) -> void :
	if _zoom < 0.6 or not _view.grow(40.0).has_point(p):
		return
	var c: int = clampi(cls, 0, 3)
	var cnt: int = maxi(1, [2, 3, 4, 6][c] * (Vfx.level() + 1) / 2)
	var lim: int = int(float(Vfx.MAX_PARTS[Vfx.level()]) * 0.8)
	var dark: bool = c >= 2
	var c0: Color = Color(0.24, 0.22, 0.2, 0.75) if dark else Color(0.5, 0.42, 0.32, 0.7)
	var c1: Color = Color(0.62, 0.6, 0.57, 0.75) if dark else Color(0.72, 0.66, 0.56, 0.7)
	var rr: float = [3.0, 5.0, 8.0, 14.0][c]
	for k in cnt:
		if n >= lim:
			return
		var ang: float = TAU * float(k) / float(cnt) + _rng.randf() * 0.8
		var dir: = Vector2.from_angle(ang)
		var sp: float = [5.0, 7.0, 9.0, 13.0][c] * _rng.randf_range(0.6, 1.2)
		var lf: float = _rng.randf_range(2.2, 3.6) * [0.8, 1.0, 1.2, 1.5][c]
		_add(K_BILLOW, p + dir * rr * _rng.randf() * Vector2(1.0, 0.6), dir * Vector2(sp, sp * 0.6), lf, [4.0, 5.0, 6.0, 8.0][c], [8.0, 11.0, 14.0, 18.0][c] * _rng.randf_range(0.85, 1.15), c0, c1)



func haze(p: Vector2) -> void :
	if _zoom < 0.6 or n >= int(float(Vfx.MAX_PARTS[Vfx.level()]) * 0.7):
		return
	var c0: = Color(0.8, 0.79, 0.74, 0.4)
	var c1: = Color(0.86, 0.85, 0.82, 0.3)
	_add(K_BILLOW, p, Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-1.5, 1.5)), _rng.randf_range(3.0, 4.5), 7.0, _rng.randf_range(15.0, 20.0), c0, c1)



func column_vis(col: Dictionary) -> float:
	var p: Vector2 = col["p"]
	if gw.vision == null or not gw.vision.active() or gw.vision.sees(p):
		return 1.0

	return 1.0 if float(col["burn"]) > gw.game_time or float(col["pow"]) >= 0.6 else 0.0




func _process(delta: float) -> void :
	if gw == null or gw.camera == null or gw.data == null or vfx.tex == null:
		return
	var us: int = Time.get_ticks_usec()
	var cam: MapCamera = gw.camera
	_zoom = cam.zoom.x
	var half: Vector2 = cam.view_size() * 0.5 / _zoom
	_view = Rect2(cam.position - half, half * 2.0)
	var cs: float = FxLayer.cosmetic_scale(gw.time_scale)
	var dt: float = delta * cs
	_ct += dt
	vfx.tick(delta * gw.time_scale)
	if dt > 0.0:
		_columns(dt)
		_chimneys(delta, dt)
		_ambient(dt)
		_birds(dt)
		_contrails(delta, dt)
		_step(dt)
	_clear_pts()
	var busy: bool = n > 0 or not flocks.is_empty() or not rings.is_empty() or not trails.is_empty() or not vfx.columns.is_empty()
	if busy or _drawn:
		queue_redraw()
	_drawn = busy
	Vfx.cost("air", Time.get_ticks_usec() - us)


func _clear_pts() -> void :
	_ncl = 0
	var need: int = vfx.focus_pts.size() + vfx.army_pts.size()
	if need == 0 or vfx.columns.is_empty():
		return
	if _clr.size() < need:
		_clr.resize(need + 8)
	var fr: float = 80.0 / maxf(_zoom, 0.05)
	for fp: Vector2 in vfx.focus_pts:
		_clr[_ncl] = Vector3(fp.x, fp.y, fr)
		_ncl += 1
	var vg: Rect2 = _view.grow(200.0)
	for ap: Vector4 in vfx.army_pts:
		if vg.has_point(Vector2(ap.x, ap.y)):
			_clr[_ncl] = Vector3(ap.x, ap.y, ap.z + 10.0)
			_ncl += 1



func _clear_k(p: Vector2, d: float) -> float:
	var k: float = 1.0
	for i in _ncl:
		var c: Vector3 = _clr[i]
		var r: float = c.z + d * 0.5
		var d2: float = p.distance_squared_to(Vector2(c.x, c.y))
		if d2 < r * r:
			k = minf(k, lerpf(SMOKE_CLEAR, 1.0, d2 / (r * r)))
	return k


func _zb() -> float:
	return clampf(0.8 / _zoom, 1.0, 3.0)



func _columns(dt: float) -> void :
	var t: float = gw.game_time
	var zb: float = _zb()
	var far: bool = _zoom < 0.75

	var demand: float = 0.0
	for col: Dictionary in vfx.columns:
		if _view.grow(300.0 * zb).has_point(col["p"]):
			var pw0: float = float(col["pow"])
			demand += ((1.5 + 1.7 * pw0) * (6.0 + 4.0 * pw0)) if float(col["burn"]) > t else 3.5
	var budget: float = clampf(0.75 * float(Vfx.MAX_PARTS[Vfx.level()]) / maxf(demand, 1.0), 0.25, 1.0)
	for col: Dictionary in vfx.columns:
		var p: Vector2 = col["p"]
		var pw: float = float(col["pow"])
		var reach: float = (110.0 + 90.0 * pw) * zb
		if not _view.grow(reach).has_point(p) and not _view.grow(reach).has_point(p + Vfx.wind * 12.0 - Vector2(0, reach)):
			continue
		var vis: float = column_vis(col)
		if vis <= 0.0:
			continue
		var burning: bool = float(col["burn"]) > t
		var rate: float = (1.5 + 1.7 * pw) if burning else 0.7
		if far:
			rate *= 0.7
		if _zoom >= 3.0:
			rate *= 0.7
		col["acc"] = float(col["acc"]) + rate * dt * budget
		while float(col["acc"]) >= 1.0:
			col["acc"] = float(col["acc"]) - 1.0
			var jit: = Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-2.0, 1.0)) * (1.0 + pw)
			if burning:
				var oil: bool = bool(col["oil"])
				var c0: Color = OIL_BASE if oil else ASH_BASE
				var c1: Color = OIL_TOP if oil else ASH_TOP
				c0.a = vis
				c1.a = vis
				var lf: float = (6.0 + 4.0 * pw) * (1.3 if far else 1.0)
				var si: int = _add(K_SMOKE, p, Vector2(_rng.randf_range(-2.5, 2.5), - (12.0 + 7.0 * pw) * _rng.randf_range(0.85, 1.15)), lf, 6.0 + 4.0 * pw, (17.0 + 12.0 * pw) * _rng.randf_range(0.85, 1.15), c0, c1)
				if si >= 0:
					ox[si] = jit.x
					oy[si] = jit.y
				if far and _rng.randf() < 0.6:
					_add(K_FIRE, p + jit * 0.5, Vector2.ZERO, 0.35, 2.0 * zb, 1.0 * zb, Color(1.0, 0.76, 0.24, vis), Color(0.84, 0.2, 0.12, vis))
			else:
				var cw: = Color(0.62, 0.6, 0.57, 0.8 * vis)
				var wi: int = _add(K_WISP, p, Vector2(0.0, -8.0), 5.0, 3.0, 10.0, cw, cw)
				if wi >= 0:
					ox[wi] = jit.x
					oy[wi] = jit.y



func _chimneys(real_dt: float, dt: float) -> void :
	if _zoom < 0.5:
		emitters.clear()
		return
	_emit_t -= real_dt
	if _emit_t <= 0.0:
		_emit_t = 1.0
		_scan_emitters()
	var lvl: float = 0.5 + 0.5 * float(Vfx.level())
	for e: Array in emitters:
		e[3] = float(e[3]) + float(e[1]) * dt * lvl
		while float(e[3]) >= 1.0:
			e[3] = float(e[3]) - 1.0
			var p: Vector2 = e[0]
			if int(e[2]) == 2:
				_add(K_STEAM, p + Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-1.0, 0.5)), Vector2(Vfx.wind.x * 0.5 + _rng.randf_range(-1.0, 1.0), -6.5 * _rng.randf_range(0.8, 1.2)), 6.0, 5.0, 17.0, STEAM_COL, Color(STEAM_COL.r, STEAM_COL.g, STEAM_COL.b, 0.0))
			elif int(e[2]) == 1:
				_add(K_STEAM, p + Vector2(_rng.randf_range(-1, 1), 0), Vector2(Vfx.wind.x * 0.3, -9.0), 3.0, 4.0, 12.0, STEAM_COL, STEAM_COL)
			else:
				_add(K_CHIMNEY, p + Vector2(_rng.randf_range(-0.5, 0.5), 0), Vector2(Vfx.wind.x * 0.3, -8.0), 4.5, 3.0, 11.0, CHIMNEY_COL, Color(0.86, 0.85, 0.82))


func _scan_emitters() -> void :
	var old: Dictionary = {}
	for e: Array in emitters:
		old[e[0]] = e[3]
	emitters.clear()
	var view: Rect2 = _view.grow(48.0)
	for f: Facility in gw.mil.facilities:
		if f.main_obj < 0 or f.halted or not view.has_point(f.center_px()):
			continue
		if not gw.mil.alive(f) or (gw.vision != null and not gw.vision.fac_shown(f)):
			continue
		if Military.uses_power(f.kind) and not gw.mil.has_power(f):
			continue
		var o: Vector2 = gw.obj_origin(f.main_obj)
		match f.kind:
			Facility.Kind.CIV_FACTORY:
				_emit(old, o + Vector2(25.5, 0), 1.3, 0)
			Facility.Kind.SAWMILL:
				_emit(old, o + Vector2(11.5, 0), 0.7, 0)
			Facility.Kind.NUCLEAR_PLANT:
				for sp: Variant in Nuclear.steam_points(gw, f):
					_emit(old, sp, 2.4, 2)
			Facility.Kind.POWER_PLANT:
				_emit(old, o + Vector2(29.5, 1), 0.9, 0)
				_emit(old, o + Vector2(33.5, 1), 0.9, 0)
			Facility.Kind.REFINERY:
				var c: Country = gw.country_by_id(f.country_id)
				var work: bool = c != null and c.oil > 0
				_emit(old, o + Vector2(9.5, 8), 1.4 if work else 0.4, 1)
				_emit(old, o + Vector2(14.5, 7), 1.0 if work else 0.3, 1)
				_emit(old, o + Vector2(3.5, 5), 0.8 if work else 0.0, 0)
			Facility.Kind.DRONE_FACTORY, Facility.Kind.MISSILE_FACTORY:
				if f.producing:
					_emit(old, o + Vector2(float(f.size.x) * 3.0, 4), 0.6, 1)

	var sid: int = int(gw.spr_index.get("factory", -1))
	if sid >= 0 and _zoom >= 1.0:
		var r: = Rect2i(Vector2i(view.position / 4.0), Vector2i(view.size / 4.0))
		var k: int = 0
		for oc: ObjChunk in gw.objects.chunks_in_rect(r):
			for id in oc.ids:
				if gw.obj_spr[id] == sid and gw.obj_state[id] == 0 and (id >= gw.obj_hidden.size() or gw.obj_hidden[id] == 0):
					var cp: Vector2 = gw.obj_origin(id) + Vector2(4.5, 0)
					if view.has_point(cp):
						_emit(old, cp, 0.6, 0)
						k += 1
						if k >= 12:
							return


func _emit(old: Dictionary, p: Vector2, rate: float, kind: int) -> void :
	if rate > 0.0:
		emitters.append([p, rate, kind, float(old.get(p, _rng.randf()))])



func _ambient(dt: float) -> void :
	var lvl: int = Vfx.level()
	var tries: int = 3
	var cnt: PackedInt32Array = PackedInt32Array()
	cnt.resize(K_BILLOW + 1)
	for i in n:
		cnt[pk[i]] += 1
	if _zoom >= 1.0:
		var want: int = int(AMB_MAX[K_RIPPLE][lvl])
		if cnt[K_RIPPLE] < want and _rng.randf() < dt * 2.0:
			_spawn_ripple()
		_fish_t -= dt
		if _fish_t <= 0.0:
			_fish_t = _rng.randf_range(5.0, 11.0) / float(lvl + 1)
			_spawn_fish()
	if _zoom < 1.99 or lvl == 0:
		return
	for k: int in [K_BFLY, K_LEAF, K_POLLEN]:
		var want2: int = int(AMB_MAX[k][lvl])
		if cnt[k] >= want2:
			continue
		for i in tries:
			if _spawn_amb(k):
				break


func _cell_b(p: Vector2) -> int:
	var c: = Vector2i(int(p.x) >> 2, int(p.y) >> 2)
	if not gw.data.inside(c.x, c.y):
		return -1
	return gw.data.get_biome(c.x, c.y)


func _rand_view() -> Vector2:
	return Vector2(_rng.randf_range(_view.position.x, _view.end.x), _rng.randf_range(_view.position.y, _view.end.y))


func _spawn_amb(k: int) -> bool:
	var p: Vector2 = _rand_view()
	var b: int = _cell_b(p)
	if b < 0:
		return false
	var meadow: bool = b == Biome.GRASS or b == Biome.STEPPE or b == Biome.FOREST or b == Biome.FIELD or b == Biome.GARDEN
	match k:
		K_BFLY:
			if not meadow or (gw.vision != null and not gw.vision.sees(p)):
				return false
			_add(K_BFLY, p, Vector2.ZERO, _rng.randf_range(8.0, 15.0), 0, 0, BFLY_COLS[_rng.randi() % BFLY_COLS.size()], Color.WHITE)
		K_POLLEN:
			if not meadow:
				return false
			_add(K_POLLEN, p, Vector2(0, -1.2), _rng.randf_range(1.6, 2.6), 0, 0, Color(1.0, 0.97, 0.75), Color.WHITE)
		K_LEAF:
			var c: = Vector2i(int(p.x) >> 2, int(p.y) >> 2)
			for r in 6:
				var q: Vector2i = c + Vector2i(_rng.randi_range( - r, r), _rng.randi_range( - r, r))
				if gw.data.inside(q.x, q.y) and gw.tree_at.has(q.y * gw.data.w + q.x):
					var lp: = Vector2(q.x * 4 + _rng.randi_range(-1, 5), q.y * 4 - _rng.randi_range(5, 10))
					var i: int = _add(K_LEAF, lp, Vector2.ZERO, _rng.randf_range(3.5, 5.0), 0, 0, LEAF_COLS[_rng.randi() % LEAF_COLS.size()], Color.WHITE)
					return i >= 0
			return false
	return true


func _spawn_ripple() -> void :
	for k in 4:
		var p: Vector2 = _rand_view()
		var b: int = _cell_b(p)
		if b < 0 or not Biome.is_water(b) or b <= Biome.OCEAN:
			continue

		var shore: bool = false
		for o: Vector2 in [Vector2(8, 0), Vector2(-8, 0), Vector2(0, 8), Vector2(0, -8)]:
			var bb: int = _cell_b(p + o)
			if bb >= 0 and not Biome.is_water(bb):
				shore = true
				break
		if shore:
			_add(K_RIPPLE, p.floor(), Vector2.ZERO, 1.6, 0, 0, Color(0.85, 0.95, 1.0, 0.85), Color.WHITE)
			return


func _spawn_fish() -> void :
	for k in 4:
		var p: Vector2 = _rand_view()
		var b: int = _cell_b(p)
		if b >= 0 and Biome.is_water(b) and (gw.vision == null or gw.vision.sees(p)):
			_add(K_FISH, p.floor(), Vector2.ZERO, 0.75, 0, 0, Color(0.9, 0.95, 1.0), Color.WHITE)
			return



func _birds(dt: float) -> void :
	if _zoom < 0.75:
		flocks.clear()
		return
	if _zoom >= 1.0 and Vfx.level() >= 1:
		_bird_t -= dt
		if _bird_t <= 0.0:
			_bird_t = _rng.randf_range(18.0, 40.0) / float(Vfx.level())
			if flocks.size() < int(FLOCKS_MAX[Vfx.level()]):
				var left: bool = _rng.randf() < 0.5
				var y: float = _rng.randf_range(_view.position.y, _view.end.y)
				var p: = Vector2(_view.position.x - 30.0 if left else _view.end.x + 30.0, y)
				var v: = Vector2(1.0 if left else -1.0, _rng.randf_range(-0.35, 0.35)).normalized() * _rng.randf_range(20.0, 28.0)
				_new_flock(p, v, _rng.randi_range(4, 7), 14.0, 0.0)
	for k in range(flocks.size() - 1, -1, -1):
		var fl: Dictionary = flocks[k]
		var v: Vector2 = fl["v"]
		var sc: float = float(fl["scared"])
		if sc > 0.0:
			fl["scared"] = maxf(0.0, sc - dt * 0.3)
			fl["h"] = minf(16.0, float(fl["h"]) + dt * 8.0)
		else:
			v = v.lerp(v.normalized() * 24.0, dt * 0.3)
		fl["v"] = v
		fl["p"] = (fl["p"] as Vector2) + v * dt
		fl["t"] = float(fl["t"]) + dt
		if not _view.grow(90.0).has_point(fl["p"]) or float(fl["t"]) > 60.0:
			flocks.remove_at(k)


func _new_flock(p: Vector2, v: Vector2, cnt: int, h: float, scared: float) -> void :
	var off: = PackedVector2Array()
	var back: Vector2 = - v.normalized()
	var side: = Vector2( - back.y, back.x)
	for i in cnt:
		var row: int = (i + 1) / 2
		var s: float = 1.0 if i % 2 == 0 else -1.0
		off.append((back * 5.0 * row + side * 5.0 * row * s + Vector2(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.5, 1.5))) * (1.6 if scared > 0.0 else 1.0))
	flocks.append({"p": p, "v": v, "off": off, "t": _rng.randf() * 3.0, "h": h, "scared": scared})


func _scare(p: Vector2, r: float) -> void :
	for fl: Dictionary in flocks:
		var d: Vector2 = (fl["p"] as Vector2) - p
		if d.length() < r:
			fl["v"] = (d.normalized() if d.length() > 1.0 else Vector2.RIGHT) * 48.0
			fl["scared"] = 1.0




func _contrails(real_dt: float, dt: float) -> void :
	_trail_t -= real_dt
	var t: float = _ct
	if _trail_t <= 0.0:
		_trail_t = 0.1
		var mil: Military = gw.mil
		for m: Missile in mil.missiles:
			_trail_pt("m%d" % m.id, m.screen_pos(), 0, m.country_id)
		for d: Drone in mil.drones:
			if d.airborne() and d.state != Drone.State.DIVE:
				_trail_pt("d%d" % d.id, d.pos, 1 if d.kind == 0 else 2, d.country_id)
		for s: Dictionary in gw.defense.shots:
			_trail_pt("s%d" % int(s["id"]), s["pos"], 3, int(s["c"]))
		for a: Dictionary in mil.air.aams:
			_trail_pt("a%d" % int(a["id"]), a["pos"], 3, int(a.get("c", -1)))

		for ac: Aircraft in mil.air.aircraft:
			if ac.type == Aircraft.Type.HELI or ac.state == Aircraft.State.DEAD or not ac.airborne():
				continue
			var fw: Vector2 = Vector2.from_angle(ac.heading)
			for sd: float in ([3.0, -3.0] if ac.type == Aircraft.Type.BOMBER else [0.0]):
				var tk: String = ("j%d" if sd >= 0.0 else "k%d") % ac.id
				_trail_pt(tk, ac.pos - fw * (7.0 if sd != 0.0 else 5.0) + fw.orthogonal() * sd, 4, ac.country_id)
				if trails.has(tk):
					trails[tk]["id"] = ac.id
					trails[tk]["side"] = sd
		var live: Dictionary = {}
		for r: Dictionary in mil.air.nars:
			var tp: Vector2 = r["t"]
			var key: String = "n%d_%d" % [roundi(tp.x * 10.0), roundi(tp.y * 10.0)]
			live[key] = tp
			if not _nar_seen.has(key) and _view.grow(40.0).has_point(r["p"]) and (gw.vision == null or gw.vision.shows_air(int(r["c"]), r["p"])):
				_nar_launch(r["p"], float(r["h"]))
			_trail_pt(key, r["p"], 5, int(r["c"]))
		for key2: String in _nar_seen.keys():
			if not live.has(key2):
				var ip: Vector2 = _nar_seen[key2]
				if _view.grow(40.0).has_point(ip) and (gw.vision == null or gw.vision.sees(ip)):
					impact(ip, 1, false)
					billow(ip, 0)
		_nar_seen = live

	if _zoom >= 0.75 and not gw.mil.air.nars.is_empty():
		var lim: int = int(float(Vfx.MAX_PARTS[Vfx.level()]) * 0.6)
		for r2: Dictionary in gw.mil.air.nars:
			if n < lim and _rng.randf() < real_dt * 14.0 and _view.has_point(r2["p"]):
				var q: Vector2 = r2["p"]
				_add(K_BILLOW, q + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)), Vector2(_rng.randf_range(-2.0, 2.0), _rng.randf_range(-2.0, 2.0)), _rng.randf_range(0.7, 1.0), 2.0, 6.0, Color(0.92, 0.91, 0.88, 0.7), Color(0.7, 0.69, 0.66, 0.5))

	for key: String in trails.keys():
		var tr: Dictionary = trails[key]
		var ts: PackedFloat32Array = tr["ts"]
		var lf: float = _trail_life(int(tr["k"]))
		var drop: int = 0
		while drop < ts.size() and t - ts[drop] > lf:
			drop += 1
		if drop >= ts.size():
			trails.erase(key)
		elif drop > 0:
			tr["pts"] = (tr["pts"] as PackedVector2Array).slice(drop)
			tr["ts"] = ts.slice(drop)


func _trail_life(k: int) -> float:
	return [5.0, 1.2, 3.0, 2.2, 1.7, 1.1][k]


var _nar_seen: Dictionary = {}



func _nar_launch(p: Vector2, h: float) -> void :
	if _zoom < 0.75:
		return
	_add(K_FIRE, p, Vector2.ZERO, 0.12, 4.0, 1.0, Color(1.0, 0.86, 0.45, 1.0), Color(1.0, 0.5, 0.15, 0.6))
	for k in 2:
		_add(K_BILLOW, p - Vector2.from_angle(h) * float(2 + k * 3), Vector2.from_angle(h + PI + _rng.randf_range(-0.6, 0.6)) * 6.0, _rng.randf_range(0.8, 1.2), 3.0, 8.0, Color(0.95, 0.94, 0.9, 0.75), Color(0.72, 0.7, 0.67, 0.5))


func _trail_pt(key: String, p: Vector2, k: int, cid: int) -> void :
	if not _view.grow(400.0).has_point(p):
		return
	if gw.vision != null and not gw.vision.shows_air(cid, p):
		return
	var tr: Dictionary = trails.get(key, {})
	if tr.is_empty():
		if trails.size() >= TRAIL_MAX:
			return
		tr = {"pts": PackedVector2Array(), "ts": PackedFloat32Array(), "k": k}
		trails[key] = tr
	var pts: PackedVector2Array = tr["pts"]
	if not pts.is_empty() and pts[pts.size() - 1].distance_squared_to(p) < 1.0:
		return
	pts.append(p.round())
	var ts: PackedFloat32Array = tr["ts"]
	ts.append(_ct)
	if pts.size() > TRAIL_PTS:
		pts = pts.slice(1)
		ts = ts.slice(1)
	tr["pts"] = pts
	tr["ts"] = ts



func _step(dt: float) -> void :
	var w: Vector2 = Vfx.wind
	var j: int = 0
	_kc.fill(0)
	for i in n:
		var a: float = age[i] + dt
		if a >= life[i]:
			continue
		var k: int = pk[i]
		var x: float = px[i]
		var y: float = py[i]
		match k:
			K_SMOKE, K_WISP:

				var u: float = a / life[i]
				var zk: float = s1[i] / 20.0
				vx[i] += (w.x * (0.15 + 1.1 * u) * zk - vx[i]) * minf(1.0, dt * 0.45)
				ox[i] += vx[i] * dt
				oy[i] += (vy[i] * (1.0 - 0.45 * u) + w.y * 0.3 * u * zk) * dt
			K_CHIMNEY, K_STEAM:
				var u2: float = a / life[i]
				vx[i] += (w.x * (0.4 + 0.8 * u2) - vx[i]) * minf(1.0, dt * 0.9)
				x += vx[i] * dt
				y += vy[i] * (1.0 - 0.5 * u2) * dt
			K_DUST:
				vx[i] *= maxf(0.0, 1.0 - dt * 2.5)
				vy[i] *= maxf(0.0, 1.0 - dt * 2.5)
				x += vx[i] * dt
				y += vy[i] * dt - 2.0 * dt
			K_BILLOW:
				vx[i] *= maxf(0.0, 1.0 - dt * 1.3)
				vy[i] *= maxf(0.0, 1.0 - dt * 1.3)
				var u5: float = a / life[i]
				x += (vx[i] + w.x * 0.45 * u5) * dt
				y += (vy[i] + w.y * 0.25 * u5 - 2.2) * dt
			K_BFLY:
				if _rng.randf() < dt * 0.8:
					var ang: float = _rng.randf() * TAU
					vx[i] = cos(ang) * 9.0
					vy[i] = sin(ang) * 6.0
				x += vx[i] * dt
				y += (vy[i] + sin(a * 9.0 + ph[i]) * 7.0) * dt
			K_LEAF:
				if a < life[i] - 1.0:
					x += (sin(a * 3.1 + ph[i]) * 6.0 + w.x * 0.4) * dt
					y += 5.5 * dt
			K_POLLEN:
				x += (sin(a * 1.3 + ph[i]) * 1.5 + w.x * 0.15) * dt
				y += -1.2 * dt
		if j != i:
			pk[j] = k
			vx[j] = vx[i]
			vy[j] = vy[i]
			life[j] = life[i]
			s0[j] = s0[i]
			s1[j] = s1[i]
			ph[j] = ph[i]
			pc[j] = pc[i]
			pc2[j] = pc2[i]
		px[j] = x
		py[j] = y
		ox[j] = ox[i]
		oy[j] = oy[i]
		age[j] = a
		_kc[k] += 1
		j += 1
	n = j
	for k in range(rings.size() - 1, -1, -1):
		if _ct - float(rings[k][1]) > 0.6:
			rings.remove_at(k)




func _sprite(sn: String, fr: int, p: Vector2, c: Color) -> void :
	if not vfx.atlas.sprites.has(sn):
		return
	var info: Dictionary = vfx.atlas.info(sn)
	var r: Rect2 = vfx.atlas.rect(sn, fr % int(info["frames"]))
	draw_texture_rect_region(vfx.tex, Rect2((p - Vector2(float(info["ax"]), float(info["ay"]))).floor(), r.size), r, c)


func _puff(p: Vector2, d: float, c: Color, wisp: bool) -> void :
	var list: Array = WISPS if wisp else PUFFS
	var di: int = clampi(int(d), 0, 79)
	var best: int = _widx[di] if wisp else _pidx[di]
	var src: Rect2 = _r_wisp[best] if wisp else _r_puff[best]
	if src.size.x <= 0.0:
		return

	var size: Vector2 = src.size * maxf(1.0, roundf(d / float(list[best])))
	draw_texture_rect_region(vfx.tex, Rect2((p - size * 0.5).round(), size), src, c)


func _draw() -> void :
	if gw == null or vfx.tex == null:
		return
	var us: int = Time.get_ticks_usec()
	var view: Rect2 = _view.grow(24.0)
	var close_a: float = 0.75 if _zoom >= 3.0 else 1.0
	var far_k: float = clampf((0.6 - _zoom) / 0.2, 0.0, 1.0)
	var zb: float = _zb()

	for i in (n if _kc[K_RIPPLE] + _kc[K_FISH] > 0 else 0):
		var k: int = pk[i]
		if k != K_RIPPLE and k != K_FISH:
			continue
		var p: = Vector2(px[i], py[i])
		if not view.has_point(p):
			continue
		var u: float = age[i] / life[i]
		if k == K_RIPPLE:
			var c: Color = pc[i]
			c.a = 0.25 + 0.6 * (1.0 - u)
			_sprite("amb_ripple", int(u * 4.0), p, c)
		else:
			_sprite("amb_fish", int(u * 5.0), p, pc[i])

	for r: Array in rings:
		var u2: float = clampf((_ct - float(r[1])) / 0.6, 0.0, 0.999)
		var sz: int = int(r[2])
		var steps: Array = [9, 15, 23, 33] if sz == 1 else ([15, 23, 33, 47] if sz == 2 else [23, 33, 47, 65])
		var d: int = int(steps[int(u2 * steps.size())])
		var col: = Color(0.62, 0.52, 0.38, 0.8 * (1.0 - u2)) if sz < 3 else Color(1.0, 1.0, 0.95, 0.55 * (1.0 - u2))
		var sc: float = 1.0 if sz < 3 else 1.6
		var nm: String = "ring_%d" % d
		if vfx.has(nm):
			var src: Rect2 = vfx.atlas.rect(nm)
			var s: Vector2 = src.size * Vector2(sc, sc * 0.62)
			draw_texture_rect_region(vfx.tex, Rect2((Vector2(r[0]) - s * 0.5).round(), s.round()), src, col)

	for i in n:
		var k3: int = pk[i]
		if k3 > K_DUST and k3 != K_FIRE and k3 != K_BILLOW:
			continue
		var p3: = Vector2(px[i], py[i])
		var d3: float = lerpf(s0[i], s1[i], sqrt(age[i] / life[i]))
		if k3 == K_SMOKE or k3 == K_WISP:
			p3 += Vector2(ox[i], oy[i]) * zb
			d3 *= zb
		if not view.grow(d3).has_point(p3):
			continue
		var u3: float = age[i] / life[i]
		var c3: Color = pc[i].lerp(pc2[i], clampf(u3 * 1.6, 0.0, 1.0))
		var base_a: float = pc[i].a
		match k3:
			K_SMOKE:
				var ck: float = _clear_k(p3, d3) if _ncl > 0 else 1.0
				if far_k > 0.0:

					if u3 > 0.4 and ph[i] < TAU * 0.3 * far_k:
						continue
					c3 = c3.lerp(SMOKE_FAR_COL, 0.35 * far_k * clampf(u3 * 2.0, 0.0, 1.0))
				c3.a = base_a * close_a * _steps((1.0 - 0.9 * pow(u3, 1.8)) * ck * (SMOKE_OLD if u3 > 0.5 else 1.0))
			K_WISP:
				c3.a = base_a * _steps(0.7 * (1.0 - u3) * (_clear_k(p3, d3) if _ncl > 0 else 1.0))
			K_CHIMNEY:
				c3.a = _steps(0.9 * (1.0 - u3))
			K_STEAM:
				c3.a = _steps(0.85 * (1.0 - u3 * u3))
			K_DUST:
				c3.a = _steps(0.7 * (1.0 - u3))
			K_BILLOW:
				c3.a = base_a * _steps(0.9 * (1.0 - pow(u3, 2.2)) * (_clear_k(p3, d3) if _ncl > 0 else 1.0))
			K_FIRE:
				c3.a = base_a
				var fs: float = maxf(1.0, roundf(lerpf(s0[i], s1[i], u3)))
				draw_texture_rect_region(vfx.tex, Rect2((p3 - Vector2(fs, fs) * 0.5).round(), Vector2(fs, fs)), _r_puff[0], c3)
				continue
		if c3.a <= 0.0:
			continue
		_puff(p3, d3, c3, k3 == K_WISP)

	for i in (n if _kc[K_BFLY] + _kc[K_LEAF] + _kc[K_POLLEN] > 0 else 0):
		var k4: int = pk[i]
		if k4 != K_BFLY and k4 != K_LEAF and k4 != K_POLLEN:
			continue
		var p4: = Vector2(px[i], py[i])
		if not view.has_point(p4):
			continue
		var a4: float = age[i]
		var c4: Color = pc[i]
		match k4:
			K_BFLY:
				c4.a = clampf(minf(a4, life[i] - a4) * 2.0, 0.0, 1.0)
				_sprite("amb_butterfly", int(a4 * 8.0 + ph[i]) % 2, p4, c4)
			K_LEAF:
				c4.a = clampf(life[i] - a4, 0.0, 1.0)
				_sprite("amb_leaf", int(a4 * 5.0 + ph[i]) % 4 if a4 < life[i] - 1.0 else 1, p4, c4)
			K_POLLEN:
				c4.a = sin(a4 / life[i] * PI)
				_sprite("amb_pollen", 1 if fmod(a4, 0.8) < 0.2 else 0, p4, c4)

	for fl: Dictionary in flocks:
		var fp: Vector2 = fl["p"]
		var h: float = float(fl["h"])
		var fr: int = int(float(fl["t"]) * (7.0 if float(fl["scared"]) > 0.0 else 3.0)) % 2
		for o: Vector2 in fl["off"]:
			_sprite("amb_bird", fr, fp + o + Vector2(h * 0.7, h), Color(0.0, 0.04, 0.02, 0.2))
		for o2: Vector2 in fl["off"]:
			_sprite("amb_bird", fr, fp + o2 + Vector2(0, 1), Color(0.86, 0.86, 0.8, 0.75))
			_sprite("amb_bird", fr, fp + o2, Color(0.16, 0.15, 0.17, 0.95))

	_seg.clear()
	_segc.clear()
	var wpx: float = maxf(1.0, 1.0 / _zoom)
	for tr: Dictionary in trails.values():
		var pts: PackedVector2Array = tr["pts"]
		var ts: PackedFloat32Array = tr["ts"]
		var k6: int = int(tr["k"])
		if k6 == 0 and _zoom >= 1.5:
			continue
		var lf: float = _trail_life(k6)
		var a0: float = [0.6, 0.3, 0.5, 0.55, 0.55, 0.75][k6]
		if k6 == 4 and _zoom < 0.75:
			continue
		if k6 == 4 and pts.size() > 0:
			var lv: Vector2 = _live_tail(tr)
			if lv.is_finite() and lv.distance_squared_to(pts[pts.size() - 1]) < 400.0:
				_seg.append(pts[pts.size() - 1])
				_seg.append(lv)
				_segc.append(Color(0.93, 0.94, 0.96, _steps(a0 * 0.8)))
		for q in range(1, pts.size()):
			var u6: float = clampf((_ct - ts[q]) / lf, 0.0, 1.0)
			if k6 == 4:

				if q % 2 == 0:
					continue
				_puff(pts[q], 2.0 + 3.0 * u6, Color(0.93, 0.94, 0.96, _steps(a0 * (1.0 - u6) * (1.0 - u6))), false)
				continue
			_seg.append(pts[q - 1])
			_seg.append(pts[q])
			_segc.append(Color(1.0, 1.0, 1.0, _steps(a0 * (1.0 - u6))))
	if not _seg.is_empty():
		draw_multiline_colors(_seg, _segc, wpx)
	Vfx.cost("air_draw", Time.get_ticks_usec() - us)



func _live_tail(tr: Dictionary) -> Vector2:
	var id: int = int(tr.get("id", -1))
	if id < 0:
		return Vector2.INF
	for ac: Aircraft in gw.mil.air.aircraft:
		if ac.id == id and ac.airborne() and ac.state != Aircraft.State.DEAD:
			var fw: Vector2 = Vector2.from_angle(ac.heading)
			var side: float = float(tr.get("side", 0.0))
			return (ac.pos - fw * (7.0 if side != 0.0 else 5.0) + fw.orthogonal() * side).round()
	return Vector2.INF



static func _steps(a: float) -> float:
	return clampf(ceilf(a * 4.0 - 0.25) / 4.0, 0.0, 1.0)
