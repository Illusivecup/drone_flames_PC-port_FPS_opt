@tool
class_name McpManualCommand
extends RefCounted

const SHELL_POSIX: = "posix"
const SHELL_POWERSHELL: = "powershell"



const _SHELL_BARE_SAFE_CHARS: = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_+=:./-"







static func build(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	resolved_path: String, 
	launch: Dictionary = {}, 
	project_roots: PackedStringArray = PackedStringArray(), 
) -> String:
	if client.command_shape == McpClient.CommandShape.NONE:
		return "%s has no authenticated v4 configuration path; do not persist the backend URL." % client.display_name
	match client.config_type:
		"cli":
			return _build_cli(client, server_name, server_url, resolved_path, launch, project_roots)
		"json":
			return _build_json(client, server_name, server_url, resolved_path, launch, project_roots)
		"toml":
			return _build_toml(client, server_name, server_url, resolved_path, launch)
		"yaml":
			return _build_yaml(client, server_name, server_url, resolved_path, launch)
		"dsh":
			return _build_dsh(client, server_name, server_url, resolved_path, launch)
	return ""








static func _build_cli(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	resolved_path: String = "", 
	launch: Dictionary = {}, 
	project_roots: PackedStringArray = PackedStringArray(), 
) -> String:
	if client.cli_register_template.is_empty() or client.cli_names.is_empty():
		return ""
	var shell_kind: = _shell_kind_for_platform()
	var short_name: String = String(client.cli_names[0])

	for n in client.cli_names:
		if not String(n).ends_with(".exe"):
			short_name = String(n)
			break
	var cmd: = ""
	if client.command_shape != McpClient.CommandShape.NONE:
		var launch_error: = McpCliStrategy.command_launch_error(client, launch)
		if not launch_error.is_empty():
			cmd = "Attach launch command unavailable: %s" % launch_error
		else:
			var args: = McpCliStrategy.format_args(client.cli_register_template, server_name, server_url, launch)
			var parts: Array[String] = [short_name]
			for arg in args:
				parts.append(String(arg))
			var lines: = _sweep_lines(client, server_name, server_url, short_name, shell_kind)
			lines.append(_render_command_line(parts, shell_kind))
			cmd = _format_shell_block(lines, shell_kind) + _sweep_caveat(client)
	else:
		var args: = McpCliStrategy.format_args(client.cli_register_template, server_name, server_url)
		var parts: Array[String] = [short_name]
		for arg in args:
			parts.append(String(arg))
		var lines: = _sweep_lines(client, server_name, server_url, short_name, shell_kind)
		lines.append(_render_command_line(parts, shell_kind))
		cmd = _format_shell_block(lines, shell_kind) + _sweep_caveat(client)




	if client.has_json_fallback() and not resolved_path.is_empty():
		return "%s\n\nNo `%s` CLI (e.g. installed as a VS Code/Cursor extension)? %s" % [
			cmd, short_name, _build_json(client, server_name, server_url, resolved_path, launch, project_roots), 
		]
	return cmd









static func _sweep_lines(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	short_name: String, 
	shell_kind: String, 
) -> Array[String]:
	var lines: Array[String] = []
	if client.cli_unregister_template.is_empty():
		return lines
	for pre_scope in McpCliStrategy.cleanup_scopes(client):
		var args: = McpCliStrategy.format_args(
			client.cli_unregister_template, server_name, server_url, {}, pre_scope
		)
		var parts: Array[String] = [short_name]
		for arg in args:
			parts.append(String(arg))
		lines.append(_render_command_line(parts, shell_kind))
	return lines








static func _sweep_caveat(client: McpClient) -> String:
	if client.cli_unregister_template.is_empty() or not McpCliStrategy.uses_scope_token(client):
		return ""
	return (
		"\n\nThe project-scope remove rewrites the .mcp.json in the directory the"
		+ " editor was launched from — not necessarily this project — so it drops a"
		+ " hand-maintained godot-ai entry there. Other servers in that file are left"
		+ " alone."
	)


static func _shell_kind_for_platform() -> String:
	return SHELL_POWERSHELL if OS.get_name() == "Windows" else SHELL_POSIX





static func _format_shell_command(parts: Array[String], shell_kind: String) -> String:
	return _format_shell_block([_render_command_line(parts, shell_kind)], shell_kind)





static func _format_shell_block(lines: Array[String], shell_kind: String) -> String:
	var label: = "Run in PowerShell:" if shell_kind == SHELL_POWERSHELL else "Run in a POSIX shell:"
	return "%s\n%s" % [label, "\n".join(lines)]


static func _render_command_line(parts: Array[String], shell_kind: String) -> String:
	var rendered: Array[String] = []
	for part in parts:
		rendered.append(_shell_display_arg(part, shell_kind))
	return " ".join(rendered)






static func _shell_display_arg(arg: String, shell_kind: String) -> String:
	if arg.is_empty():
		return "''"
	var stays_bare: = true
	for index in range(arg.length()):
		if _SHELL_BARE_SAFE_CHARS.find(arg.substr(index, 1)) < 0:
			stays_bare = false
			break
	if stays_bare:
		return arg
	if shell_kind == SHELL_POWERSHELL:
		return "'%s'" % arg.replace("'", "''")
	return "'%s'" % arg.replace("'", "'\"'\"'")


static func _build_json(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	resolved_path: String, 
	launch: Dictionary = {}, 
	project_roots: PackedStringArray = PackedStringArray(), 
) -> String:
	var target: = McpJsonStrategy.manual_target_details(client, server_name, resolved_path, project_roots)
	var target_note: = ""
	if not target.get("ok", false):
		target_note = "Target inspection failed: %s" % str(target.get("error", "cannot inspect config"))
		target = {"path": resolved_path, "key_path": client.server_key_path}
	var target_path: = str(target.get("path", resolved_path))
	var key_path: PackedStringArray = target.get("key_path", client.server_key_path)



	var key: = ".".join(key_path) if key_path.size() > 0 else "mcpServers"
	if client.command_shape != McpClient.CommandShape.NONE:
		var lines: Array[String] = []
		var launch_error: = McpJsonStrategy.command_launch_error(client, launch)
		if launch_error.is_empty():
			var command_entry: = McpJsonStrategy.build_entry(client, server_url, null, launch)
			lines.append("Edit %s and add under \"%s\":" % [target_path, key])
			lines.append("  \"%s\": %s" % [server_name, _format_entry_inline(command_entry)])
		else:
			lines.append("Attach launch command unavailable: %s" % launch_error)
		if not target_note.is_empty():
			lines.append("")
			lines.append(target_note)
		return "\n".join(lines)
	var entry: = McpJsonStrategy.build_entry(client, server_url)
	var instructions: = "Edit %s and add under \"%s\":\n  \"%s\": %s" % [target_path, key, server_name, _format_entry_inline(entry)]
	if not target_note.is_empty():
		instructions += "\n\n" + target_note
	return instructions


static func _build_toml(
	client: McpClient, 
	_server_name: String, 
	server_url: String, 
	resolved_path: String, 
	launch: Dictionary = {}, 
) -> String:
	var header: = _toml_header(client)
	if client.command_shape != McpClient.CommandShape.NONE:
		var lines: Array[String] = []
		var rendered: = McpTomlStrategy.render_body(client, server_url, launch)
		if bool(rendered.get("ok", false)):
			lines.append("Edit %s and add:" % resolved_path)
			lines.append("  %s" % header)
			for body_line in rendered.get("lines", []):
				lines.append("  %s" % str(body_line))
		else:
			lines.append("Attach launch command unavailable: %s" % str(rendered.get("error", "no compatible launcher found")))
		return "\n".join(lines)
	var body: = McpTomlStrategy.format_body(client.toml_body_template, server_url)
	var lines: Array[String] = ["Edit %s and add:" % resolved_path, "  %s" % header]
	for b in body:
		lines.append("  %s" % String(b))
	return "\n".join(lines)


static func _build_yaml(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	resolved_path: String, 
	launch: Dictionary = {}, 
) -> String:
	var key: = client.server_key_path[0] if client.server_key_path.size() > 0 else "mcp_servers"
	if client.command_shape != McpClient.CommandShape.NONE:
		var lines: Array[String] = []
		var launch_error: = McpYamlStrategy.command_launch_error(client, launch)
		if launch_error.is_empty():
			var command_entry: = McpYamlStrategy.build_entry(client, server_url, null, launch)
			lines.append("Edit %s and add under '%s':" % [resolved_path, key])
			for entry_line in McpYamlStrategy.render_entry_lines(server_name, command_entry):
				lines.append(String(entry_line))
		else:
			lines.append("Attach launch command unavailable: %s" % launch_error)
		return "\n".join(lines)
	var entry: = McpYamlStrategy.build_entry(client, server_url)
	var lines: Array[String] = [
		"Edit %s and add under '%s':" % [resolved_path, key], 
		"  %s:" % server_name, 
	]
	for k in entry:
		lines.append("    %s: %s" % [k, str(entry[k])])
	return "\n".join(lines)






static func _build_dsh(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	resolved_path: String, 
	launch: Dictionary = {}, 
) -> String:
	var lines: Array[String] = ["Edit %s and add this loader entry (an `insert` row; a plain `- id:` row only overrides an existing bundle id and would be skipped):" % resolved_path]
	var entry_id_value: = McpDshStrategy.entry_id(server_name)
	if client.command_shape != McpClient.CommandShape.NONE:
		var launch_error: = McpDshStrategy.command_launch_error(client, launch)
		if launch_error.is_empty():
			var command_entry: = McpDshStrategy.build_entry(client, server_name, server_url, null, launch)
			for row_line in McpDshStrategy.render_insert_row(entry_id_value, command_entry):
				lines.append(String(row_line))
		else:
			lines.append("Attach launch command unavailable: %s" % launch_error)
		return "\n".join(lines)
	var url_entry: = McpDshStrategy.build_url_entry(client, server_name, server_url)
	for row_line in McpDshStrategy.render_insert_row(entry_id_value, url_entry):
		lines.append(String(row_line))
	return "\n".join(lines)




static func _toml_header(client: McpClient) -> String:
	var parts: = client.toml_section_path
	if parts.size() < 2:
		return "[%s]" % ".".join(parts)
	var section: = ".".join(McpClient._array_from_packed(McpClient._packed_slice(parts, 0, parts.size() - 1)))
	var name: = parts[parts.size() - 1]
	return "[%s.\"%s\"]" % [section, name]











static func _format_entry_inline(entry: Dictionary) -> String:
	var parts: Array[String] = []
	for k in entry:
		parts.append("%s: %s" % [JSON.stringify(String(k)), _format_value(entry[k])])
	if parts.is_empty():
		return "{}"
	return "{ %s }" % ", ".join(parts)


static func _format_value(value: Variant) -> String:





	if value is Array:
		var arr_parts: Array[String] = []
		for v in value:
			arr_parts.append(_format_value(v))
		return "[%s]" % ", ".join(arr_parts)
	if value is Dictionary:
		var d_parts: Array[String] = []
		for k in value:
			d_parts.append("%s: %s" % [JSON.stringify(String(k)), _format_value(value[k])])
		if d_parts.is_empty():
			return "{}"
		return "{ %s }" % ", ".join(d_parts)
	return JSON.stringify(value)
