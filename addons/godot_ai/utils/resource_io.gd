@tool
class_name McpResourceIO
extends RefCounted

const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")

















const IMPORT_SETTLE_MAX_FRAMES: = 300
const IMPORT_SETTLE_MAX_MSEC: = 3500











static func validate_home(params: Dictionary, require_property: bool = true) -> Variant:
	var node_path: String = params.get("path", "")
	var property: String = params.get("property", "")
	var resource_path: String = params.get("resource_path", "")
	var has_node_target: = not node_path.is_empty()
	var has_file_target: = not resource_path.is_empty()

	if has_node_target and has_file_target:
		var both_msg: = "Provide either path+property or resource_path, not both" if require_property else "Provide either path or resource_path, not both"
		return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, both_msg)
	if not has_node_target and not has_file_target:
		var none_msg: = "Must provide either path+property (assign inline) or resource_path (save .tres)" if require_property else "Must provide either path or resource_path"
		return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, none_msg)
	if require_property and has_node_target and property.is_empty():
		return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, "Missing required param: property (required when path is given)")
	return null




























static func save_to_disk(
	res: Resource, 
	resource_path: String, 
	overwrite: bool, 
	label: String, 
	extra_fields: Dictionary = {}, 
	pause_target: McpConnection = null, 
) -> Dictionary:
	var path_err = McpPathValidator.path_error(resource_path, "resource_path", true)
	if path_err != null:
		return path_err

	var existed_before: = FileAccess.file_exists(resource_path)
	if existed_before and not overwrite:
		return ErrorCodes.make(
			ErrorCodes.INVALID_PARAMS, 
			"%s already exists at %s (pass overwrite=true to replace)" % [label, resource_path]
		)



	var prior_uid: = ResourceLoader.get_resource_uid(resource_path) if existed_before else ResourceUID.INVALID_ID

	var dir_path: = resource_path.get_base_dir()
	var mkdir_err: = DirAccess.make_dir_recursive_absolute(dir_path)
	if mkdir_err != OK and mkdir_err != ERR_ALREADY_EXISTS:
		return ErrorCodes.make(
			ErrorCodes.INTERNAL_ERROR, 
			"Failed to create directory %s: %s" % [dir_path, error_string(mkdir_err)]
		)

	if pause_target != null:
		pause_target.pause_processing = true
	var save_err: = ResourceSaver.save(res, resource_path)
	if pause_target != null:
		pause_target.pause_processing = false
	if save_err != OK:
		return ErrorCodes.make(
			ErrorCodes.INTERNAL_ERROR, 
			"Failed to save %s to %s: %s" % [label, resource_path, error_string(save_err)]
		)
	var uid_err: = ensure_uid(resource_path, prior_uid)
	if uid_err != OK:
		return ErrorCodes.make(
			ErrorCodes.INTERNAL_ERROR, 
			"%s saved to %s but failed to write its uid: %s" % [label, resource_path, error_string(uid_err)]
		)

	var efs: = EditorInterface.get_resource_filesystem()
	if efs != null:
		efs.update_file(resource_path)

	var data: = {
		"resource_path": resource_path, 
		"overwritten": existed_before, 
		"undoable": false, 
		"reason": "File creation is persistent; delete the file manually to revert", 
	}
	attach_cleanup_hint(data, existed_before, [resource_path])


	data.merge(extra_fields, true)
	return {"data": data}









static func guarded_save(res: Resource, resource_path: String, pause_target: McpConnection) -> int:
	var prior_uid: = ResourceLoader.get_resource_uid(resource_path) if FileAccess.file_exists(resource_path) else ResourceUID.INVALID_ID
	if pause_target != null:
		pause_target.pause_processing = true
	var save_err: = ResourceSaver.save(res, resource_path)
	if pause_target != null:
		pause_target.pause_processing = false
	if save_err != OK:
		return save_err
	return ensure_uid(resource_path, prior_uid)


















static func ensure_uid(resource_path: String, prior_uid: int) -> Error:
	var id: = prior_uid
	if id == ResourceUID.INVALID_ID:
		id = ResourceUID.create_id()
	return ResourceSaver.set_uid(resource_path, id)









static func attach_cleanup_hint(data: Dictionary, existed_before: bool, paths: Array) -> void :
	if existed_before:
		return
	data["cleanup"] = {"rm": paths}










static func write_text_to_disk(path: String, content: String) -> Variant:
	var dir_path: = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err: = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, "Failed to create directory: %s" % dir_path)

	var file: = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, "Failed to open file for writing: %s" % path)

	file.store_string(content)
	file.flush()
	var write_err: = file.get_error()
	file.close()
	if write_err != OK:
		return ErrorCodes.make(
			ErrorCodes.INTERNAL_ERROR, 
			"Write failed for %s (%s); file may be truncated" % [path, error_string(write_err)]
		)
	return null










static func finish_text_write_deferred(
	connection: McpConnection, 
	request_id: String, 
	path: String, 
	data: Dictionary, 
) -> void :
	var ledger: = preload("res://addons/godot_ai/utils/script_work.gd")
	var work: int = ledger.begin("write_file")
	await _settle_text_write(connection, request_id, path, data)
	ledger.finish(work)


static func _settle_text_write(
	connection: McpConnection, request_id: String, path: String, data: Dictionary, 
) -> void :
	if not is_instance_valid(connection):
		return
	var tree: = connection.get_tree()
	if tree == null:
		return
	var deadline_ms: = Time.get_ticks_msec() + IMPORT_SETTLE_MAX_MSEC







	await tree.process_frame
	var frames: = 0
	while (
		frames < IMPORT_SETTLE_MAX_FRAMES
		and Time.get_ticks_msec() < deadline_ms
		and not ResourceLoader.exists(path)
	):
		await tree.process_frame
		frames += 1



	if not is_instance_valid(connection):
		return
	var payload: = data.duplicate()
	var settled: = ResourceLoader.exists(path)
	payload["import_settled"] = settled
	payload["import_settle"] = "settled" if settled else "timeout"
	payload["import_pending"] = not settled
	connection.send_deferred_response(request_id, {"data": payload})
