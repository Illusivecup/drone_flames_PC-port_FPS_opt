class_name WsTunnelPeer
extends MultiplayerPeerExtension







const PART: int = 65536
const EARLY_MAX_PEERS: int = 8
const EARLY_MAX_PACKETS: int = 256

var _rtc: RtcLink
var _id: int = 0
var _server: bool = false
var _peers: Dictionary = {}
var _in: Array = []
var _cur: Array = []
var _early: Dictionary = {}  # packets can reach the relay peer before the server's peer notification
var _target: int = 0
var _status: int = MultiplayerPeer.CONNECTION_CONNECTED
var _parts: Dictionary = {}
var _seq: int = 0


func _init(rtc: RtcLink, my_id: int, server: bool) -> void :
	_rtc = rtc
	_id = my_id
	_server = server



func add(id: int) -> void :
	if not _peers.has(id):
		_peers[id] = true
		peer_connected.emit(id)
		var pending: Array = _early.get(id, [])
		_early.erase(id)
		for d: Dictionary in pending:
			_receive_known(id, d)


func remove(id: int) -> void :
	if _peers.erase(id):
		peer_disconnected.emit(id)
	_early.erase(id)
	for key: Variant in _parts.keys():
		if String(key).begins_with("%d:" % id):
			_parts.erase(key)


func peer_ids() -> Array:
	return _peers.keys()



func receive(from: int, d: Dictionary) -> void :
	if not _peers.has(from):
		if from < 1 or from > 64 or (not _early.has(from) and _early.size() >= EARLY_MAX_PEERS):
			return
		var pending: Array = _early.get(from, [])
		if pending.size() < EARLY_MAX_PACKETS:
			pending.append(d.duplicate(true))
			_early[from] = pending
		return
	_receive_known(from, d)


func _receive_known(from: int, d: Dictionary) -> void:
	var b64: String = String(d.get("p", ""))
	var n: int = int(d.get("n", 1))
	if n > 1:
		var key: String = "%d:%d" % [from, int(d.get("k", 0))]
		if _parts.size() > 256:
			_parts.clear()
		var e: Dictionary = _parts.get(key, {"n": n, "got": {}})
		(e["got"] as Dictionary)[int(d.get("i", 0))] = b64
		_parts[key] = e
		if (e["got"] as Dictionary).size() < n:
			return
		var whole: String = ""
		for i in n:
			whole += String((e["got"] as Dictionary).get(i, ""))
		_parts.erase(key)
		b64 = whole
	_in.append([from, Marshalls.base64_to_raw(b64)])


func _get_available_packet_count() -> int:
	return _in.size()


func _get_max_packet_size() -> int:
	return 1 << 22


func _get_packet_script() -> PackedByteArray:
	if _in.is_empty():
		return PackedByteArray()
	_cur = _in.pop_front()
	return _cur[1]


func _get_packet_peer() -> int:
	return int(_cur[0]) if not _cur.is_empty() else 0


func _get_packet_channel() -> int:
	return 0


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _put_packet_script(p_buffer: PackedByteArray) -> Error:
	var to: Array = []
	if _target > 0:
		to = [_target]
	elif _target == 0:
		to = [0] if _server else [1]
	else:
		for id: int in _peers:
			if id != - _target:
				to.append(id)
	var b64: String = Marshalls.raw_to_base64(p_buffer)
	_seq += 1
	var n: int = maxi(1, ceili(float(b64.length()) / float(PART)))
	for dest: int in to:
		if not _server and dest != 1:
			continue
		for i in n:
			var d: Dictionary = {"p": b64.substr(i * PART, PART)}
			if n > 1:
				d.merge({"n": n, "i": i, "k": _seq})
			_rtc.send_rpc(dest, d)
	return OK


func _set_target_peer(p_peer: int) -> void :
	_target = p_peer


func _get_unique_id() -> int:
	return _id


func _is_server() -> bool:
	return _server


func _is_server_relay_supported() -> bool:
	return false


func _poll() -> void :
	pass


func _close() -> void :
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	_peers.clear()
	_in.clear()
	_early.clear()
	_parts.clear()


func _disconnect_peer(p_peer: int, _p_force: bool) -> void :
	remove(p_peer)


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status


func _set_transfer_channel(_p_channel: int) -> void :
	pass


func _get_transfer_channel() -> int:
	return 0


func _set_transfer_mode(_p_mode: MultiplayerPeer.TransferMode) -> void :
	pass


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _set_refuse_new_connections(_p_enable: bool) -> void :
	pass


func _is_refusing_new_connections() -> bool:
	return false
