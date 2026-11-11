@tool
class_name McpAllowHosts
extends RefCounted



















static func normalize(raw: String) -> String:
	var parts: = PackedStringArray()
	for p in raw.split(","):
		var t: = p.strip_edges()
		if not t.is_empty() and parts.find(t) == -1:
			parts.append(t)
	parts.sort()
	return ",".join(parts)



static func token_is_valid(token: String) -> bool:
	var t: = token.strip_edges()
	if t.is_empty():
		return false
	var ip: = t
	var prefix: = 0



	var has_prefix: = false
	var slash: = t.find("/")
	if slash != -1:
		ip = t.substr(0, slash)
		var prefix_text: = t.substr(slash + 1)



		if prefix_text.is_empty() or prefix_text.begins_with("+") or prefix_text.begins_with("-"):
			return false
		if not prefix_text.is_valid_int():
			return false
		prefix = int(prefix_text)
		has_prefix = true
	if not ip.is_valid_ip_address():
		return false
	var max_prefix: = 128 if ip.contains(":") else 32
	return not has_prefix or (prefix >= 0 and prefix <= max_prefix)




static func invalid_tokens(raw: String) -> PackedStringArray:
	var bad: = PackedStringArray()
	for p in raw.split(","):
		var t: = p.strip_edges()
		if t.is_empty():
			continue
		if not token_is_valid(t) and bad.find(t) == -1:
			bad.append(t)
	return bad





static func is_lan_allowlist_active(value: String) -> bool:
	for p in value.split(","):
		var t: = p.strip_edges()
		if t.is_empty():
			continue
		var ip: = t.substr(0, t.find("/")) if t.contains("/") else t
		if not _is_loopback(ip):
			return true
	return false









static func pick_lan_address(addresses: PackedStringArray) -> Dictionary:
	var candidates: = PackedStringArray()
	for a in addresses:
		var addr: = String(a).strip_edges()
		if addr.is_empty() or _is_loopback(addr) or _is_link_local(addr):
			continue
		candidates.append(addr)
	if candidates.is_empty():
		return {"address": "", "ambiguous": false}
	var chosen: = ""
	for addr in candidates:
		if _is_private_ipv4(addr):
			chosen = addr
			break
	if chosen.is_empty():
		for addr in candidates:
			if addr.contains("."):
				chosen = addr
				break
	if chosen.is_empty():
		chosen = candidates[0]
	return {"address": chosen, "ambiguous": candidates.size() > 1}






static func lan_url_note(allow_hosts_value: String, addresses: PackedStringArray, http_port: int) -> String:
	if not is_lan_allowlist_active(allow_hosts_value):
		return ""
	var pick: = pick_lan_address(addresses)
	var addr: = String(pick.get("address", ""))
	if addr.is_empty():
		return (
			"LAN access is enabled (--allow-host %s), but no LAN address was detected on this machine."
			%allow_hosts_value
		)
	var host: = "[%s]" % addr if addr.contains(":") else addr
	var note: = (
		"LAN access is enabled (--allow-host %s). Remote agents on the allowed network can use: http://%s:%d/mcp"
		%[allow_hosts_value, host, http_port]
	)
	if bool(pick.get("ambiguous", false)):
		note += "\n(multiple network interfaces detected — pick the address on the network you allowed)"
	return note


static func _is_loopback(addr: String) -> bool:
	var a: = addr.to_lower()
	return a.begins_with("127.") or a == "::1" or a == "localhost"


static func _is_link_local(addr: String) -> bool:
	var a: = addr.to_lower()
	if a.begins_with("169.254."):
		return true



	if a.length() >= 4 and a.begins_with("fe") and a[2] in "89ab":
		return true
	return false


static func _is_private_ipv4(addr: String) -> bool:
	if not addr.contains("."):
		return false
	if addr.begins_with("10.") or addr.begins_with("192.168."):
		return true
	if addr.begins_with("172."):
		var second: = int(addr.get_slice(".", 1))
		return second >= 16 and second <= 31
	return false



static func configuration_error(raw: String, platform: String = OS.get_name()) -> String:
	var invalid: = invalid_tokens(raw)
	if not invalid.is_empty():
		return "Invalid entries (must be a CIDR or bare IP, comma-separated): %s" % ", ".join(invalid)
	var value: = normalize(raw)
	if platform != "Windows" or value.is_empty():
		return ""
	for token in value.split(","):
		if not token.contains(":"):
			return ""
	return "IPv6-only remote access is unsupported on Windows: the editor and attach bridge require IPv4 loopback. Use an IPv4 allowlist or clear Allow remote hosts to disable remote access. Full IPv6 support is tracked in #1072."
