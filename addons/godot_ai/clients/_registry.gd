@tool
class_name McpClientRegistry
extends RefCounted











const _CLIENT_SCRIPT_PATHS: = [
	"res://addons/godot_ai/clients/claude_code.gd", 
	"res://addons/godot_ai/clients/claude_desktop.gd", 
	"res://addons/godot_ai/clients/codex.gd", 
	"res://addons/godot_ai/clients/codebuddy.gd", 
	"res://addons/godot_ai/clients/grok.gd", 
	"res://addons/godot_ai/clients/antigravity.gd", 
	"res://addons/godot_ai/clients/cursor.gd", 
	"res://addons/godot_ai/clients/windsurf.gd", 
	"res://addons/godot_ai/clients/vscode.gd", 
	"res://addons/godot_ai/clients/vscode_insiders.gd", 
	"res://addons/godot_ai/clients/zed.gd", 
	"res://addons/godot_ai/clients/gemini_cli.gd", 
	"res://addons/godot_ai/clients/cline.gd", 
	"res://addons/godot_ai/clients/kilo_code.gd", 
	"res://addons/godot_ai/clients/roo_code.gd", 
	"res://addons/godot_ai/clients/zoo_code.gd", 
	"res://addons/godot_ai/clients/kiro.gd", 
	"res://addons/godot_ai/clients/trae.gd", 
	"res://addons/godot_ai/clients/opencode.gd", 
	"res://addons/godot_ai/clients/qwen_code.gd", 
	"res://addons/godot_ai/clients/kimi_code.gd", 
	"res://addons/godot_ai/clients/hermes.gd", 
	"res://addons/godot_ai/clients/pi.gd", 
	"res://addons/godot_ai/clients/deepseek_harness.gd", 
	"res://addons/godot_ai/clients/zcode.gd", 
	"res://addons/godot_ai/clients/omp.gd", 
]

static var _instances: Array[McpClient] = []
static var _by_id: Dictionary = {}




static var _load_mutex: = Mutex.new()






static var _stale_session: = false

const RESTART_TO_FINISH_UPDATE: = (
	"Godot AI was updated in this editor session. Restart the editor to finish the update."
)


static func all() -> Array[McpClient]:
	_ensure_loaded()
	return _instances


static func get_by_id(id: String) -> McpClient:
	_ensure_loaded()
	return _by_id.get(id, null)


static func ids() -> PackedStringArray:
	var out: = PackedStringArray()
	for c in all():
		out.append(c.id)
	return out


static func has_id(id: String) -> bool:
	_ensure_loaded()
	return _by_id.has(id)





static func stale_session_detected() -> bool:
	_ensure_loaded()
	return _stale_session








static func _instance_is_coherent(inst: Object) -> bool:
	if inst == null:
		return false
	return (
		inst.get("config_path_candidates") is Dictionary
		and inst.get("config_file_env") is String
		and inst.get("path_template") is Dictionary
		and inst.get("server_key_path_aliases") is Array
		and inst.get("config_merge_path_templates") is Dictionary
		and inst.get("config_merge_project_paths") is PackedStringArray
	)


static func _cache_is_coherent() -> bool:
	return not _instances.is_empty() and _instance_is_coherent(_instances[0])


static func _ensure_loaded() -> void :
	if _stale_session:
		return
	if _cache_is_coherent():
		return
	_load_mutex.lock()


	if not _stale_session and not _cache_is_coherent():





		_load()
		if not _instances.is_empty() and not _cache_is_coherent():
			_stale_session = true
			push_warning("MCP | %s" % RESTART_TO_FINISH_UPDATE)
	_load_mutex.unlock()


static func _load() -> void :


	var instances: Array[McpClient] = []
	var by_id: Dictionary = {}
	for path in _CLIENT_SCRIPT_PATHS:
		var script: = load(path) as GDScript
		if script == null:
			push_warning("MCP | failed to load client descriptor %s" % path)
			continue
		var inst: McpClient = script.new()
		if inst.id.is_empty():
			push_warning("MCP | client descriptor %s has empty id" % path)
			continue
		if by_id.has(inst.id):
			push_warning("MCP | duplicate client id: %s" % inst.id)
			continue
		instances.append(inst)
		by_id[inst.id] = inst
	_by_id = by_id
	_instances = instances
