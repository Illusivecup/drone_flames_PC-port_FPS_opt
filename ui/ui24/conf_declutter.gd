extends RefCounted













const BIT: int = 1 << 19

const WORLD: Array[String] = ["MapIcons", "Ops", "UnitsNight", "Hold", "Capture", "Eco", "OreMarks", "EconFx", 
	"ReconLayer", "Fog", "Trade", "Top", "CityPower", "PendingGhost", "VfxClouds", "VfxAir"]

const HUD: Array[String] = ["FrontOverlay", "ArmyPennants", "NavyMap", "StrikeMarks", "Jet316Marks", "RouteOverlay"]

static var _holders: Dictionary = {}
static var tagged: int = 0




static func tag(main: Node) -> void :
	tagged = 0
	if main == null or not is_instance_valid(main):
		return
	var w: Variant = main.get("world")
	if w is Node and is_instance_valid(w):
		for nm: String in WORLD:
			_tag1((w as Node).get_node_or_null(NodePath(nm)))
	var h: Variant = main.get("hud")
	if h is Node and is_instance_valid(h):
		var r: Variant = (h as Node).get("root")
		for nm2: String in HUD:
			var n: Node = (h as Node).get_node_or_null(NodePath(nm2))
			if n == null and r is Node and is_instance_valid(r):
				n = (r as Node).get_node_or_null(NodePath(nm2))
			_tag1(n)


static func _tag1(n: Node) -> void :
	if n is CanvasItem:
		(n as CanvasItem).visibility_layer = BIT
		tagged += 1



static func hold(who: Object, on: bool) -> void :
	if who == null:
		return
	if on:
		_holders[who.get_instance_id()] = true
	else:
		_holders.erase(who.get_instance_id())
	for id: int in _holders.keys():
		if not is_instance_id_valid(id):
			_holders.erase(id)
	_apply()


static func active() -> bool:
	return not _holders.is_empty()


static func _apply() -> void :
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var vp: Viewport = tree.root
	var want: int = (vp.canvas_cull_mask & ~ BIT) if not _holders.is_empty() else (vp.canvas_cull_mask | BIT)
	if vp.canvas_cull_mask != want:
		vp.canvas_cull_mask = want
