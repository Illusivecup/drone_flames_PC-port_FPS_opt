@tool
extends "res://addons/godot_ai/handlers/command_handler.gd"

const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")




















const FORBIDDEN_SUBCOMMANDS: = {
	"reload_plugin": "reload_plugin must be called directly so no batch continues during reload", 
	"batch_execute": "batch_execute cannot be nested inside another batch", 
	"run_tests":
		"run_tests is not allowed as a sub-command — a batch runs synchronously "
		+ "with no transport servicing; call the test_run tool directly", 
	"game_command":
		"game_command ops are deferred (their reply arrives out-of-band) and "
		+ "have no completion channel inside a batch — run them as their own tool call", 
	"configure_client":
		"configure_client is deferred and has no completion channel inside a batch — "
		+ "run it as its own tool call", 
	"remove_client":
		"remove_client is deferred and has no completion channel inside a batch — "
		+ "run it as its own tool call", 
}





const MAX_BATCH_COMMANDS: = 500

var _dispatcher: McpDispatcher
var _undo_redo: EditorUndoRedoManager


func _init(dispatcher: McpDispatcher, undo_redo: EditorUndoRedoManager) -> void :
	_dispatcher = dispatcher
	_undo_redo = undo_redo


func batch_execute(params: Dictionary) -> Dictionary:
	var commands = params.get("commands", null)
	if typeof(commands) != TYPE_ARRAY:
		return ErrorCodes.make(ErrorCodes.WRONG_TYPE, "commands must be a list")
	if commands.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "commands must not be empty")
	if commands.size() > MAX_BATCH_COMMANDS:
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			"commands exceeds the %d-command batch cap (got %d) — split into multiple batches" % [MAX_BATCH_COMMANDS, commands.size()]
		)

	var undo: bool = params.get("undo", true)

	for idx in range(commands.size()):
		var item = commands[idx]
		if typeof(item) != TYPE_DICTIONARY:
			return ErrorCodes.make(ErrorCodes.WRONG_TYPE, "commands[%d] must be a dict" % idx)
		var cmd_name: String = item.get("command", "")
		if cmd_name.is_empty():
			return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "commands[%d] missing 'command' field" % idx)
		if FORBIDDEN_SUBCOMMANDS.has(cmd_name):
			return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, 
				"commands[%d]: %s" % [idx, FORBIDDEN_SUBCOMMANDS[cmd_name]])
		if not _dispatcher.has_command(cmd_name):
			return _unknown_command_error(idx, cmd_name)




		if typeof(item.get("params", {})) != TYPE_DICTIONARY:
			return ErrorCodes.make(ErrorCodes.WRONG_TYPE, "commands[%d].params must be a dict" % idx)
		if cmd_name.begins_with("custom_tool:"):
			var _custom_tools: = McpToolRegistry.get_instance()
			if _custom_tools:
				var spec: = _custom_tools.get_spec(cmd_name.trim_prefix("custom_tool:"))






				if spec != null and spec.deferred:
					return ErrorCodes.make(
						ErrorCodes.VALUE_OUT_OF_RANGE, 
						"commands[%d] custom_tool:%s is deferred — its reply outlives the batch response; call it directly instead" % [idx, cmd_name.trim_prefix("custom_tool:")]
					)
				if undo and spec != null and not spec.undoable:
					return ErrorCodes.make(
						ErrorCodes.CUSTOM_TOOL_NOT_UNDOABLE, 
						"commands[%d] custom_tool:%s is not undoable" % [idx, cmd_name.trim_prefix("custom_tool:")]
					)

	var results: Array = []
	var succeeded: = 0
	var stopped_at = null
	var all_undoable: = true












	var committed: Array = []

	for idx in range(commands.size()):
		var item: Dictionary = commands[idx]
		var cmd_name: String = item["command"]
		var sub_params: Dictionary = item.get("params", {})

		var tracked: = _tracked_histories()
		var before: Array = []
		for ur in tracked:
			before.append(ur.get_version())

		var raw_result: Dictionary = _dispatcher.dispatch_direct(cmd_name, sub_params)



		_record_committed(tracked, before, committed)
		var status: String = raw_result.get("status", "ok")

		var result_entry: Dictionary = {"command": cmd_name, "status": status}
		if status == "error":
			result_entry["error"] = raw_result.get("error", {})
			results.append(result_entry)
			stopped_at = idx
			break
		else:
			var data: Dictionary = raw_result.get("data", raw_result)
			result_entry["data"] = data
			if typeof(data) == TYPE_DICTIONARY and data.get("undoable", false) != true:
				all_undoable = false
			results.append(result_entry)
			succeeded += 1

	var rolled_back: = false
	if stopped_at != null and undo and not committed.is_empty():
		rolled_back = _rollback(committed)

	var response_data: Dictionary = {
		"succeeded": succeeded, 
		"stopped_at": stopped_at, 
		"results": results, 
		"undo": undo, 
		"rolled_back": rolled_back, 
		"undoable": stopped_at == null and all_undoable and not rolled_back, 
	}
	if stopped_at != null:
		response_data["error"] = results[-1]["error"]
	return {"data": response_data}










func _tracked_histories() -> Array:
	var out: Array = []
	var scene_root: = EditorInterface.get_edited_scene_root()
	if scene_root != null:
		var scene_ur: = _undo_redo.get_history_undo_redo(
			_undo_redo.get_object_history_id(scene_root)
		)
		if scene_ur != null:
			out.append(scene_ur)
	var global_ur: = _undo_redo.get_history_undo_redo(EditorUndoRedoManager.GLOBAL_HISTORY)
	if global_ur != null and not global_ur in out:
		out.append(global_ur)
	return out







func _record_committed(tracked: Array, before: Array, committed: Array) -> void :
	for i in range(tracked.size()):
		var delta: int = tracked[i].get_version() - int(before[i])
		for _n in range(delta):
			committed.append(tracked[i])





func _unknown_command_error(idx: int, cmd_name: String) -> Dictionary:
	var suggestions: = _dispatcher.suggest_similar(cmd_name)
	var msg: = "commands[%d]: unknown plugin command '%s'. batch_execute expects plugin command names (e.g. 'create_node'), not MCP tool names (e.g. 'node_create')." % [idx, cmd_name]
	if not suggestions.is_empty():
		msg += " Did you mean: %s?" % ", ".join(suggestions)
	var err: = ErrorCodes.make(ErrorCodes.UNKNOWN_COMMAND, msg)
	err["error"]["data"] = {"suggestions": suggestions}
	return err








func _rollback(committed: Array) -> bool:
	if committed.is_empty():
		return false
	var ok: = true
	for i in range(committed.size() - 1, -1, -1):
		if not committed[i].undo():
			ok = false
	return ok
