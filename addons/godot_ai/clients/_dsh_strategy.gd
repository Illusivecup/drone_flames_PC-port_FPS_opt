@tool
class_name McpDshStrategy
extends RefCounted







































const ENTRY_ID_PREFIX: = "mcp-"




const PLUGIN_NAME: = "@deepseek-ai/dsh-mcp-client"


const ENTRY_INDENT: = 4


static func entry_id(server_name: String) -> String:
	return ENTRY_ID_PREFIX + server_name


static func configure(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	launch: Dictionary = {}, 
) -> Dictionary:
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

	var launch_error: = command_launch_error(client, launch)
	if not launch_error.is_empty():
		return {"status": "error", "message": launch_error}

	var read: = _read(path)
	if not read["ok"]:
		return {"status": "error", "message": "Refusing to overwrite %s: %s. Fix or move the file, then re-run Configure." % [path, read["error"]]}






	var text: = String(read["data"])
	text = _strip_empty_flow_sequence(text)
	if not _is_patch_sequence(text):
		return {
			"status": "error", 
			"message": "Refusing to overwrite %s: it is not a top-level YAML list of loader entries. Fix or remove the file, then re-run Configure." % path, 
		}

	var existing_config: Variant = null
	var lines: = _split_lines(text)
	var found: = _find_entry_block(lines, entry_id(server_name), true)
	if found.is_empty():
		var plain: = _find_entry_block(lines, entry_id(server_name), false)
		if not plain.is_empty():



			found = plain
	if not found.is_empty():


		existing_config = _extract_config(lines, found)
	var new_entry: = build_entry(client, server_name, server_url, existing_config, launch)




	var base_indent: = ENTRY_INDENT
	if not found.is_empty():
		var header_indent: = int(found.get("indent", 0))
		if header_indent > 0:
			base_indent = header_indent
	var rendered: = render_nested_entry(entry_id(server_name), new_entry, base_indent)
	var out: = ""
	if found.is_empty():
		out = _append_row(lines, rendered)
	else:
		out = _replace_lines(lines, found, rendered)
	if not McpAtomicWrite.write(path, out):
		return {"status": "error", "message": "Cannot write to %s" % path}
	return {"status": "ok", "message": McpClient.configured_message(client, server_url)}


static func check_status(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	launch: Dictionary = {}, 
) -> McpClient.Status:
	return check_status_details(client, server_name, server_url, launch)["status"]






static func check_status_details(
	client: McpClient, server_name: String, server_url: String, launch: Dictionary = {}
) -> Dictionary:
	var resolution: = client.resolved_config_path_details()
	var path: = str(resolution.get("path", ""))
	var path_error: = str(resolution.get("error", ""))
	if not path_error.is_empty():
		return {"status": McpClient.Status.ERROR, "error_msg": path_error}
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"status": McpClient.Status.NOT_CONFIGURED, "error_msg": ""}
	var read: = _read(path)
	if not read["ok"]:
		return {
			"status": McpClient.Status.ERROR, 
			"error_msg": "Cannot read %s: %s" % [path, read["error"]], 
		}
	var text: = String(read["data"])
	if not _is_patch_sequence(text):



		return {
			"status": McpClient.Status.ERROR, 
			"error_msg": "%s is not a top-level YAML list of loader entries; fix or remove the file." % path, 
		}
	var lines: = _split_lines(text)
	var found: = _find_entry_block(lines, entry_id(server_name), true)
	if found.is_empty():



		return {"status": McpClient.Status.NOT_CONFIGURED, "error_msg": ""}
	var config: = _extract_config(lines, found)
	if config.is_empty():
		return {"status": McpClient.Status.NOT_CONFIGURED, "error_msg": ""}


	var launch_error: = command_launch_error(client, launch)
	if not launch_error.is_empty():
		return {"status": McpClient.Status.ERROR, "error_msg": launch_error}
	if verify_entry(client, config, server_name, server_url, launch):
		return {"status": McpClient.Status.CONFIGURED, "error_msg": ""}
	return {
		"status": McpClient.Status.CONFIGURED_MISMATCH, 
		"error_msg": "", 
		"owned": McpClient.launch_values_mention_godot_ai(McpClient.entry_launch_values(config)), 
	}


static func remove(client: McpClient, server_name: String) -> Dictionary:
	var resolution: = client.resolved_config_path_details()
	var path: = str(resolution.get("path", ""))
	var path_error: = str(resolution.get("error", ""))
	if path_error.is_empty() and not path.is_empty():
		path_error = McpClient.unshared_flatpak_config_error(client.display_name, path)
	if not path_error.is_empty():
		return {"status": "error", "message": path_error}
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"status": "ok", "message": "Not configured"}
	var read: = _read(path)
	if not read["ok"]:
		return {"status": "error", "message": "Refusing to rewrite %s: %s." % [path, read["error"]]}
	var text: = String(read["data"])
	if not _is_patch_sequence(text):


		return {
			"status": "error", 
			"message": "Refusing to rewrite %s: it is not a top-level YAML list of loader entries. Fix or remove the file, then re-run Remove." % path, 
		}
	var lines: = _split_lines(text)
	var found: = _find_entry_block(lines, entry_id(server_name), true)
	if found.is_empty():
		found = _find_entry_block(lines, entry_id(server_name), false)
	if found.is_empty():
		return {"status": "ok", "message": "%s configuration removed" % client.display_name}
	var out: = _remove_lines(lines, found)
	if _is_blank_or_comment_only(out):





		if FileAccess.file_exists(path):
			var remove_err: = DirAccess.remove_absolute(path)
			if remove_err != OK:
				return {"status": "error", "message": "Cannot remove %s (error %d)" % [path, remove_err]}
		return {"status": "ok", "message": "%s configuration removed" % client.display_name}
	if not McpAtomicWrite.write(path, out):
		return {"status": "error", "message": "Cannot write to %s" % path}
	return {"status": "ok", "message": "%s configuration removed" % client.display_name}






static func build_entry(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	existing: Variant = null, 
	launch: Dictionary = {}, 
) -> Dictionary:
	var entry: Dictionary = (existing as Dictionary).duplicate(true) if existing is Dictionary else {}
	entry["serverName"] = server_name
	if client.command_shape == McpClient.CommandShape.FLAT:
		entry["command"] = str(launch.get("command", ""))
		entry["args"] = _array_copy(launch.get("args", []))
		if not client.command_transport_key.is_empty():
			entry[client.command_transport_key] = client.command_transport_value
		for key in client.command_initial_fields:
			if not entry.has(key):
				entry[key] = client.command_initial_fields[key]
		for key in client.command_legacy_keys:
			entry.erase(String(key))
		return entry
	if client.command_shape == McpClient.CommandShape.NONE:


		return build_url_entry(client, server_name, server_url, existing)
	return {}







static func build_url_entry(
	client: McpClient, server_name: String, server_url: String, existing: Variant = null
) -> Dictionary:
	var entry: Dictionary = (existing as Dictionary).duplicate(true) if existing is Dictionary else {}
	entry["serverName"] = server_name
	entry["transport"] = "streamable-http"
	if not client.entry_url_field.is_empty():
		entry[client.entry_url_field] = server_url
	return entry






static func verify_entry(
	client: McpClient, 
	config: Dictionary, 
	server_name: String, 
	server_url: String, 
	launch: Dictionary = {}, 
) -> bool:
	if config.get("serverName") != server_name:
		return false
	if client.command_shape != McpClient.CommandShape.NONE:
		if client.command_shape != McpClient.CommandShape.FLAT or not bool(launch.get("ok", false)):
			return false
		for key in client.command_legacy_keys:
			if config.has(String(key)):
				return false
		if config.get("command") != launch.get("command"):
			return false
		if not _arrays_equal(config.get("args", null), launch.get("args", null)):
			return false
		if not client.command_transport_key.is_empty():
			if config.get(client.command_transport_key, null) != client.command_transport_value:
				return false
		return true
	if config.get(client.entry_url_field, "") != server_url:
		return false
	return config.get("transport", "") == "streamable-http"





static func command_launch_error(client: McpClient, launch: Dictionary) -> String:
	if client.command_shape == McpClient.CommandShape.NONE:
		return ""
	if client.command_shape != McpClient.CommandShape.FLAT:
		return "%s uses a command shape not supported by DeepSeek Harness config yet" % client.display_name
	if not bool(launch.get("ok", false)):
		return str(launch.get("error", "No compatible attach launcher was found."))
	return ""







static func render_insert_row(entry_id_value: String, config: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = ["- insert:"]
	lines.append_array(render_nested_entry(entry_id_value, config))
	return lines






static func render_nested_entry(
	entry_id_value: String, config: Dictionary, base_indent: int = ENTRY_INDENT
) -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append("%s- id: %s" % [_indent_str(base_indent), entry_id_value])
	lines.append("%sname: '%s'" % [_indent_str(base_indent + 2), PLUGIN_NAME])
	lines.append("%sconfig:" % _indent_str(base_indent + 2))
	for key in config:
		lines.append_array(_emit_field(String(key), config[key], base_indent + 4))
	return lines





static func _emit_field(key: String, value: Variant, indent: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	var prefix: = _indent_str(indent)
	if value is Dictionary:
		lines.append("%s%s:" % [prefix, key])
		for sub_key in value:
			lines.append_array(_emit_field(String(sub_key), value[sub_key], indent + 2))
	elif value is Array or value is PackedStringArray:
		lines.append("%s%s: %s" % [prefix, key, McpYamlStrategy.emit_flow_array(_array_copy(value))])
	else:
		lines.append("%s%s: %s" % [prefix, key, McpYamlStrategy.emit_scalar(value)])
	return lines







static func _split_lines(text: String) -> PackedStringArray:
	if text.is_empty():
		return PackedStringArray()
	var lines: = text.split("\n")
	if lines.size() > 0 and String(lines[lines.size() - 1]).is_empty():
		lines.remove_at(lines.size() - 1)
	return lines














static func _find_entry_block(lines: PackedStringArray, entry_id_value: String, require_nested: bool) -> Dictionary:
	for i in range(lines.size()):
		var indent: = _indent_of(lines[i])
		if require_nested and indent <= 0:
			continue
		if not require_nested and indent != 0:
			continue
		var parsed: = _parse_entry_header(lines[i])
		if parsed.is_empty() or parsed.get("id") != entry_id_value:
			continue



		if require_nested and not _under_insert_row(lines, i):
			continue
		var j: = i + 1
		var last_content: = i
		while j < lines.size():
			var l: = lines[j]
			if _is_blank_or_comment(l):
				j += 1
				continue
			if _indent_of(l) <= indent:
				break
			last_content = j
			j += 1
		return {"start": i, "end": last_content + 1, "indent": indent}
	return {}






static func _under_insert_row(lines: PackedStringArray, index: int) -> bool:
	for i in range(index - 1, -1, -1):
		if _is_blank_or_comment(lines[i]):
			continue
		if _indent_of(lines[i]) == 0:
			return lines[i].strip_edges().begins_with("- insert:")
	return false




static func _parse_entry_header(line: String) -> Dictionary:
	var stripped: = line.strip_edges()
	if not stripped.begins_with("- "):
		return {}
	var body: = stripped.substr(2).strip_edges()
	if not body.begins_with("id:"):
		return {}
	var value: = body.substr(3).strip_edges()
	if value.begins_with("\"") and value.ends_with("\"") and value.length() >= 2:
		var parsed: Variant = JSON.parse_string(value)
		if parsed is String:
			value = parsed
	elif value.begins_with("'") and value.ends_with("'") and value.length() >= 2:
		value = value.substr(1, value.length() - 2)
	return {"id": value}





static func _extract_config(lines: PackedStringArray, block: Dictionary) -> Dictionary:
	var start: = int(block.get("start", -1))
	var end: = int(block.get("end", -1))
	if start < 0:
		return {}
	var config_indent: = -1
	var config_start: = -1
	for i in range(start, end):
		var stripped: = lines[i].strip_edges()
		if _is_blank_or_comment(lines[i]):
			continue
		if stripped == "config:":
			config_indent = _indent_of(lines[i])
			config_start = i
			break
	if config_start < 0:
		return {}
	return _parse_block_lines(lines, config_start + 1, end, config_indent)








static func _parse_block_lines(lines: PackedStringArray, start: int, end: int, min_indent: int) -> Dictionary:
	var out: Dictionary = {}
	var i: = start
	while i < end:
		var l: = lines[i]
		if _is_blank_or_comment(l):
			i += 1
			continue
		var indent: = _indent_of(l)
		if indent <= min_indent:
			break
		var stripped: = l.strip_edges()
		var colon: = stripped.find(":")
		if colon < 0:
			i += 1
			continue
		var key: = stripped.substr(0, colon).strip_edges()
		var value: = stripped.substr(colon + 1).strip_edges()
		if value.is_empty():


			var child_end: = i + 1
			while child_end < end:
				if not _is_blank_or_comment(lines[child_end]) and _indent_of(lines[child_end]) <= indent:
					break
				child_end += 1
			out[key] = _parse_block_lines(lines, i + 1, child_end, indent)
			i = child_end
		else:


			out[key] = McpYamlStrategy.coerce_scalar(value)
			i += 1
	return out






static func _append_row(lines: PackedStringArray, nested_lines: PackedStringArray) -> String:
	var parts: Array[String] = []
	for l in lines:
		parts.append(l)


	while parts.size() > 0 and String(parts[parts.size() - 1]).strip_edges().is_empty():
		parts.remove_at(parts.size() - 1)
	if parts.size() > 0:
		parts.append("")
	parts.append("- insert:")
	for l in nested_lines:
		parts.append(l)
	return _join_lines(parts)







static func _replace_lines(lines: PackedStringArray, block: Dictionary, nested_lines: PackedStringArray) -> String:
	var start: = int(block.get("start", -1))
	var end: = int(block.get("end", -1))
	var parts: Array[String] = []
	for i in range(lines.size()):
		if i == start:


			if _indent_of(lines[start]) > 0:
				for l in nested_lines:
					parts.append(l)
			else:
				parts.append("- insert:")
				for l in nested_lines:
					parts.append(l)
		if i >= start and i < end:
			continue
		parts.append(lines[i])
	return _join_lines(parts)






static func _remove_lines(lines: PackedStringArray, block: Dictionary) -> String:
	var start: = int(block.get("start", -1))
	var end: = int(block.get("end", -1))
	var nested: = _indent_of(lines[start]) > 0
	var parts: Array[String] = []
	if nested:


		var row_start: = -1
		for i in range(start - 1, -1, -1):
			if _indent_of(lines[i]) == 0 and lines[i].strip_edges().begins_with("- "):
				row_start = i
				break

		var row_end: = lines.size()
		for i in range(end, lines.size()):
			if _indent_of(lines[i]) == 0 and not _is_blank_or_comment(lines[i]):
				row_end = i
				break
		var has_other_entries: = false
		for i in range(row_start + 1, row_end):
			if i >= start and i < end:
				continue
			if _is_blank_or_comment(lines[i]):
				continue
			if _indent_of(lines[i]) > 0 and lines[i].strip_edges().begins_with("- "):
				has_other_entries = true
				break
		if has_other_entries or row_start < 0:


			for i in range(lines.size()):
				if i >= start and i < end:
					continue
				parts.append(lines[i])
		else:



			for i in range(lines.size()):
				if i >= row_start and i < end:
					continue
				parts.append(lines[i])
			parts = _trim_trailing_blanks(parts)
	else:

		for i in range(lines.size()):
			if i >= start and i < end:
				continue
			parts.append(lines[i])
		parts = _trim_trailing_blanks(parts)
	return _join_lines(parts)



static func _trim_trailing_blanks(parts: Array[String]) -> Array[String]:
	while parts.size() > 0 and String(parts[parts.size() - 1]).strip_edges().is_empty():
		parts.remove_at(parts.size() - 1)
	return parts





static func _is_blank_or_comment_only(text: String) -> bool:
	for line in text.split("\n"):
		var stripped: = line.strip_edges()
		if not stripped.is_empty() and not stripped.begins_with("#"):
			return false
	return true






static func _strip_empty_flow_sequence(text: String) -> String:
	var lines: = _split_lines(text)
	var bracket_line: = -1
	for i in range(lines.size()):
		if _is_blank_or_comment(lines[i]):
			continue
		if bracket_line < 0 and lines[i].strip_edges() == "[]":
			bracket_line = i
			continue
		return text
	if bracket_line < 0:
		return text
	var parts: Array[String] = []
	for i in range(lines.size()):
		if i != bracket_line:
			parts.append(lines[i])
	if parts.is_empty():
		return ""
	return _join_lines(parts)











static func _is_patch_sequence(text: String) -> bool:
	if text.strip_edges().is_empty():
		return true
	var saw_brackets: = false
	var content_count: = 0
	for line in text.split("\n"):
		var stripped: = line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue
		content_count += 1
		if stripped == "[]":
			saw_brackets = true
			continue
		if _indent_of(line) == 0 and not stripped.begins_with("- "):
			return false
	if saw_brackets and content_count > 1:
		return false
	return true


static func _join_lines(parts: Array) -> String:
	if parts.is_empty():
		return ""
	var lines: Array[String] = []
	for p in parts:
		lines.append(String(p))
	return "\n".join(lines) + "\n"




static func _indent_str(n: int) -> String:
	var out: = ""
	for i in range(n):
		out += " "
	return out


static func _indent_of(line: String) -> int:
	var n: = 0
	while n < line.length() and (line[n] == " " or line[n] == "\t"):
		n += 1
	return n


static func _is_blank_or_comment(line: String) -> bool:
	var stripped: = line.strip_edges()
	return stripped.is_empty() or stripped.begins_with("#")


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






static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "data": ""}
	var f: = FileAccess.open(path, FileAccess.READ)
	if f == null:
		var err: = FileAccess.get_open_error()
		return {"ok": false, "error": "could not open for reading (%s)" % error_string(err)}
	var t: = f.get_as_text()
	f.close()
	return {"ok": true, "data": t}
