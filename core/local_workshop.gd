extends Node
## Local map presets for the experimental PC build. This is a separate format
## from the Android 0.37 workshop; it does not use its online service.

const SAVE_PATH: String = "user://local_workshop_maps.json"
const MAX_MAPS: int = 30
const TERRAINS: Array[String] = ["normal", "desert", "forest", "snow"]

var maps: Array[Dictionary] = []
var _registered_ids: Array[String] = []


func _ready() -> void:
	_load_maps()
	_refresh_maps()


func _load_maps() -> void:
	maps.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Мастерская: не удалось открыть список карт")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		push_warning("Мастерская: неверный формат списка карт")
		return
	for item: Variant in parsed:
		if not (item is Dictionary) or maps.size() >= MAX_MAPS:
			continue
		var candidate: Dictionary = item as Dictionary
		var id: String = String(candidate.get("id", ""))
		var title: String = String(candidate.get("name", "")).strip_edges().substr(0, 32)
		var terrain: String = String(candidate.get("terrain", "normal"))
		if not id.begins_with("local_map_") or title.is_empty() or not TERRAINS.has(terrain) or not get_map(id).is_empty():
			continue
		maps.append({"id": id, "name": title, "terrain": terrain, "land": clampi(int(candidate.get("land", 50)), 15, 85)})


func get_map(id: String) -> Dictionary:
	for item: Dictionary in maps:
		if String(item.id) == id:
			return item.duplicate(true)
	return {}


func save_map(id: String, title: String, terrain: String, land: int) -> String:
	title = title.strip_edges().substr(0, 32)
	if title.is_empty():
		return "Введите название карты"
	if not TERRAINS.has(terrain):
		return "Неизвестный тип местности"
	var previous: Array[Dictionary] = maps.duplicate(true)
	var index: int = -1
	for i: int in maps.size():
		if String(maps[i].id) == id and not id.is_empty():
			index = i
			break
	if index < 0:
		if not id.is_empty():
			return "Карта не найдена"
		if maps.size() >= MAX_MAPS:
			return "Можно создать до %d карт" % MAX_MAPS
		id = "local_map_%d_%d" % [Time.get_unix_time_from_system(), randi()]
		maps.append({})
		index = maps.size() - 1
	maps[index] = {"id": id, "name": title, "terrain": terrain, "land": clampi(land, 15, 85)}
	if not _persist():
		maps = previous
		return "Не удалось сохранить карту на диск"
	_refresh_maps()
	return ""


func remove_map(id: String) -> bool:
	var previous: Array[Dictionary] = maps.duplicate(true)
	var index: int = -1
	for i: int in maps.size():
		if String(maps[i].id) == id:
			index = i
			break
	if index < 0:
		return false
	maps.remove_at(index)
	if not _persist():
		maps = previous
		return false
	_refresh_maps()
	return true


func _persist() -> bool:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(maps, "  "))
	var ok: bool = file.get_error() == OK
	file.close()
	return ok


func _refresh_maps() -> void:
	var manager: Node = get_node_or_null("/root/ModManager")
	if manager == null:
		return
	for id: String in _registered_ids:
		manager.unregister_map_type(id)
	_registered_ids.clear()
	for item: Dictionary in maps:
		var id: String = String(item.id)
		var terrain: String = String(item.terrain)
		manager.register_map_type({
			"id": id,
			"name": String(item.name),
			"hint": "Локальная карта · суша %d%%" % int(item.land),
			"icon": "map_t_normal",
			"land_percent": int(item.land),
			"generator": Callable(self, "_generate").bind(terrain)
		})
		_registered_ids.append(id)


func _generate(world: WorldData, _settings: WorldSettings, terrain: String) -> void:
	if terrain == "normal" or world == null:
		return
	var cells: PackedByteArray = world.biome
	for i: int in cells.size():
		var biome: int = cells[i]
		if biome <= Biome.RIVER or biome == Biome.ROCK or biome == Biome.HILLS:
			continue
		var variant: int = posmod(i * 37 + world.world_seed, 10)
		match terrain:
			"desert":
				cells[i] = Biome.STEPPE if variant < 2 else Biome.SAND
			"forest":
				cells[i] = Biome.GRASS if variant < 2 else (Biome.PINE if variant < 4 else Biome.FOREST)
			"snow":
				cells[i] = Biome.PINE if variant < 2 else Biome.SNOW
	world.biome = cells
