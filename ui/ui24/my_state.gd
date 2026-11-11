extends PanelContainer









signal closed

const PAD: float = 8.0

const TIER_NAMES: Array = ["МОЛОДАЯ РЕСПУБЛИКА", "РЕСПУБЛИКА", "РЕГИОНАЛЬНАЯ СИЛА", "ДЕРЖАВА", "ВЕЛИКАЯ ДЕРЖАВА", "СВЕРХДЕРЖАВА"]
const TIER_GEN: Array = ["МОЛОДОЙ РЕСПУБЛИКИ", "РЕСПУБЛИКИ", "РЕГИОНАЛЬНОЙ СИЛЫ", "ДЕРЖАВЫ", "ВЕЛИКОЙ ДЕРЖАВЫ", "СВЕРХДЕРЖАВЫ"]
const TIER_INS: Array = ["МОЛОДОЙ РЕСПУБЛИКОЙ", "РЕСПУБЛИКОЙ", "РЕГИОНАЛЬНОЙ СИЛОЙ", "ДЕРЖАВОЙ", "ВЕЛИКОЙ ДЕРЖАВОЙ", "СВЕРХДЕРЖАВОЙ"]
const TIER_STARS: Array = [1, 2, 1, 2, 2, 3]

const STATE_WHY: Array = ["", "потеряна часть городов или войск", "эмбарго и санкции от многих стран", "потеряна столица или большинство городов", "", ""]

const METAL: Array = [["a8703e", "d49a66", "6c3e1c"], ["c07a3e", "eab27a", "7c4520"], ["98a4b0", "dfe7ee", "566170"], ["a9b5c0", "f4f8fb", "5f6a76"], 
	["d9a02a", "ffe08a", "8e600c"], ["e3ad2c", "fff0b0", "94660e"]]
const TIER_COL: Array = [Color("cf9b6e"), Color("e0a068"), Color("c4d0da"), Color("e3ecf2"), Color("ffc94a"), Color("ffe27a")]
const C_WAR: = Color("ff6a4d")
const C_PEACE: = Color("a2e35f")
const C_TRUCE: = Color("ffb000")
const C_ALLY: = Color("7cccff")
const ROW_H: float = 44.0
const LAND_ICON: String = "tabi_world"

var m: Node
var hud: Node
var gw: GameWorld
var dp: Diplomacy
var me: int = 0
var vp: Vector2 = Vector2(360, 640)
var max_h: float = 480.0
var col: VBoxContainer
var scroll: ScrollContainer
var inner: VBoxContainer
var scroll_wrap: MarginContainer
var _fade_top: TextureRect
var _fade_bot: TextureRect
var _timers: Array = []
var _sig: String = ""
var _closing: bool = false
var _tick_t: float = 0.0
var _live_t: float = 0.0
var rebuilds: int = 0
var _slide: float = 0.0
var _elim0: bool = false
var _dp0: Object = null
var _st: Dictionary = {}


func setup(main: Node) -> void :
	m = main
	hud = m.hud
	gw = m.world
	dp = gw.diplo
	_dp0 = dp
	me = gw.player.id
	_elim0 = gw.player.eliminated
	name = "MyStateSheet"
	tree_exiting.connect( func() -> void :
		if hud != null and is_instance_valid(hud):
			hud.ui24_closed(self)
			if hud.has_method("my_state_closed"):
				hud.call("my_state_closed"))
	var tabs: Variant = hud.get("tabs")
	if tabs is Array:
		for tb: Variant in tabs:
			if tb is BaseButton:
				(tb as BaseButton).pressed.connect(close_sheet)
	UiKit.ensure()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var st: StyleBox = UiKit.sb("wb_window", PAD, 6)
	st.expand_margin_left = 14.0
	st.expand_margin_right = 14.0
	st.expand_margin_bottom = 14.0
	st.content_margin_left = PAD
	st.content_margin_right = PAD
	st.content_margin_top = 10.0
	st.content_margin_bottom = 10.0 + float(hud._safe_margins().y)
	add_theme_stylebox_override("panel", st)
	col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)



func fit(viewport: Vector2, tab_h: float) -> void :
	vp = viewport
	max_h = floorf(vp.y * 0.7) - tab_h
	custom_minimum_size.x = vp.x
	rebuild(false)


func compact() -> bool:
	return vp.y < 700.0


func scroll_area() -> ScrollContainer:
	return scroll if scroll != null and is_instance_valid(scroll) else null





static func provider(w: GameWorld) -> Object:
	if w == null:
		return null
	var hosts: Array = [w, w.diplo]
	for h: Variant in hosts:
		if h == null:
			continue
		for nm: String in ["power_status", "pstatus", "power", "pstat", "powers"]:
			var v: Variant = (h as Object).get(nm)
			if v is Object and v != null and _is_provider(v as Object):
				return v as Object
	if w.has_meta("power_status"):
		var mv: Variant = w.get_meta("power_status")
		if mv is Object:
			return mv as Object
	return null


static func _is_provider(o: Object) -> bool:
	for fn: String in ["info", "status_info", "info_of", "status_of", "tier_of", "tier"]:
		if o.has_method(fn):
			return true
	return false




static func status_of(w: GameWorld, cid: int) -> Dictionary:
	var out: Dictionary = {"tier": -1, "name": "", "epithet": "", "crisis": [], "progress": -1.0, "next": "", "needs": [], "hint": "", "rank": -1}
	var ps: Object = provider(w)
	if ps == null:
		return out
	if ps.has_method("label_parts"):
		return _from_pstat(w, ps, cid, out)
	var raw: Variant = null
	for fn: String in ["info", "status_info", "info_of", "status_of"]:
		if ps.has_method(fn):
			raw = ps.call(fn, cid)
			break
	if raw == null:
		for fn2: String in ["tier_of", "tier"]:
			if ps.has_method(fn2):
				raw = ps.call(fn2, cid)
				break
	if raw is int or raw is float:
		out["tier"] = int(raw)
	elif raw is Dictionary:
		var d: Dictionary = raw
		out["tier"] = int(_pick(d, ["tier", "level", "rank_tier", "t"], -1))
		out["name"] = String(_pick(d, ["name", "title", "tier_name", "label"], ""))
		out["epithet"] = String(_pick(d, ["epithet", "profile", "type", "kind", "trait"], ""))
		out["progress"] = float(_pick(d, ["progress", "next_frac", "frac", "to_next"], -1.0))
		out["next"] = String(_pick(d, ["next", "next_name"], ""))
		out["hint"] = String(_pick(d, ["hint", "next_hint", "advice", "why"], ""))
		var cr: Variant = _pick(d, ["crisis", "crises", "state", "flags", "tags"], [])
		out["crisis"] = _norm_crisis(cr)
		var nd: Variant = _pick(d, ["needs", "next_need", "need", "grow", "reqs", "criteria"], [])
		out["needs"] = _norm_needs(nd)
	else:
		for fn3: String in ["epithet_of", "profile_of"]:
			if ps.has_method(fn3):
				out["epithet"] = String(ps.call(fn3, cid))
				break
		for fn4: String in ["crisis_of", "crises_of"]:
			if ps.has_method(fn4):
				out["crisis"] = _norm_crisis(ps.call(fn4, cid))
				break
		for fn5: String in ["progress_of", "next_frac"]:
			if ps.has_method(fn5):
				out["progress"] = float(ps.call(fn5, cid))
				break
		for fn6: String in ["needs_of", "next_need"]:
			if ps.has_method(fn6):
				out["needs"] = _norm_needs(ps.call(fn6, cid))
				break
	var t: int = int(out["tier"])
	if String(out["name"]) == "" and t >= 0 and t < TIER_NAMES.size():
		out["name"] = TIER_NAMES[t]
	if String(out["name"]) != "" and t < 0:
		out["tier"] = maxi(0, TIER_NAMES.find(String(out["name"]).to_upper()))
	return out





static func _from_pstat(w: GameWorld, ps: Object, cid: int, out: Dictionary) -> Dictionary:
	var lp: Dictionary = ps.call("label_parts", cid)
	var cm: Dictionary = (ps.get_script() as Script).get_script_constant_map() if ps.get_script() != null else {}
	var names: Array = cm.get("TIER_NAMES", TIER_NAMES)
	var t: int = int(lp.get("tier", 0))
	out["tier"] = t
	out["tiers"] = names.size()
	out["tier_names"] = names
	out["name"] = String(lp.get("tier_name", names[clampi(t, 0, names.size() - 1)]))
	out["epithet"] = String(lp.get("epithet_name", ""))
	out["epithet_i"] = int(lp.get("epithet", -1))
	out["epithet_icon"] = String(lp.get("epithet_icon", ""))
	out["tier_icon"] = String(lp.get("tier_icon", ""))
	out["rank"] = int(lp.get("rank", 0))
	out["weight"] = float(lp.get("score", 1.0))
	var stt: int = int(lp.get("state", 0))
	out["state"] = stt
	if stt > 0 and stt <= 3:
		out["crisis"] = [{"name": String(lp.get("state_name", "")), "why": String(STATE_WHY[stt]), "left": -1.0, "icon": String(lp.get("state_icon", ""))}]
	var bars: Array = cm.get("TIER_UP", [])
	if t + 1 < bars.size():
		var p: float = float(ps.call("points", cid))
		out["progress"] = clampf((p - float(bars[t])) / maxf(0.001, float(bars[t + 1]) - float(bars[t])), 0.0, 1.0)
		out["next"] = String(names[t + 1])
	var lm: Variant = ps.get("last_m")
	if lm is Dictionary and (lm as Dictionary).has(cid):
		var d: Dictionary = (lm as Dictionary)[cid]
		var needs: Array = [
			{"key": "city", "name": "ГОРОДА", "have": float(d.get("cp", 0.0)), "need": float(cm.get("D_CITY", 16.0)), "ok": false, "text": ""}, 
			{"key": "eco", "name": "ДОХОД", "have": float(d.get("inc", 0.0)), "need": float(cm.get("D_INC", 5000.0)), "ok": false, "text": ""}, 
			{"key": "army", "name": "СИЛА", "have": float(d.get("mil", 0.0)), "need": float(cm.get("D_MIL", 60.0)), "ok": false, "text": ""}]
		var weak: int = -1
		var wv: float = 9.0
		for i: int in needs.size():
			var n: Dictionary = needs[i]
			var f: float = float(n["have"]) / maxf(0.001, float(n["need"]))
			n["ok"] = f >= 1.0
			if f < wv:
				wv = f
				weak = i
		if weak >= 0 and wv < 1.0 and t + 1 < names.size():
			(needs[weak] as Dictionary)["weak"] = true
		out["needs"] = needs
	return out


static func _pick(d: Dictionary, keys: Array, dflt: Variant) -> Variant:
	for k: String in keys:
		if d.has(k) and d[k] != null:
			return d[k]
	return dflt


static func _norm_crisis(v: Variant) -> Array:
	var out: Array = []
	if v is String:
		if String(v) != "":
			out.append({"name": String(v).to_upper(), "why": "", "left": -1.0})
	elif v is Array:
		for e: Variant in v:
			if e is String and String(e) != "":
				out.append({"name": String(e).to_upper(), "why": "", "left": -1.0})
			elif e is Dictionary:
				var d: Dictionary = e
				var nm: String = String(_pick(d, ["name", "title", "label", "id"], ""))
				if nm != "":
					out.append({"name": nm.to_upper(), "why": String(_pick(d, ["why", "reason", "text", "desc"], "")), "left": float(_pick(d, ["left", "until_left", "t_left"], -1.0))})
	elif v is Dictionary:
		for k: Variant in (v as Dictionary):
			if (v as Dictionary)[k]:
				out.append({"name": String(k).to_upper(), "why": "", "left": -1.0})
	return out


static func _norm_needs(v: Variant) -> Array:
	var out: Array = []
	if not v is Array:
		return out
	for e: Variant in v:
		if e is Dictionary:
			var d: Dictionary = e
			var have: float = float(_pick(d, ["have", "cur", "value", "now", "v"], -1.0))
			var need: float = float(_pick(d, ["need", "goal", "target", "min", "req"], -1.0))
			out.append({"key": String(_pick(d, ["key", "kind", "what", "id"], "")), "name": String(_pick(d, ["name", "label", "title"], "")).to_upper(), 
				"have": have, "need": need, "ok": bool(_pick(d, ["ok", "done", "met"], have >= need and need > 0.0)), "text": String(_pick(d, ["text", "short", "fmt"], ""))})
		elif e is Array and (e as Array).size() >= 3:
			var a: Array = e
			out.append({"key": "", "name": String(a[0]).to_upper(), "have": float(a[1]), "need": float(a[2]), "ok": float(a[1]) >= float(a[2]), "text": ""})
	return out



static func rivals_of(w: GameWorld, cid: int) -> Array:
	var out: Array = []
	var hosts: Array = _hosts(w) + [provider(w)]
	for h: Variant in hosts:
		if h == null:
			continue
		for fn: String in ["rivals_of", "rival_of"]:
			if (h as Object).has_method(fn):
				var v: Variant = (h as Object).call(fn, cid)
				if v is int and int(v) >= 0 and int(v) != cid:
					out.append(int(v))
				elif v is Array:
					for x: Variant in v:
						if (x is int or x is float) and int(x) >= 0 and int(x) != cid:
							out.append(int(x))
				return out
	for h2: Variant in hosts:
		if h2 == null:
			continue
		var d: Variant = (h2 as Object).get("rival")
		if d is Dictionary and (d as Dictionary).has(cid):
			var rv: Variant = (d as Dictionary)[cid]
			if rv is Array:
				for x2: Variant in rv:
					out.append(int(x2))
			elif rv != null and int(rv) >= 0:
				out.append(int(rv))
			return out
	return out




static func _hosts(w: GameWorld) -> Array:
	var out: Array = [w.diplo]
	if w.has_meta("dip331_mock"):
		out.append(w.get_meta("dip331_mock"))
	return out



static func _pair(w: GameWorld, fns: Array, dicts: Array, a: int, b: int) -> bool:
	for d: Object in _hosts(w):
		for fn: String in fns:
			if d.has_method(fn):
				return bool(d.call(fn, a, b))
		for dn: String in dicts:
			var v: Variant = d.get(dn)
			if v is Dictionary:
				return (v as Dictionary).has("%d>%d" % [a, b])
	return false



static func sky_over(w: GameWorld, a: int, b: int) -> bool:
	var sc: Variant = w.diplo.get("sky")
	if sc is Object and sc != null and (sc as Object).has_method("active"):
		return bool((sc as Object).call("active", a, b))
	return _pair(w, ["sky_closed", "sky_on", "has_sky", "sky_over"], ["sky"], a, b)



static func sanctions(w: GameWorld, a: int, b: int) -> Array:
	var tr: Variant = w.econ.get("trd") if w.econ != null else null
	if tr is Object and tr != null and (tr as Object).has_method("sanctions_by"):
		return (tr as Object).call("sanctions_by", a, b)
	for d: Object in _hosts(w):
		for fn: String in ["sanctions_on", "sanctions", "sanct_list"]:
			if d.has_method(fn):
				var v: Variant = d.call(fn, a, b)
				return (v as Array).duplicate() if v is Array else ((v as Dictionary).keys() if v is Dictionary else [])
		var s: Variant = d.get("sanct")
		if s is Dictionary:
			var e: Variant = (s as Dictionary).get("%d>%d" % [a, b], null)
			if e is Dictionary:
				return (e as Dictionary).keys()
			if e is Array:
				return (e as Array).duplicate()
			return []
	return []



static func contract_partners(w: GameWorld, cid: int) -> Array:
	var out: Array = []
	var tr: Variant = w.econ.get("trd") if w.econ != null else null
	if tr is Object and tr != null and (tr as Object).has_method("contracts_of"):
		for k: Dictionary in (tr as Object).call("contracts_of", cid):
			if String(k.get("state", "")) in ["on", "offer"]:
				var o: int = int(k["b"]) if int(k["s"]) == cid else int(k["s"])
				if not out.has(o):
					out.append(o)
		return out
	var cs: Variant = null
	for h: Object in _hosts(w):
		cs = h.get("contracts")
		if cs != null:
			break
	var lst: Array = []
	if cs is Array:
		lst = cs
	elif cs is Dictionary:
		lst = (cs as Dictionary).values()
	for e: Variant in lst:
		if not e is Dictionary:
			continue
		var d: Dictionary = e
		var st: String = str(d.get("state", "")).to_lower()
		if st in ["done", "ended", "cancel", "cancelled", "broken", "refused", "expired"]:
			continue
		var ids: Array = []
		for k: String in ["a", "b", "from", "to", "seller", "buyer", "s", "other"]:
			if d.has(k) and (d[k] is int or d[k] is float):
				ids.append(int(d[k]))
		if ids.has(cid):
			for x: int in ids:
				if x != cid and not out.has(x):
					out.append(x)
	return out


static func tier_col(t: int) -> Color:
	return TIER_COL[clampi(t, 0, TIER_COL.size() - 1)] if t >= 0 else UiKit.MUTED







const ART_EP: Array = ["d331_ep_mil", "d331_ep_ind", "d331_ep_trade", "d331_ep_sea", "d331_ep_rocket"]
const ART_ST: Array = ["", "d331_cr_weak", "d331_cr_outcast", "d331_cr_split", "d331_cr_vassal", "d331_cr_puppet"]


static func art_state(stt: int) -> String:
	return String(ART_ST[stt]) if stt > 0 and stt < ART_ST.size() and UiKit.tex(String(ART_ST[stt])) != null else ""



static func badge(tier: int, crisis: bool, k: int, mini: bool = false, cr_icon: String = "") -> Control:
	var art: String = ("d331_stm_%d" if mini else "d331_st_%d") % (tier + 1)
	if tier >= 0 and UiKit.tex(art) != null:
		var px: float = (12.0 * 1.5) if mini else 20.0 * float(k)
		var box: = Control.new()
		box.custom_minimum_size = Vector2(px, px)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ir: TextureRect = UiKit.icon_rect(art, px)
		box.add_child(ir)
		var ci: TextureRect = null
		if cr_icon != "" and UiKit.tex(cr_icon) != null:
			ci = UiKit.icon_rect(cr_icon, 12.0 * maxf(1.0, float(k) - 1.0))
			box.add_child(ci)
		box.resized.connect( func() -> void :
			ir.position = ((box.size - ir.size) * 0.5).round()
			if ci != null:
				ci.position = (box.size - ci.size + Vector2(4, 2)).round())
		return box
	var c: = Control.new()
	c.custom_minimum_size = Vector2(19 * k, 25 * k)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect( func() -> void : _draw_badge(c, tier, crisis, k))
	return c


const SHIELD: Array = [".XXXXXXXXXXXXXXX.", "XXXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXXX", 
	"XXXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXXX", 
	".XXXXXXXXXXXXXXX.", ".XXXXXXXXXXXXXXX.", "..XXXXXXXXXXXXX..", "...XXXXXXXXXXX...", "....XXXXXXXXX....", ".....XXXXXXX.....", 
	"......XXXXX......", ".......XXX.......", "........X........"]
const CROWN: Array = ["...X....X....X...", "...XX..XXX..XX...", "...XXXXXXXXXXX..."]
const STAR: Array = ["..X..", ".XXX.", "XXXXX", ".XXX.", ".X.X."]
const STAR7: Array = ["...X...", "..XXX..", "XXXXXXX", ".XXXXX.", "..XXX..", ".XX.XX.", ".X...X."]


static func _draw_badge(c: Control, tier: int, crisis: bool, k: int) -> void :
	var px: Dictionary = {}
	var oy: int = 3
	for y: int in SHIELD.size():
		var row: String = SHIELD[y]
		for x: int in row.length():
			if row[x] == "X":
				px[Vector2i(x + 1, y + oy + 1)] = 0
	if tier >= 5:
		for y2: int in CROWN.size():
			var r2: String = CROWN[y2]
			for x2: int in r2.length():
				if r2[x2] == "X":
					px[Vector2i(x2 + 1, y2 + 1)] = 1
	var met: Array = METAL[clampi(tier, 0, METAL.size() - 1)] if tier >= 0 else ["6a6e58", "9a9e88", "3a3c32"]
	var rim: = Color(String(met[0]))
	var rim_hi: = Color(String(met[1]))
	var rim_sh: = Color(String(met[2]))
	var field: = Color("4a1616") if crisis else (Color("1d2a4a") if tier >= 0 else Color("2c2d27"))
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var diag: Array = dirs + [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

	var depth: Dictionary = {}
	for p: Vector2i in px:
		var d: int = 3
		for dv: Vector2i in diag:
			if not px.has(p + dv):
				d = 1
				break
		if d == 3:
			for dv2: Vector2i in diag:
				var q: Vector2i = p + dv2 * 2
				var q1: Vector2i = p + dv2
				if not px.has(q) or not px.has(q1 + dv2):
					d = 2
					break
		depth[p] = d
	for p0: Vector2i in px:
		for dv0: Vector2i in diag:
			if not px.has(p0 + dv0):
				c.draw_rect(Rect2(Vector2((p0 + dv0) * k), Vector2(k, k)), UiKit.OUTLINE)
	var cx: float = 9.0
	for p2: Vector2i in px:
		var colr: Color
		if int(px[p2]) == 1:
			colr = rim_hi if p2.y <= 2 else rim
		else:
			match int(depth[p2]):
				1:
					colr = rim_hi if (float(p2.x) < cx and p2.y <= oy + 11) else (rim_sh if (float(p2.x) > cx + 1.0 or p2.y >= oy + 15) else rim)
				2:
					colr = rim_sh.darkened(0.2)
				_:
					colr = field.lightened(0.1) if p2.y <= oy + 4 else field
		c.draw_rect(Rect2(Vector2(p2 * k), Vector2(k, k)), colr)
	var stars: Array = []
	match int(TIER_STARS[clampi(tier, 0, TIER_STARS.size() - 1)]) if tier >= 0 else 0:
		1:
			stars = [Vector2i(6, oy + 5)]
		2:
			stars = [Vector2i(4, oy + 6), Vector2i(10, oy + 6)]
		3:
			stars = [Vector2i(7, oy + 3), Vector2i(4, oy + 9), Vector2i(10, oy + 9)]
	var pat: Array = STAR7 if stars.size() == 1 else STAR
	for s0: Vector2i in stars:
		for sy: int in pat.size():
			for sx: int in String(pat[sy]).length():
				if String(pat[sy])[sx] == "X":
					c.draw_rect(Rect2(Vector2((s0 + Vector2i(sx, sy)) * k), Vector2(k, k)), rim_hi if sy * 2 < pat.size() else rim)
	if crisis:
		for cp: Vector2i in [Vector2i(11, oy + 11), Vector2i(10, oy + 12), Vector2i(10, oy + 13), Vector2i(9, oy + 14), Vector2i(9, oy + 15)]:
			c.draw_rect(Rect2(Vector2(cp * k), Vector2(k, k)), Color("ff6a4d"))




func rebuild(keep_scroll: bool = true) -> void :
	var sv: int = scroll.scroll_vertical if keep_scroll and scroll != null and is_instance_valid(scroll) else 0
	rebuilds += 1
	for c: Node in col.get_children():
		col.remove_child(c)
		c.queue_free()
	_timers.clear()
	scroll = null
	if gw.player == null:
		return
	_build()
	_fit_scroll()
	_sig = _struct_sig()
	if sv > 0 and scroll != null:
		var sc: ScrollContainer = scroll
		sc.set_deferred("scroll_vertical", sv)
		get_tree().process_frame.connect( func() -> void :
			if is_instance_valid(sc):
				sc.scroll_vertical = sv, CONNECT_ONE_SHOT)


func _alive_others() -> Array:
	var out: Array = []
	for c: Country in gw.countries:
		if c.id != me and not c.eliminated and c.capital_id >= 0:
			out.append(c)
	return out


func _struct_sig() -> String:
	if gw.player == null:
		return ""
	var s: String = "%s|" % gw.player.eliminated
	var st: Dictionary = status_of(gw, me)
	s += "%d:%s:%s:%d|" % [int(st["tier"]), String(st["epithet"]), str(st["crisis"]), (st["needs"] as Array).size()]
	for c: Country in _alive_others():
		var o: int = c.id
		s += "%d:%d:%s:%s%s%s%s%s%s;" % [o, dp.get_rel(me, o), ",".join(PackedStringArray(dp.treaties_of(me, o))), dp.embargoed(me, o), dp.embargoed(o, me), 
			dp.has_passage(me, o), dp.has_passage(o, me), sky_over(gw, me, o), sky_over(gw, o, me)]
		s += "%s%s" % [str(sanctions(gw, me, o)), str(sanctions(gw, o, me))]
	s += "|p%d" % dp.pending_for_player().size()
	s += "|r%s" % str(rivals_of(gw, me))
	s += "|c%s" % str(contract_partners(gw, me))
	if dp.get("ally") != null:
		var a: Dictionary = dp.ally.of_country(me)
		s += "|a%s:%d" % [String(a.get("name", "")), (a.get("members", []) as Array).size()]
	s += "|v%d:%d" % [dp.subject_of(me), dp.subjects_of(me).size()]
	if dp.has_method("subject_wars"):
		for sid: int in dp.subjects_of(me):
			s += ":%s" % str(dp.subject_wars(sid).get("with", []))
	var dr: Object = gw.get("drama") as Object
	if dr != null and dr.has_method("chronicle"):
		s += "|h%d" % (dr.get("chron") as Array).size() if dr.get("chron") is Array else ""
	if not dp.coalition.is_empty():
		s += "|k%d" % int(dp.coalition["leader"])
	return s


func _build() -> void :
	_header()
	_new_scroll()
	_hero()
	_inbox_pin()
	var wars: Array = _wars()
	if not wars.is_empty():
		_wars_block(wars)
	_subjects_block()
	_numbers()
	_army_budget()
	_alliance_block()
	_ledger()
	_relations()
	_chronicle_block()
	var tail: = Control.new()
	tail.custom_minimum_size.y = 4
	inner.add_child(tail)


func _header() -> void :
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	hr.custom_minimum_size.y = 40
	col.add_child(hr)
	var p: Country = gw.player
	var fl: Control = _flag(p, Vector2(30, 19))
	hr.add_child(fl)
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", -3)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(tv)
	var k: Label = UiKit.lbl("ВАША СТРАНА", 9, UiKit.MUTED, 2, 2)
	tv.add_child(k)
	var t: Label = UiKit.lbl(Loc.name(p.name).to_upper(), 18, UiKit.TITLE, 3, 4)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fit_lbl(t, [18, 16, 14], false)
	tv.add_child(t)
	var cb: Button = UiKit.close_btn(UiKit.TOUCH_MIN)
	cb.pressed.connect( func() -> void : close_sheet())
	hr.add_child(cb)


func _new_scroll() -> void :
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll_wrap = MarginContainer.new()
	scroll_wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(scroll_wrap)
	scroll_wrap.add_child(scroll)
	_fade_top = _fade(true)
	_fade_bot = _fade(false)
	scroll_wrap.add_child(_fade_top)
	scroll_wrap.add_child(_fade_bot)
	scroll.get_v_scroll_bar().value_changed.connect( func(_v: float) -> void : _update_fades())
	inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)


func _fit_scroll() -> void :
	if scroll == null or not is_instance_valid(scroll):
		return
	var fixed: float = 0.0
	var n: int = 0
	for c: Node in col.get_children():
		if c != scroll_wrap and c is Control and (c as Control).visible:
			fixed += (c as Control).get_combined_minimum_size().y
			n += 1
	fixed += float(n) * 6.0 + 20.0 + float(hud._safe_margins().y)
	var want: float = inner.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = clampf(want, 60.0, maxf(60.0, max_h - fixed))
	_update_fades.call_deferred()


func _update_fades() -> void :
	if scroll == null or not is_instance_valid(scroll) or _fade_top == null:
		return
	var mx: float = inner.size.y - scroll.size.y
	_fade_top.visible = scroll.scroll_vertical > 2
	_fade_bot.visible = mx > 2.0 and scroll.scroll_vertical < mx - 2.0




func _hero() -> void :
	var st: Dictionary = status_of(gw, me)
	_st = st
	var tier: int = int(st["tier"])
	var crisis: Array = st["crisis"]
	var card: = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 10, 8))
	inner.add_child(card)
	card.add_child(_rim((C_WAR if not crisis.is_empty() else tier_col(tier)).darkened(0.15)))
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)

	var vm: = MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		vm.add_theme_constant_override(side, 6)
	vm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vm)
	vm.add_child(vb)
	var top: = HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vb.add_child(top)
	top.add_child(badge(tier, not crisis.is_empty(), 3 if not compact() else 2, false, art_state(int(st.get("state", 0)))))
	var tc: = VBoxContainer.new()
	tc.add_theme_constant_override("separation", 1)
	tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(tc)
	tc.add_child(UiKit.lbl("СТАТУС СТРАНЫ", 9, UiKit.MUTED, 2, 2))
	var tn: Label = UiKit.lbl(String(st["name"]) if tier >= 0 else "—", 24 if not compact() else 20, tier_col(tier), 3, 4)
	tn.name = "StatusTitle"
	tn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fit_lbl(tn, [24, 22, 20, 18, 16] if not compact() else [20, 18, 16, 14])
	tc.add_child(tn)
	var bits: PackedStringArray = PackedStringArray()
	if String(st["epithet"]) != "":
		bits.append(String(st["epithet"]).to_upper())
	var rk: int = int(st.get("rank", 0)) if int(st.get("rank", 0)) > 0 else _rank_of(me)
	if rk > 0:
		bits.append((Loc.t("%d-е по силе в мире") % rk) if int(st.get("rank", 0)) > 0 else (Loc.t("%d-е место в мире") % rk))
	var el: Label = UiKit.lbl(" · ".join(bits) if not bits.is_empty() else Loc.t("тип страны: —"), 11, UiKit.TEXT, 2, 2)
	el.name = "StatusEpithet"
	el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fit_lbl(el, [11, 10])
	var er: = HBoxContainer.new()
	er.add_theme_constant_override("separation", 4)
	var ep: int = int(st.get("epithet_i", -1))
	if ep >= 0 and ep < ART_EP.size() and UiKit.tex(String(ART_EP[ep])) != null:
		er.add_child(_icon(String(ART_EP[ep]), 12))
	er.add_child(el)
	tc.add_child(er)
	var tags: = HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 4)
	tags.add_theme_constant_override("v_separation", 4)
	for cr: Dictionary in crisis:
		var ci: String = art_state(int(st.get("state", 0)))
		if ci == "":
			ci = String(cr.get("icon", ""))
		tags.add_child(_tag(String(cr["name"]), C_WAR, ci if ci != "" and UiKit.tex(ci) != null else "icon_dip_crisis"))
	var nw: int = 0
	for w: int in _wars():
		if dp.get_rel(me, w) == Diplomacy.Rel.WAR:
			nw += 1
	if nw > 0:
		tags.add_child(_tag(Loc.t("ВОЙНА: %d") % nw, C_WAR, "icon_rel_war"))
	elif crisis.is_empty():
		tags.add_child(_tag("МИР СО ВСЕМИ", C_PEACE, "icon_rel_peace"))
	if dp.is_subject(me) and dp.subject_of(me) > 0:
		var pup: bool = dp.subject_kind(me) == "puppet"
		var vi: String = art_state(5 if pup else 4)
		tags.add_child(_tag("%s: %s" % [Loc.t("МАРИОНЕТКА") if pup else Loc.t("ВАССАЛ"), Loc.name(_cname(dp.subject_of(me)))], C_TRUCE, vi if vi != "" else "icon_dip_vassal_16"))
	var subs: Array = dp.subjects_of(me)
	if not subs.is_empty():
		tags.add_child(_tag(Loc.t("ВАССАЛОВ: %d") % subs.size(), UiKit.GOLD, "icon_dip_vassal_16"))
	if not dp.coalition.is_empty() and int(dp.coalition["leader"]) == me:
		tags.add_child(_tag(Loc.t("ПРОТИВ ВАС КОАЛИЦИЯ: %d") % (dp.coalition["members"] as Array).size(), C_WAR, "icon_coalition"))
	tc.add_child(tags)
	for cr2: Dictionary in crisis:
		if String(cr2["why"]) != "":
			var why: Label = UiKit.lbl("%s: %s" % [String(cr2["name"]), String(cr2["why"])] + ((Loc.t(" · ещё %s") % _mmss(float(cr2["left"]))) if float(cr2["left"]) > 0.0 else ""), 10, Color("ffb3a3"), 1, 2)
			why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(why)
	vb.add_child(_ladder(tier, float(st["progress"])))
	var nxt: String = ""
	var top_t: int = int(st.get("tiers", TIER_NAMES.size())) - 1
	if tier >= 0 and tier < top_t:
		var pr: float = float(st["progress"])
		nxt = Loc.t("ДО %s") % Loc.t(String(TIER_GEN[clampi(tier + 1, 0, TIER_GEN.size() - 1)])) + ((" — " + Loc.pct(roundi(clampf(pr, 0.0, 1.0) * 100.0))) if pr >= 0.0 else "")
	elif tier >= top_t:
		nxt = "ВЫСШИЙ СТАТУС — УДЕРЖИВАЙТЕ"
	if nxt != "":
		var nr: = HBoxContainer.new()
		vb.add_child(nr)
		var nl: Label = UiKit.lbl(nxt, 10, UiKit.TITLE, 2, 3)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nr.add_child(nl)
		if st.has("weight"):
			var wl: Label = UiKit.lbl(Loc.t("вес в мире ×%s") % _x(float(st["weight"])), 9, UiKit.MUTED, 2, 2)
			nr.add_child(wl)
	var extra: Array = (st["needs"] as Array).filter( func(n: Dictionary) -> bool: return _tile_key(n) == "")
	if not extra.is_empty():
		var g: = HBoxContainer.new()
		g.add_theme_constant_override("separation", 4)
		vb.add_child(g)
		for i: int in mini(3, extra.size()):
			g.add_child(_need_pill(extra[i]))
	if String(st["hint"]) != "":
		var hl: Label = UiKit.lbl(String(st["hint"]), 10, UiKit.MUTED, 1, 2)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(hl)
	if tier < 0:
		var ul: Label = UiKit.lbl("Статус по развитию: от МОЛОДОЙ РЕСПУБЛИКИ до СВЕРХДЕРЖАВЫ. Данных пока нет.", 10, UiKit.MUTED, 1, 2)
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(ul)



static func fit_lbl(l: Label, sizes: Array, wrap: bool = true) -> void :
	UiKit.fit_lbl(l, sizes, wrap)




func _tile_key(n: Dictionary) -> String:
	var ic: String = _need_icon(String(n["key"]), String(n["name"]))
	match ic:
		"icon_tank":
			return "army"
		"res_money":
			return "eco"
		"icon_city":
			return "city"
		"land":
			return "land"
	if (String(n["key"]) + Loc.src_of(String(n["name"]))).to_lower().contains("земл") or String(n["key"]).to_lower().contains("land") or Loc.src_of(String(n["name"])).to_lower().contains("терр"):
		return "land"
	return ""




func _ladder(tier: int, prog: float) -> Control:
	var names: Array = _st.get("tier_names", TIER_NAMES)
	var n: int = names.size()
	var c: = Control.new()
	c.custom_minimum_size = Vector2(0, 30)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect( func() -> void :
		var w: float = c.size.x
		var x0: float = 9.0
		var x1: float = w - 9.0
		var y: float = 8.0
		var step: float = (x1 - x0) / float(maxi(1, n - 1))
		c.draw_rect(Rect2(x0, y - 3.0, x1 - x0, 6.0), UiKit.OUTLINE)
		c.draw_rect(Rect2(x0 + 1.0, y - 2.0, x1 - x0 - 2.0, 4.0), Color("2c2d27"))
		if tier >= 0:
			var pos: float = float(tier) + (clampf(prog, 0.0, 1.0) if tier < n - 1 and prog >= 0.0 else 0.0)
			var fx: float = x0 + step * pos
			c.draw_rect(Rect2(x0 + 1.0, y - 2.0, maxf(0.0, fx - x0 - 1.0), 4.0), tier_col(tier).darkened(0.1))
			c.draw_rect(Rect2(x0 + 1.0, y - 2.0, maxf(0.0, fx - x0 - 1.0), 1.0), tier_col(tier).lightened(0.3))
		var f: Font = UiKit.f_bold
		for i: int in n:
			var nx: float = roundf(x0 + step * float(i))
			var reached: bool = tier >= i
			var cur: bool = tier == i
			var r: float = 7.0 if cur else 4.0
			c.draw_rect(Rect2(nx - r - 1.0, y - r - 1.0, 2.0 * r + 2.0, 2.0 * r + 2.0), UiKit.OUTLINE)
			c.draw_rect(Rect2(nx - r, y - r, 2.0 * r, 2.0 * r), tier_col(i) if reached else Color("3a3b33"))
			if reached:
				c.draw_rect(Rect2(nx - r, y - r, 2.0 * r, 2.0), tier_col(i).lightened(0.35))
			if cur:
				c.draw_rect(Rect2(nx - 2.0, y - 2.0, 4.0, 4.0), Color("1d2a4a"))
		var labels: Array = []
		if tier >= 0:
			labels.append([tier, tier_col(tier)])
		if tier < n - 1:
			labels.append([n - 1, UiKit.DIM])
		var used: Array = []
		for lb: Array in labels:
			var i2: int = int(lb[0])
			var s: String = Loc.t(String(names[i2]))
			var tw: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			var nx2: float = x0 + step * float(i2)
			var lx: float = clampf(nx2 - tw * 0.5, 3.0, w - tw - 3.0)
			var hit: bool = false
			for u: Array in used:
				if lx < float(u[1]) + 6.0 and lx + tw > float(u[0]) - 6.0:
					hit = true
			if hit:
				continue
			used.append([lx, lx + tw])
			c.draw_string(f, Vector2(roundf(lx), y + 20.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, lb[1] as Color))
	return c


func _need_pill(n: Dictionary) -> Control:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 44
	for s: String in ["normal", "hover", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, UiKit.sb("wb_pill", 6, 3))
	b.add_theme_stylebox_override("pressed", UiKit.sb("wb_slot_pressed", 6, 3))
	b.add_theme_stylebox_override("hover_pressed", UiKit.sb("wb_slot_pressed", 6, 3))
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 6
	vb.offset_right = -6
	vb.offset_top = 4
	vb.offset_bottom = -4
	b.add_child(vb)
	var ok: bool = bool(n["ok"])
	var hr: = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 3)
	hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hr)
	var ic: String = _need_icon(String(n["key"]), String(n["name"]))
	hr.add_child(_icon(LAND_ICON if ic == "land" else ic, 12))
	var nl: Label = UiKit.lbl(String(n["name"]), 9, UiKit.MUTED, 2, 2)
	nl.clip_text = true
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(nl)
	if ok:
		hr.add_child(_icon("corner_check", 10))
	var have: float = float(n["have"])
	var need: float = float(n["need"])
	var txt: String = String(n["text"])
	if txt == "":
		txt = ("%s / %s" % [_short(have), _short(need)]) if need > 0.0 else "—"
	var vl: Label = UiKit.lbl(txt, 11, C_PEACE if ok else UiKit.TEXT, 2, 2)
	vl.clip_text = true
	vb.add_child(vl)
	var frac: float = clampf(have / need, 0.0, 1.0) if need > 0.0 else 0.0
	var bar: = Control.new()
	bar.custom_minimum_size = Vector2(0, 3)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect( func() -> void :
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(0, 0, 0, 0.5))
		bar.draw_rect(Rect2(0, 0, roundf(bar.size.x * frac), bar.size.y), C_PEACE if ok else UiKit.GOLD))
	vb.add_child(bar)
	var key: String = String(n["key"]) + Loc.src_of(String(n["name"])).to_lower()
	b.pressed.connect( func() -> void : _goto_need(key))
	return b



func _need_icon(key: String, nm: String) -> String:
	var s: String = (key + " " + Loc.src_of(nm)).to_lower()
	if s.contains("arm") or s.contains("арм") or s.contains("mil") or s.contains("воен"):
		return "icon_tank"
	if s.contains("eco") or s.contains("эконом") or s.contains("доход") or s.contains("money") or s.contains("income"):
		return "res_money"
	if s.contains("city") or s.contains("город"):
		return "icon_city"
	if s.contains("land") or s.contains("терр") or s.contains("земл"):
		return "land"
	if s.contains("ally") or s.contains("союз") or s.contains("альян") or s.contains("влия"):
		return "icon_alliance"
	if s.contains("score") or s.contains("очк"):
		return "res_score"
	return "icon_stats"



func _goto_need(key: String) -> void :
	UiKit.snd("ui_click")
	if key.contains("arm") or key.contains("арм") or key.contains("mil") or key.contains("воен"):
		close_sheet()
		hud.action.emit("armies")
	elif key.contains("eco") or key.contains("эконом") or key.contains("доход") or key.contains("income") or key.contains("money"):
		if hud.has_method("open_hub"):
			hud.call("open_hub", 0)
	elif key.contains("city") or key.contains("город") or key.contains("land") or key.contains("терр") or key.contains("земл"):
		close_sheet()
		hud.action.emit("map_mode:%d" % GameWorld.MapMode.MY_LAND)




func _inbox_pin() -> void :
	var list: Array = dp.pending_for_player()
	if list.is_empty():
		return
	var it: Dictionary = list[0]
	var pc: = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 5))
	inner.add_child(pc)
	pc.add_child(_rim(UiKit.GOLD.darkened(0.2)))
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	pc.add_child(hb)
	hb.add_child(_icon("icon_dip_call", 24))
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(tv)
	tv.add_child(UiKit.lbl(Loc.t("ЖДУТ ВАШЕГО ОТВЕТА: %d") % list.size(), 11, UiKit.TEXT, 2, 3))
	var sub: Label = UiKit.lbl("", 10, UiKit.MUTED, 1, 2)
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(sub)
	UiKit.fit_lbl(sub, [10, 9], false)
	var who: String = _cname(int(it.get("from", -1)))
	var pre: String = Loc.t("%s · ответ до ") % who
	sub.text = pre + _mmss(float(it.get("left", 0.0))) if float(it.get("left", 0.0)) >= 0.0 else Loc.t("%s · без срока") % who
	_timers.append([sub, "deadline", float(it.get("deadline", 0.0)), pre, Loc.t("%s · без срока") % who])
	var ob: Button = UiKit.big("ОТВЕТИТЬ", "gold", "", 44.0, 11)
	ob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ob.pressed.connect( func() -> void :
		UiKit.snd("ui_click")
		if hud.has_method("open_inbox"):
			hud.call("open_inbox"))
	hb.add_child(ob)






func _army_budget() -> void :
	var ab: Control = (preload("res://ui/ui24/army_budget.gd")).make(gw, true)
	ab.connect("open_more", func() -> void :
		if hud.has_method("open_hub"):
			hud.call("open_hub", 2))
	inner.add_child(ab)


func _numbers() -> void :
	var p: Country = gw.player
	var rows: Array = []
	var land: Dictionary = _land_counts()
	var lt: int = 0
	for v: Variant in land.values():
		lt += int(v)
	var my_land: int = int(land.get(me, 0))
	rows.append(["icon_tank", str(gw.army.count_units(me)) if gw.army != null else "—", "АРМИЯ, ОТР.", _rank_by( func(c: Country) -> float: return float(gw.army.count_units(c.id)) if gw.army != null else 0.0), "army"])
	var inc: int = _income(me)
	rows.append(["res_money", ("+" if inc >= 0 else "−") + _short(absf(float(inc))) if inc != -99999 else "—", "ДОХОД/МИН", _rank_by( func(c: Country) -> float: return float(_income(c.id))) if inc != -99999 else 0, "eco"])
	rows.append([LAND_ICON, ("%d%%" % roundi(100.0 * float(my_land) / float(lt))) if lt > 0 else "—", "ЗЕМЛИ МИРА", _rank_by( func(c: Country) -> float: return float(land.get(c.id, 0))), "land"])
	rows.append(["icon_city", str(p.city_ids.size()), "ГОРОДА", _rank_by( func(c: Country) -> float: return float(c.city_ids.size())), "city"])
	var needs: Array = _st.get("needs", [])
	var g: = HBoxContainer.new()
	g.add_theme_constant_override("separation", 4)
	inner.add_child(g)
	for r: Array in rows:
		var goal: Dictionary = {}
		for n: Dictionary in needs:
			if _tile_key(n) == String(r[4]):
				goal = n
				break
		g.add_child(_num_tile(r, goal))


func _num_tile(r: Array, goal: Dictionary) -> Control:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 56)
	for s: String in ["normal", "hover", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, UiKit.sb("wb_slot", 4))
	b.add_theme_stylebox_override("pressed", UiKit.sb("wb_slot_pressed", 4))
	b.add_theme_stylebox_override("hover_pressed", UiKit.sb("wb_slot_pressed", 4))
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 5
	vb.offset_right = -5
	b.add_child(vb)
	var cap: Label = UiKit.lbl(String(r[2]), 9, UiKit.MUTED, 2, 2)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(cap)
	UiKit.fit_lbl(cap, [9, 8], false, true)
	var hr: = HBoxContainer.new()
	hr.alignment = BoxContainer.ALIGNMENT_CENTER
	hr.add_theme_constant_override("separation", 3)
	hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hr)
	hr.add_child(_icon(String(r[0]), 14))
	var val: String = String(r[1])
	var ok: bool = false
	var frac: float = -1.0
	var tgt: String = ""
	var weak: bool = bool(goal.get("weak", false))
	if not goal.is_empty():
		ok = bool(goal["ok"])
		var have: float = float(goal["have"])
		var need: float = float(goal["need"])
		if String(goal["text"]) != "":
			var tp: PackedStringArray = String(goal["text"]).split("/")
			val = tp[0].strip_edges()
			tgt = ("/ " + tp[1].strip_edges()) if tp.size() > 1 else ""
		frac = clampf(have / need, 0.0, 1.0) if need > 0.0 else 0.0
	hr.add_child(UiKit.lbl(val, 13 if not compact() else 12, C_PEACE if ok else UiKit.TEXT, 2, 3))
	if tgt != "" and (val + tgt).length() <= 9:
		hr.add_child(UiKit.lbl(tgt, 9, UiKit.MUTED, 2, 2))
	if frac >= 0.0:
		var bar: = Control.new()
		bar.custom_minimum_size = Vector2(0, 3)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw.connect( func() -> void :
			bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(0, 0, 0, 0.5))
			bar.draw_rect(Rect2(0, 0, roundf(bar.size.x * frac), bar.size.y), C_PEACE if ok else (UiKit.GOLD if weak else UiKit.MUTED)))
		vb.add_child(bar)
		if weak:
			var wl: Label = UiKit.lbl("▲ РАСТИТЬ", 9, UiKit.GOLD, 2, 2)
			wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vb.add_child(wl)
			b.add_child(_rim(UiKit.GOLD.darkened(0.25)))
	else:
		var rk: int = int(r[3])
		var rl: Label = UiKit.lbl((Loc.t("%d-е в мире") % rk) if rk > 1 and rk <= 3 else (Loc.t("1-е в мире") if rk == 1 else " "), 9, UiKit.GOLD if rk == 1 else UiKit.DIM, 2, 2)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(rl)
	var key: String = String(r[4])
	b.pressed.connect( func() -> void : _goto_need(key))
	return b


func _land_counts() -> Dictionary:
	var out: Dictionary = {}
	if gw.data == null:
		return out
	var own: PackedByteArray = gw.data.owners
	for c: Country in gw.countries:
		if not c.eliminated:
			out[c.id] = own.count(c.id)
	return out




func _income(cid: int) -> int:
	if gw.econ == null or not gw.econ.has_method("stats"):
		return -99999
	var sd: Variant = gw.econ.get("_stats")
	if not (sd is Dictionary and (sd as Dictionary).has(cid)):
		return 0
	var c: Country = gw.country_by_id(cid)
	if c == null:
		return 0
	var st: Dictionary = gw.econ.stats(c)
	var t: int = 0
	for k: Variant in st.get("income", {}):
		t += int(st["income"][k])
	for k2: Variant in st.get("spend", {}):
		t -= int(st["spend"][k2])
	return t


func _rank_by(f: Callable) -> int:
	var mine: float = 0.0
	var vals: Array = []
	for c: Country in gw.countries:
		if c.eliminated or c.capital_id < 0:
			continue
		var v: float = float(f.call(c))
		vals.append(v)
		if c.id == me:
			mine = v
	var r: int = 1
	for v2: float in vals:
		if v2 > mine:
			r += 1
	return r


func _rank_of(cid: int) -> int:
	var c0: Country = gw.country_by_id(cid)
	if c0 == null:
		return -1
	var r: int = 1
	for c: Country in gw.countries:
		if not c.eliminated and c.id != cid and c.score > c0.score:
			r += 1
	return r




func _wars() -> Array:
	var out: Array = []
	for c: Country in _alive_others():
		var r: int = dp.get_rel(me, c.id)
		if r == Diplomacy.Rel.WAR or r == Diplomacy.Rel.TRUCE:
			out.append(c.id)
	out.sort_custom( func(a: int, b: int) -> bool:
		var ra: int = dp.get_rel(me, a)
		var rb: int = dp.get_rel(me, b)
		if ra != rb:
			return ra == Diplomacy.Rel.WAR
		return dp.war_time(me, a) > dp.war_time(me, b))
	return out


func _wars_block(wars: Array) -> void :
	var nw: int = 0
	for w: int in wars:
		if dp.get_rel(me, w) == Diplomacy.Rel.WAR:
			nw += 1
	inner.add_child(_section(Loc.t("ВОЙНЫ · %d") % nw if nw > 0 else Loc.t("ПЕРЕМИРИЕ"), C_WAR if nw > 0 else C_TRUCE))
	for w2: int in wars:
		inner.add_child(_war_row(w2))


func _war_row(cid: int) -> Control:
	var c: Country = gw.country_by_id(cid)
	var r: int = dp.get_rel(me, cid)
	var war: bool = r == Diplomacy.Rel.WAR
	var b: Button = _row_btn(ROW_H + 2.0)
	var hb: HBoxContainer = _row_box(b)
	hb.add_child(_flag(c, Vector2(26, 16)))
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", -1)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tv)
	var nl: Label = UiKit.lbl(Loc.name(c.name).to_upper(), 12, UiKit.TEXT, 2, 3)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(nl)
	var sub: Label = UiKit.lbl("", 10, UiKit.MUTED, 1, 2)
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(sub)
	UiKit.fit_lbl(sub, [10, 9], false)
	if war:
		var by: int = int(dp.war_by.get(Diplomacy.key(me, cid), -1))
		var pre: String = Loc.t("%s · идёт ") % [(Loc.t("напали на вас") if by == cid else (Loc.t("вы объявили") if by == me else Loc.t("война")))]
		sub.text = pre + _mmss(dp.war_time(me, cid))
		_timers.append([sub, "war", cid, pre])
	else:
		var tu: float = float(dp.truce_until.get(Diplomacy.key(me, cid), gw.game_time))
		var pre2: String = Loc.t("перемирие · мир через ")
		sub.text = pre2 + _mmss(tu - gw.game_time)
		_timers.append([sub, "deadline", tu, pre2])
	var rv: = VBoxContainer.new()
	rv.add_theme_constant_override("separation", -1)
	rv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(rv)
	var sl: Label = UiKit.lbl(Loc.t("ВОЙНА") if war else Loc.t("ПЕРЕМИРИЕ"), 10, C_WAR if war else C_TRUCE, 2, 3)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(sl)
	var ratio: float = dp.strength(cid) / maxf(1.0, dp.strength(me))
	var rt: String = "сила равна"
	var rc: Color = UiKit.MUTED
	if ratio >= 1.15:
		rt = Loc.t("сильнее ×%s") % _x(ratio)
		rc = Color("ffb3a3")
	elif ratio <= 0.87:
		rt = Loc.t("слабее ×%s") % _x(1.0 / maxf(0.01, ratio))
		rc = C_PEACE
	var ql: Label = UiKit.lbl(rt, 10, rc, 1, 2)
	ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(ql)
	hb.add_child(_chev())
	b.pressed.connect( func() -> void : _open_country(cid))
	return b




func _subjects_block() -> void :
	var subs: Array = dp.subjects_of(me)
	if subs.is_empty() or not dp.has_method("subject_wars"):
		return
	var np: int = 0
	for sid0: int in subs:
		if dp.subject_kind(sid0) == "puppet":
			np += 1
	var ttl: String = Loc.t("МАРИОНЕТКИ") if np == subs.size() else (Loc.t("ВАССАЛЫ") if np == 0 else Loc.t("МАРИОНЕТКИ И ВАССАЛЫ"))
	inner.add_child(_section("%s · %d" % [ttl, subs.size()], UiKit.GOLD))
	for sid: int in subs:
		var c: Country = gw.country_by_id(sid)
		if c == null:
			continue
		var sw: Dictionary = dp.subject_wars(sid)
		var pup: bool = String(sw.get("kind", "")) == "puppet"
		var w_with: PackedStringArray = []
		for e: int in (sw.get("with", []) as Array):
			w_with.append(_cname(e))
		var w_not: PackedStringArray = []
		for pr: Array in (sw.get("not", []) as Array):
			w_not.append(_cname(int(pr[0])))
		var b: Button = _row_btn(ROW_H + 2.0)
		b.name = "Subject_%d" % sid
		var hb: HBoxContainer = _row_box(b)
		hb.add_child(_flag(c, Vector2(26, 16)))
		var tv: = VBoxContainer.new()
		tv.add_theme_constant_override("separation", -1)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tv)
		var nl: Label = UiKit.lbl(Loc.name(c.name).to_upper(), 12, UiKit.TEXT, 2, 3)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fit_lbl(nl, [12, 11, 10], false)
		tv.add_child(nl)
		var line: String = Loc.t("следует за вами · %s") % [((Loc.t("войны: ") + ", ".join(w_with)) if not w_with.is_empty() else Loc.t("войн нет"))]
		var colr: Color = C_PEACE if w_not.is_empty() else C_TRUCE
		if not w_not.is_empty():
			line = Loc.t("вступает в ваши войны: %s") % [", ".join(w_not)]
		var sub: Label = UiKit.lbl(line, 10, colr, 1, 2)
		sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fit_lbl(sub, [10, 9], false)
		tv.add_child(sub)
		var kl: Label = UiKit.lbl(Loc.t("МАРИОНЕТКА") if pup else Loc.t("ВАССАЛ"), 9, UiKit.GOLD, 2, 2)
		kl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(kl)
		hb.add_child(_chev())
		b.pressed.connect( func() -> void : _open_country(sid))
		inner.add_child(b)




func _chronicle_block() -> void :
	var dr: Object = gw.get("drama") as Object
	if dr == null or not dr.has_method("chronicle"):
		return
	inner.add_child(_section("ХРОНИКА МИРА", UiKit.TITLE))
	var ch: Array = dr.call("chronicle")
	if ch.is_empty():
		var el: Label = UiKit.lbl("Пока тихо. Войны, союзы, падения столиц и расколы появятся здесь.", 10, UiKit.MUTED, 1, 2)
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		el.name = "ChronEmpty"
		inner.add_child(el)
		return
	var n: int = 0
	for i: int in range(ch.size() - 1, -1, -1):
		if n >= 5:
			break
		n += 1
		var e: Dictionary = ch[i]
		var go: int = 0
		for x: int in [int(e.get("a", 0)), int(e.get("b", 0))]:
			var cx: Country = gw.country_by_id(x) if x > 0 else null
			if go == 0 and x != me and cx != null and not cx.eliminated:
				go = x
		var red: bool = String(e.get("kind", "")) in ["partition", "coalition", "backstab", "war", "capital", "city", "gone", "crisis"]
		var b: Button = _row_btn(40.0)
		b.name = "Chron_%d" % n
		var hb: HBoxContainer = _row_box(b)
		var bar: = ColorRect.new()
		bar.color = C_WAR if red else C_TRUCE
		bar.custom_minimum_size = Vector2(3, 0)
		bar.size_flags_vertical = Control.SIZE_FILL
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(bar)
		var age: int = maxi(0, int(gw.game_time - float(e.get("t", 0.0))) / 60)
		var tl: Label = UiKit.lbl(Loc.t("сейчас") if age < 1 else ((Loc.t("%d мин") % age) if age < 60 else (Loc.t("%d ч") % (age / 60))), 9, UiKit.MUTED, 1, 2)
		tl.custom_minimum_size.x = 40
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(tl)
		var txt: String = String(e.get("text", ""))
		var l: Label = UiKit.lbl(txt, 10, UiKit.TEXT, 1, 2)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(l)
		l.resized.connect( func() -> void :
			if is_instance_valid(l) and is_instance_valid(b):
				b.custom_minimum_size.y = maxf(40.0, float(l.get_line_count() * l.get_line_height()) + 10.0))
		if go > 0:
			hb.add_child(_chev())
			b.pressed.connect( func() -> void : _open_country(go))
		else:
			b.disabled = true
		inner.add_child(b)




func _alliance_block() -> void :
	inner.add_child(_section("АЛЬЯНС", UiKit.TITLE))
	var a: Dictionary = dp.ally.of_country(me) if dp.get("ally") != null else {}
	if a.is_empty():
		var b0: Button = _row_btn(40.0)
		var h0: HBoxContainer = _row_box(b0)
		h0.add_child(_icon("icon_alliance", 18))
		var l0: Label = UiKit.lbl("Без альянса", 11, UiKit.MUTED, 2, 2)
		l0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h0.add_child(l0)
		var g0: Label = UiKit.lbl("НАЙТИ СОЮЗНИКОВ", 9, UiKit.GOLD.darkened(0.1), 2, 2)
		h0.add_child(g0)
		h0.add_child(_chev())
		b0.pressed.connect( func() -> void :
			UiKit.snd("ui_click")
			hud.open_diplomacy())
		inner.add_child(b0)
		return
	var colr: Color = dp.ally.color(a)
	var b: Button = _row_btn(52.0)
	var hb: HBoxContainer = _row_box(b)
	var lg: TextureRect = _icon("ally_logo_%d" % int(a.get("logo", 0)), 34)
	lg.modulate = colr
	hb.add_child(lg)
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", -1)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tv)
	var nl: Label = UiKit.lbl(Loc.name(String(a.get("name", ""))).to_upper(), 12, colr.lightened(0.3), 2, 3)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(nl)
	var mem: Array = a.get("members", [])
	var role: String = Loc.t("глава") if int(a.get("founder", -1)) == me else Loc.t("член")
	tv.add_child(UiKit.lbl(Loc.t("%s · стран: %d") % [role, mem.size()], 10, UiKit.MUTED, 1, 2))
	var fl: = HBoxContainer.new()
	fl.add_theme_constant_override("separation", 2)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(fl)
	var shown: int = 0
	var cap: int = 3 if compact() else 4
	for x: Variant in mem:
		if int(x) == me:
			continue
		var cc: Country = gw.country_by_id(int(x))
		if cc == null:
			continue
		if shown >= cap:
			break
		fl.add_child(_flag(cc, Vector2(18, 11)))
		shown += 1
	if mem.size() - 1 > shown:
		fl.add_child(UiKit.lbl("+%d" % (mem.size() - 1 - shown), 9, UiKit.MUTED, 2, 2))
	hb.add_child(_chev())
	var aid: int = int(a.get("id", -1))
	b.pressed.connect( func() -> void : _open_alliance(aid))
	inner.add_child(b)


func _open_alliance(aid: int) -> void :
	UiKit.snd("ui_click")
	close_sheet()
	if hud.has_method("show_alliance"):
		hud.call("show_alliance", aid)
		return
	hud.action.emit("map_mode:%d" % GameWorld.MapMode.ALLIANCES)




func _ledger() -> void :
	inner.add_child(_section("ДОГОВОРЫ И МЕРЫ", UiKit.TITLE))
	var rows: Array = []
	var others: Array = _alive_others()
	var pick: = func(f: Callable) -> Array:
		var o: Array = []
		for c: Country in others:
			if bool(f.call(c.id)):
				o.append(c.id)
		return o
	rows.append(["icon_rel_ally", "СОЮЗ", pick.call( func(o: int) -> bool: return dp.allied(me, o)), null, C_ALLY, ""])
	rows.append(["icon_treaty_defense", "ОБОРОНА", pick.call( func(o: int) -> bool: return dp.has_treaty(me, o, "defense")), null, C_PEACE, ""])
	rows.append(["icon_treaty_nap", "НЕНАПАДЕНИЕ", pick.call( func(o: int) -> bool: return dp.has_treaty(me, o, "nap")), null, C_PEACE, ""])
	rows.append(["icon_treaty_trade", "ТОРГОВЛЯ", pick.call( func(o: int) -> bool: return dp.has_treaty(me, o, "trade")), null, C_PEACE, ""])
	rows.append(["icon_treaty_visa", "БЕЗВИЗ", pick.call( func(o: int) -> bool: return dp.has_treaty(me, o, "visa")), null, C_PEACE, ""])
	rows.append(["icon_treaty_passage", "ПРОХОД", pick.call( func(o: int) -> bool: return dp.has_passage(me, o)), pick.call( func(o: int) -> bool: return dp.has_passage(o, me)), C_PEACE, "", "вы через их землю", "они через вашу"])
	rows.append(["icon_ad_patriot", "НЕБО", pick.call( func(o: int) -> bool: return sky_over(gw, me, o)), pick.call( func(o: int) -> bool: return sky_over(gw, o, me)), C_ALLY, "", "вы закрыли над ними", "они — над вами"])
	rows.append(["icon_treaty_embargo", "САНКЦИИ", pick.call( func(o: int) -> bool: return not sanctions(gw, me, o).is_empty()), pick.call( func(o: int) -> bool: return not sanctions(gw, o, me).is_empty()), C_WAR, "", "ваши против", Loc.t("против вас%s") % [_sanct_note()]])
	rows.append(["icon_treaty_embargo", "ЭМБАРГО", pick.call( func(o: int) -> bool: return dp.embargoed(me, o)), pick.call( func(o: int) -> bool: return dp.embargoed(o, me)), C_WAR, "", "ваше против", "против вас"])
	rows.append(["net_handshake", "КОНТРАКТЫ", contract_partners(gw, me), null, UiKit.GOLD, ""])
	var card: = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 4))
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	card.add_child(vb)
	var n: int = 0
	for r: Array in rows:
		var outs: Array = r[2]
		var ins: Variant = r[3]
		if outs.is_empty() and (ins == null or (ins as Array).is_empty()):
			continue
		if n > 0:
			vb.add_child(_sep())
		vb.add_child(_ledger_row(r))
		n += 1
	if n == 0:
		var l: Label = UiKit.lbl("Договоров нет. Предложите их в Дипломатии — у каждой страны своя страница.", 10, UiKit.MUTED, 1, 2)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l)
	inner.add_child(card)


func _sanct_note() -> String:
	var mats: Dictionary = {}
	for c: Country in _alive_others():
		for r: Variant in sanctions(gw, c.id, me):
			mats[String(r)] = true
	if mats.is_empty():
		return ""
	var names: PackedStringArray = PackedStringArray()
	for k: String in mats:
		names.append(Loc.t(String(Economy.RES_NAMES.get(k, k))).to_lower())
	return ": " + ", ".join(names)


func _ledger_row(r: Array) -> Control:
	var outs: Array = r[2]
	var ins: Variant = r[3]
	var colr: Color = r[4]
	var all_ids: Array = outs.duplicate()
	if ins != null:
		for x: Variant in ins:
			if not all_ids.has(x):
				all_ids.append(x)
	var only: int = int(all_ids[0]) if all_ids.size() == 1 else -1
	var lines: Array = []
	if ins == null:
		lines.append(["", outs])
	else:
		if not outs.is_empty():
			lines.append([String(r[6]), outs])
		if not (ins as Array).is_empty():
			lines.append([String(r[7]), ins])
	var b: Button = _row_btn(36.0 if lines.size() < 2 else 50.0, true)
	var hb: HBoxContainer = _row_box(b)
	hb.add_child(_icon(String(r[0]), 16))
	var nl: Label = UiKit.lbl(String(r[1]), 10, colr.lightened(0.2), 2, 2)
	nl.custom_minimum_size.x = 78 if compact() else 92
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(nl)
	var right: = VBoxContainer.new()
	right.add_theme_constant_override("separation", 1)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(right)
	for ln: Array in lines:
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.add_child(row)
		if String(ln[0]) != "":
			var cl: Label = UiKit.lbl(String(ln[0]), 9, UiKit.MUTED, 1, 2)
			cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cl.clip_text = true
			cl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			row.add_child(cl)
		else:
			var sp: = Control.new()
			sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(sp)
		row.add_child(_flags(ln[1] as Array, 3 if String(ln[0]) != "" else 4, String(ln[0]) == ""))
	hb.add_child(_chev())
	if only >= 0:
		b.pressed.connect( func() -> void : _open_country(only))
	else:
		b.pressed.connect( func() -> void :
			UiKit.snd("ui_click")
			hud.open_diplomacy())
	return b


func _flags(ids: Array, cap: int, names: bool = true) -> Control:
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n: int = 0
	for x: Variant in ids:
		var c: Country = gw.country_by_id(int(x))
		if c == null:
			continue
		if n >= cap:
			break
		hb.add_child(_flag(c, Vector2(18, 11)))
		n += 1
	if ids.size() > n:
		hb.add_child(UiKit.lbl("+%d" % (ids.size() - n), 9, UiKit.MUTED, 2, 2))
	if names and ids.size() == 1 and n == 1:
		var c1: Country = gw.country_by_id(int(ids[0]))
		var nm: Label = UiKit.lbl(Loc.name(c1.name), 10, UiKit.TEXT, 2, 2)
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.custom_minimum_size.x = 66 if compact() else 84
		hb.add_child(nm)
	return hb




func _relations() -> void :
	var others: Array = _alive_others()
	if others.is_empty():
		return
	inner.add_child(_section("ОТНОШЕНИЯ", UiKit.TITLE))
	var rv: Array = rivals_of(gw, me)
	var lst: Array = []
	for c: Country in others:
		lst.append(c.id)
	lst.sort_custom( func(a: int, b: int) -> bool: return dp.relation(me, a) > dp.relation(me, b))
	var friends: Array = lst.filter( func(o: int) -> bool: return dp.relation(me, o) >= 20 and dp.get_rel(me, o) != Diplomacy.Rel.WAR).slice(0, 2)
	var foes_all: Array = lst.duplicate()
	foes_all.reverse()
	var foes: Array = foes_all.filter( func(o: int) -> bool: return dp.relation(me, o) <= -10 and not rv.has(o)).slice(0, 2)
	var g: = HBoxContainer.new()
	g.add_theme_constant_override("separation", 6)
	inner.add_child(g)
	g.add_child(_rel_col("ДРУЗЬЯ", C_PEACE, friends, "друзей пока нет"))
	g.add_child(_rel_col("НЕДРУГИ", C_WAR, foes, "недругов нет"))
	for r: int in rv:
		var rc: Country = gw.country_by_id(r)
		if rc == null or rc.eliminated:
			continue
		inner.add_child(_rival_row(r))


func _rel_col(title: String, colr: Color, ids: Array, empty: String) -> Control:
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_stretch_ratio = 1.0
	vb.add_child(UiKit.lbl(title, 9, colr, 2, 2))
	if ids.is_empty():
		var l: Label = UiKit.lbl(empty, 10, UiKit.DIM, 1, 2)
		l.custom_minimum_size.y = 36
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		vb.add_child(l)
	for o: int in ids:
		var c: Country = gw.country_by_id(o)
		var b: Button = _row_btn(40.0)
		var hb: HBoxContainer = _row_box(b)
		hb.add_child(_flag(c, Vector2(18, 11)))
		var nl: Label = UiKit.lbl(Loc.name(c.name), 10, UiKit.TEXT, 2, 2)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(nl)
		var v: int = dp.relation(me, o)
		hb.add_child(UiKit.lbl(_signed(v), 11, C_PEACE if v > 0 else (C_WAR if v < 0 else UiKit.MUTED), 2, 3))
		b.pressed.connect( func() -> void : _open_country(o))
		vb.add_child(b)
	return vb


func _rival_row(cid: int) -> Control:
	var c: Country = gw.country_by_id(cid)
	var b: Button = _row_btn(46.0)
	b.add_theme_stylebox_override("normal", _rival_sb())
	b.add_theme_stylebox_override("hover", _rival_sb())
	var hb: HBoxContainer = _row_box(b)
	var tag: = PanelContainer.new()
	var ts: = StyleBoxFlat.new()
	ts.bg_color = Color("5a1a14")
	ts.border_color = UiKit.GOLD.darkened(0.25)
	ts.set_border_width_all(1)
	ts.set_corner_radius_all(2)
	ts.content_margin_left = 5
	ts.content_margin_right = 5
	ts.content_margin_top = 1
	ts.content_margin_bottom = 1
	tag.add_theme_stylebox_override("panel", ts)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var th: = HBoxContainer.new()
	th.add_theme_constant_override("separation", 3)
	tag.add_child(th)
	if UiKit.tex("d331_rival_12") != null:
		th.add_child(_icon("d331_rival_12", 12))
	th.add_child(UiKit.lbl("СОПЕРНИК", 9, UiKit.GOLD, 2, 2))
	hb.add_child(tag)
	hb.add_child(_flag(c, Vector2(22, 14)))
	var tv: = VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tv)
	var nl: Label = UiKit.lbl(Loc.name(c.name).to_upper(), 11, UiKit.TEXT, 2, 3)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(nl)
	var sl: Label = UiKit.lbl("не примет ваших просьб", 9, UiKit.MUTED, 1, 2)
	sl.clip_text = true
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(sl)
	var v: int = dp.relation(me, cid)
	hb.add_child(UiKit.lbl(_signed(v), 11, C_PEACE if v > 0 else (C_WAR if v < 0 else UiKit.MUTED), 2, 3))
	hb.add_child(_chev())
	b.pressed.connect( func() -> void : _open_country(cid))
	return b


func _rival_sb() -> StyleBox:
	var s: StyleBox = UiKit.sb("wb_panel_dark", 8, 4)
	return s




func _open_country(cid: int) -> void :
	UiKit.snd("ui_click")
	var c: Country = gw.country_by_id(cid)
	if c == null or c.eliminated:
		return
	hud.dip_open = cid
	hud.open_diplomacy()




func open_anim() -> void :
	modulate.a = 0.0
	UiKit.snd("ui_open")
	var par: Container = get_parent() as Container
	if par != null and not par.sort_children.is_connected(_on_parent_sort):
		par.sort_children.connect(_on_parent_sort)
	_set_slide(24.0)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_method(_set_slide, 24.0, 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)


func _set_slide(v: float) -> void :
	position.y += v - _slide
	_slide = v


func _on_parent_sort() -> void :
	if _slide != 0.0:
		position.y += _slide


func close_sheet() -> void :
	if _closing or not is_inside_tree():
		return
	_closing = true
	hud.ui24_closed(self)
	UiKit.snd("ui_close")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_method(_set_slide, _slide, 24.0, 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback( func() -> void :
		closed.emit()
		if hud.panel == self:
			hud.close_panel()
		else:
			queue_free())


func close() -> void :
	close_sheet()


func _process(delta: float) -> void :
	if _closing:
		return
	if hud != null and hud.ops_panel != null and hud.ops_panel.visible:
		close_sheet()
		return
	_tick_t += delta
	if _tick_t < 0.25:
		return
	_tick_t = 0.0
	_update_fades()
	_live_t += 0.25
	if _live_t < 1.0:
		return
	_live_t = 0.0
	if gw.diplo != _dp0 or gw.player == null or gw.player.eliminated != _elim0:
		close_sheet()
		return
	for t: Array in _timers:
		var l: Label = t[0]
		if not is_instance_valid(l):
			continue
		match String(t[1]):
			"war":
				l.text = String(t[3]) + _mmss(dp.war_time(me, int(t[2])))
			"deadline":
				l.text = String(t[3]) + _mmss(maxf(0.0, float(t[2]) - gw.game_time)) if float(t[2]) >= 0.0 else (String(t[4]) if t.size() > 4 else Loc.t("%sбез срока") % [String(t[3]).trim_suffix("ответ до ")])
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _struct_sig() != _sig:
		rebuild(true)




func _row_btn(h: float, flat: bool = false) -> Button:
	var b: = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n: StyleBox = StyleBoxEmpty.new() if flat else UiKit.sb("wb_panel_dark", 8, 4)
	var p: StyleBox = UiKit.sb("wb_slot_pressed", 8, 4)
	for s: String in ["normal", "hover", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, n)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	UiKit.tap_snd(b)
	return b


func _row_box(b: Button) -> HBoxContainer:
	var mc: = MarginContainer.new()
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", 8)
	mc.add_theme_constant_override("margin_right", 6)
	mc.add_theme_constant_override("margin_top", 3)
	mc.add_theme_constant_override("margin_bottom", 3)
	b.add_child(mc)
	var hb: = HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 7)
	mc.add_child(hb)
	return hb


func _chev() -> Label:
	var l: Label = UiKit.lbl("›", 16, UiKit.MUTED, 2, 2)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	return l


func _sep() -> Control:
	var c: = ColorRect.new()
	c.color = Color(0, 0, 0, 0.35)
	c.custom_minimum_size = Vector2(0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _section(t: String, colr: Color) -> Control:
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.custom_minimum_size.y = 18
	var l: Label = UiKit.lbl(t, 10, colr, 2, 3)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(l)
	var line: = ColorRect.new()
	line.color = Color(colr, 0.25)
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(line)
	return hb


func _tag(t: String, colr: Color, icon_name: String) -> Control:
	var p: = PanelContainer.new()
	var s: = StyleBoxFlat.new()
	s.bg_color = colr.darkened(0.72)
	s.border_color = colr.darkened(0.1)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 4
	s.content_margin_right = 6
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	p.add_child(hb)
	if icon_name != "":
		hb.add_child(_icon(icon_name, 12))
	hb.add_child(UiKit.lbl(t, 9, colr.lightened(0.2), 2, 2))
	return p


func _rim(c: Color) -> Panel:
	var rim: = Panel.new()
	var rs: = StyleBoxFlat.new()
	rs.draw_center = false
	rs.border_color = c
	rs.set_border_width_all(2)
	rs.set_corner_radius_all(3)
	rim.add_theme_stylebox_override("panel", rs)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rim


func _fade(top: bool) -> TextureRect:
	var g: = Gradient.new()
	var bg: = Color("4d513f")
	g.set_color(0, Color(bg, 1.0) if top else Color(bg, 0.0))
	g.set_color(1, Color(bg, 0.0) if top else Color(bg, 1.0))
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 16
	var r: = TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = Vector2(0, 14)
	r.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if top else Control.SIZE_SHRINK_END
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.visible = false
	return r


func _icon(nm: String, box: float) -> TextureRect:
	var n2: String = nm
	if UiKit.tex(n2) == null:
		n2 = String({"icon_rel_ally": "icon_alliance", "icon_rel_peace": "icon_peace", "icon_dip_crisis": "icon_ultimatum", "icon_dip_vassal_16": "icon_treaty_alliance", 
			"icon_dip_call": "icon_ultimatum", "corner_check": "icon_ok", "icon_treaty_passage": "icon_treaty_visa", "net_handshake": "icon_treaty_trade", 
			"icon_ad_patriot": "icon_ad_sam", "icon_land": "icon_city"}.get(nm, "icon_info"))
	var r: TextureRect = UiKit.icon_rect(n2, box)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


func _flag(c: Country, sz: Vector2) -> Control:
	var p: = PanelContainer.new()
	var s: = StyleBoxFlat.new()
	s.bg_color = UiKit.OUTLINE
	s.set_content_margin_all(1)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fl: = TextureRect.new()
	if c != null:
		fl.texture = FlagMaker.tex_for(c, sz)
	fl.custom_minimum_size = sz
	fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fl.stretch_mode = TextureRect.STRETCH_SCALE
	fl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(fl)
	return p


func _cname(id: int) -> String:
	var c: Country = gw.country_by_id(id)
	return Loc.name(c.name) if c != null else "—"


static func _mmss(t: float) -> String:
	var s: int = maxi(0, int(t))
	return "%d:%02d" % [s / 60, s % 60]


static func _signed(v: int) -> String:
	return ("+%d" % v) if v > 0 else ("−%d" % - v if v < 0 else "0")


static func _x(v: float) -> String:
	return Loc.dec("%.1f" % v)


static func _short(v: float) -> String:
	var a: float = absf(v)
	if a >= 10000.0:
		return Loc.t("%dК") % roundi(a / 1000.0)
	if a >= 1000.0:
		return Loc.dec(Loc.t("%.1fК") % (a / 1000.0))
	return str(roundi(a))
