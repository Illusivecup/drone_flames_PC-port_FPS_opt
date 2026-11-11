extends RefCounted

## Мод «Кассетный боеприпас для ПТРК» для DroneFlames Reborn
## Полная интеграция в оригинальный интерфейс и движок игры.
## Добавляет нативную кнопку доктрины во вкладку «АРМИЯ» нижней панели.
## При включении: ракеты ПТРК на подлёте к цели (46 пикселей)
## разделяются на 6 кумулятивно-осколочных кассетных элементов,
## накрывающих площадь, колонны бронетехники и пехоту в окопах.

var mm_ref: Node = null
var main_ref: Node = null
var world_ref: Node = null

var world_layer: Node2D = null

# Доктрина: true = кассетные суббоеприпасы по площади, false = тандемный моноблок
var cluster_mode: bool = true

# Активные суббоеприпасы в полёте
var active_submunitions: Array = []

func init_mod(mm: Node) -> void:
	mm_ref = mm
	if mm.has_method("register_hook"):
		mm.call("register_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("register_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[ATGMCluster] Native mod initialized.")

func cleanup_mod(mm: Node) -> void:
	if main_ref != null and is_instance_valid(main_ref) and main_ref.hud != null and mm != null and mm.has_method("cleanup_mod_hud"):
		mm.call("cleanup_mod_hud", main_ref.hud, Callable(self, "_on_hud_action"), ["atgm_cluster"])
	_cleanup_nodes()
	if mm and mm.has_method("unregister_hook"):
		mm.call("unregister_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("unregister_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[ATGMCluster] Mod cleaned up.")

func _cleanup_nodes() -> void:
	active_submunitions.clear()
	if world_layer != null and is_instance_valid(world_layer):
		world_layer.queue_free()
		world_layer = null

func _ensure_hud(main: Node, world: Node) -> void:
	if main == null or not is_instance_valid(main) or world == null or not is_instance_valid(world):
		return
	main_ref = main
	world_ref = world

	# 1. Встраивание нативной кнопки переключения во вкладку «АРМИЯ» (Tab 4) нижней панели
	if main.hud != null and main.hud.pages.size() > 4:
		var army_grid = main.hud.pages[4] as GridContainer
		if army_grid != null and not main.hud.keys.has("atgm_cluster"):
			var cell = main.hud._cell("atgm_cluster", "icon_target", true)
			if main.hud.key_labels.has("atgm_cluster"):
				var lbl = main.hud.key_labels["atgm_cluster"] as Label
				if lbl != null:
					lbl.text = "ПТРК-К"
			army_grid.add_child(cell)
			main.hud.set_key_pressed("atgm_cluster", cluster_mode)

		if not main.hud.action.is_connected(_on_hud_action):
			main.hud.action.connect(_on_hud_action)

	# 2. Слой мира для эффектов суббоеприпасов
	if world_layer == null or not is_instance_valid(world_layer):
		world_layer = ATGMClusterWorldLayer.new()
		world_layer.setup(self, main, world)
		world.add_child(world_layer)

func _on_world_started(main: Node, world: Node) -> void:
	_cleanup_nodes()
	_ensure_hud(main, world)
	print("[ATGMCluster] Injected atgm_cluster cell into Army tab and world layer attached.")

func _on_hud_action(nm: String) -> void:
	if nm == "atgm_cluster":
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_tip(
				"ПТРК: кассетный боеприпас",
				"Доктрина ПТРК: 6 кумулятивно-осколочных суббоеприпасов по площади",
				""
			)
		toggle_mode()

func _on_match_tick(main: Node, world: Node, delta: float) -> void:
	main_ref = main
	world_ref = world

	if main != null and (main.hud == null or not main.hud.keys.has("atgm_cluster") or world_layer == null):
		_ensure_hud(main, world)

	var time_scale: float = 1.0
	if world != null and "time_scale" in world:
		time_scale = maxf(0.0, float(world.time_scale))
	var sim_delta: float = delta * time_scale

	if sim_delta > 0.0:
		_tick_rockets(sim_delta)
		_tick_submunitions(sim_delta)

	if world_layer != null and is_instance_valid(world_layer):
		world_layer.queue_redraw()

func toggle_mode() -> void:
	cluster_mode = not cluster_mode

	if main_ref != null and main_ref.hud != null:
		main_ref.hud.set_key_pressed("atgm_cluster", cluster_mode)
		var msg = "Доктрина ПТРК: КАССЕТНЫЙ боеприпас (6 суббоеприпасов по площади)" if cluster_mode else "Доктрина ПТРК: ТАНДЕМНЫЙ моноблок (точечный бронепробивающий удар)"
		main_ref.hud.show_toast(msg)

	if ClassDB.class_exists("UiKit"):
		UiKit.snd("ui_click")

func _tick_rockets(dt: float) -> void:
	if not cluster_mode:
		return
	if world_ref == null or not is_instance_valid(world_ref):
		return
	if not ("army" in world_ref and world_ref.army != null):
		return

	var army = world_ref.army
	var p = world_ref.player
	var player_cid = p.id if p != null and is_instance_valid(p) else -1

	# Поиск летящих ракет ПТРК войск игрока
	for k in range(army.rockets.size() - 1, -1, -1):
		var r = army.rockets[k]
		if r.get("kind") != "atgm":
			continue

		if int(r.get("c")) != player_cid:
			continue

		var t = r.get("target")
		var alive_t: bool = (t is Unit and (t as Unit).alive()) or (t is Facility and world_ref.mil.alive(t as Facility))
		if not alive_t:
			continue

		var r_pos: Vector2 = r.get("pos", Vector2.ZERO)
		var tp: Vector2 = army._target_pos(t, r_pos)
		var dist = r_pos.distance_to(tp)

		# Разделение боевой части на подлёте (дистанция 46 пикселей)
		if dist <= 46.0:
			_split_atgm_cluster(r_pos, tp, int(r.get("dmg", 60)), player_cid)
			# Удаляем оригинальную моноблочную ракету
			army.rockets.remove_at(k)

func _split_atgm_cluster(start_pos: Vector2, target_pos: Vector2, total_dmg: int, country_id: int) -> void:
	# Эффект пиропатрона отделения кассет
	if world_ref != null and world_ref.fx != null:
		world_ref.fx.spawn("atgm_launch", start_pos.round(), 5)
		world_ref.fx.spawn("smoke_puff", start_pos.round(), 4)

	if ClassDB.class_exists("Sfx"):
		Sfx.play("rpg_fire", start_pos)

	var to_target = (target_pos - start_pos).normalized()
	var base_angle = to_target.angle()
	var sub_count = 6
	var dmg_per_sub = float(total_dmg) / float(sub_count) * 1.25 # Площадной суммарный урон выше

	# Выброс 6 суббоеприпасов веером в секторе атаки
	for i in sub_count:
		var angle_spread = randf_range(-0.55, 0.55)
		var ang = base_angle + angle_spread
		var spread_dist = randf_range(16.0, 48.0)
		var landing_spot = target_pos + Vector2.from_angle(randf() * TAU) * randf_range(4.0, 28.0)

		active_submunitions.append({
			"pos": start_pos,
			"target": landing_spot,
			"vel": Vector2.from_angle(ang) * randf_range(110.0, 160.0),
			"life": 0.0,
			"max_life": randf_range(0.35, 0.65),
			"dmg": dmg_per_sub,
			"cid": country_id,
			"trail_t": 0.0
		})

func _tick_submunitions(dt: float) -> void:
	for i in range(active_submunitions.size() - 1, -1, -1):
		var s = active_submunitions[i]
		s["life"] = float(s["life"]) + dt

		# Движение суббоеприпаса
		var pos: Vector2 = s["pos"]
		var vel: Vector2 = s["vel"]
		var target: Vector2 = s["target"]

		var to_tgt = (target - pos)
		var steer = to_tgt.normalized() * 320.0 * dt
		vel += steer
		pos += vel * dt
		s["pos"] = pos
		s["vel"] = vel

		# Шлейф дыма
		s["trail_t"] = float(s["trail_t"]) + dt
		if float(s["trail_t"]) >= 0.06:
			s["trail_t"] = 0.0
			if world_ref != null and world_ref.fx != null:
				world_ref.fx.spawn("trail_s", pos.round(), 3)

		# Подрыв при достижении цели или истечении таймера
		if float(s["life"]) >= float(s["max_life"]) or pos.distance_to(target) < 6.0:
			_detonate_submunition(pos, float(s["dmg"]), int(s["cid"]))
			active_submunitions.remove_at(i)

func _detonate_submunition(pos: Vector2, dmg: float, cid: int) -> void:
	if world_ref == null or not is_instance_valid(world_ref):
		return

	# Нативные эффекты взрыва
	if world_ref.fx != null:
		world_ref.fx.spawn("dirt_burst", pos.round(), 6)
		world_ref.fx.spawn("hit_small", pos.round(), 5)

	if ClassDB.class_exists("Sfx"):
		Sfx.play("expl_small", pos)

	# Нанесение урона по площади в радиусе 22 пикселей
	var blast_r = 22.0

	# 1. Поражение вражеских юнитов (танки, БМП, пехота)
	if "army" in world_ref and world_ref.army != null:
		for u in world_ref.army.units:
			if not (u is Unit and u.alive()):
				continue
			if not world_ref.army._hostile(cid, u.country_id):
				continue
			var d = u.pos.distance_to(pos)
			if d <= blast_r:
				var falloff = 1.0 - (d / blast_r) * 0.45
				var dealt = dmg * falloff
				world_ref.army._damage(u, dealt, cid, pos)

	# 2. Поражение укреплений / построек врага
	if "mil" in world_ref and world_ref.mil != null:
		for f in world_ref.mil.facilities:
			if f == null or not is_instance_valid(f) or not world_ref.army._hostile(cid, f.country_id) or not world_ref.mil.alive(f):
				continue
			if f.center_px().distance_to(pos) <= blast_r + 10.0:
				world_ref.army._damage(f, dmg * 0.7, cid, pos)


# ==============================================================================
# Слой отрисовки суббоеприпасов в мире (Без плавающих окон UI)
# ==============================================================================
class ATGMClusterWorldLayer extends Node2D:
	var mod_ref: RefCounted = null
	var main_ref: Node = null
	var world_ref: Node = null

	func setup(m: RefCounted, main: Node, world: Node) -> void:
		mod_ref = m
		main_ref = main
		world_ref = world
		z_index = 55

	func _draw() -> void:
		if mod_ref == null:
			return

		# Отрисовка летящих суббоеприпасов
		for s in mod_ref.active_submunitions:
			var p: Vector2 = s["pos"]
			var v: Vector2 = s["vel"]
			var dir = v.normalized()

			# Огненный хвост и корпус кассетного боеприпаса
			draw_line(p - dir * 4.0, p, Color(1.0, 0.6, 0.2, 0.9), 2.0)
			draw_circle(p, 1.5, Color(1.0, 0.95, 0.8, 1.0))
