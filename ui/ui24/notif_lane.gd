extends Control

















signal action(name: String)

const U = preload("res://ui/ui24/econ_kit.gd")
const PRIO: Dictionary = {"ult": 0, "war": 1, "alert": 1, "status": 1, "msg": 2, "news": 2, "note": 2, "hint": 3, "tip": 3}
const TTL: Dictionary = {"war": 3.5, "alert": 4.0, "status": 7.0, "msg": 3.0, "news": 4.0, "note": 3.0, "hint": 6.0, "tip": 9.0}
const MAX_SHOWN: int = 2

const QUEUE_CAP: Dictionary = {"status": 3, "news": 4, "msg": 4, "war": 2, "tip": 1, "note": 1, "alert": 3}
const QUEUE_MAX_AGE: float = 15.0
const Calm = preload("res://ui/ui24/notif_calm.gd")
const NOTE_GAP: float = 10.0
const NOTE_HOLD: float = 20.0
const QUIET_S: float = 25.0
const JOURNAL_CAP: int = 40
const DISMISS: Array = ["msg", "news", "note", "alert", "tip"]
const PILL_W: float = 54.0
const MORE_HANG: float = 26.0
const W: float = 316.0
const AMBER: = Color("ffb000")

var clock_on: bool = true
var width: float = W
var x_min: float = 8.0
var x_max: float = -1.0
var max_shown: int = MAX_SHOWN
var dock_bottom: float = -1.0
var expand_until: int = 0
var _compact: bool = false
var _rail: Array = []
var _anchor: Control = null
var push_y: float = 0.0
var _anchor2: Control = null
var _shown: Array = []
var _queue: Array = []
var _seq: int = 0
var _vb: VBoxContainer
var _more: PanelContainer
var _more_hit: Button
var _more_lbl: Label
var _dirty_place: bool = false
var _last_h: float = -1.0

var clock: float = 0.0
var journal: Array = []
var journal_unread: int = 0
var quiet_until: float = 0.0
var note_next: float = 0.0
var _note_pend: Array = []
var inbox_n: int = 0
var _inbox_btn: Button
var _inbox_lbl: Label
var _inbox_dot: ColorRect
var stats: Dictionary = {}
var hold_tips: bool = false



const SOFT: Array = ["tip", "hint"]
var hold_soft: bool = false:
	set(v):
		if v != hold_soft:
			hold_soft = v
			_settle()





const CONF_HOLD: Array = ["msg", "news", "note", "status", "tip", "hint", "war"]
var hold_conf: bool = false:
	set(v):
		if v != hold_conf:
			hold_conf = v
			if v:
				for j: int in range(_shown.size() - 1, -1, -1):
					if _conf_own(_shown[j]["d"]):
						_drop_node(_shown[j])
						_shown.remove_at(j)
				for k: int in range(_queue.size() - 1, -1, -1):
					if _conf_own(_queue[k]["d"]):
						_queue.remove_at(k)
			if not v:
				for q: Dictionary in _queue:
					if String(q["kind"]) in CONF_HOLD:
						q["born"] = clock
			_settle()




static func _conf_own(d: Dictionary) -> bool:
	return Loc.src_of(String(d.get("title", ""))).to_upper().begins_with("КОНФЕРЕНЦИЯ")


func _held(it: Dictionary) -> bool:
	return (hold_soft and String(it["kind"]) in SOFT) or (hold_conf and String(it["kind"]) in CONF_HOLD)


func _next_q() -> int:
	for i: int in _queue.size():
		if not _held(_queue[i]):
			return i
	return -1



class Ring extends Control:
	var frac: float = 1.0:
		set(v):
			var nv: float = clampf(v, 0.0, 1.0)
			if absf(nv - frac) > 0.002:
				frac = nv
				queue_redraw()
	func _init() -> void :
		custom_minimum_size = Vector2(16, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void :
		var fr: int = clampi(int(floor((1.0 - frac) * 8.0)), 0, 7)
		var t: Texture2D = UiKit.tex("icon_timer_ring_%d" % fr)
		if t != null:
			draw_texture_rect(t, Rect2(Vector2.ZERO, Vector2(16, 16)), false)
			return
		var c: = Vector2(8, 8)
		draw_circle(c, 8.0, UiKit.OUTLINE)
		draw_circle(c, 6.5, Color("3a1a12"))
		draw_arc(c, 5.0, 0.0, TAU, 24, Color(1, 1, 1, 0.12), 3.0, false)
		if frac > 0.0:
			draw_arc(c, 5.0, - PI * 0.5, - PI * 0.5 + TAU * frac, 24, AMBER, 3.0, false)
		draw_circle(c, 1.5, AMBER)


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("notif_lane")
	add_to_group("i18n")
	_vb = VBoxContainer.new()
	_vb.add_theme_constant_override("separation", 4)
	_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vb.custom_minimum_size = Vector2(W, 0)
	add_child(_vb)

	_more = PanelContainer.new()
	_more.add_theme_stylebox_override("panel", UiKit.sb("wb_btn_stone", 7, 2))
	_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more.visible = false
	add_child(_more)
	_more_hit = Button.new()
	_more_hit.flat = true
	_more_hit.focus_mode = Control.FOCUS_NONE
	for s: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_more_hit.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	_more_hit.visible = false
	_more_hit.pressed.connect( func() -> void :
		UiKit.snd("ui_click")
		expand_until = Time.get_ticks_msec() + 6000
		_settle()
		action.emit("notif_queue"))
	add_child(_more_hit)
	_vb.sort_children.connect(_place_more)
	var mh: = HBoxContainer.new()
	mh.add_theme_constant_override("separation", 4)
	mh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more.add_child(mh)
	var dots: = HBoxContainer.new()
	dots.add_theme_constant_override("separation", 2)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mh.add_child(dots)
	dots.visible = false
	for i: int in 3:
		var d: = ColorRect.new()
		d.custom_minimum_size = Vector2(3, 3)
		d.color = UiKit.MUTED if i == 0 else UiKit.DIM
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(d)
	_more_lbl = UiKit.lbl("", 10, UiKit.TEXT, 2, 2)
	mh.add_child(_more_lbl)
	_build_inbox()
	resized.connect(_place)
	_settle()




func _build_inbox() -> void :
	_inbox_btn = Button.new()
	_inbox_btn.name = "InboxPill"
	_inbox_btn.focus_mode = Control.FOCUS_NONE
	_inbox_btn.custom_minimum_size = Vector2(PILL_W, 44)
	_inbox_btn.size = Vector2(PILL_W, 44)
	_inbox_btn.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_stone", 4, 2, -1))
	_inbox_btn.add_theme_stylebox_override("hover", UiKit.sb("wb_btn_stone", 4, 2, -1))
	_inbox_btn.add_theme_stylebox_override("pressed", UiKit.sb("wb_btn_stone_p", 4, 2, 1))
	_inbox_btn.add_theme_stylebox_override("hover_pressed", UiKit.sb("wb_btn_stone_p", 4, 2, 1))
	_inbox_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_inbox_btn.tooltip_text = "Входящие"
	_inbox_btn.visible = false
	UiKit.press_fx(_inbox_btn)
	_inbox_btn.pressed.connect( func() -> void : action.emit("inbox"))
	add_child(_inbox_btn)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_bottom = -11.0
	_inbox_btn.add_child(hb)
	var cap: Label = UiKit.lbl("ВХОДЯЩ.", 9, UiKit.TEXT, 1, 2)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_top = -14.0
	cap.offset_bottom = -2.0
	_inbox_btn.add_child(cap)
	var ic: TextureRect = U.icon("icon_dip_pending", 18.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	_inbox_lbl = UiKit.lbl("", 12, UiKit.GOLD, 2, 3)
	_inbox_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_inbox_lbl)
	_inbox_dot = ColorRect.new()
	_inbox_dot.custom_minimum_size = Vector2(5, 5)
	_inbox_dot.color = UiKit.GOLD
	_inbox_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_inbox_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_inbox_dot)



func set_inbox(n: int) -> void :
	if n == inbox_n and _inbox_btn != null and _inbox_btn.visible == _pill_on():
		return
	var rise: bool = n > inbox_n
	inbox_n = n
	_sync_pill()
	if rise and _inbox_btn.visible:
		_inbox_btn.pivot_offset = _inbox_btn.size * 0.5
		_inbox_btn.scale = Vector2(1.18, 1.18)
		_inbox_btn.create_tween().tween_property(_inbox_btn, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pill_on() -> bool:
	return (inbox_n > 0 or journal_unread > 0) and dock_bottom < 0.0


func _sync_pill() -> void :
	if _inbox_btn == null:
		return
	var on: bool = _pill_on()
	var t: String = str(inbox_n) if inbox_n > 0 else ""
	if _inbox_lbl.text != t:
		_inbox_lbl.text = t
	U.set_vis(_inbox_lbl, inbox_n > 0)
	U.set_vis(_inbox_dot, inbox_n == 0 and journal_unread > 0)
	if _inbox_btn.visible != on:
		_inbox_btn.visible = on
		_place()



func mark_read() -> void :
	if journal_unread != 0:
		journal_unread = 0
		_sync_pill()


func _log(text: String, lvl: int, unread: bool = false) -> void :
	if not journal.is_empty() and String(journal[journal.size() - 1]["text"]) == text:
		return
	journal.append({"t": clock, "text": text, "lvl": lvl, "k": Loc.keep(text)})
	if journal.size() > JOURNAL_CAP:
		journal.pop_front()
	if unread:
		journal_unread += 1
		_sync_pill()


func _stat(k: String) -> void :
	stats[k] = int(stats.get(k, 0)) + 1






var _mute: Dictionary = {}


func mute_title(text: String, secs: float) -> void :
	_mute[text.to_upper()] = clock + secs


func _muted(text: String) -> bool:
	var u: String = text.to_upper()
	for k: String in _mute.keys():
		if clock > float(_mute[k]):
			_mute.erase(k)
		elif u.contains(k) or k.contains(u):
			return true
	return false


func ambient(text: String, lvl: int, col: Color = Color(0, 0, 0, 0)) -> void :
	if text == "":
		return
	if not _mute.is_empty() and _muted(text):
		_log(text, Calm.NOTE)
		return
	_stat("amb_%d" % lvl)
	match lvl:
		Calm.URGENT:
			_log(text, lvl)
			push("alert", {"title": text, "colour": Color("ffb8a8"), "icon": "icon_rel_war"})
		Calm.NOTE:
			_log(text, lvl)
			var key: String = Calm.merge_key(text)
			var mk: String = key if key != "" else text
			for e: Dictionary in _note_pend:
				if String(e["mk"]) == mk:
					e["n"] = int(e["n"]) + 1
					e["text"] = text
					e["tk"] = Loc.keep(text)
					return
			_note_pend.append({"mk": mk, "key": key, "n": 1, "text": text, "t0": clock, "col": col, "tk": Loc.keep(text)})
			_note_tick()
		_:
			_log(text, lvl)


static func _note_title(e: Dictionary) -> String:
	var n: int = int(e["n"])
	if n <= 1:
		return String(e["text"])
	if String(e["key"]) != "":
		return "%s ×%d · %s" % [String(e["key"]), n, String(e["text"])]
	return "%s (×%d)" % [String(e["text"]), n]



func _note_tick() -> void :
	if _note_pend.is_empty():
		return
	for i: int in range(_note_pend.size() - 1, -1, -1):
		if clock - float(_note_pend[i]["t0"]) > NOTE_HOLD:
			var old: Dictionary = _note_pend[i]
			_note_pend.remove_at(i)
			journal_unread += int(old["n"])
			_stat("note_to_journal")
			_sync_pill()
	if _note_pend.is_empty() or clock < note_next or clock < quiet_until:
		return
	for it: Dictionary in _shown + _queue:
		if String(it["kind"]) in ["ult", "war", "alert", "note", "news"]:
			return
	var e: Dictionary = _note_pend.pop_front()
	note_next = clock + NOTE_GAP
	var t: String = _note_title(e)
	var d: Dictionary = {"title": t, "ttl": 2.6 + clampf((t.length() - 40) * 0.03, 0.0, 1.4)}
	if int(e["n"]) <= 1 and e.has("tk"):
		d["tk"] = e["tk"]
	if (e["col"] as Color).a > 0.0:
		d["colour"] = e["col"]
	push("note", d)



func dismiss(it: Dictionary) -> void :
	var i: int = _shown.find(it)
	if i < 0:
		return
	UiKit.snd("ui_click")
	_retire(i)
	_stat("dismiss")
	if String(it["kind"]) in ["note", "news", "alert"]:
		quiet_until = clock + QUIET_S
		note_next = maxf(note_next, quiet_until)
	_settle()



func attach(hud: Node) -> void :
	var root_c: Control = hud.get("root")
	root_c.add_child(self)
	process_priority = 102
	size = Vector2(root_c.get_viewport_rect().size.x, 0)
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	_anchor = hud.get("res_panel")
	var tc: Control = hud.get("top_col")
	if tc != null and tc.get_child_count() > 0:
		_anchor2 = tc.get_child(0) as Control
	var rail: Array = []
	for cb: Variant in hud.get("cmd_btns"):
		rail.append((cb as Array)[0])
	track_rail(rail)



func track_rail(controls: Array) -> void :
	_rail = controls
	_follow()



func set_compact(on: bool) -> void :
	if on == _compact:
		return
	_compact = on
	_settle()


func _cap() -> int:
	if Time.get_ticks_msec() < expand_until:
		return 3
	return 1 if _compact or _squeezed else MAX_SHOWN





var _squeezed: bool = false


func bottom() -> float:
	var b: float = position.y + (_vb.size.y if _vb != null and not _shown.is_empty() else 0.0)
	if _more != null and _more.visible and not _shown.is_empty():
		b = maxf(b, _more.get_global_rect().end.y - 2.0)
	return b


func _follow() -> void :
	if _vb == null:
		return


	if _vb.size.y > _vb.get_combined_minimum_size().y + 0.5:
		_vb.reset_size()
	var a: Control = _anchor if _anchor != null and is_instance_valid(_anchor) and _anchor.is_visible_in_tree() else _anchor2
	var y: float = position.y
	if dock_bottom >= 0.0:
		y = roundf(dock_bottom - _vb.size.y - 2.0)
	elif a != null and is_instance_valid(a) and a.is_visible_in_tree():
		y = roundf(a.get_global_rect().end.y + 4.0 + push_y)
	if absf(position.y - y) > 0.5:
		position.y = y
	var x1: float = -1.0
	var x1f: float = -1.0
	if dock_bottom < 0.0:
		for c9: Variant in _rail:
			if not is_instance_valid(c9):
				continue
			var ct9: Control = c9 as Control
			if ct9 != null and is_instance_valid(ct9) and ct9.is_visible_in_tree():
				var r9: Rect2 = ct9.get_global_rect()
				if r9.position.y <= position.y + float(MAX_SHOWN) * 48.0 + 12.0 and r9.end.y >= position.y:
					var g9: float = r9.position.x - global_position.x - 6.0
					x1f = g9 if x1f < 0.0 else minf(x1f, g9)
	var x0f: float = x_min + (PILL_W + 4.0 if _inbox_btn != null and _inbox_btn.visible else 0.0)
	var sq: bool = x1f > 0.0 and x1f - x0f < 160.0
	if sq != _squeezed:
		_squeezed = sq
		_settle()
	if dock_bottom < 0.0:
		for c: Variant in _rail:
			if not is_instance_valid(c):
				continue
			var ctl: Control = c as Control
			if ctl != null and is_instance_valid(ctl) and ctl.is_visible_in_tree():
				var r: Rect2 = ctl.get_global_rect()
				if r.position.y > position.y + maxf(_vb.size.y, 44.0) + 12.0 + MORE_HANG or r.end.y < position.y:
					continue
				var gx: float = r.position.x - global_position.x - 6.0
				x1 = gx if x1 < 0.0 else minf(x1, gx)
	var parent_w: float = get_parent_area_size().x
	var size_changed: bool = absf(size.x - parent_w) > 0.5
	if size_changed:
		size.x = parent_w
	if absf(x1 - x_max) > 0.5 or size_changed:
		set_band(x_min, x1)
	if _vb.size.y != _last_h:
		_last_h = _vb.size.y
		_place_more()



func _place_more() -> void :
	if _more == null or not _more.visible:
		return
	var last: Control = null
	for it: Dictionary in _shown:
		if it["node"] != null and is_instance_valid(it["node"]) and not (it["node"] as Node).is_queued_for_deletion():
			last = it["node"]
	if last == null:
		return
	var ms: Vector2 = _more.get_combined_minimum_size()
	_more.size = ms
	var r: Rect2 = last.get_global_rect()
	_more.global_position = Vector2(roundf(_vb.global_position.x + width - ms.x - 36.0), roundf(r.end.y - 6.0))
	_more_hit.size = Vector2(ms.x + 16.0, 44.0)
	_more_hit.global_position = _more.global_position + Vector2(-8.0, (ms.y - 44.0) * 0.5)



func set_band(x0: float, x1: float) -> void :
	x_min = x0
	x_max = x1
	_place()


func _place() -> void :
	if _vb == null:
		return



	var right: float = minf(x_max if x_max > 0.0 else 1000000000.0, size.x - 8.0)
	var x0: float = x_min
	if _inbox_btn != null and _inbox_btn.visible:
		_inbox_btn.position = Vector2(x_min, 0.0)
		x0 = x_min + PILL_W + 4.0
	width = maxf(160.0, minf(W, right - x0))
	var x: float = clampf(roundf((size.x - width) * 0.5), x0, maxf(x0, right - width))
	_vb.custom_minimum_size = Vector2(width, 0)
	for it: Dictionary in _shown:
		var n: Control = it["node"]
		if n != null and is_instance_valid(n):
			n.custom_minimum_size.x = width
			if n.has_node("Badge"):
				(n.get_node("Badge") as Control).position.x = width - 10.0
	_vb.position = Vector2(x, 0)
	_vb.reset_size()
	_place_more()




func push(kind: String, d: Dictionary) -> void :
	if d.has("title") and not d.has("tk"):
		d["tk"] = Loc.keep(String(d["title"]))
	if d.has("sub") and not d.has("sk"):
		d["sk"] = Loc.keep(String(d["sub"]))
	if kind == "tip" and hold_tips:
		return
	if hold_conf and kind != "ult" and _conf_own(d):
		return
	if not passes(kind, d):
		_stat("muted_" + kind)
		if kind != "tip" and kind != "ult":
			_log(String(d.get("title", "")), Calm.NOTE, true)
		return
	if kind == "ult" or kind == "hint":
		for it: Dictionary in _shown + _queue:
			if String(it["kind"]) == kind:
				it["d"] = d
				if kind == "hint":
					it["left"] = float(d.get("ttl", 1000000000.0))
				if it["node"] != null:
					if kind == "ult":
						_update_chip(it)
					else:
						_update_line(it)
				return
	if kind == "msg" or kind == "news" or kind == "tip" or kind == "war" or kind == "alert" or kind == "note" or kind == "status":


		for it2: Dictionary in _shown + _queue:
			if String(it2["kind"]) == kind and String(it2["d"].get("title", "")) == String(d.get("title", "")):
				it2["left"] = float(it2["total"]) if it2.has("total") else maxf(float(it2["left"]), float(d.get("ttl", TTL.get(kind, 3.0))))
				return

	if kind in ["msg", "news", "note", "alert"] and _queue.size() > 0:
		var cat_n: String = String(line_cat(kind, short_text(String(d.get("title", ""))))[0])
		for q7: Dictionary in _queue:
			if String(q7["kind"]) == kind and String(line_cat(kind, short_text(String(q7["d"].get("title", ""))))[0]) == cat_n:
				var nd7: Dictionary = d.duplicate()
				nd7["merged"] = int(q7["d"].get("merged", 1)) + 1
				q7["d"] = nd7
				_stat("merged")
				_settle()
				return
	_seq += 1
	var ttl: float = float(d.get("ttl", TTL.get(kind, 0.0)))
	_queue.append({"id": _seq, "kind": kind, "prio": int(d.get("prio", PRIO.get(kind, 3))), "seq": _seq, "left": ttl, "d": d, "node": null, 
		"born": clock})
	_stat("push_" + kind)
	if QUEUE_CAP.has(kind):
		var n_k: int = 0
		for i: int in range(_queue.size() - 1, -1, -1):
			if String(_queue[i]["kind"]) == kind:
				n_k += 1
				if n_k > int(QUEUE_CAP[kind]):
					_queue.remove_at(i)
	_settle()







static func passes(kind: String, d: Dictionary) -> bool:
	var md: int = GameConfig.notif_mode
	if md <= 0 or kind == "hint" or (kind == "msg" and bool(d.get("reply", false))):
		return true
	if kind == "status":
		return md < 2
	if md >= 2:
		return false
	if kind == "ult" or kind == "war" or kind == "alert":
		return true
	if kind == "tip":
		return false
	return Calm.important(String(d.get("title", "")))




func refilter() -> void :
	var hit: bool = false
	for arr: Array in [_shown, _queue]:
		for i: int in range(arr.size() - 1, -1, -1):
			var it: Dictionary = arr[i]
			if passes(String(it["kind"]), it["d"]):
				continue
			if String(it["kind"]) != "tip" and String(it["kind"]) != "ult":
				_log(String(it["d"].get("title", "")), Calm.NOTE, true)
			_drop_node(it)
			arr.remove_at(i)
			hit = true
	if GameConfig.notif_mode >= 1 and not _note_pend.is_empty():
		for e: Dictionary in _note_pend:
			if GameConfig.notif_mode >= 2 or not Calm.important(String(e["text"])):
				journal_unread += int(e["n"])
		_note_pend = _note_pend.filter( func(e: Dictionary) -> bool: return GameConfig.notif_mode < 2 and Calm.important(String(e["text"])))
		_sync_pill()
	if hit:
		_settle()



func clear_all() -> void :
	for arr: Array in [_shown, _queue]:
		for it: Dictionary in arr:
			_drop_node(it)
	_shown.clear()
	_queue.clear()
	expand_until = 0
	_settle()


func remove_kind(kind: String) -> void :
	var hit: bool = false
	for arr: Array in [_shown, _queue]:
		for i: int in range(arr.size() - 1, -1, -1):
			if String(arr[i]["kind"]) == kind:
				if arr[i]["node"] != null and is_instance_valid(arr[i]["node"]):
					(arr[i]["node"] as Node).queue_free()
				arr.remove_at(i)
				hit = true
	if hit:
		_settle()



func chip_style() -> String:
	for it: Dictionary in _shown + _queue:
		if String(it["kind"]) == "ult":
			return String(it["d"].get("style", "red"))
	return ""


func has_kind(kind: String) -> bool:
	for it: Dictionary in _shown + _queue:
		if String(it["kind"]) == kind:
			return true
	return false


static func _better(a: Dictionary, b: Dictionary) -> bool:
	if int(a["prio"]) != int(b["prio"]):
		return int(a["prio"]) < int(b["prio"])
	return int(a["seq"]) < int(b["seq"])




const FADE_S: float = 0.25


func _retire(i: int) -> void :
	var it: Dictionary = _shown[i]
	_shown.remove_at(i)
	var nd: Control = it["node"]
	it["node"] = null
	if nd == null or not is_instance_valid(nd) or nd.get_parent() != _vb:
		if nd != null and is_instance_valid(nd):
			nd.queue_free()
		return
	var gp: Vector2 = nd.global_position
	var sz: Vector2 = nd.size
	var idx: int = nd.get_index()
	var sp: = Control.new()
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.custom_minimum_size = Vector2(1, sz.y)
	_vb.add_child(sp)
	_vb.move_child(sp, idx)
	_vb.remove_child(nd)
	add_child(nd)
	nd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nd.global_position = gp
	nd.size = sz
	var tw: Tween = nd.create_tween()
	tw.tween_property(nd, "modulate:a", 0.0, FADE_S)
	tw.tween_callback(nd.queue_free)
	var t2: Tween = sp.create_tween()
	t2.tween_interval(FADE_S * 0.4)
	t2.tween_property(sp, "custom_minimum_size:y", 0.0, FADE_S * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t2.tween_callback(sp.queue_free)


func _drop_node(it: Dictionary) -> void :
	if it["node"] != null and is_instance_valid(it["node"]):
		var nd: Node = it["node"]
		if nd.get_parent() != null:
			nd.get_parent().remove_child(nd)
		nd.queue_free()
	it["node"] = null


func _settle() -> void :
	if _vb == null:
		return
	var cap: int = _cap()
	for j: int in range(_shown.size() - 1, -1, -1):
		if _held(_shown[j]):
			var hs: Dictionary = _shown[j]
			_shown.remove_at(j)
			_drop_node(hs)
			_queue.append(hs)
	_queue.sort_custom(_better)
	while _shown.size() > cap:
		_shown.sort_custom(_better)
		var extra: Dictionary = _shown.pop_back()
		_drop_node(extra)
		_queue.append(extra)
	_queue.sort_custom(_better)

	while _next_q() >= 0 and _shown.size() >= cap and cap > 0:
		_shown.sort_custom(_better)
		var weakest: Dictionary = _shown[_shown.size() - 1]
		var qi: int = _next_q()
		if not _better(_queue[qi], weakest):
			break
		var nx: Dictionary = _queue[qi]
		_queue.remove_at(qi)
		_shown.pop_back()
		_drop_node(weakest)
		_queue.append(weakest)
		_queue.sort_custom(_better)
		_show(nx)
	while _shown.size() < cap and _next_q() >= 0:
		var qi2: int = _next_q()
		var nx2: Dictionary = _queue[qi2]
		_queue.remove_at(qi2)
		_show(nx2)
	_shown.sort_custom(_better)

	var prev_i: int = -1
	for i: int in _shown.size():
		var sn: Control = _shown[i]["node"]
		if sn == null or not is_instance_valid(sn) or sn.get_parent() != _vb:
			continue
		var ci: int = sn.get_index()
		if ci <= prev_i:
			_vb.move_child(sn, prev_i)
			ci = sn.get_index()
		prev_i = ci
	var n_wait: int = 0
	for q9: Dictionary in _queue:
		if not _held(q9):
			n_wait += 1
	_more.visible = n_wait > 0
	_more_hit.visible = _more.visible
	_more_lbl.text = Loc.t("ещё %d") % n_wait
	_place.call_deferred()


func _show(it: Dictionary) -> void :
	var n: Control
	match String(it["kind"]):
		"ult":
			n = _make_chip(it)
		"war":
			n = _make_war(it)
		"status":
			n = _make_status(it)
			if not it.has("total"):
				it["left"] = 7.0
				it["total"] = 7.0
		_:
			n = _make_line(it)


			var k9: String = String(it["kind"])
			if k9 in ["msg", "news", "note", "alert"] and not it.has("total"):
				var c9: String = String(line_cat(k9, short_text(String(it["d"].get("title", ""))))[0])
				var life: float = 10.0 if c9 == "red" else (6.0 if c9 == "stone" else 7.0)
				it["left"] = life
				it["total"] = life
			elif k9 == "tip" and not it.has("total"):
				it["total"] = maxf(1.0, float(it["left"]))
	it["node"] = n
	_vb.add_child(n)
	_shown.append(it)

	n.pivot_offset = Vector2(width * 0.5, 20)
	n.modulate.a = 0.0
	var from: float = 1.25 if String(it["kind"]) == "war" else 0.94
	n.scale = Vector2(from, from)
	var tw: Tween = n.create_tween().set_parallel(true)
	tw.tween_property(n, "modulate:a", 1.0, 0.15)
	tw.tween_property(n, "scale", Vector2.ONE, 0.3 if String(it["kind"]) == "war" else 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)





func relocalize() -> void :
	for e: Dictionary in journal:
		if e.has("k"):
			e["text"] = Loc.re(e["k"])
	for e2: Dictionary in _note_pend:
		if e2.has("tk"):
			e2["text"] = Loc.re(e2["tk"])
	for it: Dictionary in _shown + _queue:
		var d: Dictionary = it["d"]
		if d.has("tk"):
			d["title"] = Loc.re(d["tk"])
		if d.has("sk"):
			d["sub"] = Loc.re(d["sk"])
		var v: Variant = it["node"]
		if v == null or not is_instance_valid(v):
			continue
		var old: Control = v
		if String(it["kind"]) == "ult":
			_update_chip(it)
			continue
		if old.get_parent() != _vb:
			continue
		var idx: int = old.get_index()
		var n: Control
		match String(it["kind"]):
			"war":
				n = _make_war(it)
			"status":
				n = _make_status(it)
			_:
				n = _make_line(it)
		it["node"] = n
		_vb.add_child(n)
		_vb.move_child(n, idx)
		_vb.remove_child(old)
		old.queue_free()
	_settle()



func advance(sec: float) -> void :
	var gone: bool = false
	clock += sec
	for j: int in range(_queue.size() - 1, -1, -1):
		var q: Dictionary = _queue[j]
		if QUEUE_CAP.has(String(q["kind"])) and clock - float(q.get("born", clock)) > QUEUE_MAX_AGE and not (hold_conf and _held(q)):
			_queue.remove_at(j)
			if String(q["kind"]) in ["note", "news"]:
				journal_unread += 1
			gone = true
	for i: int in range(_shown.size() - 1, -1, -1):
		var it: Dictionary = _shown[i]
		if String(it["kind"]) == "ult":
			continue
		if bool(it.get("hold", false)):
			continue
		it["left"] = float(it["left"]) - (sec / 0.6 if it.has("total") and _queue.size() >= 3 else sec)
		if it.has("total") and it["node"] != null and is_instance_valid(it["node"]):
			var bn: Control = it["node"]
			bn.set_meta("frac", clampf(float(it["left"]) / maxf(0.01, float(it["total"])), 0.0, 1.0))
			bn.queue_redraw()
		if float(it["left"]) <= 0.0:
			_retire(i)
			gone = true
	if gone:
		_settle()
	_note_tick()


var _was_expanded: bool = false







func _chip_heights() -> void :
	for it: Dictionary in _shown:
		var n: Control = it["node"]
		if n == null or not is_instance_valid(n) or String(it["kind"]) != "ult" or not n.has_meta("parts"):
			continue
		var s2: Label = (n.get_meta("parts") as Array)[2]
		if s2 == null or not is_instance_valid(s2) or s2.size.x < 8.0:
			continue
		var hh: float = 54.0 if s2.get_line_count() > 1 else 44.0
		if absf(n.custom_minimum_size.y - hh) > 0.5:
			n.custom_minimum_size.y = hh


func _fit_texts() -> void :
	for it: Dictionary in _shown:
		var n: Control = it["node"]
		if n == null or not is_instance_valid(n) or not n.has_meta("fit"):
			continue
		for e: Variant in n.get_meta("fit"):
			var l: Label = (e as Array)[0]
			if l == null or not is_instance_valid(l) or l.size.x < 8.0:
				continue
			var key: String = "%s|%d" % [l.text, int(l.size.x)]
			if String(l.get_meta("fitk", "")) == key:
				continue
			l.set_meta("fitk", key)
			var f: Font = l.get_theme_font("font")
			var hi: int = int((e as Array)[1])
			var lo: int = int((e as Array)[2])
			var fs: int = hi
			var drop: Variant = n.get_meta("fit_drop") if n.has_meta("fit_drop") else null
			while fs > lo and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > l.size.x:
				if drop is Label and is_instance_valid(drop) and (drop as Label).visible:
					(drop as Label).visible = false
					l.set_meta("fitk", "")
					break
				fs -= 1
			if l.get_theme_font_size("font_size") != fs:
				l.add_theme_font_size_override("font_size", fs)
			if (e as Array).size() > 3 and bool((e as Array)[3]):


				var src: String = String(l.get_meta("full", l.text))
				var wrap: bool = f.get_string_size(src, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > l.size.x
				var am: int = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
				if l.autowrap_mode != am:
					l.autowrap_mode = am
					l.clip_text = not wrap
					l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if wrap else TextServer.OVERRUN_TRIM_ELLIPSIS
					l.max_lines_visible = 2 if wrap else -1
					l.add_theme_constant_override("line_spacing", -3 if wrap else 0)
					if not wrap and l.has_meta("full"):
						l.text = String(l.get_meta("full"))
						l.remove_meta("clipk")
					l.set_meta("fitk", "%s|%d" % [l.text, int(l.size.x)])


func _process(delta: float) -> void :
	_follow()
	_fit_texts()
	_chip_heights()
	_clip_lines()
	var ex: bool = Time.get_ticks_msec() < expand_until
	if ex != _was_expanded:
		_was_expanded = ex
		_settle()
	if clock_on:
		advance(delta)


func blocked_rects() -> Array:
	var out: Array = []
	if not is_visible_in_tree():
		return out
	for it: Dictionary in _shown:
		var n: Control = it["node"]
		if n != null and is_instance_valid(n):
			out.append(n.get_global_rect().grow(2.0))
	if _more.visible:
		out.append(_more.get_global_rect().grow(2.0))
	if _inbox_btn != null and _inbox_btn.visible:
		out.append(_inbox_btn.get_global_rect().grow(2.0))
	return out



func state() -> Array:
	var out: Array = []
	for it: Dictionary in _shown:
		out.append(String(it["kind"]))
	out.append("+%d" % _queue.size())
	return out



func rects() -> Array:
	var out: Array = []
	for it: Dictionary in _shown:
		var n: Control = it["node"]
		if n != null and is_instance_valid(n):
			out.append(n.get_global_rect())
	if _more.visible:
		out.append(_more_hit.get_global_rect())
	if _inbox_btn != null and _inbox_btn.visible:
		out.append(_inbox_btn.get_global_rect())
	return out




func _make_chip(it: Dictionary) -> Control:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(width, 44)
	b.pressed.connect( func() -> void : action.emit("diplomacy_pending"))
	UiKit.press_fx(b)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 10
	hb.offset_right = -12
	b.add_child(hb)
	var ring: = Ring.new()
	ring.name = "Ring"
	ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ring)
	var ic: TextureRect = U.icon(String(it["d"].get("icon", "icon_dip_pending")), 24.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(col)
	var t: Label = UiKit.lbl("", 12, UiKit.TEXT, 2, 3)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(t)
	var s2: Label = UiKit.lbl("", 9, Color("ffe0d4"), 1, 2)
	s2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s2.max_lines_visible = 2
	s2.add_theme_constant_override("line_spacing", -2)
	col.add_child(s2)
	var tl: Label = UiKit.lbl("", 14, UiKit.GOLD, 2, 3)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(tl)
	var bd: Label = U.badge_label(1)
	bd.name = "Badge"
	bd.position = Vector2(width - 10.0, -4.0)
	b.add_child(bd)
	b.set_meta("parts", [ring, t, s2, tl, bd, ic])
	b.set_meta("fit", [[t, 12, 10]])
	it["node"] = b
	_update_chip(it)
	return b


func _update_chip(it: Dictionary) -> void :
	var b: Button = it["node"]
	var parts: Array = b.get_meta("parts")
	var d: Dictionary = it["d"]
	var style: String = String(d.get("style", "red"))
	if String(b.get_meta("style", "")) != style:
		b.set_meta("style", style)
		for s: String in ["normal", "hover"]:
			b.add_theme_stylebox_override(s, UiKit.sb("wb_btn_" + style, 8, 2, -1))
		b.add_theme_stylebox_override("pressed", UiKit.sb("wb_btn_%s_p" % style, 8, 2, 1))
		b.add_theme_stylebox_override("hover_pressed", UiKit.sb("wb_btn_%s_p" % style, 8, 2, 1))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icn: String = String(d.get("icon", "icon_dip_pending"))
	if String(b.get_meta("icon", "")) != icn:
		b.set_meta("icon", icn)
		U.set_icon(parts[5], icn, 24.0)
	var left: float = float(d.get("left", 0.0))
	var noexp: bool = left < 0.0
	if noexp:
		left = maxf(1.0, float(d.get("total", 90.0)))
	(parts[0] as Ring).frac = left / maxf(1.0, float(d.get("total", 90.0)))
	U.set_lbl(parts[1], String(d.get("title", "УЛЬТИМАТУМ")), UiKit.TEXT)
	U.set_lbl(parts[2], String(d.get("sub", "")), Color("ffe0d4"))
	U.set_lbl(parts[3], "∞" if noexp else U.mmss(left), UiKit.GOLD)
	var n: int = int(d.get("count", 1))
	if (parts[4] as Label).text != str(n):
		(parts[4] as Label).text = str(n)
	U.set_vis(parts[4], n > 1)

	var pulsing: bool = b.has_meta("pulse")
	if left < 20.0 and not pulsing:
		var tw: Tween = b.create_tween().set_loops()
		tw.tween_property(b, "self_modulate:a", 0.65, 0.45)
		tw.tween_property(b, "self_modulate:a", 1.0, 0.45)
		b.set_meta("pulse", tw)
	elif left >= 20.0 and pulsing:
		(b.get_meta("pulse") as Tween).kill()
		b.remove_meta("pulse")
		b.self_modulate.a = 1.0




func _make_war(it: Dictionary) -> Control:
	var d: Dictionary = it["d"]
	var pc: = PanelContainer.new()
	pc.custom_minimum_size = Vector2(width, 34)
	pc.add_theme_stylebox_override("panel", UiKit.sb("wb_ribbon", 10, 2, -1))
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.gui_input.connect( func(ev: InputEvent) -> void :
		if (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
			action.emit("war_focus"))
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	hb.add_theme_constant_override("separation", 6)
	var ic: TextureRect = U.icon(String(d.get("icon", "icon_rel_war")), 16.0, "icon_war_declare")
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var t: Label = UiKit.lbl(String(d.get("title", "ВОЙНА")), 13, UiKit.TEXT, 3, 3)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(t)
	if String(d.get("sub", "")) != "" and width >= 250.0:
		var sl: Label = UiKit.lbl(String(d["sub"]).replace("тап — ", "").to_upper(), 9, Color("ffe7c2"), 1, 2)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(sl)
		pc.set_meta("fit_drop", sl)
	pc.set_meta("fit", [[t, 13, 10]])
	return pc







const STATUS_TONE: Dictionary = {"up": "", "down": "ffb000", "crisis": "ff6a4d", "other": "7cccff"}


func _make_status(it: Dictionary) -> Control:
	var d: Dictionary = it["d"]
	var MS: Script = load("res://ui/ui24/my_state.gd") as Script
	var tier: int = int(d.get("tier", -1))
	var tone: String = String(d.get("tone", "up"))
	var tc: Color = Color(String(STATUS_TONE.get(tone, ""))) if String(STATUS_TONE.get(tone, "")) != "" else (Color("ffd75e") if MS == null else (MS.call("tier_col", tier) as Color))
	var pc: = PanelContainer.new()
	pc.custom_minimum_size = Vector2(width, 58)
	var sb: StyleBox = UiKit.sb("wb_card", 6, 3)
	sb.content_margin_bottom = 7.0
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	var rim: = Panel.new()
	var rs: = StyleBoxFlat.new()
	rs.draw_center = false
	rs.border_color = tc
	rs.set_border_width_all(2)
	rs.set_corner_radius_all(3)
	rim.add_theme_stylebox_override("panel", rs)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc.add_child(rim)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)
	if MS != null:
		var bd: Control = MS.call("badge", tier, bool(d.get("crisis", false)), 2, false, String(MS.call("art_state", int(d.get("state", 0))))) as Control
		hb.add_child(bd)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", -1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(col)
	col.add_child(UiKit.lbl(Loc.t("СТАТУС СТРАНЫ") if bool(d.get("own", true)) else Loc.t("МИРОВАЯ АРЕНА"), 9, tc, 2, 2))
	var head: Label = UiKit.lbl(String(d.get("title", "")), 12, UiKit.TEXT, 2, 3)
	head.clip_text = true
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(head)
	var sub: Label = UiKit.lbl(String(d.get("sub", "")), 10, UiKit.MUTED, 1, 2)
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(sub)
	pc.set_meta("fit", [[head, 12, 10]])
	var cid: int = int(d.get("cid", -1))
	var own: bool = bool(d.get("own", true))
	pc.gui_input.connect( func(ev: InputEvent) -> void :
		var mb: = ev as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			it["hold"] = mb.pressed
			if not mb.pressed:
				dismiss(it)
				action.emit("mystate" if own else "mystate:%d" % cid))
	var bar_c: Color = tc
	pc.draw.connect( func() -> void :
		if not pc.has_meta("frac"):
			return
		var w9: float = pc.size.x - 10.0
		var y9: float = pc.size.y - 6.0
		pc.draw_rect(Rect2(5.0, y9, w9, 3.0), Color(0, 0, 0, 0.45))
		pc.draw_rect(Rect2(5.0, y9, roundf(w9 * float(pc.get_meta("frac"))), 3.0), bar_c))
	var tw: Tween = rim.create_tween().set_loops(2)
	tw.tween_property(rim, "modulate", Color(1.6, 1.6, 1.6, 1.0), 0.18)
	tw.tween_property(rim, "modulate", Color.WHITE, 0.3)
	return pc








const LINE_H: float = 44.0



static func line_cat(kind: String, t: String) -> Array:
	var s: String = Loc.src_of(t).to_lower()
	if kind == "hint" or kind == "tip":
		return ["gold", "icon_hint"]
	if s.begins_with("удар не состоялся") or s.begins_with("удар отменён"):
		return ["stone", "icon_info"]

	if s.begins_with("наш удар") or (s.begins_with("удар") and not s.begins_with("удар по") and (s.contains(" · ") or s.begins_with("удар:"))):
		return ["green", "icon_target"]
	var blue_w: String = ""
	if not s.contains("войн"):
		for w: String in ["мир с ", "мирн", "перемир", "союз", "альянс", "договор", "предлага", "санкци", "эмбарго", "посол", "отношени"]:
			if s.contains(w):
				blue_w = w
				break
	var threat: bool = s.contains("потерян") or s.contains("лидер мира") or s.begins_with("враг на ") or s.begins_with("враг у ") or s.begins_with("враг идёт") or s.begins_with("враг наступает") or s.contains("на нашей земле")
	var good: bool = s.contains("без света") or s.contains("обесточ") or s.contains("разбит") or s.contains("отступ") or s.contains("город взят") or s.contains(" взял") or s.contains("построено") or s.contains("основан") or s.contains("заключён мир") or s.contains("мир заключ")
	if kind == "alert" or threat or (Calm.important(t) and blue_w == "" and not good):
		var ri: String = "icon_strike"
		if s.contains("лидер мира") or s.contains("сплачива") or s.contains("коалиц"):
			ri = "icon_coalition"
		elif s.contains("войн") or s.contains("ультиматум") or s.contains("капитул"):
			ri = "icon_war_declare"
		elif s.contains("ракет") or s.contains("летит") or s.contains("летят"):
			ri = "icon_m_ballistic"
		elif s.contains("десант"):
			ri = "icon_land"
		elif s.contains("корабл") or s.contains("порт") or s.contains("флот"):
			ri = "icon_ship"
		elif s.contains("город"):
			ri = "icon_city"
		return ["red", ri]
	if good:
		var gi: String = "icon_ok"
		if s.contains("свет") or s.contains("обесточ"):
			gi = "icon_power"
		elif s.contains("город") or s.contains("основан"):
			gi = "icon_city"
		elif s.contains("мир"):
			gi = "icon_peace"
		return ["green", gi]
	if blue_w != "":
		return ["blue", "icon_alliance" if (blue_w == "союз" or blue_w == "альянс") else ("icon_peace" if blue_w.begins_with("мир") or blue_w == "перемир" else "icon_diplomacy")]
	for w2: String in ["свет", "сеть", "энерг", "тэц", "склад", "куплен", "продан", "рынок", "торг", "завод", "денег", "деньг", "доход", "руд", "нефт", "металл", "ресурс"]:
		if s.contains(w2):
			var ei: String = "icon_market"
			if w2 in ["свет", "сеть", "энерг", "тэц"]:
				ei = "icon_power"
			elif w2 == "склад":
				ei = "icon_store"
			elif w2 == "завод":
				ei = "icon_factory"
			return ["gold", ei]
	return ["stone", "icon_info"]


const TAB_COL: Dictionary = {"red": "c8483a", "blue": "3c7ec8", "gold": "d39a2c", "green": "5aa83c", "stone": "6a6e58"}


static func _tab_sb(cat: String) -> StyleBoxFlat:
	var f: = StyleBoxFlat.new()
	f.bg_color = Color(String(TAB_COL.get(cat, "6a6e58")))
	f.border_color = UiKit.OUTLINE
	f.set_border_width_all(1)
	f.set_content_margin_all(4)
	return f




static func line_split(t: String) -> Array:
	var cut: int = -1
	var sl: int = 0
	for sep: String in [": ", " — "]:
		var ci: int = t.find(sep)
		if ci > 3 and ci <= 36 and (cut < 0 or ci < cut):
			cut = ci
			sl = sep.length()
	if cut < 0 or t.length() - cut - sl < 3:
		return [t, ""]
	var sub: String = t.substr(cut + sl).strip_edges()
	return [t.substr(0, cut), sub.substr(0, 1).to_upper() + sub.substr(1)]


func _make_line(it: Dictionary) -> Control:
	var d: Dictionary = it["d"]
	var kind: String = String(it["kind"])
	var hint: bool = kind == "hint" or kind == "tip"
	var full: String = short_text(String(d.get("title", "")))
	full = full.replace("расчётное время ", "через ").replace("Расчётное время ", "Через ")
	var cat: Array = line_cat(kind, full)
	var pc: = PanelContainer.new()
	pc.custom_minimum_size = Vector2(width, LINE_H)
	var card_sb: StyleBox = UiKit.sb("wb_card", 4, 3)
	card_sb.content_margin_bottom = 7.0
	pc.add_theme_stylebox_override("panel", card_sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)

	var tab: = PanelContainer.new()
	tab.name = "Tab"
	tab.add_theme_stylebox_override("panel", _tab_sb(String(cat[0])))
	tab.custom_minimum_size = Vector2(32, 32)
	tab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tab)
	var icn: String = String(cat[1])
	if (kind == "msg" or hint) and String(d.get("icon", "")) != "":
		icn = String(d["icon"])
	var ic: TextureRect = U.icon(icn, 22.0, "icon_info")
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tab.add_child(ic)

	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", -1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(col)
	var parts: Array = line_split(full)
	var mg: int = int(d.get("merged", 1))
	if mg > 1:
		if String(parts[1]) != "":
			parts[0] = "×%d · %s" % [mg, String(parts[0])]
		else:
			full = "×%d · %s" % [mg, full]
			parts = [full, ""]
	var head: Label = UiKit.lbl("", 11, UiKit.TITLE if hint else UiKit.TEXT, 2, 2)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(head)
	var sub: Label = UiKit.lbl("", 10, UiKit.MUTED, 1, 2)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if kind == "alert":
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.max_lines_visible = 2
		sub.set_meta("alert", true)
	else:
		sub.clip_text = true
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(sub)
	pc.set_meta("head_lbl", head)
	pc.set_meta("sub_lbl", sub)
	pc.set_meta("tab", tab)
	pc.set_meta("tab_ic", ic)
	_set_line_text(pc, full, parts)
	if DISMISS.has(kind):

		var xk: = PanelContainer.new()
		xk.add_theme_stylebox_override("panel", UiKit.sb("wb_btn_stone", 2, 2))
		xk.custom_minimum_size = Vector2(22, 22)
		xk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		xk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var xi: Label = UiKit.lbl("×", 13, UiKit.TEXT, 2, 2)
		xi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		xi.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		xk.add_child(xi)
		hb.add_child(xk)
		pc.mouse_filter = Control.MOUSE_FILTER_STOP
		pc.gui_input.connect( func(ev: InputEvent) -> void :
			var mb: = ev as InputEventMouseButton
			if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
				accept_event()
				it["hold"] = mb.pressed
				if not mb.pressed:
					dismiss(it))

	var bar_c: Color = Color(String(TAB_COL.get(String(cat[0]), "6a6e58"))).lightened(0.25)
	pc.draw.connect( func() -> void :
		if not pc.has_meta("frac"):
			return
		var w9: float = pc.size.x - 10.0
		var y9: float = pc.size.y - 6.0
		pc.draw_rect(Rect2(5.0, y9, w9, 3.0), Color(0, 0, 0, 0.45))
		pc.draw_rect(Rect2(5.0, y9, roundf(w9 * float(pc.get_meta("frac"))), 3.0), bar_c))
	return pc



func _set_line_text(pc: Control, full: String, parts: Array) -> void :
	var head: Label = pc.get_meta("head_lbl")
	var sub: Label = pc.get_meta("sub_lbl")
	var two: bool = String(parts[1]) != ""
	head.remove_meta("fitk")
	head.remove_meta("clipk")
	if two:
		head.autowrap_mode = TextServer.AUTOWRAP_OFF
		head.clip_text = true
		head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		head.max_lines_visible = -1
		head.text = String(parts[0])
		sub.text = String(parts[1])
		sub.remove_meta("full")
		sub.remove_meta("clipk")
		sub.visible = true
		pc.set_meta("fit", [[head, 11, 10], [sub, 10, 9, not sub.has_meta("alert")]])
		if pc.has_meta("title_lbl"):
			pc.remove_meta("title_lbl")
	else:
		head.clip_text = false
		head.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.max_lines_visible = 2
		head.add_theme_font_size_override("font_size", 11 if full.length() <= 34 else 10)
		head.text = full
		head.set_meta("full", full)
		sub.text = ""
		sub.visible = false
		if pc.has_meta("fit"):
			pc.remove_meta("fit")
		pc.set_meta("title_lbl", head)
	pc.set_meta("full", full)


func _update_line(it: Dictionary) -> void :
	var n: Control = it["node"]
	if n == null or not is_instance_valid(n) or not n.has_meta("head_lbl"):
		return
	var t: String = short_text(String(it["d"].get("title", "")))
	if String(n.get_meta("full", "")) != t:
		_set_line_text(n, t, line_split(t))




func _clip_lines() -> void :
	for it: Dictionary in _shown:
		var n: Control = it["node"]
		if n == null or not is_instance_valid(n):
			continue

		if n.has_meta("sub_lbl") and not n.has_meta("title_lbl"):
			var sl: Label = n.get_meta("sub_lbl")
			if sl.autowrap_mode != TextServer.AUTOWRAP_OFF and sl.size.x >= 8.0 and sl.visible:
				var sf: String = String(sl.get_meta("full", sl.text))
				var sk: String = "%s|%d" % [sf, int(sl.size.x)]
				if String(sl.get_meta("clipk", "")) != sk:
					sl.set_meta("clipk", sk)
					sl.set_meta("full", sf)
					sl.text = sf
					var sw: PackedStringArray = sf.split(" ")
					while sl.get_line_count() > 2 and sw.size() > 1:
						sw.remove_at(sw.size() - 1)
						sl.text = " ".join(sw).rstrip(",:;·—- ") + "…"
		if not n.has_meta("title_lbl"):
			continue
		var l: Label = n.get_meta("title_lbl")
		if l.size.x < 8.0:
			continue
		var full: String = String(l.get_meta("full", l.text))
		var key: String = "%s|%d" % [full, int(l.size.x)]
		if String(l.get_meta("clipk", "")) == key:
			continue
		l.set_meta("clipk", key)
		if l.text != full:
			l.text = full
		if l.get_line_count() <= 2:
			continue
		if String(it["kind"]) == "alert":

			var cut: int = -1
			for sep: String in [" — ", ": "]:
				var ci: int = full.find(sep)
				if ci > 8 and (cut < 0 or ci < cut):
					cut = ci
			if cut > 0:
				l.text = full.substr(0, cut)
				if l.get_line_count() <= 2:
					continue
				full = l.text
		var words: PackedStringArray = full.split(" ")
		while words.size() > 1:
			words.remove_at(words.size() - 1)
			l.text = " ".join(words).rstrip(",:;·—- ") + "…"
			if l.get_line_count() <= 2:
				break





static var _re_whose: RegEx = null





static func short_text(t: String) -> String:
	var ours: String = Loc.t("Наш удар")
	var whole: String = ""
	if not Loc.is_src():
		for h: String in Protect.LOC_OWN_HEAD:
			var th: String = Loc.t(h)
			if t.begins_with(th + ": "):
				ours = th
				whole = th
				break
	if not t.begins_with(ours):
		return t
	var c: int = t.find(": ")
	if c < 0:
		return t
	var head: String = whole if whole != "" else Loc.t("Удар") + t.substr(ours.length(), c - ours.length())
	var body: String = t.substr(c + 2).replace(Loc.t("попадание в поле, объектов нет"), Loc.t("мимо"))
	if _re_whose == null:
		_re_whose = RegEx.create_from_string("^(.+?) \\(([^()]+)\\)( ×\\d+)?$")
	var who: Dictionary = {}
	var out: PackedStringArray = PackedStringArray()
	for p: String in body.split(", "):
		var mt: RegExMatch = _re_whose.search(p)
		var s: String = p
		if mt != null:
			who[mt.get_string(2)] = true
		if s.length() > 1 and s.substr(1, 1) != s.substr(1, 1).to_upper():
			s = s.substr(0, 1).to_lower() + s.substr(1)
		out.append(s)
	if who.size() == 1:

		var cn: String = String(who.keys()[0])
		head += " · " + cn
		for i: int in out.size():
			out[i] = out[i].replace(" (%s)" % cn, "")
	return head + ": " + ", ".join(out)
