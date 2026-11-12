extends RefCounted

# Парити-бенчмарк df_native v2: spot_all / valid_one / rockets_step /
# smoke_at / occupy_candidates против GDScript-эталонов.
# Запуск: godot --headless --path . --bench-nat2  (BENCH_UNITS=250)

const EPS: float = 1e-6


func run(main: Node) -> void:
        var tree: SceneTree = main.get_tree()
        for i in range(100):
                if main.world != null and main.world.data != null and not main.world.cities.is_empty():
                        break
                await tree.create_timer(0.2).timeout
        await tree.create_timer(1.0).timeout
        var w: GameWorld = main.world
        Engine.max_fps = 0
        w._landmasses()
        var c: Vector2i = w._find_capital_spot(-1)
        if c.x >= 0:
                w.place_player_capital(c)
        main._set_mode(0)
        main.in_menu = false
        var per: int = int(OS.get_environment("BENCH_UNITS")) if OS.get_environment("BENCH_UNITS") != "" else 250
        var bl: RefCounted = (load("res://dev/bench_late.gd") as GDScript).new()
        bl.call("_stress", w, per)
        # разогрев боя: дымы, окопы, ракеты
        var t0: int = Time.get_ticks_usec()
        var warm_s: float = float(OS.get_environment("BENCH_WARM_S")) if OS.get_environment("BENCH_WARM_S") != "" else 150.0
        while w.game_time < warm_s and float(Time.get_ticks_usec() - t0) / 1e6 < 60.0:
                await tree.process_frame
                w.time_scale = 6000.0
        w.time_scale = 0.0
        await tree.process_frame
        var army: Army = w.army
        var fire = army.fire
        if army._nat == null:
                print("[NAT2] FAIL: натив не подключен — проверь addons/df_native")
                main.get_tree().quit(1)
                return
        print("[NAT2] game=", int(w.game_time), "s units=", army.units.size(), " rockets=", army.rockets.size(), " smokes: army=", army.smokes.size(), " ops=", w.ops.zones.size() if w.ops != null else -1)
        # синтетические дымы вокруг центра боя — покрывают дымовые ветки
        var ctr: Vector2 = Vector2.ZERO
        var cnt: int = 0
        for u2: Unit in army.units:
                if u2.alive():
                        ctr += u2.pos
                        cnt += 1
        if cnt > 0:
                ctr /= float(cnt)
                for i in 3:
                        var q: Vector2 = ctr + Vector2(float(i) * 40.0 - 40.0, float(i) * 55.0)
                        army.smokes.append([q, w.game_time + 9999.0])
                if w.ops != null:
                        w.ops.zones.append({"k": Operations.Order.SMOKE, "c": 0, "pos": ctr + Vector2(-60.0, -30.0), "r": 55.0, "until": w.game_time + 9999.0, "fx": []})
        army._nat_push_smokes()
        army._nat_sync()

        var total_mism: int = 0
        # ——— 1. spot: 3 среза боя — GDScript-эталон против натива
        for it in 3:
                army._nat_push_smokes()
                army._nat_sync()
                var eyes: Dictionary = fire._spot_eyes()
                var ref_spotted: Dictionary = {}
                var ref_seen: Dictionary = {}
                _spot_ref(army, fire, eyes, ref_spotted, ref_seen)
                fire.spotted.clear()
                fire.seen.clear()
                var ok: bool = fire._spot_native(eyes)
                if not ok:
                        print("[NAT2] spot iter=", it, ": native отказался (hm == -1) — FAIL")
                        total_mism += 1
                        continue
                var m: int = _cmp_spot(ref_spotted, ref_seen, fire.spotted, fire.seen)
                total_mism += m
                print("[NAT2] spot iter=", it, ": mismatches=", m, " cids=", eyes.keys().size())
        # ——— 2. valid_one против _valid_gd (юнит-цели)
        var vm: int = 0
        var vn: int = 0
        for u: Unit in army.units:
                if not u.alive() or u.target == null or not (u.target is Unit):
                        continue
                var tu: Unit = u.target
                var grd: bool = w.diplo != null and w.diplo.rq != null and w.diplo.rq.guarding(u.country_id)
                if grd or army._hmask(u.country_id) == -1:
                        continue
                var ref_v: bool = army._valid_gd(u, tu)
                var nat_v: bool = army._nat.valid_one(u.pos.x, u.pos.y, tu.pos.x, tu.pos.y, tu.country_id, army.range_of(u) * 1.15, army._hmask(u.country_id)) and tu.alive()
                vn += 1
                if ref_v != nat_v:
                        vm += 1
                        if vm <= 5:
                                print("[NAT2]   valid mismatch: unit=", u.id, " tgt=", tu.id, " ref=", ref_v, " nat=", nat_v)
        total_mism += vm
        print("[NAT2] valid: pairs=", vn, " mismatches=", vm)
        # ——— 3. rockets_step против GDScript-математики
        var rm: int = 0
        var rn: int = 0
        var dt: float = 0.033
        if not army.rockets.is_empty():
                var px := PackedFloat64Array()
                var py := PackedFloat64Array()
                var hd := PackedFloat64Array()
                var lf := PackedFloat64Array()
                var sp := PackedFloat64Array()
                var tn := PackedFloat64Array()
                var tx := PackedFloat64Array()
                var ty := PackedFloat64Array()
                var tr := PackedFloat64Array()
                for r: Dictionary in army.rockets:
                        var pos: Vector2 = r["pos"]
                        px.append(pos.x)
                        py.append(pos.y)
                        hd.append(float(r["heading"]))
                        lf.append(float(r["life"]))
                        sp.append(float(Army.ROCKET_SPEED[r["kind"]]))
                        tn.append(PI * 1.2 if r["kind"] == "atgm" else PI * 0.3)
                        var tgt: Object = r["target"]
                        var tp: Vector2 = army._target_pos(tgt, pos)
                        tx.append(tp.x)
                        ty.append(tp.y)
                        tr.append(float(r["trail"]))
                var res: PackedFloat64Array = army._nat.rockets_step(dt, px, py, hd, lf, sp, tn, tx, ty, tr)
                rn = army.rockets.size()
                for i in rn:
                        # GDScript-эталон (чистая математика, как _update_rockets_gd)
                        var st_ref: int = 0
                        if lf[i] - dt <= 0.0:
                                st_ref = 2
                        else:
                                var to: Vector2 = Vector2(tx[i] - px[i], ty[i] - py[i])
                                var turn: float = tn[i] * dt
                                var nh: float = wrapf(hd[i] + clampf(wrapf(to.angle() - hd[i], -PI, PI), -turn, turn), -PI, PI)
                                var step: float = sp[i] * dt
                                if to.length() <= step + 2.0:
                                        st_ref = 1
                                        if absf(nh - res[i * 8 + 1]) > EPS:
                                                rm += 1
                                else:
                                        var np: Vector2 = Vector2(px[i], py[i]) + Vector2.from_angle(nh) * step
                                        if absf(nh - res[i * 8 + 1]) > EPS or absf(np.x - res[i * 8 + 2]) > 1e-3 or absf(np.y - res[i * 8 + 3]) > 1e-3:
                                                rm += 1
                                                if rm <= 5:
                                                        print("[NAT2]   rocket mismatch: ref_h=", nh, " nat_h=", res[i * 8 + 1], " ref_p=", np, " nat_p=", Vector2(res[i * 8 + 2], res[i * 8 + 3]))
                        if int(res[i * 8]) != st_ref:
                                rm += 1
                                if rm <= 5:
                                        print("[NAT2]   rocket status mismatch: ref=", st_ref, " nat=", int(res[i * 8]))
        total_mism += rm
        print("[NAT2] rockets: n=", rn, " mismatches=", rm)
        # ——— 4. smoke_at против чистого GDScript
        var sm: int = 0
        var sn: int = 0
        for u3: Unit in army.units:
                if not u3.alive():
                        continue
                sn += 1
                var ref_s: bool = _smoke_ref(w, army, u3.pos)
                if ref_s != army._nat.smoke_at(u3.pos.x, u3.pos.y):
                        sm += 1
                        if sm <= 5:
                                print("[NAT2]   smoke mismatch at ", u3.pos)
        total_mism += sm
        print("[NAT2] smoke: points=", sn, " mismatches=", sm)
        # ——— 5. occupy_candidates против полного GDScript-фильтра (базовые условия)
        var om: int = 0
        var oc: int = 0
        for cc: Country in w.countries:
                var nat_res: PackedInt32Array = army._nat.occupy_candidates(cc.id)
                var nat_ids: Dictionary = {}
                for k in range(1, nat_res.size()):
                        nat_ids[nat_res[k]] = true
                var posted_nat: int = nat_res[0]
                var posted_ref: int = 0
                var ref_ids: Dictionary = {}
                for u4: Unit in army.units:
                        if u4.country_id == cc.id and u4.alive() and u4.post != null:
                                posted_ref += 1
                        if u4.country_id == cc.id and u4.alive() and u4.post == null and (u4.type == Unit.Type.INFANTRY or u4.type == Unit.Type.ATGM or u4.type == Unit.Type.ASSAULT) and u4.state != Unit.State.SIEGE and u4.reinf == 0:
                                ref_ids[u4.id] = true
                                if not nat_ids.has(u4.id):
                                        om += 1
                                        if om <= 5:
                                                print("[NAT2]   occupy: native пропустил юнит ", u4.id)
                        elif nat_ids.has(u4.id):
                                om += 1
                                if om <= 5:
                                        print("[NAT2]   occupy: native лишний юнит ", u4.id)
                if posted_nat != posted_ref:
                        om += 1
                        print("[NAT2]   occupy posted: nat=", posted_nat, " ref=", posted_ref)
                oc += ref_ids.size()
        total_mism += om
        print("[NAT2] occupy: candidates=", oc, " mismatches=", om)
        print("[NAT2] TOTAL mismatches=", total_mism)
        if total_mism == 0:
                print("[NAT2] PASS")
        else:
                print("[NAT2] FAIL")
                main.get_tree().quit(1)
                return
        # ——— замеры: spot GDScript vs native (на текущем бое)
        var reps: int = 20
        var eyes2: Dictionary = fire._spot_eyes()
        var ref_sp: Dictionary = {}
        var ref_sn: Dictionary = {}
        var ts: int = Time.get_ticks_usec()
        for r2 in range(reps):
                _spot_ref(army, fire, eyes2, ref_sp, ref_sn)
        var t_ref: float = float(Time.get_ticks_usec() - ts) / 1000.0 / float(reps)
        ts = Time.get_ticks_usec()
        for r3 in range(reps):
                fire.spotted.clear()
                fire.seen.clear()
                fire._spot_native(eyes2)
        var t_nat: float = float(Time.get_ticks_usec() - ts) / 1000.0 / float(reps)
        print("[NAT2] spot per pass: gdscript=%.2f ms  native=%.2f ms  speedup x%.2f" % [t_ref, t_nat, t_ref / maxf(0.001, t_nat)])
        main.get_tree().quit()


# Копия GDScript-тела _spot (эталон) — пишет в переданные словари.
# Чистый GDScript: дым — локальная функция, константы — из fire.
func _spot_ref(army: Army, fire, eyes: Dictionary, ref_spotted: Dictionary, ref_seen: Dictionary) -> void:
        var gw: GameWorld = army.gw
        var recon_r: float = fire.RECON_R
        var mil_kinds: Array = fire.MIL_KINDS
        for cid: int in eyes:
                var ey: Array = eyes[cid]
                var hostility: Dictionary = {}
                var box: = Rect2((ey[0][0] as Vector2), Vector2.ZERO)
                for e: Array in ey:
                        box = box.expand(e[0])
                box = box.grow(recon_r)
                var list: Array = []
                for o: Unit in army.units:
                        if not o.alive() or o.air() or o.country_id == cid or not box.has_point(o.pos):
                                continue
                        if not hostility.has(o.country_id):
                                hostility[o.country_id] = army._hostile(cid, o.country_id)
                        if not hostility[o.country_id]:
                                continue
                        if _smoke_ref(gw, army, o.pos):
                                continue
                        var hid: bool = o.entrenched
                        for e2: Array in ey:
                                if o.pos.distance_squared_to(e2[0]) <= (minf(float(e2[1]), 54.0 * 54.0) if hid and not bool(e2[2]) else float(e2[1])):
                                        list.append([o.pos, o, bool(e2[2])])
                                        break
                if gw.naval != null:
                        list.append_array(gw.naval.spotted_for(cid, ey))
                var mil = gw.mil
                for f in mil.facilities:
                        if f.parent != null or not mil_kinds.has(f.kind) or f.moving:
                                continue
                        if not hostility.has(f.country_id):
                                hostility[f.country_id] = army._hostile(cid, f.country_id)
                        if not hostility[f.country_id]:
                                continue
                        var fc: Vector2 = f.center_px()
                        var ext: float = float(maxi(f.size.x, f.size.y)) * 2.0 + (float(f.cells.size()) * 2.0 if f.is_line() else 0.0)
                        if not box.grow(ext).has_point(fc) or not mil.alive(f):
                                continue
                        var hid2: bool = Army.is_trench(f.kind)
                        for e3: Array in ey:
                                var tp: Vector2 = mil.line_point(f, e3[0]) if f.is_line() else fc
                                if tp.distance_squared_to(e3[0]) <= (minf(float(e3[1]), 54.0 * 54.0) if hid2 and not bool(e3[2]) else float(e3[1])):
                                        list.append([tp, f, bool(e3[2])])
                                        break
                        if list.size() > 60:
                                break
                ref_spotted[cid] = list
                var sd: Dictionary = {}
                for e4: Array in list:
                        sd[e4[1]] = true
                ref_seen[cid] = sd


# Чистый GDScript Army.in_smoke (эталон без натива).
func _smoke_ref(gw: GameWorld, army: Army, p: Vector2) -> bool:
        if gw.ops != null and gw.ops.smoke_at(p):
                return true
        for s: Array in army.smokes:
                var d: Vector2 = p - (s[0] as Vector2)
                if d.x * d.x / 256.0 + d.y * d.y / 81.0 <= 1.0:
                        return true
        return false


func _cmp_spot(ref_spotted: Dictionary, ref_seen: Dictionary, nat_spotted: Dictionary, nat_seen: Dictionary) -> int:
        var m: int = 0
        for cid: int in ref_spotted:
                var ra: Array = ref_spotted[cid]
                var na: Array = nat_spotted.get(cid, [])
                if ra.size() != na.size():
                        m += 1
                        if m <= 5:
                                print("[NAT2]   spot size mismatch cid=", cid, " ref=", ra.size(), " nat=", na.size())
                        continue
                for i in ra.size():
                        var ro: Array = ra[i]
                        var no: Array = na[i]
                        if ro[1] != no[1] or bool(ro[2]) != bool(no[2]):
                                m += 1
                                if m <= 5:
                                        print("[NAT2]   spot entry mismatch cid=", cid, " i=", i, " ref_obj=", ro[1], " nat_obj=", no[1], " recon ", ro[2], "/", no[2])
                        var rp: Vector2 = ro[0]
                        var np: Vector2 = no[0]
                        if rp.distance_squared_to(np) > 1e-8:
                                m += 1
                                if m <= 5:
                                        print("[NAT2]   spot pos mismatch cid=", cid, " i=", i, " ref=", rp, " nat=", np)
                if ref_seen[cid].size() != nat_seen.get(cid, {}).size():
                        m += 1
                        if m <= 5:
                                print("[NAT2]   seen size mismatch cid=", cid)
        return m
