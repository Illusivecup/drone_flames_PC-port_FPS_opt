extends RefCounted

## Мод «Термобарическая батарея «Солнцепёк»» для DroneFlames Reborn.
## Отдельная постройка во вкладке «АРМИЯ»: бетонная площадка с двумя тяжёлыми огнемётными
## системами. Залп из 24 термобарических реактивных снарядов с дымными следами и свечением,
## огненные шары, ударные волны, разлёт искр и догорающая местность в точке падения.

const BATT_COST_MONEY: int = 2400
const BATT_COST_METAL: int = 18
const SALVO_COST_MONEY: int = 500
const SALVO_COST_METAL: int = 6
const RELOAD_TIME: float = 12.0
const BATT_SIZE: Vector2i = Vector2i(8, 5)
const BATT_MAX_HP: float = 420.0
const BATT_REFUND: int = 1200
const BATT_REPAIR_COST: int = 300
const RANGE_MAX: float = 640.0
const RANGE_MIN: float = 90.0
const SALVO_ROCKETS: int = 24
const SALVO_TIME: float = 3.0
const SPREAD_R: float = 30.0
const BLAST_R: float = 17.0
const MAX_PARTICLES: int = 1400
const CELLPX: float = 4.0
const CELL_KEY: String = "thermo_battery"

const ST_READY: int = 0
const ST_AIM: int = 1
const ST_FIRE: int = 2
const ST_RELOAD: int = 3

var mm_ref: Node = null
var main_ref: Node = null
var world_ref: Node = null

var world_layer: Node2D = null
var glow_layer: Node2D = null

var is_placing: bool = false
var is_targeting: bool = false
var selected_fac: Facility = null
var targeting_fac: Facility = null

var batts: Array = []
var batts_scan_t: float = 0.0
var queue: Array = []
var rockets: Array = []
var rings: Array = []
var flashes: Array = []
var fx_sys: ThermoFx = null
var gtime: float = 0.0
var shake_cd: float = 0.0
var lamp_t: float = 0.0

const BuildPanel = preload("res://ui/ui24/build_panel.gd")

func close_all() -> void:
	is_placing = false
	is_targeting = false
	targeting_fac = null
	selected_fac = null
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

func init_mod(mm: Node) -> void:
	mm_ref = mm
	if mm.has_method("register_hook"):
		mm.call("register_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("register_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[ThermoBattery] Mod initialized.")

func cleanup_mod(mm: Node) -> void:
	if main_ref != null and is_instance_valid(main_ref) and main_ref.hud != null and mm != null and mm.has_method("cleanup_mod_hud"):
		mm.call("cleanup_mod_hud", main_ref.hud, Callable(self, "_on_hud_action"), [CELL_KEY])
	_cleanup_nodes()
	if mm and mm.has_method("unregister_hook"):
		mm.call("unregister_hook", "on_world_started", Callable(self, "_on_world_started"))
		mm.call("unregister_hook", "on_match_tick", Callable(self, "_on_match_tick"))
	print("[ThermoBattery] Mod cleaned up.")

func _cleanup_nodes() -> void:
	is_placing = false
	is_targeting = false
	selected_fac = null
	targeting_fac = null
	batts.clear()
	queue.clear()
	rockets.clear()
	rings.clear()
	flashes.clear()
	fx_sys = null
	if world_layer != null and is_instance_valid(world_layer):
		world_layer.queue_free()
	world_layer = null
	glow_layer = null

func _ensure_hud(main: Node, world: Node) -> void:
	if main == null or not is_instance_valid(main) or world == null or not is_instance_valid(world):
		return
	main_ref = main
	world_ref = world
	if fx_sys == null:
		fx_sys = ThermoFx.new()
		fx_sys.setup(MAX_PARTICLES)

	if main.hud != null:
		if main.hud.pages.size() > 4:
			var army_grid: GridContainer = main.hud.pages[4] as GridContainer
			if army_grid != null and not main.hud.keys.has(CELL_KEY):
				var cell = main.hud._cell(CELL_KEY, "icon_mlrs", true)
				army_grid.add_child(cell)
				army_grid.move_child(cell, mini(army_grid.get_child_count() - 1, 1))
		if not main.hud.action.is_connected(_on_hud_action):
			main.hud.action.connect(_on_hud_action)

	if world_layer == null or not is_instance_valid(world_layer):
		world_layer = ThermoWorldLayer.new()
		world_layer.setup(self, main, world)
		world.add_child(world_layer)
		glow_layer = ThermoGlowLayer.new()
		glow_layer.setup(self)
		world_layer.add_child(glow_layer)

func _on_world_started(main: Node, world: Node) -> void:
	_cleanup_nodes()
	_ensure_hud(main, world)
	if world != null:
		world.set_meta("thermo_battery_mod", self)
	print("[ThermoBattery] Cell injected into Army tab, world layers created.")

func launch_salvo_at(f: Facility, wpos: Vector2) -> bool:
	if f == null or not is_instance_valid(f) or not _batt_alive(f):
		return false
	if int(f.get_meta("state", ST_READY)) != ST_READY:
		return false
	var from_c: Vector2 = f.center_px()
	var dist: float = from_c.distance_to(wpos)
	if dist < RANGE_MIN or dist > RANGE_MAX:
		return false
	var p: Variant = world_ref.player if world_ref != null else null
	if p != null:
		if p.money < SALVO_COST_MONEY or p.metal < SALVO_COST_METAL:
			return false
		p.money -= SALVO_COST_MONEY
		p.metal -= SALVO_COST_METAL
	f.set_meta("target", wpos)
	f.set_meta("aim_tgt", (wpos - from_c).angle())
	f.set_meta("state", ST_AIM)
	f.set_meta("state_t", 2.5)
	if targeting_fac == f:
		is_targeting = false
		targeting_fac = null
	if main_ref != null and "overlay" in main_ref and main_ref.overlay != null:
		main_ref.overlay.ripple(wpos, "alert_red")
	Sfx.play("alarm_general_quarters", from_c, -8.0)
	return true

func _on_thermo_sheet_target() -> void:
	if is_placing:
		cancel_placement()
	if is_targeting:
		_cancel_targeting()

	_rescan_batts()
	var ready_batt: Facility = null
	var any_batt: Facility = null
	var player_id: int = int(world_ref.player.id) if world_ref != null and world_ref.player != null else 0
	for f in batts:
		if f != null and is_instance_valid(f) and f.country_id == player_id and _batt_alive(f):
			if any_batt == null:
				any_batt = f
			if int(f.get_meta("state", ST_READY)) == ST_READY:
				ready_batt = f
				break

	if ready_batt != null:
		selected_fac = ready_batt
		if main_ref != null and "selected_fac" in main_ref:
			main_ref.selected_fac = ready_batt
		_start_targeting(ready_batt)
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("СОЛНЦЕПЁК: выберите цель на карте для залпа ТОС-1А!")
	elif any_batt != null:
		selected_fac = any_batt
		if main_ref != null and "selected_fac" in main_ref:
			main_ref.selected_fac = any_batt
		_update_native_card(any_batt)
		if main_ref != null and main_ref.hud != null:
			var left_s = maxf(0.0, float(any_batt.get_meta("state_t", 0.0)))
			main_ref.hud.show_toast("Батарея «Солнцепёк» перезаряжается (%s). Ожидайте!" % main_ref.hud._mmss(left_s))
	else:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Нет батарей «Солнцепёк»! Постройте площадку во вкладке АРМИЯ.")
		if ClassDB.class_exists("UiKit"):
			UiKit.snd("ui_error")

func _on_hud_action(nm: String) -> void:
	match nm:
		"thermo_battery":
			if main_ref != null and main_ref.hud != null:
				main_ref.hud.show_tip(
					"Термобарическая батарея «Солнцепёк»",
					"Бетонная площадка с двумя тяжёлыми огнемётными системами ТОС-1А. Залп из 24 термобарических ракет выжигает всё живое и сносит постройки в зоне поражения. Стоимость: %d $ и %d металла, залп: %d $ и %d металла." % [BATT_COST_MONEY, BATT_COST_METAL, SALVO_COST_MONEY, SALVO_COST_METAL],
					"")
			toggle_placement()
		"thermo_sheet_target":
			_on_thermo_sheet_target()
		"thermo_build_another":
			start_placement()
		"thermo_fire":
			var f_fire: Facility = selected_fac
			if f_fire == null and main_ref != null and "selected_fac" in main_ref:
				f_fire = main_ref.selected_fac as Facility
			if f_fire != null and _is_batt(f_fire):
				_start_targeting(f_fire)
		"cancel_select", "thermo_close", "thermo_cancel":
			close_all()
		"thermo_repair":
			var f_rep: Facility = selected_fac
			if f_rep == null and main_ref != null and "selected_fac" in main_ref:
				f_rep = main_ref.selected_fac as Facility
			if f_rep != null and _is_batt(f_rep):
				_repair(f_rep)
		"thermo_demolish":
			var f_dem: Facility = selected_fac
			if f_dem == null and main_ref != null and "selected_fac" in main_ref:
				f_dem = main_ref.selected_fac as Facility
			if f_dem != null and _is_batt(f_dem):
				_demolish(f_dem)

func _is_batt(f: Facility) -> bool:
	if f == null or not is_instance_valid(f):
		return false
	if f.army_build == CELL_KEY or bool(f.get_meta("is_thermo", false)):
		f.kind = Facility.Kind.CIV_FACTORY
		f.set_meta("is_thermo", true)
		f.set_meta("mod_facility", true)
		f.moving = false
		f.mdest = Vector2.ZERO
		f.mpos = f.center_px()
		return true
	return false

func _batt_alive(f: Facility) -> bool:
	if f.hp <= 0.0:
		return false
	if world_ref != null and f.main_obj >= 0 and "obj_state" in world_ref:
		var st: Variant = world_ref.obj_state
		if st != null and f.main_obj < st.size() and int(st[f.main_obj]) != 0:
			return false
	return true

func _rescan_batts() -> void:
	batts.clear()
	if world_ref == null or world_ref.mil == null:
		return
	for f in world_ref.mil.facilities:
		if _is_batt(f):
			batts.append(f)

func _gdt(delta: float) -> float:
	var ts: float = 1.0
	if world_ref != null and "time_scale" in world_ref:
		ts = maxf(0.0, float(world_ref.time_scale))
	return delta * ts

func _on_match_tick(main: Node, world: Node, delta: float) -> void:
	main_ref = main
	world_ref = world
	if main != null and (main.hud == null or not main.hud.keys.has(CELL_KEY) or world_layer == null or fx_sys == null):
		_ensure_hud(main, world)
	var dt: float = _gdt(delta)
	gtime += dt
	lamp_t += dt
	shake_cd = maxf(0.0, shake_cd - dt)
	batts_scan_t -= dt
	if batts_scan_t <= 0.0:
		batts_scan_t = 0.6
		_rescan_batts()

	_tick_batteries(dt)
	_tick_queue()
	_tick_rockets(dt)
	_tick_effects(dt)

	if is_targeting and targeting_fac != null and is_instance_valid(targeting_fac):
		_update_targeting_card()
	elif main != null and "selected_fac" in main and main.selected_fac != null and is_instance_valid(main.selected_fac):
		var f: Facility = main.selected_fac as Facility
		if _is_batt(f):
			selected_fac = f
			_update_native_card(f)
		elif selected_fac != null and selected_fac == f:
			selected_fac = null
	else:
		selected_fac = null

	var busy: bool = is_placing or is_targeting or not batts.is_empty() or (fx_sys != null and fx_sys.n > 0) or not rockets.is_empty() or not rings.is_empty() or not flashes.is_empty()
	if busy:
		if world_layer != null and is_instance_valid(world_layer):
			world_layer.queue_redraw()
		if glow_layer != null and is_instance_valid(glow_layer):
			glow_layer.queue_redraw()

# ---------------------------------------------------------------- постройка
func toggle_placement() -> void:
	if is_placing:
		cancel_placement()
	else:
		start_placement()

func start_placement() -> void:
	if world_ref == null or not is_instance_valid(world_ref):
		return
	var p: Variant = world_ref.player
	if p == null:
		return
	if p.money < BATT_COST_MONEY or p.metal < BATT_COST_METAL:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает ресурсов: нужно %d $ и %d металла!" % [BATT_COST_MONEY, BATT_COST_METAL])
		UiKit.snd("ui_error")
		return
	is_placing = true
	is_targeting = false
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.set_key_pressed(CELL_KEY, true)
		main_ref.hud.show_toast("БАТАРЕЯ «СОЛНЦЕПЁК»: выберите место на своей территории (ЛКМ/Тап — построить, ПКМ — отмена)")
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
	if cell.x < 2 or cell.y < 2 or cell.x + BATT_SIZE.x >= d.w - 2 or cell.y + BATT_SIZE.y >= d.h - 2:
		return "Не помещается у края карты"
	var player: Variant = world_ref.player
	if player == null:
		return "Игрок не найден"
	for dy in range(BATT_SIZE.y):
		for dx in range(BATT_SIZE.x):
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
					var fac_at: Variant = world_ref.mil.facility_at(Vector2i(cx, cy))
					if fac_at != null and is_instance_valid(fac_at):
						return "Место занято: постройка или ПВО"
				return "Место занято другими объектами"
	return ""

func can_place_at(cell: Vector2i) -> bool:
	return place_why(cell) == ""

func place_batt_at(cell: Vector2i) -> void:
	var why: String = place_why(cell)
	if why != "":
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Нельзя построить здесь: " + why)
		UiKit.snd("ui_error")
		return
	var p: Variant = world_ref.player
	if p.money < BATT_COST_MONEY or p.metal < BATT_COST_METAL:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает: %d $ и %d металла!" % [BATT_COST_MONEY, BATT_COST_METAL])
		UiKit.snd("ui_error")
		return
	p.money -= BATT_COST_MONEY
	p.metal -= BATT_COST_METAL

	var f: Facility = Facility.new()
	f.id = world_ref.mil.facilities.size()
	f.kind = Facility.Kind.CIV_FACTORY
	f.country_id = p.id
	f.cell = cell
	f.size = BATT_SIZE
	f.army_build = CELL_KEY
	f.lower_sprite = CELL_KEY
	f.hp = BATT_MAX_HP
	f.moving = false
	f.mdest = Vector2.ZERO
	f.mpos = f.center_px()
	f.set_meta("is_thermo", true)
	f.set_meta("mod_facility", true)
	f.set_meta("state", ST_READY)
	f.set_meta("state_t", 0.0)
	f.set_meta("aim_cur", -PI * 0.5)
	f.set_meta("aim_tgt", -PI * 0.5)
	f.set_meta("target", Vector2.INF)
	f.set_meta("left", 0)

	var spr_name: String = "ad_mfg" if world_ref.spr_index.has("ad_mfg") else ("eco_silo" if world_ref.spr_index.has("eco_silo") else "missile_factory")
	f.main_obj = world_ref.add_object(spr_name, cell, GameWorld.KIND_BUILDING)
	f.obj_ids.append(f.main_obj)
	world_ref.mil.facilities.append(f)

	var d: Variant = world_ref.data
	for dy in range(f.size.y):
		for dx in range(f.size.x):
			var cx: int = cell.x + dx
			var cy: int = cell.y + dy
			world_ref.remove_tree_at(Vector2i(cx, cy))
			d.add_flag(cx, cy, WorldData.F_OCCUPIED)
			d.set_biome(cx, cy, Biome.INDUSTRIAL)

	if main_ref == null or not bool(main_ref.get("repeat_building")):
		cancel_placement()
	else:
		if main_ref.hud != null:
			main_ref.hud.show_toast("БАТАРЕЯ «СОЛНЦЕПЁК»: выберите место для следующей батареи (ПКМ — отмена)")
	UiKit.snd("ui_build")
	Sfx.play("vls_hatch_open", f.center_px())
	if world_ref.fx != null:
		world_ref.fx.spawn("dust_s", f.center_px().round(), 8)
	_rescan_batts()
	selected_fac = f
	if main_ref != null:
		main_ref.selected_fac = f
		if main_ref.hud != null:
			main_ref.hud.show_toast("Батарея «Солнцепёк» построена! Выберите её и нажмите «ОГОНЬ».")
			_update_native_card(f)

func _repair(f: Facility) -> void:
	var p: Variant = world_ref.player
	if p == null or f.hp >= BATT_MAX_HP:
		return
	if p.money < BATT_REPAIR_COST:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает средств на ремонт (нужно %d $)" % BATT_REPAIR_COST)
		UiKit.snd("ui_error")
		return
	p.money -= BATT_REPAIR_COST
	f.hp = BATT_MAX_HP
	Sfx.play("repair_work", f.center_px())
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Батарея полностью отремонтирована!")

func _demolish(f: Facility) -> void:
	var p: Variant = world_ref.player
	if p != null:
		p.money += BATT_REFUND
	var d: Variant = world_ref.data
	if d != null:
		for dy in range(f.size.y):
			for dx in range(f.size.x):
				d.clear_flag(f.cell.x + dx, f.cell.y + dy, WorldData.F_OCCUPIED)
	if f.main_obj >= 0 and world_ref.has_method("remove_object"):
		world_ref.remove_object(f.main_obj)
	world_ref.mil.facilities.erase(f)
	batts.erase(f)
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Батарея демонтирована (+%d $ возврат)." % BATT_REFUND)
	close_all()

	UiKit.snd("ui_select")

# ---------------------------------------------------------------- огонь
func _start_targeting(f: Facility) -> void:
	if int(f.get_meta("state", ST_READY)) != ST_READY:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Батарея ещё не готова к залпу.")
		UiKit.snd("ui_error")
		return
	is_targeting = true
	is_placing = false
	targeting_fac = f
	selected_fac = f
	if main_ref != null and "selected_fac" in main_ref:
		main_ref.selected_fac = f
	_update_targeting_card()
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("БАТАРЕЯ «СОЛНЦЕПЁК»: выберите цель на карте (дальность %d–%d). ЛКМ — залп!" % [int(RANGE_MIN), int(RANGE_MAX)])
	UiKit.snd("ui_select")

func _cancel_targeting() -> void:
	close_all()
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Наведение «Солнцепёка» отменено.")

func try_fire_at(wpos: Vector2) -> void:
	if targeting_fac == null or not is_instance_valid(targeting_fac):
		_cancel_targeting()
		return
	var f: Facility = targeting_fac
	var from_c: Vector2 = f.center_px()
	var dist: float = from_c.distance_to(wpos)
	if dist < RANGE_MIN or dist > RANGE_MAX:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Цель вне зоны досягаемости: дальность %d пикс. (допустимо %d–%d)" % [int(dist), int(RANGE_MIN), int(RANGE_MAX)])
		UiKit.snd("ui_error")
		return
	var p: Variant = world_ref.player
	if p == null or p.money < SALVO_COST_MONEY or p.metal < SALVO_COST_METAL:
		if main_ref != null and main_ref.hud != null:
			main_ref.hud.show_toast("Не хватает на залп: нужно %d $ и %d металла!" % [SALVO_COST_MONEY, SALVO_COST_METAL])
		UiKit.snd("ui_error")
		return
	p.money -= SALVO_COST_MONEY
	p.metal -= SALVO_COST_METAL
	f.set_meta("target", wpos)
	f.set_meta("aim_tgt", (wpos - from_c).angle())
	f.set_meta("state", ST_AIM)
	f.set_meta("state_t", 2.5)
	is_targeting = false
	targeting_fac = null
	if main_ref != null and "overlay" in main_ref and main_ref.overlay != null:
		main_ref.overlay.ripple(wpos, "alert_red")
	Sfx.play("alarm_general_quarters", from_c, -8.0)
	if main_ref != null and main_ref.hud != null:
		main_ref.hud.show_toast("Цель принята! Наведение батареи «Солнцепёк»...")
		_update_native_card(f)

func _tick_batteries(dt: float) -> void:
	for f: Facility in batts:
		if f == null or not is_instance_valid(f) or not _batt_alive(f):
			continue
		var st: int = int(f.get_meta("state", ST_READY))
		var cur: float = float(f.get_meta("aim_cur", -PI * 0.5))
		var tgt: float = float(f.get_meta("aim_tgt", cur))
		var diff: float = wrapf(tgt - cur, -PI, PI)
		var step: float = 2.4 * dt
		if absf(diff) <= step:
			cur = tgt
		else:
			cur += signf(diff) * step
		f.set_meta("aim_cur", wrapf(cur, -PI, PI))
		match st:
			ST_AIM:
				var left: float = float(f.get_meta("state_t", 0.0)) - dt
				f.set_meta("state_t", left)
				if absf(wrapf(tgt - cur, -PI, PI)) < 0.06 or left <= 0.0:
					_start_salvo(f)
			ST_FIRE:
				if int(f.get_meta("left", 0)) <= 0:
					f.set_meta("state", ST_RELOAD)
					f.set_meta("state_t", RELOAD_TIME)
			ST_RELOAD:
				var rl: float = float(f.get_meta("state_t", 0.0)) - dt
				f.set_meta("state_t", rl)
				if rl <= 0.0:
					f.set_meta("state", ST_READY)
					f.set_meta("state_t", 0.0)
					if f.country_id == int(world_ref.player.id) and main_ref != null and main_ref.hud != null:
						main_ref.hud.show_toast("Батарея «Солнцепёк» перезаряжена и готова к залпу!")
						UiKit.snd("ui_select")

func launcher_pos(f: Facility, side: int) -> Vector2:
	return f.center_px() + Vector2(-8.0 if side == 0 else 8.0, -1.0)

func _start_salvo(f: Facility) -> void:
	var tgt: Vector2 = f.get_meta("target", Vector2.INF)
	if tgt == Vector2.INF:
		f.set_meta("state", ST_READY)
		return
	var ang: float = float(f.get_meta("aim_cur", 0.0))
	var dir: Vector2 = Vector2(cos(ang), sin(ang))
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var from_c: Vector2 = f.center_px()
	var dist: float = from_c.distance_to(tgt)
	var spread: float = SPREAD_R * (0.6 + 0.6 * dist / RANGE_MAX)
	for i in range(SALVO_ROCKETS):
		var lp: Vector2 = launcher_pos(f, i % 2) + dir * 6.0 + perp * randf_range(-3.0, 3.0)
		var a2: float = randf() * TAU
		var rad: float = spread * sqrt(randf())
		var tp: Vector2 = tgt + Vector2(cos(a2), sin(a2) * 0.8) * rad
		queue.append({
			"at": gtime + float(i) * SALVO_TIME / float(SALVO_ROCKETS) + randf() * 0.05,
			"from": lp, "target": tp, "center": tgt, "cid": f.country_id,
			"last": i == SALVO_ROCKETS - 1, "idx": i
		})
	f.set_meta("left", SALVO_ROCKETS)
	f.set_meta("state", ST_FIRE)
	f.set_meta("state_t", SALVO_TIME)
	Sfx.play("mlrs_salvo", from_c, 3.0)
	if world_ref.fx != null:
		world_ref.fx.spawn("launch_cloud", from_c.round(), 5)
		world_ref.fx.spawn("tel_flash", launcher_pos(f, 0).round(), 6)
		world_ref.fx.spawn("tel_flash", launcher_pos(f, 1).round(), 6)
	_shake(3.0)
	if world_ref.has_method("say") and world_ref.player != null and f.country_id == world_ref.player.id:
		world_ref.say(world_ref.player, Loc.mk("Батарея «Солнцепёк» открыла огонь!"))

func _tick_queue() -> void:
	if queue.is_empty():
		return
	for i in range(queue.size() - 1, -1, -1):
		var q: Dictionary = queue[i]
		if float(q["at"]) > gtime:
			continue
		queue.remove_at(i)
		_launch_rocket(q)

func _launch_rocket(q: Dictionary) -> void:
	var from_p: Vector2 = q["from"]
	var tp: Vector2 = q["target"]
	var dist: float = from_p.distance_to(tp)
	var dur: float = clampf(dist / 330.0, 0.9, 2.7)
	rockets.append({
		"from": from_p, "target": tp, "center": q["center"], "t": 0.0, "dur": dur,
		"h": clampf(dist * 0.22, 24.0, 150.0), "cid": int(q["cid"]), "last": bool(q["last"]),
		"acc": randf() * 0.03, "pos": from_p, "dir": Vector2.RIGHT
	})
	# задний выхлоп установки
	if fx_sys != null:
		for k in range(5):
			fx_sys.emit(ThermoFx.K_SMOKE, from_p.x + randf_range(-2, 2), from_p.y + randf_range(-1, 1), randf_range(-14, 14), randf_range(-16, -4), randf_range(1.0, 1.7), 3.0, 8.0, -6.0)
		for k in range(4):
			fx_sys.emit(ThermoFx.K_FIRE, from_p.x, from_p.y, randf_range(-22, 22), randf_range(-26, -6), randf_range(0.14, 0.28), 4.0, 2.0, 0.0)
		fx_sys.emit(ThermoFx.K_GLOW, from_p.x, from_p.y, 0.0, 0.0, 0.18, 9.0, 4.0, 0.0)
	if int(q["idx"]) % 6 == 0:
		Sfx.play("shell_whistle_in", tp, -6.0)
	if int(q["idx"]) % 3 == 0:
		Sfx.play("mlrs_salvo", from_p, -9.0)
	for f: Facility in batts:
		if f != null and is_instance_valid(f) and f.country_id == int(q["cid"]) and f.center_px().distance_to(from_p) < 40.0:
			f.set_meta("left", maxi(0, int(f.get_meta("left", 0)) - 1))

func _rocket_pos(m: Dictionary, k: float) -> Vector2:
	var g: Vector2 = (m["from"] as Vector2).lerp(m["target"], k)
	var alt: float = 4.0 * float(m["h"]) * k * (1.0 - k)
	return g - Vector2(0.0, alt)

func _tick_rockets(dt: float) -> void:
	for i in range(rockets.size() - 1, -1, -1):
		var m: Dictionary = rockets[i]
		m["t"] = float(m["t"]) + dt
		var k: float = clampf(float(m["t"]) / float(m["dur"]), 0.0, 1.0)
		var p0: Vector2 = _rocket_pos(m, k)
		var p1: Vector2 = _rocket_pos(m, minf(1.0, k + 0.02))
		var dirv: Vector2 = (p1 - p0)
		if dirv.length() < 0.001:
			dirv = m["dir"]
		else:
			dirv = dirv.normalized()
		m["pos"] = p0
		m["dir"] = dirv
		if fx_sys != null:
			m["acc"] = float(m["acc"]) + dt
			if float(m["acc"]) >= 0.02:
				m["acc"] = 0.0
				var tail: Vector2 = p0 - dirv * 5.0
				fx_sys.emit(ThermoFx.K_TRAIL, tail.x, tail.y, randf_range(-3, 3), randf_range(-3, 3), randf_range(0.8, 1.5), 2.0, 5.5, -3.0)
				fx_sys.emit(ThermoFx.K_FIRE, tail.x, tail.y, randf_range(-4, 4), randf_range(-4, 4), 0.12, 2.0, 1.0, 0.0)
		if k >= 1.0:
			_impact(m)
			rockets.remove_at(i)

# ---------------------------------------------------------------- взрыв
func _shake(power: float) -> void:
	if shake_cd > 0.0 or world_ref == null:
		return
	shake_cd = 0.12
	var cam: Variant = world_ref.camera
	if cam != null and cam.has_method("shake_pattern"):
		cam.shake_pattern([Vector2(power, -power), Vector2(-power, power), Vector2(power * 0.6, power * 0.5), Vector2(-power * 0.3, -power * 0.3), Vector2(0, 0)], 0.05)

func _impact(m: Dictionary) -> void:
	var pos: Vector2 = m["target"]
	var cid: int = int(m["cid"])
	_spawn_fireball(pos)
	if world_ref.fx != null:
		world_ref.fx.spawn("x_mlrs", pos.round(), 6)
		if randf() < 0.75:
			world_ref.fx.spawn("fire_small", (pos + Vector2(randf_range(-6, 6), randf_range(-4, 4))).round(), 4, world_ref.game_time + randf_range(10.0, 22.0), true)
	var cell: Vector2i = Vector2i(floori(pos.x / CELLPX), floori(pos.y / CELLPX))
	if world_ref.has_method("_apply_strike"):
		world_ref._apply_strike(cell, 2, "crater_s", 22.0, cid)
	_damage_area(pos, cid)
	if randi() % 2 == 0:
		Sfx.play("expl_small", pos, -2.0)
	_shake(1.6)
	if bool(m["last"]):
		_finale(m["center"], cid)

func _damage_area(pos: Vector2, cid: int) -> void:
	var army: Variant = world_ref.army
	if army == null or army.units == null:
		return
	for u in army.units:
		if u == null or not is_instance_valid(u):
			continue
		if not u.alive():
			continue
		if u.country_id == cid:
			continue
		var d: float = u.pos.distance_to(pos)
		if d > BLAST_R:
			continue
		var fall: float = 1.0 - clampf(d / BLAST_R, 0.0, 1.0) * 0.55
		var dmg: float = (62.0 if u.vehicle() else 140.0) * fall
		u.hp -= dmg
		u.hit_t = world_ref.game_time
		if u.hp <= 0.0:
			army._kill(u, cid)

func _finale(center: Vector2, cid: int) -> void:
	if world_ref.fx != null:
		world_ref.fx.spawn("explosion_l", center.round(), 7)
		world_ref.fx.spawn("smoke_column_loop", (center + Vector2(0, -6)).round(), 6, world_ref.game_time + 16.0, true)
		for k in range(8):
			var a: float = randf() * TAU
			var r: float = randf_range(6.0, SPREAD_R * 1.1)
			var fp: Vector2 = center + Vector2(cos(a), sin(a) * 0.8) * r
			world_ref.fx.spawn("fire_small", fp.round(), 4, world_ref.game_time + randf_range(14.0, 26.0), true)
			if k % 3 == 0:
				world_ref.fx.spawn("smoke_black_loop", (fp + Vector2(0, -8)).round(), 6, world_ref.game_time + randf_range(16.0, 24.0), true)
	rings.append({"pos": center, "t": 0.0, "dur": 0.9, "r0": 6.0, "r1": SPREAD_R * 2.2})
	flashes.append({"pos": center, "t": 0.0, "dur": 0.35, "r": SPREAD_R * 1.5})
	Sfx.play("expl_big", center, 2.0)
	Sfx.play("far_boom_1", center, 0.0)
	_shake(5.0)

func _spawn_fireball(pos: Vector2) -> void:
	if fx_sys == null:
		return
	# светящаяся вспышка и кольцо ударной волны по земле
	flashes.append({"pos": pos, "t": 0.0, "dur": 0.2, "r": BLAST_R * 1.1})
	rings.append({"pos": pos, "t": 0.0, "dur": 0.38, "r0": 3.0, "r1": BLAST_R * 1.9})
	fx_sys.emit(ThermoFx.K_GLOW, pos.x, pos.y - 2.0, 0.0, -8.0, 0.5, 10.0, 17.0, -4.0)
	# ядро огненного шара: крупные раскалённые «клубы», поднимающиеся вверх
	for i in range(6):
		var a: float = randf() * TAU
		fx_sys.emit(ThermoFx.K_FIRE, pos.x + cos(a) * 2.0, pos.y + sin(a) * 1.5 - 2.0, cos(a) * randf_range(4, 14), randf_range(-26, -10), randf_range(0.6, 0.95), 6.0, 9.0, -34.0)
	# огненные языки в стороны
	for i in range(28):
		var a2: float = randf() * TAU
		var sp: float = randf_range(24.0, 74.0)
		fx_sys.emit(ThermoFx.K_FIRE, pos.x, pos.y - 1.0, cos(a2) * sp, sin(a2) * sp * 0.55 - randf_range(8.0, 36.0), randf_range(0.35, 0.85), 3.0, 6.0, -30.0)
	# чёрный дым
	for i in range(9):
		var a3: float = randf() * TAU
		fx_sys.emit(ThermoFx.K_SMOKE, pos.x + cos(a3) * 5.0, pos.y - 4.0 + sin(a3) * 3.0, cos(a3) * randf_range(2, 12), randf_range(-22, -8), randf_range(1.8, 3.2), 5.0, 13.0, -12.0)
	# искры и тлеющие угли
	for i in range(10):
		var a4: float = randf() * TAU
		var sp2: float = randf_range(36.0, 130.0)
		fx_sys.emit(ThermoFx.K_EMBER, pos.x, pos.y - 2.0, cos(a4) * sp2, sin(a4) * sp2 * 0.6 - randf_range(30.0, 90.0), randf_range(0.5, 1.3), 1.0, 1.0, 0.0)

func _tick_effects(dt: float) -> void:
	if fx_sys != null:
		fx_sys.update(dt)
	for i in range(rings.size() - 1, -1, -1):
		rings[i]["t"] = float(rings[i]["t"]) + dt
		if float(rings[i]["t"]) >= float(rings[i]["dur"]):
			rings.remove_at(i)
	for i in range(flashes.size() - 1, -1, -1):
		flashes[i]["t"] = float(flashes[i]["t"]) + dt
		if float(flashes[i]["t"]) >= float(flashes[i]["dur"]):
			flashes.remove_at(i)

# ---------------------------------------------------------------- карточки HUD
func _update_native_card(f: Facility) -> void:
	if main_ref == null or main_ref.hud == null:
		return
	var h: Variant = main_ref.hud
	var p: Variant = world_ref.player
	if p == null:
		return
	var st: int = int(f.get_meta("state", ST_READY))
	var left_s: float = maxf(0.0, float(f.get_meta("state_t", 0.0)))
	h._card("thermo_batt_%d" % f.id, "icon_mlrs", "БАТАРЕЯ «СОЛНЦЕПЁК»", "Тяжёлая огнемётная система ТОС-1А · Батарея #%d" % f.id, false, false, true)
	var info: String = ""
	if st == ST_READY:
		info = "СТАТУС: ГОТОВА К ЗАЛПУ · 24 РАКЕТЫ · ДАЛЬНОСТЬ %d-%d\nМЕТАЛЛ В СТРАНЕ: %d · ПРОЧНОСТЬ: %d/%d" % [int(RANGE_MIN), int(RANGE_MAX), int(p.metal), int(f.hp), int(BATT_MAX_HP)]
	elif st == ST_AIM:
		info = "СТАТУС: НАВЕДЕНИЕ УСТАНОВОК НА ЦЕЛЬ...\nПРОЧНОСТЬ: %d/%d" % [int(f.hp), int(BATT_MAX_HP)]
	elif st == ST_FIRE:
		info = "СТАТУС: ЗАЛП! РАКЕТЫ В ВОЗДУХЕ\nПРОЧНОСТЬ: %d/%d" % [int(f.hp), int(BATT_MAX_HP)]
	else:
		info = "СТАТУС: ЗАРЯЖАНИЕ ТРАНСПОРТНО-ЗАРЯЖАЮЩИХ МАШИН... %s\nПРОЧНОСТЬ: %d/%d" % [h._mmss(left_s), int(f.hp), int(BATT_MAX_HP)]
	h._set_info(info, st == ST_READY)
	h.ops_detail.text = "Две тяжёлые огнемётные системы на бетонной площадке. Залп из 24 термобарических снарядов создаёт огненный шторм: объёмный взрыв выжигает пехоту, калечит технику и сносит постройки. Для залпа нужны деньги и металл."
	h.ops_detail.visible = true

	var acts: Array = []
	if st == ST_READY:
		var can_fire: bool = p.money >= SALVO_COST_MONEY and p.metal >= SALVO_COST_METAL
		acts.append(h._act("ОГОНЬ\n%d $ · %d М" % [SALVO_COST_MONEY, SALVO_COST_METAL], "icon_target", "thermo_fire", can_fire))
	elif st == ST_RELOAD:
		acts.append(h._act("ЗАРЯЖАНИЕ\n%s" % h._mmss(left_s), "icon_restore", "none", false))
	elif st == ST_AIM:
		acts.append(h._act("НАВЕДЕНИЕ", "icon_target", "none", false))
	else:
		acts.append(h._act("ЗАЛП", "icon_target", "none", false))

	acts.append(h._act("ЕЩЁ БАТАРЕЯ\n%d $" % BATT_COST_MONEY, "icon_mlrs", "thermo_build_another", p.money >= BATT_COST_MONEY and p.metal >= BATT_COST_METAL))

	if f.hp < BATT_MAX_HP:
		acts.append(h._act("РЕМОНТ\n%d $" % BATT_REPAIR_COST, "icon_restore", "thermo_repair", p.money >= BATT_REPAIR_COST))

	var dact: Dictionary = h._act("СНОС\n+%d $" % BATT_REFUND, "icon_close", "thermo_demolish", true)
	dact["red"] = true
	acts.append(dact)

	acts.append(h._act("ЗАКРЫТЬ", "icon_close", "thermo_close", true))
	h._fill_acts("thermo_acts_%d" % f.id, acts)

func _update_targeting_card() -> void:
	if main_ref == null or main_ref.hud == null:
		return
	var h: Variant = main_ref.hud
	h._card("thermo_targeting", "icon_mlrs", "НАВЕДЕНИЕ БАТАРЕИ «СОЛНЦЕПЁК»", "Кликните ЛКМ по карте для залпа · ПКМ или Esc — отмена", false, false, true)
	h._set_info("ЗОНА ПОРАЖЕНИЯ: РАДИУС %d ПИКС. · ДАЛЬНОСТЬ %d–%d ПИКС." % [int(SPREAD_R * 2.0), int(RANGE_MIN), int(RANGE_MAX)], false)
	h.ops_detail.visible = false
	var acts: Array = []
	acts.append(h._act("ОТМЕНА", "icon_close", "thermo_cancel", true))
	h._fill_acts("thermo_target_acts", acts)

# ---------------------------------------------------------------- отрисовка
func draw_batteries(ci: CanvasItem) -> void:
	var atlas: SpriteAtlas = UnitsLayer.atlas314()
	for f: Facility in batts:
		if f == null or not is_instance_valid(f) or not _batt_alive(f):
			continue
		var o: Vector2 = Vector2(f.cell) * CELLPX
		var sz: Vector2 = Vector2(BATT_SIZE) * CELLPX
		# земляной вал, бетонная плита, разметка
		ci.draw_rect(Rect2(o + Vector2(-2, -2), sz + Vector2(4, 4)), Color(0.33, 0.29, 0.20))
		ci.draw_rect(Rect2(o + Vector2(-1, -1), sz + Vector2(2, 2)), Color(0.24, 0.24, 0.22))
		ci.draw_rect(Rect2(o, sz), Color(0.47, 0.48, 0.45))
		ci.draw_rect(Rect2(o + Vector2(1, 1), sz - Vector2(2, 2)), Color(0.54, 0.55, 0.51))
		for s in range(2):
			var lx: float = o.x + (1.0 if s == 0 else sz.x * 0.5 + 1.0)
			ci.draw_rect(Rect2(lx, o.y + 2, sz.x * 0.5 - 2, sz.y - 6), Color(0.62, 0.63, 0.58), false, 1.0)
		# опасная полоса у переднего края
		var x: float = o.x
		var flip: bool = false
		while x < o.x + sz.x:
			ci.draw_rect(Rect2(x, o.y + sz.y - 3, minf(3.0, o.x + sz.x - x), 2), Color(0.86, 0.72, 0.18) if flip else Color(0.14, 0.14, 0.13))
			flip = not flip
			x += 3.0
		# ящики с боеприпасом
		ci.draw_rect(Rect2(o + Vector2(2, 2), Vector2(3, 2)), Color(0.28, 0.32, 0.20))
		ci.draw_rect(Rect2(o + Vector2(sz.x - 5, 2), Vector2(3, 2)), Color(0.28, 0.32, 0.20))
		# установки
		var st: int = int(f.get_meta("state", ST_READY))
		var ang_deg: float = rad_to_deg(float(f.get_meta("aim_cur", -PI * 0.5)))
		var fr: int = posmod(int(roundf(ang_deg / 22.5)), 16)
		var nm: String = "mlrs_fire" if st == ST_FIRE else "mlrs"
		if atlas != null and atlas.has(nm):
			for s in range(2):
				var c: Vector2 = launcher_pos(f, s).round()
				var info: Dictionary = atlas.info(nm)
				if atlas.has(nm + "_shadow"):
					var rs: Rect2 = atlas.rect(nm + "_shadow", fr)
					ci.draw_texture_rect_region(atlas.texture, Rect2(c + Vector2(1, 1) - Vector2(float(info["ax"]), float(info["ay"])), rs.size), rs)
				var r: Rect2 = atlas.rect(nm, fr)
				ci.draw_texture_rect_region(atlas.texture, Rect2(c - Vector2(float(info["ax"]), float(info["ay"])), r.size), r)
		# индикатор состояния и полоса перезарядки
		var lamp: Color = Color(0.2, 1.0, 0.35)
		if st == ST_AIM or st == ST_FIRE:
			lamp = Color(1.0, 0.25, 0.2)
		elif st == ST_RELOAD:
			lamp = Color(1.0, 0.7, 0.2)
		var blink: float = 0.55 + 0.45 * sin(lamp_t * 6.0) if st == ST_READY else 1.0
		ci.draw_rect(Rect2(o + Vector2(sz.x - 3, sz.y - 6), Vector2(2, 2)), Color(lamp.r, lamp.g, lamp.b, blink))
		if st == ST_RELOAD:
			var pr: float = 1.0 - clampf(float(f.get_meta("state_t", 0.0)) / RELOAD_TIME, 0.0, 1.0)
			ci.draw_rect(Rect2(o + Vector2(0, sz.y + 2), Vector2(sz.x, 1)), Color(0.1, 0.1, 0.1, 0.7))
			ci.draw_rect(Rect2(o + Vector2(0, sz.y + 2), Vector2(sz.x * pr, 1)), Color(1.0, 0.7, 0.2))

func draw_rockets(ci: CanvasItem) -> void:
	for m: Dictionary in rockets:
		var k: float = clampf(float(m["t"]) / float(m["dur"]), 0.0, 1.0)
		var head: Vector2 = m["pos"]
		var dirv: Vector2 = m["dir"]
		var g: Vector2 = (m["from"] as Vector2).lerp(m["target"], k)
		ci.draw_circle(g.round(), 1.6, Color(0, 0, 0, 0.28))
		var tail: Vector2 = head - dirv * 5.5
		var perp: Vector2 = Vector2(-dirv.y, dirv.x)
		ci.draw_line(tail.round(), head.round(), Color(0.70, 0.69, 0.60), 2.0)
		ci.draw_line((head - dirv * 1.4).round(), (head + dirv * 1.0).round(), Color(0.90, 0.34, 0.20), 2.0)
		ci.draw_line((tail + perp * 1.5).round(), tail.round(), Color(0.38, 0.40, 0.34), 1.0)
		ci.draw_line((tail - perp * 1.5).round(), tail.round(), Color(0.38, 0.40, 0.34), 1.0)

func draw_rings(ci: CanvasItem) -> void:
	for r: Dictionary in rings:
		var u: float = clampf(float(r["t"]) / float(r["dur"]), 0.0, 1.0)
		var rad: float = lerpf(float(r["r0"]), float(r["r1"]), 1.0 - (1.0 - u) * (1.0 - u))
		ci.draw_set_transform(r["pos"], 0.0, Vector2(1.0, 0.6))
		ci.draw_arc(Vector2.ZERO, rad, 0.0, TAU, 40, Color(1.0, 0.88, 0.62, 0.65 * (1.0 - u)), 1.0 + 2.0 * (1.0 - u))
		ci.draw_arc(Vector2.ZERO, rad * 0.82, 0.0, TAU, 32, Color(1.0, 0.55, 0.2, 0.35 * (1.0 - u)), 1.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_glow(ci: CanvasItem) -> void:
	for fl: Dictionary in flashes:
		var u: float = clampf(float(fl["t"]) / float(fl["dur"]), 0.0, 1.0)
		var rr: float = float(fl["r"]) * (0.6 + u * 0.8)
		var a: float = 1.0 - u
		ci.draw_circle(fl["pos"], rr, Color(1.0, 0.55, 0.15, 0.30 * a))
		ci.draw_circle(fl["pos"], rr * 0.6, Color(1.0, 0.8, 0.4, 0.45 * a))
		ci.draw_circle(fl["pos"], rr * 0.28, Color(1.0, 1.0, 0.9, 0.8 * a))
	for m: Dictionary in rockets:
		var tail: Vector2 = (m["pos"] as Vector2) - (m["dir"] as Vector2) * 5.0
		var dirv: Vector2 = m["dir"]
		ci.draw_circle(tail, 3.2, Color(1.0, 0.5, 0.12, 0.16))
		ci.draw_circle(tail - dirv * 1.5, 1.9, Color(1.0, 0.78, 0.35, 0.5))
		ci.draw_line(tail - dirv * 4.0, tail, Color(1.0, 0.62, 0.2, 0.55), 2.0)
		ci.draw_circle(tail, 1.0, Color(1.0, 1.0, 0.92, 0.95))
	if fx_sys != null:
		fx_sys.draw_glow(ci)

func draw_targeting(ci: CanvasItem, mouse_w: Vector2) -> void:
	if not is_targeting or targeting_fac == null or not is_instance_valid(targeting_fac):
		return
	var c: Vector2 = targeting_fac.center_px()
	var dist: float = c.distance_to(mouse_w)
	var ok: bool = dist >= RANGE_MIN and dist <= RANGE_MAX
	var col: Color = Color(1.0, 0.55, 0.2) if ok else Color(1.0, 0.2, 0.2)
	var pulse: float = 0.75 + 0.25 * sin(lamp_t * 7.0)
	ci.draw_arc(c, RANGE_MAX, 0.0, TAU, 96, Color(1.0, 0.6, 0.2, 0.45), 1.0)
	ci.draw_arc(c, RANGE_MIN, 0.0, TAU, 48, Color(1.0, 0.25, 0.2, 0.4), 1.0)
	ci.draw_line(c, mouse_w, Color(col.r, col.g, col.b, 0.5), 1.0)
	var spread: float = SPREAD_R * (0.6 + 0.6 * clampf(dist / RANGE_MAX, 0.0, 1.0))
	ci.draw_arc(mouse_w, spread, 0.0, TAU, 40, Color(col.r, col.g, col.b, pulse), 1.5)
	ci.draw_arc(mouse_w, spread * 0.5, 0.0, TAU, 28, Color(col.r, col.g, col.b, pulse * 0.5), 1.0)
	ci.draw_line(mouse_w + Vector2(-spread - 4, 0), mouse_w + Vector2(-spread + 4, 0), col, 1.0)
	ci.draw_line(mouse_w + Vector2(spread - 4, 0), mouse_w + Vector2(spread + 4, 0), col, 1.0)
	ci.draw_line(mouse_w + Vector2(0, -spread - 4), mouse_w + Vector2(0, -spread + 4), col, 1.0)
	ci.draw_line(mouse_w + Vector2(0, spread - 4), mouse_w + Vector2(0, spread + 4), col, 1.0)
	for s in range(2):
		ci.draw_line(launcher_pos(targeting_fac, s), mouse_w, Color(col.r, col.g, col.b, 0.18), 1.0)

# ================================================================ частицы
class ThermoFx extends RefCounted:
	const K_FIRE: int = 0
	const K_SMOKE: int = 1
	const K_EMBER: int = 2
	const K_TRAIL: int = 3
	const K_GLOW: int = 4

	var n: int = 0
	var cap: int = 0
	var px: PackedFloat32Array = PackedFloat32Array()
	var py: PackedFloat32Array = PackedFloat32Array()
	var vx: PackedFloat32Array = PackedFloat32Array()
	var vy: PackedFloat32Array = PackedFloat32Array()
	var age: PackedFloat32Array = PackedFloat32Array()
	var life: PackedFloat32Array = PackedFloat32Array()
	var s0: PackedFloat32Array = PackedFloat32Array()
	var s1: PackedFloat32Array = PackedFloat32Array()
	var rise: PackedFloat32Array = PackedFloat32Array()
	var kind: PackedInt32Array = PackedInt32Array()

	func setup(p_cap: int) -> void:
		cap = p_cap
		n = 0
		px.resize(cap)
		py.resize(cap)
		vx.resize(cap)
		vy.resize(cap)
		age.resize(cap)
		life.resize(cap)
		s0.resize(cap)
		s1.resize(cap)
		rise.resize(cap)
		kind.resize(cap)

	func emit(k: int, x: float, y: float, p_vx: float, p_vy: float, p_life: float, p_s0: float, p_s1: float, p_rise: float) -> void:
		if n >= cap:
			return
		# при почти полном буфере дым уступает место огню
		if k == K_SMOKE and n > cap - cap / 5:
			return
		var i: int = n
		px[i] = x
		py[i] = y
		vx[i] = p_vx
		vy[i] = p_vy
		age[i] = 0.0
		life[i] = maxf(0.05, p_life)
		s0[i] = p_s0
		s1[i] = p_s1
		rise[i] = p_rise
		kind[i] = k
		n += 1

	func update(dt: float) -> void:
		if dt <= 0.0:
			return
		var i: int = n - 1
		while i >= 0:
			age[i] += dt
			if age[i] >= life[i]:
				var l: int = n - 1
				if i != l:
					px[i] = px[l]
					py[i] = py[l]
					vx[i] = vx[l]
					vy[i] = vy[l]
					age[i] = age[l]
					life[i] = life[l]
					s0[i] = s0[l]
					s1[i] = s1[l]
					rise[i] = rise[l]
					kind[i] = kind[l]
				n -= 1
			else:
				var k: int = kind[i]
				var drag: float = 1.6
				if k == K_EMBER:
					drag = 0.35
					vy[i] += 190.0 * dt
				else:
					vy[i] += rise[i] * dt
					if k == K_SMOKE:
						drag = 1.1
					elif k == K_TRAIL:
						drag = 2.2
				vx[i] *= maxf(0.0, 1.0 - drag * dt)
				vy[i] *= maxf(0.0, 1.0 - drag * 0.5 * dt)
				px[i] += vx[i] * dt
				py[i] += vy[i] * dt
			i -= 1

	static func fire_color(u: float) -> Color:
		var a: float = 1.0 if u < 0.8 else maxf(0.0, 1.0 - (u - 0.8) / 0.2)
		if u < 0.10:
			return Color(1.0, 0.99, 0.89, a)
		if u < 0.28:
			return Color(1.0, 0.87, 0.43, a)
		if u < 0.50:
			return Color(1.0, 0.63, 0.19, a)
		if u < 0.72:
			return Color(0.87, 0.34, 0.12, a)
		if u < 0.88:
			return Color(0.55, 0.17, 0.10, a)
		return Color(0.27, 0.20, 0.17, a)

	func draw_normal(ci: CanvasItem) -> void:
		for i in range(n):
			var u: float = age[i] / life[i]
			var k: int = kind[i]
			if k == K_GLOW:
				continue
			var s: float = lerpf(s0[i], s1[i], u)
			var col: Color
			if k == K_FIRE:
				col = fire_color(u)
				if u > 0.7:
					s *= 1.0 - (u - 0.7) / 0.3 * 0.45
			elif k == K_SMOKE:
				var a: float = minf(u / 0.12, 1.0) * 0.58 * (1.0 - u)
				var tone: float = lerpf(0.47, 0.20, minf(u * 1.4, 1.0))
				col = Color(tone, tone * 0.93, tone * 0.86, a)
			elif k == K_TRAIL:
				var a2: float = 0.85 * (1.0 - u)
				var tone2: float = lerpf(0.98, 0.45, minf(u * 2.5, 1.0))
				col = Color(tone2, tone2 * 0.96, tone2 * 0.88, a2)
			else:
				col = Color(1.0, lerpf(0.82, 0.35, u), lerpf(0.35, 0.1, u), 1.0 - u * 0.85)
				s = 1.0
			var sz: float = maxf(1.0, roundf(s))
			ci.draw_rect(Rect2(floorf(px[i] - sz * 0.5), floorf(py[i] - sz * 0.5), sz, sz), col)

	func draw_glow(ci: CanvasItem) -> void:
		for i in range(n):
			var k: int = kind[i]
			if k != K_GLOW:
				if k == K_EMBER:
					var ue: float = age[i] / life[i]
					ci.draw_circle(Vector2(px[i], py[i]), 1.8, Color(1.0, 0.55, 0.15, 0.30 * (1.0 - ue)))
				continue
			var u: float = age[i] / life[i]
			var r: float = lerpf(s0[i], s1[i], u)
			var a: float = 1.0 - u
			ci.draw_circle(Vector2(px[i], py[i]), r, Color(1.0, 0.5, 0.12, 0.17 * a))
			ci.draw_circle(Vector2(px[i], py[i]), r * 0.55, Color(1.0, 0.72, 0.28, 0.26 * a))

# ================================================================ слои мира
class ThermoWorldLayer extends Node2D:
	var mod = null
	var main: Node = null
	var world: Node = null

	func setup(p_mod, p_main: Node, p_world: Node) -> void:
		mod = p_mod
		main = p_main
		world = p_world
		z_index = 86

	func _unhandled_input(event: InputEvent) -> void:
		if mod == null or world == null or main == null:
			return

		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				if mod.is_placing:
					mod.cancel_placement()
					get_viewport().set_input_as_handled()
					return
				elif mod.is_targeting or mod.selected_fac != null:
					mod.close_all()
					get_viewport().set_input_as_handled()
					return

		if event is InputEventMouseButton:
			if event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					var wp: Vector2 = main.cam.screen_to_world(event.position) if main.cam != null else event.position
					var cell: Vector2i = Vector2i((wp / float(GameWorld.CELL)).floor())
					if mod.is_placing:
						mod.place_batt_at(cell)
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
					elif mod.is_targeting or mod.selected_fac != null:
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
					mod.place_batt_at(cell)
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
		mod.draw_batteries(self)
		if mod.is_placing:
			var cell: Vector2i = Vector2i((mouse_w / float(GameWorld.CELL)).floor())
			var valid: bool = mod.can_place_at(cell)
			var pos: Vector2 = Vector2(cell * GameWorld.CELL)
			var sz: Vector2 = Vector2(mod.BATT_SIZE * GameWorld.CELL)
			var fill_col: Color = Color(0.2, 1.0, 0.3, 0.25) if valid else Color(1.0, 0.25, 0.25, 0.25)
			var line_col: Color = Color(0.2, 1.0, 0.3, 0.95) if valid else Color(1.0, 0.25, 0.25, 0.95)
			draw_rect(Rect2(pos, sz), fill_col)
			draw_rect(Rect2(pos, sz), line_col, false, 2.0)
			draw_arc(pos + sz * 0.5, mod.RANGE_MAX, 0.0, TAU, 96, Color(line_col.r, line_col.g, line_col.b, 0.22), 1.0)
		mod.draw_targeting(self, mouse_w)
		mod.draw_rings(self)
		if mod.fx_sys != null:
			mod.fx_sys.draw_normal(self)
		mod.draw_rockets(self)

class ThermoGlowLayer extends Node2D:
	var mod = null

	func setup(p_mod) -> void:
		mod = p_mod
		z_index = 10
		var mat: CanvasItemMaterial = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _draw() -> void:
		if mod == null:
			return
		mod.draw_glow(self)
