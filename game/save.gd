class_name Save
extends RefCounted




















const SaveSlots = preload("res://game/save_slots.gd")
static var PATH: String = "user://saves/slot_1.save"
static var TMP: String = "user://saves/slot_1.save.tmp"
static var BAK: String = "user://saves/slot_1.save.bak"
const MAGIC: int = 827541060
const FORMAT: int = 1
const REF: String = "r"
const SET: String = "s"
const ENTITY: Array = [&"Country", &"City", &"Facility", &"Unit", &"Drone", &"Missile", &"Aircraft", &"Bridge", &"Rng"]

const ORDER: Array = ["mil", "econ", "rail", "army", "defense", "diplo", "ai", "session", "vision"]


const GENERIC: Array = ["defense", "diplo", "ai", "session"]


const CFG: Array = ["bots", "difficulty", "aggression", "victory", "target_i", "time_i", "size_i", "tutorial", "fog", "ore_preset", "ore_custom", "creative", "expand_i", "reserves_i", "ai_autodig", "alliances", "limit_i"]


const PREFS: Array = ["night", "hints", "econ_fx", "clouds", "fx_level", "performance_mode", "graphics_chosen", "pause_fps_limit", "ground_detail", "day_grade", "perf_hud", "confirm_actions", "dev_mode", "arch_i", "opening", "notif_mode", "plan_pos", "power_save", "my_name", "my_flag", "my_land", "cb_on", "cb_list", "my_money", "lang", "pseudo_loc", "fps_i", "ui_scale_i", "ui_scale_auto", "resolution_w", "resolution_h", "mods_enabled", "chunk_culling", "tree_batching", "tree_sway_mode", "object_lod", "simple_cover", "strat_lod_z", "dynamic_fps_target"]
const DISPLAY_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(3840, 2160), Vector2i(2560, 1600), Vector2i(2560, 1440),
	Vector2i(1920, 1200), Vector2i(1920, 1080), Vector2i(1680, 1050),
	Vector2i(1600, 900), Vector2i(1440, 900), Vector2i(1366, 768),
	Vector2i(1280, 800), Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1024, 576)
]
static var prefs_path: String = "user://settings.cfg"

const DELAY_OK: Array = ["_apply_strike", "_grow_initial"]
const AUTOSAVE_S: float = 60.0
const AUTOSAVE_IDLE_S: float = 20.0

static var _ents: Array = []
static var _ent_ix: Dictionary = {}
static var _dec: Array = []
static var _names_c: Dictionary = {}
static var _cls: Dictionary = {}
static var dropped: Dictionary = {}
static var last: Dictionary = {}
static var _task: int = -1
static var _write_ok: bool = true
static var _info_c: Dictionary = {}
static var _auto_t: float = 0.0

static var slot: int = 1
static var pick: int = 0
static var want: Array = []
static var _fresh: bool = false
static var _seq: int = 0
static var _mid: int = 0
static var _last_gt: float = -1.0





static func has_save() -> bool:
	return SaveSlots.continue_slot() > 0




static func save_info() -> Dictionary:
	var cs: int = SaveSlots.continue_slot()
	if cs <= 0:
		return {}
	var hh: Dictionary = (SaveSlots.info(cs)["head"] as Dictionary).duplicate()
	hh["slot"] = cs
	return hh




static func delete_save() -> void :
	_wait()
	SaveSlots.delete(slot)
	_info_c.clear()



static func use_slot(n: int) -> void :
	slot = clampi(n, 1, SaveSlots.N)
	PATH = SaveSlots.path(slot, "main")
	TMP = SaveSlots.path(slot, "tmp")
	BAK = SaveSlots.path(slot, "bak")
	_seq = SaveSlots.next_seq(slot) - 1





static func begin_new() -> void :
	_wait()
	SaveSlots.migrate()
	use_slot(pick if pick > 0 else slot)
	pick = 0
	_fresh = true
	_mid = randi()
	_last_gt = -1.0
	_auto_t = 0.0
	want = []




static func match_over(win: bool) -> void :
	if GameConfig.no_save or _fresh:
		return
	SaveSlots.set_flag(slot, "end", SaveSlots.END_WIN if win else SaveSlots.END_LOSS)



static func can_save(m: Node) -> bool:
	if m == null or bool(m.get("in_menu")):
		return false
	var gw: GameWorld = m.get("world")
	return why_not(m) == ""





static func why_not(m: Node) -> String:
	if m == null or bool(m.get("in_menu")):
		return "Сохранять пока нечего"
	var gw: GameWorld = m.get("world")
	if gw == null or gw.data == null or gw.player == null or gw.session == null:
		return "Сохранять пока нечего"
	if gw.net_driven or GameConfig.no_save:
		return "Эта партия не сохраняется"
	if GameConfig.tutorial:
		return "Обучение не сохраняется"
	if gw.player.eliminated or gw.player.city_ids.is_empty():
		return "Страна разгромлена — сохранять нечего"
	if gw.player.capital_id < 0:
		return "Сохранять пока нечего: поставьте столицу"
	return ""



static func save_game(m: Node) -> bool:
	if not can_save(m):
		return false
	_wait()
	var t0: int = Time.get_ticks_usec()
	var snap: Array = _snapshot(m)
	if not _sound(snap[1]):
		return false
	var t1: int = Time.get_ticks_usec()
	var gw: GameWorld = m.get("world")
	var th: Image = SaveSlots.render_thumb(SaveSlots.thumb_input(gw))
	var ok: bool = _write_raw(snap[0], var_to_bytes(snap[1]), "main", th)
	last["save_snapshot_ms"] = (t1 - t0) / 1000.0
	last["save_write_ms"] = (Time.get_ticks_usec() - t1) / 1000.0
	if ok:
		_last_gt = gw.game_time
	return ok



static func tick(m: Node, delta: float) -> void :
	_auto_t += delta
	if _auto_t >= AUTOSAVE_S:


		var t: Variant = m.get("_touches")
		if t is Dictionary and not (t as Dictionary).is_empty() and _auto_t < AUTOSAVE_S + AUTOSAVE_IDLE_S:
			return
		_auto_t = 0.0
		autosave(m)




static func autosave(m: Node) -> bool:
	if not can_save(m):
		return false
	var gwe: GameWorld = m.get("world")
	if gwe.session.ended and bool(m.get("_paused")):
		return false
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return false
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	var gw0: GameWorld = m.get("world")
	if absf(gw0.game_time - _last_gt) < 0.01:
		return false
	var t0: int = Time.get_ticks_usec()
	var snap: Array = _snapshot(m)
	if not _sound(snap[1]):
		return false




	var raw: PackedByteArray = var_to_bytes(snap[1])
	var thi: Dictionary = SaveSlots.thumb_input(gw0)
	last["autosave_main_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	_task = WorkerThreadPool.add_task(_write_job.bind(snap[0], raw, thi, _fresh), false, "autosave")
	_fresh = false
	_last_gt = gw0.game_time
	return true




static func load_game(m: Node) -> bool:
	_wait()
	var w: Array = want
	want = []
	var n: int = int(w[0]) if w.size() >= 2 else SaveSlots.continue_slot()
	if n <= 0:
		return false
	return await load_slot(m, n, String(w[1]) if w.size() >= 2 else "")




static func load_slot(m: Node, n: int, key: String = "") -> bool:
	_wait()
	var pack: Dictionary = {}
	for p: String in SaveSlots.load_order(n, key):
		var r: Dictionary = _read(p)
		if not r.is_empty() and _sound(r["body"]):
			pack = r
			break
		if FileAccess.file_exists(p):
			push_warning("[Save] %s is damaged, trying the next copy" % p)
	if pack.is_empty():
		SaveSlots.set_flag(n, "bad", true)
		return false
	use_slot(n)
	pick = 0
	_fresh = false
	_mid = int((pack["header"] as Dictionary).get("mid", 0))
	if _mid == 0:
		_mid = randi()
	SaveSlots.set_flag(n, "end", SaveSlots.END_NONE)
	SaveSlots.set_flag(n, "bad", false)
	GameConfig.no_save = false
	var ok: bool = await _load_pack(m, pack, false)
	if ok:
		_last_gt = -1.0
	return ok




static func net_snapshot(m: Node) -> PackedByteArray:
	if m == null or not is_instance_valid(m) or m.get("world") == null:
		return PackedByteArray()
	_wait()
	var snap: Array = _snapshot(m)
	if snap.size() < 2:
		return PackedByteArray()
	var raw: PackedByteArray = var_to_bytes(snap[1])
	return var_to_bytes([raw.size(), raw.compress(FileAccess.COMPRESSION_ZSTD)])



static func net_restore(m: Node, bytes: PackedByteArray) -> bool:
	_wait()
	var v: Variant = bytes_to_var(bytes)
	if not (v is Array) or (v as Array).size() != 2:
		if m != null and m.get("loading") != null and m.loading.active:
			m.loading.finish()
		return false
	var raw: PackedByteArray = ((v as Array)[1] as PackedByteArray).decompress(int((v as Array)[0]), FileAccess.COMPRESSION_ZSTD)
	var body: Variant = bytes_to_var(raw)
	if not (body is Dictionary) or not (body as Dictionary).has("core"):
		if m != null and m.get("loading") != null and m.loading.active:
			m.loading.finish()
		return false
	var res: bool = await _load_pack(m, {"path": "net", "header": {}, "body": body}, true)
	if not res and m != null and m.get("loading") != null and m.loading.active:
		m.loading.finish()
	return res



static func _load_pack(m: Node, pack: Dictionary, net: bool) -> bool:
	var t0: int = Time.get_ticks_usec()
	var body: Dictionary = pack["body"]
	var core: Dictionary = body["core"]
	var gw: GameWorld = m.get("world")
	var mm: Variant = m
	var cfg_in: Dictionary = core.get("cfg", {})
	_set_cfg(cfg_in)
	if not cfg_in.has("creative"):
		GameConfig.creative = false
	var s: = WorldSettings.new()
	s.gen_version = 1
	fill(s, core["settings"])
	if mm.menus != null:
		mm.menus.close()
	mm.in_menu = false
	mm.hud.visible = true
	mm._paused = false
	mm.tutorial.stop()
	mm.settings = s
	mm.loading.show_screen(Loc.t("Синхронизация с хостом...") if net else Loc.t("Загружаем партию..."))
	var keep_cam: Vector2 = mm.cam.position
	var keep_z: float = mm.cam.zoom.x
	mm._deselect()
	mm._clear_plan()
	mm.hud.close_panel()
	mm.loading.set_progress(0.12, Loc.t("Рельеф, реки и леса..."))
	await m.get_tree().process_frame
	await m.get_tree().process_frame
	var t1: int = Time.get_ticks_usec()
	gw.set_process(false)
	if not net:
		gw.net_driven = false
	gw.time_scale = 0.0
	gw.new_world(s)
	var t2: int = Time.get_ticks_usec()
	mm.loading.set_progress(0.55, Loc.t("Страны, города и границы..."))
	await m.get_tree().process_frame
	var t3: int = Time.get_ticks_usec()
	_load_core(gw, body)
	for c316: Country in gw.countries:
		while c316.missile_stock.size() < Military.MT_CAP.size():
			c316.missile_stock.append(0)
	if not cfg_in.has("creative") and gw.player != null:
		GameConfig.creative = gw.player.money >= 900000
	var t4: int = Time.get_ticks_usec()
	mm.loading.set_progress(0.72, Loc.t("Предприятия, армии, торговля..."))
	await m.get_tree().process_frame
	var t5: int = Time.get_ticks_usec()
	_load_systems(gw, body.get("sys", {}))
	if not net:
		Military.unpave_cells(gw, gw.data.dirty_cells.duplicate())
		if gw.mil != null:
			gw.mil.heal_partial(true)
	var t6: int = Time.get_ticks_usec()
	mm.loading.set_progress(0.88, Loc.t("Готовим карту..."))
	await m.get_tree().process_frame
	var t7: int = Time.get_ticks_usec()
	gw.terrain.flush()
	var t7b: int = Time.get_ticks_usec()
	var t7c: int = t7b
	_finish(gw, core)
	gw.set_process(true)
	var cam: MapCamera = mm.cam
	var z: float = keep_z if net else float(core.get("zoom", 1.0))
	cam.set_zoom_at(z, cam.view_size() * 0.5)
	cam.position = keep_cam if net else core.get("cam", cam.position)
	mm._on_zoom(z)
	if not net:
		var speeds: Array = mm.SPEEDS
		mm._speed_i = clampi(int(core.get("speed_i", 0)), 0, speeds.size() - 1)
		mm._apply_speed()
	var t8: int = Time.get_ticks_usec()
	mm.loading.finish()
	if not net:
		mm._snd("music", ["game"])
		mm._snd("loop", ["amb_wind", "ambient_wind_loop", true, Vector2.INF, -12.0])
	mm.hud.city_labels_reset()
	mm.hud.refresh()
	mm._set_mode(0)
	if not net:
		mm.hud.select_page(1)
	_auto_t = 0.0
	last["load_read_ms"] = (t1 - t0) / 1000.0
	last["load_world_ms"] = (t2 - t1) / 1000.0
	last["load_core_ms"] = (t4 - t3) / 1000.0
	last["load_systems_ms"] = (t6 - t5) / 1000.0
	last["load_terrain_ms"] = (t7b - t7) / 1000.0
	last["load_finish_ms"] = (t8 - t7c) / 1000.0
	last["load_total_ms"] = (t8 - t0) / 1000.0
	last["load_file"] = pack["path"]
	print("[Save] loaded %s: %s" % [pack["path"], last])
	return true










static func dump(o: Object, skip: Array = []) -> Dictionary:
	var cx: Variant = _complex(o)
	if cx == null:
		return dump_slow(o, skip)
	var src: Dictionary = inst_to_dict(o)
	var names: PackedStringArray = _names(o)
	var fl: PackedByteArray = cx
	var out: Dictionary = {}
	for i: int in names.size():
		var n: String = names[i]
		if not src.has(n) or ( not skip.is_empty() and skip.has(n)):
			continue
		var v: Variant = src[n]
		if fl[i] == 0:
			out[n] = v
			continue
		var t: int = typeof(v)
		if t == TYPE_CALLABLE or t == TYPE_SIGNAL or t == TYPE_RID or (t == TYPE_OBJECT and v != null and not _is_entity(v)):
			continue
		out[n] = enc(v)
	return out


static var _cx_c: Dictionary = {}


static func _complex(o: Object) -> Variant:
	var s: Script = o.get_script()
	if s == null or not s.resource_path.begins_with("res://") or s.resource_path.contains("::"):
		return null
	if _cx_c.has(s):
		return _cx_c[s]
	var ty: Dictionary = {}
	for p: Dictionary in o.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			ty[String(p["name"])] = int(p["type"])
	var out: = PackedByteArray()
	for n: String in _names(o):
		var t: int = int(ty.get(n, TYPE_NIL))
		out.append(1 if t == TYPE_NIL or t == TYPE_OBJECT or t == TYPE_ARRAY or t == TYPE_DICTIONARY or t == TYPE_CALLABLE or t == TYPE_SIGNAL or t == TYPE_RID else 0)
	_cx_c[s] = out
	return out



static func dump_slow(o: Object, skip: Array = []) -> Dictionary:
	var out: Dictionary = {}
	for n: String in _names(o):
		if skip.has(n):
			continue
		var v: Variant = o.get(n)
		var t: int = typeof(v)
		if t == TYPE_CALLABLE or t == TYPE_SIGNAL or t == TYPE_RID:
			continue
		if t == TYPE_OBJECT and v != null and not _is_entity(v):
			continue
		out[n] = enc(v)
	return out



static func fill(o: Object, d: Dictionary, skip: Array = []) -> void :
	var names: PackedStringArray = _names(o)
	for k: Variant in d:
		var n: String = String(k)
		if n.begins_with("$") or skip.has(n) or not names.has(n):
			continue
		_assign(o, n, dec(d[k]))


static func enc(v: Variant) -> Variant:
	match typeof(v):
		TYPE_OBJECT:
			return _ref(v)
		TYPE_ARRAY:
			var a: Array = v
			if a.is_typed() and a.get_typed_builtin() != TYPE_OBJECT and a.get_typed_builtin() != TYPE_ARRAY and a.get_typed_builtin() != TYPE_DICTIONARY:
				var plain: Array = []
				plain.assign(a)
				return plain
			var out: Array = []
			out.resize(a.size())
			for i in a.size():
				var e: Variant = a[i]
				var te: int = typeof(e)
				out[i] = e if te < TYPE_RID or te > TYPE_ARRAY else enc(e)
			return out
		TYPE_DICTIONARY:
			var d: Dictionary = v
			var out2: Dictionary = {}
			for k: Variant in d:
				var dv: Variant = d[k]
				var tk: int = typeof(k)
				var tv: int = typeof(dv)

				out2[k if tk < TYPE_RID or tk > TYPE_ARRAY else enc(k)] = dv if tv < TYPE_RID or tv > TYPE_ARRAY else enc(dv)
			return out2
		TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return null
	return v


static func dec(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var d: Dictionary = v
			if d.size() == 1 and d.has(REF):
				var i: int = int(d[REF])
				return _dec[i] if i >= 0 and i < _dec.size() else null
			if d.size() == 1 and d.has(SET):
				var keys: PackedInt32Array = d[SET]
				var st: Dictionary = {}
				for k: int in keys:
					st[k] = true
				return st
			var out: Dictionary = {}
			for k: Variant in d:
				out[dec(k)] = dec(d[k])
			return out
		TYPE_ARRAY:
			var a: Array = v
			var out2: Array = []
			out2.resize(a.size())
			for i in a.size():
				out2[i] = dec(a[i])
			return out2
	return v


static func _is_entity(o: Object) -> bool:
	if not is_instance_valid(o):
		return false
	var s: Script = o.get_script()
	return s != null and ENTITY.has(s.get_global_name())


static func _ref(o: Object) -> Variant:
	if o == null or not is_instance_valid(o):
		return null
	var iid: int = o.get_instance_id()
	if _ent_ix.has(iid):
		return {REF: _ent_ix[iid]}
	var s: Script = o.get_script()
	var cn: StringName = s.get_global_name() if s != null else &""
	if not ENTITY.has(cn):
		var key: String = String(cn) if cn != &"" else o.get_class()
		dropped[key] = int(dropped.get(key, 0)) + 1
		return null
	var i: int = _ents.size()
	_ents.append(o)
	_ent_ix[iid] = i
	return {REF: i}


static func _names(o: Object) -> PackedStringArray:
	var s: Script = o.get_script()
	var key: Variant = s if s != null else o.get_class()
	if _names_c.has(key):
		return _names_c[key]
	var out: = PackedStringArray()
	for p: Dictionary in o.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(String(p["name"]))
	_names_c[key] = out
	return out


static func _assign(o: Object, n: String, v: Variant) -> void :
	var cur: Variant = o.get(n)
	var tc: int = typeof(cur)
	if tc == TYPE_ARRAY and typeof(v) == TYPE_ARRAY and (cur as Array).is_typed():
		var ca: Array = cur
		var typed: = Array([], ca.get_typed_builtin(), ca.get_typed_class_name(), ca.get_typed_script())
		typed.assign(v)
		o.set(n, typed)
		return
	if tc == TYPE_DICTIONARY and typeof(v) == TYPE_DICTIONARY and (cur as Dictionary).is_typed():
		var cd: Dictionary = cur
		var td: = Dictionary({}, cd.get_typed_key_builtin(), cd.get_typed_key_class_name(), cd.get_typed_key_script(), 
			cd.get_typed_value_builtin(), cd.get_typed_value_class_name(), cd.get_typed_value_script())
		td.assign(v)
		o.set(n, td)
		return
	if tc == TYPE_OBJECT and cur != null and not _is_entity(cur):
		return
	o.set(n, v)


static func _ent_fields(o: Object) -> Dictionary:
	var d: Dictionary = dump(o, ["fx"] if o is Facility else (["visited"] if o is City else []))
	# Mods store custom facility/unit state in Object metadata. Preserve it beside
	# normal script properties so modded entities retain identity and progress.
	var meta: Dictionary = {}
	for key: StringName in o.get_meta_list():
		meta[String(key)] = o.get_meta(key)
	if not meta.is_empty():
		d["$meta"] = enc(meta)
	if o is City:
		d["visited"] = {SET: PackedInt32Array((o as City).visited.keys())}
		var fl: Variant = (o as City).flag_node
		if fl is Node2D and is_instance_valid(fl):
			d["$flag"] = (fl as Node2D).position
	return d


static func _reset_codec() -> void :
	_ents = []
	_ent_ix = {}
	dropped = {}


static func _class_script(cn: String) -> Script:
	if _cls.is_empty():
		for g: Dictionary in ProjectSettings.get_global_class_list():
			_cls[String(g["class"])] = String(g["path"])
	if not _cls.has(cn):
		return null
	return load(String(_cls[cn])) as Script




static func _snapshot(m: Node) -> Array:
	var gw: GameWorld = m.get("world")
	_reset_codec()
	var parts: Dictionary = {}
	var tp: int = Time.get_ticks_usec()
	var core: Dictionary = {}

	core["countries"] = enc(gw.countries)
	core["cities"] = enc(gw.cities)
	core["bridges"] = enc(gw.bridges)
	core["player"] = enc(gw.player)
	core["rng"] = enc(gw.rng)
	core["settings"] = dump(gw.settings)
	var cfg: Dictionary = {}
	for n: String in CFG:
		cfg[n] = (GameConfig as GDScript).get(n)
	core["cfg"] = enc(cfg)
	for n: String in ["game_time", "_expand_t", "_ai_t", "_ruin_t", "_fire_snd_t", "map_mode", "show_own_icons", "_checkpoints_dirty"]:
		core[n] = gw.get(n)
	core["road_paths"] = enc(gw.road_paths)
	var cps: Dictionary = {}
	for key: String in gw.checkpoints:
		var cp: Dictionary = gw.checkpoints[key]
		cps[key] = {"objs": cp["objs"], "cell": cp.get("cell", Vector2i.ZERO), "cells": enc(cp.get("cells", []))}
	core["checkpoints"] = cps
	var fires: Array = []
	for f: Dictionary in gw.fires:
		var fc: Dictionary = f.duplicate()
		fc["h"] = []
		fires.append(enc(fc))
	core["fires"] = fires
	core["ruins"] = enc(gw.ruins)
	core["decals"] = enc(gw.ground.decals)
	var dl: Array = []
	for d: Array in gw._delayed:
		var cb: Callable = d[1]
		if cb.is_valid() and cb.get_object() == gw and DELAY_OK.has(String(cb.get_method())):
			dl.append([float(d[0]), String(cb.get_method()), enc(cb.get_bound_arguments())])
	core["delayed"] = dl

	var rj: Array = []
	for job: Dictionary in gw._road_jobs:
		if job.has("xb"):
			continue
		rj.append([enc(job["pairs"]), bool(job["first"])])
	core["road_jobs"] = rj

	core["biome"] = gw.data.biome
	core["flags"] = gw.data.flags
	core["owners"] = gw.data.owners

	core["obj_spr"] = gw.obj_spr
	core["obj_x"] = gw.obj_x
	core["obj_y"] = gw.obj_y
	core["obj_state"] = gw.obj_state
	core["obj_kind"] = gw.obj_kind
	core["obj_hidden"] = gw.obj_hidden
	core["free_ids"] = gw._free_ids
	core["obj_fix"] = gw.obj_fix.duplicate()
	core["spr_name"] = gw.spr_name
	var cam: MapCamera = m.get("cam")
	if cam != null:
		core["cam"] = cam.position
		core["zoom"] = cam.zoom.x
	core["speed_i"] = int(m.get("_speed_i"))
	parts["core"] = (Time.get_ticks_usec() - tp) / 1000.0

	var sys: Dictionary = {}
	for n: String in _system_names(gw):
		tp = Time.get_ticks_usec()
		var o: Object = gw.get(n)
		if GENERIC.has(n):
			sys["$gen:" + n] = dump(o)
		if o.has_method("save_state"):
			sys[n] = enc(o.call("save_state"))
		parts[n] = (Time.get_ticks_usec() - tp) / 1000.0
	tp = Time.get_ticks_usec()

	var ents: Array = []
	var i: int = 0
	while i < _ents.size():
		var o2: Object = _ents[i]
		ents.append([String((o2.get_script() as Script).get_global_name()), _ent_fields(o2)])
		i += 1
	parts["ents"] = (Time.get_ticks_usec() - tp) / 1000.0
	last["snap_parts"] = parts
	var body: Dictionary = {"format": FORMAT, "core": core, "sys": sys, "ents": ents}
	var p: Country = gw.player
	var header: Dictionary = {"format": FORMAT, "version": String(ProjectSettings.get_setting("application/config/version", "")), 
		"country": p.name, "color": p.color, "game_time": gw.game_time, "elapsed": gw.session.elapsed(), "score": p.score, 
		"date": int(Time.get_unix_time_from_system()), "date_text": Time.get_datetime_string_from_system(false, true), 
		"size": gw.data.w, "bots": GameConfig.bots, "cities": p.city_ids.size()}

	_seq += 1
	header["slot"] = slot
	header["t_ms"] = int(Time.get_unix_time_from_system() * 1000.0)
	header["seq"] = _seq
	header["mid"] = _mid
	header["flag"] = p.flag_spec
	header["tier"] = gw.pstat.status_of(p) if gw.get("pstat") != null else -1
	header["place"] = gw.session.ranking().find(p) + 1
	header["n_countries"] = gw.countries.size()
	header["map_type"] = int(gw.settings.map_type) if gw.settings != null else 0
	header["size_i"] = GameConfig.size_i
	header["difficulty"] = GameConfig.difficulty
	header["cb_on"] = GameConfig.cb_on
	header["creative"] = GameConfig.creative
	if gw.session.ended:
		header["end"] = SaveSlots.END_WIN if gw.session.winner == p.id else SaveSlots.END_LOSS
	last["entities"] = ents.size()
	_ents = []
	_ent_ix = {}
	return [header, body]




static func _system_names(gw: GameWorld) -> Array:
	var out: Array = []
	for n: String in ORDER:
		var o: Variant = gw.get(n)
		if o is Object and is_instance_valid(o) and ((o as Object).has_method("save_state") or GENERIC.has(n)):
			out.append(n)
	for p: Dictionary in gw.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n2: String = p["name"]
		if out.has(n2):
			continue
		var o2: Variant = gw.get(n2)
		if o2 is Object and is_instance_valid(o2) and not (o2 is Node) and (o2 as Object).has_method("save_state") and (o2 as Object).has_method("load_state"):
			out.append(n2)
	return out




static func _md5(b: PackedByteArray) -> PackedByteArray:
	var h: = HashingContext.new()
	h.start(HashingContext.HASH_MD5)
	h.update(b)
	return h.finish()


static func _write_job(header: Dictionary, raw: PackedByteArray, thi: Dictionary = {}, fresh: bool = false) -> void :
	_write_ok = _write_raw(header, raw, "a0", SaveSlots.render_thumb(thi), fresh)


static func _write(header: Dictionary, body: Dictionary) -> bool:
	return _write_raw(header, var_to_bytes(body))





static func _write_raw(header: Dictionary, raw: PackedByteArray, key: String = "main", thumb: Image = null, fresh: bool = false) -> bool:
	if key == "main":
		fresh = fresh or _fresh
		_fresh = false
	var n: int = int(header.get("slot", slot))
	var t0: int = Time.get_ticks_usec()
	var comp: PackedByteArray = raw.compress(FileAccess.COMPRESSION_ZSTD)
	SaveSlots.migrate()
	SaveSlots._dir()
	var f: = FileAccess.open(SaveSlots.path(n, "tmp"), FileAccess.WRITE)
	if f == null:
		push_warning("[Save] cannot write %s (%d)" % [SaveSlots.path(n, "tmp"), FileAccess.get_open_error()])
		return false
	f.store_32(MAGIC)
	f.store_var(header)
	f.store_64(raw.size())
	f.store_buffer(_md5(comp))
	f.store_64(comp.size())
	f.store_buffer(comp)
	f.flush()
	var err: int = f.get_error()
	f.close()
	if err != OK:
		return false
	var da: = DirAccess.open(SaveSlots.DIR)
	if da == null:
		return false
	var meta: Dictionary = SaveSlots.before_write(n, key, header, fresh)
	var dst: String = SaveSlots.path(n, key).get_file()
	var tmpf: String = SaveSlots.path(n, "tmp").get_file()
	if key == "main" and da.file_exists(dst):
		var bakf: String = SaveSlots.path(n, "bak").get_file()
		if da.file_exists(bakf):
			da.remove(bakf)
		da.rename(dst, bakf)
	elif da.file_exists(dst):
		da.remove(dst)
	var ok: bool = da.rename(tmpf, dst) == OK
	if ok:
		var hm: Dictionary = header.duplicate()
		hm["bytes"] = comp.size()
		SaveSlots.after_write(n, key, hm, meta, thumb)
	last["file_kb"] = comp.size() / 1024
	last["raw_kb"] = raw.size() / 1024
	last["write_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	return ok


static func _wait() -> void :
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1



static func _open(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: = FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 16 or f.get_32() != MAGIC:
		return {}
	var h: Variant = f.get_var()
	if not (h is Dictionary) or int((h as Dictionary).get("format", 0)) > FORMAT:
		return {}
	var raw_n: int = f.get_64()
	var md5: PackedByteArray = f.get_buffer(16)
	var n: int = f.get_64()
	if n <= 0 or n > f.get_length() or raw_n <= 0 or raw_n > 1 << 30:
		return {}
	var comp: PackedByteArray = f.get_buffer(n)
	if comp.size() != n or _md5(comp) != md5:
		return {}
	return {"header": h, "raw_n": raw_n, "comp": comp}





static func _sound(body: Dictionary) -> bool:
	var core: Variant = body.get("core")
	if not (core is Dictionary) or not (body.get("ents") is Array):
		return false
	for k: String in ["countries", "cities", "bridges"]:
		var a: Variant = (core as Dictionary).get(k)
		if not (a is Array):
			return false
		for v: Variant in a:
			if v == null:
				push_warning("[Save] %s has a lost entity: snapshot skipped" % k)
				return false
	return true


static func _read(path: String) -> Dictionary:
	var r: Dictionary = _open(path)
	if r.is_empty():
		return {}
	var raw_n: int = r["raw_n"]
	var h: Dictionary = r["header"]
	var raw: PackedByteArray = (r["comp"] as PackedByteArray).decompress(raw_n, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_n:
		return {}
	var body: Variant = bytes_to_var(raw)
	if not (body is Dictionary) or not (body as Dictionary).has("core"):
		return {}
	return {"path": path, "header": h, "body": body}





static func save_prefs() -> void :
	var cf: = ConfigFile.new()
	if cf.load(prefs_path) != OK:
		cf = ConfigFile.new()
	for n: String in PREFS:
		cf.set_value("prefs", n, (GameConfig as GDScript).get(n))
	cf.set_value("prefs", "news_on", Hud.news_on)
	if cf.save(prefs_path) != OK:
		push_warning("Save: cannot write " + prefs_path)



static func seen_version() -> String:
	var cf: = ConfigFile.new()
	if cf.load(prefs_path) != OK:
		return ""
	return str(cf.get_value("prefs", "seen_version", ""))


static func set_seen_version(v: String) -> void :
	var cf: = ConfigFile.new()
	if cf.load(prefs_path) != OK:
		cf = ConfigFile.new()
	cf.set_value("prefs", "seen_version", v)
	if cf.save(prefs_path) != OK:
		push_warning("Save: cannot write " + prefs_path)



static func load_prefs() -> void :
	var cf: = ConfigFile.new()
	if cf.load(prefs_path) != OK:
		apply_display_resolution()
		apply_power_save()
		apply_ui_scale()
		Loc.boot()
		return
	for n: String in PREFS:
		if not cf.has_section_key("prefs", n):
			continue
		var cur: Variant = (GameConfig as GDScript).get(n)
		var v: Variant = cf.get_value("prefs", n)
		if typeof(v) == typeof(cur):
			(GameConfig as GDScript).set(n, v)
	GameConfig.fx_level = clampi(GameConfig.fx_level, 0, 2)
	GameConfig.performance_mode = clampi(GameConfig.performance_mode, 0, 4)
	GameConfig.notif_mode = clampi(GameConfig.notif_mode, 0, 2)
	GameConfig.tree_sway_mode = clampi(GameConfig.tree_sway_mode, 0, 2)
	GameConfig.object_lod = clampi(GameConfig.object_lod, 0, 2)
	GameConfig.strat_lod_z = clampi(GameConfig.strat_lod_z, 0, 3)
	GameConfig.dynamic_fps_target = clampi(GameConfig.dynamic_fps_target, 0, 3)
	apply_display_resolution()
	apply_power_save()
	apply_ui_scale()
	Loc.boot()
	if cf.has_section_key("prefs", "news_on"):
		Hud.news_on = bool(cf.get_value("prefs", "news_on", true))


static func available_display_resolutions(max_size: Vector2i = Vector2i.ZERO) -> Array[Vector2i]:
	var limit: Vector2i = max_size
	if limit.x <= 0 or limit.y <= 0:
		var screen: int = DisplayServer.window_get_current_screen()
		if screen < 0:
			screen = DisplayServer.SCREEN_PRIMARY
		limit = DisplayServer.screen_get_size(screen)
	if limit.x <= 0 or limit.y <= 0:
		limit = Vector2i(1280, 720)
	var result: Array[Vector2i] = []
	for resolution: Vector2i in DISPLAY_RESOLUTIONS:
		if resolution.x <= limit.x and resolution.y <= limit.y:
			result.append(resolution)
	if result.is_empty():
		result.append(Vector2i(mini(1280, limit.x), mini(720, limit.y)))
	return result


static func display_resolution_labels(resolutions: Array[Vector2i]) -> Array[String]:
	var result: Array[String] = []
	for resolution: Vector2i in resolutions:
		result.append("%d × %d" % [resolution.x, resolution.y])
	return result


static func display_resolution_index(resolutions: Array[Vector2i]) -> int:
	for i in resolutions.size():
		if resolutions[i] == Vector2i(GameConfig.resolution_w, GameConfig.resolution_h):
			return i
	return 0


static func apply_display_resolution() -> void:
	if GameConfig.android:
		return
	var resolutions: Array[Vector2i] = available_display_resolutions()
	if resolutions.is_empty():
		return
	var selected: Vector2i = resolutions[display_resolution_index(resolutions)]
	GameConfig.resolution_w = selected.x
	GameConfig.resolution_h = selected.y
	var screen: int = DisplayServer.window_get_current_screen()
	if screen < 0:
		screen = DisplayServer.SCREEN_PRIMARY
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
		DisplayServer.window_set_size(selected)
		if screen_size.x > 0 and screen_size.y > 0:
			var screen_pos: Vector2i = DisplayServer.screen_get_position(screen)
			var centered: Vector2i = screen_pos + Vector2i((screen_size.x - selected.x) / 2, (screen_size.y - selected.y) / 2)
			DisplayServer.window_set_position(centered)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	tree.root.content_scale_size = selected






static var fps_idle: bool = false
const IDLE_FPS: int = 30




static func apply_ui_scale() -> void :
	if GameConfig.ui_scale_auto:
		GameConfig.ui_scale_i = automatic_ui_scale_index()
	GameConfig.ui_scale_i = clampi(GameConfig.ui_scale_i, 0, GameConfig.UI_SCALES.size() - 1)
	var k: float = float(GameConfig.UI_SCALES[GameConfig.ui_scale_i])
	var st: SceneTree = Engine.get_main_loop() as SceneTree
	if st == null or st.root == null:
		return
	st.root.content_scale_factor = 1.0
	var screen: int = DisplayServer.window_get_current_screen()
	if screen < 0:
		screen = DisplayServer.SCREEN_PRIMARY
	var output_size: Vector2i = DisplayServer.screen_get_size(screen)
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		output_size = DisplayServer.window_get_size()
	if output_size.x > 1 and output_size.y > 1:
		k = minf(k, minf(float(output_size.x) / 360.0, float(output_size.y) / 640.0))
	k = maxf(k, 0.5)
	st.root.content_scale_factor = k
	MapCamera.set_ui_k(k, st.root.get_camera_2d())


static func automatic_ui_scale_index() -> int:
	var screen: int = DisplayServer.window_get_current_screen()
	if screen < 0:
		screen = DisplayServer.SCREEN_PRIMARY
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
	var target_scale: float = 1.0
	if screen_size.x >= 5120 and screen_size.y >= 2880:
		target_scale = 2.0
	elif screen_size.x >= 3840 and screen_size.y >= 2160:
		target_scale = 1.5
	elif screen_size.x >= 2560 and screen_size.y >= 1440:
		target_scale = 1.25
	var closest_index: int = 4
	var closest_delta: float = INF
	for i in GameConfig.UI_SCALES.size():
		var delta: float = absf(float(GameConfig.UI_SCALES[i]) - target_scale)
		if delta < closest_delta:
			closest_delta = delta
			closest_index = i
	return closest_index


static func apply_power_save() -> void :
	GameConfig.fps_i = clampi(GameConfig.fps_i, 0, GameConfig.FPS_CAPS.size() - 1)
	var cap: int = int(GameConfig.FPS_CAPS[GameConfig.fps_i])
	if GameConfig.power_save:
		cap = 30 if GameConfig.android else 45
	if fps_idle and GameConfig.pause_fps_limit and (cap == 0 or cap > IDLE_FPS):
		cap = IDLE_FPS
	Engine.max_fps = cap


static func _set_cfg(cfg: Dictionary) -> void :
	if not cfg.has("expand_i"):
		GameConfig.expand_i = 1
	if not cfg.has("ai_autodig"):
		GameConfig.ai_autodig = 0
	GameConfig.ai_autodig = clampi(GameConfig.ai_autodig, 0, 2)
	if not cfg.has("alliances"):
		GameConfig.alliances = true
	if not cfg.has("limit_i"):
		GameConfig.limit_i = GameConfig.TIMES.size() - 1
	if not cfg.has("reserves_i"):
		GameConfig.reserves_i = 0
	for n: String in cfg:
		if CFG.has(n):
			(GameConfig as GDScript).set(n, cfg[n])
	GameConfig.reserves_i = clampi(int(GameConfig.reserves_i), 0, GameConfig.RESERVE_NAMES.size() - 1)
	GameConfig.limit_i = clampi(int(GameConfig.limit_i), 0, GameConfig.TIMES.size() - 1)


static func _load_core(gw: GameWorld, body: Dictionary) -> void :
	var core: Dictionary = body["core"]
	var d: WorldData = gw.data

	d.dirty_cells.clear()
	if (core["biome"] as PackedByteArray).size() == d.biome.size():
		_biome_diff(d, d.biome, core["biome"])
		d.biome = core["biome"]
		d.flags = core["flags"]
		d.owners = core["owners"]
	d.owners_dirty = true

	var spr: PackedInt32Array = core["obj_spr"]
	var names: PackedStringArray = core.get("spr_name", gw.spr_name)
	if names != gw.spr_name:
		var remap: = PackedInt32Array()
		remap.resize(names.size())
		for i in names.size():
			remap[i] = int(gw.spr_index.get(names[i], 0))
		for i in spr.size():
			spr[i] = remap[spr[i]] if spr[i] < remap.size() else 0
	gw.obj_spr = spr
	gw.obj_x = core["obj_x"]
	gw.obj_y = core["obj_y"]
	gw.obj_state = core["obj_state"]
	gw.obj_kind = core["obj_kind"]
	gw.obj_hidden = core["obj_hidden"]
	gw.obj_hidden.resize(gw.obj_spr.size())
	gw._free_ids = core["free_ids"]
	gw.obj_fix = core.get("obj_fix", {})
	_rebuild_objects(gw)

	var ents: Array = body["ents"]
	_dec = []
	_dec.resize(ents.size())
	gw.countries.clear()
	gw.player = null
	for i in ents.size():
		var cn: String = ents[i][0]
		if cn == "Country":
			_dec[i] = gw.create_country(bool((ents[i][1] as Dictionary).get("is_player", false)), true)
		else:
			var sc: Script = _class_script(cn)
			_dec[i] = sc.new() if sc != null else null
	for i in ents.size():
		if _dec[i] != null:
			fill(_dec[i], ents[i][1])
	for i_meta in ents.size():
		var meta_obj: Object = _dec[i_meta]
		var ent_fields: Dictionary = ents[i_meta][1]
		if meta_obj != null and ent_fields.has("$meta"):
			var meta_data: Variant = dec(ent_fields["$meta"])
			if meta_data is Dictionary:
				for meta_key: Variant in meta_data:
					meta_obj.set_meta(StringName(meta_key), meta_data[meta_key])
	for i9 in ents.size():
		if _dec[i9] is Country and (_dec[i9] as Country).flag_spec != "":
			gw.apply_flag(_dec[i9] as Country, (_dec[i9] as Country).flag_spec, false)
	for i in ents.size():
		var o: Object = _dec[i]
		if o is Facility:
			(o as Facility).fx = []
		elif o is City:
			var fd: Dictionary = ents[i][1]
			(o as City).flag_node = null
			if fd.has("$flag"):
				var oc: Country = gw.country_by_id((o as City).country_id)
				if oc != null:
					(o as City).flag_node = gw.top.add_flag(oc.flag_frames, fd["$flag"])
	var cs: Array[Country] = []
	cs.assign(dec(core["countries"]))
	gw.countries = cs
	var ys: Array[City] = []
	ys.assign(dec(core["cities"]))
	gw.cities = ys
	var bs: Array[Bridge] = []
	bs.assign(dec(core["bridges"]))
	gw.bridges = bs
	gw.player = dec(core["player"])
	var r: Variant = dec(core["rng"])
	if r is Rng:
		gw.rng = r
	gw._update_territory_colors()
	gw.id_style = -1
	if gw.player != null and not gw.net_driven:
		var ns: int = GameWorld.COUNTRY_STYLES.size()
		for si in ns:
			if si != (gw.player.id - 1) % ns and String((GameWorld.COUNTRY_STYLES[si] as Dictionary).get("map", "")) == String(gw.player.style.get("map", "")):
				gw.id_style = si
	gw.bridge_cells.clear()
	for b: Bridge in gw.bridges:
		if b.kind != Bridge.Kind.RAIL:
			for c: Vector2i in b.cells:
				gw.bridge_cells[c.y * d.w + c.x] = b
	gw.road_paths = dec(core["road_paths"])
	for n: String in ["game_time", "_expand_t", "_ai_t", "_ruin_t", "_fire_snd_t", "_checkpoints_dirty", "show_own_icons"]:
		if core.has(n):
			gw.set(n, core[n])

	gw.checkpoints.clear()
	var flag_sid: int = int(gw.spr_index.get("flagpole", -1))
	var cps: Dictionary = core["checkpoints"]
	for key: String in cps:
		var cp: Dictionary = dec(cps[key])
		cp["flag"] = null
		var owner_id: int = int(key.get_slice(",", 2))
		var oc2: Country = gw.country_by_id(owner_id)
		for oid: int in (cp["objs"] as PackedInt32Array):
			if oid >= 0 and oid < gw.obj_spr.size() and gw.obj_spr[oid] == flag_sid and gw.obj_state[oid] != 2 and oc2 != null:
				var info: Dictionary = gw.atlas.info("flagpole")
				var a: Vector2 = gw.spr_anchor[flag_sid]
				var tip: = Vector2(gw.obj_x[oid] * GameWorld.CELL - a.x, (gw.obj_y[oid] + 1) * GameWorld.CELL - a.y) + Vector2(float(info["flag_x"]) + 1.0, float(info["flag_y"]) - 1.0)
				cp["flag"] = gw.top.add_flag(oc2.flag_frames, tip)
		if cp.has("cells"):
			var cc: Array[Vector2i] = []
			cc.assign(cp["cells"])
			cp["cells"] = cc
		gw.checkpoints[key] = cp
	gw.ruins = dec(core["ruins"])
	gw.ground.decals = dec(core["decals"])
	gw.fires = []
	for fv: Variant in core["fires"]:
		var fire: Dictionary = dec(fv)
		fire["h"] = []
		gw.fires.append(fire)
		var until: float = float(fire["until"])
		if until > gw.game_time:
			var p: Vector2 = fire["p"]
			for k in 2:
				gw._fire_fx(fire, "fire_small", p + Vector2((k - 0.5) * 5.0, 0.0), 3, until + k * 0.3)
			gw._fire_fx(fire, "smoke_black_loop", p + Vector2(0, -4), 5, until)
	gw._delayed.clear()
	for dl: Array in core.get("delayed", []):
		var args: Array = dec(dl[2])
		gw._delayed.append([float(dl[0]), Callable(gw, String(dl[1])).bindv(args)])





static func _biome_diff(d: WorldData, gen: PackedByteArray, saved: PackedByteArray) -> void :
	var w: int = d.w
	for y in d.h:
		var r0: int = y * w
		if gen.slice(r0, r0 + w) == saved.slice(r0, r0 + w):
			continue
		for x0 in range(0, w, 64):
			var a: int = r0 + x0
			var b: int = mini(a + 64, r0 + w)
			if gen.slice(a, b) == saved.slice(a, b):
				continue
			for i in range(a, b):
				if gen[i] != saved[i]:
					d.dirty_cells.append(Vector2i(i - r0, y))



static func _rebuild_objects(gw: GameWorld) -> void :
	for ck: ObjChunk in gw.objects.chunks:
		ck.ids = PackedInt32Array()
	gw.tree_at.clear()
	var w: int = gw.data.w
	var n: int = gw.obj_spr.size()
	var st: PackedByteArray = gw.obj_state
	var kd: PackedByteArray = gw.obj_kind
	var xs: PackedInt32Array = gw.obj_x
	var ys: PackedInt32Array = gw.obj_y
	var sp: PackedInt32Array = gw.obj_spr
	var fd: PackedInt32Array = gw.spr_fd
	var cc: int = gw.objects.chunk_cells
	var cw: int = gw.objects.cw
	var chn: int = gw.objects.ch
	var lists: Array = []
	lists.resize(gw.objects.chunks.size())
	for i in lists.size():
		lists[i] = []
	for id in n:
		if st[id] == 2:
			continue
		var x: int = xs[id]
		var y: int = ys[id]
		var k: int = clampi((y + fd[sp[id]] - 1) / cc, 0, chn - 1) * cw + clampi(x / cc, 0, cw - 1)
		(lists[k] as Array).append(id)
		if kd[id] == GameWorld.KIND_TREE:
			gw.tree_at[y * w + x] = id
	for i in lists.size():
		var ck2: ObjChunk = gw.objects.chunks[i]
		ck2.ids = PackedInt32Array(lists[i])
		ck2.mark()


static func _load_systems(gw: GameWorld, sys: Dictionary) -> void :
	for n: String in _system_names(gw):
		var o: Object = gw.get(n)
		if sys.has("$gen:" + n):
			fill(o, sys["$gen:" + n])
		if sys.has(n) and o.has_method("load_state"):
			var st: Variant = dec(sys[n])
			o.call("load_state", st if st is Dictionary else {})



static func _finish(gw: GameWorld, core: Dictionary) -> void :
	gw.data.owners_dirty = true
	gw._flush_territory()
	gw.ground.queue_redraw()
	gw.forts.queue_redraw()
	if gw.rail != null:
		gw.rail.layer_dirty()
	gw.map_mode = -1
	gw.set_map_mode(int(core.get("map_mode", 0)))
	for rj: Array in core.get("road_jobs", []):
		gw.road_async(dec(rj[0]), bool(rj[1]))
	_dec = []

	if gw.mil != null and gw.mil.air != null:
		gw.mil.air.after_load()

	var ag: Variant = load("res://game/army_groups.gd")
	if ag != null:
		ag.sanitize(gw)
	gw.changed.emit()
