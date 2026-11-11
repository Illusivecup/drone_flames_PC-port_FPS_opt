extends RefCounted

func run(main: Node) -> void:
	var tree: SceneTree = main.get_tree()
	for i in 300:
		if main.menus.current == "main":
			break
		await tree.create_timer(0.1).timeout
	if not await Save.load_slot(main, 4):
		push_error("[SAVE-PROFILE] Could not load copied save")
		tree.quit(1)
		return
	var gw: GameWorld = main.world
	gw.set_process(false)
	var chunk_stats: Array = []
	var old_chunk_script: GDScript = load("res://dev/obj_chunk_reference.gd")
	var old_chunk_us: int = 0
	var new_chunk_us: int = 0
	var compared: int = 0
	for chunk: ObjChunk in gw.objects.chunks:
		if chunk.left != null and chunk.ids.size() >= 100 and chunk.left.ids.size() >= 100:
			var old_chunk = old_chunk_script.new()
			old_chunk.gw = gw
			old_chunk.ids = chunk.ids
			old_chunk.left = chunk.left
			var old_start: int = Time.get_ticks_usec()
			var expected: PackedInt32Array = old_chunk._find_guests()
			old_chunk_us += Time.get_ticks_usec() - old_start
			var cstart: int = Time.get_ticks_usec()
			var guests: PackedInt32Array = chunk._find_guests()
			var elapsed_us: int = Time.get_ticks_usec() - cstart
			new_chunk_us += elapsed_us
			compared += 1
			old_chunk.free()
			if guests != expected:
				push_error("[SAVE-PROFILE] chunk guest ordering changed: %d" % chunk.idx)
				tree.quit(1)
				return
			chunk_stats.append([elapsed_us, chunk.idx, chunk.ids.size(), chunk.left.ids.size(), guests.size()])
	chunk_stats.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	print("[SAVE-PROFILE] slow_chunks_us=", chunk_stats.slice(0, 8))
	print("[SAVE-PROFILE] chunks_compared=", compared, " original_us=", old_chunk_us, " optimized_us=", new_chunk_us)
	var strat: Node = gw.get_node("Strat")
	for i in 300:
		if strat.lo_tex != null:
			break
		await tree.create_timer(0.1).timeout
	if strat.lo_tex == null:
		push_error("[SAVE-PROFILE] map texture not ready")
		tree.quit(1)
		return
	var old_zoom: Vector2 = gw.camera.zoom
	GameConfig.performance_mode = 3
	gw.camera.zoom = Vector2.ONE * (0.75 / MapCamera.ui_k)
	strat._process(0.016)
	if not strat._full:
		push_error("[SAVE-PROFILE] maximum performance profile failed")
		tree.quit(1)
		return
	GameConfig.performance_mode = 0
	gw.camera.zoom = Vector2.ONE * (0.50 / MapCamera.ui_k)
	strat._process(0.016)
	if not strat._full:
		push_error("[SAVE-PROFILE] performance profile did not hide detailed map")
		tree.quit(1)
		return
	GameConfig.performance_mode = 2
	strat._process(0.016)
	if strat._full:
		push_error("[SAVE-PROFILE] quality profile did not restore detailed map")
		tree.quit(1)
		return
	GameConfig.performance_mode = 1
	gw.camera.zoom = Vector2.ONE * (0.30 / MapCamera.ui_k)
	strat._process(0.016)
	if not strat._full:
		push_error("[SAVE-PROFILE] distant map did not switch to low detail")
		tree.quit(1)
		return
	gw.camera.zoom = Vector2.ONE * (0.6 / MapCamera.ui_k)
	strat._process(0.016)
	if strat._full:
		push_error("[SAVE-PROFILE] detailed map did not return")
		tree.quit(1)
		return
	gw.camera.zoom = old_zoom
	print("[SAVE-PROFILE] map detail switching PASS")
	var start_check: int = Time.get_ticks_usec()
	var old_forest: bool = gw.guide._sawmill_site(gw.player).x >= 0
	var old_us: int = Time.get_ticks_usec() - start_check
	start_check = Time.get_ticks_usec()
	var new_forest: bool = gw.guide._forest_site_exists(gw.player)
	var new_us: int = Time.get_ticks_usec() - start_check
	print("[SAVE-PROFILE] forest_old_us=", old_us, " forest_new_us=", new_us, " result=", new_forest)
	if old_forest != new_forest:
		push_error("[SAVE-PROFILE] forest availability changed")
		tree.quit(1)
		return
	var upkeep = gw.econ.upk
	upkeep.comp_ver = -1
	upkeep.comp = PackedInt32Array()
	upkeep._job = {}
	upkeep._fill_step()
	var ref_job: Dictionary = upkeep._job.duplicate(true)
	var reference_us: int = 0
	var optimized_us: int = 0
	for i in 12:
		var bench_start: int = Time.get_ticks_usec()
		_reference_fill(ref_job)
		reference_us += Time.get_ticks_usec() - bench_start
		bench_start = Time.get_ticks_usec()
		upkeep._fill_step()
		optimized_us += Time.get_ticks_usec() - bench_start
		if upkeep._job.is_empty() or ref_job["i"] != upkeep._job["i"] or ref_job["next"] != upkeep._job["next"] or ref_job["lab"] != upkeep._job["lab"] or ref_job["stack"] != upkeep._job["stack"]:
			push_error("[SAVE-PROFILE] flood-fill state changed")
			tree.quit(1)
			return
	print("[SAVE-PROFILE] flood-fill comparison PASS: 12 steps")
	print("[SAVE-PROFILE] flood_reference_us=", reference_us, " flood_new_us=", optimized_us)
	GameWorld.perf_prof = true
	gw.perf_sys.clear()
	gw.perf_totals.clear()
	var start: int = Time.get_ticks_usec()
	for i in 120:
		gw._sim_step(0.2)
	var elapsed: float = float(Time.get_ticks_usec() - start) / 1000.0
	print("[SAVE-PROFILE] map=", gw.data.w, "x", gw.data.h, " cities=", gw.cities.size(), " facilities=", gw.mil.facilities.size(), " units=", gw.army.units.size(), " step_avg_ms=", elapsed / 120.0)
	print("[SAVE-PROFILE] subsystem_peak_ms=", gw.perf_sys)
	print("[SAVE-PROFILE] subsystem_total_ms=", gw.perf_totals)
	GameWorld.perf_prof = false
	tree.quit(0)

func _reference_fill(job: Dictionary) -> void:
	var solid: PackedByteArray = job["solid"]
	var labels: PackedInt32Array = job["lab"]
	var stack: PackedInt32Array = job["stack"]
	var w: int = int(job["w"])
	var n: int = solid.size()
	var i: int = int(job["i"])
	var nx: int = int(job["next"])
	var budget: int = 2000
	while budget > 0:
		if stack.is_empty():
			var skip: int = 0
			while i < n and (solid[i] != 0 or labels[i] != 0):
				i += 1
				skip += 1
				if skip >= 2048:
					break
			budget -= skip / 16 + 1
			if i >= n:
				break
			if solid[i] != 0 or labels[i] != 0:
				continue
			labels[i] = nx
			nx += 1
			stack.append(i)
		var q: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		budget -= 1
		var label: int = labels[q]
		var x: int = q % w
		if x > 0 and solid[q - 1] == 0 and labels[q - 1] == 0:
			labels[q - 1] = label
			stack.append(q - 1)
		if x < w - 1 and solid[q + 1] == 0 and labels[q + 1] == 0:
			labels[q + 1] = label
			stack.append(q + 1)
		if q >= w and solid[q - w] == 0 and labels[q - w] == 0:
			labels[q - w] = label
			stack.append(q - w)
		if q + w < n and solid[q + w] == 0 and labels[q + w] == 0:
			labels[q + w] = label
			stack.append(q + w)
	job["i"] = i
	job["next"] = nx
	job["stack"] = stack
	job["lab"] = labels
