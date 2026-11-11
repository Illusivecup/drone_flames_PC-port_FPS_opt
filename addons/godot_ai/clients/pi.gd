@tool
extends McpClient


func _init() -> void :
	id = "pi"
	display_name = "Pi Agent"
	config_type = "json"






	path_template = {
		"unix": "~/.pi/agent/mcp.json", 
		"windows": "$USERPROFILE/.pi/agent/mcp.json", 
	}



	config_merge_path_templates = {
		"unix": PackedStringArray([
			"~/.pi/agent/mcp.json", 
			"~/.pi/agent/.mcp.json", 
		]), 
		"windows": PackedStringArray([
			"$USERPROFILE/.pi/agent/mcp.json", 
			"$USERPROFILE/.pi/agent/.mcp.json", 
		]), 
	}
	config_merge_project_paths = PackedStringArray([".pi/mcp.json", ".mcp.json"])
	server_key_path = PackedStringArray(["mcpServers"])



	var aliases: Array[PackedStringArray] = [
		PackedStringArray(["mcp-servers"]), 
		PackedStringArray(["servers"]), 
	]
	server_key_path_aliases = aliases
	entry_url_field = "url"


	entry_extra_fields = {}
	entry_initial_fields = {}



	command_shape = McpClient.CommandShape.FLAT
	command_legacy_keys = PackedStringArray(["url", "headers", "type"])


	command_user_fields = PackedStringArray(["env"])






	detect_paths = PackedStringArray(path_template.values())
