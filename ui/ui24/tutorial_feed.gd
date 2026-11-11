class_name TutorialFeed
extends CanvasLayer












signal closed

const SELF: = "res://ui/ui24/tutorial_feed.gd"
const DIR: = "res://assets/video/tutorial/"
const MANIFEST: = DIR + "tutorial_clips.json"
const FILM: = Vector2(540, 960)
const PREFS: = "user://tutorial337.cfg"
const END_PAUSE: float = 1.0
const SNAP: float = 0.2
const SWIPE_SHARE: float = 0.18
const SWIPE_VEL: float = 700.0
const SIDE_MIN: float = 64.0
const SIDE_MAX: float = 124.0
const M: float = 8.0
const SECTION_ICONS: Dictionary = {"ЭКОНОМИКА": "icon_farm", "ТОРГОВЛЯ": "icon_trade", "АРМИЯ": "icon_tank", 
	"ПВО": "icon_ad_sam", "УДАРЫ": "icon_strike", "ФЛОТ": "icon_ship", "ПОЛИТИКА": "icon_relations", "ПАРТИЯ": "icon_menu"}

const LOC_TUT337_SECTIONS: Dictionary = {"econ": "ЭКОНОМИКА", "trade": "ТОРГОВЛЯ", "army": "АРМИЯ", "ad": "ПВО", 
	"strike": "УДАРЫ", "navy": "ФЛОТ", "dip": "ПОЛИТИКА", "game": "ПАРТИЯ"}
const LOC_TUT337_TITLES: Dictionary = {"econ_basics": "Экономика: основы", "econ_cities": "Города и энергия", 
	"econ_ores": "Недра: залежи и добыча", "econ_chains": "Цепочки ресурсов", "trade_port": "Торговля и порт", 
	"rail_build": "Железная дорога", "supply": "Снабжение и мосты", "army_barracks": "Казармы и состав", 
	"army_orders": "Приказы армии", "army_rail": "Быстрый марш и поезд", "army_groups": "Группы и фронт", 
	"army_upkeep": "Содержание армии", "ad_who": "ПВО: кто что сбивает", "ad_radar_rules": "Радар, РЭБ и мирное небо", 
	"strike_drones": "Дроны и разведка", "strike_missiles": "Ракеты и ОТРК", "strike_air": "Авиация и КАБ", 
	"navy_basics": "Флот", "dip_treaties": "Отношения и договоры", "dip_requests": "Просьбы, эмбарго, статус", 
	"dip_war_peace": "Война, мир и конференция", "game_saves": "Время и сохранения"}

static var _open: CanvasLayer

var clips: Array[Dictionary] = []
var sections: Array[Dictionary] = []
var cur: int = 0
var from_pause: bool = false

var root: Control
var top: PanelContainer
var title_l: Label
var count_l: Label
var close_b: Button
var cards: Array[Button] = []
var stage: Control
var slide: Control
var vp: VideoStreamPlayer
var pill_l: Label
var paused_ic: TextureRect
var incoming: Control
var in_icon: TextureRect
var in_sec: Label
var in_title: Label
var play_b: Button
var scrub: Control
var time_l: Label
var next_l: Label
var hint_l: Label
var peek: Button
var peek_icon: TextureRect
var peek_l: Label
var peek_big: TextureRect
var peek_sec: Label
var peek_sub: Label
var _compact: bool = false
var _film: Vector2 = FILM * 0.5
var _press: bool = false
var _press_y: float = 0.0
var _press_ms: int = 0
var _dy: float = 0.0
var _vel: float = 0.0
var _last_my: float = 0.0
var _last_ms: int = 0
var _anim: Tween
var _busy: bool = false
var _end_t: float = -1.0
var _user_paused: bool = false
var _scrubbing: bool = false
var _seek_ms: int = 0
var _wheel_ms: int = 0
var _cache: Dictionary = {}
var _bus_keep: Dictionary = {}
var errors: Array[String] = []



static func open(host: Node, opened_from_pause: bool = false) -> CanvasLayer:
	if is_instance_valid(_open) and not _open.is_queued_for_deletion():
		return _open
	var f: CanvasLayer = (load(SELF) as GDScript).new() as CanvasLayer
	f.set("from_pause", opened_from_pause)
	f.name = "TutorialFeed"
	host.get_tree().root.add_child(f)
	_open = f
	return f


static func is_open() -> bool:
	return is_instance_valid(_open) and not _open.is_queued_for_deletion()



static func close_if_open() -> bool:
	if not is_open():
		return false
	_open.call("close")
	return true


func _ready() -> void :
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_manifest()
	_build()
	_mute_beds(true)
	get_viewport().size_changed.connect(_layout)
	cur = clampi(_last_watched(), 0, maxi(clips.size() - 1, 0))
	_layout()
	if not clips.is_empty():
		_set_clip(cur)
	UiKit.snd("ui_open")
	root.modulate.a = 0.0
	var tw: Tween = root.create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.15)


func _exit_tree() -> void :
	if _open == self:
		_open = null
	if ResourceLoader.exists("res://core/sfx.gd") and Sfx.beds_off:
		Sfx.set_beds_off(false)




func _load_manifest() -> void :
	var fa: FileAccess = FileAccess.open(MANIFEST, FileAccess.READ)
	if fa == null:
		push_warning("TutorialFeed: no manifest " + MANIFEST)
		return
	var d: Variant = JSON.parse_string(fa.get_as_text())
	if not (d is Dictionary) or not (d as Dictionary).has("clips"):
		return
	for c: Variant in (d as Dictionary)["clips"]:
		if c is Dictionary:
			clips.append(c as Dictionary)
	for i in clips.size():
		var sec: String = String(clips[i].get("section", ""))
		if sections.is_empty() or String(sections[-1]["name"]) != sec:
			sections.append({"name": sec, "first": i, "count": 0, "icon": String(SECTION_ICONS.get(sec, "icon_tutorial"))})
		sections[-1]["count"] = int(sections[-1]["count"]) + 1


func _path(i: int) -> String:
	var f: String = String(_l10n(i).get("file", ""))
	if f != "" and ResourceLoader.exists(DIR + f):
		return DIR + f
	return DIR + String(clips[i].get("file", ""))




func _l10n(i: int) -> Dictionary:
	var l: Variant = clips[i].get("l10n", {})
	if Loc.lang != Loc.SRC and l is Dictionary and (l as Dictionary).get(Loc.lang, null) is Dictionary:
		return (l as Dictionary)[Loc.lang] as Dictionary
	return {}


func _sec_of(i: int) -> int:
	for s in range(sections.size() - 1, -1, -1):
		if i >= int(sections[s]["first"]):
			return s
	return 0



func _sec_name(si: int) -> String:
	var t: String = String(_l10n(int(sections[si]["first"])).get("section", ""))
	return t if t != "" else Loc.t(String(sections[si]["name"]))


func _title(i: int) -> String:
	var t: String = String(_l10n(i).get("title", ""))
	return t if t != "" else Loc.t(String(clips[i].get("title", "")))


func _stream(i: int) -> VideoStream:
	var p: String = _path(i)
	if _cache.has(p):
		return _cache[p] as VideoStream
	var st: VideoStream = null
	if ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		st = ResourceLoader.load_threaded_get(p) as VideoStream
	if st == null and ResourceLoader.exists(p):
		st = load(p) as VideoStream
	if st == null:
		errors.append(p)
	else:
		_cache[p] = st
	return st



func _preload_near() -> void :
	var keep: Dictionary = {}
	for i: int in [cur - 1, cur, cur + 1]:
		if i < 0 or i >= clips.size():
			continue
		var p: String = _path(i)
		keep[p] = true
		if not _cache.has(p) and ResourceLoader.exists(p) and ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(p, "", false)
	for p: String in _cache.keys():
		if not keep.has(p):
			_cache.erase(p)


func _last_watched() -> int:
	var cf: = ConfigFile.new()
	if cf.load(PREFS) != OK:
		return 0
	var id: String = String(cf.get_value("feed", "last", ""))
	for i in clips.size():
		if String(clips[i].get("id", "")) == id:
			return i
	return 0


func _save_last() -> void :
	if clips.is_empty():
		return
	var cf: = ConfigFile.new()
	cf.load(PREFS)
	cf.set_value("feed", "last", String(clips[cur].get("id", "")))
	cf.save(PREFS)



func _mute_beds(on: bool) -> void :
	if ResourceLoader.exists("res://core/sfx.gd"):
		Sfx.set_beds_off(on)
		return
	for bn: String in ["Music", "Ambience"]:
		var bi: int = AudioServer.get_bus_index(bn)
		if bi < 0:
			continue
		if on:
			_bus_keep[bn] = AudioServer.is_bus_mute(bi)
			AudioServer.set_bus_mute(bi, true)
		elif _bus_keep.has(bn):
			AudioServer.set_bus_mute(bi, bool(_bus_keep[bn]))




func _lbl(text: String, size: int, col: Color, weight: int = 2, outline: int = 0) -> Label:
	var l: Label = UiKit.lbl(text, size, col, weight, outline)
	UiKit.no_tr(l)
	l.clip_text = true
	return l


func _build() -> void :
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg: = Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", UiKit.sb("wb_window"))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	top = PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiKit.sb("wb_topbar", 10, 2))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(hb)
	title_l = UiKit.title(Loc.t("ОБУЧЕНИЕ"), 18)
	UiKit.no_tr(title_l)
	title_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(title_l)
	count_l = _lbl("", 11, UiKit.MUTED, 2, 3)
	count_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(count_l)
	close_b = UiKit.close_btn(34.0)
	close_b.name = "Close"
	close_b.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_red", 4))
	close_b.add_theme_stylebox_override("hover", UiKit.sb("wb_btn_red", 4))
	close_b.add_theme_stylebox_override("pressed", UiKit.sb("wb_btn_red_p", 4))
	close_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_b.pressed.connect(close)
	hb.add_child(close_b)

	for s in sections.size():
		var b: = Button.new()
		b.name = "Card%d" % s
		b.focus_mode = Control.FOCUS_NONE
		b.clip_contents = true
		var ic: TextureRect = UiKit.icon_rect(String(sections[s]["icon"]), 26.0)
		ic.name = "Icon"
		b.add_child(ic)
		var nl: Label = _lbl(_sec_name(s), 10, UiKit.TEXT, 2, 3)
		nl.name = "Name"
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if not Loc.is_src():
			UiKit.fit_lbl(nl, [10, 9, 8])
		b.add_child(nl)
		var cnt: int = int(sections[s]["count"])
		var cl: Label = _lbl("%d %s" % [cnt, Loc.n(cnt, "ролик", "ролика", "роликов")], 9, UiKit.MUTED, 1, 2)
		cl.name = "Count"
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(cl)
		UiKit.tap_snd(b)
		b.pressed.connect(_jump_section.bind(s))
		root.add_child(b)
		cards.append(b)

	stage = Control.new()
	stage.name = "Stage"
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.gui_input.connect(_stage_input)
	root.add_child(stage)
	var black: = ColorRect.new()
	black.color = Color(0.035, 0.03, 0.028)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(black)
	slide = Control.new()
	slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(slide)
	vp = VideoStreamPlayer.new()
	vp.name = "Video"
	vp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vp.expand = true
	vp.autoplay = false
	vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(&"SFX") < 0 and ResourceLoader.exists("res://core/sfx.gd"):
		Sfx.load_settings()
		Sfx._apply_bus_volumes()
	if AudioServer.get_bus_index(&"SFX") >= 0:
		vp.bus = &"SFX"
	vp.finished.connect(_on_finished)
	slide.add_child(vp)
	var pill: = PanelContainer.new()
	pill.name = "Pill"
	pill.add_theme_stylebox_override("panel", UiKit.sb("wb_pill", 7, 2))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slide.add_child(pill)
	pill_l = _lbl("", 11, UiKit.TEXT, 2, 2)
	pill_l.clip_text = false
	pill.add_child(pill_l)
	paused_ic = UiKit.icon_rect("icon_play", 40.0)
	paused_ic.visible = false
	slide.add_child(paused_ic)
	incoming = Control.new()
	incoming.mouse_filter = Control.MOUSE_FILTER_IGNORE
	incoming.visible = false
	stage.add_child(incoming)
	var ip: = Panel.new()
	ip.set_anchors_preset(Control.PRESET_FULL_RECT)
	ip.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark"))
	ip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	incoming.add_child(ip)
	in_icon = UiKit.icon_rect("icon_tutorial", 56.0)
	incoming.add_child(in_icon)
	in_sec = _lbl("", 11, UiKit.GOLD, 2, 3)
	in_sec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	incoming.add_child(in_sec)
	in_title = _lbl("", 16, UiKit.TEXT, 3, 4)
	in_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	in_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	in_title.clip_text = false
	incoming.add_child(in_title)

	play_b = UiKit.slot("icon_pause", false, 34.0)
	play_b.name = "Play"
	play_b.pressed.connect(toggle_pause)
	root.add_child(play_b)
	scrub = Control.new()
	scrub.name = "Scrub"
	scrub.mouse_filter = Control.MOUSE_FILTER_STOP
	scrub.draw.connect(_draw_scrub)
	scrub.gui_input.connect(_scrub_input)
	root.add_child(scrub)
	time_l = _lbl("0:00 / 0:00", 11, UiKit.TEXT, 2, 2)
	time_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_l.clip_text = false
	root.add_child(time_l)
	next_l = _lbl("", 10, UiKit.TITLE, 2, 2)
	root.add_child(next_l)
	hint_l = _lbl(Loc.t("ЛИСТАЙТЕ ВВЕРХ"), 9, UiKit.MUTED, 2, 2)
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hint_l)
	peek = Button.new()
	peek.name = "Peek"
	peek.focus_mode = Control.FOCUS_NONE
	peek.clip_contents = true
	for st: String in ["normal", "hover", "pressed", "hover_pressed"]:
		peek.add_theme_stylebox_override(st, UiKit.sb("wb_card", 4))
	peek.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UiKit.tap_snd(peek)
	peek.pressed.connect( func() -> void : go(cur + 1 if cur + 1 < clips.size() else 0))
	root.add_child(peek)
	var rib: = Panel.new()
	rib.name = "Ribbon"
	rib.add_theme_stylebox_override("panel", UiKit.sb("wb_ribbon"))
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	peek.add_child(rib)
	peek_icon = UiKit.icon_rect("icon_tutorial", 26.0)
	peek.add_child(peek_icon)
	peek_l = _lbl("", 14, UiKit.TEXT, 3, 4)
	peek_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	peek.add_child(peek_l)
	peek_big = UiKit.icon_rect("icon_tutorial", 48.0)
	peek.add_child(peek_big)
	peek_sec = _lbl("", 11, UiKit.GOLD, 2, 3)
	peek_sec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	peek.add_child(peek_sec)
	peek_sub = _lbl("", 10, UiKit.MUTED, 2, 2)
	peek_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	peek.add_child(peek_sub)




func _safe_tb() -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if win.x <= 0.0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector2.ZERO
	var s: float = get_viewport().get_visible_rect().size.x / win.x
	var t: float = maxf(0.0, float(safe.position.y) * s)
	var b: float = maxf(0.0, (win.y - float(safe.end.y)) * s)
	return Vector2.ZERO if t > 90.0 or b > 90.0 else Vector2(t, b)


func _layout() -> void :
	if root == null:
		return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var sa: Vector2 = _safe_tb()
	var head_h: float = 44.0 if vs.y >= 720.0 else 40.0
	top.position = Vector2(M * 0.5, M * 0.5 + sa.x)
	top.size = Vector2(vs.x - M, head_h)
	var y0: float = top.position.y + head_h + 6.0
	var ctl_h: float = 36.0
	var nxt_h: float = 16.0
	var peek_h: float = clampf(roundf(vs.y * 0.07), 40.0, 58.0)
	var bottom: float = vs.y - M - sa.y
	var avail: float = bottom - y0 - ctl_h - nxt_h - peek_h - 12.0
	var fh: float = avail
	var fw: float = fh * FILM.x / FILM.y
	var side: float = vs.x - fw - 3.0 * M
	if side < SIDE_MIN:
		side = SIDE_MIN
		fw = vs.x - side - 3.0 * M
		fh = fw * FILM.y / FILM.x
	side = minf(side, SIDE_MAX)

	var px: float = get_viewport().get_final_transform().get_scale().x
	var kp: float = fw / FILM.x * px
	if kp >= 2.0:
		fw = floorf(kp) * FILM.x / px
		fh = fw * FILM.y / FILM.x
	fw = floorf(fw)
	fh = floorf(fh)
	_film = Vector2(fw, fh)
	var used: float = side + M + fw
	var x0: float = floorf((vs.x - used) * 0.5)
	var fx: float = x0 + side + M
	stage.position = Vector2(fx, y0)
	stage.size = _film
	slide.size = _film
	slide.position = Vector2.ZERO
	vp.position = Vector2.ZERO
	vp.size = _film
	incoming.size = _film
	var pill: Control = slide.get_node("Pill") as Control
	pill.reset_size()
	pill.position = Vector2(fw - pill.size.x - 8.0, 8.0)
	paused_ic.position = ((_film - paused_ic.size) * 0.5).round()
	in_icon.position = Vector2(floorf((fw - in_icon.size.x) * 0.5), floorf(fh * 0.34))
	in_sec.position = Vector2(8.0, in_icon.position.y + in_icon.size.y + 10.0)
	in_sec.size = Vector2(fw - 16.0, 16.0)
	in_title.position = Vector2(10.0, in_sec.position.y + 20.0)
	in_title.size = Vector2(fw - 20.0, 60.0)

	var cy: float = y0 + fh + 4.0
	play_b.position = Vector2(fx, cy + 1.0)
	play_b.size = Vector2(34, 34)
	var tw: float = 66.0
	time_l.position = Vector2(fx + fw - tw, cy + 9.0)
	time_l.size = Vector2(tw, 18.0)
	scrub.position = Vector2(fx + 42.0, cy + 2.0)
	scrub.size = Vector2(maxf(40.0, fw - 42.0 - tw - 6.0), 32.0)
	var ny: float = cy + ctl_h + 2.0
	next_l.position = Vector2(fx, ny)
	next_l.size = Vector2(fw, nxt_h)
	hint_l.position = Vector2(fx, ny)
	hint_l.size = Vector2(fw, nxt_h)
	peek.position = Vector2(fx, ny + nxt_h + 4.0)
	peek.size = Vector2(fw, maxf(peek_h, bottom - peek.position.y))
	var rib: Control = peek.get_node("Ribbon") as Control
	var ph: float = peek.size.y
	var tall: bool = ph >= 96.0
	var big: bool = ph >= 150.0
	rib.position = Vector2(6, floorf((ph - 28.0) * 0.5) + (22.0 if big else (6.0 if tall else 0.0)))
	rib.size = Vector2(fw - 12.0, 28.0)
	peek_sec.visible = tall
	peek_sub.visible = tall
	peek_big.visible = big
	peek_sec.position = Vector2(8.0, rib.position.y - 20.0)
	peek_sec.size = Vector2(fw - 16.0, 16.0)
	peek_sub.position = Vector2(8.0, rib.position.y + 33.0)
	peek_sub.size = Vector2(fw - 16.0, 14.0)
	peek_big.position = Vector2(floorf((fw - peek_big.size.x) * 0.5), peek_sec.position.y - peek_big.size.y - 6.0)
	UiKit.set_icon(peek_icon, String(peek_icon.get_meta("icon", "icon_tutorial")), 22.0)
	peek_icon.position = Vector2(12.0, floorf(rib.position.y + 14.0 - peek_icon.size.y * 0.5))
	peek_l.position = Vector2(12.0 + peek_icon.size.x + 4.0, rib.position.y + 3.0)
	peek_l.size = Vector2(fw - 2.0 * (16.0 + peek_icon.size.x), 22.0)
	_fit_font(peek_l, [14, 12, 11, 10])

	var col_h: float = peek.position.y + peek.size.y - y0
	var n: int = maxi(cards.size(), 1)
	var gap: float = 5.0
	var ch: float = floorf(minf(84.0, (col_h - gap * float(n - 1)) / float(n)))
	_compact = side < 60.0 or ch < 46.0
	for s in cards.size():
		var b: Button = cards[s]
		b.position = Vector2(x0, y0 + float(s) * (ch + gap))
		b.size = Vector2(side, ch)
		var ic: TextureRect = b.get_node("Icon") as TextureRect
		var nl: Label = b.get_node("Name") as Label
		var cl: Label = b.get_node("Count") as Label
		var ib: float = clampf(ch - 34.0, 18.0, 30.0) if not _compact else clampf(ch - 18.0, 16.0, 30.0)
		UiKit.set_icon(ic, String(sections[s]["icon"]), ib)
		nl.visible = not _compact
		var cnt: int = int(sections[s]["count"])
		cl.text = str(cnt) if _compact else "%d %s" % [cnt, Loc.n(cnt, "ролик", "ролика", "роликов")]
		var content: float = ic.size.y + (14.0 if not _compact else 0.0) + 12.0
		var ty: float = floorf((ch - content) * 0.5)
		ic.position = Vector2(floorf((side - ic.size.x) * 0.5), ty)
		nl.position = Vector2(3.0, ty + ic.size.y + 1.0)
		nl.size = Vector2(side - 6.0, 14.0)
		_fit_font(nl, [11, 10, 9, 8])
		cl.position = Vector2(3.0, nl.position.y + (14.0 if not _compact else 0.0))
		cl.size = Vector2(side - 6.0, 12.0)
		_fit_font(cl, [9, 8])
	_mark()
	scrub.queue_redraw()



func _fit_font(l: Label, sizes: Array) -> void :
	var f: Font = l.get_theme_font("font")
	for sz: Variant in sizes:
		if f == null or f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(sz)).x <= l.size.x - 2.0:
			l.add_theme_font_size_override("font_size", int(sz))
			return
	l.add_theme_font_size_override("font_size", int(sizes[-1]))





func _mark() -> void :
	if clips.is_empty():
		return
	count_l.text = Loc.f("ролик {n} из {total}", {"n": cur + 1, "total": clips.size()})
	var cs: int = _sec_of(cur)
	for s in cards.size():
		var on: bool = s == cs
		var b: Button = cards[s]
		var stl: StyleBox = UiKit.sb("wb_slot_active" if on else "wb_slot", 4)
		for st: String in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, stl)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		(b.get_node("Name") as Label).add_theme_color_override("font_color", UiKit.TEXT if on else UiKit.MUTED)
		(b.get_node("Count") as Label).add_theme_color_override("font_color", UiKit.GOLD if on else UiKit.DIM)
	var first: int = int(sections[cs]["first"])
	pill_l.text = "%d / %d" % [cur - first + 1, int(sections[cs]["count"])]
	var pill: Control = slide.get_node("Pill") as Control
	pill.reset_size()
	pill.position = Vector2(_film.x - pill.size.x - 8.0, 8.0)
	var last: bool = cur + 1 >= clips.size()
	next_l.text = Loc.t("ЭТО ПОСЛЕДНИЙ РОЛИК") if last else Loc.f("ДАЛЕЕ: {title}", {"title": _title(cur + 1).to_upper()})
	hint_l.text = "" if last else Loc.t("ЛИСТАЙТЕ ВВЕРХ")
	var ni: int = 0 if last else cur + 1
	peek_l.text = Loc.t("К ПЕРВОМУ РОЛИКУ") if last else _title(ni).to_upper()
	var pic: String = String(sections[_sec_of(ni)]["icon"])
	peek_icon.set_meta("icon", pic)
	UiKit.set_icon(peek_icon, pic, 22.0)
	UiKit.set_icon(peek_big, pic, 48.0)
	peek_big.position.x = floorf((peek.size.x - peek_big.size.x) * 0.5)
	peek_sec.text = _sec_name(_sec_of(ni))
	peek_sub.text = "%s · %s" % [Loc.f("ролик {n} из {total}", {"n": ni + 1, "total": clips.size()}), _mmss(float(clips[ni].get("duration", 0.0)))]
	if peek.size.x > 0.0:
		_fit_font(peek_l, [14, 12, 11, 10])
	_fit_next()



func _fit_next() -> void :
	var f: Font = next_l.get_theme_font("font")
	if f == null or next_l.size.x <= 0.0:
		return
	var nw: float = f.get_string_size(next_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var hf: Font = hint_l.get_theme_font("font")
	var hw: float = hf.get_string_size(hint_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x if hf != null else 0.0
	hint_l.visible = hint_l.text != "" and nw + hw + 10.0 <= next_l.size.x
	next_l.add_theme_font_size_override("font_size", 10 if f.get_string_size(next_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= next_l.size.x else 9)


func _set_clip(i: int) -> void :
	cur = clampi(i, 0, clips.size() - 1)
	_end_t = -1.0
	_user_paused = false
	vp.stop()
	vp.stream = _stream(cur)
	vp.paused = false
	if vp.stream != null:
		vp.play()
	slide.position = Vector2.ZERO
	incoming.visible = false
	paused_ic.visible = false
	UiKit.set_slot_icon(play_b, "icon_pause")
	_mark()
	_save_last()
	_preload_near()
	scrub.queue_redraw()


func _fill_incoming(i: int) -> void :
	var s: int = _sec_of(i)
	UiKit.set_icon(in_icon, String(sections[s]["icon"]), 56.0)
	in_icon.position.x = floorf((_film.x - in_icon.size.x) * 0.5)
	in_sec.text = _sec_name(s)
	in_title.text = _title(i).to_upper()



func go(i: int, from_dy: float = 0.0) -> void :
	if clips.is_empty() or _busy:
		return
	i = clampi(i, 0, clips.size() - 1)
	_press = false
	if i == cur:
		_snap_back()
		return
	var dir: float = -1.0 if i > cur else 1.0
	_fill_incoming(i)
	incoming.visible = true
	slide.position.y = from_dy
	incoming.position.y = from_dy - dir * _film.y
	vp.paused = true
	_busy = true
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_anim = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_anim.tween_property(slide, "position:y", dir * _film.y, SNAP)
	_anim.tween_property(incoming, "position:y", 0.0, SNAP)
	_anim.chain().tween_callback( func() -> void :
		_busy = false
		_set_clip(i))
	UiKit.snd("ui_tab")


func _snap_back() -> void :
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_busy = true
	_anim = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim.tween_property(slide, "position:y", 0.0, SNAP)
	if incoming.visible:
		var away: float = _film.y if incoming.position.y > 0.0 else - _film.y
		_anim.tween_property(incoming, "position:y", away, SNAP)
	_anim.chain().tween_callback( func() -> void :
		_busy = false
		incoming.visible = false
		if not _user_paused and vp.stream != null:
			vp.paused = false)


func _jump_section(s: int) -> void :
	if s < 0 or s >= sections.size():
		return
	var i: int = int(sections[s]["first"])
	if i == cur:
		seek(0.0)
		return
	go(i)


func next() -> void :
	if cur + 1 < clips.size():
		go(cur + 1)


func prev() -> void :
	if cur > 0:
		go(cur - 1)


func toggle_pause() -> void :
	if vp.stream == null:
		return
	if _end_t >= 0.0 or not vp.is_playing():
		_end_t = -1.0
		_user_paused = false
		vp.play()
		vp.paused = false
	else:
		_user_paused = not _user_paused
		vp.paused = _user_paused
	paused_ic.visible = _user_paused
	UiKit.set_slot_icon(play_b, "icon_play" if _user_paused else "icon_pause")


func seek(t: float) -> void :
	if vp.stream == null:
		return
	var ln: float = vp.get_stream_length()
	t = clampf(t, 0.0, maxf(ln - 0.05, 0.0))
	if not vp.is_playing():
		vp.play()
		vp.paused = _user_paused or _scrubbing
		UiKit.set_slot_icon(play_b, "icon_play" if _user_paused else "icon_pause")
	_end_t = -1.0
	vp.stream_position = t
	scrub.queue_redraw()


func close() -> void :
	if is_queued_for_deletion():
		return
	_save_last()
	vp.stop()
	vp.stream = null
	_cache.clear()
	_mute_beds(false)
	UiKit.snd("ui_close")
	closed.emit()
	queue_free()


func _on_finished() -> void :
	_end_t = END_PAUSE if cur + 1 < clips.size() else 0.0
	paused_ic.visible = false
	UiKit.set_slot_icon(play_b, "icon_play" if cur + 1 >= clips.size() else "icon_pause")


func _process(delta: float) -> void :
	if clips.is_empty():
		return
	if _end_t > 0.0 and not _press and not _busy:
		_end_t -= delta
		if _end_t <= 0.0:
			_end_t = -1.0
			next()
	var ln: float = vp.get_stream_length() if vp.stream != null else 0.0
	var pos: float = ln if _end_t >= 0.0 else (vp.stream_position if vp.stream != null else 0.0)
	var s: String = "%s / %s" % [_mmss(pos), _mmss(ln)]
	if time_l.text != s:
		time_l.text = s
	scrub.queue_redraw()


static func _mmss(t: float) -> String:
	var s: int = int(floorf(maxf(t, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]


func _notification(what: int) -> void :
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and vp != null and vp.is_playing() and not _user_paused:
		toggle_pause()




func _stage_input(ev: InputEvent) -> void :
	if _busy:
		return
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if mb.pressed and Time.get_ticks_msec() - _wheel_ms > 350:
				_wheel_ms = Time.get_ticks_msec()
				if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					next()
				else:
					prev()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press = true
			_press_y = mb.position.y
			_press_ms = Time.get_ticks_msec()
			_last_my = mb.position.y
			_last_ms = _press_ms
			_dy = 0.0
			_vel = 0.0
		elif _press:
			_press = false
			_release()
	elif ev is InputEventMouseMotion and _press:
		var mm: InputEventMouseMotion = ev as InputEventMouseMotion
		_drag_to(mm.position.y)


func _drag_to(y: float) -> void :
	var now: int = Time.get_ticks_msec()
	var dt: float = maxf(float(now - _last_ms) / 1000.0, 0.001)
	_vel = lerpf(_vel, (y - _last_my) / dt, 0.5)
	_last_my = y
	_last_ms = now
	var raw: float = y - _press_y
	var tgt: int = cur + (1 if raw < 0.0 else -1)
	var open_end: bool = tgt >= 0 and tgt < clips.size()
	_dy = raw if open_end else raw * 0.3
	slide.position.y = _dy
	if open_end and absf(_dy) > 4.0:
		if not incoming.visible or incoming.get_meta("for", -1) != tgt:
			_fill_incoming(tgt)
			incoming.set_meta("for", tgt)
			incoming.visible = true
		incoming.position.y = _dy + (_film.y if _dy < 0.0 else - _film.y)
	else:
		incoming.visible = false


func _release() -> void :
	var held: int = Time.get_ticks_msec() - _press_ms
	if absf(_dy) < 8.0 and held < 400:
		slide.position.y = 0.0
		incoming.visible = false
		toggle_pause()
		return
	var want: int = 0
	if _dy < - _film.y * SWIPE_SHARE or (_vel < - SWIPE_VEL and _dy < -12.0):
		want = 1
	elif _dy > _film.y * SWIPE_SHARE or (_vel > SWIPE_VEL and _dy > 12.0):
		want = -1
	var tgt: int = cur + want
	if want != 0 and tgt >= 0 and tgt < clips.size():
		go(tgt, _dy)
	else:
		_snap_back()


func _scrub_input(ev: InputEvent) -> void :
	if vp.stream == null:
		return
	var x: float = -1.0
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		if mb.pressed:
			_scrubbing = true
			vp.paused = true
			x = mb.position.x
		elif _scrubbing:
			_scrubbing = false
			seek(_scrub_t(mb.position.x))
			vp.paused = _user_paused
			return
	elif ev is InputEventMouseMotion and _scrubbing:
		x = (ev as InputEventMouseMotion).position.x
	if x >= 0.0:
		var now: int = Time.get_ticks_msec()
		if now - _seek_ms > 60:
			_seek_ms = now
			seek(_scrub_t(x))
		scrub.set_meta("drag_x", x)
		scrub.queue_redraw()


func _scrub_t(x: float) -> float:
	var w: float = maxf(scrub.size.x - 16.0, 1.0)
	return clampf((x - 8.0) / w, 0.0, 1.0) * vp.get_stream_length()


func _draw_scrub() -> void :
	var w: float = scrub.size.x
	var h: float = scrub.size.y
	var tr: = Rect2(4.0, floorf(h * 0.5) - 6.0, w - 8.0, 12.0)
	scrub.draw_style_box(UiKit.sb("wb_bar_frame", 0), tr)
	var ln: float = vp.get_stream_length() if vp != null and vp.stream != null else 0.0
	var p: float = 0.0
	if ln > 0.0:
		p = 1.0 if _end_t >= 0.0 else clampf(vp.stream_position / ln, 0.0, 1.0)
	if _scrubbing and scrub.has_meta("drag_x"):
		p = clampf((float(scrub.get_meta("drag_x")) - 8.0) / maxf(w - 16.0, 1.0), 0.0, 1.0)
	var inner: = Rect2(tr.position + Vector2(2, 2), tr.size - Vector2(4, 4))
	var fw: float = floorf(inner.size.x * p)
	if fw > 0.0:
		scrub.draw_rect(Rect2(inner.position, Vector2(fw, inner.size.y)), UiKit.TITLE)
		scrub.draw_rect(Rect2(inner.position, Vector2(fw, 2.0)), UiKit.GOLD)
	if ln > 0.0:
		var t: float = 5.0
		while t < ln - 0.5:
			var tx: float = floorf(inner.position.x + inner.size.x * t / ln)
			scrub.draw_rect(Rect2(tx, tr.end.y + 2.0, 1.0, 3.0), Color(UiKit.MUTED, 0.6))
			t += 5.0
	var kx: float = floorf(inner.position.x + fw)
	var knob: = Rect2(kx - 4.0, floorf(h * 0.5) - 10.0, 9.0, 20.0)
	scrub.draw_rect(knob.grow(1.0), UiKit.OUTLINE)
	scrub.draw_rect(knob, UiKit.TITLE)
	scrub.draw_rect(Rect2(knob.position + Vector2(2, 2), Vector2(5, 3)), UiKit.GOLD)


func _unhandled_input(ev: InputEvent) -> void :
	if ev.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("ui_down") or ev.is_action_pressed("ui_page_down"):
		next()
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("ui_up") or ev.is_action_pressed("ui_page_up"):
		prev()
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("ui_accept"):
		toggle_pause()
		get_viewport().set_input_as_handled()
