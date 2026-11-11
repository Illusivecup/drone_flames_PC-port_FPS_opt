@tool
extends "res://addons/godot_ai/handlers/command_handler.gd"












const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")

const CACHE_WARNING: = (
	"Preloaded GDScript dependencies may be stale after source edits. "
	+ "Restart the editor before treating this run as validation of dependency changes. "
	+ "ResourceLoader cache modes do not invalidate GDScript's preload cache."
)




const BUDGET_MIN_SEC: = 30.0
const BUDGET_MAX_SEC: = 3600.0



const BUDGET_DEFAULT_SEC: = 110.0


const CEILING_MARGIN_SEC: = 10.0

var _runner: McpTestRunner
var _undo_redo: EditorUndoRedoManager
var _log_buffer: McpLogBuffer




var _dispatcher


var _connection: McpConnection


func _init(
	undo_redo: EditorUndoRedoManager, 
	log_buffer: McpLogBuffer, 
	dispatcher = null, 
	connection: McpConnection = null, 
) -> void :
	_runner = McpTestRunner.new()
	_undo_redo = undo_redo
	_log_buffer = log_buffer
	_dispatcher = dispatcher
	_connection = connection


func run_tests(params: Dictionary) -> Dictionary:
	var suite_filter: String = params.get("suite", "")
	var test_filter: String = params.get("test_name", "")
	var exclude_test_filter: String = params.get("exclude_test_name", "")
	var verbose: bool = params.get("verbose", false)

	var request_id: String = params.get("_request_id", "")
	var live: = _connection != null and not request_id.is_empty()
	var service_cb: = Callable()
	var deadline_ticks_ms: = 0
	var budget_sec: = 0.0
	var started_ms: = Time.get_ticks_msec()
	var run_state: = {}
	if live:
		budget_sec = _validated_budget_sec(params)
		service_cb = Callable(_connection, "service_transport_during_exclusive_run")
		deadline_ticks_ms = started_ms + int((budget_sec - CEILING_MARGIN_SEC) * 1000.0)



	_runner.clear()

	var discovery: = _discover_suites(service_cb, deadline_ticks_ms, run_state)
	var discovery_outcome: String = discovery.get("outcome", "")
	if not discovery_outcome.is_empty():


		var empty_results: Dictionary = _runner.get_results(verbose)
		if not discovery.errors.is_empty():
			empty_results["load_errors"] = discovery.errors
		return _map_outcome(
			discovery_outcome, "discovery", empty_results, 0, started_ms, budget_sec
		)

	var suites: Array = discovery.suites





	var unknown: = unknown_suite_error(suite_filter, suites)
	if not unknown.is_empty():
		if not discovery.errors.is_empty():
			unknown["error"]["data"]["load_errors"] = discovery.errors
		return unknown

	if suites.is_empty():
		var msg: = "No test suites found in res://tests/"
		if not discovery.errors.is_empty():
			msg += " (%d script(s) failed to load: %s)" % [
				discovery.errors.size(), 
				", ".join(discovery.errors), 
			]
		var no_suites: = {"error": msg, "total": 0, "load_errors": discovery.errors, "cache_warning": CACHE_WARNING}


		_annotate_edited_scene(no_suites)
		return {"data": no_suites}

	var ctx: = {
		"undo_redo": _undo_redo, 
		"log_buffer": _log_buffer, 
		"dispatcher": _dispatcher, 
	}

	var run: Dictionary = _runner.run_suites_serviced(
		suites, suite_filter, test_filter, ctx, verbose, exclude_test_filter, 
		service_cb, deadline_ticks_ms, run_state
	)
	var results: Dictionary = run["results"]
	if not discovery.errors.is_empty():
		results["load_errors"] = discovery.errors
	return _map_outcome(
		run["outcome"], "run", results, run["tests_not_run"], started_ms, budget_sec
	)








static func unknown_suite_error(suite_filter: String, suites: Array) -> Dictionary:
	if suite_filter.is_empty():
		return {}
	var names: = PackedStringArray()
	for suite: McpTestSuite in suites:
		names.append(suite.suite_name())
	if names.has(suite_filter):
		return {}
	var err: = ErrorCodes.make(
		ErrorCodes.INVALID_PARAMS, 
		(
			"No suite named '%s' is registered (%d discovered)."
			+ " If it should exist, discovery may be truncated —"
			+ " re-import and restart the editor (#882)."
		) % [suite_filter, names.size()], 
	)
	err["error"]["data"] = {
		"suite": suite_filter, 
		"suites_available": Array(names), 
		"cache_warning": CACHE_WARNING, 
	}
	return err





func _map_outcome(
	outcome: String, 
	phase: String, 
	results: Dictionary, 
	tests_not_run: int, 
	started_ms: int, 
	budget_sec: float, 
) -> Dictionary:
	results["cache_warning"] = CACHE_WARNING
	var elapsed_ms: = Time.get_ticks_msec() - started_ms
	match outcome:
		"completed":
			_annotate_edited_scene(results)
			return {"data": results}
		"transport_lost":




			results["aborted"] = "transport_lost"
			results["tests_not_run"] = tests_not_run
			_annotate_edited_scene(results)
			return {"data": results}
		"paused":
			var depth: = _connection.pause_depth() if _connection != null else 0
			if _log_buffer != null:
				_log_buffer.log(
					"[error] test run aborted in %s: transport paused at checkpoint (depth %d)"
					%[phase, depth]
				)
			var paused_err: = ErrorCodes.make(
				ErrorCodes.INTERNAL_ERROR, 
				(
					"Test run aborted: the MCP transport was paused at a between-test "
					+ "checkpoint (pause depth %d) — a paused transport cannot service "
					+ "the WebSocket heartbeat, so continuing would starve the session. "
					+ "Partial results: test_manage(op=\"results_get\")."
				) % depth
			)
			paused_err["error"]["data"] = _abort_data(
				phase, results, tests_not_run, elapsed_ms, budget_sec, {"pause_depth": depth}
			)
			return paused_err
		"timeout":
			var timeout_err: = ErrorCodes.make(
				ErrorCodes.TEST_RUN_TIMEOUT, 
				(
					"Test run hit its abort ceiling after %.1fs (budget %.0fs, ceiling = "
					+ "budget - %.0fs): %d passed, %d failed, %d of the selected tests "
					+ "never ran. Narrow the run with suite=/test_name= filters, or fetch "
					+ "the partial results with test_manage(op=\"results_get\")."
				) % [
					elapsed_ms / 1000.0, budget_sec, CEILING_MARGIN_SEC, 
					int(results.get("passed", 0)), int(results.get("failed", 0)), 
					tests_not_run, 
				]
			)
			timeout_err["error"]["data"] = _abort_data(
				phase, results, tests_not_run, elapsed_ms, budget_sec, {}
			)
			return timeout_err

	return ErrorCodes.make(
		ErrorCodes.INTERNAL_ERROR, "Unknown test run outcome '%s'" % outcome
	)


func _abort_data(
	phase: String, 
	results: Dictionary, 
	tests_not_run: int, 
	elapsed_ms: int, 
	budget_sec: float, 
	extra: Dictionary, 
) -> Dictionary:
	var data: = {
		"phase": phase, 
		"cache_warning": CACHE_WARNING, 
		"elapsed_ms": elapsed_ms, 
		"budget_sec": budget_sec, 
		"passed": int(results.get("passed", 0)), 
		"failed": int(results.get("failed", 0)), 
		"skipped": int(results.get("skipped", 0)), 
		"total": int(results.get("total", 0)), 
		"tests_not_run": tests_not_run, 
	}
	data.merge(extra)
	return data






func _validated_budget_sec(params: Dictionary) -> float:
	var raw: Variant = params.get("timeout_budget_sec", null)
	var t: = typeof(raw)
	if t == TYPE_FLOAT or t == TYPE_INT:
		var v: = float(raw)
		if is_finite(v) and v > 0.0:
			return clampf(v, BUDGET_MIN_SEC, BUDGET_MAX_SEC)
	return BUDGET_DEFAULT_SEC







func _annotate_edited_scene(results: Dictionary) -> void :
	var scene_root: = EditorInterface.get_edited_scene_root()
	var edited: = scene_root.scene_file_path if scene_root else ""
	results["edited_scene"] = edited
	var main_scene: = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene.is_empty() or edited == main_scene:
		return
	if int(results.get("failed", 0)) <= 0:
		return
	results["scene_warning"] = (
		"Edited scene is '%s' but the project main scene is '%s'. Many suites "
		%[edited if not edited.is_empty() else "<none>", main_scene]
		+ "assume the main scene is open and will report phantom failures "
		+ "otherwise. If these failures are unexpected, scene_open('%s') and re-run." % main_scene
	)


func get_test_results(params: Dictionary) -> Dictionary:
	var verbose: bool = params.get("verbose", false)
	var results: = _runner.get_results(verbose)
	results["cache_warning"] = CACHE_WARNING
	return {"data": results}








func _discover_suites(
	service_cb: Callable = Callable(), 
	deadline_ticks_ms: int = 0, 
	run_state: Dictionary = {}, 
) -> Dictionary:
	var suites: = []
	var errors: Array[String] = []
	var dir: = DirAccess.open("res://tests")
	if dir == null:
		return {
			"suites": suites, 
			"errors": ["DirAccess.open('res://tests') returned null — directory may not exist"], 
			"outcome": "", 
		}

	dir.list_dir_begin()
	var file_name: = dir.get_next()
	while not file_name.is_empty():
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			var stop: = _discovery_checkpoint(service_cb, deadline_ticks_ms, run_state)
			if not stop.is_empty():
				return {"suites": suites, "errors": errors, "outcome": stop}
			var path: = "res://tests/" + file_name
			var script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if script == null:
				errors.append("%s (load failed — check for parse errors or duplicate methods)" % file_name)
			elif script.can_instantiate():
				var instance = script.new()
				if instance is McpTestSuite:
					suites.append(instance)
				else:
					errors.append("%s (not a McpTestSuite subclass)" % file_name)
			else:



				var reload_error: Error = script.reload(true)
				var base: Variant = script.get_base_script()
				errors.append(
					"%s (cannot instantiate — abstract or broken; reload=%s, base=%s, valid=%s)"
					%[
						file_name, 
						error_string(reload_error), 
						str(base.resource_path) if base != null else "none", 
						str(script.can_instantiate()), 
					]
				)
		file_name = dir.get_next()


	suites.sort_custom( func(a, b) -> bool:
		return a.suite_name() < b.suite_name()
	)
	return {"suites": suites, "errors": errors, "outcome": ""}





func _discovery_checkpoint(
	service_cb: Callable, deadline_ticks_ms: int, run_state: Dictionary
) -> String:
	return McpConnection.exclusive_run_checkpoint(service_cb, deadline_ticks_ms, run_state)
