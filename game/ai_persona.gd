class_name AiPersona
extends RefCounted






const LIST: Array = [
	{"id": "trader", "name": "ТОРГОВЕЦ", "icon": "icon_persona_trader", 
		"desc": "Торгует и богатеет. Мир покупает, воюет только за сырьё.", 
		"aggr": 0.2, "trade": 0.95, "sneaky": 0.2, "caution": 0.5, 
		"builds": ["motor", "at", "support"], "sub_wait": 120.0}, 
	{"id": "militarist", "name": "МИЛИТАРИСТ", "icon": "icon_persona_militarist", 
		"desc": "Растёт за счёт соседей: требует, грозит и бьёт слабых.", 
		"aggr": 0.9, "trade": 0.3, "sneaky": 0.3, "caution": 0.2, 
		"builds": ["armor", "assault", "motor", "support"], "sub_wait": 30.0}, 
	{"id": "cautious", "name": "ОСТОРОЖНЫЙ", "icon": "icon_persona_cautious", 
		"desc": "Строит ПВО и окопы, ищет союзников и пакты.", 
		"aggr": 0.15, "trade": 0.55, "sneaky": 0.1, "caution": 0.95, 
		"builds": ["at", "support", "motor"], "sub_wait": 60.0}, 
	{"id": "adventurer", "name": "АВАНТЮРИСТ", "icon": "icon_persona_adventurer", 
		"desc": "Шпионит разведдронами, рискует, предаёт и бьёт, когда вы заняты.", 
		"aggr": 0.6, "trade": 0.45, "sneaky": 0.95, "caution": 0.3, 
		"builds": ["assault", "support", "armor"], "sub_wait": 45.0}, 
]

const NEUTRAL: Dictionary = {"id": "", "name": "", "icon": "", "desc": "", "aggr": 0.5, "trade": 0.5, "sneaky": 0.5, "caution": 0.5, 
	"builds": ["mix"], "sub_wait": 60.0}

const AGGR_MUL: Array = [0.45, 1.0, 1.3]


static func by_id(id: String) -> Dictionary:
	for p: Dictionary in LIST:
		if String(p["id"]) == id:
			return p
	return NEUTRAL



static func shown(id: String, key: String = "name") -> String:
	return Loc.t(String(by_id(id).get(key, "")))


static func ids() -> Array:
	var out: Array = []
	for p: Dictionary in LIST:
		out.append(p["id"])
	return out



static func traits(id: String) -> Dictionary:
	var p: Dictionary = by_id(id).duplicate()
	p["aggr"] = clampf(float(p["aggr"]) * float(AGGR_MUL[clampi(GameConfig.aggression, 0, 2)]), 0.0, 1.0)
	return p
