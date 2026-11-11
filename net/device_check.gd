class_name DeviceCheck
extends RefCounted









const TXT_MISSING: String = "Вход с этого устройства недоступен: нужна версия для iPhone или Android"
const TXT_FAIL: String = "Не удалось проверить устройство. Проверьте интернет и попробуйте ещё раз"
const KEY_FILE: String = "user://attest.bin"


static func dev() -> Object:
	return Engine.get_singleton("DFDevice") if Engine.has_singleton("DFDevice") else null


static func available() -> bool:
	var d: Object = dev()
	if d == null:
		return false
	return OS.get_name() == "Android" or bool(d.call("attest_supported"))




static func headers(hash: PackedByteArray, assertion_only: bool) -> Dictionary:
	if available() and OS.get_name() == "Android":
		return await _android(hash)
	if available():
		return await _ios(hash, assertion_only)
	return {"ok": true, "headers": PackedStringArray(), "err": ""}


static func _ios(hash: PackedByteArray, assertion_only: bool) -> Dictionary:
	var r: Dictionary = await _ios_once(hash, assertion_only)
	if bool(r["ok"]) or assertion_only or not bool(r.get("stale", false)):
		return r



	return await _ios_once(hash, false)



static func _ios_once(hash: PackedByteArray, assertion_only: bool) -> Dictionary:
	var p: Object = dev()
	var st: Dictionary = _key_state()
	var stored: bool = String(st.get("key", "")) != ""
	if not stored:
		if assertion_only:
			return {"ok": false, "headers": PackedStringArray(), "err": TXT_FAIL}
		p.call("generate_key")
		var g: Array = await p.done
		if not bool(g[0]):
			print("[DeviceCheck] App Attest: no new key: %s" % String(g[3]))
			return {"ok": false, "headers": PackedStringArray(), "err": TXT_FAIL}
		st = {"key": String(g[1]), "attested": false}
		_save_key(st)
	var attested: bool = bool(st.get("attested", false))
	p.call("assertion" if attested else "attest", String(st["key"]), hash)
	var r: Array = await p.done
	if not bool(r[0]):
		print("[DeviceCheck] App Attest %s refused: %s" % ["assertion" if attested else "attestation", String(r[3])])
		_save_key({})
		return {"ok": false, "headers": PackedStringArray(), "err": TXT_FAIL, "stale": stored}
	var h: = PackedStringArray(["X-App-Attest-Key-Id: " + String(st["key"])])
	h.append(("X-App-Attest-Assertion: " if attested else "X-App-Attest-Attestation: ") + String(r[2]))
	return {"ok": true, "headers": h, "err": ""}










const KEY_KEPT: Array = [200, 201, 401, 409]


static func key_accepted(code: int) -> void :
	var st: Dictionary = _key_state()
	if st.is_empty():
		return
	if code == 429:
		_save_key({})
	elif KEY_KEPT.has(code):
		st["attested"] = true
		_save_key(st)


static func _android(hash: PackedByteArray) -> Dictionary:
	var p: Object = dev()
	var nonce: String = Marshalls.raw_to_base64(hash).replace("+", "-").replace("/", "_").replace("=", "")
	NetConfig.load_cfg()
	p.call("integrity_request", nonce, NetConfig.gcp_project)
	var r: Array = await p.done
	if not bool(r[0]):
		return {"ok": false, "headers": PackedStringArray(), "err": TXT_FAIL}
	return {"ok": true, "headers": PackedStringArray(["X-Play-Integrity-Token: " + String(r[2])]), "err": ""}



static func _key_state() -> Dictionary:
	var d: Variant = secure_load("attest", KEY_FILE, "|df-attest")
	return d if d is Dictionary else {}


static func _save_key(d: Dictionary) -> void :
	secure_store("attest", d, KEY_FILE, "|df-attest")




static func secure_load(key: String, file: String, salt: String) -> Variant:
	var d: Object = dev()
	if d != null:
		var s: String = String(d.call("secure_get", key))
		if s != "":
			return bytes_to_var(Marshalls.base64_to_raw(s))
	var f: FileAccess = FileAccess.open_encrypted_with_pass(file, FileAccess.READ, (OS.get_unique_id() + salt).sha256_text())
	if f == null:
		return null
	var v: Variant = f.get_var()
	f.close()
	if d != null and v != null and bool(d.call("secure_set", key, Marshalls.raw_to_base64(var_to_bytes(v)))):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	return v


static func secure_store(key: String, v: Variant, file: String, salt: String) -> void :
	var d: Object = dev()
	if d != null and bool(d.call("secure_set", key, Marshalls.raw_to_base64(var_to_bytes(v)))):
		return
	var f: FileAccess = FileAccess.open_encrypted_with_pass(file, FileAccess.WRITE, (OS.get_unique_id() + salt).sha256_text())
	if f != null:
		f.store_var(v)
		f.close()
