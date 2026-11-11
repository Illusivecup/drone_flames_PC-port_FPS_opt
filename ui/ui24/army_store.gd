extends RefCounted




const NAME_MAX: int = 12
const ArmyGroups = preload("res://game/army_groups.gd")
const ACT_ORDER: Dictionary = {"fight": 0, "sea": 1, "move": 2, "refill": 3, "dug": 4, "idle": 5}
const ACT_TEXT: Dictionary = {"fight": "В БОЮ", "move": "ИДУТ", "idle": "СТОЯТ", "dug": "ОКОП", "refill": "ПОПОЛНЕНИЕ", "sea": "В МОРЕ"}
const ACT_ICON: Dictionary = {"fight": "icon_act_fight_0", "move": "icon_act_move_0", "idle": "icon_act_idle", "dug": "icon_act_dug", 
	"refill": "icon_act_refill", "sea": "icon_act_sea"}
const STANCE_TEXT: Array[String] = ["ЖДУТ", "ДЕРЖАТ", "НАСТУПАЮТ"]
const STANCE_CHIP: Array[String] = ["ЖДУТ", "ДЕРЖАТ", "ВПЕРЁД"]
const STANCE_ICON: Array[String] = ["icon_stance_manual", "icon_stance_defend", "icon_stance_attack"]
const STANCE_COL: Array[String] = ["blue", "green", "red"]
const BUILD_ICON: Dictionary = {"assault": "icon_build_assault", "support": "icon_build_support", "at": "icon_build_at", 
	"motor": "icon_build_motor", "armor": "icon_build_armor", "mix": "icon_doctrine"}
const HIT_RECENT: float = 4.0

var gw: GameWorld
var groups: Array:
	get:
		return gw.player.army_groups if gw != null and gw.player != null else []
var _act: Dictionary = {}
var _views: Dictionary = {}


func _init(world: GameWorld) -> void :
	gw = world


func pid() -> int:
	return gw.player.id if gw.player != null else -1


func by_id(gid: int) -> Dictionary:
	return ArmyGroups.by_id(gw, pid(), gid)


func group_of(fid: int) -> Dictionary:
	return ArmyGroups.group_of(gw, pid(), fid)


func create(gname: String, col: int, emb: String, fids: PackedInt32Array) -> Dictionary:
	return ArmyGroups.create(gw, pid(), gname, col, emb, fids)


func remove(fids: PackedInt32Array) -> void :
	ArmyGroups.remove(gw, pid(), fids)


func disband(gid: int) -> void :
	ArmyGroups.disband(gw, pid(), gid)


func edit(gid: int, gname: String, col: int, emb: String) -> void :
	ArmyGroups.edit(gw, pid(), gid, gname, col, emb)


func default_name() -> String:
	return ArmyGroups.default_name(gw, pid())





func scan(sm: Dictionary) -> void :



	if gw.is_processing():
		if not gw.net_driven:
			ArmyGroups.prune(gw, pid())
	_act.clear()
	_views.clear()
	var per: Dictionary = {}
	var now: float = gw.game_time
	var p: int = pid()
	for u: Unit in gw.army.units:
		if u.home == null or u.country_id != p or not u.alive() or u.type == Unit.Type.FPV:
			continue
		var e: Array = per.get(u.home.id, [0, 0, 0, 0])
		if u.state == Unit.State.FIGHT or u.state == Unit.State.SIEGE or now - u.hit_t < HIT_RECENT:
			e[0] = int(e[0]) + 1
		if u.state == Unit.State.MOVE:
			e[1] = int(e[1]) + 1
		if u.post != null:
			e[2] = int(e[2]) + 1
		else:
			e[3] = int(e[3]) + 1
		per[u.home.id] = e
	for a: Dictionary in sm.get("armies", []):
		var fid: int = int(a["fid"])
		var e2: Array = per.get(fid, [0, 0, 0, 0])
		var op: Dictionary = a.get("op", {})
		var sk: String = String(op.get("state_kind", ""))
		var act: String = "idle"
		if int(a.get("at_sea", 0)) > 0:
			act = "sea"
		elif int(e2[0]) > 0:
			act = "fight"
		elif not op.is_empty():
			if sk == "refill":
				act = "refill"
			elif sk == "dug" or sk == "hold" or sk == "fight_line":
				act = "dug"
			else:
				act = "move"
		elif int(e2[3]) == 0 and int(e2[2]) > 0:
			act = "dug"
		elif int(a["n"]) < int(a["cap"]):
			act = "refill"
		_act[fid] = act
		_views[fid] = _view(a, act)


func activity(fid: int) -> String:
	return String(_act.get(fid, "idle"))



func armies(sm: Dictionary, gid: int) -> Array:
	var out: Array = []
	for a: Dictionary in sm.get("armies", []):
		var v: Dictionary = view(a)
		var g: int = int(v["gid"])
		if gid == -2 and g >= 0:
			continue
		if gid >= 0 and g != gid:
			continue
		out.append(v)
	out.sort_custom( func(x: Dictionary, y: Dictionary) -> bool:
		var ox: int = int(ACT_ORDER.get(String(x["act"]), 9))
		var oy: int = int(ACT_ORDER.get(String(y["act"]), 9))
		return ox < oy if ox != oy else int(x["no"]) < int(y["no"]))
	return out


func view(a: Dictionary) -> Dictionary:
	var fid: int = int(a["fid"])
	if _views.has(fid):
		return _views[fid]
	return _view(a, activity(fid))


func _view(a: Dictionary, act: String) -> Dictionary:
	var fid: int = int(a["fid"])
	var f: Facility = ArmyGroups.fac(gw, fid)
	var g: Dictionary = by_id(f.group_id) if f != null and f.group_id >= 0 else {}
	return {"fid": fid, "no": int(a["no"]), "name": String(a["name"]), "build": String(f.army_build) if f != null else "assault", 
		"n": int(a["n"]), "cap": int(a["cap"]), "hp": float(a["hp_frac"]), "stance": int(a["stance"]), "act": act, 
		"gid": int(g["id"]) if not g.is_empty() else -1, "gcol": int(g["color"]) if not g.is_empty() else -1, 
		"gemb": String(g["emblem"]) if not g.is_empty() else "", "pos": a["pos"], "doing": String(a.get("doing", ""))}



func totals(rows: Array) -> Dictionary:
	var troops: int = 0
	var cap: int = 0
	var cnt: Dictionary = {"fight": 0, "move": 0, "idle": 0}
	for r: Dictionary in rows:
		troops += int(r["n"])
		cap += int(r["cap"])
		var k: String = String(r["act"])
		if k == "sea":
			k = "move"
		elif k in ["dug", "refill"]:
			k = "idle"
		cnt[k] = int(cnt[k]) + 1
	return {"n_armies": rows.size(), "troops": troops, "hp": float(troops) / float(maxi(1, cap)), "counts": cnt}



static func pass_filter(r: Dictionary, flt: String) -> bool:
	var k: String = String(r["act"])
	match flt:
		"fight":
			return k == "fight"
		"move":
			return k in ["move", "sea"]
		"idle":
			return k in ["idle", "dug", "refill"]
	return true



func order_preview(rows: Array, kind: String, pos: Vector2, wp: Vector2 = Vector2.INF) -> Dictionary:
	var fids: = PackedInt32Array()
	for r: Dictionary in rows:
		fids.append(int(r["fid"]))
	var pv: Dictionary = ArmyGroups.preview(gw, pid(), fids, kind, pos, wp)
	var sk: Array = []
	for s: Array in pv["skipped"]:
		var f: Facility = ArmyGroups.fac(gw, int(s[0]))
		sk.append([f.army_no if f != null else 0, String(s[1]), int(s[0])])
	pv["skipped"] = sk
	return pv
