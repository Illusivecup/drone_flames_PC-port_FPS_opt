@tool
class_name McpJsonStrategy
extends RefCounted






static func configure(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	launch: Dictionary = {}, 
	project_roots: PackedStringArray = PackedStringArray(), 
) -> Dictionary:
	if _uses_merge_tiers(client):
		return _configure_merged(client, server_name, server_url, launch, project_roots)
	var resolution: = client.resolved_config_path_details()
	var path: = str(resolution.get("path", ""))
	var path_error: = str(resolution.get("error", ""))
	if path_error.is_empty() and not path.is_empty():
		path_error = McpClient.unshared_flatpak_config_error(client.display_name, path)
	if not path_error.is_empty():
		return {"status": "error", "message": path_error}
	if path.is_empty():
		return {"status": "error", "message": "Could not resolve config path for %s on this OS" % client.display_name}

	var create_error: = str(resolution.get("create_error", ""))
	if not create_error.is_empty():
		return {"status": "error", "message": create_error}

	var seed_path: = str(resolution.get("seed_path", ""))
	var read_path: = seed_path if not FileAccess.file_exists(path) and not seed_path.is_empty() else path
	var read: = _read_or_init(read_path)
	if not read["ok"]:
		return {"status": "error", "message": "Refusing to overwrite %s: %s. Fix or move the file, then re-run Configure." % [read_path, read["error"]]}
	var launch_error: = command_launch_error(client, launch)
	if not launch_error.is_empty():
		return {"status": "error", "message": launch_error}
	var config: Dictionary = read["data"]
	var holder: = _ensure_path(config, select_server_key_path(config, client))




	var existing: Variant = holder.get(server_name, null)
	holder[server_name] = build_entry(client, server_url, existing, launch)



	if _has_lossy_numbers(config):
		return {"status": "error", "message": "Refusing to rewrite %s: contains integers above 2^53 that Godot's JSON parser would re-emit imprecise. Edit the file by hand." % path}
	if not McpAtomicWrite.write(path, JSON.stringify(_narrow_integral_numbers(config), "\t", false)):
		return {"status": "error", "message": "Cannot write to %s" % path}
	return {"status": "ok", "message": McpClient.configured_message(client, server_url)}




static func _configure_merged(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	launch: Dictionary, 
	project_roots: PackedStringArray, 
) -> Dictionary:
	var write_error: = _merge_write_error(client)
	if not write_error.is_empty():
		return {"status": "error", "message": write_error}
	var launch_error: = command_launch_error(client, launch)
	if not launch_error.is_empty():
		return {"status": "error", "message": launch_error}



	var scope_error: = _scope_ambiguity_error(client)
	if not scope_error.is_empty():
		return {"status": "error", "message": scope_error}
	var project: = _load_project_definitions(client, server_name, project_roots)
	if not project.get("ok", false):
		return {"status": "error", "message": str(project.get("error", "Cannot inspect project config tiers"))}
	var project_tiers: Array = project.get("tiers", [])
	if not project_tiers.is_empty():
		return {"status": "error", "message": _project_override_message(project_tiers, "update or remove", client.display_name, server_name)}
	var loaded: = _load_merge_tiers(client)
	if not loaded.get("ok", false):
		return {"status": "error", "message": str(loaded.get("error", "Cannot read merged config tiers"))}
	var tiers: Array = loaded.get("tiers", [])
	if tiers.is_empty():
		return {"status": "error", "message": "Could not resolve config path for %s on this OS" % client.display_name}
	var denylist_error: = _denylist_error(client, tiers, server_name)
	if not denylist_error.is_empty():
		return {"status": "error", "message": denylist_error}
	var target_index: = 0
	for index in range(tiers.size()):
		var config: Dictionary = tiers[index]["data"]
		var holder: = _walk_path(config, select_server_key_path(config, client))
		if holder is Dictionary and holder.has(server_name):
			target_index = index


			if _first_wins(client):
				break
	var tier: Dictionary = tiers[target_index]
	var config: Dictionary = tier["data"]
	var holder: = _ensure_path(config, select_server_key_path(config, client))
	var existing: Variant = holder.get(server_name, null)
	var disabled_error: = _disabled_entry_error(client, tiers, server_name, existing, str(tier["path"]))
	if not disabled_error.is_empty():
		return {"status": "error", "message": disabled_error}
	holder[server_name] = build_entry(client, server_url, existing, launch)
	var path: = str(tier["path"])


	if _has_lossy_numbers(config):
		return {"status": "error", "message": "Refusing to rewrite %s: contains integers above 2^53 that Godot's JSON parser would re-emit imprecise. Edit the file by hand." % path}
	if not McpAtomicWrite.write(path, JSON.stringify(_narrow_integral_numbers(config), "\t", false)):
		return {"status": "error", "message": "Cannot write to %s" % path}








	var message: = McpClient.configured_message(client, server_url)
	var external_cwd: = str(McpClientConfigurator._editor_setting_lookup(McpClientConfigurator.SETTING_EXTERNAL_CLIENT_CWD))
	if external_cwd.is_empty() and project_tiers.is_empty():
		message += " If %s is launched from a cwd this editor cannot see, the effective entry may still be in a project-tier file — set godot_ai/external_client_cwd to that cwd to verify." % client.display_name
	return {"status": "ok", "message": message}


static func check_status(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	launch: Dictionary = {}, 
	project_roots: PackedStringArray = PackedStringArray(), 
) -> McpClient.Status:
	return check_status_details(client, server_name, server_url, launch, project_roots).get("status", McpClient.Status.NOT_CONFIGURED)







static func check_status_details(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	launch: Dictionary = {}, 
	project_roots: PackedStringArray = PackedStringArray(), 
) -> Dictionary:
	if _uses_merge_tiers(client):
		return _check_status_merged(client, server_name, server_url, launch, project_roots)
	var resolution: = client.resolved_config_path_details()
	var path: = str(resolution.get("path", ""))
	var path_error: = str(resolution.get("error", ""))
	if not path_error.is_empty():
		return {"status": McpClient.Status.ERROR, "error_msg": path_error}
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"status": McpClient.Status.NOT_CONFIGURED, "error_msg": ""}
	var read: = _read_or_init(path, _status_allows_comments(client))
	if not read["ok"]:
		return {"status": McpClient.Status.ERROR, "error_msg": String(read["error"])}
	var config: Dictionary = read["data"]
	var holder: = _walk_path(config, select_server_key_path(config, client))
	if not (holder is Dictionary) or not holder.has(server_name):
		return {"status": McpClient.Status.NOT_CONFIGURED, "error_msg": ""}
	return _entry_status_details(client, holder[server_name], server_url, launch)



static func _check_status_merged(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	launch: Dictionary, 
	project_roots: PackedStringArray, 
) -> Dictionary:
	var scope_error: = _scope_ambiguity_error(client)
	if not scope_error.is_empty():
		return {"status": McpClient.Status.ERROR, "error_msg": scope_error}
	var allow_comments: = _status_allows_comments(client)
	var loaded: = _load_merge_tiers(client, allow_comments)
	if not loaded.get("ok", false):
		return {"status": McpClient.Status.ERROR, "error_msg": str(loaded.get("error", "Cannot read merged config tiers"))}
	var effective: Variant = null
	var effective_path: = ""
	for tier in loaded.get("tiers", []):
		var config: Dictionary = tier["data"]
		var holder: = _walk_path(config, select_server_key_path(config, client))
		if holder is Dictionary and holder.has(server_name):
			effective = holder[server_name]
			effective_path = str(tier["path"])


			if _first_wins(client):
				break
	var project: = _load_project_definitions(client, server_name, project_roots, allow_comments)
	if not project.get("ok", false):
		return {"status": McpClient.Status.ERROR, "error_msg": str(project.get("error", "Cannot inspect project config tiers"))}
	var project_tiers: Array = project.get("tiers", [])
	if effective != null or not project_tiers.is_empty():
		var denylist_error: = _denylist_error(client, loaded.get("tiers", []), server_name)
		if not denylist_error.is_empty():
			return {"status": McpClient.Status.CONFIGURED_MISMATCH, "error_msg": denylist_error}
	if not project_tiers.is_empty():







		var effective_index: = 0 if _first_wins(client) else project_tiers.size() - 1
		var effective_tier: Dictionary = project_tiers[effective_index]
		var disabled_error: = _disabled_entry_error(client, loaded.get("tiers", []), server_name, effective_tier["entry"], str(effective_tier["path"]))
		if not disabled_error.is_empty():
			return {"status": McpClient.Status.CONFIGURED_MISMATCH, "error_msg": disabled_error}
		var details: = _entry_status_details(client, effective_tier["entry"], server_url, launch)
		if details.get("status") != McpClient.Status.CONFIGURED:


			var mismatch: = details.duplicate()
			mismatch["status"] = McpClient.Status.CONFIGURED_MISMATCH
			mismatch["error_msg"] = _project_override_message([effective_tier], "update or remove", client.display_name, server_name)
			return mismatch
		return {"status": McpClient.Status.CONFIGURED, "error_msg": ""}
	if effective == null:
		return {"status": McpClient.Status.NOT_CONFIGURED, "error_msg": ""}
	var disabled_error: = _disabled_entry_error(client, loaded.get("tiers", []), server_name, effective, effective_path)
	if not disabled_error.is_empty():
		return {"status": McpClient.Status.CONFIGURED_MISMATCH, "error_msg": disabled_error}
	return _entry_status_details(client, effective, server_url, launch)


static func _entry_status_details(
	client: McpClient, 
	entry: Variant, 
	server_url: String, 
	launch: Dictionary, 
) -> Dictionary:
	if not (entry is Dictionary):
		return {"status": McpClient.Status.NOT_CONFIGURED, "error_msg": ""}
	var launch_error: = command_launch_error(client, launch)
	if not launch_error.is_empty():
		return {"status": McpClient.Status.ERROR, "error_msg": launch_error}
	if verify_entry(client, entry, server_url, launch):
		return {"status": McpClient.Status.CONFIGURED, "error_msg": ""}
	return {
		"status": McpClient.Status.CONFIGURED_MISMATCH, 
		"error_msg": "", 
		"owned": McpClient.launch_values_mention_godot_ai(McpClient.entry_launch_values(entry)), 
	}


static func remove(
	client: McpClient, 
	server_name: String, 
	project_roots: PackedStringArray = PackedStringArray(), 
) -> Dictionary:
	if _uses_merge_tiers(client):
		return _remove_merged(client, server_name, project_roots)
	var resolution: = client.resolved_config_path_details()
	var path: = str(resolution.get("path", ""))
	var path_error: = str(resolution.get("error", ""))
	if path_error.is_empty() and not path.is_empty():
		path_error = McpClient.unshared_flatpak_config_error(client.display_name, path)
	if not path_error.is_empty():
		return {"status": "error", "message": path_error}
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"status": "ok", "message": "Not configured"}




	var file_read: = _read_file_text(path)
	if not file_read.get("ok", false):
		return {"status": "error", "message": "Refusing to rewrite %s: %s." % [path, file_read.get("error", "")]}
	var config: Dictionary = file_read.get("data", {})
	var key_path: = select_server_key_path(config, client)
	var original_text: String = str(file_read.get("original_text", ""))
	var updated: String = _text_remove_server_entry(original_text, key_path, server_name)
	if updated == original_text:
		return {"status": "ok", "message": "Not configured"}
	if not McpAtomicWrite.write(path, updated):
		return {"status": "error", "message": "Cannot write to %s" % path}
	return {"status": "ok", "message": "%s configuration removed" % client.display_name}


static func _remove_merged(
	client: McpClient, server_name: String, project_roots: PackedStringArray
) -> Dictionary:
	var write_error: = _merge_write_error(client)
	if not write_error.is_empty():
		return {"status": "error", "message": write_error}



	var scope_error: = _scope_ambiguity_error(client)
	if not scope_error.is_empty():
		return {"status": "error", "message": scope_error}
	var project: = _load_project_definitions(client, server_name, project_roots)
	if not project.get("ok", false):
		return {"status": "error", "message": str(project.get("error", "Cannot inspect project config tiers"))}
	var project_tiers: Array = project.get("tiers", [])
	if not project_tiers.is_empty():
		return {"status": "error", "message": _project_override_message(project_tiers, "remove", client.display_name, server_name)}
	var loaded: = _load_merge_tiers(client)
	if not loaded.get("ok", false):
		return {"status": "error", "message": str(loaded.get("error", "Cannot read merged config tiers"))}
	var writes: Array[Dictionary] = []
	for tier in loaded.get("tiers", []):
		if not tier.get("exists", false):
			continue
		var key_path: = select_server_key_path(tier["data"], client)
		var original: String = str(tier.get("original_text", ""))





		var updated: String = _text_remove_server_entry(original, key_path, server_name)
		if updated == original:
			continue
		writes.append({
			"path": tier["path"], 
			"text": updated, 
			"original_text": original, 
		})
	if writes.is_empty():
		return {"status": "ok", "message": "Not configured"}
	var written: = _write_transaction(writes)
	if not written.get("ok", false):
		return {"status": "error", "message": written.get("error", "Cannot remove merged configuration")}
	return {"status": "ok", "message": "%s configuration removed" % client.display_name}






static func build_entry(
	client: McpClient, 
	server_url: String, 
	existing: Variant = null, 
	launch: Dictionary = {}, 
) -> Dictionary:
	if _is_supported_command_shape(client.command_shape):
		var command_entry: Dictionary = (existing as Dictionary).duplicate(true) if existing is Dictionary else {}
		if client.command_shape == McpClient.CommandShape.COMMAND_ARRAY:



			command_entry["command"] = _launch_argv(launch)
			command_entry.erase("args")
		else:
			command_entry["command"] = str(launch.get("command", ""))
			command_entry["args"] = _array_copy(launch.get("args", []))
		if not client.command_transport_key.is_empty():
			command_entry[client.command_transport_key] = client.command_transport_value
		for key in client.command_initial_fields:
			if not command_entry.has(key):
				command_entry[key] = client.command_initial_fields[key]
		for key in client.command_legacy_keys:
			command_entry.erase(String(key))
		_remove_legacy_env_keys(command_entry, client.command_env_legacy_keys)
		return command_entry
	if client.command_shape != McpClient.CommandShape.NONE:
		return {}
	return build_url_entry(client, server_url, existing)


static func build_url_entry(client: McpClient, server_url: String, existing: Variant = null) -> Dictionary:
	var entry: Dictionary = (existing as Dictionary).duplicate(true) if existing is Dictionary else {}
	entry[client.entry_url_field] = server_url
	for k in client.entry_extra_fields:
		entry[k] = client.entry_extra_fields[k]
	for k in client.entry_initial_fields:
		if not entry.has(k):
			entry[k] = client.entry_initial_fields[k]
	return entry








static func verify_entry(
	client: McpClient, 
	entry: Dictionary, 
	server_url: String, 
	launch: Dictionary = {}, 
) -> bool:
	if client.command_shape != McpClient.CommandShape.NONE:
		if not _is_supported_command_shape(client.command_shape) or not bool(launch.get("ok", false)):
			return false
		for key in client.command_legacy_keys:
			if entry.has(String(key)):
				return false
		var env = entry.get("env", null)
		if env is Dictionary:
			for key in client.command_env_legacy_keys:
				if env.has(String(key)):
					return false
		if client.command_shape == McpClient.CommandShape.COMMAND_ARRAY:
			if not _arrays_equal(entry.get("command", null), _launch_argv(launch)):
				return false
			if entry.has("args"):
				return false
		else:
			if entry.get("command") != launch.get("command"):
				return false
			if not _arrays_equal(entry.get("args", null), launch.get("args", null)):
				return false
		if not client.command_transport_key.is_empty():
			if not entry.has(client.command_transport_key):
				return false
			if entry.get(client.command_transport_key) != client.command_transport_value:
				return false
		return true
	if entry.get(client.entry_url_field, "") != server_url:
		return false
	for k in client.entry_extra_fields:
		if entry.get(k) != client.entry_extra_fields[k]:
			return false
	return true


static func command_launch_error(client: McpClient, launch: Dictionary) -> String:
	if client.command_shape == McpClient.CommandShape.NONE:
		return ""
	if not _is_supported_command_shape(client.command_shape):
		return "%s uses a command shape not supported by JSON yet" % client.display_name
	if not bool(launch.get("ok", false)):
		return str(launch.get("error", "No compatible attach launcher was found."))
	return ""


static func _is_supported_command_shape(shape: McpClient.CommandShape) -> bool:
	return shape == McpClient.CommandShape.FLAT or shape == McpClient.CommandShape.COMMAND_ARRAY



static func _launch_argv(launch: Dictionary) -> Array:
	var argv: Array = [str(launch.get("command", ""))]
	argv.append_array(_array_copy(launch.get("args", [])))
	return argv


static func _remove_legacy_env_keys(entry: Dictionary, legacy_keys: PackedStringArray) -> void :
	if legacy_keys.is_empty():
		return
	var existing_env = entry.get("env", null)
	if not (existing_env is Dictionary):
		return
	var env: Dictionary = (existing_env as Dictionary).duplicate(true)
	for key in legacy_keys:
		env.erase(String(key))
	if env.is_empty():
		entry.erase("env")
	else:
		entry["env"] = env


static func _array_copy(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	if value is PackedStringArray:
		return McpClient._array_from_packed(value)
	return []


static func _arrays_equal(left: Variant, right: Variant) -> bool:
	if not (left is Array or left is PackedStringArray):
		return false
	if not (right is Array or right is PackedStringArray):
		return false
	var left_array: = _array_copy(left)
	var right_array: = _array_copy(right)
	if left_array.size() != right_array.size():
		return false
	for i in range(left_array.size()):
		if left_array[i] != right_array[i]:
			return false
	return true













static func _read_file_text(path: String, allow_comments: bool = false) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "ok": true, "data": {}, "original_text": ""}
	var file: = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_err: = FileAccess.get_open_error()
		return {"exists": true, "ok": false, "error": "could not open for reading (error %d)" % open_err, "original_text": ""}






	var buf: = file.get_buffer(file.get_length())
	file.close()
	var had_bom: = buf.size() >= 3 and buf[0] == 239 and buf[1] == 187 and buf[2] == 191
	var content: = buf.get_string_from_utf8()
	if had_bom and not content.begins_with(""):
		content = "" + content



	var body: = content.substr(1) if content.begins_with("") else content
	if body.strip_edges().is_empty():
		return {"exists": true, "ok": true, "data": {}, "original_text": content}
	var parse_copy: = body
	if allow_comments:



		var stripped: = _strip_jsonc(parse_copy)
		if not stripped.get("ok", false):
			var strip_msg: = str(stripped.get("error", "invalid JSONC"))
			push_warning("MCP | %s in %s" % [strip_msg, path])
			return {"exists": true, "ok": false, "error": strip_msg, "original_text": content}
		parse_copy = str(stripped.get("text", ""))
	var json: = JSON.new()
	if json.parse(parse_copy) != OK:
		var msg: = "JSON parse error on line %d: %s" % [json.get_error_line(), json.get_error_message()]
		push_warning("MCP | %s in %s" % [msg, path])
		return {"exists": true, "ok": false, "error": msg, "original_text": content}
	if not (json.data is Dictionary):
		return {"exists": true, "ok": false, "error": "top-level value is %s, expected object" % type_string(typeof(json.data)), "original_text": content}
	return {"exists": true, "ok": true, "data": json.data, "original_text": content}





static func _status_allows_comments(client: McpClient) -> bool:
	return client.config_allows_comments and not client.automatic_config_edits





static func _strip_jsonc(text: String) -> Dictionary:
	var parts: = PackedStringArray()
	var i: = 0
	var n: = text.length()
	var in_string: = false
	var escape: = false
	var run_start: = 0
	while i < n:
		var c: = text[i]
		if in_string:
			if escape:
				escape = false
			elif c == "\\":
				escape = true
			elif c == "\"":
				in_string = false
			i += 1
			continue
		if c == "\"":
			in_string = true
			i += 1
			continue
		var skipped: = _skip_jsonc_comment_at(text, i)
		if skipped < 0:
			return {"ok": false, "error": "unterminated block comment"}
		if skipped != i:
			if i > run_start:
				parts.append(text.substr(run_start, i - run_start))

			var emitted_nl: = false
			for j in range(i, skipped):
				if text[j] == "\n":
					parts.append("\n")
					emitted_nl = true


			if not emitted_nl:
				parts.append(" ")
			i = skipped
			run_start = i
			continue
		i += 1
	if in_string:
		return {"ok": false, "error": "unterminated string"}
	if n > run_start:
		parts.append(text.substr(run_start, n - run_start))
	return {"ok": true, "text": "".join(parts)}





static func _skip_jsonc_comment_at(text: String, i: int) -> int:
	var n: = text.length()
	if i + 1 >= n or text[i] != "/":
		return i
	if text[i + 1] == "/":
		i += 2


		while i < n and text[i] != "\n" and text[i] != "\r":
			i += 1
		return i
	if text[i + 1] == "*":
		i += 2
		while i + 1 < n:
			if text[i] == "*" and text[i + 1] == "/":
				return i + 2
			i += 1
		return -1
	return i







static func _read_or_init(path: String, allow_comments: bool = false) -> Dictionary:
	var read: = _read_file_text(path, allow_comments)
	var result: Dictionary = {"ok": read.get("ok", false), "data": read.get("data", {})}
	if not result.get("ok", false):
		result["error"] = read.get("error", "")
	return result



static func _ensure_path(root: Dictionary, key_path: PackedStringArray) -> Dictionary:
	var cur: = root
	for key in key_path:
		var next = cur.get(key)
		if not (next is Dictionary):
			next = {}
			cur[key] = next
		cur = next
	return cur



static func _walk_path(root: Dictionary, key_path: PackedStringArray) -> Variant:
	var cur: Variant = root
	for key in key_path:
		if not (cur is Dictionary) or not cur.has(key):
			return null
		cur = cur[key]
	return cur






static func select_server_key_path(root: Dictionary, client: McpClient) -> PackedStringArray:
	var candidates: Array[PackedStringArray] = [client.server_key_path]


	var aliases = client.get("server_key_path_aliases")
	if aliases is Array:
		for alias in aliases:
			if alias is PackedStringArray:
				candidates.append(alias)
	for key_path in candidates:
		if _walk_path(root, key_path) != null:
			return key_path
	return client.server_key_path


static func _uses_merge_tiers(client: McpClient) -> bool:
	var templates = client.get("config_merge_path_templates")
	return templates is Dictionary and not templates.is_empty()




static func _first_wins(client: McpClient) -> bool:
	return bool(client.get("config_merge_first_wins"))






static func _scope_ambiguity_error(client: McpClient) -> String:
	var env_names: Variant = client.get("config_scope_envs")
	if env_names is PackedStringArray:
		for env_name in env_names:
			if not McpPathTemplate.env_lookup(env_name).is_empty():
				return "%s is set and may relocate %s configuration. Confirm the active client config path and edit the entry manually; default-profile files were not changed." % [env_name, client.display_name]
	var globs: Variant = client.get("config_scope_globs")
	if not (globs is PackedStringArray):
		return ""
	var found: = PackedStringArray()
	for template in globs:
		for candidate in McpPathTemplate.expand_path_candidates(String(template)):
			if DirAccess.dir_exists_absolute(candidate) and not found.has(candidate):
				found.append(candidate)
	if found.is_empty():
		return ""
	return (
		"%s named profiles found at %s. A named profile reads only its own agent config and the active profile is chosen per %s launch, so this editor cannot resolve the effective destination; edit the entry manually."
		%[client.display_name, ", ".join(found), client.display_name]
	)


static func _disabled_entry_error(client: McpClient, tiers: Array, server_name: String, entry: Variant, path: String) -> String:
	if client.config_enabled_key.is_empty() or not (entry is Dictionary):
		return ""
	var enabled: Variant = entry.get(client.config_enabled_key)
	var disabled: bool = (enabled is bool and not enabled) or (enabled is String and enabled.to_lower() in ["false", "0"])
	if not disabled:
		return ""
	if not client.config_allowlist_key.is_empty() and not tiers.is_empty():
		var allowed: Variant = tiers[0]["data"].get(client.config_allowlist_key)
		if allowed is Array and allowed.has(server_name):
			return ""
	return "%s is disabled by %s in %s. Re-enable it in %s before configuring; all files were left unchanged." % [server_name, client.config_enabled_key, path, client.display_name]


static func _denylist_error(client: McpClient, tiers: Array, server_name: String) -> String:
	var key: Variant = client.get("config_denylist_key")
	if not (key is String) or String(key).is_empty() or tiers.is_empty():
		return ""
	var primary: Dictionary = tiers[0]
	var denylist: Variant = primary["data"].get(key, null)
	if denylist is Array and denylist.has(server_name):
		return "%s is disabled by %s in %s. Review that primary config manually before configuring; all files were left unchanged." % [server_name, key, primary["path"]]
	return ""



static func _merge_paths(client: McpClient) -> PackedStringArray:
	var result: = PackedStringArray()
	var templates = client.get("config_merge_path_templates")
	if templates is Dictionary:
		var platform_key: = McpPathTemplate.platform_key(templates)
		if not platform_key.is_empty():
			var raw_paths: Variant = templates.get(platform_key, [])
			if raw_paths is Array or raw_paths is PackedStringArray:
				for template in raw_paths:
					var path: = McpPathTemplate.expand(str(template)).simplify_path()
					if not path.is_empty() and not result.has(path):
						result.append(path)
	return result







static func _merge_write_error(client: McpClient) -> String:
	for path in _merge_paths(client):
		if not path.is_absolute_path():
			continue
		var write_error: = McpClient.unshared_flatpak_config_error(client.display_name, path)
		if not write_error.is_empty():
			return write_error
	return ""





static func _project_candidate_paths(
	client: McpClient, roots: PackedStringArray
) -> PackedStringArray:
	var result: = PackedStringArray()
	var project_paths = client.get("config_merge_project_paths")
	if not (project_paths is PackedStringArray):
		return result
	for project_path in project_paths:
		var absolute_path: = String(project_path).simplify_path()
		if absolute_path.is_absolute_path() and FileAccess.file_exists(absolute_path) and not result.has(absolute_path):
			result.append(absolute_path)
	for root in roots:
		if String(root).is_empty():
			continue
		for relative_path in project_paths:
			if String(relative_path).is_absolute_path():
				continue
			var path: = String(root).path_join(String(relative_path)).simplify_path()
			if FileAccess.file_exists(path) and not result.has(path):
				result.append(path)
	return result


static func _load_project_definitions(
	client: McpClient, 
	server_name: String, 
	project_roots: PackedStringArray, 
	allow_comments: bool = false, 
) -> Dictionary:
	var tiers: Array[Dictionary] = []
	for path in _project_candidate_paths(client, project_roots):
		var read: = _read_or_init(path, allow_comments)
		if not read.get("ok", false):
			return {"ok": false, "error": "Cannot inspect project config %s: %s" % [path, read.get("error", "invalid JSON")]}
		var config: Dictionary = read["data"]
		var key_path: = select_server_key_path(config, client)
		var holder: = _walk_path(config, key_path)
		if holder is Dictionary and holder.has(server_name):
			tiers.append({
				"path": path, 
				"data": config, 
				"key_path": key_path, 
				"entry": holder[server_name], 
			})
	return {"ok": true, "tiers": tiers}


static func _project_override_message(
	tiers: Array, action: String, client_name: String, server_name: String
) -> String:
	var paths: = PackedStringArray()
	for tier in tiers:
		paths.append(str(tier["path"]))
	return "%s project config overrides %s at %s. %s resolves project files from its own working directory, so the dock cannot safely choose one; %s the entry manually." % [client_name, server_name, ", ".join(paths), client_name, action]


static func _load_merge_tiers(client: McpClient, allow_comments: bool = false) -> Dictionary:
	var tiers: Array[Dictionary] = []
	for path in _merge_paths(client):







		if not path.is_absolute_path():
			return {
				"ok": false, 
				"error": McpClient.unresolved_config_path_error(client.display_name, path), 
			}
		var read: = _read_file_text(path, allow_comments)
		if not read.get("ok", false):
			return {
				"ok": false, 
				"error": "Refusing to rewrite %s: %s. Fix or move the file, then re-run Configure." % [path, read.get("error", "invalid JSON")], 
			}
		tiers.append({
			"path": path, 
			"exists": read.get("exists", false), 
			"original_text": read.get("original_text", ""), 
			"data": read.get("data", {}), 
		})
	return {"ok": true, "tiers": tiers}




static func _write_transaction(writes: Array[Dictionary]) -> Dictionary:
	var completed: Array[Dictionary] = []
	for write in writes:
		var path: = str(write["path"])
		if McpAtomicWrite.write(path, str(write["text"])):
			completed.append(write)
			continue
		var rollback_failed: = PackedStringArray()
		completed.reverse()
		for previous in completed:
			if not McpAtomicWrite.write(str(previous["path"]), str(previous["original_text"])):
				rollback_failed.append(str(previous["path"]))
		var suffix: = ""
		if not rollback_failed.is_empty():
			suffix = " Rollback also failed for: %s" % ", ".join(rollback_failed)
		return {"ok": false, "error": "Cannot write to %s; earlier tier changes were rolled back.%s" % [path, suffix]}
	return {"ok": true}



















static func authoritative_tier_path(
	client: McpClient, 
	server_name: String, 
	project_roots: PackedStringArray, 
) -> String:
	if not _uses_merge_tiers(client):
		return ""
	var allow_comments: = _status_allows_comments(client)
	var project: = _load_project_definitions(client, server_name, project_roots, allow_comments)
	if not bool(project.get("ok", false)):
		return ""
	var project_tiers: Array = project.get("tiers", [])
	if not project_tiers.is_empty():



		var effective_index: = 0 if _first_wins(client) else project_tiers.size() - 1
		var effective_tier: Dictionary = project_tiers[effective_index]
		return str(effective_tier.get("path", ""))
	var loaded: = _load_merge_tiers(client, allow_comments)
	if not bool(loaded.get("ok", false)):
		return ""
	var tiers: Array = loaded.get("tiers", [])




	var selected_path: String = ""
	for tier in tiers:
		var data: Dictionary = tier.get("data", {})
		var holder: Variant = _walk_path(data, select_server_key_path(data, client))
		if holder is Dictionary and holder.has(server_name):
			selected_path = str(tier.get("path", ""))
			if _first_wins(client):
				break
	return selected_path




static func manual_target_details(
	client: McpClient, 
	server_name: String, 
	fallback_path: String, 
	project_roots: PackedStringArray = PackedStringArray(), 
) -> Dictionary:


	var allow_comments: = _status_allows_comments(client)
	if _uses_merge_tiers(client):
		var project: = _load_project_definitions(client, server_name, project_roots, allow_comments)
		if not project.get("ok", false):
			return {"ok": false, "error": project.get("error", "Cannot inspect project config tiers")}
		var project_tiers: Array = project.get("tiers", [])
		if project_tiers.size() > 1:
			return {"ok": false, "error": _project_override_message(project_tiers, "update or remove", client.display_name, server_name)}
		if project_tiers.size() == 1:
			var selected_project: Dictionary = project_tiers[0]
			return {
				"ok": true, 
				"path": selected_project["path"], 
				"key_path": selected_project["key_path"], 
			}
		var loaded: = _load_merge_tiers(client, allow_comments)
		if not loaded.get("ok", false):
			return {"ok": false, "error": loaded.get("error", "Cannot read merged config tiers")}
		var tiers: Array = loaded.get("tiers", [])
		var selected: Variant = tiers[0] if not tiers.is_empty() else null
		for tier in tiers:
			var config: Dictionary = tier["data"]
			var holder: = _walk_path(config, select_server_key_path(config, client))
			if holder is Dictionary and holder.has(server_name):
				selected = tier


				if _first_wins(client):
					break
		if selected != null:
			var config: Dictionary = selected["data"]
			return {
				"ok": true, 
				"path": selected["path"], 
				"key_path": select_server_key_path(config, client), 
			}
	var read: = _read_or_init(fallback_path, allow_comments)
	if not read.get("ok", false):
		return {"ok": false, "error": "Cannot inspect %s: %s" % [fallback_path, read.get("error", "invalid JSON")]}
	return {
		"ok": true, 
		"path": fallback_path, 
		"key_path": select_server_key_path(read["data"], client), 
	}













static func _narrow_integral_numbers(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			if is_finite(value) and value == floor(value) and absf(value) <= 9.007199e+15:
				return int(value)
		TYPE_DICTIONARY:
			for k in value:
				value[k] = _narrow_integral_numbers(value[k])
		TYPE_ARRAY:
			for i in value.size():
				value[i] = _narrow_integral_numbers(value[i])
	return value







static func _has_lossy_numbers(value: Variant) -> bool:
	match typeof(value):
		TYPE_FLOAT:





			if is_finite(value) and absf(value) >= 9.007199e+15:
				return true
		TYPE_DICTIONARY:
			for k in value:
				if _has_lossy_numbers(value[k]):
					return true
		TYPE_ARRAY:
			for i in value.size():
				if _has_lossy_numbers(value[i]):
					return true
	return false









static func _text_remove_server_entry(text: String, key_path: PackedStringArray, server_name: String) -> String:





	var cursor: = 0














	if cursor < text.length() and text[cursor] == "":
		cursor += 1
	while cursor < text.length() and _is_json_ws(text[cursor]):
		cursor += 1
	if cursor < text.length() and (text[cursor] == "{" or text[cursor] == "["):
		cursor += 1
	var container_depth: = 0
	for key in key_path:
		var key_bytes: = JSON.stringify(String(key))
		var match : = _find_key_at_container_depth(text, cursor, key_bytes)
		if match .is_empty():
			return text
		var open_char: = text[match ["value_start"]]
		if open_char != "{" and open_char != "[":
			return text
		container_depth += 1
		cursor = match ["value_start"] + 1


	var entry_bytes: = JSON.stringify(server_name)
	var entry_match: = _find_key_at_container_depth(text, cursor, entry_bytes)
	if entry_match.is_empty():
		return text
	var key_start: int = entry_match["key_start"]
	var value_end: int = entry_match["value_end"]






	var remove_end: = value_end



	var trailing_scan: = remove_end
	while trailing_scan < text.length() and _is_json_ws(text[trailing_scan]):
		trailing_scan += 1
	var had_trailing_comma: = trailing_scan < text.length() and text[trailing_scan] == ","
	if had_trailing_comma:

		remove_end = trailing_scan + 1
	while remove_end < text.length() and _is_json_ws(text[remove_end]):
		remove_end += 1
	var remove_start: = key_start
	if not had_trailing_comma:
		while remove_start > 0 and _is_json_ws(text[remove_start - 1]):
			remove_start -= 1
		if remove_start > 0 and text[remove_start - 1] == ",":
			remove_start -= 1
			while remove_start > 0 and _is_json_ws(text[remove_start - 1]):
				remove_start -= 1
	return text.substr(0, remove_start) + text.substr(remove_end)











static func _find_key_at_container_depth(text: String, start: int, key_bytes: String) -> Dictionary:
	var i: = start
	var in_string: = false
	var escape: = false
	var inner_depth: = 0
	while i < text.length():
		var c: = text[i]
		if in_string:
			if escape:
				escape = false
			elif c == "\\":
				escape = true
			elif c == "\"":
				in_string = false
			i += 1
			continue
		if c == "\"":
			if text.substr(i, key_bytes.length()) == key_bytes:
				var after_key: = i + key_bytes.length()
				while after_key < text.length() and _is_json_ws(text[after_key]):
					after_key += 1
				if after_key < text.length() and text[after_key] == ":":
					var value_start: = after_key + 1
					while value_start < text.length() and _is_json_ws(text[value_start]):
						value_start += 1
					var value_end: = _json_value_span_end(text, value_start)
					if value_end >= 0 and inner_depth == 0:
						return {"key_start": i, "value_start": value_start, "value_end": value_end}
			in_string = true
			i += 1
			continue
		if c == "{" or c == "[":
			inner_depth += 1
		elif c == "}" or c == "]":
			inner_depth -= 1






			if inner_depth < 0:
				return {}
		i += 1
	return {}






static func _json_value_span_end(text: String, value_start: int) -> int:
	if value_start >= text.length():
		return -1
	var c: = text[value_start]
	if c == "{" or c == "[":
		var open_char: = c
		var close_char: = "}" if c == "{" else "]"
		var depth: = 1
		var i: = value_start + 1
		var in_string: = false
		var escape: = false
		while i < text.length() and depth > 0:
			var ch: = text[i]
			if in_string:
				if escape:
					escape = false
				elif ch == "\\":
					escape = true
				elif ch == "\"":
					in_string = false
				i += 1
				continue
			if ch == "\"":
				in_string = true
			elif ch == open_char:
				depth += 1
			elif ch == close_char:
				depth -= 1
			i += 1
		return i if depth == 0 else -1
	if c == "\"":
		var i: = value_start + 1
		var escape: = false
		while i < text.length():
			var ch: = text[i]
			if escape:
				escape = false
			elif ch == "\\":
				escape = true
			elif ch == "\"":
				return i + 1
			i += 1
		return -1


	var i: = value_start
	while i < text.length():
		var ch: = text[i]
		if ch == "," or ch == "}" or ch == "]" or _is_json_ws(ch):
			break
		i += 1
	return i


static func _is_json_ws(c: String) -> bool:
	return c == " " or c == "\t" or c == "\n" or c == "\r"
