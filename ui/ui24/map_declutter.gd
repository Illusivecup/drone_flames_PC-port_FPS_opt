extends RefCounted






static var rec: bool = false
static var rects: Dictionary = {}


static func begin(layer: String) -> void :
	if rec:
		for k: String in rects.keys():
			if k.begins_with(layer + "_"):
				rects[k] = []
		rects[layer] = []


static func note(layer: String, r: Rect2) -> void :
	if rec:
		var a: Array = rects.get(layer, [])
		a.append(r)
		rects[layer] = a



static func pennant_rect(at: Vector2, k: float, label: String, fs: int = 11) -> Rect2:
	var top: Vector2 = at - Vector2(0, 16) * k
	var r: = Rect2(top + Vector2(-1, -1) * k, Vector2(15, 18) * k)
	if label != "" and UiKit.f_black != null:
		var sz: Vector2 = UiKit.f_black.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var p: Vector2 = top + Vector2(14.5 * k, 8.5 * k)
		r = r.merge(Rect2(p + Vector2(-2, - sz.y + 3), Vector2(sz.x + 4, sz.y)))
	return r




const LOD_FAR: float = 0.5
const LOD_NEAR: float = 1.0
const QUIET_A: float = 0.78
const KEEP_A: float = 0.18



static var keep_out: Array[Rect2] = []
static var keep_ver: int = 0

static var taps: Dictionary = {}


static var pennants_on: bool = false



static func lod(z: float) -> int:
	return 0 if z < LOD_FAR else (1 if z < LOD_NEAR else 2)


static func kept(r: Rect2) -> bool:
	for k: Rect2 in keep_out:
		if k.intersects(r):
			return true
	return false


static func tap_begin(layer: String) -> void :
	taps[layer] = []


static func tap_add(layer: String, r: Rect2, world: Vector2) -> void :
	var a: Array = taps.get(layer, [])
	a.append([r, world])
	taps[layer] = a




static func tap_at(pos: Vector2) -> Vector2:
	for ly: String in ["pennant", "icon", "pin"]:
		for e: Array in taps.get(ly, []):
			if (e[0] as Rect2).grow(6.0).has_point(pos):
				return e[1]
	return Vector2.INF








static var city_lab: Array = []

static var pen_rects: Array[Rect2] = []


static var named: Dictionary = {}


static var sel_gid: int = -1



static func label_rects(gw: GameWorld, cam: MapCamera) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for e: Array in city_lab:
		var r: Rect2 = e[1]
		out.append(Rect2(cam.world_to_screen(e[0] as Vector2) + r.position, r.size))
	if gw != null and gw.city_power != null and gw.city_power.has_method("shows"):

		var z1: float = cam.zoom.x
		for c: City in gw.cities:
			if not c.powered and bool(gw.city_power.call("shows", c, z1)):
				out.append(Rect2(cam.world_to_screen(Vector2(c.center * GameWorld.CELL)) + Vector2(-14, -31), Vector2(28, 32)))
	if gw != null and gw.labels != null:
		var z: float = cam.zoom.x
		for nr: Rect2 in gw.labels.name_rects:
			out.append(Rect2(cam.world_to_screen(nr.position), nr.size * z))
	return out


static func hits(r: Rect2, list: Array) -> bool:
	for q: Rect2 in list:
		if q.intersects(r):
			return true
	return false



static func zoom_in_of(z: float) -> float:
	for s0: float in [0.5, 1.0, 2.0]:
		var s: float = MapCamera.zk(s0)
		if s > z + 0.05:
			return s
	return z
