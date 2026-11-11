@tool
extends "res://addons/godot_ai/handlers/command_handler.gd"

const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")



const NodeHandler: = preload("res://addons/godot_ai/handlers/node_handler.gd")
const RUN_READY_WAIT_SEC: = 3.0






























const STARTUP_EXECUTION_KEY_PREFIXES: Array[String] = [
	"autoload/", 
	"editor_plugins/", 
]
const STARTUP_EXECUTION_KEYS_EXACT: Array[String] = [
	"application/run/main_scene", 
	"editor/script/templates_search_path", 
	"editor/run/main_run_args", 
]


const MAIN_SCENE_KEY: = "application/run/main_scene"






const STARTUP_EXECUTION_KEY_ALTERNATIVES: = {
	"application/run/main_scene":
		"Use project_manage(op='set_main_scene', params={'path': 'res://<scene>.tscn'}), "
		+ "which accepts only an existing PackedScene inside the project.", 
}





static func startup_execution_key_refusal(key: String) -> String:
	var lowered: = key.strip_edges().to_lower()
	for prefix in STARTUP_EXECUTION_KEY_PREFIXES:
		if lowered.begins_with(prefix):
			if prefix == "autoload/":
				return (
					"Refusing to set '%s' — autoloads run code at project startup. " % key
					+ "Use autoload_manage(op='add'), which validates the script path."
				)
			return (
				"Refusing to set '%s' — keys under '%s' are loaded as code " % [key, prefix]
				+ "at project startup."
			)
	for exact in STARTUP_EXECUTION_KEYS_EXACT:
		if lowered == exact:
			var message: = (
				"Refusing to set '%s' — this key controls what the engine loads " % key
				+ "or executes at project startup."
			)
			var alternative: = str(STARTUP_EXECUTION_KEY_ALTERNATIVES.get(exact, ""))
			if not alternative.is_empty():
				message += " " + alternative
			return message
	return ""

var _connection: McpConnection
var _debugger_plugin
var _editor_log_buffer


func _init(connection: McpConnection = null, debugger_plugin = null, editor_log_buffer = null) -> void :
	_connection = connection
	_debugger_plugin = debugger_plugin
	_editor_log_buffer = editor_log_buffer


func get_project_setting(params: Dictionary) -> Dictionary:
	var key: String = params.get("key", "")
	if key.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: key")

	if not ProjectSettings.has_setting(key):
		return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, "Setting not found: %s" % key)

	var value = ProjectSettings.get_setting(key)
	return {
		"data": {
			"key": key, 
			"value": NodeHandler._serialize_value(value), 
			"type": type_string(typeof(value)), 
		}
	}


func set_project_setting(params: Dictionary) -> Dictionary:
	var key: String = params.get("key", "")
	if key.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: key")

	if not params.has("value"):
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: value")




	var refusal: = startup_execution_key_refusal(key)
	if not refusal.is_empty():
		return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, refusal)

	var value = params.get("value")
	var had_setting: = ProjectSettings.has_setting(key)
	var old_value = ProjectSettings.get_setting(key) if had_setting else null




	if had_setting and typeof(old_value) == TYPE_INT and typeof(value) == TYPE_FLOAT and float(int(value)) == value:
		value = int(value)
	ProjectSettings.set_setting(key, value)
	var err: = ProjectSettings.save()
	if err != OK:
		if had_setting:
			ProjectSettings.set_setting(key, old_value)
		else:
			ProjectSettings.clear(key)
		return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, "Failed to save project settings (error %d)" % err)

	return {
		"data": {
			"key": key, 
			"value": NodeHandler._serialize_value(value), 
			"old_value": NodeHandler._serialize_value(old_value), 
			"type": type_string(typeof(value)), 
			"undoable": false, 
			"reason": "ProjectSettings changes are saved to disk", 
		}
	}














func set_main_scene(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var path_err = McpPathValidator.path_error(path, "path")
	if path_err != null:
		return path_err

	if not ResourceLoader.exists(path):
		return ErrorCodes.make(ErrorCodes.RESOURCE_NOT_FOUND, "Scene not found: %s" % path)





	var resource: = ResourceLoader.load(path)
	if resource == null:
		return ErrorCodes.make(
			ErrorCodes.RESOURCE_NOT_FOUND, 
			"Failed to load scene (it may be corrupt or have a broken dependency): %s" % path
		)
	if not (resource is PackedScene):
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE, 
			"path must be a PackedScene, got %s: %s" % [resource.get_class(), path]
		)

	var had_setting: = ProjectSettings.has_setting(MAIN_SCENE_KEY)
	var old_value = ProjectSettings.get_setting(MAIN_SCENE_KEY) if had_setting else null
	ProjectSettings.set_setting(MAIN_SCENE_KEY, path)
	var err: = ProjectSettings.save()
	if err != OK:
		if had_setting:
			ProjectSettings.set_setting(MAIN_SCENE_KEY, old_value)
		else:
			ProjectSettings.clear(MAIN_SCENE_KEY)
		return ErrorCodes.make(
			ErrorCodes.INTERNAL_ERROR, 
			"Failed to save project settings while setting the main scene: %s (error %d)"
			%[error_string(err), err]
		)

	return {
		"data": {
			"key": MAIN_SCENE_KEY, 
			"path": path, 
			"old_value": NodeHandler._serialize_value(old_value), 
			"undoable": false, 
			"reason": "ProjectSettings changes are saved to disk", 
		}
	}


func run_project(params: Dictionary) -> Dictionary:
	var mode: String = params.get("mode", "main")
	var autosave: bool = params.get("autosave", true)





	if EditorInterface.is_playing_scene():
		return _run_project_current_liveness_response(
			_run_project_base_data(
				mode, 
				str(params.get("scene", "")), 
				autosave, 
				true, 
				"Project was already running; no action taken"
			)
		)

	var validation_error: Variant = null
	if mode == "custom":
		var custom_scene: String = params.get("scene", "")
		if custom_scene.is_empty():
			validation_error = ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: scene (required when mode='custom')")
		else:




			validation_error = McpPathValidator.loadable_error(custom_scene, "scene")
	elif mode != "main" and mode != "current":
		validation_error = ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, "Invalid mode '%s' — use 'main', 'current', or 'custom'" % mode)
	if validation_error != null:
		return validation_error






	if _connection:
		_connection.pause_processing = true




	var autosave_key: = "run/auto_save/save_before_running"
	var editor_settings: EditorSettings = null
	if not autosave:
		editor_settings = EditorInterface.get_editor_settings()
	var prior_autosave: bool = true
	var restore_setting: = false
	if editor_settings != null and editor_settings.has_setting(autosave_key):
		prior_autosave = bool(editor_settings.get_setting(autosave_key))
		editor_settings.set_setting(autosave_key, false)
		restore_setting = true

	if _debugger_plugin != null:
		_debugger_plugin.begin_game_run(_editor_log_cursor(), _game_helper_autoload_expected())

	match mode:
		"main":
			EditorInterface.play_main_scene()
		"current":
			EditorInterface.play_current_scene()
		"custom":
			var scene_path: String = params.get("scene", "")
			EditorInterface.play_custom_scene(scene_path)

	if restore_setting:
		editor_settings.set_setting(autosave_key, prior_autosave)

	if _connection:
		_connection.pause_processing = false

	var base_data: = _run_project_base_data(
		mode, 
		str(params.get("scene", "")), 
		autosave, 
		false, 
		"Play/stop is a runtime action"
	)
	var request_id: String = params.get("_request_id", "")
	if _connection != null and _debugger_plugin != null and not request_id.is_empty():
		_finish_run_project_deferred(request_id, base_data, _connection, _debugger_plugin)
		return McpDispatcher.DEFERRED_RESPONSE

	return _run_project_current_liveness_response(base_data)


func _editor_log_cursor() -> int:
	return _editor_log_buffer.appended_total() if _editor_log_buffer != null else 0


func _game_helper_autoload_expected() -> bool:
	return ProjectSettings.has_setting("autoload/_mcp_game_helper")


static func _run_project_base_data(
	mode: String, 
	scene: String, 
	autosave: bool, 
	was_already_running: bool, 
	reason: String
) -> Dictionary:
	return {
		"mode": mode, 
		"scene": scene, 
		"autosave": autosave, 
		"was_already_running": was_already_running, 
		"undoable": false, 
		"reason": reason, 
	}


func _run_project_current_liveness_response(base_data: Dictionary) -> Dictionary:
	if _debugger_plugin == null:
		return {"data": base_data}
	var status: Dictionary = _debugger_plugin.get_game_status(-1, RUN_READY_WAIT_SEC)


	var errors_info: Dictionary = _debugger_plugin.recent_editor_errors_since(int(status.get("editor_log_cursor", 0)), true)
	return _run_project_response(base_data, _run_project_liveness_decision(status, errors_info))









static func _finish_run_project_deferred(
	request_id: String, base_data: Dictionary, connection, debugger_plugin
) -> void :
	var work: = ScriptWork.begin("run_project")
	await _settle_run_project(request_id, base_data, connection, debugger_plugin)
	ScriptWork.finish(work)


static func _settle_run_project(
	request_id: String, base_data: Dictionary, connection, debugger_plugin
) -> void :
	var tree: SceneTree = connection.get_tree()
	while true:
		await tree.process_frame
		if not is_instance_valid(connection) or not is_instance_valid(debugger_plugin):
			return
		var pre_status: Dictionary = debugger_plugin.get_game_status(-1, RUN_READY_WAIT_SEC)
		if (
			not EditorInterface.is_playing_scene()
			and int(pre_status.get("elapsed_msec", 0)) > 100
			and str(pre_status.get("status", "stopped")) == "launching"
		):
			debugger_plugin.end_game_run()
		var status: Dictionary = debugger_plugin.get_game_status(-1, RUN_READY_WAIT_SEC)
		var errors_info: Dictionary = debugger_plugin.recent_editor_errors_since(int(status.get("editor_log_cursor", 0)))
		var decision: = _run_project_liveness_decision(status, errors_info)
		if not bool(decision.get("resolve", false)):
			continue






		errors_info = debugger_plugin.recent_editor_errors_since(int(status.get("editor_log_cursor", 0)), true)
		decision = _run_project_liveness_decision(status, errors_info)
		connection.send_deferred_response(request_id, _run_project_response(base_data, decision))
		return


static func _run_project_response(base_data: Dictionary, decision: Dictionary) -> Dictionary:
	var data: = base_data.duplicate(true)
	var game_status: Dictionary = decision.get("game_status", {})
	data["game_status"] = game_status
	data["helper_live"] = bool(game_status.get("helper_live", false))
	data["session_active"] = bool(game_status.get("session_active", false))
	if bool(data.get("was_already_running", false)):
		data["reason"] = _run_project_already_running_message(decision)
	else:
		data["reason"] = decision.get("message", data.get("reason", "Play/stop is a runtime action"))
	data["recent_errors"] = decision.get("recent_errors", [])
	data["recent_errors_scope"] = decision.get("recent_errors_scope", "none")
	data["recent_errors_may_predate_run"] = decision.get("recent_errors_may_predate_run", false)
	data["recent_errors_truncated"] = decision.get("recent_errors_truncated", false)
	data.merge(McpDebuggerPlugin.split_errors_by_scope(data["recent_errors"], data["recent_errors_scope"]), true)
	return {"data": data}


static func _run_project_already_running_message(decision: Dictionary) -> String:
	var state: = str(decision.get("liveness_status", "unknown"))
	match state:
		"live":
			var live_errors: Array = decision.get("recent_errors", [])
			if not live_errors.is_empty() and str(decision.get("recent_errors_scope", "none")) == "run":
				return (
					"Project was already running; the Godot AI game helper is live, but %d editor error%s surfaced during this run (first: %s). Check logs_read(source='editor', include_details=true)."
					%[live_errors.size(), "s" if live_errors.size() != 1 else "", _format_editor_error_summary(live_errors[0])]
				)
			return "Project was already running; the Godot AI game helper is live."
		"not_live":
			var errors: Array = decision.get("recent_errors", [])
			var scope: = str(decision.get("recent_errors_scope", "none"))
			if not errors.is_empty() and scope == "run":
				return "Project was already running but failed to load before the Godot AI game helper registered: %s. Check logs_read(source='editor', include_details=true)." % _format_editor_error_summary(errors[0])
			if not errors.is_empty():
				return "Project was already running but is not responding. A recent editor error may be related, but may predate this run: %s. Check logs_read(source='editor', include_details=true)." % _format_editor_error_summary(errors[0])
			return "Project was already running but did not become live before the helper-ready window elapsed. Check logs_read(source='editor', include_details=true) and poll editor_state."
		"break":
			var break_errors: Array = decision.get("recent_errors", [])
			if not break_errors.is_empty() and str(decision.get("recent_errors_scope", "none")) == "run":
				return "Project was already running but the game is parked at a debugger break: %s. Call project_manage(op='stop') to end the run, fix the error, and relaunch." % _format_editor_error_summary(break_errors[0])
			if not break_errors.is_empty():
				return "Project was already running but the game is parked at a debugger break. A recent editor error may be related, but may predate this run: %s. Call project_manage(op='stop') to end the run." % _format_editor_error_summary(break_errors[0])
			return "Project was already running but the game is parked at a debugger break. Call project_manage(op='stop') to end the run; the break reason is in the editor's Debugger panel."
		"no_helper":
			return "Project was already running, but no _mcp_game_helper autoload is expected. Headless or custom-main-loop projects cannot confirm helper liveness."
		"launching":
			return "Project was already running and is still waiting for the Godot AI game helper to register. Poll editor_state shortly."
		"stopped":
			return "Project was already marked playing by the editor, but no active game liveness run exists."
		_:
			return "Project was already running; current liveness status is %s." % state





static func _run_project_liveness_decision(status: Dictionary, errors_info: Dictionary = {}) -> Dictionary:
	var enriched_status: = McpDebuggerPlugin.with_liveness_flags(status)
	var state: = str(status.get("status", "stopped"))
	var recent_errors: Array = errors_info.get("errors", [])
	var errors_scope: = str(errors_info.get("scope", "none"))
	var truncated: = bool(errors_info.get("truncated", false))








	if state == "live" and errors_scope == "retained_recent":
		recent_errors = []
		errors_scope = "none"
	var correlated_error: = not recent_errors.is_empty() and errors_scope == "run"
	var elapsed_msec: = int(status.get("elapsed_msec", 0))
	var ready_wait_msec: = int(status.get("ready_wait_msec", int(RUN_READY_WAIT_SEC * 1000.0)))
	var decision: = {
		"resolve": false, 
		"game_status": enriched_status, 
		"liveness_status": state, 
		"recent_errors": recent_errors, 
		"recent_errors_scope": errors_scope, 
		"recent_errors_may_predate_run": errors_scope == "retained_recent", 
		"recent_errors_truncated": truncated, 
		"message": "", 
	}
	if state == "live":
		decision["resolve"] = true
		if correlated_error:





			decision["message"] = (
				"Game launched and the Godot AI game helper is live, but %d editor error%s surfaced during startup (first: %s) — likely a script that failed to parse or load. Check logs_read(source='editor', include_details=true)."
				%[recent_errors.size(), "s" if recent_errors.size() != 1 else "", _format_editor_error_summary(recent_errors[0])]
			)
			if truncated:
				decision["message"] += " Editor logs since this run may be truncated; showing retained errors."
		else:
			decision["message"] = "Game launched and the Godot AI game helper is live."
	elif state == "break":







		var break_info: Dictionary = status.get("break", {})
		var break_reason: = str(break_info.get("reason", ""))
		if bool(break_info.get("pre_live", true)):
			decision["resolve"] = correlated_error or elapsed_msec >= ready_wait_msec
			var summary: = break_reason
			if correlated_error:
				summary = _format_editor_error_summary(recent_errors[0])
			if summary.is_empty():
				summary = "script parse/load error (reason not captured)"
			decision["message"] = "Game hit a script error during startup and is frozen at a debugger break before the Godot AI game helper registered: %s. The run cannot continue; call project_manage(op='stop'), fix the error, and relaunch. Check logs_read(source='editor', include_details=true)." % summary
		else:
			var reason_suffix: = (": %s" % break_reason) if not break_reason.is_empty() else ""
			decision["resolve"] = true
			decision["message"] = "Game is paused at a debugger break%s. Resume it from the editor's Debugger panel or call project_manage(op='stop')." % reason_suffix
	elif correlated_error:
		decision["resolve"] = true
		decision["liveness_status"] = "not_live"
		decision["message"] = "Game launched but failed to load before the Godot AI game helper registered: %s. Check logs_read(source='editor', include_details=true)." % _format_editor_error_summary(recent_errors[0])
		if truncated:
			decision["message"] += " Editor logs since this run may be truncated; showing retained errors."
	elif state == "not_live":
		decision["resolve"] = true
		if not recent_errors.is_empty():
			decision["message"] = "Game launched but is not responding. A recent editor error may be related, but may predate this run: %s. Check logs_read(source='editor', include_details=true)." % _format_editor_error_summary(recent_errors[0])
		else:
			decision["message"] = "Game launched but did not become live before the helper-ready window elapsed. It may still be booting or may have failed silently; check logs_read(source='editor', include_details=true) and poll editor_state."
	elif state == "no_helper":
		decision["resolve"] = true
		decision["message"] = "Game launched, but no _mcp_game_helper autoload is expected. Headless or custom-main-loop projects cannot confirm helper liveness; use editor_state and viewport/editor tools where applicable."
	elif state == "stopped":
		decision["resolve"] = true
		decision["message"] = "The play session stopped, or no active game liveness run exists, before the Godot AI game helper became live."
	elif state == "launching" and elapsed_msec >= ready_wait_msec:
		decision["resolve"] = true
		decision["message"] = "Game launched but is not yet live after %.1fs; it may still be booting. Poll editor_state and check logs_read(source='editor', include_details=true)." % (float(elapsed_msec) / 1000.0)
	return decision


static func _format_editor_error_summary(entry: Dictionary) -> String:
	return McpSurfacedErrorTracker.format_editor_error_summary(entry)


func stop_project(params: Dictionary) -> Dictionary:




	if not EditorInterface.is_playing_scene():
		return {
			"data": {
				"stopped": true, 
				"was_running": false, 
				"undoable": false, 
				"reason": "Project was not running; no action taken", 
			}
		}

	if _debugger_plugin != null:
		_debugger_plugin.end_game_run()
	EditorInterface.stop_playing_scene()





	var request_id: String = params.get("_request_id", "")
	if _connection != null and not request_id.is_empty():
		_finish_stop_project_deferred(request_id, _connection)
		return McpDispatcher.DEFERRED_RESPONSE



	return {
		"data": {
			"stopped": true, 
			"was_running": true, 
			"undoable": false, 
			"reason": "Play/stop is a runtime action", 
		}
	}








static func _finish_stop_project_deferred(request_id: String, connection) -> void :
	var work: = ScriptWork.begin("stop_project")
	await _settle_stop_project(request_id, connection)
	ScriptWork.finish(work)


static func _settle_stop_project(request_id: String, connection) -> void :
	var tree: SceneTree = connection.get_tree()
	await tree.process_frame
	await tree.process_frame
	if not is_instance_valid(connection):
		return
	connection.send_deferred_response(request_id, {
		"data": {
			"stopped": true, 
			"was_running": true, 
			"undoable": false, 
			"reason": "Play/stop is a runtime action", 
			"readiness_after": McpConnection.get_readiness(), 
		}
	})


func search_filesystem(params: Dictionary) -> Dictionary:
	var name_filter: String = params.get("name", "")
	var type_filter: String = params.get("type", "")
	var path_filter: String = params.get("path", "")

	if name_filter.is_empty() and type_filter.is_empty() and path_filter.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "At least one filter (name, type, path) is required")

	var efs: = EditorInterface.get_resource_filesystem()
	if efs == null:
		return ErrorCodes.make_not_ready(
			ErrorCodes.SUB_EDITOR_UNAVAILABLE, 
			"EditorFileSystem not available", false)

	var results: Array[Dictionary] = []
	_scan_directory(efs.get_filesystem(), name_filter, type_filter, path_filter, results)
	return {"data": {"files": results, "count": results.size()}}


func _scan_directory(dir: EditorFileSystemDirectory, name_filter: String, type_filter: String, path_filter: String, out: Array[Dictionary]) -> void :
	for i in dir.get_file_count():
		var file_path: = dir.get_file_path(i)
		var file_type: = dir.get_file_type(i)

		var matches: = true

		if not name_filter.is_empty():
			if file_path.get_file().to_lower().find(name_filter.to_lower()) == -1:
				matches = false

		if matches and not type_filter.is_empty():
			if file_type != type_filter:
				matches = false

		if matches and not path_filter.is_empty():
			if file_path.to_lower().find(path_filter.to_lower()) == -1:
				matches = false

		if matches:
			out.append({
				"path": file_path, 
				"type": file_type, 
			})

	for i in dir.get_subdir_count():
		_scan_directory(dir.get_subdir(i), name_filter, type_filter, path_filter, out)
