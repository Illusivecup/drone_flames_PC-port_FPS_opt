extends PanelContainer










signal closed

const C_WAR: = Color("ff6a4d")
const C_PEACE: = Color("a2e35f")
const C_TRUCE: = Color("ffb000")
const C_ALLY: = Color("7cccff")
const C_UNK: = Color("8f8a76")
const C_EMPTY: = Color("3a3b33")
const PAD: float = 8.0
const ROW_H: float = 56.0
const HOLD_T: float = 0.8
const THRESH: Array = [["nap", 15], ["visa", 20], ["defense", 45], ["alliance", 60]]

var m: Node
var gw: GameWorld
var dp: Diplomacy
var me: int = 0
var page: int = -1
var pend_open: bool = false
var from_chip: bool = false
var confirm_kind: String = ""
var max_h: float = 480.0
var vp: Vector2 = Vector2(360, 780)
var col: VBoxContainer
var scroll: ScrollContainer
var inner: VBoxContainer
var scroll_wrap: MarginContainer
var _fade_top: TextureRect
var _fade_bot: TextureRect
var _timers: Array = []
var _chips: Dictionary = {}
var _tick_t: float = 0.0
var hud: Node
var rebuilds: int = 0
var _sig: String = ""
var _live_t: float = 0.0
var _rows: Dictionary = {}
var _closing: bool = false
var _hint_done: bool = false
var _elim0: bool = false
var pg = null
var aid_only: Array = []
var aid_not: Array = []


func setup(main: Node) -> void :
	m = main
	hud = m.hud
	gw = m.world
	dp = gw.diplo
	me = gw.player.id
	name = "DipSheet"
	pg = (load("res://ui/ui24/dip_page.gd") as GDScript).new(self)
	tree_exiting.connect( func() -> void :
		if hud != null and is_instance_valid(hud):
			hud.ui24_closed(self))

	var tabs: Variant = hud.get("tabs")
	if tabs is Array:
		for tb: Variant in tabs:
			if tb is BaseButton:
				(tb as BaseButton).pressed.connect(close_sheet)
	UiKit.ensure()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var st: StyleBox = UiKit.sb("wb_window", PAD, 6)

	st.expand_margin_left = 14.0
	st.expand_margin_right = 14.0
	st.expand_margin_bottom = 14.0
	st.content_margin_left = PAD
	st.content_margin_right = PAD
	st.content_margin_top = 10.0
	st.content_margin_bottom = 10.0 + float(m.hud._safe_margins().y)
	add_theme_stylebox_override("panel", st)
	col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)




func fit(viewport: Vector2, tab_h: float) -> void :
	vp = viewport
	max_h = floorf(vp.y * (0.78 if vp.y < 700.0 else 0.62)) - tab_h
	col.add_theme_constant_override("separation", 2 if vp.y < 700.0 else 4)
	custom_minimum_size.x = vp.x


func compact() -> bool:
	return vp.y < 700.0




func rebuild(keep_scroll: bool = true) -> void :
	var sv: int = scroll.scroll_vertical if keep_scroll and scroll != null and is_instance_valid(scroll) else 0
	rebuilds += 1
	for c: Node in col.get_children():
		col.remove_child(c)
		c.queue_free()
	_timers.clear()
	_chips.clear()
	_rows.clear()
	scroll = null
	if page >= 0:
		var pc: Country = gw.country_by_id(page)
		if pc == null or pc.eliminated:
			page = -1
	if page < 0:
		_build_list()
	else:
		_build_country(page)
	_fit_scroll()
	_sig = _struct_sig()
	if sv > 0 and scroll != null:

		scroll.set_deferred("scroll_vertical", sv)
		var sc: ScrollContainer = scroll
		get_tree().process_frame.connect( func() -> void :
			if is_instance_valid(sc):
				sc.scroll_vertical = sv, CONNECT_ONE_SHOT)




func refresh() -> void :
	if _struct_sig() != _sig:
		rebuild(true)
	else:
		_live_update()



func _struct_sig() -> String:
	if gw.player == null:
		return ""
	if pg != null and page >= 0 and bool(pg.chat_on):
		return "%d|chat%s" % [page, pg.sig()]
	var s: String = "%d|%s|%s|%s|" % [page, pend_open, confirm_kind, gw.player.eliminated]
	for it: Dictionary in dp.pending_for_player():
		s += String(it["id"]) + ","
	s += "|"
	for c: Country in gw.countries:
		if c.id == me:
			continue
		s += "%d:%s:%d:%s:%s%s%s%s%s;" % [c.id, c.eliminated or c.capital_id < 0, dp.get_rel(me, c.id), ",".join(PackedStringArray(dp.treaties_of(me, c.id))), 
			dp.embargoed(me, c.id), dp.embargoed(c.id, me), dp.known.has(c.id), dp.has_passage(me, c.id), dp.has_passage(c.id, me)]
	if page >= 0:
		var rv: int = dp.relation(me, page)
		var reached: int = 0
		for th: Array in THRESH:
			if rv >= int(th[1]):
				reached += 1
		s += "|%d|%s|%s|%s" % [reached, gw.player.money >= 500, Diplomacy.PEACE_MIN_WAR - dp.war_time(me, page) > 0.0, 
			not dp.demand_options(me, page).is_empty()]
		s += pg.sig()
	var net_c: NetSession = m.get("net") as NetSession if m != null else null
	if net_c != null and net_c.chat != null and page < 0:
		s += "|ch:%s" % str(net_c.chat.unread)
	if net_c != null and net_c.chat != null and page >= 0 and not bool(pg.chat_on):
		s += "|chb:%d" % int(net_c.chat.unread.get(page, 0))
	s += _dip2_sig()
	s += _call_sig()
	if dp.get("ally") != null:
		s += "|al:%s:%s:%d" % [str(dp.ally.of), _leave_arm, _kick_arm]
		for a: Dictionary in dp.ally.list.values():
			s += "%s%d%d" % [String(a["name"]), int(a["ci"]), int(a["logo"])]
	if dp.get("react") != null:
		s += "|" + String(dp.react.sig())
	return s



func _live_update() -> void :
	for k: int in _rows:
		var cid: int = page if k == -1 else k
		if cid < 0:
			continue
		var r: Array = _rows[k]
		var rv: int = dp.relation(me, cid)
		var mt: Control = r[0]
		var vl: Label = r[1]
		if is_instance_valid(mt) and int(float(mt.get_meta("v", 0.0))) != rv:
			mt.set_meta("v", float(rv))
			mt.queue_redraw()
		if is_instance_valid(vl):
			var t: String = _signed(rv)
			if vl.text != t:
				vl.text = t
				vl.add_theme_color_override("font_color", _rel_col(rv))



func scroll_area() -> ScrollContainer:
	return scroll if scroll != null and is_instance_valid(scroll) else null


func _fit_scroll() -> void :
	if scroll == null:
		return
	var fixed: float = 0.0
	var n: int = 0
	for c: Node in col.get_children():
		if c != scroll and c != scroll_wrap and c is Control and (c as Control).visible:
			fixed += (c as Control).get_combined_minimum_size().y
			n += 1
	fixed += float(n) * float(col.get_theme_constant("separation")) + 20.0 + float(m.hud._safe_margins().y)
	var want: float = inner.get_combined_minimum_size().y
	if pg != null and page >= 0 and (int(pg.comp) > 0 or bool(pg.chat_on)):
		want = 1000000.0
	scroll.custom_minimum_size.y = clampf(want, 60.0, maxf(60.0, max_h - fixed))
	_update_fades.call_deferred()



func _update_fades() -> void :
	if scroll == null or not is_instance_valid(scroll) or _fade_top == null:
		return
	var mx: float = inner.size.y - scroll.size.y
	_fade_top.visible = scroll.scroll_vertical > 2
	_fade_bot.visible = mx > 2.0 and scroll.scroll_vertical < mx - 2.0


func _header(title_text: String, back: bool) -> void :
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 6)
	hr.custom_minimum_size.y = 40
	col.add_child(hr)
	if back:
		var bb: Button = UiKit.arrow(true)
		bb.pressed.connect( func() -> void : open_list())
		hr.add_child(bb)
	var t: Label = UiKit.lbl(title_text, 18, UiKit.TITLE, 3, 4)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	hr.add_child(t)
	var cb: Button = UiKit.close_btn(UiKit.TOUCH_MIN)
	cb.pressed.connect( func() -> void : close_sheet())
	hr.add_child(cb)


func _new_scroll() -> void :
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll_wrap = MarginContainer.new()
	scroll_wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(scroll_wrap)
	scroll_wrap.add_child(scroll)
	_fade_top = _fade(true)
	_fade_bot = _fade(false)
	scroll_wrap.add_child(_fade_top)
	scroll_wrap.add_child(_fade_bot)
	scroll.get_v_scroll_bar().value_changed.connect( func(_v: float) -> void : _update_fades())
	inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)




func _build_list() -> void :
	_header("ДИПЛОМАТИЯ", false)
	if dp.is_subject(me):
		col.add_child(_my_overlord_line())
	if dp.get("ally") != null and dp.ally.id_of(me) >= 0:
		col.add_child(_ally_row(me))
	var pend: Array = dp.pending_for_player()

	pend.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		var da: int = 0 if String(a["kind"]) == "demand" or int(a.get("stage", 0)) >= 3 else 1
		var db: int = 0 if String(b["kind"]) == "demand" or int(b.get("stage", 0)) >= 3 else 1
		return da < db if da != db else float(a["deadline"]) < float(b["deadline"]))
	if not pend.is_empty():
		col.add_child(_banner(pend))
	_new_scroll()
	if pend_open:
		for it: Dictionary in pend:
			inner.add_child(_pending_card(it))
		var gap: = Control.new()
		gap.custom_minimum_size.y = 4
		inner.add_child(gap)
	var ids: Array = []
	for c: Country in gw.countries:
		if c.id != me and not c.eliminated and c.capital_id >= 0:
			ids.append(c.id)
	var pend_from: Dictionary = {}
	for it: Dictionary in pend:
		pend_from[int(it["from"])] = int(pend_from.get(int(it["from"]), 0)) + 1
	var order: Dictionary = {Diplomacy.Rel.WAR: 1, Diplomacy.Rel.TRUCE: 2, Diplomacy.Rel.ALLIANCE: 3, Diplomacy.Rel.PEACE: 4}
	ids.sort_custom( func(a: int, b: int) -> bool:
		var pa: int = 0 if pend_from.has(a) else 1
		var pb: int = 0 if pend_from.has(b) else 1
		if pa != pb:
			return pa < pb
		var ra: int = int(order[dp.get_rel(me, a)])
		var rb: int = int(order[dp.get_rel(me, b)])
		if ra != rb:
			return ra < rb
		return dp.relation(me, a) > dp.relation(me, b))
	for cid: int in ids:
		inner.add_child(_country_row(cid, int(pend_from.get(cid, 0))))
	var tip: Control = _tip_line()
	if tip != null and not compact():
		col.add_child(tip)


func _banner(pend: Array) -> Button:
	var ult: Dictionary = {}
	for it: Dictionary in pend:
		if (String(it["kind"]) == "demand" or int(it.get("stage", 0)) >= 3) and (ult.is_empty() or float(it["left"]) < float(ult["left"])):
			ult = it
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	var colour: String = "red" if not ult.is_empty() else "gold"
	b.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_" + colour, 8, 4, -1))
	b.add_theme_stylebox_override("hover", UiKit.sb("wb_btn_" + colour, 8, 4, -1))
	b.add_theme_stylebox_override("pressed", UiKit.sb("wb_btn_" + colour + "_p", 8, 4, 1))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UiKit.press_fx(b)
	var hb: HBoxContainer = _fill_box(b, 8, 0)
	hb.add_child(_icon("icon_dip_pending", 24))
	var l: Label = UiKit.lbl(Loc.t("ЖДУТ ОТВЕТА: %d") % pend.size(), 11, UiKit.TEXT, 2, 3)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	if not ult.is_empty():
		var ring: TextureRect = _icon(_ring_name(float(ult["left"]), Diplomacy.DEMAND_TIME), 16)
		hb.add_child(ring)
		var tl: Label = UiKit.lbl(Loc.t("УЛЬТ. %s") % [_mmss(float(ult["left"]))], 11, UiKit.GOLD, 2, 3)
		hb.add_child(tl)
		_timers.append([tl, ring, float(ult["deadline"]), Diplomacy.DEMAND_TIME, "УЛЬТ. "])

	var aw: = Control.new()
	aw.custom_minimum_size = Vector2(14, 14)
	aw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	aw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ar: TextureRect = _icon("wb_arrow_r", 14)
	aw.add_child(ar)
	ar.position = ((Vector2(14, 14) - ar.custom_minimum_size) * 0.5).round()
	ar.pivot_offset = ar.custom_minimum_size * 0.5
	ar.rotation_degrees = 90.0 if pend_open else 0.0
	hb.add_child(aw)
	b.pressed.connect( func() -> void :
		pend_open = not pend_open
		rebuild(false))
	return b


func _country_row(cid: int, n_pend: int) -> Button:
	var row: Dictionary = dp.country_row(me, cid)
	var c: Country = gw.country_by_id(cid)
	var st: int = int(row["rel_state"])
	var known: bool = not (row["persona"] as Dictionary).is_empty()
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 48.0 if compact() else ROW_H)
	b.add_theme_stylebox_override("normal", UiKit.sb("wb_panel_dark", 6, 4))
	b.add_theme_stylebox_override("hover", UiKit.sb("wb_panel_dark", 6, 4))
	b.add_theme_stylebox_override("pressed", UiKit.sb("wb_card", 6, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UiKit.press_fx(b)
	b.pressed.connect( func() -> void : open_country(cid))
	b.disabled = gw.player.eliminated
	var hb: HBoxContainer = _fill_box(b, 6, 1 if compact() else 4)
	hb.add_theme_constant_override("separation", 6)
	var por: Control = _portrait(String((row["persona"] as Dictionary).get("icon", "icon_persona_unknown")) if known else "icon_persona_unknown", st, 36)
	var net_c: NetSession = m.get("net") as NetSession if m != null else null
	var n_chat: int = int(net_c.chat.unread.get(cid, 0)) if net_c != null and net_c.chat != null and not net_c.chat.muted.has(cid) else 0
	if n_pend > 0:

		var pi: TextureRect = UiKit.icon_rect("icon_dip_pending_16" if UiKit.has("icon_dip_pending_16") else "icon_ultimatum", 16)
		pi.position = Vector2(36 - 12, -6)
		por.add_child(pi)
	hb.add_child(por)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(vb)
	var l1: = HBoxContainer.new()
	l1.add_theme_constant_override("separation", 5)
	vb.add_child(l1)
	l1.add_child(_flag(c, Vector2(24, 16)))
	var nm: Label = UiKit.lbl(Loc.name(c.name).to_upper(), 12, UiKit.TEXT, 2, 3)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	l1.add_child(nm)
	var sbd: Control = _subject_badge(cid)
	if sbd != null:
		l1.add_child(sbd)
	l1.add_child(_state_badge(st, cid))
	var l2: = HBoxContainer.new()
	l2.add_theme_constant_override("separation", 4)
	vb.add_child(l2)
	var rv: int = int(row["relation"])
	var meter: Control = _meter(rv, Vector2(100 if vp.x < 400 else 110, 8), false)
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l2.add_child(meter)
	var vl: Label = UiKit.lbl(_signed(rv), 11, _rel_col(rv), 2, 3)
	vl.custom_minimum_size.x = 30
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l2.add_child(vl)
	_rows[cid] = [meter, vl]
	l2.add_child(_trend(int(row["trend"])))
	var sbl: Label = _subject_line(cid)
	if sbl != null:
		sbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sbl.clip_text = true
		sbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l2.add_child(sbl)
	elif known:
		var tr: Array = row["treaties"]
		for k: String in tr:
			l2.add_child(_icon(String(Diplomacy.TREATY_INFO[k]["icon"]), 20))
		if bool(row["embargo_out"]) or bool(row["embargo_in"]):
			l2.add_child(_icon("icon_treaty_embargo", 20))
		if tr.is_empty() and not (bool(row["embargo_out"]) or bool(row["embargo_in"])):
			var nt: Label = UiKit.lbl("нет договоров", 10, UiKit.MUTED, 1)
			l2.add_child(nt)
	else:
		l2.add_child(UiKit.lbl("характер неизвестен", 10, UiKit.MUTED, 1))
	var sp: = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l2.add_child(sp)
	if n_chat > 0:
		var chi: TextureRect = _icon("icon_dip_chat_16" if UiKit.has("icon_dip_chat_16") else "icon_dip_chat", 16)
		chi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chi.name = "ChatUnread"
		chi.add_child(_count_badge(mini(n_chat, 9), Vector2(8, -6)))
		hb.add_child(chi)
	var chev: TextureRect = _icon("wb_arrow_r", 14)
	chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(chev)
	return b


func _tip_line() -> Control:
	var txt: String = ""
	for c: Country in gw.countries:
		if c.is_player or c.eliminated or not dp.known.has(c.id) or gw.econ == null:
			continue
		var sc: Array = gw.econ.scarce_of(c)
		if not sc.is_empty() and not dp.at_war(me, c.id):
			txt = Loc.t("%s: нет %s — продайте им дороже") % [Loc.name(c.name), _res_gen(String(sc[0]))]
			break
	if txt == "":
		txt = "Нажмите на страну: договоры, война и мир"
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_pill", 6, 3))
	p.custom_minimum_size.y = 28
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	p.add_child(hb)
	hb.add_child(_icon("icon_hint", 16))
	var l: Label = UiKit.lbl(txt, 10, UiKit.MUTED, 1)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	UiKit.fit_lbl(l, [10, 9], false)
	hb.add_child(l)
	return p




func _pending_card(it: Dictionary) -> Control:
	if String(it["kind"]) == "demand":
		return _ultimatum_card(it)
	return _offer_card(it)


func _demand_of(it: Dictionary) -> Dictionary:
	var n: int = int(String(it["id"]).substr(1))
	for d: Dictionary in dp.demands:
		if int(d["id"]) == n:
			return d
	return {}


func _ultimatum_card(it: Dictionary) -> Control:
	var d: Dictionary = _demand_of(it)
	var from: Country = gw.country_by_id(int(it["from"]))
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 7))
	var rim: = Panel.new()
	var rs: = StyleBoxFlat.new()
	rs.draw_center = false
	rs.border_color = C_WAR
	rs.set_border_width_all(2)
	rs.set_corner_radius_all(3)
	rim.add_theme_stylebox_override("panel", rs)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rim.offset_left = 2
	rim.offset_top = 2
	rim.offset_right = -2
	rim.offset_bottom = -2
	p.add_child(rim)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	p.add_child(vb)
	var h1: = HBoxContainer.new()
	h1.add_theme_constant_override("separation", 6)
	vb.add_child(h1)
	h1.add_child(_icon("icon_ultimatum", 24))
	var t: Label = UiKit.lbl(Loc.t("УЛЬТИМАТУМ · %s") % [Loc.name(from.name).to_upper()], 11, C_WAR, 2, 3)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	h1.add_child(t)
	var bar: Control = _time_bar(float(it["left"]) / Diplomacy.DEMAND_TIME, Vector2(48, 6))
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h1.add_child(bar)
	var tl: Label = UiKit.lbl(_mmss(float(it["left"])) if float(it["left"]) >= 0.0 else "∞", 11, UiKit.GOLD, 2, 3)
	tl.custom_minimum_size.x = 30
	h1.add_child(tl)
	_timers.append([tl, bar, float(it["deadline"]), Diplomacy.DEMAND_TIME, ""])

	var h2: = HBoxContainer.new()
	h2.add_theme_constant_override("separation", 5)
	vb.add_child(h2)
	h2.add_child(_flag(from, Vector2(24, 16)))
	h2.add_child(UiKit.lbl("Требует", 11, UiKit.TEXT, 1))
	var kind: String = String(d.get("kind", "money"))
	var n: int = int(d.get("n", 0))
	if kind == "money" or kind == "res":
		h2.add_child(UiKit.lbl(str(n), 13, UiKit.GOLD, 2, 3))
		h2.add_child(_icon("res_money" if kind == "money" else String(Economy.RES_ICONS.get(String(d.get("res", "")), "res_metal")), 14))
	else:
		var wl: Label = UiKit.lbl(String(it["text"]).get_slice(".", 0), 10, UiKit.TEXT, 1)
		h2.add_child(wl)
	var sp: = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h2.add_child(sp)
	if kind == "money":
		var have: int = gw.player.money
		h2.add_child(UiKit.lbl(Loc.t("у вас %d → %d") % [have, have - n], 10, UiKit.MUTED if have >= n else C_WAR, 1))
	var h3: = HBoxContainer.new()
	h3.add_theme_constant_override("separation", 6)
	vb.add_child(h3)
	h3.add_child(UiKit.lbl("Отказ →", 11, UiKit.TEXT, 1))
	var war: bool = String(it.get("conseq", "")) == "war"
	h3.add_child(_state_badge(Diplomacy.Rel.WAR if war else -2, int(it["from"])))
	if war and dp.has_treaty(me, int(it["from"]), "nap"):
		h3.add_child(UiKit.lbl("ваш пакт ненападения нарушат", 10, UiKit.MUTED, 1))
	var h4: = HBoxContainer.new()
	h4.add_theme_constant_override("separation", 8)
	vb.add_child(h4)
	var ok: Button = UiKit.big("УСТУПИТЬ", "green", "", 44.0, 12)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect( func() -> void : _answer(String(it["id"]), "accept", p))
	h4.add_child(ok)
	var no: Button = UiKit.big("ОТКАЗАТЬ", "red", "", 44.0, 12)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect( func() -> void : _answer(String(it["id"]), "refuse", p))
	h4.add_child(no)
	if float(it["left"]) < 20.0:
		_pulse(p)
	return p


func _offer_card(it: Dictionary) -> Control:
	if String(it["kind"]) in ["request", "sky", "contract", "contract_cancel"] and pg != null:
		return pg.req_card(it)
	if String(it["kind"]) == "react":
		return _react_card(it)
	if String(it["kind"]) in ["call", "note", "conference", "surrender"]:
		return _dip2_card(it)
	var from: Country = gw.country_by_id(int(it["from"]))
	var kind: String = String(it["kind"])
	var ico: String = String(it["icon"])
	var what: String = ""
	var eff: String = ""
	match kind:
		"offer":
			var want: int = Diplomacy.Rel.TRUCE
			for o: Array in dp.offers:
				if int(o[0]) == int(it["from"]):
					want = int(o[2])
			what = String(Diplomacy.REL_NAMES[want])
			ico = ["icon_rel_peace_24", "icon_rel_war_24", "icon_rel_truce_24", "icon_treaty_alliance"][want]
			eff = Loc.t("Бои стихнут на %s, затем мир") % _mmss(Diplomacy.TRUCE_TIME) if want == Diplomacy.Rel.TRUCE else Loc.t("Война закончится")
		"treaty":
			var n: int = int(String(it["id"]).substr(1))
			for t: Dictionary in dp.t_offers:
				if int(t["id"]) == n and Diplomacy.TREATY_INFO.has(String(t["kind"])):
					what = String(Diplomacy.TREATY_INFO[String(t["kind"])]["short"])
					eff = String(Diplomacy.TREATY_INFO[String(t["kind"])]["effect"])
			if bool(it.get("passage_give", false)):
				what = "ПРОХОД"
				eff = "предлагают пропуск через свою землю"
			if bool(it.get("passage", false)):

				what = "ПРОХОД?"
				var vs: Country = gw.country_by_id(int(it.get("vs", 0)))
				eff = Loc.t("пропустить войска и БПЛА%s") % [((Loc.t(" · война: ") + vs.name) if vs != null else "")]
		"demand":
			var d0: Dictionary = _demand_of(it)
			what = "УЛЬТИМАТУМ"
			ico = "icon_ultimatum"
			var war0: bool = String(it.get("conseq", "")) == "war"
			eff = (Loc.t("требует %d · отказ = %s") % [int(d0.get("n", 0)), Loc.t("война") if war0 else Loc.t("эмбарго")]) if String(d0.get("kind", "")) == "money" else String(it["text"])
		"alliance":
			what = String(it.get("what", "АЛЬЯНС"))
			eff = String(it.get("eff", ""))
		"trade":
			what = "ЗАКАЗ"
			eff = String(it["text"]).substr(String(it["text"]).find(" ") + 1)
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 6, 4))
	if kind == "demand":
		p.add_child(_rim(C_WAR))
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	p.add_child(hb)
	var fr: Control = _frame_icon(ico, 36)
	hb.add_child(fr)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(vb)
	var l1: = HBoxContainer.new()
	l1.add_theme_constant_override("separation", 4)
	vb.add_child(l1)
	l1.add_child(_flag(from, Vector2(18, 12)))
	var t1: Label = UiKit.lbl("%s · %s" % [Loc.name(from.name).to_upper(), Loc.t(what)], 11, UiKit.TEXT, 2, 3)
	t1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t1.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t1.clip_text = true
	l1.add_child(t1)
	var l2: = HBoxContainer.new()
	l2.add_theme_constant_override("separation", 4)
	vb.add_child(l2)
	var tl: Label = UiKit.lbl(_mmss(float(it["left"])), 9, UiKit.GOLD, 2)
	l2.add_child(tl)
	_timers.append([tl, null, float(it["deadline"]), 0.0, ""])
	var el: Label = UiKit.lbl(eff, 9, UiKit.MUTED, 1)
	el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	el.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	el.clip_text = true
	l2.add_child(el)
	var ok: Button = _icon_btn("icon_ok", "green")
	ok.pressed.connect( func() -> void : _answer(String(it["id"]), "accept", p))
	hb.add_child(ok)
	var no: Button = _icon_btn("icon_close", "red")
	no.pressed.connect( func() -> void : _answer(String(it["id"]), "refuse", p))
	hb.add_child(no)
	return p



func _dp(method: String, args: Array, done: Callable) -> void :
	NetSession.sim("diplo", method, args, func(r: Variant) -> void :
		if is_instance_valid(self):
			done.call(_rwhy(r)))


static func _rwhy(r: Variant) -> String:
	if r == null:
		return "Команда не выполнена"
	return String(r) if r is String else ""



func _human_to(cid: int) -> bool:
	var c: Country = gw.country_by_id(cid)
	return c != null and c.is_player and cid != me



func _propose(cid: int, want: int, yes_text: String, no_text: String) -> void :
	var human: bool = _human_to(cid)
	NetSession.sim("diplo", "propose", [me, cid, want], func(r: Variant) -> void :
		if not is_instance_valid(self):
			return
		if human:
			m.hud.show_toast(Loc.t("Предложение отправлено: %s ответит во «Входящих»") % Loc.name(gw.country_by_id(cid).name))
		else:
			m.hud.show_toast(yes_text if r == true else no_text)
		rebuild())


func _answer(id: String, act: String, card: Control) -> void :
	_dp("answer_as", [me, id, act], func(why: String) -> void : _answered(why, act, card))


func _answered(why: String, act: String, card: Control) -> void :
	if not is_instance_valid(card):
		rebuild(true)
		return
	if why != "":
		m.hud.show_toast(why)
		_shake(card)
		return
	m.hud.show_toast(String({"accept": "Принято", "stop": "Обещание дано", "pay": "Компенсация выплачена", "join": "Вступаем в войну", "aid": "Помощь отправлена"}.get(act, "Отказано")))


	if dp.pending_for_player().is_empty() and (from_chip or page < 0):
		get_tree().create_timer(0.4).timeout.connect(close_sheet)
		from_chip = false
	card.pivot_offset = Vector2(card.size.x * 0.5, 0)
	var tw: Tween = card.create_tween().set_parallel(true)
	tw.tween_property(card, "modulate:a", 0.0, 0.14)
	tw.tween_property(card, "scale:y", 0.0, 0.16).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback( func() -> void :
		if is_instance_valid(self) and not _closing and is_instance_valid(card) and card.is_inside_tree():
			rebuild(true))






func _build_country(cid: int) -> void :
	pg.build(cid)


func _treaty_chip(cid: int, k: String, row: Dictionary) -> Button:
	var inf: Dictionary = Diplomacy.TREATY_INFO[k]
	var active: bool = (row["treaties"] as Array).has(k)
	var st: int = int(row["rel_state"])
	var rv: int = int(row["relation"])
	var need: int = int(inf["min_rel"])
	var at_war: bool = st == Diplomacy.Rel.WAR or st == Diplomacy.Rel.TRUCE
	var in_ally: bool = not active and (k == "nap" or k == "defense") and (row["treaties"] as Array).has("alliance")
	var locked: bool = not active and not in_ally and (at_war or rv < need)
	var label: String = String(inf["short"]).trim_suffix(".")
	if k == "nap":
		label = "НЕНАПАД"
	var sub: String = ""
	var sub_col: Color = UiKit.MUTED
	if in_ally:
		sub = "в союзе"
		sub_col = C_ALLY
	elif locked and not at_war:
		sub = Loc.t("от %d") % need
		sub_col = UiKit.GOLD
	var hh: float = 52.0 if compact() else 56.0
	var b: Button = _tile(String(inf["icon"]), label, "slot" if (active or in_ally) else ("disabled" if locked else "stone"), hh, sub, sub_col)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if in_ally:
		b.add_child(_rim(Color(C_ALLY, 0.7)))
		var ac: TextureRect = _corner("icon_rel_ally" if UiKit.has("icon_rel_ally") else "corner_check")
		b.add_child(ac)
	elif active:
		var rim: = Panel.new()
		var rs: = StyleBoxFlat.new()
		rs.draw_center = false
		rs.border_color = C_PEACE
		rs.set_border_width_all(2)
		rs.set_corner_radius_all(3)
		rim.add_theme_stylebox_override("panel", rs)
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(rim)
		b.add_child(_corner("corner_check"))
	elif locked:
		var ic: TextureRect = b.get_node("V/Icon") as TextureRect
		ic.modulate = Color(1, 1, 1, 0.4)
		var lk: TextureRect = _icon("wb_lock", 12)
		lk.name = "Lock"
		b.add_child(lk)
		b.resized.connect( func() -> void : lk.position = Vector2(b.size.x - lk.size.x - 3, 3))
	else:
		b.add_child(_corner("corner_plus"))
		if String(hud.dip_hint_treaty) == k:
			b.add_child(_rim(UiKit.GOLD))
			if not _hint_done:
				_hint_done = true
				( func() -> void :
					await get_tree().process_frame
					if is_instance_valid(b):
						chip_pop(b)).call()
	b.pressed.connect( func() -> void :
		if in_ally:
			_shake(b)
			m.hud.show_toast("%s уже входит в союз" % String(inf["name"]).capitalize())
		elif active:
			confirm_kind = "" if confirm_kind == k else k
			rebuild()
		elif locked:
			_shake(b)
			if st == Diplomacy.Rel.WAR or st == Diplomacy.Rel.TRUCE:
				m.hud.show_toast("Сначала заключите мир")
			else:
				m.hud.show_toast("%s: нужны отношения от %d (сейчас %d)" % [String(inf["name"]).capitalize(), need, rv])
		else:
			if String(hud.dip_hint_treaty) == k:
				hud.dip_hint_treaty = ""
			_dp("propose_treaty", [me, cid, k], func(why: String) -> void :
				if why == "":
					m.hud.show_toast("%s подписан" % String(inf["name"]).capitalize())
					rebuild()
					var nb: Button = _chips.get(k) as Button
					if nb != null:
						chip_pop(nb)
				else:
					m.hud.show_toast(why)
					if Diplomacy.ReqS.result_kind(why) == "offer_sent":
						rebuild()
					elif is_instance_valid(b):
						_shake(b)))
	return b


func _cancel_confirm(cid: int, k: String) -> Control:
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 4))
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	p.add_child(hb)
	var l: Label = UiKit.lbl(Loc.t("Расторгнуть «%s»? −%d к отношениям") % [Loc.t(String(Diplomacy.TREATY_INFO[k]["short"])).trim_suffix(".").to_lower(), int(Diplomacy.CANCEL_PENALTY.get(k, 5))], 10, UiKit.TEXT, 2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	var y: Button = UiKit.big("ДА", "red", "", 44.0, 12)
	y.custom_minimum_size.x = 56
	y.pressed.connect( func() -> void :
		confirm_kind = ""
		_dp("cancel_treaty", [me, cid, k], func(why: String) -> void :
			if why != "":
				m.hud.show_toast(why)
			rebuild()))
	hb.add_child(y)
	var n: Button = UiKit.big("НЕТ", "stone", "", 44.0, 12)
	n.custom_minimum_size.x = 56
	n.pressed.connect( func() -> void :
		confirm_kind = ""
		rebuild())
	hb.add_child(n)
	return p


func _war_buttons(cid: int) -> Array:
	var tb: Button = UiKit.big("ПЕРЕМИРИЕ", "blue", "", 44.0, 11)
	_btn_icon(tb, "icon_rel_truce")
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb.pressed.connect( func() -> void :
		_propose(cid, Diplomacy.Rel.TRUCE, "Перемирие заключено", "Отказ: перемирие им пока не нужно"))
	var left: float = Diplomacy.PEACE_MIN_WAR - dp.war_time(me, cid)
	var pb: Button = UiKit.big(Loc.t("МИР") if left <= 0.0 else Loc.t("МИР · %s") % [_mmss(left)], "green", "", 44.0, 11)
	if left > 0.0:
		_timers.append([pb, null, gw.game_time + left, 0.0, "МИР · "])
	_btn_icon(pb, "icon_rel_peace")
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.disabled = left > 0.0
	pb.pressed.connect( func() -> void :
		_propose(cid, Diplomacy.Rel.PEACE, "Мир заключён", "Отказ: мир им пока не нужен"))
	return [tb, pb]




func _joint_war_block(cid: int, st: int) -> Control:
	if st == Diplomacy.Rel.WAR or st == Diplomacy.Rel.TRUCE or gw.player == null or not dp.has_method("support_targets"):
		return null
	var sup: Array = dp.support_targets(me, cid)
	var asks: Array = []
	if not _can_call(cid):
		for eid: int in gw.player.at_war.keys():
			if eid != cid and not dp.at_war(cid, eid) and gw.country_by_id(eid) != null and not gw.country_by_id(eid).eliminated:
				asks.append(eid)
	if sup.is_empty() and asks.is_empty():
		return null
	var vb: = VBoxContainer.new()
	vb.name = "JointWar"
	vb.add_theme_constant_override("separation", 4)
	vb.add_child(_section("ВОЙНЫ"))
	for i: int in mini(2, sup.size()):
		var eid2: int = int(sup[i])
		var en: String = Loc.name(gw.country_by_id(eid2).name).to_upper()
		var hold: = _hold_bar(Loc.t("ЗА НИХ ПРОТИВ: %s") % en, false, func() -> void :
			if gw.player.eliminated:
				return
			_dp("support_war", [me, cid, eid2], func(why: String) -> void :
				m.hud.show_toast(why if why != "" else Loc.t("Вы вступили в войну с %s на стороне %s") % [Loc.name(gw.country_by_id(eid2).name), Loc.name(gw.country_by_id(cid).name)])
				UiKit.snd("ui_error" if why != "" else "ui_click")
				rebuild()))
		hold.name = "SupportWar%d" % i
		vb.add_child(hold)
	if not sup.is_empty():
		var nl1: Label = UiKit.lbl("Они воюют: удержите, чтобы объявить войну их врагу (+12 к отношениям с ними)", 9, UiKit.MUTED, 1)
		nl1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(nl1)
	for j: int in mini(2, asks.size()):
		var eid3: int = int(asks[j])
		var ab: Button = UiKit.big(Loc.t("ПОЗВАТЬ В ВОЙНУ: %s") % Loc.name(gw.country_by_id(eid3).name).to_upper(), "stone", "", 44.0, 11)
		ab.name = "AskWar%d" % j
		_btn_icon(ab, "icon_dip_call" if UiKit.has("icon_dip_call") else "icon_war")
		ab.clip_text = true
		ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ab.pressed.connect( func() -> void :
			_dp("player_call", [me, cid, eid3], func(why2: String) -> void :
				m.hud.show_toast(why2 if why2 != "" else "%s вступает в войну на вашей стороне" % gw.country_by_id(cid).name)
				rebuild()))
		vb.add_child(ab)
	if not asks.is_empty():
		var nl2: Label = UiKit.lbl("Без договора решают сами: отношения, характер, силы сторон и своя выгода", 9, UiKit.MUTED, 1)
		nl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(nl2)
	return vb




const CALL_ROWS: int = 4


func _call_sig() -> String:
	if page < 0 or not dp.at_war(me, page) or not dp.has_method("call_candidates"):
		return ""
	var s: String = "|cw"
	for aid: int in dp.call_candidates(me, page):
		var o: Dictionary = dp.call_outlook(me, aid, page)
		s += "%d:%s:%s;" % [aid, String(o["ans"]), float(o["wait"]) > 0.0]
	return s




func _call_allies_block(cid: int, st: int) -> Control:
	if st != Diplomacy.Rel.WAR or gw.player == null or gw.player.eliminated or not dp.has_method("call_candidates"):
		return null
	var cand: Array = dp.call_candidates(me, cid)
	var vb: = VBoxContainer.new()
	vb.name = "CallAllies"
	vb.add_theme_constant_override("separation", 4)
	var hh: = HBoxContainer.new()
	hh.add_theme_constant_override("separation", 6)
	vb.add_child(hh)
	hh.add_child(_section("ПОЗВАТЬ СОЮЗНИКОВ"))
	if cand.is_empty():
		var el: Label = UiKit.lbl("Некого звать: нет союзников и друзей (отношения от +30) вне этой войны", 10, UiKit.MUTED, 1)
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(el)
		return vb
	var en: String = gw.country_by_id(cid).name
	for i: int in mini(CALL_ROWS, cand.size()):
		vb.add_child(_call_row(int(cand[i]), cid, en, i))
	if cand.size() > CALL_ROWS:
		vb.add_child(UiKit.lbl(Loc.t("ещё %d — в их карточках") % (cand.size() - CALL_ROWS), 10, UiKit.MUTED, 1))
	return vb


func _call_row(aid: int, eid: int, en: String, i: int) -> Control:
	var c: Country = gw.country_by_id(aid)
	var o: Dictionary = dp.call_outlook(me, aid, eid)
	var ans: String = String(o["ans"])
	var wait: float = float(o["wait"])
	var row: = HBoxContainer.new()
	row.name = "CallRow%d" % i
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size.y = 44
	row.add_child(_flag(c, Vector2(24, 15)))
	var tx: = VBoxContainer.new()
	tx.add_theme_constant_override("separation", 0)
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(tx)
	var nm: Label = UiKit.lbl("%s · %s" % [Loc.name(c.name).to_upper(), dp.call_tie(me, aid)], 11, UiKit.TEXT, 2)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tx.add_child(nm)
	var why: String = String(o["why"])
	var line: String = Loc.t("скорее нет: %s") % [why]
	var lc: Color = Color("ff9a80")
	match ans:
		"join":
			line = "скорее согласится"
			lc = C_PEACE
		"aid":
			line = (Loc.t("в войну не пойдёт (%s), пришлёт помощь") % why) if why != "" else Loc.t("воевать не станет, пришлёт помощь")
			lc = UiKit.GOLD
		"no":
			line = Loc.t("не может: %s") % [why]
			lc = UiKit.DIM
		"human":
			line = Loc.t("игрок — ответит сам за %d с") % int(Diplomacy.CALL_T)
			lc = C_ALLY
		"pending":
			line = "ждём ответа"
			lc = C_ALLY
	var ol: Label = UiKit.lbl(line, 10, lc, 1)
	ol.name = "Outlook"

	ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ol.max_lines_visible = 2
	ol.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	tx.add_child(ol)
	var b: Button = UiKit.big("ПОЗВАТЬ", "red" if ans == "join" else "stone", "", 44.0, 11)
	b.name = "CallBtn"
	b.custom_minimum_size.x = 92
	b.disabled = ans == "no" or ans == "pending" or wait > 0.0
	if wait > 0.0 and ans != "no" and ans != "pending":
		b.text = "ПОЗЖЕ"
		_timers.append([ol, null, gw.game_time + wait, 0.0, "уже просили · снова через "])
	b.pressed.connect( func() -> void :
		if gw.player.eliminated:
			return
		_dp("player_call", [me, aid, eid], func(why2: String) -> void :
			m.hud.show_toast(why2 if why2 != "" else "%s вступает в войну с %s" % [c.name, en])
			UiKit.snd("ui_click" if why2 == "" or Diplomacy.ReqS.result_kind(why2) == "inbox" else "ui_error")
			rebuild()))
	row.add_child(b)
	return row



func _hold_bar(text: String, treachery: bool, done: Callable) -> Control:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 46)
	var base: StyleBox = UiKit.sb("wb_btn_stone_p", 10, 4)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", base)
	b.add_theme_stylebox_override("pressed", base)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var clip: = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.name = "Fill"
	b.add_child(clip)
	var fill: = Panel.new()
	fill.add_theme_stylebox_override("panel", UiKit.sb("wb_btn_red", 10, 4))
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(fill)
	var rim: = Panel.new()
	var rs: = StyleBoxFlat.new()
	rs.draw_center = false
	rs.border_color = Color("b0306a") if treachery else C_WAR
	rs.set_border_width_all(2)
	rs.set_corner_radius_all(3)
	rim.add_theme_stylebox_override("panel", rs)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(rim)
	var hb: = HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	hb.add_child(_icon("icon_rel_war_24", 24))
	var l: Label = UiKit.lbl(text, 13, Color("ffd0c4"), 2, 4)
	hb.add_child(l)
	var hint: Label = UiKit.lbl("удерживайте", 9, Color("ffd0c4"), 1)
	hb.add_child(hint)
	var l_w: float = l.get_combined_minimum_size().x
	var h_w: float = hint.get_combined_minimum_size().x
	b.resized.connect( func() -> void :
		rim.position = Vector2.ZERO
		rim.size = b.size

		if b.size.x > 1.0:
			var room: float = b.size.x - 12.0
			hint.visible = 32.0 + l_w + 8.0 + h_w <= room
			var cut: bool = 32.0 + l_w > room
			l.clip_text = cut
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if cut else TextServer.OVERRUN_NO_TRIMMING
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL if cut else Control.SIZE_FILL
		hb.position = Vector2.ZERO
		hb.size = b.size
		clip.position = Vector2.ZERO
		clip.size = Vector2(clip.size.x, b.size.y)
		fill.size = b.size)
	clip.size = Vector2(0, 46)
	b.set_meta("tw", null)
	b.button_down.connect( func() -> void :
		UiKit.snd_if_held(b)
		var tw: Tween = b.create_tween()
		tw.tween_property(clip, "size:x", b.size.x, HOLD_T * (1.0 - clip.size.x / maxf(1.0, b.size.x))).set_trans(Tween.TRANS_LINEAR)
		tw.tween_callback( func() -> void :
			if b.is_pressed() and is_instance_valid(b) and b.is_visible_in_tree():
				done.call())
		b.set_meta("tw", tw))
	b.button_up.connect( func() -> void :
		var tw0: Variant = b.get_meta("tw")
		if tw0 is Tween and (tw0 as Tween).is_valid():
			(tw0 as Tween).kill()
		var back: Tween = b.create_tween()
		back.tween_property(clip, "size:x", 0.0, 0.12))
	return b




func open_list(expand_pending: bool = false) -> void :
	page = -1
	confirm_kind = ""
	pend_open = expand_pending
	rebuild(false)


func open_country(cid: int) -> void :
	var c: Country = gw.country_by_id(cid)
	if c == null or c.eliminated or c == gw.player or gw.player.eliminated:
		return
	page = cid
	confirm_kind = ""
	aid_open = false
	pg.reset(cid)
	_hint_done = false
	rebuild(false)

	if not sort_children.is_connected(_on_self_sort):
		sort_children.connect(_on_self_sort)
	col.modulate.a = 0.0
	_set_page_slide(24.0)
	var tw: Tween = col.create_tween().set_parallel(true)
	tw.tween_method(_set_page_slide, 24.0, 0.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(col, "modulate:a", 1.0, 0.12)
	pan_to(cid)
	_flash_border(cid)



func pan_to(cid: int) -> void :
	var c: Country = gw.country_by_id(cid)
	if c == null or c.capital_id < 0 or m.cam == null:
		return
	var target: Vector2 = Vector2(gw.cities[c.capital_id].center) * float(GameWorld.CELL)
	await get_tree().process_frame
	if not is_instance_valid(self) or not is_inside_tree() or page != cid:
		return
	var top_y: float = maxf(150.0, float(hud._win_top()))
	var sheet_top: float = hud.holder.global_position.y if hud.holder != null else vp.y - max_h - 60.0
	var vis_c: float = (top_y + maxf(top_y + 40.0, sheet_top)) * 0.5
	var w1: Vector2 = m.cam.screen_to_world(Vector2(vp.x * 0.5, vp.y * 0.5))
	var w2: Vector2 = m.cam.screen_to_world(Vector2(vp.x * 0.5, vis_c))
	m.cam.center_on(target + (w1 - w2))
	m.set("cam_lock", false)




func _flash_border(cid: int) -> void :
	var c: Country = gw.country_by_id(cid)
	if c == null or gw.top == null or not gw.top.has_method("flash_cells") or gw.data == null:
		return
	var d: WorldData = gw.data
	var own: PackedByteArray = d.owners
	var w: int = d.w
	var h: int = d.h
	var cells: Array[Vector2i] = []
	var seen: Dictionary = {}
	var budget: int = 160000
	for city_id: int in c.city_ids:
		if city_id < 0 or city_id >= gw.cities.size():
			continue
		var city: City = gw.cities[city_id]
		var r: int = int(float(city.claim_max) * 1.3) + 3
		var x0: int = maxi(2, city.center.x - r)
		var x1: int = mini(w - 3, city.center.x + r)
		var y0: int = maxi(2, city.center.y - r)
		var y1: int = mini(h - 3, city.center.y + r)
		budget -= (x1 - x0 + 1) * (y1 - y0 + 1)
		if budget < 0:
			break
		for y: int in range(y0, y1 + 1):
			var row: int = y * w
			for x: int in range(x0, x1 + 1):
				var i: int = row + x
				if own[i] != cid:
					continue
				if own[i - 1] != cid or own[i + 1] != cid or own[i - w] != cid or own[i + w] != cid\
				or own[i - 2] != cid or own[i + 2] != cid or own[i - 2 * w] != cid or own[i + 2 * w] != cid:
					if not seen.has(i):
						seen[i] = true
						cells.append(Vector2i(x, y))
	if cells.size() > 0 and cells.size() < 60000:
		gw.top.flash_cells(cells)




func open_anim() -> void :
	modulate.a = 0.0
	UiKit.snd("ui_open")
	var par: Container = get_parent() as Container
	if par != null and not par.sort_children.is_connected(_on_parent_sort):
		par.sort_children.connect(_on_parent_sort)
	_set_slide(24.0)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_method(_set_slide, 24.0, 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)


var _pslide: float = 0.0
var _papplied: float = 0.0


func _set_page_slide(v: float) -> void :
	col.position.x += v - _papplied
	_papplied = v
	_pslide = v


func _on_self_sort() -> void :
	_papplied = 0.0
	if _pslide != 0.0:
		col.position.x += _pslide
		_papplied = _pslide


var _slide: float = 0.0
var _applied: float = 0.0


func _set_slide(v: float) -> void :
	position.y += v - _applied
	_applied = v
	_slide = v


func _on_parent_sort() -> void :
	_applied = 0.0
	if _slide != 0.0:
		position.y += _slide
		_applied = _slide




func open_at(cid: int, expand: bool) -> void :
	_elim0 = gw.player.eliminated
	if cid >= 0 and gw.country_by_id(cid) != null and not gw.country_by_id(cid).eliminated and not _elim0:
		open_country(cid)
	else:
		from_chip = expand
		open_list(expand)
	open_anim()


func close_sheet() -> void :
	if _closing:
		return
	_closing = true
	if pg != null and bool(pg.chat_on):
		pg._chat_close()
	hud.dip_hint_treaty = ""
	hud.ui24_closed(self)
	UiKit.snd("ui_close")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_method(_set_slide, _slide, 24.0, 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback( func() -> void :
		closed.emit()
		if hud.panel == self:
			hud.close_panel()
		else:
			queue_free())



func _exit_tree() -> void :
	if pg != null and bool(pg.chat_on):
		pg._chat_close()



func close() -> void :
	close_sheet()



func chip_pop(b: Control) -> Tween:
	b.pivot_offset = b.size * 0.5
	var tw: Tween = b.create_tween()
	tw.tween_property(b, "scale", Vector2(1.12, 1.12), 0.05)
	tw.tween_property(b, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


func _shake(c: Control) -> void :
	var x0: float = c.position.x
	var tw: Tween = c.create_tween()
	for i in 3:
		tw.tween_property(c, "position:x", x0 + 3.0, 0.03)
		tw.tween_property(c, "position:x", x0 - 3.0, 0.03)
	tw.tween_property(c, "position:x", x0, 0.0)


func _pulse(c: Control) -> void :
	var tw: Tween = c.create_tween().set_loops()
	tw.tween_property(c, "modulate:a", 0.65, 0.45)
	tw.tween_property(c, "modulate:a", 1.0, 0.45)



func _process(delta: float) -> void :
	if not _closing and hud != null and hud.ops_panel != null and hud.ops_panel.visible:
		close_sheet()
		return
	_tick_t += delta
	if _tick_t < 0.25 or _closing:
		return
	_tick_t = 0.0
	_update_fades()
	_live_t += 0.25
	if _live_t >= 1.0:
		_live_t = 0.0
		_live_update()
		if gw.diplo != dp or gw.player == null:
			close_sheet()
			return
		if gw.player.eliminated != _elim0:
			close_sheet()
			return
		if hud.ops_panel != null and hud.ops_panel.visible:
			close_sheet()
			return
		if _struct_sig() != _sig:
			hud._dip_dirty = true
	for t: Array in _timers:
		var left: float = maxf(0.0, float(t[2]) - gw.game_time)
		var l: Variant = t[0]
		if float(t[2]) < 0.0:
			left = maxf(1.0, float(t[3]))
			if l is Label and is_instance_valid(l):
				(l as Label).text = Loc.t("без срока") if t.size() > 5 and bool(t[5]) else Loc.t(String(t[4])) + "∞"
				l = null
		if l is Label and is_instance_valid(l):
			(l as Label).text = Loc.t(String(t[4])) + _mmss(left)
		elif l is Button and is_instance_valid(l):
			(l as Button).text = Loc.t(String(t[4])) + _mmss(left) if left > 0.0 else Loc.t("МИР")
		var bar: Variant = t[1]
		if bar is TextureRect and is_instance_valid(bar):
			UiKit.set_icon(bar as TextureRect, _ring_name(left, float(t[3])), 16)
		elif bar is Control and is_instance_valid(bar):
			(bar as Control).set_meta("v", left / maxf(1.0, float(t[3])))
			(bar as Control).queue_redraw()




func _rim(c: Color) -> Panel:
	var rim: = Panel.new()
	var rs: = StyleBoxFlat.new()
	rs.draw_center = false
	rs.border_color = c
	rs.set_border_width_all(2)
	rs.set_corner_radius_all(3)
	rim.add_theme_stylebox_override("panel", rs)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rim


func _fade(top: bool) -> TextureRect:
	var g: = Gradient.new()
	var bg: = Color("4d513f")
	g.set_color(0, Color(bg, 1.0) if top else Color(bg, 0.0))
	g.set_color(1, Color(bg, 0.0) if top else Color(bg, 1.0))
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 16
	var r: = TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = Vector2(0, 14)
	r.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if top else Control.SIZE_SHRINK_END
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.visible = false
	return r


func _fill_box(b: Control, px: int, py: int) -> HBoxContainer:
	var mc: = MarginContainer.new()
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", px)
	mc.add_theme_constant_override("margin_right", px)
	mc.add_theme_constant_override("margin_top", py)
	mc.add_theme_constant_override("margin_bottom", py)
	b.add_child(mc)
	var hb: = HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 6)
	mc.add_child(hb)
	return hb


func _icon(nm: String, box: float) -> TextureRect:
	var r: TextureRect = UiKit.icon_rect(nm if UiKit.has(nm) else _fallback(nm), box)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r



func _fallback(nm: String) -> String:
	var fb: Dictionary = {"icon_dip_pending": "icon_ultimatum", "icon_rel_war": "icon_war", "icon_rel_war_24": "icon_war", 
		"icon_rel_peace": "icon_peace", "icon_rel_peace_24": "icon_peace", "icon_rel_truce": "icon_truce", "icon_rel_truce_24": "icon_truce", 
		"icon_strength": "icon_score", "icon_goto_map": "icon_center", "corner_plus": "icon_plus", "corner_check": "icon_ok", 
		"icon_dip_aid": "icon_aid", "icon_dip_call": "icon_war", "icon_dip_protest": "icon_ultimatum", "icon_dip_vassal": "icon_treaty_alliance", 
		"icon_dip_puppet": "icon_treaty_alliance", "icon_dip_conf": "icon_peace", "icon_dip_points": "icon_score", 
		"icon_dip_vassal_16": "icon_treaty_alliance", "icon_dip_puppet_16": "icon_treaty_alliance"}
	if nm.begins_with("icon_timer_ring"):
		return "icon_speed"
	return String(fb.get(nm, "icon_info"))


func _ring_name(left: float, total: float) -> String:
	var k: int = clampi(7 - int(floorf(left / maxf(1.0, total) * 8.0)), 0, 7)
	return "icon_timer_ring_%d" % k


func _section(t: String) -> Label:
	var l: Label = UiKit.lbl(t, 10, UiKit.TITLE, 2, 3)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _flag(c: Country, sz: Vector2) -> Control:
	var p: = PanelContainer.new()
	var s: = StyleBoxFlat.new()
	s.bg_color = UiKit.OUTLINE
	s.set_content_margin_all(1)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fl: = TextureRect.new()
	fl.texture = FlagMaker.tex_for(c, sz)
	fl.custom_minimum_size = sz
	fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fl.stretch_mode = TextureRect.STRETCH_SCALE
	fl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(fl)
	return p


func _state_col(st: int) -> Color:
	match st:
		Diplomacy.Rel.WAR:
			return C_WAR
		Diplomacy.Rel.TRUCE:
			return C_TRUCE
		Diplomacy.Rel.ALLIANCE:
			return C_ALLY
		Diplomacy.Rel.PEACE:
			return C_PEACE
	return C_UNK


func _portrait(icon_name: String, st: int, px: float) -> Control:
	var p: = Panel.new()
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s: = StyleBoxFlat.new()
	var sc: Color = _state_col(st) if icon_name != "icon_persona_unknown" else C_UNK
	s.bg_color = sc.darkened(0.78)
	s.border_color = sc.darkened(0.15)
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 0
	p.add_theme_stylebox_override("panel", s)
	var ic: TextureRect = _icon(icon_name, px - 6.0)
	p.add_child(ic)
	p.resized.connect( func() -> void : ic.position = ((p.size - ic.size) * 0.5).round())
	return p


func _frame_icon(icon_name: String, px: float) -> Control:
	var p: = Panel.new()
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_slot", 4))
	var ic: TextureRect = _icon(icon_name, 24)
	p.add_child(ic)
	p.resized.connect( func() -> void : ic.position = ((p.size - ic.size) * 0.5).round())
	return p



func _state_badge(st: int, cid: int) -> Control:
	var p: = PanelContainer.new()
	p.custom_minimum_size = Vector2(64, 20)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var colr: Color = _state_col(st) if st >= 0 else C_TRUCE
	var s: = StyleBoxFlat.new()
	s.bg_color = colr.darkened(0.72)
	s.border_color = colr.darkened(0.1)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 4
	s.content_margin_right = 6
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(hb)
	var ic: String = "icon_rel_peace"
	var txt: String = "МИР"
	match st:
		Diplomacy.Rel.WAR:
			ic = "icon_rel_war"
			txt = "ВОЙНА"
		Diplomacy.Rel.ALLIANCE:
			ic = "icon_rel_ally" if UiKit.has("icon_rel_ally") else "icon_alliance"
			txt = "СОЮЗ"
		Diplomacy.Rel.TRUCE:
			var left: float = float(dp.truce_until.get(Diplomacy.key(me, cid), gw.game_time)) - gw.game_time
			ic = _ring_name(left, Diplomacy.TRUCE_TIME)
			txt = _mmss(left)
			p.set_meta("truce_end", float(dp.truce_until.get(Diplomacy.key(me, cid), gw.game_time)))
		-2:
			ic = "icon_treaty_embargo"
			txt = "ЭМБАРГО"
	var icr: TextureRect = _icon(ic, 16)
	hb.add_child(icr)
	var tl: Label = UiKit.lbl(txt, 10, colr.lightened(0.15), 2, 3)
	hb.add_child(tl)
	if p.has_meta("truce_end"):
		_timers.append([tl, icr, float(p.get_meta("truce_end")), Diplomacy.TRUCE_TIME, ""])
	return p


func _count_badge(n: int, at: Vector2) -> Control:
	var p: = Panel.new()
	var s: = StyleBoxFlat.new()
	s.bg_color = Color("d6331f")
	s.border_color = UiKit.OUTLINE
	s.set_border_width_all(1)
	s.set_corner_radius_all(7)
	p.add_theme_stylebox_override("panel", s)
	p.size = Vector2(14, 14)
	p.position = at
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = UiKit.lbl(str(n), 9, Color.WHITE, 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(14, 14)
	p.add_child(l)
	return p


func _corner(nm: String) -> TextureRect:
	var r: TextureRect = UiKit.icon_rect(nm if UiKit.has(nm) else _fallback(nm), 16)
	r.name = "Corner"
	r.custom_minimum_size = Vector2(16, 16)
	r.size = Vector2(16, 16)
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = Vector2(-4, -4)
	return r


func _trend(t: int) -> TextureRect:
	return _icon(["icon_rel_down", "icon_rel_flat", "icon_rel_up"][clampi(t + 1, 0, 2)], 12)



func _tile(icon_name: String, text: String, style: String, h: float, sub: String = "", sub_col: Color = UiKit.MUTED) -> Button:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n: StyleBox
	var pr: StyleBox
	match style:
		"slot":
			n = UiKit.sb("wb_slot", 2)
			pr = UiKit.sb("wb_slot_pressed", 2)
		"disabled":
			n = UiKit.sb("wb_slot_disabled", 2)
			pr = n
		_:
			n = UiKit.sb("wb_btn_" + style, 2, 2, -1)
			pr = UiKit.sb("wb_btn_" + style + "_p", 2, 2, 1)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", UiKit.sb("wb_btn_stone_p", 2, 2, 1))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UiKit.press_fx(b)
	var vb: = VBoxContainer.new()
	vb.name = "V"
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1 if h < 50 else 3)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)
	var ic: TextureRect = _icon(icon_name, 24)
	ic.name = "Icon"
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ic)
	var l: Label = UiKit.lbl(text, 9, UiKit.TEXT if style != "disabled" else UiKit.DIM, 2, 3)
	l.name = "L"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = 40
	vb.add_child(l)
	if sub != "":
		vb.add_theme_constant_override("separation", 0)
		var sl: Label = UiKit.lbl(sub, 9, sub_col, 2, 3)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.clip_text = true
		sl.custom_minimum_size.x = 40
		vb.add_child(sl)
	b.resized.connect( func() -> void :
		vb.position = Vector2(0, -1)
		vb.size = b.size)
	b.draw.connect( func() -> void : vb.modulate.a = 0.4 if b.disabled else 1.0)
	return b


func _icon_btn(icon_name: String, colour: String) -> Button:
	var b: Button = UiKit.big("", colour, "", 44.0, 12)
	b.custom_minimum_size = Vector2(44, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic: TextureRect = _icon(icon_name, 22)
	b.add_child(ic)
	b.resized.connect( func() -> void : ic.position = ((b.size - ic.size) * 0.5 - Vector2(0, 1)).round())
	return b


func _btn_icon(b: Button, icon_name: String) -> void :
	var t: Texture2D = UiKit.tex(icon_name)
	if t != null:
		b.icon = t
		b.expand_icon = false
		b.add_theme_constant_override("h_separation", 6)




func _meter(v: int, sz: Vector2, ticks: bool) -> Control:
	var c: = Control.new()
	c.custom_minimum_size = Vector2(sz.x, sz.y + (16.0 if ticks else 0.0) + (4.0 if ticks else 0.0))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("v", float(v))
	var bh: float = sz.y
	c.draw.connect( func() -> void :
		var val: float = float(c.get_meta("v"))
		var w: float = c.size.x
		var y0: float = 4.0 if ticks else 0.0
		c.draw_rect(Rect2(0, y0, w, bh), UiKit.OUTLINE)
		var iw: float = w - 2.0
		var gap: float = 1.0
		var segw: float = (iw - gap * 19.0) / 20.0
		var nfill: int = ceili(absf(val) / 10.0 - 0.001)
		for i in 20:
			var x: float = 1.0 + float(i) * (segw + gap)
			var on: bool = (val < 0.0 and i < 10 and i >= 10 - nfill) or (val > 0.0 and i >= 10 and i - 10 < nfill)
			var base: Color = C_EMPTY
			var hl: Color = Color("4a4b42")
			var sh: Color = Color("2c2d27")
			if on and i < 10:
				base = Color("e8553f")
				hl = Color("ff8f70")
				sh = Color("a83a2e")
			elif on:
				base = Color("8fdc4f")
				hl = Color("c8f590")
				sh = Color("5aa83c")
			var r: = Rect2(roundf(x), y0 + 1.0, roundf(segw), bh - 2.0)
			c.draw_rect(r, base)
			c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0 if bh < 10.0 else 2.0)), hl)
			c.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), sh)
		var cx: float = roundf(w * 0.5)
		c.draw_rect(Rect2(cx - 1.0, y0 - 2.0, 2.0, bh + 4.0), UiKit.TEXT)
		if ticks:
			var f: Font = UiKit.f_bold
			for th: Array in THRESH:
				var tv: float = float(th[1])
				var tx: float = roundf(cx + tv / 100.0 * (w * 0.5 - 1.0))
				var reached: bool = val >= tv
				var tc: Color = UiKit.GREEN if reached else UiKit.MUTED
				c.draw_rect(Rect2(tx, y0 - 2.0, 1.0, bh + 5.0), tc)
				var s: String = str(int(tv))
				var tw: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
				var lx: float = tx - tw * 0.5
				if int(tv) == 15:
					lx = tx - tw - 3.0
				elif int(tv) == 20:
					lx = tx + 3.0
				c.draw_string(f, Vector2(roundf(lx), y0 + bh + 13.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tc)

			var px: float = roundf(cx + clampf(val, -100.0, 100.0) / 100.0 * (w * 0.5 - 1.0))
			c.draw_colored_polygon(PackedVector2Array([Vector2(px - 4, 0), Vector2(px + 4, 0), Vector2(px, y0 + 1.0)]), UiKit.GOLD)
			c.draw_string(f, Vector2(2, y0 + bh + 13.0), "−100", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiKit.DIM)
			var e: String = "+100"
			c.draw_string(f, Vector2(w - f.get_string_size(e, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x - 2.0, y0 + bh + 13.0), e, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiKit.DIM))
	return c


func _plain_bar(frac: float, sz: Vector2, colr: Color) -> Control:
	var c: = Control.new()
	c.custom_minimum_size = sz
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect( func() -> void :
		c.draw_rect(Rect2(Vector2.ZERO, c.size), UiKit.OUTLINE)
		c.draw_rect(Rect2(1, 1, c.size.x - 2, c.size.y - 2), C_EMPTY)
		var fw: float = maxf(2.0, roundf((c.size.x - 2.0) * clampf(frac, 0.0, 1.0)))
		c.draw_rect(Rect2(1, 1, fw, c.size.y - 2), colr)
		c.draw_rect(Rect2(1, 1, fw, 1), colr.lightened(0.35)))
	return c


func _time_bar(frac: float, sz: Vector2) -> Control:
	var c: = Control.new()
	c.custom_minimum_size = sz
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("v", frac)
	c.draw.connect( func() -> void :
		var f: float = clampf(float(c.get_meta("v")), 0.0, 1.0)
		c.draw_rect(Rect2(Vector2.ZERO, c.size), UiKit.OUTLINE)
		c.draw_rect(Rect2(1, 1, c.size.x - 2, c.size.y - 2), C_EMPTY)
		var col2: Color = C_TRUCE if f > 0.27 else C_WAR
		c.draw_rect(Rect2(1, 1, roundf((c.size.x - 2) * f), c.size.y - 2), col2)
		c.draw_rect(Rect2(1, 1, roundf((c.size.x - 2) * f), 1), col2.lightened(0.4)))
	return c


static func _mmss(t: float) -> String:
	var s: int = maxi(0, ceili(t))
	return "%d:%02d" % [s / 60, s % 60]


static func _signed(v: int) -> String:
	return ("+%d" % v) if v > 0 else ("−%d" % absi(v) if v < 0 else "0")


static func _rel_col(v: int) -> Color:
	return C_PEACE if v >= 15 else (C_WAR if v <= -15 else UiKit.TEXT)


static func _x(v: float) -> String:
	return str(roundi(v)) if v >= 3.0 else Loc.dec(String.num(v, 1))


static func _res_gen(r: String) -> String:
	return Loc.t(String(LOC_RES_GEN.get(r, r)))


const LOC_RES_GEN: Dictionary = {"oil": "нефти", "titanium": "титана", "metal": "металла", "precious": "драгметаллов", "wood": "дерева", 
	"food": "еды", "goods": "товаров", "uranium": "урана"}




const C_GOLD2: = Color("ffd75e")
var aid_open: bool = false
var aid_what: String = "money"
var aid_n: int = 500
var _aid_l: Label = null
var _aid_v: Label = null
var _aid_send: Button = null


func _dip2_sig() -> String:
	var s: String = "|%s|%s|%s" % [aid_open, aid_what, dp.subject_tag(me)]
	for c: Country in gw.countries:
		if c.id != me:
			s += "%d:%s;" % [c.id, dp.subject_tag(c.id)]
	if page >= 0:
		var o: Dictionary = dp.subject_options(me, page)
		s += "|%s%s%s%s|%s" % [o["status"], o["can_offer"], o["can_ult"], o["why"], _can_call(page)]
	return s



func _dip2_card(it: Dictionary) -> Control:
	var kind: String = String(it["kind"])
	var from: Country = gw.country_by_id(int(it["from"]))
	var rimc: Color = C_WAR if kind == "call" else (C_TRUCE if kind == "note" else C_GOLD2)
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 6))
	p.add_child(_rim(rimc))
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	p.add_child(vb)
	var h1: = HBoxContainer.new()
	h1.add_theme_constant_override("separation", 6)
	vb.add_child(h1)
	h1.add_child(_icon(String(it["icon"]), 24))
	var title: String = {"call": "ПРИЗЫВ К ВОЙНЕ", "note": "НОТА ПРОТЕСТА", "conference": "КОНФЕРЕНЦИЯ", "surrender": "КАПИТУЛЯЦИЯ"}.get(kind, "")
	if kind == "call" and bool(it.get("ask", false)):
		title = "ЗОВУТ В ВОЙНУ"
	var t: Label = UiKit.lbl("%s · %s" % [title, Loc.name(from.name).to_upper() if from != null else ""], 11, rimc, 2, 3)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h1.add_child(t)
	var bar: Control = _time_bar((float(it["left"]) if float(it["left"]) >= 0.0 else float(it.get("total", 60.0))) / maxf(1.0, float(it.get("total", 60.0))), Vector2(44, 6))
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h1.add_child(bar)
	var tl: Label = UiKit.lbl(_mmss(float(it["left"])) if float(it["left"]) >= 0.0 else "∞", 11, UiKit.GOLD, 2, 3)
	tl.custom_minimum_size.x = 30
	h1.add_child(tl)
	_timers.append([tl, bar, float(it["deadline"]), float(it.get("total", 60.0)), ""])
	var h2: = HBoxContainer.new()
	h2.add_theme_constant_override("separation", 5)
	vb.add_child(h2)
	if kind == "call" or kind == "note":
		var vs: Country = gw.country_by_id(int(it.get("vs", 0)))
		if from != null:
			h2.add_child(_flag(from, Vector2(21, 14)))
		h2.add_child(UiKit.lbl(Loc.t("воюет с") if kind == "call" else Loc.t("нет помощи против"), 10, UiKit.TEXT, 1))
		if vs != null:
			h2.add_child(_flag(vs, Vector2(21, 14)))
			var vl: Label = UiKit.lbl(Loc.name(vs.name).to_upper(), 10, C_WAR, 2, 3)
			vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vl.clip_text = true
			vl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			h2.add_child(vl)
		if kind == "note":
			var n: int = int(it.get("n", 1))
			for i in 3:
				var pip: = ColorRect.new()
				pip.custom_minimum_size = Vector2(8, 8)
				pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				pip.color = C_WAR if i < n else C_EMPTY
				h2.add_child(pip)
	elif kind == "surrender":
		if from != null:
			h2.add_child(_flag(from, Vector2(21, 14)))
		var sl: Label = UiKit.lbl("сдаётся: принять — и делить землю", 10, UiKit.TEXT, 1)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.clip_text = true
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h2.add_child(sl)
	else:
		var cf: Dictionary = dp.conf.conf_for_player() if dp.conf != null else {}
		var pts: int = dp.conf.points_left(cf, me) if not cf.is_empty() else 0
		h2.add_child(_icon("icon_dip_points", 14))
		h2.add_child(UiKit.lbl(Loc.t("%d очк.") % pts, 11, C_GOLD2, 2, 3))
		var cl: Label = UiKit.lbl(Loc.t("· %d террит. на кону") % (cf.get("terr", []) as Array).size(), 10, UiKit.TEXT, 1)
		cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(cl)
	if kind == "note" and not compact():
		var ln: Label = UiKit.lbl("3 отказа подряд — союз разорван", 9, UiKit.MUTED, 1)
		vb.add_child(ln)
	var h3: = HBoxContainer.new()
	h3.add_theme_constant_override("separation", 6)
	vb.add_child(h3)
	for o: Dictionary in it["options"]:
		var act: String = String(o["act"])
		var lab: String = String(o["label"])
		var colr: String = {"join": "red", "aid": "green", "open": "gold", "accept": "green"}.get(act, "stone")
		if act == "aid":
			lab = Loc.t("ПОМОЧЬ · %d") % clampi(int(float(gw.player.money) * 0.15 / 100.0) * 100, 500, 3000)
		var b: Button = UiKit.big(lab, colr, "", 44.0, 11)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if act == "open":
			_btn_icon(b, "icon_dip_conf")
			b.pressed.connect( func() -> void : _open_conference(int(String(it["id"]).substr(1))))
		else:
			b.pressed.connect( func() -> void : _answer(String(it["id"]), act, p))
		h3.add_child(b)
	if float(it["left"]) < 15.0:
		_pulse(p)
	return p



func _subject_badge(cid: int) -> Control:
	if not dp.is_subject(cid):
		return null
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pup: bool = dp.subject_kind(cid) == "puppet"
	hb.add_child(_icon("icon_dip_puppet_16" if pup else "icon_dip_vassal_16", 16))
	return hb



func _subject_line(cid: int) -> Label:
	if not dp.is_subject(cid):
		return null
	var pup: bool = dp.subject_kind(cid) == "puppet"
	var ov: int = dp.subject_of(cid)
	var t: String = (Loc.t("ВАША МАРИОНЕТКА") if pup else Loc.t("ВАШ ВАССАЛ")) if ov == me else "%s · %s" % [Loc.t("МАРИОНЕТКА") if pup else Loc.t("ВАССАЛ"), _cname_up(ov)]
	return UiKit.lbl(t, 9, C_GOLD2, 2, 3)



func _my_overlord_line() -> Control:
	var ov: int = dp.subject_of(me)
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 32
	b.add_theme_stylebox_override("normal", UiKit.sb("wb_pill", 6, 3))
	b.add_theme_stylebox_override("hover", UiKit.sb("wb_pill", 6, 3))
	b.add_theme_stylebox_override("pressed", UiKit.sb("wb_pill", 6, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect( func() -> void : open_country(ov))
	var hb: HBoxContainer = _fill_box(b, 6, 2)
	var pup: bool = dp.subject_kind(me) == "puppet"
	hb.add_child(_icon("icon_dip_puppet_16" if pup else "icon_dip_vassal_16", 16))
	var l: Label = UiKit.lbl(Loc.t("ВЫ — %s %s · дань %d %%") % [Loc.t("МАРИОНЕТКА") if pup else Loc.t("ВАССАЛ"), _cname_up(ov), roundi(float(Diplomacy.TRIBUTE.get(dp.subject_kind(me), 0.1)) * 100.0)], 10, C_GOLD2, 2, 3)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hb.add_child(l)
	hb.add_child(_icon("wb_arrow_r", 12))
	return b


func _cname_up(id: int) -> String:
	var c: Country = gw.country_by_id(id)
	return Loc.name(c.name).to_upper() if c != null else "?"




func _subject_block(cid: int) -> Control:
	var o: Dictionary = dp.subject_options(me, cid)
	var st: String = String(o["status"])
	var vb: = VBoxContainer.new()
	vb.name = "SubjectBlock"
	vb.add_theme_constant_override("separation", 3)
	var hh: = HBoxContainer.new()
	hh.add_theme_constant_override("separation", 5)
	vb.add_child(hh)
	hh.add_child(_section("ВАССАЛИТЕТ"))
	var ratio: float = float(o["ratio"])
	match st:
		"ours", "theirs":
			var pup: bool = String(o["kind"]) == "puppet"
			var p: = PanelContainer.new()
			p.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 5))
			p.add_child(_rim(C_GOLD2 if st == "ours" else C_TRUCE))
			vb.add_child(p)
			var hb: = HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			p.add_child(hb)
			hb.add_child(_icon("icon_dip_puppet" if pup else "icon_dip_vassal", 28))
			var v2: = VBoxContainer.new()
			v2.add_theme_constant_override("separation", 2)
			v2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(v2)
			var kn: String = Loc.t("МАРИОНЕТКА") if pup else Loc.t("ВАССАЛ")
			var tl: Label = UiKit.lbl((Loc.t("ВАШ %s") % [kn] if not pup else Loc.t("ВАША МАРИОНЕТКА")) if st == "ours" else Loc.t("ВЫ — %s") % kn, 11, C_GOLD2 if st == "ours" else C_TRUCE, 2, 3)
			v2.add_child(tl)
			v2.add_child(UiKit.lbl(Loc.t("дань %d %% дохода %s") % [roundi(float(o["tribute"]) * 100.0), Loc.t("вам") if st == "ours" else Loc.t("им")], 10, UiKit.TEXT, 1))
			if st == "ours":
				var lr: = HBoxContainer.new()
				lr.add_theme_constant_override("separation", 4)
				v2.add_child(lr)
				lr.add_child(UiKit.lbl("свобода", 9, UiKit.MUTED, 1))
				var lb: Control = _plain_bar(float(o["liberty"]) / 100.0, Vector2(60, 8), C_WAR if float(o["liberty"]) > 70.0 else C_TRUCE)
				lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				lr.add_child(lb)
				lr.add_child(UiKit.lbl(Loc.pct(roundi(float(o["liberty"]))), 9, UiKit.TEXT, 2))
				var rb: Button = UiKit.big("ОТПУСТИТЬ", "stone", "", 44.0, 10)
				rb.custom_minimum_size.x = 88
				rb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				rb.pressed.connect( func() -> void :
					_dp("release_subject", [me, cid], func(why: String) -> void :
						m.hud.show_toast(why if why != "" else "Отпущен: +20 к отношениям")
						rebuild()))
				hb.add_child(rb)
			else:
				var fb: Button = UiKit.big("СВОБОДА", "red", "", 44.0, 10)
				fb.custom_minimum_size.x = 84
				fb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				fb.pressed.connect( func() -> void :
					confirm_kind = "" if confirm_kind == "free" else "free"
					rebuild())
				hb.add_child(fb)
				if confirm_kind == "free":
					vb.add_child(_dip2_confirm(Loc.t("Объявить независимость? %s") % (Loc.t("Они сильнее ×%s — скорее всего война") % _x(1.0 / maxf(0.01, ratio)) if ratio < 0.77 else Loc.t("Они могут ответить войной")), "ДА", func() -> void :
						confirm_kind = ""
						_dp("seek_independence", [me], func(r: String) -> void :
							m.hud.show_toast(r if r != "" else Loc.t("Вы независимы"))
							rebuild())))
			return vb
		"other":
			var ol: Label = UiKit.lbl(String(o["why"]) + (Loc.t(" — договоры через них") if dp.subject_kind(cid) == "puppet" else ""), 10, UiKit.MUTED, 1)
			ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(ol)
			return vb
	if String(o["why"]) != "":
		var wl: Label = UiKit.lbl(String(o["why"]), 10, UiKit.MUTED, 1)
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(wl)
		return vb
	var war: bool = dp.at_war(me, cid)
	var friend: bool = dp.allied(me, cid) or dp.has_treaty(me, cid, "defense")
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	var hh2: float = 52.0 if compact() else 56.0
	if not war:
		var rv: int = dp.relation(cid, me)
		var ok_rel: bool = rv >= Diplomacy.SUBJ_OFFER_REL
		var ob: Button = _tile("icon_dip_vassal", "ПРЕДЛОЖИТЬ", "stone" if ok_rel else "disabled", hh2, Loc.t("отн. от %d") % Diplomacy.SUBJ_OFFER_REL, C_PEACE if ok_rel else UiKit.GOLD)
		ob.pressed.connect( func() -> void :
			_dp("propose_subject", [me, cid, "vassal", false], func(why: String) -> void :
				m.hud.show_toast(why if why != "" else "Согласны: теперь это ваш вассал")
				if why != "" and is_instance_valid(ob):
					_shake(ob)
				rebuild()))
		row.add_child(ob)
	for k: String in ["vassal", "puppet"]:
		if friend or (war and _human_to(cid)):
			break
		var need: float = float(o["need_v" if k == "vassal" else "need_p"])
		var ok: bool = ratio >= need
		var lab: String = (Loc.t("СДАТЬСЯ: ") if war else "") + (Loc.t("ВАССАЛ!") if k == "vassal" else Loc.t("МАРИОН.!"))
		if war:
			lab = Loc.t("ВАССАЛ?") if k == "vassal" else Loc.t("МАРИОН.?")
		var tb: Button = _tile("icon_dip_vassal" if k == "vassal" else "icon_dip_puppet", lab, "red" if ok else "stone", hh2, Loc.t("нужно ×%s") % _x(need), C_PEACE if ok else C_WAR)
		tb.pressed.connect( func() -> void :
			if war:
				_dp("propose_subject", [me, cid, k, true], func(why2: String) -> void :
					m.hud.show_toast(why2 if why2 != "" else "Сдались: теперь %s" % ("ваш вассал" if k == "vassal" else "ваша марионетка"))
					rebuild())
				return
			confirm_kind = "" if confirm_kind == "ult_" + k else "ult_" + k
			rebuild())
		row.add_child(tb)
	if confirm_kind.begins_with("ult_"):
		var k2: String = confirm_kind.substr(4)
		vb.add_child(_dip2_confirm(Loc.t("Ультиматум: стать вашим %s. Отказ — ВОЙНА") % (Loc.t("вассалом") if k2 == "vassal" else Loc.t("марионеткой")), "ОТПРАВИТЬ", func() -> void :
			confirm_kind = ""
			_dp("propose_subject", [me, cid, k2, true], func(why3: String) -> void :
				m.hud.show_toast(why3 if why3 != "" else Loc.t("Уступили: %s") % (Loc.t("ваш вассал") if k2 == "vassal" else Loc.t("ваша марионетка")))
				rebuild())))
	return vb


func _dip2_confirm(text: String, yes: String, done: Callable) -> Control:
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 4))
	p.add_child(_rim(C_WAR))
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	p.add_child(hb)
	var l: Label = UiKit.lbl(text, 10, UiKit.TEXT, 2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	var y: Button = UiKit.big(yes, "red", "", 44.0, 11)
	y.custom_minimum_size.x = 64
	y.pressed.connect(done)
	hb.add_child(y)
	var n: Button = UiKit.big("НЕТ", "stone", "", 44.0, 11)
	n.custom_minimum_size.x = 52
	n.pressed.connect( func() -> void :
		confirm_kind = ""
		rebuild())
	hb.add_child(n)
	return p



func _can_call(cid: int) -> bool:
	var p: Country = gw.player
	if p == null or p.at_war.is_empty() or dp.at_war(me, cid) or dp.truce_on(me, cid):
		return false
	if not (dp.allied(me, cid) or dp.has_treaty(me, cid, "defense") or dp.subject_of(cid) == me or (dp.get("ally") != null and dp.ally.same(me, cid))):
		return false
	for eid: int in p.at_war.keys():
		if not dp.at_war(cid, eid):
			return true
	return false




func _aid_opts(cid: int) -> Array:
	var all: Array = dp.aid_options(me, cid)
	if aid_only.is_empty() and aid_not.is_empty():
		return all
	return all.filter( func(o: Dictionary) -> bool:
		var w: String = String(o["what"])
		return (aid_only.is_empty() or aid_only.has(w)) and not aid_not.has(w))


func _aid_opt(cid: int) -> Dictionary:
	for o: Dictionary in _aid_opts(cid):
		if String(o["what"]) == aid_what:
			return o
	return {}


func _aid_picker(cid: int) -> Control:
	var p: = PanelContainer.new()
	p.name = "AidPicker"
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 5))
	p.add_child(_rim(C_PEACE))


	var mg: = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		mg.add_theme_constant_override("margin_" + side, 4 if side == "left" or side == "right" else 2)
	p.add_child(mg)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	mg.add_child(vb)
	var h0: = HBoxContainer.new()
	h0.add_theme_constant_override("separation", 5)
	vb.add_child(h0)
	h0.add_child(_icon("icon_dip_aid", 20))
	var c: Country = gw.country_by_id(cid)
	var tl: Label = UiKit.lbl(Loc.t("ПОМОЩЬ → %s") % Loc.name(c.name).to_upper(), 11, C_PEACE, 2, 3)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.clip_text = true
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiKit.fit_lbl(tl, [11, 10, 9], false)
	h0.add_child(tl)
	_aid_v = UiKit.lbl("", 9, UiKit.MUTED, 1)
	h0.add_child(_aid_v)

	var chips: = GridContainer.new()
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 4)
	vb.add_child(chips)
	var opts: Array = _aid_opts(cid)
	var n_chip: int = 0
	for oc: Dictionary in opts:
		if String(oc["what"]) == "money" or int(oc["have"]) > 0:
			n_chip += 1
	chips.columns = maxi(1, n_chip if n_chip <= 6 else ceili(n_chip / 2.0))
	var have_sel: bool = false
	for o: Dictionary in opts:
		if String(o["what"]) == aid_what:
			have_sel = true
	if not have_sel:
		aid_what = "money"
	for o2: Dictionary in opts:
		var w: String = String(o2["what"])
		if w != "money" and int(o2["have"]) <= 0:
			continue
		var sel: bool = w == aid_what
		var can: bool = int(o2["max"]) > 0
		var b: Button = _tile(String(o2["icon"]), _short_n(int(o2["have"])), "gold" if sel else ("stone" if can else "disabled"), 44)
		b.custom_minimum_size.x = 40
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = String(o2["label"])
		b.pressed.connect( func() -> void :
			if not can:
				m.hud.show_toast("%s: %s" % [String(o2["label"]).capitalize(), String(o2["why"]) if String(o2["why"]) != "" else "нечего отправить"])
				_shake(b)
				return
			aid_what = w
			aid_n = _aid_default(o2)
			rebuild())
		chips.add_child(b)

	var o3: Dictionary = _aid_opt(cid)
	var h2: = HBoxContainer.new()
	h2.add_theme_constant_override("separation", 4)
	vb.add_child(h2)
	var mn: Button = _icon_btn("icon_minus", "stone")
	h2.add_child(mn)
	var av: = VBoxContainer.new()
	av.add_theme_constant_override("separation", 0)
	av.alignment = BoxContainer.ALIGNMENT_CENTER
	av.custom_minimum_size.x = 64
	h2.add_child(av)
	_aid_l = UiKit.lbl("", 14, UiKit.TEXT, 3, 4)
	_aid_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av.add_child(_aid_l)
	var an: Label = UiKit.lbl(String(o3.get("label", "")), 9, UiKit.MUTED, 2, 3)
	an.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av.add_child(an)
	var pl: Button = _icon_btn("icon_plus", "stone")
	h2.add_child(pl)
	var mx: Button = UiKit.big("ВСЁ", "stone", "", 44.0, 10)
	mx.custom_minimum_size.x = 44
	h2.add_child(mx)
	_aid_send = UiKit.big("ОТПРАВИТЬ", "green", "", 44.0, 11)
	_aid_send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h2.add_child(_aid_send)
	var step: int = _aid_step(o3)
	mn.pressed.connect( func() -> void : _aid_set(cid, aid_n - step))
	pl.pressed.connect( func() -> void : _aid_set(cid, aid_n + step))
	mx.pressed.connect( func() -> void : _aid_set(cid, int(_aid_opt(cid).get("max", 0))))
	_aid_send.pressed.connect( func() -> void :
		var sent_n: int = aid_n
		_dp("transfer", [me, cid, aid_what, aid_n], func(why: String) -> void :
			if why != "":
				m.hud.show_toast(why)
				if is_instance_valid(_aid_send):
					_shake(_aid_send)
				return
			UiKit.snd("ui_click")
			m.hud.show_toast("Отправлено: %s ×%d — отношения растут" % [String(o3.get("label", "")).to_lower(), sent_n])
			aid_n = mini(aid_n, int(_aid_opt(cid).get("max", 0)))
			rebuild()))
	_aid_set(cid, aid_n)
	return p


func _aid_step(o: Dictionary) -> int:
	if String(o.get("what", "")) == "money":
		return 500 if int(o.get("max", 0)) > 4000 else 100
	return int(o.get("step", 1))


func _aid_default(o: Dictionary) -> int:
	if String(o["what"]) == "money":
		return clampi(int(float(o["max"]) * 0.15 / 100.0) * 100, mini(100, int(o["max"])), int(o["max"]))
	return mini(int(o["max"]), maxi(1, int(o["step"]) * 2))


func _aid_set(cid: int, n: int) -> void :
	var o: Dictionary = _aid_opt(cid)
	var mx: int = int(o.get("max", 0))
	aid_n = clampi(n, mini(1, mx), mx)
	if _aid_l != null and is_instance_valid(_aid_l):
		_aid_l.text = _short_n(aid_n) if String(o.get("what", "")) == "money" else "×%d" % aid_n
	if _aid_v != null and is_instance_valid(_aid_v):
		var val: int = int(o.get("each", 1)) * aid_n
		var gain: int = clampi(val / 80, 2, 25)
		if dp.relation(me, cid) > 40:
			gain = maxi(1, gain / 2)
		_aid_v.text = Loc.t("≈%s · отн. +%d") % [_short_n(val), gain] if aid_n > 0 else ""
	if _aid_send != null and is_instance_valid(_aid_send):
		_aid_send.disabled = aid_n <= 0


static func _short_n(v: int) -> String:
	if v >= 10000:
		return Loc.t("%dК") % (v / 1000)
	if v >= 1000:
		return Loc.t("%sК") % Loc.num(float(v) / 1000.0).trim_suffix(",0").trim_suffix(".0")
	return str(v)





func _surrender_tile(cid: int) -> Button:
	if dp.conf == null:
		return null
	var ok: Dictionary = dp.conf.can_demand_surrender(me, cid)
	if not bool(ok["ok"]):
		return null
	var b: Button = _tile("icon_dip_conf", "КАПИТУЛ.?", "gold", 44)
	b.name = "SurrenderTile"
	b.pressed.connect( func() -> void :
		NetSession.sim("diplo.conf", "demand_surrender", [me, cid], func(r: Variant) -> void :
			if not is_instance_valid(self):
				return
			var why: String = _rwhy(r)
			if why != "":
				m.hud.show_toast(why)
				if is_instance_valid(b):
					_shake(b)
				rebuild()
				return
			UiKit.snd("ui_capture")
			var cf: Dictionary = dp.conf.conf_for_player()
			if not cf.is_empty():
				_open_conference(int(cf["id"]))
			else:
				m.hud.show_toast("Капитуляция: земля поделена")
			rebuild()))
	return b



func _open_conference(conf_id: int) -> void :
	var scr: Script = load("res://ui/ui24/conference_sheet.gd") as Script
	if scr == null or dp.conf == null or not dp.conf.has_conf(conf_id):
		m.hud.show_toast("Конференция закончилась")
		rebuild()
		return
	_closing = true
	hud.ui24_closed(self)
	scr.call("open_for", m, conf_id)




const REACT_COL: Array = [Color("ffb000"), Color("ff8a3d"), Color("ff6a4d"), Color("ff3b30")]
const REACT_SHORT: Array = ["ПРОТЕСТ", "УГРОЗА", "ТРЕБОВАНИЕ", "УЛЬТИМАТУМ"]
const REACT_CONSEQ: Dictionary = {"rel": "отказ → хуже отношения", "demand": "отказ → требование", "sanctions": "отказ → санкции, коалиция", "war": "отказ → ВОЙНА"}



func _react_card(it: Dictionary) -> Control:
	var st: int = clampi(int(it.get("stage", 0)), 0, 3)
	var from: Country = gw.country_by_id(int(it["from"]))
	var rimc: Color = REACT_COL[st]
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 6))
	p.add_child(_rim(rimc))
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	p.add_child(vb)
	var h1: = HBoxContainer.new()
	h1.add_theme_constant_override("separation", 6)
	vb.add_child(h1)
	h1.add_child(_icon(String(it["icon"]), 24))
	if from != null:
		h1.add_child(_flag(from, Vector2(21, 14)))
	var t: Label = UiKit.lbl("%s · %s" % [Loc.t(String(REACT_SHORT[st])), Loc.name(from.name).to_upper() if from != null else ""], 11, rimc, 2, 3)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h1.add_child(t)
	var bar: Control = _time_bar((float(it["left"]) if float(it["left"]) >= 0.0 else float(it.get("total", 60.0))) / maxf(1.0, float(it.get("total", 60.0))), Vector2(44, 6))
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h1.add_child(bar)
	var tl: Label = UiKit.lbl(_mmss(float(it["left"])) if float(it["left"]) >= 0.0 else "∞", 11, UiKit.GOLD, 2, 3)
	tl.custom_minimum_size.x = 30
	h1.add_child(tl)
	_timers.append([tl, bar, float(it["deadline"]), float(it.get("total", 60.0)), ""])
	vb.add_child(_ladder(st))
	var h2: = HBoxContainer.new()
	h2.add_theme_constant_override("separation", 5)
	vb.add_child(h2)
	h2.add_child(_icon(String(it.get("cause_icon", "icon_cause_convoy")), 16))
	var line: String = String(it.get("line", ""))
	var dl: Label = UiKit.lbl(line.left(1).to_upper() + line.substr(1), 11, UiKit.TEXT, 2, 3)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.max_lines_visible = 2
	dl.custom_minimum_size.x = 120
	h2.add_child(dl)
	var cq: String = String(REACT_CONSEQ.get(String(it.get("conseq", "")), ""))
	var h4: = HBoxContainer.new()
	h4.add_theme_constant_override("separation", 6)
	vb.add_child(h4)
	var nl: Label = UiKit.lbl(Loc.t("инцидентов: %d") % int(it.get("n", 1)), 9, UiKit.MUTED, 1)
	h4.add_child(nl)
	var cl: Label = UiKit.lbl(cq, 10 if st >= 2 else 9, C_WAR if st >= 2 else UiKit.MUTED, 2 if st >= 2 else 1)
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cl.clip_text = true
	cl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h4.add_child(cl)
	var h3: = HBoxContainer.new()
	h3.add_theme_constant_override("separation", 6)
	vb.add_child(h3)
	for o: Dictionary in it["options"]:
		var act: String = String(o["act"])
		var lab: String = String(o["label"])
		var colr: String = {"stop": "green", "pay": "gold", "refuse": "red" if st >= 3 else "stone"}.get(act, "stone")
		if act == "pay":
			lab = lab.replace("КОМПЕНС. · ", "ОТКУП " if compact() else "КОМПЕНС. ")
		var b: Button = UiKit.big(lab, colr, "", 44.0, 10 if act == "pay" else 11)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = compact()
		b.custom_minimum_size.x = 60 if compact() else 0.0
		if act == "pay" and gw.player != null and gw.player.money < int(it.get("comp", 0)) and \
		(String(it.get("comp_res", "")) == "" or int(gw.player.get(String(it["comp_res"]))) < int(it.get("comp_n", 0))):
			b.modulate = Color(1, 1, 1, 0.55)
		b.pressed.connect( func() -> void : _answer(String(it["id"]), act, p))
		h3.add_child(b)
	if float(it["left"]) < 15.0 or st >= 3:
		_pulse(p)
	return p



func _ladder(st: int) -> Control:
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 4:
		var cell: = VBoxContainer.new()
		cell.add_theme_constant_override("separation", 1)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(cell)
		var seg: = ColorRect.new()
		seg.custom_minimum_size = Vector2(10, 4 if i != st else 6)
		seg.color = (REACT_COL[i] as Color) if i == st else ((REACT_COL[i] as Color).darkened(0.45) if i < st else C_EMPTY)
		cell.add_child(seg)
		var txt: String = String(REACT_SHORT[i])
		if compact() or i != st:
			txt = ["ПРОТЕСТ", "УГРОЗА", "ТРЕБОВ.", "УЛЬТИМ."][i]
		var l: Label = UiKit.lbl(txt, 9, (REACT_COL[i] as Color) if i == st else (UiKit.MUTED if i < st else UiKit.DIM), 2 if i == st else 1)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		cell.add_child(l)
	return hb




func _tension_line(cid: int) -> Control:
	if not dp.has_method("react_tension"):
		return null
	var tn: Dictionary = dp.react_tension(me, cid)
	if tn.is_empty():
		return null
	if bool(tn.get("mine", false)) and String(tn.get("state", "")) != "comply":
		for it: Dictionary in dp.pending_for_player():
			if String(it["kind"]) == "react" and int(it["from"]) == cid:
				return null
	var st: int = clampi(int(tn.get("stage", 0)), 0, 3)
	var comply: bool = String(tn.get("state", "")) == "comply"
	var colr: Color = C_PEACE if comply else REACT_COL[st]
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	var h1: = HBoxContainer.new()
	h1.add_theme_constant_override("separation", 5)
	vb.add_child(h1)
	h1.add_child(_icon("icon_dip_tension_16", 16))
	h1.add_child(_section("НАПРЯЖЁННОСТЬ"))
	var pill: Label = UiKit.lbl("ОБЕЩАНИЕ" if comply else String(REACT_SHORT[st]), 10, colr, 2, 3)
	h1.add_child(pill)
	var sp: = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h1.add_child(sp)
	var dl: float = float(tn.get("deadline", 0.0))
	if dl > gw.game_time:
		var tl: Label = UiKit.lbl(_mmss(dl - gw.game_time), 11, UiKit.GOLD, 2, 3)
		h1.add_child(tl)
		_timers.append([tl, null, dl, float(tn.get("total", 60.0)), ""])
	var h2: = HBoxContainer.new()
	h2.add_theme_constant_override("separation", 5)
	vb.add_child(h2)
	h2.add_child(_icon(String(tn.get("cause_icon", "icon_cause_convoy")), 16))
	var t: String = String(tn.get("text", ""))
	var i: int = t.find(": ", t.find("ОБЕЩАНИЕ") if comply else 0)
	var body: String = t.substr(i + 2) if i >= 0 and (comply or bool(tn.get("mine", false))) else t
	if tn.has("body"):
		body = String(tn["body"])
	elif not Loc.is_src() and i >= 0 and comply and t.find("ОБЕЩАНИЕ") < 0:
		body = t
	var l: Label = UiKit.lbl(body, 10, UiKit.TEXT, 1)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h2.add_child(l)
	return vb




var _leave_arm: bool = false
var _kick_arm: int = -1





func _ally_row(cid: int) -> Control:
	var al = dp.get("ally")
	var a: Dictionary = al.of_country(cid) if al != null else {}
	var outer: = VBoxContainer.new()
	outer.name = "AllyRow"
	outer.add_theme_constant_override("separation", 4)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	outer.add_child(hb)
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(k, UiKit.sb("wb_panel_dark" if k != "pressed" else "wb_slot_pressed", 6, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	hb.add_child(b)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	b.add_child(row)
	var t: Label = UiKit.lbl("АЛЬЯНС:", 10, UiKit.MUTED, 2, 3)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.size_flags_vertical = Control.SIZE_FILL
	row.add_child(t)
	if a.is_empty():
		var n0: Label = UiKit.lbl("НЕТ", 11, UiKit.DIM, 2, 3)
		n0.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n0.size_flags_vertical = Control.SIZE_FILL
		row.add_child(n0)
		b.disabled = true
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ab0: Button = _ally_action(cid)
		if ab0 != null:
			hb.add_child(ab0)
		return outer
	var colr: Color = al.color(a)
	var lg: TextureRect = UiKit.icon_rect("ally_logo_%d" % int(a["logo"]), 34.0)
	lg.modulate = colr
	lg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lg)
	var nm: Label = UiKit.lbl(Loc.name(String(a["name"])).to_upper(), 11, colr.lightened(0.3), 2, 3)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.size_flags_vertical = Control.SIZE_FILL
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(nm)
	var cnt: Label = UiKit.lbl("%d ›" % (a["members"] as Array).size(), 10, UiKit.MUTED, 2, 3)
	cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cnt.size_flags_vertical = Control.SIZE_FILL
	row.add_child(cnt)
	b.pressed.connect( func() -> void : pg.ally_focus(a))
	var founder: bool = int(a.get("founder", -1)) == me
	if cid == me:

		var act: = HBoxContainer.new()
		act.add_theme_constant_override("separation", 6)
		outer.add_child(act)
		if founder:
			var eb: Button = UiKit.big("ЗНАК И НАЗВАНИЕ", "blue", "", 44.0, 10)
			eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			eb.pressed.connect( func() -> void : hud.open_ally_sheet(int(a["id"]), true))
			act.add_child(eb)
		var lb: Button = UiKit.big(Loc.t("ТОЧНО ВЫЙТИ?") if _leave_arm else Loc.t("ВЫЙТИ ИЗ АЛЬЯНСА"), "red", "", 44.0, 10)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.pressed.connect( func() -> void :
			if not _leave_arm:
				_leave_arm = true
				rebuild()
				return
			_leave_arm = false
			_dp("alliance_leave", [me], func(why: String) -> void :
				m.hud.show_toast(why if why != "" else "Вы вышли из альянса «%s»" % String(a["name"]))
				rebuild()))
		act.add_child(lb)
	elif not (founder and al.id_of(me) == int(a["id"])):
		var ab1: Button = _ally_action(cid)
		if ab1 != null:
			hb.add_child(ab1)
	else:
		var arm: bool = _kick_arm == cid
		var kb: Button = UiKit.big(Loc.t("ТОЧНО?") if arm else Loc.t("ИСКЛЮЧИТЬ"), "red", "", 44.0, 9)
		kb.custom_minimum_size.x = 88
		kb.pressed.connect( func() -> void :
			if not arm:
				_kick_arm = cid
				rebuild()
				return
			_kick_arm = -1
			_dp("alliance_kick", [me, int(a["id"]), cid], func(why: String) -> void :
				m.hud.show_toast(why if why != "" else "%s исключена из альянса" % gw.country_by_id(cid).name)
				rebuild()))
		hb.add_child(kb)
	return outer




func _ally_action(cid: int) -> Button:
	var al = dp.get("ally")
	if al == null or cid == me or not GameConfig.alliances or dp.at_war(me, cid):
		return null
	var mine: int = al.id_of(me)
	var theirs: int = al.id_of(cid)
	var label: String = ""
	var method: String = ""
	var args: Array = []
	if mine < 0 and theirs < 0:
		label = "ОСНОВАТЬ"
		method = "alliance_found"
		args = [me, cid]
	elif mine >= 0 and theirs < 0:
		label = "ПРИГЛАСИТЬ"
		method = "alliance_invite"
		args = [me, cid]
	elif mine < 0 and theirs >= 0:
		label = "ВСТУПИТЬ"
		method = "alliance_join"
		args = [me, theirs]
	else:
		return null
	var bt: Button = UiKit.big(label, "green", "", 44.0, 10)
	bt.custom_minimum_size.x = 96
	bt.name = "AllyAction"
	bt.pressed.connect( func() -> void :
		_dp(method, args, func(why: String) -> void :
			if why == "sent":
				m.hud.show_toast("Предложение отправлено: %s ответит во «Входящих»" % gw.country_by_id(cid).name)
			elif why != "":
				m.hud.show_toast(why)
			else:
				m.hud.show_toast("Альянс «%s»" % String(al.name_of(me)))
			rebuild()))
	return bt
