extends RefCounted












const MS = preload("res://ui/ui24/my_state.gd")
const OTHER_GAP_MS: int = 45000
const ST_PARIAH: int = 2
const ST_FAIL: int = 3

var hud: Node
var _gw: Object = null
var _dp: Object = null
var _ps: Object = null
var _sig: bool = false
var _prev: Dictionary = {}
var _t: float = 9.0
var _other_ms: int = - OTHER_GAP_MS
var _badge_key: String = "?"
var _name_key: String = ""
var pushed: Array = []


func _init(h: Node) -> void :
	hud = h


func tick(delta: float) -> void :
	_t += delta
	if _t < 1.5:
		return
	_t = 0.0
	var gw: GameWorld = hud.gw
	if gw == null or gw.player == null or gw.diplo == null:
		return
	if gw != _gw or gw.diplo != _dp:
		_gw = gw
		_dp = gw.diplo
		_prev.clear()
		_badge_key = "?"
	var ps: Object = MS.provider(gw)
	if ps != _ps:
		_ps = ps
		_sig = ps != null and ps.has_signal("status_changed")
		if _sig and not ps.is_connected("status_changed", _on_change):
			ps.connect("status_changed", _on_change)
	if ps == null:
		_sync_badge(-1, false)
		return
	var own: Dictionary = MS.status_of(gw, gw.player.id)
	_sync_badge(int(own["tier"]), not (own["crisis"] as Array).is_empty())
	_fit_name()
	if not _sig:
		_poll(gw)




func _on_change(ev: Dictionary) -> void :
	var gw: GameWorld = hud.gw
	if gw == null or gw.player == null or _ps == null:
		return
	var cid: int = int(ev.get("cid", -1))
	var c: Country = gw.country_by_id(cid)
	if c == null:
		return
	var own: bool = cid == gw.player.id
	var t0: int = int(ev.get("old_tier", 0))
	var t1: int = int(ev.get("tier", 0))
	var s0: int = int(ev.get("old_state", 0))
	var s1: int = int(ev.get("state", 0))
	var text: String = String(_ps.call("change_text", ev, own)) if _ps.has_method("change_text") else ""
	var world: String = String(_ps.call("change_text", ev, false)) if _ps.has_method("change_text") else ""
	var tone: String = "up"
	var sub: String = "Новый статус · тап — паспорт страны"
	if s1 != s0 and s1 != 0:
		tone = "crisis" if s1 <= ST_FAIL else "down"
		sub = Loc.t("Кризис · тап — паспорт страны") if s1 <= ST_FAIL else Loc.t("Зависимость · тап — паспорт страны")
	elif s1 != s0:
		tone = "up"
		sub = "Кризис позади · тап — паспорт страны"
	elif t1 < t0:
		tone = "down"
		sub = "Статус понижен · тап — что растить"
	if own:
		_mute(world)
		_push(text, sub, tone, t1, cid, s1 >= 1 and s1 <= ST_FAIL, true, s1)
		return
	if not (c.is_player or gw.diplo.known.has(cid)):
		return
	var loud: bool = (s1 != s0 and (s1 == ST_PARIAH or s1 == ST_FAIL)) or (t1 > t0 and t1 >= 4) or (t1 < t0 and t0 >= 5)
	if not loud:
		return
	var now: int = Time.get_ticks_msec()
	if now - _other_ms < OTHER_GAP_MS:
		return
	_other_ms = now
	_mute(world)
	_push(text, "Мировая арена · тап — их страница", "crisis" if s1 == ST_PARIAH or s1 == ST_FAIL else "other", t1, cid, s1 == ST_PARIAH or s1 == ST_FAIL, false, s1)



func _mute(text: String) -> void :
	var lane: Variant = hud.get("lane")
	if text != "" and lane is Object and is_instance_valid(lane) and (lane as Object).has_method("mute_title"):
		(lane as Object).call("mute_title", text, 20.0)




func _poll(gw: GameWorld) -> void :
	for c: Country in gw.countries:
		if c.eliminated:
			_prev.erase(c.id)
			continue
		var st: Dictionary = MS.status_of(gw, c.id)
		var tier: int = int(st["tier"])
		var cr: Array = []
		for e: Dictionary in st["crisis"]:
			cr.append(String(e["name"]))
		cr.sort()
		if not _prev.has(c.id):
			_prev[c.id] = [tier, cr]
			continue
		var old: Array = _prev[c.id]
		_prev[c.id] = [tier, cr]
		if int(old[0]) == tier and old[1] == cr:
			continue
		_announce(gw, c, int(old[0]), tier, old[1], cr)



static func _ins(nm: String) -> String:
	nm = Loc.src_of(nm)
	var i: int = MS.TIER_NAMES.find(nm)
	if i >= 0:
		return String(MS.TIER_INS[i])
	if nm.begins_with("ИЗГО"):
		return "ИЗГОЕМ"
	return nm



func _announce(gw: GameWorld, c: Country, t0: int, t1: int, cr0: Array, cr1: Array) -> void :
	var added: Array = cr1.filter( func(x: String) -> bool: return not cr0.has(x))
	var gone: Array = cr0.filter( func(x: String) -> bool: return not cr1.has(x))
	var top: int = MS.TIER_NAMES.size() - 1
	if c == gw.player:
		if not added.is_empty():
			var a: String = String(added[0])
			_push((Loc.t("Ваша страна стала %s") % _ins(a)) if Loc.src_of(a).begins_with("ИЗГО") else (Loc.t("Ваша страна: %s") % a), "Кризис · тап — паспорт страны", "crisis", t1, c.id, true, true)
		elif t1 > t0 and t0 >= 0:
			_push(Loc.t("Ваша страна стала %s") % Loc.t(String(MS.TIER_INS[clampi(t1, 0, top)])), "Новый статус · тап — паспорт страны", "up", t1, c.id, false, true)
		elif t1 < t0 and t1 >= 0:
			_push(Loc.t("Ваша страна теряет статус: снова %s") % Loc.t(String(MS.TIER_NAMES[clampi(t1, 0, top)])), "Статус понижен · тап — что растить", "down", t1, c.id, false, true)
		elif not gone.is_empty():
			_push(Loc.t("Ваша страна больше не %s") % String(gone[0]).to_lower(), "Кризис позади · тап — паспорт страны", "up", t1, c.id, false, true)
		return
	if not (c.is_player or gw.diplo.known.has(c.id)):
		return
	var title: String = ""
	for a2: String in added:
		if Loc.src_of(a2).begins_with("ИЗГО") or Loc.src_of(a2).begins_with("РАСПАД"):
			title = Loc.t("%s стала %s") % [Loc.name(c.name), _ins(a2)]
	if title == "" and t1 > t0 and t1 >= top - 1 and t0 >= 0:
		title = Loc.t("%s стала %s") % [Loc.name(c.name), Loc.t(String(MS.TIER_INS[clampi(t1, 0, top)]))]
	if title == "":
		return
	var now: int = Time.get_ticks_msec()
	if now - _other_ms < OTHER_GAP_MS:
		return
	_other_ms = now
	_push(title, "Мировая арена · тап — их страница", "crisis" if not added.is_empty() else "other", t1, c.id, not added.is_empty(), false)




func _sync_badge(tier: int, crisis: bool) -> void :
	var key: String = "%d:%s" % [tier, crisis]
	if key == _badge_key:
		return
	_badge_key = key
	_name_key = ""
	var holder: Variant = hud.get("top_badge")
	if not holder is Control or not is_instance_valid(holder):
		return
	var h: Control = holder
	for ch: Node in h.get_children():
		ch.queue_free()
	h.visible = tier >= 0
	if tier >= 0:
		h.add_child(MS.badge(tier, crisis, 1, true))




func _fit_name() -> void :
	var tv: Variant = hud.get("top_name")
	if not tv is Label or not is_instance_valid(tv):
		return
	var tn: Label = tv
	if tn.size.x < 8.0:
		return
	var key: String = "%s|%d" % [tn.text, int(tn.size.x)]
	if key == _name_key:
		return
	_name_key = key
	var f: Font = tn.get_theme_font("font")
	var fs: int = 13
	while fs > 10 and f.get_string_size(tn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > tn.size.x:
		fs -= 1
	tn.add_theme_font_size_override("font_size", fs)


func _push(title: String, sub: String, tone: String, tier: int, cid: int, crisis: bool, own: bool, stt: int = 0) -> void :
	if title == "":
		return
	pushed.append([title, sub, tone, cid])
	var lane: Variant = hud.get("lane")
	if lane is Object and is_instance_valid(lane) and (lane as Object).has_method("push"):
		(lane as Object).call("push", "status", {"title": title, "sub": sub, "tone": tone, "tier": tier, "cid": cid, "crisis": crisis, "own": own, "state": stt})
