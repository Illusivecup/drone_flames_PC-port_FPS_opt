class_name NetSession
extends Node
## Multiplayer session (kiwy-multiplayer): lobby, lockstep turns, hash check, resync.
## Node "Net" under Main (same path on every peer, RPC target). Architecture: docs/NET_ARCH.md.
##
## Transport: LAN = ENet to the host's IP (rooms found by LanDiscovery); ONLINE = WebRTC through
## the own signaling server + TURN (RtcLink). Both end up as multiplayer.multiplayer_peer, the
## rest of this file does not care which one it is.
##
## Lockstep with a coordinating host: the host cuts game time into turns of
## NetConfig.TICKS_PER_TURN ticks (x1 only) and broadcasts each turn with the commands it got
## for it; every peer runs a turn only once it has it, so the host's clock is the match clock:
## a host that goes to the background pauses everybody (owner rule), an absent guest or one catching
## up (HOLD_MAX+ behind) pauses nobody; NET 37: a device that cannot keep up (HOLD_SLOW..HOLD_MAX
## turns behind) slows the turns down for everybody instead of letting its input lag grow. Every HASH_EVERY turns guests send a state hash; a guest that
## differs gets the host's snapshot (Save codec) and continues from there ("periodic sync").

signal lobby_changed
signal lobby_chat_received
signal mods_required(required_mods: Array)
signal player_left(nick: String, lost: bool)  # NET 29: a person left a running match (the AI took his country); lost = the link died
signal status_changed(text: String)
signal speed_changed(old: int, new: int)
signal ranked_event(d: Dictionary)  # BACKEND 2: queued / unqueued / found / accept_progress / mm_cancel / error (the screens)
signal player_back(nick: String)  # NET 32: a person came back into the running match  # NET 31: the match speed (HUD, toasts)

enum Mode { OFF, LAN, ONLINE }

## GameConfig fields the host sends with the start (match rules = the single-player setup screen).
const CFG_KEYS: Array = ["ranked", "bots", "cb_on", "cb_list", "difficulty", "aggression", "victory", "target_i", "time_i", "size_i", "fog",
	"ore_preset", "ore_custom", "creative", "night", "map_type", "rivers_i", "lakes_i", "expand_i", "reserves_i", "ai_autodig", "mp_speed", "alliances", "limit_i"]  # expand_i: NET 29 (bot growth was the guest's own setting); reserves_i / ai_autodig: v0.29b
## The only simulation calls a peer may send ("path.method" -> index of the argument that must be
## the issuer's country id, -1 = none). Every entity argument must belong to the issuer as well
## (_owns); a City may be foreign (attack target). Add new player actions here (docs/NET_ARCH.md §5).
const ALLOWED: Dictionary = {
	".cmd_field": -1, ".cmd_build_sub": -1, ".cmd_city_rename": -1,
	"mil.build": -1, "mil.build_line": -1, "mil.demolish": -1, "mil.restore": -1, "mil.restore_all": -1,
	"mil.set_halted": -1, "mil.set_prod_type": -1, "mil.set_standing": 0, "mil.set_smart": 0,
	"mil.set_auto_strike": 0, "mil.set_auto_kab": 0, "mil.set_auto_drones": 0, "mil.launch": -1,
	"mil.launch_multi_ex": -1, "mil.launch_missiles": -1, "mil.launch_missiles_multi": -1,
	"mil.retarget": -1, "mil.order_move": -1,
	"mil.air.set_pylon": -1, "mil.air.buy": -1, "mil.air.order_land": -1, "mil.air.upgrade": -1,
	"mil.air.set_payload": -1, "mil.air.order_patrol": -1, "mil.air.order_fly": -1,
	"mil.air.launch_kab": -1, "mil.air.launch_cruise": -1, "mil.air.multi_launch": -1,
	"mil.air.kab_strike": 0, "mil.air.cas_support": 0,  # R316 attack jet (country id, jet id, targets / point)
	"army.order_hold": 0, "army.occupy": 1, "army.leave": -1, "army.set_auto_refill": -1,
	"army.set_build": -1, "army.toggle_support": 0, "army.order_attack": 0, "army.set_ford": -1,  # R-FORD: спец-кнопка форсирования рек
	"ops.set_stance_all": 0, "ops.set_stance": -1, "ops.set_auto_orders": 0, "ops.start": -1,
	"ops.start_all": 0, "ops.cancel": -1, "ops.order": 0, "ops.prompt_accepted": -1, "ops.dismiss_prompt": -1,
	"ops.front_draw": 0, "ops.front_tap": 0,  # v0.29b FRONT29B: drawn front / tapped front of an army group
	"defense.rearm": -1, "protect.repair": -1, "protect.upgrade": -1,
	"defense.set_ad_rule": -1, "defense.set_ad_preset": -1,  # R335 AD RULES (arg 0 = the author's Country: entity check)
	"diplo.demand": 0, "diplo.propose_treaty": 0, "diplo.cancel_treaty": 0, "diplo.set_embargo": 0,
	"diplo.give_aid": 0, "diplo.declare_war": 0, "diplo.propose": 0, "diplo.break_alliance": 0,
	"econ.upgrade": -1, "econ.set_export": -1, "econ.buy": -1, "econ.sell": -1, "econ.set_trade": 0, "econ.market_order": -1,
	"econ.buy_shortfall": -1, "naval.launch_expedition": -1, "recon.launch": 0, ".cmd_recall": 0,
	"navy.fleet_create": 0, "navy.fleet_assign": 0, "navy.fleet_unassign": 0, "navy.fleet_disband_by": 0, "navy.fleet_style": 0,
	"navy.art.strike": 0,  # v0.30 NAVY30: ship battery strike (АРТ. УДАР)
	# NET 29: the UI24 sheets (diplomacy, inbox, conference, army groups / fronts, shipyard, УДАР)
	"diplo.answer_as": 0, "diplo.cancel_passage": 0, "diplo.support_war": 0, "diplo.release_subject": 0,
	"diplo.seek_independence": 0, "diplo.propose_subject": 0, "diplo.transfer": 0, "diplo.request_passage": 0,
	"diplo.alliance_style": 0, "diplo.alliance_leave": 0, "diplo.alliance_kick": 0, "diplo.alliance_found": 0,
	"diplo.alliance_invite": 0, "diplo.alliance_join": 0, "diplo.alliance_answer": 0,  # R320 ALLY320: name / colour / logo, leave, exclude
	"diplo.revoke_passage": 0, "diplo.offer_passage": 0, "diplo.expel_troops": 0, "diplo.recall_troops": 0,  # R331 PASSWAR
	"diplo.request": 0, "diplo.cancel_request": 0, "diplo.guard_end": 0, "diplo.guard_send": 0,  # R331 REQUESTS (guard_send: the barracks must be the author's)
	"diplo.sky_offer": 0, "diplo.sky_ask": 0, "diplo.sky_end": 0, "diplo.sky_take_home": 0,  # R331 SKY: «закрыть небо», «увезти к себе»
	"diplo.player_call": 0,  # NET 34: «ПРИЗВАТЬ» / «ПОЗВАТЬ В ВОЙНУ» (was called on the tapping device only)
	"econ.accept_request": -1, "econ.decline_request": -1,  # lead R335 FIX335: bot trade requests (args[0] = the answering Country; economy checks "to")
	"econ.autobuy_set": -1,  # NET 34: АВТОЗАКУПКА on / thresholds (econ_hub set it on the tapping device only)
	"diplo.conf.demand_surrender": 0, "diplo.conf.pick": 3, "diplo.conf.reset_picks": 1, "diplo.conf.confirm": 1,
	"navy.order": -1, "navy.cancel": -1,
	".cmd_static": -1, ".cmd_strike": -1, ".cmd_refill_all": -1,
	"hold.occupy": 2, "hold.leave": 1,  # v0.30.14 R314 (twink): soldiers into / out of a city building (game/urban_hold.gd)
	"econ.trd.set_sanctions": 0, "econ.trd.contract_offer": 0, "econ.trd.contract_answer": 0, "econ.trd.contract_cancel": 0,  # R331 TRADE (game/trade331.gd; the function checks `me` is a party)
	"rail.set_rail_ok": -1,  # R332b RAIL332: «ЖД: РАЗРЕШЕНО / ЗАПРЕЩЕНО» (args[0] = the author's Country; the barracks are checked to be his)
	"rail.build_station": -1, "rail.build_line": -1,  # R335 RAIL335: «ВОКЗАЛ» / «Ж/Д ПУТЬ» by hand (args[0] = the author's Country = _owns; the station / land are checked to be his)
}
const DEDUP_MS: int = 120  # reduced from 400ms to eliminate dropped clicks/building taps
const TURN_KEEP: int = 900  # turns kept after they ran (90 s): a resynced guest replays from the snapshot

## The session of this game (the UI24 sheets send their commands through NetSession.sim).
static var _inst: NetSession = null

static func inst() -> NetSession:
	return _inst

static func allowed() -> Dictionary:
	return ALLOWED

var main: Node  # game/main.gd
var gw: GameWorld
var lan: LanDiscovery
var rtc: RtcLink
var chat: DipChat  # CHAT (docs/CHAT.md): the people's diplomatic chat — UI only, never a lockstep command
const LOBBY_CHAT_LENGTH: int = 240
const LOBBY_CHAT_HISTORY: int = 40
const LOBBY_CHAT_INTERVAL_MS: int = 750

var lobby_chat: Array[Dictionary] = []
var _lobby_chat_sent: Dictionary = {}
var _lobby_chat_local_ms: int = -LOBBY_CHAT_INTERVAL_MS
var _lobby_kicking: Dictionary = {}

var mode: int = Mode.OFF
var is_host: bool = false
var in_match: bool = false
var slots: Array = []  # lobby / match roster: [{"peer", "name", "ready", "left"}], index = slot
var host_mods: Array = []  # active/required gameplay mods on the host
var local_slot: int = -1
var room_code: String = ""
var room_pub: bool = false  # NET 29: online room listed publicly (host's choice)
var browser: RoomBrowser  # NET 29: the public room list (screen «Мультиплеер»)
# NET 32 rejoin
var reconnecting: bool = false  # this guest lost the host and is trying to come back
var rejoining: bool = false  # connected back, waiting for the host's snapshot
var rc_t: float = 0.0  # seconds of reconnecting
var rc_tries: int = 0
var _rc_next: float = 0.0
var _rc_busy: bool = false  # a try is in progress
var _rc_started: float = 0.0
var _rj_t: float = 0.0  # seconds waiting for the snapshot after _rejoin_ok
var _rj_save_t: float = 0.0  # the saved place's time is refreshed every minute of the match
var _rejoin: Dictionary = {}  # this device's place (NetConfig.save_rejoin)
var _tokens: Dictionary = {}  # host: slot -> rejoin token
var _join_ip: String = ""
var _join_port: int = -1
var start_archs: Array = []  # NET 30: the people's styles of this match, from the start pack
var start_flags: Array = []  # MPFLAG: the people's own flags (FlagMaker codes, "" = generated), from the start pack
var start_names: Array = []  # NET 29: the people's nicks of this match (their countries' names), from the start pack
var status_text: String = ""

# lockstep state
var turns: Dictionary = {}  # turn -> Array of commands
var last_turn: int = -1
var exec_turn: int = 0
var exec_tick: int = 0
var host_active: bool = true
var stall_t: float = 0.0
var resyncs: int = 0  # snapshots this device restored (guest) / sent (host)
var desyncs: int = 0
var go: bool = false  # turns are flowing
var perf_tick_ms: float = 0.0  # NET 37 diagnostics: EMA of one lockstep tick (ms)
var perf_tick_max: float = 0.0  # max tick since the last perf_take()
var perf_frame_max: float = 0.0  # max simulation time in one frame (ms)
var perf_ticks_frame_max: int = 0  # most ticks run in one frame
var perf_holds: int = 0  # host frames without new turns (a device behind)
var _lag_now: Dictionary = {}  # NET 37 host: slot -> [backlog now, msec] (reliable, every LAG_NOW_S)
var _lag_now_t: float = 0.0
var hold_who: String = ""  # NET 37: whom the turns wait for («» = nobody): the plate
var resume_wait: bool = false  # NET 35: a resumed match waits for its players (host: the world stands; guest: the plate)
var resume_t: float = 0.0  # NET 35: host: seconds of that wait
var resume_back: int = 0  # NET 35: guest: people back (host's count) for the plate
var resume_total: int = 0
var resume_missing: String = ""  # NET 35: «ВАДИМ +1»
var _own_fog: bool = false  # NET 35: the host restores its own saved match (its fog is in the snapshot)
var _rc_limit: float = 0.0  # NET 35: this reconnect gives up after this long (a short try while the host is away)
var _leaving: bool = false  # NET 35: inside leave()
var _rc_card: bool = false  # NET 35: the reconnect came from «ВЕРНУТЬСЯ В ПАРТИЮ» (not from a lost link)
var _relay_hello_sent: bool = false
var match_id: String = ""  # BACKEND 1: the server's id of the running online match («turn»): the way back, /end
var _rc_wait_host: bool = false  # BACKEND 1: the resume socket waits for the host (no new tries meanwhile)
var _rc_resume: bool = false  # BACKEND 1: this try is a «resume» (its socket says «done» once connected)
var _rc_code_once: bool = false  # (BH #2) the next try is the room by its code, once
var _swapping: bool = false  # BACKEND 3: the lobby tunnel -> the WebRTC peer (its disconnect events are not real)
var _p2p_wait: float = -1.0  # BACKEND 3 guest: seconds left to reach the host directly after «turn»
const P2P_HOST_S: float = 28.0  # the host waits this long for the guests' direct connections (the server's window is 30)
var ranked_mode: String = ""  # BACKEND 2: "1v1" / "2v2" while queued / in a ranked lobby or match
var queue_t0: int = 0  # msec the search started (kept across a requeue)
var _ranked_go: Array = []  # host: [WorldSettings, cfg] ready for the start after «turn»
var _ranked_ready_sent: bool = false
const P2P_GUEST_S: float = 32.0
var _way_back_t: float = -1.0  # BACKEND 1 host: seconds until the way back opens again (a guest still missing)
var _acc: float = 0.0
var _host_turn: int = 0
var _host_acc: float = 0.0
var _pending: Array = []  # host: commands for the next turn
var _seq: int = 0
var _cbs: Dictionary = {}  # seq -> Callable (result of an own command)
var _cb_oid: Dictionary = {}  # seq -> [instance id, script] of the callback's object at issue (0 = none)  # lead R335
var _hashes: Dictionary = {}  # host: turn -> hash
var _ghash: Dictionary = {}  # host: turn -> {peer: hash} that arrived before the host got there
var _hparts: Dictionary = {}  # NET 34: host: turn -> NetHash.parts (what diverged is logged on a desync)
var _gparts: Dictionary = {}  # NET 34: host: turn -> {peer: parts} of the guests
var desync_parts: Dictionary = {}  # NET 34: part name -> times it differed in this match (diagnostics)
var _resync_q: Array = []
var _snap: Dictionary = {}
var _snap_next: Array = []  # [bytes, turn] that arrived while a restore was running (newest only)
var _last_snap: Dictionary = {}  # host: peer -> last snapshot turn; older hash reports are stale
var _last_snap_ms: Dictionary = {}  # host: peer -> timestamp of last snapshot/failed attempt
var _sync_wait: Dictionary = {}  # host: peer_id -> {"turn": int, "started_ms": int} holds turns until acknowledged
var _desync_streak: Dictionary = {}  # host: pid -> consecutive turns with hash mismatch
var _snap_t: float = 0.0  # seconds waiting for next chunk in _snap (guest watchdog)
var _restoring: bool = false
var _ready_peers: Dictionary = {}
var _cap_done: bool = false
var _late_cap_deadlines: Dictionary = {}
# NET 31 game speed: the host sets it (consensus: the lowest wish of the people; auto: faster while
# the people are quiet), a lag guard caps it; every turn carries it, so every device paces the same.
var speed: int = 1
var speed_why: String = ""  # "" | "start" | "lag" | "want" | "auto" | "auto:<event>"
var speed_who: String = ""  # who holds it (consensus) / whose device lags / whom an auto event concerns
var speed_why_prev: String = "start"  # the reason before the last change (the start hint)
var wants: Array = []  # the people's wished speeds by slot (sent with the speed state)
var my_want: int = 1
var calm_s: float = 0.0  # host, auto: seconds without an event
var _lag: Dictionary = {}  # host: slot -> [min backlog of its last window, msec of the report]
var _lag_min: int = 1 << 30  # this device: min backlog (turns received but not run) of this window
var _cap_i: int = 2  # host: highest allowed MP_SPEEDS index (the lag guard)
var _cap_ok_s: float = 0.0
var _last_down_ms: int = -100000
var _hold_until_ms: int = 0
var _spd_t: float = 0.0
var _auto_t: float = 0.0
var _hum: Dictionary = {}  # host, auto: cid -> [hp sum, cities, wars] of the last poll
var _want_note_ms: Dictionary = {}  # slot -> msec of its last «хочет xN» toast
var _start_t: float = -1.0  # host: seconds since the start was sent (peers that never get ready are dropped)
var _last_cmd: String = ""
var _last_cmd_ms: int = -100000


func setup(m: Node) -> void:
	main = m
	gw = m.get("world")
	lan = LanDiscovery.new()
	lan.name = "Lan"
	add_child(lan)
	rtc = RtcLink.new()
	rtc.name = "Rtc"
	add_child(rtc)
	chat = DipChat.new(self)
	browser = RoomBrowser.new()
	browser.name = "Browser"
	add_child(browser)
	rtc.room_ready.connect(_on_room_ready)
	rtc.match_started.connect(_on_match_started)
	rtc.p2p_started.connect(_on_p2p_started)
	rtc.ranked_msg.connect(_on_ranked_msg)
	rtc.promoted.connect(_on_promoted)
	rtc.host_changed.connect(func(host: String, you: bool) -> void:
		if you:
			_on_promoted()
		else:
			if is_host and in_match:
				is_host = false  # BACKEND 3: a former host back: a guest of the new one now
			_status("Новый хост: %s · соединяемся..." % host))
	rtc.resumed.connect(_on_way_back_open)
	rtc.waiting_host.connect(func() -> void:
		_rc_wait_host = true
		_status("Ждём хоста: вернётся — подключим сами"))
	rtc.reattaching.connect(func(why: String) -> void:
		if why == "" and in_match and not is_host and RtcLink.relay_only():
			_relay_hello_sent = false
			_send_relay_hello()
		_status(why if why != "" else "Связь восстановлена"))
	rtc.failed.connect(func(why: String) -> void:
		if in_match and is_host and not resume_wait:
			rtc.close_socket()  # BH v0.30.25: after an «error» the server keeps the socket open: _open_way_back() would never retry
			if why.ends_with("не найдена"):
				match_id = ""  # (critic) the server forgot the match: no way back to reopen (was a resume every 10 s)
			_way_back_t = 10.0 if _guest_missing() and match_id != "" else -1.0  # BACKEND 1: the way-back socket closed: the match goes on
			print("[Net] way back closed: %s" % why)
			return
		if resume_wait and is_host and why == "Партия не найдена" and mode == Mode.ONLINE:
			rtc.host(room_pub, String(_resume.get("code", "")))  # BACKEND 1: the match is gone on the server: a room by the old code
			return
		if reconnecting:
			_rc_busy = false
			_rc_wait_host = false
			if why == "Партия не найдена" and String(_rejoin.get("match", "")) != "":
				_rejoin["match"] = ""  # BACKEND 1: gone on the server: the next try is the room by its code
				NetConfig.save_rejoin(_rejoin)
				_rc_next = rc_t + 1.0
				return
			if why.begins_with("Время на возвращение"):
				_give_up("ХОСТ НЕ ВЕРНУЛСЯ · ЖДЁМ, КОГДА ПРОДОЛЖИТ", true)
				return
			if why.begins_with("Слишком много попыток вернуться"):
				_give_up("СЛИШКОМ МНОГО ПОПЫТОК ВЕРНУТЬСЯ · ПОДОЖДИТЕ", true)  # (2026-10-31) more tries only burn the hour's limit
				return
			if why.begins_with("Слишком много подключений"):
				_status("Сервер занят нашими же подключениями · повторяем...")
				_rc_next = rc_t + 8.0  # (2026-10-31) the server's per-account limit: give the old sockets time to close
				if _rc_limit > 0.0:
					_rc_limit += 8.0  # (critic) not out of the short «ВЕРНУТЬСЯ» try
				return
			if why.begins_with("Хост закрыл партию"):
				NetConfig.clear_rejoin()
				_rejoin = {}
				_give_up("ХОСТ ЗАВЕРШИЛ ПАРТИЮ")
				return
			if why.ends_with("не найдена") or why.begins_with("Хост закрыл"):
				_give_up("ХОСТ ЕЩЁ НЕ ПРОДОЛЖИЛ ПАРТИЮ" if _rc_card else "ХОСТ ВЫШЕЛ · ПАРТИЯ СОХРАНЕНА", true)  # NET 35: he may resume it
			elif why.begins_with("Другая версия"):
				NetConfig.clear_rejoin()
				_rejoin = {}
				_give_up(why)
			elif why == "Партия уже идёт":
				_give_up("ХОСТ ЕЩЁ НЕ ПРОДОЛЖИЛ ПАРТИЮ" if _rc_card else "Партия уже идёт", true)
			return
		if in_match and not is_host and not _rejoin.is_empty() and (why.begins_with("Хост закрыл") or why.ends_with("не найдена")):
			_rejoin["why"] = "left"  # the server saw the host go
			_start_reconnect()  # NET 35: the host's app died: try for a minute, then keep the place («ХОСТ ВЫШЕЛ»)
			return
		leave(false, true, false, is_host)  # NET 35 (critic): a host's lost server keeps the saved match
		_status(why))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void:
		if reconnecting:
			_rc_busy = false  # the next try comes
			return
		leave(false, true, false, is_host)
		_status("Не удалось подключиться"))
	multiplayer.server_disconnected.connect(_on_server_lost)


func active() -> bool:
	return mode != Mode.OFF


func _suspend_multiplayer_mods(suspend: bool) -> void:
	var mm: Node = get_node_or_null("/root/ModManager")
	if mm != null and mm.has_method("set_multiplayer_suspended"):
		mm.call("set_multiplayer_suspended", suspend)


func _network_entry_error() -> String:
	if main != null and not main.in_menu and not in_match:
		return "Сначала выйдите из одиночной партии в главное меню"
	return ""


func _status(t: String) -> void:
	status_text = t
	status_changed.emit(t)
	lobby_changed.emit()


# ------------------------------------------------------------------ lobby: host / join / leave

func host_lan() -> String:
	var entry_error: String = _network_entry_error()
	if entry_error != "":
		return entry_error
	leave(false)
	var p := ENetMultiplayerPeer.new()
	var err: int = p.create_server(NetConfig.LAN_PORT, NetConfig.MAX_PLAYERS - 1)
	if err != OK:
		return "Порт %d занят (%s)" % [NetConfig.LAN_PORT, error_string(err)]
	_suspend_multiplayer_mods(true)
	multiplayer.multiplayer_peer = p
	mode = Mode.LAN
	is_host = true
	_make_host_slot()
	lan.announce({"name": NetConfig.nick(), "port": NetConfig.LAN_PORT, "n": slots.size()})
	_status("Комната открыта в локальной сети")
	return ""


func join_lan(ip: String, port: int = -1) -> String:
	var entry_error: String = _network_entry_error()
	if entry_error != "":
		return entry_error
	leave(false)
	if port < 0:
		port = NetConfig.LAN_PORT
	var p := ENetMultiplayerPeer.new()
	var err: int = p.create_client(ip.strip_edges(), port)
	if err != OK:
		return "Не удалось подключиться (%s)" % error_string(err)
	_suspend_multiplayer_mods(true)
	multiplayer.multiplayer_peer = p
	mode = Mode.LAN
	is_host = false
	_join_ip = ip.strip_edges()
	_join_port = port
	_status("Подключение к %s..." % ip)
	return ""


## BACKEND 1: the name of this person in a room: the account's username online, the local nick on Wi-Fi.
func my_name() -> String:
	if Account.username() != "":
		return NetConfig.clean_nick(Account.username())
	return NetConfig.nick()


func host_name() -> String:
	if slots.size() > 0:
		return String(slots[0].get("name", "Хост"))
	return "Хост"


func _my_mod_versions() -> Dictionary:
	if has_node("/root/ModManager"):
		var mm = get_node("/root/ModManager")
		if mm.has_method("get_installed_mod_versions"):
			return mm.get_installed_mod_versions()
	return {}


func resend_hello_with_mods() -> void:
	if is_host or multiplayer.multiplayer_peer == null:
		return
	if not multiplayer.get_peers().has(1):
		return
	_hello.rpc_id(1, NetConfig.version(), my_name(), clampi(GameConfig.arch_i, 0, 3), String(_rejoin.get("tok", "")) if reconnecting else "", my_cos(), my_flag(), _my_mod_versions())


static func get_lan_ips() -> Array[String]:
	var out: Array[String] = []
	var addrs = IP.get_local_addresses()
	# 1. Prioritize VPN interfaces like Radmin (26.) or Hamachi (25.)
	for a: String in addrs:
		if a.count(".") == 3 and (a.begins_with("26.") or a.begins_with("25.")):
			if not out.has(a):
				out.append(a)
	# 2. Local LAN (192.168., 10., 172.16-31)
	for a: String in addrs:
		if a.count(".") == 3:
			if a.begins_with("192.168.") or a.begins_with("10.") or LanDiscovery._is_172_private(a):
				if not out.has(a):
					out.append(a)
	# 3. Fallback
	if out.is_empty():
		for a: String in addrs:
			if a.count(".") == 3 and a != "127.0.0.1":
				out.append(a)
	if out.is_empty():
		out.append("127.0.0.1")
	return out


func _gen_tok() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()



## MPFLAG (docs/NET_ARCH.md): this person's own flag (ПРОФИЛЬ / «ВАША СТРАНА», GameConfig.my_flag), "" = none.
func my_flag() -> String:
	return clean_flag(GameConfig.my_flag)


## A flag code from another device: a valid FlagMaker code or "" (never trusted as is: it is drawn on every screen).
static func clean_flag(f: Variant) -> String:
	if not (f is String) or (f as String).length() > 64 or FlagMaker.decode(f as String).is_empty():
		return ""
	return f as String


## BACKEND 3: the codes this person wears (online: the account's; Wi-Fi: none) - shown in the lobby slots.
func my_cos() -> Dictionary:
	if mode != Mode.ONLINE or not Account.signed_in():
		return {}
	var e: Dictionary = Account.equipped()
	return {"frame": e.get("frame"), "banner": e.get("banner"), "title": e.get("title")}


## Only known codes of the right kind travel on (a guest cannot push anything else into the roster).
static func _clean_cos(c: Variant) -> Dictionary:
	if not (c is Dictionary):
		return {}
	var out: Dictionary = {}
	for k: String in ["frame", "banner", "title"]:
		var v: Variant = (c as Dictionary).get(k)
		if v is String and Cosmetics.shown(k, v) == v:
			out[k] = v
	return out


## «turn»: the server sealed the room; its match id is the way back for everybody (saved with the place).
func _on_match_started(mid: String) -> void:
	match_id = mid
	if not is_host and not _rejoin.is_empty():
		_rejoin["match"] = mid
		NetConfig.save_rejoin(_rejoin)
	if mid == "":
		print("[Net] the server gave no match id: no way back into this match")
	if RtcLink.relay_only() and is_host and not _ranked_go.is_empty():
		var go2: Array = _ranked_go
		_ranked_go = []
		_online_go(go2[0], go2[1])


## Host: a guest is gone without its bye: open a resume socket (the server pairs him with us again).
func _open_way_back() -> void:
	if not is_host or mode != Mode.ONLINE or match_id == "" or rtc.socket_open() or _leaving:
		return
	_way_back_t = -1.0
	rtc.resume(match_id)
	print("[Net] way back open for the guests (match %s)" % match_id)


## The resume socket is open (host). A saved match: its peer is the room now; the guests come by «resume».
func _on_way_back_open() -> void:
	if resume_wait:
		multiplayer.multiplayer_peer = rtc.peer
		room_code = String(_resume.get("code", room_code))
		_status("Партия восстановлена: ждём игроков")
		lobby_changed.emit()


func _guest_missing() -> bool:
	for i in range(slots.size()):
		if i != local_slot and bool(slots[i].get("left", false)) and not bool(slots[i].get("bye", false)) and not bool(slots[i].get("away", false)):
			return true
	return false


## BH v0.30.25: the host drops its saved match («УДАЛИТЬ ПАРТИЮ» / «СОЗДАТЬ» over it): an online one ends on the
## server too (counted in the profiles; the guests waiting for it hear «Хост закрыл партию» instead of waiting 4 h).
func drop_saved_match() -> void:
	var d: Dictionary = NetConfig.load_match()
	NetConfig.clear_match()
	var mid: String = String(d.get("match", ""))
	if String(d.get("mode", "")) == "online" and mid != "" and Account.signed_in():
		_end_match(mid, float(d.get("played", 0.0)))  # (critic) the saved match's own count, not this session's memory


## Host: POST /mp/match/{id}/end (client-integration §5.6): counted in the profiles (>= 2 players and
## MP_PLAYED_MIN_SECONDS both by the server's clock and of real play — `played`, the seconds with another person on).
## ROTATION (docs/NET_ARCH.md «Ротация хоста»): an online casual match outlives its host. The host who leaves hands
## the match over (the server makes the most advanced guest the host at once) — when somebody else is still in it.
func can_hand_over() -> bool:
	if not is_host or not in_match or mode != Mode.ONLINE or match_id == "" or not GameConfig.ranked.is_empty() or match_decided:
		return false
	for i in slots.size():
		if i != local_slot and _live(i) and multiplayer.get_peers().has(int(slots[i].get("peer", 0))):
			return true
	return false


## ROTATION: this device's saved online match — is it still its host? The app may have died, and the server gave
## the match to a guest meanwhile: then the save is no way back as the host. It becomes this person's place as a
## guest of the new host («ВЕРНУТЬСЯ В ПАРТИЮ»). -> true = converted (the menu redraws). No answer / 404 (the match
## is gone, an old server): the save stays as it was.
static var _role_checked: Dictionary = {}  # match id -> true (once a session)


func check_saved_host() -> bool:
	var d: Dictionary = NetConfig.load_match()
	var mid: String = String(d.get("match", ""))
	if d.is_empty() or String(d.get("mode", "")) != "online" or mid == "" or _role_checked.has(mid) or not Account.signed_in():
		return false
	_role_checked[mid] = true
	var r: Dictionary = await Api.i().call_api("GET", "/mp/match/%s/role" % mid)
	if int(r["code"]) != 200 and int(r["code"]) != 404:
		_role_checked.erase(mid)  # (2026-10-31) no answer (network, 5xx, limit): ask again next time, not «checked»
		return false
	if int(r["code"]) != 200 or not (r["data"] is Dictionary) or bool((r["data"] as Dictionary).get("host", true)):
		return false
	if NetConfig.load_match().get("match", "") != mid:
		return false  # changed meanwhile
	NetConfig.save_rejoin({"mode": "online", "ip": "", "port": 0, "code": String(d.get("code", "")), "tok": "", "host": "",
		"match": mid, "why": "handover"})
	NetConfig.clear_match()
	print("[Net] saved match %s: the host changed while away — a guest's place now" % mid)
	return true


## The server: «the host left on purpose» (no 30 s wait). An old server / a match without rotation: the old /end.
func _hand_over(mid: String) -> void:
	var r: Dictionary = await Api.i().call_api("POST", "/mp/match/%s/leave" % mid)
	print("[Net] match %s handed over: %d" % [mid, int(r["code"])])
	if int(r["code"]) == 404:
		_end_match(mid)


## Guest: the host left on purpose: a new host is being picked (the link drops next; the way back is the server's).
@rpc("authority", "call_remote", "reliable")
func _host_handover() -> void:
	if not _rejoin.is_empty():
		_rejoin["why"] = "handover"
	_handing_over = true
	_status("Хост вышел · выбираем нового хоста...")
	if main != null and main.has_method("net_toast"):
		main.net_toast("ХОСТ ВЫШЕЛ · ВЫБИРАЕМ НОВОГО ХОСТА")


var _handing_over: bool = false


func _end_match(mid: String, played: float = -1.0) -> void:
	if RtcLink.relay_only():
		if is_host:
			var played_time: float = _played_s if played < 0.0 else played
			rtc.match_end(mid, "completed" if match_decided else "host_left", played_time)
		return
	if played < 0.0:
		played = _played_s if _played_mid == mid else 0.0  # read now: leave() goes on to reset the session
	var r: Dictionary = await Api.i().call_api("POST", "/mp/match/%s/end" % mid, {"played_s": snappedf(played, 0.1)})
	if int(r["code"]) == 200 and r["data"] is Dictionary:
		var counted: bool = bool((r["data"] as Dictionary).get("counted", false))
		var need_min: int = maxi(1, int((r["data"] as Dictionary).get("min_seconds", 600)) / 60)
		print("[Net] match %s ended: counted %s (played %.0f s)" % [mid, str(counted), played])
		if main != null and main.has_method("net_toast"):
			main.net_toast("ПАРТИЯ ЗАСЧИТАНА В ПРОФИЛЬ" if counted else "НЕ ЗАСЧИТАНА: НУЖНО 2 ИГРОКА И %d МИН ИГРЫ" % need_min)
		Account.fetch_info()
	else:
		print("[Net] match %s end: %d" % [mid, int(r["code"])])


func notify_match_finished() -> void:
	if is_host and in_match and RtcLink.relay_only():
		rtc.match_end(match_id, "completed", _played_s)


# ------------------------------------------------------------------ BACKEND 2: ranked (docs/RANKED.md)

## Into the ranked queue of `mode` (one socket from the queue to the match). "" = searching.
func queue_ranked(rmode: String) -> String:
	var entry_error: String = _network_entry_error()
	if entry_error != "":
		return entry_error
	if not Account.signed_in():
		return "Войдите в аккаунт"
	if not RtcLink.available():
		return "WebRTC недоступен в этой сборке"
	leave(false)
	_suspend_multiplayer_mods(true)
	GameConfig.ranked = {}
	browser.stop()
	mode = Mode.ONLINE
	is_host = false
	ranked_mode = rmode
	queue_t0 = Time.get_ticks_msec()
	if not rtc.joined_room.is_connected(_on_ranked_joined):
		rtc.joined_room.connect(_on_ranked_joined)  # the server's lobby comes from the queue (no join_online)
	rtc.queue(rmode, {"tier": snappedf(clampf(float(OS.get_processor_count()) / 8.0, 0.2, 1.0), 0.1)})
	_status("Подбираем соперников вашего уровня")
	return ""


func _on_ranked_joined() -> void:
	if ranked_mode != "" and not rtc.ranked.is_empty():
		_on_rtc_joined()
		_status("Соединяемся с хостом...")


func unqueue_ranked() -> void:
	if ranked_mode != "" and rtc.socket_open():
		rtc.unqueue()


func accept_ranked(check_id: String, yes: bool) -> void:
	rtc.accept(check_id, yes)


func _on_ranked_msg(d: Dictionary) -> void:
	match String(d.get("t", "")):
		"mm_cancel":  # the found match / the lobby fell apart: the tunnel goes (a «queued» may follow: back in the queue)
			if not String(d.get("why", "")).ends_with("продолжаем поиск"):
				ranked_mode = ""  # (critic) out of the queue: nothing to cancel any more
				rtc.close_socket()
			if multiplayer.multiplayer_peer == rtc.tunnel and rtc.tunnel != null:
				multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
			rtc.tunnel = null
			rtc.ranked = {}
			slots = []
			is_host = false
			_ranked_go = []
		"unqueued":
			ranked_mode = ""
	ranked_event.emit(d)
	var t: String = String(d.get("t", ""))
	if t == "unqueued" or (t == "mm_cancel" and ranked_mode == ""):
		leave.call_deferred(false)  # out of the search: no session, no stale «Подбираем…» status left


func _ranked_size() -> int:
	var n: int = 0
	for team: Array in rtc.ranked.get("teams", []):
		n += team.size()
	return n


## The team of a username in the server's lobby (-1 = not in it).
func _team_of_name(nm: String) -> int:
	var teams: Array = rtc.ranked.get("teams", [])
	for t in teams.size():
		for p: Dictionary in teams[t]:
			if String(p.get("name", "")).to_lower() == nm.to_lower():
				return t
	return -1


## Host: everybody is in: the settings from the server, the seed from the match id, the seats; «ready».
func _ranked_ready_host() -> void:
	if not _ranked_go.is_empty() or _ranked_ready_sent:
		return
	for sl: Dictionary in slots:
		if _team_of_name(String(sl.get("name", ""))) < 0:
			print("[Net] ranked: %s is not in the server's teams" % String(sl.get("name", "")))
			return
	_ranked_ready_sent = true
	var rk: Dictionary = rtc.ranked
	RankedRules.apply(String(rk.get("mode", ranked_mode)), rk.get("settings", {}))
	var s := WorldSettings.new()
	s.world_seed = RankedRules.seed_of(String(rk.get("mm", "")))
	s.size = int(GameConfig.SIZES[GameConfig.size_i])
	GameConfig.apply_map(s, true)
	var cfg: Dictionary = {}
	for n: String in CFG_KEYS:
		cfg[n] = (GameConfig as GDScript).get(n)
	_tokens.clear()
	var crypto := Crypto.new()
	for i in range(1, slots.size()):
		_tokens[i] = crypto.generate_random_bytes(16).hex_encode()
	_ranked_go = [s, cfg]
	rtc.ready(_tokens.values().map(func(t: String) -> String: return t.sha256_text()))
	_status("Все на связи · ждём сервер")


## The ranked part of the start pack: team and username of every slot, the match id, the limit.
func _ranked_pack() -> Dictionary:
	if rtc.ranked.is_empty():
		return {}
	var rk: Dictionary = rtc.ranked
	return {"mm": String(rk.get("mm", "")), "mode": String(rk.get("mode", "")), "match": match_id,
		"teams": slots.map(func(sl: Dictionary) -> int: return _team_of_name(String(sl.get("name", "")))),
		"names": slots.map(func(sl: Dictionary) -> String: return String(sl.get("name", ""))),
		"time_limit": int((rk.get("settings", {}) as Dictionary).get("time_limit", 600))}


## A guest checks the host's pack against the server's own lobby object: the match id, the teams of
## every seat, the map seed from the id, the time limit. "" = all agree; else what differs.
func _ranked_check(pk: Dictionary, pack: Dictionary) -> String:
	var rk: Dictionary = rtc.ranked
	if String(pk.get("mm", "")) != String(rk.get("mm", "")):
		return "mm"
	var names: Array = pk.get("names", [])
	var teams: Array = pk.get("teams", [])
	if names.size() != _ranked_size():
		return "seats"
	for i in names.size():
		if i >= teams.size() or _team_of_name(String(names[i])) != int(teams[i]):
			return "team of %s" % String(names[i])
	if int(pk.get("time_limit", -1)) != int((rk.get("settings", {}) as Dictionary).get("time_limit", 600)):
		return "time_limit"
	var ws: Dictionary = pack.get("ws", {})
	if int(ws.get("world_seed", -1)) != RankedRules.seed_of(String(rk.get("mm", ""))):
		return "seed"
	return ""


func host_online(pub: bool = false) -> String:
	var entry_error: String = _network_entry_error()
	if entry_error != "":
		return entry_error
	leave(false)
	if not RtcLink.available():
		return "WebRTC недоступен в этой сборке"
	_suspend_multiplayer_mods(true)
	browser.stop()  # BACKEND 1: the server allows 2 sockets per account
	mode = Mode.ONLINE
	is_host = true
	room_pub = pub or RtcLink.relay_only()
	_status("Создаём комнату на сервере...")
	rtc.host(room_pub)
	return ""


## Host: the room type from the lobby («ПУБЛИЧНАЯ» = in the public browser, else by code only).
func set_room_pub(pub: bool) -> void:
	if is_host and mode == Mode.ONLINE and not in_match:
		room_pub = pub
		rtc.set_pub(pub)
		if not slots.is_empty():
			slots[0]["pub"] = pub
			_roster.rpc(slots)
		lobby_changed.emit()


## NET 30: this person's country style (the room's «ВАШ ОБЛИК»): saved as a pref, sent to the host,
## shown in everybody's slots; the «cap» command founds the capital in it.
func set_arch(a: int) -> void:
	a = clampi(a, 0, 3)
	GameConfig.arch_i = a
	Save.save_prefs()
	if local_slot >= 0 and local_slot < slots.size():
		slots[local_slot]["arch"] = a  # shown at once; the host's roster confirms it
	if not active():
		lobby_changed.emit()
		return
	if in_match:
		if not is_host:
			_pick_arch.rpc_id(1, a)  # the host's capital timeout uses it
		return
	if is_host:
		_roster.rpc(slots)
		lobby_changed.emit()
	else:
		_pick_arch.rpc_id(1, a)
		lobby_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _pick_arch(a: int) -> void:
	if not is_host:
		return
	var s: int = _slot_of(multiplayer.get_remote_sender_id())
	if s < 0:
		return
	slots[s]["arch"] = clampi(a, 0, 3)
	if in_match:
		return  # picked during the start: kept for the capital timeout (a roster now would reset the status)
	_roster.rpc(slots)
	lobby_changed.emit()


## Style of slot `i` (a room roster from an old build has none: the local default).
func slot_arch(i: int) -> int:
	if i < 0 or i >= slots.size():
		return 0
	return clampi(int((slots[i] as Dictionary).get("arch", 0)), 0, 3)


## The room is in the public online list (guests: what the host set).
func room_is_pub() -> bool:
	if is_host:
		return room_pub
	return not slots.is_empty() and bool((slots[0] as Dictionary).get("pub", false))


func join_online(code: String, allow_late: bool = true) -> String:
	var entry_error: String = _network_entry_error()
	if entry_error != "":
		return entry_error
	leave(false)
	if not RtcLink.available():
		return "WebRTC недоступен в этой сборке"
	_suspend_multiplayer_mods(true)
	browser.stop()  # BACKEND 1: the server allows 2 sockets per account
	mode = Mode.ONLINE
	is_host = false
	_status("Ищем комнату %s..." % code.to_upper())
	if not rtc.joined_room.is_connected(_on_rtc_joined):
		rtc.joined_room.connect(_on_rtc_joined, CONNECT_ONE_SHOT)
	rtc.join(code, "", allow_late)
	return ""


func _on_room_ready(code: String) -> void:
	room_code = code
	if not rtc.ranked.is_empty():  # BACKEND 2: the server picked this device as the host of the ranked lobby
		is_host = true
		_ranked_go = []
		_ranked_ready_sent = false
		multiplayer.multiplayer_peer = rtc.tunnel
		_make_host_slot()
		_status("Соединяемся с игроками...")
		return
	multiplayer.multiplayer_peer = rtc.tunnel  # BACKEND 3: the lobby over the socket
	if resume_wait:  # NET 35: the resumed match: its seats (the host checks the guests' tokens; seal at resume_go)
		var old: String = String(_resume.get("code", ""))
		_status(("Комната %s: ждём игроков" % code) if old == "" or old == code else ("Новый код комнаты %s · отправьте его игрокам" % code))
		lobby_changed.emit()
		return
	_make_host_slot()
	slots[0]["pub"] = room_pub  # the guests' lobby shows the room type
	_status("Комната %s: ждём игроков" % code)


func _on_rtc_joined() -> void:
	if not rtc.ranked.is_empty() and rtc.lobby():
		is_host = false  # BACKEND 2: a guest of the ranked lobby (or of a new host of it)
		_ranked_ready_sent = false
	multiplayer.multiplayer_peer = rtc.tunnel if rtc.lobby() else rtc.peer  # BACKEND 3: the lobby over the socket
	room_code = rtc.code
	_status("Соединяемся с хостом...")
	if RtcLink.relay_only():
		_relay_hello_sent = false
		call_deferred("_send_relay_hello")


func _make_host_slot() -> void:
	var h_mods: Array = []
	if has_node("/root/ModManager"):
		var mm = get_node("/root/ModManager")
		if mm.has_method("get_required_mp_mods"):
			h_mods = mm.get_required_mp_mods()
	host_mods = h_mods
	slots = [{"peer": 1, "name": my_name(), "ready": true, "left": false, "arch": clampi(GameConfig.arch_i, 0, 3), "cos": my_cos(), "flag": my_flag(), "mods": h_mods}]
	local_slot = 0
	lobby_changed.emit()


## Leave the room / match. to_menu: the main menu is shown by the caller.
func leave(notify: bool = true, keep_status: bool = false, keep_rejoin: bool = false, keep_match: bool = false) -> void:
	_leaving = true  # NET 35: closing the peer below fires server_disconnected: not a lost link to come back from
	var was_match: bool = in_match
	var handover: bool = not keep_match and can_hand_over()  # ROTATION: the guests go on with a new host
	var own_place: Dictionary = {}
	if handover:
		_hand_over(match_id)
		own_place = {"mode": "online", "ip": "", "port": 0, "code": room_code, "tok": "", "host": "", "match": match_id, "why": "handover"}
	elif is_host and in_match and not keep_match and mode == Mode.ONLINE and match_id != "" and GameConfig.ranked.is_empty():
		_end_match(match_id)  # (a ranked match ends by every player's report, never by /end)
	ranked_mode = ""
	_ranked_go = []
	if not keep_match and (RankedRules.active() or not RankedRules._saved.is_empty()):
		RankedRules.clear()  # BACKEND 1: the match is over for the server (match_played; the waiting guests are told)
	if not keep_match:
		match_id = ""
		match_decided = false  # (critic) read above (handover); never carried into the next match
		chat.reset()
	_way_back_t = -1.0
	_rc_wait_host = false
	_rc_resume = false
	_p2p_wait = -1.0
	if is_host and in_match and not keep_match:
		NetConfig.clear_match()  # NET 35: «ЗАКОНЧИТЬ ДЛЯ ВСЕХ»: nothing to resume
	if not is_host and in_match and not reconnecting and not keep_rejoin and multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		_bye.rpc_id(1)
		if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
			_flush_peer()
	if is_host and in_match and not keep_match and multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		if handover:
			_host_handover.rpc()  # ROTATION: «a new host is being picked», not «the match is over»
		else:
			_match_over.rpc()  # NET 32: the guests do not try to come back into a match that is gone
		if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
			_flush_peer()
		else:
			for i in 8:  # BH v0.30.25: WebRTC has no flush: closed at once, the guests never got it («ХОСТ ВЫШЕЛ · ПАРТИЯ СОХРАНЕНА» for an ended match)
				multiplayer.multiplayer_peer.poll()
				OS.delay_msec(40)
	reconnecting = false
	rejoining = false
	if not keep_rejoin:
		_rejoin = {}
		if not is_host and not (was_match and not match_decided):
			NetConfig.clear_rejoin()  # left on purpose: no way back (NET 35: never the host: on one PC it shares the guest's net.cfg)
	if not own_place.is_empty():
		NetConfig.save_rejoin(own_place)  # ROTATION: the old host may come back — as a guest of the new one («ВЕРНУТЬСЯ В ПАРТИЮ»)
	if not keep_status:
		status_text = ""
	lan.stop()
	rtc.close()
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.OFF
	is_host = false
	in_match = false
	go = false
	resume_wait = false
	_own_fog = false
	slots = []
	local_slot = -1
	room_code = ""
	lobby_chat.clear()
	_lobby_chat_sent.clear()
	_lobby_chat_local_ms = -LOBBY_CHAT_INTERVAL_MS
	_lobby_kicking.clear()
	_reset_lockstep()
	if gw != null:
		gw.net_driven = false
		gw.ui_mute = false
	if notify:
		lobby_changed.emit()
	_leaving = false
	if was_match and main != null and main.has_method("net_match_closed"):
		main.net_match_closed()
	_suspend_multiplayer_mods(false)


func _reset_lockstep() -> void:
	turns.clear()
	last_turn = -1
	exec_turn = 0
	exec_tick = 0
	host_active = true
	stall_t = 0.0
	_acc = 0.0
	_host_turn = 0
	_host_acc = 0.0
	_pending.clear()
	_cbs.clear()
	_cb_oid.clear()  # lead R335
	_hashes.clear()
	_ghash.clear()
	_hparts.clear()
	_gparts.clear()
	desync_parts.clear()
	_resync_q.clear()
	_snap = {}
	_snap_next = []
	_last_snap.clear()
	_last_snap_ms.clear()
	_sync_wait.clear()
	_desync_streak.clear()
	_snap_t = 0.0
	_restoring = false
	speed = 1
	speed_why = "start"
	speed_who = ""
	my_want = 1
	wants = []
	calm_s = 0.0
	_lag.clear()
	_lag_now.clear()  # NET 37
	hold_who = ""
	_lag_min = 1 << 30
	_cap_i = NetConfig.MP_SPEEDS.size() - 1
	_cap_ok_s = 0.0
	_last_down_ms = -100000
	_hold_until_ms = 0
	_spd_t = 0.0
	_auto_t = 0.0
	_hum.clear()
	_ready_peers.clear()
	_start_t = -1.0
	_cap_done = false
	_late_cap_deadlines.clear()
	resyncs = 0
	desyncs = 0


func _on_connected() -> void:
	if mode == Mode.ONLINE and RtcLink.relay_only():
		_send_relay_hello()
		return
	if _p2p_wait >= 0.0:
		_p2p_wait = -1.0  # BACKEND 3: the host reached directly: the socket goes; the host's _start follows
		_status("Соединено с хостом · загружаем партию")
		get_tree().create_timer(15.0).timeout.connect(func() -> void:
			if not in_match and mode == Mode.ONLINE and not is_host:
				leave(false, true)  # (critic) reached after the host gave up: no start will come
				_status("Хост начал без вас: не удалось соединиться вовремя"))
		return
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		var hp: ENetPacketPeer = (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(1)
		if hp != null:
			hp.set_timeout(0, 30000, 90000)  # a host in the background = a pause for 90 s, not a dropped match
	_hello.rpc_id(1, NetConfig.version(), my_name(), clampi(GameConfig.arch_i, 0, 3), String(_rejoin.get("tok", "")) if reconnecting else "", my_cos(), my_flag(), _my_mod_versions())
	if reconnecting:
		# (2026-10-31) the host is reached: a host that has just resumed may still be building its world (we wait in
		# its queue for _rejoin_ok). Was: the short «ВЕРНУТЬСЯ» limit (15 s) ran on and gave «ХОСТ ЕЩЁ НЕ ПРОДОЛЖИЛ
		# ПАРТИЮ», and after 12 s a new try dropped this live link (critic) — a loop burning the hour's resumes.
		_rc_reached_at = rc_t
	_rc_resume = false
	_status("Подключено, ждём хост")


## The WebSocket relay peer already has its transport; it does not raise ENet/WebRTC's connected_to_server callback
## consistently on Android, so send the host's lobby hello explicitly after the relay peer is installed.
func _send_relay_hello() -> void:
	if _relay_hello_sent or is_host or mode != Mode.ONLINE or multiplayer.multiplayer_peer != rtc.tunnel or rtc.tunnel == null:
		return
	_relay_hello_sent = true
	_hello.rpc_id(1, NetConfig.version(), my_name(), clampi(GameConfig.arch_i, 0, 3), String(_rejoin.get("tok", "")) if reconnecting else "", my_cos(), my_flag(), _my_mod_versions())
	if reconnecting:
		_rc_reached_at = rc_t
	_rc_resume = false
	_status("Подключено, ждём хост")


func _on_peer_connected(id: int) -> void:
	if is_host and mode == Mode.LAN and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		var pp: ENetPacketPeer = (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(id)
		if pp != null:
			pp.set_timeout(0, 30000, 90000)  # a phone in the background keeps its seat for 90 s


func _on_peer_disconnected(id: int) -> void:
	if not is_host or _leaving or _swapping:
		return
	_lobby_chat_sent.erase(id)
	_lobby_kicking.erase(id)
	_last_snap.erase(id)
	_last_snap_ms.erase(id)
	_desync_streak.erase(id)
	_sync_wait.erase(id)
	while _resync_q.has(id):
		_resync_q.erase(id)
	var s: int = _slot_of(id)
	if s < 0:
		return
	if in_match:
		slots[s]["left"] = true
		if resume_wait:
			_resume_note()  # NET 35: back to «not here»; the AI gets the country only when the match goes on
			lobby_changed.emit()
			return
		_pending.append({"k": "ai", "c": s + 1, "s": -1, "q": 0, "lost": not bool(slots[s].get("bye", false))})  # the AI takes the country over
		if not bool(slots[s].get("bye", false)):
			_open_way_back()  # BACKEND 1: the server lets him back only while the host waits too
		_status("%s вышел: страной управляет ИИ" % String(slots[s]["name"]))
		if not go:
			_mark_ready(-1)  # the start must not wait for someone who is gone
	else:
		_remove_lobby_slot(s)
		return
	lobby_changed.emit()
	lan.update_info({"n": slots.size()})


func _remove_lobby_slot(slot: int) -> void:
	slots.remove_at(slot)
	_roster.rpc(slots)
	lobby_changed.emit()
	lan.update_info({"n": slots.size()})


func _on_server_lost() -> void:
	if _leaving or _swapping:
		return
	if in_match and not is_host and not _rejoin.is_empty() and not reconnecting:
		_start_reconnect()  # NET 32: the world stays; we try to come back
		return
	if reconnecting:
		return
	status_text = "Хост отключился"
	leave(true, true)


# ------------------------------------------------------------------ NET 32: rejoin a running match

## Lost the host in a match: keep the world, try to connect back every RECONNECT_EVERY s.
func _start_reconnect() -> void:
	if not _rejoin.is_empty():
		NetConfig.save_rejoin(_rejoin)  # «N МИН НАЗАД» counts from the loss, not from the start
	reconnecting = true
	_rc_busy = false
	_rc_wait_host = false  # (test) a fresh try: the wait of an earlier one (after a host change) is over — else no resume is ever sent
	_rc_reached_at = -1.0
	rejoining = false
	go = false
	rc_t = 0.0
	rc_tries = 0
	_rc_next = 1.0
	_drop_peer()
	_status("Связь потеряна: возвращаемся в партию")
	print("[Net] connection lost: reconnecting")


func _drop_peer() -> void:
	rtc.close()
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


const REACHED_WAIT_S: float = 150.0  # connected to the host, waiting for its _rejoin_ok (its world build) — at most this


func _reconnect_tick(delta: float) -> void:
	rc_t += delta
	var reached: bool = _rc_reached_at >= 0.0 and multiplayer.multiplayer_peer != null and multiplayer.get_peers().has(1)
	if reached:
		if rc_t - _rc_reached_at > REACHED_WAIT_S:
			_give_up("ХОСТ НЕ ОТВЕЧАЕТ · МЕСТО СОХРАНЕНО", true)  # a hard cap: connected, but the host never let us in
		return  # waiting in the host's queue: no new try, no drop of this link, no short limit
	if _rc_reached_at >= 0.0:
		_rc_reached_at = -1.0  # the link we had is gone: try again, with the time this try had left
	if rc_t > (_rc_limit if _rc_limit > 0.0 else NetConfig.RECONNECT_S):
		var away: bool = bool(_rejoin.get("gone", false)) or _rc_card
		if not away:
			_rejoin["why"] = String(_rejoin.get("why", "lost"))  # NET 35 (critic): no answer - maybe our own link: «НЕТ СВЯЗИ С ХОСТОМ»
		_give_up(("ХОСТ ЕЩЁ НЕ ПРОДОЛЖИЛ ПАРТИЮ" if _rc_card else "ХОСТ ВЫШЕЛ · ПАРТИЯ СОХРАНЕНА") if away else "НЕ УДАЛОСЬ ВЕРНУТЬСЯ · МЕСТО СОХРАНЕНО", true)
		return
	if _rc_wait_host:
		if rc_t - _rc_started < 20.0 or String(_rejoin.get("code", "")) == "" or RankedRules.active() or String(_rejoin.get("match", "")) != "":  # (ROTATION: the server picks a new host: stay)
			return  # BACKEND 1: the server waits for the host on this socket and connects us itself
		_rc_wait_host = false  # (BH #2) 20 s: the host may have resumed by the room code (no match id on his side): try that once
		_rc_code_once = true
		_rc_next = rc_t
	if _rc_busy and rc_t - _rc_started < 12.0:
		return  # NET 32 (critic): a try through TURN on a phone network can take a while: not cut
	if rc_t < _rc_next:
		return
	_rc_next = rc_t + NetConfig.RECONNECT_EVERY
	rc_tries += 1
	_rc_busy = true
	_rc_started = rc_t
	_drop_peer()
	if String(_rejoin.get("mode", "lan")) == "online":
		mode = Mode.ONLINE
		if not rtc.joined_room.is_connected(_on_rtc_joined):
			rtc.joined_room.connect(_on_rtc_joined, CONNECT_ONE_SHOT)
		browser.stop()
		_rc_wait_host = false
		_rc_resume = String(_rejoin.get("match", "")) != "" and not RtcLink.relay_only() and not _rc_code_once
		_rc_code_once = false
		if _rc_resume:
			rtc.snap = exec_turn  # BACKEND 3: the freshest world wins the host's seat (ranked)
			rtc.resume(String(_rejoin["match"]), String(_rejoin.get("tok", "")))  # BACKEND 1: the server checks the seat
		else:
			rtc.join(String(_rejoin.get("code", "")), String(_rejoin.get("tok", "")))
	else:
		mode = Mode.LAN
		var p := ENetMultiplayerPeer.new()
		if p.create_client(String(_rejoin.get("ip", "")), int(_rejoin.get("port", NetConfig.LAN_PORT))) == OK:
			multiplayer.multiplayer_peer = p
	print("[Net] reconnect try %d" % rc_tries)


func _give_up(why: String, host_away: bool = false) -> void:
	if not _rejoin.is_empty():
		if host_away:
			_rejoin["gone"] = true  # NET 35: kept 3 days: the host may resume the match
			if not _rejoin.has("gone_t"):
				_rejoin["gone_t"] = int(Time.get_unix_time_from_system())
		NetConfig.save_rejoin(_rejoin)
	_rc_limit = 0.0
	_rc_card = false
	reconnecting = false
	rejoining = false
	status_text = why
	leave(true, true, true)  # the place stays saved: «ВЕРНУТЬСЯ В ПАРТИЮ» in «Мультиплеер»


## «ВЕРНУТЬСЯ В ПАРТИЮ» (menu): the saved place of a match that is still running. "" = trying.
func rejoin() -> String:
	var entry_error: String = _network_entry_error()
	if entry_error != "":
		return entry_error
	var d: Dictionary = NetConfig.load_rejoin()
	if d.is_empty():
		return "Нет партии, в которую можно вернуться"
	leave(false, false, true)
	_suspend_multiplayer_mods(true)
	_rejoin = d
	is_host = false
	_start_reconnect()
	_rc_card = true
	_rc_limit = NetConfig.REJOIN_GONE_TRY_S if bool(d.get("gone", false)) else 0.0  # NET 35: a resumed room answers at once
	_status("Возвращаемся в партию...")
	return ""


## Host: a person of slot `s` came back (new peer `from`): his seat, his country (the AI gives it
## back by a command), then a snapshot for everybody (the host too: one state for all).
func _rejoin_slot(s: int, from: int) -> void:
	if resume_wait:
		if _restoring:
			_resume_q.append([s, from])  # NET 35: the world is not there yet: his snapshot after the load
			return
		_resume_back(s, from)
		return
	var old: int = int(slots[s]["peer"])
	var was_left: bool = bool(slots[s].get("left", false))
	slots[s]["peer"] = from
	slots[s]["left"] = false
	slots[s].erase("rot")
	_ready_peers[from] = true
	if old != from and multiplayer.get_peers().has(old):
		multiplayer.multiplayer_peer.disconnect_peer(old)  # the stale connection of the same person
	var cfg: Dictionary = {}
	for n: String in CFG_KEYS:
		cfg[n] = (GameConfig as GDScript).get(n)
	if mode == Mode.ONLINE and RtcLink.relay_only() and rtc.socket_open():
		rtc.reserve(String(_tokens.get(s, "")))
	_roster.rpc(slots)
	_rejoin_ok.rpc_id(from, s, slots, cfg, host_active, speed, speed_why, speed_who, wants, _late_cap_deadlines)
	_pending.append({"k": "human", "c": s + 1, "s": -1, "q": 0, "back": was_left,
		"name": String(slots[s].get("name", "Player")), "flag": clean_flag(slots[s].get("flag", "")), "arch": slot_arch(s)})
	if not was_left:
		print("[Net] (the old link of slot %d was still open)" % s)
	print("[Net] %s rejoined (slot %d)" % [String(slots[s]["name"]), s])


@rpc("authority", "call_remote", "reliable")
func _rejoin_ok(s: int, sl: Array, cfg: Dictionary, ha: bool, spd: int, why: String, who: String, ws: Array, late_caps: Dictionary) -> void:
	for n: String in cfg:
		if CFG_KEYS.has(n):
			(GameConfig as GDScript).set(n, cfg[n])
	GameConfig.tutorial = false
	_reset_lockstep()
	slots = sl
	local_slot = s
	in_match = true
	reconnecting = false
	_rc_limit = 0.0  # (2026-10-31) the short «ВЕРНУТЬСЯ» limit is for that one try: a later drop gets the usual one
	_rc_card = false
	_rc_reached_at = -1.0
	_rj_total = 0.0
	match_decided = false  # (critic) a match to come back into is still going
	rejoining = true  # the turns wait for the snapshot (_restore_from)
	host_active = ha
	var old_spd: int = speed
	speed = spd
	speed_why = why
	speed_who = who
	wants = ws
	_late_cap_deadlines = late_caps.duplicate(true)
	my_want = int(ws[s]) if s < ws.size() else 1  # the host still counts the old wish
	speed_changed.emit(old_spd, speed)
	if main != null and main.has_method("_apply_speed"):
		main._apply_speed()
	_rj_t = 0.0
	gw.net_driven = true
	if _rejoin.has("gone"):
		_rejoin.erase("gone")  # NET 35: the host is back
		_rejoin.erase("gone_t")
		_rejoin.erase("why")
		NetConfig.save_rejoin(_rejoin)
	if main != null and main.has_method("net_rejoin_wait"):
		main.net_rejoin_wait()
	_status("Возвращаемся в партию...")


# ------------------------------------------------------------------ the played time of a match (2026-10-31)
# Real seconds the match really ran with another person connected — the host: a live guest peer; a guest: the host —
# and not waiting for a way back / a snapshot. The host sends it in /end: a match counts in the profile only after
# MP_PLAYED_MIN_SECONDS of it (a crash, the downtime and the reconnects are not play). Every device counts (a guest
# promoted to the host carries its own count on); the host's count goes into its saved match (a resume goes on).
var _played_s: float = 0.0
## (2026-10-31) the match has a winner (main._on_match_end): leaving now ends it (/end — counted in the profiles),
## never hands it over. Was: «В МЕНЮ» after the victory with a guest still on sent /leave, and nobody got the match.
var match_decided: bool = false
var _played_mid: String = ""  # the match it counts (another match id = a new count)
var _rc_reached_at: float = -1.0  # rc_t when the host was reached in this way back (-1 = not reached)
var _rj_total: float = 0.0  # seconds since _rejoin_ok (a hard cap on the whole rejoin, whatever it waits for)


func _played_tick(delta: float) -> void:
	if not in_match or not go or reconnecting or rejoining or resume_wait or multiplayer.multiplayer_peer == null:
		return
	if match_id != _played_mid:
		_played_mid = match_id
		_played_s = float(_rejoin.get("played", 0.0)) if String(_rejoin.get("match", "")) == match_id else 0.0
	if is_host:
		for i in slots.size():
			if i != local_slot and _live(i) and multiplayer.get_peers().has(int(slots[i].get("peer", 0))):
				_played_s += delta
				return
	elif multiplayer.get_peers().has(1):
		_played_s += delta


# ------------------------------------------------------------------ REPORTS: the link measured for a report on the server
# Every 2 s a small unreliable ping (guest -> host, host -> each guest), echoed back: round trip, its spread and the
# share lost of the last 30. UI / reports only — never the simulation.
const PING_S: float = 2.0
var _ping_t: float = 0.0
var _ping_id: int = 0
var _ping_out: Dictionary = {}  # id -> msec sent
var _rtts: Array = []  # the last 30 round trips, ms
var _ping_sent: int = 0
var _ping_lost: int = 0


func _ping_tick(delta: float) -> void:
	if not in_match or mode == Mode.OFF or multiplayer.multiplayer_peer == null:
		return
	_ping_t += delta
	if _ping_t < PING_S:
		return
	_ping_t = 0.0
	var now: int = Time.get_ticks_msec()
	for id: int in _ping_out.keys():
		if now - int(_ping_out[id]) > 5000:
			_ping_out.erase(id)
			_ping_lost += 1  # no echo in 5 s
	var to: Array = [1] if not is_host else multiplayer.get_peers()
	for p: int in to:
		if not multiplayer.get_peers().has(p):
			continue
		_ping_id += 1
		_ping_out[_ping_id] = now
		_ping_sent += 1
		_ping_rq.rpc_id(p, _ping_id)


@rpc("any_peer", "call_remote", "unreliable")
func _ping_rq(id: int) -> void:
	var from: int = multiplayer.get_remote_sender_id()
	if not is_host and from != 1:
		return  # (critic) star: a guest echoes the host only
	_pong.rpc_id(from, id)


@rpc("any_peer", "call_remote", "unreliable")
func _pong(id: int) -> void:
	if not _ping_out.has(id):
		return
	_rtts.append(Time.get_ticks_msec() - int(_ping_out[id]))
	_ping_out.erase(id)
	if _rtts.size() > 30:
		_rtts.pop_front()


## The numbers a server report carries (the backend keeps only known keys: report.TELEMETRY_KEYS).
func net_stats() -> Dictionary:
	var avg: float = 0.0
	var mx: float = 0.0
	for r: int in _rtts:
		avg += float(r)
		mx = maxf(mx, float(r))
	avg = avg / float(_rtts.size()) if not _rtts.is_empty() else -1.0
	var jit: float = 0.0
	for i in range(1, _rtts.size()):
		jit += absf(float(_rtts[i]) - float(_rtts[i - 1]))
	jit = jit / float(_rtts.size() - 1) if _rtts.size() > 1 else 0.0
	return {"rtt_avg": avg, "rtt_max": mx, "jitter": jit, "loss_pct": 100.0 * float(_ping_lost) / float(maxi(1, _ping_sent)),
		"fps": Engine.get_frames_per_second(), "backlog": float(maxi(0, last_turn - exec_turn)), "resyncs": float(resyncs),
		"desyncs": float(desyncs), "speed": float(speed), "game_time": gw.game_time if gw != null else 0.0,
		"players": float(slots.size()), "link": "tunnel" if multiplayer.multiplayer_peer is WsTunnelPeer else ("webrtc" if mode == Mode.ONLINE else "lan"),
		"version": NetConfig.version(), "platform": OS.get_name(), "mode": "ranked" if RankedRules.active() else "casual",
		"net_mode": "host" if is_host else "guest"}


## CHAT: an envelope for the diplomatic chat (DipChat.on_env checks who may send what).
@rpc("any_peer", "call_remote", "reliable")
func _chat(env: Dictionary) -> void:
	if in_match:
		chat.on_env(env, multiplayer.get_remote_sender_id())


## CHAT guest: everything goes to the host (star).
func chat_to_host(env: Dictionary) -> bool:
	if multiplayer.multiplayer_peer != null and multiplayer.get_peers().has(1):
		_chat.rpc_id(1, env)
		return true
	return false  # no link to the host now (a reconnect): the sender's line says so, not «sent»


## CHAT host: to the device that sits on env.to_seat now (never back to who sent it).
func chat_route(env: Dictionary, from_peer: int = 0) -> void:
	var to: int = int(env.get("to_seat", 0))
	for i in slots.size():
		if int(slots[i].get("seat", 0)) == to and i != local_slot:
			var p: int = int(slots[i].get("peer", 0))
			if p > 1 and p != from_peer and multiplayer.get_peers().has(p):
				_chat.rpc_id(p, env)
			return


## A guest leaves on purpose (the others read «ВЫШЕЛ», not «ПРОПАЛА СВЯЗЬ»).
@rpc("any_peer", "call_remote", "reliable")
func _bye() -> void:
	var s: int = _slot_of(multiplayer.get_remote_sender_id())
	if is_host and s >= 0:
		slots[s]["bye"] = true


@rpc("authority", "call_remote", "reliable")
func _match_over() -> void:
	NetConfig.clear_rejoin()
	_rejoin = {}
	status_text = "Хост закончил партию"
	leave(true, true)


## Host, at the start: every guest gets a secret token for its seat (it comes back with it).
@rpc("authority", "call_remote", "reliable")
func _rejoin_tok(tok: String, host_nick: String) -> void:
	_rejoin = {"mode": "online" if mode == Mode.ONLINE else "lan", "ip": _join_ip, "port": _join_port,
		"code": room_code, "tok": tok, "host": host_nick, "match": match_id}
	NetConfig.save_rejoin(_rejoin)


func _name_slot(nm: String) -> int:
	for i in slots.size():
		if String(slots[i].get("name", "")).to_lower() == NetConfig.clean_nick(nm).to_lower():
			return i
	return -1


## BACKEND 3 ranked: the server made this device the host. It goes on from its own world (the freshest one):
## turns are issued from the last one it holds; the old host's country goes to the AI; the guests come back
## (server «peer») and get this world as a snapshot.
func _on_promoted() -> void:
	if not in_match or is_host:
		return  # (critic) a repeated host_changed{you:true} must not drop the connected guests
	_swapping = true
	if RtcLink.relay_only():
		multiplayer.multiplayer_peer = rtc.tunnel
	else:
		multiplayer.multiplayer_peer = rtc.peer
	is_host = true
	reconnecting = false
	rejoining = false
	_rc_wait_host = false
	for i in slots.size():
		if i == local_slot:
			slots[i]["peer"] = 1
			slots[i]["left"] = false
		elif int(slots[i].get("peer", 0)) == 1:
			slots[i]["left"] = true  # the old host: the AI plays him until he is back
			_pending.append({"k": "ai", "c": i + 1, "s": -1, "q": 0, "lost": true})
			slots[i]["peer"] = -100 - i
		else:
			if not RtcLink.relay_only():
				slots[i]["left"] = true  # the guests come back through the server (their new peer ids)
				slots[i]["rot"] = true  # (critic) not «left» in the report while they are coming back
				slots[i]["peer"] = -100 - i
			else:
				# in relay mode, peers are already connected to relay
				var pid: int = int(slots[i].get("peer", 0))
				slots[i]["left"] = not (multiplayer.get_peers().has(pid) or pid > 1)
	_host_turn = maxi(last_turn + 1, exec_turn)  # the first turn this device lacks (exec waits for exec_turn)
	go = true
	host_active = true
	match_id = rtc.match_id
	_way_back_t = -1.0
	_status("Вы теперь хост · матч продолжается")
	if main != null and main.has_method("net_toast"):
		main.net_toast("ВЫ ТЕПЕРЬ ХОСТ · МАТЧ ПРОДОЛЖАЕТСЯ")
	print("[Net] promoted to host at turn %d (epoch %d)" % [exec_turn, rtc.epoch])
	get_tree().create_timer(30.0).timeout.connect(func() -> void:  # (critic) a guest who never came back: the AI
		if not in_match or not is_host:
			return
		for j in slots.size():
			if bool(slots[j].get("rot", false)) and bool(slots[j].get("left", false)):
				slots[j].erase("rot")
				_pending.append({"k": "ai", "c": j + 1, "s": -1, "q": 0, "lost": true}))
	await get_tree().process_frame
	_swapping = false


func _tok_slot(tok: String) -> int:
	if tok == "":
		return -1
	for s: int in _tokens:
		if String(_tokens[s]) == tok:
			return s
	return -1


func send_lobby_chat(text: String) -> bool:
	if not active() or in_match or local_slot < 0:
		return false
	text = _clean_lobby_chat(text)
	var now: int = Time.get_ticks_msec()
	if text.is_empty() or now - _lobby_chat_local_ms < LOBBY_CHAT_INTERVAL_MS:
		return false
	_lobby_chat_local_ms = now
	if is_host:
		_accept_lobby_chat(1, text)
	else:
		_lobby_chat_request.rpc_id(1, text)
	return true


static func _clean_lobby_chat(text: String) -> String:
	return text.left(LOBBY_CHAT_LENGTH).replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges()


@rpc("any_peer", "call_remote", "reliable")
func _lobby_chat_request(text: String) -> void:
	if is_host and active() and not in_match:
		_accept_lobby_chat(multiplayer.get_remote_sender_id(), text)


func _accept_lobby_chat(peer_id: int, text: String) -> void:
	var slot: int = _slot_of(peer_id)
	if slot < 0 or _lobby_kicking.has(peer_id):
		return
	text = _clean_lobby_chat(text)
	var now: int = Time.get_ticks_msec()
	if text.is_empty() or now - int(_lobby_chat_sent.get(peer_id, -LOBBY_CHAT_INTERVAL_MS)) < LOBBY_CHAT_INTERVAL_MS:
		return
	_lobby_chat_sent[peer_id] = now
	var sender: String = String(slots[slot]["name"])
	_lobby_chat_add(sender, text)
	for member: Dictionary in slots:
		var target: int = int(member["peer"])
		if target != 1 and multiplayer.get_peers().has(target):
			_lobby_chat_add.rpc_id(target, sender, text)


@rpc("authority", "call_remote", "reliable")
func _lobby_chat_add(sender: String, text: String) -> void:
	if not active() or in_match:
		return
	lobby_chat.append({"name": sender, "text": text})
	if lobby_chat.size() > LOBBY_CHAT_HISTORY:
		lobby_chat.pop_front()
	lobby_chat_received.emit()


func kick_lobby_player(peer_id: int) -> bool:
	if not active() or not is_host or in_match or not rtc.ranked.is_empty():
		return false
	var slot: int = _slot_of(peer_id)
	var transport: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer_id <= 1 or slot < 1 or not multiplayer.get_peers().has(peer_id):
		return false
	_lobby_kicking[peer_id] = true
	_kick.rpc_id(peer_id, "lobby_removed")
	_flush_peer()
	_remove_lobby_slot(slot)
	get_tree().create_timer(0.75).timeout.connect(func() -> void:
		if multiplayer.multiplayer_peer != transport or not _lobby_kicking.has(peer_id):
			return
		if multiplayer.get_peers().has(peer_id):
			transport.disconnect_peer(peer_id)
		_lobby_kicking.erase(peer_id))
	return true


func _slot_of(peer: int) -> int:
	for i in slots.size():
		if int(slots[i]["peer"]) == peer:
			return i
	return -1


@rpc("any_peer", "call_remote", "reliable")
func _hello(ver: String, nm: String, arch: int = 0, tok: String = "", cos: Dictionary = {}, flag: String = "", client_mods: Dictionary = {}) -> void:
	if not is_host:
		return
	var from: int = multiplayer.get_remote_sender_id()
	if _lobby_kicking.has(from) or (not in_match and _slot_of(from) >= 0):
		return
	var why: String = ""  # R333 I18N: a code on the wire («full» / «running» / «version:<host>»); the guest words it (_kick_text)
	if ver != NetConfig.version():
		why = "version:" + NetConfig.version()
	elif not host_mods.is_empty() and has_node("/root/ModManager"):
		var mm = get_node("/root/ModManager")
		if mm.has_method("check_missing_mp_mods"):
			var missing: Array = mm.check_missing_mp_mods(host_mods, client_mods)
			if not missing.is_empty():
				_require_mods.rpc_id(from, host_mods)
				return
	elif in_match and _tok_slot(tok) >= 0 and (go or resume_wait):
		_rejoin_slot(_tok_slot(tok), from)  # NET 32: the same person back into his seat
		return
	elif in_match and (go or resume_wait) and not rtc.ranked.is_empty():
		why = "running"
	elif in_match and (go or resume_wait):
		var clean_nm: String = NetConfig.clean_nick(nm)
		var s_name: int = _name_slot(clean_nm)
		if s_name >= 0 and s_name != local_slot:
			var slot_avail: bool = bool(slots[s_name].get("left", false)) or resume_wait or not multiplayer.get_peers().has(int(slots[s_name].get("peer", 0)))
			if slot_avail:
				var cur_tok: String = tok
				if cur_tok == "":
					cur_tok = String(_tokens.get(s_name, ""))
				if cur_tok == "":
					cur_tok = _gen_tok()
				_tokens[s_name] = cur_tok
				_rejoin_tok.rpc_id(from, cur_tok, my_name())
				_rejoin_slot(s_name, from)
				lan.update_info({"n": slots.size()})
				return
		elif mode == Mode.ONLINE and rtc.peer_names.has(from) and _name_slot(String(rtc.peer_names[from])) >= 0 and _name_slot(String(rtc.peer_names[from])) != local_slot:
			_rejoin_slot(_name_slot(String(rtc.peer_names[from])), from)
			return
		# Reclaim a disconnected seat after checking its saved token and name.
		var candidate_slot: int = -1
		for i in range(1, slots.size()):
			if bool(slots[i].get("left", false)) and not multiplayer.get_peers().has(int(slots[i].get("peer", 0))):
				candidate_slot = i
				break
		if candidate_slot >= 0:
			slots[candidate_slot]["name"] = clean_nm if clean_nm != "" else "Player"
			slots[candidate_slot]["flag"] = clean_flag(flag)
			slots[candidate_slot]["cos"] = _clean_cos(cos)
			slots[candidate_slot].erase("away")
			slots[candidate_slot].erase("bye")
			var cur_tok2: String = _gen_tok()
			_tokens[candidate_slot] = cur_tok2
			_rejoin_tok.rpc_id(from, cur_tok2, my_name())
			_rejoin_slot(candidate_slot, from)
			lan.update_info({"n": slots.size()})
			return
		# An unassigned AI seat keeps its developed country and becomes human controlled.
		elif slots.size() < NetConfig.MAX_PLAYERS and gw != null and slots.size() < gw.countries.size():
			var new_slot: int = slots.size()
			var cid: int = new_slot + 1
			var cc: Country = gw.country_by_id(cid)
			if cc != null and not cc.is_player and not cc.eliminated:
				slots.append({
					"peer": from,
					"name": clean_nm if clean_nm != "" else "Player",
					"ready": true,
					"left": false,
					"arch": cc.arch,
					"seat": from,
					"cos": _clean_cos(cos),
					"flag": clean_flag(flag)
				})
				var cur_tok3: String = _gen_tok()
				_tokens[new_slot] = cur_tok3
				_rejoin_tok.rpc_id(from, cur_tok3, my_name())
				_rejoin_slot(new_slot, from)
				lan.update_info({"n": slots.size()})
				return
		# With no remaining AI country, append a fresh country if the world still has a slot.
		if slots.size() < NetConfig.MAX_PLAYERS and gw != null and gw.countries.size() == slots.size() and gw.countries.size() < NetConfig.MAX_PLAYERS:
			var fresh_slot: int = slots.size()
			var new_name: String = clean_nm if clean_nm != "" else "Player"
			var new_flag: String = clean_flag(flag)
			var capital_deadline: float = gw.game_time + NetConfig.CAPITAL_TIMEOUT_S
			slots.append({"peer": from, "name": new_name, "ready": true, "left": false, "arch": clampi(arch, 0, 3),
				"seat": from, "cos": _clean_cos(cos), "flag": new_flag})
			_tokens[fresh_slot] = _gen_tok()
			_late_cap_deadlines[fresh_slot + 1] = capital_deadline
			_rejoin_tok.rpc_id(from, String(_tokens[fresh_slot]), my_name())
			_pending.append({"k": "new", "s": -1, "q": 0, "peer": from, "name": new_name, "flag": new_flag,
				"arch": clampi(arch, 0, 3), "capital_deadline": capital_deadline})
			_rejoin_slot(fresh_slot, from)
			lan.update_info({"n": slots.size()})
			return
		why = "full" if slots.size() >= NetConfig.MAX_PLAYERS else "running"
	elif in_match:
		why = "running"
	elif slots.size() >= NetConfig.MAX_PLAYERS:
		why = "full"
	if why != "":
		_kick.rpc_id(from, why)
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if multiplayer.multiplayer_peer != null and multiplayer.get_peers().has(from):
				multiplayer.multiplayer_peer.disconnect_peer(from))
		return
	if not rtc.ranked.is_empty():
		nm = String(rtc.peer_names.get(from, ""))  # (critic) the server's name of this peer, not the one it claims
		if nm == "" or _team_of_name(nm) < 0 or _name_slot(nm) >= 0:
			_kick.rpc_id(from, "Вас нет в составе этого боя")
			return
	var clean: String = NetConfig.clean_nick(nm)
	slots.append({"peer": from, "name": clean if clean != "" else "Player", "ready": true, "left": false, "arch": clampi(arch, 0, 3), "cos": _clean_cos(cos), "flag": clean_flag(flag)})
	_roster.rpc(slots)
	for message: Dictionary in lobby_chat:
		_lobby_chat_add.rpc_id(from, message["name"], message["text"])
	lan.update_info({"n": slots.size()})
	_status("Игроков: %d" % slots.size())
	if not rtc.ranked.is_empty() and slots.size() >= _ranked_size():
		_ranked_ready_host()


@rpc("authority", "call_remote", "reliable")
func _require_mods(req_mods: Array) -> void:
	host_mods = req_mods
	mods_required.emit(req_mods)


@rpc("authority", "call_remote", "reliable")
func _roster(list: Array) -> void:
	slots = list
	if not slots.is_empty() and slots[0].has("mods"):
		host_mods = slots[0]["mods"]
	local_slot = _slot_of(multiplayer.get_unique_id())
	if not rtc.ranked.is_empty() and not is_host and not _ranked_ready_sent and local_slot >= 0:
		_ranked_ready_sent = true
		rtc.ready()  # BACKEND 2: reached the host (its tunnel): the server waits for everybody's «ready»
	_status("Игрок присоединился · %d в комнате" % slots.size() if in_match else "В комнате: %d · ждём, пока хост начнёт" % slots.size())


## R333 I18N: the kick reason in this player's language; a host older than R333 sends the Russian words (shown as is).
static func _kick_text(why: String) -> String:
	if why.begins_with("version:"):
		return Loc.f("Другая версия игры у хоста ({host}, у вас {mine}): обновите игру", {"host": why.trim_prefix("version:"), "mine": NetConfig.version()})
	match why:
		"running":
			return Loc.t("Партия уже идёт")
		"full":
			return Loc.t("Комната заполнена")
		"lobby_removed":
			return Loc.t("Хост исключил вас из комнаты")
	return why


@rpc("authority", "call_remote", "reliable")
func _kick(why: String) -> void:
	why = _kick_text(why)
	if reconnecting:
		_give_up(why)
		NetConfig.clear_rejoin()
		return
	leave(false, true)
	_status(why)


# ------------------------------------------------------------------ match start

## Host: start the match with the current setup-screen rules (GameConfig). "" = started.
func host_start() -> String:
	if not is_host or in_match:
		return "Начать может только хост"
	if slots.size() < 2:
		return "Нужен хотя бы один игрок в комнате"
	# Eight countries fit the map palette and simulation limit. Keep AI slots within that cap.
	var bot_slots: int = maxi(0, 8 - slots.size())
	if GameConfig.cb_on:
		CustomBots.sanitize()
		GameConfig.cb_list = GameConfig.cb_list.slice(0, mini(bot_slots, GameConfig.CB_MAX))
		GameConfig.bots = GameConfig.cb_list.size()
	else:
		GameConfig.bots = clampi(GameConfig.bots, 0, mini(6, bot_slots))
	var s := WorldSettings.new()
	s.world_seed = randi() % 100000000
	s.size = int(GameConfig.SIZES[GameConfig.size_i])
	GameConfig.apply_map(s, true)
	var cfg: Dictionary = {}
	for n: String in CFG_KEYS:
		cfg[n] = (GameConfig as GDScript).get(n)
	_tokens.clear()
	var crypto := Crypto.new()
	for i in range(1, slots.size()):  # NET 32: each guest's key to its seat (not guessable from randi)
		_tokens[i] = crypto.generate_random_bytes(16).hex_encode()
	lan.stop()  # the room is closed for newcomers
	if mode == Mode.ONLINE:
		rtc.seal(_tokens.values().map(func(t: String) -> String: return t.sha256_text()))  # only seat holders may come back
		_online_go(s, cfg)  # BACKEND 3: «turn» -> WebRTC with TURN -> the start (async)
		return ""
	_send_start(s, cfg)
	return ""


## R-NET: отпечаток активных модов (рассинхрон из-за разных модов — самая
## частая причина «постоянного рассинхрона»; теперь ловим до старта партии).
func _mods_fp() -> String:
	var ids: Array = []
	if has_node("/root/ModManager"):
		var mm: Node = get_node("/root/ModManager")
		var raw: Variant = mm.get("enabled_mod_ids")
		if raw is Array:
			ids = raw
	var parts: Array = []
	for id: Variant in ids:
		parts.append(str(id))
	parts.sort()
	return ",".join(parts)


## The start pack to every connected peer + the guests' seat tokens.
func _send_start(s: WorldSettings, cfg: Dictionary) -> void:
	for sl: Dictionary in slots:
		sl["seat"] = int(sl.get("peer", 0))  # CHAT: the seat = the peer id at the start (the server's «seats»); a later host change remaps «peer», never this
	_start.rpc({"seats": slots.map(func(sl: Dictionary) -> int: return int(sl["seat"])),"ws": Save.dump(s), "cfg": cfg, "n": slots.size(), "ranked": _ranked_pack(),
		"names": slots.map(func(sl: Dictionary) -> String: return String(sl.get("name", ""))),  # NET 29: country names
		"archs": slots.map(func(sl: Dictionary) -> int: return clampi(int(sl.get("arch", 0)), 0, 3)),  # NET 30: their styles
		"mods": _mods_fp(),  # R-NET: отпечаток модов — гости с другим набором не войдут
		"rust": FordCore.has_rust(),  # R-NET: у всех пиров должен быть один режим армии (Rust/GDScript)
		"flags": slots.map(func(sl: Dictionary) -> String: return clean_flag(sl.get("flag", "")))})  # MPFLAG: their own flags
	for i2: int in _tokens:
		if multiplayer.get_peers().has(int(slots[i2]["peer"])):
			_rejoin_tok.rpc_id(int(slots[i2]["peer"]), String(_tokens[i2]), my_name())


## BACKEND 3 host: after «seal» the server answers «turn» (TURN for the match); the guests connect directly
## (their offers through the socket); whoever is not reached in P2P_HOST_S starts as «left» (the AI plays him).
func _online_go(s: WorldSettings, cfg: Dictionary) -> void:
	var relay: bool = RtcLink.relay_only()
	_status("Партия создана · соединяем игроков через сервер..." if relay else "Партия создана · соединяем игроков напрямую...")
	lobby_changed.emit()
	var t0: int = Time.get_ticks_msec()
	while mode == Mode.ONLINE and not in_match and Time.get_ticks_msec() - t0 < int(P2P_HOST_S * 1000.0):
		var all: bool = false
		if relay:
			all = rtc.room_sealed() and rtc.tunnel != null and multiplayer.multiplayer_peer == rtc.tunnel
		else:
			all = rtc.peer != null and multiplayer.multiplayer_peer == rtc.peer
		for i in range(1, slots.size()):
			if all and not multiplayer.get_peers().has(int(slots[i]["peer"])):
				all = false
		if all:
			break
		await get_tree().process_frame
	if mode != Mode.ONLINE or in_match or not is_host:
		return  # left meanwhile
	var transport_ready: bool = false
	if relay:
		transport_ready = rtc.tunnel != null and multiplayer.multiplayer_peer == rtc.tunnel and rtc.room_sealed()
	else:
		transport_ready = rtc.peer != null and multiplayer.multiplayer_peer == rtc.peer
	if not transport_ready:
		leave(false, true)
		_status("Сервер не начал партию. Попробуйте ещё раз")
		return
	var lost: Array = []
	for i in range(1, slots.size()):
		if not multiplayer.get_peers().has(int(slots[i]["peer"])):
			lost.append(i)
	_send_start(s, cfg)
	for i3: int in lost:  # not reached directly: his country is the AI's from the first turn
		slots[i3]["left"] = true
		_pending.append({"k": "ai", "c": i3 + 1, "s": -1, "q": 0, "lost": true})
		print("[Net] %s not reached directly: the AI plays his country" % String(slots[i3]["name"]))
	if not lost.is_empty():
		_mark_ready(-1)


## BACKEND 3: «turn» came: the WebRTC peer takes over from the lobby tunnel (before its connections are up,
## so Godot sees them connect).
func _on_p2p_started() -> void:
	var t0: int = Time.get_ticks_msec()
	while rtc.tunnel != null and rtc.tunnel.get_available_packet_count() > 0 and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame  # (critic) what came over the tunnel before «turn» is read first
	_swapping = true
	multiplayer.multiplayer_peer = rtc.peer
	if is_host and not _ranked_go.is_empty():
		var go2: Array = _ranked_go
		_ranked_go = []
		_online_go(go2[0], go2[1])  # BACKEND 2: the server started the ranked match by itself
	if not is_host:
		_p2p_wait = P2P_GUEST_S
		_status("Партия начинается · соединяемся с хостом напрямую...")
	await get_tree().process_frame
	_swapping = false


@rpc("authority", "call_local", "reliable")
func _start(pack: Dictionary) -> void:
	# R-NET: до старта сверяем моды и режим движка армий — расхождение = гарантированный
	# рассинхрон, теперь внятная ошибка вместо бесконечных «СИНХРОНИЗАЦИЯ».
	if not is_host:
		var fp_in: String = String(pack.get("mods", ""))
		if fp_in != "" and fp_in != _mods_fp():
			leave(false, true)
			_status("Моды не совпадают с хостом: выровняйте наборы модов и попробуйте снова")
			return
		if bool(pack.get("rust", false)) != FordCore.has_rust():
			leave(false, true)
			_status("Разные версии Reborn: у хоста и у вас разный движок армий. Скачайте тот же релиз")
			return
	var cfg: Dictionary = pack["cfg"]
	for n: String in cfg:
		if CFG_KEYS.has(n):
			(GameConfig as GDScript).set(n, cfg[n])
	GameConfig.tutorial = false
	GameConfig.map_seed = -1
	GameConfig.ranked = pack.get("ranked", {})  # BACKEND 2: the same teams on every device (the pack, checked below)
	if not GameConfig.ranked.is_empty() and not is_host:
		var bad: String = _ranked_check(GameConfig.ranked, pack)
		if bad != "":
			push_warning("[Net] ranked: the host's pack differs from the server's lobby: %s" % bad)
			var mid0: String = String(GameConfig.ranked.get("match", match_id))
			if mid0 != "":
				Ranked.report(mid0, null, [])  # (critic) not a result: the two teams disagree -> disputed
			RankedRules.clear()
			leave(false, true)
			_status("Хост подменил настройки боя · результат оспорен")
			return
	var s := WorldSettings.new()
	Save.fill(s, pack["ws"])
	_reset_lockstep()
	in_match = true
	if is_host:
		_start_t = 0.0  # peers that never finish loading are dropped after 60 s
	gw.net_driven = true
	gw.net_tick = 0
	start_names = pack.get("names", [])
	var seats: Array = pack.get("seats", [])
	for i in mini(seats.size(), slots.size()):
		slots[i]["seat"] = int(seats[i])
	chat.reset()
	_played_s = 0.0  # a new match
	match_decided = false
	_played_mid = ""
	_rtts.clear()  # REPORTS: the link numbers are this match's
	_ping_out.clear()
	_ping_sent = 0
	_ping_lost = 0
	start_archs = pack.get("archs", [])
	start_flags = (pack.get("flags", []) as Array).map(func(f: Variant) -> String: return clean_flag(f))
	if mode == Mode.ONLINE:
		await rtc.wait_turn()  # BACKEND 1: the match id first (a busy frame loses «turn»; the lockstep start waits for all anyway)
	await main.net_begin(s, int(pack["n"]), local_slot)
	if is_host:
		_mark_ready(1)
	else:
		_ready_rq.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _ready_rq() -> void:
	if is_host:
		_mark_ready(multiplayer.get_remote_sender_id())


func _mark_ready(peer: int) -> void:
	if go:
		return
	if peer > 0:
		_ready_peers[peer] = true
	for sl: Dictionary in slots:
		if not bool(sl.get("left", false)) and not _ready_peers.has(int(sl["peer"])):
			return
	_begin.rpc()


@rpc("authority", "call_local", "reliable")
func _begin() -> void:
	go = true
	_status("Партия идёт")


# ------------------------------------------------------------------ NET 35: saved network match

var _resume: Dictionary = {}  # host: the saved match being resumed
var _resume_q: Array = []  # host: [slot, peer] back while the world was still loading (served after it)
var _saved_turn: int = -1


## Host: the match into user://net_match.save (snapshot of the end of turn `n`, seats, tokens, rules,
## the room). Every MATCH_SAVE_TURNS turns, when the app goes to the background, when it is closed.
func save_match(n: int = -1, force: bool = false) -> void:
	if not is_host or not in_match or _restoring:
		return
	if not force and (not go or resume_wait):
		return
	if n < 0:
		n = exec_turn - 1
	if not force and n == _saved_turn:
		return  # NET 35 (critic): FOCUS_OUT + PAUSED come together
	_saved_turn = n
	var cfg: Dictionary = {}
	for k: String in CFG_KEYS:
		cfg[k] = (GameConfig as GDScript).get(k)
	var sl: Array = []
	for i in slots.size():  # "left": gone before the save (the AI plays him): a resume does not wait for him
		sl.append({"name": String(slots[i].get("name", "")), "arch": slot_arch(i), "left": i > 0 and bool(slots[i].get("left", false)),
			"seat": int(slots[i].get("seat", 0)), "flag": clean_flag(slots[i].get("flag", ""))})  # CHAT / MPFLAG: kept through a resume
	var tk: Dictionary = {}
	for s: int in _tokens:
		tk[str(s)] = String(_tokens[s])
	var t0: int = Time.get_ticks_msec()
	NetConfig.save_match({"v": NetConfig.version(), "turn": n, "mode": "online" if mode == Mode.ONLINE else "lan",
		"code": room_code, "pub": room_pub, "port": NetConfig.LAN_PORT, "host": my_name(), "slots": sl, "tokens": tk, "match": match_id,
		"cfg": cfg, "gt": gw.game_time if gw != null else 0.0, "played": _played_s,
		"late_caps": _late_cap_deadlines, "snap": Save.net_snapshot(main)})
	print("[Net] match saved at turn %d (%d ms)" % [n, Time.get_ticks_msec() - t0])


## Host closes the app (window ✕): save, tell the guests «the host left, the match is saved» (they
## keep their places: «ВЕРНУТЬСЯ В ПАРТИЮ»), close the room without ending the match.
func host_exit_saved() -> void:
	if not is_host or not in_match:
		return
	if match_decided:
		leave(false)  # the app closes after the victory: the match ends (and counts), nothing to resume
		return
	if can_hand_over():
		leave(false)  # ROTATION: the guests go on with a new host; this device may come back as a guest
		return
	if go or resume_wait:
		save_match(-1, true)
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		_host_gone.rpc()
		for i in 8:  # the app is closing: give the message ~0.3 s to leave before the link goes (else they only see «lost»)
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
				_flush_peer()
			multiplayer.multiplayer_peer.poll()
			OS.delay_msec(40)
	leave(false, false, false, true)


## Host manually clicks «СОХРАНИТЬ И ВЫЙТИ»: save match, tell guests host exited with match saved,
## keep match in net_match.save, leave match and return to menu.
func host_save_and_exit() -> void:
	if not is_host or not in_match:
		leave(false)
		return
	if match_decided:
		leave(false)
		return
	if can_hand_over():
		leave(false)
		return
	save_match(-1, true)
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		_host_gone.rpc()
		for i in 8:
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
				_flush_peer()
			multiplayer.multiplayer_peer.poll()
			OS.delay_msec(40)
	leave(false, false, false, true)


@rpc("authority", "call_remote", "reliable")
func _host_gone() -> void:
	if _rejoin.is_empty():
		return
	_rejoin["gone"] = true
	_rejoin["why"] = "left"
	_rejoin["gone_t"] = int(Time.get_unix_time_from_system())
	NetConfig.save_rejoin(_rejoin)
	status_text = "ХОСТ ВЫШЕЛ · ПАРТИЯ СОХРАНЕНА"
	leave(true, true, true)


## Host: «ПРОДОЛЖИТЬ ПАРТИЮ». The room again (online: the old code), the world from the save, then
## the world stands until the players are back (resume_go: all back, «ИГРАТЬ БЕЗ НИХ», RESUME_WAIT_S).
## "" = resuming.
func resume_host() -> String:
	var entry_error: String = _network_entry_error()
	if entry_error != "":
		return entry_error
	var d: Dictionary = NetConfig.load_match()
	if d.is_empty():
		return "Нет сохранённой партии"
	if String(d.get("v", "")) != NetConfig.version():
		return "Партия сохранена в другой версии игры"
	var online: bool = String(d.get("mode", "lan")) == "online"
	if online and not RtcLink.available():
		return "WebRTC недоступен в этой сборке"
	leave(false, false, true, true)
	_suspend_multiplayer_mods(true)
	var cfg: Dictionary = d.get("cfg", {})
	for k: String in cfg:
		if CFG_KEYS.has(k):
			(GameConfig as GDScript).set(k, cfg[k])
	GameConfig.tutorial = false
	_reset_lockstep()
	_late_cap_deadlines = (d.get("late_caps", {}) as Dictionary).duplicate(true)
	is_host = true
	local_slot = 0
	slots = []
	var sl: Array = d.get("slots", [])
	var me: String = Account.username() if online and Account.username() != "" else NetConfig.nick()  # BH v0.30.25: mode is not ONLINE yet here: my_name() gave the Wi-Fi nick
	for i in sl.size():
		slots.append({"peer": 1 if i == 0 else -100 - i, "name": me if i == 0 else String((sl[i] as Dictionary).get("name", "Игрок")),
			"ready": true, "left": i > 0, "away": bool((sl[i] as Dictionary).get("left", false)), "arch": clampi(int((sl[i] as Dictionary).get("arch", 0)), 0, 3),
			"seat": int((sl[i] as Dictionary).get("seat", 0)), "flag": clean_flag((sl[i] as Dictionary).get("flag", ""))})
	_tokens.clear()
	var tk: Dictionary = d.get("tokens", {})
	for k2: Variant in tk:
		_tokens[int(k2)] = String(tk[k2])
	_resume = d
	_resume_q.clear()
	_saved_turn = int(d.get("turn", -1))
	match_decided = false  # (critic) a resumed match has no winner yet
	_played_s = float(d.get("played", 0.0))  # the played time goes on after a resume
	_played_mid = String(d.get("match", ""))
	in_match = true
	go = false
	resume_wait = true
	resume_t = 0.0
	gw.net_driven = true
	if online:
		mode = Mode.ONLINE
		room_pub = bool(d.get("pub", false))
		browser.stop()
		match_id = String(d.get("match", ""))
		if match_id != "":
			rtc.resume(match_id)  # BACKEND 1: the match still lives on the server: the guests come back by «resume»
		else:
			rtc.host(room_pub, String(d.get("code", "")))
	else:
		mode = Mode.LAN
		var p := ENetMultiplayerPeer.new()
		var err: int = p.create_server(int(d.get("port", NetConfig.LAN_PORT)), NetConfig.MAX_PLAYERS - 1)
		if err != OK:
			leave(false, false, true, true)
			return "Порт %d занят (%s)" % [int(d.get("port", NetConfig.LAN_PORT)), error_string(err)]
		multiplayer.multiplayer_peer = p
		lan.announce({"name": NetConfig.nick(), "port": int(d.get("port", NetConfig.LAN_PORT)), "n": slots.size()})
	if main != null and main.has_method("net_rejoin_wait"):
		main.net_rejoin_wait()
	_status("Восстанавливаем партию...")
	_resume_restore(d)
	return ""


func _resume_restore(d: Dictionary) -> void:
	_own_fog = true
	await _restore_from(d.get("snap", PackedByteArray()), int(d.get("turn", 0)))
	_own_fog = false
	if not in_match:
		return
	_host_turn = int(d.get("turn", 0)) + 1
	last_turn = int(d.get("turn", 0))
	print("[Net] resumed the saved match at turn %d: waiting for %d players" % [last_turn, _resume_counts()[1]])
	var q: Array = _resume_q
	_resume_q = []
	for e: Array in q:
		if multiplayer.get_peers().has(int(e[1])):
			_resume_back(int(e[0]), int(e[1]))
	if _resume_counts()[1] == 0:
		resume_go(false)


## Host: a person of slot `s` is back during the wait: his seat, the world as it stands (only to him).
func _resume_back(s: int, from: int) -> void:
	var bytes: PackedByteArray = _resume.get("snap", PackedByteArray())  # the exact state restored by the host
	if bytes.is_empty() and main != null:
		bytes = Save.net_snapshot(main)
	if bytes.is_empty():
		# Do not mark the returning player ready or send an impossible zero-part snapshot.
		# The guest remains in the existing reconnect flow and can retry.
		print("[Net] could not prepare snapshot for returning peer %d" % from)
		_status("Не удалось подготовить мир для возвращения игрока")
		return
	slots[s]["peer"] = from
	slots[s]["left"] = false
	slots[s].erase("rot")
	_ready_peers[from] = true
	_roster.rpc(slots)
	var cfg: Dictionary = {}
	for n: String in CFG_KEYS:
		cfg[n] = (GameConfig as GDScript).get(n)
	_rejoin_ok.rpc_id(from, s, slots, cfg, host_active, speed, speed_why, speed_who, wants, _late_cap_deadlines)
	_resume_note()
	var ch: int = NetConfig.SNAP_CHUNK
	var parts: int = ceili(float(bytes.size()) / float(ch))
	var snap_turn: int = int(_resume.get("turn", _host_turn - 1))
	_last_snap[from] = snap_turn
	_last_snap_ms[from] = Time.get_ticks_msec()
	_sync_wait[from] = {"turn": snap_turn, "started_ms": Time.get_ticks_msec()}
	_snap_begin.rpc_id(from, snap_turn, bytes.size(), parts)  # the world stands at the saved turn
	for i in parts:
		_snap_part.rpc_id(from, i, bytes.slice(i * ch, mini((i + 1) * ch, bytes.size())))
	print("[Net] %s is back in the resumed match (slot %d, waiting for snap ack)" % [String(slots[s]["name"]), s])
	lobby_changed.emit()
	if _resume_counts()[0] >= _resume_counts()[1]:
		resume_go(false)


## Host: [back, waited for] (people gone before the save are not waited for).
func _resume_counts() -> Array:
	var back_n: int = 0
	var all_n: int = 0
	for i in range(1, slots.size()):
		if not bool(slots[i].get("left", false)):
			back_n += 1
			all_n += 1
		elif not bool(slots[i].get("away", false)):
			all_n += 1
	return [back_n, all_n]


## Host: the people not back yet, «ВАДИМ» / «ВАДИМ +1».
func _missing_text() -> String:
	var miss: Array = []
	for i in range(1, slots.size()):
		if bool(slots[i].get("left", false)) and not bool(slots[i].get("away", false)):
			miss.append(String(slots[i].get("name", "?")).to_upper())
	if miss.is_empty():
		return ""
	return String(miss[0]) + ((" +%d" % (miss.size() - 1)) if miss.size() > 1 else "")


## Host: the wait's numbers to every guest that is back (their plate).
func _resume_note() -> void:
	if not is_host:
		return
	var c: Array = _resume_counts()
	for i2 in range(1, slots.size()):
		if not bool(slots[i2].get("left", false)) and int(slots[i2]["peer"]) > 0:
			_resume_state.rpc_id(int(slots[i2]["peer"]), resume_wait, int(c[0]), int(c[1]), _missing_text(), resume_t)


@rpc("authority", "call_remote", "reliable")
func _resume_state(on: bool, back_n: int, all_n: int, miss: String, waited: float = 0.0) -> void:
	resume_wait = on
	resume_back = back_n
	resume_total = all_n
	resume_missing = miss
	resume_t = waited  # NET 35 (critic): the guest's plate counts the same timer down
	stall_t = 0.0
	lobby_changed.emit()


## Host: the resumed match goes on («ИГРАТЬ БЕЗ НИХ», everybody back, or the wait ran out). The AI
## plays who is not back (he can still come back later: NET 32), the people back get their countries.
func resume_go(by_time: bool = false) -> void:
	if not is_host or not resume_wait or _restoring:
		return
	resume_wait = false
	var missing: int = 0
	for i in range(1, slots.size()):
		if bool(slots[i].get("left", false)):
			missing += 1
			_pending.append({"k": "ai", "c": i + 1, "s": -1, "q": 0, "lost": true})
		else:
			_pending.append({"k": "human", "c": i + 1, "s": -1, "q": 0, "back": false, "snap": false})
	for i2 in range(1, slots.size()):
		if not bool(slots[i2].get("left", false)) and int(slots[i2]["peer"]) > 0:
			_resume_state.rpc_id(int(slots[i2]["peer"]), false, 0, 0, "")
	_begin.rpc()
	if mode == Mode.ONLINE and rtc.socket_open():
		if rtc.my_id == 1 and rtc.match_id == "" and rtc.code != "":
			rtc.seal(_tokens.values().map(func(t: String) -> String: return t.sha256_text()))  # BACKEND 1 path b: a new match id
	if main != null and main.has_method("net_toast"):
		main.net_toast("ВСЕ ВЕРНУЛИСЬ · ИГРА ПРОДОЛЖАЕТСЯ" if missing == 0 else ("СТРАНЫ ОТСУТСТВУЮЩИХ ВЕДЁТ ИИ" if by_time else "ИГРА ПРОДОЛЖАЕТСЯ · СТРАНЫ ОТСУТСТВУЮЩИХ ВЕДЁТ ИИ"))
	print("[Net] the resumed match goes on (%d not back)" % missing)


# ------------------------------------------------------------------ commands

## Run a simulation call as a command: `path` "" = GameWorld, "mil", "mil.air", "ops"...;
## cb(result) runs on this device only, when the call ran (null when it was refused).
## Off-line it runs at once (single player: same behaviour as before).
## A player action from any UI: single player = the call at once; network = a command (see call_sim).
static func sim(path: String, method: String, args: Array, cb: Callable = Callable()) -> void:
	if _inst != null:
		_inst.call_sim(path, method, args, cb)


func _enter_tree() -> void:
	_inst = self


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


func call_sim(path: String, method: String, args: Array, cb: Callable = Callable()) -> void:
	if not in_match:
		var obj: Object = _target(path)
		var r: Variant = obj.callv(method, args) if obj != null else null
		if cb.is_valid():
			cb.call(r)
		return
	var enc: Variant = NetCodec.encode(args)
	var key: String = "%s.%s:%s" % [path, method, var_to_str(enc)]
	var now: int = Time.get_ticks_msec()
	if key == _last_cmd and now - _last_cmd_ms < DEDUP_MS:
		return  # a double tap: the first one is already on its way
	_last_cmd = key
	_last_cmd_ms = now
	UiKit.snd("ui_select")  # the result comes on the command's turn; the tap answers at once
	issue({"k": "call", "o": path, "m": method, "a": enc}, cb)


## Raw command ({"k": "cap" / "town" / "call", ...}); see _exec.
func issue(cmd: Dictionary, cb: Callable = Callable()) -> void:
	if reconnecting or rejoining:
		if main != null and main.has_method("net_toast"):
			main.net_toast("НЕТ СВЯЗИ С ХОСТОМ: КОМАНДА НЕ ОТПРАВЛЕНА")
		return
	if String(cmd.get("k", "")) == "cap" and not cmd.has("arch"):
		cmd["arch"] = clampi(GameConfig.arch_i, 0, 3)  # v0.29 STYLE: every human's own style rides on his capital
	_seq += 1
	cmd["q"] = _seq
	if cb.is_valid():
		_cbs[_seq] = cb
		var cbo: Object = cb.get_object()  # lead R335: the object a UI lambda is bound to + its script (sheet may be gone before the turn)
		_cb_oid[_seq] = [cb.get_object_id(), cbo.get_script() if cbo != null else null]
	if is_host:
		cmd["s"] = local_slot
		_pending.append(cmd)
	else:
		_cmd_rq.rpc_id(1, cmd)


@rpc("any_peer", "call_remote", "reliable")
func _cmd_rq(cmd: Dictionary) -> void:
	if not is_host or not in_match:
		return
	var s: int = _slot_of(multiplayer.get_remote_sender_id())
	if s < 0 or not (String(cmd.get("k", "")) in ["call", "cap", "town"]):
		return
	cmd["s"] = s
	cmd.erase("c")  # a guest commands its own country only
	if String(cmd["k"]) in ["cap", "town"]:
		var cell: Variant = cmd.get("cell", Vector2i(-1, -1))
		cmd["cell"] = cell if cell is Vector2i else Vector2i(-1, -1)
		var ar: Variant = cmd.get("arch", 0)
		cmd["arch"] = clampi(int(ar), 0, 3) if ar is int else 0
	_pending.append(cmd)


func _target(path: String) -> Object:
	var o: Object = gw
	if path == "":
		return o
	for part: String in path.split("."):
		if o == null or not (part in o):
			return null
		o = o.get(part) as Object
	return o


func _exec(cmd: Dictionary) -> void:
	var slot: int = int(cmd.get("s", -1))
	var issuer: Country = gw.country_by_id(slot + 1) if slot >= 0 else null
	var mine: bool = slot >= 0 and slot == local_slot
	var res: Variant = null
	var done: bool = true
	gw.ui_mute = not mine
	match String(cmd.get("k", "")):
		"call":
			var path: String = String(cmd.get("o", ""))
			var m: String = String(cmd.get("m", ""))
			var key: String = "%s.%s" % [path, m]
			var obj: Object = _target(path)
			if issuer == null or not issuer.is_player or obj == null or not ALLOWED.has(key) or not obj.has_method(m):
				done = false
			else:
				var args: Variant = NetCodec.decode(gw, cmd.get("a", []))
				if not NetCodec.ok or not (args is Array) or not _owns(issuer, args, int(ALLOWED[key])):
					done = false
				elif (key == "econ.buy" or key == "econ.sell" or key == "econ.market_order") and (args as Array).size() > 1 and args[1] is Country \
						and (args[1] as Country).is_player and args[1] != issuer:
					res = "С игроком — только по согласию: через дипломатию"  # NET 33: buy/sell would take the other person's goods or money unasked
				elif key == "econ.set_trade" and (args as Array).size() > 2 and bool(args[2]) and _human_other(issuer, int(args[1])):
					res = "С игроком — только по согласию: через дипломатию"  # NET 33: an opened trade ships both ways (the other pays)
				else:
					res = obj.callv(m, args)
		"cap":
			var cid: int = int(cmd.get("c", slot + 1))
			var cc: Country = gw.country_by_id(cid)
			if cc != null and cc.capital_id < 0:  # v0.29 STYLE: chosen style (host timeout: seeded), same on every peer
				cc.arch = clampi(int(cmd.get("arch", ArchStyle.seeded(gw, cid))), 0, 3)
			res = gw.mp_place_capital(cid, cmd.get("cell", Vector2i(-1, -1)))
			if res != null:
				_late_cap_deadlines.erase(cid)
		"town":
			if issuer != null and issuer.is_player:
				res = gw.player_found_town(cmd.get("cell", Vector2i(-1, -1)), issuer)
		"human":
			var ch: int = int(cmd.get("c", -1))
			var human_country: Country = gw.country_by_id(ch)
			if human_country != null:
				if cmd.has("name"):
					human_country.name = NetConfig.clean_nick(String(cmd.get("name", human_country.name)))
				if cmd.has("arch"):
					human_country.arch = clampi(int(cmd.get("arch", human_country.arch)), 0, 3)
				var human_flag: String = clean_flag(cmd.get("flag", ""))
				if human_flag != "":
					gw.apply_flag(human_country, human_flag, false)
			gw.mp_to_human(ch)
			if bool(cmd.get("back", true)) and ch - 1 != local_slot and ch - 1 >= 0 and ch - 1 < slots.size():
				player_back.emit(String((slots[ch - 1] as Dictionary).get("name", "Игрок")))
			if is_host and ch - 1 >= 0 and ch - 1 < slots.size() and bool(cmd.get("snap", true)):
				var back_peer: int = int(slots[ch - 1]["peer"])
				_last_snap_ms.erase(back_peer)  # a returning player needs a snapshot now
				_resync_q.append(back_peer)  # the snapshot at the end of this turn carries him back
		"new":
			if gw.countries.size() >= NetConfig.MAX_PLAYERS or gw.countries.size() + 1 != slots.size():
				done = false
			else:
				var new_country: Country = gw.create_country(false)
				if new_country == null:
					done = false
				else:
					new_country.is_player = true
					new_country.arch = clampi(int(cmd.get("arch", 0)), 0, 3)
					new_country.name = NetConfig.clean_nick(String(cmd.get("name", "Player")))
					var new_flag: String = clean_flag(cmd.get("flag", ""))
					if new_flag != "":
						gw.apply_flag(new_country, new_flag, false)
					_late_cap_deadlines[new_country.id] = float(cmd.get("capital_deadline", gw.game_time + NetConfig.CAPITAL_TIMEOUT_S))
					_cap_done = false
					if is_host:
						var new_peer: int = int(cmd.get("peer", 0))
						_last_snap_ms.erase(new_peer)  # a new player needs a snapshot now
						_resync_q.append(new_peer)
		"ai":
			var ci: int = int(cmd.get("c", -1))
			gw.mp_to_ai(ci)
			if ci - 1 != local_slot and ci - 1 >= 0 and ci - 1 < slots.size():
				player_left.emit(String((slots[ci - 1] as Dictionary).get("name", "Игрок")), bool(cmd.get("lost", true)))
		_:
			done = false
	gw.ui_mute = false
	var q: int = int(cmd.get("q", 0))
	if mine and _cbs.has(q):
		var cb: Callable = _cbs[q]
		_cbs.erase(q)
		var ob: Array = _cb_oid.get(q, [0, null])  # lead R335: «lambda with an invalid instance» — the callback's object
		_cb_oid.erase(q)  # (a sheet such as ТОРГОВЛЯ) closed / rebuilt between the tap and the command's turn (guest: a
		var oo: Object = instance_from_id(int(ob[0])) if int(ob[0]) != 0 else null  # round trip later); is_valid() alone
		if cb.is_valid() and (int(ob[0]) == 0 or (oo != null and oo.get_script() == ob[1])):  # misses an object without its script
			cb.call(res if done else null)


## NET 33: country `cid` is another person (trade with him only by his answer, through diplomacy).
func _human_other(issuer: Country, cid: int) -> bool:
	var c: Country = gw.country_by_id(cid)
	return c != null and c.is_player and c != issuer


## A command acts for its issuer only: the first country argument is the issuer, every own-able
## entity argument belongs to it, and the country-id argument (id_arg >= 0) is its id.
## A City may be foreign (attack target); a second Country may be a trade partner.
func _owns(issuer: Country, args: Array, id_arg: int) -> bool:
	var first_country: bool = true
	for a: Variant in args:
		if a is Country:
			if first_country and a != issuer:
				return false
			first_country = false
		elif a is Facility or a is Unit or a is Drone or a is Aircraft or a is Ship or a is Missile:
			if int((a as Object).get("country_id")) != issuer.id:
				return false
	if id_arg >= 0 and (id_arg >= args.size() or int(args[id_arg]) != issuer.id):
		return false
	return true


# ------------------------------------------------------------------ lockstep loop

func _process(delta: float) -> void:
	_ping_tick(delta)
	_played_tick(delta)
	if reconnecting:
		_reconnect_tick(delta)
	elif rejoining:
		# (2026-10-31) 20 s WITHOUT PROGRESS, not 20 s in all: every snapshot part resets it, and building the world
		# from the snapshot (_restoring: long on a phone) does not count. Was: «20 s and _snap empty» — it fired in the
		# middle of the build (the guest, thrown out after ~30 s on the loading screen) and never for a snapshot stuck
		# half-way (an endless loading screen).
		if _restoring:
			_rj_t = 0.0
		else:
			_rj_t += delta
		_rj_total += delta
		if _rj_t > 20.0 or _rj_total > 180.0:  # (critic) + a hard cap: a world build that never ends is not a wait
			_start_reconnect()  # NET 32: the snapshot never came / stopped coming / never finished: try again
	elif in_match and go and not is_host and not _rejoin.is_empty():
		_rj_save_t += delta
		if _rj_save_t > 60.0:
			_rj_save_t = 0.0
			_rejoin["played"] = snappedf(_played_s, 1.0)  # (critic) the count survives an app restart
			NetConfig.save_rejoin(_rejoin)  # the place stays offered (app killed late in a long match)
	if not _snap.is_empty() and not is_host:
		_snap_t += delta
		if _snap_t > 20.0:
			print("[Net] snapshot reception timed out after 20s (got %d of %d parts), aborting" % [(_snap.get("got", {}) as Dictionary).size(), int(_snap.get("parts", 0))])
			_snap = {}
			_snap_t = 0.0
			if main != null and main.get("loading") != null and main.loading.active:
				main.loading.finish()
			_start_reconnect()
	if resume_wait and in_match:
		if is_host and not _restoring:
			resume_t += delta
			if resume_t > NetConfig.RESUME_WAIT_S:
				resume_go(true)
		elif not is_host:
			stall_t = 0.0  # NET 35: no turns until the host goes on: not a lost link
			resume_t += delta  # the plate's timer (the host's count arrives with every change)
			return
	if is_host and in_match and not go and _start_t >= 0.0:
		_start_t += delta
		if _start_t > 60.0:  # someone never finished loading: start without him (the AI plays him)
			for i in range(1, slots.size()):
				if not _ready_peers.has(int(slots[i]["peer"])) and not bool(slots[i].get("left", false)):
					slots[i]["left"] = true
					_pending.append({"k": "ai", "c": i + 1, "s": -1, "q": 0})
			_mark_ready(-1)
	if _p2p_wait >= 0.0:
		_p2p_wait -= delta
		if _p2p_wait < 0.0:
			leave(false, true)
			_status("Не удалось соединиться с хостом напрямую. Проверьте интернет")
	if _way_back_t >= 0.0 and is_host and in_match:
		_way_back_t -= delta
		if _way_back_t < 0.0 and _guest_missing():
			_open_way_back()
	if not in_match or not go:
		return
	if not is_host:
		_lag_now_t += delta
		if _lag_now_t >= NetConfig.LAG_NOW_S:
			_lag_now_t = 0.0
			_lag_now_rq.rpc_id(1, maxi(0, last_turn - exec_turn))  # NET 37: the host's turn pace reads it
	delta *= NetConfig.test_speed
	if is_host:
		_speed_tick(delta)
		_host_turns(delta * float(speed))
		_capital_timeout()
	if not _restoring and not rejoining:
		_run(delta * float(speed), delta)
		if is_host and exec_tick == 0 and exec_turn > 0 and not _resync_q.is_empty():
			_send_snapshot(exec_turn - 1)  # also retry when the host is held at a turn boundary
		if not is_host and host_active and stall_t > 45.0 and not _rejoin.is_empty() and _snap.is_empty() and _snap_next.is_empty():
			_start_reconnect()  # NET 32: the link is dead, ENet would notice only after 90 s


## NET 37: the worst backlog of the host itself and the live guests (their reports of the last 2 s,
## sent every LAG_NOW_S). -> [turns, slot].
func _worst_backlog() -> Array:
	var w: int = maxi(0, last_turn - exec_turn)
	var ws: int = local_slot
	var now: int = Time.get_ticks_msec()
	for s: int in _lag_now:
		var e: Array = _lag_now[s]
		var bg: int = int(e[0])
		if s != local_slot and _live(s) and now - int(e[1]) <= 6000 and bg < NetConfig.HOLD_MAX and bg > w:
			w = bg
			ws = s
	return [w, ws]


## Host: tells everybody whom the turns wait for («» = nobody) when it changes.
func _hold_set(who: String) -> void:
	if who == hold_who:
		return
	hold_who = who
	_hold_note.rpc(who)


@rpc("authority", "call_remote", "reliable")
func _hold_note(who: String) -> void:
	hold_who = who


## Guest: my backlog now (reliable: the host may be holding the turns for me).
@rpc("any_peer", "call_remote", "reliable")
func _lag_now_rq(backlog: int) -> void:
	if not is_host:
		return
	var s: int = _slot_of(multiplayer.get_remote_sender_id())
	if s >= 0:
		_lag_now[s] = [maxi(0, backlog), Time.get_ticks_msec()]


func _host_turns(delta: float) -> void:
	if not host_active or _restoring:
		_host_acc = 0.0
		return
	if not _sync_wait.is_empty():
		var now_ms: int = Time.get_ticks_msec()
		var live_peers: PackedInt32Array = multiplayer.get_peers()
		for pid in _sync_wait.keys():
			var info: Dictionary = _sync_wait[pid]
			if not live_peers.has(pid):
				_sync_wait.erase(pid)
			elif bool(info.get("disconnecting", false)):
				if not bool(info.get("disconnect_sent", false)) and now_ms >= int(info.get("disconnect_at", now_ms)):
					info["disconnect_sent"] = true
					_kick_desynced_peer(pid)
			elif now_ms - int(info.get("started_ms", 0)) > 35000:
				# Never resume with a connected peer whose snapshot was not acknowledged.
				print("[Net] snapshot timed out for peer %d: disconnecting" % pid)
				if main != null and main.has_method("net_toast"):
					main.net_toast("ИГРОК ОТКЛЮЧЁН: НЕ УДАЛОСЬ СИНХРОНИЗИРОВАТЬ МИР")
				info["disconnecting"] = true
				info["disconnect_at"] = now_ms + 1000  # give the relay time to forward the notice
				_kick.rpc_id(pid, "Не удалось синхронизировать мир")
	if not _sync_wait.is_empty():
		_host_acc = 0.0
		return
	var turn_s: float = NetConfig.SIM_DT * NetConfig.TICKS_PER_TURN
	var wb: Array = _worst_backlog()  # NET 37: someone cannot keep up: slower turns, then none (time slows, the input lag does not grow)
	if int(wb[0]) >= NetConfig.HOLD_SLOW:
		var ws: int = int(wb[1])
		_hold_set(String((slots[ws] as Dictionary).get("name", "?")) if ws >= 0 and ws < slots.size() else "?")
		perf_holds += 1
		if int(wb[0]) >= NetConfig.HOLD_BACKLOG:
			_host_acc = 0.0
			return
		delta *= 0.5
	else:
		_hold_set("")
	_host_acc = minf(_host_acc + delta, turn_s * 3.0)  # back from a hitch: no burst of turns
	while _host_acc >= turn_s:
		_host_acc -= turn_s
		var cmds: Array = _pending
		_pending = []
		_turn.rpc(_host_turn, cmds, speed)
		_host_turn += 1


@rpc("authority", "call_local", "reliable")
func _turn(n: int, cmds: Array, spd: int = 1) -> void:
	turns[n] = cmds
	var old_spd: int = speed
	speed = clampi(spd, 1, int(NetConfig.MP_SPEEDS[NetConfig.MP_SPEEDS.size() - 1]))  # NET 31: pace like the host
	if speed != old_spd:
		speed_changed.emit(old_spd, speed)
		if main != null and main.has_method("_apply_speed"):
			main._apply_speed()
	last_turn = maxi(last_turn, n)
	turns.erase(n - TURN_KEEP)


func _run(delta: float, real: float = -1.0) -> void:
	var tpt: int = NetConfig.TICKS_PER_TURN
	var behind: int = last_turn - exec_turn
	_acc += delta
	var max_ticks: int = int(_acc / NetConfig.SIM_DT)
	if behind > 3:
		max_ticks = maxi(max_ticks, tpt * mini(behind, 6))  # catch up (back from the background, after a resync)
	max_ticks = mini(max_ticks, 24)
	var done: int = 0
	var us0: int = Time.get_ticks_usec()
	if NetConfig.guard and turns.has(exec_turn) and not _restoring:
		_guard_check()
	gw.net_sim = true  # NET301: commands + ticks (a frame-time UI call sees false)
	while done < max_ticks and turns.has(exec_turn) and not _restoring and (done == 0 or float(Time.get_ticks_usec() - us0) / 1000.0 + perf_tick_ms * 1.2 < NetConfig.FRAME_SIM_MS):
		Navy.cur = 0  # NET301: the naval-base build ghost (main._navy_snap) leaves its orientation here
		if exec_tick == 0:
			for cmd: Variant in turns[exec_turn]:
				if cmd is Dictionary:
					_exec(cmd)
		var ut: int = Time.get_ticks_usec()
		gw.net_step(NetConfig.SIM_DT)
		var tms: float = float(Time.get_ticks_usec() - ut) / 1000.0
		perf_tick_ms = lerpf(perf_tick_ms, tms, 0.05)
		perf_tick_max = maxf(perf_tick_max, tms)
		if GameConfig.creative and gw.net_tick % 15 == 0:
			_creative()
		exec_tick += 1
		done += 1
		if exec_tick >= tpt:
			var n: int = exec_turn
			exec_turn += 1
			exec_tick = 0
			_end_turn(n)
	gw.net_sim = false
	perf_frame_max = maxf(perf_frame_max, float(Time.get_ticks_usec() - us0) / 1000.0)
	perf_ticks_frame_max = maxi(perf_ticks_frame_max, done)
	if NetConfig.guard and done > 0:
		_guard_h = NetHash.of(gw)
		_guard_p = JSON.parse_string(JSON.stringify(NetHash.parts(gw)))
		_guard_m = _member_sig()
	_acc = maxf(0.0, _acc - float(done) * NetConfig.SIM_DT)
	if done == 0:
		_acc = minf(_acc, NetConfig.SIM_DT * tpt)
		stall_t += real if real >= 0.0 else delta  # real seconds: the plates do not run x3
	else:
		stall_t = 0.0
	_lag_min = mini(_lag_min, maxi(0, last_turn - exec_turn))  # NET 31: this device's own backlog (CPU, not the network)


## Text for the HUD while the match stands still ("" = running).
func stall_text() -> String:
	if not in_match:
		return ""
	if _restoring or not _snap.is_empty() or not _sync_wait.is_empty():
		return "СИНХРОНИЗАЦИЯ С ИГРОКОМ..." if is_host else "СИНХРОНИЗАЦИЯ С ХОСТОМ..."
	if not go:
		return "ЖДЁМ ИГРОКОВ..."
	if stall_t < (NetConfig.HOST_IDLE_S if not host_active else 1.0):
		return ""
	if host_active and hold_who != "":
		return "ЖДЁМ %s · МЕДЛЕННОЕ УСТРОЙСТВО" % hold_who.to_upper()  # NET 37: the turns wait for a slow device
	return "ПАУЗА: ХОСТ НЕАКТИВЕН" if not host_active else "ЖДЁМ ХОСТ..."


## NET 29: the in-match status plate (MpKit.Plate) — {} = nothing to show. Priority: sync, start,
## host paused, no data from the host, own capital, the others' capitals.
func plate() -> Dictionary:
	if not in_match:
		return {}
	if reconnecting:
		return {"key": "rc", "sev": "alarm", "icon": "net_signal_lost", "title": "ПЕРЕПОДКЛЮЧЕНИЕ...",
			"sub": ("ПОПЫТКА %d · ВАШЕ МЕСТО СОХРАНЕНО" % maxi(1, rc_tries)) if rc_tries < 3 else "ВЫЙТИ МОЖНО ЧЕРЕЗ МЕНЮ · МЕСТО СОХРАНИТСЯ",
			"timer": _mmss(maxf(0.0, NetConfig.RECONNECT_S - rc_t))}
	if rejoining:
		return {"key": "rj", "sev": "info", "icon": "net_sync", "spin": true, "title": "ВОЗВРАЩАЕМСЯ В ПАРТИЮ", "sub": "ПОЛУЧАЕМ МИР ОТ ХОСТА..."}
	if _restoring or not _snap.is_empty() or not _sync_wait.is_empty():
		return {"key": "sync", "sev": "info", "icon": "net_sync", "spin": true, "title": "СИНХРОНИЗАЦИЯ",
			"sub": "ВЫРАВНИВАЕМ МИР У ВСЕХ ИГРОКОВ" if is_host else "ПОЛУЧАЕМ МИР ОТ ХОСТА..."}
	if resume_wait and not _restoring and _snap.is_empty():
		var back_n: int = resume_back
		var all_n: int = resume_total
		var miss: String = resume_missing
		if is_host:
			var rc: Array = _resume_counts()
			back_n = int(rc[0])
			all_n = int(rc[1])
			miss = _missing_text()
		return {"key": "resume", "sev": "info", "icon": "net_players", "title": "ЖДЁМ ИГРОКОВ",
			"sub": ("ВЕРНУЛИСЬ: %d ИЗ %d" % [back_n, all_n]) + ((" · ЖДЁМ: " + miss) if miss != "" else ("" if is_host else " · ХОСТ МОЖЕТ НАЧАТЬ")),
			"timer": _mmss(maxf(0.0, NetConfig.RESUME_WAIT_S - resume_t))}
	if not go:
		var sub_s: String = "ЗАГРУЖАЮТСЯ: %d ИЗ %d" % [mini(_ready_peers.size(), slots.size()), slots.size()] if is_host else "ЗАГРУЖАЕТСЯ ПАРТИЯ"
		if is_host and _start_t > 50.0:
			sub_s = "СТРАНУ ОПОЗДАВШЕГО ВОЗЬМЁТ ИИ"
		return {"key": "start", "sev": "info", "icon": "net_sync", "spin": true, "title": "ЖДЁМ ИГРОКОВ", "sub": sub_s,
			"timer": _mmss(maxf(0.0, 60.0 - _start_t)) if is_host and _start_t >= 0.0 else ""}
	if not is_host and not host_active and stall_t >= NetConfig.HOST_IDLE_S:
		return {"key": "pause", "sev": "wait", "icon": "net_pause", "title": "ПАУЗА: ХОСТ НЕАКТИВЕН", "sub": "ИГРА ПРОДОЛЖИТСЯ, КОГДА ОН ВЕРНЁТСЯ"}
	if not is_host and host_active and stall_t >= 3.0:
		return {"key": "lost", "sev": "alarm", "icon": "net_signal_lost", "title": "ПРОБЛЕМА С ПОДКЛЮЧЕНИЕМ",
			"sub": "НЕТ ДАННЫХ ОТ ХОСТА" if stall_t < 20.0 else "МОЖНО ВЫЙТИ ЧЕРЕЗ МЕНЮ", "timer": _mmss(stall_t)}
	if not is_host and host_active and stall_t >= 1.0:
		return {"key": "weak", "sev": "wait", "icon": "net_signal_weak", "title": "СВЯЗЬ С ХОСТОМ ЗАМЕДЛИЛАСЬ", "sub": "ЖДЁМ ДАННЫЕ..."}
	var cl: float = capital_left()
	if cl >= 0.0:
		return {"key": "cap", "sev": "wait", "icon": "icon_capital", "title": "ПОСТАВЬТЕ СТОЛИЦУ", "sub": "ТАПНИТЕ ПО СУШЕ. ИНАЧЕ ВЫБЕРЕТ ИГРА",
			"timer": _mmss(cl), "urgent": cl <= 15.0}
	if not _cap_done and gw.player != null and gw.player.capital_id >= 0 and not gw.mp_all_capitals():
		var done_n: int = 0
		for i in slots.size():
			var c: Country = gw.country_by_id(i + 1)
			if c != null and c.capital_id >= 0:
				done_n += 1
		return {"key": "caps", "sev": "info", "icon": "net_players", "title": "ЖДЁМ СТОЛИЦЫ ДРУГИХ", "sub": "ГОТОВО: %d ИЗ %d" % [done_n, slots.size()],
			"timer": _mmss(maxf(0.0, NetConfig.CAPITAL_TIMEOUT_S - gw.game_time))}
	return {}


## Connection quality for the guest's indicator: 0 ok, 1 weak (a gap of 1-3 s), 2 lost (3 s+).
func link_level() -> int:
	if not in_match or is_host or not go or not host_active:
		return 0
	return 2 if stall_t >= 3.0 else (1 if stall_t >= 1.0 else 0)


static func _mmss(t: float) -> String:
	var n: int = ceili(t)
	return "%d:%02d" % [n / 60, n % 60]


# ------------------------------------------------------------------ NET 31 game speed

@rpc("any_peer", "call_remote", "unreliable")
func _lag_rq(backlog: int) -> void:
	if not is_host:
		return
	var s: int = _slot_of(multiplayer.get_remote_sender_id())
	if s >= 0:
		_lag[s] = [maxi(0, backlog), Time.get_ticks_msec()]


## «ПО СОГЛАСИЮ»: this person's wished speed (the speed picker).
func set_want(w: int) -> void:
	my_want = clampi(w, 1, int(NetConfig.MP_SPEEDS[NetConfig.MP_SPEEDS.size() - 1]))
	if not in_match:
		return
	if is_host:
		_take_want(local_slot, my_want)
	else:
		_want_rq.rpc_id(1, my_want)


@rpc("any_peer", "call_remote", "reliable")
func _want_rq(w: int) -> void:
	if is_host:
		var s: int = _slot_of(multiplayer.get_remote_sender_id())
		if s >= 0:
			_take_want(s, w)


func _take_want(s: int, w: int) -> void:
	while wants.size() < slots.size():
		wants.append(1)
	var old: int = int(wants[s])
	wants[s] = clampi(w, 1, int(NetConfig.MP_SPEEDS[NetConfig.MP_SPEEDS.size() - 1]))
	_spd_t = 1.0  # the next host frame recomputes
	if int(wants[s]) > old and Time.get_ticks_msec() - int(_want_note_ms.get(s, -100000)) > 60000:  # UX: no pressure on who holds x1 on purpose
		_want_note_ms[s] = Time.get_ticks_msec()
		_want_note.rpc(s, int(wants[s]))


## «X ХОЧЕТ x3» for the people who wish less (one toast per person in 10 s).
@rpc("authority", "call_local", "reliable")
func _want_note(s: int, w: int) -> void:
	if s != local_slot and my_want < w and GameConfig.mp_speed == 0 and main != null and main.has_method("net_toast"):
		main.net_toast("%s ЗА x%d · КНОПКА «СКОРОСТЬ»" % [String((slots[s] as Dictionary).get("name", "?")).to_upper(), w])


@rpc("authority", "call_local", "reliable")
func _speed_state(spd: int, why: String, who: String, ws: Array) -> void:
	var old: int = speed
	speed = spd
	speed_why_prev = speed_why
	speed_why = why
	speed_who = who
	wants = ws
	speed_changed.emit(old, spd)
	if main != null and main.has_method("_apply_speed"):
		main._apply_speed()


## A person still in the match (not left, not eliminated): his wish and his device count.
func _live(i: int) -> bool:
	if i < 0 or i >= slots.size() or bool((slots[i] as Dictionary).get("left", false)):
		return false
	var c: Country = gw.country_by_id(i + 1) if gw != null else null
	return c != null and not c.eliminated


## Host, every 0.25 s: the speed now; a change goes to everybody (the turns carry it too).
func _speed_tick(dt: float) -> void:
	_spd_t += dt
	if _spd_t < 0.25:
		return
	var step: float = _spd_t
	_spd_t = 0.0
	var now: int = Time.get_ticks_msec()
	var lag_who: String = _lag_guard(now, step)
	while wants.size() < slots.size():
		wants.append(1)
	var tgt: int = 1
	var why: String = "start"
	var who: String = ""
	if _cap_done or gw.mp_all_capitals():  # until every person has a capital: x1 (its timer is game time)
		if GameConfig.mp_speed == 2:
			why = "off"  # NET 33: the host turned the speed-up off: always x1
		elif GameConfig.mp_speed == 1:
			tgt = _auto_speed(step)
			var min_w: int = int(NetConfig.MP_SPEEDS[NetConfig.MP_SPEEDS.size() - 1])
			var holders: PackedStringArray = []
			for i in slots.size():
				if not _live(i):
					continue
				var w: int = int(wants[i])
				if w < min_w:
					min_w = w
					holders = []
				if w == min_w:
					holders.append(String((slots[i] as Dictionary).get("name", "?")))
			if min_w < tgt:
				tgt = min_w
				why = "want"
				who = holders[0] + (" +%d" % (holders.size() - 1) if holders.size() > 1 else "") if not holders.is_empty() else ""
			else:
				why = "auto" if tgt > 1 else "auto:" + _auto_why_s
				who = _auto_who_s if tgt == 1 else ""
		else:
			tgt = int(NetConfig.MP_SPEEDS[NetConfig.MP_SPEEDS.size() - 1])
			var holders: PackedStringArray = []
			for i in slots.size():
				if not _live(i):
					continue
				var w: int = int(wants[i])
				if w < tgt:
					tgt = w
					holders = []
				if w == tgt:
					holders.append(String((slots[i] as Dictionary).get("name", "?")))
			why = "want"
			who = holders[0] + (" +%d" % (holders.size() - 1) if holders.size() > 1 else "") if not holders.is_empty() else ""
	var cap: int = int(NetConfig.MP_SPEEDS[_cap_i])
	if tgt > cap:
		tgt = cap
		why = "lag"
		who = lag_who
	if tgt != speed or why != speed_why or who != speed_who:
		_speed_state.rpc(tgt, why, who, wants.duplicate())


## Lag guard: every device's own backlog (min over its 10-turn window, so network jitter does
## not count). Worst > 4 turns: one step down (not again within 3 s; a second drop within 60 s
## holds the cap for 60 s); worst <= 2 for 15 s: one step up. A device silent for 2 s (in the
## background, connection gone) does not count: a slow or absent guest slows nobody down.
var _lag_who_s: String = ""


func _lag_guard(now: int, step: float) -> String:
	var worst: int = 0
	var worst_s: int = -1
	for s: int in _lag:
		var e: Array = _lag[s]
		if not _live(s) or now - int(e[1]) > 10000:
			continue
		if int(e[0]) > worst:
			worst = int(e[0])
			worst_s = s
	if worst > 4:
		_cap_ok_s = 0.0
		if now - _last_down_ms >= 3000 and _cap_i > 0:
			if now - _last_down_ms < 60000:
				_hold_until_ms = now + 60000
			_cap_i -= 1
			_last_down_ms = now
			_lag_who_s = String((slots[worst_s] as Dictionary).get("name", "?")) if worst_s >= 0 and worst_s < slots.size() else ""
	elif worst <= 2:
		_cap_ok_s += step
		if _cap_ok_s >= 15.0 and now >= _hold_until_ms and _cap_i < NetConfig.MP_SPEEDS.size() - 1:
			_cap_i += 1
			_cap_ok_s = 0.0
	else:
		_cap_ok_s = 0.0
	return _lag_who_s


## «АВТО»: x1 while anything concerns a person (an answer with a deadline, a fight, an enemy on
## his land, a strike flying at it, a loss, a new war); quiet for 20 s -> x2, 60 s -> x3. The host
## polls the simulation state once a second (read only); real seconds.
var _auto_why_s: String = ""
var _auto_who_s: String = ""  # the country an auto event concerns (the toast: «… У СОКОЛ_77»)


func _auto_speed(step: float) -> int:
	_auto_t += step
	if _auto_t >= 1.0:
		var dt: float = _auto_t
		_auto_t = 0.0
		var why: String = _auto_event()
		if why != "":
			calm_s = 0.0
			_auto_why_s = why
			var ac: Country = gw.country_by_id(_ev_cid)
			_auto_who_s = ac.name if ac != null else ""
		else:
			calm_s += dt
	if calm_s >= 60.0:
		return 3
	if calm_s >= 20.0:
		return 2
	return 1


var _ev_cid: int = 0  # _auto_event: the person the last found event concerns


func _auto_event() -> String:
	var dp: Diplomacy = gw.diplo
	_ev_cid = 0
	var hum: Dictionary = {}
	for c: Country in gw.countries:
		if c.is_player and not c.eliminated:
			hum[c.id] = true
	if hum.is_empty():
		return ""
	var ev: String = ""
	# answers with a deadline waiting for a person (their timers run on game time)
	if dp != null:
		for d: Dictionary in dp.demands:
			if hum.has(int(d["to"])):
				ev = "ВХОДЯЩИЕ"
				_ev_cid = int(d["to"])
		for o: Array in dp.offers:
			if hum.has(int(o[1])):
				ev = "ВХОДЯЩИЕ"
				_ev_cid = int(o[1])
		for t: Dictionary in dp.t_offers:
			if hum.has(int(t["to"])):
				ev = "ВХОДЯЩИЕ"
				_ev_cid = int(t["to"])
		for k: Dictionary in dp.calls:
			if hum.has(int(k["to"])):
				ev = "ВХОДЯЩИЕ"
				_ev_cid = int(k["to"])
		if dp.conf != null:
			for cid: int in hum:
				if not dp.conf.conf_for(cid).is_empty():
					ev = "ВХОДЯЩИЕ"
					_ev_cid = cid
			for so: Dictionary in dp.conf.offers:
				if hum.has(dp.conf._offer_to(so)) and gw.game_time < float(so.get("until", 0.0)):  # R332 PEACE332: no expiry now; x1 only while new
					ev = "ВХОДЯЩИЕ"
					_ev_cid = dp.conf._offer_to(so)
	# losses / a new war since the last poll
	var sums: Dictionary = {}
	for f: Facility in gw.mil.facilities:
		if hum.has(f.country_id) and gw.mil.alive(f):
			sums[f.country_id] = float(sums.get(f.country_id, 0.0)) + f.hp
	for u: Unit in gw.army.units:
		if not u.alive():
			continue
		if hum.has(u.country_id):
			sums[u.country_id] = float(sums.get(u.country_id, 0.0)) + u.hp
			if u.state == Unit.State.FIGHT or u.state == Unit.State.SIEGE:
				ev = "БОЙ"
				_ev_cid = u.country_id
		elif u.ground():
			var cx: int = floori(u.pos.x / GameWorld.CELL)
			var cy: int = floori(u.pos.y / GameWorld.CELL)
			var own: int = gw.data.get_owner_id(cx, cy) if gw.data.inside(cx, cy) else 0
			if hum.has(own) and gw.army._hostile(u.country_id, own):
				ev = "ВРАГ НА ЗЕМЛЕ"
				_ev_cid = own
	for d2: Drone in gw.mil.drones:
		if d2.state >= Drone.State.BOOST and d2.state <= Drone.State.DIVE and _hits_person(d2.country_id, d2.target, hum):
			ev = "ЛЕТИТ УДАР"
			_ev_cid = _owner_at(d2.target)
	for m: Missile in gw.mil.missiles:
		if m.state != Missile.State.DONE and _hits_person(m.country_id, m.target, hum):
			ev = "ЛЕТИТ УДАР"
			_ev_cid = _owner_at(m.target)
	for cid2: int in hum:
		var c2: Country = gw.country_by_id(cid2)
		var now_v: Array = [float(sums.get(cid2, 0.0)), c2.city_ids.size(), c2.at_war.size()]
		var was: Array = _hum.get(cid2, now_v)
		if float(now_v[0]) < float(was[0]) - 0.5 or int(now_v[1]) < int(was[1]):
			ev = "ПОТЕРИ"
			_ev_cid = cid2
		if int(now_v[2]) > int(was[2]):
			ev = "ВОЙНА"
			_ev_cid = cid2
		_hum[cid2] = now_v
	return ev


func _owner_at(at: Vector2) -> int:
	var cx: int = floori(at.x / GameWorld.CELL)
	var cy: int = floori(at.y / GameWorld.CELL)
	return gw.data.get_owner_id(cx, cy) if gw.data.inside(cx, cy) else 0


func _hits_person(by: int, at: Vector2, hum: Dictionary) -> bool:
	var cx: int = floori(at.x / GameWorld.CELL)
	var cy: int = floori(at.y / GameWorld.CELL)
	if not gw.data.inside(cx, cy):
		return false
	var own: int = gw.data.get_owner_id(cx, cy)
	return hum.has(own) and own != by


## Owner rule: the match pauses only while the host is inactive (its app in the background).
func set_host_active(on: bool) -> void:
	if is_host and in_match and not on:
		save_match()  # NET 35: the phone may kill a backgrounded app: the match can be resumed
	if is_host and in_match and on != host_active:
		_host_state.rpc(on)


@rpc("authority", "call_local", "reliable")
func _host_state(on: bool) -> void:
	if on and not host_active:
		stall_t = 0.0  # BH v0.31: the turns stopped while the host was away; the 15 s lost-link watch starts now
	host_active = on


func _creative() -> void:
	for c: Country in gw.countries:
		if not c.is_player:
			continue
		c.money = maxi(c.money, 1000000)
		for rk: String in Economy.TRADE_RES + ["fuel"]:
			var cap: int = int(gw.econ.res_cap(c, rk)) if gw.econ.has_method("res_cap") else 0
			c.set(rk, maxi(int(c.get(rk)), cap if cap > 0 else 999))


## Seconds left to place the own capital (game time: every peer shows the same countdown); -1 = none.
func capital_left() -> float:
	if not in_match or not go or gw.player == null or gw.player.capital_id >= 0 or _cap_done:
		return -1.0
	var deadline: float = float(_late_cap_deadlines.get(gw.player.id, NetConfig.CAPITAL_TIMEOUT_S))
	return maxf(0.0, deadline - gw.game_time)


func _capital_timeout() -> void:
	if _cap_done:
		return
	if gw.mp_all_capitals():  # (bots, if any, come in the same tick; a match may have none)
		_cap_done = true
		return
	for i in slots.size():
		var c: Country = gw.country_by_id(i + 1)
		var deadline: float = float(_late_cap_deadlines.get(i + 1, NetConfig.CAPITAL_TIMEOUT_S))
		if c != null and c.capital_id < 0 and gw.game_time >= deadline:
			_late_cap_deadlines[i + 1] = gw.game_time + NetConfig.CAPITAL_TIMEOUT_S
			_pending.append({"k": "cap", "c": i + 1, "s": -1, "q": 0, "cell": Vector2i(-1, -1), "arch": slot_arch(i)})  # NET 30: the style picked in the room


# ------------------------------------------------------------------ hash check and resync

func _end_turn(n: int) -> void:
	if n > 0 and n % 10 == 0 and _lag_min < (1 << 30):
		if is_host:
			_lag[local_slot] = [_lag_min, Time.get_ticks_msec()]
		else:
			_lag_rq.rpc_id(1, _lag_min)
		_lag_min = 1 << 30
	if NetConfig.trace and n > 0 and n % 10 == 0 and n % NetConfig.HASH_EVERY != 0:
		print("[NetTrace] %d %s %s" % [n, NetHash.of(gw), JSON.stringify(NetHash.parts(gw))])  # finer trace only (no check)
	if n > 0 and n % NetConfig.HASH_EVERY == 0:
		var h: String = NetHash.of(gw)
		if NetConfig.trace:
			print("[NetTrace] %d %s %s" % [n, h, JSON.stringify(NetHash.parts(gw))])
		if is_host:
			_hashes[n] = h
			_hashes.erase(n - NetConfig.HASH_EVERY * 20)
			_hparts[n] = NetHash.parts(gw)
			_hparts.erase(n - NetConfig.HASH_EVERY * 20)
			_gparts.erase(n - NetConfig.HASH_EVERY * 20)
			var early: Dictionary = _ghash.get(n, {})
			_ghash.erase(n)
			for p: int in early:
				if String(early[p]) != h:
					_queue_resync(p, n)
			_gparts.erase(n)
		else:
			_hash_rq.rpc_id(1, n, h, JSON.stringify(NetHash.parts(gw)))
	var sent_snapshot: bool = false
	if is_host and not _resync_q.is_empty():
		sent_snapshot = _send_snapshot(n)
	if is_host and not sent_snapshot and go and n > 0 and n % NetConfig.MATCH_SAVE_TURNS == 0:
		save_match(n)  # NET 35


@rpc("any_peer", "call_remote", "reliable")
func _hash_rq(n: int, h: String, parts_json: String = "") -> void:
	if not is_host:
		return
	var from: int = multiplayer.get_remote_sender_id()
	if n % NetConfig.HASH_EVERY != 0 or n > _host_turn + NetConfig.HASH_EVERY * 4 or n < _host_turn - NetConfig.HASH_EVERY * 20:
		return  # NET 34: only check turns near now (a bad n would pile up in _ghash / _gparts)
	var gp: Variant = JSON.parse_string(parts_json) if parts_json.length() < 32768 else null
	if gp is Dictionary:
		if not _gparts.has(n):
			_gparts[n] = {}
		(_gparts[n] as Dictionary)[from] = gp
	if _hashes.has(n):
		if String(_hashes[n]) != h:
			_queue_resync(from, n)
		else:
			_desync_streak.erase(from)
		var gpn: Dictionary = _gparts.get(n, {})
		gpn.erase(from)  # NET 34: compared: drop it (a late report would stay forever)
		if gpn.is_empty():
			_gparts.erase(n)
	else:
		if not _ghash.has(n):
			_ghash[n] = {}
		(_ghash[n] as Dictionary)[from] = h


func _queue_resync(peer: int, n: int) -> void:
	if n <= int(_last_snap.get(peer, -1)) or _restoring:
		return  # a report from before the last snapshot: that peer is being fixed already
	if _sync_wait.has(peer):
		return  # peer is currently restoring a snapshot
	if _resync_q.has(peer):
		return
	var dp: String = _diff_parts(n, peer)
	var is_minor_float: bool = dp.begins_with("(parts equal")
	if is_minor_float:
		_desync_streak[peer] = int(_desync_streak.get(peer, 0)) + 1
		if _desync_streak[peer] < 3:
			print("[Net] minor float jitter at turn %d with peer %d (streak %d/3), deferring snapshot" % [n, peer, _desync_streak[peer]])
			return
	_desync_streak.erase(peer)
	desyncs += 1
	print("[Net] desync at turn %d with peer %d (%d so far): sending a snapshot; differs: %s" % [n, peer, desyncs, dp])
	if main != null and main.has_method("net_toast"):
		main.net_toast("РАССИНХРОН #%d · %s" % [desyncs, dp.left(90)])  # NET 34 (ПРЕДВАРИТЕЛЬНО, diagnostics): phones keep no log
	if not _resync_q.has(peer):
		_resync_q.append(peer)


var _guard_h: String = ""
var _guard_m: Dictionary = {}  # NET 34: "system.field" -> hash() at the end of the last run turns
var _guard_seen: Dictionary = {}
## Fields that change between turns on purpose (visual / per-device / diagnostics), not simulation.
const _GUARD_SKIP: Dictionary = {"econ._ab_status": true, "econ.draw_ver": true, "econ._snd_t": true, "econ._reach_ui": true,
	"rng.draws": true, "rng.log_tick": true, "rng.log_on": true, "ops.preview_arrow": true, "ops.preview_order": true,
	"ops._prev": true, "ops._prev_key": true, "ops._all_prev": true, "ops._all_key": true, "ops._str_cache": true}


## NET 34 (--net-guard): hash() of every script field of the simulation systems. A field that moves
## between turns was written by a UI / frame call on this device only (a cache included).
## NET 37: the perf counters since the last call (and reset): tick EMA / max, frame max, ticks in a frame, job waits, backlog.
func perf_take() -> Dictionary:
	var d: Dictionary = {"tick": snappedf(perf_tick_ms, 0.01), "tick_max": snappedf(perf_tick_max, 0.1), "frame_max": snappedf(perf_frame_max, 0.1),
		"ticks_frame": perf_ticks_frame_max, "job_wait": snappedf(gw.perf_job_wait_max, 0.1), "backlog": maxi(0, last_turn - exec_turn), "holds": perf_holds}
	perf_holds = 0
	perf_tick_max = 0.0
	perf_frame_max = 0.0
	perf_ticks_frame_max = 0
	gw.perf_job_wait_max = 0.0
	return d


func _member_sig() -> Dictionary:
	var out: Dictionary = {}
	var sys: Dictionary = {"econ": gw.econ, "ports": gw.econ.ports if gw.econ != null else null, "supply": gw.supply, "diplo": gw.diplo,
		"ai": gw.ai, "mil": gw.mil, "air": gw.mil.air if gw.mil != null else null, "army": gw.army, "fire": gw.army.fire if gw.army != null else null,
		"ops": gw.ops, "navy": gw.navy, "naval": gw.naval, "defense": gw.defense, "protect": gw.protect, "recon": gw.recon, "rail": gw.rail,
		"kpp": gw.kpp, "session": gw.session, "rng": gw.rng}
	for nm: String in sys:
		var o: Object = sys[nm]
		if o == null:
			continue
		for pr: Dictionary in o.get_property_list():
			if int(pr["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			var pn: String = String(pr["name"])
			if pn == "gw":
				continue
			var v: Variant = o.get(pn)
			if v is Object:
				continue
			out["%s.%s" % [nm, pn]] = hash(v)
	return out
var _guard_p: Variant = {}
var guard_hits: int = 0


## NET 34 (--net-guard): the simulation changed between two turns = something outside the lockstep
## (a UI sheet, a frame-time layer, a timer) wrote it, on this device only. The log names the parts.
func _guard_check() -> void:
	if _guard_h == "":
		return
	if not _guard_m.is_empty():
		var now_m: Dictionary = _member_sig()
		var moved: PackedStringArray = PackedStringArray()
		for k: String in now_m:
			if _guard_m.has(k) and int(_guard_m[k]) != int(now_m[k]) and not _GUARD_SKIP.has(k):
				moved.append(k)
		if not moved.is_empty():
			var key: String = ",".join(moved)
			if not _guard_seen.has(key):  # each set of fields once (a cache refilled every frame would flood)
				_guard_seen[key] = true
				guard_hits += 1
				print("[NetGuard] fields changed between turns (turn %d): %s" % [exec_turn, key])
		_guard_m = now_m
	var h: String = NetHash.of(gw)
	if h == _guard_h:
		return
	guard_hits += 1
	var now_p: Variant = JSON.parse_string(JSON.stringify(NetHash.parts(gw)))
	var diff: PackedStringArray = PackedStringArray()
	if now_p is Dictionary and _guard_p is Dictionary:
		for k: String in now_p:
			if str(now_p[k]) != str((_guard_p as Dictionary).get(k)):
				diff.append("%s: %s -> %s" % [k, str((_guard_p as Dictionary).get(k)).left(60), str(now_p[k]).left(60)])
	print("[NetGuard] state changed between turns (turn %d, t=%.1f): %s" % [exec_turn, gw.game_time, "; ".join(diff) if not diff.is_empty() else "(outside the trace parts)"])
	_guard_h = h
	_guard_p = now_p


## NET 34: entries of `a` that `b` lacks (with repeats), oldest first, at most 4.
static func _only_in(a: Variant, b: Variant) -> Array:
	var left: Dictionary = {}
	if b is Array:
		for e: Variant in b:
			left[str(e)] = int(left.get(str(e), 0)) + 1
	var out: Array = []
	if a is Array:
		for e2: Variant in a:
			var k: String = str(e2)
			if int(left.get(k, 0)) > 0:
				left[k] = int(left[k]) - 1
			elif out.size() < 4:
				out.append(k)
	return out


## NET 34: every country field that differs: "country 2 money host=5120 guest=5000".
func _diff_countries(a: Variant, b: Variant) -> String:
	if not (a is Array) or not (b is Array) or (a as Array).size() != (b as Array).size():
		return "countries?"
	var names: Array = ["id", "money", "fuel", "titanium", "metal", "wood", "oil", "precious", "food", "goods", "cities", "towns_founded", "uranium"]
	var out: PackedStringArray = PackedStringArray()
	for i in (a as Array).size():
		var ea: Array = a[i]
		var eb: Array = b[i]
		for j in range(1, mini(ea.size(), eb.size())):
			if str(ea[j]) != str(eb[j]):
				out.append("country %s %s host=%s guest=%s" % [str(ea[0]), names[j] if j < names.size() else str(j), str(ea[j]), str(eb[j])])
	return ", ".join(out.slice(0, 4)) if not out.is_empty() else "countries (lists equal)"


## NET 34: the diplomacy entries that differ: "opinion 1:3 host=12 guest=10" / "n offers host=1 guest=0".
func _diff_dict(a: Variant, b: Variant) -> String:
	if not (a is Dictionary) or not (b is Dictionary):
		return "diplo?"
	var out: PackedStringArray = PackedStringArray()
	var keys: Dictionary = {}
	for k: Variant in a:
		keys[k] = true
	for k2: Variant in b:
		keys[k2] = true
	var ks: Array = keys.keys()
	ks.sort()
	for k3: Variant in ks:
		if str((a as Dictionary).get(k3, "-")) != str((b as Dictionary).get(k3, "-")):
			out.append("%s host=%s guest=%s" % [str(k3), str((a as Dictionary).get(k3, "-")), str((b as Dictionary).get(k3, "-"))])
	return ", ".join(out.slice(0, 4)) if not out.is_empty() else "diplo (entries equal)"


## NET 34: the first unit whose short record differs: "unit 17 pos" / "unit 17 only on host" ...
func _diff_units(a: Variant, b: Variant) -> String:
	if not (a is Array) or not (b is Array):
		return "units?"
	var by: Dictionary = {}
	for e: Variant in b:
		if e is Array and (e as Array).size() >= 7:
			by[int(e[0])] = e
	var names: Array = ["id", "x", "y", "hp", "state", "target", "path"]
	for e2: Variant in a:
		if not (e2 is Array) or (e2 as Array).size() < 7:
			continue
		var id: int = int(e2[0])
		if not by.has(id):
			return "unit %d only on host" % id
		var g: Array = by[id]
		for i in range(1, 7):
			if str(e2[i]) != str(g[i]):
				return "unit %d %s host=%s guest=%s" % [id, names[i], str(e2[i]), str(g[i])]
		by.erase(id)
	if not by.is_empty():
		return "unit %d only on guest" % int(by.keys()[0])
	return "units (same list, differ beyond it)"


## NET 34: which NetHash parts of `peer` differ from the host's at turn `n` (the log says what to look for).
func _diff_parts(n: int, peer: int) -> String:
	var hp: Dictionary = _hparts.get(n, {})
	var gp: Dictionary = (_gparts.get(n, {}) as Dictionary).get(peer, {})
	if hp.is_empty() or gp.is_empty():
		return "?"
	var hp2: Variant = JSON.parse_string(JSON.stringify(hp))  # the same JSON round trip as the guest's
	var out: PackedStringArray = PackedStringArray()
	for k: String in hp2:
		if str(gp.get(k)) != str(hp2[k]):
			out.append(k)
			desync_parts[k] = int(desync_parts.get(k, 0)) + 1
	if out.is_empty():
		return "(parts equal: the difference is outside the trace parts)"
	if out.has("ulist"):
		out.remove_at(out.find("ulist"))
		out.append(_diff_units(hp2.get("ulist", []), gp.get("ulist", [])))
	if out.has("clist"):
		out.remove_at(out.find("clist"))
		out.append(_diff_countries(hp2.get("clist", []), gp.get("clist", [])))
	if out.has("dlist"):
		out.remove_at(out.find("dlist"))
		out.append(_diff_dict(hp2.get("dlist", {}), gp.get("dlist", {})))
	if out.has("estats"):
		out.remove_at(out.find("estats"))
		out.append("money flows: " + _diff_dict(hp2.get("estats", {}), gp.get("estats", {})))
	if out.has("okinds"):
		out.remove_at(out.find("okinds"))
		out.append("objects by kind: " + _diff_dict(hp2.get("okinds", {}), gp.get("okinds", {})))
	if out.has("oblocks"):
		out.remove_at(out.find("oblocks"))
		out.append("object id blocks (x1024): " + _diff_dict(hp2.get("oblocks", {}), gp.get("oblocks", {})).replace("host=", "h=").replace("guest=", "g="))
	if out.has("money_log"):
		out.remove_at(out.find("money_log"))
		out.append("money changes only on host %s, only on guest %s" % [str(_only_in(hp2.get("money_log", []), gp.get("money_log", []))), str(_only_in(gp.get("money_log", []), hp2.get("money_log", [])))])
	if out.has("rng_log"):
		out.remove_at(out.find("rng_log"))
		out.append("rng draws only on host %s, only on guest %s" % [str(_only_in(hp2.get("rng_log", []), gp.get("rng_log", []))), str(_only_in(gp.get("rng_log", []), hp2.get("rng_log", [])))])
	var tail: String = ""
	for k2: String in ["time", "rng", "units", "fire_rng"]:
		if out.has(k2):
			tail += " %s host=%s guest=%s" % [k2, str(hp2[k2]).left(40), str(gp.get(k2)).left(40)]
	return ", ".join(out) + tail


func _send_snapshot(n: int) -> bool:
	if not _sync_wait.is_empty():
		return false  # finish the current transfers before starting more
	var t0: int = Time.get_ticks_usec()
	var now_ms: int = Time.get_ticks_msec()
	var peers: PackedInt32Array = multiplayer.get_peers()
	var targets: Array[int] = []
	var pending: Array = []
	for p: Variant in _resync_q:
		var pid: int = int(p)
		if pid <= 1 or not peers.has(pid) or targets.has(pid) or pending.has(pid):
			continue
		if now_ms - int(_last_snap_ms.get(pid, -15000)) < 15000:
			pending.append(pid)  # preserve the request until the peer can receive a new snapshot
		else:
			targets.append(pid)
	_resync_q = pending
	if targets.is_empty():
		return false
	var bytes: PackedByteArray = Save.net_snapshot(main)  # Save already compresses with Zstandard.
	if bytes.is_empty():
		for pid: int in targets:
			_resync_q.append(pid)
			_last_snap_ms[pid] = now_ms  # keep the request, but avoid a retry on every turn
		print("[Net] snapshot is empty; retrying later for peers %s" % str(targets))
		return false
	_lag.clear()  # NET 37: the backlogs of before the snapshot hold nothing now
	_lag_now.clear()
	var ch: int = NetConfig.SNAP_CHUNK
	var parts: int = ceili(float(bytes.size()) / float(ch))
	for pid: int in targets:
		_last_snap[pid] = n
		_last_snap_ms[pid] = now_ms
		_sync_wait[pid] = {"turn": n, "started_ms": Time.get_ticks_msec()}
		_snap_begin.rpc_id(pid, n, bytes.size(), parts)
		for i in parts:
			_snap_part.rpc_id(pid, i, bytes.slice(i * ch, mini((i + 1) * ch, bytes.size())))
			if i % 8 == 7:
				_flush_peer()
	resyncs += 1
	print("[Net] snapshot of turn %d sent to peers %s: %d KiB in %d parts, %.1f ms" % [n, str(targets), bytes.size() / 1024, parts, (Time.get_ticks_usec() - t0) / 1000.0])
	return true


@rpc("authority", "call_remote", "reliable")
func _snap_begin(n: int, size: int, parts: int, raw_size: int = 0) -> void:
	_snap = {"turn": n, "size": size, "parts": parts, "raw_size": raw_size, "got": {}}
	_snap_t = 0.0
	stall_t = 0.0
	_rj_t = 0.0  # progress (the rejoin watchdog)


@rpc("authority", "call_remote", "reliable")
func _snap_part(i: int, data: PackedByteArray) -> void:
	if _snap.is_empty():
		return
	(_snap["got"] as Dictionary)[i] = data
	_snap_t = 0.0
	stall_t = 0.0
	_rj_t = 0.0  # progress (the rejoin watchdog)
	if (_snap["got"] as Dictionary).size() >= int(_snap["parts"]):
		_apply_snapshot()


@rpc("authority", "call_remote", "reliable")
func _snap_abort() -> void:
	print("[Net] host aborted snapshot resync")
	_snap = {}
	_snap_t = 0.0
	_restoring = false
	if main != null and main.get("loading") != null and main.loading.active:
		main.loading.finish()
	if not is_host:
		_start_reconnect()


func _apply_snapshot() -> void:
	var got: Dictionary = _snap["got"]
	var n: int = int(_snap["turn"])
	var raw_size: int = int(_snap.get("raw_size", 0))
	var buf := PackedByteArray()
	for i in int(_snap["parts"]):
		buf.append_array(got[i])
	_snap = {}
	if raw_size > 0:
		var decomp: PackedByteArray = buf.decompress(raw_size, FileAccess.COMPRESSION_DEFLATE)
		if not decomp.is_empty():
			buf = decomp
		else:
			push_warning("[Net] failed to decompress snapshot of turn %d" % n)
	if _restoring:
		_snap_next = [buf, n]  # one restore at a time; the newest snapshot follows it
		return
	_restore_from(buf, n)


## State of turn n from a snapshot (guest: the host's; host: its own, sent at the same moment).
func _restore_from(buf: PackedByteArray, n: int) -> void:
	_restoring = true
	_guard_h = ""  # NET 34: a snapshot replaces the state (not a leak)
	var t0: int = Time.get_ticks_msec()
	# NET 34: the fog is this device's (the snapshot carries the host's: a guest saw every host building)
	var keep_vis: Dictionary = gw.vision.net_keep() if gw.vision != null and gw.player != null and not rejoining else {}
	var ok: bool = await Save.net_restore(main, buf)
	if not in_match:  # left (or the host was lost) while restoring: back to single-player state
		gw.net_driven = false
		_restoring = false
		return
	if not ok:
		_restoring = false
		if main != null and main.get("loading") != null and main.loading.active:
			main.loading.finish()
		push_error("[Net] Save.net_restore failed for turn %d" % n)
		leave(true, true, true, true)
		_status("Не удалось восстановить мир · попробуйте вернуться в партию")
		return
	gw.net_driven = true
	gw.player = gw.country_by_id(local_slot + 1)
	if ok and gw.vision != null:
		gw.vision.net_rebind(gw.vision.net_keep() if _own_fog else keep_vis)  # NET 35: a resumed host's snapshot holds its own fog
	gw.net_tick = (n + 1) * NetConfig.TICKS_PER_TURN
	exec_turn = n + 1
	exec_tick = 0
	_acc = 0.0
	stall_t = 0.0
	resyncs += 1
	print("[Net] resync to turn %d: %s, %d ms" % [n, "ok" if ok else "FAILED", Time.get_ticks_msec() - t0])
	if main.has_method("net_after_restore"):
		main.net_after_restore()
	_restoring = false
	if not is_host:
		_snap_ack.rpc_id(1, n)
	if rejoining:  # NET 32: back in the match
		rejoining = false
		go = true
		if main != null and main.has_method("net_toast"):
			main.net_toast("ВЫ СНОВА В ПАРТИИ")
	if not _snap_next.is_empty():
		var nx: Array = _snap_next
		_snap_next = []
		if int(nx[1]) > n:
			_restore_from(nx[0], int(nx[1]))


@rpc("any_peer", "call_remote", "reliable")
func _snap_ack(n: int) -> void:
	if not is_host:
		return
	var from: int = multiplayer.get_remote_sender_id()
	if _sync_wait.has(from):
		if bool((_sync_wait[from] as Dictionary).get("disconnecting", false)):
			return
		if n != int((_sync_wait[from] as Dictionary).get("turn", -1)):
			print("[Net] ignoring snapshot ack from peer %d for unexpected turn %d" % [from, n])
			return
		var elapsed: int = Time.get_ticks_msec() - int((_sync_wait[from] as Dictionary).get("started_ms", 0))
		print("[Net] peer %d acknowledged snapshot of turn %d (%d ms taken)" % [from, n, elapsed])
		_sync_wait.erase(from)
		var s: int = _slot_of(from)
		if s >= 0:
			_lag.erase(s)
			_lag_now.erase(s)


func _kick_desynced_peer(pid: int) -> void:
	var s: int = _slot_of(pid)
	if s >= 0 and s < slots.size():
		var pname: String = String(slots[s].get("name", "Игрок"))
		print("[Net] dropping desynced peer %d (%s) -> handing over to AI" % [pid, pname])
		if main != null and main.has_method("net_toast"):
			main.net_toast("РАССИНХРОН: %s ОТКЛЮЧЁН (ИИ ПРИНЯЛ СТРАНУ)" % pname.to_upper())
	if multiplayer.get_peers().has(pid):
		var p: MultiplayerPeer = multiplayer.multiplayer_peer
		if p != null:
			p.disconnect_peer(pid)


## R332 crash fix (TestFlight 0.30.26, ENetConnection::flush on a null host): leave() runs from the
## server_disconnected / connection_failed handlers when the ENet host is already closed — flush only a live host.
func _flush_peer() -> void:
	var p: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if p == null or p.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	var h: ENetConnection = p.host
	if h == null:
		return
	h.flush()
