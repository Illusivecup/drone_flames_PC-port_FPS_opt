@tool
class_name McpTestRunner
extends RefCounted




const ScriptErrorCapture: = preload("res://addons/godot_ai/testing/script_error_capture.gd")

var _results: Array[Dictionary] = []
var _last_run_ms: int = 0
var _script_error_capture: ScriptErrorCapture = null
var _capture_registered: = false


func _notification(what: int) -> void :
	if what == NOTIFICATION_PREDELETE and _capture_registered and _script_error_capture != null:
		OS.remove_logger(_script_error_capture)
		_capture_registered = false


func run_suite(suite: McpTestSuite, test_filter: String = "", exclude_test_filter: String = "") -> void :
	var owns_capture: = not _capture_registered
	if owns_capture:
		_register_capture()

	_run_suite_tests(suite, test_filter, exclude_test_filter, Callable(), 0, {})

	if owns_capture:
		_unregister_capture()







func _run_suite_tests(
	suite: McpTestSuite, 
	test_filter: String, 
	exclude_test_filter: String, 
	service_cb: Callable, 
	deadline_ticks_ms: int, 
	run_state: Dictionary, 
) -> String:
	var name: = suite.suite_name()
	var methods: = _get_test_methods(suite)
	var exclusions: = _parse_exclusions(exclude_test_filter)

	for method_name in methods:
		if not test_filter.is_empty() and method_name.find(test_filter) == -1:
			continue
		_selected_processed += 1
		if _matches_any_exclusion(method_name, exclusions):
			_results.append({
				"suite": name, 
				"test": method_name, 
				"passed": true, 
				"skipped": true, 
				"message": "Excluded by exclude_test_name filter", 
				"assertion_count": 0, 
				"duration_ms": 0, 
			})
			continue

		var test_start: = Time.get_ticks_msec()
		var entry: = _run_one_test(suite, name, method_name)
		entry["duration_ms"] = Time.get_ticks_msec() - test_start
		_results.append(entry)

		var stop: = _checkpoint(service_cb, deadline_ticks_ms, run_state)
		if not stop.is_empty():
			return stop
	return ""






func _run_one_test(suite: McpTestSuite, name: String, method_name: String) -> Dictionary:
	suite._reset()
	_begin_script_error_capture()
	suite.setup()
	suite.call(method_name)
	suite.teardown()
	var script_errors: = suite._unexpected_script_errors(_end_script_error_capture())
	suite._free_tracked()







	var scene_root_for_cleanup: = _edited_scene_root()
	if scene_root_for_cleanup != null and scene_root_for_cleanup.is_inside_tree():
		_free_mcp_test_nodes_recursive(scene_root_for_cleanup)

	if not script_errors.is_empty():
		var abort_message: = "Aborted by SCRIPT ERROR: %s" % "; ".join(script_errors)
		if suite._failed:
			abort_message += " (after assertion failure: %s)" % suite._message
		return {
			"suite": name, 
			"test": method_name, 
			"passed": false, 
			"message": abort_message, 
			"assertion_count": suite._assertion_count, 
		}




	if suite._skipped and not suite._failed:
		return {
			"suite": name, 
			"test": method_name, 
			"passed": true, 
			"skipped": true, 
			"message": suite._skip_reason, 
			"assertion_count": 0, 
		}

	var passed: = not suite._failed
	var msg: = suite._message


	if passed and suite._assertion_count == 0:
		passed = false
		msg = "Test completed with 0 assertions (likely skipped its logic)"

	return {
		"suite": name, 
		"test": method_name, 
		"passed": passed, 
		"message": msg, 
		"assertion_count": suite._assertion_count, 
	}


func run_suites(suites: Array, suite_filter: String = "", test_filter: String = "", ctx: Dictionary = {}, verbose: bool = false, exclude_test_filter: String = "") -> Dictionary:




	var run: = run_suites_serviced(suites, suite_filter, test_filter, ctx, verbose, exclude_test_filter)
	return run["results"]
















func run_suites_serviced(
	suites: Array, 
	suite_filter: String = "", 
	test_filter: String = "", 
	ctx: Dictionary = {}, 
	verbose: bool = false, 
	exclude_test_filter: String = "", 
	service_cb: Callable = Callable(), 
	deadline_ticks_ms: int = 0, 
	run_state: Dictionary = {}, 
) -> Dictionary:
	_results.clear()
	_selected_processed = 0
	var selected_total: = _count_selected_tests(suites, suite_filter, test_filter)
	var start: = Time.get_ticks_msec()
	var outcome: = ""






	var _prev_console_echo: = McpLogBuffer.console_echo
	McpLogBuffer.console_echo = false



	_unregister_capture()
	_register_capture()

	for suite: McpTestSuite in suites:
		if not suite_filter.is_empty() and suite.suite_name() != suite_filter:
			continue


		var scene_root: = _edited_scene_root()
		var before_children: Array[Node] = []
		if scene_root != null:
			before_children = _get_children_snapshot(scene_root)

		suite._reset_suite_state()
		suite.suite_setup(ctx.duplicate(true))




		if suite._suite_failed:
			_results.append({
				"suite": suite.suite_name(), 
				"test": "<suite_setup>", 
				"passed": false, 
				"message": "suite_setup() failed: %s (subsequent tests not run)" % suite._suite_failed_message, 
				"assertion_count": 0, 
			})

			_selected_processed += _count_selected_tests([suite], "", test_filter)
		elif suite._suite_skipped:
			_results.append({
				"suite": suite.suite_name(), 
				"test": "<suite_setup>", 
				"passed": true, 
				"skipped": true, 
				"message": "suite_setup() skipped: %s" % suite._suite_skipped_reason, 
				"assertion_count": 0, 
			})
			_selected_processed += _count_selected_tests([suite], "", test_filter)
		else:
			outcome = _checkpoint(service_cb, deadline_ticks_ms, run_state)
			if outcome.is_empty():
				outcome = _run_suite_tests(
					suite, test_filter, exclude_test_filter, 
					service_cb, deadline_ticks_ms, run_state
				)


		suite.suite_teardown()
		suite._free_tracked()


		if scene_root != null and scene_root.is_inside_tree():
			_cleanup_leaked_nodes(scene_root, before_children)

		if not outcome.is_empty():
			break

		outcome = _checkpoint(service_cb, deadline_ticks_ms, run_state)
		if not outcome.is_empty():
			break

	_last_run_ms = Time.get_ticks_msec() - start
	McpLogBuffer.console_echo = _prev_console_echo
	_unregister_capture()
	if outcome.is_empty():
		outcome = "completed"
	return {
		"outcome": outcome, 
		"results": get_results(verbose), 
		"tests_not_run": maxi(0, selected_total - _selected_processed), 
	}





var _selected_processed: = 0


func _count_selected_tests(suites: Array, suite_filter: String, test_filter: String) -> int:
	var count: = 0
	for suite: McpTestSuite in suites:
		if not suite_filter.is_empty() and suite.suite_name() != suite_filter:
			continue
		for method_name in _get_test_methods(suite):
			if not test_filter.is_empty() and method_name.find(test_filter) == -1:
				continue
			count += 1
	return count





func _checkpoint(service_cb: Callable, deadline_ticks_ms: int, run_state: Dictionary) -> String:
	return McpConnection.exclusive_run_checkpoint(service_cb, deadline_ticks_ms, run_state)


func _register_capture() -> void :
	if _capture_registered:
		return
	if _script_error_capture == null:
		_script_error_capture = ScriptErrorCapture.new()
	if _script_error_capture == null:
		return
	OS.add_logger(_script_error_capture)
	_capture_registered = true


func _unregister_capture() -> void :
	if not _capture_registered:
		return
	if _script_error_capture == null:
		_capture_registered = false
		return
	OS.remove_logger(_script_error_capture)
	_capture_registered = false


func _begin_script_error_capture() -> void :
	if _script_error_capture != null and _capture_registered:
		_script_error_capture.begin_capture()


func _end_script_error_capture() -> PackedStringArray:
	if _script_error_capture == null or not _capture_registered:
		return PackedStringArray()
	return _script_error_capture.end_capture()


static func _edited_scene_root() -> Node:
	if not Engine.is_editor_hint():
		return null
	return EditorInterface.get_edited_scene_root()


func get_results(verbose: bool = false) -> Dictionary:
	var passed: = 0
	var failed: = 0
	var skipped: = 0
	var failures: Array[Dictionary] = []
	var suites_seen: = {}
	for r in _results:
		suites_seen[r.suite] = true
		if r.get("skipped", false):
			skipped += 1
		elif r.passed:
			passed += 1
		else:
			failed += 1
			failures.append(r)

	var result: = {
		"passed": passed, 
		"failed": failed, 
		"skipped": skipped, 
		"total": _results.size(), 
		"duration_ms": _last_run_ms, 
		"suites_run": suites_seen.keys(), 
		"suite_count": suites_seen.size(), 
	}

	if not failures.is_empty():
		result["failures"] = failures

	if verbose:
		result["results"] = _results

	return result


func clear() -> void :
	_results.clear()
	_last_run_ms = 0


func _get_test_methods(obj: Object) -> Array[String]:
	var methods: Array[String] = []
	for m in obj.get_method_list():
		var name: String = m.get("name", "")
		if name.begins_with("test_"):
			methods.append(name)
	methods.sort()
	return methods


func _get_children_snapshot(node: Node) -> Array[Node]:
	var children: Array[Node] = []
	for child in node.get_children():
		children.append(child)
	return children








func _cleanup_leaked_nodes(scene_root: Node, before: Array[Node]) -> void :
	var before_set: = {}
	for n in before:
		before_set[n] = true
	for child in scene_root.get_children():
		if not before_set.has(child):
			scene_root.remove_child(child)
			child.queue_free()





func _free_mcp_test_nodes_recursive(root: Node) -> void :
	var victims: Array[Node] = []
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var node: Node = queue.pop_back()
		for child in node.get_children():
			if str(child.name).begins_with("_McpTest"):
				victims.append(child)
			else:
				queue.append(child)
	for v in victims:
		if v.get_parent() != null:
			v.get_parent().remove_child(v)
		v.queue_free()







static func _parse_exclusions(filter: String) -> Array[String]:
	var out: Array[String] = []
	if filter.is_empty():
		return out
	for part in filter.split(","):
		var trimmed: = part.strip_edges()
		if not trimmed.is_empty():
			out.append(trimmed)
	return out


static func _matches_any_exclusion(method_name: String, exclusions: Array[String]) -> bool:
	for ex in exclusions:
		if method_name.find(ex) != -1:
			return true
	return false
