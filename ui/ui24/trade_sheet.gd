extends PanelContainer









signal action(name: String)

const U = preload("res://ui/ui24/econ_kit.gd")
const Bar = preload("res://ui/ui24/bar_track.gd")
const Spark = preload("res://ui/ui24/price_spark.gd")
const RS = preload("res://ui/ui24/res_sheet.gd")
const AMBER: = Color("ffb000")
const NOTE_T: float = 5.0
const SALMON: = Color("ffb39c")
const HOLD_FIRST: float = 0.45
const HOLD_STEP: float = 0.5
const PEND_MAX_MS: int = 2500
const QTY: Array[int] = [10, 50, -1]
const LOC_TABS: Array = [["РЫНОК", "icon_persona_trader"], ["В ПУТИ", "r332_rail_on"], ["ДОГОВОРЫ", "icon_treaty_trade"]]
const LOC_MODE: Dictionary = {"rail": "поездом", "ship": "кораблём", "truck": "грузовиком", "import": "кораблём", "export": "кораблём", "queue": "ближайшим кораблём"}
const MODE_ICON: Dictionary = {"rail": "r332_rail_on", "ship": "icon_ship", "truck": "icon_trade", "import": "icon_ship", "export": "icon_export", "queue": "icon_port_crane"}
const LOC_KIND: Dictionary = {"buy": "ПОКУПКА", "sell": "ПРОДАЖА", "import": "ИМПОРТ", "export": "ЭКСПОРТ", "queue": "ИМПОРТ", "aid": "ПОМОЩЬ", "in": "ПО ДОГОВОРУ", "out": "ПО ДОГОВОРУ"}
const KIND_COL: Dictionary = {"buy": Color("a2e35f"), "sell": Color("ffd75e"), "import": Color("7cccff"), "export": Color("ffd75e"), "queue": Color("7cccff"), "aid": Color("cfc6a8"), "in": Color("a2e35f"), "out": Color("ffd75e")}
const NOTE_STYLE: Dictionary = {"ok": "wb_btn_green_p", "bad": "wb_btn_red_p", "info": "wb_btn_blue_p", "idle": "wb_panel_dark", "warn": "wb_btn_gold_p"}
const NOTE_ICON: Dictionary = {"ok": "icon_ok", "bad": "icon_scarce", "info": "icon_buy", "warn": "icon_store"}

var hud: Node
var gw: GameWorld
var player: Country
var compact: bool = false
var closing: bool = false
var page: int = 0
var sel: String = ""
var qty_i: int = 0
var rows_d: Dictionary = {}
var transit: Array = []
var collect_us: int = 0
var orders: int = 0
var note_log: Array = []

var _t: float = 0.0
var _pages: Array = []
var _seg: Array = []
var _req_badge: Label
var _pill_lbl: Label
var _rows: Dictionary = {}
var _list_vb: VBoxContainer
var _card: PanelContainer
var _c_icon: TextureRect
var _c_name: Label
var _c_stock: Label
var _c_flow: Label
var _c_money: Label
var _chips: Array = []
var _closed_lbl: Label
var _closed_btn: Button
var closed_txt: String = ""
var _colhead: Control
var _port_chip: Button
var _port_detail: Array = ["", "info"]
var _note_tw: Tween
var _bbuy: Dictionary = {}
var _bsell: Dictionary = {}
var _cap_buy: Array = []
var _cap_sell: Array = []
var _note: PanelContainer
var _note_icon: TextureRect
var _note_lbl: Label
var _note_kind: String = ""
var _note_until: float = 0.0
var _note_q: Array = []
var _note_t0: float = 0.0
var _note_txt: String = ""
var _note_pas: bool = false
const NOTE_MIN: float = 2.0
var _clock: float = 0.0
var _acc: Dictionary = {}
var _pending: bool = false
var _pending_ms: int = 0
var _hold: String = ""
var _hold_t: float = 0.0
var _hold_n: int = 0
var _hold_fired: bool = false
var _route_cache: Dictionary = {}
var _tr_vb: VBoxContainer
var _tr_sig: String = ""
var _tr_rows: Array = []
var _tr_seen: Array = []
var _pt_vb: VBoxContainer
var _pt_sig: String = ""
var _pt_spare: Dictionary = {}
var _tin: Dictionary = {}
var _tout: Dictionary = {}



func setup(h: Node, sheet_h: float, bottom_pad: float) -> void :
	hud = h
	gw = hud.gw
	player = gw.player
	UiKit.ensure()
	compact = sheet_h < 430.0
	custom_minimum_size = Vector2(0, sheet_h)
	var psb: StyleBox = UiKit.sb("wb_window", 8, 6)
	psb.content_margin_bottom = 6.0 + bottom_pad
	add_theme_stylebox_override("panel", psb)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("kind", "trade")
	tree_exiting.connect( func() -> void :
		if hud != null and is_instance_valid(hud):
			hud.call("ui24_closed", self))
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3 if compact else 4)
	add_child(vb)
	if compact:
		var top: = HBoxContainer.new()
		top.add_theme_constant_override("separation", 4)
		vb.add_child(top)
		var sg: Control = _segments()
		sg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(sg)
		top.add_child(_close())
	else:
		vb.add_child(_header())
		vb.add_child(_segments())
	_colhead = _col_head()
	vb.add_child(_colhead)
	var stage: = Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(stage)
	for i: int in 3:
		var sc: = ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.set_anchors_preset(Control.PRESET_FULL_RECT)
		sc.visible = false
		stage.add_child(sc)
		var inner: = VBoxContainer.new()
		inner.add_theme_constant_override("separation", 3)
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(inner)
		_pages.append(sc)
	_list_vb = (_pages[0] as ScrollContainer).get_child(0) as VBoxContainer
	_tr_vb = (_pages[1] as ScrollContainer).get_child(0) as VBoxContainer
	_pt_vb = (_pages[2] as ScrollContainer).get_child(0) as VBoxContainer
	stage.add_child(_note_line())
	vb.add_child(_deal_card())
	_build_list()
	sel = _default_sel()
	refresh()
	show_page(0)




func scroll_areas() -> Array:
	return _pages


func scroll_area() -> ScrollContainer:
	return _pages[page] if page >= 0 and page < _pages.size() else null


func close() -> void :
	if closing:
		return
	closing = true
	_hold = ""
	if hud != null and is_instance_valid(hud):
		hud.call("ui24_closed", self)
	visible = false
	queue_free()


func refresh_now() -> void :
	_t = 0.0


func _process(delta: float) -> void :
	if closing or hud == null or not is_instance_valid(hud):
		return
	if gw == null or gw.player == null or gw.player != player or player.eliminated or bool(hud.ops_panel.visible):
		close()
		return
	if hud.panel != null and is_instance_valid(hud.panel):
		close()
		return
	for e: Variant in hud.cmd_btns:
		var cb: Control = (e as Array)[0]
		if cb != null and cb.visible:
			cb.visible = false
	_clock += delta
	if _pending and Time.get_ticks_msec() - _pending_ms > PEND_MAX_MS:
		_pending = false
	_hold_tick(delta)
	if _note_kind != "" and _clock >= _note_until:
		_note_hide()
	_fit_note()
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	refresh()




func refresh() -> void :
	var t0: int = Time.get_ticks_usec()
	_collect()
	_collect_transit()
	collect_us = Time.get_ticks_usec() - t0
	_fill_list()
	_fill_card()
	_fill_transit()
	_fill_partners()
	_fill_head()
	_fill_port()


func _collect() -> void :
	var e: Economy = gw.econ
	var p: Country = player
	var st: Dictionary = e.stats(p)
	_tin.clear()
	_tout.clear()
	for res: String in Economy.TRADE_RES:
		var a: int = 0
		for v: Variant in (st["res_in"].get(res, {}) as Dictionary).values():
			a += int(v)
		var b: int = 0
		for v2: Variant in (st["res_out"].get(res, {}) as Dictionary).values():
			b += int(v2)
		_tin[res] = a
		_tout[res] = b
		var d: Dictionary = {"key": res, "n": int(p.get(res)), "cap": e.res_cap(p, res), "inb": e.inbound(p, res), "need": e.need(p, res), 
			"rate": a - b, "tin": a, "tout": b, "trend": e.price_trend(res)}
		d["buy"] = _side(res, true)
		d["sell"] = _side(res, false)
		rows_d[res] = d
	var inc: Dictionary = st.get("income", {})
	var sp: Dictionary = st.get("spend", {})
	rows_d["_money"] = int(inc.get("trade", 0)) + int(inc.get("export", 0)) - int(sp.get("trade", 0)) - int(sp.get("import", 0))




func _side(res: String, buying: bool) -> Dictionary:
	var e: Economy = gw.econ
	var p: Country = player
	var mc: Dictionary = e.market_check(p, res, buying)
	var c: Country = mc.get("partner") as Country
	var out: Dictionary = {"ok": bool(mc.get("ok", false)), "why": String(mc.get("why", "")), "partner": c, "unit": 0, "mode": "", "eta": -1.0, "max": 0}
	var pf: Facility = e.ports.port_of(p)
	var stock: int = int(p.get(res))
	if buying:
		if c != null:
			var u: int = maxi(1, roundi(e.market_price(res) * gw.diplo.trade_mul(p.id, c.id)))
			out["unit"] = u
			out["max"] = mini(mini(e.surplus(c, res), e.room_for(p, res)), p.money / u)
			var rt: Array = _route(c, p)
			out["mode"] = rt[0]
			out["eta"] = rt[1]
		else:
			var u2: int = e.foreign_buy_price(res, p.id)
			out["unit"] = u2
			var bs: Country = e.best_seller(p, res) if not bool(out["ok"]) else null
			if bs != null:
				out["unit"] = maxi(1, roundi(e.market_price(res) * gw.diplo.trade_mul(p.id, bs.id)))
			out["mode"] = "import"
			if pf != null:
				out["max"] = mini(mini(e.ports.load_of(pf), e.room_for(p, res)), p.money / u2)
				if e.ports.active(pf) >= e.ports.capacity(pf):
					out["mode"] = "queue"
	else:
		if c != null:
			var u3: int = e.market_price(res)
			out["unit"] = u3
			var room_b: int = e.res_cap(c, res) - int(c.get(res)) - e.inbound(c, res)
			var lack: int = e.need(c, res) - e.inbound(c, res)
			var take: int = lack if lack > 0 else (room_b / 2 if c.money > u3 * stock + 800 else 0)
			out["max"] = maxi(0, mini(mini(take, room_b), mini(stock, c.money / u3)))
			var rt2: Array = _route(p, c)
			out["mode"] = rt2[0]
			out["eta"] = rt2[1]
		else:
			out["unit"] = maxi(1, int(e.market_price(res) * Economy.FOREIGN_SELL))
			out["mode"] = "export"
			if pf != null:
				out["max"] = mini(e.ports.load_of(pf), stock)
	return out




func _route(a: Country, b: Country) -> Array:
	var k: String = "%d>%d" % [a.id, b.id]
	var now: int = Time.get_ticks_msec()
	var c: Array = _route_cache.get(k, [])
	if not c.is_empty() and now - int(c[0]) < 5000:
		return [c[1], c[2]]
	var e: Economy = gw.econ
	var pa: Vector2 = Vector2(gw.cities[a.capital_id].entrance * GameWorld.CELL)
	var pb: Vector2 = Vector2(gw.cities[b.capital_id].entrance * GameWorld.CELL)
	var d: float = pa.distance_to(pb)
	var mode: String = "truck"
	var eta: float = d * 1.3 / Economy.TRUCK_SPEED
	var rail: Variant = gw.get("rail")
	if rail is Object and (rail as Object).has_method("has_link") and bool((rail as Object).call("has_link", a.capital_id, b.capital_id)):
		mode = "rail"
		eta = d * 1.25 / Economy.RAIL_ETA_SPEED
	elif e.ports.can_sail(a, b) and e.ports.sea_dist(a, b) < d * 1.3 * 0.8:
		mode = "ship"
		eta = e.ports.sea_dist(a, b) / Ports.SHIP_SPEED + Ports.LOAD_TIME
	_route_cache[k] = [now, mode, eta]
	return [mode, eta]



func _closed(res: String) -> Dictionary:
	var out: Dictionary = {"war": 0, "emb": 0, "sanc": 0}
	var e: Economy = gw.econ
	for o: Country in gw.countries:
		if o == player or o.eliminated or o.capital_id < 0:
			continue
		if gw.diplo.at_war(player.id, o.id):
			out["war"] = int(out["war"]) + 1
		elif gw.diplo.embargo_between(player.id, o.id):
			out["emb"] = int(out["emb"]) + 1
		elif e.trd != null and e.trd.res_blocked(player.id, o.id, res):
			out["sanc"] = int(out["sanc"]) + 1
	return out


func _default_sel() -> String:
	var best: String = ""
	var bv: int = 0
	for res: String in Economy.TRADE_RES:
		var v: int = gw.econ.need(player, res) * gw.econ.market_price(res)
		if v > bv:
			bv = v
			best = res
	return best if best != "" else "metal"


static func _plen(a: Vector2, p: PackedVector2Array, from_i: int) -> float:
	var l: float = 0.0
	var prev: Vector2 = a
	for i: int in range(maxi(0, from_i), p.size()):
		l += prev.distance_to(p[i])
		prev = p[i]
	return l



func _collect_transit() -> void :
	var e: Economy = gw.econ
	var pid: int = player.id
	var out: Array = []
	for t: Dictionary in e.trucks:
		var fr: int = int(t["from"])
		var to: int = int(t["to"])
		if fr != pid and to != pid:
			continue
		var path: PackedVector2Array = t["path"]
		var rem: float = _plen(t["pos"], path, int(t["i"]))
		var tot: float = maxf(1.0, _plen(path[0] if path.size() > 0 else t["pos"], path, 1))
		out.append(_tr_item(t, "t%d" % int(t.get("id", 0)), to == pid, t, "truck", rem / Economy.TRUCK_SPEED, 1.0 - clampf(rem / tot, 0.0, 1.0)))
	var rail: Variant = gw.get("rail")
	var ji: int = 0
	for j: Dictionary in e.rail_jobs:
		ji += 1
		var fr2: int = int(j["from"])
		var to2: int = int(j["to"])
		if fr2 != pid and to2 != pid:
			continue
		var eta: float = -1.0
		var frac: float = 0.0
		if rail is Object:
			for tr: Dictionary in (rail as Object).get("trains"):
				if is_same(tr.get("job"), j):
					var L: float = maxf(1.0, float(tr.get("L", 1.0)))
					var s: float = float(tr.get("s", 0.0))
					eta = maxf(0.0, L - s) / Rail.TRAIN_SPEED
					frac = clampf(s / L, 0.0, 1.0)
					break
		out.append(_tr_item(j, "r%d:%d:%s:%d:%d" % [fr2, to2, String(j["res"]), int(j["n"]), ji], to2 == pid, j, "rail", eta, frac))
	for s2: Dictionary in e.ports.ships:
		var st: int = int(s2["stage"])
		var kd: String = String(s2["kind"])
		var inc: bool = int(s2["to"]) == pid and (st < 2 or bool(s2.get("back", false)))
		var outg: bool = int(s2["from"]) == pid and st < 2
		if not inc and not outg:
			continue
		var path2: PackedVector2Array = s2["path"]
		var rem2: float = _plen(s2["pos"], path2, int(s2["i"]))
		var tot2: float = maxf(1.0, _plen(path2[0] if path2.size() > 0 else s2["pos"], path2, 1))
		var eta2: float = rem2 / Ports.SHIP_SPEED + (maxf(0.0, float(s2.get("t", 0.0))) if st == 0 else 0.0)
		var it: Dictionary = _tr_item(s2, "s%d" % int(s2["id"]), inc, s2, "ship", eta2, 1.0 - clampf(rem2 / tot2, 0.0, 1.0))
		if kd == "import" or (st == 2 and inc):
			it["kind"] = "import"
			it["other"] = Loc.t("из-за рубежа")
		elif kd == "export":
			it["kind"] = "export"
			it["other"] = Loc.t("за рубеж")
			it["price"] = int(e.market_price(String(s2["res"])) * Economy.FOREIGN_SELL) * int(s2["n"])
		out.append(it)
	var qi: int = 0
	for o: Dictionary in e.ports.queue.get(pid, []):
		qi += 1
		var it2: Dictionary = _tr_item(o, "q%d:%s:%d" % [qi, String(o["res"]), int(o["n"])], true, o, "queue", -1.0, 0.0)
		it2["kind"] = "queue"
		it2["other"] = Loc.t("из-за рубежа")
		out.append(it2)
	out.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		var ea: float = float(a["eta"]) if float(a["eta"]) >= 0.0 else 1000000000.0
		var eb: float = float(b["eta"]) if float(b["eta"]) >= 0.0 else 1000000000.0
		return ea < eb)

	for old: Dictionary in _tr_seen:
		var still: bool = false
		for nw: Dictionary in out:
			if is_same(nw["ref"], old["ref"]):
				still = true
				break
		if not still:
			_gone(old)
	_tr_seen = out.duplicate()
	transit = out


func _tr_item(ref: Dictionary, key: String, incoming: bool, d: Dictionary, mode: String, eta: float, frac: float) -> Dictionary:
	var oid: int = int(d["from"]) if incoming else int(d["to"])
	var oc: Country = gw.country_by_id(oid) if oid > 0 else null
	var kind: String = ("buy" if bool(d.get("mkt", false)) else "in") if incoming else ("sell" if bool(d.get("mkt", false)) else "out")
	if bool(d.get("aid", false)):
		kind = "aid"
	return {"ref": ref, "key": key, "kind": kind, "inc": incoming, "res": String(d["res"]), "n": int(d["n"]), "mode": mode, 
		"other": Loc.name(oc.name) if oc != null else "", "price": int(d.get("price", 0)), "eta": eta, "frac": frac, 
		"end": (d["path"] as PackedVector2Array)[(d["path"] as PackedVector2Array).size() - 1] if d.has("path") and (d["path"] as PackedVector2Array).size() > 0 else Vector2.ZERO, 
		"stage": int(d.get("stage", 1))}


func _gone(it: Dictionary) -> void :
	var ref: Dictionary = it["ref"]
	var rn: String = Loc.t(String(RS.GEN.get(String(it["res"]), it["res"])))
	if bool(ref.get("refunded", false)):
		_notice(Loc.f("Поставка сорвалась: {n} {res} · деньги вернулись", {"n": it["n"], "res": rn}), "bad", true)
		return
	if String(it["mode"]) == "ship" and int(ref.get("stage", 1)) < 2 and (ref.get("pos", Vector2.ZERO) as Vector2).distance_to(it["end"]) > 24.0:
		_notice(Loc.f("Корабль потоплен: {n} {res} не дошли", {"n": it["n"], "res": rn}), "bad", true)
		return
	match String(it["kind"]):
		"buy", "in", "import", "queue":
			_notice(Loc.f("Прибыло: {n} {res} — на складе", {"n": it["n"], "res": rn}), "info", true)
		"sell", "out":
			_notice(Loc.f("Доставлено: {n} {res} · получено {sum}", {"n": it["n"], "res": rn, "sum": U.num(int(it["price"]))}), "ok", true)
		"export":
			_notice(Loc.f("Экспорт дошёл: {n} {res} · получено {sum}", {"n": it["n"], "res": rn, "sum": U.num(int(it["price"]))}), "ok", true)




func _close() -> Button:
	var cb: Button = UiKit.close_btn(44.0)
	cb.pressed.connect( func() -> void :
		UiKit.snd("ui_close")
		action.emit("close"))
	return cb


func _header() -> Control:
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.custom_minimum_size = Vector2(0, 44)
	var t: Label = UiKit.lbl(Loc.t("ТОРГОВЛЯ"), 18, UiKit.TITLE, 3, 2)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(t)
	var pill: = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UiKit.sb("wb_pill", 7, 3))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ph: = HBoxContainer.new()
	ph.add_theme_constant_override("separation", 3)
	pill.add_child(ph)
	var ic: TextureRect = U.icon("icon_trade", 18.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(ic)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	ph.add_child(col)
	_pill_lbl = UiKit.lbl("0", 14, UiKit.MUTED, 2, 3)
	_pill_lbl.custom_minimum_size = Vector2(50, 0)
	col.add_child(_pill_lbl)
	col.add_child(UiKit.lbl(Loc.t("торговля / мин"), 10, UiKit.MUTED, 2, 2))
	hb.add_child(pill)
	hb.add_child(_close())
	return hb


func _segments() -> Control:
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	for i: int in LOC_TABS.size():
		var b: = Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = Loc.t(String(LOC_TABS[i][0]))
		UiKit.no_tr(b)
		b.icon = U.tex(String(LOC_TABS[i][1])) if not compact else null
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
		for s2: Array in [["normal", "wb_btn_stone_p", 1], ["hover", "wb_btn_stone_p", 1], ["pressed", "wb_btn_gold", -1], ["hover_pressed", "wb_btn_gold", -1]]:
			var sbx: StyleBox = UiKit.sb(String(s2[1]), 5, 4, float(s2[2]))
			sbx.content_margin_right = 16.0 if i == 2 else 5.0
			b.add_theme_stylebox_override(String(s2[0]), sbx)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var idx: int = i
		b.pressed.connect( func() -> void :
			UiKit.snd("ui_tab")
			show_page(idx))
		hb.add_child(b)
		_seg.append(b)
		if i == 2:
			_req_badge = U.badge_label(0)
			_req_badge.visible = false
			b.add_child(_req_badge)
			var host: Button = b
			var lab: Label = _req_badge
			host.resized.connect( func() -> void : lab.position = Vector2(host.size.x - 17.0, roundf((host.size.y - 14.0) * 0.5) - 1.0))
	return hb


func show_page(i: int) -> void :
	page = clampi(i, 0, 2)
	for k: int in _pages.size():
		(_pages[k] as Control).visible = k == page
		(_seg[k] as Button).set_pressed_no_signal(k == page)
	U.set_vis(_card, page == 0)
	U.set_vis(_colhead, page == 0)
	_hold = ""


func _fill_head() -> void :
	var nreq: int = gw.econ.requests_for(player.id).size() if player != null else 0
	if _req_badge != null:
		_req_badge.text = str(nreq)
		U.set_vis(_req_badge, nreq > 0)
	var ntr: int = transit.size()
	var tb: Button = _seg[1]
	var tt: String = Loc.t("В ПУТИ") + ((" %d" % ntr) if ntr > 0 else "")
	if tb.text != tt:
		tb.text = tt
	if _pill_lbl != null:
		var mv: int = int(rows_d.get("_money", 0))
		U.set_lbl(_pill_lbl, U.signed(mv), UiKit.GREEN if mv > 0 else (UiKit.RED if mv < 0 else UiKit.MUTED))




func _note_line() -> Control:
	_note = PanelContainer.new()
	_note.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 5))
	_note.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_note.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_note.offset_left = 3.0
	_note.offset_right = -3.0
	_note.offset_bottom = -3.0
	_note.offset_top = -40.0
	_note.mouse_filter = Control.MOUSE_FILTER_STOP
	_note.visible = false
	_note.gui_input.connect( func(ev: InputEvent) -> void :
		if ev is InputEventMouseButton and not (ev as InputEventMouseButton).pressed:
			_note_hide())
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.add_child(hb)
	_note_icon = U.icon("icon_trade", 20.0)
	_note_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_note_icon)
	_note_lbl = UiKit.lbl("", 11, UiKit.TEXT, 2, 3)
	UiKit.no_tr(_note_lbl)
	_note_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_lbl.add_theme_constant_override("line_spacing", -2)
	hb.add_child(_note_lbl)
	return _note







func _notice(text: String, kind: String, passive: bool = false) -> void :
	if _note_kind != "" and _note != null and _note.visible:
		if passive:
			if text != _note_txt and not _note_q.any( func(e: Array) -> bool: return String(e[0]) == text):
				_note_q.append([text, kind])
				if _note_q.size() > 4:
					_note_q.pop_front()
			return
		if _note_pas and text != _note_txt and _clock - _note_t0 < NOTE_MIN:
			_note_q.push_front([_note_txt, _note_kind])
	_note_show(text, kind, passive)


func _note_show(text: String, kind: String, passive: bool) -> void :
	_note_txt = text
	_note_pas = passive
	_note_t0 = _clock
	_note_kind = kind
	_note_until = _clock + NOTE_T + (2.0 if kind == "bad" else 0.0)
	note_log.append([kind, text])
	_note.add_theme_stylebox_override("panel", UiKit.sb(String(NOTE_STYLE.get(kind, "wb_panel_dark")), 8, 5))
	U.set_icon(_note_icon, String(NOTE_ICON.get(kind, "icon_trade")), 20.0)
	U.set_lbl(_note_lbl, text, UiKit.TEXT)
	_note.visible = true
	_fit_note()
	if _note_tw != null and _note_tw.is_valid():
		_note_tw.kill()
	_note.modulate = Color(1.4, 1.4, 1.4, 1.0)
	_note_tw = _note.create_tween()
	_note_tw.tween_property(_note, "modulate", Color.WHITE, 0.35)




func _fit_note() -> void :
	if _note == null or not _note.visible:
		return
	var h: float = _note.get_combined_minimum_size().y
	var top: bool = false
	var st: Control = _note.get_parent() as Control
	if page == 0 and st != null and _rows.has(sel):
		var rr: Rect2 = ((_rows[sel] as Dictionary)["pc"] as Control).get_global_rect()
		var sr: Rect2 = st.get_global_rect()
		top = rr.end.y > sr.end.y - 3.0 - h and rr.position.y < sr.end.y
	var ab: float = 0.0 if top else 1.0
	if _note.anchor_top != ab or _note.anchor_bottom != ab:
		if top:
			_note.anchor_top = 0.0
			_note.anchor_bottom = 0.0
		else:
			_note.anchor_bottom = 1.0
			_note.anchor_top = 1.0
	var ot: float = 3.0 if top else -3.0 - h
	if absf(_note.offset_top - ot) > 0.5 or absf(_note.offset_bottom - (ot + h)) > 0.5:
		_note.offset_top = ot
		_note.offset_bottom = ot + h


func _note_hide() -> void :
	_acc = {}
	if not _note_q.is_empty():
		var nx: Array = _note_q.pop_front()
		_note_show(String(nx[0]), String(nx[1]), true)
		return
	_note_kind = ""
	if _note == null or not _note.visible:
		return
	if _note_tw != null and _note_tw.is_valid():
		_note_tw.kill()
	_note_tw = _note.create_tween()
	_note_tw.tween_property(_note, "modulate:a", 0.0, 0.25)
	_note_tw.tween_callback( func() -> void :
		if _note_kind == "":
			_note.visible = false)



func _port_info() -> Array:
	var e: Economy = gw.econ
	var pf: Facility = e.ports.port_of(player)
	if pf == null:
		return [Loc.t("БЕЗ ПОРТА"), "icon_cause_port", Loc.t("Порта нет: торгуем только с соседями — грузовиками и поездами."), "warn"]
	if e.ports.blocked(player):
		return [Loc.t("ПОРТ В БЛОКАДЕ"), "icon_cause_blockade", Loc.t("Порт в блокаде: корабли не ходят — торгуем только по суше."), "bad"]
	if not e.ports.ocean(pf):
		return [Loc.t("ПОРТ БЕЗ ОКЕАНА"), "icon_cause_port", Loc.t("Из порта нет выхода в океан: за рубеж не торгуем — только соседи."), "warn"]
	return [Loc.t("ПОРТ ОТКРЫТ"), "icon_port", Loc.t("Порт открыт: импорт — цена ×1,6, экспорт — ×0,7. У соседей обычно выгоднее."), "info"]


func _fill_port() -> void :
	if _port_chip == null:
		return
	var pi: Array = _port_info()
	if _port_chip.text != String(pi[0]):
		_port_chip.text = String(pi[0])
		_port_chip.icon = U.tex(String(pi[1]))
		var col: Color = UiKit.MUTED if String(pi[3]) == "info" else SALMON
		for cn: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			_port_chip.add_theme_color_override(cn, col)
	_port_detail = [String(pi[2]), String(pi[3])]


func _eta_txt(sec: float) -> String:
	if sec < 0.0:
		return Loc.t("время неизвестно")
	if sec < 90.0:
		return Loc.f("≈ {n} с", {"n": maxi(5, roundi(sec / 5.0) * 5)})
	return Loc.f("≈ {n} мин", {"n": roundi(sec / 60.0)})




func _build_list() -> void :
	for res: String in Economy.TRADE_RES:
		_rows[res] = _row(res)



func _col_head() -> Control:
	var head: = HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	head.custom_minimum_size = Vector2(0, 30)
	var left: = HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(left)
	_port_chip = Button.new()
	_port_chip.focus_mode = Control.FOCUS_NONE
	_port_chip.custom_minimum_size = Vector2(0, 22)
	_port_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_port_chip.add_theme_font_override("font", UiKit.f_black)
	_port_chip.add_theme_font_size_override("font_size", 10)
	_port_chip.add_theme_constant_override("outline_size", 3)
	_port_chip.add_theme_color_override("font_outline_color", UiKit.OUTLINE)
	_port_chip.add_theme_constant_override("icon_max_width", 14)
	_port_chip.add_theme_constant_override("h_separation", 3)
	for stn: String in ["normal", "hover"]:
		_port_chip.add_theme_stylebox_override(stn, UiKit.sb("wb_pill", 6, 2))
	for stn2: String in ["pressed", "hover_pressed"]:
		_port_chip.add_theme_stylebox_override(stn2, UiKit.sb("wb_pill", 6, 2, 1))
	_port_chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UiKit.no_tr(_port_chip)
	_port_chip.pressed.connect( func() -> void :
		UiKit.snd("ui_tab")
		_notice(String(_port_detail[0]), String(_port_detail[1])))
	left.add_child(_port_chip)
	_port_chip.add_child(_hit_rect(_port_chip, 6.0, 9.0))
	for c: Array in [[Loc.t("ЦЕНА"), 44.0, UiKit.MUTED], [Loc.t("КУПИТЬ"), 46.0, UiKit.GREEN], [Loc.t("ПРОДАТЬ"), 50.0, UiKit.GOLD]]:
		var l: Label = UiKit.lbl(String(c[0]), 10, c[2] as Color, 2, 2)
		UiKit.no_tr(l)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if float(c[1]) > 44.0 else HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(float(c[1]), 0)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(l)
	var rp: = Control.new()
	rp.custom_minimum_size = Vector2(9, 0)
	head.add_child(rp)
	return head


func _row(res: String) -> Dictionary:
	var pc: = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 5, 2))
	pc.custom_minimum_size = Vector2(0, 44)
	_list_vb.add_child(pc)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)
	hb.add_child(_glyph(String(RS.ICON.get(res, "res_" + res))))
	var mid: = VBoxContainer.new()
	mid.add_theme_constant_override("separation", 1)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(mid)
	var top: = HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	mid.add_child(top)
	var nl: Label = UiKit.lbl(Loc.t(String(RS.SHORT.get(res, res))), 11, UiKit.TEXT, 2, 2)
	UiKit.no_tr(nl)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	top.add_child(nl)
	var al: Label = UiKit.lbl("0/0", 10, UiKit.TEXT, 2, 2)
	top.add_child(al)
	var bar = Bar.new()
	bar.custom_minimum_size = Vector2(0, 7)
	bar.min_px = 0.0
	mid.add_child(bar)
	var note: Label = UiKit.lbl("", 10, UiKit.MUTED, 2, 2)
	UiKit.no_tr(note)
	note.clip_text = true
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid.add_child(note)

	var tc: = VBoxContainer.new()
	tc.add_theme_constant_override("separation", 0)
	tc.custom_minimum_size = Vector2(44, 0)
	tc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tc)
	var sp = Spark.new()
	sp.custom_minimum_size = Vector2(44, 14)
	tc.add_child(sp)
	var pct: Label = UiKit.lbl("", 10, UiKit.MUTED, 2, 2)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tc.add_child(pct)
	var bl: Array = _price_col(hb, 46.0)
	var sl: Array = _price_col(hb, 50.0)
	var selb: = Panel.new()
	var sst: = StyleBoxFlat.new()
	sst.bg_color = Color(1.0, 0.84, 0.37, 0.07)
	sst.border_color = UiKit.GOLD
	sst.set_border_width_all(2)
	sst.expand_margin_left = 2.0
	sst.expand_margin_right = 2.0
	sst.expand_margin_top = 1.0
	sst.expand_margin_bottom = 1.0
	selb.add_theme_stylebox_override("panel", sst)
	selb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selb.visible = false
	pc.add_child(selb)
	var tap: = Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	for stn: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		tap.add_theme_stylebox_override(stn, StyleBoxEmpty.new())
	var key: String = res
	tap.pressed.connect( func() -> void :
		UiKit.snd("ui_tab")
		select(key)
		_cell_tap(key, tap.get_global_mouse_position()))
	pc.add_child(tap)
	return {"pc": pc, "sel": selb, "name": nl, "amount": al, "bar": bar, "note": note, "spark": sp, "pct": pct, 
		"buy": bl[0], "buy_lock": bl[1], "sell": sl[0], "sell_lock": sl[1]}


func _price_col(hb: HBoxContainer, w: float) -> Array:
	var box: = HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.custom_minimum_size = Vector2(w, 0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(box)
	var lk: TextureRect = U.icon("wb_lock", 12.0)
	lk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lk.visible = false
	box.add_child(lk)
	var l: Label = UiKit.lbl("—", 12, UiKit.GOLD, 2, 2)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(l)
	var cn: TextureRect = U.icon("res_money", 9.0)
	cn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(cn)
	l.set_meta("coin", cn)
	return [l, lk]



func _glyph(icon_name: String) -> Control:
	var box: = CenterContainer.new()
	box.custom_minimum_size = Vector2(28, 28)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc: = Panel.new()
	var st: = StyleBoxFlat.new()
	st.bg_color = Color("1c1d18")
	st.border_color = Color("5a5a48")
	st.set_border_width_all(1)
	st.set_corner_radius_all(13)
	disc.add_theme_stylebox_override("panel", st)
	disc.custom_minimum_size = Vector2(28, 28)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(disc)
	box.add_child(U.icon(icon_name, 20.0))
	return box


func _fill_list() -> void :
	for res: String in Economy.TRADE_RES:
		var r: Dictionary = _rows.get(res, {})
		var d: Dictionary = rows_d.get(res, {})
		if r.is_empty() or d.is_empty():
			continue
		var n: int = int(d["n"])
		var cap: int = maxi(1, int(d["cap"]))
		var need: int = int(d["need"])
		var inb: int = int(d["inb"])
		var full: bool = n + inb >= cap
		U.set_lbl(r["amount"], "%s/%s" % [U.num(n), U.num(cap)], UiKit.TEXT)
		U.set_lbl(r["name"], Loc.t(String(RS.SHORT.get(res, res))), UiKit.RED.lightened(0.15) if need > 0 else UiKit.TEXT)
		var bar = r["bar"]
		bar.fill_name = "wb_bar_red" if need > 0 else ("wb_bar_amber" if full or float(n) / float(cap) >= 0.9 else "wb_bar_green")
		bar.frac = float(n) / float(cap)
		var rate: int = int(d["rate"])
		var parts: PackedStringArray = PackedStringArray()
		var col: Color = UiKit.MUTED
		if need > 0:
			parts.append(Loc.f("нужно {n}", {"n": need}))
			col = UiKit.RED.lightened(0.2)
		elif full:
			parts.append(Loc.t("склад полон"))
			col = AMBER
		if rate != 0:
			parts.append(Loc.f("{v}/мин", {"v": U.signed(rate)}))
		if inb > 0:
			parts.append(Loc.f("в пути {n}", {"n": inb}))
		U.set_lbl(r["note"], " · ".join(parts), col)
		var tr: Dictionary = d["trend"]
		(r["spark"]).set_data(tr.get("hist", PackedFloat32Array()), int(tr.get("dir", 0)), bool(tr.get("crisis", false)))
		var pct: int = int(tr.get("pct", 0))
		U.set_lbl(r["pct"], ("%+d%%" % pct) if pct != 0 else "0%", UiKit.RED if pct >= 3 else (UiKit.GREEN if pct <= -3 else UiKit.MUTED))
		for side: String in ["buy", "sell"]:
			var sd: Dictionary = d[side]
			var ok: bool = bool(sd["ok"])
			U.set_lbl(r[side], U.num(int(sd["unit"])) if int(sd["unit"]) > 0 else "—", (UiKit.GREEN if side == "buy" else UiKit.GOLD) if ok else UiKit.DIM)
			U.set_vis(r[side + "_lock"], not ok)
			U.set_vis((r[side] as Label).get_meta("coin") as CanvasItem, ok)
		U.set_vis(r["sel"], res == sel)



func _cell_tap(res: String, at: Vector2) -> void :
	var r: Dictionary = _rows.get(res, {})
	var d: Dictionary = rows_d.get(res, {})
	if r.is_empty() or d.is_empty():
		return
	for side: String in ["buy", "sell"]:
		var box: Control = (r[side] as Label).get_parent() as Control
		if box.get_global_rect().grow_individual(4.0, 10.0, 4.0, 10.0).has_point(at) and not bool((d[side] as Dictionary)["ok"]):
			_notice(Loc.t(String((d[side] as Dictionary)["why"])), "bad")
			UiKit.snd("ui_error")
			return


func select(res: String) -> void :
	if not Economy.TRADE_RES.has(res):
		return
	sel = res
	_hold = ""
	_fill_list()
	_fill_card()
	if _card != null:
		_card.modulate = Color(1.2, 1.2, 1.2, 1.0)
		var tw: Tween = _card.create_tween()
		tw.tween_property(_card, "modulate", Color.WHITE, 0.2)




func _deal_card() -> Control:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 5))
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2 if compact else 3)
	_card.add_child(vb)

	var ra: = HBoxContainer.new()
	ra.add_theme_constant_override("separation", 4)
	vb.add_child(ra)
	_c_icon = U.icon("icon_r_metal", 24.0)
	_c_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ra.add_child(_c_icon)
	var nc: = VBoxContainer.new()
	nc.add_theme_constant_override("separation", -3)
	nc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ra.add_child(nc)
	_c_name = UiKit.lbl("", 12, UiKit.TITLE, 3, 3)
	UiKit.no_tr(_c_name)
	nc.add_child(_c_name)
	_c_stock = UiKit.lbl("", 10, UiKit.TEXT, 2, 2)
	nc.add_child(_c_stock)
	for i: int in QTY.size():
		var b: = Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(40 if i < 2 else 56, 40)
		b.add_theme_font_override("font", UiKit.f_black)
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_constant_override("outline_size", 3)
		b.add_theme_color_override("font_outline_color", UiKit.OUTLINE)
		for cname: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(cname, UiKit.TEXT)
		for s2: Array in [["normal", "wb_btn_stone_p", 1], ["hover", "wb_btn_stone_p", 1], ["pressed", "wb_btn_gold", -1], ["hover_pressed", "wb_btn_gold", -1]]:
			b.add_theme_stylebox_override(String(s2[0]), UiKit.sb(String(s2[1]), 4, 3, float(s2[2])))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		UiKit.no_tr(b)
		var idx: int = i
		b.pressed.connect( func() -> void :
			UiKit.snd("ui_tab")
			qty_i = idx
			_fill_card())
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ra.add_child(b)
		_chips.append(b)
	ra.add_child(_link("icon_inventory", Loc.t("СКЛАД"), "res:%s:"))
	ra.add_child(_link("icon_buy", Loc.t("АВТО"), "res:%s:res:-1"))

	var ri: = HBoxContainer.new()
	ri.add_theme_constant_override("separation", 4)
	ri.custom_minimum_size = Vector2(0, 16)
	vb.add_child(ri)
	_c_flow = UiKit.lbl("", 10, UiKit.MUTED, 2, 2)
	UiKit.no_tr(_c_flow)
	_c_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_c_flow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ri.add_child(_c_flow)
	_closed_btn = Button.new()
	_closed_btn.flat = true
	_closed_btn.focus_mode = Control.FOCUS_NONE
	for stn: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_closed_btn.add_theme_stylebox_override(stn, StyleBoxEmpty.new())
	_closed_btn.custom_minimum_size = Vector2(0, 40)
	_closed_btn.visible = false
	ri.add_child(_closed_btn)
	var chb: = HBoxContainer.new()
	chb.add_theme_constant_override("separation", 2)
	chb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chb.set_anchors_preset(Control.PRESET_FULL_RECT)
	_closed_btn.add_child(chb)
	_closed_lbl = UiKit.lbl(Loc.t("закрыто:"), 10, SALMON, 2, 2)
	UiKit.no_tr(_closed_lbl)
	_closed_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chb.add_child(_closed_lbl)
	for k: Array in [["war", "icon_rel_war"], ["emb", "icon_treaty_embargo"], ["sanc", "d331_sanct_16"]]:
		var ic: TextureRect = U.icon(String(k[1]), 12.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chb.add_child(ic)
		var cl: Label = UiKit.lbl("0", 10, SALMON, 2, 2)
		cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chb.add_child(cl)
		_closed_btn.set_meta(String(k[0]), [ic, cl])
	chb.minimum_size_changed.connect( func() -> void : _closed_btn.custom_minimum_size = Vector2(maxf(40.0, chb.get_combined_minimum_size().x), 40))
	_closed_btn.pressed.connect( func() -> void :
		UiKit.snd("ui_tab")
		_notice(Loc.f("Не торгуют с вами ({what}): {list}. Поэтому сделка может идти дороже — через порт или у другого соседа.", {"what": Loc.t(String(RS.SHORT.get(sel, sel))).to_lower(), "list": closed_txt}), "warn"))

	var rc: = HBoxContainer.new()
	rc.add_theme_constant_override("separation", 6)
	vb.add_child(rc)
	var cb: = VBoxContainer.new()
	cb.add_theme_constant_override("separation", 1)
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rc.add_child(cb)
	var cs: = VBoxContainer.new()
	cs.add_theme_constant_override("separation", 1)
	cs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rc.add_child(cs)
	_bbuy = _deal_btn(cb, "buy")
	_cap_buy = _caption(cb)
	_bsell = _deal_btn(cs, "sell")
	_cap_sell = _caption(cs)
	return _card




func _hit_rect(ctl: BaseButton, gx: float, gy: float) -> Button:
	var hb: = Button.new()
	hb.flat = true
	hb.focus_mode = Control.FOCUS_NONE
	for stn: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		hb.add_theme_stylebox_override(stn, StyleBoxEmpty.new())
	hb.position = Vector2( - gx, - gy)
	ctl.resized.connect( func() -> void :
		hb.position = Vector2( - gx, - gy)
		hb.size = ctl.size + Vector2(gx, gy) * 2.0)
	hb.pressed.connect( func() -> void : ctl.pressed.emit())
	return hb



func _link(icon_name: String, text: String, act: String) -> Button:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	UiKit.no_tr(b)
	b.icon = U.tex(icon_name)
	b.expand_icon = false
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_constant_override("icon_max_width", 16)
	b.add_theme_constant_override("h_separation", 0)
	b.add_theme_font_override("font", UiKit.f_black)
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_color_override("font_outline_color", UiKit.OUTLINE)
	for cname: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(cname, UiKit.TEXT)
	b.custom_minimum_size = Vector2(40, 40)
	b.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_stone", 2, 2, -1))
	b.add_theme_stylebox_override("hover", UiKit.sb("wb_btn_stone", 2, 2, -1))
	b.add_theme_stylebox_override("pressed", UiKit.sb("wb_btn_stone_p", 2, 2, 1))
	b.add_theme_stylebox_override("hover_pressed", UiKit.sb("wb_btn_stone_p", 2, 2, 1))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect( func() -> void :
		UiKit.snd("ui_tab")
		action.emit(act % sel))
	return b


func _deal_btn(parent: Control, side: String) -> Dictionary:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44 if compact else 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	var cc: = VBoxContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_theme_constant_override("separation", -2)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cc)
	var t1: Label = UiKit.lbl("", 13 if not compact else 12, UiKit.TEXT, 2, 4)
	UiKit.no_tr(t1)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cc.add_child(t1)
	var r2: = HBoxContainer.new()
	r2.alignment = BoxContainer.ALIGNMENT_CENTER
	r2.add_theme_constant_override("separation", 3)
	r2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(r2)
	var t2: Label = UiKit.lbl("", 11, UiKit.TEXT, 2, 3)
	UiKit.no_tr(t2)
	r2.add_child(t2)
	var cn: TextureRect = U.icon("res_money", 9.0)
	cn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r2.add_child(cn)
	UiKit.press_fx(b)
	b.button_down.connect( func() -> void :
		_hold = side
		_hold_t = 0.0
		_hold_n = 0
		_hold_fired = false)
	b.button_up.connect( func() -> void :
		if _hold == side:
			_hold = "")
	b.pressed.connect( func() -> void :
		if _hold_fired:
			_hold_fired = false
			return
		_order(side == "buy"))
	return {"btn": b, "t1": t1, "t2": t2, "coin": cn, "look": ""}


func _caption(parent: Control) -> Array:
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	parent.add_child(hb)
	var ic: TextureRect = U.icon("icon_cause_convoy", 14.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", -3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(col)
	var l1: Label = UiKit.lbl("", 10, UiKit.TEXT, 2, 2)
	UiKit.no_tr(l1)
	col.add_child(l1)
	var l2: Label = UiKit.lbl("", 10, UiKit.MUTED, 2, 2)
	UiKit.no_tr(l2)
	col.add_child(l2)
	return [ic, l1, l2]


func _look(bd: Dictionary, colour: String) -> void :
	if String(bd["look"]) == colour:
		return
	bd["look"] = colour
	var b: Button = bd["btn"]
	var nm: String = "wb_btn_" + colour
	b.add_theme_stylebox_override("normal", UiKit.sb(nm if colour != "stone" else "wb_btn_stone_p", 12, 4, -1 if colour != "stone" else 1))
	b.add_theme_stylebox_override("hover", UiKit.sb(nm if colour != "stone" else "wb_btn_stone_p", 12, 4, -1 if colour != "stone" else 1))
	b.add_theme_stylebox_override("pressed", UiKit.sb(nm + "_p" if colour != "stone" else "wb_btn_stone_p", 12, 4, 1))
	b.add_theme_stylebox_override("hover_pressed", UiKit.sb(nm + "_p" if colour != "stone" else "wb_btn_stone_p", 12, 4, 1))
	var dim: bool = colour == "stone"
	(bd["t1"] as Label).modulate = Color(1, 1, 1, 0.55) if dim else Color.WHITE
	(bd["coin"] as TextureRect).visible = not dim



func eff_n(sd: Dictionary) -> int:
	var q: int = QTY[qty_i]
	var mx: int = int(sd.get("max", 0))
	if q < 0:
		return maxi(mx, 0)
	return mini(q, mx) if mx > 0 else q


func _fill_card() -> void :
	var d: Dictionary = rows_d.get(sel, {})
	if d.is_empty() or _card == null:
		return
	U.set_icon(_c_icon, String(RS.ICON.get(sel, "res_" + sel)), 24.0)
	U.set_lbl(_c_name, Loc.t(String(RS.SHORT.get(sel, sel))), UiKit.TITLE)
	U.set_lbl(_c_stock, "%s/%s" % [U.num(int(d["n"])), U.num(int(d["cap"]))], UiKit.TEXT)
	var tin: int = int(d["tin"])
	var tout: int = int(d["tout"])
	var fp: PackedStringArray = PackedStringArray()
	if tin > 0:
		fp.append(Loc.f("приход {v}/мин", {"v": U.signed(tin)}))
	else:
		fp.append(Loc.t("не производится"))
	if tout > 0:
		fp.append(Loc.f("расход {v}/мин", {"v": U.signed( - tout)}))
	U.set_lbl(_c_flow, " · ".join(fp), UiKit.MUTED)
	var mx_any: int = maxi(int((d["buy"] as Dictionary)["max"]), int((d["sell"] as Dictionary)["max"]))
	for i: int in _chips.size():
		var b: Button = _chips[i]
		b.set_pressed_no_signal(i == qty_i)
		var tx: String = str(QTY[i]) if QTY[i] > 0 else (Loc.t("МАКС") + (" %d" % mx_any if mx_any > 0 and qty_i != i else ""))
		if i == qty_i and QTY[i] < 0:
			tx = Loc.t("МАКС")
		if b.text != tx:
			b.text = tx
	var cl: Dictionary = _closed(sel)
	var cp: PackedStringArray = PackedStringArray()
	if int(cl["war"]) > 0:
		cp.append(Loc.f("война {n}", {"n": cl["war"]}))
	if int(cl["emb"]) > 0:
		cp.append(Loc.f("эмбарго {n}", {"n": cl["emb"]}))
	if int(cl["sanc"]) > 0:
		cp.append(Loc.f("санкции {n}", {"n": cl["sanc"]}))
	closed_txt = " · ".join(cp)
	U.set_vis(_closed_btn, not cp.is_empty())
	for k: String in ["war", "emb", "sanc"]:
		var pr: Array = _closed_btn.get_meta(k)
		U.set_vis(pr[0], int(cl[k]) > 0)
		U.set_vis(pr[1], int(cl[k]) > 0)
		if int(cl[k]) > 0:
			U.set_lbl(pr[1], str(int(cl[k])), SALMON)
	for side: String in ["buy", "sell"]:
		var sd: Dictionary = d[side]
		var bd: Dictionary = _bbuy if side == "buy" else _bsell
		var cap: Array = _cap_buy if side == "buy" else _cap_sell
		var ok: bool = bool(sd["ok"])
		var n: int = eff_n(sd)
		var sum: int = n * int(sd["unit"])
		_look(bd, ("green" if side == "buy" else "gold") if ok else "stone")
		U.set_lbl(bd["t1"], (Loc.t("КУПИТЬ") if side == "buy" else Loc.t("ПРОДАТЬ")) + ((" %d" % n) if ok and n > 0 else ""), UiKit.TEXT)
		var ws: Array = _why_short(String(sd["why"]), sd)
		U.set_lbl(bd["t2"], (("−" if side == "buy" else "+") + U.num(sum)) if ok else String(ws[0]), UiKit.TEXT if ok else SALMON)
		var ic: TextureRect = cap[0]
		var l1: Label = cap[1]
		var l2: Label = cap[2]
		if ok:
			var mode: String = String(sd["mode"])
			U.set_icon(ic, String(MODE_ICON.get(mode, "icon_trade")), 14.0)
			var c: Country = sd["partner"] as Country
			var how: String = Loc.t(String(LOC_MODE.get(mode, "")))
			if c != null:
				U.set_lbl(l1, Loc.name(c.name), UiKit.TEXT)
				U.set_lbl(l2, how + " " + _eta_txt(float(sd["eta"])), UiKit.MUTED)
			elif mode == "export":
				U.set_lbl(l1, Loc.t("экспорт, порт"), UiKit.TEXT)

				var sp335: Dictionary = gw.econ.sale_preview(player, sel, n) if n > 0 and gw.econ.has_method("sale_preview") else {}
				if not sp335.is_empty() and int(sp335.get("drop_pct", 0)) >= 1:
					var after: int = maxi(1, roundi(float(sp335["unit_now"]) * (1.0 - float(sp335["drop_pct"]) / 100.0)))
					U.set_lbl(l2, Loc.f("цена упадёт до {u} (−{p} %)", {"u": after, "p": int(sp335["drop_pct"])}), AMBER)
					U.set_lbl(bd["t2"], "+" + U.num(int(sp335["total"])), UiKit.TEXT)
				else:
					U.set_lbl(l2, Loc.t("цена ×0,7 · кораблём"), UiKit.MUTED)
			elif mode == "queue":
				U.set_lbl(l1, Loc.t("импорт, порт"), UiKit.TEXT)
				U.set_lbl(l2, Loc.t("ждёт свободный корабль"), UiKit.MUTED)
			else:
				U.set_lbl(l1, Loc.t("импорт, порт"), UiKit.TEXT)
				U.set_lbl(l2, Loc.t("цена ×1,6 · кораблём"), UiKit.MUTED)
		else:
			U.set_icon(ic, _why_icon(Loc.src_of(String(sd["why"]))), 14.0)
			U.set_lbl(l1, String(ws[1]), SALMON)
			U.set_lbl(l2, String(ws[2]), UiKit.MUTED)



static func _why_icon(why: String) -> String:
	if why.begins_with("Склад полон"):
		return "icon_store"
	if why.begins_with("Не хватает денег"):
		return "res_money"
	if why.begins_with("Санкции"):
		return "d331_sanct_16"
	if why.begins_with("Эмбарго"):
		return "icon_treaty_embargo"
	if why.begins_with("Война"):
		return "icon_rel_war"
	if why.contains("блокаде"):
		return "icon_cause_blockade"
	if why.contains("нет порта") or why.contains("в океан"):
		return "icon_cause_port"
	if why.begins_with("Продавать нечего"):
		return "icon_inventory"
	return "wb_lock"




func _why_short(why: String, sd: Dictionary) -> Array:
	var tail: String = Loc.t("а порта нет") if why.contains("нет порта") else (Loc.t("порт в блокаде") if why.contains("блокаде") else Loc.t("порт без океана"))
	if why.begins_with("Склад полон"):
		return [Loc.t("склад полон"), Loc.t("места нет"), Loc.t("постройте склад")]
	if why.begins_with("Не хватает денег"):
		return [Loc.t("мало денег"), Loc.f("цена {u} за ед.", {"u": U.num(int(sd.get("unit", 0)))}), Loc.f("у вас {m}", {"m": U.num(player.money)})]
	if why.begins_with("Купить не у кого"):
		return [Loc.t("нет у соседей"), Loc.t("у соседей нет лишнего"), tail]
	if why.begins_with("Продать некому"):
		return [Loc.t("никому не нужно"), Loc.t("соседи не покупают"), tail]
	if why.begins_with("Продавать нечего"):
		return [Loc.t("склад пуст"), Loc.t("продавать нечего"), Loc.t("добудьте или купите")]
	if why.begins_with("Очередь импорта"):
		return [Loc.t("очередь полна"), Loc.t("импорт ждёт кораблей"), Loc.t("нужен кран в порту")]
	if why.begins_with("Все причалы"):
		return [Loc.t("причалы заняты"), Loc.t("все корабли в пути"), Loc.t("подождите")]
	if why.begins_with("Санкции"):
		return [Loc.t("санкции"), Loc.t("сделка под запретом"), Loc.t("тап — подробно")]
	if why.begins_with("Нет столицы"):
		return [Loc.t("нет столицы"), "", ""]
	return [Loc.t("нельзя"), Loc.t("тап — почему"), ""]




func _hold_tick(delta: float) -> void :
	if _hold == "":
		return
	var bd: Dictionary = _bbuy if _hold == "buy" else _bsell
	var b: Button = bd.get("btn")
	var mn8: Node = hud.main_node.get("menus") if hud.main_node != null else null
	if b == null or not b.is_pressed() or (mn8 != null and mn8.is_open()):
		_hold = ""
		return
	_hold_t += delta
	if _pending or _hold_t < HOLD_FIRST + float(_hold_n) * HOLD_STEP:
		return
	_hold_n += 1
	_hold_fired = true
	if not _order(_hold == "buy"):
		_hold = ""



func _order(buying: bool) -> bool:
	var d: Dictionary = rows_d.get(sel, {})
	if d.is_empty():
		return false
	var sd: Dictionary = d["buy" if buying else "sell"]
	if not bool(sd["ok"]):
		_notice(Loc.t(String(sd["why"])), "bad")
		UiKit.snd("ui_error")
		return false
	if _pending:
		return false
	var n: int = eff_n(sd)
	if n <= 0:
		return false
	var res: String = sel
	var partner: Country = sd["partner"] as Country
	_pending = true
	_pending_ms = Time.get_ticks_msec()
	orders += 1
	NetSession.sim("econ", "market_order", [player, partner, res, n, buying], func(r: Variant) -> void :
		if is_instance_valid(self):
			_on_result(r, buying, res))
	return true


func _on_result(r: Variant, buying: bool, res: String) -> void :
	_pending = false
	var why: String = Loc.t("Команда не выполнена") if r == null else (String(r) if r is String else "")
	if why != "":
		_hold = ""
		_notice(Loc.t("Не вышло: ") + Loc.t(why), "bad")
		UiKit.snd("ui_error")
		refresh()
		return
	var ld: Dictionary = gw.econ.last_deal
	var n: int = int(ld.get("n", 0))
	var price: int = int(ld.get("price", 0))
	var mode: String = String(ld.get("mode", ""))
	var now: int = Time.get_ticks_msec()
	var side: String = "buy" if buying else "sell"
	if not _acc.is_empty() and String(_acc["side"]) == side and String(_acc["res"]) == res and String(_acc["who"]) == String(ld.get("partner", ""))\
	and String(_acc["mode"]) == String(ld.get("mode", "")) and now - int(_acc["ms"]) < 2500 and _note_kind == "ok":
		_acc["n"] = int(_acc["n"]) + n
		_acc["price"] = int(_acc["price"]) + price
		_acc["k"] = int(_acc["k"]) + 1
	else:
		_acc = {"side": side, "res": res, "n": n, "price": price, "k": 1, "who": String(ld.get("partner", "")), "mode": String(ld.get("mode", ""))}
	_acc["ms"] = now
	var rn: String = Loc.t(String(RS.GEN.get(res, res)))
	var how: String = Loc.t(String(LOC_MODE.get(mode, "")))
	var who: String = String(ld.get("partner", ""))
	var eta: String = _eta_txt(float(ld.get("eta", -1.0)))
	var txt: String = ""
	var tn: int = int(_acc["n"])
	var tp: int = int(_acc["price"])
	if buying:
		if mode == "queue":
			txt = Loc.f("Куплено {n} {res} за {sum} · оплачено, ждёт корабль в порту", {"n": tn, "res": rn, "sum": U.num(tp)})
		elif mode == "import":
			txt = Loc.f("Куплено {n} {res} за {sum} · импорт, едет {how} {eta}", {"n": tn, "res": rn, "sum": U.num(tp), "how": how, "eta": eta})
		else:
			txt = Loc.f("Куплено {n} {res} за {sum} · {who}, едет {how} {eta}", {"n": tn, "res": rn, "sum": U.num(tp), "who": Loc.name(who), "how": how, "eta": eta})
	else:
		if mode == "export":
			txt = Loc.f("Продано {n} {res} за рубеж · {sum} при доставке, {eta}", {"n": tn, "res": rn, "sum": U.num(tp), "eta": eta})
		else:
			txt = Loc.f("Продано {n} {res} · {who} заплатит {sum} при доставке, {how} {eta}", {"n": tn, "res": rn, "sum": U.num(tp), "who": Loc.name(who), "how": how, "eta": eta})
	if int(_acc["k"]) > 1:
		txt += " " + Loc.f("(×{k})", {"k": _acc["k"]})
	if ld.is_empty():
		txt = Loc.t("Сделка оформлена")
	_notice(txt, "ok")
	UiKit.snd("ui_money")
	refresh()
	var rr: Dictionary = _rows.get(res, {})
	if not rr.is_empty():
		var pc: Control = rr["pc"]
		pc.modulate = Color(1.3, 1.45, 1.2, 1.0) if buying else Color(1.45, 1.35, 1.1, 1.0)
		var tw: Tween = pc.create_tween()
		tw.tween_property(pc, "modulate", Color.WHITE, 0.45)




func _fill_transit() -> void :
	var sig: String = ""
	for it: Dictionary in transit:
		sig += String(it["key"]) + ";"
	if sig != _tr_sig and not (page == 1 and bool(hud.call("_finger_down"))):
		_tr_sig = sig
		_build_transit()
	for i: int in mini(_tr_rows.size(), transit.size()):
		var it2: Dictionary = transit[i]
		var r: Dictionary = _tr_rows[i]
		U.set_lbl(r["eta"], _eta_txt(float(it2["eta"])) if float(it2["eta"]) >= 0.0 else Loc.t("ждёт"), UiKit.TEXT)
		(r["bar"]).frac = float(it2["frac"])


func _build_transit() -> void :
	for ch: Node in _tr_vb.get_children():
		ch.queue_free()
	_tr_rows.clear()
	if transit.is_empty():
		var pc: = PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 8))
		_tr_vb.add_child(pc)
		var hb: = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		pc.add_child(hb)
		var ic: TextureRect = U.icon("icon_cause_convoy", 24.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(ic)
		var l: Label = UiKit.lbl(Loc.t("Сейчас ничего не едет. Купите или продайте на вкладке РЫНОК — поставка появится здесь со временем прибытия."), 10, UiKit.MUTED, 2, 2)
		UiKit.no_tr(l)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		return
	for it: Dictionary in transit:
		var pc2: = PanelContainer.new()
		pc2.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 5, 3))
		pc2.custom_minimum_size = Vector2(0, 44)
		_tr_vb.add_child(pc2)
		var hb2: = HBoxContainer.new()
		hb2.add_theme_constant_override("separation", 5)
		pc2.add_child(hb2)
		var mi: TextureRect = U.icon(String(MODE_ICON.get(String(it["mode"]), "icon_trade")), 24.0)
		mi.custom_minimum_size = Vector2(28, 24)
		mi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb2.add_child(mi)
		var col: = VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb2.add_child(col)
		var top: = HBoxContainer.new()
		top.add_theme_constant_override("separation", 4)
		col.add_child(top)
		var ri: TextureRect = U.icon(String(RS.ICON.get(String(it["res"]), "res_metal")), 14.0)
		ri.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(ri)
		var tl: Label = UiKit.lbl("%s ×%d" % [Loc.t(String(RS.SHORT.get(String(it["res"]), it["res"]))), int(it["n"])], 11, UiKit.TEXT, 2, 2)
		UiKit.no_tr(tl)
		top.add_child(tl)
		var kd: String = String(it["kind"])
		var tag: Label = UiKit.lbl(Loc.t(String(LOC_KIND.get(kd, ""))), 9, KIND_COL.get(kd, UiKit.MUTED) as Color, 2, 2)
		UiKit.no_tr(tag)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(tag)
		var sub: String = ""
		var how: String = Loc.t(String(LOC_MODE.get(String(it["mode"]), "")))
		var pr: String = U.num(int(it["price"]))
		match kd:
			"buy", "in", "aid":
				sub = Loc.f("из: {who} · {how} · оплачено {sum}", {"who": it["other"], "how": how, "sum": pr})
				if kd == "aid":
					sub = Loc.f("из: {who} · {how}", {"who": it["other"], "how": how})
			"sell", "out":
				sub = Loc.f("в: {who} · {how} · {sum} при доставке", {"who": it["other"], "how": how, "sum": pr})
			"import":
				sub = Loc.f("из-за рубежа · кораблём · оплачено {sum}", {"sum": pr})
			"queue":
				sub = Loc.f("оплачено {sum} · ждёт свободный корабль", {"sum": pr})
			"export":
				sub = Loc.f("за рубеж · кораблём · ≈ {sum} при доставке", {"sum": pr})
		var sl: Label = UiKit.lbl(sub, 10, UiKit.MUTED, 2, 2)
		UiKit.no_tr(sl)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(sl)
		var rc: = VBoxContainer.new()
		rc.add_theme_constant_override("separation", 2)
		rc.custom_minimum_size = Vector2(62, 0)
		rc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb2.add_child(rc)
		var el: Label = UiKit.lbl("", 11, UiKit.TEXT, 2, 2)
		UiKit.no_tr(el)
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rc.add_child(el)
		var bar = Bar.new()
		bar.custom_minimum_size = Vector2(62, 6)
		bar.min_px = 2.0
		bar.fill_name = "wb_bar_blue" if bool(it["inc"]) else "wb_bar_amber"
		rc.add_child(bar)
		_tr_rows.append({"eta": el, "bar": bar})




func _partner_state(c: Country) -> String:
	var e: Economy = gw.econ
	if gw.diplo.at_war(player.id, c.id):
		return "war"
	if gw.diplo.embargo_between(player.id, c.id):
		return "emb"
	if e.trading(player.id, c.id):
		return "on"
	if not e.can_reach(player, c):
		return "noway"
	return "off"


func _fill_partners() -> void :
	var e: Economy = gw.econ
	var sig: String = ""
	for rq: Dictionary in e.requests_for(player.id):
		sig += "q%d;" % int(rq["id"])
	var list: Array = []
	for c: Country in gw.countries:
		if c == player or c.eliminated or c.capital_id < 0:
			continue
		var st: String = _partner_state(c)
		list.append([c, st])
		sig += "%d:%s;" % [c.id, st]
	if sig != _pt_sig and not (page == 2 and bool(hud.call("_finger_down"))):
		_pt_sig = sig
		_build_partners(list)
	for cid: int in _pt_spare:
		var c2: Country = gw.country_by_id(cid)
		var hb: HBoxContainer = _pt_spare[cid]
		if c2 == null or not is_instance_valid(hb):
			continue
		_fill_spare(hb, c2)


func _build_partners(list: Array) -> void :
	for ch: Node in _pt_vb.get_children():
		ch.queue_free()
	_pt_spare.clear()
	var e: Economy = gw.econ
	if not e.requests_for(player.id).is_empty():
		_pt_vb.add_child(_section(Loc.t("ПРОСЯТ У ВАС")))
		for rq: Dictionary in e.requests_for(player.id):
			var oc: Country = gw.country_by_id(int(rq["from"]))
			if oc == null:
				continue
			var hb: HBoxContainer = _prow()
			hb.add_child(hud.call("_flag", oc) as Control)
			var res: String = String(rq["res"])
			var l: Label = UiKit.lbl(Loc.f("{who} просит {res} ×{n} по {unit} — итого {sum}", {"who": Loc.name(oc.name), "res": Loc.t(String(RS.SHORT.get(res, res))).to_lower(), "n": int(rq["n"]), "unit": int(rq["price"]), "sum": U.num(int(rq["price"]) * int(rq["n"]))}), 10, UiKit.TEXT, 2, 2)
			UiKit.no_tr(l)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hb.add_child(l)
			var rid: int = int(rq["id"])
			var okb: Button = UiKit.big(Loc.t("ПРОДАТЬ"), "green", "", 40.0, 10)
			UiKit.no_tr(okb)
			okb.disabled = int(player.get(res)) <= 0
			okb.pressed.connect( func() -> void : _answer(rid, true))
			hb.add_child(okb)
			var nob: Button = UiKit.big(Loc.t("НЕТ"), "red", "", 40.0, 10)
			UiKit.no_tr(nob)
			nob.custom_minimum_size.x = 48
			nob.pressed.connect( func() -> void : _answer(rid, false))
			hb.add_child(nob)
	_pt_vb.add_child(_section(Loc.t("ТОРГОВЫЕ ДОГОВОРЫ")))
	var sub0: Label = UiKit.lbl(Loc.t("Излишки сами уходят соседу, которому не хватает."), 9, UiKit.MUTED, 2, 2)
	UiKit.no_tr(sub0)
	sub0.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pt_vb.add_child(sub0)
	list.sort_custom( func(a: Array, b: Array) -> bool:
		var oa: int = ["on", "off", "noway", "emb", "war"].find(String(a[1]))
		var ob: int = ["on", "off", "noway", "emb", "war"].find(String(b[1]))
		if oa != ob:
			return oa < ob
		return (a[0] as Country).id < (b[0] as Country).id)
	if list.is_empty():
		var el: Label = UiKit.lbl(Loc.t("Других стран нет."), 10, UiKit.MUTED, 2, 2)
		_pt_vb.add_child(el)
	for it: Array in list:
		var c: Country = it[0]
		var st: String = String(it[1])
		var hb2: HBoxContainer = _prow()
		hb2.add_child(hud.call("_flag", c) as Control)
		var col: = VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb2.add_child(col)
		var top: = HBoxContainer.new()
		top.add_theme_constant_override("separation", 4)
		col.add_child(top)
		var nl: Label = UiKit.name_lbl(c.name, 11, UiKit.TEXT, 2, 2)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nl)
		if st == "on" or st == "off":
			var rt: Array = _route(player, c)
			var mi: TextureRect = U.icon(String(MODE_ICON.get(String(rt[0]), "icon_trade")), 14.0)
			mi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			mi.tooltip_text = Loc.t(String(LOC_MODE.get(String(rt[0]), "")))
			top.add_child(mi)
		var sp: = HBoxContainer.new()
		sp.add_theme_constant_override("separation", 3)
		col.add_child(sp)
		_pt_spare[c.id] = sp
		_fill_spare(sp, c)
		var cid: int = c.id
		match st:
			"on":
				var b: Button = UiKit.big(Loc.t("ВЫКЛ"), "stone", "icon_ok", 40.0, 10)
				UiKit.no_tr(b)
				b.pressed.connect( func() -> void : _treaty(cid, false))
				hb2.add_child(b)
			"off":
				var b2: Button = UiKit.big(Loc.t("ДОГОВОР"), "green", "", 40.0, 10)
				UiKit.no_tr(b2)
				b2.pressed.connect( func() -> void : _treaty(cid, true))
				hb2.add_child(b2)
			_:
				var chip: Label = UiKit.lbl({"war": Loc.t("ВОЙНА"), "emb": Loc.t("ЭМБАРГО"), "noway": Loc.t("НЕТ ПУТИ")}.get(st, ""), 10, Color("ffb39c"), 2, 2)
				UiKit.no_tr(chip)
				chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				hb2.add_child(chip)
	var tl: Label = UiKit.lbl(Loc.f("Доход от торговли за партию: {n}", {"n": U.num(player.trade_income)}), 10, UiKit.MUTED, 2, 2)
	UiKit.no_tr(tl)
	_pt_vb.add_child(tl)


func _fill_spare(hb: HBoxContainer, c: Country) -> void :
	var e: Economy = gw.econ
	var have: Array = []
	for res: String in Economy.TRADE_RES:
		var s: int = e.surplus(c, res)
		if s >= 10:
			have.append([res, s])
	have.sort_custom( func(a: Array, b: Array) -> bool: return int(a[1]) * e.market_price(String(a[0])) > int(b[1]) * e.market_price(String(b[0])))
	var sig: String = ""
	for i: int in mini(3, have.size()):
		sig += "%s%d;" % [have[i][0], int(have[i][1]) / 10]
	if hb.has_meta("sig") and String(hb.get_meta("sig")) == sig:
		return
	hb.set_meta("sig", sig)
	for ch: Node in hb.get_children():
		ch.queue_free()
	if have.is_empty():
		var l: Label = UiKit.lbl(Loc.t("лишнего нет"), 9, UiKit.DIM, 2, 2)
		hb.add_child(l)
		return
	hb.add_child(UiKit.lbl(Loc.t("лишнее:"), 9, UiKit.MUTED, 2, 2))
	for i2: int in mini(3, have.size()):
		var ic: TextureRect = U.icon(String(RS.ICON.get(String(have[i2][0]), "res_metal")), 12.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(ic)
		hb.add_child(UiKit.lbl(str(int(have[i2][1])), 9, UiKit.TEXT, 2, 2))


func _section(text: String) -> Label:
	var l: Label = UiKit.lbl(text, 10, UiKit.TITLE, 2, 2)
	UiKit.no_tr(l)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _prow() -> HBoxContainer:
	var pc: = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 6, 3))
	pc.custom_minimum_size = Vector2(0, 46)
	_pt_vb.add_child(pc)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	pc.add_child(hb)
	return hb



func _treaty(cid: int, on: bool) -> void :
	var dp: Diplomacy = gw.diplo
	var use_dp: bool = dp.has_method("propose_treaty")
	var m: String = ("propose_treaty" if on else "cancel_treaty") if use_dp else "set_trade"
	var args: Array = [player.id, cid, "trade"] if use_dp else [player.id, cid, on]
	var c: Country = gw.country_by_id(cid)
	var nm: String = Loc.name(c.name) if c != null else ""
	NetSession.sim("diplo" if use_dp else "econ", m, args, func(r: Variant) -> void :
		if not is_instance_valid(self):
			return
		var why: String = Loc.t("Команда не выполнена") if r == null else (String(r) if r is String else "")
		if why == "Предложение отправлено" or why == Loc.t("Предложение отправлено"):
			_notice(Loc.f("{who}: предложение договора отправлено", {"who": nm}), "info")
		elif why != "":
			_notice(Loc.f("{who}: {why}", {"who": nm, "why": Loc.t(why)}), "bad")
			UiKit.snd("ui_error")
		elif on:
			_notice(Loc.f("Договор с {who}: излишки пойдут сами", {"who": nm}), "ok")
		else:
			_notice(Loc.f("Договор с {who} выключен", {"who": nm}), "warn")
		_pt_sig = ""
		refresh())



func _answer(rid: int, yes: bool) -> void :
	if yes:
		NetSession.sim("econ", "accept_request", [player, rid], func(r: Variant) -> void :
			if not is_instance_valid(self):
				return
			var why: String = Loc.t("Команда не выполнена") if r == null else (String(r) if r is String else "")
			if why != "":
				_notice(Loc.t("Не вышло: ") + Loc.t(why), "bad")
				UiKit.snd("ui_error")
			else:
				_notice(Loc.t("Продано по просьбе — оплата при доставке"), "ok")
				UiKit.snd("ui_money")
			_pt_sig = ""
			refresh())
	else:
		NetSession.sim("econ", "decline_request", [player, rid], func(_r: Variant) -> void :
			if is_instance_valid(self):
				_pt_sig = ""
				refresh())
