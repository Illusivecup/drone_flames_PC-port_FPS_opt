extends RefCounted


const INCOME_DT: float = 10.0
const AdTripS = preload("res://game/ad_trip.gd")
const INCOME_CAPITAL: int = 80
const INCOME_TOWN: int = 30
const INCOME_VILLAGE: int = 10
const START_MONEY: int = 3000
const COST_TOWN: int = 500
const TOWN_COST_STEP: int = 250
const TOWN_COST_MAX: int = 2000
const COST_FACTORY: int = 600
const COST_AIRFIELD: int = 800
const COST_PORT: int = 400
const COST_RAMP: int = 150
const COST_DP_RUNWAY: int = 350
const COST_STORE: int = 200
const COST_TEL: int = 2000
const COST_DRONE: int = 100
const COST_MISSILE: int = 550
const RESTORE_SHARE: float = 0.5
const RESTORE_TIME: float = 20.0



const CRIT_RESTORE: Dictionary = {Facility.Kind.POWER_PLANT: 100.0, Facility.Kind.REFINERY: 75.0, Facility.Kind.OIL_RIG: 75.0, 
	Facility.Kind.PORT: 75.0, Facility.Kind.SOLAR_FARM: 45.0, Facility.Kind.NAVAL_BASE: 60.0, 
	Facility.Kind.NUCLEAR_PLANT: 240.0, Facility.Kind.URANIUM_MINE: 75.0}
const CRIT_METAL: Dictionary = {Facility.Kind.POWER_PLANT: 8, Facility.Kind.REFINERY: 6, Facility.Kind.OIL_RIG: 5, 
	Facility.Kind.PORT: 6, Facility.Kind.SOLAR_FARM: 2, Facility.Kind.NAVAL_BASE: 10, 
	Facility.Kind.NUCLEAR_PLANT: 30, Facility.Kind.URANIUM_MINE: 8}
const RUBBLE_ADD: float = 30.0
const RUBBLE_MAX: float = 90.0
const FIRE_BLOCK: float = 30.0
const PROD_TIME: float = 20.0


const COST_JET: int = 700
const JET_PROD_TIME: float = 34.0
const JET_CRUISE: float = 60.0
const JET_RANGE: float = 5600.0
const JET_CRUISE_H: float = 12.0
const STOCK: int = 4
const RANGE_PX: float = 3200.0
const MAX_WAYPOINTS: int = 5
const RUNWAY_REPAIR: float = 45.0
const MODULE_R: int = 30


const TAXI_SPEED: float = 6.0
const GROUND_SPEED: float = 12.0
const GROUND_TURN: float = PI * 0.5
const ROLL_ACC: float = 4.0
const LIFT_SPEED: float = 20.0
const CRUISE: float = 24.0
const CLIMB: float = 1.75
const CRUISE_H: float = 8.0
const AIR_TURN: float = PI * 0.25
const DIVE_DIST: float = 40.0
const DIVE_SPEED: float = 36.0
const DIVE_ACC: float = 9.0
const SLOW_DOWN: float = 10.0
const HOLD_PAUSE: float = 0.6
const RUNWAY_GAP: float = 3.5
const GROUND_ETA: float = 10.0

const RAMP_HOLD: float = 0.8
const RAMP_RELOAD: float = 6.0
const BOOST_TIME: float = 1.2
const BOOST_ACC: float = 35.0
const BOOST_CLIMB: float = 4.5
const TRAIL_STEP: float = 3.0


const MISSILE_RANGE: float = 6000.0
const MISSILE_MIN: float = 300.0
const TEL_RELOAD: float = 20.0
const TEL_SPEED: float = 10.0

enum {MT_BALLISTIC, MT_CRUISE, MT_AA, MT_SAM, MT_HYPER, MT_KAB}
const MT_NAMES: Array = ["БАЛЛИСТИЧЕСКИЕ", "КРЫЛАТЫЕ", "ВОЗДУХ-ВОЗДУХ", "ДЛЯ ПВО", "ГИПЕРЗВУКОВЫЕ", "КАБ"]
const MT_ICONS: Array = ["icon_m_ballistic", "icon_m_cruise", "icon_m_aa", "icon_m_sam", "icon_m_hyper", "icon_m_kab"]
const MT_READY: Array = [true, true, true, true, true, true]

const MT_COST: Array = [550, 300, 150, 250, 900, 120]
const MT_TIME: Array = [40.0, 30.0, 20.0, 25.0, 60.0, 15.0]
const MT_CAP: Array = [6, 30, 12, 12, 4, 16]
const ERECT_TIME: float = 3.0
const PUFF_STEP: float = 6.0
const PUFF_LIFE: float = 2.0
const BOOM_LOWER: float = 1.5


const AF_SIZE: Vector2i = Vector2i(30, 11)
const AF_RUNWAY: Rect2 = Rect2(0, 0, 120, 16)
const AF_ROLL_Y: float = 8.0
const AF_START_X: float = 12.0
const AF_END_X: float = 118.0
const AF_TAXI_Y: float = 18.0
const AF_SPOTS: Array = [Vector2(58, 25), Vector2(72, 25), Vector2(86, 25), Vector2(100, 25), Vector2(58, 38), Vector2(72, 38), Vector2(86, 38), Vector2(100, 38)]

const SIZES: Dictionary = {
	Facility.Kind.POLICE_STATION: Vector2i(6, 4),
	Facility.Kind.NUCLEAR_PLANT: Vector2i(18, 11), Facility.Kind.URANIUM_MINE: Vector2i(6, 6), 
	Facility.Kind.COASTAL_ASM: Vector2i(6, 2), 
	Facility.Kind.NAVAL_BASE: Vector2i(24, 12), 
	Facility.Kind.SAWMILL: Vector2i(6, 5), Facility.Kind.OIL_RIG: Vector2i(4, 4), Facility.Kind.PORT: Vector2i(8, 6), Facility.Kind.PORT_CRANE: Vector2i(4, 3), Facility.Kind.SOLAR_FARM: Vector2i(6, 6), 
	Facility.Kind.DRONE_FACTORY: Vector2i(8, 6), Facility.Kind.AIRFIELD: Vector2i(30, 11), 
	Facility.Kind.DRONE_PORT: Vector2i(6, 5), Facility.Kind.DP_RAMP: Vector2i(4, 2), 
	Facility.Kind.DP_RUNWAY: Vector2i(16, 3), Facility.Kind.DP_STORE: Vector2i(5, 4), Facility.Kind.TEL: Vector2i(6, 2), 
	Facility.Kind.MISSILE_FACTORY: Vector2i(8, 6), Facility.Kind.REFINERY: Vector2i(10, 8), 
	Facility.Kind.POWER_PLANT: Vector2i(9, 8), Facility.Kind.SOLAR: Vector2i(3, 3), 
	Facility.Kind.FARM: Vector2i(8, 6), Facility.Kind.CIV_FACTORY: Vector2i(7, 5), Facility.Kind.MINE: Vector2i(5, 5), 
	Facility.Kind.BARRACKS: Vector2i(6, 4), Facility.Kind.AD_MFG: Vector2i(3, 2), Facility.Kind.AD_SPAAG: Vector2i(5, 2), 
	Facility.Kind.AD_SAM: Vector2i(6, 2), Facility.Kind.AD_PATRIOT: Vector2i(5, 2), Facility.Kind.AD_INT: Vector2i(4, 2), 
	Facility.Kind.AD_RADAR: Vector2i(3, 3), Facility.Kind.AD_EW: Vector2i(3, 2), 
	Facility.Kind.TRENCH_H: Vector2i(8, 2), Facility.Kind.TRENCH_V: Vector2i(2, 8), 
	Facility.Kind.TEETH_H: Vector2i(6, 2), Facility.Kind.TEETH_V: Vector2i(2, 6), Facility.Kind.DUGOUT: Vector2i(4, 3), 
}
const COSTS: Dictionary = {
	Facility.Kind.POLICE_STATION: 700,
	Facility.Kind.NUCLEAR_PLANT: 9000, Facility.Kind.URANIUM_MINE: 3200, 
	Facility.Kind.NAVAL_BASE: 3000, Facility.Kind.COASTAL_ASM: 2200, 
	Facility.Kind.SAWMILL: 500, Facility.Kind.OIL_RIG: 900, Facility.Kind.PORT: 1500, Facility.Kind.PORT_CRANE: 600, Facility.Kind.SOLAR_FARM: 450, 
	Facility.Kind.DRONE_FACTORY: 600, Facility.Kind.AIRFIELD: 2000, Facility.Kind.DRONE_PORT: 400, 
	Facility.Kind.DP_RAMP: 150, Facility.Kind.DP_RUNWAY: 350, Facility.Kind.DP_STORE: 200, Facility.Kind.TEL: 2000, 
	Facility.Kind.MISSILE_FACTORY: 1200, Facility.Kind.REFINERY: 1500, Facility.Kind.POWER_PLANT: 1800, 
	Facility.Kind.SOLAR: 250, Facility.Kind.FARM: 600, Facility.Kind.CIV_FACTORY: 900, Facility.Kind.MINE: 800, 
	Facility.Kind.BARRACKS: 1000, Facility.Kind.AD_MFG: 250, Facility.Kind.AD_SPAAG: 900, Facility.Kind.AD_SAM: 2500, 
	Facility.Kind.AD_PATRIOT: 3000, Facility.Kind.AD_INT: 700, Facility.Kind.AD_RADAR: 700, Facility.Kind.AD_EW: 800, 
	Facility.Kind.TRENCH_H: 5, Facility.Kind.TRENCH_V: 5, Facility.Kind.TEETH_H: 10, Facility.Kind.TEETH_V: 10, Facility.Kind.DUGOUT: 350, 
}
const TITLES: Dictionary = {
	Facility.Kind.POLICE_STATION: "Полицейский участок",
	Facility.Kind.NUCLEAR_PLANT: "АЭС", Facility.Kind.URANIUM_MINE: "Урановая шахта", 
	Facility.Kind.NAVAL_BASE: "Морская база", Facility.Kind.COASTAL_ASM: "Береговой ПКР-комплекс", 
	Facility.Kind.SAWMILL: "Лесопилка", Facility.Kind.OIL_RIG: "Нефтевышка", Facility.Kind.PORT: "Морской порт", Facility.Kind.PORT_CRANE: "Портовый кран", Facility.Kind.SOLAR_FARM: "Солнечная станция", 
	Facility.Kind.DRONE_FACTORY: "Дронный завод", Facility.Kind.AIRFIELD: "Аэродром", Facility.Kind.DRONE_PORT: "Дронопорт", 
	Facility.Kind.DP_RAMP: "Пусковая рампа", Facility.Kind.DP_RUNWAY: "ВПП дронопорта", Facility.Kind.DP_STORE: "Склад дронов", Facility.Kind.TEL: "ОТРК «Гром»", 
	Facility.Kind.MISSILE_FACTORY: "Ракетный завод", Facility.Kind.REFINERY: "НПЗ", Facility.Kind.POWER_PLANT: "ТЭЦ", 
	Facility.Kind.SOLAR: "Солнечные панели", Facility.Kind.FARM: "Колхоз", Facility.Kind.CIV_FACTORY: "Завод товаров", 
	Facility.Kind.MINE: "Рудник", Facility.Kind.BARRACKS: "Казармы", Facility.Kind.AD_MFG: "Мобильная огневая группа", 
	Facility.Kind.AD_SPAAG: "ЗСУ «Шершень»", Facility.Kind.AD_SAM: "ЗРК «Купол»", Facility.Kind.AD_PATRIOT: "ЗРК «Щит»", 
	Facility.Kind.AD_INT: "Пусковая перехватчиков", Facility.Kind.AD_RADAR: "РЛС «Обзор»", Facility.Kind.AD_EW: "РЭБ «Туман»", 
	Facility.Kind.TRENCH_H: "Окоп", Facility.Kind.TRENCH_V: "Окоп", Facility.Kind.TEETH_H: "Зубы дракона", Facility.Kind.TEETH_V: "Зубы дракона", 
	Facility.Kind.DUGOUT: "Блиндаж", 
}

const PURPOSE: Dictionary = {
	Facility.Kind.POLICE_STATION: "ПАТРУЛЬ ДО ЧЕТЫРЁХ МАШИН, ЗАЩИТА ОТ ВРАЖЕСКОЙ АРМИИ",
	Facility.Kind.NUCLEAR_PLANT: "+40 ЭНЕРГИИ НА УРАНЕ — СЕТКИ И БЕТОН НЕ ЗАЩИЩАЮТ, НУЖНА ПВО", 
	Facility.Kind.URANIUM_MINE: "ДОБЫВАЕТ УРАН НА РЕДКОЙ ЗАЛЕЖИ: ТОПЛИВО АЭС, ДОРОГО ПРОДАЁТСЯ", 
	Facility.Kind.SAWMILL: "ДЕРЕВО: РУБИТ ЛЕС ВОКРУГ СЕБЯ", Facility.Kind.OIL_RIG: "ДОБЫВАЕТ НЕФТЬ ИЗ МЕСТОРОЖДЕНИЯ", 
	Facility.Kind.NAVAL_BASE: "ВЕРФЬ КОРАБЛЕЙ, РЕМОНТ, ДЕСАНТ С БАЗЫ", 
	Facility.Kind.COASTAL_ASM: "ПКР ПО КОРАБЛЯМ: РЛС 900 М, ПУСК 1100 М. ТАП - ПЕРЕЕЗД", 
	Facility.Kind.PORT: "ТОРГОВЛЯ МОРЕМ, ЭКСПОРТ ИЗЛИШКОВ", Facility.Kind.PORT_CRANE: "ПОРТУ: +1 КОРАБЛЬ, +10 ГРУЗА", Facility.Kind.SOLAR_FARM: "ДЕШЁВОЕ ПИТАНИЕ: +2 ЭНЕРГИИ, БЕЗ ТОПЛИВА", 
	Facility.Kind.DRONE_FACTORY: "ПРОИЗВОДИТ ДРОНЫ ДЛЯ ДРОНОПОРТОВ", 
	Facility.Kind.DRONE_PORT: "ПУСК ДРОНОВ. МОДУЛИ: РАМПЫ, ВПП, СКЛАДЫ", Facility.Kind.DP_RAMP: "ПУСК ДРОНОВ С УСКОРИТЕЛЕМ", 
	Facility.Kind.DP_RUNWAY: "ВЗЛЁТ ДРОНОВ С РАЗБЕГОМ", Facility.Kind.DP_STORE: "ХРАНЕНИЕ ДРОНОВ: +4 МЕСТА", 
	Facility.Kind.TEL: "РАКЕТНЫЙ УДАР. ТАП ПО ЗЕМЛЕ - ПЕРЕЕЗД", 
	Facility.Kind.AIRFIELD: "БАЗА АВИАЦИИ: ПОКУПКА САМОЛЁТОВ", Facility.Kind.MISSILE_FACTORY: "ДЕЛАЕТ РАКЕТЫ. ВЫБЕРИТЕ ТИП НИЖЕ", 
	Facility.Kind.REFINERY: "НЕФТЬ -> ТОПЛИВО, ИЗЛИШКИ ПРОДАЮТСЯ", Facility.Kind.POWER_PLANT: "ПИТАЕТ ГОРОДА И ЗАВОДЫ СТРАНЫ", 
	Facility.Kind.SOLAR: "РЕЗЕРВНОЕ ПИТАНИЕ ЗАВОДА/ДРОНОПОРТА", 
	Facility.Kind.FARM: "ЕДА ДЛЯ АРМИИ И ТОРГОВЛИ, ДОХОД", Facility.Kind.CIV_FACTORY: "ТОВАРЫ НА ПРОДАЖУ, ДОХОД", 
	Facility.Kind.MINE: "МЕТАЛЛ, ТИТАН, ДРАГМЕТАЛЛЫ; НА УРАНЕ — УРАНОВАЯ ШАХТА, 3200", Facility.Kind.BARRACKS: "АРМИЯ ДО 12 БОЙЦОВ: ДВИЖЕНИЕ, УКРЕПЛЕНИЯ, СБОРКА", 
	Facility.Kind.AD_MFG: "ПУЛЕМЁТ ПО ДРОНАМ. ТАП - ПЕРЕЕЗД", Facility.Kind.AD_SPAAG: "ПУШКИ ПО ДРОНАМ И КР. ТАП - ПЕРЕЕЗД", 
	Facility.Kind.AD_SAM: "ДАЛЬНЯЯ ПВО: САМОЛЁТЫ, КР. 700 М", Facility.Kind.AD_PATRIOT: "ПРОТИВОРАКЕТНАЯ ОБОРОНА. 450 М", 
	Facility.Kind.AD_INT: "ДРОНЫ-ПЕРЕХВАТЧИКИ. 650 М", Facility.Kind.AD_RADAR: "ВИДИТ ЦЕЛИ ДЛЯ ПВО: 950 М", 
	Facility.Kind.AD_EW: "ГЛУШИТ ДРОНЫ И FPV: 150 М", 
	Facility.Kind.TRENCH_H: "УКРЫТИЕ ПЕХОТЫ. ЗАНЯТЬ - В КАРТОЧКЕ", Facility.Kind.TRENCH_V: "УКРЫТИЕ ПЕХОТЫ. ЗАНЯТЬ - В КАРТОЧКЕ", 
	Facility.Kind.TEETH_H: "ЗАМЕДЛЯЮТ ТЕХНИКУ", Facility.Kind.TEETH_V: "ЗАМЕДЛЯЮТ ТЕХНИКУ", 
	Facility.Kind.DUGOUT: "УКРЫТИЕ НА 3 БОЙЦОВ: ЛЕЧИТ, ЗАЩИТА x3", 
}
const SPRITES: Dictionary = {
	Facility.Kind.POLICE_STATION: "barracks",
	Facility.Kind.NUCLEAR_PLANT: "npp_core", Facility.Kind.URANIUM_MINE: "umine", 
	Facility.Kind.NAVAL_BASE: "navbase", Facility.Kind.COASTAL_ASM: "coastal_asm", 
	Facility.Kind.SAWMILL: "sawmill", Facility.Kind.OIL_RIG: "oil_rig", Facility.Kind.PORT: "port", Facility.Kind.PORT_CRANE: "port_crane", Facility.Kind.SOLAR_FARM: "solar", 
	Facility.Kind.DRONE_FACTORY: "drone_factory", Facility.Kind.DRONE_PORT: "dp_base", Facility.Kind.DP_RAMP: "dp_ramp", 
	Facility.Kind.DP_RUNWAY: "dp_runway", Facility.Kind.DP_STORE: "dp_store", Facility.Kind.TEL: "tel2", 
	Facility.Kind.MISSILE_FACTORY: "missile_factory", Facility.Kind.REFINERY: "refinery", Facility.Kind.POWER_PLANT: "power_plant", 
	Facility.Kind.AIRFIELD: "airfield_runway", 
	Facility.Kind.SOLAR: "solar", Facility.Kind.FARM: "farm", Facility.Kind.CIV_FACTORY: "civ_factory", Facility.Kind.MINE: "mine", 
	Facility.Kind.BARRACKS: "barracks", Facility.Kind.AD_MFG: "ad_mfg", Facility.Kind.AD_SPAAG: "ad_spaag_hull", 
	Facility.Kind.AD_SAM: "ad_sam", Facility.Kind.AD_PATRIOT: "ad_patriot", Facility.Kind.AD_INT: "dp_ramp", 
	Facility.Kind.AD_RADAR: "ad_radar", Facility.Kind.AD_EW: "ad_ew", 
	Facility.Kind.TRENCH_H: "trench_h", Facility.Kind.TRENCH_V: "trench_v", Facility.Kind.TEETH_H: "dragon_teeth", Facility.Kind.TEETH_V: "dragon_teeth_v", 
	Facility.Kind.DUGOUT: "dugout", 
}

const PLANT_CAP: int = 6
const SOLAR_FARM_CAP: int = 2
const USE_CAPITAL: int = 2
const USE_TOWN: int = 1
const USE_VILLAGE: int = 1
const USE_FACILITY: int = 1
const POWER_DT: float = 0.5
const FUEL_DT: float = 2.0
const FUEL_CAP_PER_REFINERY: int = 60
const FUEL_RESERVE: int = 30
const FUEL_PRICE: int = 8
const BLACKOUT_FLICKER: float = 3.0
const REFINERY_BURN: float = 45.0

var gw: GameWorld
var facilities: Array[Facility] = []
var drones: Array[Drone] = []
var missiles: Array[Missile] = []
var _income_t: float = 0.0
var _next_drone_id: int = 1
var _next_missile_id: int = 1
var _warned: Dictionary = {}
var _power_t: float = 0.0
var _pending_plants: Array = []
var _pending_t: float = 0.0
var _plant_hit_msg: bool = false
var _lost_city: int = 0
var _lost_fac: int = 0
var _back_city: int = 0
var _foe_dark: PackedStringArray = PackedStringArray()



const SHOCK_FRAC: float = 0.25
const SHOCK_MIN: int = 6
const SHOCK_T: float = 90.0
var grid_prev: Dictionary = {}
var grid_shock: Dictionary = {}
var _ai_t: float = 0.0
var _plan_cache_key: String = ""
var _plan_cache: PackedVector2Array = PackedVector2Array()
var air: Air
var brain: DroneBrain
var fort_cells: Dictionary = {}
signal forts_changed
const MT_NEEDS_CARRIER: Array = [false, true, true, false, true, true]
var _fuel_t: float = 0.0
var _audio_t: float = 0.0

var trail_pts: PackedVector2Array = PackedVector2Array()
var trail_t: PackedFloat32Array = PackedFloat32Array()
var trail_flip: PackedByteArray = PackedByteArray()


var auto_strike: Dictionary = {}
var auto_drones: Dictionary = {}
var strike_next: Dictionary = {}
var drone_next: Dictionary = {}
var struck: Dictionary = {}
var ruin_hits: Dictionary = {}
var site_hit_t: Dictionary = {}
var constructing: Dictionary = {}
var _no_construct: bool = false
var auto_log: Array = []


const TARGET_CD: float = 90.0
const TARGET_FLY_MAX: float = 180.0
const TARGET_SALVO: float = 1.0


const NEW_WAR_T: float = 600.0
const NEW_WAR_GAP: float = 40.0
var _ply_strike: Dictionary = {}
var tgt_cd: Dictionary = {}
var tgt_redirect: int = 0
var tgt_refused: int = 0



const GENDER_NAMES: Dictionary = {
	"POWER_PLANT": 1, "SAWMILL": 1, "OIL_RIG": 1, "SOLAR_FARM": 1, "DP_RAMP": 1, "DP_RUNWAY": 1, "AD_MFG": 1, 
	"AD_SPAAG": 1, "AD_INT": 1, "AD_RADAR": 1, "AD_EW": 1, "RAIL_STATION": 1, "NAVAL_BASE": 1, "NUCLEAR_PLANT": 1, "URANIUM_MINE": 1, 
	"SOLAR": 3, "BARRACKS": 3, "TEETH_H": 3, "TEETH_V": 3, 
}
const PP_END: Array = ["", "а", "о", "ы"]


const RoadDetour = preload("res://game/road_detour.gd")


var _prod_acc: float = 0.0




const HYPER_T0: float = 3.0
const HYPER_V: float = 300.0


var _own_m: Dictionary = {}






const ROAM_MAX: float = 2500.0
const ROAM_STEP: int = 6
const ROAM_DT: float = 1.0
var _roam_t: float = 0.0
var _roam_anchor: Dictionary = {}
var _roam_wait: Dictionary = {}
var _roam_try: Dictionary = {}
var _roam_jobs: Dictionary = {}
var _roam_tick: int = 0




const DRIVE_LOOK: float = 14.0
const DRIVE_HYST: float = 20.0
var drive_dir: Dictionary = {}




const LINE_MAX: int = 120
const TEETH_HP: float = 60.0

const DIG_CELL_T: float = 1.5
const TEETH_CELL_T: float = 2.0
const DUGOUT_T: float = 10.0
const DIG_ENEMY_R: float = 140.0
var dig_cells: Dictionary = {}


const ICON_OF: Dictionary = {
	Facility.Kind.DRONE_FACTORY: "icon_dronefactory", Facility.Kind.AIRFIELD: "icon_airfield_b", 
	Facility.Kind.DRONE_PORT: "icon_droneport", Facility.Kind.DP_RAMP: "icon_ramp", Facility.Kind.DP_RUNWAY: "icon_dprunway", 
	Facility.Kind.DP_STORE: "icon_store", Facility.Kind.TEL: "icon_tel", Facility.Kind.MISSILE_FACTORY: "icon_missile_factory", 
	Facility.Kind.REFINERY: "icon_refinery", Facility.Kind.POWER_PLANT: "icon_power", Facility.Kind.SOLAR: "icon_solar", 
	Facility.Kind.FARM: "icon_farm", Facility.Kind.CIV_FACTORY: "icon_civ_factory", Facility.Kind.MINE: "icon_mine", 
	Facility.Kind.BARRACKS: "icon_barracks", Facility.Kind.AD_MFG: "icon_ad_mfg", Facility.Kind.AD_SPAAG: "icon_ad_spaag", 
	Facility.Kind.AD_SAM: "icon_ad_sam", Facility.Kind.AD_PATRIOT: "icon_ad_patriot", Facility.Kind.AD_INT: "icon_int_drone", 
	Facility.Kind.AD_RADAR: "icon_ad_radar", Facility.Kind.AD_EW: "icon_ad_ew", Facility.Kind.TRENCH_H: "icon_trench", 
	Facility.Kind.TRENCH_V: "icon_trench", Facility.Kind.TEETH_H: "icon_teeth", Facility.Kind.TEETH_V: "icon_teeth", 
	Facility.Kind.DUGOUT: "icon_dugout", Facility.Kind.SAWMILL: "icon_sawmill", Facility.Kind.OIL_RIG: "icon_oil_rig", 
	Facility.Kind.PORT: "icon_port", Facility.Kind.PORT_CRANE: "icon_port_crane", Facility.Kind.RAIL_STATION: "icon_rail_station", 
	Facility.Kind.SOLAR_FARM: "icon_solar", Facility.Kind.NAVAL_BASE: "icon_port", Facility.Kind.COASTAL_ASM: "icon_coastal_asm", 
	Facility.Kind.NUCLEAR_PLANT: "icon_npp", Facility.Kind.URANIUM_MINE: "icon_umine", 
}





const HALT_KINDS: Array = [Facility.Kind.DRONE_FACTORY, Facility.Kind.MISSILE_FACTORY, Facility.Kind.REFINERY, Facility.Kind.FARM, 
	Facility.Kind.CIV_FACTORY, Facility.Kind.MINE, Facility.Kind.SAWMILL, Facility.Kind.OIL_RIG, Facility.Kind.BARRACKS, Facility.Kind.URANIUM_MINE]









const STANDING_GAP: float = 1.5
const MULTI_N_MAX: int = 30
const STANDING_RESERVE_MAX: int = 10
var standing: Dictionary = {}
var _standing_t: float = 0.0
var multi_launched: int = 0






var last_multi: Dictionary = {}


const SPREAD_W: Dictionary = {"NUCLEAR_PLANT": 6.0, "URANIUM_MINE": 2.5, "POWER_PLANT": 5.0, "REFINERY": 3.5, "MISSILE_FACTORY": 3.5, "DRONE_FACTORY": 3.5, 
	"AIRFIELD": 3.0, "DRONE_PORT": 3.0, "BARRACKS": 3.0, "CIV_FACTORY": 2.0, "MINE": 2.0, "FARM": 2.0, "OIL_RIG": 2.0, "PORT": 2.0}




const STRIKE_SPOT_R: float = 40.0
const INTEL_FRESH: float = 75.0
var stale_drop: int = 0






const DEMOLISH_REFUND: float = 0.3
const NO_DEMOLISH: Array = [Facility.Kind.RAIL_STATION]
var last_demolish_refund: int = 0


static func town_cost(towns_founded: int = 0) -> int:
	return mini(TOWN_COST_MAX, COST_TOWN + maxi(0, towns_founded) * TOWN_COST_STEP)
