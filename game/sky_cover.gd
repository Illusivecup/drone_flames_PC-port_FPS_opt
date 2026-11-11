extends RefCounted























const AdRelocateS = preload("res://game/ad_relocate.gd")
const AdTripS = preload("res://game/ad_trip.gd")

const K: int = 4096
const LIM_L: int = 4
const LIM_RADAR: int = 1
const LIM_EW: int = 1
const LIM_ALL: int = 8
const MAX_COVERS: int = 2
const UPKEEP: float = 0.02
const UNPAID_WARN: float = 60.0
const UNPAID_END: float = 180.0
const OFFER_T: float = 120.0
const DEPLOY_T: float = 20.0
const TICK: float = 2.0
const THINK: float = 12.0
const DOWN_CAP: int = 15
const DOWN_WIN: float = 600.0
const BOT_MONEY: int = 2000
const BOT_MAX_FAC: int = 2
const BOT_QUIET_END: float = 900.0
const BOT_PEACE_END: float = 120.0
const BOT_PAIR_GAP: float = 600.0
const BOT_HUMAN_GAP: float = 300.0
const BOT_FIRST: float = 480.0
const NOTE: String = "Враг союзника может сбивать ваши ПВО над ним — это не объявление войны вам"

var dp
var gw: GameWorld
var sky: Dictionary = {}
var fac: Dictionary = {}
var offers: Array = []
var next_id: int = 1
var build_for: int = 0
var _cov: Dictionary = {}
var _dead: Dictionary = {}
var _down: Dictionary = {}
var _offer_t: Dictionary = {}
var _human_t: Dictionary = {}
var _say_t: Dictionary = {}
var _t: float = 0.0
var _think: float = 0.0
var trip
static var stats: Dictionary = {}


func _init(d) -> void :
	dp = d
	gw = d.gw
	trip = AdTripS.new(self)


static func _note(k: String, n: int = 1) -> void :
	stats[k] = int(stats.get(k, 0)) + n


static func sky_kind(kind: int) -> bool:
	return Defense.is_ad(kind) or kind == Facility.Kind.AD_RADAR or kind == Facility.Kind.AD_EW


func _rebuild() -> void :
	_cov = {}
	for k: int in sky:
		var c: int = k / K
		if not _cov.has(c):
			_cov[c] = []
		(_cov[c] as Array).append(k % K)


func active(c: int, h: int) -> bool:
	return sky.has(c * K + h)


func covers(c: int, h: int) -> bool:
	return _cov.has(c) and (_cov[c] as Array).has(h)


func hosts_of(c: int) -> Array:
	return (_cov.get(c, []) as Array).duplicate()


func coverers_of(h: int) -> Array:
	var out: Array = []
	for k: int in sky:
		if k % K == h:
			out.append(k / K)
	out.sort()
	return out


func _cname(id: int) -> String:
	var c: Country = gw.country_by_id(id)
	return c.name if c != null else "?"


func _owner_at(p: Vector2) -> int:
	var x: int = floori(p.x / GameWorld.CELL)
	var y: int = floori(p.y / GameWorld.CELL)
	return gw.data.get_owner_id(x, y) if gw.data.inside(x, y) else 0


func _fac_owner(f: Facility) -> int:
	var hc: Vector2i = f.cell + f.size / 2
	return gw.data.get_owner_id(hc.x, hc.y) if gw.data.inside(hc.x, hc.y) else 0



func bond(c: int, h: int) -> bool:
	return dp.allied(c, h) or (dp.ally != null and dp.ally.same(c, h))



func pact(c: int, b: int) -> bool:
	return dp.allied(c, b) or dp.has_treaty(c, b, "nap") or dp.has_treaty(c, b, "defense")\
	or (dp.ally != null and dp.ally.same(c, b)) or dp.subject_of(c) == b or dp.subject_of(b) == c



func vs_ok(c: int, h: int, b: int) -> bool:
	if b <= 0 or b == c or b == h or not dp.at_war(h, b) or dp.at_war(c, b):
		return false
	var s: Dictionary = sky.get(c * K + h, {})
	if s.is_empty() or pact(c, b):
		return false
	return (s["vs"] as Array).has(b) or dp._defender(h, b)



func why_not(c: int, h: int) -> String:
	if c == h:
		return Loc.t("Это вы")
	if not dp._alive(c) or not dp._alive(h):
		return Loc.t("Страны нет")
	if dp.at_war(c, h):
		return Loc.t("Вы воюете")
	if dp.truce_on(c, h):
		return Loc.t("Перемирие — сначала мир")
	if not bond(c, h):
		return Loc.t("Только над союзником: СОЮЗ или ваш альянс")
	return ""



func can_start(c: int, h: int) -> String:
	var w: String = why_not(c, h)
	if w != "":
		return w
	if active(c, h):
		return Loc.t("Небо уже закрыто")
	if hosts_of(c).size() >= MAX_COVERS:
		return Loc.t("Вы уже прикрываете %d стран (максимум %d)") % [MAX_COVERS, MAX_COVERS]
	if coverers_of(h).size() >= MAX_COVERS:
		return Loc.t("Над страной %s уже %d прикрытия (максимум %d)") % [_cname(h), MAX_COVERS, MAX_COVERS]
	for o: Dictionary in offers:
		if int(o["c"]) == c and int(o["h"]) == h:
			return Loc.t("Ждём ответа")
	return ""



func host_refusal(h: int, c: int) -> String:
	if dp.get_opinion(h, c) < 0:
		return Loc.t("не доверяют вам (отношения %d)") % dp.get_opinion(h, c)
	return ""



func coverer_refusal(c: int, h: int) -> String:
	var cc: Country = gw.country_by_id(c)
	if cc == null:
		return Loc.t("страны нет")
	if dp.get_opinion(c, h) < 10:
		return Loc.t("мало доверия (отношения %d)") % dp.get_opinion(c, h)
	if cc.money < 2500:
		return Loc.t("нет денег на ПВО")
	if dp._losing_badly(c):
		return Loc.t("сами еле держатся")
	if _threat(c, h) <= 0:
		return Loc.t("вам сейчас не от кого прикрываться")
	return ""




func _threat(c: int, h: int) -> int:
	var ch: Country = gw.country_by_id(h)
	if ch == null:
		return 0
	var es: Array = ch.at_war.keys()
	es.sort()
	for e: int in es:
		if not dp._alive(e) or e == c or dp.at_war(c, e) or pact(c, e):
			continue
		if active(c, h) and not vs_ok(c, h, e):
			continue
		return e
	return 0






func offer(c: int, h: int) -> String:
	var w: String = can_start(c, h)
	if w != "":
		return w
	var ch: Country = gw.country_by_id(h)
	if ch.is_player:
		offers.append({"id": next_id, "c": c, "h": h, "ask": false, "until": gw.game_time + OFFER_T})
		next_id += 1
		_note("offers_human")
		gw.say(h, Loc.mk("%s предлагает закрыть небо над вами — ответ во «Входящих»", [Loc.name(_cname(c))]))
		dp.pending_changed.emit()
		return ""
	var r: String = host_refusal(h, c)
	if r != "":
		_note("offer_refused")
		gw.say(c, Loc.mk("%s отказывается от неба: %s", [Loc.name(_cname(h)), r]))
		return Loc.t("%s отказывается: %s") % [_cname(h), r]
	start(c, h, false)
	return ""



func ask(h: int, c: int) -> String:
	var w: String = can_start(c, h)
	if w != "":
		return w
	var cc: Country = gw.country_by_id(c)
	if cc.is_player:
		offers.append({"id": next_id, "c": c, "h": h, "ask": true, "until": gw.game_time + OFFER_T})
		next_id += 1
		_note("asks_human")
		gw.say(c, Loc.mk("%s просит закрыть небо над ними — ответ во «Входящих»", [Loc.name(_cname(h))]))
		dp.pending_changed.emit()
		return ""
	var r: String = coverer_refusal(c, h)
	if r != "":
		_note("ask_refused")
		gw.say(h, Loc.mk("%s не закроет небо: %s", [Loc.name(_cname(c)), r]))
		return Loc.t("%s отказывается: %s") % [_cname(c), r]
	start(c, h, true)
	return ""




func end_cmd(cid: int, other: int, over_them: bool) -> String:
	var c: int = cid if over_them else other
	var h: int = other if over_them else cid
	for i in range(offers.size() - 1, -1, -1):
		var o: Dictionary = offers[i]
		if int(o["c"]) == c and int(o["h"]) == h:
			offers.remove_at(i)
			dp.pending_changed.emit()
			return ""
	if not active(c, h):
		return Loc.t("Неба нет")
	end(c * K + h, Loc.t("небо открыто: %s") % _cname(cid))
	return ""



func take_home(cid: int, fid: int) -> String:
	var fl: Array = gw.mil.facilities
	var f: Facility = fl[fid] if fid >= 0 and fid < fl.size() else null
	if f == null or f.id != fid or gw.mil.is_demolished(f):
		return Loc.t("Нет такого объекта")
	if f.country_id != cid:
		return Loc.t("Это не ваше")
	if not AdRelocateS.movable(f.kind) or f.parent != null:
		return Loc.t("Увезти можно только ПВО")
	if f.moving or trip.trips.has(fid):
		return Loc.t("Уже едет домой") if trip.trips.has(fid) else Loc.t("Сейчас в пути")
	var o: int = _fac_owner(f)
	if o == cid:
		return Loc.t("Уже на вашей земле")
	fac.erase(fid)
	dp.ally_fac.erase(fid)
	_dead.erase(fid)
	var ok: bool = _home(f, Loc.t("увезено к себе"))
	_note("take_home")
	return "" if ok else Loc.t("Места дома нет: объект снят, деньги возвращены")




func start(c: int, h: int, req: bool) -> void :
	var k: int = c * K + h
	var ch: Country = gw.country_by_id(h)
	var vs: Array = ch.at_war.keys() if ch != null else []
	vs.sort()
	sky[k] = {"c": c, "h": h, "since": gw.game_time, "vs": vs, "req": req, "acc": 0.0, "unpaid": 0.0, "kills": 0, 
		"last_kill": gw.game_time, "quiet": -1.0}
	_rebuild()
	var n: int = 0
	for f: Facility in gw.mil.facilities:
		if f.country_id == c and f.parent == null and sky_kind(f.kind) and not f.moving and not fac.has(f.id)\
		and not gw.mil.is_demolished(f) and _fac_owner(f) == h:
			fac[f.id] = k
			dp.ally_fac.erase(f.id)
			n += 1
	dp._count("sky_on")
	_note("sky_on")
	dp.dlog(c, "закрывает небо над страной %s" % _cname(h), "по просьбе" if req else "по своему решению", 0.0, ["sky", h])
	gw.news_m(Loc.mk("%s ЗАКРЫВАЕТ НЕБО: НАД СТРАНОЙ %s", [Loc.name(_cname(c)).to_upper(), Loc.name(_cname(h)).to_upper()]), "intercept_cyan")
	gw.say2(c, h, Loc.t("НЕБО: %s прикрывает страну %s — её ПВО на этой земле сбивает врагов хозяина, войны с ними нет%s") % [_cname(c), _cname(h), 
		(Loc.t(" (уже там: %d)") % n) if n > 0 else ""])
	dp.pending_changed.emit()
	gw.relations_changed.emit()



func end(k: int, why: String) -> void :
	if not sky.has(k):
		return
	var c: int = k / K
	var h: int = k % K
	sky.erase(k)
	_rebuild()
	var ids: Array = []
	for fid: int in fac:
		if int(fac[fid]) == k:
			ids.append(fid)
	ids.sort()
	var moved: int = 0
	var back: int = 0
	var alive_c: bool = dp._alive(c)
	for fid2: int in ids:
		fac.erase(fid2)
		_dead.erase(fid2)
		var f: Facility = gw.mil.facilities[fid2]
		if not alive_c or f.country_id != c or gw.mil.is_demolished(f) or f.moving or _fac_owner(f) == c:
			continue
		if _home(f, Loc.t("небо над страной %s открыто") % _cname(h)):
			moved += 1
		else:
			back += 1
	dp._count("sky_off")
	_note("sky_off")
	_note("end: " + why.left(24))
	dp.dlog(c, "открывает небо над страной %s" % _cname(h), why, float(moved + back), ["sky_end", h])
	var tail: String = ""
	if moved + back > 0:
		tail = Loc.t(" · ПВО едет домой: %d%s") % [moved, (Loc.t(", снято с возвратом денег: %d") % back) if back > 0 else ""]
	gw.say2(c, h, Loc.mk("НЕБО над страной %s открыто (%s)%s", [Loc.name(_cname(h)), why, tail]))
	dp.pending_changed.emit()
	gw.relations_changed.emit()


func _home(f: Facility, why: String) -> bool:
	var ok: bool = trip.start(f, why)
	if ok and Defense.is_ad(f.kind):
		f.cd = maxf(f.cd, DEPLOY_T)
	dp._count("sky_home" if ok else "sky_home_refund")
	_note("home_moved" if ok else "home_refund")
	return ok





func site_ok(kind: int, owner: int, country: Country) -> bool:
	if country == null or owner <= 0 or not sky_kind(kind) or not covers(country.id, owner):
		return false
	return country.is_player or build_for == owner



func place_why(kind: int, nw: Vector2i, sz: Vector2i, country: Country) -> String:
	if country == null or not _cov.has(country.id) or not sky_kind(kind):
		return ""
	var cc: Vector2i = nw + sz / 2
	if not gw.data.inside(cc.x, cc.y):
		return ""
	var h: int = gw.data.get_owner_id(cc.x, cc.y)
	if h == country.id or h <= 0 or not covers(country.id, h):
		return ""
	var lim: Dictionary = limits(country.id, h)
	if Defense.is_ad(kind):
		if int(lim["launchers"][0]) >= LIM_L:
			return Loc.t("НЕБО: у вас там уже %d пусковых (максимум %d)") % [LIM_L, LIM_L]
		if int(lim["all"][0]) >= LIM_ALL:
			return Loc.t("НЕБО: над страной %s уже %d пусковых союзников (максимум %d)") % [_cname(h), LIM_ALL, LIM_ALL]
	elif kind == Facility.Kind.AD_RADAR and int(lim["radar"][0]) >= LIM_RADAR:
		return Loc.t("НЕБО: РЛС у вас там уже есть (максимум %d)") % LIM_RADAR
	elif kind == Facility.Kind.AD_EW and int(lim["ew"][0]) >= LIM_EW:
		return Loc.t("НЕБО: РЭБ у вас там уже есть (максимум %d)") % LIM_EW
	return ""



func limits(c: int, h: int) -> Dictionary:
	var nl: int = 0
	var nr: int = 0
	var ne: int = 0
	var na: int = 0
	for fid: int in fac:
		var k: int = int(fac[fid])
		if k % K != h:
			continue
		var f: Facility = gw.mil.facilities[fid]
		if Defense.is_ad(f.kind):
			na += 1
		if k / K != c:
			continue
		if Defense.is_ad(f.kind):
			nl += 1
		elif f.kind == Facility.Kind.AD_RADAR:
			nr += 1
		elif f.kind == Facility.Kind.AD_EW:
			ne += 1
	return {"launchers": [nl, LIM_L], "radar": [nr, LIM_RADAR], "ew": [ne, LIM_EW], "all": [na, LIM_ALL]}



func note_fac(f: Facility) -> void :
	if f == null or f.parent != null or not sky_kind(f.kind) or not _cov.has(f.country_id):
		return
	var h: int = _fac_owner(f)
	if h != f.country_id and covers(f.country_id, h):
		fac[f.id] = f.country_id * K + h
		dp.ally_fac.erase(f.id)
		_note("built")





func fire_host(a: int, b: int, gp: Vector2, t: Object) -> int:
	if not _cov.has(a):
		return 0
	var o: int = _owner_at(gp)
	if o <= 0:
		return 0
	if o == a:
		var dest: Vector2 = _dest(t)
		if not dest.is_finite():
			return 0
		o = _owner_at(dest)
		if o <= 0 or o == a:
			return 0
	if not (_cov[a] as Array).has(o):
		return 0
	return o if vs_ok(a, o, b) else 0


static func _dest(t: Object) -> Vector2:
	if t is Drone:
		return (t as Drone).target
	if t is Missile:
		return (t as Missile).target
	if t is Aircraft:
		var ac: Aircraft = t
		if ac.sortie > 0:
			return ac.sortie_target
		if ac.cas > 0:
			return ac.cas_p
		return ac.dest
	return Vector2.INF


static func _gp(t: Object) -> Vector2:
	if t is Missile:
		return (t as Missile).ground()
	if t is Drone:
		return (t as Drone).pos
	if t is Aircraft:
		return (t as Aircraft).pos
	return Vector2.INF



func on_down(by: int, e: int, t: Object, what: String) -> bool:
	if not _cov.has(by) or t == null:
		return false
	var gp: Vector2 = _gp(t)
	if not gp.is_finite():
		return false
	var h: int = fire_host(by, e, gp, t)
	if h <= 0:
		return false
	var s: Dictionary = sky[by * K + h]
	s["kills"] = int(s["kills"]) + 1
	s["last_kill"] = gw.game_time
	var dk: String = "%d>%d" % [e, by]
	var w: Array = _down.get(dk, [gw.game_time, 0])
	if gw.game_time - float(w[0]) >= DOWN_WIN:
		w = [gw.game_time, 0]
	if int(w[1]) < DOWN_CAP:
		dp.add_opinion(e, by, -1)
		w[1] = int(w[1]) + 1
	_down[dk] = w
	dp._count("sky_kills")
	_note("kills")
	if _owner_at(gp) == by:
		_note("kills_transit")
	var mk: int = by * K + e
	if gw.game_time >= float(_say_t.get(mk, -100.0)):
		_say_t[mk] = gw.game_time + 20.0
		gw.say2(by, e, Loc.t("НЕБО: ПВО (%s) сбила %s (%s) над %s — это не война") % [Loc.name(_cname(by)), what, Loc.name(_cname(e)), 
			(Loc.t("страной %s") % [Loc.name(_cname(h))]) if _owner_at(gp) == h else (Loc.t("своей землёй (летела к стране %s)") if t is Missile else Loc.t("своей землёй (летел к стране %s)")) % [Loc.name(_cname(h))]])
	return true




func target_host(e: int, f: Facility) -> int:
	if fac.is_empty() or f == null or not fac.has(f.id):
		return 0
	var k: int = int(fac[f.id])
	var h: int = k % K
	if not dp.at_war(e, h) or f.country_id != k / K or f.moving:
		return 0
	if _fac_owner(f) != h:
		return 0
	return h





func spot(c: int, h: int, kind: int) -> Vector2i:
	var cc: Country = gw.country_by_id(c)
	var ch: Country = gw.country_by_id(h)
	if cc == null or ch == null or ch.city_ids.is_empty():
		return Vector2i(-1, -1)
	var cities: Array = []
	for cid: int in ch.city_ids:
		var ct: City = gw.cities[cid]
		cities.append([ct.strike_t, - cid, cid])
	cities.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) > int(b[1])))
	var b0: int = build_for
	build_for = h
	var out: = Vector2i(-1, -1)
	var tried: int = 0
	for e: Array in cities.slice(0, 3):
		var ct2: City = gw.cities[int(e[2])]
		for r in range(maxi(4, ct2.radius / 2), ct2.radius + 31, 2):
			for q: Vector2i in AdRelocateS._ring(ct2.center, r):
				if not gw.data.inside(q.x, q.y) or gw.data.get_owner_id(q.x, q.y) != h:
					continue
				tried += 1
				if _near_enemy(h, q):
					continue
				if gw.mil.check_place(kind, Military.nw_for(kind, q), cc, null, false) == "":
					out = q
					break
				if tried > 900:
					break
			if out.x >= 0 or tried > 900:
				break
		if out.x >= 0 or tried > 900:
			break
	build_for = b0
	return out


func _near_enemy(h: int, q: Vector2i) -> bool:
	for dq: Vector2i in [Vector2i(6, 0), Vector2i(-6, 0), Vector2i(0, 6), Vector2i(0, -6)]:
		var p: Vector2i = q + dq
		if gw.data.inside(p.x, p.y):
			var o: int = gw.data.get_owner_id(p.x, p.y)
			if o > 0 and o != h and dp.at_war(h, o):
				return true
	return false



func info(me: int, other: int) -> Dictionary:
	var out: Dictionary = {"note": NOTE}
	for side: int in 2:
		var c: int = me if side == 0 else other
		var h: int = other if side == 0 else me
		var k: int = c * K + h
		var d: Dictionary = {"on": sky.has(k), "n": 0, "ids": [], "upkeep": 0, "since": 0.0, "kills": 0, "unpaid": 0.0, "req": false, 
			"pending": false, "id": "", "can": "" if sky.has(k) else can_start(c, h), "why_not": why_not(c, h)}
		for o: Dictionary in offers:
			if int(o["c"]) == c and int(o["h"]) == h:
				d["pending"] = true
				d["asked"] = bool(o["ask"])
				d["left"] = maxf(0.0, float(o["until"]) - gw.game_time)
				d["id"] = "h%d" % int(o["id"])
		if sky.has(k):
			var s: Dictionary = sky[k]
			d["since"] = float(s["since"])
			d["kills"] = int(s["kills"])
			d["unpaid"] = float(s["unpaid"])
			d["req"] = bool(s["req"])
			d["upkeep"] = upkeep_of(k)
			for fid: int in fac:
				if int(fac[fid]) == k:
					(d["ids"] as Array).append(fid)
			(d["ids"] as Array).sort()
			d["n"] = (d["ids"] as Array).size()
			d["limits"] = limits(c, h)
		out["over_them" if side == 0 else "over_me"] = d
	return out



func upkeep_of(k: int) -> int:
	var m: float = 0.0
	for fid: int in fac:
		if int(fac[fid]) == k:
			var f: Facility = gw.mil.facilities[fid]
			if gw.mil.alive(f):
				m += float(Military.cost_of(f.kind)) * UPKEEP
	return roundi(m)



func away(cid: int) -> Array:
	var out: Array = []
	for f: Facility in gw.mil.facilities:
		if f.country_id != cid or f.parent != null or not AdRelocateS.movable(f.kind) or (f.moving and not trip.trips.has(f.id)) or gw.mil.is_demolished(f):
			continue
		var o: int = _fac_owner(f)
		if o == cid:
			continue
		out.append({"fid": f.id, "kind": f.kind, "title": Military.title_of(f.kind), "host": o, "sky": fac.has(f.id), "alive": gw.mil.alive(f), 
			"trip": trip.phase(f.id)})
	return out




func pending(now: float) -> Array:
	var out: Array = []
	var p: Country = gw.player
	if p == null:
		return out
	for o: Dictionary in offers:
		var to: int = int(o["c"]) if bool(o["ask"]) else int(o["h"])
		if to != p.id:
			continue
		var text: String
		if bool(o["ask"]):
			text = Loc.t("%s просит закрыть небо над ними: ваше ПВО встанет на их земле и будет сбивать их врагов без войны с вами (они платят половину содержания)") % _cname(int(o["h"]))
		else:
			text = Loc.t("%s предлагает закрыть небо над вами: их ПВО встанет на вашей земле и будет сбивать ваших врагов") % _cname(int(o["c"]))
		out.append({"id": "h%d" % int(o["id"]), "from": int(o["h"]) if bool(o["ask"]) else int(o["c"]), "kind": "sky", "icon": "icon_ad_patriot", 
			"text": text, "deadline": float(o["until"]), "left": maxf(0.0, float(o["until"]) - now), "total": OFFER_T, 
			"options": [{"act": "accept", "label": Loc.t("ЗАКРЫТЬ НЕБО") if bool(o["ask"]) else Loc.t("ПРИНЯТЬ")}, {"act": "refuse", "label": Loc.t("ОТКАЗАТЬ")}]})
	return out


func item_to(n: int) -> int:
	for o: Dictionary in offers:
		if int(o["id"]) == n:
			return int(o["c"]) if bool(o["ask"]) else int(o["h"])
	return -1


func answer(n: int, act: String) -> String:
	for i in offers.size():
		var o: Dictionary = offers[i]
		if int(o["id"]) != n:
			continue
		offers.remove_at(i)
		var c: int = int(o["c"])
		var h: int = int(o["h"])
		var asker: int = h if bool(o["ask"]) else c
		var who: int = c if bool(o["ask"]) else h
		if act != "accept":
			_note("answer_no")
			gw.say(asker, Loc.mk("%s отказывается: небо над страной %s", [Loc.name(_cname(who)), Loc.name(_cname(h))]))
			return ""
		var w: String = can_start(c, h)
		if w != "":
			return Loc.t("Нельзя: %s") % [w]
		start(c, h, bool(o["ask"]))
		return ""
	return Loc.t("Нет такого")




func update(dt: float) -> void :
	_t += dt
	if _t < TICK:
		return
	var step: float = _t
	_t = 0.0
	var now: float = gw.game_time
	if not trip.trips.is_empty():
		trip.update(now)
	for i in range(offers.size() - 1, -1, -1):
		var o: Dictionary = offers[i]
		var c0: int = int(o["c"])
		var h0: int = int(o["h"])
		if now >= float(o["until"]) or why_not(c0, h0) != "":
			offers.remove_at(i)
			if now >= float(o["until"]):
				gw.say(h0 if bool(o["ask"]) else c0, Loc.mk("Нет ответа от страны %s: небо над страной %s", [Loc.name(_cname(c0 if bool(o["ask"]) else h0)), Loc.name(_cname(h0))]))
			dp.pending_changed.emit()
	if not sky.is_empty() or not fac.is_empty():
		_check(step, now)
	_think += step
	if _think >= THINK:
		_think = 0.0
		_bots(now)


func _check(step: float, now: float) -> void :
	var ks: Array = sky.keys()
	ks.sort()
	for k: int in ks:
		var s: Dictionary = sky[k]
		var c: int = k / K
		var h: int = k % K
		var why: String = ""
		if not dp._alive(c) or not dp._alive(h):
			why = Loc.t("страны нет")
		elif dp.at_war(c, h):
			why = Loc.t("война между ними")
		elif dp.truce_on(c, h):
			why = Loc.t("перемирие между ними")
		elif not bond(c, h):
			why = Loc.t("союз расторгнут")
		elif float(s["unpaid"]) >= UNPAID_END:
			why = Loc.t("нет денег на содержание")
		elif not gw.country_by_id(h).is_player and dp.get_opinion(h, c) < 0:
			why = Loc.t("%s больше не доверяет") % _cname(h)
		elif not gw.country_by_id(c).is_player:
			var thr: int = _threat(c, h)
			if thr > 0:
				s["quiet"] = -1.0
			elif float(s["quiet"]) < 0.0:
				s["quiet"] = now
			if float(s["quiet"]) >= 0.0 and now - float(s["quiet"]) >= BOT_PEACE_END:
				why = Loc.t("войны союзника закончились")
			elif now - float(s["last_kill"]) >= BOT_QUIET_END:
				why = Loc.t("небо спокойно")
		if why != "":
			end(k, why)

	var fids: Array = fac.keys()
	fids.sort()
	for fid: int in fids:
		if not fac.has(fid):
			continue
		var k2: int = int(fac[fid])
		var f: Facility = gw.mil.facilities[fid]
		if not sky.has(k2) or f.country_id != k2 / K or gw.mil.is_demolished(f):
			fac.erase(fid)
			_dead.erase(fid)
			continue
		if f.moving:
			continue
		var o: int = _fac_owner(f)
		if o == k2 / K:
			fac.erase(fid)
			_dead.erase(fid)
			continue
		if o != k2 % K:
			fac.erase(fid)
			_dead.erase(fid)
			_home(f, Loc.t("земля страны %s ушла к стране %s") % [_cname(k2 % K), _cname(o)] if o > 0 else Loc.t("земли страны %s там больше нет") % _cname(k2 % K))
			continue
		var al: bool = gw.mil.alive(f)
		if not al and not _dead.has(fid):
			_dead[fid] = true
			_lost(f, k2)
		elif al and _dead.has(fid):
			_dead.erase(fid)

	for k3: int in ks:
		if not sky.has(k3):
			continue
		var s3: Dictionary = sky[k3]
		var due: float = float(upkeep_of(k3)) * step / 60.0 + float(s3["acc"])
		var pay: int = int(due)
		s3["acc"] = due - float(pay)
		if pay <= 0:
			continue
		var cc: Country = gw.country_by_id(k3 / K)
		var ch: Country = gw.country_by_id(k3 % K)
		var hp: int = pay / 2 if bool(s3["req"]) else 0
		var cp: int = pay - hp
		if cc.money >= cp and ch.money >= hp:
			cc.money -= cp
			ch.money -= hp
			s3["unpaid"] = 0.0
		else:
			var u0: float = float(s3["unpaid"])
			s3["unpaid"] = u0 + step
			if u0 < UNPAID_WARN and u0 + step >= UNPAID_WARN:
				gw.say2(cc, ch, Loc.mk("НЕБО над страной %s: нет денег на содержание ПВО — через %d с небо откроется", [Loc.name(ch.name), int(UNPAID_END - UNPAID_WARN)]))



func _lost(f: Facility, k: int) -> void :
	var c: int = k / K
	var h: int = k % K
	var e: int = 0
	if gw.get("supply") != null and gw.supply != null:
		e = int(gw.supply.strike_by)
	if e > 0 and (e == c or e == h or not dp.at_war(e, h)):
		e = 0
	if e > 0 and not dp.at_war(c, e):
		dp.add_opinion(c, e, -2)
	dp._count("sky_lost")
	_note("lost")
	gw.say(c, Loc.mk("НЕБО: уничтожено — %s на земле страны %s%s; войны с вами нет", [Military.title_of(f.kind), Loc.name(_cname(h)), (Loc.t(" (удар: %s)") % Loc.name(_cname(e))) if e > 0 else ""]))



func _bots(now: float) -> void :
	for cc: Country in gw.countries:
		if cc.is_player or cc.eliminated or not dp._alive(cc.id):
			continue
		var c: int = cc.id
		for h: int in hosts_of(c):
			_bot_build(cc, h)
		if cc.money < BOT_MONEY or hosts_of(c).size() >= MAX_COVERS or dp._losing_badly(c):
			continue
		var P: Dictionary = dp._p(c)
		for ch: Country in gw.countries:
			var h2: int = ch.id
			if h2 == c or ch.eliminated or not bond(c, h2) or can_start(c, h2) != "":
				continue
			_note("c_bond")
			var e: int = _threat(c, h2)
			if e <= 0:
				continue
			_note("c_threat")
			if not dp._defender(h2, e) or dp.war_power(e) < dp.war_power(h2) * 0.8:
				continue
			_note("c_defend")
			if not _struck(ch, now) and not _strike_means(e):
				continue
			_note("c_struck")
			if Hash32.h2(c, h2, int(now / THINK)) % 1000 >= 350 + int(300.0 * float(P.get("caution", 0.5))):
				continue
			if ch.is_player:
				var pk: String = "%d>%d" % [c, h2]
				if now < BOT_FIRST or now - float(_offer_t.get(pk, -1000000000.0)) < BOT_PAIR_GAP or now - float(_human_t.get(h2, -1000000000.0)) < BOT_HUMAN_GAP:
					continue
				_offer_t[pk] = now
				_human_t[h2] = now
			dp.dlog(c, "предлагает небо %s" % _cname(h2), "враг %s бьёт по ним с воздуха" % _cname(e), 0.0, ["sky_offer", h2])
			offer(c, h2)
			break



func _strike_means(e: int) -> bool:
	var ce: Country = gw.country_by_id(e)
	if ce == null:
		return false
	if ce.missile_stock[Military.MT_BALLISTIC] + ce.missile_stock[Military.MT_CRUISE] > 0 or gw.mil.missiles_ready(e) > 0:
		return true
	for f: Facility in gw.mil.facilities:
		if f.country_id == e and (f.kind == Facility.Kind.DRONE_PORT or f.kind == Facility.Kind.AIRFIELD) and gw.mil.alive(f):
			return true
	return false


func _struck(ch: Country, now: float) -> bool:
	for cid: int in ch.city_ids:
		if float(gw.cities[cid].strike_t) > now - 300.0:
			return true
	return false


func _bot_build(cc: Country, h: int) -> void :
	var k: int = cc.id * K + h
	var n: int = 0
	for fid: int in fac:
		if int(fac[fid]) == k:
			n += 1
	if n >= BOT_MAX_FAC:
		return
	var kind: int = Facility.Kind.AD_SAM if n == 0 else Facility.Kind.AD_SPAAG
	if n > 0:
		var e: int = _threat(cc.id, h)
		var ce: Country = gw.country_by_id(e)
		if ce != null and (ce.missile_stock[Military.MT_BALLISTIC] > 0 or gw.mil.missiles_ready(e) > 0):
			kind = Facility.Kind.AD_PATRIOT
	if cc.money < Military.cost_of(kind) + 1000:
		kind = Facility.Kind.AD_SPAAG
		if cc.money < Military.cost_of(kind) + 1000:
			return
	var q: Vector2i = spot(cc.id, h, kind)
	if q.x < 0:
		_note("bot_no_spot")
		return
	build_for = h
	var f: Facility = null
	if gw.mil.check_place(kind, Military.nw_for(kind, q), cc, null, true) == "":
		f = gw.mil.build(kind, q, cc)
	build_for = 0
	if f != null:
		_note("bot_built")
		dp.dlog(cc.id, "ставит ПВО на земле %s" % _cname(h), Military.title_of(kind), 0.0, ["sky_build", h])




func hash_nums() -> PackedFloat64Array:
	var out: = PackedFloat64Array()
	out.append(float(sky.size()))
	var ks: Array = sky.keys()
	ks.sort()
	for k: int in ks:
		var n: int = 0
		for fid: int in fac:
			if int(fac[fid]) == k:
				n += 1
		out.append(float(k))
		out.append(float(n))
		out.append(float(int((sky[k] as Dictionary)["kills"])))
	out.append(float(fac.size()))
	out.append(float(offers.size()))
	trip.hash_nums(out)
	return out


func save() -> Dictionary:
	var s: Dictionary = {}
	for k: int in sky:
		s["%d>%d" % [k / K, k % K]] = (sky[k] as Dictionary).duplicate(true)
	var f: Dictionary = {}
	for fid: int in fac:
		f[str(fid)] = "%d>%d" % [int(fac[fid]) / K, int(fac[fid]) % K]
	return {"sky": s, "fac": f, "offers": offers.duplicate(true), "next": next_id, "dead": _dead.keys(), "down": _down.duplicate(true), 
		"offer_t": _offer_t.duplicate(), "human_t": _human_t.duplicate(), "t": _t, "think": _think, "trips": trip.save()}


func load_from(d: Dictionary) -> void :
	sky = {}
	for ks: Variant in (d.get("sky", {}) as Dictionary):
		var ab: PackedStringArray = String(ks).split(">")
		var e: Dictionary = d["sky"][ks]
		if ab.size() != 2:
			continue
		var c: int = int(ab[0])
		var h: int = int(ab[1])
		var vs: Array = []
		for v: Variant in (e.get("vs", []) as Array):
			vs.append(int(v))
		sky[c * K + h] = {"c": c, "h": h, "since": float(e.get("since", 0.0)), "vs": vs, "req": bool(e.get("req", false)), "acc": float(e.get("acc", 0.0)), 
			"unpaid": float(e.get("unpaid", 0.0)), "kills": int(e.get("kills", 0)), "last_kill": float(e.get("last_kill", 0.0)), "quiet": float(e.get("quiet", -1.0))}
	fac = {}
	var nf: int = gw.mil.facilities.size() if gw.mil != null else 0
	for kf: Variant in (d.get("fac", {}) as Dictionary):
		var ab2: PackedStringArray = String(d["fac"][kf]).split(">")
		var fid: int = int(kf)
		if ab2.size() == 2 and fid >= 0 and fid < nf:
			var k2: int = int(ab2[0]) * K + int(ab2[1])
			if sky.has(k2):
				fac[fid] = k2
	offers = []
	for o: Variant in (d.get("offers", []) as Array):
		var od: Dictionary = o
		offers.append({"id": int(od.get("id", 0)), "c": int(od.get("c", 0)), "h": int(od.get("h", 0)), "ask": bool(od.get("ask", false)), "until": float(od.get("until", 0.0))})
	next_id = int(d.get("next", 1))
	_dead = {}
	for x: Variant in (d.get("dead", []) as Array):
		_dead[int(x)] = true
	_down = {}
	for kd: Variant in (d.get("down", {}) as Dictionary):
		var w: Array = d["down"][kd]
		_down[String(kd)] = [float(w[0]), int(w[1])]
	_offer_t = {}
	for ko: Variant in (d.get("offer_t", {}) as Dictionary):
		_offer_t[String(ko)] = float(d["offer_t"][ko])
	_human_t = {}
	for kh: Variant in (d.get("human_t", {}) as Dictionary):
		_human_t[int(kh)] = float(d["human_t"][kh])
	_t = float(d.get("t", 0.0))
	_think = float(d.get("think", 0.0))
	trip.load_from(d.get("trips", {}) as Dictionary)
	_rebuild()
