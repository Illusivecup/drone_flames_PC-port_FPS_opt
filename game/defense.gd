class_name Defense
extends RefCounted





const T_DRONE: int = 1
const T_CRUISE: int = 2
const T_HELI: int = 4
const T_JET: int = 8
const T_BALLISTIC: int = 16
const T_FPV: int = 32



static var SPEC: Dictionary = {
	Facility.Kind.AD_MFG: {"range": 100.0, "detect": 100.0, "mask": 1 | 4 | 32, "cd": 1.1, "hit": 30, "gun": true, "uav": 0.8}, 
	Facility.Kind.AD_SPAAG: {"range": 210.0, "detect": 210.0, "mask": 1 | 2 | 4 | 32, "cd": 0.9, "hit": 50, "gun": true, "uav": 0.6, "jet": 0.7}, 
	Facility.Kind.AD_SAM: {"range": 700.0, "detect": 260.0, "mask": 1 | 2 | 4 | 8 | 16, "cd": 3.0, "hit": 80, "ammo": 4, "reload": 25.0, "speed": 150.0}, 
	Facility.Kind.AD_PATRIOT: {"range": 450.0, "detect": 260.0, "mask": 2 | 8 | 16, "cd": 2.0, "hit": 75, "ammo": 4, "reload": 30.0, "speed": 190.0}, 
	Facility.Kind.AD_INT: {"range": 650.0, "detect": 220.0, "mask": 1 | 2 | 4, "cd": 2.5, "hit": 85, "ammo": 4, "reload": 18.0, "speed": 70.0}, 
}



const RADAR_R_BASE: float = 950.0
static var RADAR_R: float = 950.0




const RANGE_BASE: Dictionary = {Facility.Kind.AD_SAM: 700.0, Facility.Kind.AD_PATRIOT: 450.0, Facility.Kind.AD_INT: 650.0}
const SMALL_K: Dictionary = {Facility.Kind.AD_RADAR: 0.52, Facility.Kind.AD_SAM: 0.55, Facility.Kind.AD_PATRIOT: 0.7, Facility.Kind.AD_INT: 0.58}
static var map_k: float = 1.0



static func apply_map(w_cells: int) -> void :
	map_k = clampf(float(w_cells - 512) / 512.0, 0.0, 1.0)
	RADAR_R = RADAR_R_BASE * lerpf(float(SMALL_K[Facility.Kind.AD_RADAR]), 1.0, map_k)
	for k: int in RANGE_BASE:
		(SPEC[k] as Dictionary)["range"] = roundf(float(RANGE_BASE[k]) * lerpf(float(SMALL_K[k]), 1.0, map_k))
const EW_R: float = 150.0


const EW_JAM_CHANCE: int = 22
const EW_FPV_CHANCE: int = 25
const BALLISTIC_HIT: Dictionary = {Facility.Kind.AD_SAM: 20, Facility.Kind.AD_PATRIOT: 75}

const HYPER_HIT: Dictionary = {Facility.Kind.AD_SAM: 14, Facility.Kind.AD_PATRIOT: 22}


const HYPER_SHOT_K: float = 2.0
const HYPER_U: float = 0.45
const REARM_COST: int = 40







const SHOT_COST: Dictionary = {Facility.Kind.AD_MFG: 2, Facility.Kind.AD_SPAAG: 6, Facility.Kind.AD_INT: 40, 
	Facility.Kind.AD_SAM: 150, Facility.Kind.AD_PATRIOT: 220}
const GUN_MAG: Dictionary = {Facility.Kind.AD_MFG: 12, Facility.Kind.AD_SPAAG: 20}
const GUN_RELOAD: float = 10.0
const GUN_IDLE: float = 3.0
const GUN_LOW: int = 6
const ALERT_S: float = 10.0
const GUN_LEAD: float = 100.0
const SAM_THRIFT: int = 1500
const BROKE_GAP: float = 30.0


const AD_CLASSES: Array = [Facility.Kind.AD_SAM, Facility.Kind.AD_PATRIOT, Facility.Kind.AD_SPAAG, Facility.Kind.AD_MFG, Facility.Kind.AD_INT]
const CLASS_KEY: Dictionary = {Facility.Kind.AD_SAM: "sam", Facility.Kind.AD_PATRIOT: "patriot", Facility.Kind.AD_SPAAG: "spaag", 
	Facility.Kind.AD_MFG: "mfg", Facility.Kind.AD_INT: "int"}
const R_JET: int = 1
const R_HELI: int = 2
const R_UAV: int = 4
const R_JETUAV: int = 8
const R_CRUISE: int = 16
const R_BALL: int = 32
const R_HYPER: int = 64
const R_KAB: int = 128
const R_FPV: int = 256
const R_RECON: int = 512
const R_ALL: int = 1023
const R_CHEAP: int = R_UAV | R_FPV | R_KAB
const POSSIBLE: Dictionary = {
	Facility.Kind.AD_SAM: R_JET | R_HELI | R_UAV | R_JETUAV | R_CRUISE | R_BALL | R_HYPER | R_RECON, 
	Facility.Kind.AD_PATRIOT: R_JET | R_JETUAV | R_CRUISE | R_BALL | R_HYPER, 
	Facility.Kind.AD_SPAAG: R_HELI | R_UAV | R_JETUAV | R_CRUISE | R_KAB | R_FPV | R_RECON, 
	Facility.Kind.AD_MFG: R_HELI | R_UAV | R_KAB | R_FPV | R_RECON, 
	Facility.Kind.AD_INT: R_HELI | R_UAV | R_JETUAV | R_CRUISE | R_RECON, 
}

const PRESETS: Dictionary = {
	"all": {}, 
	"eco": {Facility.Kind.AD_SAM: R_ALL & ~ R_CHEAP, Facility.Kind.AD_PATRIOT: R_ALL & ~ R_CHEAP}, 
	"missiles": {Facility.Kind.AD_SAM: R_CRUISE | R_BALL | R_HYPER | R_KAB, Facility.Kind.AD_PATRIOT: R_CRUISE | R_BALL | R_HYPER | R_KAB, 
		Facility.Kind.AD_SPAAG: R_CRUISE | R_BALL | R_HYPER | R_KAB, Facility.Kind.AD_MFG: R_CRUISE | R_BALL | R_HYPER | R_KAB, 
		Facility.Kind.AD_INT: R_CRUISE | R_BALL | R_HYPER | R_KAB}, 
}
const PRESET_ORDER: Array = ["all", "eco", "missiles"]

const LOC_AD_PRESETS: Dictionary = {"all": "Всё сбивать", "eco": "Экономно", "missiles": "Только ракеты"}
const LOC_AD_PRESET_HINT: Dictionary = {"all": "Каждый класс ПВО бьёт всё, что может", "eco": "ЗРК и ПРО — только авиация и ракеты, дроны — зенитки", 
	"missiles": "Огонь только по ракетам и КАБ"}
const LOC_AD_CLASS: Dictionary = {Facility.Kind.AD_SAM: "ЗРК (дальние)", Facility.Kind.AD_PATRIOT: "ПРО «Щит»", Facility.Kind.AD_SPAAG: "ЗСУ", 
	Facility.Kind.AD_MFG: "Огневые группы", Facility.Kind.AD_INT: "Перехватчики"}
const LOC_AD_COLS: Array = [[R_JET, "Самолёты"], [R_HELI, "Вертолёты"], [R_UAV, "Ударные БПЛА"], [R_JETUAV, "Реактивные БПЛА"], 
	[R_CRUISE, "Крылатые ракеты"], [R_BALL, "Баллистические"], [R_HYPER, "Гиперзвук"], [R_KAB, "КАБ"], [R_FPV, "FPV"], 
	[R_RECON, "Разведывательные БПЛА"]]
const BOT_ECO_IN: int = 1500
const BOT_ECO_OUT: int = 4000
const BOT_RULE_S: float = 15.0
var _broke_t: Dictionary = {}
var _gc: Dictionary = {}
var _gc_t: float = -1.0
var st335: Dictionary = {}

var gw: GameWorld
var shots: Array = []
var _id: int = 1
var _scan: float = 0.0
var _anim: float = 0.0


func _init(world: GameWorld) -> void :
	gw = world


static func is_ad(kind: int) -> bool:
	return kind >= Facility.Kind.AD_MFG and kind <= Facility.Kind.AD_INT


func _ready(f: Facility) -> bool:
	return gw.mil.alive(f) and not f.moving and not f.mb


func covered(country_id: int, p: Vector2) -> bool:
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.AD_RADAR and _ready(f) and (f.country_id == country_id or gw.diplo.allied(f.country_id, country_id)) and gw.mil.has_power(f):
			if f.center_px().distance_squared_to(p) <= RADAR_R * RADAR_R:
				return true
	return false


func _hostile(a: int, b: int) -> bool:
	if a == b:
		return false
	var c: Country = gw.country_by_id(a)
	return c != null and c.at_war.has(b)








func _engage(a: int, b: int, gp: Vector2, t: Object = null) -> bool:
	if a == b or b <= 0:
		return false
	if _hostile(a, b):
		return true
	if gw.data == null or gw.diplo == null:
		return false
	if gw.diplo.sky != null and gw.diplo.sky.fire_host(a, b, gp, t) > 0:
		return true
	var cl: = Vector2i(floori(gp.x / GameWorld.CELL), floori(gp.y / GameWorld.CELL))
	if not gw.data.inside(cl.x, cl.y) or gw.data.get_owner_id(cl.x, cl.y) != a:
		return false
	var dp: Diplomacy = gw.diplo
	if dp.allied(b, a) or dp.has_passage(b, a) or (dp.ally != null and dp.ally.same(b, a)):
		return false
	if t is Aircraft:
		return deep_inside(a, gp)
	return true







const PEACE_DEPTH: float = 150.0
const DEPTH_RAYS: int = 32
const DEPTH_STEP: float = 8.0
var _dep: Dictionary = {}
var _dep_t: float = -1.0
var peace_downs: int = 0




func deep_inside(a: int, gp: Vector2, r: float = PEACE_DEPTH) -> bool:
	var bx: int = floori(gp.x / DEPTH_STEP)
	var by: int = floori(gp.y / DEPTH_STEP)
	var key: int = (a * 4096 + by) * 4096 + bx
	if gw.game_time != _dep_t:
		_dep_t = gw.game_time
		_dep.clear()
	elif r == PEACE_DEPTH and _dep.has(key):
		return bool(_dep[key])
	var q: = Vector2((float(bx) + 0.5) * DEPTH_STEP, (float(by) + 0.5) * DEPTH_STEP)
	var dt: WorldData = gw.data
	var c0: = Vector2i(floori(q.x / GameWorld.CELL), floori(q.y / GameWorld.CELL))
	var ok: bool = dt.inside(c0.x, c0.y) and dt.get_owner_id(c0.x, c0.y) == a
	var n: int = ceili(r / DEPTH_STEP)
	for k in DEPTH_RAYS:
		if not ok:
			break
		var dir: = Vector2.from_angle(TAU * float(k) / float(DEPTH_RAYS))
		for i in range(1, n + 1):
			var pt: Vector2 = q + dir * minf(float(i) * DEPTH_STEP, r)
			var cx: int = floori(pt.x / GameWorld.CELL)
			var cy: int = floori(pt.y / GameWorld.CELL)
			if not dt.inside(cx, cy) or dt.get_owner_id(cx, cy) != a:
				ok = false
				break
	if r == PEACE_DEPTH:
		_dep[key] = ok
	return ok




var _intr_t: Dictionary = {}




func _intruder_down(by: int, owner: int, what: String, t: Object = null) -> bool:
	if by <= 0 or owner <= 0 or by == owner or _hostile(by, owner) or gw.diplo == null:
		return true
	if gw.diplo.sky != null and gw.diplo.sky.on_down(by, owner, t, what):
		return true
	peace_downs += 1
	gw.diplo.add_opinion(owner, by, -2)
	var k: int = by * 1000 + owner
	if gw.game_time < float(_intr_t.get(k, -100.0)):
		return false
	_intr_t[k] = gw.game_time + 20.0
	var cb: Country = gw.country_by_id(by)
	var co: Country = gw.country_by_id(owner)
	gw.say2(cb, co, Loc.mk("ПВО %s сбила %s %s над своей территорией", [Loc.name(cb.name) if cb != null else "?", what, Loc.name(co.name) if co != null else "?"]))
	return false



func _targets(f: Facility, sp: Dictionary) -> Array:
	var out: Array = []
	var p: Vector2 = f.center_px()
	var r: float = float(sp["range"])
	var det: float = float(sp["detect"])
	var mask: int = int(sp["mask"])
	var r2: float = r * r
	for d: Drone in gw.mil.drones:
		if not d.airborne() or d.state == Drone.State.DONE or not _engage(f.country_id, d.country_id, d.pos, d):
			continue
		var bit: int = T_CRUISE if d.kind != 0 else T_DRONE
		if mask & bit == 0:
			continue
		var d2: float = d.pos.distance_squared_to(p)
		if d.low:
			var lr: float = minf(r, det * Navy.CM_LOW_DET)
			if d2 <= lr * lr:
				out.append([d, bit, d.pos, d2])
			continue
		if d2 <= r2 and (d2 <= det * det or covered(f.country_id, d.pos)):
			out.append([d, bit, d.pos, d2])
	if bool(sp.get("gun", false)):
		for kb: Drone in gw.mil.air.kabs:
			if not kb.airborne() or kb.state == Drone.State.DONE or not _engage(f.country_id, kb.country_id, kb.pos, kb)\
			or int(gw.mil.air.kab_gun_tries.get(kb.id, 0)) >= Air.KAB_GUN_TRIES:
				continue
			var dk: float = kb.pos.distance_squared_to(p)
			if dk <= r2 and (dk <= det * det or covered(f.country_id, kb.pos)):
				out.append([kb, T_CRUISE, kb.pos, dk])
	for a: Aircraft in gw.mil.air.aircraft:
		if not a.airborne() or a.state == Aircraft.State.DEAD or not _engage(f.country_id, a.country_id, a.pos, a):
			continue
		var bit2: int = T_HELI if a.type == Aircraft.Type.HELI else T_JET
		if mask & bit2 == 0:
			continue
		var d3: float = a.pos.distance_squared_to(p)
		if d3 <= r2 and (d3 <= det * det or covered(f.country_id, a.pos)):
			out.append([a, bit2, a.pos, d3])
	if mask & T_BALLISTIC:
		for m: Missile in gw.mil.missiles:
			if m.state != Missile.State.FLIGHT or m.u() < (HYPER_U if m.hyper else 0.55) or not _engage(f.country_id, m.country_id, m.ground(), m):
				continue
			var gp: Vector2 = m.ground()
			var d4: float = gp.distance_squared_to(p)
			if d4 <= r2:
				out.append([m, T_BALLISTIC, m.screen_pos(), d4])
	if mask & T_FPV:
		for u: Unit in gw.army.fpv_targets(f.country_id, p, r):
			out.append([u, T_FPV, u.pos, u.pos.distance_squared_to(p)])
	var rm: int = rule_mask(f.country_id, f.kind)
	if rm != int(POSSIBLE.get(f.kind, R_ALL)):
		out = out.filter( func(e: Array) -> bool: return (rm & rule_bit(e[0])) != 0)
	out.sort_custom( func(a: Array, b: Array) -> bool: return float(a[3]) < float(b[3]))
	return out


func _taken(t: Object) -> int:
	var n: int = 0
	for s: Dictionary in shots:
		if s["target"] == t:
			n += 1
	return n


func update(dt: float) -> void :
	_anim += dt
	if floori(gw.game_time / BOT_RULE_S) != floori((gw.game_time - dt) / BOT_RULE_S):
		_bot_rules()
	var anim: bool = _anim >= 0.25
	if anim:
		_anim = 0.0
	var mil: Military = gw.mil
	for f: Facility in mil.facilities:
		if not is_ad(f.kind) and f.kind != Facility.Kind.AD_RADAR and f.kind != Facility.Kind.AD_EW:
			continue
		if not _ready(f):
			continue
		var c: Country = gw.country_by_id(f.country_id)
		f.cd -= dt
		match f.kind:
			Facility.Kind.AD_RADAR:
				if anim and mil.has_power(f):
					f.frame_i = (f.frame_i + 1) % 8
					gw.set_obj_frame(f.main_obj, "ad_radar", f.frame_i)
				continue
			Facility.Kind.AD_EW:
				_ew(f, dt)
				continue
		var sp: Dictionary = SPEC[f.kind]
		if sp.has("ammo") and f.ammo < int(sp["ammo"]):
			f.reload_t += dt
			if f.reload_t >= float(sp["reload"]):
				f.reload_t = 0.0
				f.ammo += 1
		var gm: int = int(GUN_MAG.get(f.kind, 0))
		if gm > 0:
			if f.mag < 0 or f.mag > gm:
				f.mag = gm
			if f.mag < gm and (f.mag == 0 or gw.game_time >= f.alert_t - ALERT_S + GUN_IDLE):
				f.mag_t += dt
				if f.mag_t >= GUN_RELOAD:
					f.mag_t = 0.0
					f.mag = gm
		if f.kind == Facility.Kind.AD_SAM:
			_sam_anim(f, dt)
		if f.cd > 0.0 or (gm > 0 and f.mag == 0):
			continue
		var ts: Array = _targets(f, sp)
		if ts.is_empty():
			f.cd = 0.25
			continue
		if gw.game_time >= f.alert_t and c != null and c.is_player:
			Sfx.play("radar_ping", f.center_px())
		f.alert_t = gw.game_time + ALERT_S
		var pick: Array = _pick(f, c, ts)
		if pick.is_empty():
			f.cd = 0.25
			continue
		if bool(sp.get("gun", false)):
			if not _pay(f, c):
				continue
			_gun(f, pick, sp)
			mag_use(f)
		elif f.ammo > 0:
			if f.kind == Facility.Kind.AD_SAM and f.frame_i < 5:
				continue
			if not _pay(f, c):
				continue
			_launch(f, pick, sp)



func _gun(f: Facility, t: Array, sp: Dictionary) -> void :
	f.cd = float(sp["cd"])
	var tp: Vector2 = t[2]
	var gun: Vector2 = _muzzle(f)
	f.turret = (tp - gun).angle()
	Sfx.play("aa_gun" if f.kind == Facility.Kind.AD_SPAAG else "mg_burst", gun)
	var on: bool = gw._on_screen(gun, 80.0)
	if on:
		gw.fx.spawn("muzzle_flash", gun.round(), 6)
	var tr: Array = gw.mil.air.tracers
	var n: int = 2 if f.kind == Facility.Kind.AD_SPAAG else 1
	for k in n:
		var jit: = Vector2(float(k * 2 - 1), float(1 - k * 2)) * 1.5
		tr.append([gun + jit, tp + jit * 2.0, gw.game_time + (0.12 if f.kind == Facility.Kind.AD_SPAAG else 0.08)])
	if t[0] is Drone and (t[0] as Drone).kind == Air.KAB_KIND:
		var kt: Dictionary = gw.mil.air.kab_gun_tries
		kt[(t[0] as Drone).id] = int(kt.get((t[0] as Drone).id, 0)) + 1
	var hit: int = uav_hit(t[0], Air.ad_hit(t[0], int(sp["hit"]), true), sp)
	if Hash32.h2(f.id, int(gw.game_time * 10.0), 51) % 100 < hit:
		var aw: Variant = gw.aftermath.air if gw.aftermath != null else null
		if aw != null:
			aw.gun = true
		_kill(t[0], f.country_id, tp)
		if aw != null:
			aw.gun = false



static func uav_hit(t: Object, hit: int, sp: Dictionary) -> int:
	if t is Drone:
		var k: int = (t as Drone).kind
		if k == 0:
			return int(float(hit) * float(sp.get("uav", 1.0)))
		if k == 2:
			return int(float(hit) * float(sp.get("jet", 1.0)))
	return hit


func _muzzle(f: Facility) -> Vector2:
	if f.main_obj < 0:
		return f.center_px()
	var info: Dictionary = gw.mil._info(String(Military.SPRITES[f.kind]))
	if f.kind == Facility.Kind.AD_SPAAG and info.has("turret"):
		return gw.mil.local_px(f.main_obj, info["turret"]) + Vector2.from_angle(f.turret) * 6.0
	for k: String in ["gun", "mouth", "tube"]:
		if info.has(k):
			return gw.mil.local_px(f.main_obj, info[k])
	return f.center_px() + Vector2(0, -6)


func _launch(f: Facility, t: Array, sp: Dictionary) -> void :
	f.cd = float(sp["cd"])
	f.ammo -= 1
	var start: Vector2 = _muzzle(f)
	var kind: String = "int" if f.kind == Facility.Kind.AD_INT else "sam"
	var hit: int = uav_hit(t[0], Air.ad_hit(t[0], int(sp["hit"])), sp)
	var spd: float = float(sp["speed"])
	if int(t[1]) == T_BALLISTIC:
		hit = int(HYPER_HIT.get(f.kind, 5)) if (t[0] as Missile).hyper else int(BALLISTIC_HIT.get(f.kind, 10))
		if (t[0] as Missile).hyper:
			spd *= HYPER_SHOT_K
	var head: float = - PI * 0.5 if kind == "sam" else (t[2] - start).angle()
	shots.append({"pos": start, "heading": head, "target": t[0], "life": 9.0, "kind": kind, "c": f.country_id, "hit": hit, "speed": spd, "id": _id, "boost": 0.5 if kind == "sam" else 0.0})
	_id += 1
	Sfx.play("sam_launch" if kind == "sam" else "drone_launch", start, 0.0 if kind == "sam" else -4.0)
	if gw._on_screen(start, 80.0):
		gw.fx.spawn("launch_cloud" if kind == "sam" else "dust_s", start.round(), 5)
		if kind == "sam":
			gw.camera_shake_tiny(start)
	if f.kind == Facility.Kind.AD_SAM:
		f.lid_t = 1.2



func _sam_anim(f: Facility, dt: float) -> void :
	var want: int = 5 if gw.game_time < f.alert_t else 0
	f.frame_t += dt
	if f.lid_t > 0.0:
		f.lid_t -= dt
		var fr: int = 8 if f.lid_t > 0.6 else (7 if f.lid_t > 0.3 else 6)
		if fr != f.frame_i:
			f.frame_i = fr
			gw.set_obj_frame(f.main_obj, "ad_sam", fr)
		if f.lid_t <= 0.0:
			f.frame_i = 5
			gw.set_obj_frame(f.main_obj, "ad_sam", 5)
		return
	if f.frame_t < 0.35 or f.frame_i == want:
		return
	f.frame_t = 0.0
	f.frame_i = clampi(f.frame_i + (1 if want > f.frame_i else -1), 0, 5)
	gw.set_obj_frame(f.main_obj, "ad_sam", f.frame_i)



func _ew(f: Facility, dt: float) -> void :
	if not gw.mil.has_power(f):
		return
	if f.fx.is_empty() and gw.mil.alive(f):
		f.fx.append(gw.fx.handle(gw.fx.spawn("ew_pulse_loop", f.center_px().round(), 4, gw.game_time + 1000000000.0, true)))
	if f.cd > 0.0:
		return
	f.cd = 1.0
	var p: Vector2 = f.center_px()
	for d: Drone in gw.mil.drones:
		if d.kind != 0 or not d.airborne() or d.state == Drone.State.DONE or not _engage(f.country_id, d.country_id, d.pos, d):
			continue
		if d.pos.distance_squared_to(p) > EW_R * EW_R or d.has_meta("ew_lost"):
			continue
		if Hash32.h2(d.id, f.id, 19) % 100 < EW_JAM_CHANCE:
			d.set_meta("ew_lost", true)
			if gw._on_screen(d.pos, 40.0):
				gw.fx.spawn("spark_burst", d.pos.round(), 6)

			var lost: Array[Vector2] = [d.pos + Vector2.from_angle(d.heading + 1.2) * 60.0]
			d.route = lost
			d.route_ver += 1
			d.range_px = d.flown + 50.0
			if gw.country_by_id(d.country_id).is_player:
				gw.say(gw.country_by_id(d.country_id), Loc.mk("БПЛА %d: потеря связи (РЭБ)", [d.id]))
	for u: Unit in gw.army.fpv_targets(f.country_id, p, EW_R):
		if Hash32.h2(u.id, f.id, 23) % 100 < EW_FPV_CHANCE:
			gw.army.jam(u)


func _target_pos(t: Object) -> Vector2:
	if t is Drone:
		return (t as Drone).pos
	if t is Aircraft:
		return (t as Aircraft).pos
	if t is Missile:
		return (t as Missile).screen_pos()
	if t is Unit:
		return (t as Unit).pos
	return Vector2.INF


func _alive(t: Object) -> bool:
	if t is Drone:
		return (t as Drone).state != Drone.State.DONE
	if t is Aircraft:
		return (t as Aircraft).state != Aircraft.State.DEAD
	if t is Missile:
		return (t as Missile).state != Missile.State.DONE and gw.mil.missiles.has(t)
	if t is Unit:
		return (t as Unit).alive()
	return false


func update_shots(dt: float) -> void :
	for k in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[k]
		s["life"] = float(s["life"]) - dt
		var t: Object = s["target"]
		var pos: Vector2 = s["pos"]
		var dp: Variant = s.get("dp")
		if dp == null and t is Aircraft and not s.has("fl") and _alive(t) and pos.distance_to((t as Aircraft).pos) <= Air.FLARE_R:
			s["fl"] = 1
			if gw.mil.air.flare_try(t as Aircraft):
				dp = Air.flare_point(t as Aircraft)
				s["dp"] = dp
		if (dp == null and not _alive(t)) or float(s["life"]) <= 0.0:
			gw.fx.spawn("intercept_flash", pos.round(), 6)
			Sfx.play("intercept_pop", pos, -8.0)
			shots.remove_at(k)
			continue
		var tp: Vector2 = dp if dp != null else _target_pos(t)
		var to: Vector2 = tp - pos
		var turn: float = PI * (3.0 if s["kind"] == "sam" else 2.0) * dt
		if float(s["boost"]) > 0.0:
			s["boost"] = float(s["boost"]) - dt
		else:
			s["heading"] = wrapf(float(s["heading"]) + clampf(wrapf(to.angle() - float(s["heading"]), - PI, PI), - turn, turn), - PI, PI)
		var step: float = float(s["speed"]) * dt
		if to.length() <= step + 3.0:
			gw.fx.spawn("intercept_flash", tp.round(), 6)
			Sfx.play("intercept_pop", tp)
			if dp == null and Hash32.h2(int(s["id"]), 7, 13) % 100 < int(s["hit"]):
				_kill(t, int(s["c"]), tp)
			shots.remove_at(k)
			continue
		s["pos"] = pos + Vector2.from_angle(float(s["heading"])) * step
		if s["kind"] == "sam" and int(float(s["life"]) * 25.0) % 2 == 0:
			gw.fx.spawn("trail_s", (s["pos"] as Vector2).round(), 5)


func _kill(t: Object, by: int, at: Vector2) -> void :
	var c: Country = gw.country_by_id(by)
	if t is Drone:
		var d: Drone = t
		if d.state == Drone.State.DONE:
			return
		gw.mil.air._kill_drone(d)
		var sc: bool = _intruder_down(by, d.country_id, Loc.t("КР") if d.kind == 1 else Loc.t("БПЛА"), d)
		if c != null and sc:
			c.destroyed += 150 if d.kind == 1 else 100
	elif t is Aircraft:
		var a: Aircraft = t
		if a.state == Aircraft.State.DEAD:
			return
		gw.mil.air._shot_down(a, "сбит ПВО")
		var sc2: bool = _intruder_down(by, a.country_id, String(Air.SPEC[a.type]["name"]), a)
		if c != null and sc2:
			c.destroyed += int(Air.SPEC[a.type]["cost"])
		if c != null and c.is_player:
			gw.say(c, Loc.mk("ПВО: сбит %s", [Air.SPEC[a.type]["name"]]))
	elif t is Missile:
		var m: Missile = t
		if not gw.mil.missiles.has(m):
			return
		m.state = Missile.State.DONE
		gw.mil.missiles.erase(m)
		var sc3: bool = _intruder_down(by, m.country_id, Loc.t("ракету"), m)
		if gw.battle_watch != null:
			gw.battle_watch.note(at, 5.0, "Перехват ракеты", m.country_id)
		gw.fx.spawn("intercept_flash", at.round(), 6)
		gw.fx.spawn("explosion_m", at.round(), 6)
		Sfx.play("expl_big", at, -2.0)
		gw.fx.debris_burst(at.round(), 4, false, true)
		if gw.aftermath != null:
			gw.aftermath.air.ballistic(m, at)
		if c != null and sc3:
			c.destroyed += 400
		gw.news_m(Loc.mk("ПВО %s ПЕРЕХВАТИЛА БАЛЛИСТИЧЕСКУЮ РАКЕТУ", [Loc.name(c.name).to_upper() if c != null else ""]), "intercept_cyan")
	elif t is Unit:
		gw.army.shoot_fpv(t as Unit)



func rearm(f: Facility, c: Country) -> String:
	if not SPEC.has(f.kind) or not SPEC[f.kind].has("ammo"):
		return Loc.t("Не требуется")
	var need: int = int(SPEC[f.kind]["ammo"]) - f.ammo
	if need <= 0:
		return Loc.t("Боекомплект полон")
	var cost: int = need * REARM_COST * 2
	if c.money < cost:
		return Loc.t("Не хватает денег: нужно %d") % cost
	c.money -= cost
	f.ammo += need
	return ""





static func rule_bit(o: Object) -> int:
	if o is Drone:
		var k: int = (o as Drone).kind
		if k == 1:
			return R_CRUISE
		if k == 2:
			return R_JETUAV
		if k == Air.KAB_KIND:
			return R_KAB
		return R_UAV
	if o is Aircraft:
		return R_HELI if (o as Aircraft).type == Aircraft.Type.HELI else R_JET
	if o is Missile:
		return R_HYPER if (o as Missile).hyper else R_BALL
	if o is Unit:
		return R_FPV
	return R_RECON



static func possible(kind: int) -> int:
	return int(POSSIBLE.get(kind, 0))



func rule_mask(cid: int, kind: int) -> int:
	var i: int = AD_CLASSES.find(kind)
	if i < 0:
		return R_ALL
	var c: Country = gw.country_by_id(cid)
	var m: int = R_ALL
	if c != null and c.ad_rules.size() > i:
		m = c.ad_rules[i]
	return m & possible(kind)



func rules(c: Country) -> Dictionary:
	var out: Dictionary = {}
	for k: int in AD_CLASSES:
		out[k] = rule_mask(c.id if c != null else -1, k)
	return out




func set_ad_rule(c: Country, kind: int, mask: int) -> String:
	if c == null:
		return "country"
	var i: int = AD_CLASSES.find(kind)
	if i < 0:
		return "class"
	if mask < 0 or mask > R_ALL:
		return "mask"
	if (mask & ~ possible(kind)) != 0:
		return "locked"
	_rules_fix(c)
	c.ad_rules[i] = mask
	return ""



func set_ad_preset(c: Country, preset: String) -> String:
	if c == null:
		return "country"
	if not PRESETS.has(preset):
		return "preset"
	_rules_fix(c)
	var pr: Dictionary = PRESETS[preset]
	for i: int in AD_CLASSES.size():
		var k: int = AD_CLASSES[i]
		c.ad_rules[i] = int(pr.get(k, R_ALL)) & possible(k)
	return ""



func preset_of(c: Country) -> String:
	var r: Dictionary = rules(c)
	for p: String in PRESET_ORDER:
		var pr: Dictionary = PRESETS[p]
		var same: bool = true
		for k: int in AD_CLASSES:
			if int(r[k]) != int(pr.get(k, R_ALL)) & possible(k):
				same = false
				break
		if same:
			return p
	return ""


func _rules_fix(c: Country) -> void :
	while c.ad_rules.size() < AD_CLASSES.size():
		c.ad_rules.append(R_ALL)



func _bot_rules() -> void :
	for c: Country in gw.countries:
		if c.is_player or c.eliminated:
			continue
		var p: String = preset_of(c)
		if c.money < BOT_ECO_IN and p != "eco":
			set_ad_preset(c, "eco")
			st335["bot_eco"] = int(st335.get("bot_eco", 0)) + 1
		elif c.money > BOT_ECO_OUT and p == "eco":
			set_ad_preset(c, "all")
			st335["bot_all"] = int(st335.get("bot_all", 0)) + 1




func _pick(f: Facility, c: Country, ts: Array) -> Array:
	var sam: bool = f.kind == Facility.Kind.AD_SAM or f.kind == Facility.Kind.AD_PATRIOT
	var thrifty: bool = sam and (c == null or (c.money < SAM_THRIFT and c.missile_stock[Military.MT_SAM] <= 0))
	var alt: Array = []
	for pass_i: int in (2 if sam else 1):
		for t: Array in ts:
			if sam:
				var ch: bool = (rule_bit(t[0]) & R_CHEAP) != 0
				if ch != (pass_i == 1):
					continue
				if ch and (thrifty or _gun_covers(f.country_id, t[2], GUN_LEAD) or (t[0] is Drone and (t[0] as Drone).target != Vector2.ZERO\
				and _gun_covers(f.country_id, (t[0] as Drone).target, 0.0))):
					st335["skip_cheap"] = int(st335.get("skip_cheap", 0)) + 1
					continue
			if _taken(t[0]) == 0 or int(t[1]) == T_BALLISTIC:
				return t
			if alt.is_empty():
				alt = t
	return alt




func _gun_covers(cid: int, p: Vector2, lead: float) -> bool:
	if _gc_t != gw.game_time:
		_gc_t = gw.game_time
		_gc.clear()
		for g: Facility in gw.mil.facilities:
			if not GUN_MAG.has(g.kind) or not _ready(g) or (g.mag >= 0 and g.mag <= GUN_LOW) or (rule_mask(g.country_id, g.kind) & R_UAV) == 0:
				continue
			if not _gc.has(g.country_id):
				_gc[g.country_id] = []
			(_gc[g.country_id] as Array).append([g.center_px(), float(SPEC[g.kind]["range"])])
	for e: Array in _gc.get(cid, []):
		var r: float = float(e[1]) + lead
		if p.distance_squared_to(e[0]) <= r * r:
			return true
	return false



func _pay(f: Facility, c: Country) -> bool:
	if c == null:
		return false
	if (f.kind == Facility.Kind.AD_SAM or f.kind == Facility.Kind.AD_PATRIOT) and c.missile_stock[Military.MT_SAM] > 0:
		c.missile_stock[Military.MT_SAM] -= 1
		st335["stock"] = int(st335.get("stock", 0)) + 1
		return true
	var cost: int = int(SHOT_COST.get(f.kind, 0))
	if c.money < cost:
		f.cd = 1.0
		st335["held"] = int(st335.get("held", 0)) + 1
		if gw.game_time >= float(_broke_t.get(c.id, -1000000000.0)):
			_broke_t[c.id] = gw.game_time + BROKE_GAP
			gw.say(c, Loc.mk("ПВО молчит: нет денег на выстрелы. Огонь возобновится, когда появятся деньги"))
		return false
	c.money -= cost
	st335["paid"] = int(st335.get("paid", 0)) + cost
	if gw.econ != null:
		gw.econ.stat_add(c, "spend", "ad_fire", cost)
		gw.econ.stat_add(c, "ad_cls", String(CLASS_KEY.get(f.kind, "?")), cost)
	return true



func pay_shot(f: Facility) -> bool:
	return _pay(f, gw.country_by_id(f.country_id))



func gun_ready(f: Facility) -> bool:
	return not GUN_MAG.has(f.kind) or f.mag != 0



func mag_use(f: Facility) -> void :
	var gm: int = int(GUN_MAG.get(f.kind, 0))
	if gm <= 0:
		return
	if f.mag < 0 or f.mag > gm:
		f.mag = gm
	f.mag = maxi(0, f.mag - 1)
	f.mag_t = 0.0 if f.mag == 0 else f.mag_t




func site_state(f: Facility) -> Dictionary:
	var out: Dictionary = {"cap": 0, "left": 0, "reloading": false, "reload_left": 0.0, "shot_cost": int(SHOT_COST.get(f.kind, 0)), "stock": false}
	if GUN_MAG.has(f.kind):
		var gm: int = int(GUN_MAG[f.kind])
		var left: int = gm if f.mag < 0 else f.mag
		out["cap"] = gm
		out["left"] = left
		out["reloading"] = left == 0
		out["reload_left"] = maxf(0.0, GUN_RELOAD - f.mag_t) if left < gm else 0.0
	elif SPEC.has(f.kind) and (SPEC[f.kind] as Dictionary).has("ammo"):
		var sp: Dictionary = SPEC[f.kind]
		out["cap"] = int(sp["ammo"])
		out["left"] = f.ammo
		out["reloading"] = f.ammo <= 0
		out["reload_left"] = maxf(0.0, float(sp["reload"]) - f.reload_t) if f.ammo < int(sp["ammo"]) else 0.0
		var c: Country = gw.country_by_id(f.country_id)
		out["stock"] = c != null and f.kind != Facility.Kind.AD_INT and c.missile_stock[Military.MT_SAM] > 0
	return out




func spend_min(c: Country) -> Dictionary:
	var out: Dictionary = {"total": 0, "by_class": {}}
	if c == null or gw.econ == null:
		return out
	var st: Variant = gw.econ._stats.get(c.id)
	if not st is Dictionary:
		return out
	var ring: Array = (st as Dictionary)["ring"]
	var k: float = 60.0 / maxf(Economy.TICK, float(ring.size()) * Economy.TICK)
	var tot: int = 0
	var by: Dictionary = {}
	for slot: Dictionary in ring:
		tot += int((slot.get("spend", {}) as Dictionary).get("ad_fire", 0))
		var cl: Dictionary = slot.get("ad_cls", {})
		for key: String in cl:
			by[key] = int(by.get(key, 0)) + int(cl[key])
	out["total"] = roundi(float(tot) * k)
	for kind: int in AD_CLASSES:
		out["by_class"][kind] = roundi(float(by.get(String(CLASS_KEY[kind]), 0)) * k)
	return out
