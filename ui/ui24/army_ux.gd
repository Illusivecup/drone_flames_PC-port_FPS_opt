extends Node













const AS = preload("res://ui/ui24/army_state.gd")
const AG = preload("res://game/army_groups.gd")
const FP = preload("res://game/front_plan.gd")
const U = preload("res://ui/ui24/arm_kit.gd")
const HT = preload("res://ui/ui24/hold_tip.gd")
const SheetScript = preload("res://ui/ui24/army_sheet.gd")

const STANCE_WORD: Array[String] = ["ЖДУТ", "ДЕРЖАТ", "НАСТУПАЮТ"]
const STANCE_LINE: Array[String] = ["стоят и ждут вашего приказа", "сами держат свой район", "сами идут на ближнего врага"]
const TOAST_S: float = 5.0
const CACHE_MS: int = 500
const REFRESH_S: float = 1.5

var hud: Node
var gw: GameWorld
var dock: Node
var sheet: PanelContainer = null
var view: String = ""
var cur_gid: int = -1
var cur_fid: int = -1
var place_kind: String = ""
var draw_on: bool = false
var draw_pts: PackedVector2Array = PackedVector2Array()
var draw_wps: PackedVector2Array = PackedVector2Array()
var place_sea: bool = false
var preview: Dictionary = {}
var picked: Dictionary = {}
var pick_into: int = -1
var chips_all: bool = false
var _pick_sx: int = 0
var toast_box: PanelContainer
var toast_l: Label
var toast_undo: Button
var toast_x: Button
var _want_cam: bool = false
var toast_bar: ColorRect
var _toast_t: float = 0.0
var toast_track: ColorRect
var _toast_len: float = 5.0
var _toast_in: float = 1.0
var _t_on_toast: bool = false
const TOAST_IN: float = 0.18
const TOAST_FADE: float = 0.4
var _undo_fids: PackedInt32Array = PackedInt32Array()
var _dock_flow: int = -1
var _cache: Dictionary = {}
var _rt: float = 0.0
var _hold_b: Button = null
var _hold_t: float = -1.0
var _hold_fill: ColorRect = null
var _pop: Control = null
var _player: Object = null



var _live: Array = []
var _struct: String = ""
var _dirty: bool = false
var _nav: Callable = Callable()
var _touch: int = 0
var stats: Dictionary = {"rebuild": 0, "deferred": 0, "under_finger": 0, "live": 0}
var trail: Array = []
var trail_on: bool = false


func mount(h: Node, d: Node) -> void :
	hud = h
	gw = h.gw
	dock = d
	name = "ArmyUX"
	h.root.add_child(self)
	toast_box = PanelContainer.new()

	var tsb: StyleBox = UiKit.sb("wb_card", 6, 0)
	tsb.content_margin_top = 0.0
	tsb.content_margin_bottom = 0.0
	_slim(tsb, 3.0, 0.0)
	toast_box.add_theme_stylebox_override("panel", tsb)
	toast_box.visible = false
	toast_box.mouse_filter = Control.MOUSE_FILTER_STOP
	h.root.add_child(toast_box)
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", -4)
	toast_box.add_child(tv)
	var th: = HBoxContainer.new()
	th.add_theme_constant_override("separation", 6)
	tv.add_child(th)
	toast_l = UiKit.lbl("", 10, UiKit.TEXT, 2, 3)
	toast_l.clip_text = true
	toast_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toast_l.custom_minimum_size = Vector2(120, 0)
	toast_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toast_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(toast_l)
	toast_undo = UiKit.big("ОТМЕНИТЬ", "stone", "", 44.0, 9)
	toast_undo.custom_minimum_size = Vector2(76, 44)
	_slim_btn(toast_undo)
	toast_undo.pressed.connect(_undo)
	HT.tip(toast_undo, "ОТМЕНИТЬ — армии прекратят этот приказ и остановятся")
	th.add_child(toast_undo)

	var tgap: = Control.new()
	tgap.custom_minimum_size = Vector2(0, 0)
	tgap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	th.add_child(tgap)
	toast_x = UiKit.close_btn(44.0)
	toast_x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slim_btn(toast_x)
	toast_x.pressed.connect( func() -> void :
		toast_box.visible = false
		_toast_t = 0.0
		_undo_fids = PackedInt32Array())
	HT.tip(toast_x, "✕ — закрыть подсказку; приказ остаётся в силе")
	th.add_child(toast_x)

	toast_track = ColorRect.new()
	toast_track.color = Color(0.0, 0.0, 0.0, 0.45)
	toast_track.custom_minimum_size = Vector2(0, 4)
	toast_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(toast_track)
	toast_bar = ColorRect.new()
	toast_bar.color = UiKit.GOLD
	toast_bar.size = Vector2(0, 4)
	toast_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_track.add_child(toast_bar)



static func _slim(sb0: StyleBox, t: float, b: float) -> void :
	if "expand_margin_top" in sb0:
		sb0.set("expand_margin_top", - t)
		sb0.set("expand_margin_bottom", - b)


static func _slim_btn(b: Button) -> void :
	for st: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		if b.has_theme_stylebox(st):
			var d: StyleBox = b.get_theme_stylebox(st).duplicate()
			_slim(d, 4.0, 4.0)
			b.add_theme_stylebox_override(st, d)


func _input(ev: InputEvent) -> void :
	if ev is InputEventScreenTouch and (ev as InputEventScreenTouch).index == 0:
		_touch = 1 if (ev as InputEventScreenTouch).pressed else 0
		if (ev as InputEventScreenTouch).pressed:
			_t_on_toast = toast_box.visible and toast_box.get_global_rect().grow(6.0).has_point((ev as InputEventScreenTouch).position)
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_touch = 1 if (ev as InputEventMouseButton).pressed else 0
		if (ev as InputEventMouseButton).pressed:
			_t_on_toast = _t_on_toast or (toast_box.visible and toast_box.get_global_rect().grow(6.0).has_point((ev as InputEventMouseButton).position))



func finger() -> bool:
	return _touch > 0 or bool(hud.call("_finger_down"))



func _later(c: Callable) -> void :
	if finger() and sheet != null and is_instance_valid(sheet):
		_nav = c
		stats["deferred"] = int(stats["deferred"]) + 1
	else:
		c.call()


func _tr(what: String) -> void :
	if trail_on:
		var st: Array = get_stack()
		trail.append([Engine.get_process_frames(), "%s finger=%s touch=%d by %s" % [what, finger(), _touch, String(st[2]["function"]) + ">" + String(st[1]["function"]) if st.size() > 2 else "?"]])


func _dyn(l: Label, fn: Callable) -> void :
	_live.append([l, fn])


func _update_live() -> void :
	for e: Array in _live:
		if not is_instance_valid(e[0]):
			continue
		var l: Label = e[0]
		var r: Array = (e[1] as Callable).call()
		if l.text != String(r[0]):
			l.text = String(r[0])
			stats["live"] = int(stats["live"]) + 1
		if r.size() > 1 and r[1] is Color:
			l.add_theme_color_override("font_color", r[1])




func _snap() -> Dictionary:
	var now: int = Time.get_ticks_msec()
	var e: Array = _cache.get("snap", [])
	if not e.is_empty() and now - int(e[0]) < CACHE_MS:
		return e[1]
	var s: Dictionary = AS.snapshot(gw, gw.player.id) if gw.player != null else {}
	_cache["snap"] = [now, s]
	return s


func gst(gid: int) -> Dictionary:
	var g: Dictionary = _group(gid)
	return AS.group(_snap(), g) if not g.is_empty() else {}


func ast(fid: int) -> Dictionary:
	var s: Dictionary = _snap()
	if s.has(fid):
		return s[fid]
	var f: Facility = AG.fac(gw, fid)
	return {"key": "form", "n": 0, "cap": 12, "hp": 0.0, "inn": 0, "foot": 0, "dug": false, "no": f.army_no if f != null else 0, "build_name": "", "build_icon": "icon_infantry", "gid": -1, "gname": ""}


func _drop_cache() -> void :
	_cache.clear()


func _group(gid: int) -> Dictionary:
	return AG.by_id(gw, gw.player.id, gid) if gw.player != null else {}


func _armies() -> Array:
	var out: Array = []
	if gw.player == null:
		return out
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.BARRACKS and f.country_id == gw.player.id and AG.army_alive(gw, f):
			out.append(f)
	return out


func _ok() -> bool:
	return gw != null and gw.player != null and not gw.player.eliminated




func _cmd(mod: String, fn: String, args: Array, done: Callable = Callable()) -> void :
	NetSession.sim("", "cmd_static", [gw.player, mod, fn, args], func(r: Variant) -> void :
		_drop_cache()
		if is_instance_valid(self) and done.is_valid():
			done.call(r))


func _sim(path: String, fn: String, args: Array, done: Callable = Callable()) -> void :
	NetSession.sim(path, fn, args, func(r: Variant) -> void :
		_drop_cache()
		if is_instance_valid(self) and done.is_valid():
			done.call(r))




func toast(t: String, undo_fids: PackedInt32Array = PackedInt32Array()) -> void :
	toast_l.text = t
	_undo_fids = undo_fids
	toast_undo.visible = not undo_fids.is_empty()
	var shown: bool = toast_box.visible and toast_box.modulate.a > 0.5
	toast_box.visible = true
	toast_box.reset_size()
	_toast_t = TOAST_S if not undo_fids.is_empty() else 3.0
	_toast_len = _toast_t
	if not shown:
		_toast_in = 0.0
		toast_box.modulate.a = 0.0


func _undo() -> void :
	for fid: int in _undo_fids:
		var f: Facility = AG.fac(gw, fid)
		if f != null:
			_sim("ops", "cancel", [f])
	_undo_fids = PackedInt32Array()
	preview = {}
	toast("Приказ отменён: армии остановились")
	_reopen()




func _process(delta: float) -> void :
	if gw == null:
		return
	if gw.player != _player:
		_player = gw.player
		close_view()
		mock_reset()
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if toast_box.visible:
		var bot: float = hud.holder.get_global_rect().position.y if hud.holder != null else vs.y
		toast_box.size.x = minf(vs.x - 16.0, 344.0)


		_toast_in = minf(1.0, _toast_in + delta / TOAST_IN)
		var ein: float = 1.0 - pow(1.0 - _toast_in, 3.0)
		_toast_t -= minf(delta, 0.1)
		if _touch > 0 and _t_on_toast:
			_toast_t = maxf(_toast_t, TOAST_FADE)
		var fo: float = clampf(_toast_t / TOAST_FADE, 0.0, 1.0)
		toast_box.modulate.a = ein * fo
		toast_box.position = Vector2(roundf((vs.x - toast_box.size.x) * 0.5), roundf(bot - toast_box.size.y - 8.0 + (1.0 - ein) * 10.0 + (1.0 - fo) * 6.0))
		var frac: float = clampf(_toast_t / maxf(0.1, _toast_len), 0.0, 1.0)
		toast_bar.size = Vector2(roundf(maxf(toast_track.size.x, toast_box.size.x - 12.0) * frac), toast_track.size.y)
		toast_bar.color = UiKit.GOLD.lerp(Color("ff6a4d"), clampf(1.0 - _toast_t / 1.5, 0.0, 1.0)) if not _undo_fids.is_empty() else UiKit.GOLD
		if _touch == 0:
			_t_on_toast = false
		if _toast_t <= 0.0 and not (finger() and _t_on_toast):
			toast_box.visible = false
			_undo_fids = PackedInt32Array()
	_hold_tick(delta)
	if _dock_flow >= 0:
		_dock_tick()
		return
	if view == "":
		return
	if sheet == null or not is_instance_valid(sheet) or not _ok():
		view = ""
		sheet = null
		return

	if hud.ops_panel != null and hud.ops_panel.visible or (hud.panel != null and is_instance_valid(hud.panel)):
		if view != "bar":
			close_view()
			return
	if not finger():
		if _nav.is_valid():
			var nv: Callable = _nav
			_nav = Callable()
			nv.call()
			return
		if _dirty:
			_dirty = false
			_rebuild_now()
			return
	_rt -= delta

	if _rt <= 0.0 and view in ["group", "army", "bar", "list"] and _pop == null and not finger():
		_rt = REFRESH_S
		_drop_cache()
		if _struct_sig() != _struct:
			_reopen()
		else:
			_update_live()



func _struct_sig() -> String:
	match view:
		"group":
			var g: Dictionary = _group(cur_gid)
			if g.is_empty():
				return "gone"
			var gs: Dictionary = gst(cur_gid)
			var pl: Dictionary = FP.plan_of(g)
			return "%d|%s|%d|%s|%s|%s|%s|%s|%d|%s|%s|%s" % [cur_gid, g["name"], int(g["color"]), g["emblem"], FP.front_of(g).is_empty(), pl.is_empty(), FP.running(g), 
				( not pl.is_empty()) and gw.player.at_war.has(int(pl["foe"])), _stance_of(g), "-", int(gs.get("armies", 0)) > 0, str(_chip_set(g["fids"])) + str(chips_all)]
		"army":
			var f: Facility = AG.fac(gw, cur_fid)
			if f == null or not AG.army_alive(gw, f):
				return "gone"
			var a: Dictionary = ast(cur_fid)
			var ab: Dictionary = gw.army.army_brief(f)
			var comp: String = ""
			for e: Dictionary in ab.get("comp", []):
				comp += "%s," % e["icon"]
			var g2: Dictionary = AG.group_of(gw, gw.player.id, cur_fid)
			return "%d|%s|%s|%s|%d|%d|%s|%s|%s" % [cur_fid, "-", gw.ops.of(f).is_empty(), (ab.get("landing", {}) as Dictionary).get("pos") is Vector2, f.stance, f.group_id, 
				FP.front_of(g2).is_empty() if not g2.is_empty() else true, int(a["n"]) > 0, comp]
		"bar":
			var f2: Facility = AG.fac(gw, cur_fid)
			if f2 == null:
				return "gone"
			return "%d|%s|%s|%s" % [cur_fid, f2.auto_refill, gw.mil.demolish_why(gw.player, f2) == "" if gw.mil.has_method("demolish_why") else false, f2.prod_type == 3]
		"list":
			var s3: String = ""
			for g3: Dictionary in gw.player.army_groups:
				s3 += "%d%s%d%s%s;" % [int(g3["id"]), g3["name"], int(g3["color"]), g3["emblem"], gst(int(g3["id"])).get("key", "")]
			for f3: Facility in _armies():
				if f3.group_id < 0:
					s3 += "f%d" % f3.id
			return s3
	return ""


func _reopen() -> void :
	_drop_cache()
	if view in ["group", "army", "bar", "list"] and sheet != null and is_instance_valid(sheet) and _struct_sig() == _struct:
		if not finger():
			_update_live()
		return
	if finger():
		_dirty = true
		stats["deferred"] = int(stats["deferred"]) + 1
		return
	_rebuild_now()


func _rebuild_now() -> void :
	match view:
		"group":
			open_group(cur_gid)
		"army":
			open_army(cur_fid)
		"bar":
			open_bar(cur_fid)
		"list":
			open_list()




func _dock_tick() -> void :
	var busy: bool = bool(dock.is_open) and (String(dock.placing) != "" or (dock.confirm != null and is_instance_valid(dock.confirm) and dock.confirm.visible) or (dock.sheet != null and is_instance_valid(dock.sheet) and dock.sheet.visible))
	if busy or finger():
		return
	var gid: int = _dock_flow
	_dock_flow = -1
	if bool(dock.is_open):
		dock.close()
	if not _group(gid).is_empty():
		open_group(gid)


func mock_reset() -> void :
	picked.clear()
	preview = {}
	_undo_fids = PackedInt32Array()
	_dock_flow = -1
	_drop_cache()




func toggle_list() -> void :
	if view == "list" and sheet != null and is_instance_valid(sheet):
		close_view()
		UiKit.snd("ui_close")
	else:
		open_list()



func open_from_dock(gid: int) -> void :
	if gid >= 0 and not _group(gid).is_empty():
		open_group(gid)
	else:
		open_list()



func map_tap(pos: Vector2, wp: Vector2) -> bool:
	if not _ok():
		return false
	if view == "place" and draw_on:
		draw_pts = PackedVector2Array([wp])
		_draw_done()
		return true
	if view == "place":
		place_tap(wp)
		return true
	if view == "pick":
		var best: Unit = null
		var bd: float = 22.0
		var cam: MapCamera = hud.main_node.cam
		for u: Unit in gw.army.units:
			if u.country_id != gw.player.id or not u.alive() or u.home == null or u.type == Unit.Type.FPV:
				continue
			var d: float = cam.world_to_screen(u.pos).distance_to(pos)
			if d < bd:
				bd = d
				best = u
		if best != null and AG.army_alive(gw, best.home):
			_pick(best.home.id)
			return true
		var ap: Variant = hud.get("army_pennants")
		if ap != null and ap.has_method("hit_at"):
			var hit: Array = ap.hit_at(pos)
			if not hit.is_empty() and String(hit[0]) == "g":
				for fid: int in _group(int(hit[1])).get("fids", []):
					picked[fid] = true
				open_pick(pick_into)
				return true
			if not hit.is_empty() and String(hit[0]) == "a":
				_pick(int(hit[1]))
				return true
		return true
	return false


func busy() -> bool:
	return view in ["place", "pick"] or _dock_flow >= 0




func close_view() -> void :
	_tr("close " + view)
	_close_pop()
	if sheet != null and is_instance_valid(sheet):
		hud.ui24_closed(sheet)
		sheet.queue_free()
	sheet = null
	if view in ["place", "pick"]:
		preview = {} if Time.get_ticks_msec() > int(preview.get("until", 0)) else preview
	view = ""
	hud.set_key_pressed("armies", false)



func _sheet(v: String) -> VBoxContainer:
	_close_pop()
	_live.clear()
	_dirty = false
	stats["rebuild"] = int(stats["rebuild"]) + 1
	_tr("build %s->%s" % [view, v])
	if finger() and sheet != null and is_instance_valid(sheet):
		stats["under_finger"] = int(stats["under_finger"]) + 1
		if OS.is_debug_build():
			print("[ux] REBUILD UNDER FINGER view=%s -> %s\n%s" % [view, v, str(get_stack())])
	var old: PanelContainer = sheet
	sheet = SheetScript.new()
	sheet.ux = self
	var psb: StyleBox = UiKit.sb("wb_panel", 8, 6)
	psb.content_margin_bottom = 8.0 + float(hud.call("_safe_margins").y)
	sheet.add_theme_stylebox_override("panel", psb)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.holder.add_child(sheet)
	hud.holder.move_child(sheet, hud.tab_row.get_index() + 1)
	if old != null and is_instance_valid(old):
		hud.ui24_closed(old)
		old.queue_free()
	if bool(dock.is_open) and _dock_flow < 0:
		dock.close()
	view = v
	hud.ui24_open(sheet)
	if hud.bottom_panel != null:
		hud.bottom_panel.visible = false
	hud.set_key_pressed("armies", true)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	sheet.add_child(vb)
	if old == null or not is_instance_valid(old):
		sheet.modulate.a = 0.0
		sheet.create_tween().tween_property(sheet, "modulate:a", 1.0, 0.15)
	_rt = REFRESH_S
	return vb



func _head(vb: VBoxContainer, icon: Control, title: String, state: String, col: Color, more: Callable = Callable(), live: Callable = Callable(), one_line: bool = false) -> void :
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	vb.add_child(hb)
	if icon != null:
		hb.add_child(icon)
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 1)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(tv)
	var tl: Label = UiKit.lbl(title, 14, UiKit.TITLE, 3, 3)
	tl.clip_text = true
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not Loc.is_src():
		UiKit.fit_lbl(tl, [14, 13, 12], false)
	tv.add_child(tl)
	if state != "":
		var sl: Label = UiKit.lbl(state, 10, col, 2, 5)
		if one_line:
			sl.clip_text = true
			sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		else:
			sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(sl)
		if live.is_valid():
			_dyn(sl, live)
	if more.is_valid():
		var mb: Button = UiKit.slot("icon_menu", false, 44.0)
		mb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mb.pressed.connect( func() -> void : more.call(mb))
		HT.tip(mb, "ЕЩЁ — редкие действия группы")
		hb.add_child(mb)
	var cb: Button = UiKit.close_btn(44.0)
	cb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cb.pressed.connect( func() -> void :
		UiKit.snd("ui_close")
		close_view())
	hb.add_child(cb)


func _icon_box(icon: String, px: float = 24.0) -> Control:
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_slot", 3))
	p.custom_minimum_size = Vector2(px + 8, px + 8)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var cc: = CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(cc)
	cc.add_child(UiKit.icon_rect(icon if UiKit.has(icon) else "icon_infantry", px))
	return p



func _verb(parent: Control, icon: String, text: String, cb: Callable, flip: bool = false, tip: String = "", on: bool = true) -> Button:
	var b: Button = UiKit.big("", "stone", "", 44.0, 10)
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	b.disabled = not on
	var vb: = HBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 2
	vb.offset_right = -2
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 3)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)
	var ic: TextureRect = U.icon(icon, 20)
	ic.flip_v = flip
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb.add_child(ic)
	var l: Label = UiKit.lbl(text, 10, UiKit.TEXT if on else UiKit.DIM, 2, 3)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb.add_child(l)

	b.resized.connect( func() -> void :
		var lw: float = l.get_minimum_size().x
		b.set_meta("need", lw + 27.0)
		var fits: bool = true
		for sib: Node in b.get_parent().get_children():
			if sib is Button and (sib as Control).visible and (sib as Control).size.x < float(sib.get_meta("need", 0.0)):
				fits = false
		for sib2: Node in b.get_parent().get_children():
			for ic2: Node in sib2.find_children("*", "TextureRect", true, false):
				if sib2.has_meta("need"):
					(ic2 as TextureRect).visible = fits
		if b.size.x < lw + 6.0 and l.get_theme_font_size("font_size") > 9:
			l.add_theme_font_size_override("font_size", 9))
	if cb.is_valid():
		b.pressed.connect(cb)
	if tip != "":
		HT.tip(b, tip)
	parent.add_child(b)
	return b




func _trench_verb(parent: Control, is_out: Callable, act: Callable, has: bool) -> Button:
	var b: Button = _verb(parent, "icon_occupy", "", Callable(), false, "", true)
	var lab: Label = b.find_children("*", "Label", true, false)[0]
	var ic: TextureRect = b.find_children("*", "TextureRect", true, false)[0]
	var upd: = func() -> Array:
		var o: bool = bool(is_out.call())
		b.set_meta("out", o)
		ic.flip_v = o
		b.disabled = not (o or has)
		HT.tip(b, Loc.t("ИЗ ОКОПОВ — выйдут и вернутся к приказу") if o else Loc.t("В ОКОПЫ — пехота займёт ближайшие свои окопы и блиндажи"))
		return [Loc.t("ИЗ ОКОПОВ") if o else Loc.t("В ОКОПЫ"), UiKit.TEXT if not b.disabled else UiKit.DIM]
	var t0: Array = upd.call()
	lab.text = String(t0[0])
	lab.add_theme_color_override("font_color", t0[1])
	_dyn(lab, upd)
	b.pressed.connect( func() -> void : act.call( not bool(b.get_meta("out", false))))
	return b






static var _rail_hint_seen: bool = false


func _rail_verb(parent: Control, fids_of: Callable) -> Button:
	var b: Button = UiKit.slot("r332_rail_on", false, 44.0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic: TextureRect = UiKit.slot_icon(b)
	var cap: Label = UiKit.lbl("ЖД", 9, UiKit.TEXT, 2, 2)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_top = -15.0
	cap.offset_bottom = -2.0
	b.add_child(cap)
	var place: = func() -> void :
		if ic != null:
			ic.position = Vector2(roundf((b.size.x - ic.size.x) * 0.5), 3.0)
	b.resized.connect(place)
	var state: = func() -> int:
		var n: int = 0
		var on: int = 0
		for fid: int in fids_of.call():
			n += 1
			if gw.rail == null or gw.rail.rail_ok(fid):
				on += 1
		return 2 if on == n else (0 if on == 0 else 1)
	var paint: = func() -> void :
		var st: int = state.call()
		if ic != null:
			UiKit.set_icon(ic, "r332_rail_off" if st == 0 else "r332_rail_on", 24.0)
			place.call()
		cap.text = ["ЖД ✕", "ЖД ½", "ЖД"][st]
		cap.add_theme_color_override("font_color", [UiKit.RED, UiKit.GOLD, UiKit.TEXT][st])
		HT.tip(b, ["ЖД: ЗАПРЕЩЕНО — быстрый марш только пешком. Нажмите: разрешить поезд", 
			"ЖД: РАЗРЕШЕНО не всем армиям группы. Нажмите: разрешить всем", 
			"ЖД: РАЗРЕШЕНО — быстрый марш едет поездом от своего вокзала, если так быстрее. Нажмите: запретить"][st])
	paint.call()
	b.pressed.connect( func() -> void :
		var want: bool = int(state.call()) != 2
		var fids: = PackedInt32Array(fids_of.call())
		if fids.is_empty() or gw.player == null:
			return
		_sim("rail", "set_rail_ok", [gw.player, fids, want], func(r: Variant) -> void :
			if r is String and String(r) != "":
				toast(String(r))
				UiKit.snd("ui_error")
			elif not _rail_hint_seen:
				_rail_hint_seen = true
				toast("Поезд для быстрого марша: %s" % ("разрешён" if want else "запрещён"))
			else:
				toast("ЖД: %s" % ("РАЗРЕШЕНО" if want else "ЗАПРЕЩЕНО"))
			if is_instance_valid(b):
				paint.call()
			_reopen()))
	parent.add_child(b)
	return b



func _rail_what(f: Facility) -> String:
	var inf: Dictionary = gw.rail.troops.info(f)

	var walk: bool = int(inf.get("stage", -1)) == 0
	var to: String = String(inf.get("from" if walk else "to", ""))
	if to.length() > 9:
		to = to.left(8) + "…"
	if walk:
		return Loc.t("НА ВОКЗАЛ → %s") % to
	var eta: int = maxi(1, int(inf.get("eta_s", 0)))
	return Loc.t("ПОЕЗД→%s · %s") % [to, (Loc.t("%d с") % eta) if eta < 90 else (Loc.t("%d мин") % roundi(eta / 60.0))]




func _rail_word() -> String:
	var nr: int = 0
	var nd: int = 0
	for e: Array in preview.get("ok", []):
		if e.size() > 3 and not (e[3] as Dictionary).is_empty():
			nr += 1
		elif e.size() > 4 and bool(e[4]):
			nd += 1
	if nr > 0:
		return Loc.t("поездом") if nr == 1 else Loc.t("%d поездом") % nr
	return Loc.t("пешком") if nd > 0 else ""



func _primary(b: Button) -> void :
	if b == null or b.disabled:
		return
	for st: Array in [["normal", "wb_btn_green", -1], ["hover", "wb_btn_green", -1], ["pressed", "wb_btn_green_p", 1], ["hover_pressed", "wb_btn_green_p", 1]]:
		b.add_theme_stylebox_override(String(st[0]), UiKit.sb(String(st[1]), 12, 4, int(st[2])))



func _verbs_last(vb: VBoxContainer, r1: Control) -> void :
	if r1 != null and is_instance_valid(r1) and r1.get_parent() == vb:
		vb.move_child(r1, vb.get_child_count() - 1)



static func _pl(n: int, one: String, few: String, many: String) -> String:
	var m10: int = n % 10
	var m100: int = n % 100
	var w: String = many
	if m10 == 1 and m100 != 11:
		w = one
	elif m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		w = few
	return "%d %s" % [n, w]


func _row(vb: Control, sep: int = 4) -> HBoxContainer:
	var r: = HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	vb.add_child(r)
	return r


func _line(vb: Control, text: String, col: Color = UiKit.TEXT, size: int = 10) -> Label:
	var l: Label = UiKit.lbl(text, size, col, 2, 2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(l)
	return l



func _stance(vb: VBoxContainer, cur: int, cb: Callable) -> void :
	var r: HBoxContainer = _row(vb, 3)
	var l: Label = UiKit.lbl("РЕЖИМ:", 10, UiKit.TEXT, 2, 2)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.custom_minimum_size = Vector2(50, 0)
	r.add_child(l)
	for s in 3:
		var sv: int = s
		var b: Button = UiKit.big(STANCE_WORD[s], "gold" if s == cur else "stone", "", 44.0, 10)
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect( func() -> void : cb.call(sv))
		HT.tip(b, "%s — %s" % [STANCE_WORD[s], STANCE_LINE[s]])
		r.add_child(b)


func _strength(vb: Control, fid: int) -> void :
	var br: = HBoxContainer.new()
	br.add_theme_constant_override("separation", 6)
	vb.add_child(br)
	var txt: = func() -> Array:
		var a: Dictionary = ast(fid)
		var rt: String = AS.reinf_txt(int(a.get("gath", 0)), int(a.get("walk", 0)))
		return [Loc.t("СИЛА %d%% · %d/%d%s") % [roundi(float(a["hp"]) * 100.0), int(a["n"]), int(a["cap"]), (" · " + rt) if rt != "" else ""], AS.hp_col(float(a["hp"]))]
	var t0: Array = txt.call()
	var sl: Label = UiKit.lbl(String(t0[0]), 10, t0[1], 2, 2)
	br.add_child(sl)
	var bar: = Control.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect( func() -> void :
		var hp: float = float(ast(fid)["hp"])
		var r: = Rect2(Vector2.ZERO, bar.size)
		bar.draw_rect(r.grow(1.0), UiKit.OUTLINE)
		bar.draw_rect(r, Color("2a2b22"))
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(roundf(r.size.x * clampf(hp, 0.0, 1.0)), r.size.y)), AS.hp_col(hp)))
	br.add_child(bar)
	_dyn(sl, func() -> Array:
		bar.queue_redraw()
		return txt.call())



func _army_chip(parent: Control, fid: int) -> Button:
	var s: Dictionary = ast(fid)
	var b: Button = UiKit.big("", "gold" if picked.has(fid) and view == "pick" else "stone", "", 44.0, 10)
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	var hb: = HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 5
	hb.offset_right = -4
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	var bic: String = String(s["build_icon"])
	hb.add_child(U.icon(bic if U.native(bic) else "icon_infantry", 18))
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tv)
	var l1: Label = UiKit.lbl("%s %s" % [Loc.no(int(s["no"])), Loc.t(String(s["build_name"])).to_upper()], 10, UiKit.TEXT, 2, 2)
	l1.clip_text = true
	l1.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(l1)
	var cl: Array = AS.chip_line(s)
	var l2: Label = UiKit.lbl(String(cl[0]), 9, cl[1], 2, 3)
	l2.clip_text = true
	l2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(l2)
	_dyn(l2, func() -> Array: return AS.chip_line(ast(fid)))
	b.pressed.connect( func() -> void :
		if view == "pick":
			_pick(fid)
		else:
			_want_cam = view == "list" or view == "group"
			open_army(fid)
			_want_cam = false)
	HT.tip(b, Loc.t("АРМИЯ №%d — тап: её карточка") % int(s["no"]))
	parent.add_child(b)
	return b


func _dug_toggle(gs: Dictionary) -> bool:
	return int(gs.get("dug_armies", 0)) > 0 and int(gs.get("dug_armies", 0)) * 2 >= int(gs.get("armies", 0))





func _chip_set(fids: PackedInt32Array) -> Array:
	var out: Array = []
	for fid: int in fids:
		if AG.valid_member(gw, gw.player.id, AG.fac(gw, fid)):
			out.append(fid)
	out.sort()
	return out


func _chip_order(fids: PackedInt32Array) -> Array:
	var order: Array = []
	for fid: int in fids:
		if AG.valid_member(gw, gw.player.id, AG.fac(gw, fid)):
			order.append(fid)
	order.sort_custom( func(a: int, b: int) -> bool:
		var fa: bool = String(ast(a)["key"]) == "fight"
		var fb: bool = String(ast(b)["key"]) == "fight"
		if fa != fb:
			return fa
		return AG.fac(gw, a).army_no < AG.fac(gw, b).army_no)
	return order



func _chips(vb: VBoxContainer, fids: PackedInt32Array) -> void :
	var order: Array = _chip_order(fids)
	var grid: = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(grid)
	var rows: int = 1
	var cap: int = 999 if chips_all else rows * 2
	var shown: int = 0
	for fid2: int in order:
		if shown >= cap - (1 if order.size() > cap else 0):
			break
		_army_chip(grid, fid2)
		shown += 1
	if order.size() > shown:
		var more: Button = UiKit.big(Loc.t("ЕЩЁ %d") % (order.size() - shown), "stone", "", 44.0, 10)
		more.custom_minimum_size = Vector2(0, 44)
		more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		more.pressed.connect( func() -> void :
			chips_all = true
			open_group(cur_gid))
		grid.add_child(more)


func _focus(d: Dictionary) -> void :
	if not _want_cam:
		return
	_want_cam = false
	var mn: Node = hud.main_node
	if mn != null and mn.get("_focus") != null:
		d["n"] = 3
		mn.set("_focus", d)





func open_list() -> void :
	if not _ok():
		return
	var vb: VBoxContainer = _sheet("list")
	var groups: Array = gw.player.army_groups
	_head(vb, _icon_box("icon_barracks"), "АРМИИ", "%s · %s" % [(Loc.n(groups.size(), "%d группа", "%d группы", "%d групп") % (groups.size())), (Loc.n(_armies().size(), "%d армия", "%d армии", "%d армий") % (_armies().size()))], UiKit.TEXT)
	var sc: = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var free: Array = []
	for f: Facility in _armies():
		if f.group_id < 0:
			free.append(f)
	var rows_h: float = float(mini(4, groups.size())) * 52.0 + (0.0 if free.is_empty() else 70.0)
	sc.custom_minimum_size = Vector2(0, minf(rows_h, get_viewport().get_visible_rect().size.y * 0.32))
	vb.add_child(sc)
	var lv: = VBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lv)
	for g: Dictionary in groups:
		var gid: int = int(g["id"])
		var gs: Dictionary = gst(gid)
		var b: Button = UiKit.big("", "stone", "", 48.0, 10)
		b.custom_minimum_size = Vector2(0, 48)
		var hb: = HBoxContainer.new()
		hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = 8
		hb.offset_right = -8
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		hb.add_child(U.emblem_rect(String(g["emblem"]), U.color(int(g["color"])), 28, true))
		var tv: = VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", 0)
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tv)
		tv.add_child(UiKit.lbl(AS.gname(g), 12, UiKit.TEXT, 2, 3))
		var rs: Label = UiKit.lbl(Loc.t("%s · %d бойцов · сила %d%%") % [(Loc.n(int(gs.get("armies", 0)), "%d армия", "%d армии", "%d армий") % (int(gs.get("armies", 0)))), int(gs.get("n", 0)), roundi(float(gs.get("hp", 0.0)) * 100.0)], 9, UiKit.MUTED, 1)
		tv.add_child(rs)
		_dyn(rs, func() -> Array:
			var g9: Dictionary = gst(gid)
			return [Loc.t("%s · %d бойцов · сила %d%%") % [(Loc.n(int(g9.get("armies", 0)), "%d армия", "%d армии", "%d армий") % (int(g9.get("armies", 0)))), int(g9.get("n", 0)), roundi(float(g9.get("hp", 0.0)) * 100.0)]])
		var sx: Array = AS.ST[gs.get("key", "idle")]
		var sw: = HBoxContainer.new()
		sw.add_theme_constant_override("separation", 3)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.add_child(U.icon(String(sx[3]), 14))
		var swl: Label = UiKit.lbl(Loc.t(String(sx[1])), 10, sx[2], 2, 3)
		swl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dyn(swl, func() -> Array:
			var x9: Array = AS.ST[gst(gid).get("key", "idle")]
			return [Loc.t(String(x9[1])), x9[2]])
		sw.add_child(swl)
		hb.add_child(sw)
		b.pressed.connect( func() -> void :
			_want_cam = true
			open_group(gid)
			_want_cam = false)
		lv.add_child(b)
	if not free.is_empty():
		lv.add_child(UiKit.lbl("БЕЗ ГРУППЫ:", 10, UiKit.TEXT, 2, 2))
		var grid: = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		lv.add_child(grid)
		for f2: Facility in free:
			_army_chip(grid, f2.id)
	if groups.is_empty() and free.is_empty():
		_line(vb, "Армий пока нет: постройте КАЗАРМЫ во вкладке АРМИЯ — армия наберётся сама.", UiKit.MUTED)
	var nb: Button = UiKit.big("+ НОВАЯ ГРУППА", "stone", "", 44.0, 11)
	nb.custom_minimum_size = Vector2(0, 44)
	nb.disabled = _armies().is_empty() or groups.size() >= AG.MAX_GROUPS
	nb.pressed.connect( func() -> void :
		picked.clear()
		open_pick(-1))
	HT.tip(nb, "НОВАЯ ГРУППА — коснитесь армий на карте или фишек, затем ГОТОВО")
	vb.add_child(nb)
	_struct = _struct_sig()


func _stance_of(g: Dictionary) -> int:
	for fid: int in g.get("fids", []):
		var f: Facility = AG.fac(gw, fid)
		if f != null:
			return clampi(f.stance, 0, 2)
	return 0



func open_group(gid: int) -> void :
	if not _ok():
		return
	var g: Dictionary = _group(gid)
	if g.is_empty():
		open_list()
		return
	if view != "group" or cur_gid != gid:
		chips_all = false
		_focus({"gid": gid})
	cur_gid = gid
	var gs: Dictionary = gst(gid)
	var fr: Dictionary = FP.front_of(g)
	var pl: Dictionary = FP.plan_of(g)
	var wh: Array = _group_what(gid)
	var vb: VBoxContainer = _sheet("group")
	_head(vb, U.emblem_rect(String(g["emblem"]), U.color(int(g["color"])), 36, true), AS.gname(g), String(wh[0]), wh[1], func(a: Control) -> void : _more(a, gid), func() -> Array: return _group_what(gid), true)
	var stl: Label = _line(vb, _group_stats(gid))
	_dyn(stl, func() -> Array: return [_group_stats(gid)])
	var has: bool = int(gs["armies"]) > 0
	var rm: HBoxContainer = _row(vb)
	_primary(_verb(rm, "icon_move", "БЫСТРЫЙ\nМАРШ", func() -> void : start_place("move"), false, "БЫСТРЫЙ МАРШ — коснитесь цели: сразу видно, кто и как пойдёт; своя земля — оборона, чужая — наступление", has))
	_verb(rm, "icon_route" if UiKit.has("icon_route") else "icon_move", "ИДТИ", func() -> void : start_draw("move"), false, "ИДТИ — проведите путь пальцем: армии пойдут по линии; два пальца — двигать карту", has)
	_verb(rm, "icon_ship" if UiKit.has("icon_ship") else "icon_port", "БЫСТРЫЙ\nДЕСАНТ", func() -> void : start_place("move", true), false, "БЫСТРЫЙ ДЕСАНТ — коснитесь цели за морем: посадка на своей морской базе, высадка у цели", has)
	_verb(rm, "icon_ship" if UiKit.has("icon_ship") else "icon_port", "ДЕСАНТ", func() -> void : start_draw("move", true), false, "ДЕСАНТ — проведите линию за море: конец линии — точка высадки", has)
	var r1: HBoxContainer = _row(vb)
	_verb(r1, "icon_op_defend", "НА ФРОНТ", func() -> void : _front_flow(gid, "front"), false, "НА ФРОНТ — коснитесь границы или проведите линию фронта пальцем", has)
	_trench_verb(r1, func() -> bool: return _dug_toggle(gst(gid)), func(into: bool) -> void : _trench_group(gid, into), has)
	_verb(r1, "icon_op_retreat", "ОТХОД", func() -> void : _retreat_group(gid), false, "ОТХОД — к своим казармам, пополниться", has)
	_rail_verb(r1, func() -> Array: return Array(_group(gid).get("fids", PackedInt32Array())))
	if not fr.is_empty():
		var fl: HBoxContainer = _row(vb, 6)
		var run: bool = FP.running(g)
		var ll: Label = UiKit.lbl(Loc.t("ИДЁТ АТАКА ПО ПЛАНУ") if run else (Loc.t("ФРОНТ: план готов") if not pl.is_empty() else Loc.t("ФРОНТ: держат линию")), 10, UiKit.TEXT, 2, 2)
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fl.add_child(ll)
		if not pl.is_empty() and not run and gw.player.at_war.has(int(pl["foe"])):
			var ab: Button = UiKit.big("В АТАКУ", "stone", "icon_op_attack", 44.0, 10)
			ab.custom_minimum_size = Vector2(118, 44)
			ab.pressed.connect( func() -> void :
				_cmd("front", "attack_now", [gid], func(r: Variant) -> void :
					if r is String and String(r) != "":
						toast(String(r))
						UiKit.snd("ui_error")
					_reopen()))
			HT.tip(ab, "В АТАКУ — наступать по плану сейчас")
			fl.add_child(ab)
		else:
			var pb: Button = UiKit.big("ПЛАН АТАКИ", "stone", "icon_op_attack", 44.0, 10)
			pb.custom_minimum_size = Vector2(140, 44)
			pb.pressed.connect( func() -> void : _front_flow(gid, "plan"))
			HT.tip(pb, "ПЛАН АТАКИ — стрелка от фронта вглубь врага")
			fl.add_child(pb)
	else:
		_stance(vb, _stance_of(g), func(s: int) -> void :
			_cmd("groups", "group_set_stance", [gid, s], func(r: Variant) -> void :
				if r is String and String(r) != "":
					toast(String(r))
				_reopen()))
	_chips(vb, g["fids"])
	vb.move_child(vb.get_child(vb.get_child_count() - 1), 2)
	_verbs_last(vb, r1)
	_verbs_last(vb, rm)
	_struct = _struct_sig()


func _group_what(gid: int) -> Array:
	var g: Dictionary = _group(gid)
	var gs: Dictionary = gst(gid)
	var key: String = String(gs.get("key", "idle"))
	var fr: Dictionary = FP.front_of(g)
	var what: String = Loc.t(String(AS.ST[key][0]))
	var pl: Dictionary = FP.plan_of(g)
	if key == "front" and not pl.is_empty() and not FP.running(g) and FP.wait_why(gw, gw.player.id, int(pl["foe"])) != "":

		var fmt: String = Loc.t("ПЕРЕМИРИЕ С %s: ЖДЁТ") if gw.diplo != null and gw.diplo.truce_on(gw.player.id, int(pl["foe"])) else Loc.t("ЖДЁТ ВОЙНЫ С %s")
		return [fmt % Loc.name(String(FP._cname(gw, int(pl["foe"])))).to_upper(), UiKit.GOLD]
	if key == "front" and not fr.is_empty():
		what = Loc.t("ДЕРЖИТ ФРОНТ · против %s · %.1f км") % [Loc.name(String(FP._cname(gw, int(fr["foe"])))), float(fr["len"]) / 1000.0]
	elif key == "fight":
		what = Loc.t("В БОЮ: %d из %d армий") % [int(gs.get("fight", 0)), int(gs.get("armies", 0))]
	return [what, AS.ST[key][2]]




func _in_line(fid: int, e: Dictionary) -> int:
	var h: int = int(e["have"])
	var t: int = int(e.get("type", -1))
	for u: Unit in gw.army.units:
		if u.reinf != 0 and u.type == t and u.home != null and u.home.id == fid and u.alive():
			h -= 1
	return maxi(0, h)


func _group_stats(gid: int) -> String:
	var gs: Dictionary = gst(gid)
	var rt: String = AS.reinf_txt(int(gs.get("gath", 0)), int(gs.get("walk", 0)))
	return Loc.t("%s · %d бойцов%s · сила %d%% · в окопах %d/%d") % [(Loc.n(int(gs.get("armies", 0)), "%d армия", "%d армии", "%d армий") % (int(gs.get("armies", 0)))), int(gs.get("n", 0)), (" " + rt) if rt != "" else "", roundi(float(gs.get("hp", 0.0)) * 100.0), int(gs.get("dug_armies", 0)), int(gs.get("armies", 0))]


func _trench_group(gid: int, into: bool) -> void :
	_cmd("groups", "trench_in" if into else "trench_out", [gid], func(r: Variant) -> void :
		var d: Dictionary = r if r is Dictionary else {}
		if String(d.get("why", "")) != "":
			toast(String(d["why"]))
			UiKit.snd("ui_error")
		_reopen())


func _retreat_group(gid: int) -> void :
	var g: Dictionary = _group(gid)
	var fids: PackedInt32Array = g.get("fids", PackedInt32Array())
	_cmd("groups", "order_fids", [fids, "retreat", Vector2.INF, AS.gname(g)], func(r: Variant) -> void :
		var d: Dictionary = r if r is Dictionary else {}
		if int(d.get("ok", 0)) > 0:
			toast(Loc.t("%s: отход к казармам") % AS.gname(g), _ok_fids(fids, d))
		else:
			toast(Loc.t("Отход: %s") % [_skip_why(d)])
			UiKit.snd("ui_error")
		_reopen())


func _ok_fids(fids: PackedInt32Array, d: Dictionary) -> PackedInt32Array:
	var skip: Dictionary = {}
	for e: Variant in d.get("skipped", []):
		if e is Array and not (e as Array).is_empty():
			skip[int((e as Array)[0])] = true
	var out: = PackedInt32Array()
	for fid: int in fids:
		if not skip.has(fid):
			out.append(fid)
	return out


func _skip_why(d: Dictionary) -> String:
	var sk: Array = d.get("skipped", [])
	if sk.is_empty():
		return "нет армий"
	var e: Array = sk[0]
	var f: Facility = AG.fac(gw, int(e[0]))
	return "%s — %s" % [Loc.no(f.army_no if f != null else 0), String(e[1])]




func _front_flow(gid: int, kind: String) -> void :
	close_view()
	_dock_flow = gid
	dock.front_flow(gid, kind)


func _more(anchor: Control, gid: int) -> void :
	var g: Dictionary = _group(gid)
	if g.is_empty():
		return
	var fr: Dictionary = FP.front_of(g)
	var pl: Dictionary = FP.plan_of(g)
	var items: Array = []
	items.append(["+ АРМИЯ", "добавить армии тапом по карте", func() -> void :
		picked.clear()
		for f0: int in g["fids"]:
			picked[f0] = true
		open_pick(gid)])
	items.append(["ДЕРЖАТЬ ТОЧКУ", "встать и держать место на карте", func() -> void : start_place("defend")])
	if not pl.is_empty():
		items.append(["ОТМЕНИТЬ ПЛАН", "армии вернутся на фронт", func() -> void : _cmd("front", "cancel_plan", [gid], func(_r: Variant) -> void : _reopen())])
	if not fr.is_empty():
		items.append(["СНЯТЬ ФРОНТ", "армии остановятся на месте", func() -> void : _cmd("front", "clear_front", [gid], func(_r: Variant) -> void : _reopen())])
	var auto: bool = bool(g.get("auto", false))
	items.append([Loc.t("АВТО-ФРОНТ: %s") % [(Loc.t("ВКЛ") if auto else Loc.t("ВЫКЛ"))], "штаб сам ведёт фронт и план в войне", func() -> void : _cmd("front", "set_auto", [gid, not auto], func(_r: Variant) -> void : _reopen())])
	items.append(["ПЕРЕИМЕНОВАТЬ", "имя, цвет, значок", func() -> void :
		close_view()
		_dock_flow = gid
		dock.rename_flow(gid)])
	items.append(["РАСПУСТИТЬ", "армии станут «без группы»", func() -> void :
		_cmd("groups", "disband", [gid], func(_r: Variant) -> void :
			toast(Loc.t("%s распущена") % AS.gname(g))
			_later(open_list))])
	_popover(anchor, Loc.t("ЕЩЁ · %s") % [AS.gname(g)], items)


func _popover(anchor: Control, title: String, items: Array) -> void :
	_close_pop()
	var root: = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect( func(e: InputEvent) -> void :
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_close_pop())
	hud.root.add_child(root)
	_pop = root
	var pop: = PanelContainer.new()
	pop.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 6, 6))
	root.add_child(pop)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	pop.add_child(vb)
	vb.add_child(UiKit.lbl(title, 10, UiKit.TITLE, 2, 3))
	for it: Array in items:
		var b: Button = UiKit.big(String(it[0]), "stone", "", 44.0, 10)
		b.custom_minimum_size = Vector2(236, 44)
		var cb: Callable = it[2]
		b.pressed.connect( func() -> void :
			_close_pop()
			cb.call())
		vb.add_child(b)
		vb.add_child(UiKit.lbl(String(it[1]), 9, UiKit.MUTED, 1))
	pop.reset_size()
	var ar: Rect2 = anchor.get_global_rect()
	var vs: Vector2 = get_viewport().get_visible_rect().size
	pop.position = Vector2(clampf(ar.end.x - pop.size.x, 4.0, vs.x - pop.size.x - 4.0), clampf(ar.position.y - pop.size.y - 6.0, 60.0, maxf(60.0, vs.y - pop.size.y)))
	UiKit.pop_in(pop, 0.9, 0.16)


func _close_pop() -> void :
	if _pop != null and is_instance_valid(_pop):
		_pop.queue_free()
	_pop = null



func open_army(fid: int) -> void :
	if not _ok():
		return
	var f: Facility = AG.fac(gw, fid)
	if f == null or not AG.army_alive(gw, f) or f.country_id != gw.player.id:
		return
	if view != "army" or cur_fid != fid:
		_focus({"fid": fid})
	cur_fid = fid
	var s: Dictionary = ast(fid)
	var ab: Dictionary = gw.army.army_brief(f)
	var g: Dictionary = AG.group_of(gw, gw.player.id, fid)
	var key: String = String(s["key"])
	var what: String = Loc.t(String(AS.ST[key][0]))
	var ot: String = String(ab.get("order_text", ""))
	if ot != "" and key == "take":
		what += " · " + ot.get_slice(": ", ot.get_slice_count(": ") - 1).to_lower()
	elif key == "rail" and gw.rail != null:
		what = _rail_what(f)
	elif ot != "" and key != "dug":
		what += " · " + ot.to_lower()
	if int(s["inn"]) > 0:
		what += Loc.t(" · в окопах %d/%d") % [int(s["inn"]), int(s["foot"])]
	var land: Dictionary = ab.get("landing", {})
	if String(land.get("line", "")) != "":
		what += Loc.t(" · десант: %s") % [String(land["line"]).to_lower()]
	var vb: VBoxContainer = _sheet("army")
	_head(vb, _icon_box(String(s["build_icon"])), Loc.t("АРМИЯ №%d · %s") % [int(s["no"]), Loc.t(String(s["build_name"])).to_upper()], what, AS.ST[key][2], Callable(), func() -> Array: return _army_what(fid))
	var cr: = HFlowContainer.new()
	cr.add_theme_constant_override("h_separation", 8)
	cr.add_theme_constant_override("v_separation", 2)
	vb.add_child(cr)
	for e: Dictionary in ab.get("comp", []):
		var c: = HBoxContainer.new()
		c.add_theme_constant_override("separation", 3)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(UiKit.icon_rect(String(e["icon"]), 16.0))
		c.tooltip_text = String(e["type_name"])
		var h0: int = _in_line(fid, e)
		var l: Label = UiKit.lbl("%d/%d" % [h0, int(e["want"])], 10, UiKit.TEXT if h0 >= int(e["want"]) else UiKit.GOLD, 2, 2)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var cic: String = String(e["icon"])
		_dyn(l, func() -> Array:
			var f9: Facility = AG.fac(gw, fid)
			for e9: Dictionary in (gw.army.army_brief(f9).get("comp", []) if f9 != null else []):
				if String(e9["icon"]) == cic:
					var h9: int = _in_line(fid, e9)
					return ["%d/%d" % [h9, int(e9["want"])], UiKit.TEXT if h9 >= int(e9["want"]) else UiKit.GOLD]
			return [l.text])
		c.add_child(l)
		cr.add_child(c)
	_strength(vb, fid)
	var n: int = int(s["n"])
	var rm: HBoxContainer = _row(vb)
	_primary(_verb(rm, "icon_move", "БЫСТРЫЙ\nМАРШ", func() -> void : start_place("move_army"), false, "БЫСТРЫЙ МАРШ — коснитесь цели: сразу видно, как пойдёт армия", n > 0))
	_verb(rm, "icon_route" if UiKit.has("icon_route") else "icon_move", "ИДТИ", func() -> void : start_draw("move_army"), false, "ИДТИ — проведите путь пальцем: армия пойдёт по линии; два пальца — двигать карту", n > 0)
	_verb(rm, "icon_ship" if UiKit.has("icon_ship") else "icon_port", "БЫСТРЫЙ\nДЕСАНТ", func() -> void : start_place("move_army", true), false, "БЫСТРЫЙ ДЕСАНТ — коснитесь цели за морем: посадка на своей морской базе, высадка у цели", n > 0)
	_verb(rm, "icon_ship" if UiKit.has("icon_ship") else "icon_port", "ДЕСАНТ", func() -> void : start_draw("move_army", true), false, "ДЕСАНТ — проведите линию за море: конец линии — точка высадки", n > 0)
	var r1: HBoxContainer = _row(vb)
	if land.get("pos") is Vector2:
		_verb(r1, "icon_ship" if UiKit.has("icon_ship") else "icon_port", "К ЛОДКАМ", func() -> void :
			hud.main_node.selected_fac = f
			hud.action.emit("to_boats"))
	else:
		_trench_verb(r1, func() -> bool: return bool(ast(fid)["dug"]), func(into: bool) -> void : _trench_army(fid, into), n > 0)
	var op: Dictionary = gw.ops.of(f) if gw.ops != null else {}
	if not op.is_empty():
		_verb(r1, "icon_close", "СТОП", func() -> void :
			_sim("ops", "cancel", [f], func(_r: Variant) -> void :
				toast(Loc.t("Армия №%d: приказ отменён") % f.army_no)
				_reopen()), false, "СТОП — армия прекращает приказ и остаётся на месте")
	_verb(r1, "icon_op_retreat", "ОТХОД", func() -> void :
		_sim("ops", "start", [f, Operations.Kind.RETREAT, Vector2.ZERO], func(r: Variant) -> void :
			if r is String and String(r) != "":
				toast(String(r))
				UiKit.snd("ui_error")
			else:
				toast(Loc.t("Армия №%d: отход к казармам") % f.army_no, PackedInt32Array([fid]))
			_reopen()), false, "ОТХОД — к своим казармам, пополниться", n > 0)
	_rail_verb(r1, func() -> Array: return [fid])
	if not g.is_empty() and not FP.front_of(g).is_empty():
		_line(vb, Loc.t("ФРОНТ группы %s: держит свой участок") % AS.gname(g), UiKit.MUTED)
	else:
		_stance(vb, clampi(f.stance, 0, 2), func(sv: int) -> void :
			_sim("ops", "set_stance", [f, sv], func(r: Variant) -> void :
				if r is String and String(r) != "":
					toast(String(r))
				_reopen()))

	var hb0: HBoxContainer = vb.get_child(0) as HBoxContainer
	var xi: int = hb0.get_child_count() - 1
	var gb: Button = UiKit.slot("icon_group_add", false, 44.0)
	gb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if not g.is_empty():
		var gi: TextureRect = UiKit.slot_icon(gb)
		if gi != null:
			gi.visible = false
		var gcc: = CenterContainer.new()
		gcc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gcc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gcc.add_child(U.emblem_rect(String(g["emblem"]), U.color(int(g["color"])), 26, true))
		gb.add_child(gcc)
		var gid: int = int(g["id"])
		gb.pressed.connect( func() -> void : open_group(gid))
		HT.tip(gb, Loc.t("ГРУППА %s — карточка группы этой армии") % AS.gname(g))
	else:
		gb.pressed.connect( func() -> void :
			picked = {fid: true}
			open_pick(-1))
		HT.tip(gb, "В ГРУППУ — собрать группу с этой армией")
	hb0.add_child(gb)
	hb0.move_child(gb, xi)
	var kb: Button = UiKit.slot("icon_barracks", false, 44.0)
	kb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	kb.pressed.connect( func() -> void : open_bar(fid))
	HT.tip(kb, "КАЗАРМЫ — здание армии: сборка, пополнение, снос")
	hb0.add_child(kb)
	hb0.move_child(kb, xi + 1)
	_verbs_last(vb, r1)
	_verbs_last(vb, rm)
	_struct = _struct_sig()


func _army_what(fid: int) -> Array:
	var f: Facility = AG.fac(gw, fid)
	var s: Dictionary = ast(fid)
	var key: String = String(s["key"])
	var what: String = Loc.t(String(AS.ST[key][0]))
	if f == null:
		return [what, AS.ST[key][2]]
	var ab: Dictionary = gw.army.army_brief(f)
	var ot: String = String(ab.get("order_text", ""))
	if ot != "" and key == "take":
		what += " · " + ot.get_slice(": ", ot.get_slice_count(": ") - 1).to_lower()
	elif key == "rail" and gw.rail != null:
		what = _rail_what(f)
	elif ot != "" and key != "dug":
		what += " · " + ot.to_lower()
	if int(s["inn"]) > 0:
		what += Loc.t(" · в окопах %d/%d") % [int(s["inn"]), int(s["foot"])]
	var land: Dictionary = ab.get("landing", {})
	if String(land.get("line", "")) != "":
		what += Loc.t(" · десант: %s") % [String(land["line"]).to_lower()]
	return [what, AS.ST[key][2]]


func _trench_army(fid: int, into: bool) -> void :
	var f: Facility = AG.fac(gw, fid)
	_cmd("groups", "trench_in_fids" if into else "trench_out_fids", [PackedInt32Array([fid]), Loc.t("Армия №%d") % (f.army_no if f != null else 0)], func(r: Variant) -> void :
		var d: Dictionary = r if r is Dictionary else {}
		if String(d.get("why", "")) != "":
			toast(String(d["why"]))
			UiKit.snd("ui_error")
		_reopen())




func open_bar(fid: int) -> void :
	if not _ok():
		return
	var f: Facility = AG.fac(gw, fid)
	if f == null or f.country_id != gw.player.id:
		return
	if view != "bar" or cur_fid != fid:
		_focus({"bar": fid})
	cur_fid = fid
	var ab: Dictionary = gw.army.army_brief(f)
	var vb: VBoxContainer = _sheet("bar")

	var rtxt: = func() -> Array:
		var f9: Facility = AG.fac(gw, fid)
		if f9 == null:
			return ["", UiKit.TEXT]
		if f9.prod_type == 3:
			return ["НАБОР ОСТАНОВЛЕН", UiKit.GOLD]
		return [String(gw.army.refill_status(f9, true)), UiKit.TEXT if f9.auto_refill else UiKit.GOLD]
	var r0: Array = rtxt.call()
	_head(vb, _icon_box("icon_barracks"), Loc.t("КАЗАРМЫ АРМИИ №%d") % int(ab.get("no", f.army_no)), String(r0[0]), r0[1], Callable(), rtxt)
	var db: Button = UiKit.big("СНЕСТИ…", "stone", "", 44.0, 9)
	db.custom_minimum_size = Vector2(72, 44)
	db.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	db.clip_contents = true


	db.set_meta("hold_act", true)
	if gw.mil.demolish_why(gw.player, f) != "":
		db.modulate.a = 0.55
	var fill: = ColorRect.new()
	fill.color = Color(0.85, 0.2, 0.12, 0.75)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.size = Vector2(0, 44)
	db.add_child(fill)
	db.button_down.connect( func() -> void :
		var f8: Facility = AG.fac(gw, fid)
		var why8: String = gw.mil.demolish_why(gw.player, f8)
		if why8 != "":
			_hold_t = -1.0
			toast(why8)
			UiKit.snd("ui_error")
			return
		_hold_b = db
		_hold_fill = fill
		_hold_t = 0.0)
	HT.tip(db, "СНЕСТИ — удерживайте 1 секунду; армия останется без пополнения")
	var hb0: HBoxContainer = vb.get_child(0) as HBoxContainer
	hb0.add_child(db)
	hb0.move_child(db, hb0.get_child_count() - 2)

	var cr: = HFlowContainer.new()
	cr.add_theme_constant_override("h_separation", 8)
	cr.add_theme_constant_override("v_separation", 2)
	vb.add_child(cr)
	for e: Dictionary in ab.get("comp", []):
		var c: = HBoxContainer.new()
		c.add_theme_constant_override("separation", 3)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(UiKit.icon_rect(String(e["icon"]), 16.0))
		var hl0: int = _in_line(fid, e)
		c.add_child(UiKit.lbl("%d/%d" % [hl0, int(e["want"])], 10, UiKit.TEXT if hl0 >= int(e["want"]) else UiKit.GOLD, 2, 2))
		cr.add_child(c)
	if AG.army_alive(gw, f):
		_strength(vb, fid)

	var sq: = func() -> String:
		var a: Dictionary = ast(fid)
		var gn: int = int(a.get("gath", 0))
		var wk: int = int(a.get("walk", 0))
		if wk > 0:
			return Loc.t("Отряд к армии: %d %s") % [wk, Loc.t("идёт") if wk == 1 else Loc.t("идут")]
		if gn > 0:
			return Loc.t("Отряд к армии: %d %s") % [gn, Loc.t("собирается") if gn == 1 else Loc.t("собираются")]
		return ""
	var sql: Label = _line(vb, sq.call(), UiKit.MUTED)
	sql.visible = sql.text != ""
	_dyn(sql, func() -> Array:
		var t: String = sq.call()
		sql.visible = t != ""
		return [t, UiKit.MUTED])

	var on: bool = f.auto_refill
	var rr: HBoxContainer = _row(vb, 4)
	var rl: Label = UiKit.lbl("ПОПОЛНЕНИЕ", 10, UiKit.TEXT, 2, 2)
	rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rr.add_child(rl)
	for o: Array in [["ВКЛ", true], ["ВЫКЛ", false]]:
		var want: bool = bool(o[1])
		var tb: Button = UiKit.big(String(o[0]), "gold" if want == on else "stone", "", 44.0, 10)
		tb.custom_minimum_size = Vector2(56, 44)
		tb.pressed.connect( func() -> void :
			if want == f.auto_refill:
				return
			_sim("army", "set_auto_refill", [f, want], func(_r: Variant) -> void : _reopen()))
		HT.tip(tb, Loc.t("Пополнение %s — %s") % [String(o[0]), Loc.t("казармы сами восполняют потери") if want else Loc.t("потери не восполняются")])
		rr.add_child(tb)
	var bic: String = String(ab.get("build_icon", "icon_infantry"))
	var ab2: Button = UiKit.big(Loc.t("АРМИЯ №%d") % int(ab.get("no", f.army_no)), "stone", bic if UiKit.has(bic) else "icon_infantry", 44.0, 10)
	ab2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ab2.clip_text = true
	ab2.pressed.connect( func() -> void : open_army(fid))
	HT.tip(ab2, "АРМИЯ — карточка армии этих казарм: приказы, окопы, режим")
	rr.add_child(ab2)

	var bn: String = Loc.t(String(ab.get("build_name", ""))).to_upper()
	var sb2: Button = UiKit.big(Loc.t("СБОРКА: %s") % bn if bn != "" else Loc.t("СБОРКА"), "stone", bic if UiKit.has(bic) else "icon_menu", 44.0, 10)
	sb2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb2.clip_text = true
	sb2.pressed.connect( func() -> void :
		hud.main_node.selected_fac = f
		hud.main_node.set("army_view", false)
		hud.main_node.set("bar_builds_fid", f.id)
		hud.open_builds(f))
	HT.tip(sb2, "СБОРКА — кого обучают казармы: штурм, ПТ-оборона, танки…")
	_primary(sb2)
	vb.add_child(sb2)
	_struct = _struct_sig()


func _hold_tick(delta: float) -> void :
	if _hold_b == null or not is_instance_valid(_hold_b) or _hold_t < 0.0:
		return
	var mn8: Node = hud.main_node.get("menus") if hud.main_node != null else null
	if _hold_b.button_pressed and not (mn8 != null and mn8.is_open()):
		var why: String = gw.mil.demolish_why(gw.player, AG.fac(gw, cur_fid))
		if why != "":
			_hold_t = -1.0
			_hold_fill.size.x = 0.0
			toast(why)
			UiKit.snd("ui_error")
			return
		_hold_t += delta
		_hold_fill.size = Vector2(_hold_b.size.x * clampf(_hold_t, 0.0, 1.0), _hold_b.size.y)
		if _hold_t >= 1.0:
			_hold_t = -1.0
			var f: Facility = AG.fac(gw, cur_fid)
			close_view()
			if f != null and hud.main_node != null and hud.main_node.has_method("_demolish_now"):
				hud.main_node._demolish_now(f)
	else:
		if _hold_t > 0.0 and _hold_t < 1.0:
			toast("Держите «СНЕСТИ…» 1 секунду")
		_hold_t = -1.0
		_hold_fill.size.x = 0.0




func start_place(kind: String, sea: bool = false) -> void :
	draw_on = false
	draw_pts = PackedVector2Array()
	draw_wps = PackedVector2Array()
	place_kind = kind
	place_sea = sea and kind != "defend"
	preview = {}
	var who: String = (Loc.t("АРМИЯ №%d") % AG.fac(gw, cur_fid).army_no) if kind == "move_army" else AS.gname(_group(cur_gid))
	var what: String = Loc.t("МОРСКОЙ ДЕСАНТ") if place_sea else {"move": "ИДТИ", "move_army": "ИДТИ", "defend": "ДЕРЖАТЬ ТОЧКУ"}[kind]
	_banner("place", "%s · %s" % [what, who], Loc.t("коснитесь цели за морем — посадка на морской базе, путь видно сразу") if place_sea else Loc.t("коснитесь цели — сразу видно, кто и как пойдёт"), UiKit.TEXT)
	hud.action.emit("cancel_select")


func _banner(v: String, t1: String, t2: String, col2: Color, done: Callable = Callable(), done_text: String = "ГОТОВО", extra: Callable = Callable()) -> void :
	var vb: VBoxContainer = _sheet(v)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)
	var tv: = VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	hb.add_child(tv)
	tv.add_child(UiKit.lbl(t1, 12, UiKit.TITLE, 2, 3))
	var l2: Label = UiKit.lbl(t2, 10, col2, 2, 4)
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(l2)
	if done.is_valid():
		var ok: Button = UiKit.big(done_text, "green", "", 44.0, 11)
		ok.custom_minimum_size = Vector2(88, 44)
		ok.pressed.connect(done)
		hb.add_child(ok)
	var cb: Button = UiKit.big("ОТМЕНА", "stone", "", 44.0, 10)
	cb.custom_minimum_size = Vector2(76, 44)
	cb.pressed.connect( func() -> void :
		var back: String = view
		preview = {}
		if back == "place" and place_kind == "move_army":
			open_army(cur_fid)
		elif back == "place" and cur_gid >= 0:
			open_group(cur_gid)
		elif back == "pick" and pick_into >= 0:
			picked.clear()
			open_group(pick_into)
		else:
			picked.clear()
			open_list())
	hb.add_child(cb)
	if extra.is_valid():
		extra.call(vb)




func check(fids: PackedInt32Array, to: Vector2, kind: String) -> Dictionary:
	var ok: Array = []
	var bad: Array = []
	var mins: float = 0.0
	var sea: int = 0
	var rk_ok: bool = gw.ops.has_method("route_kind")
	var entries: Array = []
	if place_kind == "move_army":
		var f0: Facility = AG.fac(gw, fids[0])
		entries.append({"f": f0, "to": to, "kind": -1, "why": "", "wp": Vector2.INF})
	else:
		entries = AG.plan(gw, gw.player.id, fids, kind, to)
	for e: Dictionary in entries:
		var f: Facility = e["f"]
		var why: String = String(e["why"])
		if why == "":
			if rk_ok:
				var rk: Dictionary = gw.ops.route_kind(f, e["to"], int(e["kind"]), e.get("wp", Vector2.INF), place_sea)
				if String(rk.get("kind", "none")) != "none":
					var s: bool = String(rk["kind"]) == "sea"
					ok.append([f.id, rk.get("path", PackedVector2Array()), s, rk.get("rail", {}), rk.has("rail_denied")])
					mins = maxf(mins, float(rk.get("eta", 0.0)) / 60.0)
					sea += 1 if s else 0
					continue
				why = String(rk.get("why", "нет пути"))
			else:
				var chk: Dictionary = gw.ops._check(f, int(e["kind"]), e["to"], e.get("wp", Vector2.INF))
				if bool(chk["ok"]):
					var s2: bool = chk.has("naval")
					ok.append([f.id, chk.get("path", PackedVector2Array()), s2])
					mins = maxf(mins, float(chk["len"]) / maxf(1.0, gw.ops._speed(f)) / 60.0)
					sea += 1 if s2 else 0
					continue
				why = String(chk["why"])
		bad.append([f.id, why if why != "" else "нет пути"])
	return {"ok": ok, "bad": bad, "mins": mins, "sea": sea}


func place_tap(to: Vector2) -> void :
	var fids: PackedInt32Array = PackedInt32Array([cur_fid]) if place_kind == "move_army" else _group(cur_gid).get("fids", PackedInt32Array())
	var kind: String = "defend" if place_kind == "defend" else "move"
	var chk: Dictionary = check(fids, to, kind)
	preview = {"to": to, "ok": chk["ok"], "bad": chk["bad"], "until": Time.get_ticks_msec() + 6000}
	var nok: int = (chk["ok"] as Array).size()
	var nbad: int = (chk["bad"] as Array).size()
	var sea: int = int(chk["sea"])
	var who: String = (Loc.t("Армия №%d") % AG.fac(gw, cur_fid).army_no) if place_kind == "move_army" else AS.gname(_group(cur_gid))
	var title: String = "%s · %s" % [Loc.t("ДЕРЖАТЬ ТОЧКУ") if kind == "defend" else (Loc.t("ДЕСАНТ") if place_sea else Loc.t("ИДТИ")), who]
	if nok == 0:
		var f0: Facility = AG.fac(gw, int((chk["bad"] as Array)[0][0])) if nbad > 0 else null
		var why: String = String((chk["bad"] as Array)[0][1]) if nbad > 0 else Loc.t("некому идти")
		_banner("place", title, (Loc.t("Не пойдут: ") if nbad > 1 else Loc.t("Не пойдёт: ")) + why + ("" if f0 == null or nbad == 1 else Loc.t(" (№%d и ещё %d)") % [f0.army_no, nbad - 1]), UiKit.RED)
		UiKit.snd("ui_error")
		return
	var okf: = PackedInt32Array()
	for e: Array in chk["ok"]:
		okf.append(int(e[0]))
	if nbad > 0:
		var f1: Facility = AG.fac(gw, int((chk["bad"] as Array)[0][0]))
		var line: String = Loc.t("Пойдут %d из %d · №%d: %s") % [nok, nok + nbad, f1.army_no, String((chk["bad"] as Array)[0][1])]
		if sea > 0:
			line += Loc.t(" · %d морем (ДЕСАНТ)") % sea
		_banner("place", title, line, UiKit.GOLD, func() -> void : _send(okf, to, kind, sea, float(chk["mins"])), Loc.t("ИДТИ: %d") % nok)
		return
	_send(okf, to, kind, sea, float(chk["mins"]))


func _send(fids: PackedInt32Array, to: Vector2, kind: String, sea: int, mins: float) -> void :
	var tail: String = (Loc.t(" · %d ДЕСАНТОМ") % sea) if sea > 1 else (Loc.t(" · ДЕСАНТ морем") if sea == 1 else "")
	var rw: String = _rail_word()
	if rw != "":
		tail = " · " + rw
	if place_sea:
		kind = "sea"
	if place_kind == "move_army" and place_sea:
		var fa: Facility = AG.fac(gw, cur_fid)
		var fida: int = cur_fid
		_cmd("groups", "order_fids", [PackedInt32Array([fida]), kind, to, ""], func(r: Variant) -> void :
			var d: Dictionary = r if r is Dictionary else {}
			if int(d.get("ok", 0)) > 0:
				toast(Loc.t("Армия №%d: морской десант · ~%d мин") % [fa.army_no, maxi(1, ceili(mins))], PackedInt32Array([fida]))
				UiKit.snd("ui_build")
			else:
				toast(Loc.t("Не пошла: %s") % [_skip_why(d)])
				UiKit.snd("ui_error")
			_later( func() -> void : open_army(fida)))
		return
	if place_kind == "move_army":
		var f: Facility = AG.fac(gw, cur_fid)
		var fid0: int = cur_fid
		_sim("ops", "start", [f, -1, to], func(r: Variant) -> void :
			if r is String and String(r) != "":
				toast(String(r))
				UiKit.snd("ui_error")
			else:
				if rw != "":
					toast(Loc.t("Армия №%d · %s · ~%d мин") % [f.army_no, rw, maxi(1, ceili(mins))], PackedInt32Array([fid0]))
				else:
					toast(Loc.t("Армия №%d идёт · ~%d мин%s") % [f.army_no, maxi(1, ceili(mins)), tail], PackedInt32Array([fid0]))
				UiKit.snd("ui_build")
			_later( func() -> void : open_army(fid0)))
		return
	var g: Dictionary = _group(cur_gid)
	var gid0: int = cur_gid
	_cmd("groups", "order_fids", [fids, kind, to, AS.gname(g)], func(r: Variant) -> void :
		var d: Dictionary = r if r is Dictionary else {}
		var n: int = int(d.get("ok", 0))
		if n > 0:
			toast(Loc.t("%s: %d %s · ~%d мин%s") % [AS.gname(g), n, Loc.t("армия идёт") if n == 1 else Loc.t("армий идут"), maxi(1, ceili(mins)), tail], _ok_fids(fids, d))
			UiKit.snd("ui_build")
		else:
			toast(Loc.t("Не пошли: %s") % [_skip_why(d)])
			UiKit.snd("ui_error")
		_later( func() -> void : open_group(gid0)))




const DRAW_EPS_PX: float = 20.0
const DRAW_TAP_PX: float = 24.0
const DRAW_MAX_PTS: int = 600




func start_draw(kind: String, sea: bool = false) -> void :
	start_place(kind, sea)
	draw_on = true
	var who: String = (Loc.t("АРМИЯ №%d") % AG.fac(gw, cur_fid).army_no) if kind == "move_army" else AS.gname(_group(cur_gid))
	_banner("place", "%s · %s" % [Loc.t("ДЕСАНТ ПО ЛИНИИ") if place_sea else Loc.t("ИДТИ ПО МАРШРУТУ"), who], Loc.t("проведите линию за море пальцем — конец линии = высадка; два пальца — карта") if place_sea else Loc.t("проведите путь пальцем — армии пойдут по линии; два пальца — карта"), UiKit.TEXT)


func drawing() -> bool:
	return draw_on and view == "place" and _ok()



func route_grab(_sp: Vector2) -> bool:
	if not drawing():
		return false
	draw_pts = PackedVector2Array()
	draw_wps = PackedVector2Array()
	preview = {}
	return true


func route_drag(from_w: Vector2, to_w: Vector2) -> void :
	if not drawing():
		return
	if draw_pts.is_empty():
		draw_pts.append(from_w)
	var z: float = maxf(0.05, float(hud.main_node.cam.zoom.x))
	if draw_pts.size() < DRAW_MAX_PTS and draw_pts[draw_pts.size() - 1].distance_to(to_w) > 4.0 / z:
		draw_pts.append(to_w)


func route_drag_end() -> void :
	if not drawing():
		return
	if draw_pts.size() >= 2:
		var z: float = maxf(0.05, float(hud.main_node.cam.zoom.x))
		if draw_pts[0].distance_to(draw_pts[draw_pts.size() - 1]) < DRAW_TAP_PX / z and _poly_len(draw_pts) < DRAW_TAP_PX * 2.0 / z:
			draw_pts = PackedVector2Array([draw_pts[draw_pts.size() - 1]])
	_draw_done()


static func _poly_len(p: PackedVector2Array) -> float:
	var l: float = 0.0
	for i in range(1, p.size()):
		l += p[i - 1].distance_to(p[i])
	return l



static func rdp(p: PackedVector2Array, eps: float) -> PackedVector2Array:
	if p.size() < 3:
		return p.duplicate()
	var keep: = PackedByteArray()
	keep.resize(p.size())
	keep.fill(0)
	keep[0] = 1
	keep[p.size() - 1] = 1
	var st: Array = [[0, p.size() - 1]]
	while not st.is_empty():
		var seg: Array = st.pop_back()
		var a: int = seg[0]
		var b: int = seg[1]
		var bd: float = eps
		var bi: int = -1
		for i in range(a + 1, b):
			var d: float = p[i].distance_to(Geometry2D.get_closest_point_to_segment(p[i], p[a], p[b]))
			if d > bd:
				bd = d
				bi = i
		if bi >= 0:
			keep[bi] = 1
			st.append([a, bi])
			st.append([bi, b])
	var out: = PackedVector2Array()
	for j in p.size():
		if keep[j] == 1:
			out.append(p[j])
	return out




func draw_route(raw: PackedVector2Array, z: float) -> PackedVector2Array:
	var eps: float = DRAW_EPS_PX / maxf(0.05, z)
	var pts: PackedVector2Array = rdp(raw, eps)
	while pts.size() > AG.ROUTE_MAX + 1:
		eps *= 1.5
		pts = rdp(raw, eps)
	if place_sea:
		return pts
	var out: = PackedVector2Array()
	for p: Vector2 in pts:
		var q: Vector2 = p if gw.army.tac._dry(p) else gw.econ._dry_near(p)
		if q.is_finite() and (out.is_empty() or out[out.size() - 1].distance_to(q) > 8.0):
			out.append(q)
	return out




func _draw_done() -> void :
	if draw_pts.is_empty():
		return
	var wps: PackedVector2Array = draw_route(draw_pts, float(hud.main_node.cam.zoom.x))
	var who: String = (Loc.t("Армия №%d") % AG.fac(gw, cur_fid).army_no) if place_kind == "move_army" else AS.gname(_group(cur_gid))
	var title: String = "%s · %s" % [Loc.t("ДЕСАНТ ПО ЛИНИИ") if place_sea else Loc.t("ИДТИ ПО МАРШРУТУ"), who]
	if wps.is_empty():
		draw_wps = PackedVector2Array()
		_banner("place", title, "Линия целиком в море — проведите путь по суше", UiKit.RED)
		UiKit.snd("ui_error")
		return
	draw_wps = wps
	var to: Vector2 = wps[wps.size() - 1]
	var chain: PackedVector2Array = PackedVector2Array() if place_sea else wps.slice(0, wps.size() - 1)
	var fids: PackedInt32Array = PackedInt32Array([cur_fid]) if place_kind == "move_army" else _group(cur_gid).get("fids", PackedInt32Array())
	var kind: String = "defend" if place_kind == "defend" else "move"
	var chk: Dictionary = check(fids, to, kind)
	var okl: Array = []
	var ratio: float = 1.0
	for e: Array in chk["ok"]:
		var p0: PackedVector2Array = e[1]
		if chain.size() > 0 and p0.size() >= 2 and not bool(e[2]):
			var pp: = PackedVector2Array([p0[0]])
			pp.append_array(chain)
			pp.append(to)
			ratio = maxf(ratio, _poly_len(pp) / maxf(1.0, _poly_len(p0)))
			okl.append([e[0], pp, false])
		else:
			okl.append(e)
	preview = {"to": to, "ok": okl, "bad": chk["bad"], "until": Time.get_ticks_msec() + 120000}
	var nok: int = okl.size()
	var nbad: int = (chk["bad"] as Array).size()
	if nok == 0:
		var why: String = String((chk["bad"] as Array)[0][1]) if nbad > 0 else Loc.t("некому идти")
		_banner("place", title, Loc.t("%s%s · проведите заново") % [(Loc.t("Не пойдут: ") if nbad > 1 else Loc.t("Не пойдёт: ")), why], UiKit.RED)
		UiKit.snd("ui_error")
		return
	var okf: = PackedInt32Array()
	for e2: Array in okl:
		okf.append(int(e2[0]))
	var mins: float = float(chk["mins"]) * ratio
	var line: String = (Loc.t("высадка в конце линии") if place_sea else (Loc.n(chain.size() + 1, "%d точка", "%d точки", "%d точек") % (chain.size() + 1))) + Loc.t(" · ~%d мин") % maxi(1, ceili(mins))
	if nbad > 0:
		var f1: Facility = AG.fac(gw, int((chk["bad"] as Array)[0][0]))
		line += Loc.t(" · пойдут %d из %d · №%d: %s") % [nok, nok + nbad, f1.army_no if f1 != null else 0, String((chk["bad"] as Array)[0][1])]
	line += Loc.t(" · новая линия — заново")
	_banner("place", title, line, UiKit.GOLD if nbad > 0 else UiKit.TEXT, func() -> void : _send_draw(okf, to, chain, kind, mins), Loc.t("ВЫСАДКА") if place_sea else Loc.t("ИДТИ"))
	UiKit.snd("ui_select")




func _send_draw(fids: PackedInt32Array, to: Vector2, chain: PackedVector2Array, kind: String, mins: float) -> void :
	var army: bool = place_kind == "move_army"
	var fid0: int = cur_fid
	var gid0: int = cur_gid
	var g: Dictionary = _group(cur_gid)
	var who: String = (Loc.t("Армия №%d") % AG.fac(gw, fid0).army_no) if army else AS.gname(g)
	var k2: String = "sea" if place_sea else kind
	var sea: bool = place_sea
	draw_on = false
	preview["until"] = Time.get_ticks_msec() + 6000
	_cmd("groups", "order_fids", [fids, k2, to, "" if army else who, Vector2.INF, chain], func(r: Variant) -> void :
		var d: Dictionary = r if r is Dictionary else {}
		var n: int = int(d.get("ok", 0))
		if n > 0:
			toast(Loc.t("%s: %s · ~%d мин") % [who, Loc.t("десант, высадка в конце линии") if sea else Loc.t("по маршруту"), maxi(1, ceili(mins))], _ok_fids(fids, d))
			UiKit.snd("ui_build")
		else:
			toast(Loc.t("Не пошли: %s") % [_skip_why(d)])
			UiKit.snd("ui_error")
		draw_pts = PackedVector2Array()
		draw_wps = PackedVector2Array()
		_later( func() -> void :
			if army:
				open_army(fid0)
			else:
				open_group(gid0)))




func open_pick(into: int) -> void :
	if view != "pick":
		_pick_sx = 0
		_pick_fold.clear()
	pick_into = into
	var warn: PackedStringArray = PackedStringArray()
	for fid: int in picked:
		var f: Facility = AG.fac(gw, fid)
		if f != null and f.group_id >= 0 and f.group_id != into:
			warn.append(Loc.t("№%d уйдёт из %s") % [f.army_no, AS.gname(_group(f.group_id))])
	var line: String = Loc.t("Выбрано %d · тап по армии на карте или по фишке") % picked.size()
	if not warn.is_empty():
		line = Loc.t("Выбрано %d · %s") % [picked.size(), ", ".join(warn.slice(0, 2)) + (" …" if warn.size() > 2 else "")]
	_banner("pick", (Loc.t("+ АРМИЯ В %s") % AS.gname(_group(into))) if into >= 0 else Loc.t("НОВАЯ ГРУППА"), line, UiKit.GOLD if not warn.is_empty() else UiKit.TEXT, _pick_done, "ГОТОВО", _pick_sections)






var _pick_fold: Dictionary = {}
static var _arrow_down: Texture2D = null


func _pick_sections(vb: VBoxContainer) -> void :
	var free: Array = []
	var by_g: Dictionary = {}
	var live: Dictionary = {}
	for g0: Dictionary in gw.player.army_groups:
		live[int(g0["id"])] = true
	for f: Facility in _armies():
		if f.group_id < 0 or not live.has(f.group_id):
			free.append(f)
		elif f.group_id != pick_into:
			if not by_g.has(f.group_id):
				by_g[f.group_id] = []
			(by_g[f.group_id] as Array).append(f)
	var sc: = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = false
	vb.add_child(sc)
	var lv: = VBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lv)
	if free.is_empty() and by_g.is_empty():
		_line(lv, Loc.t("Других армий нет — постройте КАЗАРМЫ во вкладке АРМИЯ.") if pick_into < 0 or _armies().size() > 0 else Loc.t("Армий пока нет."), UiKit.MUTED)

	var hr: = HBoxContainer.new()
	hr.visible = not free.is_empty()
	hr.add_theme_constant_override("separation", 6)
	lv.add_child(hr)
	var ht: Label = UiKit.lbl(Loc.t("БЕЗ ГРУППЫ · %d") % free.size(), 11, UiKit.GOLD, 2, 3)
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ht.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(ht)
	if free.size() >= 2:
		var all_on: bool = true
		for f3: Facility in free:
			all_on = all_on and picked.has(f3.id)
		var ab: Button = UiKit.big(Loc.t("СНЯТЬ ВСЕ") if all_on else Loc.t("ВЫБРАТЬ ВСЕ"), "stone", "", 44.0, 10)
		ab.custom_minimum_size = Vector2(112, 44)
		ab.pressed.connect( func() -> void :
			for f4: Facility in free:
				if all_on:
					picked.erase(f4.id)
				else:
					picked[f4.id] = true
			UiKit.snd("ui_select")
			open_pick(pick_into))
		hr.add_child(ab)
	if not free.is_empty():
		_pick_grid(lv, free)

	for g: Dictionary in gw.player.army_groups:
		var gid: int = int(g["id"])
		if not by_g.has(gid):
			continue
		var arr: Array = by_g[gid]
		var n_on: int = 0
		for f5: Facility in arr:
			if picked.has(f5.id):
				n_on += 1
		var open: bool = bool(_pick_fold.get(gid, n_on > 0 or free.is_empty()))
		var gb: Button = UiKit.big("", "stone", "", 44.0, 10)
		gb.custom_minimum_size = Vector2(0, 44)
		var gh: = HBoxContainer.new()
		gh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gh.offset_left = 8
		gh.offset_right = -8
		gh.add_theme_constant_override("separation", 8)
		gh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gb.add_child(gh)
		var stripe: = ColorRect.new()
		stripe.color = U.color(int(g["color"]))
		stripe.custom_minimum_size = Vector2(4, 0)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gh.add_child(stripe)
		gh.add_child(U.emblem_rect(String(g["emblem"]), U.color(int(g["color"])), 24, true))
		var gl: Label = UiKit.lbl(AS.gname(g), 11, UiKit.TEXT, 2, 3)
		gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		gl.clip_text = true
		gl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		gh.add_child(gl)
		var cnt: Label = UiKit.lbl((Loc.t("выбрано %d из %d") % [n_on, arr.size()]) if n_on > 0 else (Loc.n(arr.size(), "%d армия", "%d армии", "%d армий") % (arr.size())), 10, UiKit.GOLD if n_on > 0 else UiKit.MUTED, 2, 2)
		cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		gh.add_child(cnt)
		var arw: TextureRect = UiKit.icon_rect("wb_arrow_r", 14.0)
		arw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if open and arw.texture != null:
			if _arrow_down == null:
				var ai: Image = arw.texture.get_image()
				ai.rotate_90(CLOCKWISE)
				_arrow_down = ImageTexture.create_from_image(ai)
			arw.texture = _arrow_down
		gh.add_child(arw)
		gb.pressed.connect( func() -> void :
			_pick_fold[gid] = not open
			open_pick(pick_into))
		lv.add_child(gb)
		if open:
			_pick_grid(lv, arr)
	if pick_into >= 0:
		var mine: PackedStringArray = PackedStringArray()
		for fid: int in _group(pick_into).get("fids", PackedInt32Array()):
			var f6: Facility = AG.fac(gw, fid)
			if f6 != null:
				mine.append(Loc.no(f6.army_no))
		if not mine.is_empty():
			_line(lv, Loc.t("В группе %s уже: %s") % [AS.gname(_group(pick_into)), ", ".join(mine)], UiKit.MUTED)

	var want_h: float = minf(lv.get_combined_minimum_size().y, maxf(get_viewport().get_visible_rect().size.y * 0.25, 200.0))
	sc.custom_minimum_size = Vector2(0, maxf(want_h, 96.0))

	var vbar: VScrollBar = sc.get_v_scroll_bar()
	var want: Array = [_pick_sx]
	vbar.changed.connect( func() -> void :
		if int(want[0]) > 0 and is_instance_valid(sc):
			sc.scroll_vertical = int(want[0])
			if sc.scroll_vertical >= int(want[0]):
				want[0] = 0)
	vbar.value_changed.connect( func(v: float) -> void :
		if int(want[0]) == 0:
			_pick_sx = int(v))


func _pick_grid(parent: Control, arr: Array) -> void :
	var grid: = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	for f: Facility in arr:
		_army_chip(grid, f.id)


func _pick(fid: int) -> void :
	if picked.has(fid):
		picked.erase(fid)
	else:
		picked[fid] = true
	UiKit.snd("ui_select")
	open_pick(pick_into)


func _pick_done() -> void :
	if picked.is_empty():
		toast("Коснитесь хотя бы одной армии")
		return
	var fids: = PackedInt32Array()
	for k: int in picked:
		fids.append(k)
	picked.clear()
	if pick_into >= 0:
		var gid0: int = pick_into
		_cmd("groups", "add", [gid0, fids], func(_r: Variant) -> void :
			toast(Loc.t("%s: армий в группе %d") % [AS.gname(_group(gid0)), (_group(gid0).get("fids", PackedInt32Array()) as PackedInt32Array).size()])
			_later( func() -> void : open_group(gid0)))
		return
	var used: Dictionary = {}
	for g: Dictionary in gw.player.army_groups:
		used[int(g["color"])] = true
	var col: int = 0
	for c in AG.N_COLORS:
		if not used.has(c):
			col = c
			break
	var emb: String = String(AG.EMBLEMS[gw.player.army_groups.size() % AG.EMBLEMS.size()])
	_cmd("groups", "create", [AG.default_name(gw, gw.player.id), col, emb, fids], func(r: Variant) -> void :
		var g2: Dictionary = r if r is Dictionary else {}
		if g2.is_empty():
			toast(Loc.t("Групп уже %d — больше нельзя") % AG.MAX_GROUPS)
			_later(open_list)
			return
		toast(Loc.t("%s создана: %s · имя и цвет — в ЕЩЁ") % [AS.gname(g2), (Loc.n(fids.size(), "%d армия", "%d армии", "%d армий") % (fids.size()))])
		var nid: int = int(g2["id"])
		_later( func() -> void : open_group(nid)))
