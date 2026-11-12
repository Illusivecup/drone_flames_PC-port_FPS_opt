extends SceneTree
## bench_candy — паритет и производительность df_rust.
## Запуск: godot --headless --path . -s res://dev/bench_candy.gd

func _initialize() -> void:
        print("=== bench_candy: df_rust parity + spatial hash ===")
        var has_candy: bool = ClassDB.class_exists("DfFlyingCandy")
        var has_hash: bool = ClassDB.class_exists("DfSpatialHash2D")
        print("DfFlyingCandy available: ", has_candy, " | DfSpatialHash2D available: ", has_hash)

        var ok_path := true
        if has_candy:
                var c: Variant = ClassDB.instantiate("DfFlyingCandy")
                c.set("start", Vector2(-620.0, 40.0))
                c.set("end", Vector2(620.0, -24.0))
                var gd: Variant = (load("res://game/flying_candy_gd.gd") as GDScript).new()
                gd.set("start", c.get("start"))
                gd.set("end", c.get("end"))
                for i in 11:
                        var k: float = float(i) / 10.0
                        var a: Vector2 = c.call("path_point", k)
                        var b: Vector2 = gd.path_point(k)
                        if a.distance_to(b) > 0.001:
                                ok_path = false
                                print("  MISMATCH k=", k, " rust=", a, " gd=", b)
                c.free()
                gd.free()
        print("parity path_point (rust vs gdscript): ", "OK" if ok_path else "FAIL")

        var N: int = 250
        var Q: int = 3000
        var rng := RandomNumberGenerator.new()
        rng.seed = 424242
        var pts := PackedVector2Array()
        for i in N:
                pts.append(Vector2(rng.randf_range(0.0, 1024.0), rng.randf_range(0.0, 1024.0)))
        var queries: Array = []
        for i in Q:
                queries.append([Vector2(rng.randf_range(0.0, 1024.0), rng.randf_range(0.0, 1024.0)), rng.randf_range(40.0, 240.0)])

        var t0: int = Time.get_ticks_usec()
        var dt_us: int = 0
        var hits_rust: int = -1
        if has_hash:
                var hash_obj: Variant = ClassDB.instantiate("DfSpatialHash2D")
                hash_obj.setup(128.0)
                for i in N:
                        hash_obj.insert(i + 1, pts[i], 1)
                hits_rust = 0
                for q: Array in queries:
                        if int(hash_obj.nearest(q[0], q[1], 1, -1)) > 0:
                                hits_rust += 1
                dt_us = Time.get_ticks_usec() - t0
                print("rust DfSpatialHash2D: %d nearest-запросов за %d мс (hits=%d, size=%d)" % [Q, dt_us / 1000, hits_rust, hash_obj.size()])
                hash_obj = null # RefCounted освобождается сам

        t0 = Time.get_ticks_usec()
        var hits_gd: int = 0
        for q: Array in queries:
                var bd: float = q[1] * q[1]
                var best: int = -1
                for i in N:
                        var d2: float = pts[i].distance_squared_to(q[0])
                        if d2 <= bd:
                                best = i + 1
                                bd = d2
                if best > 0:
                        hits_gd += 1
        var dt2: int = Time.get_ticks_usec() - t0
        print("gdscript линейный:    %d nearest-запросов за %d мс (hits=%d)" % [Q, dt2 / 1000, hits_gd])

        if hits_rust >= 0 and hits_rust != hits_gd:
                print("PARITY MISMATCH в hits: rust=", hits_rust, " gd=", hits_gd)
        elif hits_rust >= 0:
                print("parity hits: OK, ускорение = %.1fx" % [float(dt2) / float(maxi(1, dt_us))])
        print("=== done ===")
        quit(0)
