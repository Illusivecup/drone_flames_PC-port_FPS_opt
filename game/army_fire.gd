extends RefCounted








const SPOT_R: float = 120.0
const RECON_R: float = 170.0
const TRENCH_SPOT_R: float = 54.0
const CITY_SPOT_R: float = 90.0
const DUG_IN_PICK: float = 0.6
const REQ_LIFE: float = 14.0
const RECON_CD: float = 30.0
const RECON_SPEED: float = 30.0
const RECON_IDLE: float = 8.0

const MIL_KINDS: Array[int] = [Facility.Kind.BARRACKS, Facility.Kind.DUGOUT, Facility.Kind.TEL, Facility.Kind.AD_SPAAG, Facility.Kind.AD_SAM, 
        Facility.Kind.AD_PATRIOT, Facility.Kind.AD_INT, Facility.Kind.AD_RADAR, Facility.Kind.AD_EW, Facility.Kind.AD_MFG, Facility.Kind.AIRFIELD, Facility.Kind.DRONE_PORT]
const KIND_MORTAR: int = 0
const KIND_ARTY: int = 1
const KIND_ROCKET: int = 2

var army: Army
var gw: GameWorld
var spotted: Dictionary = {}
var seen: Dictionary = {}
var requests: Array = []
var shells: Array = []
var recon: Array[Unit] = []
var flares: Array = []
var support_off: Dictionary = {}
var _spot_t: float = 0.0
var _fire_t: float = 0.0
var _sec_t: float = 0.0
var _recon_t: Dictionary = {}
var _parked: Dictionary = {}
var _shots: Array = []
var _ripple: Array[Unit] = []
var _shake_t: float = 0.0
var _decal_dirty: bool = false
var _supporting: Dictionary = {}
var _fired: Dictionary = {}
var _rid: int = 1
var _news_t: Dictionary = {}
var rng_state: int = 0
# Плоские данные spotted для нативного _pick (собираются в _aim_all раз за вызов):
# 7 double на запись [x, y, is_unit, vehicle, mortar_soft, entrenched, recon]
# и диапазоны записей по странам; запросы огня пересобираются на каждый pick
# (живые позиции и served на момент вызова — как в эталоне).
var _aim_spot_flat := PackedFloat64Array()
var _aim_spot_range: Dictionary = {}
var _aim_req_xy := PackedFloat64Array()
var _aim_req_c := PackedInt32Array()
var _aim_req_served := PackedFloat64Array()


func _init(a: Army) -> void :
        army = a
        gw = a.gw





func rf() -> float:
        return float(_u32() & 16777215) / 16777216.0


func rfr(a: float, b: float) -> float:
        return a + (b - a) * rf()


func ri(n: int) -> int:
        return _u32() % n if n > 0 else 0


func _u32() -> int:
        var x: int = rng_state
        if x == 0:
                x = Hash32.mix((gw.data.world_seed if gw.data != null else 1) ^ 5369127) & Hash32.M32
                if x == 0:
                        x = 1831565813
        x ^= (x << 13) & Hash32.M32
        x ^= x >> 17
        x ^= (x << 5) & Hash32.M32
        rng_state = x & Hash32.M32
        return rng_state


func busy() -> bool:
        return not shells.is_empty() or not recon.is_empty() or not flares.is_empty() or not requests.is_empty()


func _pt(nm: String, t0: int) -> void :
        var d: float = float(Time.get_ticks_usec() - t0) / 1000.0
        if d > float(gw.perf_sys.get(nm, 0.0)):
                gw.perf_sys[nm] = d


func update(dt: float) -> void :
        var now: float = gw.game_time
        var _u0: int = Time.get_ticks_usec()
        _spot_t -= dt
        if _spot_t <= 0.0:
                _spot_t = 1.0
                _spot()
        _pt("fire:_spot", _u0)
        _u0 = Time.get_ticks_usec()
        _fire_t -= dt
        if _fire_t <= 0.0:
                _fire_t = 0.5
                _aim_all()
        _pt("fire:_aim_all", _u0)
        _u0 = Time.get_ticks_usec()
        _sec_t -= dt
        if _sec_t <= 0.0:
                _sec_t = 1.0
                _recon_upkeep()
                _cannonade()
                for k in range(requests.size() - 1, -1, -1):
                        if now - float(requests[k]["t"]) > REQ_LIFE:
                                requests.remove_at(k)
                if _decal_dirty:
                        _decal_dirty = false
                        gw.ground.queue_redraw()
        _pt("fire:_sec", _u0)
        _u0 = Time.get_ticks_usec()
        _ripples(dt)
        _update_shells(dt)
        _update_recon(dt)
        for k2 in range(flares.size() - 1, -1, -1):
                if now - float(flares[k2]["t0"]) > float(flares[k2]["life"]):
                        flares.remove_at(k2)
        _pt("fire:_proj", _u0)




func _spot() -> void :
        spotted.clear()
        seen.clear()
        var eyes: Dictionary = _spot_eyes()
        if OS.get_environment("DF_WD_VERIFY") == "1" and army._nat != null:
                # Теневая сверка v4 (глаза в Rust, spot_all_v2) против GDScript-эталона:
                # нативный результат сохраняется, активным остаётся эталон.
                var ok: bool = _spot_native()
                var res_n: Dictionary = spotted.duplicate(true)
                spotted.clear()
                seen.clear()
                _spot_gd(eyes)
                var mis: int = _spot_verify(res_n)
                if mis == 0:
                        print("[SPOT-VERIFY] ok: cids=", res_n.size())
                return
        # Нативный путь (Rust): глаза строит df_native из снапшота (v4).
        if army._nat != null and _spot_native():
                return
        _spot_gd(eyes)


# GDScript-эталон _spot (parity + отказ без натива) — тело прежней _spot.
func _spot_gd(eyes: Dictionary) -> void :
        for cid: int in eyes:
                var ey: Array = eyes[cid]
                var hostility: Dictionary = {}
                var box: = Rect2((ey[0][0] as Vector2), Vector2.ZERO)
                for e: Array in ey:
                        box = box.expand(e[0])
                box = box.grow(RECON_R)
                var list: Array = []
                for o: Unit in army.units:
                        if not o.alive() or o.air() or o.country_id == cid or not box.has_point(o.pos):
                                continue
                        if not hostility.has(o.country_id):
                                hostility[o.country_id] = army._hostile(cid, o.country_id)
                        if not hostility[o.country_id]:
                                continue
                        if army.in_smoke(o.pos):
                                continue
                        var hid: bool = o.entrenched
                        for e: Array in ey:
                                if o.pos.distance_squared_to(e[0]) <= (minf(float(e[1]), TRENCH_SPOT_R * TRENCH_SPOT_R) if hid and not bool(e[2]) else float(e[1])):
                                        list.append([o.pos, o, bool(e[2])])
                                        break
                if gw.naval != null:
                        list.append_array(gw.naval.spotted_for(cid, ey))
                for f: Facility in gw.mil.facilities:
                        if f.parent != null or not MIL_KINDS.has(f.kind) or f.moving:
                                continue
                        if not hostility.has(f.country_id):
                                hostility[f.country_id] = army._hostile(cid, f.country_id)
                        if not hostility[f.country_id]:
                                continue
                        var fc: Vector2 = f.center_px()
                        var ext: float = float(maxi(f.size.x, f.size.y)) * 2.0 + (float(f.cells.size()) * 2.0 if f.is_line() else 0.0)
                        if not box.grow(ext).has_point(fc) or not gw.mil.alive(f):
                                continue
                        var hid2: bool = Army.is_trench(f.kind)
                        for e: Array in ey:
                                var tp: Vector2 = gw.mil.line_point(f, e[0]) if f.is_line() else fc
                                if tp.distance_squared_to(e[0]) <= (minf(float(e[1]), TRENCH_SPOT_R * TRENCH_SPOT_R) if hid2 and not bool(e[2]) else float(e[1])):
                                        list.append([tp, f, bool(e[2])])
                                        break
                        if list.size() > 60:
                                break
                spotted[cid] = list
                var sd: Dictionary = {}
                for e3: Array in list:
                        sd[e3[1]] = true
                seen[cid] = sd


# Глаза (кто смотрит): свои юниты + разведчики + города. Общая для нативного
# и GDScript-путей _spot, а также для parity-бенчмарка dev/bench_nat2.gd.
func _spot_eyes() -> Dictionary:
        var eyes: Dictionary = {}
        for u: Unit in army.units:
                if u.alive() and u.ground():
                        if not eyes.has(u.country_id):
                                eyes[u.country_id] = []
                        var r: float = SPOT_R * (1.3 if u.entrenched or u.dug else 1.0)
                        eyes[u.country_id].append([u.pos, r * r, false])
        for d: Unit in recon:
                if d.alive() and d.jam_t <= 0.0:
                        if not eyes.has(d.country_id):
                                eyes[d.country_id] = []
                        eyes[d.country_id].append([d.pos, RECON_R * RECON_R, true])
        for cc: Country in gw.countries:
                if cc.eliminated or cc.at_war.is_empty():
                        continue
                for city_id in cc.city_ids:
                        var city: City = gw.cities[city_id]
                        if not eyes.has(cc.id):
                                eyes[cc.id] = []
                        var cr: float = float(city.radius * GameWorld.CELL) + CITY_SPOT_R
                        eyes[cc.id].append([Vector2(city.center * GameWorld.CELL), cr * cr, false])
        return eyes


# Нативный _spot v4 (df_native.spot_all_v2): глаза (юниты/разведчики/города)
# строит Rust из снапшота, GDScript передаёт только разведчиков, города,
# катера и префильтрованные здания. Возвращает false, если нужен
# GDScript-путь (hm == -1 — страна вне 0..63).
func _spot_native() -> bool:
        # Принудительная свежесть снапшота: глаза строятся в Rust из позиций
        # текущего тика — 1:1 с GDScript-эталоном (units move между _build_grid
        # и _spot при нескольких sim-шагах в кадре).
        army._nat_sync(true)
        # Порядок стран: первое появление наземного юнита, затем страны «только
        # города» (в порядке gw.countries) — 1:1 с порядком ключей _spot_eyes.
        var cids := PackedInt32Array()
        var gseen := {}
        for u: Unit in army.units:
                if u.alive() and u.ground() and not gseen.has(u.country_id):
                        gseen[u.country_id] = true
                        cids.append(u.country_id)
        for cc: Country in gw.countries:
                if cc.eliminated or cc.at_war.is_empty() or gseen.has(cc.id):
                        continue
                gseen[cc.id] = true
                cids.append(cc.id)
        var hms := PackedInt64Array()
        var counts := PackedInt32Array()
        var data := PackedFloat64Array()
        var boat_meta: Array = []
        for cid: int in cids:
                var hm: int = army._hmask(cid)
                if hm == -1:
                        return false
                hms.append(hm)
                # разведчики: живые, не заглушенные (порядок fire.recon)
                var nr: int = 0
                for d: Unit in recon:
                        if d.alive() and d.jam_t <= 0.0 and d.country_id == cid:
                                data.append(d.pos.x)
                                data.append(d.pos.y)
                                nr += 1
                # города своей страны (в порядке cc.city_ids)
                var nc: int = 0
                for cc2: Country in gw.countries:
                        if cc2.id != cid or cc2.eliminated or cc2.at_war.is_empty():
                                continue
                        for city_id in cc2.city_ids:
                                var city: City = gw.cities[city_id]
                                var cr: float = float(city.radius * GameWorld.CELL) + CITY_SPOT_R
                                var cp: Vector2 = Vector2(city.center * GameWorld.CELL)
                                data.append(cp.x)
                                data.append(cp.y)
                                data.append(cr * cr)
                                nc += 1
                # катера naval-высадок: SAIL/BOARD, живые, враждебные (порядок landings)
                var nb: int = 0
                var bm: Array = []
                if gw.naval != null:
                        for L: Dictionary in gw.naval.landings:
                                if int(L["stage"]) != Naval.Stage.SAIL and int(L["stage"]) != Naval.Stage.BOARD:
                                        continue
                                if not army._hostile(cid, int(L["c"])):
                                        continue
                                for b: Dictionary in L["boats"]:
                                        if bool(b["sunk"]) or bool(b["done"]):
                                                continue
                                        var p: Vector2 = b["pos"]
                                        data.append(p.x)
                                        data.append(p.y)
                                        bm.append([p, float(b["heading"]), float(b["delay"])])
                                        nb += 1
                counts.append(nr)
                counts.append(nc)
                counts.append(nb)
                boat_meta.append(bm)
        # Здания: префильтр MIL_KINDS/parent/moving/alive в GDScript (порядок
        # gw.mil.facilities сохраняется), матчинг с глазами — Rust.
        var fac_ids := PackedInt32Array()
        var fac_cs := PackedInt32Array()
        var fac_xy := PackedFloat64Array()
        var fac_ext := PackedFloat64Array()
        var fac_flags := PackedInt32Array()
        var line_off := PackedInt32Array()
        var line_xy := PackedFloat64Array()
        var fac_objs: Array = []
        line_off.append(0)
        for f: Facility in gw.mil.facilities:
                if f.parent != null or not MIL_KINDS.has(f.kind) or f.moving or not gw.mil.alive(f):
                        continue
                fac_objs.append(f)
                fac_ids.append(f.id)
                fac_cs.append(f.country_id)
                var fc: Vector2 = f.center_px()
                fac_xy.append(fc.x)
                fac_xy.append(fc.y)
                fac_ext.append(float(maxi(f.size.x, f.size.y)) * 2.0 + (float(f.cells.size()) * 2.0 if f.is_line() else 0.0))
                fac_flags.append((1 if Army.is_trench(f.kind) else 0) | (2 if f.is_line() else 0))
                if f.is_line():
                        for c: Vector2i in f.cells:
                                var lp: = Vector2(c * GameWorld.CELL) + Vector2(2, 2)
                                line_xy.append(lp.x)
                                line_xy.append(lp.y)
                line_off.append(line_xy.size() / 2)
        # Единый f64-ответ: ряды (int-значения как f64) до маркера -1.0,
        # затем хвост tps (2 double на здание).
        var res: PackedFloat64Array = army._nat.spot_all_v2(cids, hms, data, counts, fac_ids, fac_cs, fac_xy, fac_ext, fac_flags, line_off, line_xy)
        var mark: int = -1
        for i in res.size():
                if res[i] == -1.0:
                        mark = i
                        break
        var tps_at: int = mark + 1
        # Декодирование: [на страну: n_eu, n_er, n_ec, n_u, (uid, ei)*,
        # n_b, (bi, ei)*, n_f, (fi, ei)*] + хвост tps (2 double на здание).
        var pos_i: int = 0
        var tp_i: int = 0
        for ci in cids.size():
                var cid: int = cids[ci]
                var n_eu: int = int(res[pos_i])
                var n_er: int = int(res[pos_i + 1])
                var n_ec: int = int(res[pos_i + 2])
                var n_u: int = int(res[pos_i + 3])
                pos_i += 4
                var rows_end: int = mark
                var list: Array = []
                var sd: Dictionary = {}
                for k in n_u:
                        var u: Unit = army._nat_u.get(int(res[pos_i]))
                        var ei: int = int(res[pos_i + 1])
                        pos_i += 2
                        if u != null and u.alive():
                                list.append([u.pos, u, ei >= n_eu and ei < n_eu + n_er])
                                sd[u] = true
                var n_b: int = int(res[pos_i])
                pos_i += 1
                var bm: Array = boat_meta[ci]
                var tp_at: int = tps_at + tp_i
                for k2 in n_b:
                        var bi: int = int(res[pos_i])
                        var ei2: int = int(res[pos_i + 1])
                        pos_i += 2
                        var meta: Array = bm[bi]
                        var lead: Vector2 = (meta[0] as Vector2) + Vector2.from_angle(meta[1]) * Naval.BOAT_SPEED * (0.0 if meta[2] > 0.0 else 2.0)
                        list.append([lead, null, ei2 >= n_eu and ei2 < n_eu + n_er])
                        sd[null] = true
                var n_f: int = int(res[pos_i])
                pos_i += 1
                for k3 in n_f:
                        var f: Facility = fac_objs[int(res[pos_i])]
                        var ei3: int = int(res[pos_i + 1])
                        pos_i += 2
                        var tp := Vector2(res[tp_at], res[tp_at + 1])
                        tp_i += 2
                        list.append([tp, f, ei3 >= n_eu and ei3 < n_eu + n_er])
                        sd[f] = true
                spotted[cid] = list
                seen[cid] = sd
        return true


# Теневая сверка spot_all_v2 против GDScript-эталона: длины, объекты,
# recon-флаги и точки. Возвращает число расхождений (печатает первые 6).
func _spot_verify(nat_sp: Dictionary) -> int:
        var mis: int = 0
        for cid: int in nat_sp:
                var a: Array = nat_sp[cid]
                var b: Array = spotted.get(cid, [])
                if a.size() != b.size():
                        mis += 1
                        if mis <= 6:
                                print("  cid=", cid, " size ", a.size(), "/", b.size())
                        continue
                for i in a.size():
                        var ea: Array = a[i]
                        var eb: Array = b[i]
                        var oa: Object = ea[1]
                        var ob: Object = eb[1]
                        var same_obj: bool = (oa == ob) or (oa == null and ob == null)
                        var pa: Vector2 = ea[0]
                        var pb: Vector2 = eb[0]
                        if not same_obj or bool(ea[2]) != bool(eb[2]) or not is_equal_approx(pa.x, pb.x) or not is_equal_approx(pa.y, pb.y):
                                mis += 1
                                if mis <= 6:
                                        print("  cid=", cid, " i=", i, " obj=", oa, "/", ob, " recon=", bool(ea[2]), "/", bool(eb[2]), " p=", pa, "/", pb)
        return mis


func sees(country_id: int, o: Object) -> bool:
        return (seen.get(country_id, {}) as Dictionary).has(o)



func nearest_spotted(country_id: int, p: Vector2, r: float) -> Array:
        var best: Array = []
        var bd: float = r * r
        for e: Array in spotted.get(country_id, []):
                var d: float = (e[0] as Vector2).distance_squared_to(p)
                if d < bd:
                        bd = d
                        best = [e[0], e[1]]
        return best





func request(home: Facility, c: int, p: Vector2, obj: Object, from: Vector2) -> void :
        if support_off.has(c):
                return
        for rq: Dictionary in requests:
                if rq["home"] == home and (rq["p"] as Vector2).distance_to(p) < 40.0:
                        rq["t"] = gw.game_time
                        return
        requests.append({"c": c, "p": p, "obj": obj, "t": gw.game_time, "home": home, "served": 0, "news": false, "id": _rid})
        _rid += 1
        flares.append({"p": from, "t0": gw.game_time, "life": 3.5, "col": 1, "h0": 0.0, "h1": 34.0})
        if gw._on_screen(from, 80.0):
                Sfx.play("grenade", from, -16.0)


func _serve(rq: Dictionary, shooter: Unit) -> void :
        rq["served"] = int(rq["served"]) + 1
        if shooter.home != null:
                _supporting[shooter.home] = gw.game_time
        if bool(rq["news"]) or shooter.home == rq["home"]:
                return
        rq["news"] = true
        var c: Country = gw.country_by_id(int(rq["c"]))
        if c != null and c.is_player and shooter.home != null:
                var asker: Facility = rq["home"]
                var key: String = "%d:%d" % [asker.id, shooter.home.id]
                if gw.game_time < float(_news_t.get(key, -1.0)):
                        return
                _news_t[key] = gw.game_time + 90.0
                var guns: String = Loc.t("миномёты") if shooter.type == Unit.Type.MORTAR else (Loc.t("гаубицы") if shooter.type == Unit.Type.ARTY else Loc.t("РСЗО"))
                gw.say(c, Loc.mk("Армия №%d вызвала огонь: стреляют %s армии №%d", [asker.army_no, guns, shooter.home.army_no]))


func supporting(home: Facility) -> bool:
        return gw.game_time - float(_supporting.get(home, -99.0)) < 8.0 or fired_recently(home)


func fired_recently(home: Facility) -> bool:
        return gw.game_time - float(_fired.get(home, -99.0)) < 12.0



func can_reach(country_id: int, p: Vector2) -> bool:
        for u: Unit in army.units:
                if u.alive() and u.indirect() and u.country_id == country_id and u.pos.distance_to(p) <= float(Army.SPEC[u.type]["range"]):
                        return true
        return false




func _aim_all() -> void :
        if army._nat != null:
                _aim_build_flats()
        for u: Unit in army.units:
                if not u.alive() or not u.indirect() or u.fire_cd > 0.0 or u.salvo > 0:
                        continue
                var moving: bool = u.pi < u.path.size()
                if moving and u.type != Unit.Type.MORTAR and u.type != Unit.Type.ARTY:
                        continue
                var sp: Dictionary = Army.SPEC[u.type]
                var rmax: float = float(sp["range"]) * (0.8 if moving else 1.0)
                var rmin: float = float(sp["min"])
                var pick: Array = _pick(u, rmin, rmax)
                if pick.is_empty():
                        continue
                var p: Vector2 = pick[0]
                u.heading = (p - u.pos).angle()
                u.update_frame()
                if u.type == Unit.Type.MLRS:
                        u.salvo = int(sp["salvo"])
                        u.salvo_t = 0.0
                        u.aim = p
                        u.fire_cd = float(sp["cd"])
                        _ripple.append(u)
                        Sfx.play("mlrs_salvo", u.pos)
                        _far_boom(u.pos)
                else:

                        u.fire_cd = float(sp["cd"]) * rfr(0.85, 1.15) * (1.6 if moving else 1.0)
                        _launch(u, p, bool(pick[1]))




func _pick(u: Unit, rmin: float, rmax: float) -> Array:
        # Гейт окопанных целей потребляет rf() — порядок RNG как в эталоне.
        var use_dugin: bool = (u.type == Unit.Type.MORTAR or u.type == Unit.Type.ARTY) and rf() < DUG_IN_PICK
        # Нативный путь (Rust): ветки 1–3 выбора точки огня.
        if army._nat != null:
                var got: Array = _pick_nat(u, rmin, rmax, use_dugin)
                if not got.is_empty():
                        return got
        return _pick_gd(u, rmin, rmax, use_dugin)


# Плоские spotted для нативного _pick (spotted не меняется за время _aim_all).
func _aim_build_flats() -> void :
        _aim_spot_flat.clear()
        _aim_spot_range.clear()
        for cid: int in spotted:
                var st: int = _aim_spot_flat.size() / 7
                for e: Array in spotted[cid]:
                        var p: Vector2 = e[0]
                        var o: Object = e[1]
                        if o is Unit:
                                var ou: Unit = o
                                _aim_spot_flat.append(p.x)
                                _aim_spot_flat.append(p.y)
                                _aim_spot_flat.append(1.0)
                                _aim_spot_flat.append(1.0 if ou.vehicle() else 0.0)
                                _aim_spot_flat.append(1.0 if (ou.entrenched or ou.dug or ou.foot()) else 0.0)
                                _aim_spot_flat.append(1.0 if ou.entrenched else 0.0)
                        else:
                                _aim_spot_flat.append(p.x)
                                _aim_spot_flat.append(p.y)
                                _aim_spot_flat.append(0.0)
                                _aim_spot_flat.append(0.0)
                                _aim_spot_flat.append(0.0)
                                _aim_spot_flat.append(0.0)
                        _aim_spot_flat.append(1.0 if bool(e[2]) else 0.0)
                _aim_spot_range[cid] = Vector2i(st, _aim_spot_flat.size() / 7)


# Живые данные requests на момент pick (позиции и served, как в эталоне).
func _aim_build_reqs() -> void :
        _aim_req_xy.clear()
        _aim_req_c.clear()
        _aim_req_served.clear()
        for rq: Dictionary in requests:
                var p: Vector2 = rq["p"]
                var o: Object = rq["obj"]
                if o is Unit and (o as Unit).alive():
                        p = (o as Unit).pos
                _aim_req_xy.append(p.x)
                _aim_req_xy.append(p.y)
                _aim_req_c.append(int(rq["c"]))
                _aim_req_served.append(float(rq["served"]))


# Нативный _pick: плоские данные spotted/requests готовит _aim_all (раз в вызов).
func _pick_nat(u: Unit, rmin: float, rmax: float, use_dugin: bool) -> Array:
        var c: int = u.country_id
        var rng: Vector2i = _aim_spot_range.get(c, Vector2i.ZERO)
        _aim_build_reqs() # живые позиции и served на момент вызова
        var ut := PackedInt32Array([u.type])
        var ux := PackedFloat64Array([u.pos.x])
        var uy := PackedFloat64Array([u.pos.y])
        var uc := PackedInt32Array([c])
        var rn := PackedFloat64Array([rmin])
        var rx := PackedFloat64Array([rmax])
        var s0 := PackedInt32Array([rng.x])
        var s1 := PackedInt32Array([rng.y])
        var dg := PackedInt32Array([1 if use_dugin else 0])
        var hr := PackedInt32Array([0 if support_off.has(c) else 1])
        var res: PackedFloat64Array = army._nat.aim_pick(ut, ux, uy, uc, rn, rx, s0, s1, dg, hr, _aim_spot_flat, _aim_req_xy, _aim_req_c, _aim_req_served)
        var kind: int = int(res[0])
        if kind == 1:
                return [Vector2(res[1], res[2]), res[3] != 0.0]
        if kind == 2:
                var rq: Dictionary = requests[int(res[4])]
                _serve(rq, u)
                return [Vector2(res[1], res[2]), false]
        return []


# GDScript-эталон _pick (parity + отказ без натива). use_dugin — результат
# гейта rf(), передаётся снаружи, чтобы RNG-последовательность совпадала.
func _pick_gd(u: Unit, rmin: float, rmax: float, use_dugin: bool) -> Array:
        var c: int = u.country_id
        var best: Array = []
        var bs: float = INF

        if use_dugin:
                for e0: Array in spotted.get(c, []):
                        if not (e0[1] is Unit and (e0[1] as Unit).entrenched):
                                continue
                        var d0: float = u.pos.distance_to(e0[0])
                        if d0 >= rmin and d0 <= rmax and d0 < bs:
                                bs = d0
                                best = [e0[0], bool(e0[2])]
                if not best.is_empty():
                        return best
        if not support_off.has(c):
                for rq: Dictionary in requests:
                        if int(rq["c"]) != c:
                                continue
                        var o: Object = rq["obj"]
                        var p: Vector2 = rq["p"]
                        if o is Unit and (o as Unit).alive():
                                p = (o as Unit).pos
                        var d: float = u.pos.distance_to(p)
                        if d < rmin or d > rmax:
                                continue
                        var s: float = d * 0.5 + float(rq["served"]) * 60.0
                        if s < bs:
                                bs = s
                                best = [p, false, rq]
        if not best.is_empty():
                _serve(best[2], u)
                return [best[0], false]
        var list: Array = spotted.get(c, [])
        for e: Array in list:
                var p2: Vector2 = e[0]
                var d2: float = u.pos.distance_to(p2)
                if d2 < rmin or d2 > rmax:
                        continue
                var s2: float = d2
                var o2: Object = e[1]
                if o2 is Unit:
                        var ou: Unit = o2
                        if u.type == Unit.Type.ARTY and ou.vehicle():
                                s2 -= 250.0
                        if u.type == Unit.Type.MORTAR and (ou.entrenched or ou.dug or ou.foot()):
                                s2 -= 120.0
                        if u.type == Unit.Type.MLRS:
                                var near: int = 0
                                for e2: Array in list:
                                        if (e2[0] as Vector2).distance_squared_to(p2) < 900.0:
                                                near += 1
                                s2 -= float(near) * 120.0
                                if near < 3:
                                        continue
                elif u.type == Unit.Type.MLRS:
                        continue
                if s2 < bs:
                        bs = s2
                        best = [p2, bool(e[2])]
        if not best.is_empty():
                return best

        if u.target_city >= 0 and u.op_on:
                var city: City = gw.cities[u.target_city]
                var cp: = Vector2(city.center * GameWorld.CELL)
                var d3: float = u.pos.distance_to(cp)
                if d3 >= rmin and d3 <= rmax + float(city.radius * GameWorld.CELL) * 0.5 and army._hostile(c, city.country_id):
                        var rr: float = float(city.radius * GameWorld.CELL) * 0.7
                        var aim: Vector2 = cp + Vector2(rfr( - rr, rr), rfr( - rr, rr))
                        if u.pos.distance_to(aim) > rmax:
                                aim = u.pos + (aim - u.pos).normalized() * rmax
                        return [aim, false]
        return []


func _launch(u: Unit, p: Vector2, recon_seen: bool) -> void :
        var k: int = KIND_MORTAR if u.type == Unit.Type.MORTAR else (KIND_ARTY if u.type == Unit.Type.ARTY else KIND_ROCKET)
        if u.home != null:
                _fired[u.home] = gw.game_time
        var d: float = u.pos.distance_to(p)
        var sc: float = [6.0, 9.0, 16.0][k] + d * [0.025, 0.018, 0.02][k]
        if recon_seen:
                sc *= 0.6
        var ang: float = rf() * TAU
        var to: Vector2 = p + Vector2.from_angle(ang) * sc * sqrt(rf())
        var sp: Dictionary = Army.SPEC[u.type]
        var dir: Vector2 = (p - u.pos).normalized()
        var muzzle: Vector2 = u.pos + dir * [3.0, 7.0, 5.0][k] + Vector2(0, -2)
        var dur: float = [1.6 + d / 150.0, 1.0 + d / 320.0, 0.9 + d / 300.0][k]
        var h: float = [clampf(d * 0.45, 30.0, 110.0), clampf(d * 0.1, 8.0, 50.0), clampf(d * 0.16, 18.0, 90.0)][k]
        shells.append({"k": k, "from": muzzle, "to": to, "t": 0.0, "dur": dur, "h": h, "dmg": float(sp["dmg"]), "r": float(sp["blast"]), 
                "c": u.country_id, "pts": PackedVector2Array(), "whistle": false, "trail": 0.0})
        var on: bool = gw._on_screen(u.pos, 60.0)
        if k == KIND_MORTAR:
                if on:
                        _fx("mortar_flash", "muzzle_flash", muzzle)
                Sfx.play("mortar_fire", u.pos)
        elif k == KIND_ARTY:
                if on:
                        _fx("arty_flash", "tank_shot", muzzle)
                        gw.fx.spawn("dirt_burst", (u.pos - dir * 4.0).round(), 5)
                        _shake(u.pos, false)
                Sfx.play("artillery_fire", u.pos)
                _far_boom(u.pos)
                _shots.append([gw.game_time, u.pos])
        else:
                if on:
                        _fx("mlrs_launch", "atgm_launch", muzzle)
                        if randi() % 3 == 0:
                                gw.fx.spawn("rpg_backblast", (u.pos - dir * 6.0).round(), 5)



func _far_boom(p: Vector2) -> void :
        var lp: Vector2 = Sfx.listener()
        if not lp.is_finite() or gw.camera == null:
                return
        var half: float = gw.camera.view_size().length() * 0.5
        var d: float = lp.distance_to(p) / maxf(1.0, half)
        if d > 2.0 and d < 7.0:
                Sfx.far("artillery_far", p, -3.0 - 2.5 * (d - 2.0))


func _ripples(dt: float) -> void :
        for k in range(_ripple.size() - 1, -1, -1):
                var u: Unit = _ripple[k]
                if not u.alive() or u.salvo <= 0:
                        u.salvo = 0
                        _ripple.remove_at(k)
                        continue
                u.salvo_t -= dt
                if u.salvo_t <= 0.0:
                        u.salvo_t = 0.16
                        u.salvo -= 1
                        _launch(u, u.aim, false)
                        if u.salvo % 4 == 0:
                                _shots.append([gw.game_time, u.pos])





static func shell_pos(s: Dictionary) -> Vector2:
        var k: float = clampf(float(s["t"]) / float(s["dur"]), 0.0, 1.0)
        var g: Vector2 = (s["from"] as Vector2).lerp(s["to"], k)
        return g + Vector2(0, - float(s["h"]) * 4.0 * k * (1.0 - k))


func _update_shells(dt: float) -> void :
        # Нативный путь (Rust): тайминги (t, свист, трейл-тик, прибытие).
        # RNG свиста, pts и _impact — GDScript (нужны живые объекты и randi()).
        if army._nat != null:
                var st := PackedFloat64Array()
                var sd := PackedFloat64Array()
                var sk := PackedInt32Array()
                var sw := PackedInt32Array()
                var sl := PackedFloat64Array()
                for s: Dictionary in shells:
                        st.append(float(s["t"]))
                        sd.append(float(s["dur"]))
                        sk.append(int(s["k"]))
                        sw.append(1 if bool(s["whistle"]) else 0)
                        sl.append(float(s["trail"]))
                var res: PackedFloat64Array = army._nat.shells_step(dt, st, sd, sk, sw, sl)
                var out: Array = []
                for i in shells.size():
                        var s: Dictionary = shells[i]
                        var nt: float = res[i * 4]
                        var w: float = res[i * 4 + 1]
                        var arr: float = res[i * 4 + 2]
                        var tick: float = res[i * 4 + 3]
                        s["t"] = nt
                        var kind: int = int(s["k"])
                        if kind == KIND_ROCKET:
                                var ntr: float = float(s["trail"]) + dt
                                if tick != 0.0:
                                        s["trail"] = 0.0
                                        var pts: PackedVector2Array = s["pts"]
                                        pts.append(shell_pos(s))
                                        if pts.size() > 12:
                                                pts.remove_at(0)
                                        s["pts"] = pts
                                else:
                                        s["trail"] = ntr
                        if w != 0.0:
                                s["whistle"] = true
                                if gw._on_screen(s["to"], 40.0) and randi() % 2 == 0:
                                        Sfx.play("shell_whistle_in", s["to"], -4.0)
                        if arr == 0.0:
                                out.append(s)
                        else:
                                _impact(s)
                shells = out
                return
        _update_shells_gd(dt)


# GDScript-эталон _update_shells (parity + отказ без натива).
func _update_shells_gd(dt: float) -> void :
        for k in range(shells.size() - 1, -1, -1):
                var s: Dictionary = shells[k]
                s["t"] = float(s["t"]) + dt
                var kind: int = int(s["k"])
                if kind == KIND_ROCKET:
                        s["trail"] = float(s["trail"]) + dt
                        if float(s["trail"]) >= 0.05:
                                s["trail"] = 0.0
                                var pts: PackedVector2Array = s["pts"]
                                pts.append(shell_pos(s))
                                if pts.size() > 12:
                                        pts.remove_at(0)
                                s["pts"] = pts
                if not bool(s["whistle"]) and kind != KIND_ROCKET and float(s["dur"]) - float(s["t"]) < 0.9:
                        s["whistle"] = true
                        if gw._on_screen(s["to"], 40.0) and randi() % 2 == 0:
                                Sfx.play("shell_whistle_in", s["to"], -4.0)
                if float(s["t"]) < float(s["dur"]):
                        continue
                shells.remove_at(k)
                _impact(s)


func _impact(s: Dictionary) -> void :
        var p: Vector2 = s["to"]
        var kind: int = int(s["k"])
        var c: int = int(s["c"])
        var r: float = float(s["r"])
        var dmg: float = float(s["dmg"])
        var on: bool = gw._on_screen(p, 50.0)
        if on:
                var n: String = ["mortar_burst", "shell_burst", "rocket_burst"][kind]
                _fx(n, "explosion_s" if kind != KIND_ARTY else "explosion_m", p)
                if kind == KIND_ARTY:
                        gw.fx.debris_burst(p.round(), 3, false, true)
                        _shake(p, false)
                elif kind == KIND_ROCKET:
                        _shake(p, true)
        Sfx.play("expl_big" if kind == KIND_ARTY else "expl_small", p, -5.0 if kind == KIND_ARTY else -6.0)
        _shots.append([gw.game_time, p])
        if gw.vfx != null:
                gw.vfx.on_impact(p, 0)
        if gw.battle_watch != null:
                gw.battle_watch.note(p, 1.5 if kind == KIND_ARTY else 0.8, "", c)
        if kind == KIND_ARTY or ri(3) == 0:
                add_decal("crater_s", p.round())
                army.tac.add_crater(p)
        # Сетка вместо полного перебора: ударная волна действует в радиусе r*2.5,
        # _near(p, r*2.5) покрывает его с запасом на лаг сетки (0.25 c).
        for u: Unit in army._near(p, r * 2.5):
                if not u.alive() or not u.ground() or not army._hostile(c, u.country_id):
                        continue
                var d: float = u.pos.distance_to(p)
                if d <= r + 3.0:
                        army._damage(u, dmg * (1.0 if d < r * 0.5 else 0.5), c, p, false, 2)
                elif d <= r * 2.5:
                        u.supp = minf(1.0, u.supp + 0.3)
                        if d <= r * 2.0:
                                army.pin(u)
        if gw.naval != null:
                gw.naval.on_shell(p, r, dmg, c)

        var cell: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
        var rc: int = int(ceilf(r / GameWorld.CELL * 0.6))
        var caved: bool = false
        var rt: int = maxi(1, int(r / GameWorld.CELL))
        for ty in range( - rt, rt + 1):
                for tx in range( - rt, rt + 1):
                        var tq: = cell + Vector2i(tx, ty)
                        if tx * tx + ty * ty <= rt * rt and gw.mil.fort_cells.has(tq) and Military.is_teeth((gw.mil.fort_cells[tq] as Facility).kind):
                                gw.mil.remove_line_cell(gw.mil.fort_cells[tq], tq)
        for dy in range( - rc, rc + 1):
                for dx in range( - rc, rc + 1):
                        var q: = cell + Vector2i(dx, dy)
                        if caved or not gw.mil.fort_cells.has(q):
                                continue
                        var lf: Facility = gw.mil.fort_cells[q]
                        if Military.is_teeth(lf.kind):
                                continue
                        if not army._hostile(c, lf.country_id):
                                continue
                        if ri(100) < [12, 35, 15][kind]:
                                gw.mil.remove_line_cell(lf, q)
                                caved = true
        for f: Facility in gw.mil.facilities:
                if f.parent != null or f.is_line() or not army._hostile(c, f.country_id):
                        continue
                var ext: float = float(maxi(f.size.x, f.size.y)) * 2.0 + r
                if f.center_px().distance_squared_to(p) <= ext * ext and gw.mil.alive(f):
                        army._damage(f, dmg * 0.4, c, p)
                        break

        for city: City in gw.cities:
                var cp: = Vector2(city.center * GameWorld.CELL)
                var cr: float = float(city.radius * GameWorld.CELL)
                if cp.distance_squared_to(p) > cr * cr or not army._hostile(c, city.country_id):
                        continue
                city.garrison = maxf(0.0, city.garrison - dmg * 0.3)
                city.hit_t = gw.game_time
                if ri([14, 5, 9][kind]) == 0:
                        gw._apply_strike(cell, 1, "crater_s", 6.0, c)
                break


func cook_off(p: Vector2) -> void :
        if gw._on_screen(p, 40.0):
                _fx("rocket_burst", "explosion_s", p)
        Sfx.play("expl_small", p, -6.0)



func add_decal(n: String, p: Vector2) -> void :
        var dl: Array = gw.ground.decals
        if dl.size() > 500:
                dl.remove_at(0)
        dl.append([n, p])
        _decal_dirty = true


func _fx(n: String, fallback: String, p: Vector2) -> void :
        gw.fx.spawn(n if gw.fx.atlas_of.has(n) else fallback, p.round(), 6)


func _shake(p: Vector2, big: bool) -> void :
        if gw.game_time < _shake_t or gw.camera == null:
                return
        if gw.camera.position.distance_to(p) > gw.camera.view_size().length() * 0.3:
                return
        _shake_t = gw.game_time + (1.2 if big else 0.6)
        if big:
                gw.camera.shake(false)
        else:
                gw.camera_shake_tiny(p)




func recon_count(home: Facility) -> int:
        var n: int = 0
        for d: Unit in recon:
                if d.base == home and d.alive():
                        n += 1
        return n



func _recon_upkeep() -> void :
        for k in range(recon.size() - 1, -1, -1):
                var d: Unit = recon[k]
                if not d.alive():
                        recon.remove_at(k)
                        if d.base != null:
                                _recon_t[d.base] = gw.game_time + RECON_CD
                        continue
                var c0: Country = gw.country_by_id(d.country_id)
                if c0 == null or c0.at_war.is_empty() or d.base == null or not gw.mil.alive(d.base):
                        recon.remove_at(k)
                        if d.base != null and gw.mil.alive(d.base):
                                _parked[d.base] = int(_parked.get(d.base, 0)) + 1
                        continue


                if d.still_t >= RECON_IDLE and d.pos.distance_to(_pad(d.base)) < 4.0:
                        recon.remove_at(k)
                        _parked[d.base] = int(_parked.get(d.base, 0)) + 1
        for f: Facility in gw.mil.facilities:
                if f.kind != Facility.Kind.BARRACKS or not gw.mil.alive(f):
                        continue
                var want: int = int(army.build_of(f)["recon"])
                if want <= 0 or gw.game_time < float(_recon_t.get(f, 0.0)):
                        continue
                var c: Country = gw.country_by_id(f.country_id)
                if c == null or c.at_war.is_empty() or recon_count(f) >= want:
                        continue
                if not _task(f, c.id).is_finite():
                        continue
                var parked: int = mini(int(_parked.get(f, 0)), want)
                if parked > 0:
                        _parked[f] = parked - 1
                else:
                        var cost: Dictionary = army.unit_cost(Unit.Type.RECON)
                        if not c.has_res(cost):
                                continue
                        c.pay_res(cost)
                        army._stat_spend(c, cost)
                _recon_t[f] = gw.game_time + 6.0
                var d2: = Unit.new()
                d2.id = army._next_id
                army._next_id += 1
                d2.type = Unit.Type.RECON
                d2.country_id = f.country_id
                d2.base = f
                d2.hp = float(Army.SPEC[Unit.Type.RECON]["hp"])
                d2.max_hp = d2.hp
                d2.pos = army.barracks_out(f) + Vector2(0, -4)
                d2.orbit = rf() * TAU
                d2.state = Unit.State.MOVE
                recon.append(d2)
                if gw._on_screen(d2.pos, 60.0):
                        Sfx.play("drone_launch", d2.pos, -8.0)


func _pad(home: Facility) -> Vector2:
        return army.barracks_out(home) + Vector2(0, -4)



func _task(home: Facility, cid: int) -> Vector2:
        var fr: Array = army.tac.front(home)
        if not fr.is_empty():
                var cen: Vector2 = fr[0]
                return cen + ((fr[1] as Vector2) - cen).normalized() * 80.0
        var bp: Vector2 = home.center_px()
        var best: = Vector2.INF
        var bd: float = 650.0 * 650.0
        for rq: Dictionary in requests:
                if int(rq["c"]) == cid and (rq["p"] as Vector2).distance_squared_to(bp) < bd:
                        bd = (rq["p"] as Vector2).distance_squared_to(bp)
                        best = rq["p"]
        if best.is_finite():
                return best
        var ns: Array = nearest_spotted(cid, bp, 600.0)
        if not ns.is_empty():
                return bp.lerp(ns[0], 0.8)
        return Vector2.INF


func _update_recon(dt: float) -> void :
        var snd: = Vector2.INF
        var sd: float = INF
        var lp: Vector2 = Sfx.listener()
        for d: Unit in recon:
                if not d.alive():
                        continue
                if d.jam_t > 0.0:
                        d.jam_t -= dt
                        d.heading += dt * 3.0
                        d.pos += Vector2.from_angle(d.heading) * 18.0 * dt
                        if d.jam_t <= 0.0:
                                army._kill(d, 0)
                        continue
                d.orbit += dt * 0.8
                var task: Vector2 = _task(d.base, d.country_id) if d.base != null else Vector2.INF
                d.still_t = 0.0 if task.is_finite() else d.still_t + dt
                var st: Vector2 = (task + Vector2(cos(d.orbit), sin(d.orbit) * 0.6) * 22.0) if task.is_finite() else (_pad(d.base) if d.base != null else d.pos)
                var to: Vector2 = st - d.pos
                var step: float = RECON_SPEED * dt
                if to.length() > step:
                        d.pos += to.normalized() * step
                        d.heading = to.angle()
                elif not task.is_finite():
                        d.pos = st
                if lp.is_finite() and gw._on_screen(d.pos, 30.0):
                        var dd: float = d.pos.distance_squared_to(lp)
                        if dd < sd:
                                sd = dd
                                snd = d.pos
        Sfx.loop("recon", "recon_drone_buzz", snd.is_finite(), snd)



func _shoot_recon() -> void :
        for d: Unit in recon:
                if not d.alive():
                        continue
                for o: Unit in army.units:
                        if not o.alive() or not (o.foot() or o.type == Unit.Type.IFV) or o.indirect() or not army._hostile(o.country_id, d.country_id):
                                continue
                        var r: float = 90.0 if o.type == Unit.Type.IFV else 50.0
                        if o.pos.distance_squared_to(d.pos) > r * r:
                                continue
                        if ri(100) < (8 if o.type == Unit.Type.IFV else 3):
                                if gw._on_screen(d.pos, 40.0):
                                        gw.mil.air.tracers.append([o.pos, d.pos, gw.game_time + 0.1])
                                        gw.fx.spawn("hit_small", d.pos.round(), 7)
                                        gw.fx.debris_burst(d.pos.round(), 2, false, true)
                                Sfx.play("mg_burst", o.pos, -4.0)
                                army._kill(d, o.country_id)
                                var c: Country = gw.country_by_id(d.country_id)
                                if c != null and c.is_player:
                                        gw.say(c, Loc.mk("Разведдрон армии №%d сбит", [d.base.army_no if d.base != null else 0]))
                                break





func illuminate(p: Vector2) -> void :
        flares.append({"p": p, "t0": gw.game_time, "life": 9.0, "col": 0, "h0": 46.0, "h1": 8.0})



func flare_state(f: Dictionary) -> Array:
        var age: float = gw.game_time - float(f["t0"])
        var life: float = float(f["life"])
        var h: float
        if int(f["col"]) == 1:
                h = lerpf(float(f["h0"]), float(f["h1"]), clampf(age / 1.0, 0.0, 1.0))
        else:
                h = lerpf(float(f["h0"]), float(f["h1"]), clampf(age / life, 0.0, 1.0))
        var b: float = clampf(minf(age / 0.3, (life - age) / 1.2), 0.0, 1.0)
        var g: Vector2 = f["p"]
        return [g + Vector2(sin(age * 1.7) * 2.0, - h), g, b, int(f["col"])]



func light_points() -> Array:
        var out: Array = []


        var now: float = gw.game_time
        for f: Dictionary in flares:
                var st: Array = flare_state(f)
                var b: float = float(st[2])
                if int(st[3]) == 0:
                        var age: float = now - float(f["t0"])
                        var fade: float = 1.0 - 0.45 * clampf(age / maxf(0.1, float(f["life"])), 0.0, 1.0)
                        var flick: float = 0.9 + 0.1 * sin(age * 13.0 + float(f["t0"]) * 7.0)
                        out.append([st[1], 44.0, Color(1.0, 0.9, 0.7, b * fade * flick)])
                        out.append([st[0], 4.0, Color(1.0, 0.95, 0.85, 0.55 * b * flick)])
                else:
                        out.append([st[0], 7.0, Color(1.0, 0.3, 0.2, 0.4 * b)])
        for s: Dictionary in shells:
                if int(s["k"]) == KIND_ROCKET:
                        out.append([shell_pos(s), 5.0, Color(1.0, 0.6, 0.25, 0.35)])
        return out



func _cannonade() -> void :
        _shoot_recon()
        var now: float = gw.game_time
        for k in range(_shots.size() - 1, -1, -1):
                if now - float(_shots[k][0]) > 6.0:
                        _shots.remove_at(k)
        var on: bool = _shots.size() >= 4
        var vol: float = -60.0
        if on:
                var cen: = Vector2.ZERO
                for e: Array in _shots:
                        cen += e[1]
                cen /= float(_shots.size())
                var lp: Vector2 = Sfx.listener()
                if lp.is_finite() and gw.camera != null:
                        var d: float = lp.distance_to(cen) / maxf(1.0, gw.camera.view_size().length() * 0.5)
                        vol = -2.0 - 2.5 * maxf(0.0, d - 0.5) + minf(4.0, float(_shots.size() - 4) * 0.4)
                        on = d < 6.0
                else:
                        on = false
        Sfx.loop("cannonade", "battle_cannonade_loop", on, Vector2.INF, vol)
