extends Control












const U = preload("res://ui/ui24/econ_kit.gd")
const URGENT_COL: = Color("ff8a7a")

var hud: Node
var main: Node
var gw: GameWorld
var panel: PanelContainer
var vb: VBoxContainer
var sc: ScrollContainer
var body: VBoxContainer
var req_box: VBoxContainer
var log_box: VBoxContainer
var sub_lbl: Label
var _log_sig: String = ""
var _ago: Array = []
var _sig: String = ""
var _timers: Array = []
var _t: float = 0.0


func mount(h: Node) -> void :
	hud = h
	main = h.main_node
	gw = h.gw
	name = "InboxSheet"
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.root.add_child(self)
	process_priority = 102
	visible = false
	panel = PanelContainer.new()
	var psb: StyleBox = UiKit.sb("wb_window", 8, 6)
	psb.content_margin_bottom = 6.0 + h._safe_margins().y
	panel.add_theme_stylebox_override("panel", psb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	vb.add_child(hr)
	var ic: TextureRect = U.icon("icon_dip_pending", 28.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(ic)
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tv)
	tv.add_child(UiKit.lbl("ВХОДЯЩИЕ", 17, UiKit.TITLE, 3, 4))
	sub_lbl = UiKit.lbl("", 9, UiKit.MUTED, 1, 2)
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.max_lines_visible = 2
	sub_lbl.add_theme_constant_override("line_spacing", -2)
	tv.add_child(sub_lbl)
	var x: Button = UiKit.close_btn(44.0)
	x.pressed.connect( func() -> void :
		UiKit.snd("ui_close")
		close())
	hr.add_child(x)
	sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sc)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	req_box = VBoxContainer.new()
	req_box.add_theme_constant_override("separation", 5)
	body.add_child(req_box)
	log_box = VBoxContainer.new()
	log_box.add_theme_constant_override("separation", 3)
	body.add_child(log_box)
	var tr: Control = h.tab_row
	var par: Node = tr.get_parent() if tr != null else h.holder
	par.add_child(panel)
	if tr != null and tr.get_parent() == par:
		par.move_child(panel, tr.get_index() + 1)


func is_open() -> bool:
	return visible and panel.visible


func open() -> void :
	if gw.player == null or gw.player.eliminated:
		return
	visible = true
	hud.ui24_open(self)
	panel.visible = true
	var vp: Vector2 = get_viewport_rect().size
	var tab_h: float = hud.tab_row.size.y if hud.tab_row != null else 52.0
	panel.custom_minimum_size = Vector2(0, floorf(vp.y * (0.66 if vp.y < 700.0 else 0.58)) - tab_h)
	_sig = "-"
	_log_sig = ""
	_rebuild()
	sc.scroll_vertical = 0
	var ln: Variant = hud.get("lane")
	if ln is Node and is_instance_valid(ln):
		(ln as Node).call("mark_read")
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.12)
	UiKit.snd("ui_open")


func close() -> void :
	if not visible:
		return
	visible = false
	panel.visible = false
	hud.ui24_closed(self)


func scroll_area() -> ScrollContainer:
	return sc if is_open() else null


func blocked_rects() -> Array:
	return [panel.get_global_rect().grow(2.0)] if is_open() else []


static func _urgent(it: Dictionary) -> bool:
	var k: String = String(it.get("kind", ""))
	return k == "demand" or k == "surrender" or k == "conference" or (k == "react" and int(it.get("stage", 0)) >= 2)


func _items() -> Array:
	var out: Array = []
	if gw.diplo == null or gw.player == null:
		return out
	out = gw.diplo.pending_for_player()
	out.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		var ua: bool = _urgent(a)
		var ub: bool = _urgent(b)
		if ua != ub:
			return ua
		return float(a["deadline"]) < float(b["deadline"]))
	return out




static func _key(it: Dictionary) -> String:
	var k: String = String(it.get("kind", ""))
	var t: String = Loc.src(it.get("text", ""))
	if k == "trade" and t.contains(" просит "):
		return "trade|" + t.get_slice(" просит ", 1).get_slice(" ×", 0)
	if (k == "offer" or k == "treaty") and t.contains("предлагает: "):
		return k + "|" + t.get_slice("предлагает: ", 1).get_slice(".", 0)
	if k == "call":
		return "call"
	return ""


static func _group_title(key: String, n: int) -> String:
	var who: String = "%d %s" % [n, Loc.t("страны") if n % 10 in [2, 3, 4] and not (n % 100 in [12, 13, 14]) else Loc.t("стран")]
	var what: String = key.get_slice("|", 1)
	match key.get_slice("|", 0):
		"trade":
			return Loc.t("%s просят %s") % [who, what]
		"offer", "treaty":
			return Loc.t("%s предлагают: %s") % [who, what.to_lower()]
		"call":
			return Loc.t("%s зовут в войну") % who
	return who


func _rebuild() -> void :
	_rebuild_log()
	var items: Array = _items()
	var sig: String = ""
	for it: Dictionary in items:
		sig += String(it["id"]) + ","
	if sig == _sig:
		return
	_sig = sig
	var keep: int = sc.scroll_vertical
	for c: Node in req_box.get_children():
		req_box.remove_child(c)
		c.queue_free()
	_timers.clear()
	var nu: int = 0
	var nx: int = 0
	for it: Dictionary in items:
		if _urgent(it):
			nu += 1
		if float(it.get("deadline", 0.0)) >= 0.0:
			nx += 1
	var exp_t: String = "" if nx == 0 else (Loc.t(" · без ответа — истекут") if nx == items.size() else Loc.t(" · истекут: %d") % nx)
	sub_lbl.text = ((Loc.n(items.size(), "%d ждёт ответа", "%d ждут ответа", "%d ждут ответа") % items.size()) if not items.is_empty() else Loc.t("Запросов нет")) + (Loc.t(" · срочных %d") % nu if nu > 0 else "") + exp_t
	if items.is_empty():
		var e: Label = UiKit.lbl("Все запросы отвечены. Новые придут сюда, а не в ленту наверху.", 10, UiKit.MUTED, 1, 2)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		req_box.add_child(e)

	var groups: Dictionary = {}
	for it2: Dictionary in items:
		var k: String = _key(it2)
		if k != "":
			groups[k] = int(groups.get(k, 0)) + 1
	var done_g: Dictionary = {}
	for it3: Dictionary in items:
		var k3: String = _key(it3)
		if k3 != "" and int(groups[k3]) >= 2:
			if done_g.has(k3):
				continue
			done_g[k3] = true
			var members: Array = items.filter( func(x: Dictionary) -> bool: return _key(x) == k3)
			req_box.add_child(_group_head(k3, members))
			for mm: Dictionary in members:
				req_box.add_child(_row(mm, true))
		else:
			req_box.add_child(_row(it3, false))
	sc.set_deferred("scroll_vertical", keep)


static func _ago_text(ago: float) -> String:
	return Loc.t("%d с") % int(ago) if ago < 60.0 else Loc.t("%d мин") % int(ago / 60.0)




const LOG_ROWS: int = 25
var _log_t: float = -1.0


func _rebuild_log() -> void :
	var jl: Array = []
	var ln: Variant = hud.get("lane")
	if ln is Node and is_instance_valid(ln):
		var jv: Variant = (ln as Node).get("journal")
		jl = jv if jv is Array else []
	if jl.is_empty():
		return
	var newest: float = float(jl[jl.size() - 1]["t"])
	var lsig: String = "%d|%s|%.3f" % [jl.size(), String(jl[jl.size() - 1]["text"]), newest]
	if lsig == _log_sig:
		return
	_log_sig = lsig
	var now: float = float((ln as Node).get("clock"))
	if log_box.get_child_count() == 0:
		var jh: = HBoxContainer.new()
		jh.add_theme_constant_override("separation", 6)
		log_box.add_child(jh)
		jh.add_child(U.icon("icon_hint", 16.0))
		jh.add_child(UiKit.lbl("ЖУРНАЛ", 12, UiKit.TITLE, 2, 3))
		_log_t = -1.0

	var fresh: Array = []
	for i: int in range(jl.size() - 1, -1, -1):
		if float(jl[i]["t"]) <= _log_t or fresh.size() >= LOG_ROWS:
			break
		fresh.push_front(jl[i])
	for j: Dictionary in fresh:
		var line: = HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		log_box.add_child(line)
		log_box.move_child(line, 1)
		var al: Label = UiKit.lbl(_ago_text(maxf(0.0, now - float(j["t"]))), 10, UiKit.MUTED, 1, 2)
		al.custom_minimum_size.x = 38
		_ago.append([al, float(j["t"])])
		line.add_child(al)
		var lvl: int = int(j["lvl"])
		var tl: Label = UiKit.lbl(String(j["text"]), 10, URGENT_COL if lvl == 0 else (UiKit.TEXT if lvl == 1 else UiKit.MUTED), 1, 2)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.max_lines_visible = 2
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(tl)
		_log_t = maxf(_log_t, float(j["t"]))
	while log_box.get_child_count() > LOG_ROWS + 1:
		var last: Node = log_box.get_child(log_box.get_child_count() - 1)
		log_box.remove_child(last)
		last.queue_free()
	for k: int in range(_ago.size() - 1, -1, -1):
		if not is_instance_valid(_ago[k][0]) or not (_ago[k][0] as Node).is_inside_tree():
			_ago.remove_at(k)


func _group_head(key: String, members: Array) -> Control:
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 5))
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var t: Label = UiKit.lbl(_group_title(key, members.size()).to_upper(), 11, UiKit.GOLD, 2, 3)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	v.add_child(hb)
	var opts: Array = (members[0] as Dictionary).get("options", [])
	var yes_act: String = String((opts[0] as Dictionary)["act"]) if not opts.is_empty() else "accept"
	var yes: Button = UiKit.big("ВСЕМ ДА", "green", "", 44.0, 11)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect( func() -> void : _answer_all(members, yes_act))
	hb.add_child(yes)
	var no: Button = UiKit.big("ВСЕМ НЕТ", "red", "", 44.0, 11)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect( func() -> void : _answer_all(members, "refuse"))
	hb.add_child(no)
	return p


func _row(it: Dictionary, in_group: bool) -> Control:
	var p: = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 5))
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var h1: = HBoxContainer.new()
	h1.add_theme_constant_override("separation", 6)
	v.add_child(h1)
	var ic: TextureRect = U.icon(String(it.get("icon", "icon_dip_pending")), 20.0, "icon_dip_pending")
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h1.add_child(ic)
	var urgent: bool = _urgent(it)
	var txt: String = String(it.get("lane_title", "")) + " · " + String(it.get("lane_sub", "")) if it.has("lane_title") else String(it.get("text", ""))
	var tl: Label = UiKit.lbl(txt, 10, URGENT_COL if urgent else UiKit.TEXT, 2 if urgent else 1, 2)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.max_lines_visible = 3
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h1.add_child(tl)
	var tm: Label = UiKit.lbl(U.mmss(float(it.get("left", 0.0))) if float(it.get("left", 0.0)) >= 0.0 else "∞", 12, UiKit.GOLD, 2, 3)
	tm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h1.add_child(tm)
	_timers.append([tm, float(it.get("deadline", 0.0))])
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	v.add_child(hb)
	var opts: Array = it.get("options", [])
	if opts.is_empty():
		opts = [{"act": "open", "label": "ОТКРЫТЬ"}]
	for i: int in opts.size():
		var o: Dictionary = opts[i]
		var act: String = String(o["act"])
		var col: String = "green" if i == 0 else ("red" if act == "refuse" else "stone")
		var b: Button = UiKit.big(String(o["label"]), col, "", 44.0, 10 if opts.size() > 2 else 11)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect( func() -> void : _answer(it, act))
		hb.add_child(b)
	if in_group:
		p.self_modulate = Color(0.92, 0.92, 0.92)
	return p


func _answer(it: Dictionary, act: String) -> void :
	var id: String = String(it["id"])
	if act == "open" or String(it.get("kind", "")) == "conference":
		var cs: Script = load("res://ui/ui24/conference_sheet.gd") as Script
		if cs != null and bool(cs.call("open_for", main, int(id.substr(1)))):
			return
		hud.set("dip_open", int(it.get("from", -1)))
		hud.call("open_diplomacy")
		return
	NetSession.sim("diplo", "answer_as", [gw.player.id, id, act], func(r: Variant) -> void :
		if not is_instance_valid(self):
			return
		var why: String = Loc.t("Команда не выполнена") if r == null else (String(r) if r is String else "")
		if why != "":
			hud.show_toast(why)
			return
		hud.show_toast(String({"accept": "Принято", "stop": "Обещание дано", "pay": "Компенсация выплачена", "join": "Вступаем в войну", "aid": "Помощь отправлена", "ok": "Принято к сведению"}.get(act, "Отказано")))
		_sig = "-"
		_rebuild())


func _answer_all(members: Array, act: String) -> void :

	var st: Dictionary = {"ok": 0, "left": members.size(), "why": ""}
	for it: Dictionary in members:
		NetSession.sim("diplo", "answer_as", [gw.player.id, String(it["id"]), act], func(r: Variant) -> void :
			var why: String = Loc.t("Команда не выполнена") if r == null else (String(r) if r is String else "")
			if why == "":
				st["ok"] = int(st["ok"]) + 1
			else:
				st["why"] = why
			st["left"] = int(st["left"]) - 1
			if int(st["left"]) > 0 or not is_instance_valid(self):
				return
			hud.show_toast(("%s: %d" % [Loc.t("Принято") if act != "refuse" else Loc.t("Отказано"), int(st["ok"])]) + (" · " + String(st["why"]) if String(st["why"]) != "" else ""))
			_sig = "-"
			_rebuild())


func _process(delta: float) -> void :
	if not visible:
		return
	if gw.player == null or gw.player.eliminated:
		close()
		return
	if (hud.panel != null and is_instance_valid(hud.panel)) or (hud.ops_panel != null and hud.ops_panel.visible):
		close()
		return
	for e: Variant in hud.cmd_btns:
		var cb: Control = (e as Array)[0]
		if cb != null and cb.visible:
			cb.visible = false
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var now: float = gw.game_time
	for tr: Array in _timers:
		var l: Label = tr[0]
		if is_instance_valid(l):
			var s: String = U.mmss(maxf(0.0, float(tr[1]) - now)) if float(tr[1]) >= 0.0 else "∞"
			if l.text != s:
				l.text = s
	var ln: Variant = hud.get("lane")
	if ln is Node and is_instance_valid(ln):
		var lc: float = float((ln as Node).get("clock"))
		for a: Array in _ago:
			var al: Label = a[0]
			if is_instance_valid(al):
				var s2: String = _ago_text(maxf(0.0, lc - float(a[1])))
				if al.text != s2:
					al.text = s2
	if not hud._finger_down():
		_rebuild()
