extends "res://ui/hud/hud_stack.gd"



func open_builds(f: Facility) -> void :
	var ai: Dictionary = gw.army.army_info(f)
	var vb: VBoxContainer = _window(Loc.t("Армия №%d") % int(ai["no"]) if int(ai["no"]) > 0 else Loc.t("Новая армия"), "builds")
	panel_kind = "builds"
	var ab: Dictionary = gw.army.army_brief(f) if gw.army.has_method("army_brief") else {}
	var parts: PackedStringArray = PackedStringArray()
	for cpt: Dictionary in ab.get("comp", []):
		parts.append("%s %d/%d" % [String(cpt.get("type_name", "")), int(cpt.get("have", 0)), int(cpt.get("want", 0))])
	if not parts.is_empty():
		var cl: Label = UiKit.lbl(Loc.t("СОСТАВ: %s") % " · ".join(parts), 10, UiKit.TEXT, 2)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(cl)
	var tr: = HBoxContainer.new()
	tr.add_theme_constant_override("separation", 6)
	vb.add_child(tr)
	var stop: bool = f.prod_type == 3
	if gw.army.has_method("set_auto_refill"):
		var ar_on: bool = bool(f.get("auto_refill"))
		var rb: Button = UiKit.big(Loc.t("ПОПОЛНЕНИЕ: ВКЛ") if ar_on else Loc.t("ПОПОЛНЕНИЕ: ВЫКЛ"), "gold" if ar_on else "stone", "", 44.0, 10)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rb.pressed.connect( func() -> void :
			action.emit("auto_refill")
			open_builds.call_deferred(f))
		HoldTip.tip(rb, Loc.t("ПОПОЛНЕНИЕ: %s — %s") % [Loc.t("ВКЛ") if ar_on else Loc.t("ВЫКЛ"), Loc.t("казармы сами восполняют потери этой армии") if ar_on else Loc.t("потери не восполняются; тап — включить")])
		tr.add_child(rb)
	var nb: Button = UiKit.big(Loc.t("НАБОР: СТОП") if stop else Loc.t("НАБОР: ИДЁТ"), "red" if stop else "stone", "", 44.0, 10)
	nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nb.pressed.connect( func() -> void :
		action.emit("bar_0" if stop else "bar_3")
		open_builds.call_deferred(f))
	HoldTip.tip(nb, Loc.t("НАБОР: %s — %s") % [Loc.t("СТОП") if stop else Loc.t("ИДЁТ"), Loc.t("казармы не набирают новых бойцов; тап — снова набирать") if stop else Loc.t("казармы набирают бойцов в армию; тап — остановить")])
	tr.add_child(nb)
	vb.add_child(UiKit.lbl("СБОРКА АРМИИ", 11, UiKit.GOLD, 2, 2))
	for b: Dictionary in Army.BUILDS:
		var on: bool = String(ai["build"]) == String(b["id"])
		var pc: = PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UiKit.sb("wb_card" if on else "wb_panel_dark", 6, 4))
		vb.add_child(pc)
		var hr: = HBoxContainer.new()
		hr.add_theme_constant_override("separation", 6)
		pc.add_child(hr)
		hr.add_child(UiKit.icon_rect(String(b["icon"]) if UiKit.has(String(b["icon"])) else "icon_doctrine", 26.0))
		var col: = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hr.add_child(col)
		col.add_child(UiKit.lbl(String(b["title"]), 11, UiKit.GOLD if on else UiKit.TEXT, 2, 2))
		var d: Label = UiKit.lbl(String(b["desc"]), 9, UiKit.MUTED, 1)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(d)
		var bb: Button = _small_btn(Loc.t("ВЫБРАНО") if on else Loc.t("ВЫБРАТЬ"), "build_%s" % String(b["id"]), not on, "green")
		bb.custom_minimum_size = Vector2(84, 44)
		bb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hr.add_child(bb)
	if gw.player != null and f.country_id == gw.player.id and gw.mil.has_method("demolish_why"):


		vb.add_child(HSeparator.new())
		var dr: = HBoxContainer.new()
		dr.alignment = BoxContainer.ALIGNMENT_END
		vb.add_child(dr)
		var dref: int = gw.mil.demolish_refund(f)
		var db: Button = UiKit.big("СНЕСТИ КАЗАРМЫ…", "stone", "", 44.0, 10)
		db.custom_minimum_size = Vector2(170, 44)
		if gw.mil.demolish_why(gw.player, f) != "":
			db.modulate.a = 0.55
		db.pressed.connect( func() -> void :
			var why9: String = gw.mil.demolish_why(gw.player, f)
			if why9 != "":
				show_toast(why9)
				UiKit.snd("ui_error")
				return
			close_panel()
			if main_node != null:
				main_node.selected_fac = f
				main_node.army_view = false
				main_node.set("bar_builds_fid", -1)
			action.emit("fac_demolish"))
		HoldTip.tip(db, Loc.t("СНЕСТИ — казармы исчезнут, армия останется без пополнения; вернётся %d (спросит подтверждение)") % dref)
		dr.add_child(db)






func open_economy() -> void :
	if _hub_ok():
		open_hub(0)
		return
	var vb: VBoxContainer = _window("Экономика", "economy")
	panel_kind = "economy"
	_econ_refs = {}
	_econ_dirty = false
	_econ_t = 1.0
	var p: Country = gw.player
	var g = gw.get("guide")
	if p == null or g == null:
		var el: Label = UiKit.lbl("Экономики пока нет: сначала основайте столицу — вкладка ГОРОДА › СТОЛИЦА.", 11, UiKit.TEXT, 1)
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		el.custom_minimum_size = Vector2(240, 0)
		vb.add_child(el)
		return
	var fl: Dictionary = g.flows(p)
	_econ_sig = _econ_signature(fl)
	vb.add_child(_small_btn(Loc.t("ПЛАН РАЗВИТИЯ: %s") % (Loc.t("СКРЫТ — ПОКАЗАТЬ") if plan_closed else Loc.t("ВИДЕН — СКРЫТЬ")), "plan_toggle", true, "blue"))
	var mo: Dictionary = fl.get("money", {})
	var mh: Label = UiKit.lbl("", 12, UiKit.GREEN, 2, 2)
	mh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(mh)
	var rows: Array = []
	for pair: Array in [[mo.get("income", []), true], [mo.get("spend", []), false]]:
		for _i: int in 5:
			var row: = HBoxContainer.new()
			row.add_theme_constant_override("separation", 5)
			vb.add_child(row)
			var nl: Label = UiKit.lbl("", 9, UiKit.TEXT, 1)
			nl.custom_minimum_size = Vector2(110, 0)
			nl.clip_text = true
			row.add_child(nl)
			var bar: = Panel.new()
			bar.add_theme_stylebox_override("panel", UiKit.sb("wb_bar_green" if bool(pair[1]) else "wb_bar_red", 0))
			bar.custom_minimum_size = Vector2(3, 9)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(bar)
			var vl: Label = UiKit.lbl("", 9, UiKit.GREEN if bool(pair[1]) else UiKit.RED, 1)
			row.add_child(vl)
			rows.append([nl, bar, vl, bool(pair[1]), row])
	var st: Label = UiKit.lbl("", 10, UiKit.TEXT, 2)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(st)
	vb.add_child(UiKit.lbl("ЦЕПОЧКИ ПРОИЗВОДСТВА", 11, UiKit.TITLE, 2, 2))
	var chains: Array = []
	for ch: Dictionary in fl.get("chains", []):
		var status: String = String(ch.get("status", "none"))
		var pc: = PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 6, 4))
		vb.add_child(pc)
		var col: = VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		pc.add_child(col)
		var hr: = HBoxContainer.new()
		hr.add_theme_constant_override("separation", 5)
		col.add_child(hr)
		var dot: Label = UiKit.lbl("●", 11, UiKit.MUTED, 1)
		hr.add_child(dot)
		if String(ch.get("icon", "")) != "":
			hr.add_child(UiKit.icon_rect(String(ch["icon"]), 16.0))
		var nm: Label = UiKit.lbl("", 10, UiKit.TEXT, 2)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		hr.add_child(nm)
		var fk: String = String(ch.get("fix_key", ""))

		var fb: Button = UiKit.big("ИСПРАВИТЬ", "green", "", 28.0, 9)
		fb.set_meta("fk", fk)
		fb.pressed.connect( func() -> void : action.emit("plan_go:" + String(fb.get_meta("fk", ""))))
		fb.visible = fk != "" and status != "ok"
		hr.add_child(fb)
		var tl: Label = UiKit.lbl("", 9, UiKit.MUTED, 1)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(tl)
		chains.append([dot, nm, tl, fb])
	_econ_refs = {"mh": mh, "rows": rows, "st": st, "chains": chains}
	_econ_fill(fl)




func _econ_fill(fl: Dictionary) -> void :
	if _econ_refs.is_empty() or not is_instance_valid(_econ_refs["mh"]):
		return
	var mo: Dictionary = fl.get("money", {})
	var net: int = int(mo.get("net_per_min", 0))
	var reg: int = int(mo.get("regular_per_min", net))
	_set_lbl(_econ_refs["mh"], Loc.t("ДЕНЬГИ: %s%d в мин (без строек %s%d)") % ["+" if net >= 0 else "", net, "+" if reg >= 0 else "", reg], UiKit.GREEN if reg >= 0 else UiKit.RED)
	var top: float = 1.0
	for it: Dictionary in mo.get("income", []) + mo.get("spend", []):
		top = maxf(top, absf(float(it.get("per_min", 0))))
	var inc: Array = mo.get("income", [])
	var spn: Array = mo.get("spend", [])
	var rows: Array = _econ_refs["rows"]
	for i: int in rows.size():
		var r: Array = rows[i]
		var src: Array = inc if i < 5 else spn
		var k: int = i % 5
		var show: bool = k < src.size()
		if (r[4] as Control).visible != show:
			(r[4] as Control).visible = show
		if not show:
			continue
		var it2: Dictionary = src[k]
		var v: int = int(it2.get("per_min", 0))
		_set_lbl(r[0], String(it2.get("name", "")), UiKit.TEXT)
		var bw: float = roundf(maxf(3.0, 120.0 * absf(float(v)) / top))
		if absf((r[1] as Control).custom_minimum_size.x - bw) >= 1.0:
			(r[1] as Control).custom_minimum_size = Vector2(bw, 9)
		_set_lbl(r[2], "%s%d" % ["+" if bool(r[3]) else "−", absi(v)], UiKit.GREEN if bool(r[3]) else UiKit.RED)
	var pw: Dictionary = fl.get("power", {})
	var fd: Dictionary = fl.get("food", {})
	_set_lbl(_econ_refs["st"], Loc.t("ЭНЕРГИЯ %d/%d · ЕДА %+d в мин (запас %d)") % [int(pw.get("use", 0)), int(pw.get("cap", 0)), int(fd.get("per_min", 0)), int(fd.get("stock", 0))], UiKit.RED if String(pw.get("status", "ok")) == "bad" or String(fd.get("status", "ok")) == "bad" else UiKit.TEXT)
	var cl: Array = fl.get("chains", [])
	var crefs: Array = _econ_refs["chains"]
	for j: int in mini(crefs.size(), cl.size()):
		var ch: Dictionary = cl[j]
		var cr: Array = crefs[j]
		var status: String = String(ch.get("status", "none"))
		_set_lbl(cr[0], "●", {"ok": UiKit.GREEN, "warn": UiKit.GOLD, "bad": UiKit.RED}.get(status, UiKit.MUTED))
		_set_lbl(cr[1], "%s · %d" % [String(ch.get("name", "")), int(ch.get("count", 0))], UiKit.TEXT)
		var io: PackedStringArray = PackedStringArray()
		for i2: Dictionary in ch.get("inputs", []):
			io.append("−%s %d" % [String(i2.get("name", _res_name(String(i2.get("res", ""))))).to_lower(), int(i2.get("per_min", 0))])
		for o: Dictionary in ch.get("outputs", []):
			io.append("+%s %d" % [String(o.get("name", _res_name(String(o.get("res", ""))))).to_lower(), int(o.get("per_min", 0))])
		var tx: String = String(ch.get("text", ""))
		if not io.is_empty():
			tx += "\n" + Loc.t("%s в мин") % " · ".join(io)
		_set_lbl(cr[2], tx, UiKit.RED if status == "bad" else (UiKit.GOLD if status == "warn" else UiKit.MUTED))
		var fb: Button = cr[3]
		var fk: String = String(ch.get("fix_key", ""))
		fb.set_meta("fk", fk)
		if fb.visible != (fk != "" and status != "ok"):
			fb.visible = fk != "" and status != "ok"


func _econ_process(delta: float) -> void :
	if panel_kind != "economy" or panel == null or not is_instance_valid(panel) or gw.player == null or gw.get("guide") == null:
		return
	_econ_rebuild_t -= delta
	_econ_t -= delta
	if _econ_t <= 0.0:
		_econ_t = 1.0
		var fl: Dictionary = gw.guide.flows(gw.player)
		if _econ_signature(fl) != _econ_sig:
			_econ_dirty = true
		else:
			_econ_fill(fl)
	if _econ_dirty and _econ_rebuild_t <= 0.0 and not _finger_down():
		_econ_rebuild_t = 1.5
		open_economy()




func _econ_signature(fl: Dictionary) -> String:
	var sig: String = "%s|" % plan_closed
	for ch: Dictionary in fl.get("chains", []):
		sig += "%s:%s;" % [String(ch.get("id", "")), String(ch.get("icon", ""))]
	return sig




func open_hub(pg: int) -> void :
	if not _hub_ok():
		return
	if econ_hub != null and is_instance_valid(econ_hub) and not bool(econ_hub.get("closing")):
		econ_hub.call("show_page", pg, true)
		return
	close_panel()
	var vp: Vector2 = root.get_viewport_rect().size
	var sheet_h: float = floorf(vp.y * 0.62) - BuildPanel.TAB_H


	if econ_hub != null and is_instance_valid(econ_hub):
		if econ_hub.has_method("reopen") and int(econ_hub.get_meta("loc_gen", -1)) == Loc.gen and absf(econ_hub.custom_minimum_size.y - sheet_h) < 0.5 and bool(econ_hub.call("reopen")):
			ui24_open(econ_hub)
			if root.size.x < 700:
				bottom_panel.visible = false
			econ_hub.call("show_page", pg, false)
			econ_hub.modulate.a = 0.0
			var tw0: Tween = econ_hub.create_tween()
			tw0.tween_property(econ_hub, "modulate:a", 1.0, 0.12)
			UiKit.snd("ui_open")
			return
		econ_hub.queue_free()
		econ_hub = null
	var hub: Control = EconHubScript.new()
	hub.name = "EconHub"
	var is_pc: bool = root.size.x >= 700
	var final_h: float = minf(410.0, root.size.y - 140.0) if is_pc else sheet_h
	hub.call("setup", self, final_h, _safe_margins().y if not is_pc else 0.0)
	hub.connect("action", _on_hub_action)
	hub.set_meta("loc_gen", Loc.gen)
	econ_hub = hub
	ui24_open(hub)
	if is_pc:
		var hub_w: float = minf(620.0, root.size.x - 40.0)
		hub.custom_minimum_size = Vector2(hub_w, final_h)
		hub.size = Vector2(hub_w, final_h)
		hub.position = Vector2(roundf((root.size.x - hub_w) * 0.5), roundf((root.size.y - final_h - 70.0) * 0.5 + 20.0))
		root.add_child(hub)
	else:
		holder.add_child(hub)
		bottom_panel.visible = false
	hub.call("show_page", pg, false)
	hub.modulate.a = 0.0
	var tw: Tween = hub.create_tween()
	tw.tween_property(hub, "modulate:a", 1.0, 0.12)
	UiKit.snd("ui_open")


func _on_hub_action(nm: String) -> void :
	var open: bool = econ_hub != null and is_instance_valid(econ_hub)
	match nm:
		"close":
			if open:
				econ_hub.call("close")
		"trade":
			if open:
				econ_hub.call("close")
			action.emit("trade")
		"plan_toggle":
			action.emit("plan_toggle")
		_:
			if nm.begins_with("plan_go:") or nm.begins_with("fac_go:") or nm.begins_with("dep_go:"):
				if open:
					econ_hub.call("close")
				action.emit(nm)
