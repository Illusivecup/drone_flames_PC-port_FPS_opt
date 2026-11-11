extends "res://game/economy/eco_core.gd"




func trading(a: int, b: int) -> bool:
	return trade.has(Diplomacy.key(a, b))


func set_trade(a: int, b: int, on: bool) -> String:
	if on:
		if gw.diplo.at_war(a, b):
			return Loc.t("Нельзя торговать с врагом")
		if gw.diplo.embargo_between(a, b):
			return Loc.t("Эмбарго: торговля закрыта")
		trade[Diplomacy.key(a, b)] = true
		gw.news_m(Loc.mk("ТОРГОВОЕ СОГЛАШЕНИЕ: %s И %s", [gw.country_by_id(a).name.to_upper(), gw.country_by_id(b).name.to_upper()]), "grass_light")
	else:
		trade.erase(Diplomacy.key(a, b))
	return ""



func req_to(rq: Dictionary) -> int:
	if rq.has("to"):
		return int(rq["to"])
	return gw.player.id if gw.player != null else -1



func requests_for(cid: int) -> Array:
	var out: Array = []
	for rq: Dictionary in requests:
		if req_to(rq) == cid:
			out.append(rq)
	return out



func req_to_id(req_id: int) -> int:
	for rq: Dictionary in requests:
		if int(rq["id"]) == req_id:
			return req_to(rq)
	return -1



func _pending_changed() -> void :
	if gw.diplo != null:
		gw.diplo.pending_changed.emit()



func _ship(s: Country, r: Country) -> void :
	if _in_transit(s.id, r.id) >= 2:
		return
	var best: String = ""
	var best_v: float = 0.0
	for res: String in TRADE_RES:
		var spare: int = surplus(s, res)
		var lack: int = need(r, res) - inbound(r, res)
		if spare >= 5 and lack >= 3 and not trd.res_blocked(s.id, r.id, res):
			var v: float = float(mini(spare, lack)) * market_price(res)
			if v > best_v:
				best_v = v
				best = res
	if best == "":
		return
	var unit: int = maxi(1, roundi(market_price(best) * gw.diplo.trade_mul(r.id, s.id)))
	var n: int = mini(TRUCK_LOAD * 3, mini(surplus(s, best), need(r, best) - inbound(r, best)))
	n = mini(mini(n, r.money / maxi(1, unit)), room_for(r, best))
	if n < 3:
		return
	s.set(best, int(s.get(best)) - n)
	stat_res(s, best, "trade", - n)
	if _send(s, r, best, n, unit * n) == "":
		s.set(best, int(s.get(best)) + n)
		stat_res(s, best, "trade", n)


func _in_transit(from: int, to: int) -> int:
	var n: int = 0
	for t: Dictionary in trucks:
		if int(t["from"]) == from and int(t["to"]) == to:
			n += 1
	for s: Dictionary in ports.ships:
		if int(s["from"]) == from and int(s["to"]) == to:
			n += 1
	for j: Dictionary in rail_jobs:
		if int(j["from"]) == from and int(j["to"]) == to:
			n += 1
	return n




func _send(s: Country, r: Country, res: String, n: int, price: int, aid: bool = false) -> String:
	var sh: Dictionary = {"from": s.id, "to": r.id, "res": res, "n": n, "price": price}
	if aid:
		sh["aid"] = true

	r.money -= price
	stat_add(r, "spend", "trade", price)
	var rail: Variant = gw.get("rail")
	if rail is Object and (rail as Object).has_method("send"):
		var on_ok: Callable = func() -> void : _rail_done(sh, true)
		var on_lost: Callable = func() -> void : _rail_done(sh, false)
		var ok: bool = bool((rail as Object).call("send", s.capital_id, r.capital_id, res, n, on_ok, on_lost, sh))
		if ok:
			rail_jobs.append(sh)
			return "rail"
	var a: Vector2 = Vector2(gw.cities[s.capital_id].entrance * GameWorld.CELL)
	var b: Vector2 = Vector2(gw.cities[r.capital_id].entrance * GameWorld.CELL)
	var land: PackedVector2Array = land_path(a, b)
	if ports.can_sail(s, r) and (land.is_empty() or ports.sea_dist(s, r) < _plen(a, land) * 0.8):
		if ports.send_trade(s, r, res, n, price):
			return "ship"
	if land.is_empty():
		refund(sh, false)
		return ""
	trucks.append({"from": s.id, "to": r.id, "res": res, "n": n, "path": land, "i": 0, "pos": a, "heading": 0.0, "frame": 0, "id": _truck_id, "price": price})
	if aid:
		trucks[-1]["aid"] = true
	_truck_id += 1
	Sfx.play("truck_pass", a)
	return "truck"


func _rail_done(sh: Dictionary, arrived: bool) -> void :
	var k: int = rail_jobs.find(sh)
	if k < 0:
		return
	rail_jobs.remove_at(k)
	if arrived:
		complete(sh)
	else:
		refund(sh)


func _plen(a: Vector2, p: PackedVector2Array) -> float:
	var l: float = 0.0
	var prev: Vector2 = a
	for q: Vector2 in p:
		l += prev.distance_to(q)
		prev = q
	return l



func land_path(a: Vector2, b: Vector2) -> PackedVector2Array:

	var p: PackedVector2Array = nav_path(a, b)
	if not nav_last_ok:
		return PackedVector2Array()
	return p


func _update_trucks(dt: float) -> void :
	dust_t += dt
	for k in range(trucks.size() - 1, -1, -1):
		var t: Dictionary = trucks[k]
		var sc: Country = gw.country_by_id(int(t["from"]))
		var rc: Country = gw.country_by_id(int(t["to"]))
		if sc != null and rc != null and gw.diplo.embargo_between(sc.id, rc.id) and not gw.diplo.at_war(sc.id, rc.id):
			turn_back(t)
			trucks.remove_at(k)
			continue
		if sc == null or rc == null or rc.eliminated or rc.capital_id < 0 or gw.diplo.at_war(sc.id, rc.id):
			refund(t)
			trucks.remove_at(k)
			continue
		if gw.supply != null:
			var jm: int = gw.supply.truck_tick(t, dt)
			if jm == 1:
				continue
			if jm == 2:
				trucks.remove_at(k)
				continue
		var path: PackedVector2Array = t["path"]
		var i: int = t["i"]
		if i >= path.size():
			complete(t)
			trucks.remove_at(k)
			continue
		var pos: Vector2 = t["pos"]
		var step: float = TRUCK_SPEED * dt



		for _arr in 2:
			if i > int(t.get("rf", -1)):
				path = _road_leg(t, path, i, pos)
			var to: Vector2 = path[i] - pos
			var dl: float = to.length()
			if dl <= step:
				pos = path[i]
				t["pos"] = pos
				t["i"] = i + 1
				step -= dl

				if i + 1 < path.size() - 1 and point_blocked(path[i + 1]):
					t["path"] = nav_path(path[i], path[path.size() - 1])
					t["i"] = 0
					t["rf"] = -1
					break
				i += 1
				if i >= path.size() or step <= 0.001 or int(t.get("brk", -1)) >= 0:
					break
			else:
				t["pos"] = pos + to.normalized() * step
				var want_a: float = to.angle()
				t["heading"] = want_a
				t["frame"] = posmod(roundi(rad_to_deg(want_a) / 22.5), 16)
				break


func _road_leg(t: Dictionary, path: PackedVector2Array, i: int, a: Vector2) -> PackedVector2Array:
	t["rf"] = i
	var b: Vector2 = path[i]
	if a.distance_squared_to(b) < 4.0 or _bridge_near(a) or _bridge_near(b):
		return path
	var d: WorldData = gw.data
	var last: bool = i == path.size() - 1
	if not last and not _truck_free(_tcell(b)):
		var sb: Vector2 = _truck_snap(b)
		if sb != Vector2.INF:
			b = sb
	var n: int = maxi(1, int(a.distance_to(b) / 2.0))
	var bad: bool = false
	var off: bool = false
	var town: bool = false
	for k in range(0, n + 1):
		var c: Vector2i = _tcell(a.lerp(b, float(k) / float(n)))
		if not d.inside(c.x, c.y):
			continue
		var fl: int = d.flags[c.y * d.w + c.x]
		if (fl & WorldData.F_BRIDGE) != 0:
			return path
		if k > 0 and k < n and not _truck_free(c):
			bad = true
		if (fl & WorldData.F_ROAD) == 0:
			off = true
		if (fl & WorldData.F_CITY) != 0:
			town = true
	if not bad and not (off and town):
		if b != path[i]:
			path[i] = b
			t["path"] = path
		return path
	var leg: PackedVector2Array = _fine_leg(a, b)
	if leg.is_empty():
		return path
	var out: PackedVector2Array = path.slice(0, i)
	out.append_array(leg)
	out.append_array(path.slice(i + 1))
	t["path"] = out
	t["rf"] = i + leg.size() - 1
	t["chk"] = -1
	refined += 1
	return out


func _tcell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))



func _truck_free(c: Vector2i) -> bool:
	var d: WorldData = gw.data
	if not d.inside(c.x, c.y):
		return false
	var ix: int = c.y * d.w + c.x
	var fl: int = d.flags[ix]
	if Biome.is_water(d.biome[ix]) and (fl & WorldData.F_BRIDGE) == 0:
		return false
	if (fl & WorldData.F_ROAD) != 0:
		return true
	return (fl & WorldData.F_OCCUPIED) == 0 or gw.tree_at.has(ix)



func _truck_snap(p: Vector2) -> Vector2:
	var c: Vector2i = _tcell(p)
	var d: WorldData = gw.data
	var free: = Vector2.INF
	for r in range(1, 5):
		for dy in range( - r, r + 1):
			for dx in range( - r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q: = c + Vector2i(dx, dy)
				if not _truck_free(q):
					continue
				var qp: = Vector2(q * GameWorld.CELL) + Vector2(2, 2)
				if (d.flags[q.y * d.w + q.x] & WorldData.F_ROAD) != 0:
					return qp
				if free == Vector2.INF:
					free = qp
		if free != Vector2.INF and r >= 2:
			return free
	return free



func _fine_leg(a: Vector2, b: Vector2) -> PackedVector2Array:
	var ca: Vector2i = _tcell(a)
	var cb: Vector2i = _tcell(b)
	var d: WorldData = gw.data
	var lo: = (Vector2i(mini(ca.x, cb.x), mini(ca.y, cb.y)) - Vector2i(ROAD_PAD, ROAD_PAD)).max(Vector2i.ZERO)
	var hi: = (Vector2i(maxi(ca.x, cb.x), maxi(ca.y, cb.y)) + Vector2i(ROAD_PAD + 1, ROAD_PAD + 1)).min(Vector2i(d.w, d.h))
	if not Rect2i(lo, hi - lo).has_point(ca) or not Rect2i(lo, hi - lo).has_point(cb):
		return PackedVector2Array()
	var g: = AStarGrid2D.new()
	g.region = Rect2i(lo, hi - lo)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	for y in range(lo.y, hi.y):
		for x in range(lo.x, hi.x):
			var c: = Vector2i(x, y)
			if not _truck_free(c):
				g.set_point_solid(c, true)
			elif (d.flags[y * d.w + x] & WorldData.F_ROAD) == 0:
				g.set_point_weight_scale(c, OFFROAD_W)
	g.set_point_solid(ca, false)
	g.set_point_solid(cb, false)
	var ids: Array[Vector2i] = g.get_id_path(ca, cb)
	if ids.is_empty() or ids[ids.size() - 1] != cb:
		return PackedVector2Array()
	var out: = PackedVector2Array()
	var half: = Vector2(GameWorld.CELL * 0.5, GameWorld.CELL * 0.5)
	for k in range(1, ids.size() - 1):
		if ids[k] - ids[k - 1] != ids[k + 1] - ids[k]:
			out.append(Vector2(ids[k] * GameWorld.CELL) + half)
	out.append(b)
	return out



func complete(t: Dictionary) -> void :
	var s: Country = gw.country_by_id(int(t["from"]))
	var r: Country = gw.country_by_id(int(t["to"]))
	if s == null or r == null:
		return
	if gw.diplo.at_war(s.id, r.id):
		refund(t)
		return
	if gw.diplo.embargo_between(s.id, r.id) or trd.res_blocked(s.id, r.id, String(t["res"])):
		turn_back(t)
		return
	var res: String = t["res"]
	var n: int = int(t["n"])
	var pay: int = int(t["price"])
	if gw.kpp != null:
		gw.kpp.note_trade(s.id, r.id, pay)
	s.add_money(pay)
	s.trade_income += pay
	stat_add(s, "income", "trade", pay)
	r.set(res, int(r.get(res)) + n)
	stat_res(r, res, "trade", n)
	if bool(t.get("aid", false)):
		gw.say2(s, r, Loc.mk("Помощь доставлена: %s %d (%s → %s)", [Loc.t(String(RES_NAMES[res]).to_lower()), n, Loc.name(s.name), Loc.name(r.name)]))
		return
	gw.diplo.add_opinion(s.id, r.id, 2)
	if s.is_player:
		gw.say(s, Loc.mk("Груз доставлен в %s: +%d (%s %d)", [Loc.name(r.name), pay, Loc.t(String(RES_NAMES[res]).to_lower()), n]))
	elif r.is_player:
		if bool(t.get("mkt", false)):
			gw.say(r, Loc.mk("Покупка прибыла: %s +%d от %s (оплачено %d)", [Loc.t(String(RES_NAMES[res]).to_lower()), n, Loc.name(s.name), pay]))
		else:
			gw.say(r, Loc.mk("Получено от %s: %s +%d (-%d)", [Loc.name(s.name), Loc.t(String(RES_NAMES[res]).to_lower()), n, pay]))



func on_strike(p: Vector2, r_px: float, by: int = 0) -> void :
	ports.on_strike(p, r_px, by)
	for k in range(trucks.size() - 1, -1, -1):
		var t: Dictionary = trucks[k]
		if (t["pos"] as Vector2).distance_to(p) <= r_px + 5.0:
			gw.fx.spawn("explosion_s", (t["pos"] as Vector2).round(), 6)
			gw.fx.debris_burst((t["pos"] as Vector2).round(), 3, false)
			trucks.remove_at(k)







func buy(buyer: Country, seller: Country, res: String, n: int) -> String:
	if buyer == null or n <= 0 or not TRADE_RES.has(res):
		return Loc.t("Этим не торгуют")
	if seller == null:
		return ports.import_order(buyer, res, n)
	var why: String = _deal_ok(buyer, seller, res)
	if why != "":
		return why
	if not seller.is_player and gw.diplo.get_opinion(seller.id, buyer.id) < -30:
		return Loc.t("%s не торгует с вами") % seller.name
	var avail: int = int(seller.get(res)) if seller.is_player else surplus(seller, res)
	n = mini(n, avail)
	if n <= 0:
		return Loc.t("У %s нет лишнего: %s") % [seller.name, Loc.t(String(RES_NAMES[res]).to_lower())]
	n = mini(n, room_for(buyer, res))
	if n <= 0:
		return Loc.t("Склад полон: %s (лимит %d)") % [Loc.t(String(RES_NAMES[res]).to_lower()), res_cap(buyer, res)]
	var unit: int = maxi(1, roundi(market_price(res) * gw.diplo.trade_mul(buyer.id, seller.id)))
	if buyer.money < unit:
		return Loc.t("Не хватает денег: %d за ед.") % unit
	n = mini(n, buyer.money / unit)
	seller.set(res, int(seller.get(res)) - n)
	stat_res(seller, res, "trade", - n)
	var mode: String = _send(seller, buyer, res, n, unit * n)
	if mode == "":
		seller.set(res, int(seller.get(res)) + n)
		stat_res(seller, res, "trade", n)
		return Loc.t("Нет пути: ни дороги, ни рельсов, ни моря между столицами")
	if _mkt_tag:
		_mkt_note("buy", buyer, seller, res, n, unit * n, mode)
	if buyer.is_player or seller.is_player:
		gw.say2(buyer, seller, Loc.mk("Сделка: %s %d за %d — %s", [Loc.t(String(RES_NAMES[res]).to_lower()), n, unit * n, String(MODE_NAMES[mode])]))
	return ""




func sell(seller: Country, buyer: Country, res: String, n: int) -> String:
	if seller == null or n <= 0 or not TRADE_RES.has(res):
		return Loc.t("Этим не торгуют")
	if buyer == null:
		return ports.export_order(seller, res, n)
	if buyer.is_player:
		return buy(buyer, seller, res, n)
	var why: String = _deal_ok(buyer, seller, res)
	if why != "":
		return why
	var unit: int = market_price(res)
	var room: int = res_cap(buyer, res) - int(buyer.get(res)) - inbound(buyer, res)
	var lack: int = need(buyer, res) - inbound(buyer, res)
	var take: int = lack if lack > 0 else (room / 2 if buyer.money > unit * n + 800 else 0)
	n = mini(mini(n, take), mini(room, int(seller.get(res))))
	n = mini(n, buyer.money / unit)
	if n <= 0:
		return Loc.t("%s: %s сейчас не %s") % [buyer.name, Loc.t(String(RES_NAMES[res]).to_lower()), need_word(res)]
	seller.set(res, int(seller.get(res)) - n)
	stat_res(seller, res, "trade", - n)
	var mode: String = _send(seller, buyer, res, n, unit * n)
	if mode == "":
		seller.set(res, int(seller.get(res)) + n)
		stat_res(seller, res, "trade", n)
		return Loc.t("Нет пути: ни дороги, ни рельсов, ни моря между столицами")
	if _mkt_tag:
		_mkt_note("sell", buyer, seller, res, n, unit * n, mode)
	if seller.is_player:
		gw.say(seller, Loc.mk("Продано %s: %s %d за %d (оплата при доставке)", [Loc.name(buyer.name), Loc.t(String(RES_NAMES[res]).to_lower()), n, unit * n]))
	return ""


func _deal_ok(a: Country, b: Country, res: String = "") -> String:
	if a == b:
		return Loc.t("Это ваша страна")
	if a.eliminated or b.eliminated or a.capital_id < 0 or b.capital_id < 0:
		return Loc.t("Нет столицы")
	if gw.diplo.at_war(a.id, b.id):
		return Loc.t("Война: торговля невозможна")
	if gw.diplo.embargo_between(a.id, b.id):
		return Loc.t("Эмбарго: торговля закрыта")
	if res != "" and trd.res_blocked(a.id, b.id, res):
		return Loc.t("Санкции: %s") % Loc.t(String(RES_NAMES.get(res, res)).to_lower())
	return ""




func accept_request(p: Country, req_id: int) -> String:
	for i in requests.size():
		var rq: Dictionary = requests[i]
		if int(rq["id"]) != req_id or p == null or req_to(rq) != p.id:
			continue
		var b: Country = gw.country_by_id(int(rq["from"]))
		if p == null or b == null:
			requests.remove_at(i)
			_pending_changed()
			return Loc.t("Покупателя больше нет")
		var res: String = rq["res"]
		var n: int = mini(int(rq["n"]), int(p.get(res)))
		if n <= 0:
			return Loc.t("Нечего продать: %s") % Loc.t(String(RES_NAMES[res]).to_lower())
		var why: String = _deal_ok(b, p, res)
		if why != "":
			return why
		var unit: int = int(rq["price"])
		n = mini(mini(n, b.money / maxi(1, unit)), room_for(b, res))
		if n <= 0:
			return Loc.t("У покупателя нет денег")
		p.set(res, int(p.get(res)) - n)
		stat_res(p, res, "trade", - n)
		if _send(p, b, res, n, unit * n) == "":
			p.set(res, int(p.get(res)) + n)
			stat_res(p, res, "trade", n)
			return Loc.t("Нет пути до покупателя")
		requests.remove_at(i)
		_pending_changed()
		gw.diplo.add_opinion(p.id, b.id, 4)
		gw.say(p, Loc.mk("Продано {c}: {res} {n} за {sum} (оплата при доставке)", {"c": Loc.name(b.name), "res": Loc.t(String(RES_NAMES[res]).to_lower()), "n": n, "sum": unit * n}))
		return ""
	return Loc.t("Запрос устарел")


func decline_request(p: Country, req_id: int) -> void :
	for i in requests.size():
		if int(requests[i]["id"]) == req_id and p != null and req_to(requests[i]) == p.id:
			requests.remove_at(i)
			_pending_changed()
			return


func set_export(c: Country, on: bool) -> void :
	if on:
		export_off.erase(c.id)
	else:
		export_off[c.id] = true






func _ai_trade(c: Country) -> void :
	for res: String in TRADE_RES:
		var lack: int = need(c, res) - inbound(c, res)
		if lack < 3:
			continue
		if lack < 12 and market_price(res) > roundi(float(PRICE.get(res, 10)) * AI_MAX_PRICE):
			continue
		var n: int = mini(lack, 30)
		var unit: int = market_price(res)
		var seller: Country = _best_seller(c, res)
		if seller != null and c.money >= unit * mini(n, surplus(seller, res)) + 150:
			if buy(c, seller, res, n) == "":
				continue
		if ports.has_port(c) and (res == "oil" or res == "metal" or res == "titanium" or lack >= 10) and c.money >= foreign_buy_price(res) * n + 600:
			if ports.import_order(c, res, n) == "":
				continue
		_ask_player(c, res, n)




func market_order(c: Country, partner: Country, res: String, n: int, buying: bool) -> String:
	last_deal = {}
	if c == null or not TRADE_RES.has(res) or n <= 0:
		return Loc.t("Этим не торгуют")
	var why: String = market_check(c, res, buying, partner).get("why", "")
	if why != "":
		return why
	_mkt_tag = true
	var nship: int = ports.ships.size()
	var r: String = ""
	if buying:
		r = buy(c, partner, res, n)
		if r == "" and partner == null:
			var q: bool = ports.ships.size() == nship
			var unit: int = foreign_buy_price(res, c.id)
			var eta: float = -1.0
			var got: int = n
			if not q:
				var sh: Dictionary = ports.ships[ports.ships.size() - 1]
				sh["mkt"] = true
				got = int(sh["n"])
				eta = _plen(sh["pos"], sh["path"]) / Ports.SHIP_SPEED + float(sh.get("t", 0.0))
			else:
				var qq: Array = ports.queue.get(c.id, [])
				if not qq.is_empty():
					(qq[qq.size() - 1] as Dictionary)["mkt"] = true
					got = int((qq[qq.size() - 1] as Dictionary)["n"])
			last_deal = {"kind": "buy", "res": res, "n": got, "price": unit * got, "mode": "queue" if q else "import", "eta": eta, "partner": Loc.t("из-за рубежа")}
	else:
		r = sell(c, partner, res, n)
		if r == "" and partner == null and ports.ships.size() > nship:
			var se: Dictionary = ports.ships[ports.ships.size() - 1]
			var pay: int = int(market_price(res) * FOREIGN_SELL) * int(se["n"])
			last_deal = {"kind": "sell", "res": res, "n": int(se["n"]), "price": pay, "mode": "export", 
				"eta": _plen(se["pos"], se["path"]) / Ports.SHIP_SPEED + float(se.get("t", 0.0)), "partner": Loc.t("за рубеж")}
	_mkt_tag = false
	return r



func _mkt_note(kind: String, buyer: Country, seller: Country, res: String, n: int, price: int, mode: String) -> void :
	var eta: float = -1.0
	match mode:
		"truck":
			if not trucks.is_empty():
				var t: Dictionary = trucks[trucks.size() - 1]
				t["mkt"] = true
				eta = _plen(t["pos"], t["path"]) / TRUCK_SPEED
		"ship":
			if not ports.ships.is_empty():
				var sh: Dictionary = ports.ships[ports.ships.size() - 1]
				sh["mkt"] = true
				eta = _plen(sh["pos"], sh["path"]) / Ports.SHIP_SPEED + float(sh.get("t", 0.0))
		"rail":
			if not rail_jobs.is_empty():
				(rail_jobs[rail_jobs.size() - 1] as Dictionary)["mkt"] = true
			var a: Vector2 = Vector2(gw.cities[seller.capital_id].entrance * GameWorld.CELL)
			var b: Vector2 = Vector2(gw.cities[buyer.capital_id].entrance * GameWorld.CELL)
			eta = a.distance_to(b) * 1.25 / RAIL_ETA_SPEED
	var other: Country = seller if kind == "buy" else buyer
	last_deal = {"kind": kind, "res": res, "n": n, "price": price, "mode": mode, "eta": eta, "partner": other.name if other != null else ""}




func market_check(c: Country, res: String, buying: bool, partner: Variant = false) -> Dictionary:
	var out: Dictionary = {"ok": false, "why": "", "partner": null}
	if c == null or c.capital_id < 0 or c.eliminated:
		out["why"] = Loc.t("Нет столицы")
		return out
	var nm: String = Loc.t(String(RES_NAMES.get(res, res)).to_lower())
	var pf: Facility = ports.port_of(c)
	var port_why: String = ""
	if pf == null:
		port_why = Loc.t("нет порта")
	elif not ports.ocean(pf):
		port_why = Loc.t("из порта нет выхода в океан")
	elif ports.blocked(c):
		port_why = Loc.t("порт в блокаде")
	if buying:
		if room_for(c, res) <= 0:
			out["why"] = Loc.t("Склад полон: %s %d/%d (в пути %d) — постройте склад или потратьте") % [nm, int(c.get(res)), res_cap(c, res), inbound(c, res)]
			return out
		var sel: Country = (partner as Country) if partner is Country else (best_seller(c, res) if partner is bool else null)
		if sel != null and trd.res_blocked(c.id, sel.id, res):
			out["why"] = Loc.t("Санкции: %s с %s") % [nm, sel.name]
			return out
		if sel != null:
			var unit: int = maxi(1, roundi(market_price(res) * gw.diplo.trade_mul(c.id, sel.id)))
			if c.money < unit:
				out["why"] = Loc.t("Не хватает денег: %d за ед., у вас %d") % [unit, c.money]
				return out
			out["partner"] = sel
		else:
			if port_why != "":
				out["why"] = Loc.t("Купить не у кого: у соседей нет лишнего (%s), а %s") % [nm, port_why]
				return out
			var up: int = foreign_buy_price(res, c.id)
			if c.money < up:
				out["why"] = Loc.t("Не хватает денег: импорт %d за ед., у вас %d") % [up, c.money]
				return out
			if ports.active(pf) >= ports.capacity(pf) and (ports.queue.get(c.id, []) as Array).size() >= 3:
				out["why"] = Loc.t("Очередь импорта полна: постройте кран в порту")
				return out
	else:
		if int(c.get(res)) <= 0:
			out["why"] = Loc.t("Продавать нечего: %s 0") % nm
			return out
		var unit2: int = market_price(res)
		var buyer: Country = (partner as Country) if partner is Country else null
		if buyer != null and trd.res_blocked(c.id, buyer.id, res):
			out["why"] = Loc.t("Санкции: %s с %s") % [nm, buyer.name]
			return out
		if partner is bool:
			var bn: int = 0
			for o: Country in gw.countries:
				if o == c or o.is_player or o.eliminated or o.capital_id < 0 or gw.diplo.at_war(c.id, o.id) or gw.diplo.embargo_between(c.id, o.id) or trd.res_blocked(c.id, o.id, res):
					continue
				var lack: int = need(o, res) - inbound(o, res)
				if lack > bn and o.money >= unit2 and can_reach(c, o):
					bn = lack
					buyer = o
		if buyer != null:
			out["partner"] = buyer
		elif port_why != "":
			out["why"] = Loc.t("Продать некому: соседям %s не %s, а %s") % [nm, need_word(res), port_why]
			return out
		elif ports.active(pf) >= ports.capacity(pf):
			out["why"] = Loc.t("Все причалы заняты: подождите корабль или постройте кран")
			return out
	out["ok"] = true
	return out




static func need_word(res: String) -> String:
	return String({"metal": Loc.t("нужен"), "titanium": Loc.t("нужен"), "uranium": Loc.t("нужен"), "food": Loc.t("нужна"), "oil": Loc.t("нужна"), 
		"wood": Loc.t("нужно"), "fuel": Loc.t("нужно"), "goods": Loc.t("нужны"), "precious": Loc.t("нужны")}.get(res, "нужно"))


static func eta_text(sec: float) -> String:
	if sec < 0.0:
		return Loc.t("время в пути неизвестно")
	if sec < 90.0:
		return Loc.t("≈ %d с") % maxi(5, roundi(sec / 5.0) * 5)
	return Loc.t("≈ %d мин") % roundi(sec / 60.0)





func best_seller(buyer: Country, res: String) -> Country:
	if buyer == null:
		return null
	var best: Country = null
	var bv: int = 0
	for o: Country in gw.countries:
		if o == buyer or o.is_player or o.eliminated or o.capital_id < 0 or gw.diplo.at_war(buyer.id, o.id) or gw.diplo.embargo_between(buyer.id, o.id) or trd.res_blocked(buyer.id, o.id, res):
			continue
		if gw.diplo.get_opinion(o.id, buyer.id) < -30:
			continue
		var s: int = surplus(o, res)
		if s > bv and can_reach(o, buyer):
			bv = s
			best = o
	return best







func buy_shortfall(c: Country, cost: Dictionary) -> Dictionary:
	var out: Dictionary = {"ok": false, "text": "", "bought": {}, "paid": 0, "left": {}}
	if c == null:
		out["text"] = Loc.t("Нет страны")
		return out
	var parts: PackedStringArray = PackedStringArray()
	var fails: PackedStringArray = PackedStringArray()
	var m0: int = c.money
	gw.set_block_signals(true)
	for res: String in cost:
		if res == "money" or not TRADE_RES.has(res):
			continue
		var lack: int = int(cost[res]) - int(c.get(res)) - inbound(c, res)
		if lack <= 0:
			continue
		var got: int = 0
		var seller: Country = best_seller(c, res)
		if seller != null:
			var i0: int = inbound(c, res)
			if buy(c, seller, res, lack) == "":
				got = maxi(0, inbound(c, res) - i0)
				if got > 0:
					parts.append("%s %d (%s)" % [Loc.t(String(RES_NAMES[res]).to_lower()), got, seller.name])
		if got < lack and ports.has_port(c):
			var i1: int = inbound(c, res)
			var mb: int = c.money
			var why: String = ports.import_order(c, res, lack - got)
			if why == "":
				var g2: int = maxi(inbound(c, res) - i1, 0)
				if g2 == 0 and c.money < mb:
					g2 = (mb - c.money) / maxi(1, foreign_buy_price(res))
				got += g2
				parts.append(Loc.t("%s %d (импорт)") % [Loc.t(String(RES_NAMES[res]).to_lower()), g2])
			else:
				fails.append(why)
		elif got < lack and seller == null:
			fails.append(Loc.t("%s: продавцов нет") % Loc.t(String(RES_NAMES[res]).to_lower()))
		if got > 0:
			(out["bought"] as Dictionary)[res] = got
		if got < lack:
			(out["left"] as Dictionary)[res] = lack - got
	gw.set_block_signals(false)
	out["paid"] = maxi(0, m0 - c.money)
	out["ok"] = not (out["bought"] as Dictionary).is_empty()
	if int(cost.get("money", 0)) > c.money:
		fails.append(Loc.t("денег не хватает %d") % (int(cost.get("money", 0)) - c.money))
	if out["ok"]:
		out["text"] = Loc.t("Куплено: %s · %d — в пути") % [", ".join(parts), int(out["paid"])]
	elif parts.is_empty() and fails.is_empty():
		out["text"] = Loc.t("Всё есть или уже в пути")
	else:
		out["text"] = Loc.t("Не купить: ") + (fails[0] if not fails.is_empty() else Loc.t("нет продавцов"))
	if not (out["left"] as Dictionary).is_empty() and out["ok"] and not fails.is_empty():
		out["text"] += " · " + fails[0]
	if c.is_player:
		gw.say(c, String(out["text"]))
	gw.changed.emit()
	return out


func _best_seller(c: Country, res: String) -> Country:
	var best: Country = null
	var bv: int = 4
	var raw_best: Country = null
	var rv: int = 4
	for o: Country in gw.countries:
		if o == c or o.is_player or o.eliminated or o.capital_id < 0 or gw.diplo.at_war(c.id, o.id) or gw.diplo.embargo_between(c.id, o.id) or trd.res_blocked(c.id, o.id, res):
			continue
		if gw.diplo.get_opinion(o.id, c.id) < -30:
			continue
		var s: int = surplus(o, res)
		if s > rv and can_reach(o, c):
			rv = s
			raw_best = o
		if gw.supply != null:
			s = int(float(s) / (1.0 + 3.0 * gw.supply.route_risk(o.id, c.id)))
		if s > bv and can_reach(o, c):
			bv = s
			best = o
	if best != raw_best and raw_best != null and gw.supply != null:
		gw.supply.stats["buy_elsewhere"] = int(gw.supply.stats.get("buy_elsewhere", 0)) + 1
	return best






func _ask_player(c: Country, res: String, n: int) -> void :
	if gw.game_time - float(_ask_t.get(c.id, -1000.0)) < 240.0:
		return
	var p: Country = null
	var pn: int = 0
	var pt: float = 0.0
	for h: Country in gw.countries:
		if not h.is_player or h.eliminated or h.capital_id < 0 or gw.diplo.at_war(c.id, h.id) or gw.diplo.embargo_between(c.id, h.id) or trd.res_blocked(c.id, h.id, res):
			continue
		if requests_for(h.id).size() >= 3:
			continue
		var ht: float = float(_ask_t.get(-1 - h.id, -1000.0))
		if gw.game_time - ht < 150.0:
			continue
		var spare: int = int(h.get(res)) - keep(h, res)
		if spare < 5 or not can_reach(h, c):
			continue
		var hn: int = mini(n, spare)
		var hu: int = int(ceil(market_price(res) * (1.05 if trading(c.id, h.id) else 1.15)))
		if c.money < hu * hn:
			hn = c.money / hu
		if hn < 3:
			continue
		if p == null or ht < pt:
			p = h
			pn = hn
			pt = ht
	if p == null:
		return
	n = pn
	var unit: int = int(ceil(market_price(res) * (1.05 if trading(c.id, p.id) else 1.15)))
	_ask_t[c.id] = gw.game_time
	_ask_t[-1 - p.id] = gw.game_time
	var rq: Dictionary = {"id": _req_id, "from": c.id, "res": res, "n": n, "price": unit, "until": gw.game_time + 60.0, "to": p.id}
	_req_id += 1
	requests.append(rq)
	gw.say(p, Loc.mk("{c} просит {res} ×{n} по {p} (ТОРГОВЛЯ)", {"c": Loc.name(c.name), "res": Loc.t(String(RES_NAMES[res]).to_lower()), "n": n, "p": unit}))
	request_added.emit(rq)
	_pending_changed()




func ai_blocked(c: Country, rc: Dictionary) -> void :
	var w: Dictionary = want.get(c.id, {})
	var wt: Dictionary = want_t.get(c.id, {})
	for res: String in rc:
		if int(c.get(res)) < int(rc[res]):
			w[res] = maxi(int(w.get(res, 0)), int(rc[res]))
			wt[res] = gw.game_time
	want[c.id] = w
	want_t[c.id] = wt
	if gw.game_time - float(_fix_t.get(c.id, -1000.0)) < 30.0:
		return
	for res: String in w:
		var kind: int = Facility.Kind.MINE
		if res == "oil":
			kind = Facility.Kind.OIL_RIG
		elif res == "uranium":
			kind = Facility.Kind.URANIUM_MINE
		elif res == "wood":
			kind = Facility.Kind.SAWMILL
		elif not ORE_TYPES.has(res):
			continue
		var cost: Dictionary = build_cost(kind)
		if not c.has_res(cost) or c.money < int(cost["money"]) + 150:
			continue
		_fix_t[c.id] = gw.game_time
		var f: Facility = ai_place(c, kind, res)
		if f != null:
			c.money -= int(cost["money"])
			pay_build(c, kind)
			return

	if not ports.has_port(c) and not w.is_empty():
		var pcost: Dictionary = build_cost(Facility.Kind.PORT)
		if c.has_res(pcost) and c.money >= int(pcost["money"]) + 150:
			_fix_t[c.id] = gw.game_time
			if ai_place(c, Facility.Kind.PORT) != null:
				c.money -= int(pcost["money"])
				pay_build(c, Facility.Kind.PORT)


func can_reach(a: Country, b: Country) -> bool:
	if a.capital_id < 0 or b.capital_id < 0:
		return false
	var key: String = Diplomacy.key(a.id, b.id)
	var e: Array = _reach.get(key, [])
	if not e.is_empty() and gw.game_time - float(e[0]) < (240.0 if bool(e[1]) else 120.0):
		return bool(e[1])
	if ui_time():
		var eu: Array = _reach_ui.get(key, [])
		if not eu.is_empty() and gw.game_time - float(eu[0]) < (240.0 if bool(eu[1]) else 120.0):
			return bool(eu[1])
	var ok: bool = ports.can_sail(a, b)
	var rail: Variant = gw.get("rail")
	if not ok and rail is Object and (rail as Object).has_method("has_link"):
		ok = bool((rail as Object).call("has_link", a.capital_id, b.capital_id))
	if not ok:
		ok = not land_path(Vector2(gw.cities[a.capital_id].entrance * GameWorld.CELL), Vector2(gw.cities[b.capital_id].entrance * GameWorld.CELL)).is_empty()
	if not ui_time():
		_reach[key] = [gw.game_time, ok]
	else:
		_reach_ui[key] = [gw.game_time, ok]
	return ok



static func is_eco_site(kind: int) -> bool:
	return kind == Facility.Kind.MINE or kind == Facility.Kind.OIL_RIG or kind == Facility.Kind.SAWMILL\
	or kind == Facility.Kind.PORT or kind == Facility.Kind.PORT_CRANE or kind == Facility.Kind.NAVAL_BASE or kind == Facility.Kind.URANIUM_MINE



func ai_place(c: Country, kind: int, prefer: String = "") -> Facility:
	var mil: Military = gw.mil
	match kind:
		Facility.Kind.MINE, Facility.Kind.OIL_RIG, Facility.Kind.URANIUM_MINE:
			var types: Array = ["oil"] if kind == Facility.Kind.OIL_RIG else (["uranium"] if kind == Facility.Kind.URANIUM_MINE else ORE_TYPES)
			var best: Dictionary = {}
			var bs: float = -1.0
			for dp: Dictionary in deposits:
				if dp["mine"] != null or int(dp.get("left", 0)) <= 0 or not types.has(String(dp.get("res", ""))):
					continue
				var cell: Vector2i = dp["cell"]
				if gw.data.get_owner_id(cell.x, cell.y) != c.id:
					continue
				var res: String = String(dp["res"])
				var sc: float = float(need(c, res) + 1) * float(market_price(res)) + (1000.0 if res == prefer else 0.0)
				if sc > bs and mil.check_place(kind, Military.nw_for(kind, cell), c, null, false) == "":
					bs = sc
					best = dp
			if best.is_empty():
				return null
			return mil.build(kind, best["cell"], c, null, true)
		Facility.Kind.SAWMILL:
			var bp: = Vector2i(-1, -1)
			var bt: int = SAW_MIN_TREES - 1
			for cid in c.city_ids:
				var city: City = gw.cities[cid]
				for r in range(city.radius + 6, city.radius + 46, 8):
					for a in range(0, 360, 30):
						var p: Vector2i = city.center + Vector2i(roundi(cos(deg_to_rad(a)) * r), roundi(sin(deg_to_rad(a)) * r))
						if not gw.data.inside(p.x, p.y) or gw.data.get_owner_id(p.x, p.y) != c.id:
							continue
						var t: int = count_trees(p, SAW_R, 3)
						if t > bt and mil.check_place(kind, Military.nw_for(kind, p), c, null, false) == "":
							bt = t
							bp = p
			return mil.build(kind, bp, c, null, true) if bp.x >= 0 else null
		Facility.Kind.PORT:
			var p2: Vector2i = ports.find_site(c, true)
			return mil.build(kind, p2, c, null, true) if p2.x >= 0 else null
		Facility.Kind.NAVAL_BASE:
			var p4: Vector2i = gw.navy.find_base_site(c) if gw.get("navy") != null else Vector2i(-1, -1)
			return mil.build(kind, p4, c, null, true) if p4.x >= 0 else null
		Facility.Kind.PORT_CRANE:
			var port: Facility = ports.port_of(c)
			if port == null:
				return null
			var pc: Vector2i = port.cell + port.size / 2
			for r in range(6, Ports.PORT_REACH, 2):
				for a in range(0, 360, 20):
					var p3: Vector2i = pc + Vector2i(roundi(cos(deg_to_rad(a)) * r), roundi(sin(deg_to_rad(a)) * r))
					if mil.check_place(kind, Military.nw_for(kind, p3), c, port, false) == "":
						return mil.build(kind, p3, c, port, true)
	return null




func substitute_cost(cost: Dictionary, p: Country) -> Dictionary:
	var out: Dictionary = cost.duplicate()
	out["money"] = int(out.get("money", 0))
	if p == null:
		return out
	for res: String in SUB_ORDER:
		var n: int = int(out.get(res, 0))
		if n <= 0:
			continue
		var lack: int = n - maxi(0, int(p.get(res)))
		if lack <= 0:
			continue
		out[res] = n - lack
		if SUB_RULES.has(res):
			var rule: Dictionary = SUB_RULES[res]
			for k: String in rule:
				out[k] = int(out.get(k, 0)) + int(rule[k]) * lack
		else:
			out["money"] = int(out["money"]) + int(ceil(float(market_price(res)) * SUB_MONEY_K * float(lack)))
	for k: String in out.keys():
		if k != "money" and int(out[k]) <= 0:
			out.erase(k)
	return out



func can_substitute(cost: Dictionary, p: Country) -> bool:
	if p == null or p.has_res(cost):
		return false
	return p.has_res(substitute_cost(cost, p))



func substitute_note(cost: Dictionary, p: Country) -> String:
	if p == null or p.has_res(cost):
		return ""
	var sub: Dictionary = substitute_cost(cost, p)
	var gone: PackedStringArray = PackedStringArray()
	var added: PackedStringArray = PackedStringArray()
	for k: String in cost:
		if k != "money" and int(cost[k]) > int(sub.get(k, 0)):
			gone.append("%s %d" % [Loc.t(String(RES_NAMES.get(k, k)).to_lower()), int(cost[k]) - int(sub.get(k, 0))])
	for k: String in sub:
		if k == "money":
			continue
		var extra: int = int(sub[k]) - int(cost.get(k, 0))
		if extra > 0:
			added.append("%s %d" % [Loc.t(String(RES_NAMES.get(k, k)).to_lower()), extra])
	var dm: int = int(sub["money"]) - int(cost.get("money", 0))
	if dm > 0:
		added.append("+%d" % dm)
	return Loc.t("ЗАМЕНИТЬ: %s → %s") % [", ".join(gone), " ".join(added)]




func pay_substituted(c: Country, cost: Dictionary, stat_key: String = "build") -> String:
	var pay: Dictionary = cost
	if not c.has_res(cost):
		pay = substitute_cost(cost, c)
		if not c.has_res(pay):
			return Loc.t("Не хватает даже с заменой: %s") % [c.missing_res(pay)]
	c.pay_res(pay)
	stat_add(c, "spend", stat_key, int(cost.get("money", 0)))
	var extra: int = int(pay.get("money", 0)) - int(cost.get("money", 0))
	if extra > 0:
		stat_add(c, "spend", "subst", extra)
	for res: String in pay:
		if res != "money" and int(pay[res]) > 0:
			stat_res(c, res, stat_key, - int(pay[res]))
	return ""



func upgrade(f: Facility, c: Country) -> String:
	if f == null or c == null or not UPG_RES.has(f.kind):
		return Loc.t("Это здание не улучшается")
	if f.country_id != c.id:
		return Loc.t("Это не ваше здание")
	if f.level >= MAX_LEVEL:
		return Loc.t("Уже максимальный уровень")
	if not gw.mil.alive(f):
		return Loc.t("Сначала восстановите здание")
	if f.upg_t > 0.0:
		return Loc.t("Уже строится: %s") % deep_name(f, f.level + 1)
	var cost: Dictionary = upgrade_cost(f)
	if not c.has_res(cost):
		return Loc.t("Не хватает: %s") % c.missing_res(cost)
	c.pay_res(cost)
	stat_add(c, "spend", "upgrade", int(cost.get("money", 0)))
	for r: String in cost:
		if r != "money":
			stat_res(c, r, "upgrade", - int(cost[r]))
	if is_deep(f.kind):
		f.upg_t = float(DEEP_T[f.level + 1])
		draw_ver += 1
		gw.fx.spawn("build_spark", f.center_px(), 6)
		if gw._on_screen(f.center_px(), 40.0):
			Sfx.play("ui_build", f.center_px())
		gw.changed.emit()
		return ""
	f.level += 1
	_place_extra(f)
	_cap_bonus.erase(c.id)
	draw_ver += 1
	gw.fx.spawn("build_spark", f.center_px(), 6)
	if gw._on_screen(f.center_px(), 40.0):
		Sfx.play("ui_build", f.center_px())
	gw.changed.emit()
	return ""


func _place_extra(f: Facility) -> void :
	var names: Array = UPG_EXTRA.get(f.kind, [])
	var k: int = f.level - 2
	if k < 0 or k >= names.size():
		return
	var nm: String = names[k]
	var frame: int = 0
	if nm == "eco_ore_heap":
		frame = int({"metal": 0, "titanium": 1, "precious": 2}.get(out_res(f), 0))
	var d: WorldData = gw.data
	var cands: Array[Vector2i] = []
	for x in range(0, f.size.x - 1, 2):
		cands.append(f.cell + Vector2i(x, f.size.y))
	for y in range(0, f.size.y - 1, 2):
		cands.append(f.cell + Vector2i(f.size.x, y))
	for y in range(0, f.size.y - 1, 2):
		cands.append(f.cell + Vector2i(-2, y))
	for x in range(0, f.size.x - 1, 2):
		cands.append(f.cell + Vector2i(x, -2))
	for q: Vector2i in cands:
		var ok: bool = true
		for yy in range(q.y, q.y + 2):
			for xx in range(q.x, q.x + 2):
				if not d.inside(xx, yy) or d.get_owner_id(xx, yy) != f.country_id or Biome.is_water(d.get_biome(xx, yy))\
				or d.has_flag(xx, yy, WorldData.F_OCCUPIED | WorldData.F_ROAD | WorldData.F_BRIDGE | WorldData.F_CITY):
					ok = false
		if not ok or not deposit_free_rect(Rect2i(q, Vector2i(2, 2))):
			continue
		for yy in range(q.y, q.y + 2):
			for xx in range(q.x, q.x + 2):
				gw.remove_tree_at(Vector2i(xx, yy))
				d.add_flag(xx, yy, WorldData.F_OCCUPIED)
		if not _extras.has(f):
			_extras[f] = []
		(_extras[f] as Array).append([nm, q, frame])
		return


func _rname(k: String) -> String:
	return Loc.t("деньги") if k == "money" else Loc.t(String(RES_NAMES.get(k, k)).to_lower())


func _lack_lines(cost: Dictionary, c: Country) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	for k: String in cost:
		var have: int = int(c.get(k))
		if int(cost[k]) > have:
			parts.append(Loc.t("%s %d (у вас %d): %s") % [_rname(k), int(cost[k]), have, String(RES_ADVICE.get(k, ""))])
	return parts


func _has_free_deposit(c: Country, types: Array) -> bool:
	for dp: Dictionary in deposits:
		if dp["mine"] == null and int(dp["left"]) > 0 and types.has(String(dp.get("res", ""))):
			var q: Vector2i = dp["cell"]
			if gw.data.get_owner_id(q.x, q.y) == c.id:
				return true
	return false


func _own(c: Country, kind: int) -> int:
	var n: int = 0
	for f: Facility in gw.mil.facilities:
		if f.country_id == c.id and f.kind == kind and gw.mil.alive(f):
			n += 1
	return n



func _own_halted(c: Country, kind: int) -> int:
	var n: int = 0
	for f: Facility in gw.mil.facilities:
		if f.country_id == c.id and f.kind == kind and f.halted and gw.mil.alive(f):
			n += 1
	return n





func build_hint(kind: int, c: Country, notes_only: bool = false) -> String:
	if c == null:
		return ""
	var title: String = Military.title_of(kind) if Military.TITLES.has(kind) else Loc.t("Здание")
	var out: PackedStringArray = PackedStringArray()
	var lack: PackedStringArray = _lack_lines(build_cost(kind), c)
	if not lack.is_empty() and not notes_only:
		out.append(Loc.t("%s: нужно %s") % [title, "; ".join(lack)])
	match kind:
		Facility.Kind.MINE:
			if not _has_free_deposit(c, ORE_TYPES):
				out.append(Loc.t("На вашей земле нет свободной залежи руды — расширяйте границы городом к значку руды."))
		Facility.Kind.URANIUM_MINE:
			if not _has_free_deposit(c, ["uranium"]):
				out.append(Loc.t("На вашей земле нет свободной залежи урана (зелёный значок) — она редкая: расширяйте границы к ней или покупайте уран."))
		Facility.Kind.NUCLEAR_PLANT:
			out.append(Loc.t("АЭС: сетки и бетон её не защищают — ставьте рядом ЗРК и ПРО. +%d энергии, 1 уран на %d с работы.") % [Nuclear.NPP_CAP, int(Nuclear.FUEL_S)])
		Facility.Kind.OIL_RIG:
			if not _has_free_deposit(c, ["oil"]):
				out.append(Loc.t("На вашей земле нет нефтяной залежи (чёрный значок) — расширяйте границы или покупайте нефть."))
		Facility.Kind.SAWMILL:
			if lack.is_empty() and _own(c, kind) == 0 and not notes_only:
				out.append(Loc.t("Ставьте у леса: нужно от %d деревьев рядом, лесопилка вырубает их постепенно.") % SAW_MIN_TREES)
		Facility.Kind.PORT:
			if ports.find_site(c).x < 0:
				out.append(Loc.t("Порт строится на берегу моря на вашей земле, вплотную к воде: свободного берега нет."))
		Facility.Kind.PORT_CRANE:
			if not ports.has_port(c):
				out.append(Loc.t("Кран ставится рядом с вашим портом: сначала постройте порт."))
		Facility.Kind.REFINERY:
			if c.oil < 10 and _own(c, Facility.Kind.OIL_RIG) == 0:
				out.append(Loc.t("НПЗ перерабатывает нефть в топливо: без нефтевышки или закупок нефти он будет стоять."))
		Facility.Kind.DRONE_FACTORY:
			if c.metal < 15:
				out.append(Loc.t("Каждый дрон стоит металл %d: нужен %s.") % [int(RES_COST["drone"]["metal"]), RES_ADVICE["metal"]])
		Facility.Kind.MISSILE_FACTORY:
			if c.titanium < 10:
				out.append(Loc.t("Ракеты делаются из титана (баллистическая — %d): нужен %s.") % [int(RES_COST["missile_0"]["titanium"]), RES_ADVICE["titanium"]])
		Facility.Kind.AIRFIELD:
			if c.titanium < 20 or c.precious < 1:
				out.append(Loc.t("Самолёты: титан 10–60 и драгметаллы для истребителей и бомбардировщиков."))

	if Military.uses_power(kind) and c.power_cap - c.power_use < 1:
		out.append(Loc.t("Нужна 1 энергия, а сеть занята (%d/%d): сначала ТЭЦ или солнечная станция, иначе здание будет стоять.") % [c.power_use, c.power_cap])
	match kind:
		Facility.Kind.REFINERY:
			if c.oil >= 10 and _own(c, Facility.Kind.OIL_RIG) == 0:
				out.append(Loc.t("Цепочка: нефтевышка → нефть → НПЗ → топливо. Без вышки НПЗ встанет, когда кончится запас нефти."))
		Facility.Kind.OIL_RIG:
			if _own(c, Facility.Kind.REFINERY) == 0:
				out.append(Loc.t("Дальше — НПЗ: он делает из нефти топливо, которое продаётся дороже (на постройку нужна нефть 20)."))
		Facility.Kind.DRONE_FACTORY:
			if _own(c, Facility.Kind.DRONE_PORT) == 0:
				out.append(Loc.t("Готовые дроны садятся в дронопорт — без него завод ждёт."))
	return "\n".join(out)



func next_tip(c: Country) -> String:
	if c == null or c.eliminated or c.capital_id < 0:
		return ""
	var guide: Variant = gw.get("guide")
	if guide != null and c.is_player:
		var gt: String = (guide as EconGuide).tip(c, true)
		if gt != "":
			return gt


		if EconGuide.plan_visible:
			var pt: String = (guide as EconGuide).tip(c, false)
			if pt != "":
				return pt
	var st_tip: String = _stall_tip(c)
	if st_tip != "":
		return st_tip
	if _own(c, Facility.Kind.SAWMILL) == 0 and c.wood < 30:
		return Loc.t("Дерево кончается: поставьте лесопилку у леса — дерево нужно почти для всех построек.")
	if _own(c, Facility.Kind.REFINERY) > _own_halted(c, Facility.Kind.REFINERY) and c.oil < 1:
		return Loc.t("НПЗ стоит без нефти: нефтевышка на чёрном значке или купите нефть в торговле.")
	for dp: Dictionary in deposits:
		if dp["mine"] != null or int(dp["left"]) <= 0:
			continue
		var q: Vector2i = dp["cell"]
		if gw.data.get_owner_id(q.x, q.y) == c.id:
			var r: String = String(dp.get("res", ""))
			return Loc.t("На вашей земле есть залежь: %s — поставьте %s прямо на значок.") % [_rname(r), Loc.t("нефтевышку") if r == "oil" else Loc.t("рудник")]
	var sh: Array = shortages(c).filter( func(a: Array) -> bool: return int(c.get(String(a[0]))) < res_cap(c, String(a[0])))
	if not sh.is_empty():
		var r2: String = sh[0][0]
		return Loc.t("Не хватает: %s %d — %s.") % [_rname(r2), int(sh[0][1]), String(RES_ADVICE.get(r2, ""))]
	for r3: String in RAW:
		if int(c.get(r3)) >= res_cap(c, r3):
			if ports.has_port(c):
				return Loc.t("Склад «%s» полон: продайте излишки в торговле — порт вывозит их и сам.") % _rname(r3)
			return Loc.t("Склад «%s» полон: продайте излишки в торговле или постройте порт — он вывозит излишки за рубеж.") % _rname(r3)
	if not requests_for(c.id).is_empty():
		var rq: Dictionary = requests_for(c.id)[0]
		var fc: Country = gw.country_by_id(int(rq["from"]))
		return Loc.t("%s просит %s ×%d дороже рынка — ответьте в окне торговли.") % [fc.name if fc != null else Loc.t("Сосед"), _rname(String(rq["res"])), int(rq["n"])]
	for f: Facility in gw.mil.facilities:
		if f.country_id == c.id and UPG_RES.has(f.kind) and f.level < MAX_LEVEL and gw.mil.alive(f) and not f.halted:
			var cost: Dictionary = upgrade_cost(f)
			if c.has_res(cost) and c.money >= int(cost["money"]) + 800:
				return Loc.t("Можно улучшить «%s» до уровня %d: выпуск ×%.1f.") % [Military.title_of(f.kind), f.level + 1, float(LEVEL_MUL[f.level + 1])]
	if guide != null and c.is_player:
		return (guide as EconGuide).tip(c, false)
	return ""


func _stall_tip(c: Country) -> String:
	var mil: Military = gw.mil
	for f: Facility in mil.facilities:
		if f.country_id != c.id or f.halted or not mil.alive(f):
			continue
		var miss: String = ""
		var what: String = ""
		match f.kind:
			Facility.Kind.BARRACKS:
				miss = gw.army.wait_res(f)
				if miss != "":
					what = Loc.t("Казармы стоят")
			Facility.Kind.MISSILE_FACTORY:
				var t: int = f.prod_type
				if not f.producing and c.missile_stock[t] < int(Military.MT_CAP[t]) and mil.has_carrier(c, t):
					var rc: Dictionary = res_cost("missile_%d" % t)
					rc["money"] = int(Military.MT_COST[t])
					miss = c.first_missing(rc)
					what = Loc.t("Ракетный завод стоит")
			Facility.Kind.DRONE_FACTORY:
				if not f.producing and mil.stock_count(c.id) < mil.drone_capacity(c.id):
					miss = c.first_missing(mil.drone_cost(f.prod_type == 1))
					what = Loc.t("Завод дронов стоит")
		if miss == "" or miss == "money":
			continue
		return Loc.t("%s: нет %s — %s.") % [what, Army.res_gen(miss), String(STALL_FIX.get(miss, "купите на рынке"))]
	for r: String in RAW:
		if int(c.get(r)) >= res_cap(c, r):
			if ports.has_port(c):
				return Loc.t("Склад «%s» полон — продайте излишки в торговле (порт вывозит их и сам) или стройте.") % _rname(r)
			return Loc.t("Склад «%s» полон — продайте излишки в торговле или стройте: постройки тратят сырьё.") % _rname(r)
	return ""


func autobuy_get(c: Country, res: String) -> Dictionary:
	var d: Dictionary = (autobuy.get(str(c.id), {}) as Dictionary).get(res, {}) if c != null else {}
	var cap: int = res_cap(c, res) if c != null else 100
	var out: Dictionary = {"on": bool(d.get("on", false)), "lo": int(d.get("lo", roundi(cap * 0.25 / 5.0) * 5)), 
		"hi": int(d.get("hi", roundi(cap * 0.7 / 5.0) * 5)), "max": int(d.get("max", roundi(float(PRICE.get(res, 10)) * 1.6)))}
	out["hi"] = clampi(int(out["hi"]), 10, maxi(10, cap))
	out["lo"] = clampi(int(out["lo"]), 0, int(out["hi"]) - 5)
	out["max"] = maxi(1, int(out["max"]))
	return out



func autobuy_set(c: Country, res: String, key: String, value: Variant) -> void :
	if c == null or not AB_RES.has(res):
		return
	var cur: Dictionary = autobuy_get(c, res)
	match key:
		"on":
			cur["on"] = bool(value)
		"lo", "hi", "max":
			cur[key] = int(value)
	var cap: int = res_cap(c, res)
	cur["hi"] = clampi(int(cur["hi"]), 10, maxi(10, cap))
	cur["lo"] = clampi(int(cur["lo"]), 0, int(cur["hi"]) - 5)
	cur["max"] = clampi(int(cur["max"]), 1, 9999)
	var k: String = str(c.id)
	if not autobuy.has(k):
		autobuy[k] = {}
	(autobuy[k] as Dictionary)[res] = cur
	if key == "on":
		_ab_cd.erase("%d:%s" % [c.id, res])
		_ab_status["%d:%s" % [c.id, res]] = Loc.mk("ВКЛЮЧЕНО") if bool(value) else ""


func autobuy_status(c: Country, res: String) -> String:
	return Loc.msg(_ab_status.get("%d:%s" % [c.id, res], "")) if c != null else ""




func autobuy_warn(c: Country, res: String) -> bool:
	if c == null:
		return false
	var v: Variant = _ab_status.get("%d:%s" % [c.id, res], "")
	if Loc.is_msg(v):
		return Loc.id(v) in ["ЖДЁТ: ЦЕНА %d > %d", "НЕТ ПРОДАВЦА", "НЕТ ПУТИ", "НЕТ ДЕНЕГ (РЕЗЕРВ %d)"]
	var s: String = String(v)
	return s.begins_with("ЖДЁТ") or s.begins_with("НЕТ")



func autobuy_lines(c: Country, n: int = 2) -> Array:
	var out: Array = []
	for i in range(autobuy_log.size() - 1, -1, -1):
		var e: Dictionary = autobuy_log[i]
		if c != null and int(e.get("c", -1)) == c.id:
			out.append([Loc.msg(e.get("text", "")), float(e.get("t", 0.0)), String(e.get("res", ""))])
			if out.size() >= n:
				break
	return out


func _autobuy_country(c: Country, cfg: Dictionary) -> void :
	var budget: int = int(float(c.money - AB_FLOOR) * AB_SHARE)
	var now: float = gw.game_time
	for res: String in AB_RES:
		var s: Dictionary = cfg.get(res, {})
		if not bool(s.get("on", false)):
			continue
		var key: String = "%d:%s" % [c.id, res]
		var lo: int = int(s.get("lo", 0))
		var hi: int = int(s.get("hi", 0))
		var have: int = int(c.get(res)) + inbound(c, res)
		if have >= lo:
			_ab_status[key] = Loc.mk("ЗАПАС В НОРМЕ")
			continue
		if now < float(_ab_cd.get(key, -1.0)):
			continue
		var want: int = mini(hi - have, room_for(c, res))
		if want <= 0:
			_ab_status[key] = Loc.mk("СКЛАД ПОЛОН")
			continue
		var mx: int = int(s.get("max", 9999))
		var seller: Country = best_seller(c, res)
		var u_s: int = maxi(1, roundi(market_price(res) * gw.diplo.trade_mul(c.id, seller.id))) if seller != null else 999999
		var port: bool = ports.has_port(c)
		var u_p: int = foreign_buy_price(res, c.id) if port else 999999
		var unit: int = mini(u_s, u_p)
		if unit >= 999999:
			_ab_status[key] = Loc.mk("НЕТ ПРОДАВЦА") if not port else Loc.mk("НЕТ ПУТИ")
			continue
		if unit > mx:
			_ab_status[key] = Loc.mk("ЖДЁТ: ЦЕНА %d > %d", [unit, mx])
			continue
		if budget < unit:
			_ab_status[key] = Loc.mk("НЕТ ДЕНЕГ (РЕЗЕРВ %d)", [AB_FLOOR])
			continue
		var n: int = mini(want, budget / unit)
		if n < mini(5, want):
			_ab_status[key] = Loc.mk("МАЛО ДЕНЕГ (РЕЗЕРВ %d)", [AB_FLOOR])
			continue
		var m0: int = c.money
		var i0: int = inbound(c, res)
		var why: String = ""
		gw.set_block_signals(true)
		if u_s <= u_p:
			why = buy(c, seller, res, n)
			if why != "" and port and u_p <= mx:
				why = ports.import_order(c, res, mini(n, maxi(0, c.money - AB_FLOOR) / u_p))
				unit = u_p
		else:
			why = ports.import_order(c, res, n)
		gw.set_block_signals(false)
		_ab_cd[key] = now + AB_CD
		if why != "":
			_ab_status[key] = why.to_upper()
			continue
		var got: int = maxi(inbound(c, res) - i0, 0)
		var paid: int = m0 - c.money
		if got == 0:
			got = paid / maxi(1, unit)
		if got <= 0:
			continue
		budget -= maxi(paid, got * unit)
		var line: Array = Loc.mk("куплено %d %s по %d", [got, String(RES_GEN.get(res, res)), unit])
		autobuy_log.append({"c": c.id, "t": now, "text": line, "res": res})
		while autobuy_log.size() > 16:
			autobuy_log.remove_at(0)
		_ab_status[key] = Loc.mk("КУПЛЕНО %d", [got])
		if c.is_player and now - _ab_msg_t >= 90.0:
			_ab_msg_t = now
			gw.say(c, Loc.mk("Автозакупка: %s", [Loc.msg(line)]))





func price_trend(res: String) -> Dictionary:
	var hist: = PackedFloat32Array()
	var sup: Object = gw.get("supply") as Object
	if sup != null and sup.has_method("history"):
		var h: Variant = sup.call("history", res)
		if h is PackedFloat32Array:
			hist = h
		elif h is Array:
			for v: Variant in h:
				hist.append(float(v))
	if hist.size() < 2:
		hist = PackedFloat32Array()
		for v: Variant in _px_hist.get(res, []):
			hist.append(float(v))
	var p: int = market_price(res)
	var out: Dictionary = {"price": p, "pct": 0, "dir": 0, "reason": "", "hist": hist, "crisis": false}
	if hist.size() >= 2:
		var ref: float = hist[maxi(0, hist.size() - 9)]
		if ref > 0.0:
			out["pct"] = roundi((float(p) - ref) / ref * 100.0)
	var pct: int = int(out["pct"])
	out["dir"] = 1 if pct >= 3 else (-1 if pct <= -3 else 0)
	if sup != null and sup.has_method("crises"):
		var best: float = -1.0
		var cr: Variant = sup.call("crises")
		if cr is Array:
			for e: Variant in cr:
				if e is Dictionary and String((e as Dictionary).get("commodity", "")) == res and float((e as Dictionary).get("level", 0.0)) > best:
					best = float((e as Dictionary).get("level", 0.0))
					out["reason"] = Loc.tx(String((e as Dictionary).get("reason_ru", "")))
					out["crisis"] = true
	if String(out["reason"]) == "":
		var base: int = int(PRICE.get(res, p))
		if p >= roundi(base * 1.4):
			out["reason"] = Loc.t("дефицит на рынке")
		elif p <= roundi(base * 0.8):
			out["reason"] = Loc.t("избыток на рынке")
		elif int(out["dir"]) > 0:
			out["reason"] = Loc.t("спрос растёт")
		elif int(out["dir"]) < 0:
			out["reason"] = Loc.t("предложение растёт")
	return out







func upkeep_breakdown(c: Country) -> Dictionary:
	if c == null or upk == null:
		return {}
	var tl: Dictionary = upk.tally(c.id)
	var r: float = upk.ramp()
	var cls: Dictionary = {}
	for k: String in tl["cls"]:
		var e: Array = tl["cls"][k]
		cls[k] = {"money_min": roundi(float(e[0]) * r), "n": int(e[1]), "mothballed": int(e[2])}
	return {"money_min": roundi(float(tl["money"]) * r), "money_full": roundi(float(tl["money"])), "classes": cls, 
		"free_min": roundi(float(tl.get("free", 0.0)) * r), 
		"fuel_min": snappedf(float(tl["fuel"]) * r, 0.1), "metal_min": snappedf(float(tl["metal"]) * r, 0.1), 
		"mothballed": int(tl["mb"]), "reactivating": int(tl["react"])}



func upkeep_forecast(c: Country) -> Dictionary:
	return upk.forecast(c) if c != null and upk != null else {}



func sale_preview(c: Country, res: String, n: int) -> Dictionary:
	if c == null or upk == null:
		return {}
	return upk.sale_preview(c, res, maxi(0, n), maxi(1, int(market_price(res) * FOREIGN_SELL)))



func unit_supply(u: Unit) -> int:
	return upk.unit_supply(u) if upk != null and u != null else 0


func site_supply(f: Facility) -> int:
	return upk.site_supply(f) if upk != null and f != null else 0



func army_supply(c: Country) -> Dictionary:
	return upk.army_supply(c.id) if upk != null and c != null else {}



func occupied_at(cell: Vector2i, c: Country) -> bool:
	return upk != null and upk.occupied(cell, c)
