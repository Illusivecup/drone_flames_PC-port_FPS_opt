extends RefCounted














var gw: GameWorld

var ai_ph: Dictionary = {}

var war_br: Dictionary = {}


var tick: int = 0
var step_dt: float = 0.0
var slots: int = 0
const SLOTS_PER_S: float = 60.0



const SLOTS_MAX: int = 20

var dip_q: Array = []
var dip_t0: float = 0.0

var town_q: Array = []

var trade_q: Array = []

var plan_fail: Dictionary = {}
const PLAN_TTL: float = 4.0



var plans: int = 0
var exp_cont: Dictionary = {}
var take_cont: Dictionary = {}



const GROW_RINGS: int = 3
const GROW_LONG_DT: float = 0.1

const EXP_SLICES: int = 8


func _init(w: GameWorld) -> void :
	gw = w








func phase_offsets() -> void :
	if gw.kpp != null:
		gw.kpp._t = -7.5
	if gw.rail != null:
		gw.rail._t = -1.25
	if gw.pstat != null:
		gw.pstat.next_t = 15.0
	if gw.drama != null:
		gw.drama.next_t = 20.0
		gw.drama.hist_t = 45.0



func step(dt: float) -> void :
	tick += 1
	step_dt = dt
	slots = clampi(ceili(dt * SLOTS_PER_S - 0.001), 1, SLOTS_MAX)
	plans = slots




func take_ai_slot() -> bool:
	if slots <= 0:
		return false
	slots -= 1
	return true


static func cell_key(p: Vector2i, kind: int) -> int:
	return (p.y * 8192 + p.x) * 4 + kind




func can_found_ai(p: Vector2i, kind: int) -> Dictionary:
	var k: int = cell_key(p, kind)
	if plan_fail.has(k) and gw.game_time < float(plan_fail[k]):
		return {"ok": false, "radius": 0, "memo": true}
	plans -= 1
	var pl: Dictionary = gw.can_found_city(p, kind)
	if not bool(pl["ok"]):
		if plan_fail.size() > 4096:
			_prune()
		plan_fail[k] = gw.game_time + PLAN_TTL
	return pl



func plan_free(p: Vector2i, kind: int) -> bool:
	if plans > 0:
		return true
	var k: int = cell_key(p, kind)
	return plan_fail.has(k) and gw.game_time < float(plan_fail[k])


func _prune() -> void :
	for k: int in plan_fail.keys():
		if gw.game_time >= float(plan_fail[k]):
			plan_fail.erase(k)
