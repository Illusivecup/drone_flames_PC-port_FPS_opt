class_name GameWorld
extends "res://game/game_world/gw_states.gd"




func _ready() -> void :
        Sfx.attach_world(self)
        atlas = SpriteAtlas.load_atlas("res://assets/sprites/atlas_world.png", "res://assets/sprites/atlas_world.json")
        fx_atlas = SpriteAtlas.load_atlas("res://assets/sprites/atlas_fx.png", "res://assets/sprites/atlas_fx.json")
        atlas2 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_world2.png", "res://assets/sprites/atlas_world2.json")
        atlas3 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_world3.png", "res://assets/sprites/atlas_world3.json")
        atlas4 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_world4.png", "res://assets/sprites/atlas_world4.json")
        atlas5 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_world5.png", "res://assets/sprites/atlas_world5.json")
        fx_atlas2 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_fx2.png", "res://assets/sprites/atlas_fx2.json")
        fx_atlas3 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_fx3.png", "res://assets/sprites/atlas_fx3.json")
        atlas6 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_world6.png", "res://assets/sprites/atlas_world6.json")
        atlas7 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_world7.png", "res://assets/sprites/atlas_world7.json")
        fx_atlas4 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_fx4.png", "res://assets/sprites/atlas_fx4.json")
        life_atlas = SpriteAtlas.load_atlas("res://assets/sprites/atlas_life.png", "res://assets/sprites/atlas_life.json")
        atlas8 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_world8.png", "res://assets/sprites/atlas_world8.json")
        fx_atlas5 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_fx5.png", "res://assets/sprites/atlas_fx5.json")
        atlas9 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_world9.png", "res://assets/sprites/atlas_world9.json")
        atlas10 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_world10.png", "res://assets/sprites/atlas_world10.json")
        atlas11 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_world11.png", "res://assets/sprites/atlas_world11.json")
        atlas12 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_world12.png", "res://assets/sprites/atlas_world12.json")
        fx_atlas6 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_fx6.png", "res://assets/sprites/atlas_fx6.json")
        fx_atlas7 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_fx7.png", "res://assets/sprites/atlas_fx7.json", true)
        atlas13 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_world13.png", "res://assets/sprites/atlas_world13.json")
        atlas_crane = SpriteAtlas.load_atlas("res://assets/sprites/atlas_fui_crane.png", "res://assets/sprites/atlas_fui_crane.json", true)
        fx_atlas8 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_fx8.png", "res://assets/sprites/atlas_fx8.json")
        atlas_navy1 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_navy1.png", "res://assets/sprites/atlas_navy1.json", true)
        fx_atlas_navy = SpriteAtlas.load_atlas("res://assets/sprites/atlas_fx_navy.png", "res://assets/sprites/atlas_fx_navy.json", true)
        atlas_cm28 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_cm28.png", "res://assets/sprites/atlas_cm28.json", true)
        atlas_mines27 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_mines27.png", "res://assets/sprites/atlas_mines27.json", true)
        atlas_uran30 = SpriteAtlas.load_atlas("res://assets/sprites/atlas_uran30.png", "res://assets/sprites/atlas_uran30.json", true)
        _build_sprite_table()
        Flora.register(self)
        ArchStyle.register(self)
        DmgStages.register(self)
        BorderPosts.register(self)
        terrain = TerrainView.new()
        terrain.name = "Terrain"
        add_child(terrain)
        add_child(DecalLayer.make(self, 1))
        add_child(DecalLayer.make(self, 0))
        ground = GroundLayer.new()
        ground.name = "Ground"
        ground.gw = self
        add_child(ground)
        forts = FortLayer.new()
        forts.name = "Forts"
        forts.gw = self
        add_child(forts)
        add_child((load("res://world/nature_layer.gd") as GDScript).call("make", self))
        add_child(FogLayer.make_cover(self))
        territory = Sprite2D.new()
        territory.name = "Territory"
        territory.centered = false
        territory.scale = Vector2(4, 4)
        territory.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        var mat: = ShaderMaterial.new()
        mat.shader = load("res://world/territory.gdshader") as Shader
        territory.material = mat
        add_child(territory)
        objects = ObjectsLayer.new()
        objects.name = "Objects"
        add_child(objects)
        city_power = CityPowerLayer.new()
        city_power.name = "CityPower"
        city_power.gw = self
        add_child(city_power)
        territory_border = Sprite2D.new()
        territory_border.name = "TerritoryBorder"
        territory_border.centered = false
        territory_border.scale = Vector2(4, 4)
        territory_border.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        var bmat: = ShaderMaterial.new()
        bmat.shader = mat.shader
        bmat.set_shader_parameter("mode", 1)
        territory_border.material = bmat
        add_child(territory_border)
        life = LifeLayer.new()
        life.name = "Life"
        life.gw = self
        add_child(life)
        add_child(EcoLayer.make(self))
        add_child(NavalLayer.make(self))
        add_child(NavyLayer.make(self))
        add_child(TradeLayer.make(self))
        units_ground = UnitsLayer.new()
        units_ground.name = "UnitsGround"
        units_ground.gw = self
        add_child(units_ground)
        fx = FxLayer.new()
        fx.name = "Fx"
        add_child(fx)
        fx.setup(self, fx_atlas, [fx_atlas2, fx_atlas3, fx_atlas4, fx_atlas5, fx_atlas6, fx_atlas7, fx_atlas8, fx_atlas_navy])
        units_air = UnitsLayer.new()
        units_air.name = "UnitsAir"
        units_air.gw = self
        units_air.air = true
        add_child(units_air)
        add_child(FogLayer.make(self))
        add_child(OpsLayer.make(self))
        add_child((load("res://world/sky_cover_layer.gd") as GDScript).call("make", self))
        add_child((load("res://world/hold_layer.gd") as GDScript).call("make", self))
        add_child((load("res://world/capture_layer.gd") as GDScript).call("make", self))
        top = TopLayer.new()
        top.name = "Top"
        top.gw = self
        add_child(top)
        night = NightLayer.new()
        night.name = "Night"
        night.gw = self
        add_child(night)
        map_layer = MapModeLayer.make(self)
        add_child(map_layer)
        add_child(EconFxLayer.make(self))
        vfx = Vfx.make(self)
        labels = LabelsLayer.make(self)
        add_child((load("res://world/strat_layer.gd") as GDScript).call("make", self))


func _build_sprite_table() -> void :
        for at: SpriteAtlas in [atlas, atlas2, atlas3, atlas4, atlas6, atlas7, atlas8, atlas9, atlas10, atlas11, atlas12, atlas13, atlas_navy1, atlas_mines27, atlas_uran30]:
                _add_sprites(at)
        spr_ruin.resize(spr_rect.size())
        for i in spr_rect.size():
                var sname: String = spr_name[i]
                var ruin: String = sname + "_ruin"
                if spr_index.has(ruin):
                        spr_ruin[i] = int(spr_index[ruin])
                elif sname.begins_with("ad_") and spr_index.has(sname.trim_suffix("_hull") + "_hull_ruin"):
                        spr_ruin[i] = int(spr_index[sname.trim_suffix("_hull") + "_hull_ruin"])
                elif sname.begins_with("tel") and spr_index.has("tel_ruin"):
                        spr_ruin[i] = int(spr_index["tel_ruin"])
                elif sname.begins_with("tree_") or sname == "bush_a":
                        spr_ruin[i] = int(spr_index.get("tree_burnt", -1))
                else:
                        spr_ruin[i] = -1


func _add_sprites(at: SpriteAtlas) -> void :
        for sname: String in at.sprites:
                var s: Dictionary = at.sprites[sname]
                if String(s.get("kind", "")).begins_with("unit"):
                        continue
                spr_index[sname] = spr_rect.size()
                spr_tex.append(at.texture)
                spr_name.append(sname)
                spr_rect.append(Rect2(float(s["x"]), float(s["y"]), float(s["w"]), float(s["h"])))
                spr_anchor.append(Vector2(float(s["ax"]), float(s["ay"])))
                spr_fw.append(int(s["fw"]))
                spr_fd.append(int(s["fd"]))
                spr_frames.append(int(s["frames"]))




func new_world(s: WorldSettings) -> void :
        settings = s
        rng = Rng.new(s.world_seed + 99)
        countries.clear()
        id_style = -1
        cities.clear()
        drain_jobs()
        bridges.clear()
        bridge_cells.clear()
        road_paths.clear()
        checkpoints.clear()
        _delayed.clear()
        _enc_drain()
        _enc_t = 0.0
        enc_moved = 0
        _xb_tries = 0
        _xb_made = 0
        _xb_second = false
        xb_mids.clear()
        player = null
        mil = Military.new(self)
        mil.forts_changed.connect(forts.queue_redraw)
        forts.queue_redraw()
        diplo = Diplomacy.new(self)
        econ = Economy.new(self)
        army = Army.new(self)
        defense = Defense.new(self)
        session = Match.new(self)
        ai = AiBots.new(self)
        vision = Vision.new(self)
        ops = Operations.new(self)
        battle_watch = BattleWatch.new(self)
        recon = Recon.new(self)
        guide = EconGuide.new(self)
        protect = Protect.new(self)
        naval = Naval.new(self)
        navy = Navy.new(self)
        supply = Supply.new(self)
        arch = ArchStyle.new(self)
        kpp = BorderPosts.new(self)
        hold = (load("res://game/urban_hold.gd") as GDScript).new(self)
        aftermath = preload("res://game/aftermath.gd").new(self)
        pstat = PowerStatus.new(self)
        drama = preload("res://game/world_drama.gd").new(self)
        candy_events = CandyEvents.new(self)
        fires.clear()
        ruins.clear()
        _ruin_t = 0.0
        _fire_snd_t = 0.0
        _enc_queue.clear()
        strike_net = null
        obj_fix.clear()
        city_power._cells.clear()
        game_time = 0.0
        _expand_t = 0.0
        _ai_t = 0.0
        _checkpoints_dirty = false
        fx.reset()
        obj_spr = PackedInt32Array()
        Country.mlog_on = false
        Country.mlog.clear()
        obj_x = PackedInt32Array()
        obj_y = PackedInt32Array()
        obj_state = PackedByteArray()
        obj_kind = PackedByteArray()
        obj_hidden = PackedByteArray()
        obj_arch = PackedByteArray()
        tree_at.clear()
        _free_ids = PackedInt32Array()
        _job_first.clear()
        ground.decals.clear()
        top.clear_all()
        data = WorldGen.generate(s)
        nature = preload("res://game/nature.gd").new(self)
        border_noise = WorldGen._noise_layer(data.w, data.h, maxi(4, data.w / 40), s.world_seed + 4040)
        terrain.build(data)
        territory_img = Image.create_from_data(data.w, data.h, false, Image.FORMAT_L8, data.owners)
        territory_tex = ImageTexture.create_from_image(territory_img)
        territory.texture = territory_tex
        territory_border.texture = territory_tex
        (territory.material as ShaderMaterial).set_shader_parameter("owner_tex", territory_tex)
        (territory_border.material as ShaderMaterial).set_shader_parameter("owner_tex", territory_tex)
        _update_territory_colors()
        objects.setup(self)
        _spawn_trees()
        rail = null
        econ.generate_deposits()
        econ.build_nav()
        rail = Rail.new(self)
        Operations.MAX_RANGE = maxf(3200.0, float(data.w * CELL) * 0.7)
        Defense.apply_map(data.w)
        life.reset()
        night.reset()
        ground.queue_redraw()
        if camera != null:
                camera.world_px = Vector2(data.w * CELL, data.h * CELL)
                camera.center_on(camera.world_px * 0.5)
        cad344 = Cad344.new(self)
        cad344.phase_offsets()
        changed.emit()


func _spawn_trees() -> void :
        if settings.gen_version >= 2 and Flora.ready(self):
                Flora.spawn_trees(self)
                return
        var t0: int = Time.get_ticks_msec()
        var dens: = PackedInt32Array()
        dens.resize(32)
        for k: int in TREE_DENSITY:
                dens[k] = int(TREE_DENSITY[k]) * (50 + settings.forests) / 100
        var name_ids: Array = []
        name_ids.resize(32)
        for k: int in TREE_NAMES:
                var ids: = PackedInt32Array()
                for n: String in TREE_NAMES[k]:
                        ids.append(int(spr_index[n]))
                name_ids[k] = ids
        var w: int = data.w
        var sd: int = data.world_seed + 5
        for y in data.h:
                for x in w:
                        var b: int = data.biome[y * w + x]
                        var dn: int = dens[b]
                        if dn == 0:
                                continue
                        var hh: int = Hash32.h2(x, y, sd)
                        if (hh & 255) >= dn:
                                continue
                        var ids: PackedInt32Array = name_ids[b]
                        var id: int = _add_object_id(ids[(hh >> 8) % ids.size()], x, y, KIND_TREE)
                        tree_at[y * w + x] = id
        print("[GameWorld] trees: %d in %d ms" % [obj_spr.size(), Time.get_ticks_msec() - t0])


func cmd_static(c: Country, mod: String, fn: String, args: Array) -> Variant:
        if c == null or not _NET_STATIC.has(mod) or not (_NET_STATIC[mod] as Array).has(fn):
                return null
        var scr: GDScript = load({"groups": "res://game/army_groups.gd", "front": "res://game/front_plan.gd", 
                "ship_cr": "res://game/navy_strike.gd"}[mod]) as GDScript
        for i in args.size():
                if args[i] is PackedInt32Array:
                        var own: = PackedInt32Array()
                        for fid: int in args[i]:
                                var f: Facility = (load("res://game/army_groups.gd") as GDScript).call("fac", self, fid)
                                if f != null and f.country_id == c.id:
                                        own.append(fid)
                        args[i] = own
        return scr.callv(fn, [self, c.id] + args)


func cmd_strike(c: Country, all: Dictionary, together: bool) -> Dictionary:
        if strike_net == null:
                strike_net = (load("res://game/strike_hub.gd") as GDScript).new()
        var hub: GDScript = strike_net.get_script()
        hub.set("actor", c)
        var r: Dictionary = strike_net.call("fire", self, all, together)
        hub.set("actor", null)
        return r



func _net_prune() -> void :
        var ag: GDScript = load("res://game/army_groups.gd") as GDScript
        for c: Country in countries:
                if c.is_player:
                        ag.call("prune", self, c.id)



func cmd_refill_all(c: Country, on: bool) -> int:
        var n: int = 0
        for f: Facility in mil.facilities:
                if f.kind == Facility.Kind.BARRACKS and f.country_id == c.id and mil.alive(f):
                        f.auto_refill = on
                        if on and f.prod_type == 3:
                                f.prod_type = 0
                        n += 1
        return n



func net_step(dt: float) -> void :
        net_tick += 1
        rng.log_on = true
        rng.log_tick = net_tick
        Country.mlog_on = true
        Country.mlog_tick = net_tick
        _sim_step(dt)
        if strike_net != null:
                strike_net.call("tick", self)
        if net_tick % 30 == 0:
                _net_prune()
        _poll_roads()
        if life != null:
                life.sim_trucks(dt)
        if _checkpoints_dirty:
                _update_checkpoints()


func _process(delta: float) -> void :
        if data == null:
                return
        if net_driven:
                if vision != null:
                        vision.update(delta)
                terrain.flush()
                _flush_territory()
                return
        var total: float = delta * time_scale
        var n: int = mini(SIM_MAX_STEPS, ceili(total / SIM_STEP - 0.001)) if total > 0.0 else 0
        var us: int = Time.get_ticks_usec()
        var step: float = minf(total / float(maxi(1, n)), SIM_STEP * 1.5)
        var done: int = 0
        for i in n:
                _sim_step(step)
                done += 1
                if Time.get_ticks_usec() - us > int(sim_budget_ms * 1000.0):
                        break
        sim_lag = maxf(0.0, total - step * float(done))
        sim_steps = done
        sim_ms = lerpf(sim_ms, float(Time.get_ticks_usec() - us) / 1000.0, 0.2)
        _poll_roads()
        if vision != null:
                vision.update(delta)
        terrain.flush()
        _flush_territory()
        if _checkpoints_dirty:
                _update_checkpoints()


func _sim_step(dt: float) -> void :
        if perf_prof:
                _pu = Time.get_ticks_usec()
        game_time += dt
        if cad344 != null:
                cad344.step(dt)
        if not _delayed.is_empty():
                var due: Array = []
                for k in range(_delayed.size() - 1, -1, -1):
                        if game_time >= float(_delayed[k][0]):
                                due.append(_delayed[k])
                                _delayed.remove_at(k)
                due.reverse()
                if perf_prof:
                        _pf("due.reverse")
                for d: Array in due:
                        (d[1] as Callable).call()
                        if perf_prof:
                                _pf("delayed:" + str((d[1] as Callable).get_method()))
        if dt > 0.0:



                var pe: float = _expand_t
                _expand_t += dt
                var nsl: int = Cad344.EXP_SLICES if cad344 != null else EXP_SLICES
                for ph in nsl:
                        var th: float = EXPAND_DT * float(ph + 1) / float(nsl)
                        if pe < th and _expand_t >= th:
                                if cad344 != null:
                                        _expand_tick(ph, nsl)
                                else:
                                        _expand_tick(ph)
                                if perf_prof:
                                        _pf("_expand_tick")
                if _expand_t >= EXPAND_DT:
                        _expand_t = 0.0
                _enclave_tick(dt)
                if perf_prof:
                        _pf("_enclave_tick")
                _ai_t += dt
                if _ai_t >= AI_TOWN_DT:
                        _ai_t = 0.0
                        for c: Country in countries:
                                if not c.is_player and c.city_ids.size() < 6:
                                        if cad344 != null:
                                                cad344.town_q.append(c.id)
                                                continue
                                        _ai_try_town(c)
                                        if perf_prof:
                                                _pf("_ai_try_town")
                while cad344 != null and not cad344.town_q.is_empty() and cad344.take_ai_slot():
                        var tc: Country = country_by_id(int(cad344.town_q.pop_front()))
                        if tc != null and not tc.is_player and not tc.eliminated and tc.city_ids.size() < 6:
                                _ai_try_town(tc)
                                if perf_prof:
                                        _pf("_ai_try_town")
                _update_bridges(dt)
                if perf_prof:
                        _pf("_update_bridges")
                mil.update(dt)
                if perf_prof:
                        _pf("mil.update")
                diplo.update(dt)
                if perf_prof:
                        _pf("diplo.update")
                econ.update(dt)
                if perf_prof:
                        _pf("econ.update")
                rail.update(dt)
                if perf_prof:
                        _pf("rail.update")
                army.update(dt)
                if perf_prof:
                        _pf("army.update")
                if aftermath != null:
                        aftermath.update(dt)
                        if perf_prof:
                                _pf("aftermath.update")
                if nature != null:
                        nature.update(dt)
                        if perf_prof:
                                _pf("nature.update")
                if vfx != null:
                        vfx.sim_tick()
                        if perf_prof:
                                _pf("vfx.sim_tick")
                defense.update(dt)
                if perf_prof:
                        _pf("defense.update")
                defense.update_shots(dt)
                if perf_prof:
                        _pf("defense.update_shots")
                session.update(dt)
                if perf_prof:
                        _pf("session.update")
                ai.update(dt)
                if perf_prof:
                        _pf("ai.update")
                if ops != null:
                        ops.update(dt)
                        if perf_prof:
                                _pf("ops.update")
                if guide != null:
                        guide.update(dt)
                        if perf_prof:
                                _pf("guide.update")
                if protect != null:
                        protect.update(dt)
                        if perf_prof:
                                _pf("protect.update")
                if naval != null:
                        naval.update(dt)
                        if perf_prof:
                                _pf("naval.update")
                if navy != null:
                        navy.update(dt)
                        if perf_prof:
                                _pf("navy.update")
                if supply != null:
                        supply.update(dt)
                        if perf_prof:
                                _pf("supply.update")
                if arch != null:
                        arch.update(dt)
                        if perf_prof:
                                _pf("arch.update")
                if kpp != null:
                        kpp.update(dt)
                        if perf_prof:
                                _pf("kpp.update")
                if hold != null:
                        hold.update(dt)
                        if perf_prof:
                                _pf("hold.update")
                _update_fires_ruins(dt)
                if perf_prof:
                        _pf("_update_fires_ruins")
                if pstat != null:
                        pstat.update(dt)
                        if perf_prof:
                                _pf("pstat.update")
                if drama != null:
                        drama.update(dt)
                        if perf_prof:
                                _pf("drama.update")
                if candy_events != null:
                        candy_events.update(dt)
                        if perf_prof:
                                _pf("candy.update")


func _pf(nm: String) -> void :
        var now: int = Time.get_ticks_usec()
        var d: float = float(now - _pu) / 1000.0
        if d > float(perf_sys.get(nm, 0.0)):
                perf_sys[nm] = d
        _pu = now


func _exit_tree() -> void :
        drain_jobs()
        for key: String in ["fire", "siren", "drone", "heli"]:
                Sfx.loop(key, "", false)
        Sfx.detach_world(self)


## Преобразование экранных координат в координаты ячейки карты (для модов и UI)
func cell_at_screen(screen_pos: Vector2) -> Vector2i:
        if camera != null:
                var wp: Vector2 = camera.screen_to_world(screen_pos)
                return Vector2i(floori(wp.x / float(CELL)), floori(wp.y / float(CELL)))
        return Vector2i(floori(screen_pos.x / float(CELL)), floori(screen_pos.y / float(CELL)))
