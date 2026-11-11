class_name Diplomacy
extends "res://game/diplomacy/dip_allies.gd"




const Cad344: = preload("res://game/cad344.gd")





func propose(from: int, to: int, want: int, agreed: bool = false) -> bool:
	var ct: Country = gw.country_by_id(to)
	if ct == null or ct.eliminated:
		return false
	_reveal(from, to)
	var cur: int = get_rel(from, to)
	if want == cur:
		return true
	if (want == Rel.TRUCE or want == Rel.PEACE) and subj_peace_block(from, to) != "":
		gw.say(from, subj_peace_block(from, to))
		return false
	if ct.is_player and not agreed and from != to and _human(from):
		_offer(from, to, want)
		return false
	var accept: bool = true
	if not ct.is_player:
		accept = ai_accepts(to, from, want)
	if not accept:
		if gw.country_by_id(from).is_player:
			gw.say(gw.country_by_id(from), Loc.mk("%s отказывается", [Loc.name(_name(to))]))
		add_opinion(from, to, -3)
		return false
	if want == Rel.ALLIANCE and rift != null:
		var rg: String = rift.tie_gate(to, from)
		if rg == "":
			rg = rift.tie_gate(from, to)
		if rg != "":
			_count("rift_sign_blocked")
			gw.say2(from, to, Loc.mk("Союз не заключён: %s", [rg]))
			return false
	match want:
		Rel.TRUCE:
			_set_rel(from, to, Rel.TRUCE)
			gw.news_m(Loc.mk("ПЕРЕМИРИЕ: %s И %s", [Loc.name(_name(from)), Loc.name(_name(to))]), "amber")
		Rel.PEACE:
			_set_rel(from, to, Rel.PEACE)
			gw.news_m(Loc.mk("МИРНЫЙ ДОГОВОР: %s И %s", [Loc.name(_name(from)), Loc.name(_name(to))]), "grass_light")
		Rel.ALLIANCE:
			_set_rel(from, to, Rel.ALLIANCE)
			add_opinion(from, to, 20)
			gw.news_m(Loc.mk("СОЮЗ: %s И %s", [Loc.name(_name(from)), Loc.name(_name(to))]), "intercept_cyan")
	if want == Rel.TRUCE or want == Rel.PEACE:
		_dip2_peace(from, to, want)
	return true


func update(dt: float) -> void :
	for k: String in truce_until.keys():
		var ab0: PackedStringArray = k.split(":")
		var other: int = _player_other(int(ab0[0]), int(ab0[1]))
		if conf_lock(int(ab0[0]), int(ab0[1])):
			truce_until[k] = maxf(float(truce_until[k]), gw.game_time + TRUCE_WARN + 1.0)
			continue
		if other > 0 and not _truce_warned.has(k) and int(rel.get(k, Rel.PEACE)) == Rel.TRUCE and float(truce_until[k]) - gw.game_time <= TRUCE_WARN:
			_truce_warned[k] = true
			gw.message.emit(Loc.msg(Loc.mk("Перемирие с %s: через %d с — мир. Войны не будет ещё %d мин", [Loc.name(_cname(other)), ceili(float(truce_until[k]) - gw.game_time), ceili(calm_time(other) / 60.0)])))
		if gw.game_time >= float(truce_until[k]):
			truce_until.erase(k)
			if int(rel.get(k, Rel.PEACE)) == Rel.TRUCE:
				var ab: PackedStringArray = k.split(":")
				_set_rel(int(ab[0]), int(ab[1]), Rel.PEACE)
				gw.news_m(Loc.mk("ПЕРЕМИРИЕ ПЕРЕШЛО В МИР: %s И %s", [Loc.name(_name(int(ab[0]))), Loc.name(_name(int(ab[1])))]), "grass_light")
				if other > 0:
					gw.message.emit(Loc.msg(Loc.mk("Мир с %s. Новой войны с их стороны не будет %d мин", [Loc.name(_cname(other)), ceili(calm_time(other) / 60.0)])))
	_overfly_t += dt
	if _overfly_t >= 2.0:
		_overfly_t = 0.0
		_overfly_tick()
	for k in range(offers.size() - 1, -1, -1):
		if gw.game_time > float(offers[k][3]):
			if _human(int(offers[k][0])) and _human(int(offers[k][1])):
				gw.say(int(offers[k][0]), Loc.mk("%s не ответил: %s", [Loc.name(_cname(int(offers[k][1]))), String(REL_NAMES[int(offers[k][2])]).to_lower()]))
			offers.remove_at(k)
	_v11_update(dt)
	_dip2_update(dt)
	_react_update(dt)
	_sky_update(dt)
	_req_update(dt)
	var cad: Cad344 = gw.cad344
	while cad != null and not cad.dip_q.is_empty() and cad.take_ai_slot():
		_ai_think_one(int(cad.dip_q.pop_front()), cad.dip_t0)
	_t += dt
	if _t < THINK_DT:
		return
	_t = 0.0
	if cad != null:
		_ai_think_global()
		cad.dip_t0 = gw.game_time
		cad.dip_q.clear()
		for c: Country in gw.countries:
			if not (c.is_player or c.eliminated or c.capital_id < 0):
				cad.dip_q.append(c.id)
		while not cad.dip_q.is_empty() and cad.take_ai_slot():
			_ai_think_one(int(cad.dip_q.pop_front()), cad.dip_t0)
		return
	_ai_think()



func answer_offer_from(from: int, yes: bool, to: int = -1) -> void :
	if to < 0 and gw.player != null:
		to = gw.player.id
	for i in offers.size():
		if int(offers[i][0]) == from and int(offers[i][1]) == to:
			answer_offer(i, yes)
			return


func answer_offer(i: int, yes: bool) -> void :
	if i < 0 or i >= offers.size():
		return
	var o: Array = offers[i]
	offers.remove_at(i)
	if yes:
		propose(int(o[0]), int(o[1]), int(o[2]), true)
		if _human(int(o[0])):
			gw.say(int(o[0]), Loc.mk("%s принимает: %s", [Loc.name(_cname(int(o[1]))), String(REL_NAMES[int(o[2])]).to_lower()]))
	else:
		add_opinion(int(o[0]), int(o[1]), -10)
		if _human(int(o[0])):
			gw.say(int(o[0]), Loc.mk("%s отклоняет: %s", [Loc.name(_cname(int(o[1]))), String(REL_NAMES[int(o[2])]).to_lower()]))


func _ai_think() -> void :
	_ai_think_global()
	for c: Country in gw.countries:
		if c.is_player or c.eliminated or c.capital_id < 0:
			continue
		_ai_think_c(c, int(gw.game_time))



func _ai_think_global() -> void :
	_tick_n += 1
	_drift_tick()
	if ally != null:
		ally.tick()
	if rift != null:
		rift.tick()



func _ai_think_one(cid: int, t0: float) -> void :
	var c: Country = gw.country_by_id(cid)
	if c == null or c.is_player or c.eliminated or c.capital_id < 0:
		return
	_ai_think_c(c, int(t0))



func _ai_think_c(c: Country, t: int) -> void :
	var P: Dictionary = _p(c.id)
	var h: int = Hash32.h2(c.id, t, 431) % 1000
	_ai_peace(c, P, h)
	_ai_passage_review(c)
	_ai_wars(c, P, h)
	_ai_treaties(c, P, h)
	_ai_demands(c, P, h)
	_ai_embargo(c, P, h)
	_dip2_think(c, P, h)



func _ai_peace(c: Country, P: Dictionary, h: int) -> void :
	if subject_kind(c.id) == "puppet":
		return
	for id: int in c.at_war.keys():
		var o: Country = gw.country_by_id(id)
		if o == null or o.eliminated:
			continue
		var wt: float = war_time(c.id, o.id)
		var goal: Dictionary = war_goals.get("%d>%d" % [c.id, o.id], {})
		var done: bool = false
		if not goal.is_empty():
			var gc: Vector2i = goal["cell"]
			done = gw.data.inside(gc.x, gc.y) and gw.data.get_owner_id(gc.x, gc.y) == c.id
		var losing: bool = wt > 240.0 and strength(c.id) < strength(o.id) * 0.7
		var tired: bool = (wt > 420.0 and float(P["aggr"]) < 0.5) or (wt > 240.0 and gw.ai != null and gw.ai.war_futile(c.id, o.id))
		if not (done or losing or tired):
			continue
		if o.is_player:
			if fmod(wt - 6.0, PEACE_ASK_GAP) >= THINK_DT:
				continue
		elif h >= (500 if done else 250) + roundi(300.0 * _db(c.id, o.id, "peace")):
			continue
		if not done and _keeps_word(c, o):
			continue
		var want: int = Rel.PEACE if done else Rel.TRUCE
		if o.is_player:
			_offer(c.id, o.id, want)
		elif ai_accepts(o.id, c.id, want):
			dlog(c.id, "%s с %s" % [REL_NAMES[want], o.name], "цель достигнута" if done else (Loc.t("проигрывает") if losing else Loc.t("устала")), strength(c.id) / maxf(1.0, strength(o.id)))
			propose(c.id, o.id, want)
			if done:
				war_goals.erase("%d>%d" % [c.id, o.id])




func _ai_wars(c: Country, P: Dictionary, h: int) -> void :
	if GameConfig.aggression == 0 or c.at_war.size() >= 2:
		return
	if care != null and care.defending(c.id):
		return


	var pid1: String = String(P.get("id", ""))
	var second: bool = c.at_war.size() == 1
	if second and (gw.game_time < 900.0 or (pid1 != "militarist" and pid1 != "adventurer")):
		return
	var aggr: float = float(P["aggr"])
	var sneaky: float = float(P["sneaky"])
	var pid: String = String(P.get("id", ""))
	var hard: bool = pid == "militarist" or pid == "adventurer"
	var best_o: Country = null
	var best_sc: float = - INF
	var best_wr: float = 1.0
	for o: Country in gw.countries:
		if o.id == c.id or o.eliminated or o.capital_id < 0 or not war_allowed(c.id, o.id, false):
			continue


		if second and (o.is_player or o.at_war.has(c.id)):
			continue
		var far: float = 0.8 if hard and ( not o.is_player or player_pressure() > 0.0) else 0.5
		if not _nb.has(key(c.id, o.id)) and _dist_caps(c, o) > gw.data.w * GameWorld.CELL * far:
			continue
		var ratio: float = strength(c.id) / maxf(1.0, strength(o.id))
		var rel_o: int = _rel_eff(c.id, o.id)
		var nap: bool = has_treaty(c.id, o.id, "nap") or has_treaty(c.id, o.id, "defense")
		var h2: int = Hash32.h2(c.id, o.id, int(gw.game_time)) % 1000




		if not second and sneaky > 0.6 and o.at_war.size() == 1 and war_power(c.id) > war_power(o.id) and rel_o < 15 + roundi(40.0 * maxf(0.0, _db(c.id, o.id))) and h2 < int(40.0 * sneaky * _dm(c.id, o.id)) and ( not nap or h2 < 12 + roundi(30.0 * maxf(0.0, _db(c.id, o.id))))\
		and ratio > 1.05 and war_time(o.id, int(o.at_war.keys()[0])) >= VULTURE_T:
			_war_of_choice(c, o, "удар в спину")
			return
		if o.is_player:
			if aggr > 0.6 and ratio > 1.2 and rel_o < -10 and not nap and h2 < int(30.0 * aggr * _dm(c.id, o.id)):
				_war_of_choice(c, o, "территориальные претензии")
				return



			var pr: float = player_pressure()
			if pr > 0.0 and hard and o.at_war.is_empty() and not nap and war_power(c.id) > war_power(o.id) * (1.0 - 0.3 * pr) and rel_o < 10 + roundi(30.0 * pr) and h2 < int(25.0 * aggr * pr):
				_war_of_choice(c, o, "богатая добыча")
				return
			continue



		var wr: float = war_power(c.id) / maxf(1.0, war_power(o.id))

		if hard and aggr >= 0.55 and wr > (SECOND_FRONT if second else (WAR_EDGE if gw.game_time >= 900.0 else EARLY_EDGE)) and ratio >= 0.8 and rel_o < (45 if pid == "militarist" else 30) + roundi(30.0 * maxf(0.0, _db(c.id, o.id))) and not nap and _db(c.id, o.id) > -0.3:
			var sc: float = wr + (0.4 if o.id == _leader_id() else 0.0) - float(rel_o) / 100.0 + _db(c.id, o.id)
			if sc > best_sc:
				best_sc = sc
				best_o = o
				best_wr = wr


	var appetite: float = clampf(1.0 + 4.0 * (best_wr - 1.0), 1.0, 4.0) * (1.7 if gw.game_time >= 900.0 else 1.5)
	if best_o != null and Hash32.h2(c.id, best_o.id, int(gw.game_time)) % 1000 < int(22.0 * aggr * appetite * _dm(c.id, best_o.id)):
		_war_of_choice(c, best_o, "территориальные претензии")



func _ai_treaties(c: Country, P: Dictionary, h: int) -> void :
	if h < 940 - roundi(160.0 * _db(c.id, -1, "treaty")):
		return
	var order: Array = []
	match String(P.get("id", "")):
		"trader":
			order = ["trade", "visa", "nap", "defense"]
		"cautious":
			order = ["nap", "defense", "trade", "alliance"]
		"militarist":
			order = ["nap", "alliance", "trade"]
		_:
			order = ["visa", "nap", "trade", "alliance"]
	for o: Country in gw.countries:
		if o.id == c.id or o.eliminated or o.capital_id < 0 or at_war(c.id, o.id) or get_rel(c.id, o.id) == Rel.TRUCE or embargo_between(c.id, o.id):
			continue
		var near: bool = _nb.has(key(c.id, o.id)) or _dist_caps(c, o) < gw.data.w * GameWorld.CELL * 0.4
		for kind: String in order:
			if not near and kind != "trade" and kind != "visa":
				continue
			if has_treaty(c.id, o.id, kind) or treaty_covered(c.id, o.id, kind) != "" or ai_treaty_reason(c.id, o.id, kind) != "":
				continue
			if kind == "trade" and not gw.econ.can_reach(c, o):
				continue
			if o.is_player:
				if gw.game_time < _player_offer_t or not t_offers.is_empty():
					continue
				_player_offer_t = gw.game_time + PLAYER_OFFER_GAP + float(h % 60)
				_offer_treaty(c.id, o.id, kind)
				return
			if ai_treaty_reason(o.id, c.id, kind) == "":
				_sign(c.id, o.id, kind, kind == "trade")
				return




func _ai_demands(c: Country, P: Dictionary, h: int) -> void :
	var now: float = gw.game_time
	if now < float(_next_dem.get(c.id, 420.0 + float(c.id) * 25.0)):
		return
	var aggr: float = float(P["aggr"])
	_next_dem[c.id] = now + lerpf(600.0, 210.0, aggr) * (0.8 + float(h % 40) / 100.0) * (1.0 - clampf(drama_bias(c.id, "demand"), -0.3, 0.3))
	if demands.size() >= 3 or not c.at_war.is_empty():
		return
	var lack: Array = []
	for res: String in gw.econ.scarce_of(c):
		if int(c.get(res)) < 20 or gw.econ.need(c, res) > 0:
			lack.append(res)
	var needs: Array = lack.duplicate()
	for res3: String in Economy.RAW:
		if not needs.has(res3) and gw.econ.need(c, res3) >= 10:
			needs.append(res3)
	var best: Dictionary = {}
	var bs: float = 0.0
	for o: Country in gw.countries:
		if o.id == c.id or o.eliminated or o.capital_id < 0 or at_war(c.id, o.id) or allied(c.id, o.id) or _has_demand(c.id, o.id):
			continue
		if not _nb.has(key(c.id, o.id)) and _dist_caps(c, o) > gw.data.w * GameWorld.CELL * (0.7 if o.is_player and player_pressure() > 0.0 else 0.45):
			continue
		if o.is_player and (now < _player_dem_t or now < FIRST_PLAYER_DEMAND):
			continue
		if o.is_player and not o.at_war.is_empty():
			continue
		if has_treaty(c.id, o.id, "defense") or subject_of(o.id) == c.id or subject_of(c.id) == o.id or ( not o.at_war.is_empty() and relation(c.id, o.id) > -30):
			continue
		var cap_v: int = _player_cap(o) if o.is_player else 1 << 30
		var first_p: bool = o.is_player and int(counters.get("demands_player", 0)) == 0
		if now - float(_pair_dem.get("%d>%d" % [c.id, o.id], -9999.0)) < 420.0:
			continue
		if has_treaty(c.id, o.id, "nap") and float(P["sneaky"]) < 0.7 and gw.rng.roll() < 0.6:
			continue
		var ratio: float = strength(c.id) / maxf(1.0, strength(o.id))
		if o.is_player and player_pressure() > 0.0:

			ratio = maxf(ratio, war_power(c.id) / maxf(1.0, war_power(o.id)))
		if ratio < 1.15 - aggr * 0.35 - (0.3 * player_pressure() if o.is_player else 0.0):
			continue
		var cand: Dictionary = {}
		if not lack.is_empty():
			var dep: Dictionary = border_deposit(o.id, c.id, lack)
			if not dep.is_empty() and aggr >= 0.3 and not first_p:
				cand = {"kind": "deposit", "params": {"cell": dep["cell"], "res": dep["res"]}}
			if cand.is_empty():
				for res2: String in needs:
					var have: int = int(o.get(res2)) if o.is_player else gw.econ.surplus(o, res2)
					var n2: int = mini(mini(30, have / 2), cap_v / maxi(1, gw.econ.market_price(res2)))
					if have >= 15 and n2 >= 5:
						cand = {"kind": "res", "params": {"res": res2, "n": n2}}
						break
		if cand.is_empty() and lack.is_empty() and not needs.is_empty():
			for res4: String in needs:
				var have4: int = int(o.get(res4)) if o.is_player else gw.econ.surplus(o, res4)
				var n4: int = mini(mini(30, have4 / 2), cap_v / maxi(1, gw.econ.market_price(res4)))
				if have4 >= 15 and n4 >= 5:
					cand = {"kind": "res", "params": {"res": res4, "n": n4}}
					break
		if cand.is_empty() and aggr >= 0.55 and o.money >= 1200:
			cand = {"kind": "money", "params": {"n": clampi(int(float(o.money) * 0.3 / 50.0) * 50, 300, 1500) if not o.is_player else clampi(cap_v / 50 * 50, 150, 1500)}}
		if cand.is_empty() and float(P["caution"]) > 0.6:
			for e: int in _enemies_of(c.id):
				if allied(o.id, e):
					cand = {"kind": "break_alliance", "params": {"third": e}}
		if cand.is_empty() and float(P["sneaky"]) > 0.7:
			for t: Country in gw.countries:
				if t.id != c.id and t.id != o.id and has_treaty(o.id, t.id, "visa") and relation(c.id, t.id) < -20:
					cand = {"kind": "cancel_visa", "params": {"third": t.id}}
		if cand.is_empty():
			continue
		var sc: float = ratio + (1.0 if String(cand["kind"]) == "deposit" else 0.0) - float(relation(c.id, o.id)) / 100.0
		if sc > bs:
			bs = sc
			var war: bool = aggr >= 0.45 and ratio >= (1.2 if o.is_player else 1.0) and (o.is_player or war_power(c.id) >= war_power(o.id)) and war_allowed(c.id, o.id, true) and not has_treaty(c.id, o.id, "nap")
			cand["params"]["conseq"] = "war" if war else "embargo"
			cand["to"] = o.id
			best = cand
	if best.is_empty():
		return
	var d: Dictionary = _make_demand(c.id, int(best["to"]), String(best["kind"]), best["params"])
	if _demand_ok(d) != "":
		return
	if not _human(int(best["to"])) and String(d.get("conseq", "")) != "war" and not ai_yields(int(best["to"]), c.id, d)\
	and Hash32.h2(c.id, int(best["to"]), floori(now / 60.0)) % 100 < 80:
		_count("demand_pointless_skip")
		return
	if _human(int(best["to"])):
		_player_dem_t = now + (PLAYER_DEMAND_GAP[0] + float(h % int(PLAYER_DEMAND_GAP[1] - PLAYER_DEMAND_GAP[0]))) * (1.0 - 0.4 * player_pressure())
	_issue(d)




func _v11_update(dt: float) -> void :
	var now: float = gw.game_time

	for i in range(demands.size() - 1, -1, -1):
		if i >= demands.size():
			continue
		var d: Dictionary = demands[i]
		var to: Country = gw.country_by_id(int(d["to"]))
		if to == null or not _alive(int(d["from"])) or not _alive(int(d["to"])) or at_war(int(d["from"]), int(d["to"])):
			demands.remove_at(i)
			pending_changed.emit()
			continue
		if not to.is_player and now >= float(d["made"]) + AI_ANSWER_T:
			demands.remove_at(i)
			if ai_yields(to.id, int(d["from"]), d):
				_fulfil(d)
			else:
				_refused(d)
		elif to.is_player and now >= float(d["until"]):
			demands.remove_at(i)
			gw.say(to, Loc.mk("Срок ультиматума истёк: %s", [Loc.name(_cname(int(d["from"])))]))
			_refused(d)
			pending_changed.emit()
	for i in range(t_offers.size() - 1, -1, -1):
		if now > float(t_offers[i]["until"]):
			t_offers.remove_at(i)
			pending_changed.emit()
	_tour_t += dt
	if _tour_t >= TOUR_DT:
		_tour_t = 0.0
		_tourism()
	_nb_t += dt
	if _nb_t >= 45.0 or _nb_y >= 0:
		if _nb_t >= 45.0:
			_nb_t = 0.0
		_neighbours()
	_coal_t += dt
	if _coal_t >= 30.0:
		_coal_t = 0.0
		_coalition_tick()
	if now - _prev_t >= 60.0:
		_prev_t = now
		_rel_prev = opinion.duplicate()



func _tourism() -> void :
	for k: String in treaties.keys():
		if not (treaties[k] as Dictionary).has("visa"):
			continue
		var ab: PackedStringArray = k.split(":")
		var a: Country = gw.country_by_id(int(ab[0]))
		var b: Country = gw.country_by_id(int(ab[1]))
		if a == null or b == null or not _alive(a.id) or not _alive(b.id):
			continue
		var n: int = TOUR_PER_CITY * (a.city_ids.size() + b.city_ids.size()) / 2
		for c: Country in [a, b]:
			c.add_money(n)
			gw.econ.stat_add(c, "income", "tourism", n)
		_count("tourism", n * 2)


func _neighbours() -> void :
	var d: WorldData = gw.data
	if d == null:
		return
	if _nb_y < 0:
		_nb_y = 0
		_nb_tmp = {}
	var step: int = 6 if d.w <= 1024 else 8
	var o: PackedByteArray = d.owners
	var y_end: int = mini(d.h - step, _nb_y + d.h / NB_BANDS + step)
	for y in range(_nb_y, y_end, step):
		var row: int = y * d.w
		for x in range(0, d.w - step, step):
			var a: int = o[row + x]
			if a == 0:
				continue
			var b: int = o[row + x + step]
			if b != 0 and b != a:
				_nb_tmp[key(a, b)] = true
			var c: int = o[row + step * d.w + x]
			if c != 0 and c != a:
				_nb_tmp[key(a, c)] = true
	_nb_y = y_end + (step - (y_end % step)) % step
	if _nb_y < d.h - step:
		return
	_nb_y = -1
	_nb = _nb_tmp
	var p: Country = gw.player
	if p != null:
		var late: int = 0
		for oc: Country in gw.countries:
			if oc.is_player or known.has(oc.id) or oc.eliminated:
				continue
			if _nb.has(key(p.id, oc.id)):
				_reveal(p.id, oc.id)
			elif gw.game_time > 900.0:
				_reveal(p.id, oc.id, true)
				late += 1
		if late > 0:
			gw.message.emit(Loc.msg(Loc.mk("Разведка: известны характеры всех стран (окно «Дипломатия»)")))


func neighbours(a: int, b: int) -> bool:
	return _nb.has(key(a, b))




func _coalition_tick() -> void :
	var alive: Array[Country] = []
	for c: Country in gw.countries:
		if not c.eliminated and c.capital_id >= 0:
			alive.append(c)
	if alive.size() < 4 or gw.game_time < maxf(GRACE, GameConfig.player_grace()):
		if not coalition.is_empty():
			coalition = {}
		return
	alive.sort_custom( func(x: Country, y: Country) -> bool: return strength(x.id) > strength(y.id))
	var total: float = 0.0
	for c: Country in alive:
		total += strength(c.id)
	var top: Country = alive[0]
	var share: float = strength(top.id) / maxf(1.0, total)
	var lead_ok: bool = share >= 0.3 and strength(top.id) >= strength(alive[1].id) * 1.5
	if not lead_ok:
		if not coalition.is_empty() and (share < 0.25 or int(coalition["leader"]) != top.id):
			gw.news_m(Loc.mk("КОАЛИЦИЯ РАСПАЛАСЬ: %s БОЛЬШЕ НЕ ЛИДЕР", [Loc.name(_name(int(coalition["leader"])))]), "grass_light")
			coalition = {}
		return
	if coalition.is_empty() or int(coalition["leader"]) != top.id:
		coalition = {"leader": top.id, "members": [], "since": gw.game_time}
		_count("coalition_watch")
		gw.news_m(Loc.mk("%s СЛИШКОМ СИЛЬНА: СОСЕДИ НАСТОРОЖЕ", [Loc.name(_name(top.id))]), "amber")
		if top.is_player:
			gw.say(top, Loc.mk("Вы лидер мира: соседи сплачиваются против вас"))
	var members: Array = coalition["members"]
	_appease(top, alive, members)
	if members.size() >= 2 or gw.game_time < _coal_form_t:
		return
	_coal_form_t = gw.game_time + 300.0
	var pick: Array[Country] = []
	for c: Country in alive:
		if c.id == top.id or relation(c.id, top.id) >= 25 or allied(c.id, top.id):
			continue
		var ok: bool = true
		for m: Country in pick:
			if at_war(c.id, m.id) or relation(c.id, m.id) < -20:
				ok = false
		if ok:
			pick.append(c)
		if pick.size() >= 3:
			break
	if pick.size() < 2:
		return
	var names: PackedStringArray = PackedStringArray()
	for i in pick.size():
		names.append(pick[i].name)
		for j in range(i + 1, pick.size()):
			var a: Country = pick[i]
			var b: Country = pick[j]
			if has_treaty(a.id, b.id, "defense") or treaty_covered(a.id, b.id, "defense") != "":
				continue
			if a.is_player or b.is_player:
				var ai: Country = b if a.is_player else a
				_offer_treaty(ai.id, (a if a.is_player else b).id, "defense")
			else:
				_sign(a.id, b.id, "defense", true)
	for c: Country in pick:
		if not members.has(c.id):
			members.append(c.id)
	_count("coalitions")
	gw.news_m(Loc.mk("КОАЛИЦИЯ (ЦЕЛЬ — %s): %s", [Loc.name(_name(top.id)), ", ".join(names).to_upper()]), "alert_red")





func _appease(top: Country, alive: Array[Country], members: Array) -> void :
	for c: Country in alive:
		if c.is_player or c.id == top.id or members.has(c.id) or at_war(c.id, top.id) or get_rel(c.id, top.id) == Rel.TRUCE:
			continue
		if strength(c.id) > strength(top.id) * APPEASE_RATIO or relation(c.id, top.id) < -10 or not (_nb.has(key(c.id, top.id)) or _dist_caps(c, top) < gw.data.w * GameWorld.CELL * 0.4):
			continue
		if has_treaty(c.id, top.id, "nap") or treaty_covered(c.id, top.id, "nap") != "" or ai_treaty_reason(c.id, top.id, "nap") != "":
			continue
		if top.is_player:
			if gw.game_time - float(_t_offer_last.get("%d>%d:nap" % [c.id, top.id], -1000000000.0)) < REOFFER_GAP or not t_offers.is_empty() or gw.game_time < _player_offer_t:
				continue
			_player_offer_t = gw.game_time + PLAYER_OFFER_GAP
			dlog(c.id, "ищет мира с лидером %s: пакт о ненападении" % top.name, "сила %.2f от лидера" % (strength(c.id) / maxf(1.0, strength(top.id))), 0.0, ["appease"])
			_count("appease")
			_offer_treaty(c.id, top.id, "nap")
			return
		if ai_treaty_reason(top.id, c.id, "nap") == "":
			dlog(c.id, "ищет мира с лидером %s: пакт о ненападении" % top.name, "сила %.2f от лидера" % (strength(c.id) / maxf(1.0, strength(top.id))), 0.0, ["appease"])
			_count("appease")
			_sign(c.id, top.id, "nap", true)
			return




func save_state() -> Dictionary:
	var eco: Dictionary = {}
	if gw.econ != null:
		eco = {"scarce": gw.econ.scarce.duplicate(true), "zone": gw.econ.scarce_zone.duplicate(true), "auto_sub": gw.econ.auto_sub.duplicate(), "n": gw.econ._scarce_n}
	return {"rel": rel.duplicate(), "since": since.duplicate(), "truce_until": truce_until.duplicate(), "opinion": opinion.duplicate(), 
		"offers": offers.duplicate(true), "treaties": treaties.duplicate(true), "embargo": embargo.duplicate(), "demands": demands.duplicate(true), 
		"t_offers": t_offers.duplicate(true), "known": known.duplicate(), "war_goals": war_goals.duplicate(true), "coalition": coalition.duplicate(true), 
		"counters": counters.duplicate(), "wars_log": wars_log.duplicate(true), "dem_id": _dem_id, "next_dem": _next_dem.duplicate(), 
		"player_dem_t": _player_dem_t, "player_offer_t": _player_offer_t, "pair_dem": _pair_dem.duplicate(), "player_ask_t": _player_ask_t.duplicate(), "coal_form_t": _coal_form_t, 
		"eco": eco, "peace_t": peace_t.duplicate(), "calm_hits": calm_hits.duplicate(), "passage": passage.duplicate(), "pass_ask": _pass_ask.duplicate(), "dip2": _dip2_save(), "react": _react_save(), 
		"gift_mem": gift_mem.duplicate(true), "war_by": war_by.duplicate(), "good_since": good_since.duplicate(), 
		"ally320": ally.save() if ally != null else {}, 
		"sky331": _sky_save(), 
		"req331": _req_save(), 
		"rift332": rift.save_state() if rift != null else {}}


func load_state(d: Dictionary) -> void :
	rel = d.get("rel", {})
	since = d.get("since", {})
	truce_until = d.get("truce_until", {})
	opinion = d.get("opinion", {})
	gift_mem = d.get("gift_mem", {})
	war_by = d.get("war_by", {})
	good_since = d.get("good_since", {})
	offers = d.get("offers", [])
	treaties = d.get("treaties", {})
	embargo = d.get("embargo", {})
	demands = d.get("demands", [])
	t_offers = d.get("t_offers", [])
	known = d.get("known", {})
	war_goals = d.get("war_goals", {})
	coalition = d.get("coalition", {})
	counters = d.get("counters", {})
	wars_log = d.get("wars_log", [])
	_dem_id = int(d.get("dem_id", 1))
	_next_dem = d.get("next_dem", {})
	_player_dem_t = float(d.get("player_dem_t", 300.0))
	_player_offer_t = float(d.get("player_offer_t", 240.0))
	_player_ask_t = d.get("player_ask_t", {})
	_coal_form_t = float(d.get("coal_form_t", 0.0))
	_pair_dem = d.get("pair_dem", {})

	peace_t = {}
	for k5: Variant in (d.get("peace_t", {}) as Dictionary):
		peace_t[String(k5)] = float(d["peace_t"][k5])
	calm_hits = {}
	for k6: Variant in (d.get("calm_hits", {}) as Dictionary):
		calm_hits[String(k6)] = int(d["calm_hits"][k6])
	passage = {}
	for k7: Variant in (d.get("passage", {}) as Dictionary):
		var gg: PackedStringArray = String(k7).split(">")
		if gg.size() == 2 and _alive(int(gg[0])) and _alive(int(gg[1])) and not at_war(int(gg[0]), int(gg[1])):
			passage[String(k7)] = float(d["passage"][k7])
	_pass_ask = {}
	for k8: Variant in (d.get("pass_ask", {}) as Dictionary):
		_pass_ask[String(k8)] = float(d["pass_ask"][k8])
	_truce_warned = {}
	known = _int_keys(known)
	_next_dem = _int_keys(_next_dem)
	_player_ask_t = _int_keys(_player_ask_t)
	for dm: Dictionary in demands:
		dm["cell"] = _v2i(dm.get("cell", Vector2i(-1, -1)))
	for k: String in war_goals:
		war_goals[k]["cell"] = _v2i(war_goals[k].get("cell", Vector2i(-1, -1)))
	var eco: Dictionary = d.get("eco", {})
	if gw.econ != null and not eco.is_empty():
		gw.econ.scarce = _int_keys(eco.get("scarce", {}))
		gw.econ.scarce_zone = _int_keys(eco.get("zone", {}))
		for id: int in gw.econ.scarce_zone:
			var z: Array = gw.econ.scarce_zone[id]
			z[0] = _v2i(z[0])
		gw.econ.auto_sub = _int_keys(eco.get("auto_sub", {}))
		gw.econ._scarce_n = int(eco.get("n", 0))

	for c: Country in gw.countries:
		c.at_war.clear()
	for k: String in rel:
		if int(rel[k]) == Rel.WAR:
			var ab: PackedStringArray = k.split(":")
			var ca: Country = gw.country_by_id(int(ab[0]))
			var cb: Country = gw.country_by_id(int(ab[1]))
			if ca != null and cb != null:
				ca.at_war[cb.id] = true
				cb.at_war[ca.id] = true
	_nb_t = 1000000000.0
	_nb_y = -1
	_dip2_load(d.get("dip2", {}))
	_react_load(d.get("react", {}))
	if ally != null:
		ally.load_from(d.get("ally320", {}))
	_sky_load(d.get("sky331", {}))
	_req_load(d.get("req331", {}))
	rift = RiftS.new(self)
	rift.load_state(d.get("rift332", {}))
	gw.relations_changed.emit()
	pending_changed.emit()



static func _int_keys(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in d:
		out[int(k)] = d[k]
	return out


static func _v2i(v: Variant) -> Vector2i:
	if v is Vector2i:
		return v
	if v is Vector2:
		return Vector2i(v)
	if v is String:
		var p: Variant = str_to_var("Vector2i" + String(v) if String(v).begins_with("(") else String(v))
		if p is Vector2i:
			return p
	return Vector2i(-1, -1)


func _offer(from: int, to: int, want: int) -> void :
	if (want == Rel.TRUCE or want == Rel.PEACE) and subj_peace_block(from, to) != "":
		return
	for o: Array in offers:
		if int(o[0]) == from and int(o[1]) == to:
			gw.say(from, Loc.mk("Предложение %s уже ждёт ответа", [Loc.name(_cname(to))]))
			return
	dlog(from, "предлагает %s: %s" % [_cname(to), REL_NAMES[want]], "война %d с" % int(war_time(from, to)))
	offers.append([from, to, want, gw.game_time + 60.0])
	var what: String = {Rel.TRUCE: Loc.t("ПЕРЕМИРИЕ"), Rel.PEACE: Loc.t("МИР"), Rel.ALLIANCE: Loc.t("СОЮЗ")}[want]
	if gw.player != null and to == gw.player.id:
		gw.news_m(Loc.mk("%s ПРЕДЛАГАЕТ ВАМ %s", [Loc.name(_name(from)), what]), "amber")
	gw.say(to, Loc.mk("%s предлагает: %s", [Loc.name(_cname(from)), String(REL_NAMES[want]).to_lower()]))
	gw.offer_received.emit()
	pending_changed.emit()


func _dist_caps(a: Country, b: Country) -> float:
	if a.capital_id < 0 or b.capital_id < 0:
		return 1000000000.0
	return Vector2(gw.cities[a.capital_id].center).distance_to(Vector2(gw.cities[b.capital_id].center)) * GameWorld.CELL




func propose_treaty(from: int, to: int, kind: String) -> String:
	if not TREATY_INFO.has(kind):
		return Loc.t("Нет такого договора")
	if from == to or not _alive(from) or not _alive(to):
		return Loc.t("Страны нет")
	if kind.begins_with("subj_"):
		return propose_subject(from, to, "vassal", false)
	if subject_kind(to) == "puppet" and subject_of(to) != from and kind != "trade":
		return Loc.t("Внешнюю политику %s решает %s") % [_cname(to), _cname(subject_of(to))]
	var sbk: String = subj_treaty_block(from, to, kind)
	if sbk != "":
		return sbk
	if at_war(from, to) or get_rel(from, to) == Rel.TRUCE:
		return Loc.t("Сначала заключите мир")
	if has_treaty(from, to, kind):
		return Loc.t("Договор уже действует")
	var cov: String = treaty_covered(from, to, kind)
	if cov != "":
		return Loc.t("Не нужно: %s уже включает это") % cov
	if kind == "passage":
		return request_passage(from, to)
	if embargo_between(from, to):
		return Loc.t("Сначала снимите эмбарго")
	if kind == "trade" and gw.econ != null and not gw.econ.can_reach(gw.country_by_id(from), gw.country_by_id(to)):
		return Loc.t("Нет пути для грузов между столицами")
	var ct: Country = gw.country_by_id(to)
	if ct.is_player:
		var ow: String = _offer_treaty(from, to, kind)
		return ow if ow != "" else Loc.t("Предложение отправлено")
	var why: String = ai_treaty_reason(to, from, kind)
	_reveal(from, to)
	if why != "":
		add_opinion(from, to, -2)
		_count("treaty_refused")
		return why
	_sign(from, to, kind)
	return ""






func pending_for_player() -> Array:
	var out: Array = []
	var p: Country = gw.player
	if p == null:
		return out
	var now: float = gw.game_time
	for d: Dictionary in demands:
		if int(d["to"]) == p.id:
			out.append({"id": "d%d" % int(d["id"]), "from": int(d["from"]), "kind": "demand", "icon": DEMAND_ICON, "text": Loc.msg(d["text"]), 
				"deadline": float(d["until"]), "left": maxf(0.0, float(d["until"]) - now), "conseq": String(d["conseq"]), 
				"options": [{"act": "accept", "label": Loc.t("УСТУПИТЬ")}, {"act": "refuse", "label": Loc.t("ОТКАЗАТЬ")}]})
	for o: Array in offers:
		if int(o[1]) == p.id:
			out.append({"id": "o%d" % int(o[0]), "from": int(o[0]), "kind": "offer", "icon": "icon_treaty_alliance" if int(o[2]) == Rel.ALLIANCE else "icon_treaty_nap", 
				"text": Loc.t("%s предлагает: %s") % [_cname(int(o[0])), String(REL_NAMES[int(o[2])])], "deadline": float(o[3]), "left": maxf(0.0, float(o[3]) - now), 
				"options": [{"act": "accept", "label": Loc.t("ПРИНЯТЬ")}, {"act": "refuse", "label": Loc.t("ОТКАЗАТЬ")}]})
	for t: Dictionary in t_offers:
		if int(t["to"]) == p.id:
			if String(t["kind"]) == "passage_give":

				out.append({"id": "t%d" % int(t["id"]), "from": int(t["from"]), "kind": "treaty", "icon": String(TREATY_INFO["passage"]["icon"]), "passage_give": true, 
					"text": Loc.t("%s предлагает право прохода: ваши войска и БПЛА через её землю") % _cname(int(t["from"])), 
					"deadline": float(t["until"]), "left": maxf(0.0, float(t["until"]) - now), 
					"options": [{"act": "accept", "label": Loc.t("ПРИНЯТЬ")}, {"act": "refuse", "label": Loc.t("ОТКАЗАТЬ")}]})
				continue
			var inf: Dictionary = TREATY_INFO[String(t["kind"])]
			if String(t["kind"]) == "passage":

				var vs: int = int(t.get("vs", 0))
				out.append({"id": "t%d" % int(t["id"]), "from": int(t["from"]), "kind": "treaty", "icon": String(inf["icon"]), "passage": true, "vs": vs, 
					"text": Loc.t("%s просит право прохода%s: войска и БПЛА через вашу землю") % [_cname(int(t["from"])), (Loc.t(" (война с %s)") % _cname(vs)) if vs > 0 else ""], 
					"deadline": float(t["until"]), "left": maxf(0.0, float(t["until"]) - now), 
					"options": [{"act": "accept", "label": Loc.t("ПРОПУСТИТЬ")}, {"act": "refuse", "label": Loc.t("ОТКАЗАТЬ")}]})
				continue
			out.append({"id": "t%d" % int(t["id"]), "from": int(t["from"]), "kind": "treaty", "icon": String(inf["icon"]), 
				"text": Loc.t("%s предлагает: %s. %s") % [_cname(int(t["from"])), String(inf["name"]), String(inf["effect"])], 
				"deadline": float(t["until"]), "left": maxf(0.0, float(t["until"]) - now), 
				"options": [{"act": "accept", "label": Loc.t("ПОДПИСАТЬ")}, {"act": "refuse", "label": Loc.t("ОТКАЗАТЬ")}]})
	if gw.econ != null and gw.econ.trd != null:
		out.append_array(gw.econ.trd.pending(p.id, now))
	if gw.econ != null:
		for rq: Dictionary in gw.econ.requests_for(p.id):
			out.append({"id": "r%d" % int(rq["id"]), "from": int(rq["from"]), "kind": "trade", "icon": "icon_treaty_trade", 
				"text": Loc.t("%s просит %s ×%d по %d") % [Loc.name(_cname(int(rq["from"]))), Loc.t(String(Economy.RES_NAMES.get(String(rq["res"]), "")).to_lower()), int(rq["n"]), int(rq["price"])], 
				"deadline": float(rq["until"]), "left": maxf(0.0, float(rq["until"]) - now), 
				"options": [{"act": "accept", "label": Loc.t("ПРОДАТЬ")}, {"act": "refuse", "label": Loc.tc("НЕТ", "offer")}]})
	out.append_array(_dip2_pending(now))
	if ally != null:
		out.append_array(ally.pending(now))
	if react != null:
		out.append_array(react.pending(now))
	if rq != null:
		out.append_array(rq.pending(p.id, now))
	if sky != null:
		out.append_array(sky.pending(now))
	out.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return float(a["deadline"]) < float(b["deadline"]))
	return out



func answer_as(cid: int, id: String, act: String) -> String:
	_who_hint = cid
	var to: int = item_to(id)
	_who_hint = -1
	if to != cid:
		return Loc.t("Нет такого")
	_who = cid
	var why: String = answer(id, act)
	_who = -1
	return why



func answer(id: String, act: String) -> String:
	if id.length() < 2:
		return Loc.t("Нет такого")
	var t: String = id.left(1)
	var n: int = int(id.substr(1))
	var yes: bool = act == "accept"
	var why: String = ""
	match t:
		"d":
			for i in demands.size():
				var d: Dictionary = demands[i]
				if int(d["id"]) != n:
					continue
				if yes:
					why = _demand_ok(d)
					if why != "":
						return why
					demands.remove_at(i)
					_fulfil(d)
				else:
					demands.remove_at(i)
					_refused(d)
				pending_changed.emit()
				return ""
			why = Loc.t("Ультиматум устарел")
		"o":
			answer_offer_from(n, yes, _who)
		"y":
			return ally.cmd_answer(_who if _who >= 0 else (gw.player.id if gw.player != null else -1), n, yes)
		"t":
			for i in t_offers.size():
				var o: Dictionary = t_offers[i]
				if int(o["id"]) != n:
					continue
				t_offers.remove_at(i)
				if String(o["kind"]) == "passage_give":

					if not yes:
						add_opinion(int(o["from"]), int(o["to"]), -2)
						gw.say(int(o["from"]), Loc.mk("%s отказывается от права прохода", [Loc.name(_cname(int(o["to"])))]))
					elif at_war(int(o["from"]), int(o["to"])) or truce_on(int(o["from"]), int(o["to"])):
						why = Loc.t("Война: договор невозможен")
					elif String(passage_wait(int(o["from"]), int(o["to"])).get("kind", "")) == "revoke":
						why = Loc.t("Проход недавно закрыт")
					else:
						grant_passage(int(o["from"]), int(o["to"]))
					break
				if yes:
					if at_war(int(o["from"]), int(o["to"])):
						why = Loc.t("Война: договор невозможен")
					else:
						_sign(int(o["from"]), int(o["to"]), String(o["kind"]))
				else:
					add_opinion(int(o["from"]), int(o["to"]), -4)
					if _human(int(o["from"])):
						gw.say(int(o["from"]), Loc.mk("%s отклоняет: %s", [Loc.name(_cname(int(o["to"]))), String(TREATY_INFO[String(o["kind"])]["name"]).to_lower()]))
				break
		"r":
			if gw.econ != null:
				var rc: Country = gw.country_by_id(_who) if _who >= 0 else gw.player
				if yes:
					why = gw.econ.accept_request(rc, n)
				else:
					gw.econ.decline_request(rc, n)
		"c", "n", "k", "s":
			why = _dip2_answer(t, n, act)
		"e":
			why = react.answer(n, act) if react != null else Loc.t("Нет такого")
		"q":
			why = rq.answer(n, act, _who if _who > 0 else (gw.player.id if gw.player != null else -1)) if rq != null else "Нет такого"
			if rq == null:
				why = Loc.t(why)
		"h":
			why = sky.answer(n, act) if sky != null else Loc.t("Нет такого")
		"x":
			var who: int = _who if _who >= 0 else (gw.player.id if gw.player != null else -1)
			why = gw.econ.trd.contract_answer(who, n, yes) if gw.econ != null and gw.econ.trd != null else Loc.t("Нет такого")
		_:
			why = Loc.t("Нет такого")
	pending_changed.emit()
	return why



func _pile_fit(c: int, e: int) -> float:
	var s: float = 0.1 if neighbours(c, e) else -0.25
	if gw.pstat != null and gw.pstat.is_rival(c, e):
		s += 0.25
	var side: float = 0.0
	var ce: Country = gw.country_by_id(e)
	if ce != null:
		for x: Variant in ce.at_war.keys():
			if _alive(int(x)):
				side += war_power(int(x))
	if side >= war_power(e) * 2.0:
		s -= 0.3
	if war_power(c) < war_power(e) * 0.4:
		s -= 0.15
	return s



func _dip2_peace(a: int, b: int, want: int) -> void :
	for sid: int in subjects.keys():
		var ov: int = subject_of(sid)
		var other: int = b if ov == a else (a if ov == b else -1)
		if other > 0 and other != sid and at_war(sid, other):
			_set_rel(sid, other, want)
	_follow_peace(a, b, want)




func _follow_peace(a: int, b: int, want: int) -> void :
	if care == null:
		return
	for k: String in care.joined_for.keys():
		var ab: PackedStringArray = k.split(">")
		var c: int = int(ab[0])
		var e: int = int(ab[1])
		var side: int = int(care.joined_for[k])
		if not ((side == a and e == b) or (side == b and e == a)) or not at_war(c, e):
			continue
		care.joined_for.erase(k)
		var cc: Country = gw.country_by_id(c)
		var ce: Country = gw.country_by_id(e)
		if cc == null or ce == null:
			continue
		if not cc.is_player and not ce.is_player:
			_set_rel(c, e, want)
			_count("follow_peace")
			dlog(c, "выходит из войны с %s вместе с %s" % [ce.name, _cname(side)], "воевала только за них")
			gw.news_m(Loc.mk("%s ТОЖЕ ПРЕКРАЩАЕТ ВОЙНУ С %s", [Loc.name(_name(c)), Loc.name(_name(e))]), "grass_light")
		elif ce.is_player:
			_offer(c, e, Rel.TRUCE)
		else:
			_offer(e, c, Rel.TRUCE)
			_count("follow_peace_offer")




func propose_subject(from: int, to: int, kind: String, ultimatum: bool) -> String:
	if not SUBJ_NAMES.has(kind):
		return Loc.t("Нет такого статуса")
	if from == to or not _alive(from) or not _alive(to):
		return Loc.t("Страны нет")
	var o: Dictionary = subject_options(from, to)
	if String(o["status"]) != "" or String(o["why"]) != "":
		return String(o["why"]) if String(o["why"]) != "" else Loc.t("Уже вассал")
	var ct: Country = gw.country_by_id(to)
	var cf: Country = gw.country_by_id(from)
	_reveal(from, to)
	if at_war(from, to):

		if war_time(from, to) < PEACE_MIN_WAR:
			return Loc.t("Рано: война только началась")
		if ct.is_player:
			return Loc.t("Нельзя")
		if ai_subject_yields(to, from, kind, true):
			make_subject(from, to, kind, "surrender")
			return ""
		add_opinion(from, to, -5)
		return Loc.t("%s отказывается сдаться: нужна сила ×%s (сейчас ×%s)") % [ct.name, _f1(subject_need(to, from, kind, true)), _f1(float(o["ratio"]))]
	if not ultimatum:
		if kind != "vassal":
			return Loc.t("Марионетку только ультиматумом")
		if ct.is_player:
			var ow: String = _offer_treaty(from, to, "subj_over")
			return ow if ow != "" else Loc.t("Предложение отправлено")
		var need: float = SUBJ_OFFER_NEED - float(_p(to)["caution"]) * 0.3
		if float(o["ratio"]) < need:
			add_opinion(from, to, -3)
			return Loc.t("%s: вы недостаточно сильны (нужно ×%s, сейчас ×%s)") % [ct.name, _f1(need), _f1(float(o["ratio"]))]
		if relation(to, from) < SUBJ_OFFER_REL:
			add_opinion(from, to, -3)
			return Loc.t("%s не доверяет вам: отношения %d, нужно от %d") % [ct.name, relation(to, from), SUBJ_OFFER_REL]
		make_subject(from, to, "vassal", "voluntary")
		return ""
	var r: String = demand(from, to, kind, {"conseq": "war"})
	if r == "":
		return ""
	return r




func _ai_subjects(c: Country, P: Dictionary, h: int) -> void :
	var now: float = gw.game_time
	if now < SUBJ_FIRST_T or is_subject(c.id) or GameConfig.aggression == 0:
		return
	var pid: String = String(P.get("id", ""))

	if (pid == "cautious" or pid == "trader") and not c.at_war.is_empty() and now >= float(_subj_pair.get(c.id, 0.0)):
		var foe_s: float = 0.0
		for eid: int in c.at_war.keys():
			foe_s = maxf(foe_s, strength(eid))
			if war_time(c.id, eid) < 240.0:
				foe_s = 0.0
				break
		if foe_s > strength(c.id) * 2.0 and h < 300:
			var best: Country = null
			for o: Country in gw.countries:
				if o.id == c.id or not _alive(o.id) or is_subject(o.id) or at_war(c.id, o.id) or relation(c.id, o.id) < 40:
					continue
				if subjects_of(o.id).size() >= subject_cap(o.id) or strength(o.id) < strength(c.id) * 1.5:
					continue
				if best == null or strength(o.id) > strength(best.id):
					best = o
			if best != null:
				_subj_pair[c.id] = now + SUBJ_PAIR_GAP
				if best.is_player:
					_offer_treaty(c.id, best.id, "subj_sub")
					gw.say(best, Loc.mk("%s просит покровительства: станет вашим вассалом", [Loc.name(c.name)]))
				else:
					make_subject(best.id, c.id, "vassal", "protection")
				return
	if now < _subj_t or subjects_of(c.id).size() >= subject_cap(c.id) or h % 1000 >= 120 + int(float(P["aggr"]) * 160.0) + roundi(250.0 * _db(c.id, -1, "subject")):
		return
	var hard: bool = pid == "militarist" or pid == "adventurer"
	if not c.at_war.is_empty():
		return
	var target: Country = null
	var tkind: String = ""
	var t_ult: bool = false
	var best_sc: float = - INF
	for o2: Country in gw.countries:
		if o2.id == c.id or not _alive(o2.id) or is_subject(o2.id) or now < float(_subj_pair.get(o2.id, 0.0)) or at_war(c.id, o2.id):
			continue
		if not subjects_of(o2.id).is_empty() or truce_on(c.id, o2.id) or calm_on(c.id, o2.id):
			continue
		if o2.is_player and (now < SUBJ_PLAYER_T or _has_demand(c.id, o2.id) or now - _player_dem_last < float(PLAYER_DEMAND_GAP[0])):
			continue
		var near: bool = _nb.has(key(c.id, o2.id)) or _dist_caps(c, o2) < gw.data.w * GameWorld.CELL * 0.45
		if not near:
			continue
		var ratio: float = strength(c.id) / maxf(1.0, strength(o2.id))
		var rv: int = relation(c.id, o2.id)
		if hard and not o2.at_war.is_empty() and (o2.is_player or rv > -30):
			continue
		if hard:
			if rv >= 30 or not war_allowed(c.id, o2.id, true):
				continue
			var k: String = "puppet" if pid == "militarist" and ratio >= SUBJ_NEED["puppet"] * 1.05 else "vassal"
			if ratio < subject_need(o2.id, c.id, k) * (1.15 if o2.is_player else 0.95):
				continue
			var sc: float = ratio - float(rv) / 100.0
			if sc > best_sc:
				best_sc = sc
				target = o2
				tkind = k
				t_ult = true
		else:
			if ratio < SUBJ_OFFER_NEED or rv < SUBJ_OFFER_REL + 10:
				continue
			var sc2: float = ratio + float(rv) / 100.0
			if sc2 > best_sc:
				best_sc = sc2
				target = o2
				tkind = "vassal"
				t_ult = false
	if target == null:
		return
	_subj_t = now + SUBJ_GLOBAL_GAP
	_subj_pair[target.id] = now + SUBJ_PAIR_GAP
	_count("subj_attempts")
	if target.is_player:
		if t_ult:
			demand(c.id, target.id, tkind, {"conseq": "war"})
		else:
			_offer_treaty(c.id, target.id, "subj_over")
			gw.say(target, Loc.mk("%s предлагает вам вассалитет", [Loc.name(c.name)]))
		return
	if t_ult:
		demand(c.id, target.id, tkind, {"conseq": "war"})
	else:
		var need2: float = SUBJ_OFFER_NEED - float(_p(target.id)["caution"]) * 0.3
		if strength(c.id) / maxf(1.0, strength(target.id)) >= need2 and relation(target.id, c.id) >= SUBJ_OFFER_REL and float(_p(target.id)["aggr"]) < 0.6:
			make_subject(c.id, target.id, "vassal", "voluntary")
		else:
			add_opinion(c.id, target.id, -2)



func _ai_answer_call(c: int, x: int, e: int) -> String:
	var oblig: String = _obligation(c, x, e)
	var cc: Country = gw.country_by_id(c)
	var blocked: bool = _join_block(c, e) != "" or cc.at_war.size() >= 2 or (is_subject(c) and subject_of(c) != x)\
	or not war_block(c, e).is_empty()
	if oblig == "overlord" and not blocked:
		return "join"
	if pile_gate(c, e, x, not _defender(x, e)) != "":
		_count("pile_alt")
		return _pile_alt(c, x, e)


	var defend: bool = oblig != "" and _defender(x, e)
	if defend and not blocked and not _losing_badly(c):
		return "join"
	if oblig != "" and not defend and _offense_why(c, x, e) != "":
		return "aid" if cc.money >= 3000 else "decline"
	var P: Dictionary = _p(c)
	var ours: float = war_power(c) + war_power(x)
	var theirs: float = war_power(e)
	var honour: float = 0.45 + float(P["caution"]) * 0.25 + float(relation(c, x)) / 200.0 + (0.15 if oblig == "alliance" else 0.0)
	var sc: float = honour + float(P["aggr"]) * 0.35 - float(relation(c, e) + 100) / 400.0 - float(cc.at_war.size()) * 0.3
	if theirs > ours * 1.4:
		sc -= 0.35
	if not defend:
		sc += _pile_fit(c, e)
	sc += float(Hash32.h2(c, e, int(gw.game_time / 30.0)) % 300 - 150) / 1000.0
	if GameConfig.aggression == 0:
		sc -= 0.3
	if not blocked and oblig != "" and sc > 0.5:
		return "join"
	if not defend and relation(c, e) < 0 and _pile_alt(c, x, e) == "sanction":
		return "sanction"
	if cc.money >= 1500 or cc.missile_stock[Military.MT_BALLISTIC] + cc.missile_stock[Military.MT_CRUISE] >= 3 or gw.mil.parked_count(c) >= 4:
		return "aid"
	return "refuse"



func _call(x: int, c: int, e: int) -> void :
	var cc: Country = gw.country_by_id(c)
	_count("calls")
	if cc.is_player:
		for k: Dictionary in calls:
			if int(k["from"]) == x and int(k["vs"]) == e:
				return
		calls.append({"id": _dem_id, "from": x, "to": c, "vs": e, "until": gw.game_time + CALL_T, "ask": not _defender(x, e)})
		_dem_id += 1
		_reveal(x, c)
		gw.say(cc, Loc.mk("ПРИЗЫВ К ВОЙНЕ: %s просит вступить в войну с %s", [Loc.name(_cname(x)), Loc.name(_cname(e))]))
		Sfx.ui("call_to_arms")
		gw.offer_received.emit()
		pending_changed.emit()
		return
	_call_result(c, x, e, _ai_answer_call(c, x, e))



func _ally_calls(x: int) -> void :
	var cx: Country = gw.country_by_id(x)
	if cx == null or cx.at_war.is_empty():
		return
	var now: float = gw.game_time
	for c: Country in gw.countries:
		if c.id == x or not _alive(c.id):
			continue
		for eid: int in cx.at_war.keys():
			if eid == c.id or at_war(c.id, eid) or not _alive(eid) or war_time(x, eid) < CALL_AFTER:
				continue
			if cx.is_player and not _defender(x, eid):
				continue
			if _obligation(c.id, x, eid) == "":
				continue
			if _join_block(c.id, eid) != "" or (c.is_player and _losing_badly(c.id)):
				continue
			if not c.is_player and pile_gate(c.id, eid, x, not _defender(x, eid)) == "wait":
				continue
			var ck: String = "%d>%d>%d" % [x, c.id, eid]
			if now < float(_called.get(ck, -1000000000.0)) + CALL_GAP:
				continue
			if now - float(_helped.get("%d>%d" % [c.id, x], -1000000000.0)) < CALL_GAP * 0.5:
				continue
			_called[ck] = now
			_call(x, c.id, eid)
			return





func player_call(me: int, c: int, vs: int = -1) -> String:
	var cm: Country = gw.country_by_id(me)
	if cm == null or cm.at_war.is_empty():
		return Loc.t("Вы ни с кем не воюете")
	var cc: Country = gw.country_by_id(c)
	if cc == null or cc.eliminated or c == me:
		return Loc.t("Страны нет")
	if at_war(me, c) or truce_on(me, c):
		return Loc.t("Сначала заключите мир с %s") % _cname(c)
	var e: int = -1
	var best_s: float = - INF
	for eid: int in cm.at_war.keys():
		if eid == c or at_war(c, eid) or not _alive(eid) or (vs > 0 and eid != vs):
			continue
		var s0: float = (join_interest(c, me, eid) if not cc.is_player else (0.0 if _join_block(c, eid) == "" else -5.0)) + (1.0 if _obligation(c, me, eid) != "" else 0.0)
		if s0 > best_s:
			best_s = s0
			e = eid
	if e < 0:
		return Loc.t("%s уже воюет на вашей стороне") % _cname(c)
	var ck: String = "%d>%d>%d" % [me, c, e]
	var wait: float = float(_called.get(ck, -1000000000.0)) + CALL_ASK_GAP - gw.game_time
	if wait > 0.0:
		return Loc.t("Уже просили: ещё %d с") % ceili(wait)
	if cc.is_player:
		return _human_call(me, c, e, ck)
	if rift != null and rift.deciding(c, me, e) >= 0.0:
		return Loc.t("%s выбирает сторону: вы или %s — ещё %d с") % [_cname(c), _cname(e), ceili(rift.deciding(c, me, e))]
	_called[ck] = gw.game_time
	_count("calls")
	var oblig: String = _obligation(c, me, e)
	var ans: String = _ai_answer_call(c, me, e) if oblig != "" else _ai_answer_ask(c, me, e)
	if ans == "join":
		_join_war(c, e, me, Loc.t("ПРИЗЫВ СОЮЗНИКА") if oblig != "" else Loc.t("ПО ПРОСЬБЕ"))
		if oblig == "":
			_count("ask_join")
		return ""
	if ans == "aid" and send_package(c, me, e) > 0:
		return Loc.t("%s не вступит в войну, но прислал помощь") % _cname(c)
	if oblig != "":
		add_opinion(me, c, -3)
	else:
		_count("ask_refused")
	var why: String = _join_block(c, e)
	if why == "" and oblig == "":
		why = ask_refusal(c, me, e)
	if why == "" and oblig != "" and not _defender(me, e):
		why = _offense_why(c, me, e)
	return Loc.t("%s отказывается%s") % [_cname(c), (": " + why) if why != "" else ""]





func call_outlook(me: int, c: int, e: int) -> Dictionary:
	var cc: Country = gw.country_by_id(c)
	var wait: float = maxf(0.0, float(_called.get("%d>%d>%d" % [me, c, e], -1000000000.0)) + CALL_ASK_GAP - gw.game_time)
	if cc == null or not _alive(c):
		return {"ans": "no", "why": Loc.t("страны нет"), "wait": 0.0}
	if at_war(c, e):
		return {"ans": "no", "why": Loc.t("уже воюет с %s") % _cname(e), "wait": 0.0}
	if rift != null and rift.deciding(c, me, e) >= 0.0:
		return {"ans": "no", "why": Loc.t("выбирает сторону: вы или %s — ещё %d с") % [_cname(e), ceili(rift.deciding(c, me, e))], "wait": wait}
	var blk: String = _join_block(c, e)
	if blk != "" and (cc.is_player or (_ai_answer_call(c, me, e) if _obligation(c, me, e) != "" else _ai_answer_ask(c, me, e)) != "aid"):
		return {"ans": "no", "why": blk, "wait": wait}
	if blk != "":
		return {"ans": "aid", "why": blk, "wait": wait}
	if cc.is_player:
		for k: Dictionary in calls:
			if int(k["from"]) == me and int(k["to"]) == c and int(k["vs"]) == e:
				return {"ans": "pending", "why": Loc.t("ждём ответа"), "wait": maxf(0.0, float(k["until"]) - gw.game_time)}
		return {"ans": "human", "why": Loc.t("игрок — ответит сам"), "wait": wait}
	var oblig: String = _obligation(c, me, e)
	var ans: String = _ai_answer_call(c, me, e) if oblig != "" else _ai_answer_ask(c, me, e)
	var why: String = ""
	if ans != "join":
		if oblig == "":
			why = ask_refusal(c, me, e)
		elif not _defender(me, e):
			why = _offense_why(c, me, e)
		if why == "":
			why = Loc.t("воюет за свою жизнь") if _losing_badly(c) else (Loc.t("уже две войны") if cc.at_war.size() >= 2 else Loc.t("не видит выгоды"))
	return {"ans": ans, "why": why, "wait": wait}





func join_interest(c: int, x: int, e: int) -> float:
	var cc: Country = gw.country_by_id(c)
	if cc == null or not _alive(e):
		return -9.0
	var P: Dictionary = _p(c)
	var s: float = float(relation(c, x)) / 200.0 - float(relation(c, e)) / 200.0
	s += float(P["aggr"]) * 0.3 - float(P["caution"]) * 0.15
	var ours: float = war_power(c) + war_power(x)
	var theirs: float = maxf(1.0, war_power(e))
	s += clampf((ours / theirs - 1.0) * 0.25, -0.4, 0.3)
	if neighbours(c, e):
		s += 0.12
	if not coalition.is_empty() and int(coalition["leader"]) == e:
		s += 0.2
	if war_goals.has("%d>%d" % [c, e]):
		s += 0.15
	s -= float(cc.at_war.size()) * 0.3
	if GameConfig.aggression == 0:
		s -= 0.3
	s += float(Hash32.h2(c * 31 + x, e, int(gw.game_time / 60.0)) % 160 - 80) / 1000.0
	return s



func _ai_answer_ask(c: int, x: int, e: int) -> String:
	var cc: Country = gw.country_by_id(c)
	if cc == null or cc.is_player:
		return "refuse"
	var blocked: bool = _join_block(c, e) != "" or cc.at_war.size() >= 2 or is_subject(c)\
	or gw.game_time < (maxf(GRACE, GameConfig.player_grace()) if gw.country_by_id(e).is_player else BOT_WAR_T)\
	or not war_block(c, e).is_empty()
	if not blocked and (join_interest(c, x, e) >= ASK_JOIN or (rq != null and rq.ask_join(c, x, e) == "join")):


		var side: float = war_power(c)
		for o: Country in gw.countries:
			if o.id != c and not o.eliminated and o.at_war.has(e):
				side += war_power(o.id)
		if side >= war_power(e) * JOIN_EDGE:
			return "join"
		dlog(c, "не вступает против %s" % _cname(e), "вместе слабее (%.2f)" % (side / maxf(1.0, war_power(e))), side / maxf(1.0, war_power(e)), ["skip_weak"])
	if relation(c, x) >= 30 and (cc.money >= 1500 or cc.missile_stock[Military.MT_BALLISTIC] + cc.missile_stock[Military.MT_CRUISE] >= 3 or gw.mil.parked_count(c) >= 4):
		return "aid"
	return "refuse"




func _ai_recruit(c: Country) -> void :
	if c.at_war.is_empty() or is_subject(c.id) or gw.game_time < float(_recruit_next.get(c.id, 0.0)):
		return
	var e: int = -1
	for eid: int in c.at_war.keys():
		if _alive(eid) and war_time(c.id, eid) >= RECRUIT_AFTER and war_power(eid) >= war_power(c.id) * 0.8:
			e = eid
			break
	if e < 0:
		return
	_recruit_next[c.id] = gw.game_time + RECRUIT_GAP
	var best: int = -1
	var bs: float = - INF
	var p: Country = gw.player
	for o: Country in gw.countries:
		if o.is_player or o.id == c.id or o.id == e or not _alive(o.id) or at_war(o.id, e) or at_war(o.id, c.id):
			continue
		if not o.at_war.is_empty() or relation(o.id, c.id) < 20 or _obligation(o.id, c.id, e) != "":
			continue
		var s: float = join_interest(o.id, c.id, e)
		if s > bs:
			bs = s
			best = o.id
	_count("recruit_round")
	if best > 0 and pile_gate(best, e, c.id, not _defender(c.id, e)) == "" and _ai_answer_ask(best, c.id, e) == "join":
		_join_war(best, e, c.id, Loc.t("ПО ПРОСЬБЕ"))
		add_opinion(best, c.id, 6)
		_count("recruit_join")
		dlog(best, "по просьбе %s против %s" % [c.name, _cname(e)], "интерес", bs)
		return
	if gw.game_time < _ask_player_t:
		return
	p = null
	for hc: Country in gw.countries:
		if hc.is_player and _recruit_ask_ok(c, hc, e):
			p = hc
			break
	if p == null:
		return
	_ask_player_t = gw.game_time + ASK_PLAYER_GAP
	calls.append({"id": _dem_id, "from": c.id, "to": p.id, "vs": e, "until": gw.game_time + CALL_T, "ask": true})
	_dem_id += 1
	_reveal(c.id, p.id)
	_count("recruit_ask_player")
	dlog(c.id, "просит игрока вступить против %s" % _cname(e), "отношение %d" % relation(c.id, p.id))
	gw.say(p, Loc.mk("%s предлагает вам вступить в войну с %s", [Loc.name(_cname(c.id)), Loc.name(_cname(e))]))
	gw.offer_received.emit()
	pending_changed.emit()




func _dip2_update(dt: float) -> void :
	if conf == null:
		conf = PeaceConfS.new(self)
	conf.update(dt)
	if care == null:
		care = CareS.new(self)
	care.update(dt)
	var now: float = gw.game_time
	for i in range(calls.size() - 1, -1, -1):
		var k: Dictionary = calls[i]
		if not _alive(int(k["from"])) or not _alive(int(k["vs"])) or not at_war(int(k["from"]), int(k["vs"])) or at_war(int(k["to"]), int(k["vs"])):
			calls.remove_at(i)
			pending_changed.emit()
		elif now >= float(k["until"]):
			calls.remove_at(i)
			if not bool(k.get("ask", false)):
				gw.say(int(k["to"]), Loc.mk("Вы не ответили на призыв %s", [Loc.name(_cname(int(k["from"])))]))
				_grievance(int(k["from"]), int(k["to"]), int(k["vs"]))
			elif bool(k.get("h", false)):
				gw.say(int(k["from"]), Loc.mk("%s не ответил на просьбу о войне с %s", [Loc.name(_cname(int(k["to"]))), Loc.name(_cname(int(k["vs"])))]))
			pending_changed.emit()
	for i2 in range(notes.size() - 1, -1, -1):
		if now >= float(notes[i2]["until"]):
			notes.remove_at(i2)
			pending_changed.emit()
	_pcall_t += dt
	if _pcall_t >= THINK_DT:
		_pcall_t = 0.0
		_dip2_subj_tick()
		_ally_fac_tick()
		for hc: Country in gw.countries:
			if hc.is_player and _alive(hc.id):
				_ally_calls(hc.id)



func _dip2_think(c: Country, P: Dictionary, h: int) -> void :
	_ally_calls(c.id)
	_ai_recruit(c)
	_ai_aid_tick(c, P)
	_ai_subjects(c, P, h)


func _dip2_pending(now: float) -> Array:
	var out: Array = []
	var p: Country = gw.player
	for k: Dictionary in calls:
		if int(k["to"]) != p.id:
			continue
		out.append({"id": "c%d" % int(k["id"]), "from": int(k["from"]), "kind": "call", "icon": "icon_dip_call", "vs": int(k["vs"]), "ask": bool(k.get("ask", false)), 
			"text": (Loc.t("%s предлагает вступить в войну с %s") if bool(k.get("ask", false)) else Loc.t("%s призывает к войне с %s")) % [_cname(int(k["from"])), _cname(int(k["vs"]))], 
			"deadline": float(k["until"]), "left": maxf(0.0, float(k["until"]) - now), "total": CALL_T, 
			"options": [{"act": "join", "label": Loc.t("ВСТУПИТЬ")}, {"act": "aid", "label": Loc.t("ПОМОЧЬ")}, {"act": "refuse", "label": Loc.t("ОТКАЗ")}]})
	for n: Dictionary in notes:
		if int(n["to"]) != p.id:
			continue
		out.append({"id": "n%d" % int(n["id"]), "from": int(n["from"]), "kind": "note", "icon": "icon_dip_protest", "vs": int(n["vs"]), "n": int(n["n"]), 
			"text": Loc.t("НОТА ПРОТЕСТА: %s — нет помощи в войне с %s (%d из 3)") % [_cname(int(n["from"])), _cname(int(n["vs"])), int(n["n"])], 
			"deadline": float(n["until"]), "left": maxf(0.0, float(n["until"]) - now), "total": NOTE_T, 
			"options": [{"act": "aid", "label": Loc.t("ПОМОЧЬ")}, {"act": "ok", "label": Loc.t("ПОНЯТНО")}]})
	if conf != null:
		out.append_array(conf.pending(now))
	return out



func _dip2_answer(t: String, n: int, act: String) -> String:
	var p: Country = gw.country_by_id(_who) if _who > 0 else gw.player
	match t:
		"c":
			for i in calls.size():
				var k: Dictionary = calls[i]
				if int(k["id"]) != n:
					continue
				var x: int = int(k["from"])
				var e: int = int(k["vs"])
				match act:
					"join":
						var jc: String = _join_code(p.id, e)
						if jc == "union" or jc == "pact":
							return Loc.t("Нельзя: %s") % [_join_block(p.id, e)]
						var wb: String = war_block_why(p.id, e)
						if wb != "":
							return Loc.t("Нельзя: %s") % [wb]
						calls.remove_at(i)
						declare_war(p.id, e, "призыв союзника")
						_helped["%d>%d" % [p.id, x]] = gw.game_time
						refusals.erase("%d>%d" % [p.id, x])
						add_opinion(p.id, x, 10)
					"aid":
						if send_package(p.id, x, e) <= 0:
							return Loc.t("Нужно от 500 денег")
						calls.remove_at(i)
						add_opinion(p.id, x, 4)
					_:
						calls.remove_at(i)
						if not bool(k.get("ask", false)):
							_grievance(x, p.id, e)
				if bool(k.get("h", false)):
					_count("calls_human_" + act)
					var ln: String = Loc.t("%s отказывается вступать в войну с %s")
					if act == "join":
						ln = Loc.t("%s вступает в войну с %s по вашей просьбе")
					elif act == "aid":
						ln = Loc.t("%s не вступит в войну с %s, но прислал помощь")
					gw.say(x, ln % [_cname(p.id), _cname(e)])
				pending_changed.emit()
				return ""
			return Loc.t("Призыв устарел")
		"n":
			for i2 in notes.size():
				var nt: Dictionary = notes[i2]
				if int(nt["id"]) != n:
					continue
				if act == "aid":
					if send_package(p.id, int(nt["from"]), int(nt["vs"])) <= 0:
						return Loc.t("Нужно от 500 денег")
					add_opinion(p.id, int(nt["from"]), 6)
				notes.remove_at(i2)
				pending_changed.emit()
				return ""
			return Loc.t("Нота устарела")
		"k":
			return "" if conf != null and conf.has_conf(n) else Loc.t("Конференция закончилась")
		"s":
			return conf.answer_offer(n, act, p.id if p != null else -1) if conf != null else Loc.t("Нет такого")
	return Loc.t("Нет такого")


func _dip2_save() -> Dictionary:
	return {"subjects": subjects.duplicate(true), "calls": calls.duplicate(true), "notes": notes.duplicate(true), "refusals": refusals.duplicate(), 
		"called": _called.duplicate(), "helped": _helped.duplicate(), "aid_next": _aid_next.duplicate(), "subj_t": _subj_t, "subj_pair": _subj_pair.duplicate(), 
		"trib_earned": _trib_earned.duplicate(), "reborn": reborn.duplicate(), "conf": conf.save_state() if conf != null else {}, 
		"recruit_next": _recruit_next.duplicate(), "ask_player_t": _ask_player_t, "ally_fac": ally_fac.duplicate(), 
		"care": care.save_state() if care != null else {}}


func _dip2_load(d: Dictionary) -> void :
	subjects = {}
	for k: Variant in (d.get("subjects", {}) as Dictionary):
		var s: Dictionary = d["subjects"][k]
		var sid: int = int(k)
		var ov: int = int(s.get("over", 0))
		if gw.country_by_id(sid) != null and gw.country_by_id(ov) != null and sid != ov and SUBJ_NAMES.has(String(s.get("kind", ""))):
			subjects[sid] = {"over": ov, "kind": String(s["kind"]), "since": float(s.get("since", 0.0)), "liberty": clampf(float(s.get("liberty", 0.0)), 0.0, 100.0), "young": float(s.get("young", 0.0))}
	calls = []
	for k2: Variant in (d.get("calls", []) as Array):
		var c2: Dictionary = k2
		calls.append({"id": int(c2.get("id", 0)), "from": int(c2.get("from", 0)), "to": int(c2.get("to", 0)), "vs": int(c2.get("vs", 0)), "until": float(c2.get("until", 0.0)), "ask": bool(c2.get("ask", false)), "h": bool(c2.get("h", false))})
	notes = []
	for k3: Variant in (d.get("notes", []) as Array):
		var n3: Dictionary = k3
		notes.append({"id": int(n3.get("id", 0)), "from": int(n3.get("from", 0)), "to": int(n3.get("to", 0)), "vs": int(n3.get("vs", 0)), "until": float(n3.get("until", 0.0)), "n": int(n3.get("n", 1))})
	refusals = {}
	for k4: Variant in (d.get("refusals", {}) as Dictionary):
		refusals[String(k4)] = int(d["refusals"][k4])
	_called = {}
	for k5: Variant in (d.get("called", {}) as Dictionary):
		_called[String(k5)] = float(d["called"][k5])
	_helped = {}
	for k6: Variant in (d.get("helped", {}) as Dictionary):
		_helped[String(k6)] = float(d["helped"][k6])
	_aid_next = {}
	for k7: Variant in (d.get("aid_next", {}) as Dictionary):
		_aid_next[String(k7)] = float(d["aid_next"][k7])
	_subj_t = float(d.get("subj_t", 0.0))
	_recruit_next = {}
	for kr: Variant in (d.get("recruit_next", {}) as Dictionary):
		_recruit_next[int(kr)] = float(d["recruit_next"][kr])
	_ask_player_t = float(d.get("ask_player_t", 0.0))
	ally_fac = {}
	for kf: Variant in (d.get("ally_fac", {}) as Dictionary):
		if int(d["ally_fac"][kf]) > 0:
			ally_fac[int(kf)] = int(d["ally_fac"][kf])
	_subj_pair = {}
	for k8: Variant in (d.get("subj_pair", {}) as Dictionary):
		_subj_pair[int(k8)] = float(d["subj_pair"][k8])
	_trib_earned = {}
	for k9: Variant in (d.get("trib_earned", {}) as Dictionary):
		_trib_earned[int(k9)] = int(d["trib_earned"][k9])
	reborn = {}
	for k10: Variant in (d.get("reborn", {}) as Dictionary):
		reborn[int(k10)] = int(d["reborn"][k10])
		var rc: Country = gw.country_by_id(int(k10))
		if rc != null and gw.has_method("reflag_country"):
			gw.reflag_country(rc, int(d["reborn"][k10]))
	conf = PeaceConfS.new(self)
	conf.load_state(d.get("conf", {}))
	care = CareS.new(self)
	care.load_state(d.get("care", {}))
	_stripe_sync()


static func _f1(v: float) -> String:
	return Loc.dec("%.1f" % v)
