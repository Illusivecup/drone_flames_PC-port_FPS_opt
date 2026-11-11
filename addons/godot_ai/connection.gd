@tool
class_name McpConnection
extends Node





const RECONNECT_DELAYS: Array[float] = [1.0, 2.0, 4.0, 8.0, 16.0, 30.0, 60.0]
const RECONNECT_VERBOSE_ATTEMPTS: = 5
const RECONNECT_LOG_HEARTBEAT_MSEC: = 60000




const OUTBOUND_BUFFER_LIMIT_BYTES: = 4 * 1024 * 1024





const PACKET_DRAIN_CAP_PER_TICK: = 32
const MAX_QUEUED_PACKETS: = 64
const WS_PROTOCOL_VERSION: = 2
const HANDSHAKE_TIMEOUT_MSEC: = 5000
const MAX_HANDSHAKE_FRAME_BYTES: = 8 * 1024
const CLOSE_CODE_DUPLICATE_SESSION: = 4001
const CLOSE_CODE_PROTOCOL_MISMATCH: = 4002
const CLOSE_CODE_AUTH_FAILED: = 4003
const _SERVER_PROOF_DOMAIN: = "godot-ai-ws-v2/server-proof"
const _CLIENT_PROOF_DOMAIN: = "godot-ai-ws-v2/client-proof"
const ClientConfigurator: = preload("res://addons/godot_ai/client_configurator.gd")
const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")




signal connection_state_changed(is_open: bool)

var _peer: = WebSocketPeer.new()





var ws_port: = ClientConfigurator.DEFAULT_WS_PORT




var auth_token: = ""
var _url: = ""
var _connected: = false
var _reconnect_attempt: = 0
var _reconnect_timer: = 0.0



var _observed_peer_state: = WebSocketPeer.STATE_CLOSED
var _peer_state_entered_msec: = 0
var _last_reconnect_transition_log_msec: = -1
var _transient_diagnostic: Dictionary = {}


var _preopen_failure_logged_for_peer: = false
var _session_id: = ""
var _handshake_started_msec: = 0
var _client_nonce: = ""
var _server_nonce: = ""
var _challenged_server_version: = ""
var _server_verified: = false
var _auth_response_sent: = false
var _handshake_complete: = false


var server_version: = ""

var dispatcher
var log_buffer
var surfaced_error_tracker




var debugger_plugin



var connect_blocked: = false
var connect_block_reason: = ""
var _blocked_notice_logged: = false



var pause_processing: bool:
	get: return _pause_depth > 0
	set(value):
		if value:
			pause()
		else:
			resume()
var _pause_depth: = 0




var _packet_spillover_total: = 0


func _ready() -> void :
	_session_id = _make_session_id(ProjectSettings.globalize_path("res://"))
	_configure_peer_buffers(_peer)
	if connect_blocked:
		_log_blocked_notice_once()
		set_process(false)
		return
	_connect_to_server()
	_hook_editor_signals()


func _process(delta: float) -> void :
	if pause_processing:
		return
	_peer.poll()



	_check_game_run_play_state(EditorInterface.is_playing_scene())

	var peer_state: = _peer.get_ready_state()
	var transition: = _observe_peer_state(peer_state, Time.get_ticks_msec())
	match peer_state:
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				if log_buffer:
					log_buffer.log("connected to server; authenticating")
				_send_auth_hello()

			_drain_inbound_packets(_peer)
			if not _handshake_complete:
				if (
					_handshake_started_msec > 0
					and Time.get_ticks_msec() - _handshake_started_msec >= HANDSHAKE_TIMEOUT_MSEC
				):
					_fail_handshake(CLOSE_CODE_AUTH_FAILED, "v4 editor handshake timed out")
				return

			_check_state_changes()

			if dispatcher:
				for response in dispatcher.tick():
					_send_json(response)

		WebSocketPeer.STATE_CLOSED:
			if _connected:
				_connected = false
				var was_authenticated: = _handshake_complete
				var server_was_verified: = _server_verified




				_preopen_failure_logged_for_peer = true
				_clear_on_disconnect()
				var code: = _peer.get_close_code()
				var reason: = _peer.get_close_reason()
				if _should_regenerate_session_id(code, server_was_verified, was_authenticated):
					_session_id = _make_session_id(ProjectSettings.globalize_path("res://"))
				var open_elapsed_sec: = float(transition.get("previous_elapsed_sec", 0.0))
				var close_diagnostic: = _handshake_close_diagnostic(code, was_authenticated)
				if close_diagnostic.is_empty():
					close_diagnostic = {
						"reason_code": "connection_lost", 
						"reason": _close_reason_text(code, reason), 
					}
				_transient_diagnostic = close_diagnostic
				_log_reconnect_transition(
					_postopen_close_diagnostic(
						open_elapsed_sec, 
						code, 
						reason, 
						_url, 
					), 
					maxi(1, _reconnect_attempt), 
					true, 
				)
				if was_authenticated:
					connection_state_changed.emit(false)
			elif not _preopen_failure_logged_for_peer:
				_preopen_failure_logged_for_peer = true


				_transient_diagnostic.clear()



				var failed_attempt: = maxi(1, _reconnect_attempt)
				var connecting_elapsed_sec: = float(
					transition.get("previous_elapsed_sec", 0.0)
				)
				_log_reconnect_transition(
					_preopen_failure_diagnostic(
						failed_attempt, 
						connecting_elapsed_sec, 
						_reconnect_timer, 
						_peer.get_close_code(), 
						_peer.get_close_reason(), 
						_url
					), 
					failed_attempt, 
				)
			_reconnect_timer -= delta
			if _reconnect_timer <= 0.0:
				_attempt_reconnect()

		WebSocketPeer.STATE_CLOSING:
			pass
		WebSocketPeer.STATE_CONNECTING:
			pass

func get_session_id() -> String:
	return _session_id











func _drain_inbound_packets(peer) -> Dictionary:
	var drained: = 0
	while peer.get_available_packet_count() > 0 and drained < PACKET_DRAIN_CAP_PER_TICK:
		var raw: String = peer.get_packet().get_string_from_utf8()
		_handle_message(raw)
		drained += 1

	var spilled: = 0
	if drained >= PACKET_DRAIN_CAP_PER_TICK and peer.get_available_packet_count() > 0:
		spilled = peer.get_available_packet_count()
		_packet_spillover_total += spilled
		if log_buffer:
			log_buffer.log(
				(
					"[backpressure] inbound drain capped at %d/tick;"
					+ " %d packets spilled to next frame (cumulative %d)"
				)
				%[PACKET_DRAIN_CAP_PER_TICK, spilled, _packet_spillover_total]
			)

	return {"drained": drained, "spilled": spilled}


var is_connected: bool:
	get: return _connected and _handshake_complete


func disconnect_from_server(reason: = "Plugin unloading") -> void :
	var was_authenticated: = _handshake_complete
	if _peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_peer.close(1000, reason)




	_peer = WebSocketPeer.new()
	_observed_peer_state = WebSocketPeer.STATE_CLOSED
	_peer_state_entered_msec = Time.get_ticks_msec()
	_connected = false



	_preopen_failure_logged_for_peer = true
	_clear_on_disconnect()
	if was_authenticated:
		connection_state_changed.emit(false)





func revoke_transport(reason: String) -> void :
	auth_token = ""
	connect_blocked = true
	connect_block_reason = reason
	set_process(false)
	disconnect_from_server("Transport authority revoked")





func authorize_transport(p_ws_port: int, p_auth_token: String) -> void :
	ws_port = p_ws_port
	auth_token = p_auth_token
	connect_blocked = false
	connect_block_reason = ""
	server_version = ""
	_reconnect_timer = 0.0
	set_process(true)
	if is_inside_tree():
		_attempt_reconnect()







func _clear_on_disconnect() -> void :
	server_version = ""
	_handshake_started_msec = 0
	_client_nonce = ""
	_server_nonce = ""
	_challenged_server_version = ""
	_server_verified = false
	_auth_response_sent = false
	_handshake_complete = false


	_packet_spillover_total = 0
	if dispatcher:
		dispatcher.clear_deferred_responses()




		dispatcher.clear_command_queue()






func teardown() -> void :
	set_process(false)
	disconnect_from_server()
	dispatcher = null
	log_buffer = null


func _connect_to_server() -> void :
	_url = "ws://127.0.0.1:%d" % ws_port
	var err: = _peer.connect_to_url(_url)
	if err != OK:
		log_buffer.log("failed to initiate connection (error %d)" % err)
	_observed_peer_state = _peer.get_ready_state()
	_peer_state_entered_msec = Time.get_ticks_msec()


func _attempt_reconnect() -> void :
	if connect_blocked:
		_log_blocked_notice_once()
		set_process(false)
		return
	var delay: = _reconnect_delay_for_attempt(_reconnect_attempt)
	_reconnect_attempt += 1
	_reconnect_timer = delay
	_log_reconnect_transition(
		"connecting to server (attempt %d)" % _reconnect_attempt, 
		_reconnect_attempt, 
	)



	_peer = WebSocketPeer.new()
	_preopen_failure_logged_for_peer = false
	_configure_peer_buffers(_peer)
	_connect_to_server()






static func _configure_peer_buffers(peer: WebSocketPeer) -> void :

	peer.outbound_buffer_size = OUTBOUND_BUFFER_LIMIT_BYTES

	peer.inbound_buffer_size = OUTBOUND_BUFFER_LIMIT_BYTES
	peer.max_queued_packets = MAX_QUEUED_PACKETS


func pause() -> void :
	_pause_depth += 1


func resume() -> void :
	_pause_depth = maxi(0, _pause_depth - 1)


func pause_depth() -> int:
	return _pause_depth


static func _reconnect_delay_for_attempt(attempt_index: int) -> float:
	var delay_idx: = mini(attempt_index, RECONNECT_DELAYS.size() - 1)
	return RECONNECT_DELAYS[delay_idx]


static func _should_log_reconnect_transition(
	attempt_number: int, 
	now_msec: int, 
	last_log_msec: int
) -> bool:



	return (
		attempt_number <= RECONNECT_VERBOSE_ATTEMPTS
		or last_log_msec < 0
		or now_msec - last_log_msec >= RECONNECT_LOG_HEARTBEAT_MSEC
	)


func _log_reconnect_transition(message: String, attempt_number: int, force: = false) -> void :
	if not log_buffer:
		return
	var now_msec: = Time.get_ticks_msec()
	if not force and not _should_log_reconnect_transition(
		attempt_number, 
		now_msec, 
		_last_reconnect_transition_log_msec, 
	):
		return
	_last_reconnect_transition_log_msec = now_msec
	log_buffer.log(message)


static func _preopen_failure_diagnostic(
	attempt_number: int, 
	connecting_elapsed_sec: float, 
	retry_in_sec: float, 
	code: int, 
	reason: String, 
	url: String
) -> String:
	var retry_text: = "retrying now"
	if retry_in_sec > 0.0:
		retry_text = "retrying in %.0fs" % retry_in_sec
	return (
		"connection attempt %d failed before OPEN after %.1fs; %s"
		+ " (code %d, reason %s, url %s)"
	) % [
		attempt_number, 
		maxf(0.0, connecting_elapsed_sec), 
		retry_text, 
		code, 
		_sanitized_close_reason(reason), 
		url, 
	]


static func _postopen_close_diagnostic(
	open_elapsed_sec: float, 
	code: int, 
	reason: String, 
	url: String
) -> String:
	return (
		"connection lost after being open for %.1fs (code %d, reason %s, url %s); reconnecting"
		%[maxf(0.0, open_elapsed_sec), code, _sanitized_close_reason(reason), url]
	)


static func _sanitized_close_reason(reason: String) -> String:
	var reason_label: = reason.strip_edges()
	if reason_label.is_empty():
		return "<none>"
	return reason_label.replace("\r", "\\r").replace("\n", "\\n")


static func _close_reason_text(code: int, reason: String) -> String:
	return "Close code %d: %s" % [code, _sanitized_close_reason(reason)]


func _handshake_close_diagnostic(code: int, authenticated: = false) -> Dictionary:
	if code == CLOSE_CODE_PROTOCOL_MISMATCH:
		return {
			"reason_code": "ws_protocol_mismatch", 
			"reason": "The editor and server use different Godot AI major protocols; update/restart both sides.", 
		}
	if code == CLOSE_CODE_AUTH_FAILED:
		return {
			"reason_code": "ws_auth_failed", 
			"reason": "The v4 editor capability was rejected; restart the managed server from this Godot editor.", 
		}
	if not authenticated:
		return {
			"reason_code": "ws_handshake_failed", 
			"reason": "The v4 handshake closed before authentication; update/restart both editor and server.", 
		}
	return {}





func _observe_peer_state(state: int, now_msec: int) -> Dictionary:
	if _peer_state_entered_msec <= 0:
		_observed_peer_state = state
		_peer_state_entered_msec = now_msec
		return {"changed": false, "previous_elapsed_sec": 0.0}
	if state == _observed_peer_state:
		return {"changed": false, "previous_elapsed_sec": 0.0}
	var previous_elapsed_sec: = maxf(
		0.0, 
		(now_msec - _peer_state_entered_msec) / 1000.0, 
	)
	var previous_state: = _observed_peer_state
	_observed_peer_state = state
	_peer_state_entered_msec = now_msec
	return {
		"changed": true, 
		"previous_state": previous_state, 
		"previous_elapsed_sec": previous_elapsed_sec, 
	}






static func _transport_status_snapshot(
	state: int, 
	state_elapsed_sec: float, 
	attempt: int, 
	retry_timer: float
) -> Dictionary:
	var phase: = "closing"
	match state:
		WebSocketPeer.STATE_OPEN:
			phase = "connected"
		WebSocketPeer.STATE_CONNECTING:
			phase = "connecting"
		WebSocketPeer.STATE_CLOSED:
			phase = "retrying"
		WebSocketPeer.STATE_CLOSING:
			phase = "closing"
	var snapshot: = {
		"phase": phase, 
		"attempt": maxi(0, attempt), 
		"state_elapsed_sec": maxf(0.0, state_elapsed_sec), 
	}


	if phase == "retrying":
		snapshot["retry_in_sec"] = maxf(0.0, retry_timer)
	return snapshot


func get_transport_status() -> Dictionary:
	var now_msec: = Time.get_ticks_msec()
	var elapsed_sec: = 0.0
	if _peer_state_entered_msec > 0:
		elapsed_sec = maxf(0.0, (now_msec - _peer_state_entered_msec) / 1000.0)
	var snapshot: = _transport_status_snapshot(
		_peer.get_ready_state(), 
		elapsed_sec, 
		_reconnect_attempt, 
		_reconnect_timer, 
	)
	if connect_blocked:
		snapshot["phase"] = "blocked"
		snapshot.erase("retry_in_sec")
		snapshot["reason_code"] = "connection_blocked"
		if not connect_block_reason.is_empty():
			snapshot["reason"] = connect_block_reason
	elif _connected and not _handshake_complete:
		snapshot["phase"] = "authenticating"
		snapshot.erase("retry_in_sec")
	elif not _transient_diagnostic.is_empty():
		for key in _transient_diagnostic:
			snapshot[key] = _transient_diagnostic[key]
	return snapshot


func _log_blocked_notice_once() -> void :
	if _blocked_notice_logged:
		return
	_blocked_notice_logged = true
	if log_buffer and not connect_block_reason.is_empty():
		log_buffer.log(connect_block_reason)


func _send_auth_hello() -> void :
	_handshake_started_msec = maxi(1, Time.get_ticks_msec())
	if not _is_lower_hex_64(auth_token):
		_fail_handshake(
			CLOSE_CODE_AUTH_FAILED, 
			"missing v4 editor capability; restart the managed server from Godot", 
		)
		return
	var nonce_bytes: = Crypto.new().generate_random_bytes(32)
	if nonce_bytes.size() != 32:
		_fail_handshake(CLOSE_CODE_AUTH_FAILED, "could not generate v4 client nonce")
		return
	_client_nonce = nonce_bytes.hex_encode()
	if not _send_json(_build_auth_hello(_client_nonce), true):
		_fail_handshake(CLOSE_CODE_AUTH_FAILED, "could not send v4 auth hello")


static func _build_auth_hello(client_nonce: String) -> Dictionary:
	return {
		"type": "auth_hello", 
		"protocol_version": WS_PROTOCOL_VERSION, 
		"client_nonce": client_nonce, 
	}


func _handle_auth_challenge(parsed: Dictionary) -> void :
	if _server_verified or parsed.get("protocol_version") != WS_PROTOCOL_VERSION:
		_fail_handshake(
			CLOSE_CODE_PROTOCOL_MISMATCH, 
			"Godot AI v4 WebSocket protocol %d required" % WS_PROTOCOL_VERSION, 
		)
		return
	var expected_keys: Array[String] = [
		"type", 
		"protocol_version", 
		"client_nonce", 
		"server_nonce", 
		"server_version", 
		"server_proof", 
	]
	if (
		not _has_exact_keys(parsed, expected_keys)
		or parsed.get("type") != "auth_challenge"
		or parsed.get("client_nonce") != _client_nonce
		or not _is_lower_hex_64(parsed.get("server_nonce"))
		or not _is_lower_hex_64(parsed.get("server_proof"))
		or not _is_bounded_text(parsed.get("server_version"), 64)
	):
		_fail_handshake(CLOSE_CODE_AUTH_FAILED, "invalid v4 server challenge")
		return
	var expected_proof: = _server_proof(
		auth_token, 
		_client_nonce, 
		str(parsed["server_nonce"]), 
		str(parsed["server_version"]), 
	)
	if not _constant_time_equal(str(parsed["server_proof"]), expected_proof):
		_fail_handshake(CLOSE_CODE_AUTH_FAILED, "v4 server proof failed")
		return


	_server_nonce = str(parsed["server_nonce"])
	_challenged_server_version = str(parsed["server_version"])
	_server_verified = true
	_last_readiness = get_readiness()
	var response: = _build_auth_response()
	if response.is_empty() or not _send_json(response, true):
		_fail_handshake(CLOSE_CODE_AUTH_FAILED, "could not send v4 editor proof")
		return
	_auth_response_sent = true


func _build_auth_response() -> Dictionary:
	var godot_version: = str(Engine.get_version_info().get("string", "unknown"))
	var project_path: = ProjectSettings.globalize_path("res://")
	var plugin_version: = ClientConfigurator.get_plugin_version()
	var launch_mode: = ClientConfigurator.get_server_launch_mode()
	var editor_pid: = OS.get_process_id()
	if (
		not _is_bounded_text(_session_id, 128)
		or not _is_bounded_text(godot_version, 64)
		or not _is_bounded_text(project_path, 4096)
		or not _is_bounded_text(plugin_version, 64)
		or not _is_bounded_text(launch_mode, 32)
		or _last_readiness not in ["ready", "importing", "playing", "no_scene"]
		or editor_pid < 0
	):
		return {}
	var client_proof: = _client_proof(
		auth_token, 
		_client_nonce, 
		_server_nonce, 
		_challenged_server_version, 
		_session_id, 
		godot_version, 
		project_path, 
		plugin_version, 
		_last_readiness, 
		editor_pid, 
		launch_mode, 
	)
	if not _is_lower_hex_64(client_proof):
		return {}
	return {
		"type": "auth_response", 
		"protocol_version": WS_PROTOCOL_VERSION, 
		"client_nonce": _client_nonce, 
		"server_nonce": _server_nonce, 
		"client_proof": client_proof, 
		"session_id": _session_id, 
		"godot_version": godot_version, 
		"project_path": project_path, 
		"plugin_version": plugin_version, 
		"readiness": _last_readiness, 
		"editor_pid": editor_pid, 
		"server_launch_mode": launch_mode, 
	}







func _classify_message(raw: String) -> Dictionary:
	var parsed = JSON.parse_string(raw)
	if parsed == null:
		push_warning("MCP: failed to parse websocket JSON")
		return {"kind": "ignore", "parsed": null}
	if not (parsed is Dictionary):
		return {"kind": "ignore", "parsed": null}
	if parsed.get("type", "") == "auth_challenge":
		return {"kind": "challenge", "parsed": parsed}
	if parsed.get("type", "") == "handshake_ack":
		return {"kind": "ack", "parsed": parsed}
	if parsed.has("request_id") and parsed.has("command"):
		if (
			parsed.get("request_id") is String
			and parsed.get("command") is String
			and ( not parsed.has("params") or parsed.get("params") is Dictionary)
		):
			return {"kind": "command", "parsed": parsed}
		return {"kind": "malformed_command", "parsed": parsed}
	return {"kind": "ignore", "parsed": parsed}


func _handle_message(raw: String) -> void :
	if not _handshake_complete and raw.to_utf8_buffer().size() > MAX_HANDSHAKE_FRAME_BYTES:
		_fail_handshake(CLOSE_CODE_PROTOCOL_MISMATCH, "v4 handshake frame too large")
		return
	var classified: = _classify_message(raw)
	if not _handshake_complete:
		match classified["kind"]:
			"challenge":
				_handle_auth_challenge(classified["parsed"])
			"ack":
				_handle_handshake_ack(classified["parsed"])
			_:
				_fail_handshake(
					CLOSE_CODE_PROTOCOL_MISMATCH, 
					"Godot AI v4 expected auth_challenge or handshake_ack", 
				)
		return
	match classified["kind"]:
		"challenge", "ack":
			_fail_handshake(CLOSE_CODE_PROTOCOL_MISMATCH, "unexpected v4 handshake frame")
		"command":
			if dispatcher:
				dispatcher.enqueue(classified["parsed"])
		"malformed_command":
			_reply_malformed_command(classified["parsed"])


func _handle_handshake_ack(parsed: Dictionary) -> void :
	var expected_keys: Array[String] = ["type", "protocol_version", "server_version"]
	if (
		_handshake_complete
		or not _server_verified
		or not _auth_response_sent
		or not _has_exact_keys(parsed, expected_keys)
		or parsed.get("type") != "handshake_ack"
		or parsed.get("protocol_version") != WS_PROTOCOL_VERSION
		or parsed.get("server_version") != _challenged_server_version
	):
		_fail_handshake(CLOSE_CODE_AUTH_FAILED, "invalid v4 handshake ACK")
		return
	server_version = _challenged_server_version
	_handshake_complete = true
	_reconnect_attempt = 0


	_last_scene_path = ""
	_last_play_state = false
	_transient_diagnostic.clear()
	if log_buffer:
		log_buffer.log("authenticated with server")
	connection_state_changed.emit(true)


func _fail_handshake(code: int, reason: String) -> void :
	if log_buffer:
		log_buffer.log("v4 websocket handshake failed: %s" % reason)
	_peer.close(code, reason)


static func _has_exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func _is_bounded_text(value: Variant, max_length: int) -> bool:
	return value is String and not String(value).is_empty() and String(value).length() <= max_length


static func _is_lower_hex_64(value: Variant) -> bool:
	if not (value is String) or String(value).length() != 64:
		return false
	for character in String(value):
		if not (character >= "0" and character <= "9") and not (
			character >= "a" and character <= "f"
		):
			return false
	return true


static func _proof_message(domain: String, values: Array) -> PackedByteArray:
	var message: = domain.to_utf8_buffer()
	for value in values:
		var encoded: = str(value).to_utf8_buffer()
		message.append_array(("\n%d:" % encoded.size()).to_utf8_buffer())
		message.append_array(encoded)
	return message


static func _hmac_proof(capability: String, domain: String, values: Array) -> String:
	if not _is_lower_hex_64(capability):
		return ""
	var context: = HMACContext.new()
	if context.start(HashingContext.HASH_SHA256, capability.to_utf8_buffer()) != OK:
		return ""
	if context.update(_proof_message(domain, values)) != OK:
		return ""
	return context.finish().hex_encode()


static func _server_proof(
	capability: String, 
	client_nonce: String, 
	server_nonce: String, 
	server_version_value: String, 
) -> String:
	return _hmac_proof(
		capability, 
		_SERVER_PROOF_DOMAIN, 
		[WS_PROTOCOL_VERSION, client_nonce, server_nonce, server_version_value], 
	)


static func _client_proof(
	capability: String, 
	client_nonce: String, 
	server_nonce: String, 
	server_version_value: String, 
	session_id: String, 
	godot_version: String, 
	project_path: String, 
	plugin_version: String, 
	readiness: String, 
	editor_pid: int, 
	server_launch_mode: String, 
) -> String:
	return _hmac_proof(
		capability, 
		_CLIENT_PROOF_DOMAIN, 
		[
			WS_PROTOCOL_VERSION, 
			client_nonce, 
			server_nonce, 
			server_version_value, 
			session_id, 
			godot_version, 
			project_path, 
			plugin_version, 
			readiness, 
			editor_pid, 
			server_launch_mode, 
		], 
	)


static func _constant_time_equal(left: String, right: String) -> bool:
	var difference: = left.length() ^ right.length()
	var length: = maxi(left.length(), right.length())
	for index in length:
		var left_code: = left.unicode_at(index) if index < left.length() else 0
		var right_code: = right.unicode_at(index) if index < right.length() else 0
		difference |= left_code ^ right_code
	return difference == 0







func _reply_malformed_command(parsed: Dictionary) -> void :
	push_warning("MCP: dropping malformed command frame (request_id/command must be String, params a Dictionary)")
	var rid: Variant = parsed.get("request_id")
	if rid is String and not String(rid).is_empty():
		var response: = ErrorCodes.make(
			ErrorCodes.INVALID_PARAMS, 
			"Malformed command frame: request_id/command must be strings and params a dict"
		)
		response["request_id"] = rid
		response["readiness"] = get_readiness()
		_stamp_error_watermark(response)
		_send_json(response)



func send_event(event_name: String, data: Dictionary = {}) -> bool:
	return _send_json({"type": "event", "event": event_name, "data": data})





func send_deferred_response(request_id: String, payload: Dictionary) -> void :
	if dispatcher != null and not dispatcher.has_pending_deferred_response(request_id):
		if log_buffer:
			log_buffer.log("[defer] dropped late response for expired request %s" % request_id)
		return
	var response: = payload.duplicate()
	response["request_id"] = request_id
	if not response.has("status"):
		response["status"] = "ok" if payload.has("data") else "error"





	if not response.has("readiness"):
		response["readiness"] = get_readiness()
	if not response.has("error_watermark"):
		_stamp_error_watermark(response)
	if _send_json(response) and dispatcher != null:
		dispatcher.complete_deferred_response(request_id)






enum ServiceStatus{SERVICED, DISCONNECTED, PAUSED, BLOCKED}








const EXCLUSIVE_RUN_PACKET_CAP: = 2048
const CLOSE_CODE_EXCLUSIVE_RUN_FLOOD: = 1013

const _SERVICE_REJECT_LOG_FIRST: = 5
const _SERVICE_REJECT_LOG_EVERY: = 100




















func service_transport_during_exclusive_run(run_state: Dictionary) -> ServiceStatus:
	if connect_blocked:
		return ServiceStatus.BLOCKED
	if pause_processing:
		return ServiceStatus.PAUSED
	while true:
		_peer.poll()
		if _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
			return ServiceStatus.DISCONNECTED
		if _peer.get_available_packet_count() == 0:
			return ServiceStatus.SERVICED
		while _peer.get_available_packet_count() > 0:
			var raw: String = _peer.get_packet().get_string_from_utf8()
			if _service_note_packet(run_state):
				if log_buffer:
					log_buffer.log(
						"[busy] packet flood during test run (%d > cap %d) — closing connection"
						%[int(run_state.get("packets_serviced", 0)), EXCLUSIVE_RUN_PACKET_CAP]
					)
				_peer.close(CLOSE_CODE_EXCLUSIVE_RUN_FLOOD, "command flood during test run")
				return ServiceStatus.DISCONNECTED
			_service_handle_message(raw, int(run_state.get("packets_serviced", 0)))

	return ServiceStatus.SERVICED










static func exclusive_run_checkpoint(
	service_cb: Callable, deadline_ticks_ms: int, run_state: Dictionary
) -> String:
	if deadline_ticks_ms > 0 and Time.get_ticks_msec() >= deadline_ticks_ms:
		return "timeout"
	if not service_cb.is_valid():
		return ""
	var status: int = service_cb.call(run_state)
	if status == ServiceStatus.SERVICED:
		return ""
	if status == ServiceStatus.PAUSED:
		return "paused"
	return "transport_lost"






static func _service_note_packet(run_state: Dictionary) -> bool:
	var count: int = int(run_state.get("packets_serviced", 0)) + 1
	run_state["packets_serviced"] = count
	return count > EXCLUSIVE_RUN_PACKET_CAP





func _service_handle_message(raw: String, packets_serviced: int) -> void :
	var classified: = _classify_message(raw)
	match classified["kind"]:
		"challenge", "ack":
			_fail_handshake(CLOSE_CODE_PROTOCOL_MISMATCH, "unexpected v4 handshake frame")
		"command":
			_service_reject_command(classified["parsed"], packets_serviced)
		"malformed_command":
			_reply_malformed_command(classified["parsed"])


func _service_reject_command(parsed: Dictionary, packets_serviced: int) -> void :
	_send_json(_build_service_reject(parsed))
	if log_buffer and (
		packets_serviced <= _SERVICE_REJECT_LOG_FIRST
		or packets_serviced % _SERVICE_REJECT_LOG_EVERY == 0
	):

		log_buffer.log(
			"[busy] rejected '%s' during test run (packet %d)"
			%[parsed.get("command", ""), packets_serviced], 
			false, 
		)




func _build_service_reject(parsed: Dictionary) -> Dictionary:
	var command: String = parsed.get("command", "")
	var response: = ErrorCodes.make_not_ready(
		ErrorCodes.SUB_EDITOR_TEST_RUNNING, 
		(
			"A test run is in progress on this editor — '%s' was not executed. "
			+ "Retry when the run completes, or fetch results afterward with "
			+ "test_manage(op=\"results_get\")."
		) % command, 
		true, 
	)
	response["request_id"] = parsed.get("request_id", "")
	response["readiness"] = get_readiness()
	_stamp_error_watermark(response)
	return response


func _hook_editor_signals() -> void :


	EditorInterface.get_editor_settings()
	_last_scene_path = _get_current_scene_path()
	_last_play_state = EditorInterface.is_playing_scene()
	_last_play_state_for_run = _last_play_state


var _last_scene_path: = ""
var _last_play_state: = false



var _last_play_state_for_run: = false
var _last_readiness: = ""



static func get_readiness() -> String:
	if EditorInterface.get_resource_filesystem().is_scanning():
		return "importing"
	if EditorInterface.is_playing_scene():
		return "playing"
	if EditorInterface.get_edited_scene_root() == null:
		return "no_scene"
	return "ready"



func _check_state_changes() -> void :
	var scene_path: = _get_current_scene_path()
	if scene_path != _last_scene_path:
		if send_event("scene_changed", {"current_scene": scene_path}):
			_last_scene_path = scene_path
			if log_buffer:
				log_buffer.log("[event] scene_changed -> %s" % scene_path)

	var playing: = EditorInterface.is_playing_scene()
	if playing != _last_play_state:
		var state: = "playing" if playing else "stopped"
		if send_event("play_state_changed", {"play_state": state}):
			_last_play_state = playing
			if log_buffer:
				log_buffer.log("[event] play_state_changed -> %s" % state)

	var readiness: = get_readiness()
	if readiness != _last_readiness:
		if send_event("readiness_changed", {"readiness": readiness}):
			_last_readiness = readiness
			if log_buffer:




				log_buffer.log("[event] readiness -> %s" % readiness, false)






func _check_game_run_play_state(playing: bool) -> void :
	if playing == _last_play_state_for_run:
		return
	if debugger_plugin != null:
		if playing:






			debugger_plugin.note_editor_play_started()
		else:
			debugger_plugin.note_editor_play_stopped()
	_last_play_state_for_run = playing


func _get_current_scene_path() -> String:
	var scene_root: = EditorInterface.get_edited_scene_root()
	return scene_root.scene_file_path if scene_root else ""


func _send_json(data: Dictionary, allow_pre_auth: = false) -> bool:
	if not _connected or ( not _handshake_complete and not allow_pre_auth):
		return false
	var text: = JSON.stringify(data)
	if allow_pre_auth and text.to_utf8_buffer().size() > MAX_HANDSHAKE_FRAME_BYTES:
		return false
	var buffered_bytes: = _peer.get_current_outbound_buffered_amount()





	if _might_exceed_outbound_backpressure(buffered_bytes, text.length()):
		var message_bytes: = text.to_utf8_buffer().size()
		if _would_exceed_outbound_backpressure(buffered_bytes, message_bytes):
			return _handle_outbound_backpressure(data, buffered_bytes, message_bytes)
	var err: = _peer.send_text(text)
	if err != OK:
		if log_buffer:
			log_buffer.log("[send] websocket send_text failed: %s" % error_string(err))
		return false
	return true


static func _would_exceed_outbound_backpressure(buffered_bytes: int, message_bytes: int) -> bool:
	return buffered_bytes + message_bytes > OUTBOUND_BUFFER_LIMIT_BYTES






static func _might_exceed_outbound_backpressure(buffered_bytes: int, char_count: int) -> bool:
	return buffered_bytes + char_count * 4 > OUTBOUND_BUFFER_LIMIT_BYTES


func _handle_outbound_backpressure(
	data: Dictionary, 
	buffered_bytes: int, 
	message_bytes: int, 
) -> bool:
	var request_id: String = data.get("request_id", "")
	if request_id.is_empty():
		if log_buffer:
			log_buffer.log(
				"[send] requestless payload blocked by websocket backpressure "
				+ "(buffered=%d, message=%d, limit=%d)"
				%[buffered_bytes, message_bytes, OUTBOUND_BUFFER_LIMIT_BYTES]
			)
		return false

	var err_response: = _make_backpressure_error(request_id, buffered_bytes, message_bytes)
	_stamp_error_watermark(err_response)
	var err_text: = JSON.stringify(err_response)
	var err_bytes: = err_text.to_utf8_buffer().size()
	if _would_exceed_outbound_backpressure(buffered_bytes, err_bytes):
		if log_buffer:
			log_buffer.log(
				"[send] dropped response for request %s due to websocket backpressure "
				+ "(buffered=%d, message=%d, limit=%d)"
				%[request_id, buffered_bytes, message_bytes, OUTBOUND_BUFFER_LIMIT_BYTES]
			)
		return false

	var send_err: = _peer.send_text(err_text)
	if send_err != OK:
		if log_buffer:
			log_buffer.log("[send] websocket backpressure error send failed: %s" % error_string(send_err))
		return false
	if log_buffer:
		log_buffer.log(
			"[send] %s -> error: outbound websocket backpressure"
			%data.get("command", "response")
		)
	return true


static func _make_backpressure_error(
	request_id: String, 
	buffered_bytes: int, 
	message_bytes: int, 
) -> Dictionary:
	return {
		"request_id": request_id, 
		"status": "error", 
		"data": {}, 




		"readiness": get_readiness(), 
		"error": {
			"code": ErrorCodes.INTERNAL_ERROR, 
			"message": (
				"Outbound WebSocket buffer is full; dropped response before queueing "
				+ "more data. Retry with a smaller payload (for screenshots, lower "
				+ "max_resolution or set include_image=false)."
			), 
			"data": {
				"buffered_bytes": buffered_bytes, 
				"message_bytes": message_bytes, 
				"limit_bytes": OUTBOUND_BUFFER_LIMIT_BYTES, 
			}, 
		}, 
	}


func _stamp_error_watermark(response: Dictionary) -> void :
	McpSurfacedErrorTracker.stamp_watermark(response, surfaced_error_tracker)





static func _make_session_id(project_path: String) -> String:
	var base: = project_path.rstrip("/\\").get_file()
	if base == "":
		base = "project"
	var slug: = _slugify(base)
	if slug == "":
		slug = "project"
	var random_bytes: = Crypto.new().generate_random_bytes(8)
	if random_bytes.size() != 8:
		return ""
	var suffix: = random_bytes.hex_encode()
	return "%s@%s" % [slug, suffix]


static func _slugify(s: String) -> String:
	var out: = ""
	var prev_dash: = false
	for c in s.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
			prev_dash = false
		elif not prev_dash and out != "":
			out += "-"
			prev_dash = true
	return out.trim_suffix("-")


static func _should_regenerate_session_id(
	close_code: int, 
	server_verified: bool, 
	handshake_complete: bool, 
) -> bool:



	return (
		close_code == CLOSE_CODE_DUPLICATE_SESSION
		and server_verified
		and not handshake_complete
	)
