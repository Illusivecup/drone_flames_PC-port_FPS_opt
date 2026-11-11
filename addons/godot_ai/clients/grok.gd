@tool
extends McpClient


func _init() -> void :
	id = "grok"
	display_name = "Grok Build"
	config_type = "toml"


	path_template = {
		"unix": "~/.grok/config.toml", 
		"windows": "$USERPROFILE/.grok/config.toml", 
	}
	toml_section_path = PackedStringArray(["mcp_servers", "godot-ai"])

	toml_legacy_section_aliases = PackedStringArray(["mcp_servers.godot_ai"])









	command_shape = McpClient.CommandShape.COMMAND_ARRAY
	command_legacy_keys = PackedStringArray(["url", "headers"])
	command_initial_fields = {"startup_timeout_sec": 60}
	command_user_fields = PackedStringArray([
		"env", "enabled", "startup_timeout_sec", "tool_timeout_sec", 
	])
	command_timeout_fields = PackedStringArray(["startup_timeout_sec", "tool_timeout_sec"])
	detect_paths = PackedStringArray(path_template.values())
