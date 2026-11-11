class_name Sfx
extends Node




















const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_PATH: String = "res://assets/audio/music/%s.mp3"
const SETTINGS_PATH: String = "user://settings.cfg"
const VOICES_WORLD: int = 12
const VOICES_FLAT: int = 4
const VOICES_FAST: int = 8
const FADE: float = 1.5
const FAR_DB: float = -24.0
const SILENT_DB: float = -60.0
const LOOP_SLEW: float = 60.0
const BED_SLEW: float = 12.0
const ZOOM_SMALL: float = 0.6
const ZOOM_ALL_DB: float = -5.0
const NEAR_K: float = 0.95
const SMALL_MAX_K: float = 1.5

const FOG_MUFFLE: Dictionary = {"expl_big": -8.0, "building_collapse": -8.0, "artillery_fire": -10.0, "mlrs_salvo": -10.0, 
	"missile_launch": -8.0, "hyper_launch": -8.0, "concrete_thud": -10.0, "expl_far": -6.0, "far_boom": -6.0, 
	"ship_hit": -8.0, "sea_explosion": -8.0, "ship_sinking": -10.0, "cruise_launch_vls": -10.0}

const AIR_IDS: Dictionary = {"jet_flyby": true, "missile_whistle": true, "fpv_buzz": true, "sam_launch": true, "intercept_pop": true, 
	"missile_cruise_launch": true, "drone_launch": true, "drone_buzz_loop": true, "heli_loop": true, "recon_drone_buzz": true, 
	"asm_flyby": true, "ship_sam_launch": true, 
	"jet_uav_loop": true, "cruise_missile_loop": true, "attack_jet_loop": true, "bomber_loop": true, 
	"jet_uav_pass": true, "cruise_missile_pass": true, "jet_pass": true, "bomber_pass": true, "kab_fall": true}

const FOG_LOOPS: Dictionary = {"drone_buzz_loop": true, "heli_loop": true, "recon_drone_buzz": true, "fire_loop": true, 
	"jet_uav_loop": true, "cruise_missile_loop": true, "attack_jet_loop": true, "bomber_loop": true}


const FAR_LOOPS: Dictionary = {"air_rumble_loop": [1.3, 6.0]}
const FAR_LOOP_DB: Array = [-3.0, -30.0]
const PAN_STRENGTH: float = 2.0
const PAN_COMP_DB: float = 5.0
const TICK: float = 0.25
const LOOP_OFF_SLEW: float = 150.0
const HEALTH_DT: float = 1.0
const DEAD_MIX_S: float = 1.5
const DUCK_MAX: float = 9.0
const DUCK_REC: float = 6.0
const DUCKERS: Dictionary = {"expl_big": 1.0, "building_collapse": 0.8, "hyper_launch": 0.6, "missile_launch": 0.5, 
	"mlrs_salvo": 0.6, "concrete_thud": 0.7, "tank_cannon": 0.3, "artillery_fire": 0.4, 
	"ship_hit": 0.7, "sea_explosion": 0.6, "cruise_launch_vls": 0.5, "ship_sinking": 0.4}
const BUS_DB: Dictionary = {"UI": -3.0, "Ambience": 2.0}

const FAR_SWAP: Dictionary = {"expl_big": "far_boom", "artillery_fire": "artillery_far", "mlrs_salvo": "far_boom"}
const FAR_SWAP_K: float = 6.0
const ALIAS: Dictionary = {"battle_cannonade_loop": "cannonade_loop"}

const SCAPE_KEYS: Dictionary = {"cannonade": true, "amb_wind": true}

const VARIATIONS: Dictionary = {"expl_small": 2, "expl_big": 2, "rifle_burst": 2, "far_boom": 3}

const CAT_CAP: Dictionary = {"expl": 4, "gun": 4, "launch": 3, "arty": 3, "whistle": 2, "air": 2, "misc": 3, 
	"nlaunch": 4, "ciws": 3, "decoy": 2, "splash": 2}
const CAT_OF: Dictionary = {
	"expl_big": "expl", "expl_small": "expl", "expl_far": "expl", "far_boom": "expl", "building_collapse": "expl", 
	"atgm_hit": "expl", "grenade": "expl", "concrete_thud": "expl", "net_catch": "expl", "intercept_pop": "expl", 
	"tank_cannon": "gun", "rifle_burst": "gun", "mg_burst": "gun", "aa_gun": "gun", 
	"missile_launch": "launch", "missile_cruise_launch": "launch", "hyper_launch": "launch", "sam_launch": "launch", 
	"drone_launch": "launch", "rpg_fire": "launch", "atgm_launch": "launch", 
	"artillery_fire": "arty", "artillery_far": "arty", "mortar_fire": "arty", "mlrs_salvo": "arty", 
	"missile_whistle": "whistle", "shell_whistle_in": "whistle", "jet_flyby": "air", "fpv_buzz": "air", 

	"asm_launch": "nlaunch", "cruise_launch_vls": "nlaunch", "ship_sam_launch": "nlaunch", "ciws_burst": "ciws", 
	"chaff_burst": "decoy", "decoy_flares": "decoy", "ship_hit": "expl", "sea_explosion": "expl", "ship_sinking": "expl", 
	"splash_big": "splash", "naval_gun": "gun", "asm_flyby": "air", 

	"jet_pass": "air", "bomber_pass": "air", "jet_uav_pass": "air", "cruise_missile_pass": "air", "kab_fall": "whistle", 
}

const FIRE_W: Dictionary = {"artillery_fire": 1.0, "artillery_far": 0.8, "mlrs_salvo": 2.0, "mortar_fire": 0.6, 
	"tank_cannon": 0.6, "expl_big": 0.8, "expl_small": 0.3, "rifle_burst": 0.12, "mg_burst": 0.15, "grenade": 0.2, 
	"atgm_launch": 0.3, "rpg_fire": 0.3, "atgm_hit": 0.3}



const LOOP_FLOOR: Dictionary = {}



const RULES: Dictionary = {
	"ui_click": [6, 0.03, -5.0, false], 
	"ui_tab": [6, 0.03, -6.0, false], 
	"ui_select": [4, 0.03, -4.0, false], 
	"ui_cancel": [4, 0.03, -4.0, false], 
	"ui_open": [4, 0.05, -7.0, false], 
	"ui_close": [4, 0.05, -7.0, false], 
	"ui_error": [2, 0.1, -3.0, false], 
	"ui_money": [3, 0.08, -4.0, false], 
	"ui_build": [2, 0.3, -4.0, false], 
	"ui_alert": [1, 0.5, -1.0, false], 
	"ui_war": [1, 1.0, 0.0, false], 
	"ui_capture": [1, 0.5, 0.0, false], 
	"ui_city_lost": [1, 0.5, 0.0, false], 
	"ui_victory": [1, 1.0, 0.0, false], 
	"ui_defeat": [1, 1.0, 0.0, false], 
	"expl_small": [6, 0.05, -1.0, true], 
	"expl_big": [6, 0.08, 1.0, false], 
	"expl_far": [3, 0.2, -2.0, false], 
	"far_boom": [3, 0.25, -2.0, false], 
	"building_collapse": [2, 0.4, -1.0, false], 
	"concrete_thud": [2, 0.2, 0.0, false], 
	"net_catch": [2, 0.2, -1.0, false], 
	"missile_launch": [2, 0.2, -2.0, false], 
	"missile_cruise_launch": [2, 0.3, -3.0, false], 
	"hyper_launch": [2, 0.2, -2.0, false], 
	"missile_whistle": [2, 0.3, -3.0, false], 
	"drone_launch": [2, 0.25, -6.0, true], 
	"fpv_buzz": [2, 0.5, -4.0, true], 
	"jet_flyby": [1, 1.5, -3.0, false], 
	"sam_launch": [3, 0.15, -3.0, false], 
	"aa_gun": [3, 0.15, -4.0, true], 
	"intercept_pop": [4, 0.08, -3.0, false], 
	"radar_ping": [1, 1.0, -9.0, true], 
	"tank_cannon": [3, 0.15, 0.0, true], 
	"rifle_burst": [4, 0.15, -6.0, true], 
	"mg_burst": [2, 0.25, -6.0, true], 
	"rpg_fire": [2, 0.2, -3.0, true], 
	"atgm_launch": [2, 0.2, -4.0, true], 
	"atgm_hit": [3, 0.1, -2.0, true], 
	"dig_trench": [1, 0.5, -6.0, false], 
	"truck_pass": [1, 4.0, -11.0, true], 
	"ship_horn": [1, 3.0, -8.0, false], 
	"container_clank": [2, 1.0, -9.0, true], 
	"sawmill_saw": [1, 2.5, -11.0, true], 
	"pumpjack_loop": [1, 0.0, -9.0, true], 
	"fire_loop": [1, 0.0, -4.0, false], 
	"siren_loop": [1, 0.0, -3.0, true], 
	"drone_buzz_loop": [1, 0.0, -6.0, true], 
	"heli_loop": [1, 0.0, -5.0, true], 
	"ew_hum": [1, 0.0, -8.0, true], 
	"ambient_wind_loop": [1, 0.0, 0.0, false], 
	"ambient_battle_loop": [1, 0.0, 0.0, false], 
	"train_horn": [2, 2.0, -6.0, true], 
	"train_roll_loop": [1, 0.0, -7.0, true], 
	"artillery_fire": [3, 0.12, -1.0, false], 
	"artillery_far": [2, 0.35, -2.0, false], 
	"mortar_fire": [3, 0.1, -3.0, true], 
	"shell_whistle_in": [2, 0.3, -4.0, false], 
	"mlrs_salvo": [1, 1.0, -1.0, false], 
	"grenade": [3, 0.1, -4.0, true], 
	"recon_drone_buzz": [1, 0.0, -7.0, true], 
	"cannonade_loop": [1, 0.0, 0.0, false], 

	"asm_launch": [4, 0.12, -4.0, false], 
	"cruise_launch_vls": [3, 0.2, -2.0, false], 
	"vls_hatch_open": [2, 0.15, -9.0, true], 
	"asm_flyby": [2, 0.4, -5.0, false], 
	"ciws_burst": [3, 0.1, -3.0, false], 
	"ship_sam_launch": [3, 0.15, -4.0, false], 
	"chaff_burst": [2, 0.25, -7.0, true], 
	"decoy_flares": [2, 0.25, -6.0, true], 
	"ship_hit": [4, 0.08, 0.0, false], 
	"sea_explosion": [3, 0.15, -1.0, false], 
	"splash_big": [4, 0.08, -6.0, true], 
	"ship_sinking": [2, 0.5, -2.0, false], 
	"naval_gun": [3, 0.12, -4.0, true], 
	"warship_horn": [1, 3.0, -6.0, false], 
	"convoy_horn": [1, 4.0, -7.0, false], 
	"alarm_general_quarters": [1, 6.0, -7.0, false], 
	"dock_crane": [1, 2.0, -10.0, true], 
	"repair_work": [1, 2.0, -10.0, true], 
	"ship_engine_loop": [3, 0.0, -9.0, true], 
	"bow_wash_loop": [2, 0.0, -9.0, true], 
	"ship_fire_loop": [2, 0.0, -3.0, false], 
	"navbase_ambient_loop": [1, 0.0, -4.0, true], 

	"jet_uav_loop": [1, 0.0, -5.0, false], 
	"cruise_missile_loop": [1, 0.0, -6.0, false], 
	"attack_jet_loop": [1, 0.0, -4.0, false], 
	"bomber_loop": [1, 0.0, -4.0, false], 
	"air_rumble_loop": [1, 0.0, -2.0, false], 
	"jet_pass": [1, 1.2, -2.0, false], 
	"bomber_pass": [1, 2.5, -2.0, false], 
	"jet_uav_pass": [2, 0.6, -4.0, false], 
	"cruise_missile_pass": [2, 0.6, -4.0, false], 
	"kab_fall": [2, 0.3, -3.0, false], 

	"treaty_signed": [1, 0.5, -3.0, false], 
	"protest_note": [1, 0.5, -6.0, false], 
	"call_to_arms": [1, 1.0, -2.0, false], 
	"vassal_sworn": [1, 1.0, -2.0, false], 
	"conference_gong": [1, 1.5, -3.0, false], 
	"territory_claim": [1, 0.3, -5.0, false], 
	"aid_sent": [1, 0.4, -4.0, false], 
}
const RULE_DEFAULT: Array = [3, 0.05, 0.0, false]
const RULE_UI: Array = [6, 0.03, -4.0, false]

static var sfx_volume: float = 0.8
static var music_volume: float = 0.5
static var ambience_volume: float = 0.8
static var speed: float = 1.0
static var _inst: Sfx = null
static var _settings_loaded: bool = false

var _cam: Camera2D = null
var _wv: Array[AudioStreamPlayer2D] = []
var _w_id: PackedStringArray = PackedStringArray()
var _w_cat: PackedStringArray = PackedStringArray()
var _w_k: PackedFloat32Array = PackedFloat32Array()
var _w_t: PackedInt64Array = PackedInt64Array()
var _w_wait: PackedByteArray = PackedByteArray()
var _fv: Array[AudioStreamPlayer] = []
var _f_id: PackedStringArray = PackedStringArray()
var _f_t: PackedInt64Array = PackedInt64Array()
var _f_ui: PackedByteArray = PackedByteArray()
var _f_wait: PackedByteArray = PackedByteArray()
var _last: Dictionary = {}
var _cat_win: Dictionary = {}
var _cache: Dictionary = {}
var _paths: Dictionary = {}
var _loops: Dictionary = {}
var _beds: Dictionary = {}
var _tweens: Dictionary = {}
var _mus: Array[AudioStreamPlayer] = []
var _mus_i: int = 0
var _track: String = ""
var _duck: float = 0.0
var _fire: Array = []
var _tick_t: float = 0.0
var _zoom_cut: float = -1.0
var scape: Soundscape = null
var counts: Dictionary = {"started": 0, "dropped_cap": 0, "dropped_far": 0, "stolen": 0, "throttled": 0, "fog": 0, 
	"loop_new": 0, "bad_vol": 0, "recovered": 0, "dead_mix": 0}
var _health_t: float = 0.0
var _focus_ms: int = 0
var _recover_ms: int = -100000
var _dead_told: bool = false
static var debug_force_dead: bool = false





static func play(id: String, at: Vector2 = Vector2.INF, vol_db: float = 0.0) -> void :
	var s: Sfx = _instance()
	if s != null:
		s._play(id, at, vol_db, false)



static func play_seen(id: String, at: Vector2 = Vector2.INF, vol_db: float = 0.0) -> void :
	var s: Sfx = _instance()
	if s != null:
		s._play(id, at, vol_db, false, true)



static func far(id: String, src: Vector2, vol_db: float = 0.0) -> void :
	var s: Sfx = _instance()
	if s != null:
		s._far(id, src, vol_db)



static func ui(id: String) -> void :
	var s: Sfx = _instance()
	if s != null:
		s._play(id, Vector2.INF, 0.0, true)




static func loop(key: String, id: String, on: bool, at: Vector2 = Vector2.INF, vol_db: float = 0.0) -> void :
	if not on and (_inst == null or not is_instance_valid(_inst)):
		return
	var s: Sfx = _instance()
	if s != null:
		s._loop(key, id, on, at, vol_db)



static func music(track: String) -> void :
	var s: Sfx = _instance()
	if s != null:
		s._music(track)



static func set_listener(cam: Camera2D) -> void :
	var s: Sfx = _instance()
	if s != null:
		s._cam = cam



static func attach_world(w: GameWorld) -> void :
	var s: Sfx = _instance()
	if s == null:
		return
	if w == null:
		if s.scape != null:
			s.scape.stop()
		s.scape = null
		return
	if s.scape == null or s.scape.gw != w:
		if s.scape != null:
			s.scape.stop()
		s.scape = Soundscape.new(s, w)
		for key: String in SCAPE_KEYS:
			s._loop(key, "", false, Vector2.INF, 0.0)



static func detach_world(w: GameWorld) -> void :
	if _inst == null or not is_instance_valid(_inst) or _inst.scape == null:
		return
	if _inst.scape.gw == w:
		_inst.scape.stop()
		_inst.scape = null



static func listener() -> Vector2:
	if _inst == null or not is_instance_valid(_inst):
		return Vector2.INF
	var cam: Camera2D = _inst._listener_cam()
	return cam.position if cam != null else Vector2.INF



static func debug_state() -> Dictionary:
	if _inst == null or not is_instance_valid(_inst):
		return {}
	return _inst._debug_state()



static func apply_volumes() -> void :
	_settings_loaded = true
	sfx_volume = clampf(sfx_volume, 0.0, 1.0)
	music_volume = clampf(music_volume, 0.0, 1.0)
	ambience_volume = clampf(ambience_volume, 0.0, 1.0)
	_apply_bus_volumes()
	save_settings()


static func load_settings() -> void :
	if _settings_loaded:
		return
	_settings_loaded = true
	var cf: = ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	sfx_volume = clampf(float(cf.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	music_volume = clampf(float(cf.get_value("audio", "music", music_volume)), 0.0, 1.0)
	ambience_volume = clampf(float(cf.get_value("audio", "ambience", ambience_volume)), 0.0, 1.0)


static func save_settings() -> void :
	var cf: = ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		cf = ConfigFile.new()
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("audio", "music", music_volume)
	cf.set_value("audio", "ambience", ambience_volume)
	if cf.save(SETTINGS_PATH) != OK:
		push_warning("Sfx: cannot save " + SETTINGS_PATH)




static func _instance() -> Sfx:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	load_settings()
	_inst = Sfx.new()
	_inst.name = "Sfx"
	_inst.process_mode = Node.PROCESS_MODE_ALWAYS
	_inst._setup()
	tree.root.add_child.call_deferred(_inst)
	return _inst



static func _bus(bus_name: String) -> int:
	var i: int = AudioServer.get_bus_index(bus_name)
	if i >= 0:
		return i
	if bus_name == "SFX_Far":
		_bus("SFX")
	AudioServer.add_bus()
	i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, &"SFX" if bus_name == "SFX_Far" else &"Master")
	match bus_name:
		"SFX":
			AudioServer.add_bus_effect(i, AudioEffectHardLimiter.new())
		"SFX_Far", "Ambience":
			var lp: = AudioEffectLowPassFilter.new()
			lp.cutoff_hz = 2600.0 if bus_name == "SFX_Far" else 12000.0
			lp.resonance = 0.5
			AudioServer.add_bus_effect(i, lp)
	return i





static var beds_off: bool = false


static func set_beds_off(on: bool) -> void :
	beds_off = on
	_apply_bus_volumes()


static func _apply_bus_volumes() -> void :
	var si: int = _bus("SFX")
	var mi: int = _bus("Music")
	var ui_i: int = _bus("UI")
	_bus("SFX_Far")
	AudioServer.set_bus_mute(si, sfx_volume < 0.001)
	AudioServer.set_bus_volume_db(si, linear_to_db(maxf(sfx_volume, 0.001)))
	AudioServer.set_bus_mute(ui_i, sfx_volume < 0.001)
	AudioServer.set_bus_volume_db(ui_i, linear_to_db(maxf(sfx_volume, 0.001)) + float(BUS_DB["UI"]))
	AudioServer.set_bus_mute(mi, music_volume < 0.001 or beds_off)
	AudioServer.set_bus_volume_db(mi, linear_to_db(maxf(music_volume, 0.001)))
	var duck: float = _inst._duck if _inst != null and is_instance_valid(_inst) else 0.0
	_set_amb_volume(duck)


static func _set_amb_volume(duck: float) -> void :
	var ai: int = _bus("Ambience")
	var v: float = sfx_volume * ambience_volume
	var off: bool = v < 0.001 or beds_off
	if AudioServer.is_bus_mute(ai) != off:
		AudioServer.set_bus_mute(ai, off)
	AudioServer.set_bus_volume_db(ai, linear_to_db(maxf(v, 0.001)) + float(BUS_DB["Ambience"]) - duck)


func _setup() -> void :
	_bus("SFX")
	_bus("SFX_Far")
	_bus("Ambience")
	_bus("UI")
	_bus("Music")
	_apply_bus_volumes()
	for i in VOICES_WORLD:
		var p: = AudioStreamPlayer2D.new()
		p.bus = &"SFX"
		p.attenuation = 0.0
		p.max_distance = 10000000.0
		p.panning_strength = PAN_STRENGTH
		add_child(p)
		_wv.append(p)
	_w_id.resize(VOICES_WORLD)
	_w_cat.resize(VOICES_WORLD)
	_w_k.resize(VOICES_WORLD)
	_w_t.resize(VOICES_WORLD)
	_w_wait.resize(VOICES_WORLD)
	for i in VOICES_FLAT:
		var f: = AudioStreamPlayer.new()
		f.bus = &"UI"
		add_child(f)
		_fv.append(f)
	_f_id.resize(VOICES_FLAT)
	_f_t.resize(VOICES_FLAT)
	_f_ui.resize(VOICES_FLAT)
	_f_wait.resize(VOICES_FLAT)
	for i in 2:
		var m: = AudioStreamPlayer.new()
		m.bus = &"Music"
		m.volume_db = SILENT_DB
		add_child(m)
		_mus.append(m)


	for id: String in RULES.keys() + ["battle_close_loop", "birds_day_loop", "crickets_night_loop", "surf_loop", "river_loop", 
			"town_hum_loop", "industry_hum_loop"]:
		var n: int = int(VARIATIONS.get(id, 0))
		var names: Array = [id] if n <= 0 else range(1, n + 1).map( func(k: int) -> String: return "%s_%d" % [id, k])
		for nm: String in names:
			var p: String = _path(nm)
			if p != "":
				ResourceLoader.load_threaded_request(p)




func _rule(id: String, is_ui: bool) -> Array:
	if RULES.has(id):
		return RULES[id]
	return RULE_UI if is_ui or id.begins_with("ui_") else RULE_DEFAULT


func _listener_cam() -> Camera2D:
	if is_instance_valid(_cam) and _cam.is_inside_tree():
		return _cam
	if is_inside_tree():
		return get_viewport().get_camera_2d()
	return null




func _dist_k(at: Vector2) -> float:
	if not at.is_finite():
		return -1.0
	var cam: Camera2D = _listener_cam()
	if cam == null:
		return -1.0
	var half: Vector2 = cam.get_viewport_rect().size * 0.5 / maxf(cam.zoom.x, 0.01)
	var d: Vector2 = (at - cam.position).abs()
	return maxf(d.x / maxf(half.x, 1.0), d.y / maxf(half.y, 1.0))



func _dist_db(k: float, small: bool) -> float:
	if k < 0.0:
		return 0.0
	if k >= 2.0 or (small and k > SMALL_MAX_K):
		return SILENT_DB
	var db: float = (-6.0 + (FAR_DB + 6.0) * (k - 1.0)) if k > 1.0 else 0.0
	var z: float = _cam_zoom()
	if z < 1.0:
		db += ZOOM_ALL_DB * clampf((1.0 - z) / 0.75, 0.0, 1.0)
	if small and z < ZOOM_SMALL:
		db -= 12.0 * clampf((ZOOM_SMALL - z) / (ZOOM_SMALL - 0.25), 0.0, 1.0)
	var sk: float = MapCamera.strat_k_of(z)
	if sk > 0.0:
		if small and sk > 0.5:
			return SILENT_DB
		db -= 10.0 * sk
	return db


func _cam_zoom() -> float:
	var cam: Camera2D = _listener_cam()
	return cam.zoom.x if cam != null else 1.0



static func _speed_mult() -> float:
	return 1.0 if speed <= 2.0 else clampf(sqrt(speed) / 1.4, 1.0, 3.5)



func _path(nm: String) -> String:
	if _paths.has(nm):
		return _paths[nm]
	var out: String = ""
	for ext: String in [".ogg", ".mp3"]:
		if ResourceLoader.exists(SFX_DIR + nm + ext):
			out = SFX_DIR + nm + ext
			break
	_paths[nm] = out
	return out


func _load(path: String, looped: bool) -> AudioStream:
	if path == "":
		return null
	var key: String = path + "#loop" if looped else path
	if _cache.has(key):
		return _cache[key]
	var st: AudioStream = null
	if ResourceLoader.exists(path):
		st = load(path) as AudioStream
		if st != null:
			st = st.duplicate() as AudioStream
			if st is AudioStreamMP3:
				(st as AudioStreamMP3).loop = looped
			elif st is AudioStreamOggVorbis:
				(st as AudioStreamOggVorbis).loop = looped
	_cache[key] = st
	return st


func _stream(id: String) -> AudioStream:
	var n: int = int(VARIATIONS.get(id, 0))
	if n <= 0:
		return _load(_path(id), false)
	return _load(_path("%s_%d" % [id, randi_range(1, n)]), false)




func _note_fire(id: String, at: Vector2, vis: bool) -> void :
	if not FIRE_W.has(id) or not at.is_finite():
		return
	_fire.append([Time.get_ticks_msec(), float(FIRE_W[id]), at, vis])
	if _fire.size() > 384:
		_fire = _fire.slice(192)



func fire_events(win: float) -> Array:
	var lim: int = Time.get_ticks_msec() - int(win * 1000.0)
	var k: int = _fire.size() - 1
	while k >= 0 and int(_fire[k][0]) >= lim:
		k -= 1
	if k >= 0:
		_fire = _fire.slice(k + 1)
	return _fire



func _visible(at: Vector2, air: bool) -> bool:
	if scape == null or not is_instance_valid(scape.gw) or scape.gw.vision == null or not at.is_finite():
		return true
	return scape.gw.vision.sees_air(at) if air else scape.gw.vision.sees(at)



func _cat_ok(cat: String, now: int) -> bool:
	var cap: int = int(CAT_CAP.get(cat, 3))
	if speed > 2.0:
		cap = maxi(1, cap >> 1)
	var w: Array = _cat_win.get(cat, [])
	if w.is_empty() or now - int(w[0]) >= 250:
		_cat_win[cat] = [now, 1]
		return true
	if int(w[1]) >= cap:
		return false
	w[1] = int(w[1]) + 1
	return true


func _play(id: String, at: Vector2, vol_db: float, is_ui: bool, seen: bool = false) -> void :
	if not is_finite(vol_db):
		counts["bad_vol"] = int(counts["bad_vol"]) + 1
		return
	id = String(ALIAS.get(id, id))
	var vis: bool = true
	if not is_ui and at.is_finite():
		vis = seen or _visible(at, AIR_IDS.has(id))
		_note_fire(id, at, vis)
	var fog_db: float = 0.0
	if not vis:
		if not FOG_MUFFLE.has(id):
			counts["fog"] = int(counts["fog"]) + 1
			return
		fog_db = float(FOG_MUFFLE[id])
	var rule: Array = _rule(id, is_ui)
	var now: int = Time.get_ticks_msec()
	var iv: float = float(rule[1]) * (1.0 if is_ui else _speed_mult())
	if now - int(_last.get(id, -1000000)) < int(iv * 1000.0):
		counts["throttled"] = int(counts["throttled"]) + 1
		return
	var db: float = vol_db + float(rule[2]) + fog_db
	var k: float = -1.0 if is_ui else _dist_k(at)
	if not vis:
		k = maxf(k, NEAR_K + 0.01)
	if k < 0.0:
		_play_flat(id, db, is_ui, rule, now)
		return
	var att: float = _dist_db(k, bool(rule[3]))
	if att <= SILENT_DB:
		counts["dropped_far"] = int(counts["dropped_far"]) + 1
		if FAR_SWAP.has(id) and k < FAR_SWAP_K:
			_far(String(FAR_SWAP[id]), at, vol_db - 4.0 - 2.5 * (k - 2.0))
		return
	_play_world(id, at, db + att, k, rule, now)


func _play_flat(id: String, db: float, is_ui: bool, rule: Array, now: int) -> void :
	var busy: int = 0
	var free_i: int = -1
	var old_i: int = -1
	for i in VOICES_FLAT:
		if not _fv[i].playing and _f_wait[i] == 0:
			if free_i < 0:
				free_i = i
			continue
		if _f_id[i] == id:
			busy += 1
		if (_f_ui[i] == 0 or is_ui) and (old_i < 0 or _f_t[i] < _f_t[old_i]):
			old_i = i
	if busy >= int(rule[0]):
		counts["dropped_cap"] = int(counts["dropped_cap"]) + 1
		return
	var slot: int = free_i if free_i >= 0 else old_i
	if slot < 0:
		return
	var stream: AudioStream = _stream(id)
	if stream == null:
		return
	_last[id] = now
	counts["started"] = int(counts["started"]) + 1
	var p: AudioStreamPlayer = _fv[slot]
	p.stop()
	p.stream = stream
	p.bus = &"UI" if is_ui or id.begins_with("ui_") else &"SFX"
	p.volume_db = db
	p.pitch_scale = randf_range(0.97, 1.03) if is_ui else randf_range(0.94, 1.06)
	_f_id[slot] = id
	_f_t[slot] = now
	_f_ui[slot] = 1 if is_ui else 0
	if is_inside_tree():
		p.play()
	else:
		_f_wait[slot] = 1
		p.play.call_deferred()




func _play_world(id: String, at: Vector2, db: float, k: float, rule: Array, now: int) -> void :
	var cat: String = String(CAT_OF.get(id, "misc"))
	var busy: int = 0
	var in_cat: int = 0
	var far_cat: int = -1
	var free_i: int = -1
	var far_any: int = -1
	for i in VOICES_WORLD:
		if not _wv[i].playing and _w_wait[i] == 0:
			if free_i < 0:
				free_i = i
			continue
		if _w_id[i] == id:
			busy += 1
		if _w_cat[i] == cat:
			in_cat += 1
			if far_cat < 0 or _w_k[i] > _w_k[far_cat]:
				far_cat = i
		if far_any < 0 or _w_k[i] - float(now - _w_t[i]) * 0.0005 > _w_k[far_any] - float(now - _w_t[far_any]) * 0.0005:
			far_any = i
	if busy >= int(rule[0]):
		counts["dropped_cap"] = int(counts["dropped_cap"]) + 1
		return
	var slot: int = free_i
	if speed > 2.0 and VOICES_WORLD - _free_world() >= VOICES_FAST:
		slot = -1
	if in_cat >= int(CAT_CAP.get(cat, 3)):
		if far_cat < 0 or _w_k[far_cat] <= k + 0.05:
			counts["dropped_cap"] = int(counts["dropped_cap"]) + 1
			return
		slot = far_cat
	elif slot < 0:
		if far_any < 0 or _w_k[far_any] <= k:
			counts["dropped_cap"] = int(counts["dropped_cap"]) + 1
			return
		slot = far_any
	if not _cat_ok(cat, now):
		counts["throttled"] = int(counts["throttled"]) + 1
		return
	var stream: AudioStream = _stream(id)
	if stream == null:
		return
	if _wv[slot].playing:
		counts["stolen"] = int(counts["stolen"]) + 1
	_last[id] = now
	counts["started"] = int(counts["started"]) + 1
	var p: AudioStreamPlayer2D = _wv[slot]
	p.stop()
	p.stream = stream
	p.position = at
	p.bus = &"SFX_Far" if k > NEAR_K or _cam_zoom() < 0.75 else &"SFX"
	p.volume_db = db + PAN_COMP_DB
	p.pitch_scale = randf_range(0.94, 1.06)
	_w_id[slot] = id
	_w_cat[slot] = cat
	_w_k[slot] = k
	_w_t[slot] = now
	if DUCKERS.has(id) and k < 1.2:
		_duck = maxf(_duck, DUCK_MAX * float(DUCKERS[id]) * clampf((1.2 - k) / 0.8, 0.0, 1.0) * (1.0 if speed <= 2.0 else 0.5))
	if is_inside_tree():
		p.play()
	else:
		_w_wait[slot] = 1
		p.play.call_deferred()


func _free_world() -> int:
	var n: int = 0
	for i in VOICES_WORLD:
		if not _wv[i].playing and _w_wait[i] == 0:
			n += 1
	return n



func _far(id: String, src: Vector2, vol_db: float) -> void :
	if not is_finite(vol_db):
		counts["bad_vol"] = int(counts["bad_vol"]) + 1
		return
	id = String(ALIAS.get(id, id))
	var cam: Camera2D = _listener_cam()
	var rule: Array = _rule(id, false)
	var now: int = Time.get_ticks_msec()
	if now - int(_last.get(id, -1000000)) < int(float(rule[1]) * _speed_mult() * 1000.0):
		counts["throttled"] = int(counts["throttled"]) + 1
		return
	if cam == null or not src.is_finite():
		_play_flat(id, vol_db + float(rule[2]), false, rule, now)
		return
	var half_w: float = cam.get_viewport_rect().size.x * 0.5 / maxf(cam.zoom.x, 0.01)
	var d: Vector2 = src - cam.position
	var at: Vector2 = cam.position + (d.normalized() * half_w * 1.2 if d.length() > 1.0 else Vector2.ZERO)
	_play_world(id, at, vol_db + float(rule[2]), 3.0, rule, now)


func _loop(key: String, id: String, on: bool, at: Vector2, vol_db: float) -> void :
	if scape != null and SCAPE_KEYS.has(key):
		on = false
	id = String(ALIAS.get(id, id))
	if not is_finite(vol_db):
		counts["bad_vol"] = int(counts["bad_vol"]) + 1
		vol_db = SILENT_DB



	var e: Dictionary = _loops.get(key, {})
	if not on:
		if not e.is_empty():
			e["on"] = false
		return
	if not e.is_empty():
		e["at"] = at
		e["vol"] = vol_db
		e["on"] = true
		if String(e["id"]) != id:
			var st: AudioStream = _load(_path(id), true)
			if st == null:
				e["on"] = false
				return
			var p0: AudioStreamPlayer2D = e["p"]
			p0.stop()
			p0.stream = st
			p0.volume_db = SILENT_DB
			e["id"] = id
			if p0.is_inside_tree():
				p0.play(randf() * maxf(st.get_length() - 0.2, 0.0))
			else:
				p0.play.call_deferred(0.0)
		return
	var p: AudioStreamPlayer2D = _new_loop_player(id, &"SFX")
	if p == null:
		return
	counts["loop_new"] = int(counts["loop_new"]) + 1
	_loops[key] = {"p": p, "id": id, "at": at, "vol": vol_db, "on": true}



func bed(key: String, id: String, want_db: float, at: Vector2 = Vector2.INF) -> void :
	if not is_finite(want_db):
		want_db = SILENT_DB
	var e: Dictionary = _beds.get(key, {})
	if e.is_empty():
		if want_db <= SILENT_DB + 1.0:
			return
		var p: AudioStreamPlayer2D = _new_loop_player(id, &"Ambience")
		if p == null:
			return
		p.volume_db = want_db - 18.0
		e = {"p": p, "id": id}
		_beds[key] = e
	e["want"] = want_db
	e["at"] = at


func _new_loop_player(id: String, bus: StringName) -> AudioStreamPlayer2D:
	var st: AudioStream = _load(_path(id), true)
	if st == null:
		return null
	var p: = AudioStreamPlayer2D.new()
	p.bus = bus
	p.stream = st
	p.attenuation = 0.0
	p.max_distance = 10000000.0
	p.panning_strength = PAN_STRENGTH
	p.volume_db = SILENT_DB
	var cam: Camera2D = _listener_cam()
	if cam != null:
		p.position = cam.position
	add_child(p)
	var off: float = randf() * maxf(st.get_length() - 0.2, 0.0)
	if is_inside_tree():
		p.play(off)
	else:
		p.play.call_deferred(off)
	return p



func _pan_pos(at: Vector2, cam: Camera2D, edge: float) -> Vector2:
	if cam == null:
		return at if at.is_finite() else Vector2.ZERO
	if not at.is_finite():
		return cam.position
	var half_w: float = cam.get_viewport_rect().size.x * 0.5 / maxf(cam.zoom.x, 0.01)
	var d: Vector2 = at - cam.position
	if d.length() <= half_w * edge:
		return at
	return cam.position + d.normalized() * half_w * edge


func _music(track: String) -> void :
	if track == _track:
		return
	_track = track
	var old: AudioStreamPlayer = _mus[_mus_i]
	if old.playing:
		_fade(old, SILENT_DB, FADE, true, false)
	if track == "":
		return
	var st: AudioStream = _load(MUSIC_PATH % track, true)
	if st == null:
		return
	_mus_i = 1 - _mus_i
	var p: AudioStreamPlayer = _mus[_mus_i]
	p.stop()
	p.stream = st
	p.volume_db = SILENT_DB
	if is_inside_tree():
		p.play()
	else:
		p.play.call_deferred()
	_fade(p, 0.0, FADE, false, false)


func _fade(p: Node, to_db: float, dur: float, stop_after: bool, free_after: bool) -> void :
	var prev: Tween = _tweens.get(p) as Tween
	if prev != null and prev.is_valid():
		prev.kill()
	_tweens.erase(p)
	if not is_inside_tree():
		p.set("volume_db", to_db)
		if free_after:
			p.queue_free()
		elif stop_after:
			p.call("stop")
		return
	var tw: Tween = create_tween()
	tw.tween_property(p, "volume_db", to_db, dur)
	if free_after:
		tw.tween_callback(_drop_player.bind(p))
	elif stop_after:
		tw.tween_callback(Callable(p, "stop"))
	_tweens[p] = tw


func _drop_player(p: Node) -> void :
	_tweens.erase(p)
	p.queue_free()


func _ready() -> void :
	_w_wait.fill(0)
	_f_wait.fill(0)


func _process(delta: float) -> void :
	var cam: Camera2D = _listener_cam()
	_health_t -= delta
	if _health_t <= 0.0:
		_health_t = HEALTH_DT
		_health()
	if _duck > 0.0:
		_duck = maxf(0.0, _duck - DUCK_REC * delta)
		_set_amb_volume(_duck)
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = TICK
		_tick_zoom()
		if scape != null:
			scape.tick(TICK)
	for key: String in _loops:
		var e: Dictionary = _loops[key]
		var p: AudioStreamPlayer2D = e["p"]
		var id: String = String(e["id"])
		var rule: Array = _rule(id, false)
		var at: Vector2 = e["at"]
		var k: float = _dist_k(at)
		var att: float = _dist_db(k, bool(rule[3])) if not FAR_LOOPS.has(id) else _far_loop_db(id, k)
		var want: float = float(e["vol"]) + float(rule[2]) + PAN_COMP_DB + att
		if FOG_LOOPS.has(id) and not _visible(at, AIR_IDS.has(id)):
			want = SILENT_DB
		elif att <= SILENT_DB:
			want = float(LOOP_FLOOR[id]) + float(e["vol"]) + PAN_COMP_DB if LOOP_FLOOR.has(id) and at.is_finite() else SILENT_DB
		var off: bool = not bool(e.get("on", true))
		if off:
			want = SILENT_DB
		p.position = _pan_pos(at, cam, 1.3)
		p.volume_db = move_toward(p.volume_db if is_finite(p.volume_db) else SILENT_DB, want, (LOOP_OFF_SLEW if off else LOOP_SLEW) * delta)
		var mute: bool = p.volume_db <= SILENT_DB + 0.5
		if p.stream_paused != mute:
			p.stream_paused = mute
	for key: String in _beds:
		var b: Dictionary = _beds[key]
		var bp: AudioStreamPlayer2D = b["p"]
		var want_b: float = float(b["want"])
		want_b = SILENT_DB if want_b <= SILENT_DB + 1.0 else want_b + float(_rule(String(b["id"]), false)[2]) + PAN_COMP_DB
		bp.position = _pan_pos(b["at"], cam, 0.9)
		bp.volume_db = move_toward(bp.volume_db, want_b, BED_SLEW * delta)
		var bm: bool = bp.volume_db <= SILENT_DB + 0.5
		if bp.stream_paused != bm:
			bp.stream_paused = bm



func _far_loop_db(id: String, k: float) -> float:
	var r: Array = FAR_LOOPS[id]
	if k < 0.0 or k >= float(r[1]):
		return SILENT_DB
	var t: float = clampf((k - float(r[0])) / (float(r[1]) - float(r[0])), 0.0, 1.0)
	return lerpf(float(FAR_LOOP_DB[0]), float(FAR_LOOP_DB[1]), t)



func _tick_zoom() -> void :
	var z: float = snappedf(_cam_zoom(), 0.05)
	if z == _zoom_cut:
		return
	_zoom_cut = z
	var f: float = clampf((1.0 - z) / 0.75, 0.0, 1.0)
	var fi: int = _bus("SFX_Far")
	var lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(fi, 0) as AudioEffectLowPassFilter
	if lp != null:
		lp.cutoff_hz = lerpf(2600.0, 900.0, f)
	var ai: int = _bus("Ambience")
	var la: AudioEffectLowPassFilter = AudioServer.get_bus_effect(ai, 0) as AudioEffectLowPassFilter
	if la != null:
		la.cutoff_hz = lerpf(12000.0, 2400.0, f)
		AudioServer.set_bus_effect_enabled(ai, 0, f > 0.01)






func _notification(what: int) -> void :
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_focus_ms = Time.get_ticks_msec()
		_dead_told = false
		if is_inside_tree():
			recover()



func recover() -> void :
	var now: int = Time.get_ticks_msec()
	if now - _recover_ms < 500:
		return
	_recover_ms = now
	counts["recovered"] = int(counts["recovered"]) + 1
	_duck = 0.0
	_reset_bus_fx()
	_apply_bus_volumes()
	_zoom_cut = -1.0
	_tick_t = 0.0
	for i in VOICES_WORLD:
		_wv[i].stop()
		_w_wait[i] = 0
	for i in VOICES_FLAT:
		_fv[i].stop()
		_f_wait[i] = 0
	_last.clear()
	_cat_win.clear()
	for dct: Dictionary in [_loops, _beds]:
		for key: String in dct:
			var p: AudioStreamPlayer2D = dct[key]["p"]
			if not is_instance_valid(p) or p.stream == null:
				continue
			if not is_finite(p.volume_db):
				p.volume_db = SILENT_DB
			if not p.playing and p.is_inside_tree():
				p.play(randf() * maxf(p.stream.get_length() - 0.2, 0.0))
	var mp: AudioStreamPlayer = _mus[_mus_i]
	if _track != "" and mp.stream != null and not mp.playing and mp.is_inside_tree():
		mp.volume_db = SILENT_DB
		mp.play()
		_fade(mp, 0.0, FADE, false, false)




static func _reset_bus_fx() -> void :
	for nm: String in ["SFX", "SFX_Far", "Ambience"]:
		var bi: int = AudioServer.get_bus_index(nm)
		if bi < 0:
			continue
		for ei in range(AudioServer.get_bus_effect_count(bi) - 1, -1, -1):
			var fx: AudioEffect = AudioServer.get_bus_effect(bi, ei)
			var en: bool = AudioServer.is_bus_effect_enabled(bi, ei)
			AudioServer.remove_bus_effect(bi, ei)
			AudioServer.add_bus_effect(bi, fx, ei)
			AudioServer.set_bus_effect_enabled(bi, ei, en)




func _health() -> void :
	var bad: bool = not is_finite(_duck) or not is_finite(sfx_volume) or not is_finite(music_volume) or not is_finite(ambience_volume)
	if bad:
		_duck = 0.0 if not is_finite(_duck) else _duck
		sfx_volume = 0.8 if not is_finite(sfx_volume) else sfx_volume
		music_volume = 0.5 if not is_finite(music_volume) else music_volume
		ambience_volume = 0.8 if not is_finite(ambience_volume) else ambience_volume
	for nm: String in ["Master", "SFX", "SFX_Far", "Ambience", "UI", "Music"]:
		var bi: int = AudioServer.get_bus_index(nm)
		if bi < 0:
			continue
		if not is_finite(AudioServer.get_bus_volume_db(bi)):
			bad = true
			if bi == 0:
				AudioServer.set_bus_volume_db(0, 0.0)
		if (bi == 0 or nm == "SFX_Far") and AudioServer.is_bus_mute(bi):
			bad = true
			AudioServer.set_bus_mute(bi, false)
	if AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")) != (sfx_volume < 0.001):
		bad = true
	for c: Node in get_children():
		if not is_finite(float(c.get("volume_db"))):
			bad = true
			c.set("volume_db", SILENT_DB)
	if bad:
		counts["bad_vol"] = int(counts["bad_vol"]) + 1
		_apply_bus_volumes()
	if (OS.has_feature("ios") or debug_force_dead) and Time.get_ticks_msec() - _focus_ms > 3000:
		var since: float = 99.0 if debug_force_dead else AudioServer.get_time_since_last_mix()
		if since > DEAD_MIX_S:
			counts["dead_mix"] = int(counts["dead_mix"]) + 1
			if not _dead_told:
				_dead_told = true
				print("Sfx: the audio driver has not mixed for %.1f s while focused (iOS session interruption)" % since)
				if scape != null and is_instance_valid(scape.gw):
					scape.gw.message.emit(Loc.msg(Loc.mk("Звук прерван: сверните игру и вернитесь")))
		else:
			_dead_told = false


func _debug_state() -> Dictionary:
	var wv: Array = []
	for i in VOICES_WORLD:
		if _wv[i].playing:
			wv.append("%s@%.1f%s" % [_w_id[i], _w_k[i], "~" if String(_wv[i].bus) == "SFX_Far" else ""])
	var fv: Array = []
	for i in VOICES_FLAT:
		if _fv[i].playing:
			fv.append(_f_id[i])
	var lp: Dictionary = {}
	var audible: int = wv.size() + fv.size()
	for key: String in _loops:
		var p: AudioStreamPlayer2D = _loops[key]["p"]
		if not p.stream_paused and p.volume_db > SILENT_DB + 0.5:
			lp[key] = snappedf(p.volume_db, 0.1)
			audible += 1 if p.volume_db > -35.0 else 0
	var bd: Dictionary = {}
	for key: String in _beds:
		var bp: AudioStreamPlayer2D = _beds[key]["p"]
		if not bp.stream_paused and bp.volume_db > SILENT_DB + 0.5:
			bd[key] = snappedf(bp.volume_db, 0.1)
			audible += 1 if bp.volume_db > -35.0 else 0
	var buses: Dictionary = {}
	for nm: String in ["Master", "SFX", "SFX_Far", "Ambience", "UI", "Music"]:
		var bi: int = AudioServer.get_bus_index(nm)
		if bi >= 0:
			buses[nm] = [snappedf(AudioServer.get_bus_volume_db(bi), 0.1), snappedf(maxf(AudioServer.get_bus_peak_volume_left_db(bi, 0), AudioServer.get_bus_peak_volume_right_db(bi, 0)), 0.1)]
	var out: Dictionary = {"world": wv, "flat": fv, "loops": lp, "beds": bd, "voices": wv.size() + fv.size() + lp.size() + bd.size(), "audible": audible, 
		"buses": buses, "duck": snappedf(_duck, 0.1), "counts": counts.duplicate()}
	if scape != null:
		out["scape"] = scape.state()
	return out
