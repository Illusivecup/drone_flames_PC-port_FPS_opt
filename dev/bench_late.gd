extends RefCounted

# Стенд замеров (только песочница): ускоренная партия ИИ без графики, срез по системам.
const LIMIT_REAL_S: float = 60.0
const WINDOW_GAME_S: float = 40.0   # интервал отчёта в игровых секундах

func run(main: Node) -> void:
	var tree: SceneTree = main.get_tree()
	for i in range(100):
		if main.world != null and main.world.data != null and not main.world.cities.is_empty():
			break
		await tree.create_timer(0.2).timeout
	await tree.create_timer(1.0).timeout
	var w: GameWorld = main.world
	Engine.max_fps = 0
	w._landmasses()
	var c: Vector2i = w._find_capital_spot(-1)
	if c.x >= 0:
		w.place_player_capital(c)
	main._set_mode(0)
	main.in_menu = false
	if main.menus != null:
		main.menus.visible = false
	_stress(w, int(OS.get_environment("BENCH_UNITS")) if OS.get_environment("BENCH_UNITS") != "" else 250)
	GameWorld.perf_prof = true
	print("[BENCH] start: cities=", w.cities.size(), " countries=", w.countries.size() if "countries" in w else -1)
	var t_start: int = Time.get_ticks_usec()
	var next_cp: float = WINDOW_GAME_S
	var frames: int = 0
	var win_frames: int = 0
	var win_us: int = 0
	var win_steps: int = 0
	var sys_tot: Dictionary = {}
	var last: int = Time.get_ticks_usec()
	while true:
		await tree.process_frame
		w.time_scale = 6000.0
		var now: int = Time.get_ticks_usec()
		var dt_us: int = now - last
		last = now
		frames += 1
		win_frames += 1
		win_us += dt_us
		win_steps += w.sim_steps
		for k in w.perf_sys:
			sys_tot[k] = float(sys_tot.get(k, 0.0)) + float(w.perf_sys[k])
		w.perf_sys.clear()
		if w.game_time >= next_cp or float(now - t_start) / 1e6 > LIMIT_REAL_S:
			next_cp += WINDOW_GAME_S
			var rows: Array = []
			for k in sys_tot:
				rows.append([k, float(sys_tot[k]) / float(maxi(1, win_frames))])
			rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
			var top: String = ""
			for i in range(mini(9, rows.size())):
				top += "%s=%.2f " % [rows[i][0], rows[i][1]]
			var nu: int = w.army.units.size() if w.army != null else -1
			var nf: int = w.mil.facilities.size() if w.mil != null else -1
			print("[BENCH] game=%dmin real=%ds frames=%d frame_ms=%.1f steps/fr=%.2f units=%d fac=%d objs=%d | sim ms/frame by system: %s" % [
				int(w.game_time / 60.0), int(float(now - t_start) / 1e6), frames,
				float(win_us) / 1000.0 / float(maxi(1, win_frames)), float(win_steps) / float(maxi(1, win_frames)),
				nu, nf, w.obj_spr.size() - w._free_ids.size(), top])
			win_frames = 0
			win_us = 0
			win_steps = 0
			sys_tot.clear()
		if float(now - t_start) / 1e6 > LIMIT_REAL_S:
			break
	print("[BENCH] done")
	main.get_tree().quit()


func _stress(w: GameWorld, per_country: int) -> void:
	var caps: Array = []
	for c: City in w.cities:
		if c.kind == City.Kind.CAPITAL:
			caps.append(Vector2(c.center * GameWorld.CELL))
	if caps.is_empty():
		return
	var ctr: Vector2 = Vector2.ZERO
	for p: Vector2 in caps:
		ctr += p
	ctr /= float(caps.size())
	# BENCH_FRONT=1: две коалиции (чётные против нечётных), воюют только между собой, стоят по разные стороны фронта
	var front: bool = OS.get_environment("BENCH_FRONT") == "1"
	for a: Country in w.countries:
		for b: Country in w.countries:
			if a != b and (not front or (a.id % 2) != (b.id % 2)):
				a.at_war[b.id] = true
	var land: Array = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var tries: int = 0
	while land.size() < 400 and tries < 40000:
		tries += 1
		var q: Vector2 = ctr + Vector2(rng.randf_range(-360.0, 360.0), rng.randf_range(-360.0, 360.0))
		var cell: Vector2i = Vector2i(int(q.x / GameWorld.CELL), int(q.y / GameWorld.CELL))
		if w.data.inside(cell.x, cell.y) and not Biome.is_water(w.data.get_biome(cell.x, cell.y)):
			land.append(q)
	print("[BENCH] stress: land points=", land.size(), " centroid=", ctr)
	if land.is_empty():
		return
	var home_mode: bool = OS.get_environment("BENCH_HOME") == "1"
	var cap_of: Dictionary = {}
	for ct: City in w.cities:
		if ct.kind == City.Kind.CAPITAL:
			cap_of[ct.country_id] = Vector2(ct.center * GameWorld.CELL)
	var types: Array = [Unit.Type.INFANTRY, Unit.Type.INFANTRY, Unit.Type.INFANTRY, Unit.Type.TANK, Unit.Type.IFV, Unit.Type.ATGM, Unit.Type.ARTY]
	for c: Country in w.countries:
		for i in range(per_country):
			var u: Unit = Unit.new()
			u.id = w.army._next_id
			w.army._next_id += 1
			u.type = int(types[i % types.size()])
			u.country_id = c.id
			u.hp = float(Army.SPEC[u.type]["hp"]) if Army.SPEC.has(u.type) else 100.0
			u.max_hp = u.hp
			var lp: Vector2 = land[rng.randi() % land.size()]
			if OS.get_environment("BENCH_RAID") == "1" and i % 4 == 0:
				var others: Array = cap_of.keys()
				var tid: int = int(others[(others.find(c.id) + 1) % others.size()])
				var ang: float = rng.randf() * TAU
				var rad: float = rng.randf_range(35.0, 110.0)
				var cand2: Vector2 = (cap_of[tid] as Vector2) + Vector2(cos(ang), sin(ang)) * rad
				var c2: Vector2i = Vector2i(int(cand2.x / GameWorld.CELL), int(cand2.y / GameWorld.CELL))
				if w.data.inside(c2.x, c2.y) and not Biome.is_water(w.data.get_biome(c2.x, c2.y)):
					lp = cand2
			elif home_mode and cap_of.has(c.id):
				for tr in range(12):
					var cand: Vector2 = (cap_of[c.id] as Vector2) + Vector2(rng.randf_range(-90.0, 90.0), rng.randf_range(-90.0, 90.0))
					var cc: Vector2i = Vector2i(int(cand.x / GameWorld.CELL), int(cand.y / GameWorld.CELL))
					if w.data.inside(cc.x, cc.y) and not Biome.is_water(w.data.get_biome(cc.x, cc.y)):
						lp = cand
						break
			if front:
				# сторона определяется чётностью id: левая/правая половина «зоны боёв»
				var side: float = -1.0 if (c.id % 2) == 0 else 1.0
				lp.x = ctr.x + side * (30.0 + absf(lp.x - ctr.x) * 0.5)
			u.pos = lp
			u.heading = rng.randf() * TAU
			u.update_frame()
			w.army.units.append(u)
	print("[BENCH] units after spawn: ", w.army.units.size())
