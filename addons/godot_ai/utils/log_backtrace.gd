@tool
class_name McpLogBacktrace
extends RefCounted






































const ERROR_TYPE_NAMES: = {
	0: "error", 
	1: "warning", 
	2: "script", 
	3: "shader", 
}


static func resolve_error(
	function: String, 
	file: String, 
	line: int, 
	code: String, 
	rationale: String, 
	error_type: int, 
	script_backtraces: Array, 
) -> Dictionary:
	var src_file: = file
	var src_line: = line
	var src_function: = function
	var frames: Array[Dictionary] = []



	for bt in script_backtraces:
		if bt != null and bt.get_frame_count() > 0:
			frames = _frames_from_backtrace(bt)
			src_file = str(frames[0].get("path", ""))
			src_line = int(frames[0].get("line", 0))
			src_function = str(frames[0].get("function", ""))
			break
	var message: = rationale if not rationale.is_empty() else code
	return {
		"level": "warn" if error_type == 1 else "error", 
		"message": message, 
		"path": src_file, 
		"line": src_line, 
		"function": src_function, 
		"details": {
			"message": message, 
			"code": code, 
			"rationale": rationale, 
			"error_type": error_type, 
			"error_type_name": _error_type_name(error_type), 
			"source": {
				"path": file, 
				"line": line, 
				"function": function, 
			}, 
			"resolved": {
				"path": src_file, 
				"line": src_line, 
				"function": src_function, 
			}, 
			"frames": frames, 
		}, 
	}


static func _frames_from_backtrace(bt) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	for i in bt.get_frame_count():
		frames.append({
			"path": bt.get_frame_file(i), 
			"line": bt.get_frame_line(i), 
			"function": bt.get_frame_function(i), 
		})
	return frames


static func _error_type_name(error_type: int) -> String:
	return str(ERROR_TYPE_NAMES.get(error_type, "unknown"))
