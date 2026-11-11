@tool
class_name McpTransportCapability
extends RefCounted




const CAPABILITY_DIR_ENV: = "GODOT_AI_CAPABILITY_DIR"
const RECORD_VERSION: = 1
const MAX_RECORD_BYTES: = 1024
const _POSIX_PERMISSION_MASK: = 511
const _GROUP_OTHER_PERMISSION_MASK: = 63
const _GROUP_OTHER_WRITE_MASK: = 18
const _MAX_LINK_HOPS: = 8
const _SYSTEM_TEMP_ROOTS: Array[String] = ["/tmp", "/private/tmp", "/var/tmp"]
const _FLATPAK_INFO_PATH: = "/.flatpak-info"



const _FLATPAK_HOME_GRANTS: Array[String] = [
	"host", "host:rw", "host:create", "home", "home:rw", "home:create", 
]


const _FLATPAK_HOST_EXCLUDED: Array[String] = [
	"lib", "lib32", "lib64", "bin", "sbin", "usr", "boot", "root", 
	"tmp", "etc", "app", "run", "proc", "sys", "dev", "var", 
]
const _KEYS: Array[String] = [
	"version", "http", "websocket", "instance_nonce", 
]


static func read_for_http_port(http_port: int, captured_path: = "") -> Dictionary:
	var path: = str(captured_path)
	if not path.is_empty() and path.get_file() != "http-%d.json" % http_port:
		return {}
	return _read_path(path if not path.is_empty() else path_for_http_port(http_port))


static func _read_path(path: String) -> Dictionary:
	if path.is_empty() or not path.is_absolute_path():
		return {}
	var resolved: = _resolve_trusted_path(path)
	if resolved.is_empty():
		return {}
	var directory: = resolved.get_base_dir()
	if (
		not _safe_posix_ancestors(directory)
		or not _private_path(directory, true)
		or not _private_path(resolved, false)
	):
		return {}
	var file: = FileAccess.open(resolved, FileAccess.READ)
	if file == null:
		return {}
	var length: = file.get_length()
	if length < 1 or length > MAX_RECORD_BYTES + 1:
		return {}
	var bytes: = file.get_buffer(length)
	if bytes.size() != length:
		return {}
	if bytes[bytes.size() - 1] == 10:
		bytes.resize(bytes.size() - 1)
	if bytes.is_empty() or bytes.size() > MAX_RECORD_BYTES:
		return {}
	for byte in bytes:
		if byte > 127:
			return {}
	var raw: = bytes.get_string_from_ascii()


	if raw.contains("\\"):
		return {}
	for key in _KEYS:
		if raw.count("\"%s\"" % key) != 1:
			return {}
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary) or parsed.size() != _KEYS.size():
		return {}
	for key in _KEYS:
		if not parsed.has(key):
			return {}
	var version: Variant = parsed["version"]
	if not (version is int or version is float) or float(version) != RECORD_VERSION:
		return {}
	if (
		not (parsed["http"] is String)
		or not (parsed["websocket"] is String)
		or not (parsed["instance_nonce"] is String)
	):
		return {}
	var http: String = parsed["http"]
	var websocket: String = parsed["websocket"]
	var nonce: String = parsed["instance_nonce"]
	if not is_http_capability(http) or not is_lower_hex(websocket, 64):
		return {}
	if not is_lower_hex(nonce, 32) or http == websocket:
		return {}
	return {
		"http": http, 
		"websocket": websocket, 
		"instance_nonce": nonce.to_lower(), 
	}


static func _private_path(path: String, directory: bool) -> bool:
	if directory:
		if DirAccess.open(path) == null:
			return false
	elif not FileAccess.file_exists(path):
		return false
	if OS.get_name() == "Windows":


		return true


	var mode: = FileAccess.get_unix_permissions(path) & _POSIX_PERMISSION_MASK
	return mode != 0 and (mode & _GROUP_OTHER_PERMISSION_MASK) == 0













static func _resolve_trusted_path(path: String) -> String:
	if OS.get_name() == "Windows":
		return "" if _path_has_link(path) else path
	var remaining: = path.simplify_path().split("/", false)
	var current: = "/"
	var hops: = 0
	while not remaining.is_empty():
		var part: = remaining[0]
		remaining.remove_at(0)
		var candidate: = current.path_join(part)
		var parent: = DirAccess.open(current)
		if parent == null:
			return ""
		if parent.is_link(candidate):
			if (
				remaining.is_empty()
				or hops >= _MAX_LINK_HOPS
				or not _closed_to_group_and_other(current)
			):
				return ""
			hops += 1
			var target: = parent.read_link(candidate)
			if target.is_empty():
				return ""
			if not target.is_absolute_path():
				target = current.path_join(target)
			var target_parts: = target.simplify_path().split("/", false)
			target_parts.append_array(remaining)
			remaining = target_parts
			current = "/"
			continue
		current = candidate
	return current


static func _closed_to_group_and_other(directory: String) -> bool:
	var mode: = FileAccess.get_unix_permissions(directory) & _POSIX_PERMISSION_MASK
	return mode != 0 and (mode & _GROUP_OTHER_WRITE_MASK) == 0


static func _path_has_link(path: String) -> bool:
	var current: = path
	while not current.is_empty():
		var parent: = current.get_base_dir()
		if parent.is_empty() or parent == current:
			return false
		var directory: = DirAccess.open(parent)
		if directory == null or directory.is_link(current):
			return true
		current = parent
	return false


static func _safe_posix_ancestors(path: String) -> bool:
	if OS.get_name() == "Windows":
		return true
	var current: = path.simplify_path()
	while not current.is_empty():
		if DirAccess.open(current) != null:
			var permissions: = FileAccess.get_unix_permissions(current)
			if not _safe_posix_ancestor_mode(current, permissions):
				return false
		var parent: = current.get_base_dir()
		if parent.is_empty() or parent == current:
			break
		current = parent
	return true


static func _safe_posix_ancestor_mode(path: String, permissions: int) -> bool:
	var mode: = permissions & _POSIX_PERMISSION_MASK
	if mode == 0:
		return false
	if (mode & _GROUP_OTHER_WRITE_MASK) == 0:
		return true



	return (
		path.simplify_path() in _SYSTEM_TEMP_ROOTS
		and (permissions & FileAccess.UNIX_RESTRICTED_DELETE) != 0
	)


static func is_http_capability(value: String) -> bool:
	var bytes: = value.to_ascii_buffer()
	if bytes.size() < 32 or bytes.size() > 128:
		return false
	for byte in bytes:
		if not (
			(byte >= 48 and byte <= 57)
			or (byte >= 65 and byte <= 90)
			or (byte >= 97 and byte <= 122)
			or byte in [43, 45, 46, 47, 61, 95, 126]
		):
			return false
	return true


static func is_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for index in range(length):
		var code: = value.unicode_at(index)
		if not (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 70)
			or (code >= 97 and code <= 102)
		):
			return false
	return true


static func is_lower_hex(value: String, length: int) -> bool:
	return is_hex(value, length) and value == value.to_lower()











static func directory_write_problem(http_port: int) -> String:
	var record: = path_for_http_port(http_port)
	if record.is_empty():
		return ""
	if OS.get_name() != "Windows":
		return posix_directory_problem(record.get_base_dir())
	return directory_write_problem_for(record.get_base_dir())




static func posix_directory_problem(directory: String) -> String:
	var problems: Array[String] = []
	var current: = directory.simplify_path()
	while not current.is_empty():
		if DirAccess.dir_exists_absolute(current):
			var permissions: = FileAccess.get_unix_permissions(current)
			if not _safe_posix_ancestor_mode(current, permissions):
				problems.push_front("%s (mode %03o)" % [current, permissions & _POSIX_PERMISSION_MASK])
		var parent: = current.get_base_dir()
		if parent.is_empty() or parent == current:
			break
		current = parent
	if problems.is_empty():
		return ""
	return (
		"Godot AI cannot securely store connection credentials. Check these directories: %s. "
		+ "They must be accessible and not writable by group or other users. "
		+ "If you own them and shared write access is not intentional, remove group/other write "
		+ "permission on each named directory (chmod go-w), then retry. "
		+ "Do not apply chmod recursively. No permissions have been changed."
	) % "; ".join(problems)


static func directory_write_problem_for(directory: String) -> String:
	if DirAccess.open(directory) == null:
		var created: = DirAccess.make_dir_recursive_absolute(directory)
		if created != OK:
			return windows_repair_hint(directory, error_string(created))
	var probe: = directory.path_join(".access-probe-%d-%s" % [
		OS.get_process_id(), Crypto.new().generate_random_bytes(4).hex_encode(), 
	])
	var file: = FileAccess.open(probe, FileAccess.WRITE)
	if file == null:
		return windows_repair_hint(directory, error_string(FileAccess.get_open_error()))
	file.close()
	DirAccess.remove_absolute(probe)
	return ""


static func windows_repair_hint(directory: String, detail: String) -> String:
	return (
		"Godot AI cannot use the directory %s (%s): this Windows account cannot "
		+ "access it. This can happen when an elevated (Run as administrator) "
		+ "process created it. Check this directory's permissions and grant your "
		+ "Windows account access, then reopen Godot and your AI clients without "
		+ "Run as administrator."
	) % [directory, detail]


static func path_for_http_port(http_port: int) -> String:
	if http_port < 1 or http_port > 65535:
		return ""
	var override: = OS.get_environment(CAPABILITY_DIR_ENV).strip_edges()
	if OS.get_name() == "Windows" and not override.is_empty():
		return ""
	var directory: = override
	if directory.is_empty():
		if OS.get_name() == "Windows":
			directory = OS.get_environment("LOCALAPPDATA").strip_edges()
			if directory.is_empty():
				return ""
			directory = directory.path_join("godot-ai/capabilities")
		elif OS.get_name() == "macOS":
			directory = OS.get_environment("HOME").path_join(
				"Library/Application Support/godot-ai/capabilities"
			)
		else:
			directory = linux_config_home(_flatpak_info()).path_join("godot-ai/capabilities")
	if directory.is_empty() or not directory.is_absolute_path():
		return ""
	return directory.simplify_path().path_join("http-%d.json" % http_port)








static func linux_config_home(flatpak_info: String) -> String:
	var config: = OS.get_environment(linux_config_home_variable(flatpak_info)).strip_edges()
	if config.is_empty():
		config = OS.get_environment("HOME").path_join(".config")
	return config



static func linux_config_home_variable(flatpak_info: String) -> String:
	return (
		"HOST_XDG_CONFIG_HOME" if flatpak_shares_config_home(flatpak_info) else "XDG_CONFIG_HOME"
	)








static func flatpak_shares_config_home(flatpak_info: String) -> bool:
	return (
		flatpak_shares_home(flatpak_info)
		or bool(_flatpak_filesystems(flatpak_info).get("xdg-config", false))
	)






static func flatpak_shares_home(flatpak_info: String) -> bool:
	var group: = ""
	for line in flatpak_info.split("\n"):
		if line.begins_with("["):
			group = line.strip_edges()
		elif group == "[Context]" and line.begins_with("filesystems="):
			for grant in line.trim_prefix("filesystems=").strip_edges().split(";"):
				if grant in _FLATPAK_HOME_GRANTS:
					return true
			return false
	return false






















static func flatpak_grant_over(
	flatpak_info: String, path: String, home: String, host_config_home: String
) -> Dictionary:
	var target: = path.simplify_path()
	if not target.is_absolute_path():
		return {}
	var grants: = _flatpak_filesystems(flatpak_info)
	var found: = {}
	for location in grants:
		var root: = _flatpak_grant_path(str(location), home, host_config_home)
		if root.is_empty() or not path_is_within(root, target):
			continue
		var covered: = str(found.get("root", ""))
		if root.length() > covered.length():
			found = {"root": root, "location": str(location), "writable": bool(grants[location])}
		elif root == covered and found["writable"] and not grants[location]:


			found = {"root": root, "location": str(location), "writable": false}
	var home_dir: = home.simplify_path()
	var top: = target.get_slice("/", 1)
	var wide: = {}
	if not home.is_empty() and path_is_within(home_dir, target):
		var apps_dir: = home_dir.path_join(".var/app")
		var app_id: = flatpak_application_id(flatpak_info)
		if path_is_within(apps_dir, target):
			if not app_id.is_empty() and path_is_within(apps_dir.path_join(app_id), target):
				wide = {
					"root": apps_dir.path_join(app_id), 
					"location": apps_dir.path_join(app_id), 
					"writable": true, 
				}
		elif grants.has("home") or grants.has("host"):


			wide = {
				"root": home_dir, 
				"location": "home", 
				"writable": bool(grants.get("home", false)) or bool(grants.get("host", false)), 
			}
	elif grants.has("host") and not top.is_empty() and top not in _FLATPAK_HOST_EXCLUDED:
		wide = {"root": "/" + top, "location": "host", "writable": bool(grants["host"])}
	if str(wide.get("root", "")).length() > str(found.get("root", "")).length():
		return wide
	return found



static func flatpak_application_id(flatpak_info: String) -> String:
	var group: = ""
	for line in flatpak_info.split("\n"):
		if line.begins_with("["):
			group = line.strip_edges()
		elif group == "[Application]" and line.begins_with("name="):
			return line.trim_prefix("name=").strip_edges()
	return ""



static func path_is_within(directory: String, path: String) -> bool:
	return path == directory or path.begins_with(directory.trim_suffix("/") + "/")




static func _flatpak_grant_path(location: String, home: String, host_config_home: String) -> String:
	var placed: = ""
	if location == "~" or location.begins_with("~/"):
		placed = home.path_join(location.substr(2))
	elif location.begins_with("/"):
		placed = _home_spelling(location, home)
	elif not host_config_home.is_empty() and (
		location == "xdg-config" or location.begins_with("xdg-config/")
	):
		placed = host_config_home + location.trim_prefix("xdg-config")
	return placed.simplify_path() if placed.is_absolute_path() else ""





static func _home_spelling(path: String, home: String) -> String:
	for spelling in [["/var/home/", "/home/"], ["/home/", "/var/home/"]]:
		if home.begins_with(spelling[0]) and path.begins_with(spelling[1]):
			return str(spelling[0]) + path.trim_prefix(spelling[1])
	return path






static func _flatpak_filesystems(flatpak_info: String) -> Dictionary:
	var grants: = {}
	var group: = ""
	for line in flatpak_info.split("\n"):
		if line.begins_with("["):
			group = line.strip_edges()
		elif group == "[Context]" and line.begins_with("filesystems="):
			for entry in _key_file_list(line.trim_prefix("filesystems=").strip_edges()):
				var grant: = _flatpak_location_and_mode(entry.trim_prefix("!"))

				if grant[0].is_empty() or grant[1] == "reset":
					continue
				grants[grant[0]] = not entry.begins_with("!") and grant[1] in ["", "rw", "create"]
			break
	return grants




static func _key_file_list(value: String) -> PackedStringArray:
	var entries: = PackedStringArray()
	var entry: = ""
	var index: = 0
	while index < value.length():
		var character: = value[index]
		if character == "\\" and index + 1 < value.length():
			index += 1
			match value[index]:
				"s":
					entry += " "
				"n":
					entry += "\n"
				"t":
					entry += "\t"
				"r":
					entry += "\r"
				_:
					entry += value[index]
		elif character == ";":
			entries.append(entry)
			entry = ""
		else:
			entry += character
		index += 1
	if not entry.is_empty():
		entries.append(entry)
	return entries




static func _flatpak_location_and_mode(entry: String) -> PackedStringArray:
	var location: = ""
	var index: = 0
	while index < entry.length():
		var character: = entry[index]
		if character == "\\" and index + 1 < entry.length():
			index += 1
			location += entry[index]
		elif character == ":":
			return PackedStringArray([location, entry.substr(index + 1)])
		else:
			location += character
		index += 1
	return PackedStringArray([location, ""])




static func parse_mountinfo(mountinfo: String) -> Array[Dictionary]:
	var mounts: Array[Dictionary] = []
	for line in mountinfo.split("\n", false):
		var fields: = line.split(" ", false)

		var separator: = fields.find("-", 6)
		if separator < 0 or separator + 1 >= fields.size():
			continue
		mounts.append({
			"mount_point": _unescape_mount_path(fields[4]), 
			"root": _unescape_mount_path(fields[3]), 
			"fstype": fields[separator + 1], 
			"read_only": fields[5].split(",").has("ro"), 
		})
	return mounts





static func mount_for_path(mounts: Array[Dictionary], path: String) -> Dictionary:
	var target: = path.simplify_path()
	var found: = {}
	for mount in mounts:
		var mount_point: = str(mount["mount_point"])
		if (
			path_is_within(mount_point, target)
			and mount_point.length() >= str(found.get("mount_point", "")).length()
		):
			found = mount
	return found















static func flatpak_blocking_mount(
	mounts: Array[Dictionary], path: String, boundary: String
) -> Dictionary:
	var mount: = mount_for_path(mounts, path)
	if mount.is_empty():
		return {}
	var mount_point: = str(mount["mount_point"])
	var host_directory: = boundary.simplify_path()
	if mount["fstype"] == "tmpfs" and (
		mount_point == "/"
		or (
			mount["root"] == "/"
			and mount_point != host_directory
			and path_is_within(host_directory, mount_point)
		)
	):
		return mount
	return mount if mount["read_only"] else {}








static func real_path(path: String) -> String:
	if OS.get_name() == "Windows":
		return path
	var remaining: = path.simplify_path().split("/", false)
	var current: = "/"
	var hops: = 0
	while not remaining.is_empty():
		var parent: = DirAccess.open(current)
		if parent == null:
			break
		var candidate: = current.path_join(remaining[0])
		remaining.remove_at(0)
		if not parent.is_link(candidate):
			current = candidate
			continue
		var target: = parent.read_link(candidate)
		if hops >= _MAX_LINK_HOPS or target.is_empty():
			return path
		hops += 1
		if not target.is_absolute_path():
			target = current.path_join(target)
		var target_parts: = target.simplify_path().split("/", false)
		target_parts.append_array(remaining)
		remaining = target_parts
		current = "/"
	return current if remaining.is_empty() else current.path_join("/".join(remaining))



static func _unescape_mount_path(field: String) -> String:
	if not field.contains("\\"):
		return field
	var path: = ""
	var index: = 0
	while index < field.length():
		var code: = field.substr(index + 1, 3)
		if field[index] == "\\" and _is_octal_byte(code):
			path += char(int(code[0]) * 64 + int(code[1]) * 8 + int(code[2]))
			index += 4
		else:
			path += field[index]
			index += 1
	return path


static func _is_octal_byte(code: String) -> bool:
	if code.length() != 3:
		return false
	for digit in code:
		if digit not in "01234567":
			return false
	return true


static func _flatpak_info() -> String:
	if not FileAccess.file_exists(_FLATPAK_INFO_PATH):
		return ""
	var file: = FileAccess.open(_FLATPAK_INFO_PATH, FileAccess.READ)
	return "" if file == null else file.get_as_text()
