extends RefCounted

## Мод «Расширение и развитие городов» для DroneFlames Reborn
## Полная интеграция в оригинальный интерфейс и движок игры.
## Встраивается в карточку любого города игрока (Show City Card) и во вкладку «ГОРОД» нижней панели.
## Позволяет вручную инвестировать бюджет в расширение городских территорий,
## возведение новых жилых кварталов (с нативными спрайтами домов house_a..d),
## усиление гарнизона, ремонт разрушений и модернизацию инфраструктуры со светом.

var mm_ref: Node = null
var main_ref: Node = null
var world_ref: Node = null

var selected_city: City = null
var last_ops_key: String = ""

func init_mod(mm: Node) -> void:
	mm_ref = mm
	if mm.has_method("register_hook"):
		mm.call("register_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("register_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[CityExpansion] Native mod initialized.")

func cleanup_mod(mm: Node) -> void:
	if main_ref != null and is_instance_valid(main_ref) and main_ref.hud != null and mm != null and mm.has_method("cleanup_mod_hud"):
		mm.call("cleanup_mod_hud", main_ref.hud, Callable(self, "_on_hud_action"), ["city_expand_tool"])
	selected_city = null
	last_ops_key = ""
	if mm and mm.has_method("unregister_hook"):
		mm.call("unregister_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("unregister_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[CityExpansion] Mod cleaned up.")

func _ensure_hud(main: Node, world: Node) -> void:
	if main == null or not is_instance_valid(main) or world == null or not is_instance_valid(world):
		return
	main_ref = main
	world_ref = world

	# 1. Встраивание слота развития во вкладку «ГОРОД / ЭКОНОМИКА» (Tab 2) нижней панели
	if main.hud != null and main.hud.pages.size() > 2:
		var city_grid = main.hud.pages[2] as GridContainer
		if city_grid != null and not main.hud.keys.has("city_expand_tool"):
			var cell = main.hud._cell("city_expand_tool", "icon_upgrade", true)
			if main.hud.key_labels.has("city_expand_tool"):
				var lbl = main.hud.key_labels["city_expand_tool"] as Label
				if lbl != null:
					lbl.text = "РАЗВИТИЕ\nГОРОДОВ"
			city_grid.add_child(cell)
			city_grid.move_child(cell, 2)

		if not main.hud.action.is_connected(_on_hud_action):
			main.hud.action.connect(_on_hud_action)

func _on_world_started(main: Node, world: Node) -> void:
	selected_city = null
	last_ops_key = ""
	_ensure_hud(main, world)
	print("[CityExpansion] Injected city_expand_tool cell into City tab.")

func _on_hud_action(nm: String) -> void:
	match nm:
		"city_expand_tool":
			if main_ref != null and main_ref.hud != null:
				main_ref.hud.show_tip(
					"Развитие и рост городов",
					"Выберите любой город своей страны на карте для инвестиций в новые кварталы, расширение границ и ремонт инфраструктуры.",
					""
				)
				# Если уже есть выбранный город, сразу открываем его
				if selected_city != null:
					main_ref.hud.show_city(selected_city)
				elif world_ref != null and world_ref.player != null and world_ref.player.capital_id >= 0:
					var cap: City = world_ref.cities[world_ref.player.capital_id]
					if cap != null:
						selected_city = cap
						main_ref.hud.show_city(cap)
			if ClassDB.class_exists("UiKit"):
				UiKit.snd("ui_click")

		"city_expand_claim":
			if selected_city != null:
				_execute_city_expand(selected_city)

		"city_upgrade_infra":
			if selected_city != null:
				_execute_city_infra(selected_city)

func _on_match_tick(main: Node, world: Node, _delta: float) -> void:
	main_ref = main
	world_ref = world

	if main == null or main.hud == null or world == null:
		return
	if not main.hud.keys.has("city_expand_tool"):
		_ensure_hud(main, world)

	var time_scale: float = 1.0
	if "time_scale" in world:
		time_scale = maxf(0.0, float(world.time_scale))
	var sim_delta: float = _delta * time_scale

	if world.player != null and sim_delta > 0.0:
		for city: City in world.cities:
			if city != null and city.country_id == world.player.id:
				_update_population(city, sim_delta)

	var ops_k = String(main.hud._ops_key)
	if ops_k.begins_with("city"):
		var cid_str = ops_k.substr(4)
		if cid_str.is_valid_int():
			var cid = cid_str.to_int()
			if cid >= 0 and cid < world.cities.size():
				var c: City = world.cities[cid]
				if c != null and world.player != null and c.country_id == world.player.id:
					selected_city = c
					_enhance_city_card(c)
					last_ops_key = ops_k
					return

	if selected_city != null and not ops_k.begins_with("city"):
		selected_city = null
		last_ops_key = ""

func _enhance_city_card(c: City) -> void:
	if main_ref == null or main_ref.hud == null or world_ref == null or world_ref.player == null:
		return
	var h = main_ref.hud
	var p = world_ref.player

	var exp_cost: int = 300 + c.level * 220
	var inf_cost: int = 200 + c.level * 140

	# 1. Обогащение текста описания города
	var light_status = "СВЕТ ЕСТЬ" if c.powered else "ОТКЛЮЧЕН (БЛЭКАУТ)"
	var sub_info = Loc.t("УРОВЕНЬ %d · %s\nГАРНИЗОН: %d/%d · КВАРТАЛОВ: %d · РАДИУС: %d") % [
		c.level,
		light_status,
		int(c.garrison),
		int(c.garrison_max),
		c.buildings,
		c.radius
	]
	sub_info += Loc.t("\nЖИТЕЛИ: %d / %d") % [c.residents, c.housing_capacity]
	h.ops_sub.visible = true
	h.ops_sub.text = sub_info

	# 2. Добавление нативных действий в карточку города
	var acts: Array = [
		h._act("РАСШИРИТЬ\nКВАРТАЛ", "icon_upgrade", "city_expand_claim", p.money >= exp_cost, 0, "%d $" % exp_cost),
		h._act("МОДЕРНИЗАЦИЯ\nИ СВЕТ", "icon_civ_factory", "city_upgrade_infra", p.money >= inf_cost, 0, "%d $" % inf_cost),
		h._act("ИЗМЕНИТЬ\nНАЗВАНИЕ", "icon_rename", "city_rename", true)
	]
	h._fill_acts("city_acts_%d" % c.id, acts)

func _execute_city_expand(c: City) -> void:
	if world_ref == null or world_ref.player == null:
		return
	var p = world_ref.player
	var cost: int = 300 + c.level * 220

	if p.money < cost:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает средств! Требуется %d $" % cost)
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	p.money -= cost
	if c.housing_capacity <= 0:
		c.housing_capacity = maxi(1200, c.buildings * 500)
		c.residents = int(float(c.housing_capacity) * 0.6)

	# 1. Повышение параметров города
	c.level += 1
	c.claim_max += 6
	c.radius += 2
	c.garrison_max += 150.0
	c.garrison = c.garrison_max
	c.claim_done = false
	c.frontier = [Vector3i(c.center.x, c.center.y, 0)]
	c.housing_capacity += (2 + mini(c.level, 3)) * 600
	c.residents = mini(c.housing_capacity, c.residents + 250)

	# 2. Запуск экспансии границ города через оригинальный алгоритм
	if world_ref.has_method("_grow_initial"):
		world_ref._grow_initial(c, 10, 999)

	# 3. Физическое возведение новых жилых домов в расширенной черте города
	_spawn_new_quarters(c, 2 + mini(c.level, 3))

	# 4. Аудио и визуальный отклик
	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_build")
	if ClassDB.class_exists("Sfx"):
		Sfx.play("territory_claim")

	if world_ref.fx != null:
		world_ref.fx.spawn("dust_s", Vector2(c.center * GameWorld.CELL), 10)

	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Город %s расширен до ур. %d! Новые территории присоединены, гарнизон +150." % [c.name, c.level])
		main_ref.hud.show_city(c)


func _update_population(c: City, delta: float) -> void:
	if c.housing_capacity <= 0:
		c.housing_capacity = maxi(1200, c.buildings * 500)
		c.residents = int(float(c.housing_capacity) * 0.6)
	c.population_growth_clock += delta
	if c.population_growth_clock >= 30.0:
		var cycles: int = int(c.population_growth_clock / 30.0)
		c.population_growth_clock = fmod(c.population_growth_clock, 30.0)
		c.residents = mini(c.housing_capacity, c.residents + cycles * 10)

func _execute_city_infra(c: City) -> void:
	if world_ref == null or world_ref.player == null:
		return
	var p = world_ref.player
	var cost: int = 200 + c.level * 140

	if p.money < cost:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает средств! Требуется %d $" % cost)
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	p.money -= cost

	# 1. Восстановление разрушенных зданий в радиусе города
	var repaired_count = 0
	if world_ref.ruins != null:
		var c_center_px = Vector2(c.center * GameWorld.CELL)
		var max_dist_sq = float((c.radius + 6) * GameWorld.CELL) * float((c.radius + 6) * GameWorld.CELL)
		for r in world_ref.ruins:
			var obj_id: int = int(r[0])
			if obj_id >= 0 and obj_id < world_ref.obj_state.size():
				if world_ref.obj_origin(obj_id).distance_squared_to(c_center_px) <= max_dist_sq:
					world_ref.obj_state[obj_id] = 0
					repaired_count += 1
		# Очистка отремонтированных из списка руин
		for i in range(world_ref.ruins.size() - 1, -1, -1):
			var oid: int = int(world_ref.ruins[i][0])
			if world_ref.obj_state[oid] == 0:
				world_ref.ruins.remove_at(i)

	# 2. Стабилизация и запуск автономного питания города
	c.powered = true
	c.flicker_until = 0.0
	c.dark_since = -1.0

	# 3. Экономический дивиденд в казну
	var bonus_yield = 100 + c.level * 60
	p.money += bonus_yield

	# 4. Аудио и тост
	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_money")
	if ClassDB.class_exists("Sfx"):
		Sfx.play("repair_work")

	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Инфраструктура %s модернизирована! Отремонтировано зданий: %d, доход +%d $." % [c.name, repaired_count, bonus_yield])
		main_ref.hud.show_city(c)

func _spawn_new_quarters(c: City, count: int) -> void:
	if world_ref == null or world_ref.data == null:
		return
	var d = world_ref.data
	var house_models = ["house_a", "house_b", "house_c", "house_d"]
	var placed = 0

	# Поиск свободных клеток вокруг центра города
	for r in range(3, c.radius + 1):
		if placed >= count:
			break
		for dy in range(-r, r + 1):
			if placed >= count:
				break
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cell = c.center + Vector2i(dx, dy)
				if not d.inside(cell.x, cell.y):
					continue
				if d.get_owner_id(cell.x, cell.y) != c.country_id:
					continue
				var b = d.get_biome(cell.x, cell.y)
				if Biome.is_water(b):
					continue
				if d.has_flag(cell.x, cell.y, WorldData.F_OCCUPIED):
					continue

				# Строим жилой дом
				var spr_name = house_models[randi() % house_models.size()]
				if not world_ref.spr_index.has(spr_name):
					spr_name = "civ_factory"

				var hid = world_ref.add_object(spr_name, cell, GameWorld.KIND_BUILDING)
				if hid >= 0:
					c.buildings += 1
					if ClassDB.class_exists("ArchStyle"):
						ArchStyle.mark(world_ref, hid, c.country_id)
					d.add_flag(cell.x, cell.y, WorldData.F_OCCUPIED | WorldData.F_CITY)
					# Укладка уличного покрытия рядом с домом
					for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var sc = cell + off
						if d.inside(sc.x, sc.y) and not d.has_flag(sc.x, sc.y, WorldData.F_OCCUPIED):
							d.set_biome(sc.x, sc.y, Biome.STREET)
							d.add_flag(sc.x, sc.y, WorldData.F_ROAD)
					placed += 1
					if placed >= count:
						break
