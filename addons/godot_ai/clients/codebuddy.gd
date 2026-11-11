@tool
extends McpClient









func _init() -> void :
	id = "codebuddy"
	display_name = "CodeBuddy"
	config_type = "json"
	path_template = {
		"unix": "~/.codebuddy/mcp.json", 
		"windows": "$USERPROFILE/.codebuddy/mcp.json", 
	}
	server_key_path = PackedStringArray(["mcpServers"])
	command_shape = McpClient.CommandShape.FLAT
	command_transport_key = "type"
	command_transport_value = "stdio"
	command_legacy_keys = PackedStringArray(["url", "headers"])
	command_user_fields = PackedStringArray(["env", "description"])
