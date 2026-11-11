class_name TopLayer
extends Node2D


var gw: GameWorld
var flags_root: Node2D
var flashes: Array = []
var flash_shader: Shader


func _ready() -> void :
	flags_root = Node2D.new()
	flags_root.name = "Flags"
	add_child(flags_root)
	flash_shader = load("res://world/border_flash.gdshader") as Shader


func clear_all() -> void :
	for c in flags_root.get_children():
		c.queue_free()
	for f: Array in flashes:
		(f[0] as Node).queue_free()
	flashes.clear()


func add_flag(frames: SpriteFrames, pos: Vector2) -> AnimatedSprite2D:
	var s: = AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.centered = false
	s.position = pos.round()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.play(&"wave")
	s.frame = randi() % 3
	flags_root.add_child(s)
	return s


func flash_cells(cells: Array[Vector2i]) -> void :
	if cells.is_empty() or flash_shader == null:
		return
	var mn: = Vector2i(1 << 30, 1 << 30)
	var mx: = Vector2i(-1, -1)
	for c in cells:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	var sz: Vector2i = mx - mn + Vector2i.ONE
	var img: = Image.create(sz.x, sz.y, false, Image.FORMAT_LA8)
	for c in cells:
		img.set_pixel(c.x - mn.x, c.y - mn.y, Color(0, 0, 0, 1))
	var spr: = Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = false
	spr.scale = Vector2(4, 4)
	spr.position = Vector2(mn * 4)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat: = ShaderMaterial.new()
	mat.shader = flash_shader
	spr.material = mat
	add_child(spr)
	flashes.append([spr, Time.get_ticks_msec() / 1000.0])


func _process(_delta: float) -> void :
	if gw == null:
		return
	for k in range(flashes.size() - 1, -1, -1):
		var f: Array = flashes[k]
		var t: float = Time.get_ticks_msec() / 1000.0 - float(f[1])
		var spr: Sprite2D = f[0]
		if t > 1.0:
			spr.queue_free()
			flashes.remove_at(k)
		else:
			(spr.material as ShaderMaterial).set_shader_parameter("time_s", t)
	var any: bool = false
	for b: Bridge in gw.bridges:
		if b.state == Bridge.State.REBUILDING:
			any = true
			break
	if any or _had_bars:
		queue_redraw()
	_had_bars = any


var _had_bars: bool = false


func _draw() -> void :
	if gw == null:
		return
	for b: Bridge in gw.bridges:
		if b.state != Bridge.State.REBUILDING:
			continue
		var mn: = Vector2i(1 << 30, 1 << 30)
		var mx: = Vector2i(-1, -1)
		for c in b.cells:
			mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
			mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
		var len_px: int = clampi((mx.x - mn.x + 1) * 4, 12, 32) if b.dirs[0] == 0 else 16
		var cx: int = (mn.x + mx.x + 1) * 2
		var x0: int = cx - len_px / 2
		var y0: int = mn.y * 4 - 6
		draw_rect(Rect2(x0, y0, len_px, 3), Palette.c("ui_rubber"))
		var inner: int = len_px - 2
		draw_rect(Rect2(x0 + 1, y0 + 1, inner, 1), Palette.c("ui_steel_dark"))
		var fill: int = int(floor(b.progress() * inner))
		if fill > 0:
			draw_rect(Rect2(x0 + 1, y0 + 1, fill, 1), Palette.c("amber"))
			draw_rect(Rect2(x0 + fill, y0 + 1, 1, 1), Palette.c("window_light"))
