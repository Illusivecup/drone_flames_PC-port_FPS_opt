@tool
extends McpClient





func _init() -> void :
	id = "vscode"
	display_name = "VS Code"
	config_type = "json"
	path_template = {
		"darwin": "~/Library/Application Support/Code/User/mcp.json", 
		"windows": "$APPDATA/Code/User/mcp.json", 
		"linux": "$XDG_CONFIG_HOME/Code/User/mcp.json", 
	}



	config_path_candidates = {
		"linux": [
			path_template["linux"], 
			"~/.var/app/com.visualstudio.code/config/Code/User/mcp.json", 
		], 
	}
	server_key_path = PackedStringArray(["servers"])
	entry_extra_fields = {"type": "http"}






	command_shape = McpClient.CommandShape.FLAT
	command_transport_key = "type"
	command_transport_value = "stdio"
	command_legacy_keys = PackedStringArray(["url", "headers"])
	command_user_fields = PackedStringArray(["env", "envFile", "cwd", "sandboxEnabled", "dev"])
