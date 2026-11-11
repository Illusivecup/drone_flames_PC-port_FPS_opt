class_name RankedRules
extends RefCounted






const TRUCE_S: float = 180.0
const DRAW_PCT: float = 0.03


static func active() -> bool:
	return not GameConfig.ranked.is_empty()



const _KEEP: Array = ["size_i", "map_type", "rivers_i", "lakes_i", "ore_preset", "reserves_i", "bots", "difficulty", 
	"aggression", "fog", "night", "creative", "alliances", "mp_speed", "victory"]
static var _saved: Dictionary = {}


static func save_player_cfg() -> void :
	if not _saved.is_empty():
		return
	for k: String in _KEEP:
		_saved[k] = (GameConfig as GDScript).get(k)



static func clear() -> void :
	for k: String in _saved:
		(GameConfig as GDScript).set(k, _saved[k])
	_saved = {}
	GameConfig.ranked = {}



static func apply(mode: String, settings: Dictionary) -> void :
	save_player_cfg()
	GameConfig.size_i = 0 if mode == "1v1" else 1
	GameConfig.map_type = 0
	GameConfig.rivers_i = 2
	GameConfig.lakes_i = 2
	GameConfig.ore_preset = 0
	GameConfig.reserves_i = 0
	GameConfig.bots = 0
	GameConfig.difficulty = 1
	GameConfig.aggression = 1
	GameConfig.fog = true
	GameConfig.night = true
	GameConfig.creative = false
	GameConfig.alliances = false
	GameConfig.mp_speed = 1
	GameConfig.victory = 3
	if String(settings.get("map", "default")) != "default":
		print("[Ranked] unknown map %s: the default one" % String(settings.get("map", "")))



static func seed_of(mm: String) -> int:
	return mm.sha256_text().left(8).hex_to_int() % 100000000


static func team_of(c: Country) -> int:
	if c == null or c.id < 1:
		return -1
	var t: Array = GameConfig.ranked.get("teams", [])
	return int(t[c.id - 1]) if c.id - 1 < t.size() else -1


static func my_team(gw: GameWorld) -> int:
	return team_of(gw.player)



static func capital_why(gw: GameWorld, c: Country, cell: Vector2i) -> String:
	if not active():
		return ""
	var t: int = team_of(c)
	var west: bool = cell.x < gw.data.w / 2
	if (t == 0 and not west) or (t == 1 and west):
		return Loc.t("Ставьте столицу в своей половине карты")
	return ""


static func half_of(gw: GameWorld, c: Country) -> Rect2i:
	var w2: int = gw.data.w / 2
	return Rect2i(0, 0, w2, gw.data.h) if team_of(c) == 0 else Rect2i(w2, 0, gw.data.w - w2, gw.data.h)



static func out(gw: GameWorld, c: Country) -> bool:
	if c.eliminated:
		return true
	var over: int = gw.diplo.subject_of(c.id)
	return over > 0 and team_of(gw.country_by_id(over)) != team_of(c)



static func keep_relations(gw: GameWorld, since_start: float) -> void :
	var cs: Array = gw.countries.filter( func(c: Country) -> bool: return team_of(c) >= 0 and not c.eliminated)
	for i in cs.size():
		for j in range(i + 1, cs.size()):
			var a: Country = cs[i]
			var b: Country = cs[j]
			var r: int = gw.diplo.get_rel(a.id, b.id)
			if team_of(a) == team_of(b):
				if r != Diplomacy.Rel.ALLIANCE:
					gw.diplo._set_rel(a.id, b.id, Diplomacy.Rel.ALLIANCE)
			elif since_start < TRUCE_S:
				if r != Diplomacy.Rel.TRUCE and r != Diplomacy.Rel.WAR:
					gw.diplo._set_rel(a.id, b.id, Diplomacy.Rel.TRUCE)
					gw.diplo.truce_until[Diplomacy.key(a.id, b.id)] = gw.game_time + TRUCE_S - since_start
			elif r != Diplomacy.Rel.WAR:
				gw.diplo.declare_war(a.id, b.id, "ranked")



static func verdict(gw: GameWorld, elapsed: float) -> Dictionary:
	var alive: Array = [0, 0]
	var score: Array = [0, 0]
	var have: Array = [0, 0]
	for c: Country in gw.countries:
		var t: int = team_of(c)
		if t < 0 or t > 1:
			continue
		have[t] += 1
		score[t] += c.score
		if not out(gw, c):
			alive[t] += 1
	if have[0] == 0 or have[1] == 0:
		return {"team": -2}
	if alive[0] == 0 and alive[1] == 0:
		return {"team": -1, "why": "both_out"}
	if alive[0] == 0:
		return {"team": 1, "why": "out"}
	if alive[1] == 0:
		return {"team": 0, "why": "out"}
	var limit: float = float(GameConfig.ranked.get("time_limit", 600))
	if limit <= 0.0 or elapsed < limit:
		return {"team": -2}
	if alive[0] != alive[1]:
		return {"team": 0 if alive[0] > alive[1] else 1, "why": "time_countries", "a": alive}
	var hi: float = float(maxi(score[0], score[1]))
	if hi <= 0.0 or absf(float(score[0] - score[1])) < DRAW_PCT * hi:
		return {"team": -1, "why": "time_close", "s": score}
	return {"team": 0 if score[0] > score[1] else 1, "why": "time_score", "s": score}



static func why_text(v: Dictionary, mine: int) -> String:
	var t: int = int(v.get("team", -1))
	match String(v.get("why", "")):
		"out":
			return Loc.t("ВСЕ СТРАНЫ СОПЕРНИКОВ ВЫБЫЛИ") if t == mine else Loc.t("ВАШИ СТРАНЫ ВЫБЫЛИ")
		"both_out":
			return Loc.t("ОБЕ КОМАНДЫ ВЫБЫЛИ")
		"time_countries":
			var a: Array = v.get("a", [0, 0])
			return Loc.t("ВРЕМЯ ВЫШЛО · СТРАН %d : %d") % [int(a[mine]), int(a[1 - mine])] if mine >= 0 else Loc.t("ВРЕМЯ ВЫШЛО")
		"time_score":
			var s: Array = v.get("s", [0, 0])
			return Loc.t("ВРЕМЯ ВЫШЛО · СЧЁТ %s : %s") % [Match.kilo(int(s[mine])), Match.kilo(int(s[1 - mine]))] if mine >= 0 else Loc.t("ВРЕМЯ ВЫШЛО")
		"time_close":
			return Loc.t("ВРЕМЯ ВЫШЛО · РАЗНИЦА СЧЁТА МЕНЬШЕ 3%")
	return ""



static func left_names(net: NetSession) -> Array:
	var out_n: Array = []
	for i in net.slots.size():
		if i != net.local_slot and bool(net.slots[i].get("left", false)) and not bool(net.slots[i].get("rot", false)):
			out_n.append(String(net.slots[i].get("name", "")))
	return out_n.slice(0, 5)
