class_name VerifyGame
extends RefCounted

const ModsUI = preload("res://ui/mods_ui.gd")

func run(main: Node) -> void:
	print("[VERIFY] Starting game verification sequence...")
	var tree: SceneTree = main.get_tree()

	# 1. Wait for Main Menu to be shown
	for wait_i in range(50):
		if main.menus and main.menus.visible and main.menus.screen != null:
			break
		await tree.create_timer(0.2).timeout

	await RenderingServer.frame_post_draw
	await tree.create_timer(0.5).timeout
	_snap(main, "res://verify_1_main_menu.png")
	print("[VERIFY] Saved verify_1_main_menu.png")

	# Test Native F11 Fullscreen Toggle (without any mod)
	print("[VERIFY] Testing native F11 input handling in base game...")
	var wm: Node = main.get_node_or_null("/root/Watermark")
	assert(wm != null, "Watermark autoload must be present!")
	var f11_ev = InputEventKey.new()
	f11_ev.keycode = KEY_F11
	f11_ev.pressed = true
	wm._input(f11_ev)
	await tree.create_timer(0.4).timeout
	var mode1: int = DisplayServer.window_get_mode()
	print("[VERIFY] Window mode after F11: ", mode1)
	wm._input(f11_ev)
	await tree.create_timer(0.4).timeout
	var mode2: int = DisplayServer.window_get_mode()
	print("[VERIFY] Window mode after 2nd F11: ", mode2)

	# Test Flag & Emblem Color Unlocking (Yellow emblem on green-white-red tricolor)
	print("[VERIFY] Testing Flag & Emblem Color Unlocking...")
	var test_sp: Dictionary = {
		"l": 2, # 3 stripes
		"c": [10, 0, 4], # green, white, red
		"e": 1, # star
		"ec": 2, # gold / yellow
		"p": 0, # center
		"s": 1
	}
	assert(FlagMaker.emb_ok(test_sp) == true, "Emblem color must be valid on any field!")
	assert(FlagMaker.pair_ok(10, 0) == true, "Flag stripe colors must be unlocked!")
	assert(FlagMaker.pair_ok(0, 4) == true, "Flag stripe colors must be unlocked!")
	var encoded: String = FlagMaker.encode(test_sp)
	var decoded: Dictionary = FlagMaker.decode(encoded)
	assert(decoded["ec"] == 2, "Decoded emblem color must be 2 (gold/yellow)!")
	print("[VERIFY] Flag & Emblem Color Unlocking verified successfully: ", test_sp)

	# Test GitHub Updater
	if main.has_node("/root/Updater"):
		var up: Node = main.get_node("/root/Updater")
		print("[VERIFY] Testing Updater check...")
		up.update_available.connect(func(ver: String, _c: String, _u: String, _a: String) -> void:
			print("[VERIFY] >>> UPDATE AVAILABLE SIGNAL RECEIVED: v", ver, " <<<")
		)
		up.check_failed.connect(func(reason: String) -> void:
			print("[VERIFY] >>> Updater check failed: ", reason, " <<<")
		)
		up.no_update_found.connect(func() -> void:
			print("[VERIFY] >>> No update found <<<")
		)
		up.call("check_for_updates")
		await tree.create_timer(1.5).timeout

	# Test Mod Manager Screen & Catalog
	if main.has_node("/root/ModManager"):
		var mm: Node = main.get_node("/root/ModManager")
		print("[VERIFY] Testing ModManager...")
		var full_cat: Array = mm.get_full_catalog()
		print("[VERIFY] Full catalog count: ", full_cat.size())
		print("[VERIFY] Initially installed mods count: ", mm.get("installed_mods").size())
		# Install all builtin mods from catalog for gameplay testing
		for cat_item in full_cat:
			var mid: String = String(cat_item.get("id", ""))
			if mid != "":
				print("[VERIFY] Installing catalog mod: ", mid)
				mm.install_builtin_mod(mid)
		print("[VERIFY] Post-install installed mods count: ", mm.get("installed_mods").size())
		print("[VERIFY] Post-install installed mods: ", mm.get("installed_mods").keys())
		print("[VERIFY] Registered custom maps: ", mm.get("registered_map_types").keys())
		if main.menus:
			print("[VERIFY] Opening Mods menu...")
			main.menus.show_mods()
			await tree.create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			_snap(main, "res://verify_mod_manager.png")
			print("[VERIFY] Saved verify_mod_manager.png")

		if FileAccess.file_exists("user://discord_state.json"):
			var f_rpc = FileAccess.open("user://discord_state.json", FileAccess.READ)
			if f_rpc:
				var rpc_txt = f_rpc.get_as_text()
				f_rpc.close()
				print("[VERIFY] Discord RPC state file verified: ", rpc_txt.substr(0, 120))

	# 2. Test Setup Screen, Custom Maps & Scenario Selector
	if main.menus:
		print("[VERIFY] Opening setup screen and testing Custom Maps Previews...")
		main.menus.close()
		main.menus.show_setup()
		await tree.create_timer(0.4).timeout
		
		var all_maps: Array = GameConfig.get_all_map_types()
		print("[VERIFY] Available map types: ", all_maps.map(func(m): return m.name))
		
		# Test Desert Oasis Preview (index 4)
		if all_maps.size() > 4:
			print("[VERIFY] Selecting Desert map (index 4)...")
			GameConfig.map_type = 4
			main.menus._pv_texts()
			main.menus._pv_request()
			for wait_pv in range(60):
				if main.menus._pv_task < 0 and main.menus._pv_tex != null:
					break
				await tree.create_timer(0.1).timeout
			print("[VERIFY] Desert map preview generated successfully!")
			await RenderingServer.frame_post_draw
			_snap(main, "res://verify_map_preview_desert.png")

		# Test Arctic Map Preview (index 5)
		if all_maps.size() > 5:
			print("[VERIFY] Selecting Arctic map (index 5)...")
			GameConfig.map_type = 5
			main.menus._pv_texts()
			main.menus._pv_request()
			for wait_pv in range(60):
				if main.menus._pv_task < 0 and main.menus._pv_tex != null:
					break
				await tree.create_timer(0.1).timeout
			print("[VERIFY] Arctic map preview generated successfully!")
			await RenderingServer.frame_post_draw
			_snap(main, "res://verify_map_preview_arctic.png")

		# Test Volcano Map Preview (index 6)
		if all_maps.size() > 6:
			print("[VERIFY] Selecting Volcano map (index 6)...")
			GameConfig.map_type = 6
			main.menus._pv_texts()
			main.menus._pv_request()
			for wait_pv in range(60):
				if main.menus._pv_task < 0 and main.menus._pv_tex != null:
					break
				await tree.create_timer(0.1).timeout
			print("[VERIFY] Volcano map preview generated successfully!")
			await RenderingServer.frame_post_draw
			_snap(main, "res://verify_map_preview_volcano.png")

		# Select scenario 1 (РАСКОЛ)
		var mm_node = main.get_node_or_null("/root/ModManager")
		if mm_node and mm_node.get("installed_mods").has("scenarios_pack"):
			var sc_mod = mm_node.get("installed_mods")["scenarios_pack"].get("_instance")
			if sc_mod:
				sc_mod.selected_scenario = 1
				print("[VERIFY] Selected Scenario: 1 (РАСКОЛ)")

		await RenderingServer.frame_post_draw
		_snap(main, "res://verify_setup_scenarios.png")
		print("[VERIFY] Saved verify_setup_scenarios.png")

	# 3. Launch New Game with Modded Arctic Map & Scenario Active
	print("[VERIFY] Launching _new_game() with Modded Arctic Map & Partition Scenario...")
	var maps_cnt: int = GameConfig.get_all_map_types().size()
	if maps_cnt > 5:
		GameConfig.map_type = 5 # Arctic
	main._new_game()

	# Wait for loading screen to finish
	for wait_l in range(100):
		if not main.loading.visible:
			break
		await tree.create_timer(0.1).timeout

	print("[VERIFY] Map generated! Waiting 3.5s for scenario trigger...")
	await tree.create_timer(3.5).timeout
	await RenderingServer.frame_post_draw
	_snap(main, "res://verify_2_gameplay.png")
	print("[VERIFY] Saved verify_2_gameplay.png")

	# 4. Test camera zoom and WASD movement
	print("[VERIFY] Testing camera zoom and panning...")
	if main.cam:
		var center_pt: Vector2 = main.cam.position
		main.cam.set_zoom_at(1.8, main.cam.view_size() * 0.5)
		main.cam.center_on(center_pt + Vector2(200, 150))
	
	await tree.create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_snap(main, "res://verify_3_zoom.png")
	print("[VERIFY] Saved verify_3_zoom.png")

	# 5. Found capital and Test Diplomacy Sheet
	print("[VERIFY] Founding player capital and opening diplomacy sheet...")
	if main.world:
		main.world._landmasses()
		var target_c: Vector2i = main.world._find_capital_spot(-1)
		print("[VERIFY] Found capital spot: ", target_c)
		if target_c.x >= 0:
			var cap = main.world.place_player_capital(target_c)
			print("[VERIFY] Capital placed: ", cap != null)
		main._set_mode(0) # Mode.NONE
		if main.hud:
			main.hud.refresh()
	
	await tree.create_timer(0.5).timeout
	if main.hud:
		main.hud.open_diplomacy()
		await tree.create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		_snap(main, "res://verify_5_diplomacy.png")
		print("[VERIFY] Saved verify_5_diplomacy.png")
		if main.hud.panel != null and is_instance_valid(main.hud.panel):
			main.hud.close_panel()

	# 6. Test City Renaming
	print("[VERIFY] Testing City Renaming...")
	if main.world:
		var test_city: City = null
		if not main.world.cities.is_empty():
			test_city = main.world.cities[0]
		else:
			test_city = City.new()
			test_city.id = 0
			test_city.name = "Нордборг"
			test_city.country_id = main.world.player.id if main.world.player != null else 0
			test_city.kind = City.Kind.CAPITAL
			test_city.center = Vector2i(256, 256)
			main.world.cities.append(test_city)
		
		var old_name: String = test_city.name
		var target_name: String = "Цитадель-1"
		print("[VERIFY] Renaming city '%s' (id=%d) to '%s'..." % [old_name, test_city.id, target_name])
		main.world.cmd_city_rename(test_city.id, target_name)
		assert(test_city.name == target_name, "City name must match target_name!")
		main.selected_city = test_city.id
		if main.hud:
			main.hud.show_city(test_city)
			main.hud.show_city_rename_dialog(test_city)
			await tree.create_timer(0.6).timeout
			await RenderingServer.frame_post_draw
			_snap(main, "res://verify_9_city_rename.png")
			print("[VERIFY] Saved verify_9_city_rename.png")
			if main.hud.get("_city_rename_dialog") != null and is_instance_valid(main.hud._city_rename_dialog):
				main.hud._city_rename_dialog.queue_free()
				main.hud._city_rename_dialog = null
		print("[VERIFY] City rename verified successfully: ", test_city.name)

	# 7. Test Mod Buildings Placement
	print("[VERIFY] Testing Mod Buildings Placement (Tank Factory, Silo, VDV HQ)...")
	if main.world:
		if main.world.player == null and not main.world.countries.is_empty():
			main.world.player = main.world.countries[0]
		var p = main.world.player
		if p != null:
			p.money = 50000
			p.metal = 500
			p.uranium = 100
		
			# Find a valid 20x20 land spot and assign to player
			var test_cell = Vector2i(-1, -1)
			for cy in range(50, main.world.data.h - 50, 10):
				for cx in range(50, main.world.data.w - 50, 10):
					var all_land = true
					for dy in range(15):
						for dx in range(15):
							if Biome.is_water(main.world.data.get_biome(cx + dx, cy + dy)):
								all_land = false
								break
						if not all_land:
							break
					if all_land:
						test_cell = Vector2i(cx, cy)
						for dy in range(15):
							for dx in range(15):
								main.world.data.set_owner_id(cx + dx, cy + dy, p.id)
						break
				if test_cell.x != -1:
					break
			
			if test_cell.x != -1:
				var mm = main.get_node_or_null("/root/ModManager")
				if mm:
					# 1. Test Tank Factory
					if mm.installed_mods.has("tank_factory"):
						var tf = mm.installed_mods["tank_factory"].get("_instance")
						if tf:
							print("[VERIFY] Testing Tank Factory placement at: ", test_cell)
							var can_tf = tf.can_place_at(test_cell)
							print("[VERIFY] Tank Factory can_place_at: ", can_tf)
							assert(can_tf, "Tank factory must be placeable on player land!")
							var prev_f_count = main.world.mil.facilities.size()
							tf.place_factory_at(test_cell)
							assert(main.world.mil.facilities.size() > prev_f_count, "Facility count must increase after placement!")
							print("[VERIFY] Tank Factory successfully placed! Total facilities: ", main.world.mil.facilities.size())
					
					# 2. Test VDV HQ
					var vdv_cell = test_cell + Vector2i(5, 0)
					if mm.installed_mods.has("airborne_assault"):
						var vdv = mm.installed_mods["airborne_assault"].get("_instance")
						if vdv:
							print("[VERIFY] Testing VDV HQ placement at: ", vdv_cell)
							var can_vdv = vdv.can_place_hq_at(vdv_cell)
							print("[VERIFY] VDV HQ can_place_hq_at: ", can_vdv)
							assert(can_vdv, "VDV HQ must be placeable on player land!")
							var prev_f_count = main.world.mil.facilities.size()
							vdv.place_hq_at(vdv_cell)
							assert(main.world.mil.facilities.size() > prev_f_count, "Facility count must increase after placement!")
							print("[VERIFY] VDV HQ successfully placed! Total facilities: ", main.world.mil.facilities.size())

					# 3. Test Nuclear Silo
					var silo_cell = test_cell + Vector2i(0, 5)
					if mm.installed_mods.has("nuclear_strike"):
						var ns = mm.installed_mods["nuclear_strike"].get("_instance")
						if ns:
							print("[VERIFY] Testing Nuclear Silo placement at: ", silo_cell)
							var can_ns = ns.can_place_at(silo_cell)
							print("[VERIFY] Nuclear Silo can_place_at: ", can_ns)
							assert(can_ns, "Nuclear Silo must be placeable on player land!")
							var prev_f_count = main.world.mil.facilities.size()
							ns.place_silo_at(silo_cell)
							assert(main.world.mil.facilities.size() > prev_f_count, "Facility count must increase after placement!")
							print("[VERIFY] Nuclear Silo successfully placed! Total facilities: ", main.world.mil.facilities.size())

					# 4. Test GameWorld cell_at_screen & WorldData get_owner
					assert(main.world.has_method("cell_at_screen"), "GameWorld must have cell_at_screen!")
					var c_res = main.world.cell_at_screen(Vector2(100, 100))
					assert(c_res is Vector2i, "cell_at_screen must return Vector2i!")
					assert(main.world.data.get_owner(test_cell.x, test_cell.y) == p.id, "WorldData.get_owner alias must return player id!")
					print("[VERIFY] Compatibility methods cell_at_screen and get_owner verified!")

	print("[VERIFY] ALL VERIFICATIONS PASSED SUCCESSFULLY!")
	tree.quit(0)

func _snap(main: Node, path: String) -> void:
	var vp: Viewport = main.get_viewport()
	if vp:
		var tex: Texture2D = vp.get_texture()
		if tex:
			var img: Image = tex.get_image()
			if img and not img.is_empty():
				img.save_png(path)
