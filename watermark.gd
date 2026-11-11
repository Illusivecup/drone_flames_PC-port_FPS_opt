extends Node
## DroneFlames Reborn — брендинг окна, иконка, F11 fullscreen.
## Держит чистый брендинг: заголовок окна, версия в меню, иконка приложения.

var _base_title: String = ""
var _last_title_check: int = 0
var _last_fullscreen_toggle: int = 0

func _is_mobile() -> bool:
        return OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS"

func _ready() -> void:
        process_mode = Node.PROCESS_MODE_ALWAYS
        if not _is_mobile():
                _init_title_string()
                _setup_app_icon()
                _update_title()
                call_deferred("_update_title")
        get_tree().node_added.connect(_on_node_added)
        _setup_updater()
        if not _is_mobile():
                var t := get_tree().create_timer(0.4)
                t.timeout.connect(func() -> void:
                        _update_title()
                        _setup_app_icon())

func _init_title_string() -> void:
        var ver: String = _get_game_version()
        _base_title = "DroneFlames Reborn " + ver

func _get_game_version() -> String:
        if ResourceLoader.exists("res://version_info.json"):
                var f := FileAccess.open("res://version_info.json", FileAccess.READ)
                if f != null:
                        var txt := f.get_as_text()
                        var json = JSON.parse_string(txt)
                        if json is Dictionary and json.has("version"):
                                return "v" + String(json["version"])
        return "v0.33.5.4"

func _setup_app_icon() -> void:
        if _is_mobile():
                return
        # 1. Native Windows .ico for taskbar and window frame
        if ResourceLoader.exists("res://app_icon.ico"):
                DisplayServer.set_native_icon("res://app_icon.ico")
                var abs_ico := ProjectSettings.globalize_path("res://app_icon.ico")
                if FileAccess.file_exists(abs_ico):
                        DisplayServer.set_native_icon(abs_ico)
        
        # 2. Window icon from high-res image
        var icon_path := "res://icon.png" if ResourceLoader.exists("res://icon.png") else "res://icon_ios.png"
        if ResourceLoader.exists(icon_path):
                var abs_png := ProjectSettings.globalize_path(icon_path)
                var img := Image.load_from_file(abs_png)
                if img != null and not img.is_empty():
                        DisplayServer.set_icon(img)
                        var win := get_window()
                        var win_id: int = win.get_window_id() if win != null else DisplayServer.MAIN_WINDOW_ID
                        DisplayServer.window_set_icon(img, win_id)

func _setup_updater() -> void:
        if has_node("/root/Updater"):
                var up = get_node("/root/Updater")
                up.update_available.connect(_on_update_available)

func _on_update_available(new_version: String, _changelog: String, _dl_url: String, _asset_name: String) -> void:
        var cur_v: String = _get_game_version().trim_prefix("v").strip_edges()
        var new_v: String = new_version.trim_prefix("v").strip_edges()
        var up: Node = get_node_or_null("/root/Updater")
        if up != null and up.get_script() != null and up.get_script().has_method("compare_versions"):
                if up.get_script().compare_versions(new_v, cur_v) <= 0:
                        return
        print("[Reborn] New version available on GitHub: v" + new_version)
        _base_title = "DroneFlames Reborn " + _get_game_version() + " (Обновление v" + new_version + " доступно!)"
        _update_title()

func _process(_delta: float) -> void:
        if _is_mobile():
                return
        var now := Time.get_ticks_msec()
        if now - _last_title_check > 500:
                _last_title_check = now
                _update_title()

func _input(event: InputEvent) -> void:
        if event is InputEventKey and event.pressed and not event.echo:
                if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed) or (event.keycode == KEY_F and (event.meta_pressed or (event.ctrl_pressed and event.meta_pressed))):
                        get_viewport().set_input_as_handled()
                        var now: int = Time.get_ticks_msec()
                        if now - _last_fullscreen_toggle < 350:
                                return
                        _last_fullscreen_toggle = now
                        var cur: int = DisplayServer.window_get_mode()
                        if cur == DisplayServer.WINDOW_MODE_FULLSCREEN or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
                                DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
                        else:
                                DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
                        call_deferred("_apply_ui_scale")
                        call_deferred("_update_title")
                        call_deferred("_setup_app_icon")

func _apply_ui_scale() -> void:
        if ResourceLoader.exists("res://game/save.gd"):
                var s = load("res://game/save.gd")
                if s != null and s.has_method("apply_ui_scale"):
                        s.apply_ui_scale()

func _notification(what: int) -> void:
        if _is_mobile():
                return
        if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
                # PC Optimization: Throttle FPS to 15 when game is in background / alt-tabbed to save GPU and battery
                Engine.max_fps = 15
        elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
                # Restore active framerate cap immediately upon focus
                if ResourceLoader.exists("res://game/save.gd"):
                        var save_cls = load("res://game/save.gd")
                        if save_cls != null and save_cls.has_method("apply_power_save"):
                                save_cls.apply_power_save()
                _update_title()
                _setup_app_icon()

func _update_title() -> void:
        if _is_mobile():
                return
        if _base_title.is_empty():
                _init_title_string()
        var win := get_window()
        var win_id: int = win.get_window_id() if win != null else DisplayServer.MAIN_WINDOW_ID
        DisplayServer.window_set_title(_base_title, win_id)

func _on_node_added(node: Node) -> void:
        if node is Label:
                if node.text.begins_with("v") and not node.text.contains("Reborn"):
                        node.text = node.text + " · Reborn"
