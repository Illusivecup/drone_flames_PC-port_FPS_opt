@tool
class_name McpPathValidator
extends RefCounted

const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")




































static var _cached_res_root: String = ""
static var _cached_user_root: String = ""


static func _res_root() -> String:
	if _cached_res_root.is_empty():
		_cached_res_root = ProjectSettings.globalize_path("res://").simplify_path()
	return _cached_res_root


static func _user_root() -> String:
	if _cached_user_root.is_empty():
		_cached_user_root = ProjectSettings.globalize_path("user://").simplify_path()
	return _cached_user_root






















static func _contains_invalid_path_codepoint(path: String) -> bool:
	for i in path.length():
		var codepoint: = path.unicode_at(i)
		if codepoint == 0 or codepoint == 65533:
			return true
	return false












static func validate_resource_path(path: String, for_write: bool = false) -> String:
	if path.is_empty():
		return "Missing required param: path"
	if _contains_invalid_path_codepoint(path):
		return "Path must not contain null bytes or invalid Unicode"
	if not path.begins_with("res://"):
		return "Path must start with res://"
	var confine_err: = _confine_under(path, _res_root(), "res://")
	if not confine_err.is_empty():
		return confine_err
	if for_write:
		return _reject_sensitive_write(path)
	return ""









static func validate_loadable_path(path: String) -> String:
	if path.is_empty():
		return "Missing required param: path"
	if _contains_invalid_path_codepoint(path):
		return "Path must not contain null bytes or invalid Unicode"
	if path.begins_with("uid://"):
		return ""
	if path.begins_with("user://"):
		return _confine_under(path, _user_root(), "user://")
	if path.begins_with("res://"):
		return _confine_under(path, _res_root(), "res://")
	return "Path must start with res://, uid://, or user://"



static func _confine_under(path: String, root: String, label: String) -> String:
	if ".." in path:
		return "Path must not contain '..' (path traversal not allowed)"
	var globalized: = ProjectSettings.globalize_path(path).simplify_path()


	if globalized != root and not globalized.begins_with(root + "/"):
		return "Path must resolve under %s root" % label
	return ""













static func _reject_sensitive_write(path: String) -> String:

















	var normalized: = path.replace("\\", "/").simplify_path()
	var file_lower: = normalized.get_file().to_lower()
	if file_lower == "project.godot":
		return "Refusing to write res://project.godot (project manifest)"
	if file_lower == "override.cfg":
		return "Refusing to write res://override.cfg (startup config override)"


	var segments: = normalized.trim_prefix("res://").split("/", false)
	for segment in segments:
		if segment.to_lower() == ".godot":
			return "Refusing to write under res://.godot/ (editor metadata)"




	if segments.size() >= 2 and segments[0].to_lower() == "addons" and segments[1].to_lower() == "godot_ai":
		return "Refusing to write under res://addons/godot_ai/ (overwriting a loaded plugin script can crash the editor)"
	return ""






static func path_error(path: String, param_name: String = "path", for_write: bool = false) -> Variant:
	if path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: %s" % param_name)
	var err: = validate_resource_path(path, for_write)
	if err.is_empty():
		return null
	return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, "%s: %s" % [param_name, err])





static func loadable_error(path: String, param_name: String = "path") -> Variant:
	if path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: %s" % param_name)
	var err: = validate_loadable_path(path)
	if err.is_empty():
		return null
	return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, "%s: %s" % [param_name, err])
