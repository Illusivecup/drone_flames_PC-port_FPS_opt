class_name Ports
extends RefCounted






const K: int = 4
const SHIP_SPEED: float = 18.0
const SHIP_LOAD: int = 30
const MAX_CRANES: int = 3
const LOAD_TIME: float = 8.0
const MIN_SEA: int = 40
const EXPORT_AT: float = 0.55
const PORT_REACH: int = 16

const SEG: int = 5
const MAX_SEGS: int = 8
const SEG_VALUE: int = 1200
const SEG_TYPES: Array[String] = ["port_seg_quay", "port_seg_yard", "port_seg_wh", "port_seg_yard"]
const GROW_DT: float = 20.0
const LOD_DT: float = 0.25

var gw: GameWorld
var econ: Economy
var sea: AStarGrid2D
var body: PackedInt32Array = PackedInt32Array()
var body_size: Dictionary = {}
var body_edge: Dictionary = {}
var ships: Array = []
var exported: Dictionary = {}
var no_site: Dictionary = {}
var queue: Dictionary = {}
var _state: Dictionary = {}
var _id: int = 1
var _w: int = 0
var _h: int = 0
var _grow_t: float = 0.0
var _no_grow: Dictionary = {}


func _init(world: GameWorld, e: Economy) -> void :
	gw = world
	econ = e





func ensure_sea() -> void :
	if sea != null:
		return
	var t0: int = Time.get_ticks_msec()
	var d: WorldData = gw.data
	_w = d.w / K
	_h = d.h / K
	sea = AStarGrid2D.new()
	sea.region = Rect2i(0, 0, _w, _h)
	sea.cell_size = Vector2(K * GameWorld.CELL, K * GameWorld.CELL)
	sea.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	sea.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	sea.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	sea.update()
	var water: = PackedByteArray()
	water.resize(_w * _h)
	for y in _h:
		for x in _w:
			var n: int = 0
			for yy in range(y * K, y * K + K, 2):
				for xx in range(x * K, x * K + K, 2):
					if Biome.is_water(d.biome[yy * d.w + xx]):
						n += 1
			if n >= 3:
				water[y * _w + x] = 1
			else:
				sea.set_point_solid(Vector2i(x, y), true)
	body.resize(_w * _h)
	body.fill(0)
	var bid: int = 0
	var queue: = PackedInt32Array()
	for i in _w * _h:
		if water[i] == 0 or body[i] != 0:
			continue
		bid += 1
		body[i] = bid
		queue.clear()
		queue.append(i)
		var qi: int = 0
		var edges: Array = []
		while qi < queue.size():
			var j: int = queue[qi]
			qi += 1
			var x: int = j % _w
			var y: int = j / _w
			if x == 0 or y == 0 or x == _w - 1 or y == _h - 1:
				edges.append(Vector2i(x, y))
			for dd: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + dd.x
				var ny: int = y + dd.y
				if nx < 0 or ny < 0 or nx >= _w or ny >= _h:
					continue
				var nj: int = ny * _w + nx
				if water[nj] == 1 and body[nj] == 0:
					body[nj] = bid
					queue.append(nj)
		body_size[bid] = queue.size()
		body_edge[bid] = edges
	print("[Ports] sea grid %dx%d, %d water bodies in %d ms" % [_w, _h, bid, Time.get_ticks_msec() - t0])


func _body_at(q: Vector2i) -> int:
	if q.x < 0 or q.y < 0 or q.x >= _w or q.y >= _h:
		return 0
	var b: int = body[q.y * _w + q.x]
	return b if b > 0 and int(body_size.get(b, 0)) >= MIN_SEA else 0


func cell_px(q: Vector2i) -> Vector2:
	var k: float = float(K * GameWorld.CELL)
	return Vector2(q) * k + Vector2(k * 0.5, k * 0.5)



func berth_for(nw: Vector2i, sz: Vector2i) -> Vector2i:
	ensure_sea()
	var c0: = Vector2i((nw.x + sz.x / 2) / K, (nw.y + sz.y / 2) / K)
	var rr: int = maxi(sz.x, sz.y) / K / 2 + 3
	var best: = Vector2i(-1, -1)
	var bd: int = 1 << 30
	for dy in range( - rr, rr + 1):
		for dx in range( - rr, rr + 1):
			var q: = c0 + Vector2i(dx, dy)
			if _body_at(q) == 0:
				continue
			var dd: int = dx * dx + dy * dy
			if dd < bd:
				bd = dd
				best = q
	return best



func coastal(nw: Vector2i, sz: Vector2i) -> bool:
	var d: WorldData = gw.data
	var n: int = 0
	for y in range(nw.y - 2, nw.y + sz.y + 2):
		for x in range(nw.x - 2, nw.x + sz.x + 2):
			if x >= nw.x and x < nw.x + sz.x and y >= nw.y and y < nw.y + sz.y:
				continue
			if d.inside(x, y) and Biome.is_water(d.get_biome(x, y)):
				n += 1
	if n < 4:
		return false
	return berth_for(nw, sz).x >= 0




func on_port_built(f: Facility) -> void :
	_port_state(f)


func _port_state(f: Facility) -> Dictionary:
	if _state.has(f):
		return _state[f]
	var st: Dictionary = {"berth": berth_for(f.cell, f.size), "body": 0, "edge": Vector2i(-1, -1)}
	var b: Vector2i = st["berth"]
	if b.x >= 0:
		st["body"] = _body_at(b)
		var best: = Vector2i(-1, -1)
		var bd: int = 1 << 30
		for e: Vector2i in body_edge.get(int(st["body"]), []):
			var dd: int = (e - b).length_squared()
			if dd < bd:
				bd = dd
				best = e
		st["edge"] = best
	_state[f] = st
	return st


func port_of(c: Country) -> Facility:
	if c == null:
		return null
	var first: Facility = null
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.PORT and f.country_id == c.id and gw.mil.alive(f) and (_port_state(f)["berth"] as Vector2i).x >= 0:
			if gw.supply == null or not gw.supply.port_blockaded(f):
				return f
			if first == null:
				first = f
	return first



func blocked(c: Country) -> bool:
	return gw.supply != null and gw.supply.port_blockaded(port_of(c))


func has_port(c: Country) -> bool:
	return port_of(c) != null


func nearest_port(c: Country, cell: Vector2i, reach: int = PORT_REACH) -> Facility:
	var best: Facility = null
	var bd: int = 1 << 30
	for f: Facility in gw.mil.facilities:
		if f.kind != Facility.Kind.PORT or f.country_id != c.id or not gw.mil.alive(f):
			continue
		var m: Vector2i = f.cell + f.size / 2
		var dd: int = maxi(absi(m.x - cell.x), absi(m.y - cell.y))
		if dd <= reach + f.size.x / 2 and dd < bd:
			bd = dd
			best = f
	return best


func crane_count(p: Facility) -> int:
	var n: int = 0
	for m: Facility in p.modules:
		if m.kind == Facility.Kind.PORT_CRANE and gw.mil.alive(m):
			n += 1
	return n



func capacity(p: Facility) -> int:
	return 1 + crane_count(p) + seg_count(p) / 2


func active(p: Facility) -> int:
	var n: int = 0
	for s: Dictionary in ships:
		if s["port"] == p:
			n += 1
	return n


func load_of(p: Facility) -> int:
	return SHIP_LOAD + 10 * crane_count(p)



func ocean(p: Facility) -> bool:
	return p != null and (_port_state(p)["edge"] as Vector2i).x >= 0



func container_units(c: Country) -> int:
	var have: float = 0.0
	var cap: float = 0.0
	for res: String in Economy.RAW + ["goods"]:
		have += float(int(c.get(res)))
		cap += float(econ.res_cap(c, res))
	return clampi(roundi(36.0 * have / maxf(1.0, cap) * 1.6), 0, 36)


func info(p: Facility) -> Dictionary:
	var c: Country = gw.country_by_id(p.country_id)
	return {"ships": active(p), "ships_max": capacity(p), "cranes": crane_count(p), "load": load_of(p), 
		"ocean": ocean(p), "sea": (_port_state(p)["berth"] as Vector2i).x >= 0, "export_on": not econ.export_off.has(p.country_id), 
		"exported": int(exported.get(p.country_id, 0)), "containers": container_units(c), "segments": seg_count(p), 
		"segments_max": MAX_SEGS, "length_m": length_of(p), "next_segment_at": next_seg_value(p), "trade_value": trade_value(c)}




func can_sail(a: Country, b: Country) -> bool:
	var pa: Facility = port_of(a)
	var pb: Facility = port_of(b)
	if gw.supply != null and (gw.supply.port_blockaded(pa) or gw.supply.port_blockaded(pb)):
		return false
	return pa != null and pb != null and int(_port_state(pa)["body"]) == int(_port_state(pb)["body"]) and int(_port_state(pa)["body"]) > 0


func sea_dist(a: Country, b: Country) -> float:
	var pa: Facility = port_of(a)
	var pb: Facility = port_of(b)
	if pa == null or pb == null:
		return INF
	return cell_px(_port_state(pa)["berth"]).distance_to(cell_px(_port_state(pb)["berth"])) * 1.3



func send_trade(s: Country, r: Country, res: String, n: int, price: int) -> bool:
	if not can_sail(s, r):
		return false
	var pa: Facility = port_of(s)
	var pb: Facility = port_of(r)
	var path: PackedVector2Array = _path(_port_state(pa)["berth"], _port_state(pb)["berth"])
	if path.is_empty():
		return false
	return _spawn(pa, "trade", s.id, r.id, res, n, price, path, true)



func import_order(buyer: Country, res: String, n: int) -> String:
	var p: Facility = port_of(buyer)
	if p == null:
		return Loc.t("Нужен порт на берегу моря")
	if not ocean(p):
		return Loc.t("Из порта нет выхода в океан")
	if blocked(buyer):
		return Loc.t("Порт в блокаде: суда не заходят")
	var busy: bool = active(p) >= capacity(p)
	if busy and (queue.get(buyer.id, []) as Array).size() >= 3:
		return Loc.t("Очередь импорта полна: постройте кран")
	n = mini(n, mini(load_of(p), econ.room_for(buyer, res)))
	if n <= 0:
		return Loc.t("Склад полон: %s (лимит %d)") % [Loc.t(String(Economy.RES_NAMES[res]).to_lower()), econ.res_cap(buyer, res)]
	var unit: int = econ.foreign_buy_price(res, buyer.id)
	if buyer.money < unit:
		return Loc.t("Не хватает денег: %d за ед.") % unit
	n = mini(n, buyer.money / unit)
	var price: int = unit * n
	var st: Dictionary = _port_state(p)
	var path: PackedVector2Array = _path(st["edge"], st["berth"])
	if path.is_empty():
		return Loc.t("Нет морского пути")
	buyer.money -= price
	econ.stat_add(buyer, "spend", "import", price)
	if econ.upk != null:
		econ.upk.note_trade(buyer.id, res, - n, unit)
	if busy:

		if not queue.has(buyer.id):
			queue[buyer.id] = []
		(queue[buyer.id] as Array).append({"res": res, "n": n, "price": price})
		if buyer.is_player:
			gw.say(buyer, Loc.mk("Импорт оплачен: %s %d — привезёт ближайший корабль", [Loc.t(String(Economy.RES_NAMES[res]).to_lower()), n]))
		return ""
	if not _spawn(p, "import", 0, buyer.id, res, n, price, path, false):
		buyer.money += price
		return Loc.t("Нет морского пути")
	if buyer.is_player:
		gw.say(buyer, Loc.mk("Импорт: %s %d за %d — корабль в пути", [Loc.t(String(Economy.RES_NAMES[res]).to_lower()), n, price]))
	return ""




func export_order(seller: Country, res: String, n: int) -> String:
	var p: Facility = port_of(seller)
	if p == null:
		return Loc.t("Нужен порт на берегу моря")
	if not ocean(p):
		return Loc.t("Из порта нет выхода в океан")
	if blocked(seller):
		return Loc.t("Порт в блокаде: суда не выходят")
	if active(p) >= capacity(p):
		return Loc.t("Все причалы заняты: постройте кран")
	n = mini(mini(n, load_of(p)), int(seller.get(res)))
	if n <= 0:
		return Loc.t("Нечего продавать: %s") % Loc.t(String(Economy.RES_NAMES[res]).to_lower())
	var st: Dictionary = _port_state(p)
	var path: PackedVector2Array = _path(st["berth"], st["edge"])
	if path.is_empty():
		return Loc.t("Нет морского пути")
	seller.set(res, int(seller.get(res)) - n)
	econ.stat_res(seller, res, "export", - n)
	_spawn(p, "export", seller.id, 0, res, n, 0, path, true)
	return ""



func _refund_queue(c: Country) -> void :
	var q: Array = queue.get(c.id, [])
	for o: Dictionary in q:
		c.money += int(o["price"])
		econ.stat_add(c, "spend", "import", - int(o["price"]))
	if not q.is_empty() and c.is_player:
		gw.say(c, Loc.mk("Порта нет: оплаченный импорт возвращён (%d)", [q.size()]))
	queue.erase(c.id)



func export_tick() -> void :
	for c: Country in gw.countries:
		if c.eliminated or c.capital_id < 0 or econ.export_off.has(c.id):
			continue
		var p: Facility = port_of(c)
		if p == null or not ocean(p):
			if queue.has(c.id):
				_refund_queue(c)
			continue
		if active(p) >= capacity(p) or blocked(c):
			continue
		var q: Array = queue.get(c.id, [])
		if not q.is_empty():
			var o: Dictionary = q.pop_front()
			var st: Dictionary = _port_state(p)
			if not _spawn(p, "import", 0, c.id, String(o["res"]), int(o["n"]), int(o["price"]), _path(st["edge"], st["berth"]), false):
				c.money += int(o["price"])
			elif bool(o.get("mkt", false)) and not ships.is_empty():
				(ships[ships.size() - 1] as Dictionary)["mkt"] = true
			continue
		var best: String = ""
		var best_v: float = 0.0
		for res: String in Economy.TRADE_RES:
			var floor_n: int = maxi(econ.keep(c, res), int(econ.res_cap(c, res) * EXPORT_AT))
			var extra: int = int(c.get(res)) - floor_n
			if extra >= 10 and extra * econ.market_price(res) > best_v:
				best_v = extra * econ.market_price(res)
				best = res
		if best != "":
			var floor_b: int = maxi(econ.keep(c, best), int(econ.res_cap(c, best) * EXPORT_AT))
			export_order(c, best, int(c.get(best)) - floor_b)




func _path(a: Vector2i, b: Vector2i) -> PackedVector2Array:
	var out: = PackedVector2Array()
	if sea == null or a.x < 0 or b.x < 0:
		return out


	var key: = Vector4i(a.x, a.y, b.x, b.y)
	var pc: Dictionary = gw.supply.pcache if gw.supply != null else {}
	var ver: int = 0
	var ce: Array = pc.get(key, [])
	if not ce.is_empty() and int(ce[0]) == ver and gw.game_time - float(ce[1]) < 240.0:
		return ce[2]
	var ids: Array[Vector2i] = sea.get_id_path(a, b, false)
	for q: Vector2i in ids:
		out.append(cell_px(q))
	if pc.size() >= 160:
		pc.clear()
	pc[key] = [ver, gw.game_time, out]
	return out


func _spawn(p: Facility, kind: String, from: int, to: int, res: String, n: int, price: int, path: PackedVector2Array, load_first: bool) -> bool:
	if path.is_empty():
		return false
	var s: Dictionary = {"id": _id, "port": p, "owner": p.country_id, "kind": kind, "from": from, "to": to, "res": res, "n": n, 
		"price": price, "path": path, "i": 0, "pos": path[0], "heading": 0.0, "frame": 0, "stage": 0 if load_first else 1, 
		"t": LOAD_TIME / float(1 + crane_count(p)), "trail": PackedVector2Array(), "trail_t": 0.0, "hp": Navy.CONVOY_HP}
	_id += 1
	ships.append(s)
	if gw.supply != null:
		gw.supply._lane_offset(s)
	if load_first and gw._on_screen(path[0], 60.0):
		Sfx.play("container_clank", path[0])
	return true


func update(dt: float) -> void :
	_grow_t += dt
	if _grow_t >= GROW_DT:
		_grow_t = 0.0
		_grow_tick()
	for k in range(ships.size() - 1, -1, -1):
		var s: Dictionary = ships[k]

		var sdt: float = dt
		var off: bool = not gw._on_screen(s["pos"], 120.0)



		if off and dt < LOD_DT and not gw.net_driven:
			var acc: float = float(s.get("acc", 0.0)) + dt
			if acc < LOD_DT:
				s["acc"] = acc
				continue
			s["acc"] = 0.0
			sdt = acc
		if int(s["stage"]) == 0:
			s["t"] = float(s["t"]) - sdt
			if float(s["t"]) <= 0.0:
				s["stage"] = 1
				if gw._on_screen(s["pos"], 80.0):
					Sfx.play("ship_horn", s["pos"])
			continue
		var path: PackedVector2Array = s["path"]
		var i: int = s["i"]
		if i >= path.size():
			if int(s["stage"]) == 1:
				_arrive(s)
				var back: = PackedVector2Array(path)
				back.reverse()
				s["path"] = back
				s["i"] = 0
				s["stage"] = 2
				if s.has("base") and gw.supply != null:
					gw.supply.relane(s)
			else:
				if bool(s.get("back", false)):
					_deliver_back(s)
				ships.remove_at(k)
			continue
		var pos: Vector2 = s["pos"]
		var to: Vector2 = path[i] - pos
		var step: float = SHIP_SPEED * sdt * (1.6 if float(s.get("evade_until", -1.0)) > gw.game_time else 1.0) * maxf(float(s.get("spf", 1.0)), 0.3 if float(s.get("evade_until", -1.0)) > gw.game_time else 0.0)
		if to.length() <= step:
			s["pos"] = path[i]
			s["i"] = i + 1
		else:
			s["pos"] = pos + to.normalized() * step
			var want: float = to.angle()
			var hd: float = float(s["heading"])

			hd = want if off and not gw.net_driven else hd + clampf(wrapf(want - hd, - PI, PI), - sdt * 1.6, sdt * 1.6)
			s["heading"] = hd
			s["frame"] = posmod(roundi(rad_to_deg(hd) / 22.5), 16)
		if off:
			if not (s["trail"] as PackedVector2Array).is_empty():
				s["trail"] = PackedVector2Array()
			continue
		s["trail_t"] = float(s["trail_t"]) + sdt
		if float(s["trail_t"]) >= 0.35:
			s["trail_t"] = 0.0
			var tr: PackedVector2Array = s["trail"]
			tr.append(s["pos"])
			if tr.size() > 10:
				tr.remove_at(0)
			s["trail"] = tr


func _arrive(s: Dictionary) -> void :
	var kind: String = s["kind"]
	var res: String = s["res"]
	var n: int = s["n"]
	if kind == "export":
		var c: Country = gw.country_by_id(int(s["from"]))
		if c == null:
			return
		var eu: int = econ.foreign_sell_price(res, c.id)
		var pay: int = eu * n
		if econ.upk != null:
			econ.upk.note_trade(c.id, res, n, eu)
		c.add_money(pay)
		c.trade_income += pay
		exported[c.id] = int(exported.get(c.id, 0)) + pay
		econ.stat_add(c, "income", "export", pay)
		if c.is_player:
			gw.say(c, Loc.mk("Экспорт: %s %d продано за рубеж за %d", [Loc.t(String(Economy.RES_NAMES[res]).to_lower()), n, pay]))
		_backload(s, c)
	elif kind == "import":
		var b: Country = gw.country_by_id(int(s["to"]))
		if b == null:
			return
		b.set(res, int(b.get(res)) + n)
		econ.stat_res(b, res, "import", n)
		if b.is_player and bool(s.get("mkt", false)):
			gw.say(b, Loc.mk("Покупка прибыла: %s +%d из-за рубежа (оплачено %d)", [Loc.t(String(Economy.RES_NAMES[res]).to_lower()), n, int(s.get("price", 0))]))
		elif b.is_player:
			gw.say(b, Loc.mk("Корабль из-за рубежа: %s +%d", [Loc.t(String(Economy.RES_NAMES[res]).to_lower()), n]))
	else:
		econ.complete(s)



func _backload(s: Dictionary, c: Country) -> void :
	s["n"] = 0
	var q: Array = queue.get(c.id, [])
	if not q.is_empty():
		var o: Dictionary = q.pop_front()
		s["res"] = o["res"]
		s["n"] = int(o["n"])
	elif not c.is_player:
		for sh: Array in econ.shortages(c):
			var res: String = sh[0]
			var lack: int = int(sh[1]) - econ.inbound(c, res)
			var unit: int = econ.foreign_buy_price(res, c.id)
			var n: int = mini(mini(lack, load_of(s["port"])), mini((c.money - 400) / unit, econ.room_for(c, res)))
			if n >= 3:
				c.money -= unit * n
				econ.stat_add(c, "spend", "import", unit * n)
				if econ.upk != null:
					econ.upk.note_trade(c.id, res, - n, unit)
				s["res"] = res
				s["n"] = n
				break
	if int(s["n"]) > 0:
		s["back"] = true
		s["to"] = c.id
		s["from"] = 0


func _deliver_back(s: Dictionary) -> void :
	var b: Country = gw.country_by_id(int(s["owner"]))
	if b == null:
		return
	var res: String = s["res"]
	b.set(res, int(b.get(res)) + int(s["n"]))
	econ.stat_res(b, res, "import", int(s["n"]))
	if b.is_player:
		gw.say(b, Loc.mk("Корабль вернулся с грузом: %s +%d", [Loc.t(String(Economy.RES_NAMES[res]).to_lower()), int(s["n"])]))


func inbound(c: Country, res: String) -> int:
	var n: int = 0
	for s: Dictionary in ships:
		if int(s["to"]) == c.id and String(s["res"]) == res and (int(s["stage"]) < 2 or bool(s.get("back", false))):
			n += int(s["n"])
	for o: Dictionary in queue.get(c.id, []):
		if String(o["res"]) == res:
			n += int(o["n"])
	return n



func on_strike(p: Vector2, r_px: float, by: int = 0) -> void :
	for k in range(ships.size() - 1, -1, -1):
		var s: Dictionary = ships[k]
		if (s["pos"] as Vector2).distance_to(p) <= r_px + 10.0:
			sink_ship(s, by)






func sink_ship(s: Dictionary, by: int = 0) -> void :
	var k: int = ships.find(s)
	if k < 0:
		return
	var kind: String = s["kind"]
	var n: int = int(s["n"])
	var value: int = 0
	if int(s["stage"]) < 2 and n > 0:
		if kind == "trade":
			econ.refund(s)
			value = int(s["price"])
		elif kind == "export":
			value = int(econ.market_price(String(s["res"])) * Economy.FOREIGN_SELL) * n
		else:
			value = int(s["price"])
	elif bool(s.get("back", false)) and n > 0:
		value = econ.foreign_buy_price(String(s["res"])) * n
	if gw._on_screen(s["pos"], 60.0):
		gw.fx.spawn("explosion_s", (s["pos"] as Vector2).round(), 6)
	ships.remove_at(k)
	if gw.get("navy") != null:
		gw.navy.on_convoy_sunk(s, by, value)





func find_site(c: Country, step: bool = false) -> Vector2i:
	if gw.game_time - float(no_site.get(c.id, -1000.0)) < 60.0:
		return Vector2i(-1, -1)
	var pend: Array = _site_pend.get(c.id, []) if step else []
	if not pend.is_empty() and float(pend[1]) == gw.game_time:
		return Vector2i(-1, -1)
	ensure_sea()
	var d: WorldData = gw.data


	var ids: Array = c.city_ids
	var nc: int = ids.size()
	var cur: Array = _site_off.get(c.id, [0, 0])
	var start: int = int(cur[0]) % maxi(1, nc)
	var skip: int = int(cur[1])
	var checks: int = int(pend[0]) if not pend.is_empty() else 0
	var n_step: int = 0
	var bio: PackedByteArray = d.biome
	var ow: PackedByteArray = d.owners
	var w: int = d.w
	var h: int = d.h
	for j in nc:
		var city: City = gw.cities[ids[(start + j) % nc]]
		var r: int = city.claim_max + 4
		var k: int = 0
		for y in range(city.center.y - r, city.center.y + r, 3):
			for x in range(city.center.x - r, city.center.x + r, 3):
				if x < 0 or y < 0 or x >= w or y >= h or ow[y * w + x] != c.id or bio[y * w + x] <= Biome.RIVER:
					continue

				var wet: bool = false
				for q: Vector2i in WET_PROBE:
					var qx: int = x + q.x
					var qy: int = y + q.y
					if qx >= 0 and qy >= 0 and qx < w and qy < h and bio[qy * w + qx] <= Biome.RIVER:
						wet = true
						break
				if not wet:
					continue
				k += 1
				if j == 0 and k <= skip:
					continue
				checks += 1
				if checks > SITE_CHECKS:
					_site_off[c.id] = [(start + j) % nc, k - 1 if j == 0 else k - 1]
					_site_pend.erase(c.id)
					no_site[c.id] = gw.game_time - 30.0
					return Vector2i(-1, -1)
				if step and n_step >= SITE_STEP:
					if pend.is_empty():
						pend = [0, 0.0, _site_off.get(c.id, [])]
					_site_off[c.id] = [(start + j) % nc, k - 1 if j == 0 else k - 1]
					_site_pend[c.id] = [checks - 1, gw.game_time, pend[2]]
					return Vector2i(-1, -1)
				n_step += 1
				var cen: = Vector2i(x, y)
				if gw.supply != null and gw.supply.alt_avoid(c, cen):
					continue
				if gw.mil.check_place(Facility.Kind.PORT, Military.nw_for(Facility.Kind.PORT, cen), c, null, false) == "":
					if not pend.is_empty():
						_site_pend.erase(c.id)
						if (pend[2] as Array).is_empty():
							_site_off.erase(c.id)
						else:
							_site_off[c.id] = pend[2]
					return cen
	_site_off.erase(c.id)
	_site_pend.erase(c.id)
	no_site[c.id] = gw.game_time
	return Vector2i(-1, -1)


const SITE_CHECKS: int = 90
const SITE_STEP: int = 20
const WET_PROBE: Array[Vector2i] = [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4), Vector2i(6, 0), Vector2i(-6, 0), Vector2i(0, 5), Vector2i(0, -5)]
var _site_pend: Dictionary = {}



func site_pending(c: Country) -> bool:
	return _site_pend.has(c.id)
var _site_off: Dictionary = {}




func segments(p: Facility) -> Array:
	return _port_state(p).get("segs", [])


func seg_count(p: Facility) -> int:
	var n: int = 0
	for sg: Dictionary in segments(p):
		if gw.obj_state[int(sg["obj"])] == 0:
			n += 1
	return n



func length_of(p: Facility) -> int:
	return (maxi(p.size.x, p.size.y) + SEG * segments(p).size()) * GameWorld.CELL



func trade_value(c: Country) -> int:
	var st: Dictionary = econ.stats(c)
	return int(exported.get(c.id, 0)) + int((st["income_total"] as Dictionary).get("trade", 0)) + container_units(c) * 40


func next_seg_value(p: Facility) -> int:
	var n: int = segments(p).size()
	return -1 if n >= MAX_SEGS else (n + 1) * SEG_VALUE


func _grow_tick() -> void :
	for p: Facility in gw.mil.facilities:
		if p.kind != Facility.Kind.PORT or not gw.mil.alive(p):
			continue
		var c: Country = gw.country_by_id(p.country_id)
		if c == null or segments(p).size() >= MAX_SEGS:
			continue
		if trade_value(c) < next_seg_value(p) or gw.game_time - float(_no_grow.get(p, -1000.0)) < 90.0:
			continue
		if not grow(p):
			_no_grow[p] = gw.game_time




func grow(p: Facility) -> bool:
	var st: Dictionary = _port_state(p)
	if not st.has("segs"):
		st["segs"] = []
	var segs: Array = st["segs"]
	var pieces: Array[Rect2i] = [Rect2i(p.cell, p.size)]
	for sg: Dictionary in segs:
		pieces.append(Rect2i(sg["cell"] as Vector2i, Vector2i(SEG, SEG)))
	var cen: Vector2i = p.cell + p.size / 2
	var R: int = 8 + SEG * (segs.size() + 1)
	var best: = Vector2i(-1, -1)
	var bd: float = INF
	for y in range(cen.y - R, cen.y + R + 1):
		for x in range(cen.x - R, cen.x + R + 1):
			var r: = Rect2i(x, y, SEG, SEG)
			var near: bool = false
			var hit: bool = false
			for q: Rect2i in pieces:
				if q.intersects(r):
					hit = true
					break
				if q.grow(1).intersects(r):
					near = true
			if hit or not near:
				continue
			var d: float = Vector2(r.get_center()).distance_to(Vector2(cen))
			if d >= bd or not _seg_ok(r, p.country_id):
				continue
			bd = d
			best = r.position
	if best.x < 0:
		return false
	var nm: String = SEG_TYPES[segs.size() % SEG_TYPES.size()]
	var d2: WorldData = gw.data
	for yy in range(best.y, best.y + SEG):
		for xx in range(best.x, best.x + SEG):
			gw.remove_tree_at(Vector2i(xx, yy))
			d2.add_flag(xx, yy, WorldData.F_OCCUPIED)
			d2.set_biome(xx, yy, Biome.PLAZA)
	var id: int = gw.add_object(nm, best, GameWorld.KIND_BUILDING)
	if id < 0:
		return false
	p.obj_ids.append(id)
	segs.append({"obj": id, "cell": best, "type": nm})
	if gw._on_screen(Vector2(best * GameWorld.CELL), 40.0):
		gw.fx.spawn("dust_s", Vector2(best * GameWorld.CELL) + Vector2(10, 10), 6)
	var c: Country = gw.country_by_id(p.country_id)
	if c != null and c.is_player:
		gw.say(c, Loc.mk("Порт растёт: новый причал (%d м набережной)", [length_of(p)]))
	gw.changed.emit()
	return true


func _seg_ok(r: Rect2i, owner: int) -> bool:
	var d: WorldData = gw.data
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not d.inside(x, y) or d.get_owner_id(x, y) != owner or Biome.is_water(d.get_biome(x, y)):
				return false
			if d.has_flag(x, y, WorldData.F_OCCUPIED | WorldData.F_ROAD | WorldData.F_BRIDGE | WorldData.F_CITY):
				return false
	var wet: int = 0
	for y in range(r.position.y - 1, r.end.y + 1):
		for x in range(r.position.x - 1, r.end.x + 1):
			if (x < r.position.x or x >= r.end.x or y < r.position.y or y >= r.end.y) and d.inside(x, y) and Biome.is_water(d.get_biome(x, y)):
				wet += 1
	if wet < 3:
		return false
	return econ.deposit_free_rect(r)



func yard_slots(p: Facility, at: SpriteAtlas) -> PackedVector2Array:
	var out: = PackedVector2Array()
	if at.has("port") and at.info("port").has("slots") and p.main_obj >= 0 and gw.obj_state[p.main_obj] == 0:
		var o: Vector2 = gw.obj_origin(p.main_obj)
		for sl: Array in at.info("port")["slots"]:
			out.append(o + Vector2(float(sl[0]), float(sl[1])))
	for sg: Dictionary in segments(p):
		var id: int = sg["obj"]
		if String(sg["type"]) != "port_seg_yard" or gw.obj_state[id] != 0 or not at.has("port_seg_yard"):
			continue
		var o2: Vector2 = gw.obj_origin(id)
		for sl2: Array in at.info("port_seg_yard").get("slots", []):
			out.append(o2 + Vector2(float(sl2[0]), float(sl2[1])))
	return out
