extends RefCounted


func fail(main: Node, message: String) -> void:
	push_error("[LOCAL-TEST] " + message)
	main.get_tree().quit(1)


func run(main: Node) -> void:
	var tree: SceneTree = main.get_tree()
	for i: int in 300:
		if main.menus.current == "main":
			break
		await tree.create_timer(0.1).timeout
	if main.menus.current != "main":
		fail(main, "main menu did not open")
		return
	var service: Node = tree.root.get_node_or_null("LocalWorkshop")
	if service == null or not service.maps.is_empty():
		fail(main, "test profile must be empty")
		return
	await tree.create_timer(0.5).timeout
	var initial_camera: Vector2 = main.cam.position
	await tree.create_timer(0.5).timeout
	if initial_camera.distance_to(main.cam.position) > 0.01:
		fail(main, "camera moved by itself in main menu")
		return
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_SPACE
	if not KeybindManager.is_event_match(ev, "pause") or KeybindManager.is_event_match(ev, "action_center"):
		fail(main, "space key conflict")
		return
	ev.keycode = KEY_TAB
	if KeybindManager.is_event_match(ev, "speed_next") or not KeybindManager.is_event_match(ev, "top_world"):
		fail(main, "tab key conflict")
		return
	main.menus.show_mods()
	main.menus.show_local_workshop()
	await tree.process_frame
	var name_field: LineEdit = main.menus.find_child("WorkshopMapName", true, false) as LineEdit
	var terrain: OptionButton = main.menus.find_child("WorkshopTerrain", true, false) as OptionButton
	var land: SpinBox = main.menus.find_child("WorkshopLand", true, false) as SpinBox
	var save: Button = main.menus.find_child("WorkshopSave", true, false) as Button
	if name_field == null or terrain == null or land == null or save == null:
		fail(main, "workshop controls not found")
		return
	name_field.text = "Тестовая карта"
	terrain.select(1)
	land.value = 70
	save.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	if service.maps.size() != 1:
		fail(main, "creating map through UI failed")
		return
	var map_id: String = String(service.maps[0].id)
	if not tree.root.get_node("ModManager").registered_map_types.has(map_id):
		fail(main, "created map is not registered")
		return
	service._load_maps()
	service._refresh_maps()
	if service.get_map(map_id).is_empty():
		fail(main, "map not persisted")
		return
	var all_maps: Array = GameConfig.get_all_map_types()
	if all_maps.size() != 5 or String(all_maps[4].name) != "Тестовая карта":
		fail(main, "map missing from new game options")
		return
	GameConfig.map_type = 4
	var settings: WorldSettings = WorldSettings.new()
	settings.size = 256
	settings.world_seed = 12345
	GameConfig.apply_map(settings)
	if settings.land_percent != 70:
		fail(main, "land percentage was not applied")
		return
	var world: WorldData = WorldGen.generate(settings)
	var land_cells: int = 0
	var sand_cells: int = 0
	for cell: int in world.biome:
		if cell > Biome.RIVER:
			land_cells += 1
		if cell == Biome.SAND:
			sand_cells += 1
	if land_cells == 0 or float(sand_cells) / float(land_cells) < 0.5:
		fail(main, "desert generation did not run")
		return
	main.menus.show_local_workshop()
	var edit: Button = main.menus.find_child("WorkshopEdit_" + map_id, true, false) as Button
	if edit == null:
		fail(main, "edit button missing")
		return
	edit.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	name_field = main.menus.find_child("WorkshopMapName", true, false) as LineEdit
	save = main.menus.find_child("WorkshopSave", true, false) as Button
	if name_field == null or save == null or name_field.text != "Тестовая карта":
		fail(main, "editing did not load saved values")
		return
	name_field.text = "Карта изменена"
	save.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	if String(service.get_map(map_id).get("name", "")) != "Карта изменена":
		fail(main, "editing did not save")
		return
	var remove: Button = main.menus.find_child("WorkshopRemove_" + map_id, true, false) as Button
	if remove == null:
		fail(main, "remove button missing")
		return
	remove.pressed.emit()
	if service.maps.size() != 1:
		fail(main, "delete needs confirmation")
		return
	remove.pressed.emit()
	await tree.process_frame
	if not service.maps.is_empty() or tree.root.get_node("ModManager").registered_map_types.has(map_id):
		fail(main, "delete failed")
		return
	print("[LOCAL-TEST] PASS: controls, stationary menu camera, UI create/edit/delete, persistence, map registration and desert generation")
	tree.quit(0)
