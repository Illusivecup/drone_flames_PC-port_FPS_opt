extends RefCounted










const FRONT_R: int = 70
const RECENT_T: float = 300.0
const VOL: Array = [3, 2, 1]
const AMB: Array = [2, 1, 0]
const KINDS: Array = ["vol_pickup", "vol_van", "amb_mil"]



const SPR: Dictionary = {
	"vol_pickup": [
		".ooooooo.", 
		"oBbBoRRgo", 
		"oKKKKKKKo", 
		"okkkkkkko", 
		"orrooorro", 
	], 
	"vol_van": [
		".ooooooo.", 
		"oRRRRRRgo", 
		"oKgKgKKKo", 
		"okkkkkkko", 
		"orrooorro", 
	], 
	"amb_mil": [
		".oooooooo.", 
		"oRRRRRRRgo", 
		"oKKKKKKKgo", 
		"oWWWWWWWKo", 
		"okkkkkkkko", 
		".rro..orr.", 
	], 
}
const BEACON: = Vector2i(5, 0)

static var _tex: Dictionary = {}
static var _front_c: Dictionary = {}


static func _build() -> void :
	var cols: Dictionary = {"o": Palette.c("outline"), "K": Palette.c("ui_steel_light"), "k": Palette.c("ui_steel_mid"), "g": Palette.c("water_coast"), 
		"B": Palette.c("wood_light"), "b": Palette.c("wood"), "r": Palette.c("ui_rubber"), "W": Palette.c("snow"), "G": Palette.c("grass_dark"), "R": Palette.c("sand_dark")}
	for kind: String in SPR:
		var rows: Array = SPR[kind]
		var w: int = String(rows[0]).length()
		var h: int = rows.size()
		var img: = Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in h:
			for x in w:
				var ch: String = String(rows[y])[x]
				if cols.has(ch):
					img.set_pixel(x, y, cols[ch])
		_tex[kind + "_e"] = ImageTexture.create_from_image(img)
		var imn: Image = img.duplicate()
		imn.rotate_90(COUNTERCLOCKWISE)
		_tex[kind + "_n"] = ImageTexture.create_from_image(imn)
		var ims: Image = img.duplicate()
		ims.rotate_90(CLOCKWISE)
		_tex[kind + "_s"] = ImageTexture.create_from_image(ims)


static func tex(kind: String, d: String) -> ImageTexture:
	if _tex.is_empty():
		_build()
	return _tex.get(kind + d, null)



static func beacon(d: String) -> Vector2:
	var rows: Array = SPR["amb_mil"]
	var w: int = String(rows[0]).length()
	var h: int = rows.size()
	match d:
		"_n":
			return Vector2(BEACON.y, w - 1 - BEACON.x)
		"_s":
			return Vector2(h - 1 - BEACON.y, BEACON.x)
	return Vector2(BEACON)



static func front_line(gw: GameWorld, c: City) -> bool:
	var fnum: int = Engine.get_process_frames() / 30
	var ce: Variant = _front_c.get(c.id)
	if ce != null and int(ce[0]) == fnum:
		return bool(ce[1])
	var res: bool = false
	var own: Country = gw.country_by_id(c.country_id)
	var am: Variant = gw.aftermath
	if own != null and not own.at_war.is_empty() and am != null and not am.city_hot(c):
		var r2: int = FRONT_R * FRONT_R
		for oc: City in gw.cities:
			if oc != c and oc.center.distance_squared_to(c.center) <= r2 and am.city_hot(oc):
				res = true
				break
		if not res and gw.game_time - c.war_t < RECENT_T:
			res = true
		if not res and gw.army != null:
			var cp: = Vector2(c.center * GameWorld.CELL)
			var rp: float = float(FRONT_R * GameWorld.CELL)
			for u: Unit in gw.army.units:
				if u.alive() and u.ground() and u.pos.distance_squared_to(cp) <= rp * rp and (own.at_war.has(u.country_id)\
				or (u.country_id == c.country_id and (u.state == Unit.State.FIGHT or u.state == Unit.State.SIEGE))):
					res = true
					break
	_front_c[c.id] = [fnum, res]
	return res
