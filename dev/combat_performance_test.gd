extends RefCounted

func run(main: Node) -> void:
	var tree: SceneTree = main.get_tree()
	for i in 300:
		if main.menus.current == "main":
			break
		await tree.create_timer(0.1).timeout
	var gw: GameWorld = main.world
	var own: Country = gw.create_country(true)
	var enemy: Country = gw.create_country(false)
	var neutral: Country = gw.create_country(false)
	own.at_war[enemy.id] = true
	var observer: Unit = Unit.new()
	observer.type = Unit.Type.INFANTRY
	observer.country_id = own.id
	observer.pos = Vector2(1000, 1000)
	gw.army.units.append(observer)
	var hostile: Unit = Unit.new()
	hostile.type = Unit.Type.INFANTRY
	hostile.country_id = enemy.id
	hostile.pos = Vector2(1030, 1000)
	gw.army.units.append(hostile)
	var friendly: Unit = Unit.new()
	friendly.type = Unit.Type.INFANTRY
	friendly.country_id = neutral.id
	friendly.pos = Vector2(1032, 1000)
	gw.army.units.append(friendly)
	gw.army.fire._spot()
	if not gw.army.fire.sees(own.id, hostile) or gw.army.fire.sees(own.id, friendly):
		push_error("[COMBAT-TEST] incorrect hostile detection")
		tree.quit(1)
		return
	gw.army._build_grid()
	gw.army._acquire(observer)
	if observer.target != hostile or not gw.army._acquire(observer):
		push_error("[COMBAT-TEST] target acquisition or retained target failed")
		tree.quit(1)
		return
	own.at_war.erase(enemy.id)
	gw.army.fire._spot()
	if gw.army.fire.sees(own.id, hostile):
		push_error("[COMBAT-TEST] ceasefire not reflected")
		tree.quit(1)
		return
	gw.army._acquire(observer)
	if observer.target != null:
		push_error("[COMBAT-TEST] target retained after ceasefire")
		tree.quit(1)
		return
	var air: Air = gw.mil.air
	gw.game_time = 10.0
	air.tracers = [[Vector2.ZERO, Vector2.ONE, 9.9], [Vector2.ZERO, Vector2.ONE, 10.0], [Vector2.ZERO, Vector2.ONE, 10.1]]
	air.update(0.0)
	if air.tracers.size() != 2 or float(air.tracers[0][2]) != 10.0 or float(air.tracers[1][2]) != 10.1:
		push_error("[COMBAT-TEST] tracer lifetime or ordering changed")
		tree.quit(1)
		return
	gw.game_time = 10.11
	air.update(0.0)
	if not air.tracers.is_empty():
		push_error("[COMBAT-TEST] expired tracers remain")
		tree.quit(1)
		return
	own.at_war[enemy.id] = true
	var ids: Array[int] = []
	for i in 10000:
		ids.append(enemy.id if i % 2 == 0 else neutral.id)
	var started: int = Time.get_ticks_usec()
	var count: int = 0
	for repeat in 10:
		for id in ids:
			if gw.army._hostile(own.id, id):
				count += 1
	var direct_us: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for repeat in 10:
		var cache: Dictionary = {}
		for id in ids:
			if not cache.has(id):
				cache[id] = gw.army._hostile(own.id, id)
			if cache[id]:
				count += 1
	if count != 100000:
		push_error("[COMBAT-TEST] benchmark counts differ")
		tree.quit(1)
		return
	print("[COMBAT-BENCH] direct_us=", direct_us, " cached_us=", Time.get_ticks_usec() - started, " count=", count)
	print("[COMBAT-TEST] PASS: hostile, neutral and ceasefire detection; tracer expiry and ordering")
	tree.quit(0)
