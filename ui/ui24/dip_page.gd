extends RefCounted









const DipApiS = preload("res://ui/ui24/dip_api.gd")
const ChatViewS = preload("res://ui/ui24/dip_chat_view.gd")
const AG = preload("res://game/army_groups.gd")

const C_WAR: = Color("ff6a4d")
const C_PEACE: = Color("a2e35f")
const C_TRUCE: = Color("ffb000")
const C_ALLY: = Color("7cccff")
const C_SKY: = Color("7cccff")
const C_AMB: = Color("ffb000")
const C_RED_T: = Color("ff9a80")
const C_LINE: = Color("1d1f17")
const TABS: Array = [["dog", "ДОГОВОРЫ", "icon_dip_pending"], ["mil", "ВОЕННОЕ", "icon_ad_patriot"], 
	["trade", "ТОРГОВЛЯ", "icon_trade"], ["req", "ПРОСЬБЫ", "icon_dip_call"]]
const STATUS_COL: Array = [Color("cfc6a8"), Color("cfc6a8"), Color("ffd75e"), Color("ffd75e"), Color("ff8a3d"), Color("ff8a3d")]

const KINDS: Array = [["war_on", "ОБЪЯВИТЬ ВОЙНУ…", "d331_req_war_on", true], ["sky_over", "ЗАКРЫТЬ НЕБО НАД…", "d331_req_sky_over", true], 
	["join_war", "ВСТУПИТЬ В МОЮ ВОЙНУ", "d331_req_join_war", true], ["sky_me", "ЗАКРЫТЬ НЕБО НАДО МНОЙ", "d331_req_sky_me", false], 
	["station", "ПОСТАВИТЬ ВОЙСКА У МЕНЯ", "d331_req_station", false], ["stop_war", "ПРЕКРАТИТЬ ВОЙНУ С…", "d331_req_stop_war", true], 
	["guard", "ПУСТИТЬ МОЮ АРМИЮ НА ЗАЩИТУ…", "d331_req_defend", true]]
const KIND_DONE: Dictionary = {"war_on": "ОБЪЯВИТЬ ВОЙНУ:", "sky_over": "ЗАКРЫТЬ НЕБО НАД:", "join_war": "ВСТУПИТЬ В ВОЙНУ ПРОТИВ:", 
	"sky_me": "ЗАКРЫТЬ НЕБО НАДО МНОЙ", "station": "ПОСТАВИТЬ ВОЙСКА У МЕНЯ", "stop_war": "ПРЕКРАТИТЬ ВОЙНУ:", "guard": "ПУСТИТЬ АРМИЮ НА ЗАЩИТУ ОТ:"}
const AID_TILE: Dictionary = {"drones": ["d331_aid_drones", "ДРОНЫ"], "missile_b": ["d331_aid_missiles", "РАКЕТЫ"], 
	"missile_c": ["icon_m_cruise", "КРЫЛАТЫЕ"], "missile_sam": ["d331_aid_sam", "ЗУР"]}
const CON_RES: Array = ["oil", "metal", "titanium", "wood", "precious"]
const CON_PER: Array = [5, 10, 20, 30, 40, 60]
const CON_PRICE: Array = [0.5, 0.75, 0.9, 1.0, 1.1, 1.25, 1.5, 2.0]
const CON_N: Array = [2, 5, 10, 15, 20]

var s
var api
var cur: int = -1
var tab: String = ""
var last_tab: String = "dog"
var confirm: String = ""
var more_open: bool = false
var stage: Dictionary = {}
var comp: int = 0
var comp_kind: String = ""
var comp_x: int = -1
var guard_open: bool = false
var mil_open: bool = false
var c_sell: bool = true
var c_res: String = "oil"
var c_per: int = 3
var c_price: int = 3
var c_n: int = 2
var collapsed: bool = false
var user_open: bool = false
var forced: bool = false
var _dz_full: Control = null
var _dz_mini: Control = null
var _peek_back: Vector2 = Vector2.INF
var _pin_it: Dictionary = {}
var _pin_n: int = 0
var chat_on: bool = false
var chat_draft: String = ""
var chat_focus: bool = false
var chat_base_h: float = 0.0
var chat_lifted: bool = false
var chat_hold_off: float = 0.0
var _war_in_mini: bool = false


func _init(sheet) -> void :
	s = sheet


func _a():
	if api == null or api.gw != s.gw or api.dp != s.dp:
		api = DipApiS.new(s.gw, s.me)
	return api



func reset(cid: int) -> void :
	cur = cid
	tab = ""
	confirm = ""
	more_open = false
	stage.clear()
	comp = 0
	comp_kind = ""
	comp_x = -1
	guard_open = false
	mil_open = false
	collapsed = false
	user_open = false
	if chat_on:
		_chat_close()
	chat_draft = ""



func sig() -> String:
	if chat_on:
		var ch: DipChat = _chat()
		return "|chat:%d:%s" % [cur, ch.why_closed(cur) if ch != null else ""]
	var x: String = "|pg:%s:%s:%d:%s:%d:%s%s%s:%s:%s%s%d%d%d" % [tab, confirm, comp, comp_kind, comp_x, more_open, guard_open, mil_open, 
		",".join(PackedStringArray(stage.keys())), c_sell, c_res, c_per, c_price, c_n]
	var cid: int = int(s.page)
	if cid < 0 or s.gw.player == null:
		return x
	var ap = _a()
	var me: int = int(s.me)
	x += "|%d:%d:%d:%d|%s|%s%s%s|%s|%d:%d|%s|%d:%d|%s|%s%s" % [ap.troops_on(me, cid), ap.troops_on(cid, me), ap.leaving(me, cid), ap.leaving(cid, me), 
		String(ap.war_block(me, cid).get("why", "")), ap.sky_sig(me, cid), ap.sky_sig(cid, me), str(ap.sky_away(cid).size()), str(ap.sanctions(me, cid)), 
		ap.reqs_between(me, cid).size(), ap.reqs_between(cid, me).size(), String(ap.status(cid).get("full", "")), ap.rival_of(me), ap.rival_of(cid), 
		_gsig(ap.guard_of(cid)) + _gsig(ap.guard_in(cid)), ap.t_offer(me, cid, "passage").is_empty(), ap.t_offer(me, cid, "passage_give").is_empty()]
	x += "|pw:%s%s" % [ap.pass_wait(me, cid).is_empty(), ap.pass_wait(cid, me).is_empty()]
	x += "|rf:%s" % (String(s.dp.rift_note(me, cid)).left(24) if s.dp.has_method("rift_note") else "")
	x += "|rq:%s:%d:%s:%s" % [ap.req_wait(cid, "stop_war") > 0.0, ap.press_on(cid).size(), str(ap.subject_wars(cid).get("with", [])), ap.rate_wait() > 0.0]
	for k: Dictionary in ap.contracts(cid):
		x += "%s:%s:%d;" % [str(k.get("id", "")), str(k.get("state", "")), int(k.get("done", 0))]
	return x



func _gsig(g: Dictionary) -> String:
	return "" if g.is_empty() else "%d%s%d;" % [int(g.get("gid", -1)), String(g.get("kind", "")), int(g.get("troops", 0))]




func build(cid: int) -> void :
	var gw: GameWorld = s.gw
	var dp: Diplomacy = s.dp
	var me: int = int(s.me)
	if cid != cur:
		reset(cid)
	var c: Country = gw.country_by_id(cid)
	var row: Dictionary = dp.country_row(me, cid)
	var st: int = int(row["rel_state"])
	var pend: Array = []
	for it: Dictionary in dp.pending_for_player():
		if int(it["from"]) == cid:
			pend.append(it)
	if tab == "":
		if String(s.hud.dip_hint_treaty) != "":
			tab = "dog"
		elif not pend.is_empty():
			tab = "req"
		elif st == Diplomacy.Rel.WAR:
			tab = "mil"
		else:
			tab = last_tab
	if String(s.confirm_kind).begins_with("ult_") or String(s.confirm_kind) == "free":
		more_open = true
	if comp > 0:
		_composer(cid, c)
		return
	if chat_on:
		_chat_page(c)
		return
	var pin_on: bool = tab != "req" and not pend.is_empty()
	_pin_it = pend[0] if pin_on else {}
	_pin_n = pend.size()

	forced = s.compact() and (pin_on or st == Diplomacy.Rel.WAR) and not user_open
	if forced:
		collapsed = true
	_war_in_mini = forced and st == Diplomacy.Rel.WAR
	_head(c, true)
	_dossier(cid, c, row, st)
	if pin_on and not (forced and not _war_in_mini):
		_pin(pend[0], pend.size())
	s._new_scroll()
	_watch_scroll()
	match tab:
		"dog":
			_tab_dog(cid, row, st)
		"mil":
			_tab_mil(cid, row, st)
		"trade":
			_tab_trade(cid, row, st)
		_:
			_tab_req(cid, row, st, pend)
	if st == Diplomacy.Rel.WAR and not _war_in_mini:
		var qa: = HBoxContainer.new()
		qa.name = "WarRow"
		qa.add_theme_constant_override("separation", 6)
		s.col.add_child(qa)
		for b: Button in s._war_buttons(cid):
			qa.add_child(b)
		var sur: Button = s._surrender_tile(cid)
		if sur != null:
			sur.size_flags_horizontal = Control.SIZE_FILL
			sur.custom_minimum_size.x = 76
			qa.add_child(sur)
	_tabs(cid, st, pend)
	_refit()



func _refit() -> void :
	var inn: Control = s.inner
	if inn != null and not inn.minimum_size_changed.is_connected(s._fit_scroll):
		inn.minimum_size_changed.connect(s._fit_scroll)


func _set_tab(k: String) -> void :
	if tab == k:
		return
	UiKit.snd("ui_click")
	tab = k
	last_tab = k
	confirm = ""
	collapsed = false
	s.confirm_kind = ""
	s.aid_open = false
	mil_open = false
	guard_open = false
	s.rebuild(false)




func _head(c: Country, page_btns: bool) -> void :
	var hr: = HBoxContainer.new()
	hr.name = "Head"
	hr.add_theme_constant_override("separation", 6)
	hr.custom_minimum_size.y = 40
	s.col.add_child(hr)
	var bb: Button = UiKit.arrow(true)
	bb.pressed.connect( func() -> void :
		if chat_on:
			UiKit.snd("ui_click")
			_chat_close()
			s.rebuild(false)
		elif comp > 0:
			_comp_back()
		else:
			s.open_list())
	hr.add_child(bb)
	hr.add_child(s._flag(c, Vector2(30, 19)))
	var t: Label = UiKit.lbl(Loc.name(c.name).to_upper(), 18, UiKit.TITLE, 3, 4)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.fit_lbl(t, [18, 16, 14, 12], false)
	hr.add_child(t)
	var ch: DipChat = _chat()
	if page_btns and ch != null and ch.available(c.id):
		var chb: Button = s._icon_btn("icon_dip_chat", "stone")
		chb.name = "ChatBtn"
		chb.tooltip_text = "ЧАТ"
		var n_un: int = int(ch.unread.get(c.id, 0))
		if n_un > 0 and not ch.muted.has(c.id):
			chb.add_child(s._count_badge(mini(n_un, 9), Vector2(29, 1)))
		chb.pressed.connect( func() -> void :
			UiKit.snd("ui_click")
			chat_on = true
			s.rebuild(false))
		hr.add_child(chb)
	if page_btns:
		var mb: Button = s._icon_btn("icon_goto_map", "stone")
		mb.name = "MapBtn"
		var cid: int = c.id
		mb.pressed.connect( func() -> void :
			s.pan_to(cid)
			s.close_sheet())
		hr.add_child(mb)
	var cb: Button = UiKit.close_btn(UiKit.TOUCH_MIN)
	cb.pressed.connect( func() -> void : s.close_sheet())
	hr.add_child(cb)


func _dossier(cid: int, c: Country, row: Dictionary, st: int) -> void :
	var gw: GameWorld = s.gw
	var dp: Diplomacy = s.dp
	var me: int = int(s.me)
	var ap = _a()
	var cmp: bool = s.compact()
	var p: = PanelContainer.new()
	p.name = "Dossier"
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 6, 3 if cmp else 5))
	s.col.add_child(p)
	var ov: = VBoxContainer.new()
	ov.add_theme_constant_override("separation", 0)
	p.add_child(ov)
	var vb: = VBoxContainer.new()
	vb.name = "DossierFull"
	vb.add_theme_constant_override("separation", 3)
	ov.add_child(vb)
	var r1: = HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	vb.add_child(r1)
	var per: Dictionary = row["persona"]
	var human: bool = c.is_player
	var icon: String = "net_players" if human else (String(per.get("icon", "icon_persona_unknown")) if not per.is_empty() else "icon_persona_unknown")
	r1.add_child(s._portrait(icon, st, 30.0 if cmp else 36.0))
	var who: = VBoxContainer.new()
	who.add_theme_constant_override("separation", 1)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	r1.add_child(who)
	var l1: = HBoxContainer.new()
	l1.add_theme_constant_override("separation", 5)
	who.add_child(l1)
	l1.add_child(s._state_badge(st, cid))
	var stt: Dictionary = ap.status(cid)
	var pn: String = Loc.t("ЖИВОЙ ИГРОК") if human else String(per.get("name", "ХАРАКТЕР НЕИЗВЕСТЕН"))
	var pl: Label = UiKit.lbl(pn, 11, UiKit.GOLD if (human or not per.is_empty()) else UiKit.DIM, 2, 3)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l1.add_child(pl)
	UiKit.fit_lbl(pl, [11, 10, 9], false, true)
	if human:
		l1.add_child(s._icon("net_signal_ok", 14))

	var rdir: int = ap.rival_dir(me, cid)
	var rival: bool = rdir != 0 or ap.rivals(me, cid)
	var crisis: String = String(stt.get("state_name", ""))
	var dl: = HBoxContainer.new()
	dl.name = "Line2"
	dl.add_theme_constant_override("separation", 4)
	who.add_child(dl)
	if not stt.is_empty():
		if cmp:
			var sc0: Control = _status_chip(stt)
			sc0.get_child(1).visible = false
			l1.add_child(sc0)
			l1.move_child(sc0, 1)
		else:
			dl.add_child(_status_chip(stt))
	if crisis != "":
		dl.add_child(_tag(crisis, C_TRUCE))
	if rival:
		var ri: TextureRect = UiKit.icon_rect("d331_rival_12", 12.0)
		ri.custom_minimum_size = Vector2(12, 12)
		ri.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dl.add_child(ri)
		var rg: Control = _tag(Loc.t("СОПЕРНИК") if rdir != 2 else Loc.t("ВЫ — ИХ СОПЕРНИК"), C_WAR)
		rg.name = "Rival"
		dl.add_child(rg)
	var desc: String = (Loc.t("ждут от вас подвоха") if rdir == 2 else Loc.t("не примет ваших просьб")) if rival else (Loc.t("в сети · отвечает сам, до 2:00") if human else String(per.get("desc", "Узнаете после договора, сделки или войны.")))
	var ds: Label = UiKit.lbl(desc, 9, C_RED_T if rival else UiKit.MUTED, 1)
	ds.clip_text = true
	ds.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ds.custom_minimum_size.x = 24
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ds.visible = rival or human or not cmp or (stt.is_empty() and crisis == "")
	if not cmp and not stt.is_empty():
		ds.name = "Line3"
		UiKit.fit_lbl(ds, [9])
		who.add_child(ds)
	else:
		dl.add_child(ds)
	dl.visible = not cmp or ds.visible or crisis != "" or rival

	var rv: int = int(row["relation"])
	var rc: = VBoxContainer.new()
	rc.add_theme_constant_override("separation", 0)
	rc.alignment = BoxContainer.ALIGNMENT_CENTER
	r1.add_child(rc)
	var rvh: = HBoxContainer.new()
	rvh.add_theme_constant_override("separation", 3)
	rvh.alignment = BoxContainer.ALIGNMENT_END
	rc.add_child(rvh)
	if int(row["trend"]) != 0:
		rvh.add_child(s._trend(int(row["trend"])))
	var vl: Label = UiKit.lbl(s._signed(rv), 18, s._rel_col(rv), 3, 4)
	vl.name = "RelValue"
	rvh.add_child(vl)
	var ratio: float = dp.strength(cid) / maxf(1.0, dp.strength(me))
	var stx: String = "сила равна"
	var sc: Color = UiKit.MUTED
	if ratio > 1.25:
		stx = Loc.t("сильнее ×%s") % s._x(ratio)
		sc = C_WAR
	elif ratio < 0.8:
		stx = Loc.t("слабее ×%s") % s._x(1.0 / maxf(ratio, 0.01))
		sc = C_PEACE
	var sl: Label = UiKit.lbl(stx, 9, sc, 2)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rc.add_child(sl)

	var r2: = HBoxContainer.new()
	r2.add_theme_constant_override("separation", 6)
	vb.add_child(r2)
	var mt: Control = s._meter(rv, Vector2(100, 6), false)
	mt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r2.add_child(mt)
	s._rows[-1] = [mt, vl]
	var nxt: String = ""
	if st != Diplomacy.Rel.WAR and st != Diplomacy.Rel.TRUCE:
		for th: Array in _thresh():
			if rv < int(th[1]) and not dp.has_treaty(me, cid, String(th[0])) and dp.treaty_covered(me, cid, String(th[0])) == "":
				nxt = Loc.t("%s: ещё +%d") % [Loc.t(String(Diplomacy.TREATY_INFO[String(th[0])]["short"])).trim_suffix(".").to_upper(), int(th[1]) - rv]
				break
	var n2: int = r2.get_child_count()
	_strip(r2, cid, row, st)
	if nxt != "" and r2.get_child_count() == n2:
		r2.add_child(UiKit.lbl(nxt, 9, UiKit.MUTED, 2))
	_dz_full = vb
	_dz_mini = _mini(ov, cid, row, st)
	vb.visible = not collapsed
	_dz_mini.visible = collapsed



func _mini(parent: Control, cid: int, row: Dictionary, st: int) -> Control:
	var b: = Button.new()
	b.name = "DossierMini"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 30
	for k: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	parent.add_child(b)
	var hb: HBoxContainer = s._fill_box(b, 0, 0)
	hb.add_child(s._state_badge(st, cid))
	if _war_in_mini:
		b.custom_minimum_size.y = 44
		for wb: Button in s._war_buttons(cid):
			wb.custom_minimum_size.x = 0
			hb.add_child(wb)
		_mini_arrow(hb)
		b.pressed.connect(_unfold)
		return b
	var rv: int = int(row["relation"])
	var vl: Label = UiKit.lbl(s._signed(rv), 14, s._rel_col(rv), 2, 3)
	vl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vl.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(vl)
	s._rows[cid] = [null, vl]
	var n0: int = hb.get_child_count()
	if forced and not _pin_it.is_empty():
		hb.add_child(_pin_chip(_pin_it, _pin_n))
	else:
		_strip(hb, cid, row, st, true)
	if hb.get_child_count() > n0:
		(hb.get_child(n0) as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		var sp: = Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(sp)
	_mini_arrow(hb)
	b.pressed.connect(_unfold)
	return b


func _mini_arrow(hb: HBoxContainer) -> void :
	hb.add_child(_arrow(90.0))



func _arrow(deg: float) -> Control:
	var hold: = Control.new()
	hold.custom_minimum_size = Vector2(12, 12)
	hold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ar: TextureRect = s._icon("wb_arrow_r", 12)
	ar.position = Vector2.ZERO
	ar.size = Vector2(12, 12)
	ar.pivot_offset = Vector2(6, 6)
	ar.rotation_degrees = deg
	hold.add_child(ar)
	return hold



func _unfold() -> void :
	UiKit.snd("ui_click")
	if forced:
		user_open = true
		forced = false
		collapsed = false
		s.rebuild(false)
		return
	_collapse(false)
	if s.scroll != null and is_instance_valid(s.scroll):
		s.scroll.scroll_vertical = 0



func _pin_chip(it: Dictionary, n: int) -> Control:
	var b: = Button.new()
	b.name = "PinAnswer"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 30
	var st: = StyleBoxFlat.new()
	st.bg_color = C_AMB.darkened(0.8)
	st.border_color = C_AMB.darkened(0.1)
	st.set_border_width_all(1)
	st.set_corner_radius_all(3)
	var stp: StyleBoxFlat = st.duplicate()
	stp.bg_color = C_AMB.darkened(0.6)
	for k: String in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(k, st)
	b.add_theme_stylebox_override("pressed", stp)
	b.add_theme_stylebox_override("hover_pressed", stp)
	b.clip_contents = true
	var hb: HBoxContainer = s._fill_box(b, 4, 0)
	hb.add_theme_constant_override("separation", 4)
	var ic: TextureRect = s._icon(String(it.get("icon", "icon_dip_call")), 16)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var t: Label = UiKit.lbl(Loc.t(_pend_title(it)) + ((" +%d" % (n - 1)) if n > 1 else ""), 9, UiKit.TEXT, 2, 3)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size.x = 30
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(t)
	var tl: Label = UiKit.lbl(s._mmss(float(it["left"])) if float(it["left"]) >= 0.0 else "∞", 10, C_AMB, 2, 3)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(tl)
	s._timers.append([tl, null, float(it["deadline"]), float(it.get("total", 60.0)), ""])
	b.pressed.connect( func() -> void : _set_tab("req"))
	return b



func _collapse(on: bool) -> void :
	if on == collapsed:
		return
	collapsed = on
	if is_instance_valid(_dz_full):
		_dz_full.visible = not on
	if is_instance_valid(_dz_mini):
		_dz_mini.visible = on
	s._fit_scroll()
	s._fit_scroll.call_deferred()




func _watch_scroll() -> void :
	var sc: ScrollContainer = s.scroll
	if sc == null:
		return
	sc.get_v_scroll_bar().value_changed.connect( func(v: float) -> void :
		if not is_instance_valid(sc) or comp > 0 or not is_instance_valid(_dz_full) or not is_instance_valid(_dz_mini):
			return
		if not collapsed and v > 24.0:
			var save: float = _dz_full.get_combined_minimum_size().y - _dz_mini.get_combined_minimum_size().y
			if s.inner.size.y > sc.size.y + save + 24.0:
				_collapse(true)
		elif collapsed and v <= 0.5 and not forced:
			_collapse(false))


func _thresh() -> Array:
	var cm: Dictionary = (s.get_script() as Script).get_script_constant_map()
	return cm.get("THRESH", [])



func _status_chip(stt: Dictionary) -> Control:
	var t: int = clampi(int(stt.get("tier", 0)), 0, 5)
	var hb: = HBoxContainer.new()
	hb.name = "Status"
	hb.add_theme_constant_override("separation", 2)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic: TextureRect = UiKit.icon_rect("d331_st_%d" % (t + 1), 20.0)
	ic.custom_minimum_size = Vector2(20, 20)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var nm: String = String(stt.get("abbr" if s.compact() else "short", ""))
	var l: Label = UiKit.lbl(nm, 9, STATUS_COL[t], 2, 3)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(l)
	var tip: String = String(stt.get("full", nm))
	hb.mouse_filter = Control.MOUSE_FILTER_STOP
	hb.gui_input.connect( func(ev: InputEvent) -> void :
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not ev.is_pressed():
			s.m.hud.show_toast("Статус: " + tip))
	return hb



func _tag(text: String, cc: Color) -> Control:
	var p: = PanelContainer.new()
	var st: = StyleBoxFlat.new()
	st.bg_color = cc.darkened(0.78)
	st.border_color = cc.darkened(0.2)
	st.set_border_width_all(1)
	st.set_corner_radius_all(3)
	st.content_margin_left = 4
	st.content_margin_right = 4
	st.content_margin_top = 0
	st.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", st)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UiKit.lbl(text, 9, cc.lightened(0.15), 2, 3))
	return p




func _strip(parent: Control, cid: int, row: Dictionary, st: int, folded: bool = false) -> void :
	var gw: GameWorld = s.gw
	var dp: Diplomacy = s.dp
	var me: int = int(s.me)
	var ap = _a()
	var items: Array = []
	var al = dp.get("ally")
	if al != null and GameConfig.alliances:
		var a: Dictionary = al.of_country(cid)
		if not a.is_empty():
			items.append(["ally_logo_%d" % int(a["logo"]), Loc.name(String(a["name"])).to_upper(), al.color(a), "", a])
	var n1: int = ap.leaving(cid, me)
	if n1 >= 0:
		items.append(["d331_pass_revoke", Loc.t("ИХ ВОЙСКА УХОДЯТ: %d") % n1, C_AMB, "mil", {}])
	var n2: int = ap.leaving(me, cid)
	if n2 >= 0:
		items.append(["icon_op_retreat", Loc.t("НАШИ УХОДЯТ: %d") % n2, C_AMB, "mil", {}])
	if not ap.t_offer(me, cid, "passage").is_empty() or not ap.t_offer(me, cid, "passage_give").is_empty():
		items.append(["d331_active_16", "ПРОХОД: ЖДЁМ ОТВЕТА", C_AMB, "mil", {}])
	var nq: int = ap.reqs_between(me, cid).size()
	if nq > 0:
		items.append(["d331_active_16", Loc.t("ЖДЁМ ОТВЕТА") if nq == 1 else Loc.t("ЖДЁМ ОТВЕТА: %d") % nq, C_AMB, "req", {}])
	for k: Dictionary in ap.contracts(cid):
		if String(k.get("state", "")) == "offer":
			items.append(["d331_contract_16", "КОНТРАКТ ЖДЁТ ОТВЕТА", C_AMB, "trade", {}])
			break
	for eid: int in c_wars(cid):
		if _partner(eid) and not dp.at_war(me, cid):
			items.append(["icon_rel_war", Loc.t("ВОЙНА: %s") % s._cname_up(eid), C_WAR, "trade", {}])
			break
	if bool(row["embargo_out"]):
		items.append(["icon_treaty_embargo", "ЭМБАРГО", C_WAR, "trade", {}])
	elif not ap.sanctions(me, cid).is_empty():
		items.append(["d331_sanct_16", Loc.t("САНКЦИИ: %d") % ap.sanctions(me, cid).size(), C_WAR, "trade", {}])
	if bool(row["embargo_in"]):
		items.append(["icon_treaty_embargo", "ЭМБАРГО ВАМ", C_RED_T, "trade", {}])
	elif not ap.sanctions(cid, me).is_empty():
		items.append(["d331_sanct_16", Loc.t("САНКЦИИ ВАМ: %d") % ap.sanctions(cid, me).size(), C_RED_T, "trade", {}])
	if st == Diplomacy.Rel.WAR:
		var pr: Array = ap.pressing(cid)
		pr.erase(me)
		if not pr.is_empty():
			items.append(["icon_dip_stop", Loc.t("ДАВЯТ: %d") % pr.size(), C_AMB, "mil", {}])
	if items.is_empty():
		return
	var hb: = HBoxContainer.new()
	hb.name = "Strip"
	hb.add_theme_constant_override("separation", 4)
	hb.clip_contents = true
	parent.add_child(hb)
	var room: int = 2 if s.compact() else 3


	var budget: float = float(s.vp.x) - (192.0 if folded else 214.0)
	var used: float = 0.0
	var fit_n: int = 0
	for i: int in mini(items.size(), room):
		var cw: float = 37.0 + UiKit.f_bold.get_string_size(String(items[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + (4.0 if fit_n > 0 else 0.0)
		var rsv: float = 34.0 if items.size() > i + 1 else 0.0
		if fit_n >= 1 and used + cw + rsv > budget:
			break
		used += cw
		fit_n += 1
	room = fit_n
	for i: int in mini(items.size(), room):
		hb.add_child(_chip(items[i]))
	if items.size() > room:
		var rest: Array = items[room]
		hb.add_child(_chip(["", "+%d" % (items.size() - room), UiKit.MUTED, String(rest[3]), rest[4]]))


func _chip(it: Array) -> Control:
	var cc: Color = it[2]
	var p: = PanelContainer.new()
	p.custom_minimum_size.y = 24
	var stb: = StyleBoxFlat.new()
	stb.bg_color = cc.darkened(0.78)
	stb.border_color = cc.darkened(0.25)
	stb.set_border_width_all(1)
	stb.set_corner_radius_all(3)
	stb.content_margin_left = 4
	stb.content_margin_right = 6
	p.add_theme_stylebox_override("panel", stb)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hb)
	var ic: String = String(it[0])
	var a: Dictionary = it[4]
	if ic != "":
		var tr: TextureRect = UiKit.icon_rect(ic, 17.0) if not a.is_empty() else s._icon(ic, 16)
		tr.custom_minimum_size = Vector2(17, 17) if not a.is_empty() else tr.custom_minimum_size
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not a.is_empty():
			tr.modulate = cc
		hb.add_child(tr)
	var l: Label = UiKit.lbl(String(it[1]), 9, cc.lightened(0.15), 2, 3)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(l)

	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	var pr: StyleBoxFlat = StyleBoxFlat.new()
	pr.bg_color = Color(1, 1, 1, 0.08)
	for k: String in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("hover_pressed", pr)


	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	p.add_child(b)
	p.resized.connect( func() -> void :
		b.position = Vector2(0, -10)
		b.size = p.size + Vector2(0, 20))
	var tb: String = String(it[3])
	b.pressed.connect( func() -> void :
		if not a.is_empty():
			ally_focus(a)
		elif tb != "":
			_set_tab(tb))
	return p



func ally_focus(a: Dictionary) -> void :
	UiKit.snd("ui_click")
	var gw: GameWorld = s.gw
	s.hud.action.emit("map_mode:%d" % GameWorld.MapMode.ALLIANCES)
	var cam = s.m.get("cam")
	var box: = Rect2()
	var have: bool = false
	for mid: Variant in a.get("members", []):
		var mc: Country = gw.country_by_id(int(mid))
		if mc == null or mc.eliminated or mc.capital_id < 0:
			continue
		var p: Vector2 = Vector2(gw.cities[mc.capital_id].center) * float(GameWorld.CELL)
		if not have:
			box = Rect2(p, Vector2.ZERO)
			have = true
		else:
			box = box.expand(p)
	if have and cam != null:
		var vs: Vector2 = cam.view_size()
		var z: float = 2.0
		if box.size.x > 1.0:
			z = minf(z, vs.x * 0.7 / box.size.x)
		if box.size.y > 1.0:
			z = minf(z, vs.y * 0.45 / box.size.y)
		cam.set_zoom_at(clampf(z, float(cam.min_zoom()), 2.0), vs * 0.5)
		cam.center_on(box.get_center())
		s.m.set("cam_lock", false)
	s.close_sheet()



func _pin(it: Dictionary, n: int) -> void :
	if s.compact():
		_pin_line(it, n)
		return
	var p: = PanelContainer.new()
	p.name = "Pin"
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 2, 2))
	p.add_child(s._rim(Color(C_AMB, 0.9)))
	s.col.add_child(p)
	var mg: = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		mg.add_theme_constant_override("margin_" + side, 8 if side == "left" or side == "right" else 3)
	p.add_child(mg)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	mg.add_child(hb)
	hb.add_child(s._icon(String(it.get("icon", "icon_dip_call")), 24))
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(v)
	var t: Label = UiKit.lbl(Loc.t("ПРОСЯТ: %s") % [Loc.t(_pend_title(it))], 10, UiKit.TEXT, 2, 3)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(t)
	var more: String = (Loc.t(" · ещё %d") % (n - 1)) if n > 1 else ""
	var sl: Label = UiKit.lbl((Loc.t("ответ до %s%s") % [s._mmss(float(it["left"])), more]) if float(it["left"]) >= 0.0 else Loc.t("без срока%s") % [more], 9, C_AMB, 2)
	sl.clip_text = true
	v.add_child(sl)
	s._timers.append([sl, null, float(it["deadline"]), float(it.get("total", 60.0)), "ответ до "])
	var b: Button = UiKit.big("ОТВЕТИТЬ", "gold", "", 44.0, 10)
	b.name = "PinAnswer"
	b.custom_minimum_size.x = 84
	b.pressed.connect( func() -> void : _set_tab("req"))
	hb.add_child(b)



func _pin_line(it: Dictionary, n: int) -> void :
	var b: = Button.new()
	b.name = "PinAnswer"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 40
	b.add_theme_stylebox_override("normal", UiKit.sb("wb_card", 2, 2))
	b.add_theme_stylebox_override("hover", UiKit.sb("wb_card", 2, 2))
	b.add_theme_stylebox_override("pressed", UiKit.sb("wb_slot_pressed", 2, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_child(s._rim(Color(C_AMB, 0.9)))
	s.col.add_child(b)
	var hb: HBoxContainer = s._fill_box(b, 8, 0)
	var ic: TextureRect = s._icon(String(it.get("icon", "icon_dip_call")), 20)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var t: Label = UiKit.lbl(Loc.t("ПРОСЯТ: %s%s") % [Loc.t(_pend_title(it)), ((Loc.t(" · ещё %d") % (n - 1)) if n > 1 else "")], 10, UiKit.TEXT, 2, 3)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(t)
	var tl: Label = UiKit.lbl(s._mmss(float(it["left"])) if float(it["left"]) >= 0.0 else "∞", 10, C_AMB, 2, 3)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(tl)
	s._timers.append([tl, null, float(it["deadline"]), float(it.get("total", 60.0)), ""])
	var ar: TextureRect = s._icon("wb_arrow_r", 12)
	ar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ar)
	b.pressed.connect( func() -> void : _set_tab("req"))




func _pend_title(it: Dictionary) -> String:
	var k: String = String(it.get("kind", ""))
	if it.has("title"):
		return String(it["title"])
	match k:
		"demand":
			return "УЛЬТИМАТУМ"
		"call":
			return "ВСТУПИТЬ В ИХ ВОЙНУ"
		"note":
			return "НОТА ПРОТЕСТА"
		"conference":
			return "КОНФЕРЕНЦИЯ"
		"surrender":
			return "ПРИНЯТЬ КАПИТУЛЯЦИЮ"
		"react":
			var cm: Dictionary = (s.get_script() as Script).get_script_constant_map()
			return String((cm["REACT_SHORT"] as Array)[clampi(int(it.get("stage", 0)), 0, 3)])
		"trade":
			return "ПРОДАТЬ ИМ"
		"request":
			var xn: String = String(s._cname_up(int(it.get("x", 0)))) if int(it.get("x", 0)) > 0 else ""
			return String({"war_on": Loc.t("ОБЪЯВИТЬ ВОЙНУ: %s") % [xn], "join_war": Loc.t("В ИХ ВОЙНУ: %s") % [xn], "sky_me": "ЗАКРЫТЬ НЕБО НАД НИМИ", 
				"sky_over": Loc.t("ЗАКРЫТЬ НЕБО: %s") % [xn], "station": "ВАШИ ВОЙСКА К НИМ", "stop_war": Loc.t("ПРЕКРАТИТЬ ВОЙНУ: %s") % [xn], "guard": "ИХ АРМИЯ НА ЗАЩИТУ"}.get(String(it.get("req", "")), "ПРОСЬБА"))
		"sky":
			return "НЕБО"
		"contract", "contract_cancel":
			return "КОНТРАКТ"
		"treaty":
			if bool(it.get("passage", false)):
				return "ПРАВО ПРОХОДА"
	var tx: String = String(it.get("text", ""))
	var i: int = tx.find(": ")
	if i >= 0:
		tx = tx.substr(i + 2)
	return tx.get_slice(".", 0).to_upper()




func _tabs(cid: int, st: int, pend: Array) -> void :
	var ap = _a()
	var me: int = int(s.me)
	var badge: Dictionary = {}
	if not pend.is_empty():
		badge["req"] = pend.size()
	elif ap.reqs_between(me, cid).size() > 0:
		badge["req"] = "net_wait"
	if ap.leaving(cid, me) >= 0 or ap.leaving(me, cid) >= 0 or not ap.t_offer(me, cid, "passage").is_empty() or not ap.t_offer(me, cid, "passage_give").is_empty():
		badge["mil"] = "net_wait"
	for k: Dictionary in ap.contracts(cid):
		if String(k.get("state", "")) == "offer":
			badge["trade"] = "net_wait"
	var tray: = PanelContainer.new()
	tray.name = "Tabs"
	tray.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 3, 1 if s.compact() else 3))
	s.col.add_child(tray)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	tray.add_child(hb)
	for t: Array in TABS:
		var k: String = String(t[0])
		var on: bool = k == tab
		var b: = Button.new()
		b.name = "Tab_" + k
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n: StyleBox = UiKit.sb("wb_btn_gold", 2, 2, -1) if on else StyleBoxEmpty.new()
		var np: StyleBox = UiKit.sb("wb_btn_gold_p", 2, 2, 1) if on else UiKit.sb("wb_slot_pressed", 2)
		for sk: String in ["normal", "hover"]:
			b.add_theme_stylebox_override(sk, n)
		b.add_theme_stylebox_override("pressed", np)
		b.add_theme_stylebox_override("hover_pressed", np)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		hb.add_child(b)
		var r: = HBoxContainer.new()
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_theme_constant_override("separation", 3)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(r)
		var ic: TextureRect = s._icon(String(t[2]), 16)
		if not on:
			ic.modulate = Color(1, 1, 1, 0.7)
		r.add_child(ic)
		var l: Label = UiKit.lbl(String(t[1]), 9, UiKit.TEXT if on else UiKit.MUTED, 2, 3)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_FILL
		if not Loc.is_src():
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			UiKit.fit_lbl(l, [9, 8], false)
		r.add_child(l)
		if s.compact() and not on:
			ic.visible = false
		if badge.has(k):
			var bd: Variant = badge[k]
			if bd is int:
				var cb: Control = s._count_badge(int(bd), Vector2(0, 1))
				b.add_child(cb)
				b.resized.connect( func() -> void : cb.position = Vector2(b.size.x - 15, 1))
			elif not on:
				var dot: TextureRect = s._icon(String(bd), 12)
				b.add_child(dot)
				b.resized.connect( func() -> void : dot.position = Vector2(b.size.x - 13, 2))
		b.pressed.connect( func() -> void : _set_tab(k))




func _sect(t: String, sub: String = "", sub_col: Color = UiKit.MUTED) -> HBoxContainer:
	var h: = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(s._section(t))
	if sub != "":
		var sl: Label = UiKit.lbl(sub, 9, sub_col, 1)
		sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sl.clip_text = true
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiKit.fit_lbl(sl, [9, 8], false)
		h.add_child(sl)
	s.inner.add_child(h)
	return h


func _card(rim: Color = Color(0, 0, 0, 0), nm: String = "") -> VBoxContainer:
	var p: = PanelContainer.new()
	if nm != "":
		p.name = nm
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 2, 2))
	if rim.a > 0.0:
		p.add_child(s._rim(rim))
	s.inner.add_child(p)
	var mg: = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		mg.add_theme_constant_override("margin_" + side, 8 if side == "left" or side == "right" else 5)
	p.add_child(mg)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	mg.add_child(vb)
	return vb



func _ghost(text: String) -> Button:
	var b: Button = UiKit.big(text, "stone", "", 44.0, 10)
	for k: String in ["normal", "hover"]:
		b.add_theme_stylebox_override(k, UiKit.sb("wb_panel_dark", 10, 4))
	b.add_theme_stylebox_override("pressed", UiKit.sb("wb_slot_pressed", 10, 4))
	b.add_theme_stylebox_override("disabled", UiKit.sb("wb_panel_dark", 10, 4))
	b.add_theme_color_override("font_color", UiKit.MUTED)
	b.add_theme_color_override("font_disabled_color", UiKit.DIM)
	return b




func _line(parent: Control, icon: String, title: String, state: String, scol: Color, btn: String = "", style: String = "stone", 
		on: Callable = Callable(), bar: float = -1.0) -> Button:
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.custom_minimum_size.y = 44
	parent.add_child(hb)
	hb.add_child(s._icon(icon, 24))
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(v)
	var tl: Label = UiKit.lbl(title, 10, UiKit.TEXT, 2, 3)
	tl.clip_text = true
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(tl)
	var sl: Label = UiKit.lbl(state, 9, scol, 2)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size.x = 80
	v.add_child(sl)
	if bar >= 0.0:
		var tb: Control = s._time_bar(bar, Vector2(90, 6))
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(tb)
	if btn == "" and style != "soon":
		return null
	var b: Button
	if style == "soon":
		b = _ghost("СКОРО")
		b.disabled = true
		s._btn_icon(b, "wb_lock")
	elif style == "ghost":
		b = _ghost(btn)
	else:
		b = UiKit.big(btn, style, "", 44.0, 10)
	b.custom_minimum_size.x = 84.0 if s.compact() else 96.0
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if on.is_valid():
		b.pressed.connect(on)
	hb.add_child(b)
	return b


func _note(parent: Control, text: String, cc: Color = UiKit.MUTED, icon: String = "") -> Label:
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	if icon != "":
		var ic: TextureRect = s._icon(icon, 12)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		hb.add_child(ic)
	var l: Label = UiKit.lbl(text, 9, cc, 1)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 100
	hb.add_child(l)
	parent.add_child(hb)
	return l


func _sep(parent: Control) -> void :
	var r: = ColorRect.new()
	r.color = C_LINE
	r.custom_minimum_size.y = 1
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)



func _confirm(parent: Control, text: String, yes: String, done: Callable, yes_style: String = "red") -> void :
	var p: = PanelContainer.new()
	p.name = "Confirm"
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_tooltip", 8, 5))
	parent.add_child(p)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	p.add_child(hb)
	var l: Label = UiKit.lbl(text, 9, UiKit.TEXT, 2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 100
	hb.add_child(l)
	var y: Button = UiKit.big(yes, yes_style, "", 44.0, 10)
	y.name = "ConfirmYes"
	y.custom_minimum_size.x = 80
	y.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	y.pressed.connect( func() -> void :
		confirm = ""
		done.call())
	hb.add_child(y)
	var n: Button = _ghost("НЕТ")
	n.custom_minimum_size.x = 48
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	n.pressed.connect( func() -> void :
		confirm = ""
		s.rebuild())
	hb.add_child(n)


func _arm(key: String) -> void :
	confirm = "" if confirm == key else key
	s.rebuild()



func _send(method: String, args: Array, ok: String, b: Control = null, path: String = "diplo") -> void :
	if method == "":
		s.m.hud.show_toast("Скоро: эта часть дипломатии ещё в работе")
		return
	if b is Button:
		(b as Button).disabled = true
	var sh = s
	NetSession.sim(path, method, args, func(r: Variant) -> void :
		if not is_instance_valid(sh):
			return
		var why: String = sh._rwhy(r)
		if why != "":
			s.m.hud.show_toast(why)
			if b != null and is_instance_valid(b) and not (Diplomacy.ReqS.result_kind(why) in ["offer_sent", "inbox"]):
				s._shake(b)
		elif ok != "":
			s.m.hud.show_toast(ok)
		s.rebuild())



func c_wars(cid: int) -> Array:
	var c: Country = s.gw.country_by_id(cid)
	var out: Array = []
	if c == null:
		return out
	for e: Variant in c.at_war.keys():
		var ec: Country = s.gw.country_by_id(int(e))
		if ec != null and not ec.eliminated:
			out.append(int(e))
	return out



func _partner(cid: int) -> bool:
	var dp: Diplomacy = s.dp
	var me: int = int(s.me)
	return cid != me and (dp.allied(me, cid) or dp.has_treaty(me, cid, "defense") or (dp.get("ally") != null and dp.ally.same(me, cid)))




func _tab_dog(cid: int, row: Dictionary, st: int) -> void :
	var dp: Diplomacy = s.dp
	var me: int = int(s.me)
	var sub: String = ""
	if st == Diplomacy.Rel.WAR or st == Diplomacy.Rel.TRUCE:
		sub = "все — после мира"
	elif (row["treaties"] as Array).has("alliance"):
		sub = "в обороне — сам, в вашу атаку — по вашему зову"
	var h: HBoxContainer = _sect("ДОГОВОРЫ", sub)
	if st == Diplomacy.Rel.WAR or st == Diplomacy.Rel.TRUCE:
		h.add_child(s._icon("wb_lock", 12))
		h.move_child(h.get_child(h.get_child_count() - 1), 1)
	var chips: = HBoxContainer.new()
	chips.name = "Treaties"
	chips.add_theme_constant_override("separation", 6)
	s.inner.add_child(chips)
	for k: String in Diplomacy.TREATY_KINDS:
		var ch: Button = s._treaty_chip(cid, k, row)
		chips.add_child(ch)
		s._chips[k] = ch
	if String(s.confirm_kind) != "" and Diplomacy.TREATY_INFO.has(String(s.confirm_kind)):
		s.inner.add_child(s._cancel_confirm(cid, String(s.confirm_kind)))
	var tens: Control = s._tension_line(cid)
	if tens != null:
		s.inner.add_child(tens)
	var rn: String = String(dp.rift_note(me, cid)) if dp.has_method("rift_note") else ""
	if rn != "":
		var rl: Label = _note(s.inner, rn, C_AMB, "icon_alliance")
		rl.name = "RiftNote"

	var more: Button = _ghost("")
	more.name = "MoreAlly"
	more.custom_minimum_size.y = 44
	s.inner.add_child(more)
	var hb: HBoxContainer = s._fill_box(more, 10, 2)
	hb.add_child(s._icon("icon_alliance", 20))
	hb.add_child(s._icon("icon_dip_vassal", 20))
	var l: Label = UiKit.lbl("АЛЬЯНС И ВАССАЛИТЕТ", 10, UiKit.TEXT, 2, 3)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(l)
	var r: Label = UiKit.lbl(_more_sub(cid), 9, UiKit.DIM, 1)
	r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.fit_lbl(r, [9])
	hb.add_child(r)
	hb.add_child(_arrow(90.0 if more_open else 0.0))
	more.pressed.connect( func() -> void :
		more_open = not more_open
		s.rebuild())
	if more_open:
		if GameConfig.alliances:
			s.inner.add_child(s._ally_row(cid))
		s.inner.add_child(s._subject_block(cid))


func _more_sub(cid: int) -> String:
	var dp: Diplomacy = s.dp
	var me: int = int(s.me)
	var parts: Array = []
	var al = dp.get("ally")
	if al != null and GameConfig.alliances:
		var a: Dictionary = al.of_country(cid)
		if not a.is_empty():
			parts.append(Loc.t("вы вместе") if al.same(me, cid) else Loc.t("в альянсе"))
		elif al.id_of(me) < 0:
			parts.append(Loc.t("можно основать"))
		else:
			parts.append(Loc.t("можно пригласить"))
	var o: Dictionary = dp.subject_options(me, cid)
	match String(o["status"]):
		"ours":
			parts.append(Loc.t("ваш вассал"))
		"theirs":
			parts.append(Loc.t("вы — вассал"))
		_:
			if String(o["why"]) != "" or float(o["ratio"]) < float(o["need_v"]):
				parts.append(Loc.t("вассал: нельзя"))
	return " · ".join(PackedStringArray(parts))




func _tab_mil(cid: int, row: Dictionary, st: int) -> void :
	if st == Diplomacy.Rel.WAR:
		_mil_war(cid, st)
		return
	var dp: Diplomacy = s.dp
	var me: int = int(s.me)
	var sw: Dictionary = _a().subject_wars(cid)
	if not sw.is_empty():
		_follow(cid, sw)
	var close: bool = dp.allied(me, cid) or (dp.get("ally") != null and dp.ally.same(me, cid))
	if close:
		_sky(cid, st)
		_pass(cid, st)
	else:
		_pass(cid, st)
		_sky(cid, st)
	var jw: Control = s._joint_war_block(cid, st)
	if jw != null:
		s.inner.add_child(jw)
	if s._can_call(cid):
		var cb: Button = UiKit.big("ПРИЗВАТЬ В ВОЙНУ", "red", "", 44.0, 11)
		cb.name = "CallTile"
		s._btn_icon(cb, "icon_dip_call")
		cb.pressed.connect( func() -> void :
			_send("player_call", [me, cid], "%s вступает в войну на вашей стороне" % s.gw.country_by_id(cid).name, cb))
		s.inner.add_child(cb)
	_guard(cid, st)
	_aggr(cid)
	if st != Diplomacy.Rel.TRUCE:
		_mil_aid(cid)
	_pressure(cid, row, st)
	_war(cid, st)



func _follow(cid: int, sw: Dictionary) -> void :
	var kind: String = Loc.t("МАРИОНЕТКА") if String(sw.get("kind", "")) == "puppet" else Loc.t("ВАССАЛ")
	var w: Array = sw.get("with", [])
	var names: PackedStringArray = []
	for e: Variant in w:
		names.append(String(s._cname_up(int(e))))
	_sect(Loc.t("%s СЛЕДУЕТ ЗА ВАМИ") % kind, "внешнюю политику решаете вы", UiKit.DIM)
	var pv: VBoxContainer = _card(Color(C_ALLY, 0.55), "Follow")
	_line(pv, "icon_dip_vassal", Loc.t("ВОЮЕТ ВМЕСТЕ С ВАМИ") if not names.is_empty() else Loc.t("ВАШИХ ВОЙН НЕТ"), (Loc.t("войны: %s") % [", ".join(names)]) if not names.is_empty() else Loc.t("мир — вместе с вами"), 
		C_PEACE if not names.is_empty() else UiKit.MUTED)
	for nw: Variant in sw.get("not", []):
		var pair: Array = nw
		_note(pv, Loc.t("%s — ещё нет: %s") % [String(s._cname_up(int(pair[0]))), String(pair[1])], C_AMB, "net_wait")


func _mil_war(cid: int, st: int) -> void :
	var ap = _a()
	var pr: Array = ap.pressing(cid)
	pr.erase(int(s.me))
	if not pr.is_empty():
		_sect("ДАВЛЕНИЕ НА НИХ", Loc.t("мира требуют: %d") % pr.size(), C_AMB)
		var pv: VBoxContainer = _card(Color(C_AMB, 0.6), "Pressure")
		var names: Array = []
		var mats: Dictionary = {}
		for x: int in pr:
			names.append(String(s._cname_up(x)))
			for r: Variant in ap.sanctions(x, cid):
				mats[Loc.t(String(Economy.RES_SHORT.get(String(r), String(r)))).to_lower()] = true
		var what: String = (Loc.t("санкции: %s") % [", ".join(PackedStringArray(mats.keys()))]) if not mats.is_empty() else Loc.t("эмбарго")
		_line(pv, "icon_dip_stop", ", ".join(PackedStringArray(names)), what, C_AMB)
	var cw: Control = s._call_allies_block(cid, st)
	if cw != null:
		s.inner.add_child(cw)



func _pass(cid: int, st: int) -> void :
	var dp: Diplomacy = s.dp
	var me: int = int(s.me)
	var ap = _a()
	_sect("ПРОХОД ВОЙСК")
	var pv: VBoxContainer = _card(Color(0, 0, 0, 0), "Passage")
	if st == Diplomacy.Rel.WAR or st == Diplomacy.Rel.TRUCE:
		_line(pv, "icon_treaty_passage", "ПРОХОД", "только в мире", UiKit.DIM)
		return
	var free: bool = dp.allied(me, cid) or (dp.get("ally") != null and dp.ally.same(me, cid))

	var us: bool = dp.has_passage(me, cid)
	var lv: int = ap.leaving(me, cid)
	var nu: int = ap.troops_on(me, cid)
	if lv >= 0:
		_line(pv, "icon_op_retreat", "МЫ → ИХ ЗЕМЛЯ", Loc.t("наши войска уходят к границе: %d осталось") % lv, C_AMB)
	elif free:
		_line(pv, "icon_treaty_passage", "МЫ → ИХ ЗЕМЛЯ", Loc.t("союзники проходят свободно%s") % [((Loc.t(" · наших отрядов там: %d") % nu) if nu > 0 else "")], C_PEACE)
	elif us:
		var them_too: bool = dp.has_passage(cid, me)
		_line(pv, "icon_treaty_passage", "МЫ → ИХ ЗЕМЛЯ", Loc.t("есть · наших отрядов там: %d") % nu, C_PEACE, "ОТКАЗАТЬСЯ", "ghost", 
			func() -> void : _arm("pass_us"))
		if confirm == "pass_us":
			_confirm(pv, Loc.t("Отказаться от прохода?%s%s −%d к отношениям.") % [(Loc.t(" Наши %d отр. уйдут к границе.") % nu) if nu > 0 else "", 
				Loc.t(" Их проход через нашу землю тоже закроется.") if them_too else "", int(Diplomacy.CANCEL_PENALTY.get("passage", 5))], "ОТКАЗАТЬСЯ", 
				func() -> void : _send("cancel_passage", [me, cid], "Проход закрыт"))
	elif not ap.t_offer(me, cid, "passage").is_empty():
		_line(pv, "icon_treaty_passage", "МЫ → ИХ ЗЕМЛЯ", "просьба отправлена · ждём ответа", C_AMB, "ЖДЁМ", "ghost").disabled = true
	elif String(ap.pass_wait(cid, me).get("kind", "")) == "revoke":
		var pw1: Dictionary = ap.pass_wait(cid, me)
		_line(pv, "icon_treaty_passage", "МЫ → ИХ ЗЕМЛЯ", String(pw1["why"]), C_AMB, "ПОЗЖЕ", "ghost").disabled = true
		_tick_last(pv, String(pw1.get("head", String(pw1["why"]).split("через ")[0] + "через ")), float(pw1["left"]))
	else:
		var b1: Button = null
		b1 = _line(pv, "icon_treaty_passage", "МЫ → ИХ ЗЕМЛЯ", "нет · войска и БПЛА не пройдут", UiKit.MUTED, "ПОПРОСИТЬ", "gold", 
			func() -> void : _send("propose_treaty", [me, cid, "passage"], "Право прохода получено", b1))
	_sep(pv)

	var them: bool = dp.has_passage(cid, me)
	var lv2: int = ap.leaving(cid, me)
	var nt: int = ap.troops_on(cid, me)
	if lv2 >= 0:
		_line(pv, "d331_pass_revoke", "ОНИ → НАША ЗЕМЛЯ", Loc.t("отозвано · их войска уходят к границе: %d осталось") % lv2, C_AMB)
	elif free:
		_line(pv, "d331_pass_offer", "ОНИ → НАША ЗЕМЛЯ", Loc.t("союзники проходят свободно%s") % [((Loc.t(" · их отрядов у нас: %d") % nt) if nt > 0 else "")], C_PEACE)
	elif them:
		var rv_cmd: String = ap.cmd(DipApiS.C_REVOKE)
		_line(pv, "d331_pass_offer", "ОНИ → НАША ЗЕМЛЯ", Loc.t("есть · их отрядов у нас: %d") % nt, C_TRUCE, "ОТОЗВАТЬ", "ghost", 
			func() -> void : _arm("pass_them"))
		if confirm == "pass_them":
			var tx: String = "Отозвать проход? " + ((Loc.t("Их %d отр. уйдут к ближайшей границе. ") % nt) if nt > 0 else "") + Loc.t("−%d к отношениям.") % int(Diplomacy.CANCEL_PENALTY.get("passage", 5))
			if rv_cmd == "":
				tx = Loc.t("Закрыть проход в обе стороны? −%d к отношениям.") % int(Diplomacy.CANCEL_PENALTY.get("passage", 5))
			_confirm(pv, tx, "ОТОЗВАТЬ", func() -> void :
				if rv_cmd != "":
					_send(rv_cmd, [me, cid], "Право прохода отозвано")
				else:
					_send("cancel_passage", [me, cid], "Проход закрыт"))
	elif nt > 0 and ap.has(DipApiS.C_EXPEL):
		_line(pv, "d331_pass_offer", "ОНИ → НАША ЗЕМЛЯ", Loc.t("их отрядов у нас без права: %d") % nt, C_WAR, "ВЫДВОРИТЬ", "ghost", 
			func() -> void : _send(ap.cmd(DipApiS.C_EXPEL), [me, cid], "Их войска уходят к границе"))
	elif not ap.t_offer(me, cid, "passage_give").is_empty():
		_line(pv, "d331_pass_offer", "ОНИ → НАША ЗЕМЛЯ", "предложено · ждём ответа", C_AMB, "ЖДЁМ", "ghost").disabled = true
	elif not ap.pass_wait(me, cid).is_empty():
		var pw2: Dictionary = ap.pass_wait(me, cid)
		_line(pv, "d331_pass_offer", "ОНИ → НАША ЗЕМЛЯ", String(pw2["why"]), C_AMB, "ПОЗЖЕ", "ghost").disabled = true
		_tick_last(pv, String(pw2.get("head", String(pw2["why"]).split("через ")[0] + "через ")), float(pw2["left"]))
	else:
		var oc: String = ap.cmd(DipApiS.C_OFFER_PASS)
		var b2: Button = null
		b2 = _line(pv, "d331_pass_offer", "ОНИ → НАША ЗЕМЛЯ", "нет", UiKit.MUTED, "ПРЕДЛОЖИТЬ", "green" if oc != "" else "soon", 
			func() -> void : _send(oc, [me, cid], "Они приняли право прохода", b2))
		b2.name = "PassageOffer"



func _sky(cid: int, st: int) -> void :
	var dp: Diplomacy = s.dp
	var me: int = int(s.me)
	var ap = _a()
	var close: bool = (dp.allied(me, cid) or (dp.get("ally") != null and dp.ally.same(me, cid))) and st != Diplomacy.Rel.WAR and st != Diplomacy.Rel.TRUCE
	var ready: bool = ap.sky_ready()
	var over: Dictionary = ap.sky(me, cid)
	var mine: Dictionary = ap.sky(cid, me)
	var on_o: bool = bool(over.get("on", false))
	var on_m: bool = bool(mine.get("on", false))
	var away: Array = ap.sky_away(cid)
	_sect("НЕБО", Loc.t("ваши ПВО на их земле — без войны") if close or on_o else "", C_SKY)
	if not close and not on_o and not on_m and away.is_empty() and not bool(over.get("pending", false)) and not bool(mine.get("pending", false)):
		var lv: VBoxContainer = _card(Color(0, 0, 0, 0), "Sky")
		var why: String = String(over.get("can", "")) if ready else ""
		_line(lv, "d331_sky", "ЗАКРЫТЬ НЕБО", (why.to_lower() if why != "" else Loc.t("только с союзником или альянсом")), UiKit.DIM)
		return
	var sv: VBoxContainer = _card(Color(C_SKY, 0.55) if on_o or on_m else Color(0, 0, 0, 0), "Sky")
	var end_c: String = ap.cmd(DipApiS.C_SKY_END)
	var off_c: String = ap.cmd(DipApiS.C_SKY_OFFER)
	var ask_c: String = ap.cmd(DipApiS.C_SKY_ASK)
	var home_c: String = ap.cmd(DipApiS.C_SKY_HOME)

	if on_o:
		var n: int = int(over.get("n", 0))
		var up: int = int(over.get("upkeep", 0))
		_line(sv, "d331_sky", "НАД НИМИ", Loc.t("закрыто вами · ваших ПВО там: %d%s") % [n, (Loc.t(" · %d/мин") % up) if up > 0 else ""], C_SKY, "СНЯТЬ НЕБО", "ghost" if end_c != "" else "soon", 
			func() -> void : _arm("sky_over"))
		if confirm == "sky_over":
			_confirm(sv, Loc.t("Снять небо? Их земля снова открыта ракетам и дронам врага. %s") % [((Loc.t("Ваши ПВО (%d) не разбираются — едут на вашу землю.") % n) if n > 0 else Loc.t("Ваших ПВО там нет."))], 
				"СНЯТЬ НЕБО", func() -> void : _send(end_c, [me, cid, true], "Небо снято: ваши ПВО едут домой"))
		var pb: Button = UiKit.big("ПОСТАВИТЬ ПВО У НИХ", "blue", "", 44.0, 10)
		pb.name = "SkyBuild"
		s._btn_icon(pb, "icon_ad_patriot")
		pb.pressed.connect( func() -> void : _sky_build(cid))
		sv.add_child(pb)
	elif bool(over.get("pending", false)) and not bool(over.get("asked", false)):
		_line(sv, "d331_sky", "НАД НИМИ", Loc.t("предложено · ждём ответа %s") % s._mmss(float(over.get("left", 0.0))), C_AMB, "ОТОЗВАТЬ", "ghost" if end_c != "" else "soon", 
			func() -> void : _send(end_c, [me, cid, true], "Предложение отозвано"))
		_tick_last(sv, "предложено · ждём ответа ", float(over.get("left", 0.0)))
	elif bool(over.get("pending", false)):
		_line(sv, "d331_sky", "НАД НИМИ", "они просят закрыть небо над ними · ответ во «Входящих»", C_AMB, "ОТВЕТИТЬ", "gold", func() -> void : _set_tab("req"))
	else:
		var can: String = String(over.get("can", "")) if ready else ""
		var b1: Button = null
		b1 = _line(sv, "d331_sky", "НАД НИМИ", Loc.t("открыто · ваши ПВО прикроют их без войны") if can == "" else can.to_lower(), UiKit.MUTED if can == "" else UiKit.DIM, "ЗАКРЫТЬ НЕБО", 
			"blue" if off_c != "" and can == "" else "soon", func() -> void : _send(off_c, [me, cid], "Небо закрыто", b1))

	for a: Dictionary in away:
		var fid: int = int(a.get("fid", -1))
		if int(a.get("trip", -1)) >= 0:
			_line(sv, "icon_ad_patriot", String(a.get("title", "ПВО")).to_upper(), Loc.t("сворачивается и едет домой") if int(a.get("trip", -1)) == 0 else Loc.t("колонна едет домой · уязвима в пути"), C_AMB)
			continue
		var hb2: Button = null
		hb2 = _line(sv, "icon_ad_patriot", String(a.get("title", "ПВО")).to_upper(), Loc.t("ваше на их земле%s") % [("" if bool(a.get("alive", true)) else Loc.t(" · разрушено"))], UiKit.MUTED, 
			"УВЕЗТИ ДОМОЙ", "ghost" if home_c != "" else "soon", func() -> void : _send(home_c, [me, fid], "ПВО едет на вашу землю", hb2))
		if hb2 != null:
			hb2.name = "SkyHome"
	_sep(sv)

	if on_m:
		_line(sv, "d331_req_sky_me", "НАДО МНОЙ", Loc.t("закрыто ими · их ПВО у вас: %d") % int(mine.get("n", 0)), C_SKY, "ОТКАЗАТЬСЯ", "ghost" if end_c != "" else "soon", 
			func() -> void : _arm("sky_me"))
		if confirm == "sky_me":
			_confirm(sv, Loc.t("Отказаться от их неба? Ваша земля останется без их прикрытия, их ПВО (%d) уедут к ним домой.") % int(mine.get("n", 0)), "ОТКАЗАТЬСЯ", 
				func() -> void : _send(end_c, [me, cid, false], "Их небо над вами снято"))
	elif bool(mine.get("pending", false)) and bool(mine.get("asked", false)):
		_line(sv, "d331_req_sky_me", "НАДО МНОЙ", Loc.t("просьба отправлена · ждём ответа %s") % s._mmss(float(mine.get("left", 0.0))), C_AMB, "ОТОЗВАТЬ", "ghost" if end_c != "" else "soon", 
			func() -> void : _send(end_c, [me, cid, false], "Просьба отозвана"))
		_tick_last(sv, "просьба отправлена · ждём ответа ", float(mine.get("left", 0.0)))
	elif bool(mine.get("pending", false)):
		_line(sv, "d331_req_sky_me", "НАДО МНОЙ", "они предлагают закрыть небо над вами", C_AMB, "ОТВЕТИТЬ", "gold", func() -> void : _set_tab("req"))
	else:
		var can2: String = String(mine.get("can", "")) if ready else ""
		var b2: Button = null
		b2 = _line(sv, "d331_req_sky_me", "НАДО МНОЙ", Loc.t("открыто") if can2 == "" else can2.to_lower(), UiKit.MUTED if can2 == "" else UiKit.DIM, "ПОПРОСИТЬ", 
			"gold" if ask_c != "" and can2 == "" else "soon", func() -> void : _send(ask_c, [me, cid], "Просьба отправлена", b2))
	_note(sv, "Враг союзника может сбивать ваши ПВО над ним — это не объявление войны вам.", UiKit.DIM, "net_warn")



func _tick_last(parent: Control, prefix: String, left: float) -> void :
	var hb: Node = parent.get_child(parent.get_child_count() - 1)
	if hb == null or hb.get_child_count() < 2:
		return
	var v: Node = hb.get_child(1)
	if v != null and v.get_child_count() >= 2 and v.get_child(1) is Label:
		s._timers.append([v.get_child(1), null, s.gw.game_time + left, 0.0, prefix])



func _sky_build(cid: int) -> void :
	var gw: GameWorld = s.gw
	var me: int = int(s.me)
	var hud = s.hud
	var target: Vector2 = Vector2.INF
	if s.dp.has_method("sky_spot"):
		var cell: Vector2i = s.dp.sky_spot(me, cid, Facility.Kind.AD_SAM)
		if cell.x >= 0:
			target = Vector2(cell) * float(GameWorld.CELL)
	var c: Country = gw.country_by_id(cid)
	if target == Vector2.INF and c != null and c.capital_id >= 0:
		target = Vector2(gw.cities[c.capital_id].center) * float(GameWorld.CELL)
	s.close_sheet()
	if hud.has_method("_on_tab_tap"):
		hud._on_tab_tap(3)
	var cam = s.m.get("cam")
	if cam != null and target != Vector2.INF:
		cam.center_on(target)
		s.m.set("cam_lock", false)
	hud.show_toast(Loc.t("Небо закрыто: выберите ПВО и поставьте на земле страны %s") % (c.name if c != null else ""))





func _guard(cid: int, st: int) -> void :
	if st == Diplomacy.Rel.WAR or st == Diplomacy.Rel.TRUCE:
		return
	var dp: Diplomacy = s.dp
	var me: int = int(s.me)
	var ap = _a()
	var g: Dictionary = ap.guard_of(cid)
	var gin: Dictionary = ap.guard_in(cid)
	var wars: Array = []
	for e: int in c_wars(cid):
		if e != me and not _partner(e) and not dp.at_war(me, e) and int(dp.war_by.get(Diplomacy.key(cid, e), -1)) != cid:
			wars.append(e)
	if g.is_empty() and gin.is_empty() and wars.is_empty():
		return
	var ally: bool = dp.allied(me, cid) or (dp.get("ally") != null and dp.ally.same(me, cid))
	var vs: int = int(g.get("vs", 0)) if not g.is_empty() else (int(wars[0]) if not wars.is_empty() else 0)
	var nu: int = int(g.get("troops", 0))
	var more: String = (" +%d" % (wars.size() - 1)) if wars.size() > 1 else ""
	_sect("АРМИЯ НА ЗАЩИТУ", (Loc.t("враг: %s%s · без войны") % [s._cname_up(vs), more]) if vs > 0 and s.gw.country_by_id(vs) != null else Loc.t("без вступления в войну"), UiKit.MUTED)
	var gv: VBoxContainer = _card(Color(C_PEACE, 0.5) if nu > 0 else Color(0, 0, 0, 0), "Guard")
	var send_c: String = ap.cmd(DipApiS.C_GUARD)
	var end_c: String = ap.cmd(DipApiS.C_GUARD_END)
	if not gin.is_empty():
		var nt: int = int(gin.get("troops", 0))
		var lft: float = float(gin.get("left", -1.0))
		_line(gv, "d331_req_station", "ИХ АРМИЯ У ВАС", Loc.t("%s · отрядов: %d%s") % [Loc.t("стоит по вашей просьбе") if String(gin.get("kind", "")) == "station" else Loc.t("защищает вас"), 
			nt, (Loc.t(" · ещё %s") % s._mmss(lft)) if lft > 0.0 else ""], C_PEACE, "ОТОЗВАТЬ", "ghost", func() -> void : _arm("guard_in"))
		if confirm == "guard_in":
			_confirm(gv, Loc.t("Отозвать разрешение? Их отряды (%d) уйдут к границе; враг сможет тронуть вас без их ответа.") % nt, "ОТОЗВАТЬ", 
				func() -> void : _send(end_c, [me, cid], "Их армия уходит домой"))
		if not g.is_empty() or not wars.is_empty():
			_sep(gv)
	if not g.is_empty():
		var left: float = float(g.get("left", -1.0))
		var lt: String = (Loc.t(" · право ещё %s") % s._mmss(left)) if left > 0.0 else ""
		var station: bool = String(g.get("kind", "")) == "station"
		var gone: bool = int(g.get("gid", -1)) >= 0 or bool(g.get("sent", false))
		if nu > 0 or gone:
			_line(gv, "d331_req_defend", Loc.name(String(g.get("name", "АРМИЯ"))).to_upper(), (Loc.t("на их земле · отрядов: %d · вы управляете%s") % [nu, lt]) if nu > 0 else Loc.t("идёт к ним · вы управляете ею%s") % [lt], 
				C_PEACE if nu > 0 else C_AMB, "ВЕРНУТЬ", "ghost", func() -> void : _arm("guard_end"))
			if confirm == "guard_end":
				_confirm(gv, "Вернуть армию домой? Разрешение закончится, отряды уйдут с их земли к границе.", "ВЕРНУТЬ", 
					func() -> void : _send(end_c, [me, cid], "Армия возвращается домой"))
			_note(gv, Loc.t("Растяжка: тронет её враг — вы вступите в войну.") if station else Loc.t("Агрессор может объявить вам войну — бот решает сам, не всегда."), C_RED_T, "net_warn")
			return
		_line(gv, "d331_req_defend", "РАЗРЕШЕНИЕ ЕСТЬ", (Loc.t("ждут ваши войска") if station else Loc.t("армия ещё не отправлена")) + lt, C_AMB, 
			"СВЕРНУТЬ" if guard_open else "ВЫБРАТЬ…", "ghost" if guard_open else "green", func() -> void :
				guard_open = not guard_open
				s.rebuild())
	elif wars.is_empty():
		return
	elif ally:
		_line(gv, "d331_req_defend", "ОТПРАВИТЬ АРМИЮ", "союзнику согласие не нужно · вы ею управляете там", UiKit.MUTED, 
			"СВЕРНУТЬ" if guard_open else "ВЫБРАТЬ…", "ghost" if guard_open else "green", func() -> void :
				guard_open = not guard_open
				s.rebuild())
	else:
		var waiting: bool = false
		for q: Dictionary in ap.reqs_between(me, cid):
			if String(q.get("kind", "")) == "guard":
				waiting = true
		if waiting:
			_line(gv, "d331_req_defend", "ОТПРАВИТЬ АРМИЮ", "просили согласие · ждём ответа", C_AMB)
			return
		var o: Dictionary = ap.outlook(cid, "guard", vs if wars.size() == 1 else -1)
		var a: String = String(o.get("ans", ""))
		var lk: bool = a == "lock" or a == "wait"
		var bq: Button = null
		bq = _line(gv, "d331_req_defend", "ОТПРАВИТЬ АРМИЮ", (Loc.t("нужно их согласие · %s") % [String(_ans_text(o)[0])]) if not lk else String(o.get("why", "нельзя")), 
			UiKit.MUTED if not lk else UiKit.DIM, "ПОПРОСИТЬ", "gold" if not lk else "stone", func() -> void :
				if lk:
					s._shake(bq)
					return
				comp_kind = "guard"
				comp_x = vs if wars.size() == 1 else -1
				comp = 3 if wars.size() == 1 else 2
				s.rebuild(false))
		bq.name = "GuardAsk"
		if lk:
			bq.disabled = true
		_note(gv, "Без войны: ваша армия бьёт врага только на их земле. Агрессор может объявить вам войну.", UiKit.DIM, "net_warn")
		return
	if not guard_open:
		_note(gv, "Агрессор может объявить вам войну — бот решает сам, не всегда.", UiKit.DIM, "net_warn")
		return
	_guard_pick(gv, cid, vs, send_c, wars.size())




func _guard_pick(gv: VBoxContainer, cid: int, vs: int, send_c: String, n_foes: int = 1) -> void :
	var gw: GameWorld = s.gw
	var me: int = int(s.me)
	var opts: Array = []
	for gg: Dictionary in AG.groups(gw, me):
		var fl: PackedInt32Array = gg.get("fids", PackedInt32Array())
		var men: int = 0
		for fid: int in fl:
			var f0: Facility = AG.fac(gw, fid)
			if f0 != null:
				men += gw.ops._army(f0).size()
		opts.append(["g%d" % int(gg["id"]), Loc.name(String(gg.get("name", "ГРУППА"))).to_upper(), (Loc.t("армий: %d · солдат: %d") % [fl.size(), men]) if men > 0 else Loc.t("нет солдат — сначала наберите"), int(gg["id"]) if men > 0 else null])
	var nf: int = 0
	for f: Facility in gw.mil.facilities:
		if nf >= 4:
			break
		if f.kind != Facility.Kind.BARRACKS or f.country_id != me or not gw.mil.alive(f) or int(f.get("group_id")) >= 0:
			continue
		var n: int = gw.ops._army(f).size()
		if n <= 0:
			continue
		nf += 1
		opts.append(["f%d" % f.id, Loc.t("АРМИЯ №%d") % f.army_no, Loc.t("солдат: %d%s") % [n, Loc.t(" · занята") if gw.ops.list.has(f) else ""], f])
	if opts.is_empty():
		_note(gv, "Нет армий с солдатами: постройте казарму и наберите войска.", UiKit.DIM, "icon_hint")
		return
	var vn: String = s.gw.country_by_id(vs).name if vs > 0 and s.gw.country_by_id(vs) != null else Loc.t("агрессор")
	for op: Array in opts:
		_sep(gv)
		var key: String = "guard:" + String(op[0])
		var arg: Variant = op[3]
		var ttl: String = String(op[1])
		var b: Button = _line(gv, "d331_req_defend", ttl, String(op[2]), UiKit.MUTED if arg != null else UiKit.DIM, "ОТПРАВИТЬ", "green" if arg != null else "stone", func() -> void : _arm(key))
		b.name = "GuardSend_" + String(op[0])
		b.disabled = arg == null
		if confirm == key and arg != null:
			_confirm(gv, (Loc.t("«%s» → %s: защита без войны, вы управляете армией там. Враг (%s) может объявить вам войну.") % [ttl, Loc.name(s.gw.country_by_id(cid).name), vn])
				+ (Loc.t(" Армия бьёт всех нападающих на их земле.") if n_foes > 1 else ""), 
				"ОТПРАВИТЬ", func() -> void :
					guard_open = false
					_send(send_c, [me, cid, arg, vs], Loc.t("Армия идёт на защиту: %s") % Loc.name(s.gw.country_by_id(cid).name)), "green")




func _mil_aid(cid: int) -> void :
	var ap = _a()
	_sect("ВОЕННАЯ ПОМОЩЬ", "нужно место у них")
	var ar: = HBoxContainer.new()
	ar.name = "MilAid"
	ar.add_theme_constant_override("separation", 6)
	s.inner.add_child(ar)
	var have: Dictionary = {}
	for o: Dictionary in ap.mil_aid(cid):
		have[String(o["what"])] = o
	for w: String in ["drones", "missile_b", "missile_c", "missile_sam"]:
		var spec: Array = AID_TILE[w]
		var o: Dictionary = have.get(w, {})
		var soon: bool = o.is_empty()
		var why: String = String(o.get("why", ""))
		var n_have: int = int(o.get("have", 0))
		var room: int = int(o.get("room", 0))
		var sub: String = Loc.t("скоро") if soon else (_short_why(why) if why != "" else (Loc.t("нет у вас") if n_have <= 0 else Loc.t("%d · место %d") % [n_have, room]))
		var lock: bool = soon or why != "" or n_have <= 0 or int(o.get("max", 0)) <= 0
		if not lock and room <= 0:
			sub = "нет места"
		var sel: bool = mil_open and String(s.aid_what) == w
		var t: Button = s._tile(String(spec[0]), String(spec[1]), "disabled" if lock else ("gold" if sel else "stone"), 52.0, sub, UiKit.DIM if lock else UiKit.GOLD)
		t.name = "Aid_" + w
		if lock:
			var li: TextureRect = s._icon("wb_lock", 12)
			t.add_child(li)
			t.resized.connect( func() -> void : li.position = Vector2(t.size.x - 15, 3))
		t.pressed.connect( func() -> void :
			if lock:
				s._shake(t)
				s.m.hud.show_toast("Скоро: ракеты ПВО в помощи" if soon else ("%s: %s" % [String(spec[1]).capitalize(), why if why != "" else sub]))
				return
			if sel:
				mil_open = false
			else:
				mil_open = true
				s.aid_what = w
				s.aid_n = mini(int(o.get("max", 1)), 2)
			s.rebuild())
		ar.add_child(t)
	if mil_open:
		s.aid_only = [String(s.aid_what)]
		var pk: Control = s._aid_picker(cid)
		s.aid_only = []
		s.inner.add_child(pk)



func _short_why(why: String) -> String:
	var w: String = why.to_lower()
	for pair: Array in [["дронопорт", "нет мест"], ["отрк", "нет ОТРК"], ["зрк", "нет ЗРК"], ["носител", "нет носителя"], ["полон", "склад полон"], ["пусков", "нет пусковой"]]:
		if w.contains(String(pair[0])):
			return String(pair[1])
	return why if why.length() <= 12 else why.left(11) + "…"



func _pressure(cid: int, row: Dictionary, st: int) -> void :
	var ub: Button = UiKit.big("УЛЬТИМАТУМ", "stone", "", 44.0, 11)
	ub.name = "UltBtn"
	s._btn_icon(ub, "icon_ultimatum")
	var ok: bool = bool(row["can_demand"])
	ub.disabled = not ok
	ub.pressed.connect( func() -> void :
		s.hud.ult = {"to": cid, "kind": "money", "n": 300, "res": "metal", "conseq": "embargo", "opt": -1, "new": true}
		s.hud.open_ultimatum())
	s.inner.add_child(ub)
	if not ok and st == Diplomacy.Rel.ALLIANCE:
		_note(s.inner, "Союзнику ультиматум не ставят — сначала расторгните союз.", UiKit.DIM, "wb_lock")



func _war(cid: int, st: int) -> void :
	var dp: Diplomacy = s.dp
	var gw: GameWorld = s.gw
	var me: int = int(s.me)
	var ap = _a()
	var h: HBoxContainer = _sect("ВОЙНА")
	if st == Diplomacy.Rel.TRUCE:
		var t_end: float = float(dp.truce_until.get(Diplomacy.key(me, cid), gw.game_time))
		var tl: Label = UiKit.lbl(Loc.t("перемирие: %s") % s._mmss(t_end - gw.game_time), 9, C_TRUCE, 2)
		h.add_child(tl)
		s._timers.append([tl, null, t_end, 0.0, "перемирие: "])
	var blk: Dictionary = ap.war_block(me, cid)
	if not blk.is_empty():
		var p: = PanelContainer.new()
		p.name = "WarLocked"
		p.add_theme_stylebox_override("panel", UiKit.sb("wb_btn_stone_p", 10, 4))
		p.custom_minimum_size.y = 44
		s.inner.add_child(p)
		var hb: = HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 8)
		p.add_child(hb)
		hb.add_child(s._icon("wb_lock", 14))
		hb.add_child(UiKit.lbl("ВОЙНА НЕЛЬЗЯ", 12, UiKit.DIM, 2, 4))
		var why: String = String(blk.get("why", ""))
		var wl: Label = _note(s.inner, why.left(1).to_upper() + why.substr(1) + ".", C_RED_T)
		wl.name = "WarBlock"
		var fix: String = String(blk.get("fix", ""))
		var fb: Button = null
		match fix:
			"passage":
				var rc: String = ap.cmd(DipApiS.C_REVOKE)
				if rc != "" and int(blk.get("land", -1)) == me:
					fb = _ghost("ОТОЗВАТЬ ПРОХОД")
					var who: int = int(blk.get("who", cid))
					fb.pressed.connect( func() -> void : _send(rc, [me, who], "Право прохода отозвано: их войска уходят", fb))
			"expel":
				var ec: String = ap.cmd(DipApiS.C_EXPEL)
				if ec != "":
					fb = _ghost("ВЫДВОРИТЬ")
					var who2: int = int(blk.get("who", cid))
					fb.pressed.connect( func() -> void : _send(ec, [me, who2], "Их войска уходят к границе", fb))
			"recall":
				var rcc: String = ap.cmd(DipApiS.C_RECALL)
				if rcc != "":
					fb = _ghost("ВЫВЕСТИ ВОЙСКА")
					var land: int = int(blk.get("land", cid))
					fb.pressed.connect( func() -> void : _send(rcc, [me, land], "Наши войска уходят к границе", fb))
			"alliance":
				var wa: int = int(blk.get("who", cid))
				if s.dp.allied(me, wa):
					fb = UiKit.big("РАЗОРВАТЬ СОЮЗ", "red", "", 44.0, 11)
					fb.pressed.connect( func() -> void :
						fb.disabled = true
						s._dp("break_alliance", [me, wa], func(_w: String) -> void : s.rebuild()))
		if fb != null:
			fb.name = "WarBlockFix"
			s.inner.add_child(fb)
		return
	var nap: bool = dp.has_treaty(me, cid, "nap") or dp.has_treaty(me, cid, "defense")
	var ally: bool = st == Diplomacy.Rel.ALLIANCE
	var title: String = Loc.t("ВОЙНА (ВЕРОЛОМНО)") if nap else (Loc.t("ВОЙНА СОЮЗНИКУ") if ally else Loc.t("ОБЪЯВИТЬ ВОЙНУ"))
	var hold: Control = s._hold_bar(title, nap or ally, func() -> void :
		if gw.player.eliminated or dp.at_war(me, cid):
			return
		UiKit.snd("ui_error")
		s._dp("declare_war", [me, cid, "player"], func(why2: String) -> void :
			if why2 != "":
				s.m.hud.show_toast(why2)
			s.rebuild()))
	hold.name = "WarHold"
	s.inner.add_child(hold)
	var pen: String = "−60 к отношениям с ними, все договоры сгорят"
	if nap:
		pen = "Вероломство: −15 к отношениям со всеми странами"
	elif ally:
		pen = "Союз и договоры сгорят: −60 с ними, их союзники против вас"
	_note(s.inner, pen, C_RED_T if (nap or ally) else UiKit.DIM)




func _tab_trade(cid: int, row: Dictionary, st: int) -> void :
	if st == Diplomacy.Rel.WAR:
		var wv: VBoxContainer = _card(Color(0, 0, 0, 0), "NoTrade")
		_line(wv, "icon_treaty_embargo", "ТОРГОВЛИ НЕТ — ВОЙНА", "санкции и эмбарго — против стран, с кем вы в мире", UiKit.MUTED)
		_note(wv, "Давить на агрессора лучше чужими руками: попросите союзников «прекратить войну» — их санкции бьют по нему.", UiKit.DIM, "icon_dip_call")
		return
	if s._human_to(cid):
		_contracts(cid)
	_aggr(cid)
	if st != Diplomacy.Rel.TRUCE:
		_sect("ПОМОЩЬ", "деньги и сырьё · отношения растут")
		if DipApiS.MIL_AID.has(String(s.aid_what)):
			s.aid_what = "money"
		s.aid_not = DipApiS.MIL_AID
		var pk: Control = s._aid_picker(cid)
		s.aid_not = []
		s.inner.add_child(pk)
	_sanctions(cid, row)
	_embargo(cid, row)



func _aggr(cid: int) -> void :
	var dp: Diplomacy = s.dp
	var me: int = int(s.me)
	var ap = _a()
	for v: int in c_wars(cid):
		if not _partner(v) or dp.at_war(me, cid):
			continue
		var pv: VBoxContainer = _card(Color(C_AMB, 0.7), "StopWar")
		var mine: Dictionary = {}
		for q: Dictionary in ap.reqs_between(me, cid):
			if String(q.get("kind", "")) == "stop_war":
				mine = q
		var title: String = Loc.t("ИХ ЖЕРТВА: %s") % s._cname_up(v)
		var wait: float = ap.req_wait(cid, "stop_war")
		if not mine.is_empty():
			var cc: String = ap.cmd(DipApiS.C_REQ_CANCEL)
			var qid: Variant = mine.get("id", -1)
			_line(pv, "icon_dip_stop", title, "потребовали · ждём ответа", C_AMB, "ОТОЗВАТЬ", "ghost" if cc != "" else "soon", 
				func() -> void : _send(cc, [me, qid], "Требование отозвано"))
		elif wait > 0.0:
			var sb: Button = null
			sb = _line(pv, "icon_dip_stop", title, Loc.t("отказали · повтор через %s") % s._mmss(wait), C_RED_T, Loc.t("К САНКЦИЯМ") if tab != "trade" else "", "gold", 
				func() -> void : _set_tab("trade"))
			_tick_last(pv, "отказали · повтор через ", wait)
		else:
			var vv: int = v
			var o: Dictionary = ap.outlook(cid, "stop_war", v)
			var lk: bool = String(o.get("ans", "")) == "lock"
			var rb: Button = null
			rb = _line(pv, "icon_dip_stop", title, (Loc.t("ваш партнёр · прогноз: %s") % [String(_ans_text(o)[0])]) if not lk else String(o.get("why", "")), UiKit.MUTED if not lk else UiKit.DIM, 
				"ПОТРЕБОВАТЬ МИРА", "gold" if not lk else "stone", func() -> void :
					if lk:
						s._shake(rb)
						return
					comp = 3
					comp_kind = "stop_war"
					comp_x = vv
					s.rebuild(false))
			rb.name = "StopWarAsk"
			rb.disabled = lk
		var others: PackedStringArray = []
		for pe: Dictionary in ap.press_on(cid):
			if int(pe.get("by", -1)) != me and int(pe.get("v", -1)) == v:
				others.append("%s (%s)" % [Loc.name(s.gw.country_by_id(int(pe["by"])).name), Loc.t("эмбарго") if bool(pe.get("embargo", false)) else Loc.t("санкции")])
		if not others.is_empty():
			_note(pv, Loc.t("Уже давят: %s") % [", ".join(others)], C_AMB, "icon_dip_stop")
		_note(pv, "Отказ — не война: давите санкциями на материал, потом полным эмбарго — до перемирия. Снимутся сами после мира.", UiKit.DIM, "icon_treaty_embargo")
		return



func _sanctions(cid: int, row: Dictionary) -> void :
	var me: int = int(s.me)
	var ap = _a()
	var emb: bool = bool(row["embargo_out"])
	var ready: bool = ap.sanct_ready()
	var grid: Array = ap.sanction_grid(cid)
	var on: Array = ap.sanctions(me, cid)
	var base_why: String = ""
	for gi: Dictionary in grid:
		if not bool(gi.get("on", false)) and String(gi.get("why", "")) != "" and not bool(gi.get("cap", false)):
			base_why = String(gi["why"])
			break
	var sub: String = "не продаём и не покупаем выбранное"
	var subc: Color = UiKit.MUTED
	if emb:
		sub = "полное эмбарго: не продаём ничего"
		subc = C_WAR
	elif not ready:
		sub = "скоро"
		subc = UiKit.DIM
	elif base_why != "":
		sub = base_why.to_lower()
		subc = UiKit.DIM
	var hs: HBoxContainer = _sect("САНКЦИИ", sub, subc)
	hs.add_child(s._icon("d331_sanct_16", 16))
	hs.move_child(hs.get_child(hs.get_child_count() - 1), 0)
	var g: = GridContainer.new()
	g.name = "Sanctions"
	g.columns = 4
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	s.inner.add_child(g)
	var scarce: Array = row.get("scarce", [])
	var info: Dictionary = {}
	for gi2: Dictionary in grid:
		info[String(gi2["res"])] = gi2
	for r: String in Economy.TRADE_RES:
		var gi3: Dictionary = info.get(r, {})
		var act: bool = on.has(r)
		var stg: bool = stage.has(r)
		var sc: bool = bool(gi3.get("scarce", scarce.has(r)))
		var tsub: String = Loc.t("дефицит") if sc else ""
		if stg:
			tsub = Loc.t("снять") if act else Loc.t("ввести")
		var locked: bool = emb or not ready or (base_why != "" and not act)
		var b: Button = s._tile(String(Economy.RES_ICONS.get(r, "res_metal")), String(Economy.RES_SHORT.get(r, r)), "disabled" if locked and not act else "slot", 44.0, tsub, UiKit.GOLD)
		b.name = "S_" + r
		if act and not stg:
			b.add_child(s._rim(C_WAR))
			var mk: TextureRect = UiKit.icon_rect("d331_sanct_mark", 12.0)
			mk.custom_minimum_size = Vector2(12, 12)
			mk.size = Vector2(12, 12)
			mk.position = Vector2(-2, -2)
			b.add_child(mk)
			(b.get_node("V/L") as Label).add_theme_color_override("font_color", Color("ff9f8a"))
		elif stg:
			b.add_child(s._rim(UiKit.GOLD))
			b.add_child(s._corner("icon_minus" if act else "corner_plus"))
		var rr: String = r
		var why_r: String = String(gi3.get("why", ""))
		b.pressed.connect( func() -> void :
			if emb:
				s._shake(b)
				s.m.hud.show_toast("Эмбарго уже запрещает всю торговлю с ними")
				return
			if not ready:
				s._shake(b)
				s.m.hud.show_toast("Скоро: санкции на отдельный материал")
				return
			if stage.has(rr):
				stage.erase(rr)
			elif not act and why_r != "" and not bool(gi3.get("cap", false)):
				s._shake(b)
				s.m.hud.show_toast(why_r)
				return
			else:
				var pv0: Dictionary = ap.sanction_preview(cid, _want(on, rr))
				if bool(pv0.get("cap", false)):
					s._shake(b)
					s.m.hud.show_toast(String(pv0["why"]))
					return
				stage[rr] = true
			s.rebuild())
		g.add_child(b)
	if not stage.is_empty():
		var want: Array = _want(on, "")
		var pv: Dictionary = ap.sanction_preview(cid, want)
		var cr: = HBoxContainer.new()
		cr.name = "SanctApply"
		cr.add_theme_constant_override("separation", 6)
		s.inner.add_child(cr)
		var txt: String = String(pv.get("text", ""))
		var go: Button = UiKit.big(txt if txt != "" else Loc.t("ПРИМЕНИТЬ"), "gold", "", 44.0, 10)
		go.name = "SanctGo"
		go.clip_text = true
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.disabled = String(pv.get("why", "")) != ""
		go.pressed.connect( func() -> void :
			stage.clear()
			_send(ap.tcmd("set_sanctions"), [me, cid, want], "Санкции введены" if not (pv.get("add", []) as Array).is_empty() else "Санкции сняты", go, DipApiS.TRD))
		cr.add_child(go)
		var rs: Button = _ghost("СБРОС")
		rs.custom_minimum_size.x = 72
		rs.pressed.connect( func() -> void :
			stage.clear()
			s.rebuild())
		cr.add_child(rs)
		if String(pv.get("why", "")) != "":
			_note(s.inner, String(pv["why"]), C_RED_T, "wb_lock")



func _want(on: Array, extra: String) -> Array:
	var w: Array = on.duplicate()
	var keys: Array = stage.keys()
	if extra != "":
		keys.append(extra)
	for k: Variant in keys:
		var r: String = String(k)
		if w.has(r):
			w.erase(r)
		else:
			w.append(r)
	return w


func _embargo(cid: int, row: Dictionary) -> void :
	var me: int = int(s.me)
	var emb: bool = bool(row["embargo_out"])
	if emb:
		var eb: Button = _ghost("СНЯТЬ ЭМБАРГО")
		eb.name = "EmbargoOff"
		s._btn_icon(eb, "icon_treaty_embargo")
		eb.pressed.connect( func() -> void : _arm("emb"))
		s.inner.add_child(eb)
		if confirm == "emb":
			_confirm(s.inner, "Снять эмбарго? Торговля с ними откроется.", "СНЯТЬ", func() -> void :
				_send("set_embargo", [me, cid, false], "Эмбарго снято"))
	else:
		var hold: Control = s._hold_bar("ПОЛНОЕ ЭМБАРГО", false, func() -> void :
			_send("set_embargo", [me, cid, true], "Эмбарго введено"))
		hold.name = "EmbargoHold"
		var hb: Node = hold.get_child(2) if hold.get_child_count() > 2 else null
		if hb != null and hb.get_child(0) is TextureRect:
			UiKit.set_icon(hb.get_child(0) as TextureRect, "d331_embargo", 24)
		s.inner.add_child(hold)
	var first: int = 8
	var more: int = 4
	var tr = _a().trd()
	if tr != null:
		var cm: Dictionary = (tr.get_script() as Script).get_script_constant_map()
		first = absi(int(cm.get("SANCT_OP_FIRST", -8)))
		more = absi(int(cm.get("SANCT_OP_MORE", -4)))
	_note(s.inner, Loc.t("Санкции: первый материал −%d к отношениям, следующие −%d; эмбарго −20. «Дефицит» бьёт сильнее.") % [first, more], UiKit.DIM)



func _contracts(cid: int) -> void :
	var me: int = int(s.me)
	var ap = _a()
	_sect("КОНТРАКТЫ", "только между живыми игроками онлайн", C_SKY)
	var list: Array = ap.contracts(cid)
	var end_c: String = ap.tcmd("contract_cancel")
	var ans_c: String = ap.tcmd("contract_answer")
	for i: int in mini(3, list.size()):
		var k: Dictionary = list[i]
		var st: String = String(k.get("state", ""))
		var kid: int = int(k.get("id", -1))
		var mine: bool = int(k.get("by", me)) == me
		var title: String = String(k.get("text", "")).to_upper()
		var cv: VBoxContainer = _card(Color(C_AMB, 0.6) if st == "offer" else (Color(C_SKY, 0.4) if st == "on" else Color(0, 0, 0, 0)), "Contract%d" % i)
		var key: String = "con:%d" % kid
		match st:
			"offer":
				var left: float = float(k.get("answer_in", 0.0))
				if mine:
					_line(cv, "d331_contract", title, Loc.t("ждёт ответа · %s") % s._mmss(left), C_AMB, "ОТОЗВАТЬ", "ghost" if end_c != "" else "soon", 
						func() -> void : _send(end_c, [me, kid, false], "Предложение отозвано", null, DipApiS.TRD))
					_tick_last(cv, "ждёт ответа · ", left)
				else:
					_line(cv, "d331_contract", title, Loc.t("предлагают вам · ответ до %s") % s._mmss(left), C_AMB)
					_tick_last(cv, "предлагают вам · ответ до ", left)
					var br: = HBoxContainer.new()
					br.add_theme_constant_override("separation", 6)
					cv.add_child(br)
					var no: Button = _ghost("ОТКАЗАТЬ")
					no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					no.pressed.connect( func() -> void : _send(ans_c, [me, kid, false], "Отказано", no, DipApiS.TRD))
					br.add_child(no)
					var ok: Button = UiKit.big("ПРИНЯТЬ", "green", "", 44.0, 11)
					ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					ok.pressed.connect( func() -> void : _send(ans_c, [me, kid, true], "Контракт заключён", ok, DipApiS.TRD))
					br.add_child(ok)
			"on":
				var cq: int = int(k.get("cancel_req", -1))
				var nx: String = Loc.t("%d/%d · далее через %s") % [int(k.get("done", 0)), int(k.get("n", 0)), s._mmss(float(k.get("next_in", 0.0)))]
				if cq >= 0 and cq != me:
					_line(cv, "d331_contract", title, "просят расторгнуть · без неустойки", C_AMB, "СОГЛАСИТЬСЯ", "gold" if end_c != "" else "soon", 
						func() -> void : _send(end_c, [me, kid, false], "Контракт расторгнут по согласию", null, DipApiS.TRD))
				elif cq == me:
					_line(cv, "d331_contract", title, Loc.t("%s · ждём согласия на разрыв") % [nx], C_AMB)
				else:
					_line(cv, "d331_contract", title, nx, C_PEACE, "РАЗОРВАТЬ", "ghost" if end_c != "" else "soon", func() -> void : _arm(key))
					if confirm == key:
						var pen: int = int(k.get("penalty", 0))
						var p: = PanelContainer.new()
						p.name = "Confirm"
						p.add_theme_stylebox_override("panel", UiKit.sb("wb_tooltip", 8, 5))
						cv.add_child(p)
						var vb: = VBoxContainer.new()
						vb.add_theme_constant_override("separation", 4)
						p.add_child(vb)
						var l: Label = UiKit.lbl(Loc.t("Попросить их согласия — бесплатно (ответ до 1:00). Разорвать сразу — неустойка %d и отношения хуже.") % pen, 9, UiKit.TEXT, 2)
						l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
						l.custom_minimum_size.x = 100
						vb.add_child(l)
						var br2: = HBoxContainer.new()
						br2.add_theme_constant_override("separation", 6)
						vb.add_child(br2)
						var ask: Button = UiKit.big("ПОПРОСИТЬ", "gold", "", 44.0, 10)
						ask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						ask.pressed.connect( func() -> void :
							confirm = ""
							_send(end_c, [me, kid, false], "Просьба о разрыве отправлена", ask, DipApiS.TRD))
						br2.add_child(ask)
						var force: Button = UiKit.big(Loc.t("РАЗОРВАТЬ · %d") % pen, "red", "", 44.0, 10)
						force.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						force.pressed.connect( func() -> void :
							confirm = ""
							_send(end_c, [me, kid, true], "Контракт разорван", force, DipApiS.TRD))
						br2.add_child(force)
						var nb: Button = _ghost("НЕТ")
						nb.custom_minimum_size.x = 48
						nb.pressed.connect( func() -> void : _arm(key))
						br2.add_child(nb)
			_:
				_line(cv, "d331_contract_16", title, String(k.get("why", "закрыт")), UiKit.DIM)
	if list.size() > 3:
		_note(s.inner, Loc.t("ещё %d — во «Входящих»") % (list.size() - 3), UiKit.MUTED)
	_sect("НОВЫЙ КОНТРАКТ")
	var cv2: VBoxContainer = _card(Color(C_SKY, 0.5), "NewContract")
	var oc: String = ap.tcmd("contract_offer")
	var dirr: = HBoxContainer.new()
	dirr.add_theme_constant_override("separation", 4)
	cv2.add_child(dirr)
	for d: bool in [true, false]:
		var lab: String = Loc.t("ПРОДАЮ ИМ") if d else Loc.t("ПОКУПАЮ У НИХ")
		var db: Button = UiKit.big(lab, "gold", "", 44.0, 10) if c_sell == d else _ghost(lab)
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dd: bool = d
		db.pressed.connect( func() -> void :
			c_sell = dd
			s.rebuild())
		dirr.add_child(db)
	var mr: = HBoxContainer.new()
	mr.add_theme_constant_override("separation", 4)
	cv2.add_child(mr)
	for r: String in CON_RES:
		var t: Button = s._tile(String(Economy.RES_ICONS.get(r, "res_metal")), String(Economy.RES_SHORT.get(r, r)), "slot", 44.0)
		if r == c_res:
			t.add_child(s._rim(UiKit.GOLD))
		var rr: String = r
		t.pressed.connect( func() -> void :
			c_res = rr
			s.rebuild())
		mr.add_child(t)
	var tm: Dictionary = ap.contract_terms(cid, c_res, c_sell)
	var pers: Array = tm.get("per", CON_PER)
	var per: int = int(pers[clampi(c_per, 0, pers.size() - 1)]) if not pers.is_empty() else 20
	var mkt: int = int(tm.get("market", 10))
	var price: int = clampi(roundi(float(mkt) * float(CON_PRICE[c_price])), int(tm.get("price_min", 1)), int(tm.get("price_max", 999999)))
	var mins: int = clampi(int(CON_N[c_n]), int(tm.get("n_min", 2)), int(tm.get("n_max", 20)))
	var vr: = HBoxContainer.new()
	vr.add_theme_constant_override("separation", 4)
	cv2.add_child(vr)
	for spec: Array in [[Loc.t("%d/мин") % per, "объём", "per"], [Loc.t("по %d") % price, Loc.t("рынок %d") % mkt, "price"], [Loc.t("%d мин") % mins, "срок", "n"]]:
		var b: Button = _ghost("")
		b.custom_minimum_size.y = 44
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vr.add_child(b)
		var vv: = VBoxContainer.new()
		vv.alignment = BoxContainer.ALIGNMENT_CENTER
		vv.add_theme_constant_override("separation", 0)
		vv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(vv)
		var a: Label = UiKit.lbl(String(spec[0]), 12, UiKit.TEXT, 2, 3)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vv.add_child(a)
		var c2: Label = UiKit.lbl(String(spec[1]), 9, UiKit.DIM, 1)
		c2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vv.add_child(c2)
		var which: String = String(spec[2])
		var npers: int = maxi(1, pers.size())
		b.pressed.connect( func() -> void :
			match which:
				"per":
					c_per = (c_per + 1) % npers
				"price":
					c_price = (c_price + 1) % CON_PRICE.size()
				_:
					c_n = (c_n + 1) % CON_N.size()
			s.rebuild())
	var tr: = HBoxContainer.new()
	tr.add_theme_constant_override("separation", 6)
	cv2.add_child(tr)
	var room: String = ap.contract_room(cid, c_res)
	var tot: String = "%d %s = %d" % [per * mins, String(s._res_gen(c_res)), per * mins * price]
	var have_t: String = (Loc.t("у вас %d") % int(tm.get("have", 0))) if c_sell else (Loc.t("место у вас %d") % int(tm.get("room", 0)))
	var tl: Label = UiKit.lbl("%s\n%s" % [tot, room if room != "" else have_t], 9, UiKit.MUTED if room == "" else C_RED_T, 2)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size.x = 100
	tr.add_child(tl)
	var sb2: Button = UiKit.big("ПРЕДЛОЖИТЬ", "green", "", 44.0, 11) if oc != "" else _ghost("СКОРО")
	sb2.name = "ContractGo"
	s._btn_icon(sb2, "net_handshake" if oc != "" else "wb_lock")
	sb2.custom_minimum_size.x = 132
	sb2.disabled = oc == "" or room != ""
	var sell: bool = c_sell
	var res: String = c_res
	sb2.pressed.connect( func() -> void :
		_send(oc, [me, cid, res, per, 60, mins, price, sell], "Контракт предложен: ответ во «Входящих»", sb2, DipApiS.TRD))
	tr.add_child(sb2)




func _tab_req(cid: int, row: Dictionary, st: int, pend: Array) -> void :
	var me: int = int(s.me)
	var ap = _a()
	if not pend.is_empty():
		_sect("ПРОСЯТ ВАС", "ответьте до конца таймера", C_AMB)
		for it: Dictionary in pend:
			s.inner.add_child(s._pending_card(it))
	var sent: Array = ap.reqs_between(me, cid)
	var p_ask: bool = not ap.t_offer(me, cid, "passage").is_empty()
	var p_give: bool = not ap.t_offer(me, cid, "passage_give").is_empty()
	if not sent.is_empty() or p_ask or p_give:
		_sect("ВЫ ПРОСИЛИ")
		var sv: VBoxContainer = _card(Color(0, 0, 0, 0), "Sent")
		var cc: String = ap.cmd(DipApiS.C_REQ_CANCEL)
		var first: bool = true
		for q: Dictionary in sent:
			if not first:
				_sep(sv)
			first = false
			var k: String = String(q.get("kind", ""))
			var x: int = int(q.get("x", -1))
			var ttl: String = String(KIND_DONE.get(k, k.to_upper())) + ((" " + String(s._cname_up(x))) if x >= 0 and s.gw.country_by_id(x) != null else "")
			var left: float = float(q.get("until", s.gw.game_time)) - s.gw.game_time
			var qid: Variant = q.get("id", -1)
			var lb: = _line(sv, _kind_icon(k), ttl, Loc.t("ждёт ответа · %s") % s._mmss(left), C_AMB, "ОТОЗВАТЬ", "ghost" if cc != "" else "soon", 
				func() -> void : _send(cc, [me, qid], "Просьба отозвана"))
			if lb != null:
				lb.name = "ReqCancel"
		if p_ask:
			if not first:
				_sep(sv)
			first = false
			_line(sv, "icon_treaty_passage", "ПРАВО ПРОХОДА ЧЕРЕЗ НИХ", "ждёт ответа", C_AMB)
		if p_give:
			if not first:
				_sep(sv)
			_line(sv, "icon_act_move_0", "ПРОХОД ЧЕРЕЗ НАС (предложили)", "ждёт ответа", C_AMB)
	_sect("НОВАЯ ПРОСЬБА", Loc.t("игрок ответит сам, до 2:00") if s._human_to(cid) else Loc.t("бот отвечает сразу"), UiKit.DIM)
	var ask: Button = UiKit.big("ПОПРОСИТЬ…", "gold", "", 44.0, 12)
	ask.name = "AskBtn"
	s._btn_icon(ask, "icon_dip_call")
	ask.pressed.connect( func() -> void :
		comp = 1
		comp_kind = ""
		comp_x = -1
		s.rebuild(false))
	s.inner.add_child(ask)
	if ap.rivals(me, cid):
		_note(s.inner, "Соперник: просьбы примет вряд ли — честно предупреждаем.", C_RED_T, "wb_lock")


func _kind_icon(k: String) -> String:
	for kd: Array in KINDS:
		if String(kd[0]) == k:
			return String(kd[2])
	return "icon_dip_call"




func _comp_back() -> void :
	match comp:
		3:
			comp = 2 if _needs_pick(comp_kind) else (0 if comp_kind == "stop_war" and tab == "trade" else 1)
		2:
			comp = 1
		_:
			comp = 0
	if comp <= 1:
		comp_x = -1
	s.rebuild(false)



func _targets(cid: int, kind: String) -> Array:
	var out: Array = []
	for tg: Dictionary in _a().req_targets(cid, kind):
		var x: int = int(tg["id"])
		if kind == "guard" and (_partner(x) or int(s.dp.war_by.get(Diplomacy.key(cid, x), -1)) == cid):
			continue
		out.append(x)
	return out



func _close(cid: int) -> bool:
	var dp: Diplomacy = s.dp
	return dp.allied(int(s.me), cid) or (dp.get("ally") != null and dp.ally.same(int(s.me), cid))


func _needs_pick(kind: String) -> bool:
	for kd: Array in KINDS:
		if String(kd[0]) == kind:
			if not bool(kd[3]):
				return false
			if kind == "join_war" or kind == "stop_war" or kind == "guard":
				return _targets(int(s.page), kind).size() > 1
			return true
	return false



func _kind_note(kind: String, x: int) -> String:
	var xn: String = s.gw.country_by_id(x).name if x > 0 and s.gw.country_by_id(x) != null else ""
	match kind:
		"war_on":
			return Loc.t("Если согласятся — %s запомнит, кто подтолкнул к войне.") % xn
		"join_war":
			return Loc.t("Если согласятся — вступят в вашу войну (враг: %s).") % xn
		"sky_over":
			return Loc.t("Их ПВО прикроют страну %s; её враги могут сбивать эти ПВО — это не война.") % xn
		"sky_me":
			return "Их ПВО встанут на вашей земле и будут сбивать ваших врагов."
		"station":
			var rq = s.dp.get("rq")
			var mins: int = int(float((rq.get_script() as Script).get_script_constant_map().get("STATION_T", 900.0)) / 60.0) if rq != null else 15
			return Loc.t("Их армия встанет у вас на %d мин; тронет её враг — они вступят в войну.") % mins
		"stop_war":
			return "Отказ — не война: дальше санкции на материал, затем полное эмбарго — до перемирия."
		"guard":
			return Loc.t("После «да» выберите армию (ВОЕННОЕ). Она бьёт врага только на их земле. Враг (%s) может объявить вам войну.") % xn
	return ""




func _lock_why(cid: int, kind: String) -> String:
	var ts: Array = _a().req_targets(cid, kind)
	var nm: String = s.gw.country_by_id(cid).name
	var first: String = ""
	for tg: Dictionary in ts:
		var w: String = String(tg.get("why", ""))
		var ws: String = Loc.src_of(w)
		if ws.begins_with(nm + " ") or ws.begins_with("Сначала"):
			return w
		if first == "" and w != "" and not ws.begins_with("Нельзя: это"):
			first = w
	return first if first != "" else Loc.t("нет подходящих стран")


func _ans_text(o: Dictionary) -> Array:
	match String(o.get("ans", "")):
		"yes":
			return ["скорее да", C_PEACE, 0.8]
		"maybe":
			return [Loc.t("игрок ответит сам") if bool(o.get("human", false)) else Loc.t("50 на 50"), UiKit.GOLD, 0.5]
		"no":
			return ["скорее нет", C_RED_T, 0.2]
		"wait":
			return [String(o.get("why", "уже просили · ждём ответа")), C_AMB, 0.0]
	return [String(o.get("why", "нельзя")), UiKit.DIM, 0.0]


func _composer(cid: int, c: Country) -> void :
	var ap = _a()
	var me: int = int(s.me)
	_head(c, false)
	var sr: = HBoxContainer.new()
	sr.name = "CompSteps"
	sr.add_theme_constant_override("separation", 4)
	s.col.add_child(sr)
	sr.add_child(s._section("ПРОСЬБА"))
	var names: Array = ["ЧТО ПОПРОСИТЬ", Loc.t("НАД КЕМ") if comp_kind == "sky_over" else (Loc.t("ОТ КОГО") if comp_kind == "guard" else Loc.t("ПРОТИВ КОГО")), "ПРОВЕРИТЬ И ОТПРАВИТЬ"]
	var sl: Label = UiKit.lbl("· %d/3 · %s" % [comp, names[comp - 1]], 10, UiKit.TEXT, 2, 3)
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.clip_text = true
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sr.add_child(sl)
	for i: int in 3:
		var pip: = ColorRect.new()
		pip.custom_minimum_size = Vector2(14, 4)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.color = UiKit.GOLD if i + 1 == comp else (C_PEACE if i + 1 < comp else Color("55524a"))
		sr.add_child(pip)
	s._new_scroll()
	match comp:
		1:
			var rw: float = ap.rate_wait()
			if rw > 0.0:
				var rl: Label = _note(s.inner, Loc.t("Не больше 3 просьб за 2 мин — следующая через %s.") % s._mmss(rw), C_AMB, "net_wait")
				s._timers.append([rl, null, s.gw.game_time + rw, 0.0, "Не больше 3 просьб за 2 мин — следующая через "])
			for kd: Array in KINDS:
				_kind_row(cid, kd)
			_refit()
		2:
			var verb: String = {"war_on": "Объявить войну — кому?", "sky_over": "Закрыть небо — над кем?", "join_war": "Вступить в войну — против кого?", 
				"stop_war": "Прекратить войну — с кем?", "guard": "Защищать их — от кого?"}.get(comp_kind, "Кого?")
			_note(s.inner, Loc.t("%s Серые нельзя: причина под именем. Удержание — показать на карте.") % [verb], UiKit.MUTED)
			for x: int in _targets(cid, comp_kind):
				_target_row(cid, x)
			_refit()
		3:
			_review(cid)


func _kind_row(cid: int, kd: Array) -> void :
	var ap = _a()
	var me: int = int(s.me)
	var kind: String = String(kd[0])
	var sub: String = ""
	var sc: Color = UiKit.MUTED
	var mode: String = "go"
	var tg: Array = _targets(cid, kind)
	var only: int = -1
	if kind == "join_war" and tg.is_empty():
		sub = "нельзя: вы ни с кем не воюете"
		mode = "lock"
	elif (kind == "stop_war" or kind == "guard") and tg.is_empty():
		sub = Loc.t("нельзя: они ни с кем не воюют") if c_wars(cid).is_empty() else (Loc.t("нельзя: защищают только жертву войны") if kind == "guard" else Loc.t("нельзя: войны против ваших партнёров нет"))
		mode = "lock"
	elif kind == "guard" and (_close(cid) or not _a().guard_of(cid).is_empty()):
		sub = Loc.t("согласие не нужно — ВОЕННОЕ → АРМИЯ НА ЗАЩИТУ") if _close(cid) else Loc.t("согласие уже есть — ВОЕННОЕ → АРМИЯ НА ЗАЩИТУ")
		sc = C_PEACE
		mode = "jump"
	elif bool(kd[3]) and not _needs_pick(kind):
		only = int(tg[0])
	if mode == "go":
		if bool(kd[3]) and only < 0:
			var o0: Dictionary = ap.outlook(cid, kind, -1)
			if String(o0.get("ans", "")) == "lock":
				sub = _lock_why(cid, kind)
				mode = "lock"
			else:
				sub = {"war_on": "выберите страну", "sky_over": "их ПВО прикроют выбранную страну", "join_war": "выберите войну", "stop_war": "выберите войну", 
					"guard": "без войны · выберите их войну"}.get(kind, "")
		else:
			var o: Dictionary = ap.outlook(cid, kind, only)
			var at: Array = _ans_text(o)
			var pre: String = ("%s · " % Loc.name(s.gw.country_by_id(only).name)) if only >= 0 else ""
			sub = pre + String(at[0])
			sc = at[1]
			var a: String = String(o.get("ans", ""))
			if a == "lock":
				mode = "lock"
				sub = String(o.get("why", "нельзя"))
			elif a == "wait":
				mode = "wait"
	var lk: bool = mode == "lock"
	var b: = Button.new()
	b.name = "Kind_" + kind
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 48)
	var n: StyleBox = UiKit.sb("wb_panel_dark", 6, 3)
	if lk:
		b.self_modulate = Color(1, 1, 1, 0.55)
	for k: String in ["normal", "hover"]:
		b.add_theme_stylebox_override(k, n)
	b.add_theme_stylebox_override("pressed", UiKit.sb("wb_slot_pressed", 6, 3) if not lk else n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	s.inner.add_child(b)
	var hb: HBoxContainer = s._fill_box(b, 8, 2)
	var ic: TextureRect = s._icon(String(kd[2]), 24)
	if lk:
		ic.modulate = Color(1, 1, 1, 0.4)
	hb.add_child(ic)
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(v)
	v.add_child(UiKit.lbl(String(kd[1]), 11, UiKit.DIM if lk else UiKit.TEXT, 2, 3))
	var sl: Label = UiKit.lbl(sub, 9, UiKit.DIM if lk else (C_AMB if mode == "wait" else sc), 1)
	v.add_child(sl)
	UiKit.fit_lbl(sl, [9], true, true)
	hb.add_child(s._icon("wb_lock" if lk else ("net_wait" if mode == "wait" else "wb_arrow_r"), 14))
	b.pressed.connect( func() -> void :
		if mode == "jump":
			UiKit.snd("ui_click")
			comp = 0
			tab = "mil"
			last_tab = "mil"
			guard_open = true
			s.rebuild(false)
			return
		if mode != "go":
			s._shake(b)
			return
		UiKit.snd("ui_click")
		comp_kind = kind
		if bool(kd[3]) and only < 0:
			comp_x = -1
			comp = 2
		else:
			comp_x = only
			comp = 3
		s.rebuild(false))


func _target_row(cid: int, x: int) -> void :
	var gw: GameWorld = s.gw
	var dp: Diplomacy = s.dp
	var me: int = int(s.me)
	var ap = _a()
	var cc: Country = gw.country_by_id(x)
	var st_txt: String = "это вы"
	var stc: Color = UiKit.DIM
	var line2: String = ""
	var yes2: bool = false
	var lk: bool = x == me
	if x != me:
		var rs: int = dp.get_rel(me, x)
		match rs:
			Diplomacy.Rel.WAR:
				st_txt = "ВОЙНА с вами"
				stc = C_WAR
			Diplomacy.Rel.ALLIANCE:
				st_txt = "ваш союзник"
				stc = C_ALLY
			Diplomacy.Rel.TRUCE:
				st_txt = "перемирие"
				stc = C_TRUCE
			_:
				st_txt = "мир"
				stc = C_PEACE
		if cc.is_player:
			st_txt += Loc.t(" · игрок")
		var o: Dictionary = ap.outlook(cid, comp_kind, x)
		var at: Array = _ans_text(o)
		line2 = String(at[0])
		yes2 = String(o.get("ans", "")) == "yes"
		if String(o.get("ans", "")) == "lock" or String(o.get("ans", "")) == "wait":
			lk = true
		if comp_kind == "war_on" and dp.at_war(cid, x):
			lk = true
			line2 = "уже воюют · просить незачем"
			yes2 = false
	var b: = Button.new()
	b.name = "Target_%d" % x
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 46)
	var n: StyleBox = UiKit.sb("wb_panel_dark", 6, 3)
	if lk:
		b.self_modulate = Color(1, 1, 1, 0.55)
	for k: String in ["normal", "hover"]:
		b.add_theme_stylebox_override(k, n)
	b.add_theme_stylebox_override("pressed", UiKit.sb("wb_slot_pressed", 6, 3) if not lk else n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	s.inner.add_child(b)
	var hb: HBoxContainer = s._fill_box(b, 8, 3)
	var f: Control = s._flag(cc, Vector2(24, 15))
	if lk:
		f.modulate = Color(1, 1, 1, 0.4)
	hb.add_child(f)
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(v)
	var nm: = HBoxContainer.new()
	nm.add_theme_constant_override("separation", 6)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)
	var nl: Label = UiKit.lbl(Loc.name(cc.name).to_upper(), 11, UiKit.DIM if lk else UiKit.TEXT, 2, 3)
	nm.add_child(nl)
	nm.add_child(UiKit.lbl(st_txt, 9, UiKit.DIM if lk else stc, 2))
	if line2 != "":
		var l2: Label = UiKit.lbl(line2, 9, UiKit.DIM if lk else (C_PEACE if yes2 else UiKit.MUTED), 1)
		v.add_child(l2)
		UiKit.fit_lbl(l2, [9], true, true)
	_long_press(b, x)
	b.pressed.connect( func() -> void :
		if b.has_meta("lp"):
			b.remove_meta("lp")
			_peek(x, false)
			return
		if lk:
			s._shake(b)
			return
		UiKit.snd("ui_click")
		comp_x = x
		comp = 3
		s.rebuild(false))



func _long_press(b: Button, x: int) -> void :
	b.button_down.connect( func() -> void :
		var sc: ScrollContainer = s.scroll
		var sv: int = sc.scroll_vertical if sc != null else 0
		s.get_tree().create_timer(0.45).timeout.connect( func() -> void :
			if not is_instance_valid(b) or not b.is_pressed() or not b.is_inside_tree():
				return
			if sc != null and is_instance_valid(sc) and sc.scroll_vertical != sv:
				return
			b.set_meta("lp", true)
			_peek(x, true)))
	b.button_up.connect( func() -> void :
		if b.has_meta("lp"):
			_peek(x, false)
			b.remove_meta.call_deferred("lp"))



func _peek(x: int, on: bool) -> void :
	var cam = s.m.get("cam")
	var c: Country = s.gw.country_by_id(x)
	if cam == null or not is_instance_valid(s):
		return
	if on:
		if c == null or c.capital_id < 0:
			return
		_peek_back = cam.screen_to_world(s.vp * 0.5)
		s.modulate.a = 0.15
		cam.center_on(Vector2(s.gw.cities[c.capital_id].center) * float(GameWorld.CELL))
		s.m.set("cam_lock", false)
		if s.has_method("_flash_border"):
			s._flash_border(x)
		s.hud.show_toast(Loc.t("%s · отпустите — назад") % Loc.name(c.name).to_upper())
	elif _peek_back != Vector2.INF:
		s.modulate.a = 1.0
		cam.center_on(_peek_back)
		_peek_back = Vector2.INF


func _review(cid: int) -> void :
	var gw: GameWorld = s.gw
	var dp: Diplomacy = s.dp
	var me: int = int(s.me)
	var ap = _a()
	var c: Country = gw.country_by_id(cid)
	var o: Dictionary = ap.outlook(cid, comp_kind, comp_x)
	var at: Array = _ans_text(o)
	var cv: VBoxContainer = _card(Color(UiKit.GOLD, 0.7), "Review")
	var hh: = HBoxContainer.new()
	hh.add_theme_constant_override("separation", 8)
	cv.add_child(hh)
	hh.add_child(s._icon(_kind_icon(comp_kind), 32))
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(v)
	var xt: String = (" " + String(s._cname_up(comp_x))) if comp_x >= 0 and gw.country_by_id(comp_x) != null else ""
	var tl: Label = UiKit.lbl(Loc.t(String(KIND_DONE.get(comp_kind, ""))) + xt, 12, UiKit.TEXT, 2, 3)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size.x = 120
	v.add_child(tl)
	var rs: String = String({Diplomacy.Rel.ALLIANCE: "союз", Diplomacy.Rel.WAR: "война", Diplomacy.Rel.TRUCE: "перемирие"}.get(dp.get_rel(me, cid), "мир"))
	v.add_child(UiKit.lbl(Loc.t("просим: %s (%s, %s)") % [Loc.name(c.name), rs, s._signed(dp.relation(me, cid))], 9, UiKit.MUTED, 1))
	_sep(cv)
	var fh: = HBoxContainer.new()
	fh.add_theme_constant_override("separation", 6)
	cv.add_child(fh)
	fh.add_child(UiKit.lbl("ОТВЕТ", 9, UiKit.MUTED, 2))
	var fb: Control = s._plain_bar(float(at[2]), Vector2(80, 8), at[1])
	fb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fh.add_child(fb)
	var fv: Label = UiKit.lbl(String(at[0]), 10, at[1], 2, 3)
	fv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fh.add_child(fv)
	UiKit.fit_lbl(fv, [10, 9], true, true)
	for p: Variant in o.get("pros", []):
		_note(cv, String(p), C_PEACE, "icon_rel_up")
	for q: Variant in o.get("cons", []):
		_note(cv, String(q), C_RED_T, "icon_rel_down")
	var dup: bool = false
	dup = bool(o.get("rival", false))
	if ap.rivals(me, cid) and not dup and comp_kind != "stop_war":
		_note(cv, Loc.t("%s — ваш соперник: не станет помогать вам") % Loc.name(c.name), C_RED_T, "icon_rel_down")
	var kn: String = _kind_note(comp_kind, comp_x)
	if kn != "":
		_note(cv, kn, C_AMB if comp_kind == "guard" or comp_kind == "war_on" else UiKit.MUTED, "net_warn" if comp_kind == "guard" or comp_kind == "war_on" else "icon_hint")
	var human: bool = c.is_player
	_note(s.inner, Loc.t("Игрок ответит во «Входящих», до 2:00.") if human else Loc.t("Бот отвечает сразу. Отказ отношения почти не портит; повтор — позже."), UiKit.DIM, "net_wait")
	var ok: bool = not bool(o.get("soon", false)) and String(o.get("ans", "")) != "lock" and String(o.get("ans", "")) != "wait"
	var rw: float = ap.rate_wait()
	if rw > 0.0:
		ok = false
		var rl: Label = _note(s.inner, Loc.t("Не больше 3 просьб за 2 мин — следующая через %s.") % s._mmss(rw), C_AMB, "net_wait")
		rl.name = "RateLock"
		s._timers.append([rl, null, s.gw.game_time + rw, 0.0, "Не больше 3 просьб за 2 мин — следующая через "])
	var mth: String = ap.cmd(DipApiS.C_REQUEST)
	var kind: String = comp_kind
	var args: Array = [me, cid, kind, maxi(0, comp_x)]
	var go: Button = UiKit.big("ПОТРЕБОВАТЬ МИРА" if kind == "stop_war" else Loc.t("ОТПРАВИТЬ ПРОСЬБУ"), "gold" if mth != "" and ok else "stone", "", 44.0, 12)
	go.name = "SendReq"
	s._btn_icon(go, "icon_dip_call" if ok else "wb_lock")
	go.disabled = mth == "" or not ok
	go.pressed.connect( func() -> void :
		go.disabled = true
		s._dp(mth, args, func(why: String) -> void :

			var answered: bool = why == "" or Diplomacy.ReqS.result_kind(why) in ["inbox", "refused", "agree_but"]
			if not answered:
				s.m.hud.show_toast(why)
				if is_instance_valid(go):
					s._shake(go)
					go.disabled = false
				return
			s.m.hud.show_toast(why if why != "" else "%s соглашается: %s" % [c.name, String(KIND_DONE.get(kind, "")).trim_suffix(":").to_lower()])
			comp = 0
			comp_kind = ""
			comp_x = -1
			tab = "req"
			if why == "" and kind == "guard":
				tab = "mil"
				guard_open = true
			elif kind == "stop_war" and Diplomacy.ReqS.result_kind(why) == "refused":
				tab = "trade"
			last_tab = tab
			s.rebuild(false)))
	s.col.add_child(go)
	_refit()







func req_card(it: Dictionary) -> Control:
	var gw: GameWorld = s.gw
	var from: Country = gw.country_by_id(int(it["from"]))
	var p: = PanelContainer.new()
	p.name = "ReqCard"
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 6))
	p.add_child(s._rim(Color(C_AMB, 0.8)))
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	p.add_child(vb)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	vb.add_child(hb)
	hb.add_child(s._frame_icon(String(it.get("icon", "icon_dip_call")), 36))
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 1)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(tv)
	var l1: = HBoxContainer.new()
	l1.add_theme_constant_override("separation", 5)
	tv.add_child(l1)
	if from != null:
		var fl: Control = s._flag(from, Vector2(18, 12))
		fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l1.add_child(fl)
	var nm: Label = UiKit.lbl(Loc.name(from.name).to_upper() if from != null else "?", 11, UiKit.TEXT, 2, 3)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l1.add_child(nm)
	var total: float = float(it.get("total", 120.0))
	var ring: TextureRect = s._icon(s._ring_name(float(it["left"]), total), 16)
	ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l1.add_child(ring)
	var tl: Label = UiKit.lbl(s._mmss(float(it["left"])), 10, UiKit.GOLD, 2, 3)
	l1.add_child(tl)
	s._timers.append([tl, ring, float(it["deadline"]), total, ""])
	var tx: String = String(it.get("text", ""))
	if from != null and tx.begins_with(from.name + " "):
		tx = tx.substr(from.name.length() + 1)
	var wl: Label = UiKit.lbl(tx.left(1).to_upper() + tx.substr(1), 10, UiKit.TEXT, 1)
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wl.custom_minimum_size.x = 120
	tv.add_child(wl)
	if String(it.get("yes", "")) != "":
		_note(vb, Loc.t("Да: %s") % [String(it["yes"])], C_PEACE, "icon_rel_up")
	if String(it.get("no", "")) != "":
		_note(vb, Loc.t("Нет: %s") % [String(it["no"])], C_RED_T, "icon_rel_down")
	var br: = HBoxContainer.new()
	br.add_theme_constant_override("separation", 6)
	vb.add_child(br)
	var yes_l: String = "ПРИНЯТЬ"
	var no_l: String = "ОТКАЗАТЬ"
	for op: Variant in it.get("options", []):
		if op is Dictionary:
			if String(op.get("act", "")) == "accept":
				yes_l = String(op.get("label", yes_l))
			else:
				no_l = String(op.get("label", no_l))
	var id: String = String(it["id"])
	var nb: Button = _ghost(no_l)
	nb.name = "ReqNo"
	nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nb.pressed.connect( func() -> void : s._answer(id, "refuse", p))
	br.add_child(nb)
	var yb: Button = UiKit.big(yes_l, "red" if String(it.get("req", "")) in ["war_on", "join_war"] else "gold", "", 44.0, 11)
	yb.name = "ReqYes"
	yb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yb.pressed.connect( func() -> void : s._answer(id, "accept", p))
	br.add_child(yb)
	return p




func _chat() -> DipChat:
	var m: Node = s.m
	if m == null or m.get("net") == null:
		return null
	return (m.get("net") as NetSession).chat


func _chat_close() -> void :
	chat_on = false
	chat_focus = false
	if chat_base_h > 0.0:
		s.max_h = chat_base_h
	chat_base_h = 0.0
	if chat_lifted and s.hud != null and s.hud.holder != null:
		s.hud.holder.offset_bottom = chat_hold_off
	chat_lifted = false
	var ch: DipChat = _chat()
	if ch != null:
		ch.set_open(-1)
	DisplayServer.virtual_keyboard_hide()



func _chat_page(c: Country) -> void :
	_head(c, false)
	var sub: Label = UiKit.lbl(Loc.t("ЧАТ · %s") % String(_chat_name(c)).to_upper(), 10, UiKit.TEXT, 2, 3)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.clip_text = true
	s.col.add_child(sub)
	s._new_scroll()
	var v: VBoxContainer = ChatViewS.new()
	s.col.add_child(v)
	v.call("setup", s, self, c.id)
	_refit()



func _chat_name(c: Country) -> String:
	var ch: DipChat = _chat()
	if ch != null:
		var sl: int = ch.slot_of(c.id)
		if sl >= 0:
			return String(ch.net.slots[sl].get("name", c.name))
	return c.name
