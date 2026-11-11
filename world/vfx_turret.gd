class_name VfxTurret
extends Node2D

















const TURRET_TANK: int = 60
const TURRET_IFV: int = 25
const COOK_TANK: int = 40
const FLY_T: float = 0.78
const LIE_T: float = 900.0
const AD = preload("res://world/aftermath_draw.gd")
const WRECK_FID: int = -2
const BURN_T: float = 40.0
const EMBER_T: float = 180.0
const DEB_FLY_MAX: int = 160
const DEB_LIE_MAX: int = 300
const DEB_LIFE: float = 60.0
const MARK_MAX: int = 240
const HIT_PIECES: int = 16

const DEBRIS_KEYS: Dictionary = {
	"wood": ["deb_plank", "deb_plank", "deb_tin", "deb_brick"], 
	"panel": ["deb_slab", "deb_glass", "deb_frame", "deb_slab", "deb_glass"], 
	"brick": ["deb_brick", "deb_brick", "deb_slab", "deb_glass"], 
	"tin": ["deb_tin", "deb_tin", "deb_brick"], 
}
const RUBBLE_OF: Dictionary = {"wood": "street_rubble_c", "panel": "street_rubble_a", "brick": "street_rubble_b", "tin": "street_rubble_c"}

var gw: GameWorld
var blast: VfxBlast
var ground: GroundNode
var u314: SpriteAtlas
var deb: SpriteAtlas
var d30: SpriteAtlas
var cost_us: int = 0
var _ct: float = 0.0
var _zoom: float = 1.0
var _view: = Rect2()
var flying: Array = []
var lying: Dictionary = {}
var cooks: Array = []
var debf: Array = []
var debl: Array = []
var marks: Dictionary = {}
var rubble: Dictionary = {}
var pend: Array = []
var _wreck_t: float = 0.0
var _wrecks: Array = []
var _dmg_t: float = 0.0
var _dmg: Array = []
var _drawn: bool = false
var pillars: Array = []
var later: Array = []
var puffs: Array = []
const C_PUFF: Array = [Color("4a4540"), Color("7d776e"), Color("b8b2a8")]


class GroundNode:
	extends Node2D
	var tur: VfxTurret

	func _draw() -> void :
		tur.draw_ground(self)


func _ready() -> void :
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	u314 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_units314.png", "res://assets/sprites/atlas_units314.json", true)
	deb = SpriteAtlas.load_atlas("res://assets/sprites/atlas_debris314.png", "res://assets/sprites/atlas_debris314.json", true)
	d30 = SpriteAtlas.load_atlas("res://assets/sprites/det30_fx.png", "res://assets/sprites/det30_fx.json", true)
	ground = GroundNode.new()
	ground.name = "VfxTurretGround"
	ground.tur = self
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	call_deferred("_add_ground")


func _add_ground() -> void :
	gw.add_child(ground)
	var ob: Node = gw.get_node_or_null("Objects")
	if ob != null:
		gw.move_child(ground, ob.get_index() + 1)


func reset() -> void :
	flying.clear()
	lying.clear()
	cooks.clear()
	puffs.clear()
	later.clear()
	pillars.clear()
	debf.clear()
	debl.clear()
	marks.clear()
	rubble.clear()
	pend.clear()
	_wrecks.clear()
	_dmg.clear()


func live_count() -> int:
	return flying.size() + debf.size() + cooks.size() + puffs.size()





static func school(c: Country) -> String:
	if c == null:
		return "a"
	return "b" if c.arch == 1 or c.arch == 2 else "a"



static func blown(uid: int, type: int) -> bool:
	var h: int = Hash32.h2(uid, 314, 71) % 100
	if type == Unit.Type.TANK:
		return h < TURRET_TANK
	if type == Unit.Type.IFV:
		return h < TURRET_IFV
	return false



static func cooks_off(uid: int, type: int) -> bool:
	if blown(uid, type):
		return true
	return type == Unit.Type.TANK and Hash32.h2(uid, 314, 72) % 100 < COOK_TANK



static func lie_offset(uid: int) -> Vector2:
	var a: float = float(Hash32.h2(uid, 314, 73) % 360) * PI / 180.0
	var d: float = 8.0 + float(Hash32.h2(uid, 314, 74) % 7)
	return Vector2(cos(a) * d, sin(a) * d * 0.7).round()


static func lie_frame(uid: int) -> int:
	return Hash32.h2(uid, 314, 75) % 16


func _tkey(type: int, sch: String, what: String) -> String:
	return "%s_%s_L_%s" % ["tank" if type == Unit.Type.TANK else "ifv", sch, what]





func on_kill(u: Unit) -> void :
	if gw == null or gw.fx == null or not u.vehicle():
		return
	var p: Vector2 = u.pos.round()
	var now: float = gw.game_time
	var cook: bool = cooks_off(u.id, u.type)
	if not cook:
		gw.fx.spawn("x_fpv" if gw.fx.atlas_of.has("x_fpv") else "explosion_s", p + Vector2(0, -1), 6)
	pillars.append([u.id, u.type, p, now])
	var bl: bool = blown(u.id, u.type)
	var sch: String = school(gw.country_by_id(u.country_id))
	if bl and not u314.has(_tkey(u.type, sch, "turret")):
		bl = false
	if cook:
		cooks.append({"p": p, "t": 0.0, "n": 0, "uid": u.id, "type": u.type, "sch": sch, "k": u.frame, "blown": bl, "jet": false})
	elif bl:
		_toss(u.id, u.type, sch, p, u.frame)
	if bl and gw.get("aftermath") == null:
		lying[u.id] = {"p": p + lie_offset(u.id), "type": u.type, "sch": sch, "t0": now}



func on_hit(u: Unit, dmg: float, src: int, at: Vector2) -> void :
	if gw == null or gw.fx == null or u.hp <= 0.0 or not u.vehicle() or _zoom < 0.6:
		return
	if not _view.grow(40.0).has_point(u.pos):
		return
	if gw.vision != null and gw.vision.active() and not gw.vision.sees(u.pos):
		return
	var side: Vector2 = (u.pos - at).normalized() if at != Vector2.INF and at.distance_squared_to(u.pos) > 1.0 else Vector2.from_angle(randf() * TAU)
	var hp0: Vector2 = (u.pos - side * 2.0 + Vector2(0, -2)).round()
	if dmg >= 18.0 and (u.type == Unit.Type.TANK or u.type == Unit.Type.IFV) and randf() < 0.55:
		gw.fx.spawn("era_pop", hp0, 6)
		blast._sparks(hp0, 4, 0, 22.0)
		_debris(hp0, "deb_tin", 1, 18.0, 50.0)
	elif dmg < 18.0 and randf() < 0.6:
		var s: AnimatedSprite2D = gw.fx.spawn("rico_sparks", hp0, 6)
		if s != null:
			s.flip_h = side.x > 0.0
			if s.flip_h:
				s.offset.x = - s.offset.x - 16.0
		blast._sparks(hp0, 2, 0, 18.0)
	else:
		gw.fx.spawn("hit_small" if gw.fx.atlas_of.has("hit_small") else "spark_burst", hp0, 6)
		blast._sparks(hp0, 3, 0, 20.0)




func on_blast(p: Vector2, cls: int, _sname: String) -> void :
	if gw == null or gw.objects == null or gw.objects.chunks.is_empty() or _zoom < 0.6:
		return
	var r: int = [2, 3, 5, 8][clampi(cls, 0, 3)]
	var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	var box: = Rect2i(c - Vector2i(r + 8, r + 8), Vector2i(2 * r + 16, 2 * r + 16))
	var ids: = PackedInt32Array()
	for ck: ObjChunk in gw.objects.chunks_in_rect(box):
		for id in ck.ids:
			if gw.obj_kind[id] != GameWorld.KIND_BUILDING or gw.obj_state[id] != 0:
				continue
			var rr: Rect2i = gw.object_rect(id)
			var qx: int = clampi(c.x, rr.position.x, rr.end.x - 1)
			var qy: int = clampi(c.y, rr.position.y, rr.end.y - 1)
			if (qx - c.x) * (qx - c.x) + (qy - c.y) * (qy - c.y) <= (r + 2) * (r + 2):
				ids.append(id)
	if not ids.is_empty():
		pend.append([_ct + 0.25, p, r, ids])




func _toss(uid: int, type: int, sch: String, p: Vector2, k0: int) -> void :
	var ring: Vector2 = Vector2.ZERO
	var inf: Dictionary = u314.info(_tkey(type, sch, "turret"))
	if inf.has("ring"):
		var rg: Array = (inf["ring"] as Array)[clampi(k0, 0, 15)]
		ring = Vector2(float(rg[0]), float(rg[1]))
	flying.append({"uid": uid, "type": type, "sch": sch, "a": p + ring, "b": p + lie_offset(uid), "p0": p, "t": 0.0, "k0": k0, 
		"spin": (1 if randf() < 0.5 else -1) * randi_range(9, 14), "puff": 0.0, "h": randf_range(18.0, 22.0)})
	if gw.vfx != null and gw.vfx.blast != null:
		gw.vfx.blast._sparks(p + Vector2(0, -3), 8, 0, 34.0)


func _house_class(id: int) -> String:
	var nm: String = gw.spr_name[ArchStyle.draw_sid(gw, id)].to_lower()
	for k: String in ["house", "dacha", "cottage", "izba", "barn", "shed", "farm", "hut", "village"]:
		if nm.contains(k):
			return "wood"
	for k2: String in ["garage", "kiosk", "hangar", "shop"]:
		if nm.contains(k2):
			return "tin"
	for k3: String in ["panel", "khrush", "highrise", "tower", "glass", "business", "office", "admin", "hospital", "school", "mall", "hotel"]:
		if nm.contains(k3):
			return "panel"
	return "brick"


func _deb_atlas(nm: String) -> SpriteAtlas:
	if deb != null and deb.has(nm):
		return deb
	return gw.fx.atlas_of.get(nm, null) if gw.fx != null else null


func _debris(p: Vector2, nm: String, n: int, sp: float, up: float) -> void :
	if _deb_atlas(nm) == null:
		nm = "deb_brick"
		if _deb_atlas(nm) == null:
			return
	for k in n:
		if debf.size() >= DEB_FLY_MAX:
			return
		var ang: float = randf() * TAU
		var v: float = sp * randf_range(0.4, 1.0)
		debf.append({"g": p, "z": randf_range(2.0, 6.0), "v": Vector2(cos(ang), sin(ang) * 0.6) * v, "vz": up * randf_range(0.6, 1.2), "nm": nm, "t": randf() * 0.3, "b": false, "flip": randf() < 0.5})


func _check_houses() -> void :
	var left: int = HIT_PIECES
	for k in range(pend.size() - 1, -1, -1):
		var e: Array = pend[k]
		if _ct < float(e[0]):
			continue
		pend.remove_at(k)
		var p: Vector2 = e[1]
		var r: int = e[2]
		var pc: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
		for id: int in (e[3] as PackedInt32Array):
			if id >= gw.obj_state.size():
				continue
			var rr: Rect2i = gw.object_rect(id)
			var cls: String = _house_class(id)
			var keys: Array = DEBRIS_KEYS[cls]
			var top: = Vector2((rr.position.x + rr.size.x * 0.5) * GameWorld.CELL, rr.position.y * GameWorld.CELL + 2.0)
			var foot: = Vector2((rr.position.x + rr.size.x * 0.5) * GameWorld.CELL, rr.end.y * GameWorld.CELL)
			if gw.obj_state[id] == 1:

				var n: int = mini(left, 6 + mini(rr.size.x * rr.size.y / 4, 6))
				for q in n:
					_debris(top.lerp(foot, randf_range(0.0, 0.7)) + Vector2(randf_range(-3, 3) * rr.size.x * 0.5, 0), String(keys[q % keys.size()]), 1, 34.0, 70.0)
				left -= n
				if gw.vfx != null and gw.vfx.air != null and gw.vfx.air.has_method("billow"):
					gw.vfx.air.billow(foot + Vector2(0, -3), 2)
				if gw.fx.atlas_of.has("dust_s"):
					gw.fx.spawn("dust_s", foot + Vector2(randf_range(-4, 4), -2), 6)
				var rp: Vector2 = foot + Vector2(float(Hash32.h2(id, 3, 9) % 7) - 3.0, 2.0)
				if rubble.size() < MARK_MAX and not _on_roof(rp):
					rubble[id] = [RUBBLE_OF[cls], rp]
				marks.erase(id)
			elif gw.obj_state[id] == 0 and left > 0:

				var qx: int = clampi(pc.x, rr.position.x, rr.end.x - 1)
				var qy: int = clampi(pc.y, rr.position.y, rr.end.y - 1)
				var d2: int = (qx - pc.x) * (qx - pc.x) + (qy - pc.y) * (qy - pc.y)
				if d2 > (r + 2) * (r + 2):
					continue
				var hitp: = Vector2(qx * GameWorld.CELL + 2, qy * GameWorld.CELL + 1)
				var n2: int = mini(left, 2 + randi() % 3)
				for q2 in n2:
					_debris(hitp, String(keys[q2 % keys.size()]), 1, 22.0, 45.0)
				left -= n2
				_facade_mark(id, hitp, d2 <= 4)



func _facade_mark(id: int, hitp: Vector2, close: bool) -> void :
	if DmgStages.on and DmgStages.FACADE_SPRITES and DmgStages.tab.has(ArchStyle.draw_sid(gw, id)):
		return
	var arr: Array = marks.get(id, [])
	if arr.size() >= 3 or (marks.size() >= MARK_MAX and arr.is_empty()):
		return
	var v: String = "a" if (id + arr.size()) % 2 == 0 else "b"
	var sz: String = ["s", "m", "l"][clampi(gw.object_rect(id).size.x / 3, 0, 2)]
	var nm: String = ("fac_breach_%s%s" if close else "fac_soot_%s%s") % [sz, v]
	if not deb.has(nm):
		nm = ("hole_%s" % ["a", "b", "c", "d"][(id + arr.size()) % 4]) if close else ("soot_%s" % ["a", "b", "c"][(id + arr.size()) % 3])
	var org: Vector2 = gw.obj_origin(id)
	arr.append([nm, (hitp - org + Vector2(0, -3)).round(), gw.game_time])
	marks[id] = arr


func _process(delta: float) -> void :
	if gw == null or gw.camera == null:
		return
	var us: int = Time.get_ticks_usec()
	var cam: MapCamera = gw.camera
	_zoom = cam.zoom.x
	var half: Vector2 = cam.view_size() * 0.5 / _zoom
	_view = Rect2(cam.position - half, half * 2.0)
	var dt: float = 0.0 if VfxBlast.hitstop > 0.0 else delta * FxLayer.cosmetic_scale(gw.time_scale)
	_ct += dt
	if not pend.is_empty():
		_check_houses()
	if not pillars.is_empty():
		_pillars()
	if dt > 0.0:
		for k in range(puffs.size() - 1, -1, -1):
			puffs[k][1] = float(puffs[k][1]) + dt
			puffs[k][0] = (puffs[k][0] as Vector2) + Vector2(Vfx.wind.x * 0.3, -6.0) * dt
			if float(puffs[k][1]) > 0.9:
				puffs.remove_at(k)
		_step_cooks(dt)
		_step_turrets(dt)
		_step_debris(dt)

	_wreck_t -= delta
	if _wreck_t <= 0.0:
		_wreck_t = 0.5
		_refresh_wrecks()
		var now: float = gw.game_time
		for k0 in range(later.size() - 1, -1, -1):
			var e0: Array = later[k0]
			if now >= float(e0[0]) or now < float(e0[0]) - EMBER_T:
				later.remove_at(k0)
				if now < float(e0[4]) and now >= float(e0[0]):
					gw.fx.spawn(String(e0[1]), e0[2], int(e0[3]), float(e0[4]), true)
		for k in range(debl.size() - 1, -1, -1):
			if now - float(debl[k][3]) > DEB_LIFE or now < float(debl[k][3]) - 1.0:
				debl.remove_at(k)
		for uid: Variant in lying.keys():
			if now - float(lying[uid]["t0"]) > LIE_T or now < float(lying[uid]["t0"]) - 1.0:
				lying.erase(uid)
		for id: Variant in rubble.keys():
			if int(id) >= gw.obj_state.size() or gw.obj_state[int(id)] != 1:
				rubble.erase(id)
		for id2: Variant in marks.keys():
			if int(id2) >= gw.obj_state.size() or gw.obj_state[int(id2)] != 0:
				marks.erase(id2)
		ground.queue_redraw()
	_dmg_t -= delta
	if _dmg_t <= 0.0:
		_dmg_t = 0.4
		_scan_damaged()
	if not debf.is_empty() or not flying.is_empty():
		ground.queue_redraw()
	var busy: bool = not flying.is_empty() or not debf.is_empty() or not puffs.is_empty() or not _dmg.is_empty()
	if busy or _drawn:
		queue_redraw()
	_drawn = busy
	cost_us = Time.get_ticks_usec() - us


func _refresh_wrecks() -> void :
	_wrecks.clear()
	var am: Variant = gw.get("aftermath")
	if am == null:
		return
	var v: Rect2 = _view.grow(40.0)
	for w: Dictionary in am.wrecks:
		var t: int = int(w.get("type", -1))
		var uid: int = int(w.get("uid", -1))
		if (t == Unit.Type.TANK or t == Unit.Type.IFV) and blown(uid, t) and v.has_point(w["p"]):
			_wrecks.append([uid, AD.draw_pos(gw, w), t, school(gw.country_by_id(int(w.get("c", 0))))])


func _scan_damaged() -> void :
	_dmg.clear()
	if gw.army == null or _zoom < 0.6:
		return
	var v: Rect2 = _view.grow(20.0)
	for u: Unit in gw.army.units:
		if not u.alive() or not u.vehicle() or u.hp >= u.max_hp * 0.5 or not v.has_point(u.pos):
			continue
		if gw.vision != null and gw.vision.active() and not gw.vision.sees(u.pos):
			continue
		_dmg.append([u, 2 if u.hp < u.max_hp * 0.25 else 1])
		if _dmg.size() >= 40:
			return


func _step_cooks(dt: float) -> void :
	for k in range(cooks.size() - 1, -1, -1):
		var c: Dictionary = cooks[k]
		var t0: float = float(c["t"])
		var t: float = t0 + dt
		c["t"] = t
		var p: Vector2 = c["p"]

		for i in 3:
			var ti: float = 0.15 * float(i)
			if (t0 < ti or (i == 0 and t0 == 0.0)) and t >= ti:
				gw.fx.spawn("x_fpv" if gw.fx.atlas_of.has("x_fpv") else "hit_small", p + Vector2(randf_range(-2, 2), randf_range(-3, 0)), 6)
				blast._sparks(p + Vector2(0, -3), 5, 0, 26.0)
		if bool(c["blown"]) and t0 < 0.2 and t >= 0.2:
			_toss(int(c["uid"]), int(c["type"]), String(c["sch"]), p, int(c["k"]))
		if t0 < 0.45 and t >= 0.45:
			var jet: float = randf_range(2.0, 4.0)
			gw.fx.spawn("cookoff_jet_loop", _wpos(int(c["uid"]), p) + Vector2(0, -2), 6, gw.game_time + jet, true)
			c["jet_end"] = t + jet
		if t >= 0.45 and t < float(c.get("jet_end", 0.0)):
			c["n"] = float(c["n"]) + dt
			if float(c["n"]) >= 0.08 and _view.grow(30.0).has_point(p):
				c["n"] = 0.0
				blast._add_one(p + Vector2(randf_range(-1, 1), -24.0), 6.0, Vector3(randf_range(-14, 14), randf_range(-4, 4), randf_range(30.0, 60.0)), randf_range(0.5, 0.9), 0)
		if t >= 0.45 and t >= float(c.get("jet_end", 0.0)):
			cooks.remove_at(k)


func _step_turrets(dt: float) -> void :
	for k in range(flying.size() - 1, -1, -1):
		var f: Dictionary = flying[k]
		var t: float = float(f["t"]) + dt
		f["t"] = t
		var u: float = t / FLY_T
		f["b"] = _wpos(int(f["uid"]), f["p0"]) + lie_offset(int(f["uid"]))
		if u >= 1.0:
			flying.remove_at(k)
			var b: Vector2 = f["b"]
			if gw.fx.atlas_of.has("dust_s"):
				gw.fx.spawn("dust_s", b + Vector2(0, 1), 6)
			blast._sparks(b, 3, 0, 18.0)
			for q in 4:
				blast._add_one(b, 1.0, Vector3(randf_range(-10, 10), randf_range(-4, 4), randf_range(20.0, 40.0)), randf_range(0.4, 0.7), 4)
			Sfx.play("expl_small", b, -14.0)
			ground.queue_redraw()
			continue
		f["puff"] = float(f["puff"]) + dt
		if float(f["puff"]) >= 0.05 and puffs.size() < 60:
			f["puff"] = 0.0
			var g: Vector2 = (f["a"] as Vector2).lerp(f["b"], u)
			var z: float = float(f["h"]) * 4.0 * u * (1.0 - u)
			puffs.append([g + Vector2(randf_range(-1, 1), - z - 1), 0.0])


func _step_debris(dt: float) -> void :
	var now: float = gw.game_time
	for k in range(debf.size() - 1, -1, -1):
		var d: Dictionary = debf[k]
		d["g"] = Vector2(d["g"]) + Vector2(d["v"]) * dt
		d["vz"] = float(d["vz"]) - 320.0 * dt
		d["z"] = float(d["z"]) + float(d["vz"]) * dt
		d["t"] = float(d["t"]) + dt
		if float(d["z"]) <= 0.0:
			if not bool(d["b"]) and float(d["vz"]) < -40.0:
				d["b"] = true
				d["z"] = 0.0
				d["vz"] = - float(d["vz"]) * 0.3
				d["v"] = Vector2(d["v"]) * 0.5
				continue
			debf.remove_at(k)
			if _on_roof(Vector2(d["g"])):
				continue
			if debl.size() >= DEB_LIE_MAX:
				debl.remove_at(0)
			debl.append([d["nm"], (Vector2(d["g"])).round(), int(float(d["t"]) * 12.0) % 4, now, bool(d["flip"])])



func _wpos(uid: int, fb: Vector2) -> Vector2:
	var am: Variant = gw.get("aftermath")
	if am == null:
		return fb
	for w: Dictionary in am.wrecks:
		if int(w.get("uid", -1)) == uid:
			return AD.draw_pos(gw, w)
	return fb





func _pillars() -> void :
	var now: float = gw.game_time
	for k in range(pillars.size() - 1, -1, -1):
		var e: Array = pillars[k]
		var uid: int = e[0]
		var t0: float = e[3]
		var p: Vector2 = _wpos(uid, Vector2.INF)
		if p == Vector2.INF:
			if now - t0 < 1.0 and now >= t0:
				continue
			p = e[2]
		pillars.remove_at(k)
		gw.fx.spawn("fire_small", p + Vector2(0, -1), 4, t0 + BURN_T, true)
		if int(e[1]) == Unit.Type.TANK:
			gw.fx.spawn("fire_small", p + Vector2(1, -6), 4, t0 + BURN_T * 0.75, true)
		gw.fx.spawn("smoke_black_loop", p + Vector2(0, -12), 5, t0 + BURN_T, true)
		later.append([t0 + BURN_T - 6.0, "fire_d_loop" if gw.fx.atlas_of.has("fire_d_loop") else "fire_small", p + Vector2(-1, 1), 3, t0 + EMBER_T])
		if Hash32.h2(uid, 314, 76) % 2 == 0:
			later.append([t0 + BURN_T - 4.0, "dmg_smoke_loop", p + Vector2(0, -3), 3, t0 + EMBER_T])
		if gw.vfx != null:
			gw.vfx.add_column(p + Vector2(0, -6), 0.6, BURN_T - (now - t0), false, WRECK_FID)



func _on_roof(p: Vector2) -> bool:
	if gw.objects == null or gw.objects.chunks.is_empty():
		return false
	var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	var seen: Dictionary = {}
	for dy in [0, 8, 16]:
		var ck: ObjChunk = gw.objects.chunk_at_cell(c.x, c.y + dy)
		if seen.has(ck):
			continue
		seen[ck] = true
		for id in ck.ids:
			if gw.obj_kind[id] != GameWorld.KIND_BUILDING or gw.obj_state[id] != 0:
				continue
			var r: = Rect2(gw.obj_origin(id), gw.spr_rect[gw.obj_spr[id]].size)
			if r.has_point(p):
				return true
	return false




func _spr(ci: CanvasItem, a: SpriteAtlas, nm: String, fr: int, p: Vector2, mod: = Color.WHITE, flip: bool = false) -> void :
	var inf: Dictionary = a.info(nm)
	var src: Rect2 = a.rect(nm, fr % maxi(1, int(inf["frames"])))
	var pos: Vector2 = (p - Vector2(float(inf["ax"]), float(inf["ay"]))).round()
	if flip:
		ci.draw_texture_rect_region(a.texture, Rect2(pos + Vector2(src.size.x, 0), Vector2( - src.size.x, src.size.y)), src, mod)
	else:
		ci.draw_texture_rect_region(a.texture, Rect2(pos, src.size), src, mod)



func _draw() -> void :
	var us: int = Time.get_ticks_usec()
	var v: Rect2 = _view.grow(24.0)
	var fog: bool = gw.vision != null and gw.vision.active()
	for pf: Array in puffs:
		var age: float = pf[1]
		var r: float = 1.0 + age * 3.0
		var c: Color = C_PUFF[mini(2, int(age / 0.3))]
		var q: Vector2 = (pf[0] as Vector2).round()
		draw_rect(Rect2(q - Vector2(r, r * 0.8).round(), (Vector2(r, r * 0.8) * 2.0).round()), c)
	for f: Dictionary in flying:
		var u: float = clampf(float(f["t"]) / FLY_T, 0.0, 1.0)
		var g: Vector2 = (f["a"] as Vector2).lerp(f["b"], u)
		if not v.has_point(g) or (fog and not gw.vision.sees(g)):
			continue
		var z: float = float(f["h"]) * 4.0 * u * (1.0 - u)
		var k: int = posmod(int(f["k0"]) + int(float(f["spin"]) * float(f["t"]) * 1.6), 16)
		var nm: String = _tkey(int(f["type"]), String(f["sch"]), "turret")
		var sh: String = nm + "_shadow"
		if u314.has(sh):
			_spr(self, u314, sh, k, g, Color(1, 1, 1, 0.6))
		var burnt: String = nm + "_burnt"
		_spr(self, u314, burnt if u > 0.35 and u314.has(burnt) else nm, k, g + Vector2(0, - z))
	for d: Dictionary in debf:
		var p: Vector2 = d["g"]
		if not v.has_point(p) or (fog and not gw.vision.sees(p)):
			continue
		var a: SpriteAtlas = _deb_atlas(String(d["nm"]))
		if a != null:
			_spr(self, a, String(d["nm"]), int(float(d["t"]) * 12.0), p + Vector2(0, - float(d["z"])), Color.WHITE, bool(d["flip"]))

	var x3: SpriteAtlas = gw.fx.atlas_of.get("dmg_smoke_loop", null) if gw.fx != null else null
	var t: float = FxLayer.vt
	for e: Array in _dmg:
		var un: Unit = e[0]
		if not is_instance_valid(un) or not un.alive():
			continue
		var back: Vector2 = - Vector2.from_angle(un.heading) * 3.0
		var rp: Vector2 = un.pos + back
		if int(e[1]) >= 2 and d30 != null and d30.has("fire_k_loop"):
			_spr(self, d30, "fire_k_loop", int(t * 12.0 + float(un.id)), rp + Vector2(0, 1))
		if x3 != null:
			_spr(self, x3, "dmg_smoke_loop", int(t * 8.0 + float(un.id)), rp + Vector2(0, -1))
	cost_us += Time.get_ticks_usec() - us



func draw_ground(ci: CanvasItem) -> void :
	if gw == null:
		return
	var v: Rect2 = _view.grow(30.0)
	var fog: bool = gw.vision != null and gw.vision.active()
	var flyset: Dictionary = {}
	for f: Dictionary in flying:
		flyset[int(f["uid"])] = true
	for c: Dictionary in cooks:
		if bool(c["blown"]) and float(c["t"]) < 0.2:
			flyset[int(c["uid"])] = true

	for w: Array in _wrecks:
		var uid: int = w[0]
		if flyset.has(uid):
			continue
		var p: Vector2 = (w[1] as Vector2) + lie_offset(uid)
		if fog and not gw.vision.sees(p):
			continue
		var nm: String = _tkey(int(w[2]), String(w[3]), "turret_burnt")
		if u314.has(nm):
			_spr(ci, u314, nm, lie_frame(uid), p)
	for uid2: Variant in lying:
		if flyset.has(int(uid2)):
			continue
		var l: Dictionary = lying[uid2]
		var p2: Vector2 = l["p"]
		if not v.has_point(p2) or (fog and not gw.vision.sees(p2)):
			continue
		var nm2: String = _tkey(int(l["type"]), String(l["sch"]), "turret_burnt")
		if u314.has(nm2):
			_spr(ci, u314, nm2, lie_frame(int(uid2)), p2)

	for id: Variant in rubble:
		var r: Array = rubble[id]
		var p3: Vector2 = r[1]
		if v.has_point(p3) and deb.has(String(r[0])) and not (fog and not gw.vision.sees(p3)):
			_spr(ci, deb, String(r[0]), 0, p3)

	var hid: bool = gw.obj_hidden.size() >= gw.obj_state.size()
	for id2: Variant in marks:
		var oid: int = int(id2)
		if hid and gw.obj_hidden[oid] != 0:
			continue
		var org: Vector2 = gw.obj_origin(oid)
		if not v.has_point(org):
			continue
		for m: Array in marks[id2]:
			var a: SpriteAtlas = _deb_atlas(String(m[0]))
			if a != null:
				_spr(ci, a, String(m[0]), 0, org + (m[1] as Vector2))

	var now: float = gw.game_time
	for d: Array in debl:
		var p4: Vector2 = d[1]
		if not v.has_point(p4) or (fog and not gw.vision.sees(p4)):
			continue
		var a2: SpriteAtlas = _deb_atlas(String(d[0]))
		if a2 == null:
			continue
		var age: float = now - float(d[3])
		var al: float = 1.0 if age < DEB_LIFE - 10.0 else clampf(ceilf((DEB_LIFE - age) / 10.0 * 3.0) / 3.0, 0.0, 1.0)
		_spr(ci, a2, String(d[0]), int(d[2]), p4, Color(1, 1, 1, al), bool(d[4]))
