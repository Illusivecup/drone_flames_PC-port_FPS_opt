class_name Army
extends RefCounted






const SPEC: Array = [
        {"name": "ТАНК", "hp": 120.0, "speed": 13.0, "range": 75.0, "dmg": 30.0, "cd": 2.6, "cost": 450, "ti": 8, "food": 0, "time": 22.0, "sprite": "tank", "hit": 70}, 
        {"name": "ПЕХОТА", "hp": 45.0, "speed": 8.5, "range": 42.0, "dmg": 6.0, "cd": 1.1, "cost": 150, "ti": 0, "food": 4, "time": 10.0, "sprite": "infantry", "hit": 55}, 
        {"name": "FPV", "hp": 1.0, "speed": 46.0, "range": 0.0, "dmg": 70.0, "cd": 0.0, "cost": 0, "ti": 0, "food": 0, "time": 0.0, "sprite": "fpv", "hit": 80}, 
        {"name": "ПТУР", "hp": 35.0, "speed": 7.0, "range": 230.0, "dmg": 110.0, "cd": 9.0, "cost": 350, "ti": 2, "food": 4, "time": 16.0, "sprite": "atgm_team", "hit": 80}, 
        {"name": "ШТУРМ", "hp": 60.0, "speed": 10.0, "range": 46.0, "dmg": 7.0, "cd": 0.9, "cost": 260, "ti": 0, "food": 5, "time": 12.0, "sprite": "assault_squad", "hit": 60}, 
        {"name": "БМП", "hp": 80.0, "speed": 16.0, "range": 72.0, "dmg": 8.0, "cd": 0.55, "cost": 320, "ti": 4, "food": 0, "time": 18.0, "sprite": "ifv", "hit": 55}, 
        {"name": "МИНОМЁТ", "hp": 30.0, "speed": 7.0, "range": 300.0, "dmg": 24.0, "cd": 6.5, "cost": 220, "ti": 0, "food": 3, "time": 12.0, "sprite": "mortar_team", "hit": 0, "min": 45.0, "blast": 9.0}, 
        {"name": "ГАУБИЦА", "hp": 60.0, "speed": 9.0, "range": 700.0, "dmg": 50.0, "cd": 10.0, "cost": 600, "ti": 6, "food": 0, "time": 26.0, "sprite": "howitzer", "hit": 0, "min": 90.0, "blast": 13.0}, 
        {"name": "РСЗО", "hp": 60.0, "speed": 14.0, "range": 950.0, "dmg": 22.0, "cd": 45.0, "cost": 900, "ti": 10, "food": 0, "time": 34.0, "sprite": "mlrs", "hit": 0, "min": 160.0, "blast": 11.0, "salvo": 12}, 
        {"name": "РАЗВЕДКА", "hp": 8.0, "speed": 30.0, "range": 0.0, "dmg": 0.0, "cd": 0.0, "cost": 120, "ti": 0, "food": 0, "time": 8.0, "sprite": "recon_drone", "hit": 0}, 
        {"name": "ПОЛИЦИЯ", "hp": 50.0, "speed": 20.0, "range": 80.0, "dmg": 6.0, "cd": 1.1, "cost": 100, "ti": 0, "food": 0, "time": 0.0, "sprite": "ifv", "hit": 55},
]

const TYPE_KEY: Array[String] = ["tank", "infantry", "fpv", "atgm", "assault", "ifv", "mortar", "arty", "mlrs", "recon", "police"]



const BUILDS: Array = [
        {"id": "mix", "name": "МИКС", "title": "Смешанная армия", "icon": "icon_doctrine", "style": "mix", "recon": 0, "fpv": 0, "smoke": false, 
                "desc": "Танк, два отделения и ПТУР по кругу. Прежний состав казарм.", "comp": []}, 
        {"id": "assault", "name": "ШТУРМ", "title": "Штурмовой спецназ", "icon": "icon_build_assault", "style": "assault", "recon": 1, "fpv": 1, "smoke": true, 
                "desc": "Штурмовые группы с гранатами и дымами, FPV, БМП и миномёты. Перебежками от укрытия к укрытию, рывок под дымом.", 
                "comp": [[Unit.Type.ASSAULT, 7], [Unit.Type.INFANTRY, 2], [Unit.Type.MORTAR, 2], [Unit.Type.IFV, 1]]}, 
        {"id": "motor", "name": "МОТОПЕХОТА", "title": "Мотострелки", "icon": "icon_build_motor", "style": "motor", "recon": 0, "fpv": 0, "smoke": true, 
                "desc": "Сбалансированно: пехота с РПГ, БМП, два танка, ПТУР и миномёты.", 
                "comp": [[Unit.Type.INFANTRY, 5], [Unit.Type.TANK, 2], [Unit.Type.IFV, 2], [Unit.Type.MORTAR, 2], [Unit.Type.ATGM, 1]]}, 
        {"id": "at", "name": "ПТ-ОБОРОНА", "title": "Противотанковая оборона", "icon": "icon_build_at", "style": "at", "recon": 1, "fpv": 0, "smoke": false, 
                "desc": "ПТУР и РПГ, быстро окапываются и сами занимают окопы у казарм. Держат танки.", 
                "comp": [[Unit.Type.ATGM, 4], [Unit.Type.INFANTRY, 5], [Unit.Type.MORTAR, 2], [Unit.Type.IFV, 1]]}, 
        {"id": "support", "name": "ПОДДЕРЖКА", "title": "Огневая поддержка", "icon": "icon_build_support", "style": "support", "recon": 2, "fpv": 0, "smoke": false, 
                "desc": "Миномёты, гаубицы и РСЗО с разведкой. Не штурмуют: бьют по целям, которые видят свои, и сами отвечают на вызовы других казарм.", 
                "comp": [[Unit.Type.MORTAR, 3], [Unit.Type.ARTY, 3], [Unit.Type.MLRS, 2], [Unit.Type.INFANTRY, 3], [Unit.Type.IFV, 1]]}, 
        {"id": "armor", "name": "ТАНКОВАЯ", "title": "Танковый кулак", "icon": "icon_build_armor", "style": "armor", "recon": 1, "fpv": 0, "smoke": true, 
                "desc": "Шесть танков, БМП и штурмовики сопровождения. Быстро, громко, дорого.", 
                "comp": [[Unit.Type.TANK, 6], [Unit.Type.IFV, 3], [Unit.Type.ASSAULT, 2], [Unit.Type.MORTAR, 1]]}, 
]
const GREN_R: float = 32.0
const GREN_CD: float = 9.0
const GREN_DMG: float = 26.0
const SMOKE_LIFE: float = 14.0
const DIG_T: float = 9.0
const ArmyTac = preload("res://game/army_tac.gd")
const ArmyFire = preload("res://game/army_fire.gd")
const RPG_R: float = 70.0
const RPG_CD: float = 7.0
const RPG_DMG: float = 55.0
const ROCKET_SPEED: Dictionary = {"rpg": 95.0, "atgm": 58.0}
const TRENCH_ARMOR: float = 0.5
const TRENCH_VS_FPV: float = 1.3
const TRENCH_VS_ARTY: float = 0.9
const PIN_T: float = 5.5
const PIN_MAX: float = 6.0
const PIN_SLOW: float = 3.3
const FLANK_COS: float = 0.5
var pin_until: Dictionary = {}
const ORDER_OUT: float = 10000000.0
const NEAR_POST: float = 260.0
const TRENCH_RANGE: float = 1.08
const FPV_MAX: int = 2
const BARRACKS_CAP: int = 12
const FPV_R: float = 170.0
const FPV_CD: float = 40.0
const FPV_LIFE: float = 14.0
const FPV_LOCK_R: float = FPV_R * 1.3
const FPV_FALL: float = 0.8
const SIEGE_CAPTURE: float = 8.0
const GARRISON_REGEN: float = 2.0
const GARRISON_CALM: float = 30.0
const GARRISON_DMG: float = 3.2
const CAP_T: Array = [60.0, 35.0, 25.0]
const CAP_GW: Array = [12.0, 8.0, 4.0]
const CAP_DRAIN: float = 2.0
const CAP_DECAY_T: float = 40.0
const REFILL_SLOW: float = 1.25

const UNIT_ICONS: Array[String] = ["icon_tank", "icon_infantry", "icon_infantry", "icon_atgm", "icon_build_assault", "icon_build_motor", "icon_mortar", "icon_arty", "icon_mlrs", "icon_recon_drone", "icon_barracks"]

const LOC_RES_GEN: Dictionary = {"money": "денег", "food": "еды", "titanium": "титана", "metal": "металла", "wood": "дерева", "oil": "нефти", 
        "precious": "драгметаллов", "fuel": "топлива", "goods": "товаров"}

var gw: GameWorld
var units: Array[Unit] = []
var arrows: Array = []
var shells: Array = []
var _next_id: int = 1
var _police_tick_t: float = 0.0
var _scan_t: float = 0.0
var _acq_flip: bool = false
var _siege_acc: float = 0.0
var rockets: Array = []
var _rid: int = 1
var _post_t: float = 0.0
var tac: ArmyTac
var wait_reason: Dictionary = {}
var fire: ArmyFire
var reinf = preload("res://game/army_reinf.gd").new(self)
var smokes: Array = []
var grenades: Array = []
const GRID_PX: float = 128.0
var _grid: Dictionary = {}
# Для быстрого поиска целей: битовые маски стран в ячейках сетки и «врагов» каждой страны.
# Пересобираются вместе с _grid (раз в скан), поэтому всегда согласованы с ним.
var _gmask: Dictionary = {}
var _hmask_cache: Dictionary = {}
# Нативный ускоритель поиска целей (addons/df_native, Rust GDExtension).
# null, если расширение не собрано под платформу — тогда игра идёт по
# прежнему GDScript-пути без изменений поведения.
var _nat: Object = null
var _nat_u: Dictionary = {}
const _NO_UNITS: Array = []
const _NO_FACS: Array = []
var _fgrid: Dictionary = {}
var _flines: Array = []
var _fgrid_t: float = -99.0
var _fpv_fly: Dictionary = {}
var _fpv_b: Dictionary = {}
var post_fixes: int = 0
var occupy_why: String = ""
static var occupy_m: Variant = ""

var front_dig: bool = false
var _occ: Dictionary = {}


func _init(world: GameWorld) -> void :
        gw = world
        tac = ArmyTac.new(self)
        fire = ArmyFire.new(self)
        _nat_init()


# Подключение нативного ускорителя (Rust). Только если GDExtension собран
# под текущую платформу; ClassDB.instantiate, чтобы скрипт не ломался при
# отсутствии библиотеки.
func _nat_init() -> void :
        if ClassDB.class_exists("DfNative"):
                _nat = ClassDB.instantiate("DfNative")


func count_units(country_id: int) -> int:
        var n: int = 0
        for u: Unit in units:
                if u.country_id == country_id and u.alive() and u.type != Unit.Type.FPV:
                        n += 1
        if gw.naval != null:
                n += gw.naval.aboard_n(country_id)
        return n


func idle_units(country_id: int) -> Array[Unit]:
        var out: Array[Unit] = []
        for u: Unit in units:
                if u.country_id == country_id and u.alive() and u.type != Unit.Type.FPV and u.post == null and not u.op_on and (u.state == Unit.State.IDLE or u.target_city < 0):
                        out.append(u)
        return out





func _train(dt: float) -> void :
        var mil: Military = gw.mil
        var counts: Dictionary = {}
        var counted: bool = false
        for f: Facility in mil.facilities:
                if f.kind == Facility.Kind.BARRACKS and f.army_no == 0:
                        _number(f)
                if (f.halted or f.mb) and f.kind == Facility.Kind.BARRACKS:
                        continue
                if f.kind != Facility.Kind.BARRACKS or not mil.alive(f) or f.prod_type == 3:
                        if f.kind == Facility.Kind.BARRACKS:
                                f.producing = false
                        continue
                var c: Country = gw.country_by_id(f.country_id)
                if not f.producing:
                        if not counted:
                                counted = true
                                for u: Unit in units:
                                        if u.home != null and u.alive() and u.type != Unit.Type.FPV:
                                                counts[u.home] = int(counts.get(u.home, 0)) + 1
                                if gw.naval != null:
                                        gw.naval.add_counts(counts)
                        var n: int = int(counts.get(f, 0))
                        if n >= BARRACKS_CAP - (0 if c.is_player else GameConfig.ai_cap_cut(gw.game_time)):
                                f.filled = true
                                continue
                        _ensure_build(f, c)
                        var t: int = _next_type(f)
                        if t < 0:
                                f.filled = true
                                continue
                        if f.filled and not refill_on(f):
                                wait_reason.erase(f)
                                continue
                        var cost: Dictionary = unit_cost(t)
                        if not c.has_res(cost):
                                var t2: int = _affordable_alt(f, c, t)
                                if t2 < 0:
                                        wait_reason[f] = Loc.mk("НЕ ХВАТАЕТ: {miss}", {"miss": c.missing_res(cost), "res": c.first_missing(cost)})
                                        continue
                                t = t2
                                cost = unit_cost(t)

                        var buf: int = food_buffer(c)
                        if gw.econ != null:
                                buf = mini(buf, gw.econ.res_cap(c, "food") / 2)
                        if c.food < buf + int(cost.get("food", 0)):
                                wait_reason[f] = Loc.mk("НЕ ХВАТАЕТ: {miss}", {"miss": Loc.mk("еда %d", [buf + int(cost.get("food", 0)) - c.food]), "res": "food"})
                                continue
                        wait_reason.erase(f)
                        c.pay_res(cost)
                        _stat_spend(c, cost)
                        f.producing = true
                        f.prod_refill = f.filled
                        f.prod_t = 0.0
                        f.queued = [t]
                f.prod_t += dt * (gw.ops.refill_boost(f) if gw.ops != null else 1.0)
                var tt: int = int(f.queued[0]) if not f.queued.is_empty() else Unit.Type.INFANTRY
                if f.prod_t >= float(SPEC[tt]["time"]) * (REFILL_SLOW if f.prod_refill else 1.0):
                        f.producing = false
                        f.prod_t = 0.0
                        _spawn(f, tt)


func _next_type(f: Facility) -> int:
        if f.prod_type == 0 and f.army_build != "" and f.army_build != "mix":
                var need: Array = _shortage(f)
                return int(need[0]) if not need.is_empty() else -1
        if f.prod_type == 1:
                return Unit.Type.TANK
        if f.prod_type == 2:
                return Unit.Type.INFANTRY
        if f.prod_type == 4:
                return Unit.Type.ATGM
        var tanks: int = 0
        var inf: int = 0
        var atgm: int = 0
        for u: Unit in units:
                if u.home == f and u.alive():
                        if u.type == Unit.Type.TANK:
                                tanks += 1
                        elif u.type == Unit.Type.INFANTRY:
                                inf += 1
                        elif u.type == Unit.Type.ATGM:
                                atgm += 1

        if atgm * 2 < inf - 1:
                return Unit.Type.ATGM
        return Unit.Type.TANK if tanks * 2 < inf + 1 else Unit.Type.INFANTRY


func barracks_out(f: Facility) -> Vector2:
        var info: Dictionary = gw.mil._info("barracks")
        if f.main_obj >= 0 and info.has("out"):
                return gw.mil.local_px(f.main_obj, info["out"]) + Vector2(0, 6)
        return f.center_px() + Vector2(0, f.size.y * 2 + 4)


func _spawn(f: Facility, t: int) -> Unit:
        var u: = Unit.new()
        u.id = _next_id
        _next_id += 1
        u.type = t
        u.country_id = f.country_id
        u.home = f
        u.hp = float(SPEC[t]["hp"])
        u.max_hp = u.hp
        u.pos = gw.econ.land_point(barracks_out(f))
        u.kit = _kit_for(f, t)
        var k: int = u.id % 12
        u.slot = Vector2((k % 4 - 1.5) * 9.0, float(k / 4) * 9.0 + 6.0)
        u.slot = gw.econ.land_point(u.pos + u.slot) - u.pos
        if gw.diplo != null and gw.ops != null and not gw.diplo.may_cross(u.country_id, gw.ops._owner_at(u.pos + u.slot)):
                u.slot = Vector2.ZERO
        u.heading = PI * 0.5
        u.update_frame()

        u.path = PackedVector2Array([u.pos + u.slot])
        u.pi = 0
        u.state = Unit.State.MOVE
        units.append(u)
        if gw.country_by_id(f.country_id).is_player and gw._on_screen(u.pos, 40.0):
                gw.fx.spawn("dust_s", u.pos.round(), 5)
        return u





func order_attack(country_id: int, city: City, only: Facility = null) -> int:
        var sel: Array[Unit] = []
        var oc: Country = gw.country_by_id(country_id)
        if only != null and oc != null and oc.is_player:
                release_posts(only)
        var bot0: Country = gw.country_by_id(country_id)
        var keep_sea: bool = only == null and bot0 != null and not bot0.is_player and gw.naval != null and not gw.naval.landings.is_empty()
        for u: Unit in units:
                if u.country_id != country_id or not u.alive() or u.type == Unit.Type.FPV:
                        continue
                if only != null and u.home != only:
                        continue
                if keep_sea and u.home != null and gw.naval.busy(u.home):
                        continue
                if u.post != null:
                        continue
                if u.target_city >= 0 and u.target_city != city.id and u.state == Unit.State.SIEGE:
                        continue
                sel.append(u)
        if sel.is_empty():
                return 0
        if city.country_id != country_id and gw.diplo != null and not gw.diplo.at_war(country_id, city.country_id)\
        and not gw.diplo.war_block(country_id, city.country_id).is_empty():
                gw.diplo.declare_war(country_id, city.country_id, "наступление на %s" % [city.name])
                return 0
        var cen: = Vector2.ZERO
        for u: Unit in sel:
                cen += u.pos
        cen /= float(sel.size())
        var goal: Vector2 = Vector2(city.center * GameWorld.CELL)

        var groups: Dictionary = {}
        for u: Unit in sel:
                if u.home != null and gw.mil.facilities.has(u.home):
                        if not groups.has(u.home):
                                groups[u.home] = [] as Array[Unit]
                        (groups[u.home] as Array[Unit]).append(u)
        var loose: Array[Unit] = []
        for u: Unit in sel:
                if u.home == null or not groups.has(u.home):
                        loose.append(u)
        var me0: Country = gw.country_by_id(country_id)
        for h: Facility in groups:
                if me0 != null and not me0.is_player and h.army_build == "at" and only == null:
                        continue
                if me0 != null and not me0.is_player and gw.rail != null and gw.rail.troops != null and gw.rail.troops.bot_ride(h, groups[h], city):
                        continue
                if not tac.start(h, groups[h], city):
                        loose.append_array(groups[h])
        var base_path: PackedVector2Array = gw.econ.nav_path(cen, goal) if not loose.is_empty() else PackedVector2Array()
        if not loose.is_empty():
                var fpg: GDScript = load("res://game/front_plan.gd")
                if bool(fpg.call("closed_path", gw, country_id, base_path)):
                        loose.clear()
        var k: int = 0
        for u: Unit in loose:
                u.target_city = city.id
                u.state = Unit.State.MOVE

                var off: = Vector2((k % 4 - 1.5) * 8.0, float(k / 4) * 8.0)
                var p: = PackedVector2Array()
                for q: Vector2 in base_path:
                        p.append(safe_point(q, off))
                u.path = p
                u.pi = 0
                k += 1
        arrows.append({"c": country_id, "from": cen, "to": goal, "t": gw.game_time, "city": city.id})
        var me: Country = gw.country_by_id(country_id)
        if city.country_id != country_id and not gw.diplo.at_war(country_id, city.country_id):
                gw.diplo.declare_war(country_id, city.country_id, "наступление на %s" % [city.name])
        if me.is_player:
                gw.say(me, Loc.mk("Наступление на %s: %d ед.", [Loc.name(city.name), sel.size()]))
        return sel.size()


func order_hold(country_id: int) -> void :
        tac.stop_country(country_id)
        for u: Unit in units:
                if u.country_id == country_id and u.alive() and u.type != Unit.Type.FPV and u.post == null:
                        u.target_city = -1
                        u.path = PackedVector2Array()
                        u.state = Unit.State.IDLE




func _pf2(nm: String, t0: int) -> void :
        if not GameWorld.perf_prof:
                return
        var d: float = float(Time.get_ticks_usec() - t0) / 1000.0
        if d > float(gw.perf_sys.get(nm, 0.0)):
                gw.perf_sys[nm] = d


func _pfv(nm: String, ms: float) -> void :
        if not GameWorld.perf_prof:
                return
        if ms > float(gw.perf_sys.get(nm, 0.0)):
                gw.perf_sys[nm] = ms


func update(dt: float) -> void :

        var _u0: int = Time.get_ticks_usec()
        _train(dt)
        _pf2("army:_train", _u0)
        _scan_t -= dt
        var scan: bool = _scan_t <= 0.0
        if scan:
                _scan_t = 0.25
                _u0 = Time.get_ticks_usec()
                _build_grid()
                _pf2("army:_build_grid", _u0)
                # Стаггеринг поиска целей: за скан обрабатывается половина юнитов
                # (чётные/нечётные id), каждый юнит ищет цель раз в 0.5 c вместо
                # 0.25 c. Стоимость _acquire падает вдвое, на геймплей незаметно.
                _acq_flip = not _acq_flip
                if pin_until.size() > 48:
                        for k: int in pin_until.keys():
                                if float(pin_until[k]) <= gw.game_time:
                                        pin_until.erase(k)
        _u0 = Time.get_ticks_usec()
        var acc_adv: float = 0.0
        var acc_fig: float = 0.0
        var acc_fpv: float = 0.0
        var t0i: int = 0
        for u: Unit in units:
                if not u.alive():
                        continue
                if u.type == Unit.Type.FPV:
                        _fpv(u, dt)
                        continue
                u.fire_cd -= dt
                u.gren_cd -= dt
                u.supp = maxf(0.0, u.supp - dt * 0.3)
                var p0: Vector2 = u.pos
                if u.indirect():
                        t0i = Time.get_ticks_usec()
                        _advance(u, dt)
                        acc_adv += float(Time.get_ticks_usec() - t0i) / 1000.0
                else:
                        var already_valid: bool = false
                        if scan:
                                if u.target != null and _valid(u, u.target):
                                        already_valid = true
                                elif (u.id & 1) == (1 if _acq_flip else 0):
                                        already_valid = _acquire(u)
                        var tgt: Object = u.target
                        if tgt != null and not already_valid and not _valid(u, tgt):
                                u.target = null
                                tgt = null
                        if tgt != null and not u.op_move and not (u.post != null and not u.entrenched and u.pi < u.path.size()):
                                t0i = Time.get_ticks_usec()
                                _fight(u, tgt, dt)
                                acc_fig += float(Time.get_ticks_usec() - t0i) / 1000.0
                        else:
                                t0i = Time.get_ticks_usec()
                                _advance(u, dt)
                                acc_adv += float(Time.get_ticks_usec() - t0i) / 1000.0
                                if tgt != null and u.op_move:
                                        _fire_moving(u, tgt)
                if u.pos == p0:
                        u.still_t += dt
                        if not u.dug and u.foot() and u.post == null and u.still_t >= _dig_time(u):
                                u.dug = true
                if u.type == Unit.Type.INFANTRY or u.type == Unit.Type.ASSAULT:
                        u.rpg_cd -= dt
                        t0i = Time.get_ticks_usec()
                        _maybe_fpv(u, dt)
                        acc_fpv += float(Time.get_ticks_usec() - t0i) / 1000.0
        _pfv("army:_advance", acc_adv)
        _pfv("army:_fight", acc_fig)
        _pfv("army:_maybe_fpv", acc_fpv)
        _pf2("army:units_loop", _u0)
        _u0 = Time.get_ticks_usec()
        _update_shells(dt)
        _pf2("army:shells", _u0)
        _u0 = Time.get_ticks_usec()
        _update_rockets(dt)
        _pf2("army:rockets", _u0)
        _u0 = Time.get_ticks_usec()
        _update_grenades(dt)
        _pf2("army:grenades", _u0)
        _u0 = Time.get_ticks_usec()
        tac.update(dt)
        _pf2("army:tac", _u0)
        _u0 = Time.get_ticks_usec()
        reinf.tick(dt)
        _pf2("army:reinf", _u0)
        _u0 = Time.get_ticks_usec()
        fire.update(dt)
        _pf2("army:fire", _u0)
        for k2 in range(smokes.size() - 1, -1, -1):
                if gw.game_time >= float(smokes[k2][1]):
                        smokes.remove_at(k2)
        _post_t += dt
        if _post_t >= 1.0:
                _u0 = Time.get_ticks_usec()
                _posts(_post_t)
                _pf2("army:_posts", _u0)
                _post_t = 0.0
        _police_tick_t += dt
        if _police_tick_t >= 1.0:
                _police_tick_t = 0.0
                _u0 = Time.get_ticks_usec()
                _police_patrol_tick()
                _pf2("army:police", _u0)
        _siege_acc += dt
        if _siege_acc >= 0.2:
                _u0 = Time.get_ticks_usec()
                _sieges(_siege_acc)
                _pf2("army:sieges", _u0)
                _siege_acc = 0.0
        _u0 = Time.get_ticks_usec()
        for k in range(units.size() - 1, -1, -1):
                var u: Unit = units[k]
                if u.state == Unit.State.DEAD and gw.game_time - u.dead_t > 0.5:
                        units.remove_at(k)
        for k in range(arrows.size() - 1, -1, -1):
                if gw.game_time - float(arrows[k]["t"]) > 6.0:
                        arrows.remove_at(k)
        _pf2("army:cleanup", _u0)


func _hostile(a: int, b: int) -> bool:
        if a == b:
                return false
        var c: Country = gw.country_by_id(a)
        return c != null and c.at_war.has(b)


func police_count(station: Facility) -> int:
        var count: int = 0
        for unit: Unit in units:
                if unit.type == Unit.Type.POLICE and unit.home == station and unit.country_id == station.country_id and unit.alive():
                        count += 1
        return count


func toggle_police_patrol(station: Facility) -> void:
        if station == null or station.kind != Facility.Kind.POLICE_STATION or not gw.mil.alive(station):
                return
        station.police_patrol = not station.police_patrol
        if station.police_patrol:
                var missing: int = maxi(0, 4 - police_count(station))
                for i: int in missing:
                        var unit: Unit = Unit.new()
                        unit.id = _next_id
                        _next_id += 1
                        unit.type = Unit.Type.POLICE
                        unit.country_id = station.country_id
                        unit.home = station
                        unit.max_hp = float(SPEC[Unit.Type.POLICE]["hp"])
                        unit.hp = unit.max_hp
                        unit.pos = Vector2((station.cell + Vector2i(station.size.x / 2, station.size.y + 1)) * GameWorld.CELL)
                        unit.heading = PI * 0.5
                        units.append(unit)
        else:
                for unit: Unit in units:
                        if unit.type == Unit.Type.POLICE and unit.home == station:
                                unit.path.clear()
                                unit.pi = 0


func _police_patrol_tick() -> void:
        if gw.data == null or gw.econ == null:
                return
        for unit: Unit in units:
                if unit.type != Unit.Type.POLICE or not unit.alive():
                        continue
                var station: Facility = unit.home
                if station == null or not gw.mil.facilities.has(station) or station.country_id != unit.country_id or not gw.mil.alive(station) or not station.police_patrol:
                        unit.path.clear()
                        unit.pi = 0
                        continue
                if unit.target != null or unit.pi < unit.path.size():
                        continue
                for attempt: int in 12:
                        var cell: Vector2i = station.cell + Vector2i(randi_range(-24, 24), randi_range(-24, 24))
                        if not gw.data.inside(cell.x, cell.y) or gw.data.get_owner_id(cell.x, cell.y) != unit.country_id or Biome.is_water(gw.data.get_biome(cell.x, cell.y)):
                                continue
                        var destination: Vector2 = Vector2(cell * GameWorld.CELL)
                        var route: PackedVector2Array = gw.econ.nav_path(unit.pos, destination)
                        if not route.is_empty():
                                unit.path = route
                                unit.pi = 0
                                unit.state = Unit.State.MOVE
                                break


func range_of(u: Unit) -> float:
        return float(SPEC[u.type]["range"]) * (TRENCH_RANGE if u.entrenched else 1.0)


func _valid(u: Unit, t: Object) -> bool:
        if t is Unit:
                var tu: Unit = t
                var td: float = tu.pos.distance_to(u.pos)

                return tu.alive() and (_hostile(u.country_id, tu.country_id) or _guard_foe(u, tu)) and td <= range_of(u) * 1.15 and (td < 28.0 or not in_smoke(tu.pos))
        if t is Facility:
                return gw.mil.alive(t as Facility) and _hostile(u.country_id, (t as Facility).country_id) and _target_pos(t, u.pos).distance_to(u.pos) <= float(SPEC[u.type]["range"]) * 1.3
        return false



func _hmask(cid: int) -> int:
        var v: Variant = _hmask_cache.get(cid)
        if v != null:
                return int(v)
        var m: int = 0
        var c: Country = gw.country_by_id(cid)
        if c != null:
                for k: Variant in c.at_war:
                        var kid: int = int(k)
                        if kid < 0 or kid >= 63:
                                m = -1
                                break
                        m |= 1 << kid
        _hmask_cache[cid] = m
        return m


func _acquire(u: Unit) -> bool :
        if u.target != null and _valid(u, u.target):
                return true
        var me: Country = gw.country_by_id(u.country_id)
        var grd: bool = gw.diplo != null and gw.diplo.rq != null and gw.diplo.rq.guarding(u.country_id)
        if me == null or (me.at_war.is_empty() and not grd):
                u.target = null
                return false
        var r: float = range_of(u)
        var best: Object = null
        var bd: float = r * r
        var at: bool = u.type == Unit.Type.ATGM
        var blind: bool = in_smoke(u.pos)
        var ucid: int = u.country_id
        var upos: Vector2 = u.pos
        var hm: int = _hmask(ucid)
        # Нативный путь (Rust, addons/df_native): юнит-пасс по снапшоту из _build_grid.
        # nat: <=-2 — нужен полный GDScript-проход, -1 — юнитов-целей нет, >=0 — id цели.
        var nat: int = -3
        if _nat != null and not grd and hm != -1:
                nat = _nat.acquire_one(u.id, r, hm, at, blind)
                if nat >= 0:
                        var tu: Unit = _nat_u.get(nat)
                        # цель могла умереть после снапшота — тогда честный перепросмотр
                        if tu != null and tu.state != Unit.State.DEAD:
                                best = tu
                        else:
                                nat = -3
        if nat <= -2:
                best = _acq_units_gd(u, r, at, blind, ucid, upos, hm, grd)
        # ——— здания: только если юнит-цель не найдена (как раньше) ———
        var storming: bool = u.op_on and ( not u.op_hold or u.pi < u.path.size())
        if best == null and not storming and (u.type == Unit.Type.TANK or u.type == Unit.Type.IFV or at or (u.kit & Unit.KIT_GREN) != 0):
                bd = r * r * 1.3
                # Тот же порядок, что у _near_fac (сначала линии, затем ячейки), но без копии массива
                # и с проверкой вражды по маске страны.
                var fr: float = r + 64.0
                var fx0: int = floori((upos.x - fr) / GRID_PX)
                var fx1: int = floori((upos.x + fr) / GRID_PX)
                var fy0: int = floori((upos.y - fr) / GRID_PX)
                var fy1: int = floori((upos.y + fr) / GRID_PX)
                for pass_i in 2:
                        if pass_i == 0:
                                for f: Facility in _flines:
                                        var fc0: int = f.country_id
                                        var foe0: bool = ((hm >> fc0) & 1) == 1 if (hm != -1 and fc0 >= 0 and fc0 < 63) else _hostile(ucid, fc0)
                                        if f.parent != null or f.kind == Facility.Kind.TRENCH_H or not foe0 or not gw.mil.alive(f):
                                                continue
                                        var rr0: float = r + float(maxi(f.size.x, f.size.y)) * 4.0
                                        if f.center_px().distance_squared_to(upos) > rr0 * rr0:
                                                continue
                                        var d30: float = _target_pos(f, upos).distance_squared_to(upos)
                                        if d30 < bd:
                                                bd = d30
                                                best = f
                        else:
                                for fcy in range(fy0, fy1 + 1):
                                        for fcx in range(fx0, fx1 + 1):
                                                for f: Facility in _fgrid.get(Vector2i(fcx, fcy), _NO_FACS):
                                                        var fc1: int = f.country_id
                                                        var foe1: bool = ((hm >> fc1) & 1) == 1 if (hm != -1 and fc1 >= 0 and fc1 < 63) else _hostile(ucid, fc1)
                                                        if f.parent != null or f.kind == Facility.Kind.TRENCH_H or not foe1 or not gw.mil.alive(f):
                                                                continue
                                                        var rr1: float = r + float(maxi(f.size.x, f.size.y)) * 4.0
                                                        if f.center_px().distance_squared_to(upos) > rr1 * rr1:
                                                                continue
                                                        var d31: float = _target_pos(f, upos).distance_squared_to(upos)
                                                        if d31 < bd:
                                                                bd = d31
                                                                best = f
        u.target = best
        return best != null


# Юнит-пасс поиска цели-юнита на GDScript: fallback без натива и эталон parity
# для bench-acq. Тело 1:1 с прежним _acquire (до зданий).
func _acq_units_gd(u: Unit, r: float, at: bool, blind: bool, ucid: int, upos: Vector2, hm: int, grd: bool) -> Object:
        var best: Object = null
        var bd: float = r * r
        # Ячейку без юнитов враждебных стран можно пропустить целиком (если не «охрана»,
        # при ней подходят и не враждебные). Результат идентичен полному перебору.
        var skip_ok: bool = hm != -1 and not grd
        var gx0: int = floori((upos.x - r) / GRID_PX)
        var gx1: int = floori((upos.x + r) / GRID_PX)
        var gy0: int = floori((upos.y - r) / GRID_PX)
        var gy1: int = floori((upos.y + r) / GRID_PX)
        for cy in range(gy0, gy1 + 1):
                for cx in range(gx0, gx1 + 1):
                        var ck: = Vector2i(cx, cy)
                        if skip_ok and (int(_gmask.get(ck, 0)) & hm) == 0:
                                continue
                        for o: Unit in _grid.get(ck, _NO_UNITS):
                                if o.state == Unit.State.DEAD or o.type == Unit.Type.FPV or o.country_id == ucid:
                                        continue
                                if at and not o.vehicle():
                                        continue
                                var d2: float = o.pos.distance_squared_to(upos)
                                if d2 >= bd:
                                        continue
                                var oc: int = o.country_id
                                var foe: bool = ((hm >> oc) & 1) == 1 if (hm != -1 and oc >= 0 and oc < 63) else _hostile(ucid, oc)
                                if (foe or (grd and _guard_foe(u, o))) and (d2 < 784.0 or not (blind or in_smoke(o.pos))):
                                        bd = d2
                                        best = o
        return best


func _target_pos(t: Object, from: = Vector2.INF) -> Vector2:
        if t is Unit:
                return (t as Unit).pos
        var f: Facility = t
        if f.is_line() and from != Vector2.INF:
                return gw.mil.line_point(f, from)
        return f.center_px()


func _turn(u: Unit, want: float, rate: float) -> bool:
        var dd: float = wrapf(want - u.heading, - PI, PI)
        u.heading = wrapf(u.heading + clampf(dd, - rate, rate), - PI, PI)
        u.update_frame()
        return absf(dd) < 0.3


func _fight(u: Unit, t: Object, dt: float) -> void :
        var tp: Vector2 = _target_pos(t, u.pos)
        var aimed: bool = _turn(u, (tp - u.pos).angle(), PI * dt)
        if u.state != Unit.State.SIEGE:
                u.state = Unit.State.FIGHT
        if not aimed or u.fire_cd > 0.0:
                return
        var sp: Dictionary = SPEC[u.type]
        u.fire_cd = float(sp["cd"]) * (0.8 + float(Hash32.h2(u.id, int(gw.game_time * 3.0), 9) % 40) / 100.0) * (1.0 + u.supp)
        if pinned(u):
                u.fire_cd *= PIN_SLOW
        if (u.kit & Unit.KIT_GREN) != 0 and u.gren_cd <= 0.0 and u.pos.distance_to(tp) <= GREN_R:
                u.gren_cd = GREN_CD
                _throw_grenade(u, tp)
                return
        if u.type == Unit.Type.ATGM:
                _launch_rocket(u, t, "atgm", float(sp["dmg"]), int(sp["hit"]))
                return
        if (u.type == Unit.Type.INFANTRY or u.type == Unit.Type.ASSAULT) and t is Unit and (t as Unit).vehicle() and u.rpg_cd <= 0.0 and u.pos.distance_to(tp) <= RPG_R * (TRENCH_RANGE if u.entrenched else 1.0):
                u.rpg_cd = RPG_CD
                _launch_rocket(u, t, "rpg", RPG_DMG, 60)
                return
        _shoot(u, tp, t, float(sp["dmg"]), int(sp["hit"]))


func _shoot(u: Unit, tp: Vector2, t: Object, dmg: float, hit: int) -> void :
        if gw.battle_watch != null:
                gw.battle_watch.note(u.pos, 0.4 if u.type == Unit.Type.TANK else 0.15, "", u.country_id)
        var dir: Vector2 = (tp - u.pos).normalized()
        var on: bool = gw._on_screen(u.pos, 60.0)
        if u.type == Unit.Type.TANK:
                var muzzle: Vector2 = u.pos + dir * 7.0
                if on:
                        gw.fx.spawn("tank_shot", muzzle.round(), 6)
                Sfx.play("tank_cannon", muzzle)
                var miss: = Vector2.ZERO
                var ok: bool = Hash32.h2(u.id, int(gw.game_time * 7.0), 23) % 100 < hit
                if not ok:
                        miss = Vector2(float(Hash32.h2(u.id, 1, int(gw.game_time)) % 17) - 8.0, float(Hash32.h2(u.id, 2, int(gw.game_time)) % 17) - 8.0)
                shells.append({"from": muzzle, "to": tp + miss, "t": 0.0, "dur": maxf(0.12, muzzle.distance_to(tp) / 260.0), "dmg": dmg if ok else 0.0, "target": t, "c": u.country_id})
        else:
                var ifv: bool = u.type == Unit.Type.IFV
                if on:
                        var wm: Vector2 = gw.hold.muzzle(u, tp) if gw.hold != null else Vector2.INF
                        gw.fx.spawn("muzzle_flash", (wm if wm.is_finite() else u.pos + dir * (5.0 if ifv else 3.0)).round(), 6)
                        gw.mil.air.tracers.append([wm if wm.is_finite() else u.pos + dir * 3.0, tp, gw.game_time + 0.08])
                        if ifv:
                                gw.mil.air.tracers.append([u.pos + dir * 3.0 + Vector2(dir.y, - dir.x), tp + Vector2(randf_range(-3, 3), randf_range(-3, 3)), gw.game_time + 0.12])
                Sfx.play("mg_burst" if u.id % 3 == 0 or ifv else "rifle_burst", u.pos)
                if t is Unit:
                        (t as Unit).supp = minf(1.0, (t as Unit).supp + 0.12)
                if in_smoke(tp) or in_smoke(u.pos):
                        hit = hit * 2 / 5
                hit = int(float(hit) * (1.0 - 0.4 * u.supp))
                if Hash32.h2(u.id, int(gw.game_time * 9.0), 29) % 100 < hit:
                        _damage(t, dmg, u.country_id, u.pos if t is Unit else Vector2.INF)
                        if on and Hash32.h2(u.id, int(gw.game_time * 5.0), 3) % 3 == 0:
                                gw.fx.spawn("hit_small", (tp + Vector2(randi_range(-2, 2), randi_range(-2, 2))).round(), 6)


func _update_shells(dt: float) -> void :
        for k in range(shells.size() - 1, -1, -1):
                var s: Dictionary = shells[k]
                s["t"] = float(s["t"]) + dt
                if float(s["t"]) < float(s["dur"]):
                        continue
                var p: Vector2 = s["to"]
                if gw._on_screen(p, 40.0):
                        gw.fx.spawn("hit_small" if float(s["dmg"]) > 0.0 else "dirt_burst", p.round(), 6)
                if float(s["dmg"]) > 0.0 and s["target"] != null:
                        _damage(s["target"], float(s["dmg"]), int(s["c"]), (s["from"] as Vector2) if s["target"] is Unit else p)
                shells.remove_at(k)



func _damage(t: Object, dmg: float, by: int, at: = Vector2.INF, clear: bool = false, src: int = 0) -> void :
        if t is Unit:
                var u: Unit = t
                if not u.alive():
                        return
                var k: float = 0.6 if u.type == Unit.Type.TANK and dmg < 20.0 else (0.75 if u.vehicle() and dmg < 20.0 else 1.0)
                u.hit_t = gw.game_time
                u.supp = minf(1.0, u.supp + 0.25)
                if not u.entrenched:

                        var cv: float = u.cover * (0.6 if u.dug else 1.0)
                        k *= maxf(cv, 0.85) if clear else cv
                if u.entrenched:

                        var dug_roof: bool = u.post != null and u.post.kind == Facility.Kind.DUGOUT
                        var tk: float = 1.0
                        if src == 1:
                                tk = 0.45 if dug_roof else TRENCH_VS_FPV
                        elif src == 2:
                                tk = 0.55 if dug_roof else TRENCH_VS_ARTY
                        else:
                                tk = (0.8 if clear else TRENCH_ARMOR)

                        k *= maxf(tk, 1.0) if flanked(u, at) else tk
                        if gw._on_screen(u.pos, 40.0) and Hash32.h2(u.id, int(gw.game_time * 4.0), 77) % 3 == 0:
                                gw.fx.spawn("dirt_burst", (u.pos + Vector2(randi_range(-4, 4), -1)).round(), 6)
                if src == 2:
                        pin(u)
                u.hp -= dmg * k
                if u.hp > 0.0 and gw.vfx != null and gw.vfx.blast != null: gw.vfx.blast.on_hit(u, dmg * k, src, at)
                if u.hp <= 0.0:
                        _kill(u, by)
                elif u.type == Unit.Type.TANK and not u.smoke_used and u.hp < u.max_hp * 0.6:

                        u.smoke_used = true
                        if gw._on_screen(u.pos, 80.0):
                                gw.fx.spawn("smoke_screen_loop", (u.pos + Vector2(0, 4)).round(), 5, gw.game_time + 8.0, true)
        elif t is Facility:
                var f: Facility = t
                if f.is_line():
                        gw.mil.damage_line(f, at if at != Vector2.INF else f.center_px(), dmg)
                        return
                f.hp -= dmg
                if f.hp <= 0.0 and gw.mil.alive(f):
                        f.hp = 100.0
                        gw.strike(f.cell + f.size / 2, by)


func _kill(u: Unit, by: int) -> void :
        if not u.alive():
                return
        u.state = Unit.State.DEAD
        u.dead_t = gw.game_time
        if gw.battle_watch != null:
                gw.battle_watch.note(u.pos, 4.0 if u.vehicle() else 2.0, "", u.country_id)
        Sfx.play("expl_big" if u.type == Unit.Type.TANK else "expl_small", u.pos, -3.0 if u.type == Unit.Type.TANK else -8.0)
        var c: Country = gw.country_by_id(by)
        if c != null and by != u.country_id:
                c.destroyed += int(SPEC[u.type]["cost"]) + (100 if u.type == Unit.Type.TANK else 0)
        if u.vehicle():
                if gw.vfx != null and gw.vfx.blast != null:
                        gw.vfx.blast.on_kill(u)
                else:
                        gw.fx.spawn("explosion_m", u.pos.round(), 6)
                        gw.fx.spawn("fire_small", u.pos.round(), 3, gw.game_time + 20.0, true)
                gw.fx.debris_burst(u.pos.round(), 4, false)
                fire.add_decal("wreck_hull" if gw.fx.atlas_of.has("wreck_hull") else "crater_s", u.pos.round())
                if u.type == Unit.Type.MLRS or u.type == Unit.Type.ARTY:

                        for i in 3:
                                gw._delay(0.4 + 0.5 * i, fire.cook_off.bind(u.pos + Vector2(randf_range(-6, 6), randf_range(-5, 3))))
                if u.type == Unit.Type.MLRS and gw._on_screen(u.pos, 40.0):
                        gw.camera_shake_tiny(u.pos)
        elif u.foot():
                gw.fx.spawn("explosion_s", u.pos.round(), 6)
        else:
                gw.fx.spawn("explosion_s", u.pos.round(), 6)



func _advance(u: Unit, dt: float) -> void :
        if u.state == Unit.State.FIGHT:
                u.state = Unit.State.MOVE if u.pi < u.path.size() else Unit.State.IDLE
        if u.pi >= u.path.size():
                if u.post != null and not u.entrenched:
                        u.entrenched = true
                        u.state = Unit.State.IDLE
                        u.heading = _post_facing(u.post)
                        u.update_frame()
                        return
                if u.op_hold:

                        u.op_move = false
                        if u.cover >= 1.0:
                                u.cover = tac.unit_cover(u.pos)
                        if u.state != Unit.State.IDLE:
                                u.state = Unit.State.IDLE
                        return
                if u.target_city >= 0 and u.state != Unit.State.SIEGE:
                        u.state = Unit.State.SIEGE
                elif u.target_city < 0:
                        u.state = Unit.State.IDLE
                if u.state == Unit.State.SIEGE and not u.indirect():
                        _siege_fire(u)
                return
        var st0: float = u.still_t
        var dug0: bool = u.dug
        var cov0: float = u.cover
        u.still_t = 0.0
        u.dug = false
        u.cover = 1.0
        var q: Vector2 = u.path[u.pi]
        var to: Vector2 = q - u.pos
        var spd: float = float(SPEC[u.type]["speed"])
        if u.reinf == 2 and u.reinf_v > 0.0:
                spd = minf(spd, u.reinf_v)
        var c: Country = gw.country_by_id(u.country_id)
        if c != null and c.food <= 0:
                spd *= 0.6
        if not u.foot() and not gw.mil.fort_cells.is_empty():

                var tc: = Vector2i(floori(u.pos.x / GameWorld.CELL), floori(u.pos.y / GameWorld.CELL))
                var slow: bool = false
                for ty in range(-1, 2):
                        for tx in range(-1, 2):
                                var tq: = tc + Vector2i(tx, ty)
                                var tf: Variant = gw.mil.fort_cells.get(tq, null)
                                if tf != null and Military.is_teeth((tf as Facility).kind) and not (tf as Facility).cells.is_empty():
                                        slow = true
                                        gw.mil.damage_line(tf, Vector2(tq * GameWorld.CELL) + Vector2(2, 2), TEETH_CRUSH * dt)
                if slow:
                        spd *= 0.4
        var step: float = spd * dt
        if not _dry_step(u, q, to, step):
                u.still_t = st0
                u.dug = dug0
                u.cover = cov0
                _blocked(u, st0, dt)
                return
        _turn(u, to.angle(), PI * 1.5 * dt)
        if to.length() <= step + 0.5:
                u.pos = q
                u.pi += 1
                if u.pi < u.path.size() - 1 and u.type == Unit.Type.TANK and gw.econ.point_blocked(u.path[u.pi]):

                        u.path = gw.econ.nav_path(u.pos, u.path[u.path.size() - 1])
                        u.pi = 0
                if u.target_city >= 0:
                        var city: City = gw.cities[u.target_city]
                        if u.pos.distance_to(Vector2(city.center * GameWorld.CELL)) < float(city.radius * GameWorld.CELL) + 10.0:
                                u.pi = u.path.size()
        else:
                u.pos += to / to.length() * step



func _siege_fire(u: Unit) -> void :
        if u.fire_cd > 0.0 or u.target_city < 0:
                return
        var city: City = gw.cities[u.target_city]
        if city.country_id == u.country_id:
                u.target_city = -1
                u.state = Unit.State.IDLE
                return
        if not _hostile(u.country_id, city.country_id):

                u.target_city = -1
                u.state = Unit.State.IDLE
                u.path = PackedVector2Array()
                return
        if city.garrison <= 0.0:
                return
        var sp: Dictionary = SPEC[u.type]
        u.fire_cd = float(sp["cd"]) * 1.2
        var h: int = Hash32.h2(u.id, int(gw.game_time * 2.0), 41)
        var off: = Vector2(float(h % (city.radius * 2 + 1) - city.radius), float((h >> 8) % (city.radius * 2 + 1) - city.radius)) * GameWorld.CELL * 0.7
        var tp: Vector2 = Vector2(city.center * GameWorld.CELL) + off
        _turn(u, (tp - u.pos).angle(), PI)
        var on: bool = gw._on_screen(u.pos, 80.0)
        if u.type == Unit.Type.TANK:
                if on:
                        gw.fx.spawn("tank_shot", (u.pos + Vector2.from_angle(u.heading) * 7.0).round(), 6)
                shells.append({"from": u.pos, "to": tp, "t": 0.0, "dur": 0.35, "dmg": 0.0, "target": null, "c": u.country_id})
                Sfx.play("tank_cannon", u.pos, -2.0)

                if h % 9 == 0:
                        var cell: = Vector2i(floori(tp.x / GameWorld.CELL), floori(tp.y / GameWorld.CELL))
                        gw._delay(0.35, gw._apply_strike.bind(cell, 1, "crater_s", 6.0, u.country_id))
        elif on:
                gw.fx.spawn("muzzle_flash", (u.pos + Vector2.from_angle(u.heading) * 3.0).round(), 6)
                gw.mil.air.tracers.append([u.pos, tp, gw.game_time + 0.08])
                Sfx.play("rifle_burst", u.pos, -2.0)
        city.garrison = maxf(0.0, city.garrison - float(sp["dmg"]) * (0.5 if gw.country_by_id(u.country_id).doctrine_assault else 0.3))
        city.hit_t = gw.game_time








func _sieges(dt: float) -> void :
        for city: City in gw.cities:
                if city.garrison_max != city.garrison_cap():
                        var ratio: float = city.garrison / maxf(1.0, city.garrison_max)
                        city.garrison_max = city.garrison_cap()
                        city.garrison = city.garrison_max * ratio
                var att: Array[Unit] = []
                var defs: Array[Unit] = []
                var aw: float = 0.0
                var dw: float = 0.0
                var drain: float = 0.0
                var by_w: Dictionary = {}
                var cpx: Vector2 = Vector2(city.center * GameWorld.CELL)
                var rr: float = float(city.radius * GameWorld.CELL) + 24.0
                for u: Unit in _near(cpx, rr):
                        if not u.alive() or u.type == Unit.Type.FPV or u.type == Unit.Type.RECON:
                                continue
                        if u.pos.distance_squared_to(cpx) > rr * rr:
                                continue
                        var w: float = cap_w(u)
                        if u.country_id == city.country_id or gw.diplo.allied(u.country_id, city.country_id):
                                defs.append(u)
                                dw += w * (1.5 if u.entrenched else 1.0)
                        elif _hostile(u.country_id, city.country_id):
                                att.append(u)
                                aw += w
                                by_w[u.country_id] = float(by_w.get(u.country_id, 0.0)) + w
                                if u.state != Unit.State.SIEGE or u.target_city != city.id:
                                        drain += w
                if att.is_empty():
                        city.siege_by = 0
                        if city.capture > 0.0:
                                city.capture = maxf(0.0, city.capture - dt / CAP_DECAY_T)
                        if city.capture <= 0.0:
                                city.cap_by = 0
                                city.cap_note = 0
                        if gw.game_time - city.hit_t > GARRISON_CALM:
                                city.garrison = minf(city.garrison_max, city.garrison + GARRISON_REGEN * dt)
                        continue

                var lead: int = att[0].country_id
                var lw: float = -1.0
                for cid: int in by_w:
                        var cw: float = float(by_w[cid])
                        if cw > lw or (cw == lw and cid < lead):
                                lw = cw
                                lead = cid
                if city.cap_by != lead and not by_w.has(city.cap_by):
                        if city.cap_by != 0 and not gw.diplo.allied(city.cap_by, lead):
                                city.capture = 0.0
                                city.cap_note = 0
                        city.cap_by = lead
                city.siege_by = city.cap_by
                if drain > 0.0 and city.garrison > 0.0:
                        city.garrison = maxf(0.0, city.garrison - CAP_DRAIN * drain * dt)
                        city.hit_t = gw.game_time

                if city.garrison > 0.0 and gw.game_time >= city.fire_t:
                        var h: int = Hash32.h2(city.id, int(gw.game_time * 1.5), 61)
                        city.fire_t = gw.game_time + (0.7 if city.kind == City.Kind.CAPITAL else 1.2)
                        var u: Unit = att[h % att.size()]
                        var src: Vector2 = cpx + Vector2(float(h % 9) - 4.0, float((h >> 4) % 9) - 4.0) * 3.0
                        if gw._on_screen(src, 60.0):
                                gw.fx.spawn("muzzle_flash", src.round(), 6)
                                gw.mil.air.tracers.append([src, u.pos, gw.game_time + 0.08])
                                Sfx.play("mg_burst", src, -3.0)
                        var sieger: Country = gw.country_by_id(u.country_id)
                        var k_siege: float = 0.5 if sieger != null and not sieger.doctrine_assault else 1.0
                        _damage(u, GARRISON_DMG * k_siege * maxf(0.3, city.garrison / maxf(1.0, city.garrison_max)) * (1.5 if city.kind == City.Kind.CAPITAL else 1.0), city.country_id)
                if not defs.is_empty() and city.garrison <= 0.0:

                        for u: Unit in att:
                                if u.target == null and u.state == Unit.State.SIEGE:
                                        var nd: Unit = defs[0]
                                        for dd: Unit in defs:
                                                if dd.pos.distance_squared_to(u.pos) < nd.pos.distance_squared_to(u.pos):
                                                        nd = dd
                                        u.path = PackedVector2Array([nd.pos])
                                        u.pi = 0
                                        u.state = Unit.State.MOVE
                city.capture = clampf(city.capture + cap_rate(city, aw, dw) * dt, 0.0, 1.0)
                _cap_say(city)
                if city.capture >= 1.0:
                        var by: int = city.cap_by
                        city.capture = 0.0
                        city.cap_by = 0
                        city.cap_note = 0
                        gw.capture_city(city, by)
                        city.garrison = city.garrison_max * 0.3
                        for u: Unit in att:
                                if u.country_id == city.country_id or not _hostile(u.country_id, city.country_id):
                                        u.target_city = -1
                                        u.state = Unit.State.IDLE
                                        u.path = PackedVector2Array()



static func cap_w(u: Unit) -> float:
        return clampf(float(SPEC[u.type]["cost"]) / 150.0, 0.5, 3.0)




static func cap_rate(city: City, aw: float, dw: float) -> float:
        if aw <= 0.0:
                return -1.0 / CAP_DECAY_T
        var g: float = float(CAP_GW[city.kind]) * clampf(city.garrison / maxf(1.0, city.garrison_max), 0.0, 1.0)
        var t: float = float(CAP_T[city.kind])
        if dw <= 0.0:
                return aw / (aw + g) / t
        return (aw - dw - g) / (aw + dw + g) / t



func _cap_say(city: City) -> void :
        if city.capture <= 0.05:
                city.cap_note = 0
                return
        var q: int = int(city.capture * 4.0)
        if q < 1 or q > 3 or q <= city.cap_note:
                return
        city.cap_note = q
        gw.say(gw.country_by_id(city.country_id), Loc.mk("Город %s захватывают: %d%%", [Loc.name(city.name), q * 25]))
        if q == 2:
                gw.say(gw.country_by_id(city.cap_by), Loc.mk("Захват города %s: 50%%", [Loc.name(city.name)]))




func _maybe_fpv(u: Unit, dt: float) -> void :
        if (u.kit & Unit.KIT_FPV) == 0:
                return
        var c: Country = gw.country_by_id(u.country_id)
        if c == null or not c.doctrine_fpv or (u.kit & Unit.KIT_FPV) == 0:
                return
        u.fpv_cd -= dt
        if u.fpv_cd > 0.0:
                return
        var flying: int = int(_fpv_fly.get(u.country_id, 0))
        if flying >= FPV_MAX + _fpv_bonus(u.country_id):
                u.fpv_cd = 5.0
                return
        var best: Unit = _fpv_pick(u.country_id, u.pos)
        if best == null:
                u.fpv_cd = 1.5
                return
        u.fpv_cd = FPV_CD
        var f: = Unit.new()
        f.id = _next_id
        _next_id += 1
        f.type = Unit.Type.FPV
        f.country_id = u.country_id
        f.pos = u.pos + Vector2(0, -2)
        f.heading = (best.pos - u.pos).angle()
        f.update_frame()
        f.hp = 1.0
        f.target = best
        f.life = FPV_LIFE
        f.state = Unit.State.MOVE
        units.append(f)
        _fpv_fly[u.country_id] = flying + 1
        Sfx.play("fpv_buzz", f.pos)



func _fpv_pick(cid: int, p: Vector2) -> Unit:
        var best: Unit = null
        var bd: float = FPV_R * FPV_R
        for o: Unit in _near(p, FPV_R):
                if not o.alive() or o.type == Unit.Type.FPV or not _hostile(cid, o.country_id):
                        continue
                var d2: float = o.pos.distance_squared_to(p)
                if d2 > FPV_R * FPV_R or in_smoke(o.pos):
                        continue
                var sc: float = d2 * (0.35 if o.entrenched and not (o.post != null and o.post.kind == Facility.Kind.DUGOUT) else (0.5 if o.vehicle() else 1.0))
                if sc < bd:
                        bd = sc
                        best = o
        return best





func _fpv_lock(f: Unit, t: Unit) -> bool:
        if t == null or not t.alive() or not _hostile(f.country_id, t.country_id):
                return false
        var d2: float = t.pos.distance_squared_to(f.pos)
        if d2 > FPV_LOCK_R * FPV_LOCK_R or (d2 > 28.0 * 28.0 and in_smoke(t.pos)):
                return false
        return units.has(t)


func _fpv(f: Unit, dt: float) -> void :
        f.life -= dt
        if f.jam_t > 0.0:

                f.jam_t -= dt
                f.heading += dt * 3.0
                f.pos += Vector2.from_angle(f.heading) * 20.0 * dt
                f.update_frame()
                if f.jam_t <= 0.0:
                        _kill(f, 0)
                return
        var t: Unit = f.target as Unit
        if f.life <= 0.0:
                f.target = null
                f.jam_t = FPV_FALL
                return
        if not _fpv_lock(f, t):

                t = _fpv_pick(f.country_id, f.pos) if f.life > 1.5 else null
                f.target = t
                if t == null:
                        f.jam_t = FPV_FALL
                        return
        var to: Vector2 = t.pos - f.pos
        _turn(f, to.angle(), PI * 2.5 * dt)
        var step: float = float(SPEC[Unit.Type.FPV]["speed"]) * dt
        if to.length() <= step + 1.0:
                var came: Vector2 = t.pos - to.normalized() * 12.0
                f.pos = t.pos
                _kill(f, 0)
                if Hash32.h2(f.id, 3, 99) % 100 < int(SPEC[Unit.Type.FPV]["hit"]):
                        _damage(t, float(SPEC[Unit.Type.FPV]["dmg"]), f.country_id, came, false, 1)
                return
        f.pos += Vector2.from_angle(f.heading) * step


func fpv_targets(country_id: int, p: Vector2, r: float) -> Array[Unit]:
        var out: Array[Unit] = []
        for u: Unit in units:
                if u.type == Unit.Type.FPV and u.alive() and u.jam_t <= 0.0 and _hostile(country_id, u.country_id) and u.pos.distance_squared_to(p) <= r * r:
                        out.append(u)
        for u2: Unit in fire.recon:
                if u2.alive() and u2.jam_t <= 0.0 and _hostile(country_id, u2.country_id) and u2.pos.distance_squared_to(p) <= r * r:
                        out.append(u2)
        return out






func on_ceasefire(a: int, b: int) -> void :
        if a == b or a <= 0 or b <= 0:
                return
        for u: Unit in units:
                if not u.alive() or (u.country_id != a and u.country_id != b):
                        continue
                var o: int = b if u.country_id == a else a
                if u.target != null and _owner_of(u.target) == o:
                        u.target = null
                if u.target_city >= 0 and u.target_city < gw.cities.size() and gw.cities[u.target_city].country_id == o and not u.op_on:
                        u.target_city = -1
                        u.path = PackedVector2Array()
                        u.pi = 0
                        if u.state != Unit.State.DEAD:
                                u.state = Unit.State.IDLE
        for s0: Dictionary in shells:
                if _pair(int(s0["c"]), _owner_of(s0["target"]), a, b):
                        s0["dmg"] = 0.0
        for k in range(rockets.size() - 1, -1, -1):
                if _pair(int(rockets[k]["c"]), _owner_of(rockets[k]["target"]), a, b):
                        gw.fx.spawn("dirt_burst", (rockets[k]["pos"] as Vector2).round(), 6)
                        rockets.remove_at(k)
        for k2 in range(fire.requests.size() - 1, -1, -1):
                var rq: Dictionary = fire.requests[k2]
                var ro: int = _owner_of(rq.get("obj")) if rq.get("obj") != null else gw.ops._owner_at(rq["p"])
                if _pair(int(rq["c"]), ro, a, b):
                        fire.requests.remove_at(k2)
        for cid: int in [a, b]:
                var sp: Array = fire.spotted.get(cid, [])
                for k3 in range(sp.size() - 1, -1, -1):
                        if _owner_of((sp[k3] as Array)[1]) == (b if cid == a else a):
                                sp.remove_at(k3)
        if gw.ops == null:
                return
        for f: Facility in gw.mil.facilities:
                if f.kind != Facility.Kind.BARRACKS or (f.country_id != a and f.country_id != b) or not gw.mil.alive(f):
                        continue
                var o2: int = b if f.country_id == a else a
                var op: Dictionary = gw.ops.list.get(f, {})
                if gw.diplo.conf != null and gw.diplo.conf.holds(f.country_id, o2):

                        if not op.is_empty() and int(op["kind"]) == Operations.Kind.ATTACK:
                                gw.ops.cancel(f)
                        continue
                var against: bool = false
                if not op.is_empty() and int(op["kind"]) != Operations.Kind.RETREAT:
                        var oc: int = int(op.get("city", -1))
                        against = (oc >= 0 and oc < gw.cities.size() and gw.cities[oc].country_id == o2) or gw.ops._owner_at(op["target"]) == o2
                var inside: bool = against
                if not inside:
                        for u2: Unit in gw.ops._army(f):
                                if gw.ops._owner_at(u2.pos) == o2:
                                        inside = true
                                        break
                if not inside:
                        continue
                if gw.ops.start(f, Operations.Kind.RETREAT, Vector2.ZERO) != "" and against:
                        gw.ops.cancel(f)


func _owner_of(t: Variant) -> int:
        if t is Unit:
                return (t as Unit).country_id
        if t is Facility:
                return (t as Facility).country_id
        if t is City:
                return (t as City).country_id
        return -1


static func _pair(x: int, y: int, a: int, b: int) -> bool:
        return (x == a and y == b) or (x == b and y == a)


func shoot_fpv(u: Unit) -> void :
        _kill(u, 0)


func jam(u: Unit) -> void :
        if u.jam_t <= 0.0:
                u.jam_t = 1.2




func on_strike(p: Vector2, r_px: float, by: int) -> void :
        for u: Unit in units:
                if not u.alive():
                        continue
                var d: float = u.pos.distance_to(p)
                if d > r_px + 6.0:
                        continue
                _damage(u, 90.0 if d < r_px * 0.6 else 45.0, by)


func starve(country_id: int) -> void :
        for u: Unit in units:
                if u.country_id == country_id and u.alive() and u.foot():
                        u.hp = maxf(minf(u.hp, u.max_hp * 0.25), u.hp - 3.0)




func _launch_rocket(u: Unit, t: Object, kind: String, dmg: float, hit: int) -> void :
        var tp: Vector2 = _target_pos(t, u.pos)
        var dir: Vector2 = (tp - u.pos).normalized()
        var start: Vector2 = u.pos + dir * 4.0 + Vector2(0, -2)
        rockets.append({"kind": kind, "pos": start, "heading": dir.angle(), "target": t, "c": u.country_id, "dmg": dmg, "hit": hit, "life": 6.0 if kind == "rpg" else 9.0, "id": _rid, "trail": 0.0})
        _rid += 1
        Sfx.play("rpg_fire" if kind == "rpg" else "atgm_launch", start)
        if gw._on_screen(u.pos, 80.0):
                if kind == "rpg":
                        gw.fx.spawn("rpg_backblast", (u.pos - dir * 6.0).round(), 5)
                else:
                        gw.fx.spawn("atgm_launch", (u.pos + dir * 3.0).round(), 6)


func _update_rockets(dt: float) -> void :
        for k in range(rockets.size() - 1, -1, -1):
                var r: Dictionary = rockets[k]
                r["life"] = float(r["life"]) - dt
                var t: Object = r["target"]
                var alive_t: bool = (t is Unit and (t as Unit).alive()) or (t is Facility and gw.mil.alive(t as Facility))
                var pos: Vector2 = r["pos"]
                if float(r["life"]) <= 0.0 or not alive_t:
                        gw.fx.spawn("dirt_burst", pos.round(), 6)
                        rockets.remove_at(k)
                        continue
                var tp: Vector2 = _target_pos(t, pos)
                var to: Vector2 = tp - pos

                var turn: float = (PI * 1.2 if r["kind"] == "atgm" else PI * 0.3) * dt
                r["heading"] = wrapf(float(r["heading"]) + clampf(wrapf(to.angle() - float(r["heading"]), - PI, PI), - turn, turn), - PI, PI)
                var step: float = float(ROCKET_SPEED[r["kind"]]) * dt
                if to.length() <= step + 2.0:
                        var ok: bool = Hash32.h2(int(r["id"]), 3, 57) % 100 < int(r["hit"])
                        if ok:
                                gw.fx.spawn("atgm_hit" if r["kind"] == "atgm" else "explosion_s", tp.round(), 6)
                                if gw.battle_watch != null:
                                        gw.battle_watch.note(tp, 1.0, "", int(r["c"]))
                                Sfx.play("atgm_hit" if r["kind"] == "atgm" else "expl_small", tp)
                                _damage(t, float(r["dmg"]), int(r["c"]), pos if t is Unit else tp)
                        else:
                                gw.fx.spawn("dirt_burst", (tp + Vector2.from_angle(float(r["heading"])) * 6.0).round(), 6)
                        rockets.remove_at(k)
                        continue
                r["pos"] = pos + Vector2.from_angle(float(r["heading"])) * step
                r["trail"] = float(r["trail"]) + step
                if float(r["trail"]) >= 5.0:
                        r["trail"] = 0.0
                        if gw._on_screen(pos, 60.0):
                                gw.fx.spawn("trail_s", pos.round(), 5)





static func is_trench(kind: int) -> bool:
        return kind == Facility.Kind.TRENCH_H or kind == Facility.Kind.DUGOUT


func slots_of(f: Facility) -> Array[Vector2]:
        var out: Array[Vector2] = []
        if f.kind == Facility.Kind.DUGOUT and f.build_t > 0.0:
                return out
        if f.kind == Facility.Kind.DUGOUT:
                var door: Vector2 = f.center_px() + Vector2(0, 6)
                var info: Dictionary = gw.mil._info("dugout")
                if f.main_obj >= 0 and info.has("door"):
                        door = gw.mil.local_px(f.main_obj, info["door"])
                for dx: float in [-4.0, 0.0, 4.0]:
                        out.append(door + Vector2(dx, -3.0))
                return out
        for i in range(1, f.cells.size(), 3):
                out.append(Vector2(f.cells[i] * GameWorld.CELL) + Vector2(2, 2))
        if out.is_empty() and not f.cells.is_empty():
                out.append(Vector2(f.cells[0] * GameWorld.CELL) + Vector2(2, 2))
        return out


func capacity(f: Facility) -> int:
        return slots_of(f).size()


func occupants(f: Facility) -> Array[Unit]:
        var out: Array[Unit] = []
        if _occ.has(f):
                out.assign(_occ[f])
                return out
        for u: Unit in units:
                if u.post == f and u.alive():
                        out.append(u)
        return out




func pin(u: Unit) -> void :
        if not (u.entrenched or u.dug or u.cover < 0.95):
                return
        var now: float = gw.game_time
        var was: float = float(pin_until.get(u.id, 0.0))
        pin_until[u.id] = minf(maxf(was, now) + PIN_T, now + PIN_MAX)
        if was < now and gw._on_screen(u.pos, 40.0):
                gw.fx.spawn("dirt_burst", (u.pos + Vector2(randi_range(-3, 3), -2)).round(), 6)


func pinned(u: Unit) -> bool:
        if pin_until.is_empty():
                return false
        var t: float = float(pin_until.get(u.id, -1.0))
        if t < 0.0:
                return false
        if t <= gw.game_time:
                pin_until.erase(u.id)
                return false
        return true



func trench_front(f: Facility) -> Vector2:
        var away: Vector2 = Vector2.from_angle(_post_facing(f))
        if f.kind != Facility.Kind.TRENCH_H or f.cells.size() < 2:
                return away
        var along: Vector2 = Vector2(f.cells[f.cells.size() - 1] - f.cells[0])
        if along.length_squared() < 0.5:
                return away
        var n: Vector2 = along.normalized().orthogonal()
        return n if n.dot(away) >= 0.0 else - n



func flanked(u: Unit, at: Vector2) -> bool:
        if u.post == null or not at.is_finite() or at.distance_squared_to(u.pos) < 4.0:
                return false
        return (at - u.pos).normalized().dot(trench_front(u.post)) < FLANK_COS


func _post_facing(f: Facility) -> float:
        var c: Country = gw.country_by_id(f.country_id)
        if c == null or c.capital_id < 0:
                return 0.0
        var away: Vector2 = f.center_px() - Vector2(gw.cities[c.capital_id].center * GameWorld.CELL)
        return away.angle()




func occupy(f: Facility, country_id: int, auto: bool = false, only: Facility = null) -> int:
        if not is_trench(f.kind) or not gw.mil.alive(f):
                return 0
        if not auto:
                f.post_off = false
        var taken: Dictionary = {}
        for u: Unit in occupants(f):
                taken[u.post_slot] = true
        var slots: Array[Vector2] = slots_of(f)
        var free: Array[int] = []
        for i in slots.size():
                if not taken.has(i):
                        free.append(i)
        occupy_why = ""
        occupy_m = ""
        if free.is_empty():
                occupy_m = Loc.mk("Мест нет: %d/%d", [slots.size() - free.size(), slots.size()])
                occupy_why = Loc.src(occupy_m)
                return 0
        var cand: Array[Unit] = []
        var posted: int = 0
        for u: Unit in units:
                if u.country_id == country_id and u.alive() and u.post != null and (only == null or u.home == only):
                        posted += 1
                if u.country_id == country_id and u.alive() and u.post == null and (u.type == Unit.Type.INFANTRY or u.type == Unit.Type.ATGM or u.type == Unit.Type.ASSAULT) and u.state != Unit.State.SIEGE and u.reinf == 0 and ( not u.op_on or ( not auto and _may_leave_op(u, only))):
                        if only != null and u.home != only:
                                continue
                        if auto and u.no_post_until - gw.game_time > ORDER_OUT * 0.5:
                                if u.op_on or u.pos.distance_to(f.center_px()) > NEAR_POST:
                                        continue
                        elif auto and (gw.game_time < u.no_post_until or u.target_city >= 0):
                                continue
                        cand.append(u)
        var fc: Vector2 = f.center_px()
        cand.sort_custom( func(a: Unit, b: Unit) -> bool:
                var pa: float = a.pos.distance_squared_to(fc) - (90000.0 if a.type == Unit.Type.ATGM else 0.0)
                var pb: float = b.pos.distance_squared_to(fc) - (90000.0 if b.type == Unit.Type.ATGM else 0.0)
                return pa < pb)
        var n: int = 0
        for u: Unit in cand:
                if n >= free.size() or u.pos.distance_to(fc) > 3000.0:
                        break
                if u.pos.distance_to(fc) > 40.0:
                        gw.econ.nav_path(u.pos, fc)
                        if not gw.econ.nav_last_ok:
                                continue
                var si: int = free[n]
                if not auto and not front_dig and u.home != null and gw.ops != null and gw.country_by_id(country_id) != null and gw.country_by_id(country_id).is_player:
                        gw.ops.auto_next["h%d" % u.home.id] = gw.game_time
                u.no_post_until = 0.0
                u.post = f
                u.post_slot = si
                _occ.erase(f)
                u.op_on = false
                u.op_hold = false
                u.op_move = false
                u.entrenched = false
                u.target_city = -1
                u.target = null
                u.path = gw.econ.nav_path(u.pos, slots[si]) if u.pos.distance_to(slots[si]) > 40.0 else PackedVector2Array([slots[si]])
                if u.path.size() > 0:
                        u.path[u.path.size() - 1] = slots[si]
                u.pi = 0
                u.state = Unit.State.MOVE
                n += 1
        if n == 0:
                occupy_m = Loc.mk("%s%s", [Loc.mk("Свободной пехоты рядом нет"), Loc.mk(" (в окопах: %d)", [posted]) if posted > 0 else ""])
                occupy_why = Loc.src(occupy_m)
        return n




func release_posts(h: Facility) -> int:
        var n: int = 0
        for u: Unit in units:
                if u.home == h and u.alive() and u.post != null:
                        _release(u)
                        u.no_post_until = gw.game_time + ORDER_OUT
                        n += 1
        return n






func leave(f: Facility) -> int:
        f.post_off = true
        var occ: Array[Unit] = occupants(f)
        var back: Vector2 = Vector2.from_angle(_post_facing(f) + PI)
        var rest: Dictionary = {}
        for u0: Unit in occ:
                if u0.home != null and not rest.has(u0.home):
                        rest[u0.home] = _field_centre(u0.home)
        var k: int = 0
        for u: Unit in occ:
                _release(u)
                u.no_post_until = gw.game_time + 45.0
                if gw.ops != null and gw.ops.rejoin(u):
                        continue
                var dest: Vector2 = u.pos + back * 26.0 + Vector2((k % 3 - 1) * 6.0, float(k / 3) * 6.0)
                k += 1
                var h: Facility = u.home
                if h != null and gw.mil.alive(h):
                        var rc: Vector2 = rest.get(h, Vector2.INF)
                        if h.stance == 0 and rc.is_finite() and rc.distance_to(barracks_out(h)) > 120.0:
                                dest = safe_point(rc, u.slot)
                        elif h.center_px().distance_to(u.pos) < 700.0 or h.stance > 0:
                                dest = barracks_out(h) + u.slot
                u.path = gw.econ.nav_path(u.pos, dest) if u.pos.distance_to(dest) > 40.0 else PackedVector2Array([dest])
                if u.path.is_empty():
                        u.path = PackedVector2Array([dest])
                u.path[u.path.size() - 1] = dest
                u.pi = 0
                u.state = Unit.State.MOVE
        return occ.size()



func _field_centre(h: Facility) -> Vector2:
        var s: = Vector2.ZERO
        var n: int = 0
        for u: Unit in units:
                if u.home == h and u.alive() and u.ground() and u.post == null and u.reinf == 0:
                        s += u.pos
                        n += 1
        return s / float(n) if n > 0 else Vector2.INF




func _may_leave_op(u: Unit, only: Facility) -> bool:
        if only != null:
                return u.home == only
        if u.home == null or gw.ops == null or not gw.ops.list.has(u.home):
                return false
        return int(gw.ops.list[u.home]["kind"]) == Operations.Kind.DEFEND


func _release(u: Unit) -> void :
        u.post = null
        u.post_slot = -1
        u.entrenched = false
        u.state = Unit.State.IDLE





func _check_posts() -> void :
        for f: Facility in _occ:
                var oa: Array = _occ[f]
                if oa.is_empty():
                        continue
                var slots: Array[Vector2] = slots_of(f)
                var seen: Dictionary = {}
                for k in range(oa.size() - 1, -1, -1):
                        var u: Unit = oa[k]
                        var si: int = u.post_slot
                        var bad: bool = si < 0 or si >= slots.size() or seen.has(si)
                        if not bad:
                                var sp: Vector2 = slots[si]
                                if u.entrenched:
                                        if u.pos.distance_to(sp) > 8.0:
                                                u.entrenched = false
                                                u.path = PackedVector2Array([sp])
                                                u.pi = 0
                                                u.state = Unit.State.MOVE
                                else:
                                        bad = u.pi >= u.path.size() and u.pos.distance_to(sp) > 8.0\
                                        or u.pi < u.path.size() and u.path[u.path.size() - 1].distance_to(sp) > 6.0
                        if bad:
                                _release(u)
                                post_fixes += 1
                                oa.remove_at(k)
                        else:
                                seen[si] = true



func _posts(dt: float) -> void :
        var mil: Military = gw.mil
        mil.dig_tick(dt)
        _occ.clear()
        for u0: Unit in units:
                if u0.post != null and u0.alive():
                        var oa: Array = _occ.get(u0.post, [])
                        if oa.is_empty():
                                _occ[u0.post] = oa
                        oa.append(u0)
        for f0: Facility in mil.facilities:
                if is_trench(f0.kind) and not _occ.has(f0):
                        _occ[f0] = []
        _check_posts()
        for f: Facility in mil.facilities:
                if not is_trench(f.kind):
                        continue
                var occ: Array[Unit] = occupants(f)
                if not mil.alive(f):
                        for u: Unit in occ:
                                _release(u)
                        continue

                if f.is_line():
                        for u: Unit in occ:
                                if u.entrenched and not mil.fort_cells.has(Vector2i(floori(u.pos.x / GameWorld.CELL), floori(u.pos.y / GameWorld.CELL))):
                                        _release(u)
                elif f.kind == Facility.Kind.DUGOUT:
                        for u: Unit in occ:
                                if u.entrenched:
                                        u.hp = minf(u.max_hp, u.hp + 1.5)
        _dig_in_builds()
        for c: Country in gw.countries:
                if c.eliminated or not c.army_defend:
                        continue

                for f2: Facility in mil.facilities:
                        if f2.country_id == c.id and is_trench(f2.kind) and mil.alive(f2) and not f2.post_off and occupants(f2).size() < capacity(f2):
                                if occupy(f2, c.id, true) == 0:
                                        break
                _react(c)
        _occ.clear()



func _react(c: Country) -> void :
        for city_id in c.city_ids:
                var city: City = gw.cities[city_id]
                var cp: Vector2 = Vector2(city.center * GameWorld.CELL)
                var threat: Unit = null
                for o: Unit in _near(cp, 450.0):
                        if o.alive() and o.ground() and _hostile(c.id, o.country_id) and o.pos.distance_squared_to(cp) < 450.0 * 450.0 and (c.is_player or fire.sees(c.id, o)):
                                threat = o
                                break
                if threat == null:
                        continue
                var sent: int = 0
                for u: Unit in _near(cp, 1600.0):
                        if sent >= 6:
                                break
                        if u.country_id != c.id or not u.alive() or not u.ground() or u.post != null or u.target_city >= 0 or u.target != null or u.indirect() or u.op_on:
                                continue
                        if gw.hold != null and gw.hold.holds_unit(u):
                                continue
                        if c.is_player and u.home != null and gw.ops != null and gw.ops.auto_next.has("h%d" % u.home.id):
                                continue
                        if u.state != Unit.State.IDLE or u.pos.distance_squared_to(cp) > 1600.0 * 1600.0:
                                continue
                        if not c.is_player and u.pos.distance_squared_to(cp) > 600.0 * 600.0 and u.pos.distance_squared_to(threat.pos) > 600.0 * 600.0:
                                continue
                        var meet: Vector2 = threat.pos.lerp(cp, 0.3)
                        if ground_at(meet) != 1:
                                meet = gw.econ.land_point(meet, 6)
                        u.path = gw.econ.nav_path(u.pos, meet)
                        u.pi = 0
                        u.state = Unit.State.MOVE
                        sent += 1




static func build_def(id: String) -> Dictionary:
        for b: Dictionary in BUILDS:
                if String(b["id"]) == id:
                        return b
        return BUILDS[0]


func build_of(f: Facility) -> Dictionary:
        return build_def(f.army_build if f.army_build != "" else "mix")




func set_build(f: Facility, id: String) -> String:
        if f == null or f.kind != Facility.Kind.BARRACKS:
                return Loc.t("Это не казармы")
        if build_def(id)["id"] != id:
                return Loc.t("Нет такой сборки")
        _number(f)
        f.army_build = id
        f.prod_type = 0
        f.filled = false

        for u: Unit in units:
                if u.home == f and u.alive() and u.type != Unit.Type.FPV:
                        u.kit = _kit_for(f, u.type, u.id)
        return ""



func _number(f: Facility) -> void :
        if gw.net_driven and not gw.net_sim:
                return
        var n: int = 0
        var clash: bool = false
        for o: Facility in gw.mil.facilities:
                if o.kind == Facility.Kind.BARRACKS and o.country_id == f.country_id and o != f:
                        n = maxi(n, o.army_no)
                        if o.army_no == f.army_no:
                                clash = true
        if f.army_no > 0 and not clash:
                return
        f.army_no = n + 1



func _ensure_build(f: Facility, c: Country) -> void :
        _number(f)
        if f.army_build != "" or c.is_player:
                return
        var plan: Array = [["motor", "motor", "armor", "support"], ["motor", "support", "assault", "at", "armor"], ["assault", "support", "armor", "at", "support", "motor"]][GameConfig.diff_of(c)]
        f.army_build = String(plan[(f.army_no - 1) % plan.size()])


func _have(f: Facility) -> Dictionary:
        var have: Dictionary = {}
        for u: Unit in units:
                if u.home == f and u.alive() and u.type != Unit.Type.FPV:
                        have[u.type] = int(have.get(u.type, 0)) + 1
        if gw.naval != null:
                for u2: Unit in gw.naval.aboard_of(f):
                        have[u2.type] = int(have.get(u2.type, 0)) + 1
        return have



func _shortage(f: Facility) -> Array:
        var have: Dictionary = _have(f)
        var out: Array = []
        var score: Array = []
        for e: Array in build_of(f)["comp"]:
                var t: int = int(e[0])
                var want: int = int(e[1])
                var h: int = int(have.get(t, 0))
                if h < want:
                        out.append(t)
                        score.append(float(want - h) / float(want))
        var idx: Array = range(out.size())
        idx.sort_custom( func(a: int, b: int) -> bool: return float(score[a]) > float(score[b]))
        var res: Array = []
        for i: int in idx:
                res.append(out[i])
        return res



func _affordable_alt(f: Facility, c: Country, t: int) -> int:
        if f.prod_type == 0 and (f.army_build == "" or f.army_build == "mix"):


                for t2: int in [Unit.Type.INFANTRY, Unit.Type.TANK, Unit.Type.ATGM]:
                        if t2 != t and c.has_res(unit_cost(t2)):
                                return t2
                return -1
        if f.prod_type != 0:
                return -1
        for t2: int in _shortage(f):
                if t2 != t and c.has_res(unit_cost(t2)):
                        return t2
        return -1



func _kit_for(f: Facility, t: int, uid: int = -1) -> int:
        if uid < 0:
                uid = _next_id - 1
        var b: Dictionary = build_of(f)
        var style: String = String(b["style"])
        var k: int = 0
        if t == Unit.Type.ASSAULT:
                k |= Unit.KIT_GREN | Unit.KIT_SMOKE
        if bool(b["smoke"]) and (t == Unit.Type.INFANTRY or t == Unit.Type.IFV):
                k |= Unit.KIT_SMOKE
        if t == Unit.Type.INFANTRY or t == Unit.Type.ASSAULT:

                var every: int = 2 if style == "assault" else 3
                if uid % every == 0:
                        k |= Unit.KIT_FPV
        return k


func _fpv_bonus(country_id: int) -> int:
        if _fgrid_t > -50.0:
                return int(_fpv_b.get(country_id, 0))
        for f: Facility in gw.mil.facilities:
                if f.kind == Facility.Kind.BARRACKS and f.country_id == country_id and int(build_of(f)["fpv"]) > 0 and gw.mil.alive(f):
                        return 1
        return 0


func _dig_time(u: Unit) -> float:
        if u.home != null and String(build_of(u.home)["style"]) == "at":
                return DIG_T * 0.45
        return DIG_T



func unit_cost(t: int) -> Dictionary:

        var sp: Dictionary = SPEC[t]
        var out: Dictionary = (Economy.res_cost(TYPE_KEY[t]) as Dictionary).duplicate()
        if out.is_empty():
                if int(sp["ti"]) > 0:
                        out["titanium"] = int(sp["ti"])
                if int(sp["food"]) > 0:
                        out["food"] = int(sp["food"])
        out["money"] = int(sp["cost"])
        return out




func _dig_in_builds() -> void :
        var mil: Military = gw.mil
        for f: Facility in mil.facilities:
                if f.kind != Facility.Kind.BARRACKS or f.army_build != "at" or not mil.alive(f):
                        continue
                for t: Facility in _near_fac(f.center_px(), 520.0):
                        if t.country_id != f.country_id or not is_trench(t.kind) or t.post_off or not mil.alive(t):
                                continue
                        if t.center_px().distance_squared_to(f.center_px()) > 520.0 * 520.0 or occupants(t).size() >= capacity(t):
                                continue
                        if occupy(t, f.country_id, true, f) == 0:
                                break





func _fire_moving(u: Unit, t: Object) -> void :
        if u.fire_cd > 0.0:
                return
        var sp: Dictionary = SPEC[u.type]
        u.fire_cd = float(sp["cd"]) * (1.6 if u.vehicle() else 2.2)
        if u.type == Unit.Type.ATGM:
                return
        var tp: Vector2 = _target_pos(t, u.pos)
        _shoot(u, tp, t, float(sp["dmg"]), int(sp["hit"]) * 2 / 3)


func _throw_grenade(u: Unit, tp: Vector2) -> void :
        var to: Vector2 = tp + Vector2(fire.rfr(-3.0, 3.0), fire.rfr(-3.0, 3.0))
        grenades.append({"from": u.pos + Vector2(0, -1), "to": to, "t": 0.0, "dur": 0.45 + u.pos.distance_to(to) / 70.0, "c": u.country_id})


func _update_grenades(dt: float) -> void :
        for k in range(grenades.size() - 1, -1, -1):
                var g: Dictionary = grenades[k]
                g["t"] = float(g["t"]) + dt
                if float(g["t"]) < float(g["dur"]):
                        continue
                var p: Vector2 = g["to"]
                grenades.remove_at(k)
                if gw._on_screen(p, 40.0):
                        gw.fx.spawn("grenade_burst" if gw.fx.atlas_of.has("grenade_burst") else "explosion_s", p.round(), 6)
                Sfx.play("grenade", p)
                var c: int = int(g["c"])
                for o: Unit in _near(p, 10.0):
                        if o.alive() and o.ground() and _hostile(c, o.country_id):
                                var d: float = o.pos.distance_to(p)
                                if d <= 10.0:
                                        _damage(o, GREN_DMG * (1.0 if d < 5.0 else 0.55), c, p, true)

                var cell: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
                if gw.mil.fort_cells.has(cell):
                        var lf: Facility = gw.mil.fort_cells[cell]
                        if lf.kind == Facility.Kind.TRENCH_H and _hostile(c, lf.country_id) and fire.ri(4) == 0:
                                gw.mil.remove_line_cell(lf, cell)



func throw_smoke(p: Vector2) -> void :
        for s: Array in smokes:
                if (s[0] as Vector2).distance_squared_to(p) < 100.0:
                        return
        smokes.append([p, gw.game_time + SMOKE_LIFE])
        if gw._on_screen(p, 60.0):
                gw.fx.spawn("smoke_screen_loop", p.round(), 5, gw.game_time + SMOKE_LIFE, true)
                Sfx.play("grenade", p, -10.0)


func in_smoke(p: Vector2) -> bool:
        if gw.ops != null and gw.ops.smoke_at(p):
                return true
        for s: Array in smokes:
                var d: Vector2 = p - (s[0] as Vector2)
                if d.x * d.x / 256.0 + d.y * d.y / 81.0 <= 1.0:
                        return true
        return false





func army_info(f: Facility) -> Dictionary:
        _number(f)
        var b: Dictionary = build_of(f)
        var n: int = 0
        var hp: float = 0.0
        var mhp: float = 0.0
        var reload: float = 0.0
        var by_type: Dictionary = {}
        for u: Unit in units:
                if u.home != f or not u.alive() or u.type == Unit.Type.FPV:
                        continue
                n += 1
                hp += u.hp
                mhp += u.max_hp
                by_type[u.type] = int(by_type.get(u.type, 0)) + 1
                if u.type == Unit.Type.MLRS and u.fire_cd > 0.0:
                        reload = maxf(reload, u.fire_cd)
        var comp: PackedStringArray = PackedStringArray()
        for e: Array in b["comp"]:
                comp.append("%s %d/%d" % [String(SPEC[int(e[0])]["name"]), int(by_type.get(int(e[0]), 0)), int(e[1])])
        var ammo: String = ""
        if by_type.has(Unit.Type.MLRS):
                ammo = Loc.t("РСЗО: ПЕРЕЗАРЯДКА %d С") % int(ceilf(reload)) if reload > 0.0 else Loc.t("РСЗО: ГОТОВА К ЗАЛПУ")
        return {"no": f.army_no, "build": String(b["id"]), "wait": Loc.msg(wait_reason.get(f, "")) if n < BARRACKS_CAP and f.prod_type != 3 else "", "name": String(b["name"]), "title": String(b["title"]), 
                "n": n, "cap": BARRACKS_CAP, "hp": hp / maxf(1.0, mhp), "state": army_status(f), "ammo": ammo, 
                "comp": " · ".join(comp), "recon": fire.recon_count(f)}



func army_status(f: Facility) -> String:
        var t: String = tac.status(f)
        if t != "":
                return t
        var posts: int = 0
        var fighting: int = 0
        var n: int = 0
        for u: Unit in units:
                if u.home != f or not u.alive() or u.type == Unit.Type.FPV:
                        continue
                n += 1
                if u.post != null:
                        posts += 1
                if u.state == Unit.State.FIGHT:
                        fighting += 1
                if u.state == Unit.State.SIEGE:
                        return Loc.t("ОСАДА")
        var why: String = Loc.msg(wait_reason.get(f, ""))
        if n == 0:
                return Loc.t("НЕТ ВОЙСК") if f.prod_type == 3 else (why if why != "" else Loc.t("ФОРМИРУЕТСЯ"))
        if fighting > 0:
                return Loc.t("БОЙ")
        if fire.supporting(f):
                return Loc.t("ОГНЕВАЯ ПОДДЕРЖКА")
        if posts > 0:
                return Loc.t("В ОКОПАХ: %d") % posts
        if gw.ops != null and gw.ops.list.has(f):

                var ost: String = Loc.msg((gw.ops.list[f] as Dictionary).get("state", ""))
                if ost != "":
                        return ost.to_upper()
        if why != "" and n < BARRACKS_CAP and f.prod_type != 3:
                return why
        return Loc.t("В РЕЗЕРВЕ")





func units_of(f: Facility) -> Array[Unit]:
        var out: Array[Unit] = []
        if f == null:
                return out
        for u: Unit in units:
                if u.home == f and u.alive() and u.type != Unit.Type.FPV:
                        out.append(u)
        return out



func cap_of(f: Facility) -> int:
        var c: Country = gw.country_by_id(f.country_id)
        return BARRACKS_CAP - (0 if c == null or c.is_player else GameConfig.ai_cap_cut(gw.game_time))


func refill_on(f: Facility) -> bool:
        var c: Country = gw.country_by_id(f.country_id)
        return f.auto_refill or c == null or not c.is_player





func refill_block(f: Facility) -> String:
        if f == null or f.kind != Facility.Kind.BARRACKS or gw.mil == null:
                return ""
        if not gw.mil.alive(f):
                return Loc.t("казармы восстанавливаются") if f.restore_t > 0.0 else Loc.t("казармы разрушены — восстановите")
        if f.prod_type == 3:
                return Loc.t("набор остановлен — включите пополнение")
        if f.halted:
                return Loc.t("казармы на паузе — нажмите ПУСК")
        if f.producing or units_of(f).size() >= cap_of(f):
                return ""
        if f.filled and not refill_on(f):
                return Loc.t("пополнение выключено")
        var first: String = wait_res(f)
        if first == "":
                return ""
        if first == "food":
                return Loc.t("нет еды — постройте колхоз")
        if first == "money":
                return Loc.t("нет денег")
        return Loc.t("нет %s") % res_gen(first)




func wait_res(f: Facility) -> String:
        var w: Variant = wait_reason.get(f, "")
        if Loc.is_msg(w):
                return String(((w as Array)[1] as Dictionary).get("res", "")) if Loc.id(w) == "НЕ ХВАТАЕТ: {miss}" else ""
        var why: String = String(w)
        if not why.begins_with("НЕ ХВАТАЕТ: "):
                return ""
        var ru: String = why.trim_prefix("НЕ ХВАТАЕТ: ").get_slice(",", 0).strip_edges().get_slice(" ", 0)
        var k: String = Country.res_key_ru(ru)
        return k if k != "" else ru



static func res_gen(key: String) -> String:
        return String(LOC_RES_GEN.get(key, Country.RES_RU.get(key, key)))





func set_auto_refill(f: Facility, on: bool) -> String:
        if f == null or f.kind != Facility.Kind.BARRACKS:
                return Loc.t("Это не казармы")
        f.auto_refill = on
        if on and f.prod_type == 3:
                f.prod_type = 0
        var c: Country = gw.country_by_id(f.country_id)
        if c != null and c.is_player:
                _number(f)
                gw.say(c, Loc.mk("Армия №%d: %s", [f.army_no, Loc.t("автопополнение включено") if on else Loc.t("автопополнение выключено")]))
        return ""




func refill_status(f: Facility, key_word: bool = false) -> String:
        if f == null or f.kind != Facility.Kind.BARRACKS:
                return ""
        if not gw.mil.alive(f):
                return Loc.t("КАЗАРМЫ РАЗРУШЕНЫ")
        if f.prod_type == 3:
                return Loc.t("НАБОР ОСТАНОВЛЕН")
        if f.halted:
                return Loc.t("ПАУЗА ЦЕХА")
        var on: bool = refill_on(f)
        if f.producing and not f.queued.is_empty():
                var tt: int = clampi(int(f.queued[0]), 0, SPEC.size() - 1)
                var left: float = (float(SPEC[tt]["time"]) * (REFILL_SLOW if f.prod_refill else 1.0) - f.prod_t) / (gw.ops.refill_boost(f) if gw.ops != null else 1.0)
                var s: int = maxi(0, ceili(left))
                if key_word and f.prod_refill:
                        return Loc.t("ПОПОЛНЕНИЕ ВКЛ · следующий через %d:%02d") % [s / 60, s % 60]
                return (Loc.t("ПОПОЛНЕНИЕ: АВТО · следующий через %d:%02d") if f.prod_refill else Loc.t("НАБОР · следующий через %d:%02d")) % [s / 60, s % 60]
        if units_of(f).size() >= cap_of(f):
                if key_word and on:
                        return Loc.t("ПОПОЛНЕНИЕ ВКЛ · армия полная")
                return Loc.t("ПОПОЛНЕНИЕ: АВТО · армия полная") if on else Loc.t("ПОПОЛНЕНИЕ ВЫКЛ · армия полная")
        if f.filled and not on:
                return Loc.t("ПОПОЛНЕНИЕ ВЫКЛ")
        var first: String = wait_res(f)
        if first != "":
                return Loc.t("ПАУЗА: нет %s") % res_gen(first)
        return (Loc.t("ПОПОЛНЕНИЕ ВКЛ") if key_word else Loc.t("ПОПОЛНЕНИЕ: АВТО")) if f.filled else Loc.t("НАБОР")





func army_brief(f: Facility) -> Dictionary:
        if f == null or f.kind != Facility.Kind.BARRACKS:
                return {}
        _number(f)
        var b: Dictionary = build_of(f)
        var have: Dictionary = {}
        var n: int = 0
        var posts: int = 0
        var hp: float = 0.0
        var mhp: float = 0.0
        var at_sea: Array = gw.naval.aboard_of(f) if gw.get("naval") != null else []
        for src: Array in [units, at_sea]:
                for u: Unit in src:
                        if u.home != f or not u.alive() or u.type == Unit.Type.FPV:
                                continue
                        n += 1
                        hp += u.hp
                        mhp += u.max_hp
                        have[u.type] = int(have.get(u.type, 0)) + 1
                        if u.post != null:
                                posts += 1
        var comp: Array = []
        var food_need: int = 0
        var want: Array = b["comp"]
        if want.is_empty():
                for t: int in have:
                        comp.append({"type": t, "type_name": String(SPEC[t]["name"]), "have": int(have[t]), "want": int(have[t]), "icon": UNIT_ICONS[t]})
        else:
                for e: Array in want:
                        var t2: int = int(e[0])
                        var w: int = int(e[1])
                        var h2: int = int(have.get(t2, 0))
                        comp.append({"type": t2, "type_name": String(SPEC[t2]["name"]), "have": h2, "want": w, "icon": UNIT_ICONS[t2]})
                        if h2 < w:
                                food_need += int(unit_cost(t2).get("food", 0)) * (w - h2)
        var st: int = clampi(f.stance, 0, 2)
        return {"no": f.army_no, "fid": f.id, "build": String(b["id"]), "build_name": String(b["name"]), "build_icon": String(b["icon"]), 
                "n": n, "cap": cap_of(f), "hp_frac": hp / maxf(1.0, mhp) if n > 0 else 0.0, "stance": st, "stance_name": String(Operations.AutoCmd.STANCE_NAMES[st]), 
                "order_text": _order_text(f, posts, n), "state": army_status(f), "posts": posts, "comp": comp, 
                "refill_text": refill_status(f), "refill_on": refill_on(f), "auto_refill": f.auto_refill, "food_need": food_need, 
                "at_sea": at_sea.size(), "landing": gw.naval.landing_info(f) if gw.get("naval") != null else {}}



func _order_text(f: Facility, posts: int, n: int) -> String:
        if gw.ops != null and gw.ops.has_method("doing_text"):
                return gw.ops.doing_text(f)
        if gw.ops != null and gw.ops.list.has(f):
                var op: Dictionary = gw.ops.list[f]
                return "%s %s" % [Operations.KIND_NAMES[int(op["kind"])], gw.ops._where(op)]
        if n == 0:
                return Loc.t("НЕТ ВОЙСК")
        if posts >= n:
                return Loc.t("В ОКОПАХ: %d") % posts
        var t: String = [Loc.t("ЖДУТ ПРИКАЗА"), Loc.t("ДЕРЖАТ РАЙОН"), Loc.t("НАСТУПАЮТ")][clampi(f.stance, 0, 2)]
        if posts > 0:
                t += Loc.t(" · В ОКОПАХ %d") % posts
        return t



func support_auto(country_id: int) -> bool:
        return not fire.support_off.has(country_id)


func toggle_support(country_id: int) -> bool:
        if fire.support_off.has(country_id):
                fire.support_off.erase(country_id)
        else:
                fire.support_off[country_id] = true
        return support_auto(country_id)



func busy() -> bool:
        return not units.is_empty() or not grenades.is_empty() or fire.busy()



func food_buffer(c: Country) -> int:
        return (count_units(c.id) + 3) / 3 * 3



func _stat_spend(c: Country, cost: Dictionary) -> void :
        if gw.econ == null:
                return
        if gw.econ.has_method("stat_add"):
                gw.econ.stat_add(c, "spend", "army", int(cost.get("money", 0)))
        if gw.econ.has_method("stat_res"):
                for r: String in cost:
                        if r != "money":
                                gw.econ.stat_res(c, r, "army", - int(cost[r]))



func safe_point(base: Vector2, off: Vector2) -> Vector2:
        var d: WorldData = gw.data
        var c: = Vector2i(floori(base.x / GameWorld.CELL), floori(base.y / GameWorld.CELL))
        if not d.inside(c.x, c.y) or d.has_flag(c.x, c.y, WorldData.F_BRIDGE) or Biome.is_water(d.get_biome(c.x, c.y)):
                return base
        var p: Vector2 = base + off
        var q: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
        if not d.inside(q.x, q.y) or d.has_flag(q.x, q.y, WorldData.F_BRIDGE):
                return base
        if Biome.is_water(d.get_biome(q.x, q.y)):
                var lp: Vector2 = gw.econ.land_point(p, 3) if gw.econ.has_method("land_point") else base
                var lc: = Vector2i(floori(lp.x / GameWorld.CELL), floori(lp.y / GameWorld.CELL))
                if d.inside(lc.x, lc.y) and not Biome.is_water(d.get_biome(lc.x, lc.y)) and lp.distance_to(base) <= off.length() + 8.0:
                        return lp
                return base
        return p




func save_state() -> Dictionary:
        return {"a": Save.dump(self), "t": Save.dump(tac), "f": Save.dump(fire, ["_shots"])}


func load_state(d: Dictionary) -> void :
        Save.fill(self, d.get("a", {}))
        Save.fill(tac, d.get("t", {}))
        Save.fill(fire, d.get("f", {}))







func _build_grid() -> void :
        _grid.clear()
        _gmask.clear()
        _hmask_cache.clear()
        _fpv_fly.clear()
        # Снапшот для нативного поиска целей (те же фильтры, что и у сетки:
        # живые, не FPV; порядок — как в массиве units).
        var nat_on: bool = _nat != null
        var nat_ids := PackedInt32Array()
        var nat_xs := PackedFloat32Array()
        var nat_ys := PackedFloat32Array()
        var nat_cs := PackedInt32Array()
        var nat_vs := PackedInt32Array()
        if nat_on:
                _nat_u.clear()
        for u: Unit in units:
                if not u.alive():
                        continue
                if u.type == Unit.Type.FPV:
                        _fpv_fly[u.country_id] = int(_fpv_fly.get(u.country_id, 0)) + 1
                        continue
                var k: = Vector2i(floori(u.pos.x / GRID_PX), floori(u.pos.y / GRID_PX))
                var a: Array = _grid.get(k, [])
                if a.is_empty():
                        _grid[k] = a
                a.append(u)
                var cid: int = u.country_id
                _gmask[k] = int(_gmask.get(k, 0)) | ((1 << cid) if cid >= 0 and cid < 63 else -1)
                if nat_on:
                        nat_ids.append(u.id)
                        nat_xs.append(u.pos.x)
                        nat_ys.append(u.pos.y)
                        nat_cs.append(cid)
                        nat_vs.append(1 if u.vehicle() else 0)
                        _nat_u[u.id] = u
        if nat_on:
                _nat.push_units(nat_ids, nat_xs, nat_ys, nat_cs, nat_vs)
                # дымы: операции (круги) + армейские (эллипсы 16x9)
                var circ := PackedFloat64Array()
                if gw.ops != null:
                        for z: Dictionary in gw.ops.zones:
                                if int(z["k"]) == Operations.Order.SMOKE:
                                        var sp: Vector2 = z["pos"]
                                        circ.append(sp.x)
                                        circ.append(sp.y)
                                        circ.append(float(z["r"]))
                var ell := PackedFloat64Array()
                for s: Array in smokes:
                        var sp2: Vector2 = s[0]
                        ell.append(sp2.x)
                        ell.append(sp2.y)
                _nat.push_smokes(circ, ell)
        if gw.game_time - _fgrid_t < 1.0 and gw.game_time >= _fgrid_t:
                return
        _fgrid_t = gw.game_time
        _fgrid.clear()
        _flines.clear()
        _fpv_b.clear()
        for f: Facility in gw.mil.facilities:
                if f.kind == Facility.Kind.BARRACKS and int(build_of(f)["fpv"]) > 0 and gw.mil.alive(f):
                        _fpv_b[f.country_id] = 1
                if f.parent != null or f.kind == Facility.Kind.TRENCH_H:
                        continue
                if f.is_line():
                        _flines.append(f)
                        continue
                var c: Vector2 = f.center_px()
                var k2: = Vector2i(floori(c.x / GRID_PX), floori(c.y / GRID_PX))
                var b: Array = _fgrid.get(k2, [])
                if b.is_empty():
                        _fgrid[k2] = b
                b.append(f)




func _near(p: Vector2, r: float) -> Array:
        var out: Array = []
        var x0: int = floori((p.x - r) / GRID_PX)
        var x1: int = floori((p.x + r) / GRID_PX)
        var y0: int = floori((p.y - r) / GRID_PX)
        var y1: int = floori((p.y + r) / GRID_PX)
        for cy in range(y0, y1 + 1):
                for cx in range(x0, x1 + 1):
                        var a: Array = _grid.get(Vector2i(cx, cy), [])
                        if not a.is_empty():
                                out.append_array(a)
        return out


func _near_fac(p: Vector2, r: float) -> Array:
        var out: Array = _flines.duplicate()
        var x0: int = floori((p.x - r) / GRID_PX)
        var x1: int = floori((p.x + r) / GRID_PX)
        var y0: int = floori((p.y - r) / GRID_PX)
        var y1: int = floori((p.y + r) / GRID_PX)
        for cy in range(y0, y1 + 1):
                for cx in range(x0, x1 + 1):
                        var a: Array = _fgrid.get(Vector2i(cx, cy), [])
                        if not a.is_empty():
                                out.append_array(a)
        return out









const DECK_R: int = 2
const TEETH_CRUSH: float = 30.0
const WAIT_MAX: float = 150.0
const NOWAIT_T: float = 4.0
const BRIDGE_WAIT_R: int = 4
var _rr_pend: bool = false
var w29: Dictionary = {"drowned": 0, "pushed": 0, "deck_back": 0, "rerouted": 0, "blocked": 0, "wait_ok": 0, "giveup": 0, "snap": 0, "trucks_lost": 0}




func ground_at(p: Vector2) -> int:
        var d: WorldData = gw.data
        var cx: int = floori(p.x / GameWorld.CELL)
        var cy: int = floori(p.y / GameWorld.CELL)
        if not d.inside(cx, cy):
                return 0
        if not Biome.is_water(d.biome[cy * d.w + cx]):
                return 1
        var stand: bool = false
        for dy in range( - DECK_R, DECK_R + 1):
                for dx in range( - DECK_R, DECK_R + 1):
                        var x: int = cx + dx
                        var y: int = cy + dy
                        if not d.inside(x, y):
                                continue
                        var i: int = y * d.w + x
                        if (d.flags[i] & WorldData.F_BRIDGE) == 0:
                                continue
                        var b: Bridge = gw.bridge_cells.get(i, null)
                        if b == null:
                                continue
                        if b.passable() or b.pont == 2:
                                return 1
                        if not stand and absi(dx) <= 1 and absi(dy) <= 1:
                                var k: int = b.cells.find(Vector2i(x, y))
                                stand = k >= 0 and k < b.collapse.size() and _span_ok(b, k)
        return 2 if stand else 0



func _dry_step(u: Unit, q: Vector2, to: Vector2, step: float) -> bool:
        if u.type == Unit.Type.FPV or u.type == Unit.Type.RECON:
                return true
        var nxt: Vector2 = q if to.length() <= step + 0.5 else u.pos + to / to.length() * step
        var gn: int = ground_at(nxt)
        if gn == 1:
                return true
        var g0: int = ground_at(u.pos)
        if gn == 2 and g0 == 2:
                return true
        if g0 == 0 and _deck_at(u.pos) == null:

                u.pos = gw.econ.land_point(u.pos, 8)
                w29["snap"] = int(w29["snap"]) + 1
        return false




func _blocked(u: Unit, st0: float, dt: float) -> void :
        var b: Bridge = _deck_at(u.pos)
        if b != null and not b.passable() and b.pont != 2 and _deck_back(u, b, b.cell_at_px(u.pos)):
                return
        var first: bool = st0 <= 0.0
        if first:
                w29["blocked"] = int(w29["blocked"]) + 1
        if first or fmod(st0, 2.0) < dt:
                if _reroute(u):
                        if not first:
                                w29["wait_ok"] = int(w29["wait_ok"]) + 1
                        return





                if st0 >= NOWAIT_T and not _rr_pend and not _bridge_wait(u):
                        u.pi = u.path.size()
                        w29["giveup_water"] = int(w29.get("giveup_water", 0)) + 1
                        return
        if st0 > WAIT_MAX:
                u.pi = u.path.size()
                w29["giveup"] = int(w29["giveup"]) + 1




func _bridge_wait(u: Unit) -> bool:
        var d: WorldData = gw.data
        var q: Vector2 = u.path[u.pi] if u.pi < u.path.size() else u.pos
        var ahead: Vector2 = u.pos + (q - u.pos).limit_length(12.0)
        for p: Vector2 in [u.pos, ahead]:
                var cx: int = floori(p.x / GameWorld.CELL)
                var cy: int = floori(p.y / GameWorld.CELL)
                for dy in range( - BRIDGE_WAIT_R, BRIDGE_WAIT_R + 1):
                        for dx in range( - BRIDGE_WAIT_R, BRIDGE_WAIT_R + 1):
                                var x: int = cx + dx
                                var y: int = cy + dy
                                if not d.inside(x, y):
                                        continue
                                var b: Bridge = gw.bridge_cells.get(y * d.w + x, null)
                                if b != null and not b.passable() and b.pont != 2:
                                        return true
        return false



func _reroute(u: Unit) -> bool:
        _rr_pend = false
        if u.path.is_empty():
                return false
        var goal: Vector2 = u.path[u.path.size() - 1]
        if ground_at(goal) != 1:
                goal = gw.econ.land_point(goal, 6)
                if ground_at(goal) != 1:
                        return false
        var np: PackedVector2Array = gw.econ.army_path(u.pos, goal)
        if not gw.econ.nav_last_ok or np.is_empty():
                _rr_pend = gw.econ.nav_last_pending
                return false
        np[np.size() - 1] = goal
        var deck: bool = ground_at(u.pos) == 2
        var prev: Vector2 = u.pos
        var run: float = 0.0
        for p: Vector2 in np:
                if run > 600.0:
                        break
                run += prev.distance_to(p)
                var n: int = maxi(1, int(prev.distance_to(p) / 2.0))
                for s in range(1, n + 1):
                        var g: int = ground_at(prev.lerp(p, float(s) / float(n)))
                        if g == 0 or (g == 2 and not deck):
                                return false
                        if g == 1:
                                deck = false
                prev = p
        u.path = np
        u.pi = 0
        w29["rerouted"] = int(w29["rerouted"]) + 1
        return true



func _deck_at(p: Vector2) -> Bridge:
        var d: WorldData = gw.data
        var cx: int = floori(p.x / GameWorld.CELL)
        var cy: int = floori(p.y / GameWorld.CELL)
        if not d.inside(cx, cy) or not Biome.is_water(d.biome[cy * d.w + cx]):
                return null
        for dy in range(-1, 2):
                for dx in range(-1, 2):
                        if d.inside(cx + dx, cy + dy):
                                var b: Bridge = gw.bridge_cells.get((cy + dy) * d.w + cx + dx, null)
                                if b != null:
                                        return b
        return null



func _on_deck_of(b: Bridge, p: Vector2) -> bool:
        var d: WorldData = gw.data
        var cx: int = floori(p.x / GameWorld.CELL)
        var cy: int = floori(p.y / GameWorld.CELL)
        if not d.inside(cx, cy) or not Biome.is_water(d.biome[cy * d.w + cx]):
                return false
        for dy in range( - DECK_R, DECK_R + 1):
                for dx in range( - DECK_R, DECK_R + 1):
                        if d.inside(cx + dx, cy + dy) and gw.bridge_cells.get((cy + dy) * d.w + cx + dx, null) == b:
                                return true
        return false





func _bank_px(b: Bridge, end: int, from: Vector2) -> Vector2:
        var n: int = b.cells.size()
        var c: Vector2i = b.cells[end]
        var cp: = Vector2(c * GameWorld.CELL) + Vector2(2, 2)
        if b.pts.size() >= 2:
                var e0: Vector2 = b.pts[0]
                var e1: Vector2 = b.pts[b.pts.size() - 1]
                var e: Vector2 = e0 if e0.distance_squared_to(cp) <= e1.distance_squared_to(cp) else e1
                if ground_at(e) == 1:
                        return e
        var ahead: Vector2 = from
        if n > 1:
                ahead = cp + Vector2((c - (b.cells[1] if end == 0 else b.cells[n - 2])).sign() * GameWorld.CELL)
        var d: WorldData = gw.data
        for r in range(1, 8):
                var best: = Vector2.INF
                var bd: float = INF
                for dy in range( - r, r + 1):
                        for dx in range( - r, r + 1):
                                if maxi(absi(dx), absi(dy)) != r:
                                        continue
                                var q: = c + Vector2i(dx, dy)
                                if d.inside(q.x, q.y) and not Biome.is_water(d.get_biome(q.x, q.y)):
                                        var qp: = Vector2(q * GameWorld.CELL) + Vector2(2, 2)
                                        if qp.distance_squared_to(ahead) < bd:
                                                bd = qp.distance_squared_to(ahead)
                                                best = qp
                if best.is_finite():
                        return best
        return gw.econ.land_point(cp, 10)




func _edge_side(b: Bridge, k: int) -> int:
        var n: int = b.cells.size()
        if k == b.lo:
                if b.lo == 0:
                        return -2
                if b.view(b.lo - 1) == 0:
                        return -1
        if k == b.hi:
                if b.hi == n - 1:
                        return 2
                if b.view(b.hi + 1) == 0:
                        return 1
        return 0



func _deck_back(u: Unit, b: Bridge, k: int) -> bool:
        var n: int = b.cells.size()
        var first: int = -1 if k < (b.lo + b.hi) / 2 else 1
        for dir: int in [first, - first]:
                var ok: bool = true
                var j: int = k + dir
                var pts: = PackedVector2Array()
                while j >= 0 and j < n:
                        if not _span_ok(b, j):
                                ok = false
                                break
                        pts.append(Vector2(b.cells[j] * GameWorld.CELL) + Vector2(2, 2))
                        j += dir
                if not ok:
                        continue
                pts.append(_bank_px(b, 0 if dir < 0 else n - 1, u.pos))
                u.path = pts
                u.pi = 0
                u.state = Unit.State.MOVE
                u.target = null
                w29["deck_back"] = int(w29["deck_back"]) + 1
                return true
        return false



func _drown(u: Unit, by: int) -> void :
        u.state = Unit.State.DEAD
        u.dead_t = gw.game_time
        u.path = PackedVector2Array()
        if gw.battle_watch != null:
                gw.battle_watch.note(u.pos, 4.0 if u.vehicle() else 2.0, "", u.country_id)
        var c: Country = gw.country_by_id(by)
        if c != null and by != u.country_id:
                c.destroyed += int(SPEC[u.type]["cost"]) + (100 if u.type == Unit.Type.TANK else 0)
        gw.fx.spawn("splash", u.pos.round(), 6)
        if u.vehicle():
                gw.fx.debris_burst(u.pos.round(), 2, false)
        Sfx.play("splash_big", u.pos, -8.0)
        w29["drowned"] = int(w29["drowned"]) + 1






func on_bridge_broken(b: Bridge) -> void :


        if b.cells.is_empty() or b.collapse.size() != b.cells.size():
                return
        var box: = Rect2(Vector2(b.cells[0] * GameWorld.CELL), Vector2.ZERO)
        for c: Vector2i in b.cells:
                box = box.expand(Vector2(c * GameWorld.CELL) + Vector2(4, 4))
        box = box.grow(float(GameWorld.CELL * (DECK_R + 1)))
        var by: int = gw.supply.strike_by if gw.supply != null else 0
        var n: int = b.cells.size()
        for u: Unit in units:
                if not u.alive() or u.type == Unit.Type.FPV or u.type == Unit.Type.RECON:
                        continue
                if box.has_point(u.pos) and _on_deck_of(b, u.pos):
                        var k: int = b.cell_at_px(u.pos)
                        if k >= b.lo and k <= b.hi:
                                var side: int = _edge_side(b, k)
                                if side == 0:
                                        _drown(u, by)
                                        continue
                                w29["pushed"] = int(w29["pushed"]) + 1
                                if absi(side) == 2:
                                        u.pos = _bank_px(b, 0 if side < 0 else n - 1, u.pos)
                                        u.path = PackedVector2Array()
                                        u.pi = 0
                                        continue
                                k = b.lo - 1 if side < 0 else b.hi + 1
                                u.pos = Vector2(b.cells[k] * GameWorld.CELL) + Vector2(2, 2)
                        _deck_back(u, b, k)
                        continue
                if u.pi >= u.path.size():
                        continue
                for j in range(u.pi, u.path.size()):
                        var p: Vector2 = u.path[j]
                        if box.has_point(p) and _on_deck_of(b, p):
                                _reroute(u)
                                break

        if gw.econ == null:
                return
        for ti in range(gw.econ.trucks.size() - 1, -1, -1):
                var t: Dictionary = gw.econ.trucks[ti]
                var tp: Vector2 = t.get("pos", Vector2.INF)
                if not box.has_point(tp) or not _on_deck_of(b, tp):
                        continue
                var k2: int = b.cell_at_px(tp)
                if k2 < b.lo or k2 > b.hi:
                        continue
                var side2: int = _edge_side(b, k2)
                if side2 == 0:
                        gw.econ.refund(t, false)
                        gw.econ.trucks.remove_at(ti)
                        gw.fx.spawn("splash", tp.round(), 6)
                        w29["trucks_lost"] = int(w29["trucks_lost"]) + 1
                elif absi(side2) == 2:
                        t["pos"] = _bank_px(b, 0 if side2 < 0 else n - 1, tp)
                else:
                        t["pos"] = Vector2(b.cells[b.lo - 1 if side2 < 0 else b.hi + 1] * GameWorld.CELL) + Vector2(2, 2)




func _span_ok(b: Bridge, j: int) -> bool:
        if b.view(j) != 0:
                return false
        return not (b.state == Bridge.State.REBUILDING and j < b.collapse.size() and b.t < b.collapse[j] and b.collapse[j] < 100000000.0)




func on_pontoon_sunk(b: Bridge, by: int) -> void :
        if b.cells.is_empty():
                return
        var box: = Rect2(Vector2(b.cells[0] * GameWorld.CELL), Vector2.ZERO)
        for c: Vector2i in b.cells:
                box = box.expand(Vector2(c * GameWorld.CELL) + Vector2(4, 4))
        box = box.grow(float(GameWorld.CELL * (DECK_R + 3)))
        for u: Unit in units:
                if not u.alive() or u.type == Unit.Type.FPV or u.type == Unit.Type.RECON or not box.has_point(u.pos):
                        continue
                if ground_at(u.pos) == 0 and _deck_at(u.pos) == b:
                        _drown(u, by)
                        continue
                for j in range(u.pi, u.path.size()):
                        var p: Vector2 = u.path[j]
                        if box.has_point(p) and _on_deck_of(b, p):
                                _reroute(u)
                                break







func on_barracks_captured(bars: Array, old_id: int, new_id: int) -> int:
        var n_all: int = 0
        var oc: Country = gw.country_by_id(old_id)
        var nc: Country = gw.country_by_id(new_id)
        for f: Facility in bars:
                if f == null or f.kind != Facility.Kind.BARRACKS or f.country_id != new_id:
                        continue
                var old_no: int = f.army_no
                if gw.ops != null:
                        gw.ops.cancel(f)
                tac.stop(f)
                release_posts(f)
                (load("res://game/army_groups.gd") as GDScript).call("_detach", gw, old_id, PackedInt32Array([f.id]))
                f.group_id = -1
                var n: int = 0
                for u: Unit in units:
                        if u.home != f or not u.alive():
                                continue
                        u.country_id = new_id
                        u.target = null
                        u.target_city = -1
                        u.op_on = false
                        u.op_hold = false
                        u.op_move = false
                        if u.type != Unit.Type.FPV:
                                u.path = PackedVector2Array()
                                u.pi = 0
                                if u.state != Unit.State.DEAD:
                                        u.state = Unit.State.IDLE
                                n += 1
                if gw.naval != null:
                        for L: Dictionary in gw.naval.landings:
                                if L["home"] == f:
                                        L["c"] = new_id
                        for u2: Unit in gw.naval.aboard_of(f):
                                u2.country_id = new_id
                                n += 1
                if gw.rail != null and gw.rail.troops != null:
                        gw.rail.troops.on_owner(f, new_id)
                for d: Unit in fire.recon:
                        if d.base == f and d.alive():
                                d.country_id = new_id
                f.army_no = 0
                _number(f)
                n_all += n
                if nc != null:
                        gw.say(nc, Loc.mk("Армия №%d (была №%d %s) перешла к вам с казармами: %d бойцов — без группы, добавьте в группу", [f.army_no, old_no, Loc.name(oc.name) if oc != null else "", n]))
                if oc != null:
                        gw.say(oc, Loc.mk("Армия №%d перешла к %s вместе с казармами (%d бойцов)", [old_no, Loc.name(nc.name) if nc != null else Loc.t("противнику"), n]))
        return n_all




func _guard_foe(u: Unit, o: Unit) -> bool:
        return gw.diplo != null and gw.diplo.rq != null and gw.diplo.rq.guard_hit(u.country_id, o.country_id, u.pos, o.pos)
