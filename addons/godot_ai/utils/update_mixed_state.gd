@tool
extends RefCounted











const ADDON_DIR: = "res://addons/godot_ai/"




const BACKUP_SUFFIX: = ".update_backup"



const MAX_BACKUP_RESULTS: = 200






const CACHE_TTL_MSEC: = 5000

static var _cache_value: Dictionary = {}
static var _cache_timestamp_msec: int = -1











static func find_backups(dir: String = ADDON_DIR) -> Array:
	var results: Array = []
	var stack: Array = [dir]
	while not stack.is_empty():
		if results.size() >= MAX_BACKUP_RESULTS:
			break
		var current: String = stack.pop_back()
		var d: = DirAccess.open(current)




		if d == null:
			continue
		var entries: Array = []
		d.list_dir_begin()
		while true:
			var entry: = d.get_next()
			if entry.is_empty():
				break
			if entry == "." or entry == "..":
				continue
			entries.append({"name": entry, "is_dir": d.current_is_dir()})
		d.list_dir_end()
		entries.sort_custom( func(a, b): return a["name"] < b["name"])



		for i in range(entries.size() - 1, -1, -1):
			var entry: Dictionary = entries[i]
			var child_path: = current.path_join(entry["name"])
			if entry["is_dir"] and not d.is_link(child_path):
				stack.append(child_path)
		for entry in entries:
			if entry["is_dir"]:
				continue
			if not String(entry["name"]).ends_with(BACKUP_SUFFIX):
				continue
			results.append(current.path_join(entry["name"]))
			if results.size() >= MAX_BACKUP_RESULTS:
				break
	results.sort()
	return results











static func diagnose(dir: String = ADDON_DIR, force: bool = false) -> Dictionary:
	var use_cache: = dir == ADDON_DIR and not force
	if use_cache and _cache_timestamp_msec >= 0:
		if Time.get_ticks_msec() - _cache_timestamp_msec < CACHE_TTL_MSEC:
			return _cache_value.duplicate(true)

	var backups: = find_backups(dir)
	var result: Dictionary = {}
	if not backups.is_empty():







		result = {
			"addon_dir": dir, 
			"backup_files": backups, 
			"backup_count": backups.size(), 
			"truncated": backups.size() >= MAX_BACKUP_RESULTS, 
			"message": (
				"Found .update_backup files in addons/godot_ai/. This usually"
				+ " means a self-update rollback couldn't restore the previous"
				+ " addon contents (FAILED_MIXED) — the plugin may load a mix"
				+ " of old and new files. Restore the addon from your VCS or a"
				+ " fresh release ZIP, then delete the listed *.update_backup"
				+ " files. If the plugin runs without issues these are likely"
				+ " stale from a successful install and safe to delete."
			), 
		}
	if use_cache:
		_cache_value = result.duplicate(true)
		_cache_timestamp_msec = Time.get_ticks_msec()
	return result





static func clear_cache() -> void :
	_cache_value = {}
	_cache_timestamp_msec = -1
