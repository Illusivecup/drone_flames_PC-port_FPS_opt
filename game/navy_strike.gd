extends RefCounted









static func _owner_at(gw: GameWorld, p: Vector2) -> int:
	var cx: int = floori(p.x / GameWorld.CELL)
	var cy: int = floori(p.y / GameWorld.CELL)
	return gw.data.get_owner_id(cx, cy) if gw.data.inside(cx, cy) else 0


static func _cname(gw: GameWorld, cid: int) -> String:
	var c: Country = gw.country_by_id(cid)
	return c.name if c != null else "?"





static func plan(gw: GameWorld, cid: int, targets: Array) -> Dictionary:
	var out: Dictionary = {"ok": false, "total": 0, "available": 0, "assigned": 0, "ships": 0, "in_range": 0, 
		"per_target": [], "plan": [], "shooters": [], "peace": [], "why": ""}
	var nv: Navy = gw.get("navy") as Navy
	if nv == null or cid <= 0:
		out["why"] = Loc.t("Нет флота")
		return out
	var free: Dictionary = {}
	for s: Ship in nv.ships_of(cid, true):
		if s.has_mod("vls"):
			out["ships"] = int(out["ships"]) + 1
			var k: int = int(s.ammo.get("cm", 0))
			if k > 0:
				free[s] = k
				out["available"] = int(out["available"]) + k
	if not targets.is_empty():
		var cur: Vector2 = (targets[targets.size() - 1] as Dictionary)["pos"]
		for s0: Ship in free:
			if s0.pos.distance_to(cur) <= Navy.CM_RANGE:
				out["in_range"] = int(out["in_range"]) + int(free[s0])
	var used: Dictionary = {}
	var peace: Dictionary = {}
	for t: Dictionary in targets:
		var p: Vector2 = t["pos"]
		var n: int = int(t["n"])
		out["total"] = int(out["total"]) + n
		var own: int = _owner_at(gw, p)
		var reason: String = ""


		if own > 0 and own != cid and gw.diplo != null and gw.diplo.has_method("subject_of") and (gw.diplo.subject_of(own) == cid or gw.diplo.subject_of(cid) == own):
			reason = Loc.t("Вассальная пара: войны нет")
		var got: int = 0
		if reason == "":
			for i in n:
				var best: Ship = null
				var bd: float = INF
				for s: Ship in free:
					if int(free[s]) <= 0:
						continue
					var d: float = s.pos.distance_to(p)
					if d > Navy.CM_RANGE:
						continue
					if best == null or int(free[s]) > int(free[best]) or (int(free[s]) == int(free[best]) and d < bd):
						best = s
						bd = d
				if best == null:
					break
				free[best] = int(free[best]) - 1
				(out["plan"] as Array).append([best.id, p])
				used[best] = true
				got += 1
			if got > 0 and own > 0 and own != cid and not nv._hostile(cid, own) and not peace.has(own):
				peace[own] = true
				(out["peace"] as Array).append({"id": own, "name": _cname(gw, own), "note": war_note(gw, cid, own)})
			if got == 0:
				reason = Loc.t("Нет корабля с КР ближе %.1f км") % (Navy.CM_RANGE / 1000.0)
			elif got < n:
				reason = Loc.t("Не хватает КР в досягаемости")
		(out["per_target"] as Array).append({"ok": got == n, "reason": reason, "n": n, "got": got, "pos": p})
		out["assigned"] = int(out["assigned"]) + got
	for s2: Ship in used:
		(out["shooters"] as Array).append(s2.name)
	out["ok"] = int(out["assigned"]) > 0
	if int(out["ships"]) == 0:
		out["why"] = Loc.t("Нет кораблей с УВП: верфь › тяжёлый корпус + УВП")
	elif int(out["available"]) == 0:
		out["why"] = Loc.t("Нет крылатых ракет: пополните у морской базы")
	return out



static func launch(gw: GameWorld, cid: int, targets: Array) -> Dictionary:
	var mp: Dictionary = plan(gw, cid, targets)
	var nv: Navy = gw.navy
	var res: Dictionary = {"launched": 0, "ships": 0, "wars": []}
	for e: Dictionary in mp["peace"]:
		var why: String = ensure_war(gw, cid, int(e["id"]))
		if why != "":
			gw.message.emit(why)
		else:
			(res["wars"] as Array).append(String(e["name"]))
	var per: Dictionary = {}
	for a: Array in mp["plan"]:
		var k: String = "%d|%.1f|%.1f" % [int(a[0]), (a[1] as Vector2).x, (a[1] as Vector2).y]
		if not per.has(k):
			per[k] = [int(a[0]), a[1], 0]
		per[k][2] = int(per[k][2]) + 1
	var who: Dictionary = {}
	var order: Dictionary = {}
	for k2: String in per:
		var e2: Array = per[k2]
		var s: Ship = nv.ship(int(e2[0]))
		if not order.has(int(e2[0])):
			order[int(e2[0])] = float(order.size()) * Navy.CM_SHIP_GAP
		var got: int = nv.launch_cruise(s, e2[1], int(e2[2]), float(order[int(e2[0])])) if s != null else 0
		res["launched"] = int(res["launched"]) + got
		if got > 0:
			who[s.id] = true
	res["ships"] = who.size()
	return res



static func blocked(gw: GameWorld, me: int, other: int) -> String:
	var dp: Diplomacy = gw.diplo
	if dp == null or other <= 0 or other == me:
		return ""
	if dp.has_method("subject_of"):
		if dp.subject_of(other) == me:
			return Loc.t("%s — это ваш вассал") % _cname(gw, other)
		if dp.subject_of(me) == other:
			return Loc.t("%s — это ваш сюзерен") % _cname(gw, other)
	if dp.allied(me, other):
		return Loc.t("%s — союзник") % _cname(gw, other)
	if dp.has_method("strike_block") and dp.strike_block(me, other) != "":
		return Loc.t("войска на чужой земле — сначала вывод")
	return ""




static func war_note(gw: GameWorld, me: int, other: int) -> String:
	if other <= 0 or other == me or gw.diplo == null:
		return ""
	var nv: Navy = gw.get("navy") as Navy
	if nv != null and nv._hostile(me, other):
		return ""
	var blk: String = blocked(gw, me, other)
	if blk != "":
		return Loc.t("Нельзя: %s") % [blk]
	var dp: Diplomacy = gw.diplo
	var t: String = Loc.t("%s: удар начнёт войну") % _cname(gw, other)
	var burn: PackedStringArray = []
	if dp.allied(me, other):
		burn.append(Loc.t("союз"))
	for k: String in dp.treaties_of(me, other):
		if k != "alliance":
			burn.append(String((Diplomacy.TREATY_INFO.get(k, {}) as Dictionary).get("short", k)).to_lower())
	if dp.has_method("has_passage") and (dp.has_passage(me, other) or dp.has_passage(other, me)):
		burn.append(Loc.t("проход"))
	if dp.truce_on(me, other):
		burn.append(Loc.t("перемирие"))
	if not burn.is_empty():
		t += Loc.t(" · сгорят: %s") % [", ".join(burn)]
	if dp.has_treaty(me, other, "nap") or dp.has_treaty(me, other, "defense"):
		t += Loc.t(" · вероломство")
	var join: PackedStringArray = []
	for c: Country in gw.countries:
		if c.id == me or c.id == other or c.eliminated or dp.at_war(c.id, me) or dp.allied(c.id, me):
			continue
		if dp.allied(c.id, other) or dp.has_treaty(c.id, other, "defense"):
			join.append(c.name)
	if not join.is_empty():
		t += Loc.t(" · вступят: %s%s") % [", ".join(join.slice(0, 2)), (" +%d" % (join.size() - 2) if join.size() > 2 else "")]
	return t



static func ensure_war(gw: GameWorld, me: int, other: int) -> String:
	var nv: Navy = gw.navy
	if nv._hostile(me, other):
		return ""
	var blk: String = blocked(gw, me, other)
	if blk != "":
		return Loc.t("Нельзя: %s") % [blk]
	if gw.diplo == null:
		return Loc.t("Нет дипломатии")
	if not gw.diplo.at_war(me, other):
		gw.diplo.declare_war(me, other, "удар с моря")
	if nv._hostile(me, other):
		return ""
	return Loc.t("Войну с %s объявить нельзя") % _cname(gw, other)








static func _own_ships(gw: GameWorld, cid: int, sids: Array) -> Array[Ship]:
	var out: Array[Ship] = []
	if gw.navy == null:
		return out
	for v: Variant in sids:
		var s: Ship = gw.navy.ship(int(v))
		if s != null and s.c == cid and s.alive() and not out.has(s):
			out.append(s)
	return out



static func _fkey(s: Ship) -> int:
	return s.fleet if s.fleet != 0 else int(s.ord.get("rejoin", 0))




static func dock_order(gw: GameWorld, cid: int, plan: Array, kind: String, pos: Vector2, wps: Array) -> Array:
	var nv: Navy = gw.navy
	var ok: int = 0
	var why0: String = ""
	var keys: Array = []
	if nv == null:
		return [0, Loc.t("Нет флота"), keys]
	var j: int = 0
	for e: Variant in plan:
		if not (e is Array) or (e as Array).size() < 2:
			continue
		var k: int = int(e[0])
		var w: String = ""


		var gp: Vector2 = _spread_goal(nv, pos, j) if kind == "move" else pos
		j += 1
		if k > 0:
			w = nv.fleet_order(cid, k, kind, gp, -1.0, wps)
		elif k < 0:
			var one: Array[Ship] = _own_ships(gw, cid, [ - k])
			w = nv.ship_order(one[0], kind, gp, -1.0, wps) if not one.is_empty() else Loc.t("Корабль потерян")
		else:
			continue
		if w == "":
			ok += int(e[1])
			keys.append(k)
		elif why0 == "":
			why0 = w
	return [ok, why0, keys]



static func _spread_goal(nv: Navy, pos: Vector2, j: int) -> Vector2:
	var body: int = nv._body_px(pos)
	if body == 0:

		var q0: Vector2i = nv._sea_near(pos, 40)
		if q0.x >= 0:
			pos = nv._ports().cell_px(q0)
			body = nv._body_px(pos)
	if j <= 0:
		return pos
	var ring: int = 1 + (j - 1) / 6
	var a0: float = TAU * float((j - 1) % 6) / 6.0 + float(ring) * 0.5
	for da: float in [0.0, 0.5, -0.5, 1.0, -1.0]:
		var q: Vector2 = pos + Vector2.from_angle(a0 + da) * 56.0 * float(ring)
		if nv._body_px(q) != 0 and (body == 0 or nv._body_px(q) == body):
			return q
	return pos




static func _group(gw: GameWorld, cid: int, ss: Array[Ship], per_fleet: bool) -> Array:
	var in_ss: Dictionary = {}
	for s: Ship in ss:
		if _fkey(s) != 0:
			in_ss[_fkey(s)] = int(in_ss.get(_fkey(s), 0)) + 1
	var all_n: Dictionary = {}
	for s1: Ship in gw.navy.ships_of(cid, true):
		if _fkey(s1) != 0:
			all_n[_fkey(s1)] = int(all_n.get(_fkey(s1), 0)) + 1
	var plan: Array = []
	var done: Dictionary = {}
	for s2: Ship in ss:
		var fid: int = _fkey(s2)
		if per_fleet and fid != 0 and int(in_ss.get(fid, 0)) == int(all_n.get(fid, -1)):
			if done.has(fid) or s2.fleet == 0:
				continue
			done[fid] = true
			plan.append([fid, int(in_ss[fid])])
		else:
			plan.append([ - s2.id, 1])
	return plan




static func dock_attack(gw: GameWorld, cid: int, sids: Array, foe_id: int, salvo: int, per_fleet: bool) -> Array:
	var nv: Navy = gw.navy
	var foe: Ship = nv.ship(foe_id) if nv != null else null
	if foe == null or not foe.alive():
		return [0, 0, Loc.t("Цель потеряна")]
	if not nv._hostile(cid, foe.c):
		var why: String = ensure_war(gw, cid, foe.c)
		if why != "":
			return [0, 0, why]
	var ss: Array[Ship] = _own_ships(gw, cid, sids)
	var shooters: Array[Ship] = []
	for s: Ship in ss:
		if int(s.ammo.get("asm", 0)) > 0 and s.pos.distance_to(foe.pos) <= Navy.ASM_RANGE:
			shooters.append(s)
	var left: int = salvo
	var fired: int = 0
	for s1: Ship in shooters:
		if left <= 0:
			break
		var k: int = nv.launch_asm(s1, foe, maxi(1, ceili(float(left) / float(shooters.size()))))
		left -= k
		fired += k
	var close_in: Array[Ship] = []
	for s2: Ship in ss:
		s2.order_tgt = foe.id
		if s2.has_mod("gun") and not shooters.has(s2) and s2.pos.distance_to(foe.pos) > Navy.GUN_RANGE * 0.8:
			close_in.append(s2)
	var moved: int = 0
	if not close_in.is_empty():
		moved = int(dock_order(gw, cid, _group(gw, cid, close_in, per_fleet), "move", foe.pos, [])[0])
	return [fired, moved, ""]




static func dock_salvo(gw: GameWorld, cid: int, sids: Array, kind: String, target: Vector2, n: int, war_c: int) -> Array:
	var nv: Navy = gw.navy
	var ss: Array[Ship] = _own_ships(gw, cid, sids)
	var n_ok: int = 0
	if kind == "asm":
		if war_c > 0:
			var wy: String = ensure_war(gw, cid, war_c)
			if wy != "":
				return [0, wy]
		var shooters: Array[Ship] = []
		for s: Ship in ss:
			if int(s.ammo.get("asm", 0)) > 0 and s.pos.distance_to(target) <= Navy.ASM_RANGE:
				shooters.append(s)
		var left: int = n
		for s1: Ship in shooters:
			if left <= 0:
				break
			var k: int = nv.launch_asm_at(s1, target, maxi(1, ceili(float(left) / float(shooters.size()))))
			left -= k
			n_ok += k
		return [n_ok, "" if n_ok > 0 else Loc.t("ПКР не ушли")]
	if kind == "cm":
		var own: int = _owner_at(gw, target)
		if own > 0 and own != cid and not nv._hostile(cid, own):
			var wy2: String = ensure_war(gw, cid, own)
			if wy2 != "":
				return [0, wy2]
		var k2: int = 0
		for s2: Ship in ss:
			if s2.has_mod("vls") and int(s2.ammo.get("cm", 0)) > 0:
				n_ok += nv.launch_cruise(s2, target, 2, float(k2) * Navy.CM_SHIP_GAP)
				k2 += 1
		return [n_ok, "" if n_ok > 0 else Loc.t("КР не ушли")]
	return [0, Loc.t("Нет такого приказа")]



static func dock_sink(gw: GameWorld, cid: int, sids: Array, on: bool) -> int:
	var n: int = 0
	for s: Ship in _own_ships(gw, cid, sids):
		if s.fleet != 0:
			gw.navy.set_sink_neutral(s.fleet, on)
		else:
			s.ord["sink_n"] = on
			if int(s.ord.get("rejoin", 0)) != 0:
				gw.navy.set_sink_neutral(int(s.ord["rejoin"]), on)
		n += 1
	return n



static func dock_service(gw: GameWorld, cid: int, sid: int, key: String) -> String:
	var one: Array[Ship] = _own_ships(gw, cid, [sid])
	if one.is_empty():
		return Loc.t("Корабль потерян")
	return gw.navy.repair(one[0]) if key == "repair" else gw.navy.rearm(one[0], key)
