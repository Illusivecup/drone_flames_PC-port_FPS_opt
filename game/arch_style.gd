class_name ArchStyle
extends RefCounted






















const KEYS: Array = ["east", "usa", "west", "asia"]
const NAMES: Array = ["ВОСТОЧНАЯ ЕВРОПА", "АМЕРИКАНСКИЙ", "ЗАПАДНАЯ ЕВРОПА", "АЗИАТСКИЙ"]
const HINTS: Array = ["Панельки, хрущёвки, сталинки — как сейчас", "Пригород с гаражами, кирпич, водонапорные баки, дайнеры", 
	"Черепица, фахверк, шпили церквей, стеклянные башни", "Карнизы с загибом, вывески, пагода, тонкие башни"]

const STYLED: Array = ["house_a", "house_b", "house_c", "house_d", "khrushchevka_h", "khrushchevka_v", "panel9_h", "panel9_v", 
	"tower16", "stalinka_h", "stalinka_v", "admin", "school", "factory", "warehouse", "garages_h", "garages_v", "kiosk", 
	"highrise_panel", "highrise_brick", "glass_tower_a", "glass_tower_b", "business_center", "tv_tower", "rail_station"]

const CLAD: Dictionary = {"house_a": true, "house_b": true, "house_c": true, "house_d": true, "khrushchevka_h": true, 
	"khrushchevka_v": true, "panel9_h": true, "panel9_v": true, "tower16": true, "stalinka_h": true, "stalinka_v": true, 
	"school": true, "factory": true, "warehouse": true, "garages_h": true, "garages_v": true, "kiosk": true, "rail_station": true}

const SWAP: Dictionary = {"house_a": true, "house_b": true, "house_c": true, "house_d": true, "kiosk": true, 
	"garages_h": true, "garages_v": true, "rail_station": true}
const TICK: float = 2.0
const STEP: int = 2
const CLAD_MAX: int = 870
const SWAP_MAX: int = 460
const SCANS: int = 2
const MAX_PER_SCAN: int = 6

static var atl: Array = [null, null, null, null]
static var info_sid: Dictionary = {}

var gw: GameWorld
var city_st: Dictionary = {}
var _t: float = 0.0
var _rr: int = 0
var changes: int = 0


func _init(world: GameWorld) -> void :
	gw = world






static func register(w: GameWorld) -> void :
	w.arch_tab = []
	info_sid.clear()
	var srcs: Array = []
	for k in range(1, 4):
		var a: SpriteAtlas = SpriteAtlas.load_atlas("res://assets/sprites/atlas_style_%s.png" % KEYS[k], "res://assets/sprites/atlas_style_%s.json" % KEYS[k], true)
		atl[k] = a
		if not a.sprites.is_empty():
			srcs.append([String(KEYS[k]) + ":", a])
	var cl: SpriteAtlas = SpriteAtlas.load_atlas("res://assets/sprites/atlas_style_clad.png", "res://assets/sprites/atlas_style_clad.json", true)
	if not cl.sprites.is_empty():
		srcs.append(["clad:", cl])
	if srcs.is_empty():
		return
	var old_tex: Texture2D = w.atlas.texture
	var wimg: Image = old_tex.get_image() if old_tex != null and not (old_tex is PlaceholderTexture2D) else null
	var offs: Array = []
	var mtex: Texture2D = null
	if wimg != null and not wimg.is_empty():
		if wimg.is_compressed():
			wimg.decompress()
		wimg.convert(Image.FORMAT_RGBA8)
		var imgs: Array = []
		var mw: int = wimg.get_width()
		var mh: int = wimg.get_height() + 1
		for s: Array in srcs:
			var tx: Texture2D = (s[1] as SpriteAtlas).texture
			var im: Image = tx.get_image() if tx != null and not (tx is PlaceholderTexture2D) else null
			if im == null or im.is_empty():
				imgs.append(null)
				offs.append(-1)
				continue
			if im.is_compressed():
				im.decompress()
			im.convert(Image.FORMAT_RGBA8)
			imgs.append(im)
			offs.append(mh)
			mw = maxi(mw, im.get_width())
			mh += im.get_height() + 1
		if mh <= 8192:
			var merged: = Image.create(mw, mh, false, Image.FORMAT_RGBA8)
			merged.blit_rect(wimg, Rect2i(Vector2i.ZERO, wimg.get_size()), Vector2i.ZERO)
			for i in imgs.size():
				if imgs[i] != null:
					var im2: Image = imgs[i]
					merged.blit_rect(im2, Rect2i(Vector2i.ZERO, im2.get_size()), Vector2i(0, int(offs[i])))
			mtex = ImageTexture.create_from_image(merged)
			for i in w.spr_tex.size():
				if w.spr_tex[i] == old_tex:
					w.spr_tex[i] = mtex
			w.atlas.texture = mtex
	var first: int = w.spr_rect.size()
	for i in srcs.size():
		var a2: SpriteAtlas = srcs[i][1]
		var sub: = SpriteAtlas.new()
		var oy: int = 0
		if mtex != null and int(offs[i]) >= 0:
			sub.texture = mtex
			oy = int(offs[i])
		else:
			sub.texture = a2.texture
		for n: String in a2.sprites:
			var e: Dictionary = a2.sprites[n]
			if String(e.get("kind", "")).begins_with("unit"):
				continue
			var e2: Dictionary = e.duplicate()
			e2["y"] = float(e["y"]) + float(oy)
			sub.sprites[String(srcs[i][0]) + n] = e2
		w._add_sprites(sub)
		for n2: String in sub.sprites:
			info_sid[int(w.spr_index[n2])] = sub.sprites[n2]
	w.spr_ruin.resize(w.spr_rect.size())
	for i in range(first, w.spr_rect.size()):
		var nm: String = w.spr_name[i]
		var rn: int = int(w.spr_index.get(nm + "_ruin", -1))
		if rn < 0 and nm.begins_with("clad:"):
			var base: String = nm.get_slice(">", 0).trim_prefix("clad:")
			var bn: String = nm.get_slice("/", 1)
			rn = int(w.spr_index.get((bn if base == "east" else base + ":" + bn) + "_ruin", -1))
		w.spr_ruin[i] = rn

	var n_spr: int = w.spr_rect.size()
	var ident: = PackedInt32Array()
	ident.resize(n_spr)
	for i in n_spr:
		ident[i] = i
	for look in 64:
		var tb: PackedInt32Array = ident.duplicate()
		var b: int = look & 3
		var t: int = (look >> 2) & 3
		var stg: int = mini((look >> 4) & 3, 2)
		for nm: String in STYLED:
			if not w.spr_index.has(nm):
				continue
			var sid: int = int(w.spr_index[nm])
			var own: int = _sid_of(w, b, nm, sid)
			match stg:
				0:
					tb[sid] = own
				1:
					tb[sid] = int(w.spr_index.get("clad:%s>%s/%s" % [KEYS[b], KEYS[t], nm], own)) if t != b else own
				2:
					tb[sid] = _sid_of(w, t, nm, own)
		w.arch_tab.append(tb)
	print("[ArchStyle] %d style sprites, merged: %s" % [n_spr - first, mtex != null])


static func _sid_of(w: GameWorld, style: int, nm: String, fallback: int) -> int:
	if style == 0:
		return int(w.spr_index.get(nm, fallback))
	return int(w.spr_index.get(String(KEYS[style]) + ":" + nm, fallback))



static func draw_sid(w: GameWorld, id: int) -> int:
	var s: int = w.obj_spr[id]
	if id < w.obj_arch.size() and w.obj_arch[id] != 0 and w.obj_arch[id] < w.arch_tab.size():
		var tb: PackedInt32Array = w.arch_tab[w.obj_arch[id]]
		if s < tb.size():
			s = tb[s]
	return s



static func draw_origin(w: GameWorld, id: int) -> Vector2:
	var s: int = draw_sid(w, id)
	var a: Vector2 = w.spr_anchor[s]
	return Vector2(w.obj_x[id] * GameWorld.CELL - a.x, (w.obj_y[id] + w.spr_fd[s]) * GameWorld.CELL - a.y)



static func info_of(sid: int, fallback: Dictionary) -> Dictionary:
	return info_sid.get(sid, fallback)



static func train_atlas(w: GameWorld, country_id: int) -> SpriteAtlas:
	var c: Country = w.country_by_id(country_id)
	if c == null or c.arch <= 0 or c.arch > 3:
		return null
	var a: SpriteAtlas = atl[c.arch]
	return a if a != null and a.has("rail_loco") else null






static func seeded(w: GameWorld, cid: int) -> int:
	var sd: int = w.data.world_seed if w.data != null else 0
	return (Hash32.mix(sd + 2929) + cid) % 4



static func native_of(w: GameWorld, ids: Array) -> int:
	for v: Variant in ids:
		var cid: int = int(v)
		if cid >= 0 and cid < w.cities.size():
			var f: Country = w.country_by_id(w.cities[cid].founder_id)
			if f != null:
				return clampi(f.arch, 0, 3)
	return 0



static func mark(w: GameWorld, id: int, country_id: int) -> void :
	if id < 0:
		return
	if w.obj_arch.size() < w.obj_spr.size():
		w.obj_arch.resize(w.obj_spr.size())
	var c: Country = w.country_by_id(country_id)
	w.obj_arch[id] = clampi(c.arch, 0, 3) if c != null else 0




func update(dt: float) -> void :
	_t += dt
	if _t < TICK:
		return
	_t -= TICK
	var active: Array = []
	for city: City in gw.cities:
		var own: Country = gw.country_by_id(city.country_id)
		if own == null:
			continue
		var tgt: int = clampi(own.arch, 0, 3)
		var e: Array = city_st.get(city.id, [])
		if e.is_empty():
			city_st[city.id] = [tgt, 1000, true]
			continue
		if int(e[0]) != tgt:
			e[0] = tgt
			e[1] = 0
			e[2] = false
		if bool(e[2]):
			continue
		e[1] = mini(1000, int(e[1]) + STEP)
		active.append(city)
	if active.is_empty():
		return
	for k in mini(SCANS, active.size()):
		_rr = (_rr + 1) % active.size()
		var city2: City = active[_rr]
		var e2: Array = city_st[city2.id]
		var n: int = _scan(city2, int(e2[0]), int(e2[1]))
		if int(e2[1]) >= 1000 and n == 0:
			e2[2] = true



static func desired(b: int, t: int, p: int, x: int, y: int, swap: bool) -> int:
	if b == t:
		return b
	var h: int = Hash32.h2(x, y, 2929)
	var u1: int = h & 1023
	var u2: int = (h >> 10) & 1023
	var stg: int = 0
	if swap and u2 < SWAP_MAX and p >= 450 + u2 * 500 / SWAP_MAX:
		stg = 2
	elif u1 < CLAD_MAX and p >= 100 + u1 * 600 / CLAD_MAX:
		stg = 1
	if stg == 0:
		return b
	return b | (t << 2) | (stg << 4)



static func turn(x: int, y: int) -> int:
	return 100 + (Hash32.h2(x, y, 2929) & 1023) * 600 / 1024


func _scan(city: City, tgt: int, p: int) -> int:
	var r: int = city.radius + 2
	var box: = Rect2i(city.center - Vector2i(r, r), Vector2i(2 * r + 1, 2 * r + 1))
	var n: int = 0
	if gw.obj_arch.size() < gw.obj_spr.size():
		gw.obj_arch.resize(gw.obj_spr.size())
	for ck: ObjChunk in gw.objects.chunks_in_rect(box):
		for id in ck.ids:
			if gw.obj_state[id] != 0 or gw.obj_kind[id] != GameWorld.KIND_BUILDING:
				continue
			var x: int = gw.obj_x[id]
			var y: int = gw.obj_y[id]
			if not box.has_point(Vector2i(x, y)) or gw.data.get_owner_id(x, y) != city.country_id:
				continue
			var nm: String = gw.spr_name[gw.obj_spr[id]]
			if not CLAD.has(nm):
				continue
			var cur: int = gw.obj_arch[id]
			var want: int = desired(cur & 3, tgt, p, x, y, SWAP.has(nm))
			if want == cur or p < turn(x, y):
				continue
			gw.obj_arch[id] = want
			ck.mark()
			changes += 1
			n += 1
			if gw.fx != null:
				gw.fx.spawn("build_spark", draw_origin(gw, id) + Vector2(4, 6), 6)
			if n >= MAX_PER_SCAN:
				return n
	return n



func city_stats(city: City) -> Dictionary:
	var out: Dictionary = {"own": 0, "clad": 0, "rebuilt": 0, "progress": int((city_st.get(city.id, [0, 0, true]) as Array)[1])}
	var r: int = city.radius + 2
	var box: = Rect2i(city.center - Vector2i(r, r), Vector2i(2 * r + 1, 2 * r + 1))
	for ck: ObjChunk in gw.objects.chunks_in_rect(box):
		for id in ck.ids:
			if gw.obj_state[id] == 2 or gw.obj_kind[id] != GameWorld.KIND_BUILDING or not box.has_point(Vector2i(gw.obj_x[id], gw.obj_y[id])):
				continue
			if not CLAD.has(gw.spr_name[gw.obj_spr[id]]):
				continue
			var lk: int = gw.obj_arch[id] if id < gw.obj_arch.size() else 0
			var st: int = (lk >> 4) & 3
			out["own" if st == 0 else ("clad" if st == 1 else "rebuilt")] += 1
	return out




func save_state() -> Dictionary:
	var ids: = PackedInt32Array()
	var tg: = PackedInt32Array()
	var pg: = PackedInt32Array()
	var dn: = PackedInt32Array()
	for cid: int in city_st:
		var e: Array = city_st[cid]
		ids.append(cid)
		tg.append(int(e[0]))
		pg.append(int(e[1]))
		dn.append(1 if bool(e[2]) else 0)
	return {"obj": gw.obj_arch, "ids": ids, "tg": tg, "pg": pg, "dn": dn, "t": _t, "rr": _rr}


func load_state(d: Dictionary) -> void :
	var o: Variant = d.get("obj", null)
	gw.obj_arch = o if o is PackedByteArray else PackedByteArray()
	gw.obj_arch.resize(gw.obj_spr.size())
	for i in gw.obj_arch.size():
		if gw.obj_arch[i] >= 48:
			gw.obj_arch[i] = gw.obj_arch[i] & 3
	city_st.clear()
	var ids: PackedInt32Array = d.get("ids", PackedInt32Array())
	var tg: PackedInt32Array = d.get("tg", PackedInt32Array())
	var pg: PackedInt32Array = d.get("pg", PackedInt32Array())
	var dn: PackedInt32Array = d.get("dn", PackedInt32Array())
	for i in mini(ids.size(), mini(tg.size(), mini(pg.size(), dn.size()))):
		city_st[ids[i]] = [clampi(tg[i], 0, 3), clampi(pg[i], 0, 1000), dn[i] != 0]
	_t = float(d.get("t", 0.0))
	_rr = int(d.get("rr", 0))
	for ck: ObjChunk in gw.objects.chunks:
		ck.mark()
