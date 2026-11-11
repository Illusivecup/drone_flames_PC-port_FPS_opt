extends RefCounted























const PAD: int = 2
const HOME_R: float = 3200.0
const FADE_T: float = 0.6

static var stats: Dictionary = {}


static func movable(kind: int) -> bool:
	return Defense.is_ad(kind) or kind == Facility.Kind.AD_RADAR or kind == Facility.Kind.AD_EW or kind == Facility.Kind.COASTAL_ASM


static func _note(k: String) -> void :
	stats[k] = int(stats.get(k, 0)) + 1



static func clear_site(gw: GameWorld, city: City, plan: Dictionary, founder: Country) -> int:
	if gw.mil == null or founder == null:
		return 0
	var site: Dictionary = {}
	for q: Vector2i in plan.get("cells", []):
		site[q] = true
	var rr: int = int(plan.get("radius", city.radius)) * 116 / 100 + PAD
	var n: int = 0
	for f: Facility in gw.mil.facilities:
		if f.country_id == founder.id or not movable(f.kind) or gw.mil.is_demolished(f):
			continue
		var r: Rect2i
		if f.moving:
			r = Rect2i(Vector2i(floori(f.mpos.x / GameWorld.CELL), floori(f.mpos.y / GameWorld.CELL)) - Vector2i(1, 2), Vector2i(3, 3))
		else:
			r = Rect2i(f.cell, f.size)
		var hit: bool = false
		for y in range(r.position.y - PAD, r.end.y + PAD):
			for x in range(r.position.x - PAD, r.end.x + PAD):
				if site.has(Vector2i(x, y)) or (y >= r.position.y and y < r.end.y and x >= r.position.x and x < r.end.x and maxi(absi(x - city.center.x), absi(y - city.center.y)) <= rr):
					hit = true
					break
			if hit:
				break
		if not hit:
			continue
		_note("site_hits")
		if relocate(gw, f, founder, city, true):
			n += 1
	return n



static func on_claim(gw: GameWorld, cells: Array[Vector2i], owner_id: int, city: City) -> void :
	if gw.mil == null or cells.is_empty():
		return
	var founder: Country = gw.country_by_id(owner_id)
	var done: Dictionary = {}
	for f: Facility in gw.mil.facilities:
		if f.country_id == owner_id or f.moving or not movable(f.kind) or done.has(f.id) or gw.mil.is_demolished(f):
			continue
		var r: = Rect2i(f.cell, f.size)
		var hit: bool = false
		for q: Vector2i in cells:
			if r.has_point(q):
				hit = true
				break
		if not hit:
			continue
		var dp: Diplomacy = gw.diplo
		if dp != null and (dp.allied(f.country_id, owner_id) or dp.at_war(f.country_id, owner_id) or (dp.sky != null and dp.sky.covers(f.country_id, owner_id))):
			_note("claim_kept")
			continue
		done[f.id] = true
		_note("claim_hits")
		relocate(gw, f, founder, city, false)





static func relocate(gw: GameWorld, f: Facility, by: Country, city: City, site: bool, why: String = "") -> bool:
	var mil: Military = gw.mil
	var owner: Country = gw.country_by_id(f.country_id)
	if owner == null:
		return false
	var from_c: Vector2i = Vector2i(floori(f.mpos.x / GameWorld.CELL), floori(f.mpos.y / GameWorld.CELL)) - Vector2i(0, 1) if f.moving else f.cell + f.size / 2
	var from_px: Vector2 = Vector2(from_c * GameWorld.CELL) + Vector2(2, 2)
	var avoid: = Rect2i(city.center - Vector2i(city.radius + 4, city.radius + 4), Vector2i(city.radius * 2 + 9, city.radius * 2 + 9)) if city != null else Rect2i()
	var spot: Vector2i = home_spot(gw, f.kind, owner, from_c, avoid)
	var ghost: Array = _ghost_of(gw, f)
	var ruined: bool = not f.moving and f.main_obj >= 0 and gw.obj_state[f.main_obj] == 1
	var cname: String = city.name if city != null else ""
	var title: String = Military.title_of(f.kind)
	var bname: String = by.name if by != null else Loc.t("соседи")
	if spot.x < 0:
		var back: int = 0 if ruined else Military.cost_of(f.kind)
		if f.moving:
			f.moving = false
			f.mpath.clear()
			mil.drive_dir.erase(f.id)
		mil._dem_one(f)
		owner.money += back
		mil._update_power()
		gw.changed.emit()
		_note("refunded")
		_fx_out(gw, ghost, from_px)
		_say(gw, owner, by, Loc.msg(Loc.mk("ПВО снято (места дома нет, +%d): %s — %s", [back, title, why if why != "" else ((Loc.t("тут город %s") % cname) if site else (Loc.t("земля ушла к стране %s") % bname))])))
		return false

	var d: WorldData = gw.data
	if f.moving:
		f.moving = false
		f.mpath.clear()
		mil.drive_dir.erase(f.id)
	else:
		for y in range(f.cell.y, f.cell.y + f.size.y):
			for x in range(f.cell.x, f.cell.x + f.size.x):
				if d.inside(x, y):
					d.clear_flag(x, y, WorldData.F_OCCUPIED)
		for oid in f.obj_ids:
			gw.remove_object(oid)
	mil._stop_fx(f)
	f.queued.clear()

	var nw: Vector2i = Military.nw_for(f.kind, spot)
	f.cell = nw
	f.home_nw = nw
	for y2 in range(nw.y - 4, nw.y + f.size.y + 1):
		for x2 in range(nw.x - 1, nw.x + f.size.x + 1):
			if d.inside(x2, y2):
				gw.remove_tree_at(Vector2i(x2, y2))
	for y3 in range(nw.y, nw.y + f.size.y):
		for x3 in range(nw.x, nw.x + f.size.x):
			if d.inside(x3, y3):
				d.add_flag(x3, y3, WorldData.F_OCCUPIED)
	f.main_obj = gw.add_object(mil.vehicle_sprite(f), nw, GameWorld.KIND_BUILDING)
	f.obj_ids = PackedInt32Array([f.main_obj])
	gw.set_obj_frame(f.main_obj, mil.vehicle_sprite(f), 0)
	f.frame_i = 0
	if ruined:
		gw.obj_state[f.main_obj] = 1
		gw._mark_obj_chunk(f.main_obj)
	mil._roam_anchor.erase(f.id)
	mil._roam_wait.erase(f.id)
	gw.changed.emit()
	_note("moved")
	_fx_out(gw, ghost, from_px)
	_fx_in(gw, f)
	var km: float = from_px.distance_to(f.center_px()) / 1000.0
	_say(gw, owner, by, Loc.msg(Loc.mk("ПВО перенесено домой (%.1f км): %s — %s", [km, title, why if why != "" else ((Loc.t("тут город %s") % cname) if site else (Loc.t("земля ушла к стране %s") % bname))])))
	return true




static func home_spot(gw: GameWorld, kind: int, owner: Country, from_c: Vector2i, avoid: Rect2i) -> Vector2i:
	var mil: Military = gw.mil
	var starts: Array[Vector2i] = []
	var nb: Vector2i = mil.own_near(owner.id, from_c, HOME_R)
	if nb.x >= 0:
		starts.append(nb)
	var cs: Array = []
	for cid: int in owner.city_ids:
		var ct: City = gw.cities[cid]
		cs.append([Vector2(ct.center - from_c).length_squared(), cid])
	cs.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))
	for k in mini(4, cs.size()):
		var ct2: City = gw.cities[int(cs[k][1])]
		starts.append(ct2.center + Vector2i(0, ct2.radius + 3))
	var tried: int = 0
	for s: Vector2i in starts:
		for r in range(0, 44, 2):
			for q: Vector2i in _ring(s, r):
				if avoid.has_area() and avoid.has_point(q):
					continue
				if _ok(gw, kind, owner, q):
					return q
				tried += 1
		if tried > 3000:
			break
	return Vector2i(-1, -1)



static func _ring(s: Vector2i, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if r == 0:
		out.append(s)
		return out
	for t in range( - r, r, 2):
		out.append(s + Vector2i(t, - r))
		out.append(s + Vector2i(r, t))
		out.append(s + Vector2i( - t, r))
		out.append(s + Vector2i( - r, - t))
	return out


static func _ok(gw: GameWorld, kind: int, owner: Country, q: Vector2i) -> bool:
	var d: WorldData = gw.data
	if not d.inside(q.x, q.y) or d.get_owner_id(q.x, q.y) != owner.id:
		return false
	var nw: Vector2i = Military.nw_for(kind, q)
	var sz: Vector2i = Military.size_of(kind)
	for c: Vector2i in [nw, nw + Vector2i(sz.x - 1, 0), nw + Vector2i(0, sz.y - 1), nw + sz - Vector2i.ONE]:
		if not d.inside(c.x, c.y) or d.get_owner_id(c.x, c.y) != owner.id:
			return false
	return gw.mil.check_place(kind, nw, owner, null, false) == ""



static func _say(gw: GameWorld, owner: Country, by: Country, text: String) -> void :
	gw.say(owner, text)
	if by != null and by.id != owner.id:
		gw.say(by, Loc.mk("Площадка свободна: ПВО страны %s переброшено на её землю", [Loc.name(owner.name)]))




static func _ghost_of(gw: GameWorld, f: Facility) -> Array:
	if f.moving or f.main_obj < 0 or f.main_obj >= gw.obj_spr.size():
		return []
	var s: int = gw.obj_spr[f.main_obj]
	return [gw.spr_tex[s], gw.spr_rect[s], gw.obj_origin(f.main_obj)]


static func _sprite(gw: GameWorld, g: Array) -> Sprite2D:
	if g.is_empty() or gw.fx == null or g[0] == null:
		return null
	var at: = AtlasTexture.new()
	at.atlas = g[0]
	at.region = g[1]
	var sp: = Sprite2D.new()
	sp.texture = at
	sp.centered = false
	sp.position = g[2]
	sp.z_index = 5
	gw.fx.add_child(sp)
	return sp


static func _fx_out(gw: GameWorld, ghost: Array, p: Vector2) -> void :
	if gw.fx == null:
		return
	gw.fx.spawn("dust_s", p.round(), 6)
	var sp: Sprite2D = _sprite(gw, ghost)
	if sp == null:
		return
	var tw: Tween = sp.create_tween()
	tw.tween_property(sp, "modulate", Color(1.6, 1.7, 2.0, 0.0), FADE_T)
	tw.tween_callback(sp.queue_free)


static func _fx_in(gw: GameWorld, f: Facility) -> void :
	if gw.fx == null:
		return
	gw.fx.spawn("dust_s", f.center_px().round(), 6)
	var sp: Sprite2D = _sprite(gw, _ghost_of(gw, f))
	if sp == null:
		return
	sp.modulate = Color(2.2, 2.3, 2.6, 0.95)
	var tw: Tween = sp.create_tween()
	tw.tween_property(sp, "modulate", Color(1.0, 1.0, 1.0, 0.0), FADE_T)
	tw.tween_callback(sp.queue_free)







const UNIT_PAD: int = 3


static func _site_r_px(radius: int) -> float:
	return float(radius * 116 / 100 + UNIT_PAD) * GameWorld.CELL


static func _on_site(u: Unit, cell: Vector2i, rpx: float) -> bool:
	var c: = Vector2(cell * GameWorld.CELL) + Vector2(GameWorld.CELL, GameWorld.CELL) * 0.5
	return absf(u.pos.x - c.x) <= rpx and absf(u.pos.y - c.y) <= rpx



static func war_blocked(gw: GameWorld, cell: Vector2i, founder: Country, radius: int) -> bool:
	if gw.army == null or gw.diplo == null or founder == null:
		return false
	var rpx: float = _site_r_px(radius)
	for u: Unit in gw.army.units:
		if u.country_id == founder.id or not u.alive() or not u.ground():
			continue
		if gw.diplo.at_war(founder.id, u.country_id) and _on_site(u, cell, rpx):
			_note("war_block")
			return true
	return false




static func _exit_point(gw: GameWorld, cid: int, p: Vector2, cell: Vector2i, rpx: float) -> Vector2:
	var pc: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	var rc: int = int(HOME_R / GameWorld.CELL)
	var rs: int = int(rpx / GameWorld.CELL)
	for r in range(2, rc, 2):
		var best: = Vector2i(-1, -1)
		var bd: int = 1 << 30
		for k in range( - r, r + 1, 2):
			for q: Vector2i in [pc + Vector2i(k, - r), pc + Vector2i(k, r), pc + Vector2i( - r, k), pc + Vector2i(r, k)]:
				if not gw.data.inside(q.x, q.y) or gw.data.get_owner_id(q.x, q.y) != cid:
					continue
				if maxi(absi(q.x - cell.x), absi(q.y - cell.y)) <= rs or not Biome.is_natural_land(gw.data.get_biome(q.x, q.y)):
					continue
				var d: int = (q - pc).length_squared()
				if d < bd:
					bd = d
					best = q
		if best.x >= 0:
			return Vector2(best * GameWorld.CELL) + Vector2(GameWorld.CELL, GameWorld.CELL) * 0.5
	var cen: = Vector2(cell * GameWorld.CELL)
	var dir: Vector2 = (p - cen).normalized() if p.distance_to(cen) > 1.0 else Vector2.RIGHT
	return gw.econ.land_point(cen + dir * (rpx + 4.0 * GameWorld.CELL), 8) if gw.econ != null else cen + dir * (rpx + 4.0 * GameWorld.CELL)



static func clear_units(gw: GameWorld, city: City, founder: Country, radius: int) -> int:
	if gw.army == null or founder == null:
		return 0
	var rpx: float = _site_r_px(radius)
	var homes: Array[Facility] = []
	var seen: Dictionary = {}
	var loose: Array[Unit] = []
	for u: Unit in gw.army.units:
		if u.country_id == founder.id or not u.alive() or not u.ground() or not _on_site(u, city.center, rpx):
			continue
		if u.home != null and gw.mil != null and gw.mil.alive(u.home):
			if not seen.has(u.home.id):
				seen[u.home.id] = true
				homes.append(u.home)
		else:
			loose.append(u)
	var n: int = 0
	for f: Facility in homes:
		var mem: Array[Unit] = gw.army.units_of(f)
		var cen: = Vector2.ZERO
		var k: int = 0
		for u2: Unit in mem:
			if u2.alive() and u2.ground() and _on_site(u2, city.center, rpx):
				cen += u2.pos
				k += 1
		if k == 0:
			continue
		var dest: Vector2 = _exit_point(gw, f.country_id, cen / float(k), city.center, rpx)
		var why: String = "?"
		if gw.ops != null:
			var q0: bool = gw.ops._quiet
			gw.ops._quiet = true
			why = gw.ops.start(f, Operations.Kind.DEFEND, dest)
			if why != "" and why != Operations.PENDING:
				why = gw.ops.start(f, Operations.Kind.RETREAT, Vector2.ZERO)
			gw.ops._quiet = q0
		if why != "" and why != Operations.PENDING:
			for u3: Unit in mem:
				if u3.alive() and u3.ground() and _on_site(u3, city.center, rpx):
					u3.target = null
					u3.target_city = -1
					u3.op_on = false
					u3.op_hold = false
					gw.army.tac._go(u3, dest)
		n += 1
		_note("units_out")
		gw.say(f.country_id, Loc.mk("Армия №%d выведена: %s строит город %s", [f.army_no, Loc.name(founder.name), Loc.name(city.name)]))
	for u4: Unit in loose:
		u4.target = null
		u4.target_city = -1
		gw.army.tac._go(u4, _exit_point(gw, u4.country_id, u4.pos, city.center, rpx))
		n += 1
		_note("units_out")
	return n
