extends RefCounted

## Мод «БПЛА-камикадзе «Герань-2» (Shahed-136)» для DroneFlames Reborn
## Разработано для сообщества мододелов DroneFlames.
##
## Возможности:
## - Полная нативная интеграция в Дронозавод: кнопка «ГЕРАНЬ-2» в карточке завода.
## - Полная нативная интеграция в меню «Пуск дронов»: переключатель «ГЕРАНЬ-2» с отображением запаса на складе.
## - Увеличенная скорость (34 км/ч), разрушительная БЧ (150 урона), расширенный радиус поражения.
## - Спецэффекты: свист пикирования, мощный взрыв с тряской камеры и шлейф дыма.

var mm_ref: Node = null
var main_ref: Node = null
var world_ref: Node = null

# Запасы произведённых Гераней: country_id -> int
var geran_stock: Dictionary = {}

# Заказы на заводах: facility_id -> bool
var factory_orders: Dictionary = {}

# Режим пуска: выбран ли пуск Гераней в карточке «Пуск дронов»
var plan_geran_active: bool = false

# Отслеживание активных Гераней в воздухе: drone_id -> Dictionary
var active_gerans: Dictionary = {}

# Предыдущее количество дронов для отслеживания момента вылета
var _prev_drones_count: int = 0

const GERAN_COST_MONEY: int = 350
const GERAN_COST_METAL: int = 3
const GERAN_PROD_TIME: float = 14.0
const GERAN_CRUISE_SPEED: float = 34.0
const GERAN_WARHEAD_DAMAGE: float = 150.0

func init_mod(mm: Node) -> void:
	mm_ref = mm
	_create_and_register_icons(mm)
	if mm.has_method("register_hook"):
		mm.call("register_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("register_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[ShahedGeranMod] Mod initialized successfully.")

func cleanup_mod(mm: Node) -> void:
	if main_ref != null and is_instance_valid(main_ref) and main_ref.hud != null and mm != null and mm.has_method("cleanup_mod_hud"):
		mm.call("cleanup_mod_hud", main_ref.hud, Callable(self, "_on_hud_action"))
	geran_stock.clear()
	factory_orders.clear()
	active_gerans.clear()
	plan_geran_active = false
	if mm != null:
		if mm.has_method("unregister_texture"):
			mm.call("unregister_texture", "icon_geran")
		if mm.has_method("unregister_hook"):
			mm.call("unregister_hook", "on_world_started", Callable(self, "_on_world_started"))
			mm.call("unregister_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[ShahedGeranMod] Mod cleaned up.")

# ==============================================================================
# ИКОНКА МОДА
# ==============================================================================
func _create_and_register_icons(mm: Node) -> void:
	if mm == null or not mm.has_method("register_texture"):
		return
	
	# Создаем четкую пиксельную иконку треугольного БПЛА «Герань-2» с винглетами
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Отрисовка дельтовидного корпуса (Шахед-136 / Герань-2)
	for y in range(4, 28):
		var progress: float = float(y - 4) / 23.0
		var half_w: float = progress * 12.0
		var center_x: float = 15.5
		var min_x: int = int(floor(center_x - half_w))
		var max_x: int = int(ceil(center_x + half_w))
		for x in range(min_x, max_x + 1):
			if x >= 0 and x < 32:
				var c: Color = Color(0.18, 0.20, 0.22, 1.0)
				# Окантовка и темный камуфляж
				if x == min_x or x == max_x or y == 27:
					c = Color(0.1, 0.12, 0.14, 1.0)
				elif absf(float(x) - center_x) < 1.5:
					c = Color(0.28, 0.30, 0.33, 1.0) # центральный фюзеляж
				img.set_pixel(x, y, c)

	# Боковые шайбы / винглеты на законцовках крыла
	for y in range(18, 28):
		img.set_pixel(3, y, Color(0.85, 0.25, 0.2, 1.0))
		img.set_pixel(4, y, Color(0.12, 0.14, 0.16, 1.0))
		img.set_pixel(27, y, Color(0.12, 0.14, 0.16, 1.0))
		img.set_pixel(28, y, Color(0.85, 0.25, 0.2, 1.0))

	# Носовой обтекатель (боеголовка)
	img.set_pixel(15, 3, Color(0.9, 0.2, 0.2, 1.0))
	img.set_pixel(16, 3, Color(0.9, 0.2, 0.2, 1.0))

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	mm.register_texture("icon_geran", tex)

# ==============================================================================
# СОБЫТИЯ ИГРЫ
# ==============================================================================
func _on_world_started(main: Node, world: Node) -> void:
	main_ref = main
	world_ref = world
	factory_orders.clear()
	active_gerans.clear()
	plan_geran_active = false
	_prev_drones_count = 0

	# Стартовый запас для игрока для быстрого теста
	if world.player != null:
		geran_stock[world.player.id] = 3

	# Подключение к сигналу нативного HUD
	if main.hud != null and not main.hud.action.is_connected(_on_hud_action):
		main.hud.action.connect(_on_hud_action)

	print("[ShahedGeranMod] Connected to world and HUD signals.")

func _on_hud_action(nm: String) -> void:
	match nm:
		"dtype_geran":
			if main_ref != null and main_ref.selected_fac != null and main_ref.selected_fac.kind == Facility.Kind.DRONE_FACTORY:
				var fac: Facility = main_ref.selected_fac
				var p: Country = world_ref.player
				if p != null and p.money >= GERAN_COST_MONEY:
					factory_orders[fac.id] = true
					# Переключаем завод на производство
					fac.producing = true
					fac.prod_t = 0.0
					p.money -= GERAN_COST_MONEY
					if p.has_method("missing_res") and p.get("metal") != null:
						p.metal = maxi(0, p.metal - GERAN_COST_METAL)
					UiKit.snd("ui_build")
					main_ref.hud.show_toast("Заказ: БПЛА «Герань-2» (350 $ · 3 металла)")
				else:
					UiKit.snd("ui_error")
					main_ref.hud.show_toast("Не хватает средств для производства Герань-2 (350 $)")

		"dtype_0", "dtype_1":
			# Если игрок переключился на обычный или реактивный дрон
			if main_ref != null and main_ref.selected_fac != null:
				factory_orders[main_ref.selected_fac.id] = false

		"plan_kind_geran":
			plan_geran_active = not plan_geran_active
			UiKit.snd("ui_click")
			if plan_geran_active:
				if main_ref != null:
					main_ref.plan_jet = false
				var stock_cnt: int = int(geran_stock.get(world_ref.player.id, 0)) if world_ref != null and world_ref.player != null else 0
				main_ref.hud.show_toast("Выбран БПЛА «Герань-2» (В наличии: %d шт.)" % stock_cnt)

		"plan_kind_0", "plan_kind_1":
			plan_geran_active = false

func _on_match_tick(main: Node, world: Node, delta: float) -> void:
	main_ref = main
	world_ref = world
	if main != null and main.hud != null and not main.hud.action.is_connected(_on_hud_action):
		main.hud.action.connect(_on_hud_action)

	var time_scale: float = 1.0
	if world != null and "time_scale" in world:
		time_scale = maxf(0.0, float(world.time_scale))
	var sim_delta: float = delta * time_scale

	# 1. Интеграция кнопки в карточку выбранного Дронозавода
	_tick_factory_card(main, world, delta)

	# 2. Интеграция кнопки в карточку «Пуск дронов»
	_tick_plan_card(main, world)

	# 3. Отслеживание новых дронов и конвертация в Герань при заказе
	if sim_delta > 0.0:
		_tick_drone_production(world, sim_delta)
		_tick_active_gerans(world, sim_delta)

# ==============================================================================
# ИНТЕГРАЦИЯ В КАРТОЧКУ ДРОНОЗАВОДА
# ==============================================================================
func _tick_factory_card(main: Node, world: Node, delta: float) -> void:
	if main.selected_fac == null or main.selected_fac.kind != Facility.Kind.DRONE_FACTORY:
		return
	
	var fac: Facility = main.selected_fac
	if main.hud == null or main.hud.fac_row == null:
		return

	var fac_row: HBoxContainer = main.hud.fac_row
	var is_geran_ordered: bool = bool(factory_orders.get(fac.id, false))

	# Проверяем наличие нашей кнопки в ряду кнопок здания
	if not fac_row.has_node("cell_geran"):
		var cell: VBoxContainer = VBoxContainer.new()
		cell.name = "cell_geran"
		cell.add_theme_constant_override("separation", 0)
		cell.custom_minimum_size = Vector2(52, 0)

		var b: Button = UiKit.slot("icon_geran", is_geran_ordered, 40.0)
		b.name = "btn_geran"
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void: main.hud.action.emit("dtype_geran"))
		cell.add_child(b)

		var l: Label = UiKit.lbl("ГЕРАНЬ-2\n%d" % GERAN_COST_MONEY, 9, UiKit.GOLD if is_geran_ordered else UiKit.TEXT, 2, 3)
		l.name = "lbl_geran"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(52, 0)
		cell.add_child(l)

		# Вставляем кнопку рядом с реактивными БПЛА
		fac_row.add_child(cell)
		if fac_row.get_child_count() > 3:
			fac_row.move_child(cell, 2)
	else:
		# Обновляем подсветку кнопки если режим активен
		var cell: Control = fac_row.get_node("cell_geran") as Control
		if cell != null:
			var b: Button = cell.get_node_or_null("btn_geran") as Button
			if b != null and b.button_pressed != is_geran_ordered:
				b.set_pressed_no_signal(is_geran_ordered)
			var l: Label = cell.get_node_or_null("lbl_geran") as Label
			if l != null:
				l.modulate = UiKit.GOLD if is_geran_ordered else Color.WHITE

	# Если завод строит Герань, выводим прогресс в деталях
	if is_geran_ordered and fac.producing:
		var time_left: float = maxf(0.0, GERAN_PROD_TIME - fac.prod_t)
		if main.hud.ops_info != null:
			main.hud.ops_info.text = "СБОРКА БПЛА «ГЕРАНЬ-2»: %d сек · МЕСТ %d/%d" % [
				int(ceil(time_left)),
				world.mil.stock_count(world.player.id),
				world.mil.drone_capacity(world.player.id)
			]

# ==============================================================================
# ИНТЕГРАЦИЯ В КАРТОЧКУ «ПУСК ДРОНОВ»
# ==============================================================================
func _tick_plan_card(main: Node, world: Node) -> void:
	if main.hud == null or not main.hud.ops_panel.visible:
		return
	if main.hud._ops_key != "plan_drone":
		return

	var fac_row: HBoxContainer = main.hud.fac_row
	if fac_row == null:
		return

	var p_id: int = world.player.id if world.player != null else 0
	var count_stock: int = int(geran_stock.get(p_id, 0))

	if not fac_row.has_node("cell_plan_geran"):
		var cell: VBoxContainer = VBoxContainer.new()
		cell.name = "cell_plan_geran"
		cell.add_theme_constant_override("separation", 0)
		cell.custom_minimum_size = Vector2(52, 0)

		var b: Button = UiKit.slot("icon_geran", plan_geran_active, 40.0)
		b.name = "btn_plan_geran"
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.disabled = (count_stock == 0)
		b.pressed.connect(func() -> void: main.hud.action.emit("plan_kind_geran"))
		cell.add_child(b)

		# Бейдж с количеством Гераней на складе
		var bd: Label = UiKit.lbl("%d" % count_stock, 10, UiKit.GOLD, 3, 3)
		bd.name = "badge_cnt"
		bd.position = Vector2(30, 26)
		b.add_child(bd)

		var l: Label = UiKit.lbl("ГЕРАНЬ-2", 9, UiKit.GOLD if plan_geran_active else UiKit.TEXT, 2, 3)
		l.name = "lbl_name"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(52, 0)
		cell.add_child(l)

		fac_row.add_child(cell)
		# Ставим третьим слотом после ДРОНЫ и РЕАКТИВН.
		if fac_row.get_child_count() > 2:
			fac_row.move_child(cell, 2)
	else:
		var cell: Control = fac_row.get_node("cell_plan_geran") as Control
		if cell != null:
			var b: Button = cell.get_node_or_null("btn_plan_geran") as Button
			if b != null:
				b.disabled = (count_stock == 0)
				b.set_pressed_no_signal(plan_geran_active)
				var bd: Label = b.get_node_or_null("badge_cnt") as Label
				if bd != null:
					bd.text = "%d" % count_stock
			var l: Label = cell.get_node_or_null("lbl_name") as Label
			if l != null:
				l.modulate = UiKit.GOLD if plan_geran_active else Color.WHITE

	# Если активен режим Герани, обновляем подсказку
	if plan_geran_active and main.hud.ops_sub != null:
		main.hud.ops_sub.text = "БПЛА-камикадзе «Герань-2» · Скорость 34 · Урон 150 · Большой радиус"

# ==============================================================================
# ПРОИЗВОДСТВО И ВЫПУСК
# ==============================================================================
func _tick_drone_production(world: GameWorld, delta: float) -> void:
	if world.mil == null:
		return

	# Проверяем заводы с активным заказом на Герань
	for fac in world.mil.facilities:
		if fac.kind == Facility.Kind.DRONE_FACTORY and factory_orders.get(fac.id, false):
			fac.prod_t += delta * 0.8
			if fac.prod_t >= GERAN_PROD_TIME:
				fac.producing = false
				fac.prod_t = 0.0
				factory_orders[fac.id] = false
				
				# Добавляем готовую Герань на склад страны
				var cid: int = fac.country_id
				geran_stock[cid] = int(geran_stock.get(cid, 0)) + 1
				
				world.fx.spawn("build_spark", fac.center_px(), 8)
				Sfx.play("ui_build", fac.center_px())
				if world.player != null and cid == world.player.id:
					main_ref.hud.show_toast("БПЛА «Герань-2» готов! (На складе: %d шт.)" % geran_stock[cid])

	# Отслеживаем только что запущенные дроны
	var cur_count: int = world.mil.drones.size()
	if plan_geran_active and cur_count > _prev_drones_count:
		var p_id: int = world.player.id if world.player != null else 0
		for d in world.mil.drones:
			if d.country_id == p_id and not d.has_meta("is_geran") and (d.state == Drone.State.WAIT or d.state == Drone.State.TAXI or d.state == Drone.State.ROLL or d.state == Drone.State.BOOST):
				if int(geran_stock.get(p_id, 0)) > 0:
					geran_stock[p_id] = int(geran_stock.get(p_id, 0)) - 1
					d.set_meta("is_geran", true)
					d.cruise_speed = GERAN_CRUISE_SPEED
					active_gerans[d.id] = {
						"drone": d,
						"dive_sfx": false,
						"target": d.target
					}
					main_ref.hud.show_toast("Пуск БПЛА «Герань-2» по цели!")
					break
	_prev_drones_count = cur_count

# ==============================================================================
# ПОЛЁТ И ВЗРЫВ ГЕРАНИ
# ==============================================================================
func _tick_active_gerans(world: GameWorld, delta: float) -> void:
	if active_gerans.is_empty():
		return

	var dead_ids: Array = []
	for did in active_gerans.keys():
		var info: Dictionary = active_gerans[did]
		var d: Drone = info.get("drone") as Drone
		if d == null or d.state == Drone.State.DONE:
			# Дрон достиг цели или взорвался — наносим мощный урон Герани!
			_detonate_geran(world, info)
			dead_ids.append(did)
			continue

		# Шлейф дыма от мотора
		if d.airborne():
			var tail: Vector2 = d.pos - Vector2.from_angle(d.heading) * 6.0
			world.fx.spawn("trail_s", tail.round(), 2)

		# Звук свиста/сирены при пикировании на цель
		var dist_to_tgt: float = d.pos.distance_to(d.target)
		if (d.state == Drone.State.DIVE or dist_to_tgt < 80.0) and not bool(info.get("dive_sfx", false)):
			info["dive_sfx"] = true
			Sfx.play("shell_whistle_in", d.pos, 3.0)

	for did in dead_ids:
		active_gerans.erase(did)

func _detonate_geran(world: GameWorld, info: Dictionary) -> void:
	var tgt: Vector2 = info.get("target", Vector2.ZERO)
	if tgt == Vector2.ZERO:
		return

	var cell: Vector2i = Vector2i(floori(tgt.x / GameWorld.CELL), floori(tgt.y / GameWorld.CELL))
	var cid: int = world.player.id if world.player != null else 0

	# 1. Мощный удар по эпицентру (strike_big)
	world.strike_big(cell, cid)

	# 2. Осколочно-фугасное поражение по соседним 8 клеткам (150 общего урона)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx != 0 or dy != 0:
				world.strike(cell + Vector2i(dx, dy), cid)

	# 3. Визуальные и звуковые спецэффекты
	world.fx.spawn("explosion_s", tgt.round(), 10)
	world.fx.spawn("dust_s", tgt.round(), 8)
	world.camera_shake_small()
	Sfx.play("expl_big", tgt, 4.0)

	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Герань-2: Цель уничтожена мощным взрывом (150 ув)!")
