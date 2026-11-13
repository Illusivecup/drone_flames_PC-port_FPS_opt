extends "res://game/game_world/gw_infra.gd"






func _as_gw() -> GameWorld:
	return (self as Object) as GameWorld



func create_country(is_player: bool, legacy_flag: bool = false) -> Country:
	var c: = Country.new()
	c.id = countries.size() + 1
	c.is_player = is_player
	c.style = COUNTRY_STYLES[_style_slot(c.id, is_player)]
	c.color = Color.html(String(c.style["map"])) if c.style.has("map") else Palette.c(String(c.style["base"]))
	c.color_light = Palette.c(String(c.style["light"])) if c.style.has("light") else c.color.lightened(0.35)
	c.color_dark = Palette.c(String(c.style["dark"])) if c.style.has("dark") else c.color.darkened(0.45)
	c.name = NameGen.country(rng, countries.map( func(o: Country) -> String: return o.name))
	c.money = Military.START_MONEY
	c.titanium = 20
	c.food = 30


	apply_flag(c, FlagMaker.encode(FlagMaker.random_spec(Rng.new(data.world_seed + c.id * 131), int(FlagMaker.MAIN_OF.get(String(c.style["base"]), -1)), not legacy_flag)), false)
	countries.append(c)
	if is_player:
		player = c
	_update_territory_colors()
	return c




func spawn_ai_countries(count: int) -> void :

	var cb: Array = GameConfig.cb_list.slice(0, GameConfig.CB_MAX) if GameConfig.cb_active() else []
	var lands: Array = cb_lands() if not cb.is_empty() else []
	if not cb.is_empty():
		count = cb.size()
	_landmasses()
	for k in count:

		var lm: int = _spawn_landmass(count - k)
		var spot: Vector2i = _find_capital_spot(lm)
		if spot.x < 0 and lm >= 0:
			spot = _find_capital_spot(-1)
		if spot.x < 0:
			if not cb.is_empty():
				print("[CUSTOMBOTS] no room for %d of %d bots" % [count - k, count])
			break
		var c: Country = create_country(false)
		if k < cb.size():
			_cb_apply(c, cb[k], int(lands[k + 1]))
		c.arch = ArchStyle.seeded(self, c.id)
		if k < cb.size() and int((cb[k] as Dictionary).get("a", -1)) >= 0:
			c.arch = clampi(int((cb[k] as Dictionary).get("a", -1)), 0, 3)
		var cap: City = found_city(spot, c, City.Kind.CAPITAL)
		if cap == null:
			continue
		mil.capital_plant(c, cap)
		for t in 2:
			_ai_try_town(c)




func _cb_apply(c: Country, e: Dictionary, land: int) -> void :
	var nm: String = NameGen.clean_country(String(e.get("n", "")))
	var free: bool = NameGen.country_name_error(nm) == ""
	for o: Country in countries:
		if o != c and o.name.to_lower() == nm.to_lower():
			free = false
	if free:
		c.name = nm
	apply_flag(c, String(e.get("f", "")), false)
	_restyle(c, land)
	c.ai_diff = clampi(int(e.get("d", GameConfig.difficulty)), 0, 2)
	c.money = maxi(0, int(e.get("m", Military.START_MONEY)))
	var pid: String = String(e.get("p", ""))
	if pid != "" and AiPersona.ids().has(pid) and ai != null:
		ai.personas[c.id] = pid
		if diplo != null:
			diplo.known[c.id] = true



func _lm_per_country() -> int:
	return maxi(CAP_ROOM, LM_PER_COUNTRY * data.w / 1024)


func _landmasses() -> void :
	var cw: int = data.w / LM_ST
	var ch: int = data.h / LM_ST
	_lm_area.clear()
	_lm_box.clear()


	var bio: PackedByteArray = data.biome
	var fl: PackedByteArray = data.flags
	var w: int = data.w
	var pas: = PackedByteArray()
	pas.resize(cw * ch)
	for by in ch:
		var row: int = (by * LM_ST + 2) * w
		for bx in cw:
			var si: int = row + bx * LM_ST + 2
			if bio[si] > Biome.RIVER:
				pas[by * cw + bx] = 2
			elif (fl[si] & WorldData.F_BRIDGE) != 0:
				pas[by * cw + bx] = 1
	var lab: = PackedInt32Array()
	lab.resize(cw * ch)
	var q: = PackedInt32Array()
	for i0 in cw * ch:
		if lab[i0] != 0 or pas[i0] != 2:
			continue
		var id: int = _lm_area.size()
		lab[i0] = id + 1
		q.resize(0)
		q.append(i0)
		var h: int = 0
		var x0: int = i0 % cw
		var y0: int = i0 / cw
		var mnx: int = x0
		var mxx: int = x0
		var mny: int = y0
		var mxy: int = y0
		while h < q.size():
			var c: int = q[h]
			h += 1
			var cx: int = c % cw
			var cy: int = c / cw
			mnx = mini(mnx, cx)
			mxx = maxi(mxx, cx)
			mny = mini(mny, cy)
			mxy = maxi(mxy, cy)
			if cx + 1 < cw and lab[c + 1] == 0 and pas[c + 1] != 0:
				lab[c + 1] = id + 1
				q.append(c + 1)
			if cx > 0 and lab[c - 1] == 0 and pas[c - 1] != 0:
				lab[c - 1] = id + 1
				q.append(c - 1)
			if cy + 1 < ch and lab[c + cw] == 0 and pas[c + cw] != 0:
				lab[c + cw] = id + 1
				q.append(c + cw)
			if cy > 0 and lab[c - cw] == 0 and pas[c - cw] != 0:
				lab[c - cw] = id + 1
				q.append(c - cw)
		_lm_area.append(q.size())
		var box: = Rect2i(x0, y0, 1, 1).expand(Vector2i(mnx, mny)).expand(Vector2i(mxx, mxy))
		_lm_box.append(Rect2i(box.position * LM_ST, (box.size + Vector2i.ONE) * LM_ST))
	_lm_lab = lab


func landmass_at(c: Vector2i) -> int:
	var cw: int = data.w / LM_ST
	var bx: int = c.x / LM_ST
	var by: int = c.y / LM_ST
	if _lm_lab.is_empty() or bx < 0 or by < 0 or bx >= cw or by >= data.h / LM_ST:
		return -1
	return _lm_lab[by * cw + bx] - 1






func _spawn_landmass(left: int) -> int:
	if _lm_area.is_empty():
		return -1
	var cnt: Dictionary = {}
	for oc: City in cities:
		if oc.kind == City.Kind.CAPITAL:
			var l: int = landmass_at(oc.center)
			if l >= 0:
				cnt[l] = int(cnt.get(l, 0)) + 1
	var best: int = -1
	var best_a: int = 0
	for step in 3:
		for l in _lm_area.size():
			var n: int = int(cnt.get(l, 0))
			var cap: int = _lm_area[l] / _lm_per_country()
			var a: int = _lm_area[l] - n * _lm_per_country()
			var fit: bool = false
			match step:
				0:
					fit = n == 1 and cap >= 2
				1:
					fit = n == 0 and cap >= 2 and left >= 2
				2:
					fit = n >= 2 and n < cap
			if fit and a > best_a:
				best_a = a
				best = l
		if best >= 0:
			return best
	return -1


func _find_capital_spot(lm: int = -1) -> Vector2i:
	var best: = Vector2i(-1, -1)
	var best_d: int = -1
	var fb: = Vector2i(-1, -1)
	var fb_room: int = -1
	var r: = Rng.new(data.world_seed + cities.size() * 17 + 5)
	var area: = Rect2i(data.w / 10, data.h / 10, data.w * 8 / 10, data.h * 8 / 10)
	if lm >= 0:
		area = area.intersection(_lm_box[lm])
		if area.size.x <= 0 or area.size.y <= 0:
			return Vector2i(-1, -1)
	for tries in (260 if lm < 0 else 360):
		var p: = Vector2i(r.range_ab(area.position.x, area.end.x - 1), r.range_ab(area.position.y, area.end.y - 1))
		if not Biome.is_natural_land(data.get_biome(p.x, p.y)) or data.get_owner_id(p.x, p.y) != 0:
			continue
		if lm >= 0 and landmass_at(p) != lm:
			continue
		var md: int = 1 << 30
		for oc: City in cities:
			md = mini(md, absi(oc.center.x - p.x) + absi(oc.center.y - p.y))
		if md < (data.w / 6 if lm < 0 else data.w / 9) or md <= best_d:
			continue
		if not bool(can_found_city(p, City.Kind.CAPITAL)["ok"]):
			continue
		var room: int = _land_room(p, CAP_ROOM)
		if room < CAP_ROOM:
			if room > fb_room:
				fb_room = room
				fb = p
			continue
		best_d = md
		best = p
	return best if best.x >= 0 else fb


func _land_room(p: Vector2i, need: int) -> int:
	var st: int = 4
	var c0: = Vector2i(p.x / st, p.y / st)
	var seen: Dictionary = {c0: true}
	var q: Array[Vector2i] = [c0]
	var n: int = 0
	var i: int = 0
	while i < q.size() and n < need:
		var c: Vector2i = q[i]
		i += 1
		var x: int = c.x * st + st / 2
		var y: int = c.y * st + st / 2
		if i > 1 and ( not data.inside(x, y) or not Biome.is_natural_land(data.get_biome(x, y)) or data.get_owner_id(x, y) != 0):
			continue
		n += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = c + d
			if not seen.has(nb):
				seen[nb] = true
				q.append(nb)
	return n


func _ai_try_town(c: Country) -> bool:
	if c.capital_id < 0:
		return false
	if diplo != null and diplo.conf != null and diplo.conf._in_conf(c.id):
		return false
	var cap: City = cities[c.capital_id]
	for tries in 40:
		var dist: int = rng.range_ab(46, cap.claim_max * 11 / 10)
		var p: = cap.center + Vector2i(rng.range_ab( - dist, dist), rng.range_ab( - dist, dist))
		if not data.inside(p.x, p.y):
			continue
		var o: int = data.get_owner_id(p.x, p.y)
		if o != 0 and o != c.id:
			continue
		var near: bool = false
		for oc: City in cities:
			if absi(oc.center.x - p.x) + absi(oc.center.y - p.y) < MIN_CITY_DIST:
				near = true
				break
		if near:
			continue


		if not BORDER_GAP.own_ok(self, p, c.id, 21) or not BORDER_GAP.site_ok(self, p, c.id, 21):
			continue
		if preload("res://game/ad_relocate.gd").war_blocked(self, p, c, 14):
			continue
		var pl: Dictionary = can_found_city(p, City.Kind.TOWN) if cad344 == null else cad344.can_found_ai(p, City.Kind.TOWN)
		if bool(pl["ok"]):
			return found_city(p, c, City.Kind.TOWN, pl) != null
		pl = can_found_city(p, City.Kind.VILLAGE) if cad344 == null else cad344.can_found_ai(p, City.Kind.VILLAGE)
		if not bool(pl["ok"]):
			continue
		return found_city(p, c, City.Kind.VILLAGE, pl) != null
	return false




func player_found_town(cell: Vector2i, who: Country = null) -> City:
	var pl: Country = who if who != null else player
	if pl == null or not data.inside(cell.x, cell.y):
		return null
	var o: int = data.get_owner_id(cell.x, cell.y)
	if o != 0 and o != pl.id:
		message.emit(Loc.msg(Loc.mk("Это чужая территория")))
		return null
	for oc: City in cities:
		if absi(oc.center.x - cell.x) + absi(oc.center.y - cell.y) < MIN_CITY_DIST:
			message.emit(Loc.msg(Loc.mk("Слишком близко к другому городу")))
			return null
	if o != pl.id and not _near_own_land(cell, TOWN_REACH, pl.id):
		message.emit(Loc.msg(Loc.mk("Слишком далеко от своей страны (макс. %d м)", [TOWN_REACH * CELL])))
		return null
	var price: int = Military.town_cost(pl.towns_founded)
	if pl.money < price:
		message.emit(Loc.msg(Loc.mk("Не хватает денег: город стоит %d", [price])))
		return null
	return purchase_town(cell, pl)


func _near_own_land(cell: Vector2i, reach: int, cid: int = -1) -> bool:
	if cid < 0:
		cid = player.id
	var step: int = 3
	for dy in range( - reach, reach + 1, step):
		for dx in range( - reach, reach + 1, step):
			var q: = cell + Vector2i(dx, dy)
			if data.inside(q.x, q.y) and data.get_owner_id(q.x, q.y) == cid:
				return true
	return false


func place_player_capital(cell: Vector2i) -> City:
	if player != null and (player.eliminated or player.capital_id >= 0):
		return null
	if player == null:
		create_country(true)
	if player.city_ids.is_empty():
		player.arch = clampi(GameConfig.arch_i, 0, 3)
		if countries.size() <= 1:
			apply_identity(player)
	var cap: City = found_city(cell, player, City.Kind.CAPITAL)
	if cap == null:
		return null
	mil.capital_plant(player, cap)
	if countries.size() <= 1:
		spawn_ai_countries(GameConfig.bots)
		session.start()
		if _xb_want():
			_delay(3.0, _extra_river_links)
	_flush_territory()
	_update_checkpoints()
	return cap





func mp_setup_humans(n: int, local_slot: int, names: Array = [], archs: Array = [], flags: Array = []) -> void :
	var used: Dictionary = {}
	for i in n:
		var c: Country = create_country(true)
		if c != null and i < archs.size():
			c.arch = clampi(int(archs[i]), 0, 3)
		var nick: String = NetConfig.clean_nick(String(names[i])) if i < names.size() else ""
		if c != null and nick != "":
			var nm: String = nick
			var k: int = 2
			while used.has(nm.to_lower()):
				nm = "%s %d" % [nick, k]
				k += 1
			used[nm.to_lower()] = true
			c.name = nm
		if c != null and i < flags.size() and String(flags[i]) != "":
			apply_flag(c, String(flags[i]), false)
	player = countries[clampi(local_slot, 0, countries.size() - 1)]





func _ranked_spot(c: Country) -> Vector2i:
	var r: Rect2i = RankedRules.half_of(self, c)
	var mid: Vector2i = r.position + r.size / 2
	for ring in range(0, maxi(r.size.x, r.size.y) / 2, 6):
		for dx in range( - ring, ring + 1, 6):
			for dy in [ - ring, ring]:
				for q: Vector2i in [mid + Vector2i(dx, dy), mid + Vector2i(dy, dx)]:
					if r.has_point(q) and data.inside(q.x, q.y) and bool(can_found_city(q, City.Kind.CAPITAL, true)["ok"]):
						return q
	return Vector2i(-1, -1)


func mp_place_capital(cid: int, cell: Vector2i) -> City:
	var c: Country = country_by_id(cid)
	if c == null or not c.is_player or c.capital_id >= 0 or c.eliminated:
		return null
	if cell.x >= 0 and data.inside(cell.x, cell.y) and RankedRules.capital_why(_as_gw(), c, cell) != "":
		say(c, RankedRules.capital_why(_as_gw(), c, cell))
		return null
	if cell.x < 0 or not data.inside(cell.x, cell.y):
		_landmasses()
		cell = _find_capital_spot(-1)
		if RankedRules.active() and cell.x >= 0 and RankedRules.capital_why(_as_gw(), c, cell) != "":
			cell = _ranked_spot(c)
		if cell.x < 0:
			return null
	for oc: City in cities:
		if absi(oc.center.x - cell.x) + absi(oc.center.y - cell.y) < MIN_CITY_DIST * 2:
			if c == player:
				message.emit(Loc.msg(Loc.mk("Слишком близко к другой столице")))
			return null
	var cap: City = found_city(cell, c, City.Kind.CAPITAL)
	if cap == null:
		return null
	mil.capital_plant(c, cap)
	if mp_all_capitals() and session != null and not session.started:
		spawn_ai_countries(mini(GameConfig.bots, maxi(0, 8 - countries.size())))
		session.start()
		if _xb_want():
			_delay(3.0, _extra_river_links)
	_flush_territory()
	_update_checkpoints()
	return cap


func mp_all_capitals() -> bool:
	for c: Country in countries:
		if c.is_player and c.capital_id < 0 and not c.eliminated:
			return false
	return true



func cmd_build_sub(kind: int, cell: Vector2i, pl: Country) -> Facility:
	var pwhy: String = mil.place_why(kind, cell, pl, null, false)
	if pwhy != "":
		say(pl, pwhy)
		return null
	if econ.pay_substituted(pl, Economy.build_cost(kind)) != "":
		return null
	return mil.build(kind, cell, pl, null, true)
func cmd_field(o: Object, field: String, v: Variant) -> void :
	if o != null and CMD_FIELDS.has(field) and field in o:
		o.set(field, v)


func cmd_city_rename(cid: int, new_name: String) -> void :
	if cid >= 0 and cid < cities.size():
		var c: City = cities[cid]
		if c != null:
			var trimmed: String = new_name.strip_edges()
			if trimmed != "":
				c.name = trimmed



func cmd_recall(cid: int, rid: int) -> String:
	for d: Variant in recon.drones:
		if int(d.id) == rid and int(d.country_id) == cid:
			return String(recon.recall(d))
	return Loc.t("Дрон не найден")




func mp_to_human(cid: int) -> void :
	var c: Country = country_by_id(cid)
	if c != null and not c.is_player and not c.eliminated:
		c.is_player = true


func mp_to_ai(cid: int) -> void :
	var c: Country = country_by_id(cid)
	if c != null and c.is_player and c != player:
		c.is_player = false


func _extra_river_links() -> void :
	if not _xb_want() or data == null or cities.size() < 2:
		return
	if not _road_jobs.is_empty() and _xb_tries < 10:
		_xb_tries += 1
		_delay(2.0, _extra_river_links)
		return
	_xb_tries = 0
	var base: int = 0
	for b: Bridge in bridges:
		if b.kind != Bridge.Kind.RAIL:
			base += 1


	var b0: int = base - _xb_made
	var want: int = mini(2 if not _xb_second else roundi(float(b0) * 0.45) - _xb_made, 5 - _xb_made)
	if not _xb_second:
		_xb_second = true
		_delay(150.0, _extra_river_links)
	if want <= 0:
		return
	_landmasses()



	var max_d: int = maxi(140, data.w * 34 / 100)
	var cands: Array = []
	var bio: PackedByteArray = data.biome
	var dw: int = data.w
	for i in cities.size():
		for j in range(i + 1, cities.size()):
			var ca: City = cities[i]
			var cb: City = cities[j]
			var dd: int = maxi(absi(ca.center.x - cb.center.x), absi(ca.center.y - cb.center.y))
			if dd < 50 or dd > max_d:
				continue
			var was_w: bool = false
			var tried: int = 0
			var dl: Vector2i = cb.center - ca.center
			for k in range(1, dd):
				var p: Vector2i = ca.center + dl * k / dd
				var wtr: bool = bio[p.y * dw + p.x] <= Biome.RIVER
				if wtr and not was_w and tried < 4 and not data.has_flag(p.x, p.y, WorldData.F_BRIDGE):
					tried += 1
					if _xb_far(p, []):
						var cr: Array = _xb_crossing(p, ca.center, cb.center)
						if not cr.is_empty():
							cands.append([(cr[0] as Array).size() * 4 + dd / 10, i, j, cr])
							break
				was_w = wtr
	cands.sort_custom( func(x: Array, y: Array) -> bool: return int(x[0]) < int(y[0]) or (int(x[0]) == int(y[0]) and int(x[1]) * 1000 + int(x[2]) < int(y[1]) * 1000 + int(y[2])))


	var mids: Array = []
	var links: Array = []
	var xb: Array = []
	for c2: Array in cands:
		if xb.size() >= 12:
			break
		var cr2: Array = c2[3]
		var cross: Array[Vector2i] = []
		cross.assign(cr2[0])
		var mid: Vector2i = cross[cross.size() / 2]
		if not _xb_far(mid, mids):
			continue
		mids.append(mid)
		xb.append([cross, mid])

		links.append([_xb_target(cr2[1], cr2[2], cities[int(c2[1])].entrance), cr2[1]])
		links.append([cr2[2], _xb_target(cr2[2], cr2[1], cities[int(c2[2])].entrance)])
	if not xb.is_empty():
		var job: Dictionary = _road_job(links, false)
		job["xb"] = xb
		job["xb_want"] = want
		job["task"] = WorkerThreadPool.add_task(_xb_worker.bind(job), false, "roads")
		_road_jobs.append(job)




func _xb_crossing(hit: Vector2i, a: Vector2i, b: Vector2i) -> Array:
	var best: Array = []
	var best_n: int = 1 << 30
	var horiz: bool = absi(b.x - a.x) >= absi(b.y - a.y)


	var W: int = data.w
	var H: int = data.h
	var bio: PackedByteArray = data.biome
	var fla: PackedByteArray = data.flags
	var lakes_on: bool = not data.lakes.is_empty()
	var d: Vector2i = Vector2i(signi(b.x - a.x), 0) if horiz else Vector2i(0, signi(b.y - a.y))
	if d == Vector2i.ZERO:
		return best
	for off in range(-20, 21, 2):
		var o: Vector2i = hit + (Vector2i(0, off) if horiz else Vector2i(off, 0))
		if o.x < 0 or o.y < 0 or o.x >= W or o.y >= H or bio[o.y * W + o.x] > Biome.RIVER:
			continue

		var s0: Vector2i = o
		for k in 30:
			var q: Vector2i = s0 - d
			if q.x < 0 or q.y < 0 or q.x >= W or q.y >= H or bio[q.y * W + q.x] > Biome.RIVER:
				break
			s0 = q
		var near_bank: Vector2i = s0 - d
		var e0: Vector2i = o
		var fresh: bool = true
		var n: int = 0
		var p: Vector2i = s0
		while n < 40 and p.x >= 0 and p.y >= 0 and p.x < W and p.y < H and bio[p.y * W + p.x] <= Biome.RIVER:
			var pi: int = p.y * W + p.x
			var bb: int = bio[pi]
			if not (bb == Biome.RIVER or (lakes_on and data.lake_at(p.x, p.y) == 1)):
				fresh = false
			if (fla[pi] & WorldData.F_BRIDGE) != 0:
				n = 999
				break
			e0 = p
			p += d
			n += 1
		var far_bank: Vector2i = e0 + d


		if n < 3 or n > 10 or not fresh or landmass_at(near_bank) < 0 or landmass_at(near_bank) != landmass_at(far_bank):
			continue
		var ok: bool = true
		for q2: Vector2i in [near_bank, far_bank]:
			if q2.x < 0 or q2.y < 0 or q2.x >= W or q2.y >= H:
				ok = false
				continue
			var f2: int = fla[q2.y * W + q2.x]
			if (f2 & WorldData.F_OCCUPIED) != 0 or not (Biome.is_natural_land(bio[q2.y * W + q2.x]) or (f2 & WorldData.F_ROAD) != 0):
				ok = false
			elif not _xb_flat(q2):
				ok = false
		if not ok or n >= best_n:
			continue
		var cells: Array[Vector2i] = []
		var t: Vector2i = near_bank
		while t != far_bank + d:
			cells.append(t)
			t += d
		best = [cells, near_bank, far_bank]
		best_n = n
	return best

func capture_city(city: City, new_id: int) -> void :
	var old_id: int = city.country_id
	var old: Country = country_by_id(old_id)
	var nc: Country = country_by_id(new_id)
	if old == null or nc == null or old_id == new_id:
		return
	city.country_id = new_id
	var arr: = PackedInt32Array()
	for id in old.city_ids:
		if id != city.id:
			arr.append(id)
	old.city_ids = arr
	nc.city_ids.append(city.id)
	var was_capital: bool = old.capital_id == city.id
	if was_capital:
		old.capital_id = -1
		var best: int = -1
		for id in old.city_ids:
			if best < 0 or cities[id].kind < cities[best].kind:
				best = id
		if best >= 0:
			old.capital_id = best
			cities[best].kind = City.Kind.CAPITAL
	if city.kind == City.Kind.CAPITAL:
		city.kind = City.Kind.TOWN

	var r: int = int(city.claim_max * 1.4) + 4
	var c0: Vector2i = city.center
	var others: Array[Vector2i] = []
	for id in old.city_ids:
		others.append(cities[id].center)


	var on_own: Dictionary = {}
	for f0: Facility in mil.facilities:
		if f0.country_id == old_id:
			var h0: Facility = f0.parent if f0.parent != null else f0
			var c1: Vector2i = h0.cell + h0.size / 2
			if data.inside(c1.x, c1.y) and data.get_owner_id(c1.x, c1.y) == old_id:
				on_own[f0.id] = true
	var moved: Array[Vector2i] = []




	var own: PackedByteArray = data.owners
	var dw: int = data.w
	var x0: int = maxi(1, c0.x - r)
	var x1: int = mini(data.w - 1, c0.x + r + 1) - 1
	var spl: = PackedInt32Array()
	var sph: = PackedInt32Array()
	var sy0: int = maxi(1, c0.y - r)
	for y in range(maxi(1, c0.y - r), mini(data.h - 1, c0.y + r + 1)):
		var lo: int = x0
		var hi: int = x1
		var dyc: int = (y - c0.y) * (y - c0.y)
		for oc: Vector2i in others:

			var m: int = 2 * (c0.x - oc.x)
			var rr: int = c0.x * c0.x - oc.x * oc.x + dyc - (y - oc.y) * (y - oc.y)
			if m > 0:
				lo = maxi(lo, _cdiv(rr, m))
			elif m < 0:
				hi = mini(hi, _fdiv( - rr, - m))
			elif rr > 0:
				hi = lo - 1
			if lo > hi:
				break
		spl.append(lo)
		sph.append(hi)
		var row: int = y * dw
		for x in range(lo, hi + 1):
			var i: int = row + x
			if own[i] != old_id:
				continue
			own[i] = new_id
			if (x + y) % 3 == 0:
				moved.append(Vector2i(x, y))
	if BORDER_GAP.soft_on:
		BORDER_FILL.warp_capture(own, data.owners, data.flags, dw, data.h, border_noise, spl, sph, sy0, old_id, new_id)
	data.owners = own
	data.owners_dirty = true
	top.flash_cells(moved)
	_checkpoints_dirty = true
	enclave_check(new_id)
	enclave_check(old_id)

	var bars: Array = []
	for f: Facility in mil.facilities:
		if f.country_id != old_id:
			continue
		var fc: Vector2i = f.cell + f.size / 2
		var host: Facility = f.parent if f.parent != null else f
		var hc: Vector2i = host.cell + host.size / 2
		if data.inside(hc.x, hc.y) and data.get_owner_id(hc.x, hc.y) == new_id and on_own.has(f.id):
			f.country_id = new_id
			f.queued.clear()
			if f.kind == Facility.Kind.BARRACKS:
				bars.append(f)
			if data.inside(fc.x, fc.y):
				pass
	if army != null and not bars.is_empty():
		army.on_barracks_captured(bars, old_id, new_id)
	for a: Aircraft in mil.air.aircraft:
		if a.base == null or a.base.country_id != new_id or a.country_id != old_id or a.state == Aircraft.State.DEAD:
			continue
		if not a.airborne():
			a.country_id = new_id
			continue

		var alt: Facility = null
		for f2: Facility in mil.facilities:
			if f2.kind == Facility.Kind.AIRFIELD and f2.country_id == old_id and mil.alive(f2):
				alt = f2
				break
		if alt != null:
			a.base = alt
			a.spot = mil.air._free_spot(alt, a.type == Aircraft.Type.BOMBER)
			if a.spot == -2:
				mil.air._shot_down(a, "аэродром захвачен")
		else:
			mil.air._shot_down(a, "аэродром захвачен")
	for d: Drone in mil.drones:
		if d.airfield != null and d.airfield.country_id == new_id and d.country_id == old_id and not d.airborne():
			d.country_id = new_id
			d.state = Drone.State.PARKED if d.spot >= 0 else Drone.State.DONE
			if d.launcher != null and d.launcher.reserved == d:
				d.launcher.reserved = null
			d.launcher = null
	if city.flag_node != null and is_instance_valid(city.flag_node):
		(city.flag_node as AnimatedSprite2D).sprite_frames = nc.flag_frames
	if not city.taken_by.has(new_id) and not capture_quiet:
		city.taken_by[new_id] = true
		nc.captured += 1
	if not capture_quiet:
		old.lost += 1
	if old.city_ids.is_empty():
		old.capital_id = -1
	if capture_quiet:
		city_captured.emit(city, old_id)
		changed.emit()
		return
	var p: = Vector2(city.center * CELL)
	fx.spawn("capture_burst", p.round(), 7)
	if nc.is_player or old.is_player:
		Sfx.ui("ui_capture" if nc.is_player else "ui_city_lost")
	_delay(0.4, fx.spawn.bind("capture_burst", (p + Vector2(10, 4)).round(), 7))
	_delay(0.8, fx.spawn.bind("capture_burst", (p + Vector2(-9, 6)).round(), 7))
	news_m(Loc.mk("%s ЗАХВАТЫВАЕТ %s%s", [Loc.name(nc.name).to_upper(), Loc.name(city.name).to_upper(), Loc.t(" (БЫВШАЯ СТОЛИЦА)") if was_capital else ""]), "amber")
	city_captured.emit(city, old_id)
	changed.emit()



static func _cdiv(a: int, b: int) -> int:
	return (a + b - 1) / b if a >= 0 else - (( - a) / b)


static func _fdiv(a: int, b: int) -> int:
	return a / b if a >= 0 else - (( - a + b - 1) / b)






func new_country_from(ids: Array) -> Country:
	if countries.size() >= 8 or ids.is_empty():
		return null
	var src: Country = country_by_id(cities[int(ids[0])].country_id) if int(ids[0]) >= 0 and int(ids[0]) < cities.size() else null
	var c: Country = create_country(false)
	c.ai_diff = src.ai_diff if src != null and not src.is_player else -1
	c.arch = ArchStyle.native_of(_as_gw(), ids)
	c.money = 1500
	c.food = 30
	var was: bool = capture_quiet
	capture_quiet = true
	for cid: Variant in ids:
		var k: int = int(cid)
		if k >= 0 and k < cities.size():
			capture_city(cities[k], c.id)
	capture_quiet = was
	var best: int = -1
	for id in c.city_ids:
		if best < 0 or cities[id].kind < cities[best].kind or (cities[id].kind == cities[best].kind and cities[id].radius > cities[best].radius):
			best = id
	assert (best >= 0, "new_country_from: no city moved")
	c.capital_id = best
	cities[best].kind = City.Kind.CAPITAL
	_update_territory_colors()
	return c



func reflag_country(c: Country, salt: int) -> void :
	assert (c != null and salt != 0)
	apply_flag(c, FlagMaker.encode(FlagMaker.random_spec(Rng.new(data.world_seed + c.id * 131 + salt * 7919), int(FlagMaker.MAIN_OF.get(String(c.style["base"]), -1)))))





func apply_flag(c: Country, code: String, live: bool = true) -> void :
	if c == null or FlagMaker.decode(code).is_empty():
		return
	c.flag_spec = code
	c.flag_image = FlagMaker.render(code, 24, 16)
	c.flag_tex = ImageTexture.create_from_image(c.flag_image)
	var old: SpriteFrames = c.flag_frames
	var sf: = SpriteFrames.new()
	sf.add_animation(&"wave")
	sf.set_animation_speed(&"wave", 6.0)
	sf.set_animation_loop(&"wave", true)
	for t: ImageTexture in FlagMaker.frames(code, FlagMaker.WORLD_W, FlagMaker.WORLD_H, 1):
		sf.add_frame(&"wave", t)
	c.flag_frames = sf
	if not live or top == null or old == null:
		return
	for n: Node in top.flags_root.get_children():
		if n is AnimatedSprite2D and (n as AnimatedSprite2D).sprite_frames == old:
			(n as AnimatedSprite2D).sprite_frames = sf




func apply_identity(c: Country) -> void :
	if c == null or net_driven:
		return
	var nm: String = NameGen.clean_country(GameConfig.my_name)
	if NameGen.country_name_error(nm) == "":
		c.name = nm
	if not FlagMaker.decode(GameConfig.my_flag).is_empty():
		apply_flag(c, GameConfig.my_flag)


	if GameConfig.cb_active():
		c.money = GameConfig.my_money
		id_style = int(cb_lands()[0])
	else:
		id_style = land_pref()
	_restyle(c, id_style)




func _style_slot(id: int, is_player: bool) -> int:
	var s0: int = _style_slot0(id, is_player)

	var used: Dictionary = {}
	for o: Country in countries:
		if not o.eliminated:
			used[String(o.style.get("map", ""))] = true
	if not used.has(String((COUNTRY_STYLES[s0] as Dictionary).get("map", ""))):
		return s0
	for i in COUNTRY_STYLES.size():
		if not used.has(String((COUNTRY_STYLES[i] as Dictionary).get("map", ""))):
			return i
	return s0


func _style_slot0(id: int, is_player: bool) -> int:
	var n: int = COUNTRY_STYLES.size()
	if id_style < 0 or id_style >= n:
		return (id - 1) % n
	if is_player:
		return id_style
	var others: Array = []
	for i in n:
		if i != id_style:
			others.append(i)
	var j: int = (id - 1) - (1 if player != null and player.id < id else 0)
	return int(others[posmod(j, others.size())])


func _restyle(c: Country, slot: int) -> void :
	if slot < 0 or slot >= COUNTRY_STYLES.size():
		return
	c.style = COUNTRY_STYLES[slot]
	c.color = Color.html(String(c.style["map"])) if c.style.has("map") else Palette.c(String(c.style["base"]))
	c.color_light = Palette.c(String(c.style["light"])) if c.style.has("light") else c.color.lightened(0.35)
	c.color_dark = Palette.c(String(c.style["dark"])) if c.style.has("dark") else c.color.darkened(0.45)
	_update_territory_colors()





static func cb_lands() -> Array:
	var n: int = mini(GameConfig.cb_list.size(), COUNTRY_STYLES.size() - 1)
	var out: Array = []
	out.resize(n + 1)
	out.fill(-1)
	out[0] = GameConfig.my_land if GameConfig.my_land >= 0 and GameConfig.my_land < COUNTRY_STYLES.size() else land_for_flag(GameConfig.my_flag)
	var used: Dictionary = {out[0]: true}
	for i in n:
		var l: int = int((GameConfig.cb_list[i] as Dictionary).get("l", -1))
		if l >= 0 and l < COUNTRY_STYLES.size() and not used.has(l):
			used[l] = true
			out[i + 1] = l
	for j in n:
		if int(out[j + 1]) < 0:
			out[j + 1] = land_for_flag(String((GameConfig.cb_list[j] as Dictionary).get("f", "")), used)
			used[out[j + 1]] = true
	return out



static func land_pref() -> int:
	if GameConfig.my_land >= 0 and GameConfig.my_land < COUNTRY_STYLES.size():
		return GameConfig.my_land
	return land_for_flag(GameConfig.my_flag)




static func land_for_flag(code: String, skip: Dictionary = {}) -> int:
	var sp: Dictionary = FlagMaker.decode(code)
	if sp.is_empty():
		for i0 in COUNTRY_STYLES.size():
			if not skip.has(i0):
				return i0
		return 0
	var cs: Array = sp["c"]
	var main: Color = FlagMaker.col(int(cs[0]))
	if main.s < 0.18 and int(FlagMaker.L_NCOL[int(sp["l"])]) >= 2 and FlagMaker.col(int(cs[1])).s >= 0.18:
		main = FlagMaker.col(int(cs[1]))
	var best: int = 0
	var bd: float = INF
	for i in COUNTRY_STYLES.size():
		if skip.has(i):
			continue
		var m: Color = Color.html(String((COUNTRY_STYLES[i] as Dictionary).get("map", "ffffff")))
		var dh: float = absf(m.h - main.h)
		dh = minf(dh, 1.0 - dh)

		var d: float = (dh * 3.0 + absf(m.s - main.s) * 0.8 + absf(m.v - main.v) * 0.5) if main.s >= 0.18 and m.s >= 0.18\
		else Vector3(m.r - main.r, m.g - main.g, m.b - main.b).length() + (0.6 if m.s >= 0.18 and main.s < 0.18 else 0.0)
		if d < bd:
			bd = d
			best = i
	return best
