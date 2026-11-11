

























extends RefCounted




const _ALLOWED_EVENTS: = [
	"dock_startup", 
	"plugin_reload", 
	"self_update", 
	"dev_server_toggle", 
]





const OPT_OUT_EVENT: = "telemetry_opt_out"

const _MAX_BUFFER: = 32






const PENDING_PLUGIN_RELOAD_KEY: = "godot_ai/pending_plugin_reload_event"






static func record_pending_plugin_reload(source: String) -> void :
	var settings: = EditorInterface.get_editor_settings()
	if settings == null:
		return
	settings.set_setting(
		PENDING_PLUGIN_RELOAD_KEY, 
		JSON.stringify({"source": source, "success": true}), 
	)









static func _drain_editor_setting_dict(key: String):
	var settings: = EditorInterface.get_editor_settings()
	if settings == null:
		return null
	if not settings.has_setting(key):
		return null
	var raw: = str(settings.get_setting(key))
	settings.set_setting(key, "")
	if raw == "":
		return null
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed

var _connection
var _disabled: bool = false
var _pending: Array = []

func _init(connection) -> void :
	_connection = connection
	_disabled = not McpSettings.telemetry_enabled()






	if _connection != null and _connection.has_signal("connection_state_changed"):
		_connection.connection_state_changed.connect(_on_connection_state_changed)


func record_event(name: String, data: Dictionary = {}) -> void :
	if _disabled:
		return
	if not _ALLOWED_EVENTS.has(name):



		return
	if _connection != null and _connection.is_connected:
		_flush()
		_send_one(name, data)
		return








	if _pending.size() >= _MAX_BUFFER:
		_pending.pop_front()
	_pending.append({"name": name, "data": data})


func _on_connection_state_changed(is_open: bool) -> void :
	if is_open:


		assert_opt_out()
		_flush()











func assert_opt_out() -> bool:
	if McpSettings.telemetry_enabled():
		return false
	if _connection == null or not _connection.is_connected:
		return false
	return bool(_connection.send_event(OPT_OUT_EVENT, {}))

func _flush() -> void :
	if _pending.is_empty():
		return
	var to_send: = _pending.duplicate()
	_pending.clear()
	for entry in to_send:
		_send_one(entry["name"], entry["data"])

func _send_one(name: String, data: Dictionary) -> void :
	if _connection == null:
		return
	_connection.send_event("plugin_event", {"name": name, "data": data})



func record_dock_startup(extra: Dictionary = {}) -> void :
	record_event("dock_startup", extra)

func record_self_update(
	status: String, 
	from_version: String = "", 
	to_version: String = "", 
	error: String = "", 
) -> void :
	var data: = {"status": status}
	if from_version != "":
		data["from_version"] = from_version
	if to_version != "":
		data["to_version"] = to_version
	if error != "":
		data["error"] = error.substr(0, 200)
	record_event("self_update", data)

func record_dev_server_toggle(action: String) -> void :
	record_event("dev_server_toggle", {"action": action})









func flush_pending_plugin_reload() -> void :
	var parsed = _drain_editor_setting_dict(PENDING_PLUGIN_RELOAD_KEY)
	if parsed == null:
		return
	var data: = {
		"success": bool(parsed.get("success", true)), 
		"source": str(parsed.get("source", "unknown")), 
	}
	var error: = str(parsed.get("error", ""))
	if error != "":
		data["error"] = error.substr(0, 200)
	record_event("plugin_reload", data)





func _test_set_state(connection, disabled: bool) -> void :
	_connection = connection
	_disabled = disabled
	_pending.clear()

func _test_pending_count() -> int:
	return _pending.size()
