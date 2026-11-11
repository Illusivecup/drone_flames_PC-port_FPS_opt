@tool
class_name McpDebuggerPlugin
extends EditorDebuggerPlugin

const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")
const ScriptWork: = preload("res://addons/godot_ai/utils/script_work.gd")















const CAPTURE_PREFIX: = "mcp"



const DEFAULT_TIMEOUT_SEC: = 8.0






const GAME_READY_WAIT_SEC: = 20.0

















const EVAL_READY_WAIT_SEC: = 3.0




const EVAL_LIVENESS_WAIT_SEC: = 0.25





const EVAL_COMPILE_GRACE_SEC: = 3.0







const EVAL_PROBE_INTERVAL_SEC: = 0.35
const GAME_DEBUG_CONTROL_TIMEOUT_SEC: = 5.0
const EMBED_SUSPEND_TOGGLE: = 0
const EMBED_NEXT_FRAME: = 1

const VisionRoutingScript: = preload("res://addons/godot_ai/vision_routing.gd")

var _log_buffer: McpLogBuffer
var _game_log_buffer: McpGameLogBuffer
var _editor_log_buffer: McpEditorLogBuffer
var _surfaced_error_tracker
var vision_routing: VisionRoutingScript = null





var _pending: Dictionary = {}




var _eval_ready_frame_waiter: Callable = Callable()





var _game_ready: = false
var _game_run_token: = 0
var _ready_run_token: = -1
var _game_session_id: = -1
var _game_run_active: = false






var _pending_hello_session_id: = -1


var _pre_adoption_log_rotated: = false
var _manual_run_armed: = false
var _game_run_started_msec: = 0
var _game_run_started_editor_cursor: = 0
var _game_run_started_debugger_cursor: = 0
var _game_helper_expected: = true








var _break_active: = false
var _break_can_debug: = false
var _break_reason: = ""
var _break_pre_live: = false
var _break_run_token: = -1
var _break_record_synthesized: = false






const BREAK_FRAME_SCRAPE_DELAYS_SEC: Array[float] = [0.5, 2.0]



func _init(log_buffer: McpLogBuffer = null, game_log_buffer: McpGameLogBuffer = null, editor_log_buffer: McpEditorLogBuffer = null, surfaced_error_tracker = null, vision_routing: VisionRoutingScript = null) -> void :
	_log_buffer = log_buffer
	_game_log_buffer = game_log_buffer
	_editor_log_buffer = editor_log_buffer
	_surfaced_error_tracker = surfaced_error_tracker
	self.vision_routing = vision_routing


func quiesce_for_script_swap() -> Dictionary:
	if not _pending.is_empty():
		return {"ok": false, "error": "Wait for pending game debugger requests before updating."}
	return ScriptWork.quiescence()


func _has_capture(prefix: String) -> bool:
	return prefix == CAPTURE_PREFIX











func _setup_session(session_id: int) -> void :
	_connect_session_stopped(session_id)
	_connect_session_break_signals(session_id)
	if EditorInterface.is_playing_scene() and not _game_run_active:
		_begin_game_run_tracking(_editor_log_cursor(), true, true, true, true, true)
	else:
		_game_ready = false
		_ready_run_token = -1
	_game_session_id = session_id


func begin_game_run(editor_log_cursor: int = 0, helper_expected: bool = true) -> void :
	_begin_game_run_tracking(editor_log_cursor, helper_expected, true, true)


func _begin_game_run_tracking(
	editor_log_cursor: int = 0, 
	helper_expected: bool = true, 
	rotate_game_log: bool = true, 
	sticky_debugger_scan: bool = true, 
	quiet: bool = false, 
	manual_armed: bool = false, 
	keep_session_id: int = -1, 
) -> void :
	_game_run_token += 1
	_game_run_active = true
	_manual_run_armed = manual_armed
	_game_ready = false
	_ready_run_token = -1






	_game_session_id = keep_session_id
	clear_debug_break()
	_game_run_started_msec = Time.get_ticks_msec()
	_game_run_started_editor_cursor = maxi(0, editor_log_cursor)
	if _surfaced_error_tracker != null:
		_surfaced_error_tracker.note_game_run_started(sticky_debugger_scan)
		_game_run_started_debugger_cursor = _surfaced_error_tracker.debugger_promoted_total()
	else:
		_game_run_started_debugger_cursor = 0
	_game_helper_expected = helper_expected
	var run_id: = ""
	if _game_log_buffer and rotate_game_log:
		if _pre_adoption_log_rotated:






			run_id = _game_log_buffer.run_id()
		else:
			run_id = _game_log_buffer.clear_for_new_run()
	_pre_adoption_log_rotated = false
	if _log_buffer and not quiet:
		var log_text: = "[debug] game capture pending run token %d" % _game_run_token
		if not run_id.is_empty():
			log_text += " (run %s)" % run_id
		_log_buffer.log(log_text)



	_replay_pending_hello()


func _editor_log_cursor() -> int:
	return _editor_log_buffer.appended_total() if _editor_log_buffer != null else 0


func end_game_run() -> void :
	_fail_pending_evals_not_ready(
		"The game run ended before game_eval completed — the game stopped, crashed, or is restarting. Confirm it is running and retry."
	)
	_fail_pending_game_debug_controls_not_ready(
		"The game run ended before runtime control completed — confirm it is running and retry."
	)

	_pending_hello_session_id = -1
	_pre_adoption_log_rotated = false
	_game_run_active = false
	_manual_run_armed = false
	_game_ready = false
	_ready_run_token = -1
	_game_session_id = -1
	clear_debug_break()
	if _surfaced_error_tracker != null:
		_surfaced_error_tracker.note_game_run_stopped()










func note_editor_play_started() -> void :
	if _game_run_active:
		return


	var attached_session: = _game_session_id
	var had_break: = _break_active
	var break_can_debug: = _break_can_debug
	var break_reason: = _break_reason
	_begin_game_run_tracking(
		_editor_log_cursor(), true, true, true, true, true, attached_session
	)
	if had_break:






		note_debug_break(break_can_debug, break_reason)









func note_editor_play_stopped() -> void :
	if not _game_run_active:


		_pending_hello_session_id = -1
		_pre_adoption_log_rotated = false
		return
	end_game_run()








func _accept_game_hello(session_id: int) -> void :
	_pending_hello_session_id = -1




	if session_id != -1:
		_game_session_id = session_id
	_game_ready = true
	_ready_run_token = _game_run_token





	if _surfaced_error_tracker != null:
		_surfaced_error_tracker.schedule_deferred_scans()
	if _log_buffer:
		if _game_log_buffer:
			_log_buffer.log("[debug] <- mcp:hello from game_helper (run %s)" % _game_log_buffer.run_id())
		else:
			_log_buffer.log("[debug] <- mcp:hello from game_helper")




func _replay_pending_hello() -> void :
	if _pending_hello_session_id == -1:
		return
	var held: = _pending_hello_session_id
	if _game_session_id != -1 and held != _game_session_id:


		_pending_hello_session_id = -1
		if _log_buffer:
			_log_buffer.log("[debug] dropped held mcp:hello from debugger session %d (current %d)" % [held, _game_session_id])
		return
	if _log_buffer:
		_log_buffer.log("[debug] replaying held mcp:hello from debugger session %d" % held)
	_accept_game_hello(held)


func _connect_session_stopped(session_id: int) -> void :
	var session = get_session(session_id)
	if session == null:
		return
	var stopped: = Callable(self, "_on_debugger_session_stopped").bind(session_id)
	if not session.stopped.is_connected(stopped):
		session.stopped.connect(stopped)


func _on_debugger_session_stopped(session_id: int) -> void :
	if _game_session_id != -1 and session_id != _game_session_id:
		return






	if not _manual_run_armed and _game_session_id == -1:
		return
	end_game_run()





func _fail_pending_evals_not_ready(message: String) -> void :
	for request_id in _pending.keys():
		var pending: Dictionary = _pending.get(request_id, {})
		if str(pending.get("kind", "")) not in [
			"eval_ready_wait", "eval_liveness", "eval"
		]:
			continue
		var connection: McpConnection = pending.get("connection")
		_clear_pending(str(request_id))
		if connection != null and is_instance_valid(connection):
			_send_error(connection, str(request_id), ErrorCodes.EVAL_GAME_NOT_READY, message)


func _is_current_game_run(run_token: int) -> bool:
	return _game_run_active and _game_run_token == run_token


func _fail_eval_not_ready(request_id: String, message: String) -> void :
	var pending: Dictionary = _pending.get(request_id, {})
	var connection: McpConnection = pending.get("connection")
	_clear_pending(request_id)
	if connection != null and is_instance_valid(connection):
		_send_error(connection, request_id, ErrorCodes.EVAL_GAME_NOT_READY, message)




func _connect_session_break_signals(session_id: int) -> void :
	var session = get_session(session_id)
	if session != null:
		var breaked_cb: = Callable(self, "_on_debugger_session_breaked").bind(session_id)
		if not session.breaked.is_connected(breaked_cb):
			session.breaked.connect(breaked_cb)
		var continued_cb: = Callable(self, "_on_debugger_session_continued").bind(session_id)
		if not session.continued.is_connected(continued_cb):
			session.continued.connect(continued_cb)
	_connect_script_debugger_breaked()








func _connect_script_debugger_breaked() -> void :
	var base: = EditorInterface.get_base_control()
	if base == null:
		return
	var debuggers: Array[Node] = []
	_collect_nodes_of_class(base, "ScriptEditorDebugger", debuggers)
	for dbg in debuggers:
		if not dbg.has_signal("breaked"):
			continue
		var cb: = Callable(self, "_on_script_debugger_breaked")
		if not dbg.is_connected("breaked", cb):
			dbg.connect("breaked", cb)


static func _collect_nodes_of_class(node: Node, klass: String, out: Array[Node]) -> void :
	if node.get_class() == klass:
		out.append(node)
	for child in node.get_children():
		_collect_nodes_of_class(child, klass, out)


func _on_debugger_session_breaked(can_debug: bool, session_id: int) -> void :
	if _game_session_id != -1 and session_id != _game_session_id:
		return
	note_debug_break(can_debug, "")


func _on_debugger_session_continued(session_id: int) -> void :
	if _game_session_id != -1 and session_id != _game_session_id:
		return
	clear_debug_break()



func _on_script_debugger_breaked(reallydid: bool, can_debug: bool, reason: String, _has_stackdump: bool) -> void :
	if not reallydid:
		clear_debug_break()
		return
	note_debug_break(can_debug, reason)






func note_debug_break(can_debug: bool, reason: String) -> void :
	var first_notice: = not _break_active
	_break_active = true
	_break_can_debug = can_debug
	if not reason.is_empty():
		_break_reason = reason
	if not first_notice:
		return
	_break_run_token = _game_run_token
	_break_pre_live = _game_run_active and not is_game_capture_ready()
	_break_record_synthesized = false
	if _log_buffer:
		_log_buffer.log("[debug] debugger break (pre_live=%s can_debug=%s)" % [str(_break_pre_live), str(can_debug)])
	if _break_pre_live:
		_schedule_break_record_synthesis()


func clear_debug_break() -> void :
	_break_active = false
	_break_can_debug = false
	_break_reason = ""
	_break_pre_live = false
	_break_run_token = -1
	_break_record_synthesized = false





func _schedule_break_record_synthesis() -> void :
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var token: = _break_run_token
	for i in BREAK_FRAME_SCRAPE_DELAYS_SEC.size():
		var final: = i == BREAK_FRAME_SCRAPE_DELAYS_SEC.size() - 1
		var timer: = tree.create_timer(BREAK_FRAME_SCRAPE_DELAYS_SEC[i])
		var work: = ScriptWork.begin("debugger_break_scrape")
		timer.timeout.connect( func() -> void :
			_on_break_scrape_tick(token, final)
			ScriptWork.finish(work))


func _on_break_scrape_tick(run_token: int, final: bool) -> void :
	if not _break_active or _break_record_synthesized or run_token != _break_run_token:
		return
	var frames: = _scrape_break_stack_frames()
	if frames.is_empty() and not final:
		return
	synthesize_break_error_record(frames)





func _scrape_break_stack_frames() -> Array[Dictionary]:
	var base: = EditorInterface.get_base_control()
	if base == null:
		return []
	var debuggers: Array[Node] = []
	_collect_nodes_of_class(base, "ScriptEditorDebugger", debuggers)
	for dbg in debuggers:
		var trees: Array[Node] = []
		_collect_nodes_of_class(dbg, "Tree", trees)
		for t in trees:
			var frames: = _frames_from_stack_tree(t as Tree)
			if not frames.is_empty():
				return frames
	return []


static func _frames_from_stack_tree(tree: Tree) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	var root: = tree.get_root()
	if root == null:
		return frames
	var item: = root.get_first_child()
	while item != null:
		var meta = item.get_metadata(0)
		if not (meta is Dictionary and meta.has("file") and meta.has("frame")):
			return []
		frames.append({
			"path": str(meta.get("file", "")), 
			"line": int(meta.get("line", 0)), 
			"function": str(meta.get("function", "")), 
		})
		item = item.get_next()
	return frames






func synthesize_break_error_record(frames: Array[Dictionary]) -> void :
	if _break_record_synthesized:
		return
	_break_record_synthesized = true
	if _surfaced_error_tracker == null:
		return
	var reason: = _break_reason
	if reason.is_empty():
		reason = "Game process broke into the debugger during startup (script parse/load error; reason not captured)"
	var top: Dictionary = frames[0] if not frames.is_empty() else {}
	var location: = {
		"path": str(top.get("path", "")), 
		"line": int(top.get("line", 0)), 
		"function": str(top.get("function", "")), 
	}
	var entry: = {
		"source": "editor", 
		"level": "error", 
		"text": reason, 
		"path": location["path"], 
		"line": location["line"], 
		"function": location["function"], 
		"details": {
			"debugger_tab": "Stack Trace", 
			"message": reason, 
			"error_type_name": "debugger_break", 
			"source": location.duplicate(true), 
			"resolved": location.duplicate(true), 
			"frames": frames.duplicate(true), 
		}, 
	}
	_surfaced_error_tracker.record_synthetic_error(entry)
	if _log_buffer:
		_log_buffer.log("[debug] synthesized boot-break error record: %s" % McpSurfacedErrorTracker.format_editor_error_summary(entry))





func is_game_capture_ready() -> bool:
	return _game_run_active and _game_ready and _ready_run_token == _game_run_token


static func with_liveness_flags(status: Dictionary) -> Dictionary:
	var enriched: = status.duplicate(true)
	var state: = str(enriched.get("status", "stopped"))
	enriched["helper_live"] = state == "live"
	enriched["session_active"] = not state in ["not_live", "stopped"]
	return enriched


func get_game_status(now_msec: int = -1, ready_wait_sec: float = GAME_READY_WAIT_SEC) -> Dictionary:
	var resolved_now: = Time.get_ticks_msec() if now_msec < 0 else now_msec
	var ready_wait_msec: = maxi(0, int(ready_wait_sec * 1000.0))
	var elapsed_msec: = maxi(0, resolved_now - _game_run_started_msec) if _game_run_active else 0

	var status: = "stopped"
	if _game_run_active:



		if _break_active:
			status = "break"
		elif is_game_capture_ready():
			status = "live"
		elif not _game_helper_expected:
			status = "no_helper"
		elif elapsed_msec >= ready_wait_msec:
			status = "not_live"
		else:
			status = "launching"
	var out: = {
		"status": status, 
		"run_token": _game_run_token, 
		"active": _game_run_active, 
		"ready": is_game_capture_ready(), 
		"helper_expected": _game_helper_expected, 
		"run_started_msec": _game_run_started_msec, 
		"elapsed_msec": elapsed_msec, 
		"ready_wait_msec": ready_wait_msec, 
		"editor_log_cursor": _game_run_started_editor_cursor, 
	}
	if status == "break":
		out["break"] = {
			"reason": _break_reason, 
			"can_debug": _break_can_debug, 
			"pre_live": _break_pre_live, 
		}
	return with_liveness_flags(out)


func _explain_not_live(status: Dictionary, code: String = ErrorCodes.INTERNAL_ERROR) -> Dictionary:
	var state: = str(status.get("status", "stopped"))
	var errors_info: = recent_editor_errors_since(int(status.get("editor_log_cursor", 0)))
	var recent_errors: Array = errors_info.get("errors", [])
	var recent_errors_scope: = str(errors_info.get("scope", "none"))
	var truncated: = bool(errors_info.get("truncated", false))
	var data: = {
		"game_status": status.duplicate(true), 
		"recent_errors": recent_errors, 
		"recent_errors_scope": recent_errors_scope, 
		"recent_errors_may_predate_run": recent_errors_scope == "retained_recent", 
		"recent_errors_truncated": truncated, 
	}
	data.merge(split_errors_by_scope(recent_errors, recent_errors_scope), true)
	var message: = ""
	match state:
		"not_live":
			if not recent_errors.is_empty() and recent_errors_scope == "run":
				message = "The game failed to load or crashed before the Godot AI game helper registered: %s. Check logs_read(source='editor', include_details=true)." % _format_editor_error_summary(recent_errors[0])
				if truncated:
					message += " Editor logs since this run may be truncated; showing retained errors."
			elif not recent_errors.is_empty():
				message = "The game is not responding and reported no load errors during this run. A recent editor error may be related, but may predate this run: %s. Check logs_read(source='editor', include_details=true)." % _format_editor_error_summary(recent_errors[0])
			else:
				message = "The game is not responding and reported no load errors before the helper-ready window elapsed. It may still be booting or may have failed silently; check logs_read(source='editor', include_details=true) and retry."
		"break":
			var break_info: Dictionary = status.get("break", {})
			var break_reason: = str(break_info.get("reason", ""))
			var reason_suffix: = (": %s" % break_reason) if not break_reason.is_empty() else ""
			if bool(break_info.get("pre_live", true)):
				message = "The game hit a script error during startup and is frozen at a debugger break%s. It cannot become live; call project_manage(op='stop') to end the run, fix the error, and relaunch. Check logs_read(source='editor', include_details=true)." % reason_suffix
			else:
				message = "The game is paused at a debugger break%s. Resume it from the editor's Debugger panel or call project_manage(op='stop')." % reason_suffix
		"no_helper":
			message = "The running game has no _mcp_game_helper autoload, so game-side tools cannot connect. If this is a headless or custom-main-loop project, use editor_screenshot(source='viewport') where applicable. Otherwise, re-enable the plugin and relaunch the game."
		"launching":
			message = "The game is still starting (%.1fs elapsed); the Godot AI game helper has not registered yet. Retry shortly." % (float(status.get("elapsed_msec", 0)) / 1000.0)
		"stopped":
			message = "The game is not running. Start the project and retry the game-side tool."
		_:
			message = "The game-side tool could not confirm the game is live (status=%s). Check logs_read(source='editor', include_details=true) and retry." % state
	var err: = ErrorCodes.make(code, message)
	var inner: Dictionary = err.get("error", {})
	inner["data"] = data
	err["error"] = inner
	return err


static func split_errors_by_scope(recent_errors: Array, scope: String) -> Dictionary:
	var current_run_errors: Array = []
	var retained_errors: Array = []
	if scope == "run":
		current_run_errors = recent_errors
	elif scope == "retained_recent":
		retained_errors = recent_errors
	return {
		"current_run_errors": current_run_errors, 
		"retained_errors": retained_errors, 
	}






func recent_editor_errors_since(cursor: int, force_debugger_scan: bool = false) -> Dictionary:
	return _recent_editor_errors_since(cursor, force_debugger_scan)


func _recent_editor_errors_since(cursor: int, force_debugger_scan: bool = false) -> Dictionary:
	var out: Array[Dictionary] = []
	var truncated: = false
	if _surfaced_error_tracker != null:
		var captured_by_tracker: Dictionary = _surfaced_error_tracker.editor_entries_since(
			maxi(0, cursor), 
			_game_run_started_debugger_cursor, 
			force_debugger_scan, 
		)
		truncated = bool(captured_by_tracker.get("truncated", false))
		for raw_entry in captured_by_tracker.get("entries", []):
			var compact: = _compact_editor_error(raw_entry)
			if compact.is_empty():
				continue
			out.append(compact)
			if out.size() >= 5:
				break
		if not out.is_empty():
			return {"errors": out, "truncated": truncated, "scope": "run"}
		for raw_entry in _surfaced_error_tracker.retained_recent_editor_entries():
			var compact: = _compact_editor_error(raw_entry, true)
			if compact.is_empty():
				continue
			out.append(compact)
			if out.size() >= 5:
				break
		if not out.is_empty():
			return {"errors": out, "truncated": false, "scope": "retained_recent"}
		return {"errors": out, "truncated": false, "scope": "none"}
	if _editor_log_buffer == null:
		return {"errors": out, "truncated": false, "scope": "none"}
	var captured: Dictionary = _editor_log_buffer.get_since(maxi(0, cursor), -1)
	truncated = bool(captured.get("truncated", false))
	for raw_entry in captured.get("entries", []):
		var compact: = _compact_editor_error(raw_entry)
		if compact.is_empty():
			continue
		out.append(compact)
		if out.size() >= 5:
			break
	if not out.is_empty():
		return {"errors": out, "truncated": truncated, "scope": "run"}

	for raw_entry in _reversed_entries(_editor_log_buffer.get_recent(McpEditorLogBuffer.MAX_LINES)):
		var compact: = _compact_editor_error(raw_entry, true)
		if compact.is_empty():
			continue
		out.append(compact)
		if out.size() >= 5:
			break
	if not out.is_empty():
		return {"errors": out, "truncated": false, "scope": "retained_recent"}
	return {"errors": out, "truncated": false, "scope": "none"}


func _compact_editor_error(raw_entry: Variant, fallback_recent: bool = false) -> Dictionary:
	if not raw_entry is Dictionary:
		return {}
	var entry: = raw_entry as Dictionary
	if str(entry.get("level", "info")) != "error":
		return {}
	var path: = str(entry.get("path", ""))
	if fallback_recent and _is_diagnostic_noise_path(path):
		return {}
	var compact: = {
		"source": "editor", 
		"level": "error", 
		"text": str(entry.get("text", "")), 
		"path": path, 
		"line": int(entry.get("line", 0)), 
		"function": str(entry.get("function", "")), 
	}
	if entry.has("details"):
		compact["details"] = entry["details"].duplicate(true)
	return compact


func _is_diagnostic_noise_path(path: String) -> bool:
	return path.begins_with("res://addons/godot_ai/") or path.begins_with("res://tests/")


func _reversed_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(entries.size() - 1, -1, -1):
		out.append(entries[i])
	return out


func _format_editor_error_summary(entry: Dictionary) -> String:
	return McpSurfacedErrorTracker.format_editor_error_summary(entry)


func _capture(message: String, data: Array, session_id: int) -> bool:

	match message:
		"mcp:screenshot_response":
			_on_screenshot_response(data)
			return true
		"mcp:screenshot_error":
			_on_screenshot_error(data)
			return true
		"mcp:log_batch":
			_on_log_batch(data)
			return true
		"mcp:hello":





			if _game_session_id != -1 and session_id != _game_session_id:
				if _log_buffer:
					_log_buffer.log("[debug] ignored stale mcp:hello from debugger session %d (current %d)" % [session_id, _game_session_id])
				return true
			if not _game_run_active:






				_pending_hello_session_id = session_id






				if _game_log_buffer and not _pre_adoption_log_rotated:
					_game_log_buffer.clear_for_new_run()
					_pre_adoption_log_rotated = true
				if _log_buffer:
					_log_buffer.log("[debug] holding mcp:hello from debugger session %d until the run is adopted" % session_id)
				return true
			_accept_game_hello(session_id)
			return true
		"mcp:eval_liveness_response":
			_on_eval_liveness_response(data)
			return true
		"mcp:debug_status_response":
			_on_debug_status_response(data)
			return true
		"mcp:eval_response":
			_on_eval_response(data)
			return true
		"mcp:eval_error":
			_on_eval_error(data)
			return true
		"mcp:eval_ack":
			_on_eval_ack(data)
			return true
		"mcp:eval_compiled":
			_on_eval_compiled(data)
			return true
		"mcp:eval_runtime_error":
			_on_eval_runtime_error(data)
			return true
		"mcp:game_command_response":
			_on_game_command_response(data)
			return true
		"mcp:game_command_error":
			_on_game_command_error(data)
			return true
	return false


func _on_log_batch(data: Array) -> void :
	if _game_log_buffer == null:
		return

	if data.is_empty() or not (data[0] is Array):
		return
	var entries: Array = data[0]
	for entry in entries:
		if entry is Dictionary:
			var dict_details: Dictionary = {}
			var raw_dict_details = entry.get("details", {})
			if raw_dict_details is Dictionary:
				dict_details = raw_dict_details
			_game_log_buffer.append(str(entry.get("level", "info")), str(entry.get("text", "")), dict_details)
			continue
		if not (entry is Array) or entry.size() < 2:
			continue
		var details: Dictionary = {}
		if entry.size() > 2 and entry[2] is Dictionary:
			details = entry[2]
		_game_log_buffer.append(str(entry[0]), str(entry[1]), details)









func request_game_screenshot(
	request_id: String, 
	max_resolution: int, 
	connection: McpConnection, 
	timeout_sec: float = DEFAULT_TIMEOUT_SEC, 
) -> void :
	if request_id.is_empty():
		push_warning("MCP debugger: screenshot request missing request_id")
		return

	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null:
		_send_error(connection, request_id, ErrorCodes.INTERNAL_ERROR, 
			"Editor main loop is not a SceneTree — cannot schedule capture")
		return

	if is_game_capture_ready():
		_send_take_screenshot(tree, request_id, max_resolution, connection, timeout_sec)
		return





	if _log_buffer:
		_log_buffer.log("[debug] waiting for game_helper hello (%s)" % request_id)
	_wait_then_send(tree, request_id, max_resolution, connection, timeout_sec)





func _wait_then_send(
	tree: SceneTree, 
	request_id: String, 
	max_resolution: int, 
	connection: McpConnection, 
	timeout_sec: float, 
) -> void :
	var work: = ScriptWork.begin("game_screenshot_ready")
	await _settle_capture_ready(tree, request_id, max_resolution, connection, timeout_sec)
	ScriptWork.finish(work)


func _settle_capture_ready(
	tree: SceneTree, request_id: String, max_resolution: int, 
	connection: McpConnection, timeout_sec: float, 
) -> void :
	var deadline: = Time.get_ticks_msec() + int(GAME_READY_WAIT_SEC * 1000.0)





	await tree.process_frame
	while not is_game_capture_ready() and not _break_active and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	if not is_game_capture_ready():
		_send_error_response(connection, request_id, 
			_explain_not_live(get_game_status(-1, GAME_READY_WAIT_SEC), ErrorCodes.INTERNAL_ERROR))
		return
	_send_take_screenshot(tree, request_id, max_resolution, connection, timeout_sec)




func _send_take_screenshot(
	tree: SceneTree, 
	request_id: String, 
	max_resolution: int, 
	connection: McpConnection, 
	timeout_sec: float, 
) -> void :
	var session: EditorDebuggerSession = _first_active_session()
	if session == null:
		_send_error(connection, request_id, ErrorCodes.INTERNAL_ERROR, 
			"No active debugger session — is the game actually running and started from this editor?")
		return

	var timer: SceneTreeTimer = tree.create_timer(timeout_sec)
	var timeout_callable: = func() -> void : _on_timeout(request_id)
	timer.timeout.connect(timeout_callable)
	_pending[request_id] = {
		"connection": connection, 
		"timer": timer, 
		"timeout_callable": timeout_callable, 
	}

	session.send_message("mcp:take_screenshot", [request_id, max_resolution])
	if _log_buffer:
		_log_buffer.log("[debug] -> mcp:take_screenshot (%s)" % request_id)


func _first_active_session() -> EditorDebuggerSession:
	for s in get_sessions():
		if s is EditorDebuggerSession and s.is_active():
			return s
	return null


func _on_screenshot_response(data: Array) -> void :
	if data.size() < 6:
		push_warning("MCP debugger: malformed screenshot response (expected 6 fields, got %d)" % data.size())
		return
	var request_id: String = data[0]
	var pending = _pending.get(request_id)
	if pending == null:

		return
	_clear_pending(request_id)

	var connection: McpConnection = pending.connection
	if connection == null or not is_instance_valid(connection):
		return

	var payload: = {
		"source": "game", 
		"width": int(data[2]), 
		"height": int(data[3]), 
		"original_width": int(data[4]), 
		"original_height": int(data[5]), 
		"format": "png", 
		"image_base64": data[1], 
	}




	if data.size() >= 8:
		payload["frames_drawn"] = int(data[6])
		payload["stale_frame"] = bool(data[7])
		if bool(data[7]):
			payload["note"] = ("The game window appears backgrounded or its main loop is "
				+ "stalled; returning the last rendered frame. Focus the game window and "
				+ "retry for a current frame.")




	if vision_routing != null and vision_routing.is_routing_enabled():
		if vision_routing.route_game_payload(connection, request_id, {"data": payload}):
			return
	connection.send_deferred_response(request_id, {"data": payload})
	if _log_buffer:
		_log_buffer.log("[debug] <- mcp:screenshot_response (%s)" % request_id)


func _on_screenshot_error(data: Array) -> void :
	if data.size() < 2:
		return
	var request_id: String = data[0]
	var message: String = data[1]
	var pending = _pending.get(request_id)
	if pending == null:
		return
	_clear_pending(request_id)
	var connection: McpConnection = pending.connection
	if connection == null or not is_instance_valid(connection):
		return
	_send_error(connection, request_id, ErrorCodes.INTERNAL_ERROR, message)










func _on_timeout(request_id: String) -> void :
	var pending = _pending.get(request_id)
	if pending == null:
		return
	_pending.erase(request_id)
	var connection: McpConnection = pending.connection
	if connection == null or not is_instance_valid(connection):
		return
	var status: = get_game_status(-1, GAME_READY_WAIT_SEC)
	var err: Dictionary
	if status.get("status", "") != "live":
		err = _explain_not_live(status, ErrorCodes.INTERNAL_ERROR)
	else:
		err = ErrorCodes.make(ErrorCodes.GAME_HELPER_TIMEOUT, 
			"The game process did not return a frame. The game window may be backgrounded or its main loop blocked — focus the game window and retry, or use game_command to confirm liveness.")
	_send_error_response(connection, request_id, err)
	if _log_buffer:
		_log_buffer.log("[debug] !! screenshot timeout (%s)" % request_id)


func _send_error(connection: McpConnection, request_id: String, code: String, message: String) -> void :
	_send_error_response(connection, request_id, ErrorCodes.make(code, message))


func _send_error_response(connection: McpConnection, request_id: String, err: Dictionary) -> void :
	if connection == null or not is_instance_valid(connection):
		return
	connection.send_deferred_response(request_id, err)


func _clear_pending(request_id: String) -> void :
	var pending: Dictionary = _pending.get(request_id, {})
	var timer: SceneTreeTimer = pending.get("timer")
	var cb: Callable = pending.get("timeout_callable", Callable())
	if timer != null and timer.timeout.is_connected(cb):
		timer.timeout.disconnect(cb)

	var grace: SceneTreeTimer = pending.get("grace_timer")
	var gcb: Callable = pending.get("grace_callable", Callable())
	if grace != null and grace.timeout.is_connected(gcb):
		grace.timeout.disconnect(gcb)
	var probe: SceneTreeTimer = pending.get("probe_timer")
	var pcb: Callable = pending.get("probe_callable", Callable())
	if probe != null and probe.timeout.is_connected(pcb):
		probe.timeout.disconnect(pcb)
	_pending.erase(request_id)




















func request_game_eval(
	code: String, 
	request_id: String, 
	connection: McpConnection, 
	timeout_sec: float = 10.0, 
) -> void :
	if request_id.is_empty():
		push_warning("MCP debugger: eval request missing request_id")
		return

	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null:
		_send_error(connection, request_id, ErrorCodes.INTERNAL_ERROR, 
			"Editor main loop is not a SceneTree — cannot schedule eval")
		return

	var run_token: = _game_run_token
	if is_game_capture_ready():
		_probe_then_eval(tree, code, request_id, connection, timeout_sec, run_token)
		return

	if _log_buffer:
		_log_buffer.log("[debug] waiting for game_helper hello before eval (%s)" % request_id)
	_wait_then_eval(tree, code, request_id, connection, timeout_sec, run_token)


func _wait_then_eval(
	tree: SceneTree, 
	code: String, 
	request_id: String, 
	connection: McpConnection, 
	timeout_sec: float, 
	run_token: int, 
) -> void :
	var work: = ScriptWork.begin("game_eval_ready")
	await _settle_eval_ready(tree, code, request_id, connection, timeout_sec, run_token)
	ScriptWork.finish(work)


func _settle_eval_ready(
	tree: SceneTree, code: String, request_id: String, 
	connection: McpConnection, timeout_sec: float, run_token: int, 
) -> void :



	_pending[request_id] = {
		"kind": "eval_ready_wait", 
		"connection": connection, 
		"run_token": run_token, 
	}
	var deadline: = Time.get_ticks_msec() + int(EVAL_READY_WAIT_SEC * 1000.0)




	if _eval_ready_frame_waiter.is_valid():
		await _eval_ready_frame_waiter.call()
	else:
		await tree.process_frame
	while (
		_pending.has(request_id)
		and _is_current_game_run(run_token)
		and not is_game_capture_ready()
		and not _break_active
		and Time.get_ticks_msec() < deadline
	):
		if _eval_ready_frame_waiter.is_valid():
			await _eval_ready_frame_waiter.call()
		else:
			await tree.process_frame

	if not _pending.has(request_id):
		return
	if not _is_current_game_run(run_token):
		_fail_eval_not_ready(request_id, 
			"The game run changed before game_eval could start — the game stopped or restarted. Retry against the current run.")
		return
	if not is_game_capture_ready():




		_clear_pending(request_id)
		_send_error_response(connection, request_id, 
			_explain_not_live(get_game_status(-1, EVAL_READY_WAIT_SEC), ErrorCodes.EVAL_GAME_NOT_READY))
		return
	_clear_pending(request_id)
	_probe_then_eval(tree, code, request_id, connection, timeout_sec, run_token)





func _probe_then_eval(
	tree: SceneTree, 
	code: String, 
	request_id: String, 
	connection: McpConnection, 
	timeout_sec: float, 
	run_token: int, 
) -> void :
	if not _is_current_game_run(run_token) or not is_game_capture_ready():
		_send_error(connection, request_id, ErrorCodes.EVAL_GAME_NOT_READY, 
			"The game run changed before game_eval could be checked — the game stopped or restarted. Retry against the current run.")
		return
	var session: EditorDebuggerSession = _first_active_session()
	if session == null:
		_send_error(connection, request_id, ErrorCodes.EVAL_GAME_NOT_READY, 
			"Game-side capture registered but its debugger session is no longer active — the game likely just stopped or is restarting. Confirm it is running and retry.")
		return

	var timer: = tree.create_timer(EVAL_LIVENESS_WAIT_SEC)
	var timeout_callable: = func() -> void : _on_eval_liveness_timeout(request_id)
	timer.timeout.connect(timeout_callable)
	_pending[request_id] = {
		"kind": "eval_liveness", 
		"connection": connection, 
		"timer": timer, 
		"timeout_callable": timeout_callable, 
		"code": code, 
		"eval_timeout_sec": timeout_sec, 
		"run_token": run_token, 
	}
	session.send_message("mcp:eval_liveness", [request_id])
	if _log_buffer:
		_log_buffer.log("[debug] -> mcp:eval_liveness (%s)" % request_id)


func _on_eval_liveness_timeout(request_id: String) -> void :
	var pending_entry = _pending.get(request_id)
	if pending_entry == null or str(pending_entry.get("kind", "")) != "eval_liveness":
		return
	var connection: McpConnection = pending_entry.get("connection")
	_clear_pending(request_id)
	if connection == null or not is_instance_valid(connection):
		return
	_send_error(connection, request_id, ErrorCodes.EVAL_GAME_NOT_READY, 
		("The game helper did not answer the liveness probe within %.0fms — the game may be backgrounded, frozen, stopped, or restarting. Focus the game window (or relaunch it) and retry."
			%(EVAL_LIVENESS_WAIT_SEC * 1000.0)))


func _on_eval_liveness_response(data: Array) -> void :
	if data.size() < 2:
		push_warning("MCP debugger: malformed eval liveness response")
		return
	var request_id: = str(data[0])
	var pending_entry = _pending.get(request_id)
	if pending_entry == null or str(pending_entry.get("kind", "")) != "eval_liveness":
		return
	var connection: McpConnection = pending_entry.get("connection")
	var code: = str(pending_entry.get("code", ""))
	var timeout_sec: = float(pending_entry.get("eval_timeout_sec", 10.0))
	var run_token: = int(pending_entry.get("run_token", -1))
	var loop_live: = bool(data[1])
	_clear_pending(request_id)
	if connection == null or not is_instance_valid(connection):
		return
	if not _is_current_game_run(run_token) or not is_game_capture_ready():
		_send_error(connection, request_id, ErrorCodes.EVAL_GAME_NOT_READY, 
			"The game run changed while game_eval liveness was being checked — the game stopped or restarted. Retry against the current run.")
		return
	if not loop_live:
		_send_error(connection, request_id, ErrorCodes.EVAL_GAME_NOT_READY, 
			"The game helper is registered but its main loop is not advancing — the game window may be backgrounded or the game may be frozen. Focus the game window (or relaunch it) and retry.")
		return
	var current_tree: = Engine.get_main_loop() as SceneTree
	if current_tree == null:
		_send_error(connection, request_id, ErrorCodes.INTERNAL_ERROR, 
			"Editor main loop is not a SceneTree — cannot schedule eval")
		return
	_send_eval(current_tree, code, request_id, connection, timeout_sec)


func _send_eval(
	tree: SceneTree, 
	code: String, 
	request_id: String, 
	connection: McpConnection, 
	timeout_sec: float, 
) -> void :
	var session: EditorDebuggerSession = _first_active_session()
	if session == null:



		_send_error(connection, request_id, ErrorCodes.EVAL_GAME_NOT_READY, 
			"Game-side capture registered but its debugger session is no longer active — the game likely just stopped or is restarting. Confirm it's running and retry.")
		return

	var timer: SceneTreeTimer = tree.create_timer(timeout_sec)
	var timeout_callable: = func() -> void : _on_eval_timeout(request_id, timeout_sec)
	timer.timeout.connect(timeout_callable)





	var grace: SceneTreeTimer = tree.create_timer(EVAL_COMPILE_GRACE_SEC)
	var grace_callable: = func() -> void : _on_eval_grace(request_id)
	grace.timeout.connect(grace_callable)

	_pending[request_id] = {
		"kind": "eval", 
		"connection": connection, 
		"run_token": _game_run_token, 
		"timer": timer, 
		"timeout_callable": timeout_callable, 
		"grace_timer": grace, 
		"grace_callable": grace_callable, 
		"acked": false, 
		"compiled": false, 
	}

	session.send_message("mcp:eval", [request_id, code])
	if _log_buffer:
		_log_buffer.log("[debug] -> mcp:eval (%s)" % request_id)





















func _on_eval_timeout(request_id: String, timeout_sec: float) -> void :
	var pending_entry = _pending.get(request_id)
	if pending_entry == null:
		return
	var run_token: = int(pending_entry.get("run_token", _game_run_token))
	_clear_pending(request_id)
	var conn: McpConnection = pending_entry.connection
	if conn == null or not is_instance_valid(conn):
		return
	if run_token != _game_run_token:
		_send_error(conn, request_id, ErrorCodes.EVAL_GAME_NOT_READY, 
			"The game run changed before game_eval completed — the original game stopped or restarted. Retry against the current run.")
		if _log_buffer:
			_log_buffer.log("[debug] !! eval timeout from prior run (%s, run=%d, current=%d)"
				%[request_id, run_token, _game_run_token])
		return
	var status: = get_game_status(-1, EVAL_READY_WAIT_SEC)
	if str(status.get("status", "")) != "live":
		_send_error_response(conn, request_id, 
			_explain_not_live(status, ErrorCodes.EVAL_GAME_NOT_READY))
		if _log_buffer:
			_log_buffer.log("[debug] !! eval timeout, game not live (%s, status=%s)"
				%[request_id, str(status.get("status", ""))])
		return
	var message: String
	if not bool(pending_entry.get("acked", false)):
		message = ("Game eval was sent but the game never picked it up within %.0fs — "
			+ "its main thread is busy or frozen (a long frame/load, a CPU-bound "
			+ "prior eval, or a backgrounded game window whose loop is throttled). "
			+ "Check logs_read(source='game') and retry.") % timeout_sec
	else:
		message = ("Game eval compiled and started running but never returned within "
			+ "%.0fs — the code is likely stuck in an infinite loop or awaiting a "
			+ "signal/timer that never fires (a backgrounded game window also freezes "
			+ "awaits). Check logs_read(source='game').") % timeout_sec
	_send_error(conn, request_id, ErrorCodes.EVAL_HUNG, message)
	if _log_buffer:
		_log_buffer.log("[debug] !! eval timeout (%s)" % request_id)


func _on_eval_response(data: Array) -> void :
	if data.size() < 2:
		push_warning("MCP debugger: malformed eval response (expected 2 fields, got %d)" % data.size())
		return
	var request_id: String = data[0]
	var pending_entry = _pending.get(request_id)
	if pending_entry == null:
		return
	_clear_pending(request_id)

	var connection: McpConnection = pending_entry.connection
	if connection == null or not is_instance_valid(connection):
		return

	var result_json: String = data[1] if data.size() > 1 else "null"
	var json: = JSON.new()
	var parse_err: = json.parse(result_json)
	connection.send_deferred_response(request_id, {
		"data": {
			"result": json.data if parse_err == OK else result_json, 
			"source": "game", 
		}
	})
	if _log_buffer:
		_log_buffer.log("[debug] <- mcp:eval_response (%s)" % request_id)







const _GAME_EVAL_ERROR_CODES: Array[String] = [
	ErrorCodes.EVAL_HUNG, 
	ErrorCodes.EVAL_RESULT_TOO_LARGE, 
]


func _on_eval_error(data: Array) -> void :
	if data.size() < 2:
		return
	var request_id: String = data[0]
	var message: String = data[1]
	var pending_entry = _pending.get(request_id)
	if pending_entry == null:
		return
	_clear_pending(request_id)
	var connection: McpConnection = pending_entry.connection
	if connection == null or not is_instance_valid(connection):
		return
	var code: = ErrorCodes.INTERNAL_ERROR
	if data.size() > 2 and str(data[2]) in _GAME_EVAL_ERROR_CODES:
		code = str(data[2])
	_send_error(connection, request_id, code, message)
	if _log_buffer:
		_log_buffer.log("[debug] <- mcp:eval_error (%s): %s" % [request_id, message])








func _on_eval_ack(data: Array) -> void :
	if data.is_empty():
		return
	var request_id: String = data[0]
	var pending_entry = _pending.get(request_id)
	if pending_entry == null:
		return
	pending_entry["acked"] = true
	if _log_buffer:
		_log_buffer.log("[debug] <- mcp:eval_ack (%s)" % request_id)







func _on_eval_grace(request_id: String) -> void :
	var pending_entry = _pending.get(request_id)
	if pending_entry == null or pending_entry.get("compiled", false):
		return
	if not pending_entry.get("acked", false):
		if _log_buffer:
			_log_buffer.log("[debug] eval grace: no ack yet, deferring to timeout (%s)" % request_id)
		return
	_clear_pending(request_id)
	var conn: McpConnection = pending_entry.connection
	if conn == null or not is_instance_valid(conn):
		return
	_send_error(conn, request_id, ErrorCodes.EVAL_COMPILE_ERROR, 
		"Game eval failed to compile — likely a GDScript syntax/parse error. The parse error text is in the editor's Output/Debugger panel; it is not capturable from the running game. Check your eval code's syntax.")
	if _log_buffer:
		_log_buffer.log("[debug] !! eval compile error (%s)" % request_id)





func _on_eval_compiled(data: Array) -> void :
	if data.is_empty():
		return
	var request_id: String = data[0]
	var pending_entry = _pending.get(request_id)
	if pending_entry == null:
		return
	pending_entry["compiled"] = true
	if _log_buffer:
		_log_buffer.log("[debug] <- mcp:eval_compiled (%s)" % request_id)



	_arm_eval_probe(request_id)






func _on_eval_runtime_error(data: Array) -> void :
	if data.size() < 2:
		return
	var request_id: String = data[0]
	var message: String = data[1]
	var pending_entry = _pending.get(request_id)
	if pending_entry == null:
		return
	_clear_pending(request_id)
	var connection: McpConnection = pending_entry.connection
	if connection == null or not is_instance_valid(connection):
		return
	var msg: = "Game eval raised a runtime error: %s" % message if not message.is_empty() else "Game eval raised a runtime error (no message captured). Check logs_read(source='game')."
	_send_error(connection, request_id, ErrorCodes.EVAL_RUNTIME_ERROR, msg)
	if _log_buffer:
		_log_buffer.log("[debug] <- mcp:eval_runtime_error (%s): %s" % [request_id, message])







func _arm_eval_probe(request_id: String) -> void :
	var pending_entry = _pending.get(request_id)
	if pending_entry == null:
		return
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var probe_timer: SceneTreeTimer = tree.create_timer(EVAL_PROBE_INTERVAL_SEC)
	var probe_callable: = func() -> void : _on_eval_probe_tick(request_id)
	pending_entry["probe_timer"] = probe_timer
	pending_entry["probe_callable"] = probe_callable
	probe_timer.timeout.connect(probe_callable)





func _on_eval_probe_tick(request_id: String) -> void :
	if not _pending.has(request_id):
		return
	var session: EditorDebuggerSession = _first_active_session()
	if session != null and session.is_active():
		session.send_message("mcp:eval_check", [request_id])
	_arm_eval_probe(request_id)




static func game_debug_verification(
	action: String, state_before: Dictionary, state_after: Dictionary
) -> Dictionary:
	var before_ticks: = int(state_before.get("process_ticks", -1))
	var after_ticks: = int(state_after.get("process_ticks", -1))
	var ticks_advanced: = after_ticks - before_ticks if before_ticks >= 0 and after_ticks >= 0 else -1
	match action:
		"suspend":
			return {"status": "verified" if bool(state_after.get("suspended", false)) else "pending", "ticks_advanced": ticks_advanced}
		"resume":
			return {"status": "verified" if not bool(state_after.get("suspended", true)) else "pending", "ticks_advanced": ticks_advanced}
		"next_frame":
			if before_ticks < 0 or after_ticks < 0:
				return {"status": "failed", "reason": "missing_process_ticks", "ticks_advanced": ticks_advanced}
			if ticks_advanced > 1:
				return {"status": "failed", "reason": "multiple_process_ticks", "ticks_advanced": ticks_advanced}
			if ticks_advanced == 1 and bool(state_after.get("suspended", false)):
				return {"status": "verified", "ticks_advanced": 1}
			return {"status": "pending", "ticks_advanced": ticks_advanced}
	return {"status": "failed", "reason": "unsupported_action", "ticks_advanced": ticks_advanced}


func _active_game_debug_mutation() -> Dictionary:
	for raw_request_id in _pending.keys():
		var pending_entry: Dictionary = _pending.get(raw_request_id, {})
		if str(pending_entry.get("kind", "")) != "game_debug_control":
			continue
		var active_action: = str(pending_entry.get("action", ""))
		if active_action in ["suspend", "resume", "next_frame"]:
			return {"request_id": str(raw_request_id), "action": active_action}
	return {}


func request_game_debug_control(
	action: String, 
	request_id: String, 
	connection: McpConnection, 
	timeout_sec: float = GAME_DEBUG_CONTROL_TIMEOUT_SEC, 
) -> void :
	if request_id.is_empty():
		push_warning("MCP debugger: game debug control missing request_id")
		return



	_begin_game_debug_control.call_deferred(action, request_id, connection, timeout_sec)


func _begin_game_debug_control(
	action: String, 
	request_id: String, 
	connection: McpConnection, 
	timeout_sec: float, 
) -> void :
	if action not in ["suspend", "resume", "next_frame", "debug_status"]:
		_send_error(connection, request_id, ErrorCodes.VALUE_OUT_OF_RANGE, 
			"Unsupported game debug action: %s" % action)
		return
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null:
		_send_error(connection, request_id, ErrorCodes.INTERNAL_ERROR, 
			"Editor main loop is not a SceneTree — cannot schedule game debug control")
		return
	if not is_game_capture_ready():
		_send_error_response(connection, request_id, 
			_explain_not_live(get_game_status(-1, GAME_READY_WAIT_SEC), ErrorCodes.INTERNAL_ERROR))
		return
	if action != "debug_status":
		var active_mutation: = _active_game_debug_mutation()
		if not active_mutation.is_empty():
			var busy: = ErrorCodes.make(
				ErrorCodes.EDITOR_NOT_READY, 
				"Another game runtime-control mutation is already in flight — retry after it completes."
			)
			busy["error"]["data"] = {
				"action": action, 
				"active_action": str(active_mutation.get("action", "")), 
				"retryable": true, 
			}
			_send_error_response(connection, request_id, busy)
			return
	var session: = _first_active_session()
	if session == null:
		_send_error(connection, request_id, ErrorCodes.INTERNAL_ERROR, 
			"No active debugger session — is the game actually running?")
		return
	var timer: = tree.create_timer(timeout_sec)
	var timeout_callable: = func() -> void :
		var pending_entry: Dictionary = _pending.get(request_id, {})
		if pending_entry.is_empty():
			return
		_pending.erase(request_id)
		var conn: McpConnection = pending_entry.get("connection")
		if conn != null and is_instance_valid(conn):
			var err: = ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, 
				"Game debug action '%s' timed out after %.0fs" % [action, timeout_sec])
			err["error"]["data"] = {
				"action": action, 
				"state_before": pending_entry.get("state_before", {}), 
				"state_after": pending_entry.get("state_after", {}), 
				"focus_handoff": pending_entry.get("focus_handoff", {}), 
				"path": pending_entry.get("path", ""), 
				"game_view_ui_synced": pending_entry.get("game_view_ui_synced", false), 
			}
			_send_error_response(conn, request_id, err)
	timer.timeout.connect(timeout_callable)
	_pending[request_id] = {
		"kind": "game_debug_control", 
		"phase": "before", 
		"action": action, 
		"connection": connection, 
		"timer": timer, 
		"timeout_callable": timeout_callable, 
		"run_token": _game_run_token, 
	}
	session.send_message("mcp:debug_status", [request_id])


func _on_debug_status_response(data: Array) -> void :
	if data.size() < 2 or not (data[1] is Dictionary):
		push_warning("MCP debugger: malformed debug_status response")
		return
	var request_id: = str(data[0])
	var pending_entry: Dictionary = _pending.get(request_id, {})
	if str(pending_entry.get("kind", "")) != "game_debug_control":
		return
	var connection: McpConnection = pending_entry.get("connection")
	if not _is_current_game_run(int(pending_entry.get("run_token", -1))):
		_clear_pending(request_id)
		if connection != null and is_instance_valid(connection):
			_send_error(connection, request_id, ErrorCodes.EVAL_GAME_NOT_READY, 
				"The game run changed while runtime control was in flight — retry against the current run.")
		return
	var state: Dictionary = (data[1] as Dictionary).duplicate(true)
	pending_entry["state_after"] = state
	match str(pending_entry.get("phase", "before")):
		"before":
			_handle_game_debug_before(request_id, pending_entry, state)
		"verify":
			_handle_game_debug_verify(request_id, pending_entry, state)
		_:
			_clear_pending(request_id)
			if connection != null and is_instance_valid(connection):
				_send_error(connection, request_id, ErrorCodes.INTERNAL_ERROR, 
					"Invalid game debug control phase")


func _default_focus_handoff() -> Dictionary:
	return {"attempted": false, "main_screen": "", "embedded_process_found": false, "focused": false}


func _handle_game_debug_before(
	request_id: String, pending_entry: Dictionary, state: Dictionary
) -> void :
	var action: = str(pending_entry.get("action", ""))
	var connection: McpConnection = pending_entry.get("connection")
	var focus_handoff: = _default_focus_handoff()
	if action == "debug_status":
		_clear_pending(request_id)
		if connection != null and is_instance_valid(connection):
			connection.send_deferred_response(request_id, {"data": {
				"action": action, "state": state, "focus_handoff": focus_handoff, 
			}})
		return
	var suspended: = bool(state.get("suspended", false))
	if action in ["suspend", "resume"]:
		var desired: = action == "suspend"
		if suspended == desired:
			_clear_pending(request_id)
			if connection != null and is_instance_valid(connection):
				connection.send_deferred_response(request_id, {"data": {
					"action": action, "changed": false, "verified": true, 
					"state_before": state, "state_after": state, 
					"focus_handoff": focus_handoff, 
				}})
			return
	elif action == "next_frame" and not suspended:
		_clear_pending(request_id)
		if connection != null and is_instance_valid(connection):
			_send_error(connection, request_id, ErrorCodes.INVALID_PARAMS, 
				"next_frame requires a suspended game — call suspend first")
		return
	if action == "next_frame":
		focus_handoff = _focus_embedded_game_view()
	var desired_suspended: = action == "suspend"
	var control: = _emit_game_debug_runtime_action(action, desired_suspended)
	if not bool(control.get("ok", false)):
		var err: = ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, 
			"No active debugger path accepted the native game runtime action")
		err["error"]["data"] = {
			"action": action, 
			"reason": control.get("reason", "runtime_control_unavailable"), 
			"focus_handoff": focus_handoff, 
		}
		_clear_pending(request_id)
		if connection != null and is_instance_valid(connection):
			_send_error_response(connection, request_id, err)
		return
	pending_entry["phase"] = "verify"
	pending_entry["state_before"] = state
	pending_entry["focus_handoff"] = focus_handoff
	pending_entry["path"] = str(control.get("path", ""))
	pending_entry["game_view_ui_synced"] = bool(control.get("game_view_ui_synced", false))
	_request_game_debug_verify.call_deferred(request_id)


func _request_game_debug_verify(request_id: String) -> void :
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.process_frame
	var pending_entry: Dictionary = _pending.get(request_id, {})
	if str(pending_entry.get("phase", "")) != "verify":
		return
	var session: = _first_active_session()
	if session == null:
		var connection: McpConnection = pending_entry.get("connection")
		_clear_pending(request_id)
		if connection != null and is_instance_valid(connection):
			_send_error(connection, request_id, ErrorCodes.EVAL_GAME_NOT_READY, 
				"The debugger session ended before runtime control could be verified")
		return
	session.send_message("mcp:debug_status", [request_id])


func _handle_game_debug_verify(
	request_id: String, pending_entry: Dictionary, state_after: Dictionary
) -> void :
	var action: = str(pending_entry.get("action", ""))
	var connection: McpConnection = pending_entry.get("connection")
	var state_before: Dictionary = pending_entry.get("state_before", {})
	var verdict: = game_debug_verification(action, state_before, state_after)
	match str(verdict.get("status", "failed")):
		"pending":
			_request_game_debug_verify.call_deferred(request_id)
			return
		"verified":
			pass
		_:
			var err: = ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, 
				"Game debug action '%s' violated its verification contract" % action)
			err["error"]["data"] = {
				"action": action, 
				"reason": verdict.get("reason", "verification_failed"), 
				"ticks_advanced": verdict.get("ticks_advanced", -1), 
				"state_before": state_before, 
				"state_after": state_after, 
				"focus_handoff": pending_entry.get("focus_handoff", {}), 
				"path": pending_entry.get("path", ""), 
				"game_view_ui_synced": pending_entry.get("game_view_ui_synced", false), 
			}
			_clear_pending(request_id)
			if connection != null and is_instance_valid(connection):
				_send_error_response(connection, request_id, err)
			return
	var payload: = {
		"action": action, 
		"changed": true, 
		"verified": true, 
		"state_before": state_before, 
		"state_after": state_after, 
		"focus_handoff": pending_entry.get("focus_handoff", {}), 
		"path": pending_entry.get("path", ""), 
		"game_view_ui_synced": pending_entry.get("game_view_ui_synced", false), 
	}
	if action == "next_frame":
		payload["ticks_advanced"] = int(verdict.get("ticks_advanced", -1))
	_clear_pending(request_id)
	if connection != null and is_instance_valid(connection):
		connection.send_deferred_response(request_id, {"data": payload})


func _focus_embedded_game_view() -> Dictionary:
	var result: = {
		"attempted": true, 
		"main_screen": "Game", 
		"embedded_process_found": false, 
		"focused": false, 
	}
	EditorInterface.set_main_screen_editor("Game")
	var base: = EditorInterface.get_base_control()
	if base == null:
		return result
	var embedded_nodes: Array[Node] = []
	_collect_nodes_of_class(base, "EmbeddedProcess", embedded_nodes)
	for node in embedded_nodes:
		if node is Control:
			var embedded: = node as Control
			result["embedded_process_found"] = true
			embedded.grab_focus()
			result["focused"] = embedded.has_focus()
			break
	return result


static func direct_game_debug_message(action: String, desired_suspended: bool) -> Dictionary:
	match action:
		"suspend", "resume":
			return {"message": "scene:suspend_changed", "data": [desired_suspended]}
		"next_frame":
			return {"message": "scene:next_frame", "data": []}
	return {}


func _emit_game_debug_runtime_action(action: String, desired_suspended: bool) -> Dictionary:
	var embed_action: = EMBED_NEXT_FRAME if action == "next_frame" else EMBED_SUSPEND_TOGGLE
	var base: = EditorInterface.get_base_control()
	if base != null:
		var debuggers: Array[Node] = []
		_collect_nodes_of_class(base, "ScriptEditorDebugger", debuggers)
		for debugger in debuggers:
			if not debugger.has_signal("embed_shortcut_requested"):
				continue
			if debugger.get_signal_connection_list("embed_shortcut_requested").is_empty():
				continue
			debugger.emit_signal("embed_shortcut_requested", embed_action)
			return {"ok": true, "path": "embed_signal", "game_view_ui_synced": true}

	var session: = _first_active_session()
	if session == null or not session.is_active():
		return {"ok": false, "reason": "no_active_debugger_session"}
	var direct: = direct_game_debug_message(action, desired_suspended)
	if direct.is_empty():
		return {"ok": false, "reason": "unsupported_action"}
	session.send_message(str(direct.message), direct.data as Array)


	return {"ok": true, "path": "direct_session", "game_view_ui_synced": false}


func _fail_pending_game_debug_controls_not_ready(message: String) -> void :
	for request_id in _pending.keys():
		var pending_entry: Dictionary = _pending.get(request_id, {})
		if str(pending_entry.get("kind", "")) != "game_debug_control":
			continue
		var connection: McpConnection = pending_entry.get("connection")
		_clear_pending(str(request_id))
		if connection != null and is_instance_valid(connection):
			_send_error(connection, str(request_id), ErrorCodes.EVAL_GAME_NOT_READY, message)




func request_game_command(
	op: String, 
	params: Dictionary, 
	request_id: String, 
	connection: McpConnection, 
	timeout_sec: float = 10.0, 
) -> void :
	if request_id.is_empty():
		push_warning("MCP debugger: game command request missing request_id")
		return

	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null:
		_send_error(connection, request_id, ErrorCodes.INTERNAL_ERROR, 
			"Editor main loop is not a SceneTree — cannot schedule game command")
		return

	if is_game_capture_ready():
		_send_game_command(tree, op, params, request_id, connection, timeout_sec)
		return

	if _log_buffer:
		_log_buffer.log("[debug] waiting for game_helper hello before game_command (%s)" % request_id)
	_wait_then_game_command(tree, op, params, request_id, connection, timeout_sec)


func _wait_then_game_command(
	tree: SceneTree, 
	op: String, 
	params: Dictionary, 
	request_id: String, 
	connection: McpConnection, 
	timeout_sec: float, 
) -> void :
	var work: = ScriptWork.begin("game_command_ready")
	await _settle_game_command_ready(tree, op, params, request_id, connection, timeout_sec)
	ScriptWork.finish(work)


func _settle_game_command_ready(
	tree: SceneTree, op: String, params: Dictionary, request_id: String, 
	connection: McpConnection, timeout_sec: float, 
) -> void :
	var deadline: = Time.get_ticks_msec() + int(GAME_READY_WAIT_SEC * 1000.0)




	await tree.process_frame
	while not is_game_capture_ready() and not _break_active and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	if not is_game_capture_ready():
		_send_error_response(connection, request_id, 
			_explain_not_live(get_game_status(-1, GAME_READY_WAIT_SEC), ErrorCodes.INTERNAL_ERROR))
		return
	_send_game_command(tree, op, params, request_id, connection, timeout_sec)


func _send_game_command(
	tree: SceneTree, 
	op: String, 
	params: Dictionary, 
	request_id: String, 
	connection: McpConnection, 
	timeout_sec: float, 
) -> void :
	var session: EditorDebuggerSession = _first_active_session()
	if session == null:
		_send_error(connection, request_id, ErrorCodes.INTERNAL_ERROR, 
			"No active debugger session — is the game actually running?")
		return

	var timer: SceneTreeTimer = tree.create_timer(timeout_sec)
	var timeout_callable: = func() -> void :
		var pending_entry = _pending.get(request_id)
		if pending_entry == null:
			return
		_pending.erase(request_id)
		var conn: McpConnection = pending_entry.connection
		if conn == null or not is_instance_valid(conn):
			return
		_send_error(conn, request_id, ErrorCodes.INTERNAL_ERROR, 
			"Game command '%s' timed out after %.0fs" % [op, timeout_sec])
		if _log_buffer:
			_log_buffer.log("[debug] !! game_command timeout (%s)" % request_id)
	timer.timeout.connect(timeout_callable)
	_pending[request_id] = {
		"connection": connection, 
		"timer": timer, 
		"timeout_callable": timeout_callable, 
	}

	session.send_message("mcp:game_command", [request_id, op, JSON.stringify(params)])
	if _log_buffer:
		_log_buffer.log("[debug] -> mcp:game_command %s (%s)" % [op, request_id])


func _on_game_command_response(data: Array) -> void :
	if data.size() < 2:
		push_warning("MCP debugger: malformed game_command response (expected 2 fields, got %d)" % data.size())
		return
	var request_id: String = data[0]
	var pending_entry = _pending.get(request_id)
	if pending_entry == null:
		return
	_clear_pending(request_id)

	var connection: McpConnection = pending_entry.connection
	if connection == null or not is_instance_valid(connection):
		return

	var result_json: String = data[1] if data.size() > 1 else "{}"
	var json: = JSON.new()
	var parse_err: = json.parse(result_json)
	connection.send_deferred_response(request_id, {
		"data": json.data if parse_err == OK else {"source": "game", "result": result_json}
	})
	if _log_buffer:
		_log_buffer.log("[debug] <- mcp:game_command_response (%s)" % request_id)


func _on_game_command_error(data: Array) -> void :
	if data.size() < 2:
		return
	var request_id: String = data[0]
	var message: String = data[1]
	var pending_entry = _pending.get(request_id)
	if pending_entry == null:
		return
	_clear_pending(request_id)
	var connection: McpConnection = pending_entry.connection
	if connection == null or not is_instance_valid(connection):
		return
	_send_error(connection, request_id, ErrorCodes.INTERNAL_ERROR, message)
	if _log_buffer:
		_log_buffer.log("[debug] <- mcp:game_command_error (%s): %s" % [request_id, message])
