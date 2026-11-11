extends Node













const SLOP: float = 10.0
const GLIDE_MS: int = 140
const CATCH_MS: int = 300

var _pressed: Array = []
var _down: bool = false
var _from: Vector2 = Vector2.ZERO
var _void: bool = false
var _drag_end: int = -100000
var _scrolls: Array = []
var stats: Dictionary = {"cancel_drag": 0, "cancel_glide": 0, "hold_tip": 0}


const HoldTip = preload("res://ui/ui24/hold_tip.gd")
var _press_ms: int = 0



var _hold_armed: bool = false
var _tipped: bool = false
var tip_layer: CanvasLayer = null


func _ready() -> void :
	get_tree().node_added.connect(_on_node)
	_scan(get_tree().root)


func _input(ev: InputEvent) -> void :
	on_input(ev)
	if get_index() != get_parent().get_child_count() - 1:
		get_parent().move_child.call_deferred(self, -1)


func _scan(n: Node) -> void :
	_on_node(n)
	for c: Node in n.get_children():
		_scan(c)


func _on_node(n: Node) -> void :
	if n is BaseButton:
		var b: = n as BaseButton
		if not b.button_down.is_connected(_on_btn_down):
			b.button_down.connect(_on_btn_down.bind(b))
	elif n is ScrollContainer:
		for e: Array in _scrolls:
			if e[0] == n:
				return
		_scrolls.append([n, Vector2.ZERO, -100000])


func _on_btn_down(b: BaseButton) -> void :
	for i: int in range(_pressed.size() - 1, -1, -1):
		if not is_instance_valid(_pressed[i]):
			_pressed.remove_at(i)
	if not _pressed.has(b):
		_pressed.append(b)
	if _void:
		_kill(b)


func _kill(b: BaseButton) -> void :
	if b != null and is_instance_valid(b) and not b.disabled:
		b.disabled = true
		b.disabled = false



func cancel() -> void :
	for b: Variant in _pressed:



		if is_instance_valid(b):
			_kill(b as BaseButton)
	_pressed.clear()


func on_input(ev: InputEvent) -> void :
	if ev is InputEventScreenTouch:
		var st: = ev as InputEventScreenTouch
		if st.index != 0:
			return
		if st.pressed:

			_down = true
			_from = st.position
			_void = false
			_hold_begin()
			if _gliding_at(st.position):
				_void = true
				stats["cancel_glide"] = int(stats["cancel_glide"]) + 1
				cancel()
		else:
			if _void and not _tipped:
				_drag_end = Time.get_ticks_msec()
			_hold_end()
			_down = false
			_void = false
			_pressed.clear()
	elif ev is InputEventScreenDrag:
		var sd: = ev as InputEventScreenDrag
		if _tipped and sd.index == 0 and tip_layer != null and sd.position.distance_to(_from) > SLOP * 2.0:
			tip_layer.call("hide_now")
		if sd.index != 0 or not _down or _void:
			return
		if sd.position.distance_to(_from) > SLOP:
			_void = true
			stats["cancel_drag"] = int(stats["cancel_drag"]) + 1
			cancel()
	elif ev is InputEventMouseButton:
		var mb: = ev as InputEventMouseButton
		if mb.device != InputEvent.DEVICE_ID_EMULATION and mb.button_index == MOUSE_BUTTON_LEFT:

			if mb.pressed:
				_down = true
				_from = mb.position
				_void = _gliding_at(mb.position)
				_hold_begin()
				if _void:
					cancel()
			else:
				if _void and not _tipped:
					_drag_end = Time.get_ticks_msec()
				_hold_end()
				_down = false
				_void = false
				_pressed.clear()
	elif ev is InputEventMouseMotion:
		var mm: = ev as InputEventMouseMotion
		if mm.device != InputEvent.DEVICE_ID_EMULATION and _down and not _void and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if mm.position.distance_to(_from) > SLOP:
				_void = true
				cancel()



func _gliding_at(p: Vector2) -> bool:
	var now: int = Time.get_ticks_msec()
	if now - _drag_end > 2500:
		return false
	var catch: bool = now - _drag_end <= CATCH_MS
	for e: Array in _scrolls:
		var scv: Variant = e[0]
		if not is_instance_valid(scv):
			continue
		var sc: ScrollContainer = scv
		if not sc.is_visible_in_tree() or not sc.get_global_rect().has_point(p):
			continue
		var moved_ago: int = now - int(e[2])
		if moved_ago < GLIDE_MS or (catch and moved_ago < CATCH_MS + 200):
			return true
	return false



func scroll_at(p: Vector2) -> ScrollContainer:
	var best: ScrollContainer = null
	var best_a: float = INF
	for e: Array in _scrolls:
		var scv: Variant = e[0]
		if not is_instance_valid(scv):
			continue
		var sc: ScrollContainer = scv
		if not sc.is_visible_in_tree():
			continue
		var r: Rect2 = sc.get_global_rect()
		if not r.has_point(p):
			continue
		var vb: ScrollBar = sc.get_v_scroll_bar()
		var hb: ScrollBar = sc.get_h_scroll_bar()
		var can: bool = (vb != null and vb.max_value > vb.page + 1.0 and sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED)\
		or (hb != null and hb.max_value > hb.page + 1.0 and sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED)
		if can and r.get_area() < best_a:
			best_a = r.get_area()
			best = sc
	return best


func _hold_begin() -> void :
	_press_ms = Time.get_ticks_msec()
	_hold_armed = false
	_tipped = false
	if tip_layer != null and tip_layer.call("is_showing"):
		tip_layer.call("hide_now")


func _hold_end() -> void :
	if _tipped and tip_layer != null:
		tip_layer.call("release")
	_tipped = false




func _hold_check() -> void :
	if not _down or _void or _tipped or _pressed.is_empty():
		return
	if not _hold_armed:
		_hold_armed = true
		return
	if Time.get_ticks_msec() - _press_ms < HoldTip.HOLD_MS:
		return
	for b: Variant in _pressed:
		if b == null or not is_instance_valid(b) or not (b as Control).is_visible_in_tree():
			continue
		if (b as Object).has_meta("hold_act"):
			continue
		var t: String = HoldTip.text_of(b)
		if t == "":
			continue
		_tipped = true
		_void = true
		cancel()
		if tip_layer == null or not is_instance_valid(tip_layer):
			tip_layer = HoldTip.new()
			add_child(tip_layer)
		if not is_instance_valid(b):
			return
		tip_layer.call("show_at", _from, t, (b as Control).get_global_rect())
		stats["hold_tip"] = int(stats["hold_tip"]) + 1
		return


func _process(_d: float) -> void :
	_hold_check()
	var now: int = Time.get_ticks_msec()
	for i: int in range(_scrolls.size() - 1, -1, -1):
		var e: Array = _scrolls[i]
		var sc: Variant = e[0]
		if not is_instance_valid(sc):
			_scrolls.remove_at(i)
			continue
		if not (sc as ScrollContainer).visible:
			continue
		var v: = Vector2((sc as ScrollContainer).scroll_horizontal, (sc as ScrollContainer).scroll_vertical)
		if v != e[1]:
			e[1] = v
			e[2] = now
