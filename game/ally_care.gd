extends RefCounted











const CARE_DT: float = 6.0
const PAIR_GAP: Dictionary = {"war": 120.0, "city": 200.0, "food": 120.0, "res": 180.0, "money": 240.0}
const TAKER_GAP: float = 15.0
const NOTE_GAP: float = 360.0
const NOTE_WIN: float = 600.0
const NOTE_MAX: int = 3
const OWED_HALF: float = 900.0
const NEED_HOLD: float = 10.0
const FOOD_LOW: int = 12
const RES_LOW: int = 8
const MONEY_LOW: int = 400
const CITY_T: float = 240.0
const TREACH_T: float = 900.0
const NEEDS: Array[String] = ["war", "city", "food", "res", "money"]


const LINES: Dictionary = {
	"war": {"trader": ["Держитесь. Шлём всё, что можем", "Торговля подождёт — сначала вы"], 
		"militarist": ["Ваш враг — наш враг", "Держите строй, помощь в пути"], 
		"cautious": ["Мы с вами. Берегите людей", "Поможем, чем сможем"], 
		"adventurer": ["Не сдавайтесь, мы рядом", "Ещё повоюем вместе"]}, 
	"city": {"trader": ["Скорбим вместе с вами: %s", "%s — тяжёлая потеря. Поможем отстроиться"], 
		"militarist": ["Город %s ещё вернётся под ваш флаг", "За город %s враг ответит"], 
		"cautious": ["Сочувствуем: %s. Держитесь", "Скорбим вместе с вами: %s"], 
		"adventurer": ["%s — это не конец", "Город %s ещё будет вашим"]}, 
	"capital": {"_": ["Пала столица — %s. Мы с вами", "Ваша столица пала, но страна жива. Держитесь"]}, 
	"food": {"_": ["Голод не должен решать войну — шлём еду", "Поделимся припасами", "Не оставим вас без хлеба"]}, 
	"res": {"_": ["Поделимся сырьём", "Возьмите из наших запасов"]}, 
	"money": {"_": ["Вот средства на первое время", "Казна пуста? Поможем"]}, 
	"join": {"trader": ["Не хотели войны, но вас не бросим"], "militarist": ["Плечом к плечу!", "Ваш враг — наш враг"], 
		"cautious": ["Договор есть договор: мы с вами"], "adventurer": ["Вместе веселее. Мы в деле"]}, 
	"skip_off": {"_": ["В нападение не пойдём (цель — %s). Защищать вас будем всегда", "Оборона — да, авантюры — нет. Цель %s не наша"]}, 
	"repay": {"_": ["Вы помогли нам — теперь наш черёд", "Мы помним вашу помощь"]}, 
	"thanks": {"_": ["Спасибо. Не забудем", "Мы ваши должники"]}, 
}

var dp
var gw: GameWorld
var owed: Dictionary = {}
var joined_for: Dictionary = {}
var treach: Dictionary = {}
var lost_t: Dictionary = {}
var _next: Dictionary = {}
var _taker_t: Dictionary = {}
var _need_t: Dictionary = {}
var _note_from: Dictionary = {}
var _note_times: Array = []
var _skip_log: Dictionary = {}
var _caps: Dictionary = {}
var _t: float = 0.0
var _decay_t: float = 0.0
var counters: Dictionary = {}


func _init(d) -> void :
	dp = d
	gw = d.gw
	if not gw.city_captured.is_connected(_on_capture):
		gw.city_captured.connect(_on_capture)
	for c: Country in gw.countries:
		_caps[c.id] = c.capital_id


func reset() -> void :
	owed.clear()
	joined_for.clear()
	treach.clear()
	lost_t.clear()
	_next.clear()
	_taker_t.clear()
	_need_t.clear()
	_note_from.clear()
	_note_times.clear()
	_caps.clear()
	for c: Country in gw.countries:
		_caps[c.id] = c.capital_id


func _count(k: String, n: int = 1) -> void :
	counters[k] = int(counters.get(k, 0)) + n


func _pid(c: Country) -> String:
	if gw.ai == null or c == null:
		return ""
	return String(gw.ai.persona_of(c).get("id", ""))



func line(c: Country, kind: String, arg: String = "") -> String:
	var tab: Dictionary = LINES.get(kind, {})
	var arr: Array = tab.get(_pid(c), tab.get("_", []))
	if arr.is_empty():
		for v: Variant in tab.values():
			arr = v
			break
	if arr.is_empty():
		return ""
	var s: String = String(arr[Hash32.h2(c.id, int(gw.game_time / 60.0), kind.length()) % arr.size()])
	return s % arg if s.contains("%s") else s



func note(c: Country, kind: String, arg: String = "", tail: String = "", to: int = -1) -> bool:
	var now: float = gw.game_time
	if now - float(_note_from.get(c.id, -1000000000.0)) < NOTE_GAP:
		_count("note_skip")
		return false
	while not _note_times.is_empty() and now - float(_note_times[0]) > NOTE_WIN:
		_note_times.pop_front()
	if _note_times.size() >= NOTE_MAX:
		_count("note_skip")
		return false
	var ln: String = line(c, kind, arg)
	if ln == "":
		return false
	_note_from[c.id] = now
	_note_times.append(now)
	_count("notes")
	_count("note_" + kind)
	var msg: String = "%s: «%s»%s" % [c.name, ln, (" — " + tail) if tail != "" else ""]
	if to >= 0:
		gw.say(to, msg)
	else:
		gw.message.emit(msg)
	return true




func on_help(from: int, to: int, value: int) -> void :
	if value <= 0:
		return
	var k: String = "%d>%d" % [to, from]
	owed[k] = float(owed.get(k, 0.0)) + float(value)
	var ct: Country = gw.country_by_id(to)
	var cf: Country = gw.country_by_id(from)

	if cf != null and ct != null and cf.is_player and not ct.is_player and value >= 1000:
		note(ct, "thanks", "", "", from)



func on_join(who: int, enemy: int, side: int) -> bool:
	joined_for["%d>%d" % [who, enemy]] = side
	owed["%d>%d" % [side, who]] = float(owed.get("%d>%d" % [side, who], 0.0)) + 1500.0
	var cw: Country = gw.country_by_id(who)
	var cs: Country = gw.country_by_id(side)
	if cw != null and cs != null and cs.is_player and not cw.is_player:
		return note(cw, "join", "", Loc.t("вступает в войну с %s на вашей стороне") % dp._cname(enemy), side)
	return false



func defending(c: int) -> bool:
	var pre: String = "%d>" % c
	for k: String in joined_for.keys():
		if k.begins_with(pre) and dp.at_war(c, int(k.substr(pre.length()))):
			return true
	return false


func on_treachery(a: int) -> void :
	treach[a] = gw.game_time


func traitor(id: int) -> bool:
	return gw.game_time - float(treach.get(id, -1000000000.0)) < TREACH_T


func _on_capture(city: City, old: int) -> void :
	var co: Country = gw.country_by_id(old)
	if co == null or city == null:
		return
	var cap: bool = int(_caps.get(old, -1)) == city.id
	lost_t[old] = [gw.game_time, city.name, cap, {}]
	_caps[old] = co.capital_id





func need_of(x: Country, own_only: bool = false) -> Array:
	if x == null or x.eliminated or x.capital_id < 0:
		return []
	var best: Array = []
	var bs: float = 0.0
	for e: int in x.at_war.keys():
		if not dp._alive(e):
			continue
		if not (dp._defender(x.id, e) or (joined_for.has("%d>%d" % [x.id, e]) and not own_only)):
			continue
		var r: float = dp.war_power(e) / maxf(1.0, dp.war_power(x.id))
		var sv: float = clampf(r - 0.6, 0.0, 1.5)
		if r > 0.8 and sv > bs:
			bs = sv
			best = ["war", sv, e]
	var lt: Array = lost_t.get(x.id, [])
	if not lt.is_empty() and gw.game_time - float(lt[0]) < CITY_T:
		var sv2: float = 1.3 if bool(lt[2]) else 0.7
		if sv2 > bs:
			bs = sv2
			best = ["city", sv2, String(lt[1])]
	if x.food < FOOD_LOW and x.money < 4000 and 0.8 > bs:
		bs = 0.8
		best = ["food", 0.8, "food"]
	for res: String in ["fuel", "metal"]:
		if int(x.get(res)) < RES_LOW and x.money < 2500 and 0.4 > bs and (gw.econ == null or gw.econ.need(x, res) > 0 or gw.econ.scarce_of(x).has(res)):
			bs = 0.4
			best = ["res", 0.4, res]
	if x.money < MONEY_LOW and x.city_ids.size() <= 3 and 0.35 > bs:
		bs = 0.35
		best = ["money", 0.35, ""]
	return best



func bond(c: Country, x: Country) -> float:
	if c.id == x.id or dp.at_war(c.id, x.id):
		return 0.0
	var b: float = 0.0
	if dp.allied(c.id, x.id):
		b = 1.0
	elif dp.subject_of(x.id) == c.id:
		b = 0.9
	elif dp.subject_of(c.id) == x.id:
		b = 0.5
	elif dp.has_treaty(c.id, x.id, "defense") and dp.relation(c.id, x.id) >= 40:
		b = 0.6
	var got: float = float(owed.get("%d>%d" % [c.id, x.id], 0.0))
	if b == 0.0 and got >= 800.0 and dp.relation(c.id, x.id) >= 30:
		b = 0.35
	if b == 0.0 and dp.gw.get("drama") != null:
		b = clampf(0.6 * float(dp.gw.drama.bias(c, "aid", x.id)), 0.0, 0.45)
	return b



func spare(c: Country) -> int:
	var reserve: int = 800 if not c.at_war.is_empty() else 600
	return maxi(0, c.money - reserve)




func update(dt: float) -> void :
	_t += dt
	_decay_t += dt
	if _decay_t >= 60.0:
		var f: float = pow(0.5, _decay_t / OWED_HALF)
		_decay_t = 0.0
		for k: String in owed.keys():
			owed[k] = float(owed[k]) * f
			if float(owed[k]) < 50.0:
				owed.erase(k)
	if _t < CARE_DT:
		return
	_t = 0.0
	var now: float = gw.game_time
	for k: String in joined_for.keys():
		var ab: PackedStringArray = k.split(">")
		if not dp.at_war(int(ab[0]), int(ab[1])):
			joined_for.erase(k)
	var needy: Array = []
	for x: Country in gw.countries:
		_caps[x.id] = x.capital_id
		var nd: Array = need_of(x)
		for kind: String in NEEDS:
			var nk: String = "%d:%s" % [x.id, kind]
			if nd.is_empty() or String(nd[0]) != kind:
				_need_t.erase(nk)
			elif not _need_t.has(nk):
				_need_t[nk] = now
		if not nd.is_empty() and now - float(_need_t.get("%d:%s" % [x.id, String(nd[0])], now)) >= NEED_HOLD and now - float(_taker_t.get(x.id, -1000000000.0)) >= TAKER_GAP:
			needy.append([x, nd])
	for it: Array in needy:
		var x: Country = it[0]
		var nd: Array = it[1]
		var best_c: Country = null
		var best_w: float = 0.0
		for c: Country in gw.countries:
			if c.is_player or c.eliminated or c.capital_id < 0 or c.id == x.id:
				continue
			var b: float = bond(c, x)
			if b <= 0.0 or now < float(_next.get("%d>%d:%s" % [c.id, x.id, String(nd[0])], 0.0)):
				continue
			if String(nd[0]) == "city" and ((lost_t.get(x.id, [0, "", false, {}]) as Array)[3] as Dictionary).has(c.id):
				continue
			var own: Array = need_of(c, true)
			if not own.is_empty() and (String(own[0]) == "war" or String(own[0]) == "city") and float(own[1]) >= 0.5:
				var lk: String = "%d>%d" % [c.id, x.id]
				if now - float(_skip_log.get(lk, -1000000000.0)) >= 120.0:
					_skip_log[lk] = now
					dp.dlog(c.id, "не помогает %s" % x.name, "сам в беде (%s, сила нужды %.1f)" % [String(own[0]), float(own[1])])
				continue
			var w: float = willing(c, x, b)
			if w > best_w:
				best_w = w
				best_c = c
		if best_c == null or best_w < 0.25:
			continue
		_help(best_c, x, nd, best_w)



func willing(c: Country, x: Country, b: float) -> float:
	var P: Dictionary = dp._p(c.id)
	var rel: float = float(dp.relation(c.id, x.id)) / 100.0
	var recip: float = clampf(float(owed.get("%d>%d" % [c.id, x.id], 0.0)) / 2500.0, 0.0, 0.8)
	return b * (0.55 + rel * 0.5 + recip) * (0.75 + float(P["trade"]) * 0.25 + float(P["caution"]) * 0.15)


func _help(c: Country, x: Country, nd: Array, w: float) -> void :
	var kind: String = String(nd[0])
	var sv: float = float(nd[1])
	var now: float = gw.game_time
	var sent: Array = []
	var value: int = 0
	var sp: int = spare(c)
	match kind:
		"war":
			value = dp.send_package(c.id, x.id, int(nd[2]), clampf(w * (0.6 + sv * 0.5), 0.4, 2.0), true)
		"city":
			var n: int = clampi(int(float(sp) * 0.18 * w * sv / 100.0) * 100, 0, 3000)
			if n >= 200:
				value += dp._move(c.id, x.id, "money", n)
				sent.append(Loc.t("деньги %d") % n)
			if c.food >= 50 and x.food < 60:
				var f: int = dp._move(c.id, x.id, "food", mini(20, c.food - 40))
				if f > 0:
					value += dp.aid_value("food", f)
					sent.append(Loc.t("еда ×%d") % f)
		"food", "res":
			var res: String = String(nd[2])
			var have: int = int(c.get(res))
			var keep: int = 30 if res == "food" else 20
			if have > keep + 5:
				var r: int = dp._move(c.id, x.id, res, clampi(roundi(float(have - keep) * 0.5 * w), 5, 30))
				if r > 0:
					value += dp.aid_value(res, r)
					sent.append("%s ×%d" % [String(Economy.RES_NAMES.get(res, res)).to_lower(), r])
			if value <= 0 and sp >= 600:
				var m: int = clampi(int(float(sp) * 0.1 * w / 100.0) * 100, 200, 1200)
				value += dp._move(c.id, x.id, "money", m)
				sent.append(Loc.t("деньги %d на закупку") % m)
		"money":
			var n2: int = clampi(int(float(sp) * 0.12 * w / 100.0) * 100, 0, 1500)
			if n2 >= 200:
				value += dp._move(c.id, x.id, "money", n2)
				sent.append(Loc.t("деньги %d") % n2)
	var gap: float = float(PAIR_GAP.get(kind, 180.0)) * clampf(1.5 - 0.5 * w, 0.6, 1.5)
	_next["%d>%d:%s" % [c.id, x.id, kind]] = now + gap
	if value <= 0:
		_next["%d>%d:%s" % [c.id, x.id, kind]] = now + 30.0
		dp.dlog(c.id, "сочувствует %s" % x.name, "%s, но нечего дать" % kind, w)
		if kind == "city" and x.is_player:
			note(c, "capital" if bool((lost_t.get(x.id, [0, "", false]) as Array)[2]) else "city", String(nd[2]), "", x.id)
		return
	_taker_t[x.id] = now
	if kind == "city" and lost_t.has(x.id):
		((lost_t[x.id] as Array)[3] as Dictionary)[c.id] = true
	_count("care_" + kind)
	_count("care_value", value)
	var what: String = ", ".join(PackedStringArray(sent))
	if kind != "war":
		dp._note_help(c.id, x.id, value)
		dp._count("aid_packages")
		gw.news_m(Loc.mk("ПОМОЩЬ: %s → %s (%s)", [Loc.name(dp._name(c.id)), Loc.name(dp._name(x.id)), what]), "grass_light")
		gw.relations_changed.emit()
	else:
		what = String(dp.last_package)
	dp.add_opinion(c.id, x.id, 2)
	dp.dlog(c.id, "помогает %s сам" % x.name, "%s (сила нужды %.1f): %s" % [kind, sv, what], w)
	if x.is_player:
		var lk: String = kind
		if kind == "city" and bool((lost_t.get(x.id, [0, "", false]) as Array)[2]):
			lk = "capital"
		if float(owed.get("%d>%d" % [c.id, x.id], 0.0)) >= 1500.0 and Hash32.h2(c.id, int(now), 7) % 2 == 0:
			lk = "repay"
		var arg: String = String(nd[2]) if kind == "city" else ""
		note(c, lk, arg, what, x.id)




func save_state() -> Dictionary:
	var lt: Dictionary = {}
	for k: Variant in lost_t.keys():
		var a: Array = lost_t[k]
		lt[k] = [float(a[0]), String(a[1]), bool(a[2])]
	return {"owed": owed.duplicate(), "joined_for": joined_for.duplicate(), "treach": treach.duplicate(), "lost_t": lt, 
		"next": _next.duplicate(), "note_from": _note_from.duplicate()}


func load_state(d: Dictionary) -> void :
	reset()
	for k: Variant in (d.get("owed", {}) as Dictionary):
		owed[String(k)] = float(d["owed"][k])
	for k2: Variant in (d.get("joined_for", {}) as Dictionary):
		joined_for[String(k2)] = int(d["joined_for"][k2])
	for k3: Variant in (d.get("treach", {}) as Dictionary):
		treach[int(k3)] = float(d["treach"][k3])
	for k4: Variant in (d.get("lost_t", {}) as Dictionary):
		var a: Array = d["lost_t"][k4]
		if a.size() >= 3:
			lost_t[int(k4)] = [float(a[0]), String(a[1]), bool(a[2]), {}]
	for k5: Variant in (d.get("next", {}) as Dictionary):
		_next[String(k5)] = float(d["next"][k5])
	for k6: Variant in (d.get("note_from", {}) as Dictionary):
		_note_from[int(k6)] = float(d["note_from"][k6])
