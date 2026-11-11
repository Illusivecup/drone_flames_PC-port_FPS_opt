class_name NavyFleets
extends RefCounted






const ORDERS: Array = ["move", "patrol", "hunt", "escort", "stop", "return", "blockade"]
const ORDER_NAMES: Dictionary = {"move": "Переход", "patrol": "Патруль", "hunt": "Охота", "escort": "Конвой", "stop": "Стоп", "return": "На базу", "blockade": "Блокада"}
const BLOCKADE_R: float = 260.0
const TICK: float = 1.0
const PATROL_R: float = 300.0
const HUNT_R: float = 2500.0
const ESCORT_R: float = 1300.0
const CHASE_LEASH: float = 400.0
const SERVICE_SKIP: float = 120.0
const RETURN_GIVE_UP: float = 240.0
const SALVO: Array = [2, 6, 8]
const SALVO_AI_MAX: int = 6
const SALVO_CD: float = 25.0
const FORMS: Array = ["wedge", "line"]





const ARRIVE_R: float = 40.0
const ARRIVE_WAIT: float = 45.0
const ARRIVE_MAX: float = 180.0
const SLOT_SP: Array = [30.0, 40.0, 52.0]

var nv: Navy
var gw: GameWorld
var fleets: Array = []
var _id: int = 1
var _t: float = 0.0
var _ai_t: float = 0.0
var _salvo_at: Dictionary = {}
var _cm_at: Dictionary = {}
var _lead_of: Dictionary = {}
var _svc_skip: Dictionary = {}


func _init(navy: Navy) -> void :
	nv = navy
	gw = navy.gw




func fleets_of(cid: int) -> Array:
	var out: Array = []
	for fl: Dictionary in fleets:
		if int(fl["c"]) == cid:
			out.append(fl)
	return out


func fleet(id: int) -> Dictionary:
	for fl: Dictionary in fleets:
		if int(fl["id"]) == id:
			return fl
	return {}


func members(fl: Dictionary) -> Array[Ship]:
	var out: Array[Ship] = []
	for sid: Variant in fl.get("ships", []):
		var s: Ship = nv.ship(int(sid))
		if s != null and s.alive() and s.fleet == int(fl["id"]):
			out.append(s)
	return out



func fleet_create(cid: int, fname: String, color: Color, ship_ids: Array) -> int:
	var fl: Dictionary = {"id": _id, "c": cid, "name": fname if fname != "" else "Флот %d" % _id, 
			"color": color, "ships": [], 
		"order": {}, "form": "wedge", "hold": false, "ai": ""}
	_id += 1
	fleets.append(fl)
	for sid: Variant in ship_ids:
		fleet_add(int(fl["id"]), int(sid))
	return int(fl["id"])


func fleet_add(fid: int, ship_id: int) -> String:
	var fl: Dictionary = fleet(fid)
	var s: Ship = nv.ship(ship_id)
	if fl.is_empty() or s == null or not s.alive():
		return Loc.t("Нет такого корабля или флота")
	if s.c != int(fl["c"]):
		return Loc.t("Чужой корабль")
	if s.fleet == fid:
		return ""
	if s.fleet != 0:
		fleet_remove(s.fleet, s.id)
	s.fleet = fid
	s.ord = {}
	s.fresh = false
	(fl["ships"] as Array).append(s.id)


	var k: String = String((fl.get("order", {}) as Dictionary).get("k", ""))
	if k != "":
		s.auto = true
		if k == "stop":
			var jn: Array = fl.get("join", [])
			if not jn.has(s.id):
				jn.append(s.id)
			fl["join"] = jn
	return ""


func fleet_remove(fid: int, ship_id: int) -> void :
	var fl: Dictionary = fleet(fid)
	if not fl.is_empty():
		(fl["ships"] as Array).erase(ship_id)
	var s: Ship = nv.ship(ship_id)
	if s != null and s.fleet == fid:
		s.fleet = 0
		s.ord = (fl.get("order", {}) as Dictionary).duplicate(true) if not fl.is_empty() else {}
		if bool(fl.get("sink_n", false)):
			s.ord["sink_n"] = true
		else:
			s.ord.erase("sink_n")


func fleet_disband(fid: int) -> void :
	var fl: Dictionary = fleet(fid)
	if fl.is_empty():
		return
	for sid: Variant in (fl["ships"] as Array).duplicate():
		fleet_remove(fid, int(sid))
	fleets.erase(fl)


func set_formation(fid: int, form: String) -> void :
	var fl: Dictionary = fleet(fid)
	if not fl.is_empty() and FORMS.has(form):
		fl["form"] = form



func set_sink_neutral(fid: int, on: bool) -> void :
	var fl: Dictionary = fleet(fid)
	if not fl.is_empty():
		fl["sink_n"] = on





func fleet_order(cid: int, fid: int, kind: String, pos: Vector2, r: float = -1.0, wps: Array = []) -> String:
	var fl: Dictionary = fleet(fid)
	if fl.is_empty() or int(fl["c"]) != cid:
		return Loc.t("Нет такого флота")
	var mem: Array[Ship] = members(fl)
	if mem.is_empty():
		return Loc.t("Во флоте нет кораблей")
	var o: Dictionary = _mk_order(kind, pos, r, mem[0])
	if o.has("why"):
		return String(o["why"])
	_set_route(o, wps)
	fl["order"] = o
	fl.erase("join")
	for s: Ship in mem:
		s.refit = "" if kind != "return" and kind != "stop" else s.refit
		s.auto = true
		if kind == "stop":
			nv.stop(s)
	_run(mem, o, cid, fl)
	return ""



func ship_order(s: Ship, kind: String, pos: Vector2, r: float = -1.0, wps: Array = []) -> String:
	if s == null or not s.alive():
		return Loc.t("Корабль тонет")
	var o: Dictionary = _mk_order(kind, pos, r, s)
	if o.has("why"):
		return String(o["why"])
	_set_route(o, wps)
	if s.fleet != 0:
		var fid: int = s.fleet
		fleet_remove(fid, s.id)
	if bool(s.ord.get("sink_n", false)):
		o["sink_n"] = true
	s.ord = o
	s.auto = true
	if kind == "stop":
		nv.stop(s)
	var one: Array[Ship] = [s]
	_run(one, o, s.c, {})
	return ""



func _set_route(o: Dictionary, wps: Array) -> void :
	var route: = PackedVector2Array()
	for w: Variant in wps:
		if w is Vector2 and (w as Vector2).is_finite():
			route.append(w)
	if not route.is_empty() and String(o["k"]) != "stop" and String(o["k"]) != "return":
		o["route"] = route


func _mk_order(kind: String, pos: Vector2, r: float, ref: Ship) -> Dictionary:
	if not ORDERS.has(kind):
		return {"why": Loc.t("Неизвестный приказ")}
	var o: Dictionary = {"k": kind, "pos": pos, "r": r, "i": 0, "conv": -1, "t0": gw.game_time}
	if kind == "blockade":

		var port: Facility = null
		var bd: float = 600.0
		for f: Facility in gw.mil.facilities:
			if f.kind == Facility.Kind.PORT and f.country_id != ref.c and gw.mil.alive(f) and f.center_px().distance_to(pos) < bd:
				bd = f.center_px().distance_to(pos)
				port = f
		if port == null:
			return {"why": Loc.t("Коснитесь чужого порта")}
		if gw.diplo != null and gw.diplo.allied(ref.c, port.country_id):
			return {"why": Loc.t("Нельзя блокировать союзника")}
		o["port"] = port.id
		o["victim"] = port.country_id
		pos = port.center_px()
		o["pos"] = pos
		kind = "patrol"
		r = BLOCKADE_R
	if kind == "patrol" or kind == "hunt" or kind == "escort":
		var rr: float = r if r > 0.0 else (HUNT_R if kind == "hunt" else PATROL_R)
		o["r"] = rr
		var body: int = nv._body_px(ref.pos)
		var wp: Array = []
		var pr: float = minf(rr, PATROL_R * 1.5)
		for k in 4:
			var q: Vector2i = nv._sea_near(pos + Vector2.from_angle(TAU * float(k) / 4.0 + 0.4) * pr, 8, body)
			if q.x >= 0:
				wp.append(nv._ports().cell_px(q))
		if wp.is_empty():
			var q0: Vector2i = nv._sea_near(pos, 12, body)
			if q0.x < 0:
				return {"why": Loc.t("Туда не доплыть: другое море")}
			wp.append(nv._ports().cell_px(q0))
		o["wp"] = wp
	elif kind == "move":
		var mb: int = nv._body_px(ref.pos)
		if mb == 0:
			var a0: Vector2i = nv._sea_near(ref.pos, 3)
			mb = nv._ports()._body_at(a0) if a0.x >= 0 else 0
		var mq: Vector2i = nv._sea_near(pos, 12, mb)
		if mq.x < 0:
			mq = nv._sea_near(pos, 40, mb)
		if mq.x < 0:
			return {"why": Loc.t("Туда не доплыть: другое море")}


		var mp: Vector2 = nv._ports().cell_px(mq)
		if nv._body_px(pos) != mb:
			o["pos"] = mp
	return o


func order_text(o: Dictionary) -> String:
	return String(ORDER_NAMES.get(String(o.get("k", "")), "Ожидание"))




func tick(dt: float) -> void :
	_t += dt
	if _t < TICK:
		return
	_t = 0.0
	for k in range(fleets.size() - 1, -1, -1):
		var fl: Dictionary = fleets[k]
		var mem: Array[Ship] = members(fl)
		var ids: Array = []
		for s: Ship in mem:
			ids.append(s.id)
		fl["ships"] = ids
		if mem.is_empty():
			if String(fl.get("ai", "")) == "" and gw.game_time - float((fl.get("order", {}) as Dictionary).get("t0", 0.0)) > 5.0:
				pass
			continue
		_run(mem, fl["order"], int(fl["c"]), fl)
	for s: Ship in nv.ships:
		if s.alive() and s.fleet == 0:
			if s.ord.has("rejoin") and _rejoin_ready(s):
				var back: int = int(s.ord["rejoin"])
				if not fleet(back).is_empty():
					fleet_add(back, s.id)
					continue
				s.ord.erase("rejoin")
			var one: Array[Ship] = [s]
			_run(one, s.ord, s.c, {})
	_auto_home()






func _rejoin_ready(s: Ship) -> bool:
	if s.refit != "":
		return false
	var k: String = String(s.ord.get("k", ""))
	if k == "return":
		return gw.game_time - float(s.ord.get("t0", gw.game_time)) > RETURN_GIVE_UP
	if k != "stop":
		return false
	if _service_due(s, 0):
		return false
	if s.hp < s.hp_max * 0.9 or not nv._missing(s).is_empty():
		_svc_skip[s.id] = gw.game_time + SERVICE_SKIP
	return true



func _service_due(s: Ship, keep: int) -> bool:
	if not bool(nv.auto_refit.get(s.c, true)):
		return false
	var c: Country = gw.country_by_id(s.c)
	if c == null:
		return false
	var cost: Dictionary = {}
	if s.hp < s.hp_max - 1.0 or not s.fires.is_empty():
		cost = nv.repair_cost(s)
	elif not nv._missing(s).is_empty():
		cost = nv.rearm_cost(s)
	else:
		return false
	return c.money >= int(cost.get("money", 0)) + keep and c.has_res(cost)




func _auto_home() -> void :
	for fl: Dictionary in fleets:
		var k: String = String((fl.get("order", {}) as Dictionary).get("k", ""))
		if String(fl.get("ai", "")) != "" or (k != "patrol" and k != "hunt" and k != "escort"):
			continue
		for s: Ship in members(fl):
			var dry: bool = s.has_mod("ash") and int(s.ammo.get("asm", 0)) == 0
			if (dry or s.hp < s.hp_max * 0.35) and gw.game_time >= float(_svc_skip.get(s.id, 0.0)):
				var hf: Facility = _home(s)
				if hf == null or not _service_due(s, 0):
					continue
				var fid: int = int(fl["id"])
				if ship_order(s, "return", nv.berth_px(hf)) == "":
					s.ord["rejoin"] = fid
				else:
					fleet_add(fid, s.id)


func _leader(mem: Array[Ship], fl: Dictionary = {}) -> Ship:
	var best: Ship = mem[0]
	for s: Ship in mem:
		if s.hull > best.hull or (s.hull == best.hull and s.id < best.id):
			best = s
	if fl.is_empty() or mem.size() < 2:
		return best



	var fid: int = int(fl["id"])
	var cur: Ship = nv.ship(int(_lead_of.get(fid, 0)))
	if cur != null and mem.has(cur):
		return cur
	var o: Dictionary = fl.get("order", {})
	var ref: Vector2 = o.get("at", o.get("pos", mem[0].pos))


	var jn: Array = fl.get("join", [])
	var near0: Ship = null
	for s2: Ship in mem:
		if jn.has(s2.id) and near0 != null:
			continue
		if near0 == null or (jn.has(near0.id) and not jn.has(s2.id)) or s2.pos.distance_to(ref) < near0.pos.distance_to(ref):
			near0 = s2
	best = near0
	for s3: Ship in mem:
		if s3.pos.distance_to(near0.pos) < 400.0 and (s3.hull > best.hull or (s3.hull == best.hull and s3.id < best.id)):
			best = s3
	_lead_of[fid] = best.id
	return best



func _run(mem: Array[Ship], o: Dictionary, c: int, fl: Dictionary) -> void :
	var lead: Ship = _leader(mem, fl)
	var slow: float = INF
	for s: Ship in mem:
		s.spd_cap = INF
		slow = minf(slow, float(Navy.hull_spec(s.hull)["speed"]) * nv._hp_factor(s))
	if mem.size() > 1:
		lead.spd_cap = slow * 0.9
	var foes: Array = _foes(mem, c)
	if not bool(fl.get("hold", false)) and not bool(o.get("hold", false)):
		_salvos(mem, c, foes, String(o.get("k", "")))
	var k: String = String(o.get("k", ""))
	if k == "stop" and not fl.is_empty() and mem.size() > 1:
		_gather(mem, lead, o, fl)
		return
	if k == "" or k == "stop":
		return
	if k == "return":
		var all_in: bool = true
		for s: Ship in mem:
			var f: Facility = _home(s)
			if f == null:
				continue
			if nv.near_base(s) == null:
				all_in = false
				_steer(s, nv.berth_px(f))
		if all_in:
			o["k"] = "stop"
		return

	var route: PackedVector2Array = o.get("route", PackedVector2Array())
	if not route.is_empty():
		if lead.pos.distance_to(route[0]) < 40.0:
			route.remove_at(0)
			o["route"] = route
		if not route.is_empty():
			_formation(mem, lead, route[0], fl)
			return

	var guard: Vector2 = lead.pos
	var reach: float = float(Navy.hull_spec(lead.hull)["sensor"]) * 1.2
	if k == "hunt":
		reach = maxf(reach, 900.0)
	var esc: Variant = _escort_pos(o, c, lead) if k == "escort" else null
	if esc != null:
		guard = esc
		reach = ESCORT_R



	var anchor: Vector2 = guard if esc != null else (o.get("pos", lead.pos) as Vector2)
	var lim: float = ESCORT_R if esc != null else float(o.get("r", PATROL_R)) + CHASE_LEASH
	if k != "move" and not foes.is_empty():
		var near: Array = []
		for e: Ship in foes:
			if (e.pos.distance_to(guard) <= reach or e.pos.distance_to(lead.pos) <= Navy.GUN_RANGE * 1.5) and e.pos.distance_to(anchor) <= lim:
				near.append(e)
		if not near.is_empty():
			var free: Array[Ship] = _engage(mem, near, anchor, lim)
			if not free.is_empty():
				var g0: Vector2 = lead.pos
				if free.has(lead):
					g0 = _patrol_goal(o, lead) if k == "patrol" or k == "blockade" else anchor
					_steer(lead, g0)
				for fs: Ship in free:
					if fs != lead:
						_steer(fs, _slot(mem, lead, fs, fl, g0))
			return
	var goal: Vector2 = lead.pos
	match k:
		"move":
			goal = o["pos"]
			if lead.pos.distance_to(goal) < 24.0:
				if fl.is_empty() or mem.size() < 2:
					o["k"] = "stop"
					for s2: Ship in mem:
						nv.stop(s2)
					return
				_arrive(mem, lead, o, fl, goal)
				return
		"patrol", "blockade":
			goal = _patrol_goal(o, lead)
		"hunt":
			var hv: Variant = _hunt_target(c, o, lead)
			goal = hv if hv != null else _patrol_goal(o, lead)
		"escort":
			if esc != null:
				var cv: Vector2 = esc
				goal = cv - Vector2.from_angle(float(o.get("hd", 0.0))) * 30.0
			else:
				goal = _patrol_goal(o, lead)
	_formation(mem, lead, goal, fl)





func _arrive(mem: Array[Ship], lead: Ship, o: Dictionary, fl: Dictionary, goal: Vector2) -> void :
	if not o.has("arr"):
		o["arr"] = gw.game_time
	nv.stop(lead)
	var out: int = 0
	for s2: Ship in mem:
		if s2 == lead:
			continue
		var sl: Vector2 = _slot(mem, lead, s2, fl, goal)
		if s2.pos.distance_to(sl) > ARRIVE_R and s2.refit == "":
			out += 1
		_steer(s2, sl)
	var wait: float = gw.game_time - float(o["arr"])
	if out == 0 or (wait >= ARRIVE_WAIT and out * 3 <= mem.size()) or wait >= ARRIVE_MAX:
		o["k"] = "stop"
		o["at"] = goal




func _gather(mem: Array[Ship], lead: Ship, o: Dictionary, fl: Dictionary) -> void :
	var jn: Array = fl.get("join", [])
	var at: bool = o.has("at")
	if jn.is_empty() and not at:
		return
	if lead.state == Ship.State.SAIL and lead.path.size() <= 1 and lead.pos.distance_to(o.get("at", lead.pos)) < 24.0:
		nv.stop(lead)
	for s: Ship in mem:
		if s == lead:
			continue
		var joining: bool = jn.has(s.id)
		if not joining and not at:
			continue
		var sl: Vector2 = _slot(mem, lead, s, fl, lead.pos)
		if joining and s.pos.distance_to(sl) <= ARRIVE_R:
			jn.erase(s.id)
		_steer(s, sl)
	for sid: Variant in jn.duplicate():
		var sx: Ship = nv.ship(int(sid))
		if sx == null or not sx.alive() or sx.fleet != int(fl["id"]):
			jn.erase(sid)
	if jn.is_empty():
		fl.erase("join")


func _formation(mem: Array[Ship], lead: Ship, goal: Vector2, fl: Dictionary) -> void :
	_steer(lead, goal)
	for s3: Ship in mem:
		if s3 != lead:
			_steer(s3, _slot(mem, lead, s3, fl, goal))





func _slot(mem: Array[Ship], lead: Ship, s: Ship, fl: Dictionary, goal: Vector2) -> Vector2:


	var hmax: int = lead.hull
	for m: Ship in mem:
		hmax = maxi(hmax, m.hull)
	var sp: float = float(SLOT_SP[clampi(hmax, 0, 2)])
	var idx: int = mem.find(s)
	var i: int = maxi(1, idx + 1 - (1 if mem.find(lead) < idx else 0))
	var off: Vector2
	if String(fl.get("form", "wedge")) == "line":
		off = Vector2( - sp * float(i), 0.0)
	else:
		var kk: float = float((i + 1) / 2)
		off = Vector2( - sp * kk, (1.0 if i % 2 == 1 else -1.0) * sp * 0.8 * kk)


	var hd: float = lead.heading if lead.speed > 1.0 or lead.state == Ship.State.SAIL or goal.distance_to(lead.pos) < 40.0 else (goal - lead.pos).angle()
	var body: int = nv._body_px(lead.pos)



	var tries: Array = [off, Vector2( - sp * float(i), 0.0), Vector2(sp * float(i), 0.0)]
	for fr: float in [1.0, 0.6]:
		for t: Vector2 in tries:
			var q: Vector2 = lead.pos + (t * fr).rotated(hd)
			if nv._body_px(q) == body:
				return q
	return lead.pos + (off * 0.3).rotated(hd)




func _home(s: Ship) -> Facility:
	var body: int = nv._body_px(s.pos)
	if s.base != null and gw.mil.alive(s.base) and s.base.country_id == s.c and (body == 0 or nv.base_body(s.base) == body):
		return s.base
	for f: Facility in nv.bases_of(s.c):
		if body == 0 or nv.base_body(f) == body:
			return f
	return null


func _patrol_goal(o: Dictionary, lead: Ship) -> Vector2:
	var wp: Array = o.get("wp", [])
	if wp.is_empty():
		return o.get("pos", lead.pos)
	var i: int = int(o.get("i", 0)) % wp.size()
	if lead.pos.distance_to(wp[i]) < 48.0:
		i = (i + 1) % wp.size()
		o["i"] = i
	return wp[i]



func _steer(s: Ship, p: Vector2) -> void :
	if s.refit != "" or not s.alive():
		return
	if s.pos.distance_to(p) < 10.0:
		if s.state == Ship.State.SAIL and s.path.size() <= 1:
			nv.stop(s)
		return
	if s.state == Ship.State.SAIL and not s.path.is_empty() and s.path[s.path.size() - 1].distance_to(p) < 20.0:
		return
	if nv._body_px(p) != 0 and nv._body_px(p) == nv._body_px(s.pos) and nv._los(s.pos, p):
		s.path = PackedVector2Array([p])
		s.pi = 0
		s.state = Ship.State.SAIL
		return
	nv.move_to(s, p, false)



func _foes(mem: Array[Ship], c: int) -> Array:
	var out: Array = []
	for o: Ship in nv.ships:
		if not o.alive() or o.c == c or not nv._hostile(c, o.c):
			continue
		for s: Ship in mem:
			if o.pos.distance_to(s.pos) <= float(Navy.hull_spec(s.hull)["sensor"]) * 1.2:
				out.append(o)
				break
	return out





func _engage(mem: Array[Ship], foes: Array, anchor: Vector2, lim: float) -> Array[Ship]:
	var free: Array[Ship] = []
	for s: Ship in mem:
		var best: Ship = null
		var bd: float = INF
		for e: Ship in foes:
			var d: float = e.pos.distance_to(s.pos)
			if d < bd:
				bd = d
				best = e
		if best == null or s.pos.distance_to(anchor) > lim + 60.0:
			free.append(s)
			continue
		var away: Vector2 = (s.pos - best.pos).normalized()
		if s.has_mod("gun"):
			if bd > Navy.GUN_RANGE * 0.85:
				_steer(s, _leash(best.pos + away * Navy.GUN_RANGE * 0.6, anchor, lim))
			elif s.state == Ship.State.SAIL and bd < Navy.GUN_RANGE * 0.5:
				nv.stop(s)
		elif bd < 600.0:
			_steer(s, _leash(best.pos + away * 900.0, anchor, lim))
		else:
			free.append(s)
	return free


func _leash(p: Vector2, anchor: Vector2, lim: float) -> Vector2:
	return anchor + (p - anchor).limit_length(lim)



func _salvos(mem: Array[Ship], c: int, foes: Array, k: String) -> void :
	var now: float = gw.game_time
	var shooters: Array[Ship] = []
	for s: Ship in mem:
		if int(s.ammo.get("asm", 0)) > 0 and s.refit == "":
			shooters.append(s)
	if shooters.is_empty():
		return
	var cw: Country = gw.country_by_id(c)
	var ai: bool = cw != null and not cw.is_player
	var tgts: Array = []
	for e: Ship in foes:
		tgts.append([e.pos.distance_to(shooters[0].pos), e.id, e.pos, int(SALVO[clampi(e.hull, 0, 2)])])
	if k == "hunt" or k == "patrol" or k == "escort":
		for cs: Dictionary in nv.convoys():
			if int(cs["stage"]) == 0 or not nv.may_hit(c, int(cs["owner"]), -1, shooters[0]):
				continue
			var cp: Vector2 = cs["pos"]
			var dmin: float = INF
			for s: Ship in mem:
				dmin = minf(dmin, cp.distance_to(s.pos))
			if dmin > Navy.GUN_RANGE * 1.2 and dmin <= Navy.ASM_RANGE * 0.8:
				tgts.append([dmin, - int(cs["id"]), cp, 1])
	tgts.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for t: Array in tgts:
		var key: String = "%d:%d" % [c, int(t[1])]
		if now - float(_salvo_at.get(key, -999.0)) < SALVO_CD:
			continue
		var want: int = int(t[3])
		if ai:
			want = mini(want, SALVO_AI_MAX)
		want -= nv.in_flight(int(t[1]))
		if want <= 0:
			continue
		var tp: Vector2 = t[2]
		var sent: int = 0
		var guard: int = 0
		while sent < want and guard < 16:
			guard += 1
			var any: bool = false
			for s: Ship in shooters:
				if sent >= want:
					break
				if int(s.ammo.get("asm", 0)) <= 0 or s.pos.distance_to(tp) > Navy.ASM_RANGE:
					continue
				var n: int = nv.salvo_quiet(s, int(t[1]), tp, 1, float(sent) * Navy.ASM_GAP)
				sent += n
				any = any or n > 0
			if not any:
				break
		if sent > 0:
			_salvo_at[key] = now
			if sent >= 4 and gw.battle_watch != null:
				gw.battle_watch.note(tp, 6.0, "Залп ПКР", c)
			return


func _hunt_target(c: int, o: Dictionary, lead: Ship) -> Variant:
	var centre: Vector2 = o.get("pos", lead.pos)
	var r: float = float(o.get("r", HUNT_R))
	var body: int = nv._body_px(lead.pos)
	var best: Variant = null
	var bd: float = INF
	for cs: Dictionary in nv.convoys():
		if int(cs["stage"]) == 0 or not nv.may_hit(c, int(cs["owner"]), -1, lead):
			continue
		var p: Vector2 = cs["pos"]
		if p.distance_to(centre) > r or nv._body_px(p) != body:
			continue
		var d: float = p.distance_to(lead.pos)
		if d < bd:
			bd = d
			var path: PackedVector2Array = cs["path"]
			var i: int = int(cs["i"])
			best = path[i] if i < path.size() and p.distance_to(path[i]) < 200.0 else p
	for e: Ship in nv.ships:
		if e.alive() and nv._hostile(c, e.c) and e.pos.distance_to(centre) <= r and nv._body_px(e.pos) == body:
			var d2: float = e.pos.distance_to(lead.pos) + 300.0
			if d2 < bd:
				bd = d2
				best = e.pos
	return best



func _escort_pos(o: Dictionary, c: int, lead: Ship) -> Variant:
	if not o.has("landing") and gw.naval != null:

		var bl: float = INF
		for L0: Dictionary in gw.naval.landings:
			if int(L0["c"]) == c and (int(L0["stage"]) == Naval.Stage.BOARD or int(L0["stage"]) == Naval.Stage.SAIL):
				var lp: Vector2 = L0["sea"][0] if not (L0["sea"] as PackedVector2Array).is_empty() else lead.pos
				if lp.distance_to(lead.pos) < bl:
					bl = lp.distance_to(lead.pos)
					o["landing"] = int(L0["id"])
	if o.has("landing") and gw.naval != null:
		for L: Dictionary in gw.naval.landings:
			if int(L["id"]) == int(o["landing"]):
				for b: Dictionary in L["boats"]:
					if not bool(b["sunk"]) and not bool(b.get("out", false)):
						o["hd"] = float(b["heading"])
						return b["pos"]
				return L["sea"][0] if not (L["sea"] as PackedVector2Array).is_empty() else null
		o.erase("landing")
	var cs: Dictionary = nv.convoy(int(o.get("conv", -1)))
	if cs.is_empty() or int(cs["owner"]) != c:
		cs = {}
		var bd: float = 3000.0
		for x: Dictionary in nv.convoys():
			if int(x["owner"]) == c and int(x["stage"]) != 0 and nv._body_px(x["pos"]) == nv._body_px(lead.pos):
				var d: float = (x["pos"] as Vector2).distance_to(lead.pos)
				if d < bd:
					bd = d
					cs = x
		o["conv"] = int(cs.get("id", -1))
	if cs.is_empty():
		return null
	o["hd"] = float(cs.get("heading", 0.0))
	return cs["pos"]







func ai(c: Country) -> void :
	var own: Array[Ship] = nv.ships_of(c.id)
	if own.is_empty():
		return
	var bases: Array[Facility] = nv.bases_of(c.id)
	var home: Vector2 = nv.berth_px(bases[0]) if not bases.is_empty() else own[0].pos
	var main: Dictionary = _ai_fleet(c, "main", "Флот")
	var esc: Dictionary = {}
	var enemy_navy: bool = false
	for e: Ship in nv.ships:
		if e.alive() and nv._hostile(c.id, e.c):
			enemy_navy = true
			break
	var my_conv: bool = not nv.convoys_of(c.id).is_empty()
	if my_conv and enemy_navy and own.size() >= 3:
		esc = _ai_fleet(c, "escort", "Конвой")
	for s: Ship in own:
		var hurt: bool = s.hp < s.hp_max * 0.5 or (s.has_mod("ash") and int(s.ammo.get("asm", 0)) == 0) or (s.has_mod("art") and int(s.ammo.get("art", 0)) < NavyArt.SALVO)
		var skip: bool = gw.game_time < float(_svc_skip.get(s.id, 0.0))
		var hf: Facility = _home(s)
		if hurt and hf != null and not skip:

			if s.fleet == 0 and String(s.ord.get("k", "")) == "stop" and s.refit == "" and nv.near_base(s) != null and not _service_due(s, 400):
				_svc_skip[s.id] = gw.game_time + SERVICE_SKIP
				skip = true
			else:
				var ok0: String = String(s.ord.get("k", ""))
				if s.fleet != 0 or not (ok0 == "return" or (ok0 == "stop" and nv.near_base(s) != null)):
					ship_order(s, "return", nv.berth_px(hf))
				continue
		var ready: bool = (s.hp >= s.hp_max * 0.9 or skip) and s.refit == ""
		if s.fleet == 0 and ready and not s.ord.has("strike") and not s.ord.has("art"):
			var to: Dictionary = esc if not esc.is_empty() and members(esc).is_empty() else main
			fleet_add(int(to["id"]), s.id)

	var want: Dictionary = {"k": "patrol", "pos": home, "r": 350.0}
	if gw.naval != null:
		for L: Dictionary in gw.naval.landings:
			if int(L["c"]) == c.id and (int(L["stage"]) == Naval.Stage.BOARD or int(L["stage"]) == Naval.Stage.SAIL):
				want = {"k": "escort", "pos": home, "landing": int(L["id"])}
				break
	if String(want["k"]) == "patrol":
		for cs: Dictionary in nv.convoys():
			if int(cs["stage"]) != 0 and nv._hostile(c.id, int(cs["owner"])) and (cs["pos"] as Vector2).distance_to(home) < 3000.0:
				want = {"k": "hunt", "pos": home, "r": 3000.0}
				break
	if String(want["k"]) != "escort" and gw.get("supply") != null and not members(main).is_empty():
		var bw: Dictionary = gw.supply.ai_blockade_want(c, members(main), home)
		if not bw.is_empty():
			want = bw
	var cur: Dictionary = main.get("order", {})
	if String(cur.get("k", "")) != String(want["k"]) or int(cur.get("landing", -1)) != int(want.get("landing", -1)) or (String(want["k"]) == "blockade" and (cur.get("pos", Vector2.ZERO) as Vector2).distance_to(want["pos"]) > 50.0):
		if not members(main).is_empty():
			fleet_order(c.id, int(main["id"]), String(want["k"]), want["pos"], float(want.get("r", -1.0)))
			if want.has("landing"):
				(main["order"] as Dictionary)["landing"] = want["landing"]
	if not esc.is_empty() and not members(esc).is_empty() and String((esc.get("order", {}) as Dictionary).get("k", "")) != "escort":
		fleet_order(c.id, int(esc["id"]), "escort", home)



	var P: Dictionary = gw.ai.persona_of(c) if gw.ai != null else {}
	var raids: bool = GameConfig.diff_of(c) >= 1 or float(P.get("aggr", 0.5)) > 0.5
	for s2: Ship in own:
		if not s2.has_mod("vls") or int(s2.ammo.get("cm", 0)) <= 0:
			if s2.ord.has("strike"):
				ship_order(s2, "return", home)
			continue
		if s2.ord.has("strike"):
			var sp: Vector2 = s2.ord["strike"]
			if s2.pos.distance_to(sp) <= Navy.CM_RANGE * 0.95:
				nv.launch_cruise(s2, sp, 4)
				_cm_at[s2.id] = gw.game_time
				ship_order(s2, "return", home)
			elif String(s2.ord.get("k", "")) != "move":
				ship_order(s2, "return", home)
			continue
		if gw.game_time - float(_cm_at.get(s2.id, -999.0)) <= 120.0:
			continue
		var tf: Facility = nv._cm_target(s2)
		if tf != null:
			_cm_at[s2.id] = gw.game_time
			nv.launch_cruise(s2, tf.center_px(), 2)
		elif raids and s2.hp >= s2.hp_max * 0.8 and gw.game_time - float(_cm_at.get(s2.id, -999.0)) > 240.0:
			_strike_trip(c, s2)




func _strike_trip(c: Country, s: Ship) -> void :
	var best: Facility = null
	var bd: float = Navy.CM_RANGE * 2.5
	for f: Facility in gw.mil.facilities:
		if not nv._hostile(c.id, f.country_id) or not gw.mil.alive(f):
			continue
		if f.kind != Facility.Kind.NAVAL_BASE and f.kind != Facility.Kind.PORT and f.kind != Facility.Kind.POWER_PLANT and f.kind != Facility.Kind.REFINERY:
			continue
		var d: float = f.center_px().distance_to(s.pos)
		if d < bd:
			bd = d
			best = f
	_cm_at[s.id] = gw.game_time
	if best == null:
		return
	var tp: Vector2 = best.center_px()
	var body: int = nv._body_px(s.pos)
	var away: Vector2 = (s.pos - tp).normalized()
	for frac: float in [0.8, 0.65, 0.5]:
		var q: Vector2i = nv._sea_near(tp + away * Navy.CM_RANGE * frac, 10, body)
		if q.x < 0:
			continue
		var lp: Vector2 = nv._ports().cell_px(q)
		if lp.distance_to(tp) <= Navy.CM_RANGE * 0.9 and ship_order(s, "move", lp) == "":
			s.ord["strike"] = tp
			return


func _ai_fleet(c: Country, role: String, fname: String) -> Dictionary:
	for fl: Dictionary in fleets:
		if int(fl["c"]) == c.id and String(fl.get("ai", "")) == role:
			return fl
	var id: int = fleet_create(c.id, fname, c.color, [])
	var fl2: Dictionary = fleet(id)
	fl2["ai"] = role
	return fl2




func save() -> Dictionary:
	return {"fleets": fleets, "_id": _id}


func load(d: Dictionary) -> void :
	fleets.clear()
	for f: Variant in d.get("fleets", []):
		if f is Dictionary and (f as Dictionary).has("id") and (f as Dictionary).has("c"):
			var fl: Dictionary = f
			for k: String in ["ships", "order"]:
				if not fl.has(k):
					fl[k] = [] if k == "ships" else {}
			fleets.append(fl)
	_id = maxi(1, int(d.get("_id", 1)))
	for fl2: Dictionary in fleets:
		_id = maxi(_id, int(fl2["id"]) + 1)

	for s: Ship in nv.ships:
		if s.fleet != 0 and not (fleet(s.fleet).get("ships", []) as Array).has(s.id):
			s.fleet = 0
	_salvo_at.clear()
	_cm_at.clear()
	_lead_of.clear()
	_svc_skip.clear()
