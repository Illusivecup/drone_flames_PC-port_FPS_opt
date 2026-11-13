class_name Military
extends "res://game/military/mil_strike.gd"










func _init(world: GameWorld) -> void :
        gw = world
        air = Air.new(world, self)
        brain = DroneBrain.new(world)




# Локальный под-профайлер (как в army._pf2): максимум за период в gw.perf_sys.
func _pf2(nm: String, t0: int) -> void :
        if not GameWorld.perf_prof:
                return
        var d: float = float(Time.get_ticks_usec() - t0) / 1000.0
        if d > float(gw.perf_sys.get(nm, 0.0)):
                gw.perf_sys[nm] = d


func update(dt: float) -> void :
        _income_t += dt
        if _income_t >= INCOME_DT:
                _income_t -= INCOME_DT
                _income()
        for f: Facility in facilities:
                if f.restore_t > 0.0:
                        _restore_tick(f, dt)
        _watch_state()
        _pending_t += dt
        if _pending_t >= 2.0 and not _pending_plants.is_empty():
                _pending_t = 0.0
                for k in range(_pending_plants.size() - 1, -1, -1):
                        var pc: Array = _pending_plants[k]
                        var cap: City = pc[1]
                        _no_construct = true
                        var sp: Facility = auto_place(Facility.Kind.POWER_PLANT, cap.center, pc[0], cap.radius + 6, cap.radius + 60)
                        _no_construct = false
                        if sp != null:
                                _pending_plants.remove_at(k)
        _power_t += dt
        if _power_t >= POWER_DT:
                _power_t = 0.0
                _update_power()
        _fuel_t += dt
        if _fuel_t >= FUEL_DT:
                _fuel_t -= FUEL_DT
                _update_fuel()
        var _t0 := Time.get_ticks_usec()
        _update_arcs()
        _pf2("mil:arcs", _t0)
        _ai_t += dt
        if _ai_t >= 10.0:
                _ai_t = 0.0
                _ai_energy()
        _prod_acc += dt
        if _prod_acc >= 0.5:
                _produce(_prod_acc)
                _prod_acc = 0.0
        _t0 = Time.get_ticks_usec()
        _repair(dt)
        _pf2("mil:repair", _t0)
        if int(gw.game_time / HEAL_DT) != int((gw.game_time - dt) / HEAL_DT):
                heal_partial()
        _roam_t += dt
        if _roam_t >= ROAM_DT:
                _roam_t = 0.0
                _roam_check()
        _t0 = Time.get_ticks_usec()
        _update_tels(dt)
        _pf2("mil:tels", _t0)
        _t0 = Time.get_ticks_usec()
        _update_drones(dt)
        _pf2("mil:drones", _t0)
        _t0 = Time.get_ticks_usec()
        _update_missiles(dt)
        _pf2("mil:missiles", _t0)
        _t0 = Time.get_ticks_usec()
        _standing_tick(dt)
        _pf2("mil:standing", _t0)
        _t0 = Time.get_ticks_usec()
        air.update(dt)
        _pf2("mil:air", _t0)
        _t0 = Time.get_ticks_usec()
        if gw.get("recon") != null:
                gw.recon.update(dt)
        _pf2("mil:recon", _t0)
        _audio_t += dt
        if _audio_t >= 0.5:
                _audio_t = 0.0
                _audio_tick()




func _audio_tick() -> void :
        var lp: Vector2 = Sfx.listener()
        var pl: Country = gw.player
        var alarm: Vector2 = Vector2.INF
        var buzz: Vector2 = Vector2.INF
        var bd: float = INF
        for d: Drone in drones:
                if d.state == Drone.State.DONE or not d.airborne():
                        continue
                if d.kind == 0 and lp.is_finite() and d.pos.distance_squared_to(lp) < bd:
                        bd = d.pos.distance_squared_to(lp)
                        buzz = d.pos
                if pl != null and not alarm.is_finite() and hostile(d.country_id, pl.id):
                        alarm = _alarm_city(d.target, pl)
        if pl != null and not alarm.is_finite():
                for m: Missile in missiles:
                        if hostile(m.country_id, pl.id):
                                alarm = _alarm_city(m.target, pl)
                                if alarm.is_finite():
                                        break
        Sfx.loop("drone", "drone_buzz_loop", buzz.is_finite(), buzz)
        Sfx.loop("siren", "siren_loop", alarm.is_finite(), alarm)



func _alarm_city(target: Vector2, pl: Country) -> Vector2:
        var c: = Vector2i(floori(target.x / GameWorld.CELL), floori(target.y / GameWorld.CELL))
        if not gw.data.inside(c.x, c.y) or gw.data.get_owner_id(c.x, c.y) != pl.id:
                return Vector2.INF
        var best: Vector2 = Vector2.INF
        for id in pl.city_ids:
                var cp: Vector2 = Vector2(gw.cities[id].center * GameWorld.CELL)
                if not best.is_finite() or cp.distance_squared_to(target) < best.distance_squared_to(target):
                        best = cp
        return best


func _income() -> void :
        for c: Country in gw.countries:
                var add: int = 0
                for cid in c.city_ids:
                        if not gw.cities[cid].powered:
                                continue
                        match gw.cities[cid].kind:
                                City.Kind.CAPITAL:
                                        add += INCOME_CAPITAL
                                City.Kind.TOWN:
                                        add += INCOME_TOWN
                                _:
                                        add += INCOME_VILLAGE
                if not c.is_player:
                        add = int(add * GameConfig.ai_income_mul(c))
                c.add_money(add)


func _produce(dt: float) -> void :
        for f: Facility in facilities:
                if f.kind != Facility.Kind.DRONE_FACTORY and f.kind != Facility.Kind.MISSILE_FACTORY:
                        continue
                if f.halted or f.mb:
                        continue
                if uses_power(f.kind) and not has_power(f):
                        continue
                var pdt: float = dt if f.powered else dt * 0.5
                if f.kind == Facility.Kind.MISSILE_FACTORY:
                        _produce_missiles(f, pdt)
                        continue
                if f.kind != Facility.Kind.DRONE_FACTORY:
                        continue
                if not alive(f):
                        f.producing = false
                        continue
                var c: Country = gw.country_by_id(f.country_id)
                if not f.producing:


                        if not c.is_player and f.prod_type == 0 and _port_runway(c) and gw.rng.roll() < 0.35:
                                f.prod_type = 1
                        var jet: bool = f.prod_type == 1
                        var cost: Dictionary = drone_cost(jet)
                        var sk: int = 901 if jet else 900
                        if gw.econ.get("upk") != null:
                                cost["money"] = roundi(float(int(cost["money"])) * gw.econ.upk.series_mult(c.id, sk))
                        if stock_count(c.id) >= drone_capacity(c.id):
                                continue
                        if jet and not _port_runway(c):
                                if c.is_player and not _warned.has( - f.id - 100000):
                                        _warned[ - f.id - 100000] = true
                                        gw.say(c, Loc.mk("Реактивным нужна ВПП дронопорта: тап по дронопорту › ВПП"))
                                continue
                        if not c.has_res(cost):
                                if c.is_player and not _warned.has( - f.id):
                                        _warned[ - f.id] = true
                                        gw.say(c, Loc.mk("Завод ждёт: не хватает — %s", [c.missing_res(cost)]))
                                continue
                        if _port_with_space(c, f.center_px()) == null:
                                if c.is_player and not _warned.has(f.id):
                                        _warned[f.id] = true
                                        gw.say(c, Loc.mk("Завод ждёт: нужен дронопорт со свободным местом"))
                                continue
                        c.pay_res(cost)
                        if gw.econ.get("upk") != null:
                                gw.econ.upk.note_buy(c.id, sk)
                        _warned.erase( - f.id - 100000)
                        if gw.econ.has_method("stat_add"):
                                gw.econ.call("stat_add", c, "spend", "drones", int(cost["money"]))
                                for rk: String in cost:
                                        if rk != "money":
                                                gw.econ.call("stat_res", c, rk, "drones", - int(cost[rk]))
                        _warned.erase( - f.id)
                        f.prod_jet = jet
                        f.producing = true
                        f.prod_t = 0.0
                        if not c.is_player and jet:
                                f.prod_type = 0
                        continue
                var need_t: float = JET_PROD_TIME if f.prod_jet else PROD_TIME
                f.prod_t = minf(f.prod_t + pdt, need_t)
                if f.prod_t < need_t:
                        continue
                var port: Facility = _port_with_space(c, f.center_px())
                if port == null:
                        continue
                var k: int = _free_ok_spot(port)
                var d: = Drone.new()
                d.id = _next_drone_id
                _next_drone_id += 1
                d.country_id = c.id
                if f.prod_jet:
                        d.kind = 2
                d.airfield = port
                d.spot = k
                d.pos = port.spots[k]
                port.parked[k] = d
                drones.append(d)
                f.producing = false
                f.prod_t = 0.0
                f.flash_until = gw.game_time + 0.48
                _warned.erase(f.id)
                gw.fx.spawn("build_spark", d.pos, 6)


func _produce_missiles(f: Facility, dt: float) -> void :
        if not alive(f):
                f.producing = false
                return
        var c: Country = gw.country_by_id(f.country_id)
        var t: int = f.prod_type
        if not f.producing:
                var mrc: Dictionary = Economy.res_cost("missile_%d" % t)
                if not MT_READY[t] or c.missile_stock[t] >= int(MT_CAP[t]) or c.money < int(MT_COST[t]) or not c.has_res(mrc) or not has_carrier(c, t):
                        return
                c.money -= int(MT_COST[t])
                c.pay_res(mrc)
                gw.econ.stat_add(c, "spend", "missiles", int(MT_COST[t]))
                for mr: String in mrc:
                        gw.econ.stat_res(c, mr, "missiles", - int(mrc[mr]))
                f.producing = true
                f.prod_t = 0.0
                return
        f.prod_t = minf(f.prod_t + dt, float(MT_TIME[t]))
        if f.prod_t < float(MT_TIME[t]):
                return
        c.missile_stock[t] += 1
        f.producing = false
        f.prod_t = 0.0
        f.flash_until = gw.game_time + 0.48
        gw.fx.spawn("build_spark", local_px(f.main_obj, _info("missile_factory")["out"]), 6)


func plan_info(country: Country, wps: Array[Vector2], target: Vector2, has_target: bool, jet: bool = false) -> Dictionary:
        var first: Vector2 = target if wps.is_empty() else wps[0]
        if not has_target and wps.is_empty():
                first = gw.camera.position if gw.camera != null else Vector2.ZERO
        var port: Facility = best_port(country, first)
        var info: Dictionary = {"airfield": port, "from": Vector2.ZERO, "length": 0.0, "in_range": true, "available": 0, "runway_ok": true, "launchers": 0, "next_drone": next_drone_in(country.id), "has_factory": has_kind(country.id, Facility.Kind.DRONE_FACTORY)}
        if port == null:
                return info
        info["from"] = launch_point(port)
        info["available"] = parked_at(port, 2 if jet else 0)
        info["delta"] = parked_at(port, 0)
        info["jets"] = parked_at(port, 2)
        info["launchers"] = runways_of(port) if jet else port_launchers(port).size()
        info["jet"] = jet
        info["range"] = JET_RANGE if jet else RANGE_PX
        if has_target:
                var pts: Array[Vector2] = wps.duplicate()
                pts.append(target)
                var length: float = path_length(launch_point(port), pts)
                info["length"] = length
                info["in_range"] = length <= (JET_RANGE if jet else RANGE_PX)
                if wps.is_empty() and smart_of(country.id):
                        var si: Dictionary = brain.choose(country.id, launch_point(port), target, JET_RANGE if jet else RANGE_PX, false)
                        info["smart"] = _smart_dict(country.id, launch_point(port), target, si, jet)
                        info["length"] = float(si["len"])
                        info["in_range"] = float(si["len"]) <= (JET_RANGE if jet else RANGE_PX)
        return info


func launch(country: Country, wps: Array[Vector2], target: Vector2, count: int, jet: bool = false) -> Array[Drone]:
        var out: Array[Drone] = []
        var first: Vector2 = target if wps.is_empty() else wps[0]
        var port: Facility = best_port(country, first)
        if port == null:
                if country.is_player:
                        gw.say(country, Loc.mk("Нет дронопорта"))
                return out
        if port_launchers(port).is_empty() or (jet and runways_of(port) == 0):
                if country.is_player:
                        gw.say(country, Loc.t("Реактивным нужна ВПП дронопорта") if jet else Loc.t("Нет пусковой: поставьте рампу или ВПП"))
                return out
        if gw.diplo != null and gw.diplo.strike_block_at(country.id, target) != "":
                return out
        var tf: Facility = null
        if not country.is_player:
                tf = target_fac(target)
                if not can_strike_target(tf, country.id, "drone"):
                        var alt: Facility = spread_target(country.id, tf, launch_point(port), (JET_RANGE if jet else RANGE_PX) * 0.9, "drone")
                        if alt == null:
                                return out
                        tf = alt
                        target = alt.center_px()
                        var no_wps: Array[Vector2] = []
                        wps = no_wps
        var sm: Dictionary = {}
        if smart_of(country.id) and (wps.is_empty() or not country.is_player):
                sm = brain.choose(country.id, launch_point(port), target, JET_RANGE if jet else RANGE_PX, true)
        var pts: Array[Vector2] = wps.duplicate() if sm.is_empty() else (sm["wps"] as Array[Vector2]).duplicate()
        pts.append(target)
        var length: float = path_length(launch_point(port), pts)
        if length > (JET_RANGE if jet else RANGE_PX):
                if country.is_player:
                        gw.say(country, Loc.mk("Цель вне дальности"))
                return out
        for k in port.parked.size():
                if out.size() >= count:
                        break
                var d: Drone = port.parked[k]
                if d == null or d.state != Drone.State.PARKED or not _spot_ok(port, k) or (d.kind == 2) != jet:
                        continue
                d.state = Drone.State.WAIT
                if d.kind == 2:
                        d.cruise_speed = JET_CRUISE
                        d.cruise_h = JET_CRUISE_H
                        d.turn_rate = PI * 0.35
                d.launcher = null
                d.route = pts.duplicate()
                d.target = target
                d.route_len = length
                d.range_px = JET_RANGE if d.kind == 2 else RANGE_PX
                d.smart_key = String(sm.get("key", ""))
                d.smart_ver = int(sm.get("ver", -1))
                d.smart_noted = false
                out.append(d)
        if out.is_empty():
                if country.is_player:
                        gw.say(country, Loc.mk("Нет готовых дронов"))
        elif tf != null:
                note_strike(tf, country.id, "drone")
        return out



func launch_missiles(country: Country, target: Vector2, count: int) -> int:
        var n: int = 0
        if gw.diplo != null and gw.diplo.strike_block_at(country.id, target) != "":
                return 0
        var tf: Facility = null
        if not country.is_player:
                tf = target_fac(target)
                if not can_strike_target(tf, country.id, "missile"):
                        var from: Vector2 = target
                        for t: Facility in facilities:
                                if t.kind == Facility.Kind.TEL and t.country_id == country.id and alive(t) and not t.moving and t.missiles > t.queued.size():
                                        from = t.center_px()
                                        break
                        var alt: Facility = spread_target(country.id, tf, from, MISSILE_RANGE, "missile")
                        if alt == null:
                                return 0
                        tf = alt
                        target = alt.center_px()
        for f: Facility in tels_for(country, target):
                while n < count and f.missiles - f.queued.size() > 0:
                        f.queued.append(target)
                        n += 1
        if n == 0 and country.is_player:
                gw.say(country, Loc.mk("Нет ракет в зоне досягаемости"))
        if n > 0 and tf != null:
                note_strike(tf, country.id, "missile")
        return n


func _update_tels(dt: float) -> void :
        for f: Facility in facilities:
                if f.kind != Facility.Kind.TEL:
                        # Only mobile defense facilities can use the shared vehicle movement path.
                        # A stale/corrupt moving flag on a factory (for example a mod building)
                        # must never make it drive or be parked as a vehicle.
                        if f.moving and is_mobile(f.kind):
                                _drive_tel(f, dt)
                        elif f.moving:
                                f.moving = false
                                f.mpath.clear()
                                drive_dir.erase(f.id)
                        continue
                var c: Country = gw.country_by_id(f.country_id)
                if f.moving:
                        _drive_tel(f, dt)
                        continue
                if not alive(f):
                        if f.missiles > 0 or f.erect_t >= 0.0:
                                f.missiles = 0
                                f.erect_t = -1.0
                                f.queued.clear()
                                f.reload_t = 0.0
                        continue

                if f.lower_t > 0.0:
                        f.lower_t -= dt
                        var fr: int = clampi(roundi(6.0 * minf(1.0, f.lower_t / BOOM_LOWER)), 0, 6)
                        gw.set_obj_frame(f.main_obj, f.lower_sprite, fr)
                        if f.lower_t <= 0.0:
                                f.lower_t = 0.0
                                _tel_sprite(f, 0)
                        continue

                if f.reload_t > 0.0:
                        if f.erect_t < 0.0:
                                f.reload_t -= dt
                        if f.reload_t <= 0.0:
                                f.reload_t = 0.0
                                f.missiles += 1
                                if f.erect_t < 0.0:
                                        _tel_sprite(f, 0)
                                gw.fx.spawn("build_spark", f.center_px(), 6)
                elif f.missiles < 2 and f.erect_t < 0.0 and (f.queued.is_empty() or f.missiles == 0):

                        if c.missile_stock[MT_BALLISTIC] > 0:
                                c.missile_stock[MT_BALLISTIC] -= 1
                                f.reload_t = TEL_RELOAD
                                f.warned_empty = false
                        elif f.missiles == 0 and c.is_player and not f.warned_empty:
                                f.warned_empty = true
                                gw.say(c, Loc.mk("ОТРК пуст: нужны баллистические ракеты с ракетного завода"))

                if f.erect_t < 0.0:
                        if not f.queued.is_empty() and f.missiles > 0 and not c.is_player:

                                while not f.queued.is_empty() and ( not strike_worth(f.queued[0], f.country_id)\
                                or (gw.ai != null and gw.ai.get("sense") != null and gw.ai.sense.aim_veto(f.country_id, f.queued[0], "missile") != "")):
                                        f.queued.pop_front()
                                        stale_drop += 1
                        if not f.queued.is_empty() and f.missiles > 0:
                                f.erect_t = 0.0
                        continue
                f.erect_t += dt
                _tel_sprite(f, mini(6, 1 + int(f.erect_t / ERECT_TIME * 6.0)))
                if f.erect_t >= ERECT_TIME:
                        if f.queued.is_empty():
                                f.erect_t = -1.0
                                _tel_sprite(f, 0)
                                continue
                        var tq: Vector2 = f.queued.pop_front()
                        if gw.diplo != null and gw.diplo.strike_block_at(f.country_id, tq) != "":
                                f.erect_t = -1.0
                                _tel_sprite(f, 0)
                                continue
                        _fire(f, tq)


func can_halt(f: Facility) -> bool:
        return f != null and f.parent == null and HALT_KINDS.has(f.kind)




func set_halted(f: Facility, on: bool) -> String:
        if not can_halt(f):
                return Loc.t("Этот объект ничего не производит")
        if f.halted == on:
                return ""
        f.halted = on
        _power_t = POWER_DT
        var c: Country = gw.country_by_id(f.country_id)
        if c != null and c.is_player:
                gw.say(c, "%s: %s" % [title_of(f.kind), Loc.t("производство на паузе") if on else Loc.t("производство возобновлено")])
        return ""



func set_auto_strike(country_id: int, mode: int) -> void :
        auto_strike[country_id] = clampi(mode, 0, 2)
        strike_next[country_id] = 0.0


func auto_strike_of(country_id: int) -> int:
        return int(auto_strike.get(country_id, 0))



func set_auto_drones(country_id: int, on: bool) -> void :
        auto_drones[country_id] = on
        drone_next[country_id] = 0.0


func auto_drones_of(country_id: int) -> bool:
        return bool(auto_drones.get(country_id, false))




func set_auto_kab(country_id: int, on: bool) -> void :
        air.set_auto_kab(country_id, on)


func auto_kab_of(country_id: int) -> bool:
        return air.auto_kab_of(country_id)



func ready_drones(country_id: int, jet: bool) -> int:
        var n: int = 0
        for f: Facility in facilities:
                if f.kind == Facility.Kind.DRONE_PORT and f.country_id == country_id and alive(f) and _port_can(f, jet):
                        n += parked_at(f, 2 if jet else 0)
        return n


func _port_can(port: Facility, jet: bool) -> bool:
        return runways_of(port) > 0 if jet else not port_launchers(port).is_empty()



static func _norm_target(e: Variant) -> Dictionary:
        var out: Dictionary = {"pos": Vector2.ZERO, "n": 1, "wps": [] as Array[Vector2]}
        if e is Dictionary:
                out["pos"] = (e as Dictionary).get("pos", Vector2.ZERO)
                out["n"] = clampi(int((e as Dictionary).get("n", 1)), 1, MULTI_N_MAX)
                var w: Array[Vector2] = []
                for q: Variant in ((e as Dictionary).get("wps", []) as Array):
                        if q is Vector2 and w.size() < MAX_WAYPOINTS:
                                w.append(q)
                out["wps"] = w
        return out




func _multi_port(country_id: int, t: Dictionary, jet: bool, used: Dictionary) -> Array:
        var pts: Array[Vector2] = (t["wps"] as Array[Vector2]).duplicate()
        pts.append(t["pos"])
        var rng: float = JET_RANGE if jet else RANGE_PX
        var best: Facility = null
        var bl: float = INF
        var any_l: float = INF
        for f: Facility in facilities:
                if f.kind != Facility.Kind.DRONE_PORT or f.country_id != country_id or not alive(f) or not _port_can(f, jet):
                        continue
                var l: float = path_length(launch_point(f), pts)
                any_l = minf(any_l, l)
                if l > rng or parked_at(f, 2 if jet else 0) - int(used.get(f.id, 0)) <= 0:
                        continue
                if l < bl:
                        bl = l
                        best = f
        return [best, bl, any_l]



func _send_one(port: Facility, wps: Array[Vector2], target: Vector2, length: float, jet: bool) -> Drone:
        if gw.diplo != null and gw.diplo.strike_block_at(port.country_id, target) != "":
                return null
        for k in port.parked.size():
                var d: Drone = port.parked[k]
                if d == null or d.state != Drone.State.PARKED or not _spot_ok(port, k) or (d.kind == 2) != jet:
                        continue
                d.state = Drone.State.WAIT
                if d.kind == 2:
                        d.cruise_speed = JET_CRUISE
                        d.cruise_h = JET_CRUISE_H
                        d.turn_rate = PI * 0.35
                d.launcher = null
                var sm: Dictionary = {}
                if wps.is_empty() and smart_of(port.country_id):
                        sm = brain.choose(port.country_id, launch_point(port), target, JET_RANGE if jet else RANGE_PX, true)
                var pts: Array[Vector2] = wps.duplicate() if sm.is_empty() else (sm["wps"] as Array[Vector2]).duplicate()
                pts.append(target)
                d.route = pts
                d.target = target
                d.route_len = length if sm.is_empty() else path_length(launch_point(port), pts)
                d.smart_key = String(sm.get("key", ""))
                d.smart_ver = int(sm.get("ver", -1))
                d.smart_noted = false
                d.range_px = JET_RANGE if d.kind == 2 else RANGE_PX
                d.route_ver += 1
                multi_launched += 1
                return d
        return null






func multi_plan(country: Country, targets: Array, jet: bool = false) -> Dictionary:
        var out: Dictionary = {"ok": false, "total": 0, "available": 0, "launch": 0, "jet": jet, "range": JET_RANGE if jet else RANGE_PX, 
                "delta": 0, "jets": 0, "next_drone": -1.0, "why": "", "per_target": []}
        if country == null:
                out["why"] = Loc.t("Нет страны")
                return out
        out["available"] = ready_drones(country.id, jet)
        out["delta"] = ready_drones(country.id, false)
        out["jets"] = ready_drones(country.id, true)
        out["next_drone"] = next_drone_in(country.id)
        var has_port: bool = false
        var has_l: bool = false
        for f: Facility in facilities:
                if f.kind == Facility.Kind.DRONE_PORT and f.country_id == country.id and alive(f):
                        has_port = true
                        has_l = has_l or _port_can(f, jet)
        var ts: Array = []
        for e: Variant in targets:
                ts.append(_norm_target(e))
        var rem: Array[int] = []
        var got: Array[int] = []
        var per: Array = []
        var cruise: float = JET_CRUISE if jet else CRUISE
        var sbw2: String = ""
        for t: Dictionary in ts:
                out["total"] = int(out["total"]) + int(t["n"])
                rem.append(int(t["n"]))
                got.append(0)
                var r: Array = _multi_port(country.id, t, jet, {})
                var e: Dictionary = {"ok": false, "reason": "", "dist": 0.0, "eta": 0.0, "from": Vector2.ZERO, "n": int(t["n"]), "launch": 0}
                var l: float = float(r[2])
                if l < INF:
                        e["dist"] = l
                        e["eta"] = GROUND_ETA + l / cruise
                var near: Facility = r[0]
                if near == null:

                        var bd: float = INF
                        for f: Facility in facilities:
                                if f.kind == Facility.Kind.DRONE_PORT and f.country_id == country.id and alive(f) and _port_can(f, jet):
                                        var pts: Array[Vector2] = (t["wps"] as Array[Vector2]).duplicate()
                                        pts.append(t["pos"])
                                        var pl: float = path_length(launch_point(f), pts)
                                        if pl < bd:
                                                bd = pl
                                                near = f
                if near != null:
                        e["from"] = launch_point(near)
                        if (t["wps"] as Array).is_empty() and smart_of(country.id) and l < INF:
                                var si: Dictionary = brain.choose(country.id, launch_point(near), t["pos"], float(out["range"]), false)
                                e["smart"] = _smart_dict(country.id, launch_point(near), t["pos"], si, jet)
                                e["dist"] = float(si["len"])
                                e["eta"] = GROUND_ETA + float(si["len"]) / cruise
                if gw.diplo != null and gw.diplo.strike_block_at(country.id, t["pos"], false) != "":
                        e["reason"] = Diplomacy.STRIKE_BLOCK_TXT
                        sbw2 = e["reason"]
                elif not has_port:
                        e["reason"] = Loc.t("Нет дронопорта")
                elif not has_l:
                        e["reason"] = Loc.t("Реактивным нужна ВПП дронопорта") if jet else Loc.t("Нет пусковой: поставьте рампу или ВПП")
                elif l > float(out["range"]):
                        e["reason"] = Loc.t("Вне дальности: %.1f из %.1f км") % [l / 1000.0, float(out["range"]) / 1000.0]
                else:
                        e["ok"] = true
                        if r[0] == null:
                                e["reason"] = Loc.t("Нет готовых дронов в дальности")
                per.append(e)

        var used: Dictionary = {}
        var progress: bool = true
        while progress:
                progress = false
                for i in ts.size():
                        if rem[i] <= 0 or not bool(per[i]["ok"]):
                                continue
                        var r2: Array = _multi_port(country.id, ts[i], jet, used)
                        if r2[0] == null:
                                rem[i] = 0
                                continue
                        var pf: Facility = r2[0]
                        used[pf.id] = int(used.get(pf.id, 0)) + 1
                        rem[i] -= 1
                        got[i] += 1
                        progress = true
        var n_ok: int = 0
        for i in per.size():
                per[i]["launch"] = got[i]
                out["launch"] = int(out["launch"]) + got[i]
                if bool(per[i]["ok"]):
                        n_ok += 1
        out["per_target"] = per
        if ts.is_empty():
                out["why"] = Loc.t("Нет целей")
        elif not has_port:
                out["why"] = Loc.t("Нет дронопорта")
        elif not has_l:
                out["why"] = Loc.t("Реактивным нужна ВПП дронопорта") if jet else Loc.t("Нет пусковой: поставьте рампу или ВПП")
        elif n_ok == 0:
                out["why"] = sbw2 if sbw2 != "" else Loc.t("Цели вне дальности")
        elif int(out["launch"]) == 0:
                out["why"] = Loc.t("Нет готовых дронов") if not jet else Loc.t("Нет готовых реактивных БПЛА")
        elif int(out["launch"]) < int(out["total"]):
                out["why"] = Loc.t("Готово %d из %d") % [int(out["launch"]), int(out["total"])]
        out["ok"] = int(out["launch"]) > 0
        return out



func launch_multi(country: Country, targets: Array, jet: bool = false) -> int:
        return int(launch_multi_ex(country, targets, jet)["launched"])


func launch_multi_ex(country: Country, targets: Array, jet: bool = false) -> Dictionary:
        var res: Dictionary = {"launched": 0, "targets_used": 0, "targets_total": targets.size(), "ready": 0, "wanted": 0, 
                "skipped": [], "jet": jet, "text": ""}
        if country == null:
                res["text"] = Loc.t("Пуск не выполнен: нет страны")
                last_multi = res
                return res
        res["ready"] = ready_drones(country.id, jet)
        var ts: Array = []
        for e: Variant in targets:
                ts.append(_norm_target(e))
        var rem: Array[int] = []
        var got: Array[int] = []
        for t: Dictionary in ts:
                rem.append(int(t["n"]))
                got.append(0)
        var used: Dictionary = {}
        var total: int = 0
        var progress: bool = true
        while progress:
                progress = false
                for i in ts.size():
                        if rem[i] <= 0:
                                continue
                        var t: Dictionary = ts[i]
                        var r: Array = _multi_port(country.id, t, jet, {})
                        var pf: Facility = r[0]
                        var d: Drone = null
                        if pf != null:
                                d = _send_one(pf, t["wps"], t["pos"], float(r[1]), jet)
                        if d == null:
                                rem[i] = 0
                                continue
                        used[pf.id] = int(used.get(pf.id, 0)) + 1
                        rem[i] -= 1
                        got[i] += 1
                        total += 1
                        progress = true
        var asked: int = 0
        var bad: PackedStringArray = []
        var skipped: Array = []
        for i in ts.size():
                asked += int(ts[i]["n"])
                if got[i] == 0:
                        bad.append(str(i + 1))
                        skipped.append(i + 1)
        var used_n: int = ts.size() - bad.size()
        res["launched"] = total
        res["targets_used"] = used_n if total > 0 else 0
        res["targets_total"] = ts.size()
        res["wanted"] = asked
        res["skipped"] = skipped
        var txt: String = ""
        if total == 0:
                var why: String = String(multi_plan(country, targets, jet)["why"])
                txt = Loc.t("Пуск не выполнен: %s") % ((why.left(1).to_lower() + why.substr(1)) if why != "" else Loc.t("нет готовых дронов"))
        else:
                var what: String = Loc.t("реакт. БПЛА") if jet else Loc.t("БПЛА")
                if used_n == ts.size():
                        txt = Loc.t("Пуск: %d %s по %d %s") % [total, what, used_n, Loc.t("цели") if used_n == 1 else Loc.t("целям")]
                else:
                        txt = Loc.t("Пуск: %d %s по %d из %d целей") % [total, what, used_n, ts.size()]
                if total < asked:
                        txt += Loc.t(" (готово %d из %d)") % [total, asked]
                if not bad.is_empty():
                        txt += Loc.t("; без дронов: цель %s") % ", ".join(bad)
        res["text"] = txt
        last_multi = res
        if country.is_player and not bool(gw.get_meta("strike_quiet", false)):
                gw.say(country, txt)
        return res




func set_standing(country_id: int, targets: Array, jet: bool, on: bool, reserve: int = 0) -> String:
        var ts: Array = []
        for e: Variant in targets:
                ts.append(_norm_target(e))
        var old: Dictionary = standing.get(country_id, {})
        if on and ts.is_empty():
                if old.is_empty() or (old.get("targets", []) as Array).is_empty():
                        return Loc.t("Нет целей")
                ts = old["targets"]
        var c: Country = gw.country_by_id(country_id)
        if not on:
                if not old.is_empty():
                        old["on"] = false
                        if c != null and c.is_player:
                                gw.say(c, Loc.mk("Постоянный приказ снят: запущено %d", [int(old.get("launched", 0))]))
                return ""
        var sent: Array = []
        for t: Dictionary in ts:
                sent.append(0)
        standing[country_id] = {"on": true, "targets": ts, "jet": jet, "reserve": clampi(reserve, 0, STANDING_RESERVE_MAX), 
                "launched": 0, "sent": sent, "next_t": 0.0, "warned": false}
        if c != null and c.is_player:
                gw.say(c, Loc.mk("Постоянный приказ: каждый готовый %s — по %d %s", [Loc.t("реактивный БПЛА") if jet else Loc.t("дрон"), ts.size(), Loc.t("цели") if ts.size() == 1 else Loc.t("целям")]))
        return ""



func standing_of(country_id: int) -> Dictionary:
        var st: Dictionary = standing.get(country_id, {})
        if st.is_empty():
                return {"on": false, "targets": [], "jet": false, "reserve": 0, "launched": 0, "sent": []}
        return {"on": bool(st.get("on", false)), "targets": (st.get("targets", []) as Array).duplicate(true), "jet": bool(st.get("jet", false)), 
                "reserve": int(st.get("reserve", 0)), "launched": int(st.get("launched", 0)), "sent": (st.get("sent", []) as Array).duplicate()}


func _standing_tick(dt: float) -> void :
        if standing.is_empty():
                return
        _standing_t += dt
        if _standing_t < 0.5:
                return
        _standing_t = 0.0
        var now: float = gw.game_time
        for cid: int in standing:
                var st: Dictionary = standing[cid]
                if not bool(st.get("on", false)) or now < float(st.get("next_t", 0.0)):
                        continue
                var c: Country = gw.country_by_id(cid)
                if c == null or c.eliminated:
                        st["on"] = false
                        continue
                var jet: bool = bool(st.get("jet", false))
                if ready_drones(cid, jet) <= int(st.get("reserve", 0)):
                        continue
                var ts: Array = st["targets"]
                var sent: Array = st["sent"]
                while sent.size() < ts.size():
                        sent.append(0)

                var order: Array = range(ts.size())
                order.sort_custom( func(a: int, b: int) -> bool:
                        var ra: float = float(sent[a]) / float(maxi(1, int(ts[a]["n"])))
                        var rb: float = float(sent[b]) / float(maxi(1, int(ts[b]["n"])))
                        return ra < rb or (ra == rb and a < b))
                var done: bool = false
                var peace_n: int = 0
                for i: int in order:
                        var t: Dictionary = _norm_target(ts[i])


                        var tc: = Vector2i(floori((t["pos"] as Vector2).x / GameWorld.CELL), floori((t["pos"] as Vector2).y / GameWorld.CELL))
                        var to_id: int = gw.data.get_owner_id(tc.x, tc.y) if gw.data.inside(tc.x, tc.y) else 0
                        if to_id > 0 and to_id != cid and not gw.diplo.at_war(cid, to_id):
                                peace_n += 1
                                continue
                        var r: Array = _multi_port(cid, t, jet, {})
                        if r[0] == null:
                                continue
                        if _send_one(r[0], t["wps"], t["pos"], float(r[1]), jet) != null:
                                sent[i] = int(sent[i]) + 1
                                st["launched"] = int(st.get("launched", 0)) + 1
                                st["next_t"] = now + STANDING_GAP
                                done = true
                                break
                if not done and peace_n > 0 and peace_n >= ts.size():
                        if c.is_player and not bool(st.get("peace_warned", false)):
                                st["peace_warned"] = true
                                gw.say(c, Loc.mk("Постоянный приказ на паузе: с этой страной нет войны"))
                        continue
                st["peace_warned"] = false
                if not done and not bool(st.get("warned", false)):
                        st["warned"] = true
                        if c.is_player:
                                gw.say(c, Loc.mk("Постоянный приказ: готовые дроны не достают до целей"))
                elif done:
                        st["warned"] = false








func set_smart(country_id: int, on: bool) -> void :
        brain.set_smart(country_id, on)
        var c: Country = gw.country_by_id(country_id)
        if c != null and c.is_player:
                gw.say(c, Loc.mk("Умные БПЛА: %s", [Loc.t("ВКЛ — маршруты в обход потерь") if on else Loc.t("ВЫКЛ")]))



func smart_of(country_id: int) -> bool:
        return brain != null and brain.smart_of(country_id)


func _smart_dict(country_id: int, from: Vector2, target: Vector2, si: Dictionary, jet: bool = false) -> Dictionary:
        var mem: Dictionary = si.get("mem", {})
        var route: Array = [from]
        route.append_array(si["wps"])
        route.append(target)
        var rng: float = JET_RANGE if jet else RANGE_PX
        return {"on": smart_of(country_id), "ok": true, "route": route, "wps": (si["wps"] as Array).duplicate(), "source": si["source"], 
                "danger": si["danger"], "wins": int(mem.get("tw", 0)), "losses": int(mem.get("tl", 0)), "sam": int(mem.get("ts", 0)), 
                "drops": int(mem.get("drops", 0)), "len": si["len"], "range": rng, "in_range": float(si["len"]) <= rng, "from": from}



func danger_cells(country_id: int) -> Array:
        return brain.cells_of(country_id)





func target_fac(p: Vector2) -> Facility:
        var cell: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
        var best: Facility = null
        var bd: int = 1 << 30
        for f: Facility in facilities:
                if f.is_line() or f.moving:
                        continue
                var r: = Rect2i(f.cell, f.size)
                if not r.grow(2).has_point(cell):
                        continue
                var top: Facility = f.parent if f.parent != null else f
                var qx: int = clampi(cell.x, r.position.x, r.end.x - 1)
                var qy: int = clampi(cell.y, r.position.y, r.end.y - 1)
                var d2: int = (qx - cell.x) * (qx - cell.x) + (qy - cell.y) * (qy - cell.y)
                if d2 < bd:
                        bd = d2
                        best = top
        return best







func can_strike_target(f: Facility, attacker_cid: int, cls: String = "") -> bool:
        if f == null:
                return true
        if f.parent != null:
                f = f.parent
        var hum: Country = gw.country_by_id(f.country_id)
        if hum == null or not hum.is_player or attacker_cid == hum.id:
                return true
        var e: Array = tgt_cd.get(f.id, [])
        var now: float = gw.game_time
        if e.size() >= 5 and int(e[3]) == attacker_cid and now - float(e[0]) <= TARGET_SALVO and String(e[4]) == cls:
                return true
        var pst: float = float(_ply_strike.get(hum.id, -999.0))
        if now - pst < NEW_WAR_GAP and now - pst > TARGET_SALVO and gw.diplo != null and gw.diplo.war_time(hum.id, attacker_cid) < NEW_WAR_T:
                return false
        if e.size() < 5:
                return true
        if int(e[2]) == 1 and now - float(e[0]) < TARGET_FLY_MAX:
                return false
        return now - maxf(float(e[0]), float(e[1])) >= TARGET_CD



func note_strike(f: Facility, attacker_cid: int, cls: String = "") -> void :
        if f == null:
                return
        if f.parent != null:
                f = f.parent
        var hum: Country = gw.country_by_id(f.country_id)
        if hum == null or not hum.is_player or attacker_cid == hum.id:
                return
        var e: Array = tgt_cd.get(f.id, [])
        var now: float = gw.game_time
        if now - float(_ply_strike.get(hum.id, -999.0)) > TARGET_SALVO:
                _ply_strike[hum.id] = now
        if e.size() >= 5 and int(e[3]) == attacker_cid and now - float(e[0]) <= TARGET_SALVO and String(e[4]) == cls:
                e[2] = 1
                return
        tgt_cd[f.id] = [now, float(e[1]) if e.size() >= 5 else -1000.0, 1, attacker_cid, cls]
        if tgt_cd.size() > 48:
                for k: Variant in tgt_cd.keys():
                        var a: Array = tgt_cd[k]
                        if now - maxf(float(a[0]), float(a[1])) > TARGET_FLY_MAX * 2.0:
                                tgt_cd.erase(k)



func note_impact(f: Facility, attacker_cid: int) -> void :
        if f == null:
                return
        if f.parent != null:
                f = f.parent
        var hum: Country = gw.country_by_id(f.country_id)
        if hum == null or not hum.is_player or attacker_cid == hum.id:
                return
        var e: Array = tgt_cd.get(f.id, [])
        if e.size() < 5:
                tgt_cd[f.id] = [gw.game_time, gw.game_time, 0, attacker_cid, ""]
                return
        e[1] = gw.game_time
        e[2] = 0




func spread_target(attacker_cid: int, avoid: Facility, from: Vector2, max_d: float, cls: String = "") -> Facility:
        if avoid == null:
                return null
        var best: Facility = null
        var bs: float = - INF
        for f: Facility in facilities:
                if f == avoid or f.country_id != avoid.country_id or f.parent != null or f.is_line() or f.moving or not alive(f):
                        continue
                var p: Vector2 = f.center_px()
                var d: float = p.distance_to(from)
                if d > max_d or not can_strike_target(f, attacker_cid, cls):
                        continue
                var n: Variant = Facility.Kind.find_key(f.kind)
                var sc: float = float(SPREAD_W.get(n, 1.0)) * 1000.0 - d * 0.1
                if sc > bs:
                        bs = sc
                        best = f
        if best == null:
                tgt_refused += 1
        else:
                tgt_redirect += 1
        return best










func ai_missile_strike(country: Country, target: Vector2, hyper: bool = false) -> bool:
        if not _ai_strike_ok(country, target):
                return false
        if hyper:
                return air.ai_air_strike(country, target, true)
        var free: int = 0
        for f: Facility in tels_for(country, target):
                free += maxi(0, f.missiles - f.queued.size())
        if free <= 0:
                return false
        return launch_missiles(country, target, 1) > 0





func ai_cruise_strike(country: Country, target: Vector2) -> bool:
        if not _ai_strike_ok(country, target):
                return false
        return air.ai_air_strike(country, target, false)




func strike_worth(p: Vector2, attacker_cid: int, r: int = 5) -> bool:
        var tf: Facility = target_fac(p)
        if tf != null and alive(tf) and hostile(attacker_cid, tf.country_id):
                return true
        var cell: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
        var box: = Rect2i(cell - Vector2i(r + 6, r + 6), Vector2i(2 * r + 12, 2 * r + 12))
        for ck: ObjChunk in gw.objects.chunks_in_rect(box):
                for id in ck.ids:
                        if gw.obj_state[id] != 0 or gw.obj_kind[id] != GameWorld.KIND_BUILDING:
                                continue
                        var rr: Rect2i = gw.object_rect(id)
                        var qx: int = clampi(cell.x, rr.position.x, rr.end.x - 1)
                        var qy: int = clampi(cell.y, rr.position.y, rr.end.y - 1)
                        if (qx - cell.x) * (qx - cell.x) + (qy - cell.y) * (qy - cell.y) > r * r:
                                continue
                        if gw.data.inside(qx, qy) and hostile(attacker_cid, gw.data.get_owner_id(qx, qy)):
                                return true
        return false





func city_aim(city: City, attacker_cid: int, avoid: Array, salt: int) -> Vector2:
        var r: int = clampi(city.radius, 8, 40)
        var box: = Rect2i(city.center - Vector2i(r, r), Vector2i(2 * r + 1, 2 * r + 1))
        var cand: Array = []
        var cpx: = Vector2(city.center * GameWorld.CELL)
        for ck: ObjChunk in gw.objects.chunks_in_rect(box):
                for id in ck.ids:
                        if gw.obj_state[id] != 0 or gw.obj_kind[id] != GameWorld.KIND_BUILDING:
                                continue
                        var rr: Rect2i = gw.object_rect(id)
                        if not box.has_point(rr.position) or gw.data.get_owner_id(rr.position.x, rr.position.y) != city.country_id:
                                continue
                        var p: = Vector2(rr.position * GameWorld.CELL) + Vector2(rr.size * GameWorld.CELL) * 0.5
                        var near: bool = false
                        for q: Vector2 in avoid:
                                if q.distance_to(p) < STRIKE_SPOT_R:
                                        near = true
                                        break
                        if not near:
                                cand.append([p.distance_squared_to(cpx), p])
        if cand.is_empty() or not hostile(attacker_cid, city.country_id):
                return Vector2.INF
        cand.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
        return cand[Hash32.h2(attacker_cid, salt, city.id) % mini(6, cand.size())][1]


func _ai_strike_ok(country: Country, target: Vector2) -> bool:
        if country == null or country.eliminated:
                return false
        var cell: = Vector2i(floori(target.x / GameWorld.CELL), floori(target.y / GameWorld.CELL))
        if not gw.data.inside(cell.x, cell.y):
                return false
        var v: int = gw.data.get_owner_id(cell.x, cell.y)
        return v > 0 and hostile(country.id, v)


func save_state() -> Dictionary:
        return {"m": Save.dump(self, ["_plan_cache_key", "_plan_cache", "drive_dir", "stale_drop", "_roam_jobs"]), "air": Save.dump(air), "brain": brain.save_state()}


func load_state(d: Dictionary) -> void :
        Save.fill(self, d.get("m", {}), ["_roam_jobs"])
        _roam_jobs = {}
        Save.fill(air, d.get("air", {}))
        brain.load_state(d.get("brain", {}))
        _plan_cache_key = ""
        for f: Facility in facilities:
                f.fx = []
                if (f.kind == Facility.Kind.POWER_PLANT or f.kind == Facility.Kind.REFINERY or f.kind == Facility.Kind.NUCLEAR_PLANT) and alive(f):
                        _ambient_fx(f)
        forts_changed.emit()
