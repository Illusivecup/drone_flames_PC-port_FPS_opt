@tool
extends VBoxContainer














const ClientConfigurator: = preload("res://addons/godot_ai/client_configurator.gd")
const PortResolver: = preload("res://addons/godot_ai/utils/port_resolver.gd")

signal port_apply_requested(new_http_port: int, new_ws_port: int)

var _spinbox: SpinBox
var _ws_spinbox: SpinBox

var port_in_use_probe: Callable = Callable(PortResolver, "is_port_in_use")









func setup() -> void :
	if _spinbox == null:
		_build_ui()


func _build_ui() -> void :
	add_theme_constant_override("separation", 4)
	visible = false

	var picker_row: = HBoxContainer.new()
	picker_row.add_theme_constant_override("separation", 6)

	_spinbox = _port_spinbox(ClientConfigurator.http_port(), "Effective HTTP port")
	picker_row.add_child(_spinbox)
	_ws_spinbox = _port_spinbox(ClientConfigurator.ws_port(), "Effective WebSocket port")
	picker_row.add_child(_ws_spinbox)

	var apply_btn: = Button.new()
	apply_btn.text = "Apply + Reload"
	apply_btn.tooltip_text = (
		"Saves the effective HTTP and WebSocket ports to Editor Settings and reloads"
		+ " the plugin so the server spawns on the new ports. Reconfigure your AI"
		+ " clients afterwards so their bridges use the new ports."
	)
	apply_btn.pressed.connect(_on_apply_pressed)
	picker_row.add_child(apply_btn)

	add_child(picker_row)


static func _port_spinbox(value: int, tooltip: String) -> SpinBox:
	var spinbox: = SpinBox.new()
	spinbox.min_value = ClientConfigurator.MIN_PORT
	spinbox.max_value = ClientConfigurator.MAX_PORT
	spinbox.step = 1
	spinbox.value = value
	spinbox.tooltip_text = tooltip
	spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spinbox









func seed_suggested_ports(conflict_port: = 0, occupancy: Dictionary = {}) -> void :
	if _spinbox == null:
		return
	if OS.get_name() == "Windows" and occupancy.is_empty():
		occupancy = PortResolver.windows_listener_snapshot()
	var http: = ClientConfigurator.http_port()
	var ws: = ClientConfigurator.ws_port()
	var http_occupied: bool
	var ws_occupied: bool
	if OS.get_name() == "Windows":
		http_occupied = PortResolver.windows_port_occupancy(http, occupancy) != PortResolver.PortOccupancy.FREE
		ws_occupied = PortResolver.windows_port_occupancy(ws, occupancy) != PortResolver.PortOccupancy.FREE
	else:
		http_occupied = bool(port_in_use_probe.call(http))
		ws_occupied = bool(port_in_use_probe.call(ws))
	var unavailable: = false
	if conflict_port == http or http_occupied:
		var suggested: = ClientConfigurator.suggest_free_port(http + 1, 2048, occupancy)
		if suggested > 0:
			http = suggested
		else:
			unavailable = true
	if conflict_port == ws or ws == http or ws_occupied:
		var suggested: = ClientConfigurator.suggest_free_port(ws + 1, 2048, occupancy)
		if suggested == http:
			suggested = ClientConfigurator.suggest_free_port(suggested + 1, 2048, occupancy)
		if suggested > 0:
			ws = suggested
		else:
			unavailable = true
	var detail: = "Automatic port selection is unavailable. Choose ports manually or retry." if unavailable else ""
	_spinbox.tooltip_text = detail if unavailable else "Effective HTTP port"
	_ws_spinbox.tooltip_text = detail if unavailable else "Effective WebSocket port"
	_spinbox.value = http
	_ws_spinbox.value = ws


func _on_apply_pressed() -> void :
	var new_http: int = int(_spinbox.value)
	var new_ws: int = int(_ws_spinbox.value)
	for port in [new_http, new_ws]:
		if port < ClientConfigurator.MIN_PORT or port > ClientConfigurator.MAX_PORT:
			return
	if new_http == new_ws:
		return
	port_apply_requested.emit(new_http, new_ws)
