@tool
class_name McpTestSuite
extends RefCounted






func suite_name() -> String:
	return "unnamed"



func suite_setup(_ctx: Dictionary) -> void :
	pass



func setup() -> void :
	pass



func teardown() -> void :
	pass



func suite_teardown() -> void :
	pass




var _tracked_objects: Array[Object] = []





func track(obj: Object) -> Object:
	if obj != null and not obj is RefCounted:
		_tracked_objects.append(obj)
	return obj




func _free_tracked() -> void :
	for obj in _tracked_objects:
		if not is_instance_valid(obj) or (obj is Node and obj.is_queued_for_deletion()):
			continue
		if obj is Node:
			var parent: = (obj as Node).get_parent()
			if parent != null:
				parent.remove_child(obj)
		obj.free()
	_tracked_objects.clear()




var _failed: bool = false
var _message: String = ""
var _assertion_count: int = 0
var _skipped: bool = false
var _skip_reason: String = ""
var _expected_script_error_substrings: Array[String] = []



var _suite_failed: bool = false
var _suite_failed_message: String = ""
var _suite_skipped: bool = false
var _suite_skipped_reason: String = ""


func _reset() -> void :
	_failed = false
	_message = ""
	_assertion_count = 0
	_skipped = false
	_skip_reason = ""
	_expected_script_error_substrings.clear()


func _reset_suite_state() -> void :
	_suite_failed = false
	_suite_failed_message = ""
	_suite_skipped = false
	_suite_skipped_reason = ""





func skip(reason: String = "") -> void :
	_skipped = true
	_skip_reason = reason












func fail_setup(reason: String) -> void :
	_suite_failed = true
	_suite_failed_message = reason





func skip_suite(reason: String) -> void :
	_suite_skipped = true
	_suite_skipped_reason = reason





func expect_script_error_containing(substring: String) -> void :
	_expected_script_error_substrings.append(substring)


func _unexpected_script_errors(captured: PackedStringArray) -> PackedStringArray:
	var unexpected: = PackedStringArray()
	var remaining: = _expected_script_error_substrings.duplicate()
	for error in captured:
		var matched_index: = -1
		for i in range(remaining.size()):
			if error.find(remaining[i]) != -1:
				matched_index = i
				break
		if matched_index == -1:
			unexpected.append(error)
		else:
			remaining.remove_at(matched_index)
	return unexpected








func editor_undo(undo_redo: EditorUndoRedoManager) -> bool:
	for ur in _collect_histories(undo_redo):
		if ur.undo():
			return true
	return false



func editor_redo(undo_redo: EditorUndoRedoManager) -> bool:
	for ur in _collect_histories(undo_redo):
		if ur.redo():
			return true
	return false


func _collect_histories(undo_redo: EditorUndoRedoManager) -> Array:
	var out: Array = []
	if undo_redo == null:
		return out
	var scene_root: = EditorInterface.get_edited_scene_root()
	if scene_root != null:
		var scene_id: = undo_redo.get_object_history_id(scene_root)
		var scene_ur: = undo_redo.get_history_undo_redo(scene_id)
		if scene_ur != null:
			out.append(scene_ur)
	var global_ur: = undo_redo.get_history_undo_redo(EditorUndoRedoManager.GLOBAL_HISTORY)
	if global_ur != null and not global_ur in out:
		out.append(global_ur)
	return out




func assert_true(condition: bool, msg: String = "") -> void :
	_assertion_count += 1
	if _failed:
		return
	if not condition:
		_failed = true
		_message = msg if msg else "Expected true"


func assert_false(condition: bool, msg: String = "") -> void :
	_assertion_count += 1
	if _failed:
		return
	if condition:
		_failed = true
		_message = msg if msg else "Expected false"


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void :
	_assertion_count += 1
	if _failed:
		return
	if actual != expected:
		_failed = true
		_message = msg if msg else "Expected %s, got %s" % [str(expected), str(actual)]


func assert_ne(actual: Variant, not_expected: Variant, msg: String = "") -> void :
	_assertion_count += 1
	if _failed:
		return
	if actual == not_expected:
		_failed = true
		_message = msg if msg else "Expected value != %s" % str(not_expected)


func assert_gt(actual: Variant, threshold: Variant, msg: String = "") -> void :
	_assertion_count += 1
	if _failed:
		return
	if not (actual > threshold):
		_failed = true
		_message = msg if msg else "Expected %s > %s" % [str(actual), str(threshold)]


func assert_has_key(dict: Variant, key: String, msg: String = "") -> void :
	_assertion_count += 1
	if _failed:
		return
	if not dict is Dictionary:
		_failed = true
		_message = msg if msg else "Expected Dictionary, got %s" % type_string(typeof(dict))
		return
	if not dict.has(key):
		_failed = true
		_message = msg if msg else "Missing key: %s (keys: %s)" % [key, str(dict.keys())]


func assert_contains(haystack: Variant, needle: Variant, msg: String = "") -> void :
	_assertion_count += 1
	if _failed:
		return
	if haystack is String:
		if haystack.find(str(needle)) == -1:
			_failed = true
			_message = msg if msg else "'%s' not found in '%s'" % [str(needle), haystack]
	elif haystack is Array:
		if not haystack.has(needle):
			_failed = true
			_message = msg if msg else "%s not found in array" % str(needle)
	else:
		_failed = true
		_message = msg if msg else "assert_contains requires String or Array"


func assert_is_error(result: Dictionary, expected_code: String = "", msg: String = "") -> void :
	_assertion_count += 1
	if _failed:
		return
	if not result.has("error"):
		_failed = true
		_message = msg if msg else "Expected error response, got: %s" % str(result.keys())
		return
	if expected_code and result.error.get("code", "") != expected_code:
		_failed = true
		_message = msg if msg else "Expected error code %s, got %s" % [expected_code, result.error.get("code", "")]







func _add_control(ctl_name: String, ctl: Control = null) -> String:
	var scene_root: = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		if ctl != null:
			ctl.queue_free()
		return ""
	if ctl == null:
		ctl = Panel.new()
	ctl.name = ctl_name
	scene_root.add_child(ctl)
	ctl.owner = scene_root
	return "/" + scene_root.name + "/" + ctl_name


func _remove_control(path: String) -> void :
	var scene_root: = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return
	var node: = McpScenePath.resolve(path, scene_root)
	if node != null:
		node.get_parent().remove_child(node)
		node.queue_free()
