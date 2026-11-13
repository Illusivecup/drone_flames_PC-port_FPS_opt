extends RefCounted

## Модификация «ОТРК «Искандер-М» (9К720)» для DroneFlames PC Port.
## Высокоточный оперативно-тактический ракетный комплекс сухопутных войск.
## Запуск аэробаллистических твердотопливных ракет 9М723 с квазибаллистической
## траекторией, гиперзвуковым пикированием и проникающим уроном в 650 ед.

const TEL_COST_MONEY: int = 2200
const TEL_COST_METAL: int = 12
const RELOAD_COST_MONEY: int = 800
const RELOAD_COST_METAL: int = 4
const RELOAD_TIME: float = 10.0
const TEL_SIZE: Vector2i = Vector2i(3, 3)
const TEL_MAX_HP: float = 550.0
const TEL_REFUND: int = 1100
const TEL_REPAIR_COST: int = 250
const CELL_KEY: String = "iskander_tel"

var mm_ref: Node = null
var main_ref: Node = null
var world_ref: Node = null

var world_layer: Node2D = null

var is_placing: bool = false
var is_targeting: bool = false
var selected_tel: Facility = null
var targeting_tel: Facility = null
var target_point: Vector2 = Vector2.INF
var anim_t: float = 0.0

var active_missiles: Array = []
var active_submunitions: Array = []
var active_explosions: Array = []
var targeting_mode: String = "he"

const BuildPanel = preload("res://ui/ui24/build_panel.gd")

# ==============================================================================
# Слой отрисовки и ввода (размещение, прицеливание, ракеты, взрывы)
# ==============================================================================
class IskanderWorldLayer extends Node2D:
	var mod: RefCounted = null
	var main: Node = null
	var world: Node = null

	func setup(p_mod: RefCounted, p_main: Node, p_world: Node) -> void:
		mod = p_mod
		main = p_main
		world = p_world
		z_index = 86

	func _process(delta: float) -> void:
		if mod == null:
			return
		if mod.is_placing or mod.is_targeting or not mod.active_missiles.is_empty() or not mod.active_submunitions.is_empty() or not mod.active_explosions.is_empty():
			queue_redraw()

	func _unhandled_input(event: InputEvent) -> void:
		if mod == null or world == null or main == null:
			return

		if event is InputEventKey and event.pressed and not event.echo:
			if (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and not event.alt_pressed:
				if mod.is_targeting:
					var mouse_sp: Vector2 = get_viewport().get_mouse_position()
					var mouse_w: Vector2 = main.cam.screen_to_world(mouse_sp) if main.cam != null else mouse_sp
					mod.try_fire_at(mouse_w)
					get_viewport().set_input_as_handled()
					return
			elif event.keycode == KEY_ESCAPE:
				if mod.is_placing:
					mod.cancel_placement()
					get_viewport().set_input_as_handled()
					return
				elif mod.is_targeting or mod.selected_tel != null:
					mod.close_all()
					get_viewport().set_input_as_handled()
					return

		if event is InputEventMouseButton:
			if event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					var wp: Vector2 = main.cam.screen_to_world(event.position) if main.cam != null else event.position
					var cell: Vector2i = Vector2i((wp / float(GameWorld.CELL)).floor())
					if mod.is_placing:
						mod.place_tel_at(cell)
						get_viewport().set_input_as_handled()
						return
					elif mod.is_targeting:
						mod.try_fire_at(wp)
						get_viewport().set_input_as_handled()
						return
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					if mod.is_placing:
						mod.cancel_placement()
						get_viewport().set_input_as_handled()
						return
					elif mod.is_targeting or mod.selected_tel != null:
						mod.close_all()
						get_viewport().set_input_as_handled()
						return
			else:
				if mod.is_placing or mod.is_targeting:
					get_viewport().set_input_as_handled()
					return

		elif event is InputEventScreenTouch:
			if event.pressed:
				var wp: Vector2 = main.cam.screen_to_world(event.position) if main.cam != null else event.position
				var cell: Vector2i = Vector2i((wp / float(GameWorld.CELL)).floor())
				if mod.is_placing:
					mod.place_tel_at(cell)
					get_viewport().set_input_as_handled()
					return
				elif mod.is_targeting:
					mod.try_fire_at(wp)
					get_viewport().set_input_as_handled()
					return
			else:
				if mod.is_placing or mod.is_targeting:
					get_viewport().set_input_as_handled()
					return

	func _draw() -> void:
		if mod == null or world == null or main == null:
			return

		var mouse_sp: Vector2 = get_viewport().get_mouse_position()
		var mouse_w: Vector2 = main.cam.screen_to_world(mouse_sp) if main.cam != null else mouse_sp

		# 1. Призрак размещения ОТРК (зелёный/красный квадрат)
		if mod.is_placing:
			var cell: Vector2i = Vector2i((mouse_w / float(GameWorld.CELL)).floor())
			var valid: bool = mod.can_place_at(cell)
			var pos: Vector2 = Vector2(cell * GameWorld.CELL)
			var sz: Vector2 = Vector2(TEL_SIZE * GameWorld.CELL)
			var fill_col: Color = Color(0.2, 1.0, 0.3, 0.25) if valid else Color(1.0, 0.25, 0.25, 0.25)
			var line_col: Color = Color(0.2, 1.0, 0.3, 0.95) if valid else Color(1.0, 0.25, 0.25, 0.95)
			draw_rect(Rect2(pos, sz), fill_col)
			draw_rect(Rect2(pos, sz), line_col, false, 2.0)
			# Маркер центра пусковой
			draw_circle(pos + sz * 0.5, 4.0, line_col)

		# 2. Наведение на цель (динамически следует за курсором в реальном времени, как у «Солнцепёка»)
		mod.draw_targeting(self, mouse_w)

		# 3. Полёт ракет 9М723 / 9М723К (Реалистичный гиперзвуковой силуэт)
		for m in mod.active_missiles:
			var trail: Array = m["trail"]
			for t_idx in range(trail.size() - 1):
				var alpha: float = float(t_idx) / float(trail.size())
				var c: Color = Color(1.0, 0.6, 0.15, alpha * 0.8)
				draw_line(trail[t_idx]["pos"], trail[t_idx + 1]["pos"], c, 3.5 * alpha + 1.0)
				if t_idx > trail.size() - 8:
					var core_a = (float(t_idx - (trail.size() - 8)) / 8.0) * 0.9
					draw_line(trail[t_idx]["pos"], trail[t_idx + 1]["pos"], Color(1.0, 1.0, 0.8, core_a), 2.0)

			var cur_p: Vector2 = m.get("cur_pos", Vector2.ZERO)
			var cur_ground: Vector2 = m.get("cur_ground", cur_p)
			var dir: Vector2 = m.get("dir", Vector2.DOWN)
			var perp: Vector2 = Vector2(-dir.y, dir.x)

			# Тень на земле под ракетой
			var shadow_len: float = 12.0
			draw_line(cur_ground - dir * shadow_len * 0.5, cur_ground + dir * shadow_len * 0.5, Color(0, 0, 0, 0.35), 3.0)

			var is_cl: bool = m.get("type", "he") == "cluster"
			if is_cl:
				# УНИКАЛЬНАЯ РАКЕТА ДЛЯ КАССЕТЫ:
				# Массивный широкий цилиндрический кассетный отсек (контейнерная БЧ)
				var c_tail_p: Vector2 = cur_p - dir * 11.0
				var c_nose_p: Vector2 = cur_p + dir * 11.0
				var c_flame_p: Vector2 = c_tail_p - dir * 15.0

				# Двойной реактивный факел с искрами
				draw_colored_polygon(PackedVector2Array([
					c_tail_p - perp * 3.4,
					c_tail_p + perp * 3.4,
					c_flame_p
				]), Color(1.0, 0.4, 0.05, 0.95))
				draw_colored_polygon(PackedVector2Array([
					c_tail_p - perp * 2.0,
					c_tail_p + perp * 2.0,
					c_tail_p - dir * 9.0
				]), Color(1.0, 0.95, 0.5, 1.0))

				# Корпус: тактический песчано-стальной камуфляж
				var c_body: PackedVector2Array = PackedVector2Array([
					c_tail_p - perp * 3.6,
					cur_p + dir * 5.0 - perp * 3.6,
					c_nose_p,
					cur_p + dir * 5.0 + perp * 3.6,
					c_tail_p + perp * 3.6
				])
				draw_colored_polygon(c_body, Color(0.44, 0.42, 0.38))
				draw_polyline(c_body, Color(0.16, 0.15, 0.14), 1.2)

				# Яркие оранжево-желтые полосы маркировки кассетного отсека
				var band_p1 = cur_p - dir * 1.0
				var band_p2 = cur_p + dir * 2.5
				draw_line(band_p1 - perp * 3.4, band_p1 + perp * 3.4, Color(1.0, 0.72, 0.1, 0.95), 2.0)
				draw_line(band_p2 - perp * 3.4, band_p2 + perp * 3.4, Color(1.0, 0.72, 0.1, 0.95), 2.0)

				# Характерный тупоконечный обтекатель кассетного модуля
				var c_cone: PackedVector2Array = PackedVector2Array([
					cur_p + dir * 5.0 - perp * 3.4,
					c_nose_p,
					cur_p + dir * 5.0 + perp * 3.4
				])
				draw_colored_polygon(c_cone, Color(0.78, 0.72, 0.6))

				# Решётчатые (lattice) стабилизаторы на хвосте
				draw_line(c_tail_p - perp * 3.2, c_tail_p - perp * 8.5 - dir * 2.5, Color(0.2, 0.2, 0.2), 2.0)
				draw_line(c_tail_p + perp * 3.2, c_tail_p + perp * 8.5 - dir * 2.5, Color(0.2, 0.2, 0.2), 2.0)
				draw_line(c_tail_p - perp * 8.5 - dir * 2.5, c_tail_p - perp * 8.5 + dir * 1.5, Color(0.2, 0.2, 0.2), 1.5)
				draw_line(c_tail_p + perp * 8.5 - dir * 2.5, c_tail_p + perp * 8.5 + dir * 1.5, Color(0.2, 0.2, 0.2), 1.5)
			else:
				# БАЗОВАЯ РАКЕТА ФУГАС:
				var tail_p: Vector2 = cur_p - dir * 10.0
				var nose_p: Vector2 = cur_p + dir * 10.0
				var flame_p: Vector2 = tail_p - dir * 12.0

				# Факел реактивного двигателя
				draw_colored_polygon(PackedVector2Array([
					tail_p - perp * 2.5,
					tail_p + perp * 2.5,
					flame_p
				]), Color(1.0, 0.5, 0.1, 0.9))
				draw_colored_polygon(PackedVector2Array([
					tail_p - perp * 1.5,
					tail_p + perp * 1.5,
					tail_p - dir * 7.0
				]), Color(1.0, 0.95, 0.6, 1.0))

				# Корпус ракеты (оливково-серый фюзеляж)
				var body_poly: PackedVector2Array = PackedVector2Array([
					tail_p - perp * 2.5,
					cur_p + dir * 4.0 - perp * 2.5,
					nose_p,
					cur_p + dir * 4.0 + perp * 2.5,
					tail_p + perp * 2.5
				])
				draw_colored_polygon(body_poly, Color(0.28, 0.33, 0.3))
				draw_polyline(body_poly, Color(0.12, 0.15, 0.13), 1.0)

				# Белый конический головной обтекатель ГСН
				var cone_poly: PackedVector2Array = PackedVector2Array([
					cur_p + dir * 4.0 - perp * 2.2,
					nose_p,
					cur_p + dir * 4.0 + perp * 2.2
				])
				draw_colored_polygon(cone_poly, Color(0.9, 0.92, 0.88))

				# Аэродинамические рули на хвосте
				draw_line(tail_p - perp * 2.0, tail_p - perp * 6.5 - dir * 2.0, Color(0.15, 0.18, 0.16), 1.5)
				draw_line(tail_p + perp * 2.0, tail_p + perp * 6.5 - dir * 2.0, Color(0.15, 0.18, 0.16), 1.5)

		# 4. Кассетные суббоеприпасы в полёте
		for sub in mod.active_submunitions:
			var s_trail: Array = sub["trail"]
			for s_i in range(s_trail.size() - 1):
				var a: float = float(s_i) / float(s_trail.size())
				draw_line(s_trail[s_i], s_trail[s_i + 1], Color(1.0, 0.55, 0.15, a * 0.75), 2.2 * a + 0.6)
			if s_trail.size() > 0:
				var tip = s_trail[-1]
				draw_circle(tip, 2.8, Color(1.0, 0.95, 0.5, 1.0))

		# 5. Взрывы и расширяющаяся ударная волна
		for exp in mod.active_explosions:
			var p: Vector2 = exp["pos"]
			var t: float = float(exp["t"])
			var dur: float = float(exp["duration"])
			var prog: float = clampf(t / dur, 0.0, 1.0)
			var max_rad: float = float(exp["radius"])

			# Ударная волна
			if bool(exp.get("is_shockwave", false)):
				var wave_prog = clampf(t / (dur * 0.85), 0.0, 1.0)
				var ease_rad = (1.0 - pow(1.0 - wave_prog, 2.5)) * max_rad
				var wave_alpha = 1.0 - wave_prog
				draw_arc(p, ease_rad, 0.0, TAU, 48, Color(1.0, 0.95, 0.8, wave_alpha * 0.9), 3.5)
				draw_arc(p, maxf(0.0, ease_rad - 6.0), 0.0, TAU, 36, Color(1.0, 0.6, 0.2, wave_alpha * 0.6), 2.0)
				draw_circle(p, ease_rad, Color(1.0, 0.7, 0.3, wave_alpha * 0.08))

			# Огненный шар взрыва
			var fire_rad: float = float(exp.get("fire_radius", 48.0)) * sin(prog * PI * 0.5)
			var alpha: float = 1.0 - prog
			draw_circle(p, fire_rad, Color(1.0, 0.4 + 0.5 * (1.0 - prog), 0.1, alpha * 0.8))
			draw_circle(p, fire_rad * 0.6, Color(1.0, 0.9, 0.4, alpha * 0.9))
			draw_arc(p, fire_rad * 1.15, 0.0, TAU, 32, Color(1.0, 0.8, 0.3, alpha), 2.5)

			# Раскалённые разлетающиеся осколки для кассетных разрывов
			if bool(exp.get("is_sub", false)):
				var sparks: Array = exp.get("sparks", [])
				for spk in sparks:
					var s_dir: Vector2 = spk as Vector2
					var s_start = p + s_dir * (prog * 6.0)
					var s_end = p + s_dir * (prog * 22.0)
					draw_line(s_start, s_end, Color(1.0, 0.85, 0.3, alpha * 0.9), 1.8)

# ==============================================================================
# Жизненный цикл мода
# ==============================================================================
func init_mod(mm: Node) -> void:
	mm_ref = mm
	_register_textures(mm)
	if mm.has_method("register_hook"):
		mm.call("register_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("register_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[IskanderStrike] Mod initialized.")

func cleanup_mod(mm: Node) -> void:
	if mm != null and mm.has_method("unregister_texture"):
		mm.call("unregister_texture", "icon_iskander")
	if main_ref != null and is_instance_valid(main_ref) and main_ref.hud != null and mm != null and mm.has_method("cleanup_mod_hud"):
		mm.call("cleanup_mod_hud", main_ref.hud, Callable(self, "_on_hud_action"), [CELL_KEY])
	_cleanup_nodes()
	if mm and mm.has_method("unregister_hook"):
		mm.call("unregister_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("unregister_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[IskanderStrike] Mod cleaned up.")

func _register_textures(mm: Node) -> void:
	if mm == null or not mm.has_method("register_texture"):
		return
	var img = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Шасси ОТРК «Искандер-М» (8х8 МЗКТ-7930)
	# 1. 4 массивных колеса (y = 19..22)
	for wx in [2, 7, 13, 18]:
		for wy in range(19, 23):
			for dx in range(4):
				img.set_pixel(wx + dx, wy, Color(0.12, 0.13, 0.14, 1.0))
		img.set_pixel(wx + 1, 20, Color(0.62, 0.67, 0.64, 1.0))
		img.set_pixel(wx + 2, 20, Color(0.62, 0.67, 0.64, 1.0))
		img.set_pixel(wx + 1, 21, Color(0.45, 0.5, 0.48, 1.0))
		img.set_pixel(wx + 2, 21, Color(0.45, 0.5, 0.48, 1.0))

	# 2. Корпус тяжёлого тягача (y = 15..18, x = 2..22)
	for x in range(2, 23):
		for y in range(15, 19):
			img.set_pixel(x, y, Color(0.32, 0.46, 0.3, 1.0))
		img.set_pixel(x, 15, Color(0.42, 0.58, 0.38, 1.0)) # блик
		img.set_pixel(x, 18, Color(0.2, 0.28, 0.18, 1.0))  # тень

	# 3. Кабина экипажа (слева, x = 2..7, y = 11..14)
	for x in range(2, 8):
		for y in range(11, 15):
			img.set_pixel(x, y, Color(0.28, 0.42, 0.26, 1.0))
	for x in range(3, 7):
		img.set_pixel(x, 12, Color(0.3, 0.85, 0.95, 1.0))
	img.set_pixel(3, 12, Color(0.7, 0.96, 1.0, 1.0))

	# 4. Две квазибаллистические ракеты 9М723 в пусковом положении
	for rx in [10, 16]:
		for ry in range(4, 14):
			img.set_pixel(rx, ry, Color(0.94, 0.96, 0.98, 1.0))
			img.set_pixel(rx + 1, ry, Color(0.82, 0.86, 0.88, 1.0))
		# Боеголовка (ярко-красный / оранжевый конус)
		img.set_pixel(rx, 3, Color(0.95, 0.3, 0.18, 1.0))
		img.set_pixel(rx + 1, 3, Color(0.85, 0.2, 0.12, 1.0))
		img.set_pixel(rx, 2, Color(1.0, 0.5, 0.25, 1.0))
		img.set_pixel(rx + 1, 2, Color(0.95, 0.3, 0.18, 1.0))
		# Жёлтая маркировочная полоса
		img.set_pixel(rx, 7, Color(0.95, 0.8, 0.2, 1.0))
		img.set_pixel(rx + 1, 7, Color(0.82, 0.68, 0.15, 1.0))
		# Хвостовые стабилизаторы
		img.set_pixel(rx - 1, 12, Color(0.35, 0.4, 0.38, 1.0))
		img.set_pixel(rx - 1, 13, Color(0.35, 0.4, 0.38, 1.0))
		img.set_pixel(rx + 2, 12, Color(0.35, 0.4, 0.38, 1.0))
		img.set_pixel(rx + 2, 13, Color(0.35, 0.4, 0.38, 1.0))

	# Красная тактическая метка
	img.set_pixel(4, 14, Color(0.95, 0.25, 0.2, 1.0))

	mm.call("register_texture", "icon_iskander", ImageTexture.create_from_image(img))

func _cleanup_nodes() -> void:
	is_placing = false
	is_targeting = false
	selected_tel = null
	targeting_tel = null
	target_point = Vector2.INF
	targeting_mode = "he"
	active_missiles.clear()
	active_submunitions.clear()
	active_explosions.clear()
	if world_layer != null and is_instance_valid(world_layer):
		world_layer.queue_free()
		world_layer = null

func close_all() -> void:
	cancel_placement()
	cancel_targeting()
	selected_tel = null
	if main_ref != null:
		if "selected_fac" in main_ref:
			main_ref.selected_fac = null
		if main_ref.has_method("_deselect"):
			main_ref._deselect()
		if main_ref.hud != null:
			main_ref.hud.hide_ops()
			main_ref.hud.set_key_pressed(CELL_KEY, false)
	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_close")

# ==============================================================================
# Интеграция в HUD
# ==============================================================================
func _ensure_hud(main: Node, world: Node) -> void:
	if main == null or not is_instance_valid(main) or world == null or not is_instance_valid(world):
		return
	main_ref = main
	world_ref = world

	# Подключение сигнала действий HUD
	if main.hud != null:
		if not main.hud.action.is_connected(_on_hud_action):
			main.hud.action.connect(_on_hud_action)

	# Аккуратная кнопка во вкладке «АРМИЯ» (Tab 4)
	if main.hud != null and main.hud.pages.size() > 4:
		var army_grid = main.hud.pages[4] as GridContainer
		if army_grid != null:
			var need_add: bool = true
			if main.hud.keys.has(CELL_KEY):
				var existing = main.hud.keys[CELL_KEY]
				if existing != null and is_instance_valid(existing) and existing.is_inside_tree():
					need_add = false
				else:
					main.hud.keys.erase(CELL_KEY)
			if need_add:
				var cell = main.hud._cell(CELL_KEY, "icon_iskander", true)
				if main.hud.key_labels.has(CELL_KEY):
					var lbl = main.hud.key_labels[CELL_KEY] as Label
					if lbl != null:
						lbl.text = "ИСКАНДЕР"
						BuildPanel.fit(lbl, BuildPanel.CELL_W, BuildPanel.KEY_FONT)
				army_grid.add_child(cell)
				army_grid.move_child(cell, mini(army_grid.get_child_count() - 1, 3))

	# Слой графики и перехвата ввода
	if world_layer == null or not is_instance_valid(world_layer):
		var wl = IskanderWorldLayer.new()
		wl.setup(self, main, world)
		world.add_child(wl)
		world_layer = wl
	if world != null:
		world.set_meta("iskander_strike_mod", self)

func _on_world_started(main: Node, world: Node) -> void:
	_cleanup_nodes()
	_ensure_hud(main, world)

# ==============================================================================
# Обработка действий HUD
# ==============================================================================
func _on_hud_action(action_name: String) -> void:
	match action_name:
		CELL_KEY:
			if main_ref != null and main_ref.hud != null:
				main_ref.hud.show_tip(
					"ОТРК «Искандер-М» (9К720)",
					"Высокоточный оперативно-тактический ракетный комплекс. Пуск квазибаллистических ракет 9М723 на глобальную дальность. Стоимость: %d $ и %d металла, перезарядка: %d $ и %d металла." % [TEL_COST_MONEY, TEL_COST_METAL, RELOAD_COST_MONEY, RELOAD_COST_METAL],
					""
				)
			if is_placing:
				cancel_placement()
			else:
				start_placement()

		"iskander_target", "iskander_target_he":
			targeting_mode = "he"
			var f_t: Facility = selected_tel if selected_tel != null else (main_ref.selected_fac as Facility if main_ref != null and "selected_fac" in main_ref else null)
			if f_t != null and _is_iskander(f_t):
				start_targeting(f_t)

		"iskander_target_cluster":
			targeting_mode = "cluster"
			var f_t: Facility = selected_tel if selected_tel != null else (main_ref.selected_fac as Facility if main_ref != null and "selected_fac" in main_ref else null)
			if f_t != null and _is_iskander(f_t):
				start_targeting(f_t)

		"iskander_launch_confirm", "plan_launch":
			if is_targeting and targeting_tel != null and is_instance_valid(targeting_tel):
				var mouse_sp: Vector2 = main_ref.get_viewport().get_mouse_position() if main_ref != null else Vector2.ZERO
				var mouse_w: Vector2 = main_ref.cam.screen_to_world(mouse_sp) if (main_ref != null and main_ref.cam != null) else mouse_sp
				try_fire_at(mouse_w)

		"iskander_reload":
			var f_rel: Facility = selected_tel if selected_tel != null else (main_ref.selected_fac as Facility if main_ref != null and "selected_fac" in main_ref else null)
			if f_rel != null and _is_iskander(f_rel):
				start_reload(f_rel)

		"iskander_build_another":
			start_placement()

		"iskander_repair":
			var f_rep: Facility = selected_tel if selected_tel != null else (main_ref.selected_fac as Facility if main_ref != null and "selected_fac" in main_ref else null)
			if f_rep != null and _is_iskander(f_rep):
				repair_tel(f_rep)

		"iskander_demolish":
			var f_dem: Facility = selected_tel if selected_tel != null else (main_ref.selected_fac as Facility if main_ref != null and "selected_fac" in main_ref else null)
			if f_dem != null and _is_iskander(f_dem):
				demolish_tel(f_dem)

		"cancel_select", "iskander_close", "iskander_cancel_target":
			close_all()

# ==============================================================================
# Выбор и наведение
# ==============================================================================
func select_tel(f: Facility) -> void:
	if f == null or not is_instance_valid(f):
		return
	_is_iskander(f)
	selected_tel = f
	is_placing = false
	if main_ref != null:
		main_ref.selected_fac = f
		if main_ref.hud != null:
			main_ref.hud.set_key_pressed(CELL_KEY, false)
		if main_ref.cam != null:
			main_ref.cam.center_on(f.center_px())
	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_select")
	_update_native_card(f)

func start_targeting(f: Facility) -> void:
	is_targeting = true
	is_placing = false
	targeting_tel = f
	selected_tel = f
	target_point = Vector2.INF
	if main_ref != null and "selected_fac" in main_ref:
		main_ref.selected_fac = f
	if world_layer != null:
		world_layer.queue_redraw()
	if main_ref != null and main_ref.hud != null:
		var name_str = "«КАССЕТА»" if targeting_mode == "cluster" else "«ФУГАС»"
		main_ref.hud.show_toast("НАВЕДЕНИЕ ОТРК «ИСКАНДЕР-М» (%s): кликните ЛКМ по карте для пуска · ПКМ/Esc — отмена" % name_str)
	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_select")
	_update_targeting_card()

func cancel_targeting() -> void:
	is_targeting = false
	targeting_tel = null
	target_point = Vector2.INF
	if world_layer != null:
		world_layer.queue_redraw()
	if selected_tel != null and is_instance_valid(selected_tel):
		if main_ref != null and "selected_fac" in main_ref:
			main_ref.selected_fac = selected_tel
		_update_native_card(selected_tel)
	elif main_ref != null and main_ref.hud != null:
		main_ref.hud.hide_ops()

func set_target_point(pos: Vector2) -> void:
	try_fire_at(pos)

func try_fire_at(wpos: Vector2) -> void:
	if targeting_tel == null or not is_instance_valid(targeting_tel):
		cancel_targeting()
		return
	var f: Facility = targeting_tel
	var from_c: Vector2 = f.center_px()
	var dist: float = from_c.distance_to(wpos)
	if dist < 32.0:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Слишком близко к пусковой установке (мин. 32 пикс.)!")
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return
	if not bool(f.get_meta("has_missile", false)) or bool(f.get_meta("is_reloading", false)):
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Ракета не готова к пуску!")
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	var chosen_mode: String = targeting_mode
	is_targeting = false
	targeting_tel = null
	target_point = Vector2.INF

	launch_missile(f, wpos, chosen_mode)

	if main_ref != null and "overlay" in main_ref and main_ref.overlay != null:
		main_ref.overlay.ripple(wpos, "alert_red")

	if world_layer != null:
		world_layer.queue_redraw()

	if selected_tel != null and is_instance_valid(selected_tel):
		if main_ref != null and "selected_fac" in main_ref:
			main_ref.selected_fac = selected_tel
		_update_native_card(selected_tel)

func draw_targeting(ci: CanvasItem, mouse_w: Vector2) -> void:
	if not is_targeting or targeting_tel == null or not is_instance_valid(targeting_tel):
		return
	var c: Vector2 = targeting_tel.center_px()
	var dist: float = c.distance_to(mouse_w)
	var ok: bool = dist >= 32.0
	var is_cl: bool = targeting_mode == "cluster"
	var base_col: Color = Color(1.0, 0.6, 0.15) if is_cl else Color(1.0, 0.28, 0.2)
	var col: Color = base_col if ok else Color(1.0, 0.2, 0.2)
	var pulse: float = 0.75 + 0.25 * sin(anim_t * 7.0)

	# Линия от ОТРК к курсору
	ci.draw_dashed_line(c, mouse_w, Color(col.r, col.g, col.b, 0.55), 1.5, 8.0)
	ci.draw_arc(c, 32.0, 0.0, TAU, 32, Color(1.0, 0.2, 0.2, 0.35), 1.0)

	# Радиус зоны поражения (36 px для фугаса, 68 px для кассеты)
	var r_t: float = 68.0 if is_cl else 36.0
	ci.draw_circle(mouse_w, r_t, Color(col.r, col.g, col.b, 0.18 * pulse))
	ci.draw_arc(mouse_w, r_t, 0.0, TAU, 48, Color(col.r, col.g, col.b, pulse), 2.0)
	ci.draw_arc(mouse_w, r_t * 0.5, 0.0, TAU, 32, Color(col.r, col.g, col.b, pulse * 0.5), 1.0)

	# Перекрестие
	ci.draw_line(mouse_w - Vector2(r_t + 10.0, 0), mouse_w + Vector2(r_t + 10.0, 0), col, 1.5)
	ci.draw_line(mouse_w - Vector2(0, r_t + 10.0), mouse_w + Vector2(0, r_t + 10.0), col, 1.5)

	# Угловые скобки захвата цели
	var b_sz: float = 12.0
	ci.draw_line(mouse_w + Vector2(-r_t, -r_t), mouse_w + Vector2(-r_t + b_sz, -r_t), col, 2.0)
	ci.draw_line(mouse_w + Vector2(-r_t, -r_t), mouse_w + Vector2(-r_t, -r_t + b_sz), col, 2.0)
	ci.draw_line(mouse_w + Vector2(r_t, -r_t), mouse_w + Vector2(r_t - b_sz, -r_t), col, 2.0)
	ci.draw_line(mouse_w + Vector2(r_t, -r_t), mouse_w + Vector2(r_t, -r_t + b_sz), col, 2.0)
	ci.draw_line(mouse_w + Vector2(-r_t, r_t), mouse_w + Vector2(-r_t + b_sz, r_t), col, 2.0)
	ci.draw_line(mouse_w + Vector2(-r_t, r_t), mouse_w + Vector2(-r_t, r_t - b_sz), col, 2.0)
	ci.draw_line(mouse_w + Vector2(r_t, r_t), mouse_w + Vector2(r_t - b_sz, r_t), col, 2.0)
	ci.draw_line(mouse_w + Vector2(r_t, r_t), mouse_w + Vector2(r_t, r_t - b_sz), col, 2.0)

	# Точка центра
	ci.draw_rect(Rect2(mouse_w - Vector2(2, 2), Vector2(4, 4)), Color.WHITE)

	# Иконка Искандера рядом с прицелом
	if mm_ref != null and mm_ref.has_method("get_texture"):
		var isk_tex = mm_ref.call("get_texture", "icon_iskander")
		if isk_tex != null:
			var icon_pos: Vector2 = mouse_w + Vector2(r_t + 6.0, -12.0)
			ci.draw_texture_rect(isk_tex, Rect2(icon_pos, Vector2(24, 24)), false)

	# Превью суббоеприпасов для кассеты
	if is_cl:
		for ang_i in range(8):
			var a_rad = float(ang_i) * (TAU / 8.0)
			var dot_p = mouse_w + Vector2(cos(a_rad), sin(a_rad)) * (r_t * 0.55)
			ci.draw_circle(dot_p, 2.5, Color(1.0, 0.85, 0.3, 0.85))

# ==============================================================================
# Размещение комплекса
# ==============================================================================
func toggle_placement() -> void:
	if is_placing:
		cancel_placement()
	else:
		start_placement()

func start_placement() -> void:
	if world_ref == null or world_ref.player == null:
		return
	var p = world_ref.player
	if p.money < TEL_COST_MONEY or p.metal < TEL_COST_METAL:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает: %d $ и %d металла!" % [TEL_COST_MONEY, TEL_COST_METAL])
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return
	is_placing = true
	is_targeting = false
	selected_tel = null
	if main_ref != null:
		if "selected_fac" in main_ref:
			main_ref.selected_fac = null
		if main_ref.hud != null:
			main_ref.hud.set_key_pressed(CELL_KEY, true)
			main_ref.hud.show_toast("ОТРК «ИСКАНДЕР-М»: укажите место на своей территории (ЛКМ — развернуть, ПКМ/Esc — отмена)")
	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_select")

func cancel_placement() -> void:
	is_placing = false
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.set_key_pressed(CELL_KEY, false)

func place_why(cell: Vector2i) -> String:
	if world_ref == null or not is_instance_valid(world_ref):
		return "Мир недоступен"
	var d: Variant = world_ref.data
	if d == null:
		return "Данные карты недоступны"
	if cell.x < 2 or cell.y < 2 or cell.x + TEL_SIZE.x >= d.w - 2 or cell.y + TEL_SIZE.y >= d.h - 2:
		return "Не помещается у края карты"
	var player: Variant = world_ref.player
	if player == null:
		return "Игрок не найден"
	for dy in range(TEL_SIZE.y):
		for dx in range(TEL_SIZE.x):
			var cx: int = cell.x + dx
			var cy: int = cell.y + dy
			if not d.inside(cx, cy):
				return "За пределами карты"
			var owner_id: int = d.get_owner_id(cx, cy) if d.has_method("get_owner_id") else d.get_owner(cx, cy)
			if owner_id != player.id:
				return "Стройте только на своей территории"
			var b: int = d.get_biome(cx, cy)
			if Biome.is_water(b):
				return "Нельзя строить на воде"
			var fl: int = d.flags[cy * d.w + cx]
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

func place_tel_at(cell: Vector2i) -> void:
	var why: String = place_why(cell)
	if why != "":
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Нельзя развернуть здесь: " + why)
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	var p = world_ref.player
	if p.money < TEL_COST_MONEY or p.metal < TEL_COST_METAL:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает: %d $ и %d металла!" % [TEL_COST_MONEY, TEL_COST_METAL])
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return

	p.money -= TEL_COST_MONEY
	p.metal -= TEL_COST_METAL
	cancel_placement()

	var f: Facility = Facility.new()
	f.id = world_ref.mil.facilities.size()
	f.kind = Facility.Kind.CIV_FACTORY
	f.country_id = p.id
	f.cell = cell
	f.size = TEL_SIZE
	f.army_build = CELL_KEY
	f.lower_sprite = CELL_KEY
	f.hp = TEL_MAX_HP
	f.moving = false
	f.mdest = Vector2.ZERO
	f.mpos = f.center_px()
	f.missiles = 1
	f.set_meta("is_iskander_tel", true)
	f.set_meta("mod_facility", true)
	f.set_meta("hp", TEL_MAX_HP)
	f.set_meta("max_hp", TEL_MAX_HP)
	f.set_meta("has_missile", true)
	f.set_meta("is_reloading", false)
	f.set_meta("reload_timer", 0.0)

	var spr_name: String = "tel2" if world_ref.spr_index.has("tel2") else "civ_factory"
	f.main_obj = world_ref.add_object(spr_name, cell, GameWorld.KIND_BUILDING)
	f.obj_ids.append(f.main_obj)
	world_ref.mil.facilities.append(f)

	var d = world_ref.data
	for dy in range(TEL_SIZE.y):
		for dx in range(TEL_SIZE.x):
			var cx = cell.x + dx
			var cy = cell.y + dy
			world_ref.remove_tree_at(Vector2i(cx, cy))
			d.add_flag(cx, cy, WorldData.F_OCCUPIED)

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("build_done")
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("ОТРК «Искандер-М» развёрнут на позиции и готов к пуску!")

	select_tel(f)

# ==============================================================================
# Карточка комплекса в интерфейсе (аутентичный стиль с иконками)
# ==============================================================================
func _is_iskander(f: Facility) -> bool:
	if f == null or not is_instance_valid(f):
		return false
	if f.army_build == CELL_KEY or bool(f.get_meta("is_iskander_tel", false)):
		f.kind = Facility.Kind.CIV_FACTORY
		f.army_build = CELL_KEY
		f.lower_sprite = CELL_KEY
		f.set_meta("is_iskander_tel", true)
		f.set_meta("mod_facility", true)
		f.moving = false
		f.mdest = Vector2.ZERO
		f.mpos = f.center_px()
		if not f.has_meta("hp"):
			f.set_meta("hp", f.hp if f.hp > 0.0 else TEL_MAX_HP)
			f.set_meta("max_hp", TEL_MAX_HP)
			f.set_meta("has_missile", true)
			f.set_meta("is_reloading", false)
			f.set_meta("reload_timer", 0.0)
		if f.hp <= 0.0:
			f.hp = float(f.get_meta("hp", TEL_MAX_HP))
		return true
	return false

func _update_native_card(f: Facility) -> void:
	if main_ref == null or main_ref.hud == null:
		return
	var h: Variant = main_ref.hud
	var p: Variant = world_ref.player
	if p == null:
		return

	var has_missile = bool(f.get_meta("has_missile", false))
	var is_reloading = bool(f.get_meta("is_reloading", false))
	var rem_t = float(f.get_meta("reload_timer", 0.0))
	var hp = float(f.get_meta("hp", TEL_MAX_HP))
	var max_hp = float(f.get_meta("max_hp", TEL_MAX_HP))

	var title = "ОТРК «Искандер-М» (9К720)"
	var sub = "Ракетные войска · Пусковая установка 9П78-1 · Комплекс #%d" % f.id
	h._card("iskander_tel_%d" % f.id, "icon_iskander", title, sub, false, false, true)

	var info: String = ""
	if has_missile:
		info = Loc.t("СТАТУС: БОЕГОТОВ · РАКЕТА НА НАПРАВЛЯЮЩЕЙ\nДАЛЬНОСТЬ: ГЛОБАЛЬНАЯ · УРОН: 650–700 ЕД. · ПРОЧНОСТЬ: %d/%d") % [int(hp), int(max_hp)]
	elif is_reloading:
		info = Loc.t("СТАТУС: АВТОПЕРЕЗАРЯДКА... %s\nПРОЧНОСТЬ: %d/%d") % [h._mmss(rem_t), int(hp), int(max_hp)]
	else:
		info = Loc.t("СТАТУС: ОЖИДАНИЕ РЕСУРСОВ НА ПЕРЕЗАРЯДКУ (%d $ · %d МЕТАЛЛА)\nПРОЧНОСТЬ: %d/%d") % [RELOAD_COST_MONEY, RELOAD_COST_METAL, int(hp), int(max_hp)]

	h._set_info(info, not has_missile and not is_reloading)
	h.ops_detail.text = "Высокоточный оперативно-тактический ракетный комплекс сухопутных сил. Запуск ракет по любой точке карты на глобальную дальность. Доступны фугасный удар с мощной ударной волной и кассетный осколочный удар по широкой площади."
	h.ops_detail.visible = true

	var acts: Array = []
	if has_missile:
		acts.append(h._act("ФУГАС\nУДАР", "icon_target", "iskander_target_he", true))
		acts.append(h._act("КАССЕТА\nОСКОЛКИ", "icon_target", "iskander_target_cluster", true))
	elif is_reloading:
		acts.append(h._act("ЗАРЯЖАНИЕ\n%s" % h._mmss(rem_t), "icon_restore", "none", false))
	else:
		var can_reload = p.money >= RELOAD_COST_MONEY and p.metal >= RELOAD_COST_METAL
		acts.append(h._act("ЗАРЯДИТЬ\n%d $ · %d М" % [RELOAD_COST_MONEY, RELOAD_COST_METAL], "icon_restore", "iskander_reload", can_reload))

	acts.append(h._act("ЕЩЁ ОТРК\n%d $" % TEL_COST_MONEY, "icon_iskander", "iskander_build_another", p.money >= TEL_COST_MONEY and p.metal >= TEL_COST_METAL))

	if hp < max_hp:
		acts.append(h._act("РЕМОНТ\n%d $" % TEL_REPAIR_COST, "icon_restore", "iskander_repair", p.money >= TEL_REPAIR_COST))

	var dact = h._act("СНОС\n+%d $" % TEL_REFUND, "icon_close", "iskander_demolish", true)
	dact["red"] = true
	acts.append(dact)

	acts.append(h._act("ЗАКРЫТЬ", "icon_close", "iskander_close", true))
	h._fill_acts("iskander_acts_%d" % f.id, acts)

func _update_targeting_card() -> void:
	if main_ref == null or main_ref.hud == null or targeting_tel == null:
		return
	var h: Variant = main_ref.hud
	if not h.action.is_connected(_on_hud_action):
		h.action.connect(_on_hud_action)
	var is_cl: bool = targeting_mode == "cluster"
	var title = "НАВЕДЕНИЕ ОТРК: «КАССЕТА»" if is_cl else "НАВЕДЕНИЕ ОТРК: «ФУГАС»"
	var sub = "Кликните ЛКМ по карте для пуска ракеты · ПКМ или Esc — отмена"
	h._card("iskander_targeting", "icon_iskander", title, sub, false, false, true)
	if h.ops_icon != null and (h.ops_icon.texture == null or not is_instance_valid(h.ops_icon.texture)):
		UiKit.set_icon(h.ops_icon, "icon_iskander", 32.0)

	if is_cl:
		h._set_info("ЗОНА ПОРАЖЕНИЯ: РАДИУС 68 ПИКС. · 28 ОСКОЛОЧНЫХ СУББОЕПРИПАСОВ ПО ПЛОЩАДИ", false)
	else:
		h._set_info("ЗОНА ПОРАЖЕНИЯ: РАДИУС 36 ПИКС. · ТОЧЕЧНЫЙ ТАРАН 700 HP + УДАРНАЯ ВОЛНА", false)

	h.ops_detail.visible = false

	var acts: Array = []
	acts.append(h._act("ОТМЕНА", "icon_close", "iskander_cancel_target", true))
	h._fill_acts("iskander_target_acts", acts)

# ==============================================================================
# Боевые действия и обслуживание
# ==============================================================================
func start_reload(f: Facility, is_auto: bool = false) -> void:
	var p = world_ref.player
	if p == null:
		return
	if bool(f.get_meta("has_missile", false)):
		return
	if bool(f.get_meta("is_reloading", false)):
		return
	if p.money < RELOAD_COST_MONEY or p.metal < RELOAD_COST_METAL:
		if not is_auto:
			if main_ref != null and main_ref.hud != null:
				main_ref.hud.show_toast("Не хватает ресурсов: требуется %d $ и %d металла!" % [RELOAD_COST_MONEY, RELOAD_COST_METAL])
			if ClassDB.class_exists("UiKit"):
				UiKit.snd("ui_error")
		return

	p.money -= RELOAD_COST_MONEY
	p.metal -= RELOAD_COST_METAL
	f.set_meta("is_reloading", true)
	f.set_meta("reload_timer", RELOAD_TIME)
	if not is_auto and ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_select")
	if not is_auto and main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("ОТРК «Искандер-М»: началась доставка новой ракеты...")
	_update_native_card(f)

func repair_tel(f: Facility) -> void:
	var p = world_ref.player
	if p == null:
		return
	if p.money < TEL_REPAIR_COST:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает: %d $ на ремонт!" % TEL_REPAIR_COST)
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")
		return
	p.money -= TEL_REPAIR_COST
	f.hp = TEL_MAX_HP
	f.set_meta("hp", TEL_MAX_HP)
	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_build")
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Комплекс ОТРК «Искандер-М» полностью отремонтирован!")
	_update_native_card(f)

func demolish_tel(f: Facility) -> void:
	var p = world_ref.player
	if p != null:
		p.money += TEL_REFUND
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
	close_all()
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Комплекс ОТРК «Искандер-М» демонтирован (+%d $)." % TEL_REFUND)

func launch_missile(f: Facility, target_world_pos: Vector2, custom_mode: String = "") -> void:
	f.set_meta("has_missile", false)
	f.missiles = 0
	if world_ref.spr_index.has("tel0"):
		world_ref.set_obj_frame(f.main_obj, "tel0", 0)

	var start_pos: Vector2 = f.center_px()
	var flight_duration: float = clampf(start_pos.distance_to(target_world_pos) / 380.0, 4.5, 9.0)
	var m_type = custom_mode if custom_mode != "" else targeting_mode

	var cid: int = f.country_id if f != null and "country_id" in f else (world_ref.player.id if world_ref != null and world_ref.player != null else 1)
	var m: Dictionary = {
		"start": start_pos,
		"target": target_world_pos,
		"t": 0.0,
		"duration": flight_duration,
		"type": m_type,
		"cid": cid,
		"trail": [],
		"cur_pos": start_pos,
		"cur_ground": start_pos,
		"dir": Vector2.UP,
		"split_done": false
	}
	active_missiles.append(m)

	if ClassDB.class_exists("Sfx"):
		Sfx.play("rocket_launch", start_pos)
	if main_ref != null and main_ref.hud != null:
		var name_str = "«КАССЕТА»" if m_type == "cluster" else "«ФУГАС»"
		main_ref.hud.show_toast("🚀 ОТРК «ИСКАНДЕР-М»: Ракета %s стартовала! Подлёт через %.1f сек." % [name_str, flight_duration])

	# Сразу запускаем авто-перезарядку
	start_reload(f, true)

func launch_missile_at(f: Facility, target_world_pos: Vector2, ammo_type: String = "") -> bool:
	if f == null or not is_instance_valid(f):
		return false
	if not bool(f.get_meta("has_missile", false)) or bool(f.get_meta("is_reloading", false)):
		return false
	launch_missile(f, target_world_pos, ammo_type)
	return true

func _split_cluster_missile(split_pos: Vector2, target_center: Vector2, cid: int = 1) -> void:
	if ClassDB.class_exists("Sfx"):
		Sfx.play("bomb_impact", split_pos)
	active_explosions.append({
		"pos": split_pos,
		"t": 0.0,
		"duration": 0.8,
		"radius": 34.0,
		"fire_radius": 26.0,
		"is_shockwave": false
	})
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("💥 РАЗДЕЛЕНИЕ КАССЕТНОЙ БЧ: 28 суббоеприпасов накрывают сектор!")

	# Выброс 28 суббоеприпасов-осколков по широкой площади (до 160 px)
	for s_i in range(28):
		var ang: float = randf() * TAU
		var dist_spread: float = randf_range(16.0, 160.0)
		var sub_target: Vector2 = target_center + Vector2(cos(ang), sin(ang) * 0.75) * dist_spread
		var sub_dur: float = randf_range(0.6, 1.4)
		active_submunitions.append({
			"start": split_pos + Vector2(cos(ang), sin(ang)) * randf_range(4.0, 18.0),
			"target": sub_target,
			"t": 0.0,
			"duration": sub_dur,
			"cid": cid,
			"trail": []
		})

func _trigger_war_for_strike(pos: Vector2, radius_cells: int, attacker_id: int) -> void:
	if world_ref == null:
		return
	if attacker_id <= 0:
		if world_ref.player != null:
			attacker_id = world_ref.player.id
		else:
			attacker_id = 1

	var cell: Vector2i = Vector2i(floori(pos.x / float(GameWorld.CELL)), floori(pos.y / float(GameWorld.CELL)))
	var victims: Array[int] = []

	# 1. Проверяем владельца клеток в зоне поражения
	var d = world_ref.data
	if d != null:
		for dy in range(-radius_cells, radius_cells + 1):
			for dx in range(-radius_cells, radius_cells + 1):
				var cx: int = cell.x + dx
				var cy: int = cell.y + dy
				if d.inside(cx, cy):
					var ow: int = d.get_owner_id(cx, cy)
					if ow > 0 and ow != attacker_id and not victims.has(ow):
						victims.append(ow)

	# 2. Проверяем города в зоне поражения
	if world_ref.has_method("city_at_cell"):
		for dy in range(-radius_cells, radius_cells + 1):
			for dx in range(-radius_cells, radius_cells + 1):
				var hc = world_ref.city_at_cell(cell + Vector2i(dx, dy))
				if hc != null:
					hc.strike_t = world_ref.game_time
					if attacker_id > 0 and hc.country_id != attacker_id:
						hc.war_by = attacker_id
						if hc.country_id > 0 and not victims.has(hc.country_id):
							victims.append(hc.country_id)

	# 3. Проверяем военные объекты и заводы в радиусе
	if world_ref.mil != null and "facilities" in world_ref.mil:
		var max_dist: float = float(GameWorld.CELL) * float(radius_cells + 2)
		for f in world_ref.mil.facilities:
			if f != null and is_instance_valid(f):
				if f.center_px().distance_to(pos) <= max_dist:
					var f_cid: int = f.country_id if "country_id" in f else 0
					if f_cid > 0 and f_cid != attacker_id and not victims.has(f_cid):
						victims.append(f_cid)

	# 4. Проверяем юниты и войска в радиусе
	if world_ref.army != null and "units" in world_ref.army:
		var max_u_dist: float = float(GameWorld.CELL) * float(radius_cells + 3)
		for u in world_ref.army.units:
			if u != null and is_instance_valid(u) and ("pos" in u and "country_id" in u):
				if u.pos.distance_to(pos) <= max_u_dist:
					var u_cid: int = u.country_id
					if u_cid > 0 and u_cid != attacker_id and not victims.has(u_cid):
						victims.append(u_cid)

	# 5. Вызываем нативный метод движка для разрушения объектов и фиксации удара
	if world_ref.has_method("_apply_strike"):
		world_ref._apply_strike(cell, radius_cells, "crater_m", float(GameWorld.CELL * radius_cells), attacker_id)

	# 6. Дипломатия: регистрируем нападение и принудительно объявляем войну всем пострадавшим
	if world_ref.diplo != null:
		for vic_id in victims:
			if vic_id <= 0 or vic_id == attacker_id:
				continue
			world_ref.diplo.on_attack(attacker_id, vic_id)
			if not world_ref.diplo.at_war(attacker_id, vic_id):
				world_ref.diplo.declare_war(attacker_id, vic_id, "удар ОТРК «Искандер-М»")
				var vic_c = world_ref.country_by_id(vic_id)
				var vic_name: String = vic_c.name if vic_c != null else ("Страна #%d" % vic_id)
				if main_ref != null and main_ref.hud != null:
					main_ref.hud.show_toast("⚠️ ОБЪЯВЛЕНА ВОЙНА! Страна %s подверглась удару «Искандер-М»!" % vic_name)

func _explode_submunition(pos: Vector2, cid: int = 1) -> void:
	if world_ref == null or world_ref.data == null:
		return
	var cell: Vector2i = Vector2i((pos / float(GameWorld.CELL)).floor())
	var d = world_ref.data
	if d.inside(cell.x, cell.y) and d.get_biome(cell.x, cell.y) > Biome.RIVER:
		d.set_biome(cell.x, cell.y, Biome.BURNT)

	# Сочные визуальные эффекты взрыва
	if world_ref.fx != null:
		world_ref.fx.spawn("explosion_s", pos.round(), 5)
		if randf() < 0.6:
			world_ref.fx.spawn("fire_small", pos.round(), 3, world_ref.game_time + randf_range(4.0, 8.0), true)
		if randf() < 0.35:
			world_ref.fx.spawn("smoke_black_loop", (pos + Vector2(0, -6)).round(), 5, world_ref.game_time + randf_range(5.0, 9.0), true)

	if ClassDB.class_exists("Sfx"):
		Sfx.play("expl_s", pos, randf_range(-1.2, 1.2))
	_shake(1.2)

	# Урон постройкам и войскам в радиусе (умеренный/малый урон: 40 HP зданиям, 35 HP пехоте)
	if world_ref.mil != null:
		for f in world_ref.mil.facilities:
			if f != null and is_instance_valid(f):
				if f.center_px().distance_to(pos) <= float(GameWorld.CELL) * 2.2:
					var cur_hp = float(f.get_meta("hp", f.hp if f.hp > 0.0 else 400.0)) - 40.0
					f.set_meta("hp", cur_hp)
					f.hp = maxf(0.0, cur_hp)

	# Поражение пехоты и техники
	if world_ref.army != null and "units" in world_ref.army:
		for u in world_ref.army.units:
			if u != null and is_instance_valid(u) and ("pos" in u and "hp" in u):
				if u.pos.distance_to(pos) <= 24.0:
					u.hp -= 35.0

	var sparks: Array[Vector2] = []
	for spk in range(6):
		sparks.append(Vector2.RIGHT.rotated(randf() * TAU))

	active_explosions.append({
		"pos": pos,
		"t": 0.0,
		"duration": 0.65,
		"radius": 22.0,
		"fire_radius": 16.0,
		"is_shockwave": false,
		"is_sub": true,
		"sparks": sparks
	})

	# Фиксация удара и объявление войны
	_trigger_war_for_strike(pos, 1, cid)

func _explode_he_missile(pos: Vector2, cid: int = 1) -> void:
	if world_ref == null or world_ref.data == null:
		return

	var cell: Vector2i = Vector2i((pos / float(GameWorld.CELL)).floor())
	var d = world_ref.data

	# Кратер и расширенная зона выжженной земли (радиус 7-8 клеток)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var dist_sq = dx * dx + dy * dy
			var cx = cell.x + dx
			var cy = cell.y + dy
			if d.inside(cx, cy):
				if dist_sq <= 3:
					d.set_biome(cx, cy, Biome.CRATER)
				elif dist_sq <= 14 and d.get_biome(cx, cy) > Biome.RIVER:
					d.set_biome(cx, cy, Biome.BURNT)

	# Урон постройкам в расширенном радиусе поражения (700 HP)
	if world_ref.mil != null:
		for f in world_ref.mil.facilities:
			if f != null and is_instance_valid(f):
				var f_pos: Vector2 = f.center_px()
				if f_pos.distance_to(pos) <= float(GameWorld.CELL) * 7.5:
					var cur_hp = float(f.get_meta("hp", f.hp if f.hp > 0.0 else 400.0)) - 700.0
					f.set_meta("hp", cur_hp)
					f.hp = maxf(0.0, cur_hp)

	# Поражение юнитов в зоне удара
	if world_ref.army != null and "units" in world_ref.army:
		for u in world_ref.army.units:
			if u != null and is_instance_valid(u) and ("pos" in u and "hp" in u):
				if u.pos.distance_to(pos) <= 120.0:
					u.hp -= 350.0

	# Тряска камеры и взрыв
	if main_ref != null and main_ref.cam != null and main_ref.cam.has_method("shake"):
		main_ref.cam.call("shake", 18.0)
	if ClassDB.class_exists("Sfx"):
		Sfx.play("bomb_impact", pos)

	# Добавляем мощный взрыв с расширяющейся ударной волной
	active_explosions.append({
		"pos": pos,
		"t": 0.0,
		"duration": 2.5,
		"radius": 175.0, # Радиус расширения ударной волны
		"fire_radius": 62.0,
		"is_shockwave": true,
		"cell": cell,
		"cleared_r": 0
	})

	# Фиксация удара и объявление войны
	_trigger_war_for_strike(pos, 4, cid)

	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("💥 «ФУГАС»: Точечный таран 700 HP и мощная ударная волна смели сектор!")

# ==============================================================================
# Игровой тик
# ==============================================================================
func _on_match_tick(main: Node, world: Node, delta: float) -> void:
	if main != null:
		main_ref = main
	if world != null:
		world_ref = world
	if main != null and (main.hud == null or not main.hud.keys.has(CELL_KEY) or world_layer == null):
		_ensure_hud(main, world_ref if world_ref != null else world)

	var ts: float = 1.0
	if world_ref != null and "time_scale" in world_ref:
		ts = maxf(0.0, float(world_ref.time_scale))
	var sim_delta: float = delta * ts
	anim_t += sim_delta

	if is_targeting and targeting_tel != null and is_instance_valid(targeting_tel):
		_update_targeting_card()
	elif main_ref != null and "selected_fac" in main_ref and main_ref.selected_fac != null and is_instance_valid(main_ref.selected_fac):
		var f: Facility = main_ref.selected_fac as Facility
		if f != null and _is_iskander(f):
			selected_tel = f
			_update_native_card(f)
		else:
			if selected_tel != null and selected_tel == f:
				selected_tel = null
	else:
		selected_tel = null

	# Перезарядка комплексов (автоматический запуск и таймер)
	if world_ref != null and world_ref.mil != null:
		for fac in world_ref.mil.facilities:
			if fac != null and is_instance_valid(fac) and _is_iskander(fac):
				if not bool(fac.get_meta("has_missile", false)) and not bool(fac.get_meta("is_reloading", false)):
					start_reload(fac, true)
				elif bool(fac.get_meta("is_reloading", false)):
					var rem_t = float(fac.get_meta("reload_timer", 0.0)) - sim_delta
					if rem_t <= 0.0:
						fac.set_meta("is_reloading", false)
						fac.set_meta("has_missile", true)
						fac.missiles = 1
						if world_ref.spr_index.has("tel2"):
							world_ref.set_obj_frame(fac.main_obj, "tel2", 0)
						if ClassDB.class_exists("UiKit"):
							UiKit.snd("build_done")
						if main_ref != null and main_ref.hud != null:
							main_ref.hud.show_toast("ОТРК «Искандер-М»: Ракета готова к пуску!")
					else:
						fac.set_meta("reload_timer", rem_t)

	# Обновление полёта ракет
	var i = active_missiles.size() - 1
	while i >= 0:
		var m: Dictionary = active_missiles[i]
		m["t"] += sim_delta
		var dur: float = float(m["duration"])
		var progress: float = clampf(float(m["t"]) / dur, 0.0, 1.0)
		var cur_ground: Vector2 = (m["start"] as Vector2).lerp(m["target"] as Vector2, progress)
		var arc_h: float = sin(progress * PI) * 180.0
		var cur_pos: Vector2 = cur_ground - Vector2(0, arc_h)

		var next_prog = clampf(progress + 0.02, 0.0, 1.0)
		var next_ground: Vector2 = (m["start"] as Vector2).lerp(m["target"] as Vector2, next_prog)
		var next_pos: Vector2 = next_ground - Vector2(0, sin(next_prog * PI) * 180.0)
		var dir: Vector2 = (next_pos - cur_pos).normalized()
		if dir.length_squared() < 0.001:
			dir = Vector2.DOWN

		m["cur_pos"] = cur_pos
		m["cur_ground"] = cur_ground
		m["dir"] = dir

		(m["trail"] as Array).append({"pos": cur_pos, "t": 0.0})
		if (m["trail"] as Array).size() > 32:
			(m["trail"] as Array).pop_front()

		# Разделение для 9М723К «КАССЕТА» на высоте
		if m["type"] == "cluster" and not bool(m.get("split_done", false)) and progress >= 0.82:
			m["split_done"] = true
			_split_cluster_missile(cur_pos, m["target"] as Vector2, int(m.get("cid", 1)))

		if progress >= 1.0:
			if m["type"] == "he":
				_explode_he_missile(m["target"] as Vector2, int(m.get("cid", 1)))
			active_missiles.remove_at(i)
		i -= 1

	# Обновление кассетных суббоеприпасов
	var si = active_submunitions.size() - 1
	while si >= 0:
		var sub: Dictionary = active_submunitions[si]
		sub["t"] += sim_delta
		var s_dur: float = float(sub["duration"])
		var s_prog: float = clampf(float(sub["t"]) / s_dur, 0.0, 1.0)
		var s_pos: Vector2 = (sub["start"] as Vector2).lerp(sub["target"] as Vector2, s_prog)
		s_pos.y -= sin(s_prog * PI) * 35.0
		(sub["trail"] as Array).append(s_pos)
		if (sub["trail"] as Array).size() > 10:
			(sub["trail"] as Array).pop_front()

		if s_prog >= 1.0:
			_explode_submunition(sub["target"] as Vector2, int(sub.get("cid", 1)))
			active_submunitions.remove_at(si)
		si -= 1

	# Обновление взрывов и расширение ударной волны
	var ei = active_explosions.size() - 1
	while ei >= 0:
		var exp: Dictionary = active_explosions[ei]
		exp["t"] += sim_delta

		if bool(exp.get("is_shockwave", false)):
			var wave_r = int((float(exp["t"]) / float(exp["duration"])) * float(exp["radius"]) / float(GameWorld.CELL))
			var last_r = int(exp.get("cleared_r", 0))
			if wave_r > last_r and world_ref != null:
				exp["cleared_r"] = wave_r
				var c: Vector2i = exp.get("cell", Vector2i.ZERO)
				for dy in range(-wave_r, wave_r + 1):
					for dx in range(-wave_r, wave_r + 1):
						if absi(dx) == wave_r or absi(dy) == wave_r:
							world_ref.remove_tree_at(Vector2i(c.x + dx, c.y + dy))

		if float(exp["t"]) >= float(exp["duration"]):
			active_explosions.remove_at(ei)
		ei -= 1

	if world_layer != null and is_instance_valid(world_layer):
		world_layer.queue_redraw()

func _shake(amt: float = 1.0) -> void:
	if main_ref != null and main_ref.cam != null and main_ref.cam.has_method("shake"):
		main_ref.cam.call("shake", amt)
