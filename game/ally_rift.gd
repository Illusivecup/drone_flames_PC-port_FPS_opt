extends RefCounted


















const HOSTILE_REL: int = -30
const HOSTILE_KEEP: int = -20
const DELAY: float = 90.0
const DELAY_WAR: float = 30.0
const CUT_LOCK: float = 600.0
const OUTWEIGH: int = 25
const SUPPORT_FLOOR: int = -25
const SUPPORT_MAX: int = 40
const SUPPORT_EDGE: int = 20
const SANCT_GAP: float = 900.0
const SANCT_REL: int = -15
const SANCT_DUR: float = 300.0
const TIE_BONUS: Dictionary = {"alliance": 15, "bloc": 10, "defense": 8}

var dp
var gw: GameWorld
var rifts: Dictionary = {}
var cut: Dictionary = {}
var sdrift: Dictionary = {}
var sanc_t: Dictionary = {}
var counters: Dictionary = {}
var lab_off: bool = false


func _init(d) -> void :
	dp = d
	gw = d.gw


func _n(k: String, v: int = 1) -> void :
	counters[k] = int(counters.get(k, 0)) + v


func _bot(id: int) -> bool:
	var c: Country = gw.country_by_id(id)
	return c != null and not c.is_player and not c.eliminated and c.capital_id >= 0






func hostile(a: int, b: int, keep: bool = false) -> String:
	if a == b or a <= 0 or b <= 0:
		return ""
	if dp.at_war(a, b):
		return Loc.t("война")
	if dp.truce_on(a, b):
		return Loc.t("перемирие")
	if gw.pstat != null and gw.pstat.is_rival(a, b):
		return Loc.t("соперники")
	var r: int = dp.relation(a, b)
	if r <= (HOSTILE_KEEP if keep else HOSTILE_REL):
		return Loc.t("отношения %d") % r
	return ""



func tie_kinds(c: int, o: int) -> Array:
	var out: Array = []
	if c == o:
		return out
	if dp.allied(c, o):
		out.append("alliance")
	if dp.ally != null and dp.ally.same(c, o):
		out.append("bloc")
	if dp.has_treaty(c, o, "defense"):
		out.append("defense")
	return out



func partners(c: int) -> Array:
	var out: Array = []
	for o: Country in gw.countries:
		if o.id == c or o.eliminated or o.capital_id < 0 or dp.subject_of(o.id) == c or dp.subject_of(c) == o.id:
			continue
		if not tie_kinds(c, o.id).is_empty():
			out.append(o.id)
	return out



func like(b: int, x: int, other: int) -> int:
	var v: int = dp.relation(b, x)
	for k: String in tie_kinds(b, x):
		v += int(TIE_BONUS[k])
	if dp.at_war(x, other) and dp._defender(x, other):
		v += 12
	if dp.care != null:
		v += roundi(15.0 * minf(1.0, float(dp.care.owed.get("%d>%d" % [b, x], 0.0)) / 2000.0))
	if gw.pstat != null and gw.pstat.is_rival(b, x):
		v -= 40
	if dp._common_enemy(b, x):
		v += 20
	return v



func outweighs(b: int, n: int, p: int) -> bool:
	return like(b, n, p) - like(b, p, n) >= OUTWEIGH



func tie_gate(b: int, n: int) -> String:
	if lab_off or not _bot(b) or b == n:
		return ""
	var nm: String = dp._cname(b)
	var ck: String = "%d>%d" % [b, n]
	if cut.has(ck):
		var e: Dictionary = cut[ck]
		var wv: int = int(e["w"])
		if float(e["end"]) < 0.0 and dp._alive(wv):
			return Loc.t("%s выбрала сторону страны %s — сначала помиритесь с ней") % [nm, dp._cname(wv)]
		var left: float = float(e["end"]) + CUT_LOCK - gw.game_time
		if left > 0.0:
			return Loc.t("%s недавно разорвала с вами связи — ещё %d:%02d") % [nm, int(left) / 60, int(left) % 60]
	for p: int in partners(b):
		if p == n:
			continue
		var hz: String = hostile(n, p)
		if hz == "":
			continue
		if outweighs(b, n, p):
			continue
		return Loc.t("%s: её союзник %s враждует с вами (%s) — сначала помиритесь со страной %s") % [nm, dp._cname(p), hz, dp._cname(p)]
	return ""




func tie_need(b: int, n: int) -> Array:
	if lab_off or not _bot(b):
		return [0, -1]
	var best: int = 0
	var who: int = -1
	for p: int in partners(b):
		if p == n:
			continue
		var r: int = dp.relation(n, p)
		if r < 0 and r > HOSTILE_REL:
			var ex: int = ceili(float( - r) / 2.0)
			if ex > best:
				best = ex
				who = p
	return [best, who]



func deciding(b: int, a: int, c: int) -> float:
	var k: String = "%d:%d:%d" % [b, mini(a, c), maxi(a, c)]
	if not rifts.has(k) or float(rifts[k]) < 0.0:
		return -1.0
	return maxf(0.0, float(rifts[k]) + _delay(a, c) - gw.game_time)



func rel_eff(b: int, e: int) -> int:
	return dp.relation(b, e) - int(sdrift.get("%d>%d" % [b, e], 0)) - int(sdrift.get("%d>%d" % [e, b], 0))



func note_for(me: int, other: int) -> String:
	if lab_off or not _bot(other):
		return ""
	var ck: String = "%d>%d" % [other, me]
	if cut.has(ck):
		var g: String = tie_gate(other, me)
		if g != "":
			return Loc.t("Разрыв: %s") % g
	for k: String in rifts.keys():
		var ab: PackedStringArray = k.split(":")
		if int(ab[0]) != other or float(rifts[k]) < 0.0:
			continue
		var p: int = int(ab[1])
		var q: int = int(ab[2])
		if p != me and q != me:
			continue
		var o2: int = q if p == me else p
		return Loc.t("%s выбирает сторону: вы или %s (%s) — решит в ближайшие %d с") % [dp._cname(other), dp._cname(o2), hostile(me, o2, true), int(_delay(p, q))]
	if partners(other).has(me):
		return ""
	var g2: String = tie_gate(other, me)
	return g2




func _delay(a: int, c: int) -> float:
	return DELAY_WAR if dp.at_war(a, c) or dp.truce_on(a, c) else DELAY


func tick() -> void :
	if lab_off:
		return
	var now: float = gw.game_time
	var live: Dictionary = {}
	var backed: Dictionary = {}
	for bc: Country in gw.countries:
		var b: int = bc.id
		if not _bot(b) or dp.is_subject(b):
			continue
		var ps: Array = partners(b)
		var acted: bool = false
		for i in ps.size():
			for j in range(i + 1, ps.size()):
				var p: int = mini(int(ps[i]), int(ps[j]))
				var q: int = maxi(int(ps[i]), int(ps[j]))
				var k: String = "%d:%d:%d" % [b, p, q]
				var hz: String = hostile(p, q, rifts.has(k))
				if hz == "":
					continue
				live[k] = true
				if not rifts.has(k):
					rifts[k] = now
					_open(b, p, q, hz)
				elif float(rifts[k]) < 0.0 and not (dp.ally != null and dp.ally.same(b, p) and dp.ally.same(b, q)):
					rifts[k] = now
				elif not acted and float(rifts[k]) >= 0.0 and now - float(rifts[k]) >= _delay(p, q):
					acted = true
					_resolve(b, p, q, hz)
		_back(b, partners(b), now, backed)
	for k2: String in rifts.keys():
		if not live.has(k2):
			rifts.erase(k2)
			_n("rift_closed")
	for ck: String in cut.keys():
		var e: Dictionary = cut[ck]
		var ab: PackedStringArray = ck.split(">")
		if not dp._alive(int(ab[0])) or not dp._alive(int(ab[1])):
			cut.erase(ck)
			continue
		if float(e["end"]) < 0.0 and ( not dp._alive(int(e["w"])) or hostile(int(ab[1]), int(e["w"]), true) == ""):
			e["end"] = now
		elif float(e["end"]) >= 0.0 and now - float(e["end"]) > CUT_LOCK:
			cut.erase(ck)
	for sk: String in sdrift.keys():
		if backed.has(sk):
			continue
		var sb: PackedStringArray = sk.split(">")
		var b2: int = int(sb[0])
		var e2: int = int(sb[1])
		if not dp._alive(b2) or not dp._alive(e2) or dp.at_war(b2, e2):
			sdrift.erase(sk)
			continue
		if Hash32.h2(b2 * 64 + e2, dp._tick_n, 3321) % 2 == 0:
			dp.add_opinion(b2, e2, 1)
			sdrift[sk] = int(sdrift[sk]) + 1
			if int(sdrift[sk]) >= 0:
				sdrift.erase(sk)



func _open(b: int, p: int, q: int, hz: String) -> void :
	_n("rift_open")
	var t: int = int(_delay(p, q))
	dp.dlog(b, "между %s и %s" % [dp._cname(p), dp._cname(q)], "партнёры враждуют: %s" % hz, 0.0, ["rift", p, q])
	for pr: Array in [[p, q], [q, p]]:
		var me: Country = gw.country_by_id(int(pr[0]))
		if me != null and me.is_player:
			gw.say(me, Loc.mk("%s колеблется: вы и %s враждуете (%s) — через %d с она выберет одну сторону", [Loc.name(dp._cname(b)), Loc.name(dp._cname(int(pr[1]))), hz, t]))



func _resolve(b: int, p: int, q: int, hz: String) -> void :
	var sp: int = like(b, p, q)
	var sq: int = like(b, q, p)
	var w: int = p
	if sq > sp or (sq == sp and Hash32.h2(b, p * 64 + q, 6113) % 2 == 1):
		w = q
	var l: int = q if w == p else p
	var parted: bool = false
	if dp.allied(b, l):
		dp._set_rel(b, l, Diplomacy.Rel.PEACE)
		dp.close_land(b, l)
		parted = true
	if dp.has_treaty(b, l, "defense"):
		var t: Dictionary = dp.treaties.get(Diplomacy.key(b, l), {})
		t.erase("defense")
		if t.is_empty():
			dp.treaties.erase(Diplomacy.key(b, l))
		parted = true
	if dp.ally != null and dp.ally.same(b, l):
		if dp.ally.same(b, w):
			pass
		else:
			dp.ally.leave(b, Loc.t("не будет в одном альянсе с врагом страны %s") % dp._cname(w))
			parted = true
	var k: String = "%d:%d:%d" % [b, p, q]
	if not parted:
		rifts[k] = -1.0
		_n("rift_stuck")
		return
	rifts.erase(k)
	dp.add_opinion(b, l, -15)
	cut["%d>%d" % [b, l]] = {"t": gw.game_time, "w": w, "why": hz, "end": -1.0}
	_n("rift_cut")
	if gw.country_by_id(l) != null and gw.country_by_id(l).is_player:
		_n("rift_cut_human")
	dp.dlog(b, "выбирает %s, разрыв с %s" % [dp._cname(w), dp._cname(l)], "%s (%d против %d)" % [hz, maxi(sp, sq), mini(sp, sq)], float(maxi(sp, sq) - mini(sp, sq)), ["rift_cut", w, l])
	gw.news_m(Loc.mk("%s ВЫБИРАЕТ СТОРОНУ СТРАНЫ %s: РАЗРЫВ СО СТРАНОЙ %s (%s)", [Loc.name(dp._name(b)), Loc.name(dp._name(w)), Loc.name(dp._name(l)), hz.to_upper()]), "amber")
	gw.say(l, Loc.mk("%s разрывает связи с вами: вы враждуете со страной %s (%s). Помиритесь с ней — и %s вернётся к разговору", [Loc.name(dp._cname(b)), Loc.name(dp._cname(w)), hz, Loc.name(dp._cname(b))]))
	gw.say(w, Loc.mk("%s на вашей стороне: связи со страной %s разорваны", [Loc.name(dp._cname(b)), Loc.name(dp._cname(l))]))
	dp.pending_changed.emit()
	gw.relations_changed.emit()

	if dp.at_war(w, l) and dp._defender(w, l) and dp._obligation(b, w, l) != "" and dp._join_block(b, l) == ""\
	and dp.war_block(b, l).is_empty() and not dp._losing_badly(b) and dp.pile_gate(b, l, w, false) == "":
		_n("rift_defend")
		dp._join_war(b, l, w, Loc.t("ОБОРОНА СОЮЗНИКА"))



func _back(b: int, ps: Array, now: float, backed: Dictionary) -> void :
	if ps.is_empty():
		return
	var did_s: bool = false
	for x: int in ps:
		for ec: Country in gw.countries:
			var e: int = ec.id
			if e == b or e == x or ec.eliminated or ec.capital_id < 0 or ps.has(e) or dp.at_war(b, e) or dp.subject_of(e) == b or dp.subject_of(b) == e:
				continue
			var war: bool = dp.at_war(x, e) or dp.truce_on(x, e)
			var rxe: int = dp.relation(x, e)
			if not (war or rxe <= HOSTILE_REL or (gw.pstat != null and gw.pstat.is_rival(x, e) and rxe < 0)):
				continue
			if dp.relation(b, x) < rel_eff(b, e) + SUPPORT_EDGE:
				continue
			var sk: String = "%d>%d" % [b, e]
			backed[sk] = true
			if dp.relation(b, e) > SUPPORT_FLOOR and int(sdrift.get(sk, 0)) > - SUPPORT_MAX:
				dp.add_opinion(b, e, -1)
				sdrift[sk] = int(sdrift.get(sk, 0)) - 1
				_n("back_drift")
			if did_s or dp.relation(b, e) > SANCT_REL or now < float(sanc_t.get(b, -1000000000.0)) + SANCT_GAP:
				continue
			if not war and rxe > -40:
				continue
			var trd: Variant = gw.econ.get("trd") if gw.econ != null else null
			if trd == null or not (trd.sanctions_by(b, e) as Array).is_empty() or String(trd.can_sanction(b, e, "", true)) != "":
				continue
			var by: Dictionary = {}
			for s0: Dictionary in (trd.sanctions_on(e) as Array):
				by[int(s0["by"])] = true
			if by.size() >= 2:
				continue
			if Hash32.h2(b, e * 64 + x, int(now / 60.0)) % 100 >= 30:
				continue
			if String(trd.impose_sanction(b, e, "", SANCT_DUR)) == "":
				did_s = true
				sanc_t[b] = now
				_n("back_sanction")
				dp.dlog(b, "санкции против %s" % dp._cname(e), "в поддержку %s" % dp._cname(x), 0.0, ["back_sanct", x, e])
				gw.news_m(Loc.mk("%s В ПОДДЕРЖКУ СТРАНЫ %s ВВОДИТ САНКЦИИ ПРОТИВ %s", [Loc.name(dp._name(b)), Loc.name(dp._name(x)), Loc.name(dp._name(e))]), "amber")
				gw.say(x, Loc.mk("%s в поддержку вас ввела санкции против страны %s", [Loc.name(dp._cname(b)), Loc.name(dp._cname(e))]))



func forget(id: int) -> void :
	for k: String in rifts.keys():
		var ab: PackedStringArray = k.split(":")
		if int(ab[0]) == id or int(ab[1]) == id or int(ab[2]) == id:
			rifts.erase(k)
	for ck: String in cut.keys():
		var cb: PackedStringArray = ck.split(">")
		if int(cb[0]) == id or int(cb[1]) == id or int((cut[ck] as Dictionary)["w"]) == id:
			cut.erase(ck)
	for sk: String in sdrift.keys():
		var sb: PackedStringArray = sk.split(">")
		if int(sb[0]) == id or int(sb[1]) == id:
			sdrift.erase(sk)
	sanc_t.erase(id)




func save_state() -> Dictionary:
	return {"rifts": rifts.duplicate(), "cut": cut.duplicate(true), "sdrift": sdrift.duplicate(), "sanc_t": sanc_t.duplicate(), "counters": counters.duplicate()}


func load_state(d: Dictionary) -> void :
	rifts = {}
	for k: Variant in (d.get("rifts", {}) as Dictionary):
		rifts[String(k)] = float(d["rifts"][k])
	cut = {}
	for k2: Variant in (d.get("cut", {}) as Dictionary):
		var e: Dictionary = d["cut"][k2]
		cut[String(k2)] = {"t": float(e.get("t", 0.0)), "w": int(e.get("w", -1)), "why": String(e.get("why", "")), "end": float(e.get("end", -1.0))}
	sdrift = {}
	for k3: Variant in (d.get("sdrift", {}) as Dictionary):
		sdrift[String(k3)] = int(d["sdrift"][k3])
	sanc_t = {}
	for k4: Variant in (d.get("sanc_t", {}) as Dictionary):
		sanc_t[int(k4)] = float(d["sanc_t"][k4])
	counters = d.get("counters", {})


func hash_nums() -> PackedFloat64Array:
	var out: = PackedFloat64Array()
	out.append(float(rifts.size()))
	out.append(float(cut.size()))
	var s: int = 0
	for k: String in sdrift:
		s += int(sdrift[k])
	out.append(float(s))
	return out
