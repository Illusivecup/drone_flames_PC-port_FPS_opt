class_name SocialLink
extends RefCounted

signal state_changed
signal received(result: Dictionary)

var state: Dictionary = {}
var ready: bool = false
var error_text: String = ""
var _socket: WebSocketPeer
var _session: String = ""
var _poll_at: int = 0
var _retry_at: int = 0
var _deadline: int = 0
var _room: String = ""


func tick(room: String) -> void:
	var session: String = Account.access
	var now: int = Time.get_ticks_msec()
	if session != _session:
		_disconnect()
		_session = session
		error_text = ""
		_retry_at = 0
	if session == "":
		return
	if _socket == null:
		if now < _retry_at:
			return
		_socket = WebSocketPeer.new()
		_socket.inbound_buffer_size = 4 * 1024 * 1024
		_deadline = now + 8000
		if _socket.connect_to_url(NetConfig.signal_url, NetTls.for_url(NetConfig.signal_url)) != OK:
			_fail("Не удалось подключиться к серверу")
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if _deadline != 0:
				_socket.send_text(JSON.stringify({"t": "auth_token", "token": session, "subscribe": true, "v": NetConfig.version()}))
				_deadline = 0
				_poll_at = now + 8000
			while _socket.get_available_packet_count() > 0:
				var packet: Variant = JSON.parse_string(_socket.get_packet().get_string_from_utf8())
				if packet is Dictionary:
					_handle(packet)
			if ready and (now >= _poll_at or room != _room):
				_room = room
				send("state", {"room": room, "roster_version": state.get("roster_version", "")})
				_poll_at = now + 3000
				Account.retry_pending_stats()
			elif not ready and now >= _poll_at:
				_fail("Сервер не ответил вовремя")
		WebSocketPeer.STATE_CLOSED, WebSocketPeer.STATE_CLOSING:
			_fail("Связь с сервером прервалась")
		WebSocketPeer.STATE_CONNECTING:
			if now >= _deadline:
				_fail("Сервер не ответил вовремя")


func _handle(packet: Dictionary) -> void:
	match packet.get("t"):
		"auth_ok":
			error_text = ""
			ready = true
			Account._accept_user(packet)
			Account.sync_pending_stats()
			_poll_at = 0
			state_changed.emit()
		"auth_fail":
			Account.lost_session()
		"social_changed":
			_poll_at = 0
		"social_result":
			if packet.get("action") == "state":
				if not packet.has("roster"):
					packet["roster"] = state.get("roster", {})
				if state.get("profile_version", "") != "" and packet.get("profile_version") != state.get("profile_version"):
					Account.fetch_info()
				packet["received_at"] = Time.get_ticks_msec()
				state = packet
				state_changed.emit()
			else:
				received.emit(packet)


func retry() -> void:
	error_text = ""
	_disconnect()
	_retry_at = 0
	state_changed.emit()


func _fail(message: String) -> void:
	var was_ready: bool = ready
	var changed: bool = error_text != message
	error_text = message
	_disconnect()
	if changed and not was_ready:
		state_changed.emit()


func _disconnect() -> void:
	if _socket != null:
		_socket.close()
		_socket = null
	_retry_at = Time.get_ticks_msec() + 3000
	if ready or not state.is_empty():
		ready = false
		state = {}
		state_changed.emit()


func send(action: String, data: Dictionary = {}) -> bool:
	if not ready:
		return false
	return _socket.send_text(JSON.stringify({"t": "social", "action": action}.merged(data))) == OK
