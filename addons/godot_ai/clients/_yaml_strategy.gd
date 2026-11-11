@tool
class_name McpYamlStrategy
extends RefCounted











const INDENT: = "  "


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

	var seed_path: = str(resolution.get("seed_path", ""))
	var read_path: = seed_path if not FileAccess.file_exists(path) and not seed_path.is_empty() else path
	var read: = _read(read_path)
	if not read["ok"]:
		return {"status": "error", "message": "Refusing to overwrite %s: %s. Fix or move the file, then re-run Configure." % [read_path, read["error"]]}

	var text: String = read["data"]
	var block: = _extract_block(text)
	var entries: Dictionary = block["entries"]


	var existing: Dictionary = entries.get(server_name, {})
	var new_entry: = build_entry(client, server_url, existing, launch)
	entries[server_name] = new_entry

	var out: = _assemble(text, block["prefix_lines"], entries, block["suffix_lines"])
	if not McpAtomicWrite.write(path, out):
		return {"status": "error", "message": "Cannot write to %s" % path}
	return {"status": "ok", "message": McpClient.configured_message(client, server_url)}


static func check_status(
	client: McpClient, server_name: String, server_url: String, launch: Dictionary = {}
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
	var block: = _extract_block(String(read["data"]))
	var entries: Dictionary = block["entries"]
	if not entries.has(server_name):
		return {"status": McpClient.Status.NOT_CONFIGURED, "error_msg": ""}
	var entry: Variant = entries[server_name]
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
	var text: String = read["data"]
	var block: = _extract_block(text)
	var entries: Dictionary = block["entries"]
	if not entries.has(server_name):
		return {"status": "ok", "message": "%s configuration removed" % client.display_name}
	entries.erase(server_name)
	var out: = _assemble(text, block["prefix_lines"], entries, block["suffix_lines"])
	if not McpAtomicWrite.write(path, out):
		return {"status": "error", "message": "Cannot write to %s" % path}
	return {"status": "ok", "message": "%s configuration removed" % client.display_name}













static func build_entry(
	client: McpClient, 
	server_url: String, 
	existing: Variant = null, 
	launch: Dictionary = {}, 
) -> Dictionary:
	if client.command_shape == McpClient.CommandShape.FLAT:
		var command_entry: Dictionary = (existing as Dictionary).duplicate(true) if existing is Dictionary else {}
		command_entry["command"] = str(launch.get("command", ""))
		command_entry["args"] = _array_copy(launch.get("args", []))
		if not client.command_transport_key.is_empty():
			command_entry[client.command_transport_key] = client.command_transport_value
		for key in client.command_initial_fields:
			if not command_entry.has(key):
				command_entry[key] = client.command_initial_fields[key]
		for key in client.command_legacy_keys:
			command_entry.erase(String(key))
		return command_entry
	if client.command_shape != McpClient.CommandShape.NONE:



		return {}
	var entry: Dictionary = {}
	if existing is Dictionary:




		entry = (existing as Dictionary).duplicate(true)
		for stale_key in _STDIO_BRIDGE_KEYS:
			entry.erase(stale_key)
	entry[client.entry_url_field] = server_url
	return entry





const _STDIO_BRIDGE_KEYS: = ["command", "args", "env"]




static func command_launch_error(client: McpClient, launch: Dictionary) -> String:
	if client.command_shape == McpClient.CommandShape.NONE:
		return ""
	if client.command_shape != McpClient.CommandShape.FLAT:
		return "%s uses a command shape not supported by YAML yet" % client.display_name
	if not bool(launch.get("ok", false)):
		return str(launch.get("error", "No compatible attach launcher was found."))
	return ""










static func verify_entry(
	client: McpClient, 
	entry: Dictionary, 
	server_url: String, 
	launch: Dictionary = {}, 
) -> bool:
	if client.command_shape != McpClient.CommandShape.NONE:
		if client.command_shape != McpClient.CommandShape.FLAT or not bool(launch.get("ok", false)):
			return false
		for key in client.command_legacy_keys:
			if entry.has(String(key)):
				return false
		if entry.get("command") != launch.get("command"):
			return false
		if not _arrays_equal(entry.get("args", null), launch.get("args", null)):
			return false
		if not client.command_transport_key.is_empty():
			if entry.get(client.command_transport_key, null) != client.command_transport_value:
				return false
		return true
	return entry.get(client.entry_url_field, "") == server_url


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










static func _extract_block(text: String) -> Dictionary:



	var lines: = text.split("\n")
	var prefix: PackedStringArray = []
	var entries: Dictionary = {}
	var suffix: PackedStringArray = []
	var header_idx: = -1
	for i in range(lines.size()):
		if lines[i].strip_edges().begins_with("mcp_servers:"):
			header_idx = i
			break
	if header_idx < 0:

		prefix = lines.duplicate()
		return {"prefix_lines": prefix, "entries": entries, "suffix_lines": [], "header_idx": -1}

	for i in range(0, header_idx):
		prefix.append(lines[i])






	var entry_indent: = -1
	var probe: = header_idx + 1
	while probe < lines.size() and _is_blank_or_comment(lines[probe]):
		probe += 1
	if probe < lines.size():
		entry_indent = _indent_of(lines[probe])






	if probe < lines.size() and entry_indent <= _indent_of(lines[header_idx]):
		for j in range(header_idx + 1, lines.size()):
			suffix.append(lines[j])
		return {"prefix_lines": prefix, "entries": entries, "suffix_lines": suffix, "header_idx": header_idx}

	var i: = header_idx + 1
	while i < lines.size():
		var raw: = lines[i]





		if _is_blank_or_comment(raw):
			i += 1
			continue


		if _indent_of(raw) < entry_indent:
			break
		var entry: = _parse_entry(raw, lines, i, entry_indent)
		if not entry["name"].is_empty():
			entries[entry["name"]] = entry["data"]
		i = entry["next_idx"]

	for j in range(i, lines.size()):
		suffix.append(lines[j])

	return {"prefix_lines": prefix, "entries": entries, "suffix_lines": suffix, "header_idx": header_idx}




static func _parse_entry(raw: String, lines: PackedStringArray, start: int, entry_indent: int) -> Dictionary:
	var name: = raw.strip_edges().trim_suffix(":").strip_edges()
	var data: Dictionary = {}
	var i: = start + 1
	while i < lines.size():
		var l: = lines[i]


		if _is_blank_or_comment(l):
			i += 1
			continue

		if _indent_of(l) <= entry_indent:
			break
		var stripped: = l.strip_edges()
		var colon: = stripped.find(":")
		if colon < 0:
			i += 1
			continue
		var key: = stripped.substr(0, colon).strip_edges()
		var val: = stripped.substr(colon + 1).strip_edges()
		if val.is_empty():


			var sub: = _parse_subblock(lines, i + 1, entry_indent)
			data[key] = sub["value"]
			i = sub["next_idx"]
		else:
			data[key] = coerce_scalar(val)
			i += 1
	return {"name": name, "data": data, "next_idx": i}





static func _parse_subblock(lines: PackedStringArray, start: int, entry_indent: int) -> Dictionary:
	var sub: Dictionary = {}
	var i: = start
	while i < lines.size():
		var l: = lines[i]
		if _is_blank_or_comment(l):
			i += 1
			continue

		if _indent_of(l) <= entry_indent:
			break
		var stripped: = l.strip_edges()
		var colon: = stripped.find(":")
		if colon < 0:
			i += 1
			continue
		var key: = stripped.substr(0, colon).strip_edges()
		var val: = stripped.substr(colon + 1).strip_edges()
		if val.is_empty():
			i += 1
			continue
		sub[key] = coerce_scalar(val)
		i += 1
	return {"value": sub, "next_idx": i}




static func _assemble(_text: String, prefix: PackedStringArray, entries: Dictionary, suffix: PackedStringArray) -> String:
	var out: PackedStringArray = []
	for l in prefix:
		out.append(l)

	while out.size() > 0 and out[out.size() - 1].strip_edges().is_empty():
		out.remove_at(out.size() - 1)

	if not _text.contains("mcp_servers:"):

		if out.size() > 0:
			out.append("")
		out.append("mcp_servers:")
		for name in entries:
			out.append_array(_emit_entry(name, entries[name]))
	else:
		out.append("mcp_servers:")
		for name in entries:
			out.append_array(_emit_entry(name, entries[name]))


	for l in suffix:
		out.append(l)
	return "\n".join(out)




static func render_entry_lines(name: String, data: Dictionary) -> PackedStringArray:
	return _emit_entry(name, data)





static func _emit_entry(name: String, data: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append(INDENT + "%s:" % name)
	for key in data:
		var val = data[key]
		if val is Dictionary:
			lines.append(INDENT + INDENT + "%s:" % key)
			for sk in val:
				lines.append(INDENT + INDENT + INDENT + "%s: %s" % [sk, emit_scalar(val[sk])])
		elif val is Array or val is PackedStringArray:
			lines.append(INDENT + INDENT + "%s: %s" % [key, emit_flow_array(_array_copy(val))])
		else:
			lines.append(INDENT + INDENT + "%s: %s" % [key, emit_scalar(val)])
	return lines







static func emit_flow_array(values: Array) -> String:
	var parts: Array[String] = []
	for v in values:
		parts.append(JSON.stringify(str(v)))
	return "[%s]" % ", ".join(parts)


static func emit_scalar(v: Variant) -> String:
	match typeof(v):
		TYPE_BOOL:
			return "true" if bool(v) else "false"
		TYPE_INT:
			return str(int(v))
		TYPE_FLOAT:
			return str(float(v))
		_:
			return emit_string_scalar(str(v))









static func emit_string_scalar(s: String) -> String:
	if s.is_empty():
		return "\"\""
	var needs_quote: = s.begins_with(" ") or s.ends_with(" ")
	if not needs_quote:
		for needle in [": ", " #", "\"", "'", "\n", "\t", "\\", "{", "}", "[", "]", ","]:
			if s.contains(needle):
				needs_quote = true
				break
	if not needs_quote:
		for prefix in ["#", "-", "?", "&", "*", "!", "|", ">", "%", "@", "`"]:
			if s.begins_with(prefix):
				needs_quote = true
				break
	return JSON.stringify(s) if needs_quote else s





static func _is_blank_or_comment(line: String) -> bool:
	var stripped: = line.strip_edges()
	return stripped.is_empty() or stripped.begins_with("#")





static func _indent_of(line: String) -> int:
	var n: = 0
	while n < line.length() and (line[n] == " " or line[n] == "\t"):
		n += 1
	return n











static func coerce_scalar(s: String) -> Variant:
	var t: = s.strip_edges()
	if t.begins_with("[") and t.ends_with("]"):
		var parsed_array: Variant = JSON.parse_string(t)
		if parsed_array is Array:
			return parsed_array
		return t
	if t.begins_with("\"") and t.ends_with("\""):
		var parsed_string: Variant = JSON.parse_string(t)
		if parsed_string is String:
			return parsed_string
		return t.substr(1, t.length() - 2)
	if t.begins_with("'") and t.ends_with("'"):
		return t.substr(1, t.length() - 2)
	if t == "true":
		return true
	if t == "false":
		return false
	if t.is_valid_int():
		return t.to_int()
	if t.is_valid_float():
		return t.to_float()
	return t






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
