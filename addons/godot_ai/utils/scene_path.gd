@tool
class_name McpScenePath
extends RefCounted

const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")









static func from_node(node: Node, scene_root: Node) -> String:
	if scene_root == null or node == null:
		return ""
	if node == scene_root:
		return "/" + scene_root.name
	if not scene_root.is_ancestor_of(node):
		return ""
	var relative: = scene_root.get_path_to(node)
	return "/" + scene_root.name + "/" + str(relative)

















static func resolve(scene_path: String, scene_root: Node) -> Node:
	if scene_root == null:
		return null





	if scene_path == "/":
		return scene_root




	var alias_prefix: = "/root/" + scene_root.name
	if scene_path == alias_prefix or scene_path.begins_with(alias_prefix + "/"):
		return resolve(scene_path.substr(5), scene_root)

	var root_prefix: = "/" + scene_root.name
	if scene_path == root_prefix:
		return scene_root
	if scene_path.begins_with(root_prefix + "/"):
		var relative: = scene_path.substr(root_prefix.length() + 1)
		return scene_root.get_node_or_null(relative)


	return scene_root.get_node_or_null(scene_path)













static func require_edited_scene(expected_scene_file: String) -> Dictionary:
	var root: = EditorInterface.get_edited_scene_root()
	if root == null:








		var err: = ErrorCodes.make(ErrorCodes.EDITOR_NOT_READY, "No scene open")
		err["error"]["data"] = {
			"sub_code": ErrorCodes.SUB_EDITOR_NO_SCENE, 
			"editor_state": "no_scene", 
			"retryable": false, 
			"hint": (
				"No scene is open. Call scene_open with a scene path "
				+ "(e.g. \"res://main.tscn\") before issuing scene-mutating tools."
			), 
		}
		return err
	if not expected_scene_file.is_empty() and root.scene_file_path != expected_scene_file:
		var actual: = root.scene_file_path if not root.scene_file_path.is_empty() else "<unsaved>"
		return ErrorCodes.make(
			ErrorCodes.EDITED_SCENE_MISMATCH, 
			(
				"Expected edited scene \"%s\" but \"%s\" is active. "
				+ "Call scene_open(\"%s\") first, or omit scene_file to target the active scene."
			) % [expected_scene_file, actual, expected_scene_file], 
		)
	return {"node": root}







static func format_parent_error(path: String, scene_root: Node) -> String:
	if scene_root == null:
		return "Parent not found: %s. No edited scene is open." % path
	var root_name: = str(scene_root.name)
	return "Parent not found: %s. Paths are relative to the edited scene root (e.g. \"/%s\" or \"\"), not the SceneTree. Scene root is \"/%s\"." % [path, root_name, root_name]











static func format_node_error(path: String, scene_root: Node) -> String:
	if scene_root == null:
		return "Node not found: %s. No edited scene is open." % path
	var root_name: = str(scene_root.name)
	var suggestion: = ""

	if path.begins_with("/root/"):
		var after_root: = path.substr(6)



		var first_seg: = after_root.split("/")[0]
		if first_seg != root_name and not first_seg.is_empty():
			suggestion = "/" + root_name + "/" + after_root
	elif not path.begins_with("/") and not path.is_empty():
		suggestion = "/" + root_name + "/" + path

	if suggestion.is_empty():
		return "Node not found: %s. Paths are relative to the edited scene root (e.g. \"/%s/Child\"), not runtime /root/... paths. Scene root is \"/%s\"." % [path, root_name, root_name]
	return "Node not found: %s. Did you mean \"%s\"? Paths are relative to the edited scene root, not runtime /root/... paths. Scene root is \"/%s\"." % [path, suggestion, root_name]
