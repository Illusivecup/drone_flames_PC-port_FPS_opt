class_name BorderPosts
extends RefCounted


























enum {CLOSED, SMALL, MID, BIG, OPEN}
const TIER_KEYS: Array = ["closed", "small", "mid", "big", "open", "mini", "minic"]
const MINI: int = 5
const MINIC: int = 6
const TIER_NAMES: Array = ["закрыт", "обычный", "расширенный", "многополосный", "открытый (безвиз + союз)"]
const TICK: float = 10.0
const EMA_T: float = 180.0
const MID_UP: float = 250.0
const MID_DOWN: float = 160.0
const BIG_UP: float = 900.0
const BIG_DOWN: float = 650.0
const DWELL: float = 90.0
const RUIN_FIX: float = 120.0
const SEARCH: int = 14
const MARGIN: int = 2
const MAX_BUILDS: int = 2
const NEAR: int = 4
const MAX_IN: int = 12

static var atlas: SpriteAtlas = null

var gw: GameWorld
var acc: Dictionary = {}
var vol: Dictionary = {}
var tier: Dictionary = {}
var since: Dictionary = {}
var _t: float = 0.0
var _mig: bool = false
var changes: int = 0
var rebuilt: int = 0
var last_us: int = 0


func _init(world: GameWorld) -> void :
	gw = world





static func register(w: GameWorld) -> void :
	var a: SpriteAtlas = SpriteAtlas.load_atlas("res://assets/sprites/atlas_kpp30.png", "res://assets/sprites/atlas_kpp30.json", true)
	if a.sprites.is_empty():
		atlas = null
		return
	atlas = a
	var first: int = w.spr_rect.size()
	w._add_sprites(a)
	w.spr_ruin.resize(w.spr_rect.size())
	for i in range(first, w.spr_rect.size()):
		w.spr_ruin[i] = int(w.spr_index.get(w.spr_name[i] + "_ruin", -1))


static func active() -> bool:
	return atlas != null



static func sprite_name(t: int, horiz: bool, style: int, alt: bool = false) -> String:
	return "kpp30_%s_%s_%s%s" % [TIER_KEYS[clampi(t, 0, TIER_KEYS.size() - 1)], "h" if horiz else "v", ArchStyle.KEYS[clampi(style, 0, 3)], "_b" if alt else ""]





func note_trade(a: int, b: int, money: int) -> void :
	if a == b or money <= 0:
		return
	var k: String = Diplomacy.key(a, b)
	acc[k] = int(acc.get(k, 0)) + money


func tier_of(a: int, b: int) -> int:
	return int(tier.get(Diplomacy.key(a, b), SMALL))


func volume(a: int, b: int) -> float:
	return float(vol.get(Diplomacy.key(a, b), 0.0))



func target(a: int, b: int, cur: int) -> int:
	var dp: Diplomacy = gw.diplo
	if dp == null:
		return SMALL
	if dp.at_war(a, b) or dp.embargo_between(a, b):
		return CLOSED
	if dp.allied(a, b) and dp.has_treaty(a, b, "visa"):
		return OPEN
	var v: float = volume(a, b)
	var base: int = cur if cur == MID or cur == BIG else SMALL
	match base:
		BIG:
			return BIG if v >= BIG_DOWN else (MID if v >= MID_DOWN else SMALL)
		MID:
			return BIG if v >= BIG_UP else (MID if v >= MID_DOWN else SMALL)
	return BIG if v >= BIG_UP else (MID if v >= MID_UP else SMALL)


func update(dt: float) -> void :
	_t += dt
	if _t < TICK:
		return
	_t -= TICK
	var al: float = TICK / EMA_T
	for k: String in acc:
		vol[k] = float(vol.get(k, 0.0))
	for k: String in vol.keys():
		var rate: float = float(acc.get(k, 0)) * 60.0 / TICK
		var nv: float = float(vol[k]) * (1.0 - al) + rate * al
		if nv < 0.5 and not acc.has(k):
			vol.erase(k)
		else:
			vol[k] = nv
	acc.clear()
	var dirty: bool = false
	var cs: Array = gw.countries
	for i in cs.size():
		var a: Country = cs[i]
		if a.eliminated:
			continue
		for j in range(i + 1, cs.size()):
			var b: Country = cs[j]
			if b.eliminated:
				continue
			var k: String = Diplomacy.key(a.id, b.id)
			var cur: int = int(tier.get(k, SMALL))
			var t: int = target(a.id, b.id, cur)
			if t == cur:
				continue
			var trade_step: bool = t >= SMALL and t <= BIG and cur >= SMALL and cur <= BIG
			if trade_step and gw.game_time - float(since.get(k, -1000000000.0)) < DWELL:
				continue
			if t == SMALL:
				tier.erase(k)
			else:
				tier[k] = t
			since[k] = gw.game_time
			changes += 1
			dirty = true
			_note(a, b, cur, t)

	for key: String in gw.checkpoints:
		var cp: Dictionary = gw.checkpoints[key]
		if not cp.has("want"):
			if not _mig:
				dirty = true
			continue
		var objs: PackedInt32Array = cp["objs"]
		if objs.is_empty() or objs[0] < 0 or objs[0] >= gw.obj_state.size():
			continue
		if gw.obj_state[objs[0]] == 1:
			if float(cp.get("ruin_t", -1.0)) < 0.0:
				cp["ruin_t"] = gw.game_time
				_show_flags(cp, false)
			elif gw.game_time - float(cp["ruin_t"]) > RUIN_FIX and int(cp.get("tier", SMALL)) != CLOSED:
				cp["want"] = -1
				dirty = true
	_mig = true
	if dirty:
		gw._checkpoints_dirty = true



func _note(a: Country, b: Country, from: int, to: int) -> void :
	if a == null or b == null or to == SMALL and from == CLOSED:
		return
	for pr: Array in [[a, b], [b, a]]:
		var o: Country = pr[1]
		var t: String = ""
		match to:
			OPEN:
				t = Loc.t("Граница со страной %s открыта: безвиз и союз — КПП стал открытым проездом с двумя флагами") % o.name
			BIG:
				t = Loc.t("Торговля со страной %s огромная — КПП расширен до многополосного") % o.name
			MID:
				if from == SMALL:
					t = Loc.t("Торговля со страной %s растёт — КПП расширен") % o.name
			CLOSED:
				t = Loc.t("КПП со страной %s закрыт") % o.name
		if t != "":
			gw.say(pr[0], t)





func update_posts() -> void :
	var us0: int = Time.get_ticks_usec()
	var want: Dictionary = {}
	var pairs: Array = []
	var ow: PackedByteArray = gw.data.owners
	var w: int = gw.data.w
	for path: Array in gw.road_paths:
		if path.is_empty():
			continue
		var q0: Vector2i = path[0]
		var oa: int = ow[q0.y * w + q0.x]
		for k in range(1, path.size()):
			var q: Vector2i = path[k]
			var ob: int = ow[q.y * w + q.x]
			if ob != oa and oa != 0 and ob != 0:
				var ka: String = _side(want, path, k - 1, -1, oa, ob)
				var kb: String = _side(want, path, k, 1, ob, oa)
				pairs.append([ka, kb, oa, ob])
			oa = ob

	for pr: Array in pairs:
		var oa2: int = int(pr[2])
		var ob2: int = int(pr[3])
		if tier_of(oa2, ob2) != OPEN:
			continue
		var ka2: String = pr[0]
		var kb2: String = pr[1]
		if ka2 == "" or kb2 == "":
			continue
		want.erase(kb2 if oa2 < ob2 else ka2)
	for key: String in gw.checkpoints.keys():
		if not want.has(key):
			remove(gw.checkpoints[key])
			gw.checkpoints.erase(key)


	var n: int = 0
	for key: String in want:
		var wv: Array = want[key]
		if gw.checkpoints.has(key):
			var cp: Dictionary = gw.checkpoints[key]
			if cp.has("want") and int(cp["want"]) == tier_of(int(wv[3]), int(wv[4])) and int(cp.get("pair", -1)) == int(wv[4])\
			and int(cp.get("style", -1)) == _style(int(wv[3])):
				continue
		if n >= MAX_BUILDS:
			gw._checkpoints_dirty = true
			break
		if gw.checkpoints.has(key):
			remove(gw.checkpoints[key])
			gw.checkpoints.erase(key)
		gw.checkpoints[key] = _build(wv[0], int(wv[1]), int(wv[2]), int(wv[3]), int(wv[4]))
		rebuilt += 1
		n += 1
	last_us = Time.get_ticks_usec() - us0




func _side(want: Dictionary, path: Array, j: int, inward: int, own: int, other: int) -> String:
	for n in MAX_IN:
		if j < 0 or j >= path.size():
			return ""
		var c: Vector2i = path[j]
		if gw.data.get_owner_id(c.x, c.y) != own:
			return ""
		if not gw.data.has_flag(c.x, c.y, WorldData.F_BRIDGE):
			var key: String = "%d,%d,%d" % [c.x, c.y, own]
			if want.has(key):
				return key
			for k2: String in want:
				var e: Array = want[k2]
				if int(e[3]) == own and int(e[4]) == other:
					var c2: Vector2i = (e[0] as Array)[int(e[1])]
					if absi(c2.x - c.x) <= NEAR and absi(c2.y - c.y) <= NEAR:
						return k2
			want[key] = [path, j, inward, own, other]
			return key
		j += inward
	return ""


func _style(cid: int) -> int:
	var c: Country = gw.country_by_id(cid)
	return clampi(c.arch, 0, 3) if c != null else 0




func _build(path: Array, j0: int, inward: int, own: int, other: int) -> Dictionary:
	var want_t: int = tier_of(own, other)
	var style: int = _style(own)


	var chain: Array = [[want_t, false, want_t]]
	var tail: Array = [[SMALL, false, SMALL], [SMALL, true, SMALL], [MINI, false, SMALL], [MINI, true, SMALL]]
	match want_t:
		BIG:
			chain = [[BIG, false, BIG], [MID, false, MID]] + tail
		MID:
			chain = [[MID, false, MID]] + tail
		SMALL:
			chain = tail
		CLOSED:
			chain = [[CLOSED, false, CLOSED], [CLOSED, true, CLOSED], [MINIC, false, CLOSED], [MINIC, true, CLOSED]]
	for ch: Array in chain:
		var sp: int = int(ch[0])
		var alt: bool = bool(ch[1])
		var t: int = int(ch[2])
		for mg: int in [MARGIN, 0]:
			for n in SEARCH + 1:
				var j: int = j0 + n * inward
				if j <= 0 or j >= path.size() - 1:
					break
				var c: Vector2i = path[j]
				if gw.data.get_owner_id(c.x, c.y) != own:
					break
				var fit: Dictionary = _fit(path, j, sp, style, own, mg, alt)
				if not fit.is_empty():
					return _place(fit, t, own, other, want_t, style)

	var c0: Vector2i = path[j0]
	if want_t == OPEN:
		return _open_poles(c0, own, other, style)
	var outj: int = j0 - inward
	var outward: Vector2i = (path[outj] as Vector2i) - c0 if outj >= 0 and outj < path.size() else Vector2i(1, 0)
	var cp: Dictionary = gw._create_checkpoint(c0, own, outward)
	cp["want"] = want_t
	cp["tier"] = -1
	cp["pair"] = other
	cp["style"] = style
	return cp



func _open_poles(c0: Vector2i, own: int, other: int, style: int) -> Dictionary:
	var objs: = PackedInt32Array()
	var occ: Array[Vector2i] = []
	var names: Array = ["kpp30_pole_own", "kpp30_pole_nb"]
	for r in range(1, 4):
		for q: Vector2i in [c0 + Vector2i(r, - r), c0 + Vector2i( - r, - r), c0 + Vector2i(r, r), c0 + Vector2i( - r, r), c0 + Vector2i(0, - r), c0 + Vector2i( - r, 0)]:
			if objs.size() >= 2:
				break
			if not gw.data.inside(q.x, q.y) or gw.data.get_owner_id(q.x, q.y) != own or not gw._cell_free_for_prop(q, true):
				continue
			if not gw.spr_index.has(String(names[objs.size()])):
				break
			gw.remove_tree_at(q)
			gw.data.add_flag(q.x, q.y, WorldData.F_OCCUPIED)
			occ.append(q)
			objs.append(gw.add_object(String(names[objs.size()]), q, GameWorld.KIND_PROP))
	var cp: Dictionary = {"objs": objs, "flag": null, "cell": c0, "cells": occ, "want": OPEN, "tier": -2, "pair": other, "style": style}
	_render_extras(cp, own)
	return cp



func _fit(path: Array, j: int, t: int, style: int, own: int, margin: int = 0, alt: bool = false) -> Dictionary:
	var c: Vector2i = path[j]
	var dn: Vector2i = (path[j + 1] as Vector2i) - c
	var dp: Vector2i = c - (path[j - 1] as Vector2i)
	var horiz: bool = dn.x != 0
	var nm: String = sprite_name(t, horiz, style, alt)
	if not atlas.has(nm) or not gw.spr_index.has(nm):
		return {}
	var e: Dictionary = atlas.info(nm)
	if dn != dp and int(e["fw"] if horiz else e["fd"]) > 1:
		return {}
	var rc: = Vector2i(int(e["rc"][0]), int(e["rc"][1]))
	var fw: int = int(e["fw"])
	var fd: int = int(e["fd"])
	var nw: Vector2i = c - rc
	var d: WorldData = gw.data
	var ok_rows: = PackedInt32Array()
	for r: Variant in e.get("road_ok", []):
		ok_rows.append(int(r))
	var rail_rows: = PackedInt32Array()
	for r: Variant in e.get("rail_ok", []):
		rail_rows.append(int(r))
	var rl: Rail = gw.rail
	var free: Array[Vector2i] = []
	for y in range(nw.y, nw.y + fd):
		for x in range(nw.x, nw.x + fw):
			if not d.inside(x, y) or d.get_owner_id(x, y) != own or Biome.is_water(d.get_biome(x, y)):
				return {}
			var q: = Vector2i(x, y)
			if rl != null and rl.has_rail(q):
				if not rail_rows.has((y - nw.y) if horiz else (x - nw.x)):
					return {}
				continue
			var on_road: bool = (y == c.y) if horiz else (x == c.x)
			if on_road:

				var o: int = (x - c.x) if horiz else (y - c.y)
				var sgn: int = (dn.x if horiz else dn.y)
				var jj: int = j + o * sgn
				if jj < 0 or jj >= path.size() or (path[jj] as Vector2i) != q or d.has_flag(x, y, WorldData.F_BRIDGE | WorldData.F_OCCUPIED):
					return {}
			else:
				if d.has_flag(x, y, WorldData.F_OCCUPIED | WorldData.F_BRIDGE):
					return {}
				if d.has_flag(x, y, WorldData.F_ROAD):

					if not ok_rows.has((y - nw.y) if horiz else (x - nw.x)):
						return {}
					continue
				free.append(q)
	if margin > 0:
		var ow: PackedByteArray = d.owners
		for y in range(nw.y - margin, nw.y + fd + margin):
			for x in range(nw.x - margin, nw.x + fw + margin):
				if not d.inside(x, y) or ow[y * d.w + x] != own:
					return {}
	return {"name": nm, "nw": nw, "cell": c, "free": free}


func _place(fit: Dictionary, t: int, own: int, other: int, want_t: int, style: int) -> Dictionary:
	var objs: = PackedInt32Array()
	var occ: Array[Vector2i] = []
	for q: Vector2i in fit["free"]:
		gw.remove_tree_at(q)
		gw.data.add_flag(q.x, q.y, WorldData.F_OCCUPIED)
		occ.append(q)
	var id: int = gw.add_object(String(fit["name"]), fit["nw"], GameWorld.KIND_BUILDING)
	objs.append(id)
	var cp: Dictionary = {"objs": objs, "flag": null, "cell": fit["cell"], "cells": occ, "want": want_t, "tier": t, 
		"pair": other, "style": style}
	_render_extras(cp, own)
	if gw.fx != null and id >= 0:
		gw.fx.spawn("build_spark", Vector2(fit["cell"] * GameWorld.CELL) + Vector2(2, -2), 6)
	return cp



func remove(cp: Dictionary) -> void :
	for n: Variant in cp.get("flags", []):
		if n is Node and is_instance_valid(n) and n != cp.get("flag"):
			(n as Node).queue_free()
	gw._remove_checkpoint(cp)





func _render_extras(cp: Dictionary, own: int) -> void :
	var objs: PackedInt32Array = cp["objs"]
	if objs.is_empty() or gw.top == null or atlas == null:
		return
	var flags: Array = []
	var lt: Array = []
	var mine: bool = false
	for id in objs:
		if id < 0 or id >= gw.obj_spr.size() or gw.obj_state[id] == 2:
			continue
		var nm: String = gw.spr_name[gw.obj_spr[id]]
		if not atlas.has(nm):
			continue
		mine = true
		var e: Dictionary = atlas.info(nm)
		var o: Vector2 = gw.obj_origin(id)
		for pl: Array in e.get("poles", []):
			var cid: int = own if int(pl[2]) == 0 else int(cp.get("pair", own))
			var c: Country = gw.country_by_id(cid)
			if c == null:
				continue
			var tip: Vector2 = o + Vector2(float(pl[0]) + 1.0, float(pl[1]) - 1.0)
			flags.append(gw.top.add_flag(c.flag_frames, tip))
		for l: Array in e.get("lights", []):
			lt.append([o + Vector2(float(l[0]) + 0.5, float(l[1]) + 0.5), int(l[2])])
	if not mine:
		return
	cp["flags"] = flags
	cp["flag"] = flags[0] if not flags.is_empty() else null
	cp["lights"] = lt
	if gw.obj_state[objs[0]] == 1:
		_show_flags(cp, false)


func _show_flags(cp: Dictionary, on: bool) -> void :
	for n: Variant in cp.get("flags", []):
		if n is CanvasItem and is_instance_valid(n):
			(n as CanvasItem).visible = on



func draw_lights(nl: Node2D, cv: CanvasItem, view: Rect2, a: float) -> void :
	for key: String in gw.checkpoints:
		var cp: Dictionary = gw.checkpoints[key]
		if not cp.has("lights"):
			continue
		var objs: PackedInt32Array = cp["objs"]
		if objs.is_empty():
			continue
		var id: int = objs[0]
		if id < 0 or gw.obj_state[id] != 0 or (id < gw.obj_hidden.size() and gw.obj_hidden[id] != 0):
			continue
		var c: Vector2i = cp["cell"]
		if not view.grow(24.0).has_point(Vector2(c * GameWorld.CELL)):
			continue
		for l: Array in cp["lights"]:
			var p: Vector2 = l[0]
			match int(l[1]):
				0:
					nl.call("_soft", p + Vector2(0, 3), 5.0, Color(1.0, 0.92, 0.7, a * 0.3))
					cv.draw_rect(Rect2(p - Vector2(0.5, 0.5), Vector2(1, 1)), Color(1.0, 0.97, 0.85, a * 0.8))
				1:
					cv.draw_rect(Rect2(p - Vector2(1, 0.5), Vector2(2, 1)), Color(1.0, 0.82, 0.42, a))
				2:
					var on: bool = int(gw.game_time * 2.0) % 2 == 0
					nl.call("_soft", p, 5.0, Color(1.0, 0.15, 0.08, a * (0.6 if on else 0.25)))
					cv.draw_rect(Rect2(p - Vector2(0.5, 0.5), Vector2(1, 1)), Color(1.0, 0.25, 0.15, a))
				3:
					nl.call("_soft", p, 4.0, Color(0.55, 0.75, 1.0, a * 0.45))
				4:
					nl.call("_soft", p + Vector2(0, 4), 9.0, Color(1.0, 0.95, 0.8, a * 0.3))
					cv.draw_rect(Rect2(p - Vector2(0.5, 0.5), Vector2(1, 1)), Color(1.0, 1.0, 0.9, a))




func save_state() -> Dictionary:
	var cps: Dictionary = {}
	for key: String in gw.checkpoints:
		var cp: Dictionary = gw.checkpoints[key]
		if cp.has("want"):
			cps[key] = [int(cp["want"]), int(cp.get("tier", -1)), int(cp.get("pair", -1)), int(cp.get("style", 0)), float(cp.get("ruin_t", -1.0))]
	return {"acc": acc, "vol": vol, "tier": tier, "since": since, "t": _t, "mig": _mig, "cps": cps, "n": changes}



func load_state(d: Dictionary) -> void :
	acc = _dict(d.get("acc"))
	vol = _dict(d.get("vol"))
	tier = _dict(d.get("tier"))
	since = _dict(d.get("since"))
	_t = clampf(float(d.get("t", 0.0)), 0.0, TICK)
	_mig = bool(d.get("mig", false))
	changes = int(d.get("n", 0))
	for k: String in tier.keys():
		var tv: int = int(tier[k])
		if tv < CLOSED or tv > OPEN or tv == SMALL:
			tier.erase(k)
	var cps: Dictionary = _dict(d.get("cps"))
	for key: String in cps:
		if not gw.checkpoints.has(key) or not (cps[key] is Array) or (cps[key] as Array).size() < 5:
			continue
		var v: Array = cps[key]
		var cp: Dictionary = gw.checkpoints[key]
		cp["want"] = int(v[0])
		cp["tier"] = int(v[1])
		cp["pair"] = int(v[2])
		cp["style"] = int(v[3])
		cp["ruin_t"] = float(v[4])
		if atlas != null:
			_render_extras(cp, int(key.get_slice(",", 2)))


static func _dict(v: Variant) -> Dictionary:
	return (v as Dictionary).duplicate() if v is Dictionary else {}



func posts() -> Array:
	var out: Array = []
	for key: String in gw.checkpoints:
		var cp: Dictionary = gw.checkpoints[key]
		var objs: PackedInt32Array = cp["objs"]
		var nm: String = gw.spr_name[gw.obj_spr[objs[0]]] if not objs.is_empty() and objs[0] >= 0 else ""
		out.append([int(cp.get("tier", -9)), nm, int(cp.get("pair", -1)), key])
	return out
