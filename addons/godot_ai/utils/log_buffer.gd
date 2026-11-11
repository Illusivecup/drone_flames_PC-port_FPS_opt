@tool
class_name McpLogBuffer
extends RefCounted



const MAX_LINES: = 500








static var console_echo: = true

var _lines: Array[String] = []






var _total_logged: int = 0
var enabled: = true






func log(msg: String, echo: bool = true) -> void :
	var line: = "MCP | %s" % msg
	if enabled and console_echo and echo:
		print(line)
	_lines.append(line)
	if _lines.size() > MAX_LINES:
		_lines = _lines.slice( - MAX_LINES)
	_total_logged += 1


func get_recent(count: int = 50) -> Array[String]:
	var start: = maxi(0, _lines.size() - count)
	var result: Array[String] = []
	result.assign(_lines.slice(start))
	return result


func clear() -> void :
	_lines.clear()



	_total_logged = 0


func total_count() -> int:
	return _lines.size()






func total_logged() -> int:
	return _total_logged
