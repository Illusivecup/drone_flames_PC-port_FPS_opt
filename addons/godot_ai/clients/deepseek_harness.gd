@tool
extends McpClient


func _init() -> void :
	id = "deepseek_harness"
	display_name = "DeepSeek Harness"






	config_type = "dsh"


	path_template = {
		"unix": "~/.dsh/cordis.patch.yml", 
		"windows": "~/.dsh/cordis.patch.yml", 
	}




	config_home_env = "DSH_HOME"
	config_home_env_subpath = "cordis.patch.yml"


	detect_paths = PackedStringArray(["~/.dsh"])



	command_shape = McpClient.CommandShape.FLAT
	command_transport_key = "transport"
	command_transport_value = "stdio"
	command_legacy_keys = PackedStringArray(["url"])


	command_user_fields = PackedStringArray([
		"env", "cwd", "toolCallTimeoutMs", "failOnStartupError", "reconnect", 
	])
	command_timeout_fields = PackedStringArray(["toolCallTimeoutMs"])
