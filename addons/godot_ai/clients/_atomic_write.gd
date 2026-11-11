@tool
class_name McpAtomicWrite
extends RefCounted













static func write(path: String, content: String) -> bool:







	if not path.is_absolute_path():
		return false




	path = _resolve_symlink_target(path)
	var dir_path: = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		if DirAccess.make_dir_recursive_absolute(dir_path) != OK:
			return false










	var had_original: = FileAccess.file_exists(path)
	var target_mode: = _resolve_target_mode(path, had_original)





	var tmp_path: = "%s.tmp.%d" % [path, OS.get_process_id()]
	var file: = _open_restricted_temp(tmp_path, target_mode)
	if file == null:
		return false
	file.store_string(content)





	file.flush()
	file.close()



	if not _apply_mode(tmp_path, target_mode):
		DirAccess.remove_absolute(tmp_path)
		return false







	if not _written_size_matches(tmp_path, content):
		DirAccess.remove_absolute(tmp_path)
		return false












	var backup_path: = path + ".backup"
	var backup_made: = false
	if had_original:
		DirAccess.remove_absolute(backup_path)
		if DirAccess.copy_absolute(path, backup_path) == OK:
			if not _apply_mode(backup_path, target_mode):



				DirAccess.remove_absolute(backup_path)
				DirAccess.remove_absolute(tmp_path)
				return false
			backup_made = true
		else:


			DirAccess.remove_absolute(backup_path)

	if DirAccess.rename_absolute(tmp_path, path) == OK:
		return true





	if DirAccess.copy_absolute(tmp_path, path) == OK and _written_size_matches(path, content):





		if _apply_mode(path, target_mode):
			DirAccess.remove_absolute(tmp_path)
			return true


	if backup_made:







		var restored: = (
			DirAccess.copy_absolute(backup_path, path) == OK
			and _apply_mode(path, target_mode)
		)
		if not restored:




			DirAccess.remove_absolute(path)
			DirAccess.rename_absolute(backup_path, path)
	elif not had_original and FileAccess.file_exists(path):






		DirAccess.remove_absolute(path)





	DirAccess.remove_absolute(tmp_path)
	return false











static func _resolve_symlink_target(path: String) -> String:
	var resolved: = path

	for _hop in 8:
		var base_dir: = resolved.get_base_dir()
		var da: = DirAccess.open(base_dir)
		if da == null or not da.is_link(resolved):
			return resolved
		var target: = da.read_link(resolved)
		if target.is_empty():
			return resolved
		if target.is_relative_path():
			target = base_dir.path_join(target)
		resolved = target.simplify_path()
	return resolved


static func _resolve_target_mode(path: String, had_original: bool) -> int:










	if had_original:
		var existing: = FileAccess.get_unix_permissions(path)
		if existing > 0:
			return existing
	return FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER









static func _open_restricted_temp(path: String, mode: int) -> FileAccess:
	var created: = FileAccess.open(path, FileAccess.WRITE)
	if created == null:
		return null
	created.close()
	if not _apply_mode(path, mode):
		DirAccess.remove_absolute(path)
		return null
	return FileAccess.open(path, FileAccess.READ_WRITE)


static func _apply_mode(path: String, mode: int) -> bool:




	if mode <= 0:
		return true
	var err: = FileAccess.set_unix_permissions(path, mode)
	if err == OK or err == ERR_UNAVAILABLE:
		return true


	push_warning("MCP | could not set permissions on %s: %s" % [path, error_string(err)])
	return false


static func _written_size_matches(path: String, content: String) -> bool:


	var f: = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var on_disk: = f.get_length()
	f.close()
	return on_disk == content.to_utf8_buffer().size()
