class_name NetConfig
extends RefCounted





const PROTO: int = 7
const RECONNECT_S: float = 60.0
const RECONNECT_EVERY: float = 4.0
const REJOIN_KEEP_S: int = 1200
const MATCH_KEEP_S: int = 3 * 24 * 3600
const MATCH_FILE: String = "user://net_match.save"
const MATCH_SAVE_TURNS: int = 600
const RESUME_WAIT_S: float = 180.0
const REJOIN_GONE_TRY_S: float = 15.0
const MP_SPEEDS: Array = [1, 2, 3]
const SPEED_WORDS: Array = ["ПО СОГЛАСИЮ", "АВТО", "ВЫКЛ"]
const SPEED_ORDER: Array = [0, 1, 2]
static var LAN_PORT: int = 24600
static var BEACON_PORT: int = 24601
static var BROWSE_PORT: int = 24602
static var test_no_broadcast: bool = false
const MAX_PLAYERS: int = 8
const FRAME_SIM_MS: float = 14.0
const HOLD_BACKLOG: int = 35
const HOLD_SLOW: int = 20
const HOLD_MAX: int = 70
const LAG_NOW_S: float = 0.3
const JOB_DELAY_TICKS: int = 120
const SIM_DT: float = 1.0 / 30.0
const TICKS_PER_TURN: int = 3
const HASH_EVERY: int = 150
const SNAP_CHUNK: int = 65536
const HOST_IDLE_S: float = 0.35
const CAPITAL_TIMEOUT_S: float = 90.0

static var guard: bool = false
static var trace: bool = false
static var test_speed: float = 1.0

static var signal_url: String = "wss://45.145.12.165:19080/mp/signal"
static var api_url: String = "https://drone-flames.snaipix.com"
const RELAY_URL: String = "wss://45.145.12.165:19080/mp/signal"
static var trace_api: bool = false
static var gcp_project: int = 0
const NICK_MAX: int = 16
const USER_CFG: String = "user://net.cfg"
static var nickname: String = ""
static var _loaded: bool = false


static func load_cfg() -> void :
	if _loaded:
		return
	_loaded = true
	for p: String in ["res://net/net.cfg", "user://net.cfg"]:
		var cf: = ConfigFile.new()
		if cf.load(p) != OK:
			continue
		signal_url = String(cf.get_value("net", "signal_url", signal_url))
		api_url = String(cf.get_value("net", "api_url", api_url)).trim_suffix("/")
		trace_api = bool(cf.get_value("net", "trace_api", trace_api))
		gcp_project = int(cf.get_value("net", "gcp_project", gcp_project))
		if p == USER_CFG:
			nickname = clean_nick(String(cf.get_value("net", "nick", "")))
	if OS.has_feature("mp_relay") or signal_url.contains("snaipix.com"):
		signal_url = RELAY_URL




static func clean_code(s: String) -> String:
	const CYR: String = "АВЕКМНОРСТХУ"
	const LAT: String = "ABEKMHOPCTXY"
	var o: String = ""
	for ch: String in s.to_upper():
		var i: int = CYR.find(ch)
		if i >= 0:
			ch = LAT[i]
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			o += ch
	return o



static func version() -> String:
	return "%s/%d" % [Menus.VERSION, PROTO]



static func nick() -> String:
	load_cfg()
	if nickname == "":
		set_nick("Player%06d" % (randi() % 1000000))
	return nickname



static func set_nick(n: String) -> String:
	load_cfg()
	var c: String = clean_nick(n)
	if c == "":
		return nickname
	nickname = c
	var cf: = ConfigFile.new()
	cf.load(USER_CFG)
	cf.set_value("net", "nick", nickname)
	if cf.save(USER_CFG) != OK:
		push_warning("[Net] cannot write " + USER_CFG)
	return nickname




static func save_rejoin(d: Dictionary) -> void :
	var cf: = ConfigFile.new()
	cf.load(USER_CFG)
	if cf.has_section("rejoin"):
		cf.erase_section("rejoin")
	for k: String in d:
		cf.set_value("rejoin", k, d[k])
	cf.set_value("rejoin", "t", int(Time.get_unix_time_from_system()))
	cf.save(USER_CFG)


static func load_rejoin() -> Dictionary:
	var cf: = ConfigFile.new()
	if cf.load(USER_CFG) != OK or not cf.has_section("rejoin"):
		return {}
	var d: Dictionary = {}
	for k: String in cf.get_section_keys("rejoin"):
		d[k] = cf.get_value("rejoin", k)
	var keep: int = MATCH_KEEP_S if bool(d.get("gone", false)) else REJOIN_KEEP_S

	var is_lan: bool = String(d.get("mode", "")) == "lan" or String(d.get("ip", "")) != ""
	var no_tok: bool = String(d.get("tok", "")) == "" and String(d.get("why", "")) != "handover" and not is_lan
	if no_tok or int(Time.get_unix_time_from_system()) - int(d.get("t", 0)) > keep:
		return {}
	return d



static func save_match(d: Dictionary) -> void :
	d["t"] = int(Time.get_unix_time_from_system())
	var tmp: String = MATCH_FILE + ".tmp"
	var f: = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_var(d, false)
	f.close()
	var da: = DirAccess.open("user://")
	if da == null:
		return
	if da.file_exists(MATCH_FILE.get_file()):
		da.remove(MATCH_FILE.get_file())
	da.rename(tmp.get_file(), MATCH_FILE.get_file())


static func load_match() -> Dictionary:
	if not FileAccess.file_exists(MATCH_FILE):
		return {}
	var f: = FileAccess.open(MATCH_FILE, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var(false)
	f.close()
	if not (v is Dictionary) or not (v as Dictionary).has("snap"):
		return {}
	if int(Time.get_unix_time_from_system()) - int((v as Dictionary).get("t", 0)) > MATCH_KEEP_S:
		return {}
	return v


static func clear_match() -> void :
	if FileAccess.file_exists(MATCH_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MATCH_FILE))



static func ago_text(unix_t: int) -> String:
	var s: int = maxi(0, int(Time.get_unix_time_from_system()) - unix_t)
	if s < 60:
		return "СЕЙЧАС"
	if s < 3600:
		return "%d МИН НАЗАД" % (s / 60)
	if s < 86400:
		return "%d Ч НАЗАД" % (s / 3600)
	return "ВЧЕРА" if s < 2 * 86400 else "%d ДН НАЗАД" % (s / 86400)


static func clear_rejoin() -> void :
	var cf: = ConfigFile.new()
	if cf.load(USER_CFG) == OK and cf.has_section("rejoin"):
		cf.erase_section("rejoin")
		cf.save(USER_CFG)


static func clean_nick(n: String) -> String:
	var out: String = ""
	for ch: String in n:
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127:
			out += ch
	return out.strip_edges().left(NICK_MAX).strip_edges()
