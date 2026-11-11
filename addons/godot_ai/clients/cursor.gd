@tool
extends McpClient


func _init() -> void :
	id = "cursor"
	display_name = "Cursor"
	config_type = "json"
	path_template = {"unix": "~/.cursor/mcp.json", "windows": "$USERPROFILE/.cursor/mcp.json"}
	server_key_path = PackedStringArray(["mcpServers"])





	command_shape = McpClient.CommandShape.FLAT
	command_transport_key = "type"
	command_transport_value = "stdio"
	command_legacy_keys = PackedStringArray(["url"])
	command_user_fields = PackedStringArray(["env", "envFile"])
