extends RefCounted

const LABEL_NAME: String = "FpsPingOverlayLabel"

var _label: Label
var _timer: float = 0.0


func init_mod(mod_manager: Node) -> void:
	if mod_manager == null or not is_instance_valid(mod_manager):
		return
	if mod_manager.has_method("register_hook"):
		mod_manager.call("register_hook", "on_world_started", Callable(self, "_on_world_started"))
		mod_manager.call("register_hook", "on_match_tick", Callable(self, "_on_match_tick"))


func cleanup_mod(mod_manager: Node) -> void:
	if mod_manager != null and is_instance_valid(mod_manager) and mod_manager.has_method("unregister_hook"):
		mod_manager.call("unregister_hook", "on_world_started", Callable(self, "_on_world_started"))
		mod_manager.call("unregister_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	if _label != null and is_instance_valid(_label):
		_label.queue_free()
	_label = null


func _on_world_started(main: Node, _world: Node) -> void:
	if main == null or not is_instance_valid(main):
		return
	_timer = 0.0
	_ensure_overlay(main)
	_update_stats(main)


func _on_match_tick(main: Node, _world: Node, delta: float) -> void:
	if main == null or not is_instance_valid(main):
		return
	if _label == null or not is_instance_valid(_label) or _label.get_parent() != _get_hud(main):
		_ensure_overlay(main)
	if _label == null or not is_instance_valid(_label):
		return
	_timer += maxf(delta, 0.0)
	if _timer >= 0.5:
		_timer = 0.0
		_update_stats(main)


func _get_hud(main: Node) -> Node:
	var hud: Variant = main.get("hud")
	if not hud is Node or not is_instance_valid(hud):
		return null
	var r: Variant = (hud as Node).get("root")
	if r is Control and is_instance_valid(r):
		return r as Control
	return hud as Node


func _reposition_label() -> void:
	if _label == null or not is_instance_valid(_label) or not _label.is_inside_tree():
		return
	var vp_w: float = _label.get_viewport_rect().size.x
	_label.anchor_left = 1.0
	_label.anchor_top = 0.0
	_label.anchor_right = 1.0
	_label.anchor_bottom = 0.0
	_label.offset_left = -236.0
	_label.offset_top = 12.0
	_label.offset_right = -14.0
	_label.offset_bottom = 42.0
	_label.position = Vector2(vp_w - 236.0, 12.0)
	_label.size = Vector2(222.0, 30.0)


func _ensure_overlay(main: Node) -> void:
	var container: Node = _get_hud(main)
	if container == null or not is_instance_valid(container):
		return
	var existing: Node = container.get_node_or_null(LABEL_NAME)
	if existing is Label:
		_label = existing as Label
		_reposition_label()
		return
	_label = Label.new()
	_label.name = LABEL_NAME
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.z_index = 200
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.03, 1.0))
	_label.add_theme_constant_override("outline_size", 3)
	container.add_child(_label)
	_reposition_label()
	if not _label.get_viewport().size_changed.is_connected(_reposition_label):
		_label.get_viewport().size_changed.connect(_reposition_label)


func _update_stats(main: Node) -> void:
	if _label == null or not is_instance_valid(_label):
		return
	_reposition_label()
	var fps: int = Engine.get_frames_per_second()
	_label.text = "FPS: %d | PING: %s" % [fps, _ping_text(main)]


func _ping_text(main: Node) -> String:
	var net: Variant = main.get("net")
	if not net is Node or not is_instance_valid(net) or not bool(net.get("in_match")) or not net.has_method("net_stats"):
		return "—"
	var stats: Variant = net.call("net_stats")
	if not stats is Dictionary:
		return "—"
	var rtt: float = float((stats as Dictionary).get("rtt_avg", -1.0))
	return "%d ms" % roundi(rtt) if rtt >= 0.0 else "…"
