extends RefCounted






















const CAP: int = 4
const WHY_LAND: String = "Мирная чужая страна: занять дом можно у себя, у врага, у союзника или с правом прохода"
const COVER_HOUSE: float = 0.4
const COVER_HIGH: float = 0.3
const TICK_DT: float = 1.0
const AUTO_DT: float = 5.0
const AUTO_PER_CITY: int = 4
const AUTO_MAX_CITY: int = 8
const THREAT_PAD: float = 240.0
const DEF_PAD: float = 120.0
const COOL_T: float = 30.0
const OFF_T: float = 120.0
const MAX_WALK: float = 3000.0
const COLLAPSE_KILL: int = 80
const COLLAPSE_HP: float = 0.5
const HIGH: Dictionary = {"panel9_h": true, "panel9_v": true, "tower16": true, "highrise_panel": true, "highrise_brick": true, 
	"glass_tower_a": true, "glass_tower_b": true, "business_center": true, "stalinka_h": true, "stalinka_v": true}
const HOUSE: Dictionary = {"house_a": true, "house_b": true, "house_c": true, "house_d": true, "khrushchevka_h": true, 
	"khrushchevka_v": true, "admin": true, "school": true, "warehouse": true}

var gw: GameWorld


var holds: Dictionary = {}
var _cool: Dictionary = {}
var _off: Dictionary = {}
var _hot: Dictionary = {}
var _uh: Dictionary = {}
var _t1: float = 0.0
var _t5: float = 0.0
var stats: Dictionary = {"occupied": 0, "auto": 0, "dropped": 0, "ruined": 0, "collapse_dead": 0, "collapse_hurt": 0}
var why: String = ""


func _init(world: GameWorld) -> void :
	gw = world





func kind_of(oid: int) -> int:
	if oid < 0 or oid >= gw.obj_spr.size() or gw.obj_state[oid] != 0 or gw.obj_kind[oid] != GameWorld.KIND_BUILDING:
		return 0
	var nm: String = gw.spr_name[gw.obj_spr[oid]]
	if HIGH.has(nm):
		return 2
	if HOUSE.has(nm):
		return 1
	return 0



func _ruin_of_kind(id: int) -> bool:
	if id < 0 or id >= gw.obj_spr.size() or gw.obj_state[id] != 1 or gw.obj_kind[id] != GameWorld.KIND_BUILDING:
		return false
	var nm: String = gw.spr_name[gw.obj_spr[id]]
	return HIGH.has(nm) or HOUSE.has(nm)


func is_ruin(id: int) -> bool:
	return _ruin_of_kind(id)



func owner_of(oid: int) -> int:
	var r: Rect2i = gw.object_rect(oid)
	return gw.data.get_owner_id(r.position.x + r.size.x / 2, r.position.y + r.size.y - 1)





func may_hold(cid: int, owner: int) -> bool:
	if owner == cid:
		return true
	return gw.diplo != null and gw.diplo.may_cross(cid, owner)




func building_at(wp: Vector2, ruins: bool = false) -> int:
	var c: = Vector2i(floori(wp.x / GameWorld.CELL), floori(wp.y / GameWorld.CELL))
	var box: = Rect2i(c - Vector2i(12, 2), Vector2i(25, 30))
	var best: int = -1
	var bk: int = -1
	for ck: ObjChunk in gw.objects.chunks_in_rect(box):
		for id in ck.ids:
			if kind_of(id) == 0 and not (ruins and _ruin_of_kind(id)):
				continue
			var sid: int = ArchStyle.draw_sid(gw, id)
			var rr: = Rect2(ArchStyle.draw_origin(gw, id), gw.spr_rect[sid].size)
			if rr.has_point(wp):
				var k: int = gw.obj_sort_key(id)
				if k > bk:
					bk = k
					best = id
	return best



func info(oid: int) -> Dictionary:
	if not holds.has(oid):
		return {}
	var h: Dictionary = holds[oid]
	var n_in: int = 0
	var ua: Array = h["u"]
	var sa: Array = h["s"]
	for k in ua.size():
		var u: Unit = ua[k]
		if u.alive() and u.pi >= u.path.size() and u.pos.distance_to(sa[k]) <= 3.0:
			n_in += 1
	return {"c": int(h["c"]), "home": h["home"], "n": ua.size(), "in": n_in, "hi": bool(h["hi"]), "auto": bool(h["auto"])}


func holds_unit(u: Unit) -> bool:
	return _uh.has(u.id)




func inside(u: Unit) -> bool:
	var oid: int = int(_uh.get(u.id, -1))
	if oid < 0 or u.pi < u.path.size() or not holds.has(oid):
		return false
	var h: Dictionary = holds[oid]
	var k: int = (h["u"] as Array).find(u)
	return k >= 0 and u.pos.distance_to(h["s"][k]) <= 3.0



func free_count(home: Facility) -> int:
	var n: int = 0
	for u: Unit in gw.army.units:
		if u.home == home and _foot_ok(u, false) and not holds_unit(u):
			n += 1
	return n






func occupy(oid: int, home: Facility, country_id: int) -> Variant:
	why = ""
	var k: int = kind_of(oid)
	if k == 0:
		var ruin: bool = oid >= 0 and oid < gw.obj_state.size() and gw.obj_state[oid] != 0
		why = Loc.t("Дом разрушен — в руины не зайти") if ruin else Loc.t("Это здание нельзя занять")
		return why
	if home == null or home.country_id != country_id or home.kind != Facility.Kind.BARRACKS:
		why = Loc.t("Нет такой армии")
		return why
	if not may_hold(country_id, owner_of(oid)):
		why = WHY_LAND
		return why
	var h: Dictionary = holds.get(oid, {})
	if not h.is_empty() and (int(h["c"]) != country_id or h["home"] != home):
		var hf: Facility = h["home"]
		why = Loc.t("Дом уже занят") + (Loc.t(" армией №%d") % hf.army_no if hf != null and int(h["c"]) == country_id else "")
		return why
	var n: int = _send(oid, home, country_id, false)
	if n == 0 and why == "":
		why = Loc.t("Свободной пехоты этой армии рядом нет")
	if n > 0:
		var c: Country = gw.country_by_id(country_id)
		if c != null and c.is_player and gw.ops != null:
			gw.ops.auto_next["h%d" % home.id] = gw.game_time
		_off.erase(oid)
		return n
	return why



func leave(oid: int, country_id: int) -> Variant:
	if not holds.has(oid) or int(holds[oid]["c"]) != country_id:
		return Loc.t("Дом не занят")
	var h: Dictionary = holds[oid]
	var ua: Array = h["u"]
	var sa: Array = h["s"]
	var n: int = 0
	for i in ua.size():
		var u: Unit = ua[i]
		if not u.alive():
			continue
		var out_p: Vector2 = (sa[i] as Vector2) + (h.get("out", Vector2(0, 8)) as Vector2)
		u.cover = 1.0
		u.path = PackedVector2Array([out_p])
		u.pi = 0
		u.state = Unit.State.MOVE
		_cool[u.id] = gw.game_time + COOL_T
		n += 1
	for u2: Unit in ua:
		_uh.erase(u2.id)
	holds.erase(oid)
	_off[oid] = gw.game_time + OFF_T
	return n




func update(dt: float) -> void :
	_t1 += dt
	if _t1 >= TICK_DT:
		_t1 = 0.0
		_tick()
	_t5 += dt
	if _t5 >= AUTO_DT:
		_t5 = 0.0
		_auto()


func _tick() -> void :
	var dead: Array = []
	for oid: int in holds:
		var h: Dictionary = holds[oid]
		var kk: int = kind_of(oid)

		var ok: bool = kk != 0 and gw.obj_x[oid] == int(h["x"]) and gw.obj_y[oid] == int(h["y"]) and may_hold(int(h["c"]), owner_of(oid))
		if ok:
			h["spr"] = gw.obj_spr[oid]
			h["hi"] = kk == 2
		var ua: Array = h["u"]
		var sa: Array = h["s"]
		if not ok:



			var fell: bool = oid < gw.obj_state.size() and gw.obj_state[oid] == 1 and gw.obj_x[oid] == int(h["x"]) and gw.obj_y[oid] == int(h["y"])
			for k0 in ua.size():
				var u0: Unit = ua[k0]
				_uh.erase(u0.id)
				if not u0.alive():
					continue
				var inside: bool = u0.pi >= u0.path.size() and u0.pos.distance_to(sa[k0]) <= 3.0
				if fell and inside:
					if gw.fx != null and gw._on_screen(u0.pos, 40.0):
						gw.fx.spawn("dust_s", (u0.pos + Vector2(0, -3)).round(), 6)
					if gw.rng.chance(COLLAPSE_KILL):
						gw.army._kill(u0, 0)
						stats["collapse_dead"] = int(stats["collapse_dead"]) + 1
						continue
					u0.hp = maxf(1.0, u0.hp * COLLAPSE_HP)
					stats["collapse_hurt"] = int(stats["collapse_hurt"]) + 1
				_out(u0)
			stats["ruined"] = int(stats["ruined"]) + 1
			dead.append(oid)
			continue
		var cv: float = COVER_HIGH if bool(h["hi"]) else COVER_HOUSE
		for k in range(ua.size() - 1, -1, -1):
			var u: Unit = ua[k]
			var sp: Vector2 = sa[k]
			var bad: bool = not u.alive() or u.country_id != int(h["c"]) or u.post != null or u.op_on or u.target_city >= 0 or u.state == Unit.State.SIEGE
			if not bad and bool(h["auto"]) and u.pi < u.path.size() and u.path[u.path.size() - 1].distance_to(sp) > 6.0\
			and u.pos.distance_to(sp) <= 15.0 and u.post == null and _hot.has(int(h.get("city", -1))) and not _retreating(u):





				u.path = PackedVector2Array([sp])
				u.pi = 0
				u.state = Unit.State.MOVE
				stats["kept"] = int(stats.get("kept", 0)) + 1
			if not bad:
				if u.pi < u.path.size():
					bad = u.path[u.path.size() - 1].distance_to(sp) > 6.0
				else:
					bad = u.pos.distance_to(sp) > 10.0
			if bad:
				if u.alive():
					_out(u)
					_cool[u.id] = gw.game_time + COOL_T
				_uh.erase(u.id)
				ua.remove_at(k)
				sa.remove_at(k)
				stats["dropped"] = int(stats["dropped"]) + 1
				continue
			u.no_post_until = maxf(u.no_post_until, gw.game_time + 3.0)
			if u.pi >= u.path.size() and u.pos.distance_to(sp) <= 3.0:
				u.cover = cv / 0.6 if u.dug else cv
		if ua.is_empty():
			dead.append(oid)
	for oid2: int in dead:
		holds.erase(oid2)



func _retreating(u: Unit) -> bool:
	if u.home == null or gw.ops == null or not gw.ops.list.has(u.home):
		return false
	return int(gw.ops.list[u.home].get("kind", -1)) == Operations.Kind.RETREAT



func _out(u: Unit) -> void :
	if u.cover < 1.0 and u.pi >= u.path.size():
		u.cover = 1.0




func _auto() -> void :
	if not _hit.is_empty():
		_hit_prune()
	for uid: int in _cool.keys():
		if float(_cool[uid]) <= gw.game_time:
			_cool.erase(uid)
	for oid: int in _off.keys():
		if float(_off[oid]) <= gw.game_time:
			_off.erase(oid)
	_hot.clear()
	for c: Country in gw.countries:
		if c.eliminated or c.at_war.is_empty():
			continue
		for cid: int in c.city_ids:
			if cid < 0 or cid >= gw.cities.size():
				continue
			var city: City = gw.cities[cid]
			if city.country_id != c.id or not _threat(c, city):
				continue
			_hot[cid] = true
			_auto_city(c, city)




func keep(u: Unit) -> bool:
	var oid: int = int(_uh.get(u.id, -1))
	if oid < 0 or not holds.has(oid):
		return false
	return _hot.has(int(holds[oid].get("city", -1)))


func _threat(c: Country, city: City) -> bool:
	if city.siege_by != 0 or city.cap_by != 0:
		return true
	var cp: Vector2 = Vector2(city.center * GameWorld.CELL)
	var r: float = float(city.radius * GameWorld.CELL) + THREAT_PAD
	for o: Unit in gw.army._near(cp, r):
		if o.alive() and o.ground() and gw.army._hostile(c.id, o.country_id) and o.pos.distance_squared_to(cp) < r * r:
			return true
	return false


const DISPATCH: int = 8
const DISPATCH_R: float = 2500.0
const DISPATCH_POSTS: int = 4




func _manned(c: Country, cp: Vector2, rr: float) -> bool:
	for u: Unit in gw.army._near(cp, rr):
		if u.country_id == c.id and _foot_kind(u) and u.pos.distance_squared_to(cp) < rr * rr\
		and (u.post == null or u.post.center_px().distance_squared_to(cp) < rr * rr):
			return true
	return false




func _dispatch_pool(c: Country, cp: Vector2) -> Array[Unit]:
	var best: Facility = null
	var bd: float = DISPATCH_R
	var per: Dictionary = {}
	for u: Unit in gw.army.units:
		if u.country_id != c.id or u.home == null or not _foot_kind(u) or u.target_city >= 0\
		or u.state == Unit.State.SIEGE or _cool.has(u.id) or _uh.has(u.id) or _retreating(u):
			continue
		if u.op_on and not _defending(u):
			continue
		var d: float = u.pos.distance_to(cp)
		if d > DISPATCH_R:
			continue
		var a: Array = per.get(u.home, [])
		if a.is_empty():
			per[u.home] = a
		a.append(u)
	for f: Facility in per:
		if gw.ops != null and gw.ops.list.has(f) and int(gw.ops.list[f].get("kind", -1)) == Operations.Kind.ATTACK:
			continue
		if c.is_player and (f.stance <= 0 or (gw.ops != null and gw.ops.auto_next.has("h%d" % f.id))):
			continue
		var fa: Array = per[f]
		if fa.size() < 2:
			continue
		var dm: float = INF
		for u2: Unit in fa:
			dm = minf(dm, u2.pos.distance_to(cp))
		if dm < bd or (dm == bd and best != null and f.id < best.id):
			bd = dm
			best = f
	var out: Array[Unit] = []
	if best == null:
		return out
	var pool: Array = per[best]

	pool.sort_custom( func(a2: Unit, b2: Unit) -> bool:
		var pa: float = a2.pos.distance_squared_to(cp) - (1000000.0 if a2.type == Unit.Type.ATGM else 0.0) + (100000000.0 if a2.post != null else 0.0)
		var pb: float = b2.pos.distance_squared_to(cp) - (1000000.0 if b2.type == Unit.Type.ATGM else 0.0) + (100000000.0 if b2.post != null else 0.0)
		return pa < pb or (pa == pb and a2.id < b2.id))
	var np: int = 0
	for i in mini(DISPATCH, pool.size() - 1):
		var u3: Unit = pool[i]
		if u3.post != null:
			if np >= DISPATCH_POSTS:
				break
			np += 1
		out.append(u3)
	return out



func _threat_pos(c: Country, city: City) -> Vector2:
	var cp: Vector2 = Vector2(city.center * GameWorld.CELL)
	var r: float = float(city.radius * GameWorld.CELL) + THREAT_PAD
	var sum: = Vector2.ZERO
	var n: int = 0
	for o: Unit in gw.army._near(cp, r):
		if o.alive() and o.ground() and gw.army._hostile(c.id, o.country_id) and o.pos.distance_squared_to(cp) < r * r:
			sum += o.pos
			n += 1
	return sum / float(n) if n > 0 else Vector2.INF


func _auto_city(c: Country, city: City) -> void :
	var cp: Vector2 = Vector2(city.center * GameWorld.CELL)
	var rr: float = float(city.radius * GameWorld.CELL) + DEF_PAD
	var held: int = 0
	for oid: int in holds:
		var h: Dictionary = holds[oid]
		if int(h["c"]) == c.id and bool(h["auto"]) and Vector2(gw.obj_x[oid] * GameWorld.CELL, gw.obj_y[oid] * GameWorld.CELL).distance_to(cp) < rr:
			held += 1
	if held >= AUTO_MAX_CITY:
		return




	var cr2: float = float(city.radius * GameWorld.CELL) * float(city.radius * GameWorld.CELL)
	var defs: Array[Unit] = []
	for u: Unit in gw.army.units:
		if u.country_id != c.id or u.pos.distance_squared_to(cp) > rr * rr:
			continue
		if u.post != null:
			if not (u.alive() and (u.type == Unit.Type.INFANTRY or u.type == Unit.Type.ATGM or u.type == Unit.Type.ASSAULT)\
			and not u.op_on and u.target_city < 0 and u.state != Unit.State.SIEGE and u.post.center_px().distance_squared_to(cp) < cr2):
				continue
		elif u.op_on:


			if not (_foot_kind(u) and u.op_hold and u.pi >= u.path.size() and u.target_city < 0 and u.state != Unit.State.SIEGE\
			and u.pos.distance_squared_to(cp) < cr2 and _defending(u)):
				continue
		elif not _foot_ok(u, true):
			continue
		if _cool.has(u.id) or holds_unit(u) or _retreating(u):
			continue
		if c.is_player:
			var hf: Facility = u.home
			if hf == null or hf.stance <= 0 or (gw.ops != null and gw.ops.auto_next.has("h%d" % hf.id)):
				continue
		defs.append(u)
	var far: bool = false
	if defs.is_empty():


		if held > 0 or _manned(c, cp, float(city.radius * GameWorld.CELL)):
			return
		defs = _dispatch_pool(c, cp)
		if defs.is_empty():
			return
		far = true
		stats["dispatch"] = int(stats.get("dispatch", 0)) + 1
	stats["auto_try"] = int(stats.get("auto_try", 0)) + 1


	var tp: Vector2 = _threat_pos(c, city)
	var aim: Vector2 = cp if not tp.is_finite() else cp + (tp - cp).limit_length(float(city.radius * GameWorld.CELL) * 0.5)
	var r: int = city.radius + 2
	var box: = Rect2i(city.center - Vector2i(r, r), Vector2i(2 * r + 1, 2 * r + 1))
	var cand: Array = []
	for ck: ObjChunk in gw.objects.chunks_in_rect(box):
		for id in ck.ids:
			var k: int = kind_of(id)
			if k == 0 or holds.has(id) or _off.has(id) or not box.has_point(Vector2i(gw.obj_x[id], gw.obj_y[id])):
				continue
			if owner_of(id) != c.id:
				continue
			var rc: Rect2i = gw.object_rect(id)
			var bp: Vector2 = Vector2((rc.position + rc.size / 2) * GameWorld.CELL)
			var d: float = minf(bp.distance_to(cp), bp.distance_to(aim))
			cand.append([int(d) - (40 if k == 2 else 0), id])
	cand.sort_custom( func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
	if cand.is_empty():
		stats["auto_nobld"] = int(stats.get("auto_nobld", 0)) + 1
	var took: int = 0
	for e: Array in cand:
		if took >= AUTO_PER_CITY or held + took >= AUTO_MAX_CITY or defs.is_empty():
			break
		var oid2: int = int(e[1])
		var n: int = _send(oid2, null, c.id, true, defs, far)
		if n > 0:
			took += 1
			stats["auto"] = int(stats["auto"]) + 1


func _foot_kind(u: Unit) -> bool:
	return u.alive() and (u.type == Unit.Type.INFANTRY or u.type == Unit.Type.ATGM or u.type == Unit.Type.ASSAULT)



func _defending(u: Unit) -> bool:
	if u.home == null or gw.ops == null or not gw.ops.list.has(u.home):
		return false
	return int(gw.ops.list[u.home].get("kind", -1)) == Operations.Kind.DEFEND



func _foot_ok(u: Unit, auto: bool) -> bool:
	if not u.alive() or u.post != null or u.state == Unit.State.SIEGE or u.reinf != 0:
		return false
	if not (u.type == Unit.Type.INFANTRY or u.type == Unit.Type.ATGM or u.type == Unit.Type.ASSAULT):
		return false
	if auto:
		return not u.op_on and u.target_city < 0
	return true



func _slots(oid: int) -> Array:
	var rc: Rect2i = gw.object_rect(oid)
	var cl: float = float(GameWorld.CELL)
	var front: bool = true
	var fy: int = rc.position.y + rc.size.y
	var mx: int = rc.position.x + rc.size.x / 2
	if not gw.data.inside(mx, fy) or Biome.is_water(gw.data.get_biome(mx, fy)):
		front = false
	var out: Array = []
	for i in CAP:
		var x: float = (float(rc.position.x) + float(rc.size.x) * (float(i) + 0.5) / float(CAP)) * cl
		var y: float = float(fy) * cl - 1.5 if front else float(rc.position.y) * cl + 1.5
		out.append(Vector2(x, y))
	return [out, Vector2(0, 7) if front else Vector2(0, -7)]



func _send(oid: int, home: Facility, cid: int, auto: bool, pool: Array[Unit] = [], far: bool = false) -> int:
	var sl: Array = _slots(oid)
	var slots: Array = sl[0]
	var outv: Vector2 = sl[1]
	var h: Dictionary = holds.get(oid, {})
	var taken: Dictionary = {}
	if not h.is_empty():
		for sp: Vector2 in h["s"]:
			taken[sp] = true
	var free: Array = []
	for sp2: Vector2 in slots:
		if not taken.has(sp2):
			free.append(sp2)
	if free.is_empty():
		why = Loc.t("Мест нет: %d/%d") % [CAP, CAP]
		return 0
	var bc: Vector2 = (slots[0] as Vector2).lerp(slots[slots.size() - 1], 0.5)
	var cand: Array[Unit] = []
	if auto:
		cand = pool.duplicate()
	else:
		for u: Unit in gw.army.units:
			if u.home == home and u.country_id == cid and _foot_ok(u, false) and not holds_unit(u):
				cand.append(u)
	cand.sort_custom( func(a: Unit, b: Unit) -> bool:
		var pa: float = a.pos.distance_squared_to(bc) - (90000.0 if a.type == Unit.Type.ATGM else 0.0)
		var pb: float = b.pos.distance_squared_to(bc) - (90000.0 if b.type == Unit.Type.ATGM else 0.0)
		return pa < pb or (pa == pb and a.id < b.id))
	if auto and not cand.is_empty():
		home = cand[0].home
	var n: int = 0
	var nav_fail: int = 0
	for u: Unit in cand:
		if n >= free.size():
			break
		if u.home != home or u.pos.distance_to(bc) > (900.0 if auto and not far else MAX_WALK):
			stats["s_far"] = int(stats.get("s_far", 0)) + 1
			continue
		var sp3: Vector2 = free[n]
		var ap: Vector2 = sp3 + outv
		var path: = PackedVector2Array()
		if u.pos.distance_to(sp3) > 40.0:
			path = gw.econ.nav_path(u.pos, ap)


			if not gw.econ.nav_last_ok and (path.is_empty() or path[path.size() - 1].distance_to(ap) > 24.0):
				stats["s_nav"] = int(stats.get("s_nav", 0)) + 1
				if auto:
					pool.erase(u)
				nav_fail += 1
				if nav_fail >= 3:
					break
				continue
		path.append(sp3)
		if h.is_empty():
			var hc: City = gw.city_at_cell(Vector2i(gw.obj_x[oid], gw.obj_y[oid]))
			h = {"c": cid, "home": home, "u": [], "s": [], "spr": gw.obj_spr[oid], "x": gw.obj_x[oid], "y": gw.obj_y[oid], 
				"hi": kind_of(oid) == 2, "auto": auto, "out": outv, "city": hc.id if hc != null else -1}
			holds[oid] = h
		(h["u"] as Array).append(u)
		_uh[u.id] = oid
		if u.post != null:
			gw.army._release(u)
			stats["from_trench"] = int(stats.get("from_trench", 0)) + 1
		(h["s"] as Array).append(sp3)
		u.op_on = false
		u.op_hold = false
		u.op_move = false
		u.target_city = -1
		u.target = null
		u.cover = 1.0
		u.path = path
		u.pi = 0
		u.state = Unit.State.MOVE
		u.no_post_until = maxf(u.no_post_until, gw.game_time + 3.0)
		if auto:
			pool.erase(u)
		n += 1
	if n > 0:
		stats["occupied"] = int(stats["occupied"]) + n
	elif free.size() > 0 and why == "":
		why = Loc.t("Свободной пехоты этой армии рядом нет")
	return n




const ARTY_SAFE: float = 70.0




func win_pos(oid: int, k: int) -> Vector2:
	var sid: int = ArchStyle.draw_sid(gw, oid)
	var o: Vector2 = ArchStyle.draw_origin(gw, oid)
	var sz: Vector2 = gw.spr_rect[sid].size
	var hi: bool = holds.has(oid) and bool(holds[oid]["hi"])
	var row: float = (0.42 + 0.16 * float(k % 2)) if hi else (0.55 + 0.06 * float(k % 2))
	return Vector2(floorf(o.x + sz.x * (0.18 + 0.2 * float(k))), floorf(o.y + 2.0 + (sz.y - 2.0) * row))




func muzzle(u: Unit, tp: Vector2) -> Vector2:
	if not inside(u):
		return Vector2.INF
	var oid: int = int(_uh[u.id])
	var w: Vector2 = win_pos(oid, (holds[oid]["u"] as Array).find(u))
	return w + Vector2(3.0 if tp.x >= u.pos.x else -1.0, 1.5)









func arty_target(cid: int) -> Vector2:
	var best: = Vector2.INF
	var bs: int = 0
	var bo: int = 1 << 30
	for oid: int in holds:
		var h: Dictionary = holds[oid]
		var hc: int = int(h["c"])
		if hc == cid or not gw.army._hostile(cid, hc):
			continue
		var ua: Array = h["u"]
		var sa: Array = h["s"]
		var n_in: int = 0
		var seen: bool = false
		var cen: = Vector2.ZERO
		for k in ua.size():
			var u: Unit = ua[k]
			if u.alive() and u.pi >= u.path.size() and u.pos.distance_to(sa[k]) <= 3.0:
				n_in += 1
				cen += u.pos
				if gw.army.fire.sees(cid, u):
					seen = true
		if n_in == 0 or not seen:
			continue
		var sc: int = n_in * 2
		var ci: int = int(h.get("city", -1))
		if ci >= 0 and ci < gw.cities.size() and gw.cities[ci] != null and ((gw.cities[ci] as City).country_id == cid or (gw.cities[ci] as City).founder_id == cid):
			sc += 3
		if sc < bs or (sc == bs and oid > bo):
			continue
		cen /= float(n_in)
		if gw.ops != null and not gw.ops._gun_for(cid, cen).is_finite() and not gw.ops._near_own(cid, cen, Operations.ARTY_REACH, false):
			continue
		if _friend_near(cid, cen, ARTY_SAFE):
			stats["arty_safe_skip"] = int(stats.get("arty_safe_skip", 0)) + 1
			continue
		bs = sc
		bo = oid
		best = cen
	return best


func _friend_near(cid: int, p: Vector2, r: float) -> bool:
	var r2: float = r * r
	for u: Unit in gw.army.units:
		if u.alive() and u.ground() and u.pos.distance_squared_to(p) <= r2 and (u.country_id == cid or not gw.army._hostile(cid, u.country_id)):
			return true
	return false














const D_RESTRIKE: Array = [300.0, 180.0, 90.0]
const D_GAP: Dictionary = {"drone": [120.0, 60.0, 30.0], "missile": [300.0, 180.0, 90.0], "air": [300.0, 180.0, 90.0], "kab": [120.0, 60.0, 0.0]}
const D_KNOW_T: Array = [0.0, 150.0, 300.0]
const D_VAL: Array = [0.5, 0.75, 1.0]
const D_DRONE_RISK: Array = [0.6, 1.2, 99.0]
const D_KAB_LVL: Array = [0, 1, 3]
const D_BIG_N: Array = [999, 8, BIG_N]
const HOLD_MEMO: float = 150.0
const HOLD_FRONT_R: float = 900.0
const HOLD_MARCH_R: float = 160.0
const BIG_N: int = 6
const BIG_R: float = 36.0
var _hit: Dictionary = {}
var _spots: Dictionary = {}
var _aims: Dictionary = {}









func strike_spots(cid: int) -> Array:
	var ce: Array = _spots.get(cid, [])
	if ce.size() == 2 and float(ce[0]) == gw.game_time:
		return ce[1]
	var out: Array = []
	var c: Country = gw.country_by_id(cid)
	if c == null or c.at_war.is_empty() or holds.is_empty():
		_spots[cid] = [gw.game_time, out]
		return out
	var di: int = clampi(GameConfig.diff_of(c), 0, 2)
	var dk: float = float(D_VAL[di])
	var storm: Dictionary = {}
	for su: Unit in gw.army.units:
		if su.target_city >= 0 and su.alive() and (su.country_id == cid or (gw.diplo != null and gw.diplo.allied(cid, su.country_id))):
			storm[su.target_city] = true
	for oid: int in holds:
		var h: Dictionary = holds[oid]
		var hc: int = int(h["c"])
		if hc == cid or not c.at_war.has(hc):
			continue
		var land: int = owner_of(oid)
		if land != cid and not c.at_war.has(land):
			continue
		var ua: Array = h["u"]
		var sa: Array = h["s"]
		var n_in: int = 0
		var seen: bool = false
		var cen: = Vector2.ZERO
		for k in ua.size():
			var u: Unit = ua[k]
			if u.alive() and u.pi >= u.path.size() and u.pos.distance_to(sa[k]) <= 3.0:
				n_in += 1
				cen += u.pos
				if not seen and gw.army.fire.sees(cid, u):
					seen = true
		if n_in == 0:
			continue
		cen /= float(n_in)
		var ci: int = int(h.get("city", -1))
		var city: City = gw.cities[ci] if ci >= 0 and ci < gw.cities.size() else null
		var mine: bool = city != null and (city.country_id == cid or city.founder_id == cid)
		var assault: bool = ci >= 0 and storm.has(ci)
		var front: bool = false
		for o: Variant in gw.army._near(cen, HOLD_FRONT_R):
			var ou: Unit = o
			if ou.country_id == cid and ou.alive() and ou.ground() and ou.type != Unit.Type.FPV and ou.pos.distance_squared_to(cen) <= HOLD_FRONT_R * HOLD_FRONT_R:
				front = true
				seen = true
				break
		var kk: String = "k%d>%d" % [cid, oid]
		if seen or mine:
			_hit[kk] = gw.game_time
		elif gw.game_time - float(_hit.get(kk, -1000000000.0)) >= float(D_KNOW_T[di]):
			continue
		if di < 2 and not (mine or front or assault):
			continue
		var bonus: float = (1.2 if mine else 0.0) + (1.2 if assault else (0.8 if front else 0.0))
		var v: float = (0.6 + 0.7 * float(n_in) + (0.3 if bool(h["hi"]) else 0.0) + bonus) * dk
		out.append([cen, n_in, hc, oid, v, land, n_in, bonus, mine or assault])

	for e: Array in out:
		var nb: int = int(e[1])
		for e2: Array in out:
			if e2 != e and int(e2[2]) == int(e[2]) and (e2[0] as Vector2).distance_squared_to(e[0]) <= BIG_R * BIG_R:
				nb += int(e2[1])
		e[6] = nb
		var bigok: bool = nb >= int(D_BIG_N[di]) and (di >= 2 or bool(e[8]))
		e[7] = (0.6 + 0.7 * float(nb) + float(e[7])) * dk - 2.0 if bigok else 0.0
	_spots[cid] = [gw.game_time, out]
	return out





func strike_veto(cid: int, p: Vector2, cls: String) -> String:
	var sn: Variant = gw.ai.get("sense") if gw.ai != null else null
	if sn == null:
		return ""
	var slow: bool = cls != "missile"
	var n: int = int(sn.troops_near(cid, p, HOLD_MARCH_R if slow else float(sn.SAFE_R)))
	if n > 0:
		return Loc.t("свои / не враги у цели: %d") % n
	return ""



func hit_ok(cid: int, oid: int, cls: String) -> bool:
	var di: int = diff_i(cid)
	var e: Array = _hit.get("%d>%d" % [cid, oid], [])
	if e.size() == 2 and gw.game_time - float(e[0]) < float(D_RESTRIKE[di]):
		return false
	return gw.game_time - float(_hit.get("%d>%s" % [cid, cls], -1000000000.0)) >= float((D_GAP.get(cls, D_GAP["drone"]) as Array)[di])


func diff_i(cid: int) -> int:
	var c: Country = gw.country_by_id(cid)
	return clampi(GameConfig.diff_of(c), 0, 2) if c != null else 1



func note_hit(cid: int, oid: int, cls: String) -> void :
	var aim: Vector2 = Vector2.INF
	for e: Array in strike_spots(cid):
		if int(e[3]) == oid:
			aim = e[0]
			break
	_hit["%d>%d" % [cid, oid]] = [gw.game_time, aim]
	_hit["%d>%s" % [cid, cls]] = gw.game_time
	stats["bot_hold_" + cls] = int(stats.get("bot_hold_" + cls, 0)) + 1




func hold_aim(cid: int, p: Vector2) -> int:
	if _hit.is_empty():
		return -1
	var ce: Array = _aims.get(cid, [])
	if ce.size() != 2 or float(ce[0]) != gw.game_time:

		var lst: Array = []
		var pre: String = "%d>" % cid
		for k: String in _hit:
			var e: Variant = _hit[k]
			if not (e is Array) or (e as Array).size() != 2 or not k.begins_with(pre) or gw.game_time - float(e[0]) >= HOLD_MEMO:
				continue
			if (e[1] as Vector2).is_finite():
				lst.append([e[1], int(k.substr(pre.length()))])
		ce = [gw.game_time, lst]
		_aims[cid] = ce
	for a: Array in ce[1]:
		if (a[0] as Vector2).distance_squared_to(p) <= 36.0:
			var oid: int = int(a[1])
			return 1 if holds.has(oid) and int(info(oid).get("in", 0)) > 0 else 0
	return -1




func garrison_near(cid: int, p: Vector2, r: float) -> int:
	var c: Country = gw.country_by_id(cid)
	if c == null or holds.is_empty():
		return 0
	var n: int = 0
	for oid: int in holds:
		var h: Dictionary = holds[oid]
		if not c.at_war.has(int(h["c"])):
			continue
		var sa: Array = h["s"]
		if (sa[0] as Vector2).distance_squared_to(p) > (r + 40.0) * (r + 40.0):
			continue
		var ua: Array = h["u"]
		for k in ua.size():
			var u: Unit = ua[k]
			if u.alive() and u.pi >= u.path.size() and u.pos.distance_to(sa[k]) <= 3.0 and u.pos.distance_squared_to(p) <= r * r:
				n += 1
	return n



func held_in_city(ci: int, holder: int) -> int:
	var n: int = 0
	for oid: int in holds:
		var h: Dictionary = holds[oid]
		if int(h["c"]) == holder and int(h.get("city", -1)) == ci:
			n += (h["u"] as Array).size()
	return n


func _hit_prune() -> void :
	for k: String in _hit.keys():
		var e: Variant = _hit[k]
		var t: float = float(e[0]) if e is Array else float(e)
		if gw.game_time - t >= (float(D_KNOW_T[2]) if k.begins_with("k") else maxf(HOLD_MEMO, float(D_RESTRIKE[0]))):
			_hit.erase(k)




func save_state() -> Dictionary:
	var ids: = PackedInt32Array()
	var hs: Array = []
	for oid: int in holds:
		ids.append(oid)
		var h: Dictionary = holds[oid]
		hs.append({"c": int(h["c"]), "home": h["home"], "u": (h["u"] as Array).duplicate(), "s": (h["s"] as Array).duplicate(), 
			"spr": int(h["spr"]), "x": int(h["x"]), "y": int(h["y"]), "hi": bool(h["hi"]), "auto": bool(h["auto"]), "out": h.get("out", Vector2(0, 7)), "city": int(h.get("city", -1))})
	var ck: = PackedInt32Array()
	var cv: = PackedFloat64Array()
	for uid: int in _cool:
		ck.append(uid)
		cv.append(float(_cool[uid]))
	var ok: = PackedInt32Array()
	var ov: = PackedFloat64Array()
	for oid2: int in _off:
		ok.append(oid2)
		ov.append(float(_off[oid2]))
	var hot: = PackedInt32Array()
	for hc: int in _hot:
		hot.append(hc)
	return {"ids": ids, "h": hs, "ck": ck, "cv": cv, "ok": ok, "ov": ov, "t1": _t1, "t5": _t5, "hot": hot, "bhit": _hit.duplicate(true)}


func load_state(d: Dictionary) -> void :
	holds.clear()
	_cool.clear()
	_off.clear()
	_uh.clear()
	_hot.clear()
	_hit.clear()
	_spots.clear()
	_aims.clear()
	var bh: Variant = d.get("bhit", {})
	if bh is Dictionary:
		for k: Variant in bh:
			var e: Variant = bh[k]
			if e is Array and (e as Array).size() == 2:
				_hit[String(k)] = [float(e[0]), e[1] if e[1] is Vector2 else Vector2.INF]
			elif e is float or e is int:
				_hit[String(k)] = float(e)
	var hot: Variant = d.get("hot", PackedInt32Array())
	if hot is PackedInt32Array:
		for hc: int in hot:
			_hot[hc] = true
	_t1 = float(d.get("t1", 0.0))
	_t5 = float(d.get("t5", 0.0))
	var ids: Variant = d.get("ids", PackedInt32Array())
	var hs: Variant = d.get("h", [])
	if ids is PackedInt32Array and hs is Array and (hs as Array).size() == (ids as PackedInt32Array).size():
		for i in (ids as PackedInt32Array).size():
			var e: Variant = hs[i]
			if not (e is Dictionary):
				continue
			var ua: Array = []
			var sa: Array = []
			var eu: Array = e.get("u", [])
			var es: Array = e.get("s", [])
			for k in mini(eu.size(), es.size()):
				if eu[k] is Unit and es[k] is Vector2:
					ua.append(eu[k])
					sa.append(es[k])
					_uh[(eu[k] as Unit).id] = int(ids[i])
			if ua.is_empty():
				continue
			var hf: Variant = e.get("home", null)
			holds[int(ids[i])] = {"c": int(e.get("c", 0)), "home": hf if hf is Facility else null, "u": ua, "s": sa, 
				"spr": int(e.get("spr", -1)), "x": int(e.get("x", 0)), "y": int(e.get("y", 0)), "hi": bool(e.get("hi", false)), 
				"auto": bool(e.get("auto", false)), "out": e.get("out", Vector2(0, 7)), "city": int(e.get("city", -1))}
	var ck: Variant = d.get("ck", PackedInt32Array())
	var cv: Variant = d.get("cv", PackedFloat64Array())
	if ck is PackedInt32Array and cv is PackedFloat64Array and (ck as PackedInt32Array).size() == (cv as PackedFloat64Array).size():
		for i in (ck as PackedInt32Array).size():
			_cool[int(ck[i])] = float(cv[i])
	var ok: Variant = d.get("ok", PackedInt32Array())
	var ov: Variant = d.get("ov", PackedFloat64Array())
	if ok is PackedInt32Array and ov is PackedFloat64Array and (ok as PackedInt32Array).size() == (ov as PackedFloat64Array).size():
		for i in (ok as PackedInt32Array).size():
			_off[int(ok[i])] = float(ov[i])
