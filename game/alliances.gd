extends RefCounted

















const NAMES: Array = ["Северный пакт", "Южный блок", "Восточный альянс", "Западный договор", "Морской пакт", 
	"Степной блок", "Озёрный пакт", "Лесной альянс", "Речной договор", "Медовый пакт", "Вольный блок", 
	"Лига Трёх Рек", "Лига Побережья", "Лига Свободных Земель", "Лига Холмов", "Лига Равнин", 
	"Содружество Островов", "Содружество Долин", "Северное кольцо", "Щит Юга", "Кольцо Морей", 
	"Пакт Перевалов", "Альянс Рассвета", "Горный блок"]
const COLORS: Array = [Color("2fd8e6"), Color("ffb000"), Color("ff5fb0"), Color("a2e35f"), Color("c08cff"), 
	Color("e8564a"), Color("5f8bff"), Color("f2efe6")]
const COLOR_N: int = 8
const LOGOS: int = 10
const LOGO_NAMES: Array = ["звезда", "щит", "корона", "ель", "якорь", "волны", "башня", "солнце", "горы", "факел"]
const NAME_MAX: int = 22
const STYLE_T: float = 120.0
const MAX_SHARE: float = 0.55
const PAIR_SHARE: float = 0.66
const LEAVE_MIN_T: float = 300.0
const OFFER_T: float = 90.0
const ACCEPT_REL: int = 40
const SEEK_DT: float = 45.0
const SEEK_T0: float = 360.0
const THREAT_REL: int = 5
const STRONG_X: float = 1.6
const STRONG_SHARE: float = 0.35
const CALM_END: float = 600.0

var dp
var list: Dictionary = {}
var of: Dictionary = {}
var joined: Dictionary = {}
var offers: Array = []
var counters: Dictionary = {}
var _next: int = 1
var _oid: int = 1
var _seek_t: float = SEEK_T0
var _why: String = ""
var _offered: Dictionary = {}
const REOFFER_T: float = 900.0
var _vs: Dictionary = {}


func _init(d) -> void :
	dp = d


func id_of(c: int) -> int:
	return int(of.get(c, -1))


func same(a: int, b: int) -> bool:
	return a != b and id_of(a) >= 0 and id_of(a) == id_of(b)


func get_a(aid: int) -> Dictionary:
	return list.get(aid, {})


func of_country(c: int) -> Dictionary:
	return list.get(id_of(c), {})


func name_of(c: int) -> String:
	return String(of_country(c).get("name", ""))


func color(a: Dictionary) -> Color:
	return COLORS[clampi(int(a.get("ci", 0)), 0, COLOR_N - 1)]


func _cnt(k: String) -> void :
	counters[k] = int(counters.get(k, 0)) + 1


func _alive_n() -> int:
	var n: int = 0
	for c: Country in dp.gw.countries:
		if not c.eliminated and c.capital_id >= 0:
			n += 1
	return n


func cap() -> int:
	return clampi(int(float(_alive_n()) * 0.4 + 0.5), 2, 4)


func _human(c: int) -> bool:
	var cc: Country = dp.gw.country_by_id(c)
	return cc != null and cc.is_player





func join_reason(joiner: int, partner: int) -> String:
	if not GameConfig.alliances:
		return Loc.t("альянсы выключены в настройках матча")
	if joiner == partner or not dp._alive(joiner) or not dp._alive(partner):
		return Loc.t("страны нет")
	var aj: int = id_of(joiner)
	var ap: int = id_of(partner)
	if aj >= 0 and aj == ap:
		return Loc.t("уже в одном альянсе")
	if aj >= 0 and ap >= 0:
		return Loc.t("%s уже в альянсе «%s»") % [dp._cname(partner), String(list[ap]["name"])]
	if dp.at_war(joiner, partner):
		return Loc.t("сначала заключите мир")
	var aid: int = aj if aj >= 0 else ap
	var newc: int = partner if aj >= 0 else joiner
	var mem: Array = [joiner, partner]
	if aid >= 0:
		var a: Dictionary = list[aid]
		mem = (a["members"] as Array).duplicate()
		var vs: Dictionary = a.get("vs", {})
		if not vs.is_empty() and String(vs.get("kind", "")) != "ally" and int(vs["id"]) == newc:
			return Loc.t("альянс «%s» создан против %s") % [String(a["name"]), dp._cname(newc)]
		if mem.size() + 1 > cap():
			_cnt("refused_cap")
			return Loc.t("альянс «%s» полон (%d из %d)") % [String(a["name"]), mem.size(), cap()]
		for m: int in mem:
			if dp.at_war(m, newc):
				return Loc.t("воюет с членом альянса %s") % dp._cname(m)
			if dp.relation(m, newc) < -20:
				return Loc.t("член альянса %s против (отношения %d)") % [dp._cname(m), dp.relation(m, newc)]
		mem.append(newc)
	if dp.get("rift") != null:
		for m3: int in mem:
			if m3 == newc:
				continue
			var rg: String = dp.rift.tie_gate(m3, newc)
			if rg == "":
				rg = dp.rift.tie_gate(newc, m3)
			if rg != "":
				_cnt("refused_rift")
				return rg
	var tot: float = 0.0
	for c: Country in dp.gw.countries:
		if not c.eliminated and c.capital_id >= 0:
			tot += dp.strength(c.id)
	if _alive_n() >= 4 and tot > 0.0:
		var s: float = 0.0
		for m2: int in mem:
			s += dp.strength(m2)
		if s > tot * (MAX_SHARE if mem.size() >= 3 else PAIR_SHARE):
			_cnt("refused_share")
			return Loc.t("альянс стал бы слишком сильным (%d%% мировой силы)") % int(s / tot * 100.0)
	return ""



func ai_reason(ai: int, other: int) -> String:
	var nm: String = dp._cname(ai)
	if dp.care != null and dp.care.traitor(other):
		return Loc.t("%s не верит: недавно был нарушен пакт") % nm
	if dp.grudge(ai, other) or not dp.at_peace_long(ai, other):
		return Loc.t("%s помнит войну") % nm
	if dp.subject_of(ai) == other:
		return Loc.t("%s — ваш%s: и так воюет на вашей стороне") % [nm, Loc.t("а марионетка") if dp.subject_kind(ai) == "puppet" else Loc.t(" вассал")]
	if dp.is_subject(ai):
		return Loc.t("внешнюю политику %s решает %s") % [nm, dp._cname(dp.subject_of(ai))]
	if dp.get("rift") != null:
		var rg: String = dp.rift.tie_gate(ai, other)
		if rg != "":
			return rg
	var need: int = 20 if dp._common_enemy(ai, other) else ACCEPT_REL
	var tn: Array = dp.rift.tie_need(ai, other) if dp.get("rift") != null else [0, -1]
	need += int(tn[0])
	if dp.relation(ai, other) < need:
		if int(tn[0]) > 0:
			return Loc.t("%s отказывает: отношения %d, нужно от %d (+%d: её союзник — страна %s — с вами не ладит)") % [nm, dp.relation(ai, other), need, int(tn[0]), dp._cname(int(tn[1]))]
		return Loc.t("%s отказывает: отношения %d, нужно от %d") % [nm, dp.relation(ai, other), need]
	return ""




func _found(a: int, b: int) -> int:
	var aid: int = _next
	_next += 1
	var founder: int = b if _human(b) and not _human(a) else a
	var h: int = absi(Hash32.h2(aid * 31 + a, b, 977))
	list[aid] = {"id": aid, "name": _free_name(h), "ci": _free_color(h), "logo": h % LOGOS, "members": [a, b], 
		"founded": dp.gw.game_time, "founder": founder, "styled": not _human(founder), "vs": _vs.duplicate(), "calm_t": -1.0}
	for c: int in [a, b]:
		of[c] = aid
		joined[c] = dp.gw.game_time
	_cnt("formed")
	dp._reveal(a, b, true)
	dp.gw.news_m(Loc.mk("НОВЫЙ АЛЬЯНС «%s»: %s И %s%s", [String(list[aid]["name"]).to_upper(), Loc.name(dp._name(a)), Loc.name(dp._name(b)), (" — " + _why.to_upper()) if _why != "" else ""]), "intercept_cyan")
	dp.gw.relations_changed.emit()
	return aid


func _add(aid: int, c: int) -> void :
	var a: Dictionary = list[aid]
	if not (a["members"] as Array).has(c):
		(a["members"] as Array).append(c)
	of[c] = aid
	joined[c] = dp.gw.game_time
	_cnt("joined")
	dp.gw.news_m(Loc.mk("%s ВСТУПАЕТ В АЛЬЯНС «%s»%s", [Loc.name(dp._name(c)), String(a["name"]).to_upper(), (" — " + _why.to_upper()) if _why != "" else ""]), "intercept_cyan")
	dp.gw.relations_changed.emit()


func leave(c: int, why: String) -> void :
	var aid: int = id_of(c)
	if aid < 0:
		return
	var a: Dictionary = list[aid]
	var was: Array = (a["members"] as Array).duplicate()
	(a["members"] as Array).erase(c)
	of.erase(c)
	joined.erase(c)
	_cnt("left")
	for m0: int in was:
		if m0 != c:
			dp.close_land(c, m0)
	if dp._alive(c):
		dp.gw.news_m(Loc.mk("%s ПОКИДАЕТ АЛЬЯНС «%s»%s", [Loc.name(dp._name(c)), String(a["name"]).to_upper(), (": " + why) if why != "" else ""]), "amber")
	if int(a.get("founder", -1)) == c and not (a["members"] as Array).is_empty():
		a["founder"] = int(a["members"][0])
		a["styled"] = true
	if (a["members"] as Array).size() < 2:
		_dissolve(aid, "")
	dp.gw.relations_changed.emit()



func drop(c: int) -> void :
	var aid: int = id_of(c)
	of.erase(c)
	joined.erase(c)
	if aid < 0 or not list.has(aid):
		return
	var a: Dictionary = list[aid]
	(a["members"] as Array).erase(c)
	if int(a.get("founder", -1)) == c and not (a["members"] as Array).is_empty():
		a["founder"] = int(a["members"][0])
		a["styled"] = true
	if (a["members"] as Array).size() < 2:
		_dissolve(aid, "")


func _dissolve(aid: int, why: String) -> void :
	var a: Dictionary = list[aid]
	for m: int in (a["members"] as Array):
		of.erase(m)
		joined.erase(m)
	list.erase(aid)
	var mem: Array = a["members"]
	for i0 in mem.size():
		for j0 in range(i0 + 1, mem.size()):
			dp.close_land(int(mem[i0]), int(mem[j0]))
	for i in range(offers.size() - 1, -1, -1):
		if int(offers[i]["aid"]) == aid:
			offers.remove_at(i)
	_cnt("dissolved")
	dp.gw.news_m(Loc.mk("АЛЬЯНС «%s» %s", [String(a["name"]).to_upper(), (Loc.t("РАСПУЩЕН: ") + why) if why != "" else Loc.t("РАСПАЛСЯ")]), "amber")
	dp.gw.relations_changed.emit()


func _free_name(h: int) -> String:
	var used: Dictionary = {}
	for a: Dictionary in list.values():
		used[String(a["name"])] = true
	for i in NAMES.size():
		var n: String = String(NAMES[(h + i) % NAMES.size()])
		if not used.has(n):
			return n
	return Loc.t("Альянс %d") % _next


func _free_color(h: int) -> int:
	var used: Dictionary = {}
	for a: Dictionary in list.values():
		used[int(a["ci"])] = true
	for i in COLOR_N:
		if not used.has((h + i) % COLOR_N):
			return (h + i) % COLOR_N
	return h % COLOR_N




func on_war(a: int, b: int) -> void :
	var aid: int = id_of(b)
	if aid < 0:
		return
	var ca: Country = dp.gw.country_by_id(a)
	for m: int in (list[aid]["members"] as Array).duplicate():
		if m == b or m == a or same(m, a) or dp.at_war(m, a) or dp.conf_lock(m, a) or not dp._alive(m):
			continue
		if dp.allied(m, a):
			_cnt("war_skip_pair_ally")
			continue
		if not dp.gw.country_by_id(m).is_player and dp.pile_gate(m, a, b, false) != "":
			_cnt("war_wait_pile")
			continue
		dp._set_rel(m, a, Diplomacy.Rel.WAR)
		dp._war_cleanup(m, a)
		dp.war_by[Diplomacy.key(m, a)] = a
		_cnt("war_joined")
		dp._count("joined_alliance")
		dp.dlog(m, "вступает за %s против %s" % [dp._cname(b), dp._cname(a)], "альянс «%s» (обязательно)" % String(list[aid]["name"]), 0.0, ["join", b, a])
		dp.gw.news_m(Loc.mk("%s ВСТУПАЕТ В ВОЙНУ НА СТОРОНЕ %s: АЛЬЯНС «%s»", [Loc.name(dp._name(m)), Loc.name(dp._name(b)), String(list[aid]["name"]).to_upper()]), "alert_red")
		var cm: Country = dp.gw.country_by_id(m)
		if cm.is_player:
			dp.gw.say(cm, Loc.mk("Альянс «%s»: на %s напала %s — вы вступаете в войну", [String(list[aid]["name"]), Loc.name(dp._cname(b)), Loc.name(ca.name)]))
			dp.gw.war_declared.emit(m, a)
		elif ca.is_player:
			dp.gw.war_declared.emit(m, a)





func cmd_found(cid: int, partner: int) -> String:
	if id_of(cid) >= 0:
		return Loc.t("Вы уже в альянсе: пригласите %s") % dp._cname(partner)
	if id_of(partner) >= 0:
		return Loc.t("%s уже в альянсе «%s»: попросите вступить") % [dp._cname(partner), name_of(partner)]
	return _ask("found", cid, partner, -1)



func cmd_invite(cid: int, target: int) -> String:
	var aid: int = id_of(cid)
	if aid < 0:
		return Loc.t("Вы не в альянсе")
	return _ask("invite", cid, target, aid)



func cmd_join(cid: int, aid: int) -> String:
	if not list.has(aid):
		return Loc.t("Альянса нет")
	if id_of(cid) >= 0:
		return Loc.t("Сначала выйдите из своего альянса")
	return _ask("join", cid, int(list[aid]["founder"]), aid)


func _ask(kind: String, from: int, to: int, aid: int) -> String:
	var jr: String = join_reason(from, to)
	if jr != "":
		return Loc.t("Альянс невозможен: %s") % [jr]
	for o: Dictionary in offers:
		if int(o["from"]) == from and int(o["to"]) == to:
			return Loc.t("%s ещё не ответила") % dp._cname(to)
	dp._reveal(from, to)
	if _human(to):
		offers.append({"id": _oid, "kind": kind, "from": from, "to": to, "aid": aid, "until": dp.gw.game_time + OFFER_T})
		_oid += 1
		dp.gw.say(to, "%s: %s" % [dp._cname(from), _offer_text(offers[offers.size() - 1])])
		dp.gw.offer_received.emit()
		dp.pending_changed.emit()
		return "sent"
	var why: String = ai_reason(to, from)
	if why != "":
		dp.add_opinion(from, to, -2)
		return why
	_do(kind, from, to, aid)
	return ""


func _do(kind: String, from: int, to: int, aid: int) -> void :
	match kind:
		"found":
			_found(from, to)
		"invite":
			_add(aid, to)
		"join":
			_add(aid, from)
	dp.add_opinion(from, to, 5)


func _offer_text(o: Dictionary) -> String:
	match String(o["kind"]):
		"found":
			return Loc.t("предлагает основать альянс")
		"invite":
			return Loc.t("зовёт в альянс «%s»") % String(list.get(int(o["aid"]), {}).get("name", "?"))
		"join":
			return Loc.t("просится в ваш альянс «%s»") % String(list.get(int(o["aid"]), {}).get("name", "?"))
	return Loc.t("альянс")



func cmd_answer(cid: int, oid: int, yes: bool) -> String:
	for i in offers.size():
		var o: Dictionary = offers[i]
		if int(o["id"]) != oid:
			continue
		if int(o["to"]) != cid:
			return Loc.t("Не вам")
		offers.remove_at(i)
		dp.pending_changed.emit()
		if not yes:
			dp.add_opinion(int(o["from"]), cid, -5)
			dp.gw.say(int(o["from"]), Loc.mk("%s отклоняет: альянс", [Loc.name(dp._cname(cid))]))
			return ""
		var aid: int = int(o["aid"])
		if String(o["kind"]) != "found" and not list.has(aid):
			return Loc.t("Альянса больше нет")
		if String(o["kind"]) == "found" and (list.has(id_of(int(o["from"]))) or list.has(id_of(cid))):
			return Loc.t("Предложение устарело: уже в альянсе")
		var jr: String = join_reason(int(o["from"]), cid)
		if jr != "":
			return Loc.t("Альянс невозможен: %s") % [jr]
		_do(String(o["kind"]), int(o["from"]), cid, aid)
		dp.gw.say(int(o["from"]), Loc.mk("%s принимает: альянс", [Loc.name(dp._cname(cid))]))
		return ""
	return Loc.t("Предложение устарело")


func offer_to(oid: int) -> int:
	for o: Dictionary in offers:
		if int(o["id"]) == oid:
			return int(o["to"])
	return -1



func pending(now: float) -> Array:
	var out: Array = []
	var p: Country = dp.gw.player
	if p == null:
		return out
	for o: Dictionary in offers:
		if int(o["to"]) != p.id:
			continue
		out.append({"id": "y%d" % int(o["id"]), "from": int(o["from"]), "kind": "alliance", "icon": "icon_map_alliance", 
			"text": "%s %s" % [dp._cname(int(o["from"])), _offer_text(o)], "what": Loc.t("АЛЬЯНС"), 
			"eff": Loc.t("%s: полный проход по земле, нападут на одного — война для всех") % _offer_text(o), 
			"deadline": float(o["until"]), "left": maxf(0.0, float(o["until"]) - now), 
			"options": [{"act": "accept", "label": Loc.t("ПРИНЯТЬ")}, {"act": "refuse", "label": Loc.t("ОТКАЗАТЬ")}]})
	return out


func style(cid: int, aid: int, nm: String, ci: int, logo: int) -> String:
	var a: Dictionary = list.get(aid, {})
	if a.is_empty():
		return Loc.t("Альянса нет")
	if int(a.get("founder", -1)) != cid:
		return Loc.t("Название выбирает основатель")
	var n: String = nm.strip_edges().left(NAME_MAX)
	if n == "":
		return Loc.t("Нужно название")
	a["name"] = n
	a["ci"] = clampi(ci, 0, COLOR_N - 1)
	a["logo"] = clampi(logo, 0, LOGOS - 1)
	a["styled"] = true
	dp.gw.news_m(Loc.mk("АЛЬЯНС «%s» (%s)", [n.to_upper(), ", ".join(_member_names(a))]), "intercept_cyan")
	dp.gw.relations_changed.emit()
	return ""


func cmd_leave(cid: int) -> String:
	if id_of(cid) < 0:
		return Loc.t("Вы не в альянсе")
	leave(cid, "")
	return ""


func kick(cid: int, aid: int, target: int) -> String:
	var a: Dictionary = list.get(aid, {})
	if a.is_empty() or int(a.get("founder", -1)) != cid or target == cid or id_of(target) != aid:
		return Loc.t("Нельзя")
	dp.add_opinion(cid, target, -25)
	leave(target, Loc.t("исключена"))
	return ""


func _member_names(a: Dictionary) -> PackedStringArray:
	var out: = PackedStringArray()
	for m: int in (a["members"] as Array):
		out.append(dp._cname(m))
	return out


func needs_style(cid: int) -> int:
	for a: Dictionary in list.values():
		if not bool(a.get("styled", true)) and int(a.get("founder", -1)) == cid:
			return int(a["id"])
	return -1




func tick() -> void :
	var now: float = dp.gw.game_time
	for i in range(offers.size() - 1, -1, -1):
		var o: Dictionary = offers[i]
		if now > float(o["until"]) or not dp._alive(int(o["from"])) or not dp._alive(int(o["to"])):
			offers.remove_at(i)
			dp.pending_changed.emit()
	for a: Dictionary in list.values():
		if not bool(a.get("styled", true)) and now - float(a["founded"]) > STYLE_T:
			a["styled"] = true
	_repair()
	_calm_check(now)
	_bot_leave(now)
	if now >= _seek_t:
		_seek_t = now + SEEK_DT
		_bot_seek(now)




func _repair() -> void :
	for aid: int in list.keys():
		if not list.has(aid):
			continue
		for m: int in (list[aid]["members"] as Array).duplicate():
			if not list.has(aid):
				break
			if not dp._alive(m) or id_of(m) != aid:
				_cnt("repair")
				if id_of(m) == aid:
					drop(m)
				else:
					(list[aid]["members"] as Array).erase(m)
					if (list[aid]["members"] as Array).size() < 2:
						_dissolve(aid, "")
	for c: Variant in of.keys():
		if not list.has(int(of[c])) or not (list[int(of[c])]["members"] as Array).has(int(c)):
			of.erase(c)
			_cnt("repair")
	for aid2: int in list.keys():
		if not list.has(aid2):
			continue
		var mem: Array = list[aid2]["members"]
		for i in mem.size():
			for j in range(i + 1, mem.size()):
				if dp.at_war(int(mem[i]), int(mem[j])):
					var late: int = int(mem[i]) if float(joined.get(int(mem[i]), 0.0)) > float(joined.get(int(mem[j]), 0.0)) else int(mem[j])
					leave(late, Loc.t("война внутри альянса"))
					return


func _calm_check(now: float) -> void :
	for aid: int in list.keys():
		var a: Dictionary = list[aid]
		var human: bool = false
		for m: int in (a["members"] as Array):
			if _human(m):
				human = true
		if human or _threat_alive(a):
			a["calm_t"] = -1.0
			continue
		if float(a.get("calm_t", -1.0)) < 0.0:
			a["calm_t"] = now
		elif now - float(a["calm_t"]) > CALM_END:
			_cnt("calm_dissolved")
			dp.dlog(int(a["members"][0]), "альянс «%s» распущен" % String(a["name"]), "угроза миновала", 0.0, ["ally", "calm", aid])
			_dissolve(aid, Loc.t("УГРОЗА МИНОВАЛА"))
			return


func _bot_leave(now: float) -> void :
	for aid: int in list.keys():
		var mem: Array = list[aid]["members"]
		for c: int in mem:
			var cc: Country = dp.gw.country_by_id(c)
			if cc == null or cc.is_player or now - float(joined.get(c, 0.0)) < LEAVE_MIN_T:
				continue
			var why: String = ""
			for m: int in mem:
				if m != c and dp.relation(c, m) < -10:
					why = Loc.t("ссора с %s") % dp._cname(m)
					break
			if why == "" and cc.at_war.size() >= 2 and dp._losing_badly(c) and float(dp._p(c)["caution"]) > 0.5:
				why = Loc.t("не выдерживает войн альянса")
			if why != "":
				dp.dlog(c, "выходит из альянса %s" % String(list[aid]["name"]), why, 0.0, ["ally", "leave", aid])
				leave(c, why)
				return







func threats_to(c: int) -> Array:
	var out: Array = []
	var s1: int = _strongest()
	if s1 > 0 and s1 != c and not same(s1, c):
		out.append({"kind": "strong", "id": s1, "why": "против сильного %s" % dp._cname(s1)})
	for aid: int in list:
		if aid == id_of(c):
			continue
		var near: bool = false
		var st: float = 0.0
		for m: int in (list[aid]["members"] as Array):
			st += dp.strength(m)
			if dp.neighbours(c, m):
				near = true
		if near and st >= dp.strength(c):
			out.append({"kind": "ally", "id": aid, "why": "против альянса «%s»" % String(list[aid]["name"])})
	for o: Country in dp.gw.countries:
		if o.id == c or o.eliminated or not dp.neighbours(c, o.id) or same(c, o.id):
			continue
		var attacked: int = 0
		for e: Variant in o.at_war:
			if int(dp.war_by.get(Diplomacy.key(o.id, int(e)), 0)) == o.id:
				attacked += 1
		if attacked >= 2:
			out.append({"kind": "aggr", "id": o.id, "why": "против агрессора %s" % dp._cname(o.id)})
	if dp.gw.get("drama") != null:
		out.append_array(dp.gw.drama.ally_threats(c))
	return out


func _strongest() -> int:
	var best: int = 0
	var b1: float = 0.0
	var b2: float = 0.0
	var tot: float = 0.0
	for c: Country in dp.gw.countries:
		if c.eliminated or c.capital_id < 0:
			continue
		var s: float = dp.strength(c.id)
		tot += s
		if s > b1:
			b2 = b1
			b1 = s
			best = c.id
		elif s > b2:
			b2 = s
	if best > 0 and _alive_n() >= 3 and (b1 >= b2 * STRONG_X or b1 >= tot * STRONG_SHARE):
		return best
	return 0


func _threat_side(c: int, t: Dictionary) -> bool:
	if String(t["kind"]) == "ally":
		return id_of(c) == int(t["id"])
	return c == int(t["id"]) or same(c, int(t["id"]))


func _faces(o: int, t: Dictionary) -> bool:
	if _threat_side(o, t):
		return false
	match String(t["kind"]):
		"strong":
			return true
		"ally":
			for m: int in (list[int(t["id"])]["members"] as Array):
				if dp.neighbours(o, m):
					return true
			return false
		"aggr":
			return dp.neighbours(o, int(t["id"])) or dp.at_war(o, int(t["id"]))
		"drama":
			return dp.gw.get("drama") != null and dp.gw.drama.faces(o, int(t["id"]))
	return false


func _threat_alive(a: Dictionary) -> bool:
	var vs: Dictionary = a.get("vs", {})
	if vs.is_empty():
		return true
	match String(vs.get("kind", "")):
		"strong":
			return _strongest() == int(vs["id"])
		"ally":
			return list.has(int(vs["id"]))
		"aggr":
			var c: Country = dp.gw.country_by_id(int(vs["id"]))
			return c != null and not c.eliminated and c.at_war.size() >= 1
		"drama":
			return dp.gw.get("drama") != null and dp.gw.drama.threat_alive(int(vs["id"]))
	return false


func _fit(c: int, o: int) -> int:
	var mem: Array = [c]
	var aid: int = id_of(c) if id_of(c) >= 0 else id_of(o)
	if aid >= 0:
		mem = (list[aid]["members"] as Array).duplicate()
		if not mem.has(c):
			mem.append(c)
	var low: int = 100
	for m: int in mem:
		if m != o:
			low = mini(low, dp.relation(m, o))
	if dp.grudge(c, o):
		return -1
	return low - THREAT_REL + (10 if dp.neighbours(c, o) else 0)



func bot_reason(ai: int, other: int) -> String:
	if dp.care != null and dp.care.traitor(other):
		return Loc.t("предатель")
	if dp.grudge(ai, other) or not dp.at_peace_long(ai, other) or dp.is_subject(ai) or dp.is_subject(other):
		return Loc.t("память войны")
	if dp.relation(ai, other) < THREAT_REL:
		return Loc.t("отношения")
	return join_reason(other, ai)




func _bot_seek(now: float) -> void :
	if not GameConfig.alliances:
		return
	var alive: Array = []
	for c: Country in dp.gw.countries:
		if not c.eliminated and c.capital_id >= 0:
			alive.append(c)
	if alive.size() < 3:
		return
	var n: int = alive.size()
	var start: int = absi(Hash32.h2(int(now), n, 4211)) % n
	for i in n:
		var c: Country = alive[(start + i) % n]
		if c.is_player or dp.is_subject(c.id):
			continue
		for t: Dictionary in threats_to(c.id):
			var best: int = -1
			var best_v: int = -999
			for o: Country in alive:
				if o.id == c.id or dp.at_war(c.id, o.id) or same(c.id, o.id) or not _faces(o.id, t):
					continue
				if id_of(c.id) >= 0 and id_of(o.id) >= 0:
					continue
				var v: int = _fit(c.id, o.id)
				if v > best_v:
					best_v = v
					best = o.id
			if best < 0 or best_v < 0 or join_reason(c.id, best) != "":
				continue
			if _human(best):
				var ok_t: bool = now - float(_offered.get("%d>%d" % [c.id, best], -1000000000.0)) >= REOFFER_T
				if ok_t and offers.is_empty() and now >= dp._player_offer_t:
					_offered["%d>%d" % [c.id, best]] = now
					dp._player_offer_t = now + dp.PLAYER_OFFER_GAP
					_vs = t.duplicate()
					var kind: String = "invite" if id_of(c.id) >= 0 else ("join" if id_of(best) >= 0 else "found")
					var r: String = _ask(kind, c.id, best, id_of(c.id)) if kind != "join" else ""
					_vs = {}
					if r == "sent":
						_cnt("offered_player")
						dp.dlog(c.id, "предлагает альянс человеку %s" % dp._cname(best), String(t["why"]), 0.0, ["ally", "offer", best])
						return
				continue
			if bot_reason(best, c.id) != "" or bot_reason(c.id, best) != "":
				continue
			_cnt("bot_" + String(t["kind"]))
			_why = String(t["why"])
			_vs = t.duplicate()
			dp.dlog(c.id, "альянс с %s" % dp._cname(best), String(t["why"]), float(best_v), ["ally", String(t["kind"]), int(t["id"])])
			if id_of(c.id) >= 0:
				_add(id_of(c.id), best)
			elif id_of(best) >= 0:
				_add(id_of(best), c.id)
			else:
				_found(c.id, best)
			_why = ""
			_vs = {}
			return




func save() -> Dictionary:
	return {"list": list.duplicate(true), "joined": joined.duplicate(), "next": _next, "oid": _oid, "offers": offers.duplicate(true), 
		"counters": counters.duplicate(), "seek_t": _seek_t, "offered": _offered.duplicate()}



func load_from(d: Dictionary) -> void :
	list = {}
	of = {}
	joined = {}
	offers = []
	counters = d.get("counters", {})
	_next = int(d.get("next", 1))
	_oid = int(d.get("oid", 1))
	_seek_t = float(d.get("seek_t", SEEK_T0))
	_offered = {}
	for k3: Variant in (d.get("offered", {}) as Dictionary):
		_offered[String(k3)] = float(d["offered"][k3])
	for k: Variant in (d.get("list", {}) as Dictionary):
		var a: Dictionary = d["list"][k]
		var mem: Array = []
		for m: Variant in (a.get("members", []) as Array):
			mem.append(int(m))
		a["members"] = mem
		a["id"] = int(k)
		a["ci"] = int(a.get("ci", 0))
		a["logo"] = int(a.get("logo", 0))
		a["founder"] = int(a.get("founder", -1))
		a["founded"] = float(a.get("founded", 0.0))
		a["calm_t"] = float(a.get("calm_t", -1.0))
		var vs: Dictionary = a.get("vs", {})
		if not vs.is_empty():
			vs["id"] = int(vs.get("id", 0))
		a["vs"] = vs
		list[int(k)] = a
		for m2: int in mem:
			of[m2] = int(k)
	for k2: Variant in (d.get("joined", {}) as Dictionary):
		joined[int(k2)] = float(d["joined"][k2])
	for o: Variant in (d.get("offers", []) as Array):
		var od: Dictionary = o
		for f: String in ["id", "from", "to", "aid"]:
			od[f] = int(od.get(f, -1))
		od["until"] = float(od.get("until", 0.0))
		offers.append(od)
