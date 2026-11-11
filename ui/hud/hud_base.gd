extends CanvasLayer


signal action(name: String)

var main_node: Node
var gw: GameWorld
var root: Control
var top_name: Label
var top_flag: TextureRect
var top_badge: Control
var status_watch: RefCounted = null
var score_lbl: Label
var race_lbl: Label
var _race_t: float = 0.0
var clock_lbl: Label
var res_panel: PanelContainer
var res_labels: Dictionary = {}
var _res_prev: Dictionary = {}
var news_panel: PanelContainer
var news_label: Label
var hint_panel: PanelContainer
var hint: Label
var toast_panel: PanelContainer
var toast_label: Label
var toast_until: float = 0.0
var war_banner: Label
var war_until: float = 0.0
var labels_root: Control
var top_col: VBoxContainer
var map_chip: Button
var city_labels: Dictionary = {}

var holder: VBoxContainer
var bottom_panel: PanelContainer
var tab_row: HBoxContainer
var pages: Array = []
var tabs: Array[Button] = []
var keys: Dictionary = {}
var key_labels: Dictionary = {}
var speed_badge: Label
var tip_box: VBoxContainer
var tip_title: Label
var tip_sub: Label
var _tip_until: float = 0.0
var _page: int = 0

var sel_card: PanelContainer
var sel_icon: TextureRect
var sel_name: Label
var _sel_key: String = ""

var ops_panel: PanelContainer
var ops_icon: TextureRect
var ops_title: Label
var ops_sub: Label
var ops_info: Label
var ops_detail: Label
var ops_bars: Array = []
var ops_row: HBoxContainer
var ops_count: Label
var ops_launch: Button
var ops_close: Button
var fac_row: HFlowContainer
var _fac_sig: String = ""
var _ops_key: String = ""
var _info_key: String = ""

var dialog: PanelContainer
var dlg_settings: WorldSettings
var panel: PanelContainer
var panel_kind: String = ""

var _trade_status_txt: String = ""
var _trade_status_ok: bool = true
var _trade_status_ms: int = 0
var plan_panel: PanelContainer
var plan_list: VBoxContainer
var plan_head: Label
var plan_goal: Label
var plan_icon: TextureRect
var plan_go: Button
var plan_open: bool = false
var _plan_war_open: bool = false
var _plan_was_war: bool = false
var perf_lbl: Label
var _prompt_under_win: bool = false
var dip_hint_treaty: String = ""
var prompt_go_btn: Button
var _perf_t: float = 0.0
var plan_state: int = 1
var plan_scroll: ScrollContainer
var _plan_drag: int = 0
var _plan_moved: bool = false
var _plan_drag_from: Vector2 = Vector2.ZERO
var _plan_drag_org: Vector2 = Vector2.ZERO
static var keys_collapsed: bool = false
var _fold_pad: Control = null
static var plan_closed: bool = false
var armies_open: bool = false
var arm_all_open: bool = false
var armies_bar: PanelContainer
var armies_row: HFlowContainer
var _arm_t: float = 0.0
var _arm_sig: String = ""
var _plan_t: float = 0.0
var _plan_sig: String = ""
var _plan_key: String = ""
var _econ_sig: String = ""
var _econ_t: float = 0.0
var _econ_refs: Dictionary = {}
var _econ_dirty: bool = false
var _econ_rebuild_t: float = 0.0
var _cc_dirty: bool = false
var _cc_rebuild_t: float = 0.0
var _win_refresh: bool = false
var confirm_panel: PanelContainer
var confirm_lbl: Label
var confirm_ok: Button
var _dip_dirty: bool = false
var _dip_rebuild_t: float = 0.0
var _ruin: Array = [0, 0]
var cmd_btns: Array = []
var _cmd_t: float = 0.0
var _cam_ok: bool = false
var prompt_panel: PanelContainer
var prompt_lbl: Label
var prompt_icon: TextureRect
var prompt_data: Dictionary = {}
var _prompt_until: float = 0.0
var _dip_scroll_to: int = -1
var ult: Dictionary = {}
var _dip_timers: Array = []
var _shrink_t: float = 0.0
var war_arm: int = -1
var war_arm_until: int = 0
var _dip_live_t: float = 0.0
var dip_open: int = -1
var dip_chip: Button
var _dip_t: float = 0.0
var _dip_sig: String = ""
var _dip_obj: Object = null
var busy: Control
var _t: float = 0.0
var _res_t: float = 0.0
var _req_seen: int = 0
var _inv_sig: String = ""
var ore_btn: Button
var ore_badge: Label
var ore_panel: PanelContainer
var ore_list: VBoxContainer
var ore_scroll: ScrollContainer
var _ore_t: float = 0.0
var _ore_sig: String = ""
static var ores_open: bool = false
var advisor: PanelContainer
var advisor_lbl: Label
var _adv_t: float = 12.0
var _adv_last: String = ""
var _adv_until: float = 0.0
var tip_warn: Label
var tip_yield: Label
const EconRates = preload("res://game/econ_rates.gd")
var tip_pc: PanelContainer
var tip_cost: HFlowContainer
var _tip_shown: float = 0.0
var win_reserve: float = 0.0
var _tap_btn: BaseButton = null
var _tap_from: Vector2 = Vector2.ZERO
var _tap_moved: bool = false

static var news_on: bool = true
var news_queue: Array = []
var news_until: float = 0.0




const PAGE_DEFS: Array = [



	["tabi_world", [["zoom_out", "icon_minus", false], ["zoom_in", "icon_plus", false], ["center", "icon_center", false], ["borders", "icon_border", true], ["map_modes", "icon_map_political", false], ["own_icons", "icon_map_mine", true], ["ores", "icon_map_ores", false]]], 
	["tabi_city", [["capital", "icon_capital", true], ["town", "icon_city", true], ["farm", "icon_farm", true], ["civ", "icon_civ_factory", true], ["power", "icon_power", true], ["solar_farm", "icon_solar", true], ["npp", "icon_npp", true], ["mine", "icon_mine", true], ["sawmill", "icon_sawmill", true], ["oil_rig", "icon_oil_rig", true], ["refinery", "icon_refinery", true], ["rail_st", "icon_rail_station", true], ["rail_line", "u335_rail_line", true]]],
	["tabi_military", [["launch", "icon_launch", true], ["route", "icon_route", true], ["recon", "icon_recon_drone", true], ["factory", "icon_dronefactory", true], ["droneport", "icon_droneport", true], ["missile", "icon_target", true], ["tel", "icon_tel", true], ["mfactory", "icon_missile_factory", true], ["airfield", "icon_airfield_b", true]]], 
	["icon_ad_sam", [["ad_mfg", "icon_ad_mfg", true], ["ad_spaag", "icon_ad_spaag", true], ["ad_sam", "icon_ad_sam", true], ["ad_patriot", "icon_ad_patriot", true], ["ad_int", "icon_int_drone", true], ["ad_radar", "icon_ad_radar", true], ["ad_ew", "icon_ad_ew", true], ["ad_rules", "u335_ad_rules", false]]], 
	["icon_tank", [["barracks", "icon_barracks", true], ["armies", "icon_armies", true], ["command", "icon_op_operation", false], ["doctrine", "icon_doctrine", false], ["hold", "icon_infantry", false], ["defend", "icon_defend", true], ["trench", "icon_trench", true], ["teeth", "icon_teeth", true], ["dugout", "icon_dugout", true], ["battle_cam", "icon_battle_cam", false]]], 
	["icon_relations", [["diplomacy", "icon_relations", false], ["trade", "icon_trade", false], ["economy", "icon_stats", false], ["ultimatum", "icon_ultimatum", false], ["scores", "icon_trophy", false]]], 
	["icon_ship", [["port", "icon_port", true], ["navbase", "icon_navbase", true], ["fleet", "icon_fleet", false], ["ship_cr", "icon_cr_launch", true], ["coastal_asm", "icon_ad_sam", true]]], 
]
const PAGE_TITLES: Array = ["Карта и время", "Города, производство, недра", "Удары: дроны, ракеты, авиация", "Противовоздушная оборона", "Наземная армия", "Политика, торговля, экономика", "Флот и море"]
const PAGE_SUBS: Array = ["Масштаб, режимы карты, значки, залежи", "Столица, заводы, энергия, рудники, нефть", "Дроны, разведка, ОТРК, аэродром", "ЗСУ, ЗРК, перехватчики, РЛС, РЭБ", "Казармы, штаб, окопы, оборона", "Отношения, договоры, рынок, экономика", "Порт, морбаза, корабли, КР с кораблей, береговые ПКР"]
const COLS: int = 5
const TAB_SHORT: Array = ["КАРТА", "ГОРОДА", "УДАР", "ПВО", "АРМИЯ", "ПОЛИТ.", "ФЛОТ"]


const BUILD_KIND_OF: Dictionary = {
	"factory": Facility.Kind.DRONE_FACTORY, "droneport": Facility.Kind.DRONE_PORT, "tel": Facility.Kind.TEL, 
	"mfactory": Facility.Kind.MISSILE_FACTORY, "refinery": Facility.Kind.REFINERY, "power": Facility.Kind.POWER_PLANT, 
	"airfield": Facility.Kind.AIRFIELD, "farm": Facility.Kind.FARM, "civ": Facility.Kind.CIV_FACTORY, "mine": Facility.Kind.MINE, 
	"barracks": Facility.Kind.BARRACKS, "ad_mfg": Facility.Kind.AD_MFG, "ad_spaag": Facility.Kind.AD_SPAAG, 
	"ad_sam": Facility.Kind.AD_SAM, "ad_patriot": Facility.Kind.AD_PATRIOT, "ad_int": Facility.Kind.AD_INT, 
	"ad_radar": Facility.Kind.AD_RADAR, "ad_ew": Facility.Kind.AD_EW, "trench": Facility.Kind.TRENCH_H, 
	"teeth": Facility.Kind.TEETH_H, "dugout": Facility.Kind.DUGOUT, "sawmill": Facility.Kind.SAWMILL, 
	"oil_rig": Facility.Kind.OIL_RIG, "port": Facility.Kind.PORT, "solar_farm": Facility.Kind.SOLAR_FARM, 
	"navbase": Facility.Kind.NAVAL_BASE, "coastal_asm": Facility.Kind.COASTAL_ASM, 
	"npp": Facility.Kind.NUCLEAR_PLANT, "umine": Facility.Kind.URANIUM_MINE, 
}

const KEY_INFO: Dictionary = {
	"pause": ["ПАУЗА", "Пауза", "Остановить или продолжить время"], 
	"speed": ["СКОРОСТЬ", "Скорость времени", "Тап — выбор скорости: x½, x1, x2, x5, x10, x20"], 
	"recon": ["РАЗВЕДКА", "Разведдрон · 150 + металл 1", "Нужна пусковая рампа дронопорта. Летит к точке, кружит 25 с, раскрывает постройки. Могут сбить"], 
	"battle_cam": ["СМОТРЕТЬ", "Смотреть бой", "Камера летит к самому жаркому бою и показывает попадания"], 
	"economy": ["ЭКОНОМИКА", "Экономика страны", "Цепочки, склад, доходы и расходы; узкое место и ИСПРАВИТЬ"], 
	"navbase": ["МОРБАЗА", "Морская база", "Верфь кораблей, ремонт и ракеты у причала, десант. Свой берег у глубокой воды"], 
	"fleet": ["ФЛОТ", "Флот", "Корабли и флоты: приказы, патруль, конвои, удары ПКР и КР"], 
	"ship_cr": ["КР УДАР", "Удар КР с кораблей", "Все корабли с УВП: тапы по целям, ещё тап = +1, ПУСК. Удар по стране без войны начнёт войну"], 
	"command": ["ШТАБ", "Командный центр", "Все армии, режимы авто-атаки и обороны, ракеты, дроны, угрозы"], 
	"operation": ["ДВИЖЕНИЕ", "Движение армии", "Стрелка от казармы к цели — армия идёт и воюет сама"], 
	"order_0": ["АРТУДАР", "Артудар", "Залп по площади. Цель должна быть видна"], 
	"order_1": ["ДЫМ", "Дымовая завеса", "20 с: прицельный огонь и FPV не видят войска"], 
	"order_2": ["ГОСПИТАЛЬ", "Полевой госпиталь", "20 с: свои в круге лечатся, казармы пополняют быстрее"], 
	"zoom_out": ["ОТДАЛИТЬ", "Отдалить карту", "Щипок двумя пальцами или двойной тап и вести вверх"], 
	"zoom_in": ["ПРИБЛИЗ.", "Приблизить карту", "Щипок двумя пальцами или двойной тап и вести вниз"], 
	"center": ["СТОЛИЦА", "К столице", "Камера к вашей столице"], 
	"borders": ["ГРАНИЦЫ", "Заливка стран", "Показать или скрыть цвет территорий"], 
	"map_modes": ["РЕЖИМЫ", "Режимы карты", "Обычная, политика, моя земля, руды, логистика, военная, ПВО"], 
	"own_icons": ["ЗНАЧКИ", "Значки построек", "Ваши постройки на карте отмечены значками"], 
	"scores": ["РЕЙТИНГ", "Рейтинг стран", "Очки экономики и войны"], 
	"menu": ["МЕНЮ", "Меню", "Пауза, настройки, выход"], 
	"inventory": ["СКЛАД", "Склад страны", "Все ресурсы: сколько есть, прирост, нехватка, цены"], 
	"open_stats": ["СТАТИСТ.", "Статистика", "Что приносит деньги, расходы, добыча в минуту"], 
	"capital": ["СТОЛИЦА", "Основать столицу", "Тап по свободной земле: вырастет город и ТЭЦ"], 
	"town": ["ГОРОД", "Новый город", "Свободная земля рядом с вашей страной"], 
	"rail_st": ["ВОКЗАЛ", "Вокзал", "Станция на своей земле: поезда, грузы, эшелоны войск"], 
	"rail_line": ["Ж/Д ПУТЬ", "Ж/Д путь", "Ведите от своего вокзала к точке: путь по своей земле, мосты дороже"], 
	"trade": ["ТОРГОВЛЯ", "Торговля", "Грузовики возят излишки между странами"], 
	"launch": ["ПУСК БПЛА", "Пуск дронов", "Тап по цели на карте, затем ПУСК"], 
	"route": ["МАРШРУТ", "Маршрут дронов", "Точки в обход ПВО: тап по карте"], 
	"follow": ["В ПОЛЁТЕ", "Следить за полётом", "Камера за вашими дронами и ракетами"], 
	"missile": ["УДАР", "Ракетный удар", "ОТРК бьёт по точке на карте"], 
	"attack": ["АТАКА", "Наступление", "Тап по вражескому городу — армия идёт на штурм"], 
	"defend": ["АВТООКОПЫ", "Авто-окопы", "Пехота сама занимает свободные окопы и встречает врага (это не режим армии «ОБОРОНА»)"], 
	"hold": ["СТОЯТЬ", "Приказ стоять", "Вся армия останавливается"], 
	"doctrine": ["ДОКТРИНА", "Доктрина армии", "FPV, штурм или осада, оборона"], 
	"army_next": ["К АРМИИ", "К войскам", "Камера по вашим отрядам по очереди"], 
	"garrison": ["ЗАНЯТЬ", "Занять укрепления", "Тапайте окопы и блиндажи — выбранная армия займёт их"], 
	"armies": ["АРМИИ", "Мои армии", "Полоса армий над панелью: выбор армии, приказы, авто-режим для всех"], 
	"ad_rules": ["ЦЕЛИ ПВО", "Цели ПВО", "Что сбивает каждый вид ПВО — для всей страны: пресеты и тонкая настройка"], 
	"diplomacy": ["ДИПЛОМАТ.", "Дипломатия", "Война, мир, перемирие, союзы и альянсы"], 
	"ultimatum": ["УЛЬТИМАТ.", "Ультиматум", "Потребовать деньги, ресурс или землю — иначе война или эмбарго"], 
	"factory": ["БПЛА-ЗАВ.", "", ""], "droneport": ["ДРОНОПОРТ", "", ""], "tel": ["ОТРК", "", ""], 
	"mfactory": ["РАК.ЗАВОД", "", ""], "refinery": ["НПЗ", "", ""], "power": ["ТЭЦ", "", ""], 
	"airfield": ["АЭРОДРОМ", "", ""], "farm": ["КОЛХОЗ", "", ""], "civ": ["ЗАВОД", "", ""], "mine": ["РУДНИК", "", ""], 
	"barracks": ["КАЗАРМЫ", "", ""], "ad_mfg": ["ОГН.ГРУП.", "", ""], "ad_spaag": ["ЗСУ", "", ""], 
	"ad_sam": ["ЗРК", "", ""], "ad_patriot": ["ПРО", "", ""], "ad_int": ["ПЕРЕХВАТ", "", ""], 
	"ad_radar": ["РЛС", "", ""], "ad_ew": ["РЭБ", "", ""], "trench": ["ОКОП", "", ""], "teeth": ["ЗУБЫ", "", ""], 
	"dugout": ["БЛИНДАЖ", "", ""], "sawmill": ["ЛЕСОПИЛКА", "", ""], "oil_rig": ["НЕФТЬ", "", ""], "port": ["ПОРТ", "", ""], "solar_farm": ["СОЛНЦЕ", "", ""], "coastal_asm": ["БЕРЕГ.ПКР", "", ""], 
	"npp": ["АЭС", "", ""], "umine": ["УРАН.ШАХТ", "", ""], 
	"nuclear_silo": ["ШАХТА МБР", "Шахта МБР", "Стратегический комплекс шахтного базирования. Постройка: 3500 $ и 10 урана."], 
	"thermo_battery": ["СОЛНЦЕПЁК", "ТОС-1А «Солнцепёк»", "Бетонная площадка с двумя огнемётными системами ТОС-1А. Постройка: 650 $ и 50 металла."], 
	"satellite": ["СПУТНИК", "Спутниковый снимок", "Платно: снимок 220 м находит постройки и войска на 14 с"], 
	"ores": ["СВОБ.РУДЫ", "Свободные залежи", "Залежи на вашей земле, которые никто не добывает"], 
}

const MT_SHORT: Array = ["БАЛЛИСТ.", "КРЫЛАТЫЕ", "ВОЗД-ВОЗД", "ДЛЯ ЗРК", "ГИПЕРЗВУК", "КАБ"]
const MT_PURPOSE: Array = [
	"для ОТРК: удар по точке на земле", 
	"для бомбардировщиков и подвеса истребителей", 
	"для воздушного боя истребителей", 
	"боекомплект ЗРК: перезарядка ПВО", 
	"подвес истребителя: почти не сбивается ПВО", 
	"управляемые авиабомбы для штурмовика (4 на вылет)", 
]
const RES_KEYS: Array = [["money", "res_money"], ["power", "res_power"], ["drones", "res_drone"], ["missiles", "res_missile"], ["food", "res_food"]]

const STORE: Array = [
	["titanium", "Титан", "res_titanium"], ["metal", "Металл", "res_metal"], ["wood", "Дерево", "res_wood"], 
	["oil", "Нефть", "res_oil"], ["precious", "Драгметаллы", "res_precious"], ["fuel", "Топливо", "res_fuel"], 
	["food", "Еда", "res_food"], ["goods", "Товары", "res_goods"], ["uranium", "Уран", "res_uranium"], 
]
const RAW: Array = ["titanium", "metal", "wood", "oil", "precious", "uranium"]



const EconHubScript = preload("res://ui/ui24/econ_hub.gd")
const NotifLaneScript = preload("res://ui/ui24/notif_lane.gd")
const CalmScript = preload("res://ui/ui24/notif_calm.gd")
const TapGuardScript = preload("res://ui/ui24/tap_guard.gd")
const HoldTip = preload("res://ui/ui24/hold_tip.gd")
const HelpTipsScript = preload("res://ui/ui24/help_tips.gd")
const InboxScript = preload("res://ui/ui24/inbox_sheet.gd")
const WidthGuard = preload("res://ui/ui24/width_guard.gd")
var tap_guard: Node = null
var help_tips: Control = null
var inbox: Control = null
const BuildPanel = preload("res://ui/ui24/build_panel.gd")
const RailBuild = preload("res://ui/ui24/rail_build.gd")
const ArmyBudget = preload("res://ui/ui24/army_budget.gd")
const AD_PRESET_SHORT: Dictionary = {"all": "ВСЁ", "eco": "ЭКОНОМНО", "missiles": "РАКЕТЫ", "": "СВОИ"}
const EconKit = preload("res://ui/ui24/econ_kit.gd")
var econ_hub: Control = null
var trade_sheet: Control = null
var lane: Control = null
var _lane_t: float = 0.0
var _lane_win: bool = false
var _left_grid: GridContainer
var _keys_stack: Control
var _pend_total: Dictionary = {}


var _cc_sig: String = ""
var _cc_t: float = 0.0
var _cc_cd: Array = []




const RAIL_RANK: Dictionary = {"command": 0, "battle_cam": 1, "ore": 2, "order_0": 3, "jet_menu": 4, "order_1": 6, "order_2": 7, "repair_all": 8}
var _cam_hold_ms: int = 0


var rail_cand: Dictionary = {}
var rail_fold: Dictionary = {}
var rail_more_on: bool = false
var rail_more_ms: int = 0
var _ruin_hold_ms: int = 0




var _jet_has: bool = false



var jet_fly: PanelContainer = null
var _jet_fly_ms: int = 0
var _jet_stock_lbl: Label = null



var rail_dx: float = 0.0
var rail_hidden: bool = false
var _rail_slide: float = 0.0
var rail_tab: Button = null
const RAIL_SLIDE_PX: float = 112.0





var army_dock = null
var army_ux = null
var cmd_sheet = null
var army_pennants = null
var armies_bar_old: PanelContainer = null
var _arm_player: Object = null


var _dip_warm: Resource = null




var navy_yard = null
var navy_dock = null
var _navy_icons_done: bool = false


var _qa_stack_bottom: float = 0.0


var _speed_dot: ColorRect = null


var _spect: bool = false
var _blk: Array = []






var ui24_sheet: Control = null


var _tab_quiet: bool = false
var _plan_list_t: float = 12.0





var _net_on: bool = false



var _ally_t: float = 0.0
var _ally_asked: Dictionary = {}
var ally_sheet: Control = null
const AllySheetS = preload("res://ui/ui24/ally_sheet.gd")






const ArmyGroups303 = preload("res://game/army_groups.gd")
var ops_comp: HFlowContainer = null
var ops_foot: HBoxContainer = null
var _comp_sig: String = ""
var _foot_l: Label = null






var _hold_btn: Button = null





var _sd_sc: ScrollContainer = null
var _sd_start: Vector2 = Vector2.ZERO
var _sd_origin: Vector2 = Vector2.ZERO
var _sd_moved: bool = false
var _sd_eat_release: bool = false







const DIP_SHEET_PATH: String = "res://ui/ui24/dip_sheet.gd"




const MY_STATE_PATH: String = "res://ui/ui24/my_state.gd"




var ad_rules_sheet: Control = null



var _inv_cells: Dictionary = {}


const STAT_NAMES: Dictionary = {
	"cities": "Города", "farm": "Колхозы", "civ": "Заводы товаров", "fuel_sale": "Продажа топлива", "trade": "Торговля", 
	"export": "Экспорт (порт)", "export_ships": "Экспорт (порт)", "mine": "Рудники", "sawmill": "Лесопилки", "oil": "Нефтевышки", 
	"oil_rig": "Нефтевышки", "refinery": "НПЗ", "port": "Порт", "build": "Стройка", "army": "Набор войск", "drones": "Дроны", 
	"missiles": "Ракеты", "aircraft": "Авиация", "upkeep": "Содержание армии", "ad_fire": "ПВО: выстрелы", 
}


var _chat_lane_t: Dictionary = {}
