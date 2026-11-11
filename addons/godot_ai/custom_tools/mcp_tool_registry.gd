@tool
class_name McpToolRegistry
extends RefCounted















static var _instance: McpToolRegistry = null


static func get_instance() -> McpToolRegistry:
	return _instance



var _specs: Dictionary = {}
var _by_source_path: Dictionary = {}
var _dispatcher: McpDispatcher = null
var _locator: McpServiceLocator = null
var _ready: bool = false
var _promoted_cnt = 0



signal tools_changed
signal registry_ready




func setup(dispatcher: McpDispatcher, locator: McpServiceLocator) -> void :
	_dispatcher = dispatcher
	_locator = locator
	_load_disabled_tools()
	_instance = self


func register(spec: McpCustomToolSpec) -> bool:
	if not _validate_one(spec):
		return false
	_commit_one(spec)
	tools_changed.emit()
	return true







func batch_register(specs: Array[McpCustomToolSpec]) -> bool:
	if specs.is_empty():
		return true




	var batch_names: = {}
	for spec in specs:
		if not _validate_one(spec):
			return false
		if batch_names.has(spec.name):
			push_warning("McpToolRegistry: duplicate name '%s' within batch — rejected" % spec.name)
			return false
		batch_names[spec.name] = true

	for spec in specs:
		_commit_one(spec)
	tools_changed.emit()
	return true





func _validate_one(spec: McpCustomToolSpec) -> bool:
	var errors: = spec.validate()
	if not errors.is_empty():
		push_error("McpToolRegistry: rejecting spec '%s': %s" % [spec.name, ", ".join(errors)])
		return false

	if spec.source.is_empty():
		spec.source = _read_plugin_name(spec.source_path)

	var existing: McpCustomToolSpec = _specs.get(spec.name)
	if existing != null and existing.source_path != spec.source_path:
		push_warning("McpToolRegistry: name '%s' collision between %s and %s — rejected" % [spec.name, existing.source_path, spec.source_path])
		return false
	return true





func _commit_one(spec: McpCustomToolSpec) -> void :
	var existing: McpCustomToolSpec = _specs.get(spec.name)
	if existing != null:




		_dispatcher.unregister("custom_tool:" + existing.name, "custom:" + existing.name)
		_erase_from_source_path_index_locked(existing)
	_specs[spec.name] = spec
	_by_source_path.get_or_add(spec.source_path, []).append(spec)



	var handler_key: = "custom:" + spec.name
	var wrapper_path: = "res://addons/godot_ai/custom_tools/custom_tool_wrapper.gd"
	_dispatcher.register_lazy_handler(handler_key, wrapper_path, [spec, _locator])
	_dispatcher.register_lazy("custom_tool:" + spec.name, handler_key, &"invoke")


func unregister(name: String) -> bool:
	var spec: McpCustomToolSpec = _specs.get(name)
	if spec == null:
		return false
	if _dispatcher != null:
		_dispatcher.unregister("custom_tool:" + name, "custom:" + name)
	_specs.erase(name)
	_erase_from_source_path_index_locked(spec)
	tools_changed.emit()
	return true




func unregister_source(source_path: String) -> int:
	var specs: Array = _by_source_path.get(source_path, [])
	var count: = specs.size()
	for spec in specs.duplicate():
		if _dispatcher != null:
			_dispatcher.unregister("custom_tool:" + spec.name, "custom:" + spec.name)
		_specs.erase(spec.name)
	_by_source_path.erase(source_path)
	if count > 0:
		tools_changed.emit()
	return count


func all() -> Array[McpCustomToolSpec]:
	var out: Array[McpCustomToolSpec] = []
	for spec in _specs.values():
		out.append(spec)
	return out





func enabled() -> Array[McpCustomToolSpec]:
	var out: Array[McpCustomToolSpec] = []
	for spec in _specs.values():
		if is_tool_enabled(spec.name):
			out.append(spec)
	return out








const _META_SECTION: = "godot_ai"
const _META_KEY_DISABLED: = "disabled_custom_tools"

var _disabled_tools: Dictionary = {}


func is_tool_enabled(name: String) -> bool:
	return not _disabled_tools.has(name)


func set_tool_enabled(name: String, tool_enabled: bool) -> void :
	if tool_enabled:
		if not _disabled_tools.has(name):
			return
		_disabled_tools.erase(name)
	else:
		if _disabled_tools.has(name):
			return
		_disabled_tools[name] = true
	_save_disabled_tools()
	tools_changed.emit()


func _load_disabled_tools() -> void :
	_disabled_tools.clear()
	var es: = _editor_settings()
	if es == null:
		return
	var stored: Variant = es.get_project_metadata(_META_SECTION, _META_KEY_DISABLED, PackedStringArray())
	for name in PackedStringArray(stored):
		_disabled_tools[String(name)] = true


func _save_disabled_tools() -> void :
	var es: = _editor_settings()
	if es == null:
		return
	var names: = PackedStringArray()
	for name in _disabled_tools.keys():
		names.append(String(name))
	es.set_project_metadata(_META_SECTION, _META_KEY_DISABLED, names)


static func _editor_settings() -> EditorSettings:
	if not Engine.is_editor_hint():
		return null
	return EditorInterface.get_editor_settings()


func get_spec(name: String) -> McpCustomToolSpec:
	var out: McpCustomToolSpec = _specs.get(name)
	return out


func is_ready() -> bool:
	return _ready





func clear() -> void :
	_specs.clear()
	_by_source_path.clear()
	_disabled_tools.clear()
	_ready = false
	_dispatcher = null
	_locator = null
	_instance = null





func mark_ready() -> void :
	_ready = true
	registry_ready.emit()




func _erase_from_source_path_index_locked(spec: McpCustomToolSpec) -> void :
	var specs: Array = _by_source_path.get(spec.source_path, [])
	specs.erase(spec)
	if specs.is_empty():
		_by_source_path.erase(spec.source_path)




static func _read_plugin_name(plugin_cfg_path: String) -> String:
	var cfg: = ConfigFile.new()
	if cfg.load(plugin_cfg_path) != OK:
		return ""
	return cfg.get_value("plugin", "name", "")

static func _get_command_name(spec: McpCustomToolSpec) -> String:
	return "custom_tool:" + spec.name

static func _get_handler_name(spec: McpCustomToolSpec) -> String:
	return "custom:" + spec.name
