extends VBoxContainer







const U = preload("res://ui/ui24/econ_kit.gd")
const ER = preload("res://game/econ_rates.gd")
const Bar = preload("res://ui/ui24/bar_track.gd")
const AMBER: = Color("ffb000")
const ROW_H: float = 44.0
const NAMES: Dictionary = {"titanium": "ТИТАН", "food": "ЕДА", "metal": "МЕТАЛЛ", "precious": "ДРАГМЕТАЛЛЫ", "oil": "НЕФТЬ", 
	"wood": "ДЕРЕВО", "fuel": "ТОПЛИВО", "goods": "ТОВАРЫ", "uranium": "УРАН"}
const SHORT: Dictionary = {"titanium": "ТИТАН", "food": "ЕДА", "metal": "МЕТАЛЛ", "precious": "ДРАГМЕТ.", "oil": "НЕФТЬ", 
	"wood": "ДЕРЕВО", "fuel": "ТОПЛИВО", "goods": "ТОВАРЫ", "uranium": "УРАН"}
const GEN: Dictionary = {"titanium": "титана", "food": "еды", "metal": "металла", "precious": "драгметаллов", "oil": "нефти", 
	"wood": "дерева", "fuel": "топлива", "goods": "товаров", "uranium": "урана"}
const ICON: Dictionary = {"titanium": "icon_r_titanium", "food": "res_food", "metal": "icon_r_metal", "precious": "icon_r_precious", 
	"oil": "icon_r_oil", "wood": "icon_r_wood", "fuel": "res_fuel", "goods": "res_goods", "uranium": "icon_r_uranium"}

const EAT_ICON: Dictionary = {"food": "icon_barracks", "fuel": "icon_airfield", "oil": "icon_refinery", "uranium": "icon_npp", 
	"metal": "icon_dronefactory", "titanium": "icon_missile_factory", "precious": "icon_ad_patriot", "wood": "icon_factory", "goods": "icon_port"}

const RES_COL: Dictionary = {"titanium": Color("9fc7e8"), "food": Color("e8c34a"), "metal": Color("b8b8b0"), "precious": Color("ffd75e"), 
	"oil": Color("6f6a8a"), "wood": Color("b57a43"), "fuel": Color("ff8a3d"), "goods": Color("7cccff"), "uranium": Color("9bff6a")}
const EMPTY_TXT: Dictionary = {
	Facility.Kind.FARM: "Колхозов нет. Ключ «КОЛХОЗ» на вкладке ГОРОДА — на любую свою землю.", 
	Facility.Kind.CIV_FACTORY: "Заводов товаров нет. Ключ «ЗАВОД» на вкладке ГОРОДА; нужно питание.", 
	Facility.Kind.MINE: "Рудников на этой руде нет. Рудник ставят на залежь (значок руды на карте).", 
	Facility.Kind.OIL_RIG: "Нефтевышек нет. Вышку ставят на нефть (чёрный значок на карте).", 
	Facility.Kind.SAWMILL: "Лесопилок нет. Ключ «ЛЕСОПИЛКА» — рядом с лесом.", 
	Facility.Kind.URANIUM_MINE: "Урановых шахт нет. Шахта — только на залежь урана; нужно питание.", 
	Facility.Kind.REFINERY: "НПЗ нет. Ключ «НПЗ» на вкладке ГОРОДА; нужны нефть и питание.", 
}

var hub: Node
var gw: GameWorld
var player: Country
var key: String = ""
var stage: int = 0
var scroll: ScrollContainer
var stages: Array = []
var rebuilds: int = 0
var shown: Dictionary = {}
var _compact: bool = false
var _icon: TextureRect
var _title: Label
var _stock: Label
var _bar
var _vals: Array = []
var _chain: Control
var _cells: Array = []
var _bn: PanelContainer
var _bn_lbl: Label
var _bn_btn: Button
var _bn_fix: String = ""
var _head: Label
var _list: VBoxContainer
var _rows: Dictionary = {}
var _sig: String = ""
var _drawer: Control = null


func setup(h: Node, compact: bool) -> void :
	hub = h
	gw = hub.hud.gw
	player = hub.player
	_compact = compact
	name = "ResSheet"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_head()
	_build_strip()
	_chain = ChainRow.new()
	_chain.custom_minimum_size = Vector2(0, 70 if compact else 78)
	add_child(_chain)
	_bn = PanelContainer.new()
	var sb: StyleBox = UiKit.sb("wb_btn_red_p", 5, 0)
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	_bn.add_theme_stylebox_override("panel", sb)
	_bn.visible = false
	add_child(_bn)
	var bh: = HBoxContainer.new()
	bh.add_theme_constant_override("separation", 5)
	_bn.add_child(bh)
	_bn_lbl = UiKit.lbl("", 10, Color("ffe0d4"), 2, 2)
	_bn_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bn_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bn_lbl.max_lines_visible = 2
	_bn_lbl.add_theme_constant_override("line_spacing", -3)
	bh.add_child(_bn_lbl)
	_bn_btn = UiKit.big("ИСПРАВИТЬ", "green", "", 36.0, 9)
	_bn_btn.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_green", 7, 4, -1))
	_bn_btn.add_theme_stylebox_override("pressed", UiKit.sb("wb_btn_green_p", 7, 4, 1))
	_bn_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit._touch_pad(_bn_btn)
	_bn_btn.pressed.connect( func() -> void :
		if _bn_fix != "":
			hub.call("res_fix", _bn_fix))
	bh.add_child(_bn_btn)
	_head = UiKit.lbl("", 10, UiKit.TITLE, 2, 2)
	_head.clip_text = true
	_head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_head)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)



func show_res(res: String, want: String = "") -> void :
	key = res
	stages = _stage_defs(res)
	stage = -1
	for i: int in stages.size():
		if want != "" and String(stages[i]["id"]) + ":" + str(int(stages[i].get("kind", -1))) == want:
			stage = i
	if stage < 0:
		stage = maxi(0, _res_index() - 1)
	U.set_icon(_icon, String(ICON[res]), 24.0)
	U.set_lbl(_title, Loc.t(String(NAMES[res])), UiKit.TITLE)
	_build_chain()
	_sig = ""
	refresh(true)


func stage_id() -> String:
	if stage < 0 or stage >= stages.size():
		return ""
	return String(stages[stage]["id"]) + ":" + str(int(stages[stage].get("kind", -1)))


func _res_index() -> int:
	for i: int in stages.size():
		if String(stages[i]["id"]) == "res":
			return i
	return 0


func _stage_defs(res: String) -> Array:
	var a: Array = []
	if ER.DEPOSIT_RES.has(res):
		a.append({"id": "dep", "kind": -1, "res": res, "cap": "ЗАЛЕЖИ", "icon": String(ICON[res]), "deposit": true})
	for k: int in ER.MAKERS.get(res, []):
		var r2: String = "oil" if res == "fuel" and k == Facility.Kind.OIL_RIG else res
		a.append({"id": "make", "kind": k, "res": r2, "cap": String(ER.PLURAL.get(k, Military.title_of(k).to_upper())), "icon": Military.icon_of(k)})
	a.append({"id": "res", "kind": -1, "res": res, "cap": String(SHORT[res]), "icon": String(ICON[res])})
	a.append({"id": "out", "kind": -1, "res": res, "cap": "РАСХОД", "icon": String(EAT_ICON.get(res, "icon_trade"))})
	return a




func _build_head() -> void :
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.custom_minimum_size = Vector2(0, 40 if _compact else 44)
	add_child(hb)
	var back: = Button.new()
	back.name = "ResBack"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(44, 40 if _compact else 44)
	for s: Array in [["normal", "wb_btn_stone", -1], ["hover", "wb_btn_stone", -1], ["pressed", "wb_btn_stone_p", 1], ["hover_pressed", "wb_btn_stone_p", 1]]:
		back.add_theme_stylebox_override(String(s[0]), UiKit.sb(String(s[1]), 4, 4, float(s[2])))
	back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ar: TextureRect = U.icon("wb_arrow_l", 28.0)
	back.add_child(ar)
	back.resized.connect( func() -> void : ar.position = ((back.size - ar.size) * 0.5).round() + Vector2(0, -1))
	back.pressed.connect( func() -> void :
		UiKit.snd("ui_tab")
		hub.call("close_res", true))
	hb.add_child(back)
	var gb: = CenterContainer.new()
	gb.custom_minimum_size = Vector2(28, 0)
	gb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(gb)
	_icon = U.icon("res_fuel", 24.0)
	gb.add_child(_icon)
	_title = UiKit.lbl("", 16 if _compact else 18, UiKit.TITLE, 3, 2)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hb.add_child(_title)
	var sc: = VBoxContainer.new()
	sc.add_theme_constant_override("separation", 1)
	sc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sc.custom_minimum_size = Vector2(76, 0)
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(sc)
	_stock = UiKit.lbl("0/0", 11, UiKit.TEXT, 2, 2)
	_stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sc.add_child(_stock)
	_bar = Bar.new()
	_bar.custom_minimum_size = Vector2(76, 8)
	_bar.min_px = 0.0
	sc.add_child(_bar)
	var cb: Button = UiKit.close_btn(40.0 if _compact else 44.0)
	cb.pressed.connect( func() -> void :
		UiKit.snd("ui_close")
		hub.call("close_res", false)
		hub.action.emit("close"))
	hb.add_child(cb)


func _build_strip() -> void :
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	add_child(hb)
	for it: Array in [["ПРИХОД", UiKit.GREEN], ["РАСХОД", UiKit.RED], ["ИТОГ", UiKit.TEXT]]:
		var pc: = PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 6, 2))
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.size_flags_stretch_ratio = 1.25 if String(it[0]) == "ИТОГ" else 1.0
		hb.add_child(pc)
		var v: = VBoxContainer.new()
		v.add_theme_constant_override("separation", -3)
		pc.add_child(v)
		var top: = HBoxContainer.new()
		top.add_theme_constant_override("separation", 3)
		v.add_child(top)
		var cap: Label = UiKit.lbl(Loc.t("ИТОГ", "balance") if String(it[0]) == "ИТОГ" else String(it[0]), 9, UiKit.MUTED, 2, 2)
		top.add_child(cap)
		var val: Label = UiKit.lbl("0", 13, it[1] as Color, 2, 2)
		_vals.append(val)
		if String(it[0]) == "ИТОГ":
			var sub: Label = UiKit.lbl("", 9, UiKit.MUTED, 2, 2)
			sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			sub.clip_text = true
			sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			top.add_child(sub)
			var vh: = HBoxContainer.new()
			vh.add_theme_constant_override("separation", 3)
			v.add_child(vh)
			vh.add_child(val)
			var u2: Label = UiKit.lbl("/мин", 9, UiKit.MUTED, 2, 2)
			u2.size_flags_vertical = Control.SIZE_SHRINK_END
			vh.add_child(u2)
			_vals.append(sub)
		else:
			var vh2: = HBoxContainer.new()
			vh2.add_theme_constant_override("separation", 3)
			v.add_child(vh2)
			vh2.add_child(val)
			var u3: Label = UiKit.lbl("/мин", 9, UiKit.MUTED, 2, 2)
			u3.size_flags_vertical = Control.SIZE_SHRINK_END
			vh2.add_child(u3)


func _build_chain() -> void :
	for ch: Node in _chain.get_children():
		_chain.remove_child(ch)
		ch.queue_free()
	_cells.clear()
	var big: float = 48.0 if _compact else 52.0
	var small: float = 40.0 if _compact else 44.0
	for i: int in stages.size():
		var sd: Dictionary = stages[i]
		var is_res: bool = String(sd["id"]) == "res"
		var b: = Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for s: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, _chain.custom_minimum_size.y)
		_chain.add_child(b)
		var v: = VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var dc: = CenterContainer.new()
		dc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dc.custom_minimum_size = Vector2(0, big + 2.0)
		v.add_child(dc)
		var d: = Disc.new()
		d.r = int((big if is_res else small) * 0.5)
		d.custom_minimum_size = Vector2(d.r * 2, d.r * 2)
		d.res_col = RES_COL.get(key, UiKit.GOLD)
		d.is_res = is_res
		d.deposit = bool(sd.get("deposit", false))
		dc.add_child(d)
		var ic: TextureRect = U.icon(String(sd["icon"]), 24.0)
		d.add_child(ic)
		d.icon = ic
		d.call_deferred("place_icon")
		var cap: Label = UiKit.lbl(String(sd["cap"]), 9, UiKit.MUTED, 2, 2)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.clip_text = true
		v.add_child(cap)
		var val: Label = UiKit.lbl("", 10, UiKit.TEXT, 2, 2)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.clip_text = true
		val.add_theme_constant_override("line_spacing", -2)
		v.add_child(val)
		var idx: int = i
		b.pressed.connect( func() -> void : select(idx, true))
		_cells.append({"btn": b, "disc": d, "cap": cap, "val": val})
	(_chain as ChainRow).cells = _cells
	_chain.queue_redraw()


func select(i: int, user: bool) -> void :
	if i == stage and not user:
		return
	if user:
		UiKit.snd("ui_tab")
	stage = i
	_sig = ""
	scroll.scroll_vertical = 0
	refresh(true)




func refresh(force: bool = false) -> void :
	if player == null or key == "":
		return
	var e: Economy = gw.econ
	var n: int = int(player.get(key))
	var cap: int = e.res_cap(player, key)
	U.set_lbl(_stock, "%d/%d" % [n, cap], UiKit.TEXT)
	_bar.fill_name = "wb_bar_amber" if cap > 0 and n >= cap else ("wb_bar_red" if n <= 0 else "wb_bar_green")
	_bar.frac = float(n) / float(maxi(1, cap))
	var bal: Dictionary = ER.balance(gw, player, key)
	var tin: int = int(bal["tin"])
	var tout: int = int(bal["tout"])
	var net: int = tin - tout
	U.set_lbl(_vals[0], U.signed(tin) if tin != 0 else "0", UiKit.GREEN if tin > 0 else UiKit.MUTED)
	U.set_lbl(_vals[1], ("−" + U.num(tout)) if tout > 0 else "0", UiKit.RED if tout > 0 else UiKit.MUTED)
	U.set_lbl(_vals[2], ("▲ " if net > 0 else ("▼ " if net < 0 else "")) + U.signed(net), UiKit.GREEN if net > 0 else (UiKit.RED if net < 0 else UiKit.MUTED))
	var sub: String = "ровно"
	var sc: Color = UiKit.MUTED
	if net > 0 and cap > 0:
		sub = Loc.t("полон") if n >= cap else Loc.t("полон через %s") % [U.mmss(float(cap - n) / float(net) * 60.0)]
		sc = AMBER if n >= cap else UiKit.MUTED
	elif net < 0:
		sub = Loc.t("пусто") if n <= 0 else Loc.t("0 через %s") % [U.mmss(float(n) / float( - net) * 60.0)]
		sc = UiKit.RED.lightened(0.2)
	U.set_lbl(_vals[3], sub, sc)
	shown = {"in": tin, "out": tout, "net": net, "rows": {}, "stage_total": 0.0, "cells": {}}

	var cache: Dictionary = {}
	for i: int in stages.size():
		var sd: Dictionary = stages[i]
		var c: Dictionary = _cells[i]
		var d = c["disc"]
		var txt: String = ""
		var col: Color = UiKit.TEXT
		var warn: int = 0
		match String(sd["id"]):
			"dep":
				var deps: Array = ER.deposits(gw, player, key)
				cache[i] = deps
				var free: int = 0
				for dd: Dictionary in deps:
					if String(dd["state"]) == "free":
						free += 1
				txt = (Loc.t("%d · своб. %d") % [deps.size(), free]) if free > 0 else ("%d" % deps.size() if not deps.is_empty() else Loc.t("нет"))
				col = UiKit.GREEN if free > 0 else UiKit.MUTED
			"make":
				var rows: Array = ER.producers(gw, player, String(sd["res"]), int(sd["kind"]))
				cache[i] = rows
				var t: float = ER.total(rows)
				txt = (Loc.t("%s/мин") % [ER.fmt(t)]) if not rows.is_empty() else Loc.t("нет")
				col = UiKit.GREEN if t > 0.0 else (UiKit.MUTED if rows.is_empty() else AMBER)
				for r: Dictionary in rows:
					warn = maxi(warn, ER._prob(r))
				shown["cells"][i] = t
			"res":
				txt = "%d/%d" % [n, cap]
				col = UiKit.TEXT
				d.fill = float(n) / float(maxi(1, cap))
			"out":
				var gs: Array = ER.consumers(gw, player, key)
				cache[i] = gs
				txt = (Loc.t("−%s/мин") % [U.num(tout)]) if tout > 0 else Loc.t("0/мин")
				col = UiKit.RED.lightened(0.15) if tout > 0 else UiKit.MUTED
				shown["cells"][i] = - float(tout)
		U.set_lbl(c["val"], txt, col)
		U.set_lbl(c["cap"], String(sd["cap"]), UiKit.TITLE if i == stage else UiKit.MUTED)
		d.selected = i == stage
		d.warn = warn
		if d.dirty:
			d.queue_redraw()

	for i2: int in range(0, stages.size() - 1):
		var a: Dictionary = stages[i2]
		var b: Dictionary = stages[i2 + 1]
		if String(a["id"]) == "make" and String(b["id"]) == "make" and cache.get(i2) is Array and cache.get(i2 + 1) is Array:
			var made: float = ER.total(cache[i2])
			var eat: float = ER.total(cache[i2 + 1], "use")
			var da = _cells[i2]["disc"]
			if eat > made + 0.5 and int(da.warn) < 1:
				da.warn = 1
				if da.dirty:
					da.queue_redraw()
	_fill_problem()
	_fill_list(cache.get(stage, null), force)


func _fill_problem() -> void :
	var ch: Dictionary = hub.call("chain_for_res", key)
	var st: String = String(ch.get("status", ""))
	var on: bool = st == "bad" or st == "warn"
	U.set_vis(_bn, on)
	if on:
		_bn_fix = String(ch.get("fix", ""))
		U.set_lbl(_bn_lbl, String(ch.get("full", ch.get("text", ""))).trim_suffix("."), Color("ffe0d4"))
		_bn_btn.visible = _bn_fix != ""
	else:
		_bn_fix = ""




func _fill_list(data: Variant, force: bool) -> void :
	var sd: Dictionary = stages[stage]
	var id: String = String(sd["id"])
	var items: Array = []
	var head: String = ""
	match id:
		"dep":
			var deps: Array = data if data is Array else ER.deposits(gw, player, key)
			var nf: int = 0
			for dd: Dictionary in deps:
				if String(dd["state"]) == "free":
					nf += 1
				items.append(["d%d_%d" % [(dd["cell"] as Vector2i).x, (dd["cell"] as Vector2i).y], "dep", dd])
			head = Loc.t("ЗАЛЕЖИ %s НА ВАШЕЙ ЗЕМЛЕ · %d") % [Loc.t(String(GEN[key])).to_upper(), deps.size()] + (Loc.t(" · СВОБОДНО %d") % nf if nf > 0 else "")
			if deps.is_empty():
				items.append(["empty", "note", Loc.t("Своих залежей %s нет: земля растёт с городами, ресурс можно купить на рынке.") % Loc.t(String(GEN[key]))])
		"make":
			var rows: Array = data if data is Array else ER.producers(gw, player, String(sd["res"]), int(sd["kind"]))
			var t: float = ER.total(rows)
			head = Loc.t("%s · %d · СЕЙЧАС %s/мин") % [String(sd["cap"]), rows.size(), ER.fmt(t)]
			if int(sd["kind"]) == Facility.Kind.REFINERY:
				head += Loc.t(" · НЕФТЬ −%s") % ER.fmt(ER.total(rows, "use"), false)
			shown["stage_total"] = t
			for r: Dictionary in rows:
				items.append(["f%d" % int(r["id"]), "fac", r])
				shown["rows"][int(r["id"])] = float(r["n"])
			if rows.is_empty():
				items.append(["empty", "note", String(EMPTY_TXT.get(int(sd["kind"]), "Таких построек нет."))])
		"res":
			var bal: Dictionary = ER.balance(gw, player, key)
			head = "ОТКУДА И КУДА · ПОСЛЕДНЯЯ МИНУТА"
			items.append(["hin", "sec", ["ПРИХОД", int(bal["tin"]), UiKit.GREEN]])
			for k: String in _sorted(bal["in"]):
				items.append(["i_" + k, "src", [k, int(bal["in"][k]), 1]])
			if (bal["in"] as Dictionary).is_empty():
				items.append(["i_none", "note", "За минуту ничего не пришло."])
			items.append(["hout", "sec", ["РАСХОД", - int(bal["tout"]), UiKit.RED]])
			for k2: String in _sorted(bal["out"]):
				items.append(["o_" + k2, "src", [k2, int(bal["out"][k2]), -1]])
			if (bal["out"] as Dictionary).is_empty():
				items.append(["o_none", "note", "За минуту ничего не ушло."])
			items.append(["hmkt", "sec", ["РЫНОК", 0, UiKit.GOLD]])
			items.append(["mkt", "market", key])
		"out":
			var gs: Array = data if data is Array else ER.consumers(gw, player, key)
			var tot: float = 0.0
			for g: Dictionary in gs:
				tot += float(g["n"])
			head = Loc.t("КУДА УХОДИТ %s · %s/мин") % [Loc.t(String(GEN[key])).to_upper(), ER.fmt( - tot) if tot > 0.0 else "0"]
			for g2: Dictionary in gs:
				items.append(["g_" + String(g2["key"]), "grp", g2])
				for r2: Dictionary in g2["rows"]:
					items.append(["g_%s_%d" % [String(g2["key"]), int(r2["id"])], "fac", r2])
			if gs.is_empty():
				items.append(["empty", "note", Loc.t("За последнюю минуту %s не расходовалось.") % Loc.t(String(GEN[key]))])
	U.set_lbl(_head, head, UiKit.TITLE)
	var sig: String = id + str(stage) + "|"
	for it: Array in items:
		sig += String(it[0]) + ","
	if sig != _sig or force:
		if sig != _sig and not force and hub.hud != null and bool(hub.hud.call("_finger_down")):
			return
		_rebuild(items)
		_sig = sig
	for it2: Array in items:
		var ref: Dictionary = _rows.get(String(it2[0]), {})
		if not ref.is_empty():
			_fill_row(ref, String(it2[1]), it2[2])


static func _sorted(d: Dictionary) -> Array:
	var ks: Array = d.keys()
	ks.sort_custom( func(a: Variant, b: Variant) -> bool: return int(d[a]) > int(d[b]))
	return ks


func _rebuild(items: Array) -> void :
	rebuilds += 1
	_drawer_home()
	for ch: Node in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	_rows.clear()
	for it: Array in items:
		var kind: String = String(it[1])
		var ref: Dictionary = {}
		match kind:
			"sec":
				ref = _sec_row()
			"note":
				var l: Label = UiKit.lbl("", 10, UiKit.MUTED, 1, 2)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_list.add_child(l)
				ref = {"lbl": l}
			"market":
				_drawer_take(String(it[2]))
				ref = {}
			_:
				ref = _row(kind, it[2])
		_rows[String(it[0])] = ref


func _sec_row() -> Dictionary:
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	_list.add_child(hb)
	var l: Label = UiKit.lbl("", 10, UiKit.TITLE, 2, 2)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	var v: Label = UiKit.lbl("", 11, UiKit.TEXT, 2, 2)
	hb.add_child(v)
	return {"lbl": l, "val": v}



func _row(kind: String, d: Variant) -> Dictionary:
	var pc: = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.sb("wb_card" if kind == "grp" else "wb_panel_dark", 5, 2))
	pc.custom_minimum_size = Vector2(0, ROW_H if kind != "src" else 40.0)
	_list.add_child(pc)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)
	var rail: = ColorRect.new()
	rail.custom_minimum_size = Vector2(3, 0)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.visible = kind == "fac" or kind == "dep"
	hb.add_child(rail)
	var gb: = CenterContainer.new()
	gb.custom_minimum_size = Vector2(24, 24)
	gb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(gb)
	var ic: TextureRect = U.icon("icon_info", 24.0)
	gb.add_child(ic)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", -3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(col)
	var t: Label = UiKit.lbl("", 11, UiKit.TEXT, 2, 2)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(t)
	var s: Label = UiKit.lbl("", 9, UiKit.MUTED, 2, 2)
	s.clip_text = true
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	s.visible = kind != "src"
	col.add_child(s)
	var lv: Label = UiKit.lbl("", 9, UiKit.GOLD, 2, 2)
	lv.custom_minimum_size = Vector2(30, 0)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lsb: = StyleBoxFlat.new()
	lsb.bg_color = Color("2a2416")
	lsb.border_color = Color("6b5a2a")
	lsb.set_border_width_all(1)
	lsb.content_margin_left = 3
	lsb.content_margin_right = 3
	lv.add_theme_stylebox_override("normal", lsb)
	lv.visible = false
	hb.add_child(lv)
	var vh: = HBoxContainer.new()
	vh.add_theme_constant_override("separation", 2)
	vh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vh)
	var v: Label = UiKit.lbl("", 12, UiKit.GREEN, 2, 2)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.custom_minimum_size = Vector2(34, 0)
	vh.add_child(v)
	var u: Label = UiKit.lbl("/мин", 9, UiKit.MUTED, 2, 2)
	u.size_flags_vertical = Control.SIZE_SHRINK_END
	vh.add_child(u)
	var arw: TextureRect = U.icon("wb_arrow_r", 9.0)
	arw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arw.modulate = Color(1, 1, 1, 0.8)
	hb.add_child(arw)
	var tap: = Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		tap.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	pc.add_child(tap)
	var ref: Dictionary = {"pc": pc, "rail": rail, "icon": ic, "t": t, "s": s, "lv": lv, "v": v, "u": u, "arw": arw, "tap": tap, "go": ""}
	tap.pressed.connect( func() -> void : _row_tap(ref))
	return ref


func _row_tap(ref: Dictionary) -> void :
	var go: String = String(ref.get("go", ""))
	if go == "":
		return
	UiKit.snd("ui_select")
	if go.begins_with("stage:"):
		select(int(go.get_slice(":", 1)), true)
		return
	hub.call("res_go", go)


func _state_col(st: String, why: String, n: float) -> Color:
	if st == "ruined":
		return UiKit.RED
	if st == "building" or st == "damaged" or (why != "" and n <= 0.0):
		return AMBER
	return UiKit.GREEN


func _fill_row(ref: Dictionary, kind: String, d: Variant) -> void :
	match kind:
		"sec":
			var a: Array = d
			var cap_t: String = Loc.t("%s ЗА МИНУТУ") % [String(a[0])]
			if String(a[0]) == "РЫНОК":
				cap_t = (Loc.t("ПРОДАЖА · %d ЗА ЕД.") if key == "fuel" else Loc.t("РЫНОК · ЦЕНА %d ЗА ЕД.")) % gw.econ.market_price(key)
			U.set_lbl(ref["lbl"], cap_t, a[2] as Color)
			var vv: int = int(a[1])
			U.set_lbl(ref["val"], ("" if String(a[0]) == "РЫНОК" else (U.signed(vv) if vv != 0 else "0") + "/мин"), a[2] as Color)
		"note":
			U.set_lbl(ref["lbl"], String(d), UiKit.MUTED)
		"src":
			var a2: Array = d
			var k: String = String(a2[0])
			var info: Array = ER.SRC.get(k, [String(Economy.STAT_NAMES.get(k, k)), "icon_info", -1])
			U.set_icon(ref["icon"], String(info[1]), 24.0)
			U.set_lbl(ref["t"], String(info[0]), UiKit.TEXT)
			var sgn: int = int(a2[2])
			var vv2: int = int(a2[1]) * sgn
			U.set_lbl(ref["v"], U.signed(vv2), UiKit.GREEN if vv2 > 0 else UiKit.RED.lightened(0.15))
			var go: String = ""
			for i: int in stages.size():
				if int(stages[i].get("kind", -1)) == int(info[2]) and int(info[2]) >= 0:
					go = "stage:%d" % i
			if go == "" and sgn < 0:
				go = "stage:%d" % (stages.size() - 1)
			ref["go"] = go
			U.set_vis(ref["arw"], go != "")
		"grp":
			var g: Dictionary = d
			U.set_icon(ref["icon"], String(g["icon"]), 24.0)
			U.set_lbl(ref["t"], String(g["name"]), UiKit.TITLE)
			var note: String = String(g.get("note", ""))
			if note == "":
				var nr: int = (g["rows"] as Array).size()
				note = String(ER.NOTE.get(String(g["key"]), ""))
				if nr > 0:
					note = (Loc.t("построек %d") % nr) + ((" · " + note) if note != "" else "")
				elif note == "":
					note = "за последнюю минуту"
			U.set_lbl(ref["s"], note, UiKit.MUTED)
			var gn: float = float(g["n"])
			U.set_lbl(ref["v"], ER.fmt( - gn) if gn > 0.0 else "0", UiKit.RED.lightened(0.15) if gn > 0.0 else UiKit.MUTED)
			U.set_vis(ref["arw"], false)
			ref["go"] = ""
		"fac":
			var r: Dictionary = d
			U.set_icon(ref["icon"], String(r.get("icon", "icon_info")), 24.0)
			var title: String = String(r["title"])
			U.set_lbl(ref["t"], title, UiKit.TEXT)
			var st: String = String(r["state"])
			var why: String = String(r.get("why", ""))
			var n: float = float(r.get("n", -1.0))
			var parts: PackedStringArray = PackedStringArray()
			if String(r.get("near", "")) != "":
				parts.append(Loc.t("у %s") % [BattleWatch.genitive(String(r["near"]))])
			parts.append(String(r["state_text"]))
			if why != "" and why != String(r["state_text"]):
				parts.append(why)
			if String(r.get("extra", "")) != "":
				parts.append(String(r["extra"]))
			var sc: Color = _state_col(st, why, n if n >= 0.0 else 1.0)
			U.set_lbl(ref["s"], " · ".join(parts), sc.lightened(0.25) if sc != UiKit.GREEN else UiKit.MUTED)
			(ref["rail"] as ColorRect).color = sc
			var lvl: int = int(r.get("level", 0))
			U.set_vis(ref["lv"], lvl > 0)
			if lvl > 0:
				U.set_lbl(ref["lv"], Loc.t("УР %d") % lvl, UiKit.GOLD)
			var is_use: bool = String(stages[stage]["id"]) == "out"
			if n < 0.0:
				U.set_lbl(ref["v"], "", UiKit.MUTED)
				U.set_vis(ref["u"], false)
			else:
				U.set_vis(ref["u"], true)
				var shown_n: float = - n if is_use else n
				U.set_lbl(ref["v"], ER.fmt(shown_n) if n > 0.0 else "0", (UiKit.RED.lightened(0.15) if is_use else UiKit.GREEN) if n > 0.0 else AMBER)
			ref["go"] = "fac:%d" % int(r["id"])
		"dep":
			var dd: Dictionary = d
			U.set_icon(ref["icon"], String(ICON[key]), 24.0)
			var dst: String = String(dd["state"])
			U.set_lbl(ref["t"], (Loc.t("Малая залежь ") if bool(dd["small"]) else Loc.t("Залежь ")) + String(GEN[key]), UiKit.TEXT)
			var sub: String = "свободна — можно строить"
			var sc2: Color = UiKit.GREEN
			if dst == "busy":
				var mf: Facility = dd["mine"]
				sub = Loc.t("занята: %s №%d") % [Military.title_of(mf.kind), ER.number_of(gw, player, mf)]
				sc2 = UiKit.MUTED
			elif dst == "empty":
				sub = "исчерпана"
				sc2 = UiKit.DIM
			U.set_lbl(ref["s"], sub, sc2 if sc2 != UiKit.MUTED else UiKit.MUTED)
			(ref["rail"] as ColorRect).color = UiKit.GREEN if dst == "free" else (UiKit.DIM if dst == "empty" else Color("6b5a2a"))
			U.set_vis(ref["lv"], false)
			var inf: bool = GameConfig.infinite_res()
			U.set_lbl(ref["v"], "∞" if inf else "%d/%d" % [int(dd["left"]), int(dd["max"])], UiKit.MUTED if dst == "empty" else UiKit.TEXT)
			U.set_vis(ref["u"], false)
			var cell: Vector2i = dd["cell"]
			ref["go"] = "dep:%d,%d" % [cell.x, cell.y]




func _drawer_take(res: String) -> void :
	var dr: Control = hub.call("ab_take", res)
	if dr == null:
		return
	if dr.get_parent() != null:
		dr.get_parent().remove_child(dr)
	_list.add_child(dr)
	dr.visible = true
	_drawer = dr


func _drawer_home() -> void :
	if _drawer != null and is_instance_valid(_drawer):
		if _drawer.get_parent() == _list:
			_list.remove_child(_drawer)
		hub.call("ab_give_back", _drawer)
	_drawer = null


func release() -> void :
	_drawer_home()




class Disc extends Control:
	var r: int = 22
	var selected: bool = false:
		set(v):
			if v != selected:
				selected = v
				dirty = true
	var warn: int = 0:
		set(v):
			if v != warn:
				warn = v
				dirty = true
	var fill: float = -1.0:
		set(v):
			if absf(v - fill) > 0.01:
				fill = v
				dirty = true
	var is_res: bool = false
	var deposit: bool = false
	var res_col: Color = Color.WHITE
	var icon: TextureRect
	var dirty: bool = true

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(place_icon)

	func place_icon() -> void :
		if icon != null and is_instance_valid(icon):
			icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
			icon.size = icon.custom_minimum_size
			icon.position = ((size - icon.size) * 0.5).round()

	func _span(cy: float, rad: int, col: Color, from_y: float = -1000000000.0) -> void :
		var cx: float = size.x * 0.5
		for y: int in range( - rad, rad):
			var yy: float = float(y) + 0.5
			if cy + float(y) < from_y:
				continue
			var w: int = int(floor(sqrt(maxf(0.0, float(rad * rad) - yy * yy)) + 0.5))
			if w > 0:
				draw_rect(Rect2(roundf(cx) - float(w), roundf(cy) + float(y), float(w * 2), 1.0), col)

	func _draw() -> void :
		dirty = false
		var cy: float = size.y * 0.5
		var ring: Color = UiKit.TITLE if selected else (Color("8a7a52") if is_res else Color("5a5a48"))
		_span(cy, r, UiKit.OUTLINE)
		_span(cy, r - 1, ring)
		if selected:
			_span(cy, r - 2, ring.lightened(0.25))
		var inner: int = r - (3 if selected else 2)
		var bg: Color = Color("3a2c1c") if deposit else (Color("26291f") if not is_res else Color("1c1d18"))
		_span(cy, inner, bg)
		if is_res and fill >= 0.0:
			var top: float = cy + float(inner) - 2.0 * float(inner) * clampf(fill, 0.0, 1.0)
			_span(cy, inner, Color(res_col, 0.38), top)
			if fill > 0.0:
				var cx: float = size.x * 0.5
				var yy: float = top - cy + 0.5
				var w: int = int(floor(sqrt(maxf(0.0, float(inner * inner) - yy * yy)) + 0.5))
				if w > 1:
					draw_rect(Rect2(roundf(cx) - float(w), roundf(top), float(w * 2), 1.0), Color(res_col, 0.85))
		if warn > 0:
			var dc: Color = UiKit.RED if warn >= 3 else AMBER
			var p: = Vector2(roundf(size.x * 0.5 + float(r) * 0.62), roundf(cy - float(r) * 0.78))
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), UiKit.OUTLINE)
			draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), dc)
			draw_rect(Rect2(p - Vector2(1, 3), Vector2(2, 4)), UiKit.OUTLINE)
			draw_rect(Rect2(p + Vector2(-1, 2), Vector2(2, 1)), UiKit.OUTLINE)



class ChainRow extends HBoxContainer:
	var cells: Array = []

	func _init() -> void :
		add_theme_constant_override("separation", 0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		sort_children.connect(queue_redraw)

	func _draw() -> void :
		if cells.size() < 2:
			return
		for i: int in cells.size() - 1:
			var a: Control = (cells[i] as Dictionary)["disc"]
			var b: Control = (cells[i + 1] as Dictionary)["disc"]
			if a == null or b == null or not a.is_inside_tree() or not b.is_inside_tree():
				continue
			var ra: Rect2 = a.get_global_rect()
			var rb: Rect2 = b.get_global_rect()
			var gx: Vector2 = get_global_rect().position
			var y: float = roundf(ra.get_center().y - gx.y)
			var x0: float = roundf(ra.end.x - gx.x) + 3.0
			var x1: float = roundf(rb.position.x - gx.x) - 4.0
			if x1 - x0 < 6.0:
				continue
			draw_rect(Rect2(x0, y - 2.0, x1 - x0, 4.0), UiKit.OUTLINE)
			draw_rect(Rect2(x0, y - 1.0, x1 - x0 - 3.0, 2.0), Color("8a7a52"))
			for k: int in 4:
				draw_rect(Rect2(x1 - 4.0 + float(k), y - 4.0 + float(k), 1.0, float(8 - 2 * k)), UiKit.TITLE)
