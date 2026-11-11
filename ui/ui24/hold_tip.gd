extends CanvasLayer













const HOLD_MS: int = 450
const STAY_S: float = 1.6


const G: Dictionary = {

	"move": ["ДВИЖЕНИЕ", "Тап или линия пальцем по карте — выбранные армии пойдут туда"], 
	"mode": ["РЕЖИМ", "Как армия воюет сама: ЖДУТ, ДЕРЖАТ район или НАСТУПАЮТ"], 
	"defend": ["ДЕРЖАТЬ", "Держать точку: армии стоят на месте и бьют врага в радиусе"], 
	"retreat": ["ОТХОД", "Армии отходят к своим казармам и пополняются"], 
	"front": ["ФРОНТ", "Меню группы: линия фронта вдоль границы, план атаки стрелкой, оборона точки, авто-фронт"], 
	"trench": ["ОКОПЫ", "В ОКОПЫ — пехота займёт ближайшие свои окопы; ИЗ ОКОПОВ — выйдет и вернётся к приказу"], 
	"army_trench_in": ["В ОКОПЫ", "Пехота армии займёт ближайшие свободные окопы и блиндажи"], 
	"army_trench_out": ["ИЗ ОКОПОВ", "Бойцы выйдут из окопов и вернутся к приказу армии"], 
	"army_group": ["ГРУППА", "Открыть группу этой армии в доке АРМИЯ (без группы — добавить в группу)"], 
	"army_card": ["АРМИЯ", "Карточка армии этих казарм: состав, сила, что делает, приказы"], 
	"to_group": ["В ГРУППУ", "Собрать отмеченные армии в группу (или добавить в существующую)"], 
	"cancel_sel": ["ОТМЕНА", "Снять отметки с армий"], 
	"select": ["ОТМЕТИТЬ", "Отметить армии галочками, чтобы дать им общий приказ"], 
	"all": ["ВСЕ", "Отметить все армии списка"], 
	"refill_row": ["ПОПОЛНЕНИЕ", "Казарма восполняет потери этой армии новыми бойцами"], 

	"auto_orders": ["АВТО-ПРИКАЗЫ", "Штаб сам даёт артудар, дым и полевой госпиталь, когда они готовы"], 
	"auto_strike": ["АВТОУДАРЫ", "Ракеты летят по разведанным целям; одна каждого типа остаётся в запасе"], 
	"auto_kab": ["АВТО-КАБ", "Штурмовики сами сбрасывают КАБ по врагу у линии фронта"], 
	"auto_drones": ["АВТО-ДРОНЫ", "Дроны со склада сами летят по видимым целям"], 
	"smart": ["УМНЫЕ БПЛА", "Дроны облетают зенитки по памяти о потерях; от ЗРК не уклоняются"], 
	"refill": ["ПОПОЛНЕНИЕ", "Казармы восполняют потери всех армий (стоит еду и деньги)"], 

	"route": ["МАРШРУТ", "Провести путь дрона пальцем через точки (обход ПВО)"], 
	"plan_standing": ["АВТОПУСК", "Каждый новый дрон сам летит по отмеченным целям, пока вы не снимете их"], 
	"smart_toggle": ["УМНЫЕ БПЛА", "Дроны облетают зенитки по памяти о потерях; от ЗРК не уклоняются"], 
	"plan_reset": ["СБРОС", "Убрать все отмеченные цели этого оружия"], 
	"fire": ["УДАР", "Запустить всё отмеченное оружие по своим целям одновременно"], 

	"garrison": ["ЗАНЯТЬ ОКОПЫ", "Тапайте свои окопы и блиндажи — армия этих казарм займёт их"], 
	"occupy": ["ЗАНЯТЬ", "Солдаты займут это укрепление"], 
	"stance_cycle": ["РЕЖИМ", "Переключить, как армия воюет сама: ЖДУТ, ДЕРЖАТ район или НАСТУПАЮТ"], 
	"auto_refill": ["ПОПОЛНЕНИЕ", "Казарма сама восполняет потери армии"], 
	"fac_restore": ["ВОССТАНОВИТЬ", "Отстроить разрушенный объект за указанную цену"], 
	"fac_demolish": ["РАЗРУШИТЬ", "Снести свой объект; цифра — сколько денег вернётся"], 
	"fac_upgrade": ["УЛУЧШИТЬ", "Следующий уровень объекта: больше выпуск"], 
	"operation": ["ДВИЖЕНИЕ", "Тап или линия пальцем по карте — армия идёт туда и воюет сама"], 
	"op_cancel": ["ОТМЕНИТЬ ПРИКАЗ", "Армия прекращает текущий приказ и остаётся на месте"], 
	"op_retreat": ["ОТХОД", "Армия отходит к своим казармам"], 
	"leave": ["ОСТАВИТЬ", "Солдаты выходят из укрепления"], 
	"build_pick": ["СБОРКА АРМИИ", "Кого обучают казармы: пехота, ПТУР, танки…; пополнение и набор"], 
	"ad_rearm": ["ЗАРЯДИТЬ", "Пополнить ракеты ПВО со склада ракет"], 
	"recon": ["РАЗВЕДДРОН", "Разведдрон летит к точке и раскрывает туман войны вокруг"], 
	"recon_recall": ["ОТОЗВАТЬ", "Вернуть разведдрон домой"], 
	"intel_strike": ["РАКЕТНЫЙ УДАР", "Ударить ракетой по этой разведанной цели"], 
	"missile": ["УДАР", "ОТРК бьёт баллистической ракетой по точке на карте"], 
	"air_patrol": ["ПАТРУЛЬ", "Самолёт кружит над районом и сбивает вражеские дроны"], 
	"air_land": ["ПОСАДКА", "Вернуть самолёт на аэродром"], 
	"air_cr": ["ПУСК КР", "Крылатая ракета с самолёта: выберите цель на карте"], 
	"air_kab": ["УДАР КАБ", "Штурмовик: до 4 целей, по 1 КАБ на цель, сброс на подлёте"], 
	"air_cas": ["ПОДДЕРЖКА", "Штурмовик отработает район НАРами и пушкой"], 
	"jet_kab": ["КАБ", "Удар КАБ ближайшим готовым штурмовиком: до 4 целей"], 
	"buy_attack": ["ШТУРМОВИК", "Купить штурмовик: 4 КАБ, НАРы, пушка, ракеты «воздух-воздух»"], 
	"jet_cas": ["ПОДДЕРЖКА", "Авиаподдержка: штурмовик отработает район НАРами и пушкой"], 
	"jet_menu": ["АВИА", "Штурмовик: удар КАБ или поддержка НАРами и пушкой"], 
	"air_hyp": ["ГИПЕРЗВУК", "Гиперзвуковая ракета: её почти не сбивает ПВО"], 
	"air_upgrade": ["УЛУЧШИТЬ", "Самолёт дальше летает и дольше живёт"], 
	"pylon_1": ["2 КРЫЛАТЫЕ", "Подвесить истребителю две крылатые ракеты"], 
	"pylon_2": ["ГИПЕРЗВУК", "Подвесить истребителю гиперзвуковую ракету"], 
	"plan_kind_0": ["ДРОНЫ", "Обычные ударные дроны: дёшево, медленно, сбивают чаще"], 
	"plan_kind_1": ["РЕАКТИВНЫЕ БПЛА", "Быстрые реактивные дроны: дороже, сбивают реже"], 
	"dtype_0": ["ДРОН", "Завод делает обычные ударные дроны"], 
	"dtype_1": ["РЕАКТИВНЫЙ БПЛА", "Завод делает быстрые реактивные дроны"], 
	"trade": ["ТОРГОВЛЯ", "Купить и продать ресурсы другим странам"], 
	"port_export": ["ЭКСПОРТ", "Порт продаёт излишки за границу"], 
	"mod_ramp": ["РАМПА", "Модуль дронопорта: быстрый пуск с ускорителем"], 
	"mod_runway": ["ВПП", "Модуль дронопорта: взлёт с разбега (нужна реактивным)"], 
	"mod_store": ["СКЛАД", "Модуль дронопорта: +4 места для дронов"], 
	"mod_solar": ["+СОЛНЦЕ", "Солнечная панель: резервное питание, если сеть отключат"], 
	"mod_crane": ["КРАН", "Портовый кран: порт грузит быстрее"], 
	"mtype": ["ТИП РАКЕТ", "Какие ракеты делает завод; цифра — сколько их на складе"], 

	"order_0": ["АРТУДАР", "Залп артиллерии по площади; цель должна быть видна"], 
	"order_1": ["ДЫМ", "Дымовая завеса на 20 с: прицельный огонь и FPV не видят войска"], 
	"order_2": ["ПОЛЕВОЙ ГОСПИТАЛЬ", "20 с: свои в круге лечатся, казармы пополняют быстрее"], 
	"repair_all": ["РЕМОНТ ВСЕГО", "Отстроить все свои разрушенные объекты, на сколько хватит денег"], 
	"battle_cam": ["СМОТРЕТЬ БОЙ", "Камера летит к самому жаркому бою"], 
	"command": ["ШТАБ", "Все армии, автоматика ударов и обороны, приказы командования"], 
	"ores": ["СВОБОДНЫЕ ЗАЛЕЖИ", "Залежи на вашей земле, которые никто не добывает"], 
	"bar_0": ["НАБОР", "Казармы снова набирают бойцов"], 
	"bar_3": ["НАБОР: СТОП", "Казармы перестают набирать бойцов (экономит еду и деньги)"], 

	"n_move": ["ДВИЖЕНИЕ", "Тап по морю или линия пальцем — корабли идут туда"], 
	"n_patrol": ["ПАТРУЛЬ", "Корабли ходят по району и атакуют врага"], 
	"n_convoy": ["КОНВОИ", "Топить суда врага в районе или охранять свои"], 
	"n_more": ["ЕЩЁ", "На базу, стоп, залп ПКР, удар КР"], 
	"n_asm": ["ПКР ЗАЛП", "Противокорабельные ракеты по вражескому кораблю"], 
	"n_cm": ["КР УДАР", "Крылатые ракеты по цели на суше"], 
	"n_return": ["НА БАЗУ", "Вернуться на базу: ремонт и боезапас"], 
	"n_stop": ["СТОП", "Корабли ложатся в дрейф на месте"], 
	"n_to_fleet": ["ВО ФЛОТ", "Собрать отмеченные корабли во флот"], 
	"n_cancel": ["ОТМЕНА", "Снять отметки с кораблей"], 
	"n_svc_asm": ["ПКР", "Зарядить противокорабельные ракеты у базы"], 
	"n_svc_cm": ["КРЫЛАТЫЕ", "Зарядить крылатые ракеты у базы"], 
	"n_svc_repair": ["ПОЧИНИТЬ", "Починить корабль у базы"], 

	"w_drone": ["УДАРНЫЕ БПЛА", "Дешёвые дроны с дронопортов; цифра — сколько готово к пуску"], 
	"w_jet": ["РЕАКТИВНЫЕ БПЛА", "Быстрые дроны, взлетают с ВПП дронопорта; сбивают реже"], 
	"w_tel": ["ОТРК", "Баллистические ракеты с пусковых установок"], 
	"w_ship": ["КР С МОРЯ", "Крылатые ракеты с кораблей"], 
	"w_art": ["АРТ. УДАР С МОРЯ", "Залпы артбатарей кораблей по берегу: дёшево, но с рассеиванием; корабль подходит к берегу (до 1 км), цели — не дальше 400 м от воды"], 
	"w_bomber": ["КР С САМОЛЁТОВ", "Крылатые ракеты с бомбардировщиков"], 
	"w_hyper": ["ГИПЕРЗВУК", "Ракеты с истребителей; их почти не сбивает ПВО"], 
	"w_thermo": ["СОЛНЦЕПЁК", "Тяжёлая огнемётная система ТОС-1А; залп из 24 термобарических ракет выжигает всё в зоне поражения"], 
	"w_nuke": ["МБР «САРМАТ»", "Стратегический комплекс; термоядерный удар разделяющейся боеголовкой глобальной дальности"], 

	"fix": ["ИСПРАВИТЬ", "Показать, что построить или купить, чтобы убрать нехватку"], 
	"cmd_i": ["ПОЯСНЕНИЯ", "Под каждым переключателем — строка о том, что он делает"], 
	"dock_select": ["ОТМЕТИТЬ НЕСКОЛЬКО", "Галочками выбрать армии и дать им общий приказ"], 
	"dock_back": ["НАЗАД", "Выйти из армий к постройкам"], 
}


const SHEETS: Dictionary = {
	"army_dock": ["move", "mode", "defend", "retreat", "trench", "front", "to_group"], 
	"cmd_sheet": ["auto_orders", "auto_strike", "auto_kab", "auto_drones", "smart", "refill"], 
	"navy_dock": ["n_move", "n_patrol", "n_convoy", "n_asm", "n_cm", "n_return"], 
	"econ_hub": ["fix"], 
}


const SHORT: Dictionary = {
	"move": "армии идут к точке на карте", "mode": "как армия воюет сама", "defend": "держат свои позиции", 
	"retreat": "отход к казармам", "trench": "в окопы и из окопов", "front": "линия фронта и план атаки", "to_group": "собрать отмеченные в группу", 
	"auto_orders": "сам даёт артудар, дым, госпиталь", "auto_strike": "ракеты по разведанным целям", 
	"auto_kab": "КАБ по врагу у линии фронта", "auto_drones": "дроны со склада по целям", 
	"smart": "дроны облетают зенитки", "refill": "казармы восполняют потери", 
	"n_move": "корабли идут к точке", "n_patrol": "охрана района", "n_convoy": "топить или охранять суда", 
	"n_asm": "ракеты по кораблю врага", "n_cm": "ракеты по цели на суше", "n_return": "ремонт и боезапас", 
	"fix": "что построить или купить", 
}

var _panel: PanelContainer
var _title: Label
var _text: Label
var _hide_at: int = -1
var _down: bool = false
var shown: int = 0
var last: String = ""
var _at: Vector2 = Vector2.ZERO
var _br: Rect2 = Rect2()




static func tip(b: Control, text: Variant) -> void :
	if b != null and is_instance_valid(b):
		b.set_meta("hold_tip", text)


static func key(b: Control, k: String, state: String = "") -> void :
	if not G.has(k):
		return
	var e: Array = G[k]
	tip(b, ("%s: %s — %s" % [String(e[0]), state, String(e[1])]) if state != "" else ("%s — %s" % [String(e[0]), String(e[1])]))


static func label(k: String, fallback: String = "") -> String:
	return String((G[k] as Array)[0]) if G.has(k) else fallback


static func line(k: String) -> String:
	return String((G[k] as Array)[1]) if G.has(k) else ""



static func text_of(b: Object) -> String:
	if b == null or not is_instance_valid(b) or not (b as Object).has_meta("hold_tip"):
		return ""
	var v: Variant = (b as Object).get_meta("hold_tip")
	if v is Callable:
		v = (v as Callable).call() if (v as Callable).is_valid() else ""
	return String(v)



static func act_line(act: String) -> String:
	var k: String = act
	if not G.has(k) and act.begins_with("mtype_"):
		k = "mtype"
	if not G.has(k):
		return ""
	return "%s — %s" % [String((G[k] as Array)[0]), String((G[k] as Array)[1])]



static func lines_for(sheet: String) -> String:
	var out: PackedStringArray = []
	for k: String in SHEETS.get(sheet, []):
		if G.has(k):
			out.append("%s — %s" % [String((G[k] as Array)[0]), Loc.t(String(SHORT.get(k, String((G[k] as Array)[1]).get_slice(";", 0))))])
	return "\n".join(out)




func _init() -> void :
	layer = 110
	name = "HoldTip"


func _build() -> void :
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 9, 6))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_title = UiKit.lbl("", 11, UiKit.GOLD, 2, 3)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_title)
	_text = UiKit.lbl("", 10, UiKit.TEXT, 1, 2)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text)


func is_showing() -> bool:
	return _panel != null and _panel.visible




func show_at(at: Vector2, t: String, br: Rect2) -> void :
	if _panel == null:
		_build()
	var i: int = t.find(" — ")
	_title.text = t.left(i) if i > 0 else t
	_text.text = t.substr(i + 3) if i > 0 else ""
	_text.visible = _text.text != ""
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = minf(270.0, vp.x - 24.0)
	_title.custom_minimum_size.x = w - 18.0
	_text.custom_minimum_size.x = w - 18.0
	_panel.custom_minimum_size = Vector2(w, 0)
	_panel.visible = true
	_at = at
	_br = br
	_place()
	_panel.modulate.a = 1.0 if _panel.size.y < vp.y * 0.5 else 0.0
	_down = true
	_hide_at = -1
	shown += 1
	last = t
	UiKit.snd("ui_select")





func _place() -> void :
	var at: Vector2 = _at
	var br: Rect2 = _br
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = _panel.custom_minimum_size.x
	_panel.reset_size()
	var h: float = _panel.get_combined_minimum_size().y
	_panel.size = Vector2(w, h)
	var top: float = minf(at.y, br.position.y) - 14.0 - h
	var y: float = top
	if top < 34.0:
		y = maxf(at.y, br.end.y) + 34.0
	y = clampf(y, 8.0, vp.y - h - 8.0)
	var x: float = clampf(at.x - w * 0.5, 8.0, vp.x - w - 8.0)
	_panel.position = Vector2(x, y).round()



func release() -> void :
	if _down:
		_down = false
		_hide_at = Time.get_ticks_msec() + roundi(STAY_S * 1000.0)


func hide_now() -> void :
	_down = false
	_hide_at = -1
	if _panel != null:
		_panel.visible = false


func _process(_d: float) -> void :
	if _panel != null and _panel.visible and absf(_panel.size.y - _panel.get_combined_minimum_size().y) > 0.5:
		_place()
	if _panel != null and _panel.visible and _panel.modulate.a == 0.0 and _hide_at < 0:
		_panel.modulate.a = 1.0
	if _panel == null or not _panel.visible or _down or _hide_at < 0:
		return
	var left: float = float(_hide_at - Time.get_ticks_msec()) / 1000.0
	if left <= 0.0:
		hide_now()
	elif left < 0.2:
		_panel.modulate.a = left / 0.2
