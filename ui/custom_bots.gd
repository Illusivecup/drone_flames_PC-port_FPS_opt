class_name CustomBots
extends RefCounted





const DIFF_HINT: Array = ["Доход ×0,7 · решает раз в 14 с · малые армии", "Доход ×1 · решает раз в 9 с · как обычно", "Доход ×1,5 · решает раз в 5 с · крупные наступления"]
const DIFF_COL: Array = [Color("a2e35f"), Color("ffd75e"), Color("ff6a4d")]
const DIFF_SHORT: Array = ["ЛЁГКИЙ", "НОРМА", "СЛОЖНЫЙ"]
const AUTO_DESC: String = "Как у обычных ботов: мирные и агрессивные вперемешку"

static var _arm: Dictionary = {}




static func money_text(v: int) -> String:
	return Loc.inum(v)


static func money_i(v: int) -> int:
	var best: int = 0
	for i in GameConfig.MONEY_STEPS.size():
		if absi(int(GameConfig.MONEY_STEPS[i]) - v) < absi(int(GameConfig.MONEY_STEPS[best]) - v):
			best = i
	return best


static func names_taken(skip: int) -> Array:
	var out: Array = [GameConfig.my_name] if skip != -1 else []
	for j in GameConfig.cb_list.size():
		if j != skip:
			out.append(String((GameConfig.cb_list[j] as Dictionary).get("n", "")))
	return out



static func name_error(nm: String, who: int) -> String:
	var why: String = NameGen.country_name_error(nm)
	if why != "":
		return why
	if who == -1 and not GameConfig.cb_on:
		return ""
	for t: String in names_taken(who):
		if t.to_lower() == nm.to_lower():
			return Loc.t("Так уже зовут %s — нужно другое") % (Loc.t("вашу страну") if t == GameConfig.my_name and who != -1 else Loc.t("врага"))
	return ""


static func free_name(who: int = -2) -> String:
	var r: = Rng.new(randi())
	var taken: Array = names_taken(who)
	if who != -1:
		taken.append(GameConfig.my_name)
	for k in 24:
		var n: String = NameGen.country(r, taken)
		if NameGen.country_name_error(n) == "" and n.length() <= NameGen.NAME_MAX and not taken.any( func(t: String) -> bool: return t.to_lower() == n.to_lower()):
			return n
	return Loc.t("Враг %s") % ("АБВГДЕЖ" if Loc.cur() == "ru" or Loc.cur() == "uk" else "ABCDEFG")[mini(GameConfig.cb_list.size(), 6)]


static func new_entry() -> Dictionary:
	return {"n": free_name(), "f": FlagMaker.encode(FlagMaker.random_spec(Rng.new(randi()), -1, true)), "l": -1, 
		"d": clampi(GameConfig.difficulty, 0, 2), "p": "", "m": 3000, "a": -1}




static func land_holder(li: int, who: int) -> String:
	if who >= 0 and GameWorld.land_pref() == li:
		return GameConfig.my_name
	if who == -1 and not GameConfig.cb_on:
		return ""
	for j in GameConfig.cb_list.size():
		if j != who and int((GameConfig.cb_list[j] as Dictionary).get("l", -1)) == li:
			return String((GameConfig.cb_list[j] as Dictionary).get("n", ""))
	return ""


static func any_held(who: int) -> bool:
	for li in GameWorld.COUNTRY_STYLES.size():
		if land_holder(li, who) != "":
			return true
	return false



static func sanitize() -> void :
	var out: Array = []
	for e: Variant in GameConfig.cb_list:
		if not (e is Dictionary) or out.size() >= GameConfig.CB_MAX:
			continue
		var d: Dictionary = e
		var b: Dictionary = {"n": NameGen.clean_country(String(d.get("n", ""))), "f": String(d.get("f", "")), 
			"l": clampi(int(d.get("l", -1)), -1, GameWorld.COUNTRY_STYLES.size() - 1), "d": clampi(int(d.get("d", 1)), 0, 2), 
			"p": String(d.get("p", "")), "m": int(GameConfig.MONEY_STEPS[money_i(int(d.get("m", 3000)))]), 
			"a": clampi(int(d.get("a", -1)), -1, ArchStyle.NAMES.size() - 1)}
		if not AiPersona.ids().has(b["p"]):
			b["p"] = ""
		if FlagMaker.decode(String(b["f"])).is_empty():
			b["f"] = FlagMaker.encode(FlagMaker.random_spec(Rng.new(randi()), -1, true))
		out.append(b)
	GameConfig.cb_list = out
	for i in out.size():
		if name_error(String((out[i] as Dictionary)["n"]), i) != "":
			(out[i] as Dictionary)["n"] = free_name(i)
	GameConfig.my_money = int(GameConfig.MONEY_STEPS[money_i(GameConfig.my_money)])
	sync_count()



static func sync_count() -> void :
	if GameConfig.cb_on:
		GameConfig.bots = clampi(GameConfig.cb_list.size(), 1, GameConfig.CB_MAX)



static func seed_list() -> void :
	if not GameConfig.cb_list.is_empty():
		return
	for k in clampi(GameConfig.bots, 1, GameConfig.CB_MAX):
		GameConfig.cb_list.append(new_entry())



static func crowded(n: int) -> bool:
	return GameConfig.size_i == 0 and n > 5





static func card(parent: Control, open: Callable, multiplayer: bool = false) -> Button:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 72)
	var n0: StyleBox = UiKit.sb("wb_panel_dark", 8, 2)
	var pr: StyleBox = UiKit.sb("wb_panel", 8, 2)
	for st: String in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, n0)
	for st2: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st2, pr)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row: = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10.0
	row.offset_right = -8.0
	row.offset_top = 6.0
	row.offset_bottom = -6.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	b.add_child(row)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var n: int = GameConfig.cb_list.size()
	var tr: = HBoxContainer.new()
	tr.add_theme_constant_override("separation", 6)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tr)
	var t: Label = UiKit.lbl(_count_word(n) if n > 0 else Loc.t("НЕТ ВРАГОВ"), 14, UiKit.TITLE if n > 0 else UiKit.RED, 3, 3)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.add_child(t)
	var ed: Label = UiKit.lbl("ИЗМЕНИТЬ", 10, UiKit.MUTED, 2, 1)
	ed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.add_child(ed)
	var ic: TextureRect = UiKit.icon_rect("wb_arrow_r", 20.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.add_child(ic)
	if n == 0:
		col.add_child(UiKit.lbl("Добавьте хотя бы одного", 10, UiKit.MUTED, 1, 1))
	else:
		var fl: = HBoxContainer.new()
		fl.add_theme_constant_override("separation", 4)
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(fl)
		var lands: Array = GameWorld.cb_lands()
		for i in n:
			fl.add_child(_mini_flag(String((GameConfig.cb_list[i] as Dictionary)["f"]), int(lands[i + 1])))
		var lo: int = 1 << 30
		var hi: int = 0
		for e: Dictionary in GameConfig.cb_list:
			lo = mini(lo, int(e["m"]))
			hi = maxi(hi, int(e["m"]))
		var mt: String = money_text(lo) if lo == hi else "%s–%s" % [money_text(lo), money_text(hi)]
		if multiplayer:
			col.add_child(UiKit.lbl(Loc.t("%d КАСТОМНЫХ БОТОВ") % n, 10, UiKit.MUTED, 1, 1))
		else:
			col.add_child(UiKit.lbl(Loc.t("ВЫ %s · ВРАГИ %s") % [money_text(GameConfig.my_money), mt], 10, UiKit.MUTED, 1, 1))
	UiKit.press_fx(b)
	b.pressed.connect(open)
	parent.add_child(b)
	return b


static func _count_word(n: int) -> String:
	return Loc.n(n, "%d ВРАГ", "%d ВРАГА", "%d ВРАГОВ") % n



static func _mini_flag(code: String, land: int) -> VBoxContainer:
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(FlagEditor.flag_pic(code, 24, 16, 1, 1))
	var bar: = ColorRect.new()
	bar.color = FlagEditor.land_color(land)
	bar.custom_minimum_size = Vector2(26, 3)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar)
	return v




static func build_list(mn: Menus, vb: VBoxContainer, multiplayer: bool = false) -> void :
	sanitize()
	vb.add_theme_constant_override("separation", 6)
	if not multiplayer:
		mn._section(vb, Loc.t("ВЫ · %s") % Loc.name(GameConfig.my_name).to_upper())
		if GameConfig.creative:
			mn._label(vb, "Творческий режим: у вас деньги без лимита", 10, UiKit.MUTED)
		else:
			mn._selector(vb, "СТАРТОВЫЙ КАПИТАЛ", GameConfig.MONEY_STEPS.map( func(v: int) -> String: return money_text(v)),
				func() -> int: return money_i(GameConfig.my_money), func(i: int) -> void :
					GameConfig.my_money = int(GameConfig.MONEY_STEPS[i])
					Save.save_prefs(), 100.0, "")
	var n: int = GameConfig.cb_list.size()
	mn._section(vb, Loc.t("КАСТОМНЫЕ БОТЫ · %d ИЗ %d") % [n, GameConfig.CB_MAX] if multiplayer else Loc.t("ВРАГИ · %d ИЗ %d") % [n, GameConfig.CB_MAX])
	if n == 0:
		var em: = PanelContainer.new()
		em.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 10))
		vb.add_child(em)
		var ev: = VBoxContainer.new()
		ev.add_theme_constant_override("separation", 4)
		em.add_child(ev)
		var et: Label = UiKit.lbl("ВРАГОВ НЕТ", 14, UiKit.RED, 3, 3)
		et.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ev.add_child(et)
		var ed: Label = UiKit.lbl("Без соперника партия не начнётся. Нажмите «+ ВРАГ» внизу.", 10, UiKit.MUTED, 1, 1)
		ed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ev.add_child(ed)
	var lands: Array = GameWorld.cb_lands()
	for i in n:
		_bot_row(mn, vb, i, int(lands[i + 1]))
	if crowded(n):
		mn._label(vb, Loc.t("Малая карта, %d врагов: тесно — войны сразу") % n, 10, UiKit.TITLE)
	if GameConfig.aggression == 0 and n > 0:
		mn._label(vb, "Правило «ИИ: МИРНЫЕ» — войн не начнёт никто, даже милитаристы", 10, UiKit.TITLE)
	if n >= GameConfig.CB_MAX:
		mn._label(vb, "7 врагов — предел: больше стран карта не раскрасит", 10, UiKit.MUTED)
	var row: HBoxContainer = mn._bottom_row()
	var add: Button = UiKit.big("ВРАГ", "stone", "icon_plus", 44.0, 14)
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add.disabled = n >= GameConfig.CB_MAX
	add.pressed.connect( func() -> void :
		if GameConfig.cb_list.size() >= GameConfig.CB_MAX:
			return
		GameConfig.cb_list.append(new_entry())
		sync_count()
		Save.save_prefs()
		UiKit.snd("ui_select")
		mn.show_custom_bots(true))
	row.add_child(add)
	var ok: Button = UiKit.big("ГОТОВО", "green", "", 44.0, 14)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.size_flags_stretch_ratio = 1.4
	ok.pressed.connect( func() -> void :
		Save.save_prefs()
		mn.show_setup())
	row.add_child(ok)



static func _bot_row(mn: Menus, vb: VBoxContainer, i: int, land: int) -> void :
	var e: Dictionary = GameConfig.cb_list[i]
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 56)
	var n0: StyleBox = UiKit.sb("wb_panel_dark", 8, 2)
	var pr: StyleBox = UiKit.sb("wb_panel", 8, 2)
	for st: String in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, n0)
	for st2: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st2, pr)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(b)
	var row: = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8.0
	row.offset_right = -6.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	b.add_child(row)
	var fv: = VBoxContainer.new()
	fv.add_theme_constant_override("separation", 2)
	fv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fv)
	fv.add_child(FlagEditor.flag_pic(String(e["f"]), 30, 20, 1, 2))
	var bar: = ColorRect.new()
	bar.color = FlagEditor.land_color(land)
	bar.custom_minimum_size = Vector2(34, 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fv.add_child(bar)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var nm: Label = UiKit.name_lbl(String(e["n"]).to_upper(), 14, UiKit.TITLE, 3, 3)
	col.add_child(nm)
	UiKit.fit_lbl(nm, [14, 13, 12], false, true)
	var sub: = HBoxContainer.new()
	sub.add_theme_constant_override("separation", 4)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sub)
	var P: Dictionary = AiPersona.by_id(String(e["p"]))
	sub.add_child(UiKit.lbl(String(P["name"]) if String(e["p"]) != "" else Loc.t("СЛУЧАЙНЫЙ"), 10, UiKit.MUTED, 2, 1))
	sub.add_child(UiKit.lbl("·", 10, UiKit.DIM, 1, 1))
	sub.add_child(UiKit.lbl(String(DIFF_SHORT[int(e["d"])]), 10, DIFF_COL[int(e["d"])], 2, 1))
	var mv: = HBoxContainer.new()
	mv.add_theme_constant_override("separation", 3)
	mv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mv)
	var mi: TextureRect = UiKit.icon_rect("res_money", 18.0)
	mi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mv.add_child(mi)
	mv.add_child(UiKit.lbl(money_text(int(e["m"])), 12, UiKit.GOLD, 2, 2))
	var ic: TextureRect = UiKit.icon_rect("wb_arrow_r", 20.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	UiKit.press_fx(b)
	var bi: int = i
	b.pressed.connect( func() -> void : mn.show_bot_editor(bi))




static func build_bot(mn: Menus, vb: VBoxContainer, i: int) -> void :
	var e: Dictionary = GameConfig.cb_list[i]
	vb.add_theme_constant_override("separation", 6)

	var idc: Button = _id_card(e, int(GameWorld.cb_lands()[i + 1]))
	idc.pressed.connect( func() -> void : mn.show_flag_editor(i))
	vb.add_child(idc)
	mn._section(vb, "СЛОЖНОСТЬ")
	var dr: = HBoxContainer.new()
	dr.add_theme_constant_override("separation", 6)
	vb.add_child(dr)
	var dh: Label = UiKit.lbl("", 10, UiKit.MUTED, 1, 1)
	dh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var dchips: Array = []
	for d in 3:
		var c: Button = _chip(String(DIFF_SHORT[d]), 40.0, 12)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var di: int = d
		c.pressed.connect( func() -> void :
			e["d"] = di
			Save.save_prefs()
			for k in dchips.size():
				_paint_chip(dchips[k], k == di)
			dh.text = String(DIFF_HINT[di]))
		dr.add_child(c)
		dchips.append(c)
		_paint_chip(c, d == int(e["d"]))
	dh.text = String(DIFF_HINT[int(e["d"])])
	vb.add_child(dh)
	mn._section(vb, "ХАРАКТЕР")
	var ph: Label = UiKit.lbl("", 10, UiKit.MUTED, 1, 1)
	ph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var pcs: Array = []
	var auto_b: Button = _chip("СЛУЧАЙНЫЙ", 40.0, 11)
	vb.add_child(auto_b)
	pcs.append([auto_b, ""])
	var g: = GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	vb.add_child(g)
	for P: Dictionary in AiPersona.LIST:
		var pb: Button = _persona_card(P)
		g.add_child(pb)
		pcs.append([pb, String(P["id"])])
	var paint_p: = func() -> void :
		for it: Array in pcs:
			_paint_chip(it[0], String(it[1]) == String(e["p"]))
		ph.text = AUTO_DESC if String(e["p"]) == "" else String(AiPersona.by_id(String(e["p"]))["desc"])
	for it2: Array in pcs:
		var pid: String = String(it2[1])
		(it2[0] as Button).pressed.connect( func() -> void :
			e["p"] = pid
			Save.save_prefs()
			paint_p.call())
	var pp: = PanelContainer.new()
	pp.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 6))
	pp.custom_minimum_size = Vector2(0, 44)
	vb.add_child(pp)
	ph.add_theme_color_override("font_color", UiKit.TEXT)
	ph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pp.add_child(ph)
	paint_p.call()
	if GameConfig.aggression == 0:
		mn._label(vb, "Правило «ИИ: МИРНЫЕ» в ЕЩЁ ПРАВИЛА: войн не начнёт никто", 10, UiKit.TITLE, false)
	mn._section(vb, "ОБЛИК СТРАНЫ")
	_look_picker(vb, e)
	mn._sep(vb, 2)
	mn._selector(vb, "СТАРТОВЫЙ КАПИТАЛ", GameConfig.MONEY_STEPS.map( func(v: int) -> String: return money_text(v)), 
		func() -> int: return money_i(int(e["m"])), func(k: int) -> void :
			e["m"] = int(GameConfig.MONEY_STEPS[k])
			Save.save_prefs(), 100.0, "")
	mn._label(vb, Loc.t("Обычно 3 000 · у вас %s") % money_text(GameConfig.my_money), 10, UiKit.MUTED, false)

	mn._section(vb, "ЦВЕТ ЗЕМЛИ НА КАРТЕ")
	FlagEditor.land_picker(vb, i, func() -> int: return int(e.get("l", -1)), func() -> int: return int(GameWorld.cb_lands()[i + 1]), 
		func(l: int) -> void :
			e["l"] = l
			Save.save_prefs()
			UiKit.snd("ui_select")
			mn.show_bot_editor(i, true), false)
	var row: HBoxContainer = mn._bottom_row()
	var rs: Button = UiKit.big("СБРОСИТЬ", "stone", "", 44.0, 12)
	rs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.pressed.connect( func() -> void :
		if not _confirm(rs, "rs", "ТОЧНО?"):
			return
		var ne: Dictionary = new_entry()
		GameConfig.cb_list[i] = ne
		Save.save_prefs()
		mn.show_bot_editor(i))
	row.add_child(rs)
	var del: Button = UiKit.big("УДАЛИТЬ", "red", "", 44.0, 12)
	del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del.pressed.connect( func() -> void :
		if not _confirm(del, "del", "ТОЧНО?"):
			return
		GameConfig.cb_list.remove_at(i)
		sync_count()
		Save.save_prefs()
		mn.show_custom_bots())
	row.add_child(del)
	var ok: Button = UiKit.big("ГОТОВО", "green", "", 44.0, 13)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect( func() -> void :
		Save.save_prefs()
		mn.show_custom_bots())
	row.add_child(ok)




static func _look_picker(vb: VBoxContainer, e: Dictionary) -> void :
	var chips: Array = []
	var auto_b: Button = _chip("СЛУЧАЙНЫЙ", 40.0, 11)
	vb.add_child(auto_b)
	chips.append([auto_b, -1])
	var g: = GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	vb.add_child(g)
	for a in ArchStyle.NAMES.size():
		var b: Button = _chip("", 92.0, 11)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col: = VBoxContainer.new()
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 4.0
		col.offset_right = -4.0
		col.offset_top = 5.0
		col.offset_bottom = -4.0
		col.add_theme_constant_override("separation", 3)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)
		var pc: = CenterContainer.new()
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_child(MpKit.style_card(a, 1))
		col.add_child(pc)
		var t: Label = UiKit.lbl(String(ArchStyle.NAMES[a]), 10, UiKit.TEXT, 2, 2)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.max_lines_visible = 2
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(t)
		b.set_meta("lbl", t)
		g.add_child(b)
		chips.append([b, a])
	var pp: = PanelContainer.new()
	pp.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 6))
	pp.custom_minimum_size = Vector2(0, 44)
	vb.add_child(pp)
	var lh: Label = UiKit.lbl("", 10, UiKit.TEXT, 1, 1)
	lh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pp.add_child(lh)
	var paint: = func() -> void :
		var cur: int = int(e.get("a", -1))
		for it: Array in chips:
			_paint_chip(it[0], int(it[1]) == cur)
		if cur < 0:
			lh.text = "Как у обычных ботов: облик выпадет по карте — здания и названия городов"
		else:
			lh.text = Loc.t("%s\nГорода: %s") % [String(ArchStyle.HINTS[cur]), ", ".join(NameGen.city_examples(cur, 3))]
	for it2: Array in chips:
		var av: int = int(it2[1])
		(it2[0] as Button).pressed.connect( func() -> void :
			e["a"] = av
			Save.save_prefs()
			paint.call())
	paint.call()



static func _confirm(b: Button, key: String, ask: String) -> bool:
	var now: int = Time.get_ticks_msec()
	if int(_arm.get(key, 0)) > now:
		_arm.erase(key)
		return true
	_arm[key] = now + 3000
	var was: String = b.text
	b.text = ask
	UiKit.snd("ui_select")
	b.get_tree().create_timer(3.0).timeout.connect( func() -> void :
		if is_instance_valid(b) and b.text == ask:
			b.text = was)
	return false


static func _id_card(e: Dictionary, land: int) -> Button:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 72)
	var sb: = StyleBoxFlat.new()
	var lc: Color = FlagEditor.land_color(land)
	sb.bg_color = Color(lc.darkened(0.55), 0.85)
	sb.border_color = lc
	sb.set_border_width_all(2)
	sb.border_width_left = 6
	sb.set_corner_radius_all(0)
	var sp: = sb.duplicate() as StyleBoxFlat
	sp.bg_color = Color(lc.darkened(0.35), 0.9)
	for st: String in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, sb)
	for st2: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st2, sp)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row: = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12.0
	row.offset_right = -8.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	b.add_child(row)
	row.add_child(FlagEditor.flag_pic(String(e["f"]), 30, 20, 2, 2))
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var nm: Label = UiKit.name_lbl(String(e["n"]).to_upper(), 16, UiKit.TITLE, 3, 4)
	col.add_child(nm)
	UiKit.fit_lbl(nm, [16, 14, 13], false, true)
	col.add_child(UiKit.lbl("ФЛАГ И НАЗВАНИЕ · ИЗМЕНИТЬ", 10, UiKit.MUTED, 1, 1))
	var ic: TextureRect = UiKit.icon_rect("wb_arrow_r", 20.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	UiKit.press_fx(b)
	return b



static func _persona_card(P: Dictionary) -> Button:
	var b: Button = _chip("", 44.0, 11)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hr: = HBoxContainer.new()
	hr.set_anchors_preset(Control.PRESET_FULL_RECT)
	hr.offset_left = 8.0
	hr.offset_right = -6.0
	hr.add_theme_constant_override("separation", 6)
	hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hr)
	if UiKit.has(String(P["icon"])):
		var ic: TextureRect = UiKit.icon_rect(String(P["icon"]), 20.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hr.add_child(ic)
	var t: Label = UiKit.lbl(String(P["name"]), 11, UiKit.TEXT, 3, 3)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(t)
	UiKit.fit_lbl(t, [11, 10], false, true)
	b.set_meta("lbl", t)
	return b


static func _chip(text: String, h: float, size: int = 12) -> Button:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.clip_contents = true
	b.add_theme_font_override("font", UiKit.f_black)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_color_override("font_outline_color", UiKit.OUTLINE)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_paint_chip(b, false)
	UiKit.tap_snd(b)
	return b


static func _paint_chip(b: Button, on: bool) -> void :
	if b == null or not is_instance_valid(b):
		return
	if b.has_meta("lbl"):
		(b.get_meta("lbl") as Label).add_theme_color_override("font_color", UiKit.TITLE if on else UiKit.TEXT)
	var s: StyleBox = UiKit.sb("wb_slot_active" if on else "wb_slot", 4)
	for st: String in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, s)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, UiKit.TITLE if on else UiKit.TEXT)
