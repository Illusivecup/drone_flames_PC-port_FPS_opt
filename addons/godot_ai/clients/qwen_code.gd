@tool
extends McpClient


func _init() -> void :
	id = "qwen_code"
	display_name = "Qwen Code"
	config_type = "json"
	path_template = {
		"unix": "~/.qwen/settings.json", 
		"windows": "$USERPROFILE/.qwen/settings.json", 
	}
	server_key_path = PackedStringArray(["mcpServers"])
	entry_url_field = "httpUrl"




	command_shape = McpClient.CommandShape.FLAT
	command_legacy_keys = PackedStringArray(["httpUrl", "url"])
	command_user_fields = PackedStringArray([
		"timeout", "trust", "includeTools", "excludeTools", "env", "cwd", 
		"discoveryTimeoutMs", 
	])
	command_timeout_fields = PackedStringArray(["timeout", "discoveryTimeoutMs"])
