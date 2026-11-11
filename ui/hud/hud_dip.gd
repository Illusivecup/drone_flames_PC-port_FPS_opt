extends "res://ui/hud/hud_econ.gd"


func open_diplomacy() -> void :
	if gw == null or gw.player == null or gw.diplo == null:
		return
	if panel_kind == "ultimatum" and int(ult.get("to", -1)) >= 0:
		dip_open = int(ult["to"])
		ult = {}
	var cur: Control = panel if panel_kind == "diplomacy" and panel != null and is_instance_valid(panel) and panel.has_method("refresh") else null
	if cur != null and not bool(cur.get("_closing")):
		if dip_open >= 0 and dip_open != int(cur.get("page")):
			cur.call("open_country", dip_open)
		else:
			cur.call("refresh")
		dip_open = -1
		_dip_scroll_to = -1
		return
	var scr: Script = load(DIP_SHEET_PATH) as Script
	if scr == null:
		open_diplomacy_legacy()
		return
	close_panel()
	var expand: bool = false
	for it: Dictionary in gw.diplo.pending_for_player():
		if String(it.get("kind", "")) == "demand":
			expand = true
	var is_pc: bool = root.size.x >= 700
	var sh: PanelContainer = scr.new() as PanelContainer
	sh.call("setup", main_node)
	if is_pc:
		var sh_w: float = minf(620.0, root.size.x - 40.0)
		var sh_h: float = minf(460.0, root.size.y - 120.0)
		sh.custom_minimum_size = Vector2(sh_w, sh_h)
		sh.size = Vector2(sh_w, sh_h)
		sh.position = Vector2(roundf((root.size.x - sh_w) * 0.5), roundf((root.size.y - sh_h - 70.0) * 0.5 + 20.0))
		root.add_child(sh)
	else:
		holder.add_child(sh)
		holder.move_child(sh, tab_row.get_index() + 1)
		bottom_panel.visible = false
	panel = sh
	panel_kind = "diplomacy"
	_dip_dirty = false
	_dip_rebuild_t = 1.5
	sh.call("fit", Vector2(minf(620.0, root.size.x - 40.0) if is_pc else root.get_viewport_rect().size.x, root.get_viewport_rect().size.y), tab_row.size.y + 6.0)
	ui24_open(sh)
	if dip_chip != null:
		dip_chip.visible = false
	_tip_until = 0.0
	sh.call("open_at", dip_open, expand)
	dip_open = -1
	_dip_scroll_to = -1


func open_my_state() -> void :
	if gw == null or gw.player == null or gw.player.eliminated or gw.diplo == null:
		return
	if panel_kind == "mystate" and panel != null and is_instance_valid(panel):
		if not bool(panel.get("_closing")):
			panel.call("close_sheet")
		return
	var scr: Script = load(MY_STATE_PATH) as Script
	if scr == null:
		return
	close_panel()
	var is_pc: bool = root.size.x >= 700
	var sh: PanelContainer = scr.new() as PanelContainer
	if is_pc:
		var sh_w: float = minf(620.0, root.size.x - 40.0)
		var sh_h: float = minf(460.0, root.size.y - 120.0)
		sh.custom_minimum_size = Vector2(sh_w, sh_h)
		sh.size = Vector2(sh_w, sh_h)
		sh.position = Vector2(roundf((root.size.x - sh_w) * 0.5), roundf((root.size.y - sh_h - 70.0) * 0.5 + 20.0))
		root.add_child(sh)
	else:
		holder.add_child(sh)
		holder.move_child(sh, tab_row.get_index() + 1)
		bottom_panel.visible = false
	sh.call("setup", main_node)
	panel = sh
	panel_kind = "mystate"
	sh.call("fit", Vector2(minf(620.0, root.size.x - 40.0) if is_pc else root.get_viewport_rect().size.x, root.get_viewport_rect().size.y), tab_row.size.y + 6.0)
	ui24_open(sh)
	sh.call("open_anim")
	if top_name != null:
		top_name.add_theme_color_override("font_color", UiKit.TITLE)


func my_state_closed() -> void :
	if top_name != null and is_instance_valid(top_name):
		top_name.add_theme_color_override("font_color", UiKit.TEXT)


func open_diplomacy_legacy() -> void :
	var vb: VBoxContainer = _window("Дипломатия", "diplomacy")
	panel_kind = "diplomacy"
	var dp: Diplomacy = gw.diplo
	var p: Country = gw.player
	if p == null:
		return
	var v11: bool = dp.has_method("country_row")
	_dip_timers.clear()
	if v11:
		for it: Dictionary in dp.pending_for_player():
			_pending_row(vb, it)
		var st: String = gw.econ.scarce_text(p) if gw.econ.has_method("scarce_text") else ""
		if st != "":
			var sr: HBoxContainer = _rowbox(vb)
			sr.add_child(UiKit.icon_rect("icon_scarce", 18.0))
			var sl: Label = UiKit.lbl(Loc.t("На вашей земле нет: %s. Купите, отнимите или замените.") % st.trim_prefix(Loc.t("нет: ")).trim_prefix(Loc.t("Нет: ")), 10, UiKit.GOLD, 2)
			sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sr.add_child(sl)
	for c: Country in gw.countries:
		if c.is_player:
			continue
		if v11:
			_country_block(vb, c, dp.country_row(p.id, c.id))
		else:
			var row0: HBoxContainer = _rowbox(vb)
			row0.add_child(_flag(c))
			row0.add_child(UiKit.name_lbl(c.name, 11, UiKit.TEXT, 2, 2))
	var tip: Label = UiKit.lbl("Удар по чужой земле — объявление войны. Пакты и союзники вступают в войну за вас. Нарушить пакт о ненападении — вероломство.", 9, UiKit.MUTED, 1)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(tip)



func open_ultimatum() -> void :
	if not (panel_kind == "ultimatum" and panel != null and is_instance_valid(panel)) and not bool(ult.get("new", false)):
		ult = {}
		dip_open = -1
		if panel_kind == "diplomacy" and panel != null and is_instance_valid(panel) and panel.has_method("open_list"):
			panel.call("open_list", true)
			panel.set("from_chip", true)
		else:
			open_diplomacy()
		return
	ult.erase("new")
	var c: Country = gw.country_by_id(int(ult.get("to", 0)))
	if c == null or gw.player == null:
		return
	var vb: VBoxContainer = _window(Loc.t("Ультиматум: %s") % Loc.name(c.name), "ultimatum")
	panel_kind = "ultimatum"
	var p: Country = gw.player
	var kinds: Array = [["money", "ДЕНЬГИ"], ["res", "РЕСУРС"]]
	var opts: Array = gw.diplo.demand_options(p.id, c.id)
	for i in opts.size():
		var o: Dictionary = opts[i]
		if String(o["kind"]) in ["deposit", "break_alliance", "cancel_visa"]:
			kinds.append(["opt:%d" % i, String(o["label"])])
	vb.add_child(UiKit.lbl("ЧТО ТРЕБУЕМ", 11, UiKit.TITLE, 2, 2))
	var kf: = HFlowContainer.new()
	kf.add_theme_constant_override("h_separation", 5)
	kf.add_theme_constant_override("v_separation", 5)
	vb.add_child(kf)
	var cur: String = String(ult["kind"]) if int(ult.get("opt", -1)) < 0 else "opt:%d" % int(ult["opt"])
	for k: Array in kinds:
		var key: String = String(k[0])
		var b: Button = _small_btn(String(k[1]), "", true, "gold" if key == cur else "stone")
		b.pressed.connect( func() -> void :
			if key.begins_with("opt:"):
				ult["opt"] = int(key.substr(4))
				ult["kind"] = String((opts[int(key.substr(4))] as Dictionary)["kind"])
			else:
				ult["opt"] = -1
				ult["kind"] = key
			open_ultimatum())
		kf.add_child(b)
	var summary: String = ""
	if int(ult.get("opt", -1)) < 0:
		if String(ult["kind"]) == "res":
			var rf: = HFlowContainer.new()
			rf.add_theme_constant_override("h_separation", 4)
			vb.add_child(rf)
			for rk: String in Economy.TRADE_RES:
				var rb: Button = _small_btn(_res_name(rk), "", true, "blue" if rk == String(ult["res"]) else "stone")
				rb.add_theme_font_size_override("font_size", 9)
				rb.custom_minimum_size = Vector2(0, 32)
				var rk2: String = rk
				rb.pressed.connect( func() -> void :
					ult["res"] = rk2
					open_ultimatum())
				rf.add_child(rb)
		var nr: = HBoxContainer.new()
		nr.add_theme_constant_override("separation", 4)
		vb.add_child(nr)
		for st: int in [-100, -10]:
			var sb: Button = _small_btn("%d" % st, "", true, "stone")
			var st2: int = st
			sb.pressed.connect( func() -> void :
				ult["n"] = maxi(1, int(ult["n"]) + st2)
				open_ultimatum())
			nr.add_child(sb)
		var nl: Label = UiKit.lbl(str(int(ult["n"])), 16, UiKit.GOLD, 2, 2)
		nl.custom_minimum_size = Vector2(70, 0)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nr.add_child(nl)
		for st3: int in [10, 100]:
			var sb2: Button = _small_btn("+%d" % st3, "", true, "stone")
			var st4: int = st3
			sb2.pressed.connect( func() -> void :
				ult["n"] = int(ult["n"]) + st4
				open_ultimatum())
			nr.add_child(sb2)
		var have: int = c.money if String(ult["kind"]) == "money" else int(c.get(String(ult["res"])))
		summary = "%d %s" % [int(ult["n"]), "денег" if String(ult["kind"]) == "money" else _res_name(String(ult["res"])).to_lower()]
		var hl: Label = UiKit.lbl(Loc.t("У них сейчас: %d") % have, 9, UiKit.MUTED if have >= int(ult["n"]) else UiKit.RED, 1)
		vb.add_child(hl)
	else:
		summary = String((opts[int(ult["opt"])] as Dictionary).get("text", ""))
	vb.add_child(UiKit.lbl("ИНАЧЕ", 11, UiKit.TITLE, 2, 2))
	var cr: = HBoxContainer.new()
	cr.add_theme_constant_override("separation", 6)
	vb.add_child(cr)
	for cq: Array in [["embargo", "ЭМБАРГО"], ["war", "ВОЙНА"]]:
		var cb: Button = _small_btn(String(cq[1]), "", true, ("red" if String(cq[0]) == "war" else "gold") if String(ult["conseq"]) == String(cq[0]) else "stone")
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cq2: String = String(cq[0])
		cb.pressed.connect( func() -> void :
			ult["conseq"] = cq2
			open_ultimatum())
		cr.add_child(cb)
	var sm: Label = UiKit.lbl(Loc.t("Требуем: %s. Иначе — %s. Ответ придёт сразу; чем вы сильнее и чем меньше просите, тем вероятнее согласие.") % [summary, Loc.t("ВОЙНА") if String(ult["conseq"]) == "war" else Loc.t("ЭМБАРГО")], 10, UiKit.TEXT, 1)
	sm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sm)
	vb.add_child(_small_btn("ОТПРАВИТЬ УЛЬТИМАТУМ", "ult_send", true, "red"))
	vb.add_child(_small_btn("НАЗАД", "diplomacy", true, "stone"))



func _pending_row(vb: VBoxContainer, it: Dictionary) -> void :
	var pc: = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 6, 5))
	vb.add_child(pc)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	pc.add_child(col)
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 6)
	col.add_child(hr)
	var oc: Country = gw.country_by_id(int(it.get("from", 0)))
	if oc != null:
		hr.add_child(_flag(oc))
	hr.add_child(UiKit.icon_rect(String(it.get("icon", "icon_ultimatum")), 18.0))
	var dem: bool = String(it.get("kind", "")) == "demand"
	var t: Label = UiKit.lbl(String(it.get("text", "")), 10, UiKit.RED if dem else UiKit.TITLE, 2)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(t)
	var tlb: Label = UiKit.lbl(Loc.t("%d с") % int(float(it.get("left", 0.0))) if float(it.get("left", 0.0)) >= 0.0 else "∞", 10, UiKit.GOLD, 2, 2)
	hr.add_child(tlb)
	_dip_timers.append([tlb, float(it.get("deadline", gw.game_time + float(it.get("left", 0.0))))])
	if dem and String(it.get("conseq", "")) != "":
		var cq: Label = UiKit.lbl(Loc.t("Отказ: %s") % (Loc.t("ВОЙНА") if String(it["conseq"]) == "war" else Loc.t("ЭМБАРГО")), 9, UiKit.MUTED, 1)
		col.add_child(cq)
	var br: = HBoxContainer.new()
	br.add_theme_constant_override("separation", 6)
	col.add_child(br)
	var first: bool = true
	for o: Dictionary in it.get("options", []):
		var b: Button = _small_btn(String(o["label"]), "pend:%s:%s" % [String(it["id"]), String(o["act"])], true, "green" if first else "red")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		br.add_child(b)
		first = false



func _country_block(vb: VBoxContainer, c: Country, row: Dictionary) -> void :
	var open: bool = dip_open == c.id
	var pc: = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.sb("wb_card" if open else "wb_panel_dark", 6, 4))
	vb.add_child(pc)
	if open and _dip_scroll_to == c.id and panel != null and panel.has_meta("scroll"):
		_dip_scroll_to = -1
		var scv: ScrollContainer = panel.get_meta("scroll")
		( func() -> void :
			await get_tree().process_frame
			await get_tree().process_frame
			if is_instance_valid(scv) and is_instance_valid(pc):
				scv.ensure_control_visible(pc)
				scv.scroll_vertical = maxi(scv.scroll_vertical, int(pc.position.y + pc.size.y - scv.size.y + 8.0))).call()
	var outer: = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 5)
	pc.add_child(outer)
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 6)
	outer.add_child(hr)
	hr.add_child(_flag(c))
	var per: Dictionary = row.get("persona", {})
	var pic: TextureRect = UiKit.icon_rect(String(per.get("icon", "icon_persona_unknown")) if not per.is_empty() else "icon_persona_unknown", 20.0)
	hr.add_child(pic)
	var col: = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(col)
	var nm: Label = UiKit.name_lbl(c.name + ("" if per.is_empty() else "  · " + Loc.t(String(per.get("name", "")))), 11, UiKit.DIM if c.eliminated else UiKit.TEXT, 2, 2)
	nm.clip_text = true
	col.add_child(nm)
	var r: int = int(row.get("rel_state", 0))
	if c.eliminated:
		col.add_child(UiKit.lbl("РАЗГРОМЛЕНА", 9, UiKit.MUTED, 2))
		return
	var line: = HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	col.add_child(line)
	line.add_child(UiKit.lbl(String(row.get("rel_name", "")), 9, Palette.c(String(row.get("rel_color", "grass_light"))).lightened(0.2), 2))
	var rv: int = int(row.get("relation", 0))
	line.add_child(UiKit.lbl("%+d" % rv, 9, UiKit.GREEN if rv > 10 else (UiKit.RED if rv < -10 else UiKit.MUTED), 2))
	var tr: int = int(row.get("trend", 0))
	line.add_child(UiKit.icon_rect("icon_rel_up" if tr > 0 else ("icon_rel_down" if tr < 0 else "icon_rel_flat"), 12.0))
	for k: String in row.get("treaties", []):
		var ti: Dictionary = Diplomacy.TREATY_INFO.get(k, {})
		if not ti.is_empty():
			line.add_child(UiKit.icon_rect(String(ti["icon"]), 14.0))
	if bool(row.get("embargo_out", false)) or bool(row.get("embargo_in", false)):
		line.add_child(UiKit.icon_rect("icon_treaty_embargo", 14.0))
	if String(row.get("coalition", "")) != "":
		line.add_child(UiKit.icon_rect("icon_coalition", 14.0))
	if bool(row.get("pending", false)):
		line.add_child(UiKit.lbl("!", 11, UiKit.RED, 2, 2))
	var more: Button = _small_btn(Loc.t("СКРЫТЬ") if open else Loc.t("ЕЩЁ"), "dipx:%d" % c.id, true, "blue" if not open else "stone")
	more.custom_minimum_size = Vector2(62, 34)
	hr.add_child(more)
	if not open:
		return

	var info: String = Loc.t(String(per.get("desc", ""))) if not per.is_empty() else Loc.t("Характер неизвестен: узнаете при общей границе, сделке или войне.")
	var sc: Array = row.get("scarce", [])
	if not sc.is_empty():
		var nms: PackedStringArray = PackedStringArray()
		for res: String in sc:
			nms.append(String(Economy.RES_NAMES.get(res, res)).to_lower())
		info += Loc.t("\nИм не хватает: %s — можно продать дороже.") % ", ".join(nms)
	var il: Label = UiKit.lbl(info + Loc.t("\nСила: ×%.1f от вашей · очки %d") % [float(row.get("strength_ratio", 1.0)), c.score], 9, UiKit.MUTED, 1)
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(il)
	var fl: = HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 5)
	fl.add_theme_constant_override("v_separation", 5)
	outer.add_child(fl)
	var nap: bool = (row.get("treaties", []) as Array).has("nap")
	match r:
		Diplomacy.Rel.WAR:
			fl.add_child(_small_btn("ПЕРЕМИРИЕ", "dip:%d:truce" % c.id, true, "blue"))
			fl.add_child(_small_btn("МИР", "dip:%d:peace" % c.id, true, "green"))
		Diplomacy.Rel.TRUCE:
			fl.add_child(_small_btn("ВОЙНА", "dip:%d:war" % c.id, true, "red"))
		_:
			var arm: bool = war_arm == c.id and Time.get_ticks_msec() < war_arm_until
			fl.add_child(_small_btn((Loc.t("ТОЧНО ВОЙНА?") if arm else (Loc.t("ВОЙНА (ВЕРОЛОМНО)") if nap else Loc.t("ВОЙНА"))), ("dip:%d:war" if arm else "warask:%d") % c.id, true, "red"))
	for k: String in row.get("can_propose", []):
		var ti2: Dictionary = Diplomacy.TREATY_INFO.get(k, {})
		var hint_it: bool = k == dip_hint_treaty and c.id == dip_open
		var b: Button = _small_btn("+ " + String(ti2.get("short", k)), "treaty:%d:%s" % [c.id, k], true, "gold" if hint_it else "green")
		b.tooltip_text = String(ti2.get("effect", ""))
		fl.add_child(b)
		if hint_it and not _win_refresh:
			UiKit.pop_in(b, 0.8, 0.35)
	for k2: String in row.get("can_cancel", []):
		var ti3: Dictionary = Diplomacy.TREATY_INFO.get(k2, {})
		fl.add_child(_small_btn("✕ " + String(ti3.get("short", k2)), "untreaty:%d:%s" % [c.id, k2], true, "stone"))
	var emb: bool = bool(row.get("embargo_out", false))
	fl.add_child(_small_btn(Loc.t("СНЯТЬ ЭМБАРГО") if emb else Loc.t("ЭМБАРГО"), "embargo:%d:%d" % [c.id, 0 if emb else 1], true, "stone" if emb else "red"))
	fl.add_child(_small_btn("ПОМОЩЬ 500", "aid:%d" % c.id, gw.player.money >= 500, "gold"))
	if r != Diplomacy.Rel.WAR and r != Diplomacy.Rel.TRUCE:
		var ub: Button = _small_btn("УЛЬТИМАТУМ…", "", true, "red")
		var cid: int = c.id
		ub.pressed.connect( func() -> void :
			ult = {"to": cid, "kind": "money", "n": 300, "res": "metal", "conseq": "embargo", "opt": -1}
			open_ultimatum())
		outer.add_child(ub)



func trade_status(text: String, ok: bool) -> void :
	_trade_status_txt = text
	_trade_status_ok = ok
	_trade_status_ms = Time.get_ticks_msec()
	if trade_sheet != null and is_instance_valid(trade_sheet) and trade_sheet.visible:
		trade_sheet.call("_notice", text, "ok" if ok else "bad")





func _trade24() -> bool:
	if not _hub_ok():
		return false
	if trade_sheet != null and is_instance_valid(trade_sheet) and trade_sheet.visible and not bool(trade_sheet.get("closing")):
		trade_sheet.call("refresh_now")
		return true
	close_panel()
	if trade_sheet != null and is_instance_valid(trade_sheet):
		trade_sheet.queue_free()
	var vp: Vector2 = root.get_viewport_rect().size
	var sheet_h: float = floorf(vp.y * 0.74) - BuildPanel.TAB_H
	var is_pc: bool = root.size.x >= 700
	var final_h: float = minf(460.0, root.size.y - 120.0) if is_pc else sheet_h
	var sh: Control = (load("res://ui/ui24/trade_sheet.gd") as GDScript).new()
	sh.name = "TradeSheet"
	sh.call("setup", self, final_h, _safe_margins().y if not is_pc else 0.0)
	sh.connect("action", _on_trade_action)
	trade_sheet = sh
	ui24_open(sh)
	if is_pc:
		var sh_w: float = minf(620.0, root.size.x - 40.0)
		sh.custom_minimum_size = Vector2(sh_w, final_h)
		sh.size = Vector2(sh_w, final_h)
		sh.position = Vector2(roundf((root.size.x - sh_w) * 0.5), roundf((root.size.y - final_h - 70.0) * 0.5 + 20.0))
		root.add_child(sh)
	else:
		holder.add_child(sh)
		bottom_panel.visible = false
	sh.modulate.a = 0.0
	var tw: Tween = sh.create_tween()
	tw.tween_property(sh, "modulate:a", 1.0, 0.12)
	UiKit.snd("ui_open")
	return true


func _fit_ad_rules_window() -> void :
	if ad_rules_sheet == null or not is_instance_valid(ad_rules_sheet) or ad_rules_sheet.get_parent() != root:
		return
	var available: Vector2 = root.size - Vector2(24.0, 24.0)
	if available.x <= 0.0 or available.y <= 0.0:
		return
	var panel_size: Vector2 = Vector2(minf(620.0, available.x), minf(460.0, available.y))
	if ad_rules_sheet.custom_minimum_size != panel_size:
		ad_rules_sheet.custom_minimum_size = panel_size
	if ad_rules_sheet.size != panel_size:
		ad_rules_sheet.size = panel_size
	var panel_position: Vector2 = (root.size - panel_size) * 0.5
	if ad_rules_sheet.position != panel_position:
		ad_rules_sheet.position = panel_position


func open_ad_rules(focus: int = -1) -> void :
	if not _hub_ok():
		return
	close_panel()
	if ad_rules_sheet != null and is_instance_valid(ad_rules_sheet):
		ad_rules_sheet.queue_free()
	var vp: Vector2 = root.get_viewport_rect().size
	var sheet_h: float = floorf(vp.y * 0.74) - BuildPanel.TAB_H
	var is_pc: bool = root.size.x >= 700
	var final_h: float = minf(460.0, maxf(1.0, root.size.y - 24.0)) if is_pc else sheet_h
	var final_w: float = minf(620.0, maxf(1.0, root.size.x - 24.0)) if is_pc else vp.x
	var sh: Control = (load("res://ui/ui24/ad_rules_sheet.gd") as GDScript).new()
	sh.name = "AdRulesSheet"
	sh.call("setup", self, final_h, _safe_margins().y if not is_pc else 0.0, focus, final_w)
	ad_rules_sheet = sh
	ui24_open(sh)
	if is_pc:
		sh.custom_minimum_size = Vector2(final_w, final_h)
		sh.size = Vector2(final_w, final_h)
		root.add_child(sh)
		_fit_ad_rules_window()
		call_deferred("_fit_ad_rules_window")
	else:
		holder.add_child(sh)
		bottom_panel.visible = false
	sh.modulate.a = 0.0
	var tw: Tween = sh.create_tween()
	tw.tween_property(sh, "modulate:a", 1.0, 0.12)
	UiKit.snd("ui_open")




func _on_trade_action(nm: String) -> void :
	var open: bool = trade_sheet != null and is_instance_valid(trade_sheet)
	if nm == "close":
		if open:
			trade_sheet.call("close")
		return
	if nm.begins_with("res:"):
		var res: String = nm.get_slice(":", 1)
		var want: String = nm.substr(5 + res.length())
		if open:
			trade_sheet.call("close")
		open_hub(1)
		if econ_hub != null and is_instance_valid(econ_hub):
			econ_hub.call("open_res", res, want, false)
		return
	action.emit(nm)


func open_trade() -> void :
	if _trade24():
		return
	var vb: VBoxContainer = _window("Торговля", "trade")
	panel_kind = "trade"
	var p: Country = gw.player
	if p == null:
		return
	var ec: Economy = gw.econ

	if _trade_status_txt != "" and Time.get_ticks_msec() - _trade_status_ms < 6000:
		var stl: Label = UiKit.lbl(_trade_status_txt, 11, UiKit.GREEN if _trade_status_ok else UiKit.RED, 2, 2)
		stl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stl.name = "TradeStatus"
		vb.add_child(stl)
		var my_ms: int = _trade_status_ms
		get_tree().create_timer(6.2).timeout.connect( func() -> void :
			if is_instance_valid(stl) and _trade_status_ms == my_ms:
				stl.queue_free())

	for rq: Dictionary in ec.requests_for(p.id):
		var oc: Country = gw.country_by_id(int(rq["from"]))
		if oc == null:
			continue
		var rr: HBoxContainer = _rowbox(vb)
		rr.add_child(_flag(oc))
		var rl: Label = UiKit.lbl(Loc.t("%s просит %s %d за %d") % [Loc.name(oc.name), Loc.t(String(Economy.RES_NAMES.get(String(rq["res"]), "")).to_lower()), int(rq["n"]), int(rq["price"])], 10, UiKit.TITLE, 2, 2)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rr.add_child(rl)
		rr.add_child(_small_btn("ПРОДАТЬ", "req:ok:%d" % int(rq["id"]), int(p.get(String(rq["res"]))) >= int(rq["n"]), "green"))
		rr.add_child(_small_btn("НЕТ", "req:no:%d" % int(rq["id"]), true, "red"))

	var has_port: bool = ec.ports.has_port(p)
	var mh: Label = UiKit.lbl(Loc.t("Рынок: цена за единицу, «+10» купить, «−10» продать (самым выгодным путём)") + (Loc.t(". Порт: импорт ×1.6, экспорт ×0.7") if has_port else Loc.t(". Без порта — только соседи по суше")), 10, UiKit.MUTED, 1)
	mh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(mh)
	var best_seller: = func(res: String) -> Country:
		return gw.econ.best_seller(p, res) if gw.econ.has_method("best_seller") else null
	var best_buyer: = func(res: String) -> Country:
		var best: Country = null
		var bn: int = 0
		for c: Country in gw.countries:
			if c.is_player or c.eliminated or gw.diplo.at_war(p.id, c.id) or gw.diplo.embargo_between(p.id, c.id) or not ec.can_reach(p, c):
				continue
			var nd: int = ec.need(c, res)
			if nd > bn:
				bn = nd
				best = c
		return best
	for res: String in Economy.TRADE_RES:
		var row: HBoxContainer = _rowbox(vb)
		row.add_child(UiKit.icon_rect(_res_icon(res), 18.0))
		var need: int = ec.need(p, res)
		var nm: Label = UiKit.lbl("%s\n%d%s" % [String(Economy.RES_SHORT.get(res, res)), int(p.get(res)), (Loc.t(" нужно +%d") % need) if need > 0 else ""], 10, UiKit.RED if need > 0 else UiKit.TEXT, 2, 2)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		row.add_child(nm)
		row.add_child(UiKit.lbl(str(ec.market_price(res)), 10, UiKit.GOLD, 2, 2))


		var mcb: Dictionary = ec.market_check(p, res, true)
		var sel: Country = mcb.get("partner") as Country
		var buy_from: int = sel.id if sel != null else 0
		var can_buy: bool = bool(mcb.get("ok", false))
		var bb: Button = _small_btn("+10", ("mkt:buy:%d:%s:10" % [buy_from, res]) if can_buy else "mkt_why:" + String(mcb.get("why", "")), true, "green" if can_buy else "stone")
		bb.custom_minimum_size.x = 52
		row.add_child(bb)
		var mcs: Dictionary = ec.market_check(p, res, false)
		var buyer: Country = mcs.get("partner") as Country
		var sell_to: int = buyer.id if buyer != null else 0
		var can_sell: bool = bool(mcs.get("ok", false))
		var why_s: String = String(mcs.get("why", ""))
		var sb2: Button = _small_btn("−10", ("mkt:sell:%d:%s:10" % [sell_to, res]) if can_sell else "mkt_why:" + why_s, true, "gold" if can_sell else "stone")
		sb2.custom_minimum_size.x = 52
		row.add_child(sb2)

	var dh: Label = UiKit.lbl("Договоры: излишки сами уходят партнёру, которому не хватает (оплата при доставке)", 10, UiKit.MUTED, 1)
	dh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(dh)
	for c: Country in gw.countries:
		if c.is_player or c.eliminated:
			continue
		var row2: HBoxContainer = _rowbox(vb)
		row2.add_child(_flag(c))
		var spare: PackedStringArray = PackedStringArray()
		for res2: String in Economy.RAW:
			var sv2: int = ec.surplus(c, res2)
			if sv2 >= 10:
				spare.append("%s %d" % [String(Economy.RES_SHORT[res2]).to_lower(), sv2])
		var t2: Label = UiKit.lbl(Loc.t("%s\nЕсть: %s") % [Loc.name(c.name), ", ".join(spare) if not spare.is_empty() else "—"], 10, UiKit.TEXT, 2, 2)
		t2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row2.add_child(t2)
		var on: bool = ec.trading(p.id, c.id)
		var war: bool = gw.diplo.at_war(p.id, c.id)
		row2.add_child(_small_btn(Loc.t("ВЫКЛ") if on else Loc.t("ДОГОВОР"), "trade:%d:%d" % [c.id, 0 if on else 1], not war and ec.can_reach(p, c), "stone" if on else "green"))
	var tl: Label = UiKit.lbl(Loc.t("Доход от торговли: %d") % p.trade_income, 10, UiKit.MUTED, 1)
	vb.add_child(tl)


func open_doctrine() -> void :
	var vb: VBoxContainer = _window("Доктрина", "doctrine")
	panel_kind = "doctrine"
	var p: Country = gw.player
	if p == null:
		return
	for it: Array in [["Режим обороны", "doc:defend", p.army_defend], ["Авто FPV-дроны пехоты", "doc:fpv", p.doctrine_fpv], ["Штурм (иначе осада)", "doc:assault", p.doctrine_assault], ["Автовызов огневой поддержки", "doc:support", gw.army.support_auto(p.id)]]:
		var row: HBoxContainer = _rowbox(vb)
		var lb: Label = UiKit.lbl(String(it[0]), 11, UiKit.TEXT, 2)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lb)
		var on: bool = bool(it[2])
		var tg: = TextureButton.new()
		tg.texture_normal = UiKit.tex("wb_toggle_on" if on else "wb_toggle_off")
		if tg.texture_normal != null:
			tg.ignore_texture_size = true
			tg.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			tg.custom_minimum_size = Vector2(52, 28)
			tg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var act: String = String(it[1])
			tg.pressed.connect( func() -> void : action.emit(act))
			UiKit.press_fx(tg)
			row.add_child(tg)
		else:
			row.add_child(_small_btn(Loc.t("ВКЛ") if on else Loc.t("ВЫКЛ"), String(it[1]), true, "green" if on else "red"))
	var a: Army = gw.army
	var tanks: int = 0
	var inf: int = 0
	for u: Unit in a.units:
		if u.country_id == p.id and u.alive():
			if u.type == Unit.Type.TANK:
				tanks += 1
			elif u.type == Unit.Type.INFANTRY:
				inf += 1
	var st: Label = UiKit.lbl(Loc.t("Армия: танков %d, отделений %d.\nТанк %d + %d титана, пехота %d + %d еды.\nЕда: %d (армия ест 1 на 3 отряда / 10 с).") % [tanks, inf, int(Army.SPEC[0]["cost"]), int(Army.SPEC[0]["ti"]), int(Army.SPEC[1]["cost"]), int(Army.SPEC[1]["food"]), p.food], 10, UiKit.MUTED, 1)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(st)


func _inv_update(p: Country) -> void :
	for key: String in _inv_cells:
		var cells: Array = _inv_cells[key]
		if not is_instance_valid(cells[1]):
			continue
		var amount: int = int(p.get(key))
		var cap: int = int(_econ("res_cap", [p, key], 0))
		var rate: int = int(_econ("res_rate", [p, key], 0))
		var need: int = int(_econ("need", [p, key], 0))
		var price: int = int(_econ("market_price", [key], 0))
		(cells[0] as Label).add_theme_color_override("font_color", UiKit.RED if need > 0 else UiKit.TEXT)
		(cells[1] as Label).text = ("%d/%d" % [amount, cap]) if cap > 0 else str(amount)
		(cells[2] as Label).text = _per_min(rate)
		(cells[2] as Label).add_theme_color_override("font_color", UiKit.GREEN if rate > 0 else (UiKit.RED if rate < 0 else UiKit.MUTED))
		(cells[3] as Label).text = str(price) if price > 0 else "—"


func open_inventory() -> void :
	if _hub_ok():
		open_hub(1)
		return
	_inv_cells.clear()
	var vb: VBoxContainer = _window("Склад страны", "inventory")
	panel_kind = "inventory"
	var p: Country = gw.player
	if p == null:
		return
	var grid: = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 5)
	vb.add_child(grid)
	for h: String in ["", "", "ЕСТЬ", "В МИН", "ЦЕНА"]:
		grid.add_child(UiKit.lbl(h, 9, UiKit.MUTED, 2))
	for it: Array in STORE:
		var key: String = String(it[0])
		var amount: int = int(p.get(key))
		var cap: int = int(_econ("res_cap", [p, key], 0))
		var rate: int = int(_econ("res_rate", [p, key], 0))
		var need: int = int(_econ("need", [p, key], 0))
		var price: int = int(_econ("market_price", [key], 0))
		grid.add_child(UiKit.icon_rect(_res_icon(key), 18.0))
		var nm: Label = UiKit.lbl(String(it[1]), 11, UiKit.RED if need > 0 else UiKit.TEXT, 2, 2)
		nm.custom_minimum_size = Vector2(92, 0)
		grid.add_child(nm)
		var la: Label = UiKit.lbl(("%d/%d" % [amount, cap]) if cap > 0 else str(amount), 11, UiKit.TEXT, 2, 2)
		la.custom_minimum_size = Vector2(52, 0)
		grid.add_child(la)
		var lr: Label = UiKit.lbl(_per_min(rate), 11, UiKit.GREEN if rate > 0 else (UiKit.RED if rate < 0 else UiKit.MUTED), 2, 2)
		lr.custom_minimum_size = Vector2(44, 0)
		grid.add_child(lr)
		var lp: Label = UiKit.lbl(str(price) if price > 0 else "—", 11, UiKit.GOLD, 2, 2)
		grid.add_child(lp)
		_inv_cells[key] = [nm, la, lr, lp]
	var short: String = _shortage(p)
	var tip: Label = UiKit.lbl(Loc.t("Не хватает: %s. Купите в торговле или постройте добычу.") % _res_name(short) if short != "" else Loc.t("Всего хватает. Излишки продаются через торговлю и порт."), 10, UiKit.RED if short != "" else UiKit.MUTED, 1)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(tip)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var b0: Button = _small_btn("ЭКОНОМИКА", "economy", true, "gold")
	b0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b0)
	var b1: Button = _small_btn("СТАТИСТИКА", "open_stats", true, "blue")
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b1)
	var b2: Button = _small_btn("ТОРГОВЛЯ", "trade", true, "green")
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b2)


func _stat_rows(vb: VBoxContainer, title: String, data: Dictionary, colour: String, unit: String) -> void :
	if data.is_empty():
		return
	vb.add_child(UiKit.lbl(title, 12, UiKit.TITLE, 3, 2))
	var keys: Array = data.keys()
	keys.sort_custom( func(a: Variant, b: Variant) -> bool: return float(data[a]) > float(data[b]))
	var top: float = maxf(1.0, absf(float(data[keys[0]])))
	for k: Variant in keys:
		var v: float = float(data[k])
		if absf(v) < 0.5:
			continue
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vb.add_child(row)
		var nm0: String = String(STAT_NAMES.get(String(k), Economy.STAT_NAMES.get(String(k), String(k).capitalize())))
		var nm: Label = UiKit.lbl(Loc.t("НПЗ", "stat") if nm0 == "НПЗ" else nm0, 10, UiKit.TEXT, 2, 2)
		nm.custom_minimum_size = Vector2(112, 0)
		nm.clip_text = true
		row.add_child(nm)
		var frame: = PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UiKit.sb("wb_bar_frame", 2))
		frame.custom_minimum_size = Vector2(0, 12)
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(frame)
		var fill: = Panel.new()
		fill.add_theme_stylebox_override("panel", UiKit.sb(colour, 0))
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(fill)
		var frac: float = clampf(absf(v) / top, 0.04, 1.0)
		frame.resized.connect( func() -> void :
			fill.position = Vector2(2, 2)
			fill.size = Vector2(floorf((frame.size.x - 4.0) * frac), maxf(2.0, frame.size.y - 4.0)))
		var val: Label = UiKit.lbl("%d%s" % [roundi(v), unit], 10, UiKit.GOLD, 2, 2)
		val.custom_minimum_size = Vector2(54, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)



func open_stats() -> void :
	if _hub_ok():
		open_hub(2)
		return
	var vb: VBoxContainer = _window("Статистика", "stats")
	panel_kind = "stats"
	var p: Country = gw.player
	if p == null:
		return
	var st: Dictionary = _econ("stats", [p], {}) as Dictionary
	var inc: Dictionary = st.get("income", {})
	var spend: Dictionary = st.get("spend", {})
	var total_in: float = 0.0
	for k: Variant in inc:
		total_in += float(inc[k])
	var total_out: float = 0.0
	for k: Variant in spend:
		total_out += float(spend[k])
	var best: String = ""
	var bv: float = 0.0
	for k: Variant in inc:
		if float(inc[k]) > bv:
			bv = float(inc[k])
			best = String(k)
	var head: Label = UiKit.lbl(Loc.t("Доход %d/мин · расходы %d/мин · итог %s/мин") % [roundi(total_in), roundi(total_out), _per_min(roundi(total_in - total_out))], 11, UiKit.TEXT, 2, 2)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(head)
	if best != "":
		var bl: Label = UiKit.lbl(Loc.t("Больше всего приносит: %s (%d%%)") % [Loc.t("НПЗ", "stat") if String(STAT_NAMES.get(best, best)) == "НПЗ" else Loc.t(String(STAT_NAMES.get(best, best))), roundi(100.0 * bv / maxf(1.0, total_in))], 11, UiKit.GREEN, 2, 2)
		vb.add_child(bl)
	if inc.is_empty() and spend.is_empty():
		vb.add_child(UiKit.lbl("Статистика копится: загляните через минуту.", 10, UiKit.MUTED, 1))
	_stat_rows(vb, "Доход в минуту", inc, "wb_bar_green", "")
	_stat_rows(vb, "Расходы в минуту", spend, "wb_bar_red", "")
	var res_in: Dictionary = st.get("res_in", {})
	var prod: Dictionary = {}
	for r: Variant in res_in:
		var sum: float = 0.0
		var src: Dictionary = res_in[r]
		for k2: Variant in src:
			sum += float(src[k2])
		prod[_res_name(String(r)).capitalize()] = sum
	_stat_rows(vb, "Добыча в минуту", prod, "wb_bar_amber", "")
	if gw.rail != null:
		var dv: Label = UiKit.lbl(String(gw.rail.dev_text(p.id)), 11, UiKit.TITLE, 2, 2)
		dv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(dv)
		var lvl: int = int(gw.rail.level_of(p.id))
		var nx: String = String(Rail.level_unlocks(lvl + 1)) if int(gw.rail.next_threshold(p.id)) > 0 else Loc.t("Максимальное развитие")
		var dl: Label = UiKit.lbl(Loc.t("Дальше: %s · станций %d, поездов %d") % [nx, int(gw.rail.station_count(p.id)), int(gw.rail.train_count(p.id))], 10, UiKit.MUTED, 1)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(dl)
	var sc: Label = UiKit.lbl(Loc.t("Всего заработано: %d · очки экономики %d · войны %d") % [p.earned, p.score_eco, p.score_mil], 10, UiKit.MUTED, 1)
	sc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sc)
