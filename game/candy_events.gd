class_name CandyEvents
extends RefCounted
## «Летающая конфетка» — менеджер пасхального события.
##
## Детерминированное расписание от seed мира: оба пира в мультиплеере видят
## одну и ту же конфетку в одно и то же время, без сетевых сообщений.
## Награда начисляется только в одиночной игре (в MP — визуал и тост),
## чтобы не рисковать рассинхроном экономики.
## Если нативное расширение df_rust не загрузилось — используется
## GDScript-фолбэк (FlyingCandyGd), логика идентична.

const SLOT_LEN: float = 240.0        # окно появления: раз в 4 минуты игры
const FLIGHT_DUR: float = 16.0       # длительность полёта через карту
const SPAWN_OFFSET_MIN: float = 40.0 # минимум внутри слота
const CHANCE_PCT: int = 60           # шанс появления в слоте
const REWARD: int = 1500
const HIT_R: float = 34.0            # радиус клика в экранных пикселях

const CANDY_SEED_A: int = 9901
const CANDY_SEED_B: int = 9902

var gw: Variant = null
var node: Node2D = null
var slot_active: int = -1


func _init(gw_ref: Variant) -> void:
	gw = gw_ref


## Вызывается из GameWorld._sim_step рядом с drama.update.
func update(_dt: float) -> void:
	if gw == null or not is_instance_valid(gw):
		return
	var main: Node = gw.get_parent() if gw.get_parent() != null else null
	if gw.session == null or not gw.session.started:
		_clear()
		return
	if gw.player == null or gw.player.eliminated:
		_clear()
		return
	if main != null and (bool(main.get("in_menu")) or main.has_meta("verify_game")):
		_clear()
		return

	var t: float = gw.game_time
	var slot := int(t / SLOT_LEN)
	var demo: bool = main != null and main.has_meta("candy_demo")
	var h: int = absi(Hash32.h2(_seed(), slot, CANDY_SEED_A))
	var want: bool = demo or (h % 100) < CHANCE_PCT
	var t0: float = slot_t0(_seed(), slot, demo)

	if want and t >= t0 and t <= t0 + FLIGHT_DUR:
		if node == null or not is_instance_valid(node) or slot_active != slot:
			_spawn(slot, demo)
	else:
		_clear()


## Время старта полёта внутри слота (детерминированно).
static func slot_t0(seed_v: int, slot: int, demo: bool) -> float:
	if demo and slot == 0:
		return 25.0
	var h: int = absi(Hash32.h2(seed_v, slot, CANDY_SEED_B))
	return float(slot) * SLOT_LEN + SPAWN_OFFSET_MIN + float(h % 90)


## Попала ли конфетка под тап; возвращает true, если тап поглощён.
func try_click(screen_pos: Vector2) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var vp: Vector2 = node.call("visual_world_pos")
	var main: Node = gw.get_parent() if gw.get_parent() != null else null
	if main == null or main.get("cam") == null:
		return false
	var sp: Vector2 = main.cam.world_to_screen(vp)
	if sp.distance_to(screen_pos) > HIT_R:
		return false
	_pop()
	return true


func _spawn(slot: int, demo: bool) -> void:
	_clear()
	slot_active = slot
	var cap_pos: Vector2 = _capital_pos()
	var h: int = absi(Hash32.h2(_seed(), slot, CANDY_SEED_B))
	var jitter: float = float(h % 160) - 80.0
	var start: Vector2 = cap_pos + Vector2(-620.0, jitter)
	var end: Vector2 = cap_pos + Vector2(620.0, jitter * 0.4 - 40.0)

	if ClassDB.class_exists("DfFlyingCandy"):
		node = ClassDB.instantiate("DfFlyingCandy")
	else:
		node = (load("res://game/flying_candy_gd.gd") as GDScript).new()
	node.set("start", start)
	node.set("end", end)
	node.set("height", 14.0)
	node.set("duration", FLIGHT_DUR)
	node.set("phase", float(h % 628) / 100.0)
	gw.add_child(node)
	if demo:
		print("[Candy] демо-конфетка вылетела: ", start, " -> ", end)


func _clear() -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
	node = null
	slot_active = -1


func _pop() -> void:
	var at: Vector2 = node.call("visual_world_pos")
	var main: Node = gw.get_parent() if gw.get_parent() != null else null
	_clear()

	# Конфетти.
	var parts := CPUParticles2D.new()
	parts.amount = 46
	parts.lifetime = 1.5
	parts.one_shot = true
	parts.explosiveness = 1.0
	parts.spread = 180.0
	parts.gravity = Vector2(0, 260)
	parts.initial_velocity_min = 60.0
	parts.initial_velocity_max = 170.0
	parts.scale_amount_min = 2.0
	parts.scale_amount_max = 4.5
	parts.hue_variation_min = -0.5
	parts.hue_variation_max = 0.5
	parts.color = Color(1.0, 0.55, 0.72)
	parts.position = at.round()
	parts.emitting = true
	gw.add_child(parts)
	gw._delay(2.5, func() -> void:
		if is_instance_valid(parts):
			parts.queue_free())

	if gw.fx != null:
		gw.fx.spawn("intercept_flash", at.round(), 6)
	Sfx.play("ui_build", at)
	if main != null and main.get("overlay") != null:
		main.overlay.ripple(at, "intercept_cyan")

	var sp_only: bool = gw.net_driven
	if not sp_only and gw.player != null and not gw.player.eliminated:
		gw.player.add_money(REWARD)
		if main != null and main.get("hud") != null:
			main.hud.show_toast(Loc.msg(Loc.mk("Летающая конфетка сбита: +%d к казне", [REWARD])))
	else:
		if main != null and main.get("hud") != null:
			main.hud.show_toast(Loc.msg(Loc.mk("Летающая конфетка сбита! Бонус казны — только в одиночной игре", [])))


func _seed() -> int:
	if gw.data != null:
		return int(gw.data.world_seed)
	return 1


func _capital_pos() -> Vector2:
	if gw.player != null and gw.player.capital_id >= 0 and gw.player.capital_id < int(gw.cities.size()):
		var cap: Variant = gw.cities[gw.player.capital_id]
		if cap != null:
			return Vector2(cap.center) * GameWorld.CELL
	return Vector2(512.0, 512.0)
