@tool
class_name McpEditorLogBuffer
extends McpStructuredLogRing






















const MAX_LINES: = 500

var _mutex: = Mutex.new()
var _error_appended_total: = 0
var _warn_appended_total: = 0


func _init() -> void :
	super._init(MAX_LINES)


func append(level: String, text: String, path: String = "", line: int = 0, function: String = "", details: Dictionary = {}) -> void :
	var coerced_level: = _coerce_level(level)
	var entry: = {
		"source": "editor", 
		"level": coerced_level, 
		"text": text, 
		"path": path, 
		"line": line, 
		"function": function, 
	}
	if not details.is_empty():
		entry["details"] = details.duplicate(true)
	_mutex.lock()
	_append_entry(entry)
	if coerced_level == "error":
		_error_appended_total += 1
	elif coerced_level == "warn":
		_warn_appended_total += 1
	_mutex.unlock()


func get_range(offset: int, count: int) -> Array[Dictionary]:
	_mutex.lock()
	var out: = _get_range_unlocked(offset, count)
	_mutex.unlock()
	return out


func get_recent(count: int) -> Array[Dictionary]:


	_mutex.lock()
	var size: = _total_count_unlocked()
	var start: = maxi(0, size - count)
	var out: = _get_range_unlocked(start, size - start)
	_mutex.unlock()
	return out


func get_since(since_seq: int, limit: int = -1) -> Dictionary:


	_mutex.lock()
	var out: = _get_since_unlocked(since_seq, limit)
	_mutex.unlock()
	return out


func total_count() -> int:
	_mutex.lock()
	var n: = _total_count_unlocked()
	_mutex.unlock()
	return n


func dropped_count() -> int:
	_mutex.lock()
	var n: = _dropped_count_unlocked()
	_mutex.unlock()
	return n


func appended_total() -> int:
	_mutex.lock()
	var n: = _appended_total_unlocked()
	_mutex.unlock()
	return n


func error_appended_total() -> int:
	_mutex.lock()
	var n: = _error_appended_total
	_mutex.unlock()
	return n


func warn_appended_total() -> int:
	_mutex.lock()
	var n: = _warn_appended_total
	_mutex.unlock()
	return n


func clear() -> int:
	_mutex.lock()
	var n: = _total_count_unlocked()
	_clear_storage()
	_error_appended_total = 0
	_warn_appended_total = 0
	_mutex.unlock()
	return n
