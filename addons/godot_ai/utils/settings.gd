@tool
class_name McpSettings
extends RefCounted








const SETTING_HTTP_PORT: = "godot_ai/http_port"

const SETTING_EXCLUDED_DOMAINS: = "godot_ai/excluded_domains"
const SETTING_TELEMETRY_ENABLED: = "godot_ai/telemetry_enabled"


const SETTING_ALLOW_HOSTS: = "godot_ai/allow_remote_hosts"


const SETTING_MCP_LOGGING: = "godot_ai/mcp_logging"






const SETTING_CLIENT_SCOPE: = "godot_ai/mcp_client_scope"




const CLIENT_SCOPES: = ["user", "project", "local"]
const DEFAULT_CLIENT_SCOPE: = "user"




static func truthy(value: String) -> bool:
	return value.strip_edges().to_lower() in ["1", "true", "yes", "on"]



static func env_truthy(var_name: String) -> bool:
	return truthy(OS.get_environment(var_name))















static var _client_scope_snapshot: Variant = null
static var _client_scope_mutex: = Mutex.new()


static func _client_scope_setting() -> Variant:
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		var live: Variant = null
		if Engine.is_editor_hint():
			var es: = EditorInterface.get_editor_settings()
			if es != null and es.has_setting(SETTING_CLIENT_SCOPE):
				live = es.get_setting(SETTING_CLIENT_SCOPE)
		_client_scope_mutex.lock()
		_client_scope_snapshot = live
		_client_scope_mutex.unlock()
		return live
	_client_scope_mutex.lock()
	var cached: Variant = _client_scope_snapshot
	_client_scope_mutex.unlock()
	return cached





static func warm_client_scope() -> void :
	_client_scope_setting()








static func client_scope() -> String:
	var value: Variant = _client_scope_setting()


	if value == null:
		return DEFAULT_CLIENT_SCOPE
	var raw: = String(value).strip_edges().to_lower()
	if raw in CLIENT_SCOPES:
		return raw
	return DEFAULT_CLIENT_SCOPE






static func telemetry_enabled() -> bool:
	if env_truthy("GODOT_AI_DISABLE_TELEMETRY") or env_truthy("DISABLE_TELEMETRY"):
		return false
	var es: = EditorInterface.get_editor_settings()
	if es != null and es.has_setting(SETTING_TELEMETRY_ENABLED):
		return bool(es.get_setting(SETTING_TELEMETRY_ENABLED))
	return true






static func mcp_logging_enabled() -> bool:
	var es: = EditorInterface.get_editor_settings()
	if es != null and es.has_setting(SETTING_MCP_LOGGING):
		return bool(es.get_setting(SETTING_MCP_LOGGING))
	return true



static func set_mcp_logging_enabled(enabled: bool) -> void :
	var es: = EditorInterface.get_editor_settings()
	if es != null:
		es.set_setting(SETTING_MCP_LOGGING, enabled)
