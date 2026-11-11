class_name KeybindManager
extends RefCounted

const SAVE_PATH: String = "user://keybinds.json"

const ACTIONS: Array = [
	"cam_up",
	"cam_down",
	"cam_left",
	"cam_right",
	"pan_mouse",
	"pause",
	"speed_next",
	"zoom_in",
	"zoom_out",
	"center_capital",
	"open_diplo",
	"open_economy",
	"action_center",
	"top_world",
	"tab_1",
	"tab_2",
	"tab_3",
	"tab_4",
	"tab_5",
	"tab_6",
	"tab_7",
	"build_barracks",
	"build_trench",
	"cancel_action",
]

const ACTION_TITLES: Dictionary = {
	"cam_up": "Камера вверх",
	"cam_down": "Камера вниз",
	"cam_left": "Камера влево",
	"cam_right": "Камера вправо",
	"pan_mouse": "Перетаскивание карты",
	"pause": "Пауза",
	"speed_next": "Следующая скорость",
	"zoom_in": "Приблизить",
	"zoom_out": "Отдалить",
	"center_capital": "К своей столице",
	"open_diplo": "Окно дипломатии",
	"open_economy": "Окно экономики",
	"action_center": "Действие в центре экрана",
	"top_world": "Топ мира",
	"tab_1": "1 • Карта",
	"tab_2": "2 • Здания и города",
	"tab_3": "3 • Удар",
	"tab_4": "4 • ПВО",
	"tab_5": "5 • Армия",
	"tab_6": "6 • Политика",
	"tab_7": "7 • Флот",
	"build_barracks": "Постройка: Казармы",
	"build_trench": "Постройка: Окопы",
	"cancel_action": "Отмена / Снять выбор",
}

const DEFAULTS: Dictionary = {
	"cam_up": {"type": "key", "code": KEY_W, "alt": KEY_UP},
	"cam_down": {"type": "key", "code": KEY_S, "alt": KEY_DOWN},
	"cam_left": {"type": "key", "code": KEY_A, "alt": KEY_LEFT},
	"cam_right": {"type": "key", "code": KEY_D, "alt": KEY_RIGHT},
	"pan_mouse": {"type": "mouse", "code": MOUSE_BUTTON_MIDDLE, "alt": MOUSE_BUTTON_RIGHT},
	"pause": {"type": "key", "code": KEY_P, "alt": KEY_SPACE},
	"speed_next": {"type": "key", "code": KEY_F, "alt": 0},
	"zoom_in": {"type": "key", "code": KEY_EQUAL, "alt": KEY_KP_ADD},
	"zoom_out": {"type": "key", "code": KEY_MINUS, "alt": KEY_KP_SUBTRACT},
	"center_capital": {"type": "key", "code": KEY_HOME, "alt": KEY_R},
	"open_diplo": {"type": "key", "code": KEY_C, "alt": 0},
	"open_economy": {"type": "key", "code": KEY_E, "alt": 0},
	"action_center": {"type": "key", "code": KEY_ENTER, "alt": 0},
	"top_world": {"type": "key", "code": KEY_TAB, "alt": 0},
	"tab_1": {"type": "key", "code": KEY_1, "alt": KEY_KP_1},
	"tab_2": {"type": "key", "code": KEY_2, "alt": KEY_KP_2},
	"tab_3": {"type": "key", "code": KEY_3, "alt": KEY_KP_3},
	"tab_4": {"type": "key", "code": KEY_4, "alt": KEY_KP_4},
	"tab_5": {"type": "key", "code": KEY_5, "alt": KEY_KP_5},
	"tab_6": {"type": "key", "code": KEY_6, "alt": KEY_KP_6},
	"tab_7": {"type": "key", "code": KEY_7, "alt": KEY_KP_7},
	"build_barracks": {"type": "key", "code": KEY_B, "alt": 0},
	"build_trench": {"type": "key", "code": KEY_T, "alt": 0},
	"cancel_action": {"type": "key", "code": KEY_ESCAPE, "alt": 0},
}

static var _bindings: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_load_from_disk()

static func get_bindings() -> Dictionary:
	_ensure_loaded()
	return _bindings

static func get_binding(action: String) -> Dictionary:
	_ensure_loaded()
	if _bindings.has(action):
		return _bindings[action]
	if DEFAULTS.has(action):
		return DEFAULTS[action]
	return {"type": "none", "code": 0, "alt": 0}

static func set_binding(action: String, type: String, code: int) -> void:
	_ensure_loaded()
	var prev_alt: int = 0
	if _bindings.has(action) and _bindings[action].has("alt"):
		prev_alt = int(_bindings[action]["alt"])
	elif DEFAULTS.has(action) and DEFAULTS[action].has("alt"):
		prev_alt = int(DEFAULTS[action]["alt"])
	_bindings[action] = {"type": type, "code": code, "alt": prev_alt}
	_save_to_disk()

static func reset_to_defaults() -> void:
	_ensure_loaded()
	_bindings.clear()
	for k: String in DEFAULTS.keys():
		_bindings[k] = DEFAULTS[k].duplicate(true)
	_save_to_disk()

static func get_display_name(action: String) -> String:
	var b: Dictionary = get_binding(action)
	var type: String = String(b.get("type", "none"))
	var code: int = int(b.get("code", 0))
	if type == "mouse":
		match code:
			MOUSE_BUTTON_LEFT:
				return "Левая кнопка мыши"
			MOUSE_BUTTON_RIGHT:
				return "Правая кнопка мыши"
			MOUSE_BUTTON_MIDDLE:
				return "Средняя кнопка мыши"
			MOUSE_BUTTON_WHEEL_UP:
				return "Колесо мыши вверх"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Колесо мыши вниз"
			_:
				return "Кнопка мыши %d" % code
	elif type == "key":
		match code:
			KEY_SPACE:
				return "Пробел"
			KEY_TAB:
				return "Tab"
			KEY_ESCAPE:
				return "Esc"
			KEY_ENTER:
				return "Enter"
			KEY_HOME:
				return "Home"
			KEY_END:
				return "End"
			KEY_PAGEUP:
				return "PageUp"
			KEY_PAGEDOWN:
				return "PageDown"
			KEY_UP:
				return "Стрелка вверх"
			KEY_DOWN:
				return "Стрелка вниз"
			KEY_LEFT:
				return "Стрелка влево"
			KEY_RIGHT:
				return "Стрелка вправо"
			KEY_EQUAL:
				return "= / +"
			KEY_MINUS:
				return "-"
			KEY_KP_ADD:
				return "Num +"
			KEY_KP_SUBTRACT:
				return "Num -"
			_:
				var s: String = OS.get_keycode_string(code)
				return s if s != "" else str(code)
	return "—"

static func is_action_pressed(action: String) -> bool:
	_ensure_loaded()
	var b: Dictionary = get_binding(action)
	var type: String = String(b.get("type", "none"))
	var code: int = int(b.get("code", 0))
	var alt: int = int(b.get("alt", 0))
	if type == "key":
		if code > 0 and (Input.is_key_pressed(code) or Input.is_physical_key_pressed(code)):
			return true
		if alt > 0 and (Input.is_key_pressed(alt) or Input.is_physical_key_pressed(alt)):
			return true
	elif type == "mouse":
		if code > 0 and Input.is_mouse_button_pressed(code):
			return true
		if alt > 0 and Input.is_mouse_button_pressed(alt):
			return true
	return false

static func is_event_match(event: InputEvent, action: String) -> bool:
	_ensure_loaded()
	var b: Dictionary = get_binding(action)
	var type: String = String(b.get("type", "none"))
	var code: int = int(b.get("code", 0))
	var alt: int = int(b.get("alt", 0))
	if event is InputEventKey:
		var ek: InputEventKey = event as InputEventKey
		if type == "key":
			if code > 0 and (ek.keycode == code or ek.physical_keycode == code):
				return true
			if alt > 0 and (ek.keycode == alt or ek.physical_keycode == alt):
				return true
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if type == "mouse":
			if code > 0 and mb.button_index == code:
				return true
			if alt > 0 and mb.button_index == alt:
				return true
	return false

static func _save_to_disk() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_bindings, "  "))
	f.close()

static func _load_from_disk() -> void:
	_bindings.clear()
	for k: String in DEFAULTS.keys():
		_bindings[k] = DEFAULTS[k].duplicate(true)
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var txt: String = f.get_as_text()
	f.close()
	var json: Variant = JSON.parse_string(txt)
	if json is Dictionary:
		var d: Dictionary = json as Dictionary
		for k: String in d.keys():
			if DEFAULTS.has(k) and d[k] is Dictionary:
				_bindings[k] = d[k]
