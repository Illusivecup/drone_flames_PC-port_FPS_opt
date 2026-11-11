extends RefCounted
## A small offline map editor, independent of the 0.37 Android workshop.

const TERRAIN_NAMES: Array[String] = ["Обычная", "Пустыня", "Лес", "Снег"]
const TERRAIN_IDS: Array[String] = ["normal", "desert", "forest", "snow"]


static func build(menus: Node, parent: VBoxContainer) -> void:
	var service: Node = menus.get_node_or_null("/root/LocalWorkshop")
	if service == null:
		menus._label(parent, "Мастерская недоступна")
		return
	menus._label(parent, "Создавайте карты и выбирайте их перед новой партией. Это локальный редактор ПК-версии.", 11, UiKit.MUTED)
	var edit_id: String = String(menus.get_meta("local_map_edit", ""))
	var edited: Dictionary = service.get_map(edit_id)
	menus._section(parent, "ИЗМЕНИТЬ КАРТУ" if not edited.is_empty() else "НОВАЯ КАРТА")
	menus._label(parent, "Название", 11, UiKit.TEXT, false)
	var name_field: LineEdit = LineEdit.new()
	name_field.name = "WorkshopMapName"
	name_field.placeholder_text = "Моя карта"
	name_field.max_length = 32
	name_field.text = String(edited.get("name", ""))
	name_field.custom_minimum_size.y = 38
	parent.add_child(name_field)
	menus._label(parent, "Местность", 11, UiKit.TEXT, false)
	var terrain: OptionButton = OptionButton.new()
	terrain.name = "WorkshopTerrain"
	terrain.custom_minimum_size.y = 38
	for terrain_name: String in TERRAIN_NAMES:
		terrain.add_item(terrain_name)
	terrain.select(maxi(0, TERRAIN_IDS.find(String(edited.get("terrain", "normal")))))
	parent.add_child(terrain)
	menus._label(parent, "Суша, %", 11, UiKit.TEXT, false)
	var land: SpinBox = SpinBox.new()
	land.name = "WorkshopLand"
	land.min_value = 15
	land.max_value = 85
	land.step = 5
	land.value = int(edited.get("land", 50))
	land.custom_minimum_size.y = 38
	parent.add_child(land)
	var status: Label = UiKit.lbl(String(menus.get_meta("local_map_message", "")), 11, UiKit.GOLD)
	menus.set_meta("local_map_message", "")
	parent.add_child(status)
	var save: Button = UiKit.big("СОХРАНИТЬ КАРТУ", "green", "", 40.0, 11)
	save.name = "WorkshopSave"
	save.pressed.connect(func() -> void:
		var error: String = service.save_map(edit_id, name_field.text, TERRAIN_IDS[terrain.selected], int(land.value))
		if not error.is_empty():
			status.text = error
			return
		menus.set_meta("local_map_edit", "")
		menus.set_meta("local_map_message", "Карта сохранена. Выберите её в настройках новой игры.")
		menus.call_deferred("show_local_workshop")
	)
	parent.add_child(save)
	if not edited.is_empty():
		var cancel: Button = UiKit.big("ОТМЕНИТЬ ИЗМЕНЕНИЕ", "stone", "", 36.0, 11)
		cancel.pressed.connect(func() -> void:
			menus.set_meta("local_map_edit", "")
			menus.call_deferred("show_local_workshop")
		)
		parent.add_child(cancel)
	menus._section(parent, "СОЗДАННЫЕ КАРТЫ")
	if service.maps.is_empty():
		menus._label(parent, "Пока нет сохранённых карт.", 11, UiKit.MUTED)
	for map_data: Dictionary in service.maps:
		var id: String = String(map_data.id)
		var terrain_index: int = maxi(0, TERRAIN_IDS.find(String(map_data.terrain)))
		menus._label(parent, "%s · %s · суша %d%%" % [String(map_data.name), TERRAIN_NAMES[terrain_index], int(map_data.land)], 11, UiKit.TEXT, false)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		parent.add_child(row)
		var edit: Button = UiKit.big("ИЗМЕНИТЬ", "stone", "", 34.0, 10)
		edit.name = "WorkshopEdit_" + id
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.pressed.connect(func() -> void:
			menus.set_meta("local_map_edit", id)
			menus.call_deferred("show_local_workshop")
		)
		row.add_child(edit)
		var remove: Button = UiKit.big("УДАЛИТЬ", "stone", "", 34.0, 10)
		remove.name = "WorkshopRemove_" + id
		remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		remove.pressed.connect(func() -> void:
			if not remove.has_meta("confirm"):
				remove.set_meta("confirm", true)
				remove.text = "НАЖМИТЕ ЕЩЁ РАЗ"
				return
			if service.remove_map(id):
				menus.set_meta("local_map_edit", "")
				menus.set_meta("local_map_message", "Карта удалена")
				menus.call_deferred("show_local_workshop")
			else:
				status.text = "Не удалось удалить карту"
		)
		row.add_child(remove)
	var back_row: HBoxContainer = menus._bottom_row()
	var back: Button = menus._button(back_row, "НАЗАД К МОДАМ", "stone", "")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func() -> void:
		menus.set_meta("local_map_edit", "")
		menus.show_mods()
	)
