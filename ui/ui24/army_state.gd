extends RefCounted





const AG = preload("res://game/army_groups.gd")
const FP = preload("res://game/front_plan.gd")


const ST: Dictionary = {
	"fight": ["В БОЮ", "БОЙ", Color("ff6a4d"), "icon_act_fight_0"], 
	"sea": ["В МОРЕ", "МОРЕ", Color("8fd2ff"), "icon_act_sea"], 
	"march": ["НА МАРШЕ", "МАРШ", Color("ffb000"), "icon_move"], 
	"dug": ["В ОКОПАХ", "ОКОПЫ", Color("c3d36e"), "icon_trench"], 
	"front": ["ДЕРЖИТ ФРОНТ", "ФРОНТ", Color("8fd2ff"), "icon_op_defend"], 
	"form": ["ФОРМИРУЕТСЯ", "НАБОР", Color("d8cfb0"), "icon_barracks"], 
	"idle": ["В РЕЗЕРВЕ", "РЕЗЕРВ", Color("d8cfb0"), "icon_barracks"], 
	"take": ["ЗАНИМАЕТ ГОРОД", "ЗАХВАТ", Color("ffb000"), "icon_op_attack"], 
	"rail": ["ЕДЕТ ПОЕЗДОМ", "ПОЕЗД", Color("ffcf7a"), "r332_rail_on"], 
}
const FOOT: Array = [Unit.Type.INFANTRY, Unit.Type.ATGM, Unit.Type.ASSAULT]


static func gname(g: Dictionary) -> String:
	return Loc.gtag(int(g.get("id", 0)), String(g.get("name", "")))


static func hp_col(hp: float) -> Color:
	return UiKit.GREEN if hp >= 0.75 else (UiKit.GOLD if hp >= 0.4 else UiKit.RED)



static func key_of(gw: GameWorld, f: Facility, n: int, inn: int, foot: int, fighting: bool, moving: int = 0, taking: bool = false) -> String:
	if gw.rail != null and gw.rail.troops != null and gw.rail.troops.riding(f):
		return "rail"
	var sea: bool = gw.naval != null and gw.naval.at_sea(f)
	if n == 0:
		return "sea" if sea else "form"
	if fighting:
		return "fight"
	if taking:
		return "take"
	if sea:
		return "sea"
	if foot > 0 and inn * 2 >= foot:
		return "dug"
	if moving * 2 > n:
		return "march"
	if FP.holds_fac(gw, f) or (gw.ops != null and gw.ops.list.has(f)):
		return "front"
	return "idle"




static func _siege_hot(gw: GameWorld, u: Unit) -> bool:
	if u.target_city < 0 or u.target_city >= gw.cities.size():
		return true
	var city: City = gw.cities[u.target_city]
	return city.garrison > 0.0 or u.target != null



static func snapshot(gw: GameWorld, cid: int) -> Dictionary:
	var agg: Dictionary = {}
	for u: Unit in gw.army.units:
		if u.country_id != cid or u.home == null or not u.alive() or u.type == Unit.Type.FPV:
			continue
		var a: Array = agg.get(u.home.id, [0, 0.0, 0.0, 0, 0, false, 0, false, 0, 0])
		if u.reinf != 0:
			a[8 if u.reinf == 1 else 9] = int(a[8 if u.reinf == 1 else 9]) + 1
			agg[u.home.id] = a
			continue
		a[0] = int(a[0]) + 1
		a[1] = float(a[1]) + u.hp
		a[2] = float(a[2]) + u.max_hp
		if u.post != null:
			a[3] = int(a[3]) + 1
		if u.type in FOOT:
			a[4] = int(a[4]) + 1
		if u.state == Unit.State.SIEGE and not _siege_hot(gw, u):
			a[7] = true
		elif u.state == Unit.State.FIGHT or u.state == Unit.State.SIEGE:
			a[5] = true
		elif u.state == Unit.State.MOVE and u.post == null:
			a[6] = int(a[6]) + 1
		agg[u.home.id] = a
	if gw.naval != null:

		for f0: Facility in gw.mil.facilities:
			if f0.kind != Facility.Kind.BARRACKS or f0.country_id != cid or not gw.naval.busy(f0):
				continue
			for u0: Unit in gw.naval.aboard_of(f0):
				if u0.type == Unit.Type.FPV:
					continue
				var a0: Array = agg.get(f0.id, [0, 0.0, 0.0, 0, 0, false, 0, false, 0, 0])
				a0[0] = int(a0[0]) + 1
				a0[1] = float(a0[1]) + u0.hp
				a0[2] = float(a0[2]) + u0.max_hp
				if u0.type in FOOT:
					a0[4] = int(a0[4]) + 1
				agg[f0.id] = a0
	var out: Dictionary = {}
	for f: Facility in gw.mil.facilities:
		if f.kind != Facility.Kind.BARRACKS or f.country_id != cid or ( not gw.mil.alive(f) and f.restore_t <= 0.0 and not agg.has(f.id)):
			continue
		var a2: Array = agg.get(f.id, [0, 0.0, 0.0, 0, 0, false, 0, false, 0, 0])
		var n: int = int(a2[0])
		var inn: int = int(a2[3])
		var foot: int = maxi(int(a2[4]), inn)
		var b: Dictionary = gw.army.build_of(f)
		out[f.id] = {"key": key_of(gw, f, n, inn, foot, bool(a2[5]), int(a2[6]), bool(a2[7])), "n": n, "cap": gw.army.cap_of(f), "hp": float(a2[1]) / maxf(1.0, float(a2[2])) if n > 0 else 0.0, 
			"inn": inn, "foot": foot, "dug": foot > 0 and inn * 2 >= foot, "no": f.army_no, "build_name": String(b.get("name", "")), "build_icon": String(b.get("icon", "icon_infantry")), 
			"gid": f.group_id, "gname": "", "gath": int(a2[8]), "walk": int(a2[9])}

	for g: Dictionary in AG.groups(gw, cid):
		var gk: String = String(group(out, g)["key"])
		var has_front: bool = not FP.front_of(g).is_empty()
		for fid: int in g.get("fids", []):
			if not out.has(fid):
				continue
			out[fid]["gid"] = int(g.get("id", -1))
			out[fid]["gname"] = gname(g)
			if String(out[fid]["key"]) == "idle":
				if gk == "fight" or gk == "idle":
					out[fid]["key"] = "front" if has_front or gk == "fight" else "idle"
				else:
					out[fid]["key"] = gk
	return out



static func chip_line(s: Dictionary) -> Array:
	var stx: Array = ST[s.get("key", "idle")]
	var gn: String = String(s.get("gname", ""))
	if gn == "":
		return ["%d/%d%s · %s" % [int(s["n"]), int(s["cap"]), _plus(s), Loc.t(String(stx[1]))], stx[2]]
	if String(s.get("key", "")) == "idle":
		return ["%d/%d%s · %s" % [int(s["n"]), int(s["cap"]), _plus(s), gn], UiKit.TEXT]
	return ["%d/%d%s · %s · %s" % [int(s["n"]), int(s["cap"]), _plus(s), gn, Loc.t(String(stx[1]))], stx[2]]



static func _plus(s: Dictionary) -> String:
	var k: int = int(s.get("gath", 0)) + int(s.get("walk", 0))
	return " +%d" % k if k > 0 else ""



static func reinf_txt(gath: int, walk: int) -> String:
	var out: PackedStringArray = []
	if walk > 0:
		out.append("+%d %s" % [walk, Loc.t("идёт") if walk == 1 else Loc.t("идут")])
	if gath > 0:
		out.append("+%d %s" % [gath, Loc.t("собирается") if gath == 1 else Loc.t("собираются")])
	return " · ".join(out)




static func group(snap: Dictionary, g: Dictionary) -> Dictionary:
	var cnt: Dictionary = {}
	var n: int = 0
	var hp: float = 0.0
	var a: int = 0
	var gath: int = 0
	var walk: int = 0
	for fid: int in g.get("fids", []):
		if not snap.has(fid):
			continue
		var s: Dictionary = snap[fid]
		cnt[s["key"]] = int(cnt.get(s["key"], 0)) + 1
		n += int(s["n"])
		hp += float(s["hp"]) * float(s["n"])
		a += 1
		gath += int(s.get("gath", 0))
		walk += int(s.get("walk", 0))
	var key: String = "idle"
	if cnt.has("fight"):
		key = "fight"
	else:
		for k: String in ["sea", "take", "march", "dug", "front"]:
			if cnt.has(k) and int(cnt[k]) * 2 >= maxi(1, a):
				key = k
				break
		if key == "idle" and not FP.front_of(g).is_empty():
			key = "front"
	return {"key": key, "armies": a, "n": n, "hp": hp / maxf(1.0, float(n)), "dug_armies": int(cnt.get("dug", 0)), 
		"fight": int(cnt.get("fight", 0)), "march": int(cnt.get("march", 0)) + int(cnt.get("sea", 0)), "gath": gath, "walk": walk}
