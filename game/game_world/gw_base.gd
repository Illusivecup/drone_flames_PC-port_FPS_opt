extends Node2D


const Cad344: = preload("res://game/cad344.gd")

signal changed
signal message(text: String)
signal missile_launched(m: Missile)
signal news(text: String, col: String)
signal relations_changed
signal war_declared(a: int, b: int)
signal offer_received
signal match_ended(winner: int)
signal city_captured(city: City, old_owner: int)
signal map_mode_changed(mode: int)

const CELL: int = 4
const EXPAND_DT: float = 0.8
const EXP_SLICES: int = 4
const AI_TOWN_DT: float = 38.0
const MIN_CITY_DIST: int = 46
const TOWN_REACH: int = 90
const BORDER_GAP: GDScript = preload("res://game/border_gap.gd")
const BORDER_FILL: GDScript = preload("res://game/border_fill.gd")
const MAX_SEA_BRIDGE: int = 60


const MAX_STRAIT: int = 100
const SEA_ROAD_COST: float = 30.0
const DIRS8: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
const KIND_TREE: int = 0
const KIND_BUILDING: int = 1
const KIND_PROP: int = 2


const COUNTRY_STYLES: Array = [
        {"base": "roof_blue", "light": "water_coast", "dark": "water_ocean", "map": "3a86ff"}, 
        {"base": "roof_red", "light": "fire_orange", "dark": "brick_dark", "map": "ff3b30"}, 
        {"base": "roof_green", "light": "grass_light", "dark": "forest", "map": "3fdc6a"}, 
        {"base": "amber", "light": "window_light", "dark": "amber_dark", "map": "ffc21a"}, 
        {"base": "ui_rubber", "map": "a35cff"}, 
        {"base": "white", "map": "f4f4f4"}, 
        {"base": "intercept_cyan", "map": "2fd8e6"}, 
        {"base": "brick_dark", "map": "ff5fb0"}, 
]

enum MapMode{NORMAL, POLITICAL, MY_LAND, ORES, LOGISTICS, MILITARY, ALLIANCES, AD_COVER}
const MAP_MODE_NAMES: Array = ["ОБЫЧНАЯ", "ПОЛИТИКА", "МОЯ ЗЕМЛЯ", "РУДЫ", "ЛОГИСТИКА", "ВОЕННАЯ", "АЛЬЯНСЫ", "ПВО"]
const MAP_MODE_ICONS: Array = ["icon_map_normal", "icon_map_political", "icon_map_mine", "icon_map_ores", "icon_map_logistics", "icon_map_military", "icon_map_alliance", "icon_ad_sam"]
const MAP_MODE_INFO: Array = [
        ["Обычная карта", "Местность, города и границы стран"], 
        ["Политическая карта", "Страны крупно своими цветами, местность бледная"], 
        ["Моя земля", "Только ваша страна, всё чужое серое"], 
        ["Карта руд", "Залежи по видам: яркие — свободные, тусклые — заняты"], 
        ["Логистика", "Дороги, ЖД, мосты, станции, грузовики, поезда, корабли и торговые пути"], 
        ["Военная карта", "Объекты стран по типам, зоны ПВО, линии фронта"], 
        ["Альянсы", "Цвет, знак и название альянса; вне альянсов — серые"], 
        ["Покрытие ПВО", "Где стреляет ПВО: ваша всегда, чужая — только разведанная"], 
]
const TREE_DENSITY: Dictionary = {7: 78, 8: 92, 6: 6, 9: 3, 10: 14}
const TREE_NAMES: Dictionary = {
        7: ["tree_oak_a", "tree_oak_b", "tree_birch_a", "tree_oak_a", "tree_oak_b"], 
        8: ["tree_pine_a", "tree_pine_b"], 
        6: ["tree_oak_a", "tree_birch_a", "bush_a", "tree_oak_b"], 
        9: ["bush_a"], 
        10: ["tree_pine_a", "bush_a", "tree_pine_b"], 
}

var settings: WorldSettings
var data: WorldData
var atlas: SpriteAtlas
var fx_atlas: SpriteAtlas
var atlas2: SpriteAtlas
var mil: Military
var atlas3: SpriteAtlas
var atlas4: SpriteAtlas
var atlas5: SpriteAtlas
var selected_fac_fn: Callable
var fx_atlas2: SpriteAtlas
var fx_atlas3: SpriteAtlas
var city_power: CityPowerLayer
var obj_fix: Dictionary = {}
var atlas6: SpriteAtlas
var atlas7: SpriteAtlas
var fx_atlas4: SpriteAtlas
var life_atlas: SpriteAtlas
var atlas8: SpriteAtlas
var fx_atlas5: SpriteAtlas
var atlas9: SpriteAtlas
var atlas10: SpriteAtlas
var atlas11: SpriteAtlas
var atlas12: SpriteAtlas
var atlas_crane: SpriteAtlas
var fx_atlas6: SpriteAtlas
var fx_atlas7: SpriteAtlas
var atlas13: SpriteAtlas
var fx_atlas8: SpriteAtlas
var atlas_navy1: SpriteAtlas
var fx_atlas_navy: SpriteAtlas
var atlas_cm28: SpriteAtlas
var atlas_mines27: SpriteAtlas
var atlas_uran30: SpriteAtlas
var diplo: Diplomacy
var econ: Economy
var rail: Rail
var army: Army
var defense: Defense
var session: Match
var ai: AiBots
var fires: Array = []
var ruins: Array = []
var life: LifeLayer
var night: NightLayer
var forts: FortLayer
var _ruin_t: float = 0.0
var _fire_snd_t: float = 0.0
var rng: Rng
var countries: Array[Country] = []
var cities: Array[City] = []
var bridges: Array[Bridge] = []
var road_paths: Array = []
var bridge_cells: Dictionary = {}
var _road_jobs: Array = []
var checkpoints: Dictionary = {}
var player: Country = null
var time_scale: float = 1.0
var game_time: float = 0.0
var camera: MapCamera

var _expand_t: float = 0.0
var _ai_t: float = 0.0
var cad344: Cad344 = null
var _delayed: Array = []
var _checkpoints_dirty: bool = false


var spr_index: Dictionary = {}
var spr_rect: Array[Rect2] = []
var spr_anchor: PackedVector2Array = PackedVector2Array()
var spr_fw: PackedInt32Array = PackedInt32Array()
var spr_fd: PackedInt32Array = PackedInt32Array()
var spr_frames: PackedInt32Array = PackedInt32Array()
var spr_ruin: PackedInt32Array = PackedInt32Array()
var spr_name: PackedStringArray = PackedStringArray()
var spr_tex: Array[Texture2D] = []


var obj_spr: PackedInt32Array = PackedInt32Array()
var obj_x: PackedInt32Array = PackedInt32Array()
var obj_y: PackedInt32Array = PackedInt32Array()
var obj_state: PackedByteArray = PackedByteArray()
var obj_kind: PackedByteArray = PackedByteArray()
var obj_hidden: PackedByteArray = PackedByteArray()
var vision: Vision
var ops: Operations
var battle_watch: BattleWatch
var recon: Recon
var guide: EconGuide
var protect: Protect
var vfx: Vfx
var naval: Naval
var navy: Navy
var supply: Supply
var arch: ArchStyle
var kpp: BorderPosts
var hold: Variant = null
var aftermath: RefCounted
var nature: RefCounted
var pstat: PowerStatus
var drama = null
var candy_events = null
var obj_arch: PackedByteArray = PackedByteArray()
var arch_tab: Array = []
var labels: LabelsLayer
var tree_at: Dictionary = {}
var _free_ids: PackedInt32Array = PackedInt32Array()
var border_noise: PackedByteArray = PackedByteArray()


var terrain: TerrainView
var ground: GroundLayer
var territory: Sprite2D
var territory_border: Sprite2D
var territory_img: Image
var territory_tex: ImageTexture
var map_layer: MapModeLayer
var map_mode: int = MapMode.NORMAL
var selected_army: Facility = null
var show_own_icons: bool = true
var objects: ObjectsLayer
var fx: FxLayer
var top: TopLayer
var units_ground: UnitsLayer
var units_air: UnitsLayer





var _own_rect: Rect2i = Rect2i()


var _gtab: Array = []










const ENC_MAX: int = 600
const ENC_DT: float = 45.0
var _enc_queue: Dictionary = {}
var _enc_job: Dictionary = {}
var _enc_t: float = 0.0
var enc_moved: int = 0
static var enclave_fix_on: bool = true




var _fill_q: Dictionary = {}
var fill_moved: int = 0
var _xfer_q: Dictionary = {}
var _warp_once: Dictionary = {}
var _warp_done: Dictionary = {}
static var border_fill_on: bool = true





const FILL_CAP: int = 600


var enc_main_us_max: int = 0




var selected_fn: Callable




var _lm_lab: = PackedInt32Array()
var _lm_area: Array[int] = []
var _lm_box: Array[Rect2i] = []
const LM_ST: int = 4
const LM_PER_COUNTRY: int = 900




const CAP_ROOM: int = 300




const CMD_FIELDS: Array = ["prod_type", "army_defend", "doctrine_fpv", "doctrine_assault"]









static var extra_links_on: bool = true
const XB_GAP: int = 70
var _xb_tries: int = 0
var _xb_made: int = 0
var _xb_second: bool = false
var xb_mids: Array = []







const SIM_STEP: float = 0.2
const SIM_MAX_STEPS: int = 8
var sim_steps: int = 0
var sim_budget_ms: float = 12.0
var sim_lag: float = 0.0
var sim_ms: float = 0.0





var net_driven: bool = false
static var lab_tick: int = -1
var net_tick: int = 0
var ui_mute: bool = false
var net_sim: bool = false


var perf_job_wait_max: float = 0.0
var _job_first: Dictionary = {}




const _NET_STATIC: Dictionary = {
        "groups": ["create", "add", "remove", "disband", "edit", "set_stance", "group_set_stance", "order_fids", "group_order", "trench_in", "trench_out", "trench_in_fids", "trench_out_fids"], 
        "front": ["set_front", "clear_front", "set_plan", "cancel_plan", "attack_now", "set_auto"], 
        "ship_cr": ["launch", "dock_order", "dock_attack", "dock_salvo", "dock_sink", "dock_service"], 
}




var strike_net: RefCounted = null





static var perf_prof: bool = false
var perf_sys: Dictionary = {}
var _pu: int = 0


const REBUILD_S: float = 60.0
const REBUILD_L: float = 90.0




var capture_quiet: bool = false



var id_style: int = -1
