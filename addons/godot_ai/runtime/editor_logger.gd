@tool
extends Logger























const ADDON_PATH_MARKER: = "/addons/godot_ai/"






const _LogBacktrace: = preload("res://addons/godot_ai/utils/log_backtrace.gd")


var _buffer


func _init(buffer = null) -> void :
	_buffer = buffer


func _log_error(
	function: String, 
	file: String, 
	line: int, 
	code: String, 
	rationale: String, 
	_editor_notify: bool, 
	error_type: int, 
	script_backtraces: Array, 
) -> void :
	if _buffer == null:
		return





	var message: = rationale if not rationale.is_empty() else code
	var message_res_path: = _extract_user_res_path(message)
	if not _is_user_script(file) and script_backtraces.is_empty() and message_res_path.is_empty():
		return
	var resolved: = _LogBacktrace.resolve_error(
		function, file, line, code, rationale, error_type, script_backtraces, 
	)
	if not _is_user_script(resolved.path):
		if message_res_path.is_empty():
			return
		resolved.path = message_res_path
		resolved.line = 0
		resolved.function = function
		_update_resolved_details(resolved)
	if _is_in_godot_ai_addon(resolved.path):
		return
	if not message_res_path.is_empty() and _is_in_godot_ai_addon(message_res_path):
		return
	var details: Dictionary = resolved.get("details", {})
	_buffer.append(resolved.level, resolved.message, resolved.path, resolved.line, resolved.function, details)


static func _update_resolved_details(resolved: Dictionary) -> void :
	var details: Dictionary = resolved.get("details", {})
	if details.is_empty():
		return
	details["resolved"] = {
		"path": resolved.get("path", ""), 
		"line": resolved.get("line", 0), 
		"function": resolved.get("function", ""), 
	}
	resolved["details"] = details




static func _is_user_script(path: String) -> bool:
	if path.is_empty():
		return false



	var lower: = path.to_lower()
	return lower.ends_with(".gd") or lower.ends_with(".cs")





static func _is_in_godot_ai_addon(path: String) -> bool:
	if path.begins_with("res://addons/godot_ai/"):
		return true
	return path.find(ADDON_PATH_MARKER) >= 0







static func _extract_user_res_path(message: String) -> String:
	var start: = message.find("res://")
	if start < 0:
		return ""
	var end: = message.length()
	var quote_end: = message.find("'", start)
	if quote_end >= 0:
		end = mini(end, quote_end)
	quote_end = message.find("\"", start)
	if quote_end >= 0:
		end = mini(end, quote_end)
	quote_end = message.find("`", start)
	if quote_end >= 0:
		end = mini(end, quote_end)
	var path: = message.substr(start, end - start).strip_edges()
	while not path.is_empty() and path.substr(path.length() - 1, 1) in [".", ",", ";", ":", ")"]:
		path = path.substr(0, path.length() - 1)
	if path.is_empty() or _is_in_godot_ai_addon(path):
		return ""
	return path
