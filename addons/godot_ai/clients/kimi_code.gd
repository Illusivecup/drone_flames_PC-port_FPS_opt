@tool
extends McpClient


func _init() -> void :
	id = "kimi_code"
	display_name = "Kimi Code"





	config_type = "json"
	path_template = {"unix": "~/.kimi-code/mcp.json", "windows": "~/.kimi-code/mcp.json"}
	server_key_path = PackedStringArray(["mcpServers"])
	entry_extra_fields = {"transport": "http"}



	config_home_env = "KIMI_CODE_HOME"
	config_home_env_subpath = "mcp.json"





	command_shape = McpClient.CommandShape.FLAT
	command_legacy_keys = PackedStringArray(["url", "transport"])
	command_user_fields = PackedStringArray([
		"enabled", "startupTimeoutMs", "toolTimeoutMs", "enabledTools", 
		"disabledTools", "env", "cwd", 
	])
	command_timeout_fields = PackedStringArray(["startupTimeoutMs", "toolTimeoutMs"])
