extends RefCounted
## Модификация «Карта: Зона Отчуждения (ЧАЭС)»
## Автор: @CryptoAngelazaz & Community
## Уникальный тип карты с реакторной зоной, Рыжим лесом, руинами и кратерами

var _mod_id: String = "chernobyl_zone"
var _map_type_id: String = "chernobyl_zone"

func init_mod(mod_mgr: Node) -> void:
	print("[ChernobylMod] Initializing Chernobyl Exclusion Zone Map Mod...")
	if mod_mgr.has_method("register_map_type"):
		mod_mgr.call("register_map_type", {
			"id": _map_type_id,
			"name": "ЧАЭС: ЗОНА",
			"hint": "Зона Отчуждения: саркофаг ЧАЭС в центре, Рыжий лес, кратеры, руины заводов и залежи урана",
			"icon": "map_t_pangaea",
			"land_percent": 74,
			"generator": Callable(self, "_generate_chernobyl_map")
		})
	print("[ChernobylMod] Map 'ЧАЭС: ЗОНА' registered successfully!")

func cleanup_mod(mod_mgr: Node) -> void:
	print("[ChernobylMod] Cleaning up Chernobyl Map Mod...")
	if mod_mgr.has_method("unregister_map_type"):
		mod_mgr.call("unregister_map_type", _map_type_id)

func _generate_chernobyl_map(world_data: RefCounted, _s: Resource) -> void:
	print("[ChernobylMod] Generating Chernobyl Exclusion Zone terrain...")
	if world_data == null:
		return
	var w: int = int(world_data.get("w"))
	var h: int = int(world_data.get("h"))
	var n: int = w * h
	var biomes: PackedByteArray = world_data.get("biome")
	if biomes.size() != n:
		return

	var sd: int = int(world_data.get("world_seed"))
	var rng: = Rng.new(sd + 19860426) # Дата аварии на ЧАЭС

	var cx: int = w / 2
	var cy: int = h / 2

	for y in h:
		for x in w:
			var i: int = y * w + x
			var b: int = biomes[i]
			
			var dx: float = float(x - cx)
			var dy: float = float(y - cy)
			var dist_center: float = sqrt(dx * dx + dy * dy)

			# 1. Центральный эпицентр: ЧАЭС и 4-й энергоблок (радиус 0..8 клеток)
			if dist_center <= 8.0:
				if dist_center <= 3.0:
					# Сердцевина реактора — кратер и саркофаг
					biomes[i] = Biome.CRATER if (x + y) % 2 == 0 else Biome.BURNT
				elif dist_center <= 5.5:
					# Руины машзала и выжженный бетон
					biomes[i] = Biome.INDUSTRIAL if rng.range_i(100) < 60 else Biome.BURNT
				else:
					# Пруд-охладитель и каналы вокруг станции
					if (x == cx or y == cy or rng.range_i(100) < 35):
						biomes[i] = Biome.SHALLOW
					else:
						biomes[i] = Biome.BURNT
				continue

			# 2. Водоёмы вне центра не трогаем, если это не болота
			if b <= Biome.RIVER:
				# Водные каналы около зоны превращаются в радиоактивные болота
				if dist_center <= 22.0 and rng.range_i(100) < 40:
					biomes[i] = Biome.SHALLOW
				continue

			# 3. Ближнее кольцо: «Рыжий Лес» (радиус 8..20 клеток)
			if dist_center <= 20.0:
				var roll_forest: int = rng.range_i(100)
				if roll_forest < 45:
					biomes[i] = Biome.PINE # Мёртвый рыжий хвойный лес
				elif roll_forest < 70:
					biomes[i] = Biome.BURNT # Выжженная радиоактивная полоса
				elif roll_forest < 85:
					biomes[i] = Biome.CRATER # Аномальные воронки
				else:
					biomes[i] = Biome.STEPPE # Пустошь
				continue

			# 4. Среднее кольцо: Руины Припяти и РЛС «Дуга» (радиус 20..35 клеток)
			if dist_center <= 35.0:
				# Город-призрак и индустриальные объекты
				var roll_city: int = rng.range_i(100)
				if roll_city < 18:
					biomes[i] = Biome.INDUSTRIAL # Заброшенные заводы «Юпитер» и станции
				elif roll_city < 24:
					biomes[i] = Biome.ROAD # Бетонки и подъездные пути
				elif roll_city < 50:
					biomes[i] = Biome.FOREST if rng.range_i(100) < 50 else Biome.PINE # Одичавшая природа
				elif roll_city < 65:
					biomes[i] = Biome.BURNT # Радиационные очаги (пятна Цезия/Стронция)
				continue

			# 5. Периметр Зоны: КПП, скалы, холмы и бункеры
			var roll_outer: int = rng.range_i(100)
			if b == Biome.SAND:
				biomes[i] = Biome.STEPPE if roll_outer < 70 else Biome.BURNT
			elif b == Biome.GRASS:
				if roll_outer < 35:
					biomes[i] = Biome.STEPPE # Пожухлая трава
				elif roll_outer < 55:
					biomes[i] = Biome.PINE
				elif roll_outer < 60:
					biomes[i] = Biome.CRATER # Старые испытательные воронки
			elif b == Biome.ROCK or b == Biome.HILLS:
				# Укреплённые каньоны и военные командные пункты
				if roll_outer < 25:
					biomes[i] = Biome.INDUSTRIAL

	world_data.set("biome", biomes)
	print("[ChernobylMod] Chernobyl Exclusion Zone terrain generation complete!")
