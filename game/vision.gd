class_name Vision
extends RefCounted











signal discovered(f: Facility)

const GRID: int = 16
const DT: float = 0.25
const CITY_PAD: int = 8
const R_FAC: float = 80.0
const R_RADAR: float = 220.0
const R_UNIT: float = 120.0
const R_RECON: float = 170.0
const R_FPV: float = 60.0
const R_DRONE: float = 140.0
const R_JET: float = 180.0
const R_AIRCRAFT: float = 220.0
const R_CRUISE: float = 60.0
const R_SHIP: Array = [260.0, 320.0, 380.0]


const SAT_COST: int = 400
const SAT_STEP: int = 100
const SAT_WINDOW: float = 120.0
const SAT_R: float = 220.0
const SAT_TIME: float = 14.0
const SAT_CD: float = 6.0
const NEWS_GAP: float = 2.5

const IMPORTANT: Array = [Facility.Kind.MISSILE_FACTORY, Facility.Kind.AIRFIELD, Facility.Kind.TEL, 
	Facility.Kind.AD_SAM, Facility.Kind.AD_PATRIOT, Facility.Kind.BARRACKS, Facility.Kind.DRONE_PORT]

const STATIC_KINDS: Array = [Facility.Kind.TRENCH_H, Facility.Kind.TRENCH_V, Facility.Kind.TEETH_H, 
	Facility.Kind.TEETH_V, Facility.Kind.DUGOUT]

var gw: GameWorld
var enabled: bool = true
var gw_w: int = 0
var gw_h: int = 0
var img: Image
var air_img: Image
var vis: PackedByteArray = PackedByteArray()
var air: PackedByteArray = PackedByteArray()
var ver: int = 0
var vis_ver: int = 0
var ms: float = 0.0
var ms_max: float = 0.0
var discovered_n: int = 0

var _known: PackedByteArray = PackedByteArray()
var _shown: PackedByteArray = PackedByteArray()
var _dead: PackedByteArray = PackedByteArray()
var _pos: PackedVector2Array = PackedVector2Array()
var _seen_t: PackedFloat32Array = PackedFloat32Array()
var _friend: PackedByteArray = PackedByteArray()
var _sea: PackedVector3Array = PackedVector3Array()
var _pid: int = -1
var _allies: bool = false
var _t: float = 0.0
var _stamps: Dictionary = {}
var _done: Dictionary = {}
var _news_q: Array = []
var _news_t: float = 0.0
var _all_shown: bool = true
var _markers: Array = []
var _markers_ver: int = -1

var reveals: Array = []
var _sat_uses: PackedFloat32Array = PackedFloat32Array()
var satellite_cd: float = 0.0


func _init(world: GameWorld) -> void :
	gw = world
	enabled = GameConfig.fog
	gw.relations_changed.connect(_on_relations)



func _on_relations() -> void :
	_t = 0.0



func active() -> bool:
	return enabled and gw.player != null and not vis.is_empty()



func set_enabled(on: bool) -> void :
	enabled = on
	GameConfig.fog = on
	_t = 0.0
	ver += 1





func sees(p: Vector2) -> bool:
	if not active():
		return true
	var x: int = int(p.x) / GRID
	var y: int = int(p.y) / GRID
	if x < 0 or y < 0 or x >= gw_w or y >= gw_h:
		return false
	return vis[y * gw_w + x] != 0 or _ally_land(p)



func sees_air(p: Vector2) -> bool:
	if not active():
		return true
	var x: int = int(p.x) / GRID
	var y: int = int(p.y) / GRID
	if x < 0 or y < 0 or x >= gw_w or y >= gw_h:
		return false
	var i: int = y * gw_w + x
	return vis[i] != 0 or air[i] != 0 or _ally_land(p)




func _ally_land(p: Vector2) -> bool:
	if not _allies:
		return false
	var d: WorldData = gw.data
	var cx: int = int(p.x) / GameWorld.CELL
	var cy: int = int(p.y) / GameWorld.CELL
	if d == null or cx < 0 or cy < 0 or cx >= d.w or cy >= d.h:
		return false
	var o: int = d.owners[cy * d.w + cx]
	return o > 0 and o != gw.player.id and o < _friend.size() and _friend[o] != 0



func shows_ship(country_id: int, p: Vector2) -> bool:
	if not active() or friend(country_id) or sees(p):
		return true
	for v: Vector3 in _sea:
		if (v.x - p.x) * (v.x - p.x) + (v.y - p.y) * (v.y - p.y) <= v.z * v.z:
			return true
	return false



func friend(country_id: int) -> bool:
	if gw.player == null:
		return true
	if country_id == gw.player.id:
		return true
	return country_id >= 0 and country_id < _friend.size() and _friend[country_id] != 0



func shows(country_id: int, p: Vector2) -> bool:
	return not active() or friend(country_id) or sees(p)



func shows_air(country_id: int, p: Vector2) -> bool:
	return not active() or friend(country_id) or sees_air(p)



func known(f: Facility) -> bool:
	if not active() or friend(f.country_id):
		return true
	return f.id < _known.size() and _known[f.id] != 0



func fac_shown(f: Facility) -> bool:
	if not active():
		return true
	if f.id >= _shown.size():
		return friend(f.country_id)
	return _shown[f.id] != 0



func last_pos(f: Facility) -> Vector2:
	if f.id < _pos.size() and _known[f.id] != 0:
		return _pos[f.id]
	return f.center_px()



func last_seen(f: Facility) -> float:
	if friend(f.country_id) or not active():
		return gw.game_time
	return _seen_t[f.id] if f.id < _seen_t.size() else -1.0



func markers() -> Array:
	if _markers_ver == ver:
		return _markers
	_markers_ver = ver
	_markers = []
	if not active():
		return _markers
	for f: Facility in gw.mil.facilities:
		var i: int = f.id
		if i >= _known.size() or _known[i] == 0 or _shown[i] != 0 or f.parent != null:
			continue
		if STATIC_KINDS.has(f.kind) or f.kind == Facility.Kind.SOLAR or friend(f.country_id):
			continue
		_markers.append([f, _pos[i]])
	return _markers



func marker_at(p: Vector2, z: float) -> Facility:
	var sc: float = (FogLayer.PIN_SCREEN + 0.25 * clampf(z - 1.0, 0.0, 1.0)) / z
	var best: Facility = null
	var bd: float = INF
	for mk: Array in markers():
		var c: Vector2 = (mk[1] as Vector2) + Vector2(0, -23) * sc
		var d: float = maxf(absf(p.x - c.x), absf(p.y - c.y))
		if d <= 19.0 * sc and d < bd:
			bd = d
			best = mk[0]
	return best





func reveal(center: Vector2, radius_px: float, duration_s: float) -> void :
	reveals.append({"c": center, "r": radius_px, "t0": gw.game_time, "until": gw.game_time + duration_s})
	_t = 0.0
	ver += 1



func satellite_cost() -> int:
	var n: int = 0
	for t: float in _sat_uses:
		if gw.game_time - t < SAT_WINDOW:
			n += 1
	return SAT_COST + SAT_STEP * n



func satellite_wait() -> float:
	return maxf(0.0, satellite_cd - gw.game_time)




func satellite(center: Vector2) -> String:
	var p: Country = gw.player
	if p == null:
		return Loc.t("НЕТ ИГРОКА")
	if satellite_wait() > 0.0:
		return Loc.t("СПУТНИК НАД ЦЕЛЬЮ ЧЕРЕЗ %d С") % ceili(satellite_wait())
	var cost: int = satellite_cost()
	if p.money < cost:
		return Loc.t("НЕ ХВАТАЕТ ДЕНЕГ: СНИМОК %d") % cost
	p.money -= cost
	var keep: = PackedFloat32Array()
	for t: float in _sat_uses:
		if gw.game_time - t < SAT_WINDOW:
			keep.append(t)
	keep.append(gw.game_time)
	_sat_uses = keep
	satellite_cd = gw.game_time + SAT_CD
	reveal(center, SAT_R, SAT_TIME)
	if gw.econ != null and gw.econ.has_method("stat_add"):
		gw.econ.stat_add(p, "spend", "intel", cost)
	return ""




func covers() -> Array:
	var out: Array = []
	if not active():
		return out
	for f: Facility in gw.mil.facilities:
		var i: int = f.id
		if i >= _known.size() or (_known[i] != 0 and (i >= _shown.size() or _shown[i] != 0)) or f.moving or f.is_line() or friend(f.country_id):
			continue
		var k: int = f.kind
		if Defense.is_ad(k) or k == Facility.Kind.AD_RADAR or k == Facility.Kind.AD_EW or k == Facility.Kind.TEL or STATIC_KINDS.has(k):
			continue
		out.append(f)
	return out




func update(delta: float) -> void :
	if gw.data == null or gw.mil == null:
		return
	if not enabled or gw.player == null:
		if not _all_shown:
			_show_all()
		return
	if img == null or gw_w != (gw.data.w * GameWorld.CELL + GRID - 1) / GRID or gw_h != (gw.data.h * GameWorld.CELL + GRID - 1) / GRID:
		_setup()
	_t -= delta * clampf(gw.time_scale, 1.0, 3.0)
	if _t <= 0.0 or vis.is_empty():
		_t = DT
		_recompute()
	else:
		_sync()
	_news(delta)


func _setup() -> void :
	gw_w = (gw.data.w * GameWorld.CELL + GRID - 1) / GRID
	gw_h = (gw.data.h * GameWorld.CELL + GRID - 1) / GRID
	img = Image.create(gw_w, gw_h, false, Image.FORMAT_L8)
	air_img = Image.create(gw_w, gw_h, false, Image.FORMAT_L8)
	vis = PackedByteArray()
	air = PackedByteArray()
	_known = PackedByteArray()
	_shown = PackedByteArray()
	_dead = PackedByteArray()
	_pos = PackedVector2Array()
	_seen_t = PackedFloat32Array()
	_news_q.clear()
	reveals.clear()
	_pid = -1
	ver += 1


func _grow(n: int) -> void :
	var old: int = _known.size()
	if n <= old:
		return
	_known.resize(n)
	_shown.resize(n)
	_dead.resize(n)
	_pos.resize(n)
	_seen_t.resize(n)
	for i in range(old, n):
		_seen_t[i] = -1.0
	ver += 1


func _refresh_friends() -> void :
	var n: int = 1
	for c: Country in gw.countries:
		n = maxi(n, c.id + 1)
	_friend.resize(n)
	_friend.fill(0)
	var pid: int = gw.player.id
	var al = gw.diplo.ally if gw.diplo != null else null
	var had: bool = _allies
	_allies = false
	for c: Country in gw.countries:
		if c.id == pid:
			_friend[c.id] = 1
		elif gw.diplo.allied(pid, c.id) or (al != null and al.same(pid, c.id)):
			_friend[c.id] = 1
			_allies = true
	if had != _allies:
		ver += 1
	if _pid != pid:
		_pid = pid
		ver += 1


func _recompute() -> void :
	var t0: int = Time.get_ticks_usec()
	_refresh_friends()
	img.fill(Color.BLACK)
	air_img.fill(Color.BLACK)
	_done.clear()
	var white: = Color.WHITE
	for city: City in gw.cities:
		if city.country_id <= 0 or not friend(city.country_id):
			continue
		var half: int = (city.claim_max + CITY_PAD) * GameWorld.CELL
		var c: = Vector2(city.center * GameWorld.CELL)
		var g0: = Vector2i(floori((c.x - half) / GRID), floori((c.y - half) / GRID))
		var g1: = Vector2i(floori((c.x + half) / GRID), floori((c.y + half) / GRID))
		var r: = Rect2i(g0, g1 - g0 + Vector2i.ONE)
		img.fill_rect(r, white)
	var mil: Military = gw.mil
	for f: Facility in mil.facilities:
		if not friend(f.country_id) or f.is_line() or not mil.alive(f):
			continue
		var p: Vector2 = f.mpos if f.moving else f.center_px()
		var rg: float = R_FAC
		var ra: float = 0.0
		if f.kind == Facility.Kind.AD_RADAR and not f.moving and mil.has_power(f):
			rg = R_RADAR
			ra = Defense.RADAR_R
		elif Defense.is_ad(f.kind) and not f.moving:
			ra = float(Defense.SPEC[f.kind]["detect"])
		_stamp(img, p, rg)
		if ra > rg:
			_stamp(air_img, p, ra)
	for u: Unit in gw.army.units:
		if not u.alive() or not friend(u.country_id):
			continue
		if u.type == Unit.Type.FPV:
			_stamp(img, u.pos, R_FPV)
		else:
			_stamp(img, u.pos, R_UNIT * (1.3 if u.entrenched or u.dug else 1.0))
	for d: Unit in gw.army.fire.recon:
		if d.alive() and d.jam_t <= 0.0 and friend(d.country_id):
			_stamp(img, d.pos, R_RECON)
	for dr: Drone in mil.drones:
		if dr.airborne() and friend(dr.country_id):
			_stamp(img, dr.pos, R_CRUISE if dr.kind == 1 else (R_JET if dr.kind == 2 else R_DRONE))
	for ac: Aircraft in mil.air.aircraft:
		if ac.state != Aircraft.State.DEAD and ac.airborne() and friend(ac.country_id):
			_stamp(img, ac.pos, R_AIRCRAFT)
	_stamp_ships()
	for k in range(reveals.size() - 1, -1, -1):
		var rv: Dictionary = reveals[k]
		if gw.game_time >= float(rv["until"]):
			reveals.remove_at(k)
			ver += 1
			continue
		_stamp(img, rv["c"], float(rv["r"]))
	_stamp_temp()
	vis = img.get_data()
	air = air_img.get_data()
	vis_ver += 1
	for f: Facility in mil.facilities:
		_eval(f)
	ms = float(Time.get_ticks_usec() - t0) / 1000.0
	ms_max = maxf(ms_max, ms)




func _sync() -> void :
	var n: int = _known.size()
	for f: Facility in gw.mil.facilities:
		if f.id >= n:
			_eval(f)
		elif _shown[f.id] == 0 and not f.obj_ids.is_empty():
			_hide_objs(f)





func _stamp_ships() -> void :
	_sea.clear()
	var nv: Variant = gw.get("navy")
	if nv == null:
		return
	var src: Array = []
	for s: Ship in (nv as Navy).ships:
		if s.alive() and friend(s.c):
			src.append(s)
	if src.is_empty():
		return
	src.sort_custom( func(a: Ship, b: Ship) -> bool: return a.hull > b.hull)
	var gnd: = PackedVector3Array()
	for s2: Ship in src:
		var h: int = clampi(s2.hull, 0, 2)
		var sr: float = float(Navy.hull_spec(h)["sensor"])
		var gr: float = float(R_SHIP[h])
		if not _inside(_sea, s2.pos, sr):
			_stamp(air_img, s2.pos, sr)
			_sea.append(Vector3(s2.pos.x, s2.pos.y, sr))
		if not _inside(gnd, s2.pos, gr):
			_stamp(img, s2.pos, gr)
			gnd.append(Vector3(s2.pos.x, s2.pos.y, gr))


static func _inside(cs: PackedVector3Array, p: Vector2, r: float) -> bool:
	for v: Vector3 in cs:
		if v.z >= r and Vector2(v.x, v.y).distance_to(p) + r <= v.z + float(GRID):
			return true
	return false


func _stamp(im: Image, p: Vector2, r: float) -> void :
	var gr: int = maxi(1, roundi(r / float(GRID)))
	var gx: int = int(p.x) / GRID
	var gy: int = int(p.y) / GRID
	if gx < - gr or gy < - gr or gx >= gw_w + gr or gy >= gw_h + gr:
		return
	var key: = Vector4i(gx, gy, gr, 0 if im == img else 1)
	if _done.has(key):
		return
	_done[key] = true
	var st: Array = _stamps.get(gr, [])
	if st.is_empty():
		var n: int = gr * 2 + 1
		var src: = Image.create(n, n, false, Image.FORMAT_L8)
		src.fill(Color.WHITE)
		var mask: = Image.create(n, n, false, Image.FORMAT_RGBA8)
		var lim: float = (float(gr) + 0.5) * (float(gr) + 0.5)
		for y in n:
			for x in n:
				var dx: float = float(x - gr)
				var dy: float = float(y - gr)
				if dx * dx + dy * dy <= lim:
					mask.set_pixel(x, y, Color.WHITE)
		st = [src, mask]
		_stamps[gr] = st
	im.blit_rect_mask(st[0] as Image, st[1] as Image, Rect2i(0, 0, gr * 2 + 1, gr * 2 + 1), Vector2i(gx - gr, gy - gr))


func _fpos(f: Facility) -> Vector2:
	if f.moving:
		return f.mpos
	if f.is_line() and not f.cells.is_empty():
		return Vector2(f.cells[f.cells.size() / 2] * GameWorld.CELL) + Vector2(2, 2)
	return f.center_px()


func _fac_seen(f: Facility) -> bool:
	if f.moving:
		return sees(f.mpos)
	if f.is_line():
		for k in range(0, f.cells.size(), 3):
			if sees(Vector2(f.cells[k] * GameWorld.CELL) + Vector2(2, 2)):
				return true
		return false
	var r: = Rect2(Vector2(f.cell * GameWorld.CELL), Vector2(f.size * GameWorld.CELL))
	return sees(r.get_center()) or sees(r.position) or sees(r.end - Vector2.ONE)\
	or sees(Vector2(r.end.x - 1.0, r.position.y)) or sees(Vector2(r.position.x, r.end.y - 1.0))


func _eval(f: Facility) -> void :
	var i: int = f.id
	if i >= _known.size():
		_grow(maxi(i + 1, gw.mil.facilities.size()))
	var was: int = _shown[i]
	var sh: int = 0
	if friend(f.country_id):
		_known[i] = 1
		_dead[i] = 0
		_pos[i] = _fpos(f)
		_seen_t[i] = gw.game_time
		sh = 1
	elif _fac_seen(f):
		var alive: bool = gw.mil.alive(f)
		var lp: Vector2 = _fpos(f)
		if _known[i] == 0:
			_known[i] = 1
			_on_discover(f)
			ver += 1
		elif lp != _pos[i] or _dead[i] != (0 if alive else 1):
			ver += 1
		_pos[i] = lp
		_dead[i] = 0 if alive else 1
		_seen_t[i] = gw.game_time
		sh = 1
	elif _known[i] != 0 and (_dead[i] != 0 or STATIC_KINDS.has(f.kind)):
		sh = 1
	if sh != was:
		_shown[i] = sh
		_apply(f, sh == 1)
		ver += 1
	elif sh == 0 and not f.obj_ids.is_empty():
		_hide_objs(f)


func _apply(f: Facility, show: bool) -> void :
	var v: int = 0 if show else 1
	var oh: PackedByteArray = gw.obj_hidden
	for oid in f.obj_ids:
		if oid >= 0 and oid < oh.size() and gw.obj_state[oid] != 2 and oh[oid] != v:
			gw.obj_hidden[oid] = v
			gw._mark_obj_chunk(oid)
	if f.is_line() or STATIC_KINDS.has(f.kind):
		gw.forts.queue_redraw()
	_fx_alpha(f, 1.0 if show else 0.0)




func _fx_alpha(f: Facility, a: float) -> void :
	for h: Array in f.fx:
		var sp: AnimatedSprite2D = h[0]
		if sp != null and is_instance_valid(sp) and sp.visible and int(sp.get_meta("gen", -1)) == int(h[1]) and sp.self_modulate.a != a:
			sp.self_modulate = Color(1, 1, 1, a)


func _hide_objs(f: Facility) -> void :
	if not f.fx.is_empty():
		_fx_alpha(f, 0.0)
	for oid in f.obj_ids:
		if oid >= 0 and oid < gw.obj_hidden.size() and gw.obj_hidden[oid] == 0 and gw.obj_state[oid] != 2:
			gw.obj_hidden[oid] = 1
			gw._mark_obj_chunk(oid)


func _show_all() -> void :
	_all_shown = true
	for f: Facility in gw.mil.facilities:
		if f.id < _shown.size() and _shown[f.id] == 0:
			_shown[f.id] = 1
			_apply(f, true)

	_shown.fill(1)
	ver += 1




func _on_discover(f: Facility) -> void :
	_all_shown = false
	discovered_n += 1
	discovered.emit(f)
	if f.parent == null and IMPORTANT.has(f.kind) and gw.game_time > 1.0:
		_news_q.append(f)


func _news(delta: float) -> void :
	_all_shown = false
	_news_t -= delta
	if _news_q.is_empty() or _news_t > 0.0:
		return
	_news_t = NEWS_GAP

	var cid: int = (_news_q[0] as Facility).country_id
	var titles: Array = []
	var rest: Array = []
	var k0: int = -1
	for f: Facility in _news_q:
		if f.country_id == cid:
			if titles.is_empty():
				k0 = f.kind
			titles.append(String(Military.TITLES.get(f.kind, "объект")).to_upper())
		else:
			rest.append(f)
	_news_q = rest
	var c: Country = gw.country_by_id(cid)
	var more: int = titles.size() - 3
	var txt: String = ", ".join(PackedStringArray(titles.slice(0, 3))) + (" +%d" % more if more > 0 else "")
	var verb: String = Loc.t("ОБНАРУЖЕН") if titles.size() == 1 and k0 != Facility.Kind.BARRACKS else Loc.t("ОБНАРУЖЕНЫ")
	gw.news_m(Loc.mk("РАЗВЕДКА: %s %s (%s)", [verb, txt, Loc.name(c.name) if c != null else "?"]), "amber")




func save_state() -> Dictionary:
	return Save.dump(self, ["img", "air_img", "vis", "air", "gw_w", "gw_h", "ver", "vis_ver", "ms", "ms_max", 
		"_stamps", "_done", "_news_q", "_markers", "_markers_ver", "_friend", "_pid", "_t"])






func net_rebind(keep: Dictionary) -> void :
	load_state(keep.get("state", {}))
	_pid = -1
	_all_shown = false

	var sig: Dictionary = keep.get("sig", {})
	var now: Dictionary = {}
	for f0: Facility in gw.mil.facilities:
		now[f0.id] = _sig_of(f0)
	for i in _known.size():
		if _known[i] != 0 or _shown[i] != 0:
			if not now.has(i) or str(sig.get(i, "")) != str(now[i]):
				_known[i] = 0
				_shown[i] = 0
				_dead[i] = 0
				_pos[i] = Vector2.ZERO
				_seen_t[i] = -1.0
	if not enabled:
		return
	for f: Facility in gw.mil.facilities:
		if f.id < _shown.size():
			_apply(f, _shown[f.id] == 1)
	ver += 1



func net_keep() -> Dictionary:
	var sig: Dictionary = {}
	for f: Facility in gw.mil.facilities:
		sig[f.id] = _sig_of(f)
	return {"state": save_state(), "sig": sig}


static func _sig_of(f: Facility) -> String:
	return "%d:%d:%d,%d" % [f.country_id, f.kind, f.cell.x, f.cell.y]



func load_state(d: Dictionary) -> void :
	if gw.data != null:
		_setup()
	Save.fill(self, d)
	_t = 0.0
	ver += 1








var temp_src: Dictionary = {}


func add_temp_source(key: String, country_id: int, pos: Vector2, radius: float, until_time: float) -> void :
	temp_src[key] = {"cid": country_id, "p": pos, "r": radius, "until": until_time}


func remove_temp_source(key: String) -> void :
	temp_src.erase(key)


func _stamp_temp() -> void :
	if temp_src.is_empty():
		return
	for key: String in temp_src.keys():
		var s: Dictionary = temp_src[key]
		if gw.game_time >= float(s["until"]):
			temp_src.erase(key)
			continue
		if friend(int(s["cid"])):
			_stamp(img, s["p"], float(s["r"]))
