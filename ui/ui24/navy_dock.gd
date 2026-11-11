extends Control












const U = preload("res://ui/ui24/arm_kit.gd")
const NS = preload("res://game/navy_strike.gd")
const HT = preload("res://ui/ui24/hold_tip.gd")
const HULL_ICON: Array[String] = ["icon_hull_light", "icon_hull_medium", "icon_hull_heavy"]
const KIND_TEXT: Dictionary = {"move": "ДВИЖЕНИЕ", "patrol": "ПАТРУЛЬ", "hunt": "ТОПИТЬ КОНВОИ", "escort": "ОХРАНА КОНВОЕВ", "asm": "ПКР ЗАЛП", "cm": "КР УДАР", "blockade": "БЛОКАДА ПОРТА"}
const KIND_ICON: Dictionary = {"move": "icon_move", "patrol": "icon_patrol", "hunt": "icon_hunt_convoy", "escort": "icon_escort", "asm": "icon_ash_ammo", "cm": "icon_cruise_ammo", "blockade": "icon_cause_blockade"}
const KIND_HINT: Dictionary = {"move": "Коснитесь цели или ведите от кораблей", "patrol": "Коснитесь района патруля", "hunt": "Коснитесь района охоты", 
	"escort": "Коснитесь своего конвоя или района", "asm": "Коснитесь вражеского корабля", "cm": "Коснитесь цели: суша, мост, вода", "blockade": "Коснитесь чужого порта"}

const STATUS_COL: Dictionary = {"ЗА БК": "gold", "В РЕМОНТ": "gold", "БОЙ": "red", "ТОНЕТ": "red", "ИДЁТ": "gold", "ПЕРЕХОД": "gold", "ПАТРУЛЬ": "gold", "ОХОТА": "gold", "КОНВОЙ": "gold", "НА БАЗУ": "gold"}
const ROUTE_GRAB_PX: float = 70.0
const SALVO: Array = [2, 6, 8]

var hud: Node
var gw: GameWorld
var panel: PanelContainer
var dock: VBoxContainer
var is_open: bool = false
var mode: String = "list"
var tab_fid: int = 0
const FREE_TAB: int = -1
var sel_sid: int = 0
var selecting: bool = false
var checked: Dictionary = {}
var placing: String = ""
var target: Vector2 = Vector2.INF
var route_pts: PackedVector2Array = PackedVector2Array()
var route_wp: Vector2 = Vector2.INF
var legs: Dictionary = {}
var pv: Dictionary = {}

var head: HBoxContainer
var strip_sc: ScrollContainer
var strip: HBoxContainer
var sel_btn: Button
var sel_lbl: Label
var list_sc: ScrollContainer
var list: VBoxContainer
var empty_lbl: Label
var rows: Dictionary = {}
var bar: HBoxContainer
var sbar: HBoxContainer
var bar_btns: Dictionary = {}
var _chips_sig: String = ""
var collect_btn: Button
var _fresh_seen: int = 0

var card: VBoxContainer
var card_refs: Dictionary = {}

var place_box: HBoxContainer
var place_t1: Label
var place_t2: Label
var place_ic: TextureRect
var confirm: PanelContainer
var confirm_ok: Button

var pop: PanelContainer
var scrim: Control
var sheet: PanelContainer
var sheet_state: Dictionary = {}
var sheet_refs: Dictionary = {}
var map_layer: Control
var _rt: float = 0.0
var _holds: Dictionary = {}
var _player: Object = null
var _hint_ms: int = -100000
var quick_marks: Array = []
var _war_arm: Array = [0, 0]




func _nt(n: String) -> Texture2D:
	var a: Variant = gw.get("atlas_navy1")
	if a is SpriteAtlas and (a as SpriteAtlas).has(n):
		return (a as SpriteAtlas).region(n)
	return U.tex(n)


func _icon(n: String, px: float) -> TextureRect:
	var r: = TextureRect.new()
	r.texture = _nt(n)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _cap(t: String) -> String:
	return t.left(1).to_upper() + t.substr(1)


static func pl(n: int, one: String, few: String, many: String) -> String:
	var m10: int = n % 10
	var m100: int = n % 100
	if m10 == 1 and m100 != 11:
		return "%d %s" % [n, one]
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return "%d %s" % [n, few]
	return "%d %s" % [n, many]


func _nv() -> Navy:
	return gw.get("navy") as Navy


func _fl() -> Object:
	var nv: Navy = _nv()
	return nv.get("fl") as Object if nv != null else null



func _api(method: String, args: Array) -> Variant:
	var nv: Navy = _nv()
	if nv == null:
		return null
	if nv.has_method(method):
		return nv.callv(method, args)
	var fl: Object = _fl()
	if fl != null and fl.has_method(method):
		return fl.callv(method, args)
	return null


func fleets() -> Array:
	if gw.player == null:
		return []
	var r: Variant = _api("fleets_of", [gw.player.id])
	return r if r is Array else []


func fleet(fid: int) -> Dictionary:
	for f: Dictionary in fleets():
		if int(f["id"]) == fid:
			return f
	return {}


func my_ships() -> Array:
	var nv: Navy = _nv()
	if nv == null or gw.player == null:
		return []
	var out: Array = []
	for s: Ship in nv.ships_of(gw.player.id, true):
		out.append(s)
	out.sort_custom( func(a: Ship, b: Ship) -> bool: return a.fleet < b.fleet if a.fleet != b.fleet else a.id < b.id)
	return out


func tab_ships() -> Array:
	if tab_fid == 0:
		return my_ships()
	if tab_fid == FREE_TAB:
		return free_ships()
	return my_ships().filter( func(s: Ship) -> bool: return _fleet_key(s) == tab_fid)




func free_ships() -> Array:
	var out: Array = my_ships().filter( func(s: Ship) -> bool: return _fleet_key(s) == 0)
	out.sort_custom( func(a: Ship, b: Ship) -> bool: return a.fresh and not b.fresh if a.fresh != b.fresh else a.id < b.id)
	return out



func fresh_count() -> int:
	return free_ships().filter( func(s: Ship) -> bool: return s.fresh).size()




func _fleet_cmd(method: String, args: Array, cb: Callable = Callable()) -> void :
	var mn: Node = hud.main_node if hud != null else null
	if mn != null and mn.has_method("_sim"):
		mn.call("_sim", "navy", method, args, cb)
		return
	var r: Variant = _api(method, args)
	if cb.is_valid():
		cb.call(r)




func _fleet_key(s: Ship) -> int:
	if s.fleet != 0:
		return s.fleet
	return int(s.ord.get("rejoin", 0))


func order_ships() -> Array:
	if mode == "ship":
		var s: Ship = _nv().ship(sel_sid) if _nv() != null else null
		return [s] if s != null and s.alive() else []
	if selecting:
		return tab_ships().filter( func(s: Ship) -> bool: return checked.has(s.id))
	return tab_ships()


func fleet_color(fl: Dictionary) -> Color:
	var c: Variant = fl.get("color", Color.WHITE)
	return c if c is Color else U.color(int(c))


func status_of(s: Ship) -> String:
	if not s.alive():
		return "ТОНЕТ"
	if s.refit == "repair":
		return "РЕМОНТ"
	if s.refit == "rearm":
		return "ПОГРУЗКА"
	if gw.game_time - s.hit_t < 5.0 or (s.tgt != 0 and gw.game_time - s.shot_t < 4.0):
		return "БОЙ"
	if s.fleet == 0 and s.ord.has("rejoin") and String(s.ord.get("k", "")) == "return":
		return "ЗА БК" if s.has_mod("ash") and int(s.ammo.get("asm", 0)) == 0 else "В РЕМОНТ"
	var o: Dictionary = s.ord
	if s.fleet != 0:
		o = fleet(s.fleet).get("order", {})
	var k: String = String(o.get("k", ""))
	if s.fleet == 0 and k == "return":
		var need: Dictionary = _nv()._missing(s) if _nv().has_method("_missing") else {}
		if int(need.get("asm", 0)) + int(need.get("cm", 0)) > 0:
			return "ЗА БК"
		if s.hp < s.hp_max - 1.0 or not s.fires.is_empty():
			return "В РЕМОНТ"
	if k != "" and k != "stop":
		return {"move": "ПЕРЕХОД", "patrol": "ПАТРУЛЬ", "hunt": "ОХОТА", "escort": "КОНВОЙ", "return": "НА БАЗУ", "blockade": "БЛОКАДА"}.get(k, "ИДЁТ")
	if s.state == Ship.State.SAIL:
		return "ИДЁТ"
	if _nv().near_base(s) != null:
		return "У БАЗЫ"
	return "СТОИТ"




func mount(h: Node) -> void :
	hud = h
	gw = h.gw
	name = "NavyDock"
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.root.add_child(self)
	process_priority = 103
	visible = false
	panel = PanelContainer.new()
	var psb: StyleBox = UiKit.sb("wb_panel", 6, 4)
	psb.content_margin_bottom = 5.0 + h._safe_margins().y
	panel.add_theme_stylebox_override("panel", psb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	dock = VBoxContainer.new()
	dock.add_theme_constant_override("separation", 4)
	panel.add_child(dock)
	_build_head()
	_build_list()
	_build_bars()
	_build_card()
	_build_place()
	var tr: Control = h.tab_row
	var par: Node = tr.get_parent() if tr != null else h.holder
	par.add_child(panel)
	if tr != null and tr.get_parent() == par:
		par.move_child(panel, tr.get_index() + 1)
	map_layer = (load("res://ui/ui24/navy_map.gd") as GDScript).new() if ResourceLoader.exists("res://ui/ui24/navy_map.gd") else null
	if map_layer != null:
		map_layer.call("mount", h, self)


func _btn_icon(text: String, icon_n: String, colour: String, tri: bool = false) -> Button:
	var b: Button = UiKit.big("", colour, "", 44.0, 9)
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb: = VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_top = 3
	vb.offset_bottom = -2
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)
	var ic: TextureRect = _icon(icon_n, 18)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ic)
	var lr: = HBoxContainer.new()
	lr.alignment = BoxContainer.ALIGNMENT_CENTER
	lr.add_theme_constant_override("separation", 2)
	lr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lr)
	var lb: Label = UiKit.lbl(text, 9, UiKit.TEXT, 2, 3)
	lr.add_child(lb)
	if tri:
		var t: = Control.new()
		t.custom_minimum_size = Vector2(7, 8)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.draw.connect( func() -> void : U.draw_tri(t, Vector2(3.5, 4), 3.0, UiKit.TEXT))
		lr.add_child(t)
	b.set_meta("lb", lb)
	b.set_meta("ic", ic)
	return b


func _build_head() -> void :
	head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	head.custom_minimum_size = Vector2(0, 44)
	dock.add_child(head)
	var back: Button = UiKit.arrow(true)
	back.name = "NavyBack"
	back.pressed.connect(exit_mode)
	head.add_child(back)
	strip_sc = ScrollContainer.new()
	strip_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	strip_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip_sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_sc.custom_minimum_size = Vector2(0, 46)
	head.add_child(strip_sc)
	strip = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 5)
	strip_sc.add_child(strip)
	sel_lbl = UiKit.lbl("Выбрано: 0", 15, UiKit.TITLE, 3, 4)
	sel_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sel_lbl.visible = false
	head.add_child(sel_lbl)
	sel_btn = UiKit.slot("icon_multi_select", true, 44.0)
	if not U.native("icon_multi_select"):
		UiKit.set_slot_icon(sel_btn, "icon_ok")
	sel_btn.toggled.connect( func(on: bool) -> void :
		if on != selecting:
			set_selecting(on))
	head.add_child(sel_btn)
	var close_btn: Button = UiKit.close_btn(44.0)
	close_btn.name = "NavyClose"
	close_btn.tooltip_text = Loc.t("Закрыть окно флота")
	close_btn.pressed.connect(close)
	head.add_child(close_btn)


func _chip(text: String, sub: String, col: Variant, active: bool, cb: Callable, long_cb: Callable = Callable()) -> Button:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for st: String in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, UiKit.sb("wb_card" if active else "wb_btn_stone", 6, 3))
	for st2: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st2, UiKit.sb("wb_card" if active else "wb_btn_stone_p", 6, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var hb: = HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 6
	hb.offset_right = -6
	hb.add_theme_constant_override("separation", 5)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	if col is Color:
		hb.add_child(_icon("icon_fleet", 22))
	var vb: = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", -1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	vb.add_child(UiKit.lbl(text, 11, UiKit.GOLD if active else UiKit.TEXT, 2, 3))
	vb.add_child(UiKit.lbl(sub, 9, UiKit.MUTED, 2, 2))
	var w: float = maxf(UiKit.f_black.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, UiKit.f_black.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x)
	b.custom_minimum_size.x = ceilf(w + 20.0 + (27.0 if col is Color else 0.0))
	if col is Color:
		var band: = ColorRect.new()
		band.color = col
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(band)
		b.resized.connect( func() -> void :
			band.position = Vector2(5, b.size.y - 6)
			band.size = Vector2(b.size.x - 10, 3))
	var hold: Array = [-1.0, false]
	b.button_down.connect( func() -> void :
		hold[0] = 0.0
		hold[1] = false)
	b.button_up.connect( func() -> void : hold[0] = -1.0)
	b.pressed.connect( func() -> void :
		if not bool(hold[1]):
			cb.call())
	if long_cb.is_valid():
		b.set_meta("hold", hold)
		b.set_meta("long", long_cb)
	UiKit.press_fx(b)
	return b


func _rebuild_chips() -> void :
	for ch: Node in strip.get_children():
		strip.remove_child(ch)
		ch.queue_free()
	var all: Array = my_ships()
	strip.add_child(_chip("ВСЕ", (Loc.n(all.size(), "%d корабль", "%d корабля", "%d кораблей") % (all.size())), null, tab_fid == 0, func() -> void : set_tab(0)))
	strip.add_child(_free_chip())
	for fl: Dictionary in fleets():
		var fid: int = int(fl["id"])
		var n: int = all.filter( func(s: Ship) -> bool: return _fleet_key(s) == fid).size()
		strip.add_child(_chip(Loc.uname(String(fl.get("name", "Флот"))).to_upper().left(12), (Loc.n(n, "%d корабль", "%d корабля", "%d кораблей") % (n)), fleet_color(fl), tab_fid == fid, 
			func() -> void :
				if tab_fid == fid and not selecting:
					fleet_menu(fid, strip)
				else:
					set_tab(fid), 
			func() -> void : fleet_menu(fid, strip)))
	var add: Button = UiKit.slot("icon_group_add", false, 44.0)
	if not U.native("icon_group_add"):
		UiKit.set_slot_icon(add, "icon_plus")
	add.pressed.connect( func() -> void :
		var ids: Array = checked.keys() if selecting else []
		open_fleet_sheet("new", 0, ids))
	strip.add_child(add)


func _build_list() -> void :
	list_sc = ScrollContainer.new()
	list_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock.add_child(list_sc)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_sc.add_child(list)
	collect_btn = _wide_btn("СОБРАТЬ ВСЕ СВОБОДНЫЕ ВО ФЛОТ", "", "icon_group_add", "gold")
	collect_btn.name = "NavyCollectFree"
	collect_btn.visible = false
	collect_btn.pressed.connect( func() -> void : open_to_fleet_menu(collect_btn, free_ships().map( func(s: Ship) -> int: return s.id)))
	list.add_child(collect_btn)
	empty_lbl = UiKit.lbl("", 10, UiKit.MUTED, 1, 2)
	empty_lbl.custom_minimum_size = Vector2(1, 56)
	empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_lbl.visible = false
	dock.add_child(empty_lbl)


func _build_bars() -> void :
	bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	dock.add_child(bar)
	for it: Array in [["move", "ДВИЖЕНИЕ", "icon_move", "gold", false], ["patrol", "ПАТРУЛЬ", "icon_patrol", "stone", false], 
			["convoy", "КОНВОИ", "icon_hunt_convoy", "stone", true], ["more", "ЕЩЁ", "icon_op_operation", "stone", true]]:
		var b: Button = _btn_icon(String(it[1]), String(it[2]), String(it[3]), bool(it[4]))
		var key: String = String(it[0])
		b.pressed.connect( func() -> void : _on_bar(key, b))
		HT.key(b, "n_" + key)
		bar.add_child(b)
		bar_btns[key] = b
	sbar = HBoxContainer.new()
	sbar.add_theme_constant_override("separation", 4)
	sbar.visible = false
	dock.add_child(sbar)
	for it2: Array in [["to_fleet", "ВО ФЛОТ", "icon_fleet", "gold", true], ["s_move", "ДВИЖЕНИЕ", "icon_move", "stone", false], 
			["s_more", "ЕЩЁ", "icon_op_operation", "stone", true], ["cancel", "ОТМЕНА", "icon_close", "stone", false]]:
		var b2: Button = _btn_icon(String(it2[1]), String(it2[2]), String(it2[3]), bool(it2[4]))
		var key2: String = String(it2[0])
		b2.pressed.connect( func() -> void : _on_bar(key2, b2))
		HT.key(b2, "n_" + {"s_move": "move", "s_more": "more"}.get(key2, key2))
		sbar.add_child(b2)
		bar_btns[key2] = b2




func _build_card() -> void :
	card = VBoxContainer.new()
	card.add_theme_constant_override("separation", 5)
	card.visible = false
	dock.add_child(card)
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 6)
	card.add_child(hr)
	var back: Button = UiKit.arrow(true)
	back.pressed.connect( func() -> void :
		cancel_place()
		set_mode("list"))
	hr.add_child(back)
	var hic: TextureRect = _icon("icon_hull_medium", 30)
	hr.add_child(hic)
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tv)
	var nm: Label = UiKit.lbl("", 15, UiKit.TITLE, 3, 4)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(nm)
	var fit: Label = UiKit.lbl("", 9, UiKit.MUTED, 1, 2)
	fit.clip_text = true
	fit.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(fit)
	var x: Button = UiKit.close_btn(44.0)
	x.pressed.connect(close)
	hr.add_child(x)

	var hp_row: = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	card.add_child(hp_row)
	var hp: = Control.new()
	hp.custom_minimum_size = Vector2(0, 10)
	hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.draw.connect( func() -> void : _draw_hp(hp, float(hp.get_meta("v", 1.0))))
	hp_row.add_child(hp)
	var hpl: Label = UiKit.lbl("", 10, UiKit.TEXT, 2, 3)
	hp_row.add_child(hpl)
	var stl: Label = UiKit.lbl("", 10, UiKit.GOLD, 2, 3)
	stl.custom_minimum_size = Vector2(76, 0)
	stl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(stl)

	var am: = HFlowContainer.new()
	am.add_theme_constant_override("h_separation", 5)
	am.add_theme_constant_override("v_separation", 3)
	card.add_child(am)
	var pills: Dictionary = {}
	for k: String in ["asm", "cm", "sam", "ciws", "decoy", "art"]:
		var pc: = PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UiKit.sb("wb_pill", 5, 2))
		var hb: = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 3)
		pc.add_child(hb)
		hb.add_child(_icon({"asm": "icon_ash_ammo_16", "cm": "icon_cruise_ammo_16", "sam": "icon_mod_sam_16", "ciws": "icon_mod_ciws_16", "decoy": "icon_mod_ciws_16", "art": "icon_mod_art_16"}[k], 14))
		var l: Label = UiKit.lbl("", 9, UiKit.TEXT, 2, 2)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(l)
		am.add_child(pc)
		pills[k] = [pc, l]

	var og: = GridContainer.new()
	og.columns = 3
	og.add_theme_constant_override("h_separation", 4)
	og.add_theme_constant_override("v_separation", 4)
	card.add_child(og)
	var obs: Dictionary = {}
	for it: Array in [["move", "ДВИЖЕНИЕ", "icon_move", "gold"], ["asm", "ПКР ЗАЛП", "icon_ash_ammo", "red"], ["cm", "КР УДАР", "icon_cruise_ammo", "red"], 
			["patrol", "ПАТРУЛЬ", "icon_patrol", "stone"], ["return", "НА БАЗУ", "icon_navbase", "stone"], ["stop", "СТОП", "icon_close", "stone"]]:
		var b: Button = _btn_icon(String(it[1]), String(it[2]), String(it[3]))
		var key: String = String(it[0])
		b.pressed.connect( func() -> void : _ship_cmd(key))
		HT.key(b, "n_" + key)
		og.add_child(b)
		obs[key] = b

	var sv_l: Label = UiKit.lbl("ОБСЛУЖИВАНИЕ У БАЗЫ", 10, UiKit.TITLE, 2, 3)
	card.add_child(sv_l)
	var sr: = HBoxContainer.new()
	sr.add_theme_constant_override("separation", 4)
	card.add_child(sr)
	var svc: Dictionary = {}
	for it2: Array in [["asm", "ПКР", "icon_ash_ammo"], ["cm", "КРЫЛАТЫЕ", "icon_cruise_ammo"], ["repair", "ПОЧИНИТЬ", "icon_repair_ship"]]:
		var b2: Button = UiKit.big("", "stone", "", 46.0, 10)
		b2.custom_minimum_size = Vector2(0, 50)
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hb2: = HBoxContainer.new()
		hb2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hb2.offset_left = 5
		hb2.offset_right = -4
		hb2.add_theme_constant_override("separation", 4)
		hb2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b2.add_child(hb2)
		hb2.add_child(_icon(String(it2[2]), 20))
		var tv2: = VBoxContainer.new()
		tv2.alignment = BoxContainer.ALIGNMENT_CENTER
		tv2.add_theme_constant_override("separation", -1)
		tv2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb2.add_child(tv2)
		var l1: Label = UiKit.lbl(String(it2[1]), 10, UiKit.TEXT, 2, 3)
		l1.clip_text = true
		tv2.add_child(l1)
		var l2: Label = UiKit.lbl("", 9, UiKit.MUTED, 1, 2)
		l2.clip_text = true
		tv2.add_child(l2)
		var key2: String = String(it2[0])
		b2.pressed.connect( func() -> void : _service(key2))
		sr.add_child(b2)
		svc[key2] = [b2, l1, l2]
		HT.key(b2, "n_svc_" + key2)

	var svh: Label = UiKit.lbl("", 9, UiKit.MUTED, 1, 2)
	svh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	svh.custom_minimum_size.x = 1.0
	card.add_child(svh)
	card_refs = {"hic": hic, "nm": nm, "fit": fit, "hp": hp, "hpl": hpl, "st": stl, "pills": pills, "orders": obs, "svc": svc, "svl": sv_l, "svr": sr, "svh": svh}


func _draw_hp(c: Control, v: float) -> void :
	var r: = Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r.grow(1), UiKit.OUTLINE)
	c.draw_rect(r, Color("2a2b22"))
	var col: Color = UiKit.GREEN if v > 0.66 else (UiKit.GOLD if v > 0.34 else UiKit.RED)
	var w: float = roundf(r.size.x * clampf(v, 0.0, 1.0))
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(w, r.size.y)), col)
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(w, 2)), col.lightened(0.35))
	for i in range(1, 8):
		c.draw_rect(Rect2(Vector2(roundf(r.size.x * float(i) / 8.0), 0), Vector2(1, r.size.y)), Color(0, 0, 0, 0.35))


func _build_place() -> void :
	place_box = HBoxContainer.new()
	place_box.add_theme_constant_override("separation", 6)
	place_box.custom_minimum_size = Vector2(0, 48)
	place_box.visible = false
	dock.add_child(place_box)
	var back: Button = UiKit.arrow(true)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(exit_mode)
	place_box.add_child(back)
	place_ic = _icon("icon_move", 28)
	place_box.add_child(place_ic)
	var vb: = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place_box.add_child(vb)
	place_t1 = UiKit.lbl("", 12, UiKit.TITLE, 2, 3)
	place_t1.clip_text = true
	place_t1.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vb.add_child(place_t1)
	place_t2 = UiKit.lbl("", 10, UiKit.TEXT, 1, 2)
	place_t2.clip_text = true
	place_t2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vb.add_child(place_t2)
	var cb: Button = UiKit.big("ОТМЕНА", "stone", "", 44.0, 11)
	cb.custom_minimum_size.x = 88
	cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cb.pressed.connect(cancel_place)
	place_box.add_child(cb)




func open_dock(ship: Ship = null) -> void :
	if gw.player == null or gw.player.eliminated or _nv() == null:
		return
	if _player != gw.player:
		_player = gw.player
		for r: Node in rows.values():
			r.queue_free()
		rows.clear()
		tab_fid = 0
		legs.clear()
	if not is_open:
		UiKit.snd("ui_open")
	is_open = true
	visible = true
	hud.ui24_open(self)
	panel.visible = true
	var fc: int = fresh_count()
	if ship == null and fc > _fresh_seen and tab_fid == 0:
		tab_fid = FREE_TAB
	_fresh_seen = fc
	if ship != null:
		sel_sid = ship.id
		set_mode("ship")
	else:
		set_mode("list")


func close() -> void :
	if not is_open and not visible:
		return
	is_open = false
	placing = ""
	target = Vector2.INF
	route_pts = PackedVector2Array()
	pv = {}
	selecting = false
	checked.clear()
	_hide_confirm()
	_close_pop()
	_close_sheet()
	visible = false
	panel.visible = false
	hud.ui24_closed(self)



func exit_mode() -> void :
	if not is_open:
		return
	close()
	UiKit.snd("ui_close")
	hud.action.emit("cancel_select")


func is_placing() -> bool:
	return is_open and visible and placing != ""


func scroll_area() -> ScrollContainer:
	if not is_open or mode != "list":
		return null
	var mp: Vector2 = get_viewport().get_mouse_position()
	if strip_sc.is_visible_in_tree() and strip_sc.get_global_rect().has_point(mp):
		return strip_sc
	return list_sc if list_sc.is_visible_in_tree() else null


func blocked_rects() -> Array:
	var out: Array = []
	for c: Control in [panel, confirm, pop, sheet]:
		if c != null and is_instance_valid(c) and c.is_visible_in_tree():
			out.append(c.get_global_rect().grow(2.0))
	return out


func set_mode(m: String) -> void :
	mode = m
	_close_pop()
	refresh()


func set_tab(fid: int) -> void :
	tab_fid = fid
	refresh()


func set_selecting(on: bool) -> void :
	selecting = on
	if not on:
		checked.clear()
	_close_pop()
	refresh()




func refresh() -> void :
	if not is_open or _nv() == null or gw.player == null:
		return
	_rt = 1.0
	if tab_fid > 0 and fleet(tab_fid).is_empty():
		tab_fid = 0
	var ships: Array = my_ships()
	var ids: Dictionary = {}
	for s: Ship in ships:
		ids[s.id] = true
	for k: Variant in checked.keys():
		if not ids.has(k):
			checked.erase(k)
	if mode == "ship" and not ids.has(sel_sid):
		mode = "list"
	var sig: String = "%d|%s|%d|" % [tab_fid, selecting, Loc.gen]
	for fl: Dictionary in fleets():
		sig += "%d:%s:%d;" % [int(fl["id"]), String(fl.get("name", "")), (fl.get("ships", []) as Array).size()]
	sig += str(ships.size())
	var fr: Array = free_ships()
	sig += "|f%d:%d" % [fr.size(), fr.filter( func(s: Ship) -> bool: return s.fresh).size()]
	var listing: bool = mode == "list"
	var targeting: bool = placing != ""
	head.visible = listing and not targeting
	strip_sc.visible = not selecting
	sel_lbl.visible = selecting
	sel_lbl.text = Loc.t("Выбрано: %d") % checked.size()
	if sel_btn.button_pressed != selecting:
		sel_btn.set_pressed_no_signal(selecting)
	list_sc.visible = listing and not targeting
	bar.visible = listing and not targeting and not selecting
	sbar.visible = listing and not targeting and selecting
	card.visible = mode == "ship" and not targeting
	place_box.visible = targeting
	if listing and sig != _chips_sig:
		_chips_sig = sig
		_rebuild_chips()
	if listing:
		_fill_rows(tab_ships())
	else:
		empty_lbl.visible = false
	if mode == "ship":
		_fill_card()
	for k2: String in ["to_fleet", "s_move", "s_more"]:
		(bar_btns[k2] as Button).disabled = checked.is_empty()


func _fill_rows(ts: Array) -> void :
	var seen: Dictionary = {}
	var i: int = 0
	var col_on: bool = tab_fid == FREE_TAB and not selecting and not ts.is_empty() and collect_btn != null
	if collect_btn != null:
		collect_btn.visible = col_on
		if col_on:
			list.move_child(collect_btn, 0)
			(collect_btn.get_meta("sub") as Label).text = Loc.t("%s → в новый или готовый флот") % (Loc.n(ts.size(), "%d корабль", "%d корабля", "%d кораблей") % (ts.size()))
			i = 1
	for s: Ship in ts:
		var r: Button = rows.get(s.id)
		if r == null:
			r = _make_row(s.id)
			list.add_child(r)
			rows[s.id] = r
		r.visible = true
		list.move_child(r, i)
		_set_row(r, s)
		seen[s.id] = true
		i += 1
	for sid: Variant in rows.keys():
		if not seen.has(sid):
			if _nv().ship(int(sid)) == null or not _nv().ship(int(sid)).alive():
				(rows[sid] as Node).queue_free()
				rows.erase(sid)
			else:
				(rows[sid] as Control).visible = false
	empty_lbl.visible = ts.is_empty()
	empty_lbl.text = Loc.t("Кораблей нет — постройте их на морской базе (вкладка ГОРОДА › МОРБАЗА)") if my_ships().is_empty() else (Loc.t("Все корабли во флотах. Новые корабли с верфи появятся здесь") if tab_fid == FREE_TAB else Loc.t("Во флоте нет кораблей: выберите корабли в «БЕЗ ГРУППЫ» и нажмите «ВО ФЛОТ»"))
	var vp: Vector2 = get_viewport_rect().size
	var want: float = (3.2 if vp.y >= 740.0 else 2.25) * 52.0 - 4.0
	list_sc.custom_minimum_size.y = minf(want, maxf(1.0, float(ts.size())) * 52.0 - 4.0 + (48.0 if col_on else 0.0)) if not ts.is_empty() else 0.0


func _make_row(sid: int) -> Button:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 48)
	var hb: = HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 6
	hb.offset_right = -6
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	var ck: = PanelContainer.new()
	ck.add_theme_stylebox_override("panel", UiKit.sb("wb_slot", 2))
	ck.custom_minimum_size = Vector2(24, 24)
	ck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cki: TextureRect = U.icon("wb_check", 16)
	ck.add_child(cki)
	hb.add_child(ck)
	var slot: = PanelContainer.new()
	slot.add_theme_stylebox_override("panel", UiKit.sb("wb_slot", 3))
	slot.custom_minimum_size = Vector2(36, 36)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(slot)
	var hic: TextureRect = _icon("icon_hull_light", 26)
	slot.add_child(hic)
	var band: = ColorRect.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.custom_minimum_size = Vector2(0, 3)
	slot.add_child(band)
	band.size_flags_vertical = Control.SIZE_SHRINK_END
	var nc: = VBoxContainer.new()
	nc.add_theme_constant_override("separation", 3)
	nc.alignment = BoxContainer.ALIGNMENT_CENTER
	nc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(nc)
	var nl: Label = UiKit.lbl("", 11, UiKit.TEXT, 2, 3)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var nrow: = HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 5)
	nrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nc.add_child(nrow)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nrow.add_child(nl)
	var nw: Label = _pill("НОВЫЙ", UiKit.GOLD, UiKit.OUTLINE, Color("3a1f08"))
	nw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nrow.add_child(nw)
	nrow.move_child(nw, 0)
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 5)
	hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nc.add_child(hr)
	var hp: = Control.new()
	hp.custom_minimum_size = Vector2(54, 7)
	hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.draw.connect( func() -> void : _draw_hp(hp, float(hp.get_meta("v", 1.0))))
	hr.add_child(hp)
	var am: Label = UiKit.lbl("", 9, UiKit.MUTED, 2, 2)
	am.clip_text = true
	am.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(am)
	var st: Label = UiKit.lbl("", 9, UiKit.MUTED, 2, 2)
	st.custom_minimum_size = Vector2(62, 0)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(st)
	b.set_meta("refs", {"ck": ck, "cki": cki, "hic": hic, "band": band, "nl": nl, "nw": nw, "hp": hp, "am": am, "st": st})
	var hold: Array = [-1.0, false]
	b.set_meta("hold", hold)
	b.button_down.connect( func() -> void :
		hold[0] = 0.0
		hold[1] = false)
	b.button_up.connect( func() -> void : hold[0] = -1.0)
	b.pressed.connect( func() -> void :
		if not bool(hold[1]):
			_on_row_tap(sid))
	b.set_meta("long", func() -> void :
		if not selecting:
			set_selecting(true)
		checked[sid] = true
		refresh())
	UiKit.press_fx(b)
	return b


func _set_row(r: Button, s: Ship) -> void :
	var rf: Dictionary = r.get_meta("refs")
	var on: bool = s.id == sel_sid
	var sb: StyleBox = UiKit.sb("wb_card" if on else "wb_panel_dark", 4, 2)
	for st: String in ["normal", "hover", "disabled"]:
		r.add_theme_stylebox_override(st, sb)
	for st2: String in ["pressed", "hover_pressed"]:
		r.add_theme_stylebox_override(st2, UiKit.sb("wb_card", 4, 2))
	r.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	(rf["ck"] as Control).visible = selecting
	(rf["cki"] as Control).visible = checked.has(s.id)
	(rf["hic"] as TextureRect).texture = _nt(HULL_ICON[clampi(s.hull, 0, 2)])
	var band: ColorRect = rf["band"]
	var fl: Dictionary = fleet(s.fleet) if s.fleet != 0 else {}
	band.visible = not fl.is_empty()
	if not fl.is_empty():
		band.color = fleet_color(fl)
	if is_instance_valid(rf["nl"]):
		(rf["nl"] as Label).text = "%s · %s" % [Loc.name(s.name), String(Navy.hull_spec(s.hull)["name"]).to_lower()]
	(rf["nw"] as Control).visible = s.fresh and _fleet_key(s) == 0
	var hp: Control = rf["hp"]
	hp.set_meta("v", s.hp / maxf(1.0, s.hp_max))
	hp.queue_redraw()
	var full: Dictionary = Navy.ammo_full(s.hull, s.mods)
	var parts: PackedStringArray = []
	if int(full.get("asm", 0)) > 0:
		parts.append(Loc.t("ПКР %d/%d") % [int(s.ammo.get("asm", 0)), int(full["asm"])])
	if int(full.get("cm", 0)) > 0:
		parts.append(Loc.t("КР %d/%d") % [int(s.ammo.get("cm", 0)), int(full["cm"])])
	if int(full.get("art", 0)) > 0:
		parts.append(Loc.t("СНАР %d/%d") % [int(s.ammo.get("art", 0)), int(full["art"])])
	if not s.fires.is_empty():
		parts.append(Loc.t("пожар ×%d") % s.fires.size())
	if _sinks(s):
		parts.append(Loc.t("ТОПИТ НЕЙТР."))
	(rf["am"] as Label).text = " · ".join(parts) if not parts.is_empty() else "%d/%d" % [roundi(s.hp), roundi(s.hp_max)]
	(rf["am"] as Label).add_theme_color_override("font_color", UiKit.RED if not s.fires.is_empty() or _sinks(s) else UiKit.MUTED)
	var stt: String = status_of(s)
	(rf["st"] as Label).text = stt
	var sc: String = String(STATUS_COL.get(stt, ""))
	(rf["st"] as Label).add_theme_color_override("font_color", UiKit.RED if sc == "red" else (UiKit.GOLD if sc == "gold" else UiKit.MUTED))


func _fill_card() -> void :
	var s: Ship = _nv().ship(sel_sid)
	if s == null:
		return
	var R: Dictionary = card_refs
	(R["hic"] as TextureRect).texture = _nt(HULL_ICON[clampi(s.hull, 0, 2)])
	var fl: Dictionary = fleet(s.fleet) if s.fleet != 0 else {}
	if is_instance_valid(R["nm"]):
		(R["nm"] as Label).text = Loc.name(s.name) + ((" · " + String(fl.get("name", ""))) if not fl.is_empty() else "")
	(R["fit"] as Label).text = Navy.fit_text(s.hull, s.mods)
	(R["hp"] as Control).set_meta("v", s.hp / maxf(1.0, s.hp_max))
	(R["hp"] as Control).queue_redraw()
	if is_instance_valid(R["hpl"]):
		(R["hpl"] as Label).text = "%d/%d%s" % [roundi(s.hp), roundi(s.hp_max), (Loc.t(" · пожар ×%d") % s.fires.size()) if not s.fires.is_empty() else ""]
	(R["hpl"] as Label).add_theme_color_override("font_color", UiKit.RED if not s.fires.is_empty() else UiKit.TEXT)
	var stt: String = status_of(s)
	if is_instance_valid(R["st"]):
		(R["st"] as Label).text = stt + (Loc.t(" · ТОПИТ НЕЙТРАЛЬНЫЕ") if _sinks(s) else Loc.t(" · нейтральные не топит"))
	var full: Dictionary = Navy.ammo_full(s.hull, s.mods)
	var nm: Dictionary = {"asm": "ПКР", "cm": "КР", "sam": "ЗУР", "ciws": "ЗАК", "decoy": "ловушки", "art": "СНАР."}
	for k: String in R["pills"]:
		var e: Array = R["pills"][k]
		var mx: int = int(full.get(k, 0))
		(e[0] as Control).visible = mx > 0
		(e[1] as Label).text = "%s %d/%d" % [nm[k], int(s.ammo.get(k, 0)), mx]
	var ob: Dictionary = R["orders"]
	(ob["asm"] as Button).disabled = int(s.ammo.get("asm", 0)) <= 0
	(ob["cm"] as Button).visible = s.has_mod("vls")
	(ob["cm"] as Button).disabled = int(s.ammo.get("cm", 0)) <= 0
	_fill_service(s)



func _fill_service(s: Ship) -> void :
	var nv: Navy = _nv()
	var near: bool = nv.near_base(s) != null
	var miss: Dictionary = nv._missing(s) if nv.has_method("_missing") else {}
	var sv: Dictionary = card_refs["svc"]
	var why_svc: String = "" if near else Loc.t("нужна база рядом")
	var svc_red: bool = not near
	var lack0: PackedStringArray = []
	if int(miss.get("asm", 0)) > 0:
		lack0.append(Loc.t("ПКР +%d") % int(miss["asm"]))
	if int(miss.get("cm", 0)) > 0:
		lack0.append(Loc.t("КР +%d") % int(miss["cm"]))
	if s.hp < s.hp_max - 1.0 or not s.fires.is_empty():
		lack0.append(Loc.t("ремонт"))
	(card_refs["svl"] as Control).visible = near
	(card_refs["svr"] as Control).visible = near
	var svh: Label = card_refs["svh"]
	svh.visible = not near
	svh.text = (Loc.t("Пополнение и ремонт — у своей морской базы (НА БАЗУ)%s") % ((": " + ", ".join(lack0)) if not lack0.is_empty() else "")) if not near else ""
	svh.add_theme_color_override("font_color", Color("ff9a80") if not lack0.is_empty() else UiKit.MUTED)
	if near and gw.game_time - s.hit_t < Navy.SERVICE_QUIET:
		why_svc = "под огнём"
		svc_red = true
	if near and s.refit != "":
		why_svc = Loc.t("%s · %d с") % [Loc.t("ремонт") if s.refit == "repair" else Loc.t("погрузка"), ceili(s.refit_t)]
		svc_red = false
	for k: String in ["asm", "cm"]:
		var e: Array = sv[k]
		var n: int = int(miss.get(k, 0))
		var has_slot: bool = int(Navy.ammo_full(s.hull, s.mods).get(k, 0)) > 0
		(e[0] as Button).visible = has_slot
		if is_instance_valid(e[1]):
			(e[1] as Label).text = "%s +%d" % [Loc.t("ПКР") if k == "asm" else Loc.t("КРЫЛАТЫЕ"), n]
		var cost: Dictionary = {}
		Navy._add(cost, Navy.REARM_PRICE.get(k, {}), n)
		var t: float = Navy.REARM_T_EACH * float(n) + Navy.REARM_T0
		if is_instance_valid(e[2]):
			(e[2] as Label).text = why_svc if why_svc != "" else (Loc.t("полный") if n == 0 else Loc.t("%s · %d с") % [Economy.cost_text(cost), roundi(t)])
		(e[2] as Label).add_theme_color_override("font_color", UiKit.RED if svc_red else UiKit.MUTED)
		(e[0] as Button).disabled = why_svc != "" or n == 0
	var er: Array = sv["repair"]
	var lack: float = s.hp_max - s.hp
	var rc: Dictionary = nv.repair_cost(s)
	if is_instance_valid(er[2]):
		(er[2] as Label).text = why_svc if why_svc != "" else (Loc.t("корабль цел") if lack < 1.0 and s.fires.is_empty() else Loc.t("%s · %d с") % [Economy.cost_text(rc), roundi(lack / Navy.REPAIR_HP_S + 2.0)])
	(er[2] as Label).add_theme_color_override("font_color", UiKit.RED if svc_red else UiKit.MUTED)
	(er[0] as Button).disabled = why_svc != "" or (lack < 1.0 and s.fires.is_empty())




func _on_row_tap(sid: int) -> void :
	if selecting:
		if checked.has(sid):
			checked.erase(sid)
		else:
			checked[sid] = true
		refresh()
		return
	var s: Ship = _nv().ship(sid)
	if s == null:
		return
	if sel_sid == sid:
		set_mode("ship")
		return
	sel_sid = sid
	hud.main_node.cam_lock = false
	hud.main_node.cam.center_on(s.pos)
	refresh()


func _on_bar(key: String, b: Button) -> void :
	match key:
		"move", "s_move":
			start_place("move")
		"patrol":
			start_place("patrol")
		"convoy":
			_popover(b, "КОНВОИ", [
				{"icon": "icon_hunt_convoy", "text": "ТОПИТЬ КОНВОИ", "sub": "охота в районе на суда врага", "cb": func() -> void : start_place("hunt")}, 
				{"icon": "icon_escort", "text": "ОХРАНА КОНВОЕВ", "sub": "сопровождать свои суда", "cb": func() -> void : start_place("escort")}, 
				{"icon": "icon_cause_blockade", "text": "БЛОКАДА ПОРТА", "sub": "суда в порт разворачиваются", "cb": func() -> void : start_place("blockade")}, 
				{"icon": "icon_hunt_convoy", "text": Loc.t("НЕЙТРАЛЬНЫЕ: %s") % [(Loc.t("ТОПИТЬ") if _sink_n_on() else Loc.t("НЕ ТОПИТЬ"))], "sub": (Loc.t("нажмите — не топить") if _sink_n_on() else Loc.t("нажмите — топить: инцидент, риск войны")), "warn": true, "cb": func() -> void : _toggle_sink_n()}])
		"more", "s_more":
			_popover(b, Loc.t("ПРИКАЗЫ · %s") % _who().to_upper(), [
				{"icon": "icon_navbase", "text": "НА БАЗУ", "sub": "ремонт и боезапас", "cb": func() -> void : _instant("return")}, 
				{"icon": "icon_close", "text": "СТОП", "sub": "лечь в дрейф", "cb": func() -> void : _instant("stop")}, 
				{"icon": "icon_ash_ammo", "text": "ПКР ЗАЛП", "sub": "по вражескому кораблю", "cb": func() -> void : start_place("asm")}, 
				{"icon": "icon_cruise_ammo", "text": "КР УДАР", "sub": "крылатые с УВП, любая цель", "cb": func() -> void : _cm_strike()}, 
				{"icon": "icon_ship_art", "text": "АРТ. УДАР", "sub": "по берегу, до 400 м вглубь", "cb": func() -> void : _art_strike()}])
		"to_fleet":
			open_to_fleet_menu(b)
		"cancel":
			set_selecting(false)




var _sink_want: Dictionary = {}


func _sinks(s: Ship) -> bool:
	if _sink_want.has(s.id):
		return bool(_sink_want[s.id])
	return _nv().sink_neutral(s.fleet) if s.fleet != 0 else bool(s.ord.get("sink_n", false))


func _sink_n_on() -> bool:
	for s: Ship in order_ships():
		if _sinks(s):
			return true
	return false


func _toggle_sink_n() -> void :
	var on: bool = not _sink_n_on()
	var ss: Array = order_ships()
	if ss.is_empty():
		hud.show_toast("Нет кораблей")
		return
	var ids: Array = _ids(ss)
	for sid: int in ids:
		_sink_want[sid] = on
	_dock("dock_sink", [ids, on], func(_r: Variant) -> void :
		for sid2: int in ids:
			_sink_want.erase(sid2)
		refresh())
	if on:
		hud.show_toast("ВНИМАНИЕ: топить нейтральные суда — каждое потопление станет инцидентом; конвой под охраной ответит огнём, это война")
		UiKit.snd("ui_error")
	else:
		hud.show_toast("Нейтральные суда не трогаем")
	refresh()


func _ship_cmd(key: String) -> void :
	match key:
		"move", "asm", "patrol":
			start_place(key)
		"cm":
			_cm_strike()
		"return", "stop":
			_instant(key)


func _who() -> String:
	if mode == "ship":
		var s: Ship = _nv().ship(sel_sid)
		return s.name if s != null else Loc.t("корабль")
	if selecting:
		return "выбранные"
	if tab_fid == FREE_TAB:
		return "свободные корабли"
	if tab_fid != 0:
		return Loc.uname(String(fleet(tab_fid).get("name", "Флот")))
	return "все корабли"



func _instant(kind: String) -> void :
	var ss: Array = order_ships()
	if ss.is_empty():
		hud.show_toast("Нет кораблей")
		return
	var who: String = _cap(_who())
	_issue(ss, kind, Vector2.ZERO, [], func(res: Array) -> void :
		hud.show_toast("%s: %s — %s" % [who, Loc.t("на базу") if kind == "return" else Loc.t("стоп"), (Loc.n(int(res[0]), "%d корабль", "%d корабля", "%d кораблей") % (int(res[0])))] if int(res[0]) > 0 else String(res[1]))
		refresh())





func _issue(ss: Array, kind: String, pos: Vector2, wps: Array = [], cb: Callable = Callable()) -> void :
	var plan: Array = []
	var by_fleet: Dictionary = {}
	for s: Ship in ss:
		if _fleet_key(s) != 0:
			by_fleet[_fleet_key(s)] = int(by_fleet.get(_fleet_key(s), 0)) + 1
	var done_fl: Dictionary = {}
	for s2: Ship in ss:
		var fid: int = _fleet_key(s2)
		var whole: bool = fid != 0 and int(by_fleet.get(fid, 0)) == my_ships().filter( func(x: Ship) -> bool: return _fleet_key(x) == fid).size()


		if whole and mode != "ship":
			if done_fl.has(fid) or s2.fleet == 0:
				continue
			done_fl[fid] = true
			plan.append([fid, int(by_fleet[fid])])
			continue
		plan.append([ - s2.id, 1])
	_dock("dock_order", [plan, kind, pos, wps], func(r: Variant) -> void :
		var res: Array = r if r is Array and (r as Array).size() >= 3 else [0, "Команда не выполнена", []]
		for k: Variant in res[2]:
			legs.erase(int(k))
		if cb.is_valid():
			cb.call([int(res[0]), String(res[1])]))




func _dock(fn: String, args: Array, cb: Callable = Callable()) -> void :
	if NetSession.inst() == null:
		var r: Variant = gw.cmd_static(gw.player, "ship_cr", fn, args)
		if cb.is_valid():
			cb.call(r)
		return
	NetSession.sim("", "cmd_static", [gw.player, "ship_cr", fn, args], cb)


func _ids(ss: Array) -> Array:
	var out: Array = []
	for s: Ship in ss:
		out.append(s.id)
	return out






func _cm_strike() -> void :
	var focus: Ship = null
	for s: Ship in order_ships():
		if s.has_mod("vls") and (focus == null or int(s.ammo.get("cm", 0)) > int(focus.ammo.get("cm", 0))):
			focus = s
	hud.main_node.ship_cr_begin(focus)



func _art_strike() -> void :
	var focus: Ship = null
	for s: Ship in order_ships():
		if s.has_mod("art") and (focus == null or int(s.ammo.get("art", 0)) > int(focus.ammo.get("art", 0))):
			focus = s
	hud.main_node.ship_art_begin(focus)


func _seen(o: Ship) -> bool:
	return gw.vision == null or gw.vision.shows(gw.player.id, o.pos)



func quick_ships() -> Array:
	if not is_open or placing != "" or _nv() == null:
		return []
	if mode == "ship" or (selecting and not checked.is_empty()) or ( not selecting and tab_fid > 0):
		return order_ships()
	return []



func ship_at(sp: Vector2, own: bool) -> Ship:
	var cam: MapCamera = hud.main_node.cam
	var best: Ship = null
	var bd: float = 33.0
	for s: Ship in _nv().ships:
		if not s.alive() or (s.c == gw.player.id) != own or ( not own and not _seen(s)):
			continue
		var p: Vector2 = cam.world_to_screen(s.pos)
		var d: float = minf(p.distance_to(sp), (p + Vector2(0, -14)).distance_to(sp))
		if d < bd:
			bd = d
			best = s
	return best




func map_tap(sp: Vector2, wp: Vector2) -> bool:
	var nv: Navy = _nv()
	if nv == null or gw.player == null:
		return false
	if (pop != null and is_instance_valid(pop)) or (sheet != null and is_instance_valid(sheet)):
		return false
	var fid: int = int(map_layer.call("pennant_at", sp)) if map_layer != null and map_layer.has_method("pennant_at") else 0
	if fid != 0 and not (is_open and mode == "list" and tab_fid == fid and not selecting):
		hud.action.emit("cancel_select")
		open_dock(null)
		selecting = false
		checked.clear()
		set_tab(fid)
		UiKit.snd("ui_select")
		return true
	if not is_open:
		return false
	if confirm != null and is_instance_valid(confirm):
		_hide_confirm()
	var own: Ship = ship_at(sp, true)
	if own != null:
		if selecting:
			_on_row_tap(own.id)
			UiKit.snd("ui_select")
			return true
		return false
	var ss: Array = quick_ships()
	if ss.is_empty():
		if placing == "" and nv._body_px(wp) > 0 and mode == "list" and not selecting and tab_fid <= 0 and ship_at(sp, false) == null:

			if Time.get_ticks_msec() - _hint_ms > 2500:
				_hint_ms = Time.get_ticks_msec()
				hud.show_toast("Кому приказ? Выберите флот вкладкой вверху или зажмите корабль в списке — потом коснитесь моря")
		return false
	var foe: Ship = ship_at(sp, false)
	if foe != null:
		attack(ss, foe)
		return true
	if nv._body_px(wp) > 0:
		quick_move(ss, wp)
		return true
	if nv._sea_near(wp, 3).x >= 0 and not _land_obj_at(wp):
		quick_move(ss, wp)
		return true
	close()
	return false



func _land_obj_at(wp: Vector2) -> bool:
	var cell: = Vector2i(floori(wp.x / GameWorld.CELL), floori(wp.y / GameWorld.CELL))
	if gw.city_at_cell(cell) != null or gw.mil.facility_at(cell) != null:
		return true
	for u: Unit in gw.army.units:
		if u.alive() and u.pos.distance_squared_to(wp) < 144.0:
			return true
	return false


func quick_move(ss: Array, wp: Vector2) -> void :
	_issue(ss, "move", wp, [], func(res: Array) -> void : _quick_moved(ss.size(), wp, res))


func _quick_moved(n_ss: int, wp: Vector2, res: Array) -> void :
	if int(res[0]) == 0:
		hud.show_toast(Loc.t("Не пойдут: %s") % [(String(res[1]) if String(res[1]) != "" else Loc.t("нет кораблей"))])
		UiKit.snd("ui_error")
		return
	quick_marks.append([wp, Time.get_ticks_msec(), false])
	if hud.main_node.get("overlay") != null:
		hud.main_node.overlay.ripple(wp, "water_coast")
	UiKit.snd("ui_select")
	if int(res[0]) < n_ss:
		hud.show_toast(Loc.t("Пойдут %d из %d: %s") % [int(res[0]), n_ss, String(res[1]).to_lower()])
	_rt = 0.0




func attack(ss: Array, foe: Ship) -> void :
	var nv: Navy = _nv()
	var me: int = gw.player.id
	if not nv._hostile(me, foe.c):
		var blk: String = NS.blocked(gw, me, foe.c)
		if blk != "":
			hud.show_toast(Loc.t("Нельзя: %s") % [blk])
			UiKit.snd("ui_error")
			return
		var now: int = Time.get_ticks_msec()
		if int(_war_arm[0]) != foe.id or now - int(_war_arm[1]) > 4000:
			_war_arm = [foe.id, now]
			hud.show_toast(Loc.t("%s. Тапните ещё раз — атака") % [NS.war_note(gw, me, foe.c)])
			UiKit.snd("ui_error")
			return
		_war_arm = [0, 0]

	var fpos: Vector2 = foe.pos
	var fname: String = foe.name
	_dock("dock_attack", [_ids(ss), foe.id, int(SALVO[clampi(foe.hull, 0, 2)]), mode != "ship"], func(r: Variant) -> void :
		var res: Array = r if r is Array and (r as Array).size() >= 3 else [0, 0, "Команда не выполнена"]
		_attacked(fpos, fname, int(res[0]), int(res[1]), String(res[2])))


func _attacked(fpos: Vector2, fname: String, fired: int, nmv: int, why: String) -> void :
	if why != "":
		hud.show_toast(why)
		UiKit.snd("ui_error")
		return
	quick_marks.append([fpos, Time.get_ticks_msec(), true])
	if hud.main_node.get("overlay") != null:
		hud.main_node.overlay.ripple(fpos, "alert_red")
	var parts: PackedStringArray = []
	if fired > 0:
		parts.append(Loc.t("ПКР ×%d") % fired)
	if nmv > 0:
		parts.append(Loc.t("%s на сближение") % (Loc.n(nmv, "%d корабль", "%d корабля", "%d кораблей") % (nmv)))
	if parts.is_empty():
		parts.append(Loc.t("цель далеко: ПКР до %.1f км, пушки до %d м") % [Navy.ASM_RANGE / 1000.0, int(Navy.GUN_RANGE)])
	hud.show_toast(Loc.t("Атака: %s — %s") % [fname, ", ".join(parts)])
	UiKit.snd("ui_select" if fired == 0 else "ui_click")
	_rt = 0.0




func start_place(kind: String) -> void :
	var ss: Array = order_ships()
	if ss.is_empty():
		hud.show_toast("Нет кораблей для приказа")
		UiKit.snd("ui_error")
		return
	placing = kind
	target = Vector2.INF
	route_pts = PackedVector2Array()
	route_wp = Vector2.INF
	pv = {}
	_close_pop()
	_hide_confirm()
	place_ic.texture = _nt(String(KIND_ICON.get(kind, "icon_move")))
	place_t1.text = "%s · %s" % [Loc.t(String(KIND_TEXT.get(kind, kind.to_upper()))), _who().to_upper()]
	place_t2.text = "%s · %s" % [Loc.t(String(KIND_HINT.get(kind, ""))), (Loc.n(ss.size(), "%d корабль", "%d корабля", "%d кораблей") % (ss.size()))]
	hud.action.emit("cancel_select")
	refresh()


func cancel_place() -> void :
	placing = ""
	target = Vector2.INF
	route_pts = PackedVector2Array()
	route_wp = Vector2.INF
	pv = {}
	_hide_confirm()
	refresh()



func set_target(p: Vector2) -> void :
	if placing == "":
		return
	target = p
	route_pts = PackedVector2Array()
	route_wp = Vector2.INF
	_preview()
	UiKit.snd("ui_select")


func _preview() -> void :
	var nv: Navy = _nv()
	var ss: Array = order_ships()
	var ok: int = 0
	var skipped: Array = []
	var ends: Array = []
	var aim: String = ""
	var foe: Ship = null
	if placing == "blockade":

		var bd: float = 600.0
		var port: Facility = null
		for f: Facility in gw.mil.facilities:
			if f.kind == Facility.Kind.PORT and f.country_id != gw.player.id and gw.mil.alive(f) and f.center_px().distance_to(target) < bd:
				bd = f.center_px().distance_to(target)
				port = f
		if port != null:
			target = port.center_px()
			var pc: Country = gw.country_by_id(port.country_id)
			aim = Loc.t("порт %s%s") % [Loc.name(pc.name) if pc != null else "", "" if nv._hostile(gw.player.id, port.country_id) else Loc.t(" · враждебный акт: протест, санкции")]
	if placing == "asm":
		var best: float = 160.0
		for o: Ship in nv.ships:

			if o.alive() and o.c != gw.player.id and o.pos.distance_to(target) < best and (nv._hostile(gw.player.id, o.c) or _seen(o)):
				best = o.pos.distance_to(target)
				foe = o
		if foe != null:
			target = foe.pos
			aim = "%s (%s)" % [Loc.name(foe.name), String(Navy.hull_spec(foe.hull)["name"]).to_lower()]
	for s: Ship in ss:
		var why: String = ""
		match placing:
			"asm":
				if foe == null:
					why = "нет вражеского корабля у точки"
				elif int(s.ammo.get("asm", 0)) <= 0:
					why = "нет ПКР"
				elif s.pos.distance_to(target) > Navy.ASM_RANGE:
					why = Loc.t("дальше %.1f км") % (Navy.ASM_RANGE / 1000.0)
			"cm":
				if not s.has_mod("vls"):
					why = "нет УВП"
				elif int(s.ammo.get("cm", 0)) <= 0:
					why = "нет КР"
				elif s.pos.distance_to(target) > Navy.CM_RANGE:
					why = Loc.t("дальше %.1f км") % (Navy.CM_RANGE / 1000.0)
			"blockade":
				if aim == "":
					why = "нет чужого порта у точки"
				elif nv._sea_near(target, 14, nv._body_px(s.pos)).x < 0:
					why = "другое море"
			_:
				if nv._sea_near(target, 12, nv._body_px(s.pos)).x < 0 and nv._sea_near(target, 40, nv._body_px(s.pos)).x < 0:
					why = "другое море"
		if why == "":
			ok += 1
			ends.append([s.id, target])
		else:
			skipped.append([s.name, why])
	pv = {"ok": ok, "n": ss.size(), "skipped": skipped, "ends": ends, "aim": aim}
	if foe != null and not nv._hostile(gw.player.id, foe.c):
		pv["war"] = NS.war_note(gw, gw.player.id, foe.c)
		pv["war_c"] = foe.c
	_show_confirm()


func _show_confirm() -> void :
	_hide_confirm()
	var vw: float = get_viewport_rect().size.x - 12.0
	confirm = PanelContainer.new()
	confirm.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 6))
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm.custom_minimum_size = Vector2(vw, 0)
	add_child(confirm)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	confirm.add_child(hb)
	hb.add_child(_icon(String(KIND_ICON.get(placing, "icon_move")), 30))
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var tw: float = vw - 16.0 - 38.0 - 74.0
	var what: String = Loc.t(String(KIND_TEXT.get(placing, ""))).to_lower()
	if placing == "asm" and String(pv.get("aim", "")) != "":
		what += " · " + String(pv["aim"])
	var l1: Label = UiKit.lbl("%s → %s%s" % [_cap(_who()), what, Loc.t(" по маршруту") if route_wp.is_finite() else ""], 11, UiKit.TITLE, 2, 3)
	l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l1.custom_minimum_size.x = tw
	vb.add_child(l1)
	var nok: int = int(pv.get("ok", 0))
	var n: int = int(pv.get("n", 0))
	var strike: bool = placing == "asm" or placing == "cm"
	var verb: String = Loc.t("Ударят") if strike else Loc.t("Пойдут")
	var l2: Label = UiKit.lbl((Loc.t("%s %d из %d") % [verb, nok, n]) + (Loc.t(" · %d ракет") % _salvo_n() if placing == "asm" and nok > 0 else "") if nok > 0 else Loc.t("Никто не может (0 из %d)") % n, 10, UiKit.TEXT if nok > 0 else UiKit.RED, 1, 2)
	l2.custom_minimum_size.x = tw
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(l2)
	var sk: Array = pv.get("skipped", [])
	if not sk.is_empty():
		var parts: PackedStringArray = []
		for e: Array in sk.slice(0, 3):
			parts.append("%s (%s)" % [String(e[0]), String(e[1])])
		if sk.size() > 3:
			parts.append(Loc.t("ещё %d") % (sk.size() - 3))
		var l3: Label = UiKit.lbl((Loc.t("Не ударят: ") if strike else Loc.t("Не пойдут: ")) + ", ".join(parts), 9, UiKit.RED, 2, 2)
		l3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l3.custom_minimum_size.x = tw
		vb.add_child(l3)
	if String(pv.get("war", "")) != "":
		var lw: Label = UiKit.lbl(String(pv["war"]), 10, UiKit.RED, 2, 3)
		lw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lw.custom_minimum_size.x = tw
		vb.add_child(lw)
	confirm_ok = UiKit.big("ДА", "red" if strike else "green", "", 44.0, 14)
	confirm_ok.custom_minimum_size = Vector2(66, 44)
	confirm_ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	confirm_ok.disabled = nok == 0
	confirm_ok.pressed.connect(_confirm)
	hb.add_child(confirm_ok)
	var c: PanelContainer = confirm
	c.ready.connect( func() -> void :
		c.reset_size()
		UiKit.pop_in(c, 0.9, 0.18), CONNECT_ONE_SHOT)



func _salvo_n() -> int:
	var nv: Navy = _nv()
	for o: Ship in nv.ships:
		if o.alive() and o.pos.distance_to(target) < 1.0:
			return int(SALVO[clampi(o.hull, 0, 2)])
	return 2


func _confirm() -> void :
	if placing == "" or not target.is_finite():
		cancel_place()
		return
	var ss: Array = order_ships()
	var kind: String = placing
	var tgt: Vector2 = target
	var who: String = _cap(_who())
	var done: Callable = func(res: Array) -> void : _confirmed(kind, tgt, who, int(res[0]), String(res[1]))
	if kind == "asm" or kind == "cm":


		_dock("dock_salvo", [_ids(ss), kind, tgt, _salvo_n(), int(pv.get("war_c", 0)) if kind == "asm" else 0], func(r: Variant) -> void :
			done.call(r if r is Array and (r as Array).size() >= 2 else [0, "Команда не выполнена"]))
	else:

		_issue(ss, kind, tgt, [route_wp] if route_wp.is_finite() else [], done)


func _confirmed(kind: String, target: Vector2, who: String, n_ok: int, why0: String) -> void :
	if n_ok == 0:
		hud.show_toast(Loc.t("Приказ не выполнен: %s") % [(why0 if why0 != "" else Loc.t("нет кораблей"))])
		UiKit.snd("ui_error")
		return
	if hud.main_node.get("overlay") != null:
		hud.main_node.overlay.ripple(target, "alert_red" if kind in ["asm", "cm", "hunt", "blockade"] else "water_coast")
	hud.show_toast("%s: %s — %s" % [who, Loc.t(String(KIND_TEXT.get(kind, ""))).to_lower(), ((Loc.n(n_ok, "%d ракета", "%d ракеты", "%d ракет") % (n_ok)) if kind in ["asm", "cm"] else (Loc.n(n_ok, "%d корабль", "%d корабля", "%d кораблей") % (n_ok)))])
	if placing == kind:
		if selecting:
			selecting = false
			checked.clear()
		cancel_place()


func _hide_confirm() -> void :
	if confirm != null and is_instance_valid(confirm):
		confirm.queue_free()
	confirm = null




func route_drawing() -> bool:
	return is_open and visible and (placing == "move" or placing == "patrol")


func route_grab(sp: Vector2) -> bool:
	if not route_drawing():
		return false
	var cam: MapCamera = hud.main_node.cam
	for s: Ship in order_ships():
		if cam.world_to_screen(s.pos).distance_to(sp) <= ROUTE_GRAB_PX:
			return true
	return false


func route_drag(from_w: Vector2, to_w: Vector2) -> void :
	if not route_drawing():
		return
	if route_pts.is_empty():
		_hide_confirm()
		target = Vector2.INF
		pv = {}
		route_wp = Vector2.INF
		route_pts.append(from_w)
	if route_pts[route_pts.size() - 1].distance_to(to_w) > 6.0:
		route_pts.append(to_w)


func route_drag_end() -> void :
	if not route_drawing() or route_pts.size() < 2:
		route_pts = PackedVector2Array()
		return
	var a: Vector2 = route_pts[0]
	var b: Vector2 = route_pts[route_pts.size() - 1]
	if a.distance_to(b) < 30.0:
		route_pts = PackedVector2Array()
		return
	route_wp = Vector2.INF
	var bd: float = 50.0
	for p: Vector2 in route_pts:
		var d: float = p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
		if d > bd:
			bd = d
			route_wp = p
	target = b
	_preview()
	UiKit.snd("ui_select")



func _tick_legs() -> void :
	if legs.is_empty() or _nv() == null:
		return
	for key: Variant in legs.keys():
		var e: Array = legs[key]
		var k: int = int(key)
		var ss: Array = my_ships().filter( func(s: Ship) -> bool: return (s.fleet == k) if k > 0 else (s.id == - k))
		if ss.is_empty():
			legs.erase(key)
			continue
		var lead: Ship = ss[0]
		if lead.pos.distance_to(e[0]) > 90.0:
			continue
		legs.erase(key)
		_dock("dock_order", [[[k if k > 0 else - lead.id, 1]], String(e[2]), e[1], []])




func open_to_fleet_menu(anchor: Control, ids_in: Array = []) -> void :
	var ids: Array = ids_in if not ids_in.is_empty() else checked.keys()
	if ids.is_empty():
		return
	var in_fleet: bool = false
	for sid0: Variant in ids:
		var s0: Ship = _nv().ship(int(sid0))
		in_fleet = in_fleet or (s0 != null and s0.fleet != 0)
	var items: Array = []
	for fl: Dictionary in fleets():
		var fid: int = int(fl["id"])
		items.append({"icon": "icon_fleet", "text": Loc.uname(String(fl.get("name", "Флот"))).to_upper(), "sub": Loc.t("сейчас %s") % [(Loc.n((fl.get("ships", []) as Array).size(), "%d корабль", "%d корабля", "%d кораблей") % ((fl.get("ships", []) as Array).size()))], 
			"cb": func() -> void :
				_fleet_cmd("fleet_assign", [gw.player.id, fid, ids], func(r: Variant) -> void :
					if r == null or int(r) <= 0:
						hud.show_toast("Не удалось: корабли или флот уже не ваши")
						return
					hud.show_toast("%s → «%s»" % [(Loc.n(int(r), "%d корабль", "%d корабля", "%d кораблей") % (int(r))), Loc.uname(String(fl.get("name", "")))])
					_after_assign(fid))})
	items.append({"icon": "icon_group_add", "text": "НОВЫЙ ФЛОТ", "sub": Loc.t("из %s") % [(Loc.n(ids.size(), "%d корабля", "%d кораблей", "%d кораблей") % (ids.size()))], "gold": true, "cb": func() -> void : open_fleet_sheet("new", 0, ids)})
	if in_fleet:
		items.append({"icon": "icon_close", "text": "УБРАТЬ ИЗ ФЛОТОВ", "sub": "станут «без группы»", "cb": func() -> void :
			_fleet_cmd("fleet_unassign", [gw.player.id, ids], func(_r: Variant) -> void : refresh())
			set_selecting(false)})
	_popover(anchor, Loc.t("ВО ФЛОТ: %s") % [(Loc.n(ids.size(), "%d КОРАБЛЬ", "%d КОРАБЛЯ", "%d КОРАБЛЕЙ") % (ids.size()))], items)



func _after_assign(fid: int) -> void :
	selecting = false
	checked.clear()
	if tab_fid == FREE_TAB and not free_ships().is_empty():
		refresh()
	else:
		set_tab(fid)



func _free_chip() -> Button:
	var fr: Array = free_ships()
	var nw: int = fr.filter( func(s: Ship) -> bool: return s.fresh).size()
	var sub: String = (Loc.n(nw, "%d новый", "%d новых", "%d новых") % (nw)) if nw > 0 else Loc.t("не во флотах")
	var b: Button = _chip("БЕЗ ГРУППЫ", sub, null, tab_fid == FREE_TAB, func() -> void :
		if tab_fid == FREE_TAB and not selecting and not free_ships().is_empty():
			open_to_fleet_menu(strip, free_ships().map( func(s: Ship) -> int: return s.id))
		else:
			set_tab(FREE_TAB))
	b.name = "NavyFreeChip"
	var hb: Control = b.get_child(0) as Control
	var bd: Label = _pill(str(fr.size()), Color("d23a2a") if nw > 0 else Color("6b5a44"), UiKit.OUTLINE, Color.WHITE)
	bd.custom_minimum_size = Vector2(18, 18)
	bd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(bd)
	b.custom_minimum_size.x += ceilf(maxf(18.0, UiKit.f_black.get_string_size(str(fr.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 10.0) + 5.0)
	b.set_meta("badge", bd)
	return b



func _pill(text: String, bg: Color, border: Color, fg: Color = UiKit.OUTLINE) -> Label:
	var l: Label = UiKit.lbl(text, 9, fg, 2, 0)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	var s: = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(8 if text.length() <= 3 else 3)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	l.add_theme_stylebox_override("normal", s)
	l.custom_minimum_size = Vector2(0, 15)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l



func _wide_btn(text: String, sub: String, icon_n: String, colour: String) -> Button:
	var b: Button = UiKit.big("", colour, "", 44.0, 10)
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hb: = HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 8
	hb.offset_right = -8
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	hb.add_child(_icon(icon_n, 22))
	var tv: = VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", -1)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tv)
	var tl: Label = UiKit.lbl(text, 11, UiKit.TEXT, 2, 3)
	tl.clip_text = true
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(tl)
	var sl: Label = UiKit.lbl(sub, 9, UiKit.MUTED, 1, 2)
	sl.clip_text = true
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(sl)
	b.set_meta("lb", tl)
	b.set_meta("sub", sl)
	UiKit.press_fx(b)
	return b


func fleet_menu(fid: int, anchor: Control) -> void :
	var fl: Dictionary = fleet(fid)
	if fl.is_empty():
		return
	var items: Array = [
		{"icon": "icon_rename", "text": "ИЗМЕНИТЬ", "sub": "название и цвет", "cb": func() -> void : open_fleet_sheet("edit", fid, [])}, 
		{"icon": "icon_close", "text": "РАСФОРМИРОВАТЬ", "sub": "корабли уйдут в «БЕЗ ГРУППЫ»", "cb": func() -> void :
			_fleet_cmd("fleet_disband_by", [gw.player.id, fid], func(_r: Variant) -> void :
				tab_fid = FREE_TAB
				refresh())}]
	_popover(anchor, Loc.t("ФЛОТ · %s") % [Loc.name(String(fl.get("name", ""))).to_upper()], items)


func open_fleet_sheet(kind: String, fid: int, ids: Array) -> void :
	_close_pop()
	_close_sheet()
	if _api("fleets_of", [gw.player.id]) == null:
		hud.show_toast("Флоты недоступны в этой версии")
		return
	var fl: Dictionary = fleet(fid)
	var used: Dictionary = {}
	for f2: Dictionary in fleets():
		used[int(f2.get("ci", -1))] = true
	var ci: int = 3
	for i in 8:
		if not used.has((i + 3) % 8):
			ci = (i + 3) % 8
			break
	sheet_state = {"kind": kind, "fid": fid, "ids": ids, "name": Loc.uname(String(fl.get("name", "Флот %d" % (fleets().size() + 1)))), 
		"src": String(fl.get("name", "Флот %d" % (fleets().size() + 1))), "ci": int(fl.get("ci", ci))}
	scrim = Control.new()
	scrim.position = Vector2.ZERO
	scrim.size = get_viewport_rect().size
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.32)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.add_child(dim)
	sheet = PanelContainer.new()
	var ssb: StyleBox = UiKit.sb("wb_window", 10, 10)
	ssb.content_margin_bottom = 14.0 + hud._safe_margins().y
	sheet.add_theme_stylebox_override("panel", ssb)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	sheet.add_child(vb)
	var hr: = HBoxContainer.new()
	vb.add_child(hr)
	var tl: Label = UiKit.lbl(Loc.t("Новый флот") if kind == "new" else Loc.t("Флот", "fleet"), 18, UiKit.TITLE, 3, 4)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tl)
	var x: Button = UiKit.close_btn(44.0)
	x.pressed.connect(_close_sheet)
	hr.add_child(x)
	if kind == "new":
		vb.add_child(UiKit.lbl((Loc.n(ids.size(), "%d корабль", "%d корабля", "%d кораблей") % (ids.size())) + (Loc.t(" · выбраны в списке") if not ids.is_empty() else Loc.t(" · добавьте потом через «ВО ФЛОТ»")), 9, UiKit.MUTED, 1, 2))
	vb.add_child(UiKit.lbl("НАЗВАНИЕ", 10, UiKit.TITLE, 2, 3))
	var le: = LineEdit.new()
	le.text = String(sheet_state["name"])
	le.max_length = 12
	le.custom_minimum_size = Vector2(0, 44)
	le.add_theme_font_override("font", UiKit.f_black)
	le.add_theme_font_size_override("font_size", 15)
	le.add_theme_color_override("font_color", UiKit.TEXT)
	le.add_theme_color_override("caret_color", UiKit.GOLD)
	for st: String in ["normal", "focus", "read_only"]:
		le.add_theme_stylebox_override(st, UiKit.sb("wb_slot" if st != "focus" else "wb_slot_pressed", 10, 6))
	le.text_changed.connect( func(s: String) -> void :
		sheet_state["name"] = s
		_sheet_refresh())
	vb.add_child(le)
	vb.add_child(UiKit.lbl("ЦВЕТ ФЛАГА", 10, UiKit.TITLE, 2, 3))
	var cr: = HBoxContainer.new()
	cr.add_theme_constant_override("separation", 6)
	cr.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(cr)
	var sw: Array = []
	for i2 in 8:
		var b: = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(36, 44)
		var fill: = ColorRect.new()
		fill.color = U.color(i2)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(fill)
		var ck: TextureRect = U.icon("wb_check", 14)
		b.add_child(ck)
		b.resized.connect( func() -> void :
			fill.position = Vector2(6, 8)
			fill.size = b.size - Vector2(12, 16)
			ck.position = ((b.size - ck.size) * 0.5).round())
		var cii: int = i2
		b.pressed.connect( func() -> void :
			sheet_state["ci"] = cii
			_sheet_refresh())
		UiKit.press_fx(b)
		cr.add_child(b)
		sw.append([b, ck])
	var ok: Button = UiKit.big(Loc.t("СОЗДАТЬ") if kind == "new" else Loc.t("ГОТОВО"), "green", "", 46.0, 13)
	ok.pressed.connect(_sheet_done)
	vb.add_child(ok)
	sheet_refs = {"le": le, "sw": sw, "ok": ok}
	_sheet_refresh()
	var vp: Vector2 = get_viewport_rect().size
	sheet.custom_minimum_size.x = vp.x
	sheet.reset_size()
	sheet.size = Vector2(vp.x, sheet.get_combined_minimum_size().y)
	sheet.position = Vector2(0, vp.y - sheet.size.y)
	UiKit.snd("ui_open")


func _sheet_refresh() -> void :
	for i in 8:
		var e: Array = sheet_refs["sw"][i]
		var on: bool = i == int(sheet_state["ci"])
		var s: StyleBox = UiKit.sb("wb_slot_active" if on else "wb_slot", 2)
		for st: String in ["normal", "hover", "pressed", "hover_pressed"]:
			(e[0] as Button).add_theme_stylebox_override(st, s)
		(e[0] as Button).add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		(e[1] as Control).visible = on
	(sheet_refs["ok"] as Button).disabled = String(sheet_state["name"]).strip_edges() == ""


func _sheet_done() -> void :
	var st: Dictionary = sheet_state
	if st.has("src") and String(st["name"]) == Loc.uname(String(st["src"])):
		st["name"] = String(st["src"])
	var nm: String = String(st["name"]).strip_edges().left(12)
	var col: Color = U.color(int(st["ci"]))
	if String(st.get("kind", "new")) == "new":
		var ids: Array = st["ids"]
		_close_sheet()
		_fleet_cmd("fleet_create", [gw.player.id, nm, col, ids, int(st["ci"])], func(fid: Variant) -> void :
			if fid == null or int(fid) <= 0:
				hud.show_toast("Флот не создан")
				return
			var n: int = (fleet(int(fid)).get("ships", []) as Array).size()
			hud.show_toast(Loc.t("Создан флот «%s»: %s") % [nm, (Loc.n(n, "%d корабль", "%d корабля", "%d кораблей") % (n))])
			_chips_sig = ""
			if n > 0:
				_after_assign(int(fid))
			else:
				set_tab(int(fid)))
	else:
		_close_sheet()
		_fleet_cmd("fleet_style", [gw.player.id, int(st["fid"]), nm, col, int(st["ci"])], func(_r: Variant) -> void :
			_chips_sig = ""
			refresh())


func _close_sheet() -> void :
	if sheet != null and is_instance_valid(sheet):
		var le: Variant = sheet_refs.get("le")
		if le is LineEdit and is_instance_valid(le):
			(le as LineEdit).release_focus()
		sheet.queue_free()
	sheet = null
	sheet_refs = {}
	_close_pop()




func _popover(anchor: Control, title: String, items: Array) -> void :
	_close_pop()
	scrim = Control.new()
	scrim.position = Vector2.ZERO
	scrim.size = get_viewport_rect().size
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect( func(e: InputEvent) -> void :
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_close_pop())
	add_child(scrim)
	pop = PanelContainer.new()
	pop.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 6, 6))
	pop.custom_minimum_size = Vector2(minf(240.0, get_viewport_rect().size.x - 12.0), 0)
	pop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pop)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pop.add_child(vb)
	var tl: Label = UiKit.lbl(title, 10, UiKit.TITLE, 2, 3)
	tl.clip_text = true
	vb.add_child(tl)
	for it: Dictionary in items:
		var b: Button = UiKit.big("", "gold" if bool(it.get("gold", false)) else "stone", "", 44.0, 10)
		b.custom_minimum_size = Vector2(0, 44)
		var hb: = HBoxContainer.new()
		hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = 8
		hb.offset_right = -8
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		hb.add_child(_icon(String(it.get("icon", "")), 22))
		var tv: = VBoxContainer.new()
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", -1)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tv)
		tv.add_child(UiKit.lbl(String(it["text"]), 11, UiKit.TEXT, 2, 3))
		if String(it.get("sub", "")) != "":
			var sl: Label = UiKit.lbl(String(it["sub"]), 9, Palette.c("alert_red") if bool(it.get("warn", false)) else UiKit.MUTED, 1, 2)
			sl.clip_text = true
			tv.add_child(sl)
		var cb: Callable = it["cb"]
		b.pressed.connect( func() -> void :
			_close_pop()
			cb.call())
		vb.add_child(b)
	var ar: Rect2 = anchor.get_global_rect()
	var vp: Vector2 = get_viewport_rect().size
	var sz: Vector2 = pop.get_combined_minimum_size()
	pop.size = sz
	var y: float = ar.position.y - sz.y - 6.0
	if y < 60.0:
		y = minf(ar.end.y + 6.0, vp.y - sz.y - 4.0)
	pop.position = Vector2(roundf(clampf(ar.get_center().x - sz.x * 0.5, 4.0, vp.x - sz.x - 4.0)), roundf(maxf(4.0, y)))
	UiKit.pop_in(pop, 0.9, 0.16)


func _close_pop() -> void :
	if pop != null and is_instance_valid(pop):
		pop.queue_free()
	if scrim != null and is_instance_valid(scrim) and (sheet == null or not is_instance_valid(sheet)):
		scrim.queue_free()
		scrim = null
	pop = null




func _service(key: String) -> void :
	var s: Ship = _nv().ship(sel_sid)
	if s == null:
		return
	var sname: String = s.name

	_dock("dock_service", [s.id, key], func(r: Variant) -> void : _serviced(sname, key, String(r) if r is String else Loc.t("Команда не выполнена")))


func _serviced(sname: String, key: String, why: String) -> void :
	if why != "":
		hud.show_toast(why)
		UiKit.snd("ui_error")
	else:
		UiKit.snd("ui_money")
		hud.show_toast("%s: %s" % [sname, Loc.t("ремонт") if key == "repair" else Loc.t("погрузка ракет")])
	refresh()




func _process(delta: float) -> void :
	_tick_legs()
	if not visible or not is_open:
		return
	if gw.player == null or gw.player.eliminated or gw.player != _player or _nv() == null:
		close()
		return
	if bool(hud.ops_panel.visible) or (hud.panel != null and is_instance_valid(hud.panel)):
		close()
		return
	for e: Variant in hud.cmd_btns:
		var cb: Control = (e as Array)[0]
		if cb != null and cb.visible:
			cb.visible = false
	for r: Button in rows.values():
		var hold: Array = r.get_meta("hold")
		if float(hold[0]) >= 0.0:
			if not r.button_pressed:
				hold[0] = -1.0
				continue
			hold[0] = float(hold[0]) + delta
			if float(hold[0]) >= 0.4 and not bool(hold[1]):
				hold[1] = true
				(r.get_meta("long") as Callable).call()
	for ch: Node in strip.get_children():
		if ch is Button and (ch as Button).has_meta("long"):
			var h2: Array = (ch as Button).get_meta("hold")
			if float(h2[0]) >= 0.0:
				if not (ch as Button).button_pressed:
					h2[0] = -1.0
					continue
				h2[0] = float(h2[0]) + delta
				if float(h2[0]) >= 0.45 and not bool(h2[1]):
					h2[1] = true
					((ch as Button).get_meta("long") as Callable).call()
	if confirm != null and is_instance_valid(confirm):
		var vp: Vector2 = get_viewport_rect().size
		confirm.size.x = vp.x - 12.0
		confirm.position = Vector2(6, roundf(hud.tab_row.get_global_rect().position.y - confirm.size.y - 6.0))
	if sheet != null and is_instance_valid(sheet):
		var le: LineEdit = sheet_refs.get("le")
		var kb: float = 0.0
		if le != null and is_instance_valid(le) and le.has_focus() and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			kb = float(DisplayServer.virtual_keyboard_get_height()) * (get_viewport_rect().size.x / maxf(1.0, float(DisplayServer.window_get_size().x)))
		sheet.position.y = get_viewport_rect().size.y - kb - sheet.size.y
	_rt -= delta
	if _rt <= 0.0 and not hud._finger_down() and (pop == null or not is_instance_valid(pop)) and (sheet == null or not is_instance_valid(sheet)):
		refresh()
