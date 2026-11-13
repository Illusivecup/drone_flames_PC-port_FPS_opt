extends RefCounted
## Модификация «Особые сценарии и карты»
## Автор: @good_boy_irl & @CryptoAngelazaz
##
## Возможности:
## - 2 новые уникальные карты: «АРКТИКА» (Ледниковый период) и «ВУЛКАНЫ» (Огненный архипелаг)
## - Интеграция в меню выбора партии: настройка особого исторического сценария
## - 5 сюжетных сценариев на базе скрытых механик мировых событий:
##   1. «РАСКОЛ» (Внезапная гражданская война и распад крупнейшей державы)
##   2. «ХОЛОДНАЯ ВОЙНА» (Раздел мира на два враждующих блока сверхдержав)
##   3. «БОЛЬШАЯ КОАЛИЦИЯ» (Военный альянс стран против мирового лидера)
##   4. «ГОНКА ВООРУЖЕНИЙ» (Ядерное обострение и ускоренное создание ракет)
##   5. «САНКЦИОННАЯ ВОЙНА» (Тотальное торговое эмбарго и санкционная война)

var _mod_id: String = "scenarios_pack"
var _map_arctic_id: String = "arctic_map"
var _map_volcano_id: String = "volcano_map"

const SCENARIO_NAMES: Array = [
	"СТАНДАРТ",
	"РАСКОЛ",
	"ХОЛОДНАЯ ВОЙНА",
	"БОЛЬШАЯ КОАЛИЦИЯ",
	"ГОНКА ВООРУЖЕНИЙ",
	"САНКЦИОННАЯ ВОЙНА"
]

const SCENARIO_HINTS: Array = [
	"Обычный ход истории: случайные события по времени",
	"Внезапный гражданский раскол крупнейшей державы на Север и Юг",
	"Мир раскалывается на два враждующих военно-политических блока",
	"Военный альянс мировых держав объединяется против лидера",
	"Ядерное обострение и ускоренное наращивание ракет державами",
	"Торговая война: закрытие границ, эмбарго и санкции"
]

static var selected_scenario: int = 0
var _scenario_hint_label: Label = null
var _scenario_triggered: bool = false
var _scenario_timer: float = 0.0

var _hook_setup: Callable
var _hook_start: Callable
var _hook_tick: Callable

func init_mod(mod_mgr: Node) -> void:
	print("[ScenariosPack] Initializing Special Scenarios & Maps Mod by @CryptoAngelazaz...")
	
	# Регистрация карты «АРКТИКА»
	if mod_mgr.has_method("register_map_type"):
		mod_mgr.call("register_map_type", {
			"id": _map_arctic_id,
			"name": "АРКТИКА",
			"hint": "Ледниковый период: замерзшие заливы, тундра, нефтяные и титановые шельфы",
			"icon": "map_t_islands",
			"land_percent": 68,
			"generator": Callable(self, "_generate_arctic_map")
		})
		
		# Регистрация карты «ВУЛКАНЫ»
		mod_mgr.call("register_map_type", {
			"id": _map_volcano_id,
			"name": "ВУЛКАНЫ",
			"hint": "Огненный архипелаг: базальтовые скалы, кратерные озёра и залежи урана",
			"icon": "map_t_pangaea",
			"land_percent": 58,
			"generator": Callable(self, "_generate_volcano_map")
		})

	# Регистрация хуков для расширения игры
	if mod_mgr.has_method("register_hook"):
		_hook_setup = Callable(self, "_on_setup_menu")
		_hook_start = Callable(self, "_on_world_started")
		_hook_tick = Callable(self, "_on_match_tick")
		mod_mgr.call("register_hook", "on_setup_menu", _hook_setup)
		mod_mgr.call("register_hook", "on_world_started", _hook_start)
		mod_mgr.call("register_hook", "on_match_tick", _hook_tick)

	print("[ScenariosPack] Mod initialized successfully!")

func cleanup_mod(mod_mgr: Node) -> void:
	print("[ScenariosPack] Cleaning up Special Scenarios & Maps Mod...")
	if mod_mgr.has_method("unregister_map_type"):
		mod_mgr.call("unregister_map_type", _map_arctic_id)
		mod_mgr.call("unregister_map_type", _map_volcano_id)
	if mod_mgr.has_method("unregister_hook"):
		mod_mgr.call("unregister_hook", "on_setup_menu", _hook_setup)
		mod_mgr.call("unregister_hook", "on_world_started", _hook_start)
		mod_mgr.call("unregister_hook", "on_match_tick", _hook_tick)

# ==============================================================================
# ХУКИ ИГРОВОГО ПРОЦЕССА И НАСТРОЙКИ СЦЕНАРИЕВ
# ==============================================================================

func _get_scenario_idx() -> int:
	return selected_scenario

func _on_scenario_selected(i: int) -> void:
	selected_scenario = i
	if _scenario_hint_label != null and is_instance_valid(_scenario_hint_label):
		_scenario_hint_label.text = "★ " + SCENARIO_HINTS[selected_scenario]

func _on_setup_menu(menus: Node, vb: VBoxContainer) -> void:
	if menus == null or vb == null or not is_instance_valid(menus):
		return
	
	if menus.has_method("_selector"):
		menus.call("_selector", vb, "СЦЕНАРИЙ", SCENARIO_NAMES, 
			Callable(self, "_get_scenario_idx"), 
			Callable(self, "_on_scenario_selected"), 
			100.0, "si_scenario")
	
	if menus.has_method("_label"):
		_scenario_hint_label = menus.call("_label", vb, "★ " + SCENARIO_HINTS[selected_scenario], 10, Color(0.95, 0.8, 0.3))

func _on_world_started(_main: Node, _world: Node) -> void:
	_scenario_triggered = false
	_scenario_timer = 0.0

func _on_match_tick(main: Node, world: Node, delta: float) -> void:
	if selected_scenario == 0 or _scenario_triggered:
		return

	var time_scale: float = 1.0
	if world != null and "time_scale" in world:
		time_scale = maxf(0.0, float(world.time_scale))
	var sim_delta: float = delta * time_scale
	if sim_delta <= 0.0:
		return

	_scenario_timer += sim_delta
	if _scenario_timer < 3.0:
		return

	_scenario_triggered = true
	_apply_scenario(main, world, selected_scenario)

func _apply_scenario(main: Node, world: Node, scenario_id: int) -> void:
	if world == null or world.get("drama") == null:
		return
	
	var drama = world.drama
	var diplo = world.get("diplo")
	var hud = main.get("hud")
	var now: float = float(world.get("game_time"))
	
	match scenario_id:
		1: # РАСКОЛ (Civil War / Partition)
			_trigger_partition(main, world, drama, diplo, hud, now)
		2: # ХОЛОДНАЯ ВОЙНА (Cold War / Blocs)
			_trigger_blocs(main, world, drama, diplo, hud, now)
		3: # БОЛЬШАЯ КОАЛИЦИЯ (Coalition)
			_trigger_coalition(main, world, drama, diplo, hud, now)
		4: # ГОНКА ВООРУЖЕНИЙ (Arms Race)
			_trigger_arms(main, world, drama, diplo, hud, now)
		5: # САНКЦИОННАЯ ВОЙНА (Trade War)
			_trigger_trade(main, world, drama, diplo, hud, now)

func _trigger_partition(main: Node, world: Node, drama: Object, diplo: Object, hud: Node, now: float) -> void:
	var target: Country = null
	var bots: Array = []
	for c in world.countries:
		if c != null and not c.is_player and not c.eliminated:
			bots.append(c)
	if bots.is_empty():
		return
	
	bots.sort_custom(func(a, b): return a.city_ids.size() > b.city_ids.size())
	target = bots[0]
	var old_name: String = target.name
	
	# Если у державы мало городов для раскола, создаем второй город
	if target.city_ids.size() < 2:
		var cap_pos: Vector2i = world.cities[target.capital_id].center if target.capital_id >= 0 and target.capital_id < world.cities.size() else Vector2i(world.data.w / 2, world.data.h / 2)
		var offset: Vector2i = Vector2i(24, 18)
		if world.data.inside(cap_pos.x + offset.x, cap_pos.y + offset.y):
			world.found_city(cap_pos + offset, target, City.Kind.TOWN)

	var new_country: Country = null
	if target.city_ids.size() >= 4 and drama.has_method("_partition"):
		var arc: Dictionary = {
			"id": drama.next_id,
			"k": 1, # K.PARTITION
			"a": target.id,
			"b": -1,
			"m": [],
			"side": [],
			"t0": now,
			"p": 0.95,
			"rate": 0.1,
			"life": 1200.0,
			"shown": true,
			"climax": true,
			"hold": 2,
			"data": {"dev": true}
		}
		drama.next_id += 1
		drama.arcs.append(arc)
		drama.call("_partition", arc, now)
		var new_id: int = int(arc.get("b", -1))
		if new_id > 0:
			new_country = world.country_by_id(new_id)
	else:
		# Прямой раскол через new_country_from
		var rebel_cities: Array = [target.city_ids[target.city_ids.size() - 1]]
		new_country = world.new_country_from(rebel_cities)
		if new_country != null:
			target.name = "Северная " + old_name
			new_country.name = "Южная " + old_name
			if diplo:
				var k: String = Diplomacy.key(target.id, new_country.id)
				diplo.opinion[k] = -60
				diplo.close_land(target.id, new_country.id)
				diplo.close_land(new_country.id, target.id)
			var arc2: Dictionary = {
				"id": drama.next_id,
				"k": 1,
				"a": target.id,
				"b": new_country.id,
				"m": [],
				"side": [],
				"t0": now,
				"p": 0.95,
				"rate": 0.1,
				"life": 1200.0,
				"shown": true,
				"climax": true,
				"hold": 2,
				"data": {"old": old_name}
			}
			drama.next_id += 1
			drama.arcs.append(arc2)

	var new_name: String = new_country.name if new_country != null else "Южная " + old_name
	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", "⚡ СЦЕНАРИЙ: РАСКОЛ! %s раскололась на Север и Юг (%s)!" % [old_name, new_name])

func _trigger_blocs(main: Node, world: Node, drama: Object, diplo: Object, hud: Node, now: float) -> void:
	var alive_countries: Array = []
	for c in world.countries:
		if c != null and not c.eliminated:
			alive_countries.append(c)
	if alive_countries.size() < 2:
		return
	
	alive_countries.sort_custom(func(a, b): return a.city_ids.size() > b.city_ids.size())
	var leader1 = alive_countries[0]
	var leader2 = alive_countries[1]
	
	var side_a: Array = [leader1.id]
	var side_b: Array = [leader2.id]
	
	for idx in range(2, alive_countries.size()):
		var c = alive_countries[idx]
		if idx % 2 == 0:
			side_a.append(c.id)
		else:
			side_b.append(c.id)
			
	var arc: Dictionary = {
		"id": drama.next_id,
		"k": 3, # K.BLOCS
		"a": leader1.id,
		"b": leader2.id,
		"m": [],
		"side": [side_a, side_b],
		"t0": now,
		"p": 0.6,
		"rate": 0.15,
		"life": 1800.0,
		"shown": true,
		"climax": false,
		"hold": 0,
		"data": {"blocs": true}
	}
	drama.next_id += 1
	drama.arcs.append(arc)
	
	if diplo:
		var k: String = Diplomacy.key(leader1.id, leader2.id)
		diplo.opinion[k] = -60
		diplo.rivalry_set(leader1.id, leader2.id, true)
	
	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", "⚡ СЦЕНАРИЙ: ХОЛОДНАЯ ВОЙНА! Мир разделён на блоки «%s» и «%s»!" % [leader1.name, leader2.name])

func _trigger_coalition(main: Node, world: Node, drama: Object, diplo: Object, hud: Node, now: float) -> void:
	var alive_countries: Array = []
	for c in world.countries:
		if c != null and not c.eliminated:
			alive_countries.append(c)
	if alive_countries.size() < 2:
		return
	
	alive_countries.sort_custom(func(a, b): return a.city_ids.size() > b.city_ids.size())
	var hegemon = alive_countries[0]
	var members: Array = []
	for idx in range(1, alive_countries.size()):
		members.append(alive_countries[idx].id)
		if diplo:
			var k: String = Diplomacy.key(alive_countries[idx].id, hegemon.id)
			diplo.opinion[k] = -50
	
	var arc: Dictionary = {
		"id": drama.next_id,
		"k": 2, # K.COALITION
		"a": hegemon.id,
		"b": hegemon.id,
		"m": members,
		"side": [],
		"t0": now,
		"p": 0.7,
		"rate": 0.15,
		"life": 1500.0,
		"shown": true,
		"climax": true,
		"hold": 1,
		"data": {"coalition": true}
	}
	drama.next_id += 1
	drama.arcs.append(arc)
	
	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", "⚡ СЦЕНАРИЙ: БОЛЬШАЯ КОАЛИЦИЯ! Державы мира объединились против %s!" % hegemon.name)

func _trigger_arms(main: Node, world: Node, drama: Object, diplo: Object, hud: Node, now: float) -> void:
	var alive_countries: Array = []
	for c in world.countries:
		if c != null and not c.eliminated:
			alive_countries.append(c)
	if alive_countries.size() < 2:
		return
	
	alive_countries.sort_custom(func(a, b): return a.city_ids.size() > b.city_ids.size())
	var p1 = alive_countries[0]
	var p2 = alive_countries[1]
	
	p1.uranium = maxi(p1.uranium, 1500)
	p2.uranium = maxi(p2.uranium, 1500)
	p1.money += 20000
	p2.money += 20000
	
	var arc: Dictionary = {
		"id": drama.next_id,
		"k": 5, # K.ARMS
		"a": p1.id,
		"b": p2.id,
		"m": [],
		"side": [],
		"t0": now,
		"p": 0.5,
		"rate": 0.15,
		"life": 1600.0,
		"shown": true,
		"climax": false,
		"hold": 0,
		"data": {"arms": true}
	}
	drama.next_id += 1
	drama.arcs.append(arc)
	
	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", "⚡ СЦЕНАРИЙ: ГОНКА ВООРУЖЕНИЙ! %s и %s начали ядерную эскалацию!" % [p1.name, p2.name])

func _trigger_trade(main: Node, world: Node, drama: Object, diplo: Object, hud: Node, now: float) -> void:
	var alive_countries: Array = []
	for c in world.countries:
		if c != null and not c.eliminated:
			alive_countries.append(c)
	if alive_countries.size() < 2:
		return
	
	alive_countries.sort_custom(func(a, b): return a.city_ids.size() > b.city_ids.size())
	var p1 = alive_countries[0]
	var p2 = alive_countries[1]
	
	var arc: Dictionary = {
		"id": drama.next_id,
		"k": 6, # K.TRADE
		"a": p1.id,
		"b": p2.id,
		"m": [],
		"side": [],
		"t0": now,
		"p": 0.65,
		"rate": 0.15,
		"life": 1400.0,
		"shown": true,
		"climax": true,
		"hold": 0,
		"data": {"trade": true}
	}
	drama.next_id += 1
	drama.arcs.append(arc)
	
	if diplo and diplo.has_method("embargo_set"):
		diplo.call("embargo_set", p1.id, p2.id, true)
		diplo.call("embargo_set", p2.id, p1.id, true)
		
	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", "⚡ СЦЕНАРИЙ: САНКЦИОННАЯ ВОЙНА! %s и %s ввели тотальное торговое эмбарго!" % [p1.name, p2.name])

# ==============================================================================
# ГЕНЕРАТОРЫ НОВЫХ КАРТ
# ==============================================================================

func _generate_arctic_map(world_data: RefCounted, _s: Resource) -> void:
	print("[ScenariosPack] Generating Arctic (Ice Age) terrain...")
	if world_data == null:
		return
	var w: int = int(world_data.get("w"))
	var h: int = int(world_data.get("h"))
	var n: int = w * h
	var biomes: PackedByteArray = world_data.get("biome")
	if biomes.size() != n:
		return

	var sd: int = int(world_data.get("world_seed"))
	var rng: = Rng.new(sd + 9931)

	for y in h:
		for x in w:
			var i: int = y * w + x
			var b: int = biomes[i]
			if b <= Biome.RIVER:
				continue
			if b == Biome.ROCK or b == Biome.HILLS:
				biomes[i] = Biome.SNOW if rng.range_i(100) < 65 else Biome.ROCK
			elif b == Biome.FOREST or b == Biome.PINE:
				biomes[i] = Biome.PINE if rng.range_i(100) < 70 else Biome.SNOW
			elif b == Biome.SAND:
				biomes[i] = Biome.STEPPE if rng.range_i(100) < 40 else Biome.SNOW
			else:
				var roll: int = rng.range_i(100)
				if roll < 52:
					biomes[i] = Biome.SNOW
				elif roll < 82:
					biomes[i] = Biome.PINE
				elif roll < 94:
					biomes[i] = Biome.STEPPE
				else:
					biomes[i] = Biome.ROCK

	world_data.set("biome", biomes)
	print("[ScenariosPack] Arctic terrain generation complete!")

func _generate_volcano_map(world_data: RefCounted, _s: Resource) -> void:
	print("[ScenariosPack] Generating Volcano (Ash Archipelago) terrain...")
	if world_data == null:
		return
	var w: int = int(world_data.get("w"))
	var h: int = int(world_data.get("h"))
	var n: int = w * h
	var biomes: PackedByteArray = world_data.get("biome")
	if biomes.size() != n:
		return

	var sd: int = int(world_data.get("world_seed"))
	var rng: = Rng.new(sd + 7713)

	for y in h:
		for x in w:
			var i: int = y * w + x
			var b: int = biomes[i]
			if b <= Biome.RIVER:
				continue
			if b == Biome.ROCK or b == Biome.HILLS:
				biomes[i] = Biome.ROCK
			elif b == Biome.SNOW:
				biomes[i] = Biome.ROCK if rng.range_i(100) < 75 else Biome.STEPPE
			elif b == Biome.FOREST or b == Biome.PINE:
				biomes[i] = Biome.PINE if rng.range_i(100) < 40 else Biome.STEPPE
			else:
				var roll: int = rng.range_i(100)
				if roll < 50:
					biomes[i] = Biome.ROCK
				elif roll < 80:
					biomes[i] = Biome.STEPPE
				elif roll < 92:
					biomes[i] = Biome.PINE
				else:
					biomes[i] = Biome.GRASS

	world_data.set("biome", biomes)
	print("[ScenariosPack] Volcano terrain generation complete!")
