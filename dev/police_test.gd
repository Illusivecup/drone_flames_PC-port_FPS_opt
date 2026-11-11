extends RefCounted

func fail(main: Node, reason: String) -> void:
	push_error("[POLICE-TEST] " + reason)
	main.get_tree().quit(1)

func run(main: Node) -> void:
	var tree: SceneTree = main.get_tree()
	for i: int in 300:
		if main.menus.current == "main":
			break
		await tree.create_timer(0.1).timeout
	if main.menus.current != "main":
		fail(main, "menu did not load")
		return
	var gw: GameWorld = main.world
	var owner: Country = gw.create_country(true)
	var enemy: Country = gw.create_country(false)
	var center: Vector2i = Vector2i(256, 256)
	for y: int in range(center.y - 30, center.y + 35):
		for x: int in range(center.x - 30, center.x + 35):
			gw.data.set_owner_id(x, y, owner.id)
			gw.data.set_biome(x, y, Biome.GRASS)
	for y: int in range(center.y - 5, center.y + 7):
		for x: int in range(center.x - 5, center.x + 7):
			gw.data.clear_flag(x, y, WorldData.F_OCCUPIED | WorldData.F_ROAD | WorldData.F_BRIDGE)
	gw.econ.build_nav()
	var station: Facility = gw.mil.build(Facility.Kind.POLICE_STATION, center, owner, null, true)
	if station == null or not gw.mil.alive(station):
		fail(main, "station placement failed")
		return
	main.selected_fac = station
	main.hud.show_facility(station, gw.mil, owner)
	main._on_action("police_patrol")
	if gw.army.police_count(station) != 4 or not station.police_patrol:
		fail(main, "patrol did not start with four cars")
		return
	gw.army._police_patrol_tick()
	var car: Unit = null
	for unit: Unit in gw.army.units:
		if unit.type == Unit.Type.POLICE and unit.home == station:
			car = unit
			if not unit.path.is_empty():
				break
	if car == null or car.path.is_empty():
		fail(main, "patrol has no route")
		return
	var attacker: Unit = Unit.new()
	attacker.id = gw.army._next_id
	gw.army._next_id += 1
	attacker.country_id = enemy.id
	attacker.type = Unit.Type.INFANTRY
	attacker.pos = car.pos + Vector2(12, 0)
	gw.army.units.append(attacker)
	owner.at_war[enemy.id] = true
	gw.army._build_grid()
	gw.army._acquire(car)
	if car.target != attacker:
		fail(main, "police did not detect hostile unit")
		return
	car.heading = 0.0
	car.fire_cd = 0.0
	for i: int in 30:
		gw.game_time += 0.2
		gw.army._fight(car, attacker, 1.0)
		car.fire_cd = 0.0
		if attacker.hp < 100.0:
			break
	if attacker.hp >= 100.0:
		fail(main, "police did not damage attacker")
		return
	main._on_action("police_patrol")
	main._on_action("police_patrol")
	if gw.army.police_count(station) != 4:
		fail(main, "patrol exceeded four cars")
		return
	if not bool(Save.dump(station).get("police_patrol", false)):
		fail(main, "patrol state is not saved")
		return
	print("[POLICE-TEST] PASS: native placement, four cars, route, hostile detection, damage, cap, saved patrol state")
	if OS.has_environment("DF_POLICE_VISUAL"):
		main.in_menu = false
		main.menus.close()
		main.hud.visible = true
		main._paused = true
		main.cam.center_on(station.center_px())
		main.cam.set_zoom_at(2.0, main.cam.view_size() * 0.5)
		main.hud.show_facility(station, gw.mil, owner)
		return
	tree.quit(0)
