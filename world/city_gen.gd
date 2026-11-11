class_name CityGen
extends RefCounted




const PANEL_LAYOUTS: Array = [
	[["panel9_h", 1, 0], ["khrushchevka_h", 0, 4], ["khrushchevka_h", 0, 7], ["khrushchevka_v", 8, 4]], 
	[["panel9_v", 0, 1], ["panel9_v", 7, 1], ["khrushchevka_v", 4, 1], ["garages_h", 3, 9]], 
	[["khrushchevka_h", 0, 0], ["khrushchevka_h", 0, 3], ["khrushchevka_h", 0, 6], ["khrushchevka_v", 8, 0], ["garages_h", 4, 9]], 
	[["tower16", 0, 0], ["tower16", 7, 0], ["panel9_h", 1, 5], ["kiosk", 4, 1]], 
	[["panel9_h", 1, 0], ["panel9_h", 1, 6], ["kiosk", 0, 4]], 
]
const SCHOOL_LAYOUT: Array = [["school", 2, 1], ["khrushchevka_h", 0, 6], ["garages_h", 5, 9], ["kiosk", 8, 6]]
const CENTER_LAYOUTS: Array = [
	[["stalinka_h", 0, 0], ["stalinka_v", 7, 0], ["stalinka_h", 0, 7], ["kiosk", 4, 4]], 
	[["stalinka_v", 0, 0], ["stalinka_h", 4, 0], ["tower16", 6, 6], ["kiosk", 1, 8]], 
	[["stalinka_h", 2, 0], ["stalinka_h", 2, 7], ["kiosk", 0, 4], ["kiosk", 9, 4]], 
]
const ADMIN_LAYOUT: Array = [["admin", 2, 2], ["kiosk", 0, 0], ["kiosk", 9, 9]]
const INDUSTRIAL_LAYOUTS: Array = [
	[["factory", 0, 0], ["warehouse", 0, 6], ["warehouse", 5, 6], ["garages_v", 8, 0], ["garages_v", 9, 0]], 
	[["warehouse", 0, 0], ["warehouse", 5, 0], ["factory", 2, 4]], 
]
const HOUSES: Array = ["house_a", "house_b", "house_c", "house_d"]
const YARD_TREES: Array = ["tree_oak_a", "tree_oak_b", "tree_birch_a", "bush_a"]

enum District{CENTER, ADMIN, PANEL, SCHOOL, PRIVATE, INDUSTRIAL}


static func params(kind: int) -> Dictionary:
	match kind:
		City.Kind.CAPITAL:
			return {"step": 11, "radius": 34, "min_blocks": 10, "center": 0.3, "panel": 0.64, "ind_max": 4, "claim": 116}
		City.Kind.TOWN:
			return {"step": 11, "radius": 21, "min_blocks": 4, "center": 0.22, "panel": 0.55, "ind_max": 2, "claim": 60}
	return {"step": 9, "radius": 11, "min_blocks": 2, "center": 0.0, "panel": 0.0, "ind_max": 0, "claim": 32}


static func plan(world: WorldData, atlas: SpriteAtlas, center: Vector2i, kind: int, seed_v: int) -> Dictionary:
	var p: Dictionary = params(kind)
	var rng: = Rng.new(seed_v)
	var S: int = int(p["step"])
	var I: int = S - 1
	var R: int = int(p["radius"])
	var nb: int = R / S + 1
	var res: Dictionary = {"ok": false, "reason": "", "streets": [], "avenues": [], "ground": [], "buildings": [], "trees": [], "cells": [], "entrance": center, "radius": R, "claim": int(p["claim"])}
	if not world.inside(center.x, center.y) or not Biome.is_natural_land(world.get_biome(center.x, center.y)):
		res["reason"] = "Здесь нельзя строить"
		return res
	if world.has_flag(center.x, center.y, WorldData.F_CITY):
		res["reason"] = "Здесь уже город"
		return res
	var blocks: Array = []
	for bj in range( - nb, nb):
		for bi in range( - nb, nb):
			var x0: int = center.x + bi * S + 1
			var y0: int = center.y + bj * S + 1
			var bcx: int = x0 + I / 2 - center.x
			var bcy: int = y0 + I / 2 - center.y
			var wob: int = 82 + (Hash32.h2(bi + 64, bj + 64, seed_v) % 34)
			var lim: int = R * wob / 100
			var d2: int = bcx * bcx + bcy * bcy
			if d2 > lim * lim:
				continue
			if x0 < 2 or y0 < 2 or x0 + I >= world.w - 2 or y0 + I >= world.h - 2:
				continue
			var good: int = 0
			var bad: bool = false
			for yy in range(y0, y0 + I):
				for xx in range(x0, x0 + I):
					var b: int = world.get_biome(xx, yy)
					if Biome.is_water(b) or world.has_flag(xx, yy, WorldData.F_CITY) or world.has_flag(xx, yy, WorldData.F_ROAD):
						bad = true
						break
					if Biome.is_natural_land(b):
						good += 1
				if bad:
					break
			if bad or good * 100 < I * I * 85:
				continue
			if _ring_fresh(world, x0, y0, I):
				continue
			blocks.append([bi, bj, x0, y0, d2])


	var bridges: Array = []
	if not blocks.is_empty() and _fresh_near(world, center, R + 6):
		var bb: Array = _bridge_banks(world, blocks, center, S, I, 2 if kind == City.Kind.CAPITAL else (1 if kind == City.Kind.TOWN else 0))
		bridges = bb[0]
		blocks = bb[1]
	if blocks.size() < int(p["min_blocks"]):
		res["reason"] = "Мало места для города"
		return res

	blocks.sort_custom( func(a: Array, b: Array) -> bool: return int(a[4]) < int(b[4]))
	var ind_q: int = rng.range_i(4)
	var ind_count: int = 0
	var school_done: bool = false
	var districts: Array = []
	for k in blocks.size():
		var bl: Array = blocks[k]
		var dist: float = sqrt(float(bl[4]))
		var dd: int = District.PRIVATE
		if kind != City.Kind.VILLAGE:
			if dist < R * float(p["center"]):
				dd = District.CENTER
			elif dist < R * float(p["panel"]):
				dd = District.PANEL
			var q: int = (1 if int(bl[0]) >= 0 else 0) + (2 if int(bl[1]) >= 0 else 0)
			if dist > R * 0.7 and q == ind_q and ind_count < int(p["ind_max"]) and rng.chance(70):
				dd = District.INDUSTRIAL
				ind_count += 1
		if k == 0 and kind == City.Kind.CAPITAL:
			dd = District.ADMIN
		elif dd == District.PANEL and not school_done:
			dd = District.SCHOOL
			school_done = true
		districts.append(dd)
	if kind == City.Kind.TOWN and not school_done:
		districts[0] = District.SCHOOL
	_build(world, atlas, res, blocks, districts, kind, center, rng, I, true)

	var runs: Array = []
	for bp: Array in bridges:
		var dir: int = int(bp[1])
		var run: Array[Vector2i] = []
		for c: Vector2i in bp[0]:
			if _is_fresh(world, c.x, c.y):
				run.append(c)
				continue
			if not run.is_empty():
				runs.append(_run_entry(run, dir))
				run = []
			res["streets"].append(c)
			res["cells"].append(c)
		if not run.is_empty():
			runs.append(_run_entry(run, dir))
	res["bridges"] = runs
	res["ok"] = true
	return res


static func _run_entry(run: Array[Vector2i], dir: int) -> Array:
	var dirs: = PackedByteArray()
	dirs.resize(run.size())
	dirs.fill(dir)
	return [run.duplicate(), dirs]



static func _is_fresh(world: WorldData, x: int, y: int) -> bool:
	if not world.inside(x, y):
		return false
	var b: int = world.biome[y * world.w + x]
	if b == Biome.RIVER:
		return true
	return (b == Biome.SHALLOW or b == Biome.COAST) and not world.lakes.is_empty() and world.lake_at(x, y) == 1


static func _fresh_near(world: WorldData, c: Vector2i, r: int) -> bool:
	for y in range(c.y - r, c.y + r + 1, 2):
		for x in range(c.x - r, c.x + r + 1, 2):
			if _is_fresh(world, x, y):
				return true
	return false



static func _ring_fresh(world: WorldData, x0: int, y0: int, I: int) -> bool:
	for t in range(-1, I + 1):
		if _is_fresh(world, x0 + t, y0 - 1) or _is_fresh(world, x0 + t, y0 + I) or _is_fresh(world, x0 - 1, y0 + t) or _is_fresh(world, x0 + I, y0 + t):
			return true
	return false







static func _bridge_banks(world: WorldData, blocks: Array, center: Vector2i, S: int, I: int, extra: int) -> Array:
	var road: Dictionary = {}
	for bl: Array in blocks:
		var x0: int = int(bl[2])
		var y0: int = int(bl[3])
		for t in range(-1, I + 1):
			for c: Vector2i in [Vector2i(x0 + t, y0 - 1), Vector2i(x0 + t, y0 + I), Vector2i(x0 - 1, y0 + t), Vector2i(x0 + I, y0 + t)]:
				if world.inside(c.x, c.y) and not Biome.is_water(world.get_biome(c.x, c.y)):
					road[c] = true
	var comp: Dictionary = {}
	var nc: int = 0
	for c0: Vector2i in road:
		if comp.has(c0):
			continue
		comp[c0] = nc
		var q: Array[Vector2i] = [c0]
		var h: int = 0
		while h < q.size():
			var c: Vector2i = q[h]
			h += 1
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var e: Vector2i = c + d
				if road.has(e) and not comp.has(e):
					comp[e] = nc
					q.append(e)
		nc += 1
	if nc <= 1:
		return [[], blocks]
	var cands: Array = []
	for c: Vector2i in road:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if road.has(c + d) or not (d.x == 1 and posmod(c.y - center.y, S) == 0 or d.y == 1 and posmod(c.x - center.x, S) == 0):
				continue
			var wn: int = 0
			var path: Array[Vector2i] = []
			for k in range(1, 21):
				var e: Vector2i = c + d * k
				if road.has(e):
					if wn > 0 and int(comp[e]) != int(comp[c]):
						cands.append([path.size(), int(comp[c]), int(comp[e]), path, 0 if d.x == 1 else 1, c])
					break
				if not world.inside(e.x, e.y) or world.has_flag(e.x, e.y, WorldData.F_ROAD | WorldData.F_CITY | WorldData.F_OCCUPIED):
					break
				if _is_fresh(world, e.x, e.y):
					wn += 1
					if wn > 10:
						break
				elif not Biome.is_natural_land(world.get_biome(e.x, e.y)):
					break
				path.append(e)
	cands.sort_custom( func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and (a[5] as Vector2i) < (b[5] as Vector2i)))
	var par: Array = []
	for i in nc:
		par.append(i)
	var find: = func(x: int) -> int:
		while par[x] != x:
			x = par[x]
		return x
	var out: Array = []
	var used: Array[Vector2i] = []
	for cd: Array in cands:
		var ra: int = find.call(int(cd[1]))
		var rb: int = find.call(int(cd[2]))
		if ra != rb:
			par[ra] = rb
			out.append([cd[3], cd[4]])
			used.append(cd[5])
	for cd: Array in cands:
		if extra <= 0:
			break
		var far: bool = true
		for u: Vector2i in used:
			if absi(u.x - (cd[5] as Vector2i).x) + absi(u.y - (cd[5] as Vector2i).y) < S * 3:
				far = false
				break
		if far:
			out.append([cd[3], cd[4]])
			used.append(cd[5])
			extra -= 1

	var best_k: int = 0
	for k in blocks.size():
		if int(blocks[k][4]) < int(blocks[best_k][4]):
			best_k = k
	var root: int = find.call(int(comp[Vector2i(int(blocks[best_k][2]) - 1, int(blocks[best_k][3]) - 1)])) if comp.has(Vector2i(int(blocks[best_k][2]) - 1, int(blocks[best_k][3]) - 1)) else -1
	var kept: Array = []
	for bl: Array in blocks:
		var x0: int = int(bl[2])
		var y0: int = int(bl[3])
		var ok: bool = false
		for c: Vector2i in [Vector2i(x0 - 1, y0 - 1), Vector2i(x0 + I, y0 - 1), Vector2i(x0 - 1, y0 + I), Vector2i(x0 + I, y0 + I), Vector2i(x0 + I / 2, y0 - 1), Vector2i(x0 + I / 2, y0 + I)]:
			if comp.has(c) and (root < 0 or find.call(int(comp[c])) == root):
				ok = true
				break
		if ok:
			kept.append(bl)
	return [out, kept]



static func _build(world: WorldData, atlas: SpriteAtlas, res: Dictionary, blocks: Array, districts: Array, kind: int, center: Vector2i, rng: Rng, I: int, set_entrance: bool) -> void :

	var street_set: Dictionary = {}
	var cell_set: Dictionary = {}
	for bl in blocks:
		var x0: int = int(bl[2])
		var y0: int = int(bl[3])
		for t in range(-1, I + 1):
			for c: Vector2i in [Vector2i(x0 + t, y0 - 1), Vector2i(x0 + t, y0 + I), Vector2i(x0 - 1, y0 + t), Vector2i(x0 + I, y0 + t)]:
				if world.inside(c.x, c.y) and not Biome.is_water(world.get_biome(c.x, c.y)):
					street_set[c] = true
		for yy in range(y0, y0 + I):
			for xx in range(x0, x0 + I):
				cell_set[Vector2i(xx, yy)] = true


	var quay: Dictionary = {}
	var seen: Dictionary = {}
	for bl in blocks:
		var x0: int = int(bl[2])
		var y0: int = int(bl[3])
		for yy in range(y0 - 5, y0 + I + 5):
			for xx in range(x0 - 5, x0 + I + 5):
				var c: = Vector2i(xx, yy)
				if seen.has(c):
					continue
				seen[c] = true
				if not world.inside(xx, yy) or world.has_flag(xx, yy, WorldData.F_CITY | WorldData.F_ROAD | WorldData.F_OCCUPIED):
					continue
				if not street_set.has(c) and (cell_set.has(c) or not Biome.is_natural_land(world.get_biome(xx, yy))):
					continue
				if _is_fresh(world, xx + 1, yy) or _is_fresh(world, xx - 1, yy) or _is_fresh(world, xx, yy + 1) or _is_fresh(world, xx, yy - 1):
					quay[c] = true
	if not quay.is_empty():
		for q: Vector2i in quay:
			street_set.erase(q)
			cell_set[q] = true
		for q: Vector2i in quay.keys():
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				var e: Vector2i = q + d
				if seen.has(e) and not quay.has(e) and not cell_set.has(e) and world.inside(e.x, e.y)\
				and Biome.is_natural_land(world.get_biome(e.x, e.y)) and not world.has_flag(e.x, e.y, WorldData.F_CITY | WorldData.F_ROAD | WorldData.F_OCCUPIED):
					street_set[e] = true
	res["quays"] = quay.keys()
	for c: Vector2i in street_set:
		cell_set[c] = true
		if kind == City.Kind.CAPITAL and (c.x == center.x or c.y == center.y):
			res["avenues"].append(c)
		else:
			res["streets"].append(c)
	res["cells"] = cell_set.keys()
	if set_entrance:
		res["entrance"] = center if street_set.has(center) else street_set.keys()[0]

	var occ: Dictionary = {}
	for k in blocks.size():
		var bl: Array = blocks[k]
		var x0: int = int(bl[2])
		var y0: int = int(bl[3])
		var dd: int = districts[k]
		var ground_b: int = Biome.YARD
		var layout: Array = []
		var tree_pct: int = 12
		match dd:
			District.ADMIN:
				layout = ADMIN_LAYOUT
				ground_b = Biome.PLAZA
				tree_pct = 8
			District.CENTER:
				layout = rng.pick(CENTER_LAYOUTS)
			District.PANEL:
				layout = rng.pick(PANEL_LAYOUTS)
			District.SCHOOL:
				layout = SCHOOL_LAYOUT
			District.INDUSTRIAL:
				layout = rng.pick(INDUSTRIAL_LAYOUTS)
				ground_b = Biome.INDUSTRIAL
				tree_pct = 4
			_:
				ground_b = Biome.GARDEN
				tree_pct = 22
		for yy in range(y0, y0 + I):
			for xx in range(x0, x0 + I):
				res["ground"].append([Vector2i(xx, yy), ground_b if dd != District.PRIVATE else (Biome.GARDEN if ((xx - x0) % 3 != 2 and (yy - y0) % 3 != 2) else Biome.GRASS)])
		if dd == District.PRIVATE:
			var lots: int = I / 3
			for ly in lots:
				for lx in lots:
					if rng.chance(86):
						_try_place(res, atlas, occ, world, rng.pick(HOUSES), x0 + lx * 3, y0 + ly * 3, x0, y0, I)
			if kind == City.Kind.VILLAGE and k == 0:
				_try_place(res, atlas, occ, world, "kiosk", x0 + I - 1, y0 + I - 1, x0, y0, I)
		else:
			for item: Array in layout:
				_try_place(res, atlas, occ, world, String(item[0]), x0 + int(item[1]), y0 + int(item[2]), x0, y0, I)
		for yy in range(y0, y0 + I):
			for xx in range(x0, x0 + I):
				var c: = Vector2i(xx, yy)
				if not occ.has(c) and rng.chance(tree_pct):
					res["trees"].append([rng.pick(YARD_TREES), c])
					occ[c] = true


static func _try_place(res: Dictionary, atlas: SpriteAtlas, occ: Dictionary, world: WorldData, sprite: String, x: int, y: int, x0: int, y0: int, size: int) -> bool:
	if not atlas.has(sprite):
		return false
	var info: Dictionary = atlas.info(sprite)
	var fw: int = int(info["fw"])
	var fd: int = int(info["fd"])
	if x < x0 or y < y0 or x + fw > x0 + size or y + fd > y0 + size:
		return false
	for yy in range(y, y + fd):
		for xx in range(x, x + fw):
			if occ.has(Vector2i(xx, yy)):
				return false
			var b: int = world.get_biome(xx, yy)
			if not Biome.is_natural_land(b):
				return false
	for yy in range(y, y + fd):
		for xx in range(x, x + fw):
			occ[Vector2i(xx, yy)] = true
	res["buildings"].append([sprite, Vector2i(x, y)])
	return true






static func grow(world: WorldData, atlas: SpriteAtlas, city: City, r_new: int, rail_mask: PackedByteArray, panel_frac: float) -> Dictionary:
	var kind: int = city.kind
	var center: Vector2i = city.center
	var p: Dictionary = params(kind)
	var seed_v: int = Hash32.h2(center.x, center.y, world.world_seed)
	var rng: = Rng.new(seed_v + city.radius * 7919)
	var S: int = int(p["step"])
	var I: int = S - 1
	var nb: int = r_new / S + 1
	var res: Dictionary = {"ok": false, "reason": "", "streets": [], "avenues": [], "ground": [], "buildings": [], "trees": [], "cells": [], "entrance": city.entrance, "radius": r_new, "claim": city.claim_max, "added": 0}
	var blocks: Array = []
	for bj in range( - nb, nb):
		for bi in range( - nb, nb):
			var x0: int = center.x + bi * S + 1
			var y0: int = center.y + bj * S + 1
			var bcx: int = x0 + I / 2 - center.x
			var bcy: int = y0 + I / 2 - center.y
			var wob: int = 82 + (Hash32.h2(bi + 64, bj + 64, seed_v) % 34)
			var lim: int = r_new * wob / 100
			var d2: int = bcx * bcx + bcy * bcy
			if d2 > lim * lim:
				continue
			if x0 < 3 or y0 < 3 or x0 + I >= world.w - 3 or y0 + I >= world.h - 3:
				continue
			var bad: bool = false
			for yy in range(y0 - 1, y0 + I + 1):
				for xx in range(x0 - 1, x0 + I + 1):
					var i: int = yy * world.w + xx
					var fl: int = world.flags[i]
					var ring: bool = yy < y0 or xx < x0 or yy >= y0 + I or xx >= x0 + I
					if not rail_mask.is_empty() and rail_mask[i] != 0:
						bad = true
					elif (fl & (WorldData.F_BRIDGE)) != 0:
						bad = true
					elif ring:

						if (fl & WorldData.F_OCCUPIED) != 0 or ((fl & WorldData.F_ROAD) != 0 and (fl & WorldData.F_CITY) == 0):
							bad = true
					elif (fl & (WorldData.F_CITY | WorldData.F_ROAD | WorldData.F_OCCUPIED)) != 0 or world.owners[i] != city.country_id\
					or not Biome.is_natural_land(world.biome[i]):
						bad = true
					if bad:
						break
				if bad:
					break
			if not bad and _foreign_near(world, x0, y0, I, city.country_id):
				bad = true
			if not bad:
				blocks.append([bi, bj, x0, y0, d2])
	if blocks.is_empty():
		res["reason"] = "no room"
		return res
	blocks.sort_custom( func(a: Array, b: Array) -> bool: return int(a[4]) < int(b[4]))
	var districts: Array = []
	for bl: Array in blocks:
		var dist: float = sqrt(float(bl[4]))
		districts.append(District.PANEL if kind != City.Kind.VILLAGE and dist < r_new * panel_frac else District.PRIVATE)
	_build(world, atlas, res, blocks, districts, kind, center, rng, I, false)
	res["added"] = blocks.size()
	res["ok"] = true
	return res



static func _foreign_near(world: WorldData, x0: int, y0: int, I: int, cid: int) -> bool:
	var g: int = preload("res://game/border_gap.gd").GAP
	for y in range(maxi(0, y0 - g), mini(world.h, y0 + I + g + 1), 3):
		for x in range(maxi(0, x0 - g), mini(world.w, x0 + I + g + 1), 3):
			var o: int = world.owners[y * world.w + x]
			if o != 0 and o != cid:
				return true
	return false
