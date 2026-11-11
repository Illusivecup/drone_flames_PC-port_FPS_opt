@tool
extends McpClient


func _init() -> void :
	id = "antigravity"
	display_name = "Antigravity"
	config_type = "json"




	path_template = {
		"unix": "~/.gemini/config/mcp_config.json", 
		"windows": "$USERPROFILE/.gemini/config/mcp_config.json", 
	}
	server_key_path = PackedStringArray(["mcpServers"])
	entry_url_field = "serverUrl"


	entry_initial_fields = {"disabled": false}




	command_shape = McpClient.CommandShape.FLAT
	command_legacy_keys = PackedStringArray(["serverUrl"])
	command_initial_fields = {"disabled": false}
	command_user_fields = PackedStringArray(["disabled", "disabledTools", "authProviderType", "env"])




	needs_consoleless_launcher = false
	detect_paths = PackedStringArray(path_template.values() + [
		"~/.gemini/antigravity/mcp_config.json", 
		"$USERPROFILE/.gemini/antigravity/mcp_config.json", 
	])
