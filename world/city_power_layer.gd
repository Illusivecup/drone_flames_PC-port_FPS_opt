class_name CityPowerLayer
extends Node2D










var gw: GameWorld
var _had: bool = false


const ICON: PackedStringArray = [
	"..ooooooooo..", 
	".odddbbbdddo.", 
	"oddbbhhbbordo", 
	"oddbhhbborRdo", 
	"odbhbbborRodo", 
	"odbhbborRobdo", 
	"odbbborRobbdo", 
	"oddborRobbddo", 
	"odddrRobbdddo", 
	"oddrRommddddo", 
	"odrRdnnnddddo", 
	".oRddmmmdddo.", 
	"..oooodoooo..", 
	".....odo.....", 
	"......o......", 
]
const ICON_PAL: Dictionary = {"o": "outline", "d": "asphalt_dark", "b": "smoke", "h": "smoke_light", "m": "rock", "n": "rock_dark", "r": "alert_red", "R": "fire_ember"}
const NEAR_Z: float = 0.6
const FAR_Z: float = 0.3
const ICON_SC: float = 2.0
var _tex: Texture2D
var _n_shown: int = 0


func _ready() -> void :
	_restack.call_deferred()




func _restack() -> void :
	var par: Node = get_parent()
	if par == null or gw == null or gw.labels == null or gw.labels.get_parent() != par:
		z_index = 1
		return
	var li: int = gw.labels.get_index()
	par.move_child(self, li - 1 if get_index() < li else li)


func _icon_tex() -> Texture2D:
	if _tex != null:
		return _tex
	var im: = Image.create(ICON[0].length(), ICON.size(), false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	for y in ICON.size():
		var row: String = ICON[y]
		for x in row.length():
			var ch: String = row[x]
			if ICON_PAL.has(ch):
				im.set_pixel(x, y, Palette.c(String(ICON_PAL[ch])))
	_tex = ImageTexture.create_from_image(im)
	return _tex



func shows(c: City, z: float) -> bool:
	if c.powered or c.country_id <= 0:
		return false
	return z >= NEAR_Z or (z >= FAR_Z and c.kind != City.Kind.VILLAGE)


func _process(_delta: float) -> void :
	if gw == null:
		return
	var any: bool = false
	for c: City in gw.cities:
		if not c.powered:
			any = true
			break
	if any or _had:
		queue_redraw()
	_had = any


func _draw() -> void :
	_n_shown = 0
	if gw == null or gw.camera == null:
		return
	var z: float = maxf(0.05, gw.camera.zoom.x)
	var t: float = gw.game_time
	var tex: Texture2D = _icon_tex()
	var sz: Vector2 = tex.get_size()
	var view: = Rect2(gw.camera.position - gw.camera.view_size() * 0.5 / z, gw.camera.view_size() / z).grow(40.0 / z)
	for c: City in gw.cities:
		if not shows(c, z):
			continue
		var cp: = Vector2(c.center * GameWorld.CELL) + Vector2(2, -2)
		if not view.has_point(cp):
			continue
		if t < c.flicker_until and Hash32.h2(c.id, int(Time.get_ticks_msec() * 0.003), 5) % 2 == 0:
			continue
		draw_set_transform(cp, 0.0, Vector2(ICON_SC / z, ICON_SC / z))
		draw_texture(tex, Vector2( - floorf(sz.x * 0.5), - sz.y))
		_n_shown += 1
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


var _cells: Dictionary = {}


func _cells_of(c: City) -> PackedVector2Array:
	if _cells.has(c.id):
		return _cells[c.id]
	var out: = PackedVector2Array()
	var r: int = c.radius + 2
	var d: WorldData = gw.data
	for y in range(c.center.y - r, c.center.y + r + 1):
		for x in range(c.center.x - r, c.center.x + r + 1):
			if d.inside(x, y) and d.has_flag(x, y, WorldData.F_CITY | WorldData.F_OCCUPIED):
				out.append(Vector2(x * GameWorld.CELL, y * GameWorld.CELL - 6))
	_cells[c.id] = out
	return out
