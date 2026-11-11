class_name NavySfx
extends RefCounted











const ENG_KEYS: Array = ["nv_eng0", "nv_eng1", "nv_eng2"]
const WASH_KEYS: Array = ["nv_wash0", "nv_wash1"]
const FIRE_KEYS: Array = ["nv_fire0", "nv_fire1"]
const BASE_KEYS: Array = ["nv_base"]
const LOOP_K: float = 1.3
const BASE_K: float = 1.4
const FLYBY_K: float = 0.7
const BASE_SCAN: float = 1.0

const EV_IDS: Dictionary = {
	"launch": ["asm_launch", "alarm_general_quarters", "convoy_horn"], "cm_launch": ["vls_hatch_open", "cruise_launch_vls"], 
	"sam": ["ship_sam_launch"], "sam_cm": ["ship_sam_launch"], "decoy": ["chaff_burst", "decoy_flares"], "ciws": ["ciws_burst"], 
	"intercepted": ["intercept_pop"], "cm_intercepted": ["intercept_pop"], "gun": ["naval_gun", "splash_big"], 
	"hit": ["ship_hit", "convoy_horn"], "miss": ["splash_big"], "sink": ["sea_explosion", "ship_sinking"], 
	"convoy_sunk": ["sea_explosion", "ship_sinking"], "built": ["warship_horn"], "rearm": ["dock_crane"], "repair": ["repair_work"], 
}

var sfx: Sfx
var gw: GameWorld
var navy: Navy = null
var counts: Dictionary = {"events": 0, "unmapped": 0, "plays": 0, "flyby": 0, "delayed": 0}
var by_kind: Dictionary = {}
var slots: Dictionary = {}
var _pending: Array = []
var _flyby: Dictionary = {}
var _bases: Array = []
var _base_t: float = 0.0


func _init(owner: Sfx, world: GameWorld) -> void :
	sfx = owner
	gw = world
	for key: String in ENG_KEYS + WASH_KEYS + FIRE_KEYS + BASE_KEYS:
		slots[key] = 0


func stop() -> void :
	if navy != null and navy.event.is_connected(_on_event):
		navy.event.disconnect(_on_event)
	navy = null
	_pending.clear()
	_flyby.clear()
	for key: String in slots:
		slots[key] = 0
		Sfx.loop(key, "", false)


func tick(dt: float) -> void :
	var nv: Navy = gw.navy if is_instance_valid(gw) else null
	if nv != navy:
		if navy != null and navy.event.is_connected(_on_event):
			navy.event.disconnect(_on_event)
		navy = nv
		_flyby.clear()
		if navy != null:
			navy.event.connect(_on_event)
	_flush(Time.get_ticks_msec())
	if navy == null:
		return
	var paused: bool = gw.time_scale <= 0.0 or not gw.is_inside_tree() or gw.get_tree().paused
	_ship_loops(paused)
	_base_t -= dt
	if _base_t <= 0.0:
		_base_t = BASE_SCAN
		_scan_bases()
	_base_loop(paused)
	if not paused:
		_flybys()




func _friendly(cid: int) -> bool:
	var p: Country = gw.player
	return p != null and (cid == p.id or (gw.diplo != null and gw.diplo.allied(p.id, cid)))


func _snd(id: String, at: Vector2, vol: float, seen: bool, delay: float = 0.0) -> void :
	if not at.is_finite():
		return
	if delay > 0.0:
		_pending.append([Time.get_ticks_msec() + int(delay * 1000.0), id, at, vol, seen])
		counts["delayed"] = int(counts["delayed"]) + 1
		return
	counts["plays"] = int(counts["plays"]) + 1
	if seen:
		Sfx.play_seen(id, at, vol)
	else:
		Sfx.play(id, at, vol)


func _flush(now: int) -> void :
	if _pending.is_empty():
		return
	for k in range(_pending.size() - 1, -1, -1):
		var e: Array = _pending[k]
		if now >= int(e[0]):
			_pending.remove_at(k)
			_snd(String(e[1]), e[2], float(e[3]), bool(e[4]))
	if _pending.size() > 64:
		_pending = _pending.slice(_pending.size() - 32)


func _ship_pos(id: int, fallback: Vector2) -> Vector2:
	var s: Ship = navy.ship(id) if navy != null and id > 0 else null
	return s.pos if s != null else fallback


func _on_event(ev: Dictionary) -> void :
	var k: String = String(ev.get("k", ""))
	counts["events"] = int(counts["events"]) + 1
	by_kind[k] = int(by_kind.get(k, 0)) + 1
	var pos: Variant = ev.get("pos", Vector2.INF)
	var p: Vector2 = pos if pos is Vector2 else Vector2.INF
	var c: int = int(ev.get("c", -1))
	match k:
		"launch":
			_snd("asm_launch", p, 0.0, _friendly(c))
			var tg: int = int(ev.get("tgt", 0))
			if gw.player != null and int(ev.get("victim", -1)) == gw.player.id:
				if tg > 0 and navy.ship(tg) != null:
					_snd("alarm_general_quarters", navy.ship(tg).pos, 0.0, true, 0.3)
				elif tg < 0 and not navy.convoy( - tg).is_empty():
					_snd("convoy_horn", navy.convoy( - tg).get("pos", p), 0.0, true, 0.4)
		"cm_launch":
			var f: bool = _friendly(c)
			_snd("vls_hatch_open", p, 0.0, f)
			_snd("cruise_launch_vls", p, 0.0, f, 0.25)
		"sam", "sam_cm":
			_snd("ship_sam_launch", _ship_pos(int(ev.get("ship", 0)), p), 0.0, _friendly(c))
		"intercepted", "cm_intercepted":
			_snd("intercept_pop", p, 0.0, _friendly(c))
		"gun":
			var g: bool = _friendly(c)
			_snd("naval_gun", p, 0.0, g)
			var tp: Variant = ev.get("tp", null)
			if tp is Vector2:
				_snd("splash_big", tp, -8.0, g or _friendly(int(ev.get("victim", -1))), 0.35)
		"decoy":
			var df: bool = _friendly(c)
			_snd("chaff_burst", p, 0.0, df)
			_snd("decoy_flares", p, 0.0, df, 0.15)
		"ciws":
			_snd("ciws_burst", p, 0.0, _friendly(c))
		"hit":
			var tg2: int = int(ev.get("tgt", 0))
			var mine: bool = _friendly(int(ev.get("victim", -1)))
			if tg2 < 0 and mine and float(navy.convoy( - tg2).get("hp", 0.0)) > 0.0:
				_snd("convoy_horn", p, -2.0, true, 0.6)
			_snd("ship_hit", p, 0.0, mine or _friendly(c))
		"miss":
			_snd("splash_big", p, 0.0, false)
		"sink", "convoy_sunk":
			var f2: bool = _friendly(c)
			_snd("sea_explosion", p, 0.0, f2)
			_snd("ship_sinking", p, 0.0, f2, 0.5)
		"built":
			_snd("warship_horn", p, 0.0, _friendly(c))
		"rearm":
			_snd("dock_crane", p, 0.0, _friendly(c))
		"repair":
			_snd("repair_work", p, 0.0, _friendly(c))
		_:
			counts["unmapped"] = int(counts["unmapped"]) + 1



func _flybys() -> void :
	if navy.msl.is_empty():
		if not _flyby.is_empty():
			_flyby.clear()
		return
	for m: Dictionary in navy.msl:
		var id: int = int(m["id"])
		if _flyby.has(id):
			continue
		var mp: Vector2 = m["pos"]
		var k: float = sfx._dist_k(mp)
		if k < 0.0 or k > FLYBY_K:
			continue
		var f: bool = _friendly(int(m["c"]))
		if not f and not sfx._visible(mp, true):
			continue
		_flyby[id] = true
		counts["flyby"] = int(counts["flyby"]) + 1
		_snd("asm_flyby", mp, 0.0, f)
	if _flyby.size() > 128:
		var live: Dictionary = {}
		for m2: Dictionary in navy.msl:
			if _flyby.has(int(m2["id"])):
				live[int(m2["id"])] = true
		_flyby = live





func _assign(keys: Array, clip: String, want: Array) -> void :
	var ids: Dictionary = {}
	for w: Array in want:
		ids[int(w[1])] = w
	var free: Array = []
	for key: String in keys:
		var cur: int = int(slots[key])
		if cur != 0 and ids.has(cur):
			var w0: Array = ids[cur]
			ids.erase(cur)
			Sfx.loop(key, clip, true, w0[2], float(w0[3]))
		else:
			free.append(key)
	var rest: Array = []
	for w1: Array in want:
		if ids.has(int(w1[1])):
			rest.append(w1)
	for key2: String in free:
		if rest.is_empty():
			if int(slots[key2]) != 0:
				slots[key2] = 0
				Sfx.loop(key2, "", false)
			continue
		var w2: Array = rest.pop_front()
		slots[key2] = int(w2[1])
		Sfx.loop(key2, clip, true, w2[2], float(w2[3]))


func _ship_loops(paused: bool) -> void :
	var eng: Array = []
	var wash: Array = []
	var fire: Array = []
	if not paused:
		for s: Ship in navy.ships:
			if not s.alive():
				continue
			var k: float = sfx._dist_k(s.pos)
			if k < 0.0 or k > LOOP_K:
				continue
			if not _friendly(s.c) and not sfx._visible(s.pos, false):
				continue
			var top: float = float(Navy.HULLS[clampi(s.hull, 0, 2)]["speed"])
			var sp: float = clampf(s.speed / maxf(top, 1.0), 0.0, 1.0)
			eng.append([k, s.id, s.pos, -5.0 + 5.0 * sp + 1.5 * float(s.hull)])
			if sp > 0.2:
				wash.append([k, s.id, s.pos, linear_to_db(clampf(sp, 0.25, 1.0))])
			if not s.fires.is_empty():
				fire.append([k, s.id, s.pos, -3.0 + 2.5 * float(mini(s.fires.size(), 3) - 1)])
	var by_k: = func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0])
	eng.sort_custom(by_k)
	wash.sort_custom(by_k)
	fire.sort_custom(by_k)
	_assign(ENG_KEYS, "ship_engine_loop", eng.slice(0, ENG_KEYS.size()))
	_assign(WASH_KEYS, "bow_wash_loop", wash.slice(0, WASH_KEYS.size()))
	_assign(FIRE_KEYS, "ship_fire_loop", fire.slice(0, FIRE_KEYS.size()))


func _scan_bases() -> void :
	_bases.clear()
	if gw.mil == null:
		return
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.NAVAL_BASE and gw.mil.alive(f):
			_bases.append([f.center_px(), f.id, f.country_id])


func _base_loop(paused: bool) -> void :
	var best: Array = []
	if not paused:
		for b: Array in _bases:
			var k: float = sfx._dist_k(b[0])
			if k < 0.0 or k > BASE_K or (best.size() > 0 and k >= float(best[0])):
				continue
			if not _friendly(int(b[2])) and not sfx._visible(b[0], false):
				continue
			best = [k, int(b[1]) + 1, b[0], 0.0]
	_assign(BASE_KEYS, "navbase_ambient_loop", [best] if best.size() > 0 else [])



func state() -> Dictionary:
	var used: int = 0
	for key: String in slots:
		used += 1 if int(slots[key]) != 0 else 0
	return {"counts": counts.duplicate(), "by_kind": by_kind.duplicate(), "slots_used": used, "pending": _pending.size()}
