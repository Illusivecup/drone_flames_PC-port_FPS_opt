extends RefCounted


const TICK: float = 10.0
const FARM_FOOD: int = 4
const FARM_MONEY: int = 20
const CIV_GOODS: int = 3
const CIV_MONEY: int = 35
const MINE_TI: int = 2
const MINE_MONEY: int = 10

const MINE_RATE: Dictionary = {"metal": 4, "titanium": 2, "precious": 1}
const RIG_OIL: int = 3
const SAW_WOOD_MAX: int = 4
const SAW_R: int = 14
const SAW_MIN_TREES: int = 8
const REGROW_T: float = 480.0
const START_METAL: int = 50
const START_WOOD: int = 50

const PRICE: Dictionary = {"goods": 30, "food": 12, "titanium": 45, "metal": 16, "wood": 7, "oil": 10, "precious": 90, "fuel": 16, "uranium": 110}
const RES_NAMES: Dictionary = {"goods": "ТОВАРЫ", "food": "ЕДА", "titanium": "ТИТАН", "metal": "МЕТАЛЛ", "wood": "ДЕРЕВО", 
        "oil": "НЕФТЬ", "precious": "ДРАГМЕТАЛЛЫ", "fuel": "ТОПЛИВО", "uranium": "УРАН"}

const LOC_RES_LOW: Dictionary = {"goods": "товары", "food": "еда", "titanium": "титан", "metal": "металл", "wood": "дерево", 
        "oil": "нефть", "precious": "драгметаллы", "fuel": "топливо", "uranium": "уран"}

const RES_SHORT: Dictionary = {"goods": "ТОВАРЫ", "food": "ЕДА", "titanium": "ТИТАН", "metal": "МЕТАЛЛ", "wood": "ДЕРЕВО", 
        "oil": "НЕФТЬ", "precious": "ДРАГМЕТ", "fuel": "ТОПЛИВО", "uranium": "УРАН"}

const RES_ICONS: Dictionary = {"metal": "res_metal", "titanium": "res_titanium", "wood": "res_wood", "oil": "res_oil", 
        "precious": "res_precious", "food": "res_food", "goods": "res_goods", "fuel": "res_fuel", "uranium": "res_uranium"}

const RES_ICONS_BIG: Dictionary = {"metal": "icon_r_metal", "titanium": "icon_r_titanium", "wood": "icon_r_wood", "oil": "icon_r_oil", 
        "precious": "icon_r_precious", "food": "icon_farm", "goods": "icon_civ_factory", "fuel": "res_fuel", "uranium": "icon_r_uranium"}
const RAW: Array[String] = ["metal", "titanium", "wood", "oil", "precious", "uranium"]
const TRADE_RES: Array[String] = ["metal", "titanium", "wood", "oil", "precious", "food", "goods", "uranium"]

const TOP_BAR: Array[String] = ["metal", "titanium", "wood", "oil", "precious"]
const BASE_CAP: Dictionary = {"metal": 150, "titanium": 100, "wood": 150, "oil": 150, "precious": 40, "food": 120, "goods": 120, "fuel": 60, "uranium": 40}
const PORT_CAP: Dictionary = {"metal": 150, "titanium": 100, "wood": 150, "oil": 150, "precious": 30, "food": 80, "goods": 120, "fuel": 0, "uranium": 20}
const FOREIGN_SELL: float = 0.7
const FOREIGN_BUY: float = 1.6
const ORE_TYPES: Array = ["metal", "titanium", "precious"]



const RES_COST: Dictionary = {
        "drone": {"metal": 3}, 
        "jet_uav": {"metal": 4, "titanium": 2, "precious": 1}, 
        "missile_0": {"titanium": 4, "metal": 2}, 
        "missile_1": {"titanium": 2, "metal": 2}, 
        "missile_2": {"titanium": 1, "metal": 1}, 
        "missile_3": {"titanium": 2, "metal": 1}, 
        "missile_4": {"titanium": 5, "metal": 2, "precious": 2}, 
        "missile_5": {"metal": 2}, 
        "tank": {"metal": 6, "titanium": 3}, 
        "infantry": {"food": 4}, 
        "atgm": {"metal": 2, "titanium": 1, "food": 4}, 
        "artillery": {"metal": 8, "titanium": 1}, 
        "mortar": {"metal": 3, "food": 2}, 
        "mlrs": {"metal": 8, "titanium": 3}, 
        "recon_drone": {"metal": 2, "precious": 1}, 
        "recon": {"metal": 2, "precious": 1}, 
        "arty": {"metal": 8, "titanium": 1}, 
        "assault": {"food": 4, "metal": 1}, 
        "ifv": {"metal": 5, "titanium": 1}, 
        "aircraft_0": {"titanium": 60, "metal": 25, "precious": 3}, 
        "aircraft_1": {"titanium": 20, "metal": 10, "precious": 1}, 
        "aircraft_2": {"titanium": 10, "metal": 8}, 
        "aircraft_3": {"titanium": 30, "metal": 15, "precious": 1}, 
}
const BUILD_COST: Dictionary = {
        Facility.Kind.DRONE_FACTORY: {"metal": 15, "wood": 10}, Facility.Kind.AIRFIELD: {"metal": 25, "wood": 20}, 
        Facility.Kind.DRONE_PORT: {"metal": 6, "wood": 10}, Facility.Kind.DP_RAMP: {"metal": 4}, Facility.Kind.DP_RUNWAY: {"wood": 6}, 
        Facility.Kind.DP_STORE: {"wood": 8}, Facility.Kind.TEL: {"metal": 15, "titanium": 5}, 
        Facility.Kind.MISSILE_FACTORY: {"metal": 20, "titanium": 4}, Facility.Kind.REFINERY: {"metal": 20, "oil": 20}, 
        Facility.Kind.POWER_PLANT: {"metal": 15, "wood": 10}, Facility.Kind.SOLAR: {"metal": 4}, 
        Facility.Kind.FARM: {"wood": 10}, Facility.Kind.CIV_FACTORY: {"metal": 10, "wood": 8}, Facility.Kind.MINE: {"wood": 10}, 
        Facility.Kind.BARRACKS: {"metal": 5, "wood": 15}, Facility.Kind.AD_MFG: {"metal": 2}, Facility.Kind.AD_SPAAG: {"metal": 10}, 
        Facility.Kind.AD_SAM: {"metal": 15, "titanium": 5}, Facility.Kind.AD_PATRIOT: {"metal": 20, "titanium": 8, "precious": 2}, 
        Facility.Kind.AD_INT: {"metal": 8}, Facility.Kind.AD_RADAR: {"metal": 8, "precious": 1}, Facility.Kind.AD_EW: {"metal": 6, "precious": 1}, 
        Facility.Kind.DUGOUT: {"wood": 8}, Facility.Kind.OIL_RIG: {"metal": 8}, Facility.Kind.PORT: {"wood": 30}, 
        Facility.Kind.PORT_CRANE: {"metal": 15}, Facility.Kind.SOLAR_FARM: {"metal": 3}, 
        Facility.Kind.NAVAL_BASE: {"metal": 25, "wood": 20}, 
        Facility.Kind.COASTAL_ASM: {"metal": 12, "titanium": 3}, 
        Facility.Kind.URANIUM_MINE: {"metal": 30, "titanium": 10, "wood": 10}, 
        Facility.Kind.NUCLEAR_PLANT: {"metal": 60, "titanium": 20, "uranium": 12}, 
}
const DEP_AMOUNT: Dictionary = {"metal": 900, "titanium": 600, "oil": 900, "precious": 250, "uranium": 240}
const CAP_DEP: Dictionary = {"metal": 400, "oil": 300, "titanium": 200}
const DEP_SPRITE: Dictionary = {"metal": ["ore_metal", "ore_metal_small"], "titanium": ["ore_ti", "ore_ti_small"], 
        "oil": ["oil_seep", "oil_seep_small"], "precious": ["ore_gold", "ore_gold_small"], "uranium": ["ore_uranium", "ore_uranium_small"]}
const TRADE_DT: float = 16.0
const TRUCK_SPEED: float = 14.0
const TRUCK_LOAD: int = 10
const DEPOSIT_SPACING: int = 70
const NAV_K: int = 4
const STAT_SLOTS: int = 6

var gw: GameWorld
var deposits: Array = []
var trucks: Array = []
var trade: Dictionary = {}
var nav: AStarGrid2D
var _t: float = 0.0
var _trade_t: float = 0.0
var _truck_id: int = 1
var dust_t: float = 0.0
var ports: Ports
var prices: Dictionary = {}
var want: Dictionary = {}
var want_t: Dictionary = {}
var export_off: Dictionary = {}
var requests: Array = []
var rail_jobs: Array = []
var _site: Dictionary = {}


const LOC_SITE: Dictionary = {"paused": "ПАУЗА", "bridge_out": "МОСТ РАЗРУШЕН", "detour": "ОБЪЕЗД: −50%", "no_power": "НЕТ ПИТАНИЯ", 
        "no_deposit": "НЕТ МЕСТОРОЖДЕНИЯ", "depleted": "ИСЧЕРПАНО", "store_full": "СКЛАД ПОЛОН", "forest_cut": "ЛЕС ВЫРУБЛЕН"}
var _stumps: Array = []
var _stats: Dictionary = {}
var _demand: Dictionary = {}
var _warned: Dictionary = {}
var _fix_t: Dictionary = {}
var _ask_t: Dictionary = {}
var _req_id: int = 1
var _snd_t: float = 0.0


var scarce: Dictionary = {}
var scarce_zone: Dictionary = {}
var auto_sub: Dictionary = {}
var _scarce_n: int = 0


var u_seeded: bool = false
var u_fund: Dictionary = {}
signal request_added(req: Dictionary)
const Trade331S = preload("res://game/trade331.gd")
var trd = null
const Upkeep335S = preload("res://game/upkeep335.gd")
var upk = null








const ORE_COUNT_MUL: Array = [0.0, 0.45, 1.0, 1.7, 2.6]
const ORE_SMALL: Array = [33, 50, 33, 20, 10]
const ORE_AMOUNT_MUL: Array = [1.0, 0.75, 1.0, 1.25, 1.5]
const ORE_WEIGHT: Dictionary = {"metal": 0.36, "oil": 0.28, "titanium": 0.24, "precious": 0.12}




const SCARCE_PAD: int = 30



var blocked: Dictionary = {}


var nav_last_ok: bool = true
var nav_solid_ver: int = 0
var nav_solid_b: PackedByteArray = PackedByteArray()
const PATH_TTL: float = 45.0
const PATH_CACHE_MAX: int = 384
var _path_cache: Dictionary = {}
var _nav_ver: int = 0







var nav_soft: AStarGrid2D = null
var nav_dry: AStarGrid2D = null
## R-FORD: сетка с проходимыми клетками рек (форсирование) — море остаётся стеной.
var nav_ford: AStarGrid2D = null
var nav_last_soft: bool = false
var _soft_cache: Dictionary = {}
const SOFT_DRY: int = 4
const SOFT_R: Array[int] = [2, 6, 12]
const SOFT_CHUNK: int = 40
const SOFT_CACHE_MAX: int = 96
const SOFT_BUDGET: int = 400000
var _soft_left: int = 0
const SOFT_TRIES: int = 6
static var soft_stats: Dictionary = {}








var nav_last_pending: bool = false
var _leg_wet: bool = false
var _soft_jobs: Array = []
var _soft_gt: float = -1.0
var _soft_tick_left: int = 0
const SOFT_TICK: int = 4000
const SOFT_LONG: int = 6000
const SOFT_ASTAR: int = 400
const SOFT_RW: Array[int] = [2, 5, 8]
const SOFT_JOBS_MAX: int = 8
const SOFT_CUT: int = 40
var _ap_memo: Dictionary = {}
var _ap_gt: float = -1.0
var _ap_left: float = 0.0
const ROUTE_TICK: float = 2.0


const DRY_DEPTH: int = 5
const BODY_HALF: float = 2.0









const ROAD_PAD: int = 6
const OFFROAD_W: float = 4.0


var refined: int = 0




const RAIL_ETA_SPEED: float = 22.0
var _mkt_tag: bool = false


var last_deal: Dictionary = {}



var _reach: Dictionary = {}
var _reach_ui: Dictionary = {}








const SUB_RULES: Dictionary = {"titanium": {"metal": 3, "money": 25}, "metal": {"wood": 2, "money": 10}}
const SUB_ORDER: Array[String] = ["titanium", "metal", "precious", "oil", "wood", "food", "goods", "fuel"]
const SUB_MONEY_K: float = 2.0



const STAT_NAMES: Dictionary = {"cities": "Города", "farm": "Колхозы", "civ": "Заводы товаров", "mine": "Рудники", 
        "oil_rig": "Нефтевышки", "sawmill": "Лесопилки", "refinery": "НПЗ", "fuel_sale": "Продажа топлива", 
        "trade": "Торговля", "export": "Экспорт (порт)", "import": "Импорт (порт)", "surplus": "Излишки со склада", 
        "build": "Стройка", "tourism": "Туризм (безвиз)", "tribute": "Уступки по требованиям", "subst": "Замена ресурсов", "aid": "Помощь", "army": "Армия", "drones": "Дроны", "missiles": "Ракеты", "aircraft": "Авиация", "upkeep": "Содержание", "plan": "План развития", "ad_fire": "ПВО: выстрелы"}
const MODE_NAMES: Dictionary = {"rail": "поездом", "ship": "кораблём", "truck": "грузовиком"}




var draw_ver: int = 0


const DEP_USE: Dictionary = {
        "metal": "Металл — дроны, ракеты, техника и почти любая стройка.", 
        "titanium": "Титан — ракеты, танки, самолёты, ЗРК.", 
        "oil": "Нефть — НПЗ делает из неё топливо: оно продаётся и заправляет авиацию.", 
        "precious": "Драгметаллы — реактивные БПЛА, гиперзвук, ПРО, РЛС и РЭБ. Встречаются редко.", 
        "uranium": "Уран — топливо АЭС. Залежи редкие, шахта дорогая; излишки дорого продаются.", 
}




const MAX_LEVEL: int = 3
const LEVEL_MUL: Array = [1.0, 1.0, 1.6, 2.2]
const LEVEL_CAP: int = 40

const UPG_RES: Dictionary = {
        Facility.Kind.MINE: [{"wood": 20, "metal": 10}, {"wood": 30, "metal": 25, "titanium": 5}], 
        Facility.Kind.SAWMILL: [{"metal": 10}, {"metal": 20, "titanium": 3}], 
        Facility.Kind.OIL_RIG: [{"metal": 20}, {"metal": 35, "titanium": 5}], 
        Facility.Kind.REFINERY: [{"metal": 25, "oil": 15}, {"metal": 40, "titanium": 8, "precious": 2}], 
        Facility.Kind.FARM: [{"wood": 15}, {"wood": 25, "metal": 10}], 
        Facility.Kind.CIV_FACTORY: [{"metal": 15, "wood": 10}, {"metal": 25, "wood": 15, "precious": 1}], 
}

const UPG_EXTRA: Dictionary = {
        Facility.Kind.MINE: ["eco_ore_heap", "eco_shed"], Facility.Kind.SAWMILL: ["eco_logs", "eco_logs"], 
        Facility.Kind.OIL_RIG: ["eco_pumpjack_s", "eco_tank_s"], Facility.Kind.REFINERY: ["eco_tank_s", "eco_tank_s"], 
        Facility.Kind.FARM: ["eco_silo", "eco_silo"], Facility.Kind.CIV_FACTORY: ["eco_shed", "eco_tank_s"], 
}
var _extras: Dictionary = {}
var _cap_bonus: Dictionary = {}




const RES_ADVICE: Dictionary = {
        "metal": "рудник на залежи металла (красный значок) или покупка в торговле", 
        "titanium": "рудник на залежи титана (голубой значок) или покупка", 
        "wood": "лесопилка у леса", 
        "oil": "нефтевышка на нефтяной залежи (чёрный значок) или покупка нефти в торговле", 
        "precious": "рудник на редкой залежи драгметаллов (золотой значок), чаще — покупка или импорт через порт", 
        "uranium": "урановая шахта на редкой залежи (зелёный значок), покупка у соседей или импорт через порт", 
        "food": "колхоз", "goods": "завод товаров", "fuel": "НПЗ (нужна нефть)", 
        "money": "доход городов, колхозов, заводов и торговли", 
}




const STALL_FIX: Dictionary = {"titanium": "рудник титана или купите на рынке", "metal": "рудник металла или купите на рынке", 
        "wood": "лесопилка у леса или купите на рынке", "oil": "нефтевышка или купите нефть на рынке", 
        "precious": "купите на рынке или импорт через порт", "uranium": "урановая шахта или купите на рынке", "food": "колхоз или купите еду на рынке", 
        "fuel": "НПЗ (нужна нефть)", "goods": "завод товаров", "money": "доход: заводы товаров, колхозы, торговля"}









const DEEP_NAMES: Dictionary = {Facility.Kind.MINE: ["", "Рудник", "Шахта", "Карьер"], 
        Facility.Kind.OIL_RIG: ["", "Вышка", "Куст скважин", "Глубокое бурение"]}
const DEEP_ADD: Array = [0.0, 0.0, 0.55, 0.85]
const DEEP_T: Array = [0.0, 0.0, 60.0, 90.0]
const DEEP_ORE: Dictionary = {"titanium": "ti", "metal": "metal", "precious": "precious"}
const DEEP_LOW_TICKS: float = 30.0
var _deep_t: float = 0.0










const AB_DT: float = 6.0
const AB_FLOOR: int = 500
const AB_SHARE: float = 0.35
const AB_CD: float = 20.0
const AB_RES: Array[String] = ["metal", "titanium", "wood", "oil", "precious", "food", "goods", "uranium"]
const AI_MAX_PRICE: float = 1.9
const RES_GEN: Dictionary = {"metal": "металла", "titanium": "титана", "wood": "дерева", "oil": "нефти", 
        "precious": "драгметаллов", "food": "еды", "goods": "товаров", "fuel": "топлива", "uranium": "урана"}
var autobuy: Dictionary = {}
var autobuy_log: Array = []
var _ab_t: float = 0.0
var _ab_cd: Dictionary = {}
var _ab_status: Dictionary = {}
var _ab_msg_t: float = -999.0
var _px_hist: Dictionary = {}
var _px_t: float = 0.0
