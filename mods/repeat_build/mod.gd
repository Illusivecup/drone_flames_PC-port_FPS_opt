extends RefCounted

var mm_ref: Node = null
var main_ref: Node = null
var enabled: bool = true

func init_mod(mm: Node) -> void:
	mm_ref = mm
	if mm.has_method("register_hook"):
		mm.call("register_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("register_hook", "on_match_tick", Callable(self, "_on_match_tick"))

func cleanup_mod(mm: Node) -> void:
	if main_ref != null and is_instance_valid(main_ref):
		main_ref.repeat_building = false
		if main_ref.hud != null:
			if mm != null and mm.has_method("cleanup_mod_hud"):
				mm.call("cleanup_mod_hud", main_ref.hud, Callable(self, "_on_hud_action"), ["repeat_build_toggle"])
	if mm != null and mm.has_method("unregister_hook"):
		mm.call("unregister_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("unregister_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	main_ref = null

func _ensure_hud(main: Node) -> void:
	if main == null or not is_instance_valid(main):
		return
	main_ref = main
	if main.hud == null:
		return
	if main.hud.pages.size() > 1 and not main.hud.keys.has("repeat_build_toggle"):
		var cell: Control = main.hud._cell("repeat_build_toggle", "icon_plus", true)
		if main.hud.key_labels.has("repeat_build_toggle"):
			var lbl = main.hud.key_labels["repeat_build_toggle"] as Label
			if lbl != null:
				lbl.text = "ПОВТОР\nСТРОЙКИ"
		main.hud.pages[1].add_child(cell)
		main.hud.set_key_pressed("repeat_build_toggle", enabled)
	if not main.hud.action.is_connected(_on_hud_action):
		main.hud.action.connect(_on_hud_action)
	main.repeat_building = enabled

func _on_world_started(main: Node, _world: Node) -> void:
	_ensure_hud(main)

func _on_match_tick(main: Node, _world: Node, _delta: float) -> void:
	if main_ref == null or main == null or main.hud == null or not main.hud.keys.has("repeat_build_toggle"):
		_ensure_hud(main)

func _on_hud_action(action: String) -> void:
	if action != "repeat_build_toggle" or main_ref == null or not is_instance_valid(main_ref):
		return
	enabled = not enabled
	main_ref.repeat_building = enabled
	if main_ref.hud != null:
		main_ref.hud.set_key_pressed("repeat_build_toggle", enabled)
		main_ref.hud.show_toast("Повторное размещение %s" % ("включено" if enabled else "выключено"))
