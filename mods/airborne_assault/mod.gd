extends RefCounted

const BuildPanel = preload("res://ui/ui24/build_panel.gd")

## Мод «Воздушный Десант (ВДВ) — Спецназ и Тактическая Авиация» для DroneFlames Reborn
## Полная интеграция в оригинальный интерфейс и движок игры.
## Добавляет слот постройки «ШТАБ ВДВ» во вкладку «АРМИЯ» в нижней панели.
## Требует электроэнергию (ТЭС/АЭС/СЭС), производит и готовит к вылету
## вертолёты Ми-8 «Терминатор» (тактическая высадка на тросах с зависания)
## и тяжёлые десантные самолёты Ил-76 (выброска БМД-4 и спецназа на парашютах).
## ПРЯМОЕ УПРАВЛЕНИЕ:
## - ЛКМ по бойцам ВДВ на карте — выделение отряда
## - ПКМ по карте/городу — приказ движения или штурма выбранным бойцам
## - Кнопка [ПРИКАЗ ВДВ / НАСТУПЛЕНИЕ] в карточке штаба — общее наступление всех групп
## АВТОНОМНЫЙ ИИ КАМПАНИИ:
## - После взятия города отряд лечится, пополняет бойцов и АВТОМАТИЧЕСКИ развивает наступление
##   на следующий вражеский город или военную базу (никогда не встаёт намертво)!

var mm_ref: Node = null
var main_ref: Node = null
var world_ref: Node = null

var world_layer: Node2D = null

# Размещение нового штаба ВДВ
var is_placing_hq: bool = false
var selected_hq: Facility = null

# Режим целеуказания для вылета: "" (нет), "mi8" (вертолёт), "il76" (самолёт), "vdv_order_all" (общий штурм)
var targeting_op: String = ""
var targeting_fac: Facility = null

# Активные вертолёты и самолёты в воздухе
var active_helis: Array = []
var active_planes: Array = []
var active_parachutes: Array = []

# Выбранный в воздухе вертолёт
var selected_heli: Object = null

# Список зарегистрированных бойцов ВДВ на земле и текущий выделенный игроком отряд
var active_vdv_troops: Array = []
var selected_vdv_troops: Array = []

# Таймер пополнений и лечения в освобождённых городах
var vdv_city_restock_t: float = 0.0
var last_reported_capture: String = ""

# Стоимости и параметры
const HQ_COST_MONEY: int = 1400
const HQ_COST_METAL: int = 15
const HQ_SIZE: Vector2i = Vector2i(6, 4)
const HQ_MAX_HP: float = 450.0

const MI8_COST_MONEY: int = 950
const MI8_COST_METAL: int = 6
const MI8_PREP_TIME: float = 14.0
const MI8_MAX_LIMIT: int = 2

const IL76_COST_MONEY: int = 2200
const IL76_COST_METAL: int = 14
const IL76_PREP_TIME: float = 24.0
const IL76_MAX_LIMIT: int = 1

func init_mod(mm: Node) -> void:
	mm_ref = mm
	_create_and_register_icons(mm)
	if mm.has_method("register_hook"):
		mm.call("register_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("register_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[AirborneAssault] Native VDV mod initialized.")

func cleanup_mod(mm: Node) -> void:
	if main_ref != null and is_instance_valid(main_ref) and main_ref.hud != null and mm != null and mm.has_method("cleanup_mod_hud"):
		mm.call("cleanup_mod_hud", main_ref.hud, Callable(self, "_on_hud_action"), ["airborne_hq"])
	_cleanup_nodes()
	if mm != null:
		if mm.has_method("unregister_texture"):
			mm.call("unregister_texture", "icon_vdv_hq")
			mm.call("unregister_texture", "icon_mi8")
			mm.call("unregister_texture", "icon_il76")
			mm.call("unregister_texture", "icon_vdv_desant")
		if mm.has_method("unregister_hook"):
			mm.call("unregister_hook", "on_world_started", Callable(self, "_on_world_started"))
			mm.call("unregister_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[AirborneAssault] Mod cleaned up.")

func _cleanup_nodes() -> void:
	is_placing_hq = false
	selected_hq = null
	targeting_op = ""
	targeting_fac = null
	selected_heli = null
	active_helis.clear()
	active_planes.clear()
	active_parachutes.clear()
	active_vdv_troops.clear()
	selected_vdv_troops.clear()
	last_reported_capture = ""
	if world_layer != null and is_instance_valid(world_layer):
		world_layer.queue_free()
		world_layer = null

func _ensure_hud(main: Node, world: Node) -> void:
	if main == null or not is_instance_valid(main) or world == null or not is_instance_valid(world):
		return
	main_ref = main
	world_ref = world

	# 1. Встраивание слота постройки в нативную вкладку «АРМИЯ» (Tab 4)
	if main.hud != null and main.hud.pages.size() > 4:
		var army_grid = main.hud.pages[4] as GridContainer
		if army_grid != null:
			var need_add: bool = true
			if main.hud.keys.has("airborne_hq"):
				var existing = main.hud.keys["airborne_hq"]
				if existing != null and is_instance_valid(existing) and existing.is_inside_tree():
					need_add = false
				else:
					main.hud.keys.erase("airborne_hq")
			if need_add:
				var cell = main.hud._cell("airborne_hq", "icon_vdv_hq", true)
				if main.hud.key_labels.has("airborne_hq"):
					var lbl = main.hud.key_labels["airborne_hq"] as Label
					if lbl != null:
						lbl.text = "ШТАБ ВДВ"
						BuildPanel.fit(lbl, BuildPanel.CELL_W, BuildPanel.KEY_FONT)
				army_grid.add_child(cell)
				army_grid.move_child(cell, mini(army_grid.get_child_count() - 1, 2))

		# Подключение к сигналу действий HUD
		if not main.hud.action.is_connected(_on_hud_action):
			main.hud.action.connect(_on_hud_action)

	# 2. Слой мира для отображения сетки постройки, вертолётов, тросов, парашютов и выделения
	if world_layer == null or not is_instance_valid(world_layer):
		world_layer = AirborneAssaultWorldLayer.new()
		world_layer.setup(self, main, world)
		world.add_child(world_layer)

func _on_world_started(main: Node, world: Node) -> void:
	_cleanup_nodes()
	_ensure_hud(main, world)
	print("[AirborneAssault] Injected airborne_hq into Army tab. World layer attached.")

# ==============================================================================
# Генерация аутентичных пиксельных иконок для интерфейса игры
# ==============================================================================
func _create_and_register_icons(mm: Node) -> void:
	if mm == null or not mm.has_method("register_texture"):
		return

	# 1. Иконка Штаба ВДВ (вертолётная площадка с буквой H и шевроном)
	var img_hq = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img_hq.fill(Color(0, 0, 0, 0))
	for y in range(4, 28):
		for x in range(4, 28):
			var d = Vector2(x - 15.5, y - 15.5).length()
			if d <= 12.0:
				if d >= 10.5:
					img_hq.set_pixel(x, y, Color(0.9, 0.75, 0.2, 1.0))
				else:
					img_hq.set_pixel(x, y, Color(0.14, 0.16, 0.18, 0.95))
	for y in range(9, 23):
		for x in range(11, 14):
			img_hq.set_pixel(x, y, Color(0.95, 0.85, 0.3, 1.0))
		for x in range(18, 21):
			img_hq.set_pixel(x, y, Color(0.95, 0.85, 0.3, 1.0))
	for y in range(14, 18):
		for x in range(14, 18):
			img_hq.set_pixel(x, y, Color(0.95, 0.85, 0.3, 1.0))
	for i in range(5):
		img_hq.set_pixel(6 + i, 6 + i, Color(0.2, 0.8, 1.0, 0.9))
		img_hq.set_pixel(25 - i, 6 + i, Color(0.2, 0.8, 1.0, 0.9))
	mm.call("register_texture", "icon_vdv_hq", ImageTexture.create_from_image(img_hq))

	# 2. Иконка вертолёта Ми-8
	var img_mi8 = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img_mi8.fill(Color(0, 0, 0, 0))
	for x in range(3, 29):
		img_mi8.set_pixel(x, 7, Color(0.75, 0.82, 0.9, 0.85))
	for y in range(8, 11):
		img_mi8.set_pixel(15, y, Color(0.4, 0.45, 0.5, 1.0))
		img_mi8.set_pixel(16, y, Color(0.4, 0.45, 0.5, 1.0))
	for y in range(11, 19):
		for x in range(8, 22):
			img_mi8.set_pixel(x, y, Color(0.24, 0.34, 0.28, 1.0))
	for y in range(12, 17):
		for x in range(6, 10):
			img_mi8.set_pixel(x, y, Color(0.25, 0.75, 0.95, 1.0))
	for y in range(13, 16):
		for x in range(22, 28):
			img_mi8.set_pixel(x, y, Color(0.24, 0.34, 0.28, 1.0))
	for y in range(9, 19):
		img_mi8.set_pixel(28, y, Color(0.9, 0.6, 0.1, 0.95))
	img_mi8.set_pixel(10, 20, Color(0.15, 0.15, 0.15, 1.0))
	img_mi8.set_pixel(11, 20, Color(0.15, 0.15, 0.15, 1.0))
	img_mi8.set_pixel(18, 20, Color(0.15, 0.15, 0.15, 1.0))
	img_mi8.set_pixel(19, 20, Color(0.15, 0.15, 0.15, 1.0))
	mm.call("register_texture", "icon_mi8", ImageTexture.create_from_image(img_mi8))

	# 3. Иконка транспортного самолёта Ил-76
	var img_il76 = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img_il76.fill(Color(0, 0, 0, 0))
	for y in range(4, 28):
		for x in range(14, 18):
			img_il76.set_pixel(x, y, Color(0.7, 0.75, 0.8, 1.0))
	img_il76.set_pixel(15, 3, Color(0.2, 0.7, 0.95, 1.0))
	img_il76.set_pixel(16, 3, Color(0.2, 0.7, 0.95, 1.0))
	for x in range(3, 29):
		var y_w = 14 + int(abs(x - 15.5) * 0.35)
		for dy in range(3):
			img_il76.set_pixel(x, y_w + dy, Color(0.55, 0.62, 0.68, 1.0))
	for eng_x in [7, 11, 20, 24]:
		for y in range(16, 20):
			img_il76.set_pixel(eng_x, y, Color(0.2, 0.22, 0.25, 1.0))
	for x in range(10, 22):
		for y in range(26, 28):
			img_il76.set_pixel(x, y, Color(0.65, 0.7, 0.76, 1.0))
	mm.call("register_texture", "icon_il76", ImageTexture.create_from_image(img_il76))

	# 4. Иконка воздушного десанта
	var img_desant = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img_desant.fill(Color(0, 0, 0, 0))
	for y in range(4, 13):
		for x in range(6, 26):
			var dy = float(y - 4) / 9.0
			var dx = abs(float(x - 15.5) / 10.0)
			if dx * dx + dy * dy <= 1.0:
				if x % 4 < 2:
					img_desant.set_pixel(x, y, Color(0.95, 0.95, 0.95, 1.0))
				else:
					img_desant.set_pixel(x, y, Color(0.25, 0.65, 0.9, 1.0))
	for i in range(7):
		var t = float(i) / 6.0
		img_desant.set_pixel(int(lerpf(7.0, 15.5, t)), int(lerpf(13.0, 21.0, t)), Color(0.8, 0.8, 0.8, 0.7))
		img_desant.set_pixel(int(lerpf(24.0, 15.5, t)), int(lerpf(13.0, 21.0, t)), Color(0.8, 0.8, 0.8, 0.7))
	for y in range(21, 27):
		for x in range(14, 18):
			img_desant.set_pixel(x, y, Color(0.2, 0.35, 0.22, 1.0))
	img_desant.set_pixel(15, 21, Color(0.2, 0.7, 0.9, 1.0))
	img_desant.set_pixel(16, 21, Color(0.2, 0.7, 0.9, 1.0))
	mm.call("register_texture", "icon_vdv_desant", ImageTexture.create_from_image(img_desant))

# ==============================================================================
# Обработка действий нативного интерфейса игры
# ==============================================================================
func _on_hud_action(nm: String) -> void:
	match nm:
		"airborne_hq":
			if main_ref != null and main_ref.hud != null:
				main_ref.hud.show_tip(
					"Штаб ВДВ и вертолётная база",
					"Тактическая авиабаза сил быстрого реагирования. Готовит вертолёты Ми-8 для точечной высадки спецназа и самолёты Ил-76 для сброса техники БМД. 1400 $ · металл 15. Требует электричество.",
					""
				)
			toggle_hq_placement()

		"vdv_prep_mi8":
			if selected_hq != null:
				_order_preparation(selected_hq, "mi8")

		"vdv_launch_mi8":
			if selected_hq != null:
				_start_targeting(selected_hq, "mi8")

		"vdv_prep_il76":
			if selected_hq != null:
				_order_preparation(selected_hq, "il76")

		"vdv_launch_il76":
			if selected_hq != null:
				_start_targeting(selected_hq, "il76")

		"vdv_order_storm":
			if selected_hq != null:
				_start_targeting(selected_hq, "vdv_order_all")

		"vdv_repair":
			if selected_hq != null:
				_repair_hq(selected_hq)

		"vdv_demolish":
			if selected_hq != null:
				_demolish_hq(selected_hq)

func _on_match_tick(main: Node, world: Node, delta: float) -> void:
	main_ref = main
	world_ref = world

	if main != null and (main.hud == null or not main.hud.keys.has("airborne_hq") or not is_instance_valid(main.hud.keys["airborne_hq"]) or not main.hud.keys["airborne_hq"].is_inside_tree() or world_layer == null):
		_ensure_hud(main, world)

	var time_scale: float = 1.0
	if world != null and "time_scale" in world:
		time_scale = maxf(0.0, float(world.time_scale))
	var sim_delta: float = delta * time_scale

	if sim_delta > 0.0:
		_tick_hqs(sim_delta)
		_tick_helis(sim_delta)
		_tick_planes(sim_delta)
		_tick_parachutes(sim_delta)
		_tick_vdv_ai(sim_delta)

	# Обновление нативной карточки здания внизу экрана, если выбран наш штаб ВДВ
	if main != null and "selected_fac" in main and main.selected_fac != null and is_instance_valid(main.selected_fac):
		var f: Facility = main.selected_fac as Facility
		if f != null and f.has_meta("is_vdv_hq") and f.get_meta("is_vdv_hq"):
			selected_hq = f
			_update_native_card(f)
		else:
			if selected_hq != null and selected_hq == f:
				selected_hq = null
	else:
		selected_hq = null

	if world_layer != null and is_instance_valid(world_layer):
		world_layer.queue_redraw()

# ==============================================================================
# Режим строительства Штаба ВДВ
# ==============================================================================
func toggle_hq_placement() -> void:
	if is_placing_hq:
		cancel_hq_placement()
	else:
		start_hq_placement()

func start_hq_placement() -> void:
	if world_ref == null or not is_instance_valid(world_ref):
		return
	var p = world_ref.player
	if p == null:
		return

	if p.money < HQ_COST_MONEY or p.metal < HQ_COST_METAL:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает ресурсов: 1400 $ и 15 металла!")
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	is_placing_hq = true
	targeting_op = ""
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.set_key_pressed("airborne_hq", true)
		main_ref.hud.show_toast("ШТАБ ВДВ: Выберите место на своей территории для вертолётной площадки")

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_select")

func cancel_hq_placement() -> void:
	is_placing_hq = false
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.set_key_pressed("airborne_hq", false)

func can_place_hq_at(cell: Vector2i) -> bool:
	if world_ref == null or not is_instance_valid(world_ref):
		return false
	var d = world_ref.data
	if d == null:
		return false

	if cell.x < 3 or cell.y < 3 or cell.x + HQ_SIZE.x >= d.w - 3 or cell.y + HQ_SIZE.y >= d.h - 3:
		return false

	var player = world_ref.player
	if player == null:
		return false

	for dy in range(HQ_SIZE.y):
		for dx in range(HQ_SIZE.x):
			var cx = cell.x + dx
			var cy = cell.y + dy

			var own = d.get_owner_id(cx, cy) if d.has_method("get_owner_id") else d.get_owner(cx, cy)
			if own != player.id:
				return false

			var b = d.get_biome(cx, cy)
			if Biome.is_water(b):
				return false

			if d.has_flag(cx, cy, WorldData.F_OCCUPIED):
				return false

	return true

func place_hq_at(cell: Vector2i) -> void:
	if not can_place_hq_at(cell):
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Нельзя построить здесь: нужна свободная суша на вашей земле")
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	var p = world_ref.player
	if p.money < HQ_COST_MONEY or p.metal < HQ_COST_METAL:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает: 1400 $ и 15 металла!")
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	p.money -= HQ_COST_MONEY
	p.metal -= HQ_COST_METAL

	var f = Facility.new()
	f.id = world_ref.mil.facilities.size()
	f.kind = Facility.Kind.CIV_FACTORY
	f.country_id = p.id
	f.cell = cell
	f.size = HQ_SIZE
	f.powered = true
	var grp_id = _get_next_hq_group()
	f.set_meta("is_vdv_hq", true)
	f.set_meta("vdv_group", grp_id)
	f.army_no = grp_id
	f.group_id = grp_id
	f.army_build = "airborne_hq"
	f.lower_sprite = "airborne_hq"
	f.set_meta("hp", HQ_MAX_HP)
	f.set_meta("max_hp", HQ_MAX_HP)
	f.set_meta("mi8_ready", 1)
	f.set_meta("il76_ready", 1)
	f.set_meta("mi8_reload_t", 0.0)
	f.set_meta("il76_reload_t", 0.0)
	f.set_meta("prep_op", "")
	f.set_meta("active_heli", null)
	f.set_meta("antenna_t", 0.0)

	f.main_obj = world_ref.add_object("barracks", cell, GameWorld.KIND_BUILDING)
	f.obj_ids.append(f.main_obj)
	world_ref.mil.facilities.append(f)

	var d = world_ref.data
	for dy in range(f.size.y):
		for dx in range(f.size.x):
			var cx = cell.x + dx
			var cy = cell.y + dy
			world_ref.remove_tree_at(Vector2i(cx, cy))
			d.add_flag(cx, cy, WorldData.F_OCCUPIED)
			d.set_biome(cx, cy, Biome.PLAZA)

	cancel_hq_placement()

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_build")
	if world_ref.fx != null:
		world_ref.fx.spawn("dust_s", Vector2(cell * GameWorld.CELL + Vector2i(18, 12)), 8)

	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Штаб ВДВ (Группа #%d) и вертолётная площадка готовы к службе!" % grp_id)
		main_ref.selected_fac = f

func _get_next_hq_group() -> int:
	var used: Dictionary = {}
	if world_ref != null and "mil" in world_ref and world_ref.mil != null:
		for fac in world_ref.mil.facilities:
			if fac is Facility and fac.has_meta("is_vdv_hq") and fac.get_meta("is_vdv_hq"):
				var gid = int(fac.get_meta("vdv_group", 0))
				if gid > 0:
					used[gid] = true
	var g: int = 1
	while used.has(g):
		g += 1
	return g

static func _group_color(g: int) -> Color:
	match (g - 1) % 6:
		0: return Color(0.25, 0.85, 1.0) # Голубой ВДВ (Группа #1)
		1: return Color(1.0, 0.65, 0.15) # Оранжевый (Группа #2)
		2: return Color(0.35, 1.0, 0.35) # Салатовый (Группа #3)
		3: return Color(0.9, 0.45, 1.0)  # Фиолетовый (Группа #4)
		4: return Color(1.0, 0.3, 0.3)   # Красный (Группа #5)
		_: return Color(1.0, 0.9, 0.25)  # Золотой (Группа #6+)

# ==============================================================================
# Жизненный цикл штабов ВДВ (Энергия, подготовка бортов)
# ==============================================================================
func _tick_hqs(delta: float) -> void:
	if world_ref == null or not is_instance_valid(world_ref):
		return
	if not ("mil" in world_ref and world_ref.mil != null):
		return

	for f in world_ref.mil.facilities:
		if not (f is Facility and f.has_meta("is_vdv_hq") and f.get_meta("is_vdv_hq")):
			continue

		var grp_id = int(f.get_meta("vdv_group", 0))
		if grp_id <= 0:
			grp_id = _get_next_hq_group()
			f.set_meta("vdv_group", grp_id)
		f.army_no = grp_id
		f.group_id = grp_id
		f.army_build = "airborne_hq"
		f.lower_sprite = "airborne_hq"

		var is_powered = true
		if not is_powered:
			continue

		# 1. Автоперезарядка вертолёта Ми-8 «Терминатор»
		var cur_mi8 = int(f.get_meta("mi8_ready", 0))
		if cur_mi8 < MI8_MAX_LIMIT:
			var mi8_t = float(f.get_meta("mi8_reload_t", 0.0)) + delta
			if mi8_t >= MI8_PREP_TIME:
				mi8_t = 0.0
				cur_mi8 += 1
				f.set_meta("mi8_ready", cur_mi8)
				if main_ref != null and main_ref.hud != null:
					main_ref.hud.show_toast("Штаб ВДВ %d: Вертолёт Ми-8 готов к вылету (%d/%d)!" % [grp_id, cur_mi8, MI8_MAX_LIMIT])
				if ClassDB.class_exists("UiKit"):
					UiKit.snd("ui_build")
			f.set_meta("mi8_reload_t", mi8_t)
		else:
			f.set_meta("mi8_reload_t", 0.0)

		# 2. Автоперезарядка транспортного самолёта Ил-76 «Десантник»
		var cur_il76 = int(f.get_meta("il76_ready", 0))
		if cur_il76 < IL76_MAX_LIMIT:
			var il76_t = float(f.get_meta("il76_reload_t", 0.0)) + delta
			if il76_t >= IL76_PREP_TIME:
				il76_t = 0.0
				cur_il76 += 1
				f.set_meta("il76_ready", cur_il76)
				if main_ref != null and main_ref.hud != null:
					main_ref.hud.show_toast("Штаб ВДВ %d: Самолёт Ил-76 готов к десанту (%d/%d)!" % [grp_id, cur_il76, IL76_MAX_LIMIT])
				if ClassDB.class_exists("UiKit"):
					UiKit.snd("ui_build")
			f.set_meta("il76_reload_t", il76_t)
		else:
			f.set_meta("il76_reload_t", 0.0)

# ==============================================================================
# Заказ подготовки авиации и нативная карточка здания
# ==============================================================================
func _order_preparation(f: Facility, op_type: String) -> void:
	var p = world_ref.player
	var cost_m = 0
	var cost_met = 0
	var prep_dur = 0.0

	if op_type == "mi8":
		cost_m = MI8_COST_MONEY
		cost_met = MI8_COST_METAL
		prep_dur = MI8_PREP_TIME
		if int(f.get_meta("mi8_ready", 0)) >= MI8_MAX_LIMIT:
			if main_ref != null and main_ref.hud != null:
				main_ref.hud.show_toast("Достигнут лимит вертолётов Ми-8 на площадке (макс. %d)!" % MI8_MAX_LIMIT)
			return
	elif op_type == "il76":
		cost_m = IL76_COST_MONEY
		cost_met = IL76_COST_METAL
		prep_dur = IL76_PREP_TIME
		if int(f.get_meta("il76_ready", 0)) >= IL76_MAX_LIMIT:
			if main_ref != null and main_ref.hud != null:
				main_ref.hud.show_toast("Достигнут лимит самолётов Ил-76 (макс. %d)!" % IL76_MAX_LIMIT)
			return

	if p.money < cost_m or p.metal < cost_met:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает ресурсов: требуется %d $ и %d металла!" % [cost_m, cost_met])
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	p.money -= cost_m
	p.metal -= cost_met

	f.set_meta("prep_op", op_type)
	f.set_meta("prep_t", 0.0)
	f.set_meta("prep_dur", prep_dur)

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_build")

	if main_ref != null and main_ref.hud != null:
		var name_str = "Ми-8 «Терминатор»" if op_type == "mi8" else "Ил-76 «Десантник»"
		main_ref.hud.show_toast("Начата подготовка и вооружение: %s" % name_str)

func _start_targeting(f: Facility, op_type: String) -> void:
	if op_type == "vdv_order_all":
		if active_vdv_troops.is_empty():
			if main_ref != null and main_ref.hud != null:
				main_ref.hud.show_toast("Нет высаженных бойцов ВДВ! Сначала отправьте вертолёт или самолёт с десантом.")
			return
		targeting_op = "vdv_order_all"
		targeting_fac = f
		is_placing_hq = false
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_select")
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("ПРИКАЗ ВДВ: Кликните ЛКМ по любой точке или городу на карте для общего наступления!")
		return

	var is_powered = true

	if op_type == "mi8":
		if int(f.get_meta("mi8_ready", 0)) <= 0:
			return
		if f.get_meta("active_heli") != null:
			if main_ref != null and main_ref.hud != null:
				main_ref.hud.show_toast("Вертолёт уже в воздухе! Дождитесь завершения высадки или возвращения.")
			return
	elif op_type == "il76":
		if int(f.get_meta("il76_ready", 0)) <= 0:
			return

	if targeting_op == op_type and targeting_fac == f:
		cancel_targeting()
		return

	targeting_op = op_type
	targeting_fac = f
	is_placing_hq = false

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_select")

	if main_ref != null and main_ref.hud != null:
		var tip = "МИ-8: Выберите точку высадки спецназа на карте (ЛКМ - пуск, ПКМ - отмена)" if op_type == "mi8" else "ИЛ-76: Выберите район парашютного сброса БМД на карте (ЛКМ - пуск, ПКМ - отмена)"
		main_ref.hud.show_toast(tip)

func cancel_targeting() -> void:
	targeting_op = ""
	targeting_fac = null

func _repair_hq(f: Facility) -> void:
	var p = world_ref.player
	var rep_cost = 150
	if p.money < rep_cost:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает средств на ремонт штаба: требуется %d $!" % rep_cost)
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	p.money -= rep_cost
	f.set_meta("hp", HQ_MAX_HP)

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_build")

	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Штаб ВДВ и площадка полностью отремонтированы!")

func _demolish_hq(f: Facility) -> void:
	var p = world_ref.player
	p.money += 700

	var d = world_ref.data
	for dy in range(f.size.y):
		for dx in range(f.size.x):
			var cx = f.cell.x + dx
			var cy = f.cell.y + dy
			d.clear_flag(cx, cy, WorldData.F_OCCUPIED)

	if f.main_obj >= 0:
		world_ref.remove_object(f.main_obj)

	world_ref.mil.facilities.erase(f)

	if main_ref != null:
		main_ref.call("_deselect")
		if main_ref.hud != null:
			main_ref.hud.show_toast("Штаб ВДВ демонтирован (+700 $)")

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_click")

# ==============================================================================
# Отрисовка нативной карточки Штаба ВДВ
# ==============================================================================
func _update_native_card(f: Facility) -> void:
	if main_ref == null or main_ref.hud == null:
		return

	var p = world_ref.player
	var prep_op = String(f.get_meta("prep_op", ""))
	var prep_t = float(f.get_meta("prep_t", 0.0))
	var prep_dur = float(f.get_meta("prep_dur", 1.0))
	var mi8_ready = int(f.get_meta("mi8_ready", 0))
	var il76_ready = int(f.get_meta("il76_ready", 0))
	var hp = float(f.get_meta("hp", HQ_MAX_HP))
	var max_hp = float(f.get_meta("max_hp", HQ_MAX_HP))

	var is_powered = true
	var active_heli = f.get_meta("active_heli")

	var grp_id = int(f.get_meta("vdv_group", 1))
	var my_troops: Array = []
	for u in active_vdv_troops:
		if u != null and is_instance_valid(u) and ("alive" in u and u.alive()):
			if int(u.get_meta("vdv_group", 1)) == grp_id:
				my_troops.append(u)

	main_ref.hud._card(
		"vdv_hq_%d" % f.id,
		"icon_vdv_hq",
		"ШТАБ ВДВ · ГРУППА #%d" % grp_id,
		"ДЕЙСТВУЕТ В ПОЛЕ: %d БОЙЦОВ/ТЕХНИКИ" % my_troops.size(),
		false,
		false,
		true
	)

	var acts: Array = []

	# Кнопка 1: Вертолёт Ми-8 «Терминатор» (автоперезарядка)
	if mi8_ready > 0:
		var can_fly = is_powered and active_heli == null
		acts.append(main_ref.hud._act(
			"ВЫЛЕТ\nМИ-8 (%d)" % mi8_ready,
			"icon_mi8",
			"vdv_launch_mi8",
			can_fly,
			1 if targeting_op == "mi8" else 0
		))
	else:
		var mi8_rem = maxf(0.0, MI8_PREP_TIME - float(f.get_meta("mi8_reload_t", 0.0)))
		acts.append(main_ref.hud._act(
			"МИ-8\n%s" % main_ref.hud._mmss(mi8_rem),
			"icon_mi8",
			"",
			false,
			1
		))

	# Кнопка 2: Самолёт Ил-76 «Десантник» (автоперезарядка)
	if il76_ready > 0:
		acts.append(main_ref.hud._act(
			"СБРОС\nИЛ-76 (%d)" % il76_ready,
			"icon_il76",
			"vdv_launch_il76",
			is_powered,
			1 if targeting_op == "il76" else 0
		))
	else:
		var il76_rem = maxf(0.0, IL76_PREP_TIME - float(f.get_meta("il76_reload_t", 0.0)))
		acts.append(main_ref.hud._act(
			"ИЛ-76\n%s" % main_ref.hud._mmss(il76_rem),
			"icon_il76",
			"",
			false,
			1
		))

	# Кнопка 3: Приказ штурма для бойцов этой конкретной группы
	if my_troops.size() > 0:
		acts.append(main_ref.hud._act(
			"ШТУРМ ГР.%d\n(%d)" % [grp_id, my_troops.size()],
			"icon_vdv_desant",
			"vdv_order_storm",
			true,
			1 if targeting_op == "vdv_order_all" else 0
		))

	# Кнопка 4: Ремонт базы
	var can_rep = hp < max_hp - 1.0 and p.money >= 150
	acts.append(main_ref.hud._act(
		"РЕМОНТ\n150 $",
		"icon_restore",
		"vdv_repair",
		can_rep
	))

	# Кнопка 5: Снос базы
	var dact = main_ref.hud._act("СНОС\n+700 $", "icon_close", "vdv_demolish", true)
	dact["red"] = true
	acts.append(dact)

	var status_str = ""
	var is_alert = false

	if not is_powered:
		status_str = "ОБЪЕКТ ОБЕСТОЧЕН (НЕТ ЭЛЕКТРОЭНЕРГИИ) · ПРОЧНОСТЬ %d/%d" % [int(hp), int(max_hp)]
		is_alert = true
	elif active_heli != null and is_instance_valid(active_heli):
		status_str = "МИ-8 В ВОЗДУХЕ · СТАТУС: %s" % active_heli.get_status_text()
	elif mi8_ready < MI8_MAX_LIMIT or il76_ready < IL76_MAX_LIMIT:
		status_str = "АВТОПЕРЕЗАРЯДКА АВИАЦИИ · МИ-8: %d/%d · ИЛ-76: %d/%d" % [mi8_ready, MI8_MAX_LIMIT, il76_ready, IL76_MAX_LIMIT]
	elif my_troops.size() > 0:
		status_str = "ГРУППА ВДВ %d В ПОЛЕ: %d БОЙЦОВ/ТЕХНИКИ · ШТУРМ И ЗАЧИСТКА ТЫЛА" % [grp_id, my_troops.size()]
	else:
		status_str = "ГОТОВ К ВЫЛЕТУ · МИ-8: %d/%d · ИЛ-76: %d/%d · ПРОЧНОСТЬ %d/%d" % [
			mi8_ready, MI8_MAX_LIMIT, il76_ready, IL76_MAX_LIMIT, int(hp), int(max_hp)
		]

	main_ref.hud._set_info(status_str, is_alert or hp <= 0.0)
	main_ref.hud.ops_detail.text = "Штаб ВДВ (Десантно-штурмовая группа ВДВ %d). Автоперезарядка вертолётов и самолётов включена. Выделите бойцов на карте для управления или нажмите [ШТУРМ ВДВ %d] для атаки." % [grp_id, grp_id]
	main_ref.hud.ops_detail.visible = true
	main_ref.hud._fill_acts("vdv_hq_%d" % f.id, acts)

# ==============================================================================
# Запуск операций (Вертолёт Ми-8, Самолёт Ил-76 и Приказ Штурма)
# ==============================================================================
func launch_operation_at(target_pos: Vector2) -> void:
	if targeting_op == "vdv_order_all":
		order_group_vdv_assault(targeting_fac, target_pos)
		cancel_targeting()
		return

	if targeting_fac == null or not is_instance_valid(targeting_fac):
		cancel_targeting()
		return

	var f = targeting_fac
	if targeting_op == "mi8":
		var cur_mi8 = int(f.get_meta("mi8_ready", 0))
		if cur_mi8 <= 0:
			cancel_targeting()
			return
		f.set_meta("mi8_ready", cur_mi8 - 1)

		var h_pos = Vector2(f.cell * GameWorld.CELL) + Vector2(float(f.size.x * GameWorld.CELL) * 0.5, float(f.size.y * GameWorld.CELL) * 0.5)
		var heli = VdvHelicopter.new()
		heli.setup(self, f, h_pos, target_pos)
		active_helis.append(heli)
		f.set_meta("active_heli", heli)

		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_select")
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Ми-8 (Группа #%d) поднялся с площадки и взял курс на цель!" % int(f.get_meta("vdv_group", 1)))

	elif targeting_op == "il76":
		var cur_il76 = int(f.get_meta("il76_ready", 0))
		if cur_il76 <= 0:
			cancel_targeting()
			return
		f.set_meta("il76_ready", cur_il76 - 1)

		var plane = VdvCargoPlane.new()
		plane.setup(self, f, target_pos)
		active_planes.append(plane)

		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_select")
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Тяжёлый десантный Ил-76 (Группа #%d) заходит в зону сброса техники!" % int(f.get_meta("vdv_group", 1)))

	cancel_targeting()

func order_group_vdv_assault(fac: Facility, target_pos: Vector2) -> void:
	if active_vdv_troops.is_empty():
		return
	var grp_id: int = int(fac.get_meta("vdv_group", 1)) if fac != null and is_instance_valid(fac) else 1

	var count = 0
	for u in active_vdv_troops:
		if u == null or not is_instance_valid(u) or not ("alive" in u and u.alive()):
			continue
		if int(u.get_meta("vdv_group", 1)) != grp_id:
			continue

		var offset = Vector2.RIGHT.rotated(float(count) * 0.9) * float((count % 4) * 8)
		var final_pos = target_pos + offset
		_assign_unit_path(u, final_pos)
		u.set_meta("manual_order", true)
		u.set_meta("manual_target", target_pos)
		count += 1

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_build")
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("ШТАБ ВДВ: Десантно-штурмовой группе #%d (%d бойцов) отдан приказ на штурм!" % [grp_id, count])

# ==============================================================================
# Жизненный цикл авиации и парашютистов
# ==============================================================================
func _tick_helis(delta: float) -> void:
	var remove_list: Array = []
	for h in active_helis:
		if h == null or not is_instance_valid(h):
			remove_list.append(h)
			continue
		h.tick(delta)
		if h.is_finished:
			remove_list.append(h)
			if h.hq_ref != null and is_instance_valid(h.hq_ref):
				h.hq_ref.set_meta("active_heli", null)
			if selected_heli == h:
				selected_heli = null

	for h in remove_list:
		active_helis.erase(h)

func _tick_planes(delta: float) -> void:
	var remove_list: Array = []
	for p in active_planes:
		if p == null or not is_instance_valid(p):
			remove_list.append(p)
			continue
		p.tick(delta)
		if p.is_finished:
			remove_list.append(p)

	for p in remove_list:
		active_planes.erase(p)

func _tick_parachutes(delta: float) -> void:
	var remove_list: Array = []
	for para in active_parachutes:
		if para == null or not is_instance_valid(para):
			remove_list.append(para)
			continue
		para.tick(delta)
		if para.is_finished:
			remove_list.append(para)

	for para in remove_list:
		active_parachutes.erase(para)

# ==============================================================================
# Автономный боевой интеллект бойцов ВДВ и поддержка кампании
# ==============================================================================
func _tick_vdv_ai(delta: float) -> void:
	if world_ref == null or not is_instance_valid(world_ref):
		return
	if not ("army" in world_ref and world_ref.army != null):
		return

	var alive_troops: Array = []
	var player = world_ref.player
	var player_id = player.id if player != null else 0

	for u in active_vdv_troops:
		if u == null or not is_instance_valid(u):
			continue
		if not ("alive" in u and u.alive()):
			continue
		alive_troops.append(u)

		# Привязка номера группы и команды
		var u_grp = int(u.get_meta("vdv_group", 0))
		if u_grp <= 0:
			if u.home != null and is_instance_valid(u.home) and u.home.has_meta("vdv_group"):
				u_grp = int(u.home.get_meta("vdv_group", 1))
			else:
				u_grp = 1
			u.set_meta("vdv_group", u_grp)
		u.team = u_grp

		# Полевая медицина спецназа
		var medic_t = float(u.get_meta("medic_t", 0.0)) + delta
		if medic_t >= 2.0:
			medic_t = 0.0
			if u.hp < u.max_hp:
				u.hp = minf(u.max_hp, u.hp + 4.0)
		u.set_meta("medic_t", medic_t)

		# Проверка ручного приказа игрока
		if u.get_meta("manual_order", false):
			var mt = u.get_meta("manual_target", Vector2.ZERO) as Vector2
			if u.pos.distance_to(mt) <= 24.0 or u.state == Unit.State.IDLE or u.path.is_empty():
				# Достигли назначенной точки или выполнили приказ — переходим в автономный режим
				u.set_meta("manual_order", false)

		# Автономное принятие тактических решений при простое
		if not u.get_meta("manual_order", false):
			if u.state == Unit.State.IDLE or u.path.is_empty():
				var ai_think_t = float(u.get_meta("ai_think_t", 0.0)) + delta
				if ai_think_t >= 1.2:
					ai_think_t = 0.0
					_execute_trooper_campaign_behavior(u, player_id)
				u.set_meta("ai_think_t", ai_think_t)

	active_vdv_troops = alive_troops

	# Очистка выделения от погибших бойцов
	var alive_selected: Array = []
	for sel_u in selected_vdv_troops:
		if sel_u != null and is_instance_valid(sel_u) and ("alive" in sel_u and sel_u.alive()):
			alive_selected.append(sel_u)
	selected_vdv_troops = alive_selected

	# Пополнение и ремонт в освобождённых городах каждые 4 секунды
	vdv_city_restock_t += delta
	if vdv_city_restock_t >= 4.0 and not active_vdv_troops.is_empty():
		vdv_city_restock_t = 0.0
		_check_city_restock_and_reinforce(player_id)

func _check_city_restock_and_reinforce(player_id: int) -> void:
	if "cities" not in world_ref or world_ref.cities == null:
		return

	for c in world_ref.cities:
		if c == null or c.country_id != player_id:
			continue

		var c_pos = Vector2(c.center * GameWorld.CELL)
		var near_vdv: Array = []
		for u in active_vdv_troops:
			if u.pos.distance_to(c_pos) <= 65.0:
				near_vdv.append(u)

		if near_vdv.is_empty():
			continue

		# Полное лечение и ремонт отряда в городе
		for u in near_vdv:
			u.hp = u.max_hp

		# Если отряд потерял бойцов (меньше 5) — город предоставляет добровольца
		if active_vdv_troops.size() < 12:
			var squad_lead = near_vdv[0] if not near_vdv.is_empty() else null
			var grp_id = int(squad_lead.get_meta("vdv_group", 1)) if squad_lead != null else 1
			var recruit = Unit.new()
			recruit.id = world_ref.army._next_id
			world_ref.army._next_id += 1
			recruit.type = Unit.Type.ASSAULT
			recruit.hp = 70.0
			recruit.max_hp = 70.0
			recruit.country_id = player_id
			recruit.home = squad_lead.home if squad_lead != null else selected_hq
			recruit.pos = c_pos + Vector2.RIGHT.rotated(randf() * TAU) * 12.0
			recruit.heading = randf() * TAU
			recruit.update_frame()
			recruit.state = Unit.State.IDLE
			recruit.set_meta("is_vdv_trooper", true)
			recruit.set_meta("vdv_group", grp_id)
			recruit.team = grp_id

			world_ref.army.units.append(recruit)
			active_vdv_troops.append(recruit)

			if main_ref != null and main_ref.hud != null:
				main_ref.hud.show_toast("Город %s снарядил добровольца в группу #%d (+1 боец)!" % [c.name, grp_id])
			if ClassDB.class_exists("UiKit"):
				UiKit.snd("ui_build")

func _execute_trooper_campaign_behavior(u: Unit, player_id: int) -> void:
	# 1. Захват и удержание ячейки под ногами в пользу игрока
	var cell = Vector2i((u.pos / float(GameWorld.CELL)).floor())
	if world_ref.data != null and world_ref.data.inside(cell.x, cell.y):
		var cur_owner = world_ref.data.get_owner_id(cell.x, cell.y) if world_ref.data.has_method("get_owner_id") else world_ref.data.get_owner(cell.x, cell.y)
		if cur_owner != player_id:
			if world_ref.data.has_method("set_owner_id"):
				world_ref.data.set_owner_id(cell.x, cell.y, player_id)
			elif world_ref.data.has_method("set_owner"):
				world_ref.data.set_owner(cell.x, cell.y, player_id)

	# 2. Поиск ближайших вражеских юнитов в боевом радиусе 280 px
	var best_enemy_u: Unit = null
	var min_dist_u = 280.0
	for enemy in world_ref.army.units:
		if enemy == null or not enemy.alive():
			continue
		if enemy.country_id != player_id and (world_ref.mil == null or world_ref.mil.hostile(enemy.country_id, player_id)):
			var d = u.pos.distance_to(enemy.pos)
			if d < min_dist_u:
				min_dist_u = d
				best_enemy_u = enemy

	if best_enemy_u != null:
		var target_dist = 36.0 if u.type == Unit.Type.ASSAULT else 65.0
		var dir = (best_enemy_u.pos - u.pos).normalized()
		var move_to = u.pos + dir * maxf(12.0, min_dist_u - target_dist)
		_assign_unit_path(u, move_to)
		return

	# 3. ПОИСК СЛЕДУЮЩЕГО ВРАЖЕСКОГО ГОРОДА ПО ВСЕЙ КАРТЕ (радиус до 3500 px!)
	# Это гарантирует, что десант никогда не зависнет после захвата города, а продолжит наступление!
	var best_city: City = null
	var min_dist_c = 3500.0
	if "cities" in world_ref and world_ref.cities != null:
		for c in world_ref.cities:
			if c == null or c.country_id == player_id:
				continue
			if world_ref.mil != null and not world_ref.mil.hostile(c.country_id, player_id):
				continue
			var c_pos = Vector2(c.center * GameWorld.CELL)
			var d = u.pos.distance_to(c_pos)
			if d < min_dist_c:
				min_dist_c = d
				best_city = c

	if best_city != null:
		var c_pos = Vector2(best_city.center * GameWorld.CELL)
		_assign_unit_path(u, c_pos)
		u.set_meta("campaign_target_city", best_city.name)
		return

	# 4. Если все вражеские города взяты — штурм военных объектов врага (аэродромы, радары, заводы)
	if "mil" in world_ref and world_ref.mil != null and "facilities" in world_ref.mil:
		var best_fac: Facility = null
		var min_dist_f = 3500.0
		for f in world_ref.mil.facilities:
			if f == null or not world_ref.mil.alive(f) or f.country_id == player_id:
				continue
			if not world_ref.mil.hostile(f.country_id, player_id):
				continue
			var f_pos = Vector2(f.cell * GameWorld.CELL)
			var d = u.pos.distance_to(f_pos)
			if d < min_dist_f:
				min_dist_f = d
				best_fac = f

		if best_fac != null:
			var f_pos = Vector2(best_fac.cell * GameWorld.CELL)
			_assign_unit_path(u, f_pos)
			return

func _assign_unit_path(u: Unit, dest: Vector2) -> void:
	if world_ref != null and "econ" in world_ref and world_ref.econ != null and world_ref.econ.has_method("nav_path"):
		var p: PackedVector2Array = world_ref.econ.nav_path(u.pos, dest)
		if not p.is_empty():
			u.path = p
			u.pi = 0
			u.state = Unit.State.MOVE
			return

	u.path = PackedVector2Array([dest])
	u.pi = 0
	u.state = Unit.State.MOVE

# ==============================================================================
# Класс вертолёта Ми-8 (Тактический десант, спуск на тросах, управляемость в полёте)
# ==============================================================================
class VdvHelicopter extends RefCounted:
	var mod_ref: RefCounted = null
	var hq_ref: Facility = null

	var pos: Vector2 = Vector2.ZERO
	var target_pos: Vector2 = Vector2.ZERO
	var base_pos: Vector2 = Vector2.ZERO

	var heading: float = 0.0
	var speed: float = 44.0
	var alt: float = 0.0
	var rotor_angle: float = 0.0

	enum State { TAKEOFF, FLY_TO_LZ, HOVER_DESCEND, FAST_ROPING, CLIMB, RTB, LANDING, DONE }
	var state: int = State.TAKEOFF

	var roping_timer: float = 0.0
	var dropped_count: int = 0
	var is_finished: bool = false
	var dust_timer: float = 0.0

	func setup(m: RefCounted, hq: Facility, b_pos: Vector2, t_pos: Vector2) -> void:
		mod_ref = m
		hq_ref = hq
		base_pos = b_pos
		pos = b_pos
		target_pos = t_pos
		heading = (t_pos - b_pos).angle()
		alt = 0.0
		state = State.TAKEOFF

	func get_status_text() -> String:
		match state:
			State.TAKEOFF: return "ВЗЛЁТ С ПЛОЩАДКИ"
			State.FLY_TO_LZ: return "ВЫХОД В ЗОНУ ВЫСАДКИ"
			State.HOVER_DESCEND: return "СНИЖЕНИЕ И ЗАВИСАНИЕ"
			State.FAST_ROPING: return "ВЫСАДКА ДЕСАНТА НА ТРОСАХ"
			State.CLIMB: return "НАБОР ВЫСОТЫ"
			State.RTB: return "ВОЗВРАЩЕНИЕ НА БАЗУ"
			State.LANDING: return "ПОСАДКА НА ПЛОЩАДКУ"
			_: return "ЗАВЕРШЕНО"

	func tick(delta: float) -> void:
		rotor_angle += delta * 35.0
		if rotor_angle > TAU:
			rotor_angle -= TAU

		match state:
			State.TAKEOFF:
				alt = minf(16.0, alt + delta * 12.0)
				_spawn_rotor_dust(delta, 1.5)
				if alt >= 16.0:
					state = State.FLY_TO_LZ

			State.FLY_TO_LZ:
				var to_lz = target_pos - pos
				var dist = to_lz.length()
				heading = lerp_angle(heading, to_lz.angle(), delta * 3.5)
				pos += Vector2.RIGHT.rotated(heading) * (speed * delta)

				if dist <= 16.0:
					state = State.HOVER_DESCEND

			State.HOVER_DESCEND:
				alt = maxf(2.5, alt - delta * 9.0)
				_spawn_rotor_dust(delta, 0.4)
				if alt <= 2.8:
					state = State.FAST_ROPING
					roping_timer = 0.0
					dropped_count = 0

			State.FAST_ROPING:
				_spawn_rotor_dust(delta, 0.3)
				roping_timer += delta

				if roping_timer >= 0.75 and dropped_count < 4:
					roping_timer = 0.0
					dropped_count += 1
					_deploy_trooper(dropped_count)

				if dropped_count >= 4 and roping_timer >= 1.0:
					state = State.CLIMB

			State.CLIMB:
				alt = minf(16.0, alt + delta * 10.0)
				if alt >= 16.0:
					state = State.RTB

			State.RTB:
				var to_base = base_pos - pos
				var dist = to_base.length()
				heading = lerp_angle(heading, to_base.angle(), delta * 3.5)
				pos += Vector2.RIGHT.rotated(heading) * (speed * delta)

				if dist <= 12.0:
					pos = base_pos
					state = State.LANDING

			State.LANDING:
				alt = maxf(0.0, alt - delta * 8.0)
				_spawn_rotor_dust(delta, 1.5)
				if alt <= 0.0:
					alt = 0.0
					state = State.DONE
					is_finished = true

	func _spawn_rotor_dust(delta: float, rate: float) -> void:
		if mod_ref.world_ref != null and mod_ref.world_ref.fx != null:
			dust_timer += delta
			if dust_timer >= rate:
				dust_timer = 0.0
				mod_ref.world_ref.fx.spawn("dust_s", pos.round(), 4)

	func _deploy_trooper(index: int) -> void:
		if mod_ref.world_ref == null or not ("army" in mod_ref.world_ref and mod_ref.world_ref.army != null):
			return

		var p = mod_ref.world_ref.player
		var u = Unit.new()
		u.id = mod_ref.world_ref.army._next_id
		mod_ref.world_ref.army._next_id += 1

		if index in [1, 2]:
			u.type = Unit.Type.ASSAULT
			u.hp = 70.0
		elif index == 3:
			u.type = Unit.Type.ATGM
			u.hp = 45.0
		else:
			u.type = Unit.Type.INFANTRY
			u.hp = 50.0

		u.max_hp = u.hp
		u.country_id = p.id
		u.home = hq_ref
		var grp = int(hq_ref.get_meta("vdv_group", 1)) if hq_ref != null and is_instance_valid(hq_ref) else 1
		u.set_meta("vdv_group", grp)
		u.team = grp
		u.set_meta("is_vdv_trooper", true)

		var offset = Vector2.RIGHT.rotated(randf() * TAU) * float(randi_range(6, 16))
		u.pos = pos + offset
		u.heading = randf() * TAU
		u.update_frame()
		u.state = Unit.State.IDLE

		mod_ref.world_ref.army.units.append(u)
		mod_ref.active_vdv_troops.append(u)

		if mod_ref.world_ref.fx != null:
			mod_ref.world_ref.fx.spawn("dust_s", u.pos.round(), 6)
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_click")

# ==============================================================================
# Класс транспортного самолёта Ил-76 (Сброс БМД и роты десанта на парашютах)
# ==============================================================================
class VdvCargoPlane extends RefCounted:
	var mod_ref: RefCounted = null
	var hq_ref: Facility = null

	var pos: Vector2 = Vector2.ZERO
	var lz_pos: Vector2 = Vector2.ZERO
	var dir: Vector2 = Vector2.RIGHT
	var speed: float = 62.0
	var alt: float = 26.0

	var has_dropped: bool = false
	var is_finished: bool = false
	var life_time: float = 0.0

	func setup(m: RefCounted, hq: Facility, target_pos: Vector2) -> void:
		mod_ref = m
		hq_ref = hq
		lz_pos = target_pos

		dir = Vector2(1.0, 0.2).normalized()
		pos = target_pos - dir * 450.0
		has_dropped = false

	func tick(delta: float) -> void:
		life_time += delta
		pos += dir * (speed * delta)

		var dist_to_lz = pos.distance_to(lz_pos)
		if not has_dropped and (dist_to_lz <= 24.0 or (pos - lz_pos).dot(dir) > 0.0):
			has_dropped = true
			_drop_cargo()

		if life_time > 18.0:
			is_finished = true

	func _drop_cargo() -> void:
		if mod_ref == null:
			return

		var para_bmd = VdvParachuteCargo.new()
		para_bmd.setup(mod_ref, hq_ref, pos, Unit.Type.IFV, true)
		mod_ref.active_parachutes.append(para_bmd)

		var para_assault = VdvParachuteCargo.new()
		para_assault.setup(mod_ref, hq_ref, pos - dir * 18.0, Unit.Type.ASSAULT, false)
		mod_ref.active_parachutes.append(para_assault)

		var para_atgm = VdvParachuteCargo.new()
		para_atgm.setup(mod_ref, hq_ref, pos - dir * 36.0, Unit.Type.ATGM, false)
		mod_ref.active_parachutes.append(para_atgm)

		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_build")

# ==============================================================================
# Класс спускающегося парашютного груза / техники
# ==============================================================================
class VdvParachuteCargo extends RefCounted:
	var mod_ref: RefCounted = null
	var hq_ref: Facility = null

	var pos: Vector2 = Vector2.ZERO
	var alt: float = 24.0
	var unit_type: int = Unit.Type.ASSAULT
	var is_vehicle: bool = false
	var is_finished: bool = false
	var swing_phase: float = 0.0

	func setup(m: RefCounted, hq: Facility, drop_p: Vector2, u_type: int, vehicle: bool) -> void:
		mod_ref = m
		hq_ref = hq
		pos = drop_p
		unit_type = u_type
		is_vehicle = vehicle
		alt = 24.0
		swing_phase = randf() * TAU

	func tick(delta: float) -> void:
		swing_phase += delta * 3.0
		alt -= delta * 7.5
		pos.x += sin(swing_phase) * delta * 4.0

		if alt <= 0.0:
			alt = 0.0
			is_finished = true
			_land()

	func _land() -> void:
		if mod_ref.world_ref == null or not ("army" in mod_ref.world_ref and mod_ref.world_ref.army != null):
			return

		var p = mod_ref.world_ref.player
		var u = Unit.new()
		u.id = mod_ref.world_ref.army._next_id
		mod_ref.world_ref.army._next_id += 1
		u.type = unit_type
		u.country_id = p.id
		u.home = hq_ref
		var grp = int(hq_ref.get_meta("vdv_group", 1)) if hq_ref != null and is_instance_valid(hq_ref) else 1
		u.set_meta("vdv_group", grp)
		u.team = grp
		u.set_meta("is_vdv_trooper", true)

		if is_vehicle:
			u.hp = 95.0
		else:
			u.hp = 70.0 if unit_type == Unit.Type.ASSAULT else 45.0
		u.max_hp = u.hp

		u.pos = pos
		u.heading = randf() * TAU
		u.update_frame()
		u.state = Unit.State.IDLE

		mod_ref.world_ref.army.units.append(u)
		mod_ref.active_vdv_troops.append(u)

		if mod_ref.world_ref.fx != null:
			mod_ref.world_ref.fx.spawn("dust_s", pos.round(), 8)
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_click")

# ==============================================================================
# Слой игрового мира (Отрисовка призрака постройки, вертолёта, тросов, парашютов и выделения)
# ==============================================================================
class AirborneAssaultWorldLayer extends Node2D:
	var mod_ref: RefCounted = null
	var main_ref: Node = null
	var world_ref: Node = null

	func setup(m: RefCounted, main: Node, world: Node) -> void:
		mod_ref = m
		main_ref = main
		world_ref = world
		z_index = 68

	func _unhandled_input(event: InputEvent) -> void:
		if mod_ref == null or main_ref == null:
			return

		# 1. Режим размещения постройки Штаба ВДВ
		if mod_ref.is_placing_hq:
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					var mpos = main_ref.cam.screen_to_world(event.position)
					var cell = Vector2i((mpos / float(GameWorld.CELL)).floor())
					mod_ref.place_hq_at(cell)
					get_viewport().set_input_as_handled()
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					mod_ref.cancel_hq_placement()
					get_viewport().set_input_as_handled()
			return

		# 2. Режим целеуказания для вылета десанта (Ми-8 или Ил-76) или общего наступления
		if mod_ref.targeting_op != "":
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					var mpos = main_ref.cam.screen_to_world(event.position)
					mod_ref.launch_operation_at(mpos)
					get_viewport().set_input_as_handled()
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					mod_ref.cancel_targeting()
					get_viewport().set_input_as_handled()
			return

		# 3. Интерактивное управление бойцами ВДВ и вертолётом на карте
		if event is InputEventMouseButton and event.pressed:
			var mpos = main_ref.cam.screen_to_world(event.position)

			# ЛКМ: Выбор вертолёта в воздухе или бойца/отряда ВДВ на земле
			if event.button_index == MOUSE_BUTTON_LEFT:
				# А) Проверяем вертолёты
				for h in mod_ref.active_helis:
					if h.pos.distance_to(mpos) <= 24.0:
						mod_ref.selected_heli = h
						mod_ref.selected_vdv_troops.clear()
						if ClassDB.class_exists("UiKit"):
							UiKit.snd("ui_select")
						if main_ref.hud != null:
							main_ref.hud.show_toast("Ми-8 взят под прямое управление (ПКМ по карте - изменить точку высадки)")
						get_viewport().set_input_as_handled()
						return

				# Б) Проверяем бойцов ВДВ на земле
				var clicked_trooper: Unit = null
				for u in mod_ref.active_vdv_troops:
					if u != null and is_instance_valid(u) and ("alive" in u and u.alive()):
						if u.pos.distance_to(mpos) <= 24.0:
							clicked_trooper = u
							break

				if clicked_trooper != null:
					# Выделяем бойца и всю его группу
					var grp_id = int(clicked_trooper.get_meta("vdv_group", 1))
					mod_ref.selected_vdv_troops.clear()
					for u in mod_ref.active_vdv_troops:
						if u != null and is_instance_valid(u) and ("alive" in u and u.alive()):
							if int(u.get_meta("vdv_group", 1)) == grp_id:
								mod_ref.selected_vdv_troops.append(u)

					mod_ref.selected_heli = null
					if ClassDB.class_exists("UiKit"):
						UiKit.snd("ui_select")
					if main_ref.hud != null:
						main_ref.hud.show_toast("ГРУППА ВДВ #%d (%d бойцов) ВЫБРАНА (ПКМ по карте - движение / атака)" % [grp_id, mod_ref.selected_vdv_troops.size()])
					get_viewport().set_input_as_handled()
					return
				else:
					# Кликнули в пустое место — сбрасываем выделение десанта
					if not mod_ref.selected_vdv_troops.is_empty():
						mod_ref.selected_vdv_troops.clear()

			# ПКМ: Отдача приказа движения или атаки выбранному вертолёту или отряду ВДВ
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				if mod_ref.selected_heli != null and is_instance_valid(mod_ref.selected_heli):
					mod_ref.selected_heli.target_pos = mpos
					if mod_ref.selected_heli.state in [VdvHelicopter.State.FLY_TO_LZ, VdvHelicopter.State.HOVER_DESCEND]:
						mod_ref.selected_heli.state = VdvHelicopter.State.FLY_TO_LZ
					if ClassDB.class_exists("UiKit"):
						UiKit.snd("ui_select")
					if main_ref.hud != null:
						main_ref.hud.show_toast("Ми-8 изменил курс на новую точку высадки!")
					get_viewport().set_input_as_handled()
					return

				if not mod_ref.selected_vdv_troops.is_empty():
					var cell = Vector2i((mpos / float(GameWorld.CELL)).floor())
					var target_city: City = world_ref.city_at_cell(cell) if world_ref != null and world_ref.has_method("city_at_cell") else null
					var is_enemy_city = target_city != null and world_ref.player != null and target_city.country_id != world_ref.player.id

					var idx = 0
					var count = mod_ref.selected_vdv_troops.size()
					for u in mod_ref.selected_vdv_troops:
						if u == null or not is_instance_valid(u) or not ("alive" in u and u.alive()):
							continue

						var form_offset = Vector2.RIGHT.rotated(float(idx) * TAU / maxf(1.0, float(count))) * 12.0
						var dest = (Vector2(target_city.center * GameWorld.CELL) if is_enemy_city else mpos) + form_offset

						mod_ref._assign_unit_path(u, dest)
						u.set_meta("manual_order", true)
						u.set_meta("manual_target", dest)
						idx += 1

					if ClassDB.class_exists("UiKit"):
						UiKit.snd("ui_click")

					if main_ref.hud != null:
						if is_enemy_city:
							main_ref.hud.show_toast("СПЕЦНАЗ ВДВ: ШТУРМ ГОРОДА %s!" % target_city.name)
						else:
							main_ref.hud.show_toast("СПЕЦНАЗ ВДВ: Приказ принят, выдвигаемся на позицию!")

					get_viewport().set_input_as_handled()
					return

	func _draw() -> void:
		if mod_ref == null or main_ref == null:
			return

		# 1. Отрисовка вертолётных площадок на построенных штабах ВДВ
		if world_ref != null and "mil" in world_ref and world_ref.mil != null:
			for f in world_ref.mil.facilities:
				if f is Facility and f.has_meta("is_vdv_hq") and f.get_meta("is_vdv_hq"):
					_draw_helipad(f)

		# 2. Отрисовка призрака сетки при строительстве
		if mod_ref.is_placing_hq:
			_draw_placement_ghost()

		# 3. Отрисовка прицела десантирования в режиме целеуказания
		if mod_ref.targeting_op != "":
			_draw_targeting_overlay()

		# 4. Отрисовка тактических маркеров групп над всеми десантниками
		_draw_all_vdv_indicators()

		# 5. Отрисовка тактических кругов под выбранными бойцами ВДВ
		_draw_selected_vdv_indicators()

		# 6. Отрисовка вертолётов в воздухе
		for h in mod_ref.active_helis:
			_draw_helicopter(h)

		# 7. Отрисовка самолётов Ил-76 в воздухе
		for p in mod_ref.active_planes:
			_draw_cargo_plane(p)

		# 8. Отрисовка спускающихся парашютов
		for para in mod_ref.active_parachutes:
			_draw_parachute(para)

	func _draw_helipad(f: Facility) -> void:
		var center = Vector2(f.cell * GameWorld.CELL) + Vector2(float(f.size.x * GameWorld.CELL) * 0.5, float(f.size.y * GameWorld.CELL) * 0.5)
		var grp_id = int(f.get_meta("vdv_group", 1)) if f.has_meta("vdv_group") else 1
		var grp_col = mod_ref._group_color(grp_id)

		draw_circle(center, 14.0, Color(0.18, 0.2, 0.22, 0.85))
		draw_arc(center, 14.0, 0, TAU, 24, grp_col, 2.0)
		var col_h = Color(0.95, 0.85, 0.3, 0.95)
		draw_line(center + Vector2(-5, -7), center + Vector2(-5, 7), col_h, 2.0)
		draw_line(center + Vector2(5, -7), center + Vector2(5, 7), col_h, 2.0)
		draw_line(center + Vector2(-5, 0), center + Vector2(5, 0), col_h, 2.0)

		# Аккуратная тактическая плашка базы «ВДВ 1», «ВДВ 2»
		var font: Font = UiKit.f_bold if UiKit.f_bold != null else (UiKit.font if UiKit.font != null else ThemeDB.fallback_font)
		var label_txt = "ВДВ %d" % grp_id
		var f_sz = 10
		var tw = font.get_string_size(label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f_sz).x
		var th = 13.0
		var bw = tw + 10.0
		var b_rect = Rect2(center.x - bw * 0.5, center.y - 23.0, bw, th)
		# Контур и тёмная подложка
		draw_rect(b_rect.grow(1.0), Color(0.04, 0.05, 0.07, 0.95))
		draw_rect(b_rect, Color(0.10, 0.12, 0.14, 0.92))
		draw_rect(Rect2(b_rect.position.x, b_rect.end.y - 1.5, bw, 1.5), grp_col)
		draw_string_outline(font, Vector2(b_rect.position.x + 5.0, b_rect.end.y - 2.5), label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f_sz, 2, Color.BLACK)
		draw_string(font, Vector2(b_rect.position.x + 5.0, b_rect.end.y - 2.5), label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f_sz, Color(0.98, 0.98, 0.96))

	func _draw_placement_ghost() -> void:
		var mouse_w = main_ref.cam.screen_to_world(get_viewport().get_mouse_position())
		var cell = Vector2i((mouse_w / float(GameWorld.CELL)).floor())
		var valid = mod_ref.can_place_hq_at(cell)

		var pos = Vector2(cell * GameWorld.CELL)
		var sz = Vector2(HQ_SIZE * GameWorld.CELL)

		var outline_col = Color(0.2, 1.0, 0.3, 0.9) if valid else Color(1.0, 0.25, 0.25, 0.9)
		var fill_col = Color(0.2, 1.0, 0.3, 0.2) if valid else Color(1.0, 0.25, 0.25, 0.2)

		draw_rect(Rect2(pos, sz), fill_col)
		draw_rect(Rect2(pos, sz), outline_col, false, 2.0)

		for x in range(HQ_SIZE.x + 1):
			var lx = pos.x + float(x * GameWorld.CELL)
			draw_line(Vector2(lx, pos.y), Vector2(lx, pos.y + sz.y), Color(outline_col.r, outline_col.g, outline_col.b, 0.3), 1.0)
		for y in range(HQ_SIZE.y + 1):
			var ly = pos.y + float(y * GameWorld.CELL)
			draw_line(Vector2(pos.x, ly), Vector2(pos.x + sz.x, ly), Color(outline_col.r, outline_col.g, outline_col.b, 0.3), 1.0)

	func _draw_targeting_overlay() -> void:
		var mouse_w = main_ref.cam.screen_to_world(get_viewport().get_mouse_position())
		var radius = 28.0
		var ring_col = Color(0.2, 0.85, 1.0, 0.85)

		if mod_ref.targeting_op == "il76":
			radius = 48.0
			ring_col = Color(1.0, 0.75, 0.2, 0.85)
		elif mod_ref.targeting_op == "vdv_order_all":
			radius = 38.0
			ring_col = Color(1.0, 0.3, 0.3, 0.9)

		if mod_ref.targeting_fac != null:
			var base_p = Vector2(mod_ref.targeting_fac.cell * GameWorld.CELL) + Vector2(18, 12)
			draw_line(base_p, mouse_w, Color(ring_col.r, ring_col.g, ring_col.b, 0.4), 1.5)

		draw_circle(mouse_w, radius, Color(ring_col.r, ring_col.g, ring_col.b, 0.15))
		draw_arc(mouse_w, radius, 0, TAU, 32, ring_col, 2.0)
		draw_line(mouse_w - Vector2(radius + 8, 0), mouse_w + Vector2(radius + 8, 0), ring_col, 1.5)
		draw_line(mouse_w - Vector2(0, radius + 8), mouse_w + Vector2(0, radius + 8), ring_col, 1.5)

	func _draw_all_vdv_indicators() -> void:
		var font: Font = UiKit.f_bold if UiKit.f_bold != null else (UiKit.font if UiKit.font != null else ThemeDB.fallback_font)
		for u in mod_ref.active_vdv_troops:
			if u == null or not is_instance_valid(u) or not ("alive" in u and u.alive()):
				continue

			var grp_id = int(u.get_meta("vdv_group", 1))
			var col = mod_ref._group_color(grp_id)
			var r = 10.0 if u.type == Unit.Type.IFV else 6.0
			var pt = u.pos + Vector2(0, -r - 4.0)

			# Аккуратная тактическая плашка группы «ВДВ 1», «ВДВ 2»
			var grp_txt = "ВДВ %d" % grp_id
			var f_sz = 9
			var tw = font.get_string_size(grp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f_sz).x
			var th = 11.0
			var bw = tw + 8.0
			var b_rect = Rect2(pt.x - bw * 0.5, pt.y - th, bw, th)

			draw_rect(b_rect.grow(1.0), Color(0.04, 0.05, 0.07, 0.92))
			draw_rect(b_rect, Color(0.09, 0.11, 0.13, 0.9))
			draw_rect(Rect2(b_rect.position.x + 1.5, b_rect.position.y + 1.5, 3.0, th - 3.0), col)
			draw_rect(Rect2(b_rect.position.x, b_rect.end.y - 1.0, bw, 1.0), col)

			draw_string_outline(font, Vector2(b_rect.position.x + 6.0, b_rect.end.y - 2.0), grp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f_sz, 2, Color.BLACK)
			draw_string(font, Vector2(b_rect.position.x + 6.0, b_rect.end.y - 2.0), grp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f_sz, Color(0.97, 0.97, 0.95))

	func _draw_selected_vdv_indicators() -> void:
		if mod_ref.selected_vdv_troops.is_empty():
			return

		for u in mod_ref.selected_vdv_troops:
			if u == null or not is_instance_valid(u) or not ("alive" in u and u.alive()):
				continue

			var grp_id = int(u.get_meta("vdv_group", 1))
			var sel_col = mod_ref._group_color(grp_id)
			var r = 10.0 if u.type == Unit.Type.IFV else 6.0
			draw_arc(u.pos, r + 1.5, 0, TAU, 18, sel_col, 2.0)

			# Полоска здоровья над бойцом
			var hp_frac = clampf(u.hp / maxf(1.0, u.max_hp), 0.0, 1.0)
			var bar_w = 14.0
			var bar_pos = u.pos + Vector2(-bar_w * 0.5, -r - 8.0)
			draw_rect(Rect2(bar_pos, Vector2(bar_w, 2.5)), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_frac, 2.5)), sel_col)

			# Линия приказа к цели
			if not u.path.is_empty() and u.pi < u.path.size():
				var dest = u.path[u.path.size() - 1]
				draw_line(u.pos, dest, Color(sel_col.r, sel_col.g, sel_col.b, 0.45), 1.5)
				draw_circle(dest, 3.5, sel_col)

	func _draw_helicopter(h: VdvHelicopter) -> void:
		var shadow_pos = h.pos + Vector2(h.alt * 0.4, h.alt * 0.7)
		var shadow_scale = maxf(0.5, 1.0 - h.alt * 0.03)
		draw_circle(shadow_pos, 8.0 * shadow_scale, Color(0, 0, 0, 0.35))

		var heli_screen_pos = h.pos - Vector2(0, h.alt)

		if h.state == VdvHelicopter.State.FAST_ROPING:
			var rope_col = Color(0.2, 0.22, 0.2, 0.9)
			draw_line(heli_screen_pos + Vector2(-4, 0), h.pos + Vector2(-6, 0), rope_col, 1.5)
			draw_line(heli_screen_pos + Vector2(4, 0), h.pos + Vector2(6, 0), rope_col, 1.5)

		var fwd = Vector2.RIGHT.rotated(h.heading)
		var side = Vector2.UP.rotated(h.heading)
		var body_col = Color(0.26, 0.36, 0.3, 1.0)
		var dark_col = Color(0.18, 0.24, 0.2, 1.0)

		draw_line(heli_screen_pos - fwd * 12.0, heli_screen_pos + fwd * 8.0, body_col, 5.0)
		draw_circle(heli_screen_pos + fwd * 8.0, 3.0, Color(0.2, 0.75, 0.95, 1.0))
		draw_line(heli_screen_pos - fwd * 12.0, heli_screen_pos - fwd * 22.0, dark_col, 2.5)
		draw_line(heli_screen_pos - fwd * 22.0 - side * 4.0, heli_screen_pos - fwd * 22.0 + side * 4.0, Color(0.9, 0.6, 0.1, 0.9), 1.5)

		var blade_vec = Vector2.RIGHT.rotated(h.rotor_angle) * 18.0
		draw_line(heli_screen_pos - blade_vec, heli_screen_pos + blade_vec, Color(0.85, 0.9, 0.95, 0.75), 1.5)
		draw_line(heli_screen_pos - blade_vec.orthogonal(), heli_screen_pos + blade_vec.orthogonal(), Color(0.85, 0.9, 0.95, 0.75), 1.5)

		if mod_ref.selected_heli == h:
			draw_arc(heli_screen_pos, 16.0, 0, TAU, 24, Color(0.2, 1.0, 0.4, 0.9), 2.0)
			draw_line(h.pos, h.target_pos, Color(0.2, 1.0, 0.4, 0.5), 1.0)

	func _draw_cargo_plane(p: VdvCargoPlane) -> void:
		var shadow_pos = p.pos + Vector2(p.alt * 0.4, p.alt * 0.7)
		draw_circle(shadow_pos, 16.0, Color(0, 0, 0, 0.25))

		var plane_pos = p.pos - Vector2(0, p.alt)
		var fwd = p.dir
		var side = Vector2(-fwd.y, fwd.x)
		var wing_span = 26.0

		draw_line(plane_pos - side * wing_span, plane_pos + side * wing_span, Color(0.65, 0.7, 0.75, 1.0), 3.5)
		draw_line(plane_pos - fwd * 22.0, plane_pos + fwd * 20.0, Color(0.72, 0.78, 0.84, 1.0), 6.0)
		draw_circle(plane_pos + fwd * 20.0, 3.0, Color(0.2, 0.7, 0.95, 1.0))
		draw_line(plane_pos - fwd * 20.0 - side * 10.0, plane_pos - fwd * 20.0 + side * 10.0, Color(0.65, 0.7, 0.75, 1.0), 2.5)

	func _draw_parachute(para: VdvParachuteCargo) -> void:
		var ground_pos = para.pos
		var cargo_pos = para.pos - Vector2(0, para.alt)
		var chute_pos = cargo_pos - Vector2(0, 14.0)

		draw_circle(ground_pos, 4.0, Color(0, 0, 0, 0.3))

		var str_col = Color(0.8, 0.8, 0.8, 0.6)
		draw_line(chute_pos + Vector2(-10, 0), cargo_pos, str_col, 1.0)
		draw_line(chute_pos + Vector2(10, 0), cargo_pos, str_col, 1.0)

		var r_chute = 12.0 if para.is_vehicle else 8.0
		draw_arc(chute_pos, r_chute, PI, TAU, 16, Color(0.95, 0.95, 0.95, 0.95), 2.5)

		if para.is_vehicle:
			draw_rect(Rect2(cargo_pos - Vector2(7, 4), Vector2(14, 8)), Color(0.25, 0.38, 0.28, 1.0))
		else:
			draw_circle(cargo_pos, 3.0, Color(0.2, 0.35, 0.22, 1.0))
