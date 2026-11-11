class_name FlagEditor
extends RefCounted








static var tab: int = 0
static var slot: int = 0
static var hpage: int = 0

const HINT: String = "3–12 букв · видно на карте, на КПП и в дипломатии"
const UNDO_MASK: Array = ["...#.......", "..##.......", ".#########.", "##########.", ".##.....##.", "..#......##", ".........##", "........##.", "......###.."]



static var who: int = -1

static var from_profile: bool = false

var mn: Menus
var sp: Dictionary = {}
var undo: Array = []
var paints: Array[Callable] = []
var body: VBoxContainer
var name_edit: LineEdit
var hint: Label
var undo_b: Button
var _tabs: Array = []





static func ensure_identity() -> void :
	var dirty: bool = false
	var nm: String = NameGen.clean_country(GameConfig.my_name)
	if NameGen.country_name_error(nm) != "":
		nm = random_name()
		dirty = true
	GameConfig.my_name = nm
	if FlagMaker.decode(GameConfig.my_flag).is_empty():
		GameConfig.my_flag = FlagMaker.encode(FlagMaker.random_spec(Rng.new(randi()), -1, true))
		dirty = true
	if dirty:
		Save.save_prefs()


static func random_name() -> String:
	var r: = Rng.new(randi())
	for k in 12:
		var n: String = NameGen.country(r, [GameConfig.my_name])
		if NameGen.country_name_error(n) == "" and n.length() <= NameGen.NAME_MAX:
			return n
	return "Нордания"



static func flag_pic(code: String, w: int, h: int, k: int = 1, frame: int = 1) -> PanelContainer:
	var p: = PanelContainer.new()
	var s: = StyleBoxFlat.new()
	s.bg_color = UiKit.OUTLINE
	s.set_content_margin_all(frame)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var tr: = TextureRect.new()
	tr.name = "Pic"
	tr.texture = FlagMaker.tex(code, w, h)
	tr.custom_minimum_size = Vector2(w * k, h * k)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tr)
	return p



static func card(parent: Control, open: Callable, mp: bool = false) -> Button:
	ensure_identity()
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 60)
	var n: StyleBox = UiKit.sb("wb_panel_dark", 8, 2)
	var pr: StyleBox = UiKit.sb("wb_panel", 8, 2)
	for st: String in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, n)
	for st2: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st2, pr)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row: = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8.0
	row.offset_right = -8.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	b.add_child(row)
	row.add_child(flag_pic(GameConfig.my_flag, 30, 20, 2, 2))
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var nm: Label = UiKit.lbl("ФЛАГ ВАШЕЙ СТРАНЫ" if mp else Loc.name(GameConfig.my_name).to_upper(), 14 if mp else 16, UiKit.TITLE, 3, 4)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	col.add_child(UiKit.lbl(Loc.t("ВИДЯТ ВСЕ В СЕТИ · ИЗМЕНИТЬ") if mp else Loc.t("ФЛАГ И НАЗВАНИЕ · ИЗМЕНИТЬ"), 10, UiKit.MUTED, 1, 1))
	if UiKit.tex("wb_arrow_r") != null:
		var ic: TextureRect = UiKit.icon_rect("wb_arrow_r", 20.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	UiKit.press_fx(b)
	b.pressed.connect(open)
	parent.add_child(b)
	return b




func _init(menus: Menus) -> void :
	mn = menus
	ensure_identity()
	sp = FlagMaker.decode(String(_v("f")))


func code() -> String:
	return FlagMaker.encode(sp)



func _v(k: String) -> Variant:
	if who >= 0 and who < GameConfig.cb_list.size():
		return (GameConfig.cb_list[who] as Dictionary).get(k, "" if k != "l" else -1)
	return GameConfig.my_name if k == "n" else (GameConfig.my_flag if k == "f" else GameConfig.my_land)


func _nm() -> String:
	if from_profile and who < 0 and Account.username() != "":
		return NetConfig.clean_nick(Account.username())
	return String(_v("n"))



func _shown_nm() -> String:
	return Loc.name(_nm())


func _put(k: String, v: Variant) -> void :
	if who >= 0 and who < GameConfig.cb_list.size():
		(GameConfig.cb_list[who] as Dictionary)[k] = v
		return
	match k:
		"n":
			GameConfig.my_name = String(v)
		"f":
			GameConfig.my_flag = String(v)
		_:
			GameConfig.my_land = int(v)



func _land_now() -> int:
	if who >= 0:
		var ls: Array = GameWorld.cb_lands()
		return int(ls[who + 1]) if who + 1 < ls.size() else 0
	return GameWorld.land_pref()


func build(vb: VBoxContainer) -> void :
	vb.add_theme_constant_override("separation", 6)


	var head: = VBoxContainer.new()
	head.name = "Sticky"
	head.add_theme_constant_override("separation", 6)
	var outer: Node = mn._scroll.get_parent()
	outer.add_child(head)
	outer.move_child(head, mn._scroll.get_index())
	_hero(head)
	if not from_profile:
		_name_row(head)
	var tr: = HBoxContainer.new()
	tr.add_theme_constant_override("separation", 6)
	head.add_child(tr)
	_tabs.clear()
	for i in 3:
		var b: Button = _chip(["УЗОР", "ЦВЕТА", "ЭМБЛЕМА"][i], 40.0, 12)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ti: int = i
		b.pressed.connect( func() -> void :
			if tab != ti:
				tab = ti
				UiKit.snd("ui_select")
				_paint_tabs()
				_body())
		tr.add_child(b)
		_tabs.append(b)
	_paint_tabs()
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	vb.add_child(body)
	_body()
	var row: HBoxContainer = mn._bottom_row()
	undo_b = UiKit.slot("", false, 44.0)
	var ui: TextureRect = UiKit.slot_icon(undo_b)
	if ui != null:
		ui.texture = _mask_tex(UNDO_MASK, UiKit.TEXT)
		ui.custom_minimum_size = Vector2(22, 18)
		ui.size = ui.custom_minimum_size
		ui.stretch_mode = TextureRect.STRETCH_SCALE
	undo_b.tooltip_text = "Отменить"
	undo_b.pressed.connect(_undo)
	row.add_child(undo_b)
	var dice: Button = UiKit.big("СЛУЧАЙНЫЙ", "stone", "mi_dice", 44.0, 13)
	dice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice.pressed.connect( func() -> void :
		_push()
		sp = FlagMaker.random_spec(Rng.new(randi()), -1, true)
		slot = 0
		_changed(true))
	row.add_child(dice)
	var ok: Button = UiKit.big("ГОТОВО", "green", "", 44.0, 14)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect( func() -> void :
		_commit_name()
		Save.save_prefs()
		if who >= 0:
			mn.show_bot_editor(who)
		elif from_profile:
			from_profile = false
			mn.show_profile()
		else:
			mn.show_setup())
	row.add_child(ok)
	_paint_undo()



func _hero(vb: VBoxContainer) -> void :
	var box: = PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 6))
	vb.add_child(box)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	box.add_child(hb)
	var stage: = Control.new()
	stage.custom_minimum_size = Vector2(118, 86)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(stage)
	var pole: = ColorRect.new()
	pole.color = Color("8a6238")
	pole.position = Vector2(8, 10)
	pole.size = Vector2(4, 76)
	stage.add_child(pole)
	var hl: = ColorRect.new()
	hl.color = Color("b98a52")
	hl.position = Vector2(8, 10)
	hl.size = Vector2(2, 76)
	stage.add_child(hl)
	var tip: = ColorRect.new()
	tip.color = UiKit.TITLE
	tip.position = Vector2(6, 4)
	tip.size = Vector2(8, 8)
	stage.add_child(tip)
	var flag: = TextureRect.new()
	flag.position = Vector2(12, 8)
	flag.size = Vector2(96, 72)
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.stretch_mode = TextureRect.STRETCH_SCALE
	flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(flag)
	paints.append( func() -> void : flag.texture = _anim(code(), 48, 32, 2))
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(col)
	col.add_child(UiKit.lbl("КАК В ИГРЕ", 10, UiKit.MUTED, 2, 1))

	var tb: = PanelContainer.new()
	tb.add_theme_stylebox_override("panel", UiKit.sb("wb_panel", 4, 2))
	col.add_child(tb)
	var tbr: = HBoxContainer.new()
	tbr.add_theme_constant_override("separation", 5)
	tb.add_child(tbr)
	var tf: PanelContainer = flag_pic(code(), 24, 16, 1, 1)
	tbr.add_child(tf)
	var tn: Label = UiKit.lbl("", 12, UiKit.TEXT, 3, 3)
	tn.clip_text = true
	tn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tbr.add_child(tn)


	var land: = PanelContainer.new()
	land.name = "LandTint"
	var lsb: = StyleBoxFlat.new()
	lsb.set_border_width_all(2)
	lsb.content_margin_left = 4
	lsb.content_margin_right = 4
	lsb.content_margin_top = 2
	lsb.content_margin_bottom = 2
	land.add_theme_stylebox_override("panel", lsb)
	col.add_child(land)
	var ml: = HBoxContainer.new()
	ml.add_theme_constant_override("separation", 4)
	land.add_child(ml)
	paints.append( func() -> void :
		var lc: Color = land_color(_land_now())
		lsb.bg_color = Color(lc, 0.3)
		lsb.border_color = lc)
	var mf: PanelContainer = flag_pic(code(), 18, 12, 1, 2)
	ml.add_child(mf)
	var mt: Label = UiKit.lbl("", 12, UiKit.TEXT, 3, 4)
	mt.clip_text = true
	mt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ml.add_child(mt)

	var kr: = HBoxContainer.new()
	kr.add_theme_constant_override("separation", 6)
	col.add_child(kr)
	var kp: = Control.new()
	kp.custom_minimum_size = Vector2(44, 34)
	kp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kr.add_child(kp)
	var kpole: = ColorRect.new()
	kpole.color = Color("a8a49a")
	kpole.position = Vector2(2, 2)
	kpole.size = Vector2(3, 32)
	kp.add_child(kpole)
	var kf: = TextureRect.new()
	kf.position = Vector2(5, 2)
	kf.size = Vector2(FlagMaker.WORLD_W * 3, (FlagMaker.WORLD_H + 2) * 3)
	kf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	kf.stretch_mode = TextureRect.STRETCH_SCALE
	kf.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	kf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kp.add_child(kf)
	var kl: Label = UiKit.lbl("на КПП и\nнад городами", 10, UiKit.MUTED, 1, 1)
	kl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kr.add_child(kl)
	paints.append( func() -> void :
		var c: String = code()
		(tf.get_node("Pic") as TextureRect).texture = FlagMaker.tex(c, 24, 16)
		(mf.get_node("Pic") as TextureRect).texture = FlagMaker.tex(c, 18, 12)
		kf.texture = _anim(c, FlagMaker.WORLD_W, FlagMaker.WORLD_H, 1)
		tn.text = Loc.name(_nm()).to_upper()
		mt.text = Loc.name(_nm()).to_upper())


func _name_row(vb: VBoxContainer) -> void :
	var nr: = HBoxContainer.new()
	nr.add_theme_constant_override("separation", 6)
	vb.add_child(nr)
	var ne: = LineEdit.new()
	ne.text = _shown_nm()
	ne.max_length = NameGen.NAME_MAX
	ne.placeholder_text = "Название страны"
	ne.custom_minimum_size = Vector2(0, 44)
	ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ne.select_all_on_focus = true
	ne.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	ne.right_icon = UiKit.tex("net_edit")
	ne.add_theme_font_size_override("font_size", 16)
	ne.add_theme_color_override("font_placeholder_color", UiKit.MUTED)
	ne.text_changed.connect( func(t: String) -> void :
		if t == _shown_nm():
			return
		var cl: String = NameGen.clean_country(t)
		if cl != t and cl.to_lower() != t.strip_edges().to_lower():
			var cpos: int = ne.caret_column
			ne.text = cl
			ne.caret_column = mini(cpos, cl.length())
		var why: String = CustomBots.name_error(cl, who)
		_hint(why)
		if why == "":
			_put("n", cl)
			for p: Callable in paints:
				p.call())
	ne.text_submitted.connect( func(_t: String) -> void : ne.release_focus())
	ne.focus_entered.connect( func() -> void : _push())
	ne.focus_exited.connect(_commit_name)
	nr.add_child(ne)
	name_edit = ne
	var dice: Button = UiKit.slot("mi_dice", false, 44.0)
	dice.tooltip_text = "Случайное название"
	dice.pressed.connect( func() -> void :
		_push()
		_put("n", CustomBots.free_name(who))
		ne.text = _shown_nm()
		_hint("")
		_changed(false))
	nr.add_child(dice)
	hint = UiKit.lbl(HINT, 10, UiKit.MUTED, 1, 1)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hint)


func _hint(why: String) -> void :
	if hint == null or not is_instance_valid(hint):
		return
	hint.text = HINT if why == "" else why
	hint.add_theme_color_override("font_color", UiKit.MUTED if why == "" else UiKit.RED)



func _commit_name() -> void :
	if name_edit == null or not is_instance_valid(name_edit):
		return
	var cl: String = NameGen.clean_country(name_edit.text)
	if name_edit.text != _shown_nm() and CustomBots.name_error(cl, who) == "":
		_put("n", cl)
	name_edit.text = _shown_nm()
	_hint("")
	Save.save_prefs()
	for p: Callable in paints:
		p.call()


func _body() -> void :
	for ch: Node in body.get_children():
		ch.queue_free()
	paints = paints.slice(0, 3)
	match tab:
		0:
			_tab_layout()
		1:
			_tab_colors()
		_:
			_tab_emblem()
	for p: Callable in paints:
		p.call()


func _tab_layout() -> void :
	var g: = GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	body.add_child(g)
	for l in FlagMaker.LAYOUTS.size():
		var b: Button = _chip("", 48.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = String(FlagMaker.LAYOUTS[l])
		var pic: = TextureRect.new()
		pic.custom_minimum_size = Vector2(48, 32)
		pic.size = pic.custom_minimum_size
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pic)
		b.resized.connect( func() -> void : pic.position = ((b.size - pic.size) * 0.5).round())
		var li: int = l
		b.pressed.connect( func() -> void : _set_layout(li))
		g.add_child(b)
		paints.append( func() -> void :
			var s2: Dictionary = sp.duplicate(true)
			s2["l"] = li
			s2["e"] = 0
			pic.texture = FlagMaker.tex(FlagMaker.encode(s2), 24, 16)
			_paint_chip(b, int(sp["l"]) == li))
	var nm: Label = UiKit.lbl("", 10, UiKit.MUTED, 1, 1)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(nm)
	paints.append( func() -> void : nm.text = Loc.t("УЗОР: %s · цветов: %d") % [Loc.t(String(FlagMaker.LAYOUTS[int(sp["l"])])), int(FlagMaker.L_NCOL[int(sp["l"])])])


func _set_layout(l: int) -> void :
	if int(sp["l"]) == l:
		return
	_push()
	var was_def: bool = int(sp["p"]) == FlagMaker.default_place(int(sp["l"]))
	sp["l"] = l
	if was_def:
		sp["p"] = FlagMaker.default_place(l)
	_fix_colors()
	_changed(true)



func _fix_colors() -> void :
	pass


func _best_for(k: int) -> int:
	var cs: Array = sp["c"]
	return int(cs[k])



func _color_ok(_k: int, _v: int) -> bool:
	return true


func _tab_colors() -> void :
	var n: int = int(FlagMaker.L_NCOL[int(sp["l"])])
	slot = mini(slot, n - 1)
	body.add_child(_caption("ГОТОВЫЕ СОЧЕТАНИЯ"))
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 5)
	body.add_child(hr)
	var per: int = 5
	var pages: int = int(ceil(float(FlagMaker.HARMONY.size()) / per))
	for i in per:
		var b: Button = _chip("", 44.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pic: = TextureRect.new()
		pic.custom_minimum_size = Vector2(30, 20)
		pic.size = pic.custom_minimum_size
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pic)
		b.resized.connect( func() -> void : pic.position = ((b.size - pic.size) * 0.5).round())
		var ii: int = i
		b.pressed.connect( func() -> void :
			var hm: Array = FlagMaker.HARMONY[(hpage * per + ii) % FlagMaker.HARMONY.size()]
			_push()
			sp["c"] = hm.duplicate()
			sp["ec"] = FlagMaker.auto_ec(sp)
			_changed(false))
		hr.add_child(b)
		paints.append( func() -> void :
			var hm2: Array = FlagMaker.HARMONY[(hpage * per + ii) % FlagMaker.HARMONY.size()]
			pic.texture = _strip_tex(hm2)
			_paint_chip(b, sp["c"] == hm2))
	var more: Button = _chip("ЕЩЁ", 44.0, 11)
	more.custom_minimum_size.x = 50
	more.pressed.connect( func() -> void :
		hpage = (hpage + 1) % pages
		for p: Callable in paints:
			p.call())
	hr.add_child(more)
	body.add_child(_caption("ЦВЕТ ФЛАГА"))
	var sr: = HBoxContainer.new()
	sr.add_theme_constant_override("separation", 6)
	body.add_child(sr)
	for k in 3:
		var b2: Button = _chip("", 44.0, 11)
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.visible = k < n
		var r: = HBoxContainer.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_theme_constant_override("separation", 6)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b2.add_child(r)

		var sw: = TextureRect.new()
		sw.custom_minimum_size = Vector2(36, 24)
		sw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sw.stretch_mode = TextureRect.STRETCH_SCALE
		sw.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(sw)
		var kk: int = k
		b2.pressed.connect( func() -> void :
			slot = kk
			UiKit.snd("ui_select")
			for p: Callable in paints:
				p.call())
		sr.add_child(b2)
		paints.append( func() -> void :
			var s5: Dictionary = sp.duplicate(true)
			var mine: int = int((sp["c"] as Array)[kk])
			var grey: int = 15 if mine == 14 else 14
			for j in 3:
				if j != kk:
					(s5["c"] as Array)[j] = grey
			s5["e"] = 0
			sw.texture = FlagMaker.tex(FlagMaker.encode(s5), 18, 12)
			_paint_chip(b2, slot == kk))
	var ok_f: Callable = func(_v: int) -> bool: return true
	var cur_f: Callable = func(_v: int) -> int: return int((sp["c"] as Array)[slot])
	var pick_f: Callable = func(v: int) -> void :
		_push()
		(sp["c"] as Array)[slot] = v
		_changed(false)
	_palette(ok_f, cur_f, pick_f)
	body.add_child(_caption("Доступны все цвета палитры", false))
	_land_row()




func _land_row() -> void :
	paints.append(land_picker(body, who, func() -> int: return int(_v("l")), _land_now, func(l: int) -> void :
		if int(_v("l")) != l:
			_push()
			_put("l", l)
			_changed(false)))





static func land_picker(parent: Control, who_i: int, cur: Callable, now: Callable, pick: Callable, title: bool = true) -> Callable:
	if title:
		parent.add_child(UiKit.lbl("ЦВЕТ ЗЕМЛИ НА КАРТЕ", 10, UiKit.TITLE, 2, 1))
	var auto_b: Button = CustomBots._chip("АВТО · ПО ФЛАГУ", 40.0, 11)
	auto_b.name = "LandAuto"
	auto_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_b.pressed.connect( func() -> void :
		if int(cur.call()) >= 0:
			pick.call(-1))
	parent.add_child(auto_b)
	var sr: = GridContainer.new()
	sr.columns = 4
	sr.add_theme_constant_override("h_separation", 5)
	sr.add_theme_constant_override("v_separation", 5)
	parent.add_child(sr)
	var cap: Label = UiKit.lbl(Loc.t("Цвета с × выбрали другие страны партии") if CustomBots.any_held(who_i) else Loc.t("Боты этой партии возьмут другие цвета"), 10, UiKit.MUTED, 1, 1)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var reps: Array[Callable] = []
	for i in GameWorld.COUNTRY_STYLES.size():
		var b: = Button.new()
		b.name = "Land_%d" % i
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var li: int = i
		var x: TextureRect = TextureRect.new()
		x.texture = _mask_tex(["#...#", ".#.#.", "..#..", ".#.#.", "#...#"], Color(UiKit.OUTLINE, 0.9))
		x.custom_minimum_size = Vector2(10, 10)
		x.size = x.custom_minimum_size
		x.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		x.stretch_mode = TextureRect.STRETCH_SCALE
		x.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		x.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(x)
		b.resized.connect( func() -> void : x.position = ((b.size - x.size) * 0.5).round())
		UiKit.tap_snd(b)
		b.pressed.connect( func() -> void :
			if int(cur.call()) != li:
				pick.call(li))
		sr.add_child(b)
		reps.append( func() -> void :
			var on: bool = int(now.call()) == li
			var held: bool = CustomBots.land_holder(li, who_i) != "" and who_i >= 0
			x.visible = held
			b.modulate = Color(1, 1, 1, 0.4 if held else 1.0)
			var c: Color = land_color(li)
			var s: = StyleBoxFlat.new()
			s.bg_color = c
			s.border_color = UiKit.TITLE if on else c.darkened(0.45)
			s.set_border_width_all(4 if on else 2)
			s.border_width_top = 4 if on else 1
			for st: String in ["normal", "hover", "pressed", "hover_pressed"]:
				b.add_theme_stylebox_override(st, s))
	parent.add_child(cap)
	var rep: = func() -> void :
		CustomBots._paint_chip(auto_b, int(cur.call()) < 0)
		for r: Callable in reps:
			r.call()
	rep.call()
	return rep


static func land_color(i: int) -> Color:
	return Color.html(String((GameWorld.COUNTRY_STYLES[clampi(i, 0, GameWorld.COUNTRY_STYLES.size() - 1)] as Dictionary).get("map", "ffffff")))



func _palette(ok: Callable, cur: Callable, pick: Callable) -> void :
	var g: = GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 5)
	g.add_theme_constant_override("v_separation", 5)
	body.add_child(g)
	for v in FlagMaker.COLS.size():
		var b: = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = String((FlagMaker.COLS[v] as Array)[0])
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var vi: int = v
		b.pressed.connect( func() -> void :
			UiKit.snd("ui_select")
			pick.call(vi))
		g.add_child(b)
		var x: TextureRect = TextureRect.new()
		x.texture = _mask_tex(["#...#", ".#.#.", "..#..", ".#.#.", "#...#"], Color(UiKit.OUTLINE, 0.85))
		x.custom_minimum_size = Vector2(10, 10)
		x.size = x.custom_minimum_size
		x.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		x.stretch_mode = TextureRect.STRETCH_SCALE
		x.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		x.mouse_filter = Control.MOUSE_FILTER_IGNORE
		x.visible = false
		b.add_child(x)
		b.resized.connect( func() -> void : x.position = ((b.size - x.size) * 0.5).round())
		paints.append( func() -> void :
			var on: bool = int(cur.call(vi)) == vi
			var s: StyleBox = _swatch_sb(vi, on)
			for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				b.add_theme_stylebox_override(st, s)
			b.modulate = Color(1, 1, 1, 1.0)
			x.visible = false
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND)


func _tab_emblem() -> void :
	var g: = GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 5)
	g.add_theme_constant_override("v_separation", 5)
	body.add_child(g)
	for e in FlagMaker.EMBLEMS.size():
		var b: Button = _chip("НЕТ" if e == 0 else "", 48.0, 11)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = String(FlagMaker.EMB_NAMES[e])
		if e > 0:
			var pic: = TextureRect.new()
			var rows: Array = (FlagMaker.EMB_MASKS[FlagMaker.EMBLEMS[e]] as Dictionary)[15]
			pic.custom_minimum_size = Vector2(30, 30)
			pic.size = pic.custom_minimum_size
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_SCALE
			pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(pic)
			b.resized.connect( func() -> void : pic.position = ((b.size - pic.size) * 0.5).round())

			var ic_on: ImageTexture = _mask_tex(rows, UiKit.TITLE, Color("c97a00"))
			var ic_off: ImageTexture = _mask_tex(rows, UiKit.TEXT, Color("a8a49a"))
			var eix: int = e
			paints.append( func() -> void : pic.texture = ic_on if int(sp["e"]) == eix else ic_off)
		var ei: int = e
		b.pressed.connect( func() -> void :
			if int(sp["e"]) == ei:
				return
			_push()
			sp["e"] = ei
			_changed(false))
		g.add_child(b)
		paints.append( func() -> void : _paint_chip(b, int(sp["e"]) == ei))
	var nm: Label = _caption("")
	body.add_child(nm)
	paints.append( func() -> void : nm.text = Loc.t("ЭМБЛЕМА: %s") % Loc.t(FlagMaker.EMB_NAMES[int(sp["e"])]))
	body.add_child(_caption("ЦВЕТ ЭМБЛЕМЫ"))
	var ok_e: Callable = func(_v: int) -> bool: return true
	var cur_e: Callable = func(_v: int) -> int: return int(sp["ec"])
	var pick_e: Callable = func(v: int) -> void :
		_push()
		sp["ec"] = v
		if int(sp["e"]) == 0:
			sp["e"] = 1
		_changed(false)
	_palette(ok_e, cur_e, pick_e)
	body.add_child(_caption("Доступны все цвета палитры для эмблемы", false))
	_choice_row(Loc.t("МЕСТО", "emblem"), FlagMaker.PLACES, "p")
	_choice_row("РАЗМЕР", FlagMaker.SIZE_NAMES, "s")


func _choice_row(title: String, names: Array, key: String) -> void :
	var r: = HBoxContainer.new()
	r.add_theme_constant_override("separation", 5)
	body.add_child(r)
	var t: Label = UiKit.lbl(title, 10, UiKit.MUTED, 2, 1)
	t.custom_minimum_size = Vector2(54, 0)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(t)
	for i in names.size():
		var b: Button = _chip(String(names[i]), 44.0, 11)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ii: int = i
		b.pressed.connect( func() -> void :
			if int(sp[key]) == ii:
				return
			_push()
			sp[key] = ii
			if int(sp["e"]) == 0:
				sp["e"] = 1
			_changed(false))
		r.add_child(b)
		paints.append( func() -> void : _paint_chip(b, int(sp[key]) == ii))




func _push() -> void :
	var e: Array = [_nm(), code(), int(_v("l"))]
	if undo.is_empty() or undo.back() != e:
		undo.append(e)
		if undo.size() > 40:
			undo.pop_front()
	_paint_undo()


func _undo() -> void :
	while not undo.is_empty():
		var e: Array = undo.pop_back()
		if e != [_nm(), code(), int(_v("l"))]:
			if not from_profile:
				_put("n", String(e[0]))
			sp = FlagMaker.decode(String(e[1]))
			_put("l", int(e[2]) if e.size() > 2 else int(_v("l")))
			if name_edit != null and is_instance_valid(name_edit):
				name_edit.text = _shown_nm()
			_hint("")
			_changed(true, false)
			return
	_paint_undo()


func _changed(rebuild: bool, snd: bool = true) -> void :
	_put("f", code())
	Save.save_prefs()
	if snd:
		UiKit.snd("ui_select")
	if rebuild and tab == 1:
		_body()
	else:
		for p: Callable in paints:
			p.call()
	_paint_undo()


func _paint_undo() -> void :
	if undo_b != null and is_instance_valid(undo_b):
		undo_b.disabled = undo.is_empty()
		undo_b.modulate = Color(1, 1, 1, 1.0 if not undo.is_empty() else 0.45)


func _paint_tabs() -> void :
	for i in _tabs.size():
		_paint_chip(_tabs[i], i == tab)





func _chip(text: String, h: float, size: int = 12) -> Button:
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


func _paint_chip(b: Button, on: bool) -> void :
	if b == null or not is_instance_valid(b):
		return
	var s: StyleBox = UiKit.sb("wb_slot_active" if on else "wb_slot", 4)
	for st: String in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, s)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, UiKit.TITLE if on else UiKit.TEXT)


func _caption(t: String, gold: bool = true) -> Label:
	var l: Label = UiKit.lbl(t, 10, UiKit.TITLE if gold else UiKit.MUTED, 2 if gold else 1, 1)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _swatch_sb(v: int, on: bool) -> StyleBoxFlat:
	var s: = StyleBoxFlat.new()
	s.bg_color = FlagMaker.col(v)
	s.border_color = UiKit.TITLE if on else FlagMaker.col(v, 2).darkened(0.25)
	s.set_border_width_all(4 if on else 3)
	s.border_width_top = 4 if on else 2
	if not on:
		s.border_color = FlagMaker.col(v, 2).darkened(0.25)
	s.expand_margin_left = 1.0 if on else 0.0
	s.expand_margin_right = 1.0 if on else 0.0
	s.expand_margin_top = 1.0 if on else 0.0
	s.expand_margin_bottom = 1.0 if on else 0.0
	return s



static func _strip_tex(hm: Array) -> ImageTexture:
	var img: = Image.create(15, 10, false, Image.FORMAT_RGBA8)
	img.fill(UiKit.OUTLINE)
	for x in 15:
		var k: int = 0 if x < 7 else (1 if x < 11 else 2)
		if x == 7 or x == 11:
			continue
		for y in range(1, 9):
			img.set_pixel(x, y, FlagMaker.col(int(hm[k])))
	return ImageTexture.create_from_image(img)



func _anim(c: String, w: int, h: int, amp: int) -> AnimatedTexture:
	var fr: Array[ImageTexture] = FlagMaker.frames(c, w, h, amp, 3)
	var at: = AnimatedTexture.new()
	at.frames = fr.size()
	for i in fr.size():
		at.set_frame_texture(i, fr[i])
		at.set_frame_duration(i, 1.0 / 6.0)
	return at



static func _mask_tex(rows: Array, a: Color, b: Color = Color.TRANSPARENT) -> ImageTexture:
	var w: int = String(rows[0]).length()
	var img: = Image.create(w, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var r: String = rows[y]
		for x in w:
			if r[x] == "#":
				img.set_pixel(x, y, a)
			elif r[x] == "o":
				img.set_pixel(x, y, b if b.a > 0.0 else a.darkened(0.3))
	return ImageTexture.create_from_image(img)
