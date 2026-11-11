extends RefCounted

func run(main: Node) -> void:
	var tree: SceneTree = main.get_tree()
	for i in 300:
		if main.menus.current == "main" or main.menus.current == "graphics_first":
			break
		await tree.create_timer(0.1).timeout
	if main.menus.current == "graphics_first":
		var first_button: Button = _find_button(main.menus, "МАКС. ПРОИЗВОДИТЕЛЬНОСТЬ")
		if first_button == null:
			push_error("[GFX-TEST] first-run choice missing")
			tree.quit(1)
			return
		first_button.pressed.emit()
		if not GameConfig.graphics_chosen or GameConfig.performance_mode != 3:
			push_error("[GFX-TEST] first-run choice failed")
			tree.quit(1)
			return
	main.menus.show_settings_sub("gfx")
	await tree.process_frame
	if main.menus.current != "settings_gfx":
		push_error("[GFX-TEST] graphics menu failed")
		tree.quit(1)
		return
	var profile_label: Label = _find_label(main.menus, "ПРОФИЛЬ ГРАФИКИ")
	if profile_label == null:
		push_error("[GFX-TEST] profile control missing")
		tree.quit(1)
		return
	var buttons: Array[Button] = []
	for child in profile_label.get_parent().get_children():
		if child is Button:
			buttons.append(child)
	if buttons.size() != 2:
		push_error("[GFX-TEST] profile arrows missing")
		tree.quit(1)
		return
	GameConfig.performance_mode = 1
	buttons[0].pressed.emit()
	if GameConfig.performance_mode != 0 or GameConfig.clouds or GameConfig.fx_level != 0:
		push_error("[GFX-TEST] performance preset did not apply")
		tree.quit(1)
		return
	await tree.process_frame
	for i in 4:
		GameConfig.performance_mode = i
		Save.save_prefs()
		GameConfig.performance_mode = (i + 1) % 4
		Save.load_prefs()
		if GameConfig.performance_mode != i:
			push_error("[GFX-TEST] profile persistence failed")
			tree.quit(1)
			return
	GameConfig.fps_i = 1
	GameConfig.power_save = false
	GameConfig.pause_fps_limit = false
	Save.fps_idle = true
	Save.apply_power_save()
	if Engine.max_fps != 60:
		push_error("[GFX-TEST] pause fps unexpectedly capped")
		tree.quit(1)
		return
	GameConfig.pause_fps_limit = true
	Save.apply_power_save()
	if Engine.max_fps != 30:
		push_error("[GFX-TEST] optional pause fps cap failed")
		tree.quit(1)
		return
	print("[GFX-TEST] PASS: first launch, four profiles, persistence and pause FPS")
	tree.quit(0)

func _find_label(node: Node, value: String) -> Label:
	if node is Label and node.text == value:
		return node
	for child in node.get_children():
		var result: Label = _find_label(child, value)
		if result != null:
			return result
	return null

func _find_button(node: Node, value: String) -> Button:
	if node is Button and node.text == value:
		return node
	for child in node.get_children():
		var result: Button = _find_button(child, value)
		if result != null:
			return result
	return null
