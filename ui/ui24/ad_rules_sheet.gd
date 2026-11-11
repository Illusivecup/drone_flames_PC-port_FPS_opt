extends PanelContainer









signal action(name: String)

const U = preload("res://ui/ui24/econ_kit.gd")
const WidthGuard = preload("res://ui/ui24/width_guard.gd")
const AMBER: = Color("ffb000")
const C_ON_BG: = Color("27401c")
const C_ON_RIM: = Color("a2e35f")
const C_OFF_BG: = Color("2e1c17")
const C_OFF_RIM: = Color("4d4234")
const C_LOCK_BG: = Color("17150f")
const C_X: = Color("ff6a4d")
const CELL_H: float = 42.0
const PEND_MS: int = 2500

const CLASS_ICON: Dictionary = {Facility.Kind.AD_SAM: "icon_ad_sam", Facility.Kind.AD_PATRIOT: "icon_ad_patriot", Facility.Kind.AD_SPAAG: "icon_ad_spaag", 
	Facility.Kind.AD_MFG: "icon_ad_mfg", Facility.Kind.AD_INT: "icon_int_drone"}
const LOC_CLASS_NAME: Dictionary = {Facility.Kind.AD_SAM: "ЗРК «Купол»", Facility.Kind.AD_PATRIOT: "ЗРК/ПРО «Щит»", Facility.Kind.AD_SPAAG: "ЗСУ «Шершень»", 
	Facility.Kind.AD_MFG: "Огневые группы", Facility.Kind.AD_INT: "Перехватчики"}
const COL_ICON: Dictionary = {Defense.R_JET: "icon_fighter", Defense.R_HELI: "icon_heli", Defense.R_UAV: "icon_launch", Defense.R_JETUAV: "icon_jet_uav", 
	Defense.R_CRUISE: "icon_m_cruise", Defense.R_BALL: "icon_m_ballistic", Defense.R_HYPER: "icon_m_hyper", Defense.R_KAB: "icon_m_kab", 
	Defense.R_FPV: "icon_fpv", Defense.R_RECON: "icon_recon_drone"}
const LOC_COL_SHORT: Dictionary = {Defense.R_JET: "Самолёты", Defense.R_HELI: "Вертолёты", Defense.R_UAV: "Дроны", Defense.R_JETUAV: "Реактив.", 
	Defense.R_CRUISE: "КР", Defense.R_BALL: "Баллистика", Defense.R_HYPER: "Гиперзвук", Defense.R_KAB: "КАБ", Defense.R_FPV: "FPV", Defense.R_RECON: "Разведка"}

const LOC_LOCK_WHY: Dictionary = {
	Facility.Kind.AD_SAM: "ЗРК не наводится на КАБ и FPV — мелкие цели сбивают стволы", 
	Facility.Kind.AD_PATRIOT: "«Щит» бережёт ракеты для крупных целей: самолёты, реактивные БПЛА, КР, баллистика", 
	Facility.Kind.AD_SPAAG: "ЗСУ не достаёт: самолёты, баллистика и гиперзвук — слишком высоко и быстро", 
	Facility.Kind.AD_MFG: "Пулемёт не догонит реактивные цели и не достанет высоко летящие", 
	Facility.Kind.AD_INT: "Дрон-перехватчик не догонит самолёты, баллистику и гиперзвук, а КАБ и FPV слишком малы", 
}
const LOC_PRESET_BTN: Dictionary = {"all": "ВСЁ СБИВАТЬ", "eco": "ЭКОНОМНО", "missiles": "ТОЛЬКО РАКЕТЫ"}

var hud: Node
var gw: GameWorld
var player: Country
var compact: bool = false
var closing: bool = false
var cols: int = 5
var focus_kind: int = -1
var sent: int = 0
var hint_log: Array = []
var _t: float = 0.0
var _hint_until: int = 0
var _pill_lbl: Label
var _preset_btns: Dictionary = {}
var _hint: Label
var _scroll: ScrollContainer
var _cards: Dictionary = {}
var _pend: Dictionary = {}
var _mask0: Dictionary = {}
var _want: Dictionary = {}
var _sb: Dictionary = {}
var _cell_w: float = 60.0


func setup(h: Node, sheet_h: float, bottom_pad: float, focus: int = -1, sheet_w: float = -1.0) -> void :
	hud = h
	gw = hud.gw
	player = gw.player
	focus_kind = focus
	UiKit.ensure()
	compact = sheet_h < 430.0
	custom_minimum_size = Vector2(0, sheet_h)
	var psb: StyleBox = UiKit.sb("wb_window", 8, 6)
	psb.content_margin_bottom = 6.0 + bottom_pad
	add_theme_stylebox_override("panel", psb)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("kind", "ad_rules")
	tree_exiting.connect( func() -> void :
		if hud != null and is_instance_valid(hud):
			hud.call("ui24_closed", self))
	var vw: float = sheet_w if sheet_w > 0.0 else (hud.root.get_viewport_rect().size.x if hud.get("root") != null else 360.0)
	var inner_w: float = vw - 16.0 - 12.0 - 8.0
	cols = 10 if inner_w >= 580.0 else 5
	_cell_w = floorf((inner_w - float(cols - 1) * 3.0) / float(cols))
	_sb = {"on": _flat(C_ON_BG, C_ON_RIM, 2), "off": _flat(C_OFF_BG, C_OFF_RIM.lerp(C_X, 0.35), 1), "lock": _flat(C_LOCK_BG, Color(0, 0, 0, 0), 0), 
		"on_p": _flat(C_ON_BG.lightened(0.12), C_ON_RIM, 2), "off_p": _flat(C_OFF_BG.lightened(0.1), C_OFF_RIM.lightened(0.2), 1)}
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)
	vb.add_child(_header())
	vb.add_child(_presets())
	_hint = UiKit.no_tr(UiKit.lbl("", 10, UiKit.MUTED, 1, 2)) as Label
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(0, 26 if not compact else 14)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vb.add_child(_hint)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_scroll)
	var list: = VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(list)
	for kind: int in Defense.AD_CLASSES:
		list.add_child(_card(kind))
	var foot: Label = UiKit.lbl(Loc.t("Настройка для всей страны: действует сразу на все площадки, старые и новые. Боты играют по тем же правилам."), 9, UiKit.DIM, 1, 2)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(foot)
	refresh()
	if focus_kind >= 0 and _cards.has(focus_kind):
		_focus.call_deferred(focus_kind)


func _flat(bg: Color, rim: Color, w: int) -> StyleBoxFlat:
	var st: = StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = rim
	st.set_border_width_all(w)
	st.set_corner_radius_all(4)
	st.content_margin_left = 2
	st.content_margin_right = 2
	st.content_margin_top = 3
	st.content_margin_bottom = 2
	if w == 0:
		st.border_color = Color(1, 1, 1, 0.04)
		st.set_border_width_all(1)
	return st




func scroll_areas() -> Array:
	return [_scroll]


func scroll_area() -> ScrollContainer:
	return _scroll


func close() -> void :
	if closing:
		return
	closing = true
	if hud != null and is_instance_valid(hud):
		hud.call("ui24_closed", self)
	visible = false
	queue_free()


func _process(delta: float) -> void :
	if closing or hud == null or not is_instance_valid(hud):
		return
	if gw == null or gw.player == null or gw.player != player or player.eliminated or bool(hud.ops_panel.visible):
		close()
		return
	if hud.panel != null and is_instance_valid(hud.panel):
		close()
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	refresh()




func _close() -> Button:
	var cb: Button = UiKit.close_btn(44.0)
	cb.pressed.connect( func() -> void :
		UiKit.snd("ui_close")
		close())
	return cb


func _header() -> Control:
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.custom_minimum_size = Vector2(0, 44)
	var ic: TextureRect = U.icon("u335_ad_rules", 24.0, "icon_target")
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var t: Label = UiKit.lbl(Loc.t("ЦЕЛИ ПВО"), 18 if not compact else 15, UiKit.TITLE, 3, 2)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(t)
	var pill: = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UiKit.sb("wb_pill", 7, 3))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ph: = HBoxContainer.new()
	ph.add_theme_constant_override("separation", 3)
	pill.add_child(ph)
	var pi: TextureRect = U.icon("res_money", 18.0)
	pi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(pi)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	ph.add_child(col)
	_pill_lbl = UiKit.no_tr(UiKit.lbl("0", 14, UiKit.MUTED, 2, 3)) as Label
	_pill_lbl.custom_minimum_size = Vector2(50, 0)
	col.add_child(_pill_lbl)
	col.add_child(UiKit.lbl(Loc.t("огонь ПВО / мин"), 9, UiKit.MUTED, 2, 2))
	hb.add_child(pill)
	hb.add_child(_close())
	return hb


func _presets() -> Control:
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	for key: String in Defense.PRESET_ORDER:
		var b: = Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = Loc.t(String(LOC_PRESET_BTN[key]))
		UiKit.no_tr(b)
		b.clip_text = true
		b.add_theme_font_override("font", UiKit.f_black)
		b.add_theme_font_size_override("font_size", 11 if cols < 10 else 12)
		WidthGuard.fit_btn(b, [11, 10, 9] if cols < 10 else [12, 11, 10])
		b.add_theme_constant_override("outline_size", 0)
		for st: String in ["normal", "hover", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, UiKit.sb("wb_btn_stone", 4, 4, -1))
		for st2: String in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st2, UiKit.sb("wb_btn_gold_p", 4, 4, 1))
		for cn: String in ["font_color", "font_hover_color", "font_focus_color"]:
			b.add_theme_color_override(cn, UiKit.TEXT)
		for cn2: String in ["font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(cn2, Color("2a1a08"))
		UiKit.tap_snd(b)
		b.pressed.connect( func() -> void : _preset_tap(key))
		hb.add_child(b)
		_preset_btns[key] = b
	return hb


func _card(kind: int) -> Control:
	var pc: = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 6, 5))
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pc.add_child(vb)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)
	var ic: TextureRect = U.icon(String(CLASS_ICON[kind]), 24.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(col)
	var nm: Label = UiKit.lbl(Loc.t(String(LOC_CLASS_NAME[kind])), 12, UiKit.TEXT, 2, 2)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	var sub: Label = UiKit.no_tr(UiKit.lbl("", 9, UiKit.MUTED, 1, 2)) as Label
	sub.clip_text = true
	UiKit.fit_lbl(sub, [9, 8], false)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(sub)
	var sp: = VBoxContainer.new()
	sp.add_theme_constant_override("separation", -3)
	sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(sp)
	var spend: Label = UiKit.no_tr(UiKit.lbl("", 12, AMBER, 2, 2)) as Label
	spend.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sp.add_child(spend)
	var sl: Label = UiKit.lbl(Loc.t("расход/мин"), 9, UiKit.DIM, 1, 2)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sp.add_child(sl)
	var grid: = GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	vb.add_child(grid)
	var cells: Dictionary = {}
	for e: Array in Defense.LOC_AD_COLS:
		var bit: int = int(e[0])
		cells[bit] = _cell(kind, bit)
		grid.add_child(cells[bit]["b"])
	_cards[kind] = {"pc": pc, "spend": spend, "sub": sub, "cells": cells}
	return pc


func _cell(kind: int, bit: int) -> Dictionary:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(_cell_w, CELL_H)
	b.clip_contents = true
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(vb)
	var ic: TextureRect = U.icon(String(COL_ICON[bit]), 24.0, "icon_target")
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ic)
	var cs: String = String(LOC_COL_SHORT[bit])
	var lb: Label = UiKit.lbl(Loc.t("КАБ", "ad_col") if cs == "КАБ" else Loc.t(cs), 9, UiKit.TEXT, 2, 2)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.clip_text = true
	lb.custom_minimum_size = Vector2(_cell_w - 4.0, 0)
	vb.add_child(lb)
	UiKit.fit_lbl(lb, [9, 8], false, true)
	var lock: TextureRect = U.icon("wb_lock", 12.0)
	lock.position = Vector2(_cell_w - 15.0, 3.0)
	lock.visible = false
	b.add_child(lock)
	var chk: TextureRect = U.icon("wb_check", 12.0)
	chk.position = Vector2(_cell_w - 15.0, 3.0)
	chk.visible = false
	b.add_child(chk)
	var xm: Label = UiKit.lbl("×", 14, C_X, 3, 2)
	xm.position = Vector2(_cell_w - 13.0, -3.0)
	xm.visible = false
	b.add_child(xm)
	UiKit.tap_snd(b)
	b.pressed.connect( func() -> void : _cell_tap(kind, bit))
	return {"b": b, "ic": ic, "lb": lb, "lock": lock, "chk": chk, "x": xm, "st": ""}




func _sites(kind: int) -> Array:
	var n: int = 0
	var mb: int = 0
	for f: Facility in gw.mil.facilities:
		if f.country_id == player.id and f.kind == kind and gw.mil.alive(f):
			n += 1
			if f.mb:
				mb += 1
	return [n, mb]


func refresh() -> void :
	var rules: Dictionary = gw.defense.rules(player)
	var sp: Dictionary = gw.defense.spend_min(player)
	var tot: int = int(sp.get("total", 0))
	U.set_lbl(_pill_lbl, ("−" + U.num(tot)) if tot > 0 else "0", AMBER if tot > 0 else UiKit.MUTED)
	var now: int = Time.get_ticks_msec()
	var pr: String = gw.defense.preset_of(player)
	for key: String in _preset_btns:
		var pb: Button = _preset_btns[key]
		if pb.button_pressed != (key == pr):
			pb.set_pressed_no_signal(key == pr)
	if _pend.has("preset") and (now - int(_pend["preset"]) > PEND_MS or pr == String(_pend.get("preset_key", ""))):
		_pend.erase("preset")
		_pend.erase("preset_key")
	if now > _hint_until:
		var ht: String = Loc.t(String(Defense.LOC_AD_PRESET_HINT[pr])) if pr != "" else Loc.f("Своя настройка · не сбивают целей: {n} · пресет выше заменит её", {"n": _off_count(rules)})
		U.set_lbl(_hint, ht, UiKit.MUTED)
	var by: Dictionary = sp.get("by_class", {})
	for kind: int in Defense.AD_CLASSES:
		var cd: Dictionary = _cards[kind]
		var s: Array = _sites(kind)
		var shot: int = int(Defense.SHOT_COST.get(kind, 0))
		var st: String = Loc.f("выстрел {c}", {"c": shot})
		if int(s[0]) > 0:
			st += " · " + Loc.f("на карте {n}", {"n": int(s[0])})
			if int(s[1]) > 0:
				st += " " + Loc.f("(консервация {n})", {"n": int(s[1])})
		else:
			st += " · " + Loc.t("пока не построены")
		U.set_lbl(cd["sub"], st, UiKit.MUTED)
		var v: int = int(by.get(kind, 0))
		U.set_lbl(cd["spend"], ("−" + U.num(v)) if v > 0 else "0", AMBER if v > 0 else UiKit.DIM)
		var mask: int = int(rules.get(kind, Defense.R_ALL))
		var poss: int = Defense.possible(kind)
		if _mask0.has(kind) and int(_mask0[kind]) != mask and int(_want.get(kind, mask)) == mask:
			_mask0.erase(kind)
			_want.erase(kind)
			for k2: Variant in _pend.keys():
				if String(k2).begins_with("%d:" % kind):
					_pend.erase(k2)
		for bit: int in cd["cells"]:
			var c: Dictionary = cd["cells"][bit]
			var pk: String = "%d:%d" % [kind, bit]
			if _pend.has(pk) and now - int(_pend[pk]) > PEND_MS:
				_pend.erase(pk)
				_mask0.erase(kind)
				_want.erase(kind)
			var stt: String = "lock" if (poss & bit) == 0 else ("on" if (mask & bit) != 0 else "off")
			_paint(c, stt, _pend.has(pk) or _pend.has("preset"))


func _paint(c: Dictionary, stt: String, pending: bool) -> void :
	var b: Button = c["b"]
	var key: String = stt + ("*" if pending else "")
	if String(c["st"]) == key:
		return
	c["st"] = key
	var base: StyleBox = _sb[stt]
	for s: String in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, base)
	var prs: StyleBox = _sb.get(stt + "_p", base)
	b.add_theme_stylebox_override("pressed", prs)
	b.add_theme_stylebox_override("hover_pressed", prs)
	var ic: TextureRect = c["ic"]
	var lb: Label = c["lb"]
	match stt:
		"on":
			ic.modulate = Color(1, 1, 1, 1)
			lb.add_theme_color_override("font_color", UiKit.TEXT)
		"off":
			ic.modulate = Color(0.85, 0.7, 0.65, 0.6)
			lb.add_theme_color_override("font_color", Color("c9a99a"))
		"lock":
			ic.modulate = Color(0.5, 0.5, 0.5, 0.2)
			lb.add_theme_color_override("font_color", Color(UiKit.DIM, 0.45))
	(c["lock"] as Control).visible = stt == "lock"
	(c["chk"] as Control).visible = stt == "on"
	(c["x"] as Control).visible = stt == "off"
	b.modulate = Color(1, 1, 1, 0.55) if pending else Color(1, 1, 1, 1)


func _off_count(rules: Dictionary) -> int:
	var n: int = 0
	for kind: int in Defense.AD_CLASSES:
		var poss: int = Defense.possible(kind)
		var m: int = int(rules.get(kind, Defense.R_ALL))
		for e: Array in Defense.LOC_AD_COLS:
			var bit: int = int(e[0])
			if (poss & bit) != 0 and (m & bit) == 0:
				n += 1
	return n


func _say(text: String, col: Color, sec: float = 4.0) -> void :
	_hint_until = Time.get_ticks_msec() + int(sec * 1000.0)
	U.set_lbl(_hint, text, col)
	hint_log.append(text)


func _focus(kind: int) -> void :
	var pc: Control = _cards[kind]["pc"]
	if not is_instance_valid(pc):
		return
	await get_tree().process_frame
	if is_instance_valid(_scroll) and is_instance_valid(pc):
		_scroll.scroll_vertical = maxi(0, int(pc.position.y) - 4)
		pc.modulate = Color(1.35, 1.25, 0.8)
		var tw: Tween = pc.create_tween()
		tw.tween_property(pc, "modulate", Color(1, 1, 1), 1.2).set_trans(Tween.TRANS_QUAD)




func _col_name(bit: int) -> String:
	for e: Array in Defense.LOC_AD_COLS:
		if int(e[0]) == bit:
			return Loc.t(String(e[1]))
	return ""


func _cell_tap(kind: int, bit: int) -> void :
	var poss: int = Defense.possible(kind)
	if (poss & bit) == 0:
		_say(Loc.t(String(LOC_LOCK_WHY[kind])), AMBER, 5.0)
		UiKit.snd("ui_cancel")
		return
	var pk: String = "%d:%d" % [kind, bit]
	if _pend.has(pk) or _pend.has("preset"):
		return
	var mask: int = int(_want.get(kind, gw.defense.rule_mask(player.id, kind)))
	var want: int = mask ^ bit
	_pend[pk] = Time.get_ticks_msec()
	if not _mask0.has(kind):
		_mask0[kind] = gw.defense.rule_mask(player.id, kind)
	_want[kind] = want
	sent += 1
	var on: bool = (want & bit) != 0
	_say(Loc.f("{cls} · {target}: {state}", {"cls": Loc.t(String(LOC_CLASS_NAME[kind])), "target": _col_name(bit), 
		"state": Loc.t("сбивают") if on else Loc.t("не трогают")}), UiKit.GREEN if on else UiKit.MUTED, 3.0)
	refresh()
	hud.main_node._sim("defense", "set_ad_rule", [player, kind, want], func(r: Variant) -> void :
		if r is String and String(r) != "":
			_pend.erase(pk)
			_want.erase(kind)
			_say(Loc.t("Не удалось изменить правило"), UiKit.RED, 3.0)
		if is_instance_valid(self):
			refresh())


func _preset_tap(key: String) -> void :
	if _pend.has("preset"):
		return
	if gw.defense.preset_of(player) == key:
		(_preset_btns[key] as Button).set_pressed_no_signal(true)
		_say(Loc.t(String(Defense.LOC_AD_PRESET_HINT[key])), UiKit.GOLD, 3.0)
		return
	_pend["preset"] = Time.get_ticks_msec()
	_pend["preset_key"] = key
	_want.clear()
	sent += 1
	_say(Loc.f("{p}: {hint}", {"p": Loc.t(String(Defense.LOC_AD_PRESETS[key])), "hint": Loc.t(String(Defense.LOC_AD_PRESET_HINT[key]))}), UiKit.GOLD, 3.5)
	refresh()
	hud.main_node._sim("defense", "set_ad_preset", [player, key], func(r: Variant) -> void :
		if r is String and String(r) != "":
			_pend.erase("preset")
			_say(Loc.t("Не удалось применить пресет"), UiKit.RED, 3.0)
		if is_instance_valid(self):
			refresh())
