extends RefCounted









const TIERS: int = 6


static func _src(gw: Object, fn: String) -> Object:
	if gw == null:
		return null
	if gw.has_method("power_" + fn):
		return gw
	for prop: String in ["power_status", "pstatus"]:
		if prop in gw:
			var o: Variant = gw.get(prop)
			if typeof(o) == TYPE_OBJECT and o != null and (o as Object).has_method(fn):
				return o as Object
	return null



static func _pstat(gw: Object) -> Object:
	if gw == null or not ("pstat" in gw):
		return null
	var o: Variant = gw.get("pstat")
	return o as Object if typeof(o) == TYPE_OBJECT and o != null and (o as Object).has_method("status_of") else null



static func tier(gw: Object, cid: int) -> int:
	var ps: Object = _pstat(gw)
	if ps != null:
		return clampi(int(ps.call("status_of", cid)) + 1, 1, TIERS)
	var s: Object = _src(gw, "tier")
	if s == null:
		return 0
	var v: Variant = s.call("power_tier" if s == gw else "tier", cid)
	return clampi(int(v), 0, TIERS) if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT else 0


static func epithet(gw: Object, cid: int) -> String:
	var ps: Object = _pstat(gw)
	if ps != null:
		return String(ps.call("epithet_name", int(ps.call("epithet_of", cid))))
	var s: Object = _src(gw, "epithet")
	return String(s.call("power_epithet" if s == gw else "epithet", cid)) if s != null else ""


static func crisis(gw: Object, cid: int) -> String:
	var ps: Object = _pstat(gw)
	if ps != null:
		return String(ps.call("state_name", int(ps.call("state_of", cid))))
	var s: Object = _src(gw, "crisis")
	return String(s.call("power_crisis" if s == gw else "crisis", cid)) if s != null else ""


static func badge(t: int, small: bool = false) -> String:
	if t <= 0:
		return ""
	return ("d331_stm_%d" if small else "d331_st_%d") % clampi(t, 1, TIERS)
