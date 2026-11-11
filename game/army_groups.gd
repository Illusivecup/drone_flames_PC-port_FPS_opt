extends RefCounted










const NAME_MAX: int = 12
const MAX_GROUPS: int = 12
const N_COLORS: int = 8
const EMBLEMS: Array[String] = ["emb_star", "emb_shield", "emb_arrow", "emb_bird", "emb_wolf", "emb_tower", "emb_bolt", "emb_spade"]




static func _country(gw: GameWorld, cid: int) -> Country:
	return gw.country_by_id(cid) if gw != null else null


static func groups(gw: GameWorld, cid: int) -> Array:
	var c: Country = _country(gw, cid)
	return c.army_groups if c != null else []


static func by_id(gw: GameWorld, cid: int, gid: int) -> Dictionary:
	for g: Dictionary in groups(gw, cid):
		if int(g.get("id", -1)) == gid:
			return g
	return {}



static func fac(gw: GameWorld, fid: int) -> Facility:
	var fl: Array = gw.mil.facilities
	if fid >= 0 and fid < fl.size():
		var f: Facility = fl[fid]
		if f != null and f.id == fid:
			return f
	for f2: Facility in fl:
		if f2.id == fid:
			return f2
	return null


static func valid_member(gw: GameWorld, cid: int, f: Facility) -> bool:
	return f != null and f.kind == Facility.Kind.BARRACKS and f.country_id == cid and army_alive(gw, f)





static func army_alive(gw: GameWorld, f: Facility) -> bool:
	if f == null or f.kind != Facility.Kind.BARRACKS or gw.mil == null or not gw.mil.facilities.has(f):
		return false
	if gw.mil.alive(f) or f.restore_t > 0.0:
		return true
	if gw.army == null:
		return false
	for u: Unit in gw.army.units:
		if u.home == f and u.alive() and u.country_id == f.country_id:
			return true
	return false


static func group_of(gw: GameWorld, cid: int, fid: int) -> Dictionary:
	var f: Facility = fac(gw, fid)
	if f != null and f.group_id >= 0:
		var g: Dictionary = by_id(gw, cid, f.group_id)
		if not g.is_empty() and (g["fids"] as PackedInt32Array).has(fid):
			return g
	for g2: Dictionary in groups(gw, cid):
		if (g2["fids"] as PackedInt32Array).has(fid):
			return g2
	return {}


static func next_id(gw: GameWorld, cid: int) -> int:
	var used: Dictionary = {}
	for g: Dictionary in groups(gw, cid):
		used[int(g["id"])] = true
	var i: int = 1
	while used.has(i):
		i += 1
	return i


static func default_name(gw: GameWorld, cid: int) -> String:
	return "Группа %d" % next_id(gw, cid)


static func _clean_name(s: String, fallback: String) -> String:
	var n: String = s.strip_edges().replace("\n", " ").left(NAME_MAX).strip_edges()
	return n if n != "" else fallback





static func _detach(gw: GameWorld, cid: int, fids: PackedInt32Array) -> void :
	for g: Dictionary in groups(gw, cid):
		var keep: = PackedInt32Array()
		for f: int in g["fids"]:
			if not fids.has(f):
				keep.append(f)
		g["fids"] = keep
	for fid: int in fids:
		var f2: Facility = fac(gw, fid)
		if f2 != null:
			f2.group_id = -1


static func _own_fids(gw: GameWorld, cid: int, fids: PackedInt32Array) -> PackedInt32Array:
	var out: = PackedInt32Array()
	for fid: int in fids:
		if not out.has(fid) and valid_member(gw, cid, fac(gw, fid)):
			out.append(fid)
	return out



static func create(gw: GameWorld, cid: int, gname: String, color: int, emblem: String, fids: PackedInt32Array) -> Dictionary:
	var c: Country = _country(gw, cid)
	if c == null or c.army_groups.size() >= MAX_GROUPS:
		return {}
	var own: PackedInt32Array = _own_fids(gw, cid, fids)
	_detach(gw, cid, own)
	var gid: int = next_id(gw, cid)
	var g: Dictionary = {"id": gid, "name": _clean_name(gname, "Группа %d" % gid), "color": clampi(color, 0, N_COLORS - 1), 
		"emblem": emblem if EMBLEMS.has(emblem) else "emb_star", "fids": own, "order": c.army_groups.size(), "created": gw.game_time}
	c.army_groups.append(g)
	for fid: int in own:
		fac(gw, fid).group_id = gid
	return g


static func add(gw: GameWorld, cid: int, gid: int, fids: PackedInt32Array) -> int:
	var g: Dictionary = by_id(gw, cid, gid)
	if g.is_empty():
		return 0
	var own: PackedInt32Array = _own_fids(gw, cid, fids)
	_detach(gw, cid, own)
	var cur: PackedInt32Array = g["fids"]
	var mode: Dictionary = {} if bool(g.get("ai", false)) else group_mode(gw, cid, cur, own)
	cur.append_array(own)
	g["fids"] = cur
	for fid: int in own:
		fac(gw, fid).group_id = gid
	if not mode.is_empty() and not own.is_empty():
		_adopt(gw, cid, g, own, mode)
	var frv: Variant = g.get("front", {})
	if frv is Dictionary and not (frv as Dictionary).is_empty() and gw.ops != null:

		for fid2: int in own:
			var op2: Dictionary = gw.ops.list.get(fac(gw, fid2), {})
			if not op2.is_empty() and int(op2["kind"]) != Operations.Kind.RETREAT:
				op2["front_take"] = true
	return own.size()







static func group_mode(gw: GameWorld, cid: int, fids: PackedInt32Array, skip: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var cnt: Array = [0, 0, 0]
	var first: int = -1
	var n: int = 0
	var ops: Dictionary = {}
	for fid: int in fids:
		var f: Facility = fac(gw, fid)
		if skip.has(fid) or not valid_member(gw, cid, f):
			continue
		var st: int = clampi(f.stance, 0, 2)
		cnt[st] += 1
		if first < 0:
			first = st
		n += 1
		var op: Dictionary = gw.ops.list.get(f, {}) if gw.ops != null else {}
		if not op.is_empty() and not bool(op.get("stance", false)) and int(op["kind"]) != Operations.Kind.RETREAT:
			var e: Array = ops.get(int(op["kind"]), [0, op["target"]])
			e[0] = int(e[0]) + 1
			ops[int(op["kind"])] = e
	if n == 0:
		return {}
	var best: int = first
	for s in 3:
		if int(cnt[s]) > int(cnt[best]):
			best = s
	var out: Dictionary = {"stance": best, "kind": -1, "target": Vector2.INF}
	for k: int in ops:
		if int(ops[k][0]) * 2 >= n:
			out["kind"] = k
			out["target"] = ops[k][1]
	return out



static func _adopt(gw: GameWorld, cid: int, g: Dictionary, own: PackedInt32Array, mode: Dictionary) -> void :
	var who: String = Loc.t("Группа «%s»") % String(g["name"])
	var diff: = PackedInt32Array()
	for fid: int in own:
		if fac(gw, fid).stance != int(mode["stance"]):
			diff.append(fid)
	if not diff.is_empty():
		set_stance(gw, cid, diff, int(mode["stance"]), who)
	var fr: Variant = g.get("front", {})
	if int(mode["kind"]) >= 0 and (mode["target"] as Vector2).is_finite() and ( not (fr is Dictionary) or (fr as Dictionary).is_empty()):
		order_fids(gw, cid, own, "defend" if int(mode["kind"]) == Operations.Kind.DEFEND else "move", mode["target"], who)


static func remove(gw: GameWorld, cid: int, fids: PackedInt32Array) -> void :
	_detach(gw, cid, fids)


static func edit(gw: GameWorld, cid: int, gid: int, gname: String, color: int, emblem: String) -> void :
	var g: Dictionary = by_id(gw, cid, gid)
	if g.is_empty():
		return
	g["name"] = _clean_name(gname, String(g["name"]))
	g["color"] = clampi(color, 0, N_COLORS - 1)
	if EMBLEMS.has(emblem):
		g["emblem"] = emblem


static func disband(gw: GameWorld, cid: int, gid: int) -> void :
	var c: Country = _country(gw, cid)
	var g: Dictionary = by_id(gw, cid, gid)
	if c == null or g.is_empty():
		return
	_detach(gw, cid, (g["fids"] as PackedInt32Array).duplicate())
	c.army_groups.erase(g)
	for i in c.army_groups.size():
		(c.army_groups[i] as Dictionary)["order"] = i




static func prune(gw: GameWorld, cid: int) -> bool:
	var c: Country = _country(gw, cid)
	if c == null or c.army_groups.is_empty():
		return false
	var changed: bool = false
	var seen: Dictionary = {}
	for g: Dictionary in c.army_groups:
		var gid: int = int(g["id"])
		var keep: = PackedInt32Array()
		for fid: int in g["fids"]:
			var f: Facility = fac(gw, fid)
			if seen.has(fid) or not valid_member(gw, cid, f):
				changed = true
				if f != null and f.group_id == gid and not seen.has(fid):
					f.group_id = -1
				continue
			seen[fid] = true
			keep.append(fid)
			if f.group_id != gid:
				f.group_id = gid
		g["fids"] = keep
	return changed




static func sanitize(gw: GameWorld) -> void :
	if gw == null or gw.mil == null:
		return
	var fpl: Variant = load("res://game/front_plan.gd")
	if fpl != null:
		fpl.reset()
	for f: Facility in gw.mil.facilities:
		f.group_id = -1
	for c: Country in gw.countries:
		var raw: Variant = c.get("army_groups")
		var out: Array = []
		if raw is Array:
			var used: Dictionary = {}
			for e: Variant in raw:
				if not (e is Dictionary) or out.size() >= MAX_GROUPS:
					continue
				var d: Dictionary = e
				var gid: int = int(d.get("id", -1))
				if gid <= 0 or used.has(gid):
					continue
				used[gid] = true
				var fids: = PackedInt32Array()
				var rf: Variant = d.get("fids", PackedInt32Array())
				if rf is PackedInt32Array or rf is Array or rf is PackedInt64Array:
					for v: Variant in rf:
						fids.append(int(v))
				var emb: String = String(d.get("emblem", "emb_star"))
				out.append({"id": gid, "name": _clean_name(String(d.get("name", "")), "Группа %d" % gid), "color": clampi(int(d.get("color", 0)), 0, N_COLORS - 1), 
					"emblem": emb if EMBLEMS.has(emb) else "emb_star", "fids": fids, "order": out.size(), "created": float(d.get("created", 0.0))})
				if fpl != null:
					fpl.carry(d, out[out.size() - 1])
				if bool(d.get("dug_off", false)):
					out[out.size() - 1]["dug_off"] = true
				var ro: Variant = d.get("out_fids")
				if ro is PackedInt32Array or ro is Array or ro is PackedInt64Array:
					var oo: = PackedInt32Array()
					for v2: Variant in ro:
						if fids.has(int(v2)) and not oo.has(int(v2)):
							oo.append(int(v2))
					if not oo.is_empty():
						out[out.size() - 1]["out_fids"] = oo
		c.army_groups = out
		prune(gw, c.id)






static func set_stance(gw: GameWorld, cid: int, fids: PackedInt32Array, s: int, who: String = "") -> String:
	var ops: Operations = gw.ops
	var c: Country = _country(gw, cid)
	var st: int = clampi(s, 0, 2)
	var why: String = ""
	var n: int = 0
	for fid: int in fids:
		var f: Facility = fac(gw, fid)
		if not valid_member(gw, cid, f):
			continue
		f.stance = st
		if ops.list.has(f) and st == 0 and bool(ops.list[f].get("stance", false)):
			ops.list[f]["stance"] = false
		ops.auto_next.erase("t%d" % f.id)
		var r: String = Operations.AutoCmd.attack_reason(gw, c, f) if st == 2 else ""
		ops.auto_next["n%d" % f.id] = r
		if why == "" and r != "":
			why = Loc.t("Армия №%d: %s") % [f.army_no, r]
		n += 1
	ops.auto_next.erase("a%d" % cid)
	if c != null and c.is_player and n > 0:
		gw.say(c, "%s: %s" % [who if who != "" else ("%d %s" % [n, Operations._armies_word(n)]), String(Operations.AutoCmd.STANCE_TITLES[st]).to_upper()])
	return why


static func group_set_stance(gw: GameWorld, cid: int, gid: int, s: int) -> String:
	var g: Dictionary = by_id(gw, cid, gid)
	if g.is_empty():
		return Loc.t("Нет такой группы")
	return set_stance(gw, cid, g["fids"], s, Loc.t("Группа «%s»") % String(g["name"]))









static func plan(gw: GameWorld, cid: int, fids: PackedInt32Array, kind: String, pos: Vector2, wp: Vector2 = Vector2.INF, lazy: bool = false) -> Array:
	var out: Array = []
	var only: Dictionary = {}
	for fid: int in fids:
		var f: Facility = fac(gw, fid)
		if valid_member(gw, cid, f):
			only[fid] = true
	if only.is_empty():
		return out
	if kind == "retreat":
		for fid2: int in only:
			out.append({"f": fac(gw, fid2), "to": Vector2.ZERO, "kind": Operations.Kind.RETREAT, "why": ""})
		return out
	if not pos.is_finite():
		return out
	for e: Dictionary in gw.ops._all_plan(cid, pos, only, lazy):
		if kind == "defend" and int(e["kind"]) != Operations.Kind.RETREAT:
			e["kind"] = Operations.Kind.DEFEND
		if String(e["why"]) != "" and gw.naval != null and gw.naval.at_sea(e["f"]):
			e["why"] = Loc.t("в море, ждите высадки")
		e["wp"] = Vector2.INF
		if wp.is_finite() and int(e["kind"]) != Operations.Kind.RETREAT:
			var sh: Vector2 = wp + ((e["to"] as Vector2) - pos)
			e["wp"] = sh if gw.ops._dry(sh) else wp
		out.append(e)
	return out




static func preview(gw: GameWorld, cid: int, fids: PackedInt32Array, kind: String, pos: Vector2, wp: Vector2 = Vector2.INF) -> Dictionary:
	var ok: int = 0
	var skipped: Array = []
	var ends: Array = []
	var mins: float = 0.0
	var kinds: Dictionary = {}
	var sea: int = 0
	var pend: int = 0
	var was_sea: bool = gw.ops.sea_force
	gw.ops.sea_force = kind == "sea" or was_sea
	var pl: Array = plan(gw, cid, fids, kind, pos, wp)
	for e: Dictionary in pl:
		var f: Facility = e["f"]
		var why: String = String(e["why"])
		if why == "":
			var chk: Dictionary = gw.ops._check(f, int(e["kind"]), e["to"], e.get("wp", Vector2.INF))
			if chk.has("pending"):
				ok += 1
				pend += 1
				continue
			if not bool(chk["ok"]):
				why = String(chk["why"])
			else:
				ok += 1
				kinds[int(chk["kind"])] = true
				if chk.has("naval"):
					sea += 1
				ends.append([f.id, chk["target"], e.get("wp", Vector2.INF)])
				mins = maxf(mins, float(chk["len"]) / maxf(1.0, gw.ops._speed(f)) / 60.0)
		if why != "":
			skipped.append([f.id, why])
	gw.ops.sea_force = was_sea
	return {"ok": ok, "n": pl.size(), "skipped": skipped, "mins": mins, "ends": ends, "kinds": kinds, "sea": sea, "pending": pend}



static func order_fids(gw: GameWorld, cid: int, fids: PackedInt32Array, kind: String, pos: Vector2, who: String = "", wp: Vector2 = Vector2.INF, chain: PackedVector2Array = PackedVector2Array()) -> Dictionary:
	prune(gw, cid)
	var ch: PackedVector2Array = route_chain(gw, cid, kind, pos, chain)
	var ok: int = 0
	var skipped: Array = []
	var ops: Operations = gw.ops
	ops._quiet = true
	var was_sea: bool = ops.sea_force
	ops.sea_force = kind == "sea"
	var pl: Array = plan(gw, cid, fids, kind, pos, wp, fids.size() > Operations.OQ_NOW)
	var now_n: int = 0
	for e: Dictionary in pl:
		var f: Facility = e["f"]
		var why: String = String(e["why"])
		if why == "" and ch.is_empty() and now_n >= Operations.OQ_NOW and fids.size() > Operations.OQ_NOW:

			ops.queue_order(f, int(e["kind"]), e["to"], e.get("cands", []), wp, pos, true, kind == "sea")
			ok += 1
			continue
		if why == "" and e.has("cands") and not (e["cands"] as Array).is_empty():
			e["to"] = ops._resolve_to(f, int(e["kind"]), e["to"], e["cands"])
			if wp.is_finite() and int(e["kind"]) != Operations.Kind.RETREAT:
				var sh: Vector2 = wp + ((e["to"] as Vector2) - pos)
				e["wp"] = sh if ops._dry(sh) else wp
		if why == "":
			now_n += 1
			if not ch.is_empty():
				gw.army.tac.chain = ch
			why = ops.start(f, int(e["kind"]), e["to"], e.get("wp", Vector2.INF))
			if not ch.is_empty():
				gw.army.tac.chain = PackedVector2Array()
		if why == "":
			ok += 1
		else:
			skipped.append([f.id, why])
	ops._quiet = false
	ops.sea_force = was_sea
	var c: Country = _country(gw, cid)
	if c != null and c.is_player and ok > 0:
		var what: String = {"move": Loc.t("ДВИЖЕНИЕ", "status"), "defend": Loc.t("ОБОРОНА"), "retreat": Loc.t("ОТХОД"), "sea": Loc.t("МОРСКОЙ ДЕСАНТ")}.get(kind, Loc.t("ПРИКАЗ"))
		gw.say(c, "%s%s: %d %s" % [(who + " · ") if who != "" else "", what, ok, Operations._armies_word(ok)])
		Sfx.play("ui_alert", Vector2.INF, -8.0)
	return {"ok": ok, "skipped": skipped}


const ROUTE_MAX: int = 8





static func route_chain(gw: GameWorld, cid: int, kind: String, pos: Vector2, chain: PackedVector2Array) -> PackedVector2Array:
	var out: = PackedVector2Array()
	if chain.is_empty() or not (kind == "move" or kind == "defend") or not pos.is_finite():
		return out
	var lim: Vector2 = Vector2(gw.data.w, gw.data.h) * float(GameWorld.CELL)
	for p: Vector2 in chain:
		if out.size() < ROUTE_MAX and p.is_finite() and p.x >= 0.0 and p.y >= 0.0 and p.x < lim.x and p.y < lim.y:
			out.append(p)
	if out.is_empty():
		return out
	var dense: = PackedVector2Array()
	var pts: PackedVector2Array = out.duplicate()
	pts.append(pos)
	for i in range(pts.size() - 1):
		var n: int = maxi(1, ceili(pts[i].distance_to(pts[i + 1]) / 16.0))
		for k in n:
			dense.append(pts[i].lerp(pts[i + 1], float(k) / float(n)))
	dense.append(pos)
	if (load("res://game/front_plan.gd") as GDScript).call("closed_path", gw, cid, dense):
		var c: Country = _country(gw, cid)
		if c != null:
			gw.say(c, Loc.mk("Маршрут через закрытую землю — пойдут обычным путём"))
		return PackedVector2Array()
	return out



static func group_order(gw: GameWorld, cid: int, gid: int, kind: String, pos: Vector2) -> Dictionary:
	prune(gw, cid)
	var g: Dictionary = by_id(gw, cid, gid)
	if g.is_empty():
		return {"ok": 0, "skipped": []}
	return order_fids(gw, cid, g["fids"], kind, pos, Loc.t("Группа «%s»") % String(g["name"]))




const TRENCH_R: float = 600.0




static func _foot_free(gw: GameWorld, f: Facility) -> Array[Unit]:
	var out: Array[Unit] = []
	for u: Unit in gw.army.units:
		if u.home == f and u.alive() and u.post == null and u.state != Unit.State.SIEGE and (u.type == Unit.Type.INFANTRY or u.type == Unit.Type.ATGM or u.type == Unit.Type.ASSAULT):
			out.append(u)
	return out




static func trench_info(gw: GameWorld, cid: int, fids: PackedInt32Array, gid: int = -1) -> Dictionary:
	var g: Dictionary = by_id(gw, cid, gid) if gid >= 0 else {}
	var out: Dictionary = {"in": 0, "foot": 0, "slots": 0, "off": bool(g.get("dug_off", false))}
	if gw.army == null:
		return out
	var cens: Array = []
	var mem: Dictionary = {}
	for fid: int in fids:
		var f: Facility = fac(gw, fid)
		if valid_member(gw, cid, f):
			mem[f] = true
			var fu: Array[Unit] = _foot_free(gw, f)
			out["foot"] = int(out["foot"]) + fu.size()
			if not fu.is_empty():
				var s: = Vector2.ZERO
				for u: Unit in fu:
					s += u.pos
				cens.append(s / float(fu.size()))
	for u2: Unit in gw.army.units:
		if u2.post != null and u2.alive() and mem.has(u2.home):
			out["in"] = int(out["in"]) + 1
	if cens.is_empty():
		return out
	for t: Facility in gw.mil.facilities:
		if t.country_id != cid or not Army.is_trench(t.kind) or not gw.mil.alive(t):
			continue
		var tc: Vector2 = t.center_px()
		for cp: Vector2 in cens:
			if tc.distance_to(cp) <= TRENCH_R:
				out["slots"] = int(out["slots"]) + maxi(0, gw.army.capacity(t) - gw.army.occupants(t).size())
				break
	return out






static func trench_in(gw: GameWorld, cid: int, gid: int) -> Dictionary:
	prune(gw, cid)
	var g: Dictionary = by_id(gw, cid, gid)
	if g.is_empty():
		return {"n": 0, "armies": 0, "foot": 0, "why": Loc.t("Нет такой группы")}
	g.erase("dug_off")
	return trench_in_fids(gw, cid, g["fids"], Loc.t("Группа «%s»") % String(g["name"]))



static func trench_in_fids(gw: GameWorld, cid: int, fids: PackedInt32Array, who: String = "") -> Dictionary:
	var a: Army = gw.army
	var n: int = 0
	var armies: int = 0
	var foot: int = 0
	var seen_tr: int = 0
	for fid: int in fids:
		var f: Facility = fac(gw, fid)
		if not valid_member(gw, cid, f):
			continue
		_mark_out(gw, cid, f, false)
		var fu: Array[Unit] = _foot_free(gw, f)
		foot += fu.size()
		if fu.is_empty():
			continue
		var cen: = Vector2.ZERO
		for u: Unit in fu:
			cen += u.pos
		cen /= float(fu.size())
		var trs: Array = []
		for t: Facility in gw.mil.facilities:
			if t.country_id != cid or not Army.is_trench(t.kind) or not gw.mil.alive(t):
				continue
			var d: float = t.center_px().distance_to(cen)
			if d <= TRENCH_R and a.occupants(t).size() < a.capacity(t):
				trs.append([d, t.id, t])
		trs.sort_custom( func(x: Array, y: Array) -> bool:
			return float(x[0]) < float(y[0]) or (float(x[0]) == float(y[0]) and int(x[1]) < int(y[1])))
		seen_tr += trs.size()
		var sent: int = 0
		for e: Array in trs:
			if sent >= fu.size():
				break
			sent += a.occupy(e[2], cid, false, f)
		if sent > 0:
			armies += 1
		n += sent
	var why: String = ""
	if n == 0:
		if foot == 0:
			why = Loc.t("Свободной пехоты нет: все в окопах или в группе только техника")
		elif seen_tr == 0:
			why = Loc.t("Рядом нет свободных окопов — выройте окоп у фронта")
		else:
			why = a.occupy_why if a.occupy_why != "" else Loc.t("Окопы рядом заняты")
	var c: Country = _country(gw, cid)
	if c != null and c.is_player and n > 0:
		gw.say(c, Loc.mk("%s: в окопы идут %d %s", [who if who != "" else Loc.t("Армии"), n, [Loc.t("боец"), Loc.t("бойца"), Loc.t("бойцов")][_pl3(n)]]))
	return {"n": n, "armies": armies, "foot": foot, "why": why}







static func trench_out(gw: GameWorld, cid: int, gid: int) -> Dictionary:
	prune(gw, cid)
	var g: Dictionary = by_id(gw, cid, gid)
	if g.is_empty():
		return {"n": 0, "why": Loc.t("Нет такой группы")}
	g["dug_off"] = true
	return trench_out_fids(gw, cid, g["fids"], Loc.t("Группа «%s»") % String(g["name"]))



static func trench_out_fids(gw: GameWorld, cid: int, fids: PackedInt32Array, who: String = "") -> Dictionary:
	var a: Army = gw.army
	var n: int = 0
	var left: Dictionary = {}
	for fid: int in fids:
		var h: Facility = fac(gw, fid)
		if not valid_member(gw, cid, h):
			continue
		_mark_out(gw, cid, h, true)
		var rest: Vector2 = a._field_centre(h)
		var k: int = 0
		for u: Unit in a.units:
			if u.home != h or not u.alive() or u.post == null:
				continue
			var t: Facility = u.post
			left[t] = true
			var back: Vector2 = Vector2.from_angle(a._post_facing(t) + PI)
			a._release(u)
			u.no_post_until = gw.game_time + 45.0
			n += 1
			if gw.ops != null and gw.ops.rejoin(u):
				continue
			var dest: Vector2 = u.pos + back * 26.0 + Vector2((k % 3 - 1) * 6.0, float(k / 3) * 6.0)
			k += 1
			if h.stance == 0 and rest.is_finite() and rest.distance_to(a.barracks_out(h)) > 120.0:
				dest = a.safe_point(rest, u.slot)
			elif h.center_px().distance_to(u.pos) < 700.0 or h.stance > 0:
				dest = a.barracks_out(h) + u.slot
			u.path = gw.econ.nav_path(u.pos, dest) if u.pos.distance_to(dest) > 40.0 else PackedVector2Array([dest])
			if u.path.is_empty():
				u.path = PackedVector2Array([dest])
			u.path[u.path.size() - 1] = dest
			u.pi = 0
			u.state = Unit.State.MOVE
	for t2: Facility in left:
		if a.occupants(t2).is_empty():
			t2.post_off = true
	var c: Country = _country(gw, cid)
	if c != null and c.is_player:
		var wh: String = who if who != "" else Loc.t("Армии")
		gw.say(c, (Loc.t("%s: из окопов выходят %d %s") % [wh, n, [Loc.t("боец"), Loc.t("бойца"), Loc.t("бойцов")][_pl3(n)]]) if n > 0 else Loc.t("%s: в окопах никого нет") % wh)
	return {"n": n, "why": "" if n > 0 else Loc.t("В окопах никого нет")}




static func _mark_out(gw: GameWorld, cid: int, f: Facility, on: bool) -> void :
	if f.group_id < 0:
		return
	var g: Dictionary = by_id(gw, cid, f.group_id)
	if g.is_empty():
		return
	var ov: Variant = g.get("out_fids", PackedInt32Array())
	var o: PackedInt32Array = ov if ov is PackedInt32Array else PackedInt32Array()
	if on and not o.has(f.id):
		o.append(f.id)
	elif not on and o.has(f.id):
		o.remove_at(o.find(f.id))
	if o.is_empty():
		g.erase("out_fids")
	else:
		g["out_fids"] = o



static func stay_out(gw: GameWorld, cid: int, f: Facility) -> bool:
	if f == null or f.group_id < 0:
		return false
	var g: Dictionary = by_id(gw, cid, f.group_id)
	if g.is_empty():
		return false
	var ov: Variant = g.get("out_fids", PackedInt32Array())
	return bool(g.get("dug_off", false)) or (ov is PackedInt32Array and (ov as PackedInt32Array).has(f.id))


static func _pl3(n: int) -> int:
	var m10: int = n % 10
	var m100: int = n % 100
	if m10 == 1 and m100 != 11:
		return 0
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return 1
	return 2
