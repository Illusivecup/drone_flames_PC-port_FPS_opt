extends "res://game/economy/eco_base.gd"


static func site_text(code: String) -> String:
        return Loc.t(String(LOC_SITE.get(code, code)))



static func site_code(s: String) -> String:
        for k: String in LOC_SITE:
                if String(LOC_SITE[k]) == s:
                        return k
        return s


static func is_enterprise(kind: int) -> bool:
        return kind == Facility.Kind.FARM or kind == Facility.Kind.CIV_FACTORY or kind == Facility.Kind.MINE\
        or kind == Facility.Kind.SAWMILL or kind == Facility.Kind.OIL_RIG or kind == Facility.Kind.URANIUM_MINE


func generate_deposits() -> void :
        deposits.clear()
        var d: WorldData = gw.data
        var r: = Rng.new(d.world_seed + 7777)
        var base_n: int = maxi(8, d.w * d.h / (DEPOSIT_SPACING * DEPOSIT_SPACING) / 2)
        var bag: Array[String] = []
        for res: String in ORE_WEIGHT:
                var lv: int = GameConfig.ore_level(res)
                var n: int = roundi(float(base_n) * float(ORE_WEIGHT[res]) * float(ORE_COUNT_MUL[lv]))
                if lv > 0:
                        n = maxi(n, 1)
                for i in n:
                        bag.append(res)
        for i in range(bag.size() - 1, 0, -1):
                var j: int = r.range_i(i + 1)
                var tmp: String = bag[i]
                bag[i] = bag[j]
                bag[j] = tmp
        var spacing: int = maxi(14, int(float(DEPOSIT_SPACING) * 0.6 / sqrt(maxf(0.3, float(bag.size()) / float(base_n)))))
        for res: String in bag:
                var lv2: int = GameConfig.ore_level(res)
                for t in 40:
                        var c: = Vector2i(r.range_ab(8, d.w - 8), r.range_ab(8, d.h - 8))
                        if not _deposit_spot_ok(c, spacing, -1):
                                continue
                        var small: bool = r.range_i(100) < int(ORE_SMALL[lv2])
                        add_deposit(c, res, small, int(float(DEP_AMOUNT[res]) * (0.4 if small else 1.0) * float(ORE_AMOUNT_MUL[lv2])))
                        break
        generate_uranium()
        ports.ensure_sea()
        if gw.get("navy") != null:
                gw.navy._ensure_nav()





func generate_uranium(owner_free: bool = false) -> void :
        u_seeded = true
        var lv: int = GameConfig.ore_level("uranium")
        if lv <= 0:
                return
        var d: WorldData = gw.data
        var r: = Rng.new(d.world_seed + 30030)
        var base_n: int = maxi(8, d.w * d.h / (DEPOSIT_SPACING * DEPOSIT_SPACING) / 2)
        var n: int = maxi(Nuclear.U_MIN_DEP, roundi(float(base_n) * Nuclear.U_WEIGHT * float(ORE_COUNT_MUL[lv])))
        n = mini(n, 4 + 3 * maxi(1, GameConfig.bots + 1))
        var spacing: int = maxi(30, int(float(DEPOSIT_SPACING) * 1.2))
        var placed: int = 0
        for t in n * 60:
                if placed >= n:
                        break
                var c: = Vector2i(r.range_ab(10, d.w - 10), r.range_ab(10, d.h - 10))
                if not _deposit_spot_ok(c, 14, 0 if owner_free and t < n * 40 else -1):
                        continue
                var far: bool = true
                for dp: Dictionary in deposits:
                        if String(dp.get("res", "")) == "uranium" and (dp["cell"] as Vector2i).distance_to(c) < float(spacing):
                                far = false
                                break
                if not far:
                        continue
                var small: bool = r.range_i(100) < int(ORE_SMALL[lv])
                add_deposit(c, "uranium", small, int(float(DEP_AMOUNT["uranium"]) * (0.4 if small else 1.0) * float(ORE_AMOUNT_MUL[lv])))
                placed += 1


func _deposit_spot_ok(c: Vector2i, spacing: int, owner: int) -> bool:
        var d: WorldData = gw.data
        for dy in range(-2, 3):
                for dx in range(-2, 3):
                        var x: int = c.x + dx
                        var y: int = c.y + dy
                        if not d.inside(x, y):
                                return false
                        if not Biome.is_natural_land(d.get_biome(x, y)) or d.has_flag(x, y, WorldData.F_ROAD | WorldData.F_OCCUPIED | WorldData.F_CITY | WorldData.F_BRIDGE):
                                return false
                        if gw.get("rail") != null and gw.rail.has_rail(Vector2i(x, y)):
                                return false
                        if owner >= 0:
                                var o: int = d.get_owner_id(x, y)
                                if o != 0 and o != owner:
                                        return false
        for dp: Dictionary in deposits:
                if (dp["cell"] as Vector2i).distance_to(c) < spacing:
                        return false
        return true


func add_deposit(c: Vector2i, res: String, small: bool, amount: int) -> Dictionary:
        amount = roundi(float(amount) * GameConfig.reserve_mul())
        var nm: String = String(DEP_SPRITE[res][1 if small else 0])
        var sz: int = 2 if small else 3
        var nw: Vector2i = c - Vector2i(sz / 2, sz / 2)
        for yy in range(nw.y, nw.y + sz):
                for xx in range(nw.x, nw.x + sz):
                        gw.remove_tree_at(Vector2i(xx, yy))
        var id: int = gw.add_object(nm, nw, GameWorld.KIND_PROP)
        var dp: Dictionary = {"cell": c, "obj": id, "small": small, "mine": null, "res": res, "left": amount, "max": amount, "size": sz}
        deposits.append(dp)
        draw_ver += 1
        return dp




func on_capital(c: Country, cap: City) -> void :
        if c.metal == 0 and c.wood == 0:
                c.metal = START_METAL
                c.wood = START_WOOD

        for dp: Dictionary in deposits.duplicate():
                var dc: Vector2i = dp["cell"]
                if dp["mine"] == null and (dc.distance_to(cap.center) < float(cap.radius + 3) or gw.data.has_flag(dc.x, dc.y, WorldData.F_CITY)):
                        _relocate(dp)
        if not scarce.has(c.id):
                _assign_scarce(c)
        _push_scarce_out(c, cap)
        var r: = Rng.new(gw.data.world_seed + cap.center.x * 31 + cap.center.y * 17)
        var a0: float = float(r.range_i(360))
        var k: int = 0
        for res: String in ["metal", "oil", "titanium"]:
                if GameConfig.ore_level(res) == 0 or scarce_of(c).has(res):
                        k += 1
                        continue
                for t in 48:
                        var ang: float = deg_to_rad(a0 + float(k) * 120.0 + float(t) * 23.0)
                        var dist: float = float(cap.radius + 6 + (t % 6) * 3)
                        var cell: Vector2i = cap.center + Vector2i(roundi(cos(ang) * dist), roundi(sin(ang) * dist))
                        if _deposit_spot_ok(cell, 10, c.id) and not _in_scarce_zone(cell, res, c.id):
                                add_deposit(cell, res, true, int(CAP_DEP[res]))
                                break
                k += 1
        _ensure_every_res()



func scarce_of(c: Country) -> Array:
        return (scarce.get(c.id, []) as Array) if c != null else []



func scarce_text(c: Country) -> String:
        var parts: PackedStringArray = PackedStringArray()
        for r: String in scarce_of(c):
                parts.append(Loc.t(String(RES_NAMES.get(r, r)).to_lower()))
        return (Loc.t("нет: %s") % [", ".join(parts)]) if not parts.is_empty() else ""


func _assign_scarce(c: Country) -> void :
        var pool: Array = []
        for res: String in ["titanium", "oil", "precious", "metal"]:
                if GameConfig.ore_level(res) > 0:
                        pool.append(res)
        var out: Array = []
        if pool.size() >= 2:
                var k: int = _scarce_n
                _scarce_n += 1
                var sd: int = gw.data.world_seed
                if c.is_player:

                        var opts: Array = pool.filter( func(r: String) -> bool: return r != "metal")
                        if opts.is_empty():
                                opts = pool
                        out.append(opts[Hash32.h2(sd, c.id, 71) % opts.size()])
                else:

                        var off: int = Hash32.h2(sd, 3, 72) % pool.size()
                        var first: String = pool[(k + off) % pool.size()]
                        if first == "metal" and k % 2 == 0:
                                first = pool[(k + off + 1) % pool.size()]
                        out.append(first)
                        if pool.size() >= 3 and Hash32.h2(sd, c.id, 73) % 100 < 45:
                                var second: String = pool[(k + off + 2) % pool.size()]
                                if second != first and second != "metal":
                                        out.append(second)
        scarce[c.id] = out


func _in_scarce_zone(cell: Vector2i, res: String, except_id: int = -1) -> bool:
        for id: int in scarce_zone:
                if id == except_id or not (scarce.get(id, []) as Array).has(res):
                        continue
                var z: Array = scarce_zone[id]
                var zc: Vector2i = z[0]
                if maxi(absi(zc.x - cell.x), absi(zc.y - cell.y)) <= int(z[1]):
                        return true
        return false



func _push_scarce_out(c: Country, cap: City) -> void :
        var lack: Array = scarce_of(c)
        scarce_zone[c.id] = [cap.center, cap.claim_max + SCARCE_PAD]
        if lack.is_empty():
                return
        var r: = Rng.new(gw.data.world_seed + c.id * 977 + 13)
        for dp: Dictionary in deposits.duplicate():
                if dp["mine"] != null or not lack.has(String(dp.get("res", ""))):
                        continue
                var dc: Vector2i = dp["cell"]
                if not _in_scarce_zone(dc, String(dp["res"])):
                        continue
                var spot: Vector2i = _scarce_spot(String(dp["res"]), r)
                if spot.x < 0:
                        if int(dp["obj"]) >= 0:
                                gw.remove_object(int(dp["obj"]))
                        deposits.erase(dp)
                        draw_ver += 1
                        continue
                _move_deposit(dp, spot)



func _scarce_spot(res: String, r: Rng) -> Vector2i:
        var d: WorldData = gw.data
        for t in 420:
                var q: = Vector2i(r.range_ab(10, d.w - 10), r.range_ab(10, d.h - 10))
                if _in_scarce_zone(q, res):
                        continue
                if not _deposit_spot_ok(q, 22, 0 if t < 300 else -1):
                        continue
                return q
        return Vector2i(-1, -1)


func _move_deposit(dp: Dictionary, to: Vector2i) -> void :
        if int(dp["obj"]) >= 0:
                gw.remove_object(int(dp["obj"]))
        var sz: int = int(dp.get("size", 3))
        var nw: Vector2i = to - Vector2i(sz / 2, sz / 2)
        for yy in range(nw.y, nw.y + sz):
                for xx in range(nw.x, nw.x + sz):
                        gw.remove_tree_at(Vector2i(xx, yy))
        var res: String = String(dp.get("res", "titanium"))
        dp["obj"] = gw.add_object(String(DEP_SPRITE[res][1 if bool(dp.get("small", false)) else 0]), nw, GameWorld.KIND_PROP)
        dp["cell"] = to
        draw_ver += 1




func _ensure_every_res() -> void :
        var r: = Rng.new(gw.data.world_seed + gw.countries.size() * 61 + 5)
        for res: String in ORE_WEIGHT:
                var lv: int = GameConfig.ore_level(res)
                if lv == 0:
                        continue
                var lacked: bool = false
                for id: int in scarce:
                        if (scarce[id] as Array).has(res):
                                lacked = true
                var total: int = 0
                var neutral: int = 0
                for dp: Dictionary in deposits:
                        if String(dp.get("res", "")) != res or int(dp.get("left", 0)) <= 0:
                                continue
                        total += 1
                        var dc: Vector2i = dp["cell"]
                        if dp["mine"] == null and gw.data.get_owner_id(dc.x, dc.y) == 0:
                                neutral += 1
                var add: int = maxi(2 - total, (1 - neutral) if lacked else 0)
                for i in add:
                        var q: Vector2i = _scarce_spot(res, r)
                        if q.x < 0:
                                break
                        add_deposit(q, res, false, int(float(DEP_AMOUNT[res]) * float(ORE_AMOUNT_MUL[lv])))



func deposit_near(cell: Vector2i, r: int = 4, types: Array = []) -> Dictionary:
        var best: Dictionary = {}
        var bd: int = 1 << 30
        for dp: Dictionary in deposits:
                if dp["mine"] != null:
                        continue
                if not types.is_empty() and not types.has(String(dp.get("res", "titanium"))):
                        continue
                var dc: Vector2i = dp["cell"]
                var dd: int = maxi(absi(dc.x - cell.x), absi(dc.y - cell.y))
                if dd <= r and dd < bd:
                        bd = dd
                        best = dp
        return best



func check_site(kind: int, nw: Vector2i, sz: Vector2i, c: Country, parent: Facility) -> String:
        var mid: Vector2i = nw + sz / 2
        match kind:
                Facility.Kind.MINE:
                        if deposit_near(mid, 3, ORE_TYPES).is_empty():
                                return Loc.t("Рудник ставится на месторождение руды (металл, титан, драгметаллы)")
                        return ""
                Facility.Kind.OIL_RIG:
                        if deposit_near(mid, 3, ["oil"]).is_empty():
                                return Loc.t("Нефтевышка ставится на месторождение нефти")
                        return ""
                Facility.Kind.URANIUM_MINE:
                        if deposit_near(mid, 3, ["uranium"]).is_empty():
                                return Loc.t("Урановая шахта ставится на залежь урана (зелёный значок)")
                        return ""
                Facility.Kind.SAWMILL:
                        if count_trees(mid, SAW_R, 1) < SAW_MIN_TREES:
                                return Loc.t("Лесопилке нужен лес рядом (от %d деревьев)") % SAW_MIN_TREES
                Facility.Kind.PORT:
                        if not ports.coastal(nw, sz):
                                return Loc.t("Порт ставится на берегу моря, вплотную к воде")
                Facility.Kind.NAVAL_BASE:
                        if gw.get("navy") != null:
                                var nwhy: String = gw.navy.site_why(nw, sz)
                                if nwhy != "":
                                        return nwhy
                Facility.Kind.PORT_CRANE:
                        var p: Facility = parent if parent != null and parent.kind == Facility.Kind.PORT else ports.nearest_port(c, mid)
                        if p == null:
                                return Loc.t("Кран ставится рядом со своим портом (до %d м)") % (Ports.PORT_REACH * GameWorld.CELL)
                        if ports.crane_count(p) >= Ports.MAX_CRANES:
                                return Loc.t("У порта уже %d крана") % Ports.MAX_CRANES

        if not deposit_free_rect(Rect2i(nw, sz)):
                return Loc.t("Здесь месторождение: ставьте рудник или нефтевышку")
        return ""




func bind_site(f: Facility) -> void :
        match f.kind:
                Facility.Kind.MINE, Facility.Kind.OIL_RIG, Facility.Kind.URANIUM_MINE:
                        var dp: Dictionary = deposit_near(f.cell + f.size / 2, 3, ORE_TYPES if f.kind == Facility.Kind.MINE else (["uranium"] if f.kind == Facility.Kind.URANIUM_MINE else ["oil"]))
                        if not dp.is_empty():
                                dp["mine"] = f
                                f.deposit = dp
                                if int(dp["obj"]) >= 0:
                                        gw.remove_object(int(dp["obj"]))
                                        dp["obj"] = -1
                                if f.kind == Facility.Kind.MINE and f.main_obj >= 0:
                                        var res: String = String(dp.get("res", "titanium"))
                                        if res == "metal":
                                                gw.set_obj_frame(f.main_obj, "mine_metal", 0)
                                        elif res == "precious":
                                                gw.set_obj_frame(f.main_obj, "mine_precious", 0)
                Facility.Kind.PORT_CRANE:
                        if f.parent == null:
                                var p: Facility = ports.nearest_port(gw.country_by_id(f.country_id), f.cell + f.size / 2)
                                if p != null:
                                        f.parent = p
                                        p.modules.append(f)
                Facility.Kind.PORT:
                        ports.on_port_built(f)
        draw_ver += 1
        if is_extractor(f.kind):
                _site[f] = {"status": "", "rate": 0, "trees": 0}


static func is_extractor(kind: int) -> bool:
        return kind == Facility.Kind.MINE or kind == Facility.Kind.OIL_RIG or kind == Facility.Kind.SAWMILL or kind == Facility.Kind.URANIUM_MINE



func pay_build(c: Country, kind: int) -> void :
        var rc: Dictionary = res_cost("build_%d" % kind)
        c.pay_res(rc)
        stat_add(c, "spend", "build", Military.cost_of(kind) if Military.COSTS.has(kind) else 0)
        for res: String in rc:
                stat_res(c, res, "build", - int(rc[res]))


func count_trees(mid: Vector2i, r: int, step: int = 1) -> int:
        var d: WorldData = gw.data
        var n: int = 0
        for y in range(maxi(0, mid.y - r), mini(d.h, mid.y + r + 1), step):
                for x in range(maxi(0, mid.x - r), mini(d.w, mid.x + r + 1), step):
                        if gw.tree_at.has(y * d.w + x):
                                n += 1
        return n * step * step




func build_nav() -> void :
        var d: WorldData = gw.data
        var t0: int = Time.get_ticks_msec()
        nav = AStarGrid2D.new()
        _nav_ver += 1
        nav_solid_ver += 1
        _path_cache.clear()
        var gw_n: int = d.w / NAV_K
        var gh_n: int = d.h / NAV_K
        nav.region = Rect2i(0, 0, gw_n, gh_n)
        nav.cell_size = Vector2(NAV_K * GameWorld.CELL, NAV_K * GameWorld.CELL)
        nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
        nav.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
        nav.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
        nav.update()
        nav_soft = AStarGrid2D.new()
        nav_soft.region = nav.region
        nav_soft.cell_size = nav.cell_size
        nav_soft.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
        nav_soft.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
        nav_soft.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
        nav_soft.update()
        nav_dry = AStarGrid2D.new()
        nav_dry.region = nav.region
        nav_dry.cell_size = nav.cell_size
        nav_dry.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
        nav_dry.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
        nav_dry.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
        nav_dry.update()
        # R-FORD: сетка форсирования — клетки рек проходимы (дорогой ценой), море стеною.
        nav_ford = AStarGrid2D.new()
        nav_ford.region = nav.region
        nav_ford.cell_size = nav.cell_size
        nav_ford.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
        nav_ford.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
        nav_ford.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
        nav_ford.update()
        _soft_cache.clear()
        nav_solid_b = PackedByteArray()
        nav_solid_b.resize(gw_n * gh_n)
        for y in gh_n:
                for x in gw_n:
                        _nav_eval(Vector2i(x, y), false)
        # R-FORD: та же terrain-сетка в Rust-движок (детерминированный степпинг).
        FordCore.grid_load(gw)
        print("[Nav] %dx%d in %d ms" % [gw_n, gh_n, Time.get_ticks_msec() - t0])



func _nav_eval(q: Vector2i, _broken: bool) -> void :



        var d: WorldData = gw.data
        var w: int = d.w
        var water: int = 0
        var river: int = 0
        var road: bool = false
        var land_road: bool = false
        var span: bool = false
        var rough: int = 0
        var x0: int = q.x * NAV_K
        var y0: int = q.y * NAV_K
        for yy in range(y0, y0 + NAV_K):
                var row: int = yy * w
                for xx in range(x0, x0 + NAV_K):
                        var i: int = row + xx
                        var b: int = d.biome[i]
                        var fl: int = d.flags[i]
                        if b <= Biome.RIVER:
                                if (fl & WorldData.F_BRIDGE) != 0 and gw.bridge_ok_idx(i):
                                        span = true
                                        road = true
                                else:
                                        water += 1
                                        if b == Biome.RIVER:
                                                river += 1
                                continue
                        if (fl & WorldData.F_ROAD) != 0:
                                road = true
                                land_road = true
                                if not span and _bridgehead(xx, yy):
                                        span = true
                        if b == Biome.FOREST or b == Biome.PINE or b == Biome.HILLS:
                                rough += 1
                        elif b == Biome.ROCK or b == Biome.SNOW:
                                rough += 2


        var solid: bool = water >= 3 and not span and not (land_road and river == 0)
        if nav.is_point_solid(q) != solid:
                nav_solid_ver += 1
        nav.set_point_solid(q, solid)
        var si: int = q.y * nav.region.size.x + q.x
        if si >= 0 and si < nav_solid_b.size():
                nav_solid_b[si] = 1 if solid else 0
        _nav_ver += 1
        if not solid:
                nav.set_point_weight_scale(q, (1.0 if road else 1.6 + float(rough) * 0.125) * (4.0 if blocked.has(q) else 1.0))
        if nav_soft != null:


                var soft_solid: bool = NAV_K * NAV_K - water < SOFT_DRY and not span
                nav_soft.set_point_solid(q, soft_solid)
                var dry_solid: bool = soft_solid or (river > 0 and not span)
                nav_dry.set_point_solid(q, dry_solid)
                if not soft_solid:
                        nav_soft.set_point_weight_scale(q, 1.0 if not (solid or blocked.has(q)) else 4.0)
                if not dry_solid:
                        nav_dry.set_point_weight_scale(q, 1.0 if not (solid or blocked.has(q)) else 4.0)
        # R-FORD: реки проходимы (море — нет), цена растёт с долей воды в ячейке.
        if nav_ford != null:
                var ford_solid: bool = solid and river == 0
                nav_ford.set_point_solid(q, ford_solid)
                if not ford_solid:
                        var base_w: float = 1.0 if road else 1.6 + float(rough) * 0.125
                        if river > 0:
                                base_w += 2.0 + 6.0 * float(water) / float(NAV_K * NAV_K)
                        if blocked.has(q):
                                base_w *= 4.0
                        nav_ford.set_point_weight_scale(q, base_w)



func _bridgehead(x: int, y: int) -> bool:
        var d: WorldData = gw.data
        for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                var xx: int = x + o.x
                var yy: int = y + o.y
                if d.inside(xx, yy) and d.has_flag(xx, yy, WorldData.F_BRIDGE) and gw.bridge_ok_idx(yy * d.w + xx):
                        return true
        return false



func bridge_state(cells: Array[Vector2i], intact: bool) -> void :
        if nav == null:
                return
        var seen: Dictionary = {}
        for c: Vector2i in cells:

                for o: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                        var q: = Vector2i((c.x + o.x) / NAV_K, (c.y + o.y) / NAV_K)
                        if seen.has(q) or not nav.region.has_point(q):
                                continue
                        seen[q] = true
                        _nav_eval(q, not intact)
        # R-FORD: те же клетки в Rust-сетке (мост цел -> суша; разрушен -> река/море).
        var idx: PackedInt32Array = PackedInt32Array()
        var codes: PackedByteArray = PackedByteArray()
        var d: WorldData = gw.data
        for c2: Vector2i in cells:
                if not d.inside(c2.x, c2.y):
                        continue
                var i: int = c2.y * d.w + c2.x
                idx.append(i)
                var b: int = d.biome[i]
                var code: int = 2
                if b == Biome.RIVER:
                        code = 1
                if intact:
                        code = 0
                codes.append(code)
        FordCore.grid_patch(idx, codes)


func block_rect(r: Rect2i, on: bool) -> void :
        if nav == null:
                return
        for y in range(r.position.y / NAV_K, (r.end.y - 1) / NAV_K + 1):
                for x in range(r.position.x / NAV_K, (r.end.x - 1) / NAV_K + 1):
                        var q: = Vector2i(x, y)
                        if not nav.region.has_point(q):
                                continue
                        var n: int = int(blocked.get(q, 0)) + (1 if on else -1)
                        if n <= 0:
                                blocked.erase(q)
                        else:
                                blocked[q] = n
                        _nav_eval(q, false)


func point_blocked(p: Vector2) -> bool:
        if nav == null:
                return false
        var q: Vector2i = _nav_cell(p)
        return nav.is_point_solid(q)



func nav_open(path: Array[Vector2i]) -> void :
        var seen: Dictionary = {}
        for c: Vector2i in path:
                var q: = Vector2i(c.x / NAV_K, c.y / NAV_K)
                if nav.region.has_point(q) and not seen.has(q):
                        seen[q] = true
                        _nav_eval(q, false)


func _nav_cell(p: Vector2) -> Vector2i:
        var k: float = float(NAV_K * GameWorld.CELL)
        return Vector2i(clampi(int(p.x / k), 0, nav.region.size.x - 1), clampi(int(p.y / k), 0, nav.region.size.y - 1))


func _nearest_open(c: Vector2i) -> Vector2i:
        if not nav.is_point_solid(c):
                return c
        for r in range(1, 12):
                for dy in range( - r, r + 1):
                        for dx in range( - r, r + 1):
                                var q: = c + Vector2i(dx, dy)
                                if nav.region.has_point(q) and not nav.is_point_solid(q):
                                        return q
        return c




func _land_center(q: Vector2i) -> Vector2:
        var d: WorldData = gw.data
        var k: float = float(NAV_K * GameWorld.CELL)
        var c: = Vector2(q) * k + Vector2(k * 0.5, k * 0.5)
        var cc: = Vector2i(q.x * NAV_K + NAV_K / 2, q.y * NAV_K + NAV_K / 2)
        if not d.inside(cc.x, cc.y) or not _shore_cell(cc):
                return c


        var best: Vector2 = c
        var bd: float = INF
        for yy in range(q.y * NAV_K, q.y * NAV_K + NAV_K):
                for xx in range(q.x * NAV_K, q.x * NAV_K + NAV_K):
                        var i: int = yy * d.w + xx
                        if Biome.is_water(d.biome[i]) and (d.flags[i] & WorldData.F_BRIDGE) == 0:
                                continue
                        var p: = Vector2(xx * GameWorld.CELL + 2, yy * GameWorld.CELL + 2)
                        var dd: float = p.distance_squared_to(c) - (30.0 if (d.flags[i] & WorldData.F_ROAD) != 0 else 0.0)\
                        + (1000.0 if _shore_cell(Vector2i(xx, yy)) else 0.0)
                        if dd < bd:
                                bd = dd
                                best = p
        return best



func _shore_cell(c: Vector2i) -> bool:
        var d: WorldData = gw.data
        for o: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                var n: Vector2i = c + o
                if d.inside(n.x, n.y):
                        var i: int = n.y * d.w + n.x
                        if Biome.is_water(d.biome[i]) and (d.flags[i] & WorldData.F_BRIDGE) == 0:
                                return true
        return false




func land_point(p: Vector2, r: int = 6) -> Vector2:
        var d: WorldData = gw.data
        var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
        if not d.inside(c.x, c.y) or not Biome.is_water(d.get_biome(c.x, c.y)) or d.has_flag(c.x, c.y, WorldData.F_BRIDGE):
                return p
        for rr in range(1, r + 1):
                for dy in range( - rr, rr + 1):
                        for dx in range( - rr, rr + 1):
                                if maxi(absi(dx), absi(dy)) != rr:
                                        continue
                                var q: = c + Vector2i(dx, dy)
                                if d.inside(q.x, q.y) and not Biome.is_water(d.get_biome(q.x, q.y)):
                                        return Vector2(q * GameWorld.CELL) + Vector2(2, 2)
        return p



func _bridge_in(q: Vector2i) -> Bridge:
        var d: WorldData = gw.data
        for yy in range(q.y * NAV_K, q.y * NAV_K + NAV_K):
                for xx in range(q.x * NAV_K, q.x * NAV_K + NAV_K):
                        var i: int = yy * d.w + xx
                        if (d.flags[i] & WorldData.F_BRIDGE) != 0 and gw.bridge_ok_idx(i):
                                return gw.bridge_cells[i]
        return null



func _deck_points(b: Bridge, from: Vector2) -> PackedVector2Array:
        var pts: = PackedVector2Array()
        if b.pts.size() >= 2:
                pts = b.pts.duplicate()
        else:
                var d: WorldData = gw.data
                for j: int in [0, b.cells.size() - 1]:
                        var c: Vector2i = b.cells[j]
                        var bank: Vector2i = c
                        for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                                var q: Vector2i = c + o
                                if d.inside(q.x, q.y) and d.has_flag(q.x, q.y, WorldData.F_ROAD) and not Biome.is_water(d.get_biome(q.x, q.y)):
                                        bank = q
                                        break
                        if j == 0:
                                pts.append(Vector2(bank * GameWorld.CELL) + Vector2(2, 2))
                        for c2: Vector2i in (b.cells if j == 0 else []):
                                pts.append(Vector2(c2 * GameWorld.CELL) + Vector2(2, 2))
                        if j != 0:
                                pts.append(Vector2(bank * GameWorld.CELL) + Vector2(2, 2))
        if pts.size() >= 2 and from.distance_squared_to(pts[0]) > from.distance_squared_to(pts[pts.size() - 1]):
                pts.reverse()
        return pts




func nav_path(a: Vector2, b: Vector2) -> PackedVector2Array:
        var out: = PackedVector2Array()
        nav_last_ok = true
        if nav == null:
                out.append(b)
                return out
        var ca: Vector2i = _nearest_open(_nav_cell(a))
        var cb: Vector2i = _nearest_open(_nav_cell(b))
        var key: = Vector4i(ca.x, ca.y, cb.x, cb.y)
        var ce: Array = _path_cache.get(key, [])
        var ids: Array[Vector2i] = []
        if not ce.is_empty() and int(ce[0]) == _nav_ver and gw.game_time - float(ce[1]) < PATH_TTL:
                ids = ce[2]
        else:
                ids = nav.get_id_path(ca, cb, true)
                if not ui_time():
                        if _path_cache.size() >= PATH_CACHE_MAX:
                                _path_cache.clear()
                        _path_cache[key] = [_nav_ver, gw.game_time, ids]
        nav_last_ok = not ids.is_empty() and ids[ids.size() - 1] == cb
        if ids.is_empty():
                return out
        var k: float = float(NAV_K * GameWorld.CELL)
        var used: Dictionary = {}
        for i in range(1, ids.size()):


                var br: Bridge = _bridge_in(ids[i])
                if br != null and used.has(br):
                        continue
                if br != null:
                        var prev: Vector2 = out[out.size() - 1] if not out.is_empty() else a
                        var nxt: Vector2 = b
                        for j in range(i + 1, ids.size()):
                                if _bridge_in(ids[j]) != br:
                                        nxt = Vector2(ids[j]) * k + Vector2(k * 0.5, k * 0.5)
                                        break
                        var deck: PackedVector2Array = _deck_points(br, prev)
                        var e1: Vector2 = deck[deck.size() - 1]

                        if deck.size() >= 2 and nxt.distance_squared_to(e1) < nxt.distance_squared_to(deck[0]):
                                used[br] = true
                                out.append_array(deck)
                                continue
                out.append(_land_center(ids[i]))


        if nav_last_ok:
                out.append(b)
        return _dry_segments(a, out)


## R-FORD: путь с форсированием — клетки рек проходимы (медленно), мосты при
## этом тоже используются. Без _dry_segments: мокрые сегменты здесь и есть цель.
func army_path_ford(a: Vector2, b: Vector2) -> PackedVector2Array :
        var out: PackedVector2Array = PackedVector2Array()
        nav_last_ok = false
        nav_last_pending = false
        if nav == null or nav_ford == null:
                return out
        var ca: Vector2i = _nearest_open_f(_nav_cell(a))
        var cb: Vector2i = _nearest_open_f(_nav_cell(b))
        var ids: Array[Vector2i] = nav_ford.get_id_path(ca, cb, true)
        nav_last_ok = not ids.is_empty() and ids[ids.size() - 1] == cb
        if ids.is_empty():
                return out
        var k: float = float(NAV_K * GameWorld.CELL)
        var used: Dictionary = {}
        for i in range(1, ids.size()):
                var br: Bridge = _bridge_in(ids[i])
                if br != null and used.has(br):
                        continue
                if br != null and br.passable():
                        var prev: Vector2 = out[out.size() - 1] if not out.is_empty() else a
                        var nxt: Vector2 = b
                        for j in range(i + 1, ids.size()):
                                if _bridge_in(ids[j]) != br:
                                        nxt = Vector2(ids[j]) * k + Vector2(k * 0.5, k * 0.5)
                                        break
                        var deck: PackedVector2Array = _deck_points(br, prev)
                        var e1: Vector2 = deck[deck.size() - 1]
                        if deck.size() >= 2 and nxt.distance_squared_to(e1) < nxt.distance_squared_to(deck[0]):
                                used[br] = true
                                out.append_array(deck)
                                continue
                out.append(Vector2(ids[i]) * k + Vector2(k * 0.5, k * 0.5))
        if nav_last_ok:
                out.append(b)
        return out


## Ближайшая открытая клетка на ford-сетке (фолбэк — на обычной).
func _nearest_open_f(c: Vector2i) -> Vector2i :
        if nav_ford != null and not nav_ford.is_point_solid(c):
                return c
        if nav_ford == null:
                return _nearest_open(c)
        for r in range(1, 12):
                for dy in range(-r, r + 1):
                        for dx in range(-r, r + 1):
                                var q: = c + Vector2i(dx, dy)
                                if nav_ford.region.has_point(q) and not nav_ford.is_point_solid(q):
                                        return q
        return _nearest_open(c)





func army_path(a: Vector2, b: Vector2, budget: bool = false) -> PackedVector2Array:

        if gw.game_time != _ap_gt:
                _ap_gt = gw.game_time
                _ap_memo.clear()
                _ap_left = ROUTE_TICK
        var mk: = Vector4(a.x, a.y, b.x, b.y)
        var me: Array = _ap_memo.get(mk, [])
        if not me.is_empty() and int(me[0]) == _nav_ver:
                nav_last_ok = bool(me[2])
                nav_last_soft = bool(me[3])
                nav_last_pending = bool(me[4])
                return (me[1] as PackedVector2Array).duplicate()
        if budget and not ui_time():
                if _ap_left <= 0.0:
                        nav_last_ok = false
                        nav_last_soft = false
                        nav_last_pending = true
                        return PackedVector2Array()
                _ap_left -= 1.0 + a.distance_to(b) / 1000.0
        var r: PackedVector2Array = _army_path(a, b)
        if not ui_time():
                _ap_memo[mk] = [_nav_ver, r.duplicate(), nav_last_ok, nav_last_soft, nav_last_pending]
        return r


func _army_path(a: Vector2, b: Vector2) -> PackedVector2Array:
        nav_last_soft = false
        nav_last_pending = false
        _leg_wet = false
        var p: PackedVector2Array = nav_path(a, b)
        if nav == null or nav_soft == null:
                return p
        var ok: bool = nav_last_ok
        if ok and not (_leg_wet and _wet_path(p)):
                return p
        var fp: PackedVector2Array = _soft_path(a, b)
        if nav_last_pending:
                nav_last_ok = false
                return p
        if not fp.is_empty():
                nav_last_ok = true
                nav_last_soft = true
                return fp
        nav_last_ok = false
        return p




func _wet_path(p: PackedVector2Array) -> bool:
        var ar: Army = gw.army
        if ar == null:
                return false
        for i in range(1, p.size()):
                var u: Vector2 = p[i - 1]
                var v: Vector2 = p[i]
                var n: int = maxi(1, int(u.distance_to(v) / 2.0))
                for s in range(1, n + 1):
                        if ar.ground_at(u.lerp(v, float(s) / float(n))) != 1:
                                return true
        return false


func _soft_path(a: Vector2, b: Vector2) -> PackedVector2Array:
        var d: WorldData = gw.data
        var fa: = Vector2i(clampi(floori(a.x / GameWorld.CELL), 0, d.w - 1), clampi(floori(a.y / GameWorld.CELL), 0, d.h - 1))
        var fb: = Vector2i(clampi(floori(b.x / GameWorld.CELL), 0, d.w - 1), clampi(floori(b.y / GameWorld.CELL), 0, d.h - 1))
        var key: = Vector4i(fa.x >> 1, fa.y >> 1, fb.x >> 1, fb.y >> 1)
        var ce: Array = _soft_cache.get(key, [])
        if not ce.is_empty() and int(ce[0]) == _nav_ver:
                return ce[1]
        if ui_time():
                var jn: Dictionary = _job_new(key, fa, fb, b)
                _job_run(jn, 1 << 30)
                return jn["res"]
        var job: Dictionary = {}
        for j: Dictionary in _soft_jobs:
                if j["key"] == key and int(j["ver"]) == _nav_ver:
                        job = j
                        break
        if job.is_empty():
                if _soft_jobs.size() >= SOFT_JOBS_MAX:
                        _soft_jobs.pop_front()
                job = _job_new(key, fa, fb, b)
                _soft_jobs.append(job)
        _soft_budget()
        _job_run(job, _soft_tick_left)
        if not bool(job["done"]):
                nav_last_pending = true
                return PackedVector2Array()
        _soft_jobs.erase(job)
        _soft_done(job)
        return job["res"]



func soft_tick() -> void :
        if _soft_jobs.is_empty():
                return
        _soft_budget()
        for j: Dictionary in _soft_jobs.duplicate():
                if _soft_tick_left <= 0:
                        break
                if int(j["ver"]) != _nav_ver:
                        _soft_jobs.erase(j)
                        continue
                _job_run(j, _soft_tick_left)
                if bool(j["done"]):
                        _soft_jobs.erase(j)
                        _soft_done(j)


func _soft_budget() -> void :
        if gw.game_time != _soft_gt:
                _soft_gt = gw.game_time
                _soft_tick_left = SOFT_TICK


func _soft_done(j: Dictionary) -> void :
        soft_stats["n"] = int(soft_stats.get("n", 0)) + 1
        soft_stats["found"] = int(soft_stats.get("found", 0)) + (1 if not (j["res"] as PackedVector2Array).is_empty() else 0)
        if _soft_cache.size() >= SOFT_CACHE_MAX:
                _soft_cache.clear()
        _soft_cache[j["key"]] = [_nav_ver, j["res"]]




func ui_time() -> bool:
        return gw != null and gw.net_driven and not gw.net_sim



func _fine_ok(x: int, y: int) -> bool:
        var d: WorldData = gw.data
        if not Biome.is_water(d.biome[y * d.w + x]):
                return true
        return gw.army != null and gw.army.ground_at(Vector2(x * GameWorld.CELL + 2, y * GameWorld.CELL + 2)) == 1


func _soft_open(g: AStarGrid2D, c: Vector2i) -> Vector2i:
        if not g.is_point_solid(c):
                return c
        for r in range(1, 4):
                for dy in range( - r, r + 1):
                        for dx in range( - r, r + 1):
                                var q: = c + Vector2i(dx, dy)
                                if maxi(absi(dx), absi(dy)) == r and g.region.has_point(q) and not g.is_point_solid(q):
                                        return q
        return c






func _job_new(key: Vector4i, fa: Vector2i, fb: Vector2i, b: Vector2) -> Dictionary:
        var none: Array[Vector2i] = []
        return {"key": key, "ver": _nav_ver, "fa": fa, "fb": fb, "b": b, "gi": 0, "att": 0, "cut": none.duplicate(), "ids": none.duplicate(), 
                "k0": 0, "k1": 0, "cur": fa, "cells": none.duplicate(), "ri": 0, "ca": Vector2i.ZERO, "cb": Vector2i.ZERO, "st": 0, "left": SOFT_BUDGET, 
                "done": false, "res": PackedVector2Array()}



func _job_run(j: Dictionary, budget: int) -> void :
        var g: AStarGrid2D = nav_soft if int(j["gi"]) == 0 else nav_dry
        var cut: Array[Vector2i] = j["cut"]
        for c: Vector2i in cut:
                g.set_point_solid(c, true)
        var spent: int = 0
        var first: bool = budget >= SOFT_TICK
        while budget > 0 and not bool(j["done"]):
                var cost: int = _job_step(j, budget - spent, first)
                if cost < 0:
                        break
                spent += cost
                first = false
                var g2: AStarGrid2D = nav_soft if int(j["gi"]) == 0 else nav_dry
                if g2 != g:
                        g = g2
                        cut = j["cut"]
        for c2: Vector2i in (j["cut"] as Array[Vector2i]):
                g.set_point_solid(c2, false)
        if budget < (1 << 30):
                _soft_tick_left -= spent




func _job_step(j: Dictionary, left: int, first: bool) -> int:
        var g: AStarGrid2D = nav_soft if int(j["gi"]) == 0 else nav_dry
        var fa: Vector2i = j["fa"]
        var fb: Vector2i = j["fb"]
        if int(j["st"]) == 0:
                if not first and left < SOFT_ASTAR:
                        return -1
                var ca: Vector2i = _soft_open(g, Vector2i(fa.x / NAV_K, fa.y / NAV_K))
                var cb: Vector2i = _soft_open(g, Vector2i(fb.x / NAV_K, fb.y / NAV_K))
                var ids: Array[Vector2i] = [] as Array[Vector2i]
                if not g.is_point_solid(ca) and not g.is_point_solid(cb):
                        ids = g.get_id_path(ca, cb)
                if ids.is_empty():
                        _job_next_grid(j, g)
                        return SOFT_ASTAR
                j["ca"] = ca
                j["cb"] = cb
                j["ids"] = ids
                j["k0"] = 0
                j["cur"] = fa
                (j["cells"] as Array[Vector2i]).clear()
                j["ri"] = 0
                _job_k1(j)
                j["st"] = 1
                return SOFT_ASTAR
        var ids2: Array[Vector2i] = j["ids"]
        var k0: int = int(j["k0"])
        var k1: int = int(j["k1"])
        var last: bool = k1 >= ids2.size() - 1
        var rad: int = int(SOFT_RW[int(j["ri"])]) if int(j["ri"]) < SOFT_RW.size() else int(SOFT_RW[1])
        var cor: Dictionary = _soft_corridor(ids2, k0, k1, j["cur"], fb if last else Vector2i(-1, -1), rad)
        var cost: int = cor.size() * NAV_K * NAV_K
        if not first and cost > left:
                return -1
        j["left"] = int(j["left"]) - cost
        if int(j["left"]) < 0:
                _job_finish(j, false)
                return cost
        var seg: Array[Vector2i] = _soft_window(cor, ids2, k1, j["cur"], fb if last else Vector2i(-1, -1))
        if not seg.is_empty():
                var cells: Array[Vector2i] = j["cells"]
                for i in range(1 if not cells.is_empty() else 0, seg.size()):
                        cells.append(seg[i])
                j["cur"] = seg[seg.size() - 1]
                if last:
                        _job_finish(j, true)
                        return cost
                j["k0"] = k1
                j["ri"] = 0
                _job_k1(j)
                return cost
        j["ri"] = int(j["ri"]) + 1
        if int(j["ri"]) <= SOFT_RW.size():
                _job_k1(j)
                return cost

        if int(j["gi"]) == 0 or int(j["att"]) + 1 >= SOFT_TRIES:
                _job_next_grid(j, g)
                return cost
        var n0: int = (j["cut"] as Array[Vector2i]).size()
        for k in range(k0, mini(ids2.size(), k0 + SOFT_CUT)):
                var q: Vector2i = ids2[k]
                if q != j["ca"] and q != j["cb"] and not g.is_point_solid(q) and _wet_cell(q):
                        g.set_point_solid(q, true)
                        (j["cut"] as Array[Vector2i]).append(q)
        if (j["cut"] as Array[Vector2i]).size() == n0:
                _job_next_grid(j, g)
                return cost
        j["att"] = int(j["att"]) + 1
        j["st"] = 0
        return cost




func _job_k1(j: Dictionary) -> void :
        var ids: Array[Vector2i] = j["ids"]
        var k0: int = int(j["k0"])
        var w: int = 2 * int(SOFT_RW[mini(int(j["ri"]), SOFT_RW.size() - 1)]) + 1
        var n: int = maxi(1, SOFT_TICK / (NAV_K * NAV_K * w) - w)
        if int(j["ri"]) >= SOFT_RW.size():
                w = 2 * int(SOFT_RW[1]) + 1
                n = maxi(4, SOFT_LONG / (NAV_K * NAV_K * w) - w)
        var k1: int = mini(ids.size() - 1, k0 + n)
        while k1 < ids.size() - 1 and k1 < k0 + n + 3 and nav.is_point_solid(ids[k1]):
                k1 += 1
        j["k1"] = k1


func _job_next_grid(j: Dictionary, g: AStarGrid2D) -> void :
        for c: Vector2i in (j["cut"] as Array[Vector2i]):
                g.set_point_solid(c, false)
        (j["cut"] as Array[Vector2i]).clear()
        if int(j["gi"]) >= 1:
                _job_finish(j, false)
                return
        j["gi"] = 1
        j["att"] = 0
        j["st"] = 0


func _job_finish(j: Dictionary, ok: bool) -> void :
        j["done"] = true
        if not ok:
                j["res"] = PackedVector2Array()
                return
        var cells: Array[Vector2i] = j["cells"]
        var fb: Vector2i = j["fb"]
        var out: = PackedVector2Array()
        for i in range(1, cells.size()):
                if i < cells.size() - 1 and cells[i] - cells[i - 1] == cells[i + 1] - cells[i]:
                        continue
                out.append(Vector2(cells[i] * GameWorld.CELL) + Vector2(2, 2))
        if _fine_ok(fb.x, fb.y):
                out.append(j["b"])
        if out.is_empty():
                out.append(j["b"])
        j["res"] = out



func _wet_cell(q: Vector2i) -> bool:
        for yy in range(q.y * NAV_K, q.y * NAV_K + NAV_K):
                for xx in range(q.x * NAV_K, q.x * NAV_K + NAV_K):
                        if not _fine_ok(xx, yy):
                                return true
        return false



func _soft_corridor(ids: Array[Vector2i], k0: int, k1: int, from: Vector2i, to: Vector2i, rad: int) -> Dictionary:
        var cor: Dictionary = {}
        var extra: Array[Vector2i] = [Vector2i(from.x / NAV_K, from.y / NAV_K)]
        if to.x >= 0:
                extra.append(Vector2i(to.x / NAV_K, to.y / NAV_K))
        for k in range(k0, k1 + 1):
                extra.append(ids[k])
        for q: Vector2i in extra:
                for dy in range( - rad, rad + 1):
                        for dx in range( - rad, rad + 1):
                                var c: = q + Vector2i(dx, dy)
                                if not cor.has(c) and nav_soft.region.has_point(c):
                                        cor[c] = true
        return cor




func _soft_window(cor: Dictionary, ids: Array[Vector2i], k1: int, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
        var d: WorldData = gw.data
        var none: Array[Vector2i] = []
        if cor.is_empty():
                return none
        var lo: = Vector2i(1 << 30, 1 << 30)
        var hi: = Vector2i(-1, -1)
        for c0: Vector2i in cor:
                lo = Vector2i(mini(lo.x, c0.x), mini(lo.y, c0.y))
                hi = Vector2i(maxi(hi.x, c0.x), maxi(hi.y, c0.y))
        var reg: = Rect2i(lo * NAV_K, (hi - lo + Vector2i.ONE) * NAV_K)
        var g: = AStarGrid2D.new()
        g.region = reg
        g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
        g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
        g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
        g.update()
        g.fill_solid_region(reg, true)

        var deck: Dictionary = {}
        var rr: Rect2i = reg.grow(Army.DECK_R)
        for bi: int in gw.bridge_cells:
                var bx: int = bi % d.w
                var by: int = bi / d.w
                if not rr.has_point(Vector2i(bx, by)):
                        continue
                var br: Bridge = gw.bridge_cells[bi]
                if br == null or not (br.passable() or br.pont == 2):
                        continue
                for dy in range( - Army.DECK_R, Army.DECK_R + 1):
                        for dx in range( - Army.DECK_R, Army.DECK_R + 1):
                                deck[(by + dy) * d.w + bx + dx] = true
        for c: Vector2i in cor:
                for yy in range(c.y * NAV_K, c.y * NAV_K + NAV_K):
                        for xx in range(c.x * NAV_K, c.x * NAV_K + NAV_K):
                                var fi: int = yy * d.w + xx
                                if not Biome.is_water(d.biome[fi]) or deck.has(fi):
                                        var fq: = Vector2i(xx, yy)
                                        g.set_point_solid(fq, false)
                                        if (d.flags[yy * d.w + xx] & WorldData.F_ROAD) == 0:
                                                g.set_point_weight_scale(fq, 1.6)
        var s0: Vector2i = _fine_near(g, from)
        if s0.x < 0:
                return none
        var goals: Array[Vector2i] = []
        if to.x >= 0:
                var t0: Vector2i = _fine_near(g, to)
                if t0.x >= 0:
                        goals.append(t0)
        else:

                var q1: Vector2i = ids[k1]
                var cc: = Vector2(q1 * NAV_K) + Vector2(NAV_K, NAV_K) * 0.5
                var cand: Array = []
                for yy in range(q1.y * NAV_K, q1.y * NAV_K + NAV_K):
                        for xx in range(q1.x * NAV_K, q1.x * NAV_K + NAV_K):
                                if g.region.has_point(Vector2i(xx, yy)) and not g.is_point_solid(Vector2i(xx, yy)):
                                        cand.append([Vector2(xx, yy).distance_squared_to(cc), Vector2i(xx, yy)])
                cand.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]) or (float(x[0]) == float(y[0]) and (x[1] as Vector2i) < (y[1] as Vector2i)))
                for e: Array in cand.slice(0, 6):
                        goals.append(e[1])
        for t: Vector2i in goals:
                var fp: Array[Vector2i] = g.get_id_path(s0, t)
                if not fp.is_empty():
                        return fp
        return none


func _fine_near(g: AStarGrid2D, c: Vector2i) -> Vector2i:
        for r in range(0, 5):
                for dy in range( - r, r + 1):
                        for dx in range( - r, r + 1):
                                var q: = c + Vector2i(dx, dy)
                                if maxi(absi(dx), absi(dy)) == r and g.region.has_point(q) and not g.is_point_solid(q):
                                        return q
        return Vector2i(-1, -1)





func _dry_segments(a: Vector2, p: PackedVector2Array) -> PackedVector2Array:
        var out: = PackedVector2Array()
        var prev: Vector2 = a
        for q: Vector2 in p:
                _dry_leg(prev, q, out, 0)
                prev = q
        return out



func _dry_leg(a: Vector2, b: Vector2, out: PackedVector2Array, depth: int) -> void :
        var wet: Vector2 = _wet_on(a, b)
        if wet == Vector2.INF or depth >= DRY_DEPTH:
                if wet != Vector2.INF:
                        _leg_wet = true
                out.append(b)
                return
        var dry: Vector2 = _dry_near(wet)
        if dry == Vector2.INF or dry.distance_squared_to(a) < 1.0 or dry.distance_squared_to(b) < 1.0:
                _leg_wet = true
                out.append(b)
                return
        _dry_leg(a, dry, out, depth + 1)
        _dry_leg(dry, b, out, depth + 1)


func _water_px(p: Vector2) -> bool:
        var d: WorldData = gw.data
        var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
        if not d.inside(c.x, c.y):
                return false
        var i: int = c.y * d.w + c.x
        return Biome.is_water(d.biome[i]) and (d.flags[i] & WorldData.F_BRIDGE) == 0


func _bridge_near(p: Vector2) -> bool:
        var d: WorldData = gw.data
        var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
        for dy in range(-2, 3):
                for dx in range(-2, 3):
                        if d.inside(c.x + dx, c.y + dy) and (d.flags[(c.y + dy) * d.w + c.x + dx] & WorldData.F_BRIDGE) != 0:
                                return true
        return false



func _wet_on(a: Vector2, b: Vector2) -> Vector2:
        var L: float = a.distance_to(b)
        if L < 0.5:
                return Vector2.INF
        var d: WorldData = gw.data
        var side: Vector2 = (b - a).normalized().orthogonal() * BODY_HALF
        var steps: int = maxi(1, int(L / 2.0))
        var inv: float = 1.0 / float(GameWorld.CELL)
        var last: int = -1
        for s in range(1, steps):
                var m: Vector2 = a.lerp(b, float(s) / float(steps))
                var c0: = Vector2i(floori(m.x * inv), floori(m.y * inv))
                var c1: = Vector2i(floori((m.x + side.x) * inv), floori((m.y + side.y) * inv))
                var c2: = Vector2i(floori((m.x - side.x) * inv), floori((m.y - side.y) * inv))
                var key: int = ((c0.y * d.w + c0.x) * 31 + (c1.y * d.w + c1.x)) * 31 + (c2.y * d.w + c2.x)
                if key == last:
                        continue
                last = key

                if (_water_px(m) or _water_px(m + side) or _water_px(m - side)) and not _bridge_near(m):
                        return m
        return Vector2.INF




func _dry_near(p: Vector2) -> Vector2:
        var d: WorldData = gw.data
        var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
        var any: = Vector2.INF
        for rr in range(0, 5):
                var best: = Vector2.INF
                var bd: float = INF
                for dy in range( - rr, rr + 1):
                        for dx in range( - rr, rr + 1):
                                if maxi(absi(dx), absi(dy)) != rr:
                                        continue
                                var q: = c + Vector2i(dx, dy)
                                if not d.inside(q.x, q.y) or Biome.is_water(d.get_biome(q.x, q.y)):
                                        continue
                                var qp: = Vector2(q * GameWorld.CELL) + Vector2(2, 2)
                                if any == Vector2.INF:
                                        any = qp
                                var margin: bool = true
                                for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                                        var n: Vector2i = q + o
                                        if d.inside(n.x, n.y) and Biome.is_water(d.get_biome(n.x, n.y)) and not d.has_flag(n.x, n.y, WorldData.F_BRIDGE):
                                                margin = false
                                                break
                                var dd: float = qp.distance_squared_to(p)
                                if margin and dd < bd:
                                        bd = dd
                                        best = qp
                if best != Vector2.INF:
                        return best
        return any


func _site_of(f: Facility) -> Dictionary:
        if not _site.has(f):
                _site[f] = {"status": "", "rate": 0, "trees": 0}
        return _site[f]





static func res_cost(key: String) -> Dictionary:
        if key.begins_with("build_"):
                return (BUILD_COST.get(int(key.substr(6)), {}) as Dictionary).duplicate()
        return (RES_COST.get(key, {}) as Dictionary).duplicate()



static func build_cost(kind: int) -> Dictionary:
        var out: Dictionary = res_cost("build_%d" % kind)
        out["money"] = Military.cost_of(kind) if Military.COSTS.has(kind) else 0
        return out



static func cost_text(cost: Dictionary) -> String:
        var parts: PackedStringArray = PackedStringArray()
        if int(cost.get("money", 0)) > 0:
                parts.append(str(int(cost["money"])))
        for k: String in cost:
                if k != "money" and int(cost[k]) > 0:
                        parts.append("%s %d" % [Loc.t(String(RES_NAMES.get(k, k)).to_lower()), int(cost[k])])
        return " · ".join(parts)


func res_cap(c: Country, res: String) -> int:
        var cap: int = int(BASE_CAP.get(res, 999))
        if ports != null and ports.has_port(c):
                cap += int(PORT_CAP.get(res, 0))
        return cap + int(_bonus(c).get(res, 0))


func _update_prices() -> void :
        for res: String in PRICE:
                var supply: float = 0.0
                var dem: float = 0.0
                for c: Country in gw.countries:
                        if c.eliminated or c.capital_id < 0:
                                continue
                        supply += float(int(c.get(res)))
                        dem += float(need(c, res)) + float(demand(c).get(res, 0.0))
                var k: float = clampf(0.75 + 0.6 * (dem + 5.0) / (supply + 20.0), 0.6, 2.2)
                var target: float = float(PRICE[res]) * k
                prices[res] = lerpf(float(prices.get(res, float(PRICE[res]))), target, 0.35)





func market_price(res: String, cid: int = -1) -> int:
        var m: float = gw.supply.price_mult(cid, res) if gw.supply != null else 1.0
        if upk != null:
                m = clampf(m * upk.world_k(res), Upkeep335S.MULT_MIN, Upkeep335S.MULT_MAX)
        return maxi(1, roundi(float(prices.get(res, float(PRICE.get(res, 10)))) * m))


func foreign_buy_price(res: String, cid: int = -1) -> int:
        return maxi(1, int(market_price(res, cid) * FOREIGN_BUY * (trd.import_mul(cid, res) if trd != null else 1.0) * (upk.buy_k(cid, res) if upk != null else 1.0)))



func foreign_sell_price(res: String, cid: int = -1) -> int:
        return maxi(1, int(market_price(res) * FOREIGN_SELL * (upk.sell_k(cid, res) if upk != null else 1.0)))




func demand(c: Country) -> Dictionary:
        if _demand.has(c.id):
                return _demand[c.id]
        var out: Dictionary = {}
        for f: Facility in gw.mil.facilities:
                if f.country_id != c.id or not gw.mil.alive(f):
                        continue
                match f.kind:
                        Facility.Kind.DRONE_FACTORY:
                                _acc(out, res_cost("drone"), 60.0 / Military.PROD_TIME)
                        Facility.Kind.MISSILE_FACTORY:
                                _acc(out, res_cost("missile_%d" % f.prod_type), 60.0 / float(Military.MT_TIME[f.prod_type]))
                        Facility.Kind.BARRACKS:
                                _acc(out, res_cost("tank"), 1.0)
                                _acc(out, res_cost("infantry"), 1.5)
                        Facility.Kind.REFINERY:
                                out["oil"] = float(out.get("oil", 0.0)) + 60.0 / Military.FUEL_DT * float(f.level)
                        Facility.Kind.NUCLEAR_PLANT:
                                out["uranium"] = float(out.get("uranium", 0.0)) + 60.0 / Nuclear.FUEL_S
        var units: int = gw.army.count_units(c.id)
        if units > 0:
                out["food"] = float(out.get("food", 0.0)) + float((units + 2) / 3) * 60.0 / TICK
        if not ui_time():
                _demand[c.id] = out
        return out


func _acc(out: Dictionary, cost: Dictionary, k: float) -> void :
        for r: String in cost:
                out[r] = float(out.get(r, 0.0)) + float(cost[r]) * k



func keep(c: Country, res: String) -> int:
        var d: float = float(demand(c).get(res, 0.0))
        var w: int = int((want.get(c.id, {}) as Dictionary).get(res, 0))
        return maxi(int(ceil(d * 2.0)) + w + int(res_cap(c, res) * 0.1), _ab_keep(c, res))



func need(c: Country, res: String) -> int:
        var d: float = float(demand(c).get(res, 0.0))
        var w: int = int((want.get(c.id, {}) as Dictionary).get(res, 0))
        return clampi(int(ceil(d * 2.0)) + w - int(c.get(res)), 0, res_cap(c, res))



func surplus(c: Country, res: String) -> int:
        return maxi(0, int(c.get(res)) - keep(c, res))



func shortages(c: Country) -> Array:
        var out: Array = []
        for res: String in TRADE_RES:
                var n: int = need(c, res)
                if n > 0:
                        out.append([res, n])
        out.sort_custom( func(a: Array, b: Array) -> bool: return int(a[1]) * market_price(String(a[0])) > int(b[1]) * market_price(String(b[0])))
        return out



func inbound(c: Country, res: String) -> int:
        var n: int = 0
        for t: Dictionary in trucks:
                if int(t["to"]) == c.id and String(t["res"]) == res:
                        n += int(t["n"])
        for j: Dictionary in rail_jobs:
                if int(j["to"]) == c.id and String(j["res"]) == res:
                        n += int(j["n"])
        return n + ports.inbound(c, res)






func stat_add(c: Country, kind: String, key: String, amount: int) -> void :
        if c == null or amount == 0:
                return
        var st: Dictionary = _stat_of(c.id)
        for part: String in ["cur", "total"]:
                var d: Dictionary = st[part]
                if not d.has(kind):
                        d[kind] = {}
                var dk: Dictionary = d[kind]
                dk[key] = int(dk.get(key, 0)) + amount



func stat_res(c: Country, res: String, src: String, n: int) -> void :
        if n > 0:
                stat_add(c, "res_in", res + ":" + src, n)
        elif n < 0:
                stat_add(c, "res_out", res + ":" + src, - n)


func _stat_of(id: int) -> Dictionary:
        if not _stats.has(id):
                _stats[id] = {"cur": {}, "ring": [], "total": {}}
        return _stats[id]


func _stat_roll() -> void :
        for st: Dictionary in _stats.values():
                var ring: Array = st["ring"]
                ring.append(st["cur"])
                if ring.size() > STAT_SLOTS:
                        ring.pop_front()
                st["cur"] = {}



func _stat_cities() -> void :
        for c: Country in gw.countries:
                var add: int = 0
                for cid in c.city_ids:
                        var city: City = gw.cities[cid]
                        if not city.powered:
                                continue
                        match city.kind:
                                City.Kind.CAPITAL:
                                        add += Military.INCOME_CAPITAL
                                City.Kind.TOWN:
                                        add += Military.INCOME_TOWN
                                _:
                                        add += Military.INCOME_VILLAGE
                if not c.is_player:
                        add = int(add * GameConfig.ai_income_mul(c))
                stat_add(c, "income", "cities", add * int(TICK / Military.INCOME_DT))






func stats(c: Country) -> Dictionary:
        var st: Dictionary = _stat_of(c.id)
        var ring: Array = st["ring"]
        var k: float = 60.0 / maxf(TICK, float(ring.size()) * TICK)
        var win: Dictionary = {}
        for slot: Dictionary in ring:
                for kind: String in slot:
                        if not win.has(kind):
                                win[kind] = {}
                        for key: String in slot[kind]:
                                win[kind][key] = int(win[kind].get(key, 0)) + int(slot[kind][key])
        var tot: Dictionary = st["total"]
        var out: Dictionary = {"window_s": int(ring.size() * TICK)}
        for kind: String in ["income", "spend"]:
                var rate: Dictionary = {}
                for key: String in win.get(kind, {}):
                        rate[key] = roundi(float(win[kind][key]) * k)
                out[kind] = rate
                out[kind + "_total"] = (tot.get(kind, {}) as Dictionary).duplicate()
        for kind: String in ["res_in", "res_out"]:
                out[kind] = _split(win.get(kind, {}), k)
                out[kind + "_total"] = _split(tot.get(kind, {}), 1.0)
        var top: String = ""
        var tv: int = 0
        for key: String in out["income"]:
                if int(out["income"][key]) > tv:
                        tv = int(out["income"][key])
                        top = key
        out["top_income"] = top
        return out


func _split(d: Dictionary, k: float) -> Dictionary:
        var out: Dictionary = {}
        for key: String in d:
                var p: PackedStringArray = key.split(":")
                var res: String = p[0]
                var src: String = p[1] if p.size() > 1 else "?"
                if not out.has(res):
                        out[res] = {}
                out[res][src] = roundi(float(d[key]) * k)
        return out



func res_rate(c: Country, res: String) -> int:
        var st: Dictionary = stats(c)
        var n: int = 0
        for v: int in (st["res_in"].get(res, {}) as Dictionary).values():
                n += v
        for v: int in (st["res_out"].get(res, {}) as Dictionary).values():
                n -= v
        return n






func site_info(f: Facility) -> Dictionary:
        var st: Dictionary = _site_of(f)
        var base: float = base_rate(f)
        var out: Dictionary = {"code": st["status"], "status": site_text(String(st["status"])), "rate": st["rate"], "trees": st["trees"], "res": out_res(f), "left": -1, "max": -1, 
                "level": f.level, "max_level": MAX_LEVEL if UPG_RES.has(f.kind) else 1, "next_rate": -1, "upgrade_cost": upgrade_cost(f)}
        if not is_extractor(f.kind):
                out["rate"] = ceili(base * level_mul(f))
        if not f.deposit.is_empty():
                out["left"] = int(f.deposit["left"])
                out["max"] = int(f.deposit.get("max", f.deposit["left"]))
        if UPG_RES.has(f.kind) and f.level < MAX_LEVEL:
                out["next_rate"] = ceili(base * float(LEVEL_MUL[f.level + 1]))
        if f.kind == Facility.Kind.REFINERY:
                out["rate"] = roundi(TICK / Military.FUEL_DT) * level_of(f)
                out["next_rate"] = roundi(TICK / Military.FUEL_DT) * (f.level + 1) if f.level < MAX_LEVEL else -1
        out["halted"] = f.halted
        if f.halted:
                out["code"] = "paused"
                out["status"] = site_text("paused")
                out["rate"] = 0
        return out



func base_rate(f: Facility) -> float:
        match f.kind:
                Facility.Kind.MINE:
                        return float(MINE_RATE.get(String(f.deposit.get("res", "titanium")), 2))
                Facility.Kind.URANIUM_MINE:
                        return Nuclear.U_MINE_RATE
                Facility.Kind.OIL_RIG:
                        return float(RIG_OIL)
                Facility.Kind.SAWMILL:
                        var t: int = int(_site_of(f)["trees"])
                        if t <= 0:
                                t = count_trees(f.cell + f.size / 2, SAW_R, 2)
                        return 0.0 if t <= 0 else float(mini(SAW_WOOD_MAX, 1 + t / 15))
                Facility.Kind.FARM:
                        return float(FARM_FOOD)
                Facility.Kind.CIV_FACTORY:
                        return float(CIV_GOODS)
                Facility.Kind.REFINERY:
                        return TICK / Military.FUEL_DT
        return 0.0



func out_res(f: Facility) -> String:
        match f.kind:
                Facility.Kind.MINE:
                        return String(f.deposit.get("res", "titanium"))
                Facility.Kind.URANIUM_MINE:
                        return "uranium"
                Facility.Kind.OIL_RIG:
                        return "oil"
                Facility.Kind.SAWMILL:
                        return "wood"
                Facility.Kind.FARM:
                        return "food"
                Facility.Kind.CIV_FACTORY:
                        return "goods"
                Facility.Kind.REFINERY:
                        return "fuel"
        return ""





func room_for(c: Country, res: String) -> int:
        return maxi(0, res_cap(c, res) - int(c.get(res)) - inbound(c, res))



func refund(sh: Dictionary, tell: bool = true) -> void :
        var r: Country = gw.country_by_id(int(sh.get("to", 0)))
        var price: int = int(sh.get("price", 0))
        if r == null or price <= 0 or bool(sh.get("refunded", false)):
                return
        sh["refunded"] = true
        r.money += price
        stat_add(r, "spend", "trade", - price)
        if tell and r.is_player:
                gw.say(r, Loc.mk("Груз потерян: деньги возвращены (+%d)", [price]))




func turn_back(sh: Dictionary) -> void :
        if bool(sh.get("refunded", false)):
                return
        refund(sh, false)
        var s: Country = gw.country_by_id(int(sh.get("from", 0)))
        var res: String = String(sh.get("res", ""))
        var n: int = int(sh.get("n", 0))
        if s != null and n > 0 and TRADE_RES.has(res):
                s.set(res, int(s.get(res)) + n)
                stat_res(s, res, "trade", n)
        var r: Country = gw.country_by_id(int(sh.get("to", 0)))
        if (s != null and s.is_player) or (r != null and r.is_player):
                gw.say2(s, r, Loc.mk("Эмбарго: груз (%s %d) развёрнут, деньги возвращены", [Loc.t(String(RES_NAMES.get(res, res)).to_lower()), n]))


func deposit_free_rect(rect: Rect2i) -> bool:
        for dp: Dictionary in deposits:
                if dp["mine"] != null:
                        continue
                var dc: Vector2i = dp["cell"]
                var h: int = int(dp.get("size", 3)) / 2 + 1
                if rect.intersects(Rect2i(dc - Vector2i(h, h), Vector2i(h * 2 + 1, h * 2 + 1))):
                        return false
        return true







func drop_spent() -> int:
        var n: int = 0
        for k in range(deposits.size() - 1, -1, -1):
                var dp: Dictionary = deposits[k]
                if dp["mine"] != null or int(dp.get("left", 0)) > 0:
                        continue
                if int(dp.get("obj", -1)) >= 0:
                        gw.remove_object(int(dp["obj"]))
                deposits.remove_at(k)
                n += 1
        if n > 0:
                draw_ver += 1
        return n


func _relocate_check() -> void :
        _relocate_check_fast()






func _relocate_check_fast() -> void :
        var d: WorldData = gw.data
        var w: int = d.w
        var h: int = d.h
        var stop: int = WorldData.F_CITY | WorldData.F_OCCUPIED | WorldData.F_ROAD | WorldData.F_BRIDGE
        var has_r: bool = gw.get("rail") != null
        var bio: PackedByteArray = d.biome
        var fl: PackedByteArray = d.flags
        var rm: PackedByteArray = gw.rail.mask if has_r else PackedByteArray()
        for dp: Dictionary in deposits.duplicate():
                if dp["mine"] != null:
                        continue
                var c: Vector2i = dp["cell"]
                var sz: int = int(dp.get("size", 3))
                var x0: int = c.x - sz / 2
                var y0: int = c.y - sz / 2
                var bad: bool = x0 < 0 or y0 < 0 or x0 + sz > w or y0 + sz > h
                if not bad:
                        var rn: int = rm.size()
                        for y in range(y0, y0 + sz):
                                var row: int = y * w
                                for x in range(x0, x0 + sz):
                                        var i: int = row + x
                                        if bio[i] <= Biome.RIVER or (fl[i] & stop) != 0 or (i < rn and rm[i] != 0):
                                                bad = true
                                                break
                                if bad:
                                        break
                if bad:
                        _relocate(dp)
                        bio = d.biome
                        fl = d.flags
                        rm = gw.rail.mask if has_r else PackedByteArray()



func _relocate(dp: Dictionary) -> bool:
        var c0: Vector2i = dp["cell"]
        var owner: int = gw.data.get_owner_id(c0.x, c0.y) if gw.data.inside(c0.x, c0.y) else 0
        var idx: int = deposits.find(dp)
        if idx < 0:
                return false
        deposits.remove_at(idx)
        var found: = Vector2i(-1, -1)
        for k in range(2, 60):
                for i in 8 * k:
                        var side: int = i / (2 * k)
                        var o: int = i % (2 * k)
                        var q: Vector2i
                        match side:
                                0:
                                        q = c0 + Vector2i( - k + o, - k)
                                1:
                                        q = c0 + Vector2i(k, - k + o)
                                2:
                                        q = c0 + Vector2i(k - o, k)
                                _:
                                        q = c0 + Vector2i( - k, k - o)
                        if _deposit_spot_ok(q, 8, owner):
                                found = q
                                break
                if found.x >= 0:
                        break
        deposits.insert(idx, dp)
        if found.x < 0:
                return false
        if int(dp["obj"]) >= 0:
                gw.remove_object(int(dp["obj"]))
        var sz: int = int(dp.get("size", 3))
        var nw: Vector2i = found - Vector2i(sz / 2, sz / 2)
        for yy in range(nw.y, nw.y + sz):
                for xx in range(nw.x, nw.x + sz):
                        gw.remove_tree_at(Vector2i(xx, yy))
        var res: String = String(dp.get("res", "titanium"))
        dp["obj"] = gw.add_object(String(DEP_SPRITE[res][1 if bool(dp.get("small", false)) else 0]), nw, GameWorld.KIND_PROP)
        dp["cell"] = found
        draw_ver += 1
        return true





func deposit_at(cell: Vector2i, r: int = 3) -> Dictionary:
        var best: Dictionary = {}
        var bd: int = 1 << 30
        for dp: Dictionary in deposits:
                var dc: Vector2i = dp["cell"]
                var dd: int = maxi(absi(dc.x - cell.x), absi(dc.y - cell.y))
                if dd <= r + int(dp.get("size", 3)) / 2 and dd < bd:
                        bd = dd
                        best = dp
        if best.is_empty():
                return {}
        var c: Vector2i = best["cell"]
        return {"res": String(best.get("res", "titanium")), "left": int(best["left"]), "max": int(best.get("max", best["left"])), 
                "small": bool(best.get("small", false)), "taken_by": best["mine"], "owner": gw.data.get_owner_id(c.x, c.y), "cell": c, "dep": best}



func deposit_hint(dep: Dictionary, c: Country) -> String:
        if dep.is_empty():
                return ""
        var res: String = dep["res"]
        var nm: String = String(RES_NAMES.get(res, res))
        var site: String = Loc.t("нефтевышку") if res == "oil" else (Loc.t("урановую шахту") if res == "uranium" else Loc.t("рудник"))
        var lines: PackedStringArray = PackedStringArray()
        if int(dep["left"]) <= 0 and not GameConfig.infinite_res():
                lines.append(Loc.t("%s: залежь исчерпана.") % nm.capitalize())
        elif dep["taken_by"] != null:
                var f: Facility = dep["taken_by"]
                var oc: Country = gw.country_by_id(f.country_id)
                if c != null and f.country_id == c.id:
                        lines.append(Loc.t("%s: здесь ваш объект — %s, уровень %d. Улучшение ускоряет добычу.") % [nm.capitalize(), Military.title_of(f.kind).to_lower(), f.level])
                else:
                        lines.append(Loc.t("%s: залежь разрабатывает %s. Купите у неё в торговле или захватите город рядом.") % [nm.capitalize(), oc.name if oc != null else Loc.t("другая страна")])
        else:
                lines.append(Loc.t("%s: поставьте %s прямо на залежь.") % [nm.capitalize(), site])
                var own: int = int(dep["owner"])
                if c != null and own != c.id:
                        if own == 0:
                                lines.append(Loc.t("Нужна своя земля — расширяйте границы: основайте город рядом."))
                        else:
                                var o2: Country = gw.country_by_id(own)
                                lines.append(Loc.t("Это земля страны %s: торгуйте с ней или захватите город рядом.") % (o2.name if o2 != null else "?"))
        lines.append(Loc.t("Запас: %s%s.") % [reserve_text(int(dep["left"]), int(dep["max"]), Loc.t(" из ")), Loc.t(" — залежь не иссякает") if GameConfig.infinite_res() else (Loc.t(" (малая залежь)") if bool(dep["small"]) else "")])
        lines.append(String(DEP_USE.get(res, "")))
        return "\n".join(lines)


func level_of(f: Facility) -> int:
        return f.level if f != null else 1


func level_mul(f: Facility) -> float:
        return float(LEVEL_MUL[clampi(f.level, 1, MAX_LEVEL)])


static func kind_upgradable(kind: int) -> bool:
        return UPG_RES.has(kind)





func can_upgrade(f: Facility) -> bool:
        return f != null and UPG_RES.has(f.kind) and f.level < MAX_LEVEL and gw.mil.alive(f) and f.upg_t <= 0.0



func upgrade_cost(f: Facility) -> Dictionary:
        if f == null or not UPG_RES.has(f.kind) or f.level >= MAX_LEVEL:
                return {}
        var out: Dictionary = (UPG_RES[f.kind][f.level - 1] as Dictionary).duplicate()
        out["money"] = int(float(Military.cost_of(f.kind)) * (0.6 if f.level == 1 else 1.0))
        return out


func extras_of(f: Facility) -> Array:
        return _extras.get(f, [])



func _bonus(c: Country) -> Dictionary:
        if _cap_bonus.has(c.id):
                return _cap_bonus[c.id]
        var out: Dictionary = {}
        for f: Facility in gw.mil.facilities:
                if f.country_id == c.id and f.level > 1 and gw.mil.alive(f):
                        var r: String = out_res(f)
                        if r != "":
                                out[r] = int(out.get(r, 0)) + LEVEL_CAP * (f.level - 1)
        if not ui_time():
                _cap_bonus[c.id] = out
        return out



static func reserve_text(left: int, mx: int = -1, sep: String = "/") -> String:
        if GameConfig.infinite_res():
                return "∞"
        return str(left) if mx < 0 else "%d%s%d" % [left, sep, mx]


static func is_deep(kind: int) -> bool:
        return kind == Facility.Kind.MINE or kind == Facility.Kind.OIL_RIG



func deep_name(f: Facility, lvl: int = -1) -> String:
        if f == null or not DEEP_NAMES.has(f.kind):
                return ""
        return String((DEEP_NAMES[f.kind] as Array)[clampi(f.level if lvl < 0 else lvl, 1, MAX_LEVEL)])



func deep_add(f: Facility, lvl: int) -> int:
        if f == null or f.deposit.is_empty() or lvl < 2 or lvl > MAX_LEVEL or GameConfig.infinite_res():
                return 0
        var res: String = String(f.deposit.get("res", "oil"))
        var base: float = float(DEP_AMOUNT.get(res, 600)) * (0.6 if bool(f.deposit.get("small", false)) else 1.0)
        return roundi(base * float(DEEP_ADD[lvl]) * GameConfig.reserve_mul() / 10.0) * 10



func deep_sprite(f: Facility) -> String:
        var res: String = String(f.deposit.get("res", "titanium")) if not f.deposit.is_empty() else "titanium"
        if f.kind == Facility.Kind.MINE:
                if f.level >= 2:
                        return "mine27_l%d_%s" % [mini(f.level, MAX_LEVEL), String(DEEP_ORE.get(res, "ti"))]
                return String({"metal": "mine_metal", "precious": "mine_precious"}.get(res, "mine"))
        if f.level >= 2:
                return "rig27_l%d" % mini(f.level, MAX_LEVEL)
        return "oil_rig"


func _deep_apply_sprite(f: Facility) -> void :
        if f == null or f.main_obj < 0 or not is_deep(f.kind):
                return
        var nm: String = deep_sprite(f)
        if gw.spr_index.has(nm):
                gw.set_obj_frame(f.main_obj, nm, 0)



func deep_low(f: Facility) -> bool:
        if f == null or not is_deep(f.kind) or f.deposit.is_empty() or f.level >= MAX_LEVEL or f.upg_t > 0.0 or GameConfig.infinite_res():
                return false
        var left: int = int(f.deposit.get("left", 0))
        var rate: float = maxf(1.0, base_rate(f) * level_mul(f))
        return float(left) <= rate * DEEP_LOW_TICKS or float(left) <= 0.15 * float(maxi(1, int(f.deposit.get("max", 1))))



func _deep_reserve(f: Facility) -> int:
        var dp: Dictionary = f.deposit
        if dp.is_empty():
                return 0
        var done: int = int(dp.get("deep_lv", 1))
        var add: int = 0
        for l: int in range(done + 1, f.level + 1):
                add += deep_add(f, l)
        if add > 0:
                dp["left"] = int(dp["left"]) + add
                dp["max"] = int(dp.get("max", dp["left"])) + add
        dp["deep_lv"] = maxi(done, f.level)
        return add



func _ab_keep(c: Country, res: String) -> int:
        var d: Dictionary = (autobuy.get(str(c.id), {}) as Dictionary).get(res, {})
        return int(d.get("hi", 0)) if bool(d.get("on", false)) else 0
