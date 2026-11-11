extends Node


enum Mode{NONE, CAPITAL, TOWN, STRIKE, FACTORY, DRONEPORT, TEL, MODULE, TARGET, MISSILE, MFACTORY, REFINERY, POWER, AIRFIELD, CR_TARGET, FARM, CIV, MINE, BARRACKS, AD_MFG, AD_SPAAG, AD_SAM, AD_PATRIOT, AD_INT, AD_RADAR, AD_EW, ATTACK, HYP_TARGET, TRENCH_H, TRENCH_V, TEETH_H, TEETH_V, DUGOUT, SAWMILL, OIL_RIG, PORT, SOLAR_FARM, SATELLITE, OPERATION, ORDER, RECON, GARRISON, MOVE_ALL, EXPEDITION, NAVBASE, SHIP_CR, COASTAL_ASM, NPP, UMINE, HOLD, JET_KAB, JET_CAS, RAIL_ST, RAIL_LINE, POLICE_STATION}

const SPEEDS: Array = [1.0, 2.0, 5.0, 10.0, 20.0, 0.5]
const GRAB_R: float = 22.0
const NavyStrike = preload("res://game/navy_strike.gd")
const RB = preload("res://ui/ui24/rail_build.gd")
const BUILD_KEYS: Dictionary = {"police_station": Mode.POLICE_STATION, "factory": Mode.FACTORY, "droneport": Mode.DRONEPORT, "tel": Mode.TEL, "mfactory": Mode.MFACTORY, "refinery": Mode.REFINERY, "power": Mode.POWER, "airfield": Mode.AIRFIELD, 
	"farm": Mode.FARM, "civ": Mode.CIV, "mine": Mode.MINE, "barracks": Mode.BARRACKS, "ad_mfg": Mode.AD_MFG, "ad_spaag": Mode.AD_SPAAG, "ad_sam": Mode.AD_SAM, 
	"ad_patriot": Mode.AD_PATRIOT, "ad_int": Mode.AD_INT, "ad_radar": Mode.AD_RADAR, "ad_ew": Mode.AD_EW, 
	"trench": Mode.TRENCH_H, "teeth": Mode.TEETH_H, "dugout": Mode.DUGOUT, "sawmill": Mode.SAWMILL, "oil_rig": Mode.OIL_RIG, "port": Mode.PORT, "solar_farm": Mode.SOLAR_FARM, "navbase": Mode.NAVBASE, "coastal_asm": Mode.COASTAL_ASM, "npp": Mode.NPP, "umine": Mode.UMINE}
const BUILD_KIND: Dictionary = {Mode.POLICE_STATION: Facility.Kind.POLICE_STATION, Mode.FACTORY: Facility.Kind.DRONE_FACTORY, Mode.DRONEPORT: Facility.Kind.DRONE_PORT, Mode.TEL: Facility.Kind.TEL, Mode.MFACTORY: Facility.Kind.MISSILE_FACTORY, Mode.REFINERY: Facility.Kind.REFINERY, Mode.POWER: Facility.Kind.POWER_PLANT, Mode.AIRFIELD: Facility.Kind.AIRFIELD, 
	Mode.FARM: Facility.Kind.FARM, Mode.CIV: Facility.Kind.CIV_FACTORY, Mode.MINE: Facility.Kind.MINE, Mode.BARRACKS: Facility.Kind.BARRACKS, Mode.AD_MFG: Facility.Kind.AD_MFG, 
	Mode.AD_SPAAG: Facility.Kind.AD_SPAAG, Mode.AD_SAM: Facility.Kind.AD_SAM, Mode.AD_PATRIOT: Facility.Kind.AD_PATRIOT, Mode.AD_INT: Facility.Kind.AD_INT, Mode.AD_RADAR: Facility.Kind.AD_RADAR, Mode.AD_EW: Facility.Kind.AD_EW, 
	Mode.TRENCH_H: Facility.Kind.TRENCH_H, Mode.TEETH_H: Facility.Kind.TEETH_H, Mode.DUGOUT: Facility.Kind.DUGOUT, 
	Mode.SAWMILL: Facility.Kind.SAWMILL, Mode.OIL_RIG: Facility.Kind.OIL_RIG, Mode.PORT: Facility.Kind.PORT, Mode.SOLAR_FARM: Facility.Kind.SOLAR_FARM, Mode.NAVBASE: Facility.Kind.NAVAL_BASE, Mode.COASTAL_ASM: Facility.Kind.COASTAL_ASM, 
	Mode.NPP: Facility.Kind.NUCLEAR_PLANT, Mode.UMINE: Facility.Kind.URANIUM_MINE}

var world: GameWorld
var cam: MapCamera
var hud: Hud
var mode: int = Mode.NONE
var decorator_sprite: String = ""
var repeat_building: bool = false
var settings: WorldSettings
var _speed_i: int = 0
var _paused: bool = false
var _touches: Dictionary = {}
var _press_pos: Vector2 = Vector2.ZERO
var _press_ms: int = 0
var _moved: bool = false
var _pinch_d: float = 0.0
var _mouse_down: bool = false
var _cap_i: int = 0
var _kpp_i: int = -1
var _br_i: int = -1
var _perf_t: float = 0.0
var overlay: RouteOverlay

var plan_wps: Array[Vector2] = []
var plan_target: Vector2 = Vector2.ZERO
var plan_has_target: bool = false
var plan_count: int = 1
var _last_mp: Dictionary = {}
var _danger: Array = []
var _danger_t: float = 0.0
var _hold_t: float = -10.0
var plan_jet: bool = false
var selected_dep: Dictionary = {}
var selected_city: int = -1
var selected_intel: Facility = null
var route_mode: bool = false
var _plan_info: Dictionary = {}
var _drag_pt: int = -2
var _drag_drone_pos: Vector2 = Vector2.ZERO
const LINE_HOLD_MS: int = 250

var follow: Object = null
var cam_lock: bool = false
var _follow_done_t: float = 0.0
var selected_fac: Facility = null
var _focus: Dictionary = {}
var bar_builds_fid: int = -1
var army_view: bool = false
var module_kind: int = Facility.Kind.DP_RAMP
var module_port: Facility = null
var _await_missile: bool = false
var air_patrol_pending: bool = false
var _sel_hint: String = ""
var menus: Menus
var tutorial: Tutorial
var in_menu: bool = true
var _pend: Dictionary = {}
var _confirming: bool = false
var _ghost: Node2D
var _ghost_live: bool = false
var op_from: Facility = null
var hold_from: Facility = null
var garrison_from: Facility = null
var order_kind: int = 0
var _cam_plan: Array = []
var _cam_t: float = 0.0
var _cam_from: Vector2 = Vector2.ZERO
var _cam_from_z: float = 1.0
var _cam_home: Vector2 = Vector2.ZERO
var _cam_home_z: float = 1.0
var _cam_speed_keep: int = -1
var _cam_follow_t: float = 0.0
var _focus_sig: = Vector3(-9, -9, -9)
var _auto_card: Facility = null
var _auto_card_t: float = 0.0
var exp_port: Facility = null
var _prompt_t: float = 0.0
var _sub_confirm: Array = []
var _menu_paused: bool = false
var plan_list: Array = []
const StrikeHubScript = preload("res://game/strike_hub.gd")
const StrikeSheetScript = preload("res://ui/ui24/strike_sheet.gd")
const StrikeMarksScript = preload("res://ui/ui24/strike_marks.gd")
var strike = StrikeHubScript.new()
var strike_ui: Control = null
var strike_marks: Control = null
const Jet316MarksScript = preload("res://ui/ui24/jet316_marks.gd")
var jet316_marks: Control = null
var jet316: Aircraft = null
var jet_pts: Array = []
var _strike_sw: bool = false
var _creative_t: float = 0.0
var attack_from: Facility = null
var _confirm_city: int = -1
var line_cells: Array[Vector2i] = []
var _pinch_mid: Vector2 = Vector2.INF
var _pinch_z0: float = 1.0

var _last_tap_ms: int = -10000


var _strat_tap: Vector2 = Vector2.INF
var _strat_tap_ms: int = 0
var _strat_tap_w: Vector2 = Vector2.INF
var _last_tap_pos: Vector2 = Vector2.INF
var _dtz: bool = false
var _dtz_y0: float = 0.0
var _dtz_z0: float = 1.0
var _dtz_anchor: Vector2 = Vector2.ZERO
var _menu_pan: Vector2 = Vector2(1, 0.35)
var loading: Loading
var net: NetSession
var _net_banner: MpKit.Plate = null
var _net_last_key: String = ""
const MODE_KEY: Dictionary = {Mode.MOVE_ALL: "operation", Mode.GARRISON: "garrison", Mode.RECON: "recon", Mode.OPERATION: "operation", Mode.SATELLITE: "satellite", Mode.CAPITAL: "capital", Mode.TOWN: "town", Mode.TARGET: "launch", Mode.MISSILE: "missile", Mode.ATTACK: "attack", Mode.STRIKE: "missile", Mode.SHIP_CR: "ship_cr"}




var _snap_c: Dictionary = {}


var _seen_pend: Dictionary = {}



const SPECTATOR_OK: Array = ["pause", "speed", "speed_next", "zoom_in", "zoom_out", "center", "menu", "map_modes", "open_stats", "scores", "borders", "own_icons", "battle_cam", "resume", "continue", "main_menu", "setup", "load_save", "new_world", "economy", "inventory", "diplomacy", "ops_close", "pend_cancel", "prompt_no", "plan_toggle"]



var _spick: Control = null


const MapDeclutter303b = preload("res://ui/ui24/map_declutter.gd")


const AGroups303 = preload("res://game/army_groups.gd")




static var _res_go_told: bool = false





var _gw_key: Array = []
var _gw_why: String = ""
var _gw_t: int = -100000




var _cr_warn: Label = null




const STRIKE_MODE: Dictionary = {"drone": Mode.TARGET, "jet": Mode.TARGET, "tel": Mode.MISSILE, "ship": Mode.SHIP_CR, "art": Mode.SHIP_CR, "bomber": Mode.CR_TARGET, "hyper": Mode.HYP_TARGET, "thermo": Mode.MISSILE, "nuke": Mode.MISSILE, "iskander": Mode.MISSILE}



var _short_cost: Dictionary = {}


var _army_i: int = 0


var _speed_hinted: bool = false
var _speed_toast_ms: int = -100000


var _resume_btn: Button = null





const JET_MAX_PTS: int = 4
