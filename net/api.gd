class_name Api
extends Node
## BACKEND 1: the HTTP client of the DroneFlames backend (docs/BACKEND.md, the backend's
## docs/client-integration.md). One node under the tree root (Api.i()); every call is a coroutine:
##   var r: Dictionary = await Api.i().call_api("GET", "/user/info")
## -> {"code": HTTP code (0 = no network), "data": parsed JSON (or null), "err": text for the player ("" = ok)}.
## Every request carries the strict User-Agent (the server answers 429 to any other); authorized ones
## the Bearer access token; a 401 refreshes the token once (Account.refresh) and repeats the call.
## Device-checked calls (register / login / refresh) sign the exact body bytes: request_raw() sends
## the very PackedByteArray the SHA-256 for App Attest / Play Integrity was taken of.

signal account_changed  # Account: signed in / out, the profile changed

const TIMEOUT_S: float = 15.0
const TXT_429: String = "Слишком много попыток. Попробуйте позже"
const TXT_NET: String = "Нет связи с сервером. Проверьте интернет"
const TXT_SRV: String = "Сервер не отвечает. Попробуйте позже"

static var _inst: Api = null



static func i() -> Api:
	if _inst == null or not is_instance_valid(_inst):
		_inst = Api.new()
		_inst.name = "Api"
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_inst)
	return _inst


## «DroneFlames v0.30.25 rv:3025 (iPhone15,2; iOS 17.5; ru_RU)» — the server's regex (client-integration §1.1).
static func user_agent() -> String:
	var v: PackedStringArray = Menus.VERSION.trim_prefix("v").split(".")
	var nums: Array = []
	for k in 3:
		nums.append(clampi(int(v[k]) if k < v.size() else 0, 0, 9999))
	var rv: int = int(nums[0]) * 10000 + int(nums[1]) * 100 + int(nums[2])  # ПРЕДВАРИТЕЛЬНО: no build number at run time
	return "DroneFlames v%d.%d.%d rv:%d (%s; %s; %s)" % [nums[0], nums[1], nums[2], rv, _ua_model(), _ua_os(), _ua_locale()]


static func _ua_model() -> String:
	var m: String = OS.get_model_name()
	if m == "" or m == "GenericDevice":
		m = OS.get_name()
	var out: String = ""
	for ch: String in m:
		if _alnum(ch) or ch in [" ", ",", ".", "_", "+", "-"]:
			out += ch
	out = out.strip_edges()
	if out == "" or not _alnum(out[0]):
		out = "Device " + out  # the server wants a letter or digit first
	return out.left(40).strip_edges()


static func _alnum(ch: String) -> bool:
	return (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9")


static func _letters(s: String) -> bool:
	for ch: String in s:
		if not ((ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z")):
			return false
	return s != ""


static func _ua_os() -> String:
	var n: String = {"macOS": "macOS", "Windows": "Windows", "Linux": "Linux", "iOS": "iOS", "Android": "Android"}.get(OS.get_name(), "Other")
	var parts: PackedStringArray = PackedStringArray()
	for p: String in OS.get_version().split("."):
		if p.is_valid_int() and p.length() <= 3 and parts.size() < 3:
			parts.append(str(int(p)))
		else:
			break  # Windows «10.0.19045»: the server takes at most 3 digits a part
	return "%s %s" % [n, ".".join(parts) if not parts.is_empty() else "0"]


static func _ua_locale() -> String:
	var parts: PackedStringArray = OS.get_locale().replace("-", "_").split("_")
	var out: PackedStringArray = PackedStringArray()
	var lang: String = parts[0].to_lower() if not parts.is_empty() else ""
	if lang.length() < 2 or lang.length() > 3 or not _letters(lang):
		return "en"
	out.append(lang)
	for k in range(1, mini(parts.size(), 3)):
		var p: String = parts[k]
		if p.length() < 2 or p.length() > 4 or not _letters(p):
			break
		out.append(p)
	return "_".join(out)


## A JSON call. `auth`: Bearer + one refresh-and-retry on 401. `raw`: the exact body bytes (device-checked
## calls build them once: Account), `extra`: more headers (App Attest / Play Integrity).
func call_api(method: String, path: String, body: Variant = null, auth: bool = true, raw: PackedByteArray = PackedByteArray(), extra: PackedStringArray = PackedStringArray()) -> Dictionary:
	var r: Dictionary = await _once(method, path, body, auth, raw, extra)
	if auth and int(r["code"]) == 401 and raw.is_empty():
		if await Account.refresh():
			r = await _once(method, path, body, auth, raw, extra)
			if int(r["code"]) == 401:
				Account.lost_session()  # a fresh token refused too
		# (critic) a refresh that failed on the network / a 429 keeps the session: only its own 401 ends it
	return r


func _once(method: String, path: String, body: Variant, auth: bool, raw: PackedByteArray, extra: PackedStringArray) -> Dictionary:
	while not is_inside_tree():
		await (Engine.get_main_loop() as SceneTree).process_frame  # i() adds the node deferred
	NetConfig.load_cfg()
	var h := HTTPRequest.new()
	h.timeout = TIMEOUT_S
	var tls: TLSOptions = NetTls.for_url(NetConfig.api_url)
	if tls != null:
		h.set_tls_options(tls)  # SSL pinning (net/net_tls.gd)
	h.use_threads = false
	add_child(h)
	var hd := PackedStringArray(["User-Agent: " + user_agent(), "Accept: application/json"])
	if auth and Account.access != "":
		hd.append("Authorization: Bearer " + Account.access)
	hd.append_array(extra)
	var m: int = {"GET": HTTPClient.METHOD_GET, "POST": HTTPClient.METHOD_POST, "DELETE": HTTPClient.METHOD_DELETE}.get(method, HTTPClient.METHOD_GET)
	var bytes: PackedByteArray = raw
	if bytes.is_empty() and body != null:
		bytes = JSON.stringify(body).to_utf8_buffer()
	if not bytes.is_empty():
		hd.append("Content-Type: application/json")
	var err: int = h.request_raw(NetConfig.api_url + path, hd, m, bytes)
	if err != OK:
		h.queue_free()
		return {"code": 0, "data": null, "err": TXT_NET}
	var res: Array = await h.request_completed
	h.queue_free()
	var code: int = int(res[1])
	var txt: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(txt) if txt != "" else null
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "data": null, "err": TXT_NET}
	if NetConfig.trace_api:
		print("[Api] %s %s -> %d" % [method, path, code])  # never the body: tokens
	return {"code": code, "data": data, "err": "" if code >= 200 and code < 300 else err_text(code, data)}


## Text for the player; the screens map their own known `detail`s first (Account / profile).
static func err_text(code: int, data: Variant) -> String:
	if code == 429:
		return TXT_429
	if code == 0:
		return TXT_NET
	if code >= 500:
		return TXT_SRV
	var d: String = String((data as Dictionary).get("detail", "")) if data is Dictionary else ""
	return DETAIL_RU.get(d, "Ошибка сервера (%d)" % code)


## The backend's English `detail`s (client-integration §2-3, 10) -> Russian.
const DETAIL_RU: Dictionary = {
	"Username already taken": "Этот ник уже занят",
	"Email already registered": "Эта почта уже зарегистрирована",
	"Invalid email or password": "Неверная почта или пароль",
	"Invalid refresh token": "Сессия закончилась. Войдите снова",
	"Not authenticated": "Войдите в аккаунт",
	"Invalid token": "Сессия закончилась. Войдите снова",
	"Cosmetic not owned": "Это украшение ещё не открыто",
	"Match not found": "Партия не найдена",
}
