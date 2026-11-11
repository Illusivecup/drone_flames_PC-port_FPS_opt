extends RefCounted











const NavyStrike = preload("res://game/navy_strike.gd")
const BASE_W_IDS: Array[String] = ["drone", "jet", "tel", "ship", "art", "bomber", "hyper"]
const W_IDS: Array[String] = ["drone", "jet", "tel", "ship", "art", "bomber", "hyper", "thermo", "nuke", "iskander"]

static func active_w_ids(gw: GameWorld = null) -> Array[String]:
	var out: Array[String] = BASE_W_IDS.duplicate()
	var root = Engine.get_main_loop().root if Engine.get_main_loop() != null else null
	var mm = root.get_node_or_null("ModManager") if root != null else null
	if mm != null and mm.has_method("is_mod_loaded"):
		if mm.is_mod_loaded("thermo_battery"):
			out.append("thermo")
		if mm.is_mod_loaded("nuclear_strike"):
			out.append("nuke")
		if mm.is_mod_loaded("iskander_strike"):
			out.append("iskander")
	elif gw != null:
		if gw.has_meta("thermo_battery_mod"):
			out.append("thermo")
		if gw.has_meta("nuclear_strike_mod"):
			out.append("nuke")
		if gw.has_meta("iskander_strike_mod"):
			out.append("iskander")
	return out
const W_INFO: Dictionary = {
	"drone": {"short": "БПЛА", "title": "Ударные БПЛА", "sub": "дронопорты", "icon": "icon_launch", "col": Color("ffb000"), "unit": "БПЛА"}, 
	"jet": {"short": "РЕАКТ.", "title": "Реактивные БПЛА", "sub": "ВПП", "icon": "icon_jet_uav", "col": Color("7cccff"), "unit": "БПЛА"}, 
	"tel": {"short": "ОТРК", "title": "ОТРК", "sub": "баллистика", "icon": "icon_tel", "col": Color("ff5a3c"), "unit": "ракет"}, 
	"ship": {"short": "КР МОРЕ", "title": "КР с кораблей", "sub": "УВП кораблей", "icon": "icon_ship_cr", "col": Color("3fd8c4"), "unit": "КР"}, 
	"art": {"short": "АРТ. УДАР", "title": "Артбатареи", "sub": "по берегу, до 400 м вглубь", "icon": "icon_ship_art", "col": Color("ffd166"), "unit": "залпов"}, 
	"bomber": {"short": "КР АВИА", "title": "КР с самолётов", "sub": "носители", "icon": "icon_bomber", "col": Color("c69cff"), "unit": "КР"}, 
	"hyper": {"short": "ГИПЕР", "title": "Гиперзвук", "sub": "истребители", "icon": "icon_m_hyper", "col": Color("ff72d6"), "unit": "ракет"}, 
	"thermo": {"short": "СОЛНЦЕПЁК", "title": "Батарея «Солнцепёк»", "sub": "ТОС-1А · термобар", "icon": "icon_mlrs", "col": Color("ff8c3c"), "unit": "залпов"}, 
	"nuke": {"short": "МБР", "title": "Шахта МБР «Сармат»", "sub": "стратегический ядерный", "icon": "icon_m_ballistic", "col": Color("ff3333"), "unit": "ракет"}, 
	"iskander": {"short": "ИСКАНДЕР", "title": "ОТРК «Искандер-М»", "sub": "баллистика · 9К720", "icon": "icon_iskander", "col": Color("e84128"), "unit": "ракет"}, 
}

const AIR_TAKEOFF: float = 4.5
const TEL_NEXT: float = 6.0
const DRONE_NEXT: float = 4.0

static var sync_arrive: bool = true


static var actor: Country = null


static func _p(gw: GameWorld) -> Country:
	return actor if actor != null else gw.player

var active: bool = false
var cur: String = "drone"
var plans: Dictionary = {}
var pending: Array = []
var log: Array = []
var last_drones: Array = []
var _closed: Dictionary = {}
var _closed_ms: int = -1000000
var _wid: int = 0
var _ready_c: Dictionary = {}
var _drop_n: int = 0
var _ready_t: int = -1000000


func begin(gw: GameWorld) -> void :
	active = true
	plans.clear()
	if gw.get_instance_id() != _wid:
		_closed = {}
	_drop_old(gw)
	_wid = gw.get_instance_id()
	if Time.get_ticks_msec() - _closed_ms < 90000 and not _closed.is_empty():
		plans = _closed.duplicate(true)
	_closed = {}
	_ready_t = -1000000



func end(cur_targets: Array, fired: bool) -> void :
	if not active:
		return
	active = false
	if not fired:
		stash(cur, cur_targets)
		var keep: Dictionary = {}
		for w: String in plans:
			if not (plans[w] as Array).is_empty():
				keep[w] = plans[w]
		_closed = keep
		_closed_ms = Time.get_ticks_msec()
	else:
		_closed = {}
	plans.clear()


func stash(wid: String, targets: Array) -> void :
	var out: Array = []
	for t: Dictionary in targets:
		var wps: Array[Vector2] = []
		wps.assign(t.get("wps", []))
		out.append({"pos": t["pos"], "n": int(t["n"]), "wps": wps})
	plans[wid] = out


func take(wid: String) -> Array:
	var a: Array = plans.get(wid, [])
	plans.erase(wid)
	return a


func restored() -> bool:
	return not plans.is_empty()


static func title(wid: String) -> String:
	return String((W_INFO.get(wid, {}) as Dictionary).get("title", wid))


static func short(wid: String) -> String:
	return String((W_INFO.get(wid, {}) as Dictionary).get("short", wid))


static func icon(wid: String) -> String:
	return String((W_INFO.get(wid, {}) as Dictionary).get("icon", "icon_target"))


static func colour(wid: String) -> Color:
	return (W_INFO.get(wid, {}) as Dictionary).get("col", Color.WHITE)


static func n_of(targets: Array) -> int:
	var n: int = 0
	for t: Dictionary in targets:
		n += int(t["n"])
	return n





func ready_all(gw: GameWorld) -> Dictionary:
	var now: int = Time.get_ticks_msec()
	if now - _ready_t < 500 and not _ready_c.is_empty():
		return _ready_c
	_ready_t = now
	for w: String in active_w_ids(gw):
		_ready_c[w] = _ready(gw, w)
	return _ready_c


func _ready(gw: GameWorld, wid: String) -> Array:
	var p: Country = gw.player
	if p == null:
		return [0, ""]
	var mil: Military = gw.mil
	match wid:
		"drone", "jet":
			var jet: bool = wid == "jet"
			var n: int = mil.ready_drones(p.id, jet)
			if n > 0:
				return [n, ""]
			if not mil.has_kind(p.id, Facility.Kind.DRONE_PORT):
				return [0, Loc.t("Нет дронопорта: ВОЕННОЕ › ДРОНОПОРТ")]
			var nd: float = mil.next_drone_in(p.id)
			if jet:
				return [0, Loc.t("Нет реактивных: дронный завод › тип «РЕАКТИВН.», нужна ВПП")]
			if nd >= 0.0:
				return [0, Loc.t("Дрон будет через %d с") % int(ceil(nd))]
			return [0, Loc.t("Нет дронов: постройте дронный завод")]
		"tel":
			var mp: Dictionary = mil.missile_multi_plan(p, [])
			if int(mp["available"]) > 0 or mil.has_kind(p.id, Facility.Kind.TEL):
				return [int(mp["available"]), String(mp["why"])]
			return [0, Loc.t("Нет ОТРК: АРМИЯ › ОТРК")]
		"iskander":
			var isk_cnt: int = 0
			var isk_total: int = 0
			var isk_why: String = ""
			if mil != null:
				for f in mil.facilities:
					if f != null and is_instance_valid(f) and f.country_id == p.id and (f.army_build == "iskander_tel" or bool(f.get_meta("is_iskander_tel", false))) and f.hp > 0.0:
						isk_total += 1
						if bool(f.get_meta("has_missile", false)) and not bool(f.get_meta("is_reloading", false)):
							isk_cnt += 1
						elif isk_why == "":
							isk_why = Loc.t("ОТРК «Искандер-М» перезаряжается")
			if isk_total > 0:
				if isk_cnt > 0:
					return [isk_cnt, ""]
				return [0, isk_why]
			return [0, Loc.t("Нет ОТРК: АРМИЯ › ИСКАНДЕР")]
		"ship":
			var sp: Dictionary = NavyStrike.plan(gw, p.id, [])
			return [int(sp["available"]), String(sp["why"])]
		"art":
			var ap0: Dictionary = gw.navy.art.plan(p.id, []) if gw.navy != null else {"available": 0, "why": Loc.t("Нет флота")}
			return [int(ap0["available"]), String(ap0["why"])]
		"bomber", "hyper":
			var ap: Dictionary = mil.air.multi_plan(p, [], wid == "hyper")
			var why: String = String(ap["why"])
			if int(ap["available"]) == 0:
				why = (Loc.t("Нет истребителя с гиперзвуком: аэродром › истребитель › подвес «ГИПЕР»") if wid == "hyper"
					else Loc.t("Нет КР на носителях: аэродром › бомбардировщик (или подвес КР)"))
			return [int(ap["available"]), why]
		"thermo":
			var cnt: int = 0
			var why: String = ""
			if mil != null:
				for f in mil.facilities:
					if f != null and is_instance_valid(f) and f.country_id == p.id and (f.army_build == "thermo_battery" or bool(f.get_meta("is_thermo", false))) and f.hp > 0.0:
						if int(f.get_meta("state", 0)) == 0:
							cnt += 1
						elif why == "":
							why = Loc.t("Батарея «Солнцепёк» перезаряжается")
			var max_by_res: int = mini(p.money / 500, p.metal / 6) if (p.money >= 0 and p.metal >= 0) else 0
			if cnt > 0 and max_by_res < cnt:
				cnt = max_by_res
				if cnt == 0 and why == "":
					why = Loc.t("Не хватает ресурсов: нужно 500 $ и 6 металла на залп")
			if cnt == 0 and why == "":
				why = Loc.t("Нет батареи «Солнцепёк»: АРМИЯ › СОЛНЦЕПЁК")
			return [cnt, why]
		"nuke":
			var cnt: int = 0
			var why: String = ""
			if mil != null:
				for f in mil.facilities:
					if f != null and is_instance_valid(f) and f.country_id == p.id and (f.army_build == "nuclear_silo" or bool(f.get_meta("is_nuclear_silo", false))) and f.hp > 0.0:
						if bool(f.get_meta("has_warhead", false)):
							cnt += 1
						elif why == "":
							why = Loc.t("В шахте МБР нет собранной боеголовки")
			if cnt == 0 and why == "":
				why = Loc.t("Нет шахты МБР: АРМИЯ › ЯДЕРНЫЙ УДАР")
			return [cnt, why]
	return [0, ""]





static func plan(gw: GameWorld, wid: String, targets: Array) -> Dictionary:
	var p: Country = _p(gw)
	var mp: Dictionary = {}
	match wid:
		"drone", "jet":
			mp = gw.mil.multi_plan(p, targets, wid == "jet")
			mp["assigned"] = int(mp.get("launch", 0))
		"tel":
			mp = gw.mil.missile_multi_plan(p, targets)
		"iskander":
			var isk_free: Array[Facility] = []
			if gw.mil != null:
				for f: Facility in gw.mil.facilities:
					if f != null and is_instance_valid(f) and f.country_id == p.id and (f.army_build == "iskander_tel" or bool(f.get_meta("is_iskander_tel", false))) and f.hp > 0.0:
						if bool(f.get_meta("has_missile", false)) and not bool(f.get_meta("is_reloading", false)):
							isk_free.append(f)
			mp = _iskander_plan(gw, p, targets, isk_free)
		"ship":
			mp = NavyStrike.plan(gw, p.id, targets)
		"art":
			mp = gw.navy.art.plan(p.id, targets) if gw.navy != null else {}
		"bomber", "hyper":
			mp = gw.mil.air.multi_plan(p, targets, wid == "hyper")
		"thermo":
			mp = _thermo_plan(gw, p, targets)
		"nuke":
			mp = _nuke_plan(gw, p, targets)
	return mp


static func _strike_pts(targets: Array) -> Array:
	var out: Array = []
	for e: Variant in targets:
		if e is Vector2:
			out.append([e, 1])
		elif e is Dictionary:
			out.append([(e as Dictionary).get("pos", Vector2.ZERO), clampi(int((e as Dictionary).get("n", 1)), 1, 99)])
	return out


static func plan_single(gw: GameWorld, wid: String, target: Vector2, has_target: bool) -> Dictionary:
	var p: Country = _p(gw)
	var info: Dictionary = {"tel": null, "from": Vector2.ZERO, "launch": Vector2.ZERO, "dist": 0.0, "in_range": false, "available": 0, "flight": 0.0, "alt0": 0.0}
	if p == null or gw == null:
		return info
	if wid == "tel":
		return gw.mil.missile_plan(p, target, has_target)
	elif wid == "iskander":
		var best: Facility = null
		var bd: float = INF
		var avail: int = 0
		if gw.mil != null:
			for f: Facility in gw.mil.facilities:
				if f != null and is_instance_valid(f) and f.country_id == p.id and (f.army_build == "iskander_tel" or bool(f.get_meta("is_iskander_tel", false))) and f.hp > 0.0:
					if bool(f.get_meta("has_missile", false)) and not bool(f.get_meta("is_reloading", false)):
						avail += 1
						var d: float = f.center_px().distance_to(target) if has_target else 0.0
						if d < bd:
							bd = d
							best = f
		info["available"] = avail
		info["tel"] = best
		if best != null:
			info["from"] = best.center_px()
			info["launch"] = best.center_px()
			if has_target:
				info["dist"] = bd
				info["in_range"] = true
				info["flight"] = clampf(bd / 380.0, 4.5, 9.0)
		return info
	elif wid == "thermo":
		var best: Facility = null
		var bd: float = INF
		var avail: int = 0
		if gw.mil != null:
			for f: Facility in gw.mil.facilities:
				if f != null and is_instance_valid(f) and f.country_id == p.id and (f.army_build == "thermo_battery" or bool(f.get_meta("is_thermo", false))) and f.hp > 0.0:
					if int(f.get_meta("state", 0)) == 0:
						avail += 1
						var d: float = f.center_px().distance_to(target) if has_target else 0.0
						if d < bd:
							bd = d
							best = f
		var max_by_res: int = mini(p.money / 500, p.metal / 6) if (p.money >= 0 and p.metal >= 0) else 0
		avail = mini(avail, max_by_res)
		info["available"] = avail
		info["tel"] = best
		if best != null:
			info["from"] = best.center_px()
			info["launch"] = best.center_px()
			if has_target:
				info["dist"] = bd
				info["in_range"] = bd >= 90.0 and bd <= 640.0
				info["flight"] = 4.0
		return info
	elif wid == "nuke":
		var best: Facility = null
		var bd: float = INF
		var avail: int = 0
		if gw.mil != null:
			for f: Facility in gw.mil.facilities:
				if f != null and is_instance_valid(f) and f.country_id == p.id and (f.army_build == "nuclear_silo" or bool(f.get_meta("is_nuclear_silo", false))) and f.hp > 0.0:
					if bool(f.get_meta("has_warhead", false)):
						avail += 1
						var d: float = f.center_px().distance_to(target) if has_target else 0.0
						if d < bd:
							bd = d
							best = f
		info["available"] = avail
		info["tel"] = best
		if best != null:
			info["from"] = best.center_px()
			info["launch"] = best.center_px()
			if has_target:
				info["dist"] = bd
				info["in_range"] = true
				info["flight"] = clampf(5.5 + bd * 0.002, 6.5, 9.5)
		return info
	return info


static func _iskander_plan(gw: GameWorld, p: Country, targets: Array, free: Array[Facility]) -> Dictionary:
	var out: Dictionary = {"ok": false, "total": 0, "available": free.size(), "assigned": 0, "per_target": [], "plan": [], "why": "", "tels": 0}
	if p == null or gw == null:
		return out
	var avail: int = free.size()
	var used: Dictionary = {}
	var pts: Array = _strike_pts(targets)
	for e: Array in pts:
		var tp: Vector2 = e[0]
		var n: int = int(e[1])
		out["total"] = int(out["total"]) + n
		var got: int = 0
		for i in n:
			if int(out["assigned"]) >= avail:
				break
			var best: Facility = null
			var bd: float = INF
			for f: Facility in free:
				if used.has(f):
					continue
				var d: float = f.center_px().distance_to(tp)
				if d < bd:
					bd = d
					best = f
			if best == null:
				break
			used[best] = true
			(out["plan"] as Array).append([best, tp])
			got += 1
			out["assigned"] = int(out["assigned"]) + 1
		var why: String = ""
		if got < n:
			why = Loc.t("Не хватает боеготовых ОТРК «Искандер-М»")
		(out["per_target"] as Array).append({"ok": got == n, "reason": why, "n": n, "got": got, "pos": tp})
	out["tels"] = used.size()
	out["ok"] = int(out["assigned"]) > 0
	if int(out["assigned"]) == 0 and not targets.is_empty():
		out["why"] = Loc.t("Нет готовых ОТРК «Искандер-М»")
	return out


static func _thermo_plan(gw: GameWorld, p: Country, targets: Array) -> Dictionary:
	var out: Dictionary = {"ok": false, "total": 0, "available": 0, "assigned": 0, "per_target": [], "plan": [], "why": ""}
	if p == null or gw == null:
		return out
	var free: Array[Facility] = []
	if gw.mil != null:
		for f: Facility in gw.mil.facilities:
			if f != null and is_instance_valid(f) and f.country_id == p.id and (f.army_build == "thermo_battery" or bool(f.get_meta("is_thermo", false))) and f.hp > 0.0:
				if int(f.get_meta("state", 0)) == 0:
					free.append(f)
	var max_by_res: int = mini(p.money / 500, p.metal / 6) if (p.money >= 0 and p.metal >= 0) else 0
	var avail: int = mini(free.size(), max_by_res)
	out["available"] = avail
	var used: Dictionary = {}
	var pts: Array = _strike_pts(targets)
	for e: Array in pts:
		var tp: Vector2 = e[0]
		var n: int = int(e[1])
		out["total"] = int(out["total"]) + n
		var got: int = 0
		for i in n:
			if int(out["assigned"]) >= avail:
				break
			var best: Facility = null
			var bd: float = INF
			for f: Facility in free:
				if used.has(f):
					continue
				var d: float = f.center_px().distance_to(tp)
				if d >= 90.0 and d <= 640.0:
					if d < bd:
						bd = d
						best = f
			if best == null:
				break
			used[best] = true
			(out["plan"] as Array).append([best, tp])
			got += 1
			out["assigned"] = int(out["assigned"]) + 1
		var why: String = ""
		if got < n:
			if free.is_empty():
				why = Loc.t("Нет готовых батарей «Солнцепёк»")
			elif max_by_res < free.size() and int(out["assigned"]) >= max_by_res:
				why = Loc.t("Не хватает ресурсов на залп: 500 $ и 6 металла")
			else:
				why = Loc.t("Цель вне зоны досягаемости (90–640)")
		(out["per_target"] as Array).append({"ok": got == n, "reason": why, "n": n, "got": got, "pos": tp})
	out["ok"] = int(out["assigned"]) > 0
	if int(out["assigned"]) == 0 and not targets.is_empty():
		if free.is_empty():
			out["why"] = Loc.t("Нет готовых батарей «Солнцепёк»")
		elif max_by_res == 0:
			out["why"] = Loc.t("Не хватает ресурсов: нужно 500 $ и 6 металла на залп")
		else:
			out["why"] = Loc.t("Цели вне досягаемости батарей «Солнцепёк» (90–640)")
	return out


static func _nuke_plan(gw: GameWorld, p: Country, targets: Array) -> Dictionary:
	var out: Dictionary = {"ok": false, "total": 0, "available": 0, "assigned": 0, "per_target": [], "plan": [], "why": ""}
	if p == null or gw == null:
		return out
	var free: Array[Facility] = []
	if gw.mil != null:
		for f: Facility in gw.mil.facilities:
			if f != null and is_instance_valid(f) and f.country_id == p.id and (f.army_build == "nuclear_silo" or bool(f.get_meta("is_nuclear_silo", false))) and f.hp > 0.0:
				if bool(f.get_meta("has_warhead", false)):
					free.append(f)
	var avail: int = free.size()
	out["available"] = avail
	var used: Dictionary = {}
	var pts: Array = _strike_pts(targets)
	for e: Array in pts:
		var tp: Vector2 = e[0]
		var n: int = int(e[1])
		out["total"] = int(out["total"]) + n
		var got: int = 0
		for i in n:
			var best: Facility = null
			var bd: float = INF
			for f: Facility in free:
				if used.has(f):
					continue
				var d: float = f.center_px().distance_to(tp)
				if d < bd:
					bd = d
					best = f
			if best == null:
				break
			used[best] = true
			(out["plan"] as Array).append([best, tp])
			got += 1
			out["assigned"] = int(out["assigned"]) + 1
		var why: String = ""
		if got < n:
			why = Loc.t("Не хватает снаряжённых МБР «Сармат»")
		(out["per_target"] as Array).append({"ok": got == n, "reason": why, "n": n, "got": got, "pos": tp})
	out["ok"] = int(out["assigned"]) > 0
	if int(out["assigned"]) == 0 and not targets.is_empty():
		out["why"] = Loc.t("Нет снаряжённых шахт МБР «Сармат»")
	return out


static func eta(gw: GameWorld, wid: String, mp: Dictionary) -> float:
	var sum: float = 0.0
	var n: int = 0
	match wid:
		"drone", "jet":
			var k: int = 0
			for pt: Dictionary in mp.get("per_target", []):
				var got: int = int(pt.get("launch", 0))
				for i in got:
					sum += float(pt.get("eta", 0.0)) + float(k) * DRONE_NEXT * 0.5
					k += 1
					n += 1
		"tel":
			var q: Dictionary = {}
			for e: Array in mp.get("plan", []):
				var f: Facility = e[0]
				var qi: int = int(q.get(f, 0))
				q[f] = qi + 1
				sum += Military.ERECT_TIME + Missile.IGNITE_TIME + Military.flight_time_for(f.center_px().distance_to(e[1])) + float(qi) * TEL_NEXT
				n += 1
		"iskander":
			var q_isk: Dictionary = {}
			for e_isk: Array in mp.get("plan", []):
				var f_isk: Facility = e_isk[0]
				var qi_isk: int = int(q_isk.get(f_isk, 0))
				q_isk[f_isk] = qi_isk + 1
				sum += clampf(f_isk.center_px().distance_to(e_isk[1]) / 380.0, 4.5, 9.0) + float(qi_isk) * 1.5
				n += 1
		"ship":
			var nv: Navy = gw.get("navy") as Navy
			var order: Dictionary = {}
			var per: Dictionary = {}
			for e2: Array in mp.get("plan", []):
				var s: Ship = nv.ship(int(e2[0])) if nv != null else null
				if s == null:
					continue
				if not order.has(s.id):
					order[s.id] = order.size()
				var k2: int = int(per.get(s.id, 0))
				per[s.id] = k2 + 1
				sum += float(order[s.id]) * Navy.CM_SHIP_GAP + float(k2) * Navy.CM_GAP + Navy.CM_RISE + Navy.CM_TURN + maxf(0.0, s.pos.distance_to(e2[1]) - Navy.CM_OUT) / Air.CR_SPEED
				n += 1
		"art":
			var nv2: Navy = gw.get("navy") as Navy
			for e4: Array in mp.get("plan", []):
				var s4: Ship = nv2.ship(int(e4[0])) if nv2 != null else null
				if s4 == null:
					continue
				sum += maxf(0.0, float(e4[2]) - gw.game_time) + float(NavyArt.SALVO) * NavyArt.RIPPLE * 0.5 + clampf(s4.pos.distance_to(e4[1]) / NavyArt.SHELL_V, 1.2, 4.5)
				n += 1
		"bomber", "hyper":
			var hyper: bool = wid == "hyper"
			for e3: Array in mp.get("plan", []):
				var a: Aircraft = e3[0]
				var p: Vector2 = e3[1]
				var k3: int = int(e3[2])
				var from: Vector2 = a.pos
				var t0: float = 0.0
				if bool(e3[3]):
					var d: float = a.pos.distance_to(p)
					var rr: float = (Air.HYPER_RANGE if hyper else Air.CR_RANGE) * Air.CR_FIRE_FRAC
					var fire: Vector2 = a.pos + (p - a.pos) / maxf(d, 1.0) * minf(d * 0.5, 260.0)
					if d > rr:
						fire = p + (a.pos - p) / d * rr
					t0 = AIR_TAKEOFF + a.pos.distance_to(fire) / float(Air.SPEC[a.type]["speed"])
					from = fire
				var fl: float = (Missile.IGNITE_TIME + 2.0 + from.distance_to(p) / 420.0) if hyper else from.distance_to(p) / Air.CR_SPEED
				for i in k3:
					sum += t0 + fl + (0.0 if hyper else float(i) * Air.CR_GAP)
					n += 1
		"thermo":
			for e5: Array in mp.get("plan", []):
				sum += 4.0
				n += 1
		"nuke":
			for e6: Array in mp.get("plan", []):
				var f6: Facility = e6[0]
				var d6: float = f6.center_px().distance_to(e6[1])
				sum += clampf(5.5 + d6 * 0.002, 6.5, 9.5)
				n += 1
	return sum / float(n) if n > 0 else 0.0



static func war_notes(gw: GameWorld, targets: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var me: int = gw.player.id if gw.player != null else 0
	for t: Dictionary in targets:
		var pp: Vector2 = t["pos"]
		var cx: int = floori(pp.x / GameWorld.CELL)
		var cy: int = floori(pp.y / GameWorld.CELL)
		var own: int = gw.data.get_owner_id(cx, cy) if gw.data.inside(cx, cy) else 0
		if own <= 0 or own == me or seen.has(own) or gw.diplo == null or gw.diplo.at_war(me, own):
			continue
		seen[own] = true
		var note: String = NavyStrike.war_note(gw, me, own)
		if note != "":
			out.append(note)
	return out






func fire(gw: GameWorld, all: Dictionary, arrive_together: bool) -> Dictionary:
	var res: Dictionary = {"now": {}, "later": {}, "eta": {}, "text": "", "failed": []}
	last_drones = []
	var etas: Dictionary = {}
	for w: String in active_w_ids(gw):
		var ts: Array = all.get(w, [])
		if ts.is_empty():
			continue
		var mp: Dictionary = plan(gw, w, ts)
		if int(mp.get("assigned", 0)) <= 0:
			(res["failed"] as Array).append(w)
			continue
		etas[w] = eta(gw, w, mp)
	res["eta"] = etas
	var t_max: float = 0.0
	for w2: String in etas:
		t_max = maxf(t_max, float(etas[w2]))
	var parts: PackedStringArray = []


	var multi: bool = etas.size() > 1
	var n_tg: int = 0
	for w4: String in etas:
		n_tg += (all[w4] as Array).size()
	if multi:
		gw.set_meta("strike_quiet", true)
	for w3: String in etas:
		var delay: float = (t_max - float(etas[w3])) if arrive_together else 0.0
		if delay < 1.0:
			var n: int = _launch_now(gw, w3, all[w3], float(etas[w3]))
			res["now"][w3] = n
			if n > 0:
				parts.append("%s %d" % [short(w3), n])
		else:
			pending.append({"gw": gw.get_instance_id(), "wd": gw.data.get_instance_id(), "at": gw.game_time + delay, "wid": w3, "targets": all[w3], "eta": float(etas[w3]), 
				"cid": _p(gw).id if _p(gw) != null else 0})
			res["later"][w3] = delay
			parts.append(Loc.t("%s через %d с") % [short(w3), int(round(delay))])
	if multi:
		gw.set_meta("strike_quiet", false)
	if not parts.is_empty():
		var head: String = Loc.t("УДАР: ")
		if multi:
			head = Loc.t("УДАР: %s, %s · ") % [Loc.n(etas.size(), "%d вид оружия", "%d вида оружия", "%d видов оружия") % etas.size(), Loc.n(n_tg, "%d цель", "%d цели", "%d целей") % n_tg]
		res["text"] = head + ", ".join(parts) + ((Loc.t(" · прилёт через %d с") % int(round(t_max))) if arrive_together and etas.size() > 1 else "")
	res["drones"] = last_drones.duplicate()
	return res



static func _ru(n: int, one: String, few: String, many: String) -> String:
	var m10: int = n % 10
	var m100: int = n % 100
	if m10 == 1 and m100 != 11:
		return one
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return few
	return many


func _launch_now(gw: GameWorld, wid: String, targets: Array, eta_s: float) -> int:
	var p: Country = _p(gw)
	if p == null or p.eliminated:
		return 0
	var n: int = 0
	match wid:
		"drone", "jet":
			var jet: bool = wid == "jet"
			if targets.size() == 1:
				var t: Dictionary = targets[0]
				var wps: Array[Vector2] = []
				wps.assign(t.get("wps", []))
				var ds: Array[Drone] = gw.mil.launch(p, wps, t["pos"], int(t["n"]), jet)
				last_drones = ds
				n = ds.size()
			else:
				n = int(gw.mil.launch_multi_ex(p, targets, jet)["launched"])
		"tel":
			n = int(gw.mil.launch_missiles_multi(p, targets)["launched"])
		"iskander":
			var isk_mod: Object = gw.get_meta("iskander_strike_mod", null)
			var mp_isk: Dictionary = plan(gw, "iskander", targets)
			if isk_mod != null and not (mp_isk.get("plan", []) as Array).is_empty():
				var ammo_type: String = String(gw.get_meta("iskander_strike_ammo", "he"))
				for e in mp_isk["plan"]:
					var f: Facility = e[0]
					var tp: Vector2 = e[1]
					if isk_mod.has_method("launch_missile_at"):
						if isk_mod.launch_missile_at(f, tp, ammo_type):
							n += 1
				if n > 0 and not bool(gw.get_meta("strike_quiet", false)):
					var ammo_title: String = "«ФУГАС»" if ammo_type == "he" else "«КАССЕТА»"
					gw.say(p, Loc.mk("ОТРК «Искандер-М»: произведён пуск %d ракет (%s) по целям!", [n, ammo_title]))
		"ship":
			var r: Dictionary = NavyStrike.launch(gw, p.id, targets)
			n = int(r.get("launched", 0))
			var wars: Array = r.get("wars", [])
			if n > 0 and not bool(gw.get_meta("strike_quiet", false)):
				gw.say(p, Loc.mk("Пуск КР с кораблей: %d (кораблей: %d)%s", [n, int(r["ships"]), (Loc.t(" · война: ") + ", ".join(PackedStringArray(wars))) if not wars.is_empty() else ""]))
		"art":
			n = _art_launch(gw, p, targets)
		"bomber", "hyper":
			n = int(gw.mil.air.multi_launch(p, targets, wid == "hyper")["launched"])
		"thermo":
			n = _thermo_launch(gw, p, targets)
		"nuke":
			n = _nuke_launch(gw, p, targets)
	if n > 0:
		log.append({"wid": wid, "t": gw.game_time, "n": n, "eta": eta_s})
	return n




func _art_launch(gw: GameWorld, p: Country, targets: Array) -> int:
	var plain: Array = []
	for t: Dictionary in targets:
		plain.append({"pos": t["pos"], "n": int(t["n"])})
	var r: Variant = gw.navy.art.strike(p.id, plain)
	if not (r is Dictionary):
		return 0
	var rd: Dictionary = r
	var n: int = int(rd.get("launched", 0))
	var wars: Array = rd.get("wars", [])
	if n > 0 and not bool(gw.get_meta("strike_quiet", false)):
		gw.say(p, Loc.t("Артудар с кораблей: %d залп. (%d снар., кораблей: %d)%s") % [n, int(rd.get("shells", 0)), int(rd.get("ships", 0)), 
			(Loc.t(" · война: %s") % [", ".join(PackedStringArray(wars))]) if not wars.is_empty() else ""])
	return n


func _thermo_launch(gw: GameWorld, p: Country, targets: Array) -> int:
	var mp: Dictionary = _thermo_plan(gw, p, targets)
	var tmod: Object = gw.get_meta("thermo_battery_mod", null)
	var launched: int = 0
	for e: Array in mp.get("plan", []):
		var f: Facility = e[0]
		var tp: Vector2 = e[1]
		if tmod != null and tmod.has_method("launch_salvo_at"):
			if tmod.launch_salvo_at(f, tp):
				launched += 1
	if launched > 0 and not bool(gw.get_meta("strike_quiet", false)):
		gw.say(p, Loc.mk("Батарея «Солнцепёк»: произведено залпов: %d", [launched]))
	return launched


func _nuke_launch(gw: GameWorld, p: Country, targets: Array) -> int:
	var mp: Dictionary = _nuke_plan(gw, p, targets)
	var nmod: Object = gw.get_meta("nuclear_strike_mod", null)
	var launched: int = 0
	for e: Array in mp.get("plan", []):
		var f: Facility = e[0]
		var tp: Vector2 = e[1]
		if nmod != null and nmod.has_method("launch_strike_from_silo"):
			if nmod.launch_strike_from_silo(f, tp):
				launched += 1
	if launched > 0 and not bool(gw.get_meta("strike_quiet", false)):
		gw.say(p, Loc.mk("РВСН: произведён запуск стратегических МБР: %d!", [launched]))
	return launched



func tick(gw: GameWorld) -> void :
	if _drop_n > 0 and gw != null and gw.player != null:
		if not gw.player.eliminated:
			gw.message.emit(Loc.msg(Loc.mk("Отложенные пуски отменены, ракеты возвращены")))
		_drop_n = 0
	if pending.is_empty() or gw == null:
		return
	var i: int = 0
	while i < pending.size():
		var e: Dictionary = pending[i]
		if _stale(e, gw):
			_drop_old(gw)
			continue
		if gw.game_time >= float(e["at"]):
			pending.remove_at(i)
			var who: Country = gw.country_by_id(int(e.get("cid", 0)))
			actor = who if who != null else null
			gw.set_meta("strike_quiet", true)
			var n: int = _launch_now(gw, String(e["wid"]), e["targets"], float(e["eta"]))
			gw.set_meta("strike_quiet", false)
			actor = null
			if n <= 0 and who != null and not who.eliminated:
				gw.say(who, Loc.mk("%s: синхронный пуск не состоялся — нет готовых средств", [title(String(e["wid"]))]))
		else:
			i += 1






func _stale(e: Dictionary, gw: GameWorld) -> bool:
	return int(e.get("gw", 0)) != gw.get_instance_id() or (gw.data != null and int(e.get("wd", 0)) != gw.data.get_instance_id())


func _drop_old(gw: GameWorld) -> void :
	var n: int = 0
	for k in range(pending.size() - 1, -1, -1):
		if _stale(pending[k], gw):
			pending.remove_at(k)
			n += 1
	_drop_n += n



func pending_marks(gw: GameWorld, cid: int = -1) -> Array:
	var out: Array = []
	for e: Dictionary in pending:
		if int(e.get("gw", 0)) != gw.get_instance_id() or (cid >= 0 and int(e.get("cid", 0)) != cid):
			continue
		out.append([String(e["wid"]), e["targets"], maxf(0.0, float(e["at"]) - gw.game_time)])
	return out
