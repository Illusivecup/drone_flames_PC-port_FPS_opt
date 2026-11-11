@tool
extends McpClient


func _init() -> void :
	id = "roo_code"
	display_name = "Roo Code"
	config_type = "json"
	path_template = {
		"darwin": "~/Library/Application Support/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json", 
		"windows": "$APPDATA/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json", 
		"linux": "$XDG_CONFIG_HOME/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json", 
	}


	config_path_candidates = {
		"linux": [
			path_template["linux"], 
			"~/.var/app/com.visualstudio.code/config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json", 
		], 
	}
	server_key_path = PackedStringArray(["mcpServers"])






	entry_extra_fields = {"type": "streamable-http"}





	entry_initial_fields = {"disabled": false, "alwaysAllow": []}




	command_shape = McpClient.CommandShape.FLAT
	command_transport_key = "type"
	command_transport_value = "stdio"
	command_legacy_keys = PackedStringArray(["url", "headers"])
	command_initial_fields = {"disabled": false, "alwaysAllow": []}
	command_user_fields = PackedStringArray([
		"disabled", "alwaysAllow", "timeout", "disabledTools", "watchPaths", 
		"env", "cwd", 
	])
	command_timeout_fields = PackedStringArray(["timeout"])
