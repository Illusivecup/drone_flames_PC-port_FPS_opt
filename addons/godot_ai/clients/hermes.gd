@tool
extends McpClient

func _init() -> void :
	id = "hermes"
	display_name = "Hermes Agent"
	config_type = "yaml"







	path_template = {
		"unix": "~/.hermes/config.yaml", 
		"windows": "$LOCALAPPDATA/hermes/config.yaml"
	}





	server_key_path = PackedStringArray(["mcp_servers"])



	entry_url_field = "url"


	entry_extra_fields = {}
	entry_initial_fields = {}






	command_shape = McpClient.CommandShape.FLAT
	command_legacy_keys = PackedStringArray(["url", "headers"])
	command_user_fields = PackedStringArray(["enabled", "tools", "env"])



	detect_paths = PackedStringArray()
