@tool
class_name McpClient
extends RefCounted


















enum Status{NOT_CONFIGURED, CONFIGURED, CONFIGURED_MISMATCH, ERROR}







static func status_label(status: McpClient.Status) -> String:
	match status:
		Status.CONFIGURED:
			return "configured"
		Status.NOT_CONFIGURED:
			return "not_configured"
		Status.CONFIGURED_MISMATCH:
			return "configured_mismatch"
	return "error"







static func configured_message(client: McpClient, server_url: String) -> String:
	if client.command_shape != CommandShape.NONE:
		return "%s configured (stdio attach)" % client.display_name
	return "%s configured (HTTP: %s)" % [client.display_name, server_url]

var id: String = ""
var display_name: String = ""
var config_type: String = ""



var automatic_config_edits: bool = true






var config_allows_comments: bool = false




var path_template: Dictionary = {}































var config_path_candidates: Dictionary = {}










var config_merge_path_templates: Dictionary = {}



var config_merge_project_paths: PackedStringArray = PackedStringArray()









var config_merge_first_wins: bool = false








var config_scope_globs: PackedStringArray = PackedStringArray()



var config_scope_envs: PackedStringArray = PackedStringArray()




var config_denylist_key: String = ""




var config_enabled_key: String = ""
var config_allowlist_key: String = ""




var _last_config_path_warning: = ""
var _config_path_warning_mutex: = Mutex.new()





var server_key_path: PackedStringArray = PackedStringArray()



var server_key_path_aliases: Array[PackedStringArray] = []



var entry_url_field: String = "url"










var entry_extra_fields: Dictionary = {}










var entry_initial_fields: Dictionary = {}























enum CommandShape{NONE, FLAT, TYPED_FLAT, COMMAND_ARRAY, NESTED_COMMAND}
var command_shape: CommandShape = CommandShape.NONE



var command_transport_key: String = ""
var command_transport_value: Variant = null







var needs_consoleless_launcher: bool = true




var command_legacy_keys: PackedStringArray = PackedStringArray()




var command_env_legacy_keys: PackedStringArray = PackedStringArray()



var command_initial_fields: Dictionary = {}




var command_user_fields: PackedStringArray = PackedStringArray()
var command_timeout_fields: PackedStringArray = PackedStringArray()





var detect_paths: PackedStringArray = PackedStringArray()







var config_file_env: String = ""










var config_home_env: String = ""



var config_home_env_subpath: String = ""


var cli_names: PackedStringArray = PackedStringArray()






var cli_register_template: PackedStringArray = PackedStringArray()
var cli_unregister_template: PackedStringArray = PackedStringArray()



var cli_status_args: PackedStringArray = PackedStringArray()









var cli_scope_status_template: PackedStringArray = PackedStringArray()




var toml_section_path: PackedStringArray = PackedStringArray()
var toml_legacy_section_aliases: PackedStringArray = PackedStringArray()


var toml_body_template: PackedStringArray = PackedStringArray()






func resolved_config_path() -> String:
	return str(resolved_config_path_details().get("path", ""))






func resolved_config_path_details() -> Dictionary:
	var details: = _resolve_config_path_details()
	var path: = str(details.get("path", ""))
	if path.is_empty() or path.is_absolute_path():
		return details









	return {"path": "", "error": unresolved_config_path_error(display_name, path)}




func config_write_error() -> String:
	var path: = resolved_config_path()
	return "" if path.is_empty() else unshared_flatpak_config_error(display_name, path)












static func unshared_flatpak_config_error(client_name: String, path: String) -> String:
	var block: = McpPathTemplate.flatpak_write_block(path)
	if block.is_empty():
		return ""
	var refused: = (
		"Godot runs in a Flatpak sandbox that cannot write %s where %s reads "
		+ "it, so nothing was changed."
	) % [path, client_name]
	var by_hand: = "or edit that file by hand (docs/steam-capability-directory.md)."
	if block.has("unmounted"):
		return refused + (
			" Flatpak was asked to share %s but mounted nothing there, which "
			+ "is what it does when the directory does not exist as Godot "
			+ "starts. Create it, restart Godot, and try again, %s"
		) % [block["unmounted"], by_hand]
	if block.has("hidden"):
		return refused + (
			" Flatpak hides %s from this sandbox, as a --nofilesystem rule "
			+ "does. Remove that rule, restart Godot, and try again, %s"
		) % [block["hidden"], by_hand]
	if block.has("read_only"):
		return refused + (
			" %s is mounted read-only. Make it writable, restart Godot, and "
			+ "try again, %s"
		) % [block["read_only"], by_hand]
	var app_id: = McpPathTemplate.flatpak_app_id()
	return refused + (
		" Run `flatpak override --user --filesystem=%s %s`, restart Godot, "
		+ "and try again, or edit that file by hand: "
		+ "docs/steam-capability-directory.md covers a sandbox without that "
		+ "grant."
	) % [block["needs"], app_id if not app_id.is_empty() else "<Godot's Flatpak ID>"]






static func unresolved_config_path_error(client_name: String, path: String) -> String:
	return (
		"Could not resolve %s's config path: %s did not expand to an absolute "
		+ "path. Set HOME/USERPROFILE (or the variable the path names) in the "
		+ "environment the editor was launched from."
	) % [client_name, path]


func _resolve_config_path_details() -> Dictionary:






	var candidates: Variant = get("config_path_candidates")
	var template: Variant = get("path_template")
	var file_env: Variant = get("config_file_env")
	if not (candidates is Dictionary) or not (template is Dictionary) or not (file_env is String):
		return {"path": "", "error": McpClientRegistry.RESTART_TO_FINISH_UPDATE}
	var file_override: = config_file_override_details()
	if not str(file_override.get("path", "")).is_empty() or not str(file_override.get("error", "")).is_empty():
		_clear_config_path_warning()
		return file_override
	var home_override: = config_home_override_details()
	if not str(home_override.get("path", "")).is_empty() or not str(home_override.get("error", "")).is_empty():
		_clear_config_path_warning()
		return home_override
	var candidate_key: = McpPathTemplate.platform_key(candidates)
	if not candidate_key.is_empty():
		return _resolve_ordered_config_path_candidates(candidates[candidate_key])
	_clear_config_path_warning()
	return {"path": McpPathTemplate.resolve(template), "error": ""}




func config_file_override_details() -> Dictionary:
	if config_file_env.is_empty():
		return {"path": "", "error": ""}

	var raw_path: = McpPathTemplate.env_lookup(config_file_env).strip_edges()
	if raw_path.is_empty():
		return {"path": "", "error": ""}
	var expanded: = McpPathTemplate.expand(raw_path)
	if not expanded.is_absolute_path():
		return {
			"path": "", 
			"error": "%s's $%s override must be an absolute config-file path; got %s" % [
				display_name, config_file_env, raw_path, 
			], 
		}
	if DirAccess.dir_exists_absolute(expanded):
		return {
			"path": "", 
			"error": "%s's $%s override must point to a config file, not a directory: %s" % [
				display_name, config_file_env, expanded, 
			], 
		}
	return {"path": expanded, "error": ""}


func _resolve_ordered_config_path_candidates(templates: Variant) -> Dictionary:
	if not (templates is Array or templates is PackedStringArray):
		_clear_config_path_warning()
		return {"path": "", "error": ""}
	var ordered_templates: Array = []
	for template_variant in templates:
		ordered_templates.append(str(template_variant))

	var create_templates: = PackedStringArray()
	var create_paths: = PackedStringArray()
	var hidden_app_dirs: = PackedStringArray()
	var hidden_paths: = PackedStringArray()
	for index in range(ordered_templates.size()):
		var template: = str(ordered_templates[index])
		var expanded_template: = McpPathTemplate.expand(template)




		if not expanded_template.is_absolute_path():
			_clear_config_path_warning()
			return {
				"path": "", 
				"error": unresolved_config_path_error(display_name, expanded_template), 
			}
		var group: = McpPathTemplate.expand_path_candidates(template)
		if group.size() > 1:
			var message: = (
				"%s has multiple matching config package paths for %s: %s. "
				+ "Remove the stale package installation or edit the intended config manually."
			) % [display_name, template, ", ".join(group)]
			_warn_config_path_once(message)
			return {"path": "", "error": message}
		if group.is_empty():
			continue
		var path: = String(group[0])
		if FileAccess.file_exists(path):
			_clear_config_path_warning()
			return {"path": path, "error": ""}





		if template.contains("*"):
			var seed: = _first_existing_later_candidate(ordered_templates, index + 1)
			if not str(seed.get("error", "")).is_empty():
				_clear_config_path_warning()
				return {"path": "", "error": seed["error"]}
			_clear_config_path_warning()
			return {"path": path, "error": "", "seed_path": seed.get("path", "")}



		var hidden_app_dir: = McpPathTemplate.hidden_flatpak_app_dir(path)
		if not hidden_app_dir.is_empty():
			hidden_paths.append(path)
			if not hidden_app_dirs.has(hidden_app_dir):
				hidden_app_dirs.append(hidden_app_dir)
			continue
		create_templates.append(template)
		create_paths.append(path)
	_clear_config_path_warning()
	var evident_create_path: = _evident_create_path(create_templates, create_paths)
	if not evident_create_path.is_empty():
		return {"path": evident_create_path, "error": ""}
	var fallback_create_path: = "" if create_paths.is_empty() else create_paths[0]
	if hidden_app_dirs.is_empty():
		return {"path": fallback_create_path, "error": ""}
	var hidden_error: = hidden_flatpak_config_error(
		display_name, fallback_create_path.get_base_dir(), hidden_app_dirs
	)
	if fallback_create_path.is_empty():
		return {"path": "", "error": hidden_error}
	return {
		"path": fallback_create_path, 
		"error": "", 
		"create_error": hidden_error, 
		"hidden_paths": hidden_paths, 
	}













static func _evident_create_path(templates: PackedStringArray, paths: PackedStringArray) -> String:
	if paths.is_empty():
		return ""
	var shared: = _shared_root_length(templates)
	var levels: = -1
	for template in templates:
		var own_directories: = template.split("/").size() - 1 - shared
		levels = own_directories if levels < 0 else mini(levels, own_directories)
	var directories: = PackedStringArray()
	for path in paths:
		directories.append(path.get_base_dir())
	for _level in range(maxi(levels, 0)):
		for index in range(directories.size()):
			if DirAccess.dir_exists_absolute(directories[index]):
				return paths[index]
		for index in range(directories.size()):
			directories[index] = directories[index].get_base_dir()
	return ""





static func _shared_root_length(templates: PackedStringArray) -> int:
	if templates.size() < 2:
		return 1
	var first: = templates[0].split("/")
	var shared: = first.size() - 1
	for index in range(1, templates.size()):
		var other: = templates[index].split("/")
		var limit: = mini(shared, other.size() - 1)
		var same: = 0
		while same < limit and first[same] == other[same]:
			same += 1
		shared = same
	return maxi(shared, 1)






static func hidden_flatpak_config_error(
	client_name: String, settings_dir: String, hidden_app_dirs: PackedStringArray
) -> String:
	var app_id: = McpPathTemplate.flatpak_app_id()
	var grants: = PackedStringArray()
	for app_dir in hidden_app_dirs:
		grants.append("--filesystem=%s" % app_dir)
	var missing: = (
		"%s does not exist" % settings_dir
		if not settings_dir.is_empty()
		else "it has no settings location outside Flatpak"
	)
	return (
		"Could not find where %s keeps its settings: %s, and a Flatpak build "
		+ "keeps them under %s, which Godot's own Flatpak sandbox cannot see. "
		+ "If you use the Flatpak build, run `flatpak override --user %s %s`, "
		+ "restart Godot, and configure again. If it is installed outside "
		+ "Flatpak, start it once so it creates its settings, then configure "
		+ "again."
	) % [
		client_name, missing, ", ".join(hidden_app_dirs), 
		" ".join(grants), app_id if not app_id.is_empty() else "<Godot's Flatpak ID>", 
	]






func _first_existing_later_candidate(templates: Array, start_index: int) -> Dictionary:
	for index in range(start_index, templates.size()):
		var template: = str(templates[index])
		var expanded_template: = McpPathTemplate.expand(template)
		if not expanded_template.is_absolute_path():
			return {
				"path": "", 
				"error": unresolved_config_path_error(display_name, expanded_template), 
			}
		var group: = McpPathTemplate.expand_path_candidates(template)


		if group.size() != 1:
			continue
		var path: = String(group[0])
		if FileAccess.file_exists(path):
			return {"path": path, "error": ""}
	return {"path": "", "error": ""}


func _warn_config_path_once(message: String) -> void :
	_config_path_warning_mutex.lock()
	var should_warn: = message != _last_config_path_warning
	_last_config_path_warning = message
	_config_path_warning_mutex.unlock()
	if should_warn:
		push_warning(message)


func _clear_config_path_warning() -> void :
	_config_path_warning_mutex.lock()
	_last_config_path_warning = ""
	_config_path_warning_mutex.unlock()





func config_home_override_details() -> Dictionary:
	if config_home_env.is_empty() or config_home_env_subpath.is_empty():
		return {"path": "", "error": ""}


	var home: = McpPathTemplate.env_lookup(config_home_env).strip_edges()
	if home.is_empty():
		return {"path": "", "error": ""}

	var expanded: = McpPathTemplate.expand(home)






	if not expanded.is_absolute_path():
		return {
			"path": "", 
			"error": "%s's $%s override must be an absolute config-home directory path; got %s" % [
				display_name, config_home_env, home, 
			], 
		}
	return {"path": expanded.path_join(config_home_env_subpath), "error": ""}





func config_home_override() -> String:
	return str(config_home_override_details().get("path", ""))







func has_json_fallback() -> bool:
	return config_type == "cli" and not path_template.is_empty() and not server_key_path.is_empty()



func is_installed() -> bool:
	if config_type == "cli":
		if not McpCliFinder.find(_array_from_packed(cli_names)).is_empty():
			return true



		if has_json_fallback():
			var cfg: = resolved_config_path()
			return not cfg.is_empty() and FileAccess.file_exists(cfg)
		return false
	for p in detect_paths:
		for resolved in McpPathTemplate.expand_path_candidates(p):
			if FileAccess.file_exists(resolved) or DirAccess.dir_exists_absolute(resolved):
				return true

	var cfg: = resolved_config_path()
	return not cfg.is_empty() and FileAccess.file_exists(cfg)


static func _array_from_packed(packed: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	for s in packed:
		out.append(s)
	return out





static func _packed_slice(packed: PackedStringArray, from: int, to: int) -> PackedStringArray:
	var out: = PackedStringArray()
	for i in range(from, to):
		out.append(packed[i])
	return out








static func launch_mentions_godot_ai(text: String) -> bool:


	return launch_values_mention_godot_ai(PackedStringArray(text.split(" ", false)))





static func launch_values_mention_godot_ai(values: PackedStringArray) -> bool:
	for raw_value in values:
		var value: = raw_value.strip_edges().lstrip("\"'[{(").rstrip("\"'])},")
		if value.is_empty() or value.contains("://"):
			continue
		if value == "godot-ai" or value == "godot_ai" or value.begins_with("godot-ai=="):
			return true
		var base: = value.replace("\\", "/").get_file()
		if base == "godot-ai" or base == "godot-ai.exe":
			return true
	return false





static func entry_launch_values(entry: Dictionary) -> PackedStringArray:
	var values: = PackedStringArray()
	for key in ["command", "args", "url"]:
		if not entry.has(key):
			continue
		var value: Variant = entry[key]
		if value is Array:
			for item in value:
				values.append(str(item))
		else:
			values.append(str(value))
	return values
