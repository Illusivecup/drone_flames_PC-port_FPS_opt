extends RefCounted










var gw: GameWorld
var stats: Dictionary = {}

const SAFE_R: float = 56.0
const SAFE_R_SLOW: float = 90.0
const MARCH_R: float = 420.0
const BR_PAD: float = 60.0
const BR_TRUCK_R: float = 300.0
const BR_ROUTE_R: float = 240.0
const BR_PATH_N: int = 80





const AD_W: Dictionary = {
	"drone": {Facility.Kind.AD_MFG: 0.3, Facility.Kind.AD_SPAAG: 0.6, Facility.Kind.AD_SAM: 1.2, Facility.Kind.AD_INT: 1.2}, 
	"air": {Facility.Kind.AD_SPAAG: 0.5, Facility.Kind.AD_SAM: 1.0, Facility.Kind.AD_PATRIOT: 0.75, Facility.Kind.AD_INT: 0.8}, 
	"missile": {Facility.Kind.AD_PATRIOT: 1.2, Facility.Kind.AD_SAM: 0.25}, 
}
const ROUTE_K: float = 0.5
const RISK_CAP: float = 6.0

var _ad: Dictionary = {}
var _inb: Dictionary = {}


func _init(world: GameWorld) -> void :
	gw = world


func _note(k: String) -> void :
	stats[k] = int(stats.get(k, 0)) + 1



func spared(cid: int, oid: int) -> bool:
	if oid == cid:
		return true
	var c: Country = gw.country_by_id(cid)
	return c == null or not c.at_war.has(oid)



func friend(cid: int, oid: int) -> bool:
	if oid == cid:
		return true
	var dp: Diplomacy = gw.diplo
	return dp != null and (dp.allied(cid, oid) or dp.subject_of(oid) == cid or dp.subject_of(cid) == oid)



func troops_near(cid: int, p: Vector2, r: float) -> int:
	var n: int = 0
	for o: Variant in gw.army._near(p, r):
		var u: Unit = o
		if u.alive() and u.type != Unit.Type.FPV and u.pos.distance_squared_to(p) <= r * r and spared(cid, u.country_id):
			n += 1
	return n


static func slow(cls: String) -> bool:
	return cls != "missile"



func aim_veto(cid: int, p: Vector2, cls: String) -> String:
	var s: bool = slow(cls)
	var n: int = troops_near(cid, p, SAFE_R_SLOW if s else SAFE_R)
	if n > 0:
		_note("veto_troops")
		return Loc.t("свои / не враги у цели: %d") % n
	if s:
		for o: Variant in gw.army._near(p, MARCH_R):
			var u: Unit = o
			if u.alive() and u.target_city >= 0 and u.target_city < gw.cities.size() and friend(cid, u.country_id):
				var city: City = gw.cities[u.target_city]
				if Vector2(city.center * GameWorld.CELL).distance_to(p) <= float(city.radius * GameWorld.CELL) + 150.0:
					_note("veto_march")
					return Loc.t("свои идут на штурм г. %s") % city.name
	return ""




func bridge_veto(c: Country, b: Bridge) -> String:
	var bc: Vector2 = b.center_px()
	var half: float = float(b.cells.size()) * GameWorld.CELL * 0.5
	var r: float = half + BR_PAD
	if troops_near(c.id, bc, r) > 0:
		_note("veto_br_troops")
		return Loc.t("на мосту / у моста свои или не враги")
	var fronts: Dictionary = {}
	for u: Unit in gw.army.units:
		if not u.alive() or u.type == Unit.Type.FPV or not friend(c.id, u.country_id):
			continue
		if u.state == Unit.State.MOVE and u.path.size() > u.pi:
			var top: int = mini(u.path.size(), u.pi + BR_PATH_N)
			for i in range(u.pi, top):
				if u.path[i].distance_squared_to(bc) <= r * r:
					_note("veto_br_path")
					return Loc.t("по нему идут свои войска")
		if u.target_city >= 0 and u.target_city < gw.cities.size():
			var tc: Vector2 = Vector2(gw.cities[u.target_city].center * GameWorld.CELL)
			var prev: Variant = fronts.get(u.target_city)
			if prev == null or (prev as Vector2).distance_squared_to(tc) > u.pos.distance_squared_to(tc):
				fronts[u.target_city] = u.pos
	for cid2: int in fronts.keys():
		var a: Vector2 = fronts[cid2]
		var tc2: Vector2 = Vector2(gw.cities[cid2].center * GameWorld.CELL)
		if Geometry2D.get_closest_point_to_segment(bc, a, tc2).distance_to(bc) <= BR_ROUTE_R:
			_note("veto_br_route")
			return Loc.t("на линии своего наступления на г. %s") % gw.cities[cid2].name
	for t: Dictionary in gw.econ.trucks:
		if (t["pos"] as Vector2).distance_squared_to(bc) > BR_TRUCK_R * BR_TRUCK_R:
			continue
		if spared(c.id, int(t["from"])) and spared(c.id, int(t["to"])):
			_note("veto_br_trucks")
			return Loc.t("свои / нейтральные грузовики у моста")
	if inbound_at(c, bc, half + 12.0) > 0:
		_note("veto_br_dup")
		return Loc.t("по нему уже летит")
	return ""




func inbound(c: Country) -> Array:
	var e: Array = _inb.get(c.id, [])
	if e.size() == 2 and float(e[0]) == gw.game_time:
		return e[1]
	var out: Array = []
	var mil: Military = gw.mil
	for d: Drone in mil.drones:
		if d.state != Drone.State.PARKED and d.state != Drone.State.DONE and friend(c.id, d.country_id):
			out.append(d.target)
	for m: Missile in mil.missiles:
		if m.state != Missile.State.DONE and friend(c.id, m.country_id):
			out.append(m.target)
	if mil.air != null:
		for kb: Drone in mil.air.kabs:
			if kb.state != Drone.State.DONE and friend(c.id, kb.country_id):
				out.append(kb.target)
		for a: Aircraft in mil.air.aircraft:
			if a.auto_ai and a.auto_cr > 0 and a.state != Aircraft.State.DEAD and friend(c.id, a.country_id):
				out.append(a.auto_tgt)
	for f: Facility in mil.facilities:
		if f.kind == Facility.Kind.TEL and not f.queued.is_empty() and friend(c.id, f.country_id):
			out.append_array(f.queued)
	_inb[c.id] = [gw.game_time, out]
	return out


func inbound_at(c: Country, p: Vector2, r: float) -> int:
	var n: int = 0
	for q: Variant in inbound(c):
		if (q as Vector2).distance_squared_to(p) <= r * r:
			n += 1
	return n



static func need(risk: float) -> int:
	return clampi(1 + int(risk * 1.4), 1, 3)


func _ad_list(c: Country) -> Array:
	var e: Array = _ad.get(c.id, [])
	if e.size() == 2 and float(e[0]) == gw.game_time:
		return e[1]
	var out: Array = []
	for f: Facility in gw.mil.facilities:
		if Defense.is_ad(f.kind) and c.at_war.has(f.country_id) and not f.moving and gw.mil.alive(f) and Defense.SPEC.has(f.kind):
			out.append([f.center_px(), f.kind, float(Defense.SPEC[f.kind]["range"])])
	_ad[c.id] = [gw.game_time, out]
	return out




func ad_risk(c: Country, from: Vector2, p: Vector2, cls: String) -> float:
	var wt: Dictionary = AD_W.get(cls if cls != "kab" else "air", AD_W["air"])
	var risk: float = 0.0
	for e: Array in _ad_list(c):
		var k: float = float(wt.get(int(e[1]), 0.0))
		if k <= 0.0:
			continue
		var ap: Vector2 = e[0]
		var rr: float = float(e[2])
		if ap.distance_squared_to(p) <= rr * rr:
			risk += k
		elif cls == "drone" and from.is_finite() and Geometry2D.get_closest_point_to_segment(ap, from, p).distance_squared_to(ap) <= rr * rr:
			risk += k * ROUTE_K
	return minf(risk, RISK_CAP)





static func value_k(risk: float) -> float:
	return 1.0 / (1.0 + risk + risk * risk * 0.5 + risk * risk * risk / 6.0)


func log(c: Country, what: String, why: String, score: float, tag: String) -> void :
	if gw.diplo != null and gw.diplo.trace_on:
		gw.diplo.dlog(c.id, what, why, score, [tag])
