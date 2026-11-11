class_name AirborneDemo
extends RefCounted

const ARTIFACT_DIR: String = "C:/Users/mxka/.gemini/antigravity/brain/e1148530-9e66-40af-8e51-e48ae98b86bf/"
const LOCAL_DIR: String = "C:/Users/mxka/Documents/GitHub/DroneFlames-PC-Port/screenshots/"

func run(main: Node, _arg: String = "") -> void:
	print("[AirborneDemo] Starting automated airborne assault demonstration (Building-Based Redesign)...")
	var tree: SceneTree = main.get_tree()

	DirAccess.make_dir_recursive_absolute(LOCAL_DIR)
	DirAccess.make_dir_recursive_absolute(ARTIFACT_DIR)

	await tree.create_timer(0.6).timeout

	# 1. Capture Mods screen
	print("[AirborneDemo] Staging Shot 1: Mods screen...")
	if main.menus:
		main.menus.show_mods()
		await tree.create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		_snap(main, "01_mods_menu.png")
		main.menus.close()

	# 2. Load game save
	print("[AirborneDemo] Loading game world...")
	Save.want = [1, ""]
	var ok: bool = await Save.load_game(main)
	print("[AirborneDemo] Save load result: ", ok)

	for wait_step in range(40):
		if main.world != null and not main.world.countries.is_empty() and not main.world.cities.is_empty():
			break
		await tree.create_timer(0.2).timeout

	var world: GameWorld = main.world
	var player: Country = null
	for c: Country in world.countries:
		if c.is_player:
			player = c
			break
	if player == null and not world.countries.is_empty():
		player = world.countries[0]

	player.money = 250000 # Ample funds

	# Find player capital/city
	var p_pos: Vector2 = Vector2(800, 800)
	var cap_cell: Vector2i = Vector2i(200, 200)
	for city: City in world.cities:
		if city.country_id == player.id:
			p_pos = Vector2(city.center * GameWorld.CELL)
			cap_cell = city.center
			break

	# Ensure AirborneAssaultMod is initialized
	var mm: Node = main.get_node_or_null("/root/ModManager")
	var airborne_mod: RefCounted = null
	if mm != null:
		if not mm.get("enabled_mod_ids").has("airborne_assault"):
			mm.call("toggle_mod", "airborne_assault", true)
		if mm.get("installed_mods").has("airborne_assault"):
			airborne_mod = mm.get("installed_mods")["airborne_assault"].get("_instance")

	if airborne_mod != null and airborne_mod.overlay_node == null:
		airborne_mod._on_world_started(main, world)

	# Switch to Tab 2 (УДАР)
	if main.hud != null:
		main.hud.select_page(2)
		airborne_mod._inject_hud_button()

	main.cam.set_zoom_at(1.3, main.cam.view_size() * 0.5)
	main.cam.center_on(p_pos)
	await tree.create_timer(0.6).timeout
	await RenderingServer.frame_post_draw

	# 2. Shot 2: In-Game HUD Tab 2 with [ БАЗА ВДВ ] button
	print("[AirborneDemo] Staging Shot 2: In-game HUD Tab with [ БАЗА ВДВ ] button...")
	_snap(main, "02_hud_airborne_base_button.png")

	# 3. Shot 3: Base Placement Ghost Preview
	print("[AirborneDemo] Staging Shot 3: Base Placement Ghost Preview...")
	var place_cell = cap_cell + Vector2i(6, -4)
	if airborne_mod != null:
		airborne_mod.start_base_placement()
		airborne_mod.hover_cell = place_cell
		if airborne_mod.overlay_node != null:
			airborne_mod.overlay_node.queue_redraw()
	await tree.create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	_snap(main, "03_base_placement_ghost.png")

	# 4. Shot 4: Built Airborne Base on Map
	print("[AirborneDemo] Staging Shot 4: Built Airborne Base on Map...")
	var base_fac: Facility = null
	if airborne_mod != null:
		airborne_mod.try_place_base(place_cell)
		if not airborne_mod.bases.is_empty():
			base_fac = airborne_mod.bases[airborne_mod.bases.size() - 1]
	await tree.create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	_snap(main, "04_built_airborne_base_on_map.png")

	# 5. Shot 5: Base Selected -> Native Bottom Card
	print("[AirborneDemo] Staging Shot 5: Base Selected -> Native Bottom Card...")
	if main != null and base_fac != null:
		main.selected_fac = base_fac
		airborne_mod._update_base_card(base_fac)
	await tree.create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	_snap(main, "05_base_selected_bottom_card.png")

	# 6. Shot 6: Mi-8 Targeting Reticle from Base
	print("[AirborneDemo] Staging Shot 6: Mi-8 Targeting Reticle from Base...")
	var heli_target: Vector2 = p_pos + Vector2(170.0, -110.0)
	if world.econ != null and world.econ.has_method("land_point"):
		heli_target = world.econ.land_point(heli_target, 8)

	if airborne_mod != null and base_fac != null:
		airborne_mod.start_targeting(1, base_fac)
		airborne_mod.target_hover_pos = heli_target
		if airborne_mod.overlay_node != null:
			airborne_mod.overlay_node.queue_redraw()

	main.cam.center_on(p_pos.lerp(heli_target, 0.45))
	await tree.create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	_snap(main, "06_heli_targeting_reticle.png")

	# 7. Shot 7: Mi-8 Takeoff and In-Flight from Base
	print("[AirborneDemo] Staging Shot 7: Mi-8 In-flight from base...")
	if airborne_mod != null and base_fac != null:
		airborne_mod.try_launch_assault(1, base_fac, heli_target)

	await tree.create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	_snap(main, "07_heli_in_flight.png")

	# 8. Shot 8: Hover & Fast-Rope Insertion
	print("[AirborneDemo] Staging Shot 8: Hover & fast-rope deployment...")
	for step in range(50):
		if airborne_mod != null and not airborne_mod.active_ops.is_empty():
			if airborne_mod.active_ops[0].get("phase") == "hover_drop":
				break
		await tree.create_timer(0.1).timeout

	main.cam.center_on(heli_target)
	await tree.create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	_snap(main, "08_heli_fastrope_insertion.png")

	# 9. Shot 9: Il-76 Mass Parachute Drop
	print("[AirborneDemo] Staging Shot 9: Il-76 Parachute Drop (BMD + Paratroopers)...")
	var plane_target: Vector2 = p_pos + Vector2(-180.0, 120.0)
	if world.econ != null and world.econ.has_method("land_point"):
		plane_target = world.econ.land_point(plane_target, 8)

	if airborne_mod != null and base_fac != null:
		base_fac.set_meta("cooldown_left", 0.0)
		airborne_mod.try_launch_assault(2, base_fac, plane_target)

	for step in range(50):
		if airborne_mod != null and not airborne_mod.active_ops.is_empty():
			var last_op = airborne_mod.active_ops[airborne_mod.active_ops.size() - 1]
			if last_op.get("cargo_dropped", false):
				break
		await tree.create_timer(0.1).timeout

	main.cam.center_on(plane_target)
	await tree.create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_snap(main, "09_plane_parachute_drop.png")

	# 10. Shot 10: Bridgehead Secured with Landed Armor & Troops
	print("[AirborneDemo] Staging Shot 10: Paratroopers & BMD on ground securing bridgehead...")
	await tree.create_timer(1.8).timeout
	await RenderingServer.frame_post_draw
	_snap(main, "10_airborne_bridgehead_secured.png")

	print("[AirborneDemo] SUCCESS: ALL 10 SCREENSHOTS CAPTURED!")
	await tree.create_timer(1.0).timeout
	tree.quit(0)

func _snap(main: Node, filename: String) -> void:
	var vp: Viewport = main.get_viewport()
	if vp:
		var tex: Texture2D = vp.get_texture()
		if tex:
			var img: Image = tex.get_image()
			if img and not img.is_empty():
				var p1: String = LOCAL_DIR + filename
				var p2: String = ARTIFACT_DIR + filename
				img.save_png(p1)
				img.save_png(p2)
				print("[AirborneDemo] Saved: ", filename)
