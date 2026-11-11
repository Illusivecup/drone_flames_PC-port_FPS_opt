extends SceneTree

func _init() -> void:
	print("========================================")
	print("[TEST] Verifying Title & Icon Configuration")
	print("========================================")

	# 1. Verify project.godot settings
	var app_name: String = ProjectSettings.get_setting("application/config/name")
	print("application/config/name: ", app_name)
	assert(app_name.contains("v0.33.5.2"), "config/name must contain v0.33.5.2!")
	assert(not app_name.to_lower().contains("debug"), "config/name must NOT contain debug!")

	var icon_setting: String = ProjectSettings.get_setting("application/config/icon")
	print("application/config/icon: ", icon_setting)
	assert(icon_setting == "res://icon.png", "icon setting must point to res://icon.png!")

	var native_icon: String = ProjectSettings.get_setting("application/config/windows_native_icon")
	print("application/config/windows_native_icon: ", native_icon)
	assert(native_icon == "res://app_icon.ico", "windows_native_icon must point to res://app_icon.ico!")

	# 2. Verify watermark.gd logic
	var wm_script = load("res://watermark.gd")
	var wm = wm_script.new()
	var ver: String = wm._get_game_version()
	print("Game version from watermark: ", ver)
	assert(ver == "v0.33.5.2", "Game version must be v0.33.5.2!")

	wm._init_title_string()
	print("Generated base title: ", wm._base_title)
	assert(wm._base_title == "DroneFlames v0.33.5.2 — Reborn by Reborn Team", "Title string must match expected format!")
	assert(not wm._base_title.to_lower().contains("debug"), "Base title must not contain debug!")

	# 3. Verify icon files exist and load
	assert(FileAccess.file_exists("res://app_icon.ico"), "app_icon.ico must exist!")
	assert(FileAccess.file_exists("res://icon.png"), "icon.png must exist!")
	var img = Image.load_from_file(ProjectSettings.globalize_path("res://icon.png"))
	assert(img != null and not img.is_empty(), "icon.png must be a valid image!")
	print("icon.png dimensions: ", img.get_size())

	# 4. Verify DisplayServer calls
	wm._setup_app_icon()
	wm._update_title()
	print("DisplayServer title and icon calls succeeded without errors.")

	print("========================================")
	print("[TEST] ALL TITLE AND ICON CHECKS PASSED!")
	print("========================================")
	quit(0)
