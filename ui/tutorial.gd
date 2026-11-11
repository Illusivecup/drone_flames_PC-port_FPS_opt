class_name Tutorial
extends CanvasLayer









const FrontPlan = preload("res://game/front_plan.gd")
const REWARD: int = 100
const SKIP_AFTER: float = 45.0




const STEPS: Array = [

	{"ch": "КАРТА", "t": "КАРТА И ВРЕМЯ", "w": "Двигайте карту пальцем, щипок — масштаб. Нажмите СКОРОСТЬ слева внизу: до x20.", 
		"y": "Стройка и армии живут в реальном времени — ускоряйте, когда ждёте.", "k": "speed", "p": 0, "keys": ["speed"], "r": 0}, 
	{"ch": "КАРТА", "t": "РЕЖИМЫ КАРТЫ", "w": "Вкладка КАРТА → РЕЖИМЫ: политика, руды, логистика, военная. Откройте список.", 
		"y": "Военный режим показывает фронты и армии, руды — свободные залежи.", "k": "mapmode", "p": 0, "keys": ["map_modes"], "r": 0}, 
	{"ch": "КАРТА", "t": "СТОЛИЦА", "w": "Вкладка ГОРОДА → СТОЛИЦА, тап по свободной земле и «✓ ДА».", 
		"y": "Столица даёт землю, доход и первую ТЭЦ — с неё начинается страна.", "k": "capital", "p": 1, "keys": ["capital"], "r": 0}, 

	{"ch": "ЭКОНОМИКА", "t": "КОЛХОЗ", "w": "Вкладка ГОРОДА → КОЛХОЗ, тап по земле рядом со столицей и «✓ ДА».", 
		"y": "Колхоз — самый дешёвый доход, а еда кормит армию.", "k": "farm", "p": 1, "keys": ["farm"], "btn": ["ПОКАЗАТЬ"], "r": REWARD}, 
	{"ch": "ЭКОНОМИКА", "t": "ЗАВОД ТОВАРОВ", "w": "Так же поставьте ЗАВОД; пока не нажали «✓ ДА», карту можно двигать и приближать.", 
		"y": "Товары — главный доход страны, но заводу нужна энергия.", "k": "civ", "p": 1, "keys": ["civ"], "btn": ["ПОКАЗАТЬ"], "r": REWARD}, 
	{"ch": "ЭКОНОМИКА", "t": "ЭНЕРГИЯ", "w": "Постройте вторую станцию: ТЭЦ или дешёвое СОЛНЦЕ.", 
		"y": "Каждый завод и рудник берёт энергию; без запаса сети города и цеха гаснут.", "k": "power", "p": 1, "keys": ["solar_farm", "power"], "btn": ["ПОКАЗАТЬ"], "r": REWARD}, 
	{"ch": "ЭКОНОМИКА", "t": "РУДНИК", "w": "Вкладка ГОРОДА → РУДНИК прямо на значок залежи у столицы.", 
		"y": "Металл и титан нужны технике, ракетам и дорогим постройкам.", "k": "mine", "p": 1, "keys": ["mine"], "btn": ["ПОКАЗАТЬ"], "r": REWARD}, 
	{"ch": "ЭКОНОМИКА", "t": "УЛУЧШЕНИЕ", "w": "Тапните по колхозу или заводу и нажмите на карточке «УР 1→2».", 
		"y": "Уровень даёт больше выпуска за те же рабочие места. Город растёт от добычи сам.", "k": "upgrade", "p": -1, "btn": ["УР "], "r": REWARD}, 
	{"ch": "ЭКОНОМИКА", "t": "ЭКОНОМИКА", "w": "Вкладка ПОЛИТ. → ЭКОНОМИКА: цепочки, склад, доходы и расходы.", 
		"y": "Красная цепочка = где-то затор; кнопка ИСПРАВИТЬ сама покажет, что строить.", "k": "win:economy", "p": 5, "keys": ["economy"], "r": 0}, 
	{"ch": "ЭКОНОМИКА", "t": "ТОРГОВЛЯ", "w": "Откройте ТОРГОВЛЮ: покупка и продажа ресурсов, а порт на берегу возит их сам.", 
		"y": "«Нет титана» — купите, отнимите или замените: замена дороже и просит второе «✓ ДА».", "k": "win:trade", "p": 5, "keys": ["trade"], "r": 0}, 

	{"ch": "ОБОРОНА", "t": "ПВО", "w": "Вкладка ПВО → ОГН.ГРУП. (дёшево) или ЗСУ рядом со столицей.", 
		"y": "ПВО сбивает дроны врага; ЗРК и ПРО — ракеты и авиацию.", "k": "ad", "p": 3, "keys": ["ad_mfg", "ad_spaag"], "btn": ["ПОКАЗАТЬ"], "r": REWARD}, 

	{"ch": "АРМИЯ", "t": "КАЗАРМЫ", "w": "Вкладка АРМИЯ → КАЗАРМЫ рядом со столицей.", 
		"y": "Одни казармы — одна армия до 12 бойцов, она набирается сама.", "k": "barracks", "p": 4, "keys": ["barracks"], "r": REWARD}, 
	{"ch": "АРМИЯ", "t": "СБОРКА", "w": "Тапните по казармам, на их карточке нажмите СБОРКА и выберите: штурм, мотопехота, ПТ-оборона…", 
		"y": "Сборка решает, кого обучат: танкам нужен титан, пехоте хватит еды.", "k": "build", "p": -1, "btn": ["СБОРКА"], "r": REWARD}, 
	{"ch": "АРМИЯ", "t": "БЫСТРЫЙ МАРШ", "w": "Когда появятся бойцы — коснитесь солдат: откроется карточка армии. БЫСТРЫЙ МАРШ и тап по цели.", 
		"y": "ИДТИ — провести путь пальцем. Передумали — ОТМЕНИТЬ над карточкой.", "k": "move", "p": -1, "btn": ["БЫСТРЫЙ", "АРМИЯ"], "r": REWARD}, 
	{"ch": "АРМИЯ", "t": "УКРЕПЛЕНИЯ", "w": "АРМИЯ → ОКОП (ведите пальцем рядом с армией) или БЛИНДАЖ, затем на карточке армии В ОКОПЫ.", 
		"y": "Пехота с ПТУР в окопе держит танки в разы дольше.", "k": "garrison", "p": 4, "keys": ["trench", "dugout"], "btn": ["В ОКОПЫ", "АРМИЯ"], "r": REWARD}, 
	{"ch": "АРМИЯ", "t": "РЕЖИМ АРМИИ", "w": "На карточке армии или группы: РЕЖИМ — ЖДУТ, ДЕРЖАТ или НАСТУПАЮТ. Нажмите ДЕРЖАТ.", 
		"y": "Армии сами держат свой район или наступают, пока вы строите.", "k": "stance", "p": 4, "keys": ["armies"], "btn": ["ДЕРЖАТ", "АРМИЯ", "№"], "r": REWARD}, 
	{"ch": "АРМИЯ", "t": "ГРУППА", "w": "АРМИЯ → АРМИИ → «+ НОВАЯ ГРУППА», коснитесь армии и ГОТОВО.", 
		"y": "Группе — один приказ на всех и своя линия фронта.", "k": "group", "p": 4, "keys": ["armies"], "btn": ["ГОТОВО", "+ НОВАЯ", "№"], "r": REWARD}, 
	{"ch": "АРМИЯ", "t": "ФРОНТ И ПЛАН АТАКИ", "w": "В войне: карточка группы → НА ФРОНТ и тап по границе. ПЛАН АТАКИ — стрелка вглубь врага.", 
		"y": "Сейчас войны нет — нажмите ДАЛЕЕ.", "k": "front", "opt": true, "p": -1, "btn": ["НА ФРОНТ", "ПЛАН АТАКИ"], "r": 0}, 

	{"ch": "УДАРЫ", "t": "ДРОНЫ И РАКЕТЫ", "w": "Вкладка УДАР: дроны (завод + дронопорт с рампой), ракеты ОТРК и КР — одна панель УДАР.", 
		"y": "РАЗВЕДКА найдёт цели в тумане. Удар по чужой земле = война.", "k": "next", "p": 2, "keys": ["launch", "recon"], "r": 0}, 
	{"ch": "УДАРЫ", "t": "АВИАЦИЯ", "w": "УДАР → АЭРОДРОМ: на его карточке — истребители, штурмовики, бомбардировщики.", 
		"y": "В войну справа — АВИА: УДАР КАБ и ПОДДЕРЖКА войск.", "k": "next", "p": 2, "keys": ["airfield"], "r": 0}, 
	{"ch": "ФЛОТ", "t": "ФЛОТ И ДЕСАНТ", "w": "Вкладка ФЛОТ: ПОРТ возит товары, МОРБАЗА строит корабли. Корабли бьют ПКР и КР.", 
		"y": "Десант — на карточке армии: БЫСТРЫЙ ДЕСАНТ от своей морбазы.", "k": "next", "p": 6, "keys": ["navbase", "port"], "r": 0}, 

	{"ch": "ПОЛИТИКА", "t": "ДИПЛОМАТИЯ", "w": "Вкладка ПОЛИТ. → ДИПЛОМАТ.: тап по стране — война, мир, перемирие, союз, торговля.", 
		"y": "Союзник воюет вместе с вами; ультиматум придёт красной плашкой с таймером — успейте ответить.", "k": "win:diplomacy", "p": 5, "keys": ["diplomacy"], "r": 0}, 
	{"ch": "ПОЛИТИКА", "t": "ВХОДЯЩИЕ", "w": "Просьбы стран ждут во ВХОДЯЩИХ — кнопка с письмом слева вверху (с первым запросом).", 
		"y": "Ответ ДА / НЕТ; у каждой просьбы свой таймер.", "k": "next", "p": -1, "inbox": true, "r": 0}, 
	{"ch": "ШТАБ", "t": "ШТАБ", "w": "Откройте ШТАБ справа: все армии, авто-приказы и авто-удары в одном месте.", 
		"y": "В войну под ним появятся АРТУДАР, ДЫМ и ГОСПИТАЛЬ.", "k": "win:command", "p": -1, "keys": ["command"], "r": 0}, 
	{"ch": "ШТАБ", "t": "СОХРАНЕНИЕ И ПОБЕДА", "w": "Обычная партия сохраняется сама раз в минуту — «ПРОДОЛЖИТЬ» в меню.", 
		"y": "Цель — больше всех очков (ПОЛИТ. → РЕЙТИНГ) или условие победы из настроек. Удачи!", "k": "done", "p": -1, "r": 0}, 
]

var gw: GameWorld
var hud: Hud
var main
var step: int = 0
var root: Control
var card: PanelContainer
var title: Label
var chap: Label
var text: Label
var why: Label
var next_btn: Button
var why_row: HBoxContainer
var ring: Panel
var _t: float = 0.0
var _hl_t: float = 0.0
var _step_t: float = 0.0
var _target: Control = null
var active: bool = false


func setup(world: GameWorld, h: Hud) -> void :
	gw = world
	hud = h
	main = h.main_node if h != null else null
	layer = 15
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.make_theme()
	add_child(root)
	ring = Panel.new()
	var rs: = StyleBoxFlat.new()
	rs.draw_center = false
	rs.border_color = UiKit.GOLD
	rs.set_border_width_all(3)
	rs.set_corner_radius_all(6)
	rs.shadow_color = Color(1.0, 0.75, 0.2, 0.45)
	rs.shadow_size = 6
	ring.add_theme_stylebox_override("panel", rs)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	root.add_child(ring)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.sb("wb_window", 10, 8))
	card.set_anchors_preset(Control.PRESET_TOP_WIDE)
	card.offset_top = 112 + _safe_top()
	card.offset_left = 10
	card.offset_right = -10
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(card)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	card.add_child(vb)
	var hr: = HBoxContainer.new()
	vb.add_child(hr)
	var ic: = TextureRect.new()
	ic.texture = UiKit.tex("icon_tutorial")
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	hr.add_child(ic)
	title = UiKit.lbl("", 13, UiKit.TITLE, 3, 3)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(title)
	chap = UiKit.lbl("", 10, UiKit.GOLD, 2, 2)
	chap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(chap)

	text = UiKit.lbl("", 11, UiKit.TEXT, 1, 2)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(text)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)
	why_row = hb
	why = UiKit.lbl("", 10, UiKit.MUTED, 1, 2)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	why.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(why)
	next_btn = UiKit.big("ДАЛЕЕ", "green", "", 32.0, 11)
	next_btn.custom_minimum_size = Vector2(96, 32)
	next_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	next_btn.pressed.connect(_on_next)
	hb.add_child(next_btn)
	visible = false


func start() -> void :
	step = 0
	active = true
	visible = true
	_show()


func stop() -> void :
	active = false
	visible = false
	if hud != null:
		hud.win_reserve = 0.0
	_target = null
	if ring != null:
		ring.visible = false



func current() -> Array:
	return [step, String((STEPS[step] as Dictionary)["t"])] if active else [-1, ""]


func _show() -> void :
	var s: Dictionary = STEPS[step]
	title.text = "%d/%d  %s" % [step + 1, STEPS.size(), String(s["t"])]
	var ch: String = String(s.get("ch", ""))
	chap.text = "" if String(s["t"]).begins_with(ch) else ch
	text.text = String(s["w"])
	why.text = String(s["y"])
	_step_t = 0.0
	_target = null
	_hl_t = 0.0
	_update_next()
	var pg: int = int(s.get("p", -1))
	if pg >= 0 and hud != null and pg < hud.tabs.size() and (pg <= 1 or _has_capital()):
		hud.select_page(pg)
	print("[Tutorial] step %d/%d %s" % [step + 1, STEPS.size(), String(s["t"])])


func _update_next() -> void :
	var k: String = String((STEPS[step] as Dictionary)["k"])
	var manual: bool = k == "next" or k == "done" or bool((STEPS[step] as Dictionary).get("opt", false))
	next_btn.visible = manual or _step_t >= SKIP_AFTER
	next_btn.text = "ГОТОВО" if k == "done" else ("ДАЛЕЕ" if manual else "ПРОПУСТИТЬ ШАГ")


func _on_next() -> void :
	_advance()


func _advance() -> void :
	if String((STEPS[step] as Dictionary)["k"]) == "done":
		stop()
		return
	_close_step_win(String((STEPS[step] as Dictionary)["k"]))
	step += 1
	if step >= STEPS.size():
		stop()
		return
	_show()




func _close_step_win(k: String) -> void :
	if not k.begins_with("win:") or hud == null:
		return
	var kind: String = k.substr(4)
	if hud.panel != null and is_instance_valid(hud.panel) and hud.panel_kind == kind:
		hud.close_panel()


func _has_capital() -> bool:
	return gw != null and gw.player != null and gw.player.capital_id >= 0


func _process(delta: float) -> void :
	if not active or gw == null or hud == null:
		return
	_dock()
	if main != null and bool(main.get("in_menu")):
		ring.visible = false
		return
	_step_t += delta
	_hl_t -= delta
	if _hl_t <= 0.0:
		_hl_t = 0.25
		_target = _find_target()
		if not next_btn.visible:
			_update_next()
	_place_ring()
	_t += delta
	if _t < 0.25:
		return
	_t = 0.0
	var s: Dictionary = STEPS[step]
	if _check(String(s["k"])):
		var rw: int = int(s.get("r", 0))
		var p: Country = gw.player
		if rw > 0 and p != null:
			p.money += rw
			if gw.econ != null and gw.econ.has_method("stat_add"):
				gw.econ.stat_add(p, "income", "tutorial", rw)
			hud.show_toast("Обучение: готово, +%d" % rw)
		else:
			hud.show_toast("Обучение: готово")
		UiKit.snd("ui_build")
		_advance()




func _check(k: String) -> bool:
	var p: Country = gw.player
	if k.begins_with("win:"):
		return _win_is(k.substr(4))
	match k:
		"speed":
			return main != null and int(main.get("_speed_i")) > 0 and not bool(main.get("_paused"))
		"mapmode":
			return (hud.panel_kind == "map_modes" and hud.panel != null and is_instance_valid(hud.panel)) or gw.map_mode != 0
		"capital":
			return p != null and p.capital_id >= 0
	if p == null or p.capital_id < 0 or gw.mil == null:
		return false
	match k:
		"farm":
			return gw.mil.has_kind(p.id, Facility.Kind.FARM)
		"civ":
			return gw.mil.has_kind(p.id, Facility.Kind.CIV_FACTORY)
		"power":


			var np: int = _count(p, [Facility.Kind.POWER_PLANT, Facility.Kind.SOLAR_FARM])
			var cons: Variant = gw.mil.get("constructing")
			if cons is Dictionary:
				for f: Facility in gw.mil.facilities:
					if f.country_id == p.id and (f.kind == Facility.Kind.POWER_PLANT or f.kind == Facility.Kind.SOLAR_FARM) and (cons as Dictionary).has(f.id) and not gw.mil.alive(f):
						np += 1
			return np >= 2
		"mine":
			for f: Facility in gw.mil.facilities:
				if f.country_id == p.id and f.kind == Facility.Kind.MINE and gw.mil.alive(f) and not f.deposit.is_empty():
					return true
			return false
		"barracks":
			return gw.mil.has_kind(p.id, Facility.Kind.BARRACKS)
		"build":
			if hud.panel_kind == "builds" and hud.panel != null and is_instance_valid(hud.panel):
				return true
			for f: Facility in _barracks(p):
				if f.army_build != "":
					return true
			return false
		"move":
			if gw.get("ops") == null:
				return false
			for f: Facility in _barracks(p):
				if not gw.ops.of(f).is_empty():
					return true
			return false
		"garrison":
			if gw.army != null:
				for u: Unit in gw.army.units:
					if u.country_id == p.id and u.alive() and u.post != null:
						return true

			if main != null and int(main.get("mode")) == int(main.Mode.GARRISON):
				return _count(p, [Facility.Kind.TRENCH_H, Facility.Kind.TRENCH_V, Facility.Kind.DUGOUT]) > 0
			return false
		"stance":
			for f: Facility in _barracks(p):
				if f.stance > 0:
					return true
			return false
		"upgrade":
			for f: Facility in gw.mil.facilities:
				if f.country_id == p.id and (f.level >= 2 or f.upg_t > 0.0):
					return true
			return false
		"ad":
			for f: Facility in gw.mil.facilities:
				if f.country_id == p.id and f.kind >= Facility.Kind.AD_MFG and f.kind <= Facility.Kind.AD_EW:
					return true
			return false
		"group":
			return not p.army_groups.is_empty()
		"front":
			for g: Dictionary in p.army_groups:
				if not FrontPlan.front_of(g).is_empty():
					return true
			return false
	return false


func _count(p: Country, kinds: Array) -> int:
	var n: int = 0
	for f: Facility in gw.mil.facilities:
		if f.country_id == p.id and f.kind in kinds and gw.mil.alive(f):
			n += 1
	return n


func _barracks(p: Country) -> Array:
	var out: Array = []
	for f: Facility in gw.mil.facilities:
		if f.country_id == p.id and f.kind == Facility.Kind.BARRACKS and gw.mil.alive(f):
			out.append(f)
	return out






func _find_target() -> Control:
	var s: Dictionary = STEPS[step]
	if hud.confirm_panel != null and hud.confirm_panel.is_visible_in_tree():
		var ok: Control = _find_text(hud.confirm_panel, ["✓"])
		if ok != null:
			return ok
	if hud.panel != null and is_instance_valid(hud.panel):
		return null
	if (s.get("keys", []) as Array).has("speed") and main != null:

		var sp: Variant = main.get("_spick")
		if sp != null and is_instance_valid(sp) and bool(sp.get("is_open")):
			for e: Array in sp.get("chips"):
				if is_equal_approx(float(main.SPEEDS[int(e[1])]), 2.0) and is_instance_valid(e[0]):
					return e[0] as Control
	if bool(s.get("inbox", false)):
		var ln: Variant = hud.get("lane")
		var pill: Variant = (ln as Object).get("_inbox_btn") if ln is Object and is_instance_valid(ln) else null
		if pill is Control and is_instance_valid(pill) and (pill as Control).is_visible_in_tree():
			return pill as Control
	var btns: Array = s.get("btn", [])
	if not btns.is_empty():
		for pre: String in btns:
			for holder: Variant in [hud.ops_panel, hud.armies_bar, hud.plan_panel, hud.get("ui24_sheet")]:
				if holder is Control and is_instance_valid(holder) and (holder as Control).is_visible_in_tree():
					var c: Control = _find_text(holder as Control, [pre])
					if c != null:
						return c
	for nm: String in s.get("keys", []):
		var c2: Control = _key_target(nm)
		if c2 != null:
			return c2
	return null


func _key_target(nm: String) -> Control:

	var lbl_txt: String = String((Hud.KEY_INFO.get(nm, [""]) as Array)[0])
	var pg: int = int(hud.get("_page"))
	if pg >= 0 and pg < hud.pages.size() and lbl_txt != "":
		for cell: Node in (hud.pages[pg] as Node).get_children():
			if cell.get_child_count() >= 2 and cell.get_child(1) is Label and (cell.get_child(1) as Label).text == lbl_txt and cell.get_child(0) is Control:
				return cell.get_child(0) as Control
	if not hud.keys.has(nm):
		return null
	var b: Control = hud.keys[nm] as Control
	if b == null or not is_instance_valid(b):
		return null
	if b.is_visible_in_tree():
		return b
	for i in mini(hud.pages.size(), hud.tabs.size()):
		if (hud.pages[i] as Node).is_ancestor_of(b):
			return hud.tabs[i]
	return null




func _find_text(n: Node, prefixes: Array) -> Control:
	for ch: Node in n.get_children():
		if ch is Control and not (ch as Control).visible:
			continue
		var t: String = ""
		if ch is Button:
			t = (ch as Button).text
		elif ch is Label:
			t = (ch as Label).text
		if t != "":
			for pre: String in prefixes:
				if t.begins_with(pre):
					if ch is Label and ch.get_parent() is VBoxContainer and ch.get_index() > 0 and ch.get_parent().get_child(0) is Button:
						return ch.get_parent().get_child(0) as Control
					var up: Node = ch.get_parent()
					for _i: int in 4:
						if up == null:
							break
						if up is Button:
							return up as Control
						up = up.get_parent()
					return ch as Control
		var r: Control = _find_text(ch, prefixes)
		if r != null:
			return r
	return null


func _place_ring() -> void :
	var t: Control = _target
	if t == null or not is_instance_valid(t) or not t.is_visible_in_tree():
		ring.visible = false
		return
	var r: Rect2 = t.get_global_rect().grow(3.0)
	ring.position = r.position
	ring.size = r.size
	ring.visible = true
	ring.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 160.0)





func _dock() -> void :
	var win_open: bool = hud.panel != null and is_instance_valid(hud.panel)
	var docked: bool = win_open or (hud.ops_panel != null and hud.ops_panel.visible)



	why.visible = not docked
	why_row.visible = not docked or next_btn.visible
	text.visible = true
	if docked and win_open and not (hud.ui24_open_now() and hud.ui24_sheet == hud.panel) and hud.holder != null:
		var pw: Control = hud.panel as Control
		var hmin: float = pw.get_combined_minimum_size().y
		if pw.has_meta("scroll"):
			hmin = hmin - (pw.get_meta("scroll") as Control).custom_minimum_size.y + 120.0
		var free: float = hud.holder.position.y - 4.0 - (hud._win_top() + hmin + 4.0)
		text.visible = card.get_combined_minimum_size().y <= free
	var right: float = 10.0
	if not docked:
		for e: Array in hud.cmd_btns:
			var b: Control = e[0]
			if b != null and b.visible:
				right = maxf(right, b.size.x + 10.0)
	var y: float = 112.0 + _safe_top()
	var ln: Control = hud.get("lane") as Control
	if not docked and ln != null and is_instance_valid(ln):
		y = maxf(y, roundf(ln.position.y + 50.0))
		if ln.has_method("rects"):
			for lr: Rect2 in ln.call("rects"):
				if lr.position.y < y and lr.position.x < hud.root.size.x - right:
					y = maxf(y, ceilf(lr.end.y + 2.0))
	if docked and hud.holder != null:
		y = hud.holder.position.y - card.size.y - 4.0
	if absf(card.offset_top - y) > 0.5 or absf(card.offset_right + right) > 0.5:
		card.offset_top = y
		card.offset_bottom = y
		card.offset_right = - right
		card.reset_size()
	hud.win_reserve = card.size.y + 6.0 if docked else 0.0


func _safe_top() -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if win.x <= 0.0 or safe.size.y <= 0:
		return 0.0
	return clampf(float(safe.position.y) * 360.0 / win.x, 0.0, 90.0)




func _win_is(kind: String) -> bool:
	if hud.panel != null and is_instance_valid(hud.panel) and hud.panel_kind == kind:
		return true
	if kind == "command":
		var cs: Variant = hud.get("cmd_sheet")
		return cs is Object and is_instance_valid(cs) and bool((cs as Object).call("is_open"))
	var sh: Variant = hud.get("ui24_sheet")
	if sh is Control and is_instance_valid(sh) and (sh as Control).visible:
		var c: Control = sh as Control
		if String(c.get_meta("kind", "")) == kind:
			return true
		var scr: Script = c.get_script() as Script
		if scr != null and kind == "diplomacy" and scr.resource_path.get_file().begins_with("dip"):
			return true
	return false
