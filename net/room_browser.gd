class_name RoomBrowser
extends Node





signal rooms_changed
signal peeked(code: String, open: bool)

const REFRESH_S: float = 2.5
const ANSWER_S: float = 8.0
const STATE_OFF: int = 0
const STATE_LOADING: int = 1
const STATE_OK: int = 2
const STATE_FAIL: int = 3

var rooms: Array = []
var state: int = STATE_OFF
var busy: bool = false
var _ws: WebSocketPeer = null
var _open: bool = false
var _t: float = 0.0
var _wait: float = 0.0
var _url: String = ""
var _retried: bool = false
var _closing: Array = []
var fail_why: String = ""
var _err_why: String = ""


func start() -> void :
	NetConfig.load_cfg()
	if _ws != null and _url != NetConfig.signal_url:
		stop()
	if _ws != null:
		refresh()
		return
	if NetConfig.signal_url == "" or not RtcLink.available() or (not Account.signed_in() and not RtcLink.relay_only()):
		_set_state(STATE_FAIL)
		return
	fail_why = ""
	_err_why = ""
	_ws = WebSocketPeer.new()
	_url = NetConfig.signal_url
	_wait = 0.0
	if RtcLink.open_socket(_ws) != OK:
		_ws = null
		_set_state(STATE_FAIL)
		return
	_open = false
	busy = true
	if rooms.is_empty():
		_set_state(STATE_LOADING)


func stop() -> void :
	if _ws != null:


		_ws.close(1000)
		_closing.append([_ws, 3.0])
	_ws = null
	_open = false
	busy = false
	state = STATE_OFF




var _peek_q: String = ""


func peek(code: String) -> void :
	_peek_q = code
	if _ws == null:
		start()
	_send_peek()


func _send_peek() -> void :
	if _peek_q != "" and _ws != null and _open:
		_ws.send_text(JSON.stringify({"t": "peek", "code": _peek_q, "v": NetConfig.version(),
			"name": NetConfig.nick() if RtcLink.relay_only() else Account.username()}))
		_peek_q = ""



func refresh() -> void :
	if _ws == null:
		start()
		return
	if _open and not busy:
		busy = true
		_wait = 0.0
		_t = REFRESH_S
		_ws.send_text(JSON.stringify({"t": "list", "v": NetConfig.version(),
			"name": NetConfig.nick() if RtcLink.relay_only() else Account.username()}))
		rooms_changed.emit()


func _set_state(s: int) -> void :
	state = s
	rooms_changed.emit()


func _process(delta: float) -> void :
	for c: Array in _closing.duplicate():
		var cw: WebSocketPeer = c[0]
		cw.poll()
		c[1] = float(c[1]) - delta
		if cw.get_ready_state() == WebSocketPeer.STATE_CLOSED or float(c[1]) <= 0.0:
			_closing.erase(c)
	if _ws == null:
		return
	_ws.poll()
	if busy:
		_wait += delta
		if _wait > ANSWER_S:
			stop()
			_set_state(STATE_FAIL)
			return
	var st: int = _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _open:
			_open = true
			_retried = false
			busy = false
			refresh()
			_send_peek()
		_t -= delta
		if _t <= 0.0 and not busy:
			refresh()
	elif st == WebSocketPeer.STATE_CLOSED:
		var refused: bool = not _open
		fail_why = _err_why
		if _ws.get_close_code() == 1013 and fail_why == "":
			fail_why = "СЛИШКОМ МНОГО ПОДКЛЮЧЕНИЙ · ПОВТОРИТЕ ЧЕРЕЗ МИНУТУ"
		_ws = null
		_open = false
		busy = false
		_set_state(STATE_FAIL)
		if refused and not _retried:
			_retried = true
			if await Account.refresh() and state != STATE_OFF and _ws == null:
				start()
		return
	while _ws != null and _ws.get_available_packet_count() > 0:
		var d: Variant = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
		if d is Dictionary and String((d as Dictionary).get("t", "")) == "peek":
			peeked.emit(String((d as Dictionary).get("code", "")), bool((d as Dictionary).get("open", false)))
			continue
		if d is Dictionary and String((d as Dictionary).get("t", "")) == "error":
			_err_why = String((d as Dictionary).get("why", "")).to_upper()
			continue
		if d is Dictionary and String((d as Dictionary).get("t", "")) == "rooms":
			rooms = (d as Dictionary).get("rooms", [])
			busy = false
			fail_why = ""
			_set_state(STATE_OK)
