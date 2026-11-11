class_name City
extends RefCounted


enum Kind{CAPITAL, TOWN, VILLAGE}

var id: int = 0
var name: String = ""
var kind: int = Kind.TOWN
var country_id: int = 0
var founder_id: int = 0
var center: Vector2i = Vector2i.ZERO
var entrance: Vector2i = Vector2i.ZERO
var radius: int = 10
var claim_done: bool = false
var grow_ticks: int = 0
var frontier: Array[Vector3i] = []
var visited: Dictionary = {}
var claim_max: int = 30
var level: int = 1
var buildings: int = 0
var residents: int = 0
var housing_capacity: int = 0
var population_growth_clock: float = 0.0
var powered: bool = true
var flicker_until: float = 0.0
var dark_since: float = -1.0
var spark_next: float = 0.0

var garrison: float = 100.0
var garrison_max: float = 100.0
var siege_by: int = 0
var capture: float = 0.0
var hit_t: float = 0.0
var fire_t: float = 0.0
var taken_by: Dictionary = {}
var flag_node: Node = null

var cap_by: int = 0
var cap_note: int = 0

var strike_t: float = -999.0
var war_t: float = -999.0
var war_by: int = 0

var claim_v: int = 0


func garrison_cap() -> float:
	match kind:
		Kind.CAPITAL:
			return 1200.0
		Kind.TOWN:
			return 500.0
	return 200.0
