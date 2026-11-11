extends RefCounted















const DIR: String = "user://saves/"
const N: int = 5
const STEP_S: float = 300.0
const FILES: Array = ["main", "a0", "a1", "a2", "bak"]
const LEGACY: Array = ["user://match.save", "user://match.save.tmp", "user://match.save.bak"]
const THUMB: int = 56
const END_NONE: int = 0
const END_WIN: int = 1
const END_LOSS: int = 2

static var _meta_c: Dictionary = {}
static var _gen: int = 0
static var _migrated: bool = false
static var last_migration: String = ""


static func path(n: int, key: String) -> String:
	match key:
		"main":
			return DIR + "slot_%d.save" % n
		"tmp":
			return DIR + "slot_%d.save.tmp" % n
		"bak":
			return DIR + "slot_%d.save.bak" % n
		"meta":
			return DIR + "slot_%d.meta" % n
		"png":
			return DIR + "slot_%d.png" % n
	return DIR + "slot_%d.%s.save" % [n, key]


static func _dir() -> DirAccess:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)
	return DirAccess.open(DIR)





static func peek(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var f: = FileAccess.open(p, FileAccess.READ)
	if f == null or f.get_length() < 16 or f.get_32() != Save.MAGIC:
		return {}
	var h: Variant = f.get_var()
	return h if h is Dictionary else {}


static func _sig(n: int) -> String:
	var s: String = ""
	for k: String in FILES + ["meta"]:
		var p: String = path(n, k)
		s += "%d," % (FileAccess.get_modified_time(p) if FileAccess.file_exists(p) else 0)
	return s + str(_gen)



static func meta(n: int) -> Dictionary:
	migrate()
	var sig: String = _sig(n)
	var c: Variant = _meta_c.get(n)
	if c is Array and String((c as Array)[0]) == sig:
		return (c as Array)[1]
	var m: Dictionary = {}
	var mp: String = path(n, "meta")
	if FileAccess.file_exists(mp):
		var f: = FileAccess.open(mp, FileAccess.READ)
		if f != null:
			var v: Variant = f.get_var()
			if v is Dictionary and (v as Dictionary).get("files") is Dictionary:
				m = v
	if m.is_empty():
		m = {"files": {}, "end": END_NONE, "bad": false}

	var mt: int = FileAccess.get_modified_time(mp) if FileAccess.file_exists(mp) else 0
	var files: Dictionary = m["files"]
	var fixed: bool = false
	for k: String in FILES:
		var p: String = path(n, k)
		if not FileAccess.file_exists(p):
			if files.has(k):
				files.erase(k)
				fixed = true
			continue
		if files.has(k) and FileAccess.get_modified_time(p) <= mt:
			continue
		var h: Dictionary = peek(p)
		if h.is_empty():
			if not files.has(k):
				files[k] = {"broken": true}
		else:
			files[k] = h
		fixed = true
	if fixed and files.is_empty():
		m["end"] = END_NONE
		m["bad"] = false
	_meta_c[n] = [sig, m]
	return m


static func _write_meta(n: int, m: Dictionary) -> void :
	var tmp: String = path(n, "meta") + ".tmp"
	var f: = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_var(m)
	f.close()
	var da: DirAccess = _dir()
	if da != null:
		da.rename(tmp.get_file(), path(n, "meta").get_file())
	_gen += 1




static func rows(n: int) -> Array:
	var files: Dictionary = meta(n)["files"]
	var out: Array = []
	for k: String in files:
		var h: Dictionary = files[k]
		if h.get("broken", false) or (k == "bak" and files.size() > 1):
			continue
		out.append({"key": k, "h": h})
	out.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return _order(a["h"]) > _order(b["h"]))
	var keep: Array = []
	for r: Dictionary in out:
		if not keep.is_empty() and absf(float((keep[keep.size() - 1] as Dictionary)["h"].get("game_time", 0.0)) - float(r["h"].get("game_time", 0.0))) < 1.0:
			continue
		keep.append(r)
	return keep



static func _order(h: Dictionary) -> float:
	return float(h.get("seq", 0)) * 10000000000.0 + float(h.get("date", 0))



static func info(n: int) -> Dictionary:
	var m: Dictionary = meta(n)
	var r: Array = rows(n)
	var st: String = "empty"
	var files: Dictionary = m["files"]
	if not files.is_empty():
		st = "bad" if r.is_empty() or bool(m.get("bad", false)) else ("ended" if int(m.get("end", 0)) != END_NONE else "ok")
	return {"n": n, "state": st, "head": (r[0] as Dictionary)["h"] if not r.is_empty() else {}, "rows": r, "end": int(m.get("end", 0))}


static func all() -> Array:
	var out: Array = []
	for n in range(1, N + 1):
		out.append(info(n))
	return out



static func continue_slot() -> int:
	var best: int = -1
	var bd: float = -1.0
	for n in range(1, N + 1):
		var i: Dictionary = info(n)
		if i["state"] != "ok":
			continue
		var d: float = stamp(i["head"])
		if d > bd:
			bd = d
			best = n
	return best



static func default_pick() -> int:
	var old: int = 1
	var od: float = INF
	for n in range(1, N + 1):
		var i: Dictionary = info(n)
		if i["state"] == "empty":
			return n
		var d: float = stamp(i["head"]) if i["state"] != "bad" else -1.0
		if d < od:
			od = d
			old = n
	return old


static func first_empty_slot() -> int:
	for n in range(1, N + 1):
		if info(n)["state"] == "empty":
			return n
	return -1



static func stamp(h: Dictionary) -> float:
	return float(h.get("t_ms", int(h.get("date", 0)) * 1000))


static func next_seq(n: int) -> int:
	var s: int = 0
	for k: String in (meta(n)["files"] as Dictionary):
		s = maxi(s, int((meta(n)["files"][k] as Dictionary).get("seq", 0)))
	return s + 1



static func load_order(n: int, first: String = "") -> Array:
	var files: Dictionary = meta(n)["files"]
	var ks: Array = files.keys()
	ks.sort_custom( func(a: String, b: String) -> bool:
		if a == "bak" or b == "bak":
			return b == "bak" and a != "bak"
		return _order(files[a]) > _order(files[b]))
	if first != "" and ks.has(first):
		ks.erase(first)
		ks.push_front(first)
	var out: Array = []
	for k: String in ks:
		out.append(path(n, k))
	out.append(path(n, "tmp"))
	return out


static func set_flag(n: int, key: String, v: Variant) -> void :
	Save._wait()
	var m: Dictionary = meta(n).duplicate(true)
	if m.get(key) == v:
		return
	m[key] = v
	_write_meta(n, m)
	_meta_c.erase(n)


static func delete(n: int) -> void :
	Save._wait()
	var da: DirAccess = _dir()
	if da == null:
		return
	for k: String in FILES + ["tmp", "meta", "png"]:
		var f: String = path(n, k).get_file()
		if da.file_exists(f):
			da.remove(f)
	if da.file_exists(path(n, "meta").get_file() + ".tmp"):
		da.remove(path(n, "meta").get_file() + ".tmp")
	_meta_c.erase(n)


static func export_file(n: int, destination: String) -> String:
	if n < 1 or n > N:
		return "Некорректный слот"
	Save._wait()
	var available: Array = rows(n)
	if available.is_empty():
		return "В слоте нет сохранения"
	var source: String = path(n, String((available[0] as Dictionary)["key"]))
	var input: FileAccess = FileAccess.open(source, FileAccess.READ)
	if input == null:
		return "Не удалось прочитать сохранение"
	var bytes: PackedByteArray = input.get_buffer(input.get_length())
	input.close()
	var output: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
	if output == null:
		return "Не удалось создать файл"
	output.store_buffer(bytes)
	output.close()
	return ""


static func import_file(source: String, n: int) -> String:
	if n < 1 or n > N:
		return "Некорректный слот"
	Save._wait()
	if info(n)["state"] != "empty":
		return "Импорт доступен только в пустой слот. Освободите слот и повторите попытку."
	var imported: Dictionary = Save._read(source)
	if imported.is_empty():
		return "Формат сохранения не поддерживается"
	var body: Variant = imported.get("body", {})
	if not (body is Dictionary) or not Save._sound(body as Dictionary):
		return "Сохранение повреждено или не поддерживается"
	var header: Dictionary = (imported["header"] as Dictionary).duplicate(true)
	var raw: PackedByteArray = var_to_bytes(body)
	var compressed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_ZSTD)
	header["slot"] = n
	header["seq"] = 1
	header["t_ms"] = int(Time.get_unix_time_from_system() * 1000.0)
	header["date"] = int(Time.get_unix_time_from_system())
	header["date_text"] = Time.get_datetime_string_from_system(false, true)
	header["bytes"] = compressed.size()
	Save._wait()
	var da: DirAccess = _dir()
	if da == null:
		return "Не удалось открыть папку сохранений"
	for key: String in FILES + ["tmp", "meta", "png"]:
		var leaf: String = path(n, key).get_file()
		if da.file_exists(leaf):
			da.remove(leaf)
	var output: FileAccess = FileAccess.open(path(n, "main"), FileAccess.WRITE)
	if output == null:
		return "Не удалось записать слот"
	output.store_32(Save.MAGIC)
	output.store_var(header)
	output.store_64(raw.size())
	output.store_buffer(Save._md5(compressed))
	output.store_64(compressed.size())
	output.store_buffer(compressed)
	output.close()
	_write_meta(n, {"files": {"main": header}, "end": int(header.get("end", END_NONE)), "bad": false})
	_meta_c.erase(n)
	return ""


static func thumb_tex(n: int) -> Texture2D:
	var p: String = path(n, "png")
	if not FileAccess.file_exists(p):
		return null
	var img: = Image.load_from_file(p)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)







static func before_write(n: int, key: String, header: Dictionary, fresh: bool) -> Dictionary:
	var da: DirAccess = _dir()
	var m: Dictionary = {"files": {}, "end": END_NONE, "bad": false}
	if fresh:
		for k: String in FILES + ["meta", "png"]:
			if da.file_exists(path(n, k).get_file()):
				da.remove(path(n, k).get_file())
		return m
	var mp: String = path(n, "meta")
	if FileAccess.file_exists(mp):
		var f: = FileAccess.open(mp, FileAccess.READ)
		if f != null:
			var v: Variant = f.get_var()
			if v is Dictionary and (v as Dictionary).get("files") is Dictionary:
				m = v
	var files: Dictionary = m["files"]
	if key == "a0" and files.has("a0") and da.file_exists(path(n, "a0").get_file()):
		var gap: float = float(header.get("game_time", 0.0)) - float((files["a0"] as Dictionary).get("game_time", 0.0))
		if gap >= STEP_S:
			if da.file_exists(path(n, "a2").get_file()):
				da.remove(path(n, "a2").get_file())
			files.erase("a2")
			if da.file_exists(path(n, "a1").get_file()):
				da.rename(path(n, "a1").get_file(), path(n, "a2").get_file())
				if files.has("a1"):
					files["a2"] = files["a1"]
			files.erase("a1")
			da.rename(path(n, "a0").get_file(), path(n, "a1").get_file())
			files["a1"] = files["a0"]
			files.erase("a0")
	if key == "main" and files.has("main"):
		files["bak"] = files["main"]
	return m




static func after_write(n: int, key: String, header: Dictionary, m: Dictionary, thumb: Image) -> void :
	(m["files"] as Dictionary)[key] = header
	m["end"] = int(header.get("end", END_NONE))
	m["bad"] = false
	_write_meta(n, m)
	if thumb != null and not thumb.is_empty():
		thumb.save_png(path(n, "png"))




static func thumb_input(gw: GameWorld) -> Dictionary:
	if gw == null or gw.data == null or gw.data.w <= 0:
		return {}
	var cols: Dictionary = {}
	for c: Country in gw.countries:
		cols[c.id] = c.color
	var cap: Vector2i = Vector2i(-1, -1)
	if gw.player != null:
		var ci: int = gw.player.capital_id
		if ci >= 0 and ci < gw.cities.size() and gw.cities[ci] != null:
			cap = gw.cities[ci].center
	return {"biome": gw.data.biome, "owners": gw.data.owners, "w": gw.data.w, "h": gw.data.h, "cols": cols, 
		"pid": gw.player.id if gw.player != null else -1, "cap": cap}




static func render_thumb(t: Dictionary) -> Image:
	if t.is_empty():
		return null
	var w: int = t["w"]
	var h: int = t["h"]
	var bio: PackedByteArray = t["biome"]
	var own: PackedByteArray = t["owners"]
	var cols: Dictionary = t["cols"]
	var pid: int = t["pid"]
	var n: int = THUMB
	var ow: = PackedInt32Array()
	ow.resize(n * n)
	var cls: = PackedByteArray()
	cls.resize(n * n)
	for py in n:
		for px in n:
			var cx: int = mini(w - 1, int((float(px) + 0.5) * float(w) / float(n)))
			var cy: int = mini(h - 1, int((float(py) + 0.5) * float(h) / float(n)))
			var i: int = cy * w + cx
			var o: int = py * n + px
			cls[o] = 0 if int(bio[i]) <= Biome.COAST else 1
			ow[o] = int(own[i]) if i < own.size() else 0
	var img: = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var sea: = Color("284e92")
	var foam: = Color("3b72b9")
	var land: = Color("7da739")
	for py in n:
		for px in n:
			var o: int = py * n + px
			var col: Color
			if cls[o] == 0:
				col = sea
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var qx: int = px + d.x
					var qy: int = py + d.y
					if qx >= 0 and qy >= 0 and qx < n and qy < n and cls[qy * n + qx] == 1:
						col = foam
						break
			else:
				var id: int = ow[o]
				col = land
				if id > 0 and cols.has(id):
					var cc: Color = cols[id]
					col = land.lerp(cc, 0.6)
					if id != pid:
						col = col.darkened(0.18)
					var edge: bool = false
					for d2: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var qx2: int = px + d2.x
						var qy2: int = py + d2.y
						if qx2 >= 0 and qy2 >= 0 and qx2 < n and qy2 < n and ow[qy2 * n + qx2] != id and (cls[qy2 * n + qx2] == 1 or id == pid):
							edge = true
							break
					if edge:
						col = Color("ffd75e") if id == pid else col.darkened(0.35)
			img.set_pixel(px, py, col)
	var cap: Vector2i = t["cap"]
	if cap.x >= 0:
		var c2: = Vector2i(int(float(cap.x) * float(n) / float(w)), int(float(cap.y) * float(n) / float(h)))
		for d3: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, 1), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, -1)]:
			var q: Vector2i = c2 + d3
			if q.x >= 0 and q.y >= 0 and q.x < n and q.y < n:
				img.set_pixelv(q, Color("1b120c"))
		for d4: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var q2: Vector2i = c2 + d4
			if q2.x >= 0 and q2.y >= 0 and q2.x < n and q2.y < n:
				img.set_pixelv(q2, Color("ffd75e"))
	return img







static func migrate() -> void :
	if _migrated:
		return
	_migrated = true
	var any: bool = false
	for p: String in LEGACY:
		any = any or FileAccess.file_exists(p)
	if not any:
		return
	var da: DirAccess = _dir()
	if da == null:
		last_migration = "no dir"
		return
	for n in range(1, N + 1):
		for k: String in FILES:
			if da.file_exists(path(n, k).get_file()):
				last_migration = "slots exist: legacy kept"
				return
	var src: String = ""
	var best: float = -1.0
	for p2: String in LEGACY:
		var r: Dictionary = Save._open(p2)
		if r.is_empty():
			continue
		var d: float = float((r["header"] as Dictionary).get("date", 0))
		if d > best:
			best = d
			src = p2
	if src == "":
		last_migration = "legacy unreadable: kept"
		return
	var b: PackedByteArray = FileAccess.get_file_as_bytes(src)
	var f: = FileAccess.open(path(1, "tmp"), FileAccess.WRITE)
	if f == null:
		last_migration = "cannot write"
		return
	f.store_buffer(b)
	f.close()
	if Save._open(path(1, "tmp")).is_empty():
		da.remove(path(1, "tmp").get_file())
		last_migration = "copy failed: legacy kept"
		return
	da.rename(path(1, "tmp").get_file(), path(1, "main").get_file())
	var h: Dictionary = peek(path(1, "main"))
	_write_meta(1, {"files": {"main": h}, "end": END_NONE, "bad": false})
	var ud: = DirAccess.open("user://")
	for p3: String in LEGACY:
		if ud != null and ud.file_exists(p3.get_file()):
			if ud.file_exists(p3.get_file() + ".pre332"):
				ud.remove(p3.get_file() + ".pre332")
			ud.rename(p3.get_file(), p3.get_file() + ".pre332")
	_meta_c.clear()
	last_migration = "migrated %s -> slot 1 (%d KB)" % [src.get_file(), b.size() / 1024]
	print("[Save] " + last_migration)
