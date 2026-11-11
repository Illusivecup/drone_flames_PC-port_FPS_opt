@tool
class_name McpCallContext
extends RefCounted











var request_id: String = ""
var session_id: String = ""
var deadline_msec: int = 0
var spec: McpCustomToolSpec = null



var _locator: McpServiceLocator = null



func attach_locator(locator: McpServiceLocator) -> void :
	_locator = locator


func is_expired() -> bool:
	if deadline_msec == 0:
		return false
	return Time.get_ticks_msec() > deadline_msec


func send_deferred(payload: Dictionary) -> void :
	if _locator == null:
		push_error("McpCallContext: cannot send deferred response, locator is null")
		return
	var conn: = _locator.get_connection()
	if conn == null:
		push_error("McpCallContext: cannot send deferred response, connection is null")
		return
	conn.send_deferred_response(request_id, payload)
