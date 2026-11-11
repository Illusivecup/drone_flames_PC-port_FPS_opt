class_name Match
extends RefCounted




const DT: float = 2.0

const EARN_DIV: int = 25
const DESTROY_DIV: int = 5
const CAPTURE_PTS: int = 600

var gw: GameWorld
var started: bool = false
var start_time: float = 0.0
var ended: bool = false
var winner: int = 0
var win_team: int = -2
var verdict: Dictionary = {}
var _t: float = 0.0
var _land_swept: bool = false


func _init(world: GameWorld) -> void :
	gw = world


func start() -> void :
	started = true
	ended = false
	winner = 0
	start_time = gw.game_time


func elapsed() -> float:
	return gw.game_time - start_time if started else 0.0


func time_left() -> float:
	return maxf(0.0, GameConfig.match_limit() - elapsed())


static func city_points(k: int) -> int:
	return [150, 60, 25][k]


func update(dt: float) -> void :
	_t += dt
	if _t < DT:
		return
	_t = 0.0
	for c: Country in gw.countries:
		var pop: int = 0
		for cid in c.city_ids:
			pop += city_points(gw.cities[cid].kind)
		var ent: int = 0
		for f: Facility in gw.mil.facilities:
			if f.country_id == c.id and Economy.is_enterprise(f.kind) and gw.mil.alive(f):
				ent += 1
		c.score_eco = c.earned / EARN_DIV + pop + ent * 25
		c.score_mil = c.destroyed / DESTROY_DIV + c.captured * CAPTURE_PTS
		c.score = c.score_eco + c.score_mil
		if not c.eliminated and c.capital_id < 0 and not c.city_ids.is_empty():



			var best: int = -1
			for id2 in c.city_ids:
				if best < 0 or gw.cities[id2].kind < gw.cities[best].kind:
					best = id2
			c.capital_id = best
			gw.cities[best].kind = City.Kind.CAPITAL
		if not c.eliminated and c.city_ids.is_empty() and c.capital_id < 0 and (started or not c.is_player):
			if gw.cities.size() > 0 and _ever_had_city(c):
				c.eliminated = true
				gw.news_m(Loc.mk("%s ПЕРЕСТАЁТ СУЩЕСТВОВАТЬ", [Loc.name(c.name).to_upper()]), "alert_red")
				_cleanup(c)
	if not _land_swept:
		_land_swept = true
		for c2: Country in gw.countries:
			if c2.eliminated:
				free_land(c2.id)
	if not started or ended or gw.player == null:
		return
	if RankedRules.active():
		RankedRules.keep_relations(gw, elapsed())
		var v: Dictionary = RankedRules.verdict(gw, elapsed())
		if int(v.get("team", -2)) != -2:
			_finish_team(v)
		return
	_race_tick()
	var p: Country = gw.player
	if gw.net_driven:


		var humans_in: bool = false
		for c: Country in gw.countries:
			if c.is_player and not c.eliminated:
				humans_in = true
		if not humans_in:
			_finish(_best())
			return
	elif p.eliminated:
		_finish(_best())
		return
	if GameConfig.victory != 1 and GameConfig.match_limit() > 0.0 and elapsed() >= GameConfig.match_limit():
		_finish(_best())
		return
	match GameConfig.victory:
		0:
			for c: Country in gw.countries:
				if c.score >= GameConfig.score_target():
					_finish(c.id)
					return
		1:
			if GameConfig.time_limit() <= 0.0:

				for c: Country in gw.countries:
					if c.score >= GameConfig.score_target():
						_finish(c.id)
						return
			elif elapsed() >= GameConfig.time_limit():
				_finish(_best())
		2:
			if gw.net_driven:
				var alive: Array[Country] = []
				for c: Country in gw.countries:
					if not c.eliminated and c.capital_id >= 0:
						alive.append(c)
				if alive.size() == 1:
					_finish(alive[0].id)
				return
			var others: bool = false
			for c: Country in gw.countries:
				if c.id != p.id and not c.eliminated and c.capital_id >= 0:
					others = true
			if not others:
				_finish(p.id)






const RACE_STEPS: Array = [0.6, 0.8, 0.9]
var _race: Dictionary = {}
var _race_ready: bool = false


func _race_tick() -> void :
	if GameConfig.victory != 0:
		return
	var tgt: int = GameConfig.score_target()
	var p: Country = gw.player
	var rv: Country = _rival()
	if tgt <= 0 or p == null:
		return
	for i in RACE_STEPS.size():
		var lim: float = float(tgt) * float(RACE_STEPS[i])
		var pct: int = roundi(float(RACE_STEPS[i]) * 100.0)
		if rv != null and float(rv.score) >= lim and not _race.has("r%d" % i):
			_race["r%d" % i] = true
			if _race_ready:
				var lead: bool = p.score > rv.score
				gw.news_m(Loc.mk("ГОНКА ОЧКОВ: %s — %d%% (%s)%s", [Loc.name(rv.name).to_upper(), pct, of_target(rv.score, tgt), Loc.t(" · ЛИДЕР — ВЫ") if lead else ""]), "amber" if i == 0 else "alert_red")
				if not lead:
					gw.message.emit(Loc.msg(Loc.mk("%s: %s очков, у вас %s", [Loc.name(rv.name), of_target(rv.score, tgt), kilo(p.score)])))
		if float(p.score) >= lim and not _race.has("p%d" % i):
			_race["p%d" % i] = true
			if _race_ready:
				gw.news_m(Loc.mk("ВЫ НАБРАЛИ %d%% ОЧКОВ ДО ПОБЕДЫ (%s)", [pct, of_target(p.score, tgt)]), "grass_light")
	_race_ready = true



func _rival() -> Country:
	var best: Country = null
	for c: Country in gw.countries:
		if c.eliminated or (gw.player != null and c.id == gw.player.id):
			continue
		if best == null or c.score > best.score:
			best = c
	return best



static func kilo(n: int) -> String:
	if absi(n) < 1000:
		return str(n)
	var s: String = "%.1f" % (float(n) / 1000.0)
	if s.ends_with(".0"):
		s = s.substr(0, s.length() - 2)
	return Loc.t("%s тыс.") % [Loc.dec(s)]



static func of_target(n: int, tgt: int) -> String:
	if n >= 1000 and tgt >= 1000:
		return "%s/%s" % [kilo(n).trim_suffix(" тыс."), kilo(tgt)]
	return "%s/%s" % [kilo(n), kilo(tgt)]






func race_info() -> Dictionary:
	var p: Country = gw.player
	var tgt: int = GameConfig.score_target() if GameConfig.victory == 0 else 0
	var lead: Country = null
	var rank: int = 1
	for c: Country in gw.countries:
		if c.eliminated:
			continue
		if lead == null or c.score > lead.score:
			lead = c
		if p != null and c.id != p.id and c.score > p.score:
			rank += 1
	var rv: Country = _rival()
	var me: bool = p != null and lead != null and lead.id == p.id
	var ls: int = lead.score if lead != null else 0
	var txt: String = (Loc.t("вы лидер ") if me else Loc.t("лидер ")) + (of_target(ls, tgt) if tgt > 0 else kilo(ls))
	return {"on": tgt > 0, "target": tgt, "leader_id": lead.id if lead != null else -1, "leader_name": lead.name if lead != null else "", 
		"leader_score": ls, "leader_is_player": me, "rival_id": rv.id if rv != null else -1, "rival_name": rv.name if rv != null else "", 
		"rival_score": rv.score if rv != null else 0, "player_score": p.score if p != null else 0, "player_rank": rank, 
		"pct": float(ls) / float(tgt) if tgt > 0 else 0.0, "text": txt}


func _ever_had_city(c: Country) -> bool:
	for city: City in gw.cities:
		if city.founder_id == c.id:
			return true
	return false


func _best() -> int:
	var best: int = 0
	var bs: int = -1
	for c: Country in gw.countries:
		if not c.eliminated and c.score > bs:
			bs = c.score
			best = c.id
	return best


func _finish(id: int) -> void :
	ended = true
	winner = id
	Sfx.ui("ui_victory" if gw.player != null and gw.player.id == id else "ui_defeat")
	gw.match_ended.emit(id)



func _finish_team(v: Dictionary) -> void :
	ended = true
	verdict = v
	win_team = int(v.get("team", -1))
	winner = 0
	for c: Country in gw.countries:
		if RankedRules.team_of(c) == win_team:
			winner = c.id
			break
	var mine: int = RankedRules.my_team(gw)
	Sfx.ui("ui_victory" if win_team >= 0 and win_team == mine else "ui_defeat")
	gw.match_ended.emit(winner)



func ranking() -> Array[Country]:
	var arr: Array[Country] = gw.countries.duplicate()
	arr.sort_custom( func(a: Country, b: Country) -> bool: return a.score > b.score)
	return arr







func free_land(cid: int) -> int:
	var d: WorldData = gw.data
	if d == null or cid <= 0 or cid > 255:
		return 0
	var n: int = 0
	var i: int = d.owners.find(cid)
	while i >= 0:
		d.owners[i] = 0
		n += 1
		i = d.owners.find(cid, i + 1)
	if n > 0:
		d.owners_dirty = true
		gw._checkpoints_dirty = true
	return n


func _cleanup(c: Country) -> void :
	free_land(c.id)
	for o: Country in gw.countries:
		if o.id != c.id and gw.diplo.get_rel(c.id, o.id) != Diplomacy.Rel.PEACE:
			gw.diplo._set_rel(c.id, o.id, Diplomacy.Rel.PEACE)
	for u: Unit in gw.army.units:
		if u.country_id == c.id and u.alive():
			gw.army._kill(u, 0)
	for k in range(gw.econ.trucks.size() - 1, -1, -1):
		var t: Dictionary = gw.econ.trucks[k]
		if int(t["from"]) == c.id or int(t["to"]) == c.id:
			gw.econ.trucks.remove_at(k)
	for f: Facility in gw.mil.facilities:
		if f.country_id != c.id:
			continue
		var best: City = null
		var bd: float = INF
		for city: City in gw.cities:
			var d: float = Vector2(city.center).distance_squared_to(Vector2(f.cell))
			if city.country_id != c.id and d < bd:
				bd = d
				best = city
		if best != null:
			f.country_id = best.country_id
	for d: Drone in gw.mil.drones:
		if d.country_id == c.id and not d.airborne():
			d.state = Drone.State.DONE
	for a: Aircraft in gw.mil.air.aircraft:
		if a.country_id == c.id and a.state != Aircraft.State.DEAD:
			gw.mil.air._shot_down(a, "страна разгромлена")
