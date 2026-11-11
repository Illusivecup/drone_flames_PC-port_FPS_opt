class_name NetHash
extends RefCounted






static func of(gw: GameWorld) -> String:
	var nums: PackedFloat64Array = PackedFloat64Array()
	nums.append(gw.game_time)
	nums.append(float(gw.rng.state))
	nums.append(float(gw.net_tick))
	for c: Country in gw.countries:
		for v: int in [c.id, c.money, c.fuel, c.titanium, c.metal, c.wood, c.oil, c.precious, c.food, c.goods, c.city_ids.size(), 1 if c.eliminated else 0, 1 if c.is_player else 0, c.uranium]:
			nums.append(float(v))
	nums.append(float(gw.mil.facilities.size()))
	nums.append(float(gw.mil.drones.size()))
	nums.append(float(gw.mil.missiles.size()))
	nums.append(float(gw.army.units.size()))
	nums.append(float(gw.mil.air.aircraft.size()))
	nums.append(float(gw.navy.ships.size()) if gw.navy != null else 0.0)
	var sx: int = 0
	var sy: int = 0
	var hp: int = 0
	for f: Facility in gw.mil.facilities:
		hp = (hp * 31 + int(f.hp * 4.0)) & 2147483647
	for u: Unit in gw.army.units:
		sx = (sx * 31 + int(u.pos.x * 8.0)) & 2147483647
		sy = (sy * 31 + int(u.pos.y * 8.0)) & 2147483647
		hp = (hp * 31 + int(u.hp * 4.0)) & 2147483647
	for a: Aircraft in gw.mil.air.aircraft:
		sx = (sx * 31 + int(a.pos.x * 8.0)) & 2147483647
		sy = (sy * 31 + int(a.pos.y * 8.0)) & 2147483647
	nums.append(float(hp))
	for dr: Drone in gw.mil.drones:
		sx = (sx * 31 + int(dr.pos.x * 8.0)) & 2147483647
		sy = (sy * 31 + int(dr.pos.y * 8.0)) & 2147483647
	nums.append(float(sx))
	nums.append(float(sy))
	nums.append_array(diplo_nums(gw))
	var h: = HashingContext.new()
	h.start(HashingContext.HASH_MD5)
	h.update(nums.to_byte_array())
	h.update(gw.obj_state)
	h.update(gw.data.owners)
	return h.finish().hex_encode().substr(0, 16)




static func diplo_nums(gw: GameWorld) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var dp: Diplomacy = gw.diplo
	if dp != null:
		var ks: Array = dp.rel.keys()
		ks.sort()
		for k: Variant in ks:
			out.append(float(hash(k)))
			out.append(float(int(dp.rel[k])))
		var ok: Array = dp.opinion.keys()
		ok.sort()
		for k2: Variant in ok:
			out.append(float(roundi(float(dp.opinion[k2]))))
		for v: int in [dp.treaties.size(), dp.offers.size(), dp.t_offers.size(), dp.demands.size(), dp.calls.size(), dp.notes.size()]:
			out.append(float(v))
		if dp.has_method("sky_hash"):
			out.append_array(dp.sky_hash())
		if dp.has_method("req_hash"):
			out.append_array(dp.req_hash())
		if dp.has_method("rift_hash"):
			out.append_array(dp.rift_hash())
	if gw.econ != null and gw.econ.trd != null:
		out.append_array(gw.econ.trd.hash_nums())
	if gw.rail != null and gw.rail.has_method("hash_nums"):
		out.append_array(gw.rail.hash_nums())
	if gw.army != null and gw.army.fire != null:
		out.append(float(gw.army.fire.rng_state))
	if gw.recon != null:
		out.append(float(gw.recon.get("_rng").state))
	if gw.pstat != null:
		out.append_array(gw.pstat.hash_nums())
	if gw.get("drama") != null:
		out.append_array(gw.drama.hash_nums())
	for c: Country in gw.countries:
		out.append(float(c.army_groups.size()))
		for g: Dictionary in c.army_groups:
			out.append(float((g["fids"] as PackedInt32Array).size()))
	return out



static func parts(gw: GameWorld) -> Dictionary:
	var out: Dictionary = {}
	out["time"] = "%.4f/%d" % [gw.game_time, gw.net_tick]
	out["rng"] = str(gw.rng.state)
	var cs: PackedFloat64Array = PackedFloat64Array()
	for c: Country in gw.countries:
		for v: int in [c.money, c.fuel, c.titanium, c.metal, c.wood, c.oil, c.precious, c.food, c.goods, c.city_ids.size(), c.uranium]:
			cs.append(float(v))
	out["countries"] = _h(cs.to_byte_array())
	out["diplo"] = _h(diplo_nums(gw).to_byte_array())

	var cl: Array = []
	for c: Country in gw.countries:
		cl.append([c.id, c.money, c.fuel, c.titanium, c.metal, c.wood, c.oil, c.precious, c.food, c.goods, c.city_ids.size(), c.uranium])
	out["clist"] = cl
	var dd: Dictionary = {}
	var dp: Diplomacy = gw.diplo
	if dp != null:
		for k: Variant in dp.rel:
			dd["rel " + str(k)] = int(dp.rel[k])
		for k2: Variant in dp.opinion:
			dd["opinion " + str(k2)] = roundi(float(dp.opinion[k2]))
		dd["n treaties"] = dp.treaties.size()
		dd["n offers"] = dp.offers.size()
		dd["n t_offers"] = dp.t_offers.size()
		dd["n demands"] = dp.demands.size()
		dd["n calls"] = dp.calls.size()
		dd["n notes"] = dp.notes.size()
	if gw.recon != null:
		dd["recon rng"] = str(gw.recon.get("_rng").state)
	for c2: Country in gw.countries:
		dd["groups %d" % c2.id] = c2.army_groups.size()
	out["dlist"] = dd

	var es: Dictionary = {}
	if gw.econ != null:
		for cid: Variant in gw.econ._stats:
			var tot: Dictionary = (gw.econ._stats[cid] as Dictionary).get("total", {})
			for kind: String in tot:
				if kind == "income" or kind == "spend" or kind.begins_with("money"):
					for key: String in tot[kind]:
						es["%s %s:%s" % [str(cid), kind, key]] = int(tot[kind][key])
	out["estats"] = es
	out["rng_log"] = gw.rng.draws.duplicate() if gw.rng != null else []
	out["money_log"] = Country.mlog.slice(maxi(0, Country.mlog.size() - 40))

	var kinds: Dictionary = {}
	var blocks: Dictionary = {}
	for oi in gw.obj_state.size():
		if gw.obj_state[oi] != 2:
			var kk: int = int(gw.obj_kind[oi]) if oi < gw.obj_kind.size() else -1
			kinds[str(kk)] = int(kinds.get(str(kk), 0)) + 1
		var bk: String = str(oi / 1024)
		blocks[bk] = (int(blocks.get(bk, 17)) * 31 + int(gw.obj_state[oi]) * 7 + (int(gw.obj_spr[oi]) if oi < gw.obj_spr.size() else 0)) & 2147483647
	out["okinds"] = kinds
	out["oblocks"] = blocks
	out["fire_rng"] = str(gw.army.fire.rng_state) if gw.army != null and gw.army.fire != null else "0"

	var ul: Array = []
	for u: Unit in gw.army.units:
		if ul.size() >= 100:
			break
		ul.append([u.id, roundi(u.pos.x * 16.0), roundi(u.pos.y * 16.0), roundi(u.hp * 16.0), int(u.state), int(u.target.get("id")) if u.target != null and is_instance_valid(u.target) else -1, u.path.size()])
	out["ulist"] = ul
	if NetConfig.trace:
		var hp: PackedFloat64Array = PackedFloat64Array()
		for f: Facility in gw.mil.facilities:
			hp.append(float(f.id))
			hp.append(float(roundi(f.hp * 4.0)))
		out["fac_hp"] = _h(hp.to_byte_array())
		var up: PackedFloat64Array = PackedFloat64Array()
		for u: Unit in gw.army.units:
			up.append(float(u.id))
			up.append(float(roundi(u.pos.x * 8.0)))
			up.append(float(roundi(u.pos.y * 8.0)))
			up.append(float(roundi(u.hp * 4.0)))
		out["units"] = _h(up.to_byte_array())
	if NetConfig.trace:
		var money: Array = []
		for c: Country in gw.countries:
			money.append([c.money, c.metal, c.food, c.goods, c.oil, c.fuel])
		out["money"] = money
		var ruin: PackedInt32Array = PackedInt32Array()
		for i in gw.obj_state.size():
			if gw.obj_state[i] == 1:
				ruin.append(i)
		out["ruins"] = ruin
		out["fires"] = gw.fires.size()
	out["owners"] = _h(gw.data.owners)
	out["obj_state"] = _h(gw.obj_state)
	out["objects"] = gw.obj_spr.size() - gw._free_ids.size()
	var fs: PackedFloat64Array = PackedFloat64Array()
	for f: Facility in gw.mil.facilities:
		fs.append_array([float(f.id), float(f.kind), float(f.country_id), f.hp, float(f.cell.x), float(f.cell.y)])
	out["facilities"] = "%d:%s" % [gw.mil.facilities.size(), _h(fs.to_byte_array())]
	var us: PackedFloat64Array = PackedFloat64Array()
	for u: Unit in gw.army.units:
		us.append_array([float(u.id), u.pos.x, u.pos.y, u.hp, float(u.state)])
	out["units"] = "%d:%s" % [gw.army.units.size(), _h(us.to_byte_array())]
	var ds: PackedFloat64Array = PackedFloat64Array()
	for d: Drone in gw.mil.drones:
		ds.append_array([float(d.id), d.pos.x, d.pos.y, float(d.state)])
	out["drones"] = "%d:%s" % [gw.mil.drones.size(), _h(ds.to_byte_array())]
	var ms: PackedFloat64Array = PackedFloat64Array()
	for mi: Missile in gw.mil.missiles:
		ms.append_array([float(mi.id), float(mi.state)])
	out["missiles"] = "%d:%s" % [gw.mil.missiles.size(), _h(ms.to_byte_array())]
	var ac: PackedFloat64Array = PackedFloat64Array()
	for a2: Aircraft in gw.mil.air.aircraft:
		ac.append_array([float(a2.id), a2.pos.x, a2.pos.y, float(a2.state)])
	out["aircraft"] = "%d:%s" % [gw.mil.air.aircraft.size(), _h(ac.to_byte_array())]
	if gw.navy != null:
		var sh: PackedFloat64Array = PackedFloat64Array()
		for s2: Ship in gw.navy.ships:
			sh.append_array([float(s2.id), s2.pos.x, s2.pos.y, s2.hp])
		out["ships"] = _h(sh.to_byte_array())
	return out


static func _h(b: PackedByteArray) -> String:
	if b.is_empty():
		return "-"
	var h: = HashingContext.new()
	h.start(HashingContext.HASH_MD5)
	h.update(b)
	return h.finish().hex_encode().substr(0, 8)
