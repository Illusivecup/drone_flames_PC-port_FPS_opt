extends RefCounted






const KINDS: Array[String] = ["war_on", "sky_over", "join_war", "sky_me", "station", "stop_war", "guard"]
const KIND_NAMES: Dictionary = {"war_on": "ОБЪЯВИТЬ ВОЙНУ", "sky_over": "ЗАКРЫТЬ НЕБО НАД СОЮЗНИКОМ", "join_war": "ВСТУПИТЬ В МОЮ ВОЙНУ", 
	"sky_me": "ЗАКРЫТЬ НЕБО НАДО МНОЙ", "station": "ПОСТАВИТЬ ВОЙСКА У МЕНЯ", "stop_war": "ПРЕКРАТИТЬ ВОЙНУ", "guard": "ПУСТИТЬ МОЮ АРМИЮ НА ЗАЩИТУ"}
const KIND_ICONS: Dictionary = {"war_on": "icon_dip_call", "sky_over": "icon_ad_patriot", "join_war": "icon_dip_call", "sky_me": "icon_ad_patriot", 
	"station": "icon_op_defend", "stop_war": "icon_treaty_embargo", "guard": "icon_op_defend"}
const NEEDS_X: Dictionary = {"war_on": true, "sky_over": true, "join_war": true, "sky_me": false, "station": false, "stop_war": true, "guard": true}
const COSTLY: Array[String] = ["war_on", "join_war", "sky_over", "sky_me", "station", "guard"]
const DEFENSIVE: Array[String] = ["join_war", "sky_over", "sky_me", "station", "guard"]

const NEED: Dictionary = {"war_on": 0.75, "sky_over": 0.55, "join_war": 0.65, "sky_me": 0.55, "station": 0.6, "stop_war": 0.35, "guard": 0.45}
const MOOD_NO: int = 12
const HUMAN_T: float = 120.0
const GRACE: float = 600.0
const CD_NO: float = 180.0
const CD_JOIN_NO: float = 120.0
const CD_YES: float = 600.0
const CD_HH: float = 120.0
const HUMAN_RATE_N: int = 3
const HUMAN_RATE_T: float = 120.0
const BOT_GAP: float = 300.0
const WAR_ON_BOT_GAP: float = 900.0
const WAR_ON_MAP_GAP: float = 600.0
const B2H_FIRST: float = 480.0
const B2H_GAP: float = 300.0
const B2H_N: int = 3
const B2H_WIN: float = 900.0
const STATION_T: float = 900.0
const GUARD_TAIL: float = 120.0
const TRIP_R: float = 300.0
const GAIN_CAP: int = 15
const GAIN_WIN: float = 600.0
const PRESS_MAX: int = 3
const PRESS_STEP_T: float = 180.0
const PRESS_LIFT_T: float = 120.0
const INCITE_T: float = 600.0
const TICK: float = 2.0
const AGS = preload("res://game/army_groups.gd")
const THINK: float = 12.0

var dp
var gw: GameWorld
var reqs: Array = []
var next_id: int = 1
var cd: Dictionary = {}
var pn: Dictionary = {}
var hist: Array = []
var sent: Dictionary = {}
var gain: Dictionary = {}
var station: Dictionary = {}
var press: Dictionary = {}
var press_done: Dictionary = {}
var incite: Dictionary = {}
var bot_next: Dictionary = {}
var war_on_t: Dictionary = {}
var war_on_map: float = 0.0
var b2h: Dictionary = {}
var hits: Dictionary = {}
var clash: Dictionary = {}
var anger_t: Dictionary = {}
var gp: Dictionary = {}
var gcount: Dictionary = {}
var counters: Dictionary = {}
var last_fail: String = ""
var lab_off: bool = false
var _t: float = 0.0
var _think: float = 0.0


func _init(d) -> void :
	dp = d
	gw = d.gw


func _n(k: String, v: int = 1) -> void :
	counters[k] = int(counters.get(k, 0)) + v


func _cn(id: int) -> String:
	return dp._cname(id)


static func kid(kind: String) -> int:
	return KINDS.find(kind)


func _alive(id: int) -> bool:
	return dp._alive(id)


func _human(id: int) -> bool:
	var c: Country = gw.country_by_id(id)
	return c != null and c.is_player





func standing(a: int) -> float:
	if gw.get("pstat") != null and gw.pstat.has_method("standing"):
		return clampf(float(gw.pstat.standing(a)), 0.0, 1.0)
	var alive: Array = []
	for c: Country in gw.countries:
		if _alive(c.id) and c.capital_id >= 0:
			alive.append(c.id)
	if alive.size() < 2:
		return 0.5
	var below: int = 0
	for o: int in alive:
		if o != a and dp.strength(o) < dp.strength(a):
			below += 1
	return float(below) / float(alive.size() - 1)



func rival(t: int, a: int) -> bool:
	if gw.get("pstat") != null and gw.pstat.has_method("rivals_of"):
		return (gw.pstat.rivals_of(a) as Array).has(t)
	return false



func drama(c: int, topic: String) -> float:
	for nm: String in ["world_drama", "drama"]:
		var o: Variant = gw.get(nm)
		if o != null and (o as Object).has_method("bias"):
			return clampf(float((o as Object).call("bias", gw.country_by_id(c), topic)), -0.5, 0.5)
	return 0.0


func _trd() -> Variant:
	return gw.econ.get("trd") if gw.econ != null else null





func gate(from: int, to: int, kind: String, x: int) -> String:
	if not KINDS.has(kind):
		return Loc.t("Нет такой просьбы")
	if from == to:
		return Loc.t("Это вы")
	if not _alive(from) or not _alive(to):
		return Loc.t("Страны нет")
	if bool(NEEDS_X[kind]) and (x <= 0 or not _alive(x)):
		return Loc.t("Выберите страну")
	if x > 0 and (x == from or x == to):
		return Loc.t("Нельзя: это %s") % (Loc.t("вы") if x == from else Loc.t("они сами"))
	if kind != "stop_war" and (dp.at_war(from, to) or dp.truce_on(from, to)):
		return Loc.t("Сначала заключите мир")
	if dp.is_subject(to) and dp.subject_of(to) != from and kind in ["war_on", "join_war", "station", "guard"]:
		return Loc.t("Внешнюю политику страны %s решает %s") % [_cn(to), _cn(dp.subject_of(to))]
	var now: float = gw.game_time
	var wars_on: bool = false
	for c: Country in gw.countries:
		if not c.at_war.is_empty():
			wars_on = true
			break
	if now < GRACE and not ((kind == "stop_war" or kind.begins_with("sky")) and wars_on) and not _human(from):
		return Loc.t("Рано: просьбы — после 10-й минуты")
	var ct: Country = gw.country_by_id(to)
	match kind:
		"war_on":
			if dp.at_war(from, x):
				return Loc.t("Вы уже воюете со страной %s — просите «вступить в мою войну»") % _cn(x)
			if dp.allied(from, x) or (dp.ally != null and dp.ally.same(from, x)) or dp.has_treaty(from, x, "defense") or dp.has_treaty(from, x, "nap") or dp.subject_of(x) == from:
				return Loc.t("%s — ваш союзник или партнёр по пакту") % _cn(x)
			if dp.at_war(to, x):
				return Loc.t("%s уже воюет со страной %s") % [_cn(to), _cn(x)]
			if not ct.at_war.is_empty():
				return Loc.t("%s уже воюет") % _cn(to)
			var jb: String = dp._join_block(to, x)
			if jb != "":
				return "%s: %s" % [_cn(to), jb]
			if not dp.war_allowed(to, x, false):
				return Loc.t("%s не может сейчас начать войну со страной %s") % [_cn(to), _cn(x)]
			var wb: String = dp.war_block_why(to, x)
			if wb != "":
				return "%s: %s" % [_cn(to), wb]
			if not ct.is_player and dp.has_method("pile_gate") and dp.pile_gate(to, x, from, true) != "":
				return Loc.t("%s: не сейчас — против %s уже воюют") % [_cn(to), _cn(x)]
		"join_war":
			if not dp.at_war(from, x):
				return Loc.t("Вы не воюете со страной %s") % _cn(x)
			if dp.at_war(to, x):
				return Loc.t("%s уже воюет со страной %s") % [_cn(to), _cn(x)]
			var jb2: String = dp._join_block(to, x)
			if jb2 != "":
				return "%s: %s" % [_cn(to), jb2]
			if ct.at_war.size() >= 2:
				return Loc.t("%s уже ведёт две войны") % _cn(to)
			var wb2: String = dp.war_block_why(to, x)
			if wb2 != "":
				return "%s: %s" % [_cn(to), wb2]
			if not ct.is_player and dp.has_method("pile_gate") and dp.pile_gate(to, x, from, true) != "":
				return Loc.t("%s: не сейчас — против %s уже воюют") % [_cn(to), _cn(x)]
		"sky_me":
			if not dp.has_method("sky_why"):
				return Loc.t("Небо пока недоступно")
			var sw: String = dp.sky_why(to, from)
			if sw != "":
				return sw
		"sky_over":
			if not dp.has_method("sky_why"):
				return Loc.t("Небо пока недоступно")
			var sw2: String = dp.sky_why(to, x)
			if sw2 != "":
				return "%s → %s: %s" % [_cn(to), _cn(x), sw2]
		"station":
			if station.has("%d>%d" % [to, from]):
				return Loc.t("Их войска уже вправе стоять у вас")
			if ct.at_war.size() >= 2:
				return Loc.t("%s ведёт две войны") % _cn(to)
			if not _human(to) and _free_army(to) == null:
				return Loc.t("%s: нет свободной армии") % _cn(to)
		"stop_war":
			if not dp.at_war(to, x):
				return Loc.t("%s не воюет со страной %s") % [_cn(to), _cn(x)]
			if dp.at_war(from, to):
				return Loc.t("Вы сами воюете со страной %s") % _cn(to)
			if dp.war_time(to, x) < 120.0:
				return Loc.t("Война только началась")
		"guard":
			if not dp.at_war(to, x):
				return Loc.t("%s не воюет со страной %s") % [_cn(to), _cn(x)]
			if dp.at_war(from, x):
				return Loc.t("Вы уже воюете со страной %s — просто отправьте армию") % _cn(x)
			if station.has("%d>%d" % [from, to]):
				return Loc.t("Разрешение уже есть — отправьте армию")
			if dp.allied(from, to) or (dp.ally != null and dp.ally.same(from, to)):
				return Loc.t("Союзнику разрешение не нужно — отправьте армию")
	return ""



func wait_left(from: int, to: int, kind: String) -> float:
	return maxf(0.0, float(cd.get("%d>%d>%d" % [from, to, kid(kind)], -1000000000.0)) - gw.game_time)


func _rec(a: int, t: int, win: float) -> int:
	var n: int = 0
	for h: Array in hist:
		if int(h[1]) == a and int(h[2]) == t and gw.game_time - float(h[0]) <= win:
			n += 1
	return n


func _busy(t: int) -> int:
	var n: int = 0
	for h: Array in hist:
		if int(h[2]) == t and int(h[4]) == 1 and gw.game_time - float(h[0]) <= 900.0 and COSTLY.has(KINDS[int(h[3])]):
			n += 1
	return n




func score(from: int, to: int, kind: String, x: int, n_override: int = -1) -> Dictionary:
	var P: Dictionary = dp._p(to)
	var aggr: float = float(P.get("aggr", 0.5))
	var caution: float = float(P.get("caution", 0.5))
	var trade: float = float(P.get("trade", 0.5))
	var rel: int = dp.relation(to, from)
	var parts: Array = []
	var s: float = 0.35 * float(rel) / 100.0
	parts.append([Loc.t("отношения %d") % rel, 0.35 * float(rel) / 100.0])
	var st: float = 0.15 * standing(from)
	s += st
	parts.append([Loc.t("ваш вес в мире"), st])

	var L: float = 0.0
	var leader: bool = false
	if DEFENSIVE.has(kind) and dp.ally != null:
		var a: Dictionary = dp.ally.of_country(to)
		if not a.is_empty() and int(a.get("founder", -1)) == from and (a["members"] as Array).has(from):
			L = 0.1
			leader = true
	if L == 0.0 and dp.allied(to, from) and kind != "war_on":
		L = 0.05
	s += L
	if L > 0.0:
		parts.append([Loc.t("глава альянса") if leader else Loc.t("союз"), L])
	if dp.care != null:
		var ow: float = 0.15 * minf(1.0, float(dp.care.owed.get("%d>%d" % [to, from], 0.0)) / 2000.0)
		if ow > 0.005:
			s += ow
			parts.append([Loc.t("вы помогали им"), ow])
	var pk: float = 0.0
	var ik: float = 0.0
	var ck: float = 0.0
	match kind:
		"war_on":
			pk = 0.3 * aggr - 0.3 * caution
			if not dp.coalition.is_empty() and int(dp.coalition["leader"]) == x:
				ik += 0.25
			if rival(to, x) or rival(x, to):
				ik += 0.2
			if dp.neighbours(to, x):
				ik += 0.15
			for e: int in (gw.country_by_id(x).at_war.keys() if gw.country_by_id(x) != null else []):
				if dp.allied(to, e):
					ik += 0.15
					break
			ck = 0.2 * float(dp.relation(to, x)) / 100.0
			var wp: float = dp.war_power(to) + 0.5 * dp.war_power(from)
			if wp < 1.1 * dp.war_power(x):
				ck += 0.4
				parts.append([Loc.t("%s сильнее") % _cn(x), -0.4])
			ik += drama(to, "war")
		"join_war":
			pk = 0.3 * aggr - 0.15 * caution
			ik = clampf(dp.join_interest(to, from, x), -0.6, 0.6)
			ik += drama(to, "war")
		"sky_me", "sky_over":
			pk = 0.25 * caution
			var h: int = from if kind == "sky_me" else x
			if dp._obligation(to, h, 0) != "":
				ik += 0.2
			ik += minf(0.3, 0.1 * float(_hits_n(h) / 3))
			var cc: Country = gw.country_by_id(to)
			if cc != null and cc.money < 3500:
				ck += 0.2
			var ch: Country = gw.country_by_id(h)
			for e2: int in (ch.at_war.keys() if ch != null else []):
				if dp.war_power(e2) > dp.war_power(to) * 1.5:
					ck += 0.15
					break
			ik += drama(to, "help")
		"station", "guard":
			pk = 0.2 * caution + 0.1 * aggr
			var host: int = from if kind == "station" else to
			var helper: int = to if kind == "station" else from
			if dp._obligation(helper, host, 0) != "" or dp.has_treaty(helper, host, "defense"):
				ik += 0.2
			var ch2: Country = gw.country_by_id(host)
			for e3: int in (ch2.at_war.keys() if ch2 != null else []):
				if dp.war_power(e3) > dp.war_power(host) * 1.3:
					ik += 0.15
					break
			if kind == "station":
				ck = 0.2 * _away_share(to)
			else:
				ik += 0.15
			ik += drama(to, "help")
		"stop_war":
			pk = 0.2 * trade - 0.2 * aggr
			var goal: Dictionary = dp.war_goals.get("%d>%d" % [to, x], {})
			if not goal.is_empty():
				var gc: Vector2i = goal["cell"]
				if gw.data.inside(gc.x, gc.y) and gw.data.get_owner_id(gc.x, gc.y) == to:
					ik += 0.35
			if dp.war_time(to, x) > 300.0 or dp.strength(to) < dp.strength(x) * 0.8:
				ik += 0.25
			ik += minf(0.45, 0.15 * float(_pressers(to)))
			var trd: Variant = _trd()
			if trd != null and trd.has_method("sanctions_on"):
				ik += minf(0.3, 0.1 * float((trd.sanctions_on(to) as Array).size()))
			if dp.strength(to) > dp.strength(x) * 1.5 and dp.war_time(to, x) < 600.0:
				ck += 0.3
			ik -= drama(to, "war")
	s += pk + ik - ck
	parts.append([Loc.t("характер"), pk])
	if ik != 0.0:
		parts.append([Loc.t("интерес"), ik])
	if ck != 0.0 and kind != "war_on":
		parts.append([Loc.t("цена"), - ck])
	elif kind == "war_on" and ck != 0.0:
		parts.append([Loc.t("цена войны"), - ck])
	if COSTLY.has(kind) and dp.get("rift") != null and not dp.rift.lab_off and not _human(to):

		for pp: int in dp.rift.partners(to):
			if pp == from or pp == x:
				continue
			var hz: String = dp.rift.hostile(from, pp)
			if hz != "" and not dp.rift.outweighs(to, from, pp):
				s -= 0.3
				parts.append([Loc.t("союзник %s враждует с вами") % _cn(pp), -0.3])
				break
	var fat: float = 0.12 * float(_rec(from, to, 600.0)) * (1.5 if leader else 1.0) + 0.1 * float(_busy(to))
	if fat > 0.0:
		s -= fat
		parts.append([Loc.t("усталость от просьб"), - fat])
	var n: int = n_override if n_override >= 0 else int(pn.get("%d>%d" % [from, to], 0))
	var noise: float = float(Hash32.h2(to * 131 + from, kid(kind) * 7 + n, floori(gw.game_time / 60.0)) % 200 - 100) / 1000.0
	s += noise
	var mood: bool = Hash32.h2(from * 977 + to, kid(kind) * 13 + n, 4049) % 100 >= MOOD_NO
	return {"s": s, "need": float(NEED[kind]), "parts": parts, "mood": mood, "rival": rival(to, from)}


func _hits_n(h: int) -> int:
	var a: Array = hits.get(h, [])
	var n: int = 0
	for t: float in a:
		if gw.game_time - t <= 300.0:
			n += 1
	return n


func _pressers(t: int) -> int:
	var n: int = 0
	for k: String in press:
		if int(k.split(">")[1]) == t:
			n += 1
	return n



func _away_share(c: int) -> float:
	var tot: int = 0
	var out: int = 0
	for u: Unit in gw.army.units:
		if u.country_id == c and u.alive() and u.ground():
			tot += 1
			var x: int = floori(u.pos.x / GameWorld.CELL)
			var y: int = floori(u.pos.y / GameWorld.CELL)
			if gw.data.inside(x, y) and gw.data.get_owner_id(x, y) != c:
				out += 1
	return float(out) / float(maxi(1, tot))



func bot_verdict(from: int, to: int, kind: String, x: int, sc: Dictionary) -> String:
	if bool(sc["rival"]) and kind != "stop_war":
		return Loc.t("СОПЕРНИК — %s не станет помогать вам") % _cn(to)
	if float(sc["s"]) < float(sc["need"]):
		return _why_low(sc)
	if not bool(sc["mood"]):
		return Loc.t("НЕ СЕЙЧАС — %s отказывает без объяснений") % _cn(to)
	return ""


func _why_low(sc: Dictionary) -> String:
	var worst: String = ""
	var wv: float = 0.0
	for p: Array in (sc["parts"] as Array):
		if float(p[1]) < wv:
			wv = float(p[1])
			worst = String(p[0])
	return (Loc.t("не видит выгоды") if worst == "" else worst)



func outlook(from: int, to: int, kind: String, x: int) -> Dictionary:
	var why: String = gate(from, to, kind, x)
	var w: float = wait_left(from, to, kind)
	var out: Dictionary = {"ok": why == "" and w <= 0.0, "why": why, "bucket": "", "human": _human(to), "wait": w, "parts": [], "wcode": "", "bk": ""}
	if why == "" and w > 0.0:
		out["why"] = Loc.t("уже просили · ждём %d:%02d") % [int(w) / 60, int(w) % 60]
		out["wcode"] = "asked"
	for r: Dictionary in reqs:
		if int(r["from"]) == from and int(r["to"]) == to and String(r["kind"]) == kind:
			out["ok"] = false
			out["why"] = Loc.t("ждём ответа")
			out["wcode"] = "waiting"
	if why != "" or _human(to):
		return out
	var sc: Dictionary = score(from, to, kind, x)
	out["parts"] = sc["parts"]
	var d: float = float(sc["s"]) - float(sc["need"])
	if bool(sc["rival"]) and kind != "stop_war":
		out["bucket"] = Loc.t("СКОРЕЕ НЕТ")
		out["bk"] = "no"
		out["why"] = Loc.t("СОПЕРНИК — не станет помогать")
	else:
		out["bk"] = "yes" if d >= 0.1 else ("maybe" if d >= -0.1 else "no")
		out["bucket"] = String(BUCKET_TEXT[out["bk"]])
	return out



const BUCKET_TEXT: Dictionary = {"yes": "СКОРЕЕ ДА", "maybe": "50 НА 50", "no": "СКОРЕЕ НЕТ"}




func ui_outlook(me: int, other: int, kind: String, x: int) -> Dictionary:
	var hum: bool = _human(other)
	if not KINDS.has(kind):
		return {"ans": "lock", "why": Loc.t("Нет такой просьбы"), "pros": [], "cons": [], "wait": 0.0, "human": hum, "chance_word": "", "reasons": [], "why_not": Loc.t("Нет такой просьбы")}
	if bool(NEEDS_X[kind]) and x <= 0:
		var ts: Array = targets(me, other, kind)
		var ok: bool = not ts.is_empty() and bool(ts[0]["ok"])
		var w0: String = "" if ok else (Loc.t("нет подходящих стран") if ts.is_empty() else String(ts[0]["why"]))
		return {"ans": "maybe" if ok else "lock", "why": w0, "pros": [], "cons": [], "wait": wait_left(me, other, kind), "human": hum, "chance_word": "", "reasons": [], "why_not": w0}
	var o: Dictionary = outlook(me, other, kind, maxi(0, x))
	var why: String = String(o["why"])
	var ans: String = "maybe"
	if String(o["wcode"]) != "":
		ans = "wait"
	elif not bool(o["ok"]):
		ans = "lock"
	elif not hum:
		ans = String(o["bk"]) if String(o["bk"]) != "" else "maybe"
	var pros: Array = []
	var cons: Array = []
	for pr: Array in (o["parts"] as Array):
		if float(pr[1]) > 0.02:
			pros.append(String(pr[0]))
		elif float(pr[1]) < -0.02:
			cons.append(String(pr[0]))
	var rival: bool = bool(score(me, other, kind, maxi(0, x))["rival"]) and not hum and kind != "stop_war"
	if rival:
		cons.push_front(Loc.t("СОПЕРНИК — не станет помогать"))
	var cw: String = Loc.t("ОТВЕТИТ САМ") if hum else String(o["bucket"])
	return {"ans": ans, "why": why, "pros": pros, "cons": cons, "wait": float(o["wait"]), "human": hum, "chance_word": cw, "rival": rival, 
		"reasons": pros + cons, "why_not": why if ans == "lock" or ans == "wait" else ""}






var sent_to_inbox: bool = false





static func result_kind(why: String) -> String:
	var s: String = Loc.src_of(why)
	if s.begins_with("Просьба отправлена"):
		return "inbox"
	if s.begins_with("Предложение отправлено"):
		return "offer_sent"
	if s.contains(" отказывает: "):
		return "refused"
	if s.contains(" согласна, но: "):
		return "agree_but"
	return ""


func send(from: int, to: int, kind: String, x: int) -> String:
	sent_to_inbox = false
	var why: String = gate(from, to, kind, x)
	if why != "":
		return why
	var w: float = wait_left(from, to, kind)
	if w > 0.0:
		return Loc.t("Уже просили: ещё %d с") % ceili(w)
	for r: Dictionary in reqs:
		if int(r["from"]) == from and int(r["to"]) == to and String(r["kind"]) == kind:
			sent_to_inbox = true
			return Loc.t("Просьба уже ждёт ответа")
	var now: float = gw.game_time
	if _human(from):
		var ts: Array = sent.get(from, [])
		var recent: Array = []
		for t: float in ts:
			if now - t < HUMAN_RATE_T:
				recent.append(t)
		if recent.size() >= HUMAN_RATE_N:
			return Loc.t("Не больше %d просьб за %d мин") % [HUMAN_RATE_N, int(HUMAN_RATE_T / 60.0)]
		recent.append(now)
		sent[from] = recent
	var pk: String = "%d>%d" % [from, to]
	var n: int = int(pn.get(pk, 0))
	pn[pk] = n + 1
	_n("asked_" + kind)
	_n("asked_%s_%s" % ["h" if _human(from) else "b", "h" if _human(to) else "b"])
	dp._reveal(from, to, true)
	if _human(to):
		if kind == "sky_me":
			var sk: String = dp.sky_ask(from, to)
			sent_to_inbox = sk == ""
			return (Loc.t("Просьба отправлена: %s ответит во «Входящих»") % _cn(to)) if sk == "" else sk
		reqs.append({"id": next_id, "kind": kind, "from": from, "to": to, "x": x, "made": now, "until": now + HUMAN_T, "n": n})
		next_id += 1
		gw.say(to, Loc.mk("ПРОСЬБА: %s", [text(reqs[reqs.size() - 1])]))
		gw.offer_received.emit()
		dp.pending_changed.emit()
		sent_to_inbox = true
		return Loc.t("Просьба отправлена: %s ответит во «Входящих» (до 2:00)") % _cn(to)
	var sc: Dictionary = score(from, to, kind, x, n)
	var v: String = bot_verdict(from, to, kind, x, sc)
	_bucket_count(from, to, kind, v == "")
	dp.dlog(to, "%s просьбу %s: %s" % [Loc.t("принимает") if v == "" else Loc.t("отклоняет"), _cn(from), kind], v, float(sc["s"]), ["req", kind, from, x])
	if v != "":
		_refused(from, to, kind, x, v, false)
		return Loc.t("%s отказывает: %s") % [_cn(to), v]
	return _accept(from, to, kind, x)


func _bucket_count(from: int, to: int, kind: String, yes: bool) -> void :
	var r: int = dp.relation(to, from)
	var b: String = "r<0" if r < 0 else ("r0-29" if r < 30 else ("r30-59" if r < 60 else "r60+"))
	_n("%s_%s_%s" % [kind, b, "yes" if yes else "no"])


func _log(from: int, to: int, kind: String, yes: bool) -> void :
	hist.append([gw.game_time, from, to, kid(kind), 1 if yes else 0])
	while not hist.is_empty() and gw.game_time - float(hist[0][0]) > 900.0:
		hist.remove_at(0)
	var k: String = "%d>%d>%d" % [from, to, kid(kind)]
	if yes:
		cd[k] = gw.game_time + CD_YES
	elif _human(from) and _human(to):
		cd[k] = gw.game_time + CD_HH
	else:
		cd[k] = gw.game_time + (CD_JOIN_NO if kind == "join_war" else CD_NO)



func _gain(a: int, b: int, v: int) -> void :
	var k: String = Diplomacy.key(a, b)
	var g: Array = gain.get(k, [gw.game_time, 0])
	if gw.game_time - float(g[0]) > GAIN_WIN:
		g = [gw.game_time, 0]
	var add: int = mini(v, GAIN_CAP - int(g[1]))
	if add > 0:
		dp.add_opinion(a, b, add)
		g[1] = int(g[1]) + add
	gain[k] = g



func _accept(from: int, to: int, kind: String, x: int) -> String:
	var why: String = ""
	match kind:
		"war_on":
			dp.declare_war(to, x, "по просьбе страны %s" % _cn(from))
			if not dp.at_war(to, x):
				why = Loc.t("война не началась")
			else:
				_n("war_by_req")
				dp.add_opinion(x, from, -25)
				dp.add_opinion(x, to, -10)
				incite["%d>%d" % [to, x]] = {"a": from, "t": gw.game_time, "hit": false}
				gw.news_m(Loc.mk("ПОДСТРЕКАТЕЛЬ — %s: %s НАЧИНАЕТ ВОЙНУ, ЦЕЛЬ — %s", [Loc.name(_cn(from)).to_upper(), Loc.name(_cn(to)).to_upper(), Loc.name(_cn(x)).to_upper()]), "alert_red")
		"join_war":
			why = dp.support_war(to, from, x)
			if why == "":
				_n("war_by_req")
				_n("join_by_req")
				incite["%d>%d" % [to, x]] = {"a": from, "t": gw.game_time, "hit": true, "j": true}
		"sky_me":
			if dp.has_method("_sky"):
				dp._sky().start(to, from, true)
			else:
				why = Loc.t("небо недоступно")
		"sky_over":
			why = dp.sky_offer(to, x)
		"station":
			station["%d>%d" % [to, from]] = {"kind": "station", "t": gw.game_time, "until": gw.game_time + STATION_T, "vs": x, "fid": -1}
			_n("station_on")
			if not _human(to):
				_bot_send(to, from, x)
			else:
				gw.say(to, Loc.mk("%s ждёт ваши войска: ВОЕННОЕ → РАЗМЕСТИТЬ АРМИЮ (право на %d мин)", [Loc.name(_cn(from)), int(STATION_T / 60.0)]))
		"guard":
			station["%d>%d" % [from, to]] = {"kind": "guard", "t": gw.game_time, "until": -1.0, "vs": x, "fid": -1}
			_n("guard_on")
			if not _human(from):
				_bot_send(from, to, x)
		"stop_war":
			_truce(to, x)
	_log(from, to, kind, why == "")
	if why != "":
		return Loc.t("%s соглашается, но: %s") % [_cn(to), why]
	_n("yes_" + kind)
	_gain(from, to, 8)
	if dp.care != null and COSTLY.has(kind):
		dp.care.on_help(to, from, 1500)
	gw.say2(from, to, Loc.mk("%s соглашается: %s", [Loc.name(_cn(to)), text({"kind": kind, "from": from, "to": to, "x": x}, true)]))
	dp.pending_changed.emit()
	gw.relations_changed.emit()
	return ""



func _refused(from: int, to: int, kind: String, x: int, why: String, silent: bool) -> void :
	_log(from, to, kind, false)
	_n("no_" + kind)
	if not silent:
		var oblig: bool = (kind == "join_war" and dp._obligation(to, from, x) != "" and dp._defender(from, x))\
		or ((kind == "sky_me" or kind == "station") and (dp.allied(to, from) or (dp.ally != null and dp.ally.same(to, from))) and not gw.country_by_id(from).at_war.is_empty())
		if oblig:
			dp._grievance(from, to, x)
		elif dp.relation(from, to) >= 30:
			dp.add_opinion(from, to, -2)
	if kind == "stop_war":
		_press_refused(from, to, x)
	if _human(from):
		gw.say(from, Loc.mk("%s отказывает: %s%s", [Loc.name(_cn(to)), KIND_NAMES[kind].to_lower(), (" — " + why) if why != "" else ""]))


func _truce(t: int, v: int) -> void :
	if not dp.at_war(t, v):
		return
	_n("stop_truce")
	if _human(v):
		dp._offer(t, v, Diplomacy.Rel.TRUCE)
		return
	dp._set_rel(t, v, Diplomacy.Rel.TRUCE)
	gw.news_m(Loc.mk("ПЕРЕМИРИЕ: %s И %s (ПОД ДАВЛЕНИЕМ)", [Loc.name(_cn(t)).to_upper(), Loc.name(_cn(v)).to_upper()]), "amber")
	dp._dip2_peace(t, v, Diplomacy.Rel.TRUCE)



func answer(n: int, act: String, who: int) -> String:
	for i in reqs.size():
		var r: Dictionary = reqs[i]
		if int(r["id"]) != n:
			continue
		if who > 0 and int(r["to"]) != who:
			return Loc.t("Нет такого")
		var from: int = int(r["from"])
		var kind: String = String(r["kind"])
		var x: int = int(r["x"])
		if act == "accept":
			var g: String = gate(from, int(r["to"]), kind, x)
			if g != "":
				return Loc.t("Нельзя: %s") % [g]
			reqs.remove_at(i)
			_bucket_count(from, int(r["to"]), kind, true)
			var w: String = _accept(from, int(r["to"]), kind, x)
			dp.pending_changed.emit()
			return w
		reqs.remove_at(i)
		_bucket_count(from, int(r["to"]), kind, false)
		_refused(from, int(r["to"]), kind, x, "", false)
		dp.pending_changed.emit()
		return ""
	return Loc.t("Просьба устарела")



func cancel(cid: int, n: int) -> String:
	for i in reqs.size():
		if int(reqs[i]["id"]) == n:
			if int(reqs[i]["from"]) != cid:
				return Loc.t("Это не ваша просьба")
			reqs.remove_at(i)
			dp.pending_changed.emit()
			return ""
	return Loc.t("Просьбы нет")


func item_to(n: int) -> int:
	for r: Dictionary in reqs:
		if int(r["id"]) == n:
			return int(r["to"])
	return -1



func text(r: Dictionary, done: bool = false) -> String:
	var a: String = Loc.name(_cn(int(r["from"])))
	var x: String = Loc.name(_cn(int(r.get("x", 0)))) if int(r.get("x", 0)) > 0 else ""
	var t: String = Loc.name(_cn(int(r["to"])))
	match String(r["kind"]):
		"war_on":

			return (Loc.t("%s объявляет войну — цель: %s") % [t, x]) if done else (Loc.t("%s просит объявить войну — цель: %s") % [a, x])
		"join_war":
			return (Loc.t("%s вступает в войну — враг: %s") % [t, x]) if done else (Loc.t("%s просит вступить в её войну — враг: %s") % [a, x])
		"sky_me":
			return (Loc.t("%s закрывает небо над страной %s") % [t, a]) if done else (Loc.t("%s просит: «закройте небо над нами»") % a)
		"sky_over":
			return (Loc.t("%s предлагает закрыть небо над страной %s") % [t, x]) if done else (Loc.t("%s просит закрыть небо над страной %s") % [a, x])
		"station":
			return (Loc.t("%s размещает войска на земле страны %s") % [t, a]) if done else (Loc.t("%s просит: «поставьте войска у нас»%s") % [a, (Loc.t(" (угроза: %s)") % x) if x != "" else ""])
		"stop_war":
			return (Loc.t("%s предлагает перемирие стране %s") % [t, x]) if done else (Loc.t("%s требует прекратить войну против страны %s") % [a, x])
		"guard":
			return (Loc.t("%s пускает армию страны %s на защиту") % [t, a]) if done else (Loc.t("%s хочет прислать армию на вашу защиту без войны — враг: %s") % [a, x])
	return "?"



func conseq(r: Dictionary) -> Array:
	var k: String = String(r["kind"])
	var x: String = _cn(int(r.get("x", 0))) if int(r.get("x", 0)) > 0 else ""
	var a: String = _cn(int(r["from"]))
	var yes: String = Loc.t("+отношения: %s") % a
	var no: String = Loc.t("ничего (немного остынут, если дружите)")
	match k:
		"war_on":
			yes = Loc.t("вы объявляете войну стране %s; %s запомнит подстрекателя") % [x, x]
		"join_war":
			yes = Loc.t("вы вступаете в войну против страны %s") % x
			if dp._obligation(int(r["to"]), int(r["from"]), int(r["x"])) != "":
				no = Loc.t("нота протеста (3 — разрыв договора)")
		"sky_me", "sky_over":
			yes = Loc.t("ваше ПВО прикрывает союзника без войны")
		"station":
			yes = Loc.t("право держать армию у них %d мин; если враг тронет её — война") % int(STATION_T / 60.0)
		"guard":
			yes = Loc.t("их армия бьёт врага на вашей земле; вы не платите")
		"stop_war":
			yes = Loc.t("перемирие со страной %s") % x
			no = Loc.t("%s вводит санкции против вас (материал, потом эмбарго)") % a
	return [yes, no]



func pending(me: int, now: float) -> Array:
	var out: Array = []
	for r: Dictionary in reqs:
		if int(r["to"]) != me:
			continue
		var cq: Array = conseq(r)
		out.append({"id": "q%d" % int(r["id"]), "from": int(r["from"]), "kind": "request", "req": String(r["kind"]), "x": int(r["x"]), 
			"icon": String(KIND_ICONS[String(r["kind"])]), "text": text(r), "yes": cq[0], "no": cq[1], 
			"deadline": float(r["until"]), "left": maxf(0.0, float(r["until"]) - now), "total": HUMAN_T, 
			"options": [{"act": "accept", "label": Loc.t("СОГЛАСИТЬСЯ") if String(r["kind"]) != "join_war" else Loc.t("ВСТУПИТЬ")}, {"act": "refuse", "label": Loc.t("ОТКАЗАТЬ")}]})
	return out



func asked_by(me: int) -> Array:
	var out: Array = []
	for r: Dictionary in reqs:
		if int(r["from"]) == me:
			out.append({"id": int(r["id"]), "kind": String(r["kind"]), "to": int(r["to"]), "x": int(r["x"]), "left": maxf(0.0, float(r["until"]) - gw.game_time), "text": text(r)})
	return out



func targets(me: int, other: int, kind: String) -> Array:
	var out: Array = []
	for c: Country in gw.countries:
		if not _alive(c.id) or c.capital_id < 0 or c.id == other or (c.id == me and kind != "sky_over"):
			continue
		match kind:
			"join_war":
				if not dp.at_war(me, c.id):
					continue
			"stop_war", "guard":
				if not dp.at_war(other, c.id):
					continue
		var o: Dictionary = outlook(me, other, kind, c.id)
		out.append({"id": c.id, "ok": o["ok"], "why": o["why"], "bucket": o["bucket"]})
	out.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["ok"]) != bool(b["ok"]):
			return bool(a["ok"])
		return int(a["id"]) < int(b["id"]))
	return out





func land_ok(c: int, owner: int) -> bool:
	return station.has("%d>%d" % [c, owner])



func stations_of(me: int) -> Array:
	var out: Array = []
	var ks: Array = station.keys()
	ks.sort()
	for k: String in ks:
		var ab: PackedStringArray = k.split(">")
		var s: int = int(ab[0])
		var h: int = int(ab[1])
		if s != me and h != me:
			continue
		var e: Dictionary = station[k]
		out.append({"who": s, "host": h, "kind": String(e["kind"]), "left": (float(e["until"]) - gw.game_time) if float(e["until"]) > 0.0 else -1.0, 
			"vs": int(e["vs"]), "troops": dp.troops_on(s, h)})
	return out



func _free_army(c: int, toward: Vector2 = Vector2.INF) -> Facility:
	var best: Facility = null
	var bd: float = INF
	for f: Facility in gw.mil.facilities:
		if f.kind != Facility.Kind.BARRACKS or f.country_id != c or not gw.mil.alive(f) or gw.ops.list.has(f):
			continue
		if gw.ops._army(f).size() < 4:
			continue
		var d: float = f.center_px().distance_to(toward) if toward.is_finite() else float(f.id)
		if d < bd:
			bd = d
			best = f
	return best



func guard_spot(host: int, vs: int) -> Vector2:
	var ch: Country = gw.country_by_id(host)
	if ch == null or ch.capital_id < 0:
		return Vector2.INF
	var hc: Vector2 = Vector2(gw.cities[ch.capital_id].center)
	var ce: Country = gw.country_by_id(vs) if vs > 0 else null
	if ce == null or ce.capital_id < 0:
		return gw.econ.land_point(hc * GameWorld.CELL + Vector2(24, 0), 30)
	var ec: Vector2 = Vector2(gw.cities[ce.capital_id].center)
	var dir: Vector2 = (ec - hc).normalized()
	var last: float = 0.0
	for i in range(0, int(hc.distance_to(ec)), 2):
		var q: Vector2 = hc + dir * float(i)
		if gw.data.inside(int(q.x), int(q.y)) and gw.data.get_owner_id(int(q.x), int(q.y)) == host:
			last = float(i)
	for fr: float in [0.7, 0.55, 0.4, 0.25]:
		var q2: Vector2 = gw.econ.land_point((hc + dir * maxf(last * fr, 12.0)) * GameWorld.CELL, 30)
		var x: int = floori(q2.x / GameWorld.CELL)
		var y: int = floori(q2.y / GameWorld.CELL)
		if gw.data.inside(x, y) and gw.data.get_owner_id(x, y) == host:
			return q2
	return gw.econ.land_point(hc * GameWorld.CELL + Vector2(24, 0), 30)






func guard_send(cid: int, host: int, what: Variant, vs: int = 0) -> String:
	if not _alive(host) or host == cid:
		return Loc.t("Страны нет")
	if dp.at_war(cid, host):
		return Loc.t("Вы воюете с ними")
	var k: String = "%d>%d" % [cid, host]
	var ally: bool = dp.allied(cid, host) or (dp.ally != null and dp.ally.same(cid, host))
	if not station.has(k) and not ally:
		return Loc.t("Нужно согласие страны %s: попросите «пустить армию на защиту» или договоритесь о размещении") % _cn(host)
	var fs: Array = []
	var gid: int = -1
	if what is Facility:
		fs.append(what)
	elif typeof(what) == TYPE_INT:
		gid = int(what)
		var g: Dictionary = AGS.by_id(gw, cid, gid)
		if g.is_empty():
			return Loc.t("Нет такой группы армий")
		for fid: int in (g.get("fids", PackedInt32Array()) as PackedInt32Array):
			var f0: Facility = AGS.fac(gw, fid)
			if f0 != null:
				fs.append(f0)
	if station.has(k) and vs > 0 and dp.at_war(host, vs):
		station[k]["vs"] = vs
	var sent_n: int = 0
	var why: String = Loc.t("Выберите свою армию")
	for i in fs.size():
		why = _send_army(cid, host, fs[i], i, vs)
		if why == "":
			sent_n += 1
	if sent_n == 0:
		return why
	if not station.has(k):
		station[k] = {"kind": "guard", "t": gw.game_time, "until": -1.0, "vs": _focus(host, vs), "fid": -1, "ally": true}
		_n("guard_ally")
	elif vs > 0 and dp.at_war(host, vs):
		station[k]["vs"] = vs
	station[k]["gid"] = gid
	if fs.size() == 1:
		station[k]["fid"] = (fs[0] as Facility).id
	return ""



func _send_army(cid: int, host: int, f: Facility, i: int, want: int = 0) -> String:
	if f == null or f.kind != Facility.Kind.BARRACKS or f.country_id != cid or not gw.mil.alive(f):
		return Loc.t("Выберите свою армию")
	var k: String = "%d>%d" % [cid, host]
	if gw.ops._army(f).is_empty():
		return Loc.t("В армии №%d нет солдат") % f.army_no
	var vs: int = int((station.get(k, {}) as Dictionary).get("vs", 0))
	if vs <= 0 or not dp.at_war(host, vs):
		vs = _focus(host, want)
	var p: Vector2 = guard_spot(host, vs)
	if not p.is_finite():
		return Loc.t("Нет места на их земле")
	if i > 0:
		p = gw.econ.land_point(p + Vector2(float((i % 2) * 2 - 1) * 70.0 * float((i + 1) / 2), 0.0), 30)
	var why: String = gw.ops.start(f, Operations.Kind.DEFEND, p)
	if why == "":
		_n("army_sent")
		gw.say2(cid, host, Loc.mk("Армия №%d (%s) идёт на землю страны %s%s", [f.army_no, Loc.name(_cn(cid)), Loc.name(_cn(host)), (Loc.t(" — защита без войны, враг: %s") % Loc.name(_cn(vs))) if vs > 0 and String((station.get(k, {}) as Dictionary).get("kind", "")) != "station" else ""]))
	return why




func _focus(host: int, want: int = 0) -> int:
	if want > 0 and dp.at_war(host, want):
		return want
	var ch: Country = gw.country_by_id(host)
	if ch == null:
		return 0
	var es: Array = ch.at_war.keys()
	es.sort()
	for e: int in es:
		if int(dp.war_by.get(Diplomacy.key(host, e), -1)) != host:
			return e
	return int(es[0]) if not es.is_empty() else 0


func _bot_send(c: int, host: int, vs: int) -> void :
	var ch: Country = gw.country_by_id(host)
	if ch == null or ch.capital_id < 0:
		return
	var f: Facility = _free_army(c, Vector2(gw.cities[ch.capital_id].center * GameWorld.CELL))
	if f == null:
		_n("bot_send_noarmy")
		return
	var why: String = guard_send(c, host, f, vs)
	if why != "":
		_n("bot_send_fail")
		dp.dlog(c, "не может отправить армию к %s" % _cn(host), why)
		last_fail = why



func guard_info(me: int, other: int) -> Dictionary:
	var k: String = "%d>%d" % [me, other]
	if not station.has(k):
		return {}
	var e: Dictionary = station[k]
	var gid: int = int(e.get("gid", -1))
	var nm: String = ""
	var sent: bool = gid >= 0
	if gid >= 0:
		nm = String(AGS.by_id(gw, me, gid).get("name", ""))
	if nm == "" and int(e.get("fid", -1)) >= 0:
		var f: Facility = AGS.fac(gw, int(e["fid"]))
		nm = (Loc.t("АРМИЯ №%d") % f.army_no) if f != null else ""
		sent = sent or f != null
	if nm == "":
		nm = Loc.t("АРМИЯ")
	return {"gid": gid, "name": nm, "sent": sent, "kind": String(e["kind"]), "left": (float(e["until"]) - gw.game_time) if float(e["until"]) > 0.0 else -1.0, 
		"troops": dp.troops_on(me, other), "vs": int(e.get("vs", 0))}



func station_end(cid: int, other: int) -> String:
	var n: int = 0
	for k: String in ["%d>%d" % [cid, other], "%d>%d" % [other, cid]]:
		if station.has(k):
			_end(k, Loc.t("отозвано: %s") % _cn(cid))
			n += 1
	return "" if n > 0 else Loc.t("Размещения нет")


func _end(k: String, why: String) -> void :
	if not station.has(k):
		return
	var ab: PackedStringArray = k.split(">")
	var s: int = int(ab[0])
	var h: int = int(ab[1])
	var kind: String = String(station[k]["kind"])
	station.erase(k)
	_n("station_off")
	gw.say2(s, h, Loc.mk("%s: армия (%s) уходит с земли страны %s (%s)", [Loc.t("РАЗМЕЩЕНИЕ") if kind == "station" else Loc.t("ЗАЩИТА"), Loc.name(_cn(s)), Loc.name(_cn(h)), why]))
	if _alive(s) and _alive(h) and not dp.at_war(s, h):
		dp.close_land(s, h)
	gw.relations_changed.emit()




func forget(id: int) -> void :
	for k: String in station.keys():
		var ab: PackedStringArray = k.split(">")
		if int(ab[0]) == id or int(ab[1]) == id:
			_end(k, Loc.t("новое государство"))
	for i in range(reqs.size() - 1, -1, -1):
		if int(reqs[i]["from"]) == id or int(reqs[i]["to"]) == id or int(reqs[i].get("x", 0)) == id:
			reqs.remove_at(i)
	for dct: Dictionary in [press, press_done, incite, cd, pn]:
		for k2: String in dct.keys():
			var ps: PackedStringArray = k2.split(">")
			if (ps.size() > 0 and int(ps[0]) == id) or (ps.size() > 1 and int(ps[1]) == id) or (ps.size() > 2 and ps[2].is_valid_int() and int(ps[2]) == id):
				dct.erase(k2)
	for dct2: Dictionary in [sent, bot_next, war_on_t, b2h, hits]:
		dct2.erase(id)
	dp.pending_changed.emit()



func guarding(cid: int) -> bool:
	return gcount.has(cid)




func guard_hit(a: int, b: int, pa: Vector2, pb: Vector2) -> bool:
	var h: int = int(gp.get(a * 64 + b, 0))
	if h <= 0:
		return false
	if _owner(pb) != h and _owner(pa) != h:
		return false
	clash[mini(a, b) * 64 + maxi(a, b)] = gw.game_time
	return true


func _owner(p: Vector2) -> int:
	var x: int = floori(p.x / GameWorld.CELL)
	var y: int = floori(p.y / GameWorld.CELL)
	return gw.data.get_owner_id(x, y) if gw.data.inside(x, y) else 0




func on_hit(attacker: int, owner: int) -> bool:
	var a: Array = hits.get(owner, [])
	a.append(gw.game_time)
	while a.size() > 12 or ( not a.is_empty() and gw.game_time - float(a[0]) > 300.0):
		a.remove_at(0)
	hits[owner] = a
	for k: String in incite:
		if int(incite[k]["a"]) == attacker and k.ends_with(">%d" % owner):
			incite[k]["hit"] = true
	return station.has("%d>%d" % [attacker, owner])


func _tick_land() -> void :
	gp.clear()
	gcount.clear()
	var now: float = gw.game_time
	var ks: Array = station.keys()
	ks.sort()
	for k: String in ks:
		if not station.has(k):
			continue
		var ab: PackedStringArray = k.split(">")
		var s: int = int(ab[0])
		var h: int = int(ab[1])
		var e: Dictionary = station[k]
		if not _alive(s) or not _alive(h) or dp.at_war(s, h):
			station.erase(k)
			continue
		var ch: Country = gw.country_by_id(h)
		if String(e["kind"]) == "station":
			if now >= float(e["until"]):
				_end(k, Loc.t("срок размещения вышел"))
				continue
			_tripwire(s, h, ch)
		else:
			if bool(e.get("ally", false)) and not (dp.allied(s, h) or (dp.ally != null and dp.ally.same(s, h))):
				_end(k, Loc.t("союз расторгнут"))
				continue


			var foes: Array = []
			var hw: Array = ch.at_war.keys()
			hw.sort()
			for en0: int in hw:
				if en0 == int(e.get("vs", 0)) or int(dp.war_by.get(Diplomacy.key(h, en0), -1)) != h:
					foes.append(en0)
			if foes.is_empty():
				if float(e["until"]) < 0.0:
					e["until"] = now + GUARD_TAIL
				elif now >= float(e["until"]):
					_end(k, Loc.t("война кончилась"))
					continue
			else:
				e["until"] = -1.0
				if not foes.has(int(e.get("vs", 0))):
					e["vs"] = int(foes[0])
			for en: int in foes:
				if en == s or dp.at_war(s, en) or not _alive(en):
					continue
				gp[s * 64 + en] = h
				gp[en * 64 + s] = h
				gcount[s] = true
				gcount[en] = true



func _tripwire(s: int, h: int, ch: Country) -> void :
	if ch.at_war.is_empty():
		return
	var mine: Array[Unit] = gw.ops.wd_units(s, h)
	if mine.is_empty():
		return
	var es: Array = ch.at_war.keys()
	es.sort()
	for en: int in es:
		if dp.at_war(s, en) or not _alive(en) or dp._join_block(s, en) != "":
			continue
		for u: Unit in gw.army.units:
			if u.country_id != en or not u.alive() or not u.ground():
				continue
			if _owner(u.pos) != h:
				continue
			var near: bool = false
			for m: Unit in mine:
				if m.pos.distance_squared_to(u.pos) < TRIP_R * TRIP_R:
					near = true
					break
			if not near:
				continue
			_n("tripwire")
			gw.news_m(Loc.mk("РАСТЯЖКА: %s (ВОЙСКА НА ЗЕМЛЕ СТРАНЫ %s) ВСТУПАЕТ В ВОЙНУ — ВРАГ: %s", [Loc.name(_cn(s)).to_upper(), Loc.name(_cn(h)).to_upper(), Loc.name(_cn(en)).to_upper()]), "alert_red")
			if dp.war_block(s, en).is_empty():
				dp._join_war(s, en, h, Loc.t("РАСТЯЖКА"))
			break



func _anger() -> void :
	var now: float = gw.game_time
	var ks: Array = clash.keys()
	ks.sort()
	for ck: int in ks:
		if now - float(clash[ck]) > 60.0:
			clash.erase(ck)
			continue
		var a: int = ck / 64
		var b: int = ck % 64
		for pr: Array in [[a, b], [b, a]]:
			var e: int = int(pr[0])
			var s: int = int(pr[1])
			if int(gp.get(s * 64 + e, 0)) <= 0 or _human(e):
				continue
			var guard_side: bool = false
			for k: String in station:
				if k.begins_with("%d>" % s) and String(station[k]["kind"]) == "guard":
					guard_side = true
			if not guard_side:
				continue
			var ak: String = "%d>%d" % [e, s]
			if now - float(anger_t.get(ak, -1000000000.0)) < 60.0:
				continue
			anger_t[ak] = now
			dp.add_opinion(e, s, -3)
			if not dp.war_allowed(e, s, false) or not dp.war_block(e, s).is_empty():
				continue
			var P: Dictionary = dp._p(e)
			var ch: int = 120 + int(250.0 * float(P.get("aggr", 0.5))) - int(150.0 * float(P.get("caution", 0.5)))
			if dp.war_power(e) > dp.war_power(s) * 1.3:
				ch += 150
			if dp.war_power(s) > dp.war_power(e) * 1.3:
				ch -= 200
			ch += int(drama(e, "war") * 1000.0)
			if Hash32.h2(e * 61 + s, floori(now / 60.0), 7331) % 1000 < ch:
				_n("guard_anger_war")
				dp.declare_war(e, s, "армия страны %s мешает войне" % _cn(s))
			else:
				_n("guard_anger_pass")




func _press_refused(p: int, t: int, v: int) -> void :
	if _human(p):
		return
	var k: String = "%d>%d" % [p, t]
	if press.has(k):
		return
	press[k] = {"v": v, "step": 0, "next": gw.game_time, "emb": false, "end": -1.0}
	_press_step(k)




func _press_step(k: String) -> void :
	var e: Dictionary = press[k]
	var ab: PackedStringArray = k.split(">")
	var p: int = int(ab[0])
	var t: int = int(ab[1])
	var trd: Variant = _trd()
	var step: int = int(e["step"]) + 1
	e["step"] = step
	e["next"] = gw.game_time + PRESS_STEP_T
	var P: Dictionary = dp._p(p)
	var hard: bool = step >= 2 and (float(P.get("trade", 0.5)) >= 0.6 or dp.allied(p, int(e["v"])) or (dp.ally != null and dp.ally.same(p, int(e["v"]))))
	if not hard and trd != null and trd.has_method("impose_sanction"):
		if String(trd.impose_sanction(p, t, "")) == "":
			_n("press_sanction")
			gw.say(t, Loc.mk("%s вводит санкции, пока вы воюете со страной %s", [Loc.name(_cn(p)), Loc.name(_cn(int(e["v"])))]))
			return
	if step >= 2 and not dp.embargoed(p, t):
		dp.set_embargo(p, t, true)
		e["emb"] = true
		_n("press_embargo")


func _press_tick() -> void :
	var now: float = gw.game_time
	var ks: Array = press.keys()
	ks.sort()
	for k: String in ks:
		var e: Dictionary = press[k]
		var ab: PackedStringArray = k.split(">")
		var p: int = int(ab[0])
		var t: int = int(ab[1])
		var v: int = int(e["v"])
		if not _alive(p) or not _alive(t):
			press.erase(k)
			continue
		if not dp.at_war(t, v) or dp.at_war(p, t):
			if float(e["end"]) < 0.0:
				e["end"] = now + PRESS_LIFT_T
			elif now >= float(e["end"]):
				var trd: Variant = _trd()
				if trd != null and trd.has_method("lift_all") and not dp.at_war(p, t):
					trd.lift_all(p, t)
				if bool(e["emb"]) and not dp.at_war(p, t):
					dp.set_embargo(p, t, false)
				press.erase(k)
				_n("press_lifted")
			continue
		if int(e["step"]) < 2 and now >= float(e["next"]):
			if not _human(t) and bot_verdict(p, t, "stop_war", v, score(p, t, "stop_war", v, int(e["step"]) + 7)) == "":
				_n("press_won")
				gw.say(p, Loc.mk("%s уступает давлению: перемирие со страной %s", [Loc.name(_cn(t)), Loc.name(_cn(v))]))
				_truce(t, v)
				continue
			_press_step(k)

	for k2: String in dp.war_by.keys():
		var ab2: PackedStringArray = String(k2).split(":")
		var a0: int = int(ab2[0])
		var b0: int = int(ab2[1])
		if not dp.at_war(a0, b0):
			continue
		var t2: int = int(dp.war_by[k2])
		var v2: int = b0 if t2 == a0 else a0
		if dp.war_time(t2, v2) < 120.0:
			continue
		var choice: bool = true
		for i in range(dp.wars_log.size() - 1, -1, -1):
			var wl: Array = dp.wars_log[i]
			if int(wl[1]) == t2 and int(wl[2]) == v2:
				choice = not Loc.src(wl[3]).begins_with("ультиматум")
				break
		var lost: bool = dp.care != null and not (dp.care.lost_t.get(v2, []) as Array).is_empty()
		if not choice and not lost:
			continue
		var cands: Array = []
		var n_on: int = 0
		for pk: String in press:
			if pk.ends_with(">%d" % t2) and int(press[pk]["v"]) == v2:
				n_on += 1
		for c: Country in gw.countries:
			var p2: int = c.id
			if c.is_player or p2 == t2 or p2 == v2 or not _alive(p2) or c.capital_id < 0 or dp.at_war(p2, t2) or dp.allied(p2, t2) or dp.is_subject(p2):
				continue
			if press_done.has("%d>%d>%d" % [p2, t2, v2]) or press.has("%d>%d" % [p2, t2]):
				continue
			var tie: bool = dp.allied(p2, v2) or dp.has_treaty(p2, v2, "defense") or (dp.ally != null and dp.ally.same(p2, v2))
			if dp.relation(p2, v2) < 40 and not tie:
				continue
			cands.append([dp.relation(p2, v2) + (100 if tie else 0), p2, tie])
		cands.sort_custom( func(x: Array, y: Array) -> bool: return int(x[0]) > int(y[0]) or (int(x[0]) == int(y[0]) and int(x[1]) < int(y[1])))
		for cd0: Array in cands:
			if n_on >= PRESS_MAX:
				break
			var p3: int = int(cd0[1])
			press_done["%d>%d>%d" % [p3, t2, v2]] = true
			var P3: Dictionary = dp._p(p3)
			var ch: int = 350 + int(300.0 * float(P3.get("caution", 0.5))) + (200 if bool(cd0[2]) else 0) - (300 if dp.strength(t2) > dp.strength(p3) * 2.0 else 0)
			ch += int(drama(p3, "peace") * 1000.0)
			if Hash32.h2(p3 * 71 + t2, v2, 9157) % 1000 >= ch:
				continue
			n_on += 1
			_n("press_call")
			if _human(t2) and not _b2h_ok(t2, 180.0):
				press[("%d>%d" % [p3, t2])] = {"v": v2, "step": 0, "next": now + PRESS_STEP_T, "emb": false, "end": -1.0}
				_press_step("%d>%d" % [p3, t2])
				continue
			var r: String = send(p3, t2, "stop_war", v2)
			if _human(t2) and sent_to_inbox:
				_b2h_note(t2)



func press_on(t: int) -> Array:
	var out: Array = []
	var trd: Variant = _trd()
	var ks: Array = press.keys()
	ks.sort()
	for k: String in ks:
		var ab: PackedStringArray = k.split(">")
		if int(ab[1]) != t:
			continue
		var e: Dictionary = press[k]
		out.append({"by": int(ab[0]), "v": int(e["v"]), "step": int(e["step"]), "embargo": bool(e["emb"]), 
			"res": (trd.sanctions_by(int(ab[0]), t) if trd != null and trd.has_method("sanctions_by") else [])})
	return out




func _b2h_ok(h: int, gap: float = B2H_GAP) -> bool:
	var now: float = gw.game_time
	if now < B2H_FIRST:
		return false
	var a: Array = b2h.get(h, [])
	var n: int = 0
	for t: float in a:
		if now - t < B2H_WIN:
			n += 1
	return n < B2H_N and (a.is_empty() or now - float(a[a.size() - 1]) >= gap)


func _b2h_note(h: int) -> void :
	var a: Array = b2h.get(h, [])
	a.append(gw.game_time)
	while a.size() > 6:
		a.remove_at(0)
	b2h[h] = a


func _bots_ask() -> void :
	var now: float = gw.game_time
	if now < GRACE or GameConfig.aggression == 0:
		return
	for c: Country in gw.countries:
		var a: int = c.id
		if c.is_player or not _alive(a) or c.capital_id < 0 or dp.is_subject(a) or now < float(bot_next.get(a, 0.0)):
			continue
		var P: Dictionary = dp._p(a)
		var pid: String = String(P.get("id", ""))
		var h: int = Hash32.h2(a, floori(now / THINK), 5821) % 1000
		var did: bool = false

		if (pid == "militarist" or pid == "adventurer") and now >= float(war_on_t.get(a, 0.0)) and now >= war_on_map and h < 120 + int(drama(a, "war") * 600.0):
			did = _ask_war_on(a)

		if not did and (pid == "cautious" or float(P.get("caution", 0.5)) >= 0.6) and h < 200:
			did = _ask_station(a)

		if not did and h < 160 + int(drama(a, "help") * 600.0):
			did = _ask_guard(a)
		if did:
			bot_next[a] = now + BOT_GAP


func _target_ok(a: int, t: int, kind: String) -> bool:
	if not _human(t):
		return true
	return _b2h_ok(t)


func _ask_war_on(a: int) -> bool:
	var ca: Country = gw.country_by_id(a)
	if not ca.at_war.is_empty():
		return false
	var best_x: int = -1
	var bs: float = 0.0
	for o: Country in gw.countries:
		var x: int = o.id
		if x == a or not _alive(x) or o.capital_id < 0 or dp.at_war(a, x) or dp.allied(a, x) or (dp._rel_eff(a, x) if dp.has_method("_rel_eff") else dp.relation(a, x)) > -10:
			continue
		var sc: float = 0.0
		if dp.neighbours(a, x) and dp.war_power(x) > dp.war_power(a) * 1.3:
			sc += 1.0
		if rival(x, a) or rival(a, x):
			sc += 0.6
		if not dp.coalition.is_empty() and int(dp.coalition["leader"]) == x:
			sc += 0.6
		sc += float( - dp.relation(a, x)) / 200.0
		if sc > bs:
			bs = sc
			best_x = x
	if best_x < 0 or bs < 1.0:
		return false
	var best_t: int = -1
	var br: int = 49
	for o2: Country in gw.countries:
		var t: int = o2.id
		if t == a or t == best_x or not _alive(t) or o2.capital_id < 0 or dp.relation(t, a) <= br:
			continue
		if gate(a, t, "war_on", best_x) != "" or wait_left(a, t, "war_on") > 0.0 or not _target_ok(a, t, "war_on"):
			continue
		br = dp.relation(t, a)
		best_t = t
	if best_t < 0:
		return false
	war_on_t[a] = gw.game_time + WAR_ON_BOT_GAP
	war_on_map = gw.game_time + WAR_ON_MAP_GAP
	_n("bot_ask_war_on")
	var r: String = send(a, best_t, "war_on", best_x)
	if _human(best_t) and sent_to_inbox:
		_b2h_note(best_t)
	return true


func _ask_station(h: int) -> bool:
	var e: int = -1
	for o: Country in gw.countries:
		if o.id != h and _alive(o.id) and o.capital_id >= 0 and dp.neighbours(h, o.id) and dp.war_power(o.id) >= dp.war_power(h) * 1.5 and dp.relation(h, o.id) < -30:
			e = o.id
			break
	if e < 0:
		return false
	for o2: Country in gw.countries:
		var t: int = o2.id
		if t == h or t == e or not _alive(t) or o2.capital_id < 0:
			continue
		if not (dp.allied(h, t) or dp.has_treaty(h, t, "defense") or (dp.ally != null and dp.ally.same(h, t))):
			continue
		if gate(h, t, "station", e) != "" or wait_left(h, t, "station") > 0.0 or not _target_ok(h, t, "station"):
			continue
		_n("bot_ask_station")
		var r: String = send(h, t, "station", e)
		if _human(t) and sent_to_inbox:
			_b2h_note(t)
		return true
	return false


func _ask_guard(s: int) -> bool:
	var cs: Country = gw.country_by_id(s)
	if not cs.at_war.is_empty() or _free_army(s) == null:
		return false
	for o: Country in gw.countries:
		var v: int = o.id
		if v == s or not _alive(v) or o.capital_id < 0 or o.at_war.is_empty() or dp.relation(s, v) < 50:
			continue
		var es: Array = o.at_war.keys()
		es.sort()
		for e: int in es:
			if not dp._defender(v, e) or dp.war_power(e) < dp.war_power(v) * 0.9 or dp.relation(s, e) > 0:
				continue
			if gate(s, v, "guard", e) != "" or wait_left(s, v, "guard") > 0.0 or not _target_ok(s, v, "guard"):
				continue
			_n("bot_ask_guard")
			var r: String = send(s, v, "guard", e)
			if _human(v) and sent_to_inbox:
				_b2h_note(v)
			return true
	return false




func ask_join(c: int, x: int, e: int) -> String:
	if lab_off:
		return ""
	var sc: Dictionary = score(x, c, "join_war", e)
	return "join" if bot_verdict(x, c, "join_war", e, sc) == "" else ""



func _incite_tick() -> void :
	var now: float = gw.game_time
	var ks: Array = incite.keys()
	ks.sort()
	for k: String in ks:
		var e: Dictionary = incite[k]
		var ab: PackedStringArray = k.split(">")
		var t: int = int(ab[0])
		var x: int = int(ab[1])
		var a: int = int(e["a"])
		if not _alive(a) or not _alive(t):
			incite.erase(k)
			continue
		var betray: bool = dp.has_treaty(a, x, "nap") or dp.has_treaty(a, x, "trade") or dp.has_treaty(a, x, "defense") or dp.allied(a, x)
		if bool(e.get("j", false)):

			if not dp.at_war(a, x) and dp.at_war(t, x):
				_n("join_abandoned")
				dp.add_opinion(t, a, -20)
				gw.news_m(Loc.mk("ПРЕДАТЕЛЬСТВО: %s ПОЗВАЛА СТРАНУ %s В ВОЙНУ ПРОТИВ: %s И САМА ВЫШЛА ИЗ НЕЁ", [Loc.name(_cn(a)).to_upper(), Loc.name(_cn(t)).to_upper(), Loc.name(_cn(x)).to_upper()]), "alert_red")
				gw.say(t, Loc.mk("%s бросает вас: позвала в войну со страной %s и сама вышла из неё", [Loc.name(_cn(a)), Loc.name(_cn(x))]))
				incite.erase(k)
			elif now - float(e["t"]) >= INCITE_T or not dp.at_war(t, x):
				incite.erase(k)
			continue
		if betray:
			_n("incite_betrayed")
			dp.add_opinion(t, a, -30)
			if dp.care != null:
				dp.care.on_treachery(a)
			gw.news_m(Loc.mk("ПРЕДАТЕЛЬСТВО: %s ВТЯГИВАЕТ В ВОЙНУ ДРУГИХ (%s ПРОТИВ: %s) И САМА ПОДПИСЫВАЕТ ДОГОВОР С ВРАГОМ", [Loc.name(_cn(a)).to_upper(), Loc.name(_cn(t)).to_upper(), Loc.name(_cn(x)).to_upper()]), "alert_red")
			gw.say(t, Loc.mk("%s предаёт вас: просила войны со страной %s, а сама подписывает с ней договор", [Loc.name(_cn(a)), Loc.name(_cn(x))]))
			incite.erase(k)
		elif now - float(e["t"]) >= INCITE_T:
			if not bool(e["hit"]) and not dp.at_war(a, x):
				dp.add_opinion(t, a, -10)
				_n("incite_idle")
			incite.erase(k)




func update(dt: float) -> void :
	if lab_off:
		return
	var now: float = gw.game_time
	for i in range(reqs.size() - 1, -1, -1):
		var r: Dictionary = reqs[i]
		if now >= float(r["until"]) or not _alive(int(r["from"])) or not _alive(int(r["to"])):
			reqs.remove_at(i)
			_n("expired")
			_log(int(r["from"]), int(r["to"]), String(r["kind"]), false)
			if String(r["kind"]) == "stop_war":
				_press_refused(int(r["from"]), int(r["to"]), int(r["x"]))
			gw.say(int(r["from"]), Loc.mk("Нет ответа от страны %s: %s", [Loc.name(_cn(int(r["to"]))), KIND_NAMES[String(r["kind"])].to_lower()]))
			dp.pending_changed.emit()
	_t += dt
	if _t >= TICK:
		_t = 0.0
		_tick_land()
		_anger()
	_think += dt
	if _think >= THINK:
		_think = 0.0
		_incite_tick()
		_press_tick()
		_bots_ask()


func save_state() -> Dictionary:
	return {"reqs": reqs.duplicate(true), "next_id": next_id, "cd": cd.duplicate(), "pn": pn.duplicate(), "hist": hist.duplicate(true), 
		"sent": sent.duplicate(true), "gain": gain.duplicate(true), "station": station.duplicate(true), "press": press.duplicate(true), 
		"press_done": press_done.duplicate(), "incite": incite.duplicate(true), "bot_next": bot_next.duplicate(), "war_on_t": war_on_t.duplicate(), 
		"war_on_map": war_on_map, "b2h": b2h.duplicate(true), "hits": hits.duplicate(true), "clash": clash.duplicate(), "anger_t": anger_t.duplicate(), 
		"counters": counters.duplicate(), "t": _t, "think": _think}


func load_state(d: Dictionary) -> void :
	reqs = []
	for v: Variant in (d.get("reqs", []) as Array):
		var r: Dictionary = v
		reqs.append({"id": int(r.get("id", 0)), "kind": String(r.get("kind", "war_on")), "from": int(r.get("from", 0)), "to": int(r.get("to", 0)), 
			"x": int(r.get("x", 0)), "made": float(r.get("made", 0.0)), "until": float(r.get("until", 0.0)), "n": int(r.get("n", 0))})
	next_id = int(d.get("next_id", 1))
	cd = {}
	for k: Variant in (d.get("cd", {}) as Dictionary):
		cd[String(k)] = float(d["cd"][k])
	pn = {}
	for k2: Variant in (d.get("pn", {}) as Dictionary):
		pn[String(k2)] = int(d["pn"][k2])
	hist = []
	for h: Variant in (d.get("hist", []) as Array):
		var ha: Array = h
		hist.append([float(ha[0]), int(ha[1]), int(ha[2]), int(ha[3]), int(ha[4])])
	sent = _times(d.get("sent", {}))
	b2h = _times(d.get("b2h", {}))
	hits = _times(d.get("hits", {}))
	gain = {}
	for k3: Variant in (d.get("gain", {}) as Dictionary):
		var g: Array = d["gain"][k3]
		gain[String(k3)] = [float(g[0]), int(g[1])]
	station = {}
	for k4: Variant in (d.get("station", {}) as Dictionary):
		var e: Dictionary = d["station"][k4]
		station[String(k4)] = {"kind": String(e.get("kind", "station")), "t": float(e.get("t", 0.0)), "until": float(e.get("until", -1.0)), "vs": int(e.get("vs", 0)), "fid": int(e.get("fid", -1)), "gid": int(e.get("gid", -1)), "ally": bool(e.get("ally", false))}
	press = {}
	for k5: Variant in (d.get("press", {}) as Dictionary):
		var p: Dictionary = d["press"][k5]
		press[String(k5)] = {"v": int(p.get("v", 0)), "step": int(p.get("step", 0)), "next": float(p.get("next", 0.0)), "emb": bool(p.get("emb", false)), "end": float(p.get("end", -1.0))}
	press_done = {}
	for k6: Variant in (d.get("press_done", {}) as Dictionary):
		press_done[String(k6)] = true
	incite = {}
	for k7: Variant in (d.get("incite", {}) as Dictionary):
		var ic: Dictionary = d["incite"][k7]
		incite[String(k7)] = {"a": int(ic.get("a", 0)), "t": float(ic.get("t", 0.0)), "hit": bool(ic.get("hit", false)), "j": bool(ic.get("j", false))}
	bot_next = {}
	for k8: Variant in (d.get("bot_next", {}) as Dictionary):
		bot_next[int(k8)] = float(d["bot_next"][k8])
	war_on_t = {}
	for k9: Variant in (d.get("war_on_t", {}) as Dictionary):
		war_on_t[int(k9)] = float(d["war_on_t"][k9])
	war_on_map = float(d.get("war_on_map", 0.0))
	clash = {}
	for k10: Variant in (d.get("clash", {}) as Dictionary):
		clash[int(k10)] = float(d["clash"][k10])
	anger_t = {}
	for k11: Variant in (d.get("anger_t", {}) as Dictionary):
		anger_t[String(k11)] = float(d["anger_t"][k11])
	counters = {}
	for k12: Variant in (d.get("counters", {}) as Dictionary):
		counters[String(k12)] = int(d["counters"][k12])
	_t = float(d.get("t", 0.0))
	_think = float(d.get("think", 0.0))
	_tick_land()


static func _times(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in (v as Dictionary):
		var a: Array = []
		for t: Variant in (v[k] as Array):
			a.append(float(t))
		out[int(k)] = a
	return out


func hash_nums() -> PackedFloat64Array:
	var out: = PackedFloat64Array()
	out.append(float(reqs.size()))
	out.append(float(next_id))
	var ks: Array = station.keys()
	ks.sort()
	out.append(float(ks.size()))
	for k: String in ks:
		out.append(float(hash(k)))
		out.append(float(roundi(float(station[k]["until"]))))
	var pk: Array = press.keys()
	pk.sort()
	for k2: String in pk:
		out.append(float(hash(k2)) + float(int(press[k2]["step"])))
	out.append(float(incite.size()))
	out.append(float(gp.size()))
	return out
