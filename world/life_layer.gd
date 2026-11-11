class_name LifeLayer
extends Node2D




const MAX_CARS: Array = [14, 8, 3]
const MAX_PEDS: Array = [16, 9, 4]
const CAR_SPEED: float = 9.0
const PED_SPEED: float = 2.5
const TRUCK_SPEED: float = 16.0
const SPRAY_TIME: float = 6.0

var gw: GameWorld
var agents: Array = []
var _t: float = 0.0
var _streets: Dictionary = {}
const CAR_NAMES: Array = ["car_a", "car_b", "car_c", "car_d", "car_e", "car_f", "bus", "truck"]


func reset() -> void :
	agents.clear()
	_streets.clear()


func _street_cells(c: City) -> Array:
	if _streets.has(c.id):
		return _streets[c.id]
	var out: Array = []
	var r: int = c.radius + 2
	for y in range(c.center.y - r, c.center.y + r + 1):
		for x in range(c.center.x - r, c.center.x + r + 1):
			if gw.data.inside(x, y) and gw.data.has_flag(x, y, WorldData.F_ROAD) and not gw.data.has_flag(x, y, WorldData.F_BRIDGE):
				out.append(Vector2i(x, y))
	_streets[c.id] = out
	return out


func _road(c: Vector2i) -> bool:
	return gw.road_ok(c)


func _process(delta: float) -> void :
	if gw == null or gw.data == null or gw.camera == null:
		return
	var dt: float = delta * gw.time_scale


	var cdt: float = delta * FxLayer.cosmetic_scale(gw.time_scale)
	var z: float = gw.camera.zoom.x
	_t -= delta
	if _t <= 0.0:
		_t = 1.0
		_populate(z)
	if not gw.net_driven:
		_fire_brigades()
	for k in range(agents.size() - 1, -1, -1):
		var a: Dictionary = agents[k]
		match int(a["type"]):
			0, 1:
				_wander(a, cdt)
			2, 3:
				if not gw.net_driven and not _drive(a, dt):
					agents.remove_at(k)
	queue_redraw()




func sim_trucks(dt: float) -> void :
	_fire_brigades()
	for k in range(agents.size() - 1, -1, -1):
		var a: Dictionary = agents[k]
		var ty: int = a["type"]
		if (ty == 2 or ty == 3) and not _drive(a, dt):
			agents.remove_at(k)


func _populate(z: float) -> void :
	var view: = Rect2(gw.camera.position - gw.camera.view_size() * 0.5 / z, gw.camera.view_size() / z).grow(40)
	var close: bool = z >= 1.5
	var have: Dictionary = {}
	for k in range(agents.size() - 1, -1, -1):
		var a: Dictionary = agents[k]
		var ty: int = a["type"]
		if ty <= 1 and ( not close or not view.has_point(a["pos"])):
			agents.remove_at(k)
			continue
		if ty <= 1 and _hot(int(a["city"])):


			if not a.has("leave"):
				a["leave"] = FxLayer.vt + 0.5 + float(Hash32.h2(int(a["phase"]), k, 3) % 40) * 0.1
			elif FxLayer.vt >= float(a["leave"]):
				agents.remove_at(k)
			continue
		var key: String = "%d:%d" % [int(a["city"]), ty] if not a.has("mil") else "%d:m%d" % [int(a["city"]), int(a["mil"])]
		have[key] = int(have.get(key, 0)) + 1
	if not close:
		return
	for c: City in gw.cities:
		var cp: = Vector2(c.center * GameWorld.CELL)
		if not view.grow(c.radius * GameWorld.CELL).has_point(cp):
			continue
		if _hot(c.id):
			continue
		var st: Array = _street_cells(c)
		if st.is_empty():
			continue
		var cars: int = MAX_CARS[c.kind] if c.powered else MAX_CARS[c.kind] / 3
		var peds: int = MAX_PEDS[c.kind]
		var hc: int = 0
		while int(have.get("%d:0" % c.id, 0)) < cars and hc < 4:
			_spawn(c, 0, st)
			have["%d:0" % c.id] = int(have.get("%d:0" % c.id, 0)) + 1
			hc += 1
		hc = 0
		while int(have.get("%d:1" % c.id, 0)) < peds and hc < 4:
			_spawn(c, 1, st)
			have["%d:1" % c.id] = int(have.get("%d:1" % c.id, 0)) + 1
			hc += 1
		if WL.front_line(gw, c):

			var kk: int = clampi(c.kind, 0, 2)
			var want: Array = [int(WL.VOL[kk]), int(WL.VOL[kk]), int(WL.AMB[kk])]
			want[0] = (want[0] + 1) / 2
			want[1] = want[1] / 2 + (c.id % 2 if want[1] %2 == 1 else 0)
			for mk in 3:
				if int(have.get("%d:m%d" % [c.id, mk], 0)) < int(want[mk]):
					_spawn(c, 0, st)
					var na: Dictionary = agents[agents.size() - 1]
					na["mil"] = mk
					na["spr"] = String(WL.KINDS[mk])
					have["%d:m%d" % [c.id, mk]] = int(have.get("%d:m%d" % [c.id, mk], 0)) + 1



func _hot(cid: int) -> bool:
	return gw.aftermath != null and cid >= 0 and cid < gw.cities.size() and gw.aftermath.city_hot(gw.cities[cid])


func _spawn(c: City, ty: int, st: Array) -> void :
	var h: int = Hash32.h2(c.id, agents.size() * 31 + int(gw.game_time * 7.0), 77)
	var cell: Vector2i = st[h % st.size()]
	var spr: String = String(CAR_NAMES[(h >> 5) % CAR_NAMES.size()]) if ty == 0 else ("ped_a" if (h >> 7) % 2 == 0 else "ped_b")
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var dir: Vector2i = dirs[(h >> 3) % 4]

	for k in 4:
		var dk: Vector2i = dirs[((h >> 3) + k) % 4]
		if _road(cell + dk):
			dir = dk
			break
	var side: = Vector2(float((h >> 9) % 2) * 3.0 - 1.5, 0) if ty == 1 else Vector2.ZERO
	agents.append({"city": c.id, "type": ty, "pos": Vector2(cell * GameWorld.CELL) + Vector2(2, 2), "dir": dir, "cell": cell, "spr": spr, "t": 0.0, "phase": h % 100, "side": side})



func _wander(a: Dictionary, dt: float) -> void :
	var spd: float = CAR_SPEED if int(a["type"]) == 0 else PED_SPEED
	if a.has("leave"):
		spd *= 2.0
	var cell: Vector2i = a["cell"]
	var dir: Vector2i = a["dir"]
	var target: = Vector2((cell + dir) * GameWorld.CELL) + Vector2(2, 2)
	var pos: Vector2 = a["pos"]
	var to: Vector2 = target - pos
	var step: float = spd * dt
	if to.length() <= step:
		a["pos"] = target
		cell = cell + dir
		a["cell"] = cell
		var opts: Array[Vector2i] = []
		for d: Vector2i in [dir, Vector2i(dir.y, dir.x), Vector2i( - dir.y, - dir.x)]:
			if _road(cell + d):
				opts.append(d)
		if opts.is_empty():
			a["dir"] = - dir
		else:
			var h: int = Hash32.h2(cell.x, cell.y, int(a["phase"]) + int(gw.game_time))
			a["dir"] = opts[0] if (h % 4 != 0 or opts.size() == 1) else opts[1 + h % (opts.size() - 1)]
		if not _road(cell):
			a["dir"] = - dir
	else:
		a["pos"] = pos + to / to.length() * step










const TRUCK_CAP: Array = [3, 2, 1]
const POLICE_CAP: Array = [2, 1, 0]
const INCIDENT_R: float = 48.0
const INCIDENT_BIG: int = 4
var w29: Dictionary = {"trucks": 0, "police": 0, "out": 0, "chained": 0, "no_way": 0, "held": 0, "recalled": 0}






const WAY_PER_TICK: int = 2
var _way_left: int = WAY_PER_TICK


func _fire_brigades() -> void :
	_way_left = WAY_PER_TICK
	var now: float = gw.game_time
	var crews: Dictionary = {}
	var busy: Array = []
	for a: Dictionary in agents:
		var ty: int = a["type"]
		if ty != 2 and ty != 3:
			continue
		var cr0: Array = crews.get(int(a["city"]), [0, 0])
		cr0[ty - 2] = int(cr0[ty - 2]) + 1
		crews[int(a["city"])] = cr0
		if int(a["stage"]) != 2 and _hot(int(a["city"])):
			_recall(a)
			continue
		if ty == 2 and int(a["stage"]) <= 1 and a["fire"] != null:
			busy.append(a)
	for f: Dictionary in gw.fires:
		if bool(f["truck"]) or int(f["city"]) < 0 or float(f["until"]) <= now:
			continue
		if _hot(int(f["city"])):
			w29["held"] = int(w29["held"]) + 1
			continue
		var c: City = gw.cities[int(f["city"])]
		var cc: Country = gw.country_by_id(c.country_id)
		if cc == null:
			continue
		var fp: Vector2 = f["p"]
		var at: int = 0
		for a2: Dictionary in busy:
			if int(a2["city"]) == c.id and (a2["fire"]["p"] as Vector2).distance_to(fp) <= INCIDENT_R:
				at += 1
		if at >= 2 or (at == 1 and _incident_n(c.id, fp) < INCIDENT_BIG):
			continue
		var back: Dictionary = {}
		for a3: Dictionary in agents:
			if int(a3["type"]) == 2 and int(a3["city"]) == c.id and int(a3["stage"]) == 2:
				back = a3
				break
		if not back.is_empty():
			if _send_crew(back, f):
				busy.append(back)
			continue
		var cr: Array = crews.get(c.id, [0, 0])
		if int(cr[0]) >= int(TRUCK_CAP[clampi(c.kind, 0, 2)]):
			continue
		var home: = Vector2(c.entrance * GameWorld.CELL) + Vector2(2, 2)
		var a4: Dictionary = {"city": c.id, "type": 2, "pos": home, "dest": home, "home": home, "fire": null, "t": 0.0, "spr": "fire_truck", "phase": 0, "stage": 0}
		if not _send_crew(a4, f):
			continue
		agents.append(a4)
		busy.append(a4)
		cr[0] = int(cr[0]) + 1
		w29["trucks"] = int(w29["trucks"]) + 1
		if at == 0 and int(cr[1]) < int(POLICE_CAP[clampi(c.kind, 0, 2)]):
			var dest: Vector2 = (a4["wp"] as PackedVector2Array)[(a4["wp"] as PackedVector2Array).size() - 1]
			var pp: Vector2 = home - (dest - home).normalized() * 10.0
			if gw.army == null or gw.army.ground_at(pp) != 1:
				pp = home
			var pw: PackedVector2Array = (a4["wp"] as PackedVector2Array).duplicate()
			pw[pw.size() - 1] = dest + Vector2(8, 6)
			if gw.aftermath != null and not gw.aftermath._clear(pw[pw.size() - 2] if pw.size() >= 2 else pp, pw[pw.size() - 1]):
				pw[pw.size() - 1] = dest + Vector2(3, 3)
				if not gw.aftermath._clear(pw[pw.size() - 2] if pw.size() >= 2 else pp, pw[pw.size() - 1]):
					pw[pw.size() - 1] = (a4["wp"] as PackedVector2Array)[pw.size() - 1]
			agents.append({"city": c.id, "type": 3, "pos": pp, "dest": pw[0], "wp": pw, "wi": 0, "home": home, "fire": null, "t": 0.0, "spr": "police_car", "phase": 1, "stage": 0})
			cr[1] = int(cr[1]) + 1
			w29["police"] = int(w29["police"]) + 1
		crews[c.id] = cr



func _incident_n(cid: int, p: Vector2) -> int:
	var n: int = 0
	for f: Dictionary in gw.fires:
		if int(f["city"]) == cid and not bool(f["truck"]) and float(f["until"]) > gw.game_time and (f["p"] as Vector2).distance_to(p) <= INCIDENT_R:
			n += 1
	return n




func _send_crew(a: Dictionary, f: Dictionary) -> bool:
	var from: Vector2 = a["pos"]
	var dest: Vector2 = (f["p"] as Vector2) + Vector2(6, 4)
	if gw.aftermath != null and not gw.aftermath._free(gw.aftermath._cell(dest)):
		var sd: Vector2 = gw.aftermath._snap(dest)
		if sd != Vector2.INF:
			dest = sd
	if gw.aftermath == null or not gw.aftermath._clear(from, dest):
		if _way_left <= 0:
			return false
		_way_left -= 1
	var wp: PackedVector2Array = _way(from, dest)
	if wp.is_empty():
		w29["no_way"] = int(w29["no_way"]) + 1
		return false
	f["truck"] = true
	a["fire"] = f
	a["wp"] = wp
	a["wi"] = 0
	a["dest"] = wp[0]
	a["stage"] = 0
	a["t"] = 0.0
	return true




func _way(a: Vector2, b: Vector2) -> PackedVector2Array:
	if gw.aftermath != null:


		var fw: PackedVector2Array = gw.aftermath._way(a, b)
		if not fw.is_empty():
			return fw
	var dry: bool = true
	if gw.army != null:
		var n: int = maxi(1, int(a.distance_to(b) / 3.0))
		for k in range(1, n + 1):
			if gw.army.ground_at(a.lerp(b, float(k) / float(n))) != 1:
				dry = false
				break
	if dry:
		return PackedVector2Array([b])
	var p: PackedVector2Array = gw.econ.nav_path(a, b) if gw.econ != null else PackedVector2Array()
	if gw.econ == null or not gw.econ.nav_last_ok or p.is_empty():
		return PackedVector2Array()
	p[p.size() - 1] = b
	return p




func _recall(a: Dictionary) -> void :
	if a["fire"] != null:
		a["fire"]["truck"] = false
		a["fire"] = null
	w29["recalled"] = int(w29["recalled"]) + 1
	if int(a["stage"]) == 0 and a.has("wp"):

		var wp0: PackedVector2Array = a["wp"]
		var keep: PackedVector2Array = wp0.slice(0, clampi(int(a.get("wi", 0)), 0, wp0.size()))
		keep.append(a["pos"])
		a["wp"] = keep
	_go_home(a)



func _next_fire(a: Dictionary) -> Dictionary:
	if _hot(int(a["city"])):
		return {}
	var best: Dictionary = {}
	var bd: float = INF
	var pos: Vector2 = a["pos"]
	for f: Dictionary in gw.fires:
		if int(f["city"]) != int(a["city"]) or bool(f["truck"]) or float(f["until"]) <= gw.game_time:
			continue
		var d: float = (f["p"] as Vector2).distance_squared_to(pos)
		if d < bd:
			bd = d
			best = f
	return best



func _drive(a: Dictionary, dt: float) -> bool:
	var pos: Vector2 = a["pos"]
	var stage: int = a["stage"]
	if stage == 1:
		a["t"] = float(a["t"]) + dt
		if float(a["t"]) >= SPRAY_TIME:
			if a["fire"] != null:
				gw.extinguish(a["fire"])
				w29["out"] = int(w29["out"]) + 1
			var nf: Dictionary = _next_fire(a)
			if not nf.is_empty() and _send_crew(a, nf):
				w29["chained"] = int(w29["chained"]) + 1
				return true
			_go_home(a)
		return true
	var dest: Vector2 = a["dest"]
	var to: Vector2 = dest - pos
	var step: float = TRUCK_SPEED * dt
	if to.length() <= step:
		a["pos"] = dest
		var wp: PackedVector2Array = a.get("wp", PackedVector2Array())
		var wi: int = int(a.get("wi", 0)) + 1
		if wi < wp.size():
			a["wi"] = wi
			a["dest"] = wp[wi]
			return true
		if stage == 0:
			a["stage"] = 1 if int(a["type"]) == 2 else 3
			a["t"] = 0.0
			return true
		return stage == 3 and a["fire"] == null and _police_wait(a, dt)
	a["pos"] = pos + to / to.length() * step
	a["vel"] = to
	return true


func _police_wait(a: Dictionary, dt: float) -> bool:
	a["t"] = float(a["t"]) + dt
	if float(a["t"]) > 7.0:
		_go_home(a)
	return true



func _go_home(a: Dictionary) -> void :
	var wp: PackedVector2Array = a.get("wp", PackedVector2Array())
	var back: = PackedVector2Array()
	for k in range(wp.size() - 2, -1, -1):
		back.append(wp[k])
	var last: Vector2 = back[back.size() - 1] if not back.is_empty() else (a["pos"] as Vector2)
	if gw.aftermath != null and not gw.aftermath._clear(last, a["home"]):

		back.append_array(gw.aftermath._way(last, a["home"]))
	if back.is_empty() or back[back.size() - 1] != (a["home"] as Vector2):
		back.append(a["home"])
	a["wp"] = back
	a["wi"] = 0
	a["dest"] = back[0]
	a["stage"] = 2


func _draw() -> void :
	if gw == null or gw.camera == null or gw.camera.zoom.x < 1.5:
		return
	var la: SpriteAtlas = gw.life_atlas
	var t: float = FxLayer.vt
	for a: Dictionary in agents:
		var ty: int = a["type"]
		var pos: Vector2 = (a["pos"] as Vector2)
		var v: = Vector2.ZERO
		if ty <= 1:
			v = Vector2(a["dir"])
			pos += a.get("side", Vector2.ZERO)
			if ty == 0:

				pos += Vector2( - v.y, v.x) * 0.0 + Vector2(v.y, - v.x) * -1.0
		else:
			v = a.get("vel", Vector2(1, 0))
			if int(a["stage"]) == 1 or int(a["stage"]) == 3:
				v = (a["fire"]["p"] - pos) if a["fire"] != null else Vector2(1, 0)
		var base: String = a["spr"]
		var dname: String
		var flip: bool = false
		if absf(v.x) >= absf(v.y):
			dname = "_e"
			flip = v.x < 0.0
		else:
			dname = "_s" if v.y > 0.0 else "_n"
		if ty == 1 and dname == "_e" and (a.has("leave") or (Hash32.h2(int(a["phase"]), 0, 0) % 5 == 0 and gw.fires.size() > 0)):
			dname = "_run_e"
		if a.has("mil"):
			_draw_mil(a, pos, dname, flip, t)
			continue
		var n: String = base + dname
		if not la.has(n):
			n = base + "_e"
		var info: Dictionary = la.info(n)
		var nf: int = int(info.get("frames", 1))
		var fr: int = 0
		if nf > 1:
			fr = int(t * float(info.get("fps", 6))) % nf
		var r: Rect2 = la.rect(n, fr)
		var tl: Vector2 = pos.round() - Vector2(float(info["ax"]), float(info["ay"]))
		var sz: Vector2 = r.size
		if flip:
			tl.x += sz.x - 1.0
			sz.x = - sz.x
		_draw_clipped(la.texture, tl, sz, r, flip, a)
		if ty == 2 and int(a["stage"]) == 1 and a["fire"] != null:
			_spray(pos, a["fire"]["p"], t)


const WL = preload("res://world/war_life.gd")




func _draw_mil(a: Dictionary, pos: Vector2, dname: String, flip: bool, t: float) -> void :
	var tx: ImageTexture = WL.tex(String(a["spr"]), dname)
	if tx == null:
		return
	var sz: = Vector2(tx.get_size())
	var tl: Vector2 = pos.round() - (sz * 0.5).floor()
	var r: = Rect2(Vector2.ZERO, sz)
	var dsz: Vector2 = sz
	if flip:
		tl.x += sz.x - 1.0
		dsz.x = - sz.x
	_draw_clipped(tx, tl, dsz, r, flip, a)
	if int(a["mil"]) == 2:
		var bp: Vector2 = WL.beacon(dname)
		if flip:
			bp.x = sz.x - 1.0 - bp.x
		var on: bool = int(t * 3.0 + float(int(a["phase"]) % 7) * 0.3) % 2 == 0
		var bpos: Vector2 = pos.round() - (sz * 0.5).floor() + bp
		if flip:
			bpos.x -= 1.0
		draw_rect(Rect2(bpos, Vector2.ONE), Palette.c("water_mid") if on else Palette.c("water_deep"))
		if on:
			var g: = Palette.c("intercept_cyan")
			g.a = 0.35
			draw_rect(Rect2(bpos - Vector2(1, 1), Vector2(3, 3)), g)





func _draw_clipped(tex: Texture2D, tl: Vector2, sz: Vector2, r: Rect2, flip: bool, a: Dictionary) -> void :
	var ol: ObjectsLayer = gw.objects
	var w: int = int(absf(sz.x))
	var h: int = int(sz.y)
	var x0: int = int(tl.x + sz.x) if flip else int(tl.x)
	var y0: int = int(tl.y)
	var foot: int = y0 + h - 1
	var tops: = PackedInt32Array()
	if ol != null:

		var cv: Array = a.get("_cv", [])
		if cv.size() == 5 and int(cv[0]) == x0 and int(cv[1]) == foot and int(cv[2]) == w and int(cv[3]) == ol.cover_ver:
			tops = cv[4]
		else:
			tops = ol.cover_span(x0, w, foot)
			a["_cv"] = [x0, foot, w, ol.cover_ver, tops]
	var cut: = PackedInt32Array()
	var any: bool = false
	if not tops.is_empty():
		cut.resize(w)
		for k in w:
			cut[k] = clampi(tops[k] - y0, 0, h)
			if cut[k] < h:
				any = true
	if not any:
		draw_texture_rect_region(tex, Rect2(tl, sz), r)
		return
	for k in w:
		var vh: int = cut[k]
		if vh <= 0:
			continue
		var sx: float = r.position.x + float(w - 1 - k if flip else k)
		draw_texture_rect_region(tex, Rect2(x0 + k, y0, 1, vh), Rect2(sx, r.position.y, 1, vh))



func _spray(from: Vector2, to: Vector2, t: float) -> void :
	var col: = Palette.c("water_coast")
	var col2: = Palette.c("white")
	for i in 10:
		var k: float = fmod(float(i) / 10.0 + t * 1.6, 1.0)
		var p: Vector2 = from.lerp(to + Vector2(0, -3), k) + Vector2(0, - sin(k * PI) * 6.0)
		draw_rect(Rect2(p.round(), Vector2(1, 1)), col if i % 3 else col2)
