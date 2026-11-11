@tool
extends "res://addons/godot_ai/handlers/command_handler.gd"

const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")
const ScriptHandler: = preload("res://addons/godot_ai/handlers/script_handler.gd")









const _SCAN_START_GRACE_MSEC: = 750
const _SCAN_SETTLE_MAX_MSEC: = 28000




const IMPORT_SIDECAR_SUFFIX: = ".import"










static var _scan_in_flight: = false

var _connection: McpConnection


func _init(connection: McpConnection = null) -> void :
	_connection = connection


func read_file(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")

	var path_err = McpPathValidator.path_error(path, "path")
	if path_err != null:
		return path_err

	if not FileAccess.file_exists(path):
		return ErrorCodes.make(ErrorCodes.RESOURCE_NOT_FOUND, "File not found: %s" % path)

	var file: = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, "Failed to open file: %s" % path)

	var content: = file.get_as_text()
	file.close()

	return {
		"data": {
			"path": path, 
			"content": content, 
			"size": content.length(), 
			"line_count": content.count("\n") + (1 if not content.is_empty() else 0), 
		}
	}


func write_file(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var content: String = params.get("content", "")

	var path_err = McpPathValidator.path_error(path, "path", true)
	if path_err != null:
		return path_err

	var existed_before: = FileAccess.file_exists(path)



	var write_failure: Variant = McpResourceIO.write_text_to_disk(path, content)
	if write_failure != null:
		return write_failure





	var efs: = EditorInterface.get_resource_filesystem()
	if efs != null:
		efs.update_file(path)

	var data: = {
		"path": path, 
		"size": content.length(), 
		"undoable": false, 
		"reason": "File system operations cannot be undone via editor undo", 
	}
	var is_gdscript: = path.ends_with(".gd")






	if is_gdscript:
		ScriptHandler.new(null)._attach_gdscript_diagnostics(data, path, content)
		data["committed"] = true
		data["import_settled"] = existed_before
		data["import_settle"] = "already_known" if existed_before else "not_waited"
	McpResourceIO.attach_cleanup_hint(data, existed_before, [path])











	var request_id: String = params.get("_request_id", "")
	if is_gdscript and not existed_before and _connection != null and not request_id.is_empty():
		McpResourceIO.finish_text_write_deferred(_connection, request_id, path, data)
		return McpDispatcher.DEFERRED_RESPONSE

	return {"data": data}


func reimport(params: Dictionary) -> Dictionary:
	var paths: Array = params.get("paths", [])

	if paths.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: paths (non-empty array)")

	var efs: = EditorInterface.get_resource_filesystem()
	if efs == null:
		return ErrorCodes.make_not_ready(
			ErrorCodes.SUB_EDITOR_UNAVAILABLE, 
			"EditorFileSystem not available", false)

	var reimported: Array[String] = []
	var skipped_non_imported: Array[String] = []
	var not_found: Array[String] = []

	for path_variant in paths:
		var path: String = str(path_variant)
		var path_err: = McpPathValidator.validate_resource_path(path)
		if not path_err.is_empty():
			not_found.append("%s (%s)" % [path, path_err])
			continue
		if not FileAccess.file_exists(path):
			not_found.append("%s (file does not exist)" % path)
			continue
		efs.update_file(path)
		if _is_imported_resource(path):
			reimported.append(path)
		else:
			skipped_non_imported.append(path)

	var data: = {
		"reimported": reimported, 
		"skipped_non_imported": skipped_non_imported, 
		"not_found": not_found, 
		"reimported_count": reimported.size(), 
		"skipped_non_imported_count": skipped_non_imported.size(), 
		"not_found_count": not_found.size(), 
		"undoable": false, 
		"reason": "Reimport is a file system operation", 
	}


	if not skipped_non_imported.is_empty():
		data["skipped_non_imported_hint"] = (
			"%d path(s) are not imported resources. Their editor filesystem entry was "
			+ "refreshed, but no import ran — a success here is not evidence that a "
			+ "script parsed or that diagnostics were produced. Use script_patch/"
			+ "script_create for GDScript diagnostics, or filesystem_manage(op=\"scan\") "
			+ "for an asset the editor has not imported yet."
		) % skipped_non_imported.size()
	return {"data": data}




















static func _is_imported_resource(path: String) -> bool:
	if path.ends_with(IMPORT_SIDECAR_SUFFIX):
		return false
	return FileAccess.file_exists(path + IMPORT_SIDECAR_SUFFIX)










func scan_filesystem(params: Dictionary) -> Dictionary:
	var efs: = EditorInterface.get_resource_filesystem()
	if efs == null:
		return ErrorCodes.make_not_ready(
			ErrorCodes.SUB_EDITOR_UNAVAILABLE, 
			"EditorFileSystem not available", false)

	var request_id: String = params.get("_request_id", "")




	if _connection != null and not request_id.is_empty():
		_finish_scan_deferred(_connection, request_id, efs)
		return McpDispatcher.DEFERRED_RESPONSE






	var already: = _scan_in_flight or efs.is_scanning()
	if not already:
		efs.scan()
	return {
		"data": {
			"scan_completed": false, 
			"scan_settle": "not_waited", 
			"was_already_scanning": already, 
			"global_class_count": ProjectSettings.get_global_class_list().size(), 


			"global_classes_registered_delta": 0, 
			"undoable": false, 
			"reason": "Filesystem scan is an editor operation", 
		}
	}






static func _finish_scan_deferred(
	connection: McpConnection, 
	request_id: String, 
	efs: EditorFileSystem, 
) -> void :
	var work: = ScriptWork.begin("scan_filesystem")
	await _settle_scan(connection, request_id, efs)
	ScriptWork.finish(work)


static func _settle_scan(
	connection: McpConnection, request_id: String, efs: EditorFileSystem, 
) -> void :
	if not is_instance_valid(connection):
		return
	var tree: = connection.get_tree()
	if tree == null:
		return
	var classes_before: = ProjectSettings.get_global_class_list().size()





	var was_already_scanning: = _scan_in_flight or efs.is_scanning()
	var we_started: = not was_already_scanning
	if we_started:
		_scan_in_flight = true
		efs.scan()


	await tree.process_frame
	var deadline_ms: = Time.get_ticks_msec() + _SCAN_SETTLE_MAX_MSEC
	var start_grace_ms: = Time.get_ticks_msec() + _SCAN_START_GRACE_MSEC
	var saw_scanning: = efs.is_scanning()
	while Time.get_ticks_msec() < deadline_ms:
		if efs.is_scanning():
			saw_scanning = true
		elif saw_scanning or Time.get_ticks_msec() > start_grace_ms:


			break
		await tree.process_frame


	if we_started:
		_scan_in_flight = false
	if not is_instance_valid(connection):
		return
	var completed: = not efs.is_scanning()
	var classes_after: = ProjectSettings.get_global_class_list().size()
	connection.send_deferred_response(request_id, {
		"data": {
			"scan_completed": completed, 
			"scan_settle": "settled" if completed else "timeout", 
			"was_already_scanning": was_already_scanning, 
			"global_class_count": classes_after, 
			"global_classes_registered_delta": classes_after - classes_before, 
			"undoable": false, 
			"reason": "Filesystem scan is an editor operation", 
		}
	})



const Mutation: = preload("res://addons/godot_ai/handlers/filesystem_mutation.gd")


func move_file(params: Dictionary) -> Dictionary:
	return Mutation.start(_connection, params, "move")


func rename_file(params: Dictionary) -> Dictionary:
	return Mutation.start(_connection, params, "rename")


func remove_file(params: Dictionary) -> Dictionary:
	return Mutation.start(_connection, params, "remove")
