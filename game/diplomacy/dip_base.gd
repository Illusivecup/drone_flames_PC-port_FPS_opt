extends RefCounted


enum Rel{PEACE, WAR, TRUCE, ALLIANCE}

const REL_NAMES: Array = ["МИР", "ВОЙНА", "ПЕРЕМИРИЕ", "СОЮЗ"]
const REL_COLORS: Array = ["grass_light", "alert_red", "amber", "intercept_cyan"]
const TRUCE_TIME: float = 150.0



const CALM_MIN: float = 300.0
const CALM_MAX: float = 600.0
const CALM_HITS: int = 4
const TRUCE_WARN: float = 30.0
const PEACE_MIN_WAR: float = 60.0
const PEACE_ASK_GAP: float = 240.0
const THINK_DT: float = 12.0

var gw: GameWorld
var rel: Dictionary = {}
var since: Dictionary = {}
var truce_until: Dictionary = {}
var opinion: Dictionary = {}
var offers: Array = []
var _t: float = 0.0



const GIFT_MAX: float = 40.0
const GIFT_W_MIN: float = 1500.0
const GIFT_FORGET: float = 600.0
const GRUDGE_T: float = 600.0
const GRUDGE_MUL: float = 0.35
const GRUDGE_MUL_AGGR: float = 0.15
const GRUDGE_CAP: int = 15
const GRUDGE_CAP_AGGR: int = 0
const FRIEND_REL: int = 30
const ALLY_SUSTAIN: float = 300.0
const DEFENSE_SUSTAIN: float = 180.0
var gift_mem: Dictionary = {}
var war_by: Dictionary = {}
var good_since: Dictionary = {}
var peace_t: Dictionary = {}
var calm_hits: Dictionary = {}
var _truce_warned: Dictionary = {}



var passage: Dictionary = {}
var _pass_ask: Dictionary = {}
var _overfly_t: float = 0.0
var _overfly_last: Dictionary = {}





const TREATY_KINDS: Array[String] = ["trade", "visa", "nap", "defense", "alliance"]
const TREATY_INFO: Dictionary = {
	"trade": {"name": "ТОРГОВЫЙ ДОГОВОР", "short": "ТОРГОВЛЯ", "icon": "icon_treaty_trade", "min_rel": 0, 
		"effect": "Излишки сами идут партнёру, цены для вас −10 %, отношения растут"}, 
	"visa": {"name": "БЕЗВИЗ", "short": "БЕЗВИЗ", "icon": "icon_treaty_visa", "min_rel": 20, 
		"effect": "Туристы приносят доход обоим (по числу городов), торговля −5 %, отношения растут"}, 
	"nap": {"name": "ПАКТ О НЕНАПАДЕНИИ", "short": "НЕНАПАД.", "icon": "icon_treaty_nap", "min_rel": 15, 
		"effect": "Напасть, не расторгнув пакт, — вероломство: весь мир охладеет к нарушителю"}, 
	"defense": {"name": "ОБОРОННЫЙ ПАКТ", "short": "ОБОРОНА", "icon": "icon_treaty_defense", "min_rel": 45, 
		"effect": "Если на одного нападут, второй вступит в войну. В чужие нападения не втягивает"}, 
	"alliance": {"name": "СОЮЗ", "short": "СОЮЗ", "icon": "icon_treaty_alliance", "min_rel": 60, 
		"effect": "Оборона — вместе; в вашу атаку вступит только по вашему зову; общая РЛС"}, 

	"passage": {"name": "ПРАВО ПРОХОДА", "short": "ПРОХОД", "icon": "icon_treaty_passage", "min_rel": 10, 
		"effect": "Войска идут через их землю и бьют оттуда третью страну, БПЛА летают над ней"}, 

	"subj_over": {"name": "ВАССАЛИТЕТ", "short": "ВАССАЛИТЕТ", "icon": "icon_dip_vassal", "min_rel": 0, 
		"effect": "Вы станете их вассалом: дань 10 % дохода, их войны — ваши, своих войн нет"}, 
	"subj_sub": {"name": "ПОКРОВИТЕЛЬСТВО", "short": "ПОКРОВИТ.", "icon": "icon_dip_vassal", "min_rel": 0, 
		"effect": "Они станут вашим вассалом: дань 10 % вам, воюют за вас, вы защищаете их"}, 
}
const EMBARGO_INFO: Dictionary = {"name": "ЭМБАРГО", "short": "ЭМБАРГО", "icon": "icon_treaty_embargo", 
	"effect": "Закрывает всю торговлю с этой страной (вводит одна сторона)"}
const CANCEL_PENALTY: Dictionary = {"trade": 5, "visa": 6, "nap": 12, "defense": 12, "alliance": 40, "passage": 8}
const DEMAND_ICON: String = "icon_ultimatum"
const DEMAND_KINDS: Array[String] = ["money", "res", "deposit", "break_alliance", "cancel_visa", "vassal", "puppet"]
const GRACE: float = 600.0
const BOT_WAR_T: float = 600.0
const WAR_EDGE: float = 1.0
const PRESSURE_T: float = 1500.0
const EARLY_EDGE: float = 1.2
const SECOND_FRONT: float = 1.5
const VULTURE_T: float = 180.0
const APPEASE_RATIO: float = 0.55
const DEMAND_TIME: float = 75.0
const PLAYER_DEMAND_GAP: Array = [240.0, 420.0]
const FIRST_PLAYER_DEMAND: float = 480.0
const PLAYER_DEMAND_SHARE: Array = [0.15, 0.25]
const PLAYER_OFFER_GAP: float = 210.0
const PLAYER_ASK_GAP: float = 120.0
const AI_ANSWER_T: float = 15.0
const TOUR_DT: float = 10.0
const TOUR_PER_CITY: int = 1
const CEDE_R: int = 9
const INCIDENT_NAMES: Dictionary = {"saboteur": "диверсанты", "spy": "шпионаж", "decoy": "ложные цели", "drone": "дрон-разведчик", 
	"border": "нарушение границы", "sabotage": "диверсия"}

signal pending_changed

var treaties: Dictionary = {}
var embargo: Dictionary = {}
var demands: Array = []
var t_offers: Array = []
var known: Dictionary = {}
var war_goals: Dictionary = {}
var coalition: Dictionary = {}
var counters: Dictionary = {}
var wars_log: Array = []
var _dem_id: int = 1
var _next_dem: Dictionary = {}
var _player_dem_t: float = 480.0
var _player_offer_t: float = 240.0
var _player_dem_last: float = -999.0
var _pair_dem: Dictionary = {}
var _player_ask_t: Dictionary = {}
var _tour_t: float = 0.0
var _coal_t: float = 0.0
var _coal_form_t: float = 0.0
var _nb_t: float = 1000000000.0
var _nb: Dictionary = {}
var _prev_t: float = 0.0
var _rel_prev: Dictionary = {}
var _tick_n: int = 0
var trace_on: bool = false
var trace: Array = []
const CareS = preload("res://game/ally_care.gd")
var care = null
var last_package: String = ""


func _init(world: GameWorld) -> void :
	gw = world
	ally = AllyS.new(self)
	rift = RiftS.new(self)


const AllyS = preload("res://game/alliances.gd")
const RiftS = preload("res://game/ally_rift.gd")


var rift = null


var ally = null



func dlog(who: int, what: String, why: String, score: float = 0.0, meta: Array = []) -> void :
	if trace_on:
		trace.append([gw.game_time, who, what, why, score, meta])


static func key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


func get_rel(a: int, b: int) -> int:
	if a == b:
		return Rel.ALLIANCE
	return int(rel.get(key(a, b), Rel.PEACE))


func at_war(a: int, b: int) -> bool:
	return a != b and get_rel(a, b) == Rel.WAR


func allied(a: int, b: int) -> bool:
	return a != b and get_rel(a, b) == Rel.ALLIANCE


func war_time(a: int, b: int) -> float:
	return gw.game_time - float(since.get(key(a, b), 0.0))


func get_opinion(a: int, b: int) -> int:
	return int(opinion.get(key(a, b), 0))


func add_opinion(a: int, b: int, v: int) -> void :
	var k: String = key(a, b)
	if v > 0 and gw.pstat != null:
		v = gw.pstat.rival_clamp(a, b, int(opinion.get(k, 0)), v)
	opinion[k] = clampi(int(opinion.get(k, 0)) + v, -100, 100)




func truce_on(a: int, b: int) -> bool:
	return a != b and get_rel(a, b) == Rel.TRUCE



func conf_lock(a: int, b: int) -> bool:
	return conf != null and a != b and conf.locks(a, b)




func calm_time(a: int) -> float:
	return lerpf(CALM_MAX, CALM_MIN, clampf(float(_p(a)["aggr"]), 0.0, 1.0))




func calm_left(a: int, b: int) -> float:
	var k: String = key(a, b)
	if not peace_t.has(k) or a == b:
		return 0.0
	return maxf(0.0, float(peace_t[k]) + calm_time(a) - gw.game_time)


func calm_on(a: int, b: int) -> bool:
	return calm_left(a, b) > 0.0 or calm_left(b, a) > 0.0


func _name(id: int) -> String:
	var c: Country = gw.country_by_id(id)
	return c.name.to_upper() if c != null else "?"



func _rel_eff(a: int, b: int) -> int:
	return rift.rel_eff(a, b) if rift != null else relation(a, b)



func ally_of_ally(a: int, b: int) -> int:
	for d: Country in gw.countries:
		if d.id != a and d.id != b and not d.eliminated and allied(a, d.id) and allied(d.id, b):
			return d.id
	return -1



func _war_cleanup(a: int, b: int) -> void :
	treaties.erase(key(a, b))
	passage.erase("%d>%d" % [a, b])
	passage.erase("%d>%d" % [b, a])
	embargo.erase("%d>%d" % [a, b])
	embargo.erase("%d>%d" % [b, a])
	for i in range(demands.size() - 1, -1, -1):
		var d: Dictionary = demands[i]
		if (int(d["from"]) == a and int(d["to"]) == b) or (int(d["from"]) == b and int(d["to"]) == a):
			demands.remove_at(i)
	for i in range(t_offers.size() - 1, -1, -1):
		var o: Dictionary = t_offers[i]
		if (int(o["from"]) == a and int(o["to"]) == b) or (int(o["from"]) == b and int(o["to"]) == a):
			t_offers.remove_at(i)
	pending_changed.emit()



func alliance_found(cid: int, partner: int) -> String:
	return ally.cmd_found(cid, partner)


func alliance_invite(cid: int, target: int) -> String:
	return ally.cmd_invite(cid, target)


func alliance_join(cid: int, aid: int) -> String:
	return ally.cmd_join(cid, aid)


func alliance_answer(cid: int, oid: int, yes: bool) -> String:
	return ally.cmd_answer(cid, oid, yes)


func alliance_style(cid: int, aid: int, nm: String, ci: int, logo: int) -> String:
	return ally.style(cid, aid, nm, ci, logo)


func alliance_leave(cid: int) -> String:
	return ally.cmd_leave(cid)


func alliance_kick(cid: int, aid: int, target: int) -> String:
	return ally.kick(cid, aid, target)



func strength(id: int) -> float:
	var c: Country = gw.country_by_id(id)
	if c == null:
		return 0.0
	return float(c.score) + minf(float(c.money) * 0.3, 3000.0) + float(gw.army.count_units(id)) * 120.0 + float(c.city_ids.size()) * 300.0



func _db(c: int, o: int, topic: String = "war") -> float:
	return gw.drama.bias(c, topic, o) if gw.drama != null else 0.0



func _dm(c: int, o: int) -> float:
	return gw.drama.war_mul(c, o) if gw.drama != null else 1.0





func war_power(id: int) -> float:
	var c: Country = gw.country_by_id(id)
	if c == null:
		return 0.0
	return float(gw.army.count_units(id)) * 60.0 + float(c.score) * 0.3 + float(c.city_ids.size()) * 150.0




func _human(cid: int) -> bool:
	var c: Country = gw.country_by_id(cid)
	return c != null and c.is_player


func player_pressure() -> float:
	if gw.net_driven:
		return 0.0
	var p: Country = gw.player
	if p == null or p.eliminated or GameConfig.aggression == 0 or not p.at_war.is_empty() or gw.game_time < PRESSURE_T:
		return 0.0
	return clampf((float(p.money) - 8000.0) / 20000.0, 0.0, 1.0) * clampf((gw.game_time - PRESSURE_T) / 300.0, 0.0, 1.0)


func _leader_id() -> int:
	var best: int = -1
	var bs: int = -1
	for c: Country in gw.countries:
		if not c.eliminated and c.score > bs:
			bs = c.score
			best = c.id
	return best


func _enemies_of(id: int) -> Array:
	var c: Country = gw.country_by_id(id)
	return c.at_war.keys() if c != null else []



const NB_BANDS: int = 4
var _nb_y: int = -1
var _nb_tmp: Dictionary = {}




func relation(a: int, b: int) -> int:
	return get_opinion(a, b)


func embargoed(from: int, to: int) -> bool:
	return embargo.has("%d>%d" % [from, to])


func embargo_between(a: int, b: int) -> bool:
	return embargoed(a, b) or embargoed(b, a)


func persona_known(id: int) -> bool:
	return known.has(id)



func relation_trend(a: int, b: int) -> int:
	var k: String = key(a, b)
	var d: int = get_opinion(a, b) - int(_rel_prev.get(k, get_opinion(a, b)))
	return 1 if d >= 2 else (-1 if d <= -2 else 0)


func _p(id: int) -> Dictionary:
	var c: Country = gw.country_by_id(id)
	if gw.ai != null and c != null:
		return gw.ai.persona_of(c)
	return AiPersona.NEUTRAL


func _cname(id: int) -> String:
	var c: Country = gw.country_by_id(id)
	return c.name if c != null else "?"


func _count(k: String, n: int = 1) -> void :
	counters[k] = int(counters.get(k, 0)) + n


func _alive(id: int) -> bool:
	var c: Country = gw.country_by_id(id)
	return c != null and not c.eliminated and c.capital_id >= 0



func _drift(a: int, b: int, v: int) -> void :
	add_opinion(a, b, v)



func _reveal(a: int, b: int, quiet: bool = false) -> void :
	var p: Country = gw.player
	if p == null:
		return
	var other: int = b if a == p.id else (a if b == p.id else -1)
	if other < 0 or other == p.id or known.has(other):
		return
	var oc: Country = gw.country_by_id(other)
	if oc == null or oc.is_player:
		return
	known[other] = true
	var P: Dictionary = _p(other)
	if String(P.get("name", "")) != "" and not quiet:
		gw.message.emit(Loc.t("%s — %s: %s") % [Loc.name(oc.name), Loc.t(String(P["name"])), Loc.t(String(P["desc"]))])
	pending_changed.emit()


const REOFFER_GAP: float = 600.0
var _t_offer_last: Dictionary = {}


var _who: int = -1
var _who_hint: int = -1




const PASS_ASK_GAP: float = 240.0
const PASS_ASK_GAP_H: float = 600.0
const PASS_ASK_GAP_ANY: float = 360.0
const PASS_ANSWER_T: float = 45.0
const OVERFLY_GAP: float = 90.0



const PASS_OFFER_T: float = 60.0
const PASS_REGRANT_GAP: float = 150.0
const PASS_OFFER_GAP: float = 60.0




const STRIKE_BLOCK_TXT: String = "Нельзя: войска на чужой земле — сначала вывод"
const STRIKE_SUBJ_TXT: String = "Нельзя: войны нет, а вассалитет её не допускает"
var _sb_said: Dictionary = {}




const PeaceConfS = preload("res://game/peace_conf.gd")
const SUBJ_NAMES: Dictionary = {"vassal": "ВАССАЛ", "puppet": "МАРИОНЕТКА"}
const TRIBUTE: Dictionary = {"vassal": 0.1, "puppet": 0.2}
const TRIBUTE_DT: float = 30.0
const SUBJ_NEED: Dictionary = {"vassal": 2.2, "puppet": 3.4}
const SUBJ_OFFER_NEED: float = 1.8
const SUBJ_OFFER_REL: int = 35
const SUBJ_FIRST_T: float = 900.0
const SUBJ_PLAYER_T: float = 1200.0
const SUBJ_GLOBAL_GAP: float = 420.0
const SUBJ_PAIR_GAP: float = 600.0
const SUBJ_AI_MAX: Dictionary = {"militarist": 2, "adventurer": 2, "cautious": 1, "trader": 1}
const CALL_AFTER: float = 30.0
const CALL_T: float = 60.0
const CALL_GAP: float = 420.0
const NOTE_T: float = 45.0
const AID_GAP: float = 150.0
const AID_KINDS: Array[String] = ["money", "missile_b", "missile_c", "drones", "metal", "titanium", "oil", "fuel", "food", "wood", "precious", "goods", "missile_sam"]
const AID_ICONS: Dictionary = {"money": "res_money", "missile_b": "icon_m_ballistic", "missile_c": "icon_m_cruise", "drones": "icon_launch", "missile_sam": "icon_m_sam"}
const AID_NAMES: Dictionary = {"money": "ДЕНЬГИ", "missile_b": "БАЛЛИСТ.", "missile_c": "КРЫЛАТЫЕ", "drones": "ДРОНЫ", "missile_sam": "РАКЕТЫ ПВО"}

var conf = null
var subjects: Dictionary = {}
var calls: Array = []
var notes: Array = []
var refusals: Dictionary = {}
var _called: Dictionary = {}
var _helped: Dictionary = {}
var _aid_next: Dictionary = {}
var _subj_t: float = 0.0
var _subj_pair: Dictionary = {}
var _trib_t: float = 0.0
var _trib_earned: Dictionary = {}
var _pcall_t: float = 0.0
var _dip2_follow: bool = false
var reborn: Dictionary = {}
var aid_log: Array = []








const LOC_SUBJ_WHY: Dictionary = {"treaty": "договор", "ultimatum": "ультиматум", "surrender": "капитуляция", "voluntary": "добровольно", 
	"protection": "просит защиты", "conference": "конференция"}


const YOUNG_T: float = 600.0







const PILE_GAP: Array = [150.0, 110.0, 80.0]
const PILE_CAP: Array = [2, 2, 3]
const PILE_GAP_DEF: float = 60.0
const PILE_CAP_DEF: int = 4
const PILE_GAP_BOT: float = 45.0
const PILE_CAP_BOT: int = 4



const CALL_ASK_GAP: float = 120.0




const ASK_JOIN: float = 0.6
const JOIN_EDGE: float = 0.9
const RECRUIT_AFTER: float = 90.0
const RECRUIT_GAP: float = 360.0
const ASK_PLAYER_GAP: float = 600.0
var _recruit_next: Dictionary = {}
var _ask_player_t: float = 0.0




const ALLY_FAC_SHARE: float = 0.4
var ally_fac: Dictionary = {}




const DipReactS = preload("res://game/dip_react.gd")
var react = null







const SkyS = preload("res://game/sky_cover.gd")
var sky = null




const ReqS = preload("res://game/dip_requests.gd")
var rq = null


var reqs: Array:
	get:
		return rq.reqs if rq != null else []
