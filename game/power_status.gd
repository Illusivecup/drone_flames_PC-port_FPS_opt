class_name PowerStatus
extends RefCounted

















signal status_changed(ev: Dictionary)
signal rival_changed(cid: int, rival: int)

enum {ST_NONE, ST_WEAK, ST_PARIAH, ST_FAIL, ST_VASSAL, ST_PUPPET}
enum {EP_NONE = -1, EP_MIL, EP_IND, EP_TRADE, EP_SEA, EP_MSL}

const TIER_NAMES: Array = ["МОЛОДАЯ РЕСПУБЛИКА", "РЕСПУБЛИКА", "РЕГИОНАЛЬНАЯ СИЛА", "ДЕРЖАВА", "ВЕЛИКАЯ ДЕРЖАВА", "СВЕРХДЕРЖАВА"]

const TIER_INS: Array = ["МОЛОДОЙ РЕСПУБЛИКОЙ", "РЕСПУБЛИКОЙ", "РЕГИОНАЛЬНОЙ СИЛОЙ", "ДЕРЖАВОЙ", "ВЕЛИКОЙ ДЕРЖАВОЙ", "СВЕРХДЕРЖАВОЙ"]

const TIER_PRE: Array = ["МОЛОДАЯ", "", "РЕГИОНАЛЬНАЯ", "", "ВЕЛИКАЯ", ""]
const TIER_NOUN: Array = ["РЕСПУБЛИКА", "РЕСПУБЛИКА", "СИЛА", "ДЕРЖАВА", "ДЕРЖАВА", "СВЕРХДЕРЖАВА"]
const TIER_SHORT: Array = ["МОЛ. РЕСПУБЛИКА", "РЕСПУБЛИКА", "РЕГ. СИЛА", "ДЕРЖАВА", "ВЕЛ. ДЕРЖАВА", "СВЕРХДЕРЖАВА"]
const EPI_NAMES: Array = ["ВОЕННАЯ", "ПРОМЫШЛЕННАЯ", "ТОРГОВАЯ", "МОРСКАЯ", "РАКЕТНАЯ"]
const STATE_NAMES: Array = ["", "ОСЛАБЛЕННАЯ", "ИЗГОЙ", "РАСПАДАЮЩАЯСЯ", "ВАССАЛ", "МАРИОНЕТКА"]
const STATE_INS: Array = ["", "ОСЛАБЛЕННОЙ", "ИЗГОЕМ", "РАСПАДАЮЩЕЙСЯ", "ВАССАЛОМ", "МАРИОНЕТКОЙ"]
const STATE_ICONS: Array = ["", "icon_st_weak", "icon_st_pariah", "icon_st_fail", "icon_st_vassal", "icon_st_puppet"]
const TIER_ICONS: Array = ["icon_tier0", "icon_tier1", "icon_tier2", "icon_tier3", "icon_tier4", "icon_tier5"]
const EPI_ICONS: Array = ["icon_ep_mil", "icon_ep_ind", "icon_ep_trade", "icon_ep_sea", "icon_ep_msl"]

const EVAL_DT: float = 30.0

const TIER_UP: Array = [0.0, 0.25, 0.55, 0.95, 1.45, 1.95]
const DOWN_MUL: float = 0.78
const UP_HOLD: int = 2
const DOWN_HOLD: int = 4
const MIN_DWELL: float = 150.0

const TOP5_MAX: int = 2
const TOP4_MAX: int = 3
const TOP5_SECOND: float = 1.3

const D_CITY: float = 16.0
const D_INC: float = 5000.0
const D_MIL: float = 60.0
const D_CAP: float = 1.5

const W_INC: float = 0.3
const W_IND: float = 0.15
const W_LAND: float = 0.2
const W_MIL: float = 0.35
const R_CAP: float = 3.0
const INC_EMA: float = 0.35



const EPI_MIN: float = 1.35
const EPI_LEAD: float = 1.15
const EPI_KEEP: float = 1.0
const EPI_KEEPR: float = 0.75
const EPI_HOLD: int = 4
const EPI_DWELL: float = 420.0
const EPI_SEA: float = 6.0
const EPI_MSL: float = 12.0

const WEAK_LOSS: float = 0.34
const FAIL_LOSS: float = 0.6
const WEAK_MEM: float = 600.0
const PARIAH_N: int = 3
const PARIAH_SHARE: float = 0.5
const STATE_HOLD: int = 2
const STATE_DWELL: float = 240.0

const RIVAL_FIRST: float = 180.0
const RIVAL_EVERY: float = 900.0
const RIVAL_SWITCH: float = 1.5
const RIVAL_CAP: int = 10
const RIVAL_FLOOR: int = -15

const MT_W: Array = [3.0, 1.5, 0.5, 0.5, 5.0, 0.3]
const IND_KINDS: Array = [Facility.Kind.DRONE_FACTORY, Facility.Kind.MISSILE_FACTORY, Facility.Kind.CIV_FACTORY, Facility.Kind.REFINERY, 
	Facility.Kind.POWER_PLANT, Facility.Kind.AD_MFG, Facility.Kind.SOLAR_FARM, Facility.Kind.NUCLEAR_PLANT]
const AD_KINDS: Array = [Facility.Kind.AD_SPAAG, Facility.Kind.AD_SAM, Facility.Kind.AD_PATRIOT, Facility.Kind.AD_INT, Facility.Kind.AD_RADAR, Facility.Kind.AD_EW]

var gw: GameWorld


var tier: Dictionary = {}
var epi: Dictionary = {}
var state: Dictionary = {}
var pts: Dictionary = {}
var rel: Dictionary = {}
var stand: Dictionary = {}
var rank: Dictionary = {}
var hold: Dictionary = {}
var since: Dictionary = {}
var s_since: Dictionary = {}
var e_since: Dictionary = {}
var earned0: Dictionary = {}
var trade0: Dictionary = {}
var inc: Dictionary = {}
var trd: Dictionary = {}
var peak: Dictionary = {}
var rival: Dictionary = {}
var rival2: Dictionary = {}
var rival_t: float = 0.0
var next_t: float = 0.0
var evals: int = 0
var history: Array = []
var counters: Dictionary = {}
static var bias_on: bool = true
var last_m: Dictionary = {}


func _init(world: GameWorld) -> void :
	gw = world




func _id(c: Variant) -> int:
	if c == null:
		return -1
	return (c as Country).id if c is Country else int(c)



func status_of(c: Variant) -> int:
	return int(tier.get(_id(c), 0))


static func status_name(t: int) -> String:
	return String(TIER_NAMES[clampi(t, 0, TIER_NAMES.size() - 1)])



func epithet_of(c: Variant) -> int:
	return int(epi.get(_id(c), EP_NONE))


static func epithet_name(e: int) -> String:
	return String(EPI_NAMES[e]) if e >= 0 and e < EPI_NAMES.size() else ""



func state_of(c: Variant) -> int:
	return int(state.get(_id(c), ST_NONE))


static func state_name(s: int) -> String:
	return String(STATE_NAMES[s]) if s > 0 and s < STATE_NAMES.size() else ""



func label(c: Variant) -> String:
	return String(label_parts(c)["full"])





func label_parts(c: Variant) -> Dictionary:
	var t: int = status_of(c)
	var e: int = epithet_of(c)
	var s: int = state_of(c)
	var words: PackedStringArray = PackedStringArray()
	if String(TIER_PRE[t]) != "":
		words.append(String(TIER_PRE[t]))
	if e >= 0:
		words.append(epithet_name(e))
	words.append(String(TIER_NOUN[t]))
	var title: String = " ".join(words)
	return {"tier": t, "tier_name": status_name(t), "short": status_name(t), "abbr": String(TIER_SHORT[t]), 
		"tier_icon": String(TIER_ICONS[t]), "epithet": e, "epithet_name": epithet_name(e), "epithet_icon": String(EPI_ICONS[e]) if e >= 0 else "", 
		"state": s, "state_name": state_name(s), "state_icon": String(STATE_ICONS[s]), "title": title, 
		"full": title + (" · " + state_name(s) if s != ST_NONE else ""), "rank": int(rank.get(_id(c), 0)), "score": score(c), "standing": standing(c)}



func points(c: Variant) -> float:
	return float(pts.get(_id(c), 0.0))



func score(c: Variant) -> float:
	return float(rel.get(_id(c), 1.0))




func standing(c: Variant) -> float:
	return float(stand.get(_id(c), 0.5))



func rank_of(c: Variant) -> int:
	return int(rank.get(_id(c), 0))



func rival_of(c: Variant) -> int:
	return int(rival.get(_id(c), -1))



func rivals_of(c: Variant) -> Array:
	var out: Array = []
	var id: int = _id(c)
	if rival.has(id):
		out.append(int(rival[id]))
	if rival2.has(id):
		out.append(int(rival2[id]))
	return out



func is_rival(a: Variant, b: Variant) -> bool:
	var ia: int = _id(a)
	var ib: int = _id(b)
	return int(rival.get(ia, -1)) == ib or int(rival.get(ib, -1)) == ia or int(rival2.get(ia, -1)) == ib or int(rival2.get(ib, -1)) == ia




func rival_bias(a: int, b: int, op: int, v: int, h: int) -> int:
	if not bias_on or not is_rival(a, b):
		return v
	if op > RIVAL_CAP:
		return mini(v - 1, -3)
	if op >= 0:
		return mini(v - 1, -1)
	if op > RIVAL_FLOOR:
		return mini(v, 0) - (1 if h == 1 or h == 4 else 0)
	return v



func rival_clamp(a: int, b: int, op: int, v: int) -> int:
	if v <= 0 or not bias_on or not is_rival(a, b):
		return v
	return clampi(RIVAL_CAP - op, 0, v)



func change_text(ev: Dictionary, own: bool) -> String:
	var c: Country = gw.country_by_id(int(ev["cid"]))


	var who: String = "Ваша страна" if own else (c.name if c != null else "?")
	var s: int = int(ev["state"])
	var os: int = int(ev["old_state"])
	if s != os and s != ST_NONE:
		return Loc.msg(Loc.mk("%s стала %s", [who, String(STATE_INS[s])]))
	if s != os and s == ST_NONE:
		match os:
			ST_PARIAH:
				return Loc.msg(Loc.mk("%s больше не изгой", [who]))
			ST_VASSAL, ST_PUPPET:
				return Loc.msg(Loc.mk("%s снова независима", [who]))
		return Loc.msg(Loc.mk("%s оправилась от кризиса", [who]))
	if int(ev["tier"]) > int(ev["old_tier"]):
		return Loc.msg(Loc.mk("%s стала %s", [who, String(TIER_INS[int(ev["tier"])])]))
	return Loc.t("%s теряет статус: снова %s") % [Loc.tx(who), status_name(int(ev["tier"]))]




func update(_dt: float) -> void :
	if gw.game_time < next_t:
		return
	var cold: bool = evals == 0 and gw.game_time > 60.0
	next_t = maxf(next_t + EVAL_DT, gw.game_time + 1.0)
	evals += 1
	_evaluate(cold)
	if gw.game_time >= RIVAL_FIRST:
		_rival_tick()


func _alive_list() -> Array[Country]:
	var out: Array[Country] = []
	for c: Country in gw.countries:
		if not c.eliminated and c.capital_id >= 0:
			out.append(c)
	return out



func measure(alive: Array[Country], dt: float) -> Dictionary:
	var ms: Dictionary = {}
	for c: Country in alive:
		var cp: float = 0.0
		var caps: int = 0
		for cid: int in c.city_ids:
			var ct: City = gw.cities[cid]
			cp += (3.0 if ct.kind == City.Kind.CAPITAL else (2.0 if ct.kind == City.Kind.TOWN else 1.0)) + 0.5 * float(maxi(0, ct.level - 1))
			if ct.kind == City.Kind.CAPITAL:
				caps += 1
		var msl: float = 0.0
		for t in mini(c.missile_stock.size(), MT_W.size()):
			msl += float(c.missile_stock[t]) * float(MT_W[t])
		var e0: int = int(earned0.get(c.id, -1))
		var t0: int = int(trade0.get(c.id, -1))
		var mins: float = maxf(dt, 1.0) / 60.0
		var ir: float = (float(c.earned - e0) / mins) if e0 >= 0 else float(c.earned) / maxf(1.0, gw.game_time / 60.0)
		var tr: float = (float(c.trade_income - t0) / mins) if t0 >= 0 else float(c.trade_income) / maxf(1.0, gw.game_time / 60.0)
		ms[c.id] = {"cp": cp, "cities": c.city_ids.size(), "caps": caps, "cells": 0, "ir": maxf(0.0, ir), "tr": maxf(0.0, tr), 
			"ind": 0.0, "army": gw.army.count_units(c.id), "air": 0, "sea": 0.0, "msl": msl, "ad": 0, "tel": 0}
	for f: Facility in gw.mil.facilities:
		if not ms.has(f.country_id) or not gw.mil.alive(f):
			continue
		var d: Dictionary = ms[f.country_id]
		if Economy.is_enterprise(f.kind) or IND_KINDS.has(f.kind):
			d["ind"] = float(d["ind"]) + 1.0 + 0.5 * float(maxi(0, f.level - 1))
		elif AD_KINDS.has(f.kind):
			d["ad"] = int(d["ad"]) + 1
		elif f.kind == Facility.Kind.TEL:
			d["tel"] = int(d["tel"]) + 1
			d["msl"] = float(d["msl"]) + 2.0 + float(f.missiles) * float(MT_W[0])
		elif f.kind == Facility.Kind.COASTAL_ASM:
			d["sea"] = float(d["sea"]) + 1.0
	for a: Aircraft in gw.mil.air.aircraft:
		if ms.has(a.country_id) and a.state != Aircraft.State.DEAD:
			ms[a.country_id]["air"] = int(ms[a.country_id]["air"]) + 1
	if gw.navy != null:
		for s: Ship in gw.navy.ships:
			if ms.has(s.c) and s.alive():
				ms[s.c]["sea"] = float(ms[s.c]["sea"]) + 1.0 + float(s.hull)
	var own: PackedByteArray = gw.data.owners
	for c: Country in alive:
		var d2: Dictionary = ms[c.id]
		d2["cells"] = own.count(c.id)
		d2["lf"] = float(d2["army"]) + 1.5 * float(d2["ad"])
		d2["mil"] = float(d2["lf"]) + 4.0 * float(d2["air"]) + 5.0 * float(d2["sea"]) + float(d2["msl"])
	return ms


func _evaluate(cold: bool) -> void :
	var alive: Array[Country] = _alive_list()
	if alive.is_empty():
		return
	var ms: Dictionary = measure(alive, EVAL_DT)
	for c: Country in alive:
		var d: Dictionary = ms[c.id]
		var i0: float = float(d["ir"])
		inc[c.id] = i0 if not inc.has(c.id) else float(inc[c.id]) + (i0 - float(inc[c.id])) * INC_EMA
		trd[c.id] = float(d["tr"]) if not trd.has(c.id) else float(trd[c.id]) + (float(d["tr"]) - float(trd[c.id])) * INC_EMA
		d["inc"] = float(inc[c.id])
		d["trd"] = float(trd[c.id])
		earned0[c.id] = c.earned
		trade0[c.id] = c.trade_income

	var mean: Dictionary = {"inc": 0.0, "ind": 0.0, "cells": 0.0, "cp": 0.0, "mil": 0.0, "trd": 0.0, "sea": 0.0, "msl": 0.0, "lf": 0.0}
	for c: Country in alive:
		for k: String in mean:
			mean[k] = float(mean[k]) + float(ms[c.id][k])
	var n: float = float(alive.size())
	const FLOOR: Dictionary = {"inc": 100.0, "ind": 2.0, "cells": 500.0, "cp": 3.0, "mil": 5.0, "trd": 30.0, "sea": 2.0, "msl": 4.0, "lf": 5.0}
	for k2: String in mean:
		mean[k2] = maxf(float(mean[k2]) / n, float(FLOOR[k2]))
	var order: Array = []
	for c: Country in alive:
		var d: Dictionary = ms[c.id]
		var r_inc: float = minf(float(d["inc"]) / float(mean["inc"]), R_CAP)
		var r_ind: float = minf(float(d["ind"]) / float(mean["ind"]), R_CAP)
		var r_land: float = minf(0.5 * float(d["cells"]) / float(mean["cells"]) + 0.5 * float(d["cp"]) / float(mean["cp"]), R_CAP)
		var r_mil: float = minf(float(d["mil"]) / float(mean["mil"]), R_CAP)
		var sc: float = W_INC * r_inc + W_IND * r_ind + W_LAND * r_land + W_MIL * r_mil
		var dev: float = (minf(float(d["cp"]) / D_CITY, D_CAP) + minf(float(d["inc"]) / D_INC, D_CAP) + minf(float(d["mil"]) / D_MIL, D_CAP)) / 3.0
		d["r_inc"] = r_inc
		d["r_ind"] = r_ind
		d["r_land"] = r_land
		d["r_mil"] = r_mil
		d["r_trd"] = minf(float(d["trd"]) / float(mean["trd"]), R_CAP)
		d["r_sea"] = minf(float(d["sea"]) / float(mean["sea"]), R_CAP)
		d["r_msl"] = minf(float(d["msl"]) / float(mean["msl"]), R_CAP)
		d["r_lf"] = minf(float(d["lf"]) / float(mean["lf"]), R_CAP)
		d["dev"] = dev
		d["sc"] = sc
		var p: float = dev * sc
		d["pts"] = p
		rel[c.id] = sc
		pts[c.id] = p
		order.append([p, - c.id])
	order.sort()
	order.reverse()
	for i in order.size():
		rank[ - int(order[i][1])] = i + 1
	last_m = ms


	var n5: int = 0
	var n4: int = 0
	if not cold:
		for o0: Array in order:
			var tt: int = int(tier.get( - int(o0[1]), 0))
			n5 += 1 if tt >= 5 else 0
			n4 += 1 if tt >= 4 else 0
	for o: Array in order:
		var cid: int = - int(o[1])
		var c: Country = gw.country_by_id(cid)
		var p: float = float(o[0])
		var t0: int = int(tier.get(cid, 0))
		var want: int = 0
		for t in range(TIER_UP.size() - 1, 0, -1):
			if p >= float(TIER_UP[t]):
				want = t
				break
		var st: int = _state_now(c, ms[cid])
		var cap: int = 2 if st == ST_VASSAL or st == ST_PUPPET else 5
		want = mini(want, cap)
		var hd: Array = hold.get(cid, [0, 0, EP_NONE, 0, ST_NONE, 0])
		var nt: int = t0
		if cold:
			nt = want
			if nt >= 5 and (n5 >= TOP5_MAX or (n5 >= 1 and p < float(TIER_UP[5]) * TOP5_SECOND)):
				nt = 4
			if nt >= 4 and n4 >= TOP4_MAX:
				nt = 3
		elif want > t0:
			hd[0] = int(hd[0]) + 1
			hd[1] = 0
			var full: bool = (t0 + 1 == 5 and n5 >= TOP5_MAX) or (t0 + 1 == 4 and n4 >= TOP4_MAX)
			if t0 + 1 == 5 and n5 >= 1 and p < float(TIER_UP[5]) * TOP5_SECOND:
				full = true
			if int(hd[0]) >= UP_HOLD and gw.game_time - float(since.get(cid, -999.0)) >= MIN_DWELL and not full:
				nt = t0 + 1
		else:
			hd[0] = 0
			var down: bool = t0 > cap or p < float(TIER_UP[t0]) * DOWN_MUL
			hd[1] = int(hd[1]) + 1 if down else 0
			if t0 > cap or (down and int(hd[1]) >= DOWN_HOLD and gw.game_time - float(since.get(cid, -999.0)) >= MIN_DWELL):
				nt = t0 - 1
		if cold:
			n5 += 1 if nt >= 5 else 0
			n4 += 1 if nt >= 4 else 0
		else:
			n5 += (1 if nt >= 5 else 0) - (1 if t0 >= 5 else 0)
			n4 += (1 if nt >= 4 else 0) - (1 if t0 >= 4 else 0)

		var e_old: int = int(epi.get(cid, EP_NONE))
		var e_want: int = _epithet_now(ms[cid], e_old, gw.game_time - float(e_since.get(cid, -999.0)) < EPI_DWELL) if nt >= 1 else EP_NONE
		var e_new: int = e_old
		if cold or e_want == e_old:
			e_new = e_want
			hd[3] = 0
		else:
			if int(hd[2]) == e_want:
				hd[3] = int(hd[3]) + 1
			else:
				hd[2] = e_want
				hd[3] = 1
			if int(hd[3]) >= EPI_HOLD:
				e_new = e_want
				hd[3] = 0
				e_since[cid] = gw.game_time

		var s_old: int = int(state.get(cid, ST_NONE))
		var s_new: int = s_old
		if cold or st == s_old or st == ST_VASSAL or st == ST_PUPPET or s_old == ST_VASSAL or s_old == ST_PUPPET:
			s_new = st
			hd[5] = 0
		else:
			if int(hd[4]) == st:
				hd[5] = int(hd[5]) + 1
			else:
				hd[4] = st
				hd[5] = 1
			var calm: bool = s_old == ST_NONE or gw.game_time - float(s_since.get(cid, -999.0)) >= STATE_DWELL
			if int(hd[5]) >= STATE_HOLD and (calm or st > s_old):
				s_new = st
				hd[5] = 0
		hold[cid] = hd
		var changed_t: bool = nt != t0
		var changed_s: bool = s_new != s_old
		tier[cid] = nt
		state[cid] = s_new
		if e_new == EP_NONE:
			epi.erase(cid)
		else:
			epi[cid] = e_new
		if changed_t:
			since[cid] = gw.game_time
		if changed_s:
			s_since[cid] = gw.game_time
		if (changed_t or changed_s) and not cold:
			_announce(c, t0, nt, s_old, s_new, e_new)

	for o2: Array in order:
		var cid2: int = - int(o2[1])
		var rk: float = 1.0 - float(int(rank[cid2]) - 1) / maxf(1.0, n - 1.0)
		var sv: float = 0.55 * float(int(tier.get(cid2, 0))) / 5.0 + 0.45 * rk
		match int(state.get(cid2, ST_NONE)):
			ST_WEAK:
				sv -= 0.1
			ST_FAIL, ST_PARIAH:
				sv -= 0.25
			ST_VASSAL:
				sv -= 0.15
			ST_PUPPET:
				sv -= 0.3
		stand[cid2] = clampf(sv, 0.0, 1.0)

	for c3: Country in gw.countries:
		if c3.eliminated and (tier.has(c3.id) or rival.has(c3.id)):
			tier.erase(c3.id)
			epi.erase(c3.id)
			state.erase(c3.id)
			stand.erase(c3.id)
			rank.erase(c3.id)
			rival.erase(c3.id)
			rival2.erase(c3.id)




func forget(id: int) -> void :
	for dct: Dictionary in [tier, epi, state, stand, rank, rival, rival2, peak, hold, since, s_since, e_since, inc, trd, pts, rel]:
		dct.erase(id)
	for o: Variant in rival.keys():
		if int(rival[o]) == id:
			rival.erase(o)
	for o2: Variant in rival2.keys():
		if int(rival2[o2]) == id:
			rival2.erase(o2)



func _profile(d: Dictionary) -> Array:
	return [float(d["r_lf"]), float(d["r_ind"]), float(d["r_trd"]), float(d["r_sea"]) if float(d["sea"]) >= EPI_SEA else 0.0, 
		float(d["r_msl"]) if float(d["msl"]) >= EPI_MSL else 0.0]




func _epithet_now(d: Dictionary, cur: int, fresh: bool) -> int:
	var sh: Array = _profile(d)
	var best: int = EP_NONE
	var bv: float = 0.0
	var second: float = 0.0
	for i in sh.size():
		var v: float = float(sh[i])
		if v > bv:
			second = bv
			bv = v
			best = i
		elif v > second:
			second = v
	var want: int = best if best >= 0 and bv >= EPI_MIN and bv >= second * EPI_LEAD else EP_NONE
	if cur >= 0 and float(sh[cur]) >= EPI_KEEP and (fresh or float(sh[cur]) >= EPI_KEEPR * bv):
		return cur
	return want


func _state_now(c: Country, d: Dictionary) -> int:
	var dp: Diplomacy = gw.diplo
	match dp.subject_kind(c.id):
		"puppet":
			return ST_PUPPET
		"vassal":
			return ST_VASSAL

	var cp: float = float(d["cp"])
	var mv: float = float(d["mil"])
	var pk: Array = peak.get(c.id, [cp, mv, gw.game_time])
	if cp >= float(pk[0]) or mv >= float(pk[1]) or gw.game_time - float(pk[2]) > WEAK_MEM:
		pk = [maxf(cp, float(pk[0]) if gw.game_time - float(pk[2]) <= WEAK_MEM else cp), maxf(mv, float(pk[1]) if gw.game_time - float(pk[2]) <= WEAK_MEM else mv), gw.game_time]
	peak[c.id] = pk
	var city_loss: float = 1.0 - cp / maxf(1.0, float(pk[0]))
	var mil_loss: float = 1.0 - mv / maxf(1.0, float(pk[1]))
	var lost_cap: bool = int(d["caps"]) == 0 and c.city_ids.size() > 0
	if lost_cap or (city_loss >= FAIL_LOSS and float(pk[0]) >= 6.0):
		return ST_FAIL
	var who: Dictionary = {}
	for k: String in dp.embargo:
		var ab: PackedStringArray = k.split(">")
		if int(ab[1]) == c.id:
			who[int(ab[0])] = true
	if dp.has_method("sanctioners_of"):
		for sid: Variant in dp.call("sanctioners_of", c.id):
			who[int(sid)] = true
	var others: int = 0
	for o: Country in gw.countries:
		if o.id != c.id and not o.eliminated and o.capital_id >= 0:
			others += 1
	if who.size() >= mini(PARIAH_N, maxi(2, ceili(float(others) * PARIAH_SHARE))) and who.size() >= 2:
		return ST_PARIAH
	if (city_loss >= WEAK_LOSS and float(pk[0]) >= 5.0) or (mil_loss >= 0.5 and float(pk[1]) >= 25.0 and not c.at_war.is_empty()):
		return ST_WEAK
	return ST_NONE


func _notable(c: Country, t0: int, t1: int, s0: int, s1: int) -> bool:
	if s1 != s0 and (s1 == ST_PARIAH or s1 == ST_FAIL or s1 == ST_VASSAL or s1 == ST_PUPPET):
		return true
	if s1 != s0 and s1 == ST_NONE and (s0 == ST_VASSAL or s0 == ST_PUPPET):
		return true
	return t1 != t0 and maxi(t0, t1) >= 4


func _announce(c: Country, t0: int, t1: int, s0: int, s1: int, e: int) -> void :
	var ev: Dictionary = {"cid": c.id, "t": gw.game_time, "old_tier": t0, "tier": t1, "old_state": s0, "state": s1, "epithet": e, 
		"notable": _notable(c, t0, t1, s0, s1), "up": t1 > t0}
	history.append([gw.game_time, c.id, t0, t1, s0, s1, e])
	if history.size() > 60:
		history.pop_front()
	counters["changes"] = int(counters.get("changes", 0)) + 1
	counters["up" if t1 > t0 else ("down" if t1 < t0 else "state")] = int(counters.get("up" if t1 > t0 else ("down" if t1 < t0 else "state"), 0)) + 1
	status_changed.emit(ev)

	if status_changed.get_connections().is_empty():
		gw.say(c, change_text(ev, true))
	if bool(ev["notable"]):
		gw.news.emit(change_text(ev, false).to_upper(), "grass_light" if t1 > t0 or (s1 == ST_NONE) else "amber")




func _rival_ok(a: Country, b: Country) -> bool:
	var dp: Diplomacy = gw.diplo
	if b == null or b.id == a.id or b.is_player or b.eliminated or b.capital_id < 0:
		return false
	if dp.allied(a.id, b.id) or (dp.ally != null and dp.ally.same(a.id, b.id)):
		return false
	return dp.subject_of(a.id) != b.id and dp.subject_of(b.id) != a.id


func _rival_score(a: Country, b: Country) -> float:
	var dp: Diplomacy = gw.diplo
	var pa: String = String(dp._p(a.id).get("id", ""))
	var pb: String = String(dp._p(b.id).get("id", ""))
	var s: float = 0.0
	if dp.neighbours(a.id, b.id):
		s += 2.0
	if (pa == "militarist" and pb == "trader") or (pa == "trader" and pb == "militarist"):
		s += 1.5
	if (pa == "adventurer" and pb == "cautious") or (pa == "cautious" and pb == "adventurer"):
		s += 1.0
	if pa == "militarist" and pb == "militarist":
		s += 1.0
	var ra: float = maxf(1.0, dp.strength(a.id))
	var r: float = dp.strength(b.id) / ra
	if r >= 0.6 and r <= 1.67:
		s += 1.0
	if dp.get_opinion(a.id, b.id) < 0:
		s += 1.0
	s += float(Hash32.h2(gw.data.world_seed, a.id * 64 + b.id, 3310) % 100) / 100.0
	return s


func _best_rival(a: Country, skip: int) -> Array:
	var best: int = -1
	var bs: float = -1.0
	for b: Country in gw.countries:
		if b.id == skip or not _rival_ok(a, b):
			continue
		var s: float = _rival_score(a, b)
		if s > bs:
			bs = s
			best = b.id
	return [best, bs]


func _rival_tick() -> void :
	var full: bool = gw.game_time >= rival_t
	if full:
		rival_t = gw.game_time + RIVAL_EVERY
	var leader: int = int(gw.diplo.coalition.get("leader", 0)) if not (gw.diplo.coalition.get("members", []) as Array).is_empty() else 0
	for a: Country in _alive_list():
		var cur: int = int(rival.get(a.id, -1))
		var ok: bool = cur > 0 and _rival_ok(a, gw.country_by_id(cur))
		if ok and not full:
			pass
		else:
			var br: Array = _best_rival(a, -1)
			var nid: int = int(br[0])
			if ok and nid != cur and nid > 0 and float(br[1]) < _rival_score(a, gw.country_by_id(cur)) + RIVAL_SWITCH:
				nid = cur
			if nid != cur:
				if nid > 0:
					rival[a.id] = nid
				else:
					rival.erase(a.id)
				counters["rival_changes"] = int(counters.get("rival_changes", 0)) + 1
				rival_changed.emit(a.id, nid)

		var cur2: int = int(rival2.get(a.id, -1))
		if a.id == leader and rival.has(a.id):
			if cur2 <= 0 or not _rival_ok(a, gw.country_by_id(cur2)) or full:
				var b2: int = int(_best_rival(a, int(rival[a.id]))[0])
				if b2 > 0:
					rival2[a.id] = b2
				else:
					rival2.erase(a.id)
		elif cur2 > 0:
			rival2.erase(a.id)




func save_state() -> Dictionary:
	return {"tier": tier, "epi": epi, "state": state, "pts": pts, "rel": rel, "stand": stand, "rank": rank, "hold": hold, "since": since, "s_since": s_since, "e_since": e_since, 
		"earned0": earned0, "trade0": trade0, "inc": inc, "trd": trd, "peak": peak, "rival": rival, "rival2": rival2, "rival_t": rival_t, 
		"next_t": next_t, "evals": evals, "history": history, "counters": counters}


func load_state(d: Dictionary) -> void :
	for k: String in ["tier", "epi", "state", "pts", "rel", "stand", "rank", "hold", "since", "s_since", "e_since", "earned0", "trade0", "inc", "trd", "peak", "rival", "rival2", "counters"]:
		if d.get(k) is Dictionary:
			var src: Dictionary = d[k]
			var dst: Dictionary = {}
			for kk: Variant in src:
				dst[int(kk)] = src[kk] if k != "counters" else src[kk]
			if k == "counters":
				dst = src.duplicate()
			set(k, dst)
	rival_t = float(d.get("rival_t", 0.0))
	next_t = float(d.get("next_t", 0.0))
	evals = int(d.get("evals", 0))
	if d.get("history") is Array:
		history = (d["history"] as Array).duplicate()



func hash_nums() -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	out.append(float(evals))
	var ids: Array = tier.keys()
	ids.sort()
	for id: int in ids:
		out.append(float(id * 1000 + int(tier[id]) * 100 + int(state.get(id, 0)) * 10 + int(epi.get(id, -1)) + 1))
	var rk: Array = rival.keys()
	rk.sort()
	for id2: int in rk:
		out.append(float(id2 * 1000 + int(rival[id2])))
	return out
