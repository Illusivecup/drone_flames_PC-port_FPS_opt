class_name ImpossibleShots
extends RefCounted

func run(main: Node, _arg: String = "") -> void:
	print("[ImpossibleShots] Starting showcase capture...")
	var tree: SceneTree = main.get_tree()
	await tree.create_timer(0.6).timeout
	
	Save.want = [1, ""]
	var ok: bool = await Save.load_game(main)
	print("[ImpossibleShots] Save load result: ", ok)
	
	for wait_step in range(30):
		if not main.world.countries.is_empty() and not main.world.cities.is_empty():
			break
		await tree.create_timer(0.2).timeout
	
	GameConfig.dev_mode = true
	GameConfig.perf_hud = true
	if main.world.vision != null:
		main.world.vision.set_enabled(false)
	
	var player: Country = null
	var enemy: Country = null
	for c: Country in main.world.countries:
		if c.is_player:
			player = c
		elif enemy == null:
			enemy = c
	
	if player == null and not main.world.countries.is_empty():
		player = main.world.countries[0]
	if enemy == null:
		enemy = main.world.countries[1] if main.world.countries.size() > 1 else player
	
	var p_pos: Vector2 = Vector2(800, 800)
	for city: City in main.world.cities:
		if city.country_id == player.id:
			p_pos = Vector2(city.center * GameWorld.CELL)
			break
	
	var e_pos: Vector2 = p_pos + Vector2(700, -300)
	for city: City in main.world.cities:
		if city.country_id != player.id:
			e_pos = Vector2(city.center * GameWorld.CELL)
			break

	# -------------------------------------------------------------
	# SHOT 6: MEGA ECONOMY / GOD MODE ($999M, Max Stockpiles, Mega Base)
	# -------------------------------------------------------------
	print("[ImpossibleShots] Staging Shot 6: Mega Economy God Mode...")
	player.name = "ИМПЕРИЯ Reborn Team"
	player.money = 999999999
	player.oil = 999999
	player.titanium = 999999
	player.metal = 999999
	player.precious = 999999
	player.missile_stock = [999, 999, 999, 999, 999, 999]
	player.power_cap = 9999
	player.power_use = 1250
	
	var kinds: Array[int] = [
		Facility.Kind.AD_PATRIOT, Facility.Kind.AD_PATRIOT,
		Facility.Kind.AD_RADAR, Facility.Kind.AD_RADAR,
		Facility.Kind.NUCLEAR_PLANT, Facility.Kind.NUCLEAR_PLANT,
		Facility.Kind.TEL, Facility.Kind.TEL,
		Facility.Kind.DRONE_PORT, Facility.Kind.DRONE_FACTORY
	]
	var base_cell: Vector2i = Vector2i(p_pos / float(GameWorld.CELL))
	var k_idx: int = 0
	for k: int in kinds:
		var c_off: Vector2i = Vector2i((k_idx % 4) * 3 - 4, (k_idx / 4) * 3 - 4)
		main.world.mil.build(k, base_cell + c_off, player, null, true)
		k_idx += 1
	
	main.cam.set_zoom_at(1.0, main.cam.view_size() * 0.5)
	main.cam.center_on(p_pos)
	await tree.create_timer(0.6).timeout
	_snap(main, "6_mega_economy_god_mode.png")
	
	# -------------------------------------------------------------
	# SHOT 7: HYPERSONIC MISSILE SALVO (16 Hypersonic Missiles Mid-Flight)
	# -------------------------------------------------------------
	print("[ImpossibleShots] Staging Shot 7: Hypersonic Missile Salvo...")
	main.world.mil.missiles.clear()
	main.world.time_scale = 1.0
	for i in range(16):
		var from_pt: Vector2 = p_pos + Vector2(i * 18 - 140, randf_range(-15, 15))
		var to_pt: Vector2 = e_pos + Vector2(randf_range(-80, 80), randf_range(-80, 80))
		var m: Missile = main.world.mil.launch_hyper(player.id, from_pt, to_pt, 0.0)
		m.t = 1.5 + (i % 5) * 0.4
	
	main.cam.set_zoom_at(1.0, main.cam.view_size() * 0.5)
	main.cam.center_on(p_pos + Vector2(180, -80))
	await tree.create_timer(0.5).timeout
	main.world.time_scale = 0.0
	_snap(main, "7_hypersonic_missile_salvo.png")
	
	# -------------------------------------------------------------
	# SHOT 8: MASSIVE DRONE SWARM (Crisp 2.0x Tactical Formation with Jet Fire)
	# -------------------------------------------------------------
	print("[ImpossibleShots] Staging Shot 8: Massive Drone Swarm...")
	main.world.mil.missiles.clear()
	main.world.mil.drones.clear()
	var swarm_center: Vector2 = p_pos + Vector2(300, -260)
	var flight_dir: Vector2 = Vector2(1.0, -0.2).normalized()
	var wing_dir: Vector2 = Vector2(-flight_dir.y, flight_dir.x)
	
	for r in range(5):
		var in_row: int = r + 1
		for c in range(in_row):
			var d: Drone = Drone.new()
			d.id = main.world.mil._next_drone_id
			main.world.mil._next_drone_id += 1
			d.country_id = player.id
			d.state = Drone.State.FLY
			var dx: float = -float(r) * 36.0
			var dy: float = (float(c) - float(in_row - 1) * 0.5) * 26.0
			d.pos = swarm_center + flight_dir * dx + wing_dir * dy
			d.heading = flight_dir.angle()
			d.speed = 40.0
			d.h = 12.0 + float(r) * 1.5
			d.cruise_speed = d.speed
			d.cruise_h = d.h
			d.target = swarm_center + flight_dir * 1000.0
			d.route = [d.target]
			d.kind = 1
			d.boost_t = 0.6
			main.world.mil.drones.append(d)
	
	main.cam.set_zoom_at(2.0, main.cam.view_size() * 0.5)
	main.cam.center_on(swarm_center)
	await tree.create_timer(0.6).timeout
	_snap(main, "8_massive_drone_swarm.png")
	
	# -------------------------------------------------------------
	# SHOT 9: CUSTOM MAP - TOTAL WORLD WAR (Overlapping Radar Networks)
	# -------------------------------------------------------------
	print("[ImpossibleShots] Staging Shot 9: Custom Map Total World War...")
	main.world.mil.drones.clear()
	for c1: Country in main.world.countries:
		for c2: Country in main.world.countries:
			if c1.id != c2.id:
				c1.at_war[c2.id] = true
	
	for city: City in main.world.cities:
		main.world.mil.build(Facility.Kind.AD_RADAR, city.center + Vector2i(2, 2), main.world.country_by_id(city.country_id), null, true)
		main.world.mil.build(Facility.Kind.AD_PATRIOT, city.center + Vector2i(-2, -2), main.world.country_by_id(city.country_id), null, true)
	
	main.cam.set_zoom_at(0.35, main.cam.view_size() * 0.5)
	main.cam.center_on(p_pos.lerp(e_pos, 0.5))
	await tree.create_timer(0.8).timeout
	_snap(main, "9_custom_map_world_war.png")
	
	# -------------------------------------------------------------
	# SHOT 10: DEVELOPER SANDBOX INTEL (Tactical Targeting & Telemetry)
	# -------------------------------------------------------------
	print("[ImpossibleShots] Staging Shot 10: Developer Sandbox Intel...")
	if not main.world.mil.facilities.is_empty():
		main.selected_fac = main.world.mil.facilities[0]
	main.cam.set_zoom_at(2.0, main.cam.view_size() * 0.5)
	main.cam.center_on(p_pos)
	await tree.create_timer(0.6).timeout
	_snap(main, "10_developer_sandbox_intel.png")
	
	print("[ImpossibleShots] All 5 impossible showcase screenshots captured successfully!")
	tree.quit()

func _snap(main: Node, filename: String) -> void:
	var vp: Viewport = main.get_viewport()
	var img: Image = vp.get_texture().get_image()
	var out_dir: String = "c:/Users/mxka/Documents/port/СКРИНШОТЫ_ДЛЯ_РЕБЯТ/"
	var out_path: String = out_dir + filename
	img.save_png(out_path)
	print("[ImpossibleShots] Saved: ", out_path)
