@tool
extends McpClient





func _init() -> void :
	id = "opencode"
	display_name = "OpenCode"
	config_type = "json"






	path_template = {
		"unix": "~/.config/opencode/opencode.json", 
		"windows": "$HOME/.config/opencode/opencode.json", 
	}
	config_file_env = "OPENCODE_CONFIG"






	config_merge_path_templates = {
		"unix": PackedStringArray([
			"~/.config/opencode/opencode.json", 
			"~/.config/opencode/opencode.jsonc", 
		]), 
		"windows": PackedStringArray([
			"$HOME/.config/opencode/opencode.json", 
			"$HOME/.config/opencode/opencode.jsonc", 
		]), 
	}
	server_key_path = PackedStringArray(["mcp"])
	entry_extra_fields = {"type": "remote"}

	entry_initial_fields = {"enabled": true}





	command_shape = McpClient.CommandShape.COMMAND_ARRAY
	command_transport_key = "type"
	command_transport_value = "local"
	command_legacy_keys = PackedStringArray(["url", "headers"])
	command_initial_fields = {"enabled": true}
	command_user_fields = PackedStringArray(["enabled", "timeout", "environment", "cwd"])
	command_timeout_fields = PackedStringArray(["timeout"])
