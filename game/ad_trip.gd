extends RefCounted















const AdRelocateS = preload("res://game/ad_relocate.gd")

const PACK_T: float = 8.0
const TRIP_MUL: float = 1.6
const MAX_DRIVE: float = 900.0
const HIT_R: float = 10.0

var sc
var gw: GameWorld
var trips: Dictionary = {}
static var stats: Dictionary = {}


func _init(s) -> void :
	sc = s
	gw = s.gw


static func _note(k: String) -> void :
	stats[k] = int(stats.get(k, 0)) + 1



func phase(fid: int) -> int:
	return int((trips[fid] as Dictionary)["ph"]) if trips.has(fid) else -1



func left(fid: int) -> float:
	if not trips.has(fid):
		return 0.0
	var t: Dictionary = trips[fid]
	return maxf(0.0, float(t["until"]) - gw.game_time) if int(t["ph"]) != 1 else 0.0


func _fac(fid: int) -> Facility:
	var fl: Array = gw.mil.facilities if gw.mil != null else []
	var f: Facility = fl[fid] if fid >= 0 and fid < fl.size() else null
	return f if f != null and f.id == fid else null



func start(f: Facility, why: String) -> bool:
	var owner: Country = gw.country_by_id(f.country_id)
	if owner == null:
		return false
	if trips.has(f.id):
		return true
	if f.moving or not gw.mil.alive(f) or gw.econ == null:
		_note("jump_now")
		return AdRelocateS.relocate(gw, f, null, null, false, why)
	var from_c: Vector2i = f.cell + f.size / 2
	var spot: Vector2i = AdRelocateS.home_spot(gw, f.kind, owner, from_c, Rect2i())
	if spot.x < 0:
		_note("no_spot")
		return AdRelocateS.relocate(gw, f, null, null, false, why)
	trips[f.id] = {"ph": 0, "until": gw.game_time + PACK_T, "t0": gw.game_time, "dx": spot.x, "dy": spot.y, "why": why, "host": sc._fac_owner(f)}
	f.cd = maxf(f.cd, PACK_T + 1.0)
	f.queued.clear()
	_note("started")
	if gw.fx != null:
		gw.fx.spawn("dust_s", f.center_px().round(), 6)
	var km: float = f.center_px().distance_to(Vector2(spot * GameWorld.CELL)) / 1000.0
	gw.say(owner, Loc.mk("ПВО сворачивается и едет домой (%.1f км): %s — %s", [km, Military.title_of(f.kind), why]))
	return true



func update(now: float) -> void :
	var ids: Array = trips.keys()
	ids.sort()
	for fid: int in ids:
		var t: Dictionary = trips[fid]
		var f: Facility = _fac(fid)
		if f == null or gw.mil.is_demolished(f) or not gw.diplo._alive(f.country_id):
			trips.erase(fid)
			continue
		match int(t["ph"]):
			0:
				if sc._fac_owner(f) == f.country_id:
					trips.erase(fid)
				elif not gw.mil.alive(f):
					trips.erase(fid)
					_note("ruined_packing")
				elif now >= float(t["until"]):
					_drive(f, t, now)
			1:
				if f.moving:
					if now - float(t["t0"]) > MAX_DRIVE:
						trips.erase(fid)
						_note("jump_late")
						AdRelocateS.relocate(gw, f, null, null, false, String(t["why"]))
					continue
				if sc._fac_owner(f) == f.country_id:
					t["ph"] = 2
					t["until"] = now + float(sc.DEPLOY_T)
					if Defense.is_ad(f.kind):
						f.cd = maxf(f.cd, float(sc.DEPLOY_T))
					_note("arrived")
				else:
					trips.erase(fid)
					_note("jump_park")
					AdRelocateS.relocate(gw, f, null, null, false, String(t["why"]))
			_:
				if now >= float(t["until"]):
					trips.erase(fid)


func _drive(f: Facility, t: Dictionary, now: float) -> void :
	var owner: Country = gw.country_by_id(f.country_id)
	var dest: = Vector2i(int(t["dx"]), int(t["dy"]))
	if not AdRelocateS._ok(gw, f.kind, owner, dest):
		dest = AdRelocateS.home_spot(gw, f.kind, owner, f.cell + f.size / 2, Rect2i())
	if dest.x < 0:
		trips.erase(f.id)
		_note("no_spot_late")
		AdRelocateS.relocate(gw, f, null, null, false, String(t["why"]))
		return
	var from: Vector2 = f.origin_px() + Vector2(f.size.x * 2.0, f.size.y * 4.0)
	var to: Vector2 = Vector2(dest * GameWorld.CELL) + Vector2(2, 3)
	var pts: PackedVector2Array = gw.econ.land_path(from, to)
	if pts.is_empty():
		trips.erase(f.id)
		_note("no_road")
		AdRelocateS.relocate(gw, f, null, null, false, Loc.t("%s, по суше не проехать") % [String(t["why"])])
		return
	var cells: Array[Vector2i] = [Vector2i(floori(from.x / GameWorld.CELL), floori(from.y / GameWorld.CELL))]
	for p: Vector2 in pts:
		var q: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
		if q != cells[cells.size() - 1]:
			cells.append(q)
	if cells[cells.size() - 1] != dest:
		cells.append(dest)
	if cells.size() < 2:
		cells.append(dest + Vector2i(1, 0))
	gw.mil._drive_path(f, cells, from)
	t["ph"] = 1
	t["t0"] = now
	t["dx"] = dest.x
	t["dy"] = dest.y
	_note("on_road")



func on_strike(p: Vector2, r_px: float) -> void :
	var ids: Array = trips.keys()
	ids.sort()
	for fid: int in ids:
		var f: Facility = _fac(fid)
		if f == null or not f.moving or int((trips[fid] as Dictionary)["ph"]) != 1 or f.mpos.distance_to(p) > r_px + HIT_R:
			continue
		_destroy(f, trips[fid])


func _destroy(f: Facility, t: Dictionary) -> void :
	var c: int = f.country_id
	var at: Vector2 = f.mpos
	var o: int = sc._owner_at(at)
	var h: int = int(t.get("host", 0))
	var e: int = 0
	if gw.get("supply") != null and gw.supply != null:
		e = int(gw.supply.strike_by)
	trips.erase(f.id)
	f.moving = false
	f.mpath.clear()
	gw.mil.drive_dir.erase(f.id)
	var sz: Vector2i = f.size
	f.size = Vector2i.ZERO
	gw.mil._dem_one(f)
	f.size = sz
	gw.mil._update_power()
	gw.changed.emit()
	_note("destroyed")
	if gw.fx != null:
		gw.fx.spawn("explosion_s", at.round(), 6)
	var dp: Diplomacy = gw.diplo
	if o != c and o > 0 and e > 0 and e != c and dp.at_war(e, o) and not dp.at_war(c, e):
		dp.add_opinion(c, e, -2)
	var where: String = Loc.t("на своей земле") if o == c else (Loc.t("на земле страны %s") % sc._cname(o) if o > 0 else Loc.t("в пути"))
	gw.say(c, Loc.t("ПВО уничтожено в пути домой %s: %s%s") % [where, Military.title_of(f.kind), 
		(Loc.t(" (удар: %s)") % sc._cname(e)) if e > 0 and e != c else ""])
	if h > 0 and h != c and o == h:
		gw.say(h, Loc.mk("На вашей земле уничтожено ПВО страны %s в пути домой", [Loc.name(sc._cname(c))]))




func hash_nums(out: PackedFloat64Array) -> void :
	var ids: Array = trips.keys()
	ids.sort()
	out.append(float(ids.size()))
	for fid: int in ids:
		out.append(float(fid))
		out.append(float(int((trips[fid] as Dictionary)["ph"])))


func save() -> Dictionary:
	var out: Dictionary = {}
	for fid: int in trips:
		out[str(fid)] = (trips[fid] as Dictionary).duplicate()
	return out


func load_from(d: Dictionary) -> void :
	trips = {}
	for k: Variant in d:
		var e: Dictionary = d[k]
		trips[int(k)] = {"ph": int(e.get("ph", 0)), "until": float(e.get("until", 0.0)), "t0": float(e.get("t0", 0.0)), "dx": int(e.get("dx", -1)), 
			"dy": int(e.get("dy", -1)), "why": String(e.get("why", "")), "host": int(e.get("host", 0))}
