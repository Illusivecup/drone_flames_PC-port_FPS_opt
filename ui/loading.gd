class_name Loading
extends CanvasLayer







const TIPS: Array = [
	"Удар по чужой земле — это объявление войны.", 
	"Окопы и зубы дракона рисуются пальцем: проведите линию по своей земле.", 
	"Зубы дракона не пропускают танки и грузовики — тем приходится искать объезд.", 
	"Ночью города без света видны сразу. Берегите ТЭЦ и ставьте солнечные панели.", 
	"РЛС увеличивает дальность, на которой ваша ПВО видит цели.", 
	"Титан нужен танкам и самолётам — стройте рудник на серо-голубых камнях.", 
	"Разрушенный мост восстанавливается сам примерно через минуту.", 
	"Дрон можно перенацелить прямо в полёте: выберите его и тапните по карте.", 
	"Гиперзвуковые ракеты почти не сбиваются ПВО, но стоят дорого.", 
	"Союзники вступают в войну на вашей стороне.", 
	"ПТУР в окопе — лучший ответ на танковую атаку.", 
	"Режим обороны: пехота сама занимает окопы рядом с городами.", 
	"Выбранный объект виден слева. Красный крестик — отменить выбор.", 
]

const SPLASH_SIZE: = Vector2(1080, 2340)
const SPLASH_LOGO: = Vector2(-37, 900)
const SPLASH_K: float = 5.0
const SKY_TOP: = Color("2f6fd0")
const SKY_BOT: = Color("0f1c45")
const EMBER_COLS: Array = [Color("fff3a8"), Color("ffe04a"), Color("ffa02c"), Color("ef561c")]
const FLAME_SHADER: = "\nshader_type canvas_item;\nuniform float t = 0.0;\nuniform float amt = 0.0;\nvoid fragment() {\n\tvec4 src = texture(TEXTURE, UV);\n\tvec2 px = floor(UV / TEXTURE_PIXEL_SIZE);\n\tfloat warm = step(0.9, src.r) * step(src.b, 0.7) * step(0.3, src.g);\n\tfloat h = fract(sin(px.x * 12.9898) * 43758.5453);\n\tfloat w = sin(t * 6.0 + px.y * 0.7 + h * 2.5) + 0.6 * sin(t * 9.7 - px.x * 0.45);\n\tfloat k = floor(w * 1.5 + 0.5) / 3.0;\n\tCOLOR.rgb += warm * amt * vec3(0.0, 0.11, 0.06) * k * COLOR.a;\n}\n"














var root: Control
var bg: TextureRect
var glow: TextureRect
var bar_fill: Panel
var bar_frame: PanelContainer
var stage: Label
var tip: Label
var logo: TextureRect
var drone: TextureRect
var embers_node: Control
var credits_row: HBoxContainer
var ui_nodes: Array = []
var clouds: Array = []
var embers: Array = []
var _flame_mat: ShaderMaterial
var _stage_base: String = ""
var _target: float = 0.0
var _shown: float = 0.0
var _t: float = 0.0
var _drone_x: float = -60.0
var active: bool = false


func _ready() -> void :
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.ensure()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = UiKit.make_theme()
	add_child(root)
	bg = TextureRect.new()
	var g: = Gradient.new()
	g.set_color(0, SKY_TOP)
	g.set_color(1, SKY_BOT)
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	bg.texture = gt
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	for i in 5:
		var nm: String = ["cloud_a", "cloud_b", "cloud_c"][i % 3]
		var c: = TextureRect.new()
		c.texture = UiKit.tex(nm)
		if c.texture == null:
			continue
		c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.scale = Vector2(2, 2) if i % 2 == 0 else Vector2(3, 3)
		c.modulate.a = 0.0
		c.position = Vector2(randf_range(-150.0, 360.0), 40.0 + float(i) * 150.0 + randf_range(-30.0, 30.0))
		root.add_child(c)
		clouds.append([c, 5.0 + float(i) * 3.0, 0.25 + 0.08 * float(i % 3)])
	glow = TextureRect.new()
	var gg: = Gradient.new()
	gg.set_color(0, Color(1.0, 0.55, 0.15, 0.7))
	gg.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	var ggt: = GradientTexture2D.new()
	ggt.gradient = gg
	ggt.fill = GradientTexture2D.FILL_RADIAL
	ggt.fill_from = Vector2(0.5, 0.5)
	ggt.fill_to = Vector2(0.5, 0.0)
	ggt.width = 32
	ggt.height = 32
	glow.texture = ggt
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add_mat: = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add_mat
	glow.modulate.a = 0.0
	root.add_child(glow)
	embers_node = Control.new()
	embers_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	embers_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	embers_node.draw.connect(_draw_embers)
	root.add_child(embers_node)
	logo = TextureRect.new()
	logo.texture = UiKit.tex("logo_df")
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sh: = Shader.new()
	sh.code = FLAME_SHADER
	_flame_mat = ShaderMaterial.new()
	_flame_mat.shader = sh
	logo.material = _flame_mat
	root.add_child(logo)
	if logo.texture == null:
		var t: Label = UiKit.title("DRONE FLAMES", 34)
		t.set_anchors_preset(Control.PRESET_CENTER)
		root.add_child(t)
	stage = UiKit.lbl("", 13, UiKit.TEXT, 2, 3)
	stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(stage)
	bar_frame = PanelContainer.new()
	bar_frame.add_theme_stylebox_override("panel", UiKit.sb("wb_bar_frame", 3))
	bar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_frame)
	bar_fill = Panel.new()
	bar_fill.add_theme_stylebox_override("panel", UiKit.sb("wb_bar_amber", 0))
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_frame.add_child(bar_fill)
	tip = UiKit.lbl("", 11, UiKit.MUTED, 1, 2)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(tip)
	drone = TextureRect.new()
	drone.texture = UiKit.tex("load_drone_0")
	drone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	drone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drone.scale = Vector2(2, 2)
	root.add_child(drone)
	credits_row = HBoxContainer.new()
	credits_row.add_theme_constant_override("separation", 6)
	credits_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(credits_row)
	var clbl: Label = UiKit.lbl("Порт создан: @droneflamesmod   Главный разработчик: @nufxa", 10, UiKit.MUTED, 1, 1)
	clbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits_row.add_child(clbl)
	var c_duck: TextureRect = TextureRect.new()
	c_duck.texture = UiKit.tex("duck_dev")
	c_duck.custom_minimum_size = Vector2(18, 16)
	c_duck.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c_duck.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c_duck.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	c_duck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits_row.add_child(c_duck)
	ui_nodes = [stage, bar_frame, tip, drone, credits_row]
	for n: CanvasItem in ui_nodes:
		n.modulate.a = 0.0
	visible = false


func show_screen(text: String) -> void :
	active = true
	visible = true
	root.modulate.a = 1.0
	_t = 0.0
	_target = 0.02
	_shown = 0.0
	_drone_x = -60.0
	embers.clear()
	for c: Array in clouds:
		(c[0] as CanvasItem).modulate.a = 0.0
	for n: CanvasItem in ui_nodes:
		n.modulate.a = 1.0
	_set_stage(text)
	tip.text = Loc.t("Совет: %s") % Loc.t(String(TIPS[randi() % TIPS.size()]))
	_layout()


func set_progress(f: float, text: String = "") -> void :
	_target = clampf(f, 0.0, 1.0)
	if text != "":
		_set_stage(text)
	_shown = maxf(_shown, _target - 0.15)
	_draw_bar()


func finish() -> void :
	set_progress(1.0)
	active = false
	var tw: Tween = root.create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(root, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback( func() -> void : visible = false)



func _set_stage(text: String) -> void :
	_stage_base = text.rstrip(".…")
	stage.text = _stage_base + "..."


func _draw_bar() -> void :
	var inner: Vector2 = bar_frame.size - Vector2(6, 6)
	bar_fill.position = Vector2(3, 3)
	bar_fill.size = Vector2(floorf(maxf(0.0, inner.x) * _shown), maxf(2.0, inner.y))



func _cover() -> Array:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var s: float = maxf(vs.x / SPLASH_SIZE.x, vs.y / SPLASH_SIZE.y)
	return [vs, s, (vs - SPLASH_SIZE * s) * 0.5]


func _layout() -> void :
	var cv: Array = _cover()
	var vs: Vector2 = cv[0]
	var s: float = cv[1]
	var o: Vector2 = cv[2]
	bg.position = Vector2.ZERO
	bg.size = vs
	if vs.x > vs.y:
		var lsz: Vector2 = logo.texture.get_size() if logo.texture != null else Vector2(230, 60)
		var lk: float = floorf(minf(2.5, (vs.x - 40.0) / lsz.x) * 2.0) / 2.0
		if lk < 1.0:
			lk = 1.0
		logo.scale = Vector2(lk, lk)
		logo.position = Vector2((vs.x - lsz.x * lk) * 0.5, maxf(20.0, vs.y * 0.14))
		var bw: float = minf(320.0, vs.x - 60.0)
		var by: float = roundf(vs.y * 0.72)
		bar_frame.size = Vector2(bw, 18)
		bar_frame.position = Vector2(roundf((vs.x - bw) * 0.5), by)
		stage.position = Vector2(bar_frame.position.x, by - 24.0)
		stage.size = Vector2(bw, 20)
		tip.position = Vector2(28.0, by + 30.0)
		tip.size = Vector2(vs.x - 56.0, 40)
		var gs: = Vector2(vs.x * 1.1, 200.0 * lk / 1.6)
		glow.size = gs
		glow.position = Vector2(vs.x * 0.5, logo.position.y + lsz.y * lk * 0.5) - gs * 0.5
	else:
		logo.scale = Vector2(SPLASH_K * s, SPLASH_K * s)
		logo.position = o + SPLASH_LOGO * s
		var lb: float = o.y + (SPLASH_LOGO.y + 60.0 * SPLASH_K) * s
		var bw: float = minf(270.0, vs.x - 60.0)
		var by: float = roundf(lb + 104.0)
		bar_frame.size = Vector2(bw, 18)
		bar_frame.position = Vector2(roundf((vs.x - bw) * 0.5), by)
		stage.position = Vector2(bar_frame.position.x, by - 24.0)
		stage.size = Vector2(bw, 20)
		tip.position = Vector2(28.0, by + 34.0)
		tip.size = Vector2(vs.x - 56.0, 40)
		var gs: = Vector2(vs.x * 1.1, 200.0 * SPLASH_K * s / 1.6)
		glow.size = gs
		glow.position = Vector2(vs.x * 0.5, o.y + (SPLASH_LOGO.y + 30.0 * SPLASH_K) * s) - gs * 0.5
	if credits_row != null:
		var c_sz: Vector2 = credits_row.get_combined_minimum_size()
		credits_row.position = Vector2(roundf((vs.x - c_sz.x) * 0.5), vs.y - 28.0)


func _process(delta: float) -> void :
	if not visible:
		return
	_t += delta
	_layout()
	_shown = move_toward(_shown, _target, delta * 0.8)
	_draw_bar()
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var intro: float = clampf(_t / 0.3, 0.0, 1.0)
	intro = intro * intro * (3.0 - 2.0 * intro)
	for n: CanvasItem in ui_nodes:
		n.modulate.a = maxf(n.modulate.a, intro)
	stage.text = _stage_base + ".".repeat(1 + int(_t * 2.5) % 3) if _stage_base != "" else ""
	for c: Array in clouds:
		var tr: TextureRect = c[0]
		tr.modulate.a = float(c[2]) * intro
		tr.position.x += float(c[1]) * delta
		if tr.position.x > vs.x + 20.0:
			tr.position.x = - tr.texture.get_size().x * tr.scale.x - 20.0
	if logo.texture != null:
		logo.position.y += roundf(sin(_t * 2.2) * 2.0 * intro)
		_flame_mat.set_shader_parameter("t", _t)
		_flame_mat.set_shader_parameter("amt", intro)
		glow.modulate.a = intro * (0.55 + 0.25 * sin(_t * 3.1) + 0.08 * sin(_t * 11.0))
	_tick_embers(delta, vs, intro)
	if drone.texture != null:
		var t2: Texture2D = UiKit.tex("load_drone_%d" % (int(_t * 16.0) % 4))
		if t2 != null:
			drone.texture = t2
		var head: float = bar_frame.position.x + 3.0 + bar_fill.size.x - 32.0
		_drone_x = lerpf(_drone_x, head, minf(1.0, delta * 3.0))
		drone.position = Vector2(_drone_x, bar_frame.position.y - 68.0 + sin(_t * 4.0) * 3.0).round()


func _tick_embers(delta: float, vs: Vector2, intro: float) -> void :
	if intro > 0.0 and embers.size() < 26 and randf() < delta * 22.0:
		var lx: float = logo.position.x + 35.0 * logo.scale.x
		var lw: float = 161.0 * logo.scale.x
		var p: = Vector2(lx + randf() * lw, logo.position.y + randf_range(20.0, 60.0) * logo.scale.y)
		if randf() < 0.35:
			p = Vector2(randf() * vs.x, vs.y + 4.0)
		embers.append([p, Vector2(randf_range(-6.0, 6.0), randf_range(-38.0, -18.0)), randf_range(1.2, 2.6), randi() % 4])
	var i: int = embers.size() - 1
	while i >= 0:
		var e: Array = embers[i]
		e[2] = float(e[2]) - delta
		if float(e[2]) <= 0.0:
			embers.remove_at(i)
		else:
			var v: Vector2 = e[1]
			v.x += sin(_t * 3.0 + float(i)) * 8.0 * delta
			e[1] = v
			e[0] = (e[0] as Vector2) + v * delta
		i -= 1
	embers_node.queue_redraw()


func _draw_embers() -> void :
	for e: Array in embers:
		var life: float = e[2]
		var ci: int = mini(3, int(e[3]) + (1 if life < 0.8 else 0))
		var col: Color = EMBER_COLS[ci]
		col.a = clampf(life / 0.8, 0.0, 1.0) * (0.6 + 0.4 * float(int(_t * 12.0 + float(e[3])) % 2))
		var p: Vector2 = (e[0] as Vector2).round()
		var sz: float = 3.0 if life > 1.8 else 2.0
		embers_node.draw_rect(Rect2(p, Vector2(sz, sz)), col)
