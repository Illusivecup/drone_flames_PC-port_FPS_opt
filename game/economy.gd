class_name Economy
extends "res://game/economy/eco_trade.gd"






const Cad344: = preload("res://game/cad344.gd")


func _init(world: GameWorld) -> void :
	gw = world
	ports = Ports.new(world, self)
	trd = Trade331S.new(self)
	upk = Upkeep335S.new(self)




func update(dt: float) -> void :
	soft_tick()
	_t += dt
	if _t >= TICK:
		_t -= TICK
		_produce()
		_stat_cities()
		_stat_roll()
	_trade_t += dt
	if _trade_t >= TRADE_DT:
		_trade_t = 0.0
		_trade_tick()
	var cad: Cad344 = gw.cad344
	while cad != null and not cad.trade_q.is_empty() and cad.take_ai_slot():
		var tc: Country = gw.country_by_id(int(cad.trade_q.pop_front()))
		if tc != null and not tc.is_player and not tc.eliminated and tc.capital_id >= 0:
			_ai_trade(tc)
			_ai_upgrade(tc)
	_update_trucks(dt)
	ports.update(dt)
	_econ27_tick(dt)
	trd.update(dt)
	upk.update(dt)
	_snd_t += dt
	if _snd_t >= 0.5:
		_snd_t = 0.0
		_audio_tick()


func _produce() -> void :
	var mil: Military = gw.mil
	_cap_bonus.clear()
	drop_spent()
	_relocate_check()
	for f: Facility in mil.facilities:
		if not mil.alive(f):
			continue
		var c: Country = gw.country_by_id(f.country_id)
		if c == null:
			continue
		if f.halted:
			if is_extractor(f.kind) or f.kind == Facility.Kind.FARM or f.kind == Facility.Kind.CIV_FACTORY:
				_site_of(f)["status"] = "paused"
				_site_of(f)["rate"] = 0
			continue
		if gw.supply != null and gw.supply.cut_off(f):
			if is_extractor(f.kind) or f.kind == Facility.Kind.FARM or f.kind == Facility.Kind.CIV_FACTORY:
				var hard: bool = not gw.supply.has_method("cut_level") or int(gw.supply.cut_level(f)) >= 2
				_site_of(f)["status"] = "bridge_out" if hard else "detour"
				if hard:
					_site_of(f)["rate"] = 0
			continue
		var mul: float = 1.0 if c.is_player else GameConfig.ai_income_mul(c)
		match f.kind:
			Facility.Kind.FARM:
				var ff: int = ceili(FARM_FOOD * level_mul(f))
				c.food += ff
				stat_res(c, "food", "farm", ff)
				c.add_money(int(FARM_MONEY * mul * level_mul(f)))
				stat_add(c, "income", "farm", int(FARM_MONEY * mul * level_mul(f)))
				_puff(f)
			Facility.Kind.CIV_FACTORY:
				if mil.has_power(f):
					var cg: int = ceili(CIV_GOODS * level_mul(f))
					c.goods += cg
					stat_res(c, "goods", "civ", cg)
					c.add_money(int(CIV_MONEY * mul * level_mul(f)))
					stat_add(c, "income", "civ", int(CIV_MONEY * mul * level_mul(f)))
					_puff(f)
			Facility.Kind.MINE:
				if mil.has_power(f):
					_extract(f, c, mul)
				else:
					_site_of(f)["status"] = "no_power"
					_site_of(f)["rate"] = 0
			Facility.Kind.OIL_RIG:
				_extract(f, c, mul)
			Facility.Kind.URANIUM_MINE:
				if mil.has_power(f):
					_extract(f, c, mul)
				else:
					_site_of(f)["status"] = "no_power"
					_site_of(f)["rate"] = 0
			Facility.Kind.SAWMILL:
				_saw(f, c)
		if gw.supply != null and gw.supply.has_method("cut_level") and int(gw.supply.cut_level(f)) == 1 and (is_extractor(f.kind) or f.kind == Facility.Kind.FARM or f.kind == Facility.Kind.CIV_FACTORY):
			_site_of(f)["status"] = "detour"

	for c: Country in gw.countries:
		var n: int = gw.army.count_units(c.id)
		var need_f: int = (n + 2) / 3
		if c.food >= need_f:
			c.food -= need_f
			stat_res(c, "food", "army", - need_f)
		else:
			stat_res(c, "food", "army", - c.food)
			c.food = 0
			if n > 0:
				gw.army.starve(c.id)

		for r: String in TRADE_RES:
			var cap: int = res_cap(c, r)
			var v: int = int(c.get(r))
			if v > cap:
				c.set(r, cap)
				var ou: int = maxi(1, int(float(market_price(r)) * upk.sell_k(c.id, r)) / 2)
				var pay: int = (v - cap) * ou
				upk.note_trade(c.id, r, v - cap, ou)
				c.add_money(pay)
				stat_res(c, r, "surplus", - (v - cap))
				stat_add(c, "income", "surplus", pay)

	for cid: int in want.keys():
		var w: Dictionary = want[cid]
		var wt: Dictionary = want_t.get(cid, {})
		var c2: Country = gw.country_by_id(cid)
		for res: String in w.keys():
			if c2 == null or int(c2.get(res)) >= int(w[res]) or gw.game_time - float(wt.get(res, 0.0)) > 180.0:
				w.erase(res)
				wt.erase(res)
	_regrow()



func _extract(f: Facility, c: Country, mul: float) -> void :
	var st: Dictionary = _site_of(f)
	var dp: Dictionary = f.deposit
	st["rate"] = 0
	if dp.is_empty():
		st["status"] = "no_deposit"
		return
	var res: String = String(dp.get("res", "titanium"))
	var inf: bool = GameConfig.infinite_res()
	if int(dp["left"]) <= 0 and not inf:
		st["status"] = "depleted"
		if c.is_player and not _warned.has(f):
			_warned[f] = true
			gw.say(c, Loc.mk("Месторождение исчерпано: %s", [Loc.t(String(RES_NAMES[res]).to_lower())]))
		return
	var room: int = res_cap(c, res) - int(c.get(res))
	if room <= 0:
		st["status"] = "store_full"
		return
	var rate: int = ceili(float(RIG_OIL if f.kind == Facility.Kind.OIL_RIG else int(MINE_RATE.get(res, 2))) * level_mul(f))
	if f.kind == Facility.Kind.URANIUM_MINE:
		f.u_part += Nuclear.U_MINE_RATE
		rate = int(f.u_part)
		f.u_part -= float(rate)
		if rate <= 0:
			st["status"] = ""
			return
	var n: int = mini(rate, room if inf else mini(int(dp["left"]), room))
	c.set(res, int(c.get(res)) + n)
	if not inf:
		dp["left"] = int(dp["left"]) - n
	stat_res(c, res, "oil_rig" if f.kind == Facility.Kind.OIL_RIG else ("umine" if f.kind == Facility.Kind.URANIUM_MINE else "mine"), n)
	if f.kind == Facility.Kind.MINE or f.kind == Facility.Kind.URANIUM_MINE:
		c.add_money(int(MINE_MONEY * mul))
		stat_add(c, "income", "mine", int(MINE_MONEY * mul))
	st["status"] = ""
	st["rate"] = n




func _saw(f: Facility, c: Country) -> void :
	var st: Dictionary = _site_of(f)
	var mid: Vector2i = f.cell + f.size / 2
	var trees: int = count_trees(mid, SAW_R)
	st["trees"] = trees
	st["rate"] = 0
	if trees <= 0:
		st["status"] = "forest_cut"
		return
	var room: int = res_cap(c, "wood") - c.wood
	if room <= 0:
		st["status"] = "store_full"
		return
	var n: int = mini(ceili(float(mini(SAW_WOOD_MAX, 1 + trees / 15)) * level_mul(f)), room)
	c.wood += n
	stat_res(c, "wood", "sawmill", n)
	st["status"] = ""
	st["rate"] = n
	for _k in level_of(f):
		_fell(mid, SAW_R)


func _fell(mid: Vector2i, r: int) -> void :
	var d: WorldData = gw.data
	for k in range(3, r + 1):
		for i in 8 * k:
			var q: Vector2i
			var side: int = i / (2 * k)
			var o: int = i % (2 * k)
			match side:
				0:
					q = mid + Vector2i( - k + o, - k)
				1:
					q = mid + Vector2i(k, - k + o)
				2:
					q = mid + Vector2i(k - o, k)
				_:
					q = mid + Vector2i( - k, k - o)
			if not d.inside(q.x, q.y) or not gw.tree_at.has(q.y * d.w + q.x) or d.has_flag(q.x, q.y, WorldData.F_CITY):
				continue
			gw.remove_tree_at(q)
			var sid: int = gw.add_object("eco_stump", q, GameWorld.KIND_PROP)
			if sid >= 0:
				_stumps.append([sid, q, gw.game_time])
			var px: = Vector2(q * GameWorld.CELL) + Vector2(2, 2)
			if gw._on_screen(px, 30.0):
				gw.fx.spawn("dust_s", px, 5)
				Sfx.play("sawmill_saw", px)
			return


func _regrow() -> void :
	var d: WorldData = gw.data
	var stump_sid: int = int(gw.spr_index.get("eco_stump", -1))
	while not _stumps.is_empty() and gw.game_time - float(_stumps[0][2]) > REGROW_T:
		var s: Array = _stumps.pop_front()
		var id: int = s[0]
		var q: Vector2i = s[1]
		if id >= 0 and id < gw.obj_spr.size() and gw.obj_state[id] != 2 and gw.obj_spr[id] == stump_sid:
			gw.remove_object(id)
		var b: int = d.get_biome(q.x, q.y)
		if not GameWorld.TREE_NAMES.has(b) or d.has_flag(q.x, q.y, WorldData.F_OCCUPIED | WorldData.F_ROAD | WorldData.F_CITY) or gw.tree_at.has(q.y * d.w + q.x):
			continue
		var names: Array = GameWorld.TREE_NAMES[b]
		var tid: int = gw.add_object(String(names[Hash32.h2(q.x, q.y, 3) % names.size()]), q, GameWorld.KIND_TREE)
		if tid >= 0:
			gw.tree_at[q.y * d.w + q.x] = tid



func _audio_tick() -> void :
	var lp: Vector2 = Sfx.listener()
	var best: = Vector2.INF
	if lp.is_finite() and gw.camera != null and gw.camera.zoom.x >= 1.0:
		var bd: float = 260.0 * 260.0
		for f: Facility in gw.mil.facilities:
			if f.kind == Facility.Kind.OIL_RIG and site_working(f):
				var p: Vector2 = f.center_px()
				if p.distance_squared_to(lp) < bd:
					bd = p.distance_squared_to(lp)
					best = p
	Sfx.loop("pumpjack", "pumpjack_loop", best.is_finite(), best)



func site_working(f: Facility) -> bool:
	if not gw.mil.alive(f) or f.halted:
		return false
	var st: Dictionary = _site.get(f, {})
	return int(st.get("rate", 0)) > 0 or (st.is_empty() and not f.deposit.is_empty())


func _puff(f: Facility) -> void :
	if f.main_obj < 0 or not gw._on_screen(f.center_px(), 40.0):
		return
	var info: Dictionary = gw.mil._info(String(Military.SPRITES[f.kind]))
	if info.has("smoke"):
		gw.fx.spawn("smoke_s" if gw.fx_atlas.has("smoke_s") else "dust_s", gw.mil.local_px(f.main_obj, info["smoke"]), 5)


func _trade_tick() -> void :
	_demand.clear()
	_update_prices()

	for a: Country in gw.countries:
		for b: Country in gw.countries:
			if a.id >= b.id or a.is_player or b.is_player or a.eliminated or b.eliminated:
				continue
			if not gw.diplo.at_war(a.id, b.id) and gw.diplo.get_opinion(a.id, b.id) >= 5 and not gw.diplo.embargo_between(a.id, b.id):
				trade[Diplomacy.key(a.id, b.id)] = true
	for k: String in trade.keys():
		var ab: PackedStringArray = k.split(":")
		var a: Country = gw.country_by_id(int(ab[0]))
		var b: Country = gw.country_by_id(int(ab[1]))
		if a == null or b == null or a.eliminated or b.eliminated or a.capital_id < 0 or b.capital_id < 0 or gw.diplo.at_war(a.id, b.id) or gw.diplo.embargo_between(a.id, b.id):
			trade.erase(k)
			continue
		_ship(a, b)
		_ship(b, a)
	for c: Country in gw.countries:
		if not c.is_player and not c.eliminated and c.capital_id >= 0:
			if gw.cad344 != null:
				gw.cad344.trade_q.append(c.id)
				continue
			_ai_trade(c)
			_ai_upgrade(c)
	ports.export_tick()
	var gone: bool = false
	for i in range(requests.size() - 1, -1, -1):
		var rq: Dictionary = requests[i]
		var fc: Country = gw.country_by_id(int(rq["from"]))
		var tc: Country = gw.country_by_id(req_to(rq))
		if gw.game_time > float(rq["until"]) or fc == null or fc.eliminated or need(fc, String(rq["res"])) <= 0\
		or tc == null or not tc.is_player or tc.eliminated:
			requests.remove_at(i)
			gone = true
	if gone:
		_pending_changed()



func _ai_upgrade(c: Country) -> void :
	if _ai_deepen(c):
		return
	if c.money < 2500:
		return
	var best: Facility = null
	var bs: float = 0.0
	for f: Facility in gw.mil.facilities:
		if f.country_id != c.id or not UPG_RES.has(f.kind) or f.level >= MAX_LEVEL or not gw.mil.alive(f):
			continue
		if f.upg_t > 0.0 or ( not f.deposit.is_empty() and int(f.deposit["left"]) < 150 and not deep_low(f) and not GameConfig.infinite_res()):
			continue
		var cost: Dictionary = upgrade_cost(f)
		if not c.has_res(cost) or c.money < int(cost["money"]) + 1500:
			continue
		var r: String = out_res(f)
		var sc: float = float(need(c, r) + 5) * float(market_price(r)) / float(f.level)
		if sc > bs:
			bs = sc
			best = f
	if best != null:
		upgrade(best, c)




func save_state() -> Dictionary:
	return {"e": Save.dump(self, ["nav", "_reach", "_reach_ui", "_mkt_tag", "last_deal", "nav_last_ok", "_path_cache", "_nav_ver", "nav_soft", "nav_dry", "nav_last_soft", "_soft_cache", "_soft_left", 
		"nav_last_pending", "_leg_wet", "_soft_jobs", "_soft_gt", "_soft_tick_left", "_ap_memo", "_ap_gt", "_ap_left", "nav_solid_ver", "nav_solid_b"]), 
		"p": Save.dump(ports, ["sea", "body", "body_size", "body_edge", "_w", "_h"]), "t331": trd.save_state(), "u335": upk.save_state()}




func load_state(d: Dictionary) -> void :
	Save.fill(self, d.get("e", {}))
	Save.fill(ports, d.get("p", {}))
	for sf: Variant in _site:
		var sd: Dictionary = _site[sf]
		sd["status"] = site_code(String(sd.get("status", "")))
	trd = Trade331S.new(self)
	trd.load_state(d.get("t331", {}))
	upk.load_state(d.get("u335", {}), d.has("u335"))
	for dp: Dictionary in deposits:
		var f: Variant = dp.get("mine")
		if f is Facility:
			(f as Facility).deposit = dp
	if not (d.get("e", {}) as Dictionary).has("u_seeded"):
		generate_uranium(true)
	var uf: Dictionary = {}
	for k: Variant in u_fund:
		uf[int(k)] = int(u_fund[k])
	u_fund = uf
	ports.ensure_sea()
	if gw.get("navy") != null:
		gw.navy._ensure_nav()
	build_nav()
	_deep_on_load()
	draw_ver += 1



func _deep_tick(dt: float) -> void :
	_deep_t += dt
	if _deep_t < 1.0:
		return
	var step: float = _deep_t
	_deep_t = 0.0
	for f: Facility in gw.mil.facilities:
		if f.upg_t <= 0.0 or not gw.mil.alive(f):
			continue
		f.upg_t -= step
		if f.upg_t <= 0.0:
			f.upg_t = 0.0
			_deep_finish(f)


func _deep_finish(f: Facility) -> void :
	var c: Country = gw.country_by_id(f.country_id)
	f.level = mini(f.level + 1, MAX_LEVEL)
	var add: int = _deep_reserve(f)
	_place_extra(f)
	if c != null:
		_cap_bonus.erase(c.id)
	_warned.erase(f)
	_deep_apply_sprite(f)
	draw_ver += 1
	gw.fx.spawn("build_spark", f.center_px(), 8)
	if gw._on_screen(f.center_px(), 40.0):
		Sfx.play("ui_build", f.center_px())
	if c != null and c.is_player:
		gw.say(c, (Loc.t("%s готов: запас +%d, добыча ×%.1f") % [deep_name(f), add, float(LEVEL_MUL[f.level])]) if add > 0
			else (Loc.t("%s готов: добыча ×%.1f") % [deep_name(f), float(LEVEL_MUL[f.level])]))
	gw.changed.emit()



func upgrade_toast(f: Facility) -> String:
	if f != null and is_deep(f.kind) and f.upg_t > 0.0:
		var add: int = deep_add(f, f.level + 1) if int((f.deposit as Dictionary).get("deep_lv", 1)) < f.level + 1 else 0
		return (Loc.t("Строится «%s»: %d с, запас +%d") % [deep_name(f, f.level + 1), ceili(f.upg_t), add]) if add > 0 else (Loc.t("Строится «%s»: %d с, добыча ×%.1f") % [deep_name(f, f.level + 1), ceili(f.upg_t), float(LEVEL_MUL[mini(f.level + 1, MAX_LEVEL)])])
	return Loc.t("Улучшено: %s, уровень %d") % [Military.title_of(f.kind) if f != null else "", level_of(f)]




func deep_card(f: Facility) -> Dictionary:
	var res: String = out_res(f)
	var left: int = int(f.deposit.get("left", 0)) if not f.deposit.is_empty() else 0
	var mx: int = maxi(1, int(f.deposit.get("max", left)) if not f.deposit.is_empty() else 1)
	var busy: bool = f.upg_t > 0.0
	var nxt: int = f.level + 1
	var out: Dictionary = {"title": Loc.t("%s · УР %d") % [deep_name(f), f.level], "icon": String(RES_ICONS.get(res, "res_metal")), 
		"frac": float(left) / float(mx), "left": left, "max": mx, "busy": busy, "progress": 0.0, "eta": 0.0, 
		"next": deep_name(f, nxt) if nxt <= MAX_LEVEL else "", "next_add": 0, "detail": "", "inf": GameConfig.infinite_res()}
	if bool(out["inf"]):
		out["frac"] = 1.0
	var rate: float = maxf(1.0, base_rate(f) * level_mul(f))
	var mins: int = ceili(float(left) / rate * TICK / 60.0)
	if f.deposit.is_empty():
		out["detail"] = Loc.t("Нет месторождения рядом.")
		return out
	if nxt <= MAX_LEVEL:
		var opened: bool = int(f.deposit.get("deep_lv", 1)) >= nxt
		var add: int = 0 if opened else deep_add(f, nxt)
		out["next_add"] = add
		var gain: String = (Loc.t("запас +%d, ") % add) if add > 0 else ""
		var nr: int = ceili(base_rate(f) * float(LEVEL_MUL[nxt])) * 6
		if busy:
			var tot: float = maxf(1.0, float(DEEP_T[nxt]))
			out["progress"] = clampf(1.0 - f.upg_t / tot, 0.0, 1.0)
			out["eta"] = f.upg_t
			out["title"] = "%s → %s" % [deep_name(f), deep_name(f, nxt)]
			out["detail"] = Loc.t("Строится «%s»: %sдобыча +%d/мин. Пока идут работы, добыча идёт по-старому.") % [deep_name(f, nxt), gain, nr]
		elif GameConfig.infinite_res():
			out["detail"] = Loc.t("Залежь не иссякает (∞). «%s»: добыча +%d/мин, %d с работ.") % [deep_name(f, nxt), nr, int(DEEP_T[nxt])]
		elif left <= 0:
			out["detail"] = Loc.t("Залежь исчерпана. «%s» вскроет %s, добыча +%d/мин.") % [deep_name(f, nxt), (Loc.t("ещё %d") % add) if add > 0 else Loc.t("старые горизонты:"), nr]
		else:
			out["detail"] = Loc.t("Хватит на ~%d мин. «%s»: %sдобыча +%d/мин, %d с работ.") % [mins, deep_name(f, nxt), gain, nr, int(DEEP_T[nxt])]
	elif GameConfig.infinite_res():
		out["detail"] = Loc.t("Последний уровень. Залежь не иссякает (∞).")
	else:
		out["detail"] = (Loc.t("Последний уровень. Залежь исчерпана — ищите новые месторождения или покупайте.") if left <= 0
			else Loc.t("Последний уровень. Хватит на ~%d мин — заранее ищите новые залежи или включите автозакупку.") % mins)
	return out



func _deep_on_load() -> void :
	for f: Facility in gw.mil.facilities:
		if not is_deep(f.kind):
			continue
		f.level = clampi(f.level, 1, MAX_LEVEL)
		if f.upg_t < 0.0 or f.level >= MAX_LEVEL or is_nan(f.upg_t):
			f.upg_t = 0.0
		f.upg_t = minf(f.upg_t, float(DEEP_T[MAX_LEVEL]))
		if not f.deposit.is_empty() and not f.deposit.has("deep_lv"):
			_deep_reserve(f)
		if f.level >= 2:
			_deep_apply_sprite(f)



func _ai_deepen(c: Country) -> bool:
	for f: Facility in gw.mil.facilities:
		if f.country_id != c.id or not deep_low(f) or not gw.mil.alive(f):
			continue
		var cost: Dictionary = upgrade_cost(f)
		if cost.is_empty() or not c.has_res(cost) or c.money < int(cost.get("money", 0)) + 400:
			continue
		return upgrade(f, c) == ""
	return false


func _econ27_tick(dt: float) -> void :
	_deep_tick(dt)
	_px_t += dt
	if _px_t >= 15.0:
		_px_t = 0.0
		for res: String in PRICE:
			var h: Array = _px_hist.get(res, [])
			h.append(float(market_price(res)))
			while h.size() > 40:
				h.remove_at(0)
			_px_hist[res] = h
	_ab_t += dt
	if _ab_t < AB_DT:
		return
	_ab_t = 0.0
	for k: String in autobuy.keys():
		var c: Country = gw.country_by_id(int(k))
		if c == null or c.eliminated or c.capital_id < 0:
			continue
		_autobuy_country(c, autobuy[k])
