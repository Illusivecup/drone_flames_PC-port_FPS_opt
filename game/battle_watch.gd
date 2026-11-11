class_name BattleWatch
extends RefCounted







const CELL_PX: float = 128.0
const TAU: float = 10.0
const MIN_HEAT: float = 3.0
const OWN_T: float = 30.0
const IMPACT_KEEP: float = 20.0
const FIGHT_CELL: float = 160.0
const LIVE_R: float = 140.0
const FRESH_S: float = 1.5
const STRIKE_KEEP: float = 60.0

var gw: GameWorld
var cells: Dictionary = {}
var impacts: Array = []
var _prune_t: float = 0.0
var _hs_t: float = -1.0
var _hs: Dictionary = {}


func _init(world: GameWorld) -> void :
	gw = world




func note(pos: Vector2, heat: float, label: String = "", cid: int = -1) -> void :
	if not pos.is_finite():
		return
	var k: = Vector2i(floori(pos.x / CELL_PX), floori(pos.y / CELL_PX))
	var now: float = gw.game_time
	var e: Array = cells.get(k, [])
	if e.is_empty():
		e = [0.0, now, 0.0, 0.0, 0.0, "", -999.0, -999.0]
		cells[k] = e
	var h: float = float(e[0]) * exp( - (now - float(e[1])) / TAU) + heat
	e[0] = h
	e[1] = now

	var fade: float = 0.85 if float(e[4]) > 0.0 else 0.0
	e[2] = float(e[2]) * fade + pos.x * heat
	e[3] = float(e[3]) * fade + pos.y * heat
	e[4] = float(e[4]) * fade + heat
	if label != "" and (heat >= 2.0 or now - float(e[7]) > 10.0):
		e[5] = label
		e[7] = now
	if gw.player != null and cid >= 0 and (cid == gw.player.id or _owner_at(pos) == gw.player.id):
		e[6] = now



func impact(pos: Vector2, label: String, by: int = -1) -> void :
	note(pos, 6.0, label, by)
	if not _may_show(pos, by):
		return
	impacts.append({"pos": pos, "t": gw.game_time, "label": label, "c": by})
	if impacts.size() > 8:
		impacts.remove_at(0)


func _owner_at(p: Vector2) -> int:
	var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	if gw.data == null or not gw.data.inside(c.x, c.y):
		return -1
	return gw.data.get_owner_id(c.x, c.y)



func _may_show(p: Vector2, by: int) -> bool:
	if gw.player == null:
		return true
	if by == gw.player.id or _owner_at(p) == gw.player.id:
		return true
	if gw.vision != null and gw.vision.has_method("sees"):
		return gw.vision.sees(p)
	return true


func heat_at(k: Vector2i) -> float:
	var e: Array = cells.get(k, [])
	if e.is_empty():
		return 0.0
	return float(e[0]) * exp( - (gw.game_time - float(e[1])) / TAU)








func hot_spot() -> Dictionary:
	var now: float = gw.game_time
	if now == _hs_t:
		return _hs.duplicate()
	_hs_t = now
	_hs = _fight_spot()
	if _hs.is_empty():
		_hs = _heat_spot(true)
	var p: Country = gw.player
	var war: bool = p != null and not p.eliminated and not p.at_war.is_empty()
	var fr: Dictionary = player_front() if _hs.is_empty() and war else {}
	if not fr.is_empty() and (String(fr["kind"]) == "army" or String(fr["kind"]) == "enemy"):
		_hs = {"pos": fr["pos"], "heat": 0.0, "label": fr["label"], "kind": "front"}
	if _hs.is_empty():
		_hs = _heat_spot(false)
	if _hs.is_empty() and war:
		_hs = _player_strike()
		if _hs.is_empty() and not fr.is_empty() and String(fr["kind"]) == "city":
			_hs = {"pos": fr["pos"], "heat": 0.0, "label": fr["label"], "kind": "front"}
	return _hs.duplicate()




func _fight_spot() -> Dictionary:
	if gw.army == null:
		return {}
	var now: float = gw.game_time
	var pid: int = gw.player.id if gw.player != null else -1
	var cl: Dictionary = {}
	for u: Unit in gw.army.units:
		if not u.alive() or not u.ground():
			continue
		var busy: bool = u.target != null and (u.state == Unit.State.FIGHT or u.state == Unit.State.SIEGE) and not u.indirect()
		if not busy and now - u.hit_t > 4.0:
			continue
		var k: = Vector2i(floori(u.pos.x / FIGHT_CELL), floori(u.pos.y / FIGHT_CELL))
		var e: Array = cl.get(k, [])
		if e.is_empty():
			e = [0.0, 0.0, 0.0, 0, false, 0]
			cl[k] = e
		if busy:
			e[5] = int(e[5]) + 1
		e[0] = float(e[0]) + (1.0 if busy else 0.6)
		e[1] = float(e[1]) + u.pos.x
		e[2] = float(e[2]) + u.pos.y
		e[3] = int(e[3]) + 1
		if u.country_id == pid:
			e[4] = true
	var best: = Vector2.INF
	var bs: float = 1.5
	for k: Vector2i in cl:
		var e: Array = cl[k]
		var pos: = Vector2(float(e[1]), float(e[2])) / float(e[3])
		if int(e[5]) == 0 and not _two_sides(pos, FIGHT_CELL * 1.5):
			continue
		var mine: bool = bool(e[4]) or (pid >= 0 and _owner_at(pos) == pid)
		if not mine and not _may_show(pos, -1):
			continue
		var s: float = float(e[0])
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var e2: Array = cl.get(k + o, [])
			if not e2.is_empty():
				s += float(e2[0]) * 0.5
		if mine:
			s *= 4.0
		if s > bs:
			bs = s
			best = pos
	if not best.is_finite():
		return {}
	best = _on_troops(best, -1)
	var he: Array = cells.get(Vector2i(floori(best.x / CELL_PX), floori(best.y / CELL_PX)), [])
	var kind: String = String(he[5]) if not he.is_empty() and now - float(he[7]) < 20.0 else ""
	return {"pos": best, "heat": bs, "label": _label(best, kind), "kind": "fight"}




func _live(p: Vector2, age: float, troops: bool = false) -> bool:
	if not troops and age <= FRESH_S * maxf(1.0, gw.time_scale):
		return true
	if gw.army == null:
		return false
	return _two_sides(p, LIVE_R * 1.5)



func _two_sides(p: Vector2, r: float) -> bool:
	var first: int = -1
	var others: Dictionary = {}
	for u: Unit in gw.army._near(p, r):
		if not u.alive() or u.pos.distance_squared_to(p) > r * r:
			continue
		if first < 0:
			first = u.country_id
		elif u.country_id != first:
			others[u.country_id] = true
	for o: int in others:
		if gw.army._hostile(first, o):
			return true
	if others.size() > 1:
		var ks: Array = others.keys()
		for i in ks.size():
			for j in range(i + 1, ks.size()):
				if gw.army._hostile(int(ks[i]), int(ks[j])):
					return true
	return false




func _on_troops(p: Vector2, cid: int = -1) -> Vector2:
	if gw.army == null or not p.is_finite():
		return p
	var near: Unit = null
	var bd: float = 400.0 * 400.0
	for u: Unit in gw.army.units:
		if u.alive() and u.ground() and (cid < 0 or u.country_id == cid):
			var d: float = u.pos.distance_squared_to(p)
			if d < bd:
				bd = d
				near = u
	if near == null:
		return p
	var s: = Vector2.ZERO
	var n: int = 0
	for u2: Unit in gw.army._near(near.pos, 80.0):
		if u2.alive() and u2.ground() and (cid < 0 or u2.country_id == cid) and u2.pos.distance_squared_to(near.pos) <= 6400.0:
			s += u2.pos
			n += 1
	return s / float(n) if n > 0 else near.pos




func follow(p: Vector2) -> Vector2:
	if gw.army == null or not p.is_finite():
		return p
	var s: = Vector2.ZERO
	var n: int = 0
	var s2: = Vector2.ZERO
	var n2: int = 0
	for u: Unit in gw.army._near(p, 220.0):
		if not u.alive() or u.pos.distance_squared_to(p) > 220.0 * 220.0:
			continue
		s2 += u.pos
		n2 += 1
		if u.target != null and u.state == Unit.State.FIGHT:
			s += u.pos
			n += 1
	if n > 0:
		return p.lerp(s / float(n), 0.5)
	if n2 > 0:
		return p.lerp(s2 / float(n2), 0.5)
	return p






func player_front() -> Dictionary:
	var p: Country = gw.player
	if p == null or p.eliminated:
		return {}
	var now: float = gw.game_time
	var ops: Operations = gw.ops
	if ops != null and gw.army != null:
		var best: Facility = null
		var bs: float = INF
		for f: Facility in ops.list:
			var op: Dictionary = ops.list[f]
			if int(op["c"]) != p.id or int(op["kind"]) == Operations.Kind.RETREAT:
				continue
			var top: Dictionary = gw.army.tac.ops.get(f, {})
			var s: float = (op["front"] as Vector2).distance_to(op["target"])
			if not top.is_empty() and now - float(top["contact"]) < 10.0:
				s -= 100000.0
			if s < bs:
				bs = s
				best = f
		if best != null:
			var bo: Dictionary = ops.list[best]
			return {"pos": _on_troops(bo["front"], p.id), "label": Loc.t("Армия №%d: %s") % [best.army_no, Loc.msg(bo["state"])], "kind": "army"}
		var ef: Facility = null
		var ed: float = INF
		for f2: Facility in ops.list:
			var op2: Dictionary = ops.list[f2]
			if int(op2["c"]) == p.id or int(op2["kind"]) != Operations.Kind.ATTACK or not p.at_war.has(int(op2["c"])):
				continue
			var fr: Vector2 = op2["front"]
			var tc: int = int(op2["city"])
			var mine: bool = (tc >= 0 and gw.cities[tc].country_id == p.id) or _owner_at(op2["target"]) == p.id
			if not mine or not _may_show(fr, -1):
				continue
			var d: float = fr.distance_to(op2["target"])
			if d < ed:
				ed = d
				ef = f2
		if ef != null:
			var eo: Dictionary = ops.list[ef]
			var ec: int = int(eo["city"])
			var nm: String = (Loc.t("Враг идёт на %s") % [gw.cities[ec].name]) if ec >= 0 else Loc.t("Враг идёт к нашей земле")
			return {"pos": _on_troops(eo["front"], int(eo["c"])), "label": nm, "kind": "enemy"}

		var nu: Unit = null
		var nd: float = 2500.0
		for u: Unit in gw.army.units:
			if u.country_id != p.id or not u.alive() or not u.ground() or u.home == null:
				continue
			if u.pos.distance_to(gw.army.barracks_out(u.home)) < 150.0:
				continue
			for cid2: int in p.at_war:
				var oc: Country = gw.country_by_id(cid2)
				if oc == null:
					continue
				for ci: int in oc.city_ids:
					var dd: float = u.pos.distance_to(Vector2(gw.cities[ci].center * GameWorld.CELL))
					if dd < nd:
						nd = dd
						nu = u
		if nu != null:
			var fp: Vector2 = _on_troops(nu.pos, p.id)
			return {"pos": fp, "label": _label(fp, Loc.t("Армия №%d") % nu.home.army_no, true), "kind": "army"}
	var hc: City = null
	for cid: int in p.city_ids:
		var c: City = gw.cities[cid]
		if c.hit_t > 0.0 and now - c.hit_t < 60.0 and (hc == null or c.hit_t > hc.hit_t):
			hc = c
	if hc != null:
		return {"pos": Vector2(hc.center * GameWorld.CELL), "label": Loc.t("%s под огнём") % [hc.name], "kind": "city"}
	if p.capital_id >= 0:
		var cap: City = gw.cities[p.capital_id]
		return {"pos": Vector2(cap.center * GameWorld.CELL), "label": Loc.t("Столица: %s") % [cap.name], "kind": "home"}
	return {}



func _player_strike() -> Dictionary:
	var p: Country = gw.player
	if p == null:
		return {}
	for i in range(impacts.size() - 1, -1, -1):
		var im: Dictionary = impacts[i]
		if gw.game_time - float(im["t"]) > STRIKE_KEEP:
			break
		if int(im.get("c", -1)) != p.id and _owner_at(im["pos"]) == p.id:
			return {"pos": im["pos"], "heat": 0.0, "label": _label(im["pos"], String(im["label"])), "kind": "strike"}
	return {}




func _heat_spot(troops: bool = false) -> Dictionary:
	var now: float = gw.game_time
	var best: Vector2i = Vector2i(-99999, -99999)
	var bs: float = MIN_HEAT
	_prune()
	for k: Vector2i in cells:
		var h: float = heat_at(k)
		if h < MIN_HEAT * 0.5:
			continue

		var s: float = h
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if cells.has(k + o):
				s += heat_at(k + o) * 0.5
		if s <= bs:
			continue
		var e: Array = cells[k]
		var p: Vector2 = Vector2(float(e[2]), float(e[3])) / maxf(0.001, float(e[4]))
		if now - float(e[6]) > OWN_T and not _may_show(p, -1):
			continue
		if not _live(p, now - float(e[1]), troops):
			continue
		bs = s
		best = k
	if best.x == -99999:
		return {}
	var be: Array = cells[best]
	var pos: Vector2 = Vector2(float(be[2]), float(be[3])) / maxf(0.001, float(be[4]))
	if troops or gw.game_time - float(be[1]) > FRESH_S * maxf(1.0, gw.time_scale):
		pos = _on_troops(pos, -1)
	return {"pos": pos, "heat": bs, "label": _label(pos, String(be[5])), "kind": "heat"}


func last_impact() -> Dictionary:
	if impacts.is_empty():
		return {}
	return (impacts[impacts.size() - 1] as Dictionary).duplicate()



func _label(p: Vector2, kind: String, colon_field: bool = false) -> String:
	var city: City = null
	var bd: float = 900.0
	for c: City in gw.cities:
		var d: float = Vector2(c.center * GameWorld.CELL).distance_to(p) - float(c.radius * GameWorld.CELL)
		if d < bd:
			bd = d
			city = c
	var head: String = Loc.t(kind) if kind != "" else Loc.t("Бой")
	if city == null:
		return head + (Loc.t(": в поле") if colon_field else Loc.t(" в поле"))
	if Vector2(city.center * GameWorld.CELL).distance_to(p) < float(city.radius * GameWorld.CELL) * 0.8:
		return Loc.t("%s в %s") % [head, prepositional(city.name)]
	return Loc.t("%s у %s") % [head, genitive(city.name)]



static func genitive(n: String) -> String:
	for e: Array in [["ичи", "ичей"], ["ное", "ного"], ["ополь", "ополя"], ["оград", "ограда"], ["ань", "ани"], ["ец", "ца"], ["ка", "ки"], ["ск", "ска"], ["ов", "ова"], ["ий", "ого"], ["ок", "ка"]]:
		if n.ends_with(e[0]):
			return n.substr(0, n.length() - String(e[0]).length()) + String(e[1])
	return n



static func prepositional(n: String) -> String:
	for e: Array in [["ичи", "ичах"], ["ное", "ном"], ["ополь", "ополе"], ["оград", "ограде"], ["ань", "ани"], ["ец", "це"], ["ка", "ке"], ["ск", "ске"], ["ов", "ове"], ["ок", "ке"]]:
		if n.ends_with(e[0]):
			return n.substr(0, n.length() - String(e[0]).length()) + String(e[1])
	return n






func cam_plan() -> Array:
	var out: Array = []
	var hs: Dictionary = hot_spot()
	if not hs.is_empty():

		var hk: String = String(hs.get("kind", "fight"))
		out.append({"pos": hs["pos"], "zoom": 2.0 if hk == "strike" else 2.5, "hold_s": 3.5, "kind": "impact" if hk == "strike" else "hot", "label": hs["label"], 
			"speed": 1.0 if gw.time_scale > 4.0 and (hk == "fight" or hk == "front") else 0.0, "follow": hk == "fight" or hk == "front"})
	var inc: Dictionary = _incoming()
	if not inc.is_empty():
		out.append(inc)
	else:
		var li: Dictionary = last_impact()
		if not li.is_empty() and gw.game_time - float(li["t"]) <= IMPACT_KEEP and (hs.is_empty() or (li["pos"] as Vector2).distance_to(hs["pos"]) > 60.0):
			out.append({"pos": li["pos"], "zoom": 2.0, "hold_s": 2.5, "kind": "impact", "label": li["label"], "speed": 0.0})
	if out.is_empty():
		return out
	out.append({"pos": Vector2.INF, "zoom": -1.0, "hold_s": 0.0, "kind": "back", "label": "", "speed": 0.0})
	return out



func _incoming() -> Dictionary:
	if gw.mil == null:
		return {}
	var best: Missile = null
	for m: Missile in gw.mil.missiles:
		if m.state == Missile.State.DONE or m.time_left() > 8.0 or m.time_left() < 0.8:
			continue
		if not _may_show(m.target, m.country_id):
			continue
		if best == null or m.time_left() < best.time_left():
			best = m
	if best == null:
		return {}
	var ts: float = maxf(1.0, gw.time_scale)

	return {"pos": best.target, "zoom": 2.0, "hold_s": clampf(best.time_left() / ts + 1.5, 2.0, 7.0), "kind": "incoming", 
		"label": Loc.t("Ракета на подлёте"), "speed": 1.0 if gw.time_scale > 2.0 else 0.0}


func _prune() -> void :
	if gw.game_time - _prune_t < 10.0:
		return
	_prune_t = gw.game_time
	for k: Vector2i in cells.keys():
		if heat_at(k) < 0.05:
			cells.erase(k)


func save_state() -> Dictionary:
	var cs: Array = []
	for k: Vector2i in cells:
		var e: Array = cells[k]
		cs.append([k, float(e[0]), float(e[1]), float(e[2]), float(e[3]), float(e[4]), String(e[5]), float(e[6]), float(e[7])])
	return {"cells": cs, "impacts": impacts.duplicate(true)}


func load_state(d: Dictionary) -> void :
	cells.clear()
	for r: Array in d.get("cells", []):
		cells[r[0] as Vector2i] = [float(r[1]), float(r[2]), float(r[3]), float(r[4]), float(r[5]), String(r[6]), float(r[7]), float(r[8])]
	impacts.clear()
	for i: Dictionary in d.get("impacts", []):
		impacts.append(i)
