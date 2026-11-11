@tool
class_name McpStructuredLogRing
extends RefCounted




















const VALID_LEVELS: = ["info", "warn", "error"]

var _max_lines: int
var _storage: Array[Dictionary] = []



var _head: = 0
var _dropped_count: = 0



var _appended_total: = 0


func _init(max_lines: int) -> void :
	_max_lines = max_lines




func _append_entry(entry: Dictionary) -> void :
	if _storage.size() < _max_lines:
		_storage.append(entry)
		_head = _storage.size() % _max_lines
	else:

		_storage[_head] = entry
		_head = (_head + 1) % _max_lines
		_dropped_count += 1
	_appended_total += 1





func _get_range_unlocked(offset: int, count: int) -> Array[Dictionary]:
	var size: = _storage.size()
	var start: = maxi(0, offset)
	var stop: = mini(size, start + count)
	var out: Array[Dictionary] = []
	for i in range(start, stop):
		out.append(_storage[_logical_to_physical(i)])
	return out


func get_range(offset: int, count: int) -> Array[Dictionary]:
	return _get_range_unlocked(offset, count)


func get_recent(count: int) -> Array[Dictionary]:
	var size: = _storage.size()
	var start: = maxi(0, size - count)
	return _get_range_unlocked(start, size - start)




func _get_since_unlocked(since_seq: int, limit: int = -1) -> Dictionary:
	var size: = _storage.size()
	var oldest_seq: = _appended_total - size
	var start_seq: = mini(maxi(since_seq, oldest_seq), _appended_total)
	var start: = start_seq - oldest_seq
	var available: = maxi(0, size - start)
	var count: = available
	if limit >= 0:
		count = mini(available, limit)
	var entries: = _get_range_unlocked(start, count)
	var next_cursor: = start_seq + entries.size()
	return {
		"cursor": since_seq, 
		"oldest_cursor": oldest_seq, 
		"next_cursor": next_cursor, 
		"appended_total": _appended_total, 
		"truncated": since_seq < oldest_seq, 
		"has_more": next_cursor < _appended_total, 
		"entries": entries, 
	}


func get_since(since_seq: int, limit: int = -1) -> Dictionary:
	return _get_since_unlocked(since_seq, limit)





func _total_count_unlocked() -> int:
	return _storage.size()


func _dropped_count_unlocked() -> int:
	return _dropped_count


func _appended_total_unlocked() -> int:
	return _appended_total


func total_count() -> int:
	return _total_count_unlocked()


func dropped_count() -> int:
	return _dropped_count_unlocked()


func appended_total() -> int:
	return _appended_total_unlocked()





func _logical_to_physical(logical: int) -> int:
	if _storage.size() < _max_lines:
		return logical
	return (_head + logical) % _max_lines





func _clear_storage() -> void :
	_storage.clear()
	_head = 0
	_dropped_count = 0




static func _coerce_level(level: String) -> String:
	return level if level in VALID_LEVELS else "info"
