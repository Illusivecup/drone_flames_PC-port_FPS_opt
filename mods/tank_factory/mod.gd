extends RefCounted

## Мод «Завод танков и бронетехники» для DroneFlames Reborn
## Полная интеграция в оригинальный интерфейс и движок игры.
## Добавляет слот постройки во вкладку «АРМИЯ» в нижней панели,
## строит аутентичный завод с текстурами из атласа игры,
## поддерживает выбор завода на карте с открытием нативной карточки
## и производство ОБТ Т-90М, БМП-3, САУ «Мста-С» и ТОС-1А «Солнцепёк».

var mm_ref: Node = null
var main_ref: Node = null
var world_ref: Node = null

var world_layer: Node2D = null

# Режим размещения нового завода через нижнюю панель
var is_placing: bool = false
var selected_fac: Facility = null

const FACTORY_COST_MONEY: int = 1200
const FACTORY_COST_METAL: int = 25
const FACTORY_SIZE: Vector2i = Vector2i(6, 4)
const FACTORY_MAX_HP: float = 350.0

const PRODUCTS: Dictionary = {
	"tank": {
		"id": "tank",
		"name": "ОБТ Т-90М «Прорыв»",
		"short": "ОБТ Т-90М",
		"type": Unit.Type.TANK,
		"cost": 450,
		"metal": 8,
		"time": 18.0,
		"desc": "Основной боевой танк. 125-мм гладкоствольная пушка, тяжелая динамическая защита для прорыва обороны.",
		"icon": "icon_tank"
	},
	"ifv": {
		"id": "ifv",
		"name": "БМП-3",
		"short": "БМП-3",
		"type": Unit.Type.IFV,
		"cost": 320,
		"metal": 5,
		"time": 14.0,
		"desc": "Боевая машина пехоты. 100-мм орудие + 30-мм автоматическая пушка, десантное отделение и поддержка пехоты.",
		"icon": "icon_infantry"
	},
	"arty": {
		"id": "arty",
		"name": "САУ 2С19 «Мста-С»",
		"short": "САУ «МСТА»",
		"type": Unit.Type.ARTY,
		"cost": 600,
		"metal": 10,
		"time": 22.0,
		"desc": "152-мм дивизионная самоходная гаубица. Дальнобойный навесной огонь по опорным пунктам и скоплениям врага.",
		"icon": "icon_target"
	},
	"mlrs": {
		"id": "mlrs",
		"name": "ТОС-1А «Солнцепёк»",
		"short": "ТОС-1А",
		"type": Unit.Type.MLRS,
		"cost": 750,
		"metal": 12,
		"time": 25.0,
		"desc": "Тяжелая огнеметная система. 220-мм термобарические реактивные снаряды для выжигания укреплений.",
		"icon": "icon_missile"
	}
}

func init_mod(mm: Node) -> void:
	mm_ref = mm
	if mm.has_method("register_hook"):
		mm.call("register_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("register_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[TankFactory] Native mod initialized.")

func cleanup_mod(mm: Node) -> void:
	if main_ref != null and is_instance_valid(main_ref) and main_ref.hud != null and mm != null and mm.has_method("cleanup_mod_hud"):
		mm.call("cleanup_mod_hud", main_ref.hud, Callable(self, "_on_hud_action"), ["tank_factory"])
	_cleanup_nodes()
	if mm and mm.has_method("unregister_hook"):
		mm.call("unregister_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("unregister_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[TankFactory] Mod cleaned up.")

func _cleanup_nodes() -> void:
	is_placing = false
	selected_fac = null
	if world_layer != null and is_instance_valid(world_layer):
		world_layer.queue_free()
		world_layer = null

func _ensure_hud(main: Node, world: Node) -> void:
	if main == null or not is_instance_valid(main) or world == null or not is_instance_valid(world):
		return
	main_ref = main
	world_ref = world

	# 1. Встраивание слота постройки напрямую во вкладку «АРМИЯ» (Tab 4) нижней панели
	if main.hud != null and main.hud.pages.size() > 4:
		var army_grid = main.hud.pages[4] as GridContainer
		if army_grid != null and not main.hud.keys.has("tank_factory"):
			var cell = main.hud._cell("tank_factory", "icon_tank", true)
			if main.hud.key_labels.has("tank_factory"):
				var lbl = main.hud.key_labels["tank_factory"] as Label
				if lbl != null:
					lbl.text = "БРОНЕЗАВОД"
			army_grid.add_child(cell)
			army_grid.move_child(cell, 1) # Рядом с казармами

		if not main.hud.action.is_connected(_on_hud_action):
			main.hud.action.connect(_on_hud_action)

	# 2. Слой мира для отображения сетки призрака постройки и частиц цеха
	if world_layer == null or not is_instance_valid(world_layer):
		world_layer = TankFactoryWorldLayer.new()
		world_layer.setup(self, main, world)
		world.add_child(world_layer)

func _on_world_started(main: Node, world: Node) -> void:
	_cleanup_nodes()
	_ensure_hud(main, world)
	print("[TankFactory] Injected tank_factory cell into Army tab and world layer attached.")

func _on_hud_action(nm: String) -> void:
	match nm:
		"tank_factory":
			if main_ref != null and main_ref.hud != null:
				main_ref.hud.show_tip(
					"Завод бронетехники",
					"Строит тяжёлую технику: Т-90М, БМП-3, САУ «Мста-С», ТОС-1А. 1200 $ · металл 25",
					""
				)
			toggle_placement()
		"tank_prod_tank":
			if selected_fac != null:
				_order_production(selected_fac, "tank")
		"tank_prod_ifv":
			if selected_fac != null:
				_order_production(selected_fac, "ifv")
		"tank_prod_arty":
			if selected_fac != null:
				_order_production(selected_fac, "arty")
		"tank_prod_mlrs":
			if selected_fac != null:
				_order_production(selected_fac, "mlrs")
		"tank_repair":
			if selected_fac != null:
				_repair_factory(selected_fac)
		"tank_demolish":
			if selected_fac != null:
				_demolish_factory(selected_fac)

func _on_match_tick(main: Node, world: Node, delta: float) -> void:
	main_ref = main
	world_ref = world
	if main != null and (main.hud == null or not main.hud.keys.has("tank_factory") or world_layer == null):
		_ensure_hud(main, world)

	var ts: float = 1.0
	if world != null and "time_scale" in world:
		ts = maxf(0.0, float(world.time_scale))
	var sim_delta: float = delta * ts

	_tick_factories(sim_delta)

	# Обновление нативной карточки здания внизу экрана, если выбран наш завод
	if main != null and "selected_fac" in main and main.selected_fac != null and is_instance_valid(main.selected_fac):
		var f: Facility = main.selected_fac as Facility
		if f != null and f.has_meta("is_tank_factory") and f.get_meta("is_tank_factory"):
			selected_fac = f
			_update_native_card(f)
		else:
			if selected_fac != null and selected_fac == f:
				selected_fac = null
	else:
		selected_fac = null

	if world_layer != null and is_instance_valid(world_layer):
		world_layer.queue_redraw()

func toggle_placement() -> void:
	if is_placing:
		cancel_placement()
	else:
		start_placement()

func start_placement() -> void:
	if world_ref == null or not is_instance_valid(world_ref):
		return
	var p = world_ref.player
	if p == null:
		return

	if p.money < FACTORY_COST_MONEY or p.metal < FACTORY_COST_METAL:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает ресурсов: 1200 $ и 25 металла!")
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	is_placing = true
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.set_key_pressed("tank_factory", true)
		main_ref.hud.show_toast("БРОНЕЗАВОД: Выберите место на своей территории")

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_select")

func cancel_placement() -> void:
	is_placing = false
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.set_key_pressed("tank_factory", false)

func can_place_at(cell: Vector2i) -> bool:
	if world_ref == null or not is_instance_valid(world_ref):
		return false
	var d = world_ref.data
	if d == null:
		return false

	if cell.x < 3 or cell.y < 3 or cell.x + FACTORY_SIZE.x >= d.w - 3 or cell.y + FACTORY_SIZE.y >= d.h - 3:
		return false

	var player = world_ref.player
	if player == null:
		return false

	for dy in range(FACTORY_SIZE.y):
		for dx in range(FACTORY_SIZE.x):
			var cx = cell.x + dx
			var cy = cell.y + dy

			# Проверка принадлежности территории игроку
			if d.get_owner_id(cx, cy) != player.id:
				return false

			# Проверка на сушу (не вода)
			var b = d.get_biome(cx, cy)
			if Biome.is_water(b):
				return false

			# Проверка на занятость другими строениями
			if d.has_flag(cx, cy, WorldData.F_OCCUPIED):
				return false

	return true

func place_factory_at(cell: Vector2i) -> void:
	if not can_place_at(cell):
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Нельзя построить здесь: нужна свободная суша на вашей земле")
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	var p = world_ref.player
	if p.money < FACTORY_COST_MONEY or p.metal < FACTORY_COST_METAL:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает: 1200 $ и 25 металла!")
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	# Оплата постройки
	p.money -= FACTORY_COST_MONEY
	p.metal -= FACTORY_COST_METAL

	# Создание нативного Facility объекта
	var f = Facility.new()
	f.id = world_ref.mil.facilities.size()
	f.kind = Facility.Kind.CIV_FACTORY
	f.country_id = p.id
	f.cell = cell
	f.size = FACTORY_SIZE
	f.set_meta("is_tank_factory", true)
	f.set_meta("hp", FACTORY_MAX_HP)
	f.set_meta("max_hp", FACTORY_MAX_HP)
	f.set_meta("cur_prod", "")
	f.set_meta("prod_t", 0.0)
	f.set_meta("prod_dur", 0.0)
	f.set_meta("producing", false)
	f.set_meta("chimney_t", 0.0)

	# Размещение нативного спрайта фабрики в объектах игрового мира
	f.main_obj = world_ref.add_object("civ_factory", cell, GameWorld.KIND_BUILDING)
	f.obj_ids.append(f.main_obj)
	world_ref.mil.facilities.append(f)

	# Установка занятости клеток и индустриального покрытия
	var d = world_ref.data
	for dy in range(f.size.y):
		for dx in range(f.size.x):
			var cx = cell.x + dx
			var cy = cell.y + dy
			world_ref.remove_tree_at(Vector2i(cx, cy))
			d.add_flag(cx, cy, WorldData.F_OCCUPIED)
			d.set_biome(cx, cy, Biome.INDUSTRIAL)

	cancel_placement()

	# Звук и частицы постройки
	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_build")
	if world_ref.fx != null:
		world_ref.fx.spawn("dust_s", Vector2(cell * GameWorld.CELL + Vector2i(18, 12)), 8)

	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Завод танков и бронетехники успешно построен!")
		# Сразу выбираем построенный завод, открывая нативную карточку управления
		main_ref.selected_fac = f

func _order_production(f: Facility, prod_id: String) -> void:
	if not PRODUCTS.has(prod_id):
		return
	var prod = PRODUCTS[prod_id]
	var p = world_ref.player
	var cost_m = int(prod["cost"])
	var cost_met = int(prod["metal"])

	if p.money < cost_m or p.metal < cost_met:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает ресурсов: требуется %d $ и %d металла!" % [cost_m, cost_met])
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	# Списание ресурсов и запуск цикла производства
	p.money -= cost_m
	p.metal -= cost_met

	f.set_meta("producing", true)
	f.set_meta("cur_prod", prod_id)
	f.set_meta("prod_t", 0.0)
	f.set_meta("prod_dur", float(prod["time"]))

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_build")

	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Завод заложил производство: %s" % prod["name"])

func _repair_factory(f: Facility) -> void:
	var p = world_ref.player
	var rep_cost = 150
	if p.money < rep_cost:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает средств на ремонт: требуется %d $!" % rep_cost)
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	p.money -= rep_cost
	f.set_meta("hp", FACTORY_MAX_HP)

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_build")

	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Завод полностью отремонтирован!")

func _demolish_factory(f: Facility) -> void:
	var p = world_ref.player
	p.money += 600

	# Освобождение клеток
	var d = world_ref.data
	for dy in range(f.size.y):
		for dx in range(f.size.x):
			var cx = f.cell.x + dx
			var cy = f.cell.y + dy
			d.clear_flag(cx, cy, WorldData.F_OCCUPIED)

	# Удаление графического объекта
	if f.main_obj >= 0:
		world_ref.remove_object(f.main_obj)

	world_ref.mil.facilities.erase(f)

	if main_ref != null:
		main_ref.call("_deselect")
		if main_ref.hud != null:
			main_ref.hud.show_toast("Завод танков демонтирован (+600 $)")

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_click")

func _tick_factories(delta: float) -> void:
	if world_ref == null or not is_instance_valid(world_ref):
		return
	if not ("mil" in world_ref and world_ref.mil != null):
		return

	for f in world_ref.mil.facilities:
		if not (f is Facility and f.has_meta("is_tank_factory") and f.get_meta("is_tank_factory")):
			continue

		var is_prod = bool(f.get_meta("producing", false))
		if is_prod:
			# Дым из трубы во время производства
			var ct = float(f.get_meta("chimney_t", 0.0)) + delta
			if ct >= 0.35:
				ct = 0.0
				var chimney_pos = Vector2(f.cell * GameWorld.CELL) + Vector2(24, 4)
				if world_ref.fx != null:
					world_ref.fx.spawn("smoke_puff", chimney_pos, 4)
			f.set_meta("chimney_t", ct)

			# Прогресс сборки техники
			var pt = float(f.get_meta("prod_t", 0.0)) + delta
			var dur = float(f.get_meta("prod_dur", 1.0))
			f.set_meta("prod_t", pt)

			if pt >= dur:
				# Производство завершено!
				f.set_meta("producing", false)
				var prod_id = String(f.get_meta("cur_prod", "tank"))
				f.set_meta("cur_prod", "")
				_spawn_produced_unit(f, prod_id)

func _spawn_produced_unit(f: Facility, prod_id: String) -> void:
	if world_ref == null or not is_instance_valid(world_ref):
		return
	if not ("army" in world_ref and world_ref.army != null):
		return

	var prod = PRODUCTS.get(prod_id, PRODUCTS["tank"])
	var utype: int = int(prod["type"])

	# Создание нативного юнита
	var u = Unit.new()
	u.id = world_ref.army._next_id
	world_ref.army._next_id += 1
	u.type = utype
	u.country_id = f.country_id
	u.home = f
	if Army.SPEC.has(utype):
		u.hp = float(Army.SPEC[utype]["hp"])
	else:
		u.hp = 100.0
	u.max_hp = u.hp

	# Точка выезда из цеха
	var exit_pos = Vector2(f.cell * GameWorld.CELL) + Vector2(float(f.size.x * GameWorld.CELL) * 0.5, float((f.size.y + 1) * GameWorld.CELL))
	u.pos = exit_pos
	u.heading = PI * 0.5
	u.update_frame()
	u.state = Unit.State.MOVE

	# Поиск ближайшей казармы/армии игрока для приписки
	var best_bar: Facility = null
	var min_d = 1e9
	for fac in world_ref.mil.facilities:
		if fac.kind == Facility.Kind.BARRACKS and fac.country_id == f.country_id and world_ref.mil.alive(fac):
			var d = fac.center_px().distance_to(u.pos)
			if d < min_d:
				min_d = d
				best_bar = fac

	if best_bar != null:
		u.home = best_bar
		u.path = PackedVector2Array([world_ref.army.barracks_out(best_bar)])
		u.pi = 0
	else:
		u.path = PackedVector2Array([u.pos + Vector2(0, 32)])
		u.pi = 0

	world_ref.army.units.append(u)

	if world_ref.fx != null:
		world_ref.fx.spawn("dust_s", u.pos.round(), 8)

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_build")

	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Бронезавод выпустил: %s!" % prod["name"])

func _update_native_card(f: Facility) -> void:
	if main_ref == null or main_ref.hud == null:
		return

	var p = world_ref.player
	var is_producing = bool(f.get_meta("producing", false))
	var cur_prod = String(f.get_meta("cur_prod", ""))
	var prod_t = float(f.get_meta("prod_t", 0.0))
	var prod_dur = float(f.get_meta("prod_dur", 1.0))
	var hp = float(f.get_meta("hp", FACTORY_MAX_HP))
	var max_hp = float(f.get_meta("max_hp", FACTORY_MAX_HP))

	# Открытие нативной карточки через Hud._card
	main_ref.hud._card(
		"tank_fac_%d" % f.id,
		"icon_tank",
		"ЗАВОД БРОНЕТЕХНИКИ",
		"ПРОИЗВОДСТВО ТЯЖЁЛОЙ БРОНЕТЕХНИКИ И РЕМОНТ",
		false,
		false,
		true
	)

	var acts: Array = []

	# 1. ОБТ Т-90М
	var c_tank = int(PRODUCTS["tank"]["cost"])
	var m_tank = int(PRODUCTS["tank"]["metal"])
	acts.append(main_ref.hud._act(
		"ОБТ Т-90\n%d $" % c_tank,
		"icon_tank",
		"tank_prod_tank",
		p.money >= c_tank and p.metal >= m_tank and not is_producing,
		1 if cur_prod == "tank" else 0
	))

	# 2. БМП-3
	var c_ifv = int(PRODUCTS["ifv"]["cost"])
	var m_ifv = int(PRODUCTS["ifv"]["metal"])
	acts.append(main_ref.hud._act(
		"БМП-3\n%d $" % c_ifv,
		"icon_infantry",
		"tank_prod_ifv",
		p.money >= c_ifv and p.metal >= m_ifv and not is_producing,
		1 if cur_prod == "ifv" else 0
	))

	# 3. САУ «Мста-С»
	var c_arty = int(PRODUCTS["arty"]["cost"])
	var m_arty = int(PRODUCTS["arty"]["metal"])
	acts.append(main_ref.hud._act(
		"САУ МСТА\n%d $" % c_arty,
		"icon_target",
		"tank_prod_arty",
		p.money >= c_arty and p.metal >= m_arty and not is_producing,
		1 if cur_prod == "arty" else 0
	))

	# 4. ТОС-1А «Солнцепёк»
	var c_mlrs = int(PRODUCTS["mlrs"]["cost"])
	var m_mlrs = int(PRODUCTS["mlrs"]["metal"])
	acts.append(main_ref.hud._act(
		"ТОС-1А\n%d $" % c_mlrs,
		"icon_missile",
		"tank_prod_mlrs",
		p.money >= c_mlrs and p.metal >= m_mlrs and not is_producing,
		1 if cur_prod == "mlrs" else 0
	))

	# 5. Ремонт завода
	var can_rep = hp < max_hp - 1.0 and p.money >= 150
	acts.append(main_ref.hud._act(
		"РЕМОНТ\n150 $",
		"icon_restore",
		"tank_repair",
		can_rep
	))

	# 6. Снос
	var dact = main_ref.hud._act("СНОС\n+600 $", "icon_close", "tank_demolish", true)
	dact["red"] = true
	acts.append(dact)

	var status_str = "ГОТОВ К ПРОИЗВОДСТВУ · ПРОЧНОСТЬ %d/%d" % [int(hp), int(max_hp)]
	if is_producing:
		var prod_info = PRODUCTS.get(cur_prod, {})
		var pname = prod_info.get("short", cur_prod.to_upper())
		var left_s = maxf(0.0, prod_dur - prod_t)
		status_str = "ПРОИЗВОДИТСЯ: %s · ГОТОВО ЧЕРЕЗ %s" % [pname, main_ref.hud._mmss(left_s)]

	main_ref.hud._set_info(status_str, hp <= 0.0)
	main_ref.hud.ops_detail.text = "Специализированный завод тяжелой бронетехники. Производит танки Т-90М «Прорыв», боевые машины пехоты БМП-3, дальнобойные САУ «Мста-С» и реактивные огнеметные системы ТОС-1А «Солнцепёк». Готовые машины выкатываются из цеха и вступают в строй армии."
	main_ref.hud.ops_detail.visible = true
	main_ref.hud._fill_acts("tank_fac_%d" % f.id, acts)


# ==============================================================================
# Слой игрового мира (Отрисовка призрака постройки по сетке)
# ==============================================================================
class TankFactoryWorldLayer extends Node2D:
	var mod_ref: RefCounted = null
	var main_ref: Node = null
	var world_ref: Node = null

	func setup(m: RefCounted, main: Node, world: Node) -> void:
		mod_ref = m
		main_ref = main
		world_ref = world
		z_index = 65

	func _unhandled_input(event: InputEvent) -> void:
		if mod_ref == null or not mod_ref.is_placing:
			return

		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var mpos = main_ref.cam.screen_to_world(event.position)
				var cell = Vector2i((mpos / float(GameWorld.CELL)).floor())
				mod_ref.place_factory_at(cell)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				mod_ref.cancel_placement()
				get_viewport().set_input_as_handled()

	func _draw() -> void:
		if mod_ref == null or not mod_ref.is_placing or main_ref == null:
			return

		var mouse_w = main_ref.cam.screen_to_world(get_viewport().get_mouse_position())
		var cell = Vector2i((mouse_w / float(GameWorld.CELL)).floor())
		var valid = mod_ref.can_place_at(cell)

		var pos = Vector2(cell * GameWorld.CELL)
		var sz = Vector2(FACTORY_SIZE * GameWorld.CELL)

		var outline_col = Color(0.2, 1.0, 0.3, 0.9) if valid else Color(1.0, 0.25, 0.25, 0.9)
		var fill_col = Color(0.2, 1.0, 0.3, 0.2) if valid else Color(1.0, 0.25, 0.25, 0.2)

		# Сетка ячеек фундамента
		draw_rect(Rect2(pos, sz), fill_col)
		draw_rect(Rect2(pos, sz), outline_col, false, 2.0)

		for x in range(FACTORY_SIZE.x + 1):
			var lx = pos.x + float(x * GameWorld.CELL)
			draw_line(Vector2(lx, pos.y), Vector2(lx, pos.y + sz.y), Color(outline_col.r, outline_col.g, outline_col.b, 0.3), 1.0)
		for y in range(FACTORY_SIZE.y + 1):
			var ly = pos.y + float(y * GameWorld.CELL)
			draw_line(Vector2(pos.x, ly), Vector2(pos.x + sz.x, ly), Color(outline_col.r, outline_col.g, outline_col.b, 0.3), 1.0)

		# Контур корпуса завода
		draw_rect(Rect2(pos + Vector2(2, 4), sz - Vector2(4, 6)), Color(outline_col.r, outline_col.g, outline_col.b, 0.35))
