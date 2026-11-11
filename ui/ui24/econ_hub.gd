extends PanelContainer










signal action(name: String)

const U = preload("res://ui/ui24/econ_kit.gd")
const Bar = preload("res://ui/ui24/bar_track.gd")
const HT = preload("res://ui/ui24/hold_tip.gd")
const ResSheet = preload("res://ui/ui24/res_sheet.gd")
const ArmyBudget = preload("res://ui/ui24/army_budget.gd")
const BulkInfrastructure = preload("res://game/bulk_infrastructure.gd")
const AMBER: = Color("ffb000")
const STATUS_COL: Dictionary = {"bad": UiKit.RED, "warn": AMBER, "ok": UiKit.GREEN, "none": Color("8f8a76")}
const TABS: Array = [["ЦЕПОЧКИ", "icon_factory"], ["СКЛАД", "icon_inventory"], ["ДОХОДЫ", "icon_stats"]]

const CHAIN_VIEW: Dictionary = {
	"food": ["Еда", ["icon_farm", "res_food", "icon_barracks"], "food"], 
	"power": ["Энергия", ["icon_power", "res_power", "icon_civ_factory"], "power"], 
	"goods": ["Товары", ["icon_civ_factory", "res_goods", "icon_port"], "goods"], 
	"metal": ["Металл", ["icon_mine", "icon_r_metal", "icon_dronefactory"], "metal"], 
	"titanium": ["Титан", ["icon_mine", "icon_r_titanium", "icon_missile_factory"], "titanium"], 
	"precious": ["Драгмет.", ["icon_mine", "icon_r_precious", "icon_ad_patriot"], "precious"], 
	"uranium": ["Уран", ["icon_umine", "icon_r_uranium", "icon_npp"], "uranium"], 
	"wood": ["Дерево", ["icon_sawmill", "icon_r_wood", "icon_trench"], "wood"], 
	"oil": ["Топливо", ["icon_oil_rig", "icon_r_oil", "icon_refinery"], "fuel"], 
	"trade": ["Торговля", ["icon_trade", "res_goods", "icon_port"], "money"], 
	"drones": ["Дроны", ["icon_r_metal", "icon_dronefactory", "res_drone"], "drones"], 
	"missiles": ["Ракеты", ["icon_r_titanium", "icon_missile_factory", "res_missile"], "missiles"], 
}

const STORE_ROWS: Array = [
	["titanium", "Титан", "icon_r_titanium"], ["food", "Еда", "res_food"], ["metal", "Металл", "icon_r_metal"], 
	["precious", "Драгмет.", "icon_r_precious"], ["oil", "Нефть", "icon_r_oil"], ["wood", "Дерево", "icon_r_wood"], 
	["fuel", "Топливо", "res_fuel"], ["goods", "Товары", "res_goods"], ["uranium", "Уран", "icon_r_uranium"], 
]
const STORE_W: Array = [24.0, 64.0, 0.0, 40.0, 38.0]

const ONE_OFF_EXTRA: Array = ["tutorial", "intel"]
const POOL_INC: int = 8
const POOL_SPEND: int = 8
const POOL_ONE: int = 4
const POOL_PROD: int = 8

var hud: Node
var player: Country
var page: int = -1
var compact: bool = false
var closing: bool = false
var rebuilds: int = 0
var fills: int = 0
var last_rebuild_why: String = ""
var _t: float = 0.0
var _seg: Array = []
var _seg_badges: Array = []
var _pages: Array = []
var _stage: Control
var _tweens: Array = []
var _anim_until: int = 0

var _net_lbl: Label
var _bn_panel: PanelContainer
var _bn_icon: TextureRect
var _bn_title: Label
var _bn_sub: Label
var _bn_btn: Button
var _bn_fix: String = ""
var _sb_bad: StyleBox
var _sb_ok: StyleBox

var _chain_vb: VBoxContainer
var _chain_rows: Dictionary = {}
var _chain_sig: String = ""
var _chain_pending: String = ""
var _chain_pending_n: int = 0
var _chain_rebuild_ms: int = -100000
var _plan_lbl: Label
var _plan_btn: Button

var _store_refs: Dictionary = {}
var _store_tip: Label

var _tot_in: Array = []
var _tot_out: Array = []
var _scale_lbl: Label
var _inc_rows: Array = []
var _spend_rows: Array = []
var _one_rows: Array = []
var _prod_rows: Array = []
var _inc_empty: Label
var _spend_empty: Label
var _prod_empty: Label
var _one_head: Label
var _dev_lbl: Label
var _tot_lbl: Label
var _slot_of: Dictionary = {}
var _data: Dictionary = {}




func setup(h: Node, sheet_h: float, bottom_pad: float) -> void :
	hud = h
	player = hud.gw.player
	UiKit.ensure()
	compact = sheet_h < 420.0
	custom_minimum_size = Vector2(0, sheet_h)
	var psb: StyleBox = UiKit.sb("wb_window", 8, 6)
	psb.content_margin_bottom = 6.0 + bottom_pad
	add_theme_stylebox_override("panel", psb)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("kind", "economy")
	_sb_bad = UiKit.sb("wb_btn_red_p", 5, 0)
	_sb_ok = UiKit.sb("wb_panel_dark", 5, 0)
	for s: StyleBox in [_sb_bad, _sb_ok]:
		s.content_margin_top = 3.0
		s.content_margin_bottom = 3.0
	_data = _collect()
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)
	_vb = vb
	if compact:
		var top: = HBoxContainer.new()
		top.add_theme_constant_override("separation", 4)
		vb.add_child(top)
		var seg: Control = _segments()
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(seg)
		top.add_child(_close())
		vb.add_child(_bottleneck(true))
	else:
		vb.add_child(_header())
		vb.add_child(_bottleneck(false))
		vb.add_child(_segments())
	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_stage)
	for i: int in 3:
		var sc: = ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.set_anchors_preset(Control.PRESET_FULL_RECT)
		sc.visible = false
		_stage.add_child(sc)
		var inner: = VBoxContainer.new()
		inner.add_theme_constant_override("separation", 3)
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(inner)
		_pages.append(sc)
	_chain_vb = _pages[0].get_child(0)
	_build_chains()
	_build_store(_pages[1].get_child(0))
	_build_money(_pages[2].get_child(0))
	_fill(_data)



func scroll_areas() -> Array:
	return _pages



func scroll_area() -> ScrollContainer:
	if res_view != null and is_instance_valid(res_view) and res_view.visible:
		return res_view.scroll
	return _pages[page] if page >= 0 and page < _pages.size() else null


func close() -> void :
	if closing:
		return
	closing = true
	for x: Variant in _tweens:
		var tw: Tween = x as Tween
		if tw != null and tw.is_valid():
			tw.kill()
	if hud != null and is_instance_valid(hud):
		hud.call("ui24_closed", self)
	close_res(false)
	visible = false
	if hud == null or not is_instance_valid(hud) or hud.gw == null or hud.gw.player != player:
		queue_free()



func reopen() -> bool:
	if hud == null or not is_instance_valid(hud) or hud.gw == null or hud.gw.player == null or hud.gw.player != player or player.eliminated:
		return false
	closing = false
	visible = true
	_t = 1.0
	_data = _collect()
	if _chains_signature(_data) != _chain_sig:
		_build_chains()
	_fill(_data)
	if _back_res != "" and Time.get_ticks_msec() < _back_until:
		open_res(_back_res, _back_stage, false)
	_back_res = ""
	return true


func _process(delta: float) -> void :
	if closing or hud == null or not is_instance_valid(hud):
		return
	var gw: GameWorld = hud.gw

	if gw == null or gw.player == null or gw.player != player or gw.player.eliminated or bool(hud.ops_panel.visible):
		close()
		return
	if hud.panel != null and is_instance_valid(hud.panel):
		close()
		return


	for e: Variant in hud.cmd_btns:
		var cb: Control = (e as Array)[0]
		if cb != null and cb.visible:
			cb.visible = false
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	_data = _collect()
	var sig: String = _chains_signature(_data)
	if sig != _chain_sig:
		if sig == _chain_pending:
			_chain_pending_n += 1
		else:
			_chain_pending = sig
			_chain_pending_n = 1
		var now: int = Time.get_ticks_msec()
		if _chain_pending_n >= 10 and now - _chain_rebuild_ms >= 20000 and not bool(hud.call("_finger_down")):
			last_rebuild_why = "%s -> %s" % [_chain_sig, sig]
			_chain_rebuild_ms = now
			var sc: ScrollContainer = _pages[0]
			var keep: int = sc.scroll_vertical
			_build_chains()
			sc.set_deferred("scroll_vertical", keep)
			rebuilds += 1
	else:
		_chain_pending = ""
		_chain_pending_n = 0
	_fill(_data)
	if res_view != null and is_instance_valid(res_view) and res_view.visible:
		res_view.refresh()




static func short_text(t: String) -> String:
	var s: String = t.strip_edges().trim_suffix(".")
	var i: int = s.find(" — ")
	if i > 0:
		s = s.substr(0, i)
	elif s.find(": ") > 0 and s.find(": ") <= 24:
		s = s.substr(0, s.find(": "))
	elif s.length() > 26 and s.find(", ") > 0:
		s = s.substr(0, s.find(", "))
	if s.length() > 0:
		s = s.substr(0, 1).to_lower() + s.substr(1)
	return s


func _collect() -> Dictionary:
	var gw: GameWorld = hud.gw
	var p: Country = gw.player
	var out: Dictionary = {"chains": [], "store": [], "income": [], "spend": [], "one_off": [], "prod": [], "net": 0}
	if p == null or gw.econ == null:
		return out
	var econ: Economy = gw.econ
	var fl: Dictionary = gw.guide.flows(p) if gw.get("guide") != null else {}

	var one_keys: Array = EconGuide.ONE_OFF_MONEY + ONE_OFF_EXTRA
	var mo: Dictionary = fl.get("money", {})
	var tin: int = 0
	var tout: int = 0
	for it: Dictionary in mo.get("income", []):
		var k: String = String(it.get("key", ""))
		var v: int = int(it.get("per_min", 0))
		var nm: String = String(Hud.STAT_NAMES.get(k, it.get("name", k)))
		if one_keys.has(k):
			out["one_off"].append([k, nm, v])
		else:
			out["income"].append([k, nm, v])
			tin += v
	for it2: Dictionary in mo.get("spend", []):
		var k2: String = String(it2.get("key", ""))
		var v2: int = int(it2.get("per_min", 0))
		var nm2: String = String(Hud.STAT_NAMES.get(k2, it2.get("name", k2)))
		if one_keys.has(k2):
			out["one_off"].append([k2, nm2, - v2])
		else:
			out["spend"].append([k2, nm2, v2])
			tout += v2
	out["tin"] = tin
	out["tout"] = tout
	out["net"] = tin - tout

	var pw: Dictionary = fl.get("power", {})
	for ch: Dictionary in fl.get("chains", []):
		var id: String = String(ch.get("id", ""))
		var view: Array = CHAIN_VIEW.get(id, [String(ch.get("name", id)), [String(ch.get("icon", "icon_info"))], ""])
		var st: String = String(ch.get("status", "none"))
		var fk: String = String(ch.get("fix_key", ""))
		var c: Dictionary = {"id": id, "name": String(view[0]), "flow": view[1], "status": st, "text": short_text(String(ch.get("text", ""))), 
			"full": String(ch.get("text", "")), "fix": fk if st != "ok" else "", "rate": 0, "rate_text": "", "rate_sub": "/мин"}
		var rr: String = String(view[2])
		if rr == "power":
			var free: int = int(pw.get("cap", 0)) - int(pw.get("use", 0))
			c["rate_text"] = U.signed(free)
			c["rate_sub"] = "своб."
		elif rr != "":
			c["rate"] = _chain_rate(ch, rr, p, econ)
		out["chains"].append(c)

	var dem: Dictionary = econ.demand(p)
	for row: Array in STORE_ROWS:
		var key: String = String(row[0])
		var n: int = int(p.get(key))
		var cap: int = econ.res_cap(p, key)
		var rate: int = econ.res_rate(p, key)
		var need: int = econ.need(p, key)
		var d: float = float(dem.get(key, 0.0))
		var st2: String = "ok"
		var note: String = ""
		if cap > 0 and n >= cap:
			st2 = "full"
			note = "полон"
		elif rate < 0 and n > 0:
			var secs: float = float(n) / float( - rate) * 60.0
			if secs < 60.0 or need > 0:
				st2 = "bad"
			elif secs < 180.0:
				st2 = "warn"
			if st2 != "ok":
				note = Loc.t("0 через %s") % [U.mmss(secs)]
		elif need > 0:
			st2 = "bad"
			note = (Loc.t("нужно %d/мин") % ceili(d)) if d >= 1.0 else (Loc.t("нужно %d") % need)
		out["store"].append({"key": key, "name": String(row[1]), "icon": String(row[2]), "n": n, "cap": cap, "rate": rate, 
			"price": econ.market_price(key), "status": st2, "note": note})

	var st3: Dictionary = econ.stats(p)
	var res_in: Dictionary = st3.get("res_in", {})
	for r: Variant in res_in:
		var sum: int = 0
		for k3: Variant in (res_in[r] as Dictionary):
			sum += int(res_in[r][k3])
		out["prod"].append([String(r), String(hud.call("_res_name", String(r))).capitalize(), sum])
	if gw.rail != null:
		out["dev"] = String(gw.rail.dev_text(p.id))
	out["totals"] = Loc.t("Всего заработано: %s · очки экономики %d · войны %d") % [U.num(p.earned), p.score_eco, p.score_mil]
	return out


func _chain_rate(ch: Dictionary, res: String, p: Country, econ: Economy) -> int:
	var found: bool = false
	var n: int = 0
	for o: Dictionary in ch.get("outputs", []):
		if String(o.get("res", "")) == res:
			n += int(o.get("per_min", 0))
			found = true
	for i: Dictionary in ch.get("inputs", []):
		if String(i.get("res", "")) == res:
			n -= int(i.get("per_min", 0))
			found = true
	if found:
		if res in Economy.TRADE_RES or res == "fuel":
			return econ.res_rate(p, res)
		return n
	if res in Economy.TRADE_RES or res == "fuel":
		return econ.res_rate(p, res)
	return 0


static func _group(c: Dictionary) -> String:
	var st: String = String(c["status"])
	return "alert" if st == "bad" or st == "warn" else ("idle" if st == "none" else "ok")


func _chains_signature(d: Dictionary) -> String:
	var s: String = ""
	for c: Dictionary in d.get("chains", []):
		s += "%s:%s;" % [String(c["id"]), _group(c)]
	return s




func _bn_short(t: String) -> String:
	var wd: float = _bn_sub.size.x
	if wd < 40.0:
		return t
	var f: Font = _bn_sub.get_theme_font("font")
	var fs: int = _bn_sub.get_theme_font_size("font_size")
	var c: String = t
	for sep: String in ["", " — ", ". ", ": "]:
		if sep != "" and c.find(sep) > 0:
			c = c.substr(0, c.find(sep))
		if f.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= wd:
			return c
	return c


func _bottleneck_of(d: Dictionary) -> Dictionary:
	for want: String in ["bad", "warn"]:
		for c: Dictionary in d.get("chains", []):
			if String(c["status"]) == want:
				return c
	return {}




func _close() -> Button:
	var cb: Button = UiKit.close_btn(44.0)
	cb.pressed.connect( func() -> void :
		UiKit.snd("ui_close")
		action.emit("close"))
	return cb



func _money_pill() -> Control:
	var pill: = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UiKit.sb("wb_pill", 7, 3))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ph: = HBoxContainer.new()
	ph.add_theme_constant_override("separation", 3)
	pill.add_child(ph)
	var coin: TextureRect = U.icon("res_money", 18.0)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(coin)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	ph.add_child(col)
	_net_lbl = UiKit.lbl("+0", 14, UiKit.GREEN, 2, 3)
	_net_lbl.custom_minimum_size = Vector2(54, 0)
	col.add_child(_net_lbl)
	col.add_child(UiKit.lbl("в минуту", 9, UiKit.MUTED, 2, 2))
	return pill


func _header() -> Control:
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.custom_minimum_size = Vector2(0, 44)
	var t: Label = UiKit.lbl("ЭКОНОМИКА", 18, UiKit.TITLE, 3, 2)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(t)
	hb.add_child(_money_pill())
	hb.add_child(_close())
	return hb




func _bottleneck(with_money: bool) -> Control:
	var outer: = HBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	if with_money:
		outer.add_child(_money_pill())
	_bn_panel = PanelContainer.new()
	_bn_panel.add_theme_stylebox_override("panel", _sb_bad)
	_bn_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bn_panel.custom_minimum_size = Vector2(0, 46)
	outer.add_child(_bn_panel)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	_bn_panel.add_child(hb)
	_bn_icon = U.icon("icon_scarce", 24.0)
	_bn_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_bn_icon)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(col)
	_bn_title = UiKit.lbl("", 11, UiKit.TEXT, 2, 3)
	_bn_title.add_theme_constant_override("line_spacing", -3)
	_bn_title.clip_text = true
	_bn_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_bn_title)
	_bn_sub = UiKit.lbl("", 10, Color("ffe0d4"), 2, 2)
	_bn_sub.clip_text = true
	_bn_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_bn_sub)
	_bn_btn = UiKit.big("ИСПРАВИТЬ", "green", "", 40.0, 10)
	HT.key(_bn_btn, "fix")
	_bn_btn.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_green", 8, 4, -1))
	_bn_btn.add_theme_stylebox_override("pressed", UiKit.sb("wb_btn_green_p", 8, 4, 1))
	_bn_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit._touch_pad(_bn_btn)
	_bn_btn.pressed.connect( func() -> void :
		if _bn_fix != "":
			action.emit("plan_go:" + _bn_fix))
	hb.add_child(_bn_btn)
	return outer


func _segments() -> Control:
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	for i: int in TABS.size():
		var b: = Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = Loc.t(String(TABS[i][0]))
		b.icon = U.tex(String(TABS[i][1])) if not compact else null
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 18)
		b.add_theme_font_override("font", UiKit.f_black)
		b.add_theme_font_size_override("font_size", 10)
		b.add_theme_constant_override("outline_size", 3)
		b.add_theme_color_override("font_outline_color", UiKit.OUTLINE)
		b.add_theme_color_override("font_pressed_color", UiKit.TEXT)
		b.add_theme_color_override("font_hover_pressed_color", UiKit.TEXT)
		b.add_theme_color_override("font_color", UiKit.MUTED)
		b.add_theme_color_override("font_hover_color", UiKit.MUTED)
		b.add_theme_constant_override("h_separation", 3)
		var right_pad: float = 18.0 if i < 2 else 5.0
		for s2: Array in [["normal", "wb_btn_stone_p", 1], ["hover", "wb_btn_stone_p", 1], ["pressed", "wb_btn_gold", -1], ["hover_pressed", "wb_btn_gold", -1]]:
			var sbx: StyleBox = UiKit.sb(String(s2[1]), 5, 4, float(s2[2]))
			sbx.content_margin_right = right_pad
			b.add_theme_stylebox_override(String(s2[0]), sbx)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var idx: int = i
		b.pressed.connect( func() -> void :
			UiKit.snd("ui_tab")
			if idx == page:
				(_seg[idx] as Button).set_pressed_no_signal(true)
			show_page(idx, true))
		hb.add_child(b)
		_seg.append(b)
		var bd: Label = null
		if i < 2:
			bd = U.badge_label(0)
			bd.visible = false
			b.add_child(bd)
			var host: Button = b
			var lab: Label = bd
			host.resized.connect( func() -> void : lab.position = Vector2(host.size.x - 18.0, roundf((host.size.y - 14.0) * 0.5) - 1.0))
		_seg_badges.append(bd)
	return hb


func _section(parent: Control, text: String) -> Label:
	var l: Label = UiKit.lbl(text, 10, UiKit.TITLE, 2, 2)
	parent.add_child(l)
	return l


func _row_panel(parent: Control, style: String = "wb_panel_dark", pad_y: float = 2.0) -> HBoxContainer:
	var pc: = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.sb(style, 5, pad_y))
	parent.add_child(pc)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	pc.add_child(hb)
	return hb



func _glyph(icon_name: String) -> Control:
	var box: = CenterContainer.new()
	box.custom_minimum_size = Vector2(24, 24)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_name.begins_with("res_"):
		var disc: = Panel.new()
		var st: = StyleBoxFlat.new()
		st.bg_color = Color("1c1d18")
		st.border_color = Color("5a5a48")
		st.set_border_width_all(1)
		st.set_corner_radius_all(11)
		disc.add_theme_stylebox_override("panel", st)
		disc.custom_minimum_size = Vector2(24, 24)
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(disc)
		box.add_child(U.icon(icon_name, 18.0))
	else:
		box.add_child(U.icon(icon_name, 24.0))
	return box





func _build_chains() -> void :
	var vb: VBoxContainer = _chain_vb
	for ch: Node in vb.get_children():
		vb.remove_child(ch)
		ch.queue_free()
	_chain_rows.clear()
	var bulk: Button = UiKit.big("УЛУЧШИТЬ ЗДАНИЯ", "gold", "", 36.0, 10)
	bulk.name = "BulkInfrastructureButton"
	bulk.pressed.connect(_bulk_infrastructure_preview)
	vb.add_child(bulk)
	var chains: Array = (_data.get("chains", []) as Array).duplicate()
	var rank: Dictionary = {"alert": 0, "idle": 1, "ok": 2}
	var order: Dictionary = {}
	for i: int in chains.size():
		order[String(chains[i]["id"])] = i
	chains.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		var ra: int = int(rank[_group(a)])
		var rb: int = int(rank[_group(b)])
		if ra != rb:
			return ra < rb
		if ra == 0 and String(a["status"]) != String(b["status"]):
			return String(a["status"]) == "bad"
		return int(order[String(a["id"])]) < int(order[String(b["id"])]))
	var counts: Dictionary = {"alert": 0, "idle": 0, "ok": 0}
	for c: Dictionary in chains:
		counts[_group(c)] = int(counts[_group(c)]) + 1
	var heads: Dictionary = {"alert": Loc.t("НУЖНО ВНИМАНИЕ · %d"), "idle": Loc.t("МОЖНО РАЗВИТЬ · %d"), "ok": Loc.t("РАБОТАЮТ · %d")}
	var last_group: String = ""
	for c: Dictionary in chains:
		var g: String = _group(c)
		if g != last_group:
			last_group = g
			_section(vb, String(heads[g]) % int(counts[g]))
		_chain_row(vb, c)
	if chains.is_empty():
		var e: Label = UiKit.lbl("Цепочек пока нет: постройте столицу.", 10, UiKit.MUTED, 1, 2)
		vb.add_child(e)

	var pr: HBoxContainer = _row_panel(vb, "wb_panel_dark", 2.0)
	_plan_lbl = UiKit.lbl("", 10, UiKit.MUTED, 2, 2)
	_plan_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plan_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(_plan_lbl)
	_plan_btn = UiKit.big("СКРЫТЬ", "blue", "", 34.0, 9)
	_plan_btn.custom_minimum_size = Vector2(96, 34)
	UiKit._touch_pad(_plan_btn)
	_plan_btn.pressed.connect( func() -> void : action.emit("plan_toggle"))
	pr.add_child(_plan_btn)
	_chain_sig = _chains_signature(_data)


func _bulk_infrastructure_preview() -> void:
	if hud == null or hud.gw == null or hud.gw.player == null or hud.gw.econ == null:
		return
	if hud.main_node != null and hud.main_node.net != null and hud.main_node.net.in_match:
		hud.show_toast("Массовое улучшение доступно только в одиночной игре")
		return
	var gw: GameWorld = hud.gw
	var owner: Country = gw.player
	var preview: Dictionary = BulkInfrastructure.plan(gw.econ, gw.mil.facilities, owner)
	var items: Array = preview["items"]
	if items.is_empty():
		hud.show_toast("Нет доступных улучшений или не хватает ресурсов")
		return
	var costs: PackedStringArray = PackedStringArray()
	for resource: String in preview["cost"]:
		costs.append("%s: %d" % [String(Country.RES_RU.get(resource, resource)), int(preview["cost"][resource])])
	var confirm: ConfirmationDialog = ConfirmationDialog.new()
	confirm.title = "Улучшение инфраструктуры"
	confirm.dialog_text = "Улучшить на один уровень: %d из %d зданий.\nСтоимость: %s\n\nРесурсы и доступность проверяются ещё раз перед улучшением." % [items.size(), int(preview["eligible"]), ", ".join(costs)]
	confirm.ok_button_text = "УЛУЧШИТЬ"
	confirm.cancel_button_text = "ОТМЕНА"
	add_child(confirm)
	confirm.confirmed.connect(func() -> void:
		if hud == null or hud.gw != gw or gw.player != owner or (hud.main_node != null and hud.main_node.net != null and hud.main_node.net.in_match):
			return
		var count: int = BulkInfrastructure.apply(gw.econ, gw.mil.facilities, owner, preview)
		hud.show_toast("Улучшено зданий: %d" % count)
	)
	confirm.close_requested.connect(confirm.queue_free)
	confirm.canceled.connect(confirm.queue_free)
	confirm.confirmed.connect(confirm.queue_free)
	confirm.popup_centered()


func _chain_row(vb: VBoxContainer, c: Dictionary) -> void :
	var st: String = String(c["status"])
	var has_fix: bool = String(c["fix"]) != ""
	var alert: bool = _group(c) != "ok"
	var hb: HBoxContainer = _row_panel(vb, "wb_panel_dark", 2.0 if alert else 3.0)

	hb.custom_minimum_size = Vector2(0, 40 if alert else 36)
	var rail: = ColorRect.new()
	rail.color = STATUS_COL.get(st, UiKit.MUTED)
	rail.custom_minimum_size = Vector2(3, 0)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(rail)
	var flow: = HBoxContainer.new()
	flow.add_theme_constant_override("separation", 0)
	flow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(flow)
	var fl: Array = c["flow"]
	for k: int in fl.size():
		if k > 0:
			var ar: TextureRect = U.icon("wb_arrow_r", 9.0)
			ar.custom_minimum_size = Vector2(9, 14)
			ar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			flow.add_child(ar)
		flow.add_child(_glyph(String(fl[k])))

	var mid: = Button.new()
	mid.flat = true
	mid.focus_mode = Control.FOCUS_NONE
	for s: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		mid.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.custom_minimum_size = Vector2(0, 26)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(mid)


	var line: BoxContainer = VBoxContainer.new()
	line.add_theme_constant_override("separation", -2)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(line)
	var nl: Label = UiKit.lbl(String(c["name"]), 11, UiKit.TEXT, 2, 2)
	nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(nl)
	var sub: Label = UiKit.lbl("", 9 if alert else 10, UiKit.MUTED, 2, 2)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if alert:
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.max_lines_visible = 2
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
		sub.add_theme_constant_override("line_spacing", -3)
	else:
		sub.clip_text = true
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(sub)
	var id: String = String(c["id"])
	mid.pressed.connect( func() -> void :
		if CHAIN_RES.has(id):
			UiKit.snd("ui_tab")
			open_res(String(CHAIN_RES[id]))
			return
		var r: Dictionary = _chain_rows.get(id, {})
		if not r.is_empty():
			hud.call("show_tip", String(c["name"]), String(r.get("full", ""))))
	var fb: Button = UiKit.big("ИСПРАВИТЬ", "green", "", 40.0, 9)
	HT.key(fb, "fix")
	fb.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_green", 7, 4, -1))
	fb.add_theme_stylebox_override("pressed", UiKit.sb("wb_btn_green_p", 7, 4, 1))
	UiKit._touch_pad(fb)
	fb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fb.pressed.connect( func() -> void :
		var r2: Dictionary = _chain_rows.get(id, {})
		if String(r2.get("fix", "")) != "":
			action.emit("plan_go:" + String(r2["fix"])))
	fb.visible = has_fix
	hb.add_child(fb)
	var rv: = HBoxContainer.new()
	rv.add_theme_constant_override("separation", 2)
	rv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rv.visible = not has_fix
	hb.add_child(rv)
	var rl: Label = UiKit.lbl("", 12, UiKit.MUTED, 2, 2)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rl.custom_minimum_size = Vector2(34, 0)
	rv.add_child(rl)
	var ru: Label = UiKit.lbl("/мин", 9, UiKit.MUTED, 2, 2)
	ru.custom_minimum_size = Vector2(30, 0)
	ru.size_flags_vertical = Control.SIZE_SHRINK_END
	rv.add_child(ru)
	if CHAIN_RES.has(String(c["id"])):
		var go: TextureRect = U.icon("wb_arrow_r", 9.0)
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		go.modulate = Color(1, 1, 1, 0.8)
		hb.add_child(go)
	_chain_rows[id] = {"alert": alert, "rail": rail, "sub": sub, "fixb": fb, "rv": rv, "rate": rl, "unit": ru, "fix": String(c["fix"]), "full": String(c["full"])}


func _fill_chains(d: Dictionary) -> void :
	for c: Dictionary in d.get("chains", []):
		var r: Dictionary = _chain_rows.get(String(c["id"]), {})
		if r.is_empty():
			continue
		var st: String = String(c["status"])
		var rail: ColorRect = r["rail"]
		var col: Color = STATUS_COL.get(st, UiKit.MUTED)
		if rail.color != col:
			rail.color = col
		U.set_lbl(r["sub"], String(c["text"]), UiKit.RED.lightened(0.2) if st == "bad" else (AMBER if st == "warn" else UiKit.MUTED))
		if not bool(r["alert"]):


			var sl: Label = r["sub"]
			var wrap: bool = st == "bad" or st == "warn"
			if sl.clip_text == wrap:
				sl.clip_text = not wrap
				sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
				sl.max_lines_visible = 2 if wrap else -1
				sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS if wrap else TextServer.OVERRUN_TRIM_ELLIPSIS
		r["full"] = String(c["full"])



		r["fix"] = String(c["fix"]) if bool(r["alert"]) else ""
		U.set_vis(r["fixb"], String(r["fix"]) != "")
		U.set_vis(r["rv"], String(r["fix"]) == "")
		if String(c["rate_text"]) != "":
			U.set_lbl(r["rate"], String(c["rate_text"]), UiKit.BLUE)
			U.set_lbl(r["unit"], String(c["rate_sub"]), UiKit.MUTED)
		else:
			var rate: int = int(c["rate"])
			U.set_lbl(r["rate"], U.signed(rate), UiKit.GREEN if rate > 0 else (UiKit.RED if rate < 0 else UiKit.MUTED))
	if _plan_lbl != null and is_instance_valid(_plan_lbl):
		var closed: bool = bool(Hud.plan_closed)
		U.set_lbl(_plan_lbl, Loc.t("План развития: %s") % (Loc.t("скрыт") if closed else Loc.t("виден")), UiKit.MUTED)
		if _plan_btn.text != (Loc.t("ПОКАЗАТЬ") if closed else Loc.t("СКРЫТЬ")):
			_plan_btn.text = Loc.t("ПОКАЗАТЬ") if closed else Loc.t("СКРЫТЬ")




func _build_store(vb: VBoxContainer) -> void :
	var head: = HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	vb.add_child(head)
	var pad: = Control.new()
	pad.custom_minimum_size = Vector2(5, 0)
	head.add_child(pad)
	for c: Array in [["", STORE_W[0], 0], ["РЕСУРС", STORE_W[1], 0], ["ЗАПАС", 0.0, 0], ["В МИН", STORE_W[3], 2], ["ЦЕНА", STORE_W[4], 2]]:
		var l: Label = UiKit.lbl(String(c[0]), 9, UiKit.MUTED, 2, 2)
		l.horizontal_alignment = int(c[2]) as HorizontalAlignment
		if float(c[1]) > 0.0:
			l.custom_minimum_size = Vector2(float(c[1]), 0)
		else:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(l)
	var rp: = Control.new()
	rp.custom_minimum_size = Vector2(5, 0)
	head.add_child(rp)
	for it: Array in STORE_ROWS:
		var key: String = String(it[0])
		var hb: HBoxContainer = _row_panel(vb, "wb_panel_dark", 3.0)
		hb.add_child(_glyph(String(it[2])))
		var nl: Label = UiKit.lbl(String(it[1]), 11, UiKit.TEXT, 2, 2)
		nl.custom_minimum_size = Vector2(STORE_W[1], 0)
		nl.clip_text = true
		UiKit.fit_lbl(nl, [11, 10, 9], false)
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(nl)
		var bc: = VBoxContainer.new()
		bc.add_theme_constant_override("separation", 1)
		bc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(bc)
		var top: = HBoxContainer.new()
		top.add_theme_constant_override("separation", 4)
		bc.add_child(top)
		var al: Label = UiKit.lbl("0/0", 10, UiKit.TEXT, 2, 2)
		al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(al)
		var note: Label = UiKit.lbl("", 9, UiKit.MUTED, 2, 2)
		top.add_child(note)
		var bar = Bar.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.min_px = 0.0
		bc.add_child(bar)
		var rl: Label = UiKit.lbl("0", 11, UiKit.MUTED, 2, 2)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rl.custom_minimum_size = Vector2(STORE_W[3], 0)
		rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(rl)
		var ph: = HBoxContainer.new()
		ph.add_theme_constant_override("separation", 2)
		ph.alignment = BoxContainer.ALIGNMENT_END
		ph.custom_minimum_size = Vector2(STORE_W[4], 0)
		ph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(ph)
		var pl: Label = UiKit.lbl("0", 11, UiKit.GOLD, 2, 2)
		ph.add_child(pl)
		var cn: TextureRect = U.icon("res_money", 9.0)
		cn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ph.add_child(cn)
		_store_refs[key] = {"name": nl, "amount": al, "note": note, "bar": bar, "rate": rl, "price": pl}
		_ab_row(vb, key, hb)
	var foot: = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	vb.add_child(foot)
	_store_tip = UiKit.lbl("Цена — за 1 ед. на рынке. Красный — здания стоят.", 9, UiKit.MUTED, 2, 2)
	_store_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_store_tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_store_tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_store_tip)
	var tb: Button = UiKit.big("ТОРГОВЛЯ", "blue", "", 44.0, 10)
	tb.pressed.connect( func() -> void : action.emit("trade"))
	foot.add_child(tb)
	_ab_foot(vb)


func _fill_store(d: Dictionary) -> int:
	var bad: int = 0
	var anim: bool = Time.get_ticks_msec() < _anim_until and page == 1
	for it: Dictionary in d.get("store", []):
		var r: Dictionary = _store_refs.get(String(it["key"]), {})
		if r.is_empty():
			continue
		var st: String = String(it["status"])
		if st == "bad":
			bad += 1
		var n: int = int(it["n"])
		var cap: int = maxi(1, int(it["cap"]))
		U.set_lbl(r["name"], String(it["name"]), UiKit.RED.lightened(0.1) if st == "bad" else UiKit.TEXT)
		U.set_lbl(r["amount"], "%d/%d" % [n, cap], UiKit.TEXT)
		var nc: Color = {"bad": UiKit.RED.lightened(0.2), "warn": AMBER, "full": UiKit.GOLD}.get(st, UiKit.MUTED)
		U.set_lbl(r["note"], String(it["note"]), nc)
		var bar = r["bar"]
		bar.fill_name = {"bad": "wb_bar_red", "warn": "wb_bar_amber", "full": "wb_bar_amber"}.get(st, "wb_bar_green")
		bar.set_meta("target", float(n) / float(cap))
		if not anim:
			bar.frac = float(n) / float(cap)
		var rate: int = int(it["rate"])
		U.set_lbl(r["rate"], U.signed(rate), UiKit.GREEN if rate > 0 else (UiKit.RED if rate < 0 else UiKit.MUTED))
		U.set_lbl(r["price"], str(int(it["price"])), UiKit.GOLD)
	_ab_fill()
	return bad




func _build_money(vb: VBoxContainer) -> void :
	var card: = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 5))
	vb.add_child(card)
	var cv: = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 3)
	card.add_child(cv)
	_tot_in = _money_row(cv, "ДОХОД", true, 12, 2)
	_tot_out = _money_row(cv, "РАСХОД", false, 12, 2)
	_scale_lbl = UiKit.lbl("", 9, UiKit.MUTED, 1, 2)
	cv.add_child(_scale_lbl)
	vb.add_child(ArmyBudget.make(hud.gw, false))
	_section(vb, "ОТКУДА ДЕНЬГИ")
	_inc_empty = UiKit.lbl("Статистика копится: загляните через минуту.", 9, UiKit.MUTED, 1, 2)
	_inc_empty.custom_minimum_size = Vector2(0, 18)
	vb.add_child(_inc_empty)
	for i: int in POOL_INC:
		_inc_rows.append(_pool_row(vb, true, "wb_bar_green"))
	_section(vb, "КУДА УХОДЯТ")
	_spend_empty = UiKit.lbl("Расходов нет.", 9, UiKit.MUTED, 1, 2)
	_spend_empty.custom_minimum_size = Vector2(0, 18)
	vb.add_child(_spend_empty)
	for i2: int in POOL_SPEND:
		_spend_rows.append(_pool_row(vb, false, "wb_bar_red"))
	_one_head = _section(vb, "РАЗОВО (НЕ В МИНУТУ)")
	_one_head.visible = false
	for i3: int in POOL_ONE:
		var hb: HBoxContainer = _row_panel(vb)
		var row: Control = hb.get_parent()
		row.visible = false
		var ic: TextureRect = U.icon("icon_trophy", 24.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(ic)
		var col: = VBoxContainer.new()
		col.add_theme_constant_override("separation", -1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(col)
		var nl: Label = UiKit.lbl("", 10, UiKit.GOLD, 2, 2)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(nl)
		col.add_child(UiKit.lbl("не входит в доход в минуту", 9, UiKit.MUTED, 1, 2))
		var v: Label = UiKit.lbl("", 12, UiKit.GOLD, 2, 2)
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(v)
		_one_rows.append({"row": row, "name": nl, "val": v, "key": ""})
	_section(vb, "ДОБЫЧА В МИНУТУ")
	_prod_empty = UiKit.lbl("Добычи пока нет.", 9, UiKit.MUTED, 1, 2)
	_prod_empty.custom_minimum_size = Vector2(0, 18)
	vb.add_child(_prod_empty)
	for i4: int in POOL_PROD:
		_prod_rows.append(_pool_row(vb, true, "wb_bar_amber"))
	_dev_lbl = UiKit.lbl("", 10, UiKit.TITLE, 2, 2)
	_dev_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_dev_lbl)
	_tot_lbl = UiKit.lbl("", 9, UiKit.MUTED, 1, 2)
	_tot_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_tot_lbl)



func _money_row(parent: Control, name_text: String, plus: bool, fs: int, weight: int) -> Array:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(0, 18)
	parent.add_child(row)
	var nl: Label = UiKit.lbl(name_text, fs, UiKit.TEXT, weight, 2)
	nl.custom_minimum_size = Vector2(104 if fs <= 10 else 62, 0)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiKit.fit_lbl(nl, [fs, fs - 1, fs - 2], false)
	nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(nl)
	var bar = Bar.new()
	bar.custom_minimum_size = Vector2(0, 12 if fs > 10 else 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.fill_name = "wb_bar_green" if plus else "wb_bar_red"
	bar.ticks = 4
	row.add_child(bar)
	var vl: Label = UiKit.lbl("", fs + 1, UiKit.GREEN if plus else UiKit.RED, 2, 2)
	vl.custom_minimum_size = Vector2(56, 0)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vl)
	return [bar, vl, nl, row]


func _pool_row(parent: Control, plus: bool, fill: String) -> Dictionary:
	var a: Array = _money_row(parent, "", plus, 10, 1)
	(a[0]).fill_name = fill
	(a[3] as Control).visible = false
	return {"row": a[3], "name": a[2], "bar": a[0], "val": a[1], "key": "", "plus": plus}



func _slot(prefix: String, key: String, pool: Array) -> int:
	var sk: String = prefix + ":" + key
	if _slot_of.has(sk):
		return int(_slot_of[sk])
	for i: int in pool.size():
		if String(pool[i]["key"]) == "":
			pool[i]["key"] = key
			_slot_of[sk] = i
			return i
	return -1


func _fill_pool(prefix: String, pool: Array, rows: Array, sc_max: float, sign_txt: String, anim: bool) -> int:
	var shown: int = 0
	var seen: Dictionary = {}
	var sorted: Array = rows.duplicate()
	sorted.sort_custom( func(a: Array, b: Array) -> bool: return absi(int(a[2])) > absi(int(b[2])))
	for r: Array in sorted:
		if int(r[2]) == 0 and not _slot_of.has(prefix + ":" + String(r[0])):
			continue
		var i: int = _slot(prefix, String(r[0]), pool)
		if i < 0:
			continue
		seen[i] = true
		var pr: Dictionary = pool[i]
		U.set_vis(pr["row"], true)
		U.set_lbl(pr["name"], Loc.t("НПЗ", "stat") if String(r[1]) == "НПЗ" else String(r[1]), UiKit.TEXT)
		var v: int = absi(int(r[2]))
		var col: Color = UiKit.GREEN if sign_txt == "+" else (UiKit.RED if sign_txt == "−" else UiKit.GOLD)
		var bar = pr["bar"]
		bar.set_meta("target", float(v) / sc_max)
		if not anim:
			U.set_lbl(pr["val"], sign_txt + U.num(v), col)
			bar.frac = float(v) / sc_max
		pr["v"] = v

	for i2: int in pool.size():
		var pr2: Dictionary = pool[i2]
		if String(pr2["key"]) == "":
			continue
		shown += 1
		if not seen.has(i2):
			pr2["v"] = 0
			pr2["bar"].set_meta("target", 0.0)
			if not anim:
				U.set_lbl(pr2["val"], sign_txt + "0", UiKit.MUTED)
				pr2["bar"].frac = 0.0
	return shown


func _fill_money(d: Dictionary) -> void :
	var anim: bool = Time.get_ticks_msec() < _anim_until and page == 2
	var tin: int = int(d.get("tin", 0))
	var tout: int = int(d.get("tout", 0))

	var sc_max: float = ceilf(maxf(1.0, float(maxi(tin, tout))) / 1000.0) * 1000.0
	for pair: Array in [[_tot_in, tin, "+", UiKit.GREEN], [_tot_out, tout, "−", UiKit.RED]]:
		var a: Array = pair[0]
		a[0].set_meta("target", float(int(pair[1])) / sc_max)
		if not anim:
			a[0].frac = float(int(pair[1])) / sc_max
			U.set_lbl(a[1], String(pair[2]) + U.num(int(pair[1])), pair[3])
	U.set_lbl(_scale_lbl, Loc.t("Шкала общая · 1 деление = %s/мин") % U.num(int(sc_max / 4.0)), UiKit.MUTED)
	var n_in: int = _fill_pool("inc", _inc_rows, d.get("income", []), sc_max, "+", anim)
	U.set_vis(_inc_empty, n_in == 0)
	var n_sp: int = _fill_pool("sp", _spend_rows, d.get("spend", []), sc_max, "−", anim)
	U.set_vis(_spend_empty, n_sp == 0)

	var one: Array = d.get("one_off", [])
	for r: Array in one:
		if int(r[2]) == 0:
			continue
		var i: int = _slot("one", String(r[0]), _one_rows)
		if i < 0:
			continue
		var orow: Dictionary = _one_rows[i]
		U.set_vis(orow["row"], true)
		U.set_lbl(orow["name"], Loc.t("Разово: %s") % [String(r[1]).to_lower()], UiKit.GOLD)
		U.set_lbl(orow["val"], U.signed(int(r[2])), UiKit.GOLD if int(r[2]) > 0 else UiKit.RED)
	var any_one: bool = false
	for orow2: Dictionary in _one_rows:
		if String(orow2["key"]) != "":
			any_one = true
			var still: bool = false
			for r2: Array in one:
				if String(r2[0]) == String(orow2["key"]) and int(r2[2]) != 0:
					still = true
			if not still:
				U.set_lbl(orow2["val"], "0", UiKit.MUTED)
	U.set_vis(_one_head, any_one)

	var pmax: float = 1.0
	for pr: Array in d.get("prod", []):
		pmax = maxf(pmax, float(int(pr[2])))
	pmax = ceilf(pmax / 10.0) * 10.0
	var n_pr: int = _fill_pool("pr", _prod_rows, d.get("prod", []), pmax, "+", anim)
	U.set_vis(_prod_empty, n_pr == 0)
	U.set_lbl(_dev_lbl, String(d.get("dev", "")), UiKit.TITLE)
	U.set_vis(_dev_lbl, String(d.get("dev", "")) != "")
	U.set_lbl(_tot_lbl, String(d.get("totals", "")), UiKit.MUTED)




func _fill(d: Dictionary) -> void :
	fills += 1
	var net: int = int(d.get("net", 0))
	U.set_lbl(_net_lbl, U.signed(net), UiKit.GREEN if net >= 0 else UiKit.RED)
	var bn: Dictionary = _bottleneck_of(d)
	if bn.is_empty():
		if _bn_panel.get_theme_stylebox("panel") != _sb_ok:
			_bn_panel.add_theme_stylebox_override("panel", _sb_ok)
		U.set_lbl(_bn_title, "Узких мест нет", UiKit.GREEN)
		U.set_lbl(_bn_sub, Loc.t("все цепочки работают") if not compact else "", UiKit.MUTED)
		_bn_fix = ""
	else:
		if _bn_panel.get_theme_stylebox("panel") != _sb_bad:
			_bn_panel.add_theme_stylebox_override("panel", _sb_bad)
		var title: String = Loc.t("Узкое место:%s%s") % [("\n" if compact else " "), String(bn["name"]).to_lower()]
		U.set_lbl(_bn_title, title, UiKit.TEXT)
		U.set_lbl(_bn_sub, "" if compact else _bn_short(String(bn["text"])), Color("ffe0d4"))
		_bn_fix = String(bn["fix"])
	U.set_vis(_bn_sub, not compact)
	_bn_btn.modulate.a = 1.0 if _bn_fix != "" else 0.0
	_bn_btn.disabled = _bn_fix == ""
	_fill_chains(d)
	var bad_store: int = _fill_store(d)
	_fill_money(d)
	var bad_ch: int = 0
	for c: Dictionary in d.get("chains", []):
		if String(c["status"]) == "bad":
			bad_ch += 1
	for i: int in 2:
		var bd: Label = _seg_badges[i]
		var n: int = bad_ch if i == 0 else bad_store
		if bd != null:
			U.set_vis(bd, n > 0)
			if bd.text != str(n):
				bd.text = str(n)




func _tw() -> Tween:
	var t: Tween = create_tween().set_parallel(true)
	_tweens.append(t)
	if _tweens.size() > 8:
		_tweens.pop_front()
	return t


func show_page(i: int, animate: bool) -> void :
	if i == page:
		return
	page = i
	for k: int in _seg.size():
		(_seg[k] as Button).set_pressed_no_signal(k == i)
	for k2: int in _pages.size():
		(_pages[k2] as Control).visible = k2 == i
	var sc: ScrollContainer = _pages[i]
	sc.scroll_vertical = 0
	var bars: Array = _page_bars(i)
	if not animate:
		_anim_until = 0
		for b: Variant in bars:
			b.frac = float(b.get_meta("target", b.frac))
		_fill(_data)
		return
	var tw: Tween = _tw()
	_anim_until = Time.get_ticks_msec() + 350
	sc.position.x = 24.0
	sc.modulate.a = 0.0
	tw.tween_property(sc, "position:x", 0.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(sc, "modulate:a", 1.0, 0.12)
	for b2: Variant in bars:
		b2.tween_to(tw, float(b2.get_meta("target", 0.0)), 0.3)
	if i == 2:
		for pair: Array in [[_tot_in, "+"], [_tot_out, "−"]]:
			var lab: Label = pair[0][1]
			var target: int = int(_data.get("tin" if String(pair[1]) == "+" else "tout", 0))
			var pre: String = String(pair[1])
			tw.tween_method( func(x: float) -> void : lab.text = pre + U.num(roundi(x)), 0.0, float(target), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect( func() -> void :
		_anim_until = 0
		if not closing:
			_fill(_data))


func _page_bars(i: int) -> Array:
	var out: Array = []
	if i == 1:
		for k: String in _store_refs:
			out.append(_store_refs[k]["bar"])
	elif i == 2:
		out.append(_tot_in[0])
		out.append(_tot_out[0])
		for pool: Array in [_inc_rows, _spend_rows, _prod_rows]:
			for pr: Dictionary in pool:
				if String(pr["key"]) != "":
					out.append(pr["bar"])
	return out








const Spark = preload("res://ui/ui24/price_spark.gd")
var _ab_rows: Dictionary = {}
var _ab_open: String = ""
var _ab_foot_lbl: Label


func _econ() -> Economy:
	return hud.gw.econ if hud != null and hud.gw != null else null


func _ab_row(vb: VBoxContainer, key: String, hb: HBoxContainer) -> void :
	var pc: PanelContainer = hb.get_parent() as PanelContainer
	if pc == null:
		return
	pc.remove_child(hb)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(col)
	col.add_child(hb)
	var l2: = HBoxContainer.new()
	l2.add_theme_constant_override("separation", 4)
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(l2)
	var pad: = Control.new()
	pad.custom_minimum_size = Vector2(STORE_W[0], 0)
	l2.add_child(pad)
	var sp = Spark.new()
	sp.custom_minimum_size = Vector2(52, 12)
	sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l2.add_child(sp)
	var pct: Label = UiKit.lbl("", 9, UiKit.MUTED, 2, 2)
	pct.custom_minimum_size = Vector2(30, 0)
	l2.add_child(pct)
	var why: Label = UiKit.lbl("", 9, UiKit.MUTED, 1, 2)
	why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	why.clip_text = true
	why.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l2.add_child(why)
	var chip: Label = UiKit.lbl("", 9, UiKit.GREEN, 2, 2)
	l2.add_child(chip)
	pc.custom_minimum_size.y = 44.0

	var tap: = Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		tap.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	tap.pressed.connect( func() -> void :
		UiKit.snd("ui_tab")
		open_res(key))
	pc.add_child(tap)
	var drawer: PanelContainer = _ab_drawer(vb, key)
	_ab_rows[key]["spark"] = sp
	_ab_rows[key]["pct"] = pct
	_ab_rows[key]["why"] = why
	_ab_rows[key]["chip"] = chip
	_ab_rows[key]["drawer"] = drawer


func _ab_drawer(vb: VBoxContainer, key: String) -> PanelContainer:
	var pc: = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 5))
	pc.visible = false
	vb.add_child(pc)
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pc.add_child(v)
	var head: Label = UiKit.lbl("", 10, UiKit.TITLE, 2, 2)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(head)
	var big = Spark.new()
	big.big = true
	big.custom_minimum_size = Vector2(0, 40)
	v.add_child(big)
	var refs: Dictionary = {"head": head, "big": big, "vals": {}}
	_ab_rows[key] = refs
	if not Economy.AB_RES.has(key):
		var nl: Label = UiKit.lbl("Топливо не продаётся на рынке: его делает НПЗ из нефти. Нефть можно закупать автоматически.", 9, UiKit.MUTED, 1, 2)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(nl)
		return pc
	var top: = HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	var tg: Button = UiKit.big("АВТОЗАКУПКА", "stone", "", 44.0, 11)
	tg.custom_minimum_size.x = 132
	tg.pressed.connect(_ab_flip.bind(key))
	top.add_child(tg)
	var st: Label = UiKit.lbl("", 9, UiKit.MUTED, 2, 2)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(st)
	refs["toggle"] = tg
	refs["st"] = st
	for it: Array in [["lo", "Покупать, когда меньше"], ["hi", "Докупать до"], ["max", "Цена не выше"]]:
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		v.add_child(row)
		var cap: Label = UiKit.lbl(String(it[1]), 10, UiKit.TEXT, 1, 2)
		cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cap)
		var mb: Button = UiKit.big("−", "stone", "", 44.0, 16)
		mb.custom_minimum_size.x = 44
		mb.pressed.connect(_ab_step.bind(key, String(it[0]), -1))
		row.add_child(mb)
		var val: Label = UiKit.lbl("0", 12, UiKit.GOLD, 2, 2)
		val.custom_minimum_size = Vector2(44, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(val)
		var pb: Button = UiKit.big("+", "stone", "", 44.0, 16)
		pb.custom_minimum_size.x = 44
		pb.pressed.connect(_ab_step.bind(key, String(it[0]), 1))
		row.add_child(pb)
		(refs["vals"] as Dictionary)[String(it[0])] = val
	var lg: Label = UiKit.lbl("", 9, UiKit.MUTED, 1, 2)
	lg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(lg)
	refs["log"] = lg
	return pc


func _ab_foot(vb: VBoxContainer) -> void :
	_ab_foot_lbl = UiKit.lbl("", 9, UiKit.MUTED, 1, 2)
	_ab_foot_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_ab_foot_lbl)


func _ab_flip(key: String) -> void :
	var e: Economy = _econ()
	if e == null or player == null:
		return
	var on: bool = not bool(e.autobuy_get(player, key)["on"])
	UiKit.snd("ui_build" if on else "ui_tab")
	NetSession.sim("econ", "autobuy_set", [player, key, "on", on], func(_r: Variant) -> void :
		if is_instance_valid(self):
			_ab_fill())


func _ab_step(key: String, what: String, sgn: int) -> void :
	var e: Economy = _econ()
	if e == null or player == null:
		return
	var cur: Dictionary = e.autobuy_get(player, key)
	var cap: int = e.res_cap(player, key)
	var step: int = (10 if cap > 200 else 5) if what != "max" else (2 if int(cur["max"]) >= 40 else 1)
	NetSession.sim("econ", "autobuy_set", [player, key, what, int(cur[what]) + sgn * step], func(_r: Variant) -> void :
		if is_instance_valid(self):
			_ab_fill())


func _ab_fill() -> void :
	var e: Economy = _econ()
	if e == null or player == null:
		return
	var now: float = hud.gw.game_time
	for key: String in _ab_rows:
		var r: Dictionary = _ab_rows[key]
		if not r.has("spark"):
			continue
		var pt: Dictionary = e.price_trend(key)
		var dir: int = int(pt["dir"])
		(r["spark"]).set_data(pt["hist"], dir, bool(pt["crisis"]))
		var pc: int = int(pt["pct"])
		U.set_lbl(r["pct"], (U.signed(pc) + "%") if dir != 0 else "0%", Spark.UP if dir > 0 else (Spark.DOWN if dir < 0 else UiKit.DIM))
		var why: String = String(pt["reason"])
		U.set_lbl(r["why"], why if why != "" else Loc.t("цена ровная"), UiKit.RED.lightened(0.25) if bool(pt["crisis"]) else UiKit.MUTED)
		var ab: Dictionary = e.autobuy_get(player, key) if Economy.AB_RES.has(key) else {"on": false}
		U.set_lbl(r["chip"], Loc.t("АВТО") if bool(ab["on"]) else "", UiKit.GREEN)
		if _ab_open != key:
			continue
		(r["big"]).set_data(pt["hist"], dir, bool(pt["crisis"]))
		var nm: String = String(Economy.RES_NAMES.get(key, key))
		var head: String = Loc.t("%s · %d за ед. · %s за ~2 мин") % [nm, int(pt["price"]), (U.signed(pc) + "%") if dir != 0 else Loc.t("без изменений")]
		if why != "":
			head += " · " + why
		U.set_lbl(r["head"], head, UiKit.TITLE)
		if not r.has("toggle"):
			continue
		var tg: Button = r["toggle"]
		var on: bool = bool(ab["on"])
		var want_txt: String = Loc.t("АВТО: ВКЛ") if on else Loc.t("АВТО: ВЫКЛ")
		if tg.text != want_txt:
			tg.text = want_txt
			var colour: String = "green" if on else "stone"
			tg.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_" + colour, 12, 4, -1))
			tg.add_theme_stylebox_override("hover", UiKit.sb("wb_btn_" + colour, 12, 4, -1))
		var st: String = e.autobuy_status(player, key)
		U.set_lbl(r["st"], st.to_lower() if st != "" else (Loc.t("купит, когда запас ниже порога") if on else Loc.t("выключено: включите, чтобы склад пополнялся сам")), 
			UiKit.RED.lightened(0.2) if e.autobuy_warn(player, key) else UiKit.MUTED)
		var vals: Dictionary = r["vals"]
		U.set_lbl(vals["lo"], str(int(ab["lo"])), UiKit.GOLD)
		U.set_lbl(vals["hi"], str(int(ab["hi"])), UiKit.GOLD)
		U.set_lbl(vals["max"], str(int(ab["max"])), UiKit.GOLD if int(pt["price"]) <= int(ab["max"]) else UiKit.RED.lightened(0.2))
		var lines: Array = e.autobuy_lines(player, 1)
		var lt: String = ""
		for ln: Array in lines:
			if (String(ln[2]) == key) if String(ln[2]) != "" else String(ln[0]).find(String(Economy.RES_GEN.get(key, "?"))) >= 0:
				lt = Loc.t("Последняя: %s · %s назад") % [String(ln[0]), U.mmss(now - float(ln[1]))]
		U.set_lbl(r["log"], lt if lt != "" else Loc.t("Покупает у соседей без войны и эмбарго или через порт; резерв %d денег не трогает.") % Economy.AB_FLOOR, UiKit.MUTED)
	if _ab_foot_lbl != null:
		var ls: Array = e.autobuy_lines(player, 2)
		var parts: PackedStringArray = PackedStringArray()
		for ln2: Array in ls:
			parts.append(Loc.t("%s (%s назад)") % [String(ln2[0]), U.mmss(now - float(ln2[1]))])
		U.set_lbl(_ab_foot_lbl, (Loc.t("Автозакупка: %s") % [" · ".join(parts)]) if not parts.is_empty() else Loc.t("Тап по строке — кто делает, кто тратит, рынок."), UiKit.MUTED)





const CHAIN_RES: Dictionary = {"food": "food", "goods": "goods", "metal": "metal", "titanium": "titanium", 
	"precious": "precious", "uranium": "uranium", "wood": "wood", "oil": "fuel"}
var res_view = null
var _vb: VBoxContainer
var _hidden: Array = []
var _back_res: String = ""
var _back_stage: String = ""
var _back_until: int = 0
var _ab_home: Array = []



func open_res(res: String, want: String = "", animate: bool = true) -> void :
	if _vb == null or not ResSheet.NAMES.has(res):
		return
	if res_view == null or not is_instance_valid(res_view):
		res_view = ResSheet.new()
		_vb.add_child(res_view)
		res_view.setup(self, compact)
	if not res_view.visible or _hidden.is_empty():
		_hidden.clear()
		for ch: Node in _vb.get_children():
			if ch != res_view and ch is CanvasItem and (ch as CanvasItem).visible:
				_hidden.append(ch)
				(ch as CanvasItem).visible = false
	res_view.visible = true
	_back_res = ""
	res_view.call("show_res", res, want)
	if animate:
		var tw: Tween = _tw()
		res_view.modulate.a = 0.0
		tw.tween_property(res_view, "modulate:a", 1.0, 0.12)



func close_res(user_back: bool) -> void :
	if res_view == null or not is_instance_valid(res_view) or not res_view.visible:
		return
	res_view.call("release")
	res_view.visible = false
	for ch: Variant in _hidden:
		if is_instance_valid(ch):
			(ch as CanvasItem).visible = true
	_hidden.clear()
	if user_back:
		_back_res = ""
		_fill(_data)


func chain_for_res(res: String) -> Dictionary:
	for c: Dictionary in _data.get("chains", []):
		if String(CHAIN_RES.get(String(c["id"]), "")) == res:
			return c
	return {}


func res_fix(fix: String) -> void :
	action.emit("plan_go:" + fix)



func res_go(go: String) -> void :
	if res_view == null:
		return
	_back_res = String(res_view.key)
	_back_stage = String(res_view.call("stage_id"))
	_back_until = Time.get_ticks_msec() + 180000
	if go.begins_with("fac:"):
		action.emit("fac_go:" + go.substr(4))
	elif go.begins_with("dep:"):
		action.emit("dep_go:" + go.substr(4))


func ab_take(res: String) -> Control:
	var r: Dictionary = _ab_rows.get(res, {})
	var drv: Variant = r.get("drawer")
	if not is_instance_valid(drv):
		return null
	var dr: Control = drv
	var par: Node = dr.get_parent()
	_ab_home = [par, dr.get_index()] if par != null else []
	_ab_open = res
	_ab_fill()
	return dr


func ab_give_back(dr: Control) -> void :
	if dr == null or not is_instance_valid(dr):
		return
	if dr.get_parent() != null:
		dr.get_parent().remove_child(dr)
	if _ab_home.size() == 2 and is_instance_valid(_ab_home[0]):
		var par: Node = _ab_home[0]
		par.add_child(dr)
		par.move_child(dr, mini(int(_ab_home[1]), par.get_child_count() - 1))
	dr.visible = false
	_ab_open = ""
	_ab_home = []
