@tool
class_name McpNodeValidator
extends RefCounted















const ScenePath: = preload("res://addons/godot_ai/utils/scene_path.gd")
const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")




















static func resolve_or_error(
	node_path: String, 
	param_name: String = "path", 
	scene_file: String = "", 
) -> Dictionary:
	if node_path.is_empty():
		return ErrorCodes.make(
			ErrorCodes.MISSING_REQUIRED_PARAM, 
			"Missing required param: %s" % param_name, 
		)
	var scene_check: = ScenePath.require_edited_scene(scene_file)
	if scene_check.has("error"):
		return scene_check
	var scene_root: Node = scene_check.node
	var node: = ScenePath.resolve(node_path, scene_root)
	if node == null:
		return ErrorCodes.make(
			ErrorCodes.NODE_NOT_FOUND, 
			ScenePath.format_node_error(node_path, scene_root), 
		)
	return {"node": node, "scene_root": scene_root, "path": node_path}





static func require_scene_or_error(scene_file: String = "") -> Dictionary:
	var scene_check: = ScenePath.require_edited_scene(scene_file)
	if scene_check.has("error"):
		return scene_check
	return {"scene_root": scene_check.node}
