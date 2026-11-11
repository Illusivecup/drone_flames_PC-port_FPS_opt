class_name Bridge
extends RefCounted








enum State{INTACT, REBUILDING}
enum Kind{RIVER, SEA, RAIL}
const REBUILD_TIME: float = 120.0
const RAIL_REBUILD_TIME: float = 240.0
const SPAN_HALF: int = 5
const SEA_MIN: int = 7

var id: int = 0
var kind: int = Kind.RIVER
var cells: Array[Vector2i] = []
var dirs: PackedByteArray = PackedByteArray()
var pts: PackedVector2Array = PackedVector2Array()
var state: int = State.INTACT
var t: float = 0.0
var hit: int = 0
var lo: int = 0
var hi: int = 0
var collapse: PackedFloat32Array = PackedFloat32Array()
var scaffold: PackedFloat32Array = PackedFloat32Array()
var done: PackedFloat32Array = PackedFloat32Array()
var next_spark: float = 0.0
var hit_t: PackedFloat32Array = PackedFloat32Array()
var rehit: bool = false

var pont: int = 0
var pont_t: float = 0.0
var pont_hp: int = 0
var pont_next: float = 0.0


func start_rebuild(k: int) -> void :
	var n: int = cells.size()
	var fresh: bool = state != State.REBUILDING or collapse.size() != n or scaffold.size() != n or done.size() != n
	rehit = not fresh
	if fresh:
		state = State.REBUILDING
		t = 0.0
		collapse.resize(n)
		scaffold.resize(n)
		done.resize(n)
		for i in n:
			collapse[i] = 1000000000.0
			scaffold[i] = 1000000000.0
			done[i] = 0.0
		next_spark = 1.2
	if hit_t.size() != n:
		hit_t.resize(n)
		hit_t.fill(-1000000000.0)
	hit = k
	lo = 0
	hi = n - 1
	if kind != Kind.RIVER and n > SPAN_HALF * 2 + 3:
		lo = maxi(0, k - SPAN_HALF)
		hi = mini(n - 1, k + SPAN_HALF)
	var m: int = (hi - lo + 2) / 2
	for i in range(lo, hi + 1):
		var d: int = absi(i - k)
		if fresh or view(i) == 0:
			collapse[i] = t + 0.08 * d
		var bank: int = mini(i - lo, hi - i)

		scaffold[i] = maxf(collapse[i] + 0.35, t + 0.6 + 0.15 * bank)
		done[i] = t + 4.0 + (rebuild_time() - 4.0) * float(bank + 1) / float(m)
		hit_t[i] = t



func end_t() -> float:
	var e: float = 0.0
	for v in done:
		e = maxf(e, v)
	return e if e > 0.0 else rebuild_time()



func rebuild_time() -> float:
	return RAIL_REBUILD_TIME if kind == Kind.RAIL else REBUILD_TIME



func left() -> float:
	return maxf(0.0, end_t() - t) if state == State.REBUILDING else 0.0




func fresh_hit(k: int) -> bool:
	return state == State.REBUILDING and k >= 0 and k < hit_t.size() and t - hit_t[k] < 2.0



func down_spans() -> int:
	if state != State.REBUILDING:
		return 0
	var n: int = 0
	var prev: bool = false
	for i in cells.size():
		var dn: bool = view(i) != 0 or (i < collapse.size() and t >= collapse[i] and t < done[i])
		if dn and not prev:
			n += 1
		prev = dn
	return n



func view(i: int) -> int:
	if state == State.INTACT:
		return 0
	if t < collapse[i]:
		return 0
	if t < scaffold[i]:
		return 1
	if t < done[i]:
		return 2
	return 0


func passable() -> bool:
	return state == State.INTACT


func progress() -> float:
	return clampf(1.0 - left() / rebuild_time(), 0.0, 1.0)


func center_px() -> Vector2:
	var c: Vector2i = cells[cells.size() / 2] if state == State.INTACT else cells[clampi(hit, 0, cells.size() - 1)]
	return Vector2(c.x * 4 + 2, c.y * 4 + 2)



func cell_at_px(p: Vector2) -> int:
	var best: int = 0
	var bd: float = INF
	for i in cells.size():
		var d: float = p.distance_squared_to(Vector2(cells[i] * 4) + Vector2(2, 2))
		if d < bd:
			bd = d
			best = i
	return best
