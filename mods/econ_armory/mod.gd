extends RefCounted

var mm_ref: Node = null
var main_ref: Node = null
var panel: PanelContainer = null
var rows: VBoxContainer = null

func init_mod(mm: Node) -> void:
	mm_ref = mm
	if mm.has_method("register_hook"):
		mm.call("register_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("register_hook", "on_match_tick", Callable(self, "_on_match_tick"))

func cleanup_mod(mm: Node) -> void:
	if main_ref != null and is_instance_valid(main_ref) and main_ref.hud != null and mm != null and mm.has_method("cleanup_mod_hud"):
		mm.call("cleanup_mod_hud", main_ref.hud, Callable(self, "_on_hud_action"), ["econ_armory_open"])
	if is_instance_valid(panel):
		panel.queue_free()
	panel = null
	rows = null
	main_ref = null
	if mm != null and mm.has_method("unregister_hook"):
		mm.call("unregister_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("unregister_hook", "on_match_tick", Callable(self, "_on_match_tick"))

func _ensure_hud(main: Node) -> void:
	if main == null or not is_instance_valid(main):
		return
	main_ref = main
	if main.hud == null:
		return
	if main.hud.pages.size() > 5 and not main.hud.keys.has("econ_armory_open"):
		var cell: Control = main.hud._cell("econ_armory_open", "icon_upgrade", false)
		if main.hud.key_labels.has("econ_armory_open"):
			main.hud.key_labels["econ_armory_open"].text = "ЦЕНТР\nУЛУЧШЕНИЙ"
		main.hud.pages[5].add_child(cell)
	if not main.hud.action.is_connected(_on_hud_action):
		main.hud.action.connect(_on_hud_action)

func _on_world_started(main: Node, _world: Node) -> void:
	_ensure_hud(main)

func _on_match_tick(main: Node, _world: Node, _delta: float) -> void:
	if main_ref == null or main == null or main.hud == null or not main.hud.keys.has("econ_armory_open"):
		_ensure_hud(main)

func _on_hud_action(action: String) -> void:
	if action == "econ_armory_open":
		open()

func open() -> void:
	if main_ref == null or not is_instance_valid(main_ref) or main_ref.world == null:
		return
	if not is_instance_valid(panel):
		_build_panel()
	panel.visible = true
	panel.position = (main_ref.hud.root.size - panel.size) * 0.5
	_refresh()

func close() -> void:
	if is_instance_valid(panel):
		panel.visible = false

func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "EconArmoryPanel"
	panel.custom_minimum_size = Vector2(620, 460)
	panel.size = Vector2(620, 460)
	panel.z_index = 120
	panel.add_theme_stylebox_override("panel", UiKit.sb("wb_panel", 8, 4))
	main_ref.hud.root.add_child(panel)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var head: HBoxContainer = HBoxContainer.new()
	body.add_child(head)
	var title: Label = UiKit.title("ЦЕНТР УЛУЧШЕНИЙ", 17)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x: Button = UiKit.close_btn(40.0)
	x.pressed.connect(close)
	head.add_child(x)
	var hint: Label = UiKit.lbl("Промышленные уровни и готовность истребителей", 10, UiKit.MUTED, 1, 1)
	body.add_child(hint)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)

func _refresh() -> void:
	if main_ref == null or not is_instance_valid(rows):
		return
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var world: GameWorld = main_ref.world
	var country: Country = world.player
	if country == null:
		return
	var count: int = 0
	for facility: Facility in world.mil.facilities:
		if facility.country_id != country.id or not world.econ.can_upgrade(facility):
			continue
		_add_row("%s · уровень %d" % [Military.title_of(facility.kind), facility.level], Economy.cost_text(world.econ.upgrade_cost(facility)), Callable(self, "_upgrade_facility").bind(facility.id))
		count += 1
	for aircraft: Aircraft in world.mil.air.aircraft:
		if aircraft.country_id != country.id or aircraft.type != Aircraft.Type.FIGHTER or aircraft.level >= 3 or aircraft.state != Aircraft.State.PARKED:
			continue
		_add_row("Истребитель №%d · уровень %d→%d" % [aircraft.id, aircraft.level, aircraft.level + 1], "%d $" % Air.UPGRADE_COST, Callable(self, "_upgrade_aircraft").bind(aircraft.id))
		count += 1
	if count == 0:
		rows.add_child(UiKit.lbl("Сейчас нет доступных улучшений.", 12, UiKit.MUTED, 1, 1))

func _add_row(title: String, cost: String, callback: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	rows.add_child(row)
	var label: Label = UiKit.lbl(title, 11, UiKit.TEXT, 2, 1)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(UiKit.lbl(cost, 10, UiKit.GOLD, 2, 1))
	var button: Button = UiKit.big("УЛУЧШИТЬ", "green", "", 38.0, 10)
	button.pressed.connect(callback)
	row.add_child(button)

func _upgrade_facility(facility_id: int) -> void:
	if main_ref == null or not is_instance_valid(main_ref):
		return
	var target: Facility = null
	for facility: Facility in main_ref.world.mil.facilities:
		if facility.id == facility_id:
			target = facility
			break
	if target == null:
		return
	var country: Country = main_ref.world.player
	main_ref._sim("econ", "upgrade", [target, country], func(result: Variant) -> void:
		var why: String = String(result) if result is String else ""
		main_ref.hud.show_toast(why if why != "" else "Улучшение завершено")
		_refresh())

func _upgrade_aircraft(aircraft_id: int) -> void:
	if main_ref == null or not is_instance_valid(main_ref):
		return
	var target: Aircraft = null
	for aircraft: Aircraft in main_ref.world.mil.air.aircraft:
		if aircraft.id == aircraft_id and aircraft.country_id == main_ref.world.player.id:
			target = aircraft
			break
	if target == null:
		return
	var country: Country = main_ref.world.player
	main_ref._sim("mil.air", "upgrade", [target, country], func(result: Variant) -> void:
		var why: String = String(result) if result is String else ""
		main_ref.hud.show_toast(why if why != "" else "Вооружение и характеристики истребителя улучшены")
		_refresh())
