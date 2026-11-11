extends "res://game/game_world/gw_map.gd"



func found_city(cell: Vector2i, country: Country, kind: int, plan_in: Dictionary = {}) -> City:
	var plan: Dictionary = plan_in if not plan_in.is_empty() else can_found_city(cell, kind, kind == City.Kind.CAPITAL)
	if bool(plan["ok"]) and plan.has("center"):
		cell = plan["center"]
	if not bool(plan["ok"]):
		if kind == City.Kind.TOWN:
			plan = can_found_city(cell, City.Kind.VILLAGE)
			kind = City.Kind.VILLAGE
		if not bool(plan["ok"]):
			message.emit(String(plan["reason"]))
			return null
	if kind != City.Kind.CAPITAL and not BORDER_GAP.site_ok(self, cell, country.id, int(plan["radius"])):
		if country.is_player:
			message.emit(Loc.msg(Loc.mk("Слишком близко к чужой границе: нужно %d м от города", [BORDER_GAP.GAP * CELL])))
		return null
	if kind != City.Kind.CAPITAL and not BORDER_GAP.own_ok(self, cell, country.id, int(plan["radius"])):
		if country.is_player:
			message.emit(Loc.msg(Loc.mk("Слишком близко к своему городу: нужно %d м между городами", [BORDER_GAP.OWN_GAP * CELL])))
		return null
	if preload("res://game/ad_relocate.gd").war_blocked(self, cell, country, int(plan["radius"])):
		if country.is_player:
			message.emit(Loc.msg(Loc.mk("Нельзя: на месте города стоят войска противника")))
		return null
	var city: = City.new()
	city.id = cities.size()
	city.kind = kind
	city.country_id = country.id
	city.founder_id = country.id
	city.center = cell
	city.entrance = plan["entrance"]
	city.radius = int(plan["radius"])
	city.claim_max = int(plan["claim"])
	city.claim_v = 2
	city.name = NameGen.city(rng, country.arch, cities.map( func(o: City) -> String: return o.name))
	if mil != null:
		preload("res://game/ad_relocate.gd").clear_site(self, city, plan, country)
	if army != null:
		preload("res://game/ad_relocate.gd").clear_units(self, city, country, city.radius)
	_apply_plan(plan, city)
	city.garrison_max = city.garrison_cap()
	city.garrison = city.garrison_max
	cities.append(city)
	country.city_ids.append(city.id)
	BORDER_GAP.reopen_near(self, city)
	if kind == City.Kind.CAPITAL:
		country.capital_id = city.id
	if aftermath != null:
		aftermath.clear_site(city)
	if nature != null:
		nature.touch_site(city.center, city.radius + 2)

	var cells_all: Array[Vector2i] = []
	var ci: int = cell.y * data.w + cell.x
	if data.owners[ci] == 0:
		data.owners[ci] = country.id
		cells_all.append(cell)
		_own_mark(cells_all)
	city.frontier = [Vector3i(cell.x, cell.y, 0)]
	city.visited = {ci: true}
	top.flash_cells(cells_all)

	_grow_initial(city, city.radius + 3, 999 if kind == City.Kind.CAPITAL else 6)

	_road_to_own(city, country.id)
	if kind == City.Kind.CAPITAL:
		for oc: City in cities:
			if oc.kind == City.Kind.CAPITAL and oc.country_id != country.id and oc.center.distance_to(city.center) < data.w * 0.75:
				road_async([[city.entrance, oc.entrance]], true)
	_checkpoints_dirty = true
	changed.emit()
	return city


func _apply_plan(plan: Dictionary, city: City) -> void :
	var colony_look: GDScript = preload("res://game/colony_look.gd")
	if colony_look.is_poor(self, city):
		plan = colony_look.poorer(self, plan, city)
	for c: Vector2i in plan["cells"]:
		data.add_flag(c.x, c.y, WorldData.F_CITY)
		remove_tree_at(c)
	for g: Array in plan["ground"]:
		var c: Vector2i = g[0]
		data.set_biome(c.x, c.y, int(g[1]))
	for c: Vector2i in plan["streets"]:
		data.set_biome(c.x, c.y, Biome.STREET)
		data.add_flag(c.x, c.y, WorldData.F_ROAD)
	for c: Vector2i in plan["avenues"]:
		data.set_biome(c.x, c.y, Biome.ROAD)
		data.add_flag(c.x, c.y, WorldData.F_ROAD)

	for c: Vector2i in plan.get("quays", []):
		data.set_biome(c.x, c.y, Biome.PLAZA)
		data.add_flag(c.x, c.y, WorldData.F_ROAD | WorldData.F_CITY)
		remove_tree_at(c)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var e: Vector2i = c + d
			if data.inside(e.x, e.y) and Biome.is_water(data.get_biome(e.x, e.y)):
				data.dirty_cells.append(e)
	for br: Array in plan.get("bridges", []):
		var bc: Array[Vector2i] = []
		bc.assign(br[0])
		for c: Vector2i in bc:
			data.add_flag(c.x, c.y, WorldData.F_BRIDGE | WorldData.F_ROAD)
		_make_bridge(bc, br[1])
		if econ != null and econ.nav != null:
			econ.nav_open(bc)
	for b: Array in plan["buildings"]:
		var sname: String = b[0]
		var c: Vector2i = b[1]
		var id: int = add_object(sname, c, KIND_BUILDING)
		if id < 0:
			continue
		city.buildings += 1
		ArchStyle.mark(self, id, city.country_id)
		var r: Rect2i = object_rect(id)
		for yy in range(r.position.y, r.end.y):
			for xx in range(r.position.x, r.end.x):
				data.add_flag(xx, yy, WorldData.F_OCCUPIED)
		if sname == "admin" and city.kind == City.Kind.CAPITAL:
			var fsid: int = ArchStyle.draw_sid(self, id)
			var info: Dictionary = ArchStyle.info_of(fsid, atlas.info("admin"))
			var a: Vector2 = spr_anchor[fsid]
			var p: = Vector2(c.x * CELL - a.x, (c.y + spr_fd[fsid]) * CELL - a.y) + Vector2(float(info.get("flag_x", 0)) + 1.0, float(info.get("flag_y", 0)) - 1.0)
			city.flag_node = top.add_flag(country_by_id(city.country_id).flag_frames, p)
	for t: Array in plan["trees"]:
		var c: Vector2i = t[1]
		var id: int = add_object(String(t[0]), c, KIND_TREE)
		tree_at[c.y * data.w + c.x] = id
	colony_look.after(self, plan)







func road_async(pairs: Array, first_only: bool) -> void :
	if pairs.is_empty():
		return
	var job: Dictionary = _road_job(pairs, first_only)
	job["task"] = WorkerThreadPool.add_task(_road_worker.bind(job), false, "roads")
	_road_jobs.append(job)




func _road_to_own(city: City, country_id: int) -> void :
	var cand: Array = []
	for oc: City in cities:
		if oc != city and oc.country_id == country_id:
			cand.append([oc.center.distance_squared_to(city.center), oc.id])
	cand.sort()
	var pairs: Array = []
	for k in mini(3, cand.size()):
		pairs.append([city.entrance, cities[int(cand[k][1])].entrance])
	road_async(pairs, true)




func _road_job(pairs: Array, first_only: bool) -> Dictionary:
	return {"pairs": pairs, "first": first_only, "paths": [], "log": [], "w": data.w, "h": data.h, "seed": data.world_seed, 
		"biome": data.biome.duplicate(), "flags": data.flags.duplicate(), "mask": rail.mask.duplicate() if rail != null else PackedByteArray(), 
		"data_id": data.get_instance_id(), "task": -1}



func _road_worker(job: Dictionary) -> void :
	for pr: Array in job["pairs"]:
		var a: Vector2i = pr[0]
		var b: Vector2i = pr[1]
		var path: Array[Vector2i] = _road_astar(job, a, b, 48, false)
		if path.is_empty():
			path = _road_astar(job, a, b, 180, false)
		if path.is_empty():

			path = _road_astar(job, a, b, 90, true)
		if not path.is_empty():
			(job["paths"] as Array).append(path)
			if bool(job["first"]):
				break


func _road_astar(job: Dictionary, a: Vector2i, b: Vector2i, margin: int, sea: bool) -> Array[Vector2i]:
	var t0: int = Time.get_ticks_msec()
	var w: int = job["w"]
	var h: int = job["h"]
	var biome: PackedByteArray = job["biome"]
	var flags: PackedByteArray = job["flags"]
	var rail_m: PackedByteArray = job["mask"]
	var sd: int = int(job["seed"]) + 31
	var x0: int = maxi(1, mini(a.x, b.x) - margin)
	var y0: int = maxi(1, mini(a.y, b.y) - margin)
	var x1: int = mini(w - 2, maxi(a.x, b.x) + margin)
	var y1: int = mini(h - 2, maxi(a.y, b.y) + margin)
	var astar: = AStarGrid2D.new()
	astar.region = Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	var has_rail: bool = not rail_m.is_empty()
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i: int = y * w + x
			var fl: int = flags[i]
			var cost: float
			if (fl & WorldData.F_ROAD) != 0:
				cost = 1.0
			elif (fl & WorldData.F_OCCUPIED) != 0:
				astar.set_point_solid(Vector2i(x, y), true)
				continue
			else:
				var bb: int = biome[i]
				if sea and bb <= Biome.RIVER:
					cost = SEA_ROAD_COST
				else:
					cost = Biome.road_cost(bb)
				if cost < 0.0:
					astar.set_point_solid(Vector2i(x, y), true)
					continue
				cost += float(Hash32.h2(x, y, sd) & 7) * 0.12
				if has_rail and rail_m[i] != 0:
					cost += 6.0
			astar.set_point_weight_scale(Vector2i(x, y), cost)
	astar.set_point_solid(a, false)
	astar.set_point_solid(b, false)
	var path: Array[Vector2i] = astar.get_id_path(a, b)
	if path.is_empty():
		(job["log"] as Array).append("[Road] no path %s -> %s (window %d%s)" % [a, b, margin, ", sea" if sea else ""])
		return path



	var run: int = 0
	var longest: int = 0
	var span: float = 0.0
	var r0: = Vector2i(-1, -1)
	for p: Vector2i in path:
		var i2: int = p.y * w + p.x
		if biome[i2] <= Biome.RIVER and (flags[i2] & WorldData.F_BRIDGE) == 0:
			if run == 0:
				r0 = p
			run += 1
			longest = maxi(longest, run)
			span = maxf(span, Vector2(p - r0).length() + 1.0)
		else:
			run = 0
	if span > float(MAX_STRAIT) or longest > MAX_STRAIT * 3 / 2:
		(job["log"] as Array).append("[Road] sea gap %d m (%d path cells) > %d m: no bridge %s -> %s" % [roundi(span * CELL), longest, MAX_STRAIT * CELL, a, b])
		var none: Array[Vector2i] = []
		return none
	(job["log"] as Array).append("[Road] %d cells in %d ms (worker)%s" % [path.size(), Time.get_ticks_msec() - t0, " (sea bridge)" if sea else ""])
	return path



func _road_apply(job: Dictionary) -> bool:
	if job.has("xb"):
		return _xb_apply(job)
	for line: String in job["log"]:
		print(line)
	if int(job["data_id"]) != data.get_instance_id():
		return false
	var any: bool = false
	for path: Array[Vector2i] in job["paths"]:
		var blocked: bool = false
		for p: Vector2i in path:
			if data.has_flag(p.x, p.y, WorldData.F_OCCUPIED) and not data.has_flag(p.x, p.y, WorldData.F_ROAD):
				blocked = true
				break
		if blocked:

			if int(job.get("retry", 0)) < 2:
				var again: Dictionary = _road_job([[path[0], path[path.size() - 1]]], true)
				again["retry"] = int(job.get("retry", 0)) + 1
				again["task"] = WorkerThreadPool.add_task(_road_worker.bind(again), false, "roads")
				_road_jobs.append(again)
			else:
				print("[Road] path blocked meanwhile - skipped")
			continue
		_apply_road(path)
		road_paths.append(path)
		any = true
	if any:
		_checkpoints_dirty = true
	return any



func _poll_roads() -> void :
	if _road_jobs.is_empty():
		return
	for k in range(_road_jobs.size() - 1, -1, -1):
		var job: Dictionary = _road_jobs[k]
		if not job_ready(int(job["task"])):
			continue
		WorkerThreadPool.wait_for_task_completion(int(job["task"]))
		_road_jobs.remove_at(k)
		var t0: int = Time.get_ticks_usec()
		_road_apply(job)
		if rail != null:
			rail.pt("road_apply", t0)



func drain_jobs() -> void :
	_enc_drain()
	for job: Dictionary in _road_jobs:
		if int(job["task"]) >= 0:
			WorkerThreadPool.wait_for_task_completion(int(job["task"]))
	_road_jobs.clear()
	if rail != null:
		rail.drain()
	if supply != null and supply.has_method("drain"):
		supply.drain()
	if mil != null and mil.has_method("drain_roam"):
		mil.drain_roam()


func _apply_road(path: Array[Vector2i]) -> void :
	var run: Array[Vector2i] = []
	var run_dirs: = PackedByteArray()
	var run_k0: int = 0
	var n: int = path.size()
	for k in n:
		var p: Vector2i = path[k]
		var prev: Vector2i = path[k - 1] if k > 0 else p
		var nxt: Vector2i = path[k + 1] if k < n - 1 else p
		var dir: int = 0 if (prev.x != p.x or nxt.x != p.x) else 1
		if Biome.is_water(data.get_biome(p.x, p.y)):
			if not data.has_flag(p.x, p.y, WorldData.F_BRIDGE):
				if run.is_empty():
					run_k0 = k
				run.append(p)
				run_dirs.append(dir)
				data.add_flag(p.x, p.y, WorldData.F_BRIDGE | WorldData.F_ROAD)
			elif not run.is_empty():
				_make_bridge(run, run_dirs, path, run_k0)
				run.clear()
				run_dirs = PackedByteArray()
		else:
			if not run.is_empty():
				_make_bridge(run, run_dirs, path, run_k0)
				run.clear()
				run_dirs = PackedByteArray()
			var bb: int = data.get_biome(p.x, p.y)
			if bb != Biome.STREET and bb != Biome.ROAD:
				data.set_biome(p.x, p.y, Biome.ROAD)
			data.add_flag(p.x, p.y, WorldData.F_ROAD)
			remove_tree_at(p)
	if not run.is_empty():
		_make_bridge(run, run_dirs, path, run_k0)
	if econ != null and econ.nav != null:
		econ.nav_open(path)


func _make_bridge(cells: Array[Vector2i], dirs: PackedByteArray, path: Array[Vector2i] = [], k0: int = 0) -> void :
	var b: = Bridge.new()
	b.id = bridges.size()
	b.cells = cells.duplicate()
	b.dirs = dirs
	var open_sea: bool = false
	for c: Vector2i in cells:
		if Biome.is_open_sea(data.get_biome(c.x, c.y)):
			open_sea = true
			break
	if cells.size() >= Bridge.SEA_MIN or open_sea:

		b.kind = Bridge.Kind.SEA
		var raw: = PackedVector2Array()
		var ka: int = maxi(0, k0 - 1)
		var kb: int = mini(path.size() - 1, k0 + cells.size()) if not path.is_empty() else -1
		if kb >= 0:
			for k in range(ka, kb + 1):
				raw.append(Vector2(path[k] * CELL) + Vector2(2, 2))
		else:
			for c: Vector2i in cells:
				raw.append(Vector2(c * CELL) + Vector2(2, 2))
		b.pts = poly_simplify(raw, 6.0)
	bridges.append(b)
	for c: Vector2i in b.cells:
		bridge_cells[c.y * data.w + c.x] = b
	ground.queue_redraw()
	if rail != null:
		rail.layer_dirty()



static func poly_simplify(p: PackedVector2Array, eps: float) -> PackedVector2Array:
	if p.size() < 3:
		return p
	var keep: = PackedByteArray()
	keep.resize(p.size())
	keep[0] = 1
	keep[p.size() - 1] = 1
	var stack: Array[Vector2i] = [Vector2i(0, p.size() - 1)]
	while not stack.is_empty():
		var seg: Vector2i = stack.pop_back()
		var a: Vector2 = p[seg.x]
		var b: Vector2 = p[seg.y]
		var best: int = -1
		var bd: float = eps
		for i in range(seg.x + 1, seg.y):
			var d: float = Geometry2D.get_closest_point_to_segment(p[i], a, b).distance_to(p[i])
			if d > bd:
				bd = d
				best = i
		if best >= 0:
			keep[best] = 1
			stack.append(Vector2i(seg.x, best))
			stack.append(Vector2i(best, seg.y))
	var out: = PackedVector2Array()
	for i in p.size():
		if keep[i] == 1:
			out.append(p[i])
	return out


func bridge_at(c: Vector2i) -> Bridge:
	if not data.inside(c.x, c.y):
		return null
	return bridge_cells.get(c.y * data.w + c.x, null)



func bridge_ok_idx(i: int) -> bool:
	var b: Bridge = bridge_cells.get(i, null)
	return b != null and (b.passable() or b.pont == 2)




func road_ok(c: Vector2i) -> bool:
	if not data.inside(c.x, c.y) or not data.has_flag(c.x, c.y, WorldData.F_ROAD):
		return false
	if not data.has_flag(c.x, c.y, WorldData.F_BRIDGE):
		return true
	var b: Bridge = bridge_cells.get(c.y * data.w + c.x, null)
	return b != null and b.passable() and b.kind == Bridge.Kind.RIVER


func destroy_bridge(b: Bridge, k: int) -> void :
	b.start_rebuild(k)
	if supply != null:
		supply.on_bridge_destroyed(b, k)
	for i in range(b.lo, b.hi + 1):
		var c: Vector2i = b.cells[i]
		var p: = Vector2(c.x * CELL + 2, c.y * CELL + 2)
		var tc: float = maxf(0.0, b.collapse[i] - b.t)
		_delay(tc, fx.debris_burst.bind(p, 2, true, true))
		_delay(tc + 0.15, fx.spawn.bind("splash", p + Vector2(0, 2), 6))
		if i % 2 == 0:
			_delay(tc, fx.spawn.bind("dust_s", p, 5))
	_delay(0.0, ground.queue_redraw)
	if rail != null:
		rail.layer_dirty()
	if econ != null:
		econ.bridge_state(b.cells, false)
	if army != null:
		army.on_bridge_broken(b)
	var mid: Vector2i = b.cells[clampi(k, 0, b.cells.size() - 1)]
	var own: int = data.get_owner_id(mid.x, mid.y)
	if own == 0 and rail != null:
		own = rail.bridge_owner(b)
	if player != null and own == player.id:
		if b.rehit:
			message.emit(Loc.msg(Loc.mk("%s: разрушен ещё пролёт (%d) — весь мост через %d с", [Loc.t("Ж/д мост") if b.kind == Bridge.Kind.RAIL else Loc.t("Мост"), b.down_spans(), ceili(b.left())])))
		else:
			message.emit(Loc.t("Ж/д мост разрушен — восстановление 4 мин") if b.kind == Bridge.Kind.RAIL else Loc.t("Мост разрушен — восстановление 2 мин"))


func _update_bridges(dt: float) -> void :
	var redraw: bool = false
	for b: Bridge in bridges:
		if b.state != Bridge.State.REBUILDING:
			continue
		var before: Array = []
		for i in b.cells.size():
			before.append(b.view(i))
		b.t += dt
		var et: float = b.end_t()
		if b.t >= b.next_spark and b.t < et and b.t > 1.2:
			b.next_spark = b.t + randf_range(0.35, 0.6)
			for i in b.cells.size():
				if b.view(i) == 2:
					var c: Vector2i = b.cells[i]
					fx.spawn("build_spark", Vector2(c.x * CELL + 2 + randi_range(-2, 2), c.y * CELL + 2 + randi_range(-2, 2)), 6)
					break
		if b.t >= et:
			b.state = Bridge.State.INTACT
			var c0: Vector2i = b.cells[0]
			var c1: Vector2i = b.cells[b.cells.size() - 1]
			fx.spawn("build_spark", Vector2(c0.x * CELL + 2, c0.y * CELL + 2), 6)
			fx.spawn("build_spark", Vector2(c1.x * CELL + 2, c1.y * CELL + 2), 6)
			if econ != null:
				econ.bridge_state(b.cells, true)
			if supply != null:
				supply.on_bridge_rebuilt(b)
			if player != null and data.get_owner_id(c0.x, c0.y) == player.id:
				message.emit(Loc.msg(Loc.mk("Мост восстановлен")))
			redraw = true
			continue
		for i in b.cells.size():
			var v: int = b.view(i)
			if v != int(before[i]):
				redraw = true
				if v == 0 or before[i] == 1:
					var c: Vector2i = b.cells[i]
					fx.spawn("build_spark", Vector2(c.x * CELL + 2, c.y * CELL + 2), 6)
	if redraw:
		ground.queue_redraw()
		if rail != null:
			rail.layer_dirty()




func _update_checkpoints() -> void :
	_checkpoints_dirty = false
	if kpp != null and BorderPosts.active():
		kpp.update_posts()
		return
	var stable: Dictionary = {}
	for c: Country in countries:
		stable[c.id] = country_stable(c.id)
	var want: Dictionary = {}
	for path: Array in road_paths:
		for k in range(1, path.size()):
			var a: Vector2i = path[k - 1]
			var b: Vector2i = path[k]
			var oa: int = data.get_owner_id(a.x, a.y)
			var ob: int = data.get_owner_id(b.x, b.y)
			if oa == ob:
				continue

			if oa == 0 or ob == 0:
				continue
			if true:
				var pa: Array = _dry_side(path, k - 1, -1, oa)
				if not pa.is_empty():
					want["%d,%d,%d" % [pa[0].x, pa[0].y, oa]] = [pa[0], oa, pa[1]]
			if true:
				var pb: Array = _dry_side(path, k, 1, ob)
				if not pb.is_empty():
					want["%d,%d,%d" % [pb[0].x, pb[0].y, ob]] = [pb[0], ob, pb[1]]
	for key: String in checkpoints.keys():
		if not want.has(key):
			_remove_checkpoint(checkpoints[key])
			checkpoints.erase(key)
	for key: String in want:
		if checkpoints.has(key):
			continue
		var wv: Array = want[key]
		checkpoints[key] = _create_checkpoint(wv[0], int(wv[1]), wv[2])




func _dry_side(path: Array, k: int, step: int, own_id: int) -> Array:
	var j: int = k
	for n in 12:
		if j < 0 or j >= path.size():
			return []
		var c: Vector2i = path[j]
		if data.get_owner_id(c.x, c.y) != own_id:
			return []
		if not data.has_flag(c.x, c.y, WorldData.F_BRIDGE):
			var outward: Vector2i = path[j - step] if (j - step >= 0 and j - step < path.size()) else c
			return [c, outward - c]
		j -= step
	return []


func _remove_checkpoint(cp: Dictionary) -> void :
	for id in cp["objs"]:
		remove_object(id)
	for c: Vector2i in cp.get("cells", []):
		data.clear_flag(c.x, c.y, WorldData.F_OCCUPIED)
	if cp["flag"] != null:
		(cp["flag"] as Node).queue_free()


func _cell_free_for_prop(c: Vector2i, allow_trees: bool = true) -> bool:
	if not data.inside(c.x, c.y):
		return false
	if Biome.is_water(data.get_biome(c.x, c.y)):
		return false
	if not allow_trees and tree_at.has(c.y * data.w + c.x):
		return false
	return not data.has_flag(c.x, c.y, WorldData.F_OCCUPIED | WorldData.F_ROAD)


func _create_checkpoint(cell: Vector2i, country_id: int, out_dir: Vector2i) -> Dictionary:
	var objs: = PackedInt32Array()
	var horiz: bool = out_dir.x != 0
	objs.append(add_object("barrier_h" if horiz else "barrier_v", cell, KIND_PROP))
	var base: Vector2i = cell - out_dir
	var sides: Array[Vector2i] = []
	if horiz:
		sides.append_array([Vector2i(0, -1), Vector2i(0, 1)])
	else:
		sides.append_array([Vector2i(1, 0), Vector2i(-1, 0)])
	var booth_side: = Vector2i.ZERO
	var booth_rect: = Rect2i(-10, -10, 0, 0)
	var occ_cells: Array[Vector2i] = []
	for attempt in 4:
		if booth_side != Vector2i.ZERO:
			break
		var p: Vector2i = sides[attempt % 2]
		var allow_trees: bool = attempt >= 2
		var nw: Vector2i
		if horiz:
			nw = Vector2i(base.x - 1, base.y - 2) if p.y < 0 else Vector2i(base.x - 1, base.y + 1)
		else:
			nw = Vector2i(base.x + 1, base.y - 1) if p.x > 0 else Vector2i(base.x - 2, base.y - 1)
		var ok: bool = true
		for dy in 2:
			for dx in 2:
				if not _cell_free_for_prop(nw + Vector2i(dx, dy), allow_trees):
					ok = false
		if ok:
			for dy in 2:
				for dx in 2:
					var q: Vector2i = nw + Vector2i(dx, dy)
					remove_tree_at(q)
					data.add_flag(q.x, q.y, WorldData.F_OCCUPIED)
					occ_cells.append(q)
			objs.append(add_object("kpp_booth", nw, KIND_PROP))
			booth_side = p
			booth_rect = Rect2i(nw, Vector2i(2, 2))
	var flag_node: Node = null
	var first: Vector2i = - booth_side if booth_side != Vector2i.ZERO else sides[0]
	var cands: Array[Vector2i] = [base + first, base - first, base - out_dir + first, base - out_dir - first, cell + first, cell - first, base - out_dir * 2 + first, base - out_dir * 2 - first]
	var pole: = Vector2i(-1, -1)
	for pass_i in 2:
		for q: Vector2i in cands:
			if _cell_free_for_prop(q, pass_i == 1) and not booth_rect.has_point(q):
				pole = q
				break
		if pole.x >= 0:
			break
	if pole.x >= 0:
		remove_tree_at(pole)
		data.add_flag(pole.x, pole.y, WorldData.F_OCCUPIED)
		occ_cells.append(pole)
		var pid: int = add_object("flagpole", pole, KIND_PROP)
		objs.append(pid)
		var info: Dictionary = atlas.info("flagpole")
		var a: Vector2 = spr_anchor[obj_spr[pid]]
		var tip: = Vector2(pole.x * CELL - a.x, (pole.y + 1) * CELL - a.y) + Vector2(float(info["flag_x"]) + 1.0, float(info["flag_y"]) - 1.0)
		var c: Country = country_by_id(country_id)
		if c != null:
			flag_node = top.add_flag(c.flag_frames, tip)
	return {"objs": objs, "flag": flag_node, "cell": cell, "cells": occ_cells}


func selected_facility() -> Facility:
	return selected_fac_fn.call() if selected_fac_fn.is_valid() else null


func selected_drone() -> Object:
	return selected_fn.call() if selected_fn.is_valid() else null


func camera_shake_small() -> void :
	if camera != null:
		camera.shake(false)


func _on_screen(p: Vector2, margin: float = 0.0) -> bool:
	if camera == null:
		return false
	var sp: Vector2 = camera.world_to_screen(p)
	return Rect2(Vector2( - margin, - margin), camera.view_size() + Vector2(margin, margin) * 2.0).has_point(sp)



func camera_shake_tiny(p: Vector2) -> void :
	if _on_screen(p):
		camera.shake_pattern([Vector2(1, 0), Vector2(0, 1), Vector2(0, 0)], 0.033)



func camera_shake_launch(p: Vector2) -> void :
	if _on_screen(p):
		var seq: Array = []
		for k in 20:
			seq.append([Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)][k % 4])
		seq.append(Vector2.ZERO)
		camera.shake_pattern(seq, 0.05)



func strike_big(cell: Vector2i, by: int = 0) -> void :
	var p: = Vector2(cell.x * CELL + 2, cell.y * CELL + 2)
	var water: bool = data.inside(cell.x, cell.y) and Biome.is_water(data.get_biome(cell.x, cell.y))


	var wild: bool = not water and data.inside(cell.x, cell.y) and Biome.is_natural_land(data.get_biome(cell.x, cell.y)) and not data.has_flag(cell.x, cell.y, WorldData.F_CITY | WorldData.F_OCCUPIED)
	fx.spawn("explosion_m" if wild else "explosion_l", p, 6)
	Sfx.play("expl_big", p, 2.0)
	fx.spawn("splash" if water else "shockwave", p, 1)
	if _on_screen(p):
		camera.shake_pattern([Vector2(4, 0), Vector2(-3, 2), Vector2(2, -3), Vector2(-3, 1), Vector2(2, 2), Vector2(-1, -2), Vector2(1, 1), Vector2(-1, 0), Vector2(0, 0)], 0.033)
	elif _on_screen(p, camera.view_size().x):
		camera.shake_pattern([Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, 0)], 0.033)
	_delay(0.07, fx.debris_burst.bind(p, 8, false))
	_delay(0.14, _apply_strike.bind(cell, 7, "crater_l", 30.0, by))
	if not water:
		var burn_end: float = game_time + (18.0 if wild else 40.0)
		var offs: Array = [Vector2(-2, 1)] if wild else [Vector2(-7, -2), Vector2(5, -5), Vector2(-2, 6), Vector2(7, 4)]
		for k in offs.size():
			_delay(0.5 + k * 0.04, fx.spawn.bind("fire_small", p + Vector2(offs[k]), 3, burn_end + k * 0.4, true))
		_delay(0.6, fx.spawn.bind("smoke_black_loop", p + Vector2(-7, -6), 5, burn_end, true))
		if not wild:
			_delay(0.6, fx.spawn.bind("smoke_black_loop", p + Vector2(5, -9), 5, burn_end, true))


func strike(cell: Vector2i, by: int = 0) -> void :
	var p: = Vector2(cell.x * CELL + 2, cell.y * CELL + 2)
	fx.spawn("explosion_m", p, 6)
	Sfx.play("expl_small", p, 2.0)
	if camera != null and _on_screen(p, 100.0):
		camera.shake(true)
	fx.debris_burst(p, 6, false)
	_delay(0.14, _apply_strike.bind(cell, 3, "crater_m", 14.0, by))


func _apply_strike(cell: Vector2i, r: int = 3, crater: String = "crater_m", r_px: float = 14.0, by: int = 0) -> void :
	if not data.inside(cell.x, cell.y):
		return
	if NetConfig.trace:
		print("[Trace] strike tick=%d t=%.3f cell=%s r=%d by=%d" % [net_tick, game_time, cell, r, by])
	var victim: int = data.get_owner_id(cell.x, cell.y)
	if data.has_flag(cell.x, cell.y, WorldData.F_CITY):
		var hc: City = city_at_cell(cell)
		if hc != null:
			hc.strike_t = game_time
			if by > 0 and by != hc.country_id:
				hc.war_by = by
	if supply != null:
		supply.strike_by = by
	if by > 0 and victim > 0 and victim != by and diplo != null:
		diplo.on_attack(by, victim)
	var value: int = 0
	var spare: PackedInt32Array = protect.take_spare(cell) if protect != null else PackedInt32Array()
	var box: = Rect2i(cell - Vector2i(r + 8, r + 8), Vector2i(2 * r + 16, 2 * r + 16))
	var fo: Dictionary = {}
	var fo_ok: bool = false
	for ck: ObjChunk in objects.chunks_in_rect(box):
		for id in ck.ids:
			if obj_state[id] != 0:
				continue
			var rr: Rect2i = object_rect(id)
			var qx: int = clampi(cell.x, rr.position.x, rr.end.x - 1)
			var qy: int = clampi(cell.y, rr.position.y, rr.end.y - 1)
			if (qx - cell.x) * (qx - cell.x) + (qy - cell.y) * (qy - cell.y) > r * r:
				continue
			var kind: int = obj_kind[id]
			if kind == KIND_PROP:
				continue
			if not spare.is_empty() and spare.has(id):
				continue
			obj_state[id] = 1
			ck.mark()
			if kind == KIND_BUILDING:
				_start_fire(rr)
				value += 25 * rr.size.x * rr.size.y / 4 + 10
				if data.has_flag(rr.position.x, rr.position.y, WorldData.F_CITY) and not fo_ok:
					fo = _fac_objs()
					fo_ok = true
				if data.has_flag(rr.position.x, rr.position.y, WorldData.F_CITY) and not fo.has(id):
					ruins.append([id, game_time, -1.0, 0])
					var rc: City = city_at_cell(rr.position)
					if rc != null:
						rc.strike_t = game_time
						if by > 0 and by != rc.country_id:
							rc.war_by = by
						night._cells.erase(rc.id)
	for b: Bridge in bridges:
		for k in b.cells.size():
			if b.cells[k].distance_squared_to(cell) <= 4:
				if not b.fresh_hit(k):
					destroy_bridge(b, k)
				break
	var bc: int = data.get_biome(cell.x, cell.y)
	if not Biome.is_water(bc) and not data.has_flag(cell.x, cell.y, WorldData.F_ROAD | WorldData.F_OCCUPIED):
		ground.decals.append([crater, Vector2(cell.x * CELL + 2, cell.y * CELL + 2)])
		ground.queue_redraw()
	var br: int = 2 if r <= 3 else 5
	for dy in range( - br, br + 1):
		for dx in range( - br, br + 1):
			var c: = Vector2i(cell.x + dx, cell.y + dy)
			if not data.inside(c.x, c.y) or dx * dx + dy * dy > br * br + 1:
				continue
			var b: int = data.get_biome(c.x, c.y)
			if Biome.is_natural_land(b) and b != Biome.SAND and rng.range_i(3) != 0:
				data.set_biome(c.x, c.y, Biome.BURNT)
	if nature != null:
		nature.on_strike(cell, r, br)
	mil.on_strike(cell, r_px)
	var pp: = Vector2(cell.x * CELL + 2, cell.y * CELL + 2)
	if value > 0:
		Sfx.play("building_collapse", pp)
	army.on_strike(pp, r_px, by)
	if naval != null:
		naval.on_strike(pp, r_px, by)
	if navy != null:
		navy.on_strike(pp, r_px, by)
	econ.on_strike(pp, r_px, by)
	if supply != null:
		supply.on_strike(pp, r_px, by)
	rail.on_strike(cell, r, by)
	if by > 0 and victim != by and value > 0:
		var att: Country = country_by_id(by)
		if att != null:
			att.destroyed += value


func _start_fire(rr: Rect2i) -> void :
	var cx: float = (rr.position.x + rr.size.x * 0.5) * CELL
	var by: float = (rr.position.y + rr.size.y * 0.5) * CELL
	var n: int = 2 if rr.size.x * rr.size.y <= 4 else 3
	var burn_end: float = game_time + 30.0
	var fire: Dictionary = {"p": Vector2(cx, by), "until": burn_end, "h": [], "city": -1, "truck": false}
	var city: City = city_at_cell(Vector2i(int(cx / CELL), int(by / CELL)))
	if city != null:
		fire["city"] = city.id
		fire["until"] = game_time + 60.0
		burn_end = game_time + 60.0
	fires.append(fire)
	for k in n:
		var p: = Vector2(cx + randi_range(-3, 3) + (k - 1) * 3, by + randi_range(-2, 2))
		_delay(0.21 + k * 0.05, _fire_fx.bind(fire, "fire_small", p, 3, burn_end + k * 0.3))
	var sp: = Vector2(cx, by - 4)
	_delay(0.26, _fire_fx.bind(fire, "smoke_black_loop", sp, 5, burn_end))
	_delay(burn_end - game_time, fx.spawn.bind("smoke_loop", sp, 5, burn_end + 45.0, true))


func _fire_fx(fire: Dictionary, n: String, p: Vector2, z: int, until: float) -> void :
	if float(fire["until"]) <= game_time:
		return
	(fire["h"] as Array).append(fx.handle(fx.spawn(n, p, z, until, true)))



func extinguish(fire: Dictionary) -> void :
	for h: Array in fire["h"]:
		fx.stop_h(h)
	(fire["h"] as Array).clear()
	fire["until"] = game_time
	if NetConfig.trace:
		print("[Trace] extinguish tick=%d p=%s" % [net_tick, fire["p"]])
	fx.spawn("smoke_loop", (fire["p"] as Vector2) + Vector2(0, -4), 5, game_time + 8.0, true)


func _xb_want() -> bool:
	return extra_links_on and settings != null and (settings.rivers > 22 or settings.map_type != 0)


func _xb_far(c: Vector2i, extra: Array) -> bool:
	for b: Bridge in bridges:
		if b.kind != Bridge.Kind.RAIL and not b.cells.is_empty():
			var m: Vector2i = b.cells[b.cells.size() / 2]
			if maxi(absi(m.x - c.x), absi(m.y - c.y)) < XB_GAP:
				return false
	for q: Vector2i in extra:
		if maxi(absi(q.x - c.x), absi(q.y - c.y)) < XB_GAP:
			return false
	return true



func _xb_worker(job: Dictionary) -> void :
	var out: Array = []
	for pr: Array in job["pairs"]:
		var path: Array[Vector2i] = _road_astar(job, pr[0], pr[1], 48, false)
		if path.is_empty():
			path = _road_astar(job, pr[0], pr[1], 110, false)
		out.append(path)
	job["xb_paths"] = out




func _xb_road_ok(path: Array[Vector2i]) -> bool:
	if path.size() < 2:
		return path.size() == 1
	var a: Vector2i = path[0]
	var b: Vector2i = path[path.size() - 1]
	var straight: float = Vector2(b - a).length()
	if float(path.size()) > straight * 1.6 * 1.25 + 12.0:
		return false
	var hills: int = 0
	for p: Vector2i in path:
		if data.has_flag(p.x, p.y, WorldData.F_ROAD):
			continue
		var bb: int = data.get_biome(p.x, p.y)
		if bb == Biome.SNOW or bb == Biome.ROCK or Biome.is_water(bb):
			return false
		if bb == Biome.HILLS or bb == Biome.PINE:
			hills += 1
	return hills * 100 <= path.size() * 20



func _xb_apply(job: Dictionary) -> bool:
	if int(job["data_id"]) != data.get_instance_id() or not job.has("xb_paths"):
		return false
	var paths: Array = job["xb_paths"]
	var made: int = 0
	for i in (job["xb"] as Array).size():
		if made >= int(job["xb_want"]):
			break
		var e: Array = job["xb"][i]
		var cross: Array[Vector2i] = []
		cross.assign(e[0])
		var pa: Array[Vector2i] = []
		var pb: Array[Vector2i] = []
		pa.assign(paths[i * 2])
		pb.assign(paths[i * 2 + 1])
		if pa.is_empty() or pb.is_empty() or not _xb_road_ok(pa) or not _xb_road_ok(pb) or not _xb_far(e[1], []):
			continue
		var free: bool = true
		for arr: Array in [cross, pa, pb]:
			for q: Vector2i in arr:
				if data.has_flag(q.x, q.y, WorldData.F_OCCUPIED) and not data.has_flag(q.x, q.y, WorldData.F_ROAD):
					free = false
					break
		if not free:
			continue
		for arr2: Array[Vector2i] in [pa, cross, pb]:
			_apply_road(arr2)
			road_paths.append(arr2)
		xb_mids.append(e[1])
		made += 1
	_xb_made += made
	if made > 0:
		_checkpoints_dirty = true
	return made > 0




func _xb_target(bank: Vector2i, other: Vector2i, fallback: Vector2i) -> Vector2i:
	var best: Vector2i = fallback
	var bd: int = absi(fallback.x - bank.x) + absi(fallback.y - bank.y)
	for path: Array in road_paths:
		for i in range(0, path.size(), 3):
			var q: Vector2i = path[i]
			var d: int = absi(q.x - bank.x) + absi(q.y - bank.y)
			if d < bd and d >= 6 and d + 4 < absi(q.x - other.x) + absi(q.y - other.y) and not data.has_flag(q.x, q.y, WorldData.F_BRIDGE):
				bd = d
				best = q
	return best



func _xb_flat(c: Vector2i) -> bool:
	var W: int = data.w
	var bio: PackedByteArray = data.biome
	if bio[c.y * W + c.x] == Biome.HILLS:
		return false
	for y in range(maxi(0, c.y - 3), mini(data.h, c.y + 4)):
		var row: int = y * W
		for x in range(maxi(0, c.x - 3), mini(W, c.x + 4)):
			var bb: int = bio[row + x]
			if bb == Biome.ROCK or bb == Biome.SNOW:
				return false
	return true




func _update_fires_ruins(dt: float) -> void :
	for k in range(fires.size() - 1, -1, -1):
		if game_time > float(fires[k]["until"]) + 5.0:
			fires.remove_at(k)
	_fire_snd_t -= dt
	if _fire_snd_t <= 0.0:
		_fire_snd_t = 0.5
		_fire_sound()
	_ruin_t += dt
	if _ruin_t < 4.0:
		return
	_ruin_t = 0.0
	if NetConfig.trace:
		print("[Trace] ruins_check tick=%d n=%d fires=%d" % [net_tick, ruins.size(), fires.size()])






	var busy: Dictionary = {}
	var rcity: Array = []
	rcity.resize(ruins.size())
	for k in ruins.size():
		var e: Array = ruins[k]
		while e.size() < 4:
			e.append(-1.0 if e.size() == 2 else 0)
		var rcc: City = city_at_cell(Vector2i(obj_x[int(e[0])], obj_y[int(e[0])])) if int(e[0]) < obj_x.size() else null
		rcity[k] = rcc
		if rcc != null and float(e[2]) >= 0.0:
			busy[rcc.id] = int(busy.get(rcc.id, 0)) + 1
	var seen: Dictionary = {}
	var fo: Dictionary = _fac_objs() if not ruins.is_empty() else {}
	for k in range(ruins.size() - 1, -1, -1):
		var e2: Array = ruins[k]
		var id: int = e2[0]
		if id >= obj_state.size() or obj_state[id] != 1 or seen.has(id) or fo.has(id):
			ruins.remove_at(k)
			continue
		seen[id] = true
		var city: City = rcity[k]
		var ok: bool = aftermath == null or aftermath.repair_ok(city)
		if float(e2[2]) >= 0.0:
			if not ok:
				e2[2] = -1.0
				busy[city.id] = int(busy.get(city.id, 1)) - 1
				continue
			e2[2] = float(e2[2]) - 4.0
			if float(e2[2]) > 0.0:
				continue
			obj_state[id] = 0
			if NetConfig.trace:
				print("[Trace] rebuild tick=%d id=%d" % [net_tick, id])
			_mark_obj_chunk(id)
			fx.spawn("build_spark", obj_origin(id) + Vector2(4, 4), 6)
			ruins.remove_at(k)
			continue
		if not ok or game_time - float(e2[1]) < 70.0:
			continue
		if city != null and int(busy.get(city.id, 0)) >= int(aftermath.build_cap(city) if aftermath != null else 99):
			continue
		var cell: = Vector2i(obj_x[id], obj_y[id])
		var o: int = data.get_owner_id(cell.x, cell.y)
		var c: Country = country_by_id(o)
		if c == null:
			continue
		var burning: bool = false
		for f: Dictionary in fires:
			if float(f["until"]) > game_time and (f["p"] as Vector2).distance_to(Vector2(cell * CELL)) < 16.0:
				burning = true
		if burning:
			continue
		if int(e2[3]) == 0:
			if c.money < 30:
				continue
			c.money -= 30
			e2[3] = 1
		var rr: Rect2i = object_rect(id)
		e2[2] = REBUILD_L if rr.size.x * rr.size.y > 16 else REBUILD_S
		if city != null:
			busy[city.id] = int(busy.get(city.id, 0)) + 1
		if NetConfig.trace:
			print("[Trace] rebuild_start tick=%d id=%d c=%d" % [net_tick, id, c.id])



func _fire_sound() -> void :
	var lp: Vector2 = Sfx.listener()
	var best: Vector2 = Vector2.INF
	var bd: float = INF
	if lp.is_finite():
		for f: Dictionary in fires:
			var fp: Vector2 = f["p"]
			if float(f["until"]) > game_time and fp.distance_squared_to(lp) < bd:
				bd = fp.distance_squared_to(lp)
				best = fp
	Sfx.loop("fire", "fire_loop", best.is_finite(), best)






func _fac_objs() -> Dictionary:
	var out: Dictionary = {}
	if mil == null:
		return out
	for f: Facility in mil.facilities:
		for oid in f.obj_ids:
			out[oid] = true
	return out
