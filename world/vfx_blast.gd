class_name VfxBlast
extends Node2D



























const ATLAS_PNG: = "res://assets/sprites/det30_fx.png"
const ATLAS_JSON: = "res://assets/sprites/det30_fx.json"

const FXK: Dictionary = {
	"explosion_l": 3, "tank_blast": 2, "blast_m": 2, "explosion_m": 2, "explosion_sea": 2, 
	"shell_burst": 1, "rocket_burst": 1, "atgm_hit": 1, "mortar_burst": 0, "explosion_s": 0, 
	"grenade_burst": 0, "hit_small": -1, "spark_burst": -1, "intercept_flash": -1, 
	"muzzle_flash": -2, "tank_shot": -2, "arty_flash": -2, "mortar_flash": -2, "mlrs_launch": -2, 
	"tel_flash": -2, "ramp_blast": -2, 
}
const MAX_SPARKS: Array = [48, 110, 170]
const MAX_LIGHTS: int = 24
const SPARK_N: Array = [0, 4, 7, 12, 18]
const DEBRIS_N: Array = [0, 1, 3, 5, 8]


const LIGHT_R: Array = [7.0, 12.0, 34.0, 62.0, 110.0]
const MAX_AREA: int = 4
const FLASH_T: float = 0.16
const DEPOT: Dictionary = {
	Facility.Kind.MISSILE_FACTORY: 6, Facility.Kind.TEL: 5, Facility.Kind.DP_STORE: 5, Facility.Kind.AD_SAM: 4, 
	Facility.Kind.AD_PATRIOT: 5, Facility.Kind.COASTAL_ASM: 5, Facility.Kind.NAVAL_BASE: 4, Facility.Kind.AIRFIELD: 4, 
	Facility.Kind.DRONE_FACTORY: 4, Facility.Kind.AD_MFG: 4, Facility.Kind.BARRACKS: 3, Facility.Kind.DRONE_PORT: 3, 
	Facility.Kind.AD_SPAAG: 2, Facility.Kind.AD_INT: 3, 
}
const C_HOT: = Color("fff1a8")
const C_YEL: = Color("ffc23d")
const C_ORA: = Color("ff7a1f")
const C_RED: = Color("d6331f")
const C_EMB: = Color("8a1f14")
const C_DEB: = Color("3a3a3c")
const C_HALO: = Color(1.0, 0.62, 0.22)
const C_DIRT: = Color("6b4f30")
const C_DIRT2: = Color("8a6a42")
const MAX_STREAKS: Array = [24, 64, 96]
const HEAT_CELL: float = 48.0
const HEAT_MAX: int = 72
const CANNON_FX: Dictionary = {"tank_shot": true, "arty_flash": true, "mlrs_launch": true, "tel_flash": true}

const X_CLS: Dictionary = {"x_fpv": 0, "x_mine": 0, "x_shell": 1, "x_mlrs": 1, "x_kab": 2, "x_cruise": 2, "x_ball": 3, "x_hyper": 3}
const X_PARTS: Dictionary = {
	"x_fpv": [8, 2, 0, 0], "x_mine": [4, 1, 7, 0], "x_shell": [7, 3, 11, 0], "x_mlrs": [14, 3, 3, 0], 
	"x_kab": [8, 4, 16, 5], "x_cruise": [14, 6, 4, 8], "x_ball": [16, 8, 8, 12], "x_hyper": [16, 8, 8, 12], 
}
const X_STOP: Dictionary = {"x_kab": 0.05, "x_cruise": 0.05, "x_ball": 0.07, "x_hyper": 0.07}
const BURST_MAX: int = 48
const C_SMK: = Color("7d776e")
const C_SMK2: = Color("b8b2a8")

static var hitstop: float = 0.0

static var last_x: String = ""
static var last_xp: Vector2 = Vector2.ZERO
static var n_x: int = 0
static var log_x: bool = false
static var r314_on: bool = true

var vfx: Vfx
var gw: GameWorld
var atlas: SpriteAtlas

var cost_us: int = 0

var n: int = 0
var sx: = PackedFloat32Array()
var sy: = PackedFloat32Array()
var sz: = PackedFloat32Array()
var svx: = PackedFloat32Array()
var svy: = PackedFloat32Array()
var svz: = PackedFloat32Array()
var sage: = PackedFloat32Array()
var slife: = PackedFloat32Array()
var skind: = PackedInt32Array()
var flashes: Array = []
var lights: Array = []
var pops: Array = []
var _ct: float = 0.0
var _zoom: float = 1.0
var _view: = Rect2()
var _night: float = 0.0
var _ember_t: float = 0.0
var _drawn: bool = false
var _r_flash: Array[Rect2] = []

var sn: int = 0
var tax: = PackedFloat32Array()
var tay: = PackedFloat32Array()
var tbx: = PackedFloat32Array()
var tby: = PackedFloat32Array()
var tage: = PackedFloat32Array()
var tlife: = PackedFloat32Array()
var tside: = PackedInt32Array()
var tbig: = PackedInt32Array()
var _tr_last: float = -1.0
var _shell_seen: Dictionary = {}
var heat: Dictionary = {}
var _heat_t: float = 0.0
var _haze_t: float = 0.0
var _seen_gc: float = 0.0
var tur: VfxTurret
var hints: Dictionary = {}
var _hint_t: float = 0.0
var _rate: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void :
	gw = vfx.gw
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 6
	atlas = SpriteAtlas.load_atlas(ATLAS_PNG, ATLAS_JSON, true)
	for nm: String in ["flash_s", "flash_m", "flash_l"]:
		_r_flash.append(atlas.rect(nm, 0) if atlas.sprites.has(nm) else Rect2())
	var cap: int = int(MAX_SPARKS[2])
	sx.resize(cap)
	sy.resize(cap)
	sz.resize(cap)
	svx.resize(cap)
	svy.resize(cap)
	svz.resize(cap)
	sage.resize(cap)
	slife.resize(cap)
	skind.resize(cap)
	var sc: int = int(MAX_STREAKS[2])
	tax.resize(sc)
	tay.resize(sc)
	tbx.resize(sc)
	tby.resize(sc)
	tage.resize(sc)
	tlife.resize(sc)
	tside.resize(sc)
	tbig.resize(sc)
	call_deferred("_make_layers")



func _make_layers() -> void :
	if gw == null or tur != null:
		return
	tur = VfxTurret.new()
	tur.name = "VfxTurret"
	tur.blast = self
	tur.gw = gw
	gw.add_child(tur)
	gw.move_child(tur, get_index() + 1)


func reset() -> void :
	n = 0
	sn = 0
	heat.clear()
	_shell_seen.clear()
	_tr_last = -1.0
	flashes.clear()
	lights.clear()
	pops.clear()
	hints.clear()
	_rate.resize(0)
	hitstop = 0.0
	if tur != null:
		tur.reset()
	DmgStages.reset()





func on_fx(sname: String, p: Vector2) -> void :
	var cls: int = int(X_CLS.get(sname, FXK.get(sname, -9)))
	if X_CLS.has(sname):
		last_x = sname
		last_xp = p
		n_x += 1
		if log_x:
			print("[R314fx] %s at %s hint=%s t=%.2f" % [sname, p.round(), _hint_at(p), gw.game_time if gw != null else 0.0])
	if cls == -9 or gw == null or gw.camera == null:
		return
	if CANNON_FX.has(sname) and gw.vision != null and gw.vision.active() and not gw.vision.sees(p):
		return
	if cls >= -1 or CANNON_FX.has(sname):
		_heat(p, 0.5 if cls >= 0 else 0.25)
	if not _view.grow(140.0).has_point(p):
		return
	if cls >= 0 and tur != null and r314_on:
		tur.on_blast(p, cls, sname)
	_burst(p, cls, sname)
	if _zoom < 0.6:
		return
	if CANNON_FX.has(sname):

		if flashes.size() < 24:
			flashes.append([p, _ct, 0])
		_sparks(p, 3, 0, 22.0)
		if randf() < 0.5 and gw.vfx != null and gw.vfx.air != null:
			gw.vfx.air.billow(p, 0)
	elif cls >= 0 and cls <= 1:

		var cell: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
		var fort: bool = gw.mil != null and gw.mil.fort_cells.has(cell)
		var cnt: int = (4 if cls == 1 else 2) + (5 if fort else 0)
		for k in cnt:
			var ang: float = randf() * TAU
			var v: float = randf_range(6.0, 16.0) * (1.4 if fort else 1.0)
			_add_one(p, 1.0, Vector3(cos(ang) * v, sin(ang) * v * 0.6, randf_range(40.0, 75.0) * (1.25 if cls == 1 else 0.9)), randf_range(0.6, 1.1), 4)



func pop(p: Vector2, size: int) -> void :
	if gw == null or gw.fx == null:
		return
	var nm: String = ["explosion_s", "blast_m", "blast_m", "explosion_l"][clampi(size, 0, 3)]
	if not gw.fx.atlas_of.has(nm):
		nm = "explosion_m" if size >= 1 else "explosion_s"
	gw.fx.spawn(nm, p.round(), 6)



func on_ruin(f: Facility) -> void :
	var cnt: int = int(DEPOT.get(f.kind, 0))
	if cnt <= 0:
		return
	var c: Vector2 = f.center_px()
	var ext: = Vector2(float(f.size.x), float(f.size.y)) * GameWorld.CELL * 0.4
	var t: float = 0.6
	for k in cnt:
		t += randf_range(0.5, 2.2)
		var q: Vector2 = c + Vector2(randf_range( - ext.x, ext.x), randf_range( - ext.y, ext.y))
		pops.append([_ct + t, q, 2 if k == 0 or randf() < 0.25 else 0, f.id])




func _lvl() -> int:
	return clampi(GameConfig.fx_level, 0, 2)


func _burst(p: Vector2, cls: int, sname: String = "") -> void :

	if _night > 0.02 and lights.size() < MAX_LIGHTS:
		var r: float = float(LIGHT_R[clampi(cls + 1, 0, 4)]) if cls >= -1 else 6.0
		var life: float = [0.09, 0.14, 0.22, 0.38, 0.5, 0.75][clampi(cls + 2, 0, 5)]
		var inten: float = [0.5, 0.55, 0.6, 0.75, 0.85, 1.0][clampi(cls + 2, 0, 5)]
		lights.append([p, _ct, life, r, inten])
	if cls < 0:
		if cls == -1 and _zoom >= 1.0:
			_sparks(p, 2, 0, 18.0)
		return

	if cls >= 1 and flashes.size() < 24 and not (X_CLS.has(sname) and cls >= 2):
		flashes.append([p, _ct, clampi(cls - 1, 0, 1 if X_CLS.has(sname) else 2)])
	if X_PARTS.has(sname):
		_calibre(p, cls, sname)
		return
	if _zoom < 0.6:
		return
	var lv: float = [0.5, 1.0, 1.4][_lvl()]
	_sparks(p, roundi(float(SPARK_N[cls + 1]) * lv), 0, [26.0, 34.0, 42.0, 55.0][cls])
	_sparks(p, roundi(float(DEBRIS_N[cls + 1]) * lv), 1, [20.0, 26.0, 32.0, 40.0][cls])
	if gw.vfx != null and gw.vfx.air != null and gw.vfx.air.has_method("billow"):
		gw.vfx.air.billow(p, cls)



func _calibre(p: Vector2, cls: int, sname: String) -> void :
	_rate.append(_ct)
	while _rate.size() > 0 and _ct - _rate[0] > 1.0:
		_rate.remove_at(0)


	if _zoom < 0.6:
		return
	var far: float = p.distance_to(_view.get_center()) / maxf(_view.size.length(), 1.0)
	if X_STOP.has(sname) and _zoom >= 1.0 and far < 0.3 and hitstop <= 0.0:
		hitstop = float(X_STOP[sname])
	if gw.vfx != null and gw.vfx.air != null and gw.vfx.air.has_method("billow"):
		gw.vfx.air.billow(p, cls)
	if _rate.size() > 20 and far > 0.3:
		return
	var mix: Array = X_PARTS[sname]
	var lv: float = [0.5, 1.0, 1.25][_lvl()]
	var left: int = BURST_MAX
	var sp: float = [30.0, 36.0, 46.0, 58.0][cls]
	var cnt: int = mini(left, roundi(float(mix[0]) * lv))
	_sparks(p, cnt, 0, sp)
	left -= cnt
	cnt = mini(left, roundi(float(mix[1]) * lv))
	_sparks(p, cnt, 1, sp * 0.8)
	left -= cnt
	cnt = mini(left, roundi(float(mix[2]) * lv))
	var big: float = 1.6 if sname == "x_kab" else 1.0
	for k in cnt:
		var ang: float = randf() * TAU
		var v: float = randf_range(8.0, 22.0) * big
		_add_one(p, 1.0, Vector3(cos(ang) * v, sin(ang) * v * 0.6, randf_range(55.0, 95.0) * big), randf_range(0.8, 1.4), 4)
	left -= cnt
	cnt = mini(left, roundi(float(mix[3]) * lv))
	for k in cnt:
		var ang2: float = randf() * TAU
		var v2: float = randf_range(18.0, 40.0) * (1.3 if cls >= 3 else 1.0)
		_add_one(p, 2.0, Vector3(cos(ang2) * v2, sin(ang2) * v2 * 0.6, randf_range(70.0, 120.0)), randf_range(1.0, 1.7), 5)


func _sparks(p: Vector2, cnt: int, kind: int, sp: float) -> void :
	var cap: int = int(MAX_SPARKS[_lvl()])
	for k in cnt:
		if n >= cap:
			return
		var ang: float = randf() * TAU
		var v: float = sp * randf_range(0.45, 1.0)
		var i: int = n
		n += 1
		sx[i] = p.x
		sy[i] = p.y
		sz[i] = 1.0
		svx[i] = cos(ang) * v
		svy[i] = sin(ang) * v * 0.6
		svz[i] = randf_range(0.6, 1.3) * (sp * 1.3 if kind == 0 else sp * 1.6)
		sage[i] = 0.0
		slife[i] = randf_range(0.45, 0.9) if kind == 0 else randf_range(0.7, 1.3)
		skind[i] = kind


func _add_one(p: Vector2, z: float, v: Vector3, life: float, kind: int) -> void :
	if n >= int(MAX_SPARKS[_lvl()]):
		return
	var i: int = n
	n += 1
	sx[i] = p.x
	sy[i] = p.y
	sz[i] = z
	svx[i] = v.x
	svy[i] = v.y
	svz[i] = v.z
	sage[i] = 0.0
	slife[i] = life
	skind[i] = kind


func _process(delta: float) -> void :
	if gw == null or gw.camera == null:
		return
	var us: int = Time.get_ticks_usec()
	var cam: MapCamera = gw.camera
	_zoom = cam.zoom.x
	var half: Vector2 = cam.view_size() * 0.5 / _zoom
	_view = Rect2(cam.position - half, half * 2.0)
	_night = gw.night.factor if gw.night != null else 0.0
	var dt: float = delta * FxLayer.cosmetic_scale(gw.time_scale)
	if hitstop > 0.0:
		hitstop = maxf(0.0, hitstop - delta)
		dt = 0.0
	_ct += dt
	_hints(delta)
	if dt > 0.0:
		_pops()
		_embers(dt)
		_step(dt)
		_shots()
		_step_streaks(dt)
		_heat_tick(dt)
	for k in range(flashes.size() - 1, -1, -1):
		if _ct - float(flashes[k][1]) > FLASH_T:
			flashes.remove_at(k)
	for k in range(lights.size() - 1, -1, -1):
		if _ct - float(lights[k][1]) > float(lights[k][2]):
			lights.remove_at(k)
	var busy: bool = n > 0 or sn > 0 or not flashes.is_empty() or ( not lights.is_empty() and _night > 0.02) or (_zoom < 0.6 and not heat.is_empty())
	if busy or _drawn:
		queue_redraw()
	_drawn = busy
	cost_us = Time.get_ticks_usec() - us



func _pops() -> void :
	if pops.is_empty():
		return
	for k in range(pops.size() - 1, -1, -1):
		var e: Array = pops[k]
		if _ct < float(e[0]):
			continue
		pops.remove_at(k)
		var f: Facility = gw.vfx._fac(int(e[3])) if gw.vfx != null else null
		if f == null or gw.mil.alive(f):
			continue
		var q: Vector2 = e[1]
		pop(q, int(e[2]))
		if _zoom >= 0.6 and _view.grow(60.0).has_point(q):
			for s in randi_range(1, 2):
				var ang: float = randf_range( - PI * 0.85, - PI * 0.15)
				_add_one(q, 2.0, Vector3(cos(ang) * 30.0, sin(ang) * 10.0, randf_range(60.0, 95.0)), randf_range(0.8, 1.3), 3)



func _embers(dt: float) -> void :
	if _zoom < 1.2 or gw.fx == null or _lvl() == 0:
		return
	_ember_t -= dt
	if _ember_t > 0.0:
		return
	_ember_t = 0.12
	var fires: Array = gw.fx.get("fires_live") if gw.fx.get("fires_live") != null else []
	var v: Rect2 = _view.grow(8.0)
	var k: int = 0
	for e: Array in fires:
		var s: AnimatedSprite2D = e[0]
		if not is_instance_valid(s) or not s.visible or s.modulate.a < 0.5 or not v.has_point(s.position):
			continue
		if randf() < 0.22:
			_add_one(s.position + Vector2(randf_range(-3, 3), -2), randf_range(3.0, 7.0), Vector3(Vfx.wind.x * 0.4 + randf_range(-3, 3), Vfx.wind.y * 0.2, randf_range(8.0, 14.0)), randf_range(1.0, 2.2), 2)
			k += 1
			if k >= 4:
				break


func _step(dt: float) -> void :
	var j: int = 0
	for i in n:
		var a: float = sage[i] + dt
		if a >= slife[i]:
			continue
		var kd: int = skind[i]
		var z: float = sz[i]
		var vz: float = svz[i]
		if kd == 2:
			vz = maxf(2.0, vz - 6.0 * dt)
			svx[i] += (Vfx.wind.x * 0.6 - svx[i]) * minf(1.0, dt)
		elif kd == 3:
			vz -= 40.0 * dt
		elif kd == 5:
			vz -= 120.0 * dt
		else:
			vz -= 150.0 * dt
		z += vz * dt
		var x: float = sx[i] + svx[i] * dt
		var y: float = sy[i] + svy[i] * dt
		if z <= 0.0:
			if kd == 1 or kd == 0 or kd == 4 or kd == 5:
				continue
			z = 0.0
		if j != i:
			svx[j] = svx[i]
			svy[j] = svy[i]
			slife[j] = slife[i]
			skind[j] = kd
		sx[j] = x
		sy[j] = y
		sz[j] = z
		svz[j] = vz
		sage[j] = a
		j += 1
	n = j



func _shots() -> void :
	var trs: Array = gw.mil.air.tracers if gw.mil != null and gw.mil.air != null else []
	if gw.game_time + 0.5 < _tr_last:
		_tr_last = -1.0
	var newest: float = _tr_last
	var made: int = 0
	var own: int = gw.player.id if gw.player != null else -1
	var v: Rect2 = _view.grow(24.0)
	for tr: Array in trs:
		var until: float = float(tr[2])
		if until <= _tr_last:
			continue
		newest = maxf(newest, until)
		var a: Vector2 = tr[0]
		var b: Variant = tr[1]
		if not (b is Vector2):
			continue
		_heat(b, 0.12)
		if _zoom < 0.6 or made >= 24 or not (v.has_point(a) or v.has_point(b)) or (_hid(a) and _hid(b)):
			continue
		var side: int = 0 if _owner(a) == own else 1
		var burst: int = 1 if randf() < 0.5 else 2
		for k in burst:
			_streak(a, (b as Vector2) + Vector2(randf_range(-2, 2), randf_range(-2, 2)), -0.06 * float(k), side, 0)
		made += 1
	_tr_last = newest

	if gw.army == null or _zoom < 0.6:
		return
	for s: Dictionary in gw.army.shells:
		if float(s.get("t", 9.0)) > 0.3:
			continue
		var fa: Vector2 = s["from"]
		var to: Vector2 = s["to"]
		var key: Vector4i = Vector4i(int(fa.x), int(fa.y), int(to.x), int(to.y))
		if _shell_seen.has(key):
			continue
		_shell_seen[key] = _ct + 1.5
		_heat(to, 0.3)
		if (v.has_point(fa) or v.has_point(to)) and not (_hid(fa) and _hid(to)):
			_streak(fa, to, 0.0, 0 if _owner(fa) == own else 1, 1, maxf(0.12, float(s.get("dur", 0.2))))
	if _shell_seen.size() > 64 and _ct > _seen_gc:
		_seen_gc = _ct + 0.5
		for kk: Variant in _shell_seen.keys():
			if float(_shell_seen[kk]) < _ct:
				_shell_seen.erase(kk)



func _hid(p: Vector2) -> bool:
	return gw.vision != null and gw.vision.active() and not gw.vision.sees(p)


func _owner(p: Vector2) -> int:
	var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	return gw.data.get_owner_id(c.x, c.y) if gw.data != null and gw.data.inside(c.x, c.y) else -1


func _streak(a: Vector2, b: Vector2, age0: float, side: int, big: int, life: float = -1.0) -> void :
	if sn >= int(MAX_STREAKS[_lvl()]):
		return
	var i: int = sn
	sn += 1
	tax[i] = a.x
	tay[i] = a.y
	tbx[i] = b.x
	tby[i] = b.y
	tage[i] = age0
	tlife[i] = life if life > 0.0 else clampf(a.distance_to(b) / 420.0, 0.08, 0.22)
	tside[i] = side
	tbig[i] = big


func _step_streaks(dt: float) -> void :
	var j: int = 0
	for i in sn:
		var a: float = tage[i] + dt
		if a >= tlife[i]:
			if randf() < (0.9 if tbig[i] == 1 else 0.35):
				var b: = Vector2(tbx[i], tby[i])
				for k in (3 if tbig[i] == 1 else 1):
					_add_one(b, 1.0, Vector3(randf_range(-8, 8), randf_range(-5, 5), randf_range(18.0, 34.0)), randf_range(0.3, 0.55), 4)
			continue
		if j != i:
			tax[j] = tax[i]
			tay[j] = tay[i]
			tbx[j] = tbx[i]
			tby[j] = tby[i]
			tlife[j] = tlife[i]
			tside[j] = tside[i]
			tbig[j] = tbig[i]
		tage[j] = a
		j += 1
	sn = j



func _heat(p: Vector2, w: float) -> void :
	var c: = Vector2i(floori(p.x / HEAT_CELL), floori(p.y / HEAT_CELL))
	if heat.has(c):
		heat[c] = minf(4.0, float(heat[c]) + w)
	elif heat.size() < HEAT_MAX:
		heat[c] = w


func _heat_tick(dt: float) -> void :
	_heat_t -= dt
	if _heat_t <= 0.0 and not heat.is_empty():
		_heat_t = 0.25
		var k: float = exp(-0.25 / 3.0)
		for c: Variant in heat.keys():
			var h: float = float(heat[c]) * k
			if h < 0.05:
				heat.erase(c)
			else:
				heat[c] = h

	_haze_t -= dt
	if _haze_t > 0.0 or _zoom < 0.6 or heat.is_empty() or gw.vfx == null or gw.vfx.air == null or _lvl() == 0:
		return
	_haze_t = 0.35
	var v: Rect2 = _view.grow(30.0)
	var made: int = 0
	for c: Variant in heat:
		var h2: float = float(heat[c])
		if h2 < 0.8 or randf() > h2 * 0.18:
			continue
		var q: Vector2 = (Vector2(c as Vector2i) + Vector2(randf(), randf())) * HEAT_CELL
		if v.has_point(q) and gw.vfx.air.has_method("haze"):
			gw.vfx.air.haze(q)
			made += 1
			if made >= 2:
				return



func area_lights() -> Array:
	var out: Array = []
	if _night <= 0.02:
		return out
	for k in range(lights.size() - 1, -1, -1):
		var l: Array = lights[k]
		var r: float = float(l[3])
		if r < 16.0:
			continue
		var u: float = clampf((_ct - float(l[1])) / float(l[2]), 0.0, 1.0)
		out.append([l[0], r * (0.8 + 0.2 * u), float(l[4]) * (1.0 - u * u)])
		if out.size() >= MAX_AREA:
			break
	return out


func _draw() -> void :
	var us: int = Time.get_ticks_usec()
	var view: Rect2 = _view.grow(16.0)
	var px: float = maxf(1.0, roundf(1.0 / maxf(_zoom, 0.05)))

	if atlas.texture != null and not (atlas.texture is PlaceholderTexture2D):
		var fk: float = clampf(0.6 / maxf(_zoom, 0.05), 1.0, 3.0)
		for fl: Array in flashes:
			var u: float = (_ct - float(fl[1])) / FLASH_T
			var si: int = int(fl[2])
			var src: Rect2 = _r_flash[si]
			if src.size.x <= 0.0:
				continue
			if u > 0.5:
				src.position.x += src.size.x
			var s: Vector2 = (src.size * roundf(fk)).round()
			var c: = Color(1.0, 0.93, 0.7, (0.75 if u <= 0.5 else 0.6) * (0.75 + 0.25 * _night))
			draw_texture_rect_region(atlas.texture, Rect2((Vector2(fl[0]) - s * 0.5).round(), s), src, c)

		if _night > 0.02:
			var src2: Rect2 = _r_flash[0]
			src2.position.x += src2.size.x
			for l: Array in lights:
				if float(l[3]) >= 16.0:
					continue
				var p2: Vector2 = l[0]
				if not view.has_point(p2):
					continue
				var u2: float = (_ct - float(l[1])) / float(l[2])
				var c2: = C_HALO
				c2.a = 0.55 * _night * (1.0 if u2 < 0.5 else 0.5)
				draw_texture_rect_region(atlas.texture, Rect2((p2 - src2.size * 0.5).round(), src2.size), src2, c2)

	for i in sn:
		var ag: float = tage[i]
		if ag < 0.0:
			continue
		var a2: = Vector2(tax[i], tay[i])
		var b2: = Vector2(tbx[i], tby[i])
		var u4: float = ag / tlife[i]
		var head: Vector2 = a2.lerp(b2, u4)
		if not view.has_point(head):
			continue
		var dir: Vector2 = (b2 - a2).normalized()
		var big: bool = tbig[i] == 1
		var ln: float = (6.0 if big else 3.5) * px
		var ch: Color = C_HOT if tside[i] == 0 else C_YEL
		var ct: Color = C_YEL if tside[i] == 0 else C_ORA
		if big:
			ct = C_ORA
		draw_line(head.round(), (head - dir * ln).round(), ct, px)
		draw_rect(Rect2(head.floor(), Vector2(px, px) * (2.0 if big else 1.0)), ch)

	if _zoom < 0.6 and not heat.is_empty() and atlas.texture != null and not (atlas.texture is PlaceholderTexture2D):
		var src3: Rect2 = _r_flash[0]
		src3.position.x += src3.size.x
		var fk3: float = roundf(clampf(0.5 / maxf(_zoom, 0.05), 1.0, 4.0))
		for c: Variant in heat:
			var h3: float = float(heat[c])
			if h3 < 0.4 or randf() > clampf(h3 * 0.22, 0.0, 0.7):
				continue
			var q3: Vector2 = (Vector2(c as Vector2i) + Vector2(randf_range(0.2, 0.8), randf_range(0.2, 0.8))) * HEAT_CELL
			if not view.has_point(q3):
				continue
			var s3: Vector2 = src3.size * fk3
			var c3: = Color(1.0, 0.7, 0.3, 0.35 + 0.35 * _night)
			draw_texture_rect_region(atlas.texture, Rect2((q3 - s3 * 0.5).round(), s3), src3, c3)

	for i in n:
		var g: = Vector2(sx[i], sy[i])
		if not view.has_point(g):
			continue
		var u3: float = sage[i] / slife[i]
		var kd: int = skind[i]
		var p3: Vector2 = (g + Vector2(0.0, - sz[i])).floor()
		match kd:
			0:
				var c3: Color = C_HOT if u3 < 0.25 else (C_YEL if u3 < 0.55 else (C_ORA if u3 < 0.8 else C_RED))
				var tail: = Vector2( - svx[i], svz[i] - svy[i]).normalized() * px
				draw_rect(Rect2(p3 + tail.round(), Vector2(px, px)), C_RED if u3 > 0.4 else C_ORA)
				draw_rect(Rect2(p3, Vector2(px, px)), c3)
			1:
				draw_rect(Rect2(p3, Vector2(px, px)), C_DEB)
			4:
				draw_rect(Rect2(p3, Vector2(px, px)), C_DIRT if i % 2 == 0 else C_DIRT2)
			2:
				if fmod(sage[i] * 7.0 + float(i), 2.0) < 1.6:
					draw_rect(Rect2(p3, Vector2(px, px)), C_YEL if u3 < 0.3 else (C_ORA if u3 < 0.7 else C_EMB))
			5:

				var bk: = Vector2( - svx[i], svz[i] - svy[i]).normalized() * px
				draw_rect(Rect2((p3 + bk * 4.0).round(), Vector2(px, px)), C_SMK2)
				draw_rect(Rect2((p3 + bk * 2.0).round(), Vector2(px, px)), C_SMK)
				draw_rect(Rect2(p3, Vector2(px, px) * (2.0 if u3 < 0.5 else 1.0)), C_YEL if u3 < 0.3 else (C_ORA if u3 < 0.65 else C_RED))
			3:
				var dir: = Vector2(svx[i], svy[i] - svz[i]).normalized()
				for t in 3:
					draw_rect(Rect2((p3 - dir * float(t) * 2.0 * px).floor(), Vector2(px, px)), [C_HOT, C_YEL, C_ORA][t])
	cost_us += Time.get_ticks_usec() - us





func remap(sname: String, p: Vector2) -> String:
	if not r314_on or gw == null or gw.fx == null or not gw.fx.atlas_of.has("x_ball"):
		return sname
	match sname:
		"explosion_s":
			return "x_fpv"
		"mortar_burst":
			return "x_mine"
		"shell_burst":
			return "x_shell"
		"rocket_burst":
			return "x_mlrs"
		"blast_m":
			var h: String = _hint_at(p)
			if h == "kab":
				return "x_kab"
			if h == "cruise":
				return "x_cruise"
		"explosion_l":
			return "x_hyper" if _hint_at(p) == "hyper" else "x_ball"
		"shockwave":
			return ""
	return sname



func hint(p: Vector2, what: String) -> void :
	hints[Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))] = [what, _ct + 3.0]


func _hint_at(p: Vector2) -> String:
	var c: = Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var e: Variant = hints.get(c + Vector2i(dx, dy))
			if e != null:
				return String((e as Array)[0])
	return ""



func _hints(delta: float) -> void :
	_hint_t -= delta
	if _hint_t > 0.0 or gw.mil == null:
		return
	_hint_t = 0.1
	for k: Variant in hints.keys():
		if float((hints[k] as Array)[1]) < _ct:
			hints.erase(k)
	var v: Rect2 = _view.grow(240.0)
	for d: Drone in gw.mil.drones:
		if (d.state == Drone.State.DIVE or (d.state == Drone.State.FLY and d.pos.distance_squared_to(d.target) < 90.0 * 90.0)) and v.has_point(d.target):
			hint(d.target, ["drone", "cruise", "jet"][clampi(d.kind, 0, 2)])
	if gw.mil.air != null:
		for d2: Drone in gw.mil.air.kabs:
			if v.has_point(d2.target):
				hint(d2.target, "kab")
	for m: Missile in gw.mil.missiles:
		if m.state == Missile.State.FLIGHT and v.has_point(m.target):
			hint(m.target, "hyper" if m.hyper else "ballistic")



func on_kill(u: Unit) -> void :
	if tur != null:
		tur.on_kill(u)



func on_hit(u: Unit, dmg: float, src: int, at: Vector2) -> void :
	if tur != null:
		tur.on_hit(u, dmg, src, at)
