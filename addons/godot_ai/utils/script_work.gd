@tool
extends RefCounted






static var _next_id: = 0
static var _active: Dictionary = {}


static func begin(label: String) -> int:
	_next_id += 1
	_active[_next_id] = label
	return _next_id


static func finish(id: int) -> void :
	_active.erase(id)


static func active_count(label: String = "") -> int:
	if label.is_empty():
		return _active.size()
	return _active.values().count(label)


static func quiescence() -> Dictionary:
	if not _active.is_empty():
		return {
			"ok": false, 
			"error": "Wait for active editor work before updating: %s" % str(_active.values()), 
		}
	return {"ok": true}
