extends PanelContainer







const AG = preload("res://game/army_groups.gd")

var hud: Node
var gw: GameWorld
var main: Node
var oid: int = -1
var _step: int = 1
var _vb: VBoxContainer
var _sig: String = ""
var _sig_t: float = 0.0


static func open(h: Node, id: int) -> Control:
	var old: Variant = h.get_meta("hold_card") if h.has_meta("hold_card") else null
	if old != null and is_instance_valid(old):
		(old as Control).call("close")
	var c: PanelContainer = (load("res://ui/ui24/hold_card.gd") as GDScript).new()
	c.hud = h
	c.gw = h.get("gw")
	c.main = h.get("main_node")
	c.oid = id
	h.set_meta("hold_card", c)
	c._mount()
	return c


func _mount() -> void :
	var psb: StyleBox = UiKit.sb("wb_panel", 8, 6)
	psb.content_margin_bottom = 8.0 + float(hud.call("_safe_margins").y)
	add_theme_stylebox_override("panel", psb)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var holder: Control = hud.get("holder")
	holder.add_child(self)
	var tr: Control = hud.get("tab_row")
	if tr != null:
		holder.move_child(self, tr.get_index() + 1)
	hud.call("ui24_open", self)
	_vb = VBoxContainer.new()
	_vb.add_theme_constant_override("separation", 6)
	add_child(_vb)
	_sel(oid)
	_build()


func close() -> void :
	_sel(-1)
	if hud != null and is_instance_valid(hud):
		hud.call("ui24_closed", self)
		if hud.has_meta("hold_card") and hud.get_meta("hold_card") == self:
			hud.remove_meta("hold_card")
		var bp: Control = hud.get("bottom_panel")
		if bp != null and (hud.get("ui24_sheet") == null):
			bp.visible = true
	queue_free()


func _sel(id: int) -> void :
	var l: Node = gw.get_node_or_null("Hold") if gw != null else null
	if l != null:
		l.set("sel", id)


func _process(_d: float) -> void :
	if gw == null or gw.get("hold") == null or gw.player == null or int(gw.hold.kind_of(oid)) == 0:
		close()
		return
	if hud.get("ui24_sheet") != self or int(main.get("mode")) != 0:
		close()
		return
	_sig_t -= _d
	if _sig_t > 0.0:
		return
	_sig_t = 0.25
	var s: String = _state_sig()
	if s != _sig:
		_build()


func _state_sig() -> String:
	var inf: Dictionary = gw.hold.info(oid)
	return "%d|%d|%d|%d|%d" % [_step, int(inf.get("c", 0)), int(inf.get("n", 0)), int(inf.get("in", 0)), _armies().size()]



func _armies() -> Array:
	var out: Array = []
	var r: Rect2i = gw.object_rect(oid)
	var bc: Vector2 = Vector2((r.position + r.size / 2) * GameWorld.CELL)
	for f: Facility in gw.mil.facilities:
		if f.kind != Facility.Kind.BARRACKS or f.country_id != gw.player.id or not AG.army_alive(gw, f):
			continue
		var n: int = int(gw.hold.free_count(f))
		if n <= 0:
			continue
		var fc: Vector2 = gw.army._field_centre(f)
		if not fc.is_finite():
			fc = f.center_px()
		out.append([f, n, int(fc.distance_to(bc) * 2.5)])
	out.sort_custom( func(a: Array, b: Array) -> bool: return int(a[2]) < int(b[2]) or (int(a[2]) == int(b[2]) and (a[0] as Facility).id < (b[0] as Facility).id))
	return out


func _build() -> void :
	_sig = _state_sig()
	for ch: Node in _vb.get_children():
		_vb.remove_child(ch)
		ch.queue_free()
	var hi: bool = int(gw.hold.kind_of(oid)) == 2
	var inf: Dictionary = gw.hold.info(oid)
	var mine: bool = not inf.is_empty() and int(inf["c"]) == gw.player.id
	var foe: bool = not inf.is_empty() and not mine

	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	_vb.add_child(hb)
	hb.add_child(UiKit.icon_rect("icon_city", 26.0))
	var tv: = VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	hb.add_child(tv)
	tv.add_child(UiKit.lbl(Loc.t("ВЫСОТКА") if hi else Loc.t("ДОМ"), 13, UiKit.TITLE, 2, 2))
	var sub: String = ""
	if mine:
		var hf: Facility = inf.get("home")
		sub = Loc.t("ЗАНЯТ: армия №%d · в доме %d/%d") % [hf.army_no if hf != null else 0, int(inf["in"]), int(inf["n"])]
	elif foe:
		sub = "Занят чужими бойцами"
	else:
		sub = Loc.t("Свободен · до %d бойцов · урон по ним −%d%%") % [4, 70 if hi else 60]
	var sl: Label = UiKit.lbl(sub, 10, UiKit.GOLD if mine else UiKit.MUTED, 2, 2)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(sl)
	var xb: Button = UiKit.close_btn(44.0)
	xb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	xb.pressed.connect( func() -> void :
		UiKit.snd("ui_close")
		close())
	hb.add_child(xb)
	var arm: Array = _armies()
	if _step == 1:
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_vb.add_child(row)
		var room: bool = not foe and (inf.is_empty() or int(inf["n"]) < 4)

		var have: bool = (int(gw.hold.free_count(inf.get("home"))) > 0) if mine else not arm.is_empty()
		var ob: Button = UiKit.big(Loc.t("ЗАНЯТЬ") if have or not room else Loc.t("НЕТ СВОБОДНОЙ ПЕХОТЫ"), "green" if room and have else "stone", "icon_occupy", 44.0, 12 if have or not room else 10)
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.disabled = not room or not have
		ob.pressed.connect( func() -> void :
			var a2: Array = _armies()
			if a2.is_empty():
				hud.call("show_toast", "Нет свободной пехоты (стрелки, ПТУР, штурмовики)")
				UiKit.snd("ui_error")
			elif a2.size() == 1 and not mine:
				_go(a2[0][0])
			elif mine:
				_go(inf.get("home"))
			else:
				_step = 2
				_build())
		row.add_child(ob)
		if mine:
			var lb: Button = UiKit.big("ОСТАВИТЬ", "stone", "icon_op_retreat", 44.0, 12)
			lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lb.pressed.connect( func() -> void :
				var id: int = oid
				main.call("_sim", "hold", "leave", [id, gw.player.id], func(r: Variant) -> void :
					if r is String:
						hud.call("show_toast", String(r))
						UiKit.snd("ui_error")
					else:
						hud.call("show_toast", "Бойцы вышли из дома: %d" % int(r))
						UiKit.snd("ui_select"))
				close())
			row.add_child(lb)
		return

	_vb.add_child(UiKit.lbl("КАКАЯ АРМИЯ ЗАЙМЁТ:", 10, UiKit.MUTED, 2, 2))
	for i in mini(4, arm.size()):
		var e: Array = arm[i]
		var f: Facility = e[0]
		var b: Button = UiKit.big(Loc.t("АРМИЯ №%d · %d бойц. · %s") % [f.army_no, int(e[1]), _dist(int(e[2]))], "stone", "icon_infantry", 44.0, 11)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect( func() -> void : _go(f))
		_vb.add_child(b)


func _dist(m: int) -> String:
	return Loc.t("%.1f км") % (float(m) / 1000.0) if m >= 1000 else Loc.t("%d м") % m


func _go(f: Facility) -> void :
	if f == null:
		return
	var id: int = oid
	var r: Rect2i = gw.object_rect(id)
	var at: Vector2 = Vector2((r.position + Vector2i(r.size.x / 2, r.size.y)) * GameWorld.CELL)
	var mn: Node = main
	var hd: Node = hud
	main.call("_sim", "hold", "occupy", [id, f, gw.player.id], func(res: Variant) -> void :
		if res is String:
			hd.call("show_toast", String(res))
			UiKit.snd("ui_error")
		else:
			hd.call("show_toast", Loc.t("Армия №%d: %d бойц. занимают дом") % [f.army_no, int(res)])
			var ov: Variant = mn.get("overlay")
			if ov != null:
				ov.ripple(at, "intercept_cyan")
			UiKit.snd("ui_select"))
	close()
