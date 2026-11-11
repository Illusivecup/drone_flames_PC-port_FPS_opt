@tool
extends EditorExportPlugin






























const AUTOLOAD_KEY: = "autoload/_mcp_game_helper"

var _saved_value: Variant = null
var _stripped: = false


func _get_name() -> String:
	return "GodotAIStripAutoload"


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void :



	if _stripped:
		return
	if not ProjectSettings.has_setting(AUTOLOAD_KEY):
		return
	_saved_value = ProjectSettings.get_setting(AUTOLOAD_KEY)

	ProjectSettings.set_setting(AUTOLOAD_KEY, null)
	_stripped = true
	print("MCP | export: stripping %s from the exported pack (restored in the editor after export)" % AUTOLOAD_KEY)


func _export_end() -> void :
	if not _stripped:
		return
	ProjectSettings.set_setting(AUTOLOAD_KEY, _saved_value)




	ProjectSettings.set_initial_value(AUTOLOAD_KEY, "")
	ProjectSettings.set_as_basic(AUTOLOAD_KEY, true)
	_saved_value = null
	_stripped = false
