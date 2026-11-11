@tool
extends McpClient



















func _init() -> void :
	id = "zcode"
	display_name = "ZCode"
	config_type = "json"

	automatic_config_edits = false
	path_template = {
		"unix": "~/.zcode/cli/config.json", 
		"windows": "$USERPROFILE/.zcode/cli/config.json", 
	}
	server_key_path = PackedStringArray(["mcp", "servers"])
	command_shape = McpClient.CommandShape.FLAT
	command_transport_key = "type"
	command_transport_value = "stdio"
	command_legacy_keys = PackedStringArray(["url", "headers"])
	command_user_fields = PackedStringArray(["env", "enable"])


	detect_paths = PackedStringArray(["~/.zcode"])
