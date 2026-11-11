class_name NavalLayer
extends Node2D






const S_BOAT: int = 15
const S_SHIP: int = 21

const BOAT: Array[String] = [
	"..OOOOOOOOO.", 
	".OhhhhhhhhhO", 
	"OHsHsHsHsHrO", 
	"OHHsHsHsHHrO", 
	".OdddddddddO", 
	"..OOOOOOOOO.", 
]
const BOAT_VEH: Array[String] = [
	"..OOOOOOOOO.", 
	".OhhhhhhhhhO", 
	"OHHkkkkkgggO", 
	"OHHkKKkkHHrO", 
	".OdddddddddO", 
	"..OOOOOOOOO.", 
]
const SHIP: Array[String] = [
	"...OOOOOOOOOOOO...", 
	"..OHHHHHHHHHHHHOO.", 
	".OHWWWccwccwccHHOO", 
	"OHHWFWccwccwccHHHO", 
	".OHWWWccwccwccHHOO", 
	"..OHHHHHHHHHHHHOO.", 
	"...OOOOOOOOOOOO...", 
]
const _PAL: Dictionary = {"O": "outline", "h": "ui_steel_light", "H": "ui_steel", "d": "ui_steel_dark", "s": "earth_dark", "r": "rock_dark", 
	"k": "rock", "K": "rock_dark", "g": "rock_deep"}
const _PAL_SHIP: Dictionary = {"O": "outline", "H": "brick", "W": "concrete_light", "F": "amber_dark", "c": "wood_light", "w": "wood"}

var gw: GameWorld
var _tex: Dictionary = {}
var _t: float = 0.0
var _cam_key: Vector3 = Vector3.INF
var _had: bool = false


static func make(world: GameWorld) -> NavalLayer:
	var l: = NavalLayer.new()
	l.name = "Naval"
	l.gw = world
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return l


func _ready() -> void :
	_tex["boat"] = _strip(BOAT, _PAL, S_BOAT)
	_tex["veh"] = _strip(BOAT_VEH, _PAL, S_BOAT)
	_tex["ship"] = _strip(SHIP, _PAL_SHIP, S_SHIP)



static func _strip(rows: Array[String], pal: Dictionary, s: int) -> ImageTexture:
	var h: int = rows.size()
	var w: int = rows[0].length()
	var img: = Image.create(s * 16, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cols: Dictionary = {}
	for k: String in pal:
		cols[k] = Palette.c(String(pal[k]))
	var cx: float = float(w) * 0.5
	var cy: float = float(h) * 0.5
	var half: float = float(s) * 0.5
	for f in 16:
		var a: float = deg_to_rad(22.5 * f)
		var ca: float = cos(a)
		var sa: float = sin(a)
		for y in s:
			for x in s:
				var dx: float = float(x) + 0.5 - half
				var dy: float = float(y) + 0.5 - half

				var mx: int = floori(dx * ca + dy * sa + cx)
				var my: int = floori( - dx * sa + dy * ca + cy)
				if mx < 0 or my < 0 or mx >= w or my >= h:
					continue
				var ch: String = rows[my][mx]
				if cols.has(ch):
					img.set_pixel(f * s + x, y, cols[ch])
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void :
	if gw == null or gw.naval == null or gw.camera == null:
		return
	_t += delta
	var nv: Naval = gw.naval
	var busy: bool = not nv.landings.is_empty() or not nv.expeditions.is_empty() or not nv.beached.is_empty()
	var cam: MapCamera = gw.camera
	var key: = Vector3(cam.position.x, cam.position.y, cam.zoom.x)
	if (busy and (_t >= 1.0 / 20.0 or key != _cam_key)) or (_had and not busy):
		_t = 0.0
		_cam_key = key
		queue_redraw()
	_had = busy


func _shows(country_id: int, p: Vector2) -> bool:
	return gw.vision == null or gw.vision.shows(country_id, p)


func _draw() -> void :
	if gw == null or gw.naval == null or gw.camera == null or _tex.is_empty():
		return
	var nv: Naval = gw.naval
	var cam: MapCamera = gw.camera
	var z: float = cam.zoom.x
	var view: = Rect2(cam.screen_to_world(Vector2.ZERO), cam.view_size() / z).grow(40.0 / z)
	var sc: float = clampf(0.6 / z, 1.0, 2.5)
	var me: int = gw.player.id if gw.player != null else -1
	var foam: = Palette.c("water_foam")

	for L: Dictionary in nv.landings:
		if int(L["c"]) == me and int(L["stage"]) != Naval.Stage.LAND:
			_dots(L["sea"], view, Color(foam, 0.45), z)
	for e: Dictionary in nv.expeditions:
		if int(e["c"]) == me:
			_dots(e["path"], view, Color(Palette.c("amber"), 0.5), z, int(e["i"]))

	for bb: Array in nv.beached:
		var p0: Vector2 = bb[0]
		if not view.has_point(p0) or not _shows(int(bb[3]), p0):
			continue
		var left: float = float(bb[2]) - gw.game_time
		var ship: bool = bb.size() > 5 and bool(bb[5])
		_sprite("ship" if ship else ("veh" if bool(bb[4]) else "boat"), p0, float(bb[1]), sc, clampf(left / 4.0, 0.0, 1.0), int(bb[3]))
	for L: Dictionary in nv.landings:
		var st: int = int(L["stage"])
		if st == Naval.Stage.MARCH and L.has("ferry"):
			_ferry(L, view, sc, foam, me)
			continue
		if st != Naval.Stage.BOARD and st != Naval.Stage.SAIL:
			continue
		for b: Dictionary in L["boats"]:
			if bool(b["sunk"]) or bool(b.get("out", false)):
				continue
			var p: Vector2 = (b["pos"] as Vector2).round()
			if not view.has_point(p) or not _shows(int(L["c"]), p):
				continue
			_wake(b, foam)
			var hit: bool = gw.game_time - float(b.get("hit_t", -99.0)) < 0.25
			_sprite("veh" if bool(b["veh"]) else "boat", p, float(b["heading"]), sc, 1.0, int(L["c"]), hit)
	for e2: Dictionary in nv.expeditions:
		var p2: Vector2 = (e2["pos"] as Vector2).round()
		if not view.has_point(p2) or not _shows(int(e2["c"]), p2):
			continue
		_wake(e2, foam)
		_sprite("ship", p2, float(e2["heading"]), sc, 1.0, int(e2["c"]), gw.game_time - float(e2.get("hit_t", -99.0)) < 0.25)
	draw_set_transform(Vector2.ZERO)




func _ferry(L: Dictionary, view: Rect2, sc: float, foam: Color, me: int) -> void :
	var fy: Dictionary = L["ferry"]
	var pk: PackedVector2Array = L["pick"]
	var cid: int = int(L["c"])
	if cid == me:
		_dots(pk, view, Color(foam, 0.45), gw.camera.zoom.x, int(fy["i"]))
	var p0: Vector2 = fy["pos"]
	var hd: float = float(fy["heading"])
	var dirv: Vector2 = Vector2.from_angle(hd)
	var docked: bool = int(fy["i"]) >= pk.size()
	var n: int = int(fy.get("n", 1))
	for k in n:
		var p: Vector2
		if docked:
			p = p0 - dirv * float(k / 3) * 9.0 + dirv.orthogonal() * float(k % 3 - 1) * 8.0
		else:
			p = p0 - dirv * float(k) * 14.0
		p = p.round()
		if not view.has_point(p) or not _shows(cid, p):
			continue
		if k == 0 and not docked:
			_wake(fy, foam)
		elif not docked:

			var side: Vector2 = dirv.orthogonal()
			var st: Vector2 = p - dirv * 5.0
			draw_rect(Rect2(st.round() - Vector2(1, 0), Vector2(2, 1)), Color(foam, 0.8))
			for j in 3:
				var tp: Vector2 = st - dirv * float(j * 2 + 2)
				var sp: Vector2 = side * (1.0 + float(j) * 0.7)
				var col: = Color(foam, 0.6 * (1.0 - float(j) / 3.0))
				draw_rect(Rect2((tp + sp).round(), Vector2(1, 1)), col)
				draw_rect(Rect2((tp - sp).round(), Vector2(1, 1)), col)
			draw_rect(Rect2((p + dirv * 6.0).round(), Vector2(1, 1)), Color(foam, 0.7))
		else:
			draw_rect(Rect2((p - dirv * 5.0).round(), Vector2(1, 1)), Color(foam, 0.5))
		_sprite("boat", p, hd, sc, 1.0, cid)


func _sprite(kind: String, p: Vector2, heading: float, sc: float, alpha: float, country_id: int, flash: bool = false) -> void :
	var tex: ImageTexture = _tex[kind]
	var s: int = S_SHIP if kind == "ship" else S_BOAT
	var fr: int = posmod(roundi(rad_to_deg(heading) / 22.5), 16)
	var src: = Rect2(fr * s, 0, s, s)
	var half: = Vector2(s, s) * 0.5
	draw_set_transform(p, 0.0, Vector2(sc, sc))
	draw_texture_rect_region(tex, Rect2( - half + Vector2(1, 1), Vector2(s, s)), src, Color(0, 0, 0, 0.28 * alpha))
	draw_texture_rect_region(tex, Rect2( - half, Vector2(s, s)), src, Color(1.6, 1.4, 1.2, alpha) if flash else Color(1, 1, 1, alpha))

	var c: Country = gw.country_by_id(country_id)
	if c != null:
		var back: Vector2 = - Vector2.from_angle(float(fr) * PI / 8.0) * (7.0 if kind == "ship" else 5.0)
		draw_rect(Rect2(back.round() - Vector2(0, 1), Vector2(1, 2) if kind == "ship" else Vector2(1, 1)), Color(c.color, alpha))
	draw_set_transform(Vector2.ZERO)


func _wake(b: Dictionary, foam: Color) -> void :
	var tr: PackedVector2Array = b["trail"]
	var nn: int = tr.size()
	if nn == 0:
		return
	var dirv: Vector2 = Vector2.from_angle(float(b["heading"]))
	for i in nn:
		var age: float = float(nn - i)
		var side: Vector2 = dirv.orthogonal() * (1.0 + age * 0.6)
		var col: = Color(foam, 0.7 * (1.0 - age / float(nn + 1)))
		draw_rect(Rect2((tr[i] + side).round(), Vector2(1, 1)), col)
		draw_rect(Rect2((tr[i] - side).round(), Vector2(1, 1)), col)
	var p: Vector2 = (b["pos"] as Vector2) - dirv * 5.0
	draw_rect(Rect2(p.round() - Vector2(1, 0), Vector2(2, 1)), Color(foam, 0.8))


func _dots(path: PackedVector2Array, view: Rect2, col: Color, z: float, from_i: int = 0) -> void :
	var step: float = 10.0 / clampf(z, 0.35, 1.5)
	var carry: float = 0.0
	var d: float = maxf(1.0, 1.0 / z)
	for i in range(maxi(1, from_i), path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var ln: float = a.distance_to(b)
		var s: float = carry
		while s < ln:
			var q: Vector2 = a.lerp(b, s / ln)
			if view.has_point(q):
				draw_rect(Rect2(q.round(), Vector2(d, d)), col)
			s += step
		carry = s - ln
