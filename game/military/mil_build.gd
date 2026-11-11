extends "res://game/military/mil_base.gd"


static func cost_of(kind: int) -> int:
	return int(COSTS[kind])


static func size_of(kind: int) -> Vector2i:
	if kind == Facility.Kind.NAVAL_BASE:
		return Navy.base_size()
	return SIZES[kind]


static func title_of(kind: int) -> String:
	return Loc.t(String(TITLES[kind]))


static func gender_of(kind: int) -> int:
	var n: Variant = Facility.Kind.find_key(kind)
	return int(GENDER_NAMES.get(n, 0)) if n != null else 0





static func pp(kind: int, stem: String) -> String:
	return Loc.t(stem + String(PP_END[gender_of(kind)]))



const LOC_PP: Array = ["разрушен", "разрушена", "разрушено", "разрушены", "поврежден", "повреждена", "повреждено", "повреждены", 
	"цел", "цела", "цело", "целы", "поражен", "поражена", "поражено", "поражены", "захвачен", "захвачена", "захвачено", "захвачены"]



static func is_field_work(kind: int) -> bool:
	return kind == Facility.Kind.TRENCH_H or kind == Facility.Kind.TRENCH_V or kind == Facility.Kind.TEETH_H or kind == Facility.Kind.TEETH_V


static func is_teeth(kind: int) -> bool:
	return kind == Facility.Kind.TEETH_H or kind == Facility.Kind.TEETH_V


static func is_module(kind: int) -> bool:
	return kind == Facility.Kind.DP_RAMP or kind == Facility.Kind.DP_RUNWAY or kind == Facility.Kind.DP_STORE or kind == Facility.Kind.SOLAR



static func uses_power(kind: int) -> bool:
	return kind == Facility.Kind.DRONE_FACTORY or kind == Facility.Kind.MISSILE_FACTORY or kind == Facility.Kind.DRONE_PORT or kind == Facility.Kind.REFINERY\
	or kind == Facility.Kind.CIV_FACTORY or kind == Facility.Kind.MINE or kind == Facility.Kind.AD_RADAR or kind == Facility.Kind.AD_EW\
	or kind == Facility.Kind.URANIUM_MINE



static func nw_for(kind: int, center: Vector2i) -> Vector2i:
	return center - size_of(kind) / 2


func _info(sprite: String) -> Dictionary:
	for at: SpriteAtlas in [gw.atlas3, gw.atlas4, gw.atlas2, gw.atlas6, gw.atlas7, gw.atlas8, gw.atlas9, gw.atlas10, gw.atlas11, gw.atlas12]:
		if at.has(sprite):
			return at.info(sprite)
	if gw.atlas_uran30 != null and gw.atlas_uran30.has(sprite):
		return gw.atlas_uran30.info(sprite)
	return gw.atlas.info(sprite)



func local_px(id: int, p: Array) -> Vector2:
	return gw.obj_origin(id) + Vector2(float(p[0]), float(p[1]))





func check_place(kind: int, nw: Vector2i, country: Country, parent: Facility = null, pay: bool = true, roam: bool = false, detour_dry: bool = true) -> String:
	var sz: Vector2i = size_of(kind)
	if kind == Facility.Kind.MINE and gw.get("econ") != null:
		var mid: Vector2i = nw + sz / 2
		if not gw.econ.deposit_near(mid, 3, ["uranium"]).is_empty():
			kind = Facility.Kind.URANIUM_MINE
			sz = size_of(kind)
	var d: WorldData = gw.data
	if gw.diplo != null and gw.diplo.get("sky") != null:
		var skw: String = gw.diplo.sky.place_why(kind, nw, sz, country)
		if skw != "":
			return skw
	if parent != null and kind != Facility.Kind.PORT_CRANE:
		var pc: Vector2i = parent.cell + parent.size / 2
		var mc: Vector2i = nw + sz / 2
		if maxi(absi(pc.x - mc.x), absi(pc.y - mc.y)) > MODULE_R:
			return Loc.t("Слишком далеко от дронопорта (до %d м)") % (MODULE_R * GameWorld.CELL)
	var wet: int = 0
	var wet_land: int = 0
	var neutral: int = 0
	var dry: int = 0



	var nb: bool = kind == Facility.Kind.NAVAL_BASE
	var rows: Array = Navy.mask_rows() if nb else []
	var dw: int = d.w
	var bio: PackedByteArray = d.biome
	var fl: PackedByteArray = d.flags
	var owr: PackedByteArray = d.owners
	var has_rm: bool = gw.rail != null
	var rm: PackedByteArray = gw.rail.mask if has_rm else PackedByteArray()
	var busy: int = WorldData.F_OCCUPIED | WorldData.F_BRIDGE | (0 if is_field_work(kind) else WorldData.F_ROAD)
	var dk: bool = detours(kind)
	var n_road: int = 0
	var n_rail: int = 0
	for y in range(nw.y, nw.y + sz.y):
		for x in range(nw.x, nw.x + sz.x):
			if not d.inside(x, y):
				return Loc.t("Не помещается у края карты")
			var i: int = y * dw + x
			if nb:


				var mk: int = 0
				if y - nw.y < rows.size():
					var mr: Array = rows[y - nw.y]
					if x - nw.x < mr.size():
						mk = int(mr[x - nw.x])
				var bb: int = bio[i]
				if (fl[i] & WorldData.F_BRIDGE) != 0:
					return Loc.t("Здесь мост")
				if bb <= Biome.RIVER:
					if (fl[i] & WorldData.F_OCCUPIED) != 0:
						return Loc.t("Место занято: здесь уже база")
					if mk == 1 and bb != Biome.SHALLOW and bb != Biome.COAST:
						wet_land += 1
					elif mk != 1:
						wet += 1
					continue
				if mk == 2 and bb == Biome.SAND:
					wet += 1
				if has_rm and i < rm.size() and rm[i] != 0:
					return Loc.t("Здесь железная дорога")
				var ow: int = owr[i]
				if ow != country.id:
					if ow != 0:
						return Loc.t("Стройте только на своей территории")
					neutral += 1
				dry += 1
				if (fl[i] & WorldData.F_OCCUPIED) != 0:
					return Loc.t("Место занято: дома")
				continue
			if has_rm and i < rm.size() and rm[i] != 0:
				if not dk:
					return Loc.t("Здесь железная дорога")
				n_rail += 1
			var o2: int = owr[i]
			if o2 != country.id and not roam and not ally_site(kind, o2, country):
				return Loc.t("Стройте только на своей территории") + (Loc.t(" или у союзника (ПВО, казармы, окопы)") if country.is_player else "")
			if bio[i] <= Biome.RIVER:
				return Loc.t("Нельзя строить на воде")
			if not dk and (bio[i] == Biome.ROCK or bio[i] == Biome.SNOW):
				return Loc.t("Нельзя на скалах")
			if (fl[i] & busy) != 0:
				if not dk or (fl[i] & (WorldData.F_OCCUPIED | WorldData.F_BRIDGE)) != 0:
					return Loc.t("Место занято: дома или дороги")
				n_road += 1
	if kind == Facility.Kind.NAVAL_BASE:
		if float(neutral) > float(dry) * 0.4:
			return Loc.t("Стройте только на своей территории")
		var why_w: String = Navy.wet_why(wet, wet_land, sz)
		if why_w != "":
			return why_w
	if kind == Facility.Kind.DUGOUT and enemy_near(country, Vector2(nw * GameWorld.CELL) + Vector2(sz * GameWorld.CELL) * 0.5):
		return Loc.t("Слишком близко к противнику")
	if not roam and gw.econ.upk != null:
		var occ_why: String = gw.econ.upk.occupied_why(kind, nw, sz, country)
		if occ_why != "":
			return occ_why
	var eco_why: String = gw.econ.check_site(kind, nw, sz, country, parent)
	if eco_why != "":
		return eco_why
	if n_road + n_rail > 0 and detour_dry:
		var dtw: String = detour_why(nw, sz, n_road > 0, n_rail > 0)
		if dtw != "":
			return dtw
	if pay and country.money < price_of(kind, country):
		return Loc.t("Не хватает денег: нужно %d") % price_of(kind, country)
	if pay and not country.has_res(Economy.res_cost("build_%d" % kind)):
		return Loc.t("Не хватает: %s") % country.missing_res(Economy.res_cost("build_%d" % kind))
	return ""




static func detours(kind: int) -> bool:
	return kind == Facility.Kind.MINE or kind == Facility.Kind.OIL_RIG or kind == Facility.Kind.URANIUM_MINE




func detour_why(nw: Vector2i, sz: Vector2i, road: bool, rail: bool) -> String:
	var r: = Rect2i(nw, sz)
	if rail and gw.rail != null and not gw.rail.reroute_around(r, false):
		return Loc.t("Здесь железная дорога: объезд не проложить (мост, вокзал, вода или постройки рядом)")
	if road:
		var rc: int = RoadDetour.plan(gw, r, false)
		if rc == -1 or rc == -3:
			return Loc.t("Здесь улица или мост: дорогу не обвести")
		if rc == -2:
			return Loc.t("Здесь въезд в город: дорогу не обвести")
		if rc < 0:
			return Loc.t("Дорогу не обвести: вода или постройки рядом")
	return ""




func _detour_apply(nw: Vector2i, sz: Vector2i) -> String:
	var r: = Rect2i(nw, sz)
	var road: bool = false
	var rail: bool = false
	var d: WorldData = gw.data
	for y in range(nw.y, nw.y + sz.y):
		for x in range(nw.x, nw.x + sz.x):
			if not d.inside(x, y):
				continue
			if d.has_flag(x, y, WorldData.F_ROAD):
				road = true
			if gw.rail != null and gw.rail.has_rail(Vector2i(x, y)):
				rail = true
	if road:
		var rw: String = detour_why(nw, sz, true, false)
		if rw != "":
			return rw
	if rail and not gw.rail.reroute_around(r, true):
		return detour_why(nw, sz, false, true)
	if road and RoadDetour.plan(gw, r, true) < 0:
		return Loc.t("Дорогу не обвести: вода или постройки рядом")
	return ""



func detour_note(kind: int, nw: Vector2i) -> String:
	if not detours(kind):
		return ""
	var sz: Vector2i = size_of(kind)
	var d: WorldData = gw.data
	var road: bool = false
	var rail: bool = false
	for y in range(nw.y, nw.y + sz.y):
		for x in range(nw.x, nw.x + sz.x):
			if not d.inside(x, y):
				continue
			if d.has_flag(x, y, WorldData.F_ROAD):
				road = true
			if gw.rail != null and gw.rail.has_rail(Vector2i(x, y)):
				rail = true
	var what: String = Loc.t("нефтевышку") if kind == Facility.Kind.OIL_RIG else (Loc.t("шахту") if kind == Facility.Kind.URANIUM_MINE else Loc.t("рудник"))
	if road and rail:
		return Loc.t("Дорога и Ж/Д обойдут %s") % what
	if road:
		return Loc.t("Дорога обойдёт %s") % what
	if rail:
		return Loc.t("Ж/Д обойдёт %s") % what
	return ""





func place_why(kind: int, center: Vector2i, country: Country, parent: Facility = null, pay: bool = true) -> String:
	if kind == Facility.Kind.MINE and gw.get("econ") != null:
		if not gw.econ.deposit_near(center, 3, ["uranium"]).is_empty():
			kind = Facility.Kind.URANIUM_MINE
	if kind == Facility.Kind.NAVAL_BASE and gw.get("navy") != null:
		center = gw.navy.resolve_site(center, country)
	return check_place(kind, nw_for(kind, center), country, parent, pay)


func build(kind: int, center: Vector2i, country: Country, parent: Facility = null, free: bool = false) -> Facility:
	if kind == Facility.Kind.MINE and gw.get("econ") != null:
		if not gw.econ.deposit_near(center, 3, ["uranium"]).is_empty():
			kind = Facility.Kind.URANIUM_MINE
	if kind == Facility.Kind.NAVAL_BASE and gw.get("navy") != null:



		center = gw.navy.resolve_site(center, country)
	var nw: Vector2i = nw_for(kind, center)
	var why: String = check_place(kind, nw, country, parent, not free, false, false)
	if why == "" and detours(kind):
		why = _detour_apply(nw, size_of(kind))
	if why != "":
		if not free:
			gw.message.emit(why)
		return null
	if not free:
		pay_series(country, kind)
		gw.econ.pay_build(country, kind)
	var f: = Facility.new()
	f.id = facilities.size()
	f.kind = kind
	f.country_id = country.id
	f.cell = nw
	f.size = size_of(kind)
	f.parent = parent
	if gw.diplo != null and gw.diplo.has_method("note_ally_fac"):
		gw.diplo.note_ally_fac(f)
	if gw.diplo != null and gw.diplo.get("sky") != null:
		gw.diplo.sky.note_fac(f)
	var d: WorldData = gw.data
	for y in range(nw.y, nw.y + f.size.y):
		for x in range(nw.x, nw.x + f.size.x):
			gw.remove_tree_at(Vector2i(x, y))
			d.add_flag(x, y, WorldData.F_OCCUPIED)
			if kind == Facility.Kind.NAVAL_BASE:
				d.clear_flag(x, y, WorldData.F_ROAD)
				if Biome.is_water(d.get_biome(x, y)):
					continue
			if kind == Facility.Kind.DRONE_FACTORY or kind == Facility.Kind.MISSILE_FACTORY or kind == Facility.Kind.REFINERY or kind == Facility.Kind.POWER_PLANT or kind == Facility.Kind.CIV_FACTORY or kind == Facility.Kind.MINE\
			or kind == Facility.Kind.NUCLEAR_PLANT or kind == Facility.Kind.URANIUM_MINE:
				d.set_biome(x, y, Biome.INDUSTRIAL)
			elif kind == Facility.Kind.FARM:
				d.set_biome(x, y, Biome.FIELD)
			elif Defense.is_ad(kind) or kind == Facility.Kind.AD_RADAR or kind == Facility.Kind.AD_EW or is_field_work(kind):
				pass
			elif kind == Facility.Kind.AIRFIELD:
				var lx: int = x - nw.x
				d.set_biome(x, y, Biome.ROAD if y - nw.y == 4 and lx >= 2 and lx <= 27 else Biome.PLAZA)
			elif kind != Facility.Kind.TEL and kind != Facility.Kind.COASTAL_ASM:
				d.set_biome(x, y, Biome.PLAZA)
	if kind == Facility.Kind.TEL:

		for y in range(nw.y - 4, nw.y + f.size.y + 1):
			for x in range(nw.x - 1, nw.x + f.size.x + 1):
				if d.inside(x, y):
					gw.remove_tree_at(Vector2i(x, y))
	if kind == Facility.Kind.AIRFIELD:

		f.obj_ids.append(gw.add_object("airfield_runway", nw, GameWorld.KIND_PROP))
		f.obj_ids.append(gw.add_object("airfield_hangar", nw + Vector2i(1, 7), GameWorld.KIND_BUILDING))
		f.obj_ids.append(gw.add_object("airfield_hangar", nw + Vector2i(7, 7), GameWorld.KIND_BUILDING))
		f.main_obj = gw.add_object("airfield_tower", nw + Vector2i(27, 8), GameWorld.KIND_BUILDING)
		f.obj_ids.append(f.main_obj)
	elif kind == Facility.Kind.NAVAL_BASE and gw.spr_index.has(Navy.variant_sprite(Navy.cur)):
		f.variant = Navy.cur
		f.main_obj = gw.add_object(Navy.variant_sprite(Navy.cur), nw, GameWorld.KIND_BUILDING)
		f.obj_ids.append(f.main_obj)
	elif kind == Facility.Kind.NAVAL_BASE and not gw.spr_index.has("navbase"):

		for pl: Array in [["port", Vector2i(0, 0)], ["port", Vector2i(8, 0)], ["port_crane", Vector2i(1, 6)], ["port_crane", Vector2i(10, 6)]]:
			var pid: int = gw.add_object(String(pl[0]), nw + (pl[1] as Vector2i), GameWorld.KIND_BUILDING)
			if pid >= 0:
				f.obj_ids.append(pid)
				if f.main_obj < 0:
					f.main_obj = pid
	elif kind == Facility.Kind.NUCLEAR_PLANT:
		Nuclear.build_parts(gw, f, nw, country)
	elif kind == Facility.Kind.COASTAL_ASM and not gw.spr_index.has("coastal_asm"):
		f.main_obj = gw.add_object("ad_sam", nw, GameWorld.KIND_BUILDING)
		f.obj_ids.append(f.main_obj)
	else:
		var okind: int = GameWorld.KIND_PROP if kind == Facility.Kind.DP_RUNWAY else GameWorld.KIND_BUILDING
		f.main_obj = gw.add_object(String(SPRITES[kind]), nw, okind)
		f.obj_ids.append(f.main_obj)
	match kind:
		Facility.Kind.DRONE_PORT:
			for p: Array in _info("dp_base")["spots"]:
				_add_spot(f, local_px(f.main_obj, p), f)
		Facility.Kind.DP_STORE:
			for p: Array in _info("dp_store")["spots"]:
				_add_spot(parent, local_px(f.main_obj, p), f)
		Facility.Kind.TEL:
			f.missiles = 2
			gw.set_obj_frame(f.main_obj, "tel2", 0)
		Facility.Kind.AD_SAM:
			gw.set_obj_frame(f.main_obj, "ad_sam", 0)
		Facility.Kind.AD_RADAR:
			gw.set_obj_frame(f.main_obj, "ad_radar", 0)
		Facility.Kind.MINE, Facility.Kind.OIL_RIG, Facility.Kind.SAWMILL, Facility.Kind.PORT, Facility.Kind.PORT_CRANE, Facility.Kind.URANIUM_MINE:
			gw.econ.bind_site(f)
		Facility.Kind.BARRACKS:
			f.prod_type = 0
		Facility.Kind.NAVAL_BASE:
			if gw.get("navy") != null:
				gw.navy.on_base_built(f)
		Facility.Kind.SOLAR_FARM:

			for off: Vector2i in [Vector2i(3, 0), Vector2i(0, 3), Vector2i(3, 3)]:
				var sid: int = gw.add_object("solar", nw + off, GameWorld.KIND_BUILDING)
				if sid >= 0:
					f.obj_ids.append(sid)
		Facility.Kind.DUGOUT:
			if not free:
				f.build_t = DUGOUT_T
	if parent != null:
		parent.modules.append(f)
	facilities.append(f)
	if CRIT_RESTORE.has(kind) and parent == null and not _no_construct:


		f.restore_t = float(CRIT_RESTORE[kind])
		f.was_alive = false
		constructing[f.id] = true
	else:
		_ambient_fx(f)
	if not free:
		gw.fx.spawn("dust_s", f.center_px(), 6)
		gw.camera_shake_small()
		Sfx.play("ui_build", f.center_px())
	gw.changed.emit()
	return f



func auto_place(kind: int, near: Vector2i, country: Country, r0: int = 16, r1: int = 70) -> Facility:
	if is_field_work(kind):
		return _auto_line(Facility.Kind.TEETH_H if is_teeth(kind) else Facility.Kind.TRENCH_H, near, country, r0, r1)
	for r in range(r0, r1, 2):
		for a in range(0, 360, 15):
			var p: Vector2i = near + Vector2i(roundi(cos(deg_to_rad(a)) * r), roundi(sin(deg_to_rad(a)) * r))
			if check_place(kind, nw_for(kind, p), country, null, false) == "":
				return build(kind, p, country, null, true)
	return null



func _auto_line(kind: int, near: Vector2i, country: Country, r0: int, r1: int) -> Facility:
	for r in range(r0, r1, 2):
		for a in range(0, 360, 15):
			var dir: = Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a)))
			var p: Vector2i = near + Vector2i(roundi(dir.x * r), roundi(dir.y * r))
			var cells: Array[Vector2i] = []
			for k in range(-6, 6):
				var c: Vector2i = p + Vector2i(roundi( - dir.y * k), roundi(dir.x * k))
				if line_cell_ok(c, country) and not cells.has(c):
					cells.append(c)
			if cells.size() >= 10:
				return build_line(kind, cells, country, true)
	return null



func capital_plant(c: Country, cap: City) -> void :
	gw.econ.on_capital(c, cap)
	_no_construct = true
	if auto_place(Facility.Kind.POWER_PLANT, cap.center, c, cap.radius + 6, cap.radius + 40) == null:
		_pending_plants.append([c, cap])
	_no_construct = false



func _ambient_fx(f: Facility) -> void :
	var forever: float = gw.game_time + 1000000000.0
	if f.kind == Facility.Kind.POWER_PLANT:
		var info: Dictionary = _info("power_plant")
		for p: Array in info["steam"]:
			f.fx.append(gw.fx.handle(gw.fx.spawn("smoke_loop", local_px(f.main_obj, p), 5, forever, true)))
		for p: Array in info["smoke"]:
			f.fx.append(gw.fx.handle(gw.fx.spawn("smoke_loop", local_px(f.main_obj, p), 5, forever, true)))
	elif f.kind == Facility.Kind.NUCLEAR_PLANT:
		Nuclear.ambient(gw, f)
	elif f.kind == Facility.Kind.REFINERY:
		var ri: Dictionary = _info("refinery")
		f.fx.append(gw.fx.handle(gw.fx.spawn("fire_small", local_px(f.main_obj, [ri["flare_x"], ri["flare_y"]]) + Vector2(0, 3), 6, forever, true)))


func _stop_fx(f: Facility) -> void :
	for h: Array in f.fx:
		gw.fx.stop_h(h)
	f.fx.clear()


func _add_spot(port: Facility, p: Vector2, owner: Facility) -> void :
	port.spots.append(p.round())
	port.spot_owner.append(owner)
	port.parked.append(null)




func alive(f: Facility) -> bool:
	if f == null or f.restore_t > 0.0:
		return false
	if f.kind == Facility.Kind.NUCLEAR_PLANT and f.main_obj >= 0:
		return gw.obj_state[f.main_obj] == 0
	if f.is_line():
		return not f.cells.is_empty()
	var any_b: bool = false
	for id in f.obj_ids:
		if gw.obj_kind[id] == GameWorld.KIND_BUILDING:
			any_b = true
			if gw.obj_state[id] == 0:
				return true
	if not any_b:
		return f.parent == null or alive(f.parent)
	return false


func has_kind(country_id: int, kind: int) -> bool:
	for f: Facility in facilities:
		if f.country_id == country_id and f.kind == kind and alive(f):
			return true
	return false


func facility_at(cell: Vector2i) -> Facility:

	var near_line: Facility = null
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q: = cell + Vector2i(dx, dy)
			if fort_cells.has(q):
				var lf: Facility = fort_cells[q]
				if dx == 0 and dy == 0:
					return lf
				near_line = lf

	for pass_i in 2:
		for f: Facility in facilities:
			if (pass_i == 0) != is_module(f.kind):
				continue
			if f.moving:
				if Vector2(cell * GameWorld.CELL).distance_to(f.mpos + Vector2(0, -6)) < 14.0:
					return f
				continue
			if f.is_line():
				continue
			if Rect2i(f.cell, f.size).grow(1).has_point(cell):
				return f

	if gw.econ != null and gw.econ.get("ports") != null:
		for f: Facility in facilities:
			if f.kind != Facility.Kind.PORT:
				continue
			for sg: Dictionary in gw.econ.ports.segments(f):
				var oid: int = int(sg.get("obj", -1))
				if oid >= 0 and gw.object_rect(oid).grow(1).has_point(cell):
					return f
	return near_line


func port_level(port: Facility) -> int:
	var n: int = 1
	for m: Facility in port.modules:
		if alive(m):
			n += 1
	return n


func port_launchers(port: Facility, working_only: bool = true) -> Array[Facility]:
	var out: Array[Facility] = []
	for m: Facility in port.modules:
		if m.is_launcher() and ( not working_only or alive(m)):
			out.append(m)
	return out






func _crit_hit(p: Vector2, r_px: float) -> void :
	for f: Facility in facilities:
		if f.parent != null or not CRIT_RESTORE.has(f.kind):
			continue
		var r: = Rect2(f.origin_px(), Vector2(f.size * GameWorld.CELL)).grow(r_px)
		if not r.has_point(p):
			continue
		site_hit_t[f.id] = gw.game_time
		if f.restore_t > 0.0 and constructing.has(f.id):
			f.restore_t = float(CRIT_RESTORE[f.kind])
			if gw.country_by_id(f.country_id).is_player:
				gw.say(gw.country_by_id(f.country_id), Loc.mk("%s: стройка сорвана ударом", [title_of(f.kind)]))
		elif f.restore_t > 0.0:
			ruin_hits[f.id] = int(ruin_hits.get(f.id, 0)) + 1
			f.restore_t = 0.0
			if gw.country_by_id(f.country_id).is_player:
				gw.say(gw.country_by_id(f.country_id), Loc.mk("%s: восстановление сорвано ударом", [title_of(f.kind)]))
		elif not alive(f) and f.ruined_at >= 0.0 and gw.game_time - f.ruined_at > 1.0:
			ruin_hits[f.id] = int(ruin_hits.get(f.id, 0)) + 1


func can_restore(f: Facility) -> bool:
	if f.kind == Facility.Kind.NUCLEAR_PLANT and f.restore_t <= 0.0 and f.u_hits > 0:
		return true
	if f.restore_t > 0.0 or (alive(f) and f.kind != Facility.Kind.NUCLEAR_PLANT):
		return false
	for id in f.obj_ids:
		if gw.obj_kind[id] == GameWorld.KIND_BUILDING and gw.obj_state[id] == 1:
			return true
	return false








const HEAL_DT: float = 20.0


func heal_partial(now: bool = false) -> int:
	var n: int = 0
	for f: Facility in facilities:
		if f.restore_t > 0.0 or f.is_line() or f.kind == Facility.Kind.NUCLEAR_PLANT:
			continue
		if not now and fire_block_left(f) > 0.0:
			continue
		var bad: bool = false
		for id in f.obj_ids:
			if id >= 0 and id < gw.obj_state.size() and gw.obj_kind[id] == GameWorld.KIND_BUILDING and gw.obj_state[id] == 1:
				bad = true
				break
		if not bad or not alive(f):
			continue
		for id2 in f.obj_ids:
			if id2 >= 0 and id2 < gw.obj_state.size() and gw.obj_kind[id2] == GameWorld.KIND_BUILDING and gw.obj_state[id2] == 1:
				gw.obj_state[id2] = 0
				gw._mark_obj_chunk(id2)
				n += 1
	return n



func ruined_own(country_id: int) -> Array:
	var n: int = 0
	var cost: int = 0
	for f: Facility in facilities:
		if f.country_id == country_id and _repair_all_ok(f) and can_restore(f) and not (f.kind == Facility.Kind.NUCLEAR_PLANT and alive(f)):
			n += 1
			cost += restore_cost(f)
	return [n, cost]





func _repair_all_ok(f: Facility) -> bool:
	return f.parent == null or alive(f.parent) or can_restore(f.parent) or f.parent.restore_t > 0.0




func restore_all(country: Country) -> Array:
	var list: Array[Facility] = []
	for f: Facility in facilities:
		if f.country_id == country.id and _repair_all_ok(f) and can_restore(f) and not (f.kind == Facility.Kind.NUCLEAR_PLANT and alive(f)):
			list.append(f)
	var key: = func(f: Facility) -> int:
		return 0 if f.kind == Facility.Kind.POWER_PLANT or f.kind == Facility.Kind.NUCLEAR_PLANT else (1 if f.kind == Facility.Kind.REFINERY or f.kind == Facility.Kind.CIV_FACTORY else 2)
	list.sort_custom( func(a: Facility, b: Facility) -> bool:
		var ka: int = key.call(a)
		var kb: int = key.call(b)
		return ka < kb if ka != kb else restore_cost(a) < restore_cost(b))
	var done: int = 0
	var spent: int = 0



	var fire_n: int = 0
	var fire_s: float = 0.0
	var cash_n: int = 0
	var cash_need: int = 0
	for f: Facility in list:
		if f.country_id != country.id:
			continue
		var why: String = restore_why(f, country)
		if why != "":
			if fire_block_left(f) > 0.0:
				fire_n += 1
				fire_s = maxf(fire_s, fire_block_left(f))
			else:
				cash_n += 1
				cash_need += restore_cost(f) + restore_buy(f, country)
			continue
		var m0: int = country.money
		if restore(f, country, true):
			done += 1
			spent += m0 - country.money
	var parts: Array = []
	if fire_n > 0:
		parts.append(Loc.t("под огнём %d (ещё %d с)") % [fire_n, ceili(fire_s)])
	if cash_n > 0:
		parts.append(Loc.t("не хватает денег на %d: нужно ещё %d") % [cash_n, maxi(0, cash_need - country.money)])
	return [done, spent, list.size() - done, ", ".join(parts)]



func restore_buy(f: Facility, country: Country) -> int:
	var mt: int = restore_metal(f)
	return _metal_price(mt - country.metal) if mt > 0 and country.metal < mt else 0


static func restore_cost(f: Facility) -> int:
	return int(cost_of(f.kind) * RESTORE_SHARE)



func restore_time(f: Facility) -> float:
	if not CRIT_RESTORE.has(f.kind):
		return RESTORE_TIME
	if f.kind == Facility.Kind.NUCLEAR_PLANT and alive(f):
		return 90.0
	return float(CRIT_RESTORE[f.kind]) + minf(RUBBLE_MAX, float(int(ruin_hits.get(f.id, 0))) * RUBBLE_ADD)



static func restore_metal(f: Facility) -> int:
	return int(CRIT_METAL.get(f.kind, 0))



func fire_block_left(f: Facility) -> float:
	if not CRIT_RESTORE.has(f.kind):
		return 0.0
	return maxf(0.0, float(site_hit_t.get(f.id, -1000000000.0)) + FIRE_BLOCK - gw.game_time)



func restore_why(f: Facility, country: Country) -> String:
	if gw.econ != null and gw.econ.upk != null:
		var ow: String = gw.econ.upk.occupied_why(f.kind, f.cell, f.size, country)
		if ow != "":
			return ow
	var wait: float = fire_block_left(f)
	if wait > 0.0:
		return Loc.t("Ремонт под огнём: ещё %d с") % ceili(wait)

	var cost: int = restore_cost(f)
	var buy: int = restore_buy(f, country)
	if country.money < cost + buy:
		if buy > 0:
			return Loc.t("Не хватает денег: нужно %d (ремонт %d + металл %d), есть %d") % [cost + buy, cost, buy, country.money]
		return Loc.t("Не хватает денег: нужно %d, есть %d") % [cost, country.money]
	return ""


func _metal_price(n: int) -> int:
	return int(float(n) * float(gw.econ.market_price("metal") if gw.econ != null else 16) * 1.5)


func restore(f: Facility, country: Country, quiet: bool = false) -> bool:
	if not can_restore(f):
		return false
	var why: String = restore_why(f, country)
	if why != "":
		if country.is_player and not quiet:
			gw.say(country, why)
		return false
	var cost: int = restore_cost(f)
	var mt: int = restore_metal(f)
	var bought: int = 0
	if mt > 0 and country.metal < mt:

		var miss: int = mt - country.metal
		bought = miss
		country.money -= _metal_price(miss)
		country.metal += miss
	country.money -= cost
	country.metal -= mt
	if mt > 0 and gw.econ != null:
		gw.econ.stat_res(country, "metal", "repair", - mt)
	f.restore_t = restore_time(f)
	gw.fx.spawn("dust_s", f.center_px(), 6)
	if country.is_player and not quiet:
		gw.say(country, Loc.mk("Восстановление: %d с%s%s", [int(f.restore_t), (Loc.t(" · металл −%d") % mt) if mt > 0 else "", (Loc.t(" (куплено %d)") % bought) if bought > 0 else ""]))
	return true


func _restore_tick(f: Facility, dt: float) -> void :
	var before: float = f.restore_t
	f.restore_t = maxf(0.0, f.restore_t - dt)
	if int(before * 2.0) != int(f.restore_t * 2.0):
		var r: Rect2 = Rect2(f.origin_px(), Vector2(f.size * 4))
		var k: int = int(before * 7.0)
		gw.fx.spawn("build_spark", r.position + Vector2(float(k * 13 % int(r.size.x)), float(k * 7 % int(r.size.y))), 6)
	if f.restore_t > 0.0:
		return
	for id in f.obj_ids:
		if gw.obj_kind[id] == GameWorld.KIND_BUILDING and gw.obj_state[id] == 1:
			gw.obj_state[id] = 0
			gw._mark_obj_chunk(id)
	if f.kind == Facility.Kind.TEL:
		f.missiles = 0
		f.erect_t = -1.0
		gw.set_obj_frame(f.main_obj, "tel0", 0)
	if f.kind == Facility.Kind.NUCLEAR_PLANT:
		f.u_hits = 0
		Nuclear.refresh_look(gw, f)
		_stop_fx(f)
		_ambient_fx(f)
	ruin_hits.erase(f.id)
	f.ruined_at = -1.0
	gw.fx.spawn("build_spark", f.center_px(), 6)
	var built: bool = constructing.has(f.id)
	constructing.erase(f.id)
	if gw.country_by_id(f.country_id).is_player:
		gw.say(gw.country_by_id(f.country_id), (Loc.t("Построено: %s") if built else Loc.t("Восстановлено: %s")) % title_of(f.kind))



func has_carrier(c: Country, t: int) -> bool:
	if t == MT_CRUISE:
		return air.count(c.id, Aircraft.Type.BOMBER) > 0 or air.count(c.id, Aircraft.Type.FIGHTER) > 0
	if t == MT_AA:
		return air.count(c.id, Aircraft.Type.FIGHTER) > 0 or air.count(c.id, Aircraft.Type.ATTACK) > 0
	if t == MT_HYPER:
		return air.count(c.id, Aircraft.Type.FIGHTER) > 0
	if t == MT_KAB:
		return air.count(c.id, Aircraft.Type.ATTACK) > 0
	return true


func hostile(a: int, b: int) -> bool:
	if a == b:
		return false
	var ca: Country = gw.country_by_id(a)
	return ca != null and ca.at_war.has(b)



func set_prod_type(f: Facility, t: int) -> void :
	if f.kind != Facility.Kind.MISSILE_FACTORY or t == f.prod_type or not MT_READY[t]:
		return
	if f.producing:
		gw.country_by_id(f.country_id).money += int(MT_COST[f.prod_type])
		f.producing = false
		f.prod_t = 0.0
	f.prod_type = t


func prod_time_of(f: Facility) -> float:
	return float(MT_TIME[f.prod_type]) if f.kind == Facility.Kind.MISSILE_FACTORY else PROD_TIME



func drone_cost(jet: bool) -> Dictionary:
	var cost: Dictionary = {}
	if gw.econ != null and gw.econ.has_method("res_cost"):
		cost = (gw.econ.call("res_cost", "jet_uav" if jet else "drone") as Dictionary).duplicate()
	cost["money"] = COST_JET if jet else COST_DRONE
	return cost


func _port_runway(c: Country) -> bool:
	for f: Facility in facilities:
		if f.kind == Facility.Kind.DP_RUNWAY and f.country_id == c.id and alive(f):
			return true
	return false


func drone_capacity(country_id: int) -> int:
	var n: int = 0
	for f: Facility in facilities:
		if f.kind == Facility.Kind.DRONE_PORT and f.country_id == country_id and alive(f):
			for i in f.parked.size():
				if _spot_ok(f, i):
					n += 1
	return n


func _spot_ok(port: Facility, k: int) -> bool:
	return alive(port.spot_owner[k] as Facility)


func _free_ok_spot(port: Facility) -> int:
	for i in port.parked.size():
		if port.parked[i] == null and _spot_ok(port, i):
			return i
	return -1


func _port_with_space(c: Country, near: Vector2) -> Facility:
	var best: Facility = null
	var bd: float = INF
	for f: Facility in facilities:
		if f.kind != Facility.Kind.DRONE_PORT or f.country_id != c.id or not alive(f):
			continue
		var k: int = -1
		for i in f.parked.size():
			if f.parked[i] == null and _spot_ok(f, i):
				k = i
				break
		if k < 0:
			continue
		var dd: float = f.center_px().distance_squared_to(near)
		if dd < bd:
			bd = dd
			best = f
	return best


func _repair(dt: float) -> void :
	for f: Facility in facilities:
		if f.craters.is_empty():
			continue
		f.repair_t -= dt
		if f.repair_t <= 0.0:
			for p: Vector2 in f.craters:
				gw.fx.spawn("build_spark", p, 6)
			f.craters = PackedVector2Array()
			f.repair_t = 0.0
			if gw.country_by_id(f.country_id).is_player:
				gw.say(gw.country_by_id(f.country_id), Loc.mk("ВПП восстановлена"))




func has_solar(f: Facility) -> bool:
	for m: Facility in f.modules:
		if m.kind == Facility.Kind.SOLAR and alive(m):
			return true
	return false


func has_power(f: Facility) -> bool:
	return f.powered or has_solar(f)




func _update_power() -> void :
	Nuclear.burn(gw, POWER_DT)
	for c: Country in gw.countries:
		var cap: int = 0
		for f: Facility in facilities:
			if f.kind == Facility.Kind.POWER_PLANT and f.country_id == c.id and alive(f):
				cap += PLANT_CAP
			elif f.kind == Facility.Kind.NUCLEAR_PLANT and f.country_id == c.id:
				cap += Nuclear.output(gw, f)
			elif f.kind == Facility.Kind.SOLAR_FARM and f.country_id == c.id and alive(f):
				cap += SOLAR_FARM_CAP
		var left: int = cap
		var use: int = 0
		var order: Array = []
		for cid in c.city_ids:
			order.append(gw.cities[cid])
		order.sort_custom( func(a: City, b: City) -> bool: return a.kind < b.kind or (a.kind == b.kind and a.id < b.id))
		var forced: Dictionary = _grid_shock(c, cap, order)
		for city: City in order:
			var need: int = USE_CAPITAL if city.kind == City.Kind.CAPITAL else (USE_TOWN if city.kind == City.Kind.TOWN else USE_VILLAGE)
			use += need
			if forced.has(city.id):
				_set_city_power(city, false)
				continue
			_set_city_power(city, left >= need)
			if left >= need:
				left -= need

		var fl: Array = []
		for f: Facility in facilities:
			if f.country_id == c.id and uses_power(f.kind) and alive(f) and not f.halted:
				fl.append(f)
		fl.sort_custom( func(a: Facility, b: Facility) -> bool: return ( not has_solar(a)) and has_solar(b))
		for f: Facility in fl:
			use += USE_FACILITY
			var was: bool = f.powered
			f.powered = left >= USE_FACILITY
			if f.powered:
				left -= USE_FACILITY
			if was and not f.powered and c == gw.player:
				_lost_fac += 1
		c.power_cap = cap
		c.power_use = use

	if _plant_hit_msg or _lost_city > 0 or _lost_fac > 0 or _back_city > 0:
		var parts: Array[String] = []
		if _lost_city > 0:
			parts.append(Loc.t("обесточено городов: %d") % _lost_city)
		if _lost_fac > 0:
			parts.append(Loc.t("объектов без сети: %d") % _lost_fac)
		if _back_city > 0 and _lost_city == 0:
			parts.append(Loc.t("свет вернулся в городов: %d") % _back_city)

		if not parts.is_empty():
			gw.message.emit(Loc.msg(Loc.mk("Сеть: %s", [", ".join(parts)])))
	if not _foe_dark.is_empty():
		var nm: Array[String] = []
		for k in mini(3, _foe_dark.size()):
			nm.append(_foe_dark[k])
		gw.message.emit(Loc.msg(Loc.mk("Враг без света: %s%s", [", ".join(nm), (Loc.t(" и ещё %d") % (_foe_dark.size() - 3)) if _foe_dark.size() > 3 else ""])))
		_foe_dark.clear()
	_plant_hit_msg = false
	_lost_city = 0
	_lost_fac = 0
	_back_city = 0




func _grid_shock(c: Country, cap: int, order: Array) -> Dictionary:
	var prev: int = int(grid_prev.get(c.id, cap))
	grid_prev[c.id] = cap
	if prev - cap >= maxi(SHOCK_MIN, ceili(float(prev) * SHOCK_FRAC)) and not order.is_empty():
		var o: Vector2i = _shock_origin(c)
		var nd: int = clampi(ceili(float(order.size()) * float(prev - cap) / float(maxi(1, prev))), 1, order.size())
		var before: int = prev
		if grid_shock.has(c.id):
			before = maxi(before, int((grid_shock[c.id] as Array)[4]))
		grid_shock[c.id] = [gw.game_time + SHOCK_T, nd, o.x, o.y, before]
	if not grid_shock.has(c.id):
		return {}
	var sh: Array = grid_shock[c.id]
	if gw.game_time > float(sh[0]) or cap >= int(sh[4]):
		grid_shock.erase(c.id)
		return {}
	var oc: = Vector2i(int(sh[2]), int(sh[3]))
	var near: Array = order.duplicate()
	near.sort_custom( func(a: City, b: City) -> bool:
		var da: int = a.center.distance_squared_to(oc)
		var db: int = b.center.distance_squared_to(oc)
		return da < db or (da == db and a.id < b.id))
	var out: Dictionary = {}
	for k in mini(int(sh[1]), near.size()):
		out[(near[k] as City).id] = true
	return out



func _shock_origin(c: Country) -> Vector2i:
	var best: Facility = null
	var npp: Facility = null
	for f: Facility in facilities:
		if f.country_id != c.id or (f.kind != Facility.Kind.POWER_PLANT and f.kind != Facility.Kind.NUCLEAR_PLANT and f.kind != Facility.Kind.SOLAR_FARM):
			continue
		if f.kind == Facility.Kind.NUCLEAR_PLANT and npp == null:
			npp = f
		if f.ruined_at >= 0.0 and (best == null or f.ruined_at > best.ruined_at):
			best = f
	if best != null and gw.game_time - best.ruined_at < 5.0:
		return best.cell + best.size / 2
	if npp != null:
		return npp.cell + npp.size / 2
	return gw.cities[c.capital_id].center if c.capital_id >= 0 else Vector2i.ZERO


func _set_city_power(city: City, on: bool) -> void :
	if city.powered == on:
		return
	city.powered = on
	if not on:
		city.flicker_until = gw.game_time + BLACKOUT_FLICKER
		city.dark_since = gw.game_time
		city.spark_next = gw.game_time
		if gw.player != null and city.country_id != gw.player.id and gw.diplo != null and gw.diplo.at_war(gw.player.id, city.country_id):
			_foe_dark.append(city.name)
		if gw.player != null and city.country_id == gw.player.id:
			_lost_city += 1
	else:
		city.dark_since = -1.0
		if gw.player != null and city.country_id == gw.player.id:
			_back_city += 1



func _ai_energy() -> void :
	for c: Country in gw.countries:
		if c.is_player or c.capital_id < 0:
			continue
		for f: Facility in facilities:

			if f.country_id == c.id and f.kind == Facility.Kind.POWER_PLANT and can_restore(f) and fire_block_left(f) <= 0.0 and c.money >= restore_cost(f):
				restore(f, c)


		if c.power_use > c.power_cap and c.has_res(Economy.build_cost(Facility.Kind.POWER_PLANT)):
			var cap: City = gw.cities[c.capital_id]
			if auto_place(Facility.Kind.POWER_PLANT, cap.center, c, cap.radius + 6, cap.radius + 80) != null:
				c.money -= cost_of(Facility.Kind.POWER_PLANT)
				gw.econ.pay_build(c, Facility.Kind.POWER_PLANT)


func _update_fuel() -> void :
	for c: Country in gw.countries:
		var n: int = 0
		for f: Facility in facilities:
			if f.kind == Facility.Kind.REFINERY and f.country_id == c.id and alive(f):
				n += 1
				if has_power(f) and not f.halted:
					for _lv in gw.econ.level_of(f):
						if c.oil < 1:
							break
						c.oil -= 1
						c.fuel += 1
						gw.econ.stat_res(c, "oil", "refinery", -1)
						gw.econ.stat_res(c, "fuel", "refinery", 1)

		if c.fuel > FUEL_RESERVE:
			var sold: int = c.fuel - FUEL_RESERVE
			var fp: int = maxi(1, roundi(float(gw.econ.market_price("fuel")) * (gw.econ.upk.sell_k(c.id, "fuel") if gw.econ.upk != null else 1.0)))
			if gw.econ.upk != null:
				gw.econ.upk.note_trade(c.id, "fuel", sold, fp)
			c.fuel = FUEL_RESERVE
			c.add_money(sold * fp)
			c.fuel_sold += sold * fp
			gw.econ.stat_res(c, "fuel", "fuel_sale", - sold)
			gw.econ.stat_add(c, "income", "fuel_sale", sold * fp)



func _watch_state() -> void :
	for f: Facility in facilities:
		var a: bool = alive(f)
		if a == f.was_alive:
			continue
		f.was_alive = a
		if f.restore_t > 0.0 and not a:
			continue
		if not a:
			f.ruined_at = gw.game_time
			_stop_fx(f)
			if gw.vfx != null:
				gw.vfx.on_burn(f)
			if f.kind == Facility.Kind.REFINERY:
				_refinery_blaze(f)
			elif f.kind == Facility.Kind.POWER_PLANT or f.kind == Facility.Kind.NUCLEAR_PLANT:
				f.arc_next = gw.game_time
				f.fx.append(gw.fx.handle(gw.fx.spawn("power_arc_loop", local_px(f.main_obj, [20, 40]), 6, gw.game_time + 20.0)))
				gw.fx.spawn("spark_burst", local_px(f.main_obj, [12, 30]), 6)
				if gw.country_by_id(f.country_id).is_player:
					_plant_hit_msg = true
		else:
			_stop_fx(f)
			_ambient_fx(f)



func _refinery_blaze(f: Facility) -> void :
	var pts: Array = _info("refinery_ruin")["tanks_fire"]
	var t0: Array = [0.0, 0.35, 0.8, 1.4]
	var end: float = gw.game_time + REFINERY_BURN
	for k in pts.size():
		var p: Vector2 = local_px(f.main_obj, pts[k])
		var t: float = float(t0[k % 4])
		gw._delay(t, gw.fx.spawn.bind("tank_blast", p + Vector2(0, -5), 6))
		gw._delay(t + 0.43, _add_fx.bind(f, "fire_big_loop", p, 6, end + k * 0.5))
		if k == 0 or k == 3:
			gw._delay(t + 0.5, _add_fx.bind(f, "smoke_column_loop", p + Vector2(0, -6), 7, end))
			gw._delay(t + 0.5, _add_fx.bind(f, "smoke_black_loop", p + Vector2(2, -4), 5, end + 60.0))
		if k < 2:
			gw._delay(REFINERY_BURN, _add_fx.bind(f, "fire_small", p, 6, gw.game_time + REFINERY_BURN + 30.0))
	if gw.camera != null and gw._on_screen(f.center_px()):
		gw.camera.shake(true)


func _add_fx(f: Facility, n: String, p: Vector2, z: int, until: float) -> void :
	if alive(f):
		return
	f.fx.append(gw.fx.handle(gw.fx.spawn(n, p.round(), z, until, true)))



func _update_arcs() -> void :
	var t: float = gw.game_time
	for f: Facility in facilities:
		if (f.kind != Facility.Kind.POWER_PLANT and f.kind != Facility.Kind.NUCLEAR_PLANT) or alive(f) or f.ruined_at < 0.0 or f.restore_t > 0.0:
			continue
		if t - f.ruined_at > 20.0 and t >= f.arc_next:
			var h: int = Hash32.h2(f.id, int(t), 91)
			f.arc_next = t + 3.0 + float(h % 30) / 10.0
			if gw._on_screen(f.center_px(), 60.0):
				gw.fx.spawn("power_arc_loop", local_px(f.main_obj, [20 + (h >> 4) % 9 - 4, 40]), 6, t + 0.6 + float((h >> 8) % 6) / 10.0)
	for city: City in gw.cities:
		if city.powered or t < city.spark_next:
			continue
		var age: float = t - city.dark_since
		var hh: int = Hash32.h2(city.id, int(t * 4.0), 17)
		city.spark_next = t + (0.25 + float(hh % 15) / 100.0 if age < 10.0 else (0.8 + float(hh % 7) / 10.0 if age < 30.0 else 3.0 + float(hh % 30) / 10.0))
		if not gw._on_screen(Vector2(city.center * GameWorld.CELL), 40.0):
			continue
		var off: = Vector2i((hh >> 4) % (city.radius * 2 + 1) - city.radius, (hh >> 9) % (city.radius * 2 + 1) - city.radius)
		var c: Vector2i = city.center + off
		if gw.data.inside(c.x, c.y) and gw.data.has_flag(c.x, c.y, WorldData.F_OCCUPIED):
			gw.fx.spawn("spark_burst", Vector2(c * GameWorld.CELL) + Vector2(2, -6), 6)





func ally_site(kind: int, owner: int, country: Country) -> bool:
	if gw.diplo != null and gw.diplo.get("sky") != null and gw.diplo.sky.site_ok(kind, owner, country):
		return true
	if country == null or not country.is_player or owner <= 0 or owner == country.id or gw.diplo == null or not gw.diplo.has_method("ally_land_ok"):
		return false
	if not (Defense.is_ad(kind) or kind == Facility.Kind.AD_RADAR or kind == Facility.Kind.AD_EW or kind == Facility.Kind.BARRACKS or is_field_work(kind)):
		return false
	return gw.diplo.ally_land_ok(country.id, owner)



func line_cell_ok(c: Vector2i, country: Country) -> bool:
	var d: WorldData = gw.data
	if not d.inside(c.x, c.y) or (d.get_owner_id(c.x, c.y) != country.id and not ally_site(Facility.Kind.TRENCH_H, d.get_owner_id(c.x, c.y), country)):
		return false
	if Biome.is_water(d.get_biome(c.x, c.y)) or fort_cells.has(c) or dig_cells.has(c):
		return false
	if gw.rail != null and gw.rail.has_rail(c):
		return false
	return not d.has_flag(c.x, c.y, WorldData.F_OCCUPIED | WorldData.F_BRIDGE)


static func line_cost(kind: int, n: int) -> int:
	return cost_of(kind) * n





func build_line(kind: int, cells: Array[Vector2i], country: Country, free: bool = false, quiet: bool = false) -> Facility:
	var ok: Array[Vector2i] = []
	var hot: int = 0
	for c: Vector2i in cells:
		if ok.size() >= LINE_MAX:
			break
		if line_cell_ok(c, country) and not ok.has(c):
			if not free and enemy_near(country, Vector2(c * GameWorld.CELL) + Vector2(2, 2)):
				hot += 1
				continue
			ok.append(c)
	if ok.size() < 2:
		if not free and country.is_player and not quiet:
			gw.say(country, Loc.t("Слишком близко к противнику") if hot > 0 else Loc.t("Ведите пальцем по своей земле"))
		return null
	var cost: int = line_cost(kind, ok.size())
	if not free:
		if country.money < cost:
			if country.is_player and not quiet:
				gw.say(country, Loc.mk("Не хватает денег: нужно %d", [cost]))
			return null
		country.money -= cost

	var host: Facility = null
	for c: Vector2i in ok:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var q: = c + Vector2i(dx, dy)
				if host != null:
					continue
				var lf: Facility = fort_cells.get(q, dig_cells.get(q, null))
				if lf != null and lf.kind == kind and lf.country_id == country.id:
					host = lf
	var f: Facility = host
	if f == null:
		f = Facility.new()
		f.id = facilities.size()
		f.kind = kind
		f.country_id = country.id
		facilities.append(f)
	var d: WorldData = gw.data
	for c: Vector2i in ok:
		gw.remove_tree_at(c)
		d.add_flag(c.x, c.y, WorldData.F_OCCUPIED)
		if free:
			_dig_done(f, c, false)
		else:
			f.pending.append(c)
			dig_cells[c] = f
	_line_bounds(f)
	if host == null and gw.diplo != null and gw.diplo.has_method("note_ally_fac"):
		gw.diplo.note_ally_fac(f)
	if not free and gw._on_screen(Vector2(ok[0] * GameWorld.CELL), 40.0):
		gw.fx.spawn("dust_s", Vector2(ok[0] * GameWorld.CELL) + Vector2(2, 2), 5)
	if not free:
		Sfx.play("ui_build" if kind == Facility.Kind.TEETH_H or kind == Facility.Kind.TEETH_V else "dig_trench", Vector2(ok[ok.size() >> 1] * GameWorld.CELL))
		if country.is_player and hot > 0:
			gw.say(country, Loc.mk("У противника не копаем: %d клеток пропущено", [hot]))
	forts_changed.emit()
	gw.changed.emit()
	return f



func _dig_done(f: Facility, c: Vector2i, fx: bool) -> void :
	dig_cells.erase(c)
	if fort_cells.has(c):
		return
	var d: WorldData = gw.data
	f.cells.append(c)
	fort_cells[c] = f
	if f.kind == Facility.Kind.TEETH_H:
		f.cell_hp[c] = TEETH_HP
		gw.econ.block_rect(Rect2i(c, Vector2i.ONE), true)
	elif not d.has_flag(c.x, c.y, WorldData.F_ROAD) and (c.x + c.y) % 3 != 0:
		d.set_biome(c.x, c.y, Biome.BURNT if Biome.is_natural_land(d.get_biome(c.x, c.y)) else d.get_biome(c.x, c.y))
	if fx and gw._on_screen(Vector2(c * GameWorld.CELL), 40.0):
		gw.fx.spawn("dust_s", Vector2(c * GameWorld.CELL) + Vector2(2, 2), 5)





func dig_tick(dt: float) -> void :
	var changed: bool = false
	for f: Facility in facilities:
		if f.build_t <= 0.0 and f.pending.is_empty():
			continue
		var c: Country = gw.country_by_id(f.country_id)
		if c == null:
			continue
		if f.kind == Facility.Kind.DUGOUT:
			if not enemy_near(c, f.center_px()):
				f.build_t = maxf(0.0, f.build_t - dt)
				if f.build_t <= 0.0:
					changed = true
					if c.is_player:
						gw.say(c, Loc.mk("Блиндаж готов"))
			continue
		var left: float = dt
		while left > 0.0 and not f.pending.is_empty():
			var cell: Vector2i = f.pending[0]
			if gw.data.get_owner_id(cell.x, cell.y) != f.country_id or fort_cells.has(cell):
				f.pending.pop_front()
				dig_cells.erase(cell)
				if not fort_cells.has(cell):
					gw.data.clear_flag(cell.x, cell.y, WorldData.F_OCCUPIED)
				f.build_t = 0.0
				changed = true
				continue
			if enemy_near(c, Vector2(cell * GameWorld.CELL) + Vector2(2, 2)):
				break
			if f.build_t <= 0.0:
				f.build_t = TEETH_CELL_T if f.kind == Facility.Kind.TEETH_H else DIG_CELL_T
			var use: float = minf(left, f.build_t)
			f.build_t -= use
			left -= use
			if f.build_t <= 0.001:
				f.build_t = 0.0
				f.pending.pop_front()
				_dig_done(f, cell, true)
				changed = true
		if f.pending.is_empty():
			f.build_t = 0.0
			_line_bounds(f)
			if c.is_player and not f.cells.is_empty():
				gw.say(c, Loc.mk("%s готов: %d м", [Loc.t("Окоп") if f.kind == Facility.Kind.TRENCH_H else Loc.t("Ряд зубов дракона"), f.cells.size() * GameWorld.CELL]))
	if changed:
		forts_changed.emit()



func enemy_near(country: Country, p: Vector2, r: float = DIG_ENEMY_R) -> bool:
	if country == null or country.at_war.is_empty() or gw.army == null:
		return false
	var fog: bool = country.is_player and not gw.net_driven and gw.vision != null and gw.vision.active()
	for o: Variant in gw.army._near(p, r):
		var u: Unit = o
		if not u.alive() or not u.ground() or not country.at_war.has(u.country_id) or u.pos.distance_squared_to(p) > r * r:
			continue
		if fog and not gw.vision.sees(u.pos):
			continue
		return true
	return false



func is_built(f: Facility) -> bool:
	return f.build_t <= 0.0 and f.pending.is_empty()



func dig_progress(f: Facility) -> float:
	if f.kind == Facility.Kind.DUGOUT:
		return 1.0 - clampf(f.build_t / DUGOUT_T, 0.0, 1.0)
	var n: int = f.cells.size() + f.pending.size()
	return float(f.cells.size()) / float(maxi(1, n)) if not f.pending.is_empty() else 1.0


func dig_eta(f: Facility) -> float:
	if f.kind == Facility.Kind.DUGOUT or f.pending.is_empty():
		return f.build_t
	var per: float = TEETH_CELL_T if f.kind == Facility.Kind.TEETH_H else DIG_CELL_T
	return (f.build_t if f.build_t > 0.0 else per) + per * float(f.pending.size() - 1)


func _line_bounds(f: Facility) -> void :
	var all: Array[Vector2i] = f.cells.duplicate()
	all.append_array(f.pending)
	if all.is_empty():
		return
	var r: = Rect2i(all[0], Vector2i.ONE)
	for c: Vector2i in all:
		r = r.expand(c).expand(c + Vector2i.ONE)
	f.cell = r.position
	f.size = r.size


func remove_line_cell(f: Facility, c: Vector2i) -> void :
	if not fort_cells.has(c):
		return
	fort_cells.erase(c)
	f.cells.erase(c)
	f.cell_hp.erase(c)
	gw.data.clear_flag(c.x, c.y, WorldData.F_OCCUPIED)
	if f.kind == Facility.Kind.TEETH_H:
		gw.econ.block_rect(Rect2i(c, Vector2i.ONE), false)
		if gw._on_screen(Vector2(c * GameWorld.CELL), 40.0):
			gw.fx.spawn("dust_s", Vector2(c * GameWorld.CELL) + Vector2(2, 2), 5)
	_line_bounds(f)
	forts_changed.emit()



func damage_line(f: Facility, at: Vector2, dmg: float) -> void :
	if f.cells.is_empty():
		return
	var best: Vector2i = f.cells[0]
	var bd: float = INF
	for c: Vector2i in f.cells:
		var dd: float = (Vector2(c * GameWorld.CELL) + Vector2(2, 2)).distance_squared_to(at)
		if dd < bd:
			bd = dd
			best = c
	if f.kind == Facility.Kind.TEETH_H:
		var hp: float = float(f.cell_hp.get(best, TEETH_HP)) - dmg
		if hp <= 0.0:
			remove_line_cell(f, best)
		else:
			f.cell_hp[best] = hp



func line_point(f: Facility, from: Vector2) -> Vector2:
	var best: = Vector2.INF
	var bd: float = INF
	for c: Vector2i in f.cells:
		var p: = Vector2(c * GameWorld.CELL) + Vector2(2, 2)
		var dd: float = p.distance_squared_to(from)
		if dd < bd:
			bd = dd
			best = p
	return best



static func icon_of(kind: int) -> String:
	return String(ICON_OF.get(kind, "icon_info"))



func is_demolished(f: Facility) -> bool:
	return f != null and f.is_line() and f.cells.is_empty() and f.pending.is_empty() and f.obj_ids.is_empty()



func _dem_cell(f: Facility) -> Vector2i:
	var h: Facility = f.parent if f.parent != null else f
	if h.is_line():
		if not h.cells.is_empty():
			return h.cells[h.cells.size() / 2]
		return h.pending[h.pending.size() / 2] if not h.pending.is_empty() else h.cell
	return h.cell + h.size / 2






func demolish_why(country: Country, f: Facility) -> String:
	if country == null or f == null or f.id < 0 or f.id >= facilities.size() or facilities[f.id] != f or is_demolished(f):
		return Loc.t("Объекта нет")
	if f.country_id != country.id or (f.parent != null and f.parent.country_id != country.id):
		return Loc.t("Это не ваш объект")
	if NO_DEMOLISH.has(f.kind):
		return Loc.t("Это часть города")
	if f.moving:
		return Loc.t("Объект в пути")
	if f.restore_t > 0.0:
		return Loc.t("Идёт восстановление")
	var hc: Vector2i = _dem_cell(f)
	for cid in country.city_ids:
		var city: City = gw.cities[cid]
		if city.siege_by != 0 and maxi(absi(hc.x - city.center.x), absi(hc.y - city.center.y)) <= maxi(city.claim_max, city.radius) + 4:
			return Loc.t("Город в осаде — сносить нельзя")
	for x: Facility in _dem_set(f):
		if x.kind == Facility.Kind.BARRACKS and gw.naval != null and gw.naval.at_sea(x):
			return Loc.t("Армия в поезде или в лодках — сносить нельзя")
		if x.kind == Facility.Kind.AIRFIELD:
			for a: Aircraft in air.aircraft:
				if a.base == x and a.state != Aircraft.State.DEAD:
					return Loc.t("На аэродроме самолёты")
	return ""




func demolish_refund(f: Facility) -> int:
	var n: int = 0
	for x: Facility in _dem_set(f):
		if x.is_line():
			n += roundi(float(cost_of(x.kind) * (x.cells.size() + x.pending.size())) * DEMOLISH_REFUND)
		elif alive(x) and COSTS.has(x.kind):
			n += roundi(float(cost_of(x.kind)) * DEMOLISH_REFUND)
	return n



func _dem_set(f: Facility) -> Array[Facility]:
	var out: Array[Facility] = [f]
	var k: int = 0
	while k < out.size():
		for m: Variant in out[k].modules:
			if m is Facility and not out.has(m) and (m as Facility).country_id == f.country_id:
				out.append(m)
		k += 1
	return out








func demolish(country: Country, f: Facility) -> String:
	var why: String = demolish_why(country, f)
	if why != "":
		return why
	var back: int = demolish_refund(f)
	var lst: Array[Facility] = _dem_set(f)
	lst.reverse()
	for x: Facility in lst:
		_dem_one(x)
	country.money += back
	last_demolish_refund = back
	var AG = preload("res://game/army_groups.gd")
	AG.prune(gw, country.id)
	_plan_cache_key = ""
	_update_power()
	forts_changed.emit()
	gw.changed.emit()
	return ""


func _dem_one(x: Facility) -> void :
	_stop_fx(x)
	if gw.army != null:
		for u: Unit in gw.army.units:
			if not u.alive():
				continue
			if u.post == x:
				gw.army._release(u)
			if u.home == x:
				u.state = Unit.State.DEAD
				u.dead_t = gw.game_time
				u.post = null
		gw.army.tac.ops.erase(x)
	if gw.ops != null and gw.ops.list.has(x):
		gw.ops.cancel(x)
	if gw.ai != null:
		gw.ai._rg.erase(x)
	for d: Drone in drones:
		if (d.airfield == x or d.launcher == x) and d.state != Drone.State.FLY and d.state != Drone.State.DIVE and d.state != Drone.State.DONE:
			d.state = Drone.State.DONE
	if x.parent != null:
		var p: Facility = x.parent
		for k in range(p.spot_owner.size() - 1, -1, -1):
			if p.spot_owner[k] == x:
				var pd: Variant = p.parked[k]
				if pd is Drone:
					(pd as Drone).state = Drone.State.DONE
				p.spots.remove_at(k)
				p.spot_owner.remove_at(k)
				p.parked.remove_at(k)
		p.modules.erase(x)
		x.parent = null
	x.modules = []
	x.spots = PackedVector2Array()
	x.spot_owner = []
	x.parked = []
	x.reserved = null
	x.queued.clear()
	x.producing = false
	x.prod_t = 0.0
	x.restore_t = 0.0
	if not x.deposit.is_empty():
		if x.deposit.get("mine") == x:
			x.deposit["mine"] = null
		x.deposit = {}
		if gw.econ != null:
			gw.econ.drop_spent()
	if gw.econ != null:
		gw.econ._site.erase(x)
		if gw.econ.ports != null:
			gw.econ.ports._state.erase(x)
			gw.econ.ports._no_grow.erase(x)
		gw.econ.draw_ver += 1
	if gw.get("protect") != null:
		gw.protect.st.erase(x.id)
		gw.protect.ver += 1
	struck.erase(x.id)
	var d: WorldData = gw.data
	if x.is_line():
		for c: Vector2i in x.cells.duplicate():
			remove_line_cell(x, c)
		for c: Vector2i in x.pending:
			dig_cells.erase(c)
			if not fort_cells.has(c):
				d.clear_flag(c.x, c.y, WorldData.F_OCCUPIED)
		x.pending.clear()
		x.build_t = 0.0
		return
	var fr: = Rect2i(x.cell, x.size)
	var outer: Array[Rect2i] = []
	for oid in x.obj_ids:
		if oid >= 0 and oid < gw.obj_spr.size() and gw.obj_state[oid] != 2:
			var orr: Rect2i = gw.object_rect(oid)
			if not fr.encloses(orr):
				outer.append(orr)
		gw.remove_object(oid)
	x.obj_ids = PackedInt32Array()
	x.main_obj = -1
	for y in range(x.cell.y, x.cell.y + x.size.y):
		for xx in range(x.cell.x, x.cell.x + x.size.x):
			if d.inside(xx, y):
				d.clear_flag(xx, y, WorldData.F_OCCUPIED)
	for orr2: Rect2i in outer:
		for y in range(orr2.position.y, orr2.end.y):
			for xx in range(orr2.position.x, orr2.end.x):
				if d.inside(xx, y) and not fr.has_point(Vector2i(xx, y)):
					d.clear_flag(xx, y, WorldData.F_OCCUPIED)
		unpave(gw, orr2)
	unpave(gw, fr)
	x.build_t = 0.0
	x.kind = Facility.Kind.TRENCH_H
	x.cells.clear()
	x.cell_hp = {}







static func unpave(gw: GameWorld, r: Rect2i) -> int:
	var cells: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			cells.append(Vector2i(x, y))
	return unpave_cells(gw, cells)


static func unpave_cells(gw: GameWorld, cells: Array[Vector2i]) -> int:
	var nat: Variant = gw.get("nature")
	if nat == null:
		return 0
	var gen: PackedByteArray = nat.get("_gen")
	var d: WorldData = gw.data
	var keep: int = WorldData.F_OCCUPIED | WorldData.F_CITY | WorldData.F_ROAD | WorldData.F_BRIDGE
	var n: int = 0
	for c: Vector2i in cells:
		if not d.inside(c.x, c.y):
			continue
		var i: int = c.y * d.w + c.x
		var b: int = d.biome[i]
		if (b != Biome.PLAZA and b != Biome.INDUSTRIAL and b != Biome.FIELD) or i >= gen.size():
			continue
		var g: int = gen[i]
		if g == b or Biome.is_water(g) or (d.flags[i] & keep) != 0:
			continue
		d.set_biome(c.x, c.y, g)
		n += 1
		for e: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + e
			if d.inside(q.x, q.y) and Biome.is_water(d.get_biome(q.x, q.y)):
				d.dirty_cells.append(q)
	return n





func transfer_missiles(a: Country, b: Country, t: int, n: int) -> int:
	if a == null or b == null or t < 0 or t >= MT_CAP.size() or n <= 0:
		return 0
	var k: int = mini(mini(n, a.missile_stock[t]), maxi(0, int(MT_CAP[t]) - b.missile_stock[t]))
	if k <= 0:
		return 0
	a.missile_stock[t] -= k
	b.missile_stock[t] += k
	return k



func drone_room(b: Country) -> int:
	var n: int = 0
	if b == null:
		return 0
	for f: Facility in facilities:
		if f.kind == Facility.Kind.DRONE_PORT and f.country_id == b.id and alive(f):
			for i in f.parked.size():
				if f.parked[i] == null and _spot_ok(f, i):
					n += 1
	return n




func transfer_drones(a: Country, b: Country, n: int) -> int:
	if a == null or b == null or n <= 0:
		return 0
	var moved: int = 0
	for f: Facility in facilities:
		if f.kind != Facility.Kind.DRONE_PORT or f.country_id != a.id or not alive(f):
			continue
		for i in f.parked.size():
			if moved >= n:
				return moved
			var d: Drone = f.parked[i]
			if d == null or d.state != Drone.State.PARKED or not _spot_ok(f, i):
				continue
			var port: Facility = _port_with_space(b, f.center_px())
			if port == null:
				return moved
			var k: int = _free_ok_spot(port)
			f.parked[i] = null
			if d.launcher != null and d.launcher.reserved == d:
				d.launcher.reserved = null
			d.launcher = null
			d.country_id = b.id
			d.airfield = port
			d.spot = k
			d.pos = port.spots[k]
			port.parked[k] = d
			gw.fx.spawn("build_spark", d.pos, 6)
			moved += 1
	return moved





func price_of(kind: int, c: Country) -> int:
	if c == null or gw.econ == null or gw.econ.upk == null:
		return cost_of(kind)
	return roundi(float(cost_of(kind)) * gw.econ.upk.series_mult(c.id, kind))



func series_info(kind: int, c: Country) -> Dictionary:
	if c == null or gw.econ == null or gw.econ.upk == null:
		return {"heat": 0.0, "mult": 1.0, "price": cost_of(kind), "base": cost_of(kind), "free": 0, "cool_s": 0.0, "series": false}
	return gw.econ.upk.series_info(c.id, kind)



func pay_series(c: Country, kind: int) -> int:
	var p: int = price_of(kind, c)
	c.money -= p
	if gw.econ != null and gw.econ.upk != null:
		gw.econ.upk.note_buy(c.id, kind)
	return p
