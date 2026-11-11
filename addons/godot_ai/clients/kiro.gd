@tool
extends McpClient


func _init() -> void :
	id = "kiro"
	display_name = "Kiro"
	config_type = "json"
	path_template = {
		"unix": "~/.kiro/settings/mcp.json", 
		"windows": "$USERPROFILE/.kiro/settings/mcp.json", 
	}
	server_key_path = PackedStringArray(["mcpServers"])

	entry_initial_fields = {"disabled": false}



	command_shape = McpClient.CommandShape.FLAT
	command_legacy_keys = PackedStringArray(["url"])
	command_initial_fields = {"disabled": false}
	command_user_fields = PackedStringArray(["disabled", "autoApprove", "disabledTools", "env"])
