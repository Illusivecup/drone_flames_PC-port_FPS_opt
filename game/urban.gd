class_name Urban
extends RefCounted






const HIGH: Array = ["highrise_panel", "highrise_brick"]
const GLASS: Array = ["glass_tower_a", "glass_tower_b"]
const BIZ: String = "business_center"
const TV: String = "tv_tower"

const REPL: Dictionary = {
	"panel9_h": [Vector2i(0, 0), Vector2i(5, 0)], "panel9_v": [Vector2i(0, 0), Vector2i(0, 5)], 
	"stalinka_h": [Vector2i(0, 0), Vector2i(3, 0)], "stalinka_v": [Vector2i(0, 0), Vector2i(0, 3)], 
	"tower16": [Vector2i(0, 0)], 
}
const REPL_BIZ: Dictionary = {"stalinka_h": Vector2i(0, 0), "panel9_h": Vector2i(1, 0)}

var gw: GameWorld
var rail: Rail
var stage: Dictionary = {}
var towers: Array = []
var _job: Dictionary = {}
var _apply_q: Array = []


func _init(world: GameWorld, r: Rail) -> void :
	gw = world
	rail = r


static func steps(kind: int) -> Array:
	match kind:
		City.Kind.CAPITAL:
			return [[2, "ring"], [2, "high", 2], [3, "high", 2], [3, "glass", 2], [3, "ring"], [4, "tv"], [4, "glass", 3], [4, "biz", 1]]
		City.Kind.TOWN:
			return [[2, "high", 1], [3, "ring"], [3, "high", 2], [4, "glass", 2], [4, "ring"]]
	return [[3, "ring"], [4, "ring"]]



func city_stage(city_id: int) -> int:
	return int(stage.get(city_id, 0))


func tower_count(city_id: int) -> int:
	var n: int = 0
	for t: Array in towers:
		if int(t[2]) == city_id and gw.obj_state[int(t[0])] != 2:
			n += 1
	return n



func tick() -> bool:
	if not _job.is_empty() or not _apply_q.is_empty():
		return false
	for c: Country in gw.countries:
		if c.eliminated:
			continue
		var lvl: int = rail.level_of(c.id)
		if lvl < 2:
			continue
		for cid in c.city_ids:
			var city: City = gw.cities[cid]
			var st: Array = steps(city.kind)
			var k: int = int(stage.get(cid, 0))
			while k < st.size() and int(st[k][0]) <= lvl:
				var done: bool = _do(city, st[k])
				k += 1
				stage[cid] = k
				if done:
					if c.is_player:
						gw.say(c, Loc.mk("%s растёт: %s", [Loc.name(city.name), _what(String(st[k - 1][1]))]))
					return true
	return false


static func _what(a: String) -> String:
	match a:
		"ring":
			return Loc.t("новые кварталы")
		"high":
			return Loc.t("новые высотки")
		"glass":
			return Loc.t("небоскрёбы")
		"biz":
			return Loc.t("деловой центр")
		"tv":
			return Loc.t("телебашня")
	return Loc.t("застройка")


func _do(city: City, step: Array) -> bool:
	match String(step[1]):
		"ring":
			return _ring(city)
		"high":
			return _replace(city, HIGH, int(step[2]))
		"glass":
			return _replace(city, GLASS, int(step[2]))
		"biz":
			return _biz(city)
		"tv":
			return _tv(city)
	return false


func _ring(city: City) -> bool:

	var S: int = int(CityGen.params(city.kind)["step"])
	var d: WorldData = gw.data
	var snap: = WorldData.new(0, 0, d.world_seed)
	snap.w = d.w
	snap.h = d.h
	snap.biome = d.biome.duplicate()
	snap.flags = d.flags.duplicate()
	snap.owners = d.owners.duplicate()
	snap.lakes = d.lakes
	var cc: = City.new()
	cc.id = city.id
	cc.kind = city.kind
	cc.center = city.center
	cc.entrance = city.entrance
	cc.radius = city.radius
	cc.claim_max = city.claim_max
	cc.country_id = city.country_id
	var gmask: PackedByteArray = rail.mask.duplicate()
	_reserve_deposits(gmask, city.center, city.radius + S + 14)
	_job = {"snap": snap, "city": cc, "r_new": city.radius + S, "mask": gmask, "atlas": gw.atlas, 
		"frac": 0.75 if city.kind == City.Kind.CAPITAL else 0.6, "plan": {}, "data_id": d.get_instance_id()}
	_job["task"] = WorkerThreadPool.add_task(_ring_worker.bind(_job), false, "urban plan")
	return true




func _reserve_deposits(mask: PackedByteArray, center: Vector2i, reach: int) -> void :
	if gw.econ == null:
		return
	var d: WorldData = gw.data
	if mask.size() < d.w * d.h:
		return
	for dp: Dictionary in gw.econ.deposits:
		var dc: Vector2i = dp["cell"]
		if dp["mine"] != null or maxi(absi(dc.x - center.x), absi(dc.y - center.y)) > reach:
			continue
		for y in range(maxi(0, dc.y - 5), mini(d.h, dc.y + 6)):
			for x in range(maxi(0, dc.x - 5), mini(d.w, dc.x + 6)):
				mask[y * d.w + x] = 1


func _ring_worker(job: Dictionary) -> void :
	job["plan"] = CityGen.grow(job["snap"], job["atlas"], job["city"], int(job["r_new"]), job["mask"], float(job["frac"]))



func poll() -> void :
	if not _job.is_empty() and gw.job_ready(int(_job["task"])):
		WorkerThreadPool.wait_for_task_completion(int(_job["task"]))
		var job: Dictionary = _job
		_job = {}
		var plan: Dictionary = job["plan"]
		var city: City = gw.cities[int((job["city"] as City).id)]
		if int(job["data_id"]) == gw.data.get_instance_id() and bool(plan.get("ok", false)) and _plan_still_free(plan):
			city.radius = maxi(city.radius, int(job["r_new"]))
			_split_plan(plan, city.id)
			print("[Urban] %s +%d blocks (r %d)" % [city.name, int(plan["added"]), city.radius])
	if not _apply_q.is_empty():
		var t0: int = Time.get_ticks_usec()
		var part: Array = _apply_q.pop_front()
		var city2: City = gw.cities[int(part[0])]
		gw._apply_plan(part[1], city2)
		if _apply_q.is_empty() or int(_apply_q[0][0]) != city2.id:
			_refresh(city2)
		rail.pt("urban_apply", t0)


const PART: int = 160


func _split_plan(plan: Dictionary, city_id: int) -> void :
	var keys: Array = ["cells", "ground", "streets", "avenues", "buildings", "trees", "quays"]
	if not plan.has("quays"):
		plan["quays"] = []
	var n: int = 1
	for k: String in keys:
		n = maxi(n, ((plan[k] as Array).size() + PART - 1) / PART)
	n = mini(n, 12)
	for p in n:
		var part: Dictionary = {}
		for k: String in keys:
			var arr: Array = plan[k]
			var sz: int = (arr.size() + n - 1) / n
			part[k] = arr.slice(p * sz, mini(arr.size(), (p + 1) * sz))
		_apply_q.append([city_id, part])



func _plan_still_free(plan: Dictionary) -> bool:
	var d: WorldData = gw.data
	for g: Array in plan["ground"]:
		var c: Vector2i = g[0]
		var i: int = c.y * d.w + c.x
		if (d.flags[i] & (WorldData.F_OCCUPIED | WorldData.F_CITY | WorldData.F_ROAD)) != 0 or rail.mask[i] != 0:
			return false
	return true


func drain() -> void :
	if not _job.is_empty():
		WorkerThreadPool.wait_for_task_completion(int(_job["task"]))
		_job = {}
	_apply_q.clear()


func _refresh(city: City) -> void :
	if gw.life != null:
		gw.life._streets.erase(city.id)
	if gw.night != null:
		gw.night._cells.erase(city.id)
	gw.city_power._cells.erase(city.id)



func _replace(city: City, pool: Array, n: int) -> bool:
	if not gw.spr_index.has(String(pool[0])):
		return false
	var cands: Array = _candidates(city, REPL)
	var placed: int = 0
	for cd: Array in cands:
		if placed >= n:
			break
		var id: int = cd[1]
		var nm: String = gw.spr_name[gw.obj_spr[id]]
		var base: = Vector2i(gw.obj_x[id], gw.obj_y[id])
		var offs: Array = REPL[nm]
		var take: int = mini(offs.size(), n - placed)



		var plan: Array = []
		for j in take:
			var tn: String = String(pool[(Hash32.h2(base.x + j, base.y, 77) >> 3) % pool.size()])
			var nw: Vector2i = base + (offs[j] as Vector2i)
			if _tall_clash(tn, nw, id, plan):
				tn = LOW if not _tall_clash(LOW, nw, id, plan) else ""
			if tn != "":
				plan.append([tn, nw])
		if plan.is_empty():
			continue
		_clear(id)
		for pl: Array in plan:
			if _place(String(pl[0]), pl[1], city):
				placed += 1
	return placed > 0


const LOW: String = "tower16"
const TALL_PX: int = 30




func _body(s: int, nw: Vector2i) -> Rect2i:
	var a: Vector2 = gw.spr_anchor[s]
	var base_y: int = (nw.y + gw.spr_fd[s]) * GameWorld.CELL
	var top: int = base_y - int(a.y)
	return Rect2i(nw.x * GameWorld.CELL, top, gw.spr_fw[s] * GameWorld.CELL, base_y - top)



func _tall_clash(sname: String, nw: Vector2i, skip_id: int, plan: Array) -> bool:
	if not gw.spr_index.has(sname):
		return true
	var s: int = int(gw.spr_index[sname])
	var me: Rect2i = _body(s, nw)
	for pl: Array in plan:
		if me.intersects(_body(int(gw.spr_index[String(pl[0])]), pl[1])):
			return true
	var reach: int = 24
	for ck: ObjChunk in gw.objects.chunks_in_rect(Rect2i(nw - Vector2i(4, reach), Vector2i(10, reach * 2 + 3))):
		for id in ck.ids:
			if id == skip_id or gw.obj_state[id] == 2 or gw.obj_kind[id] != GameWorld.KIND_BUILDING:
				continue
			var os: int = gw.obj_spr[id]
			if int(gw.spr_rect[os].size.y) < TALL_PX:
				continue
			if me.intersects(_body(os, Vector2i(gw.obj_x[id], gw.obj_y[id]))):
				return true
	return false


func _biz(city: City) -> bool:
	if not gw.spr_index.has(BIZ):
		return false
	for cd: Array in _candidates(city, REPL_BIZ):
		var id: int = cd[1]
		var nm: String = gw.spr_name[gw.obj_spr[id]]
		var base: = Vector2i(gw.obj_x[id], gw.obj_y[id]) + (REPL_BIZ[nm] as Vector2i)
		_clear(id)
		return _place(BIZ, base, city)
	return false



func _tv(city: City) -> bool:
	if not gw.spr_index.has(TV):
		return false
	var d: WorldData = gw.data
	var best: = Vector2i(-1, -1)
	var bd: int = 1 << 30
	var r: int = city.radius * 6 / 10
	for y in range(city.center.y - r, city.center.y + r):
		for x in range(city.center.x - r, city.center.x + r):
			var ok: bool = true
			for yy in range(y, y + 3):
				for xx in range(x, x + 3):
					if not d.inside(xx, yy):
						ok = false
						break
					var i: int = yy * d.w + xx
					if (d.flags[i] & (WorldData.F_OCCUPIED | WorldData.F_ROAD)) != 0 or (d.flags[i] & WorldData.F_CITY) == 0 or Biome.is_water(d.biome[i]):
						ok = false
						break
				if not ok:
					break
			if ok:
				var dd: int = (x + 1 - city.center.x) * (x + 1 - city.center.x) + (y + 1 - city.center.y) * (y + 1 - city.center.y)
				if dd < bd:
					bd = dd
					best = Vector2i(x, y)
	if best.x >= 0:
		for yy in range(best.y, best.y + 3):
			for xx in range(best.x, best.x + 3):
				gw.remove_tree_at(Vector2i(xx, yy))
				d.set_biome(xx, yy, Biome.PLAZA)
		return _place(TV, best, city)
	var cands: Array = _candidates(city, REPL)
	if cands.is_empty():
		return false
	var id: int = cands[0][1]
	var base: = Vector2i(gw.obj_x[id], gw.obj_y[id])
	_clear(id)
	return _place(TV, base, city)


func _candidates(city: City, table: Dictionary) -> Array:
	var out: Array = []
	var r: int = city.radius
	var lim: int = (r * 7 / 10) * (r * 7 / 10)
	for ck: ObjChunk in gw.objects.chunks_in_rect(Rect2i(city.center - Vector2i(r, r), Vector2i(r * 2 + 1, r * 2 + 1))):
		for id in ck.ids:
			if gw.obj_state[id] != 0 or gw.obj_kind[id] != GameWorld.KIND_BUILDING:
				continue
			var nm: String = gw.spr_name[gw.obj_spr[id]]
			if not table.has(nm):
				continue
			var dd: int = (gw.obj_x[id] - city.center.x) * (gw.obj_x[id] - city.center.x) + (gw.obj_y[id] - city.center.y) * (gw.obj_y[id] - city.center.y)
			if dd <= lim:
				out.append([dd, id])
	out.sort()
	return out



func _clear(id: int) -> void :
	var rr: Rect2i = gw.object_rect(id)
	gw.remove_object(id)
	for yy in range(rr.position.y, rr.end.y):
		for xx in range(rr.position.x, rr.end.x):
			gw.data.clear_flag(xx, yy, WorldData.F_OCCUPIED)
			gw.data.set_biome(xx, yy, Biome.PLAZA)
	gw.fx.spawn("dust_s", Vector2(rr.get_center() * GameWorld.CELL), 6)


func _place(sname: String, nw: Vector2i, city: City) -> bool:
	var id: int = gw.add_object(sname, nw, GameWorld.KIND_BUILDING)
	if id < 0:
		return false
	ArchStyle.mark(gw, id, city.country_id)
	var rr: Rect2i = gw.object_rect(id)
	for yy in range(rr.position.y, rr.end.y):
		for xx in range(rr.position.x, rr.end.x):
			gw.data.add_flag(xx, yy, WorldData.F_OCCUPIED)
			gw.remove_tree_at(Vector2i(xx, yy))
	towers.append([id, sname, city.id])
	gw.fx.spawn("build_spark", gw.obj_origin(id) + Vector2(6, 8), 6)
	_refresh(city)
	return true


func draw_lights(n: Node2D, view: Rect2, a: float, far: bool) -> void :
	var at: SpriteAtlas = gw.atlas11
	if at == null:
		return
	var warm: = Color(1.0, 0.86, 0.5, a)
	var cool: = Color(0.75, 0.9, 1.0, a * 0.9)
	var red: = Color(1.0, 0.15, 0.1, a)
	var blink: bool = int(gw.game_time * 1.5) % 2 == 0
	for t: Array in towers:
		var id: int = t[0]
		if gw.obj_state[id] != 0 or gw.spr_name[gw.obj_spr[id]] != String(t[1]):
			continue
		var org: Vector2 = ArchStyle.draw_origin(gw, id)
		if not view.grow(80).has_point(org):
			continue
		var city: City = gw.cities[int(t[2])]
		if not city.powered:
			continue
		var inf: Dictionary = ArchStyle.info_of(ArchStyle.draw_sid(gw, id), at.info(String(t[1])) if at.has(String(t[1])) else {})
		if inf.has("beacon") and blink:
			var bp: Array = inf["beacon"]
			n.draw_circle(org + Vector2(float(bp[0]), float(bp[1])), 2.5, Color(0.8, 0.1, 0.05, a * 0.5))
			n.draw_rect(Rect2(org + Vector2(float(bp[0]), float(bp[1])), Vector2(1, 1)), red)
		if far:
			continue
		var glass: bool = String(t[1]).begins_with("glass") or String(t[1]) == BIZ
		for p: Array in inf.get("lights", []):
			n.draw_rect(Rect2(org + Vector2(float(p[0]), float(p[1])), Vector2(1, 1)), cool if glass else warm)
