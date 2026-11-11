class_name Palette
extends RefCounted


static var colors: Dictionary = {}


static func ensure_loaded() -> void :
	if not colors.is_empty():
		return
	var f: = FileAccess.open("res://assets/palettes/main_named.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for k: String in d:
		colors[k] = Color.html(String(d[k]))


static func c(name: String) -> Color:
	ensure_loaded()
	return colors.get(name, Color.MAGENTA)
