@tool
extends McpClient






func _init() -> void :
	id = "claude_desktop"
	display_name = "Claude Desktop"
	config_type = "json"
	path_template = {
		"darwin": "~/Library/Application Support/Claude/claude_desktop_config.json", 
		"windows": "$APPDATA/Claude/claude_desktop_config.json", 
		"linux": "$XDG_CONFIG_HOME/Claude/claude_desktop_config.json", 
	}







	config_path_candidates = {
		"windows": [
			"$LOCALAPPDATA/Packages/Claude_*/LocalCache/Roaming/Claude/claude_desktop_config.json", 
			"$APPDATA/Claude/claude_desktop_config.json", 
		], 
	}
	detect_paths = PackedStringArray([
		"$LOCALAPPDATA/Packages/Claude_*", 
	])
	server_key_path = PackedStringArray(["mcpServers"])
	command_shape = McpClient.CommandShape.FLAT
	command_legacy_keys = PackedStringArray(["url"])
	command_env_legacy_keys = PackedStringArray(["UV_LINK_MODE"])
	command_user_fields = PackedStringArray(["env", "disabled"])
