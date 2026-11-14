class_name Operations
extends RefCounted
















enum Kind{ATTACK, DEFEND, RETREAT}
enum Order{ARTY, SMOKE, MEDIC, EW = 2}

const KIND_NAMES: Array = ["НАСТУПЛЕНИЕ", "ОБОРОНА", "ОТХОД"]
const KIND_SHORT: Array = ["АТАКА", "ОБОРОНА", "ОТХОД"]
const KIND_ICONS: Array = ["icon_op_attack", "icon_op_defend", "icon_op_retreat"]
const KIND_COLS: Array = ["alert_red", "amber", "intercept_cyan"]
const BAD_COL: String = "ui_steel_mid"
static var MAX_RANGE: float = 3200.0
const MAX_PATH: float = 5600.0
const CITY_PAD: float = 60.0
const HOME_R: float = 50.0
const HEAL_RATE: float = 0.025
const DONE_HOLD: float = 20.0
const RETREAT_AT: float = 0.5
const SHATTER: float = 0.75
const REINF_DT: float = 6.0
const REINF_HOME_R: float = 260.0
const REINF_SQUAD_FAR: float = 500.0
const REINF_FAR: float = 320.0
const TICK: float = 0.5
const AI_DT: float = 3.0

const ORDERS: Array = [
        {"id": "arty", "name": "АРТУДАР", "title": "Артиллерийский удар", "icon": "icon_order_arty", "cd": 90.0, "r": 50.0, "dur": 7.0, "shells": 12, 
                "cost": {"money": 500, "metal": 2}, "cost_far": {"money": 1100, "metal": 2}, 
                "desc": "Налёт по площади: 12 снарядов за 7 с. Своя артиллерия в радиусе — дешевле, без неё — вдвое дороже. Цель должна быть видна и не дальше досягаемости гаубиц от своих войск. Окопы и укрытия снижают урон, но окопы осыпаются."}, 
        {"id": "smoke", "name": "ДЫМ", "title": "Дымовая завеса", "icon": "icon_order_smoke", "cd": 60.0, "r": 60.0, "dur": 20.0, "shells": 0, 
                "cost": {"money": 200}, "cost_far": {"money": 200}, 
                "desc": "Плотный дым на 20 с: внутри и сквозь него почти не стреляют прицельно, не видят дроны и разведка. Помогает штурму пересечь открытое место. Гранаты и артиллерия по площади работают."}, 
        {"id": "medic", "name": "ГОСПИТАЛЬ", "title": "Полевой госпиталь", "icon": "icon_restore", "cd": 120.0, "r": 90.0, "dur": 20.0, "shells": 0, 
                "cost": {"money": 400, "food": 6}, "cost_far": {"money": 400, "food": 6}, 
                "desc": "Медики на 20 с: свои бойцы в круге лечатся (до 30% здоровья, под огнём втрое медленнее), казармы этих армий набирают пополнение в 1.5 раза быстрее. Только рядом со своими войсками."}, 
]
const SHELL_DMG: float = 34.0
const SHELL_BLAST: float = 13.0
const ORDER_NEAR: float = 320.0
const FAR_SPOT: float = 1500.0
const ARTY_REACH: float = 700.0
const WARN_T: float = 1.5
const MEDIC_RATE: float = 0.015
const MEDIC_HIT_K: float = 0.33
const MEDIC_BOOST: float = 1.5
const PROMPT_GAP: float = 60.0
const PROMPT_REPEAT: float = 180.0
const PROMPT_DISMISS: float = 300.0
const PROMPT_SCAN: float = 5.0
const ALL_SPREAD: float = 90.0





const DETOUR_K: float = 2.5
const DETOUR_MIN: float = 1500.0
const SEA_GAIN: float = 0.6
const WARN_ETA: float = 100.0
const WARN_FAR: float = 330.0
const WARN_CITY_GAP: float = 240.0
const WARN_REARM: float = 90.0
const WARN_CLOSE_V: float = 1.5
const STR_W: Array = [4.0, 1.0, 0.0, 1.6, 1.3, 2.4, 1.4, 3.0, 3.5, 0.0]
const STR_CELL: float = 350.0
const AGx = preload("res://game/army_groups.gd")
const AutoCmd = preload("res://game/auto_cmd.gd")

var gw: GameWorld
var list: Dictionary = {}
var zones: Array = []
var ready_at: Dictionary = {}
var orders: Array = ORDERS

var preview_arrow: Dictionary = {}
var preview_order: Dictionary = {}
var _t: float = 0.0
var auto_ctx: bool = false
var _ai_next: Dictionary = {}
var _prev_key: String = ""
var _prev: Dictionary = {}
var _prompt_t: float = -99.0
var _prompted: Dictionary = {}
var _zid: int = 1


var auto_orders: Dictionary = {}
var auto_next: Dictionary = {}


var _prompt_sup: Dictionary = {}
var _prompt_acc: Dictionary = {}
var _prompt_scan_t: float = -99.0
var _prompt_last: String = ""
var _quiet: bool = false







var _from_auto: bool = false




const PENDING: String = "Прокладываем путь…"
const OQ_NOW: int = 1
const OQ_PER_TICK: int = 1
const OQ_TRY: int = 4
var _oq: Array = []
var _q_run: bool = false
var _all_key: String = ""
var _all_prev: Dictionary = {}
var _warned: Dictionary = {}
var _appr: Dictionary = {}
var _wcity: Dictionary = {}
var _urgent: Array = []
var _warn_t: float = 0.0
var _naval_wait: Dictionary = {}
var _str_cache: Dictionary = {}
# Нативный ускоритель (Rust, addons/df_native): wd-скан и плотность целей.
# null, если библиотеки нет под платформу — прежний GDScript-путь.
var _nat: Object = null
var _wd_blocked: PackedByteArray = PackedByteArray()
var _wd_blocked_wh: int = -1


func _init(world: GameWorld) -> void :
        gw = world
        _nat_init()


func _nat_init() -> void :
        if OS.get_environment("DF_NO_NATIVE") == "1":
                return
        if ClassDB.class_exists("DfNative"):
                _nat = ClassDB.instantiate("DfNative")








var sea_force: bool = false


func start(f: Facility, kind: int, target: Vector2, waypoint: Vector2 = Vector2.INF, sea: bool = false) -> String:
        if not sea:
                return _start(f, kind, target, waypoint)
        var was: bool = sea_force
        sea_force = true
        var r: String = _start(f, kind, target, waypoint)
        sea_force = was
        return r


func _start(f: Facility, kind: int, target: Vector2, waypoint: Vector2 = Vector2.INF) -> String:
        var wk: String = _wd_key_of(f)
        if wk != "" and not _wd_force and kind != Kind.RETREAT and not _wd_is_exit(wk, f, target):
                var lw: String = wd_lock(f, kind)
                if lw != "":
                        return lw
        var chk: Dictionary = _check(f, kind, target, waypoint)
        if chk.has("pending"):

                if _q_run or f == null:
                        return PENDING
                queue_order(f, kind, target, [], waypoint, Vector2.INF, true)
                return ""
        if not bool(chk["ok"]):
                return String(chk["why"])
        kind = int(chk["kind"])
        target = chk["target"]
        if not _from_auto:
                auto_next.erase("h%d" % f.id)
                auto_next.erase("k%d" % f.id)
        var pc: Country = gw.country_by_id(f.country_id)
        if pc != null and pc.is_player:
                gw.army.release_posts(f)
        var mem: Array[Unit] = _army(f)
        var a: Army = gw.army
        var city: City = chk["city"]
        if gw.naval != null:
                gw.naval.on_cancel(f)
        if list.has(f):
                _release(list[f], false)
        var ok: bool = true
        a.tac.sea_pref = chk.has("detour") or chk.has("sea_forced")
        a.tac.route_free = true
        var pch: bool = chk.get("pass_chain") is PackedVector2Array and a.tac.chain.is_empty()
        if pch:
                a.tac.chain = chk["pass_chain"]

        var by_rail: bool = chk.has("rail") and gw.rail != null and gw.rail.troops.start(f, mem, city, target, kind, chk["rail"])
        match -99 if by_rail else kind:
                Kind.ATTACK:
                        ok = a.tac.start(f, mem, city, waypoint) if city != null else a.tac.start_area(f, mem, target, waypoint, false)
                Kind.DEFEND:
                        ok = a.tac.start_area(f, mem, target, waypoint, true)
                Kind.RETREAT:
                        a.tac.stop(f)
        a.tac.sea_pref = false
        a.tac.route_free = false
        if pch:
                a.tac.chain = PackedVector2Array()
        if not ok:
                if gw.econ.nav_last_pending:



                        if _q_run:
                                return PENDING
                        queue_order(f, kind, target, [], waypoint, Vector2.INF, true)
                        return ""
                return Loc.t("Нет пути по суше")
        var op: Dictionary = _new_op(f, kind, target, waypoint, city.id if city != null else -1, chk["path"], false)
        list[f] = op
        if wk != "":
                op["wd"] = wk
        if chk.get("home_chain") is PackedVector2Array:
                op["home_chain"] = chk["home_chain"]
        if kind == Kind.RETREAT:
                _send_home(op)
        var c: Country = gw.country_by_id(f.country_id)
        if c != null and c.is_player and not chk.has("naval") and _teeth_on(chk["path"]):
                for u: Unit in mem:
                        if u.ground() and not u.foot():
                                gw.say(c, Loc.mk("Армия №%d: зубы дракона на пути замедлят технику", [f.army_no]))
                                break
        if c != null and c.is_player and not _quiet:
                gw.say(c, Loc.mk("Армия №%d: %s — %s", [f.army_no, KIND_NAMES[kind], _where(op)]))
                Sfx.play("ui_alert", Vector2.INF, -8.0)
        return ""





func front_draw(cid: int, gid: int, pts: PackedVector2Array) -> String:
        var geo: Dictionary = AutoCmd.FrontPlan.front_from_line(gw, cid, gid, pts)
        if not bool(geo.get("ok", false)):
                return String(geo.get("why", "Фронт не назначен"))
        return "" if AutoCmd.FrontPlan.set_front(gw, cid, gid, geo) else Loc.t("Фронт не назначен")


func front_tap(cid: int, gid: int, p: Vector2) -> String:
        var geo: Dictionary = AutoCmd.FrontPlan.front_from_tap(gw, cid, gid, p)
        if not bool(geo.get("ok", false)):
                return String(geo.get("why", "Фронт не назначен"))
        return "" if AutoCmd.FrontPlan.set_front(gw, cid, gid, geo) else Loc.t("Фронт не назначен")



func cancel(f: Facility) -> void :
        if gw.naval != null:
                gw.naval.on_cancel(f)
        var pc: Country = gw.country_by_id(f.country_id)
        if pc != null and pc.is_player:
                auto_next["h%d" % f.id] = gw.game_time
                if list.has(f):
                        _release(list[f], true)
                for u: Unit in _army(f):
                        if u.target_city < 0 or u.state != Unit.State.SIEGE:
                                u.path = PackedVector2Array()
                                u.pi = 0
                                u.op_on = false
                                u.op_hold = false
                                u.op_move = false
                                u.state = Unit.State.IDLE
        for k in range(_oq.size() - 1, -1, -1):
                if int(_oq[k]["fid"]) == f.id:
                        _oq.remove_at(k)
        if not list.has(f):
                return
        var op: Dictionary = list[f]
        _release(op, true)
        list.erase(f)
        var c: Country = gw.country_by_id(int(op["c"]))
        if c != null and c.is_player:
                gw.say(c, Loc.mk("Армия №%d: движение отменено", [f.army_no]))








func of(f: Facility) -> Dictionary:
        if f == null or not list.has(f):
                return {}
        var op: Dictionary = list[f]
        var dt: Array = _doing(f)
        return {"kind": int(op["kind"]), "name": String(dt[0]), "kind_name": KIND_NAMES[int(op["kind"])], "icon": KIND_ICONS[int(op["kind"])], "target": op["target"], 
                "waypoint": op["wp"], "city": int(op["city"]), "state_text": String(dt[1]), "state_kind": state_kind(op["state"]) if String(dt[1]) == Loc.msg(op["state"]) else "", "line": "%s: %s" % [dt[0], dt[1]], "progress": float(op["progress"]), 
                "losses": float(op["losses"]), "front": op["front"], "auto": bool(op["auto"]), "stance_op": bool(op.get("stance", false)), "no": f.army_no, "fid": f.id}



func list_for(country_id: int) -> Array:
        var out: Array = []
        for f: Facility in list:
                if int(list[f]["c"]) == country_id:
                        var d: Dictionary = of(f)
                        d["f"] = f
                        out.append(d)
        out.sort_custom( func(x: Dictionary, y: Dictionary) -> bool: return int(x["no"]) < int(y["no"]))
        return out




func preview(f: Facility, to: Vector2, kind: int = -1, waypoint: Vector2 = Vector2.INF) -> Dictionary:
        if f == null:
                return {"ok": false, "kind": -1, "path": PackedVector2Array(), "text": "", "colour": BAD_COL, "city": -1}
        var key: String = "%d:%d:%d:%d:%s:%d" % [f.id, floori(to.x / 8.0), floori(to.y / 8.0), kind, str(waypoint.round()) if waypoint.is_finite() else "-", int(gw.game_time / 3.0)]
        if key == _prev_key:
                return _prev
        _prev_key = key
        var chk: Dictionary = _check(f, kind, to, waypoint)
        var k: int = int(chk["kind"])
        var path: PackedVector2Array = chk["path"]
        if path.is_empty():
                path = PackedVector2Array([_from(f), to])
        var res: Dictionary = {"ok": bool(chk["ok"]), "kind": k, "path": _simplify(path), "city": (chk["city"] as City).id if chk["city"] != null else -1}
        if not bool(chk["ok"]):
                res["text"] = String(chk["why"])
                res["colour"] = BAD_COL
        else:
                var km: float = float(chk["len"]) / 1000.0
                var mins: float = float(chk["len"]) / maxf(1.0, _speed(f)) / 60.0
                var op_fake: Dictionary = {"kind": k, "city": res["city"], "target": chk["target"]}
                res["text"] = Loc.t("%s %s · %.1f км · ~%d мин") % [KIND_NAMES[k], _where(op_fake), km, maxi(1, roundi(mins))]
                if chk.has("naval"):
                        res["text"] = Loc.t("%s %s · через море%s: десант ~%d мин") % [KIND_NAMES[k], _where(op_fake), (Loc.t(" (по суше %.1f км)") % (float(chk["detour"]) / 1000.0)) if chk.has("detour") else "", 
                                maxi(1, roundi(float((chk["naval"] as Dictionary)["eta"]) / 60.0))]
                        res["naval"] = true
                if chk.has("rail"):
                        res["text"] = Loc.t("%s %s · поездом ~%d мин") % [KIND_NAMES[k], _where(op_fake), maxi(1, roundi(float((chk["rail"] as Dictionary)["eta"]) / 60.0))]
                        res["rail"] = chk["rail"]
                res["colour"] = KIND_COLS[k]
        _prev = res
        return res







func route_kind(f: Facility, to: Vector2, kind: int = -1, waypoint: Vector2 = Vector2.INF, by_sea: bool = false) -> Dictionary:
        var was: bool = sea_force
        sea_force = by_sea or was
        var chk: Dictionary = _check(f, kind, to, waypoint)
        sea_force = was
        var ok: bool = bool(chk["ok"])
        var sea: bool = ok and chk.has("naval")
        var spd: float = maxf(1.0, _speed(f)) if f != null and f.kind == Facility.Kind.BARRACKS else 8.0
        if chk.has("pending"):
                var pd: Dictionary = {"kind": "pending", "why": PENDING, "order": int(chk["kind"]), "path": chk["path"], "len": 0.0, "eta": 0.0, "detour": false, "land_len": 0.0}
                var rh: Dictionary = chk.get("rail_hint", {})
                if bool(rh.get("ok", false)):
                        pd["rail"] = rh
                        pd["eta"] = float(rh["eta"])
                        pd["path"] = rh["path"]
                elif bool(rh.get("denied", false)):
                        pd["rail_denied"] = rh
                return pd
        var out: Dictionary = {"kind": "none" if not ok else ("sea" if sea else "land"), "why": String(chk["why"]), "order": int(chk["kind"]), 
                "path": chk["path"], "len": float(chk["len"]), "eta": float((chk["naval"] as Dictionary)["eta"]) if sea else float(chk["len"]) / spd, 
                "detour": chk.has("detour"), "land_len": float(chk.get("detour", 0.0))}
        if ok and chk.has("rail"):
                out["rail"] = chk["rail"]
                out["eta"] = float((chk["rail"] as Dictionary)["eta"])
        elif ok and chk.has("rail_denied"):
                out["rail_denied"] = chk["rail_denied"]
        return out




func queue_order(f: Facility, kind: int, target: Vector2, cands: Array, wp: Vector2, pos: Vector2, quiet: bool, sea: bool = false) -> void :
        for k in range(_oq.size() - 1, -1, -1):
                if int(_oq[k]["fid"]) == f.id:
                        _oq.remove_at(k)
        _oq.append({"fid": f.id, "kind": kind, "target": target, "cands": cands.duplicate(), "wp": wp, "pos": pos, "quiet": quiet, "t": gw.game_time, "sea": sea})
        var old: Dictionary = list.get(f, {})
        if not old.is_empty() and not bool(old.get("wait", false)):
                _release(old, true)
        var ph: Dictionary = _new_op(f, maxi(0, kind), target, wp, -1, PackedVector2Array(), false)
        ph["wait"] = true
        ph["state"] = Loc.mk("прокладываем путь…")
        for key: String in ["fp", "stance", "retreat_at", "front_take", "held", "peak", "fell_back"]:
                if old.has(key):
                        ph[key] = old[key]
        list[f] = ph


func _queued(f: Facility) -> bool:
        for e: Dictionary in _oq:
                if int(e["fid"]) == f.id:
                        return true
        return false






const HOSTAGE_DT: float = 10.0
var hostage_n: int = 0


func free_hostages() -> int:
        if gw.diplo == null or gw.mil == null or gw.army == null:
                return 0
        var n: int = 0
        for f: Facility in gw.mil.facilities:
                if f.kind != Facility.Kind.BARRACKS or _queued(f):
                        continue


                var op0: Dictionary = list.get(f, {})
                var stale: bool = not op0.is_empty() and int(op0["kind"]) != Kind.RETREAT and not bool(op0.get("wait", false))\
                and (op0["target"] as Vector2).is_finite() and not gw.diplo.may_cross(f.country_id, _owner_at(op0["target"]))
                if (list.has(f) or gw.army.tac.ops.has(f)) and not stale:
                        continue
                var c: Country = gw.country_by_id(f.country_id)
                if c == null or not c.is_player or c.eliminated:
                        continue
                if gw.naval != null and gw.naval.busy(f):
                        continue
                if gw.game_time - float(auto_next.get("h%d" % f.id, -999.0)) < 30.0:
                        continue
                var mem: Array[Unit] = _army(f)
                if mem.is_empty():
                        continue
                var idle: bool = true
                for u: Unit in mem:
                        if not stale and (u.state != Unit.State.IDLE or u.pi < u.path.size()):
                                idle = false
                                break
                if not idle:
                        continue
                var cen: Vector2 = _centre(mem)
                var o: int = _owner_at(cen)
                if o <= 0 or o == f.country_id or gw.diplo.may_cross(f.country_id, o):
                        continue
                var q0: bool = _quiet
                var fa: bool = _from_auto
                _quiet = true
                _from_auto = true
                var why: String = start(f, Kind.RETREAT, Vector2.ZERO)
                if why != "" and why != PENDING:
                        var cl: = Vector2i(floori(cen.x / GameWorld.CELL), floori(cen.y / GameWorld.CELL))
                        var dest: Vector2 = preload("res://game/ad_relocate.gd")._exit_point(gw, f.country_id, cen, cl, 0.0)
                        if _owner_at(dest) == f.country_id:
                                why = start(f, Kind.DEFEND, dest)
                _quiet = q0
                _from_auto = fa
                if why == "" or why == PENDING:
                        n += 1
                        var oc: Country = gw.country_by_id(o)
                        gw.say(c, Loc.mk("Армия №%d выведена с земли %s: нет права прохода", [f.army_no, Loc.name(oc.name) if oc != null else Loc.t("чужой страны")]))
        hostage_n += n
        return n











const WD_DT: float = 2.0
const WD_STILL: float = 3.0
const WD_STUCK: int = 4
const WD_JUMP: int = 3
const WD_MAX: float = 240.0
const WD_WAIT_WAY: float = 60.0


var wd: Dictionary = {}
var wd_stats: Dictionary = {}
var _wd_force: bool = false



func _wd_key_of(f: Facility) -> String:
        if wd.is_empty() or f == null:
                return ""
        for k: String in wd:
                var gg: PackedStringArray = k.split(">")
                if int(gg[0]) != f.country_id:
                        continue
                var land: int = int(gg[1])
                for u: Unit in gw.army.units:
                        if u.home == f and u.alive() and u.ground() and _owner_at(u.pos) == land:
                                return k
        return ""


func _wd_is_exit(k: String, f: Facility, target: Vector2) -> bool:
        var a: Array = ((wd[k] as Dictionary)["a"] as Dictionary).get(str(f.id), [])
        return a.size() >= 2 and Vector2(float(a[0]), float(a[1])).distance_to(target) < 2.0


static func _wd_k(who: int, land: int) -> String:
        return "%d>%d" % [who, land]


func _wd_note(k: String, n: int = 1) -> void :
        wd_stats[k] = int(wd_stats.get(k, 0)) + n



func wd_units(who: int, land: int) -> Array[Unit]:
        var out: Array[Unit] = []
        if gw.army == null:
                return out
        for u: Unit in gw.army.units:
                if u.country_id == who and u.alive() and u.ground() and _owner_at(u.pos) == land:
                        out.append(u)
        return out



func withdraw_left(who: int, land: int) -> int:
        if not wd.has(_wd_k(who, land)):
                return -1
        return wd_units(who, land).size()



func _wd_legal(who: int, land: int, o: int) -> bool:
        if o == land or o < 0:
                return false
        if o == 0 or o == who:
                return true
        var dp: Diplomacy = gw.diplo
        return not dp.at_war(who, o) and (dp.allied(who, o) or dp.has_passage(who, o) or (dp.ally != null and dp.ally.same(who, o)) or (dp.rq != null and dp.rq.land_ok(who, o)))




const WD_IN: int = 10
const WD_R: int = 320
const WD_EXIT_TTL: float = 12.0
const WD_EXIT_BUCKET: float = 64.0
var _wd_exit_c: Dictionary = {}

## Поиск выхода к границе с кэшем. Спиральный скан до 320 ячеек — самая
## дорогая операция _wd_tick (при глубоком вклинении войск — сотни тысяч
## проверок ячеек на вызов). Результат кэшируется по бакетам 64px на
## WD_EXIT_TTL секунд игрового времени; конечный путь всё равно
## перепроверяется через _wd_legal перед отправкой юнита.
func wd_exit(who: int, land: int, p: Vector2) -> Vector2:
        var ckey: String = "%d>%d>%d_%d" % [who, land, floori(p.x / WD_EXIT_BUCKET), floori(p.y / WD_EXIT_BUCKET)]
        var hit: Variant = _wd_exit_c.get(ckey)
        if hit != null and gw.game_time < float((hit as Array)[1]):
                return (hit as Array)[0]
        var v: Vector2 = _wd_exit_scan(who, land, p)
        if _wd_exit_c.size() > 512:
                _wd_exit_c.clear()
        _wd_exit_c[ckey] = [v, gw.game_time + WD_EXIT_TTL]
        return v


func _wd_exit_scan(who: int, land: int, p: Vector2) -> Vector2:
        var d: WorldData = gw.data
        var pc: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
        var rmax: int = mini(maxi(d.w, d.h), WD_R)
        var lid: int = gw.naval._land_id(p) if gw.naval != null else 0




        var best: = Vector2i(-1, -1)
        var bs: int = 1 << 30
        var W: int = d.w
        var H: int = d.h
        var bio: PackedByteArray = d.biome
        var own: PackedByteArray = d.owners
        var nat: PackedByteArray = _wd_nat()
        var leg: = PackedByteArray()
        leg.resize(256)
        var px: int = pc.x
        var py: int = pc.y
        for r in range(1, rmax):
                if best.x >= 0 and r * r >= bs:
                        break
                var st: int = 1 if r < 48 else 2
                for k in range( - r, r + 1, st):
                        for sd in 4:
                                var dx: int = k
                                var dy: int = k
                                if sd == 0:
                                        dy = - r
                                elif sd == 1:
                                        dy = r
                                elif sd == 2:
                                        dx = - r
                                else:
                                        dx = r
                                var e2: int = dx * dx + dy * dy
                                if e2 >= bs:
                                        continue
                                var qx: int = px + dx
                                var qy: int = py + dy
                                if qx < 0 or qy < 0 or qx >= W or qy >= H:
                                        continue
                                var ci: int = qy * W + qx
                                if nat[bio[ci]] == 0:
                                        continue
                                var o: int = own[ci]
                                var lg: int = leg[o]
                                if lg == 0:
                                        lg = 1 if _wd_legal(who, land, o) else 2
                                        leg[o] = lg
                                if lg != 1:
                                        continue
                                var dd: int = e2 * (4 if o == 0 else 1)
                                if dd >= bs:
                                        continue
                                if lid > 0 and gw.naval._land_id(Vector2(qx * GameWorld.CELL, qy * GameWorld.CELL) + Vector2(2, 2)) != lid:
                                        continue
                                bs = dd
                                best = Vector2i(qx, qy)
        if best.x < 0:
                return Vector2.INF
        var dir: Vector2 = Vector2(best - pc).normalized()
        var deep: Vector2i = best
        for k2 in range(1, WD_IN + 1):
                var q2: = Vector2i(roundi(best.x + dir.x * k2), roundi(best.y + dir.y * k2))
                if not d.inside(q2.x, q2.y) or not Biome.is_natural_land(d.get_biome(q2.x, q2.y)) or not _wd_legal(who, land, d.get_owner_id(q2.x, q2.y)):
                        break
                deep = q2
        return Vector2(deep * GameWorld.CELL) + Vector2(GameWorld.CELL, GameWorld.CELL) * 0.5



static var _wd_nat_t: = PackedByteArray()
static func _wd_nat() -> PackedByteArray:
        if _wd_nat_t.is_empty():
                _wd_nat_t.resize(256)
                for b in 256:
                        _wd_nat_t[b] = 1 if Biome.is_natural_land(b) else 0
        return _wd_nat_t




func withdraw_start(who: int, land: int, own: bool = false) -> int:
        if who <= 0 or land <= 0 or who == land:
                return 0
        var k: String = _wd_k(who, land)
        var us: Array[Unit] = wd_units(who, land)
        if us.is_empty():
                wd.erase(k)
                return 0
        if not wd.has(k):
                wd[k] = {"t": gw.game_time, "own": own, "a": {}, "u": {}}
                _wd_note("started")
        _wd_fronts(who, land)
        _wd_orders(who, land, us)
        return us.size()


## withdraw без повторного скана юнитов: список уже посчитан нативом
## (критерии wd_units) и передан из _wd_sweep_nat. Остальное — 1:1 с withdraw_start.
func withdraw_start_ids(who: int, land: int, us: Array[Unit]) -> int:
        if who <= 0 or land <= 0 or who == land:
                return 0
        var k: String = _wd_k(who, land)
        if us.is_empty():
                wd.erase(k)
                return 0
        if not wd.has(k):
                wd[k] = {"t": gw.game_time, "own": false, "a": {}, "u": {}}
                _wd_note("started")
        _wd_fronts(who, land)
        _wd_orders(who, land, us)
        return us.size()



func _wd_fronts(who: int, land: int) -> void :
        var c: Country = gw.country_by_id(who)
        if c == null:
                return
        for g: Dictionary in c.army_groups.duplicate():
                var fr: Dictionary = AutoCmd.FrontPlan.front_of(g)
                if fr.is_empty():
                        continue
                var pts: Variant = fr.get("pts")
                if not (pts is PackedVector2Array) or (pts as PackedVector2Array).is_empty():
                        continue
                if int(fr.get("foe", -1)) == land and int(fr.get("host", -1)) <= 0:




                        _wd_note("fronts_kept")
                        continue
                var on: int = 0
                for q: Vector2 in pts:
                        if _owner_at(q) == land:
                                on += 1
                if on * 4 >= (pts as PackedVector2Array).size():
                        AutoCmd.FrontPlan.clear_front(gw, who, int(g["id"]))
                        _wd_note("fronts_lifted")



func _wd_orders(who: int, land: int, us: Array[Unit]) -> void :
        var k: String = _wd_k(who, land)
        var e: Dictionary = wd[k]
        var homes: Array[Facility] = []
        var seen: Dictionary = {}
        var cen: Dictionary = {}
        var loose: Array[Unit] = []
        for u: Unit in us:
                if u.home != null and gw.mil.alive(u.home) and u.home.kind == Facility.Kind.BARRACKS:
                        if not seen.has(u.home.id):
                                seen[u.home.id] = true
                                homes.append(u.home)
                                cen[u.home.id] = [Vector2.ZERO, 0]
                        var cc: Array = cen[u.home.id]
                        cc[0] = (cc[0] as Vector2) + u.pos
                        cc[1] = int(cc[1]) + 1
                else:
                        loose.append(u)
        var ex: Dictionary = e["a"]
        for f: Facility in homes:
                var op: Dictionary = list.get(f, {})
                var ea: Array = ex.get(str(f.id), [])
                var ok_dest: bool = ea.size() >= 2 and _wd_legal(who, land, _owner_at(Vector2(float(ea[0]), float(ea[1]))))
                if ok_dest and (( not op.is_empty() and String(op.get("wd", "")) == k) or _queued(f) or ea.size() == 3):
                        continue
                var cc2: Array = cen[f.id]
                var mid: Vector2 = (cc2[0] as Vector2) / float(int(cc2[1]))
                var dest: Vector2 = wd_exit(who, land, mid)
                var home: bool = not dest.is_finite()
                if home:
                        dest = gw.army.barracks_out(f)
                ex[str(f.id)] = [dest.x, dest.y]
                var q0: bool = _quiet
                var fa: bool = _from_auto
                _quiet = true
                _from_auto = true
                _wd_force = true
                var why: String = "home" if home else start(f, Kind.DEFEND, dest)
                if why != "" and why != PENDING:
                        why = start(f, Kind.RETREAT, Vector2.ZERO)
                _wd_force = false
                _quiet = q0
                _from_auto = fa
                _wd_note("orders")
                if list.has(f) and not bool((list[f] as Dictionary).get("wait", false)):
                        list[f]["wd"] = k
                if why != "" and why != PENDING:
                        _wd_note("orders_failed")
                        ex[str(f.id)] = [dest.x, dest.y, 1]
                        for u2: Unit in us:
                                if u2.home == f:
                                        _wd_walk(u2, dest)
        for u3: Unit in loose:
                var d3: Vector2 = wd_exit(who, land, u3.pos)
                if d3.is_finite():
                        _wd_walk(u3, d3)


func _wd_walk(u: Unit, dest: Vector2) -> void :
        if u.post != null:
                gw.army._release(u)
        u.target = null
        u.target_city = -1
        u.op_on = false
        u.op_hold = false
        u.op_move = false
        gw.army.tac._go(u, dest)



func _wd_put(u: Unit, dest: Vector2) -> void :
        if not dest.is_finite():
                u.state = Unit.State.DEAD
                u.dead_t = gw.game_time
                _wd_note("disbanded")
                return
        if u.post != null:
                gw.army._release(u)
        var p2: Vector2 = gw.econ.land_point(dest + u.slot * 0.5, 10)
        u.pos = p2 if _wd_legal(u.country_id, -1, _owner_at(p2)) and _owner_at(p2) != _owner_at(u.pos) else dest
        u.path = PackedVector2Array()
        u.pi = 0
        u.target = null
        u.target_city = -1
        u.op_on = false
        u.op_hold = false
        u.op_move = false
        u.state = Unit.State.IDLE
        _wd_note("relocated")



func _wd_dest(e: Dictionary, who: int, land: int, u: Unit) -> Vector2:
        if u.home != null:
                var a: Array = (e["a"] as Dictionary).get(str(u.home.id), [])
                if a.size() >= 2 and _wd_legal(who, land, _owner_at(Vector2(float(a[0]), float(a[1])))):
                        return Vector2(float(a[0]), float(a[1]))
        var q: Vector2 = wd_exit(who, land, u.pos)
        if not q.is_finite() and u.home != null and gw.mil.alive(u.home):
                q = gw.army.barracks_out(u.home)
        return q



## _wd_tick: «вывод войск» с чужой земли. Раньше на каждый ключ выполнялся
## полный скан всех юнитов (wd_units) и поиск границы (wd_exit, спираль до
## 320 ячеек) на каждую казарму и каждого «беспризорного» юнита — при большой
## войне это давало 100+ мс на тик. Теперь:
##   1) юниты бакетируются по странам одним проходом;
##   2) очередь приказов (_oq) проверяется по набору id за O(1);
##   3) ключи обрабатываются порциями (WD_KEYS_PER_TICK за тик) с ротацией;
##   4) wd_exit кэшируется по бакетам 64px.
const WD_KEYS_PER_TICK: int = 2
var _wd_cur: int = 0

func _wd_tick() -> void :
        if wd.is_empty() or gw.diplo == null or gw.army == null:
                return
        var now: float = gw.game_time
        var ks: Array = wd.keys()
        if ks.is_empty():
                return
        var qfids: Dictionary = {}
        for e0: Dictionary in _oq:
                qfids[int(e0["fid"])] = true
        var by_c: Dictionary = {}
        for u0: Unit in gw.army.units:
                if u0.alive() and u0.ground():
                        var b0: Variant = by_c.get(u0.country_id)
                        if b0 == null:
                                b0 = []
                                by_c[u0.country_id] = b0
                        (b0 as Array).append(u0)
        var budget: int = mini(WD_KEYS_PER_TICK, ks.size())
        var i: int = _wd_cur % ks.size()
        var processed: int = 0
        while processed < budget:
                var k: String = ks[i]
                i = (i + 1) % ks.size()
                processed += 1
                if not wd.has(k):
                        continue
                var e: Dictionary = wd[k]
                var gg: PackedStringArray = k.split(">")
                var who: int = int(gg[0])
                var land: int = int(gg[1])
                var cw: Country = gw.country_by_id(who)
                var cl: Country = gw.country_by_id(land)
                if cw == null or cl == null or cw.eliminated or cl.eliminated or gw.diplo.at_war(who, land)\
                or ( not bool(e.get("own", false)) and gw.diplo.may_cross(who, land)):
                        wd.erase(k)
                        continue
                var us: Array[Unit] = _wd_units_b(who, land, by_c)
                if us.is_empty():
                        wd.erase(k)
                        _wd_note("done")
                        gw.say(cl, Loc.mk("Войска %s покинули вашу землю", [Loc.name(cw.name)]))
                        gw.say(cw, Loc.mk("Войска выведены с земли %s", [Loc.name(cl.name)]))
                        continue
                _wd_orders(who, land, us)
                var um: Dictionary = e["u"]
                var late: bool = now - float(e["t"]) >= WD_MAX
                var keep: Dictionary = {}
                for u: Unit in us:
                        var uk: String = str(u.id)
                        keep[uk] = true
                        var rec: Array = um.get(uk, [u.pos.x, u.pos.y, 0, 0])
                        var moved: bool = Vector2(float(rec[0]), float(rec[1])).distance_to(u.pos) >= WD_STILL
                        rec[0] = u.pos.x
                        rec[1] = u.pos.y
                        rec[2] = 0 if moved else int(rec[2]) + 1
                        if not late and u.home != null and qfids.has(u.home.id) and now - float(e["t"]) < WD_WAIT_WAY:
                                rec[2] = 0
                        var waits: bool = u.home != null and qfids.has(u.home.id)
                        if not waits and u.pi < u.path.size() and not _wd_legal(who, land, _owner_at(u.path[u.path.size() - 1]))\
                        and not (u.home != null and String((list.get(u.home, {}) as Dictionary).get("wd", "")) == k and u.op_on):
                                _wd_walk(u, _wd_dest(e, who, land, u))
                                _wd_note("redirect")
                        if late or (int(rec[2]) >= WD_STUCK and int(rec[3]) >= WD_JUMP):
                                _wd_put(u, _wd_dest(e, who, land, u))
                                rec[2] = 0
                        elif int(rec[2]) >= WD_STUCK:
                                rec[2] = 0
                                rec[3] = int(rec[3]) + 1
                                _wd_walk(u, _wd_dest(e, who, land, u))
                                _wd_note("repath")
                        um[uk] = rec
                for uk2: String in um.keys():
                        if not keep.has(uk2):
                                um.erase(uk2)
        _wd_cur = i


func _wd_units_b(who: int, land: int, by_c: Dictionary) -> Array[Unit]:
        var out: Array[Unit] = []
        var b: Variant = by_c.get(who)
        if b == null:
                return out
        for u: Unit in (b as Array):
                if _owner_at(u.pos) == land:
                        out.append(u)
        return out








const SWEEP_SAY: float = 120.0
var _sw_say: Dictionary = {}


func _wd_sweep() -> void :
        if gw.diplo == null or gw.army == null or gw.data == null:
                return
        if _nat != null:
                _wd_sweep_nat()
                return
        var dp: Diplomacy = gw.diplo
        var pairs: Dictionary = {}
        for u: Unit in gw.army.units:
                if not u.alive() or not u.ground():
                        continue
                var o: int = _owner_at(u.pos)
                if o <= 0 or o == u.country_id:
                        continue
                var k: String = _wd_k(u.country_id, o)
                if pairs.has(k) or wd.has(k):
                        continue
                var cx: int = floori(u.pos.x / GameWorld.CELL)
                var cy: int = floori(u.pos.y / GameWorld.CELL)
                if Biome.is_water(gw.data.get_biome(cx, cy)) and not gw.data.has_flag(cx, cy, WorldData.F_BRIDGE):
                        continue
                if u.home != null and gw.naval != null and gw.naval.at_sea(u.home):
                        continue
                if u.home != null and int((list.get(u.home, {}) as Dictionary).get("kind", -1)) == Kind.RETREAT and dp.truce_on(u.country_id, o):
                        continue
                pairs[k] = true
        var ks: Array = pairs.keys()
        ks.sort()
        for k2: String in ks:
                var gg: PackedStringArray = k2.split(">")
                var who: int = int(gg[0])
                var land: int = int(gg[1])
                var cw: Country = gw.country_by_id(who)
                var cl: Country = gw.country_by_id(land)
                if cw == null or cl == null or cw.eliminated or cl.eliminated or dp.may_cross(who, land):
                        continue
                var n: int = withdraw_start(who, land)
                if n <= 0:
                        continue
                _wd_note("swept")
                if gw.game_time - float(_sw_say.get(k2, -1000000000.0)) >= SWEEP_SAY:
                        _sw_say[k2] = gw.game_time
                        if dp.truce_on(who, land):
                                gw.say(cw, Loc.mk("Перемирие со страной %s: ваши войска уходят с её земли к ближайшей границе (%d ед.)", [Loc.name(cl.name), n]))
                                gw.say(cl, Loc.mk("Перемирие: войска страны %s уходят с вашей земли (%d ед.)", [Loc.name(cw.name), n]))
                        else:
                                gw.say(cw, Loc.mk("Земля под вашими войсками теперь страны %s: они уходят к ближайшей границе (%d ед.)", [Loc.name(cl.name), n]))
                                gw.say(cl, Loc.mk("Войска страны %s оказались на вашей земле без права: они уходят к границе (%d ед.)", [Loc.name(cw.name), n]))




## Нативный _wd_sweep (Rust df_native.wd_scan): юнит-фильтры (вода/море/
## отступ+перемирие), владельцы ячеек и полный список юнитов каждой пары
## считает натив; GDScript остаётся на парных проверках (страны, may_cross,
## truce-сообщения) и withdraw. Семантика 1:1 с GDScript-путью выше.
func _wd_sweep_nat() -> void :
        var dp: Diplomacy = gw.diplo
        var d: WorldData = gw.data
        # Сетка «вода без моста» — кэш на партию (биомы/мосты не меняются).
        var wh: int = d.w * 100000 + d.h
        if _wd_blocked_wh != wh:
                var b := PackedByteArray()
                b.resize(d.w * d.h)
                for y in d.h:
                        for x in d.w:
                                b[y * d.w + x] = 1 if (Biome.is_water(d.get_biome(x, y)) and not d.has_flag(x, y, WorldData.F_BRIDGE)) else 0
                _wd_blocked = b
                _wd_blocked_wh = wh
        _nat.push_wd_grid(d.w, d.h, _wd_blocked, d.owners)
        # Юниты: живые наземные, в порядке army.units.
        var ids := PackedInt32Array()
        var xs := PackedFloat32Array()
        var ys := PackedFloat32Array()
        var cs := PackedInt32Array()
        var hs := PackedInt32Array()
        for u: Unit in gw.army.units:
                if not u.alive() or not u.ground():
                        continue
                ids.append(u.id)
                xs.append(u.pos.x)
                ys.append(u.pos.y)
                cs.append(u.country_id)
                hs.append(u.home.id if u.home != null else -1)
        var sea := PackedInt64Array()
        if gw.naval != null:
                for L: Dictionary in gw.naval.landings:
                        if L.has("home") and (L["home"] as Facility) != null and int(L["stage"]) != 0:
                                sea.append((L["home"] as Facility).id)
        if gw.rail != null and gw.rail.troops != null:
                for r: Dictionary in gw.rail.troops.rides:
                        if r.has("home") and (r["home"] as Facility) != null and int(r["stage"]) != 0:
                                sea.append((r["home"] as Facility).id)
        var retreat := PackedInt64Array()
        for f0: Facility in list:
                if list.has(f0) and int(list[f0]["kind"]) == Kind.RETREAT:
                        retreat.append(f0.id)
        var truce := PackedInt64Array()
        for a: Country in gw.countries:
                for b2: Country in gw.countries:
                        if a.id != b2.id and dp.truce_on(a.id, b2.id):
                                truce.append((a.id << 16) | b2.id)
        var known := PackedInt64Array()
        for k0: String in wd:
                var gg0: PackedStringArray = k0.split(">")
                known.append((int(gg0[0]) << 16) | int(gg0[1]))
        var blocks: PackedInt64Array = _nat.wd_scan(ids, xs, ys, cs, hs, sea, retreat, truce, known, float(GameWorld.CELL))
        if OS.get_environment("DF_WD_VERIFY") == "1":
                _wd_verify(ids, xs, ys, cs, hs, sea, retreat, truce, known, blocks)
        if blocks.is_empty():
                return
        var by_id: Dictionary = {}
        for u2: Unit in gw.army.units:
                by_id[u2.id] = u2
        var i: int = 0
        while i < blocks.size():
                var who: int = int(blocks[i])
                var land: int = int(blocks[i + 1])
                var nu: int = int(blocks[i + 2])
                i += 3
                var us: Array[Unit] = []
                for j in nu:
                        var u3: Variant = by_id.get(int(blocks[i + j]))
                        if u3 != null:
                                us.append(u3 as Unit)
                i += nu
                var k: String = _wd_k(who, land)
                if wd.has(k):
                        continue
                var cw: Country = gw.country_by_id(who)
                var cl: Country = gw.country_by_id(land)
                if us.is_empty() or cw == null or cl == null or cw.eliminated or cl.eliminated or dp.may_cross(who, land):
                        continue
                var n: int = withdraw_start_ids(who, land, us)
                if n <= 0:
                        continue
                _wd_note("swept")
                if gw.game_time - float(_sw_say.get(k, -1000000000.0)) >= SWEEP_SAY:
                        _sw_say[k] = gw.game_time
                        if dp.truce_on(who, land):
                                gw.say(cw, Loc.mk("Перемирие со страной %s: ваши войска уходят с её земли к ближайшей границе (%d ед.)", [Loc.name(cl.name), n]))
                                gw.say(cl, Loc.mk("Перемирие: войска страны %s уходят с вашей земли (%d ед.)", [Loc.name(cw.name), n]))
                        else:
                                gw.say(cw, Loc.mk("Земля под вашими войсками теперь страны %s: они уходят к ближайшей границе (%d ед.)", [Loc.name(cl.name), n]))
                                gw.say(cl, Loc.mk("Войска страны %s оказались на вашей земле без права: они уходят к границе (%d ед.)", [Loc.name(cw.name), n]))





## DF_WD_VERIFY=1: контрольный прогон исходного GDScript-скана по тем же
## данным — наборы пар обязаны совпасть с нативными (миссинг/экстра = баг).
func _wd_verify(ids: PackedInt32Array, xs: PackedFloat32Array, ys: PackedFloat32Array, cs: PackedInt32Array, hs: PackedInt32Array, sea: PackedInt64Array, retreat: PackedInt64Array, truce: PackedInt64Array, known: PackedInt64Array, blocks: PackedInt64Array) -> void :
        var known_set: Dictionary = {}
        for k in known:
                known_set[int(k)] = true
        var pairs: Dictionary = {}
        for i in ids.size():
                var o: int = _owner_at(Vector2(xs[i], ys[i]))
                if o <= 0 or o == cs[i]:
                        continue
                var key: int = (cs[i] << 16) | o
                if known_set.has(key) or pairs.has(key):
                        continue
                var cx: int = floori(float(xs[i]) / float(GameWorld.CELL))
                var cy: int = floori(float(ys[i]) / float(GameWorld.CELL))
                if Biome.is_water(gw.data.get_biome(cx, cy)) and not gw.data.has_flag(cx, cy, WorldData.F_BRIDGE):
                        continue
                if hs[i] >= 0 and sea.has(hs[i]):
                        continue
                if hs[i] >= 0 and retreat.has(hs[i]) and truce.has(key):
                        continue
                pairs[key] = true
        var nat: Dictionary = {}
        var i2: int = 0
        while i2 < blocks.size():
                nat[(int(blocks[i2]) << 16) | int(blocks[i2 + 1])] = true
                i2 += 3 + int(blocks[i2 + 2])
        var miss: Array = []
        var extra: Array = []
        for k2: int in pairs:
                if not nat.has(k2):
                        miss.append(k2)
        for k3: int in nat:
                if not pairs.has(k3):
                        extra.append(k3)
        if not miss.is_empty() or not extra.is_empty():
                push_error("[WD-VERIFY] mismatches: gd-only=%s nat-only=%s" % [miss, extra])
        else:
                print("[WD-VERIFY] ok: pairs=", pairs.size())





func wd_lock(f: Facility, kind: int) -> String:
        if wd.is_empty() or f == null or _wd_force or kind == Kind.RETREAT:
                return ""
        for k: String in wd:
                var gg: PackedStringArray = k.split(">")
                if int(gg[0]) != f.country_id:
                        continue
                var land: int = int(gg[1])
                for u: Unit in gw.army.units:
                        if u.home == f and u.alive() and u.ground() and _owner_at(u.pos) == land:
                                var cl: Country = gw.country_by_id(land)
                                return Loc.t("Армия №%d уходит с земли %s — новый приказ после выхода") % [f.army_no, cl.name if cl != null else Loc.t("чужой страны")]
        return ""


func wd_save() -> Dictionary:
        return wd.duplicate(true)


func wd_load(d: Variant) -> void :
        wd = {}
        if not (d is Dictionary):
                return
        for k: Variant in d:
                var e: Variant = d[k]
                if e is Dictionary:
                        var e2: Dictionary = (e as Dictionary).duplicate(true)
                        var a2: Dictionary = {}
                        for ak: Variant in (e2.get("a", {}) as Dictionary):
                                a2[str(ak)] = e2["a"][ak]
                        var u2: Dictionary = {}
                        for uk: Variant in (e2.get("u", {}) as Dictionary):
                                u2[str(uk)] = e2["u"][uk]
                        wd[String(k)] = {"t": float(e2.get("t", 0.0)), "own": bool(e2.get("own", false)), "a": a2, "u": u2}



func _run_oq() -> void :
        if _oq.is_empty():
                return
        var started: int = 0
        var looked: int = 0
        var k: int = 0
        while k < _oq.size() and started < OQ_PER_TICK and looked < OQ_TRY:
                var e: Dictionary = _oq[k]
                var f: Facility = _fac(int(e["fid"]))
                var ph: Dictionary = list.get(f, {}) if f != null else {}
                if f == null or not gw.mil.alive(f) or ph.is_empty() or not bool(ph.get("wait", false)):
                        _oq.remove_at(k)
                        continue
                if float(auto_next.get("h%d" % f.id, - INF)) >= float(e.get("t", INF)):
                        _oq.remove_at(k)
                        if list.get(f, {}) == ph:
                                list.erase(f)
                        continue
                looked += 1
                var kind: int = int(e["kind"])
                var to: Vector2 = _resolve_to(f, kind, e["target"], e["cands"])
                var wp: Vector2 = e["wp"]
                var pos: Vector2 = e["pos"]
                if wp.is_finite() and pos.is_finite() and kind != Kind.RETREAT:
                        var sh: Vector2 = wp + (to - pos)
                        wp = sh if _dry(sh) else wp
                _q_run = true
                var was_quiet: bool = _quiet
                _quiet = bool(e["quiet"])
                var why: String = start(f, kind, to, wp, bool(e.get("sea", false)))
                if why != "" and why != PENDING and pos.is_finite() and to.distance_to(pos) > 1.0 and kind != Kind.RETREAT:


                        var why2: String = start(f, kind, pos, e["wp"], bool(e.get("sea", false)))
                        if why2 == "" or why2 == PENDING:
                                why = why2
                _quiet = was_quiet
                _q_run = false
                if why == PENDING:
                        k += 1
                        continue
                _oq.remove_at(k)
                started += 1
                if why == "":
                        var op: Dictionary = list.get(f, {})
                        for key: String in ["fp", "stance", "retreat_at", "front_take", "held", "peak", "fell_back"]:
                                if ph.has(key):
                                        op[key] = ph[key]
                else:
                        if list.get(f, {}) == ph:
                                list.erase(f)
                        var c: Country = gw.country_by_id(f.country_id)
                        if c != null and c.is_player:
                                gw.say(c, Loc.mk("Армия №%d: %s", [f.army_no, why]))




func _resolve_to(f: Facility, kind: int, target: Vector2, cands: Array) -> Vector2:
        if cands.is_empty():
                return target
        var sea0: bool = _check(f, kind, target, Vector2.INF).has("naval")
        for q: Vector2 in cands:
                if not _dry(q):
                        continue
                var cq: Dictionary = _check(f, kind, q, Vector2.INF)
                if bool(cq["ok"]) and cq.has("naval") == sea0:
                        return q
        return target




func suggest_kind(f: Facility, p: Vector2) -> int:
        if f != null and p.distance_to(f.center_px()) < 70.0:
                return Kind.RETREAT
        var o: int = _owner_at(p)
        if f != null and o == f.country_id and _foreign_city(p, f.country_id) == null:
                return Kind.DEFEND
        return _peace_kind(f.country_id, p, Kind.ATTACK) if f != null else Kind.ATTACK



func _teeth_on(path: PackedVector2Array) -> bool:
        if gw.econ == null or gw.econ.blocked.is_empty() or gw.econ.nav == null:
                return false
        for p: Vector2 in path:
                if gw.econ.blocked.has(gw.econ._nav_cell(p)):
                        return true
        return false





func _peace_kind(cid: int, p: Vector2, k: int) -> int:
        if k != Kind.ATTACK or gw.diplo == null:
                return k
        var city: City = _foreign_city(p, cid)
        var o: int = _owner_at(p)
        var foe: int = city.country_id if city != null else o
        if foe <= 0 or foe == cid or gw.diplo.at_war(cid, foe):
                return k
        return Kind.DEFEND if gw.diplo.may_cross(cid, o) else k





func order(country_id: int, kind: int, pos: Vector2) -> String:
        var chk: Dictionary = order_check(country_id, kind, pos)
        if not bool(chk["ok"]):
                return String(chk["why"])
        var c: Country = gw.country_by_id(country_id)
        var cost: Dictionary = chk["cost"]
        c.pay_res(cost)
        if gw.econ != null and gw.econ.has_method("stat_add"):
                gw.econ.stat_add(c, "spend", "army", int(cost.get("money", 0)))
        var spec: Dictionary = ORDERS[kind]
        ready_at["%d:%d" % [country_id, kind]] = gw.game_time + float(spec["cd"])
        var z: Dictionary = {"id": _zid, "k": kind, "c": country_id, "pos": pos, "r": float(spec["r"]), "t0": gw.game_time, "until": gw.game_time + float(spec["dur"]), "fx": []}
        _zid += 1
        match kind:
                Order.ARTY:
                        z["until"] = gw.game_time + WARN_T + float(spec["dur"]) + 1.5
                        z["next"] = gw.game_time + WARN_T
                        z["left"] = int(spec["shells"])
                        z["gun"] = chk["gun"]
                        z["hit"] = false
                        if _visible(pos, country_id):
                                z["fx"].append(gw.fx.handle(gw.fx.spawn(_fxn("target_flare_loop", "smoke_screen_loop"), pos.round(), 5, gw.game_time + WARN_T + 3.0, true)))
                Order.SMOKE:
                        _smoke_fx(z)
                        Sfx.play("grenade", pos, -6.0)
                Order.MEDIC:
                        if _visible(pos, country_id):
                                gw.fx.spawn(_fxn("medic_pop", "dust_s"), pos.round(), 6)
                                Sfx.play("ui_build", pos, -8.0)
        zones.append(z)
        if c.is_player:
                gw.say(c, "%s: %s" % [spec["name"], Loc.t("огонь через %d с") % ceili(WARN_T) if kind == Order.ARTY else (Loc.t("%d с") % int(spec["dur"]))])
        return ""



func order_check(country_id: int, kind: int, pos: Vector2) -> Dictionary:
        var out: Dictionary = {"ok": false, "why": "", "cost": {}, "far": false, "gun": Vector2.INF}
        var c: Country = gw.country_by_id(country_id)
        if c == null or kind < 0 or kind >= ORDERS.size():
                out["why"] = Loc.t("Нет такого приказа")
                return out
        var spec: Dictionary = ORDERS[kind]
        var left: float = cooldown_left(country_id, kind)
        if left > 0.0:
                out["why"] = Loc.t("Перезарядка: %d с") % ceili(left)
                return out
        var cell: = Vector2i(floori(pos.x / GameWorld.CELL), floori(pos.y / GameWorld.CELL))
        if gw.data == null or not gw.data.inside(cell.x, cell.y):
                out["why"] = Loc.t("За краем карты")
                return out
        var cost: Dictionary = spec["cost"]
        match kind:
                Order.ARTY:
                        var gun: Vector2 = _gun_for(country_id, pos)
                        out["gun"] = gun
                        if not gun.is_finite():
                                out["far"] = true
                                cost = spec["cost_far"]
                                if not _near_own(country_id, pos, ARTY_REACH, false):
                                        out["why"] = Loc.t("Слишком далеко от своих войск")
                                        out["too_far"] = true
                                        return out
                        if c.is_player and not gw.net_driven and gw.vision != null and gw.vision.has_method("sees") and not gw.vision.sees(pos) and not _near_own(country_id, pos, 140.0, false):
                                out["why"] = Loc.t("Цель не видна: нужна разведка")
                                return out
                Order.SMOKE:
                        if not _near_own(country_id, pos, ORDER_NEAR, false) and not _gun_for(country_id, pos).is_finite():
                                out["why"] = Loc.t("Рядом нет своих войск")
                                return out
                Order.MEDIC:
                        if not _near_own(country_id, pos, float(spec["r"]) + 30.0, false):
                                out["why"] = Loc.t("Госпиталь — только рядом со своими войсками")
                                return out
        out["cost"] = cost
        if not c.has_res(cost) and gw.econ != null and gw.econ.has_method("can_substitute") and gw.econ.can_substitute(cost, c):
                cost = gw.econ.substitute_cost(cost, c)
                out["cost"] = cost
        if not c.has_res(cost):
                out["why"] = Loc.t("Не хватает: %s") % [c.missing_res(cost)]
                return out
        out["ok"] = true
        return out



func order_info(kind: int) -> Dictionary:
        var s: Dictionary = ORDERS[clampi(kind, 0, ORDERS.size() - 1)]
        var ct: String = _cost_text(s["cost"])
        if kind == Order.ARTY:
                ct += Loc.t(" (без своей артиллерии %s)") % _cost_text(s["cost_far"])
        return {"name": s["name"], "title": s["title"], "icon": s["icon"], "desc": s["desc"], "cost_text": ct, "radius": float(s["r"]), "cd": float(s["cd"]), "dur": float(s["dur"])}


func cooldown_left(country_id: int, kind: int) -> float:
        return maxf(0.0, float(ready_at.get("%d:%d" % [country_id, kind], -1.0)) - gw.game_time)



func smoke_at(p: Vector2) -> bool:
        for z: Dictionary in zones:
                if int(z["k"]) == Order.SMOKE and (z["pos"] as Vector2).distance_squared_to(p) <= float(z["r"]) * float(z["r"]):
                        return true
        return false



func _zone_near(country_id: int, kind: int, p: Vector2, d: float) -> bool:
        for z: Dictionary in zones:
                if int(z["k"]) == kind and int(z["c"]) == country_id and (z["pos"] as Vector2).distance_squared_to(p) <= d * d:
                        return true
        return false




func refill_boost(f: Facility) -> float:
        for z: Dictionary in zones:
                if int(z["k"]) == Order.MEDIC and int(z["c"]) == f.country_id and (z.get("homes", []) as Array).has(f.id):
                        return MEDIC_BOOST
        return 1.0




func medic_spot(country_id: int) -> Vector2:
        var hurt: Array[Unit] = []
        for u: Unit in gw.army.units:
                if u.country_id == country_id and u.alive() and u.ground() and u.hp < u.max_hp * 0.65:
                        hurt.append(u)
                        if hurt.size() >= 120:
                                break
        if hurt.size() < 3:
                return Vector2.INF
        var best: = Vector2.INF
        var bs: float = 59.0
        for u: Unit in hurt:
                var sum: = Vector2.ZERO
                var n: int = 0
                var miss: float = 0.0
                for o: Unit in hurt:
                        if o.pos.distance_squared_to(u.pos) <= 70.0 * 70.0:
                                sum += o.pos
                                n += 1
                                miss += o.max_hp - o.hp
                if n >= 3 and miss > bs:
                        var cp: Vector2 = sum / float(n)
                        if _zone_near(country_id, Order.MEDIC, cp, 100.0):
                                continue
                        bs = miss
                        best = cp
        return best








func next_prompt() -> Dictionary:
        var p: Country = gw.player
        if p == null or p.at_war.is_empty():
                return {}
        var now: float = gw.game_time
        while not _urgent.is_empty():
                var ur: Dictionary = _urgent.pop_front()
                if now - float(ur.get("t", now)) <= 60.0 and prompt_valid(ur) and (String(ur["action"]) != "op_defend" or _prompt_ok(p, ur)):
                        _prompt_t = now
                        _prompted[String(ur["key"])] = now
                        _prompt_last = String(ur["action"])
                        return _shown_pr(ur)
        var due: bool = now - _prompt_t >= PROMPT_GAP
        if not due and now - _prompt_scan_t < PROMPT_SCAN:
                return {}
        _prompt_scan_t = now
        var cands: Array = _find_prompt(p)

        var live: Dictionary = {}
        for pr: Dictionary in cands:
                live[String(pr["key"])] = true
        for k: String in _prompt_acc.keys():
                if not live.has(k):
                        _prompt_acc.erase(k)
        if not due:
                return {}
        var pick: Dictionary = {}
        for pass_i in 2:
                for pr: Dictionary in cands:
                        var key: String = pr["key"]
                        if _prompt_acc.has(key) or now < float(_prompt_sup.get(key, -1.0)) or now - float(_prompted.get(key, -999.0)) < PROMPT_REPEAT:
                                continue
                        if pass_i == 0 and String(pr["action"]) == _prompt_last:
                                continue
                        if not _prompt_ok(p, pr):
                                _prompt_sup[key] = now + PROMPT_REPEAT
                                continue
                        pick = pr
                        break
                if not pick.is_empty():
                        break
        if pick.is_empty():
                return {}
        _prompt_t = now
        _prompted[String(pick["key"])] = now
        _prompt_last = String(pick["action"])
        return _shown_pr(pick)



static func _shown_pr(pr: Dictionary) -> Dictionary:
        if not Loc.is_msg(pr.get("text", "")):
                return pr
        var out: Dictionary = pr.duplicate()
        out["text"] = Loc.msg(pr["text"])
        return out



func dismiss_prompt(pr: Dictionary) -> void :
        var key: String = _pkey(pr)
        if key != "":
                _prompt_sup[key] = gw.game_time + PROMPT_DISMISS




func prompt_accepted(pr: Dictionary) -> void :
        var key: String = _pkey(pr)
        if key != "":
                _prompt_acc[key] = true
                _prompted[key] = gw.game_time




func do_prompt(pr: Dictionary) -> String:
        var p: Country = gw.player
        if p == null or pr.is_empty():
                return Loc.t("Нет решения")
        var fid: int = int(pr.get("fid", -1))
        var f: Facility = _fac(fid) if fid >= 0 else null
        if f != null and f.country_id != p.id:
                f = null
        var pos: Vector2 = pr.get("pos", Vector2.INF)
        var why: String = Loc.t("Нет решения")
        match String(pr.get("action", "")):
                "op_retreat":
                        why = start(f, Kind.RETREAT, Vector2.ZERO) if f != null else Loc.t("Армия не найдена")
                "op_defend":
                        why = start(f, Kind.DEFEND, pos) if f != null else Loc.t("Нет свободной армии")
                "order_arty":
                        why = order(p.id, Order.ARTY, pos)
                "order_smoke":
                        why = order(p.id, Order.SMOKE, pos)
                "order_ew", "order_medic":
                        why = order(p.id, Order.MEDIC, pos)
                "select_barracks":
                        why = "" if f != null else Loc.t("Армия не найдена")
                "look":
                        why = ""
        if why == "":
                prompt_accepted(pr)
        return why


func _pkey(pr: Dictionary) -> String:
        if pr.is_empty():
                return ""
        return String(pr.get("key", "%s:f%d" % [String(pr.get("action", "")), int(pr.get("fid", -1))]))


func _pr(action: String, place: String, text: Variant, icon: String, pos: Vector2, fid: int) -> Dictionary:
        return {"text": text, "icon": icon, "action": action, "pos": pos, "fid": fid, "key": action + ":" + place}



func _prompt_ok(p: Country, pr: Dictionary) -> bool:
        var fid: int = int(pr["fid"])
        var f: Facility = _fac(fid) if fid >= 0 else null
        match String(pr["action"]):
                "op_retreat":
                        return f != null and list.has(f) and int(list[f]["kind"]) != Kind.RETREAT
                "op_defend":
                        return f != null and not list.has(f) and bool(_check(f, Kind.DEFEND, pr["pos"], Vector2.INF)["ok"])
                "order_arty":
                        return bool(order_check(p.id, Order.ARTY, pr["pos"])["ok"])
                "order_smoke":
                        return bool(order_check(p.id, Order.SMOKE, pr["pos"])["ok"])
                "order_ew":
                        return bool(order_check(p.id, Order.MEDIC, pr["pos"])["ok"])
                "select_barracks":
                        return f != null and gw.mil.alive(f) and not list.has(f)
        return false





func prompt_valid(pr: Dictionary) -> bool:
        var p: Country = gw.player
        if pr.is_empty() or p == null or p.eliminated or p.at_war.is_empty():
                return false
        var key: String = _pkey(pr)
        if _prompt_acc.has(key) or gw.game_time < float(_prompt_sup.get(key, -1.0)):
                return false
        var fid: int = int(pr.get("fid", -1))
        var f: Facility = _fac(fid) if fid >= 0 else null
        if f != null and (f.country_id != p.id or not gw.mil.alive(f)):
                return false
        var cid: int = int(pr.get("cid", -1))
        if cid >= 0 and (cid >= gw.cities.size() or gw.cities[cid].country_id != p.id):
                return false
        match String(pr.get("action", "")):
                "select_barracks":
                        return f != null and not list.has(f) and f.stance == 0 and _army(f).size() >= Army.BARRACKS_CAP - 3
                "op_retreat":
                        if f == null or not list.has(f):
                                return false
                        var op: Dictionary = list[f]
                        return int(op["kind"]) != Kind.RETREAT and not bool(op.get("stance", false)) and float(op["losses"]) >= 0.25
                "op_defend":
                        if f == null or list.has(f) or f.stance != 0 or _army(f).size() < 3:
                                return false
                        if cid >= 0:
                                var city: City = gw.cities[cid]
                                return not _city_covered(p.id, Vector2(city.center * GameWorld.CELL), float(city.radius * GameWorld.CELL))
                        return true
                "order_arty", "order_smoke":
                        var k: int = Order.ARTY if String(pr["action"]) == "order_arty" else Order.SMOKE
                        if auto_orders_of(p.id) or cooldown_left(p.id, k) > 0.0 or f == null or not list.has(f):
                                return false
                        var top: Dictionary = gw.army.tac.ops.get(f, {})
                        return not top.is_empty() and gw.game_time - float(top["contact"]) <= 12.0
                "order_ew", "order_medic":
                        return not auto_orders_of(p.id) and cooldown_left(p.id, Order.MEDIC) <= 0.0
                "look":
                        return gw.game_time - float(pr.get("t", gw.game_time)) < 45.0
        return false





func doing_text(f: Facility) -> String:
        var d: Array = _doing(f)
        if String(d[0]) == "":
                return ""
        return String(d[0]) if String(d[1]) == "" else "%s: %s" % [d[0], d[1]]



func _doing(f: Facility) -> Array:
        if f == null or f.kind != Facility.Kind.BARRACKS:
                return ["", ""]
        var st: int = clampi(f.stance, 0, 2)
        var free: Array[Unit] = _army(f)
        var n: int = free.size()
        var need: int = mini(AutoCmd.ATTACK_N, Army.BARRACKS_CAP)
        var short: String = Loc.t("нужно %d бойцов (есть %d/%d)") % [need, n, gw.army.cap_of(f)]
        if list.has(f):
                var op: Dictionary = list[f]
                var kind: int = int(op["kind"])
                var s: String = Loc.msg(op["state"])
                if op.has("fp") and kind != Kind.ATTACK:

                        return [Loc.t("ФРОНТ"), ((Loc.t("разбита — пополнение и ") if bool(op.get("shattered", false)) else "") + Loc.t("лечение у казарм — вернётся на фронт") + (Loc.t(" (нет еды: не лечатся)") if gw.country_by_id(f.country_id) != null and gw.country_by_id(f.country_id).food <= 0 else "")) if kind == Kind.RETREAT else s]
                if st == 0 or not bool(op.get("stance", false)):
                        return [KIND_NAMES[kind], s]
                var where: String = _where(op)
                if st == 2:
                        if kind == Kind.DEFEND:
                                if n < need:
                                        var rb2: String = gw.army.refill_block(f)
                                        return [Loc.t("НАСТУПАЮТ"), Loc.t("%s — пока держим рубеж %s%s") % [short, where, (" · " + rb2) if rb2 != "" else ""]]
                                return [Loc.t("НАСТУПАЮТ"), Loc.t("сначала отбиваем врага %s — %s") % [where, s]]
                        if kind == Kind.RETREAT:
                                return [Loc.t("НАСТУПАЮТ"), Loc.t("сначала лечимся — %s") % s]
                        return [Loc.t("НАСТУПАЮТ"), s]
                if kind == Kind.DEFEND:
                        return [Loc.t("ДЕРЖАТ"), Loc.t("враг рядом — %s") % s]
                if kind == Kind.ATTACK:
                        return [Loc.t("ДЕРЖАТ"), Loc.t("выбиваем врага с нашей земли — %s") % s]
                return [Loc.t("ДЕРЖАТ"), s]
        var fw: String = AutoCmd.FrontPlan.idle_why(gw, f) if f.group_id >= 0 else ""
        if fw != "":
                return [Loc.t("ФРОНТ"), fw]
        var all_n: int = _army(f, true).size()
        var rf: Vector2i = gw.army.reinf.counts(f)
        var posts: int = all_n - n - rf.x - rf.y
        if all_n == 0:
                var rb0: String = gw.army.refill_block(f)
                return [Loc.t("НЕТ ВОЙСК"), Loc.t("набор остановлен") if f.prod_type == 3 else (rb0 if rb0 != "" else Loc.t("армия формируется"))]
        if n == 0 and posts > 0:
                return [Loc.t("В ОКОПАХ"), Loc.t("%d бойцов") % posts]
        var t: Array = [Loc.t("ЖДУТ ПРИКАЗА"), Loc.t("проведите стрелку от казарм")]
        if st == 1:
                t = [Loc.t("ДЕРЖАТ"), Loc.t("ждём угрозы у казарм")]
        elif st == 2:
                var c: Country = gw.country_by_id(f.country_id)
                var hp: float = 0.0
                var mhp: float = 0.0
                for u: Unit in free:
                        hp += u.hp
                        mhp += u.max_hp
                if c == null or c.at_war.is_empty():
                        t = [Loc.t("НАСТУПАЮТ"), Loc.t("войны нет — ждём у казарм")]
                elif n < need:
                        var rb: String = gw.army.refill_block(f)
                        t = [Loc.t("НАСТУПАЮТ"), short + (" — " + rb if rb != "" else Loc.t(" — ждём у казарм"))]
                elif hp / maxf(1.0, mhp) < AutoCmd.ATTACK_HP:
                        t = [Loc.t("НАСТУПАЮТ"), Loc.t("лечимся перед атакой (%d%%)") % roundi(hp / maxf(1.0, mhp) * 100.0)]
                elif gw.game_time < float(auto_next.get("t%d" % f.id, 0.0)):
                        t = [Loc.t("НАСТУПАЮТ"), Loc.t("нет цели в досягаемости — ищем")]
                else:
                        t = [Loc.t("НАСТУПАЮТ"), Loc.t("выбираем цель")]
        if posts > 0:
                t[1] = String(t[1]) + Loc.t(" · в окопах %d") % posts
        var rb1: String = gw.army.refill_block(f) if all_n < gw.army.cap_of(f) else ""
        if rb1 != "" and not String(t[1]).contains(rb1):
                t[1] = String(t[1]) + " · " + rb1
        return t








func strength(cid_a: int, cid_b: int = -1) -> Dictionary:
        var key: String = "%d:%d" % [cid_a, cid_b]
        var cached: Array = _str_cache.get(key, [])
        if not cached.is_empty() and absf(gw.game_time - float(cached[0])) < 1.0:
                return (cached[1] as Dictionary).duplicate()
        var a: Country = gw.country_by_id(cid_a)
        var foe: Dictionary = {}
        if cid_b >= 0:
                foe[cid_b] = true
        elif a != null:
                for k: Variant in a.at_war:
                        foe[int(k)] = true
        var occ: Array = [{}, {}]
        var side_units: Array = [[], []]
        for u: Unit in gw.army.units:
                if not u.alive() or not u.ground() or u.type == Unit.Type.RECON:
                        continue
                var s: int = 0 if u.country_id == cid_a else (1 if foe.has(u.country_id) else -1)
                if s < 0:
                        continue
                (side_units[s] as Array).append(u)
                (occ[s] as Dictionary)[Vector2i(floori(u.pos.x / STR_CELL), floori(u.pos.y / STR_CELL))] = true

        var sea_units: Array = [[], []]
        if gw.get("naval") != null:
                for L: Dictionary in gw.naval.landings:
                        var lc: int = int(L["c"])
                        var s1: int = 0 if lc == cid_a else (1 if foe.has(lc) else -1)
                        if s1 < 0:
                                continue
                        for b: Dictionary in L["boats"]:
                                if bool(b["sunk"]) or bool(b.get("out", false)):
                                        continue
                                for ub: Unit in b["u"]:
                                        if ub.alive() and ub.type != Unit.Type.RECON:
                                                (sea_units[s1] as Array).append(ub)
        var front: bool = false
        var o1: Dictionary = occ[1]
        for c0: Vector2i in (occ[0] as Dictionary):
                for dy in range(-2, 3):
                        for dx in range(-2, 3):
                                if o1.has(c0 + Vector2i(dx, dy)):
                                        front = true
                if front:
                        break
        var pw: Array = [0.0, 0.0]
        var nn: Array = [0, 0]
        for s2 in 2:
                var other: Dictionary = occ[1 - s2]
                for u2: Unit in (side_units[s2] as Array):
                        if front:
                                var k2: = Vector2i(floori(u2.pos.x / STR_CELL), floori(u2.pos.y / STR_CELL))
                                var r: int = 3 if u2.indirect() else 2
                                var near: bool = false
                                for dy2 in range( - r, r + 1):
                                        for dx2 in range( - r, r + 1):
                                                if other.has(k2 + Vector2i(dx2, dy2)):
                                                        near = true
                                if not near:
                                        continue
                        pw[s2] = float(pw[s2]) + float(STR_W[u2.type]) * (0.5 + 0.5 * u2.hp / maxf(1.0, u2.max_hp))
                        nn[s2] = int(nn[s2]) + 1
                if not front:
                        for u3: Unit in (sea_units[s2] as Array):
                                pw[s2] = float(pw[s2]) + float(STR_W[u3.type]) * (0.5 + 0.5 * u3.hp / maxf(1.0, u3.max_hp))
                                nn[s2] = int(nn[s2]) + 1
        var ours: float = pw[0]
        var theirs: float = pw[1]
        var ratio: float = ours / (ours + theirs) if ours + theirs > 0.0 else 0.5
        var label: String = Loc.t("СИЛЫ РАВНЫ")
        if ours + theirs <= 0.0:
                label = Loc.t("ВОЙСК НЕТ")
        elif ratio >= 0.67:
                label = Loc.t("ЯВНЫЙ ПЕРЕВЕС")
        elif ratio >= 0.55:
                label = Loc.t("МЫ СИЛЬНЕЕ")
        elif ratio <= 0.33:
                label = Loc.t("ВРАГ НАМНОГО СИЛЬНЕЕ")
        elif ratio <= 0.45:
                label = Loc.t("ВРАГ СИЛЬНЕЕ")
        var out: Dictionary = {"ours": snappedf(ours, 0.1), "theirs": snappedf(theirs, 0.1), "ratio": ratio, "label": label, 
                "n_ours": int(nn[0]), "n_theirs": int(nn[1]), "front": front}
        _str_cache[key] = [gw.game_time, out]
        return out.duplicate()








func set_stance(f: Facility, s: int) -> String:
        if f == null or f.kind != Facility.Kind.BARRACKS:
                return Loc.t("Это не казармы")
        f.stance = clampi(s, 0, 2)
        if list.has(f) and bool(list[f].get("stance", false)) and f.stance == 0:
                list[f]["stance"] = false
        auto_next.erase("t%d" % f.id)
        auto_next.erase("a%d" % f.country_id)
        var c: Country = gw.country_by_id(f.country_id)
        var why: String = AutoCmd.attack_reason(gw, c, f) if f.stance == 2 else ""
        auto_next["n%d" % f.id] = why
        if c != null and c.is_player:
                gw.say(c, Loc.mk("Армия №%d: %s", [f.army_no, AutoCmd.STANCE_TITLES[f.stance].to_upper()]))
        return why


func stance_of(f: Facility) -> int:
        return f.stance if f != null else 0



func set_stance_all(country_id: int, s: int) -> int:
        var n: int = 0
        for f: Facility in gw.mil.facilities:
                if f.kind == Facility.Kind.BARRACKS and f.country_id == country_id and gw.mil.alive(f):
                        f.stance = clampi(s, 0, 2)
                        if list.has(f) and f.stance == 0 and bool(list[f].get("stance", false)):
                                list[f]["stance"] = false
                        auto_next.erase("t%d" % f.id)
                        n += 1
        var c: Country = gw.country_by_id(country_id)
        if c != null and c.is_player and n > 0:
                gw.say(c, Loc.mk("Все армии: %s", [AutoCmd.STANCE_TITLES[clampi(s, 0, 2)].to_upper()]))
        return n




func set_auto_orders(country_id: int, on: bool) -> void :
        auto_orders[country_id] = on
        auto_next.erase("o%d" % country_id)


func auto_orders_of(country_id: int) -> bool:
        return bool(auto_orders.get(country_id, false))






func command_summary(country_id: int) -> Dictionary:
        var out: Dictionary = AutoCmd.summary(gw, country_id)
        if gw.get("naval") == null:
                return out
        for a: Dictionary in out.get("armies", []):
                var f: Facility = null
                for g: Facility in gw.mil.facilities:
                        if g.id == int(a["fid"]):
                                f = g
                                break
                var sea: Array = gw.naval.aboard_of(f) if f != null else []
                a["at_sea"] = sea.size()
                a["landing"] = gw.naval.landing_info(f) if f != null else {}
                if sea.is_empty():
                        continue
                var n0: int = int(a["n"])
                var hp: float = 0.0
                var mhp: float = 0.0
                for u: Unit in sea:
                        if u.type != Unit.Type.FPV:
                                hp += u.hp
                                mhp += u.max_hp
                var n1: int = n0 + sea.size()
                a["hp_frac"] = (float(a["hp_frac"]) * float(n0) + (hp / maxf(1.0, mhp)) * float(sea.size())) / float(maxi(1, n1))
                a["n"] = n1
        return out




func _pf2(nm: String, t0: int) -> void :
        if not GameWorld.perf_prof:
                return
        var d: float = float(Time.get_ticks_usec() - t0) / 1000.0
        if d > float(gw.perf_sys.get(nm, 0.0)):
                gw.perf_sys[nm] = d


func update(dt: float) -> void :
        var _u0: int = Time.get_ticks_usec()
        _zones(dt)
        _pf2("ops:_zones", _u0)
        _u0 = Time.get_ticks_usec()
        _run_oq()
        _pf2("ops:_run_oq", _u0)
        _t += dt
        if _t < TICK:
                return
        var step: float = _t
        _t = 0.0
        _u0 = Time.get_ticks_usec()
        _adopt()
        _pf2("ops:_adopt", _u0)
        _u0 = Time.get_ticks_usec()
        for f: Facility in list.keys():
                if list.has(f):
                        _tick(list[f], step)
        _pf2("ops:_ticks", _u0)
        auto_ctx = true
        _u0 = Time.get_ticks_usec()
        for c: Country in gw.countries:
                if c.is_player or c.eliminated or c.capital_id < 0:
                        continue
                if gw.game_time >= float(_ai_next.get(c.id, 0.0)):
                        _ai_next[c.id] = gw.game_time + (AI_DT + float(c.id % 3) * 0.37) * GameConfig.ai_pace(gw.game_time)
                        _ai(c)
        _pf2("ops:_ai", _u0)
        _u0 = Time.get_ticks_usec()
        AutoCmd.tick(gw)
        _pf2("ops:autocmd", _u0)
        auto_ctx = false
        if floori(gw.game_time / HOSTAGE_DT) != floori((gw.game_time - step) / HOSTAGE_DT):
                _u0 = Time.get_ticks_usec()
                _wd_sweep()
                free_hostages()
                _pf2("ops:wd_sweep", _u0)
        if floori(gw.game_time / WD_DT) != floori((gw.game_time - step) / WD_DT):
                _u0 = Time.get_ticks_usec()
                _wd_tick()
                _pf2("ops:wd_tick", _u0)
        _warn_t -= step
        if _warn_t <= 0.0:
                _warn_t = 2.0
                _u0 = Time.get_ticks_usec()
                _warn_scan()
                _pf2("ops:warn_scan", _u0)









func _warn_scan() -> void :
        var p: Country = gw.player
        if p == null or p.eliminated or p.at_war.is_empty() or p.city_ids.is_empty():
                return
        var now: float = gw.game_time
        var per_city: Dictionary = {}
        var near_city: Dictionary = {}
        var seen_keys: Dictionary = {}
        for f: Facility in list:
                var op: Dictionary = list[f]
                var oc: int = int(op["c"])
                if oc == p.id or int(op["kind"]) != Kind.ATTACK or not gw.army._hostile(p.id, oc):
                        continue
                var city: City = null
                if int(op["city"]) >= 0:
                        city = gw.cities[int(op["city"])]
                else:
                        city = _near_city(op["target"])
                if city == null or city.country_id != p.id:
                        continue
                var fr: Vector2 = op["front"]
                var cp: = Vector2(city.center * GameWorld.CELL)
                var d: float = fr.distance_to(cp) - float(city.radius * GameWorld.CELL)
                if d < 40.0:
                        continue
                var ak: String = "%d:%d" % [f.id, city.id]
                seen_keys[ak] = true
                var ap: Array = _appr.get(ak, [d, now, 0, 0.0])
                var dtv: float = now - float(ap[1])
                if dtv > 0.5:
                        var v: float = (float(ap[0]) - d) / dtv
                        if v >= WARN_CLOSE_V:
                                ap = [d, now, int(ap[2]) + 1, v if int(ap[2]) == 0 else lerpf(float(ap[3]), v, 0.5)]
                        else:
                                ap = [d, now, 0, 0.0]
                        _appr[ak] = ap
                elif not _appr.has(ak):
                        _appr[ak] = ap
                if int(ap[2]) < 2:
                        continue
                var eta: float = d / maxf(float(ap[3]), 1.0)
                if eta <= WARN_FAR * 2.0:
                        near_city[city.id] = true
                var key: String = "%d:%d:%d" % [f.id, city.id, int(float(op["t0"]))]
                if _warned.has(key):
                        continue
                var seen: bool = _owner_at(fr) == p.id or gw.vision == null or not gw.vision.has_method("sees") or gw.vision.sees(fr)
                if eta > WARN_FAR or ( not seen and eta > WARN_ETA):
                        continue
                _warned[key] = now
                var e: Array = per_city.get(city.id, [0, INF, fr])
                e[0] = int(e[0]) + 1
                if eta < float(e[1]):
                        e[1] = eta
                        e[2] = fr
                per_city[city.id] = e
        for ak2: String in _appr.keys():
                if not seen_keys.has(ak2):
                        _appr.erase(ak2)
        for cid0: int in near_city:
                var wc: Array = _wcity.get(cid0, [true, now])
                wc[1] = now
                _wcity[cid0] = wc
        for cid1: int in _wcity.keys():
                var wc1: Array = _wcity[cid1]
                if not bool(wc1[0]) and now - float(wc1[1]) >= WARN_REARM:
                        wc1[0] = true
        for cid: int in per_city:
                var wc2: Array = _wcity.get(cid, [true, now])
                if not bool(wc2[0]) or now - float(_warned.get("c%d" % cid, -999.0)) < WARN_CITY_GAP:
                        continue
                wc2[0] = false
                wc2[1] = now
                _wcity[cid] = wc2
                _warned["c%d" % cid] = now
                _warn(p, gw.cities[cid], per_city[cid])
        if _warned.size() > 64:
                for k: String in _warned.keys():
                        if now - float(_warned[k]) > 900.0:
                                _warned.erase(k)


func _warn(p: Country, city: City, e: Array) -> void :
        var n: int = int(e[0])
        var eta: float = float(e[1])
        var fr: Vector2 = e[2]
        var cp: = Vector2(city.center * GameWorld.CELL)
        var edge: float = float(city.radius * GameWorld.CELL)
        var when : Array = Loc.mk("меньше минуты") if eta < 60.0 else Loc.mk("~%d мин", [maxi(1, roundi(eta / 60.0))])
        var who: Array = Loc.mk("Армия врага идёт") if n == 1 else Loc.mk("%d армии врага идут", [n])
        var head: Array = Loc.mk("{who} к {city:dat} ({when})", {"who": who, "city": city.name, "when": when })
        var pr: Dictionary = {}
        var text: Array = []
        if _city_covered(p.id, cp, edge):
                text = Loc.mk("%s — наша армия рядом", [head])
        else:
                var fid: int = _idle_barracks(p.id, cp, 3)
                if fid >= 0:
                        text = Loc.mk("%s — ОБОРОНА?", [head])
                        pr = _pr("op_defend", "c%d" % city.id, text, KIND_ICONS[Kind.DEFEND], cp + (fr - cp).normalized() * (edge + 30.0), fid)
                else:
                        text = Loc.mk("%s — свободных армий нет: займите окопы", [head])
                        pr = _pr("look", "w%d" % city.id, text, KIND_ICONS[Kind.DEFEND], fr, -1)
        if pr.is_empty():
                gw.say(p, text)
        Sfx.play("ui_alert", Vector2.INF, -4.0)
        _prompted["op_defend:c%d" % city.id] = gw.game_time
        if not pr.is_empty():
                pr["cid"] = city.id
                pr["t"] = gw.game_time
                pr["warn"] = true
                _urgent.append(pr)



func _adopt() -> void :
        var tac = gw.army.tac
        for h: Facility in tac.ops:
                var top: Dictionary = tac.ops[h]
                if list.has(h):
                        var op: Dictionary = list[h]
                        if int(op["kind"]) == Kind.ATTACK and int(op["city"]) != int(top["city"]) and int(top["city"]) >= 0:
                                op["city"] = int(top["city"])
                                op["target"] = top["goal"]
                                op["path"] = _simplify(top["path"])
                                op["dist0"] = maxf(1.0, _path_len(top["path"]))
                        continue
                if bool(top.get("area", false)) or not gw.mil.facilities.has(h) or h.country_id != int(top["c"]):
                        continue
                list[h] = _new_op(h, Kind.ATTACK, top["goal"], Vector2.INF, int(top["city"]), top["path"], true)


func _new_op(f: Facility, kind: int, target: Vector2, wp: Vector2, city: int, path: PackedVector2Array, auto: bool) -> Dictionary:
        var from: Vector2 = _from(f)
        var n0: float = 0.0
        for u: Unit in _army(f):
                n0 += u.hp
        return {"f": f, "fid": f.id, "kind": kind, "c": f.country_id, "target": target, "wp": wp, "city": city, "t0": gw.game_time, 
                "n0": maxf(1.0, n0), "state": Loc.mk("выдвижение"), "progress": 0.0, "losses": 0.0, "from": from, "path": _simplify(path), 
                "front": from, "held_t": -1.0, "quiet_t": -1.0, "auto": auto, "dist0": maxf(1.0, _path_len(path)), "said": "", 
                "retreat_at": RETREAT_AT, "home_t": -1.0}


func _tick(op: Dictionary, dt: float) -> void :
        if bool(op.get("wait", false)):
                if not _queued(op["f"]):
                        list.erase(op["f"])
                return
        var f: Facility = op["f"]
        var c: Country = gw.country_by_id(int(op["c"]))
        if not gw.mil.facilities.has(f) or f.country_id != int(op["c"]) or c == null:

                _finish(op, false, Loc.t("Армия №%d: казармы потеряны, приказ прерван") % f.army_no)
                return
        if gw.naval != null and gw.naval.busy(f):
                op["state"] = gw.naval.status_text(f)
                var fp: Vector2 = gw.naval.front(f)
                if fp.is_finite():
                        op["front"] = fp
                return
        var mem: Array[Unit] = []
        for u: Unit in gw.army.units:
                if u.home == f and u.alive() and u.ground() and (u.op_on or int(op["kind"]) == Kind.RETREAT and u.post == null and u.reinf == 0):
                        mem.append(u)
        if mem.is_empty():

                mem = _army(f)
        if mem.is_empty():
                if not _army(f, true).is_empty():
                        _finish(op, true, Loc.t("Армия №%d заняла укрепления") % f.army_no)
                else:
                        _finish(op, false, Loc.t("Армия №%d: войск не осталось") % f.army_no)
                return
        var cen: = Vector2.ZERO
        var hp: float = 0.0
        for u: Unit in mem:
                cen += u.pos
                hp += u.hp
        cen /= float(mem.size())
        for u3: Unit in gw.army.units:


                if u3.home == f and u3.post != null and u3.alive() and not u3.op_on:
                        hp += u3.hp
        op["front"] = cen
        var kind: int = int(op["kind"])
        if kind != Kind.RETREAT and (bool(op.get("held", false)) or (kind == Kind.DEFEND and op.has("fp") and c.is_player)):
                op["n0"] = maxf(float(op["n0"]), hp)
        op["losses"] = clampf(1.0 - hp / float(op["n0"]), 0.0, 1.0)
        if kind != Kind.RETREAT and gw.game_time >= float(op.get("rf_t", -1.0)):
                op["rf_t"] = gw.game_time + REINF_DT
                if c.is_player or op.has("fp"):
                        _reinforce(op, c)
        if kind == Kind.RETREAT:
                _tick_retreat(op, mem, dt)
                return
        var tac = gw.army.tac
        var top: Dictionary = tac.ops.get(f, {})
        var contact: bool = not top.is_empty() and gw.game_time - float(top["contact"]) < 10.0
        var afloat: bool = gw.naval != null and gw.naval.busy(f)
        if float(op["losses"]) >= float(op["retreat_at"]) and int(op["kind"]) != Kind.RETREAT and not afloat\
        and not (int(op["kind"]) == Kind.ATTACK and int(op["city"]) >= 0 and manual(f)):
                _to_retreat(op, Loc.mk("потери %d%%, отход", [roundi(float(op["losses"]) * 100.0)]))
                return
        var city: City = gw.cities[int(op["city"])] if int(op["city"]) >= 0 else null
        var place: String = _where(op)
        var d_left: float = cen.distance_to(op["target"])
        var approach: float = clampf(1.0 - d_left / float(op["dist0"]), 0.0, 1.0)
        if kind == Kind.ATTACK and city != null:
                if city.country_id == int(op["c"]):
                        if float(op["held_t"]) < 0.0:
                                op["held_t"] = gw.game_time
                                _say(op, Loc.mk("Армия №{n} взяла {city:acc}", {"n": f.army_no, "city": city.name}))
                        op["state"] = Loc.mk("закрепились в {city:loc}", {"city": city.name})
                        op["progress"] = 1.0
                        if gw.game_time - float(op["held_t"]) > DONE_HOLD:
                                _finish(op, true, Loc.t("Армия №%d: %s — приказ выполнен") % [f.army_no, Loc.msg(op["state"])])
                        return
                if top.is_empty():
                        # R-OBED: тактический план кончился (штурм отменён/застряли).
                        # Раньше при потерях >= 30% вся армия уходила к казармам — это и
                        # было «подошли и ушли». Теперь: отход только при тяжёлых потерях
                        # (retreat_at), иначе армия закрепляется на достигнутом рубеже.
                        if float(op["losses"]) >= float(op["retreat_at"]) and not afloat:
                                _to_retreat(op, Loc.mk("потери %d%%, отход", [roundi(float(op["losses"]) * 100.0)]))
                        else:
                                _finish(op, false, Loc.t("Армия №%d: закрепилась на достигнутом рубеже") % f.army_no)
                        return
                var ph: int = int(top["phase"])
                match ph:
                        0:
                                op["state"] = Loc.mk("бой у {city:gen}", {"city": city.name}) if contact else Loc.mk("выдвижение к {city:dat}", {"city": city.name})
                                op["progress"] = approach * 0.6
                        1:
                                op["state"] = Loc.mk("бой у {city:gen}", {"city": city.name}) if contact else Loc.mk("перебежками к {city:dat}", {"city": city.name})
                                op["progress"] = approach * 0.6
                        2:
                                op["state"] = Loc.mk("у {city:gen}: ждём огня", {"city": city.name}) if bool(top.get("holding", false)) else Loc.mk("сбор перед штурмом")
                                op["progress"] = 0.65
                        3:
                                op["state"] = Loc.mk("штурм: {city}", {"city": city.name})
                                op["progress"] = 0.7 + 0.3 * maxf(city.capture, 1.0 - city.garrison / maxf(1.0, city.garrison_max)) * 0.9
                        4:
                                op["state"] = Loc.mk("огонь по {city:dat}", {"city": city.name})
                                op["progress"] = 0.6 + 0.3 * (1.0 - city.garrison / maxf(1.0, city.garrison_max))
                if contact:
                        _say(op, Loc.mk("Армия №%d: %s", [f.army_no, Loc.msg(op["state"])]), "contact")
                return

        if top.is_empty():
                # R-OBED: как выше — без автоматического ухода к казармам.
                if float(op["losses"]) >= float(op["retreat_at"]) and not afloat:
                        _to_retreat(op, Loc.mk("потери %d%%, отход", [roundi(float(op["losses"]) * 100.0)]))
                else:
                        _finish(op, false, Loc.t("Армия №%d: закрепилась на достигнутом рубеже") % f.army_no)
                return
        var hold: bool = int(top["phase"]) == 5 or int(top["phase"]) == 4
        if not hold:
                var nc: City = _near_city(op["target"])
                op["state"] = Loc.mk("бой {place}", {"place": _where_m(op)}) if contact else (Loc.mk("выдвижение к рубежу") if kind == Kind.DEFEND or nc == null else Loc.mk("выдвижение к {city:dat}", {"city": nc.name}))
                op["progress"] = approach * 0.9
                if contact:
                        _say(op, Loc.mk("Армия №%d: бой %s", [f.army_no, place]), "contact")
                return
        op["progress"] = 1.0
        if contact:
                op["quiet_t"] = -1.0
                op["state"] = Loc.mk("бой на рубеже")
                _say(op, Loc.mk("Армия №%d: бой на рубеже %s", [f.army_no, place]), "contact")
                return
        if float(op["quiet_t"]) < 0.0:
                op["quiet_t"] = gw.game_time
        if kind == Kind.DEFEND:
                op["state"] = Loc.mk("держим рубеж")
                _say(op, Loc.mk("Армия №%d заняла оборону %s", [f.army_no, place]), "hold")
                return
        op["state"] = Loc.mk("закрепились")
        if gw.game_time - float(op["quiet_t"]) > DONE_HOLD:
                _finish(op, true, Loc.t("Армия №%d закрепилась %s — приказ выполнен") % [f.army_no, place])



func _tick_retreat(op: Dictionary, mem: Array[Unit], dt: float) -> void :
        var f: Facility = op["f"]
        var home: Vector2 = gw.army.barracks_out(f)
        var at_home: int = 0
        var hp: float = 0.0
        var mhp: float = 0.0
        for u: Unit in mem:
                var dest: Vector2 = home + u.slot
                if u.pos.distance_to(dest) <= HOME_R or (u.pi >= u.path.size() and u.pos.distance_to(home) < HOME_R * 2.0):
                        at_home += 1
                        u.op_move = false
                        if gw.game_time - u.hit_t > 5.0:
                                u.hp = minf(u.max_hp, u.hp + u.max_hp * HEAL_RATE * dt)
                elif u.pi >= u.path.size() and u.target == null:

                        u.path = gw.econ.nav_path(u.pos, dest)
                        if u.path.is_empty():
                                u.path = PackedVector2Array([dest])
                        u.pi = 0
                        u.state = Unit.State.MOVE
                hp += u.hp
                mhp += u.max_hp
        var share: float = float(at_home) / float(mem.size())
        var healed: float = hp / maxf(1.0, mhp)
        op["progress"] = share * 0.6 + healed * 0.4 if share >= 0.99 else share * 0.6
        if share < 0.8:
                if state_kind(op["state"]) == "losses" and gw.game_time - float(op["t0"]) < 25.0:
                        pass
                else:
                        op["state"] = Loc.mk("отход к казармам")
                op["home_t"] = -1.0
                return
        if float(op["home_t"]) < 0.0:
                op["home_t"] = gw.game_time
        op["state"] = Loc.mk("у казарм: лечение %d%%", [roundi(healed * 100.0)])
        if healed >= 0.97 or gw.game_time - float(op["home_t"]) > 70.0:
                _finish(op, true, Loc.t("Армия №%d отошла и восстановилась") % f.army_no)





var _landed: Dictionary = {}


func on_landed(f: Facility, landed: Array, beach: Vector2) -> void :
        _landed[f] = gw.game_time
        if not list.has(f):
                return
        var op: Dictionary = list[f]
        var hp: float = 0.0
        for u: Unit in landed:
                hp += u.hp
        op["n0"] = maxf(1.0, hp)
        op["losses"] = 0.0
        op["landed"] = true
        op["beach"] = beach


func _to_retreat(op: Dictionary, why: Variant) -> void :
        var f: Facility = op["f"]
        if _hold_on(op):
                return
        if _no_auto_hold(op):
                return
        if bool(op.get("shattered", false)):
                why = Loc.mk("разбита (осталось %d%%), отход к казармам на пополнение", [roundi((1.0 - float(op["losses"])) * 100.0)])
        var ashore: bool = bool(op.get("landed", false)) or gw.game_time - float(_landed.get(f, -1000000000.0)) < 900.0
        if ashore and int(op["kind"]) != Kind.RETREAT:
                var mem0: Array[Unit] = _army(f)
                if not mem0.is_empty():
                        gw.econ.nav_path(_centre(mem0), gw.army.barracks_out(f))
                        if not gw.econ.nav_last_ok:

                                op["retreat_at"] = 2.0
                                op["state"] = Loc.mk("держит плацдарм")
                                gw.army.tac.start_area(f, mem0, _centre(mem0), Vector2.INF, true)
                                var cw: Country = gw.country_by_id(int(op["c"]))
                                if cw != null and cw.is_player:
                                        gw.say(cw, Loc.mk("Армия №%d: %s, держит плацдарм", [f.army_no, Loc.msg(why)]))
                                return
        var mem1: Array[Unit] = _army(f)
        if not mem1.is_empty() and gw.diplo != null:
                var c1: Vector2 = _centre(mem1)
                var lr: Dictionary = AutoCmd.FrontPlan.legal_route(gw, f.country_id, c1, gw.army.barracks_out(f))
                if bool(lr.get("busy", false)):
                        return
                if not bool(lr.get("ok", false)):

                        op["retreat_at"] = 2.0
                        op["state"] = Loc.mk("нет пути домой без права прохода — держим позицию")
                        gw.army.tac.start_area(f, mem1, c1, Vector2.INF, true)
                        AutoCmd.FrontPlan._stat("pass_hold")
                        return
                op["home_chain"] = lr["chain"]
        gw.army.tac.stop(f)
        op["kind"] = Kind.RETREAT
        op["state"] = why
        op["t0"] = gw.game_time
        op["target"] = gw.army.barracks_out(f)
        op["path"] = _simplify(gw.econ.nav_path(op["front"], op["target"]))
        op["city"] = -1
        op["home_t"] = -1.0
        _send_home(op)
        var c: Country = gw.country_by_id(int(op["c"]))
        if c != null and c.is_player:
                gw.say(c, Loc.mk("Армия №%d: %s", [f.army_no, Loc.msg(why)]))
                Sfx.play("ui_alert", Vector2.INF, -6.0)













func manual(f: Facility) -> bool:
        if f == null:
                return false
        var c: Country = gw.country_by_id(f.country_id)
        if c == null or not c.is_player or auto_orders_of(c.id):
                return false
        if f.group_id >= 0:
                for g: Dictionary in c.army_groups:
                        if int(g["id"]) == f.group_id and bool(g.get("auto", false)):
                                return false
        return true


func _no_auto_hold(op: Dictionary) -> bool:
        if int(op["kind"]) == Kind.RETREAT or bool(op.get("stance", false)):
                return false
        var c: Country = gw.country_by_id(int(op["c"]))
        if c == null or not c.is_player or auto_orders_of(c.id):
                return false
        var f: Facility = op["f"]
        if f.group_id >= 0:
                for g: Dictionary in c.army_groups:
                        if int(g["id"]) == f.group_id and bool(g.get("auto", false)):
                                return false
        if gw.naval != null and gw.naval.busy(f):
                return false
        var mem: Array[Unit] = _army(f)
        if mem.is_empty():
                return false
        var goal: Vector2 = _centre(mem)
        if int(op["kind"]) == Kind.DEFEND and (op["target"] as Vector2).is_finite() and (op["target"] as Vector2).distance_to(goal) < 400.0:
                goal = op["target"]
        gw.army.tac.start_area(f, mem, goal, Vector2.INF, true)
        op["kind"] = Kind.DEFEND
        op["target"] = goal
        op["city"] = -1
        op["retreat_at"] = 2.0
        op["held"] = true
        op["held_t"] = -1.0
        op["quiet_t"] = -1.0
        op["state"] = Loc.mk("держит позицию до приказа")
        return true


func _hold_on(op: Dictionary) -> bool:
        if int(op["kind"]) == Kind.RETREAT or bool(op.get("stance", false)) or bool(op.get("landed", false)):
                return false
        var f: Facility = op["f"]
        var c: Country = gw.country_by_id(int(op["c"]))
        if c == null or not c.is_player or f.group_id < 0 or (gw.naval != null and gw.naval.busy(f)):
                return false
        var mem: Array[Unit] = _army(f)
        if mem.size() < 2:
                return false
        var hp: float = 0.0
        for u: Unit in mem:
                hp += u.hp
        var peak: float = maxf(float(op.get("peak", 0.0)), float(op["n0"]))
        if hp < peak * (1.0 - SHATTER):
                op["shattered"] = true
                AutoCmd.FrontPlan._stat("army_shattered")
                return false
        var goal: Vector2 = _centre(mem)
        var slot: Vector2 = AutoCmd.FrontPlan.slot_of(gw, f) if op.has("fp") else Vector2.INF
        var back: bool = slot.is_finite()
        if back:
                goal = slot
        elif int(op["kind"]) == Kind.DEFEND and (op["target"] as Vector2).distance_to(goal) < 400.0:
                goal = op["target"]
        if not gw.army.tac.start_area(f, mem, goal, Vector2.INF, true):
                return false
        var was_attack: bool = int(op["kind"]) == Kind.ATTACK
        op["kind"] = Kind.DEFEND
        op["target"] = goal
        op["city"] = -1
        op["n0"] = peak
        op["peak"] = peak
        op["retreat_at"] = SHATTER
        op["held"] = true
        op["held_t"] = -1.0
        op["quiet_t"] = -1.0
        if was_attack and op.has("fp"):
                op["fell_back"] = true
        op["state"] = Loc.mk("потери %d%%: %s", [roundi(float(op["losses"]) * 100.0), Loc.mk("назад на фронт") if back else Loc.mk("держим позицию")])
        AutoCmd.FrontPlan._stat("hold_on")
        if not bool(op.get("held_said", false)):
                op["held_said"] = true
                gw.say(c, Loc.mk("Армия №%d: потери %d%% — %s, пополнение подойдёт к ней", [f.army_no, roundi(float(op["losses"]) * 100.0), Loc.t("отходит на линию фронта") if back else Loc.t("держит позицию")]))
        return true





func _reinforce(op: Dictionary, c: Country) -> void :
        var f: Facility = op["f"]
        if gw.army.tac.ops.get(f, {}).is_empty() or (gw.naval != null and gw.naval.busy(f)):
                return
        var home: Vector2 = gw.army.barracks_out(f)
        if (op["front"] as Vector2).distance_to(home) < REINF_FAR:
                return
        var n: int = 0
        for u: Unit in gw.army.units:
                if u.home != f or u.op_on or u.post != null or not u.alive() or not u.ground() or u.state != Unit.State.IDLE or _kept(u) or u.reinf != 0:
                        continue
                if c.is_player and (op["front"] as Vector2).distance_to(home) >= REINF_SQUAD_FAR and gw.game_time >= u.reinf_t:
                        continue
                if u.pos.distance_to(home) > REINF_HOME_R:
                        continue
                if not rejoin(u):
                        break
                if AutoCmd.FrontPlan.closed_path(gw, u.country_id, u.path):
                        u.op_on = false
                        u.path = PackedVector2Array()
                        u.pi = 0
                        u.state = Unit.State.IDLE
                        continue
                n += 1
        if n > 0:
                AutoCmd.FrontPlan._stat("reinforce_units", n)


func _send_home(op: Dictionary) -> void :
        var f: Facility = op["f"]
        var home: Vector2 = gw.army.barracks_out(f)
        if gw.naval != null and not gw.naval.busy(f):
                var mem0: Array[Unit] = _army(f)
                if not mem0.is_empty():
                        gw.econ.nav_path(_centre(mem0), home)
                        if not gw.econ.nav_last_ok and gw.naval.divert(f, mem0, null, home, Naval.Mode.RETREAT) == 1:
                                return
        var hch: Variant = op.get("home_chain")
        var tac = gw.army.tac
        for u: Unit in _army(f):
                var dest: Vector2 = home + u.slot
                u.op_on = true
                u.op_hold = false
                u.op_move = true
                u.target_city = -1
                u.target = null
                if hch is PackedVector2Array and (hch as PackedVector2Array).size() > 0 and u.pos.distance_to(dest) > 40.0:
                        tac.chain = hch
                        u.path = tac.route(u.pos, dest)
                        tac.chain = PackedVector2Array()
                else:
                        u.path = gw.econ.nav_path(u.pos, dest) if u.pos.distance_to(dest) > 40.0 else PackedVector2Array([dest])
                if u.path.is_empty():
                        u.path = PackedVector2Array([dest])
                u.path[u.path.size() - 1] = dest
                u.pi = 0
                u.state = Unit.State.MOVE



func _release(op: Dictionary, stop_tac: bool) -> void :
        var f: Facility = op["f"]
        if stop_tac or int(op["kind"]) == Kind.RETREAT:
                gw.army.tac.stop(f)
        if int(op["kind"]) == Kind.RETREAT:
                for u: Unit in gw.army.units:
                        if u.home == f and u.alive() and u.op_on:
                                u.op_on = false
                                u.op_move = false
                                u.op_hold = false
                                if u.pi >= u.path.size():
                                        u.state = Unit.State.IDLE


func _finish(op: Dictionary, ok: bool, text: String) -> void :
        var f: Facility = op["f"]
        _release(op, int(op["kind"]) != Kind.ATTACK or int(op["city"]) < 0)
        list.erase(f)
        var c: Country = gw.country_by_id(int(op["c"]))
        if c != null and c.is_player and not bool(op.get("stance", false)) and int(op["kind"]) != Kind.RETREAT:
                auto_next["k%d" % f.id] = gw.game_time
        if c != null and c.is_player:
                gw.say(c, text)
                Sfx.play("ui_capture" if ok else "ui_alert", Vector2.INF, -8.0)



func _say(op: Dictionary, text: Variant, what: String = "") -> void :
        var key: String = what if what != "" else Loc.src(text)
        if String(op["said"]) == key:
                return
        op["said"] = key
        var c: Country = gw.country_by_id(int(op["c"]))
        if c != null and c.is_player:
                gw.say(c, text)




func _zones(dt: float) -> void :
        var now: float = gw.game_time
        for k in range(zones.size() - 1, -1, -1):
                var z: Dictionary = zones[k]
                match int(z["k"]):
                        Order.ARTY:
                                _barrage(z)
                        Order.MEDIC:
                                z["tick"] = float(z.get("tick", 0.0)) - dt
                                if float(z["tick"]) <= 0.0:
                                        z["tick"] = 0.5
                                        _heal(z, 0.5)
                if now >= float(z["until"]):
                        for h: Array in z["fx"]:
                                gw.fx.stop_h(h)
                        zones.remove_at(k)


func _barrage(z: Dictionary) -> void :
        var now: float = gw.game_time
        var n: int = 0
        while int(z["left"]) > 0 and now >= float(z["next"]) and n < 4:
                n += 1
                z["left"] = int(z["left"]) - 1
                var spec: Dictionary = ORDERS[Order.ARTY]
                z["next"] = float(z["next"]) + float(spec["dur"]) / float(spec["shells"]) * gw.army.fire.rfr(0.5, 1.5)
                var p: Vector2 = z["pos"]
                var to: Vector2 = p + Vector2.from_angle(gw.army.fire.rf() * TAU) * float(z["r"]) * sqrt(gw.army.fire.rf())
                var gun: Vector2 = z["gun"]
                var from: Vector2 = gun if gun.is_finite() else p + Vector2(-260.0, -420.0).rotated(float(int(z["id"]) % 7) * 0.4)
                var d: float = from.distance_to(to)
                var dur: float = clampf(1.0 + d / 320.0, 1.2, 3.5)
                gw.army.fire.shells.append({"k": 1, "from": from, "to": to, "t": 0.0 if gun.is_finite() else dur * 0.55, "dur": dur, "h": clampf(d * 0.1, 30.0, 70.0), 
                        "dmg": SHELL_DMG, "r": SHELL_BLAST, "c": int(z["c"]), "pts": PackedVector2Array(), "whistle": false, "trail": 0.0})
                if gun.is_finite():
                        if gw._on_screen(gun, 60.0):
                                gw.fx.spawn(_fxn("arty_flash", "tank_shot"), gun.round(), 6)
                        Sfx.play("artillery_fire", gun, -4.0)
                elif randi() % 3 == 0:
                        Sfx.play("artillery_far", Vector2.INF, -6.0)


        if now >= float(z["t0"]) + WARN_T + 1.0:
                var pr: float = float(z["r"]) * 1.25
                # Сетка вместо полного перебора юнитов (радиус pr с запасом).
                for u: Unit in gw.army._near(z["pos"], pr):
                        if u.alive() and u.ground() and gw.army._hostile(int(z["c"]), u.country_id) and u.pos.distance_squared_to(z["pos"]) <= pr * pr:
                                u.supp = maxf(u.supp, 0.5 if u.type == Unit.Type.TANK else 0.85)
        if not bool(z["hit"]) and now >= float(z["t0"]) + WARN_T + 1.2:
                z["hit"] = true
                if gw.battle_watch != null:
                        gw.battle_watch.impact(z["pos"], "Артудар", int(z["c"]))


func _smoke_fx(z: Dictionary) -> void :
        var p: Vector2 = z["pos"]
        if not _visible(p, int(z["c"])):
                return
        var r: float = float(z["r"])
        var until: float = float(z["until"])
        var n: String = _fxn("smoke_wall_loop", "smoke_screen_loop")
        for i in 9:
                var a: float = float(i) / 9.0 * TAU + 0.3
                var q: Vector2 = p + (Vector2.from_angle(a) * Vector2(1.0, 0.7) * r * (0.62 if i % 2 == 0 else 0.3) if i > 0 else Vector2.ZERO)
                z["fx"].append(gw.fx.handle(gw.fx.spawn(n, q.round(), 5, until - float(i % 3) * 0.6, true)))
        for i in 3:
                gw.fx.spawn(_fxn("smoke_pop", "grenade_burst"), (p + Vector2.from_angle(float(i) * 2.1) * r * 0.4).round(), 6)




func _heal(z: Dictionary, dt: float) -> void :
        var c: int = int(z["c"])
        var p: Vector2 = z["pos"]
        var r2: float = float(z["r"]) * float(z["r"])
        var homes: Array = []
        for u: Unit in gw.army.units:
                if u.country_id != c or not u.alive() or not u.ground() or u.pos.distance_squared_to(p) > r2:
                        continue
                if u.hp < u.max_hp:
                        var k: float = MEDIC_HIT_K if gw.game_time - u.hit_t < 3.0 else 1.0
                        u.hp = minf(u.max_hp, u.hp + u.max_hp * MEDIC_RATE * k * dt)
                if u.home != null and not homes.has(u.home.id):
                        homes.append(u.home.id)
        z["homes"] = homes




func _ai(c: Country) -> void :
        if c.at_war.is_empty():
                return
        var per: Dictionary = {}
        if gw.ai != null and gw.ai.has_method("persona_of"):
                per = gw.ai.call("persona_of", c)
        var aggr: float = float(per.get("aggr", 0.5))
        var caution: float = float(per.get("caution", 0.5))
        var dk: float = [0.55, 0.8, 1.0][GameConfig.diff_of(c)] * (1.0 - 0.5 * GameConfig.early_damp(gw.game_time))
        var reserve: int = 250 + int(caution * 300.0)

        for f: Facility in list:
                var op: Dictionary = list[f]
                if int(op["c"]) == c.id and int(op["kind"]) != Kind.RETREAT:
                        op["retreat_at"] = 0.6 - 0.25 * caution
        _ai_defend(c, caution, dk)

        var spotted: Array = gw.army.fire.spotted.get(c.id, [])

        if cooldown_left(c.id, Order.ARTY) <= 0.0 and gw.hold != null:
                var hp: Vector2 = gw.hold.arty_target(c.id)
                if hp.is_finite() and gw.army.fire.rf() < (0.5 + 0.4 * aggr) * dk and _ai_afford(c, Order.ARTY, hp, reserve):
                        if order(c.id, Order.ARTY, hp) == "":
                                gw.hold.stats["bot_arty"] = int(gw.hold.stats.get("bot_arty", 0)) + 1
                                return
        if cooldown_left(c.id, Order.ARTY) <= 0.0 and gw.army.fire.rf() < (0.3 + 0.5 * aggr) * dk:
                var best: = Vector2.INF
                var bn: int = 2
                # Сетка 45px: соседи считаются в нативе (df_native.spot_density,
                # f32-паритет с Vector2.distance_squared_to) или, если библиотеки
                # нет, по ячейкам 3x3 с точной проверкой дистанции — семантика та же.
                var _dens: Array = []
                var _poss: Array = []
                if _nat != null:
                        var pxs := PackedFloat64Array()
                        for e0: Array in spotted:
                                if not (e0[1] is Unit):
                                        continue
                                pxs.append((e0[0] as Vector2).x)
                                pxs.append((e0[0] as Vector2).y)
                                _poss.append(e0[0] as Vector2)
                        if pxs.size() > 0:
                                _dens = _nat.spot_density(pxs)
                                if OS.get_environment("DF_WD_VERIFY") == "1":
                                        var g_dens: Array = []
                                        for ii0 in _poss.size():
                                                var ep0: Vector2 = _poss[ii0]
                                                var scx0: int = floori(ep0.x / 45.0)
                                                var scy0: int = floori(ep0.y / 45.0)
                                                var n00: int = 0
                                                for e3: Array in spotted:
                                                        if not (e3[1] is Unit):
                                                                continue
                                                        if (e3[0] as Vector2).distance_squared_to(ep0) < 2025.0:
                                                                n00 += 1
                                                g_dens.append(n00)
                                        var bad: int = 0
                                        for ii1 in _dens.size():
                                                if int(_dens[ii1]) != int(g_dens[ii1]):
                                                        bad += 1
                                        if bad > 0:
                                                push_error("[DENS-VERIFY] %d/%d mismatched" % [bad, _dens.size()])
                                        else:
                                                print("[DENS-VERIFY] ok: n=", _dens.size())
                if _nat == null:
                        var sc: Dictionary = {}
                        for e: Array in spotted:
                                if not (e[1] is Unit):
                                        continue
                                var sp0: Vector2 = e[0]
                                var sk: = Vector2i(floori(sp0.x / 45.0), floori(sp0.y / 45.0))
                                var sl: Variant = sc.get(sk)
                                if sl == null:
                                        sl = []
                                        sc[sk] = sl
                                (sl as Array).append(e)
                        for e: Array in spotted:
                                if not (e[1] is Unit):
                                        continue
                                _poss.append(e[0] as Vector2)
                                var ep0: Vector2 = e[0]
                                var scx: int = floori(ep0.x / 45.0)
                                var scy: int = floori(ep0.y / 45.0)
                                var n0: int = 0
                                for dy in range(-1, 2):
                                        for dx in range(-1, 2):
                                                var sl2: Variant = sc.get(Vector2i(scx + dx, scy + dy))
                                                if sl2 == null:
                                                        continue
                                                for e2: Array in (sl2 as Array):
                                                        if (e2[0] as Vector2).distance_squared_to(ep0) < 2025.0:
                                                                n0 += 1
                                _dens.append(n0)
                for ii in _poss.size():
                        var ep: Vector2 = _poss[ii]
                        var n: int = _dens[ii]
                        if n > bn and gw.hold != null and gw.hold._friend_near(c.id, ep, gw.hold.ARTY_SAFE):
                                continue
                        if n > bn:
                                bn = n
                                best = ep
                if best.is_finite() and _ai_afford(c, Order.ARTY, best, reserve):
                        order(c.id, Order.ARTY, best)
                        return
        if cooldown_left(c.id, Order.SMOKE) <= 0.0 and gw.army.fire.rf() < (0.25 + 0.45 * caution) * dk:
                for f2: Facility in gw.army.tac.ops:
                        var top: Dictionary = gw.army.tac.ops[f2]
                        if int(top["c"]) != c.id or not top.has("cen"):
                                continue
                        var ph: int = int(top["phase"])
                        var foe: Vector2 = top["foe"]
                        if (ph == 1 or (ph == 2 and bool(top.get("holding", false)))) and foe.is_finite() and gw.game_time - float(top["contact"]) < 6.0:
                                var sp: Vector2 = (top["cen"] as Vector2).lerp(foe, 0.45)
                                if _ai_afford(c, Order.SMOKE, sp, reserve):
                                        order(c.id, Order.SMOKE, sp)
                                        return
        if cooldown_left(c.id, Order.MEDIC) <= 0.0 and gw.army.fire.rf() < (0.3 + 0.4 * caution) * dk:
                var hs: Vector2 = medic_spot(c.id)
                if hs.is_finite() and _ai_afford(c, Order.MEDIC, hs, reserve):
                        order(c.id, Order.MEDIC, hs)


func _ai_afford(c: Country, kind: int, p: Vector2, reserve: int) -> bool:
        var chk: Dictionary = order_check(c.id, kind, p)
        return bool(chk["ok"]) and c.money - int((chk["cost"] as Dictionary).get("money", 0)) >= reserve



func _ai_defend(c: Country, caution: float, dk: float) -> void :
        if gw.army.fire.rf() > (0.45 + 0.4 * caution) * dk:
                return
        for f: Facility in list:
                var op: Dictionary = list[f]
                if int(op["c"]) == c.id or not gw.army._hostile(c.id, int(op["c"])) or int(op["kind"]) != Kind.ATTACK:
                        continue
                var front: Vector2 = op["front"]
                for cid in c.city_ids:
                        var city: City = gw.cities[cid]
                        var cp: = Vector2(city.center * GameWorld.CELL)
                        var edge: float = float(city.radius * GameWorld.CELL)
                        if front.distance_to(cp) > edge + 700.0 or (op["target"] as Vector2).distance_to(cp) > edge + 300.0:
                                continue
                        var line: Vector2 = cp + (front - cp).normalized() * (edge + 30.0)
                        for b: Facility in gw.mil.facilities:
                                if b.kind != Facility.Kind.BARRACKS or b.country_id != c.id or list.has(b) or not gw.mil.alive(b):
                                        continue
                                if _army(b).size() < 4 or b.center_px().distance_to(line) > 2400.0:
                                        continue
                                if gw.naval != null and gw.naval.busy(b):
                                        continue
                                if start(b, Kind.DEFEND, line) == "":
                                        return







func _find_prompt(p: Country) -> Array:
        var now: float = gw.game_time
        var out: Array = []
        var mine: Array = list_for(p.id)
        for d: Dictionary in mine:
                var op0: Dictionary = list[d["f"]]
                if int(d["kind"]) != Kind.RETREAT and float(d["losses"]) >= 0.3 and not bool(op0.get("stance", false)):
                        out.append(_pr("op_retreat", "f%d" % int(d["fid"]), Loc.t("Армия №%d: потери %d%% — отвести?") % [d["no"], roundi(float(d["losses"]) * 100.0)], 
                                KIND_ICONS[Kind.RETREAT], d["front"], int(d["fid"])))
        if not auto_orders_of(p.id):
                for d2: Dictionary in mine:
                        if int(d2["kind"]) == Kind.RETREAT:
                                continue
                        var top: Dictionary = gw.army.tac.ops.get(d2["f"], {})
                        if top.is_empty() or now - float(top["contact"]) > 8.0:
                                continue
                        var foe: Vector2 = top["foe"]
                        if not foe.is_finite():
                                continue
                        if cooldown_left(p.id, Order.ARTY) <= 0.0 and not _zone_near(p.id, Order.ARTY, foe, 150.0):
                                out.append(_pr("order_arty", "f%d" % int(d2["fid"]), Loc.t("Армия №%d: %s — АРТУДАР готов") % [d2["no"], Loc.src(list[d2["f"]]["state"])], ORDERS[Order.ARTY]["icon"], foe, int(d2["fid"])))
                        var cen: Vector2 = top.get("cen", d2["front"])
                        var sp: Vector2 = cen.lerp(foe, 0.45)
                        if int(top["phase"]) <= 2 and cooldown_left(p.id, Order.SMOKE) <= 0.0 and not _zone_near(p.id, Order.SMOKE, sp, 120.0):
                                out.append(_pr("order_smoke", "f%d" % int(d2["fid"]), Loc.t("Армия №%d под огнём — поставить дым?") % d2["no"], ORDERS[Order.SMOKE]["icon"], sp, int(d2["fid"])))
                if cooldown_left(p.id, Order.MEDIC) <= 0.0:
                        var hs: Vector2 = medic_spot(p.id)
                        if hs.is_finite():
                                out.append(_pr("order_ew", "m%d_%d" % [floori(hs.x / 400.0), floori(hs.y / 400.0)], Loc.t("Много раненых — ПОЛЕВОЙ ГОСПИТАЛЬ?"), ORDERS[Order.MEDIC]["icon"], hs, -1))
        var seen: Dictionary = {}
        for f: Facility in list:
                var op: Dictionary = list[f]
                if int(op["c"]) == p.id or int(op["kind"]) != Kind.ATTACK or not gw.army._hostile(p.id, int(op["c"])):
                        continue
                var fr: Vector2 = op["front"]
                if gw.vision != null and gw.vision.has_method("sees") and not gw.vision.sees(fr):
                        continue
                for cid in p.city_ids:
                        if seen.has(cid):
                                continue
                        var city: City = gw.cities[cid]
                        var cp: = Vector2(city.center * GameWorld.CELL)
                        var edge: float = float(city.radius * GameWorld.CELL)
                        if fr.distance_to(cp) >= edge + 600.0:
                                continue
                        seen[cid] = true
                        if _city_covered(p.id, cp, edge):
                                continue
                        var fid: int = _idle_barracks(p.id, cp, 4)
                        if fid < 0:
                                continue
                        var pd: Dictionary = _pr("op_defend", "c%d" % cid, Loc.t("Враг наступает на %s — ОБОРОНА?") % city.name, KIND_ICONS[Kind.DEFEND], 
                                cp + (fr - cp).normalized() * (edge + 30.0), fid)
                        pd["cid"] = cid
                        out.append(pd)
        var ib: int = _idle_barracks(p.id, Vector2.INF)
        if ib >= 0:
                var bf: Facility = _fac(ib)
                out.append(_pr("select_barracks", "f%d" % ib, Loc.t("Армия №%d готова — проведите стрелку от казарм") % bf.army_no, KIND_ICONS[Kind.ATTACK], bf.center_px(), ib))
        return out




func _city_covered(country_id: int, cp: Vector2, edge: float) -> bool:
        for f: Facility in list:
                var op: Dictionary = list[f]
                if int(op["c"]) == country_id and int(op["kind"]) != Kind.RETREAT and (op["target"] as Vector2).distance_to(cp) < edge + 600.0:
                        return true
        for b: Facility in gw.mil.facilities:
                if b.kind != Facility.Kind.BARRACKS or b.country_id != country_id or b.stance <= 0 or not gw.mil.alive(b):
                        continue
                if b.center_px().distance_to(cp) <= AutoCmd.DEF_REACH + edge and _army(b).size() >= AutoCmd.MIN_ARMY:
                        return true
        return false




func _idle_barracks(country_id: int, near: Vector2, min_n: int = -1) -> int:
        var best: int = -1
        var bd: float = INF
        var need: int = Army.BARRACKS_CAP - 3 if min_n < 0 else min_n
        for f: Facility in gw.mil.facilities:
                if f.kind != Facility.Kind.BARRACKS or f.country_id != country_id or list.has(f) or f.stance != 0 or not gw.mil.alive(f):
                        continue
                if _army(f).size() < need:
                        continue
                var d: float = f.center_px().distance_to(near) if near.is_finite() else float(f.army_no)
                if near.is_finite() and d > MAX_RANGE + 200.0:
                        continue
                if d < bd:
                        bd = d
                        best = f.id
        return best







func rejoin(u: Unit) -> bool:
        var f: Facility = u.home
        if f == null or not list.has(f) or not u.alive() or not u.ground() or _kept(u):
                return false
        var op: Dictionary = list[f]
        var dest: Vector2
        if int(op["kind"]) == Kind.RETREAT:
                dest = gw.army.barracks_out(f) + u.slot
                u.op_hold = false
                u.op_move = true
                u.target_city = -1
        else:
                var top: Dictionary = gw.army.tac.ops.get(f, {})
                if top.is_empty():
                        return false
                var slots: Dictionary = top.get("slots", {})
                if slots.has(u.id):
                        dest = slots[u.id]
                elif int(top["phase"]) == 5 and top.has("dir"):
                        dest = _line_slot(top, u)
                else:
                        dest = gw.army.safe_point(top.get("cen", op["front"]), u.slot)
                u.op_hold = true
                u.op_move = false
                u.team = u.id % 2
                u.target_city = int(top["city"])
        u.op_on = true
        u.target = null
        u.cover = 1.0
        u.path = gw.econ.nav_path(u.pos, dest) if u.pos.distance_to(dest) > 40.0 else PackedVector2Array([dest])
        if u.path.is_empty():
                u.path = PackedVector2Array([dest])
        u.path[u.path.size() - 1] = dest
        u.pi = 0
        u.state = Unit.State.MOVE
        return true




func _line_slot(top: Dictionary, u: Unit) -> Vector2:
        var goal: Vector2 = top["goal"]
        var dir: Vector2 = top["dir"]
        var side: = Vector2( - dir.y, dir.x)
        var slots: Dictionary = top.get("slots", {})
        var dest: Vector2
        if u.indirect():
                dest = goal - dir * 60.0 + side * float(slots.size() % 3 - 1) * 12.0
        else:
                var lo: float = 0.0
                var hi: float = 0.0
                for id: Variant in slots:
                        var rel: Vector2 = (slots[id] as Vector2) - goal
                        if rel.dot(dir) < -30.0:
                                continue
                        lo = minf(lo, rel.dot(side))
                        hi = maxf(hi, rel.dot(side))
                dest = goal + side * ((hi + 11.0) if hi <= - lo else (lo - 11.0))
        dest = gw.econ.land_point(dest)
        slots[u.id] = dest
        top["slots"] = slots
        return dest







func start_all(country_id: int, target: Vector2) -> Dictionary:
        var started: int = 0
        var reasons: Array = []
        _quiet = true
        for e: Dictionary in _all_plan(country_id, target):
                var f: Facility = e["f"]
                var why: String = String(e["why"])
                if why == "":
                        why = start(f, int(e["kind"]), e["to"])
                if why == "":
                        started += 1
                else:
                        reasons.append(Loc.t("Армия №%d: %s") % [f.army_no, why])
        _quiet = false
        var c: Country = gw.country_by_id(country_id)
        if c != null and c.is_player and started > 0:
                gw.say(c, Loc.mk("ДВИЖЕНИЕ: %d %s", [started, _armies_word(started)]))
                Sfx.play("ui_alert", Vector2.INF, -8.0)
        return {"started": started, "reasons": reasons}




func preview_all(country_id: int, target: Vector2) -> Dictionary:
        var key: String = "%d:%d:%d:%d" % [country_id, floori(target.x / 16.0), floori(target.y / 16.0), int(gw.game_time / 3.0)]
        if key == _all_key:
                return _all_prev
        _all_key = key
        var n: int = 0
        var ends: = PackedVector2Array()
        var reasons: Array = []
        var kinds: Dictionary = {}
        var mins: float = 0.0
        for e: Dictionary in _all_plan(country_id, target):
                var f: Facility = e["f"]
                var why: String = String(e["why"])
                var chk: Dictionary = {}
                if why == "":
                        chk = _check(f, int(e["kind"]), e["to"], Vector2.INF)
                        if not bool(chk["ok"]):
                                why = String(chk["why"])
                if why != "":
                        reasons.append("%s: %s" % [Loc.no(f.army_no), why])
                        continue
                n += 1
                ends.append(chk["target"])
                kinds[int(chk["kind"])] = true
                mins = maxf(mins, float(chk["len"]) / maxf(1.0, _speed(f)) / 60.0)
        var res: Dictionary = {"ok": n > 0, "n": n, "ends": ends, "reasons": reasons, "text": "", "colour": BAD_COL}
        if n == 0:
                res["text"] = String(reasons[0]) if not reasons.is_empty() else Loc.t("Нет армий")
        else:
                var k: int = int(kinds.keys()[0]) if kinds.size() == 1 else Kind.ATTACK
                var what: String = KIND_NAMES[k] if kinds.size() == 1 else Loc.t("РАЗНЫЕ ПРИКАЗЫ")
                res["text"] = Loc.t("ДВИЖЕНИЕ ВСЕХ: %d %s · %s · ~%d мин%s") % [n, _armies_word(n), what, maxi(1, roundi(mins)), (Loc.t(" · не пойдут: %d") % reasons.size()) if not reasons.is_empty() else ""]
                res["colour"] = KIND_COLS[k]
        _all_prev = res
        return res






func _all_plan(country_id: int, target: Vector2, only: Dictionary = {}, lazy: bool = false) -> Array:
        var out: Array = []
        if not target.is_finite():
                return out
        var ok: Array = []
        var from: Dictionary = {}
        var cen: = Vector2.ZERO
        for f: Facility in gw.mil.facilities:
                if f.kind != Facility.Kind.BARRACKS or f.country_id != country_id or not AGx.army_alive(gw, f):
                        continue
                if not only.is_empty() and not only.has(f.id):
                        continue
                var mem: Array[Unit] = _army(f)
                if mem.is_empty():
                        out.append({"f": f, "to": target, "kind": -1, "why": Loc.t("нет войск")})
                        continue
                from[f] = _centre(mem)
                cen += from[f]
                ok.append(f)
        if ok.is_empty():
                return out
        cen /= float(ok.size())
        var dir: Vector2 = (target - cen).normalized() if target.distance_to(cen) > 1.0 else Vector2.RIGHT
        var side: = Vector2( - dir.y, dir.x)
        ok.sort_custom( func(a: Facility, b: Facility) -> bool: return (from[a] as Vector2).dot(side) < (from[b] as Vector2).dot(side))
        var city: bool = _foreign_city(target, country_id) != null
        var o: int = _owner_at(target)
        var kind: int = _peace_kind(country_id, target, Kind.ATTACK if city or (o > 0 and o != country_id) else Kind.DEFEND)
        for i in ok.size():
                var f2: Facility = ok[i]
                var k2: int = Kind.RETREAT if target.distance_to(f2.center_px()) < 70.0 else kind
                var to: Vector2 = target
                if not city and ok.size() > 1 and k2 != Kind.RETREAT:
                        var off: float = (float(i) - float(ok.size() - 1) * 0.5) * ALL_SPREAD


                        var cands: Array = [target + side * off, target + side * off * 0.5]
                        if lazy:
                                out.append({"f": f2, "to": target, "kind": k2, "why": "", "cands": cands})
                                continue
                        to = _resolve_to(f2, k2, target, cands)
                out.append({"f": f2, "to": to, "kind": k2, "why": "", "cands": []})
        return out


func _dry(p: Vector2) -> bool:
        var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
        return gw.data.inside(c.x, c.y) and ( not Biome.is_water(gw.data.get_biome(c.x, c.y)) or gw.data.has_flag(c.x, c.y, WorldData.F_BRIDGE))


static func _armies_word(n: int) -> String:
        if n % 10 == 1 and n % 100 != 11:
                return Loc.t("армия")
        if n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 10 or n % 100 >= 20):
                return Loc.t("армии")
        return Loc.t("армий")




func _check(f: Facility, kind: int, target: Vector2, wp: Vector2) -> Dictionary:
        var out: Dictionary = {"ok": false, "why": "", "kind": kind, "city": null, "path": PackedVector2Array(), "len": 0.0, "target": target}
        if f == null or f.kind != Facility.Kind.BARRACKS or not AGx.army_alive(gw, f):
                out["why"] = Loc.t("Казармы разрушены")
                return out
        var c: Country = gw.country_by_id(f.country_id)
        if kind < 0:
                kind = suggest_kind(f, target)
                out["kind"] = kind
        if gw.rail != null and gw.rail.troops != null and gw.rail.troops.riding(f):
                out["why"] = Loc.t("Армия в поезде: ждите прибытия")
                return out
        if gw.naval != null and gw.naval.at_sea(f):
                out["why"] = Loc.t("Армия в море: ждите высадки")
                return out
        var mem: Array[Unit] = _army(f)
        if mem.is_empty():
                out["why"] = Loc.t("Нет войск: армия формируется")
                return out
        var cen: Vector2 = _centre(mem)
        if kind == Kind.RETREAT:
                target = gw.army.barracks_out(f)
                out["target"] = target
                if cen.distance_to(target) < 100.0:
                        out["why"] = Loc.t("Армия и так у казарм")
                        return out
        var cell: = Vector2i(floori(target.x / GameWorld.CELL), floori(target.y / GameWorld.CELL))
        if not gw.data.inside(cell.x, cell.y):
                out["why"] = Loc.t("За краем карты")
                return out
        if Biome.is_water(gw.data.get_biome(cell.x, cell.y)) and not gw.data.has_flag(cell.x, cell.y, WorldData.F_BRIDGE):
                out["why"] = Loc.t("Цель в воде")
                return out
        if kind != Kind.RETREAT and f.center_px().distance_to(target) > MAX_RANGE:
                out["why"] = Loc.t("Слишком далеко: до %.1f км от казарм") % (MAX_RANGE / 1000.0)
                return out
        var owner: int = gw.data.get_owner_id(cell.x, cell.y)
        if kind == Kind.ATTACK:
                var city: City = _foreign_city(target, f.country_id)
                out["city"] = city
                var foe: int = city.country_id if city != null else owner
                if foe > 0 and foe != f.country_id and c != null and c.is_player and not c.at_war.has(foe) and gw.diplo.may_cross(f.country_id, owner):
                        kind = Kind.DEFEND
                        out["kind"] = kind
                        out["city"] = null
                elif foe > 0 and foe != f.country_id:
                        if gw.diplo.allied(f.country_id, foe):
                                out["why"] = Loc.t("Это союзник")
                                return out
                        if not c.at_war.has(foe):
                                var fc: Country = gw.country_by_id(foe)
                                out["why"] = Loc.t("Нет войны с %s: сначала объявите") % (fc.name if fc != null else Loc.t("этой страной"))
                                return out
        if kind == Kind.DEFEND and owner > 0 and owner != f.country_id and not c.at_war.has(owner) and not gw.diplo.allied(f.country_id, owner)\
        and not gw.diplo.has_passage(f.country_id, owner) and not gw.diplo.ally.same(f.country_id, owner)\
        and not (gw.diplo.rq != null and gw.diplo.rq.land_ok(f.country_id, owner)):
                out["why"] = Loc.t("Чужая земля: оборона — на своей, ничейной, вражеской или с правом прохода")
                return out
        if sea_force and kind != Kind.RETREAT:

                var nvs: Dictionary = gw.naval.plan(f.country_id, cen, target, _speed(f), false, true) if gw.naval != null else {}
                if not bool(nvs.get("ok", false)):
                        var nws: String = String(nvs.get("why", ""))
                        out["why"] = Loc.t("Десант невозможен%s") % [((": " + nws.to_lower()) if nws != "" else "")]
                        return out
                out["naval"] = nvs
                out["sea_forced"] = true
                out["path"] = nvs["path"]
                out["len"] = float(nvs["land1"]) + float(nvs["sea_len"]) + float(nvs["land2"])
                if float(nvs["land1"]) + float(nvs["land2"]) > max_path():
                        out["why"] = Loc.t("Десант: слишком длинный путь по суше %.1f км") % ((float(nvs["land1"]) + float(nvs["land2"])) / 1000.0)
                        return out
                out["ok"] = true
                return out
        var path: PackedVector2Array = gw.army.tac.route(cen, target, wp, true)
        if gw.econ.nav_last_pending:
                out["why"] = PENDING
                out["pending"] = true
                out["path"] = path
                if not wp.is_finite() and gw.rail != null and gw.rail.troops != null:
                        out["rail_hint"] = gw.rail.troops.plan(f, cen, target, kind, _speed(f), cen.distance_to(target) * 1.3)
                return out
        var land_ok: bool = not path.is_empty() and gw.econ.nav_last_ok
        var nv0: Dictionary = {}
        if land_ok and gw.naval != null and kind != Kind.RETREAT and not wp.is_finite():

                var ln0: float = _path_len(path) + cen.distance_to(path[0])
                var st0: float = cen.distance_to(target)
                if ln0 > max_path() or (ln0 > st0 * DETOUR_K and ln0 - st0 > DETOUR_MIN):
                        var nvd: Dictionary = gw.naval.plan(f.country_id, cen, target, _speed(f), false, true)
                        if bool(nvd.get("ok", false)) and float(nvd["eta"]) <= ln0 / maxf(1.0, _speed(f)) * SEA_GAIN:
                                nv0 = nvd
                                out["detour"] = ln0
        if not land_ok or not nv0.is_empty():

                var nv: Dictionary = nv0 if not nv0.is_empty() else (gw.naval.plan(f.country_id, cen, target, _speed(f)) if gw.naval != null else {})
                if not bool(nv.get("ok", false)):
                        out["path"] = path
                        var nw: String = String(nv.get("why", ""))
                        out["why"] = Loc.t("Нет пути по суше") + ((Loc.t(", морем: %s") % [nw.to_lower()]) if nw != "" and not bool(nv.get("land", false)) else "")
                        return out
                out["naval"] = nv
                out["path"] = nv["path"]
                out["len"] = float(nv["land1"]) + float(nv["sea_len"]) + float(nv["land2"])
                if float(nv["land1"]) + float(nv["land2"]) > max_path():
                        out["why"] = Loc.t("Слишком длинный путь: %.1f км по суше") % ((float(nv["land1"]) + float(nv["land2"])) / 1000.0)
                        return out
                out["ok"] = true
                return out
        var ln: float = _path_len(path) + cen.distance_to(path[0])
        out["path"] = path
        out["len"] = ln



        var blk: int = gw.diplo.path_block(f.country_id, AutoCmd.FrontPlan._past_closed(gw, f.country_id, path)) if kind != Kind.RETREAT else 0
        if kind == Kind.RETREAT and AutoCmd.FrontPlan.closed_path(gw, f.country_id, path):

                var lr: Dictionary = AutoCmd.FrontPlan.legal_route(gw, f.country_id, cen, target)
                if bool(lr.get("ok", false)):
                        out["home_chain"] = lr["chain"]
                else:
                        blk = gw.diplo.path_block(f.country_id, AutoCmd.FrontPlan._past_closed(gw, f.country_id, path))
        if blk > 0 and kind != Kind.RETREAT and gw.army.tac.chain.is_empty():



                var lr2: Dictionary = AutoCmd.FrontPlan.legal_route(gw, f.country_id, cen, target)
                if bool(lr2.get("busy", false)):
                        out["why"] = PENDING
                        out["pending"] = true
                        return out
                var ch2: PackedVector2Array = lr2.get("chain", PackedVector2Array())
                if bool(lr2.get("ok", false)) and not ch2.is_empty():
                        var tac2 = gw.army.tac
                        tac2.chain = ch2
                        var p2: PackedVector2Array = tac2.route(cen, target)
                        tac2.chain = PackedVector2Array()
                        if gw.econ.nav_last_ok and p2.size() >= 2:
                                path = p2
                                ln = _path_len(path) + cen.distance_to(path[0])
                                out["path"] = path
                                out["len"] = ln
                                out["pass_chain"] = ch2
                                blk = 0
        if blk > 0:
                var bc: Country = gw.country_by_id(blk)
                out["why"] = Loc.t("Путь через %s: нужно право прохода") % (bc.name if bc != null else Loc.t("чужую страну"))
                out["blocker"] = blk
                return out
        if ln > max_path():
                out["why"] = Loc.t("Слишком длинный путь: %.1f км") % (ln / 1000.0)
                return out
        if not wp.is_finite() and gw.rail != null and gw.rail.troops != null:

                var rpl: Dictionary = gw.rail.troops.plan(f, cen, target, kind, _speed(f), ln)
                if bool(rpl.get("ok", false)):
                        out["rail"] = rpl
                        out["path"] = rpl["path"]
                elif bool(rpl.get("denied", false)):
                        out["rail_denied"] = rpl
        out["ok"] = true
        return out




static func max_path() -> float:
        return maxf(MAX_PATH, MAX_RANGE * 1.75)



func _army(f: Facility, all: bool = false) -> Array[Unit]:
        var out: Array[Unit] = []
        for u: Unit in gw.army.units:
                if u.home == f and u.alive() and u.ground() and (all or (u.post == null and u.reinf == 0 and not _kept(u))):
                        out.append(u)
        return out



func strength_units(f: Facility) -> Array[Unit]:
        var out: Array[Unit] = _army(f)
        for u: Unit in gw.army.units:
                if u.home == f and u.reinf != 0 and u.alive() and u.ground():
                        out.append(u)
        return out




func _kept(u: Unit) -> bool:
        if gw.hold == null or not gw.hold.keep(u):
                return false
        if auto_ctx:
                return true
        var c: Country = gw.country_by_id(u.country_id)
        return c != null and not c.is_player


func _centre(mem: Array[Unit]) -> Vector2:
        var cen: = Vector2.ZERO
        for u: Unit in mem:
                cen += u.pos
        cen /= float(maxi(1, mem.size()))
        if mem.size() < 2 or gw.army == null or (gw.army.ground_at(cen) == 1 and (gw.diplo == null or gw.diplo.may_cross(mem[0].country_id, _owner_at(cen)))):
                return cen




        # O(n) вместо O(n²): якорь — юнит, ближайший к центроиду, кластер — все
        # юниты в радиусе CLUSTER_R от якоря. Результат практически идентичен
        # выбору зоны максимальной плотности, но без квадратичного перебора.
        var best: int = 0
        var bd: float = INF
        for i in mem.size():
                var di: float = mem[i].pos.distance_squared_to(cen)
                if di < bd:
                        bd = di
                        best = i
        var anchor: Vector2 = mem[best].pos
        var c2: = Vector2.ZERO
        var k: int = 0
        for u2: Unit in mem:
                if u2.pos.distance_squared_to(anchor) < CLUSTER_R * CLUSTER_R:
                        c2 += u2.pos
                        k += 1
        c2 /= float(maxi(1, k))
        return c2 if gw.army.ground_at(c2) == 1 else anchor


const CLUSTER_R: float = 160.0


func _from(f: Facility) -> Vector2:
        var mem: Array[Unit] = _army(f)
        return _centre(mem) if not mem.is_empty() else gw.army.barracks_out(f)


func _speed(f: Facility) -> float:
        var s: float = INF
        for u: Unit in _army(f):
                s = minf(s, float(Army.SPEC[u.type]["speed"]))
        return s if s < INF else 8.0



func _foreign_city(p: Vector2, country_id: int) -> City:
        var best: City = null
        var bd: float = INF
        for city: City in gw.cities:
                if city.country_id == country_id:
                        continue
                var d: float = Vector2(city.center * GameWorld.CELL).distance_to(p)
                if d <= float(city.radius * GameWorld.CELL) + CITY_PAD and d < bd:
                        bd = d
                        best = city
        return best


func _owner_at(p: Vector2) -> int:
        var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
        if gw.data == null or not gw.data.inside(c.x, c.y):
                return -1
        return gw.data.get_owner_id(c.x, c.y)





const LOC_STATE_KIND: Dictionary = {"у казарм: лечение %d%%": "refill", "штурм: {city}": "assault", "бой на рубеже": "fight_line", 
        "бой у {city:gen}": "fight", "бой {place}": "fight", "огонь по {city:dat}": "fire", "у {city:gen}: ждём огня": "wait_fire", 
        "сбор перед штурмом": "gather", "закрепились в {city:loc}": "dug", "закрепились": "dug", "держим рубеж": "hold", 
        "выдвижение": "march", "выдвижение к {city:dat}": "march", "выдвижение к рубежу": "march", "перебежками к {city:dat}": "march", 
        "потери %d%%: %s": "losses", "потери %d%%, отход": "losses"}


static func state_kind(st: Variant) -> String:
        if Loc.is_msg(st):
                return String(LOC_STATE_KIND.get(Loc.id(st), ""))
        var s: String = String(st)
        for e: Array in [["у казарм", "refill"], ["штурм", "assault"], ["бой на рубеже", "fight_line"], ["бой", "fight"], ["огонь", "fire"]]:
                if s.begins_with(String(e[0])):
                        return String(e[1])
        if s.find("ждём огня") >= 0:
                return "wait_fire"
        for e2: Array in [["сбор", "gather"], ["закреп", "dug"], ["держим", "hold"], ["выдвиж", "march"], ["перебеж", "march"], ["потери", "losses"]]:
                if s.begins_with(String(e2[0])):
                        return String(e2[1])
        return ""



static func state_pct(st: Variant) -> int:
        if Loc.is_msg(st):
                var a: Variant = (st as Array)[1] if (st as Array).size() > 1 else []
                return int((a as Array)[0]) if a is Array and not (a as Array).is_empty() and state_kind(st) in ["refill", "losses"] else -1
        var s: String = String(st)
        var pct: int = s.find("%")
        if pct <= 0:
                return -1
        var sp: int = s.rfind(" ", pct)
        return int(s.substr(sp + 1, pct - sp - 1)) if sp >= 0 else -1



func _where_m(op: Dictionary) -> Array:
        if int(op["kind"]) == Kind.RETREAT:
                return Loc.mk("к казармам")
        if int(op["city"]) >= 0:
                return Loc.mk("на {city}", {"city": gw.cities[int(op["city"])].name})
        var best: City = _near_city(op["target"])
        if best == null:
                return Loc.mk("в поле")
        return Loc.mk("у {city:gen}", {"city": best.name})


func _where(op: Dictionary) -> String:
        var kind: int = int(op["kind"])
        if kind == Kind.RETREAT:
                return Loc.t("к казармам")
        if int(op["city"]) >= 0:
                return Loc.t("на %s") % [gw.cities[int(op["city"])].name]
        var best: City = _near_city(op["target"])
        if best == null:
                return Loc.t("в поле")
        return Loc.t("у %s") % [BattleWatch.genitive(best.name)]


func _near_city(tp: Vector2) -> City:
        var best: City = null
        var bd: float = 700.0
        for city: City in gw.cities:
                var d: float = Vector2(city.center * GameWorld.CELL).distance_to(tp) - float(city.radius * GameWorld.CELL)
                if d < bd:
                        bd = d
                        best = city
        return best



static func _dat(n: String) -> String:
        for e: Array in [["ичи", "ичам"], ["ное", "ному"], ["ополь", "ополю"], ["оград", "ограду"], ["ань", "ани"], ["ец", "цу"], ["ка", "ке"], ["ск", "ску"], ["ов", "ову"], ["ок", "ку"]]:
                if n.ends_with(e[0]):
                        return n.substr(0, n.length() - String(e[0]).length()) + String(e[1])
        return n



func _near_own(country_id: int, p: Vector2, r: float, land: bool) -> bool:
        if land and _owner_at(p) == country_id:
                return true
        for u: Unit in gw.army.units:
                if u.country_id == country_id and u.alive() and u.ground() and u.pos.distance_squared_to(p) <= r * r:
                        return true
        if land:
                for f: Facility in gw.mil.facilities:
                        if f.country_id == country_id and f.parent == null and f.center_px().distance_squared_to(p) <= r * r:
                                return true
        return false



func arty_anchor(country_id: int, p: Vector2) -> Vector2:
        var best: = Vector2.INF
        var bd: float = INF
        for u: Unit in gw.army.units:
                if u.country_id == country_id and u.alive() and u.ground():
                        var d: float = u.pos.distance_squared_to(p)
                        if d < bd:
                                bd = d
                                best = u.pos
        return best



func _gun_for(country_id: int, p: Vector2) -> Vector2:
        var best: = Vector2.INF
        var bd: float = INF
        for u: Unit in gw.army.units:
                if u.alive() and u.indirect() and u.country_id == country_id:
                        var d: float = u.pos.distance_to(p)
                        if d <= float(Army.SPEC[u.type]["range"]) and d >= float(Army.SPEC[u.type].get("min", 0.0)) and d < bd:
                                bd = d
                                best = u.pos
        return best



func _visible(p: Vector2, c: int) -> bool:
        if gw.player == null or c == gw.player.id:
                return true
        if gw.vision != null and gw.vision.has_method("shows"):
                return gw.vision.shows(c, p)
        return true


func _fxn(n: String, fallback: String) -> String:
        return n if gw.fx.atlas_of.has(n) else fallback


func _cost_text(cost: Dictionary) -> String:
        var names: Dictionary = {"money": "", "metal": Loc.t("металл "), "precious": Loc.t("драгмет. "), "titanium": Loc.t("титан "), "oil": Loc.t("нефть "), "food": Loc.t("еда "), "uranium": Loc.t("уран ")}
        var out: PackedStringArray = PackedStringArray()
        for k: String in cost:
                out.append("%s%d" % [names.get(k, k + " "), int(cost[k])])
        return " + ".join(out)


func _fac(id: int) -> Facility:
        for f: Facility in gw.mil.facilities:
                if f.id == id:
                        return f
        return null


static func _path_len(path: PackedVector2Array) -> float:
        var s: float = 0.0
        for i in range(1, path.size()):
                s += path[i - 1].distance_to(path[i])
        return s



static func _simplify(path: PackedVector2Array) -> PackedVector2Array:
        if path.size() <= 2:
                return path
        var out: = PackedVector2Array([path[0]])
        for i in range(1, path.size() - 1):
                if path[i].distance_to(out[out.size() - 1]) >= 20.0:
                        out.append(path[i])
        out.append(path[path.size() - 1])
        return out






func _hold_flags() -> Dictionary:
        var out: Dictionary = {}
        for k: Variant in auto_next:
                var ks: String = String(k)
                if ks.length() > 1 and (ks[0] == "h" or ks[0] == "k") and ks.substr(1).is_valid_int():
                        out[ks] = float(auto_next[k])
        return out


func save_state() -> Dictionary:
        var ops: Array = []
        for f: Facility in list:
                var op: Dictionary = list[f]
                var d: Dictionary = {}
                for k: String in op:
                        if k != "f":
                                d[k] = op[k]
                ops.append(d)
        var zs: Array = []
        for z: Dictionary in zones:
                var zz: Dictionary = z.duplicate()
                zz.erase("fx")
                zs.append(zz)
        return {"ops": ops, "zones": zs, "ready_at": ready_at.duplicate(), "zid": _zid, "auto_orders": auto_orders.duplicate(), 
                "prompt": {"t": _prompt_t, "shown": _prompted.duplicate(), "sup": _prompt_sup.duplicate(), "acc": _prompt_acc.duplicate(), "last": _prompt_last, 
                "warned": _warned.duplicate(), "urgent": _urgent.duplicate(true)}, "oq": _oq.duplicate(true), "hold": _hold_flags(), "wd331": wd_save()}



func naval_loaded() -> void :
        for f: Facility in _naval_wait:
                if gw.naval != null and gw.naval.busy(f):
                        var op: Dictionary = (_naval_wait[f] as Dictionary).duplicate()
                        op["f"] = f
                        list[f] = op
        _naval_wait.clear()







func load_state(d: Dictionary) -> void :
        list.clear()
        zones.clear()
        _oq = []
        wd_load(d.get("wd331", {}))
        for e: Variant in d.get("oq", []):
                if e is Dictionary and (e as Dictionary).has("fid"):
                        _oq.append((e as Dictionary).duplicate(true))
        ready_at = (d.get("ready_at", {}) as Dictionary).duplicate()
        _zid = int(d.get("zid", 1))
        auto_orders = {}
        auto_next = {}
        var hd: Dictionary = d.get("hold", {})
        for hk: Variant in hd:
                if String(hk).begins_with("h") or String(hk).begins_with("k"):
                        auto_next[String(hk)] = float(hd[hk])
        var ao: Dictionary = d.get("auto_orders", {})
        for k: Variant in ao:
                auto_orders[int(k)] = bool(ao[k])
        var pd: Dictionary = d.get("prompt", {})
        _prompt_t = float(pd.get("t", -99.0))
        _prompted = (pd.get("shown", {}) as Dictionary).duplicate()
        _prompt_sup = (pd.get("sup", {}) as Dictionary).duplicate()
        _prompt_acc = (pd.get("acc", {}) as Dictionary).duplicate()
        _prompt_last = String(pd.get("last", ""))
        _warned = (pd.get("warned", {}) as Dictionary).duplicate()
        _urgent = (pd.get("urgent", []) as Array).duplicate(true)
        _str_cache.clear()
        _prompt_scan_t = -99.0
        for z: Dictionary in d.get("zones", []):
                var zz: Dictionary = z.duplicate()
                zz["fx"] = []
                if int(zz["k"]) == Order.SMOKE:
                        _smoke_fx(zz)
                zones.append(zz)
        for o: Dictionary in d.get("ops", []):
                var f: Facility = _fac(int(o.get("fid", -1)))
                if f == null or not gw.mil.alive(f):
                        continue
                var kind: int = int(o["kind"])
                var city: City = gw.cities[int(o["city"])] if int(o.get("city", -1)) >= 0 and int(o["city"]) < gw.cities.size() else null
                var mem: Array[Unit] = _army(f)
                if gw.rail != null and gw.rail.troops != null and gw.rail.troops.busy(f):
                        var opr: Dictionary = o.duplicate()
                        opr["f"] = f
                        list[f] = opr
                        continue
                if mem.is_empty():
                        _naval_wait[f] = o
                        continue
                if kind == Kind.ATTACK and gw.army.tac.ops.get(f) == null:
                        if city != null:
                                gw.army.tac.start(f, mem, city)
                        else:
                                gw.army.tac.start_area(f, mem, o["target"], Vector2.INF, false)
                elif kind == Kind.DEFEND and gw.army.tac.ops.get(f) == null:
                        var lwp: Variant = o.get("wp", Vector2.INF)
                        gw.army.tac.start_area(f, mem, o["target"], lwp if lwp is Vector2 and (lwp as Vector2).is_finite() else Vector2.INF, true)
                var op: Dictionary = o.duplicate()
                op["f"] = f
                list[f] = op
                if kind == Kind.RETREAT:
                        _send_home(op)
