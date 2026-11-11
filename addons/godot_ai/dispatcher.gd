@tool
class_name McpDispatcher
extends RefCounted




var _command_queue: Array[Dictionary] = []
var _handlers: Dictionary = {}








var _lazy_handler_specs: Dictionary = {}
var _lazy_handler_cache: Dictionary = {}
var _lazy_commands: Dictionary = {}
var _pending_deferred: Dictionary = {}
var _tick_active: = false
var _log_buffer
var _surfaced_error_tracker






var pause_target
var mcp_logging: = true
var deferred_timeout_overrides_ms: Dictionary = {}

const DEFAULT_DEFERRED_TIMEOUT_MS: = 4500
const DEFERRED_TIMEOUT_MS_BY_COMMAND: = {
	"create_script": 4500, 


	"write_file": 4500, 
	"stop_project": 4500, 
	"run_project": 6000, 
	"take_screenshot": 30000, 
	"check_client_status": 30000, 
	"game_eval": 15000, 
	"game_command": 15000, 


	"game_debug_control": 6500, 
	"scan_filesystem": 30000, 
}
const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")
const FuzzySuggestions: = preload("res://addons/godot_ai/utils/fuzzy_suggestions.gd")
const PluginReload: = preload("res://addons/godot_ai/utils/plugin_reload.gd")


func _init(log_buffer: McpLogBuffer, surfaced_error_tracker = null) -> void :
	_log_buffer = log_buffer
	_surfaced_error_tracker = surfaced_error_tracker



func register(command_name: String, handler: Callable) -> void :
	_handlers[command_name] = handler








func register_lazy_handler(handler_key: String, script_path: String, ctor_args: Array) -> void :
	_lazy_handler_specs[handler_key] = {"path": script_path, "args": ctor_args}





func register_lazy(command_name: String, handler_key: String, method: StringName) -> void :
	_lazy_commands[command_name] = {"handler": handler_key, "method": method}

func unregister(command_name: String, handler_key: String) -> void :
	_handlers.erase(command_name)
	_lazy_commands.erase(command_name)





	for entry in _lazy_commands.values():
		if entry.get("handler", "") == handler_key:
			return
	_lazy_handler_cache.erase(handler_key)
	_lazy_handler_specs.erase(handler_key)




func quiesce_for_script_swap() -> Dictionary:


	var work: Dictionary = preload("res://addons/godot_ai/utils/script_work.gd").quiescence()
	if not bool(work.get("ok", false)):
		return work
	if not _pending_deferred.is_empty():
		return {"ok": false, "error": "Wait for pending tool responses before updating."}
	for handler_key in _lazy_handler_cache:
		var instance: Variant = _lazy_handler_cache[handler_key]
		if not is_instance_valid(instance) or not instance.has_method("quiesce_for_script_swap"):
			return {
				"ok": false, 
				"error": "Command handler '%s' cannot prove quiescence for script replacement." % handler_key, 
			}
		var result: Variant = instance.call("quiesce_for_script_swap")
		if not result is Dictionary or not bool(result.get("ok", false)):
			return {
				"ok": false, 
				"error": "Command handler '%s' could not quiesce for script replacement: %s" % [
					handler_key, result, 
				], 
			}
	return {"ok": true}






func clear() -> Dictionary:
	var quiesced: = quiesce_for_script_swap()
	if not bool(quiesced.get("ok", false)):
		return quiesced
	release_after_teardown()
	return {"ok": true}








func release_after_teardown() -> void :
	_handlers.clear()





	_lazy_handler_specs.clear()
	_lazy_handler_cache.clear()
	_lazy_commands.clear()
	_command_queue.clear()
	_pending_deferred.clear()
	_log_buffer = null
	_surfaced_error_tracker = null
	pause_target = null








func clear_command_queue() -> void :
	_command_queue.clear()





func dispatch_direct(command: String, params: Dictionary) -> Dictionary:
	if not has_command(command):
		return ErrorCodes.make(ErrorCodes.UNKNOWN_COMMAND, "Unknown command: %s" % command)






	if params.has("_request_id"):
		params = params.duplicate()
		params.erase("_request_id")
	return _call_handler(command, params)



func has_command(command: String) -> bool:
	return _handlers.has(command) or _lazy_commands.has(command)






func suggest_similar(cmd_name: String, limit: int = 3, threshold: float = 0.5) -> Array[String]:
	return FuzzySuggestions.rank(cmd_name, _registered_command_names(), limit, threshold, 0.0, 0.0)




func _registered_command_names() -> Array:
	var names: Dictionary = {}
	for command in _handlers:
		names[command] = true
	for command in _lazy_commands:
		names[command] = true
	return names.keys()



func enqueue(cmd: Dictionary) -> void :
	_command_queue.append(cmd)


func pending_deferred_count() -> int:
	return _pending_deferred.size()


func clear_deferred_responses() -> void :
	_pending_deferred.clear()


func has_pending_deferred_response(request_id: String) -> bool:
	return request_id.is_empty() or _pending_deferred.has(request_id)


func complete_deferred_response(request_id: String) -> bool:
	if request_id.is_empty():
		return true
	if not _pending_deferred.has(request_id):
		return false
	_pending_deferred.erase(request_id)
	return true









const DEFERRED_RESPONSE: = {"_deferred": true}




func tick(budget_ms: float = 4.0) -> Array[Dictionary]:


	if _tick_active or PluginReload.is_reload_pending():
		return []
	_tick_active = true
	var responses: Array[Dictionary] = _collect_deferred_timeouts()
	var start: = Time.get_ticks_msec()
	var idx: = 0

	while idx < _command_queue.size() and (Time.get_ticks_msec() - start) < budget_ms:
		var cmd: Dictionary = _command_queue[idx]
		var response: = _dispatch(cmd)
		if not response.get("_deferred", false):
			responses.append(response)
		idx += 1
		if PluginReload.is_reload_pending():
			break

	if idx > 0:
		_command_queue = _command_queue.slice(idx)

	_tick_active = false
	return responses


func _dispatch(cmd: Dictionary) -> Dictionary:
	var request_id: String = cmd.get("request_id", "")
	var command: String = cmd.get("command", "")
	var raw_params: Dictionary = cmd.get("params", {})




	var params: Dictionary = raw_params.duplicate()
	params["_request_id"] = request_id

	if mcp_logging:
		_log_buffer.log("[recv] %s(%s)" % [command, JSON.stringify(raw_params)])

	var result: Dictionary

	if has_command(command):
		result = _call_handler(command, params)
	else:
		result = ErrorCodes.make(ErrorCodes.UNKNOWN_COMMAND, "Unknown command: %s" % command)

	if result.get("_deferred", false):





		_register_deferred(request_id, command, int(result.get("_deferred_timeout_ms", 0)))
		if mcp_logging:
			_log_buffer.log("[defer] %s (request %s)" % [command, request_id])
		return result

	result["request_id"] = request_id
	if not result.has("status"):
		result["status"] = "ok"








	result["readiness"] = McpConnection.get_readiness()
	_stamp_error_watermark(result)

	if mcp_logging:
		var status: String = result.get("status", "ok")
		if status == "ok":
			_log_buffer.log("[send] %s -> ok" % command)
		else:
			var err_msg: String = result.get("error", {}).get("message", "unknown")
			_log_buffer.log("[send] %s -> error: %s" % [command, err_msg])

	return result






const _MALFORMED_ARGS_MAX: = 400


func _call_handler(command: String, params: Dictionary) -> Dictionary:
	if not _handlers.has(command):
		var materialize_error: = _materialize_lazy_command(command)
		if not materialize_error.is_empty():
			return materialize_error






	var pause_depth_before: int = pause_target.pause_depth() if pause_target != null else 0
	var result: Dictionary = _handlers[command].call(params)
	if pause_target != null and pause_target.pause_depth() > pause_depth_before:
		var leaked: int = pause_target.pause_depth() - pause_depth_before
		while pause_target.pause_depth() > pause_depth_before:
			pause_target.resume()
		if mcp_logging and _log_buffer != null:
			_log_buffer.log(
				"[error] %s leaked %d pause_processing level(s) — restored (handler crash?)"
				%[command, leaked]
			)



	if result == null or not (result.has("data") or result.has("error") or result.has("_deferred")):
		var safe_params: = params.duplicate()
		safe_params.erase("_request_id")
		var args_json: = JSON.stringify(safe_params)
		if args_json.length() > _MALFORMED_ARGS_MAX:
			args_json = args_json.substr(0, _MALFORMED_ARGS_MAX) + "..."
		var backtrace: = _capture_compact_backtrace()
		var msg: = (
			"Handler '%s' returned malformed result — likely a runtime error in the handler "
			+ "(e.g. param type mismatch). Args received: %s"
		) % [command, args_json]
		if not backtrace.is_empty():
			msg += "\nBacktrace:\n%s" % backtrace
		if mcp_logging and _log_buffer != null:
			var compact_backtrace: = backtrace.replace("\n", " | ")
			_log_buffer.log(
				"[error] %s -> malformed result; args=%s; backtrace=%s"
				%[command, args_json, compact_backtrace]
			)
		return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, msg)
	return result








func _materialize_lazy_command(command: String) -> Dictionary:
	var command_spec: Dictionary = _lazy_commands.get(command, {})
	if command_spec.is_empty():
		return ErrorCodes.make(ErrorCodes.UNKNOWN_COMMAND, "Unknown command: %s" % command)
	var handler_key: String = command_spec["handler"]
	var instance = _lazy_handler_cache.get(handler_key)
	if instance == null:
		var handler_spec: Dictionary = _lazy_handler_specs.get(handler_key, {})
		if handler_spec.is_empty():
			return ErrorCodes.make(
				ErrorCodes.INTERNAL_ERROR, 
				"No lazy handler '%s' declared for command '%s'" % [handler_key, command]
			)


		if not ResourceLoader.exists(handler_spec["path"]):
			return ErrorCodes.make(
				ErrorCodes.INTERNAL_ERROR, 
				"Missing handler script '%s' for command '%s'" % [handler_spec["path"], command]
			)
		var script: = load(handler_spec["path"]) as GDScript
		if script == null:
			return ErrorCodes.make(
				ErrorCodes.INTERNAL_ERROR, 
				"Failed to load handler script '%s' for command '%s'" % [handler_spec["path"], command]
			)
		instance = script.callv("new", handler_spec["args"])
		if instance == null:
			return ErrorCodes.make(
				ErrorCodes.INTERNAL_ERROR, 
				"Failed to construct handler '%s' for command '%s'" % [handler_key, command]
			)
		_lazy_handler_cache[handler_key] = instance
	var method: StringName = command_spec["method"]
	if not instance.has_method(method):
		return ErrorCodes.make(
			ErrorCodes.INTERNAL_ERROR, 
			"Handler '%s' has no method '%s' for command '%s'" % [handler_key, method, command]
		)
	_handlers[command] = Callable(instance, method)
	return {}


func _register_deferred(request_id: String, command: String, timeout_override_ms: int = 0) -> void :
	if request_id.is_empty():
		return




	var timeout_ms: int = (
		timeout_override_ms if timeout_override_ms > 0
		else _deferred_timeout_ms_for_command(command)
	)
	_pending_deferred[request_id] = {
		"command": command, 
		"started_ms": Time.get_ticks_msec(), 
		"timeout_ms": timeout_ms, 
	}


func _deferred_timeout_ms_for_command(command: String) -> int:
	if deferred_timeout_overrides_ms.has(command):
		return int(deferred_timeout_overrides_ms[command])
	return int(DEFERRED_TIMEOUT_MS_BY_COMMAND.get(command, DEFAULT_DEFERRED_TIMEOUT_MS))


func _collect_deferred_timeouts() -> Array[Dictionary]:
	var responses: Array[Dictionary] = []
	if _pending_deferred.is_empty():
		return responses
	var now: = Time.get_ticks_msec()
	for request_id in _pending_deferred.keys():
		var entry: Dictionary = _pending_deferred[request_id]
		var timeout_ms: int = entry.get("timeout_ms", DEFAULT_DEFERRED_TIMEOUT_MS)
		var elapsed_ms: = now - int(entry.get("started_ms", now))
		if elapsed_ms < timeout_ms:
			continue
		_pending_deferred.erase(request_id)
		var command: String = entry.get("command", "")
		var response: = ErrorCodes.make(
			ErrorCodes.DEFERRED_TIMEOUT, 
			"Deferred response for '%s' timed out after %dms" % [command, timeout_ms]
		)
		response["request_id"] = request_id
		response["error"]["data"] = {
			"command": command, 
			"elapsed_ms": elapsed_ms, 
			"timeout_ms": timeout_ms, 
		}




		response["readiness"] = McpConnection.get_readiness()
		_stamp_error_watermark(response)
		responses.append(response)
		if mcp_logging and _log_buffer != null:
			_log_buffer.log("[defer] %s (request %s) -> timeout" % [command, request_id])
	return responses


func _stamp_error_watermark(response: Dictionary) -> void :
	McpSurfacedErrorTracker.stamp_watermark(response, _surfaced_error_tracker)


static func _capture_compact_backtrace(max_frames: int = 8) -> String:
	var traces: Array = Engine.capture_script_backtraces(false)
	for bt in traces:
		if bt != null and not bt.is_empty():
			return _trim_backtrace_string(bt.format(0, 2), max_frames)
	return _format_stack_frames(get_stack(), max_frames)


static func _trim_backtrace_string(text: String, max_frames: int) -> String:
	var lines: = text.strip_edges().split("\n")
	var kept: Array[String] = []
	for i in range(min(lines.size(), max_frames)):
		kept.append(lines[i].strip_edges())
	return "\n".join(kept)


static func _format_stack_frames(frames: Array, max_frames: int) -> String:
	var lines: Array[String] = []
	for i in range(min(frames.size(), max_frames)):
		var frame: Dictionary = frames[i]
		lines.append(
			"%s:%s in %s"
			%[
				frame.get("source", "?"), 
				frame.get("line", 0), 
				frame.get("function", "?"), 
			]
		)
	return "\n".join(lines)
