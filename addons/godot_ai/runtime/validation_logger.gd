@tool
extends Logger









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
	var resolved: = _LogBacktrace.resolve_error(
		function, 
		file, 
		line, 
		code, 
		rationale, 
		error_type, 
		script_backtraces, 
	)
	var details: Dictionary = resolved.get("details", {})
	_buffer.append(resolved.level, resolved.message, resolved.path, resolved.line, resolved.function, details)
