@tool
class_name McpWindowsPortReservation
extends RefCounted









const NETSH_ARGS: = ["interface", "ipv4", "show", "excludedportrange", "protocol=tcp"]









static var _netsh_cache_text: = ""
static var _netsh_cache_valid: = false
static var _netsh_query_count: = 0




static func is_port_excluded(port: int) -> bool:
	if OS.get_name() != "Windows":
		return false
	var cached: = _get_cached_excluded_output()
	if bool(cached.get("hit", false)):
		return parse_excluded(str(cached.get("text", "")), port)
	var output: Array = []
	var exit_code: = _execute_netsh_excluded_ranges(output)
	if exit_code != 0 or output.is_empty():
		return false
	var text: = str(output[0])
	_store_excluded_output(text)
	return parse_excluded(text, port)


static func _store_excluded_output(text: String) -> void :
	_netsh_cache_text = text
	_netsh_cache_valid = true


static func _get_cached_excluded_output() -> Dictionary:
	if not _netsh_cache_valid:
		return {"hit": false, "text": ""}
	return {"hit": true, "text": _netsh_cache_text}


static func _clear_cache_for_tests() -> void :
	_netsh_cache_text = ""
	_netsh_cache_valid = false


static func netsh_query_count() -> int:
	return _netsh_query_count


static func _execute_netsh_excluded_ranges(output: Array) -> int:
	_netsh_query_count += 1
	return OS.execute("netsh", NETSH_ARGS, output, true)















static func parse_excluded(text: String, port: int) -> bool:
	return _ranges_contain(parse_excluded_ranges(text), port)



static func parse_excluded_ranges(text: String) -> Array[Vector2i]:
	var ranges: Array[Vector2i] = []
	for line in text.split("\n"):
		var trimmed: = line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("-") or trimmed.begins_with("*"):
			continue
		var parts: PackedStringArray = trimmed.split(" ", false)
		if parts.size() < 2:
			continue
		if not parts[0].is_valid_int() or not parts[1].is_valid_int():
			continue
		var start_p: = int(parts[0])
		var end_p: = int(parts[1])
		ranges.append(Vector2i(start_p, end_p))
	return ranges


static func _ranges_contain(ranges: Array[Vector2i], port: int) -> bool:
	for r in ranges:
		if port >= r.x and port <= r.y:
			return true
	return false






static func suggest_non_excluded_port(start: int, span: int = 2048, max_port: int = 65535) -> int:
	if OS.get_name() != "Windows":
		return start
	var cached: = _get_cached_excluded_output()
	if bool(cached.get("hit", false)):
		return suggest_non_excluded_port_from_output(str(cached.get("text", "")), start, span, max_port)
	var output: Array = []
	var exit_code: = _execute_netsh_excluded_ranges(output)
	if exit_code != 0 or output.is_empty():
		return start
	var text: = str(output[0])
	_store_excluded_output(text)
	return suggest_non_excluded_port_from_output(text, start, span, max_port)



static func suggest_non_excluded_port_from_output(text: String, start: int, span: int = 2048, max_port: int = 65535) -> int:
	var ranges: = parse_excluded_ranges(text)
	var limit: = mini(start + span - 1, max_port)
	var p: = start
	while p <= limit:
		var advanced: = false
		for r in ranges:
			if p >= r.x and p <= r.y:
				p = r.y + 1
				advanced = true
				break
		if not advanced:
			return p
	return start
