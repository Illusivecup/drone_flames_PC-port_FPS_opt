extends RefCounted

var mm_ref: Node = null
var bridge_pid: int = 0
var state_file_global: String = ""
var timer_node: Timer = null
var match_start_time: int = 0
var in_match: bool = false
var last_main: Node = null
var last_world: Node = null
var launch_time: int = 0
var custom_client_id: String = "1566515978806759500"

func init_mod(mm: Node) -> void:
	mm_ref = mm
	launch_time = int(Time.get_unix_time_from_system())
	match_start_time = launch_time

	# Read custom client_id from settings if configured
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		var cid = cfg.get_value("discord", "client_id", "")
		if String(cid).strip_edges() != "":
			custom_client_id = String(cid).strip_edges()

	# Resolve absolute path for state file
	state_file_global = ProjectSettings.globalize_path("user://discord_state.json")

	# Write initial menu state immediately
	_write_state(_build_menu_state())

	# Ensure bridge scripts exist in user:// and launch bridge
	_ensure_bridge_scripts()
	_launch_bridge()

	# Register game hooks
	if mm.has_method("register_hook"):
		mm.call("register_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("register_hook", "on_match_tick", Callable(self, "_on_match_tick"))

	# Create periodic timer attached to ModManager
	if mm and is_instance_valid(mm):
		timer_node = Timer.new()
		timer_node.wait_time = 2.0
		timer_node.autostart = true
		timer_node.timeout.connect(_on_timer_tick)
		mm.add_child(timer_node)

	print("[DiscordRPC] Mod initialized and bridge started.")

func cleanup_mod(mm: Node) -> void:
	# Signal shutdown to bridge
	var f = FileAccess.open("user://discord_state.json", FileAccess.WRITE)
	if f:
		f.store_string('{"shutdown": true}')
		f.close()

	if bridge_pid > 0:
		OS.kill(bridge_pid)
		bridge_pid = 0

	if timer_node != null and is_instance_valid(timer_node):
		timer_node.queue_free()
		timer_node = null

	if mm and mm.has_method("unregister_hook"):
		mm.call("unregister_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("unregister_hook", "on_match_tick", Callable(self, "_on_match_tick"))

	print("[DiscordRPC] Mod cleaned up.")

func _ensure_bridge_scripts() -> void:
	var base_folder: String = ""
	var scr = get_script()
	if scr:
		base_folder = scr.resource_path.get_base_dir()
	if base_folder == "":
		base_folder = "res://mods/discord_rpc"

	# Copy discord_bridge.py to user:// if accessible from base_folder
	var py_src = base_folder.path_join("discord_bridge.py")
	if FileAccess.file_exists(py_src):
		var src_file = FileAccess.open(py_src, FileAccess.READ)
		if src_file:
			var content = src_file.get_as_text()
			src_file.close()
			var dst_file = FileAccess.open("user://discord_bridge.py", FileAccess.WRITE)
			if dst_file:
				dst_file.store_string(content)
				dst_file.close()

	var ps_src = base_folder.path_join("discord_bridge.ps1")
	if FileAccess.file_exists(ps_src):
		var src_file = FileAccess.open(ps_src, FileAccess.READ)
		if src_file:
			var content = src_file.get_as_text()
			src_file.close()
			var dst_file = FileAccess.open("user://discord_bridge.ps1", FileAccess.WRITE)
			if dst_file:
				dst_file.store_string(content)
				dst_file.close()

func _launch_bridge() -> void:
	var py_bridge = ProjectSettings.globalize_path("user://discord_bridge.py")
	var ps_bridge = ProjectSettings.globalize_path("user://discord_bridge.ps1")
	var parent_pid_str = str(OS.get_process_id())

	# Python candidates to try
	var py_candidates: Array = [
		"pythonw",
		"python",
		"C:\\Users\\mxka\\AppData\\Local\\Programs\\Python\\Python314\\pythonw.exe",
		"C:\\Users\\mxka\\AppData\\Local\\Programs\\Python\\Python314\\python.exe"
	]

	for exe in py_candidates:
		var out_arr: Array = []
		var test_code = OS.execute(exe, ["--version"], out_arr, false)
		if test_code == 0 and FileAccess.file_exists("user://discord_bridge.py"):
			bridge_pid = OS.create_process(exe, [py_bridge, state_file_global, parent_pid_str])
			if bridge_pid > 0:
				print("[DiscordRPC] Launched Python bridge using '%s' (PID %d)" % [exe, bridge_pid])
				return

	# Fallback to PowerShell bridge
	if FileAccess.file_exists("user://discord_bridge.ps1"):
		bridge_pid = OS.create_process("powershell.exe", [
			"-NoProfile",
			"-WindowStyle", "Hidden",
			"-ExecutionPolicy", "Bypass",
			"-File", ps_bridge,
			state_file_global,
			parent_pid_str
		])
		if bridge_pid > 0:
			print("[DiscordRPC] Launched PowerShell bridge (PID %d)" % bridge_pid)
			return

	print("[DiscordRPC] Warning: Could not launch bridge process.")

func _find_main_and_world() -> void:
	if last_main == null or not is_instance_valid(last_main):
		if mm_ref != null and is_instance_valid(mm_ref):
			var tree = mm_ref.get_tree()
			if tree != null and tree.root != null:
				var m = tree.root.get_node_or_null("Main")
				if m != null:
					last_main = m
				else:
					for child in tree.root.get_children():
						if "world" in child and "menus" in child:
							last_main = child
							break
	if last_main != null and is_instance_valid(last_main):
		if "world" in last_main and last_main.world != null and is_instance_valid(last_main.world):
			last_world = last_main.world

func _check_in_match() -> bool:
	_find_main_and_world()
	if last_main == null or not is_instance_valid(last_main):
		return false

	# If Main indicates we are in the main menu, we are not playing
	if "in_menu" in last_main and bool(last_main.in_menu):
		return false

	# Check world and world data
	if last_world == null or not is_instance_valid(last_world):
		return false
	if not ("data" in last_world and last_world.data != null):
		return false
	if "w" in last_world.data and int(last_world.data.w) <= 0:
		return false

	return true

func _on_world_started(main: Node, world: Node) -> void:
	last_main = main
	last_world = world
	in_match = true
	match_start_time = int(Time.get_unix_time_from_system())
	_update_presence()

func _on_match_tick(main: Node, world: Node, _delta: float) -> void:
	last_main = main
	last_world = world
	in_match = true

func _on_timer_tick() -> void:
	var currently_playing: bool = _check_in_match()
	if currently_playing:
		if not in_match:
			in_match = true
			match_start_time = int(Time.get_unix_time_from_system())
	else:
		in_match = false

	_update_presence()

func _update_presence() -> void:
	var state_dict: Dictionary = {}
	if in_match and last_world != null and is_instance_valid(last_world):
		state_dict = _build_ingame_state()
	else:
		state_dict = _build_menu_state()
	_write_state(state_dict)

func _build_menu_state() -> Dictionary:
	var player_name = _get_player_name()
	var has_save: bool = Save.has_save() if ClassDB.class_exists("Save") or ResourceLoader.exists("res://game/save.gd") else false
	var state_txt = "Готово сохранение" if has_save else "Выбор режима игры"

	var res_dict = {
		"client_id": custom_client_id,
		"details": "В главном меню",
		"state": state_txt,
		"timestamps": {
			"start": launch_time
		},
		"assets": {
			"large_image": "https://raw.githubusercontent.com/makkaX2/DroneFlames-Mods/main/assets/droneflames_logo.png",
			"large_text": "DroneFlames (Reborn by Reborn Team)",
			"small_image": "https://raw.githubusercontent.com/makkaX2/DroneFlames-Mods/main/assets/profile_avatar.png",
			"small_text": "Профиль: %s" % player_name
		},
		"buttons": [
			{"label": "GitHub Проект", "url": "https://github.com/makkaX2/DroneFlames-PC-Port"}
		]
	}
	return res_dict

func _build_ingame_state() -> Dictionary:
	var player_name = _get_player_name()
	var world = last_world
	var world_w: int = 1024
	var world_h: int = 1024
	if world != null and "data" in world and world.data != null:
		if "w" in world.data: world_w = int(world.data.w)
		if "h" in world.data: world_h = int(world.data.h)

	# Map Name
	var map_name: String = "Обычная"
	var mt_idx: int = 0
	if world != null and "settings" in world and world.settings != null and "map_type" in world.settings:
		mt_idx = int(world.settings.map_type)
	
	var standard_names: Array = ["Обычная", "Архипелаг", "Острова", "Материки"]
	if mt_idx >= 0 and mt_idx < standard_names.size():
		map_name = standard_names[mt_idx]
	elif mm_ref != null and mm_ref.has_method("get_custom_map_types"):
		var custom_maps: Array = mm_ref.call("get_custom_map_types")
		var custom_idx = mt_idx - standard_names.size()
		if custom_idx >= 0 and custom_idx < custom_maps.size():
			map_name = String(custom_maps[custom_idx].get("name", "Особая карта"))
		else:
			map_name = "Особая карта"
	else:
		map_name = "Особая карта"

	# Player Country Stats
	var player_country: Country = null
	if world != null:
		if "player" in world and world.player != null and is_instance_valid(world.player):
			player_country = world.player
		elif "countries" in world and world.countries is Array:
			for c in world.countries:
				if c != null and is_instance_valid(c) and "is_player" in c and c.is_player:
					player_country = c
					break

	var cities_count: int = 0
	var wars_count: int = 0
	var treasury: int = 0
	var score: int = 0
	var country_name: String = "Моя страна"
	var capital_name: String = ""

	if player_country != null and is_instance_valid(player_country):
		if "city_ids" in player_country and player_country.city_ids != null:
			cities_count = player_country.city_ids.size()
		if "at_war" in player_country and player_country.at_war != null:
			wars_count = player_country.at_war.size()
		if "money" in player_country:
			treasury = int(player_country.money)
		if "score" in player_country:
			score = int(player_country.score)
		if "name" in player_country and String(player_country.name).strip_edges() != "":
			country_name = String(player_country.name).strip_edges()

		# Capital city name
		if "capital_id" in player_country and int(player_country.capital_id) >= 0:
			var cid = int(player_country.capital_id)
			if world != null and "cities" in world and world.cities is Array and cid < world.cities.size():
				var cap_obj = world.cities[cid]
				if cap_obj != null and is_instance_valid(cap_obj) and "name" in cap_obj:
					capital_name = String(cap_obj.name).strip_edges()

	if capital_name != "" and cities_count == 0:
		cities_count = 1

	# Units count
	var armies_count: int = 0
	if world != null and "army" in world and world.army != null and is_instance_valid(world.army):
		if "units" in world.army and world.army.units is Array:
			for u in world.army.units:
				if u != null and is_instance_valid(u) and "hp" in u and u.hp > 0:
					if player_country != null and "country_id" in u and u.country_id == player_country.id:
						armies_count += 1

	# Check if paused
	var is_paused: bool = false
	if last_main != null and is_instance_valid(last_main):
		if "_paused" in last_main and bool(last_main._paused):
			is_paused = true
		elif "menus" in last_main and last_main.menus != null and is_instance_valid(last_main.menus):
			if last_main.menus.has_method("is_open") and last_main.menus.is_open() and "current" in last_main.menus and last_main.menus.current == "pause":
				is_paused = true

	var cash_str = _format_cash(treasury)

	# Details string (max 128 chars)
	var details_str = "Мир: %s (%dx%d)" % [map_name, world_w, world_h]
	if capital_name != "":
		details_str = "Мир: %s • Столица: %s" % [map_name, capital_name]

	# State string (max 128 chars)
	var prefix = "[Пауза] " if is_paused else ""
	var state_str = prefix + "Городов: %d | Армий: %d | Войн: %d | Казна: %s" % [
		cities_count, armies_count, wars_count, cash_str
	]
	if cities_count == 0 and capital_name == "":
		state_str = prefix + "Основание столицы..."

	# Small text (hovering over avatar icon)
	var small_txt = "%s (%s) • Счёт: %d" % [country_name, player_name, score]
	if country_name == player_name:
		small_txt = "%s • Счёт: %d" % [player_name, score]

	return {
		"client_id": custom_client_id,
		"details": details_str.left(120),
		"state": state_str.left(120),
		"timestamps": {
			"start": match_start_time
		},
		"assets": {
			"large_image": "https://raw.githubusercontent.com/makkaX2/DroneFlames-Mods/main/assets/droneflames_logo.png",
			"large_text": "DroneFlames (Reborn by Reborn Team)",
			"small_image": "https://raw.githubusercontent.com/makkaX2/DroneFlames-Mods/main/assets/profile_avatar.png",
			"small_text": small_txt.left(120)
		},
		"buttons": [
			{"label": "GitHub Проект", "url": "https://github.com/makkaX2/DroneFlames-PC-Port"}
		]
	}

func _write_state(dict: Dictionary) -> void:
	var json_str = JSON.stringify(dict)
	var f = FileAccess.open("user://discord_state.json", FileAccess.WRITE)
	if f:
		f.store_string(json_str)
		f.close()

func _get_player_name() -> String:
	if last_main != null and is_instance_valid(last_main):
		if "world" in last_main and last_main.world != null and is_instance_valid(last_main.world):
			if "player" in last_main.world and last_main.world.player != null and is_instance_valid(last_main.world.player):
				if last_main.world.player.name != "":
					return last_main.world.player.name
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		var n = cfg.get_value("prefs", "my_name", "")
		if String(n).strip_edges() != "":
			return String(n)
	return "Reborn Team & @CryptoAngelazaz"

func _format_cash(val: int) -> String:
	if abs(val) >= 1000000:
		return "%.1fM" % (float(val) / 1000000.0)
	if abs(val) >= 1000:
		return "%.1fK" % (float(val) / 1000.0)
	return str(val)
