@tool
class_name McpClientConfigurator
extends RefCounted















const Client: = preload("res://addons/godot_ai/clients/_base.gd")
const ClientRegistry: = preload("res://addons/godot_ai/clients/_registry.gd")
const JsonStrategy: = preload("res://addons/godot_ai/clients/_json_strategy.gd")
const TomlStrategy: = preload("res://addons/godot_ai/clients/_toml_strategy.gd")
const YamlStrategy: = preload("res://addons/godot_ai/clients/_yaml_strategy.gd")
const DshStrategy: = preload("res://addons/godot_ai/clients/_dsh_strategy.gd")
const CliStrategy: = preload("res://addons/godot_ai/clients/_cli_strategy.gd")
const ManualCommand: = preload("res://addons/godot_ai/clients/_manual_command.gd")
const CliFinder: = preload("res://addons/godot_ai/clients/_cli_finder.gd")
const MutationLock: = preload("res://addons/godot_ai/utils/client_mutation_lock.gd")
const WindowsPortReservation: = preload("res://addons/godot_ai/utils/windows_port_reservation.gd")
const PortResolver: = preload("res://addons/godot_ai/utils/port_resolver.gd")
const UvResolution: = preload("res://addons/godot_ai/utils/uv_resolution_policy.gd")

const SERVER_NAME: = "godot-ai"






const DEFAULT_HTTP_PORT: = 8000
const DEFAULT_WS_PORT: = 9500
const STARTUP_TRACE_ENV: = "GODOT_AI_STARTUP_TRACE"
const MIN_PORT: = 1024
const MAX_PORT: = 65535




const SUGGEST_PORT_MAX_PROBES: = 64
const SETTING_WS_PORT: = "godot_ai/ws_port"
const SETTING_V4_ENDPOINT_PORTS: = "godot_ai/v4_endpoint_ports"
const SETTING_STARTUP_TRACE: = "godot_ai/log_startup_timing"
const SETTING_KEEP_SERVER_ON_EXIT: = "godot_ai/keep_server_on_exit"





const SETTING_EXTERNAL_CLIENT_CWD: = "godot_ai/external_client_cwd"
const _DISCOVERY_TIMEOUT_MS: = 3000











const _WINDOWS_STDIO_BOOTSTRAP: = (
	"import subprocess,sys; "
	+ "raise SystemExit(subprocess.call(sys.argv[1:], stdin=sys.stdin, stdout=sys.stdout, "
	+ "stderr=sys.stderr, creationflags=0x08000000))"
)



static func http_port() -> int:
	var override: = v4_endpoint_ports_status()
	if bool(override.present):
		return int(override.get("http_port", 0))
	return _read_port_setting(McpSettings.SETTING_HTTP_PORT, DEFAULT_HTTP_PORT)



static func ws_port() -> int:
	var override: = v4_endpoint_ports_status()
	if bool(override.present):
		return int(override.get("ws_port", 0))
	return _read_port_setting(SETTING_WS_PORT, DEFAULT_WS_PORT)




static func v4_endpoint_ports_status() -> Dictionary:
	var es: = EditorInterface.get_editor_settings()
	if es == null or not es.has_setting(SETTING_V4_ENDPOINT_PORTS):
		return {"ok": true, "present": false}
	var pair: Variant = es.get_setting(SETTING_V4_ENDPOINT_PORTS)
	var invalid: = {"ok": false, "present": true, 
		"error": "Invalid %s: set distinct integer http_port and ws_port values between %d and %d, or remove the override." % [SETTING_V4_ENDPOINT_PORTS, MIN_PORT, MAX_PORT]}
	if not (pair is Dictionary) or pair.size() != 2:
		return invalid
	for key in ["http_port", "ws_port"]:
		var value: Variant = pair.get(key)
		if not (value is int or value is float) or not is_finite(float(value)):
			return invalid
		if float(value) < MIN_PORT or float(value) > MAX_PORT or float(value) != float(int(value)):
			return invalid
	if int(pair.http_port) == int(pair.ws_port):
		return invalid
	return {"ok": true, "present": true, "http_port": int(pair.http_port), "ws_port": int(pair.ws_port)}




static func prepare_major_upgrade_endpoints(from_version: String, to_version: String) -> Dictionary:
	var previous: = McpServerVersionCheck.version_tuple(from_version)
	var installed: = McpServerVersionCheck.version_tuple(to_version)
	if previous.is_empty() or installed.is_empty() or int(previous[0]) >= 4 or int(installed[0]) < 4:
		return {"ok": true, "changed": false}
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "error": "upgrade endpoint selection requires the main thread"}
	var existing: = v4_endpoint_ports_status()
	if not bool(existing.ok) or bool(existing.present):
		existing["changed"] = false
		return existing
	var es: = EditorInterface.get_editor_settings()
	if es == null:
		return {"ok": false, "error": "EditorSettings is unavailable"}
	var legacy_http: = _read_port_setting(McpSettings.SETTING_HTTP_PORT, DEFAULT_HTTP_PORT)
	var legacy_ws: = _read_port_setting(SETTING_WS_PORT, DEFAULT_WS_PORT)
	var occupancy: = PortResolver.windows_listener_snapshot() if OS.get_name() == "Windows" else {}
	if OS.get_name() == "Windows" and not occupancy.known:
		return {"ok": false, "error": "Windows could not query listening ports; retry endpoint selection."}
	var selected: Array[int] = []
	var candidate: = legacy_http + 1 if legacy_http < MAX_PORT else MIN_PORT
	candidate = WindowsPortReservation.suggest_non_excluded_port(candidate, MAX_PORT - candidate + 1, MAX_PORT)
	var reserved_output: = str(WindowsPortReservation._get_cached_excluded_output().get("text", ""))
	for _probe in range(SUGGEST_PORT_MAX_PROBES):
		candidate = WindowsPortReservation.suggest_non_excluded_port_from_output(reserved_output, candidate, MAX_PORT - candidate + 1, MAX_PORT)
		if candidate < MIN_PORT or candidate > MAX_PORT:
			break
		if candidate not in [legacy_http, legacy_ws] and not selected.has(candidate) and PortResolver.can_bind_local_port(candidate):
			var available: bool
			if OS.get_name() == "Windows":
				available = PortResolver.windows_port_occupancy(candidate, occupancy) == PortResolver.PortOccupancy.FREE
			else:
				available = not PortResolver.is_port_in_use(candidate)
			if available:
				selected.append(candidate)
				if selected.size() == 2:
					break
		candidate += 1
		if candidate > MAX_PORT:
			candidate = MIN_PORT
	if selected.size() != 2:
		return {"ok": false, "error": "No independent HTTP/WebSocket port pair was available for this major upgrade."}
	if OS.get_name() == "Windows":
		occupancy = PortResolver.windows_listener_snapshot()
		if not occupancy.known:
			return {"ok": false, "error": "Windows could not query listening ports; retry endpoint selection."}
	for port in selected:
		var available: bool
		if OS.get_name() == "Windows":
			available = PortResolver.windows_port_occupancy(port, occupancy) == PortResolver.PortOccupancy.FREE
		else:
			available = not PortResolver.is_port_in_use(port)
		if WindowsPortReservation.parse_excluded(reserved_output, port) or not PortResolver.can_bind_local_port(port) or not available:
			return {"ok": false, "error": "The selected upgrade port %d became unavailable; retry endpoint selection." % port}
	var pair: = {"http_port": selected[0], "ws_port": selected[1]}
	es.set_setting(SETTING_V4_ENDPOINT_PORTS, pair)
	return {"ok": true, "changed": true, "http_port": selected[0], "ws_port": selected[1]}


static func http_url() -> String:
	return "http://127.0.0.1:%d/mcp" % http_port()




static func server_url_from(launch_context: Dictionary) -> String:
	if launch_context.has("server_url"):
		return str(launch_context["server_url"])
	return http_url()


static func _read_port_setting(key: String, default_port: int) -> int:
	var es: = EditorInterface.get_editor_settings()
	if es == null or not es.has_setting(key):
		return default_port
	var value: int = int(es.get_setting(key))
	if value < MIN_PORT or value > MAX_PORT:
		return default_port
	return value







static func ensure_settings_registered() -> void :
	var es: = EditorInterface.get_editor_settings()
	if es == null:
		return
	_register_port_setting(es, McpSettings.SETTING_HTTP_PORT, DEFAULT_HTTP_PORT)
	_register_port_setting(es, SETTING_WS_PORT, DEFAULT_WS_PORT)
	_register_bool_setting(es, SETTING_STARTUP_TRACE, false)
	_register_bool_setting(es, SETTING_KEEP_SERVER_ON_EXIT, false)
	_register_string_setting(es, McpSettings.SETTING_EXCLUDED_DOMAINS, "")
	_register_bool_setting(es, McpSettings.SETTING_TELEMETRY_ENABLED, true)
	_register_string_setting(es, McpSettings.SETTING_ALLOW_HOSTS, "")
	_register_client_scope_setting(es)
	_register_string_setting(es, SETTING_EXTERNAL_CLIENT_CWD, "")


static func _register_port_setting(es: EditorSettings, key: String, default_port: int) -> void :
	if not es.has_setting(key):
		es.set_setting(key, default_port)
	es.set_initial_value(key, default_port, false)
	es.add_property_info({
		"name": key, 
		"type": TYPE_INT, 
		"hint": PROPERTY_HINT_RANGE, 
		"hint_string": "%d,%d,1" % [MIN_PORT, MAX_PORT], 
	})





static func _register_client_scope_setting(es: EditorSettings) -> void :
	var key: = McpSettings.SETTING_CLIENT_SCOPE
	if not es.has_setting(key):
		es.set_setting(key, McpSettings.DEFAULT_CLIENT_SCOPE)
	es.set_initial_value(key, McpSettings.DEFAULT_CLIENT_SCOPE, false)
	es.add_property_info({
		"name": key, 
		"type": TYPE_STRING, 
		"hint": PROPERTY_HINT_ENUM, 
		"hint_string": ",".join(PackedStringArray(McpSettings.CLIENT_SCOPES)), 
	})


static func _register_bool_setting(es: EditorSettings, key: String, default_value: bool) -> void :
	if not es.has_setting(key):
		es.set_setting(key, default_value)
	es.set_initial_value(key, default_value, false)
	es.add_property_info({
		"name": key, 
		"type": TYPE_BOOL, 
	})


static func _register_string_setting(es: EditorSettings, key: String, default_value: String) -> void :



	if not es.has_setting(key):
		es.set_setting(key, default_value)
	es.set_initial_value(key, default_value, false)
	es.add_property_info({
		"name": key, 
		"type": TYPE_STRING, 
		"hint": PROPERTY_HINT_NONE, 
		"hint_string": "", 
	})


static func startup_trace_enabled() -> bool:


	var raw: = McpPathTemplate.env_lookup(STARTUP_TRACE_ENV).strip_edges().to_lower()
	if raw == "1" or raw == "true" or raw == "yes" or raw == "on":
		return true
	var setting: Variant = _editor_setting_lookup(SETTING_STARTUP_TRACE)
	if setting != null:
		return bool(setting)
	return false










static func keep_server_on_exit() -> bool:
	var setting: Variant = _editor_setting_lookup(SETTING_KEEP_SERVER_ON_EXIT)
	if setting != null:
		return bool(setting)
	return false










static var _setting_snapshot: = {}
static var _setting_snapshot_mutex: = Mutex.new()



static var _launch_context_snapshot: = {}
static var _endpoint_policy_snapshot: = {}
static var _launch_context_snapshot_mutex: = Mutex.new()


static func _editor_setting_lookup(key: String) -> Variant:
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		var live: Variant = null
		if Engine.is_editor_hint():
			var es: = EditorInterface.get_editor_settings()
			if es != null and es.has_setting(key):
				live = es.get_setting(key)
		_setting_snapshot_mutex.lock()
		_setting_snapshot[key] = live
		_setting_snapshot_mutex.unlock()
		return live
	_setting_snapshot_mutex.lock()
	var cached: Variant = _setting_snapshot.get(key, null)
	_setting_snapshot_mutex.unlock()
	return cached













static func excluded_domains() -> String:
	var es: = EditorInterface.get_editor_settings()
	if es == null or not es.has_setting(McpSettings.SETTING_EXCLUDED_DOMAINS):
		return ""
	return _canonicalize_excluded_domains(str(es.get_setting(McpSettings.SETTING_EXCLUDED_DOMAINS)))





static func _canonicalize_excluded_domains(raw: String) -> String:
	var parts: = PackedStringArray()
	for p in raw.split(","):
		var t: = p.strip_edges()
		if t.is_empty() or parts.find(t) != -1:
			continue
		if not McpToolCatalog.is_excludable_domain(t):
			continue
		parts.append(t)
	parts.sort()
	return ",".join(parts)





static func capture_endpoint_policy(resolved_ws_port: int = -1) -> Dictionary:
	var selected_ws_port: = ws_port() if resolved_ws_port <= 0 else resolved_ws_port
	return {
		"http_port": http_port(), 
		"ws_port": selected_ws_port, 
		"excluded_domains": excluded_domains(), 
		"allow_hosts": allow_hosts(), 
		"keep_alive": keep_server_on_exit(), 
		"telemetry_enabled": McpSettings.telemetry_enabled(), 
	}






static func capture_launch_context(endpoint_policy: Dictionary = {}) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		_launch_context_snapshot_mutex.lock()
		var cached: = _launch_context_snapshot.duplicate(true)
		_launch_context_snapshot_mutex.unlock()
		return cached
	var policy: = endpoint_policy.duplicate(true)
	if policy.is_empty():
		_launch_context_snapshot_mutex.lock()
		policy = _endpoint_policy_snapshot.duplicate(true)
		_launch_context_snapshot_mutex.unlock()
	if policy.is_empty():


		policy = capture_endpoint_policy()
	var captured_http_port: = int(policy.get("http_port", DEFAULT_HTTP_PORT))
	var context: = {
		"http_port": captured_http_port, 
		"ws_port": int(policy.get("ws_port", DEFAULT_WS_PORT)), 
		"excluded_domains": str(policy.get("excluded_domains", "")), 
		"plugin_version": get_plugin_version(), 
		"allow_dev_venv": mode_override() != "user", 
		"platform": OS.get_name(), 
		"server_url": "http://127.0.0.1:%d/mcp" % captured_http_port, 
		"project_roots": capture_project_roots(), 



		"telemetry_enabled": bool(policy.get("telemetry_enabled", true)), 
	}
	_launch_context_snapshot_mutex.lock()
	_endpoint_policy_snapshot = policy.duplicate(true)
	_launch_context_snapshot = context.duplicate(true)
	_launch_context_snapshot_mutex.unlock()
	return context





static func apply_endpoint_settings(changes: Dictionary) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "error": "settings writes require the main thread"}
	var normalized: = {}
	for key in changes:
		var value: Variant = changes[key]
		match str(key):
			"http_port":
				if not (value is int or value is float):
					return {"ok": false, "error": "HTTP port must be an integer"}
				var port: = int(value)
				if float(value) != float(port) or port < MIN_PORT or port > MAX_PORT:
					return {"ok": false, "error": "HTTP port is outside the supported range"}
				normalized[McpSettings.SETTING_HTTP_PORT] = port
			"ws_port":
				if not (value is int or value is float):
					return {"ok": false, "error": "WebSocket port must be an integer"}
				var ws_port_value: = int(value)
				if (
					float(value) != float(ws_port_value)
					or ws_port_value < MIN_PORT
					or ws_port_value > MAX_PORT
				):
					return {"ok": false, "error": "WebSocket port is outside the supported range"}
				normalized[SETTING_WS_PORT] = ws_port_value
			"excluded_domains":
				if not (value is String):
					return {"ok": false, "error": "excluded domains must be text"}
				normalized[McpSettings.SETTING_EXCLUDED_DOMAINS] = _canonicalize_excluded_domains(value)
			"telemetry_enabled":
				if not (value is bool):
					return {"ok": false, "error": "telemetry preference must be boolean"}
				normalized[McpSettings.SETTING_TELEMETRY_ENABLED] = value
			"allow_hosts":
				if not (value is String):
					return {"ok": false, "error": "allow-host policy must be text"}
				var allowed: = McpAllowHosts.normalize(value)
				if not McpAllowHosts.invalid_tokens(allowed).is_empty():
					return {"ok": false, "error": "allow-host policy is invalid"}
				normalized[McpSettings.SETTING_ALLOW_HOSTS] = allowed
			_:
				return {"ok": false, "error": "unknown endpoint setting: %s" % key}
	var next_http: = int(normalized.get(McpSettings.SETTING_HTTP_PORT, http_port()))
	var next_ws: = int(normalized.get(SETTING_WS_PORT, ws_port()))
	var override: = v4_endpoint_ports_status()
	var ports_changed: = normalized.has(McpSettings.SETTING_HTTP_PORT) or normalized.has(SETTING_WS_PORT)
	if bool(override.present) and ports_changed:
		if next_http < MIN_PORT or next_http > MAX_PORT or next_ws < MIN_PORT or next_ws > MAX_PORT:
			return {"ok": false, "error": "A complete valid HTTP/WebSocket pair is required to repair the v4 override."}
		normalized.erase(McpSettings.SETTING_HTTP_PORT)
		normalized.erase(SETTING_WS_PORT)
		normalized[SETTING_V4_ENDPOINT_PORTS] = {"http_port": next_http, "ws_port": next_ws}
	if next_http == next_ws and (ports_changed or not bool(override.present)):
		return {"ok": false, "error": "HTTP and WebSocket ports must differ"}
	var es: = EditorInterface.get_editor_settings()
	if es == null:
		return {"ok": false, "error": "EditorSettings is unavailable"}
	for key in normalized:
		es.set_setting(key, normalized[key])
	return {"ok": true, "changes": normalized.duplicate(true)}




static func capture_project_roots() -> PackedStringArray:
	var current_access: = DirAccess.open(".")
	var current_root: = "" if current_access == null else current_access.get_current_dir().simplify_path()
	var project_root: = ProjectSettings.globalize_path("res://").simplify_path()





	var external_cwd: = str(_editor_setting_lookup(SETTING_EXTERNAL_CLIENT_CWD))
	return _canonicalize_roots_for_test(PackedStringArray([current_root, project_root, external_cwd]))












static func _canonicalize_roots_for_test(raws: PackedStringArray) -> PackedStringArray:
	var seen: = {}
	var roots: = PackedStringArray()
	for raw in raws:
		var s: = str(raw).strip_edges()
		if s.is_empty():
			continue
		var canon: = ProjectSettings.globalize_path(s).simplify_path()
		if canon.is_empty() or seen.has(canon):
			continue
		seen[canon] = true
		roots.append(canon)
	return roots


static func _project_roots_from_context(context: Dictionary) -> PackedStringArray:
	var roots = context.get("project_roots", PackedStringArray())
	return roots if roots is PackedStringArray else PackedStringArray()








static func allow_hosts() -> String:
	var es: = EditorInterface.get_editor_settings()
	if es == null or not es.has_setting(McpSettings.SETTING_ALLOW_HOSTS):
		return ""
	return McpAllowHosts.normalize(str(es.get_setting(McpSettings.SETTING_ALLOW_HOSTS)))















static func suggest_free_port(start: int, span: int = 2048, occupancy: Dictionary = {}) -> int:
	if OS.get_name() == "Windows":
		if occupancy.is_empty():
			occupancy = PortResolver.windows_listener_snapshot()
		if not occupancy.known:
			return 0
	var candidate: = clampi(start, MIN_PORT, MAX_PORT - span + 1)
	var limit: = mini(candidate + span - 1, MAX_PORT)
	var p: = candidate
	var probes: = 0
	while p <= limit and probes < SUGGEST_PORT_MAX_PROBES:




		var not_reserved: = WindowsPortReservation.suggest_non_excluded_port(p, limit - p + 1, MAX_PORT)
		if not_reserved < p or not_reserved > limit:
			break
		p = not_reserved
		probes += 1
		var occupied: = OS.get_name() == "Windows" and PortResolver.windows_port_occupancy(p, occupancy) != PortResolver.PortOccupancy.FREE
		if not occupied and PortResolver.can_bind_local_port(p):
			return p
		p += 1
	return 0




static func client_ids() -> PackedStringArray:
	return ClientRegistry.ids()


static func has_client(id: String) -> bool:
	return ClientRegistry.has_id(id)


static func client_display_name(id: String) -> String:
	var c: = ClientRegistry.get_by_id(id)
	return c.display_name if c != null else id






static func configure(id: String, url: String = "", launch_context: Dictionary = {}) -> Dictionary:
	if ClientRegistry.stale_session_detected():
		return {"status": "error", "message": ClientRegistry.RESTART_TO_FINISH_UPDATE}
	var client: = ClientRegistry.get_by_id(id)
	if client == null:
		return {"status": "error", "message": "Unknown client: %s" % id}
	if not client.automatic_config_edits:
		return _manual_edit_result(client, "configure")
	var path_error: = _config_path_resolution_error(client)
	if path_error.is_empty():
		path_error = _config_write_error(client, "configure")
	if path_error.is_empty():
		path_error = _config_create_error(client)
	if path_error.is_empty():
		path_error = _credentials_error(client)
	if not path_error.is_empty():
		return {"status": "error", "message": path_error}



	if url.is_empty():
		url = http_url()
	var context: = launch_context
	if client.command_shape != Client.CommandShape.NONE and context.is_empty():
		if OS.get_thread_caller_id() != OS.get_main_thread_id():
			return {
				"status": "error", 
				"message": "Cannot configure %s without a main-thread launch snapshot; retry from the dock." % client.display_name, 
			}
		context = capture_launch_context()
	var launch: = (
		resolve_attach_launch(context)
		if client.command_shape != Client.CommandShape.NONE
		else {}
	)
	var claim: = MutationLock.acquire(client.id, "configure")
	if not bool(claim.get("ok", false)):
		return {
			"status": "error", 
			"message": str(claim.get("error", MutationLock.recovery_message())), 
		}
	var result: = _dispatch_configure(client, url, launch, context)





	var verified: = _verify_post_state(
		client, result, Client.Status.CONFIGURED, url, "configure", launch, context
	)
	return _finish_client_mutation(claim, verified)


static func check_status(id: String) -> Client.Status:
	if ClientRegistry.stale_session_detected():
		return Client.Status.ERROR
	var client: = ClientRegistry.get_by_id(id)
	if client == null:
		return Client.Status.NOT_CONFIGURED
	var context: = capture_launch_context() if client.command_shape != Client.CommandShape.NONE else {}
	return _dispatch_check_status(client, http_url(), context)


static func check_status_for_url_with_cli_path(
	id: String, url: String, cli_path: String, launch_context: Dictionary = {}
) -> Client.Status:
	return check_status_details_for_url_with_cli_path(id, url, cli_path, launch_context).get("status", Client.Status.NOT_CONFIGURED)
















static func entry_drift_is_version_pin_only(
	id: String, from_version: String, launch_context: Dictionary = {}
) -> bool:
	var pinned_from: = from_version.strip_edges()
	if pinned_from.is_empty():
		return false









	var client: = ClientRegistry.get_by_id(id)
	if client == null:
		return false
	if client.config_type == "cli":
		if client.command_shape == Client.CommandShape.NONE:
			return false
		if not client.has_json_fallback():
			return false
		if _scope_diverges_from_json_fallback(client):
			return false
	var context: = launch_context if not launch_context.is_empty() else capture_launch_context()
	var old_context: = context.duplicate(true)
	old_context["plugin_version"] = pinned_from



	var url: = str(context.get("server_url", http_url()))
	var status: = check_status_for_url_with_cli_path(id, url, "", old_context)
	return status == Client.Status.CONFIGURED







static func check_status_details_for_url_with_cli_path(
	id: String, 
	url: String, 
	cli_path: String, 
	launch_context: Dictionary = {}, 
	resolved_launch: Dictionary = {}, 
) -> Dictionary:


	if ClientRegistry.stale_session_detected():
		return {"status": Client.Status.ERROR, "error_msg": ClientRegistry.RESTART_TO_FINISH_UPDATE}
	var client: = ClientRegistry.get_by_id(id)
	if client == null:
		return {"status": Client.Status.NOT_CONFIGURED, "error_msg": ""}




	if client.config_type == "cli" and cli_path.is_empty() and not client.has_json_fallback():
		return {"status": Client.Status.NOT_CONFIGURED, "error_msg": ""}
	var path_error: = _config_path_resolution_error(client)
	if not path_error.is_empty():
		return {"status": Client.Status.ERROR, "error_msg": path_error}
	if client.command_shape != Client.CommandShape.NONE and launch_context.is_empty():
		return {
			"status": Client.Status.ERROR, 
			"error_msg": "Missing launch-context snapshot; retry the status refresh.", 
		}
	return _dispatch_check_status_with_cli_path_details(
		client, url, cli_path, launch_context, resolved_launch
	)










static func warm_env_snapshot(endpoint_policy: Dictionary = {}) -> void :
	var extras: = PackedStringArray()
	for id in client_ids():
		var client: = ClientRegistry.get_by_id(String(id))
		if client == null:
			continue



		for env_name in [client.get("config_file_env"), client.get("config_home_env")]:
			if env_name is String and not env_name.is_empty() and not extras.has(env_name):
				extras.append(env_name)
		var scope_envs: Variant = client.get("config_scope_envs")
		if scope_envs is PackedStringArray:
			for env_name in scope_envs:
				if not env_name.is_empty() and not extras.has(env_name):
					extras.append(env_name)
	McpPathTemplate.warm_env_snapshot(extras)
	UvResolution.warm_environment()
	_editor_setting_lookup(MODE_OVERRIDE_SETTING)
	_editor_setting_lookup(SETTING_STARTUP_TRACE)
	_editor_setting_lookup(SETTING_KEEP_SERVER_ON_EXIT)
	_editor_setting_lookup(SETTING_EXTERNAL_CLIENT_CWD)
	McpSettings.warm_client_scope()


	capture_launch_context(endpoint_policy)


static func client_status_probe_snapshot(id: String) -> Dictionary:
	var client: = ClientRegistry.get_by_id(id)
	if client == null:
		return {}
	var cli_path: = ""
	var installed: = false
	if client.config_type == "cli":
		cli_path = CliStrategy.resolve_cli_path(client)


		installed = not cli_path.is_empty() or client.is_installed()
	else:
		installed = client.is_installed()
	return {
		"id": id, 
		"cli_path": cli_path, 
		"installed": installed, 
		"automatic_config_edits": client.automatic_config_edits, 
	}




static func client_status_response(results: Dictionary) -> Dictionary:
	var clients: = []
	for client_id in client_ids():
		var details: Dictionary = results.get(client_id, {
			"status": Client.Status.ERROR, 
			"installed": false, 
			"error_msg": "Client status probe returned no result.", 
		})
		clients.append(_client_status_sweep_entry(
			client_id, details, bool(details.get("installed", false))
		))
	return {"data": {"clients": clients}}


static func _client_status_sweep_entry(
	client_id: String, details: Dictionary, installed: bool
) -> Dictionary:
	var status = details.get("status", Client.Status.NOT_CONFIGURED)
	var entry: = {
		"id": client_id, 
		"display_name": client_display_name(client_id), 
		"status": Client.status_label(status), 
		"installed": installed, 
	}
	var error_msg: = str(details.get("error_msg", ""))
	if not error_msg.is_empty():
		entry["error"] = error_msg
	return entry





static func remove(id: String, url: String = "", launch_context: Dictionary = {}) -> Dictionary:
	if ClientRegistry.stale_session_detected():
		return {"status": "error", "message": ClientRegistry.RESTART_TO_FINISH_UPDATE}
	var client: = ClientRegistry.get_by_id(id)
	if client == null:
		return {"status": "error", "message": "Unknown client: %s" % id}
	if not client.automatic_config_edits:
		return _manual_edit_result(client, "remove")
	var path_error: = _config_path_resolution_error(client)
	if path_error.is_empty():
		path_error = _config_write_error(client, "remove")
	if not path_error.is_empty():
		return {"status": "error", "message": path_error}
	if url.is_empty():
		url = http_url()
	var context: = launch_context
	if client.command_shape != Client.CommandShape.NONE and context.is_empty():
		if OS.get_thread_caller_id() != OS.get_main_thread_id():
			return {
				"status": "error", 
				"message": "Cannot remove %s without a main-thread launch snapshot; retry from the dock." % client.display_name, 
			}
		context = capture_launch_context()
	var launch: = (
		resolve_attach_launch(context)
		if client.command_shape != Client.CommandShape.NONE
		else {}
	)
	var claim: = MutationLock.acquire(client.id, "remove")
	if not bool(claim.get("ok", false)):
		return {
			"status": "error", 
			"message": str(claim.get("error", MutationLock.recovery_message())), 
		}
	var result: = _dispatch_remove(client, context)
	var verified: = _verify_post_state(
		client, result, Client.Status.NOT_CONFIGURED, url, "remove", launch, context
	)
	return _finish_client_mutation(claim, verified)






static func _config_path_resolution_error(client: Client) -> String:
	if client.config_type == "cli":
		return ""
	return str(client.resolved_config_path_details().get("error", ""))






static func _config_create_error(client: Client) -> String:
	if client.config_type == "cli":
		return ""
	return str(client.resolved_config_path_details().get("create_error", ""))







static func _config_write_error(client: Client, action: String) -> String:
	if client.config_type == "cli":
		if action == "configure":
			return CliStrategy.configure_write_error(client)
		return CliStrategy.remove_write_error(client)
	return client.config_write_error()






static func _credentials_error(client: Client) -> String:
	if client.command_shape == Client.CommandShape.NONE:
		return ""
	if not McpPathTemplate.flatpak_hides_credentials():
		return ""
	var app_id: = McpPathTemplate.flatpak_app_id()
	return (
		"Godot runs in a Flatpak sandbox that keeps Godot AI's credentials to "
		+ "itself, so the bridge %s starts could not connect and nothing was "
		+ "changed. Run `flatpak override --user "
		+ "--filesystem=xdg-config/godot-ai:create %s`, restart Godot, and try "
		+ "again. docs/steam-capability-directory.md covers the other ways to "
		+ "share them."
	) % [client.display_name, app_id if not app_id.is_empty() else "<Godot's Flatpak ID>"]




static func _manual_edit_result(client: Client, action: String) -> Dictionary:
	return {
		"status": "error", 
		"message": (
			"%s settings require a manual edit; godot-ai will not %s this file automatically. "
			+ "Use the configuration shown below."
		) % [client.display_name, action], 
	}





static func _finish_client_mutation(claim: Dictionary, result: Dictionary) -> Dictionary:
	if bool(result.get("termination_failed", false)):
		return result
	if MutationLock.release(claim):
		return result
	return {
		"status": "error", 
		"message": MutationLock.recovery_message(), 
		"mutation_lock_release_failed": true, 
	}

static func _dispatch_configure(
	client: Client, url: String, launch: Dictionary = {}, launch_context: Dictionary = {}
) -> Dictionary:
	launch = launch_for_client(client, launch)
	match client.config_type:
		"json":
			return JsonStrategy.configure(client, SERVER_NAME, url, launch, _project_roots_from_context(launch_context))
		"toml":
			return TomlStrategy.configure(client, SERVER_NAME, url, launch)
		"yaml":
			return YamlStrategy.configure(client, SERVER_NAME, url, launch)
		"dsh":
			return DshStrategy.configure(client, SERVER_NAME, url, launch)
		"cli":


			if client.has_json_fallback() and CliStrategy.resolve_cli_path(client).is_empty():
				return _note_unhonoured_scope(
					client, JsonStrategy.configure(client, SERVER_NAME, url, launch, _project_roots_from_context(launch_context))
				)
			return CliStrategy.configure(client, SERVER_NAME, url, launch)
	return {"status": "error", "message": "Unknown config_type for %s: %s" % [client.id, client.config_type]}


static func _dispatch_remove(client: Client, launch_context: Dictionary = {}) -> Dictionary:
	match client.config_type:
		"json":
			return JsonStrategy.remove(client, SERVER_NAME, _project_roots_from_context(launch_context))
		"toml":
			return TomlStrategy.remove(client, SERVER_NAME)
		"yaml":
			return YamlStrategy.remove(client, SERVER_NAME)
		"dsh":
			return DshStrategy.remove(client, SERVER_NAME)
		"cli":


			if client.has_json_fallback() and CliStrategy.resolve_cli_path(client).is_empty():
				return JsonStrategy.remove(client, SERVER_NAME, _project_roots_from_context(launch_context))
			return CliStrategy.remove(client, SERVER_NAME)
	return {"status": "error", "message": "Unknown config_type for %s: %s" % [client.id, client.config_type]}


static func _dispatch_check_status(
	client: Client, url: String, launch_context: Dictionary = {}
) -> Client.Status:
	return _dispatch_check_status_with_cli_path(client, url, "", launch_context)


static func _dispatch_check_status_with_cli_path(
	client: Client, url: String, cli_path: String, launch_context: Dictionary = {}
) -> Client.Status:
	return _dispatch_check_status_with_cli_path_details(client, url, cli_path, launch_context).get("status", Client.Status.NOT_CONFIGURED)


static func _dispatch_check_status_with_cli_path_details(
	client: Client, 
	url: String, 
	cli_path: String, 
	launch_context: Dictionary = {}, 
	resolved_launch: Dictionary = {}, 
) -> Dictionary:
	match client.config_type:
		"json":
			var launch: = {}
			if client.command_shape != Client.CommandShape.NONE:
				launch = _resolved_or_discovered_launch(client, resolved_launch, launch_context)
			return JsonStrategy.check_status_details(client, SERVER_NAME, url, launch, _project_roots_from_context(launch_context))
		"toml":
			var launch: = {}
			if client.command_shape != Client.CommandShape.NONE:
				launch = _resolved_or_discovered_launch(client, resolved_launch, launch_context)
			return TomlStrategy.check_status_details(client, SERVER_NAME, url, launch)
		"yaml":
			var yaml_launch: = {}
			if client.command_shape != Client.CommandShape.NONE:
				yaml_launch = _resolved_or_discovered_launch(client, resolved_launch, launch_context)
			return YamlStrategy.check_status_details(client, SERVER_NAME, url, yaml_launch)
		"dsh":
			var dsh_launch: = {}
			if client.command_shape != Client.CommandShape.NONE:
				dsh_launch = _resolved_or_discovered_launch(client, resolved_launch, launch_context)
			return DshStrategy.check_status_details(client, SERVER_NAME, url, dsh_launch)
		"cli":








			if (
				client.command_shape != Client.CommandShape.NONE
				and client.has_json_fallback()
				and not _scope_diverges_from_json_fallback(client)
			):
				var command_launch: = _resolved_or_discovered_launch(client, resolved_launch, launch_context)
				return JsonStrategy.check_status_details(client, SERVER_NAME, url, command_launch, _project_roots_from_context(launch_context))
			var resolved_cli: = cli_path if not cli_path.is_empty() else CliStrategy.resolve_cli_path(client)


			if resolved_cli.is_empty() and client.has_json_fallback():
				var fallback_launch: = {}
				if client.command_shape != Client.CommandShape.NONE:
					fallback_launch = _resolved_or_discovered_launch(client, resolved_launch, launch_context)
				return JsonStrategy.check_status_details(client, SERVER_NAME, url, fallback_launch, _project_roots_from_context(launch_context))
			var cli_launch: = {}
			if client.command_shape != Client.CommandShape.NONE:
				cli_launch = _resolved_or_discovered_launch(client, resolved_launch, launch_context)




			if (
				not client.cli_scope_status_template.is_empty()
				and CliStrategy.uses_scope_token(client)
			):
				return CliStrategy.check_scope_status_details(
					client, SERVER_NAME, url, resolved_cli, cli_launch, McpSettings.client_scope()
				)
			return CliStrategy.check_status_details(client, SERVER_NAME, url, resolved_cli, cli_launch)
	return {"status": Client.Status.NOT_CONFIGURED, "error_msg": ""}
















static func _note_unhonoured_scope(client: Client, result: Dictionary) -> Dictionary:
	if result.get("status") != "ok":
		return result
	if not CliStrategy.uses_scope_token(client):
		return result
	var scope: = McpSettings.client_scope()
	if scope == McpSettings.DEFAULT_CLIENT_SCOPE:
		return result
	var noted: = result.duplicate(true)
	noted["message"] = (
		"%s — wrote %s scope, not %s: the %s CLI wasn't found, and the file fallback can only write %s"
		%[
			str(result.get("message", "")), 
			McpSettings.DEFAULT_CLIENT_SCOPE, 
			scope, 
			client.display_name, 
			client.resolved_config_path(), 
		]
	)
	return noted




























static func _scope_diverges_from_json_fallback(client: Client) -> bool:
	if not CliStrategy.uses_scope_token(client):
		return false
	return McpSettings.client_scope() != McpSettings.DEFAULT_CLIENT_SCOPE


static func _resolved_or_discovered_launch(
	client: Client, resolved_launch: Dictionary, launch_context: Dictionary
) -> Dictionary:
	var launch: = (
		resolved_launch
		if not resolved_launch.is_empty()
		else resolve_attach_launch(launch_context)
	)
	return launch_for_client(client, launch)






static func _verify_post_state(
	client: Client, 
	result: Dictionary, 
	expected: Client.Status, 
	url: String, 
	action: String, 
	resolved_launch: Dictionary = {}, 
	launch_context: Dictionary = {}, 
) -> Dictionary:
	if result.get("status") != "ok":
		return result
	var details: = _dispatch_check_status_with_cli_path_details(
		client, url, "", launch_context, resolved_launch
	)
	var actual: = details.get("status", Client.Status.NOT_CONFIGURED)
	if actual == expected:
		return result
	var path_hint: = _post_state_path_hint(client, str(details.get("resolved_scope", "")))
	return {
		"status": "error", 
		"message": "%s reported %s ok but verification still reads %s (expected %s).%s" % [
			client.display_name, action, 
			Client.status_label(actual), Client.status_label(expected), 
			path_hint, 
		], 
	}









static func _post_state_path_hint(client: Client, resolved_scope: String) -> String:
	match resolved_scope:
		"project":
			return (
				" The surviving entry is project-scoped: inspect the .mcp.json in the"
				+ " directory the editor was launched from and remove the godot-ai entry"
				+ " by hand if needed."
			)
		"local":
			var local_path: = client.resolved_config_path()
			if local_path.is_empty():
				return ""
			return (
				" The surviving entry is local-scoped: inspect the block for the"
				+ " directory the editor was launched from in %s and remove the"
				+ " godot-ai entry by hand if needed."
			) % local_path
		_:
			var path: = client.resolved_config_path()
			if path.is_empty():
				return ""
			return " Inspect %s and remove the godot-ai entry by hand if needed." % path

















static func configure_sweep_note(id: String) -> String:
	var client: = ClientRegistry.get_by_id(id)
	if client == null or client.config_type != "cli":
		return ""
	if client.cli_unregister_template.is_empty() or not CliStrategy.uses_scope_token(client):
		return ""
	return "attempted to clear %s from %s" % [
		SERVER_NAME, ", ".join(CliStrategy.cleanup_scopes(client)), 
	]


static func manual_command(id: String) -> String:
	var client: = ClientRegistry.get_by_id(id)
	if client == null:
		return ""
	var path_resolution: = client.resolved_config_path_details()
	var path_error: = str(path_resolution.get("error", ""))
	if not path_error.is_empty():
		return "Config path unavailable: %s" % path_error
	var context: = capture_launch_context() if client.command_shape != Client.CommandShape.NONE else {}
	var launch: = (
		launch_for_client(client, resolve_attach_launch(context))
		if client.command_shape != Client.CommandShape.NONE
		else {}
	)
	var cmd: = ManualCommand.build(
		client, 
		SERVER_NAME, 
		server_url_from(context), 
		str(path_resolution.get("path", "")), 
		launch, 
		_project_roots_from_context(context), 
	)
	if cmd.is_empty():
		return cmd




	var hidden_paths: Variant = path_resolution.get("hidden_paths", null)
	if hidden_paths is PackedStringArray and not hidden_paths.is_empty():
		cmd += (
			"\n\nA Flatpak build keeps this file at %s instead. Godot's own Flatpak "
			+ "sandbox cannot see it, so edit that one if it is the build you use."
		) % " or ".join(hidden_paths)




	var note: = McpAllowHosts.lan_url_note(allow_hosts(), IP.get_local_addresses(), http_port())
	if not note.is_empty():
		cmd += "\n\n" + note
	return cmd


static func config_path(id: String) -> String:
	var client: = ClientRegistry.get_by_id(id)
	return client.resolved_config_path() if client != null else ""









static func effective_config_path(id: String, launch_context: Dictionary = {}) -> String:
	var client: = ClientRegistry.get_by_id(id)
	if client == null:
		return ""
	var resolution: = client.resolved_config_path_details()
	var fallback: = str(resolution.get("path", ""))
	var context: = launch_context
	if context.is_empty() and client.command_shape != Client.CommandShape.NONE:
		context = capture_launch_context()
	var roots: = _project_roots_from_context(context)
	var target: = JsonStrategy.manual_target_details(client, SERVER_NAME, fallback, roots)
	if bool(target.get("ok", false)):
		return str(target.get("path", fallback))
	return fallback















static func effective_authoritative_path(id: String, launch_context: Dictionary = {}) -> String:
	var client: = ClientRegistry.get_by_id(id)
	if client == null:
		return ""
	var resolution: = client.resolved_config_path_details()
	var fallback: = str(resolution.get("path", ""))
	var context: = launch_context
	if context.is_empty() and client.command_shape != Client.CommandShape.NONE:
		context = capture_launch_context()
	var roots: = _project_roots_from_context(context)
	var authoritative: String = JsonStrategy.authoritative_tier_path(client, SERVER_NAME, roots)
	if not authoritative.is_empty():
		return authoritative
	return fallback


static func is_installed(id: String) -> bool:
	var client: = ClientRegistry.get_by_id(id)
	return client != null and client.is_installed()









static func get_plugin_version() -> String:
	var cfg: = ConfigFile.new()
	if cfg.load("res://addons/godot_ai/plugin.cfg") == OK:
		return cfg.get_value("plugin", "version", "0.0.1")
	return "0.0.1"




static func _pypi_pin_version(version: String) -> String:
	var v: = version.strip_edges()
	var plus: = v.find("+")
	if plus >= 0:
		v = v.substr(0, plus)
	return v









static func resolve_attach_launch(
	launch_context: Dictionary, discovery_override: Dictionary = {}
) -> Dictionary:




	if not discovery_override.is_empty():
		return _resolve_attach_launch_uncached(launch_context, discovery_override)
	var cache_key: = _attach_launch_cache_key(launch_context)
	_attach_launch_cache_mutex.lock()
	if _attach_launch_cache.has(cache_key):
		var cached: Dictionary = _attach_launch_cache[cache_key].duplicate(true)
		_attach_launch_cache_mutex.unlock()
		return cached





	var resolved: = _resolve_attach_launch_uncached(launch_context)
	_attach_launch_cache[cache_key] = resolved.duplicate(true)
	_attach_launch_cache_mutex.unlock()
	return resolved


static func _resolve_attach_launch_uncached(
	launch_context: Dictionary, discovery_override: Dictionary = {}
) -> Dictionary:
	for key in ["http_port", "ws_port", "excluded_domains", "plugin_version", "allow_dev_venv", "platform"]:
		if not launch_context.has(key):
			return _attach_discovery_error("Launch context is missing `%s`; retry Configure." % key)

	var plugin_version: = str(launch_context.get("plugin_version", "")).strip_edges()
	if plugin_version.is_empty():
		return _attach_discovery_error("The bundled godot-ai version is unavailable; reinstall the plugin and retry Configure.")

	var common_args: Array[String] = [
		"attach", 
		"--port", str(int(launch_context.get("http_port", DEFAULT_HTTP_PORT))), 
		"--ws-port", str(int(launch_context.get("ws_port", DEFAULT_WS_PORT))), 
	]
	var exclusions: = str(launch_context.get("excluded_domains", "")).strip_edges()
	if not exclusions.is_empty():
		common_args.append_array(["--exclude-domains", exclusions])





	if not bool(launch_context.get("telemetry_enabled", true)):
		common_args.append("--disable-telemetry")

	var venv_python: = ""
	if discovery_override.has("venv_python"):
		venv_python = str(discovery_override["venv_python"])
	elif bool(launch_context.get("allow_dev_venv", true)):
		venv_python = _cached_venv_python()
	if bool(launch_context.get("allow_dev_venv", true)) and not venv_python.is_empty():
		var venv_args: Array[String] = ["-m", "godot_ai"]
		venv_args.append_array(common_args)
		return _finalize_attach_launch(
			"dev_venv", venv_python, venv_args, launch_context, discovery_override
		)

	var uvx: = ""
	if discovery_override.has("uvx_path"):
		uvx = str(discovery_override["uvx_path"])
	else:


		uvx = find_uvx()
	if not uvx.is_empty():
		var uvx_args: = UvResolution.args()
		uvx_args.append_array([
			"--link-mode", "copy", 
			"--from", "godot-ai==%s" % _pypi_pin_version(plugin_version), 
			"godot-ai", 
		])
		uvx_args.append_array(common_args)
		return _finalize_attach_launch(
			"uvx", uvx, uvx_args, launch_context, discovery_override
		)

	var system_cmd: = ""
	if discovery_override.has("system_path"):
		system_cmd = str(discovery_override["system_path"])
	else:
		system_cmd = _find_system_install()
	if not system_cmd.is_empty():
		var probe: Dictionary
		if discovery_override.has("system_version_result"):
			probe = discovery_override["system_version_result"] as Dictionary
		else:
			probe = McpCliExec.run(system_cmd, ["--version"], _DISCOVERY_TIMEOUT_MS, false)
		var version_check: = _system_version_from_probe(probe)
		if bool(version_check.get("ok", false)):
			var found_version: = str(version_check.get("version", ""))
			if found_version == plugin_version:
				return _finalize_attach_launch(
					"system", system_cmd, common_args, launch_context, discovery_override
				)
			return _attach_discovery_error(
				"System godot-ai is version %s, but this plugin requires %s. Install uv or update the system package, then retry Configure."
				%[found_version, plugin_version]
			)
		if bool(probe.get("timed_out", false)):
			return _attach_discovery_error(
				"Timed out checking the system godot-ai version. Install uv or repair the system command, then retry Configure."
			)
		return _attach_discovery_error(
			"Could not verify the system godot-ai version. Install uv or repair the system command, then retry Configure."
		)

	return _attach_discovery_error(
		"No compatible godot-ai launcher was found. Install uv (provides uvx), then retry Configure."
	)






static func _finalize_attach_launch(
	tier: String, 
	command: String, 
	args: Array[String], 
	launch_context: Dictionary, 
	discovery_override: Dictionary, 
) -> Dictionary:
	if str(launch_context.get("platform", "")) != "Windows":
		return {"ok": true, "tier": tier, "command": command, "args": args}

	var pythonw: = _resolve_consoleless_python(command, tier, discovery_override)
	if pythonw.is_empty():
		return _attach_discovery_error(
			"Windows requires pythonw.exe to launch the MCP bridge without opening a terminal window. Repair this Python or uv installation, then retry Configure."
		)





	if tier == "dev_venv":
		return {
			"ok": true, "tier": tier, "command": pythonw, "args": args, 
			"console_command": command, "console_args": args, 
		}

	var wrapped_args: Array[String] = ["-c", _WINDOWS_STDIO_BOOTSTRAP, command]
	wrapped_args.append_array(args)
	return {
		"ok": true, "tier": tier, "command": pythonw, "args": wrapped_args, 
		"console_command": command, "console_args": args, 
	}







static func launch_for_client(client: Client, launch: Dictionary) -> Dictionary:
	if client == null or client.needs_consoleless_launcher:
		return launch
	if not launch.has("console_command"):
		return launch
	var selected: = launch.duplicate(true)
	selected["command"] = selected["console_command"]
	selected["args"] = selected["console_args"]
	selected.erase("console_command")
	selected.erase("console_args")
	return selected


static func _resolve_consoleless_python(
	command: String, tier: String, discovery_override: Dictionary
) -> String:

	if discovery_override.has("consoleless_python"):
		return str(discovery_override["consoleless_python"])




	var sibling: = command.get_base_dir().path_join("pythonw.exe")
	if FileAccess.file_exists(sibling):
		return sibling
	if tier == "dev_venv":
		return ""




	if tier == "uvx":
		var uv: = command.get_base_dir().path_join("uv.exe")
		if not FileAccess.file_exists(uv):
			uv = CliFinder.find(["uv.exe"])
		if not uv.is_empty():
			var probe: = McpCliExec.run(
				uv, ["python", "find", "--system"], _DISCOVERY_TIMEOUT_MS, false
			)
			if int(probe.get("exit_code", -1)) == 0:
				var python: = str(probe.get("stdout", "")).strip_edges()
				if not python.is_empty():
					var managed_pythonw: = _consoleless_python_for_interpreter(python)
					if not managed_pythonw.is_empty():
						return managed_pythonw



	return CliFinder.find(["pythonw.exe"])





static func _consoleless_python_for_interpreter(
	python: String, probe_result: Dictionary = {}
) -> String:
	if not python.is_absolute_path() or not FileAccess.file_exists(python):
		return ""
	var sibling: = python.get_base_dir().path_join("pythonw.exe")
	if FileAccess.file_exists(sibling):
		return sibling
	var probe: = probe_result
	if probe.is_empty():
		probe = McpCliExec.run(
			python, ["-I", "-c", "import sys; print(getattr(sys, '_base_executable', sys.executable))"], 
			_DISCOVERY_TIMEOUT_MS, false
		)
	if int(probe.get("exit_code", -1)) != 0 or not probe.get("stdout") is String:
		return ""
	var base_python: = str(probe["stdout"]).strip_edges()
	if base_python.contains("\n") or base_python.contains("\r"):
		return ""
	if not base_python.is_absolute_path() or not FileAccess.file_exists(base_python):
		return ""
	var base_pythonw: = base_python.get_base_dir().path_join("pythonw.exe")
	return base_pythonw if FileAccess.file_exists(base_pythonw) else ""


static func _system_version_from_probe(probe: Dictionary) -> Dictionary:
	if int(probe.get("exit_code", -1)) != 0:
		return {"ok": false}
	var output: = str(probe.get("stdout", "")).strip_edges()
	var pattern: = RegEx.new()
	if pattern.compile("^godot-ai\\s+([^\\s]+)(?:\\s|$)") != OK:
		return {"ok": false}
	var matched: = pattern.search(output)
	if matched == null:
		return {"ok": false}
	return {"ok": true, "version": matched.get_string(1)}


static func _attach_discovery_error(message: String) -> Dictionary:
	return {"ok": false, "error": message}


















const MODE_OVERRIDE_ENV: = "GODOT_AI_MODE"
const MODE_OVERRIDE_SETTING: = "godot_ai/mode_override"


static func mode_override() -> String:






	var setting: Variant = _editor_setting_lookup(MODE_OVERRIDE_SETTING)
	if setting != null:
		var setting_val: = str(setting).strip_edges().to_lower()
		if setting_val == "dev" or setting_val == "user":
			return setting_val


	var raw: = McpPathTemplate.env_lookup(MODE_OVERRIDE_ENV).strip_edges().to_lower()
	if raw == "dev" or raw == "user":
		return raw
	return ""


static func is_dev_checkout() -> bool:
	match mode_override():
		"dev":
			return true
		"user":
			return false
	return not _find_venv_python().is_empty()







static func addons_dir_is_symlink() -> bool:
	return _is_symlink(ProjectSettings.globalize_path("res://addons/godot_ai"))





static func _is_symlink(path: String) -> bool:
	if path.is_empty():
		return false
	var dir: = DirAccess.open(path.get_base_dir())
	if dir == null:




		return DirAccess.dir_exists_absolute(path) or FileAccess.file_exists(path)
	return dir.is_link(path)


static func get_server_command(trace: Callable = Callable()) -> Array[String]:




	if mode_override() != "user":
		var venv_python: = _cached_venv_python()
		if not venv_python.is_empty():
			print("MCP | using dev venv: %s" % venv_python)
			return [venv_python, "-m", "godot_ai"]

	var uvx: = find_uvx(trace)
	if not uvx.is_empty():
		var version: = get_plugin_version()




		var pypi_version: = _pypi_pin_version(version)








		if pypi_version != version:
			print(
				"MCP | using uvx (godot-ai==%s; local plugin %s not on PyPI)"
				%[pypi_version, version]
			)
		else:
			print("MCP | using uvx (godot-ai==%s)" % pypi_version)
		var cmd: Array[String] = [uvx]
		cmd.append_array(UvResolution.args())
		cmd.append_array(["--from", "godot-ai==%s" % pypi_version, "godot-ai"])
		return cmd

	var system_cmd: = _find_system_install(trace)
	if not system_cmd.is_empty():
		print("MCP | using system install: %s" % system_cmd)
		return [system_cmd]

	push_warning("MCP | no server found — install uv or run: pip install godot-ai")
	return []





static func get_server_launch_mode() -> String:
	if mode_override() != "user" and not _cached_venv_python().is_empty():
		return "dev_venv"
	if not find_uvx().is_empty():
		return "uvx"
	if not _find_system_install().is_empty():
		return "system"
	return "unknown"








const PREWARM_TIMEOUT_MS: = 180000


static func find_uvx(trace: Callable = Callable()) -> String:
	return CliFinder.find(_uvx_cli_names(), trace)









static func prewarm_server_package_argv(version: String) -> Array[String]:
	var pinned: = version.strip_edges()
	if pinned.is_empty():
		return []



	var re: = RegEx.new()
	if re.compile("^[A-Za-z0-9.+!-]+$") != OK or re.search(pinned) == null:
		return []
	var args: = UvResolution.args()
	args.append_array(["--from", "godot-ai==%s" % pinned, "godot-ai", "--version"])
	return args



























static func prewarm_server_package_blocking(
	version: String, 
	timeout_ms: int = PREWARM_TIMEOUT_MS, 
	cancel_check: Callable = Callable(), 
) -> Dictionary:
	var args: = prewarm_server_package_argv(version)
	if args.is_empty():
		return {"skipped": true, "reason": "no version pin"}
	var uvx: = find_uvx()
	if uvx.is_empty():

		return {"skipped": true, "reason": "no uvx"}
	var command: Array[String] = [uvx]
	command.append_array(args)
	var result: = McpCliExec.run(
		uvx, 
		args, 
		timeout_ms, 
		true, 
		cancel_check, 
		UvResolution.is_production_command(command), 
	)
	result["skipped"] = false
	return result














static func prewarm_attach_plan(
	launch_context: Dictionary, discovery_override: Dictionary = {}
) -> Dictionary:
	var launch: = resolve_attach_launch(launch_context, discovery_override)
	if not bool(launch.get("ok", false)):
		return {"warm": false, "version": "", "reason": "launch discovery failed"}
	var tier: = str(launch.get("tier", ""))
	if tier != "uvx":
		return {"warm": false, "version": "", "reason": "tier %s has no env to warm" % tier}
	var version: = _pypi_pin_version(str(launch_context.get("plugin_version", "")))
	if version.is_empty():
		return {"warm": false, "version": "", "reason": "no version pin"}
	return {"warm": true, "version": version, "reason": ""}




static func prewarm_attach_launch(
	launch_context: Dictionary, 
	timeout_ms: int = PREWARM_TIMEOUT_MS, 
	discovery_override: Dictionary = {}, 
	cancel_check: Callable = Callable(), 
) -> Dictionary:
	var plan: = prewarm_attach_plan(launch_context, discovery_override)
	if not bool(plan.get("warm", false)):
		return {"skipped": true, "reason": str(plan.get("reason", ""))}
	return prewarm_server_package_blocking(
		str(plan.get("version", "")), timeout_ms, cancel_check
	)


static func _uvx_cli_names() -> Array[String]:
	var names: Array[String] = []
	names.append("uvx.exe" if OS.get_name() == "Windows" else "uvx")
	return names









static func invalidate_uvx_cli_cache() -> void :
	for name in _uvx_cli_names():
		CliFinder.invalidate(name)















static func invalidate_cli_cache() -> void :
	CliFinder.invalidate()


static var _uv_version_cache: String = ""
static var _uv_version_searched: bool = false













static func check_uv_version() -> String:
	if _uv_version_searched:
		return _uv_version_cache
	var uvx: = find_uvx()
	if uvx.is_empty():
		_uv_version_searched = true
		_uv_version_cache = ""
		return ""
	var result: = McpCliExec.run(uvx, ["--version"], _DISCOVERY_TIMEOUT_MS, false)
	if int(result.get("exit_code", -1)) == 0:
		var lines: = PackedStringArray(str(result.get("stdout", "")).split("\n"))
		_uv_version_cache = lines[0].strip_edges() if lines.size() > 0 else ""
	else:
		_uv_version_cache = ""
	_uv_version_searched = true
	return _uv_version_cache


static func invalidate_uv_version_cache() -> void :
	_uv_version_searched = false
	_uv_version_cache = ""






static func uv_probe_negative() -> bool:
	return _uv_version_searched and _uv_version_cache.is_empty()









static func invalidate_uv_detection() -> void :
	invalidate_uvx_cli_cache()
	invalidate_uv_version_cache()
	_attach_launch_cache_mutex.lock()
	_attach_launch_cache.clear()
	_attach_launch_cache_mutex.unlock()


static var _venv_python_cache: String = ""
static var _venv_python_searched: bool = false


static var _venv_mutex: Mutex = Mutex.new()
static var _attach_launch_cache: = {}
static var _attach_launch_cache_mutex: = Mutex.new()


static func _attach_launch_cache_key(launch_context: Dictionary) -> String:
	return JSON.stringify([
		launch_context.get("http_port", null), 
		launch_context.get("ws_port", null), 
		launch_context.get("excluded_domains", null), 
		launch_context.get("plugin_version", null), 
		launch_context.get("allow_dev_venv", null), 
		launch_context.get("platform", null), 
		launch_context.get("telemetry_enabled", null), 
	])


static func _cached_venv_python() -> String:
	_venv_mutex.lock()
	if not _venv_python_searched:
		_venv_python_cache = _find_venv_python()
		_venv_python_searched = true
	var cached: = _venv_python_cache
	_venv_mutex.unlock()
	return cached






static func resolve_addons_realpath() -> String:
	var addons_path: = ProjectSettings.globalize_path("res://addons/godot_ai").rstrip("/").rstrip("\\")
	if addons_path.is_empty():
		return ""
	var parent: = addons_path.get_base_dir()
	var dir: = DirAccess.open(parent)
	if dir != null and dir.is_link(addons_path):
		var target: = dir.read_link(addons_path)
		if not target.is_empty():
			if target.is_relative_path():
				target = parent.path_join(target).simplify_path()
			return target.rstrip("/").rstrip("\\")
	return addons_path


static func _find_venv_python() -> String:

	var env_py: = McpPathTemplate.env_lookup("GODOT_AI_VENV_PYTHON").strip_edges()
	if not env_py.is_empty():
		if FileAccess.file_exists(env_py):
			return env_py



		push_warning(
			"godot-ai: GODOT_AI_VENV_PYTHON is set but no file exists at '%s'; ignoring override."
			%env_py
		)

	var from_project: = _find_venv_python_in(
		ProjectSettings.globalize_path("res://").rstrip("/").rstrip("\\")
	)
	if not from_project.is_empty():
		return from_project

	var addons_real: = resolve_addons_realpath()
	if not addons_real.is_empty():
		var from_addons: = _find_venv_python_in(addons_real)
		if not from_addons.is_empty():
			return from_addons
	return ""








static func _find_venv_python_in(start_dir: String) -> String:
	var dir: = start_dir.rstrip("/").rstrip("\\")
	var python_name: = "python" if OS.get_name() != "Windows" else "python.exe"
	var venv_dir: = ".venv/bin/" if OS.get_name() != "Windows" else ".venv/Scripts/"


	for i in 8:
		var venv_path: = dir.path_join(venv_dir + python_name)
		if FileAccess.file_exists(venv_path) and DirAccess.dir_exists_absolute(dir.path_join("src/godot_ai")):
			return venv_path
		var parent: = dir.get_base_dir()
		if parent == dir or parent.is_empty():
			break
		dir = parent
	return ""







static func find_worktree_src_dir(start_dir: String) -> String:
	var dir: = start_dir.rstrip("/")
	for i in 5:
		var candidate: = dir.path_join("src/godot_ai")
		if DirAccess.dir_exists_absolute(candidate):
			return dir.path_join("src")
		var parent: = dir.get_base_dir()
		if parent == dir:
			break
		dir = parent
	return ""






static func _find_system_install(trace: Callable = Callable()) -> String:



	var names: Array[String] = ["godot-ai"]
	if OS.get_name() == "Windows":
		names.push_front("godot-ai.exe")
	return CliFinder.find(names, trace)
