class_name NetCodec
extends RefCounted






const ArmyGroups = preload("res://game/army_groups.gd")
const TAGS: Dictionary = {"Country": "C", "City": "Y", "Facility": "F", "Unit": "U", "Drone": "D", "Missile": "M", "Aircraft": "A", "Ship": "S"}

static var ok: bool = true


static func encode(v: Variant) -> Variant:
	if v is Object:
		var o: Object = v
		var sc: Script = o.get_script() as Script
		var cn: String = String(sc.get_global_name()) if sc != null else ""
		if TAGS.has(cn) and "id" in o:
			return {"$e": TAGS[cn], "i": int(o.get("id"))}
		push_warning("[Net] not sendable: %s" % o)
		return null
	if v is Array:
		var a: Array = v
		var out: Array = []
		for x: Variant in a:
			out.append(encode(x))
		if a.is_typed():
			var sp: String = ""
			var ts: Variant = a.get_typed_script()
			if ts is Script:
				sp = (ts as Script).resource_path
			return {"$a": a.get_typed_builtin(), "c": String(a.get_typed_class_name()), "s": sp, "v": out}
		return out
	if v is Dictionary:
		var d: Dictionary = v
		var od: Dictionary = {}
		for k: Variant in d:
			od[k] = encode(d[k])
		return {"$d": od}
	return v


static func decode(gw: GameWorld, v: Variant) -> Variant:
	ok = true
	return _dec(gw, v)


static func _dec(gw: GameWorld, v: Variant) -> Variant:
	if v is Array:
		var out: Array = []
		for x: Variant in v:
			out.append(_dec(gw, x))
		return out
	if not (v is Dictionary):
		return v
	var d: Dictionary = v
	if d.has("$e"):
		var e: Object = _entity(gw, String(d["$e"]), int(d["i"]))
		if e == null:
			ok = false
		return e
	if d.has("$a"):
		var items: Array = _dec(gw, d["v"])
		var sc: Variant = null
		var sp: String = String(d["s"])
		if sp != "":
			if not (sp.begins_with("res://game/") and sp.ends_with(".gd") and not sp.contains("..")):
				ok = false
				return []
			sc = load(sp)
		return Array(items, int(d["$a"]), StringName(String(d["c"])), sc)
	if d.has("$d"):
		var od: Dictionary = {}
		var src: Dictionary = d["$d"]
		for k: Variant in src:
			od[k] = _dec(gw, src[k])
		return od
	return d


static func _entity(gw: GameWorld, tag: String, id: int) -> Object:
	match tag:
		"C":
			return gw.country_by_id(id)
		"Y":
			for c: City in gw.cities:
				if c.id == id:
					return c
		"F":
			var f: Facility = ArmyGroups.fac(gw, id)
			return f
		"U":
			for u: Unit in gw.army.units:
				if u.id == id:
					return u
		"D":
			for dr: Drone in gw.mil.drones:
				if dr.id == id:
					return dr
		"M":
			for m: Missile in gw.mil.missiles:
				if m.id == id:
					return m
		"A":
			for a: Aircraft in gw.mil.air.aircraft:
				if a.id == id:
					return a
		"S":
			if gw.navy != null:
				return gw.navy.ship(id)
	return null
