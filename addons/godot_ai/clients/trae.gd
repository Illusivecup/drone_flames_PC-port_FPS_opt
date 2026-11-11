@tool
extends McpClient


func _init() -> void :
	id = "trae"
	display_name = "Trae"
	config_type = "json"
	path_template = {
		"darwin": "~/Library/Application Support/Trae/User/mcp.json", 
		"windows": "$APPDATA/Trae/User/mcp.json", 
		"linux": "$XDG_CONFIG_HOME/Trae/User/mcp.json", 
	}
	server_key_path = PackedStringArray(["mcpServers"])





	command_shape = McpClient.CommandShape.FLAT
	command_legacy_keys = PackedStringArray(["url", "headers"])
	command_user_fields = PackedStringArray(["env"])
