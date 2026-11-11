extends RefCounted























const EVAL_DT: float = 30.0
const HIST_DT: float = 60.0
const HIST_N: int = 21
const MAX_ACTIVE: int = 3
const FIRST_T: float = 240.0
const SHOW_T: float = 480.0
const SHOW_P: float = 0.35
const CLIMAX_P: float = 0.78
const END_P: float = 0.1
const ENTRY: float = 0.45
const HUMAN_WAR_CAP: float = 0.35
const MAX_COUNTRIES: int = 8
const KINDS: Array = ["colonial", "partition", "coalition", "blocs", "backstab", "arms", "trade", "hermit", "rising", "puppets"]
const KIND_NAMES: Array = ["КОЛОНИАЛЬНАЯ ГОНКА", "РАСКОЛ", "БОЛЬШАЯ КОАЛИЦИЯ", "ХОЛОДНАЯ ВОЙНА", "ПРЕДАТЕЛЬСТВО", 
	"ГОНКА ВООРУЖЕНИЙ", "САНКЦИОННАЯ ВОЙНА", "ИЗОЛЯЦИЯ", "ВЫЗОВ ЛИДЕРУ", "ИМПЕРИЯ МАРИОНЕТОК"]
enum K{COLONIAL, PARTITION, COALITION, BLOCS, BACKSTAB, ARMS, TRADE, HERMIT, RISING, PUPPETS}


const PRIOR: Array = [1.1, 1.7, 0.85, 0.5, 1.0, 0.75, 0.55, 1.2, 1.0, 1.2]

const NOT_AGGR: Array = ["в поддержку", "призыв союзника", "мятеж вассала", "инцидент"]
const DIRS: Dictionary = {"S": ["ЮГ", "Южная"], "N": ["СЕВЕР", "Северная"], "E": ["ВОСТОК", "Восточная"], "W": ["ЗАПАД", "Западная"]}
const PREFIXES: Array = ["Южная ", "Северная ", "Восточная ", "Западная ", "Новая "]
const CONTRAST: Dictionary = {"militarist": "trader", "adventurer": "cautious", "trader": "militarist", "cautious": "adventurer"}

var gw: GameWorld
var arcs: Array = []
var done: Array = []
var chron: Array = []
var cool: Dictionary = {}
var hist: Dictionary = {}
var counters: Dictionary = {}
var next_t: float = 0.0
var hist_t: float = 0.0
var new_t: float = 0.0
var next_id: int = 1
var temper: Array = []
var trace_on: bool = false


var dev_split_t: float = -1.0


func _init(world: GameWorld) -> void :
	gw = world
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--drama-split="):
			dev_split_t = float(arg.get_slice("=", 1))





func bias(c: Variant, topic: String, other: int = -1) -> float:
	var id: int = _cid(c)
	if id <= 0 or arcs.is_empty():
		return 0.0
	if topic == "help":
		topic = "join_war"
	var s: float = 0.0
	for a: Dictionary in arcs:
		var o2: int = other
		if o2 < 0 and topic in ["war", "sanction", "join_war", "aid", "sky", "request", "treaty", "alliance"]:
			o2 = _natural_other(a, id, topic)
		var v: float = _bias1(a, id, topic, o2)
		if topic == "war" and other < 0 and o2 > 0 and v > 0.0:
			var oc: Country = gw.country_by_id(o2)
			if oc != null and oc.is_player:
				v = 0.0 if not oc.at_war.is_empty() else minf(v, HUMAN_WAR_CAP)
		s += v
	if topic == "war" and other > 0:
		var o: Country = gw.country_by_id(other)
		if o != null and o.is_player:

			s = minf(s, 0.0 if not o.at_war.is_empty() else HUMAN_WAR_CAP)
	return clampf(s, -1.0, 1.0)



func war_mul(a: int, b: int) -> float:
	return clampf(1.0 + 1.5 * bias(a, "war", b), 0.25, 2.5)



func drift(a: int, b: int, h: int, op: int) -> int:
	if arcs.is_empty():
		return 0
	var v: int = 0
	for arc: Dictionary in arcs:
		var p: float = float(arc["p"])
		if p < 0.3:
			continue
		var k: int = int(arc["k"])
		var x: int = int(arc["a"])
		var y: int = int(arc["b"])
		match k:
			K.COALITION:
				var m: Array = arc["m"]
				if m.has(a) and m.has(b) and h % 3 == 0:
					v += 1
				elif ((m.has(a) and b == y) or (m.has(b) and a == y)) and h % 3 == 1:
					v -= 1
			K.BLOCS:
				var sa: int = _side(arc, a)
				var sb: int = _side(arc, b)
				if sa != 0 and sa == sb and h % 3 == 0:
					v += 1
				elif sa != 0 and sb != 0 and sa != sb and h % 3 == 1:
					v -= 1
			K.PARTITION:
				if bool(arc["climax"]) and _pair(a, b, x, y) and h % 2 == 0:
					v -= 1
			K.ARMS:
				if _pair(a, b, x, y) and h % 4 == 0:
					v -= 1
			K.RISING:
				if _pair(a, b, x, y) and h % 3 == 2 and p >= 0.4:
					v -= 1
			K.TRADE:
				var tm: Array = arc["m"]
				if _pair(a, b, x, y) and h % 3 == 0:
					v -= 1
				elif ((a == x and tm.has(b)) or (b == x and tm.has(a))) and h % 3 == 1:
					v += 1
			K.HERMIT:
				if (a == x or b == x) and h % 3 == 0:
					if op > 15:
						v -= 1
					elif op < -25:
						v += 1
	return clampi(v, -1, 1)



func colony_target(c: Variant) -> int:
	var id: int = _cid(c)
	for a: Dictionary in arcs:
		if int(a["k"]) == K.COLONIAL and int(a["a"]) == id and float(a["p"]) >= 0.25:
			return int(a["b"])
	return -1



func ally_threats(c: int) -> Array:
	var out: Array = []
	for a: Dictionary in arcs:
		if float(a["p"]) < 0.45:
			continue
		match int(a["k"]):
			K.COALITION:
				if (a["m"] as Array).has(c):
					out.append({"kind": "drama", "id": int(a["b"]), "why": "коалиция против страны %s" % _cn(int(a["b"]))})
			K.BLOCS:
				var s: int = _side(a, c)
				if s != 0 and c != int(a["a"]) and c != int(a["b"]):
					var head: int = int(a["b"]) if s == 1 else int(a["a"])
					out.append({"kind": "drama", "id": head, "why": "блок против страны %s" % _cn(head)})
	return out



func faces(o: int, id: int) -> bool:
	for a: Dictionary in arcs:
		match int(a["k"]):
			K.COALITION:
				if int(a["b"]) == id and (a["m"] as Array).has(o):
					return true
			K.BLOCS:
				var s: int = _side(a, o)
				if s != 0 and ((id == int(a["a"]) and s == -1) or (id == int(a["b"]) and s == 1)) and o != int(a["a"]) and o != int(a["b"]):
					return true
	return false



func threat_alive(id: int) -> bool:
	for a: Dictionary in arcs:
		if float(a["p"]) >= 0.25 and ((int(a["k"]) == K.COALITION and int(a["b"]) == id) or (int(a["k"]) == K.BLOCS and (int(a["a"]) == id or int(a["b"]) == id))):
			return true
	return false



func chronicle() -> Array:
	var out: Array = []
	for e: Array in chron:

		var k: int = int(e[1])
		out.append({"t": float(e[0]), "kind": String(KINDS[k]) if k < EV_K0 else String(EV_KINDS[clampi(k - EV_K0, 0, EV_KINDS.size() - 1)]), "text": Loc.msg(e[2]), 
			"a": int(e[3]) if e.size() > 3 else 0, "b": int(e[4]) if e.size() > 4 else 0})
	return out



func arcs_view() -> Array:
	var out: Array = []
	for a: Dictionary in arcs:
		if bool(a["shown"]):
			out.append({"kind": String(KINDS[int(a["k"])]), "name": String(KIND_NAMES[int(a["k"])]), "a": int(a["a"]), "b": int(a["b"]), "p": float(a["p"]), "members": (a["m"] as Array).duplicate()})
	return out



func debug_cands() -> Array:
	var out: Array = []
	if temper.is_empty():
		return out
	for k in KINDS.size():
		var c: Dictionary = _candidate(k, gw.game_time)
		if not c.is_empty():
			out.append([String(KINDS[k]), int(c["a"]), int(c.get("b", -1)), snappedf(float(c["d"]), 0.01), snappedf(float(c["d"]) * float(temper[k]), 0.01)])
	return out





func _natural_other(a: Dictionary, id: int, topic: String) -> int:
	var x: int = int(a["a"])
	var y: int = int(a["b"])
	var hostile: bool = topic == "war" or topic == "sanction"
	match int(a["k"]):
		K.COALITION:
			var m: Array = a["m"]
			if not m.has(id):
				return -1
			if hostile:
				return y
			for o: Variant in m:
				if int(o) != id:
					return int(o)
			return -1
		K.BLOCS:
			var si: int = _side(a, id)
			if si == 0:
				return -1
			var head_other: int = y if si == 1 else x
			if not hostile:
				return x if si == 1 and id != x else (y if si == -1 and id != y else -1)
			if id == x or id == y:
				return head_other
			for e: Array in a["side"]:
				if int(e[1]) == - si and int(e[0]) != head_other:
					return int(e[0])
			return head_other
		K.TRADE:
			if id == x:
				return y if hostile else (int((a["m"] as Array)[0]) if not (a["m"] as Array).is_empty() else -1)
			return x if id == y or (a["m"] as Array).has(id) and hostile else -1
	if id == x and y > 0:
		return y if (hostile or topic == "treaty") else -1
	if id == y:
		return x if (hostile or topic == "treaty") else -1
	return -1

func _bias1(a: Dictionary, id: int, topic: String, other: int) -> float:
	var p: float = float(a["p"])
	var x: int = int(a["a"])
	var y: int = int(a["b"])
	match int(a["k"]):
		K.COLONIAL:
			if id == x:
				match topic:
					"colony":
						return 0.7 * p
					"expand":
						return 0.35 * p
		K.PARTITION:
			if not bool(a["climax"]):
				if id == x:
					match topic:
						"peace":
							return 0.5 * p
						"war":
							return -0.5 * p
						"join_war", "request":
							return -0.3 * p
						"demand":
							return -0.4 * p
			else:
				if id == x and other == y or id == y and other == x:
					match topic:
						"war":
							return (0.45 if id == x else 0.1) * p
						"treaty", "request", "alliance":
							return -0.7 * p
				if id == y and topic == "arms":
					return 0.4 * p
		K.COALITION:
			var m: Array = a["m"]
			if m.has(id):
				if other == y:
					match topic:
						"war":
							var hot: bool = false
							for e: Variant in _at_war_of(y):
								if m.has(int(e)):
									hot = true
							return (0.6 if hot else 0.25) * p * (1.0 if bool(a["climax"]) else 0.5)
						"sanction":
							return 0.5 * p
						"treaty", "request":
							return -0.4 * p
				elif other > 0 and m.has(other):
					match topic:
						"treaty":
							return 0.5 * p
						"alliance", "join_war":
							return 0.55 * p
						"aid", "sky":
							return 0.4 * p
						"request":
							return 0.3 * p
				if topic == "arms":
					return 0.35 * p
			elif id == y and topic == "arms":
				return 0.3 * p
		K.BLOCS:
			var si: int = _side(a, id)
			if si == 0:
				return 0.0
			if topic == "arms":
				return 0.25 * p
			if other <= 0:
				return 0.0
			var so: int = _side(a, other)
			if _pair(id, other, x, y):
				return -0.6 * p if topic == "war" else (-0.3 * p if topic == "treaty" else 0.0)
			if so == si:
				match topic:
					"treaty":
						return 0.45 * p
					"alliance", "join_war", "sky":
						return 0.45 * p
					"aid":
						return 0.5 * p
					"request":
						return 0.35 * p
			elif so != 0:
				match topic:
					"war":
						var oc: Country = gw.country_by_id(other)
						return 0.0 if oc == null or oc.is_player else 0.3 * p
					"sanction":
						return 0.35 * p
					"treaty":
						return -0.3 * p
					"request":
						return -0.4 * p
		K.BACKSTAB:
			if id == x and other == y:
				match topic:
					"war":
						return 0.9 * p
					"treaty":
						return 0.3 * (1.0 - p)
		K.ARMS:
			if id == x or id == y:
				if topic == "arms":
					return 0.6 * p
				if _pair(id, other, x, y):
					return 0.2 * p if topic == "war" else (-0.3 * p if topic == "treaty" else 0.0)
		K.TRADE:
			var tm: Array = a["m"]
			if id == x:
				if other == y:
					return 0.6 * p if topic == "sanction" else (-0.5 * p if topic == "treaty" else 0.0)
				if topic == "treaty":
					return 0.4 * p if tm.has(other) else 0.2 * p
				if topic == "request" and tm.has(other):
					return 0.2 * p
			elif id == y and other == x and topic == "sanction":
				return 0.4 * p
			elif tm.has(id) and other == y and topic == "sanction":
				return 0.3 * p
		K.HERMIT:
			if id == x:
				match topic:
					"treaty":
						return -0.6 * p
					"alliance", "colony", "sky":
						return -0.7 * p if topic == "alliance" else -0.6 * p
					"request", "join_war":
						return -0.6 * p
					"war", "aid":
						return -0.5 * p
					"arms":
						return 0.5 * p
					"expand":
						return -0.3 * p
					"demand":
						return -0.5 * p
		K.RISING:
			if id == x:
				match topic:
					"demand":
						return 0.3 * p
					"arms":
						return 0.4 * p
					"expand":
						return 0.45 * p
					"war":
						if other == y:
							return (0.4 if _wp(x) >= _wp(y) * 0.9 else 0.1) * p
					"treaty":
						if other == y:
							return -0.3 * p
			elif id == y:
				if topic == "arms":
					return 0.3 * p
				if topic == "war" and other == x:
					return 0.1 * p
		K.PUPPETS:
			if id == x:
				match topic:
					"subject":
						return 0.7 * p
					"demand":
						return 0.4 * p
					"expand":
						return 0.2 * p
					"war":
						if other > 0 and _s(other) * 2.0 < _s(x):
							return 0.15 * p
	return 0.0




func update(_dt: float) -> void :
	var now: float = gw.game_time
	if now >= hist_t:
		hist_t = now + HIST_DT
		_sample(now)
	if now < next_t:
		return
	next_t = now + EVAL_DT
	if gw.diplo == null:
		return
	_events(now)
	if temper.is_empty():
		_make_temper()
		if new_t <= 0.0:
			new_t = FIRST_T + float(absi(Hash32.h2(gw.data.world_seed if gw.data != null else 1, 7, 9107)) % 480)
	if dev_split_t >= 0.0 and now >= dev_split_t + EVAL_DT * 2.0:
		dev_split_t = -1.0
	if dev_split_t >= 0.0 and now >= dev_split_t:
		dev_split_t = -1.0
		_force_split(now)
	if now < FIRST_T:
		return
	for i in range(arcs.size() - 1, -1, -1):
		if not _step(arcs[i], now):
			arcs.remove_at(i)
	if arcs.size() < MAX_ACTIVE and now >= new_t:
		_try_new(now)


func _make_temper() -> void :
	var sd: int = gw.data.world_seed if gw.data != null else 1
	var n: int = KINDS.size()
	temper = []
	for k in n:
		temper.append(0.5 + float(absi(Hash32.h2(sd, k, 9101)) % 1000) / 1000.0 * 0.9)
	var f1: int = absi(Hash32.h2(sd, 1, 9102)) % n
	var f2: int = (f1 + 1 + absi(Hash32.h2(sd, 2, 9102)) % (n - 1)) % n
	temper[f1] = float(temper[f1]) + 0.45
	temper[f2] = float(temper[f2]) + 0.3
	for j in 2:
		var m1: int = absi(Hash32.h2(sd, 3 + j, 9102)) % n
		if m1 != f1 and m1 != f2:
			temper[m1] = float(temper[m1]) * 0.6


func _sample(now: float) -> void :
	for c: Country in gw.countries:
		if c.eliminated or c.capital_id < 0:
			continue
		var h: Array = hist.get(c.id, [])
		h.append([now, _s(c.id), c.city_ids.size(), _wp(c.id), c.captured, c.capital_id])
		while h.size() > HIST_N:
			h.pop_front()
		hist[c.id] = h



func _step(a: Dictionary, now: float) -> bool:
	var k: int = int(a["k"])
	var d: float = _drive(a, now)
	if d < 0.0:
		_end(a, now, String(a["data"].get("over", "gone")))
		return false
	var age: float = now - float(a["t0"])
	var life: float = float(a["life"])
	if age > life:
		d *= clampf(1.0 - (age - life) / 600.0, 0.0, 1.0)
	var tgt: float = clampf(d * (0.75 + 0.35 * minf(float(temper[k]), 1.5)), 0.0, 1.0)
	if k == K.PARTITION and not bool(a["climax"]):


		var ur: int = int(a["data"].get("ur", 0))
		ur = ur + 1 if d >= 0.4 else maxi(0, ur - 2)
		a["data"]["ur"] = ur
		tgt = minf(1.0, tgt + minf(0.25, 0.02 * float(ur)))
	var rt: float = float(a["rate"])
	if k == K.PARTITION and not bool(a["climax"]) and tgt < float(a["p"]):
		rt *= 0.35
	a["p"] = clampf(float(a["p"]) + rt * (tgt - float(a["p"])), 0.0, 1.0)
	var p: float = float(a["p"])
	if trace_on:
		print("  [drama] t%d #%d %s a%d b%d drive %.2f p %.2f" % [int(now), int(a["id"]), KINDS[k], int(a["a"]), int(a["b"]), d, p])
	if not bool(a["shown"]) and p >= _show_p(k) and now >= _show_t(a):
		a["shown"] = true
		_say(a, _show_text(a, now))
	if bool(a["shown"]) and not bool(a["climax"]):
		if p >= _climax_p(k):
			a["hold"] = int(a["hold"]) + 1
			if int(a["hold"]) >= 2:
				a["climax"] = true
				_climax(a, now)
		else:
			a["hold"] = 0
	var ov: String = _watch(a, now)
	if ov != "":
		_end(a, now, ov)
		return false
	if p < END_P and age > 240.0:
		_end(a, now, "fade")
		return false
	if not bool(a["shown"]) and p < 0.22 and age > (900.0 if k == K.PARTITION else 360.0):
		_end(a, now, "stillborn")
		return false
	return true


func _show_p(k: int) -> float:
	return 0.4 if k == K.BACKSTAB else (0.42 if k == K.PARTITION else SHOW_P)


func _climax_p(k: int) -> float:
	return 0.62 if k == K.PARTITION else (0.7 if k == K.COALITION else CLIMAX_P)



func _show_t(a: Dictionary) -> float:
	var t: float = maxf(SHOW_T, float(a["t0"]) + float(a["data"].get("lag", 0.0)))
	var b: Country = gw.country_by_id(int(a["b"]))
	if b != null and b.is_player:
		t = maxf(t, GameConfig.player_grace())
		if int(a["k"]) == K.COALITION:
			t = maxf(t, 1200.0)
	return t


func _try_new(now: float) -> void :
	var best: Dictionary = {}
	var bs: float = -1.0
	var slot: int = int(now / EVAL_DT)
	for k in KINDS.size():
		if _has_kind(k) or now < float(cool.get(str(k), 0.0)):
			continue
		var c: Dictionary = _candidate(k, now)
		if c.is_empty():
			continue
		if now < float(cool.get("%d:%d" % [k, int(c["a"])], 0.0)):
			continue
		var noise: float = float(absi(Hash32.h2(slot, k, 9103 + next_id)) % 240 - 120) / 1000.0
		var sc: float = float(c["d"]) * float(temper[k]) * float(PRIOR[k]) + noise
		if sc >= ENTRY and sc > bs:
			bs = sc
			best = c
			best["k"] = k
	if best.is_empty():
		new_t = now + 60.0
		return
	var sd: int = gw.data.world_seed if gw.data != null else 1
	var hh: int = absi(Hash32.h2(sd, next_id, 9104))
	var arc: Dictionary = {"id": next_id, "k": int(best["k"]), "a": int(best["a"]), "b": int(best.get("b", -1)), "m": (best.get("m", []) as Array).duplicate(), 
		"side": (best.get("side", []) as Array).duplicate(true), "t0": now, "p": 0.12, "rate": 0.08 + float(hh % 90) / 1000.0, 
		"life": 900.0 + float((hh / 97) % 1200), "shown": false, "climax": false, "hold": 0, "data": {"lag": 90.0 + float((hh / 13) % 300)}}
	next_id += 1
	arcs.append(arc)
	_count("start_" + String(KINDS[int(arc["k"])]))
	new_t = now + 90.0 + float((hh / 7) % 240)
	gw.diplo.dlog(int(arc["a"]), "мир: начинается дуга «%s»" % KIND_NAMES[int(arc["k"])], String(best.get("why", "")), float(best["d"]), ["drama", int(arc["k"]), int(arc["b"])])


func _names(a: Dictionary) -> void :
	a["data"]["na"] = _cn(int(a["a"]))
	a["data"]["nb"] = _cn(int(a["b"])) if int(a["b"]) > 0 else ""


func _has_kind(k: int) -> bool:
	for a: Dictionary in arcs:
		if int(a["k"]) == k:
			return true
	return false


func _end(a: Dictionary, now: float, why: String) -> void :
	var k: int = int(a["k"])
	if bool(a["shown"]):
		var tx: Variant = _end_text(a, why)
		if Loc.is_msg(tx):
			_say(a, tx)
	done.append([int(a["id"]), k, int(a["a"]), int(a["b"]), float(a["t0"]), now, why, bool(a["shown"]), bool(a["climax"])])
	while done.size() > 40:
		done.pop_front()
	_count("end_%s_%s" % [KINDS[k], why])
	var hh: int = absi(Hash32.h2(int(a["id"]), k, 9105))
	cool[str(k)] = now + (240.0 if why == "stillborn" else 420.0) + float(hh % 600)
	cool["%d:%d" % [k, int(a["a"])]] = now + 1500.0
	_branch(a, now, why)



func _branch(a: Dictionary, now: float, why: String) -> void :
	if arcs.size() > MAX_ACTIVE:
		return
	var k: int = int(a["k"])
	var x: int = int(a["a"])
	var y: int = int(a["b"])
	var nk: int = -1
	var na: int = -1
	var nb: int = -1
	match k:
		K.COLONIAL:
			if int(a["data"].get("near", 0)) > 0 and _alive(y) and _rel(x, y) < 15:
				nk = K.ARMS
				na = x
				nb = y
		K.RISING:
			if why == "overtook" and _alive(x):
				nk = K.COALITION
				na = x
				nb = x
	if nk < 0 or _has_kind(nk) or now < float(cool.get(str(nk), 0.0)):
		return
	var m: Array = []
	if nk == K.COALITION:
		var cc: Dictionary = _coal(nb, now)
		if cc.is_empty():
			return
		m = cc["m"]
	elif _d_arms(na, nb) <= 0.0:
		return
	var arc: Dictionary = {"id": next_id, "k": nk, "a": na, "b": nb, "m": m.duplicate(), 
		"side": [], "t0": now, "p": 0.3, "rate": 0.1, "life": 1200.0, "shown": false, "climax": false, "hold": 0, "data": {"from": int(a["id"])}}
	next_id += 1
	arcs.append(arc)
	_count("branch_%s_%s" % [KINDS[k], KINDS[nk]])



func _say(a: Dictionary, text: Variant) -> void :
	if not Loc.is_msg(text):
		return
	var k: int = int(a["k"])
	chron.append([gw.game_time, k, text, int(a.get("a", 0)), int(a.get("b", 0))])
	while chron.size() > 60:
		chron.pop_front()
	_count("news")
	if not ev.is_empty():
		ev["next"] = maxf(float(ev["next"]), gw.game_time + 60.0)
	var col: String = "alert_red" if k in [K.PARTITION, K.COALITION, K.BACKSTAB] else "amber"
	gw.news_m(text, col)





func _candidate(k: int, now: float) -> Dictionary:
	match k:
		K.COLONIAL:
			return _cand_colonial(now)
		K.PARTITION:
			return _cand_partition(now)
		K.COALITION:
			return _cand_coalition(now)
		K.BLOCS:
			return _cand_blocs(now)
		K.BACKSTAB:
			return _cand_backstab(now)
		K.ARMS:
			return _cand_arms(now)
		K.TRADE:
			return _cand_trade(now)
		K.HERMIT:
			return _cand_hermit(now)
		K.RISING:
			return _cand_rising(now)
		K.PUPPETS:
			return _cand_puppets(now)
	return {}



func _drive(a: Dictionary, now: float) -> float:
	var x: int = int(a["a"])
	var y: int = int(a["b"])
	if not _alive(x):
		a["data"]["over"] = "gone"
		return -1.0
	if not a["data"].has("na"):
		_names(a)
	if _cn(x) != String(a["data"]["na"]) or (y > 0 and _cn(y) != String(a["data"]["nb"])):
		a["data"]["over"] = "gone"
		return -1.0
	match int(a["k"]):
		K.COLONIAL:
			return _d_colonial(x, y, true)
		K.PARTITION:
			if bool(a["climax"]):
				if not _alive(y):
					a["data"]["over"] = "reunited"
					return -1.0
				return 0.6 if _rel(x, y) < 0 or _at_war(x, y) else 0.25
			return _d_partition(x, now)
		K.COALITION:
			if not _alive(y):
				a["data"]["over"] = "gone"
				return -1.0
			var cc: Dictionary = _coal(y, now)
			if cc.is_empty():
				return 0.0
			_merge_members(a, cc["m"])
			return float(cc["d"])
		K.BLOCS:
			if not _alive(y):
				a["data"]["over"] = "gone"
				return -1.0
			if _at_war(x, y):
				a["data"]["over"] = "hot"
				return -1.0
			a["side"] = _sides(x, y, a["side"])
			return _d_blocs(x, y, a["side"])
		K.BACKSTAB:
			if not _alive(y):
				a["data"]["over"] = "gone"
				return -1.0
			return _d_backstab(x, y, now)
		K.ARMS:
			if not _alive(y):
				a["data"]["over"] = "gone"
				return -1.0
			return _d_arms(x, y)
		K.TRADE:
			if not _alive(y):
				a["data"]["over"] = "gone"
				return -1.0
			a["m"] = _partners(x, y)
			return _d_trade(x, y)
		K.HERMIT:
			return _d_hermit(x, now)
		K.RISING:
			if not _alive(y):
				a["data"]["over"] = "gone"
				return -1.0
			return _d_rising(x, y)
		K.PUPPETS:
			return _d_puppets(x)
	return 0.0




func _cand_colonial(now: float) -> Dictionary:
	if gw.naval == null:
		return {}
	var best: Dictionary = {}
	for c: Country in _bots():
		var d: float = _d_colonial(c.id, -1)
		if d <= 0.0:
			continue
		var b: int = _colony_target_pick(c)
		if b > 0:
			d += 0.1
		if best.is_empty() or d > float(best["d"]):
			best = {"a": c.id, "b": b, "d": d, "why": "порт, свободные берега"}
	return best


func _d_colonial(x: int, _y: int, going: bool = false) -> float:
	var c: Country = gw.country_by_id(x)
	if c == null or c.is_player or gw.naval == null:
		return 0.0
	var pr: Variant = gw.naval._ports()
	if pr == null or pr.port_of(c) == null:
		return 0.0
	if gw.naval.colony_count(c) >= gw.naval.colony_cap(c):
		return 0.0
	if not going and (c.city_ids.size() < 6 or _cities_ago(x, 600.0) < c.city_ids.size() or gw.game_time < 600.0):
		return 0.0
	var d: float = 0.3 + 0.25 * _tr(x, "trade") + 0.2 * _tr(x, "sneaky") - 0.2 * _tr(x, "caution")
	if not c.at_war.is_empty():
		d -= 0.3
	return clampf(d, 0.0, 1.0)


func _colony_target_pick(c: Country) -> int:
	var pr: Variant = gw.naval._ports()
	var port: Facility = pr.port_of(c) if pr != null else null
	if port == null:
		return -1
	var pc: Vector2 = port.center_px()
	var best: int = -1
	var bd: float = 7000.0 * 0.8
	for o: Country in _alive_l():
		if o.id == c.id or gw.diplo.allied(c.id, o.id) or _same_ally(c.id, o.id):
			continue
		var dd: float = 1000000000000.0
		for cid in o.city_ids:
			dd = minf(dd, Vector2(gw.cities[cid].center * GameWorld.CELL).distance_to(pc))
		if _rival(c.id, o.id):
			dd *= 0.8
		if o.is_player:
			dd *= 0.85
		if dd < bd:
			bd = dd
			best = o.id
	return best




func _cand_partition(now: float) -> Dictionary:
	var best: Dictionary = {}
	for c: Country in _bots():
		var d: float = _d_partition(c.id, now)
		if d > 0.0 and (best.is_empty() or d > float(best["d"])):
			best = {"a": c.id, "b": -1, "d": d, "why": "кризис большой страны"}
	return best


func _d_partition(x: int, now: float) -> float:
	var c: Country = gw.country_by_id(x)
	if c == null or c.is_player or c.city_ids.size() < 5 or gw.diplo.is_subject(x) or _in_conf(x):
		return 0.0
	var d: float = 0.0
	var e10: Array = _ago(x, 600.0)
	if e10.size() > 5 and int(e10[5]) != c.capital_id and gw.game_time - float(e10[0]) >= 300.0:
		d += 0.3
	for o: Country in _alive_l():
		if o.id != x and gw.game_time - float(gw.diplo.peace_t.get(Diplomacy.key(x, o.id), -1000000000.0)) < 600.0 and _cities_ago(x, 1200.0) > c.city_ids.size():
			d += 0.15
			break
	match _state(x):
		3:
			d += 0.45
		1:
			d += 0.3
		2:
			d += 0.15
	for e: Variant in c.at_war.keys():
		var eid: int = int(e)
		if gw.diplo.war_time(x, eid) >= 300.0 and _s(x) < _s(eid) * 0.8:
			d += 0.2
			break
	for e2: Variant in c.at_war.keys():
		if gw.diplo.war_time(x, int(e2)) >= 900.0:
			d += 0.1
			break
	if not c.at_war.is_empty() and _growth(x, 600.0) < 0.75:
		d += 0.25
	var lost: int = _cities_ago(x, 600.0) - c.city_ids.size()
	var peak: int = 0
	for e9: Array in hist.get(x, []):
		peak = maxi(peak, int(e9[2]))
	if peak >= 7 and c.city_ids.size() * 10 <= peak * 7:
		d += 0.2
	if lost >= 2:
		d += 0.15
	var spread: float = _spread(c)
	if spread >= 0.33 and c.city_ids.size() >= 9:
		d += 0.15


	if c.city_ids.size() >= 8:
		d += minf(0.3, 0.06 * float(c.city_ids.size() - 7))
	var strain: bool = c.at_war.size() >= 2 or _state(x) in [1, 3] or lost >= 1
	if c.city_ids.size() >= 10 and strain:
		d += 0.25
	var conq: int = 0
	for cid3 in c.city_ids:
		if gw.cities[cid3].taken_by.has(x):
			conq += 1
	if conq >= 3 and (strain or not c.at_war.is_empty() or conq >= 5):
		d += minf(0.3, 0.15 + 0.05 * float(conq - 3))
	if c.at_war.is_empty() and _rank(x) == 1 and lost <= 0:
		d -= 0.3
	return clampf(d, 0.0, 1.0)


func _spread(c: Country) -> float:
	if c.capital_id < 0 or gw.data == null:
		return 0.0
	var cap: Vector2i = gw.cities[c.capital_id].center
	var m: float = 0.0
	for cid in c.city_ids:
		m = maxf(m, Vector2(gw.cities[cid].center - cap).length())
	return m / float(maxi(1, gw.data.w))



func _split_group(c: Country) -> Dictionary:
	if c.capital_id < 0:
		return {}
	var n: int = c.city_ids.size()
	if n < 4:
		return {}
	var cap: Vector2i = gw.cities[c.capital_id].center
	var minx: int = 1 << 30
	var maxx: int = - (1 << 30)
	var miny: int = 1 << 30
	var maxy: int = - (1 << 30)
	for cid in c.city_ids:
		var p: Vector2i = gw.cities[cid].center
		minx = mini(minx, p.x)
		maxx = maxi(maxx, p.x)
		miny = mini(miny, p.y)
		maxy = maxi(maxy, p.y)
	var vert: bool = (maxy - miny) >= (maxx - minx)
	var items: Array = []
	for cid2 in c.city_ids:
		var q: Vector2i = gw.cities[cid2].center
		items.append([q.y if vert else q.x, cid2])
	items.sort_custom( func(u: Array, v: Array) -> bool: return int(u[0]) < int(v[0]) or (int(u[0]) == int(v[0]) and int(u[1]) < int(v[1])))
	var cap_v: int = cap.y if vert else cap.x
	var mid: int = int(items[n / 2][0])
	var far_high: bool = cap_v <= mid
	var take: int = clampi(n * 2 / 5, 2, n - (3 if n >= 6 else 2))
	var ids: Array = []
	var order: Array = items.duplicate()
	if far_high:
		order.reverse()
	for it: Array in order:
		if ids.size() >= take:
			break
		if int(it[1]) == c.capital_id:
			break
		ids.append(int(it[1]))
	if ids.size() < 2:
		return {}
	var dir: String = ("S" if far_high else "N") if vert else ("E" if far_high else "W")
	return {"ids": ids, "dir": dir}



func _force_split(now: float) -> void :
	var best: Country = null
	for c: Country in _bots():
		if c.city_ids.size() >= 4 and (best == null or c.city_ids.size() > best.city_ids.size()):
			best = c
	if best == null:
		print("[drama] forced split: no bot with 4+ cities")
		return
	var arc: Dictionary = {"id": next_id, "k": K.PARTITION, "a": best.id, "b": -1, "m": [], "side": [], "t0": now, "p": 0.9, "rate": 0.1, 
		"life": 1200.0, "shown": true, "climax": true, "hold": 2, "data": {"dev": true}}
	next_id += 1
	arcs.append(arc)
	_partition(arc, now)
	print("[drama] forced split t=%d: %s / %s" % [int(now), _cn(best.id), _cn(int(arc["b"]))])


func _opp(dir: String) -> String:
	return {"S": "N", "N": "S", "E": "W", "W": "E"}[dir]


func _base_name(nm: String) -> String:
	for pf: String in PREFIXES:
		if nm.begins_with(pf):
			return nm.substr(pf.length())
	return nm



func _partition(a: Dictionary, now: float) -> void :
	var c: Country = gw.country_by_id(int(a["a"]))
	var g: Dictionary = _split_group(c)
	if g.is_empty():
		a["data"]["over"] = "suppressed"
		return
	var ids: Array = g["ids"]
	var nc: Country = _make_state(ids)
	if nc == null:
		a["data"]["over"] = "suppressed"
		_count("partition_no_slot")
		return
	var dir: String = String(a["data"].get("dir", g["dir"]))
	var base: String = _base_name(c.name)
	var old_name: String = c.name
	c.name = "%s %s" % [DIRS[_opp(dir)][1], base]
	nc.name = "%s %s" % [DIRS[dir][1], base]
	var pid: String = String(gw.ai.personas.get(c.id, "trader")) if gw.ai != null else "trader"
	if gw.ai != null:
		gw.ai.personas[nc.id] = String(CONTRAST.get(pid, "cautious"))
	var dp: Diplomacy = gw.diplo
	var k: String = Diplomacy.key(c.id, nc.id)
	dp.opinion[k] = -45
	dp.peace_t[k] = now
	for o: Country in _alive_l():
		if o.id != nc.id:
			dp.close_land(o.id, nc.id)
	a["b"] = nc.id
	a["data"]["old"] = old_name
	for a2: Dictionary in arcs:
		if int(a2["a"]) in [c.id, nc.id] or int(a2["b"]) in [c.id, nc.id] or a2 == a:
			_names(a2)
	a["data"]["n"] = ids.size()
	_count("partitions")
	_say(a, Loc.mk("РАСКОЛ: {p0:name} И {p1:name} — {p2} РАСПАЛАСЬ НАДВОЕ", {"p0": c.name.to_upper(), "p1": nc.name.to_upper(), "p2": old_name.to_upper()}))
	dp.dlog(c.id, "раскол: %s отделилась (%d гор.)" % [nc.name, ids.size()], "кризис", 0.0, ["drama", "partition", nc.id])
	gw.relations_changed.emit()
	gw.changed.emit()


func _make_state(ids: Array) -> Country:
	if gw.countries.size() < MAX_COUNTRIES:
		return gw.new_country_from(ids)
	var dp: Diplomacy = gw.diplo
	if dp.conf == null:
		return null
	for e: Country in gw.countries:
		if not e.eliminated or e.is_player or not e.city_ids.is_empty():
			continue
		var src: Country = gw.country_by_id(gw.cities[int(ids[0])].country_id) if not ids.is_empty() else null
		dp.conf._revive(e)
		e.ai_diff = src.ai_diff if src != null and not src.is_player else -1
		var was: bool = gw.capture_quiet
		gw.capture_quiet = true
		for cid: Variant in ids:
			gw.capture_city(gw.cities[int(cid)], e.id)
		gw.capture_quiet = was
		var best: int = -1
		for id in e.city_ids:
			if best < 0 or gw.cities[id].kind < gw.cities[best].kind or (gw.cities[id].kind == gw.cities[best].kind and gw.cities[id].radius > gw.cities[best].radius):
				best = id
		if best < 0:
			return null
		e.capital_id = best
		gw.cities[best].kind = City.Kind.CAPITAL
		gw._update_territory_colors()
		return e
	return null


func _in_conf(x: int) -> bool:
	var dp: Diplomacy = gw.diplo
	if dp.conf == null:
		return false
	for cf: Dictionary in dp.conf.active:
		if int(cf.get("def", -1)) == x or (cf.get("parts", []) as Array).has(x):
			return true
	return false




func _cand_coalition(now: float) -> Dictionary:
	var al: Array[Country] = _alive_l()
	if al.size() < 4:
		return {}
	var top: Country = _top()
	if top == null:
		return {}
	var cc: Dictionary = _coal(top.id, now)
	if cc.is_empty():
		return {}
	return {"a": top.id, "b": top.id, "m": cc["m"], "d": cc["d"], "why": "лидер слишком силён"}



func _coal(b: int, now: float) -> Dictionary:
	if now < 900.0:
		return {}
	var al: Array[Country] = _alive_l()
	if al.size() < 4:
		return {}
	var top: Country = _top()
	if top == null or top.id != b:
		return {}
	var second: float = 1.0
	var total: float = 0.0
	for c: Country in al:
		total += _s(c.id)
		if c.id != b:
			second = maxf(second, _s(c.id))
	var lead: float = _s(b) / second
	var share: float = _s(b) / maxf(1.0, total)
	if lead < 1.15 or share < 0.2:
		return {}
	var bc: Country = gw.country_by_id(b)
	if bc.is_player and now < 1200.0:
		return {}
	var aggr: int = _aggr_wars(b, now - 900.0)
	var caps: int = _captured_ago(b, 900.0)
	var d: float = clampf((lead - 1.1) * 1.2, 0.0, 0.5) + clampf((share - 0.18) * 2.0, 0.0, 0.25) + minf(0.3, 0.15 * float(aggr)) + minf(0.25, 0.08 * float(caps))
	if _tier(b) >= 4:
		d += 0.1
	if bc.is_player and aggr == 0 and caps < 2 and lead < 1.6:
		d *= 0.5
	var m: Array = []
	var cands: Array = []
	for c2: Country in al:
		if c2.id == b or c2.is_player or gw.diplo.allied(c2.id, b) or _same_ally(c2.id, b) or gw.diplo.subject_of(c2.id) == b or gw.diplo.is_subject(c2.id):
			continue
		if _rel(c2.id, b) >= 35:
			continue
		var sc: float = (2.0 if gw.diplo.neighbours(c2.id, b) else 0.0) + (1.0 if _rel(c2.id, b) < 0 else 0.0) + (1.0 if gw.diplo.at_war(c2.id, b) else 0.0) + float(absi(Hash32.h2(c2.id, b, 9106)) % 100) / 200.0
		cands.append([sc, c2.id])
	cands.sort_custom( func(u: Array, v: Array) -> bool: return float(u[0]) > float(v[0]) or (float(u[0]) == float(v[0]) and int(u[1]) < int(v[1])))
	for e: Array in cands:
		if m.size() >= 4:
			break
		m.append(int(e[1]))
	if m.size() < 2:
		return {}
	return {"m": m, "d": clampf(d, 0.0, 1.0)}


func _merge_members(a: Dictionary, nm: Array) -> void :

	var m: Array = []
	for x: Variant in a["m"]:
		if nm.has(int(x)):
			m.append(int(x))
	for y: Variant in nm:
		if not m.has(int(y)):
			m.append(int(y))
	a["m"] = m




func _cand_blocs(now: float) -> Dictionary:
	if now < 600.0:
		return {}
	var al: Array[Country] = _alive_l()
	if al.size() < 5:
		return {}
	var top: Array = al.duplicate()
	top.sort_custom( func(u: Country, v: Country) -> bool: return _s(u.id) > _s(v.id) or (_s(u.id) == _s(v.id) and u.id < v.id))
	var best: Dictionary = {}
	for i in mini(3, top.size()):
		for j in range(i + 1, mini(3, top.size())):
			var x: int = (top[i] as Country).id
			var y: int = (top[j] as Country).id
			if (top[i] as Country).is_player and (top[j] as Country).is_player:
				continue
			if gw.diplo.at_war(x, y) or gw.diplo.allied(x, y) or _same_ally(x, y):
				continue
			var sd: Array = _sides(x, y, [])
			var d: float = _d_blocs(x, y, sd)
			if d > 0.0 and (best.is_empty() or d > float(best["d"])):
				best = {"a": x, "b": y, "side": sd, "d": d, "why": "две силы и их друзья"}
	return best


func _d_blocs(x: int, y: int, side: Array) -> float:
	var r: float = _s(x) / maxf(1.0, _s(y))
	if r > 1.7 or r < 1.0 / 1.7:
		return 0.0
	var rel: int = _rel(x, y)
	if _tier(x) < 2 or _tier(y) < 2 or rel >= 10 or not (_rival(x, y) or rel < -30):
		return 0.0
	var d: float = 0.15 + (0.25 if _rival(x, y) else 0.0) + (0.2 if rel < -15 else 0.1)
	if _tier(x) >= 2 and _tier(y) >= 2:
		d += 0.1
	var n1: int = 0
	var n2: int = 0
	for e: Array in side:
		if int(e[1]) == 1:
			n1 += 1
		elif int(e[1]) == -1:
			n2 += 1
	if n1 == 0 or n2 == 0:
		d *= 0.6
	return clampf(d, 0.0, 1.0)



func _sides(x: int, y: int, prev: Array) -> Array:
	var old: Dictionary = {}
	for e: Array in prev:
		old[int(e[0])] = int(e[1])
	var out: Array = [[x, 1], [y, -1]]
	for c: Country in _alive_l():
		if c.id == x or c.id == y:
			continue
		var da: float = float(_rel(c.id, x) - _rel(c.id, y))
		for pr: Array in [[x, 1.0], [y, -1.0]]:
			var h: int = int(pr[0])
			var sg: float = float(pr[1])
			if gw.diplo.allied(c.id, h) or _same_ally(c.id, h):
				da += 25.0 * sg
			if gw.diplo.subject_of(c.id) == h:
				da += 40.0 * sg
			if gw.econ != null and gw.econ.trading(c.id, h):
				da += 10.0 * sg
			if gw.diplo.at_war(c.id, h):
				da -= 60.0 * sg
		var s: int = 1 if da >= 15.0 else (-1 if da <= -15.0 else 0)
		var o: int = int(old.get(c.id, 0))
		if o != 0 and s == 0 and da * float(o) >= 5.0:
			s = o
		out.append([c.id, s])
	return out


func _side(a: Dictionary, id: int) -> int:
	if int(a["k"]) != K.BLOCS:
		return 0
	for e: Array in a["side"]:
		if int(e[0]) == id:
			return int(e[1])
	return 0




func _cand_backstab(now: float) -> Dictionary:
	var best: Dictionary = {}
	for c: Country in _bots():
		if not c.at_war.is_empty():
			continue
		for o: Country in _alive_l():
			if o.id == c.id:
				continue
			var d: float = _d_backstab(c.id, o.id, now)
			if d > 0.0 and (best.is_empty() or d > float(best["d"])):
				best = {"a": c.id, "b": o.id, "d": d, "why": "сосед занят войной"}
	return best


func _d_backstab(x: int, y: int, now: float) -> float:
	var c: Country = gw.country_by_id(x)
	var o: Country = gw.country_by_id(y)
	if c == null or o == null or c.is_player or not c.at_war.is_empty() or o.at_war.is_empty():
		return 0.0
	var sn: float = _tr(x, "sneaky")
	var pid: String = _pid(x)
	var nap: bool = gw.diplo.has_treaty(x, y, "nap")
	if sn < 0.6 and not (pid == "militarist" and nap):
		return 0.0
	if gw.diplo.allied(x, y) or _same_ally(x, y) or gw.diplo.subject_of(x) == y or gw.diplo.subject_of(y) == x or gw.diplo.at_war(x, y):
		return 0.0
	if not gw.diplo.neighbours(x, y):
		return 0.0
	var rel: int = _rel(x, y)
	if rel < -20 or rel > 60 or _wp(x) < _wp(y) * 0.85:
		return 0.0
	if o.is_player and (now < GameConfig.player_grace() + 300.0 or o.at_war.size() != 1):
		return 0.0
	var e0: int = int(o.at_war.keys()[0])
	if gw.diplo.war_time(y, e0) < 90.0:
		return 0.0
	var d: float = 0.25 + 0.3 * sn
	for e: Variant in o.at_war.keys():
		if _s(y) < _s(int(e)) * 0.8:
			d += 0.2
			break
	if _rival(x, y):
		d += 0.1
	if nap:
		d += 0.1
	if o.is_player:
		d *= 0.75
	return clampf(d, 0.0, 1.0)




func _cand_arms(now: float) -> Dictionary:
	var best: Dictionary = {}
	var al: Array[Country] = _alive_l()
	for i in al.size():
		for j in range(i + 1, al.size()):
			var x: Country = al[i]
			var y: Country = al[j]
			if x.is_player and y.is_player:
				continue
			var a1: int = y.id if x.is_player else x.id
			var b1: int = x.id if x.is_player else y.id
			var d: float = _d_arms(a1, b1)
			if d > 0.0 and (best.is_empty() or d > float(best["d"])):
				best = {"a": a1, "b": b1, "d": d, "why": "соседи-соперники"}
	return best


func _d_arms(x: int, y: int) -> float:
	var dp: Diplomacy = gw.diplo
	if dp.at_war(x, y) or dp.allied(x, y) or _same_ally(x, y):
		return 0.0
	if not (dp.neighbours(x, y) or _rival(x, y)):
		return 0.0
	var r: float = _wp(x) / maxf(1.0, _wp(y))
	var rel: int = _rel(x, y)
	if r < 0.6 or r > 1.6 or rel >= -10:
		return 0.0
	var both: bool = _wp_growth(x, 600.0) > 1.15 and _wp_growth(y, 600.0) > 1.15
	if not both or not dp.neighbours(x, y) or not ((_rival(x, y) and rel < -30) or rel < -55):
		return 0.0
	var d: float = 0.2 * (1.0 if _rival(x, y) else 0.0) + (0.15 if rel < -40 else 0.0) + 0.15 * maxf(_tr(x, "aggr"), _tr(y, "aggr")) + 0.1
	return clampf(d, 0.0, 1.0)




func _cand_trade(now: float) -> Dictionary:
	if gw.econ == null:
		return {}
	var best: Dictionary = {}
	for c: Country in _bots():
		if _tr(c.id, "trade") < 0.9:
			continue
		for o: Country in _alive_l():
			if o.id == c.id:
				continue
			var d: float = _d_trade(c.id, o.id)
			if d > 0.0 and (best.is_empty() or d > float(best["d"])):
				best = {"a": c.id, "b": o.id, "m": _partners(c.id, o.id), "d": d, "why": "торговая держава и её недруг"}
	return best


func _partners(x: int, y: int) -> Array:
	var out: Array = []
	if gw.econ == null:
		return out
	for o: Country in _alive_l():
		if o.id == x or o.id == y or o.is_player:
			continue
		if gw.econ.trading(x, o.id) and _rel(o.id, y) < 20 and out.size() < 3:
			out.append(o.id)
	return out


func _d_trade(x: int, y: int) -> float:
	var dp: Diplomacy = gw.diplo
	if dp.at_war(x, y) or dp.allied(x, y) or _same_ally(x, y) or gw.econ == null:
		return 0.0
	var np: int = 0
	for o: Country in _alive_l():
		if o.id != x and gw.econ.trading(x, o.id):
			np += 1
	if np < 3 or _earn_rank(x) > 2:
		return 0.0
	var rel: int = _rel(x, y)
	var emb: bool = dp.embargo_between(x, y)
	if rel >= -5 and not emb:
		return 0.0
	if not ((_rival(x, y) and rel < -15) or (dp.embargoed(y, x) and rel < -30)):
		return 0.0
	var yc: Country = gw.country_by_id(y)
	if yc != null and yc.is_player and not _rival(x, y) and _earn_rank(y) > 3:
		return 0.0
	var d: float = 0.1 + 0.2 * _tr(x, "trade") + (0.12 if _rival(x, y) else 0.0) + (0.15 if emb else 0.0) + (0.1 if rel < -40 else 0.0)
	return clampf(d, 0.0, 1.0)




func _cand_hermit(now: float) -> Dictionary:
	var best: Dictionary = {}
	for c: Country in _bots():
		var d: float = _d_hermit(c.id, now)
		if d > 0.0 and (best.is_empty() or d > float(best["d"])):
			best = {"a": c.id, "b": -1, "d": d, "why": "проигранная война / враждебное окружение"}
	return best


func _d_hermit(x: int, now: float) -> float:
	var c: Country = gw.country_by_id(x)
	var dp: Diplomacy = gw.diplo
	if c == null or c.is_player or not c.at_war.is_empty() or (dp.ally != null and dp.ally.id_of(x) >= 0) or dp.is_subject(x):
		return 0.0
	var reason: float = 0.0
	var lost_war: bool = false
	for o: Country in _alive_l():
		var pt: float = float(dp.peace_t.get(Diplomacy.key(x, o.id), -1000000000.0))
		if now - pt < 900.0 and (_cities_ago(x, 1200.0) > c.city_ids.size() or _growth(x, 900.0) < 0.8):
			lost_war = true
	if lost_war:
		reason += 0.25
	if _state(x) == 2:
		reason += 0.2
	var ring: int = 0
	for o2: Country in _alive_l():
		if o2.id != x and dp.neighbours(x, o2.id) and _rel(x, o2.id) < -20 and _s(o2.id) > _s(x) * 1.2:
			ring += 1
	if ring >= 2:
		reason += 0.15
	if reason <= 0.0:
		return 0.0
	var d: float = 0.2 + 0.35 * _tr(x, "caution") + reason - (0.3 if _pid(x) == "trader" else 0.0)
	return clampf(d, 0.0, 1.0)




func _cand_rising(now: float) -> Dictionary:
	if now < 900.0:
		return {}
	var top: Country = _top()
	if top == null:
		return {}
	var best: Dictionary = {}
	for c: Country in _alive_l():
		if c.id == top.id:
			continue
		var d: float = _d_rising(c.id, top.id)
		if d > 0.0 and (best.is_empty() or d > float(best["d"])):
			best = {"a": c.id, "b": top.id, "d": d, "why": "быстрый рост"}
	return best


func _d_rising(x: int, y: int) -> float:
	if gw.diplo.allied(x, y) or _same_ally(x, y) or gw.diplo.subject_of(x) == y:
		return 0.0
	if _rank(x) > 3 or _s(x) < _s(y) * 0.6:
		return 0.0
	var gx: float = _growth(x, 600.0)
	var gy: float = _growth(y, 600.0)
	if gx < 1.15 or gx - gy < 0.12:
		return 0.0
	var d: float = 0.2 + clampf((gx - gy) * 1.5, 0.0, 0.45) + (0.15 if _rival(x, y) else 0.0) + 0.1 * _tr(x, "aggr")
	return clampf(d, 0.0, 1.0)




func _cand_puppets(now: float) -> Dictionary:
	if now < 900.0:
		return {}
	var best: Dictionary = {}
	for c: Country in _bots():
		var d: float = _d_puppets(c.id)
		if d > 0.0 and (best.is_empty() or d > float(best["d"])):
			best = {"a": c.id, "b": -1, "d": d, "why": "сильная держава с вассалами"}
	return best


func _d_puppets(x: int) -> float:
	var dp: Diplomacy = gw.diplo
	var c: Country = gw.country_by_id(x)
	if c == null or c.is_player or dp.is_subject(x):
		return 0.0
	var ns: int = dp.subjects_of(x).size()
	var pid: String = _pid(x)
	var hard: bool = pid == "militarist" or pid == "adventurer"
	if ns == 0 and not (hard and _tier(x) >= 3 and _rank(x) <= 2):
		return 0.0
	var weak: int = 0
	for o: Country in _alive_l():
		if o.id != x and dp.neighbours(x, o.id) and _s(o.id) * 2.0 < _s(x):
			weak += 1
	if ns == 0 and weak < 2:
		return 0.0
	var d: float = 0.05 + 0.2 * float(mini(ns, 2)) + (0.2 if hard else 0.0) + (0.1 if _tier(x) >= 3 else 0.0) + (0.1 if weak >= 2 else 0.0)
	return clampf(d, 0.0, 1.0)




func _show_text(a: Dictionary, now: float) -> Variant:
	var x: String = _cn(int(a["a"])).to_upper()
	var y: String = _cn(int(a["b"])).to_upper() if int(a["b"]) > 0 else ""
	match int(a["k"]):
		K.COLONIAL:
			return Loc.mk("{p0:name} СНАРЯЖАЕТ КОЛОНИСТОВ ЗА МОРЕ — К БЕРЕГАМ {p1:cgen}", {"p0": x, "p1": y}) if y != "" else Loc.mk("{p0:name} СНАРЯЖАЕТ КОЛОНИСТОВ ЗА МОРЕ", {"p0": x})
		K.PARTITION:
			var c: Country = gw.country_by_id(int(a["a"]))
			var g: Dictionary = _split_group(c)
			var dir: String = String(g.get("dir", "S"))
			a["data"]["dir"] = dir
			return Loc.mk("БЕСПОРЯДКИ В {p0:cloc}: {p1} ТРЕБУЕТ АВТОНОМИИ", {"p0": x, "p1": Loc.mk(String(DIRS[dir][0]))})
		K.COALITION:
			var names: PackedStringArray = PackedStringArray()
			for mid: Variant in a["m"]:
				names.append(_cn(int(mid)).to_upper())
			var bc: Country = gw.country_by_id(int(a["b"]))
			if bc != null and bc.is_player:
				var low: PackedStringArray = PackedStringArray()
				for mid2: Variant in a["m"]:
					low.append(_cn(int(mid2)))
				gw.say(bc, Loc.mk("Соседи сговариваются против вас: %s", [", ".join(low)]))
			return Loc.mk("ВСЕ ПРОТИВ {p0:cgen}: {p1:name} ИЩУТ СОЮЗА", {"p0": y, "p1": ", ".join(names)})
		K.BLOCS:
			return Loc.mk("ХОЛОДНАЯ ВОЙНА: {p0:name} ПРОТИВ {p1:cgen}, МИР ДЕЛИТСЯ НА БЛОКИ", {"p0": x, "p1": y})
		K.BACKSTAB:
			var bc2: Country = gw.country_by_id(int(a["b"]))
			if bc2 != null and bc2.is_player:
				gw.say(bc2, Loc.mk("Разведка: %s стягивает войска к вашей границе", [Loc.name(_cn(int(a["a"])))]))
			return Loc.mk("РАЗВЕДКА: {p0:name} СТЯГИВАЕТ ВОЙСКА К ГРАНИЦЕ {p1:cgen}", {"p0": x, "p1": y})
		K.ARMS:
			return Loc.mk("ГОНКА ВООРУЖЕНИЙ: {p0:name} И {p1:name} НАРАЩИВАЮТ АРМИИ", {"p0": x, "p1": y})
		K.TRADE:
			return Loc.mk("ТОРГОВАЯ ВОЙНА: {p0:name} ПРОТИВ {p1:cgen}", {"p0": x, "p1": y})
		K.HERMIT:
			return Loc.mk("{p0:name} ЗАКРЫВАЕТ ГРАНИЦЫ: КУРС НА ИЗОЛЯЦИЮ", {"p0": x})
		K.RISING:
			return Loc.mk("{p0:name} БРОСАЕТ ВЫЗОВ ЛИДЕРУ — {p1:name}", {"p0": x, "p1": y})
		K.PUPPETS:
			return Loc.mk("{p0:name} СТРОИТ ИМПЕРИЮ: ВАССАЛЫ И МАРИОНЕТКИ", {"p0": x})
	return ""


func _end_text(a: Dictionary, why: String) -> Variant:
	var x: String = _cn(int(a["a"])).to_upper()
	var y: String = _cn(int(a["b"])).to_upper() if int(a["b"]) > 0 else ""
	if why == "gone":
		return ""
	match int(a["k"]):
		K.COLONIAL:
			return Loc.mk("КОЛОНИАЛЬНАЯ ГОНКА {p0:cgen} ЗАКОНЧЕНА: КОЛОНИЙ {p1}", {"p0": x, "p1": int(a["data"].get("col", 0))})
		K.PARTITION:
			if why == "suppressed" or not bool(a["climax"]):
				return Loc.mk("{p0:name} ПОДАВИЛА БЕСПОРЯДКИ: СТРАНА ЕДИНА", {"p0": x})
			if why == "reunited":
				return Loc.mk("{p0:name} ВОССОЕДИНЕНА", {"p0": _base_name(_cn(int(a["a"]))).to_upper()})
			return Loc.mk("{p0:name} И {p1:name}: ХОЛОДНЫЙ МИР", {"p0": x, "p1": y})
		K.COALITION:
			return Loc.mk("КОАЛИЦИЯ ПРОТИВ {p0:cgen} РАСПАЛАСЬ", {"p0": y})
		K.BLOCS:
			if why == "hot":
				return Loc.mk("ХОЛОДНАЯ ВОЙНА СТАЛА ГОРЯЧЕЙ: {p0:name} — {p1:name}", {"p0": x, "p1": y})
			return Loc.mk("РАЗРЯДКА: {p0:name} И {p1:name}", {"p0": x, "p1": y})
		K.BACKSTAB:
			if why == "strike":
				return Loc.mk("УДАР В СПИНУ: {p0:name} НАПАЛА НА {p1:cacc}", {"p0": x, "p1": y})
			return Loc.mk("{p0:name} ОТВОДИТ ВОЙСКА ОТ ГРАНИЦЫ {p1:cgen}", {"p0": x, "p1": y})
		K.ARMS:
			if why == "war":
				return Loc.mk("ГОНКА ВООРУЖЕНИЙ {p0:cgen} И {p1:cgen} ЗАКОНЧИЛАСЬ ВОЙНОЙ", {"p0": x, "p1": y})
			return Loc.mk("{p0:name} И {p1:name} СВОРАЧИВАЮТ ГОНКУ ВООРУЖЕНИЙ", {"p0": x, "p1": y})
		K.TRADE:
			return Loc.mk("САНКЦИОННАЯ ВОЙНА {p0:cgen} И {p1:cgen} УТИХАЕТ", {"p0": x, "p1": y})
		K.HERMIT:
			if why == "war":
				return Loc.mk("ИЗОЛЯЦИЯ {p0:cgen} ПРЕРВАНА ВОЙНОЙ", {"p0": x})
			return Loc.mk("{p0:name} СНОВА ОТКРЫТА МИРУ", {"p0": x})
		K.RISING:
			if why == "overtook":
				return Loc.mk("СМЕНА ЛИДЕРА: {p0:name} ОБОШЛА {p1:cacc}", {"p0": x, "p1": y})
			if why == "war":
				return Loc.mk("ВЫЗОВ ПРИНЯТ: {p0:name} И {p1:name} ВОЮЮТ ЗА ПЕРВЕНСТВО", {"p0": x, "p1": y})
			return Loc.mk("ВЫЗОВ {p0:cgen} ЗАХЛЕБНУЛСЯ", {"p0": x})
		K.PUPPETS:
			return Loc.mk("ИМПЕРИЯ {p0:cgen} ТЕРЯЕТ ХВАТКУ", {"p0": x})
	return ""






func _case_gen(nm: String) -> String:
	return Loc.ccase(nm, "cgen")


func _case_loc(nm: String) -> String:
	return Loc.ccase(nm, "cloc")


func _case_acc(nm: String) -> String:
	return Loc.ccase(nm, "cacc")


func _case_ins(nm: String) -> String:
	return Loc.ccase(nm, "cins")


func _climax(a: Dictionary, now: float) -> void :
	var dp: Diplomacy = gw.diplo
	var x: int = int(a["a"])
	var y: int = int(a["b"])
	_count("climax_" + String(KINDS[int(a["k"])]))
	match int(a["k"]):
		K.PARTITION:
			_partition(a, now)
		K.COALITION:
			var m: Array = a["m"]
			var signed: int = 0
			for i in m.size():
				for j in range(i + 1, m.size()):
					var u: int = int(m[i])
					var v: int = int(m[j])
					if not _alive(u) or not _alive(v) or dp.at_war(u, v) or dp.get_rel(u, v) == Diplomacy.Rel.TRUCE or _rel(u, v) < -15:
						continue
					if dp.has_treaty(u, v, "defense") or dp.treaty_covered(u, v, "defense") != "" or dp.embargo_between(u, v):
						continue
					dp._sign(u, v, "defense", true)
					signed += 1
			var names: PackedStringArray = PackedStringArray()
			for mid: Variant in m:
				names.append(_cn(int(mid)).to_upper())
			_count("coalition_formed")
			_say(a, Loc.mk("КОАЛИЦИЯ СЛОЖИЛАСЬ: {p0:name} ПРОТИВ {p1:cgen}{p2}", {"p0": ", ".join(names), "p1": _cn(y).to_upper(), "p2": Loc.mk(" — ОБОРОННЫХ ПАКТОВ %d", [signed]) if signed > 0 else ""}))
			var bc: Country = gw.country_by_id(y)
			if bc != null and bc.is_player:
				var low2: PackedStringArray = PackedStringArray()
				for mid3: Variant in m:
					low2.append(_cn(int(mid3)))
				gw.say(bc, Loc.mk("Против вас сложилась коалиция: %s", [", ".join(low2)]))
		K.BLOCS:
			var l1: PackedStringArray = PackedStringArray()
			var l2: PackedStringArray = PackedStringArray()
			for e: Array in a["side"]:
				if int(e[0]) == x or int(e[0]) == y:
					continue
				if int(e[1]) == 1:
					l1.append(_cn(int(e[0])).to_upper())
				elif int(e[1]) == -1:
					l2.append(_cn(int(e[0])).to_upper())
			_say(a, Loc.mk("ЖЕЛЕЗНЫЙ ЗАНАВЕС: {p0:name}{p1} ПРОТИВ {p2:cgen}{p3}", {"p0": _cn(x).to_upper(), "p1": (" (" + ", ".join(l1) + ")") if not l1.is_empty() else "", "p2": _cn(y).to_upper(), "p3": (" (" + ", ".join(l2) + ")") if not l2.is_empty() else ""}))

			for hd: Array in [[x, 1], [y, -1]]:
				var h: int = int(hd[0])
				var best: int = -1
				var br: int = 24
				for e2: Array in a["side"]:
					var o: int = int(e2[0])
					if int(e2[1]) != int(hd[1]) or o == h or not _alive(o) or dp.at_war(h, o) or dp.allied(h, o) or dp.grudge(h, o):
						continue
					var oc: Country = gw.country_by_id(o)
					if oc == null or oc.is_player or gw.country_by_id(h).is_player or dp.ally_conflict(h, o) != "":
						continue
					if _rel(h, o) > br:
						br = _rel(h, o)
						best = o
				if best > 0:
					dp._sign(h, best, "alliance")
					_count("bloc_unions")
		K.TRADE:
			var n: int = 0
			var xc: Country = gw.country_by_id(x)
			if xc != null and not xc.is_player and not dp.embargoed(x, y) and _rel(x, y) < 0:
				dp.set_embargo(x, y, true)
				n += 1
			for pid: Variant in a["m"]:
				var pc: Country = gw.country_by_id(int(pid))
				if n >= 3 or pc == null or pc.is_player or dp.embargoed(int(pid), y) or _rel(int(pid), y) >= 0:
					continue
				dp.set_embargo(int(pid), y, true)
				n += 1
			var yc: Country = gw.country_by_id(y)
			if yc != null and not yc.is_player and not dp.embargoed(y, x) and _rel(y, x) < -10:
				dp.set_embargo(y, x, true)
			_count("sanctions", n)
		K.HERMIT:
			var cut: int = 0
			for o: Country in _alive_l():
				if cut >= 2 or o.id == x or o.is_player:
					continue
				if dp.has_treaty(x, o.id, "visa") and _rel(x, o.id) < 40:
					dp.cancel_treaty(x, o.id, "visa")
					cut += 1
		K.RISING:
			_say(a, Loc.mk("{p0:name} НАРАВНЕ С {p1:cins}: БОРЬБА ЗА ПЕРВЕНСТВО", {"p0": _cn(x).to_upper(), "p1": _cn(y).to_upper()}) if _s(x) >= _s(y) * 0.9 else "")
		K.ARMS:
			_say(a, Loc.mk("{p0:name} И {p1:name}: АРМИИ У ГРАНИЦЫ", {"p0": _cn(x).to_upper(), "p1": _cn(y).to_upper()}))



func _watch(a: Dictionary, now: float) -> String:
	var dp: Diplomacy = gw.diplo
	var x: int = int(a["a"])
	var y: int = int(a["b"])
	var data: Dictionary = a["data"]
	match int(a["k"]):
		K.COLONIAL:
			var c: Country = gw.country_by_id(x)
			var n: int = gw.naval.colony_count(c) if gw.naval != null else 0
			if not data.has("col0"):
				data["col0"] = n
			var got: int = n - int(data["col0"])
			if got > int(data.get("col", 0)):
				data["col"] = got
				var near: bool = y > 0 and _colony_near(x, y)
				if near:
					data["near"] = int(data.get("near", 0)) + 1
				if bool(a["shown"]):
					_say(a, (Loc.mk("КОЛОНИИ {p0:cgen} У БЕРЕГОВ {p1:cgen}", {"p0": _cn(x).to_upper(), "p1": _cn(y).to_upper()})) if near else (Loc.mk("{p0:name} ОСНОВЫВАЕТ КОЛОНИЮ ЗА МОРЕМ", {"p0": _cn(x).to_upper()})))
				_count("colonies")
			if gw.naval != null and n >= gw.naval.colony_cap(c) and got > 0:
				return "full"
		K.PARTITION:
			if not bool(a["climax"]):
				if bool(a["shown"]) and not bool(data.get("mid", false)) and float(a["p"]) >= 0.6:
					data["mid"] = true
					_say(a, Loc.mk("{p0:name} НА ГРАНИ РАСКОЛА: {p1} ГОТОВИТ РЕФЕРЕНДУМ", {"p0": _cn(x).to_upper(), "p1": Loc.mk(String(DIRS[String(data.get("dir", "S"))][0]))}))
			else:
				if String(data.get("over", "")) == "suppressed":
					return "suppressed"
				if y > 0 and dp.at_war(x, y) and not bool(data.get("war", false)):
					data["war"] = true
					_say(a, Loc.mk("ВОЙНА ЗА ОБЪЕДИНЕНИЕ: {p0:name} — {p1:name}", {"p0": _cn(x).to_upper(), "p1": _cn(y).to_upper()}))
		K.BLOCS:
			var seen: Array = data.get("proxy", [])
			for e: Array in a["side"]:
				var u: int = int(e[0])
				var su: int = int(e[1])
				if su != 1:
					continue
				for f: Array in a["side"]:
					var v: int = int(f[0])
					if int(f[1]) != -1 or u == x or v == y or not dp.at_war(u, v):
						continue
					if float(dp.since.get(Diplomacy.key(u, v), -1000000000.0)) < float(a["t0"]):
						continue
					var kk: String = "%d>%d" % [u, v]
					if seen.has(kk):
						continue
					seen.append(kk)
					_count("proxy_wars")
					if bool(a["shown"]) and now >= float(data.get("proxy_t", -1000000000.0)):
						data["proxy_t"] = now + 120.0
						_say(a, Loc.mk("ВОЙНА ЧУЖИМИ РУКАМИ: {p0:name} (БЛОК {p1:cgen}) — {p2:name} (БЛОК {p3:cgen})", {"p0": _cn(u).to_upper(), "p1": _cn(x).to_upper(), "p2": _cn(v).to_upper(), "p3": _cn(y).to_upper()}))
			data["proxy"] = seen
		K.BACKSTAB:
			if dp.at_war(x, y):
				if int(dp.war_by.get(Diplomacy.key(x, y), 0)) == x:
					_count("backstab_strike")
					return "strike"
				return "war"
		K.ARMS:
			if dp.at_war(x, y):
				return "war"
		K.HERMIT:
			var hc: Country = gw.country_by_id(x)
			if hc != null and not hc.at_war.is_empty():
				return "war"
		K.RISING:
			if _s(x) > _s(y) * 1.05 and _rank(x) == 1:
				return "overtook"
			if dp.at_war(x, y):
				return "war"
		K.PUPPETS:
			var ns: int = dp.subjects_of(x).size()
			if not data.has("ns"):
				data["ns"] = ns
			if ns > int(data["ns"]) and bool(a["shown"]):
				var subs: Array = dp.subjects_of(x)
				var sid: int = int(subs[subs.size() - 1])
				_say(a, Loc.mk("ИМПЕРИЯ {p0:cgen} РАСТЁТ: {p1:name} — {p2}", {"p0": _cn(x).to_upper(), "p1": _cn(sid).to_upper(), "p2": Loc.mk(String(Diplomacy.SUBJ_NAMES.get(dp.subject_kind(sid), "ВАССАЛ")))}))
			data["ns"] = ns
	return ""


func _colony_near(x: int, y: int) -> bool:
	var yc: Country = gw.country_by_id(y)
	if yc == null or gw.naval == null:
		return false
	for cid: Variant in gw.naval.colonies.keys():
		var ci: int = int(cid)
		if ci < 0 or ci >= gw.cities.size() or gw.cities[ci].country_id != x:
			continue
		for yid in yc.city_ids:
			var dv: Vector2i = gw.cities[ci].center - gw.cities[yid].center
			if maxi(absi(dv.x), absi(dv.y)) < 170:
				return true
	return false




func _cid(c: Variant) -> int:
	if c is Country:
		return (c as Country).id
	return int(c) if c != null else -1


func _alive(id: int) -> bool:
	var c: Country = gw.country_by_id(id)
	return c != null and not c.eliminated and c.capital_id >= 0


func _alive_l() -> Array[Country]:
	var out: Array[Country] = []
	for c: Country in gw.countries:
		if not c.eliminated and c.capital_id >= 0:
			out.append(c)
	return out


func _bots() -> Array[Country]:
	var out: Array[Country] = []
	for c: Country in _alive_l():
		if not c.is_player:
			out.append(c)
	return out


func _top() -> Country:
	var best: Country = null
	for c: Country in _alive_l():
		if best == null or _s(c.id) > _s(best.id):
			best = c
	return best


func _rank(id: int) -> int:
	var r: int = 1
	var s: float = _s(id)
	for c: Country in _alive_l():
		if c.id != id and _s(c.id) > s:
			r += 1
	return r


func _earn_rank(id: int) -> int:
	var me: Country = gw.country_by_id(id)
	if me == null:
		return 99
	var r: int = 1
	for c: Country in _alive_l():
		if c.id != id and c.earned > me.earned:
			r += 1
	return r


func _s(id: int) -> float:
	return gw.diplo.strength(id)


func _wp(id: int) -> float:
	return gw.diplo.war_power(id)


func _rel(a: int, b: int) -> int:
	return gw.diplo.relation(a, b)


func _at_war(a: int, b: int) -> bool:
	return gw.diplo.at_war(a, b)


func _at_war_of(id: int) -> Array:
	var c: Country = gw.country_by_id(id)
	return c.at_war.keys() if c != null else []


func _pair(a: int, b: int, x: int, y: int) -> bool:
	return (a == x and b == y) or (a == y and b == x)


func _pid(id: int) -> String:
	var c: Country = gw.country_by_id(id)
	if c == null or c.is_player or gw.ai == null:
		return ""
	return String(gw.ai.persona_of(c).get("id", ""))


func _tr(id: int, key: String) -> float:
	var c: Country = gw.country_by_id(id)
	if c == null or gw.ai == null:
		return 0.5
	return float(gw.ai.persona_of(c).get(key, 0.5))


func _rival(a: int, b: int) -> bool:
	return gw.pstat != null and gw.pstat.is_rival(a, b)


func _state(id: int) -> int:
	return gw.pstat.state_of(id) if gw.pstat != null else 0


func _tier(id: int) -> int:
	return gw.pstat.status_of(id) if gw.pstat != null else 0


func _same_ally(a: int, b: int) -> bool:
	return gw.diplo.ally != null and gw.diplo.ally.same(a, b)


func _cn(id: int) -> String:
	var c: Country = gw.country_by_id(id)
	return c.name if c != null else "?"



func _ago(id: int, ago: float) -> Array:
	var h: Array = hist.get(id, [])
	if h.is_empty():
		return []
	var want: float = gw.game_time - ago
	var pick: Array = h[0]
	for e: Array in h:
		if float(e[0]) <= want:
			pick = e
	return pick


func _cities_ago(id: int, ago: float) -> int:
	var e: Array = _ago(id, ago)
	var c: Country = gw.country_by_id(id)
	return int(e[2]) if not e.is_empty() else (c.city_ids.size() if c != null else 0)


func _captured_ago(id: int, ago: float) -> int:
	var e: Array = _ago(id, ago)
	var c: Country = gw.country_by_id(id)
	if e.is_empty() or c == null:
		return 0
	return maxi(0, c.captured - int(e[4]))


func _growth(id: int, ago: float) -> float:
	var e: Array = _ago(id, ago)
	if e.is_empty() or gw.game_time - float(e[0]) < ago * 0.5:
		return 1.0
	return _s(id) / maxf(1.0, float(e[1]))


func _wp_growth(id: int, ago: float) -> float:
	var e: Array = _ago(id, ago)
	if e.is_empty() or gw.game_time - float(e[0]) < ago * 0.5:
		return 1.0
	return _wp(id) / maxf(1.0, float(e[3]))



func _aggr_wars(id: int, t0: float) -> int:
	var n: int = 0
	for e: Array in gw.diplo.wars_log:
		if float(e[0]) < t0 or int(e[1]) != id:
			continue
		var why: String = String(e[3])
		var own: bool = true
		for s: String in NOT_AGGR:
			if why.begins_with(s):
				own = false
		if own:
			n += 1
	return n


func _count(k: String, n: int = 1) -> void :
	counters[k] = int(counters.get(k, 0)) + n











const EV_KINDS: Array = ["war", "capital", "city", "power", "crisis", "subject", "alliance", "pact", "embargo", "sky", "peace", "gone", "rival", "conf"]
const EV_K0: int = 100
const EV_FIRST: float = 150.0
const EV_REPEAT: float = 900.0
const EV_LATE: float = 1500.0
var ev: Dictionary = {}


func _ev_key_pair(k: String) -> Array:
	var p: PackedStringArray = k.split(":")
	return [int(p[0]), int(p[1])] if p.size() >= 2 else [0, 0]



func _ev_snap() -> Dictionary:
	var dp: Diplomacy = gw.diplo
	var s: Dictionary = {}
	s["wl"] = dp.wars_log.size()
	var co: Array = []
	for ct: City in gw.cities:
		co.append(ct.country_id)
	s["co"] = co
	var cap: Dictionary = {}
	var tier: Dictionary = {}
	var st: Dictionary = {}
	var elim: Array = []
	for c: Country in gw.countries:
		var k: String = str(c.id)
		cap[k] = c.capital_id
		tier[k] = _tier(c.id)
		st[k] = _state(c.id)
		if c.eliminated:
			elim.append(c.id)
	s["cap"] = cap
	s["tier"] = tier
	s["st"] = st
	s["elim"] = elim
	var war: Dictionary = {}
	var uni: Array = []
	for k2: String in dp.rel:
		var r: int = int(dp.rel[k2])
		if r == Diplomacy.Rel.WAR:
			war[k2] = float(dp.since.get(k2, gw.game_time))
		elif r == Diplomacy.Rel.ALLIANCE:
			uni.append(k2)
	s["war"] = war
	s["uni"] = uni
	var tre: Array = []
	for k3: String in dp.treaties:
		for kind: String in ["nap", "defense"]:
			if (dp.treaties[k3] as Dictionary).has(kind):
				tre.append(k3 + ":" + kind)
	s["tre"] = tre
	s["emb"] = dp.embargo.keys()
	var snc: Array = []
	var trd: Object = gw.econ.get("trd") as Object if gw.econ != null else null
	if trd != null and trd.get("sanct") != null:
		for k4: String in (trd.get("sanct") as Dictionary):
			if not ((trd.get("sanct") as Dictionary)[k4] as Dictionary).is_empty():
				snc.append(k4)
	s["snc"] = snc
	var sky: Array = []
	if dp.get("sky") != null and dp.sky.get("sky") != null:
		for k5: Variant in (dp.sky.sky as Dictionary):
			sky.append(int(k5))
	s["sky"] = sky
	var al: Array = []
	if dp.ally != null:
		for k6: Variant in dp.ally.list:
			al.append(int(k6))
	s["al"] = al
	var cf: Array = []
	if dp.get("conf") != null and dp.conf != null:
		for c7: Dictionary in dp.conf.active:
			cf.append(int(c7.get("def", 0)))
	s["cf"] = cf
	return s


func _events(now: float) -> void :
	var dp: Diplomacy = gw.diplo
	if dp == null:
		return
	var cur: Dictionary = _ev_snap()
	if not bool(ev.get("on", false)):
		ev = {"on": true, "s": cur, "q": [], "seen": {}, "first": {}, "next": EV_FIRST, "last": -999.0, "embw": [], "top": ""}
		return
	var old: Dictionary = ev["s"]
	var first: Dictionary = ev["first"]

	var wl0: int = int(old["wl"])
	for i in range(wl0, dp.wars_log.size()):
		var e: Array = dp.wars_log[i]
		var a: int = int(e[1])
		var b: int = int(e[2])
		if Loc.src(e[3]) in ["в поддержку", "призыв союзника"]:
			continue
		var big: bool = maxi(_tier(a), _tier(b)) >= 3
		if not first.has("war"):
			first["war"] = true
			_ev_add(90, "war", "war:%d:%d" % [mini(a, b), maxi(a, b)], Loc.mk("ПЕРВАЯ ВОЙНА: {p0:name} НАПАДАЕТ НА {p1:cacc}", {"p0": _cn(a).to_upper(), "p1": _cn(b).to_upper()}), a, b)
		else:
			_ev_add(55 + (12 if big else 0), "war", "war:%d:%d" % [mini(a, b), maxi(a, b)], Loc.mk("ВОЙНА: {p0:name} НАПАДАЕТ НА {p1:cacc}", {"p0": _cn(a).to_upper(), "p1": _cn(b).to_upper()}), a, b)

	var co: Array = old["co"]
	var caps: Dictionary = old["cap"]
	var tier0: Dictionary = old["tier"]
	for ci in mini(co.size(), gw.cities.size()):
		var ct: City = gw.cities[ci]
		var o: int = int(co[ci])
		var n: int = ct.country_id
		if o == n or o <= 0 or n <= 0 or not tier0.has(str(n)) or now - ct.war_t > EVAL_DT * 4.0:
			continue
		var cn: String = ct.name.to_upper()
		var oc: Country = gw.country_by_id(o)
		if oc != null and oc.eliminated:
			continue
		if int(caps.get(str(o), -1)) == ct.id:
			_ev_add(95, "capital", "cap:%d" % o, Loc.mk("ПАЛА СТОЛИЦА {p0:cgen} — {p1:name}: ГОРОД ВЗЯЛИ ВОЙСКА {p2:cgen}", {"p0": _cn(o).to_upper(), "p1": cn, "p2": _cn(n).to_upper()}), n, o)
		elif not first.has("city"):
			first["city"] = true
			_ev_add(70, "city", "city:%d" % ct.id, Loc.mk("ПЕРВЫЙ ГОРОД ВЗЯТ С БОЮ: {p0:name} ОТНИМАЕТ У {p1:cgen} ГОРОД {p2:name}", {"p0": _cn(n).to_upper(), "p1": _cn(o).to_upper(), "p2": cn}), n, o)
		elif ct.kind == City.Kind.TOWN and ct.level >= 2:
			_ev_add(52, "city", "city:%d" % ct.id, Loc.mk("{p0:name} ОТНИМАЕТ У {p1:cgen} ГОРОД {p2:name}", {"p0": _cn(n).to_upper(), "p1": _cn(o).to_upper(), "p2": cn}), n, o)

	var elim0: Array = old["elim"]
	var st0: Dictionary = old["st"]
	for c: Country in gw.countries:
		var k: String = str(c.id)
		if not tier0.has(k):
			continue
		var nm: String = c.name.to_upper()
		if c.eliminated:
			if not elim0.has(c.id):
				var by: int = 0
				var cap0: int = int(caps.get(k, -1))
				if cap0 >= 0 and cap0 < gw.cities.size():
					by = gw.cities[cap0].country_id
				_ev_add(100, "gone", "gone:%d" % c.id, (Loc.mk("{p0:name} ПЕРЕСТАЁТ СУЩЕСТВОВАТЬ: СТОЛИЦУ ВЗЯЛИ ВОЙСКА {p1:cgen}", {"p0": nm, "p1": _cn(by).to_upper()})) if by > 0 and by != c.id and _alive(by) else (Loc.mk("{p0:name} ПЕРЕСТАЁТ СУЩЕСТВОВАТЬ", {"p0": nm})), by if by != c.id else 0, c.id)
			continue
		var t0: int = int(tier0[k])
		var t1: int = _tier(c.id)
		if t1 > t0 and t1 >= 2:
			var fk: String = "tier%d" % t1
			var tn: String = String(PowerStatus.TIER_NAMES[t1]) if t1 < PowerStatus.TIER_NAMES.size() else "?"
			var ti: String = String(PowerStatus.TIER_INS[t1]) if t1 < PowerStatus.TIER_INS.size() else "?"
			if not first.has(fk):
				first[fk] = true
				_ev_add(40 + 15 * maxi(0, t1 - 2), "power", "tier:%d:%d" % [c.id, t1], Loc.mk("ПЕРВАЯ {p0} МИРА: {p1:name}", {"p0": tn, "p1": nm}), c.id, 0)
			elif t1 >= 3:
				_ev_add(45 + 10 * (t1 - 3), "power", "tier:%d:%d" % [c.id, t1], Loc.mk("{p0:name} СТАНОВИТСЯ {p1}", {"p0": nm, "p1": ti}), c.id, 0)
		var s0: int = int(st0.get(k, 0))
		var s1: int = _state(c.id)
		if s1 != s0 and s1 > 0:
			var over: int = dp.subject_of(c.id)
			match s1:
				1:
					_ev_add(42, "crisis", "st:%d:1" % c.id, Loc.mk("{p0:name} ОСЛАБЛЕНА: ПОТЕРИ ГОРОДОВ И АРМИИ", {"p0": nm}), c.id, 0)
				2:
					_ev_add(58, "crisis", "st:%d:2" % c.id, Loc.mk("{p0:name} — ИЗГОЙ: САНКЦИИ СО ВСЕХ СТОРОН", {"p0": nm}), c.id, 0)
				3:
					_ev_add(72, "crisis", "st:%d:3" % c.id, Loc.mk("{p0:name} НА ГРАНИ РАСПАДА", {"p0": nm}), c.id, 0)
				4, 5:
					if over > 0:
						_ev_add(66, "subject", "st:%d:%d" % [c.id, s1], Loc.mk("{p0:name} СТАНОВИТСЯ {p1} {p2:cgen}", {"p0": nm, "p1": Loc.mk("ВАССАЛОМ") if s1 == 4 else Loc.mk("МАРИОНЕТКОЙ"), "p2": _cn(over).to_upper()}), over, c.id)

	var uni0: Array = old["uni"]
	for k8: String in cur["uni"]:
		if not uni0.has(k8):
			var pr: Array = _ev_key_pair(k8)
			if not first.has("uni"):
				first["uni"] = true
				_ev_add(48, "alliance", "uni:" + k8, Loc.mk("ПЕРВЫЙ СОЮЗ МИРА: {p0:name} И {p1:name}", {"p0": _cn(pr[0]).to_upper(), "p1": _cn(pr[1]).to_upper()}), pr[0], pr[1])
			else:
				_ev_add(28, "alliance", "uni:" + k8, Loc.mk("СОЮЗ: {p0:name} И {p1:name}", {"p0": _cn(pr[0]).to_upper(), "p1": _cn(pr[1]).to_upper()}), pr[0], pr[1])
	var tre0: Array = old["tre"]
	for k9: String in cur["tre"]:
		if tre0.has(k9):
			continue
		var p9: PackedStringArray = k9.split(":")
		if p9.size() < 3:
			continue
		var a9: int = int(p9[0])
		var b9: int = int(p9[1])
		var fk9: String = "t_" + p9[2]
		if not first.has(fk9):
			first[fk9] = true
			_ev_add(36 if p9[2] == "nap" else 40, "pact", "tre:" + k9, Loc.mk("{p0}: {p1:name} И {p2:name}", {"p0": Loc.mk("ПЕРВЫЙ ПАКТ О НЕНАПАДЕНИИ") if p9[2] == "nap" else Loc.mk("ПЕРВЫЙ ОБОРОННЫЙ ПАКТ"), "p1": _cn(a9).to_upper(), "p2": _cn(b9).to_upper()}), a9, b9)
		elif p9[2] == "defense":
			_ev_add(24, "pact", "tre:" + k9, Loc.mk("ОБОРОННЫЙ ПАКТ: {p0:name} И {p1:name}", {"p0": _cn(a9).to_upper(), "p1": _cn(b9).to_upper()}), a9, b9)

	var war0: Dictionary = old["war"]
	var war1: Dictionary = cur["war"]
	for k10: String in war0:
		if war1.has(k10):
			continue
		var p10: Array = _ev_key_pair(k10)
		var dur: float = now - float(war0[k10])
		if dur >= 420.0 and _alive(p10[0]) and _alive(p10[1]):
			_ev_add(46, "peace", "peace:" + k10, Loc.mk("{p0:name} И {p1:name} ПРЕКРАЩАЮТ ОГОНЬ ПОСЛЕ {p2} МИН ВОЙНЫ", {"p0": _cn(p10[0]).to_upper(), "p1": _cn(p10[1]).to_upper(), "p2": int(dur / 60.0)}), p10[0], p10[1])

	var embw: Array = ev["embw"]
	for pair: Array in [[old["emb"], cur["emb"]], [old["snc"], cur["snc"]]]:
		for k11: Variant in pair[1]:
			if (pair[0] as Array).has(k11):
				continue
			var p11: PackedStringArray = String(k11).split(">")
			if p11.size() < 2:
				continue
			var f11: int = int(p11[0])
			var t11: int = int(p11[1])
			embw.append([now, t11, f11])
			if not first.has("emb"):
				first["emb"] = true
				_ev_add(34, "embargo", "emb1", Loc.mk("ПЕРВЫЕ САНКЦИИ: {p0:name} ПРОТИВ {p1:cgen}", {"p0": _cn(f11).to_upper(), "p1": _cn(t11).to_upper()}), f11, t11)
	for i2 in range(embw.size() - 1, -1, -1):
		if now - float(embw[i2][0]) > 600.0:
			embw.remove_at(i2)
	var by_t: Dictionary = {}
	for e12: Array in embw:
		var tg: int = int(e12[1])
		if not by_t.has(tg):
			by_t[tg] = []
		if not (by_t[tg] as Array).has(int(e12[2])):
			(by_t[tg] as Array).append(int(e12[2]))
	var tgs: Array = by_t.keys()
	tgs.sort()
	for tg2: int in tgs:
		var nf: int = (by_t[tg2] as Array).size()
		if nf >= 2 and _alive(tg2):
			_ev_add(52 + 5 * mini(nf, 5), "embargo", "wave:%d" % tg2, Loc.mk("ВОЛНА САНКЦИЙ ПРОТИВ {p0:cgen}: {p1} {p2}", {"p0": _cn(tg2).to_upper(), "p1": nf, "p2": Loc.mk(Loc.pick(nf, "СТРАНА", "СТРАНЫ", "СТРАН"))}), int((by_t[tg2] as Array)[0]), tg2)

	var sky0: Array = old["sky"]
	for k13: Variant in cur["sky"]:
		if not sky0.has(k13):
			var cc: int = int(k13) / 4096
			var hh: int = int(k13) % 4096
			_ev_add(54, "sky", "sky:%d" % int(k13), Loc.mk("{p0:name} ЗАКРЫВАЕТ НЕБО НАД {p1:cins}", {"p0": _cn(cc).to_upper(), "p1": _cn(hh).to_upper()}), cc, hh)

	var al0: Array = old["al"]
	for k14: Variant in cur["al"]:
		if al0.has(k14) or dp.ally == null:
			continue
		var ad: Dictionary = dp.ally.get_a(int(k14))
		if ad.is_empty():
			continue
		var names: PackedStringArray = PackedStringArray()
		var mm: Array = ad.get("members", [])
		for mid: Variant in mm:
			names.append(_cn(int(mid)).to_upper())
		_ev_add(70, "alliance", "al:%d" % int(k14), Loc.mk("ОСНОВАН АЛЬЯНС «{p0}»: {p1:name}", {"p0": String(ad.get("name", "?")).to_upper(), "p1": ", ".join(names)}), int(mm[0]) if mm.size() > 0 else 0, int(mm[1]) if mm.size() > 1 else 0)

	var cf0: Array = old["cf"]
	for d15: Variant in cur["cf"]:
		if not cf0.has(d15) and int(d15) > 0:
			_ev_add(75, "conf", "conf:%d" % int(d15), Loc.mk("МИРНАЯ КОНФЕРЕНЦИЯ: ПОБЕДИТЕЛИ ДЕЛЯТ ЗЕМЛИ {p0:cgen}", {"p0": _cn(int(d15)).to_upper()}), 0, int(d15))

	if gw.pstat != null and now >= 180.0:
		var lead: int = 0
		for c16: Country in _alive_l():
			if gw.pstat.rank_of(c16.id) == 1:
				lead = c16.id
		var rv: int = gw.pstat.rival_of(lead) if lead > 0 else 0
		if lead > 0 and rv > 0 and _alive(rv):
			var tk: String = "%d:%d" % [mini(lead, rv), maxi(lead, rv)]
			if tk != String(ev["top"]):
				var was: String = String(ev["top"])
				ev["top"] = tk
				_ev_add(44 if was == "" else 38, "rival", "rival:" + tk, Loc.mk("{p0}: {p1:name} ПРОТИВ {p2:cgen}", {"p0": Loc.mk("ГЛАВНОЕ СОПЕРНИЧЕСТВО МИРА") if was == "" else Loc.mk("НОВОЕ ГЛАВНОЕ СОПЕРНИЧЕСТВО"), "p1": _cn(lead).to_upper(), "p2": _cn(rv).to_upper()}), lead, rv)
	ev["s"] = cur
	_ev_publish(now)


func _ev_add(score: int, kind: String, key: String, text: Variant, a: int, b: int) -> void :
	var seen: Dictionary = ev["seen"]
	if seen.has(key) and gw.game_time - float(seen[key]) < EV_REPEAT:
		return
	var q: Array = ev["q"]
	for e: Array in q:
		if String(e[2]) == key:
			e[0] = maxi(int(e[0]), score)
			e[3] = text
			return
	q.append([score, gw.game_time, key, text, EV_KINDS.find(kind), a, b])
	_count("ev_" + kind)


func _ev_publish(now: float) -> void :
	var q: Array = ev["q"]
	for i in range(q.size() - 1, -1, -1):
		var sc: int = int(q[i][0])
		var ttl: float = 300.0 if sc < 50 else (600.0 if sc < 80 else 1200.0)
		if now - float(q[i][1]) > ttl:
			q.remove_at(i)
			_count("ev_expired")
	if q.is_empty() or now < EV_FIRST:
		return
	var bi: int = 0
	for i2 in q.size():
		var x: Array = q[i2]
		var y: Array = q[bi]
		if int(x[0]) > int(y[0]) or (int(x[0]) == int(y[0]) and (float(x[1]) < float(y[1]) or (float(x[1]) == float(y[1]) and String(x[2]) < String(y[2])))):
			bi = i2
	var best: Array = q[bi]
	var urgent: bool = int(best[0]) >= 90 and now - float(ev["last"]) >= 45.0
	if now < float(ev["next"]) and not urgent:
		return
	q.remove_at(bi)
	(ev["seen"] as Dictionary)[String(best[2])] = now
	var seen: Dictionary = ev["seen"]
	for k: Variant in seen.keys():
		if now - float(seen[k]) > EV_REPEAT:
			seen.erase(k)
	chron.append([now, EV_K0 + int(best[4]), best[3] if Loc.is_msg(best[3]) else String(best[3]), int(best[5]), int(best[6])])
	while chron.size() > 60:
		chron.pop_front()
	_count("ev_news")
	ev["last"] = now
	var h: int = absi(Hash32.h2(int(now), chron.size(), 9131))
	ev["next"] = now + ((80.0 + float(h % 50)) if now >= EV_LATE else (170.0 + float(h % 80)))


func _ev_save() -> Dictionary:
	return ev.duplicate(true)


func _ev_load(d: Dictionary) -> void :
	ev = {}
	if d.is_empty() or not bool(d.get("on", false)):
		return
	ev = d.duplicate(true)
	ev["next"] = float(ev.get("next", EV_FIRST))
	ev["last"] = float(ev.get("last", -999.0))
	ev["top"] = String(ev.get("top", ""))
	var s: Dictionary = ev.get("s", {})
	s["wl"] = int(s.get("wl", 0))
	var co: Array = []
	for v: Variant in s.get("co", []):
		co.append(int(v))
	s["co"] = co
	for k: String in ["cap", "tier", "st"]:
		var m: Dictionary = {}
		var src: Dictionary = s.get(k, {})
		for kk: Variant in src:
			m[str(kk)] = int(src[kk])
		s[k] = m
	for k2: String in ["elim", "sky", "al", "cf"]:
		var a: Array = []
		for v2: Variant in s.get(k2, []):
			a.append(int(v2))
		s[k2] = a
	for k3: String in ["uni", "tre", "emb", "snc"]:
		var a3: Array = []
		for v3: Variant in s.get(k3, []):
			a3.append(String(v3))
		s[k3] = a3
	var wm: Dictionary = {}
	var w0: Dictionary = s.get("war", {})
	for k4: Variant in w0:
		wm[String(k4)] = float(w0[k4])
	s["war"] = wm
	ev["s"] = s
	var q: Array = []
	for e: Variant in ev.get("q", []):
		var r: Array = e
		q.append([int(r[0]), float(r[1]), String(r[2]), r[3] if Loc.is_msg(r[3]) else String(r[3]), int(r[4]), int(r[5]), int(r[6])])
	ev["q"] = q
	var sn: Dictionary = {}
	var s0: Dictionary = ev.get("seen", {})
	for k5: Variant in s0:
		sn[String(k5)] = float(s0[k5])
	ev["seen"] = sn
	var ew: Array = []
	for e2: Variant in ev.get("embw", []):
		ew.append([float(e2[0]), int(e2[1]), int(e2[2])])
	ev["embw"] = ew
	var fs: Dictionary = {}
	for k6: Variant in ev.get("first", {}):
		fs[String(k6)] = true
	ev["first"] = fs




func save_state() -> Dictionary:
	return {"arcs": arcs.duplicate(true), "done": done.duplicate(true), "chron": chron.duplicate(true), "cool": cool.duplicate(), 
		"hist": hist.duplicate(true), "counters": counters.duplicate(), "next_t": next_t, "hist_t": hist_t, "new_t": new_t, "next_id": next_id, 
		"ev": _ev_save()}


func load_state(d: Dictionary) -> void :
	arcs = []
	for a0: Variant in d.get("arcs", []):
		var a: Dictionary = (a0 as Dictionary).duplicate(true)
		for key: String in ["id", "k", "a", "b", "hold"]:
			a[key] = int(a.get(key, 0))
		for key2: String in ["t0", "p", "rate", "life"]:
			a[key2] = float(a.get(key2, 0.0))
		var m: Array = []
		for x: Variant in a.get("m", []):
			m.append(int(x))
		a["m"] = m
		var sd: Array = []
		for e: Variant in a.get("side", []):
			sd.append([int((e as Array)[0]), int((e as Array)[1])])
		a["side"] = sd
		if not a.has("data"):
			a["data"] = {}
		arcs.append(a)
	done = (d.get("done", []) as Array).duplicate(true)
	chron = (d.get("chron", []) as Array).duplicate(true)
	cool = (d.get("cool", {}) as Dictionary).duplicate()
	hist = {}
	var h0: Dictionary = d.get("hist", {})
	for k: Variant in h0:
		hist[int(k)] = (h0[k] as Array).duplicate(true)
	counters = (d.get("counters", {}) as Dictionary).duplicate()
	next_t = float(d.get("next_t", 0.0))
	hist_t = float(d.get("hist_t", 0.0))
	new_t = float(d.get("new_t", 0.0))
	next_id = int(d.get("next_id", 1))
	temper = []
	_ev_load(d.get("ev", {}))



func hash_nums() -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	out.append(float(arcs.size()))
	out.append(float(next_id))
	for a: Dictionary in arcs:
		for v: int in [int(a["id"]), int(a["k"]), int(a["a"]), int(a["b"]), roundi(float(a["p"]) * 1000.0), 1 if bool(a["climax"]) else 0, (a["m"] as Array).size()]:
			out.append(float(v))
	out.append(float(chron.size()))
	return out
