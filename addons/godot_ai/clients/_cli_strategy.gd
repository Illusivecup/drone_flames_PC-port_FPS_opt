@tool
class_name McpCliStrategy
extends RefCounted















const SCOPE_TOKEN: = "{scope}"

const _CONFIGURE_TIMEOUT_MS: = 10000
const _REMOVE_TIMEOUT_MS: = 10000
const _STATUS_TIMEOUT_MS: = 6000
const MutationLock: = preload("res://addons/godot_ai/utils/client_mutation_lock.gd")


static func configure(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	launch: Dictionary = {}, 
) -> Dictionary:
	var write_error: = configure_write_error(client)
	if not write_error.is_empty():
		return {"status": "error", "message": write_error}



	var launch_error: = command_launch_error(client, launch)
	if not launch_error.is_empty():
		return {"status": "error", "message": launch_error}
	var cli: = _resolve_cli(client)
	if cli.is_empty():
		return {"status": "error", "message": "%s not found" % client.display_name}
	return _configure_claimed(client, server_name, server_url, launch, cli)


static func _configure_claimed(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	launch: Dictionary, 
	cli: String, 
) -> Dictionary:




	if not client.cli_unregister_template.is_empty():







		for pre_scope in _cleanup_scopes(client):
			var pre_args: = _format_args(
				client.cli_unregister_template, server_name, server_url, {}, pre_scope
			)
			var cleaned: = McpCliExec.run(cli, pre_args, _REMOVE_TIMEOUT_MS)
			var cleanup_failure: = _unproven_mutation_failure(
				client, "Prior cleanup", cleaned
			)
			if not cleanup_failure.is_empty():
				return cleanup_failure

	if client.cli_register_template.is_empty():
		return {"status": "error", "message": "%s descriptor missing cli_register_template" % client.display_name}
	var args: = _format_args(client.cli_register_template, server_name, server_url, launch)
	var result: = McpCliExec.run(cli, args, _CONFIGURE_TIMEOUT_MS)
	var termination_failure: = _unproven_mutation_failure(client, "Configure", result)
	if not termination_failure.is_empty():
		return termination_failure
	if result.get("timed_out", false):
		return {
			"status": "error", 
			"message": "Configure %s timed out after %ds — see 'Run this manually' below to retry by hand" % [
				client.display_name, _CONFIGURE_TIMEOUT_MS / 1000, 
			], 
		}
	if result.get("spawn_failed", false):
		return {"status": "error", "message": "Failed to spawn %s" % client.display_name}
	if int(result.get("exit_code", -1)) == 0:
		return {"status": "ok", "message": McpClient.configured_message(client, server_url)}



	var combined: = str(result.get("output", "")).strip_edges()
	var err: = combined if not combined.is_empty() else "exit code %d" % int(result.get("exit_code", -1))
	return {"status": "error", "message": "Failed to configure %s: %s" % [client.display_name, err]}












static func check_status(
	client: McpClient, server_name: String, server_url: String, launch: Dictionary = {}
) -> McpClient.Status:
	return check_status_with_cli_path(client, server_name, server_url, _resolve_cli(client), launch)


static func check_status_with_cli_path(
	client: McpClient, server_name: String, server_url: String, cli: String, launch: Dictionary = {}
) -> McpClient.Status:
	return check_status_details(client, server_name, server_url, cli, launch).get("status", McpClient.Status.NOT_CONFIGURED)







static func check_status_details(
	client: McpClient, server_name: String, server_url: String, cli: String, launch: Dictionary = {}
) -> Dictionary:
	if cli.is_empty():
		return _status_details(McpClient.Status.NOT_CONFIGURED)
	if client.cli_status_args.is_empty():
		return _status_details(McpClient.Status.NOT_CONFIGURED)
	var expected_target: = server_url
	if client.command_shape != McpClient.CommandShape.NONE:



		var launch_error: = command_launch_error(client, launch)
		if not launch_error.is_empty():
			return _status_details(McpClient.Status.ERROR, launch_error)
		expected_target = str(launch.get("command", ""))
	var result: = McpCliExec.run(
		cli, 
		McpClient._array_from_packed(client.cli_status_args), 
		_STATUS_TIMEOUT_MS, 
		false
	)
	if result.get("timed_out", false):
		return _status_details(McpClient.Status.ERROR, "probe timed out")
	if result.get("spawn_failed", false):
		return _status_details(McpClient.Status.NOT_CONFIGURED)
	if int(result.get("exit_code", -1)) != 0:
		return _status_details(McpClient.Status.NOT_CONFIGURED)
	var text: = str(result.get("stdout", ""))
	if text.find(server_name) < 0:
		return _status_details(McpClient.Status.NOT_CONFIGURED)


	if text.find(expected_target) < 0:
		return _status_details(
			McpClient.Status.CONFIGURED_MISMATCH, "", _probe_output_launches_godot_ai(text)
		)
	return _status_details(McpClient.Status.CONFIGURED)






static func command_launch_error(client: McpClient, launch: Dictionary) -> String:
	if client.command_shape == McpClient.CommandShape.NONE:
		return ""
	if not bool(launch.get("ok", false)):
		return str(launch.get("error", "No compatible attach launcher was found."))
	return ""


static func _status_details(
	status: McpClient.Status, error_msg: String = "", owned: bool = false
) -> Dictionary:
	return {"status": status, "error_msg": error_msg, "owned": owned}


static func remove(client: McpClient, server_name: String) -> Dictionary:
	var write_error: = remove_write_error(client)
	if not write_error.is_empty():
		return {"status": "error", "message": write_error}
	var cli: = _resolve_cli(client)
	if cli.is_empty():
		return {"status": "error", "message": "%s not found" % client.display_name}
	return _remove_claimed(client, server_name, cli)


static func _remove_claimed(client: McpClient, server_name: String, cli: String) -> Dictionary:
	if client.cli_unregister_template.is_empty():
		return {"status": "error", "message": "%s descriptor missing cli_unregister_template" % client.display_name}
	var args: = _format_args(client.cli_unregister_template, server_name, "")
	var result: = McpCliExec.run(cli, args, _REMOVE_TIMEOUT_MS)
	var termination_failure: = _unproven_mutation_failure(client, "Remove", result)
	if not termination_failure.is_empty():
		return termination_failure
	if result.get("timed_out", false):
		return {
			"status": "error", 
			"message": "Remove %s timed out after %ds — see 'Run this manually' below to retry by hand" % [
				client.display_name, _REMOVE_TIMEOUT_MS / 1000, 
			], 
		}
	if result.get("spawn_failed", false):
		return {"status": "error", "message": "Failed to spawn %s" % client.display_name}
	if int(result.get("exit_code", -1)) == 0:
		return {"status": "ok", "message": "%s configuration removed" % client.display_name}



	var combined: = str(result.get("output", "")).strip_edges()
	var err: = combined if not combined.is_empty() else "exit code %d" % int(result.get("exit_code", -1))
	return {"status": "error", "message": "Failed to remove %s: %s" % [client.display_name, err]}






static func _unproven_mutation_failure(
	client: McpClient, operation: String, result: Dictionary
) -> Dictionary:
	if not bool(result.get("termination_failed", false)):
		return {}
	return {
		"status": "error", 
		"message": (
			"%s for %s could not be proven stopped. %s"
			%[operation, client.display_name, MutationLock.recovery_message()]
		), 
		"termination_failed": true, 
	}















static func format_args(
	template: PackedStringArray, 
	server_name: String, 
	server_url: String, 
	launch: Dictionary = {}, 
	scope_override: String = "", 
) -> Array[String]:
	return _format_args(template, server_name, server_url, launch, scope_override)


static func _format_args(
	template: PackedStringArray, 
	server_name: String, 
	server_url: String, 
	launch: Dictionary = {}, 
	scope_override: String = "", 
) -> Array[String]:
	var scope: = scope_override if not scope_override.is_empty() else McpSettings.client_scope()
	var out: Array[String] = []
	for arg in template:
		var s: = String(arg)
		if s == "{command}":
			out.append(str(launch.get("command", "")))
			continue
		if s == "{args...}":
			for launch_arg in launch.get("args", []):
				out.append(str(launch_arg))
			continue
		s = s.replace("{name}", server_name)
		s = s.replace("{url}", server_url)



		s = s.replace(SCOPE_TOKEN, scope)
		out.append(s)
	return out








static func check_scope_status_details(
	client: McpClient, 
	server_name: String, 
	server_url: String, 
	cli: String, 
	launch: Dictionary, 
	expected_scope: String, 
) -> Dictionary:
	if cli.is_empty() or client.cli_scope_status_template.is_empty():
		return _status_details(McpClient.Status.NOT_CONFIGURED)
	var expected_target: = server_url
	var expected_args: Array[String] = []
	var expected_type: = ""
	if client.command_shape != McpClient.CommandShape.NONE:

		var launch_error: = command_launch_error(client, launch)
		if not launch_error.is_empty():
			return _status_details(McpClient.Status.ERROR, launch_error)
		expected_target = str(launch.get("command", ""))
		for launch_arg in launch.get("args", []):
			expected_args.append(str(launch_arg))
		expected_type = str(client.command_transport_value)
	var args: = _format_args(client.cli_scope_status_template, server_name, server_url)
	var result: = McpCliExec.run(cli, args, _STATUS_TIMEOUT_MS, false)
	if result.get("timed_out", false):
		return _status_details(McpClient.Status.ERROR, "probe timed out")
	if result.get("spawn_failed", false):
		return _status_details(McpClient.Status.NOT_CONFIGURED)
	return _scope_probe_verdict(
		int(result.get("exit_code", -1)), 
		str(result.get("stdout", "")), 
		expected_scope, 
		expected_target, 
		expected_args, 
		expected_type, 
	)






static func _scope_from_probe_output(text: String) -> String:
	for raw_line in text.split("\n"):
		var line: = String(raw_line).strip_edges()
		var marker: = line.find("Scope:")
		if marker < 0:
			continue
		var rest: = line.substr(marker + 6).strip_edges().to_lower()
		for scope in McpSettings.CLIENT_SCOPES:
			var name: = String(scope)
			if rest.begins_with(name):
				return name
	return ""




static func _probe_output_launches_godot_ai(text: String) -> bool:
	return McpClient.launch_mentions_godot_ai(
		_field_from_probe_output(text, "Command:")
		+ " "
		+ _field_from_probe_output(text, "Args:")
		+ " "
		+ _field_from_probe_output(text, "URL:")
	)


static func _field_from_probe_output(text: String, label: String) -> String:
	for raw_line in text.split("\n"):
		var line: = String(raw_line).strip_edges()
		if line.begins_with(label):
			return line.substr(label.length()).strip_edges()
	return ""


















static func _scope_probe_verdict(
	exit_code: int, 
	text: String, 
	expected_scope: String, 
	expected_target: String, 
	expected_args: Array[String] = [], 
	expected_type: String = "", 
) -> Dictionary:
	if exit_code != 0:
		return _status_details(McpClient.Status.NOT_CONFIGURED)






	var resolved: = _scope_from_probe_output(text)
	var command_matches: = (
		expected_target.is_empty()
		or _field_from_probe_output(text, "Command:") == expected_target
	)
	var launch_details_match: = true
	if not expected_type.is_empty():
		launch_details_match = (
			_field_from_probe_output(text, "Type:") == expected_type
			and _field_from_probe_output(text, "Args:") == " ".join(expected_args)
		)
	if not command_matches or not launch_details_match:
		var drifted: = _status_details(
			McpClient.Status.CONFIGURED_MISMATCH, "", _probe_output_launches_godot_ai(text)
		)
		if not resolved.is_empty():
			drifted["resolved_scope"] = resolved
		return drifted
	if resolved.is_empty():
		return _status_details(McpClient.Status.CONFIGURED)
	if resolved != expected_scope:
		var details: = _status_details(
			McpClient.Status.CONFIGURED_MISMATCH, 
			"registered at %s scope, not %s" % [resolved, expected_scope], 
			_probe_output_launches_godot_ai(text), 
		)
		details["resolved_scope"] = resolved
		return details
	return _status_details(McpClient.Status.CONFIGURED)






static func uses_scope_token(client: McpClient) -> bool:
	return client.cli_register_template.has(SCOPE_TOKEN)











static func configure_write_error(client: McpClient) -> String:
	if not client.has_json_fallback():
		return ""
	return client.config_write_error()






static func remove_write_error(client: McpClient) -> String:
	if not client.has_json_fallback():
		return ""
	if uses_scope_token(client) and McpSettings.client_scope() == "project":
		return ""
	return client.config_write_error()




static func cleanup_scopes(client: McpClient) -> Array[String]:
	return _cleanup_scopes(client)





static func _cleanup_scopes(client: McpClient) -> Array[String]:
	if not uses_scope_token(client):
		return [""]
	var scopes: Array[String] = []
	for scope in McpSettings.CLIENT_SCOPES:
		scopes.append(String(scope))
	return scopes


static func _resolve_cli(client: McpClient) -> String:
	return McpCliFinder.find(McpClient._array_from_packed(client.cli_names))


static func resolve_cli_path(client: McpClient) -> String:
	return _resolve_cli(client)
