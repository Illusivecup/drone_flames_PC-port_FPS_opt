class_name FaunaLayer
extends Node2D














const ATLAS_PNG: = "res://assets/sprites/atlas_fauna319.png"
const ATLAS_JSON: = "res://assets/sprites/atlas_fauna319.json"
const MIN_ZOOM: float = 1.0
const SITE: float = 64.0
const SLOT: float = 20.0
const GOOSE_C: float = 100.0
const SCARE_R: float = 60.0
const ALERT_R: float = 115.0
const BLAST_R: float = 150.0
const FLEE_S: float = 5.0
const QUIET_S: float = 90.0
const PRESENT: float = 0.34
const WALK_V: Dictionary = {"deer": 4.0, "doe": 4.0, "fawn": 4.0, "elk": 3.5, "boar": 3.0, "piglet": 3.0, "hare": 3.0, "fox": 4.0, "stork": 2.5, "goose": 2.5}
const RUN_V: Dictionary = {"deer": 26.0, "doe": 26.0, "fawn": 22.0, "elk": 20.0, "boar": 17.0, "piglet": 15.0, "hare": 30.0, "fox": 24.0, "stork": 18.0, "goose": 20.0}
const DRINKERS: Array = ["deer", "elk", "boar", "goose", "stork"]
const BIRDS: Array = ["stork", "goose"]
const ANIM: Array = ["_idle", "_graze", "_walk", "_run", "_graze"]
const SEED_SALT: int = 5904368

var gw: GameWorld
var atlas: SpriteAtlas
var sites: Dictionary = {}
var blasts: Array = []
var _epoch: int = -1
var _data_id: int = 0
var _bins: Dictionary = {}
var _bins_t: float = -1.0
var _list: Array = []
var n_drawn: int = 0
var _eyes: Node2D
static var cost_us: int = 0
var _eyes_on: bool = false
var _last_t: float = -1.0
var _last_view: Rect2 = Rect2()
var _pending: bool = false
var _last_ms: int = 0


static func make(world: GameWorld) -> FaunaLayer:
	var f: = FaunaLayer.new()
	f.name = "Fauna"
	f.gw = world
	f.atlas = SpriteAtlas.load_atlas(ATLAS_PNG, ATLAS_JSON, true)
	world.add_child(f)
	f._eyes = Node2D.new()
	f._eyes.name = "FaunaEyes"
	f._eyes.z_index = 1
	var am: = CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	f._eyes.material = am
	f.add_child(f._eyes)
	f._eyes.draw.connect(f._draw_eyes)


	var a: Node = world.get_node_or_null("Fog")
	if a == null:
		a = world.get_node_or_null("Life")
	if a != null:
		world.move_child(f, a.get_index() + 1)
	return f


func reset() -> void :
	sites.clear()
	_fresh_memo.clear()
	_ok_memo.clear()
	_bin_rect = Rect2()
	blasts.clear()
	_bins.clear()
	_bins_t = -1.0
	_epoch = -1


func _process(_delta: float) -> void :
	if gw == null or gw.data == null or gw.camera == null or atlas == null or atlas.sprites.is_empty():
		return
	var t0: int = Time.get_ticks_usec()
	if gw.data.get_instance_id() != _data_id:
		_data_id = gw.data.get_instance_id()
		reset()
	var z: float = gw.camera.zoom.x
	var view: = Rect2(gw.camera.position - gw.camera.view_size() * 0.5 / z, gw.camera.view_size() / z)
	if z < MIN_ZOOM:
		if n_drawn > 0:
			_list.clear()
			queue_redraw()
		return
	var t: float = gw.game_time
	var ms: int = Time.get_ticks_msec()
	if view == _last_view and not _pending and (t == _last_t or ms - _last_ms < 30):
		cost_us = Time.get_ticks_usec() - t0
		return
	_last_ms = ms
	_last_t = t
	_last_view = view
	_list.clear()
	collect(view.grow(12.0), t, _thin(z), _list, 8)
	queue_redraw()
	if _eyes != null and ( not _list.is_empty() or _eyes_on):
		_eyes.queue_redraw()
	cost_us = Time.get_ticks_usec() - t0



func _thin(z: float) -> int:
	var m: int = 0
	if z < 1.5:
		m = 1
	if z < 1.2 or Vfx.level() == 0:
		m = 3
	return m




func _r(hs: int, k: int) -> float:
	return float(Hash32.mix(hs ^ ((k * 2654435761) & Hash32.M32)) & 65535) / 65536.0


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))



var _ok_memo: Dictionary = {}
var _ok_min: int = -1


func _ok(p: Vector2, sp: String) -> bool:
	var c: Vector2i = _cell(p)
	var d: WorldData = gw.data
	if not d.inside(c.x, c.y):
		return false
	var bird: int = 1 if (sp == "hare" or sp == "stork" or sp == "goose") else 0
	var key: int = (c.y * d.w + c.x) * 2 + bird
	var v: Variant = _ok_memo.get(key)
	if v != null:
		return v
	var r: bool = _ok_raw(c, bird == 1)
	_ok_memo[key] = r
	return r


func _ok_raw(c: Vector2i, bird: bool) -> bool:
	var d: WorldData = gw.data
	var b: int = d.get_biome(c.x, c.y)
	if not Biome.is_natural_land(b) or b == Biome.BURNT:
		return false
	if d.has_flag(c.x, c.y, WorldData.F_CITY | WorldData.F_OCCUPIED | WorldData.F_BRIDGE):
		return false
	if bird:
		if b == Biome.SAND:
			return false

	for dy in range(-3, 4, 3):
		for dx in range(-3, 4, 3):
			var x: int = c.x + dx
			var y: int = c.y + dy
			if d.inside(x, y):
				var bb: int = d.get_biome(x, y)
				if (bb >= Biome.ROAD and bb <= Biome.PLAZA) or bb == Biome.GARDEN or bb == Biome.INDUSTRIAL or d.has_flag(x, y, WorldData.F_CITY):
					return false
	var ta: Dictionary = gw.tree_at
	if not ta.is_empty():
		for ty in range(c.y, mini(c.y + 4, d.h)):
			for tx in range(maxi(c.x - 1, 0), mini(c.x + 2, d.w)):
				if ta.has(ty * d.w + tx):
					return false
	return true



func _edge_wood(c: Vector2i) -> bool:
	for dy in range(-4, 5, 4):
		for dx in range(-4, 5, 4):
			if gw.data.inside(c.x + dx, c.y + dy):
				var b: int = gw.data.get_biome(c.x + dx, c.y + dy)
				if b == Biome.FOREST or b == Biome.PINE:
					return true
	return false


func _road_near(c: Vector2i) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if gw.data.inside(c.x + dx, c.y + dy) and gw.data.has_flag(c.x + dx, c.y + dy, WorldData.F_ROAD):
				return true
	return false



func _edge(c: Vector2i) -> bool:
	var b0: int = gw.data.get_biome(c.x, c.y)
	if b0 != Biome.FOREST and b0 != Biome.PINE:
		return true
	for dy in range(-3, 4, 3):
		for dx in range(-3, 4, 3):
			if gw.data.inside(c.x + dx, c.y + dy):
				var b: int = gw.data.get_biome(c.x + dx, c.y + dy)
				if b == Biome.GRASS or b == Biome.FIELD or b == Biome.STEPPE or b == Biome.HILLS:
					return true
	return false




func _shore(c: Vector2i) -> Array:
	var out: Array = []
	var d: WorldData = gw.data

	var sea: bool = false
	for k in 16:
		var o: Vector2i = c + Vector2i((Vector2.from_angle(float(k) * TAU / 16.0) * (6.0 + float(k % 3) * 4.0)).round())
		if d.inside(o.x, o.y) and Biome.is_open_sea(d.get_biome(o.x, o.y)):
			sea = true
			break
	for dy in range(-12, 13, 2):
		for dx in range(-12, 13, 2):
			var x: int = c.x + dx
			var y: int = c.y + dy
			if not d.inside(x, y) or not Biome.is_natural_land(d.get_biome(x, y)) or d.has_flag(x, y, WorldData.F_CITY | WorldData.F_OCCUPIED):
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if d.inside(x + o.x, y + o.y):
					var bw: int = d.get_biome(x + o.x, y + o.y)
					if bw == Biome.RIVER or ( not sea and Biome.is_water(bw) and not Biome.is_open_sea(bw) and _fresh(Vector2i(x + o.x, y + o.y))):
						out.append([Vector2(x * GameWorld.CELL + 2, y * GameWorld.CELL + 2) + Vector2(o) * 1.5, o.x])
						break
			if out.size() >= 8:
				return out
	return out




const FRESH_MAX: int = 900
var _fresh_memo: Dictionary = {}


func _fresh(c: Vector2i) -> bool:
	var v: Variant = _fresh_memo.get(c)
	if v != null:
		return v
	var d: WorldData = gw.data
	var seen: Dictionary = {c: true}
	var todo: Array[Vector2i] = [c]
	var ok: bool = true
	var k: int = 0
	while k < todo.size():
		var q: Vector2i = todo[k]
		k += 1
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = q + o
			if seen.has(n) or not d.inside(n.x, n.y):
				continue
			var b: int = d.get_biome(n.x, n.y)
			if not Biome.is_water(b) or b == Biome.RIVER:
				continue
			if Biome.is_open_sea(b) or todo.size() >= FRESH_MAX:
				ok = false
				break
			seen[n] = true
			todo.append(n)
		if not ok:
			break
	for q: Vector2i in todo:
		_fresh_memo[q] = ok
	return ok


func _town_near(p: Vector2) -> bool:
	for c: City in gw.cities:
		var cr: float = float(c.radius + 4) * GameWorld.CELL
		if Vector2(c.center * GameWorld.CELL).distance_squared_to(p) < cr * cr:
			return true
	return false



func _pick_kind(b: int, r: float) -> String:
	match b:
		Biome.FOREST:
			return "deer" if r < 0.5 else ("boar" if r < 0.85 else "elk")
		Biome.PINE:
			return "elk" if r < 0.3 else ("deer" if r < 0.7 else "boar")
		Biome.GRASS, Biome.HILLS:
			return "deer" if r < 0.4 else ("hare" if r < 0.75 else "stork")
		Biome.FIELD:
			return "stork" if r < 0.4 else ("hare" if r < 0.8 else "deer")
		Biome.STEPPE:
			return "hare" if r < 0.6 else ("stork" if r < 0.75 else "deer")
	return ""





func _site(s: Vector2i) -> Dictionary:
	var hs: int = Hash32.h2(s.x, s.y, gw.data.world_seed ^ SEED_SALT)
	if _r(hs, 1) > PRESENT:
		return {}
	var home: = Vector2(s) * SITE + Vector2(8.0 + _r(hs, 2) * 48.0, 8.0 + _r(hs, 3) * 48.0)
	home = home.round()
	var c: Vector2i = _cell(home)
	if not gw.data.inside(c.x, c.y):
		return {}
	var b: int = gw.data.get_biome(c.x, c.y)
	var kind: String = _pick_kind(b, _r(hs, 4))
	if kind == "" or not _ok(home, kind) or _road_near(c) or _town_near(home):
		return {}
	if not _edge(c):
		return {}
	var shore: Array = _shore(c)
	if shore.is_empty() and (b == Biome.GRASS or b == Biome.FIELD or b == Biome.STEPPE) and not _edge_wood(c) and _r(hs, 7) < 0.4:
		return {}
	if not shore.is_empty() and (b == Biome.GRASS or b == Biome.FIELD or b == Biome.STEPPE) and _r(hs, 5) < 0.6:
		kind = "goose"
	var mem: Array = []
	match kind:
		"deer":
			mem.append("deer")
			for k in 1 + int(_r(hs, 20) * 2.0):
				mem.append("doe")
			for k in int(_r(hs, 21) * 2.0):
				mem.append("fawn")
		"elk":
			mem = ["elk"] if _r(hs, 20) < 0.6 else ["elk", "elk"]
		"boar":
			mem.append("boar")
			if _r(hs, 20) < 0.5:
				mem.append("boar")
			for k in 1 + int(_r(hs, 21) * 3.0):
				mem.append("piglet")
		"hare":
			mem = ["hare"] if _r(hs, 20) < 0.6 else ["hare", "hare"]
		"stork":
			for k in 1 + int(_r(hs, 20) * 2.0):
				mem.append("stork")
		"goose":
			for k in 3 + int(_r(hs, 20) * 3.0):
				mem.append("goose")
	var offs: Array = []
	var spread: float = (4.0 + 1.6 * float(mem.size())) * (1.5 if kind == "goose" else 1.0)
	for i in mem.size():
		var o: = Vector2.ZERO
		for tr in 6:
			o = Vector2((_r(hs, 40 + i + tr * 17) - 0.5) * 2.0 * spread, (_r(hs, 60 + i + tr * 17) - 0.5) * 1.2 * spread).round()
			var near: bool = false
			for q: Vector2 in offs:
				if q.distance_squared_to(o) < 25.0:
					near = true
					break
			if not near:
				break
		if mem[i] == "fawn" or mem[i] == "piglet":
			o = (offs[1] if offs.size() > 1 else offs[0]) + Vector2(3.0 if _r(hs, 80 + i) < 0.5 else -3.0, 1.0)
		offs.append(o.round())
	return {"hs": hs, "kind": kind, "home": home, "shore": shore, "mem": mem, "offs": offs, 
		"ph": _r(hs, 6), "sent": 1 if kind == "deer" and mem.size() >= 3 else -1, "tc": {}, "fp": [-1099511627776, {}]}





func _target(h: Dictionary, i: int, k: int) -> Array:
	var tc: Dictionary = h["tc"]
	var key: int = k * 16 + i
	var v: Variant = tc.get(key)
	if v != null:
		return v
	if tc.size() > 64:
		tc.clear()
	var r: Array = _target_raw(h, i, k)
	tc[key] = r
	return r


func _target_raw(h: Dictionary, i: int, k: int) -> Array:
	var hs: int = h["hs"]
	var hk: int = Hash32.h2(hs & 65535, k, hs)
	var home: Vector2 = h["home"]
	var sp: String = h["mem"][i]
	var off: Vector2 = h["offs"][i]
	var shore: Array = h["shore"]
	var drink: bool = not shore.is_empty() and DRINKERS.has(String(h["kind"])) and (hk & 255) < 100 and i != int(h["sent"])
	if drink:
		var e: Array = shore[(hk >> 8) % shore.size()]
		var e2: Array = shore[((hk >> 8) + i) % shore.size()]
		var p: Vector2 = e2[0] if (e2[0] as Vector2).distance_squared_to(e[0]) < 196.0 else e[0]
		p += Vector2(float(i % 3) - 1.0, float((i / 3) % 2)) * Vector2(2.0, 1.5)
		p = p.round()
		if not _ok(p, sp):
			p = e[0]
		if _ok(p, sp):
			return [p, true, int(e2[1]) if p.distance_squared_to(e2[0]) < 16.0 else int(e[1])]
	var anchor: Vector2 = home + Vector2(float((hk >> 8) & 255) / 255.0 - 0.5, float((hk >> 16) & 255) / 255.0 - 0.5) * Vector2(28.0, 18.0)
	var q: Vector2 = (anchor + off).round()
	if _ok(q, sp):
		return [q, false, 0]
	q = (home + off).round()
	return [q if _ok(q, sp) else home, false, 0]



func _calm(h: Dictionary, i: int, t: float) -> Array:
	var sp: String = h["mem"][i]
	var u0: float = t + float(h["ph"]) * SLOT
	var k: int = floori(u0 / SLOT)
	var u: float = u0 - float(k) * SLOT
	var a: Array = _target(h, i, k - 1)
	var b: Array = _target(h, i, k)
	var pa: Vector2 = a[0]
	var pb: Vector2 = b[0]
	var delay: float = float(i) * 0.6
	var w: float = minf(pa.distance_to(pb) / float(WALK_V[sp]), 9.0)
	var hs: int = h["hs"]
	if u < delay + w and w > 0.05:
		if u < delay:
			return [sp + "_idle", pa, pb.x < pa.x, 0.0]
		return [sp + "_walk", pa.lerp(pb, (u - delay) / w), pb.x < pa.x, 0.0]
	if bool(b[1]):
		var fl: bool = int(b[2]) < 0 if int(b[2]) != 0 else pb.x < pa.x
		var sub2: int = floori(u / 4.0)
		var look: bool = (Hash32.h2(i, k * 8 + sub2, hs) & 255) < 50
		return [sp + ("_idle" if look else "_graze"), pb, fl, 0.0]
	var sub: int = floori(u / 3.5)
	var hp: int = Hash32.h2(i, k * 8 + sub, hs) & 255
	var st: String = "_graze"
	if i == int(h["sent"]):
		st = "_idle" if hp < 190 else "_graze"
	elif sp == "hare":
		st = "_idle" if hp < 150 else "_graze"
	elif hp < 70:
		st = "_idle"
	return [sp + st, pb, (pb.x < pa.x) if (Hash32.mix(hs + k) & 1) == 0 else (hp & 1) == 1, 0.0]




func _goose(h: Dictionary, i: int, t: float, fox: Dictionary) -> Array:
	var u0: float = t + float(h["ph"]) * GOOSE_C
	var cyc: int = floori(u0 / GOOSE_C)
	var u: float = u0 - float(cyc) * GOOSE_C
	var t_off: float = float(fox["pounce"]) if not fox.is_empty() else 88.0
	if u < 5.0:
		var land: Array = _calm(h, i, t - u + 5.0)
		var wdir: Vector2 = Vector2.from_angle(float(Hash32.h2(cyc, 5, int(h["hs"])) & 65535) / 65536.0 * TAU)
		var lift: float = (5.0 - u) * 3.6
		return ["goose_run", (land[1] as Vector2) - wdir * lift * 2.2, wdir.x < 0.0, lift, minf(1.0, u * 1.5)]
	if u < t_off:
		var c: Array = _calm(h, i, t)
		c.append(1.0)
		return c
	var dt: float = u - t_off - float(i % 4) * 0.12
	if u - t_off > 6.0:
		return ["", Vector2.ZERO, false, 0.0, 0.0]
	var p0: Array = _calm(h, i, t - u + t_off)
	if dt < 0.0:
		return ["goose_idle", p0[1], p0[2], 0.0, 1.0]
	var src: Vector2 = fox["at"] if not fox.is_empty() else (h["home"] as Vector2) + Vector2.from_angle(float(Hash32.h2(cyc, 9, int(h["hs"])) & 65535) / 65536.0 * TAU) * 20.0
	var away: Vector2 = ((p0[1] as Vector2) - src).normalized().rotated((float(i % 5) - 2.0) * 0.12)
	var p: Vector2 = (p0[1] as Vector2) + away * 20.0 * dt
	return ["goose_run", p, away.x < 0.0, minf(18.0, dt * 7.0), clampf((6.0 - (u - t_off)) / 1.2, 0.0, 1.0)]



func _fox_plan(h: Dictionary, t: float) -> Dictionary:
	var u0: float = t + float(h["ph"]) * GOOSE_C
	var cyc: int = floori(u0 / GOOSE_C)
	var fp: Array = h["fp"]
	if int(fp[0]) == cyc:
		return fp[1]
	var f: Dictionary = _fox_plan_raw(h, t, u0, cyc)
	h["fp"] = [cyc, f]
	return f


func _fox_plan_raw(h: Dictionary, t: float, u0: float, cyc: int) -> Dictionary:
	var hc: int = Hash32.h2(cyc, 31, int(h["hs"]))
	if (hc & 255) >= 150:
		return {}
	var base: float = t - (u0 - float(cyc) * GOOSE_C)
	var g: Vector2 = (_calm(h, 0, base + 58.0)[1] as Vector2)
	var ang: float = float((hc >> 8) & 65535) / 65536.0 * TAU
	var s: = Vector2.INF
	for tr in 8:
		var q: Vector2 = (g + Vector2.from_angle(ang + float(tr) * 0.8) * 46.0).round()
		if not _ok(q, "fox") or _road_near(_cell(q)):
			continue
		var dq: Vector2 = (g - q).normalized()
		var dry: bool = true
		for k in 9:
			var pt: Vector2 = q.lerp(g + dq * 2.0, float(k) / 8.0)
			if not _ok(pt, "fox") or not _ok(g + dq * 2.0 - dq.rotated(0.5) * float(k) * 7.5, "fox"):
				dry = false
				break
		if dry:
			s = q
			break
	if s == Vector2.INF:
		return {}
	var dir: Vector2 = (g - s).normalized()
	return {"base": base, "from": s, "to": g - dir * 12.0, "at": g - dir * 12.0, "dir": dir, "pounce": 58.0, 
		"catch": ((hc >> 24) & 255) < 115}



func _fox(f: Dictionary, t: float) -> Array:
	var u: float = t - float(f["base"])
	if u < 38.0 or u > 70.0:
		return ["", Vector2.ZERO, false, 0.0]
	var s: Vector2 = f["from"]
	var e: Vector2 = f["to"]
	var dir: Vector2 = f["dir"]
	if u < 58.0:
		var v: float = u - 38.0
		var cyc: float = floorf(v / 3.7)
		var r: float = v - cyc * 3.7
		var moved: float = cyc * 2.5 + minf(r, 2.5)
		var prog: float = clampf(moved / (floorf(20.0 / 3.7) * 2.5 + minf(20.0 - floorf(20.0 / 3.7) * 3.7, 2.5)), 0.0, 1.0)
		return ["fox_stalk" if r < 2.5 else "fox_idle", s.lerp(e, prog), dir.x < 0.0, minf(1.0, v / 1.5)]
	if u < 58.55:
		return ["fox_run", e + dir * 14.0 * ((u - 58.0) / 0.55), dir.x < 0.0, 1.0]
	var land: Vector2 = e + dir * 14.0
	var back: Vector2 = - dir.rotated(0.5)
	if bool(f["catch"]):
		var p: Vector2 = land + back * 5.0 * (u - 58.55)
		return ["fox_carry", p, back.x < 0.0, clampf((70.0 - u) / 1.5, 0.0, 1.0)]
	if u < 60.5:
		return ["fox_idle", land, dir.x < 0.0, 1.0]
	return ["fox_walk", land + back * 4.0 * (u - 60.5), back.x < 0.0, clampf((70.0 - u) / 1.5, 0.0, 1.0)]





func blast(p: Vector2, size: int) -> void :
	if gw == null:
		return
	var r: float = BLAST_R * [0.75, 1.0, 1.5][clampi(size, 0, 2)]
	blasts.append([p, gw.game_time, r])
	var t: float = gw.game_time
	for k in range(blasts.size() - 1, -1, -1):
		if t - float(blasts[k][1]) > QUIET_S + 1.0 or float(blasts[k][1]) > t + 0.5:
			blasts.remove_at(k)





var _bin_rect: Rect2 = Rect2()


func _rebin(t: float, rect: Rect2) -> void :
	var q: float = floorf(t)
	if q == _bins_t and _bin_rect.grow(-260.0).encloses(rect):
		return
	_bins_t = q
	_bin_rect = rect.grow(400.0)
	_bins = {}
	var br: Rect2 = _bin_rect
	if gw.army != null:
		for u: Unit in gw.army.units:
			if u.state != Unit.State.DEAD and br.has_point(u.pos):
				_bin(u.pos)
	for f: Dictionary in gw.fires:
		if br.has_point(f["p"]):
			_bin(f["p"])
	if gw.mil != null:
		for d: Drone in gw.mil.drones:
			if br.has_point(d.pos):
				_bin(d.pos)


func _bin(p: Vector2) -> void :
	var s: = Vector2i(floori(p.x / SITE), floori(p.y / SITE))
	if not _bins.has(s):
		_bins[s] = PackedVector2Array()
	(_bins[s] as PackedVector2Array).append(p)



func _threat(p: Vector2) -> Array:
	var best: float = ALERT_R
	var bp: Vector2 = Vector2.INF
	var s: = Vector2i(floori(p.x / SITE), floori(p.y / SITE))
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var arr: Variant = _bins.get(s + Vector2i(dx, dy))
			if arr == null:
				continue
			for q: Vector2 in arr:
				var d: float = q.distance_to(p)
				if d < best:
					best = d
					bp = q
	return [best, bp]



func _blast_for(home: Vector2, t: float) -> Array:
	var out: Array = []
	for b: Array in blasts:
		var tb: float = b[1]
		if tb <= t and t - tb < QUIET_S and (b[0] as Vector2).distance_squared_to(home) < float(b[2]) * float(b[2]):
			if out.is_empty() or tb > float(out[1]):
				out = b
	return out






func collect(rect: Rect2, t: float, thin: int, out: Array, max_new: int) -> void :


	_epoch = floori(t / 180.0)
	var mn: int = floori(t / 60.0)
	if mn != _ok_min:
		_ok_min = mn
		_ok_memo.clear()
	_rebin(t, rect)
	_pending = false
	var s0: = Vector2i(floori((rect.position.x - 40.0) / SITE), floori((rect.position.y - 40.0) / SITE))
	var s1: = Vector2i(floori((rect.end.x + 40.0) / SITE), floori((rect.end.y + 40.0) / SITE))
	var built: int = 0
	for sy in range(s0.y, s1.y + 1):
		for sx in range(s0.x, s1.x + 1):
			var s: = Vector2i(sx, sy)
			var h: Variant = sites.get(s)
			if h == null or int((h as Dictionary)["ep"]) != _epoch:
				if built >= (max_new if h == null else mini(max_new, 2)):
					_pending = h == null
					if h == null:
						continue
				else:
					built += 1
					var nh: Dictionary = _site(s)
					nh["ep"] = _epoch
					sites[s] = nh
					h = nh
			var hd: Dictionary = h
			if not hd.has("hs") or ((int(hd["hs"]) >> 12) & thin) != 0:
				continue
			_herd(hd, t, rect, out)


func _herd(h: Dictionary, t: float, rect: Rect2, out: Array) -> void :
	var home: Vector2 = h["home"]
	var mem: Array = h["mem"]
	var goose: bool = h["kind"] == "goose"
	var fox: Dictionary = _fox_plan(h, t) if goose else {}

	var bl: Array = _blast_for(home, t)
	var alpha: float = 1.0
	var flee: float = -1.0
	var src: = Vector2.ZERO
	if not bl.is_empty():
		var e: float = t - float(bl[1])
		if e < FLEE_S:
			flee = e
			src = bl[0]
		elif e < QUIET_S - 4.0:
			return
		else:
			alpha = (e - (QUIET_S - 4.0)) / 4.0

	var th: Array
	var tc: Array = h.get("thr", [])
	if not tc.is_empty() and float(tc[0]) == _bins_t and is_same(tc[1], _bins):
		th = tc[2]
	else:
		th = _threat(home)
		h["thr"] = [_bins_t, _bins, th]
	var shift: = Vector2.ZERO
	var alert: bool = false
	if float(th[0]) < ALERT_R and flee < 0.0:
		if float(th[0]) < SCARE_R:
			return
		alert = true
		alpha = minf(alpha, (float(th[0]) - SCARE_R) / (ALERT_R - SCARE_R))
		shift = (home - (th[1] as Vector2)).normalized() * (ALERT_R - float(th[0])) * 0.4
	for i in mem.size():
		var sp: String = mem[i]
		var r: Array
		var al: float = alpha
		if flee >= 0.0:
			var at: Array = _goose(h, i, float(bl[1]), fox) if goose else _calm(h, i, float(bl[1]))
			if goose and float(at[4]) <= 0.0:
				continue
			var p0: Vector2 = at[1]
			var react: float = 0.1 + float(i % 4) * 0.12
			if flee < react:
				r = [sp + "_idle", p0, at[2], float(at[3])]
			else:
				var away: Vector2 = (p0 - src).normalized().rotated((float(i % 5) - 2.0) * 0.1)
				if away == Vector2.ZERO:
					away = Vector2.RIGHT
				var dd: float = float(RUN_V[sp]) * (flee - react)
				var lift: float = minf(18.0, (flee - react) * 7.0) if BIRDS.has(sp) else 0.0
				r = [sp + "_run", p0 + away * dd, away.x < 0.0, lift]
				al = minf(al, clampf((FLEE_S - flee) / 1.0, 0.0, 1.0))
		elif goose:
			var g: Array = _goose(h, i, t, fox)
			if float(g[4]) <= 0.0:
				continue
			al = minf(al, float(g[4]))
			r = [g[0], g[1], g[2], g[3]]
		else:
			r = _calm(h, i, t)
		var pos: Vector2 = (r[1] as Vector2) + shift


		if float(r[3]) < 1.0 and (shift != Vector2.ZERO or not String(r[0]).ends_with("_graze") and not String(r[0]).ends_with("_idle")):
			if not _ok(pos, sp):
				pos = r[1]
				if not _ok(pos, sp):
					continue
		if alert and String(r[0]).ends_with("_graze"):
			r[0] = sp + "_idle"
		if al <= 0.02 or not rect.has_point(pos):
			continue
		out.append([r[0], pos.round(), r[2], al, float(r[3])])
	if not fox.is_empty() and flee < 0.0:
		var f: Array = _fox(fox, t)
		var fa: float = minf(alpha, float(f[3]))
		var fp: Vector2 = (f[1] as Vector2) + shift
		if not _ok(fp, "fox"):
			fp = f[1]
		if fa > 0.02 and rect.has_point(fp) and _ok(fp, "fox"):
			out.append([f[0], fp.round(), f[2], fa, 0.0])



func digest(rect: Rect2, t: float) -> Array:
	var out: Array = []
	collect(rect, t, 0, out, 1 << 30)
	var acc: int = 17
	for e: Array in out:
		var p: Vector2 = e[1]
		acc = Hash32.mix(acc ^ String(e[0]).hash() ^ (int(p.x) * 73856093) ^ (int(p.y) * 19349663) ^ (1 if e[2] else 0) ^ int(float(e[3]) * 100.0) ^ (int(float(e[4])) << 7))
	return [out.size(), acc]




func _draw() -> void :
	n_drawn = 0
	if _list.is_empty() or gw.camera.zoom.x < MIN_ZOOM:
		return
	var tx: Texture2D = atlas.texture
	var sh: = Color(0.04, 0.07, 0.03, 0.22)
	var t: float = gw.game_time

	var q_dst: Array = []
	var q_src: Array = []
	var q_al: PackedFloat32Array = PackedFloat32Array()
	var k: int = 0
	for e: Array in _list:
		var nm: String = e[0]
		var al: float = e[3]
		var lift: float = e[4]
		var info: Dictionary = atlas.info(nm)
		if info.is_empty():
			continue
		var nf: int = int(info.get("frames", 1))
		var fr: int = 0
		if nf > 1:
			fr = int((t + float(k) * 0.37) * maxf(1.0, float(info.get("fps", 4)))) % nf
		k += 1
		var r: Rect2 = atlas.rect(nm, fr)
		var w: float = r.size.x
		var hh: float = r.size.y
		var p: Vector2 = e[1]
		var ax: float = float(info.get("ax", 0))
		var ay: float = float(info.get("ay", 0))
		if lift < 1.0:
			draw_rect(Rect2(p.x - floorf(w * 0.5) + 1.0, p.y, maxf(2.0, w - 2.0), 1.0), Color(sh, sh.a * al))
		else:
			draw_rect(Rect2(p.x - 2.0 + roundf(lift * 0.3), p.y + roundf(lift * 0.2), 4.0, 1.0), Color(sh, sh.a * al * 0.5))
		var tl: = Vector2(p.x - ax, p.y - ay - roundf(lift))
		var dst: = Rect2(tl, Vector2(w, hh))
		if bool(e[2]):
			dst = Rect2(Vector2(p.x + ax + 1.0, tl.y), Vector2( - w, hh))
		q_dst.append(dst)
		q_src.append(r)
		q_al.append(al)
	for j in q_dst.size():
		draw_texture_rect_region(tx, q_dst[j], q_src[j], Color(1, 1, 1, q_al[j]))
	n_drawn = q_dst.size()



func _draw_eyes() -> void :
	_eyes_on = false
	if _list.is_empty() or gw.night == null:
		return
	var nf: float = gw.night.night_factor()
	if nf < 0.45:
		return
	var kf: float = clampf((nf - 0.45) / 0.3, 0.0, 1.0)
	var j: int = 0
	for e: Array in _list:
		j += 1
		var nm: String = e[0]
		if nm.ends_with("_graze") or nm.begins_with("piglet") or float(e[3]) < 0.3:
			continue
		var inf: Dictionary = atlas.info(nm)
		if not inf.has("eye"):
			continue
		if sin(gw.game_time * 0.7 + float(j)) < -0.2:
			continue
		var ev: = Vector2(float(inf["eye"][0]), float(inf["eye"][1]))
		if bool(e[2]):
			ev.x = - ev.x
		var p: Vector2 = (e[1] as Vector2) + ev
		_eyes.draw_rect(Rect2(p, Vector2.ONE), Color(0.7, 1.0, 0.55, 0.9 * kf * float(e[3])))
		_eyes_on = true
