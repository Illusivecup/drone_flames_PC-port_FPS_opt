@tool
class_name McpUvCacheCleanup
extends RefCounted









































const DEAD_PREFIX: = "_dead_"
const TMP_PREFIX: = ".tmp"





static func purge_stale_builds() -> Dictionary:
	if OS.get_name() != "Windows":
		return _empty_result()
	var local_appdata: = OS.get_environment("LOCALAPPDATA")
	if local_appdata.is_empty():
		return _empty_result()
	var builds_root: = local_appdata.replace("\\", "/").path_join("uv/cache/builds-v0")
	return purge_directory(builds_root)












static func purge_directory(builds_root: String) -> Dictionary:
	var result: = _empty_result()
	if not DirAccess.dir_exists_absolute(builds_root):
		return result
	var dir: = DirAccess.open(builds_root)
	if dir == null:
		return result
	dir.include_hidden = true



	var tmp_names: Array[String] = []
	var dead_names: Array[String] = []
	dir.list_dir_begin()
	var entry: = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not (entry == "." or entry == ".."):
			if entry.begins_with(TMP_PREFIX):
				tmp_names.append(entry)
			elif entry.begins_with(DEAD_PREFIX):
				dead_names.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	result.scanned = tmp_names.size()




	for name in tmp_names:
		var src: = builds_root.path_join(name)
		var dst: = builds_root.path_join(DEAD_PREFIX + name)
		if dir.rename(src, dst) == OK:
			result.renamed += 1
			dead_names.append(DEAD_PREFIX + name)



	for name in dead_names:
		var path: = builds_root.path_join(name)
		if _remove_recursive(path):
			result.deleted += 1



	var dir2: = DirAccess.open(builds_root)
	if dir2 != null:
		dir2.include_hidden = true
		dir2.list_dir_begin()
		var e: = dir2.get_next()
		while e != "":
			if dir2.current_is_dir() and e.begins_with(DEAD_PREFIX):
				result.remaining += 1
			e = dir2.get_next()
		dir2.list_dir_end()

	return result




static func _remove_recursive(path: String) -> bool:
	var dir: = DirAccess.open(path)
	if dir == null:


		DirAccess.remove_absolute(path)
		return not DirAccess.dir_exists_absolute(path)
	dir.include_hidden = true
	dir.list_dir_begin()
	var entry: = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child: = path.path_join(entry)
		if dir.current_is_dir():
			_remove_recursive(child)
		else:
			DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()



	DirAccess.remove_absolute(path)
	return not DirAccess.dir_exists_absolute(path)


static func _empty_result() -> Dictionary:
	return {"scanned": 0, "renamed": 0, "deleted": 0, "remaining": 0}
