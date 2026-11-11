extends Control












const GAP: float = 25.0
const HoldTip = preload("res://ui/ui24/hold_tip.gd")
const LIFE: float = 14.0
const SECTION: String = "tips"

const TIPS: Dictionary = {
	"war": ["ВОЙНА", "Армии воюют сами, по своему РЕЖИМУ. Соберите их в группу (АРМИЯ) и нарисуйте линию фронта — так граница держится без лишних тапов."], 
	"front": ["ЛИНИЯ ФРОНТА", "Армии группы встают вдоль линии. ПЛАН АТАКИ — стрелка на карте: группа наступает по ней, линия сдвигается за ней."], 
	"army": ["АРМИЯ", "Казарма — это армия. Вкладка АРМИЯ → АРМИИ: все армии списком, их РЕЖИМ, БЫСТРЫЙ МАРШ и группы."], 
	"strike": ["УДАРЫ", "ОТРК, дронопорты и самолёты бьют по точкам на карте. ПВО противника сбивает часть — бейте по нескольким целям сразу."], 
	"navybase": ["МОРБАЗА", "Тап по морбазе — верфь: корпус и модули, цена и время внизу. Готовый корабль спускают на воду рядом."], 
	"fleet": ["ФЛОТ", "Все корабли — во вкладке ФЛОТ. Выберите корабль, приказ ДВИЖЕНИЕ и точку на море. ПКР и КР — в приказах корабля."], 
	"ally": ["СОЮЗ", "На земле союзника можно ставить ПВО, казармы и держать фронт, как по праву прохода."], 
	"inbox": ["ВХОДЯЩИЕ", "Просьбы и предложения стран ждут здесь — кнопка с письмом слева вверху. Ответ — ДА / НЕТ; без ответа срок истечёт."], 
	"uranium": ["УРАН", "На вашей земле залежь урана (зелёный значок). Урановая шахта (ГОРОДА › РУДНИК прямо на зелёный значок) дорогая, но уран — топливо АЭС и дорогой товар."], 
	"npp": ["АЭС", "АЭС даёт +40 энергии и жжёт 1 уран за 90 с. Сетки и бетон её не защищают — поставьте рядом ЗРК и ПРО: без неё один налёт гасит полстраны."], 
}

const HELP: Dictionary = {
	"dip_sheet": ["ДИПЛОМАТИЯ", "Тап по стране — договоры, торговля, ультиматум. Полоска — мнение о вас: ниже нуля — ждите претензий. Сверху — запросы, ждущие ответа."], 
	"army_dock": ["АРМИИ", "Отметьте армии и дайте приказ: РЕЖИМ, БЫСТРЫЙ МАРШ, НА ФРОНТ. Группа держит свою линию фронта; новая армия группы берёт её приказ."], 
	"cmd_sheet": ["ШТАБ", "Сводка войн и угроз, автоматика для всех армий и приказы командования. Тап по группе — она в списке армий."], 
	"econ_hub": ["ЭКОНОМИКА", "ЦЕПОЧКИ — что производится и чего не хватает, СКЛАД — запасы и рынок, ДОХОДЫ — откуда деньги. Красное — дефицит."], 
	"navy_yard": ["ВЕРФЬ", "Корпус + модули = корабль; цена и время внизу. Слева все ваши верфи: тап — переход к ней."], 
	"navy_dock": ["ФЛОТ", "Корабли и флотилии. Выберите корабль и точку на море; ПАТРУЛЬ, КОНВОИ и удары ПКР / КР — в приказах."], 
	"conference_sheet": ["КОНФЕРЕНЦИЯ", "Сдавшаяся страна делится по очкам. Тапните территорию на карте (щипок — масштаб, ВСЕ — вся страна) или выберите во вкладке СПИСОК и подтвердите."], 
	"trade_sheet": ["ТОРГОВЛЯ", "Тап по ресурсу — внизу количество и КУПИТЬ или ПРОДАТЬ. Цена в строке — уже для этой сделки: у соседа дешевле, через порт импорт ×1,6, экспорт ×0,7.\nПокупка оплачивается сразу, продажа — когда груз доедет. Серая кнопка или цена с замком — тапните, скажет почему. Удерживайте КУПИТЬ — сделка повторяется.\nВ ПУТИ — что и когда приедет. ДОГОВОРЫ — излишки уходят соседям сами."], 
	"inbox_sheet": ["ВХОДЯЩИЕ", "Запросы ждут здесь со своим таймером: ДА / НЕТ сразу, одинаковые — ВСЕМ ДА / ВСЕМ НЕТ. Ниже — журнал событий, которые не попали в ленту."], 
}

var hud: Node
var gw: GameWorld
var seen: Dictionary = {}
var card: PanelContainer = null
var _title: Label
var _text: Label
var _until: float = 0.0
var _last: float = 0.0
var _auto: bool = false
var _pending_help: Array = []
var _t: float = 0.0
var _clock: float = 0.0
var shown_log: Array = []
var _cur: String = ""
var _shown_at: float = 0.0
var _requeued: Dictionary = {}


func mount(h: Node) -> void :
	hud = h
	gw = h.gw
	name = "HelpTips"
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.root.add_child(self)
	z_index = 40
	_load()


func _load() -> void :
	var cf: = ConfigFile.new()
	if cf.load(Save.prefs_path) != OK or not cf.has_section(SECTION):
		return
	for k: String in cf.get_section_keys(SECTION):
		seen[k] = true



func _unmark(id: String) -> void :
	seen.erase(id)
	var cf: = ConfigFile.new()
	if cf.load(Save.prefs_path) == OK and cf.has_section_key(SECTION, id):
		cf.erase_section_key(SECTION, id)
		cf.save(Save.prefs_path)




func _covered() -> bool:
	for nm: String in ["confirm_panel", "prompt_panel", "ops_panel"]:
		var c: Variant = hud.get(nm)
		if c is Control and (c as Control).visible:
			return true
	return bool(hud.call("ui24_open_now")) or _hits(card.get_global_rect().grow(-1.0))


func _hits(r: Rect2) -> bool:
	for nm: String in ["confirm_panel", "prompt_panel", "ops_panel", "sel_card"]:
		var c: Variant = hud.get(nm)
		if c is Control and is_instance_valid(c) and (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().intersects(r):
			return true
	return false



func _zone() -> Rect2:
	var y: float = 64.0
	var ln: Control = hud.get("lane")
	if ln != null and is_instance_valid(ln):
		y = float(ln.call("bottom")) + 6.0
	return Rect2(8.0, y, get_viewport_rect().size.x - 16.0, 110.0)


func _mark(id: String) -> void :
	seen[id] = true
	var cf: = ConfigFile.new()
	if cf.load(Save.prefs_path) != OK:
		cf = ConfigFile.new()
	cf.set_value(SECTION, id, true)
	cf.save(Save.prefs_path)



func reset_seen() -> void :
	seen.clear()
	var cf: = ConfigFile.new()
	if cf.load(Save.prefs_path) == OK and cf.has_section(SECTION):
		cf.erase_section(SECTION)
		cf.save(Save.prefs_path)


func _build() -> void :
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.sb("wb_tooltip", 10, 7))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.visible = false
	add_child(card)
	card.gui_input.connect( func(ev: InputEvent) -> void :
		var mb: = ev as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			accept_event()
			hide_card())
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hb)
	var ic: TextureRect = UiKit.icon_rect("icon_hint", 20.0)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(ic)
	_title = UiKit.lbl("", 12, UiKit.GOLD, 2, 3)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(_title)
	var ok: Button = UiKit.big("ПОНЯТНО", "green", "", 44.0, 10)
	ok.custom_minimum_size.x = 96
	ok.pressed.connect(hide_card)
	hb.add_child(ok)
	_text = UiKit.lbl("", 10, UiKit.TEXT, 1, 2)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.max_lines_visible = 4
	v.add_child(_text)


func is_showing() -> bool:
	return card != null and card.visible


func show_card(title: String, text: String, auto: bool = false) -> void :
	_auto = auto
	if card == null:
		_build()
	_title.text = title
	_text.text = text
	_text.max_lines_visible = 4 if auto else 14
	card.visible = true
	_hold_lane_tips(true)
	_until = _clock + LIFE
	_place()
	UiKit.pop_in(card, 0.92, 0.16)


func hide_card() -> void :
	if card != null and card.visible:
		card.visible = false
		_last = _clock
		_hold_lane_tips(false)



func _hold_lane_tips(on: bool) -> void :
	var ln: Node = hud.get("lane")
	if ln != null and is_instance_valid(ln):
		ln.set("hold_tips", on)
		if on:
			ln.call("remove_kind", "tip")



func _place() -> void :
	if card == null or not card.visible:
		return
	var vp: Vector2 = get_viewport_rect().size
	var ln: Control = hud.get("lane")
	var y: float = 64.0
	if ln != null and is_instance_valid(ln):
		y = float(ln.call("bottom")) + 6.0
		var pill: Variant = ln.get("_inbox_btn")
		if pill is Control and (pill as Control).visible:
			y = maxf(y, (pill as Control).get_global_rect().end.y + 6.0)
	var x1: float = vp.x - 8.0
	for e: Variant in hud.get("cmd_btns"):
		var cb: Control = (e as Array)[0]
		if cb != null and is_instance_valid(cb) and cb.is_visible_in_tree():
			var r: Rect2 = cb.get_global_rect()
			if r.end.y > y and r.position.y < y + 140.0:
				x1 = minf(x1, r.position.x - 6.0)
	var w: float = clampf(x1 - 8.0, 220.0, 320.0)
	card.custom_minimum_size = Vector2(w, 0)
	card.reset_size()
	var cx: float = roundf(maxf(8.0, minf(8.0 + (x1 - 8.0 - w) * 0.5, x1 - w)))


	var hold: Control = hud.get("holder") as Control
	var floor_y: float = hold.global_position.y - 8.0 if hold != null else vp.y - 8.0
	for nm: String in ["prompt_panel", "plan_panel", "prompt_panel", "plan_panel"]:
		var pc: Variant = hud.get(nm)
		if pc is Control and is_instance_valid(pc) and (pc as Control).is_visible_in_tree():
			var pr: Rect2 = (pc as Control).get_global_rect()
			if pr.intersects(Rect2(cx, y, card.size.x, card.size.y)) and pr.end.y + 6.0 + card.size.y <= floor_y:
				y = pr.end.y + 6.0
	card.position = Vector2(cx, roundf(y))




func attach_help(sheet: Control) -> void :
	if sheet == null or not is_instance_valid(sheet) or sheet.has_meta("uxc_help"):
		return
	for e: Array in _pending_help:
		if e[0] == sheet:
			return
	_pending_help.append([sheet, 0])


func _try_help() -> void :
	for i: int in range(_pending_help.size() - 1, -1, -1):
		var e: Array = _pending_help[i]
		e[1] = int(e[1]) + 1
		var r: int = _attach_now(e[0] as Control) if is_instance_valid(e[0]) else 1
		if r != 0 or int(e[1]) > 20:
			_pending_help.remove_at(i)



func _attach_now(sheet: Control) -> int:
	if sheet.has_meta("uxc_help"):
		return 1
	var s: Script = sheet.get_script() as Script
	var key: String = s.resource_path.get_file().get_basename() if s != null else ""
	if not HELP.has(key):
		return 1
	var x: Button = _find_close(sheet)
	var pn: Variant = sheet.get("panel")
	if x == null and pn is Node and is_instance_valid(pn):
		x = _find_close(pn as Node)
	if x == null or not (x.get_parent() is BoxContainer):
		return 1
	var row: BoxContainer = x.get_parent() as BoxContainer
	if not x.is_visible_in_tree() or row.size.x <= 1.0:
		return 0
	var free: float = row.size.x - row.get_combined_minimum_size().x
	if free < 50.0:
		sheet.set_meta("uxc_help", false)
		return 1
	sheet.set_meta("uxc_help", true)
	var q: Button = UiKit.big("?", "stone", "", 44.0, 14)
	q.name = "HelpQ"
	q.custom_minimum_size = Vector2(44, 44)
	q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	q.tooltip_text = "Что здесь"
	q.pressed.connect( func() -> void :
		if is_showing() and _title.text == String(HELP[key][0]):
			hide_card()
		else:
			show_card(String(HELP[key][0]), _help_text(key)))
	var par: Node = x.get_parent()
	par.add_child(q)
	par.move_child(q, x.get_index())
	return 1



func _help_text(key: String) -> String:
	var t: String = String(HELP[key][1])
	var ls: String = HoldTip.lines_for(key)
	if ls != "":
		t += "\n" + ls
	if key == "trade_sheet":
		return t
	return Loc.t("%s\nУдерживайте любую кнопку — подсказка о ней.") % [t]


func _find_close(n: Node) -> Button:
	var want: Texture2D = UiKit.tex("wb_close")
	var want2: Texture2D = UiKit.tex("icon_close")
	var st: Array = [n]
	while not st.is_empty():
		var c: Node = st.pop_front()
		if c is Button and c.get_child_count() > 0 and c.get_child(0) is TextureRect:
			var t: Texture2D = (c.get_child(0) as TextureRect).texture
			if t != null and (t == want or t == want2 or (want != null and t is AtlasTexture and want is AtlasTexture and (t as AtlasTexture).region == (want as AtlasTexture).region)):
				return c as Button
		for k: Node in c.get_children():
			st.append(k)
	return null


func _blocked_urgent() -> bool:
	var ln: Node = hud.get("lane")
	if ln != null and is_instance_valid(ln):
		for k: String in ["ult", "war", "alert"]:
			if bool(ln.call("has_kind", k)):
				return true
	return false


func _blocked() -> bool:
	if not GameConfig.hints or GameConfig.tutorial:
		return true
	var mn: Node = hud.get("main_node")
	if mn != null:
		var tut: Object = mn.get("tutorial")
		if tut != null and bool(tut.get("active")):
			return true
		if bool(mn.get("in_menu")):
			return true
	if _blocked_urgent():
		return true
	var ln: Node = hud.get("lane")
	if ln != null and is_instance_valid(ln):
		if bool(ln.call("has_kind", "tip")) or (ln.call("state") as Array).size() > 2:
			return true
	for nm: String in ["confirm_panel", "prompt_panel", "ops_panel"]:
		var c: Variant = hud.get(nm)
		if c is Control and (c as Control).visible:
			return true
	if hud.call("ui24_open_now") or _hits(_zone()):
		return true
	return hud._finger_down()


func _want() -> String:
	var p: Country = gw.player
	if p == null or p.eliminated:
		return ""
	if not seen.has("war") and not p.at_war.is_empty():
		return "war"
	if not seen.has("inbox"):
		var ln: Node = hud.get("lane")
		if ln != null and is_instance_valid(ln) and int(ln.get("inbox_n")) > 0:
			return "inbox"
	if not seen.has("front"):
		for g: Variant in p.get("army_groups") if p.get("army_groups") != null else []:
			if g is Dictionary and (g as Dictionary).has("front") and not ((g as Dictionary)["front"] as Dictionary).is_empty():
				return "front"
	if not seen.has("ally") and gw.diplo != null:
		for c: Country in gw.countries:
			if c != p and not c.eliminated and gw.diplo.allied(p.id, c.id):
				return "ally"
	if not seen.has("npp") and gw.mil.has_kind(p.id, Facility.Kind.NUCLEAR_PLANT):
		return "npp"
	if not seen.has("uranium") and gw.econ._has_free_deposit(p, ["uranium"]):
		return "uranium"
	if not seen.has("fleet") and gw.get("navy") != null:
		for sh: Variant in gw.navy.ships:
			if sh != null and int(sh.get("c")) == p.id:
				return "fleet"
	var need: Dictionary = {}
	for k2: String in ["army", "strike", "navybase"]:
		if not seen.has(k2):
			need[k2] = true
	if need.is_empty():
		return ""
	for f: Facility in gw.mil.facilities:
		if f.country_id != p.id:
			continue
		if need.has("army") and f.kind == Facility.Kind.BARRACKS:
			return "army"
		if need.has("strike") and (f.kind == Facility.Kind.TEL or f.kind == Facility.Kind.DRONE_PORT):
			return "strike"
		if need.has("navybase") and f.kind == Facility.Kind.NAVAL_BASE:
			return "navybase"
	return ""


func _process(delta: float) -> void :
	_clock += delta
	if not _pending_help.is_empty():
		_try_help()
	if card != null and card.visible:
		_place()
		if _clock > _until or (_auto and _blocked_urgent()):
			hide_card()
		elif _auto and _covered():
			if _cur != "" and _clock - _shown_at < 5.0 and not _requeued.has(_cur):
				_requeued[_cur] = true
				_unmark(_cur)
			hide_card()
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.5
	if gw == null or _clock - _last < GAP or _blocked():
		return
	var id: String = _want()
	if id == "":
		return
	_mark(id)
	shown_log.append(id)
	_cur = id
	_shown_at = _clock
	show_card(String(TIPS[id][0]), String(TIPS[id][1]), true)
