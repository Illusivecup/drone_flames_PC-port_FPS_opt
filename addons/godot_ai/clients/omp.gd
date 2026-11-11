@tool
extends McpClient



















func _init() -> void :
	id = "omp"
	display_name = "Oh My Pi"
	config_type = "json"
	path_template = {
		"unix": "~/.omp/agent/mcp.json", 
		"windows": "$USERPROFILE/.omp/agent/mcp.json", 
	}




	config_merge_path_templates = {
		"unix": PackedStringArray([
			"~/.omp/agent/mcp.json", 
			"~/.omp/agent/.mcp.json", 
		]), 
		"windows": PackedStringArray([
			"$USERPROFILE/.omp/agent/mcp.json", 
			"$USERPROFILE/.omp/agent/.mcp.json", 
		]), 
	}
	config_merge_project_paths = PackedStringArray([".omp/mcp.json", ".omp/.mcp.json"])
	config_merge_first_wins = true
	config_scope_globs = PackedStringArray(["~/.omp/profiles/*"])
	config_scope_envs = PackedStringArray(["PI_CODING_AGENT_DIR", "PI_CONFIG_DIR", "OMP_PROFILE", "PI_PROFILE"])

	config_denylist_key = "disabledServers"
	config_enabled_key = "enabled"
	config_allowlist_key = "enabledServers"
	server_key_path = PackedStringArray(["mcpServers"])
	command_shape = McpClient.CommandShape.FLAT
	command_legacy_keys = PackedStringArray(["url", "headers", "type"])



	command_initial_fields = {"enabled": true, "timeout": 300000}
	command_timeout_fields = PackedStringArray(["timeout"])
	command_user_fields = PackedStringArray(["enabled", "timeout", "env", "cwd"])



	detect_paths = PackedStringArray(["~/.omp/agent"])
