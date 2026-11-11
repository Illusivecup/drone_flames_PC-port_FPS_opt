@tool
extends McpClient





func _init() -> void :
	id = "zed"
	display_name = "Zed"
	config_type = "json"



	automatic_config_edits = false


	config_allows_comments = true
	path_template = {
		"darwin": "~/.config/zed/settings.json", 
		"linux": "$XDG_CONFIG_HOME/zed/settings.json", 
		"windows": "$APPDATA/Zed/settings.json", 
	}




	config_path_candidates = {
		"linux": [
			path_template["linux"], 
			"~/.var/app/dev.zed.Zed/config/zed/settings.json", 
		], 
	}
	server_key_path = PackedStringArray(["context_servers"])







	command_shape = McpClient.CommandShape.FLAT
	command_legacy_keys = PackedStringArray(["url", "headers", "oauth"])
	command_user_fields = PackedStringArray(["enabled", "remote", "timeout", "env"])
	command_timeout_fields = PackedStringArray(["timeout"])
