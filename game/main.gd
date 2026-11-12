extends "res://game/main/main_input.gd"

const KeybindManager = preload("res://core/keybind_manager.gd")

var _rmb_down: bool = false
var _rmb_dragged: bool = false
var _rmb_start_pos: Vector2 = Vector2.ZERO
var _dyn_fps_stage: int = 0
var _dyn_fps_timer: float = 0.0
var _dyn_fps_low_time: float = 0.0
var _dyn_fps_high_time: float = 0.0
var _playtime_accum: float = 0.0






func _ready() -> void :
        RenderingServer.set_default_clear_color(Palette.c("water_deep"))
        world = GameWorld.new()
        world.name = "World"
        add_child(world)
        cam = MapCamera.new()
        cam.name = "Camera"
        add_child(cam)
        cam.make_current()
        cam.zoom_changed.connect(_on_zoom)
        world.camera = cam
        world.selected_fn = follow_drone
        world.selected_fac_fn = func() -> Facility: return selected_fac
        world.missile_launched.connect(_on_missile_launched)
        hud = Hud.new()
        hud.name = "Hud"
        add_child(hud)
        hud.setup(self, world)
        hud.action.connect(_on_action)
        _ghost = Node2D.new()
        _ghost.name = "PendingGhost"
        _ghost.z_index = 60
        _ghost.draw.connect(_draw_ghost)
        world.add_child(_ghost)
        overlay = RouteOverlay.new()
        overlay.name = "RouteOverlay"
        overlay.gw = world
        overlay.main_node = self
        hud.add_child(overlay)
        hud.move_child(overlay, 0)
        net = NetSession.new()
        net.name = "Net"
        add_child(net)
        net.setup(self)
        menus = Menus.new()
        menus.name = "Menus"
        add_child(menus)
        menus.setup(world)
        menus.net = net
        menus.request.connect(_on_menu)
        tutorial = Tutorial.new()
        tutorial.name = "Tutorial"
        add_child(tutorial)
        tutorial.setup(world, hud)
        world.news.connect(hud.push_news)
        world.war_declared.connect(_on_war)
        world.match_ended.connect(_on_match_end)
        world.city_captured.connect(_on_city_captured)
        world.offer_received.connect(_on_offer)
        loading = Loading.new()
        loading.name = "Loading"
        add_child(loading)
        if LangPicker.needed(self):
                await LangPicker.first_run(self)
        if Opening.should_autoplay(self):
                await play_opening(true)
        else:
                loading.show_screen("Создаём мир...")
        _snd("set_listener", [cam])
        settings = WorldSettings.new()
        await get_tree().process_frame
        _main_menu()
        var all_args: Array = OS.get_cmdline_user_args()
        all_args.append_array(OS.get_cmdline_args())
        print("[MainReady] All cmdline args received: ", all_args)
        for a: String in all_args:
                if a.begins_with("--net-test="):
                        var nt: RefCounted = (load("res://dev/net_autotest.gd") as GDScript).new()
                        set_meta("net_test", nt)
                        nt.call("run", self, a)
                elif a.begins_with("--mp-shots="):
                        var ms: RefCounted = (load("res://dev/mp_shots.gd") as GDScript).new()
                        set_meta("mp_shots", ms)
                        ms.call("run", self, a)
                elif a.begins_with("--impossible-shots"):
                        var ishots: RefCounted = (load("res://dev/impossible_shots.gd") as GDScript).new()
                        set_meta("impossible_shots", ishots)
                        ishots.call("run", self, a)
                elif a == "--bench":
                        # Фиксированный сид мира — воспроизводимые A/B-замеры.
                        if OS.get_environment("DF_SEED") != "":
                                GameConfig.map_seed = int(OS.get_environment("DF_SEED"))
                        else:
                                GameConfig.map_seed = 424242
                        var bn: RefCounted = (load("res://dev/bench_late.gd") as GDScript).new()
                        set_meta("bench_late", bn)
                        bn.call("run", self)
                elif a == "--bench-acq":
                        var ba: RefCounted = (load("res://dev/bench_acq.gd") as GDScript).new()
                        set_meta("bench_acq", ba)
                        ba.call("run", self)
                elif a == "--bench-nat2":
                        var bn2: RefCounted = (load("res://dev/bench_nat2.gd") as GDScript).new()
                        set_meta("bench_nat2", bn2)
                        bn2.call("run", self)
                elif a == "--verify":
                        var v: RefCounted = (load("res://dev/verify_game.gd") as GDScript).new()
                        set_meta("verify_game", v)
                        v.call("run", self)
                elif a == "--local-workshop-test":
                        var workshop_test: RefCounted = (load("res://dev/local_workshop_test.gd") as GDScript).new()
                        set_meta("local_workshop_test", workshop_test)
                        workshop_test.call("run", self)
                elif a.begins_with("--lan-smoke="):
                        var lan_test: RefCounted = (load("res://dev/lan_smoke_test.gd") as GDScript).new()
                        set_meta("lan_smoke_test", lan_test)
                        lan_test.call("run", self, a.get_slice("=", 1))
                elif a.begins_with("--mp-resilience=") or a.begins_with("--lan-resilience="):
                        var mp_res: RefCounted = (load("res://dev/mp_resilience_test.gd") as GDScript).new()
                        set_meta("mp_resilience", mp_res)
                        mp_res.call("run", self, a.get_slice("=", 1))
                elif a == "--graphics-test":
                        var gfx_test: RefCounted = (load("res://dev/graphics_test.gd") as GDScript).new()
                        set_meta("gfx_test", gfx_test)
                        gfx_test.call("run", self)
                elif a == "--profile-saved-game":
                        var save_profile: RefCounted = (load("res://dev/profile_saved_game.gd") as GDScript).new()
                        set_meta("save_profile", save_profile)
                        save_profile.call("run", self)
                elif a == "--combat-performance-test":
                        var combat_test: RefCounted = (load("res://dev/combat_performance_test.gd") as GDScript).new()
                        set_meta("combat_performance_test", combat_test)
                        combat_test.call("run", self)
                elif a == "--police-test":
                        var police_test: RefCounted = (load("res://dev/police_test.gd") as GDScript).new()
                        set_meta("police_test", police_test)
                        police_test.call("run", self)
                elif a == "--create-nuke-save":
                        var cns: RefCounted = (load("res://dev/create_nuke_save.gd") as GDScript).new()
                        set_meta("create_nuke_save", cns)
                        cns.call("run", self)
                elif a.begins_with("--airborne-demo"):
                        var ad: RefCounted = (load("res://dev/airborne_demo.gd") as GDScript).new()
                        set_meta("airborne_demo", ad)
                        ad.call("run", self)



func _main_menu() -> void :
        in_menu = true
        if has_node("/root/ModManager"):
                get_node("/root/ModManager").clear_active_world()
        tutorial.stop()
        hud.visible = false
        menus.close()
        hud.close_panel()
        if not loading.visible:
                loading.show_screen("Создаём мир...")
        loading.set_progress(0.1, "Рельеф, реки и леса...")
        for _i in 3:
                await get_tree().process_frame
        var s: = WorldSettings.new()
        s.world_seed = randi() % 100000000
        if GameConfig.map_seed >= 0:
                # Фиксированный сид (бенчмарк --bench, DF_SEED) — воспроизводимые замеры.
                s.world_seed = GameConfig.map_seed
                GameConfig.map_seed = -1
        s.size = 256
        settings = s
        _deselect()
        _clear_plan()
        world.new_world(s)
        loading.set_progress(0.7, "Страны и города...")
        for _i in 2:
                await get_tree().process_frame
        world.spawn_ai_countries(4)
        world._flush_territory()
        world.time_scale = 2.0
        cam.set_zoom_at(MapCamera.zk(1.0), cam.view_size() * 0.5)
        _on_zoom(1.0)
        var caps: Array = []
        for c: City in world.cities:
                if c.kind == City.Kind.CAPITAL:
                        caps.append(c)
        if not caps.is_empty():
                cam.center_on(Vector2((caps[0] as City).center * GameWorld.CELL))
        mode = Mode.NONE
        loading.finish()
        _snd("music", ["menu"])
        _snd("loop", ["amb_wind", "ambient_wind_loop", true, Vector2.INF, -16.0])
        menus.show_main()




func play_opening(boot: bool) -> void :
        var op: = Opening.new()
        op.name = "Opening"
        if boot:
                op.reveal.connect( func() -> void : loading.show_screen("Создаём мир..."))
        else:
                _snd("music", [""])
        add_child(op)
        await op.finished
        if not boot:
                _snd("music", ["menu" if in_menu else "game"])


func _on_menu(req: String) -> void :
        match req:
                "watch_opening":
                        menus.close()
                        await play_opening(false)
                        menus.show_settings_sub("opening")
                "main":
                        menus.show_main()
                "setup":
                        if net.in_match:
                                net.leave()
                                return
                        if not in_menu:
                                _main_menu()
                        menus.show_setup()
                "mp":
                        menus.show_mp()
                "mp_lobby":
                        menus.show_lobby()
                "settings_main":
                        menus.show_settings(false)
                "settings_pause":
                        menus.show_settings(true)
                "mods":
                        if GameConfig.mods_enabled:
                                menus.show_mods()
                        else:
                                menus.show_mods_settings(false)
                "start":
                        GameConfig.tutorial = false
                        if GameConfig.cb_on:
                                CustomBots.sanitize()
                                if GameConfig.cb_list.is_empty():
                                        menus.show_custom_bots()
                                        return
                        _new_game()
                "tutorial", "tutorial_restart":
                        if net.in_match:
                                net.leave()
                                return

                        var keep: Array = [GameConfig.bots, GameConfig.difficulty, GameConfig.aggression, GameConfig.size_i]
                        GameConfig.tutorial = true
                        GameConfig.bots = 2
                        GameConfig.difficulty = 0
                        GameConfig.aggression = 0
                        GameConfig.size_i = 0
                        _new_game()
                        GameConfig.bots = keep[0]
                        GameConfig.difficulty = keep[1]
                        GameConfig.aggression = keep[2]
                        GameConfig.size_i = keep[3]
                "pause":
                        menus.show_pause()
                "scores":
                        menus.show_scores()
                "resume", "continue":
                        menus.close()
                        _paused = _menu_paused
                        _menu_paused = false
                        _apply_speed()
                "restart":
                        if net.in_match:
                                net.leave()
                                return
                        _new_game()
                "quit":
                        if net != null and net.in_match:
                                net.leave()
                        elif not in_menu:
                                Save.save_game(self)
                        get_tree().quit()
                "main_menu":
                        if net.in_match:
                                if net.reconnecting or net.rejoining:
                                        net.leave(true, true, true)
                                else:
                                        net.leave()
                                return
                        Save.save_game(self)
                        _main_menu()
                "mp_start":
                        var whys: String = net.host_start()
                        if whys != "":
                                menus.show_lobby(whys)
                "load_save":
                        if net.in_match:
                                net.leave()
                                return
                        menus.close()
                        hud.hide_prompt()
                        if not await Save.load_game(self):
                                _main_menu()
                                hud.show_toast("Сохранение повреждено")
                        else:
                                _plan_refresh()
                                if has_node("/root/ModManager"):
                                        var mod_manager: Node = get_node("/root/ModManager")
                                        mod_manager.set_active_world(self, world)
                                        mod_manager.call_hook("on_world_started", [self, world])


func _new_game() -> void :
        RankedRules.clear()

        Save.begin_new()
        hud.hide_prompt()
        menus.close()
        in_menu = false
        hud.visible = true
        var s: = WorldSettings.new()
        s.world_seed = randi() % 100000000
        if GameConfig.map_seed >= 0:
                # Фиксированный сид (бенчмарк --bench, DF_SEED) — воспроизводимые замеры.
                s.world_seed = GameConfig.map_seed
                GameConfig.map_seed = -1
        s.size = int(GameConfig.SIZES[GameConfig.size_i])
        GameConfig.apply_map(s, true)
        GameConfig.bots = maxi(1, GameConfig.bots)
        _paused = false
        _speed_i = 0
        start_world(s)
        if GameConfig.tutorial:
                tutorial.start()
        else:
                tutorial.stop()


func start_world(s: WorldSettings) -> void :
        settings = s
        if not net.in_match:
                world.net_driven = false
        loading.show_screen("Генерация мира...")
        _deselect()
        _clear_plan()
        hud.close_panel()
        loading.set_progress(0.15, "Рельеф, реки и леса...")
        await get_tree().process_frame
        await get_tree().process_frame
        world.new_world(s)
        loading.set_progress(0.9, "Готовим карту...")
        await get_tree().process_frame
        _apply_speed()
        cam.set_zoom_at(MapCamera.zk(1.0), cam.view_size() * 0.5)
        _on_zoom(1.0)
        loading.finish()
        _snd("music", ["game"])
        _snd("loop", ["amb_wind", "ambient_wind_loop", true, Vector2.INF, -12.0])
        hud.city_labels_reset()
        hud.refresh()
        _set_mode(Mode.CAPITAL)
        hud.select_page(1)
        if has_node("/root/ModManager"):
                var mod_manager: Node = get_node("/root/ModManager")
                mod_manager.set_active_world(self, world)
                mod_manager.call_hook("on_world_started", [self, world])


func _notification(what: int) -> void :
        if what == NOTIFICATION_WM_GO_BACK_REQUEST:
                if bool(load("res://ui/ui24/tutorial_feed.gd").call("close_if_open")):
                        return
                if (menus == null or not menus.is_open()) and _army_back():
                        return
                if menus != null and menus.is_open():
                        if not in_menu:
                                _on_menu("resume")
                else:
                        _open_pause()
        elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
                _touches.clear()
                _pinch_d = 0.0
                _pinch_mid = Vector2.INF
                _dtz = false
                _mouse_down = false
                _rmb_down = false
                _rmb_dragged = false
                if net != null and net.in_match:

                        if OS.has_feature("mobile"):
                                net.set_host_active(false)
                        return
                if not in_menu:
                        Save.save_game(self)
                if not in_menu and menus != null and not menus.is_open() and OS.has_feature("mobile"):
                        _open_pause()
        elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
                if net != null and net.in_match:
                        net.set_host_active(true)
        elif what == NOTIFICATION_WM_CLOSE_REQUEST:
                if _playtime_accum > 0.0:
                        Account.record_playtime(_playtime_accum)
                        _playtime_accum = 0.0
                if net != null and net.in_match:
                        if net.is_host:
                                net.host_exit_saved()
                        else:
                                net.leave(false)
                elif not in_menu:
                        Save.save_game(self)



func open_report(cid: int) -> void :
        if in_menu:
                return
        _open_pause()
        ReportScreen.start(cid, true)
        menus.show_report()


func _open_pause() -> void :
        if in_menu:
                return
        if not menus.is_open():
                _menu_paused = _paused
        _paused = true
        _apply_speed()
        menus.show_pause()



func _on_offer() -> void :
        if net.in_match and world.diplo != null:
                var fresh: bool = false
                var now: Dictionary = {}
                for it: Dictionary in world.diplo.pending_for_player():
                        var id: String = String(it["id"])
                        now[id] = true
                        fresh = fresh or not _seen_pend.has(id)
                _seen_pend = now
                if not fresh:
                        return
        var was: bool = world.ui_mute
        world.ui_mute = false
        hud._on_world_message("Дипломатия: новое предложение")
        world.ui_mute = was


func _on_war(a: int, b: int) -> void :
        if world.player == null or (a != world.player.id and b != world.player.id):
                return
        var other: int = b if a == world.player.id else a
        var oc: Country = world.country_by_id(other)
        hud.war_flash(Loc.msg(Loc.mk("ВОЙНА: %s", [(Loc.name(oc.name).to_upper() if oc != null else "")])), "war")
        hud.plan_state = 0
        hud.plan_open = false
        hud._plan_sig = ""
        world.camera_shake_small()


func _on_match_end(winner: int) -> void :
        if net.in_match and RankedRules.active():
                var wt: int = world.session.win_team if world.session != null else -1
                var mid: String = String(GameConfig.ranked.get("match", net.match_id))
                if mid == "":
                        mid = net.match_id
                if mid != "":
                        Ranked.report(mid, null if wt < 0 else wt, RankedRules.left_names(net))
                _menu_paused = false
                _paused = true
                _apply_speed()
                NetConfig.clear_rejoin()
                menus.show_end_ranked(wt, mid)
                return
        if not net.in_match:
                var won: bool = world.player != null and winner == world.player.id
                Save.match_over(won)
                if won:
                        Account.record_solo_win()
                elif _playtime_accum > 0.0:
                        Account.record_playtime(_playtime_accum)
                        _playtime_accum = 0.0
        else:
                net.match_decided = true
                if net.is_host:
                        net.notify_match_finished()
                NetConfig.clear_rejoin()
                if net.is_host:
                        NetConfig.clear_match()
        if _playtime_accum > 0.0:
                Account.record_playtime(_playtime_accum)
                _playtime_accum = 0.0
        _menu_paused = false
        _paused = true
        _apply_speed()
        menus.show_end(winner)


func _on_city_captured(city: City, _old: int) -> void :
        hud.city_label_drop(city.id)
        if selected_fac != null and world.player != null and selected_fac.country_id != world.player.id:
                _deselect()
        if follow is Aircraft and world.player != null and (follow as Aircraft).country_id != world.player.id:
                _deselect()
        if world.player != null and city.country_id == world.player.id:
                var annex: bool = world.diplo != null and world.diplo.get("conf") != null and bool(world.diplo.conf.applying)
                hud.war_flash((Loc.t("АННЕКСИЯ: %s") if annex else Loc.t("ГОРОД ВЗЯТ: %s")) % Loc.name(city.name).to_upper())
        elif world.player != null and _old == world.player.id:
                var by_c: Country = world.country_by_id(city.country_id)
                hud.war_flash(Loc.msg(Loc.mk("ПОТЕРЯН ГОРОД: %s — взял %s", [Loc.name(city.name).to_upper(), Loc.name(by_c.name).to_upper() if by_c != null else "?"])), "lost")


const _TutorialFeed = preload("res://ui/ui24/tutorial_feed.gd")

func _process(delta: float) -> void :
        if not in_menu and not _paused:
                _playtime_accum += delta
                if _playtime_accum >= 30.0:
                        Account.record_playtime(_playtime_accum)
                        _playtime_accum = 0.0
        var idle: bool = ((in_menu and menus.current == "main") or (not in_menu and (_paused or menus.is_open()))) and not _TutorialFeed.is_open()
        if idle != Save.fps_idle:
                Save.fps_idle = idle
                Save.apply_power_save()
        if not _focus.is_empty():
                _focus_tick()
        if in_menu:

                cam.position += _menu_pan * delta * 14.0
                var wpx: Vector2 = cam.world_px
                if cam.position.x < 200.0 or cam.position.x > wpx.x - 200.0:
                        _menu_pan.x = - _menu_pan.x
                if cam.position.y < 300.0 or cam.position.y > wpx.y - 300.0:
                        _menu_pan.y = - _menu_pan.y
                return
        _pc_camera_process(delta)
        Save.tick(self, delta)
        if _strat_tap.is_finite() and Time.get_ticks_msec() - _strat_tap_ms >= 320:
                var stp: Vector2 = _strat_tap
                _strat_tap = Vector2.INF


                if not menus.is_open() and mode == Mode.NONE and _strat_tap_w.is_finite() and cam.world_to_screen(_strat_tap_w).distance_to(stp) < 12.0:
                        _tap(stp)
        world.selected_army = selected_fac if selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS else null
        _creative_t -= delta
        if world.get("vfx") != null and world.vfx.has_method("set_focus"):

                var fp: Vector2 = _pend["wp"] if _pend.has("wp") else Vector2.INF
                var fsig: = Vector3(fp.x if fp.is_finite() else -1.0, fp.y if fp.is_finite() else -1.0, float(mode))
                if fsig != _focus_sig:
                        _focus_sig = fsig
                        world.vfx.set_focus([fp] if fp.is_finite() else [], mode != Mode.NONE or fp.is_finite())
        if _auto_card != null:

                _auto_card_t -= delta
                if selected_fac != _auto_card:
                        _auto_card = null
                elif _auto_card_t <= 0.0 and not _confirming:
                        _auto_card = null
                        _deselect()
        if GameConfig.creative and _creative_t <= 0.0 and world.player != null and not GameConfig.tutorial and not net.in_match:
                _creative_t = 0.5
                var cp: Country = world.player
                cp.money = maxi(cp.money, 1000000)
                for rk: String in Economy.TRADE_RES + ["fuel"]:
                        var cap: int = int(world.econ.res_cap(cp, rk)) if world.econ.has_method("res_cap") else 0
                        cp.set(rk, maxi(int(cp.get(rk)), cap if cap > 0 else 999))

        var mt: float = hud.top_col.position.y + hud.top_col.size.y
        var mb: float = hud.root.size.y - hud.holder.position.y
        if absf(cam.margin_top_px - mt) > 2.0 or absf(cam.margin_bottom_px - mb) > 2.0:
                cam.margin_top_px = mt
                cam.margin_bottom_px = mb
                cam.center_on(cam.position)
        var g_live: bool = not _pend.is_empty() or mode == Mode.TARGET or BUILD_KIND.has(mode) or mode == Mode.RAIL_ST or mode == Mode.RAIL_LINE or ((Input.is_key_pressed(KEY_SHIFT) or repeat_building) and (BUILD_KIND.has(mode) or mode == Mode.MODULE or mode == Mode.CAPITAL or mode == Mode.TOWN))
        if (g_live or _ghost_live) and _ghost != null:
                _ghost.queue_redraw()
        _ghost_live = g_live
        _cam_tick(delta)
        _prompt_tick(delta)
        _update_ops(delta)
        _net_banner_tick(delta)
        strike.tick(world)
        if strike_marks != null:
                strike_marks.tick()
        if jet316_marks != null:
                jet316_marks.tick()
        _perf_t += delta
        if _perf_t >= 5.0:
                _perf_t = 0.0
                var dyn_tag: String = " dyn_stage=%d" % _dyn_fps_stage if GameConfig.dynamic_fps_target > 0 else ""
                print("[Perf] fps=%d draw_calls=%d objects=%d cities=%d zoom=%.2f%s" % [Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), world.obj_spr.size() - world._free_ids.size(), world.cities.size(), cam.zoom.x, dyn_tag])
        _adaptive_perf_tick(delta)
        if has_node("/root/ModManager") and not in_menu:
                get_node("/root/ModManager").call_hook("on_match_tick", [self, world, delta])


func _adaptive_perf_tick(delta: float) -> void :
        if GameConfig.dynamic_fps_target <= 0 or in_menu or _paused:
                if _dyn_fps_stage != 0:
                        _dyn_fps_stage = 0
                        GameConfig.apply_adaptive_stage(0)
                return
        _dyn_fps_timer += delta
        if _dyn_fps_timer < 0.5:
                return
        _dyn_fps_timer = 0.0

        var cur_fps: int = Engine.get_frames_per_second()
        var targets: Array[int] = [0, 30, 45, 60]
        var target: int = targets[clampi(GameConfig.dynamic_fps_target, 0, 3)]

        if cur_fps < target - 5:
                _dyn_fps_low_time += 0.5
                _dyn_fps_high_time = 0.0
                if _dyn_fps_low_time >= 1.5:
                        _dyn_fps_low_time = 0.0
                        var next_stage: int = _dyn_fps_stage
                        if cur_fps <= 12 or _dyn_fps_stage >= 2:
                                next_stage = 3
                        elif cur_fps < target - 12 or _dyn_fps_stage >= 1:
                                next_stage = 2
                        elif _dyn_fps_stage == 0:
                                next_stage = 1
                        if next_stage != _dyn_fps_stage:
                                _dyn_fps_stage = next_stage
                                GameConfig.apply_adaptive_stage(_dyn_fps_stage)
                                print("[AdaptivePerf] FPS drop (%d < %d) -> Enabled Stage %d" % [cur_fps, target, _dyn_fps_stage])
        elif cur_fps >= target + 5:
                _dyn_fps_high_time += 0.5
                _dyn_fps_low_time = 0.0
                if _dyn_fps_high_time >= 5.0:
                        _dyn_fps_high_time = 0.0
                        if _dyn_fps_stage > 0:
                                _dyn_fps_stage -= 1
                                GameConfig.apply_adaptive_stage(_dyn_fps_stage)
                                print("[AdaptivePerf] FPS recovered (%d >= %d) -> Reduced to Stage %d" % [cur_fps, target, _dyn_fps_stage])


func _on_action(nm: String) -> void :
        _auto_card = null
        decorator_sprite = ""
        if world.player != null and world.player.eliminated and not in_menu and not (nm in SPECTATOR_OK or nm.begins_with("page_") or nm.begins_with("dipx:")):
                hud.show_toast("Наблюдение: ваша страна выбыла. «Новая партия» — в меню")
                return

        if selected_fac != null and world.player != null and selected_fac.country_id != world.player.id:
                _deselect()
        if net.in_match and nm == "pause":
                hud.show_toast("Мультиплеер: пауза — только когда хост свернул игру")
                return
        if net.in_match and nm in ["speed", "speed_next"]:
                _speed_picker()
                return
        match nm:
                "pause":
                        _paused = not _paused
                        _apply_speed()
                "speed":
                        _speed_picker()
                "speed_next":
                        if net.in_match:
                                _speed_picker()
                                return
                        _speed_i = (_speed_i + 1) % SPEEDS.size()
                        _paused = false
                        _apply_speed()
                "zoom_in":
                        cam.step_zoom(1, cam.view_size() * 0.5)
                "zoom_out":
                        cam.step_zoom(-1, cam.view_size() * 0.5)
                "center":
                        if world.player != null and world.player.capital_id >= 0:
                                cam_lock = false
                                cam.center_on(Vector2(world.cities[world.player.capital_id].center * GameWorld.CELL))
                "new_world":
                        hud.open_new_world(settings)
                "borders":
                        world.territory.visible = not world.territory.visible
                        world.territory_border.visible = world.territory.visible
                        hud.set_key_pressed("borders", not world.territory.visible)
                "capital":
                        _set_mode(Mode.NONE if mode == Mode.CAPITAL else Mode.CAPITAL)
                "town":
                        if _has_capital():
                                _set_mode(Mode.NONE if mode == Mode.TOWN else Mode.TOWN)
                        else:
                                _set_mode(Mode.CAPITAL)
                "city_rename":
                        if selected_city >= 0 and selected_city < world.cities.size():
                                hud.show_city_rename_dialog(world.cities[selected_city])
                "strike":
                        if net.in_match:
                                hud.show_toast("Тестовый удар в сетевой партии недоступен")
                                return
                        _set_mode(Mode.NONE if mode == Mode.STRIKE else Mode.STRIKE)
                "menu":
                        _open_pause()
                "scores":
                        if not menus.is_open():
                                _menu_paused = _paused
                        _paused = true
                        _apply_speed()
                        menus.show_scores("pause" if menus.is_open() and menus.current == "pause" else "resume")
                "diplomacy":
                        hud.open_diplomacy()
                "trade":
                        hud.open_trade()
                "ad_rules":
                        hud.open_ad_rules(selected_fac.kind if selected_fac != null and Defense.AD_CLASSES.has(selected_fac.kind) else -1)
                "doctrine":
                        hud.open_doctrine()
                "attack":
                        if _has_capital():
                                attack_from = null
                                _set_mode(Mode.NONE if mode == Mode.ATTACK else Mode.ATTACK)
                "attack_from":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS:
                                var bf: Facility = selected_fac
                                _set_mode(Mode.ATTACK)
                                attack_from = bf
                                hud.set_hint("АТАКА ИЗ КАЗАРМ: ТАП ПО ГОРОДУ")
                "hold":
                        if world.player != null:
                                var now_h: float = Time.get_ticks_msec() / 1000.0
                                if now_h - _hold_t > 3.0:
                                        _hold_t = now_h
                                        hud.show_toast("Остановить ВСЕ армии? Нажмите «СТОЯТЬ» ещё раз")
                                else:
                                        _hold_t = -10.0
                                        _sim("army", "order_hold", [world.player.id])
                                        hud.show_toast("Все армии: стоять на месте")
                "army_next":
                        _cycle_army()
                "bar_0", "bar_1", "bar_2", "bar_3":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS:
                                _sim("", "cmd_field", [selected_fac, "prod_type", int(nm.substr(4))])
                "ad_rearm":
                        if selected_fac != null:
                                _sim("defense", "rearm", [selected_fac, world.player], func(r: Variant) -> void :
                                        hud.show_toast(_why(r) if _why(r) != "" else "Боекомплект пополнен"))
                "pylon_1", "pylon_2", "pylon_3":
                        if follow is Aircraft:
                                var a2: Aircraft = follow as Aircraft
                                var np: int = int(nm.substr(6))
                                _sim("mil.air", "set_pylon", [a2, 0 if a2.pylon == np else np], func(r: Variant) -> void :
                                        hud.show_toast(_why(r) if _why(r) != "" else Loc.msg(Loc.mk("Подвес: %s", [Loc.t(Air.PYLON_NAMES[a2.pylon])]))))
                "air_hyp":
                        if follow is Aircraft:
                                strike_open("hyper")
                "page_0", "page_1", "page_2", "page_3", "page_4", "page_5", "page_6":
                        pass
                "defend":
                        if world.player != null:
                                _sim("", "cmd_field", [world.player, "army_defend", not world.player.army_defend], func(_r: Variant) -> void :
                                        hud.set_key_pressed("defend", world.player.army_defend)
                                        hud.show_toast("Режим обороны: пехота занимает окопы" if world.player.army_defend else "Режим обороны выключен"))
                "occupy":
                        if selected_fac != null and Army.is_trench(selected_fac.kind):
                                _sim("army", "occupy", [selected_fac, world.player.id], func(r: Variant) -> void :
                                        var no: int = int(r) if r != null else 0
                                        hud.show_toast(Loc.msg(Loc.mk("В окоп идут: %d", [no])) if no > 0 else "Нет свободной пехоты рядом (казармы)"))
                "leave":
                        if selected_fac != null and Army.is_trench(selected_fac.kind):
                                _sim("army", "leave", [selected_fac])
                "bar_4":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS:
                                _sim("", "cmd_field", [selected_fac, "prod_type", 4])
                "police_patrol":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.POLICE_STATION:
                                _sim("army", "toggle_police_patrol", [selected_fac])
                "police_station", "factory", "droneport", "tel", "mfactory", "refinery", "power", "airfield", "farm", "civ", "mine", "barracks", "ad_mfg", "ad_spaag", "ad_sam", "ad_patriot", "ad_int", "ad_radar", "ad_ew", "trench", "teeth", "dugout", "sawmill", "oil_rig", "port", "solar_farm", "navbase", "coastal_asm", "npp", "umine":
                        var bm: int = BUILD_KEYS[nm]
                        if not _has_capital():
                                _set_mode(mode)
                        else:
                                _set_mode(Mode.NONE if mode == bm else bm)
                "rail_st", "rail_line":
                        var rm: int = Mode.RAIL_ST if nm == "rail_st" else Mode.RAIL_LINE
                        if _has_capital():
                                RB.reset()
                                _set_mode(Mode.NONE if mode == rm else rm)
                        else:
                                _set_mode(mode)
                "launch":
                        if mode == Mode.TARGET and not strike.active:
                                _set_mode(Mode.NONE)
                        elif _has_capital():
                                route_mode = false
                                strike_open("jet" if plan_jet else "drone")
                        else:
                                _set_mode(mode)
                "ship_cr":
                        if mode == Mode.SHIP_CR:
                                _set_mode(Mode.NONE)
                        else:
                                ship_cr_begin(null)
                "missile":
                        if mode == Mode.MISSILE and not strike.active:
                                _set_mode(Mode.NONE)
                        elif _has_capital():
                                route_mode = false
                                strike_open("tel")
                        else:
                                _set_mode(mode)
                "route":
                        if mode == Mode.NONE and follow is Drone:
                                route_mode = not route_mode
                                hud.show_toast("Тап по карте добавит точку маршрута" if route_mode else "Тап по карте задаёт новую цель")
                        elif mode != Mode.TARGET:
                                if not _has_capital():
                                        _set_mode(mode)
                                        return
                                strike_open("jet" if plan_jet else "drone")
                                route_mode = true
                        else:
                                route_mode = not route_mode
                        hud.set_key_pressed("route", route_mode)
                "follow":
                        _cycle_follow()
                "plan_minus":
                        plan_count = maxi(1, plan_count - 1)
                        _plan_per_all()
                "plan_plus":
                        var is_mod_weapon: bool = strike.active and (strike.cur == "thermo" or strike.cur == "nuke" or strike.cur == "iskander")
                        var av: int = int(_plan_info.get("available", 0)) if is_mod_weapon else int(_plan_info.get("available", 1))
                        if is_mod_weapon:
                                var cur_targets: Array = _plan_targets()
                                var tot: int = 0
                                for t: Dictionary in cur_targets:
                                        tot += int(t["n"])
                                if tot >= av or av <= 0:
                                        var w_name: String = "залпы" if strike.cur == "thermo" else ("ракеты «Искандер»" if strike.cur == "iskander" else "МБР")
                                        hud.show_toast(Loc.msg(Loc.mk("Все %s распределены: %d", [w_name, av])))
                                        if ClassDB.class_exists("UiKit"):
                                                UiKit.snd("ui_error")
                                        return
                                if plan_list.is_empty():
                                        plan_count = mini(av, plan_count + 1)
                                else:
                                        if tot + plan_list.size() + 1 <= av:
                                                plan_count = mini(av, plan_count + 1)
                                                _plan_per_all()
                                        else:
                                                plan_count = mini(av - (tot - plan_count), plan_count + 1)
                        else:
                                if plan_list.is_empty():
                                        plan_count = mini(maxi(1, int(_plan_info.get("available", 1))), plan_count + 1)
                                else:
                                        plan_count = mini(12, plan_count + 1)
                                        _plan_per_all()
                "plan_back":
                        if mode == Mode.JET_KAB or mode == Mode.JET_CAS:
                                _jet_back()
                        else:
                                _plan_back()
                "plan_launch":
                        if mode == Mode.JET_KAB or mode == Mode.JET_CAS:
                                _jet_fire()
                        elif strike.active:
                                strike_fire()
                        else:
                                _do_launch()
                "plan_cancel":
                        _set_mode(Mode.NONE)
                "ops_close":
                        _deselect()
                "open_stats":
                        hud.open_stats()
                "map_modes":
                        hud.open_map_modes()
                "own_icons":
                        world.show_own_icons = not world.show_own_icons
                        hud.set_key_pressed("own_icons", world.show_own_icons)
                        hud.show_toast(Loc.msg(Loc.mk("Значки построек: %s", [(Loc.t("вкл") if world.show_own_icons else Loc.t("выкл"))])))
                        if hud.panel_kind == "map_modes" and hud.panel != null and is_instance_valid(hud.panel):
                                hud.open_map_modes()
                "ores":
                        hud.toggle_ores()
                "command":
                        hud.open_command()
                "armies":
                        hud.toggle_armies()
                "fleet":
                        hud.open_navy_dock(null)
                "move_all":
                        _set_mode(Mode.MOVE_ALL)
                _ when nm.begins_with("arm_all_set:"):
                        var sa: int = int(nm.get_slice(":", 1))
                        _sim("ops", "set_stance_all", [world.player.id, sa])
                        hud.show_toast(Loc.msg(Loc.mk("Все армии: %s", [Loc.t(String(Operations.AutoCmd.STANCE_TITLES[sa]))])))
                        hud._arm_sig = ""
                "arm_all":
                        var sm: Dictionary = world.ops.command_summary(world.player.id)
                        var cur: int = -1
                        for a: Dictionary in sm.get("armies", []):
                                cur = int(a["stance"]) if cur == -1 or cur == int(a["stance"]) else -2
                        var nx: int = 1 if cur < 0 else (cur + 1) % 3
                        _sim("ops", "set_stance_all", [world.player.id, nx])
                        hud.show_toast(Loc.msg(Loc.mk("Все армии: %s", [Loc.t(String(Operations.AutoCmd.STANCE_TITLES[nx]))])))
                        hud._arm_sig = ""
                _ when nm.begins_with("arm_sel:"):
                        var aid: int = int(nm.get_slice(":", 1))
                        if aid >= 0 and aid < world.mil.facilities.size():
                                var af: Facility = world.mil.facilities[aid]
                                _set_mode(Mode.NONE)
                                _deselect()
                                if hud.get("army_ux") != null and preload("res://game/army_groups.gd").army_alive(world, af):
                                        hud.army_ux.open_army(af.id)
                                        return
                                selected_fac = af
                                army_view = true
                                cam_lock = false
                                var sum: = Vector2.ZERO
                                var cnt: int = 0
                                for u: Unit in world.army.units:
                                        if u.home == af and u.alive():
                                                sum += u.pos
                                                cnt += 1
                                cam.center_on(sum / cnt if cnt > 0 else af.center_px())
                                _focus = {"fid": af.id, "n": 3}
                                hud._arm_sig = ""
                "auto_refill":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS:
                                var arf: Facility = selected_fac
                                _sim("army", "set_auto_refill", [arf, not bool(arf.get("auto_refill"))], func(r: Variant) -> void :
                                        hud.show_toast(_why(r) if _why(r) != "" else String(world.army.refill_status(arf))))
                "build_pick":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS:
                                hud.open_builds(selected_fac)
                "army_trench_in", "army_trench_out":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS:
                                var tf: Facility = selected_fac
                                var tin: bool = nm == "army_trench_in"
                                NetSession.sim("", "cmd_static", [world.player, "groups", "trench_in_fids" if tin else "trench_out_fids", [PackedInt32Array([tf.id]), "Армия №%d" % tf.army_no]], func(r: Variant) -> void :
                                        var tr: Dictionary = r if r is Dictionary else {}
                                        if String(tr.get("why", "")) != "":
                                                hud.show_toast(String(tr["why"]))
                                                UiKit.snd("ui_error")
                                        else:
                                                UiKit.snd("ui_select"))
                "army_group":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS and hud.get("army_dock") != null:
                                var gf2: Facility = selected_fac
                                _deselect()
                                hud.army_dock.open_group_card(gf2.group_id if gf2.group_id >= 0 else -2, gf2.id)
                "army_barracks":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS:
                                army_view = false
                                cam_lock = false
                                UiKit.snd("ui_select")
                "army_card":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS:
                                army_view = true
                                cam_lock = false
                                UiKit.snd("ui_select")
                "garrison":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS:
                                var gb: Facility = selected_fac
                                garrison_from = gb
                                _set_mode(Mode.GARRISON)
                "plan_toggle":
                        Hud.plan_closed = not Hud.plan_closed
                        hud.open_economy()
                "economy":
                        hud.open_economy()
                _ when nm.begins_with("plan_go:"):
                        _plan_go(nm.get_slice(":", 1))
                _ when nm.begins_with("fac_go:") or nm.begins_with("dep_go:"):
                        _res_go(nm)
                "prot:net", "prot:conc":
                        if selected_fac != null and world.get("protect") != null:
                                var pw: String = nm.substr(5)
                                var pf: Facility = selected_fac
                                var pinf: Dictionary = world.protect.info(pf)
                                var broken_p: bool = String(pinf[pw + "_state"]) in ["torn", "broken"]
                                _sim("protect", "repair" if broken_p else "upgrade", [pf, pw, world.player], func(r: Variant) -> void :
                                        if _why(r) != "":
                                                hud.show_toast(_why(r)))
                "fac_halt":
                        if selected_fac != null and world.mil.has_method("set_halted"):
                                var hf: Facility = selected_fac
                                _sim("mil", "set_halted", [hf, not bool(hf.get("halted"))], func(r: Variant) -> void :
                                        hud.show_toast(_why(r) if _why(r) != "" else ("Производство остановлено" if bool(hf.get("halted")) else "Производство запущено")))
                "stance_cycle":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS:
                                var ns: int = (world.ops.stance_of(selected_fac) + 1) % 3
                                _sim("ops", "set_stance", [selected_fac, ns], func(r: Variant) -> void :
                                        hud.show_toast(_why(r) if _why(r) != "" else Loc.msg(Loc.mk("Армия: %s", [Loc.t(String(Operations.AutoCmd.STANCE_TITLES[ns]))]))))
                "cc_auto_orders":
                        _sim("ops", "set_auto_orders", [world.player.id, not world.ops.auto_orders_of(world.player.id)], func(_r: Variant) -> void : hud.open_command())
                "cc_auto_strike":
                        _sim("mil", "set_auto_strike", [world.player.id, (world.mil.auto_strike_of(world.player.id) + 1) % 3], func(_r: Variant) -> void : hud.open_command())
                "cc_auto_kab":
                        _sim("mil", "set_auto_kab", [world.player.id, not world.mil.auto_kab_of(world.player.id)], func(_r: Variant) -> void : hud.open_command())
                "smart_toggle", "cc_smart":
                        if world.player != null and world.mil.has_method("set_smart"):
                                _sim("mil", "set_smart", [world.player.id, not world.mil.smart_of(world.player.id)])
                                _danger_t = 0.0
                                if hud.panel_kind == "command":
                                        hud.open_command()
                "cc_auto_drones":
                        _sim("mil", "set_auto_drones", [world.player.id, not world.mil.auto_drones_of(world.player.id)], func(_r: Variant) -> void : hud.open_command())
                _ when nm.begins_with("cc_"):
                        var cp: PackedStringArray = nm.split(":")
                        match cp[0]:
                                "cc_go":
                                        var gf: Facility = world.mil.facilities[int(cp[1])] if int(cp[1]) < world.mil.facilities.size() else null
                                        if gf != null:
                                                hud.close_panel()
                                                _deselect()
                                                selected_fac = gf
                                                cam_lock = false
                                                cam.center_on(gf.center_px())
                                "cc_pos":
                                        hud.close_panel()
                                        cam_lock = false
                                        cam.center_on(Vector2(float(cp[1]), float(cp[2])))
                                "cc_st":
                                        var sf: Facility = world.mil.facilities[int(cp[1])] if int(cp[1]) < world.mil.facilities.size() else null
                                        if sf != null:
                                                _sim("ops", "set_stance", [sf, int(cp[2])], func(r: Variant) -> void :
                                                        if _why(r) != "":
                                                                hud.show_toast(_why(r)))
                                        hud.open_command()
                                "cc_all":
                                        _sim("ops", "set_stance_all", [world.player.id, int(cp[1])])
                                        hud.show_toast(Loc.msg(Loc.mk("Все армии: %s", [Loc.t(String(Operations.AutoCmd.STANCE_TITLES[int(cp[1])]))])))
                                        hud.open_command()
                "ult_send":
                        var u: Dictionary = hud.ult
                        var opts2: Array = world.diplo.demand_options(world.player.id, int(u["to"]))
                        var prm: Dictionary = {"conseq": String(u["conseq"])}
                        var kind: String = String(u["kind"])
                        if int(u.get("opt", -1)) >= 0 and int(u["opt"]) < opts2.size():
                                var o2: Dictionary = opts2[int(u["opt"])]
                                kind = String(o2["kind"])
                                prm.merge(o2.get("params", {}), true)
                        else:
                                prm["n"] = int(u["n"])
                                if kind == "res":
                                        prm["res"] = String(u["res"])
                        var uc: Country = world.country_by_id(int(u["to"]))
                        _sim("diplo", "demand", [world.player.id, int(u["to"]), kind, prm], func(r: Variant) -> void :
                                var whyu: String = _why(r)
                                hud.show_toast(whyu if whyu != "" else Loc.msg(Loc.mk("%s уступает: требование выполнено", [(Loc.name(uc.name) if uc != null else "")])))
                                UiKit.snd("ui_error" if whyu != "" else "ui_money")
                                hud.open_diplomacy())
                "pend_ok":
                        _pend_ok()
                "pend_cancel":
                        _pend_cancel()
                "operation":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS:
                                var obf: Facility = selected_fac
                                _set_mode(Mode.OPERATION)
                                op_from = obf
                "op_retreat":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS:
                                _sim("ops", "start", [selected_fac, 2, Vector2.ZERO], func(r: Variant) -> void : hud.show_toast(_or_ok(_why(r), "Отход к казармам")))
                "op_cancel":
                        if selected_fac != null:
                                _sim("ops", "cancel", [selected_fac])
                                hud.show_toast("Приказ отменён")
                "order_0", "order_1", "order_2":
                        var ok2: int = int(nm.right(1))
                        if world.player == null or not _has_capital():
                                return
                        var cdl: float = world.ops.cooldown_left(world.player.id, ok2)
                        if mode == Mode.ORDER and order_kind == ok2:
                                _set_mode(Mode.NONE)
                        elif cdl > 0.0:
                                hud.show_toast(Loc.msg(Loc.mk("%s: ещё %d с", [Loc.t(String(world.ops.order_info(ok2).get("name", ""))), ceili(cdl)])))
                        else:
                                order_kind = ok2
                                _set_mode(Mode.ORDER)
                "battle_cam":
                        _battle_cam()
                "prompt_go":
                        if world.ops.has_method("prompt_accepted"):
                                _sim("ops", "prompt_accepted", [hud.prompt_data])
                        _prompt_act(hud.prompt_data)
                        hud.hide_prompt()
                "prompt_no":
                        if world.ops.has_method("dismiss_prompt"):
                                _sim("ops", "dismiss_prompt", [hud.prompt_data])
                        hud.hide_prompt()
                "recon":
                        if world.get("recon") != null and _has_capital():
                                if mode == Mode.RECON:
                                        _set_mode(Mode.NONE)
                                else:
                                        var rw: String = world.recon.can_launch(world.player.id)
                                        if rw != "":
                                                hud.show_toast(rw)
                                        else:
                                                _set_mode(Mode.RECON)
                "recon_recall":
                        var rd: Variant = world.selected_drone() if world.has_method("selected_drone") else null
                        if rd != null:
                                _sim("", "cmd_recall", [world.player.id, int(rd.get("id"))])
                "satellite":
                        if net.in_match:
                                hud.show_toast("Спутник в сетевой партии пока недоступен")
                                return
                        if world.get("vision") == null or not world.vision.has_method("reveal"):
                                hud.show_toast("Спутниковая разведка недоступна")
                        elif _has_capital():
                                _set_mode(Mode.NONE if mode == Mode.SATELLITE else Mode.SATELLITE)
                _ when nm.begins_with("map_mode:"):
                        world.set_map_mode(int(nm.get_slice(":", 1)))
                _ when nm.begins_with("goto_dep:"):
                        var gp: PackedStringArray = nm.split(":")
                        var gc: = Vector2i(int(gp[1]), int(gp[2]))
                        _deselect()
                        _set_mode(Mode.NONE)
                        cam.center_on(Vector2(gc * GameWorld.CELL) + Vector2(0, 40))
                        if cam.zoom.x < 1.5:
                                cam.set_zoom_at(1.5, cam.view_size() * 0.5)
                        selected_dep = world.econ.deposit_at(gc, 1)
                "inventory":
                        hud.open_inventory()
                "cancel_select":
                        _set_mode(Mode.NONE)
                        _deselect()
                        _clear_plan()
                        hud.hide_ops()
                "buy_bomber", "buy_fighter", "buy_heli", "buy_attack":
                        if selected_fac != null:
                                var t: int = {"buy_bomber": Aircraft.Type.BOMBER, "buy_fighter": Aircraft.Type.FIGHTER, "buy_heli": Aircraft.Type.HELI, "buy_attack": Aircraft.Type.ATTACK}[nm]
                                _sim("mil.air", "buy", [selected_fac, t, world.player], func(r: Variant) -> void :
                                        hud.show_toast(_why(r) if _why(r) != "" else Loc.msg(Loc.mk("Куплен: %s", [Loc.t(String(Air.SPEC[t]["name"]))]))))
                "air_land":
                        if follow is Aircraft:
                                _sim("mil.air", "order_land", [follow])
                                hud.show_toast("Возврат на базу")
                "air_patrol":
                        if follow is Aircraft:
                                air_patrol_pending = true
                                hud.show_toast("Тапните центр зоны патрулирования")
                "air_upgrade":
                        if follow is Aircraft:
                                _sim("mil.air", "upgrade", [follow, world.player], func(r: Variant) -> void :
                                        hud.show_toast(_why(r) if _why(r) != "" else "Истребитель улучшен"))
                "air_cr":
                        if follow is Aircraft:
                                strike_open("bomber")
                "air_kab", "air_cas", "jet_kab", "jet_cas":


                        var jm: int = Mode.JET_KAB if nm.ends_with("kab") else Mode.JET_CAS
                        if nm.begins_with("jet_") and mode == jm:
                                _set_mode(Mode.NONE)
                        else:
                                _jet_begin(follow as Aircraft if nm.begins_with("air_") and follow is Aircraft else null, jm)
                _ when nm.begins_with("dip:"):
                        _dip_action(nm)
                _ when nm.begins_with("dipx:"):
                        var xid: int = int(nm.get_slice(":", 1))
                        hud.dip_open = -1 if hud.dip_open == xid else xid
                        hud._dip_scroll_to = hud.dip_open
                        hud.open_diplomacy()
                _ when nm.begins_with("warask:"):
                        hud.war_arm = int(nm.get_slice(":", 1))
                        hud.war_arm_until = Time.get_ticks_msec() + 4000
                        hud.open_diplomacy()
                "demand_arrived":
                        if _speed_i > 0 and not _paused:
                                _speed_i = 0
                                _apply_speed()
                                hud.show_toast("Ультиматум: скорость x1 — ответьте в окне дипломатии")
                _ when nm.begins_with("treaty:") or nm.begins_with("untreaty:") or nm.begins_with("embargo:") or nm.begins_with("aid:") or nm.begins_with("dem:") or nm.begins_with("pend:"):
                        _dip11(nm)
                _ when nm.begins_with("offer:"):
                        var parts: PackedStringArray = nm.split(":")
                        _sim("diplo", "answer_as", [world.player.id, "o%d" % int(parts[1]), "accept" if parts[2] == "1" else "refuse"], func(_r: Variant) -> void :
                                hud.open_diplomacy())
                _ when nm.begins_with("trade:"):
                        var tp: PackedStringArray = nm.split(":")
                        var t_m: String = ("propose_treaty" if tp[2] == "1" else "cancel_treaty") if world.diplo.has_method("propose_treaty") else "set_trade"
                        var t_a: Array = [world.player.id, int(tp[1]), tp[2] == "1"] if t_m == "set_trade" else [world.player.id, int(tp[1]), "trade"]
                        _sim("econ" if t_m == "set_trade" else "diplo", t_m, t_a, func(r: Variant) -> void :
                                if _why(r) != "":
                                        hud.show_toast(_why(r))
                                hud.open_trade())
                _ when nm.begins_with("build_"):
                        if selected_fac != null and selected_fac.kind == Facility.Kind.BARRACKS:
                                _sim("army", "set_build", [selected_fac, nm.substr(6)], func(r: Variant) -> void :
                                        if _why(r) != "":
                                                hud.show_toast(_why(r))
                                        elif hud.panel_kind == "builds":
                                                hud.close_panel()
                                                hud.show_toast("Сборка армии изменена"))
                _ when nm.begins_with("doc:"):
                        var p: Country = world.player
                        if p != null:
                                match nm:
                                        "doc:fpv":
                                                _sim("", "cmd_field", [p, "doctrine_fpv", not p.doctrine_fpv])
                                        "doc:assault":
                                                _sim("", "cmd_field", [p, "doctrine_assault", not p.doctrine_assault])
                                        "doc:support":
                                                _sim("army", "toggle_support", [p.id])
                                        "doc:defend":
                                                _sim("", "cmd_field", [p, "army_defend", not p.army_defend], func(_r: Variant) -> void : hud.set_key_pressed("defend", p.army_defend))
                        hud.open_doctrine()
                "fac_upgrade":
                        if selected_fac != null and world.econ.has_method("upgrade"):
                                var uf: Facility = selected_fac
                                _sim("econ", "upgrade", [uf, world.player], func(r: Variant) -> void :
                                        var whyu: String = _why(r)
                                        hud.show_toast(whyu if whyu != "" else (String(world.econ.call("upgrade_toast", uf)) if world.econ.has_method("upgrade_toast") else Loc.msg(Loc.mk("Улучшено: %s, уровень %d", [Loc.t(Military.title_of(uf.kind)), int(world.econ.call("level_of", uf))]))))
                                        UiKit.snd("ui_error" if whyu != "" else "ui_build"))
                "intel_strike":

                        if selected_intel != null:
                                var tp: Vector2 = world.vision.last_pos(selected_intel)
                                _deselect()
                                route_mode = false
                                strike_open("tel")
                                if plan_has_target:
                                        plan_list.append({"pos": plan_target, "n": plan_count, "wps": plan_wps.duplicate()})
                                        plan_wps.clear()
                                        plan_count = 1
                                plan_target = tp
                                plan_has_target = true
                                cam.center_on(tp)
                "dep_build":
                        _dep_build()
                "repair_all":
                        if world.player != null:
                                _sim("mil", "restore_all", [world.player], func(r: Variant) -> void :
                                        var rr: Array = r if r is Array else [0, 0, 0]
                                        var rwhy: String = String(rr[3]) if rr.size() > 3 else ""
                                        if int(rr[0]) > 0:
                                                hud.show_toast(Loc.msg(Loc.mk("Ремонт: %d объект(ов), −%d%s", [int(rr[0]), int(rr[1]), (Loc.t(" · не начато: ") + rwhy) if rwhy != "" else ""])))
                                                UiKit.snd("ui_build")
                                        else:
                                                hud.show_toast((Loc.t("Ремонт не начат: ") + rwhy) if rwhy != "" else "Ремонтировать нечего")
                                                UiKit.snd("ui_error"))
                "fac_restore":
                        if selected_fac != null:
                                _sim("mil", "restore", [selected_fac, world.player])
                "fac_demolish":

                        if selected_fac != null and world.player != null and world.mil.has_method("demolish"):
                                var whyd: String = world.mil.demolish_why(world.player, selected_fac)
                                if whyd != "":
                                        hud.show_toast(whyd)
                                        UiKit.snd("ui_error")
                                else:
                                        _pend = {"kind": "demolish", "fac": selected_fac}
                                        _show_pend()
                "plan_reset":
                        _clear_plan()
                        hud.show_toast("Цели сброшены")
                "plan_standing":
                        if world.mil.has_method("set_standing"):
                                var on: bool = not _standing_on()
                                if on and not plan_has_target:
                                        hud.show_toast("Сначала отметьте цели")
                                else:
                                        _sim("mil", "set_standing", [world.player.id, _plan_targets() if on else [], plan_jet, on, 1])
                                        hud.show_toast("Автопуск: каждый новый дрон летит по этим целям" if on else "Автопуск выключен")
                "plan_kind_0", "plan_kind_1":
                        plan_jet = nm == "plan_kind_1"
                        plan_count = 1
                "dtype_0", "dtype_1":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.DRONE_FACTORY:
                                _sim("", "cmd_field", [selected_fac, "prod_type", int(nm.substr(6))])
                _ when nm.begins_with("mtype_"):
                        if selected_fac != null:
                                _sim("mil", "set_prod_type", [selected_fac, int(nm.substr(6))])
                "mod_ramp", "mod_runway", "mod_store", "mod_solar", "mod_crane":
                        if selected_fac != null and world.mil.alive(selected_fac):
                                module_port = selected_fac
                                module_kind = {"mod_ramp": Facility.Kind.DP_RAMP, "mod_runway": Facility.Kind.DP_RUNWAY, "mod_store": Facility.Kind.DP_STORE, "mod_solar": Facility.Kind.SOLAR, "mod_crane": Facility.Kind.PORT_CRANE}[nm]
                                _set_mode(Mode.MODULE)
                "expedition":
                        if selected_fac != null and selected_fac.kind == Facility.Kind.PORT and world.get("naval") != null:
                                var ready: String = String(world.naval.port_info(selected_fac).get("ready", ""))
                                if ready != "":
                                        hud.show_toast(ready)
                                        UiKit.snd("ui_error")
                                        if bool(world.naval.port_info(selected_fac).get("short_res", false)):
                                                _offer_buy(Naval.EXP_COST)
                                else:
                                        exp_port = selected_fac
                                        _deselect()
                                        _set_mode(Mode.EXPEDITION)
                "to_boats":
                        if selected_fac != null and world.get("naval") != null:
                                var li: Dictionary = world.naval.landing_info(selected_fac)
                                if li.get("pos") is Vector2:
                                        cam_lock = false
                                        cam.center_on(li["pos"])
                "port_export":
                        if world.player != null:
                                _sim("econ", "set_export", [world.player, world.econ.export_off.has(world.player.id)])
                "dip_best", "upg_best", "net_best", "dp_ramp":
                        _plan_action(nm)
                _ when nm.begins_with("mkt_why:"):
                        hud.show_toast(nm.substr(8))
                        UiKit.snd("ui_error")
                        if hud.panel_kind == "trade":
                                hud.trade_status(Loc.t("НЕ ВЫШЛО: %s") % Loc.t(nm.substr(8)), false)
                                hud.open_trade()
                _ when nm.begins_with("mkt:"):

                        var mp: PackedStringArray = nm.split(":")
                        var other: Country = world.country_by_id(int(mp[2])) if int(mp[2]) > 0 else null


                        _sim("econ", "market_order", [world.player, other, mp[3], int(mp[4]), mp[1] == "buy"], func(r: Variant) -> void :
                                var whym: String = _why(r)
                                var ld: Dictionary = world.econ.last_deal
                                if whym != "" or ld.is_empty():
                                        var tmsg: String = whym if whym != "" else (Loc.t("Сделка оформлена: %s") % Loc.t(String(Economy.RES_NAMES.get(mp[3], mp[3]))).to_lower())
                                        hud.show_toast(tmsg)
                                        hud.trade_status((Loc.t("НЕ ВЫШЛО: %s") % Loc.t(whym)) if whym != "" else tmsg, whym == "")
                                else:
                                        var rn: String = String(Economy.RES_NAMES.get(String(ld["res"]), "")).to_lower()
                                        var how: String = String({"truck": "грузовиком", "rail": "поездом", "ship": "кораблём", "import": "кораблём", "export": "кораблём", "queue": "ближайшим кораблём"}.get(String(ld["mode"]), ""))
                                        var txt: String = ""
                                        if String(ld["kind"]) == "buy":
                                                txt = Loc.t("КУПЛЕНО: %s ×%d за %d (%s) · поступит, когда приедет %s, %s") % [rn, int(ld["n"]), int(ld["price"]), String(ld["partner"]), how, Economy.eta_text(float(ld["eta"]))]
                                        else:
                                                txt = Loc.t("ПРОДАНО: %s ×%d (%s) за %d · оплата при доставке %s, %s") % [rn, int(ld["n"]), String(ld["partner"]), int(ld["price"]), how, Economy.eta_text(float(ld["eta"]))]
                                        var eta_s: String = Economy.eta_text(float(ld["eta"]))
                                        if String(ld["kind"]) == "buy":
                                                hud.trade_status(Loc.t("КУПЛЕНО: %s ×%d за %d · в пути %s") % [rn, int(ld["n"]), int(ld["price"]), eta_s], true)
                                        else:
                                                hud.trade_status(Loc.t("ПРОДАНО: %s ×%d за %d · в пути %s") % [rn, int(ld["n"]), int(ld["price"]), eta_s], true)
                                        if hud.lane != null and is_instance_valid(hud.lane):
                                                hud.lane.call("push", "msg", {"title": txt, "icon": hud._res_icon(String(ld["res"])), "ttl": 5.0})
                                        else:
                                                hud.show_toast(txt)
                                UiKit.snd("ui_error" if whym != "" else "ui_money")
                                if hud.panel_kind == "trade":
                                        hud.open_trade())
                _ when nm.begins_with("req:"):
                        var rp: PackedStringArray = nm.split(":")
                        if rp[1] == "ok":
                                _sim("econ", "accept_request", [world.player, int(rp[2])], func(r: Variant) -> void :
                                        hud.show_toast(_why(r) if _why(r) != "" else "Сделка принята"))
                        else:
                                _sim("econ", "decline_request", [world.player, int(rp[2])])
                        hud.open_trade()


func _unhandled_input(event: InputEvent) -> void :
        if event is InputEventKey and event.pressed and not event.echo:
                var kc_global: int = (event as InputEventKey).keycode
                if kc_global == KEY_F11 or (kc_global == KEY_ENTER and event.alt_pressed):
                        get_viewport().set_input_as_handled()
                        _toggle_fullscreen()
                        return
        if in_menu:
                return
        if event is InputEventKey:
                var k_shift: int = (event as InputEventKey).keycode
                if k_shift == KEY_SHIFT:
                        if _ghost != null:
                                _ghost.queue_redraw()
        if event is InputEventKey and event.pressed and not event.echo:
                var kc: int = (event as InputEventKey).keycode
                if kc == KEY_ESCAPE or kc == KEY_BACK:
                        if hud != null and hud.has_method("ui24_open_now") and hud.ui24_open_now():
                                hud.close_panel()
                                return
                        if not _pend.is_empty():
                                _pend_cancel()
                                return
                        if mode != Mode.NONE:
                                _set_mode(Mode.NONE)
                                hud.refresh()
                                return
                        if selected_fac != null:
                                _deselect()
                                return
                        if not menus.is_open() and _army_back():
                                return
                        if menus.is_open():
                                _on_menu("resume")
                        else:
                                _open_pause()
                        return
                if _handle_pc_shortcut(kc, event as InputEventKey):
                        return
                _debug_key(kc)
                return
        if event is InputEventMagnifyGesture:
                var mg: = event as InputEventMagnifyGesture
                cam.set_zoom_at(cam.zoom.x * mg.factor, mg.position)
                _on_zoom(cam.zoom.x)
                return
        if event is InputEventPanGesture:
                var pg: = event as InputEventPanGesture
                cam.pan_screen( - pg.delta * 8.0)
                cam_lock = false
                return
        if event is InputEventScreenTouch:
                var st: = event as InputEventScreenTouch
                if st.pressed:


                        if st.index == 0:
                                _touches.clear()
                                _pinch_d = 0.0
                                _pinch_mid = Vector2.INF
                        _touches[st.index] = st.position
                        if _touches.size() == 1:
                                _begin_press(st.position)
                        else:
                                _drag_pt = -2
                                _dtz = false
                                _pinch_z0 = cam.zoom.x
                        _pinch_d = 0.0
                else:
                        var was_single: bool = _touches.size() == 1
                        _touches.erase(st.index)
                        if was_single:
                                _release_press(st.position)
                        else:
                                _end_drag()
                        if _touches.size() < 2 and _pinch_d > 0.0:


                                var zf: Vector2 = _pinch_mid if _pinch_mid.is_finite() else cam.view_size() * 0.5
                                cam.settle_zoom(zf, signi(int(signf(cam.zoom.x - _pinch_z0))))
                                _pinch_d = 0.0
                        if _touches.size() < 2:
                                _pinch_mid = Vector2.INF
        elif event is InputEventScreenDrag:
                var sd: = event as InputEventScreenDrag
                _touches[sd.index] = sd.position
                if _touches.size() == 1:
                        if _dtz:
                                _dtz_drag(sd.position)
                        elif _moved or sd.position.distance_to(_press_pos) > 6.0:
                                _moved = true
                                _drag_or_pan(sd.position, sd.relative)
                elif _touches.size() >= 2:
                        var pts: Array = _touches.values()
                        var a: Vector2 = pts[0]
                        var b: Vector2 = pts[1]
                        var d: float = a.distance_to(b)
                        var mid: Vector2 = (a + b) * 0.5
                        if _pinch_d > 0.0 and d > 1.0:
                                cam.set_zoom_at(cam.zoom.x * d / _pinch_d, mid)
                        if _pinch_mid != Vector2.INF:
                                cam.pan_screen(mid - _pinch_mid)
                                cam_lock = false
                        _pinch_mid = mid
                        _pinch_d = d
                        _moved = true
                        if not line_cells.is_empty():
                                line_cells.clear()
        elif event is InputEventMouseButton:
                var mb: = event as InputEventMouseButton
                if mb.device == InputEvent.DEVICE_ID_EMULATION:
                        return
                if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
                        var f: float = mb.factor if mb.factor > 0.0 else 1.0
                        cam.step_zoom(1.0, mb.position, f)
                        return
                elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
                        var f: float = mb.factor if mb.factor > 0.0 else 1.0
                        cam.step_zoom(-1.0, mb.position, f)
                        return
                elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE or KeybindManager.is_event_match(mb, "pan_mouse"):
                        if mb.pressed:
                                _rmb_down = true
                                _rmb_dragged = false
                                _rmb_start_pos = mb.position
                        else:
                                _rmb_down = false
                                if not _rmb_dragged:
                                        if mode != Mode.NONE:
                                                _set_mode(Mode.NONE)
                                                hud.refresh()
                                        elif selected_fac != null:
                                                _deselect()
                                        elif hud != null and hud.has_method("close_panel"):
                                                hud.close_panel()
                        return
                elif mb.button_index == MOUSE_BUTTON_LEFT:
                        if mb.pressed:
                                _mouse_down = true
                                _begin_press(mb.position)
                        else:
                                _mouse_down = false
                                _release_press(mb.position)
        elif event is InputEventMouseMotion:
                var mm: = event as InputEventMouseMotion
                if mm.device == InputEvent.DEVICE_ID_EMULATION:
                        return
                if _rmb_down:
                        if not _rmb_dragged and mm.position.distance_to(_rmb_start_pos) > 4.0:
                                _rmb_dragged = true
                        if _rmb_dragged:
                                cam.pan_screen(-mm.relative)
                                cam_lock = false
                        return
                if not _mouse_down:
                        if (Input.is_key_pressed(KEY_SHIFT) or repeat_building) and (BUILD_KIND.has(mode) or mode == Mode.MODULE or mode == Mode.CAPITAL or mode == Mode.TOWN):
                                if _ghost != null:
                                        _ghost.queue_redraw()
                        return
                if _dtz:
                        _dtz_drag(mm.position)
                elif _moved or mm.position.distance_to(_press_pos) > (20.0 if (Input.is_key_pressed(KEY_SHIFT) and (BUILD_KIND.has(mode) or mode == Mode.MODULE)) else 6.0):
                        _moved = true
                        _drag_or_pan(mm.position, mm.relative)





var _last_fullscreen_toggle: int = 0

func _toggle_fullscreen() -> void :
        var now: int = Time.get_ticks_msec()
        if now - _last_fullscreen_toggle < 350:
                return
        _last_fullscreen_toggle = now
        var cur: int = DisplayServer.window_get_mode()
        if cur == DisplayServer.WINDOW_MODE_FULLSCREEN or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
                DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
                Save.apply_display_resolution()
        else:
                Save.apply_display_resolution()
                DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _pc_camera_process(delta: float) -> void :
        if in_menu or cam == null or menus.is_open():
                return
        var fo: Control = get_viewport().gui_get_focus_owner()
        if fo is LineEdit or fo is TextEdit:
                return
        var pan_v: Vector2 = Vector2.ZERO
        if KeybindManager.is_action_pressed("cam_up"):
                pan_v.y += 1.0
        if KeybindManager.is_action_pressed("cam_down"):
                pan_v.y -= 1.0
        if KeybindManager.is_action_pressed("cam_left"):
                pan_v.x += 1.0
        if KeybindManager.is_action_pressed("cam_right"):
                pan_v.x -= 1.0
        if pan_v != Vector2.ZERO:
                var speed: float = 750.0
                if Input.is_key_pressed(KEY_SHIFT):
                        speed *= 2.2
                cam.pan_screen(pan_v.normalized() * (speed * delta))
                cam_lock = false

func _handle_pc_shortcut(k: int, ev: InputEventKey) -> bool :
        var fo: Control = get_viewport().gui_get_focus_owner()
        if fo is LineEdit or fo is TextEdit:
                return false
        if (k == KEY_E or ev.keycode == KEY_E or k == KEY_ENTER or ev.keycode == KEY_ENTER) and not _pend.is_empty():
                if _pend_why() == "":
                        _pend_ok()
                else:
                        hud.show_toast(_pend_why())
                        UiKit.snd("ui_error")
                return true
        if KeybindManager.is_event_match(ev, "cam_up") \
                or KeybindManager.is_event_match(ev, "cam_down") \
                or KeybindManager.is_event_match(ev, "cam_left") \
                or KeybindManager.is_event_match(ev, "cam_right"):
                return true
        if KeybindManager.is_event_match(ev, "pause"):
                _on_action("pause")
                return true
        if KeybindManager.is_event_match(ev, "speed_next"):
                _on_action("speed_next")
                return true
        if ev.keycode == KEY_F2 and ev.pressed and not ev.echo:
                if selected_city >= 0 and world != null and selected_city < world.cities.size() and hud != null and hud.has_method("show_city_rename_dialog"):
                        hud.show_city_rename_dialog(world.cities[selected_city])
                        return true
        if KeybindManager.is_event_match(ev, "zoom_in"):
                if cam != null:
                        cam.step_zoom(1, cam.view_size() * 0.5)
                return true
        if KeybindManager.is_event_match(ev, "zoom_out"):
                if cam != null:
                        cam.step_zoom(-1, cam.view_size() * 0.5)
                return true
        if KeybindManager.is_event_match(ev, "center_capital"):
                if world != null and world.player != null and world.player.capital != null:
                        cam.center_on(world.player.capital.pos)
                        cam.snap_zoom(cam.view_size() * 0.5)
                        if hud != null:
                                hud.show_toast("Камера: Столица")
                        return true
        if KeybindManager.is_event_match(ev, "open_diplo"):
                if hud != null and hud.has_method("open_diplomacy"):
                        hud.open_diplomacy()
                return true
        if KeybindManager.is_event_match(ev, "open_economy"):
                if hud != null and hud.has_method("open_economy"):
                        hud.open_economy()
                return true
        if KeybindManager.is_event_match(ev, "top_world"):
                if hud != null:
                        _on_action("scores")
                return true
        if KeybindManager.is_event_match(ev, "tab_1"):
                if hud != null and hud.has_method("select_page"):
                        hud.select_page(0)
                return true
        if KeybindManager.is_event_match(ev, "tab_2"):
                if hud != null and hud.has_method("select_page"):
                        hud.select_page(1)
                return true
        if KeybindManager.is_event_match(ev, "tab_3"):
                if hud != null and hud.has_method("select_page"):
                        hud.select_page(2)
                return true
        if KeybindManager.is_event_match(ev, "tab_4"):
                if hud != null and hud.has_method("select_page"):
                        hud.select_page(3)
                return true
        if KeybindManager.is_event_match(ev, "tab_5"):
                if hud != null and hud.has_method("select_page"):
                        hud.select_page(4)
                return true
        if KeybindManager.is_event_match(ev, "tab_6"):
                if hud != null and hud.has_method("select_page"):
                        hud.select_page(5)
                return true
        if KeybindManager.is_event_match(ev, "tab_7"):
                if hud != null and hud.has_method("select_page"):
                        hud.select_page(6)
                return true
        if KeybindManager.is_event_match(ev, "build_barracks"):
                _on_action("barracks")
                return true
        if KeybindManager.is_event_match(ev, "build_trench"):
                _on_action("trench")
                return true
        if KeybindManager.is_event_match(ev, "cancel_action"):
                if not _pend.is_empty():
                        _pend_cancel()
                        return true
                if mode != Mode.NONE:
                        _set_mode(Mode.NONE)
                        hud.refresh()
                        return true
                if selected_fac != null:
                        _deselect()
                        return true
        match k:
                KEY_R:
                        if world != null and world.player != null and world.player.capital != null:
                                cam.center_on(world.player.capital.pos)
                                cam.snap_zoom(cam.view_size() * 0.5)
                                if hud != null:
                                        hud.show_toast("Камера: Столица")
                                return true
                KEY_M:
                        var muted: bool = AudioServer.is_bus_mute(0)
                        AudioServer.set_bus_mute(0, not muted)
                        if hud != null:
                                hud.show_toast("Звук: ВЫКЛ" if not muted else "Звук: ВКЛ")
                        return true
                KEY_H:
                        if hud != null:
                                hud.show_toast("ПК: WASD - Камера | Shift - Постройка/окопы без подтверждения | B - Казармы | T - Окопы | F11 - Экран | Пробел/P - Пауза | Tab/F - Скорость | 1-7 - Вкладки")
                        return true
        return false

func _debug_key(k: int) -> void :
        if net.in_match and (k == KEY_3 or k == KEY_B):
                return
        var c: Vector2 = cam.view_size() * 0.5
        match k:
                KEY_K:
                        var keys: Array = world.checkpoints.keys()
                        if not keys.is_empty():
                                _kpp_i = (_kpp_i + 1) % keys.size()
                                var cp: Dictionary = world.checkpoints[keys[_kpp_i]]
                                var cc: Vector2i = cp["cell"]
                                cam.set_zoom_at(3.0, c)
                                cam.center_on(Vector2(cc * GameWorld.CELL))
                                var d: WorldData = world.data
                                var row: String = ""
                                for yy in range(cc.y - 2, cc.y + 3):
                                        for xx in range(cc.x - 2, cc.x + 3):
                                                row += str(d.get_owner_id(xx, yy))
                                        row += "|"
                                print("[Debug] KPP %d/%d %s at %s owners %s flag=%s" % [_kpp_i + 1, keys.size(), keys[_kpp_i], cc, row, cp["flag"] != null])
                KEY_B:
                        if not world.bridges.is_empty():
                                _br_i = (_br_i + 1) % world.bridges.size()
                                var br: Bridge = world.bridges[_br_i]
                                var mid: Vector2i = br.cells[br.cells.size() / 2]
                                cam.set_zoom_at(3.0, c)
                                cam.center_on(Vector2(mid * GameWorld.CELL))
                                world.strike(mid)
                                print("[Debug] strike bridge %d (%d cells) at %s" % [br.id, br.cells.size(), mid])
                KEY_N:
                        var caps: Array = []
                        for ct: City in world.cities:
                                if ct.kind == City.Kind.CAPITAL:
                                        caps.append(ct)
                        if not caps.is_empty():
                                _cap_i = (_cap_i + 1) % caps.size()
                                cam.center_on(Vector2((caps[_cap_i] as City).center * GameWorld.CELL))




func _plan_go(key: String) -> void :
        if key == "" or world.player == null:
                return
        hud.close_panel()
        if not BUILD_KEYS.has(key) and key != "town" and key != "capital":
                _on_action(key)
                return
        var pos: Vector2 = Vector2.INF
        if world.get("guide") != null and world.guide.has_method("best_site"):
                pos = world.guide.best_site(world.player, key)
        _deselect()
        var want: int = int(BUILD_KEYS[key]) if BUILD_KEYS.has(key) else (Mode.TOWN if key == "town" else Mode.CAPITAL)
        if mode != want:
                _on_action(key)
        if pos.is_finite():
                cam_lock = false
                cam.center_on(pos)
                if mode == want and _confirm_mode(mode):
                        _tap(cam.world_to_screen(pos))
        else:
                hud.show_toast("Подходящего места не видно — выберите сами")



func _plan_action(nm: String) -> void :
        var p: Country = world.player
        var g = world.get("guide")
        if p == null or g == null:
                return
        match nm:
                "dip_best":
                        var cid: int = int(g.best_neighbour(p)) if g.has_method("best_neighbour") else -1
                        hud.dip_open = cid
                        hud._dip_scroll_to = cid
                        hud.dip_hint_treaty = "trade"
                        hud.open_diplomacy()
                "upg_best", "net_best", "dp_ramp":
                        var f: Facility = null
                        if nm == "upg_best" and g.has_method("upgrade_target"):
                                f = g.upgrade_target(p)
                        elif nm == "net_best" and g.has_method("net_target"):
                                f = g.net_target(p)
                        elif nm == "dp_ramp" and g.has_method("ramp_port"):
                                f = g.ramp_port(p)
                        if f == null:
                                hud.show_toast("Пока не на чем: постройте объект")
                                return
                        _deselect()
                        selected_fac = f
                        cam_lock = false
                        cam.center_on(f.center_px())
                        if nm == "dp_ramp":
                                _on_action("mod_ramp")
                        else:
                                hud.show_toast("Нажмите «СЕТКА» в карточке" if nm == "net_best" else "Улучшение — кнопка «УР» в карточке")




func net_begin(s: WorldSettings, humans: int, local_slot: int) -> void :
        hud.hide_prompt()
        menus.close()
        in_menu = false
        hud.visible = true
        _paused = false
        _speed_i = 0
        tutorial.stop()
        await start_world(s)
        world.mp_setup_humans(humans, local_slot, net.start_names, net.start_archs, net.start_flags)
        hud.set_net_mode(true)
        hud.refresh()
        _apply_speed()
        hud.show_toast("Мультиплеер: выберите место для столицы")




func net_after_restore() -> void :
        (load("res://game/front_plan.gd") as GDScript).call("reset")
        world.strike_net = null
        hud.set_net_mode(true)
        _apply_speed()
        hud.refresh()



func net_match_closed() -> void :
        hud.set_net_mode(false)
        if not in_menu:
                await _main_menu()
        menus.show_mp()




func _on_net_speed(old: int, new: int) -> void :
        _apply_speed()
        if _spick != null and is_instance_valid(_spick) and bool(_spick.get("is_open")):
                _spick.call("refresh_net")
        if not net.in_match:
                return
        var why: String = net.speed_why
        var me_name: String = world.player.name if world.player != null else ""
        if net.speed_why_prev == "start" and why != "start" and not _speed_hinted:
                _speed_hinted = true
                if GameConfig.mp_speed == 2:
                        hud.show_toast("УСКОРЕНИЕ ВЫКЛЮЧЕНО ХОСТОМ · ИГРА ИДЁТ x1")
                elif GameConfig.mp_speed == 1:
                        hud.show_toast("АВТОУСКОРЕНИЕ · В ЗАТИШЬЕ ДО x3")
                else:
                        hud.show_toast(Loc.t("УСКОРЕНИЕ ПО СОГЛАСИЮ · КНОПКА «СКОРОСТЬ»") + (Loc.msg(Loc.mk(" · ВСЕ ЗА x%d", [new])) if new > 1 else ""))
                return
        if old == new:
                return
        var t: String = Loc.t("СКОРОСТЬ x%d") % new
        if new > old:
                if GameConfig.mp_speed == 1:
                        return
                t += Loc.t(" · ВСЕ ЗА") if why == "want" else ""
        else:
                var now: int = Time.get_ticks_msec()
                if GameConfig.mp_speed == 1 and now - _speed_toast_ms < 15000:
                        return
                _speed_toast_ms = now
                if why == "lag":
                        t += Loc.t(" · ВАШЕ УСТРОЙСТВО НЕ УСПЕВАЕТ") if net.speed_who == NetConfig.nick() else (Loc.t(" · НЕ УСПЕВАЕТ %s") % net.speed_who.to_upper() if net.speed_who != "" else "")
                elif why == "want":
                        t += Loc.t(" · ВАШ ВЫБОР") if net.my_want == new else Loc.t(" · ВЫБОР %s") % net.speed_who.to_upper()
                elif why.begins_with("auto:"):
                        if net.speed_who == me_name:
                                return
                        t += " · %s%s" % [why.substr(5), (Loc.t(" У %s") % net.speed_who.to_upper()) if net.speed_who != "" else ""]
        hud.show_toast(t)



func net_rejoin_wait() -> void :
        menus.close()
        loading.show_screen("Возвращаемся в партию...")
        hud.set_net_mode(true)


func _on_net_player_back(nick: String) -> void :
        hud.show_toast(Loc.msg(Loc.mk("%s СНОВА В ПАРТИИ", [nick.to_upper()])))
        UiKit.snd("ui_select")



func net_toast(t: String) -> void :
        hud.show_toast(t)


func _net_banner_tick(delta: float) -> void :
        if net == null:
                return
        if not net.speed_changed.is_connected(_on_net_speed):
                net.speed_changed.connect(_on_net_speed)
        if not net.player_left.is_connected(_on_net_player_left):
                net.player_left.connect(_on_net_player_left)
        if not net.player_back.is_connected(_on_net_player_back):
                net.player_back.connect(_on_net_player_back)
        var st: Dictionary = net.plate() if net.in_match else {}
        var key: String = String(st.get("key", ""))
        if key != _net_last_key:
                if _net_last_key == "lost" and key == "" and net.in_match:
                        hud.show_toast("СВЯЗЬ ВОССТАНОВЛЕНА")
                _net_last_key = key
        if _net_banner == null:
                if st.is_empty():
                        return
                _net_banner = MpKit.Plate.new()
                hud.root.add_child(_net_banner)
        var w: float = minf(380.0, hud.root.size.x - 16.0)
        _net_banner.size = Vector2(w, 0.0)
        _net_banner.position = Vector2((hud.root.size.x - w) * 0.5, hud.top_col.position.y + hud.top_col.size.y + 4.0)
        _net_banner.set_state(st, delta)
        var extra: float = _resume_btn_tick(key == "resume" and net.is_host and _net_banner.visible)
        if hud.lane != null and is_instance_valid(hud.lane):
                hud.lane.set("push_y", (_net_banner.size.y + 4.0 + extra) if _net_banner.visible else 0.0)




func _resume_btn_tick(show: bool) -> float:
        if not show:
                if _resume_btn != null and is_instance_valid(_resume_btn):
                        _resume_btn.queue_free()
                _resume_btn = null
                return 0.0
        if _resume_btn == null or not is_instance_valid(_resume_btn):
                _resume_btn = UiKit.big("ИГРАТЬ БЕЗ НИХ", "green", "", 44.0, 11)
                _resume_btn.custom_minimum_size = Vector2(150, 44)
                _resume_btn.pressed.connect( func() -> void :
                        UiKit.snd("ui_select")
                        net.resume_go(false))
                hud.root.add_child(_resume_btn)
        _resume_btn.size = Vector2(150, 44)
        _resume_btn.position = Vector2(_net_banner.position.x + _net_banner.size.x - 150.0, _net_banner.position.y + _net_banner.size.y + 4.0)
        return 48.0


func _on_net_player_left(nick: String, lost: bool = true) -> void :
        hud.show_toast((Loc.t("У %s ПРОПАЛА СВЯЗЬ · СТРАНУ ВЕДЁТ ИИ") if lost else Loc.t("%s ВЫШЕЛ · СТРАНУ ВЕДЁТ ИИ")) % nick.to_upper())
        UiKit.snd("ui_select")
