extends "res://ui/hud/hud_dip.gd"


func _build_army24() -> void :
	_dip_warm = load(DIP_SHEET_PATH)
	var ds: Variant = load("res://ui/ui24/army_dock.gd")
	var cs: Variant = load("res://ui/ui24/cmd_sheet.gd")
	var ps: Variant = load("res://ui/ui24/map_pennants.gd")
	if not (ds is GDScript and cs is GDScript and ps is GDScript):
		push_warning("UI24 army: scripts missing, the old armies bar stays")
		return
	army_dock = (ds as GDScript).new()
	army_dock.mount(self)
	cmd_sheet = (cs as GDScript).new()
	cmd_sheet.mount(self, army_dock)
	army_pennants = (ps as GDScript).new()
	army_pennants.mount(self, army_dock)
	var ux: Variant = load("res://ui/ui24/army_ux.gd")
	if ux is GDScript:
		army_ux = (ux as GDScript).new()
		army_ux.mount(self, army_dock)
	armies_bar_old = armies_bar
	armies_bar = army_dock.panel


func open_navy_yard(f: Facility) -> void :
	if f == null or gw.get("navy") == null:
		return
	if navy_yard == null or not is_instance_valid(navy_yard):
		var s: Variant = load("res://ui/ui24/navy_yard.gd")
		if not (s is GDScript):
			return
		navy_yard = (s as GDScript).new()
		navy_yard.mount(self)
	close_panel()
	navy_yard.open(f)


func open_navy_dock(ship: Variant) -> void :
	if gw.get("navy") == null:
		return
	if navy_dock == null or not is_instance_valid(navy_dock):
		var s: Variant = load("res://ui/ui24/navy_dock.gd")
		if not (s is GDScript):
			return
		navy_dock = (s as GDScript).new()
		navy_dock.mount(self)
	close_panel()
	navy_dock.open_dock(ship as Ship)



func _navy_key_icons() -> void :
	if _navy_icons_done or gw == null:
		return
	var a: Variant = gw.get("atlas_navy1")
	if not (a is SpriteAtlas) or not (a as SpriteAtlas).has("icon_navbase"):
		return
	_navy_icons_done = true
	if tabs.size() > 6 and (a as SpriteAtlas).has("icon_fleet"):
		var ti: TextureRect = (tabs[6] as Node).get_node_or_null("Icon") as TextureRect
		if ti != null:
			ti.texture = (a as SpriteAtlas).region("icon_fleet")
	for it: Array in [["navbase", "icon_navbase"], ["fleet", "icon_fleet"], ["coastal_asm", "icon_coastal_asm"], ["ship_cr", "icon_ship_cr"]]:
		var b: Button = keys.get(String(it[0])) as Button
		var ic: TextureRect = UiKit.slot_icon(b) if b != null else null
		if ic != null and (a as SpriteAtlas).has(String(it[1])):
			ic.texture = (a as SpriteAtlas).region(String(it[1]))
			var k: float = maxf(1.0, floorf((b.custom_minimum_size.x - 10.0) / 24.0 * 4.0) / 4.0)
			ic.custom_minimum_size = (Vector2(24, 24) * k).round()
			ic.size = ic.custom_minimum_size
			ic.pivot_offset = ic.size * 0.5
			ic.position = ((b.size - ic.size) * 0.5).round()


func _army24_ok() -> bool:
	return army_dock != null and is_instance_valid(army_dock)




func _build_armies() -> void :
	armies_bar = PanelContainer.new()
	armies_bar.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 4, 4))
	armies_bar.visible = false
	armies_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(armies_bar)

	armies_row = HFlowContainer.new()
	armies_row.add_theme_constant_override("h_separation", 4)
	armies_row.add_theme_constant_override("v_separation", 4)

	var asc: = ScrollContainer.new()
	asc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	asc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	armies_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asc.add_child(armies_row)
	armies_bar.add_child(asc)
	_build_army24()


func toggle_armies() -> void :
	if army_ux != null and is_instance_valid(army_ux):
		army_ux.toggle_list()
		return
	if _army24_ok():
		army_dock.toggle()
		return
	armies_open = not armies_open
	set_key_pressed("armies", armies_open)
	_arm_sig = ""
	_arm_t = 0.0
	UiKit.snd("ui_open" if armies_open else "ui_close")


func _armies_process(delta: float) -> void :
	if _army24_ok():
		_army24_process()
		return
	if armies_bar == null:
		return
	var p: Country = gw.player
	var busy_ui: bool = (panel != null and is_instance_valid(panel)) or (confirm_panel != null and confirm_panel.visible)
	var want: bool = armies_open and p != null and gw.get("ops") != null and not busy_ui
	armies_bar.visible = want
	if not want:
		return
	armies_bar.custom_minimum_size.x = root.size.x - 8.0
	var y: float = holder.position.y - armies_bar.size.y - 4.0
	if ops_panel.visible:
		y = minf(y, ops_panel.global_position.y - armies_bar.size.y - 4.0)
	armies_bar.position = Vector2(4.0, roundf(y))
	_arm_t -= delta
	if _arm_t > 0.0:
		return
	_arm_t = 0.5
	var sm: Dictionary = gw.ops.command_summary(p.id)
	var sel: Facility = gw.selected_facility()
	var sig: String = str(sel.id if sel != null else -1) + "|%s|" % arm_all_open
	for a: Dictionary in sm.get("armies", []):
		var op: Dictionary = a.get("op", {})
		sig += "%d:%d:%d:%s;" % [int(a["fid"]), int(a["n"]), int(a["stance"]), String(op.get("name", ""))]
	if sig == _arm_sig:
		return
	_arm_sig = sig
	for ch: Node in armies_row.get_children():
		ch.queue_free()
	var armies: Array = sm.get("armies", [])
	var nrows: int = 1 if arm_all_open else ceili(float(armies.size() + 1) / 4.0)
	(armies_row.get_parent() as Control).custom_minimum_size.y = float(mini(maxi(nrows, 1), 3)) * 48.0 - 4.0
	if armies.is_empty():
		armies_row.add_child(UiKit.lbl("  Нет армий — постройте казармы", 10, UiKit.MUTED, 2))
		return
	var all_auto: int = -1
	for a2: Dictionary in armies:
		var st: int = int(a2["stance"])
		all_auto = st if all_auto == -1 or all_auto == st else -2
	var cw: float = floorf((root.size.x - 8.0 - 8.0 - 12.0 - (12.0 if nrows > 3 else 0.0)) / 4.0)
	if arm_all_open:
		cw = floorf((root.size.x - 8.0 - 8.0 - 16.0 - 48.0 - 4.0) / 4.0)
	var ab: Button = UiKit.big(Loc.t("ВСЕ:") if arm_all_open else Loc.t("ВСЕ…"), "gold" if arm_all_open else "stone", "", 44.0, 10)
	ab.custom_minimum_size.x = 48.0 if arm_all_open else cw
	ab.pressed.connect( func() -> void :
		arm_all_open = not arm_all_open
		_arm_sig = ""
		_arm_t = 0.0)
	armies_row.add_child(ab)
	if arm_all_open:
		var ix: int = 0
		for it: Array in [["ЖДУТ", "arm_all_set:0", "blue"], ["ДЕРЖАТ", "arm_all_set:1", "green"], ["НАСТУПАЮТ", "arm_all_set:2", "red"], ["ДВИЖЕНИЕ", "move_all", "gold"]]:
			var on_now: bool = ix == all_auto
			ix += 1
			var sb: Button = UiKit.big(("✓" if on_now else "") + String(it[0]), String(it[2]), "", 44.0, 8)
			sb.custom_minimum_size.x = 0.0
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var act: String = String(it[1])
			sb.pressed.connect( func() -> void :
				arm_all_open = false
				_arm_sig = ""
				action.emit(act))
			armies_row.add_child(sb)
		return
	for a3: Dictionary in armies:
		var op3: Dictionary = a3.get("op", {})
		var st3: int = int(a3["stance"])
		var tag: String = ["", " · ОБ", " · АТ"][st3]
		if not op3.is_empty():
			tag = Loc.t(" · ДВ")
		var txt: String = Loc.t("%s %s\n%d бойц.%s") % [Loc.no(int(a3["no"])) if int(a3["no"]) > 0 else Loc.t("НОВ."), String(a3["name"]).left(6), int(a3["n"]), tag]
		var is_sel: bool = sel != null and sel.id == int(a3["fid"])
		var b: Button = UiKit.big(txt, "gold" if is_sel else ("red" if st3 == 2 else ("green" if st3 == 1 else "blue")), "", 44.0, 9)
		b.custom_minimum_size.x = cw
		b.clip_text = true
		var fid: int = int(a3["fid"])
		b.pressed.connect( func() -> void : action.emit("arm_sel:%d" % fid))
		armies_row.add_child(b)




func _army24_process() -> void :
	_navy_key_icons()
	if navy_dock == null and gw != null and gw.get("navy") != null and not gw.navy.ships.is_empty():


		var nds: Variant = load("res://ui/ui24/navy_dock.gd")
		if nds is GDScript:
			navy_dock = (nds as GDScript).new()
			navy_dock.mount(self)
	if armies_bar_old != null:
		armies_bar_old.visible = false
	if gw.player != _arm_player:
		_arm_player = gw.player
		army_dock.reset()
		if cmd_sheet != null and is_instance_valid(cmd_sheet):
			cmd_sheet.close()
	if not bool(army_dock.is_open):
		return
	var p: Country = gw.player
	var busy_ui: bool = ops_panel.visible or (panel != null and is_instance_valid(panel)) or p == null or p.eliminated
	var show: bool = not busy_ui
	if army_dock.visible != show:
		army_dock.visible = show
		army_dock._host_show(show)
		if show:
			army_dock.refresh()
			if ui24_sheet == army_dock and bottom_panel != null:
				bottom_panel.visible = false
	if army_dock.visible and army_dock.has_method("_restack_cmd"):
		army_dock._restack_cmd()
	if String(army_dock.placing) != "" and not army_dock.is_visible_in_tree():
		army_dock.cancel_place()
