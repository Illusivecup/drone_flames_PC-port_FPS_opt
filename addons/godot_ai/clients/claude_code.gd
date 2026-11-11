@tool
extends McpClient


func _init() -> void :
	id = "claude_code"
	display_name = "Claude Code"
	config_type = "cli"
	cli_names = PackedStringArray(["claude", "claude.exe"] if OS.get_name() == "Windows" else ["claude"])







	cli_register_template = PackedStringArray(
		["mcp", "add", "--scope", "{scope}", "{name}", "--", "{command}", "{args...}"]
	)







	cli_unregister_template = PackedStringArray(["mcp", "remove", "--scope", "{scope}", "{name}"])








	cli_status_args = PackedStringArray(["mcp", "list"])










	cli_scope_status_template = PackedStringArray(["mcp", "get", "{name}"])














	path_template = {"unix": "~/.claude.json", "windows": "~/.claude.json"}
	server_key_path = PackedStringArray(["mcpServers"])

	entry_extra_fields = {"type": "http"}
	command_shape = McpClient.CommandShape.FLAT
	command_transport_key = "type"
	command_transport_value = "stdio"



	command_legacy_keys = PackedStringArray(["url"])
	command_user_fields = PackedStringArray(["env"])






	config_home_env = "CLAUDE_CONFIG_DIR"
	config_home_env_subpath = ".claude.json"
