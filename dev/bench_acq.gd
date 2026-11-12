extends RefCounted

# Проверка эквивалентности и замер: GDScript юнит-пасс (_acq_units_gd,
# эталон parity) против нативного Rust-пути (DfNative.acquire_one).

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
        # даём разгореться боям (дымы, смерти, смены целей)
        var t0: int = Time.get_ticks_usec()
        while w.game_time < float(OS.get_environment("BENCH_GAME_S") if OS.get_environment("BENCH_GAME_S") != "" else "150") and float(Time.get_ticks_usec() - t0) / 1e6 < 60.0:
                await tree.process_frame
                w.time_scale = 6000.0
        w.time_scale = 0.0
        await tree.process_frame
        var army: Army = w.army
        print("[ACQ] game=", int(w.game_time), "s units=", army.units.size(), " native=", army._nat != null)
        if army._nat == null:
                print("[ACQ] FAIL: натив не подключен — проверь addons/df_native")
                main.get_tree().quit(1)
                return
        # Виты покрытия дымовых веток: синтетические дымы (армия: эллипс 16x9;
        # операции: круг r) вокруг центра боя — часть ищущих и целей в дыму.
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
        army._build_grid()
        # какие юниты участвуют (как в update: живые, не FPV, не артиллерия)
        var pool: Array = []
        for u: Unit in army.units:
                if u.alive() and u.type != Unit.Type.FPV and not u.indirect():
                        pool.append(u)
        print("[ACQ] pool=", pool.size(), " grid cells=", army._grid.size(), " smokes: army=", army.smokes.size(), " ops=", w.ops.zones.size() if w.ops != null else -1)
        # эквивалентность: GDScript юнит-пасс против натива
        var mism: int = 0
        var with_ref: int = 0
        var nat_unavail: int = 0
        for u: Unit in pool:
                var r: float = army.range_of(u)
                var at: bool = u.type == Unit.Type.ATGM
                var blind: bool = army.in_smoke(u.pos)
                var hm: int = army._hmask(u.country_id)
                var upos: Vector2 = u.pos
                u.target = null
                var ref_obj: Object = army._acq_units_gd(u, r, at, blind, u.country_id, upos, hm, false)
                var nid: int = army._nat.acquire_one(u.id, r, hm, at, blind)
                var nat_obj: Object = null
                if nid == -2:
                        nat_unavail += 1
                elif nid >= 0:
                        nat_obj = army._nat_u.get(nid)
                if ref_obj != nat_obj:
                        mism += 1
                        if mism <= 5:
                                print("[ACQ]   mismatch: unit=", u.id, " type=", u.type, " ref=", ref_obj, " nat=", nid)
                if ref_obj != null:
                        with_ref += 1
        print("[ACQ] equivalence: mismatches=", mism, " units_with_target=", with_ref, " nat_unavail=", nat_unavail, " of ", pool.size())
        # замер
        var reps: int = 30
        var ts: int = Time.get_ticks_usec()
        for r2 in range(reps):
                for u2: Unit in pool:
                        var rr: float = army.range_of(u2)
                        var at2: bool = u2.type == Unit.Type.ATGM
                        var bl2: bool = army.in_smoke(u2.pos)
                        var hm2: int = army._hmask(u2.country_id)
                        army._acq_units_gd(u2, rr, at2, bl2, u2.country_id, u2.pos, hm2, false)
        var t_ref: float = float(Time.get_ticks_usec() - ts) / 1000.0 / float(reps)
        ts = Time.get_ticks_usec()
        for r3 in range(reps):
                for u3: Unit in pool:
                        var rr3: float = army.range_of(u3)
                        var at3: bool = u3.type == Unit.Type.ATGM
                        var hm3: int = army._hmask(u3.country_id)
                        army._nat.acquire_one(u3.id, rr3, hm3, at3, army.in_smoke(u3.pos))
        var t_nat: float = float(Time.get_ticks_usec() - ts) / 1000.0 / float(reps)
        print("[ACQ] per full pass: gdscript=%.2f ms  native=%.2f ms  speedup x%.2f" % [t_ref, t_nat, t_ref / maxf(0.001, t_nat)])
        main.get_tree().quit()
