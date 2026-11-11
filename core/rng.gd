class_name Rng
extends RefCounted


var state: int = 1



var log_on: bool = false
var log_tick: int = 0
var draws: Array = []


func _init(seed_value: int = 1) -> void :
	state = Hash32.mix(seed_value ^ 2654435769)
	if state == 0:
		state = 1831565813


func next_u32() -> int:
	if log_on:
		var st: Array = get_stack()
		var who: String = ""
		for fr: Dictionary in st:
			var src: String = String(fr.get("source", ""))
			if not src.ends_with("rng.gd"):
				who = "%s:%s:%d" % [src.get_file().get_basename(), String(fr.get("function", "")), int(fr.get("line", 0))]
				break
		draws.append("%d %s" % [log_tick, who])
		if draws.size() > 48:
			draws.pop_front()
	var x: int = state
	x ^= (x << 13) & Hash32.M32
	x ^= x >> 17
	x ^= (x << 5) & Hash32.M32
	state = x & Hash32.M32
	return state


func range_i(n: int) -> int:
	if n <= 0:
		return 0
	return next_u32() % n


func range_ab(a: int, b: int) -> int:
	return a + range_i(b - a + 1)



func roll() -> float:
	return float(next_u32()) / 4294967300.0


func chance(percent: int) -> bool:
	return range_i(100) < percent


func pick(arr: Array) -> Variant:
	return arr[range_i(arr.size())]
