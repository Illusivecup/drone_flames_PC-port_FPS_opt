class_name Opening
extends CanvasLayer








signal reveal
signal finished

const VIDEO: = "res://assets/video/opening.ogv"
const MUSIC: = "res://assets/audio/music/opening.ogg"
const FILM: = Vector2(432, 768)
const LEN: float = 45.0
const WATCHDOG: float = 50.0
const HOLD: float = 1.0
const FADE: float = 0.3
const BAR_COL: = Color(0.035, 0.03, 0.028)
const RING: = Vector2(506.0 / 540.0, 914.0 / 960.0)
const RING_R: float = 13.0 / 540.0
const SKY_FROM: float = 42.4
const DRIFT: float = 0.12

var root: Control
var bars: ColorRect
var bg_vp: TextureRect
var bg_dim: ColorRect
var sky: TextureRect
var vp: VideoStreamPlayer
var music: AudioStreamPlayer
var ring: Control
var _t: float = 0.0
var _hold: float = -1.0
var _done: bool = false
var _paused: bool = false
var _sync_t: float = 0.0




static func should_autoplay(main: Node) -> bool:
	if not GameConfig.opening or not ResourceLoader.exists(VIDEO):
		return false
	if DisplayServer.get_name() == "headless" or OS.has_environment("DF_NO_OPENING"):
		return false
	if not OS.get_cmdline_user_args().is_empty() or OS.get_cmdline_args().has("--verify") or OS.get_cmdline_args().has("--airborne-demo"):
		return false
	var tree: SceneTree = main.get_tree()
	return tree != null and tree.current_scene == main


func _ready() -> void :
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	bars = ColorRect.new()
	bars.color = BAR_COL
	bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bars)
	bg_vp = TextureRect.new()
	bg_vp.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_vp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_vp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_vp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg_vp.self_modulate = Color(0.35, 0.35, 0.38, 1.0)
	bg_vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg_vp)
	bg_dim = ColorRect.new()
	bg_dim.color = Color(0.04, 0.04, 0.06, 0.45)
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg_dim)
	sky = TextureRect.new()
	var g: = Gradient.new()
	g.set_color(0, Loading.SKY_TOP)
	g.set_color(1, Loading.SKY_BOT)
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	sky.texture = gt
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.modulate.a = 0.0
	root.add_child(sky)
	vp = VideoStreamPlayer.new()
	vp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vp.expand = true
	vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.autoplay = false
	vp.volume_db = -80.0
	var st: VideoStream = load(VIDEO) as VideoStream if ResourceLoader.exists(VIDEO) else null
	if st != null:
		vp.stream = st
	root.add_child(vp)
	ring = Control.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(_draw_ring)
	root.add_child(ring)
	music = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://core/sfx.gd"):
		Sfx.load_settings()
		Sfx._apply_bus_volumes()
	if AudioServer.get_bus_index(&"Music") >= 0:
		music.bus = &"Music"
	var ms: AudioStream = load(MUSIC) as AudioStream if ResourceLoader.exists(MUSIC) else null
	if ms != null:
		music.stream = ms
	add_child(music)
	get_viewport().size_changed.connect(_layout)
	_layout()
	if vp.stream == null:
		_finish.call_deferred(true)
		return
	vp.finished.connect( func() -> void : _finish(false))
	vp.play()
	if music.stream != null:
		music.play()


func _layout() -> void :
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var k: float = vs.x / FILM.x
	if FILM.y * k > vs.y:
		k = vs.y / FILM.y
	var sz: Vector2 = FILM * k
	vp.size = sz
	vp.position = ((vs - sz) * 0.5).floor()
	if ring != null:
		ring.queue_redraw()


func _process(delta: float) -> void :
	if _done or _paused:
		return
	if bg_vp != null and bg_vp.texture == null and vp != null and vp.is_playing():
		var vt: Texture2D = vp.get_video_texture()
		if vt != null:
			bg_vp.texture = vt
	_t += delta
	var pos: float = vp.stream_position if vp.is_playing() else _t
	sky.modulate.a = clampf((pos - SKY_FROM) / 1.0, 0.0, 1.0)
	_sync_t += delta
	if music.playing and vp.is_playing() and _sync_t > 0.5:
		_sync_t = 0.0
		var mpos: float = music.get_playback_position() + AudioServer.get_time_since_last_mix()
		if absf(mpos - pos) > DRIFT and pos < LEN - 0.5:
			music.seek(pos)
	if _hold >= 0.0:
		_hold += delta
		ring.queue_redraw()
		if _hold >= HOLD:
			_finish(false)
			return

	if (_t > 1.5 and not vp.is_playing() and vp.stream_position <= 0.0) or _t > WATCHDOG:
		_finish(false)


func _input(ev: InputEvent) -> void :
	if _done:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]:
			_finish(false)
			get_viewport().set_input_as_handled()
			return
	var down: int = -1
	if ev is InputEventScreenTouch:
		down = 1 if (ev as InputEventScreenTouch).pressed else 0
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		down = 1 if (ev as InputEventMouseButton).pressed else 0
	if down == 1 and _hold < 0.0:
		_hold = 0.0
	elif down == 0:
		_hold = -1.0
		ring.queue_redraw()
	if down >= 0:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void :
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_set_paused(true)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_set_paused(false)



func _set_paused(on: bool) -> void :
	if _done or vp == null or on == _paused:
		return
	_paused = on
	_hold = -1.0
	vp.paused = on
	music.stream_paused = on
	if not on and music.playing and vp.is_playing():
		music.seek(vp.stream_position)
	ring.queue_redraw()


func _draw_ring() -> void :
	if _hold < 0.0 or _done:
		return
	var k: float = vp.size.x
	var c: Vector2 = vp.position + Vector2(RING.x * vp.size.x, RING.y * vp.size.y)
	var r: float = RING_R * k
	var d: float = maxf(2.0, roundf(3.0 / 540.0 * k))
	var fill: float = clampf(_hold / HOLD, 0.0, 1.0)
	var n: int = 28
	for i in n:
		var a: float = - PI / 2.0 + float(i) / float(n) * TAU
		var p: Vector2 = (c + Vector2(cos(a), sin(a)) * r - Vector2(d, d) * 0.5).round()
		var on: bool = float(i) / float(n) < fill
		ring.draw_rect(Rect2(p, Vector2(d, d)), Color(1.0, 0.706, 0.196) if on else Color(1, 1, 1, 0.55))
	var s: float = maxf(1.0, roundf(4.0 / 540.0 * k))
	ring.draw_colored_polygon(PackedVector2Array([c + Vector2( - s, - s * 1.25), c + Vector2( - s, s * 1.25), c + Vector2(s * 1.25, 0)]), Color(1.0, 0.706, 0.196))



func _finish(instant: bool) -> void :
	if _done:
		return
	_done = true
	_hold = -1.0
	if ring != null:
		ring.queue_redraw()
	reveal.emit()
	if instant or not is_inside_tree():
		_close()
		return
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 0.0, FADE)
	if music.playing:
		tw.tween_property(music, "volume_db", -40.0, FADE)
	tw.chain().tween_callback(_close)


func _close() -> void :
	if bg_vp != null:
		bg_vp.texture = null
	if vp != null:
		vp.stop()
	if music != null:
		music.stop()
	finished.emit()
	queue_free()
