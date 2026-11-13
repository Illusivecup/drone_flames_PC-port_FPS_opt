extends "res://ui/hud/hud_base.gd"


func _safe_margins() -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var vp: Vector2 = root.get_viewport_rect().size
	if win.x <= 0.0:
		return Vector2.ZERO
	var s: float = vp.x / win.x
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector2.ZERO
	var top_m: float = maxf(0.0, float(safe.position.y) * s)
	var bot_m: float = maxf(0.0, (win.y - float(safe.end.y)) * s)
	if top_m > 90.0 or bot_m > 90.0:
		return Vector2.ZERO
	return Vector2(top_m, bot_m)


func _tooltip_panel() -> PanelContainer:
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_tooltip", 8, 5))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p



func key_title(nm: String) -> Array:
	var info: Array = KEY_INFO.get(nm, [nm, nm, ""])
	if BUILD_KIND_OF.has(nm):
		var kind: int = BUILD_KIND_OF[nm]
		var per: String = Loc.t(" за клетку") if nm == "trench" or nm == "teeth" else ""
		var purpose: String = String(Military.PURPOSE.get(kind, ""))
		return [Military.title_of(kind), "%s · %s%s" % [_sentence(purpose), Economy.cost_text(Economy.build_cost(kind)), per]]
	var sub: String = String(info[2])
	if nm == "town":
		sub = "%s · %d" % [sub, Military.town_cost(gw.player.towns_founded if gw != null and gw.player != null else 0)]
	elif nm == "rail_st":
		sub = Loc.t("%s · %s · ~%d мин") % [sub, Economy.cost_text(RailBuild.station_cost()), ceili(Rail.MAN_ST_TIME / 60.0)]
	elif nm == "rail_line":
		sub = Loc.t("%s · ~%d за 100 м, 3–5 мин") % [sub, roundi(Rail.MAN_PX_COST * 100.0)]
	return [String(info[1]), sub]


func key_icon(nm: String) -> String:
	for def: Array in PAGE_DEFS:
		for it: Array in def[1]:
			if String(it[0]) == nm:
				return String(it[1])
	return {"pause": "icon_pause", "speed": "icon_speed"}.get(nm, "")


static func _sentence(s: String) -> String:

	if s == "":
		return ""
	var parts: PackedStringArray = s.to_lower().split(". ")
	for i in parts.size():
		parts[i] = parts[i].substr(0, 1).to_upper() + parts[i].substr(1)
	return ". ".join(parts)


func _show_tip_for(nm: String) -> void :
	if BUILD_KIND_OF.has(nm) and gw != null and gw.player != null:
		_show_build_tip(nm)
		return
	var t: Array = key_title(nm)
	var warn: String = ""
	if GameConfig.hints and BUILD_KIND_OF.has(nm) and gw != null and gw.player != null and gw.econ.has_method("build_hint"):
		warn = String(gw.econ.call("build_hint", int(BUILD_KIND_OF[nm]), gw.player))
	if BUILD_KIND_OF.has(nm) and gw != null and gw.player != null and gw.econ.has_method("can_substitute"):
		var bc: Dictionary = Economy.build_cost(int(BUILD_KIND_OF[nm]))
		if gw.econ.can_substitute(bc, gw.player):
			warn += ("\n" if warn != "" else "") + Loc.t("%s (второй тап по месту)") % gw.econ.substitute_note(bc, gw.player)
	show_tip(String(t[0]), String(t[1]), warn)


func show_tip(t: String, sub: String, warn: String = "", cost: Dictionary = {}, yld: String = "") -> void :
	tip_title.text = t
	if tip_yield != null:
		tip_yield.text = yld
		tip_yield.visible = yld != ""
	tip_sub.text = sub
	tip_sub.visible = sub != ""
	tip_warn.text = warn
	tip_warn.visible = warn != ""
	_fill_tip_cost(cost)
	tip_pc.visible = true
	tip_pc.modulate.a = 1.0
	tip_pc.custom_minimum_size = Vector2(root.size.x - 20.0, 0)
	tip_box.custom_minimum_size.x = root.size.x - 44.0
	tip_pc.reset_size()
	if tip_pc.size.x > root.size.x - 12.0:
		tip_pc.size.x = root.size.x - 20.0
	_place_tip()
	UiKit.pop_in(tip_pc, 0.85, 0.2)
	_tip_shown = Time.get_ticks_msec() / 1000.0
	_tip_until = _tip_shown + 6.0



func _show_build_tip(nm: String) -> void :
	var kind: int = BUILD_KIND_OF[nm]
	var p: Country = gw.player
	var bc: Dictionary = Economy.build_cost(kind)
	var hint: String = ""
	var warn: bool = false
	if gw.econ.has_method("can_substitute") and gw.econ.can_substitute(bc, p):
		hint = Loc.t("Замена: %s — второй тап по месту") % _short_line(String(gw.econ.substitute_note(bc, p)).trim_prefix(Loc.t("ЗАМЕНИТЬ: ")), 40)
		warn = true
	elif GameConfig.hints and gw.econ.has_method("build_hint"):
		for ln: String in String(gw.econ.call("build_hint", kind, p, true)).split("\n"):
			if ln != "":
				hint = _short_line(ln, 64)
				warn = true
				break
	if hint == "":
		hint = _short_line(_sentence(String(Military.PURPOSE.get(kind, ""))), 64)
	if nm == "trench" or nm == "teeth":
		hint = Loc.t("Цена за клетку. ") + Loc.t(hint)
	var yl: String = EconRates.build_yield(gw, p, kind)
	var ser: String = ArmyBudget.series_line(gw, kind)
	if ser != "":
		bc = bc.duplicate()
		bc["money"] = gw.mil.price_of(kind, p)
		hint = ser + ("" if hint == "" or not warn else " · " + hint)
		warn = true
	show_tip(Military.title_of(kind), "" if warn else hint, hint if warn else "", bc, (Loc.t("ДАЁТ: ") + yl) if yl != "" else "")



static func _short_line(s: String, n: int) -> String:
	var t: String = s.strip_edges()
	var dot: int = t.find(". ")
	if dot > 0:
		t = t.substr(0, dot)
	if t.length() > n:
		for sep: String in [": ", " — ", " (", ", "]:
			var i: int = t.find(sep)
			if i >= 12 and i <= n:
				t = t.substr(0, i)
				break
	if t.length() > n:
		t = t.substr(0, n - 1).strip_edges() + "…"
	return t.trim_suffix(".")


func _fill_tip_cost(cost: Dictionary) -> void :
	for ch in tip_cost.get_children():
		ch.queue_free()
	tip_cost.visible = not cost.is_empty()
	var p: Country = gw.player if gw != null else null
	var keys2: Array = cost.keys()
	keys2.sort_custom( func(a: String, b: String) -> bool: return a == "money" and b != "money")
	for k: String in keys2:
		var need: int = int(cost[k])
		if need <= 0:
			continue
		var have: int = int(p.get(k)) if p != null else need
		var pair: = HBoxContainer.new()
		pair.add_theme_constant_override("separation", 3)
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic: TextureRect = UiKit.icon_rect("res_money" if k == "money" else _res_icon(k), 16.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(ic)
		var miss: bool = have < need
		var l: Label = UiKit.lbl((Loc.t("%d (есть %d)") % [need, have]) if miss else str(need), 11, UiKit.RED if miss else UiKit.TEXT, 2, 3)
		if k != "money":
			l.text = "%s %s" % [String(Economy.RES_NAMES.get(k, k)).to_lower(), l.text]
		pair.add_child(l)
		tip_cost.add_child(pair)


func _place_tip() -> void :
	if tip_pc.size.y > tip_pc.get_combined_minimum_size().y + 2.0:
		tip_pc.reset_size()
	tip_pc.position = Vector2(10, holder.position.y + (tab_row.position.y if not ops_panel.visible else 0.0) - tip_pc.size.y - 2.0)


static func _set_lbl(l: Label, text: String, col: Color) -> void :
	if not is_instance_valid(l):
		return
	if l.text != text:
		l.text = text
	if not l.has_theme_color_override("font_color") or l.get_theme_color("font_color") != col:
		l.add_theme_color_override("font_color", col)

func ui24_open_now() -> bool:
	return ui24_sheet != null and is_instance_valid(ui24_sheet) and ui24_sheet.visible


func _warn_col(key: String, warn: bool) -> void :
	var l: Label = res_labels[key]
	if bool(l.get_meta("warn", false)) != warn:
		l.set_meta("warn", warn)
		l.add_theme_color_override("font_color", UiKit.RED if warn else UiKit.TEXT)


func _slider(parent: Control, title: String, prop: String, mn: int, mx: int) -> void :
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var l: Label = UiKit.lbl(title, 10, UiKit.MUTED, 2)
	l.custom_minimum_size = Vector2(96, 0)
	row.add_child(l)
	var s: = HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 1
	s.value = int(dlg_settings.get(prop))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 32)
	row.add_child(s)
	var v: Label = UiKit.lbl(str(int(s.value)), 10, UiKit.TITLE, 2)
	v.custom_minimum_size = Vector2(28, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	s.value_changed.connect( func(val: float) -> void :
		dlg_settings.set(prop, int(val))
		v.text = str(int(val)))


static func _mmss(sec: float) -> String:
	var t: int = maxi(0, int(ceil(sec)))
	return "%d:%02d" % [t / 60, t % 60]



static func smart_line(sm: Dictionary) -> String:
	var src: String = DroneBrain.src_code(String(sm.get("source", "")))
	var t: String = Loc.t("УМНЫЙ МАРШРУТ: %s") % Loc.t({"memory": "ПАМЯТЬ", "new": "ОБХОД ОПАСНЫХ ЗОН", "direct": "ПРЯМО, УГРОЗ НЕ ЗНАЕМ"}.get(src, src.to_upper()))
	if int(sm.get("wins", 0)) + int(sm.get("losses", 0)) > 0:
		t += " ✓%d ✕%d" % [int(sm.get("wins", 0)), int(sm.get("losses", 0))]
	return t



static func _act(t: String, icon: String, a: String, on: bool, sel: int = -1, badge: String = "") -> Dictionary:
	return {"t": t, "i": icon, "a": a, "on": on, "sel": sel, "badge": badge}


static func _res_line(cost: Dictionary) -> String:
	const NAMES: Dictionary = {"titanium": "титан", "metal": "металл", "wood": "дерево", "oil": "нефть", "precious": "драгметаллы", "food": "еда", "fuel": "топливо", "goods": "товары", "uranium": "уран"}
	var out: PackedStringArray = PackedStringArray()
	for k: String in cost:
		if k != "money":
			out.append("%s %d" % [String(NAMES.get(k, k)), int(cost[k])])
	return ", ".join(out)




func close_panel() -> void :
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
	panel = null
	panel_kind = ""



func _window(title: String, kind: String = "") -> VBoxContainer:
	var same: bool = kind != "" and kind == panel_kind and panel != null and is_instance_valid(panel)
	var keep_pos: Vector2 = panel.position if same else Vector2.ZERO
	var keep_scroll: int = 0
	var keep_h: float = 0.0
	var keep_settled: bool = same and panel.has_meta("settled")
	if same and panel.has_meta("scroll"):
		keep_scroll = (panel.get_meta("scroll") as ScrollContainer).scroll_vertical
		keep_h = (panel.get_meta("scroll") as ScrollContainer).custom_minimum_size.y
	_win_refresh = same
	close_panel()
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.sb("wb_window", 12, 12))
	panel.custom_minimum_size = Vector2(minf(344.0, root.size.x - 12.0), 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 7)
	panel.add_child(vb)
	var hr: = HBoxContainer.new()
	vb.add_child(hr)


	var t: Label = UiKit.title(title, 20 if title.length() <= 20 else 16)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 60.0
	hr.add_child(t)
	var cb: Button = UiKit.close_btn(36.0)
	cb.pressed.connect( func() -> void :
		UiKit.snd("ui_close")
		dip_hint_treaty = ""
		close_panel())
	hr.add_child(cb)

	var sc: = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sc)
	var inner: = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 7)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	panel.set_meta("scroll", sc)
	panel.set_meta("inner", inner)
	_fix_scroll_input.call_deferred(inner)
	sc.custom_minimum_size.y = keep_h
	if keep_scroll > 0:
		sc.set_deferred("scroll_vertical", keep_scroll)
	var p: PanelContainer = panel
	p.resized.connect( func() -> void :
		p.pivot_offset = p.size * 0.5
		var top_y: float = _win_top()
		var bot: float = holder.position.y - win_reserve - 4.0
		var py: float = maxf(top_y, top_y + (bot - top_y - p.size.y) * 0.5)
		if p.has_meta("settled"):

			py = clampf(p.position.y, top_y, maxf(top_y, bot - p.size.y))
		p.position = Vector2(roundf((root.size.x - p.size.x) * 0.5), roundf(py)))
	if same:
		p.position = keep_pos
		if keep_settled:
			p.set_meta("settled", true)
		else:
			_settle_later(p)
		return inner
	_settle_later(p)
	p.scale = Vector2(0.88, 0.88)
	p.modulate.a = 0.0
	var tw: Tween = p.create_tween().set_parallel(true)
	tw.tween_property(p, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.14)
	UiKit.snd("ui_open")
	return inner




func _win_top() -> float:
	var y: float = top_col.position.y
	for i: int in mini(2, top_col.get_child_count()):
		var c: Control = top_col.get_child(i) as Control
		if c != null and c.visible:
			y = maxf(y, top_col.position.y + c.position.y + c.size.y)
	return y + 4.0



func _settle_later(p: Control) -> void :
	var pid: int = p.get_instance_id()
	get_tree().create_timer(0.5).timeout.connect( func() -> void :
		var w: Object = instance_from_id(pid)
		if w != null and is_instance_valid(w):
			(w as Control).set_meta("settled", true))



func _finger_down() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or _sd_sc != null


func _small_btn(text: String, act: String, enabled: bool = true, colour: String = "stone") -> Button:
	var b: Button = UiKit.big(text, colour, "", 40.0, 10)
	b.disabled = not enabled
	b.pressed.connect( func() -> void : action.emit(act))
	return b


func _flag(c: Country) -> TextureRect:
	var fl: = TextureRect.new()
	fl.texture = FlagMaker.tex_for(c, Vector2(24, 16))
	fl.custom_minimum_size = Vector2(24, 16)
	fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fl.stretch_mode = TextureRect.STRETCH_SCALE
	fl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return fl



func _fix_scroll_input(_n: Node) -> void :
	pass




func _button_under() -> BaseButton:
	var c: Control = get_viewport().gui_get_hovered_control()
	for i in 4:
		if c == null or not root.is_ancestor_of(c):
			return null
		if c is BaseButton:
			return c as BaseButton
		c = c.get_parent() as Control
	return null





func _cancel_tap() -> void :
	if tap_guard != null:
		tap_guard.call("cancel")
	if _tap_btn != null and is_instance_valid(_tap_btn) and not _tap_btn.disabled:
		_tap_btn.disabled = true
		_tap_btn.disabled = false
	_tap_btn = null


func _rowbox(parent: Control) -> HBoxContainer:
	var pc: = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 6, 4))
	parent.add_child(pc)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	pc.add_child(row)
	return row




func _econ(fn: String, args: Array, fallback: Variant) -> Variant:
	if gw != null and gw.econ != null and gw.econ.has_method(fn):
		return gw.econ.callv(fn, args)
	return fallback







func _shortage(p: Country) -> String:
	var low: String = ""
	for r: String in RAW:
		if int(_econ("need", [p, r], 0)) <= 0:
			continue
		var cap: int = int(_econ("res_cap", [p, r], 0))
		var n: int = int(p.get(r))
		if cap > 0 and n >= cap:
			continue
		if n <= 0:
			return r
		if low == "":
			low = r
	return low


func _res_icon(key: String) -> String:
	for nm2: String in [String(Economy.RES_ICONS_BIG.get(key, "")), String(Economy.RES_ICONS.get(key, ""))]:
		if nm2 != "" and UiKit.has(nm2):
			return nm2
	for it: Array in STORE:
		if String(it[0]) == key:
			var ic: String = String(it[2])
			if UiKit.has(ic):
				return ic
	return {"titanium": "res_titanium", "fuel": "res_fuel", "food": "res_food", "goods": "res_goods"}.get(key, "res_goods")


static func _per_min(v: int) -> String:
	return ("+%d" % v) if v > 0 else str(v)


func _res_name(key: String) -> String:
	for it: Array in STORE:
		if String(it[0]) == key:
			return String(it[1]).to_lower()
	return key


static func short_num(v: int) -> String:
	if absi(v) >= 100000:
		return "%dK" % (v / 1000)
	if absi(v) >= 10000:
		return "%.1fK" % (float(v) / 1000.0)
	return str(v)




func _hub_ok() -> bool:
	return gw != null and gw.player != null and holder != null and bottom_panel != null


func _tut_on() -> bool:
	return get_parent() != null and get_parent().get("tutorial") != null and bool(get_parent().tutorial.get("active"))



static func pending_urgent(it: Dictionary) -> bool:
	var k: String = String(it.get("kind", ""))
	return k == "demand" or k == "surrender" or k == "conference" or (k == "react" and int(it.get("stage", 0)) >= 2)
