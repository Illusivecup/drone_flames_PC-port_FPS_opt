extends Node
## Keeps persistent files available after the project display name changes between releases.

const MIGRATION_MARKER: String = "user://.legacy_user_data_migrated_v1"
const LEGACY_FOLDER: String = "app_userdata"
const LEGACY_PREFIX: String = "DroneFlames v"
const LEGACY_SUFFIX: String = " (PC Port by @good_boy_irl)"
const LEGACY_NAMES: Array[String] = [
	"DroneFlames (PC Port by @good_boy_irl)",
	"DroneFlames",
]


func _ready() -> void:
	if OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS":
		return
	_migrate_legacy_data()


func _migrate_legacy_data() -> void:
	if FileAccess.file_exists(MIGRATION_MARKER):
		return
	var engine_folder: String = "Godot" if OS.get_name() in ["Windows", "macOS"] else "godot"
	var data_root: String = OS.get_data_dir().path_join(engine_folder).path_join(LEGACY_FOLDER)
	var legacy_root: DirAccess = DirAccess.open(data_root)
	if legacy_root == null:
		_write_marker()
		return
	var candidates: Array[String] = []
	for folder: String in LEGACY_NAMES:
		if DirAccess.dir_exists_absolute(data_root.path_join(folder)):
			candidates.append(folder)
	legacy_root.list_dir_begin()
	var entry: String = legacy_root.get_next()
	while entry != "":
		if legacy_root.current_is_dir() and entry.begins_with(LEGACY_PREFIX) and entry.ends_with(LEGACY_SUFFIX):
			if not candidates.has(entry):
				candidates.append(entry)
		entry = legacy_root.get_next()
	legacy_root.list_dir_end()
	candidates.sort_custom(_newer_legacy_version)
	var destination: String = OS.get_user_data_dir()
	var all_copied: bool = true
	for folder: String in candidates:
		var source: String = data_root.path_join(folder)
		if source.simplify_path() == destination.simplify_path():
			continue
		if not _merge_missing_files(source, destination):
			all_copied = false
	if all_copied:
		_write_marker()
		if not candidates.is_empty():
			print("[UserDataMigration] Merged old DroneFlames data into the stable user folder; old copies were kept.")
	else:
		push_warning("[UserDataMigration] Some old user files could not be copied. Migration will retry next launch.")


func _newer_legacy_version(a: String, b: String) -> bool:
	var av: PackedStringArray = _version_parts(a)
	var bv: PackedStringArray = _version_parts(b)
	for index: int in maxi(av.size(), bv.size()):
		var an: int = int(av[index]) if index < av.size() else 0
		var bn: int = int(bv[index]) if index < bv.size() else 0
		if an != bn:
			return an > bn
	return a > b


func _version_parts(folder: String) -> PackedStringArray:
	if not folder.begins_with(LEGACY_PREFIX):
		return PackedStringArray()
	return folder.trim_prefix(LEGACY_PREFIX).trim_suffix(LEGACY_SUFFIX).split(".")


func _merge_missing_files(source: String, destination: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(destination) != OK:
		return false
	var source_dir: DirAccess = DirAccess.open(source)
	if source_dir == null:
		return false
	var ok: bool = true
	source_dir.list_dir_begin()
	var entry: String = source_dir.get_next()
	while entry != "":
		if entry != "." and entry != ".." and entry != ".godot" and entry != "updates":
			var source_path: String = source.path_join(entry)
			var destination_path: String = destination.path_join(entry)
			if source_dir.current_is_dir():
				if not _merge_missing_files(source_path, destination_path):
					ok = false
			elif not FileAccess.file_exists(destination_path):
				if not _copy_file(source_path, destination_path):
					ok = false
		entry = source_dir.get_next()
	source_dir.list_dir_end()
	return ok


func _copy_file(source: String, destination: String) -> bool:
	var input: FileAccess = FileAccess.open(source, FileAccess.READ)
	if input == null:
		return false
	var bytes: PackedByteArray = input.get_buffer(input.get_length())
	input.close()
	var output: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
	if output == null:
		return false
	output.store_buffer(bytes)
	var ok: bool = output.get_error() == OK
	output.close()
	return ok


func _write_marker() -> void:
	var marker: FileAccess = FileAccess.open(MIGRATION_MARKER, FileAccess.WRITE)
	if marker != null:
		marker.store_string("Completed without deleting legacy folders.\n")
		marker.close()
