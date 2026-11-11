@tool
extends Logger





















const _LogBacktrace: = preload("res://addons/godot_ai/utils/log_backtrace.gd")

var _pending: Array = []
var _mutex: = Mutex.new()










const _ERROR_TYPE_SCRIPT: = 2
const _MAX_RECENT_SCRIPT_ERRORS: = 64
const _MAX_PENDING: = 4096
const _PENDING_TRIM_THRESHOLD: = _MAX_PENDING * 2


var _dropped: int = 0
var _script_error_seq: int = 0
var _recent_script_errors: Array = []


func _log_message(message: String, error: bool) -> void :

	var level: = "error" if error else "info"
	_append(level, message)


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




	var resolved: = _LogBacktrace.resolve_error(
		function, file, line, code, rationale, error_type, script_backtraces, 
	)
	var loc: = ""
	if not resolved.path.is_empty():
		loc = "%s:%d @ %s" % [resolved.path, resolved.line, resolved.function] if not resolved.function.is_empty() else "%s:%d" % [resolved.path, resolved.line]
	var text: String = "%s (%s)" % [resolved.message, loc] if not loc.is_empty() else resolved.message
	var details: Dictionary = resolved.get("details", {})
	_append(resolved.level, text, details)
	if error_type == _ERROR_TYPE_SCRIPT:


		var funcs: = PackedStringArray()
		for bt: RefCounted in script_backtraces:
			if bt != null and bt.get_frame_count() > 0:
				for i: int in bt.get_frame_count():
					funcs.append(bt.get_frame_function(i))
				break
		_mutex.lock()
		_script_error_seq += 1
		_recent_script_errors.append({"seq": _script_error_seq, "text": text, "funcs": funcs})
		if _recent_script_errors.size() > _MAX_RECENT_SCRIPT_ERRORS:
			_recent_script_errors.remove_at(0)
		_mutex.unlock()


func _append(level: String, text: String, details: Dictionary = {}) -> void :
	_mutex.lock()
	if details.is_empty():
		_pending.append([level, text])
	else:
		_pending.append([level, text, details.duplicate(true)])


	if _pending.size() >= _PENDING_TRIM_THRESHOLD:
		_dropped += _pending.size() - _MAX_PENDING
		_pending = _pending.slice(_pending.size() - _MAX_PENDING)
	_mutex.unlock()



func clear() -> void :
	_mutex.lock()
	_pending.clear()
	_dropped = 0
	_mutex.unlock()




func drain() -> Array:
	_mutex.lock()
	var out: = _pending
	_pending = []
	var dropped: = _dropped
	_dropped = 0
	_mutex.unlock()
	if dropped > 0:
		out.push_front([
			"warn", 
			"[godot_ai] dropped %d older game log lines: the game logged faster than they could be forwarded"
			%dropped, 
		])
	return out


func has_pending() -> bool:
	_mutex.lock()
	var any: = not _pending.is_empty()
	_mutex.unlock()
	return any





func script_error_seq() -> int:
	_mutex.lock()
	var v: = _script_error_seq
	_mutex.unlock()
	return v







func find_script_error_since(since_seq: int, function_name: String) -> String:
	_mutex.lock()
	var found: = ""
	for i in range(_recent_script_errors.size() - 1, -1, -1):
		var rec: Dictionary = _recent_script_errors[i]
		if int(rec["seq"]) <= since_seq:
			break
		if (rec["funcs"] as PackedStringArray).has(function_name):
			found = rec["text"]
			break
	_mutex.unlock()
	return found
