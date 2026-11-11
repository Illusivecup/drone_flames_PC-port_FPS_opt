extends RefCounted

## Мод «Ядерный арсенал (МБР и Шахты)» для DroneFlames Reborn
## Полная аутентичная интеграция в интерфейс, меню и движок игры.
## Добавляет шахтный комплекс МБР во вкладку «АРМИЯ» нижней панели.
## Позволяет обогащать уран и собирать термоядерные боеголовки.
## Производит пуск межконтинентальной баллистической ракеты с глобальным радиусом поражения,
## кинематографичной ослепляющей вспышкой, гигантским ядерным грибом и выжиганием радиоактивной пустоши.

var mm_ref: Node = null
var main_ref: Node = null
var world_ref: Node = null

var world_layer: Node2D = null
var flash_layer: CanvasLayer = null
var flash_rect: ColorRect = null

var is_placing: bool = false
var is_targeting: bool = false
var selected_fac: Facility = null
var targeting_silo: Facility = null
var target_point: Vector2 = Vector2.INF

const SILO_COST_MONEY: int = 3500
const SILO_COST_URANIUM: int = 10
const WARHEAD_COST_MONEY: int = 1500
const WARHEAD_COST_URANIUM: int = 8
const WARHEAD_TIME: float = 24.0

const SILO_SIZE: Vector2i = Vector2i(4, 4)
const SILO_MAX_HP: float = 650.0
const SILO_REFUND: int = 1750
const SILO_REPAIR_COST: int = 400

var active_missiles: Array = []
var active_explosions: Array = []

const BuildPanel = preload("res://ui/ui24/build_panel.gd")

func close_all() -> void:
	is_placing = false
	is_targeting = false
	targeting_silo = null
	target_point = Vector2.INF
	selected_fac = null
	if main_ref != null:
		if "selected_fac" in main_ref:
			main_ref.selected_fac = null
		if main_ref.has_method("_deselect"):
			main_ref._deselect()
		if main_ref.hud != null:
			main_ref.hud.hide_ops()
			main_ref.hud.set_key_pressed("nuclear_silo", false)
	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_close")

func init_mod(mm: Node) -> void:
	mm_ref = mm
	if mm.has_method("register_texture"):
		var ref_t = UiKit.tex("net_refresh")
		if ref_t != null:
			mm.register_texture("icon_refresh", ref_t)
	if mm.has_method("register_hook"):
		mm.call("register_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("register_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[NuclearStrike] Native mod initialized.")

func cleanup_mod(mm: Node) -> void:
	if main_ref != null and is_instance_valid(main_ref) and main_ref.hud != null and mm != null and mm.has_method("cleanup_mod_hud"):
		mm.call("cleanup_mod_hud", main_ref.hud, Callable(self, "_on_hud_action"), ["nuclear_silo"])
	_cleanup_nodes()
	if mm and mm.has_method("unregister_hook"):
		mm.call("unregister_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("unregister_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[NuclearStrike] Mod cleaned up.")

func _cleanup_nodes() -> void:
	is_placing = false
	is_targeting = false
	selected_fac = null
	targeting_silo = null
	target_point = Vector2.INF
	active_missiles.clear()
	active_explosions.clear()
	if world_layer != null and is_instance_valid(world_layer):
		world_layer.queue_free()
		world_layer = null
	if flash_layer != null and is_instance_valid(flash_layer):
		flash_layer.queue_free()
		flash_layer = null

func _ensure_hud(main: Node, world: Node) -> void:
	if main == null or not is_instance_valid(main) or world == null or not is_instance_valid(world):
		return
	main_ref = main
	world_ref = world

	# 1. Встраивание слота МБР во вкладку «АРМИЯ» (Tab 4) нижней панели
	if main.hud != null and main.hud.pages.size() > 4:
		var army_grid = main.hud.pages[4] as GridContainer
		if army_grid != null and not main.hud.keys.has("nuclear_silo"):
			var cell = main.hud._cell("nuclear_silo", "icon_m_ballistic", true)
			army_grid.add_child(cell)
			army_grid.move_child(cell, mini(army_grid.get_child_count() - 1, 2))

		if not main.hud.action.is_connected(_on_hud_action):
			main.hud.action.connect(_on_hud_action)

	# 2. Слой мира для визуализации призрака, шахты, полёта МБР и ядерных грибов
	if world_layer == null or not is_instance_valid(world_layer):
		world_layer = NuclearWorldLayer.new()
		world_layer.setup(self, main, world)
		world.add_child(world_layer)

	# 3. CanvasLayer для кинематографичной ослепляющей ядерной вспышки
	if flash_layer == null or not is_instance_valid(flash_layer):
		flash_layer = CanvasLayer.new()
		flash_layer.layer = 125
		flash_rect = ColorRect.new()
		flash_rect.anchor_right = 1.0
		flash_rect.anchor_bottom = 1.0
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
		flash_layer.add_child(flash_rect)
		main.add_child(flash_layer)

func _trigger_nuclear_flash() -> void:
	if main_ref == null or not is_instance_valid(main_ref):
		return
	if flash_layer == null or not is_instance_valid(flash_layer) or not flash_layer.is_inside_tree():
		if flash_layer != null and is_instance_valid(flash_layer):
			flash_layer.queue_free()
		flash_layer = CanvasLayer.new()
		flash_layer.layer = 125
		flash_rect = ColorRect.new()
		flash_rect.anchor_right = 1.0
		flash_rect.anchor_bottom = 1.0
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
		flash_layer.add_child(flash_rect)
		main_ref.add_child(flash_layer)

	if flash_rect != null and is_instance_valid(flash_rect):
		var vp_sz: Vector2 = main_ref.get_viewport().get_visible_rect().size
		flash_rect.position = Vector2.ZERO
		flash_rect.size = vp_sz * 1.5

		# Фаза 1: Мгновенное ослепление сверхчистым белым светом (100% непрозрачность)
		flash_rect.color = Color(1.0, 1.0, 1.0, 1.0)
		var tw: Tween = flash_rect.create_tween()
		# Фаза 2: Держим ослепляющий пик 0.18 секунды (эффект перегрузки сетчатки глаза)
		tw.tween_interval(0.18)
		# Фаза 3: Переход в огненную плазму и раскалённый янтарно-оранжевый жар
		tw.tween_property(flash_rect, "color", Color(1.0, 0.72, 0.22, 0.85), 0.45).set_trans(Tween.TRANS_QUAD)
		# Фаза 4: Рассеивание жара в тёплый дымный оттенок
		tw.tween_property(flash_rect, "color", Color(0.9, 0.45, 0.1, 0.35), 0.75).set_trans(Tween.TRANS_QUAD)
		# Фаза 5: Окончательное мягкое затухание в прозрачность
		tw.tween_property(flash_rect, "color:a", 0.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_world_started(main: Node, world: Node) -> void:
	_cleanup_nodes()
	_ensure_hud(main, world)
	if world != null:
		world.set_meta("nuclear_strike_mod", self)
	print("[NuclearStrike] Injected nuclear_silo into Army tab and world layers created.")

func launch_strike_from_silo(f: Facility, target_world_pos: Vector2) -> bool:
	if f == null or not is_instance_valid(f) or not bool(f.get_meta("has_warhead", false)):
		return false
	f.set_meta("has_warhead", false)
	f.missiles = 0
	if targeting_silo == f:
		targeting_silo = null
		is_targeting = false
		target_point = Vector2.INF
	var start_pos: Vector2 = f.center_px()
	var dist: float = start_pos.distance_to(target_world_pos)
	var flight_duration: float = clampf(5.5 + dist * 0.002, 6.5, 9.5)
	if ClassDB.class_exists("Sfx"):
		Sfx.play("vls_hatch_open", start_pos)
		Sfx.play("missile_launch", start_pos)
		Sfx.play("hyper_launch", start_pos)
	if world_ref != null and world_ref.fx != null:
		world_ref.fx.spawn("tel_flash", start_pos.round(), 6)
		world_ref.fx.spawn("launch_cloud", start_pos.round(), 5)
		world_ref.fx.spawn("shockwave", start_pos.round(), 1)
	if world_ref != null and world_ref.has_method("camera_shake_launch"):
		world_ref.camera_shake_launch(start_pos)
	var m: Dictionary = {
		"from": start_pos,
		"target": target_world_pos,
		"t": 0.0,
		"duration": flight_duration,
		"whistled": false,
		"country_id": f.country_id,
		"trail": []
	}
	active_missiles.append(m)
	return true

func _on_nuke_sheet_target() -> void:
	if is_placing:
		cancel_placement()
	if is_targeting:
		_cancel_targeting()

	var ready_silo: Facility = null
	var any_silo: Facility = null
	var player_id: int = int(world_ref.player.id) if world_ref != null and world_ref.player != null else 0
	if world_ref != null and world_ref.mil != null:
		for f in world_ref.mil.facilities:
			if f != null and is_instance_valid(f) and _is_silo(f) and f.country_id == player_id and f.hp > 0.0:
				if any_silo == null:
					any_silo = f
				if bool(f.get_meta("has_warhead", false)):
					ready_silo = f
					break

	if ready_silo != null:
		selected_fac = ready_silo
		if main_ref != null and "selected_fac" in main_ref:
			main_ref.selected_fac = ready_silo
		_start_targeting(ready_silo)
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("ЯДЕРНЫЙ УДАР: выберите квадрат на карте для пуска МБР «Сармат»!")
	elif any_silo != null:
		selected_fac = any_silo
		if main_ref != null and "selected_fac" in main_ref:
			main_ref.selected_fac = any_silo
		_update_native_card(any_silo)
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Шахта МБР пуста. Закажите сборку термоядерной боеголовки!")
	else:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Нет шахты МБР! Постройте шахтный комплекс во вкладке АРМИЯ.")
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")

func _on_hud_action(nm: String) -> void:
	match nm:
		"nuclear_silo":
			if main_ref != null and main_ref.hud != null:
				main_ref.hud.show_tip(
					"Термоядерный удар МБР «Сармат»",
					"Стратегический комплекс шахтного базирования. Постройка: %d $ и %d урана. Боеголовка снаряжается в шахте." % [SILO_COST_MONEY, SILO_COST_URANIUM],
					""
				)
			if is_placing:
				cancel_placement()
			else:
				start_placement()
		"nuke_sheet_target":
			_on_nuke_sheet_target()
		"nuke_craft":
			var f_c = selected_fac if selected_fac != null else (main_ref.selected_fac as Facility if main_ref != null and "selected_fac" in main_ref else null)
			if f_c != null and _is_silo(f_c):
				_order_warhead(f_c)
		"nuke_target":
			var f_t = selected_fac if selected_fac != null else (main_ref.selected_fac as Facility if main_ref != null and "selected_fac" in main_ref else null)
			if f_t != null and _is_silo(f_t):
				_start_targeting(f_t)
		"nuke_build_another":
			start_placement()
		"nuke_target_reset":
			target_point = Vector2.INF
			if main_ref != null and main_ref.hud != null:
				main_ref.hud.show_toast("Точка ядерного удара сброшена. Укажите новый квадрат на карте.")
			if ClassDB.class_exists("UiKit"):
				UiKit.snd("ui_select")
		"nuke_launch_confirm":
			if target_point != Vector2.INF and targeting_silo != null:
				launch_strike(target_point)
			elif main_ref != null and main_ref.hud != null:
				main_ref.hud.show_toast("Сначала укажите точку удара на карте!")
				if ClassDB.class_exists("UiKit"):
					UiKit.snd("ui_error")
		"cancel_select", "nuke_close", "nuke_cancel_target":
			close_all()
		"nuke_repair":
			var f_r = selected_fac if selected_fac != null else (main_ref.selected_fac as Facility if main_ref != null and "selected_fac" in main_ref else null)
			if f_r != null and _is_silo(f_r):
				_repair_silo(f_r)
		"nuke_demolish":
			var f_d = selected_fac if selected_fac != null else (main_ref.selected_fac as Facility if main_ref != null and "selected_fac" in main_ref else null)
			if f_d != null and _is_silo(f_d):
				_demolish_silo(f_d)

func _is_silo(f: Facility) -> bool:
	if f == null:
		return false
	if f.army_build == "nuclear_silo" or f.lower_sprite == "nuclear_silo" or bool(f.get_meta("is_nuclear_silo", false)):
		f.kind = Facility.Kind.CIV_FACTORY
		f.set_meta("is_nuclear_silo", true)
		f.set_meta("mod_facility", true)
		f.moving = false
		f.mdest = Vector2.ZERO
		f.mpos = f.center_px()
		if not f.has_meta("hp"):
			f.set_meta("hp", f.hp if f.hp > 0.0 else SILO_MAX_HP)
			f.set_meta("max_hp", SILO_MAX_HP)
			f.set_meta("has_warhead", f.missiles > 0)
			f.set_meta("producing", f.producing)
			f.set_meta("prod_t", f.prod_t)
		return true
	return false

func _on_match_tick(main: Node, world: Node, delta: float) -> void:
	main_ref = main
	world_ref = world
	if main != null and (main.hud == null or not main.hud.keys.has("nuclear_silo") or world_layer == null or flash_layer == null):
		_ensure_hud(main, world)

	var ts: float = 1.0
	if world != null and "time_scale" in world:
		ts = maxf(0.0, float(world.time_scale))
	var sim_delta: float = delta * ts

	_tick_silos(sim_delta)
	_tick_missiles(sim_delta)
	_tick_explosions(sim_delta)

	# 1. Если активен режим наведения термоядерного удара — отображаем специальную карточку прицеливания
	if is_targeting and targeting_silo != null and is_instance_valid(targeting_silo):
		_update_targeting_card()
	# 2. Иначе обновляем карточку выбранной шахты
	elif main != null and "selected_fac" in main and main.selected_fac != null and is_instance_valid(main.selected_fac):
		var f: Facility = main.selected_fac as Facility
		if _is_silo(f):
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

	if p.money < SILO_COST_MONEY or p.uranium < SILO_COST_URANIUM:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает ресурсов: требуется 3500 $ и 10 Урана (добывается на урановых шахтах)!")
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	is_placing = true
	is_targeting = false
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.set_key_pressed("nuclear_silo", true)
		main_ref.hud.show_toast("ШАХТА МБР: Выберите безопасное место на своей территории (ЛКМ/Тап — построить, ПКМ — отмена)")

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_select")

func cancel_placement() -> void:
	is_placing = false
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.set_key_pressed("nuclear_silo", false)

func place_why(cell: Vector2i) -> String:
	if world_ref == null or not is_instance_valid(world_ref):
		return "Мир недоступен"
	var d = world_ref.data
	if d == null:
		return "Данные карты недоступны"

	if cell.x < 2 or cell.y < 2 or cell.x + SILO_SIZE.x >= d.w - 2 or cell.y + SILO_SIZE.y >= d.h - 2:
		return "Не помещается у края карты"

	var player = world_ref.player
	if player == null:
		return "Игрок не найден"

	for dy in range(SILO_SIZE.y):
		for dx in range(SILO_SIZE.x):
			var cx = cell.x + dx
			var cy = cell.y + dy
			if not d.inside(cx, cy):
				return "За пределами карты"
			
			var owner_id = d.get_owner_id(cx, cy) if d.has_method("get_owner_id") else d.get_owner(cx, cy)
			if owner_id != player.id:
				return "Стройте только на своей территории"

			var b = d.get_biome(cx, cy)
			if Biome.is_water(b):
				return "Нельзя строить на воде"

			var fl = d.flags[cy * d.w + cx]
			if (fl & (WorldData.F_CITY | WorldData.F_BRIDGE)) != 0:
				return "Место занято: городские постройки"

			if (fl & WorldData.F_OCCUPIED) != 0:
				if world_ref.tree_at.has(cy * d.w + cx):
					continue
				if world_ref.mil != null and world_ref.mil.has_method("facility_at"):
					var fac_at = world_ref.mil.facility_at(Vector2i(cx, cy))
					if fac_at != null and is_instance_valid(fac_at):
						return "Место занято: постройка или ПВО"
				return "Место занято другими объектами"

	return ""

func can_place_at(cell: Vector2i) -> bool:
	return place_why(cell) == ""

func place_silo_at(cell: Vector2i) -> void:
	var why = place_why(cell)
	if why != "":
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Нельзя построить здесь: " + why)
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	var p = world_ref.player
	if p.money < SILO_COST_MONEY or p.uranium < SILO_COST_URANIUM:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает: 3500 $ и 10 урана!")
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	p.money -= SILO_COST_MONEY
	p.uranium -= SILO_COST_URANIUM

	var f = Facility.new()
	f.id = world_ref.mil.facilities.size()
	# ВАЖНО: CIV_FACTORY — неподвижное сооружение. Ни при каких обстоятельствах не поедет!
	f.kind = Facility.Kind.CIV_FACTORY
	f.country_id = p.id
	f.cell = cell
	f.size = SILO_SIZE
	f.army_build = "nuclear_silo"
	f.lower_sprite = "nuclear_silo"
	f.hp = SILO_MAX_HP
	f.moving = false
	f.mdest = Vector2.ZERO
	f.mpos = f.center_px()
	f.missiles = 1
	f.set_meta("is_nuclear_silo", true)
	f.set_meta("mod_facility", true)
	f.set_meta("hp", SILO_MAX_HP)
	f.set_meta("max_hp", SILO_MAX_HP)
	f.set_meta("has_warhead", true)
	f.set_meta("producing", false)
	f.set_meta("prod_t", 0.0)

	var spr_name = "eco_silo" if world_ref.spr_index.has("eco_silo") else ("missile_factory" if world_ref.spr_index.has("missile_factory") else "npp_core")
	f.main_obj = world_ref.add_object(spr_name, cell, GameWorld.KIND_BUILDING)
	f.obj_ids.append(f.main_obj)
	world_ref.mil.facilities.append(f)

	var d = world_ref.data
	for dy in range(f.size.y):
		for dx in range(f.size.x):
			var cx = cell.x + dx
			var cy = cell.y + dy
			world_ref.remove_tree_at(Vector2i(cx, cy))
			d.add_flag(cx, cy, WorldData.F_OCCUPIED)
			d.set_biome(cx, cy, Biome.INDUSTRIAL)

	cancel_placement()

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_build")
	if ClassDB.class_exists("Sfx"):
		Sfx.play("vls_hatch_open", f.center_px())
	if world_ref.fx != null:
		world_ref.fx.spawn("dust_s", Vector2(cell * GameWorld.CELL + Vector2i(8, 8)), 8)

	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Шахтный комплекс МБР построен! Стратегическая ракета с термоядерной БЧ на боевом дежурстве.")
		main_ref.selected_fac = f

func _order_warhead(f: Facility) -> void:
	var p = world_ref.player
	if p == null:
		return
	if p.money < WARHEAD_COST_MONEY or p.uranium < WARHEAD_COST_URANIUM:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает: требуется 1500 $ и 8 урана (из урановых шахт или торговли)!")
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	p.money -= WARHEAD_COST_MONEY
	p.uranium -= WARHEAD_COST_URANIUM

	f.set_meta("producing", true)
	f.set_meta("prod_t", 0.0)
	f.producing = true
	f.prod_t = 0.0

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_build")
	if ClassDB.class_exists("Sfx"):
		Sfx.play("vls_hatch_open", f.center_px())
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Сборка термоядерной боеголовки запущена (требуется 24 сек)...")

func _start_targeting(f: Facility) -> void:
	if not bool(f.get_meta("has_warhead", false)):
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("В шахте нет готовой боеголовки! Сначала произведите ЯБЧ.")
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return
	is_targeting = true
	is_placing = false
	targeting_silo = f
	target_point = Vector2.INF

	if ClassDB.class_exists("Sfx"):
		Sfx.play("alarm_general_quarters")
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("БОЕВАЯ ТРЕВОГА! Выберите точку нанесения термоядерного удара на карте.")

func _cancel_targeting() -> void:
	close_all()
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Наведение ядерного удара отменено.")

func set_target_point(wpos: Vector2) -> void:
	target_point = wpos
	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_select")
	if main_ref != null and "overlay" in main_ref and main_ref.overlay != null:
		main_ref.overlay.ripple(target_point, "alert_red")
	var cell: Vector2i = Vector2i(floori(wpos.x / float(GameWorld.CELL)), floori(wpos.y / float(GameWorld.CELL)))
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Цель зафиксирована: квадрат (%d, %d). Нажмите «ПУСК МБР» в меню!" % [cell.x, cell.y])

func launch_strike(target_world_pos: Vector2) -> void:
	if targeting_silo == null or not is_instance_valid(targeting_silo):
		_cancel_targeting()
		return

	var f = targeting_silo
	f.set_meta("has_warhead", false)
	f.missiles = 0
	is_targeting = false
	targeting_silo = null
	target_point = Vector2.INF

	var start_pos = f.center_px()
	var dist = start_pos.distance_to(target_world_pos)
	var flight_duration = clampf(5.5 + dist * 0.002, 6.5, 9.5)

	# Звук и эффекты пуска
	if ClassDB.class_exists("Sfx"):
		Sfx.play("vls_hatch_open", start_pos)
		Sfx.play("missile_launch", start_pos)
		Sfx.play("hyper_launch", start_pos)
	if world_ref.fx != null:
		world_ref.fx.spawn("tel_flash", start_pos.round(), 6)
		world_ref.fx.spawn("launch_cloud", start_pos.round(), 5)
		world_ref.fx.spawn("shockwave", start_pos.round(), 1)
	if world_ref.has_method("camera_shake_launch"):
		world_ref.camera_shake_launch(start_pos)

	var p = world_ref.player
	var m = {
		"from": start_pos,
		"target": target_world_pos,
		"t": 0.0,
		"duration": flight_duration,
		"whistled": false,
		"country_id": p.id if p != null else 1,
		"trail": []
	}
	active_missiles.append(m)

	if world_ref.has_method("say") and p != null:
		world_ref.say(p, Loc.mk("ВНИМАНИЕ: Произведён запуск стратегической МБР «Сармат»!"))

	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Пуск МБР «Сармат» выполнен! Подлёт к цели через %d сек." % int(ceil(flight_duration)))
	close_all()

func _repair_silo(f: Facility) -> void:
	var p = world_ref.player
	if p == null:
		return
	var cur_hp = float(f.get_meta("hp", SILO_MAX_HP))
	if cur_hp >= SILO_MAX_HP:
		return
	if p.money < SILO_REPAIR_COST:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает средств на ремонт шахты (требуется %d $)" % SILO_REPAIR_COST)
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return
	p.money -= SILO_REPAIR_COST
	f.set_meta("hp", SILO_MAX_HP)
	f.hp = SILO_MAX_HP
	if ClassDB.class_exists("Sfx"):
		Sfx.play("repair_work", f.center_px())
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Шахтный комплекс МБР полностью отремонтирован!")

func _demolish_silo(f: Facility) -> void:
	var p = world_ref.player
	if p != null:
		p.money += SILO_REFUND

	var d = world_ref.data
	if d != null:
		for dy in range(f.size.y):
			for dx in range(f.size.x):
				var cx = f.cell.x + dx
				var cy = f.cell.y + dy
				d.clear_flag(cx, cy, WorldData.F_OCCUPIED)

	if f.main_obj >= 0 and world_ref.has_method("remove_object"):
		world_ref.remove_object(f.main_obj)
	world_ref.mil.facilities.erase(f)

	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Шахтный комплекс МБР демонтирован (+%d $ возврат)." % SILO_REFUND)
	close_all()

func _tick_silos(delta: float) -> void:
	if world_ref == null or world_ref.mil == null:
		return
	for f in world_ref.mil.facilities:
		if f == null or not is_instance_valid(f):
			continue
		if not _is_silo(f):
			continue
		# Железная блокировка любого движения
		f.kind = Facility.Kind.CIV_FACTORY
		f.moving = false
		f.mdest = Vector2.ZERO
		f.mpos = f.center_px()

		if bool(f.get_meta("producing", false)):
			var t = float(f.get_meta("prod_t", 0.0)) + delta
			f.set_meta("prod_t", t)
			f.prod_t = t
			if t >= WARHEAD_TIME:
				f.set_meta("producing", false)
				f.producing = false
				f.set_meta("has_warhead", true)
				f.missiles = 1
				if ClassDB.class_exists("UiKit"):
					UiKit.snd("ui_victory")
				if ClassDB.class_exists("Sfx"):
					Sfx.play("vls_hatch_open", f.center_px())
				if main_ref != null and main_ref.hud != null:
					main_ref.hud.show_toast("Боеголовка смонтирована! МБР готова к ядерному удару.")

func _tick_missiles(delta: float) -> void:
	for i in range(active_missiles.size() - 1, -1, -1):
		var m = active_missiles[i]
		m["t"] += delta
		var k = clampf(m["t"] / m["duration"], 0.0, 1.0)
		var cur_ground = (m["from"] as Vector2).lerp(m["target"], k)
		var alt = 4.0 * 420.0 * k * (1.0 - k)
		var m_pos = cur_ground - Vector2(0, alt)

		var trail = m["trail"] as Array
		trail.append({"pos": m_pos, "t": 0.0})
		if trail.size() > 60:
			trail.pop_front()

		for tp in trail:
			tp["t"] += delta

		if not bool(m["whistled"]) and (m["duration"] - m["t"]) <= 1.8:
			m["whistled"] = true
			if ClassDB.class_exists("Sfx"):
				Sfx.play("missile_whistle", m["target"])

		if k >= 1.0:
			_detonate_nuclear(m)
			active_missiles.remove_at(i)

func _detonate_nuclear(m: Dictionary) -> void:
	var target_pos: Vector2 = m["target"]
	var cell: Vector2i = Vector2i(floori(target_pos.x / float(GameWorld.CELL)), floori(target_pos.y / float(GameWorld.CELL)))
	var country_id: int = int(m["country_id"])

	# 1. Регистрация гигантского ядерного взрыва (гриб + огненный купол + ударная волна)
	var puffs: Array = []
	for p_i in range(50):
		var ang = randf() * TAU
		var rad = randf_range(15.0, 115.0)
		puffs.append({
			"offset": Vector2(cos(ang) * rad, sin(ang) * rad * 0.65),
			"size": randf_range(32.0, 64.0),
			"burn": randf() > 0.4
		})

	var exp = {
		"pos": target_pos,
		"cell": cell,
		"t": 0.0,
		"duration": 12.0,
		"country_id": country_id,
		"max_radius": 260.0,
		"cloud_height": 190.0,
		"sound_phase": 0,
		"puffs": puffs
	}
	active_explosions.append(exp)

	# 2. Ослепляющая вспышка экрана ядерного удара
	_trigger_nuclear_flash()

	# 3. Каскад сокрушительных звуков
	if ClassDB.class_exists("Sfx"):
		Sfx.play("expl_big", target_pos, 4.0)
		Sfx.play("far_boom_1", target_pos, 4.0)
		Sfx.play("building_collapse", target_pos, 3.5)

	# 4. Мощнейшее сотрясение экрана
	if world_ref != null and world_ref.camera != null:
		world_ref.camera.shake_pattern([
			Vector2(20, -10), Vector2(-18, 14), Vector2(16, -16),
			Vector2(-15, 12), Vector2(12, 10), Vector2(-10, -12),
			Vector2(10, 8), Vector2(-8, -8), Vector2(6, 6), Vector2(-5, -4),
			Vector2(3, 3), Vector2(0, 0)
		], 0.06)

	# 5. Массивное формирование кратеров и разрушение построек
	var strike_offsets = [
		Vector2i(0, 0),
		Vector2i(-6, 0), Vector2i(6, 0), Vector2i(0, -6), Vector2i(0, 6),
		Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4), Vector2i(4, 4),
		Vector2i(-10, 0), Vector2i(10, 0), Vector2i(0, -10), Vector2i(0, 10),
		Vector2i(-8, -6), Vector2i(8, -6), Vector2i(-8, 6), Vector2i(8, 6),
		Vector2i(-12, -4), Vector2i(12, -4), Vector2i(-12, 4), Vector2i(12, 4)
	]
	for off in strike_offsets:
		if world_ref.has_method("_apply_strike"):
			world_ref._apply_strike(cell + off, 12, "crater_l", 75.0, country_id)

	# 6. Начальное выжигание эпицентра
	var d = world_ref.data
	if d != null:
		var init_burn = 8
		for dy in range(-init_burn, init_burn + 1):
			for dx in range(-init_burn, init_burn + 1):
				if dx * dx + dy * dy <= init_burn * init_burn:
					var cx = cell.x + dx
					var cy = cell.y + dy
					if d.inside(cx, cy):
						var b = d.get_biome(cx, cy)
						if Biome.is_natural_land(b):
							d.set_biome(cx, cy, Biome.BURNT)

	# 7. Уничтожение всей армии и техники в радиусе 260 пикселей
	if world_ref.army != null and world_ref.army.units != null:
		var blast_r_sq = 260.0 * 260.0
		for u in world_ref.army.units:
			if u != null and is_instance_valid(u) and u.alive:
				if u.pos.distance_squared_to(target_pos) <= blast_r_sq:
					u.hp = 0.0
					u.alive = false

	# 8. Разрушение военных баз и заводов врага
	if world_ref.mil != null and world_ref.mil.facilities != null:
		for f_item in world_ref.mil.facilities:
			if f_item == null or not is_instance_valid(f_item):
				continue
			if f_item.center_px().distance_to(target_pos) <= 260.0:
				f_item.hp = 0.0
				f_item.restore_t = 180.0
				if f_item.kind == Facility.Kind.NUCLEAR_PLANT or f_item.kind == Facility.Kind.POWER_PLANT:
					f_item.u_fuel = 0.0
					f_item.u_hits = 3
					var vict = world_ref.country_by_id(f_item.country_id)
					if vict != null:
						vict.power_cap = maxi(0, vict.power_cap - 60)
						if world_ref.has_method("say"):
							world_ref.say(vict, Loc.mk("КАТАСТРОФА! В результате термоядерного удара разрушена энергостанция! Полный блэкаут сети."))

	# 9. Спавн нативных пиксельных взрывов и дымовых завес из движка игры
	if world_ref.fx != null:
		world_ref.fx.spawn("shockwave", target_pos, 1)
		world_ref.fx.spawn("x_ball", target_pos, 7)
		world_ref.fx.spawn("explosion_l", target_pos, 7)
		for bi in range(6):
			var b_ang: float = float(bi) * (TAU / 6.0)
			var b_pos: Vector2 = target_pos + Vector2(cos(b_ang), sin(b_ang)) * randf_range(20.0, 50.0)
			world_ref.fx.spawn("explosion_m", b_pos, 6)
			world_ref.fx.spawn("launch_cloud", b_pos, 5)
		for k in range(20):
			var r_dist = randf_range(16.0, 200.0)
			var f_ang = randf() * TAU
			var fire_pos = target_pos + Vector2(cos(f_ang), sin(f_ang)) * r_dist
			world_ref.fx.spawn("fire_small", fire_pos, 4, world_ref.game_time + 50.0, true)
			world_ref.fx.spawn("smoke_column_loop", fire_pos + Vector2(0, -8), 6, world_ref.game_time + 55.0, true)

	if world_ref.has_method("say"):
		world_ref.say(world_ref.country_by_id(country_id), Loc.mk("ТЕРМОЯДЕРНЫЙ УДАР НАНЕСЁН ПО КВАДРАТУ (%d, %d)! Зона полностью уничтожена.", [cell.x, cell.y]))

	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Ядерный удар МБР нанесён! Цель и окружающая территория стёрты с лица земли.")

func _tick_explosions(delta: float) -> void:
	for i in range(active_explosions.size() - 1, -1, -1):
		var exp = active_explosions[i]
		exp["t"] += delta
		var t = float(exp["t"])

		# Прогрессивное выжигание земли ударной волной (до 30 клеток радиуса)
		var d = world_ref.data if world_ref != null else null
		if d != null and t <= 3.2:
			var prev_t = maxf(0.0, t - delta)
			var r_prev = (prev_t / 3.0) * float(exp["max_radius"])
			var r_curr = (t / 3.0) * float(exp["max_radius"])
			var cell_prev = int(r_prev / float(GameWorld.CELL))
			var cell_curr = mini(30, int(r_curr / float(GameWorld.CELL)))
			var target_cell: Vector2i = exp["cell"]
			for r in range(cell_prev, cell_curr + 1):
				for dy in range(-r, r + 1):
					for dx in range(-r, r + 1):
						var d_sq = dx * dx + dy * dy
						if d_sq <= r * r and d_sq > (r - 1) * (r - 1):
							var cx = target_cell.x + dx
							var cy = target_cell.y + dy
							if d.inside(cx, cy):
								var b = d.get_biome(cx, cy)
								if Biome.is_natural_land(b):
									d.set_biome(cx, cy, Biome.BURNT)
								var idx = cy * d.w + cx
								if world_ref.tree_at.has(idx):
									world_ref.tree_at.erase(idx)

		if exp["sound_phase"] == 0 and t >= 1.2:
			exp["sound_phase"] = 1
			if ClassDB.class_exists("Sfx"):
				Sfx.play("expl_big", exp["pos"], 3.5)
				Sfx.play("building_collapse", exp["pos"], 3.0)
		elif exp["sound_phase"] == 1 and t >= 2.5:
			exp["sound_phase"] = 2
			if ClassDB.class_exists("Sfx"):
				Sfx.play("far_boom_1", exp["pos"], 3.0)
		if t >= exp["duration"]:
			active_explosions.remove_at(i)

func _update_native_card(f: Facility) -> void:
	if main_ref == null or main_ref.hud == null:
		return
	var h = main_ref.hud
	var p = world_ref.player
	if p == null:
		return

	var has_w = bool(f.get_meta("has_warhead", false))
	var prod = bool(f.get_meta("producing", false))
	var hp = float(f.get_meta("hp", SILO_MAX_HP))
	var max_hp = float(f.get_meta("max_hp", SILO_MAX_HP))

	var title = "Шахтный комплекс МБР «Сармат»"
	var sub = "РВСН · Стратегический арсенал · Шахта #%d" % f.id
	h._card("nuclear_silo_%d" % f.id, "icon_m_ballistic", title, sub, false, false, true)

	var info = ""
	if has_w:
		info = Loc.t("СТАТУС: БОЕГОЛОВКА СМОНТИРОВАНА · МБР НА ДЕЖУРСТВЕ · ДАЛЬНОСТЬ: ГЛОБАЛЬНАЯ\nЗАПАС УРАНА В СТРАНЕ: %d ШТ. · ПРОЧНОСТЬ ШАХТЫ: %d/%d") % [p.uranium, int(hp), int(max_hp)]
	elif prod:
		var left_s = maxf(0.0, WARHEAD_TIME - float(f.get_meta("prod_t", 0.0)))
		info = Loc.t("СТАТУС: ОБОГАЩЕНИЕ УРАНА И МОНТАЖ ЯБЧ... %s\nЗАПАС УРАНА В СТРАНЕ: %d ШТ. · ПРОЧНОСТЬ ШАХТЫ: %d/%d") % [h._mmss(left_s), p.uranium, int(hp), int(max_hp)]
	else:
		info = Loc.t("СТАТУС: ШАХТА ПУСТА · ТРЕБУЕТСЯ СБОРКА ТЕРМОЯДЕРНОЙ БЧ (1500$ · 8 УРАНА)\nЗАПАС УРАНА В СТРАНЕ: %d ШТ. · ПРОЧНОСТЬ ШАХТЫ: %d/%d") % [p.uranium, int(hp), int(max_hp)]

	h._set_info(info, not has_w and not prod)
	h.ops_detail.text = "Стратегический ракетный комплекс шахтного базирования. Заглублённая железобетонная шахта с броневой крышкой способна выдержать бомбардировку. Оснащается межконтинентальной баллистической ракетой с разделяющейся головной частью термоядерного оснащения. Для сборки боеголовки требуется обогащённый уран с урановых шахт."
	h.ops_detail.visible = true

	var acts: Array = []
	if has_w:
		acts.append(h._act("ПУСК МБР", "icon_target", "nuke_target", true))
	elif prod:
		var left_s = maxf(0.0, WARHEAD_TIME - float(f.get_meta("prod_t", 0.0)))
		acts.append(h._act("ИДЁТ СБОРКА\n%s" % h._mmss(left_s), "icon_r_uranium", "none", false))
	else:
		var can_craft = p.money >= WARHEAD_COST_MONEY and p.uranium >= WARHEAD_COST_URANIUM
		acts.append(h._act("СБОРКА ЯБЧ\n1500 $ · 8 У", "icon_r_uranium", "nuke_craft", can_craft))

	acts.append(h._act("ЕЩЁ ШАХТА\n3500 $", "icon_m_ballistic", "nuke_build_another", p.money >= SILO_COST_MONEY and p.uranium >= SILO_COST_URANIUM))

	if hp < max_hp:
		acts.append(h._act("РЕМОНТ\n400 $", "icon_restore", "nuke_repair", p.money >= SILO_REPAIR_COST))

	var dact = h._act("СНОС\n+1750 $", "icon_close", "nuke_demolish", true)
	dact["red"] = true
	acts.append(dact)

	acts.append(h._act("ЗАКРЫТЬ", "icon_close", "nuke_close", true))
	h._fill_acts("nuclear_silo_acts_%d" % f.id, acts)

func _update_targeting_card() -> void:
	if main_ref == null or main_ref.hud == null or targeting_silo == null:
		return
	var h = main_ref.hud
	var title = "БОЕВАЯ ТРЕВОГА: НАВЕДЕНИЕ МБР"
	var sub = "Укажите квадрат удара на карте (ЛКМ/Тап — выбор, ПКМ — отмена)"
	h._card("nuke_targeting", "icon_m_ballistic", title, sub, false, false, true)

	if target_point == Vector2.INF:
		h._set_info("ТАПНИТЕ ПО КАРТЕ, ЧТОБЫ ВЫБРАТЬ ЦЕЛЬ ДЛЯ ТЕРМОЯДЕРНОГО УДАРА", false)
	else:
		var cell: Vector2i = Vector2i(floori(target_point.x / float(GameWorld.CELL)), floori(target_point.y / float(GameWorld.CELL)))
		var dist_km = targeting_silo.center_px().distance_to(target_point) * 0.004
		var flight_s = int(ceil(clampf(5.5 + targeting_silo.center_px().distance_to(target_point) * 0.002, 6.5, 9.5)))
		h._set_info("ЦЕЛЬ: КВАДРАТ (%d, %d) · ДИСТАНЦИЯ: %.1f КМ · ВРЕМЯ ПОЛЁТА: %d СЕК\nРАДИУС ПОРАЖЕНИЯ: 30 КЛЕТОК · ГЛОБАЛЬНЫЙ ТЕРМОЯДЕРНЫЙ ВЗРЫВ" % [cell.x, cell.y, dist_km, flight_s], false)

	h.ops_detail.text = "Наведение стратегической МБР «Сармат». После подтверждения пуска ракета выйдет из шахты на твердотопливном ускорителе, выйдет на баллистическую траекторию и сокрушит цель. Все строения, войска и ПВО противника в зоне будут полностью стёрты."
	h.ops_detail.visible = true

	var acts: Array = []
	var has_tgt = target_point != Vector2.INF
	acts.append(h._act("ПУСК МБР", "icon_target", "nuke_launch_confirm", has_tgt))
	if has_tgt:
		acts.append(h._act("СБРОС ЦЕЛИ", "icon_refresh", "nuke_target_reset", true))
	acts.append(h._act("ОТМЕНА", "icon_close", "nuke_cancel_target", true))
	h._fill_acts("nuclear_targeting_acts", acts)

# -------------------------------------------------------------
# Внутренний класс визуального слоя мира для NuclearStrike
# -------------------------------------------------------------
class NuclearWorldLayer extends Node2D:
	var mod = null
	var main: Node = null
	var world: Node = null

	func setup(p_mod, p_main: Node, p_world: Node) -> void:
		mod = p_mod
		main = p_main
		world = p_world
		z_index = 85

	func _unhandled_input(event: InputEvent) -> void:
		if mod == null or world == null or main == null:
			return

		var is_press: bool = false
		var is_cancel: bool = false
		var ev_pos: Vector2 = Vector2.ZERO

		if (mod.is_placing or mod.is_targeting) and (event is InputEventMouseButton or event is InputEventScreenTouch) and not event.pressed:
			get_viewport().set_input_as_handled()
			return

		if event is InputEventMouseButton:
			if event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					is_press = true
					ev_pos = event.position
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					is_cancel = true
		elif event is InputEventScreenTouch:
			if event.pressed:
				is_press = true
				ev_pos = event.position

		if event is InputEventKey and event.pressed and not event.echo:
			if (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and not event.alt_pressed:
				if mod.is_targeting and mod.target_point != Vector2.INF:
					mod._on_hud_action("nuke_launch_confirm")
					get_viewport().set_input_as_handled()
					return
			if event.keycode == KEY_ESCAPE:
				if mod.is_placing:
					mod.cancel_placement()
					get_viewport().set_input_as_handled()
					return
				elif mod.is_targeting or mod.selected_fac != null:
					mod.close_all()
					get_viewport().set_input_as_handled()
					return

		if is_press:
			var wp: Vector2 = main.cam.screen_to_world(ev_pos) if main.cam != null else ev_pos
			var cell = Vector2i((wp / float(GameWorld.CELL)).floor())

			if mod.is_placing:
				mod.place_silo_at(cell)
				get_viewport().set_input_as_handled()
				return
			elif mod.is_targeting:
				mod.set_target_point(wp)
				get_viewport().set_input_as_handled()
				return

		elif is_cancel:
			if mod.is_placing:
				mod.cancel_placement()
				get_viewport().set_input_as_handled()
				return
			elif mod.is_targeting or mod.selected_fac != null:
				mod.close_all()
				get_viewport().set_input_as_handled()
				return

	const P_BLOCK: float = 4.0

	func _draw_pixel_span(bx_start: int, bx_end: int, by: int, col: Color) -> void:
		if bx_end < bx_start or col.a <= 0.001:
			return
		draw_rect(Rect2(float(bx_start) * P_BLOCK, float(by) * P_BLOCK, float(bx_end - bx_start + 1) * P_BLOCK, P_BLOCK), col)

	func _draw_pixel_disc_grid(cx: int, cy: int, r_blocks: int, col: Color) -> void:
		if r_blocks <= 0 or col.a <= 0.001:
			return
		var r_sq = r_blocks * r_blocks
		for dy in range(-r_blocks, r_blocks + 1):
			var dy_sq = dy * dy
			var dx = int(floor(sqrt(float(r_sq - dy_sq))))
			_draw_pixel_span(cx - dx, cx + dx, cy + dy, col)

	func _draw_pixel_ellipse_grid(cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
		if rx <= 0 or ry <= 0 or col.a <= 0.001:
			return
		var ry_f = float(ry)
		var rx_f = float(rx)
		for dy in range(-ry, ry + 1):
			var norm_y = float(dy) / ry_f
			var dx = int(floor(rx_f * sqrt(maxf(0.0, 1.0 - norm_y * norm_y))))
			_draw_pixel_span(cx - dx, cx + dx, cy + dy, col)

	func _draw_pixel_ring_grid(cx: int, cy: int, r_outer: int, thick_blocks: int, col: Color) -> void:
		if r_outer <= 0 or col.a <= 0.001:
			return
		var r_inner = max(0, r_outer - thick_blocks)
		var r_out_sq = r_outer * r_outer
		var r_in_sq = r_inner * r_inner
		for dy in range(-r_outer, r_outer + 1):
			var dy_sq = dy * dy
			if dy_sq > r_out_sq:
				continue
			var dx_out = int(floor(sqrt(float(r_out_sq - dy_sq))))
			var dx_in = int(floor(sqrt(float(r_in_sq - dy_sq)))) if dy_sq < r_in_sq else 0
			if dx_out > dx_in:
				_draw_pixel_span(cx - dx_out, cx - dx_in, cy + dy, col)
				_draw_pixel_span(cx + dx_in, cx + dx_out, cy + dy, col)
			elif dx_out == dx_in and dx_out > 0:
				_draw_pixel_span(cx - dx_out, cx - dx_out, cy + dy, col)
				_draw_pixel_span(cx + dx_out, cx + dx_out, cy + dy, col)

	func _draw() -> void:
		if mod == null or world == null or main == null:
			return

		var mouse_sp: Vector2 = get_viewport().get_mouse_position()
		var mouse_w: Vector2 = main.cam.screen_to_world(mouse_sp) if main.cam != null else mouse_sp

		# 1. Отрисовка призрака при постройке шахты по сетке
		if mod.is_placing:
			var cell = Vector2i((mouse_w / float(GameWorld.CELL)).floor())
			var valid = mod.can_place_at(cell)

			var pos = Vector2(cell * GameWorld.CELL)
			var sz = Vector2(mod.SILO_SIZE * GameWorld.CELL)

			var fill_col = Color(0.2, 1.0, 0.3, 0.25) if valid else Color(1.0, 0.25, 0.25, 0.25)
			var outline_col = Color(0.2, 1.0, 0.3, 0.95) if valid else Color(1.0, 0.25, 0.25, 0.95)

			draw_rect(Rect2(pos, sz), fill_col)
			draw_rect(Rect2(pos, sz), outline_col, false, 2.0)

			for x in range(mod.SILO_SIZE.x + 1):
				var lx = pos.x + float(x * GameWorld.CELL)
				draw_line(Vector2(lx, pos.y), Vector2(lx, pos.y + sz.y), Color(outline_col.r, outline_col.g, outline_col.b, 0.3), 1.0)
			for y in range(mod.SILO_SIZE.y + 1):
				var ly = pos.y + float(y * GameWorld.CELL)
				draw_line(Vector2(pos.x, ly), Vector2(pos.x + sz.x, ly), Color(outline_col.r, outline_col.g, outline_col.b, 0.3), 1.0)

			var center_p = pos + sz * 0.5
			draw_circle(center_p, 6.0, Color(0.15, 0.18, 0.22, 0.85))
			draw_arc(center_p, 6.0, 0.0, TAU, 24, outline_col, 1.5)
			draw_circle(center_p, 2.5, Color(outline_col.r, outline_col.g, outline_col.b, 0.9))
			draw_arc(center_p, 22.0, 0.0, TAU, 32, Color(outline_col.r, outline_col.g, outline_col.b, 0.4), 1.0)

		# 2. Отрисовка тактического прицела при ядерном наведении
		if mod.is_targeting:
			var t_time = float(Time.get_ticks_msec()) * 0.005
			var pulse = 0.8 + 0.2 * sin(t_time * 5.0)
			var aim_pos = mod.target_point if mod.target_point != Vector2.INF else mouse_w

			if mod.targeting_silo != null and is_instance_valid(mod.targeting_silo):
				var silo_pos = mod.targeting_silo.center_px()
				draw_line(silo_pos, aim_pos, Color(1.0, 0.8, 0.2, 0.4 * pulse), 1.5)
				draw_circle(silo_pos, 4.0, Color(1.0, 0.85, 0.2, 0.8))

			# Окружность радиуса поражения (радиус 260px)
			draw_circle(aim_pos, 260.0, Color(1.0, 0.15, 0.1, 0.15 * pulse))
			draw_arc(aim_pos, 260.0, 0.0, TAU, 64, Color(1.0, 0.85, 0.2, 0.9 * pulse), 2.5)
			draw_arc(aim_pos, 130.0, 0.0, TAU, 48, Color(1.0, 0.3, 0.1, 0.5 * pulse), 1.5)

			# Тактическое перекрестье
			draw_line(aim_pos - Vector2(36, 0), aim_pos + Vector2(36, 0), Color(1.0, 0.2, 0.1, 0.95), 2.0)
			draw_line(aim_pos - Vector2(0, 36), aim_pos + Vector2(0, 36), Color(1.0, 0.2, 0.1, 0.95), 2.0)
			draw_circle(aim_pos, 5.0, Color(1.0, 0.9, 0.15, 1.0))

		# 3. Отрисовка построенных шахт на карте (железобетонный бронекупол и статус)
		if world.mil != null and world.mil.facilities != null:
			for f in world.mil.facilities:
				if f == null or not is_instance_valid(f):
					continue
				if not f.has_meta("is_nuclear_silo"):
					continue
				var f_pos = Vector2(f.cell * GameWorld.CELL)
				var f_sz = Vector2(f.size * GameWorld.CELL)
				var center_px = f.center_px()

				# Плита фундамента
				draw_rect(Rect2(f_pos, f_sz), Color(0.2, 0.22, 0.25, 0.45))
				draw_rect(Rect2(f_pos, f_sz), Color(0.35, 0.38, 0.42, 0.9), false, 1.5)

				# Бронелюк шахты
				draw_circle(center_px, 8.0, Color(0.12, 0.14, 0.16, 0.95))
				draw_arc(center_px, 8.0, 0.0, TAU, 24, Color(0.5, 0.55, 0.6), 1.5)

				# Индикатор готовности
				var has_w = bool(f.get_meta("has_warhead", false))
				var prod = bool(f.get_meta("producing", false))
				var led_col = Color(0.2, 1.0, 0.3, 0.95) if has_w else (Color(1.0, 0.8, 0.2, 0.95) if prod else Color(1.0, 0.25, 0.25, 0.8))
				draw_circle(center_px, 3.0, led_col)

		# 4. Отрисовка летящей МБР и дымного инверсионного следа
		for m in mod.active_missiles:
			var k = clampf(m["t"] / m["duration"], 0.0, 1.0)
			var cur_ground = (m["from"] as Vector2).lerp(m["target"], k)
			var alt = 4.0 * 420.0 * k * (1.0 - k)
			var m_pos = cur_ground - Vector2(0, alt)

			# Тень на земле
			draw_circle(cur_ground, 4.5, Color(0.0, 0.0, 0.0, 0.45))

			# Дымный след
			var trail = m["trail"] as Array
			for tp in trail:
				var tr_age = float(tp["t"])
				var tr_a = clampf(1.0 - tr_age / 2.0, 0.0, 0.7)
				var tr_sz = 3.0 + tr_age * 4.0
				draw_circle(tp["pos"], tr_sz, Color(0.85, 0.88, 0.92, tr_a))

			# Корпус ракеты
			var next_k = minf(1.0, k + 0.01)
			var next_g = (m["from"] as Vector2).lerp(m["target"], next_k)
			var next_alt = 4.0 * 420.0 * next_k * (1.0 - next_k)
			var next_pos = next_g - Vector2(0, next_alt)
			var dir = (next_pos - m_pos).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.UP

			draw_line(m_pos - dir * 14.0, m_pos + dir * 6.0, Color(0.92, 0.94, 0.96), 3.5)
			draw_circle(m_pos + dir * 6.0, 2.5, Color(0.2, 0.22, 0.25)) # Головная часть
			# Пламя двигателя
			draw_line(m_pos - dir * 14.0, m_pos - dir * 26.0, Color(1.0, 0.75, 0.15), 3.0)

		# 5. Отрисовка термоядерного гриба и ударной волны (100% пиксель-арт стиль песочницы)
		for exp in mod.active_explosions:
			var pos: Vector2 = exp["pos"]
			var t: float = float(exp["t"])
			var max_rad: float = float(exp["max_radius"])
			var cloud_h: float = float(exp["cloud_height"])

			var orig_gx: int = int(round(pos.x / P_BLOCK))
			var orig_gy: int = int(round(pos.y / P_BLOCK))

			# А) Ступенчатая пиксельная ударная волна (0 .. 2.8 сек)
			if t < 2.8:
				var sw_prog = clampf(t / 2.6, 0.0, 1.0)
				var sw_blocks = int(round(sin(sw_prog * PI * 0.5) * (max_rad / P_BLOCK)))
				var sw_alpha = (1.0 - sw_prog) * 0.85
				if sw_blocks > 0:
					_draw_pixel_ring_grid(orig_gx, orig_gy, sw_blocks, 2, Color(1.0, 0.95, 0.7, sw_alpha))
					_draw_pixel_ring_grid(orig_gx, orig_gy, int(sw_blocks * 0.94), 1, Color(1.0, 0.45, 0.08, sw_alpha * 0.75))
				var spark_n = 18
				for s_i in range(spark_n):
					var s_ang = float(s_i) * (TAU / float(spark_n)) + t * 2.0
					var sp_gx = orig_gx + int(round(cos(s_ang) * float(sw_blocks + 1)))
					var sp_gy = orig_gy + int(round(sin(s_ang) * float(sw_blocks + 1) * 0.7))
					_draw_pixel_span(sp_gx, sp_gx, sp_gy, Color(1.0, 0.9, 0.3, sw_alpha))

			# Б) Пиксельный огненный шар в эпицентре (0 .. 3.6 сек)
			if t < 3.6:
				var fb_prog = clampf(t / 0.75, 0.0, 1.0) if t <= 0.75 else maxf(0.0, 1.0 - (t - 0.75) / 2.85)
				var fb_blocks = int(round(sin(fb_prog * PI * 0.5) * 22.0))
				var fb_alpha = clampf(1.0 - (t - 0.5) / 3.1, 0.0, 1.0)
				if fb_blocks > 0 and fb_alpha > 0.0:
					_draw_pixel_disc_grid(orig_gx, orig_gy, int(fb_blocks * 1.25), Color(0.14, 0.12, 0.10, fb_alpha * 0.7))
					_draw_pixel_disc_grid(orig_gx, orig_gy, fb_blocks, Color(0.95, 0.28, 0.05, fb_alpha * 0.9))
					_draw_pixel_disc_grid(orig_gx, orig_gy, int(fb_blocks * 0.68), Color(1.0, 0.75, 0.12, fb_alpha * 0.95))
					_draw_pixel_disc_grid(orig_gx, orig_gy, int(fb_blocks * 0.35), Color(1.0, 1.0, 0.9, fb_alpha))

			# В) Аутентичный пиксель-арт термоядерный гриб (ножка, юбка и шапка) (0.25 .. 12.0 сек)
			if t > 0.25:
				var rise_k = clampf((t - 0.25) / 4.0, 0.0, 1.0)
				var cloud_a = clampf(1.0 - (t - 4.5) / 7.5, 0.0, 0.95) if t > 4.5 else clampf((t - 0.25) / 0.7, 0.0, 0.95)
				var cap_h_blocks = int(round(rise_k * (cloud_h / P_BLOCK)))
				var cap_gy = orig_gy - cap_h_blocks

				# 1. Юбка у основания (Ground skirt / Wilson cloud)
				var skirt_rx = int(10 + rise_k * 18)
				var skirt_ry = int(3 + rise_k * 4)
				_draw_pixel_ellipse_grid(orig_gx, orig_gy, skirt_rx, skirt_ry, Color(0.12, 0.11, 0.10, cloud_a * 0.85))
				_draw_pixel_ellipse_grid(orig_gx, orig_gy, int(skirt_rx * 0.75), int(skirt_ry * 0.65), Color(0.28, 0.25, 0.23, cloud_a * 0.75))

				# 2. Ствол / ножка гриба (Column / Stem)
				for sy in range(cap_gy, orig_gy + 1):
					var hk = float(orig_gy - sy) / maxf(1.0, float(cap_h_blocks))
					var stem_half = int(round(3.5 + 2.0 * sin(hk * PI) + (1.0 - hk) * 3.5 + (hk * hk) * 2.5))
					# Тёмный контур дыма
					_draw_pixel_span(orig_gx - stem_half, orig_gx + stem_half, sy, Color(0.12, 0.11, 0.10, cloud_a * 0.95))
					# Пепельный дым
					_draw_pixel_span(orig_gx - stem_half + 1, orig_gx + stem_half - 1, sy, Color(0.25, 0.23, 0.21, cloud_a * 0.9))
					# Восходящий огненный вихрь внутри ствола
					if t < 6.5 and stem_half >= 3:
						var fw = stem_half - 2
						var fire_fade = cloud_a * (1.0 - hk * 0.45) * maxf(0.0, 1.0 - (t - 0.8) / 5.7)
						_draw_pixel_span(orig_gx - fw, orig_gx + fw, sy, Color(0.95, 0.45, 0.08, fire_fade * 0.85))
						if fw >= 2 and t < 3.5:
							_draw_pixel_span(orig_gx - (fw - 1), orig_gx + (fw - 1), sy, Color(1.0, 0.85, 0.22, fire_fade * 0.95))

				# 3. Шляпка гриба (Тороид / Anvil / Cap)
				var cap_rx = int(round((14 + rise_k * 26) * (1.0 + 0.04 * sin(t * 2.0))))
				var cap_ry = int(round(8 + rise_k * 13))

				# Слой 1: Внешняя тёмная окантовка всей шапки (силуэт)
				var col_dark = Color(0.10, 0.09, 0.09, cloud_a * 0.95)
				_draw_pixel_ellipse_grid(orig_gx, cap_gy, cap_rx, cap_ry, col_dark)
				_draw_pixel_ellipse_grid(orig_gx - int(cap_rx * 0.58), cap_gy + int(cap_ry * 0.25), int(cap_rx * 0.44), int(cap_ry * 0.65), col_dark)
				_draw_pixel_ellipse_grid(orig_gx + int(cap_rx * 0.58), cap_gy + int(cap_ry * 0.25), int(cap_rx * 0.44), int(cap_ry * 0.65), col_dark)
				_draw_pixel_ellipse_grid(orig_gx, cap_gy - int(cap_ry * 0.4), int(cap_rx * 0.6), int(cap_ry * 0.55), col_dark)

				# Слой 2: Основное дымное тело шапки
				var col_smoke = Color(0.22, 0.20, 0.19, cloud_a * 0.9)
				_draw_pixel_ellipse_grid(orig_gx, cap_gy, cap_rx - 1, cap_ry - 1, col_smoke)
				_draw_pixel_ellipse_grid(orig_gx - int(cap_rx * 0.58), cap_gy + int(cap_ry * 0.25), int(cap_rx * 0.44) - 1, int(cap_ry * 0.65) - 1, col_smoke)
				_draw_pixel_ellipse_grid(orig_gx + int(cap_rx * 0.58), cap_gy + int(cap_ry * 0.25), int(cap_rx * 0.44) - 1, int(cap_ry * 0.65) - 1, col_smoke)
				_draw_pixel_ellipse_grid(orig_gx, cap_gy - int(cap_ry * 0.4), int(cap_rx * 0.6) - 1, int(cap_ry * 0.55) - 1, col_smoke)

				# Слой 3: Светлые клубы и блики на гребнях (пиксельные складки дыма)
				var col_light = Color(0.42, 0.38, 0.36, cloud_a * 0.85)
				_draw_pixel_ellipse_grid(orig_gx, cap_gy - int(cap_ry * 0.45), int(cap_rx * 0.42), int(cap_ry * 0.35), col_light)
				_draw_pixel_ellipse_grid(orig_gx - int(cap_rx * 0.4), cap_gy - int(cap_ry * 0.25), int(cap_rx * 0.28), int(cap_ry * 0.3), col_light)
				_draw_pixel_ellipse_grid(orig_gx + int(cap_rx * 0.4), cap_gy - int(cap_ry * 0.25), int(cap_rx * 0.28), int(cap_ry * 0.3), col_light)

				# Слой 4: Огненная подсветка нижней части шапки из эпицентра
				if t < 6.0:
					var fire_cap_a = cloud_a * maxf(0.0, 1.0 - t / 6.0)
					var col_fire = Color(0.92, 0.42, 0.08, fire_cap_a * 0.85)
					var col_hot = Color(1.0, 0.80, 0.20, fire_cap_a * 0.95)
					_draw_pixel_ellipse_grid(orig_gx, cap_gy + int(cap_ry * 0.3), int(cap_rx * 0.48), int(cap_ry * 0.4), col_fire)
					if t < 3.5:
						_draw_pixel_ellipse_grid(orig_gx, cap_gy + int(cap_ry * 0.35), int(cap_rx * 0.28), int(cap_ry * 0.25), col_hot)

				# 4. Пиксельные искры и частицы пепла в воздухе
				if t < 8.0:
					var ember_seed = int(pos.x + pos.y) % 100
					for e_i in range(24):
						var e_ang = float(e_i * 37 + ember_seed) * 0.1
						var e_dist_b = int(fmod(float(e_i * 7 + int(t * 12)), float(cap_rx + 12))) + 4
						var e_h_b = int(fmod(float(e_i * 5 + int(t * 10)), float(cap_h_blocks + 15)))
						var e_gx = orig_gx + int(cos(e_ang) * float(e_dist_b))
						var e_gy = orig_gy - e_h_b + int(sin(e_ang) * float(e_dist_b) * 0.3)
						_draw_pixel_span(e_gx, e_gx, e_gy, Color(1.0, 0.65, 0.15, cloud_a * 0.8))
