extends RefCounted


















const SANCT_MAX: int = 3
const SANCT_OP_FIRST: int = -8
const SANCT_OP_MORE: int = -4
const SANCT_OP_LIFT: int = 3
const IMPORT_STEP: float = 0.1
const IMPORT_CAP: float = 0.4
const ANSWER_T: float = 120.0
const CANCEL_T: float = 60.0
const PENALTY: float = 0.2
const BREACH_OP: int = -15
const PER_MIN: int = 5
const PER_MAX: int = 60
const EVERY_OPTS: Array[int] = [60, 120, 180, 300]
const N_MIN: int = 2
const N_MAX: int = 20
const PRICE_LO: float = 0.5
const PRICE_HI: float = 2.0
const PAIR_MAX: int = 3
const PERSON_MAX: int = 6
const OFFER_GAP: float = 30.0
const WARN_T: float = 30.0
const KEEP_DONE: float = 180.0
const PLAN_DT: float = 6.0
const PLAN_GAP: float = 420.0
const PLAN_SHARE: float = 0.08
const STOP_WHY: Dictionary = {"war": "война", "embargo": "эмбарго", "sanction": "санкции", "gone": "страны нет", "left": "игрок вышел", 
	"noroute": "нет пути", "breach": "срыв поставки", "cancel": "расторгнут", "done": "выполнен", "offline": "не в сети"}

const K_FIELDS: Array[String] = ["id", "s", "b", "by", "res", "per", "every", "n", "price", "made", "until", "next", "done", "noroute", "state", "end", "why", "cq", "cq_t", "warned"]
static var test_online: bool = false

var econ
var gw: GameWorld
var sanct: Dictionary = {}
var contracts: Array = []
var next_kid: int = 1
var offer_t: Dictionary = {}
var plan_next: Dictionary = {}
var stats: Dictionary = {}
var _t: float = 0.0
var _plan_t: float = 0.0


func _init(e) -> void :
	econ = e
	gw = e.gw


func _count(k: String, n: int = 1) -> void :
	stats[k] = int(stats.get(k, 0)) + n


func _dp() -> Diplomacy:
	return gw.diplo


func _alive(id: int) -> bool:
	var c: Country = gw.country_by_id(id)
	return c != null and not c.eliminated and c.capital_id >= 0


func _cn(id: int) -> String:
	var c: Country = gw.country_by_id(id)
	return c.name if c != null else "?"


static func rname(res: String) -> String:
	return String(Economy.RES_NAMES.get(res, res))





func res_blocked(a: int, b: int, res: String) -> bool:
	if a == b:
		return false
	var dp: Diplomacy = _dp()
	if dp != null and dp.embargo_between(a, b):
		return true
	if sanct.is_empty():
		return false
	return has_sanction(a, b, res) or has_sanction(b, a, res)


func has_sanction(by: int, on: int, res: String) -> bool:
	var d: Dictionary = sanct.get("%d>%d" % [by, on], {})
	return d.has(res)



func sanctions_by(by: int, on: int) -> Array:
	var out: Array = []
	var d: Dictionary = sanct.get("%d>%d" % [by, on], {})
	for r: String in Economy.TRADE_RES:
		if d.has(r):
			out.append(r)
	return out



func sanctions_on(on: int) -> Array:
	var out: Array = []
	for k: String in _sorted_keys():
		var ab: PackedStringArray = k.split(">")
		if int(ab[1]) != on:
			continue
		var d: Dictionary = sanct[k]
		for r: String in Economy.TRADE_RES:
			if d.has(r):
				out.append({"by": int(ab[0]), "res": r, "since": float(d[r][0]), "until": float(d[r][1])})
	return out



func sanctions_of(by: int) -> Array:
	var out: Array = []
	for k: String in _sorted_keys():
		var ab: PackedStringArray = k.split(">")
		if int(ab[0]) != by:
			continue
		var d: Dictionary = sanct[k]
		for r: String in Economy.TRADE_RES:
			if d.has(r):
				out.append({"on": int(ab[1]), "res": r, "since": float(d[r][0]), "until": float(d[r][1])})
	return out


func _sorted_keys() -> Array:
	var ks: Array = sanct.keys()
	ks.sort_custom( func(x: Variant, y: Variant) -> bool:
		var xa: PackedStringArray = String(x).split(">")
		var ya: PackedStringArray = String(y).split(">")
		return int(xa[0]) < int(ya[0]) or (int(xa[0]) == int(ya[0]) and int(xa[1]) < int(ya[1])))
	return ks



func sanction_count(on: int, res: String) -> int:
	var n: int = 0
	var dp: Diplomacy = _dp()
	for c: Country in gw.countries:
		if c.id == on or c.eliminated:
			continue
		if has_sanction(c.id, on, res) or (dp != null and dp.embargoed(c.id, on)):
			n += 1
	return n



func import_mul(cid: int, res: String) -> float:
	if cid <= 0 or sanct.is_empty() and (_dp() == null or _dp().embargo.is_empty()):
		return 1.0
	return 1.0 + minf(IMPORT_CAP, IMPORT_STEP * float(sanction_count(cid, res)))



func can_sanction(by: int, on: int, res: String = "", bot: bool = false) -> String:
	var dp: Diplomacy = _dp()
	if by == on:
		return Loc.t("Это ваша страна")
	if not _alive(by) or not _alive(on):
		return Loc.t("Страны нет")
	if res != "" and not Economy.TRADE_RES.has(res):
		return Loc.t("Этим не торгуют")
	if dp.at_war(by, on):
		return Loc.t("Война: торговли и так нет")
	if dp.embargoed(by, on):
		return Loc.t("Уже эмбарго: торговля закрыта целиком")
	if dp.allied(by, on) or (dp.ally != null and dp.ally.same(by, on)):
		return Loc.t("Союзник: сначала расторгните союз")
	if dp.has_treaty(by, on, "defense"):
		return Loc.t("Договор обороны: сначала расторгните его")
	if bot and (dp.subject_of(by) == on or dp.subject_of(on) == by):
		return Loc.t("Сюзерен и подданный")
	if res != "" and not has_sanction(by, on, res) and sanctions_by(by, on).size() >= SANCT_MAX:
		return Loc.t("Не больше %d материалов — дальше только эмбарго") % SANCT_MAX
	return ""



func sanction_grid(me: int, other: int) -> Array:
	var out: Array = []
	var lack: Array = econ.scarce_of(gw.country_by_id(other)) if gw.country_by_id(other) != null else []
	var base: String = can_sanction(me, other)
	for r: String in Economy.TRADE_RES:
		var on: bool = has_sanction(me, other, r)
		var why: String = base
		var cap: bool = false
		if why == "" and not on and sanctions_by(me, other).size() >= SANCT_MAX:
			why = Loc.t("Не больше %d — дальше эмбарго") % SANCT_MAX
			cap = true
		out.append({"res": r, "name": String(Economy.RES_SHORT.get(r, r)), "icon": String(Economy.RES_ICONS.get(r, "res_metal")), 
			"on": on, "scarce": lack.has(r), "why": why, "cap": cap})
	return out




func sanction_preview(me: int, other: int, want: Array) -> Dictionary:
	var cur: Array = sanctions_by(me, other)
	var add: Array = []
	var drop: Array = []
	for r: String in Economy.TRADE_RES:
		if want.has(r) and not cur.has(r):
			add.append(r)
		elif cur.has(r) and not want.has(r):
			drop.append(r)
	var op: int = 0
	var cap: bool = false
	for i in add.size():
		op += SANCT_OP_FIRST if i == 0 else SANCT_OP_MORE
	op += SANCT_OP_LIFT * drop.size()
	var why: String = ""
	if add.is_empty() and drop.is_empty():
		why = Loc.t("Ничего не выбрано")
	elif not add.is_empty():
		why = can_sanction(me, other)
		if why == "" and cur.size() - drop.size() + add.size() > SANCT_MAX:
			why = Loc.t("Не больше %d материалов — дальше только эмбарго") % SANCT_MAX
			cap = true
	var parts: PackedStringArray = PackedStringArray()
	for r2: String in add:
		parts.append(String(Economy.RES_SHORT.get(r2, r2)))
	var txt: String = ""
	var ops: String = ("%+d" % op).replace("-", "−")
	if not add.is_empty():
		txt = Loc.t("ВВЕСТИ: %s · %s") % [", ".join(parts), ops]
	elif not drop.is_empty():
		txt = Loc.t("СНЯТЬ: %d · %s") % [drop.size(), ops]
	return {"add": add, "drop": drop, "opinion": op, "why": why, "text": txt, "cap": cap}




func set_sanctions(me: int, other: int, want: Array) -> String:
	var w: Array = []
	for v: Variant in want:
		if v is String and Economy.TRADE_RES.has(String(v)) and not w.has(String(v)):
			w.append(String(v))
	var pv: Dictionary = sanction_preview(me, other, w)
	if String(pv["why"]) != "":
		return String(pv["why"])
	for r: String in pv["drop"]:
		_lift(me, other, r, false)
	var added: Array = pv["add"]
	for i in added.size():
		_impose(me, other, String(added[i]), -1.0, SANCT_OP_FIRST if i == 0 else SANCT_OP_MORE, i == added.size() - 1)
	if not (pv["drop"] as Array).is_empty() and added.is_empty():
		_lift_note(me, other, pv["drop"])
	gw.relations_changed.emit()
	return ""





func impose_sanction(by: int, on: int, res: String, dur: float = -1.0) -> String:
	if res == "":
		res = pick_material(by, on)
		if res == "":
			return Loc.t("Нечем давить")
	var bc: Country = gw.country_by_id(by)
	if bc == null:
		return Loc.t("Страны нет")
	var why: String = can_sanction(by, on, res, not bc.is_player)
	if why != "":
		return why
	if has_sanction(by, on, res):
		return ""
	var until: float = -1.0
	if not bc.is_player:
		until = gw.game_time + (dur if dur > 0.0 else lerpf(600.0, 300.0, float(_dp()._p(by)["trade"])))
	elif dur > 0.0:
		until = gw.game_time + dur
	_impose(by, on, res, until, SANCT_OP_FIRST, true)
	gw.relations_changed.emit()
	return ""


func lift_sanction(by: int, on: int, res: String) -> String:
	if not has_sanction(by, on, res):
		return Loc.t("Санкций нет")
	_lift(by, on, res, true)
	gw.relations_changed.emit()
	return ""



func lift_all(by: int, on: int, quiet: bool = false) -> int:
	var rs: Array = sanctions_by(by, on)
	for r: String in rs:
		_lift(by, on, r, false)
	if not rs.is_empty() and not quiet:
		_lift_note(by, on, rs)
	return rs.size()




func pick_material(by: int, on: int) -> String:
	var ct: Country = gw.country_by_id(on)
	var cb: Country = gw.country_by_id(by)
	if ct == null or cb == null:
		return ""
	var lack: Array = econ.scarce_of(ct)
	var best: String = ""
	var bv: int = -1
	for r: String in ["oil", "titanium", "metal", "food", "uranium", "precious", "wood", "goods"]:
		if has_sanction(by, on, r):
			continue
		var bs: Country = econ.best_seller(cb, r) if not econ.ui_time() else null
		if bs != null and bs.id == on:
			continue
		var v: int = maxi(0, econ.need(ct, r)) + (30 if lack.has(r) else 0) + (10 if _trades(by, on, r) else 0)
		if v > bv:
			bv = v
			best = r
	return best



func _trades(a: int, b: int, res: String) -> bool:
	for t: Dictionary in econ.trucks:
		if String(t["res"]) == res and ((int(t["from"]) == a and int(t["to"]) == b) or (int(t["from"]) == b and int(t["to"]) == a)):
			return true
	for j: Dictionary in econ.rail_jobs:
		if String(j["res"]) == res and ((int(j["from"]) == a and int(j["to"]) == b) or (int(j["from"]) == b and int(j["to"]) == a)):
			return true
	return false


func _impose(by: int, on: int, res: String, until: float, op: int, tell: bool) -> void :
	var k: String = "%d>%d" % [by, on]
	if not sanct.has(k):
		sanct[k] = {}
	(sanct[k] as Dictionary)[res] = [gw.game_time, until]
	var dp: Diplomacy = _dp()
	dp.add_opinion(by, on, op)
	_count("sanctions")
	dp._reveal(by, on)
	gw.news_m(Loc.mk("САНКЦИИ: %s → %s (%s)", [Loc.name(dp._name(by)), Loc.name(dp._name(on)), rname(res)]), "amber")
	if tell:
		var rs: PackedStringArray = PackedStringArray()
		for r: String in sanctions_by(by, on):
			rs.append(rname(r))
		var n: int = sanction_count(on, res)
		gw.say(on, Loc.t("САНКЦИИ: %s — %s. Импорт %s +%d %% (%d %s)") % [_cn(by), ", ".join(rs), String(Economy.RES_GEN.get(res, rname(res).to_lower())), 
			roundi(minf(IMPORT_CAP, IMPORT_STEP * float(n)) * 100.0), n, Loc.n(n, "страна", "страны", "стран", "count")])
		var ra: Variant = ""
		var first: bool = true
		for r2: String in sanctions_by(by, on):
			var lo: String = rname(r2).to_lower()
			ra = lo if first else Loc.mk("%s, %s", [ra, lo])
			first = false
		gw.say(by, Loc.mk("Санкции против страны %s: %s", [_cn(on), ra]))


func _lift(by: int, on: int, res: String, tell: bool) -> void :
	var k: String = "%d>%d" % [by, on]
	if not sanct.has(k):
		return
	(sanct[k] as Dictionary).erase(res)
	if (sanct[k] as Dictionary).is_empty():
		sanct.erase(k)
	_dp().add_opinion(by, on, SANCT_OP_LIFT)
	_count("sanctions_lifted")
	if tell:
		_lift_note(by, on, [res])


func _lift_note(by: int, on: int, rs: Array) -> void :
	var nm: PackedStringArray = PackedStringArray()
	for r: Variant in rs:
		nm.append(rname(String(r)).to_lower())
	gw.news_m(Loc.mk("САНКЦИИ СНЯТЫ: %s → %s", [_dp()._name(by), _dp()._name(on)]), "grass_light")
	gw.say2(by, on, Loc.mk("%s снимает санкции со страны %s: %s", [Loc.name(_cn(by)), Loc.name(_cn(on)), ", ".join(nm)]))




func _sanct_tick() -> void :
	if sanct.is_empty():
		return
	var dp: Diplomacy = _dp()
	for k: String in _sorted_keys():
		var ab: PackedStringArray = k.split(">")
		var by: int = int(ab[0])
		var on: int = int(ab[1])
		if not _alive(by) or not _alive(on) or dp.at_war(by, on):
			sanct.erase(k)
			continue
		if dp.allied(by, on) or dp.has_treaty(by, on, "defense") or (dp.ally != null and dp.ally.same(by, on)):
			lift_all(by, on)
			continue
		var d: Dictionary = sanct[k]
		for r: String in Economy.TRADE_RES:
			if not d.has(r):
				continue
			var until: float = float(d[r][1])
			if until < 0.0 or gw.game_time < until:
				continue
			var bc: Country = gw.country_by_id(by)
			if bc != null and not bc.is_player and dp.relation(by, on) <= -35:
				d[r] = [float(d[r][0]), gw.game_time + 120.0]
			else:
				_lift(by, on, r, true)
		if sanct.has(k) and (sanct[k] as Dictionary).is_empty():
			sanct.erase(k)




func online() -> bool:
	return gw.net_driven or test_online



func contract_why(me: int, other: int, res: String = "") -> String:
	var a: Country = gw.country_by_id(me)
	var b: Country = gw.country_by_id(other)
	if a == null or b == null or me == other:
		return Loc.t("Страны нет")
	if not online():
		return Loc.t("Только в сетевой партии")
	if not b.is_player:
		return Loc.t("Только с игроком")
	if not a.is_player:
		return Loc.t("Только для игрока")
	if not _alive(me) or not _alive(other):
		return Loc.t("Нет столицы")
	var dp: Diplomacy = _dp()
	if dp.at_war(me, other):
		return Loc.t("Война: торговли нет")
	if dp.embargo_between(me, other):
		return Loc.t("Эмбарго: торговля закрыта")
	if res != "":
		if not Economy.TRADE_RES.has(res):
			return Loc.t("Этим не торгуют")
		if res_blocked(me, other, res):
			return Loc.t("Санкции: %s") % rname(res).to_lower()
	if _active(me, other) >= PAIR_MAX:
		return Loc.t("Не больше %d контрактов с одной страной") % PAIR_MAX
	if _active(me, -1) >= PERSON_MAX or _active(other, -1) >= PERSON_MAX:
		return Loc.t("Не больше %d контрактов у игрока") % PERSON_MAX
	return ""


func _active(me: int, other: int) -> int:
	var n: int = 0
	for k: Dictionary in contracts:
		var st: String = String(k["state"])
		if st != "offer" and st != "on":
			continue
		var a: int = int(k["s"])
		var b: int = int(k["b"])
		if (a == me or b == me) and (other < 0 or a == other or b == other):
			n += 1
	return n




func contract_terms(me: int, other: int, res: String, selling: bool) -> Dictionary:
	var mp: int = econ.market_price(res) if Economy.TRADE_RES.has(res) else 0
	var a: Country = gw.country_by_id(me)
	var b: Country = gw.country_by_id(other)
	var buyer: Country = b if selling else a
	var per: Array = []
	for v in range(PER_MIN, PER_MAX + 1, 5):
		per.append(v)
	return {"market": mp, "price_min": maxi(1, int(floor(float(mp) * PRICE_LO))), "price_max": maxi(1, int(ceil(float(mp) * PRICE_HI))), 
		"per": per, "every": EVERY_OPTS.duplicate(), "n_min": N_MIN, "n_max": N_MAX, 
		"have": int(a.get(res)) if a != null and Economy.TRADE_RES.has(res) else 0, 
		"room": econ.res_cap(buyer, res) if buyer != null and Economy.TRADE_RES.has(res) else 0, 
		"why": contract_why(me, other, res)}





func contract_offer(me: int, other: int, res: String, per: int, every: int, n: int, price: int, selling: bool) -> String:
	var why: String = contract_why(me, other, res)
	if why != "":
		return why
	if per < PER_MIN or per > PER_MAX or per % 5 != 0:
		return Loc.t("Объём: %d…%d, шаг 5") % [PER_MIN, PER_MAX]
	if not EVERY_OPTS.has(every):
		return Loc.t("Срок между поставками: 1, 2, 3 или 5 мин")
	if n < N_MIN or n > N_MAX:
		return Loc.t("Поставок: %d…%d") % [N_MIN, N_MAX]
	var t: Dictionary = contract_terms(me, other, res, selling)
	if price < int(t["price_min"]) or price > int(t["price_max"]):
		return Loc.t("Цена: %d…%d за ед. (рынок %d)") % [int(t["price_min"]), int(t["price_max"]), int(t["market"])]
	var ok: String = "%d>%d" % [me, other]
	if gw.game_time - float(offer_t.get(ok, -1000000000.0)) < OFFER_GAP:
		return Loc.t("Новое предложение — через %d с") % ceili(OFFER_GAP - (gw.game_time - float(offer_t[ok])))
	var s: Country = gw.country_by_id(me if selling else other)
	var b: Country = gw.country_by_id(other if selling else me)
	if not econ.can_reach(s, b):
		return Loc.t("Нет пути: ни дороги, ни рельсов, ни моря между столицами")
	offer_t[ok] = gw.game_time
	var k: Dictionary = {"id": next_kid, "s": s.id, "b": b.id, "by": me, "res": res, "per": per, "every": every, "n": n, "price": price, 
		"made": gw.game_time, "until": gw.game_time + ANSWER_T, "next": 0.0, "done": 0, "noroute": 0, "state": "offer", "end": -1.0, "why": "", 
		"cq": -1, "cq_t": -1.0, "warned": -1}
	next_kid += 1
	contracts.append(k)
	_count("contract_offers")
	gw.say(other, Loc.mk("%s предлагает контракт: %s", [Loc.name(_cn(me)), contract_text(k, other)]))
	gw.say(me, Loc.mk("Контракт предложен стране %s: ждём ответа до 2:00", [Loc.name(_cn(other))]))
	if _dp() != null:
		_dp().pending_changed.emit()
	return ""



func contract_text(k: Dictionary, me: int) -> String:
	var sell: bool = int(k["s"]) == me
	var tot: int = int(k["price"]) * int(k["per"]) * int(k["n"])

	return Loc.t("%s %s %d × %d · раз в %d мин · %d за ед. (%d)") % [Loc.t("ПРОДАЁТЕ") if sell else Loc.t("ПОКУПАЕТЕ"), (Loc.t("ЕДУ") if String(k["res"]) == "food" else rname(String(k["res"]))), int(k["per"]), int(k["n"]), 
		int(k["every"]) / 60, int(k["price"]), tot]


func find(kid: int) -> Dictionary:
	for k: Dictionary in contracts:
		if int(k["id"]) == kid:
			return k
	return {}



func item_to(n: int) -> int:
	var k: Dictionary = find(absi(n))
	if k.is_empty():
		return -1
	if n > 0:
		if String(k["state"]) != "offer":
			return -1
		return int(k["b"]) if int(k["by"]) == int(k["s"]) else int(k["s"])
	if String(k["state"]) != "on" or int(k["cq"]) < 0:
		return -1
	return int(k["b"]) if int(k["cq"]) == int(k["s"]) else int(k["s"])



func pending(me: int, now: float) -> Array:
	var out: Array = []
	for k: Dictionary in contracts:
		var kid: int = int(k["id"])
		if item_to(kid) == me:
			out.append({"id": "x%d" % kid, "from": int(k["by"]), "kind": "contract", "icon": "net_handshake", 
				"text": Loc.t("%s предлагает контракт: %s") % [_cn(int(k["by"])), contract_text(k, me)], 
				"deadline": float(k["until"]), "left": maxf(0.0, float(k["until"]) - now), "total": ANSWER_T, 
				"options": [{"act": "accept", "label": Loc.t("ПРИНЯТЬ")}, {"act": "refuse", "label": Loc.t("ОТКАЗАТЬ")}]})
		elif item_to( - kid) == me:
			out.append({"id": "x-%d" % kid, "from": int(k["cq"]), "kind": "contract_cancel", "icon": "net_handshake", 
				"text": Loc.t("%s просит расторгнуть контракт без неустойки: %s") % [_cn(int(k["cq"])), contract_text(k, me)], 
				"deadline": float(k["cq_t"]) + CANCEL_T, "left": maxf(0.0, float(k["cq_t"]) + CANCEL_T - now), "total": CANCEL_T, 
				"options": [{"act": "accept", "label": Loc.t("РАСТОРГНУТЬ")}, {"act": "refuse", "label": Loc.t("НЕТ")}]})
	return out




func contract_answer(me: int, kid: int, yes: bool) -> String:
	if item_to(kid) != me:
		return Loc.t("Нет такого")
	var k: Dictionary = find(absi(kid))
	if kid < 0:
		if yes:
			_end(k, "cancel", Loc.t("расторгнут по согласию"), -1)
		else:
			k["cq"] = -1
			k["cq_t"] = -1.0
			gw.say(int(k["s"]) if me == int(k["b"]) else int(k["b"]), Loc.mk("%s против расторжения контракта", [Loc.name(_cn(me))]))
		_changed()
		return ""
	var other: int = int(k["by"])
	if not yes:
		_end(k, "refused", Loc.t("отказ"), -1)
		gw.say(other, Loc.mk("%s отклоняет контракт: %s", [Loc.name(_cn(me)), contract_text(k, other)]))
		_changed()
		return ""
	var fw: String = _force_why(k)
	if fw != "":
		return Loc.t("Контракт невозможен: %s") % String(STOP_WHY.get(fw, fw))
	if not econ.can_reach(gw.country_by_id(int(k["s"])), gw.country_by_id(int(k["b"]))):
		return Loc.t("Нет пути: ни дороги, ни рельсов, ни моря между столицами")
	k["state"] = "on"
	k["next"] = gw.game_time + 5.0
	_count("contracts")
	gw.say2(int(k["s"]), int(k["b"]), Loc.mk("Контракт подписан: %s %d × %d, %d за ед.", [rname(String(k["res"])).to_lower(), int(k["per"]), int(k["n"]), int(k["price"])]))
	_dp().add_opinion(int(k["s"]), int(k["b"]), 3)
	_changed()
	return ""





func contract_cancel(me: int, kid: int, force: bool) -> String:
	var k: Dictionary = find(kid)
	if k.is_empty() or (int(k["s"]) != me and int(k["b"]) != me):
		return Loc.t("Нет такого контракта")
	if String(k["state"]) == "offer":
		if int(k["by"]) != me:
			return contract_answer(me, kid, false)
		_end(k, "cancel", Loc.t("предложение отозвано"), -1)
		_changed()
		return ""
	if String(k["state"]) != "on":
		return Loc.t("Контракт уже закрыт")
	var asked: bool = int(k["cq"]) >= 0 and int(k["cq"]) != me and gw.game_time - float(k["cq_t"]) <= CANCEL_T
	if asked:
		_end(k, "cancel", Loc.t("расторгнут по согласию"), -1)
	elif force:
		_end(k, "cancel", Loc.t("расторгнут в одностороннем порядке"), me)
	else:
		if int(k["cq"]) == me:
			return Loc.t("Уже просили — ждём ответа")
		k["cq"] = me
		k["cq_t"] = gw.game_time
		var other: int = int(k["b"]) if me == int(k["s"]) else int(k["s"])
		gw.say(other, Loc.mk("%s просит расторгнуть контракт (%s) — ответ во «Входящих»", [Loc.name(_cn(me)), rname(String(k["res"])).to_lower()]))
	_changed()
	return ""



func cancel_cost(me: int, kid: int) -> int:
	var k: Dictionary = find(kid)
	if k.is_empty() or String(k["state"]) != "on":
		return 0
	if int(k["cq"]) >= 0 and int(k["cq"]) != me and gw.game_time - float(k["cq_t"]) <= CANCEL_T:
		return 0
	var c: Country = gw.country_by_id(me)
	return mini(_left_value(k), c.money if c != null else 0)


func _left_value(k: Dictionary) -> int:
	return roundi(float(int(k["price"]) * int(k["per"]) * maxi(0, int(k["n"]) - int(k["done"]))) * PENALTY)





func contracts_of(me: int, other: int = -1) -> Array:
	var out: Array = []
	for k: Dictionary in contracts:
		var a: int = int(k["s"])
		var b: int = int(k["b"])
		if (a != me and b != me) or (other >= 0 and a != other and b != other):
			continue
		var st: String = String(k["state"])
		out.append({"id": int(k["id"]), "s": a, "b": b, "res": String(k["res"]), "per": int(k["per"]), "every": int(k["every"]), "n": int(k["n"]), 
			"price": int(k["price"]), "done": int(k["done"]), "state": st, "selling": a == me, "by": int(k["by"]), 
			"next_in": maxf(0.0, float(k["next"]) - gw.game_time) if st == "on" else -1.0, 
			"answer_in": maxf(0.0, float(k["until"]) - gw.game_time) if st == "offer" else -1.0, 
			"cancel_req": int(k["cq"]), "text": contract_text(k, me), "why": String(k["why"]), "penalty": cancel_cost(me, int(k["id"]))})
	out.sort_custom( func(x: Dictionary, y: Dictionary) -> bool:
		var xa: int = 0 if String(x["state"]) == "on" else (1 if String(x["state"]) == "offer" else 2)
		var ya: int = 0 if String(y["state"]) == "on" else (1 if String(y["state"]) == "offer" else 2)
		return xa < ya or (xa == ya and int(x["id"]) < int(y["id"])))
	return out



func _force_why(k: Dictionary) -> String:
	var s: int = int(k["s"])
	var b: int = int(k["b"])
	var cs: Country = gw.country_by_id(s)
	var cb: Country = gw.country_by_id(b)
	if cs == null or cb == null or not _alive(s) or not _alive(b):
		return "gone"
	if not cs.is_player or not cb.is_player:
		return "left"
	if not online():
		return "offline"
	var dp: Diplomacy = _dp()
	if dp.at_war(s, b):
		return "war"
	if dp.embargo_between(s, b):
		return "embargo"
	if res_blocked(s, b, String(k["res"])):
		return "sanction"
	return ""




func _imposer(k: Dictionary, fw: String) -> int:
	var s: int = int(k["s"])
	var b: int = int(k["b"])
	var a_s: bool = false
	var a_b: bool = false
	if fw == "sanction":
		a_s = has_sanction(s, b, String(k["res"]))
		a_b = has_sanction(b, s, String(k["res"]))
	elif fw == "embargo":
		a_s = _dp().embargoed(s, b)
		a_b = _dp().embargoed(b, s)
	if a_s == a_b:
		return -1
	return s if a_s else b




func _end(k: Dictionary, state: String, why: String, guilty: int, code: String = "") -> void :
	var was: String = String(k["state"])
	k["state"] = state
	k["why"] = why
	k["end"] = gw.game_time
	k["cq"] = -1
	if was != "on":
		return
	var s: int = int(k["s"])
	var b: int = int(k["b"])
	if guilty >= 0:
		var other: int = b if guilty == s else s
		var cg: Country = gw.country_by_id(guilty)
		var co: Country = gw.country_by_id(other)
		var pay: int = mini(_left_value(k), cg.money if cg != null else 0)
		if pay > 0 and cg != null and co != null:
			cg.money -= pay
			co.add_money(pay)
			econ.stat_add(cg, "spend", "trade", pay)
			econ.stat_add(co, "income", "trade", pay)
		_dp().add_opinion(guilty, other, BREACH_OP)
		_count("contract_penalties")
		_count("penalty_value", pay)
		var rn: String = rname(String(k["res"])).to_lower()
		if state == "stop" and (code == "sanction" or code == "embargo"):

			var sw: String = Loc.t("санкций") if code == "sanction" else Loc.t("эмбарго")
			gw.say(guilty, Loc.mk("Контракт (%s): разрыв из-за ваших %s: неустойка %d, отношения со страной %s %d", [rn, sw, pay, Loc.name(_cn(other)), BREACH_OP]))
			gw.say(other, Loc.mk("Контракт (%s): разрыв из-за %s страны %s: неустойка +%d вам", [rn, sw, Loc.name(_cn(guilty)), pay]))
		else:
			gw.say(guilty, Loc.mk("Контракт (%s) %s: неустойка −%d, отношения со страной %s %d", [rn, why, pay, Loc.name(_cn(other)), BREACH_OP]))
			gw.say(other, Loc.mk("Контракт (%s) %s по вине страны %s: неустойка +%d", [rn, why, Loc.name(_cn(guilty)), pay]))
	else:
		gw.say2(s, b, Loc.mk("Контракт (%s %d/%d): %s", [rname(String(k["res"])).to_lower(), int(k["done"]), int(k["n"]), why]))
	_count("contract_" + state)


func _changed() -> void :
	gw.relations_changed.emit()
	if _dp() != null:
		_dp().pending_changed.emit()



func _contract_tick() -> void :
	var now: float = gw.game_time
	var changed: bool = false
	for i in range(contracts.size() - 1, -1, -1):
		var k: Dictionary = contracts[i]
		var st: String = String(k["state"])
		if st != "offer" and st != "on":
			if now - float(k["end"]) > KEEP_DONE:
				contracts.remove_at(i)
				changed = true
			continue
		var fw: String = _force_why(k)
		if st == "offer":
			if fw != "" or now >= float(k["until"]):
				_end(k, "lapsed", Loc.t("нет ответа") if fw == "" else String(STOP_WHY.get(fw, fw)), -1)
				if fw == "":
					gw.say(int(k["by"]), Loc.mk("Нет ответа от страны %s на контракт (%s)", [Loc.name(_cn(int(k["b"]) if int(k["by"]) == int(k["s"]) else int(k["s"]))), rname(String(k["res"])).to_lower()]))
				changed = true
			continue
		if int(k["cq"]) >= 0 and now - float(k["cq_t"]) > CANCEL_T:
			k["cq"] = -1
			k["cq_t"] = -1.0
			changed = true
		if fw != "":
			_end(k, "stop", Loc.t("остановлен: %s") % [String(STOP_WHY.get(fw, fw))], _imposer(k, fw), fw)
			changed = true
			continue
		var s: Country = gw.country_by_id(int(k["s"]))
		var b: Country = gw.country_by_id(int(k["b"]))
		var res: String = String(k["res"])
		var per: int = int(k["per"])
		if now < float(k["next"]):
			if int(k["warned"]) != int(k["done"]) and float(k["next"]) - now <= WARN_T and int(s.get(res)) < per:
				k["warned"] = int(k["done"])
				gw.say(s, Loc.mk("Контракт: через %d с поставка — %s %d, у вас %d. Не будет товара — неустойка", [ceili(float(k["next"]) - now), rname(res).to_lower(), per, int(s.get(res))]))
			continue
		changed = true
		if int(s.get(res)) < per:
			_end(k, "broken", Loc.t("сорван: у продавца нет товара"), s.id)
			continue
		var unit: int = int(k["price"])
		var q: int = mini(per, econ.room_for(b, res))
		if q <= 0:
			k["done"] = int(k["done"]) + 1
			k["next"] = now + float(int(k["every"]))
			gw.say2(s, b, Loc.mk("Контракт: склад страны %s полон — поставка %d/%d пропущена", [Loc.name(b.name), int(k["done"]), int(k["n"])]))
			if int(k["done"]) >= int(k["n"]):
				_end(k, "done", Loc.t("выполнен"), -1)
			continue
		if b.money < unit * q:
			_end(k, "broken", Loc.t("сорван: покупателю нечем платить"), b.id)
			continue
		s.set(res, int(s.get(res)) - q)
		econ.stat_res(s, res, "trade", - q)
		var mode: String = econ._send(s, b, res, q, unit * q)
		if mode == "":
			s.set(res, int(s.get(res)) + q)
			econ.stat_res(s, res, "trade", q)
			k["noroute"] = int(k["noroute"]) + 1
			k["next"] = now + float(int(k["every"]))
			if int(k["noroute"]) >= 2:
				_end(k, "stop", Loc.t("остановлен: нет пути"), -1)
			else:
				gw.say2(s, b, Loc.mk("Контракт: нет пути между столицами — поставка отложена"))
			continue
		k["noroute"] = 0
		k["done"] = int(k["done"]) + 1
		k["next"] = now + float(int(k["every"]))
		_count("contract_deliveries")
		gw.say2(s, b, Loc.mk("Контракт: отправлено %s %d (%d/%d) — %s", [rname(res).to_lower(), q, int(k["done"]), int(k["n"]), String(Economy.MODE_NAMES.get(mode, mode))]))
		if int(k["done"]) >= int(k["n"]):
			_end(k, "done", Loc.t("выполнен"), -1)
	if changed:
		_changed()






func aid_carrier(c: Country, t: int) -> bool:
	if c == null:
		return false
	if t == Military.MT_BALLISTIC or t == Military.MT_SAM:
		for f: Facility in gw.mil.facilities:
			if f.country_id != c.id or not gw.mil.alive(f):
				continue
			if t == Military.MT_BALLISTIC and f.kind == Facility.Kind.TEL:
				return true
			if t == Military.MT_SAM and (f.kind == Facility.Kind.AD_SAM or f.kind == Facility.Kind.AD_PATRIOT):
				return true
		return false
	return gw.mil.has_carrier(c, t)



func _sam_spent(c: Country) -> bool:
	for f: Facility in gw.mil.facilities:
		if f.country_id == c.id and gw.mil.alive(f) and (f.kind == Facility.Kind.AD_SAM or f.kind == Facility.Kind.AD_PATRIOT):
			var sp: Dictionary = Defense.SPEC.get(f.kind, {})
			if sp.has("ammo") and f.ammo < int(sp["ammo"]):
				return true
	return false







func _plan_tick() -> void :
	var dp: Diplomacy = _dp()
	var now: float = gw.game_time
	for c: Country in gw.countries:
		if c.is_player or c.eliminated or c.capital_id < 0:
			continue
		for x: Country in gw.countries:
			if x.id == c.id or x.eliminated or x.capital_id < 0 or x.at_war.is_empty() or dp.at_war(c.id, x.id):
				continue
			if not (dp.allied(c.id, x.id) or (dp.ally != null and dp.ally.same(c.id, x.id))):
				continue
			var pk: String = "%d>%d" % [c.id, x.id]
			if not plan_next.has(pk):
				plan_next[pk] = now + 60.0 + float(Hash32.h2(c.id, x.id, 331) % 120)
				continue
			if now < float(plan_next[pk]):
				continue
			var gap: float = PLAN_GAP * (1.3 - 0.5 * float(dp._p(c.id)["trade"]))
			plan_next[pk] = now + gap
			if not c.at_war.is_empty():
				var foes: float = 0.0
				for e: int in c.at_war.keys():
					foes += dp.war_power(e)
				if dp.war_power(c.id) < foes * 1.2:
					continue
			_plan_send(c, x)


func _plan_send(c: Country, x: Country) -> int:
	var dp: Diplomacy = _dp()
	var arsenal: int = 0
	for t: int in Military.MT_CAP.size():
		arsenal += c.missile_stock[t] * int(Military.MT_COST[t])
	var cap: int = int(float(c.money + arsenal + gw.mil.parked_count(c.id) * dp.aid_value("drones", 1)) * PLAN_SHARE)
	var value: int = 0
	var sent: Array = []
	if gw.mil.parked_count(c.id) >= 6 and dp.aid_value("drones", 1) <= cap:
		var dn: int = dp._move(c.id, x.id, "drones", mini(2, cap / maxi(1, dp.aid_value("drones", 1))))
		if dn > 0:
			value += dp.aid_value("drones", dn)
			sent.append(Loc.t("дроны ×%d") % dn)
	if c.missile_stock[Military.MT_BALLISTIC] > 3 and value + dp.aid_value("missile_b", 1) <= cap:
		var mb: int = dp._move(c.id, x.id, "missile_b", 1)
		if mb > 0:
			value += dp.aid_value("missile_b", mb)
			sent.append(Loc.t("баллист. ракеты ×%d") % mb)
	if c.missile_stock[Military.MT_SAM] > 4 and _sam_spent(x):
		var ms: int = mini(3, (cap - value) / maxi(1, dp.aid_value("missile_sam", 1)))
		if ms > 0:
			ms = dp._move(c.id, x.id, "missile_sam", ms)
			if ms > 0:
				value += dp.aid_value("missile_sam", ms)
				sent.append(Loc.t("ракеты ПВО ×%d") % ms)
	if value <= 0:
		return 0
	var what: String = ", ".join(PackedStringArray(sent))
	dp._note_help(c.id, x.id, value)
	dp._count("aid_packages")
	dp._count("aid_planned")
	_count("planned")
	_count("planned_value", value)
	dp.add_opinion(c.id, x.id, 1)
	dp.dlog(c.id, "плановая поставка → %s" % x.name, what, float(value))
	gw.news_m(Loc.mk("ПОСТАВКА: %s → %s (%s)", [Loc.name(dp._name(c.id)), Loc.name(dp._name(x.id)), what]), "grass_light")
	gw.say(x, Loc.mk("Плановая поставка от страны %s: %s", [Loc.name(c.name), what]))
	gw.relations_changed.emit()
	return value




func update(dt: float) -> void :
	_t += dt
	if _t >= 1.0:
		_t -= 1.0
		_sanct_tick()
		_contract_tick()
	_plan_t += dt
	if _plan_t >= PLAN_DT:
		_plan_t = 0.0
		_plan_tick()


func save_state() -> Dictionary:
	return {"sanct": sanct.duplicate(true), "contracts": contracts.duplicate(true), "next_kid": next_kid, "offer_t": offer_t.duplicate(), 
		"plan_next": plan_next.duplicate(), "stats": stats.duplicate(), "t": _t, "plan_t": _plan_t}


func load_state(d: Dictionary) -> void :
	sanct = {}
	var sd: Dictionary = d.get("sanct", {})
	for k: Variant in sd:
		var m: Dictionary = {}
		var src: Dictionary = sd[k]
		for r: Variant in src:
			var v: Array = src[r]
			m[String(r)] = [float(v[0]), float(v[1])]
		if not m.is_empty():
			sanct[String(k)] = m
	contracts = []
	for v2: Variant in (d.get("contracts", []) as Array):
		var c: Dictionary = v2
		var k2: Dictionary = {}
		for f: String in K_FIELDS:
			match f:
				"res", "state", "why":
					k2[f] = String(c.get(f, ""))
				"made", "until", "next", "end", "cq_t":
					k2[f] = float(c.get(f, -1.0))
				_:
					k2[f] = int(c.get(f, -1 if f == "cq" or f == "warned" else 0))
		contracts.append(k2)
	next_kid = int(d.get("next_kid", 1))
	offer_t = {}
	for k3: Variant in (d.get("offer_t", {}) as Dictionary):
		offer_t[String(k3)] = float(d["offer_t"][k3])
	plan_next = {}
	for k4: Variant in (d.get("plan_next", {}) as Dictionary):
		plan_next[String(k4)] = float(d["plan_next"][k4])
	stats = {}
	for k5: Variant in (d.get("stats", {}) as Dictionary):
		stats[String(k5)] = int(d["stats"][k5])
	_t = float(d.get("t", 0.0))
	_plan_t = float(d.get("plan_t", 0.0))



func hash_nums() -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var n: int = 0
	for k: String in _sorted_keys():
		out.append(float(hash(k)))
		for r: String in sanctions_by(int(k.split(">")[0]), int(k.split(">")[1])):
			out.append(float(hash(r)))
			n += 1
	out.append(float(n))
	for c: Dictionary in contracts:
		out.append(float(int(c["id"])))
		out.append(float(hash(String(c["state"]))))
		out.append(float(int(c["done"])))
	out.append(float(plan_next.size()))
	return out
