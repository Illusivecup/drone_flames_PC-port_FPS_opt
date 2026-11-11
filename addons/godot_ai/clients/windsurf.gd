@tool
extends McpClient


func _init() -> void :







	id = "windsurf"
	display_name = "Devin Desktop (Windsurf)"
	config_type = "json"
	path_template = {
		"unix": "~/.codeium/windsurf/mcp_config.json", 
		"windows": "$USERPROFILE/.codeium/windsurf/mcp_config.json", 
	}
	server_key_path = PackedStringArray(["mcpServers"])
	entry_url_field = "serverUrl"




	command_shape = McpClient.CommandShape.FLAT
	command_legacy_keys = PackedStringArray(["serverUrl"])
	command_user_fields = PackedStringArray(["env"])
