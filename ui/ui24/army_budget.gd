extends PanelContainer









const U = preload("res://ui/ui24/econ_kit.gd")
const Bar = preload("res://ui/ui24/bar_track.gd")
const AMBER: = Color("ffb000")
const WARN_MIN: float = 5.0

const ROWS: Array = [["ad", "icon_ad_sam", "ПВО"], ["strike", "icon_tel", "Ракеты и ОТРК"], ["air", "icon_fighter", "Авиация"], 
	["drones", "icon_droneport", "Дроны"], ["army", "icon_barracks", "Казармы"], ["navy", "icon_ship", "Флот"], 
	["fire", "icon_target", "ПВО: выстрелы"]]
const LOC_FIRE_CLS: Dictionary = {Facility.Kind.AD_SAM: "ЗРК", Facility.Kind.AD_PATRIOT: "«Щит»", Facility.Kind.AD_SPAAG: "ЗСУ", 
	Facility.Kind.AD_MFG: "МОГ", Facility.Kind.AD_INT: "перехв."}

signal open_more

var gw: GameWorld
var compact_mode: bool = false
var last: Dictionary = {}
var _t: float = 0.0
var _head_val: Label
var _status_pc: PanelContainer
var _status_icon: TextureRect
var _status_lbl: Label
var _status_sub: Label
var _rows: Dictionary = {}
var _fire_sub: Label
var _mb_box: VBoxContainer
var _mb_lbl: Label
var _mb_note: Label
var _sup_lbl: Label
var _foot: Label
var _sb: Dictionary = {}
var _level: String = ""


static func make(world: GameWorld, compact: bool) -> PanelContainer:
	var c = (load("res://ui/ui24/army_budget.gd") as GDScript).new()
	c.gw = world
	c.compact_mode = compact
	c._build()
	c.refresh()
	return c


func _process(delta: float) -> void :
	_t += delta
	if _t < 1.0:
		return
	_t = 0.0
	if is_visible_in_tree():
		refresh()





static func collect(world: GameWorld) -> Dictionary:
	var p: Country = world.player if world != null else null
	if p == null or world.econ == null or world.econ.get("upk") == null:
		return {}
	var ub: Dictionary = world.econ.upkeep_breakdown(p)
	var fc: Dictionary = world.econ.upkeep_forecast(p)
	if ub.is_empty() or fc.is_empty():
		return {}
	var sp: Dictionary = world.defense.spend_min(p) if world.defense != null and world.defense.has_method("spend_min") else {"total": 0, "by_class": {}}
	var upk: int = int(fc.get("upkeep_min", 0))
	var fire: int = int(sp.get("total", 0))
	var inc: int = int(fc.get("income_min", 0))
	var net: int = inc - upk - fire
	var left: float = -1.0
	if net < 0:
		left = float(maxi(0, p.money)) / float( - net)
	var level: String = "ok"
	if net < 0:
		level = "warn" if left <= WARN_MIN else "drain"
	var mbn: int = int(ub.get("mothballed", 0))
	return {"upkeep": upk, "fire": fire, "army": upk + fire, "income": inc, "net": net, "left": left, "level": level, 
		"mb_soon": int(fc.get("net_min", 0)) < 0, "mothballed": mbn, "react": int(ub.get("reactivating", 0)), 
		"classes": ub.get("classes", {}), "fire_by": sp.get("by_class", {}), "ramp": float(world.econ.upk.ramp()), 
		"free": int(ub.get("free_min", 0)), 
		"fuel": float(ub.get("fuel_min", 0.0)), "metal": float(ub.get("metal_min", 0.0)), "mb_list": mb_list(world, p), 
		"supply": world.econ.army_supply(p), "money": p.money}



static func mb_list(world: GameWorld, p: Country) -> Array:
	var cnt: Dictionary = {}
	for f: Facility in world.mil.facilities:
		if f.country_id == p.id and f.mb and f.parent == null and world.mil.alive(f):
			var t: String = Loc.t(Military.title_of(f.kind))
			cnt[t] = int(cnt.get(t, 0)) + 1
	var mba: Dictionary = world.econ.upk.mb_air
	if not mba.is_empty():
		for a: Aircraft in world.mil.air.aircraft:
			if a.country_id == p.id and mba.has(a.id) and a.state != Aircraft.State.DEAD:
				var ta: String = Loc.t(String(Air.SPEC.get(a.type, {}).get("name", "Самолёт")))
				cnt[ta] = int(cnt.get(ta, 0)) + 1
	var out: Array = []
	for k: String in cnt:
		out.append([k, int(cnt[k])])
	out.sort_custom( func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]) or (int(a[1]) == int(b[1]) and String(a[0]) < String(b[0])))
	return out


static func mins(m: float) -> String:
	return str(maxi(1, roundi(m)))




func _flat(bg: Color, border: Color) -> StyleBoxFlat:
	var st: = StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(1)
	st.border_width_left = 3
	st.set_corner_radius_all(3)
	st.content_margin_left = 7
	st.content_margin_right = 6
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	return st


func _build() -> void :
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", UiKit.sb("wb_card", 8, 5))
	_sb = {"ok": _flat(Color("23331a"), UiKit.GREEN.darkened(0.2)), "drain": _flat(Color("3a2c12"), AMBER), 
		"warn": _flat(Color("4a1d14"), UiKit.RED)}
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)

	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hb)
	var ic: TextureRect = U.icon("icon_tank", 24.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var ht: Label = UiKit.lbl(Loc.t("АРМИЯ"), 13, UiKit.TEXT, 3, 2)
	ht.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ht)
	var hs: Label = UiKit.lbl(Loc.t("содержание и огонь"), 9, UiKit.MUTED, 1, 2)
	hs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hs.clip_text = true
	UiKit.fit_lbl(hs, [9, 8], false)
	hs.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hb.add_child(hs)
	_head_val = UiKit.no_tr(UiKit.lbl("", 15, UiKit.RED, 2, 3)) as Label
	_head_val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_head_val)
	if compact_mode:
		var chev: Label = UiKit.lbl("›", 16, UiKit.GOLD, 2, 2)
		chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(chev)

	_status_pc = PanelContainer.new()
	_status_pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_pc.add_theme_stylebox_override("panel", _sb["ok"])
	vb.add_child(_status_pc)
	var sh: = HBoxContainer.new()
	sh.add_theme_constant_override("separation", 5)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_pc.add_child(sh)
	_status_icon = U.icon("icon_ok", 16.0, "icon_info")
	_status_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.add_child(_status_icon)
	var scol: = VBoxContainer.new()
	scol.add_theme_constant_override("separation", -1)
	scol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.add_child(scol)
	_status_lbl = UiKit.no_tr(UiKit.lbl("", 11, UiKit.TEXT, 2, 2)) as Label
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scol.add_child(_status_lbl)
	_status_sub = UiKit.no_tr(UiKit.lbl("", 9, UiKit.MUTED, 1, 2)) as Label
	_status_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scol.add_child(_status_sub)

	_mb_box = VBoxContainer.new()
	_mb_box.add_theme_constant_override("separation", 0)
	_mb_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mb_box.visible = false
	vb.add_child(_mb_box)
	_mb_lbl = UiKit.no_tr(UiKit.lbl("", 10, Color("9fc3e6"), 2, 2)) as Label
	_mb_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mb_box.add_child(_mb_lbl)
	_mb_note = UiKit.no_tr(UiKit.lbl("", 9, UiKit.MUTED, 1, 2)) as Label
	_mb_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mb_box.add_child(_mb_note)
	if compact_mode:
		return

	for r: Array in ROWS:
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.custom_minimum_size = Vector2(0, 18)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.visible = false
		vb.add_child(row)
		var ri: TextureRect = U.icon(String(r[1]), 16.0)
		ri.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ri)
		var nl: Label = UiKit.lbl(Loc.t(String(r[2])), 10, UiKit.TEXT, 1, 2)
		nl.custom_minimum_size = Vector2(92, 0)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(nl)
		var nn: Label = UiKit.no_tr(UiKit.lbl("", 9, UiKit.DIM, 2, 2)) as Label
		nn.custom_minimum_size = Vector2(26, 0)
		nn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(nn)
		var bar = Bar.new()
		bar.custom_minimum_size = Vector2(0, 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.fill_name = "wb_bar_amber" if String(r[0]) == "fire" else "wb_bar_red"
		row.add_child(bar)
		var vl: Label = UiKit.no_tr(UiKit.lbl("", 11, UiKit.RED, 2, 2)) as Label
		vl.custom_minimum_size = Vector2(52, 0)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(vl)
		_rows[String(r[0])] = {"row": row, "n": nn, "bar": bar, "val": vl}
	_fire_sub = UiKit.no_tr(UiKit.lbl("", 9, UiKit.MUTED, 1, 2)) as Label
	_fire_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fire_sub.visible = false
	vb.add_child(_fire_sub)
	_sup_lbl = UiKit.no_tr(UiKit.lbl("", 10, AMBER, 2, 2)) as Label
	_sup_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sup_lbl.visible = false
	vb.add_child(_sup_lbl)
	_foot = UiKit.no_tr(UiKit.lbl("", 9, UiKit.MUTED, 1, 2)) as Label
	_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_foot)


var _press_at: Vector2 = Vector2.INF


func _gui_input(ev: InputEvent) -> void :
	if not compact_mode:
		return
	var mb: InputEventMouseButton = ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_press_at = mb.global_position
	elif _press_at.is_finite() and _press_at.distance_to(mb.global_position) < 12.0:
		_press_at = Vector2.INF
		UiKit.snd("ui_click")
		open_more.emit()




func refresh() -> void :
	var d: Dictionary = collect(gw)
	last = d
	if d.is_empty():
		U.set_lbl(_head_val, "—", UiKit.MUTED)
		U.set_lbl(_status_lbl, Loc.t("Нет данных"), UiKit.MUTED)
		return
	var army: int = int(d["army"])
	U.set_lbl(_head_val, (Loc.f("−{n}/мин", {"n": U.num(army)}) if army > 0 else Loc.t("0/мин")), UiKit.RED if army > 0 else UiKit.MUTED)

	var lv: String = String(d["level"])
	var net: int = int(d["net"])
	var t: String = ""
	var sub: String = ""
	var col: Color = UiKit.GREEN
	var icn: String = "icon_ok"
	if lv == "ok":
		t = Loc.t("Доход покрывает армию") if army > 0 else Loc.t("Армия пока ничего не стоит")
		sub = Loc.f("Доход {inc} − армия {army} = чистыми +{net}/мин", {"inc": U.num(int(d["income"])), "army": U.num(army), "net": U.num(net)})
	elif lv == "drain":
		col = AMBER
		icn = "icon_scarce"
		t = Loc.f("Доход не покрывает армию: {net}/мин · казны хватит на ~{m} мин", {"net": U.num(net), "m": mins(float(d["left"]))})
		sub = Loc.f("Доход {inc} − армия {army}. Не хватит — техника встанет на консервацию сама", {"inc": U.num(int(d["income"])), "army": U.num(army)})
	else:
		col = UiKit.RED
		icn = "icon_scarce"
		if bool(d["mb_soon"]):
			t = Loc.f("Через ~{m} мин — консервация", {"m": mins(float(d["left"]))})
			sub = Loc.t("Денег не хватает на содержание: сначала встанет наименее важное (тыл, заводы), ПВО у столицы — последней")
		else:
			t = Loc.f("Через ~{m} мин ПВО замолчит", {"m": mins(float(d["left"]))})
			sub = Loc.t("Выстрелы ПВО съедают казну. «Цели ПВО» › «Экономно» — ракеты не тратятся на дешёвые дроны")
	if int(d.get("free", 0)) > 0:
		sub += ("\n" if sub != "" else "") + Loc.f("Льгота малой страны: −{n}/мин содержания (пока городов меньше 9)", {"n": U.num(int(d["free"]))})
	var r: float = float(d["ramp"])
	if r < 1.0 and gw.game_time < 900.0:
		sub += ("\n" if sub != "" else "") + (Loc.t("Первые 3 минуты армия бесплатна") if r <= 0.0 else Loc.f("Содержание растёт: сейчас {p} %, полностью — к 15-й минуте", {"p": roundi(r * 100.0)}))
	if lv != _level:
		_level = lv
		_status_pc.add_theme_stylebox_override("panel", _sb[lv])
		U.set_icon(_status_icon, icn, 16.0, "icon_info")
	U.set_lbl(_status_lbl, t, col)
	U.set_lbl(_status_sub, sub, UiKit.MUTED)
	U.set_vis(_status_sub, sub != "" and not compact_mode)

	var mbn: int = int(d["mothballed"])
	U.set_vis(_mb_box, mbn > 0)
	if mbn > 0:
		var parts: PackedStringArray = []
		for e: Array in d["mb_list"]:
			parts.append(("%s ×%d" % [String(e[0]), int(e[1])]) if int(e[1]) > 1 else String(e[0]))
			if parts.size() >= (2 if compact_mode else 5):
				break
		var more: int = (d["mb_list"] as Array).size() - parts.size()
		var lst: String = ", ".join(parts) + (Loc.f(" и ещё {n}", {"n": more}) if more > 0 else "")
		U.set_lbl(_mb_lbl, Loc.f("НА КОНСЕРВАЦИИ: {n} — {list}", {"n": mbn, "list": lst}), Color("9fc3e6"))
		var note: String = Loc.t("Не работают и не стоят денег. Вернутся сами по одному, когда доход покроет содержание")
		if int(d["react"]) > 0:
			note = Loc.f("Возвращается в строй: {n}. Остальные — сами, когда хватит денег", {"n": int(d["react"])})
		U.set_lbl(_mb_note, note, UiKit.MUTED)
		U.set_vis(_mb_note, not compact_mode or int(d["react"]) > 0)
	if compact_mode:
		return

	var cls: Dictionary = d["classes"]
	var vals: Dictionary = {}
	var mx: float = 1.0
	for rr: Array in ROWS:
		var k: String = String(rr[0])
		var v: int = int(d["fire"]) if k == "fire" else int((cls.get(k, {}) as Dictionary).get("money_min", 0))
		vals[k] = v
		mx = maxf(mx, float(v))
	for rr2: Array in ROWS:
		var k2: String = String(rr2[0])
		var e2: Dictionary = _rows[k2]
		var v2: int = int(vals[k2])
		var ce: Dictionary = cls.get(k2, {})
		var n: int = int(ce.get("n", 0))
		U.set_vis(e2["row"], v2 > 0 or n > 0)
		var mbk: int = int(ce.get("mothballed", 0))
		U.set_lbl(e2["n"], ("" if k2 == "fire" or n <= 0 else "×%d" % n), Color("9fc3e6") if mbk > 0 else UiKit.DIM)
		e2["bar"].frac = float(v2) / mx
		U.set_lbl(e2["val"], ("−" + U.num(v2)) if v2 > 0 else "0", UiKit.RED if v2 > 0 and k2 != "fire" else (AMBER if v2 > 0 else UiKit.MUTED))

	var fb: Dictionary = d["fire_by"]
	var fp: PackedStringArray = []
	for kind: int in Defense.AD_CLASSES:
		var fv: int = int(fb.get(kind, 0))
		if fv > 0:
			fp.append("%s %s" % [Loc.t(String(LOC_FIRE_CLS[kind])), U.num(fv)])
	U.set_vis(_fire_sub, not fp.is_empty())
	if not fp.is_empty():
		U.set_lbl(_fire_sub, Loc.f("Выстрелы за минуту: {list}", {"list": " · ".join(fp)}), UiKit.MUTED)

	var su: Dictionary = d["supply"]
	var sl: String = ""
	var cut: int = int(su.get("cut", 0))
	var sc: int = int(su.get("sites_cut", 0))
	if cut > 0 or sc > 0:
		var what: PackedStringArray = []
		if cut > 0:
			what.append("%d %s" % [cut, Loc.n(cut, "боец", "бойца", "бойцов")])
		if sc > 0:
			what.append("%d %s" % [sc, Loc.n(sc, "площадка ПВО/ОТРК", "площадки ПВО/ОТРК", "площадок ПВО/ОТРК")])
		sl = Loc.f("БЕЗ СНАБЖЕНИЯ: {what} — огонь слабеет, пока нет дороги к своему городу или порту", {"what": ", ".join(what)})
	elif bool(su.get("short", false)):
		sl = Loc.t("НЕХВАТКА ТОПЛИВА ИЛИ МЕТАЛЛА: огонь −25 % — купите или добудьте")
	U.set_vis(_sup_lbl, sl != "")
	U.set_lbl(_sup_lbl, sl, UiKit.RED if cut > 0 or sc > 0 else AMBER)
	var fu: String = Loc.f("Ест армия: топливо {f}/мин · металл {m}/мин", {"f": Loc.num(float(d["fuel"])), "m": Loc.num(float(d["metal"]))}) if float(d["fuel"]) + float(d["metal"]) > 0.0 else ""
	U.set_lbl(_foot, fu, UiKit.MUTED)
	U.set_vis(_foot, fu != "")





static func site_line(world: GameWorld, f: Facility) -> String:
	if world == null or world.econ == null or world.econ.get("upk") == null or f == null:
		return ""
	var upk = world.econ.upk
	if f.mb:
		var rt: float = float((upk.react as Dictionary).get("f%d" % f.id, -1.0))
		if rt >= 0.0:
			return Loc.f("РАСКОНСЕРВАЦИЯ: В СТРОЮ ЧЕРЕЗ {t}", {"t": U.mmss(rt - world.game_time)})
		return Loc.t("НА КОНСЕРВАЦИИ: НЕ РАБОТАЕТ И НЕ СТОИТ ДЕНЕГ · ВЕРНЁТСЯ САМ, КОГДА ХВАТИТ ДЕНЕГ")
	var s: int = world.econ.site_supply(f)
	return _sup_text(upk, s, (upk.cut_f as Dictionary).get(f.id, -1.0))



static func army_line(world: GameWorld, f: Facility) -> String:
	if world == null or world.econ == null or world.econ.get("upk") == null or f == null:
		return ""
	var upk = world.econ.upk
	var worst: int = 0
	var since: float = INF
	var n: int = 0
	for u: Unit in world.army.units:
		if u.home != f or not u.alive():
			continue
		var s: int = world.econ.unit_supply(u)
		if s == 1 or s == 2:
			n += 1
			since = minf(since, float((upk.cut_u as Dictionary).get(u.id, INF)))
		if s > worst and not (worst in [1, 2] and s == 3):
			worst = s
	if worst == 0:
		return ""
	return _sup_text(upk, worst, since if since < INF else -1.0)


static func _sup_text(upk, s: int, since: Variant) -> String:
	match s:
		1:
			return Loc.t("ОТРЕЗАНЫ ОТ СНАБЖЕНИЯ: ОГОНЬ ПОКА ПОЛНЫЙ, ЧЕРЕЗ МИНУТУ НАЧНЁТ СЛАБЕТЬ")
		2:
			var rate: float = float(upk._rate(float(since))) if upk.has_method("_rate") and float(since) >= 0.0 else 0.6
			return Loc.f("БЕЗ СНАБЖЕНИЯ — ОГОНЬ −{p} %", {"p": roundi((1.0 - rate) * 100.0)})
		3:
			return Loc.t("НЕХВАТКА ТОПЛИВА ИЛИ МЕТАЛЛА — ОГОНЬ −25 %")
	return ""



static func series_line(world: GameWorld, kind: int) -> String:
	if world == null or world.player == null or world.mil == null or not world.mil.has_method("series_info"):
		return ""
	var si: Dictionary = world.mil.series_info(kind, world.player)
	if not bool(si.get("series", false)):
		return ""
	var m: float = float(si.get("mult", 1.0))
	if m > 1.001:
		return Loc.f("ЦЕНА СЕРИИ +{p} % · остынет через {t}", {"p": roundi((m - 1.0) * 100.0), "t": U.mmss(float(si.get("cool_s", 0.0)))})
	var left: int = int(si.get("free", 0)) - floori(float(si.get("heat", 0.0)) + 0.0001)
	if float(si.get("heat", 0.0)) >= 1.0 and left <= 2:
		return Loc.f("По обычной цене ещё {n}, дальше +8 % за каждый (цена остывает за 2 мин)", {"n": maxi(0, left)})
	return ""
