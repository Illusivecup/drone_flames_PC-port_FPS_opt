extends RefCounted














const QUIET: float = 40.0
const T_SPROUT: float = 55.0
const T_YOUNG: float = 140.0
const T_DONE: float = 245.0
const JIT: int = 45
const BLK: int = 16
const STEP: float = 0.25
const SLICES: int = 8
const FIGHT_STEP: float = 2.0
const FIGHT_HIT: float = 8.0

var gw: GameWorld
var cells: Dictionary = {}


var blk: Dictionary = {}
var _bkeys: Array = []
var _cur: int = 0
var _ft: float = 0.0
var ver: int = 0
var bver: Dictionary = {}
var bdue: Dictionary = {}
var hot: Dictionary = {}
var _gen: PackedByteArray = PackedByteArray()
var _t: float = 0.0
var _scanned: bool = false
var regrown: int = 0


func _init(world: GameWorld) -> void :
	gw = world



	if gw.data != null:
		_gen = gw.data.biome.duplicate()


func _orig(i: int) -> int:
	var b: int = _gen[i] if i < _gen.size() else Biome.GRASS
	if Biome.is_water(b):
		return b
	if b == Biome.BURNT or not Biome.is_natural_land(b):
		return Biome.GRASS
	return b


static func _forest(b: int) -> bool:
	return b == Biome.FOREST or b == Biome.PINE


func _bkey(x: int, y: int) -> int:
	return (y / BLK) * 65536 + x / BLK


func _heat(x: int, y: int) -> void :
	hot[_bkey(x, y)] = gw.game_time



func on_strike(cell: Vector2i, r: int, br: int) -> void :
	var d: WorldData = gw.data
	if d == null:
		return
	_heat(cell.x, cell.y)
	var rr: int = maxi(r, br)
	for dy in range( - rr, rr + 1):
		for dx in range( - rr, rr + 1):
			var x: int = cell.x + dx
			var y: int = cell.y + dy
			if not d.inside(x, y) or dx * dx + dy * dy > rr * rr + 1:
				continue
			var i: int = y * d.w + x
			if d.biome[i] == Biome.BURNT or _dead_tree(i):
				_add(i, x, y)


func _dead_tree(i: int) -> bool:
	if not gw.tree_at.has(i):
		return false
	var id: int = int(gw.tree_at[i])
	return id >= 0 and id < gw.obj_state.size() and gw.obj_state[id] == 1



func _taken(i: int, x: int, y: int) -> bool:
	var d: WorldData = gw.data
	if Biome.is_water(d.biome[i]) or (i < _gen.size() and Biome.is_water(_gen[i])):
		return true
	if d.has_flag(x, y, WorldData.F_CITY | WorldData.F_ROAD | WorldData.F_BRIDGE):
		return true
	if d.has_flag(x, y, WorldData.F_OCCUPIED) and not gw.tree_at.has(i):
		return true
	var c: = Vector2i(x, y)
	return gw.mil.fort_cells.has(c) or gw.mil.dig_cells.has(c)


func _put(i: int, rec: Array) -> void :
	cells[i] = rec
	var bk: int = _bkey(i % gw.data.w, i / gw.data.w)
	if not blk.has(bk):
		blk[bk] = []
		_bkeys.append(bk)
	(blk[bk] as Array).append(i)
	_bump(bk)
	bdue[bk] = 0.0




func touch_site(center: Vector2i, r: int) -> void :
	for by in range((center.y - r) / BLK, (center.y + r) / BLK + 1):
		for bx in range((center.x - r) / BLK, (center.x + r) / BLK + 1):
			var bk: int = by * 65536 + bx
			if blk.has(bk):
				bdue[bk] = 0.0


func _bump(bk: int) -> void :
	ver += 1
	bver[bk] = int(bver.get(bk, 0)) + 1


func _add(i: int, x: int, y: int) -> void :
	var d: WorldData = gw.data
	if _taken(i, x, y):
		return
	var r: Array = cells.get(i, [])
	if r.is_empty():
		_put(i, [gw.game_time, 0, _orig(i)])
	else:
		_bump(_bkey(x, y))
		bdue[_bkey(x, y)] = 0.0
		r[0] = gw.game_time
		if d.biome[i] == Biome.BURNT:
			r[1] = 0


func update(dt: float) -> void :
	_t += dt
	_ft += dt
	if _t < STEP:
		return
	_t -= STEP
	if not _scanned:
		_scanned = true
		_scan_old()
	if cells.is_empty():
		return
	if _ft >= FIGHT_STEP:
		_ft -= FIGHT_STEP
		_fights()

	var nb: int = _bkeys.size()
	var take: int = (nb + SLICES - 1) / SLICES
	var done: Array = []
	for k in take:
		if nb == 0:
			break
		if _cur >= nb:
			_cur = 0
		var bk: int = _bkeys[_cur]
		_cur += 1
		if gw.game_time < float(bdue.get(bk, 0.0)):
			continue
		if _block(bk):
			done.append(bk)
	for bk: int in done:
		var j: int = _bkeys.find(bk)
		if j >= 0:
			_bkeys.remove_at(j)
			if j < _cur:
				_cur -= 1
		blk.erase(bk)
		bver.erase(bk)
		bdue.erase(bk)
		ver += 1
	if cells.is_empty():
		hot.clear()
		_cur = 0



func _block(bk: int) -> bool:
	var d: WorldData = gw.data
	var now: float = gw.game_time
	var w: int = d.w
	var list: Array = blk[bk]
	var bx: int = bk % 65536
	var by: int = bk / 65536
	var q: float = _hot_around(bx, by)
	var keep: Array = []
	var changed: bool = false
	var due: float = 1e+18
	for i: int in list:
		var r: Array = cells.get(i, [])
		if r.is_empty():
			changed = true
			continue
		var x: int = i % w
		var y: int = i / w
		if _taken(i, x, y):
			cells.erase(i)
			changed = true
			continue
		var stage: int = int(r[1])
		var b: int = d.biome[i]
		if stage == 0 and b != Biome.BURNT and not _dead_tree(i):
			if b == Biome.GRASS and _forest(int(r[2])):
				r[1] = 1
				stage = 1
				changed = true
			else:
				cells.erase(i)
				changed = true
				continue
		var base: float = maxf(float(r[0]), q) + QUIET
		var quiet: float = now - base
		var jit: int = (Hash32.h2(x, y, d.world_seed + 319) & 65535) % JIT
		if quiet <= 0.0:
			keep.append(i)
			due = minf(due, base + T_SPROUT + float(jit) * 0.5)
			continue
		var o: int = int(r[2])
		if stage == 0 and quiet >= T_SPROUT + float(jit) * 0.5:
			if b == Biome.BURNT:
				d.set_biome(x, y, Biome.GRASS if _forest(o) else o)
			r[1] = 1 if _forest(o) or _dead_tree(i) else 3
			stage = int(r[1])
			changed = true
			if jit % 3 == 0:
				_revive(i)
		if stage == 1 and quiet >= T_YOUNG + float(jit) * 0.7:
			r[1] = 2
			stage = 2
			changed = true
			if jit % 3 == 1:
				_revive(i)
		if (stage >= 2 and quiet >= T_DONE + float(jit)) or stage == 3:
			if stage != 3 and (d.biome[i] == Biome.GRASS or d.biome[i] == Biome.BURNT):
				d.set_biome(x, y, o)
			_revive(i)
			cells.erase(i)
			regrown += 1
			changed = true
			continue
		keep.append(i)
		if stage == 0:
			due = minf(due, base + T_SPROUT + float(jit) * 0.5)
		elif stage == 1:
			due = minf(due, base + T_YOUNG + float(jit) * 0.7)
		else:
			due = minf(due, base + T_DONE + float(jit))
	bdue[bk] = due if due < 1e+17 else 0.0
	if changed:
		blk[bk] = keep
		_bump(bk)
	return keep.is_empty()


func _revive(i: int) -> void :
	if _dead_tree(i):
		var id: int = int(gw.tree_at[i])
		gw.obj_state[id] = 0
		gw._mark_obj_chunk(id)



func _hot_around(bx: int, by: int) -> float:
	var t: float = -1000000000.0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var k: int = (by + oy) * 65536 + bx + ox
			if hot.has(k):
				t = maxf(t, float(hot[k]))
	return t



func _fights() -> void :
	if gw.army == null:
		return
	var now: float = gw.game_time
	for u: Unit in gw.army.units:
		if u.state == Unit.State.DEAD:
			continue
		if u.state == Unit.State.FIGHT or u.state == Unit.State.SIEGE or now - u.hit_t < FIGHT_HIT:
			_heat(floori(u.pos.x / GameWorld.CELL), floori(u.pos.y / GameWorld.CELL))



func _scan_old() -> void :
	var d: WorldData = gw.data
	if d == null:
		return
	var w: int = d.w
	var i: int = d.biome.find(Biome.BURNT)
	while i >= 0:
		var x: int = i % w
		var y: int = i / w
		if not cells.has(i) and not _taken(i, x, y):
			_put(i, [gw.game_time - QUIET, 0, _orig(i)])
		i = d.biome.find(Biome.BURNT, i + 1)


func save_state() -> Dictionary:
	var ks: = PackedInt32Array()
	var ts: = PackedFloat64Array()
	var ss: = PackedByteArray()
	for i: int in cells:
		var r: Array = cells[i]
		ks.append(i)
		ts.append(float(r[0]))
		ss.append(int(r[1]) | (int(r[2]) << 2))
	var hk: = PackedInt32Array()
	var ht: = PackedFloat64Array()
	for k: int in hot:
		hk.append(k)
		ht.append(float(hot[k]))
	var bo: = PackedInt32Array()
	for bk: int in _bkeys:
		bo.append(bk)
	return {"k": ks, "t": ts, "s": ss, "hk": hk, "ht": ht, "scan": _scanned, "acc": _t, "n": regrown, 
		"bo": bo, "cur": _cur, "facc": _ft, "bd": bdue.duplicate()}


func load_state(st: Dictionary) -> void :
	cells.clear()
	hot.clear()
	blk.clear()
	bver.clear()
	_bkeys.clear()
	bdue.clear()
	ver += 1
	var ks: PackedInt32Array = PackedInt32Array(st.get("k", PackedInt32Array()))
	var ts: PackedFloat64Array = PackedFloat64Array(st.get("t", PackedFloat64Array()))
	var ss: PackedByteArray = PackedByteArray(st.get("s", PackedByteArray()))

	for bk: int in PackedInt32Array(st.get("bo", PackedInt32Array())):
		blk[bk] = []
		_bkeys.append(bk)
	for j in mini(ks.size(), mini(ts.size(), ss.size())):
		_put(ks[j], [ts[j], ss[j] & 3, ss[j] >> 2])
	var hk: PackedInt32Array = PackedInt32Array(st.get("hk", PackedInt32Array()))
	var ht: PackedFloat64Array = PackedFloat64Array(st.get("ht", PackedFloat64Array()))
	for j in mini(hk.size(), ht.size()):
		hot[hk[j]] = ht[j]
	_scanned = bool(st.get("scan", true))
	_t = float(st.get("acc", 0.0))
	regrown = int(st.get("n", 0))
	_cur = clampi(int(st.get("cur", 0)), 0, maxi(0, _bkeys.size()))
	_ft = float(st.get("facc", 0.0))
	var bd: Variant = st.get("bd", {})
	if bd is Dictionary:
		for bk: int in bd:
			if blk.has(bk):
				bdue[bk] = float(bd[bk])
