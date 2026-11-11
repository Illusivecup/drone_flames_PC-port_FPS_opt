extends "res://ui/hud/hud_cards.gd"




func push_news(text: String, col: String) -> void :
	if not news_on:
		return
	if lane != null and is_instance_valid(lane):

		lane.call("ambient", text, CalmScript.news_level(text, gw.player.name if gw != null and gw.player != null else ""), Palette.c(col).lightened(0.15))
		return
	news_queue.append([text, col])
	if news_queue.size() > 6:
		news_queue.pop_front()


func _news_tick() -> void :
	if lane != null and is_instance_valid(lane):
		_lane_sync(get_process_delta_time())
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if panel != null and is_instance_valid(panel):
		news_panel.visible = false
		news_until = 0.0
		return
	if now < news_until:
		return
	if news_queue.is_empty():
		news_panel.visible = false
		return

	if (toast_panel != null and toast_panel.visible) or (prompt_panel != null and prompt_panel.visible):
		news_panel.visible = false
		return
	var n: Array = news_queue.pop_front()
	news_label.text = String(n[0])
	news_label.add_theme_color_override("font_color", Palette.c(String(n[1])).lightened(0.15))
	news_panel.visible = true
	UiKit.pop_in(news_panel, 0.95, 0.15)
	news_until = now + 4.0


func war_flash(text: String, kind: String = "") -> void :
	if lane != null and is_instance_valid(lane):
		var sub: String = ""
		if kind == "war":
			sub = Loc.t("тап — к линии фронта")
		elif kind == "lost":
			sub = Loc.t("тап — к месту боя")
		lane.call("push", "war", {"title": text, "sub": sub})
		return
	war_banner.text = text
	war_banner.visible = true
	war_banner.modulate.a = 1.0
	war_banner.pivot_offset = Vector2(root.size.x * 0.5, war_banner.size.y * 0.5)
	war_banner.scale = Vector2(1.6, 1.6)
	var tw: Tween = war_banner.create_tween()
	tw.tween_property(war_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	war_until = Time.get_ticks_msec() / 1000.0 + 3.0





func _on_tab_tap(p: int) -> void :
	UiKit.snd("ui_tab")
	var again: bool = p == _page
	var dock_was: bool = armies_open
	var had: Control = ui24_sheet if ui24_open_now() else null


	var sheet_up: bool = had != null and is_instance_valid(had) and had.visible
	var card_up: bool = ops_panel.visible
	if card_up and main_node != null and main_node.has_method("drop_cards_for_sheet"):
		main_node.drop_cards_for_sheet()
	if again and not sheet_up and not (p == 4 and dock_was) and not _tut_on() and not card_up:
		set_keys_folded( not keys_collapsed)
		return
	if keys_collapsed:
		set_keys_folded(false)
	if had != null and is_instance_valid(had) and had.visible and had.has_method("close"):
		had.call("close")
	_select_page(p, true)
	_army_tab_hook(p, again and dock_was)
	if p == 4 and armies_open:
		show_tip(String(PAGE_TITLES[4]), "Армии внизу · ещё тап по АРМИЯ — постройки")





func _army_tab_hook(p: int, second_tap: bool) -> void :
	if p == 4 and not second_tap:
		if not armies_open and gw != null and gw.player != null and gw.mil != null and gw.mil.has_kind(gw.player.id, Facility.Kind.BARRACKS):
			toggle_armies()
	elif armies_open:
		toggle_armies()




func _ultimatum_key() -> void :
	open_ultimatum()


func _on_lane_action(nm: String) -> void :
	match nm:
		"diplomacy_pending":
			UiKit.snd("ui_click")
			var top: Array = (gw.diplo.pending_for_player() if gw.diplo != null and gw.player != null else []).filter(pending_urgent)
			if not top.is_empty() and String((top[0] as Dictionary).get("kind", "")) == "conference":
				var cs: Script = load("res://ui/ui24/conference_sheet.gd") as Script
				if cs != null and bool(cs.call("open_for", main_node, int(String(top[0]["id"]).substr(1)))):
					return

			if lane.call("chip_style") == "red":
				open_ultimatum()
			else:
				open_diplomacy()
		"war_focus":
			action.emit("battle_cam")
		"inbox":
			open_inbox()
		"mystate":
			open_my_state()
		_ when nm.begins_with("mystate:"):
			var sc: int = int(nm.get_slice(":", 1))
			var scn: Country = gw.country_by_id(sc) if gw != null else null
			if scn != null and not scn.eliminated and gw.player != null and not gw.player.eliminated:
				dip_open = sc
				open_diplomacy()





func _lane_sync(delta: float) -> void :
	if status_watch == null:
		status_watch = (load("res://ui/ui24/status_watch.gd") as GDScript).new(self)
	status_watch.call("tick", delta)
	for c: CanvasItem in [news_panel, hint_panel, toast_panel, war_banner]:
		if c != null and c.visible:
			c.visible = false
	if advisor != null and advisor.visible:
		if advisor_lbl.text != "":
			lane.call("push", "tip", {"title": advisor_lbl.text, "icon": "icon_hint"})
		advisor.visible = false

	var win: bool = panel != null and is_instance_valid(panel) and not (ui24_open_now() and ui24_sheet == panel)
	var tut: Object = get_parent().get("tutorial") if get_parent() != null else null
	var tut_card: bool = tut != null and bool(tut.get("active")) and not win and not (ops_panel != null and ops_panel.visible)
	var cfm: bool = confirm_panel != null and confirm_panel.visible
	lane.call("set_compact", win or ui24_open_now() or tut_card or cfm or (ops_panel != null and ops_panel.visible))
	var db: float = -1.0

	var conf_up: bool = panel_kind == "conference" and ui24_open_now() and ui24_sheet == panel
	if conf_up and not win:
		var mo0: Variant = lane.get("_more")
		db = roundf((ui24_sheet as Control).global_position.y - 6.0 - (22.0 if mo0 is Control and (mo0 as Control).visible else 0.0))
	if win:


		db = holder.position.y
		if ops_panel != null and ops_panel.visible:
			db = minf(db, ops_panel.global_position.y)
		if cfm:
			db = minf(db, confirm_panel.global_position.y)
		var mo: Variant = lane.get("_more")
		db = roundf(db - 6.0 - (22.0 if mo is Control and (mo as Control).visible else 0.0))
	if absf(float(lane.get("dock_bottom")) - db) > 0.5:
		lane.set("dock_bottom", db)


	var soft_hold: bool = win
	if not soft_hold and ui24_open_now() and lane is Control:
		var sr: Rect2 = (ui24_sheet as Control).get_global_rect()
		var ly: float = (lane as Control).global_position.y
		soft_hold = sr.position.y < ly + 52.0 and sr.end.y > ly
	if bool(lane.get("hold_soft")) != soft_hold:
		lane.set("hold_soft", soft_hold)
	var conf_hold: bool = conf_up and bool(ui24_sheet.get("_mm_on"))
	if lane.get("hold_conf") != null and bool(lane.get("hold_conf")) != conf_hold:
		lane.set("hold_conf", conf_hold)
	if win != _lane_win:
		_lane_win = win
		if win:
			lane.move_to_front()
	_lane_t -= delta
	if _lane_t <= 0.0:
		_lane_t = 0.25
		_pending_chip()



func open_inbox() -> void :
	if gw == null or gw.player == null:
		return
	if inbox == null or not is_instance_valid(inbox):
		inbox = InboxScript.new()
		inbox.call("mount", self)
	close_panel()
	inbox.call("open")




func _chat_dot() -> void :
	var net: NetSession = main_node.get("net") as NetSession if main_node != null else null
	if net == null or net.chat == null:
		return
	if not net.chat.incoming.is_connected(_on_chat_in):
		net.chat.incoming.connect(_on_chat_in)
	var b: Button = keys.get("diplomacy") as Button
	if b == null or not is_instance_valid(b):
		return
	var dot: ColorRect = b.get_node_or_null("ChatDot") as ColorRect
	var on: bool = net.in_match and net.chat.unread_total() > 0
	if dot == null:
		if not on:
			return
		dot = ColorRect.new()
		dot.name = "ChatDot"
		dot.color = UiKit.OUTLINE
		dot.size = Vector2(10, 10)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inner: = ColorRect.new()
		inner.color = Color("ffb000")
		inner.position = Vector2(1, 1)
		inner.size = Vector2(8, 8)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_child(inner)
		b.add_child(dot)
	dot.position = Vector2(3, 3)
	dot.visible = on


func _on_chat_in(cid: int, text: String) -> void :
	if lane == null or gw == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_chat_lane_t.get(cid, -100.0)) < 20.0:
		return
	_chat_lane_t[cid] = now
	var c: Country = gw.country_by_id(cid)
	var who: String = Loc.name(c.name).to_upper() if c != null else Loc.t("ИГРОК")
	var short: String = text if text.length() <= 40 else text.left(39) + "…"
	lane.call("push", "msg", {"title": "%s: %s" % [who, short], "ttl": 3.0})




func _pending_chip() -> void :
	var list: Array = []
	if gw != null and gw.player != null and gw.diplo != null and gw.diplo.has_method("pending_for_player") and not gw.player.eliminated:
		list = gw.diplo.pending_for_player()
	BuildPanel.set_key_badge(keys.get("diplomacy") as Button, list.size())
	_chat_dot()


	var urgent: Array = list.filter(pending_urgent) if GameConfig.notif_mode < 2 else []
	lane.call("set_inbox", list.size() - urgent.size())
	if panel_kind == "conference" and ui24_open_now():
		urgent = urgent.filter( func(x: Dictionary) -> bool: return String(x.get("kind", "")) != "conference")
	list = urgent
	if list.is_empty():
		_pend_total.clear()
		if bool(lane.call("has_kind", "ult")):
			lane.call("remove_kind", "ult")
		return
	var it: Dictionary = list[0]
	var dem: bool = false
	for x: Dictionary in list:
		if String(x.get("kind", "")) == "demand":
			it = x
			dem = true
			break

	if not dem:
		for x: Dictionary in list:
			if int(x.get("stage", 0)) >= 3:
				it = x
				break
	var id: String = String(it.get("id", ""))
	var left: float = float(it.get("left", 0.0))
	var total: float = maxf(float(_pend_total.get(id, 0.0)), left)
	_pend_total[id] = total
	var c: Country = gw.country_by_id(int(it.get("from", 0)))
	var cname: String = Loc.name(c.name).to_upper() if c != null else "?"
	var d: Dictionary = {"left": left, "count": list.size()}
	if dem:
		var sub: String = ""
		for dd: Dictionary in gw.diplo.demands:
			if "d%d" % int(dd["id"]) == id:
				total = maxf(1.0, float(dd.get("until", 0.0)) - float(dd.get("made", 0.0)))
				match String(dd.get("kind", "")):
					"money":
						sub = Loc.t("требует %s") % EconKit.num(int(dd.get("n", 0)))
					"res":
						sub = Loc.t("требует %s ×%d") % [Loc.t(String(Economy.RES_NAMES.get(String(dd.get("res", "")), "")).to_lower()), int(dd.get("n", 0))]
					"deposit":
						sub = Loc.t("требует землю с залежью")
					"break_alliance":
						sub = Loc.t("требует разорвать союз")
					"cancel_visa":
						sub = Loc.t("требует отменить безвиз")
		d["title"] = Loc.t("УЛЬТИМАТУМ · %s") % cname
		d["sub"] = Loc.t(sub) + (Loc.t(" · отказ = война") if String(it.get("conseq", "")) == "war" else Loc.t(" · отказ = эмбарго"))
		d["style"] = "red"
		d["icon"] = "icon_dip_pending"
	else:
		var head: String = String({"offer": "ПРЕДЛОЖЕНИЕ", "treaty": "ДОГОВОР", "trade": "ЗАПРОС", "surrender": "СДАЁТСЯ", "conference": "КОНФЕРЕНЦИЯ"}.get(String(it.get("kind", "")), "ДИПЛОМАТИЯ"))
		var t: String = Loc.msg(it.get("text", ""))
		for sep: String in ["предлагает: ", "просит "]:
			if t.contains(sep):
				t = t.substr(t.find(sep) + sep.length())
				break
		d["title"] = head + " · " + cname
		d["sub"] = t.get_slice(".", 0).to_lower()
		if String(it.get("kind", "")) in ["surrender", "conference"] and t.contains(" — "):
			d["sub"] = t.substr(t.find(" — ") + 3).trim_suffix(".")
		d["style"] = "blue"
		d["icon"] = String(it.get("icon", "icon_dip_pending"))
		if it.has("lane_title"):
			d["title"] = String(it["lane_title"])
			d["sub"] = String(it.get("lane_sub", d["sub"]))
			d["style"] = String(it.get("lane_style", d["style"]))
	d["total"] = total
	lane.call("push", "ult", d)
