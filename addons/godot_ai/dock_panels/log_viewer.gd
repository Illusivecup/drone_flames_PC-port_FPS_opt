@tool
extends VBoxContainer









signal logging_enabled_changed(enabled: bool)

const Dock: = preload("res://addons/godot_ai/mcp_dock.gd")
const Settings: = preload("res://addons/godot_ai/utils/settings.gd")

var _log_display: RichTextLabel
var _log_toggle: CheckButton




var _last_log_seq: = 0









func setup() -> void :
	if _log_display == null:
		_build_ui()


func _build_ui() -> void :
	add_child(HSeparator.new())

	var log_header_row: = HBoxContainer.new()
	var log_header: = Dock._make_header("MCP Log")
	log_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_header_row.add_child(log_header)

	_log_toggle = CheckButton.new()
	_log_toggle.text = "Log"


	_log_toggle.button_pressed = Settings.mcp_logging_enabled()
	_log_toggle.toggled.connect(_on_log_toggled)
	log_header_row.add_child(_log_toggle)

	add_child(log_header_row)

	_log_display = RichTextLabel.new()
	_log_display.custom_minimum_size = Vector2(0, 80)
	_log_display.scroll_following = true
	_log_display.bbcode_enabled = false
	_log_display.selection_enabled = true
	_log_display.visible = _log_toggle.button_pressed
	add_child(_log_display)


func sequence() -> int:
	return _last_log_seq


func present_snapshot(snapshot: Dictionary) -> void :
	if _log_display == null:
		return
	var seq: = int(snapshot.get("sequence", _last_log_seq))
	if bool(snapshot.get("reset", false)) or seq < _last_log_seq:
		_log_display.clear()
		_last_log_seq = 0
	var lines: Array[String] = []
	lines.assign(snapshot.get("lines", []))
	for line in lines:
		_log_display.add_text(line + "\n")
	_last_log_seq = seq


func _on_log_toggled(enabled: bool) -> void :
	Settings.set_mcp_logging_enabled(enabled)
	_log_display.visible = enabled
	logging_enabled_changed.emit(enabled)
