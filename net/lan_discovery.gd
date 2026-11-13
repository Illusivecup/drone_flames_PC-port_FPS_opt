class_name LanDiscovery
extends Node







signal rooms_changed

const SCAN_EVERY: float = 3.0
const SCAN_PER_FRAME: int = 64
const ROOM_TTL: float = 7.0

var rooms: Dictionary = {}
var _udp: PacketPeerUDP = null
var _host_info: Dictionary = {}
var _t: float = 0.0
var _clock: float = 0.0
var _targets: PackedStringArray = []
var _scan_t: float = 0.0
var scanning: bool = false



func announce(info: Dictionary) -> void :
	stop()
	_host_info = info.duplicate()
	_udp = PacketPeerUDP.new()
	var err: int = _udp.bind(NetConfig.BEACON_PORT)
	if err != OK:
		push_warning("[Net] LAN query port %d busy (%s)" % [NetConfig.BEACON_PORT, error_string(err)])
	if not OS.has_feature("ios"):
		_udp.set_broadcast_enabled(true)
	_t = 0.0


func update_info(info: Dictionary) -> void :
	_host_info.merge(info, true)



func browse() -> void :
	stop()
	rooms.clear()
	_udp = PacketPeerUDP.new()
	if _udp.bind(NetConfig.BROWSE_PORT) != OK:
		_udp.bind(0)
	scanning = true
	_scan_t = 0.0
	_targets = PackedStringArray()


func stop() -> void :
	if _udp != null:
		_udp.close()
	_udp = null
	_host_info = {}
	scanning = false
	_targets = PackedStringArray()



static func sweep_targets() -> PackedStringArray:
	var out: = PackedStringArray(["127.0.0.1"])
	var nets: Dictionary = {}
	for a: String in IP.get_local_addresses():
		if a.count(".") != 3:
			continue
		if not (a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("26.") or a.begins_with("25.") or _is_172_private(a)):
			continue
		nets[a.substr(0, a.rfind("."))] = true
	for n: String in nets:
		for i in range(1, 255):
			out.append("%s.%d" % [n, i])
	return out


static func _is_172_private(a: String) -> bool:
	if not a.begins_with("172."):
		return false
	var b: int = int(a.get_slice(".", 1))
	return b >= 16 and b <= 31


func _process(delta: float) -> void :
	_clock += delta
	if _udp == null:
		return
	if not _host_info.is_empty():
		_host_tick(delta)
		return
	_browse_tick(delta)


func _twin(ip: String, r: Dictionary) -> String:
	for other: String in rooms:
		if other == ip or (other != "127.0.0.1" and ip != "127.0.0.1"):
			continue
		var o: Dictionary = rooms[other]
		if int(o.get("port", 0)) == int(r.get("port", -1)) and String(o.get("name", "")) == String(r.get("name", "")):
			return other
	return ""


func _info_packet() -> PackedByteArray:
	var msg: Dictionary = {"df": "DroneFlames", "v": NetConfig.version()}
	msg.merge(_host_info)
	return JSON.stringify(msg).to_utf8_buffer()


func _host_tick(delta: float) -> void :
	while _udp.get_available_packet_count() > 0:
		var q: PackedByteArray = _udp.get_packet()
		if q.get_string_from_utf8() != "DF?":
			continue
		_udp.set_dest_address(_udp.get_packet_ip(), _udp.get_packet_port())
		_udp.put_packet(_info_packet())
	if OS.has_feature("ios") or NetConfig.test_no_broadcast:
		return
	_t -= delta
	if _t <= 0.0:
		_t = 1.0
		_udp.set_dest_address("255.255.255.255", NetConfig.BROWSE_PORT)
		_udp.put_packet(_info_packet())
		for a: String in IP.get_local_addresses():
			if a.begins_with("26."):
				_udp.set_dest_address("26.255.255.255", NetConfig.BROWSE_PORT)
				_udp.put_packet(_info_packet())
			elif a.begins_with("25."):
				_udp.set_dest_address("25.255.255.255", NetConfig.BROWSE_PORT)
				_udp.put_packet(_info_packet())


func _browse_tick(delta: float) -> void :
	if scanning:
		_scan_t -= delta
		if _scan_t <= 0.0 and _targets.is_empty():
			_scan_t = SCAN_EVERY
			_targets = sweep_targets()
		var q: PackedByteArray = "DF?".to_utf8_buffer()
		if _targets.size() == sweep_targets().size() or _scan_t >= SCAN_EVERY - 0.2:
			_udp.set_dest_address("255.255.255.255", NetConfig.BEACON_PORT)
			_udp.put_packet(q)
			for a: String in IP.get_local_addresses():
				if a.begins_with("26."):
					_udp.set_dest_address("26.255.255.255", NetConfig.BEACON_PORT)
					_udp.put_packet(q)
				elif a.begins_with("25."):
					_udp.set_dest_address("25.255.255.255", NetConfig.BEACON_PORT)
					_udp.put_packet(q)
		var n: int = mini(SCAN_PER_FRAME, _targets.size())
		for i in n:
			_udp.set_dest_address(_targets[i], NetConfig.BEACON_PORT)
			_udp.put_packet(q)
		if n > 0:
			_targets = _targets.slice(n)
	var changed: bool = false
	while _udp.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _udp.get_packet()
		var ip: String = _udp.get_packet_ip()
		var d: Variant = JSON.parse_string(pkt.get_string_from_utf8())
		if not (d is Dictionary) or String((d as Dictionary).get("df", "")) != "DroneFlames":
			continue
		var r: Dictionary = d

		var twin: String = _twin(ip, r)
		if twin != "":
			if ip == "127.0.0.1":
				continue
			rooms.erase(twin)
		r["t"] = _clock
		changed = changed or not rooms.has(ip) or int((rooms[ip] as Dictionary).get("n", 0)) != int(r.get("n", 0))
		rooms[ip] = r
	for ip: String in rooms.keys():
		if _clock - float((rooms[ip] as Dictionary)["t"]) > ROOM_TTL:
			rooms.erase(ip)
			changed = true
	if changed:
		rooms_changed.emit()
