@tool
extends "res://addons/godot_ai/handlers/command_handler.gd"

const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")








const CameraValues: = preload("res://addons/godot_ai/handlers/camera_values.gd")
const CameraPresets: = preload("res://addons/godot_ai/handlers/camera_presets.gd")

const _VALID_TYPES: = {
	"2d": "Camera2D", 
	"3d": "Camera3D", 
}

const _KEYS_2D: = [
	"zoom", 
	"offset", 
	"anchor_mode", 
	"ignore_rotation", 
	"enabled", 
	"current", 
	"process_callback", 
	"position_smoothing_enabled", 
	"position_smoothing_speed", 
	"rotation_smoothing_enabled", 
	"rotation_smoothing_speed", 
	"drag_horizontal_enabled", 
	"drag_vertical_enabled", 
	"drag_horizontal_offset", 
	"drag_vertical_offset", 
	"drag_left_margin", 
	"drag_top_margin", 
	"drag_right_margin", 
	"drag_bottom_margin", 
	"limit_left", 
	"limit_right", 
	"limit_top", 
	"limit_bottom", 
	"limit_smoothed", 
]

const _KEYS_3D: = [
	"fov", 
	"near", 
	"far", 
	"size", 
	"projection", 
	"keep_aspect", 
	"cull_mask", 
	"doppler_tracking", 
	"h_offset", 
	"v_offset", 
	"current", 
]




const _NODE_TRANSFORM_KEYS: = [
	"position", "rotation", "scale", "transform", 
	"global_position", "global_rotation", "global_scale", "global_transform", 
]

const _DAMPING_MARGIN_KEYS: = ["left", "top", "right", "bottom"]
const _CURRENT_SETTLE_ATTEMPTS: = 8
const _CURRENT_SETTLE_DELAY_MSEC: = 10


var _undo_redo: EditorUndoRedoManager









var _logical_current: Dictionary = {}


func _init(undo_redo: EditorUndoRedoManager) -> void :
	_undo_redo = undo_redo





static func _is_current(cam: Node) -> bool:
	if cam == null:
		return false
	return bool(cam.is_current())


static func _viewport_current_camera(scene_root: Node) -> Node:
	if scene_root == null:
		return null
	var viewport: = scene_root.get_viewport()
	if viewport == null:
		return null
	var current_2d: = viewport.get_camera_2d()
	if current_2d != null and scene_root.is_ancestor_of(current_2d):
		return current_2d
	var current_3d: = viewport.get_camera_3d()
	if current_3d != null and scene_root.is_ancestor_of(current_3d):
		return current_3d
	return null


static func _is_effective_current(cam: Node) -> bool:
	if _is_current(cam):
		return true
	if cam is Camera2D:
		var viewport_2d: = cam.get_viewport()
		return viewport_2d != null and viewport_2d.get_camera_2d() == cam
	if cam is Camera3D:
		var viewport_3d: = cam.get_viewport()
		return viewport_3d != null and viewport_3d.get_camera_3d() == cam
	return false








func _set_logical_current(cam: Node) -> void :
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		return
	var type_str: = _camera_type_str(cam)
	if type_str.is_empty():
		return
	var scene_root: = EditorInterface.get_edited_scene_root()
	if scene_root == null or not scene_root.is_ancestor_of(cam):
		return
	var slot: Dictionary = _logical_current.get(scene_root.get_instance_id(), {})
	slot[type_str] = McpScenePath.from_node(cam, scene_root)
	_logical_current[scene_root.get_instance_id()] = slot


func _clear_logical_current(cam: Node) -> void :
	if cam == null:
		return
	var type_str: = _camera_type_str(cam)
	if type_str.is_empty():
		return
	var scene_root: = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return
	var key: = scene_root.get_instance_id()
	if not _logical_current.has(key):
		return
	var slot: Dictionary = _logical_current[key]
	if not slot.has(type_str):
		return


	var current_path: = ""
	if is_instance_valid(cam) and cam.is_inside_tree() and scene_root.is_ancestor_of(cam):
		current_path = McpScenePath.from_node(cam, scene_root)
	if String(slot[type_str]) == current_path:
		slot.erase(type_str)
		if slot.is_empty():
			_logical_current.erase(key)
		else:
			_logical_current[key] = slot


func _logical_current_camera(scene_root: Node, type_str: String = "") -> Node:
	if scene_root == null:
		return null
	var key: = scene_root.get_instance_id()
	if not _logical_current.has(key):
		return null
	var slot: Dictionary = _logical_current[key]
	var types: Array[String] = []
	if type_str == "2d" or type_str == "3d":
		types = [type_str]
	else:
		types = ["2d", "3d"]
	for t in types:
		if not slot.has(t):
			continue
		var path: = String(slot[t])
		if path.is_empty():
			slot.erase(t)
			continue
		var node: = McpScenePath.resolve(path, scene_root)
		if node == null or not _is_camera(node) or _camera_type_str(node) != t:
			slot.erase(t)
			continue
		return node
	if slot.is_empty():
		_logical_current.erase(key)
	else:
		_logical_current[key] = slot
	return null










func peek_logical_current(scene_root: Node, type_str: String = "") -> Node:
	return _logical_current_camera(scene_root, type_str)










func _resolve_current(scene_root: Node, cam: Node) -> bool:
	if scene_root == null or cam == null:
		return false
	var logical: = _logical_current_camera(scene_root, _camera_type_str(cam))
	if logical != null:
		return logical == cam
	return _is_effective_current(cam)





func _resolve_current_with_logicals(cam: Node, logical_2d: Node, logical_3d: Node) -> bool:
	if cam == null:
		return false
	if cam is Camera2D:
		if logical_2d != null:
			return logical_2d == cam
	elif cam is Camera3D:
		if logical_3d != null:
			return logical_3d == cam
	return _is_effective_current(cam)






























func _add_make_current_to_action(node: Node, type_str: String, scene_root: Node) -> void :
	var prev_current: Node = null
	for cam in _list_cameras_in_scene(scene_root, type_str):
		if cam == node:
			continue
		if _resolve_current(scene_root, cam):
			prev_current = cam
			break
	_undo_redo.add_do_method(self, "_apply_make_current", node)
	if prev_current != null:
		_undo_redo.add_undo_method(self, "_apply_make_current", prev_current)
	else:
		_undo_redo.add_undo_method(self, "_apply_clear_current", node)












func _apply_make_current(cam: Node) -> void :
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		return
	_set_logical_current(cam)
	var scene_root: = EditorInterface.get_edited_scene_root()
	var type_str: = _camera_type_str(cam)
	cam.make_current()
	if cam is Camera2D and not _is_current_settled(cam):
		_broadcast_make_current_2d(cam as Camera2D, scene_root)
	_force_camera_refresh(cam)



	_force_clear_other_currents(cam, type_str, scene_root)






















func _broadcast_make_current_2d(cam: Camera2D, scene_root: Node) -> void :
	if not cam.has_method("_make_current"):
		return
	if scene_root != null:
		for other in _list_cameras_in_scene(scene_root, "2d"):
			if other == cam or not is_instance_valid(other) or not other.is_inside_tree():
				continue
			if other.has_method("_make_current"):
				other.call("_make_current", cam)
	cam.call("_make_current", cam)






func _force_clear_other_currents(target: Node, type_str: String, scene_root: Node) -> void :
	if scene_root == null or type_str.is_empty():
		return
	for sibling in _list_cameras_in_scene(scene_root, type_str):
		if sibling == target:
			continue
		if not is_instance_valid(sibling) or not sibling.is_inside_tree():
			continue
		if not _is_current(sibling):



			if sibling is Camera2D:
				var vp_other: Viewport = (sibling as Camera2D).get_viewport()
				if vp_other != null and vp_other.get_camera_2d() == sibling:
					target.make_current()
					_force_camera_refresh(target)
			continue
		sibling.clear_current()
		if sibling is Camera2D:
			(sibling as Camera2D).force_update_scroll()





func _verify_current_after_commit(node: Node) -> void :
	_apply_make_current(node)


func _force_camera_refresh(cam: Node) -> void :
	if cam is Camera2D:
		(cam as Camera2D).force_update_scroll()


func _is_current_settled(cam: Node) -> bool:
	if not _is_current(cam):
		return false
	if cam is Camera2D:
		var viewport: = cam.get_viewport()
		if viewport != null and viewport.get_camera_2d() != cam:
			return false
	return true






func _apply_clear_current(cam: Node) -> void :
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		return
	_clear_logical_current(cam)
	for attempt in range(_CURRENT_SETTLE_ATTEMPTS):
		if _is_clear_settled(cam):
			return
		if _is_current(cam):
			cam.clear_current()
			_force_camera_refresh(cam)



		if cam is Camera2D:
			var vp: = cam.get_viewport()
			if vp != null and vp.get_camera_2d() == cam:
				var was_enabled: = (cam as Camera2D).enabled
				if was_enabled:
					(cam as Camera2D).enabled = false
				_force_camera_refresh(cam)
				if was_enabled:
					(cam as Camera2D).enabled = true
		if _is_clear_settled(cam):
			return
		if attempt < _CURRENT_SETTLE_ATTEMPTS - 1:
			OS.delay_msec(_CURRENT_SETTLE_DELAY_MSEC)


func _is_clear_settled(cam: Node) -> bool:
	if cam == null:
		return true
	if _is_current(cam):
		return false
	if cam is Camera2D:
		var vp: = cam.get_viewport()
		if vp != null and vp.get_camera_2d() == cam:
			return false
	return true






func create_camera(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var node_name: String = params.get("name", "Camera")
	var type_str: String = params.get("type", "2d")
	var make_current: bool = bool(params.get("make_current", false))

	if not _VALID_TYPES.has(type_str):
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			"Invalid camera type '%s'. Valid: %s" % [type_str, ", ".join(_VALID_TYPES.keys())]
		)

	var _scene_check: = McpNodeValidator.require_scene_or_error()
	if _scene_check.has("error"):
		return _scene_check
	var scene_root: Node = _scene_check.scene_root

	var parent: Node = scene_root
	if not parent_path.is_empty():
		parent = McpScenePath.resolve(parent_path, scene_root)
		if parent == null:
			return ErrorCodes.make(ErrorCodes.NODE_NOT_FOUND, McpScenePath.format_parent_error(parent_path, scene_root))

	var node: = _instantiate_camera(type_str)
	if node == null:
		return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, "Failed to instantiate camera")
	if not node_name.is_empty():
		node.name = node_name

	_undo_redo.create_action(
		"MCP: Create %s '%s'" % [_VALID_TYPES[type_str], node.name], 
		UndoRedo.MERGE_DISABLE, scene_root
	)
	_undo_redo.add_do_method(parent, "add_child", node, true)
	_undo_redo.add_do_method(node, "set_owner", scene_root)
	_undo_redo.add_do_reference(node)
	if make_current:


		_add_make_current_to_action(node, type_str, scene_root)
	_undo_redo.add_undo_method(parent, "remove_child", node)
	_undo_redo.commit_action()
	if make_current:
		_verify_current_after_commit(node)

	return {
		"data": {
			"path": McpScenePath.from_node(node, scene_root), 
			"parent_path": McpScenePath.from_node(parent, scene_root), 
			"name": String(node.name), 
			"type": type_str, 
			"class": _VALID_TYPES[type_str], 
			"current": bool(make_current), 
			"undoable": true, 
		}
	}






func configure(params: Dictionary) -> Dictionary:
	var resolved: = _resolve_camera(params)
	if resolved.has("error"):
		return resolved
	var node: Node = resolved.node
	var node_path: String = resolved.path
	var type_str: String = resolved.type
	var scene_root: Node = resolved.scene_root

	var properties: Dictionary = params.get("properties", {})
	if properties.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "properties dict is empty")

	var valid_keys: Array = _KEYS_2D if type_str == "2d" else _KEYS_3D
	var prop_types: = _property_type_map(node)
	var coerced: Dictionary = {}
	var old_values: Dictionary = {}

	var current_request: Variant = null

	for property in properties:
		var prop_name: String = String(property)
		if not (prop_name in valid_keys):
			var msg: = "Property '%s' not valid for %s. Valid: %s" % [
				prop_name, _VALID_TYPES[type_str], ", ".join(valid_keys)
			]
			if prop_name in _NODE_TRANSFORM_KEYS:
				msg += (
					". Transforms live on the Node, not on the camera config — "
					+ "use node_set_property(path=%s, property=\"%s\", value=...)" % [node_path, prop_name]
				)
			return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, msg)
		if prop_name == "current":
			current_request = bool(properties[prop_name])
			continue
		var prop_type: int = prop_types.get(prop_name, TYPE_NIL)
		if prop_type == TYPE_NIL:
			return ErrorCodes.make(
				ErrorCodes.PROPERTY_NOT_ON_CLASS, 
				"Property '%s' not present on %s" % [prop_name, node.get_class()]
			)
		var coerce_result: = CameraValues.coerce(prop_name, properties[prop_name], prop_type)
		if not coerce_result.ok:
			return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, String(coerce_result.error))
		coerced[prop_name] = coerce_result.value
		old_values[prop_name] = node.get(prop_name)

	_undo_redo.create_action(
		"MCP: Configure camera %s" % node.name, 
		UndoRedo.MERGE_DISABLE, scene_root
	)
	for prop_name in coerced:
		_undo_redo.add_do_property(node, prop_name, coerced[prop_name])
		_undo_redo.add_undo_property(node, prop_name, old_values[prop_name])
	var verify_current_after: = false
	if current_request != null:
		var want_on: bool = bool(current_request)
		var was_on: bool = _resolve_current(scene_root, node)
		if want_on and not was_on:
			_add_make_current_to_action(node, type_str, scene_root)
			verify_current_after = true
		elif not want_on and was_on:
			_undo_redo.add_do_method(self, "_apply_clear_current", node)
			_undo_redo.add_undo_method(self, "_apply_make_current", node)
	_undo_redo.commit_action()
	if verify_current_after:
		_verify_current_after_commit(node)

	var applied: Array[String] = []
	var serialized: Dictionary = {}
	for prop_name in coerced:
		applied.append(prop_name)
		serialized[prop_name] = CameraValues.serialize(coerced[prop_name])
	if current_request != null:
		applied.append("current")
		serialized["current"] = bool(current_request)

	return {
		"data": {
			"path": node_path, 
			"type": type_str, 
			"class": node.get_class(), 
			"applied": applied, 
			"values": serialized, 
			"undoable": true, 
		}
	}






func set_limits_2d(params: Dictionary) -> Dictionary:
	var resolved: = _resolve_camera(params)
	if resolved.has("error"):
		return resolved
	var node: Node = resolved.node
	var node_path: String = resolved.path
	var type_str: String = resolved.type

	if type_str != "2d":
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE, 
			"camera_set_limits_2d requires a Camera2D (got %s)" % node.get_class()
		)

	var applied: Dictionary = {}
	var old_values: Dictionary = {}
	var edges: = {
		"left": "limit_left", 
		"right": "limit_right", 
		"top": "limit_top", 
		"bottom": "limit_bottom", 
	}
	for edge in edges:
		var v = params.get(edge)
		if v != null:
			var prop_name: String = edges[edge]
			applied[prop_name] = int(v)
			old_values[prop_name] = node.get(prop_name)

	var smoothed = params.get("smoothed")
	if smoothed != null:
		applied["limit_smoothed"] = bool(smoothed)
		old_values["limit_smoothed"] = node.get("limit_smoothed")

	if applied.is_empty():
		return ErrorCodes.make(
			ErrorCodes.MISSING_REQUIRED_PARAM, 
			"No limits specified; provide at least one of left, right, top, bottom, smoothed"
		)

	_undo_redo.create_action("MCP: Set camera limits on %s" % node.name)
	for prop_name in applied:
		_undo_redo.add_do_property(node, prop_name, applied[prop_name])
		_undo_redo.add_undo_property(node, prop_name, old_values[prop_name])
	_undo_redo.commit_action()

	var values: Dictionary = {}
	for prop_name in applied:
		values[prop_name] = applied[prop_name]

	return {
		"data": {
			"path": node_path, 
			"applied": applied.keys(), 
			"values": values, 
			"undoable": true, 
		}
	}






func set_damping_2d(params: Dictionary) -> Dictionary:
	var resolved: = _resolve_camera(params)
	if resolved.has("error"):
		return resolved
	var node: Node = resolved.node
	var node_path: String = resolved.path
	var type_str: String = resolved.type

	if type_str != "2d":
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE, 
			"camera_set_damping_2d requires a Camera2D (got %s)" % node.get_class()
		)

	var applied: Dictionary = {}
	var old_values: Dictionary = {}


	var pos_v = params.get("position_speed")
	if pos_v != null:
		var pos_speed: = float(pos_v)
		var pos_enable: = pos_speed > 0.0
		applied["position_smoothing_enabled"] = pos_enable
		old_values["position_smoothing_enabled"] = node.get("position_smoothing_enabled")
		if pos_enable:
			applied["position_smoothing_speed"] = pos_speed
			old_values["position_smoothing_speed"] = node.get("position_smoothing_speed")


	var rot_v = params.get("rotation_speed")
	if rot_v != null:
		var rot_speed: = float(rot_v)
		var rot_enable: = rot_speed > 0.0
		applied["rotation_smoothing_enabled"] = rot_enable
		old_values["rotation_smoothing_enabled"] = node.get("rotation_smoothing_enabled")
		if rot_enable:
			applied["rotation_smoothing_speed"] = rot_speed
			old_values["rotation_smoothing_speed"] = node.get("rotation_smoothing_speed")

	for flag in ["drag_horizontal_enabled", "drag_vertical_enabled"]:
		var flag_v = params.get(flag)
		if flag_v != null:
			applied[flag] = bool(flag_v)
			old_values[flag] = node.get(flag)


	var margins_v = params.get("drag_margins")
	if margins_v != null:
		if not (margins_v is Dictionary):
			return ErrorCodes.make(
				ErrorCodes.WRONG_TYPE, 
				"drag_margins must be a dict with optional keys left/top/right/bottom"
			)
		var margins: Dictionary = margins_v
		for edge in _DAMPING_MARGIN_KEYS:
			var margin_v = margins.get(edge)
			if margin_v == null:
				continue
			var v: = float(margin_v)
			if v < 0.0 or v > 1.0:
				return ErrorCodes.make(
					ErrorCodes.INVALID_PARAMS, 
					"drag_margins.%s must be in [0, 1] (got %s)" % [edge, v]
				)
			var prop_name: String = "drag_%s_margin" % edge
			applied[prop_name] = v
			old_values[prop_name] = node.get(prop_name)

	if applied.is_empty():
		return ErrorCodes.make(
			ErrorCodes.MISSING_REQUIRED_PARAM, 
			"No damping params specified; provide at least one of position_speed, rotation_speed, drag_margins, drag_horizontal_enabled, drag_vertical_enabled"
		)

	_undo_redo.create_action("MCP: Set camera damping on %s" % node.name)
	for prop_name in applied:
		_undo_redo.add_do_property(node, prop_name, applied[prop_name])
		_undo_redo.add_undo_property(node, prop_name, old_values[prop_name])
	_undo_redo.commit_action()

	return {
		"data": {
			"path": node_path, 
			"applied": applied.keys(), 
			"values": applied, 
			"undoable": true, 
		}
	}






func follow_2d(params: Dictionary) -> Dictionary:
	var resolved: = _resolve_camera(params)
	if resolved.has("error"):
		return resolved
	var node: Node = resolved.node
	var node_path: String = resolved.path
	var type_str: String = resolved.type
	var scene_root: Node = resolved.scene_root

	if type_str != "2d":
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE, 
			"camera_follow_2d requires a Camera2D (got %s)" % node.get_class()
		)

	var target_path: String = params.get("target_path", "")
	if target_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: target_path")
	var target: = McpScenePath.resolve(target_path, scene_root)
	if target == null:
		return ErrorCodes.make(ErrorCodes.NODE_NOT_FOUND, 
			"target_path: %s" % McpScenePath.format_node_error(target_path, scene_root))
	if not (target is Node2D) and target != scene_root:
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE, 
			"Follow target must be a Node2D (got %s)" % target.get_class()
		)
	if target == node:
		return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, "Camera cannot follow itself")
	if target.is_ancestor_of(node) and node.get_parent() != target:

		pass
	if node.is_ancestor_of(target):
		return ErrorCodes.make(
			ErrorCodes.INVALID_PARAMS, 
			"Cannot follow a descendant of the camera"
		)

	var smoothing_speed: = float(params.get("smoothing_speed", 5.0))
	var zero_transform: bool = bool(params.get("zero_transform", true))

	var old_parent: = node.get_parent()
	var old_idx: int = node.get_index() if old_parent != null else 0
	var old_position = node.get("position")
	var old_rotation = node.get("rotation")
	var old_smoothing_enabled: bool = bool(node.get("position_smoothing_enabled"))
	var old_smoothing_speed: float = float(node.get("position_smoothing_speed"))

	var already_child: bool = old_parent == target
	var reparented: bool = not already_child

	_undo_redo.create_action("MCP: Camera follow %s" % target.name)
	if reparented:
		_undo_redo.add_do_method(old_parent, "remove_child", node)
		_undo_redo.add_do_method(target, "add_child", node, true)
		_undo_redo.add_do_method(node, "set_owner", scene_root)
		_undo_redo.add_do_reference(node)
	if zero_transform:
		if target is Node2D:
			_undo_redo.add_do_property(node, "position", Vector2.ZERO)
			_undo_redo.add_undo_property(node, "position", old_position)
			_undo_redo.add_do_property(node, "rotation", 0.0)
			_undo_redo.add_undo_property(node, "rotation", old_rotation)
	_undo_redo.add_do_property(node, "position_smoothing_enabled", true)
	_undo_redo.add_undo_property(node, "position_smoothing_enabled", old_smoothing_enabled)
	if smoothing_speed > 0.0:
		_undo_redo.add_do_property(node, "position_smoothing_speed", smoothing_speed)
		_undo_redo.add_undo_property(node, "position_smoothing_speed", old_smoothing_speed)
	if reparented:
		_undo_redo.add_undo_method(target, "remove_child", node)
		_undo_redo.add_undo_method(old_parent, "add_child", node, true)
		_undo_redo.add_undo_method(old_parent, "move_child", node, old_idx)
		_undo_redo.add_undo_method(node, "set_owner", scene_root)
		_undo_redo.add_undo_reference(node)
	_undo_redo.commit_action()

	return {
		"data": {
			"path": McpScenePath.from_node(node, scene_root), 
			"target_path": McpScenePath.from_node(target, scene_root), 
			"reparented": reparented, 
			"smoothing_speed": smoothing_speed, 
			"zero_transform": zero_transform and (target is Node2D), 
			"undoable": true, 
		}
	}






func get_camera(params: Dictionary) -> Dictionary:
	var _scene_check: = McpNodeValidator.require_scene_or_error()
	if _scene_check.has("error"):
		return _scene_check
	var scene_root: Node = _scene_check.scene_root

	var camera_path: String = params.get("camera_path", "")
	var node: Node = null
	var resolved_via: String = ""
	if camera_path.is_empty():




		var all_cams: = _list_cameras_in_scene(scene_root, "")
		var logical_current: = _logical_current_camera(scene_root)
		if logical_current != null and all_cams.has(logical_current):
			node = logical_current
			resolved_via = "current"
		var viewport_current: = _viewport_current_camera(scene_root)
		if node == null and viewport_current != null and all_cams.has(viewport_current):
			node = viewport_current
			resolved_via = "current"
		for cam in all_cams:
			if node != null:
				break
			if _is_current(cam):
				node = cam
				resolved_via = "current"
				break
		if node == null and not all_cams.is_empty():
			node = all_cams[0]
			resolved_via = "first"
	else:
		node = McpScenePath.resolve(camera_path, scene_root)
		if node == null:
			return ErrorCodes.make(ErrorCodes.NODE_NOT_FOUND, McpScenePath.format_node_error(camera_path, scene_root))
		if not _is_camera(node):
			return ErrorCodes.make(
				ErrorCodes.WRONG_TYPE, 
				"Node %s is not a camera (got %s)" % [camera_path, node.get_class()]
			)
		resolved_via = "path"

	if node == null:
		return {
			"data": {
				"path": "", 
				"type": "", 
				"class": "", 
				"current": false, 
				"properties": {}, 
				"resolved_via": "not_found", 
			}
		}

	var type_str: = _camera_type_str(node)
	var keys: Array = _KEYS_2D if type_str == "2d" else _KEYS_3D
	var prop_types: = _property_type_map(node)
	var props: Dictionary = {}
	var is_current_effective: = _resolve_current(scene_root, node)
	for key in keys:
		if key == "current":
			props[key] = is_current_effective
			continue
		if prop_types.has(key):
			props[key] = CameraValues.serialize(node.get(key))

	return {
		"data": {
			"path": McpScenePath.from_node(node, scene_root), 
			"type": type_str, 
			"class": node.get_class(), 
			"current": is_current_effective, 
			"properties": props, 
			"resolved_via": resolved_via, 
		}
	}






func list_cameras(_params: Dictionary) -> Dictionary:
	var _scene_check: = McpNodeValidator.require_scene_or_error()
	if _scene_check.has("error"):
		return _scene_check
	var scene_root: Node = _scene_check.scene_root

	var cams: = _list_cameras_in_scene(scene_root, "")
	var out: Array[Dictionary] = []
	var logical_2d: = _logical_current_camera(scene_root, "2d")
	var logical_3d: = _logical_current_camera(scene_root, "3d")
	for cam in cams:
		out.append({
			"path": McpScenePath.from_node(cam, scene_root), 
			"class": cam.get_class(), 
			"type": _camera_type_str(cam), 
			"current": _resolve_current_with_logicals(cam, logical_2d, logical_3d), 
		})
	return {"data": {"cameras": out}}






func apply_preset(params: Dictionary) -> Dictionary:
	var preset_name: String = params.get("preset", "")
	if preset_name.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: preset")

	var overrides: Dictionary = params.get("overrides", {})
	var blueprint = CameraPresets.build(preset_name, overrides)
	if blueprint == null:
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			"Unknown preset '%s'. Valid: %s" % [preset_name, ", ".join(CameraPresets.list_presets())]
		)

	var parent_path: String = params.get("parent_path", "")
	var node_name: String = params.get("name", "")
	var type_str: String = params.get("type", String(blueprint.get("default_type", "2d")))
	var make_current: bool = bool(params.get("make_current", true))
	if node_name.is_empty():
		node_name = preset_name.capitalize()
	if not _VALID_TYPES.has(type_str):
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			"Invalid camera type '%s'. Valid: %s" % [type_str, ", ".join(_VALID_TYPES.keys())]
		)

	var _scene_check: = McpNodeValidator.require_scene_or_error()
	if _scene_check.has("error"):
		return _scene_check
	var scene_root: Node = _scene_check.scene_root

	var parent: Node = scene_root
	if not parent_path.is_empty():
		parent = McpScenePath.resolve(parent_path, scene_root)
		if parent == null:
			return ErrorCodes.make(ErrorCodes.NODE_NOT_FOUND, McpScenePath.format_parent_error(parent_path, scene_root))

	var node: = _instantiate_camera(type_str)
	node.name = node_name

	var preset_props: Dictionary = blueprint.get("properties", {})
	var valid_keys: Array = _KEYS_2D if type_str == "2d" else _KEYS_3D
	var prop_types: = _property_type_map(node)
	var applied: Array[String] = []
	for prop in preset_props:
		var prop_name: = String(prop)
		if not (prop_name in valid_keys):
			continue


		if prop_name == "current":
			continue
		var prop_type: int = prop_types.get(prop_name, TYPE_NIL)
		if prop_type == TYPE_NIL:
			continue
		var coerce_result: = CameraValues.coerce(prop_name, preset_props[prop_name], prop_type)
		if not coerce_result.ok:
			return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, String(coerce_result.error))
		node.set(prop_name, coerce_result.value)
		applied.append(prop_name)

	_undo_redo.create_action(
		"MCP: Apply camera preset %s" % preset_name, 
		UndoRedo.MERGE_DISABLE, scene_root
	)
	_undo_redo.add_do_method(parent, "add_child", node, true)
	_undo_redo.add_do_method(node, "set_owner", scene_root)
	_undo_redo.add_do_reference(node)
	if make_current:
		_add_make_current_to_action(node, type_str, scene_root)
	_undo_redo.add_undo_method(parent, "remove_child", node)
	_undo_redo.commit_action()
	if make_current:
		_verify_current_after_commit(node)

	return {
		"data": {
			"path": McpScenePath.from_node(node, scene_root), 
			"parent_path": McpScenePath.from_node(parent, scene_root), 
			"name": node_name, 
			"preset": preset_name, 
			"type": type_str, 
			"class": _VALID_TYPES[type_str], 
			"applied": applied, 
			"current": bool(make_current), 
			"undoable": true, 
		}
	}






static func _instantiate_camera(type_str: String) -> Node:
	match type_str:
		"2d":
			return Camera2D.new()
		"3d":
			return Camera3D.new()
	return null


static func _is_camera(node: Node) -> bool:
	return node is Camera2D or node is Camera3D


static func _camera_type_str(node: Node) -> String:
	if node is Camera2D:
		return "2d"
	if node is Camera3D:
		return "3d"
	return ""


func _resolve_camera(params: Dictionary) -> Dictionary:
	var resolved: = McpNodeValidator.resolve_or_error(
		params.get("camera_path", ""), "camera_path", 
	)
	if resolved.has("error"):
		return resolved
	var node: Node = resolved.node
	var node_path: String = resolved.path
	var scene_root: Node = resolved.scene_root
	if not _is_camera(node):
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE, 
			"Node %s is not a camera (got %s)" % [node_path, node.get_class()]
		)
	return {
		"node": node, 
		"path": node_path, 
		"type": _camera_type_str(node), 
		"scene_root": scene_root, 
	}



static func _list_cameras_in_scene(scene_root: Node, class_filter: String) -> Array:
	var result: Array = []
	if scene_root == null:
		return result
	_collect_cameras(scene_root, class_filter, result)
	return result


static func _collect_cameras(node: Node, class_filter: String, out: Array) -> void :
	var matches: = false
	match class_filter:
		"2d":
			matches = node is Camera2D
		"3d":
			matches = node is Camera3D
		_:
			matches = node is Camera2D or node is Camera3D
	if matches:
		out.append(node)
	for child in node.get_children():
		_collect_cameras(child, class_filter, out)





static func _property_type_map(obj: Object) -> Dictionary:
	var out: Dictionary = {}
	if obj == null:
		return out
	for prop in obj.get_property_list():
		out[prop.name] = int(prop.get("type", TYPE_NIL))
	return out
