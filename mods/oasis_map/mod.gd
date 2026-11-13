extends RefCounted
## Модификация «Карта: Оазис в Пустыне»
## Автор: @good_boy_irl & @CryptoAngelazaz

var _mod_id: String = "oasis_map"
var _map_type_id: String = "desert_oasis"

func init_mod(mod_mgr: Node) -> void:
	print("[OasisMod] Initializing Desert Oasis Map Mod...")
	if mod_mgr.has_method("register_map_type"):
		mod_mgr.call("register_map_type", {
			"id": _map_type_id,
			"name": "ПУСТЫНЯ",
			"hint": "Бескрайние песчаные дюны, оазисы вокруг озёр и богатая нефть",
			"icon": "map_t_normal",
			"land_percent": 82,
			"generator": Callable(self, "_generate_desert_map")
		})
	print("[OasisMod] Map 'ПУСТЫНЯ' successfully registered!")

func cleanup_mod(mod_mgr: Node) -> void:
	print("[OasisMod] Cleaning up Desert Oasis Map Mod...")
	if mod_mgr.has_method("unregister_map_type"):
		mod_mgr.call("unregister_map_type", _map_type_id)

func _generate_desert_map(world_data: RefCounted, _s: Resource) -> void:
	print("[OasisMod] Generating Desert Oasis terrain...")
	if world_data == null:
		return
	var w: int = int(world_data.get("w"))
	var h: int = int(world_data.get("h"))
	var n: int = w * h
	var biomes: PackedByteArray = world_data.get("biome")
	if biomes.size() != n:
		return

	# Создаем маску воды для нахождения прибрежных оазисов
	var water_mask: PackedByteArray = PackedByteArray()
	water_mask.resize(n)
	for i in n:
		var b: int = biomes[i]
		if b <= Biome.RIVER:
			water_mask[i] = 1

	var sd: int = int(world_data.get("world_seed"))
	var rng: = Rng.new(sd + 4242)

	# Преобразуем ландшафт в песчаную пустыню с зелеными оазисами
	for y in h:
		for x in w:
			var i: int = y * w + x
			var b: int = biomes[i]
			if b <= Biome.RIVER:
				continue

			# Проверяем радиус до воды для создания оазиса
			var near_water: bool = false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var qx: int = x + dx
					var qy: int = y + dy
					if qx >= 0 and qx < w and qy >= 0 and qy < h:
						if water_mask[qy * w + qx] == 1:
							near_water = true
							break
				if near_water:
					break

			if near_water:
				biomes[i] = Biome.GRASS # Пышный оазис вокруг пресной воды
			elif b == Biome.ROCK or b == Biome.SNOW:
				biomes[i] = Biome.ROCK # Песчаные скалы и каньоны
			elif b == Biome.HILLS:
				biomes[i] = Biome.STEPPE if rng.range_i(100) < 60 else Biome.SAND
			else:
				biomes[i] = Biome.SAND if rng.range_i(100) < 78 else Biome.STEPPE

	world_data.set("biome", biomes)
	print("[OasisMod] Desert terrain generation complete!")
