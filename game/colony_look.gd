extends RefCounted










const RICH: Dictionary = {"panel9_h": true, "panel9_v": true, "tower16": true, "stalinka_h": true, "stalinka_v": true, 
	"khrushchevka_h": true, "khrushchevka_v": true, "highrise_panel": true, "highrise_brick": true, 
	"glass_tower_a": true, "glass_tower_b": true, "business_center": true}
const SHACKS: Array = ["col_shack_a", "col_shack_b", "col_shack_c"]
const SMALL: Array = ["col_shack_a", "col_shack_b", "col_shack_c", "col_cont", "col_tent", "col_shack_a", "col_cont"]
const EMPTY_LOT: float = 0.3
const HOUSE_TO_SHACK: float = 0.65
const KEEP_TREES: float = 0.45



static func is_poor(gw: GameWorld, city: City) -> bool:
	if gw == null or city == null or city.kind == City.Kind.CAPITAL:
		return false
	if gw.has_meta("poor_city") and bool(gw.get_meta("poor_city")):
		return true
	return gw.get("naval") != null and gw.naval != null and gw.naval.is_colony(city)


static func poorer(gw: GameWorld, plan: Dictionary, city: City) -> Dictionary:
	if not gw.spr_index.has("col_shack_a") or not plan.has("buildings"):
		return plan
	var rng: = RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(city.center.x * 31 + 7, city.center.y * 17 + int(plan.get("added", 0))))
	var out: Array = []
	for b: Array in plan["buildings"]:
		var sname: String = String(b[0])
		var c: Vector2i = b[1]
		if sname.begins_with("house_"):
			out.append([String(SHACKS[rng.randi() % SHACKS.size()]), c] if rng.randf() < HOUSE_TO_SHACK else b)
			continue
		if not RICH.has(sname) or not gw.spr_index.has(sname):
			out.append(b)
			continue
		var si: int = int(gw.spr_index[sname])
		_fill(out, rng, c, int(gw.spr_fw[si]), int(gw.spr_fd[si]))
	plan["buildings"] = out

	var trees: Array = []
	for t: Array in plan.get("trees", []):
		if rng.randf() < KEEP_TREES:
			trees.append(t)
	plan["trees"] = trees
	for g: Array in plan.get("ground", []):
		if int(g[1]) == Biome.YARD:
			g[1] = Biome.GARDEN
	plan["poor"] = true
	return plan



static func _fill(out: Array, rng: RandomNumberGenerator, c: Vector2i, fw: int, fd: int) -> void :
	var occ: Dictionary = {}
	if fw >= 6 and fd >= 2 and rng.randf() < 0.75:
		var oy: int = 0 if fd < 4 or rng.randf() < 0.5 else fd - 2
		out.append(["col_barrack_h", c + Vector2i(0, oy)])
		for yy in range(oy, oy + 2):
			for xx in 6:
				occ[Vector2i(xx, yy)] = true
	elif fd >= 6 and fw >= 2 and rng.randf() < 0.75:
		out.append(["col_barrack_v", c])
		for yy in 6:
			for xx in 2:
				occ[Vector2i(xx, yy)] = true
	for yy in range(0, fd - 1, 2):
		for xx in range(0, fw - 1, 2):
			var free: bool = true
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				if occ.has(Vector2i(xx, yy) + d):
					free = false
			if not free or rng.randf() < EMPTY_LOT:
				continue
			out.append([String(SMALL[rng.randi() % SMALL.size()]), c + Vector2i(xx, yy)])



static func after(gw: GameWorld, plan: Dictionary) -> void :
	if not bool(plan.get("poor", false)):
		return
	var d: WorldData = gw.data
	for c: Vector2i in plan.get("streets", []):
		if d.has_flag(c.x, c.y, WorldData.F_BRIDGE):
			continue
		d.set_biome(c.x, c.y, Biome.GARDEN)
