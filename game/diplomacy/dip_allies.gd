extends "res://game/diplomacy/dip_rules.gd"




func declare_war(a: int, b: int, reason: String = "") -> void :
	if a == b or at_war(a, b):
		return
	if conf_lock(a, b) or (conf != null and conf._in_conf(a)):
		_count("conf_war_blocked")
		return
	var ca: Country = gw.country_by_id(a)
	var cb: Country = gw.country_by_id(b)
	if ca == null or cb == null or ca.eliminated or cb.eliminated:
		return
	if _subject_blocks(a, b) or subject_of(b) == a or subject_of(a) == b:
		return
	var blk: Dictionary = war_block(a, b)
	if not blk.is_empty():



		_count("war_blocked_troops")
		dlog(a, "не может объявить войну %s" % _cname(b), String(blk["why"]), 0.0, ["war_block", b])
		if ca.is_player:
			gw.say(ca, Loc.mk("Война не объявлена: %s", [String(blk["why"])]))
		else:
			_ai_war_prep(a, blk)
		return
	if ally != null and ally.same(a, b):
		ally.leave(a, Loc.t("нападение на члена альянса"))
	var treachery: bool = has_treaty(a, b, "nap") or has_treaty(a, b, "defense")
	war_by[key(a, b)] = a
	_set_rel(a, b, Rel.WAR)
	_war_cleanup(a, b)
	add_opinion(a, b, -60)
	wars_log.append([gw.game_time, a, b, reason])
	_count("wars")
	dlog(a, "объявляет войну %s" % _cname(b), reason + (Loc.t(" (нарушен пакт)") if treachery else ""))
	_reveal(a, b)
	gw.news_m(Loc.mk("%s ОБЪЯВЛЯЕТ ВОЙНУ: %s%s", [Loc.name(_name(a)), Loc.name(_name(b)), (" (" + reason + ")") if reason != "" else ""]), "alert_red")
	if treachery:
		_count("nap_broken")
		if care != null:
			care.on_treachery(a)
		gw.news_m(Loc.mk("ВЕРОЛОМСТВО: %s НАРУШАЕТ ПАКТ — %s", [Loc.name(_name(a)), Loc.name(_name(b))]), "alert_red")
		for c: Country in gw.countries:
			if c.id != a and c.id != b and not c.eliminated:
				add_opinion(a, c.id, -15)
	if cb.is_player or ca.is_player:
		gw.war_declared.emit(a, b)
		Sfx.ui("ui_war")
	for c: Country in gw.countries:
		if c.id == a or c.id == b or c.eliminated or at_war(c.id, a) or at_war(c.id, b):
			continue
		var pact: bool = has_treaty(c.id, b, "defense")
		if (allied(c.id, b) or pact) and not allied(c.id, a) and not has_treaty(c.id, a, "defense") and not truce_on(c.id, a) and calm_left(c.id, a) <= 0.0 and not conf_lock(c.id, a):
			if not c.is_player and pile_gate(c.id, a, b, false) != "":
				_count("pile_wait_def")
				continue
			_set_rel(c.id, a, Rel.WAR)
			_war_cleanup(c.id, a)
			_count("joined_defense" if pact else "joined_ally")
			dlog(c.id, "вступает за %s против %s" % [_cname(b), _cname(a)], "оборона союзника (авто)" if not pact else "оборонный пакт (авто)", 0.0, ["join", b, a])
			if care != null:
				care.on_join(c.id, a, b)
			gw.news_m(Loc.mk("%s ВСТУПАЕТ В ВОЙНУ НА СТОРОНЕ: %s%s", [Loc.name(_name(c.id)), Loc.name(_name(b)), Loc.t(" (ОБОРОННЫЙ ПАКТ)") if pact and not allied(c.id, b) else ""]), "alert_red")
			if c.is_player:
				gw.say(c, Loc.mk("По договору вы вступаете в войну: %s", [Loc.name(ca.name)]))
				gw.war_declared.emit(c.id, a)
		elif allied(c.id, a) and not allied(c.id, b):
			if c.is_player:
				gw.say(c, Loc.mk("Союзник %s начал войну: %s", [Loc.name(ca.name), Loc.name(cb.name)]))
			elif ca.is_player:
				_count("ally_waits_call")
			elif _rel_eff(c.id, b) < 20 and not has_treaty(c.id, b, "nap") and not truce_on(c.id, b) and calm_left(c.id, b) <= 0.0 and not conf_lock(c.id, b) and war_block(c.id, b).is_empty() and pile_gate(c.id, b, a, true) == "" and _offense_ok(c.id, a, b):
				_set_rel(c.id, b, Rel.WAR)
				_war_cleanup(c.id, b)
				_count("joined_ally")
				dlog(c.id, "вступает за %s против %s" % [_cname(a), _cname(b)], "нападение союзника (авто), отношение к жертве %d" % relation(c.id, b), 0.0, ["join", a, b])
				gw.news_m(Loc.mk("%s ВСТУПАЕТ В ВОЙНУ НА СТОРОНЕ: %s", [Loc.name(_name(c.id)), Loc.name(_name(a))]), "alert_red")
				if cb.is_player:
					gw.war_declared.emit(c.id, b)
	if ally != null:
		ally.on_war(a, b)
	_dip2_on_war(a, b)


func ai_accepts(ai: int, other: int, want: int) -> bool:
	var op: int = get_opinion(ai, other)
	var cur: int = get_rel(ai, other)
	match want:
		Rel.TRUCE, Rel.PEACE:
			if subj_peace_block(ai, other) != "":
				return false
			if cur == Rel.WAR and war_time(ai, other) < PEACE_MIN_WAR:
				return false
			if cur == Rel.WAR and _keeps_word(gw.country_by_id(ai), gw.country_by_id(other)):
				return false
			var ratio: float = strength(other) / maxf(1.0, strength(ai))

			var weary: bool = war_time(ai, other) > 240.0
			if ratio > 0.8 or weary or op > -20:
				return GameConfig.aggression < 2 or ratio > 1.0 or weary
			return false
		Rel.ALLIANCE:
			if cur == Rel.WAR or ally_conflict(ai, other) != "" or (care != null and care.traitor(other)):
				return false
			if rift != null and rift.tie_gate(ai, other) != "":
				return false
			op -= int(rift.tie_need(ai, other)[0]) if rift != null else 0

			for c: Country in gw.countries:
				if at_war(ai, c.id) and at_war(other, c.id):
					return true
			if grudge(ai, other):
				return false
			if friend_time(ai, other) < ALLY_SUSTAIN:
				return false
			return op >= 15 or (GameConfig.aggression == 0 and op >= 0)
	return false



func on_attack(attacker: int, owner: int) -> void :
	if rq != null and attacker > 0 and owner > 0 and attacker != owner and rq.on_hit(attacker, owner):
		return
	if attacker <= 0 or owner <= 0 or attacker == owner or at_war(attacker, owner) or allied(attacker, owner):
		return
	if truce_on(attacker, owner):


		add_opinion(owner, attacker, -5)
		_count("truce_hits")
		return

	if gw.game_time - float(since.get(key(attacker, owner), -999.0)) < 40.0:
		return




	if calm_left(attacker, owner) > 0.0 or calm_left(owner, attacker) > 0.0:
		var hk: String = "%d>%d" % [attacker, owner]
		calm_hits[hk] = int(calm_hits.get(hk, 0)) + 1
		add_opinion(owner, attacker, -5)
		_count("calm_hits")
		if int(calm_hits[hk]) < CALM_HITS:
			var ca: Country = gw.country_by_id(attacker)
			if ca != null and ca.is_player and int(calm_hits[hk]) == 1:
				gw.say(ca, Loc.mk("Удар по земле %s в мирное время: ещё %d — и это война", [Loc.name(_cname(owner)), CALM_HITS - 1]))
			return
		calm_hits.erase(hk)
		declare_war(attacker, owner, "нарушение мира")
		return
	if not war_block(attacker, owner).is_empty():
		add_opinion(owner, attacker, -8)
		_count("strike_blocked_hit")
		return
	declare_war(attacker, owner, "внезапный удар")




func _keeps_word(c: Country, o: Country) -> bool:
	if care == null:
		return false
	var side: int = int(care.joined_for.get("%d>%d" % [c.id, o.id], -1))
	if side <= 0 or not _alive(side) or not at_war(side, o.id) or not _defender(side, o.id):
		return false
	var lt: Array = care.lost_t.get(c.id, [])
	if strength(c.id) < strength(o.id) * 0.2 or war_time(c.id, o.id) > 900.0 or ( not lt.is_empty() and gw.game_time - float(lt[0]) < 300.0):
		return false
	_count("kept_word")
	dlog(c.id, "держит слово: не мирится с %s отдельно" % o.name, "%s ещё воюет" % _cname(side), strength(c.id) / maxf(1.0, strength(o.id)))
	return true


func _war_of_choice(c: Country, o: Country, why: String) -> void :
	_count("wars_choice")
	dlog(c.id, "война по выбору: %s" % o.name, why, war_power(c.id) / maxf(1.0, war_power(o.id)))
	if has_treaty(c.id, o.id, "nap"):
		_count("betrayals")
	declare_war(c.id, o.id, why)




func _sign(a: int, b: int, kind: String, quiet: bool = false) -> void :
	if kind == "subj_over" or kind == "subj_sub":

		if kind == "subj_over":
			make_subject(a, b, "vassal", "treaty")
		else:
			make_subject(b, a, "vassal", "treaty")
		return
	if subj_treaty_block(a, b, kind) != "":
		_count("subj_treaty_blocked")
		return
	if (kind == "alliance" or kind == "defense") and rift != null:
		var rg: String = rift.tie_gate(a, b)
		if rg == "":
			rg = rift.tie_gate(b, a)
		if rg != "":
			_count("rift_sign_blocked")
			gw.say2(a, b, Loc.mk("Договор не подписан: %s", [rg]))
			return
	if kind == "passage":
		grant_passage(b, a, quiet)
		return
	if (kind == "nap" or kind == "defense") and treaty_covered(a, b, kind) != "":
		return


	var own_ui: bool = gw.player != null and (a == gw.player.id or b == gw.player.id) and not quiet
	match kind:
		"trade":
			if gw.econ != null and not gw.econ.trading(a, b):
				gw.econ.set_trade(a, b, true)
		"alliance":
			_set_rel(a, b, Rel.ALLIANCE)
			if not quiet and not own_ui:
				gw.news_m(Loc.mk("СОЮЗ: %s И %s", [Loc.name(_name(a)), Loc.name(_name(b))]), "intercept_cyan")
		_:
			var k: String = key(a, b)
			var t: Dictionary = treaties.get(k, {})
			t[kind] = gw.game_time
			treaties[k] = t
			if not quiet and not own_ui:
				gw.news_m(Loc.mk("%s: %s И %s", [String(TREATY_INFO[kind]["name"]), Loc.name(_name(a)), Loc.name(_name(b))]), "grass_light")
	add_opinion(a, b, 5)
	_count("treaty_" + kind)
	dlog(a, "договор с %s: %s" % [_cname(b), kind], "подписан")
	_reveal(a, b)
	if gw.player != null and (a == gw.player.id or b == gw.player.id) and not quiet:
		gw.say(gw.player, Loc.mk("Договор подписан: %s — %s", [String(TREATY_INFO[kind]["name"]).to_lower(), Loc.name(_cname(a + b - gw.player.id))]))
		Sfx.ui("treaty_signed")
	gw.relations_changed.emit()


func give_aid(from: int, to: int, amount: int) -> String:
	var cf: Country = gw.country_by_id(from)
	if cf == null or not _alive(to) or from == to:
		return Loc.t("Страны нет")
	if at_war(from, to):
		return Loc.t("Помощь врагу невозможна")
	if amount < 100:
		return Loc.t("Минимум 100")
	if cf.money < amount:
		return Loc.t("Не хватает денег")
	var ct: Country = gw.country_by_id(to)
	cf.money -= amount
	ct.add_money(amount)
	var gain: int = gift_gain(from, to, amount)
	add_opinion(from, to, gain)
	if gw.econ != null:
		gw.econ.stat_add(cf, "spend", "aid", amount)
		gw.econ.stat_add(ct, "income", "aid", amount)
	_count("aid")
	_note_help(from, to, amount)
	_reveal(from, to)
	gw.news_m(Loc.mk("ПОМОЩЬ: %s → %s (%d)", [Loc.name(_name(from)), Loc.name(_name(to)), amount]), "grass_light")
	gw.relations_changed.emit()
	return ""



func _fulfil(d: Dictionary) -> void :
	var f: Country = gw.country_by_id(int(d["from"]))
	var v: Country = gw.country_by_id(int(d["to"]))
	if f == null or v == null:
		return
	match String(d["kind"]):
		"money":
			var n: int = mini(int(d["n"]), v.money)
			v.money -= n
			f.add_money(n)
			if gw.econ != null:
				gw.econ.stat_add(v, "spend", "tribute", n)
				gw.econ.stat_add(f, "income", "tribute", n)
		"res":
			var res: String = String(d["res"])
			var n2: int = mini(int(d["n"]), int(v.get(res)))
			v.set(res, int(v.get(res)) - n2)
			var room: int = gw.econ.room_for(f, res) if gw.econ != null else n2
			f.set(res, int(f.get(res)) + mini(n2, maxi(0, room)))
			if gw.econ != null:
				gw.econ.stat_res(v, res, "trade", - n2)
				gw.econ.stat_res(f, res, "trade", mini(n2, maxi(0, room)))
		"deposit":
			cede_area(v.id, f.id, d["cell"], CEDE_R)
		"break_alliance":
			break_alliance(v.id, int(d["third"]))
		"cancel_visa":
			cancel_treaty(v.id, int(d["third"]), "visa")
		"vassal", "puppet":
			make_subject(f.id, v.id, String(d["kind"]), "ultimatum")
			for c3: Country in gw.countries:
				if c3.id != f.id and c3.id != v.id and not c3.eliminated:
					add_opinion(f.id, c3.id, -3)
	add_opinion(f.id, v.id, -4)
	_count("demands_accepted")
	gw.news_m(Loc.mk("УЛЬТИМАТУМ ПРИНЯТ: %s → %s", [Loc.name(_name(f.id)), Loc.name(_name(v.id))]), "amber")
	if f.is_player:
		gw.say(f, "%s уступает: %s" % [v.name, Loc.msg(d["head"]) if d.has("head") else String(d["text"]).split(". Иначе")[0]])



func _refused(d: Dictionary) -> void :
	var a: int = int(d["from"])
	var b: int = int(d["to"])
	add_opinion(a, b, -15)
	_count("demands_refused")
	_next_dem[a] = maxf(float(_next_dem.get(a, 0.0)), gw.game_time + 360.0)
	gw.news_m(Loc.mk("УЛЬТИМАТУМ ОТВЕРГНУТ: %s → %s", [Loc.name(_name(a)), Loc.name(_name(b))]), "alert_red")
	if not _alive(a) or not _alive(b) or at_war(a, b):
		return
	var ca: Country = gw.country_by_id(a)
	var war: bool = String(d["conseq"]) == "war"
	var cb2: Country = gw.country_by_id(b)
	var weak: bool = strength(a) < strength(b) * (0.8 if cb2.is_player else 0.9) or ( not cb2.is_player and war_power(a) < war_power(b))
	if war and not ca.is_player and (weak or not war_allowed(a, b, true)):
		war = false
	if war:
		if String(d["kind"]) == "deposit":
			war_goals["%d>%d" % [a, b]] = {"cell": d["cell"], "res": String(d["res"]), "since": gw.game_time}
		declare_war(a, b, "ультиматум отвергнут")
	else:


		var trd: Variant = gw.econ.get("trd") if gw.econ != null else null
		var hard: bool = float(_p(a)["aggr"]) >= 0.65 or float(_p(a)["trade"]) >= 0.65
		if not ca.is_player and not hard and trd != null and trd.has_method("sanctions_by") and (trd.sanctions_by(a, b) as Array).is_empty()\
		and String(trd.impose_sanction(a, b, String(d.get("res", "")) if String(d.get("res", "")) != "" and String(trd.can_sanction(a, b, String(d.get("res", "")), true)) == "" else "")) == "":
			_count("demand_sanction")
		else:
			set_embargo(a, b, true)




func demand(from: int, to: int, kind: String, params: Dictionary = {}) -> String:
	if not DEMAND_KINDS.has(kind):
		return Loc.t("Нет такого требования")
	if from == to or not _alive(from) or not _alive(to):
		return Loc.t("Страны нет")
	if at_war(from, to):
		return Loc.t("Вы уже воюете")
	var cf: Country = gw.country_by_id(from)
	if cf.is_player:
		var wait: float = float(_player_ask_t.get(to * 1000 + from, 0.0)) - gw.game_time
		if wait > 0.0:
			return Loc.t("Слишком часто: ещё %d с") % ceili(wait)
	var d: Dictionary = _make_demand(from, to, kind, params)
	var why: String = _demand_ok(d)
	if why != "":
		return Loc.t("Требование невыполнимо: %s") % [why.to_lower()]
	if cf.is_player:
		_player_ask_t[to * 1000 + from] = gw.game_time + PLAYER_ASK_GAP
	var ct: Country = gw.country_by_id(to)
	if ct.is_player:
		_issue(d)
		return Loc.t("Ультиматум отправлен")
	_count("demands")
	_count("demands_by_player" if cf.is_player else "demands_ai_ai")
	_reveal(from, to)
	if ai_yields(to, from, d):
		_fulfil(d)
		return ""
	_refused(d)
	return Loc.t("%s отвергает требование%s") % [ct.name, Loc.t(" — война") if at_war(from, to) else Loc.t(" — эмбарго")]





func on_incident(victim_id: int, culprit_id: int, kind: String, severity: int) -> void :
	if victim_id == culprit_id or not _alive(victim_id) or not _alive(culprit_id):
		return
	if truce_on(victim_id, culprit_id):
		_count("truce_incidents")
		return
	var sev: int = clampi(severity, 1, 10)
	add_opinion(victim_id, culprit_id, -4 * sev)
	_count("incidents")
	_count("inc_%d_%d" % [victim_id, culprit_id])
	_reveal(victim_id, culprit_id)
	if sev >= 3:
		gw.news_m(Loc.mk("ИНЦИДЕНТ (%s): %s ОБВИНЯЕТ — %s", [String(INCIDENT_NAMES.get(kind, kind)).to_upper(), Loc.name(_name(victim_id)), Loc.name(_name(culprit_id))]), "amber")
	var v: Country = gw.country_by_id(victim_id)
	if v.is_player or at_war(victim_id, culprit_id):
		return
	var P: Dictionary = _p(victim_id)
	if has_treaty(victim_id, culprit_id, "visa") and (float(P["caution"]) > 0.4 or sev >= 4):
		cancel_treaty(victim_id, culprit_id, "visa")
	if relation(victim_id, culprit_id) < -40 and float(P["aggr"]) > 0.6 and war_allowed(victim_id, culprit_id, true):
		declare_war(victim_id, culprit_id, "инцидент: %s" % [String(INCIDENT_NAMES.get(kind, kind))])
		return
	if sev >= 3 and not _has_demand(victim_id, culprit_id):
		var cp: Country = gw.country_by_id(culprit_id)
		if cp.is_player and (gw.game_time - _player_dem_last < 120.0 or gw.game_time < FIRST_PLAYER_DEMAND):
			return
		var comp: int = 150 * sev if not cp.is_player else clampi(mini(150 * sev, _player_cap(cp)) / 50 * 50, 100, 1500)
		var war: bool = float(P["aggr"]) >= 0.55 and war_allowed(victim_id, culprit_id, false)
		var d: Dictionary = _make_demand(victim_id, culprit_id, "money", {"n": comp, "conseq": "war" if war else "embargo"})
		d["head"] = Loc.mk("%s требует компенсацию за инцидент: %d денег", [v.name, comp])
		d["text"] = Loc.mk("%s. Иначе — %s", [d["head"], Loc.mk("ВОЙНА") if war else Loc.mk("ЭМБАРГО")])
		if cp.is_player:
			_player_dem_t = maxf(_player_dem_t, gw.game_time + PLAYER_DEMAND_GAP[0])
		_issue(d)



func _overfly_tick() -> void :
	if gw.mil == null:
		return
	var now: float = gw.game_time
	for dr: Drone in gw.mil.drones:
		if (dr.kind != 0 and dr.kind != 2) or not dr.airborne() or dr.state == Drone.State.DONE:
			continue
		var x: int = floori(dr.pos.x / GameWorld.CELL)
		var y: int = floori(dr.pos.y / GameWorld.CELL)
		if not gw.data.inside(x, y):
			continue
		var o: int = gw.data.get_owner_id(x, y)
		if may_cross(dr.country_id, o) or not _alive(o):
			continue
		var k: String = "%d>%d" % [dr.country_id, o]
		if now - float(_overfly_last.get(k, -1000000000.0)) < OVERFLY_GAP:
			continue
		_overfly_last[k] = now
		_count("overfly")
		on_incident(o, dr.country_id, "border", 2)
		var cp: Country = gw.country_by_id(dr.country_id)
		if cp != null and cp.is_player:
			gw.say(cp, Loc.mk("БПЛА над %s без права прохода: инцидент", [Loc.name(_cname(o))]))


func make_subject(over: int, sub: int, kind: String, why: String = "") -> void :
	if over == sub or not _alive(over) or not _alive(sub) or is_subject(over) or not SUBJ_NAMES.has(kind):
		return
	var cs: Country = gw.country_by_id(sub)
	var co: Country = gw.country_by_id(over)
	for s2: int in subjects_of(sub):
		_free_subject(s2, true)
	if subjects.has(sub):
		_free_subject(sub, true)
	if at_war(over, sub) or truce_on(over, sub):
		_set_rel(over, sub, Rel.PEACE)
	peace_t.erase(key(over, sub))
	subjects[sub] = {"over": over, "kind": kind, "since": gw.game_time, "liberty": 0.0}
	_drop_covered_offers(over, sub)
	if why == "conference":
		subjects[sub]["young"] = gw.game_time + YOUNG_T
	_trib_earned[sub] = cs.earned
	_subj_pair[sub] = gw.game_time + SUBJ_PAIR_GAP

	for c: Country in gw.countries:
		if c.id == over or c.id == sub or c.eliminated:
			continue
		if at_war(sub, c.id) and (allied(over, c.id) or subject_of(c.id) == over):
			_set_rel(sub, c.id, Rel.TRUCE)
		if allied(sub, c.id) and at_war(over, c.id):
			break_alliance(sub, c.id)
		if kind == "puppet" and allied(sub, c.id):
			break_alliance(sub, c.id)
	_dip2_follow = true
	for eid: int in co.at_war.keys():
		if eid != sub and not at_war(sub, eid) and _alive(eid) and not truce_on(sub, eid):
			_subj_join(sub, eid, over, Loc.t("ВАССАЛ"))
	for eid2: int in cs.at_war.keys():
		if eid2 != over and not at_war(over, eid2) and _alive(eid2) and not allied(over, eid2) and not truce_on(over, eid2) and calm_left(over, eid2) <= 0.0:
			_subj_join(over, eid2, sub, Loc.t("ЗАЩИТА ВАССАЛА"))
	_dip2_follow = false
	add_opinion(over, sub, 10 if kind == "vassal" else 0)
	_count("subj_" + kind)
	_reveal(over, sub, true)
	if cs.is_player or co.is_player:
		Sfx.ui("vassal_sworn")
	gw.news.emit(Loc.t("%s СТАНОВИТСЯ %s: %s") % [_name(sub), Loc.t("ВАССАЛОМ") if kind == "vassal" else Loc.t("МАРИОНЕТКОЙ"), _name(over)] + ((" (" + Loc.t(String(LOC_SUBJ_WHY.get(why, why))) + ")") if why != "" else ""), "amber")
	if cs.is_player:
		gw.say(cs, Loc.mk("Вы — %s %s: дань %d %% дохода, войны вместе с ними", [Loc.t("вассал") if kind == "vassal" else Loc.t("марионетка"), Loc.name(co.name), roundi(float(TRIBUTE[kind]) * 100.0)]))
	elif co.is_player:
		gw.say(co, Loc.mk("%s — %s: дань %d %% их дохода, воюют на вашей стороне", [Loc.name(cs.name), Loc.t("ваш вассал") if kind == "vassal" else Loc.t("ваша марионетка"), roundi(float(TRIBUTE[kind]) * 100.0)]))
	_stripe_sync()
	gw.relations_changed.emit()
	pending_changed.emit()




func seek_independence(sub: int) -> String:
	var over: int = subject_of(sub)
	if over <= 0:
		return Loc.t("Вы и так независимы")
	var co: Country = gw.country_by_id(over)
	var ratio: float = strength(over) / maxf(1.0, strength(sub))
	_free_subject(sub)
	add_opinion(over, sub, -30)
	_count("subj_independence")
	gw.news_m(Loc.mk("%s ОБЪЯВЛЯЕТ НЕЗАВИСИМОСТЬ ОТ %s", [Loc.name(_name(sub)), Loc.name(_name(over))]), "amber")
	if co != null and not co.is_player and ratio > 1.3 and float(_p(over)["aggr"]) > 0.35 and GameConfig.aggression > 0:
		peace_t.erase(key(over, sub))
		declare_war(over, sub, "мятеж вассала")
		return Loc.t("%s не отпускает: война") % co.name
	if co != null and co.is_player:
		gw.say(co, Loc.mk("%s больше не ваш вассал", [Loc.name(_cname(sub))]))
	return ""



func _dip2_on_war(a: int, b: int) -> void :
	if conf != null:
		conf.on_war(a, b)
	_dip2_follow = true
	for sid: int in subjects.keys():
		if not _alive(sid):
			continue
		var ov: int = subject_of(sid)

		if ov == a and sid != b and not truce_on(sid, b):
			_subj_join(sid, b, a, Loc.t("ВАССАЛ"))
		elif ov == b and sid != a and not truce_on(sid, a):
			_subj_join(sid, a, b, Loc.t("ВАССАЛ"))
	var ob: int = subject_of(b)
	if ob > 0 and ob != a and not allied(ob, a) and not truce_on(ob, a) and calm_left(ob, a) <= 0.0:
		_subj_join(ob, a, b, Loc.t("ЗАЩИТА ВАССАЛА"))
	_dip2_follow = false




func _dip2_subj_tick() -> void :
	var now: float = gw.game_time
	for sid: int in subjects.keys():
		if not subjects.has(sid):
			continue
		var over: int = subject_of(sid)
		if not _alive(sid) or not _alive(over):
			subjects.erase(sid)
			_trib_earned.erase(sid)
			continue
		var cs: Country = gw.country_by_id(sid)
		var s: Dictionary = subjects[sid]

		var ratio: float = strength(over) / maxf(1.0, strength(sid))
		var d: float = 6.0 if ratio < 1.3 else (2.0 if ratio < 2.2 else -2.0)
		var co: Country = gw.country_by_id(over)
		for eid: int in co.at_war.keys():
			if strength(eid) > strength(over) * 1.2:
				d += 2.0
				break
		d -= float(get_opinion(sid, over)) / 30.0
		if String(s["kind"]) == "puppet":
			d *= 0.5
		s["liberty"] = clampf(float(s["liberty"]) + d, 0.0, 100.0)
		if float(s["liberty"]) >= 100.0 and not cs.is_player and strength(sid) > strength(over) * 0.55:
			seek_independence(sid)
			continue


		_dip2_follow = true
		for eid2: int in co.at_war.keys():
			if eid2 != sid and not at_war(sid, eid2) and not truce_on(sid, eid2) and _alive(eid2) and not allied(sid, eid2):
				_subj_join(sid, eid2, over, Loc.t("МАРИОНЕТКА") if String(s["kind"]) == "puppet" else Loc.t("ВАССАЛ"))
		_dip2_follow = false
	if now >= _trib_t:
		_trib_t = now + TRIBUTE_DT
		for sid2: int in subjects.keys():
			var cs2: Country = gw.country_by_id(sid2)
			var co2: Country = gw.country_by_id(subject_of(sid2))
			if cs2 == null or co2 == null:
				continue
			var base: int = int(_trib_earned.get(sid2, cs2.earned))
			var n: int = mini(int(float(maxi(0, cs2.earned - base)) * float(TRIBUTE.get(subject_kind(sid2), 0.1))), maxi(0, cs2.money))
			_trib_earned[sid2] = cs2.earned
			if n <= 0:
				continue
			cs2.money -= n
			co2.add_money(n)
			_trib_earned[sid2] = cs2.earned
			if gw.econ != null:
				gw.econ.stat_add(cs2, "spend", "tribute", n)
				gw.econ.stat_add(co2, "income", "tribute", n)
			_count("tribute", n)





func _obligation(c: int, x: int, e: int) -> String:
	if subject_of(c) == x:
		return "overlord"
	if allied(c, x):
		return "alliance"
	if ally != null and ally.same(c, x):
		return "alliance"
	if has_treaty(c, x, "defense") and _defender(x, e):
		return "defense"
	return ""



func _defender(x: int, e: int) -> bool:
	for i in range(wars_log.size() - 1, -1, -1):
		var w: Array = wars_log[i]
		if (int(w[1]) == e and int(w[2]) == x):
			return true
		if (int(w[1]) == x and int(w[2]) == e):
			return false


	if care != null:
		var s: int = int(care.joined_for.get("%d>%d" % [e, x], -1))
		if s > 0 and s != x and s != e:
			for j in range(wars_log.size() - 1, -1, -1):
				var w2: Array = wars_log[j]
				if int(w2[1]) == s and int(w2[2]) == x:
					return true
				if int(w2[1]) == x and int(w2[2]) == s:
					return false
	return false




func _join_code(c: int, e: int) -> String:
	if not _alive(c) or not _alive(e) or c == e:
		return "none"
	if allied(c, e) or subject_of(e) == c or subject_of(c) == e:
		return "union"
	if ally != null and ally.same(c, e):
		return "alliance"
	if has_treaty(c, e, "nap") or has_treaty(c, e, "defense"):
		return "pact"
	if truce_on(c, e):
		return "truce"
	if calm_left(c, e) > 0.0:
		return "calm"
	if ally_of_ally(c, e) > 0:
		return "ally_ally"
	return ""



func _join_block(c: int, e: int) -> String:
	if not _alive(c) or not _alive(e) or c == e:
		return Loc.t("Страны нет")
	if allied(c, e) or subject_of(e) == c or subject_of(c) == e:
		return Loc.t("союз с %s") % _cname(e)
	if ally != null and ally.same(c, e):
		return Loc.t("альянс с %s") % _cname(e)
	if has_treaty(c, e, "nap") or has_treaty(c, e, "defense"):
		return Loc.t("пакт с %s") % _cname(e)
	if truce_on(c, e):
		return Loc.t("перемирие с %s") % _cname(e)
	if calm_left(c, e) > 0.0:
		return Loc.t("недавний мир с %s") % _cname(e)
	var d0: int = ally_of_ally(c, e)
	if d0 > 0:
		return Loc.t("%s — союзник союзника (%s)") % [_cname(e), _cname(d0)]
	return ""



func _losing_badly(c: int) -> bool:
	var cc: Country = gw.country_by_id(c)
	if cc == null:
		return true
	for eid: int in cc.at_war.keys():
		if _alive(eid) and war_power(c) < war_power(eid) * 0.5:
			return true
	return false


func _call_result(c: int, x: int, e: int, ans: String) -> void :
	dlog(c, "призыв %s против %s: %s" % [_cname(x), _cname(e), ans], "обязательство «%s», %s" % [_obligation(c, x, e), Loc.t("они защищаются") if _defender(x, e) else Loc.t("они напали")], 0.0, ["call", x, e, ans])
	match ans:
		"join":
			if not war_block(c, e).is_empty():
				return
			_join_war(c, e, x, Loc.t("ПРИЗЫВ СОЮЗНИКА"))
			add_opinion(c, x, 8)
		"aid":
			if send_package(c, x, e) <= 0:
				if _defender(x, e):
					_grievance(x, c, e)
				return
			add_opinion(c, x, 3)
		"sanction":
			var trd: Variant = gw.econ.get("trd") if gw.econ != null else null
			if trd != null and String(trd.impose_sanction(c, e, "")) == "":
				_count("pile_sanction")
				add_opinion(c, x, 3)
				gw.news_m(Loc.mk("%s НЕ ВСТУПАЕТ В ВОЙНУ, НО ВВОДИТ САНКЦИИ ПРОТИВ %s", [Loc.name(_name(c)), Loc.name(_name(e))]), "amber")
			elif not _defender(x, e):
				_decline_offense(x, c, e)
		"decline":
			_decline_offense(x, c, e)
		_:
			if _defender(x, e):
				_grievance(x, c, e)
			else:
				_decline_offense(x, c, e)



func _decline_offense(x: int, c: int, e: int) -> void :
	add_opinion(x, c, -3)
	_count("ally_skip_offense")
	dlog(c, "не идёт в нападение %s на %s" % [_cname(x), _cname(e)], _offense_why(c, x, e), 0.0, ["skip_off", x, e])
	var cx: Country = gw.country_by_id(x)
	var cc: Country = gw.country_by_id(c)
	if cx != null and cx.is_player and cc != null and not cc.is_player and (care == null or not care.note(cc, "skip_off", _cname(e), "", cx.id)):
		gw.say(cx, Loc.mk("%s не пойдёт с вами в нападение на %s", [Loc.name(cc.name), Loc.name(_cname(e))]))



func _grievance(x: int, c: int, e: int) -> void :
	var k: String = "%d>%d" % [c, x]
	var n: int = int(refusals.get(k, 0)) + 1
	dlog(x, "обида на %s (отказ %d)" % [_cname(c), n], "нет помощи против %s" % _cname(e), 0.0, ["grievance", x, c])
	refusals[k] = n
	var ally: bool = allied(c, x)
	add_opinion(x, c, -10 if ally else -6)
	_count("refusals")
	var cc: Country = gw.country_by_id(c)
	var cx: Country = gw.country_by_id(x)
	if cc.is_player and not cx.is_player:
		notes.append({"id": _dem_id, "from": x, "to": c, "vs": e, "until": gw.game_time + NOTE_T, "n": n})
		_dem_id += 1
		gw.say(cc, Loc.mk("НОТА ПРОТЕСТА: %s — вы не помогли в войне с %s (отказ %d из 3)", [Loc.name(cx.name), Loc.name(_cname(e)), n]))
		Sfx.ui("protest_note")
		pending_changed.emit()
	elif cx.is_player:
		gw.say(cx, Loc.mk("%s не вступит в войну с %s", [Loc.name(cc.name), Loc.name(_cname(e))]))
	if n >= 2:
		add_opinion(x, c, -10)
		gw.news_m(Loc.mk("ОХЛАЖДЕНИЕ: %s НЕДОВОЛЬНА %s", [Loc.name(_name(x)), Loc.name(_name(c))]), "amber")
	if n >= 3:
		refusals.erase(k)
		_count("dip2_broken")
		var broke: bool = true
		if ally:
			break_alliance(x, c)
		elif has_treaty(x, c, "defense"):
			cancel_treaty(x, c, "defense")
		else:
			broke = false
		if broke:
			gw.news_m(Loc.mk("%s РАЗРЫВАЕТ ДОГОВОР С %s: НЕТ ПОМОЩИ В ВОЙНЕ", [Loc.name(_name(x)), Loc.name(_name(c))]), "alert_red")




func _human_call(me: int, c: int, e: int, ck: String) -> String:
	var why: String = _join_block(c, e)
	if why != "":
		return Loc.t("%s не может вступить: %s") % [_cname(c), why]
	for k: Dictionary in calls:
		if int(k["from"]) == me and int(k["to"]) == c and int(k["vs"]) == e:
			return Loc.t("Просьба уже ждёт ответа %s") % _cname(c)
	_called[ck] = gw.game_time
	_count("calls_human")
	calls.append({"id": _dem_id, "from": me, "to": c, "vs": e, "until": gw.game_time + CALL_T, "ask": true, "h": true})
	_dem_id += 1
	_reveal(me, c)
	gw.say(c, Loc.mk("ПРОСЬБА О ПОМОЩИ: %s просит вступить в войну с %s", [Loc.name(_cname(me)), Loc.name(_cname(e))]))
	if gw.country_by_id(c) == gw.player:
		Sfx.ui("call_to_arms")
	gw.offer_received.emit()
	pending_changed.emit()
	return Loc.t("Просьба отправлена: %s ответит во «Входящих» (%d с)") % [_cname(c), int(CALL_T)]




func call_candidates(me: int, e: int) -> Array:
	var out: Array = []
	if not at_war(me, e):
		return out
	for c: Country in gw.countries:
		var cid: int = c.id
		if cid == me or cid == e or not _alive(cid) or c.capital_id < 0 or at_war(cid, e) or at_war(me, cid) or truce_on(me, cid):
			continue
		var tie: String = call_tie(me, cid)
		if tie == "":
			continue
		out.append(cid)
	out.sort_custom( func(a: int, b: int) -> bool:
		var ta: int = 0 if _obligation(a, me, e) != "" else 1
		var tb: int = 0 if _obligation(b, me, e) != "" else 1
		if ta != tb:
			return ta < tb
		if relation(a, me) != relation(b, me):
			return relation(a, me) > relation(b, me)
		return a < b)
	return out



func call_tie(me: int, c: int) -> String:
	if subject_of(c) == me:
		return Loc.t("ВАССАЛ")
	if allied(me, c):
		return Loc.t("СОЮЗ")
	if ally != null and ally.same(me, c):
		return Loc.t("АЛЬЯНС")
	if has_treaty(me, c, "defense"):
		return Loc.t("ПАКТ")
	if relation(me, c) >= 30 and not is_subject(c):
		return Loc.t("ДРУГ")
	return ""



func ask_refusal(c: int, x: int, e: int) -> String:
	if is_subject(c):
		return Loc.t("войну за неё решает %s") % _cname(subject_of(c))
	if (war_power(c) + war_power(x)) < war_power(e) * 0.8:
		return Loc.t("%s слишком сильна") % _cname(e)
	if relation(c, x) < 20:
		return Loc.t("отношения с вами слабые (%d)") % relation(c, x)
	if relation(c, e) > 20:
		return Loc.t("не хочет ссориться с %s") % _cname(e)
	var cc: Country = gw.country_by_id(c)
	if cc != null and not cc.at_war.is_empty():
		return Loc.t("уже воюет")
	return Loc.t("не видит выгоды")



func support_targets(me: int, side: int) -> Array:
	var out: Array = []
	var cs: Country = gw.country_by_id(side)
	if cs == null or me == side or not _alive(me) or at_war(me, side) or is_subject(me):
		return out
	for eid: int in cs.at_war.keys():
		if eid == me or at_war(me, eid) or not _alive(eid) or truce_on(side, eid):
			continue
		if _join_block(me, eid) != "":
			continue
		out.append(eid)
	return out



func support_war(me: int, side: int, enemy: int) -> String:
	if not _alive(side) or not _alive(enemy):
		return Loc.t("Страны нет")
	if not at_war(side, enemy):
		return Loc.t("%s не воюет с %s") % [_cname(side), _cname(enemy)]
	if at_war(me, enemy):
		return Loc.t("Вы уже воюете с %s") % _cname(enemy)
	if is_subject(me):
		return Loc.t("Вассал не объявляет войн сам: решает %s") % _cname(subject_of(me))
	var why: String = _join_block(me, enemy)
	if why != "":
		return Loc.t("Нельзя: %s") % [why]
	var wb: String = war_block_why(me, enemy)
	if wb != "":
		return Loc.t("Нельзя: %s") % [wb]
	declare_war(me, enemy, "в поддержку %s" % [_cname(side)])
	if not at_war(me, enemy):
		return Loc.t("Война не началась")
	_helped["%d>%d" % [me, side]] = gw.game_time
	refusals.erase("%d>%d" % [me, side])
	add_opinion(me, side, 12)
	_count("support_war")
	var cs: Country = gw.country_by_id(side)
	if cs != null and not cs.is_player:
		gw.news_m(Loc.mk("%s ВСТУПАЕТ В ВОЙНУ НА СТОРОНЕ %s: %s", [Loc.name(_name(me)), Loc.name(_name(side)), Loc.name(_name(enemy))]), "alert_red")
	return ""



func _recruit_ask_ok(c: Country, p: Country, e: int) -> bool:
	if not _alive(p.id) or p.id == e or at_war(p.id, e) or at_war(p.id, c.id) or truce_on(p.id, c.id):
		return false
	if relation(c.id, p.id) < 30 or _obligation(p.id, c.id, e) != "" or _join_block(p.id, e) != "":
		return false
	if not p.at_war.is_empty():
		return false
	for k: Dictionary in calls:
		if int(k["to"]) == p.id:
			return false
	return true



func ally_land_ok(cid: int, owner: int) -> bool:
	return owner > 0 and owner != cid and _alive(owner) and _alive(cid) and (allied(cid, owner) or subject_of(owner) == cid)



func note_ally_fac(f: Facility) -> void :
	if f == null:
		return
	var host: Facility = f.parent if f.parent != null else f
	var hc: Vector2i = host.cell + host.size / 2
	if not gw.data.inside(hc.x, hc.y):
		return
	var o: int = gw.data.get_owner_id(hc.x, hc.y)
	if ally_land_ok(f.country_id, o):
		ally_fac[f.id] = o
		_count("ally_fac_built")





func _ally_fac_tick() -> void :
	if ally_fac.is_empty() or gw.mil == null:
		return
	var fl: Array = gw.mil.facilities
	var handed: Dictionary = {}
	for fid: int in ally_fac.keys():
		var f: Facility = fl[fid] if fid >= 0 and fid < fl.size() else null
		if f == null or f.id != fid or not gw.mil.alive(f):
			ally_fac.erase(fid)
			continue
		var host: Facility = f.parent if f.parent != null else f
		var hc: Vector2i = host.cell + host.size / 2
		var o: int = gw.data.get_owner_id(hc.x, hc.y) if gw.data.inside(hc.x, hc.y) else 0
		if o == f.country_id or o <= 0:
			ally_fac.erase(fid)
			continue
		if ally_land_ok(f.country_id, o):
			ally_fac[fid] = o
			continue
		var was: int = f.country_id
		var pay: int = 0
		var co: Country = gw.country_by_id(o)
		if co != null and not at_war(was, o):
			pay = mini(co.money, int(float(gw.mil.cost_of(f.kind)) * ALLY_FAC_SHARE))
			co.money -= pay
			var cw: Country = gw.country_by_id(was)
			if cw != null:
				cw.money += pay
		f.country_id = o
		f.queued.clear()
		ally_fac.erase(fid)
		_count("ally_fac_handed")
		var hk: String = "%d>%d" % [was, o]
		var e: Array = handed.get(hk, [0, 0])
		handed[hk] = [int(e[0]) + 1, int(e[1]) + pay]
	if handed.is_empty():
		return
	for hk2: String in handed:
		var ab: PackedStringArray = hk2.split(">")
		var a: int = int(ab[0])
		var b: int = int(ab[1])
		var ca: Country = gw.country_by_id(a)
		var n: int = int(handed[hk2][0])
		var m: int = int(handed[hk2][1])
		if ca != null and ca.is_player:
			gw.say(ca, Loc.n(n, "Союза с %s больше нет: %d ваш объект на их земле отошёл им%s", "Союза с %s больше нет: %d ваших объекта на их земле отошли им%s", 
				"Союза с %s больше нет: %d ваших объектов на их земле отошли им%s") % [Loc.name(_cname(b)), n, (Loc.t(", компенсация %d") % m) if m > 0 else ""])
	gw.changed.emit()



func _ai_aid_tick(c: Country, P: Dictionary) -> void :
	if care != null:
		return
	var now: float = gw.game_time
	for x: Country in gw.countries:
		if x.id == c.id or not _alive(x.id) or x.at_war.is_empty() or at_war(c.id, x.id):
			continue
		if not (allied(c.id, x.id) or subject_of(x.id) == c.id or (has_treaty(c.id, x.id, "defense") and relation(c.id, x.id) >= 50)):
			continue
		var ak: String = "%d>%d" % [c.id, x.id]
		if now < float(_aid_next.get(ak, 0.0)):
			continue
		var foe: int = -1
		var fs: float = 0.0
		for eid: int in x.at_war.keys():
			if strength(eid) > fs:
				fs = strength(eid)
				foe = eid
		var struggling: bool = fs > strength(x.id) * 0.9 or x.money < 1500 or x.lost > 0
		if not struggling or foe < 0 or war_time(x.id, foe) < CALL_AFTER:
			continue
		_aid_next[ak] = now + AID_GAP * (1.3 - float(P["trade"]) * 0.5)
		send_package(c.id, x.id, foe)
		return




func send_package(from: int, to: int, vs: int, scale: float = 1.0, care_pkg: bool = false) -> int:
	var cf: Country = gw.country_by_id(from)
	var ct: Country = gw.country_by_id(to)
	if cf == null or ct == null:
		return 0
	var P: Dictionary = _p(from)
	var sent: Array = []
	var value: int = 0
	var reserve: int = 1200
	if cf.is_player:
		reserve = 0
	var spare: int = cf.money - reserve
	if spare >= 400:
		var n: int = clampi(int(float(spare) * (0.15 + float(P["trade"]) * 0.15) * scale / 100.0) * 100, 300, roundi(2500.0 * maxf(1.0, scale)))
		if cf.is_player:
			n = clampi(int(float(cf.money) * 0.15 / 100.0) * 100, 500, 3000)
		if n <= spare and _move(from, to, "money", n) > 0:
			sent.append("деньги %d" % n)
			value += n
	if not cf.is_player:
		for t: int in [Military.MT_BALLISTIC, Military.MT_CRUISE]:
			var keep: int = 2 if t == Military.MT_BALLISTIC else 4
			if cf.missile_stock[t] > keep and aid_carrier(ct, t):
				var m: int = _move(from, to, "missile_b" if t == Military.MT_BALLISTIC else "missile_c", mini(2, cf.missile_stock[t] - keep))
				if m > 0:
					sent.append("ракеты ×%d" % m)
					value += aid_value("missile_b" if t == Military.MT_BALLISTIC else "missile_c", m)
		if gw.mil.parked_count(from) >= 6:
			var dn: int = _move(from, to, "drones", 2)
			if dn > 0:
				sent.append("дроны ×%d" % dn)
				value += aid_value("drones", dn)
		var lack: Array = gw.econ.scarce_of(ct) if gw.econ != null else []
		for res: String in ["fuel", "metal", "titanium", "food"]:
			if not lack.has(res) and int(ct.get(res)) < 15:
				lack.append(res)
		if ct.food < 15:
			lack.erase("food")
			lack.push_front("food")
		var kinds: int = 0
		for res2: Variant in lack:
			var r: String = String(res2)
			if not AID_KINDS.has(r) or int(cf.get(r)) < 30:
				continue
			var rn: int = _move(from, to, r, mini(20, int(cf.get(r)) - 20))
			if rn > 0:
				sent.append("%s ×%d" % [String(Economy.RES_NAMES.get(r, r)).to_lower(), rn])
				value += aid_value(r, rn)
				kinds += 1
				if kinds >= 2:
					break
	last_package = ", ".join(PackedStringArray(sent))
	if value <= 0:
		return 0
	_note_help(from, to, value)
	_count("aid_packages")
	if care_pkg:
		_count("care_war")
	dlog(from, "помощь → %s" % _cname(to), ", ".join(PackedStringArray(sent)), float(value))
	gw.news_m(Loc.mk("ПОМОЩЬ: %s → %s (%s)", [Loc.name(_name(from)), Loc.name(_name(to)), ", ".join(PackedStringArray(sent))]), "grass_light")
	if ct.is_player:
		gw.say(ct, Loc.mk("Помощь от %s: %s", [Loc.name(cf.name), ", ".join(PackedStringArray(sent))]))
	gw.relations_changed.emit()
	return value




func aid_value(what: String, n: int) -> int:
	match what:
		"money":
			return n
		"missile_b":
			return int(Military.MT_COST[Military.MT_BALLISTIC]) * n
		"missile_c":
			return int(Military.MT_COST[Military.MT_CRUISE]) * n
		"missile_sam":
			return int(Military.MT_COST[Military.MT_SAM]) * n
		"drones":
			return int(gw.mil.drone_cost(false).get("money", 250)) * n
	var pr: int = gw.econ.market_price(what) if gw.econ != null else 20
	return pr * n



func _move(from: int, to: int, what: String, n: int) -> int:
	var cf: Country = gw.country_by_id(from)
	var ct: Country = gw.country_by_id(to)
	if cf == null or ct == null or n <= 0:
		return 0
	match what:
		"money":
			var k: int = mini(n, cf.money)
			if k <= 0:
				return 0
			cf.money -= k
			ct.money += k
			if gw.econ != null:
				gw.econ.stat_add(cf, "spend", "aid", k)
				gw.econ.stat_add(ct, "income", "aid", k)
			return k
		"missile_b", "missile_c", "missile_sam":
			var mt: int = aid_mtype(what)
			if not aid_carrier(ct, mt):
				return 0
			return gw.mil.transfer_missiles(cf, ct, mt, n)
		"drones":
			return gw.mil.transfer_drones(cf, ct, n)
	if not AID_KINDS.has(what):
		return 0
	var room: int = gw.econ.room_for(ct, what) if gw.econ != null else n
	var k2: int = mini(mini(n, int(cf.get(what))), maxi(0, room))
	if k2 <= 0:
		return 0
	if gw.econ != null and gw.rail != null and cf.capital_id >= 0 and ct.capital_id >= 0 and gw.rail.has_link(cf.capital_id, ct.capital_id):

		cf.set(what, int(cf.get(what)) - k2)
		gw.econ.stat_res(cf, what, "trade", - k2)
		if gw.econ._send(cf, ct, what, k2, 0, true) != "":
			return k2
		cf.set(what, int(cf.get(what)) + k2)
		gw.econ.stat_res(cf, what, "trade", k2)
	cf.set(what, int(cf.get(what)) - k2)
	ct.set(what, int(ct.get(what)) + k2)
	if gw.econ != null:
		gw.econ.stat_res(cf, what, "trade", - k2)
		gw.econ.stat_res(ct, what, "trade", k2)
	return k2



func aid_options(from: int, to: int) -> Array:
	var out: Array = []
	var cf: Country = gw.country_by_id(from)
	var ct: Country = gw.country_by_id(to)
	if cf == null or ct == null:
		return out
	out.append({"what": "money", "icon": "res_money", "label": Loc.t("ДЕНЬГИ"), "have": cf.money, "max": cf.money, "step": 100, "each": 1, "why": ""})
	for t: int in [Military.MT_BALLISTIC, Military.MT_CRUISE, Military.MT_SAM]:
		var w: String = "missile_b" if t == Military.MT_BALLISTIC else ("missile_c" if t == Military.MT_CRUISE else "missile_sam")
		var room: int = maxi(0, int(Military.MT_CAP[t]) - ct.missile_stock[t])
		var why: String = ""
		if not aid_carrier(ct, t):
			why = _carrier_why(t)
		elif room <= 0:
			why = Loc.t("склад полон")
		out.append({"what": w, "icon": String(Military.MT_ICONS[t]), "label": String(AID_NAMES[w]), "have": cf.missile_stock[t], 
			"max": mini(cf.missile_stock[t], room) if why == "" else 0, "step": 1, "each": aid_value(w, 1), "why": why})
	var droom: int = gw.mil.drone_room(ct)
	out.append({"what": "drones", "icon": "icon_launch", "label": Loc.t("ДРОНЫ"), "have": gw.mil.parked_count(from), "max": mini(gw.mil.parked_count(from), droom), 
		"step": 1, "each": aid_value("drones", 1), "why": Loc.t("нет мест в дронопорте") if droom <= 0 else ""})
	for res: String in ["metal", "titanium", "oil", "fuel", "food", "wood", "precious", "goods"]:
		var room2: int = gw.econ.room_for(ct, res) if gw.econ != null else 999
		out.append({"what": res, "icon": String(Economy.RES_ICONS.get(res, "res_metal")), "label": String(Economy.RES_SHORT.get(res, res)), 
			"have": int(cf.get(res)), "max": mini(int(cf.get(res)), maxi(0, room2)), "step": 5, "each": aid_value(res, 1), "why": Loc.t("склад полон") if room2 <= 0 else ""})
	return out




func transfer(from: int, to: int, what: String, n: int) -> String:
	var cf: Country = gw.country_by_id(from)
	if cf == null or not _alive(to) or from == to:
		return Loc.t("Страны нет")
	if at_war(from, to):
		return Loc.t("Помощь врагу невозможна")
	if not AID_KINDS.has(what):
		return Loc.t("Нельзя передать")
	if n <= 0:
		return Loc.t("Выберите количество")
	var moved: int = _move(from, to, what, n)
	if moved <= 0:
		for o: Dictionary in aid_options(from, to):
			if String(o["what"]) == what and String(o["why"]) != "":
				return Loc.t("У них %s") % String(o["why"])
		return Loc.t("Нечего отправить")
	var value: int = aid_value(what, moved)
	var gain: int = gift_gain(from, to, value)
	add_opinion(from, to, gain)
	_note_help(from, to, value)
	_count("aid")
	_count("aid_" + what)
	_reveal(from, to)
	var nm: String = String(AID_NAMES.get(what, Economy.RES_NAMES.get(what, what))).to_lower()
	gw.news_m(Loc.mk("ПОМОЩЬ: %s → %s (%s ×%d)", [Loc.name(_name(from)), Loc.name(_name(to)), nm, moved]), "grass_light")
	var ct: Country = gw.country_by_id(to)
	if ct.is_player:
		gw.say(ct, Loc.mk("Помощь от %s: %s ×%d", [Loc.name(cf.name), nm, moved]))
	gw.relations_changed.emit()
	return ""



func _note_help(from: int, to: int, value: int) -> void :
	aid_log.append([gw.game_time, from, to, value])
	if care != null:
		care.on_help(from, to, value)
	if gw.player != null and (from == gw.player.id or to == gw.player.id):
		Sfx.ui("aid_sent")
	if aid_log.size() > 40:
		aid_log.pop_front()
	var ct: Country = gw.country_by_id(to)
	if ct == null or ct.at_war.is_empty():
		return
	_helped["%d>%d" % [from, to]] = gw.game_time
	var k: String = "%d>%d" % [from, to]
	if refusals.has(k):
		refusals[k] = maxi(0, int(refusals[k]) - 1)
	if conf != null:
		conf.note_aid(from, to, value)


func _react_update(dt: float) -> void :
	if react == null:
		react = DipReactS.new(self)
	react.update(dt)




func react_restrained(a: int, vs: int, fac_kind: int = -1, cause: String = "") -> bool:
	if react == null:
		return false
	if fac_kind >= 0:
		match fac_kind:
			Facility.Kind.PORT, Facility.Kind.PORT_CRANE, Facility.Kind.NAVAL_BASE:

				return react.restrained(a, vs, "port") or react.restrained(a, vs, "convoy")
			Facility.Kind.OIL_RIG, Facility.Kind.REFINERY:
				cause = "oil"
			_:
				return false
	return react.restrained(a, vs, cause)



func react_tension(me: int, cid: int) -> Dictionary:
	return react.tension(me, cid) if react != null else {}



func world_events() -> Array:
	return react.world_events() if react != null else []


func _react_save() -> Dictionary:
	return react.save_state() if react != null else {}


func _react_load(d: Dictionary) -> void :
	react = DipReactS.new(self)
	react.load_state(d)





static func aid_mtype(what: String) -> int:
	match what:
		"missile_b":
			return Military.MT_BALLISTIC
		"missile_c":
			return Military.MT_CRUISE
		"missile_sam":
			return Military.MT_SAM
	return -1





func aid_carrier(c: Country, t: int) -> bool:
	if gw.econ != null and gw.econ.trd != null:
		return gw.econ.trd.aid_carrier(c, t)
	return gw.mil.has_carrier(c, t)


func _carrier_why(t: int) -> String:
	match t:
		Military.MT_BALLISTIC:
			return Loc.t("нет ОТРК")
		Military.MT_SAM:
			return Loc.t("нет ЗРК «Купол» / «Щит»")
	return Loc.t("нет носителя")







func _subj_join(who: int, enemy: int, side: int, why: String) -> void :
	if who == enemy or at_war(who, enemy) or not _alive(who) or not _alive(enemy):
		return
	var blk: Dictionary = war_block(who, enemy)
	if not blk.is_empty():
		_count("subj_join_wait")
		dlog(who, "ждёт вывода войск, чтобы вступить за %s против %s" % [_cname(side), _cname(enemy)], String(blk["why"]), 0.0, ["subj_wait", side, enemy])
		_ai_war_prep(who, blk)
		return
	_join_war(who, enemy, side, why)




func subj_peace_block(a: int, b: int) -> String:
	for pr: Array in [[a, b], [b, a]]:
		var s: int = int(pr[0])
		var o: int = int(pr[1])
		var ov: int = subject_of(s)
		if ov > 0 and ov != o and at_war(ov, o) and at_war(s, o):
			return Loc.t("Мир с %s заключает %s: %s воюет вместе с сюзереном") % [_cname(o), _cname(ov), _cname(s)]
	return ""




func subj_treaty_block(a: int, b: int, kind: String) -> String:
	if kind == "trade" or kind.begins_with("subj_"):
		return ""
	for pr: Array in [[a, b], [b, a]]:
		var s: int = int(pr[0])
		var o: int = int(pr[1])
		var ov: int = subject_of(s)
		if ov <= 0 or ov == o:
			continue
		if at_war(ov, o) or truce_on(ov, o):
			return Loc.t("%s — враг сюзерена %s: договор невозможен") % [_cname(o), _cname(ov)]
		if subject_kind(s) == "puppet":
			return Loc.t("Внешнюю политику %s решает %s") % [_cname(s), _cname(ov)]
	return ""




func subject_wars(sid: int) -> Dictionary:
	var ov: int = subject_of(sid)
	var out: Dictionary = {"over": ov, "kind": subject_kind(sid), "with": [], "not": []}
	var co: Country = gw.country_by_id(ov)
	if ov <= 0 or co == null:
		return out
	for e: int in co.at_war.keys():
		if e == sid or not _alive(e):
			continue
		if at_war(sid, e):
			(out["with"] as Array).append(e)
		else:
			var why: String = Loc.t("перемирие") if truce_on(sid, e) else war_block_why(sid, e)
			(out["not"] as Array).append([e, why if why != "" else Loc.t("вступит на ближайшем ходу")])
	return out



func subjects_follow_text(over: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for sid: int in subjects_of(over):
		var sw: Dictionary = subject_wars(sid)
		var names: PackedStringArray = []
		for e: int in (sw["with"] as Array):
			names.append(_cname(e).to_upper())
		var kind: String = Loc.t("Марионетка") if String(sw["kind"]) == "puppet" else Loc.t("Вассал")
		out.append(Loc.t("%s %s следует за вами: %s") % [kind, _cname(sid).to_upper(), (Loc.t("войны %s") % [", ".join(names)]) if not names.is_empty() else Loc.t("войн нет")])
	return out


func _sky():
	if sky == null:
		sky = SkyS.new(self)
	return sky


func _sky_update(dt: float) -> void :
	_sky().update(dt)



func sky_offer(cid: int, host: int) -> String:
	return _sky().offer(cid, host)



func sky_ask(cid: int, coverer: int) -> String:
	return _sky().ask(cid, coverer)




func sky_end(cid: int, other: int, over_them: bool = true) -> String:
	return _sky().end_cmd(cid, other, over_them)



func sky_take_home(cid: int, fid: int) -> String:
	return _sky().take_home(cid, fid)



func sky_info(me: int, other: int) -> Dictionary:
	return _sky().info(me, other)



func sky_why(c: int, h: int) -> String:
	return _sky().can_start(c, h)



func sky_away(cid: int) -> Array:
	return _sky().away(cid)



func sky_spot(cid: int, host: int, kind: int) -> Vector2i:
	return _sky().spot(cid, host, kind)



func sky_target(e: int, f: Facility) -> int:
	return sky.target_host(e, f) if sky != null else 0


func sky_hash() -> PackedFloat64Array:
	return sky.hash_nums() if sky != null else PackedFloat64Array()


func _sky_save() -> Dictionary:
	return sky.save() if sky != null else {}


func _sky_load(d: Dictionary) -> void :
	sky = SkyS.new(self)
	sky.load_from(d)



func rift_hash() -> PackedFloat64Array:
	return rift.hash_nums() if rift != null else PackedFloat64Array()



func rift_note(me: int, other: int) -> String:
	return rift.note_for(me, other) if rift != null else ""


func _req_update(dt: float) -> void :
	if rq == null:
		rq = ReqS.new(self)
	rq.update(dt)


func _req_save() -> Dictionary:
	return rq.save_state() if rq != null else {}


func _req_load(d: Dictionary) -> void :
	rq = ReqS.new(self)
	rq.load_state(d)


func _rq():
	if rq == null:
		rq = ReqS.new(self)
	return rq



func guard_send(cid: int, host: int, what: Variant, vs: int = 0) -> String:
	return _rq().guard_send(cid, host, what, vs)


func req_targets(me: int, other: int, kind: String) -> Array:
	return _rq().targets(me, other, kind)


func req_asked(me: int) -> Array:
	return _rq().asked_by(me)


func req_stations(me: int) -> Array:
	return _rq().stations_of(me)


func req_press_on(t: int) -> Array:
	return _rq().press_on(t)






func request(cid: int, to: int, kind: String, x: int = 0) -> String:
	return _rq().send(cid, to, kind, maxi(0, x))


func cancel_request(cid: int, id: int) -> String:
	return _rq().cancel(cid, id)


func guard_end(cid: int, other: int) -> String:
	return _rq().station_end(cid, other)


func guard_info(me: int, other: int) -> Dictionary:
	return _rq().guard_info(me, other)


func request_outlook(me: int, other: int, kind: String, x: int = 0) -> Dictionary:
	return _rq().ui_outlook(me, other, kind, x)


func req_hash() -> PackedFloat64Array:
	return rq.hash_nums() if rq != null else PackedFloat64Array()



func drama_bias(cid: int, topic: String) -> float:
	for nm: String in ["world_drama", "drama"]:
		var o: Variant = gw.get(nm)
		if o != null and (o as Object).has_method("bias"):
			return clampf(float((o as Object).call("bias", gw.country_by_id(cid), topic)), -0.5, 0.5)
	return 0.0
