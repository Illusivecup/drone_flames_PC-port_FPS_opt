@tool
class_name McpPathTemplate
extends RefCounted



















static var _env_snapshot: = {}
static var _env_snapshot_mutex: = Mutex.new()

const LinuxProc: = preload("res://addons/godot_ai/utils/linux_proc.gd")
const _MOUNTINFO_PATH: = "/proc/self/mountinfo"





static var _flatpak_info: = ""
static var _flatpak_info_read: = false


static var _flatpak_mounts: Array[Dictionary] = []






const _BASE_ENV_VARS: Array[String] = [
	"HOME", 
	"USERPROFILE", 
	"XDG_CONFIG_HOME", 

	"HOST_XDG_CONFIG_HOME", 

	"GODOT_AI_CAPABILITY_DIR", 
	"APPDATA", 
	"LOCALAPPDATA", 
	"SHELL", 
	"ProgramFiles", 
	"GODOT_AI_MODE", 
	"GODOT_AI_STARTUP_TRACE", 




	"GODOT_AI_VENV_PYTHON", 
]









static func env_lookup(name: String) -> String:
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		var live: = OS.get_environment(name)
		_env_snapshot_mutex.lock()
		_env_snapshot[name] = live
		_env_snapshot_mutex.unlock()
		return live
	_env_snapshot_mutex.lock()
	var cached: Variant = _env_snapshot.get(name, null)
	_env_snapshot_mutex.unlock()
	if cached != null:
		return str(cached)
	return ""




static func warm_env_snapshot(extra_vars: PackedStringArray = PackedStringArray()) -> void :
	for var_name in _BASE_ENV_VARS:
		env_lookup(var_name)
	for var_name in extra_vars:
		if not String(var_name).is_empty():
			env_lookup(String(var_name))
	_flatpak_info_text()




static func _flatpak_info_text() -> String:
	_env_snapshot_mutex.lock()
	_read_flatpak_sandbox()
	var info: = _flatpak_info
	_env_snapshot_mutex.unlock()
	return info




static func _flatpak_mount_list() -> Array[Dictionary]:
	_env_snapshot_mutex.lock()
	_read_flatpak_sandbox()
	var mounts: = _flatpak_mounts
	_env_snapshot_mutex.unlock()
	return mounts



static func _read_flatpak_sandbox() -> void :
	if _flatpak_info_read:
		return
	_flatpak_info = McpTransportCapability._flatpak_info() if _os_key() == "linux" else ""
	var mountinfo: = ""
	if not _flatpak_info.is_empty():
		mountinfo = str(LinuxProc.read_text(_MOUNTINFO_PATH).text)
	_flatpak_mounts = McpTransportCapability.parse_mountinfo(mountinfo)
	_flatpak_info_read = true






static func _set_flatpak_info_for_test(info: Variant, mountinfo: String = "") -> void :
	_env_snapshot_mutex.lock()
	_flatpak_info = "" if info == null else str(info)
	_flatpak_mounts = McpTransportCapability.parse_mountinfo(mountinfo)
	_flatpak_info_read = info != null
	_env_snapshot_mutex.unlock()



static func flatpak_app_id() -> String:
	return McpTransportCapability.flatpak_application_id(_flatpak_info_text())







static func flatpak_host_config_home() -> String:
	if not McpTransportCapability.flatpak_shares_config_home(_flatpak_info_text()):
		return ""
	var config_home: = expand("$XDG_CONFIG_HOME")
	return config_home if config_home.is_absolute_path() else ""














static func flatpak_hides_credentials() -> bool:
	var info: = _flatpak_info_text()
	if info.is_empty():
		return false
	if not env_lookup(McpTransportCapability.CAPABILITY_DIR_ENV).strip_edges().is_empty():
		return false
	var config_home: = expand("$XDG_CONFIG_HOME")
	if not config_home.is_absolute_path():
		return false
	var host_directory: = config_home.path_join("godot-ai/capabilities")
	if not flatpak_write_block(host_directory.path_join("http.json")).is_empty():
		return true
	if McpTransportCapability.flatpak_shares_config_home(info):
		return false
	var grant: = McpTransportCapability.flatpak_grant_over(
		info, host_directory, _home(), config_home
	)
	return not str(grant.get("location", "")).begins_with("xdg-config/")









static func hidden_flatpak_app_dir(path: String) -> String:
	if _flatpak_info_text().is_empty():
		return ""
	var home: = _home()
	if home.is_empty():
		return ""
	var apps: = home.path_join(".var/app") + "/"
	if not path.begins_with(apps):
		return ""
	var app_dir: = apps + path.trim_prefix(apps).get_slice("/", 0)
	return "" if DirAccess.dir_exists_absolute(app_dir) else app_dir



static func resolve(template_map: Dictionary) -> String:
	var key: = platform_key(template_map)
	if key.is_empty():
		return ""
	var template: String = template_map[key]
	return expand(template)





static func platform_key(template_map: Dictionary) -> String:
	var key: = _os_key()
	if template_map.has(key):
		return key
	if (key == "darwin" or key == "linux") and template_map.has("unix"):
		return "unix"
	return ""












static func expand_path_candidates(template: String) -> PackedStringArray:
	var expanded: = expand(template)
	if expanded.is_empty():
		return PackedStringArray()
	var star: = expanded.find("*")
	if star < 0:
		return PackedStringArray([expanded])
	if expanded.find("*", star + 1) >= 0:
		return PackedStringArray()

	var slash_before: = maxi(expanded.rfind("/", star), expanded.rfind("\\", star))
	var forward_after: = expanded.find("/", star)
	var backward_after: = expanded.find("\\", star)
	var slash_after: = forward_after
	if slash_after < 0 or (backward_after >= 0 and backward_after < slash_after):
		slash_after = backward_after
	if slash_before < 0:
		return PackedStringArray()

	var parent: = expanded.substr(0, slash_before)
	var pattern: = (
		expanded.substr(slash_before + 1)
		if slash_after < 0
		else expanded.substr(slash_before + 1, slash_after - slash_before - 1)
	)
	var suffix: = "" if slash_after < 0 else expanded.substr(slash_after + 1)
	var pattern_star: = pattern.find("*")
	if pattern_star < 0:
		return PackedStringArray()
	var prefix: = pattern.substr(0, pattern_star)
	var ending: = pattern.substr(pattern_star + 1)
	var dir: = DirAccess.open(parent)
	if dir == null:
		return PackedStringArray()

	var matches: = PackedStringArray()
	for child in dir.get_directories():
		if _wildcard_segment_matches(String(child), prefix, ending):
			var matched_path: = parent.path_join(String(child))
			matches.append(matched_path if suffix.is_empty() else matched_path.path_join(suffix))
	matches.sort()
	return matches



















static func expand(template: String) -> String:
	if template.is_empty():
		return ""
	var out: = template
	if out.begins_with("~/") or out == "~":
		var home: = _home()
		if not home.is_empty():
			out = home if out == "~" else home.path_join(out.substr(2))

	for var_name in ["XDG_CONFIG_HOME", "LOCALAPPDATA", "USERPROFILE", "APPDATA", "HOME"]:
		var token: = "$%s" % var_name
		if out.find(token) < 0:
			continue
		var value: = env_lookup(_env_source(var_name))
		if value.is_empty():
			value = _home_fallback(var_name)
		if value.is_empty():
			continue
		out = out.replace(token, value)
	return out













static func _env_source(var_name: String) -> String:
	if var_name == "XDG_CONFIG_HOME" and not _flatpak_info_text().is_empty():
		return "HOST_XDG_CONFIG_HOME"
	return var_name




















static func flatpak_write_block(path: String) -> Dictionary:
	var info: = _flatpak_info_text()
	if info.is_empty():
		return {}
	var directory: = McpAtomicWrite._resolve_symlink_target(path).get_base_dir()
	var home: = _home()
	var inside_home: = (
		not home.is_empty() and McpTransportCapability.path_is_within(home, directory)
	)
	var grant: = McpTransportCapability.flatpak_grant_over(
		info, directory, home, expand("$XDG_CONFIG_HOME")
	)
	if not grant.get("writable", false):
		if not grant.is_empty():
			return {"needs": str(grant["location"])}


		var apps: = home.path_join(".var/app") + "/"
		if inside_home and directory.begins_with(apps):
			return {"needs": apps + directory.trim_prefix(apps).get_slice("/", 0)}
		return {"needs": "home" if inside_home else directory}
	var root: = str(grant["root"])
	var real_root: = McpTransportCapability.real_path(root)
	var mount: = McpTransportCapability.flatpak_blocking_mount(
		_flatpak_mount_list(), 
		McpTransportCapability.real_path(directory), 
		McpTransportCapability.real_path(home) if inside_home else real_root, 
	)
	if mount.is_empty():
		return {}
	var mount_point: = str(mount["mount_point"])
	if mount["read_only"]:
		return {"read_only": mount_point}


	if not McpTransportCapability.path_is_within(real_root, mount_point):
		return {"unmounted": root}
	return {"hidden": mount_point}








static func _home_fallback(var_name: String) -> String:
	var home: = _home()
	if home.is_empty():
		return ""
	match var_name:
		"XDG_CONFIG_HOME":
			return home.path_join(".config")
		"APPDATA":
			return home.path_join("AppData/Roaming")
		"LOCALAPPDATA":
			return home.path_join("AppData/Local")
		"HOME":
			return home
	return ""


static func _os_key() -> String:
	match OS.get_name():
		"macOS":
			return "darwin"
		"Windows":
			return "windows"
		_:
			return "linux"


static func _wildcard_segment_matches(value: String, prefix: String, ending: String) -> bool:



	if value.length() < prefix.length() + ending.length():
		return false
	if OS.get_name() == "Windows":
		return value.to_lower().begins_with(prefix.to_lower()) and value.to_lower().ends_with(ending.to_lower())
	return value.begins_with(prefix) and value.ends_with(ending)


static func _home() -> String:
	var h: = env_lookup("HOME")
	if h.is_empty():
		h = env_lookup("USERPROFILE")
	return h
