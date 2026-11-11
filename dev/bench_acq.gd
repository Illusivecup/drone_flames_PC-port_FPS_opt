extends RefCounted

# Проверка эквивалентности и замер: оригинальный _acquire (эталон) против нового.

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
	var per: int = int(OS.get_environment("BENCH_UNITS")) if OS.get_environment("BENCH_UNITS") != "" else 250
	var bl: RefCounted = (load("res://dev/bench_late.gd") as GDScript).new()
	bl.call("_stress", w, per)
	# даём разгореться боям
	var t0: int = Time.get_ticks_usec()
	while w.game_time < float(OS.get_environment("BENCH_GAME_S") if OS.get_environment("BENCH_GAME_S") != "" else "150") and float(Time.get_ticks_usec() - t0) / 1e6 < 60.0:
		await tree.process_frame
		w.time_scale = 6000.0
	w.time_scale = 0.0
	await tree.process_frame
	var army: Army = w.army
	print("[ACQ] game=", int(w.game_time), "s units=", army.units.size())
	army._build_grid()
	# какие юниты участвуют (как в update: живые, не FPV, не артиллерия)
	var pool: Array = []
	for u: Unit in army.units:
		if u.alive() and u.type != Unit.Type.FPV and not u.indirect():
			pool.append(u)
	print("[ACQ] pool=", pool.size(), " grid cells=", army._grid.size())
	# эквивалентность (в разных режимах: обычный и с «охраной» нельзя имитировать, поэтому только обычный)
	var mism: int = 0
	var with_t: int = 0
	var fac_t: int = 0
	var saved: Array = []
	for u: Unit in pool:
		u.target = null
		army._acquire_ref(u)
		saved.append(u.target)
		if u.target != null:
			with_t += 1
			if u.target is Facility:
				fac_t += 1
	var i: int = 0
	for u: Unit in pool:
		u.target = null
		army._acquire(u)
		if u.target != saved[i]:
			mism += 1
		i += 1
	print("[ACQ] equivalence: mismatches=", mism, " units_with_target=", with_t, " (из них зданий: ", fac_t, ") of ", pool.size())
	# замер
	var reps: int = 30
	var ts: int = Time.get_ticks_usec()
	for r in range(reps):
		for u: Unit in pool:
			u.target = null
			army._acquire_ref(u)
	var t_ref: float = float(Time.get_ticks_usec() - ts) / 1000.0 / float(reps)
	ts = Time.get_ticks_usec()
	for r in range(reps):
		for u: Unit in pool:
			u.target = null
			army._acquire(u)
	var t_new: float = float(Time.get_ticks_usec() - ts) / 1000.0 / float(reps)
	print("[ACQ] per full pass: reference=%.2f ms  new=%.2f ms  speedup x%.2f" % [t_ref, t_new, t_ref / maxf(0.001, t_new)])
	main.get_tree().quit()
