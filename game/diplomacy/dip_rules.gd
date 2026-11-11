extends "res://game/diplomacy/dip_base.gd"


func _set_rel(a: int, b: int, r: int) -> void :
	var k: String = key(a, b)
	var prev: int = int(rel.get(k, Rel.PEACE))
	rel[k] = r
	since[k] = gw.game_time
	var ca: Country = gw.country_by_id(a)
	var cb: Country = gw.country_by_id(b)
	if ca == null or cb == null:
		return
	if r == Rel.WAR:
		ca.at_war[b] = true
		cb.at_war[a] = true
	else:
		ca.at_war.erase(b)
		cb.at_war.erase(a)
	if r == Rel.TRUCE:
		truce_until[k] = gw.game_time + TRUCE_TIME
	if (prev == Rel.WAR or prev == Rel.TRUCE) and r != Rel.WAR:

		peace_t[k] = gw.game_time + (TRUCE_TIME if r == Rel.TRUCE else 0.0)
		calm_hits.erase("%d>%d" % [a, b])
		calm_hits.erase("%d>%d" % [b, a])
		_truce_warned.erase(k)
	if r == Rel.WAR:
		peace_t.erase(k)
	if r == Rel.ALLIANCE:
		_drop_covered_offers(a, b)
	if prev == Rel.WAR and r != Rel.WAR and gw.army != null:
		gw.army.on_ceasefire(a, b)
	gw.relations_changed.emit()





func _offense_ok(c: int, a: int, b: int) -> bool:
	var why: String = _offense_why(c, a, b)
	if why == "":
		return true
	dlog(c, "не идёт в нападение %s на %s" % [_cname(a), _cname(b)], why, 0.0, ["skip_off", a, b])
	_count("ally_skip_offense")
	var ca: Country = gw.country_by_id(a)
	if ca != null and ca.is_player and care != null:
		care.note(gw.country_by_id(c), "skip_off", _cname(b), "", a)
	return false


func _offense_why(c: int, a: int, b: int) -> String:
	var cc: Country = gw.country_by_id(c)
	if cc == null:
		return Loc.t("нет страны")
	if not cc.at_war.is_empty():
		return Loc.t("уже воюет")
	if has_treaty(c, b, "defense"):
		return Loc.t("оборонный пакт с %s") % _cname(b)
	if ally_of_ally(c, b) > 0:
		return Loc.t("%s — союзник нашего союзника %s") % [_cname(b), _cname(ally_of_ally(c, b))]
	if war_power(c) + war_power(a) < war_power(b) * 1.3:
		return Loc.t("мало сил против %s: %.0f против %.0f, нужно ×1,3") % [Loc.name(_cname(b)), war_power(c) + war_power(a), war_power(b)]
	if war_power(c) < war_power(b) * 0.5 and float(_p(c)["aggr"]) < 0.6:
		return Loc.t("сама вдвое слабее %s") % _cname(b)
	return ""



func break_alliance(a: int, b: int) -> void :
	if allied(a, b):
		_set_rel(a, b, Rel.PEACE)
		add_opinion(a, b, -40)
		dlog(a, "разрывает союз с %s" % _cname(b), "")
		gw.news_m(Loc.mk("СОЮЗ РАЗОРВАН: %s И %s", [Loc.name(_name(a)), Loc.name(_name(b))]), "amber")
		close_land(a, b)



func _ai_embargo(c: Country, P: Dictionary, h: int) -> void :
	for k: String in embargo.keys():
		var ab: PackedStringArray = k.split(">")
		if int(ab[0]) != c.id:
			continue
		var o: int = int(ab[1])
		var age: float = gw.game_time - float(embargo[k])
		if not _alive(o) or (age > lerpf(420.0, 180.0, float(P["trade"])) and relation(c.id, o) > -35 and h < 300 and not at_war(c.id, o) and _db(c.id, o, "sanction") < 0.3):
			set_embargo(c.id, o, false)



func _drift_tick() -> void :
	var alive: Array[Country] = []
	for c: Country in gw.countries:
		if not c.eliminated and c.capital_id >= 0:
			alive.append(c)
	var leader: int = int(coalition.get("leader", 0))
	for i in alive.size():
		for j in range(i + 1, alive.size()):
			var a: Country = alive[i]
			var b: Country = alive[j]
			var k: String = key(a.id, b.id)
			var r: int = get_rel(a.id, b.id)
			if r == Rel.WAR:
				good_since.erase(k)
				continue
			var op: int = get_opinion(a.id, b.id)
			var grd: bool = grudge(a.id, b.id)
			if op >= FRIEND_REL and not grd:
				if not good_since.has(k):
					good_since[k] = gw.game_time
			else:
				good_since.erase(k)
			var h: int = Hash32.h2(a.id * 64 + b.id, _tick_n, 77) % 6
			var v: int = 0
			var tr: Dictionary = treaties.get(k, {})
			if tr.has("visa") and op < 45 and h % 2 == 0:
				v += 1
			if r == Rel.ALLIANCE and op < 80:
				v += 1
			if gw.econ.trading(a.id, b.id) and op < 30 and h % 3 == 0:
				v += 1
			if _common_enemy(a.id, b.id) and op < 70:
				v += 1
			if embargo_between(a.id, b.id) and op > -80:
				v -= 1
			var calm: bool = tr.has("nap") or tr.has("visa") or r == Rel.ALLIANCE
			if _nb.has(k) and not calm and op > -60 and h == 0:
				var ag: float = maxf(float(_p(a.id)["aggr"]), float(_p(b.id)["aggr"]))
				if ag > 0.5:
					v -= 1
			if leader > 0:
				if (a.id == leader or b.id == leader) and op > -50 and h % 2 == 1:
					v -= 1
				elif a.id != leader and b.id != leader and op < 40 and h == 3:
					v += 1
			if v == 0 and h == 5:

				if op < 15:
					v = 1
				elif op > 30:
					v = -1
			if gw.pstat != null:
				v = gw.pstat.rival_bias(a.id, b.id, op, v, h)
			if gw.drama != null:
				v += gw.drama.drift(a.id, b.id, h, op)
			if v > 0 and grd and op >= (GRUDGE_CAP_AGGR if war_by.has(k) and _alive(int(war_by[k])) and get_rel(a.id, b.id) == Rel.TRUCE else GRUDGE_CAP):
				v = 0
			if v != 0:
				opinion[k] = clampi(op + v, -100, 100)


func has_treaty(a: int, b: int, kind: String) -> bool:
	if a == b:
		return false
	match kind:
		"alliance":
			return allied(a, b)
		"trade":
			return gw.econ != null and gw.econ.trading(a, b)
		"passage":
			return has_passage(a, b)
	return (treaties.get(key(a, b), {}) as Dictionary).has(kind)




func treaty_covered(a: int, b: int, kind: String) -> String:
	if a == b:
		return ""
	var vass: bool = subject_of(a) == b or subject_of(b) == a
	match kind:
		"nap", "defense":
			if allied(a, b):
				return Loc.t("союз")
			if vass:
				return Loc.t("вассалитет")
		"alliance":
			if vass:
				return Loc.t("вассалитет")
	return ""



func _drop_covered_offers(a: int, b: int) -> void :
	var n0: int = t_offers.size()
	for i in range(t_offers.size() - 1, -1, -1):
		var o: Dictionary = t_offers[i]
		var pair: bool = (int(o["from"]) == a and int(o["to"]) == b) or (int(o["from"]) == b and int(o["to"]) == a)
		if pair and treaty_covered(a, b, String(o["kind"])) != "":
			t_offers.remove_at(i)
	if t_offers.size() != n0:
		_count("offer_covered_dropped", n0 - t_offers.size())
		pending_changed.emit()



func treaties_of(a: int, b: int) -> Array:
	var out: Array = []
	for k: String in TREATY_KINDS:
		if has_treaty(a, b, k):
			out.append(k)
	return out



func trade_mul(buyer: int, seller: int) -> float:
	var m: float = 1.0
	if has_treaty(buyer, seller, "trade"):
		m -= 0.1
	if has_treaty(buyer, seller, "visa"):
		m -= 0.05
	return m



func ai_treaty_reason(ai: int, other: int, kind: String) -> String:
	var P: Dictionary = _p(ai)
	var rv: int = relation(ai, other)
	var need: int = int(TREATY_INFO[kind]["min_rel"])
	var ratio: float = strength(other) / maxf(1.0, strength(ai))
	var nm: String = _cname(ai)
	var common: bool = _common_enemy(ai, other)
	if not coalition.is_empty() and int(coalition["leader"]) == other and kind != "trade" and kind != "nap":
		return Loc.t("%s опасается вашей силы") % nm
	if kind != "trade" and kind != "visa" and care != null and care.traitor(other):
		return Loc.t("%s не верит: недавно был нарушен пакт") % nm
	var tn: Array = [0, -1]
	if kind == "alliance" or kind == "defense":
		var cf: String = ally_conflict(ai, other)
		if cf != "":
			return "%s: %s" % [nm, cf]
		if rift != null:
			var tg: String = rift.tie_gate(ai, other)
			if tg != "":
				return tg
			tn = rift.tie_need(ai, other)
	match kind:
		"trade":
			need -= int(float(P["trade"]) * 25.0)
		"visa":
			need += int(float(P["caution"]) * 15.0) - int(float(P["sneaky"]) * 15.0)
			if float(P["caution"]) > 0.7 and int(counters.get("inc_%d_%d" % [ai, other], 0)) > 0:
				return Loc.t("%s не откроет границу: ваши разведдроны уже попадались") % nm
		"nap":
			need -= int(float(P["caution"]) * 20.0) + int(float(P["sneaky"]) * 15.0)
			if ratio > 1.3:
				need -= 15
			if float(P["aggr"]) > 0.7 and ratio < 1.1:
				return Loc.t("%s: пакт со слабым не нужен") % nm
		"defense":
			need -= int(float(P["caution"]) * 10.0) + (25 if common else 0)
		"alliance":
			if common:
				need = mini(need, 15)
			need -= int(float(P["caution"]) * 5.0)
			if not at_peace_long(ai, other):
				return Loc.t("%s пока не доверяет вам: нужен долгий мир") % nm
	need += int(tn[0])
	if rv < need:
		if int(tn[0]) > 0:
			return Loc.t("%s отказывает: отношения %d, нужно от %d (+%d: её союзник — страна %s — с вами не ладит)") % [nm, rv, need, int(tn[0]), _cname(int(tn[1]))]
		return Loc.t("%s отказывает: отношения %d, нужно от %d") % [nm, rv, need]
	if (kind == "alliance" or kind == "defense" or kind == "nap") and grudge(ai, other):
		return Loc.t("%s помнит войну: пакт не раньше чем через %d с") % [nm, grudge_left(ai, other)]
	if (kind == "alliance" or kind == "defense") and not common:
		var need_t: float = ALLY_SUSTAIN if kind == "alliance" else DEFENSE_SUSTAIN
		var ft: float = friend_time(ai, other)
		if ft < need_t:
			return Loc.t("%s присматривается: нужна дружба (от %d) подольше — ещё %d с") % [nm, FRIEND_REL, ceili(need_t - ft)]
	return ""



func ally_conflict(a: int, b: int) -> String:
	for c: Country in gw.countries:
		if c.id == a or c.id == b or c.eliminated:
			continue
		if at_war(b, c.id) and (allied(a, c.id) or subject_of(c.id) == a):
			return Loc.t("воюет с нашим союзником %s") % c.name
		if at_war(a, c.id) and (allied(b, c.id) or subject_of(c.id) == b):
			return Loc.t("союзник нашего врага %s") % c.name
	return ""


func at_peace_long(a: int, b: int) -> bool:
	return get_rel(a, b) != Rel.WAR and gw.game_time - float(since.get(key(a, b), -999.0)) > 60.0


func _common_enemy(a: int, b: int) -> bool:
	for c: Country in gw.countries:
		if c.id != a and c.id != b and not c.eliminated and at_war(a, c.id) and at_war(b, c.id):
			return true
	return false



func cancel_treaty(a: int, b: int, kind: String) -> String:
	if kind == "passage":
		return cancel_passage(a, b)
	if not has_treaty(a, b, kind):
		return Loc.t("Нет такого договора")
	match kind:
		"alliance":
			break_alliance(a, b)
			return ""
		"trade":
			gw.econ.set_trade(a, b, false)
		_:
			var t: Dictionary = treaties.get(key(a, b), {})
			t.erase(kind)
			if t.is_empty():
				treaties.erase(key(a, b))
	add_opinion(a, b, - int(CANCEL_PENALTY.get(kind, 5)))
	_count("cancel_" + kind)
	dlog(a, "расторгает %s с %s" % [kind, _cname(b)], "")
	gw.news_m(Loc.mk("%s РАСТОРГНУТ: %s И %s", [String(TREATY_INFO[kind]["name"]), Loc.name(_name(a)), Loc.name(_name(b))]), "amber")
	if gw.player != null and b == gw.player.id:
		gw.say(gw.player, Loc.mk("%s расторгает: %s", [Loc.name(_cname(a)), String(TREATY_INFO[kind]["name"]).to_lower()]))
	gw.relations_changed.emit()
	return ""



func set_embargo(from: int, to: int, on: bool) -> String:
	var k: String = "%d>%d" % [from, to]
	if on == embargo.has(k):
		return ""
	if on:
		if from == to or not _alive(from) or not _alive(to):
			return Loc.t("Страны нет")
		embargo[k] = gw.game_time
		if gw.econ != null and gw.econ.trading(from, to):
			gw.econ.set_trade(from, to, false)
		add_opinion(from, to, -20)
		_count("embargo")
		gw.news_m(Loc.mk("ЭМБАРГО: %s → %s", [Loc.name(_name(from)), Loc.name(_name(to))]), "amber")
		gw.say(to, Loc.mk("%s ввела эмбарго: торговля с ней закрыта", [Loc.name(_cname(from))]))
	else:
		embargo.erase(k)
		add_opinion(from, to, 5)
		gw.news_m(Loc.mk("ЭМБАРГО СНЯТО: %s → %s", [Loc.name(_name(from)), Loc.name(_name(to))]), "grass_light")
	_reveal(from, to)
	gw.relations_changed.emit()
	return ""





func gift_gain(from: int, to: int, value: int) -> int:
	var ct: Country = gw.country_by_id(to)
	var gk: String = "%d>%d" % [from, to]
	var m: Array = gift_mem.get(gk, [0.0, 0.0])
	var r: float = float(m[1]) * maxf(0.0, 1.0 - (gw.game_time - float(m[0])) / GIFT_FORGET)
	var w: float = maxf(GIFT_W_MIN, float(ct.money) if ct != null else 0.0)
	var v: float = float(maxi(0, value))
	var g: float = GIFT_MAX * (r + v) / (r + v + w) - GIFT_MAX * r / (r + w)
	gift_mem[gk] = [gw.game_time, r + v]
	var cap: int = 100
	if grudge(from, to):
		var aggr: bool = int(war_by.get(key(from, to), 0)) == from
		g *= GRUDGE_MUL_AGGR if aggr else GRUDGE_MUL
		cap = GRUDGE_CAP_AGGR if aggr else GRUDGE_CAP
	var gi: int = int(floor(g + 0.5))
	return clampi(gi, 0, maxi(0, cap - get_opinion(from, to)))



func grudge(a: int, b: int) -> bool:
	var k: String = key(a, b)
	if get_rel(a, b) == Rel.WAR or get_rel(a, b) == Rel.TRUCE:
		return peace_t.has(k) or war_by.has(k) or get_rel(a, b) == Rel.TRUCE
	return peace_t.has(k) and gw.game_time < float(peace_t[k]) + GRUDGE_T


func grudge_left(a: int, b: int) -> int:
	var k: String = key(a, b)
	if not peace_t.has(k):
		return 0
	return maxi(0, ceili(float(peace_t[k]) + GRUDGE_T - gw.game_time))



func friend_time(a: int, b: int) -> float:
	var k: String = key(a, b)
	return gw.game_time - float(good_since[k]) if good_since.has(k) else 0.0

func _offer_treaty(from: int, to: int, kind: String) -> String:
	if treaty_covered(from, to, kind) != "":
		_count("offer_covered_blocked")
		return Loc.t("Не нужно: договор уже есть")
	for o: Dictionary in t_offers:
		if int(o["from"]) == from and int(o["to"]) == to:
			return Loc.t("%s ещё не ответил на прошлое предложение") % _cname(to)
	var rk: String = "%d>%d:%s" % [from, to, kind]
	var left: float = REOFFER_GAP - (gw.game_time - float(_t_offer_last.get(rk, -1000000000.0)))
	if left > 0.0:
		_count("reoffer_blocked")
		return Loc.t("То же предложение снова — через %d с") % ceili(left)
	_t_offer_last[rk] = gw.game_time
	dlog(from, "предлагает %s: %s" % [_cname(to), kind], "отношение %d" % relation(from, to))
	t_offers.append({"id": _dem_id, "from": from, "to": to, "kind": kind, "until": gw.game_time + 90.0})
	_dem_id += 1
	_count("offer_" + kind)
	_reveal(from, to)
	gw.say(to, Loc.mk("%s предлагает: %s", [Loc.name(_cname(from)), String(TREATY_INFO[kind]["name"])]))
	gw.offer_received.emit()
	pending_changed.emit()
	return ""





func _demand_text(d: Dictionary) -> Array:
	var who: String = _cname(int(d["from"]))
	var t: Array = Loc.mk("")
	var rn: Array = Loc.mk(String(Economy.RES_NAMES.get(String(d["res"]), "")).to_lower())
	match String(d["kind"]):
		"money":
			t = Loc.mk("%s требует %d денег", [who, int(d["n"])])
		"res":
			t = Loc.mk("%s требует %s ×%d", [who, rn, int(d["n"])])
		"deposit":
			t = Loc.mk("%s требует отдать землю с месторождением (%s)", [who, rn])
		"break_alliance":
			t = Loc.mk("%s требует разорвать союз (%s)", [who, _cname(int(d["third"]))])
		"cancel_visa":
			t = Loc.mk("%s требует отменить безвиз (%s)", [who, _cname(int(d["third"]))])
		"vassal", "puppet":
			t = Loc.mk("%s требует: станьте %s (дань %d %%)", [who, Loc.mk("вассалом") if String(d["kind"]) == "vassal" else Loc.mk("марионеткой"), roundi(float(TRIBUTE[String(d["kind"])]) * 100.0)])
	d["head"] = t
	return Loc.mk("%s. Иначе — %s", [t, Loc.mk("ВОЙНА") if String(d["conseq"]) == "war" else Loc.mk("ЭМБАРГО")])


func _make_demand(from: int, to: int, kind: String, params: Dictionary) -> Dictionary:
	var d: Dictionary = {"id": _dem_id, "from": from, "to": to, "kind": kind, "n": int(params.get("n", 0)), "res": String(params.get("res", "")), 
		"cell": params.get("cell", Vector2i(-1, -1)), "third": int(params.get("third", 0)), "conseq": String(params.get("conseq", "embargo")), 
		"made": gw.game_time, "until": gw.game_time + DEMAND_TIME}
	_dem_id += 1
	d["text"] = _demand_text(d)
	return d



func _demand_ok(d: Dictionary) -> String:
	var v: Country = gw.country_by_id(int(d["to"]))
	if v == null or not _alive(int(d["from"])):
		return Loc.t("Страны нет")
	match String(d["kind"]):
		"money":
			if v.money < int(d["n"]):
				return Loc.t("Не хватает денег: нужно %d") % int(d["n"])
		"res":
			if int(v.get(String(d["res"]))) < int(d["n"]):
				return Loc.t("Не хватает: %s %d") % [Loc.t(String(Economy.RES_NAMES.get(String(d["res"]), "")).to_lower()), int(d["n"])]
		"deposit":
			var cell: Vector2i = d["cell"]
			if not gw.data.inside(cell.x, cell.y) or gw.data.get_owner_id(cell.x, cell.y) != v.id:
				return Loc.t("Эта земля уже не ваша")
		"break_alliance":
			if not allied(v.id, int(d["third"])):
				return Loc.t("Союза уже нет")
		"cancel_visa":
			if not has_treaty(v.id, int(d["third"]), "visa"):
				return Loc.t("Безвиза уже нет")
		"vassal", "puppet":
			if is_subject(v.id) or is_subject(int(d["from"])):
				return Loc.t("Уже вассал")
	return ""


func _issue(d: Dictionary) -> void :
	dlog(int(d["from"]), "ультиматум %s: %s" % [_cname(int(d["to"])), String(d["kind"])], "последствие %s" % String(d.get("conseq", "")))
	demands.append(d)
	_pair_dem["%d>%d" % [int(d["from"]), int(d["to"])]] = gw.game_time
	_count("demand_" + String(d["kind"]))
	_count("demands")
	var to_p: bool = _human(int(d["to"]))
	if to_p:
		_count("demands_player")
		_player_dem_last = gw.game_time
	_reveal(int(d["from"]), int(d["to"]))
	gw.news_m(Loc.mk("%s ПРЕДЪЯВЛЯЕТ УЛЬТИМАТУМ: %s", [Loc.name(_name(int(d["from"]))), Loc.name(_name(int(d["to"])))]), "amber")
	if to_p:
		gw.say(int(d["to"]), Loc.mk("УЛЬТИМАТУМ: %s (%d с)", [d["text"], int(DEMAND_TIME)]))
		Sfx.ui("ui_alert")
		gw.offer_received.emit()
		pending_changed.emit()



func demand_options(from: int, to: int) -> Array:
	var out: Array = []
	var ct: Country = gw.country_by_id(to)
	if ct == null or not _alive(to) or at_war(from, to) or from == to:
		return out
	if ct.money >= 400:
		var n: int = clampi(int(float(ct.money) * 0.25 / 100.0) * 100, 300, 2000)
		out.append({"kind": "money", "label": Loc.t("ДЕНЬГИ"), "text": Loc.t("%d денег") % n, "params": {"n": n}})
	if gw.econ != null:
		var best: String = ""
		var bs: int = 9
		for res: String in Economy.TRADE_RES:
			var s: int = gw.econ.surplus(ct, res) if not ct.is_player else int(ct.get(res))
			if s > bs:
				bs = s
				best = res
		if best != "":
			var n2: int = mini(30, bs)
			out.append({"kind": "res", "label": Loc.t("РЕСУРС"), "text": "%s ×%d" % [Loc.t(String(Economy.RES_NAMES[best]).to_lower()), n2], "params": {"res": best, "n": n2}})
		var dep: Dictionary = border_deposit(to, from)
		if not dep.is_empty():
			out.append({"kind": "deposit", "label": Loc.t("ЗЕМЛЯ"), "text": Loc.t("земля с месторождением (%s)") % Loc.t(String(Economy.RES_NAMES.get(String(dep["res"]), "")).to_lower()), 
				"params": {"cell": dep["cell"], "res": String(dep["res"])}})
	for c: Country in gw.countries:
		if c.id == from or c.id == to or c.eliminated:
			continue
		if allied(to, c.id):
			out.append({"kind": "break_alliance", "label": Loc.t("РАЗРЫВ"), "text": Loc.t("разорвать союз (%s)") % c.name, "params": {"third": c.id}})
		if has_treaty(to, c.id, "visa"):
			out.append({"kind": "cancel_visa", "label": Loc.t("ВИЗЫ"), "text": Loc.t("отменить безвиз (%s)") % c.name, "params": {"third": c.id}})
	return out



func ai_yields(victim: int, demander: int, d: Dictionary) -> bool:
	if _demand_ok(d) != "":
		return false
	if String(d["kind"]) == "vassal" or String(d["kind"]) == "puppet":
		return ai_subject_yields(victim, demander, String(d["kind"]))
	var P: Dictionary = _p(victim)
	var ratio: float = strength(demander) / maxf(1.0, strength(victim))
	var threat: float = 1.0 if String(d["conseq"]) == "war" else 0.35
	var friends: int = 0
	for c: Country in gw.countries:
		if c.id != victim and c.id != demander and not c.eliminated and (has_treaty(victim, c.id, "defense") or allied(victim, c.id)):
			friends += 1
	var score: float = ratio * threat * (0.6 + float(P["caution"]) * 0.8) - float(P["aggr"]) * 0.5 - _demand_value(d, victim) * 0.8\
	- float(friends) * 0.2 + float(relation(victim, demander)) / 200.0
	return score > 0.7


func _demand_value(d: Dictionary, victim: int) -> float:
	var v: Country = gw.country_by_id(victim)
	var wealth: float = float(maxi(0, v.money) + 1000)
	match String(d["kind"]):
		"money":
			return float(d["n"]) / wealth
		"res":
			var pr: int = gw.econ.market_price(String(d["res"])) if gw.econ != null else 20
			return float(int(d["n"]) * pr) / wealth
		"deposit":
			var dp: Dictionary = gw.econ.deposit_at(d["cell"], 2) if gw.econ != null else {}
			return 0.5 + (0.3 if not dp.is_empty() and dp["taken_by"] != null else 0.0)
		"break_alliance":
			return 0.45
		"cancel_visa":
			return 0.25
	return 0.3




func cede_area(giver: int, taker: int, cell: Vector2i, r: int) -> void :
	var d: WorldData = gw.data
	var moved: Array[Vector2i] = []
	for y in range(maxi(1, cell.y - r), mini(d.h - 1, cell.y + r + 1)):
		for x in range(maxi(1, cell.x - r), mini(d.w - 1, cell.x + r + 1)):
			var i: int = y * d.w + x
			if d.owners[i] != giver or d.has_flag(x, y, WorldData.F_CITY):
				continue
			d.owners[i] = taker
			if (x + y) % 3 == 0:
				moved.append(Vector2i(x, y))
	d.owners_dirty = true
	if gw.player != null and (giver == gw.player.id or taker == gw.player.id) and not moved.is_empty():
		Sfx.ui("territory_claim")
	if gw.top != null and gw.top.has_method("flash_cells"):
		gw.top.flash_cells(moved)
	gw._checkpoints_dirty = true
	for f: Facility in gw.mil.facilities:
		if f.country_id != giver:
			continue
		var host: Facility = f.parent if f.parent != null else f
		var hc: Vector2i = host.cell + host.size / 2
		if d.inside(hc.x, hc.y) and d.get_owner_id(hc.x, hc.y) == taker:
			f.country_id = taker
			f.queued.clear()
	if gw.econ != null:
		gw.econ.draw_ver += 1
	_count("land_ceded")
	gw.news_m(Loc.mk("%s ПЕРЕДАЁТ ЗЕМЛЮ С МЕСТОРОЖДЕНИЕМ: %s", [Loc.name(_name(giver)), Loc.name(_name(taker))]), "amber")
	gw.changed.emit()




func border_deposit(owner: int, taker: int, types: Array = []) -> Dictionary:
	if gw.econ == null:
		return {}
	var d: WorldData = gw.data
	var tc: Country = gw.country_by_id(taker)
	var lack: Array = gw.econ.scarce_of(tc) if tc != null else []
	var best: Dictionary = {}
	var bs: float = -1.0
	for dp: Dictionary in gw.econ.deposits:
		var c: Vector2i = dp["cell"]
		var res: String = String(dp.get("res", ""))
		if int(dp.get("left", 0)) < 100 or d.get_owner_id(c.x, c.y) != owner:
			continue
		if not types.is_empty() and not types.has(res):
			continue
		if _near_city(c, owner, 6):
			continue
		var dist: int = _dist_to_land(c, taker, 90)
		if dist < 0:
			continue
		var sc: float = float(int(dp["left"])) / 100.0 + (12.0 if lack.has(res) else 0.0) + (4.0 if dp["mine"] != null else 0.0) - float(dist) / 10.0
		if sc > bs:
			bs = sc
			best = {"cell": c, "res": res, "left": int(dp["left"])}
	return best


func _near_city(c: Vector2i, owner: int, pad: int) -> bool:
	for city: City in gw.cities:
		if city.country_id == owner and maxi(absi(city.center.x - c.x), absi(city.center.y - c.y)) <= city.radius + pad:
			return true
	return false



func _dist_to_land(c: Vector2i, id: int, reach: int) -> int:


	var d: WorldData = gw.data
	var ow: PackedByteArray = d.owners
	var w: int = d.w
	var h: int = d.h
	for r in range(3, reach + 1, 3):
		var ya: int = c.y - r
		var yb: int = c.y + r
		var xa: int = c.x - r
		var xb: int = c.x + r
		for k in range( - r, r + 1, 3):
			var x: int = c.x + k
			var y: int = c.y + k
			if x >= 0 and x < w:
				if ya >= 0 and ya < h and ow[ya * w + x] == id:
					return r
				if yb >= 0 and yb < h and ow[yb * w + x] == id:
					return r
			if y >= 0 and y < h:
				if xa >= 0 and xa < w and ow[y * w + xa] == id:
					return r
				if xb >= 0 and xb < w and ow[y * w + xb] == id:
					return r
	return -1



func item_to(id: String) -> int:
	if id.length() < 2:
		return -1
	var n: int = int(id.substr(1))
	match id.left(1):
		"d":
			for d: Dictionary in demands:
				if int(d["id"]) == n:
					return int(d["to"])
		"o":

			for o: Array in offers:
				if int(o[0]) == n and (_who_hint < 0 or int(o[1]) == _who_hint):
					return int(o[1])
		"t":
			for t: Dictionary in t_offers:
				if int(t["id"]) == n:
					return int(t["to"])
		"c":
			for k: Dictionary in calls:
				if int(k["id"]) == n:
					return int(k["to"])
		"n":
			for nt: Dictionary in notes:
				if int(nt["id"]) == n:
					return int(nt["to"])
		"s", "k":
			return conf.item_to(id) if conf != null else -1
		"e":
			return react.item_to(n) if react != null else -1
		"r":
			return gw.econ.req_to_id(n) if gw.econ != null else -1
		"y":
			return ally.offer_to(n) if ally != null else -1
		"q":
			return rq.item_to(n) if rq != null else -1
		"h":
			return sky.item_to(n) if sky != null else -1
		"x":
			return gw.econ.trd.item_to(n) if gw.econ != null and gw.econ.trd != null else -1
	return -1



func country_row(me: int, other: int) -> Dictionary:
	var c: Country = gw.country_by_id(other)
	if c == null:
		return {}
	var r: int = get_rel(me, other)
	var row: Dictionary = {"id": other, "name": c.name, "eliminated": c.eliminated, "rel_state": r, "rel_name": String(REL_NAMES[r]), 
		"rel_color": String(REL_COLORS[r]), "relation": relation(me, other), "trend": relation_trend(me, other), 
		"treaties": treaties_of(me, other), "embargo_out": embargoed(me, other), "embargo_in": embargoed(other, me), 
		"strength_ratio": strength(other) / maxf(1.0, strength(me)), "score": c.score, "persona": {}, "scarce": [], 
		"coalition": "", "can_propose": [], "can_cancel": [], "can_demand": false, "pending": false}
	if known.has(other) or c.is_player:
		var P: Dictionary = _p(other)
		row["persona"] = {"id": String(P.get("id", "")), "name": String(P.get("name", "")), "icon": String(P.get("icon", "")), "desc": String(P.get("desc", ""))}
		if gw.econ != null:
			row["scarce"] = gw.econ.scarce_of(c)
	if not coalition.is_empty():
		if int(coalition["leader"]) == other:
			row["coalition"] = "leader"
		elif (coalition["members"] as Array).has(other):
			row["coalition"] = "member"
	if c.eliminated:
		return row
	if r != Rel.WAR and r != Rel.TRUCE:
		for k: String in TREATY_KINDS:
			if not has_treaty(me, other, k):
				(row["can_propose"] as Array).append(k)
		row["can_demand"] = not demand_options(me, other).is_empty()
	for k2: String in treaties_of(me, other):
		(row["can_cancel"] as Array).append(k2)
	row["subject"] = subject_kind(other)
	row["overlord"] = subject_of(other)
	row["subject_tag"] = subject_tag(other)
	row["passage_us"] = has_passage(me, other)
	row["passage_them"] = has_passage(other, me)
	for d: Dictionary in demands:
		if int(d["from"]) == other and int(d["to"]) == me:
			row["pending"] = true
	return row




func _player_cap(p: Country) -> int:
	var share: float = float(PLAYER_DEMAND_SHARE[0 if int(counters.get("demands_player", 0)) == 0 else 1])
	return int(float(maxi(p.money, 800)) * share)


func _has_demand(from: int, to: int) -> bool:
	for d: Dictionary in demands:
		if int(d["from"]) == from and int(d["to"]) == to:
			return true
	return false




func war_allowed(a: int, b: int, threat: bool) -> bool:
	if GameConfig.aggression == 0 or at_war(a, b) or allied(a, b) or truce_on(a, b):
		return false
	if calm_left(a, b) > 0.0:
		return false
	if is_subject(a) or subject_of(b) == a or subject_of(a) == b:
		return false
	if ally_of_ally(a, b) > 0:
		return false
	var cb: Country = gw.country_by_id(b)
	if cb == null:
		return false
	var ca0: Country = gw.country_by_id(a)
	var bots: bool = not cb.is_player and ca0 != null and not ca0.is_player


	if gw.game_time < (GameConfig.player_grace() if cb.is_player else (BOT_WAR_T if bots else 300.0)):
		return false
	var foes: int = cb.at_war.size()
	var cap: int = 1 if (cb.is_player and gw.game_time < 1200.0) else 2
	if not threat and foes >= cap:
		return false
	return true



func passage_pending(grantee: int) -> bool:
	for o: Dictionary in t_offers:
		if String(o["kind"]) == "passage" and int(o["from"]) == grantee and gw.game_time <= float(o["until"]):
			return true
	return false



func _player_other(a: int, b: int) -> int:
	var p: Country = gw.player
	if p == null:
		return -1
	if a == p.id:
		return b
	if b == p.id:
		return a
	return -1



func has_passage(grantee: int, grantor: int) -> bool:
	return passage.has("%d>%d" % [grantor, grantee])




func may_cross(c: int, owner: int) -> bool:
	return (rq != null and owner > 0 and rq.land_ok(c, owner)) or owner <= 0 or owner == c or at_war(c, owner) or allied(c, owner) or has_passage(c, owner)\
	or (ally != null and ally.same(c, owner))\
	or (conf != null and conf.holds(c, owner))




func cross_block(c: int, from: Vector2, to: Vector2) -> int:
	var d: WorldData = gw.data
	if d == null:
		return 0
	var dist: float = from.distance_to(to)
	var n: int = int(dist / 16.0)
	for i in range(1, n):
		if dist - float(i) * 16.0 < 24.0:
			break
		var p: Vector2 = from.lerp(to, float(i) / float(n))
		var x: int = floori(p.x / GameWorld.CELL)
		var y: int = floori(p.y / GameWorld.CELL)
		if not d.inside(x, y):
			continue
		var o: int = d.get_owner_id(x, y)
		if not may_cross(c, o):
			return o
	return 0



func path_block(c: int, path: PackedVector2Array) -> int:
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var n: int = maxi(1, int(a.distance_to(b) / 16.0))
		for k in n:
			var p: Vector2 = a.lerp(b, float(k) / float(n))
			var x: int = floori(p.x / GameWorld.CELL)
			var y: int = floori(p.y / GameWorld.CELL)
			if gw.data.inside(x, y):
				var o: int = gw.data.get_owner_id(x, y)
				if not may_cross(c, o):
					return o
	return 0




func request_passage(grantee: int, grantor: int, vs: int = 0) -> String:
	if grantee == grantor or not _alive(grantee) or not _alive(grantor):
		return Loc.t("Страны нет")
	if at_war(grantee, grantor) or truce_on(grantee, grantor):
		return Loc.t("Сначала заключите мир")
	if has_passage(grantee, grantor):
		return Loc.t("Право прохода уже есть")
	var pw: Dictionary = passage_wait(grantor, grantee)
	if String(pw.get("kind", "")) == "revoke":
		return Loc.t("Проход недавно закрыт: снова через %s") % _mmss_s(float(pw["left"]))
	_pass_ask["%d>%d" % [grantee, grantor]] = gw.game_time
	var cg: Country = gw.country_by_id(grantor)
	if cg != null and cg.is_player:
		_pass_ask["h%d" % grantor] = gw.game_time
	_reveal(grantee, grantor)
	if cg.is_player:
		for o: Dictionary in t_offers:
			if int(o["from"]) == grantee and int(o["to"]) == grantor and String(o["kind"]) == "passage":
				return Loc.t("Запрос отправлен")
		t_offers.append({"id": _dem_id, "from": grantee, "to": grantor, "kind": "passage", "vs": vs, "until": gw.game_time + PASS_ANSWER_T})
		_dem_id += 1
		_count("offer_passage")
		gw.say(cg, Loc.mk("%s просит право прохода через вашу землю%s", [Loc.name(_cname(grantee)), (Loc.t(" (война с %s)") % Loc.name(_cname(vs))) if vs > 0 else ""]))
		gw.offer_received.emit()
		pending_changed.emit()
		return Loc.t("Запрос отправлен")
	var why: String = ai_passage_reason(grantor, grantee)
	if why != "":
		add_opinion(grantee, grantor, -2)
		_count("passage_refused")
		return why
	grant_passage(grantor, grantee)
	return ""




func ai_passage_reason(grantor: int, grantee: int) -> String:
	var nm: String = _cname(grantor)
	if at_war(grantor, grantee) or truce_on(grantor, grantee):
		return Loc.t("%s: сначала мир") % nm
	if allied(grantor, grantee):
		return ""
	var ce: Country = gw.country_by_id(grantee)
	if ce != null:
		for e: int in ce.at_war.keys():
			if e != grantor and (allied(grantor, e) or has_treaty(grantor, e, "defense") or relation(grantor, e) > 40):
				return Loc.t("%s не пустит войска против друга: %s") % [nm, _cname(e)]
	var P: Dictionary = _p(grantor)
	var need: int = int(TREATY_INFO["passage"]["min_rel"])
	need -= int(float(P["trade"]) * 12.0)
	need += int(float(P["caution"]) * 25.0)
	if _common_enemy(grantor, grantee):
		need -= 40
	if has_treaty(grantor, grantee, "nap") or has_treaty(grantor, grantee, "defense"):
		need -= 10
	if strength(grantee) > strength(grantor) * 1.5:
		need -= 10
	var rv: int = relation(grantor, grantee)
	if rv < need:
		return Loc.t("%s отказывает: отношения %d, нужно от %d") % [nm, rv, need]
	return ""


func grant_passage(grantor: int, grantee: int, quiet: bool = false) -> void :
	if grantor == grantee or not _alive(grantor) or not _alive(grantee) or at_war(grantor, grantee):
		return
	passage["%d>%d" % [grantor, grantee]] = gw.game_time
	add_opinion(grantor, grantee, 3)
	_count("treaty_passage")
	_reveal(grantor, grantee)
	if not quiet:
		gw.news_m(Loc.mk("ПРАВО ПРОХОДА: %s ПРОПУСКАЕТ ВОЙСКА СТРАНЫ %s", [Loc.name(_name(grantor)), Loc.name(_name(grantee))]), "grass_light")
	gw.say(grantee, Loc.mk("%s даёт право прохода: войска и БПЛА могут идти через её землю", [Loc.name(_cname(grantor))]))
	if not quiet:
		gw.say(grantor, Loc.mk("Вы пропускаете войска страны %s через свою землю", [Loc.name(_cname(grantee))]))
	gw.relations_changed.emit()
	pending_changed.emit()



func cancel_passage(a: int, b: int) -> String:
	var k1: String = "%d>%d" % [a, b]
	var k2: String = "%d>%d" % [b, a]
	if not passage.has(k1) and not passage.has(k2):
		return Loc.t("Нет такого договора")
	passage.erase(k1)
	passage.erase(k2)
	_pass_closed(a, b)
	_passage_out(a, b)
	add_opinion(a, b, - int(CANCEL_PENALTY["passage"]))
	_count("cancel_passage")
	gw.news_m(Loc.mk("ПРАВО ПРОХОДА ОТМЕНЕНО: %s И %s", [Loc.name(_name(a)), Loc.name(_name(b))]), "amber")
	gw.say(b, Loc.mk("%s закрывает проход через свою землю", [Loc.name(_cname(a))]))
	gw.relations_changed.emit()
	pending_changed.emit()
	return ""




func _passage_out(a: int, b: int) -> void :
	close_land(a, b)



func ai_want_passage(c: int, through: int, vs: int) -> bool:
	if through <= 0 or may_cross(c, through):
		return true
	var k: String = "%d>%d" % [c, through]
	if gw.game_time - float(_pass_ask.get(k, -1000000000.0)) < (PASS_ASK_GAP_H if _human(through) else PASS_ASK_GAP)\
	or (_human(through) and gw.game_time - float(_pass_ask.get("h%d" % through, -1000000000.0)) < PASS_ASK_GAP_ANY):
		return false
	return request_passage(c, through, vs) == ""



func _ai_passage_review(c: Country) -> void :
	for k: String in passage.keys():
		var gg: PackedStringArray = k.split(">")
		if int(gg[0]) != c.id:
			continue
		var e: int = int(gg[1])
		if not _alive(e):
			passage.erase(k)
			continue
		var bad: bool = relation(c.id, e) < -25
		var ce: Country = gw.country_by_id(e)
		for x: int in ce.at_war.keys():
			if x != c.id and (allied(c.id, x) or has_treaty(c.id, x, "defense")):
				bad = true
		if bad:
			revoke_passage(c.id, e)




func passage_wait(grantor: int, grantee: int) -> Dictionary:
	var now: float = gw.game_time
	var lr: float = PASS_REGRANT_GAP - (now - float(_pass_ask.get("r%d>%d" % [grantor, grantee], -1000000000.0)))
	var lo: float = PASS_OFFER_GAP - (now - float(_pass_ask.get("o%d>%d" % [grantor, grantee], -1000000000.0)))
	if lr > 0.0 and lr >= lo:
		return {"why": Loc.t("проход недавно закрыт · снова через %s") % _mmss_s(lr), "left": lr, "kind": "revoke", "head": Loc.t("проход недавно закрыт · снова через ")}
	if lo > 0.0:
		return {"why": Loc.t("предлагали недавно · снова через %s") % _mmss_s(lo), "left": lo, "kind": "offer", "head": Loc.t("предлагали недавно · снова через ")}
	return {}


static func _mmss_s(t: float) -> String:
	var n: int = maxi(0, ceili(t))
	return "%d:%02d" % [n / 60, n % 60]



func _pass_closed(a: int, b: int) -> void :
	_pass_ask["r%d>%d" % [a, b]] = gw.game_time
	_pass_ask["r%d>%d" % [b, a]] = gw.game_time
	for i in range(t_offers.size() - 1, -1, -1):
		var o: Dictionary = t_offers[i]
		var k: String = String(o.get("kind", ""))
		if (k == "passage" or k == "passage_give") and ((int(o["from"]) == a and int(o["to"]) == b) or (int(o["from"]) == b and int(o["to"]) == a)):
			t_offers.remove_at(i)



func troops_on(who: int, land: int) -> int:
	return gw.ops.wd_units(who, land).size() if gw.ops != null else 0



func _war_sides(a: int, b: int) -> Array:
	var out: Array = [b]
	for c: Country in gw.countries:
		if c.id == a or c.id == b or c.eliminated or at_war(c.id, a):
			continue
		if (allied(c.id, b) or has_treaty(c.id, b, "defense") or (ally != null and ally.same(c.id, b))) and not allied(c.id, a) and not (ally != null and ally.same(c.id, a)):
			out.append(c.id)
	return out





func war_block(a: int, b: int) -> Dictionary:
	if gw.ops == null or gw.army == null or a == b or at_war(a, b):
		return {}
	for x: int in _war_sides(a, b):
		var tag: String = "" if x == b else Loc.t(" (союзник: %s)") % _cname(b)
		var n: int = troops_on(x, a)
		if n > 0:
			var left: int = gw.ops.withdraw_left(x, a)
			if left >= 0:
				return {"why": Loc.t("войска страны %s%s уходят с вашей земли: %d осталось") % [_cname(x), tag, left], "fix": "wait", "who": x, "land": a, "n": left}
			if has_passage(x, a):
				return {"why": Loc.t("войска страны %s%s на вашей земле — сначала отзовите право прохода и дождитесь их вывода") % [_cname(x), tag], "fix": "passage", "who": x, "land": a, "n": n}
			if allied(x, a) or (ally != null and ally.same(x, a)):
				return {"why": Loc.t("войска страны %s%s на вашей земле — сначала %s и дождитесь их вывода") % [_cname(x), tag, Loc.t("разорвите союз") if allied(x, a) else Loc.t("выйдите из альянса")], "fix": "alliance", "who": x, "land": a, "n": n}
			return {"why": Loc.t("войска страны %s%s на вашей земле — выдворите их и дождитесь вывода") % [_cname(x), tag], "fix": "expel", "who": x, "land": a, "n": n}
		var n2: int = troops_on(a, x)
		if n2 > 0:
			var left2: int = gw.ops.withdraw_left(a, x)
			if left2 >= 0:
				return {"why": Loc.t("ваши войска уходят с земли страны %s: %d осталось") % [_cname(x), left2], "fix": "wait", "who": a, "land": x, "n": left2}
			return {"why": Loc.t("ваши войска на земле страны %s%s — сначала выведите их") % [_cname(x), tag], "fix": "recall", "who": a, "land": x, "n": n2}
	return {}


func war_block_why(a: int, b: int) -> String:
	return String(war_block(a, b).get("why", ""))


func strike_block(a: int, o: int) -> String:
	if a <= 0 or o <= 0 or a == o or at_war(a, o):
		return ""
	if is_subject(a) or subject_of(o) == a or subject_of(a) == o:
		return STRIKE_SUBJ_TXT
	return STRIKE_BLOCK_TXT if not war_block(a, o).is_empty() else ""



func strike_block_at(a: int, p: Vector2, tell: bool = true) -> String:
	if gw.ops == null or gw.data == null:
		return ""
	var o: int = gw.ops._owner_at(p)
	var why: String = strike_block(a, o)
	if why != "" and tell:
		_count("strike_blocked")
		var k: String = "%d>%d" % [a, o]
		if gw.game_time - float(_sb_said.get(k, -1000000000.0)) >= 10.0:
			_sb_said[k] = gw.game_time
			gw.say(a, "%s (%s)" % [why, _cname(o)])
	return why



func _ai_war_prep(a: int, blk: Dictionary) -> void :
	var who: int = int(blk["who"])
	var land: int = int(blk["land"])
	match String(blk["fix"]):
		"passage":
			revoke_passage(a, who)
		"expel":
			expel_troops(a, who)
		"recall":
			recall_troops(a, land)
	_count("ai_war_prep_" + String(blk["fix"]))



func close_land(a: int, b: int) -> void :
	if gw.ops == null or at_war(a, b):
		return
	for pr: Array in [[a, b], [b, a]]:
		var who: int = int(pr[0])
		var land: int = int(pr[1])
		if may_cross(who, land):
			continue
		var n: int = gw.ops.withdraw_start(who, land)
		if n > 0:
			gw.say(who, Loc.mk("Нет права быть на земле страны %s: войска уходят к ближайшей границе (%d ед.)", [Loc.name(_cname(land)), n]))
			gw.say(land, Loc.mk("Войска страны %s уходят с вашей земли (%d ед.)", [Loc.name(_cname(who)), n]))




func revoke_passage(owner: int, grantee: int) -> String:
	var k: String = "%d>%d" % [owner, grantee]
	if not passage.has(k):
		return Loc.t("Нет права прохода")
	passage.erase(k)
	add_opinion(owner, grantee, - int(CANCEL_PENALTY["passage"]))
	_pass_ask["%d>%d" % [grantee, owner]] = gw.game_time
	_pass_closed(owner, grantee)
	_count("revoke_passage")
	var n: int = 0
	if gw.ops != null and not may_cross(grantee, owner):
		n = gw.ops.withdraw_start(grantee, owner)
	gw.news_m(Loc.mk("ПРАВО ПРОХОДА ОТОЗВАНО: %s — %s", [Loc.name(_name(owner)), Loc.name(_name(grantee))]), "amber")
	gw.say(grantee, Loc.mk("%s отзывает право прохода: %s", [Loc.name(_cname(owner)), (Loc.t("ваши войска уходят к ближайшей границе (%d ед.)") % n) if n > 0 else Loc.t("войска и БПЛА больше не пройдут")]))
	gw.say(owner, Loc.mk("Право прохода для страны %s отозвано%s", [Loc.name(_cname(grantee)), (Loc.t(": их войска уходят (%d ед.)") % n) if n > 0 else ""]))
	gw.relations_changed.emit()
	pending_changed.emit()
	return ""




func expel_troops(owner: int, who: int) -> String:
	if not _alive(owner) or not _alive(who) or owner == who:
		return Loc.t("Страны нет")
	if at_war(owner, who):
		return Loc.t("Война: выбивайте их силой")
	if has_passage(who, owner):
		return revoke_passage(owner, who)
	if allied(who, owner) or (ally != null and ally.same(who, owner)):
		return Loc.t("Союзник вправе стоять на вашей земле — сначала разорвите союз")
	if rq != null and rq.land_ok(who, owner):
		return rq.station_end(owner, who)
	if gw.ops == null:
		return Loc.t("Нельзя")
	var again: bool = gw.ops.withdraw_left(who, owner) >= 0
	var n: int = gw.ops.withdraw_start(who, owner)
	if n == 0:
		return Loc.t("Их войск на вашей земле нет")
	if again:
		return ""
	add_opinion(owner, who, -3)
	_count("expel_troops")
	gw.say(who, Loc.mk("%s выдворяет ваши войска: они уходят к ближайшей границе (%d ед.)", [Loc.name(_cname(owner)), n]))
	gw.say(owner, Loc.mk("Войска страны %s уходят с вашей земли (%d ед.)", [Loc.name(_cname(who)), n]))
	return ""



func recall_troops(who: int, land: int) -> String:
	if not _alive(who) or not _alive(land) or who == land:
		return Loc.t("Страны нет")
	if at_war(who, land):
		return Loc.t("Война: отводите армии приказом")
	var n: int = gw.ops.withdraw_start(who, land, true) if gw.ops != null else 0
	if n == 0:
		return Loc.t("Ваших войск там нет")
	_count("recall_troops")
	gw.say(who, Loc.mk("Войска уходят с земли страны %s к ближайшей границе (%d ед.)", [Loc.name(_cname(land)), n]))
	return ""





func offer_passage(grantor: int, grantee: int) -> String:
	if grantor == grantee or not _alive(grantor) or not _alive(grantee):
		return Loc.t("Страны нет")
	if at_war(grantor, grantee) or truce_on(grantor, grantee):
		return Loc.t("Сначала заключите мир")
	if has_passage(grantee, grantor):
		return Loc.t("Право прохода уже есть")
	if allied(grantor, grantee) or (ally != null and ally.same(grantor, grantee)):
		return Loc.t("Союзники и так проходят")
	var pw: Dictionary = passage_wait(grantor, grantee)
	if not pw.is_empty():
		return (Loc.t("Проход недавно закрыт: снова через %s") if String(pw["kind"]) == "revoke" else Loc.t("Уже предлагали: снова через %s")) % _mmss_s(float(pw["left"]))
	_pass_ask["o%d>%d" % [grantor, grantee]] = gw.game_time
	_reveal(grantor, grantee)
	var cg: Country = gw.country_by_id(grantee)
	if cg.is_player:
		for o: Dictionary in t_offers:
			if int(o["from"]) == grantor and int(o["to"]) == grantee and String(o["kind"]) == "passage_give":
				return Loc.t("Предложение отправлено")
		t_offers.append({"id": _dem_id, "from": grantor, "to": grantee, "kind": "passage_give", "until": gw.game_time + PASS_OFFER_T})
		_dem_id += 1
		_count("offer_passage_give")
		gw.say(cg, Loc.mk("%s предлагает право прохода через свою землю", [Loc.name(_cname(grantor))]))
		gw.offer_received.emit()
		pending_changed.emit()
		return Loc.t("Предложение отправлено")
	var why: String = ai_passage_offer_reason(grantee, grantor)
	if why != "":
		_count("passage_give_refused")
		dlog(grantee, "отклоняет право прохода от %s" % _cname(grantor), why)
		return why
	_count("passage_give_ok")
	grant_passage(grantor, grantee)
	return ""





func ai_passage_offer_reason(ai: int, grantor: int) -> String:
	var nm: String = _cname(ai)
	var cg: Country = gw.country_by_id(grantor)
	if cg != null:
		for x: int in cg.at_war.keys():
			if allied(ai, x) or has_treaty(ai, x, "defense") or (ally != null and ally.same(ai, x)):
				return Loc.t("%s не примет помощь от врага своего друга: %s") % [nm, _cname(x)]
	var ca: Country = gw.country_by_id(ai)
	if ca != null and cg != null and ca.capital_id >= 0 and cg.capital_id >= 0 and gw.naval != null\
	and gw.naval._land_id(Vector2(gw.cities[ca.capital_id].center * GameWorld.CELL)) != gw.naval._land_id(Vector2(gw.cities[cg.capital_id].center * GameWorld.CELL)):
		return Loc.t("%s: нам не нужен проход — нет пути по суше") % nm
	var P: Dictionary = _p(ai)
	var need: int = -20 + int(float(P["caution"]) * 25.0) - int(float(P["trade"]) * 10.0)
	if _common_enemy(ai, grantor):
		need -= 30
	var rv: int = relation(ai, grantor)
	if rv < need:
		return Loc.t("%s не доверяет: отношения %d, нужно от %d") % [nm, rv, need]
	return ""




func subject_of(id: int) -> int:
	var s: Dictionary = subjects.get(id, {})
	return int(s.get("over", 0))


func subject_kind(id: int) -> String:
	return String((subjects.get(id, {}) as Dictionary).get("kind", ""))


func is_subject(id: int) -> bool:
	return subjects.has(id)


func subjects_of(over: int) -> Array:
	var out: Array = []
	for sid: int in subjects:
		if int(subjects[sid]["over"]) == over and _alive(sid):
			out.append(sid)
	return out



func subject_tag(id: int) -> String:
	if not subjects.has(id):
		return ""
	return "%s · %s" % [String(SUBJ_NAMES.get(subject_kind(id), "")), _cname(subject_of(id)).to_upper()]



func subject_cap(over: int) -> int:
	var c: Country = gw.country_by_id(over)
	if c == null:
		return 0
	if c.is_player:
		return clampi(c.city_ids.size() / 3, 1, 3)
	return int(SUBJ_AI_MAX.get(String(_p(over).get("id", "")), 1))



func subject_need(victim: int, over: int, kind: String, war: bool = false) -> float:
	var P: Dictionary = _p(victim)
	var friends: int = 0
	for c: Country in gw.countries:
		if c.id != victim and c.id != over and not c.eliminated and (has_treaty(victim, c.id, "defense") or allied(victim, c.id)):
			friends += 1
	var need: float = float(SUBJ_NEED.get(kind, 2.2)) + float(P["aggr"]) * 0.8 - float(P["caution"]) * 0.5 + float(friends) * 0.5 - float(relation(victim, over)) / 150.0
	if war and war_time(victim, over) > 180.0:
		need -= 0.6
	var cv: Country = gw.country_by_id(victim)
	if cv != null and cv.is_player:
		need = maxf(need, float(SUBJ_NEED.get(kind, 2.2)))
	return maxf(1.4, need)


func ai_subject_yields(victim: int, over: int, kind: String, war: bool = false) -> bool:
	if is_subject(victim) or is_subject(over):
		return false
	return strength(over) / maxf(1.0, strength(victim)) >= subject_need(victim, over, kind, war)



func subject_options(me: int, other: int) -> Dictionary:
	var o: Dictionary = {"status": "", "kind": "", "liberty": 0.0, "tribute": 0.0, "ratio": strength(me) / maxf(1.0, strength(other)), 
		"need_v": subject_need(other, me, "vassal", at_war(me, other)), "need_p": subject_need(other, me, "puppet", at_war(me, other)), 
		"why": "", "can_offer": false, "can_ult": false, "can_release": false, "can_free": false, "n": subjects_of(me).size(), "cap": subject_cap(me)}
	if subject_of(other) == me:
		o["status"] = "ours"
		o["kind"] = subject_kind(other)
		o["liberty"] = float(subjects[other]["liberty"])
		o["tribute"] = float(TRIBUTE.get(o["kind"], 0.1))
		o["can_release"] = true
		return o
	if subject_of(me) == other:
		o["status"] = "theirs"
		o["kind"] = subject_kind(me)
		o["tribute"] = float(TRIBUTE.get(o["kind"], 0.1))
		o["can_free"] = true
		return o
	if is_subject(other):
		o["status"] = "other"
		o["why"] = Loc.t("%s — вассал %s") % [_cname(other), _cname(subject_of(other))]
		return o
	if is_subject(me):
		o["why"] = Loc.t("Вы сами вассал %s") % _cname(subject_of(me))
		return o
	if not subjects_of(other).is_empty() and float(o["ratio"]) < 3.0:
		o["why"] = Loc.t("У них свои вассалы")
		return o
	if subjects_of(me).size() >= subject_cap(me):
		o["why"] = Loc.t("Предел вассалов: %d (1 на 3 города)") % subject_cap(me)
		return o
	if truce_on(me, other) or calm_on(me, other):
		o["why"] = Loc.t("Идёт перемирие") if truce_on(me, other) else Loc.t("Мир ещё свеж")
		return o
	o["can_offer"] = not at_war(me, other)
	o["can_ult"] = true
	return o



func _stripe_sync() -> void :
	var cols: = PackedColorArray()
	cols.resize(9)
	cols.fill(Color(0, 0, 0, 0))
	for sid: int in subjects:
		var oc: Country = gw.country_by_id(subject_of(sid))
		if sid > 0 and sid < 9 and oc != null:
			cols[sid] = Color(oc.color, 1.0)
	for spr: Variant in [gw.get("territory"), gw.get("territory_border")]:
		if spr is Sprite2D and (spr as Sprite2D).material is ShaderMaterial:
			((spr as Sprite2D).material as ShaderMaterial).set_shader_parameter("over_cols", cols)


func _young(sid: int) -> bool:
	return float((subjects.get(sid, {}) as Dictionary).get("young", 0.0)) > gw.game_time


func _free_subject(sub: int, quiet: bool = false) -> void :
	if not subjects.has(sub):
		return
	var over: int = subject_of(sub)
	subjects.erase(sub)
	_trib_earned.erase(sub)
	_subj_pair[sub] = gw.game_time + SUBJ_PAIR_GAP
	peace_t[key(over, sub)] = gw.game_time
	_stripe_sync()
	if not quiet:
		gw.relations_changed.emit()
		pending_changed.emit()



func release_subject(over: int, sub: int) -> String:
	if subject_of(sub) != over:
		return Loc.t("Это не ваш вассал")
	_free_subject(sub)
	add_opinion(over, sub, 20)
	_count("subj_released")
	gw.news_m(Loc.mk("%s ОТПУСКАЕТ ВАССАЛА: %s", [Loc.name(_name(over)), Loc.name(_name(sub))]), "grass_light")
	return ""



func _join_war(who: int, enemy: int, side: int, why: String) -> void :
	if who == enemy or at_war(who, enemy) or not _alive(who) or not _alive(enemy):
		return
	if conf_lock(who, enemy) or (conf != null and conf._in_conf(who)):
		_count("conf_war_blocked")
		return
	_set_rel(who, enemy, Rel.WAR)
	_war_cleanup(who, enemy)
	add_opinion(who, enemy, -30)
	_count("dip2_join")
	dlog(who, "вступает за %s против %s" % [_cname(side), _cname(enemy)], why, 0.0, ["join", side, enemy])
	_helped["%d>%d" % [who, side]] = gw.game_time
	refusals.erase("%d>%d" % [who, side])
	if conf != null:
		conf.on_war(who, enemy)
	var noted: bool = care != null and care.on_join(who, enemy, side)
	gw.news_m(Loc.mk("%s ВСТУПАЕТ В ВОЙНУ НА СТОРОНЕ %s: %s (%s)", [Loc.name(_name(who)), Loc.name(_name(side)), Loc.name(_name(enemy)), why]), "alert_red")
	var cw: Country = gw.country_by_id(who)
	var ce: Country = gw.country_by_id(enemy)
	if cw.is_player or ce.is_player:
		gw.war_declared.emit(who, enemy)
	if cw.is_player:
		gw.say(cw, Loc.mk("Вы вступаете в войну с %s (%s)", [Loc.name(ce.name), why.to_lower()]))
	var cs: Country = gw.country_by_id(side)
	if cs != null and cs.is_player and not cw.is_player and not noted:
		gw.say(cs, Loc.mk("%s вступает в войну с %s на вашей стороне", [Loc.name(cw.name), Loc.name(ce.name)]))





func pile_gate(c: int, e: int, side: int, offense: bool) -> String:
	var ce: Country = gw.country_by_id(e)
	var cs: Country = gw.country_by_id(side) if side > 0 else null
	if ce == null or c == e or (cs != null and cs.is_player):
		return ""
	var human: bool = ce.is_player
	if not human and not offense:
		return ""
	var n: int = 0
	var young: float = INF
	for x: Variant in ce.at_war.keys():
		var xi: int = int(x)
		if xi == c or not _alive(xi):
			continue
		n += 1
		if offense or xi != side:
			young = minf(young, war_time(e, xi))
	var d: int = GameConfig.diff_of(gw.country_by_id(c))
	var cap: int = (int(PILE_CAP[d]) if offense else PILE_CAP_DEF) if human else PILE_CAP_BOT
	if n >= cap:
		return "cap"
	var gap: float = (float(PILE_GAP[d]) if offense else PILE_GAP_DEF) if human else PILE_GAP_BOT
	if young < gap:
		return "wait"
	return ""



func _pile_alt(c: int, x: int, e: int) -> String:
	var trd: Variant = gw.econ.get("trd") if gw.econ != null else null
	if relation(c, e) < 20 and trd != null and trd.has_method("can_sanction") and (trd.sanctions_by(c, e) as Array).is_empty() and String(trd.can_sanction(c, e, "", true)) == "":
		return "sanction"
	var cc: Country = gw.country_by_id(c)
	if cc != null and relation(c, x) >= 30 and cc.money >= 1500:
		return "aid"
	return "decline"



func _subject_blocks(a: int, b: int) -> bool:
	if _dip2_follow or not is_subject(a):
		return false
	_count("subj_war_blocked")
	var ca: Country = gw.country_by_id(a)
	if ca != null and ca.is_player:
		gw.say(ca, Loc.mk("Вассал не объявляет войн сам: решает %s", [Loc.name(_cname(subject_of(a)))]))
	return true
