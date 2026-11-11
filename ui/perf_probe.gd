extends CanvasLayer







const DURATION: float = 600.0
const SEED: int = 336336
const GAP_MS: float = 2000.0
const BENCH_N: int = 60000

static var armed: bool = false
static var inst: CanvasLayer = null

var dur: float = DURATION
var gw: GameWorld = null
var running: bool = false
var done: bool = false
var t0_us: int = 0
var last_us: int = 0
var gaps: int = 0
var ft: = PackedFloat32Array()
var mft: = PackedFloat32Array()
var rows: Array = []
var next_min: float = 60.0
var steps: int = 0
var m_steps: int = 0
var sim_tot: float = 0.0
var m_sim: float = 0.0
var sim_frame_max: float = 0.0
var sys_tot: Dictionary = {}
var sys_max: Dictionary = {}
var draw_sum: float = 0.0
var draw_max: int = 0
var m_draw: float = 0.0
var mem0: float = 0.0
var vmem0: float = 0.0
var mem_max: float = 0.0
var vmem_max: float = 0.0
var nodes_max: int = 0
var objs_max: int = 0
var temp_path: String = ""
var enc_task: int = -1
var enc_t0: int = 0
var enc_open: bool = false
var enc_ms: = PackedFloat32Array()
var objs_map_max: int = 0
var temp0: float = -1.0
var file: String = ""
var report: String = ""
var lbl: Label

var r_cpu: float = 0.0
var r_gpu: float = 0.0
var r_obj: float = 0.0
var r_prim: float = 0.0
var r_tp: float = 0.0
var r_tph: float = 0.0
var r_n: int = 0
const SWEEP_PH: float = 1.0
const SWEEP_SKIP: float = 0.15
var sweeping: bool = false
var sw_nodes: Array = []
var sw_i: int = 0
var sw_t: float = 0.0
var sw_ph: int = 0
var sw_acc: Array = [0, 0.0, 0.0, 0.0, 0.0, 0.0]
var sw_base: Array = []
var sw_res: Array = []
var copy_btn: Button
var _ui_t: float = 0.0


static func arm(tree: SceneTree, on: bool) -> void :
	armed = on
	if on and inst == null:
		inst = (load("res://ui/perf_probe.gd") as GDScript).new()
		tree.root.add_child(inst)
	elif not on and inst != null:
		if bool(inst.get("running")):
			inst.call("_finish", "probe switched off")
		inst.queue_free()
		inst = null
		GameWorld.perf_prof = false


func _ready() -> void :
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg: = PanelContainer.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_content_margin_all(3)
	bg.add_theme_stylebox_override("panel", sb)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.position = Vector2(4, 150)
	add_child(bg)
	var col: = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(col)
	lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(lbl)
	copy_btn = Button.new()
	copy_btn.text = "COPY REPORT"
	copy_btn.focus_mode = Control.FOCUS_NONE
	copy_btn.add_theme_font_size_override("font_size", 10)
	copy_btn.visible = false
	copy_btn.pressed.connect( func() -> void : DisplayServer.clipboard_set(report))
	col.add_child(copy_btn)
	lbl.text = "PERF PROBE armed: start a match"


func _world() -> GameWorld:
	var w: Variant = get_tree().current_scene.get("world") if get_tree().current_scene != null else null
	if not (w is GameWorld):
		for n: Node in get_tree().root.get_children():
			if n != self and n.get("world") is GameWorld:
				w = n.get("world")
				break
	return w as GameWorld if w is GameWorld and is_instance_valid(w) else null


func _process(delta: float) -> void :
	var now: int = Time.get_ticks_usec()
	var w: GameWorld = _world()
	if running and (w != gw or w == null):
		_finish("the match ended early")
	if not running:
		if not done and w != null and w.player != null and w.session != null and w.session.started:
			_begin(w, now)
		return
	var dt: float = float(now - last_us) / 1000.0
	last_us = now
	if dt > GAP_MS:
		gaps += 1
	else:
		ft.append(dt)
		mft.append(dt)
	steps += w.sim_steps
	m_steps += w.sim_steps
	_enc_watch(w, now)
	var fs: float = 0.0
	for k: String in w.perf_sys:
		var v: float = float(w.perf_sys[k])
		fs += v
		sys_tot[k] = float(sys_tot.get(k, 0.0)) + v
		if v > float(sys_max.get(k, 0.0)):
			sys_max[k] = v
	w.perf_sys.clear()
	sim_tot += fs
	m_sim += fs
	sim_frame_max = maxf(sim_frame_max, fs)
	var dc: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	draw_sum += dc
	m_draw += dc
	draw_max = maxi(draw_max, dc)
	var el: float = float(now - t0_us) / 1000000.0
	if el >= next_min:
		next_min += 60.0
		_minute(w)
		_write()
	_render_acc()
	if el >= dur:
		if not sweeping:
			_sweep_begin(w)
		if _sweep(delta, dt):
			_finish("")
		return
	_ui_t -= delta
	if _ui_t <= 0.0:
		_ui_t = 0.5
		_overlay(el)




func _enc_watch(w: GameWorld, now: int) -> void :
	var tk: int = int(w._enc_job.get("task", -1)) if not w._enc_job.is_empty() else -1
	if enc_open and tk != enc_task:
		enc_open = false
		enc_ms.append(float(now - enc_t0) / 1000.0)
	if tk >= 0 and tk != enc_task:
		enc_task = tk
		enc_t0 = now
		enc_open = true
	if enc_open and WorkerThreadPool.is_task_completed(tk):
		enc_open = false
		enc_ms.append(float(now - enc_t0) / 1000.0)



func _render_acc() -> void :
	var vp: RID = get_viewport().get_viewport_rid()
	r_cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
	r_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	r_obj += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	r_prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	r_tp += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	r_tph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	r_n += 1





func _sweep_begin(w: GameWorld) -> void :
	sweeping = true
	sw_nodes = []
	for c: Node in w.get_children():
		if c is CanvasItem and (c as CanvasItem).visible:
			sw_nodes.append(c)
	var sc: Node = w.get_parent()
	if sc != null:
		for c2: Node in sc.get_children():
			if c2 is CanvasLayer and c2 != self and (c2 as CanvasLayer).visible:
				sw_nodes.append(c2)
	sw_i = 0
	sw_t = 0.0
	sw_ph = 0
	sw_base = []
	sw_acc = [0, 0.0, 0.0, 0.0, 0.0, 0.0]



func _sweep(delta: float, dt: float) -> bool:
	if sw_i >= sw_nodes.size():
		return true
	sw_t += delta
	if sw_t >= SWEEP_SKIP:
		var vp: RID = get_viewport().get_viewport_rid()
		sw_acc[0] += 1
		sw_acc[1] += dt
		sw_acc[2] += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		sw_acc[3] += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		sw_acc[4] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		sw_acc[5] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	if sw_t >= SWEEP_PH:
		var n: float = maxf(1.0, float(sw_acc[0]))
		var r: Array = [float(sw_acc[1]) / n, float(sw_acc[2]) / n, float(sw_acc[3]) / n, float(sw_acc[4]) / n, float(sw_acc[5]) / n]
		sw_acc = [0, 0.0, 0.0, 0.0, 0.0, 0.0]
		sw_t = 0.0
		var nd: Node = sw_nodes[sw_i] if is_instance_valid(sw_nodes[sw_i]) else null
		if sw_ph == 0:
			sw_base = r
			sw_ph = 1
			if nd != null:
				nd.set("visible", false)
		else:
			sw_ph = 0
			sw_i += 1
			if nd != null:
				nd.set("visible", true)
				sw_res.append([String(nd.name), float(sw_base[0]) - float(r[0]), float(sw_base[1]) - float(r[1]), float(sw_base[2]) - float(r[2]), 
					float(sw_base[3]) - float(r[3]), float(sw_base[4]) - float(r[4])])
	lbl.text = "PERF LAYER SWEEP %d/%d (layers blink: ok)" % [mini(sw_i + 1, sw_nodes.size()), sw_nodes.size()]
	return sw_i >= sw_nodes.size()


func _sweep_restore() -> void :
	if sweeping and sw_ph == 1 and sw_i < sw_nodes.size() and is_instance_valid(sw_nodes[sw_i]):
		(sw_nodes[sw_i] as Node).set("visible", true)
	sweeping = false


func _begin(w: GameWorld, now: int) -> void :
	gw = w
	running = true
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	t0_us = now
	last_us = now
	GameWorld.perf_prof = true
	w.perf_sys.clear()
	mem0 = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	vmem0 = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	mem_max = mem0
	vmem_max = vmem0
	if OS.get_name() == "Android":
		for p: String in ["/sys/class/power_supply/battery/temp", "/sys/class/thermal/thermal_zone0/temp"]:
			if _temp(p) > 0.0:
				temp_path = p
				break
	temp0 = _temp(temp_path)
	var ts: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	file = "user://perf/%s.txt" % ts
	DirAccess.make_dir_recursive_absolute("user://perf")



func _temp(p: String) -> float:
	if p == "":
		return -1.0
	var f: FileAccess = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return -1.0
	var v: float = f.get_as_text().strip_edges().to_float()
	return v / 1000.0 if v > 1000.0 else v / 10.0


func _pct(a: PackedFloat32Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	return a[clampi(int(float(a.size() - 1) * q), 0, a.size() - 1)]



func _low(sorted: PackedFloat32Array, part: float) -> float:
	var n: int = maxi(1, int(float(sorted.size()) * part))
	var s: float = 0.0
	for i in range(sorted.size() - n, sorted.size()):
		s += sorted[i]
	return 1000.0 * float(n) / maxf(0.001, s)


func _fps(a: PackedFloat32Array) -> float:
	var s: float = 0.0
	for v: float in a:
		s += v
	return 1000.0 * float(a.size()) / maxf(0.001, s)


func _bench() -> int:
	var us: int = Time.get_ticks_usec()
	var x: int = 1
	for i in BENCH_N:
		x = (x * 1103515245 + 12345 + i) & 16777215
	return Time.get_ticks_usec() - us + (x & 0)


func _minute(w: GameWorld) -> void :
	var s: PackedFloat32Array = mft.duplicate()
	s.sort()
	var mem: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var vmem: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objs: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	mem_max = maxf(mem_max, mem)
	vmem_max = maxf(vmem_max, vmem)
	nodes_max = maxi(nodes_max, nodes)
	objs_max = maxi(objs_max, objs)
	rows.append([rows.size() + 1, _fps(mft), _low(s, 0.01), _pct(s, 0.95), m_sim / float(maxi(1, m_steps)), mem, vmem, nodes, 
		m_draw / float(maxi(1, mft.size())), _bench(), _temp(temp_path), int(w.game_time)])
	mft = PackedFloat32Array()
	m_steps = 0
	m_sim = 0.0
	m_draw = 0.0


func _overlay(el: float) -> void :
	var fps: float = Engine.get_frames_per_second()
	mem_max = maxf(mem_max, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	vmem_max = maxf(vmem_max, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
	nodes_max = maxi(nodes_max, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	objs_max = maxi(objs_max, int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	if gw != null and is_instance_valid(gw):
		objs_map_max = maxi(objs_map_max, gw.obj_spr.size() - gw._free_ids.size())
	var vp: RID = get_viewport().get_viewport_rid()
	lbl.text = "PERF %02d:%02d/%02d:00  fps %d  sim %.1f ms/step\nmem %d MB  vmem %d MB  nodes %d  dc %d\ncpu %.1f gpu %.1f ms  obj %d" % [
		int(el) / 60, int(el) % 60, int(dur) / 60, int(fps), sim_tot / float(maxi(1, steps)), 
		roundi(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0), roundi(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0), 
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), 
		RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(), RenderingServer.viewport_get_measured_render_time_gpu(vp), 
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))]


func _finish(why: String) -> void :
	_sweep_restore()
	running = false
	done = true
	GameWorld.perf_prof = false
	if gw != null and is_instance_valid(gw) and not mft.is_empty():
		_minute(gw)
	_write(why)
	DisplayServer.clipboard_set(report)
	lbl.text = "PERF DONE%s\n%s\nreport copied to the clipboard" % [" (" + why + ")" if why != "" else "", file]
	copy_btn.visible = true


func _write(why: String = "running") -> void :
	report = _report(why)
	var f: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	if f != null:
		f.store_string(report)
		f.close()


func _report(why: String) -> String:
	var s: PackedFloat32Array = ft.duplicate()
	s.sort()
	var el: float = float(last_us - t0_us) / 1000000.0
	var L: PackedStringArray = []
	L.append("DroneFlames PERF PROBE (R336D) %s  %s  status: %s" % [str((load("res://ui/menus.gd") as GDScript).get_script_constant_map().get("VERSION", "?")), Time.get_datetime_string_from_system(), why if why != "" else "complete"])
	L.append("device: %s | %s %s | cores %d | gpu %s (%s) | %s" % [OS.get_model_name(), OS.get_name(), OS.get_version(), OS.get_processor_count(), 
		RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(), str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ""))])
	L.append("screen %s window %s | max_fps %d | power save %s | effects %d | clouds %s | night %s" % [str(DisplayServer.screen_get_size()), str(get_viewport().get_visible_rect().size), 
		Engine.max_fps, str(GameConfig.power_save), GameConfig.fx_level, str(GameConfig.clouds), str(GameConfig.night)])
	var ok: bool = GameConfig.map_seed == SEED and GameConfig.size_i == 2 and GameConfig.bots == 6
	L.append("match: seed %d size %s bots %d type %d | game time %d s | speed x%s | scenario %s" % [GameConfig.map_seed, str(GameConfig.SIZE_NAMES[clampi(GameConfig.size_i, 0, 2)]), 
		GameConfig.bots, GameConfig.map_type, int(gw.game_time) if gw != null and is_instance_valid(gw) else -1, str(gw.time_scale) if gw != null and is_instance_valid(gw) else "?", "OK" if ok else "DIFFERENT (see docs/phone_perf.md)"])
	L.append("real %.0f s | frames %d | background gaps %d" % [el, ft.size(), gaps])
	L.append("FPS avg %.1f | 1%% low %.1f | 0.1%% low %.1f" % [_fps(ft), _low(s, 0.01), _low(s, 0.001)])
	L.append("frame ms p50 %.1f | p95 %.1f | p99 %.1f | max %.1f" % [_pct(s, 0.5), _pct(s, 0.95), _pct(s, 0.99), _pct(s, 1.0)])
	L.append("sim (main thread): %d steps (%.1f/s) | %.2f ms/step | %.1f ms per real s (%.1f%% of the frame time) | worst frame %.1f ms" % [steps, float(steps) / maxf(1.0, el), 
		sim_tot / float(maxi(1, steps)), sim_tot / maxf(1.0, el), 100.0 * sim_tot / maxf(1.0, el * 1000.0), sim_frame_max])
	var es: PackedFloat32Array = enc_ms.duplicate()
	es.sort()
	var esum: float = 0.0
	for v: float in es:
		esum += v
	L.append("enclave worker jobs: %d | avg %.0f ms | p95 %.0f ms | max %.0f ms (wall time on a worker thread, +-1 frame)" % [es.size(), esum / float(maxi(1, es.size())), _pct(es, 0.95), _pct(es, 1.0)])
	var ks: Array = sys_tot.keys()
	ks.sort_custom( func(a: String, b: String) -> bool: return float(sys_tot[a]) > float(sys_tot[b]))
	var sl: String = ""
	for k: String in ks.slice(0, 14):
		sl += "\n  %-22s %7.3f ms/step  max %6.1f" % [k, float(sys_tot[k]) / float(maxi(1, steps)), float(sys_max[k])]
	L.append("sim by system:" + sl)
	L.append("memory static MB: start %.0f max %.0f | video MB: start %.0f max %.0f | objects max %d | nodes max %d | map objects max %d" % [mem0, mem_max, vmem0, vmem_max, objs_max, nodes_max, objs_map_max])
	L.append("draw calls avg %.0f max %d" % [draw_sum / float(maxi(1, ft.size())), draw_max])

	var rn: float = float(maxi(1, r_n))
	L.append("render per frame: cpu %.2f ms | gpu %.2f ms | objects %.0f | primitives %.0f | TIME_PROCESS %.2f ms | TIME_PHYSICS %.2f ms" % [
		r_cpu / rn, r_gpu / rn, r_obj / rn, r_prim / rn, r_tp / rn, r_tph / rn])
	if not sw_res.is_empty():
		for key: Array in [[1, "frame"], [2, "gpu"], [3, "render cpu"]]:
			var srt: Array = sw_res.duplicate()
			srt.sort_custom( func(a: Array, b: Array) -> bool: return float(a[int(key[0])]) > float(b[int(key[0])]))
			var tl: String = ""
			for e: Array in srt.slice(0, 5):
				tl += "  %s %.2f" % [e[0], float(e[int(key[0])])]
			L.append("layer sweep top by %s ms:%s" % [key[1], tl])
		var al: String = ""
		for e2: Array in sw_res:
			al += "\n  %-18s frame %6.2f gpu %6.2f rcpu %6.2f dc %5.0f obj %6.0f" % e2
		L.append("layer sweep (ms saved when hidden):" + al)
	if not rows.is_empty():
		var r0: Array = rows[mini(1, rows.size() - 1)]
		var r1: Array = rows[rows.size() - 1]
		L.append("thermal: %s | proxy: FPS min%d -> min%d %+.0f%%, CPU bench %+.0f%% (> +15%% = throttling likely)" % [
			("battery/soc %.1f -> %.1f C" % [temp0, float(r1[10])]) if temp_path != "" else "no sensor readable (iOS / Android without access)", 
			int(r0[0]), int(r1[0]), 100.0 * (float(r1[1]) / maxf(0.1, float(r0[1])) - 1.0), 100.0 * (float(r1[9]) / maxf(1.0, float(r0[9])) - 1.0)])
	L.append("min | fps | 1%low | p95 ms | sim ms/step | mem MB | vmem MB | nodes | draw | bench us | temp C | game s")
	for r: Array in rows:
		L.append("%3d | %5.1f | %5.1f | %6.1f | %6.2f | %4.0f | %4.0f | %6d | %4.0f | %6d | %5.1f | %d" % r)
	return "\n".join(L) + "\n"
