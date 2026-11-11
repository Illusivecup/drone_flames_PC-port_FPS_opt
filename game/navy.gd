class_name Navy
extends RefCounted







signal event(ev: Dictionary)

const HULLS: Array = [
	{"key": "light", "name": "Корвет", "hp": 320.0, "speed": 22.0, "turn": 1.4, "sensor": 450.0, "slots": 3, "decoy": 2, 
		"cost": {"money": 1100, "metal": 10}, "time": 50.0}, 
	{"key": "medium", "name": "Фрегат", "hp": 650.0, "speed": 17.0, "turn": 0.9, "sensor": 550.0, "slots": 4, "decoy": 4, 
		"cost": {"money": 2600, "metal": 16, "titanium": 2, "fuel": 10}, "time": 80.0}, 
	{"key": "heavy", "name": "Крейсер", "hp": 1300.0, "speed": 13.0, "turn": 0.6, "sensor": 700.0, "slots": 6, "decoy": 6, 
		"cost": {"money": 5200, "metal": 30, "titanium": 6, "fuel": 16}, "time": 120.0}, 
]

const MODS: Dictionary = {
	"gun": {"name": "Артустановка", "max": [1, 2, 2], "cost": {"money": 250, "metal": 2}, "time": 8.0}, 
	"ciws": {"name": "ЗАК", "max": [1, 2, 2], "cost": {"money": 350, "metal": 2}, "time": 8.0, "ammo": "ciws", "n": 300}, 
	"sam": {"name": "ЗРК", "max": [1, 1, 2], "cost": {"money": 700, "metal": 3, "titanium": 1}, "time": 14.0, "ammo": "sam", "n": 8}, 
	"ash": {"name": "ПКР", "max": [1, 2, 2], "cost": {"money": 500, "metal": 3}, "time": 10.0, "ammo": "asm", "n": 4}, 
	"vls": {"name": "УВП", "max": [0, 0, 2], "cost": {"money": 1200, "metal": 4, "titanium": 2}, "time": 20.0, "ammo": "cm", "n": 8}, 
	"art": {"name": "Артбатарея", "max": [1, 1, 2], "cost": {"money": 600, "metal": 3}, "time": 12.0, "ammo": "art", "n": 24}, 
}
const MOD_ORDER: Array = ["gun", "ciws", "sam", "ash", "vls", "art"]

const PRESETS: Array = [["gun", "ciws", "ash"], ["gun", "ciws", "sam", "ash"], ["gun", "ciws", "sam", "ash", "ash", "vls"]]
const AMMO_KEYS: Array = ["asm", "cm", "sam", "ciws", "decoy", "art"]

const DOCK_R: float = 100.0
const GUN_RANGE: float = 260.0
const GUN_DMG: float = 16.0
const GUN_CD: float = 1.5
const GUN_HIT: float = 0.7
const ASM_RANGE: float = 1500.0
const ASM_SPEED: float = 70.0
const ASM_TURN: float = 2.5
const ASM_DMG: float = 180.0
const ASM_GAP: float = 0.4
const SAM_AT: float = 300.0
const DECOY_AT: float = 140.0
const CIWS_AT: float = 80.0
const SAM_SPEED: float = 180.0
const SAM_BUSY: float = 0.45
const CIWS_BUSY: float = 0.45
const CIWS_HELP_R: float = 60.0
const CM_RANGE: float = 3200.0
const CM_GAP: float = 2.0
const CM_RISE: float = 1.0
const CM_TURN: float = 0.8
const CM_UP: float = 44.0
const CM_OUT: float = 40.0
const CM_LOW_H: float = 1.0
const CM_SMOKE: float = 2.2
const CM_SHIP_GAP: float = 0.7
const CM_LOW_DET: float = 0.7
const CM_LOW_HIT: float = 0.55
const CM_LOW_GUN: float = 0.4
const CM_LOW_SAM: float = 0.6
const SAM_R: float = 380.0
const SAM_P: float = 0.6
const SAM_SHOTS: int = 1
const DECOY_P: float = 0.35
const CIWS_P: float = 0.55
const CM_SAM_P: float = 0.4
const JET_SAM_P: float = 0.5
const SERVICE_QUIET: float = 6.0
const CIWS_BURST: int = 50

const PD_CIWS_R: float = 100.0
const PD_BUSY: float = 1.0
const PD_GUN_R: float = 70.0
const PD_CIWS_P: Array = [0.3, 0.15, 0.3]
const PD_GUN_P: Array = [0.15, 0.0, 0.05]
const PD_BURST: int = 15
const PD_GUN_CD: float = 1.5
const FIRE_CHANCE: Dictionary = {"gun": 0.12, "asm": 0.6, "strike": 0.5}
const FIRE_DPS: float = 4.0
const FIRE_MAX: int = 3
const FIRE_SPREAD: float = 0.04
const STRIKE_DMG: float = 260.0
const SINK_T: float = 7.0
const SLICK_T: float = 120.0
const CONVOY_HP: float = 90.0
const BASE_ARMOR: int = 3
const REARM_PRICE: Dictionary = {"asm": {"money": 150, "metal": 1}, "cm": {"money": 250, "metal": 1}, "sam": {"money": 60}, "decoy": {"money": 40}, "ciws": {}, "art": {"money": 10}}
const REARM_T0: float = 4.0
const REARM_T_EACH: float = 3.0
const REPAIR_HP_S: float = 25.0
const REPAIR_PRICE_HP: float = 2.0
const REPAIR_METAL_HP: float = 150.0
const QUEUE_MAX: int = 6
const SPAWN_CLEAR: float = 10.0
const SLIPWAYS: int = 2
const THINK_DT: float = 0.5
const AI_DT: float = 12.0
const AI_FLEET_DT: float = 4.0
const AI_START: float = 240.0
const BASE_AT: Array = [780.0, 480.0, 240.0]
const DEEP_R: int = 14
const SNAP_R: int = 24
const SNAP_TRIES: int = 140
const SITE_CHECKS: int = 120

var gw: GameWorld
var ships: Array[Ship] = []
var prod: Array = []
var msl: Array = []
var asm_queue: Array = []
var cr_queue: Array = []
var cm_boost: Array = []
var slicks: Array = []
var wrecks: Array = []
const WRECK_T: float = 14.0
var base_armor: Dictionary = {}
var auto_refit: Dictionary = {}
var convoy_lost: Dictionary = {}
var stats: Dictionary = {"built": 0, "sunk": 0, "asm": 0, "asm_hit": 0, "intercepted": 0, "cm": 0, "convoys_sunk": 0, "gun_hits": 0}
var events: Array = []
var ai_next: Dictionary = {}
var ai_fund: Dictionary = {}
var _fund_t: Dictionary = {}
var ai_why: Dictionary = {}
var ai_earn: Dictionary = {}
var names_n: Dictionary = {}



const NAMES_LIGHT: Array[String] = ["Зимородок", "Свиристель", "Варакушка", "Зуёк", "Крачка", "Чибис", "Поморник", 
	"Гагара", "Турпан", "Огарь", "Казарка", "Нырок", "Луток", "Пеночка", "Щур", "Клёст", "Неусыпный", "Вихревой", 
	"Звенящий", "Хлёсткий", "Порывистый", "Юркий", "Ершистый", "Задиристый", "Остроглазый", "Быстрокрылый", "Неугомонный"]
const NAMES_MEDIUM: Array[String] = ["Ирвень", "Сарна", "Тальва", "Велица", "Кремна", "Ольша", "Беляна", "Ровна", 
	"Лесна", "Сивера", "Горна", "Межень", "Отвага", "Верность", "Стойкость", "Решимость", "Удаль", "Твёрдость", 
	"Упорство", "Терпение", "Доблесть", "Честь", "Прямота", "Бодрость"]
const NAMES_HEAVY: Array[String] = ["Державец", "Вечевой", "Заступник", "Кремень", "Порубежье", "Твердыня", "Оплот", 
	"Детинец", "Посадник", "Воевода", "Ратник", "Вольница", "Острог", "Стольный", "Охранитель", "Земледержец"]
const NAME_LAPS: Array[String] = ["II", "III", "IV", "V", "VI"]
var _id: int = 1
var _mid: int = 1
var _rn: int = 1
var _fleet_t: float = 0.0
var _think_acc: float = 0.0
var _pcache: Dictionary = {}
var _berth: Dictionary = {}
var _alive_b: Dictionary = {}
var _reach: Dictionary = {}
var _wants: Dictionary = {}
var _site_off: Dictionary = {}
var _site_fail: Dictionary = {}
var _coast_acc: float = 0.0
var _shore_t: Dictionary = {}
var _boat_t: Dictionary = {}
var _asm_at: Dictionary = {}
var _seed: int = 1
var fl: NavyFleets
var art: NavyArt


var _nav: AStarGrid2D = null
var _flat: AStarGrid2D = null
var _said: Dictionary = {}
var _cdist: PackedByteArray = PackedByteArray()
var nav_ms: float = 0.0
var vis: Array = []
var _cm_kill: Array = []
var _cm_tried: Dictionary = {}
var _cmd_t: float = 0.0


func _init(world: GameWorld) -> void :
	gw = world
	if gw.data != null:
		_seed = int(gw.data.world_seed)
	fl = NavyFleets.new(self)
	art = NavyArt.new(self)




func fleets_of(cid: int) -> Array:
	return fl.fleets_of(cid)


func fleet(id: int) -> Dictionary:
	return fl.fleet(id)


func fleet_create(cid: int, fname: String, color: Color, ship_ids: Array, ci: int = -1) -> int:
	var id: int = fl.fleet_create(cid, fname.strip_edges().left(12), color, ship_ids)
	if ci >= 0:
		fl.fleet(id)["ci"] = clampi(ci, 0, 7)
	return id





func fleet_assign(cid: int, fid: int, ship_ids: Array) -> int:
	var f: Dictionary = fl.fleet(fid)
	if f.is_empty() or int(f["c"]) != cid:
		return 0
	var n: int = 0
	for sid: Variant in ship_ids:
		var s: Ship = ship(int(sid))
		if s != null and s.c == cid and s.alive() and fl.fleet_add(fid, s.id) == "":
			n += 1
	return n



func fleet_unassign(cid: int, ship_ids: Array) -> int:
	var n: int = 0
	for sid: Variant in ship_ids:
		var s: Ship = ship(int(sid))
		if s != null and s.c == cid and s.fleet != 0:
			fl.fleet_remove(s.fleet, s.id)
			n += 1
	return n


func fleet_disband_by(cid: int, fid: int) -> bool:
	var f: Dictionary = fl.fleet(fid)
	if f.is_empty() or int(f["c"]) != cid:
		return false
	fl.fleet_disband(fid)
	return true



func fleet_style(cid: int, fid: int, fname: String, color: Color, ci: int) -> bool:
	var f: Dictionary = fl.fleet(fid)
	var nm: String = fname.strip_edges().left(12)
	if f.is_empty() or int(f["c"]) != cid or nm == "":
		return false
	f["name"] = nm
	f["color"] = color
	f["ci"] = clampi(ci, 0, 7)
	return true


func fleet_add(fid: int, ship_id: int) -> String:
	return fl.fleet_add(fid, ship_id)


func fleet_remove(fid: int, ship_id: int) -> void :
	fl.fleet_remove(fid, ship_id)


func fleet_disband(fid: int) -> void :
	fl.fleet_disband(fid)




func fleet_order(cid: int, fid: int, kind: String, pos: Vector2, r: float = -1.0, wps: Array = []) -> String:
	return fl.fleet_order(cid, fid, kind, pos, r, wps)


func ship_order(s: Ship, kind: String, pos: Vector2, r: float = -1.0, wps: Array = []) -> String:
	return fl.ship_order(s, kind, pos, r, wps)


func set_formation(fid: int, form: String) -> void :
	fl.set_formation(fid, form)




func set_sink_neutral(fid: int, on: bool) -> void :
	fl.set_sink_neutral(fid, on)


func sink_neutral(fid: int) -> bool:
	return bool(fl.fleet(fid).get("sink_n", false))


func _ports() -> Ports:
	return gw.econ.ports if gw.econ != null else null




static func hull_spec(h: int) -> Dictionary:
	return HULLS[clampi(h, 0, HULLS.size() - 1)]



static func fit_why(hull: int, mods: Array) -> String:
	if hull < 0 or hull >= HULLS.size():
		return Loc.t("Нет такого корпуса")
	var hs: Dictionary = HULLS[hull]
	if mods.size() > int(hs["slots"]):
		return Loc.t("%s: только %d слота") % [String(hs["name"]), int(hs["slots"])]
	for m: Variant in mods:
		if not MODS.has(String(m)):
			return Loc.t("Неизвестный модуль")
	for m2: String in MOD_ORDER:
		var mx: int = int(MODS[m2]["max"][hull])
		if mods.count(m2) > mx:
			if mx == 0:
				return Loc.t("%s - только на крейсере") % String(MODS[m2]["name"])
			return Loc.t("%s: не больше %d на корпус «%s»") % [String(MODS[m2]["name"]), mx, String(hs["name"])]
	return ""


static func _add(a: Dictionary, b: Dictionary, k: int = 1) -> void :
	for r: String in b:
		a[r] = int(a.get(r, 0)) + int(b[r]) * k


static func _plus(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = a.duplicate()
	_add(out, b)
	return out


static func cost_of(hull: int, mods: Array) -> Dictionary:
	var out: Dictionary = {}
	_add(out, hull_spec(hull)["cost"])
	for m: Variant in mods:
		if MODS.has(String(m)):
			_add(out, MODS[String(m)]["cost"])
	return out


static func build_time(hull: int, mods: Array) -> float:
	var t: float = float(hull_spec(hull)["time"])
	for m: Variant in mods:
		if MODS.has(String(m)):
			t += float(MODS[String(m)]["time"])
	return t


static func ammo_full(hull: int, mods: Array) -> Dictionary:
	var a: Dictionary = {"asm": 0, "cm": 0, "sam": 0, "ciws": 0, "decoy": int(hull_spec(hull)["decoy"]), "art": 0}
	for m: Variant in mods:
		var sp: Dictionary = MODS.get(String(m), {})
		if sp.has("ammo"):
			a[String(sp["ammo"])] = int(a[String(sp["ammo"])]) + int(sp["n"])
	return a



static func fit_text(hull: int, mods: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for m: Variant in mods:
		parts.append(String(MODS.get(String(m), {"name": "?"})["name"]))
	return "%s: %s" % [String(hull_spec(hull)["name"]), ", ".join(parts)]




const MASK_SOFT: int = 2
const VARIANTS: Array = ["navbase", "navbase_n", "navbase_e", "navbase_w"]
static var cur: int = 0
static var _meta: Array = []





static func _base_meta() -> void :
	if not _meta.is_empty():
		return
	var sp: Dictionary = {}
	var path: String = "res://assets/sprites/atlas_navy1.json"
	if FileAccess.file_exists(path):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary and (d as Dictionary).get("sprites") is Dictionary:
			sp = (d as Dictionary)["sprites"]
	for v in VARIANTS.size():
		var nb: Dictionary = sp.get(String(VARIANTS[v]), {})
		if nb.is_empty() and v > 0:
			_meta.append({})
			continue
		var sz: = Vector2i(int(nb.get("fw", 24)), int(nb.get("fd", 12)))
		if sz.x <= 0 or sz.y <= 0:
			sz = Vector2i(24, 12)
		var rows: Array = []
		var mk: Variant = nb.get("mask", nb.get("footprint_mask", []))
		if mk is Array and (mk as Array).size() == sz.y:
			for row: Variant in mk:
				var r: Array = []
				for i in sz.x:
					var c: int = 0
					if row is String and i < (row as String).length():
						var ch: String = (row as String)[i]
						c = 1 if "Ll#1".contains(ch) else (2 if "Ww~2".contains(ch) else 0)
					elif row is Array and i < (row as Array).size():
						c = clampi(int((row as Array)[i]), 0, 2)
					r.append(c)
				rows.append(r)
		_meta.append({"sprite": String(VARIANTS[v]), "size": sz, "mask": _soften(rows, MASK_SOFT), "berths": nb.get("berths", [])})



static func _soften(rows: Array, r: int) -> Array:
	var h: int = rows.size()
	var out: Array = []
	for y in h:
		var row: Array = rows[y]
		var o: Array = row.duplicate()
		for x in row.size():
			var v: int = int(row[x])
			if v == 0:
				continue
			for yy in range(maxi(0, y - r), mini(h, y + r + 1)):
				var r2: Array = rows[yy]
				for xx in range(maxi(0, x - r), mini(r2.size(), x + r + 1)):
					var u: int = int(r2[xx])
					if u != 0 and u != v:
						o[x] = 0
		out.append(o)
	return out


static func variant_ok(v: int) -> bool:
	_base_meta()
	return v >= 0 and v < _meta.size() and not (_meta[v] as Dictionary).is_empty()


static func variant_sprite(v: int) -> String:
	return String(VARIANTS[clampi(v, 0, VARIANTS.size() - 1)])


static func base_size(v: int = -1) -> Vector2i:
	_base_meta()
	var k: int = cur if v < 0 else v
	return (_meta[k] as Dictionary)["size"] if variant_ok(k) else (_meta[0] as Dictionary)["size"]





static func mask_rows() -> Array:
	_base_meta()
	return (_meta[cur] as Dictionary).get("mask", []) if variant_ok(cur) else []


static func mask_at(x: int, y: int) -> int:
	_base_meta()
	var rows: Array = (_meta[cur] as Dictionary).get("mask", []) if variant_ok(cur) else []
	if rows.is_empty() or y < 0 or y >= rows.size():
		return 0
	var r: Array = rows[y]
	return int(r[x]) if x >= 0 and x < r.size() else 0





static func wet_why(wet: int, wet_land: int, sz: Vector2i) -> String:
	_base_meta()
	var rows: Array = (_meta[cur] as Dictionary).get("mask", []) if variant_ok(cur) else []
	var need: int = 0
	var land: int = 0
	for r: Array in rows:
		need += r.count(2)
		land += r.count(1)
	if need > 0:
		if float(wet_land) > float(land) * 0.15:
			return Loc.t("Суша базы попадает на глубокую воду: сдвиньте к берегу")
		return "" if float(wet) >= float(need) * 0.3 else Loc.t("Причалы базы должны стоять на воде: сдвиньте к морю")
	return "" if float(wet + wet_land) <= float(sz.x * sz.y) * 0.45 else Loc.t("Слишком много воды: база ставится на берег")




func fit_variant(center: Vector2i, c: Country, pay: bool = true) -> int:
	_base_meta()
	var kind: int = Facility.Kind.NAVAL_BASE
	for v in VARIANTS.size():
		if not variant_ok(v):
			continue
		cur = v
		if gw.mil.check_place(kind, Military.nw_for(kind, center), c, null, pay) == "":
			return v
	cur = 0
	return -1




func snap_site(center: Vector2i, c: Country, pay: bool = true) -> Vector2i:
	var d: WorldData = gw.data
	var bs: Vector2i = base_size(0)
	var hx: int = maxi(4, bs.x / 2)
	var hy: int = maxi(3, bs.y / 2)
	var cand: Array = []
	for dy in range( - SNAP_R, SNAP_R + 1, 2):
		for dx in range( - SNAP_R, SNAP_R + 1, 2):
			if dx * dx + dy * dy > SNAP_R * SNAP_R:
				continue
			cand.append([dx * dx + dy * dy, center + Vector2i(dx, dy)])
	cand.sort_custom( func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var tries: int = 0
	for e: Array in cand:
		var p: Vector2i = e[1]
		var wet: bool = false
		var own: bool = false
		for q: Vector2i in [Vector2i(0, 0), Vector2i(hx, 0), Vector2i( - hx, 0), Vector2i(0, hy), Vector2i(0, - hy)]:
			var x: int = p.x + q.x
			var y: int = p.y + q.y
			if not d.inside(x, y):
				continue
			if Biome.is_water(d.get_biome(x, y)):
				wet = true
			elif d.get_owner_id(x, y) == c.id:
				own = true
		if not wet or not own:
			continue
		tries += 1
		if tries > SNAP_TRIES:
			break
		if fit_variant(p, c, pay) >= 0:
			cur = 0
			return p
	cur = 0
	return Vector2i(-1, -1)





func resolve_site(center: Vector2i, c: Country) -> Vector2i:
	if fit_variant(center, c, false) >= 0:
		return center
	var sn: Vector2i = snap_site(center, c, false)
	if sn.x >= 0 and fit_variant(sn, c, false) >= 0:
		return sn
	cur = 0
	return center


static func is_base(f: Facility) -> bool:
	return f != null and f.kind == Facility.Kind.NAVAL_BASE


func bases_of(cid: int, alive_only: bool = true) -> Array[Facility]:
	var out: Array[Facility] = []
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.NAVAL_BASE and f.country_id == cid and ( not alive_only or gw.mil.alive(f)):
			out.append(f)
	return out


func berth_q(f: Facility) -> Vector2i:
	if not _berth.has(f):
		var pr: Ports = _ports()
		var q: = Vector2i(-1, -1)
		var bp: Array = art_berths(f)
		if pr != null and not bp.is_empty():
			pr.ensure_sea()
			var qa: Vector2i = _q(bp[0])
			if pr._body_at(qa) > 0:
				q = qa
		if q.x < 0 and pr != null:
			q = pr.berth_for(f.cell, f.size)
		_berth[f] = q
	return _berth[f]



func art_berths(f: Facility) -> Array:
	_base_meta()
	var out: Array = []
	if f == null or f.main_obj < 0 or not variant_ok(f.variant):
		return out
	if gw.obj_spr[f.main_obj] != int(gw.spr_index.get(variant_sprite(f.variant), -2)):
		return out
	for b: Variant in (_meta[f.variant] as Dictionary).get("berths", []):
		if b is Array and (b as Array).size() >= 2:
			out.append(gw.obj_origin(f.main_obj) + Vector2(float(b[0]), float(b[1])))
	return out


func berth_px(f: Facility) -> Vector2:
	var q: Vector2i = berth_q(f)
	return _ports().cell_px(q) if q.x >= 0 else f.center_px()


func base_body(f: Facility) -> int:
	var q: Vector2i = berth_q(f)
	return _ports()._body_at(q) if q.x >= 0 else 0



func near_base(s: Ship) -> Facility:
	for f: Facility in bases_of(s.c):
		if berth_px(f).distance_to(s.pos) <= DOCK_R:
			return f
	return null


func on_base_built(f: Facility) -> void :
	base_armor[f.id] = armor_max(f)
	_berth.erase(f)
	cur = 0



func armor_max(f: Facility) -> int:
	var n: int = 0
	for id in f.obj_ids:
		if id >= 0 and gw.obj_kind[id] == GameWorld.KIND_BUILDING:
			n += 1
	return maxi(0, BASE_ARMOR + 1 - n)



func site_why(nw: Vector2i, sz: Vector2i) -> String:
	var pr: Ports = _ports()
	if pr == null or not pr.coastal(nw, sz):
		return Loc.t("Морская база - только на берегу моря")
	var d: WorldData = gw.data
	var deep: int = 0
	for y in range(nw.y - DEEP_R, nw.y + sz.y + DEEP_R, 2):
		for x in range(nw.x - DEEP_R, nw.x + sz.x + DEEP_R, 2):
			if d.inside(x, y):
				var b: int = d.get_biome(x, y)
				if b == Biome.DEEP or b == Biome.OCEAN:
					deep += 1
	if deep < 3:
		return Loc.t("Нужна глубокая вода у берега (не мелководье)")
	return ""



func find_base_site(c: Country) -> Vector2i:
	if gw.game_time - float(_site_fail.get(c.id, -1000.0)) < 90.0:
		return Vector2i(-1, -1)
	var pr: Ports = _ports()
	if pr == null:
		return Vector2i(-1, -1)
	pr.ensure_sea()
	var d: WorldData = gw.data
	var now: float = gw.game_time



	if _site_pend.has(c.id) and float(_site_pend[c.id][2]) == now:
		return Vector2i(-1, -1)
	var hit: Array = _site_hit.get(c.id, [])
	if not hit.is_empty() and now - float(hit[0]) < 60.0:
		if fit_variant(hit[1], c, false) >= 0:
			cur = 0
			return hit[1]
		_site_hit.erase(c.id)
	var pend: Array = _site_pend.get(c.id, [])
	var checks: int = int(pend[0]) if not pend.is_empty() else 0
	var off0: int = int(pend[1]) if not pend.is_empty() else int(_site_off.get(c.id, 0))
	var step: int = 0
	var bs: Vector2i = base_size(0)
	var hx: int = maxi(4, roundi(float(bs.x) * 0.5))
	var hy: int = maxi(3, roundi(float(bs.y) * 0.5))
	var skip: int = int(_site_off.get(c.id, 0))
	var k: int = 0
	var bio: PackedByteArray = d.biome
	var ow: PackedByteArray = d.owners
	var w: int = d.w
	var h: int = d.h
	var me: int = c.id
	for cid in c.city_ids:
		var city: City = gw.cities[cid]
		var r: int = city.claim_max + 6
		for y in range(city.center.y - r, city.center.y + r, 3):
			if y < 0 or y >= h:
				continue
			for x in range(city.center.x - r, city.center.x + r, 3):
				if x < 0 or x >= w:
					continue

				var wet: bool = false
				var dry: bool = false
				for j in 5:
					var qx: int = x + (hx if j == 1 else ( - hx if j == 2 else 0))
					var qy: int = y + (hy if j == 3 else ( - hy if j == 4 else 0))
					if qx < 0 or qy < 0 or qx >= w or qy >= h:
						continue
					var qi: int = qy * w + qx
					if bio[qi] <= Biome.RIVER:
						wet = true
					elif ow[qi] == me:
						dry = true
				if not wet or not dry:
					continue
				k += 1
				if k <= skip:
					continue
				checks += 1
				if checks > SITE_CHECKS:
					_site_off[c.id] = k - 1
					_site_pend.erase(c.id)
					_site_fail[c.id] = now - 75.0
					return Vector2i(-1, -1)
				if step >= SITE_STEP:
					_site_off[c.id] = k - 1
					_site_pend[c.id] = [checks - 1, off0, now]
					return Vector2i(-1, -1)
				step += 1
				var cen: = Vector2i(x, y)
				if fit_variant(cen, c, false) >= 0:
					cur = 0
					_site_pend.erase(c.id)
					if off0 > 0:
						_site_off[c.id] = off0
					else:
						_site_off.erase(c.id)
					_site_hit[c.id] = [now, cen]
					return cen
	_site_off.erase(c.id)
	_site_pend.erase(c.id)
	_site_fail[c.id] = now
	return Vector2i(-1, -1)


const SITE_STEP: int = 1
var _site_pend: Dictionary = {}
var _site_hit: Dictionary = {}



func site_pending(c: Country) -> bool:
	return _site_pend.has(c.id)



func base_info(f: Facility) -> Dictionary:
	var q: Array = []
	for o: Dictionary in prod:
		if o["base"] == f:
			q.append({"hull": int(o["hull"]), "name": String(hull_spec(int(o["hull"]))["name"]), "fit": fit_text(int(o["hull"]), o["mods"]), 
				"n": int(o["n"]), "done": int(o["done"]), "t_left": float(o["t"]), "t_total": build_time(int(o["hull"]), o["mods"])})
	var docked: Array = []
	var home: int = 0
	for s: Ship in ships:
		if not s.alive() or s.c != f.country_id:
			continue
		if s.base == f:
			home += 1
		if berth_px(f).distance_to(s.pos) <= DOCK_R:
			docked.append(ship_info(s))
	var ok: bool = gw.mil.alive(f)
	return {"alive": ok, "queue": q, "docked": docked, "home_ships": home, "armor": int(base_armor.get(f.id, 0)), 
		"supply": Loc.t("Снабжение: есть (ремонт и боезапас в 100 м)") if ok else Loc.t("Снабжение: нет - база разрушена"), 
		"auto_refit": bool(auto_refit.get(f.country_id, true)), "berth": berth_px(f)}


func ship_info(s: Ship) -> Dictionary:
	var full: Dictionary = ammo_full(s.hull, s.mods)
	return {"id": s.id, "name": s.name, "hull": s.hull, "hp": roundi(s.hp), "hp_max": roundi(s.hp_max), "fires": s.fires.size(), 
		"ammo": s.ammo.duplicate(), "ammo_max": full, "refit": s.refit, "refit_t": s.refit_t, "state": s.state, 
		"supplied": near_base(s) != null, "fit": fit_text(s.hull, s.mods)}




func queue_of(f: Facility) -> Array:
	var out: Array = []
	for o: Dictionary in prod:
		if o["base"] == f:
			out.append(o)
	return out


func _order_why(f: Facility, hull: int, mods: Array, n: int) -> String:
	if not is_base(f):
		return Loc.t("Нужна морская база")
	if not gw.mil.alive(f):
		return Loc.t("База разрушена или строится")
	var c: Country = gw.country_by_id(f.country_id)
	if c == null:
		return "?"
	var why: String = fit_why(hull, mods)
	if why != "":
		return why
	if queue_of(f).size() >= QUEUE_MAX:
		return Loc.t("Очередь верфи полна (%d)") % QUEUE_MAX
	var tot: Dictionary = {}
	_add(tot, cost_of(hull, mods), n)
	if not c.has_res(tot):
		return Loc.t("Не хватает: %s") % c.missing_res(tot)
	return ""



func order(f: Facility, hull: int, mods: Array, n: int = 1) -> String:
	n = clampi(n, 1, 5)
	var why: String = _order_why(f, hull, mods, n)
	if why != "":
		return why
	var c: Country = gw.country_by_id(f.country_id)
	var tot: Dictionary = {}
	_add(tot, cost_of(hull, mods), n)
	c.pay_res(tot)
	if gw.econ != null:
		gw.econ.stat_add(c, "spend", "navy", int(tot.get("money", 0)))
	var ms: Array = _enqueue(f, hull, mods, n)
	if c.is_player:
		gw.say(c, Loc.mk("Верфь: заказ %s ×%d (%d с)", [String(hull_spec(hull)["name"]).to_lower(), n, roundi(build_time(hull, ms))]))
	return ""



func _enqueue(f: Facility, hull: int, mods: Array, n: int) -> Array:
	var ms: Array = []
	for m: Variant in mods:
		ms.append(String(m))
	prod.append({"base": f, "c": f.country_id, "hull": hull, "mods": ms, "n": n, "done": 0, "t": build_time(hull, ms)})
	return ms



static func order_key(o: Dictionary) -> String:
	return "%d:%d:%s" % [int(o.get("hull", 0)), int(o.get("n", 0)), ",".join(PackedStringArray(o.get("mods", [])))]






func cancel(f: Facility, i: int, key: String = "") -> String:
	var q: Array = queue_of(f)
	if key != "" and (i < 0 or i >= q.size() or order_key(q[i]) != key):
		var best: int = -1
		for j in q.size():
			if order_key(q[j]) == key and (best < 0 or absi(j - i) < absi(best - i)):
				best = j
		if best < 0:
			return Loc.t("Заказ уже выполнен: корабль в ФЛОТ › БЕЗ ГРУППЫ")
		i = best
	if i < 0 or i >= q.size():
		return Loc.t("Нет такого заказа")
	var o: Dictionary = q[i]
	var left: int = int(o["n"]) - int(o["done"])
	var c: Country = gw.country_by_id(int(o["c"]))
	if c != null and left > 0:
		var back: Dictionary = {}
		_add(back, cost_of(int(o["hull"]), o["mods"]), left)
		for r: String in back:
			c.set(r, int(c.get(r)) + int(back[r]))
	_prod_remove(o)
	return ""






func _prod_remove(o: Dictionary) -> void :
	for k in prod.size():
		if is_same(prod[k], o):
			prod.remove_at(k)
			return


func _produce(dt: float) -> void :

	for k0 in range(prod.size() - 1, -1, -1):
		var o0: Dictionary = prod[k0]
		var f0: Facility = o0["base"]
		if f0 != null and f0.country_id != int(o0["c"]):
			var old: Country = gw.country_by_id(int(o0["c"]))
			var left: int = int(o0["n"]) - int(o0["done"])
			if old != null and left > 0:
				var back: Dictionary = {}
				_add(back, cost_of(int(o0["hull"]), o0["mods"]), left)
				for r: String in back:
					old.set(r, int(old.get(r)) + int(back[r]))
			prod.remove_at(k0)
	var seen: Array = []
	for k in range(prod.size()):
		if k >= prod.size():
			break
		var o: Dictionary = prod[k]
		var f: Facility = o["base"]
		if f == null or not gw.mil.alive(f) or f.country_id != int(o["c"]):
			continue


		if seen.count(f) >= SLIPWAYS:
			continue
		seen.append(f)
		o["t"] = float(o["t"]) - dt
		if float(o["t"]) > 0.0:
			continue
		spawn_ship(f, int(o["hull"]), o["mods"])
		o["done"] = int(o["done"]) + 1
		o["t"] = build_time(int(o["hull"]), o["mods"])
		if int(o["done"]) >= int(o["n"]):
			_prod_remove(o)



func spawn_ship(f: Facility, hull: int, mods: Array) -> Ship:
	var s: = Ship.new()
	s.id = _id
	_id += 1
	s.c = f.country_id
	s.hull = clampi(hull, 0, 2)
	for m: Variant in mods:
		s.mods.append(String(m))
	var key: String = "%d:%d" % [s.c, s.hull]
	names_n[key] = int(names_n.get(key, 0)) + 1
	s.name = ship_name(s.c, s.hull, int(names_n[key]))
	s.base = f
	var hs: Dictionary = hull_spec(s.hull)
	s.hp_max = float(hs["hp"])
	s.hp = s.hp_max
	s.ammo = ammo_full(s.hull, s.mods)
	s.pos = _spawn_spot(f)
	s.heading = (s.pos - f.center_px()).angle()
	s.think_t = float(s.id % 5) * 0.1
	s.fresh = true
	ships.append(s)
	stats["built"] = int(stats["built"]) + 1
	_ev({"k": "built", "ship": s.id, "c": s.c, "pos": s.pos})
	var c: Country = gw.country_by_id(s.c)
	if c != null and c.is_player:
		gw.say(c, Loc.mk("Спущен на воду: %s «%s» · ФЛОТ › БЕЗ ГРУППЫ", [String(hull_spec(s.hull)["name"]).to_lower(), Loc.name(s.name)]))
	return s





func ship_name(cid: int, hull: int, k: int) -> String:
	var used: Dictionary = {}
	for s0: Ship in ships:
		if s0.c == cid and s0.alive():
			used[s0.name] = true
	var pool: Array[String] = []
	var start: int = 0
	if hull >= 2:
		var c: Country = gw.country_by_id(cid)
		if c != null:
			for id: int in c.city_ids:
				if id >= 0 and id < gw.cities.size():
					var nm0: String = String(gw.cities[id].name)
					if nm0 != "" and nm0.length() <= 11 and not pool.has(nm0):
						if id == c.capital_id:
							pool.push_front(nm0)
						else:
							pool.append(nm0)
		pool.append_array(NAMES_HEAVY)
	else:
		pool.assign(NAMES_LIGHT if hull <= 0 else NAMES_MEDIUM)
		start = posmod(cid * 7 + hull * 5, pool.size())
	var n: int = pool.size()
	for j in n * (NAME_LAPS.size() + 1):
		var i: int = maxi(0, k - 1) + j
		var nm: String = pool[(start + i) % n]
		var lap: int = i / n
		if lap > 0:
			nm = "%s %s" % [nm, NAME_LAPS[mini(lap - 1, NAME_LAPS.size() - 1)]]
		if not used.has(nm):
			return nm
	return "%s-%d" % [String(hull_spec(hull)["name"]), k]






func _spawn_spot(f: Facility) -> Vector2:
	var rc: = Rect2(f.origin_px(), Vector2(f.size * 4))
	if f.main_obj >= 0 and f.main_obj < gw.obj_spr.size():
		var si: int = gw.obj_spr[f.main_obj]
		if si >= 0 and si < gw.spr_rect.size():
			rc = rc.merge(Rect2(gw.obj_origin(f.main_obj), gw.spr_rect[si].size))
	var keep: Rect2 = rc.grow(SPAWN_CLEAR)
	var b: Vector2 = berth_px(f)
	var body: int = base_body(f)
	var r: float = 0.0
	while r <= DOCK_R - 10.0:
		var na: int = 1 if r == 0.0 else 24
		for k in na:
			var p: Vector2 = (b + Vector2.from_angle(TAU * float(k) / float(na)) * r).round()
			if keep.has_point(p):
				continue
			var bp: int = _body_px(p)
			if bp <= 0 or (body > 0 and bp != body):
				continue
			var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
			if not gw.data.inside(c.x, c.y) or not Biome.is_water(gw.data.get_biome(c.x, c.y)) or gw.mil.facility_at(c) != null:
				continue
			var free: bool = true
			for s: Ship in ships:
				if s.alive() and s.pos.distance_to(p) < 16.0:
					free = false
					break
			if free:
				return p
		r += 8.0
	return _dock_spot(f)



func _dock_spot(f: Facility) -> Vector2:
	var b: Vector2 = berth_px(f)
	var body: int = base_body(f)
	for bp: Vector2 in art_berths(f):
		var taken: bool = false
		for s: Ship in ships:
			if s.alive() and s.pos.distance_to(bp) < 12.0:
				taken = true
				break
		if not taken and _body_px(bp) > 0:
			return bp
	for r in [0, 16, 32, 48, 64]:
		for a in range(0, 360, 45):
			var p: Vector2 = b + Vector2.from_angle(deg_to_rad(float(a))) * float(r)
			if body > 0 and _body_px(p) != body:
				continue
			var free: bool = true
			for s: Ship in ships:
				if s.alive() and s.pos.distance_to(p) < 12.0:
					free = false
					break
			if free:
				return p
	return b




func _q(p: Vector2) -> Vector2i:
	var k: float = float(Ports.K * GameWorld.CELL)
	return Vector2i(floori(p.x / k), floori(p.y / k))


func _body_px(p: Vector2) -> int:
	return _ports()._body_at(_q(p))



func _sea_near(p: Vector2, r: int, body: int = 0) -> Vector2i:
	var pr: Ports = _ports()
	var c: Vector2i = _q(p)
	var best: = Vector2i(-1, -1)
	var bd: int = 1 << 30
	for dy in range( - r, r + 1):
		for dx in range( - r, r + 1):
			var dd: int = dx * dx + dy * dy
			if dd >= bd:
				continue
			var b: int = pr._body_at(c + Vector2i(dx, dy))
			if b == 0 or (body > 0 and b != body):
				continue
			bd = dd
			best = c + Vector2i(dx, dy)
	return best



const COAST_N: int = 7
const COAST_W: float = 12.0
const THREAT_W: float = 6.0
const DETOUR_K: float = 1.3
const THREAT_DETOUR_K: float = 2.0
const THREAT_R: Dictionary = {Facility.Kind.AD_SAM: 700.0, Facility.Kind.AD_PATRIOT: 450.0, Facility.Kind.AD_SPAAG: 300.0, Facility.Kind.NAVAL_BASE: 450.0}



func _ensure_nav() -> void :
	if _nav != null:
		return
	var pr: Ports = _ports()
	pr.ensure_sea()
	var t0: int = Time.get_ticks_usec()
	var W: int = pr._w
	var H: int = pr._h
	_nav = AStarGrid2D.new()
	_nav.region = Rect2i(0, 0, W, H)
	_nav.cell_size = pr.sea.cell_size
	_nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_nav.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_nav.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_nav.update()
	_flat = AStarGrid2D.new()
	_flat.region = Rect2i(0, 0, W, H)
	_flat.cell_size = pr.sea.cell_size
	_flat.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_flat.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_flat.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_flat.update()
	_cdist.resize(W * H)
	_cdist.fill(255)
	var q: = PackedInt32Array()
	for i in W * H:
		var c: = Vector2i(i % W, i / W)
		if pr.sea.is_point_solid(c):
			_nav.set_point_solid(c, true)
			_flat.set_point_solid(c, true)
			_cdist[i] = 0
			q.append(i)
	var qi: int = 0
	while qi < q.size():
		var j: int = q[qi]
		qi += 1
		var dj: int = _cdist[j]
		if dj >= COAST_N:
			continue
		var x0: int = j % W
		var y0: int = j / W
		for dd: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var x: int = x0 + dd.x
			var y: int = y0 + dd.y
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			var k: int = y * W + x
			if _cdist[k] > dj + 1:
				_cdist[k] = dj + 1
				q.append(k)
				var f: float = float(COAST_N - (dj + 1)) / float(COAST_N)
				_nav.set_point_weight_scale(Vector2i(x, y), 1.0 + COAST_W * f * f)
	if art != null and art._inl_src.is_empty():
		art._build_inland(pr)
	nav_ms = (Time.get_ticks_usec() - t0) / 1000.0


func coast_dist(q: Vector2i) -> int:
	_ensure_nav()
	var pr: Ports = _ports()
	if q.x < 0 or q.y < 0 or q.x >= pr._w or q.y >= pr._h:
		return 0
	return _cdist[q.y * pr._w + q.x]



func _threats(cid: int) -> Array:
	var out: Array = []
	if cid <= 0:
		return out
	for f: Facility in gw.mil.facilities:
		if THREAT_R.has(f.kind) and _hostile(cid, f.country_id) and gw.mil.alive(f):
			out.append([f.center_px(), float(THREAT_R[f.kind])])
	for e: Ship in ships:
		if e.alive() and _hostile(cid, e.c):
			out.append([e.pos, 450.0])
	return out




func sea_path(a: Vector2i, b: Vector2i, cid: int = 0) -> PackedVector2Array:
	_ensure_nav()
	var thr: Array = _threats(cid)
	var key: = Vector4i(a.x, a.y, b.x, b.y)
	if thr.is_empty() and _pcache.has(key):
		return _pcache[key]
	var raw: PackedVector2Array = _id_path(a, b)


	var lim: float = _plen(_id_path(a, b, _flat))
	if _plen(raw) > lim * DETOUR_K + 64.0:
		raw = _id_path(a, b, _flat)
	if not thr.is_empty() and _crosses(raw, thr, a, b):
		var touched: Array = _weigh_threats(thr, a, b)
		var avoid: PackedVector2Array = _id_path(a, b)
		for e: Array in touched:
			_nav.set_point_weight_scale(e[0], e[1])
		if _plen(avoid) <= lim * THREAT_DETOUR_K + 64.0:
			raw = avoid
	var out: PackedVector2Array = _smooth(raw)
	if thr.is_empty():
		if _pcache.size() > 256:
			_pcache.clear()
		_pcache[key] = out
	return out


func _id_path(a: Vector2i, b: Vector2i, g: AStarGrid2D = null) -> PackedVector2Array:
	var out: = PackedVector2Array()
	if a.x < 0 or b.x < 0:
		return out
	var pr: Ports = _ports()
	for q: Vector2i in (g if g != null else _nav).get_id_path(a, b, false):
		out.append(pr.cell_px(q))
	return out


static func _plen(p: PackedVector2Array) -> float:
	var s: float = 0.0
	for i in range(1, p.size()):
		s += p[i - 1].distance_to(p[i])
	return s



func _crosses(raw: PackedVector2Array, thr: Array, a: Vector2i, b: Vector2i) -> bool:
	var pa: Vector2 = _ports().cell_px(a)
	var pb: Vector2 = _ports().cell_px(b)
	for i in range(0, raw.size(), 3):
		for t: Array in thr:
			var c: Vector2 = t[0]
			var r: float = float(t[1])
			if raw[i].distance_to(c) < r and pa.distance_to(c) > r and pb.distance_to(c) > r:
				return true
	return false



func _weigh_threats(thr: Array, a: Vector2i, b: Vector2i) -> Array:
	var pr: Ports = _ports()
	var k: float = float(Ports.K * GameWorld.CELL)
	var touched: Array = []
	var pa: Vector2 = pr.cell_px(a)
	var pb: Vector2 = pr.cell_px(b)
	for t: Array in thr:
		var c: Vector2 = t[0]
		var r: float = float(t[1])
		if pa.distance_to(c) <= r or pb.distance_to(c) <= r:
			continue
		var cq: Vector2i = _q(c)
		var rc: int = ceili(r / k)
		for dy in range( - rc, rc + 1):
			for dx in range( - rc, rc + 1):
				var q: = cq + Vector2i(dx, dy)
				if q.x < 0 or q.y < 0 or q.x >= pr._w or q.y >= pr._h or dx * dx + dy * dy > rc * rc or _nav.is_point_solid(q):
					continue
				var w0: float = _nav.get_point_weight_scale(q)
				touched.append([q, w0])
				_nav.set_point_weight_scale(q, w0 + THREAT_W)
	touched.reverse()
	return touched


func _smooth(raw: PackedVector2Array) -> PackedVector2Array:
	var n: int = raw.size()
	if n <= 2:
		return raw
	var out: = PackedVector2Array([raw[0]])
	var i: int = 0
	while i < n - 1:
		var j: int = mini(n - 1, i + 24)
		while j > i + 1 and not _los(raw[i], raw[j]):
			j -= 1
		out.append(raw[j])
		i = j
	return out


func _los(a: Vector2, b: Vector2) -> bool:
	var pr: Ports = _ports()
	var ln: float = a.distance_to(b)
	var steps: int = maxi(1, ceili(ln / 6.0))
	var keep: int = mini(mini(coast_dist(_q(a)), coast_dist(_q(b))), COAST_N) - 1
	for k in range(1, steps):
		var p: Vector2 = a.lerp(b, float(k) / float(steps))
		if pr._body_at(_q(p)) == 0 or coast_dist(_q(p)) < keep:
			return false

		var side: Vector2 = (b - a).normalized().orthogonal() * 6.0
		if pr._body_at(_q(p + side)) == 0 or pr._body_at(_q(p - side)) == 0:
			return false
	return true




func move_to(s: Ship, px: Vector2, manual: bool = true, wps: Array = []) -> String:
	if not wps.is_empty():
		return _move_route(s, px, manual, wps)
	if s == null or not s.alive():
		return Loc.t("Корабль тонет")
	var pr: Ports = _ports()
	if pr == null or pr.sea == null:
		return Loc.t("Нет моря")
	var a: Vector2i = _q(s.pos)
	var body: int = pr._body_at(a)
	if body == 0:
		a = _sea_near(s.pos, 3)
		body = pr._body_at(a) if a.x >= 0 else 0
	if body == 0:
		return Loc.t("Корабль на мели")
	var b: Vector2i = _sea_near(px, 12, body)
	if b.x < 0:
		b = _sea_near(px, 40, body)
	if b.x < 0:
		return Loc.t("Туда не доплыть: другое море")
	if manual and pr.cell_px(b).distance_to(px) > float(Ports.K * GameWorld.CELL) * 2.5 and gw.game_time - float(_said.get(s.c, -10.0)) > 2.0:
		_said[s.c] = gw.game_time
		gw.say(s.c, Loc.mk("Флот: в точку не доплыть — корабли идут к ближайшей воде рядом"))
	var path: PackedVector2Array = sea_path(a, b, s.c)
	if path.is_empty():
		return Loc.t("Нет морского пути")
	s.path = PackedVector2Array(path)
	s.path.append(pr.cell_px(b) if px.distance_to(pr.cell_px(b)) > 24.0 else px)
	s.pi = 0
	s.state = Ship.State.SAIL
	s.refit = ""
	s.auto = not manual
	return ""



func _move_route(s: Ship, px: Vector2, manual: bool, wps: Array) -> String:
	var pts: Array = []
	for w: Variant in wps:
		if w is Vector2:
			pts.append(w)
	pts.append(px)
	var why: String = move_to(s, pts[0], manual)
	if why != "":
		return why
	var whole: = PackedVector2Array(s.path)
	var pr: Ports = _ports()
	var body: int = _body_px(s.pos) if _body_px(s.pos) != 0 else pr._body_at(_sea_near(s.pos, 3))
	for i in range(1, pts.size()):
		var a: Vector2i = _sea_near(pts[i - 1], 12, body)
		var b: Vector2i = _sea_near(pts[i], 12, body)
		if a.x < 0 or b.x < 0:
			return Loc.t("Туда не доплыть: другое море")
		var leg: PackedVector2Array = sea_path(a, b, s.c)
		if leg.is_empty():
			return Loc.t("Нет морского пути")
		whole.append_array(leg)
	whole.append(pts[pts.size() - 1])
	s.path = whole
	s.pi = 0
	return ""


func stop(s: Ship) -> void :
	s.path = PackedVector2Array()
	s.pi = 0
	if s.alive():
		s.state = Ship.State.IDLE


func _hp_factor(s: Ship) -> float:
	var r: float = s.hp / maxf(1.0, s.hp_max)
	return 0.5 if r < 0.25 else (0.75 if r < 0.5 else 1.0)


func _move(s: Ship, dt: float) -> void :
	var hs: Dictionary = hull_spec(s.hull)
	var vmax: float = minf(float(hs["speed"]) * _hp_factor(s), s.spd_cap)
	var want_v: float = 0.0
	if s.state == Ship.State.SAIL and s.pi < s.path.size():
		var to: Vector2 = s.path[s.pi] - s.pos
		var last: bool = s.pi == s.path.size() - 1
		if to.length() < (4.0 if last else 10.0):
			s.pi += 1
			if s.pi >= s.path.size():
				s.state = Ship.State.IDLE
				s.path = PackedVector2Array()
				s.pi = 0
		else:
			var diff: float = wrapf(to.angle() - s.heading, - PI, PI)
			var turn: float = float(hs["turn"]) * dt
			s.heading = wrapf(s.heading + clampf(diff, - turn, turn), - PI, PI)
			want_v = vmax * clampf(cos(diff) * 0.85 + 0.15, 0.25, 1.0)
			if last:
				want_v = minf(want_v, maxf(3.0, to.length() * 0.6))
	s.speed = move_toward(s.speed, want_v, vmax * 0.5 * dt)
	if s.speed > 0.01:
		var np: Vector2 = s.pos + Vector2.from_angle(s.heading) * s.speed * dt
		if _body_px(np) != 0:
			s.pos = np
		else:



			var slid: bool = false
			for da: float in [0.4, -0.4, 0.8, -0.8, 1.2, -1.2]:
				var np2: Vector2 = s.pos + Vector2.from_angle(s.heading + da) * maxf(s.speed, 2.0) * dt
				if _body_px(np2) != 0:
					s.pos = np2
					s.heading = wrapf(s.heading + da * 0.5, - PI, PI)
					s.speed = minf(s.speed, vmax * 0.5)
					slid = true
					break
			if not slid:
				s.speed = 0.0
		s.trail_t += dt
		if s.trail_t >= 0.3:
			s.trail_t = 0.0
			s.trail.append(s.pos)
			if s.trail.size() > 12:
				s.trail.remove_at(0)
	elif not s.trail.is_empty():
		s.trail_t += dt
		if s.trail_t >= 0.3:
			s.trail_t = 0.0
			s.trail.remove_at(0)




func update(dt: float) -> void :
	if ships.is_empty() and prod.is_empty() and msl.is_empty() and slicks.is_empty() and wrecks.is_empty() and cr_queue.is_empty() and asm_queue.is_empty() and cm_boost.is_empty():
		_fleet_t += dt
		if _fleet_t >= 2.0:
			_fleet_t = 0.0
			_track_bases()
		return
	_produce(dt)
	var now: float = gw.game_time
	for k in range(asm_queue.size() - 1, -1, -1):
		if now >= float(asm_queue[k][0]):
			var q: Array = asm_queue[k]
			asm_queue.remove_at(k)
			_fire_asm(ship(int(q[1])), int(q[2]), q[3])
	for k in range(cr_queue.size() - 1, -1, -1):
		if now >= float(cr_queue[k][0]):
			var q2: Array = cr_queue[k]
			cr_queue.remove_at(k)
			_release_cm(ship(int(q2[1])), q2[2])
	_cm_boost_tick(now)
	_think_acc += dt
	var think: bool = _think_acc >= THINK_DT * 0.2
	var tdt: float = _think_acc
	if think:
		_think_acc = 0.0
	for k in range(ships.size() - 1, -1, -1):
		if k >= ships.size():
			continue
		var s: Ship = ships[k]
		if s.state == Ship.State.SINK:
			s.sink_t += dt
			s.speed = move_toward(s.speed, 0.0, 4.0 * dt)
			s.pos += Vector2.from_angle(s.heading) * s.speed * dt
			if s.sink_t >= SINK_T:
				slicks.append([s.pos, now + SLICK_T])
				if gw._on_screen(s.pos, 40.0):
					gw.fx.spawn("splash", s.pos.round(), 6)
				ships.remove_at(k)
			continue
		_move(s, dt)
		s.gun_cd -= dt
		if s.refit != "":
			_refit_tick(s, dt)
		s.think_t += tdt if think else 0.0
		if s.think_t >= THINK_DT:
			var tt: float = s.think_t
			s.think_t = 0.0
			_think(s, tt)
		if s.tgt != 0 and s.gun_cd <= 0.0 and s.has_mod("gun"):
			_gun(s)
		elif s.gun_cd <= 0.0 and _boat_t.has(s.id) and s.has_mod("gun"):
			_gun_boat(s)
		elif s.gun_cd <= 0.0 and _shore_t.has(s.id) and s.has_mod("gun"):
			_gun_shore(s)
	_tick_msl(dt)
	_coast_acc += dt
	if _coast_acc >= 0.5:
		_coastal(_coast_acc)
		_coast_acc = 0.0
	art.tick(dt)
	fl.tick(dt)
	_cmd_t += dt
	if _cmd_t >= 0.25:
		_cmd_t = 0.0
		_cm_defence()
		_point_defence()
	for k in range(_cm_kill.size() - 1, -1, -1):
		if now >= float(_cm_kill[k][0]):
			var ck: Array = _cm_kill[k]
			_cm_kill.remove_at(k)
			var dr: Drone = ck[1]
			if dr != null and dr.state == Drone.State.FLY:
				dr.state = Drone.State.DONE
				dr.end_reason = Drone.End.DESTROYED
				stats["cm_intercepted"] = int(stats.get("cm_intercepted", 0)) + 1
				_ev({"k": "cm_intercepted", "ship": int(ck[2]), "pos": dr.pos, "c": dr.country_id})
				if gw._on_screen(dr.pos, 60.0):
					_fx("intercept_flash", "explosion_s", dr.pos)
	for k in range(vis.size() - 1, -1, -1):
		if now > float(vis[k]["t1"]) + 0.3:
			vis.remove_at(k)
	for k in range(slicks.size() - 1, -1, -1):
		if now > float(slicks[k][1]):
			slicks.remove_at(k)
	for k in range(wrecks.size() - 1, -1, -1):
		if now - float(wrecks[k]["t0"]) > WRECK_T:
			wrecks.remove_at(k)
	_fleet_t += dt
	if _fleet_t >= AI_FLEET_DT:
		_fleet_t = 0.0
		_track_bases()
		for c: Country in gw.countries:
			if not c.is_player and not c.eliminated:
				fl.ai(c)
				art.ai(c)


func ship(id: int) -> Ship:
	for s: Ship in ships:
		if s.id == id:
			return s
	return null


func ships_of(cid: int, alive_only: bool = true) -> Array[Ship]:
	var out: Array[Ship] = []
	for s: Ship in ships:
		if s.c == cid and ( not alive_only or s.alive()):
			out.append(s)
	return out




func _hostile(a: int, b: int) -> bool:
	if a == b or a <= 0 or b <= 0:
		return false
	var dp: Diplomacy = gw.diplo
	if dp == null:
		return gw.army != null and gw.army._hostile(a, b)
	if not dp.at_war(a, b) or dp.allied(a, b):
		return false
	if dp.truce_on(a, b) or dp.calm_left(a, b) > 0.0:
		return false
	var ca: Country = gw.country_by_id(a)
	return ca != null and ca.at_war.has(b)




func may_hit(c: int, victim: int, tgt: int, s: Ship = null) -> bool:
	if tgt < 0 and gw.diplo != null and gw.diplo.has_method("react_restrained") and gw.diplo.react_restrained(c, victim, -1, "convoy")\
	and gw.country_by_id(c) != null and not gw.country_by_id(c).is_player:
		return false
	if _hostile(c, victim):
		return true
	return tgt < 0 and gw.supply != null and gw.supply.may_sink_neutral(c, victim, s)



func _think(s: Ship, dt: float) -> void :

	if not s.fires.is_empty():
		for k in range(s.fires.size() - 1, -1, -1):
			var fr: Array = s.fires[k]
			fr[1] = float(fr[1]) - dt
			if float(fr[1]) <= 0.0:
				s.fires.remove_at(k)
		var nf: int = s.fires.size()
		if nf > 0:
			if s.fires.size() < FIRE_MAX and _roll(s.id, _next()) < FIRE_SPREAD * dt * float(nf):
				_ignite(s)
			damage(s, FIRE_DPS * float(nf) * dt, 0, "fire")
			if not s.alive():
				return

	if s.base == null or not gw.mil.alive(s.base) or s.base.country_id != s.c:
		var body: int = _body_px(s.pos)
		for f: Facility in bases_of(s.c):
			if base_body(f) == body:
				s.base = f
				break

	s.tgt = 0
	_boat_t.erase(s.id)
	if s.has_mod("gun"):
		var best: float = GUN_RANGE
		if s.order_tgt > 0:
			var ot: Ship = ship(s.order_tgt)
			if ot == null or not ot.alive():
				s.order_tgt = 0
			elif ot.pos.distance_to(s.pos) <= GUN_RANGE:
				s.tgt = ot.id
		if s.tgt == 0:
			for o: Ship in ships:
				if o.alive() and o.c != s.c and _hostile(s.c, o.c):
					var d: float = o.pos.distance_to(s.pos)
					if d < best:
						best = d
						s.tgt = o.id
		if s.tgt == 0:
			for cs: Dictionary in convoys():
				if may_hit(s.c, int(cs["owner"]), -1, s):
					var d2: float = (cs["pos"] as Vector2).distance_to(s.pos)
					if d2 < best and int(cs["stage"]) != 0:
						best = d2
						s.tgt = - int(cs["id"])
		if s.tgt == 0 and gw.naval != null:
			for L: Dictionary in gw.naval.landings:
				if int(L["stage"]) != Naval.Stage.SAIL or not _hostile(s.c, int(L["c"])):
					continue
				for b: Dictionary in L["boats"]:
					if not bool(b["sunk"]) and not bool(b.get("out", false)) and (b["pos"] as Vector2).distance_to(s.pos) < best:
						best = (b["pos"] as Vector2).distance_to(s.pos)
						_boat_t[s.id] = [L, b]
	_shore_t.erase(s.id)
	if s.tgt == 0 and not _boat_t.has(s.id) and s.has_mod("gun"):
		var su: Object = _shore_target(s)
		if su == null:
			su = _shore_fac(s)
		if su != null:
			_shore_t[s.id] = su

	if s.refit == "" and s.state == Ship.State.IDLE and bool(auto_refit.get(s.c, true)) and gw.game_time - s.hit_t >= SERVICE_QUIET:
		var f: Facility = near_base(s)
		if f != null:
			var c: Country = gw.country_by_id(s.c)
			var keep: int = 0 if c == null or c.is_player else 400
			if s.hp < s.hp_max - 1.0 or not s.fires.is_empty():
				if c != null and c.money >= int(repair_cost(s).get("money", 0)) + keep:
					repair(s)
			elif not _missing(s).is_empty():
				if c != null and c.money >= int(rearm_cost(s).get("money", 0)) + keep:
					rearm(s)


func _target_pos(tgt: int) -> Variant:
	if tgt > 0:
		var t: Ship = ship(tgt)
		return t.pos if t != null and t.alive() else null
	if tgt < 0:
		var cs: Dictionary = convoy( - tgt)
		return cs["pos"] if not cs.is_empty() else null
	return null


func _gun(s: Ship) -> void :
	var tp: Variant = _target_pos(s.tgt)
	if tp == null or (tp as Vector2).distance_to(s.pos) > GUN_RANGE + 10.0:
		s.tgt = 0
		return
	s.gun_cd = GUN_CD
	var n: int = s.count_mod("gun")
	var p: Vector2 = tp
	s.shot_t = gw.game_time
	s.aim = (p - s.pos).angle()
	var victim: int = ship(s.tgt).c if s.tgt > 0 and ship(s.tgt) != null else int(convoy( - s.tgt).get("owner", 0))
	if not may_hit(s.c, victim, s.tgt, s):
		s.tgt = 0
		return
	_ev({"k": "gun", "ship": s.id, "c": s.c, "victim": victim, "n": n, "pos": s.pos, "tp": p})
	var vis: bool = gw._on_screen(s.pos, 60.0) or gw._on_screen(p, 60.0)
	for i in n:
		var hit: bool = _roll(s.id, _next()) < GUN_HIT
		if vis:
			_fx("hit_small" if hit else "splash_big", "splash", p + Vector2(randf_range(-6, 6), randf_range(-4, 4)))
		if not hit:
			continue
		stats["gun_hits"] = int(stats["gun_hits"]) + 1
		if s.tgt > 0:
			damage(ship(s.tgt), GUN_DMG, s.c, "gun")
		else:
			hit_convoy(convoy( - s.tgt), GUN_DMG, s.c)



func _gun_boat(s: Ship) -> void :
	var lb: Array = _boat_t[s.id]
	var b: Dictionary = lb[1]
	if bool(b["sunk"]) or (b["pos"] as Vector2).distance_to(s.pos) > GUN_RANGE + 10.0:
		_boat_t.erase(s.id)
		return
	var lc: int = int((lb[0] as Dictionary)["c"])
	if not _hostile(s.c, lc):
		_boat_t.erase(s.id)
		return
	s.gun_cd = GUN_CD
	s.shot_t = gw.game_time
	s.aim = ((b["pos"] as Vector2) - s.pos).angle()
	_ev({"k": "gun", "ship": s.id, "c": s.c, "victim": lc, "n": s.count_mod("gun"), "pos": s.pos, "tp": b["pos"]})
	for i in s.count_mod("gun"):
		if _roll(s.id, _next()) < GUN_HIT and not bool(b["sunk"]):
			gw.naval._hit(b, GUN_DMG * 3.0, s.c, lb[0], "gun")
	if gw._on_screen(s.pos, 60.0):
		gw.fx.spawn("muzzle_flash", s.pos.round(), 6)





const SHORE_R: float = 220.0
const SHORE_INLAND: float = 100.0
const SHORE_DMG: float = 14.0
const SHORE_HIT: float = 0.45
const SHORE_COVER: Array = [Biome.FOREST, Biome.PINE, Biome.HILLS, Biome.ROCK]


func _shore_target(s: Ship) -> Unit:
	if gw.army == null:
		return null
	var best: Unit = null
	var bd: float = SHORE_R
	for o: Variant in gw.army._near(s.pos, SHORE_R):
		var u: Unit = o as Unit
		if u == null or not u.alive() or not u.ground() or u.entrenched or not _hostile(s.c, u.country_id):
			continue
		var d: float = u.pos.distance_to(s.pos)
		if d >= bd or not _open_shore(u.pos):
			continue
		bd = d
		best = u
	return best


func _open_shore(p: Vector2) -> bool:
	var cell: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	var dd: WorldData = gw.data
	if not dd.inside(cell.x, cell.y) or SHORE_COVER.has(dd.get_biome(cell.x, cell.y)) or dd.has_flag(cell.x, cell.y, WorldData.F_OCCUPIED):
		return false
	for city: City in gw.cities:
		if p.distance_to(Vector2(city.center * GameWorld.CELL)) <= float(city.radius * GameWorld.CELL) + 16.0:
			return false
	return _sea_near(p, ceili(SHORE_INLAND / float(Ports.K * GameWorld.CELL))).x >= 0





const SHORE_FAC_R: float = 300.0
const SHORE_FAC_KINDS: Array = [Facility.Kind.COASTAL_ASM, Facility.Kind.AD_SAM, Facility.Kind.AD_SPAAG, Facility.Kind.AD_PATRIOT, 
	Facility.Kind.AD_RADAR, Facility.Kind.AD_EW, Facility.Kind.AD_INT, Facility.Kind.TEL, Facility.Kind.BARRACKS, Facility.Kind.DRONE_PORT, Facility.Kind.DUGOUT]


func _shore_fac(s: Ship) -> Facility:
	if gw.army == null or gw.mil == null:
		return null
	var best: Facility = null
	var bd: float = INF
	for f: Facility in gw.mil.facilities:
		if f.parent != null or f.moving or not SHORE_FAC_KINDS.has(f.kind) or not _hostile(s.c, f.country_id):
			continue
		var d: float = f.center_px().distance_to(s.pos) - float(maxi(f.size.x, f.size.y)) * GameWorld.CELL * 0.5
		if d > SHORE_FAC_R or not gw.mil.alive(f):
			continue
		if f.kind == Facility.Kind.COASTAL_ASM:
			d -= SHORE_FAC_R
		if d < bd:
			bd = d
			best = f
	return best


func _gun_fac(s: Ship, f: Facility) -> void :
	if not gw.mil.alive(f) or not _hostile(s.c, f.country_id) or f.center_px().distance_to(s.pos) - float(maxi(f.size.x, f.size.y)) * GameWorld.CELL * 0.5 > SHORE_FAC_R + 10.0:
		_shore_t.erase(s.id)
		return
	s.gun_cd = GUN_CD
	s.shot_t = gw.game_time
	var tp: Vector2 = f.center_px()
	s.aim = (tp - s.pos).angle()
	var n: int = s.count_mod("gun")
	_ev({"k": "gun", "ship": s.id, "c": s.c, "victim": f.country_id, "n": n, "pos": s.pos, "tp": tp, "shore": true})
	var vis_on: bool = gw._on_screen(tp, 60.0)
	for i in n:
		var hit: bool = _roll(s.id, _next()) < GUN_HIT
		if vis_on:
			_fx("shell_burst" if hit else "dirt_burst", "hit_small", tp + Vector2(randf_range(-8, 8), randf_range(-4, 4)))
		if hit and gw.mil.alive(f):
			stats["shore_hits"] = int(stats.get("shore_hits", 0)) + 1
			stats["fac_hits"] = int(stats.get("fac_hits", 0)) + 1
			gw.army._damage(f, GUN_DMG, s.c, tp)
	if not gw.mil.alive(f):
		_shore_t.erase(s.id)


func _gun_shore(s: Ship) -> void :
	if _shore_t[s.id] is Facility:
		_gun_fac(s, _shore_t[s.id])
		return
	var u: Unit = _shore_t[s.id]
	if u == null or not u.alive() or u.pos.distance_to(s.pos) > SHORE_R + 10.0 or not _hostile(s.c, u.country_id):
		_shore_t.erase(s.id)
		return
	s.gun_cd = GUN_CD
	s.shot_t = gw.game_time
	s.aim = (u.pos - s.pos).angle()
	var n: int = s.count_mod("gun")
	_ev({"k": "gun", "ship": s.id, "c": s.c, "victim": u.country_id, "n": n, "pos": s.pos, "tp": u.pos, "shore": true})
	var vis_on: bool = gw._on_screen(u.pos, 60.0)
	for i in n:
		var hit: bool = _roll(s.id, _next()) < SHORE_HIT
		if vis_on:
			_fx("shell_burst" if hit else "dirt_burst", "hit_small", u.pos + Vector2(randf_range(-5, 5), randf_range(-4, 4)))
		if hit and u.alive():
			stats["shore_hits"] = int(stats.get("shore_hits", 0)) + 1
			gw.army._damage(u, SHORE_DMG, s.c)








const COAST_DETECT: float = 900.0
const COAST_RANGE: float = 1100.0
const COAST_AMMO: int = 4
const COAST_RELOAD: float = 40.0
const COAST_SALVO: int = 2
const COAST_CD: float = 15.0
const COAST_RIPPLE: float = 2.0
var _coast_q: Array = []


func _coastal(dt: float) -> void :
	var now: float = gw.game_time
	var art: bool = gw.spr_index.has("coastal_asm")
	for k in range(_coast_q.size() - 1, -1, -1):
		var q: Dictionary = _coast_q[k]
		if float(q["t"]) > now:
			continue
		_coast_q.remove_at(k)
		var qf: Facility = q["f"]
		var qs: Ship = ship(int(q["tgt"]))
		if qf.ammo > 0 and not qf.moving and gw.mil.alive(qf) and qs != null and qs.alive() and _hostile(qf.country_id, qs.c)\
		and qs.pos.distance_to(qf.center_px()) <= COAST_RANGE:
			_coast_fire(qf, qs, 1)
	for f: Facility in gw.mil.facilities:
		if f.kind != Facility.Kind.COASTAL_ASM or f.moving or not gw.mil.alive(f) or f.mb:
			continue
		if f.ammo > COAST_AMMO:
			f.ammo = COAST_AMMO
		if f.ammo < COAST_AMMO:
			f.reload_t += dt
			if f.reload_t >= COAST_RELOAD:
				f.reload_t = 0.0
				f.ammo += 1
		if art and f.alert_t > 0.0 and now > f.alert_t:
			f.alert_t = 0.0
			gw.set_obj_frame(f.main_obj, "coastal_asm", 0)
		f.cd -= dt
		if f.cd > 0.0 or f.ammo <= 0:
			continue
		var p: Vector2 = f.center_px()
		var best: Ship = null
		var bd: float = minf(COAST_DETECT, COAST_RANGE)
		for e: Ship in ships:
			if e.alive() and _hostile(f.country_id, e.c) and e.pos.distance_to(p) < bd:
				bd = e.pos.distance_to(p)
				best = e
		if best == null:
			continue
		var n: int = mini(COAST_SALVO, f.ammo)
		f.cd = COAST_CD
		_coast_fire(f, best, 0)
		for i in range(1, n):
			_coast_q.append({"f": f, "tgt": best.id, "t": now + COAST_RIPPLE * float(i)})



func _coast_fire(f: Facility, best: Ship, i: int) -> void :
	var now: float = gw.game_time
	f.ammo -= 1
	var mouth: Vector2 = f.center_px() + Vector2(0, -6)
	if gw.spr_index.has("coastal_asm") and f.main_obj >= 0:
		var at1: Variant = gw.get("atlas_navy1")
		var inf: Dictionary = (at1 as SpriteAtlas).info("coastal_asm") if at1 is SpriteAtlas and (at1 as SpriteAtlas).has("coastal_asm") else {}
		var mo: Variant = inf.get("mouth", null)
		if mo is Array and (mo as Array).size() >= 2:
			mouth = gw.obj_origin(f.main_obj) + Vector2(float(mo[0]), float(mo[1]))
		gw.set_obj_frame(f.main_obj, "coastal_asm", 2)
		f.alert_t = now + 1.5
	var m: Dictionary = {"id": _mid, "c": f.country_id, "src": -1 - f.id, "pos": mouth + Vector2(float(i % 2) * 3.0, 0.0), 
		"heading": (best.pos - mouth).angle(), "tgt": best.id, "tp": best.pos, "life": COAST_RANGE * 1.35 / ASM_SPEED, 
		"res": "", "st": 0, "kill_t": -1.0, "trail": PackedVector2Array(), "tr_t": 0.0}
	_mid += 1
	msl.append(m)
	stats["asm"] = int(stats["asm"]) + 1
	stats["coastal_asm"] = int(stats.get("coastal_asm", 0)) + 1
	_ev({"k": "launch", "msl": m["id"], "c": f.country_id, "ship": 0, "tgt": best.id, "victim": best.c, "pos": mouth, "coastal": true})
	if gw._on_screen(mouth, 60.0):
		_fx("launch_cloud", "dust_s", mouth)




func _ai_coastal(c: Country, reserve: int) -> void :
	var have: int = 0
	for f: Facility in gw.mil.facilities:
		if f.kind == Facility.Kind.COASTAL_ASM and f.country_id == c.id:
			have += 1
	if have >= [1, 2, 3][GameConfig.diff_of(c)]:
		return
	var anchor: Facility = null
	var bs: Array[Facility] = bases_of(c.id)
	if not bs.is_empty():
		anchor = bs[0]
	elif _ports() != null:
		anchor = _ports().port_of(c)
	if anchor == null:
		return
	var threat: bool = false
	for e: Ship in ships:
		if e.alive() and _hostile(c.id, e.c) and e.pos.distance_to(anchor.center_px()) < 3000.0:
			threat = true
			break
	if not threat:
		return
	var cost: Dictionary = Economy.build_cost(Facility.Kind.COASTAL_ASM)
	if c.money < int(cost["money"]) + reserve / 2 or not c.has_res(cost):
		return
	var f2: Facility = gw.mil.auto_place(Facility.Kind.COASTAL_ASM, anchor.cell + anchor.size / 2, c, 8, 40)
	if f2 != null:
		c.money -= int(cost["money"])
		gw.econ.pay_build(c, Facility.Kind.COASTAL_ASM)
		f2.ammo = COAST_AMMO





func damage(s: Ship, dmg: float, by: int, what: String) -> void :
	if s == null or not s.alive() or dmg <= 0.0:
		return
	s.hp -= dmg
	if what != "fire":
		s.hit_t = gw.game_time
		if s.fires.size() < FIRE_MAX and _roll(s.id, _next()) < float(FIRE_CHANCE.get(what, 0.0)):
			_ignite(s)
	if s.hp <= 0.0:
		_sink(s, by)


func _ignite(s: Ship) -> void :
	var r: float = _roll(s.id, _next())
	var off: = Vector2(lerpf(-5.0, 5.0, r), lerpf(-1.5, 1.5, fposmod(r * 7.0, 1.0)))
	s.fires.append([off, 20.0 + r * 15.0])


func _sink(s: Ship, by: int) -> void :
	s.hp = 0.0
	s.state = Ship.State.SINK
	s.sink_t = 0.0
	s.refit = ""
	s.fires.clear()
	s.path = PackedVector2Array()
	stats["sunk"] = int(stats["sunk"]) + 1
	for k in range(asm_queue.size() - 1, -1, -1):
		if int(asm_queue[k][1]) == s.id:
			asm_queue.remove_at(k)
	for k in range(cr_queue.size() - 1, -1, -1):
		if int(cr_queue[k][1]) == s.id:
			cr_queue.remove_at(k)
	var value: int = int(cost_of(s.hull, s.mods).get("money", 0))
	var att: Country = gw.country_by_id(by)
	if att != null and by != s.c:
		att.destroyed += value
	_ev({"k": "sink", "ship": s.id, "c": s.c, "by": by, "pos": s.pos})
	if gw._on_screen(s.pos, 60.0):
		_fx("explosion_sea", "explosion_m", s.pos)
	var me: Country = gw.player
	if me != null and s.c == me.id:
		gw.message.emit(Loc.msg(Loc.mk("Потоплен наш корабль «%s»", [Loc.name(s.name)])))
		gw.news_m(Loc.mk("Потоплен корабль «%s»", [Loc.name(s.name)]), "red")
	elif me != null and by == me.id:
		gw.message.emit(Loc.msg(Loc.mk("Потоплен вражеский корабль «%s»", [Loc.name(s.name)])))



func on_strike(p: Vector2, r_px: float, by: int) -> void :
	for s: Ship in ships:
		if not s.alive():
			continue
		var d: float = s.pos.distance_to(p)
		if d <= r_px + 12.0:
			damage(s, STRIKE_DMG * (1.0 - 0.5 * d / (r_px + 12.0)), by, "strike")
	_armor_check(p, r_px)




func _armor_check(p: Vector2, r_px: float) -> void :
	for f: Facility in gw.mil.facilities:
		if f.kind != Facility.Kind.NAVAL_BASE or not bool(_alive_b.get(f.id, false)):
			continue
		if Rect2(f.origin_px(), Vector2(f.size * GameWorld.CELL)).grow(r_px + 16.0).has_point(p) == false:
			continue
		if gw.mil.alive(f):
			continue
		var arm: int = int(base_armor.get(f.id, 0))
		if arm <= 0 or f.restore_t > 0.0:
			_alive_b[f.id] = false
			continue
		base_armor[f.id] = arm - 1
		for id in f.obj_ids:
			if id >= 0 and gw.obj_kind[id] == GameWorld.KIND_BUILDING and gw.obj_state[id] == 1:
				gw.obj_state[id] = 0
				gw._mark_obj_chunk(id)
		var c: Country = gw.country_by_id(f.country_id)
		if c != null and c.is_player:
			gw.say(c, Loc.mk("Морская база повреждена: выдержит ещё %d удар(а)", [arm - 1]))







var _cap_seen: Dictionary = {}


func _sync_owners() -> void :
	for c: Country in gw.countries:
		if not c.eliminated and c.capital_id >= 0:
			_cap_seen[c.id] = c.capital_id
	var moved: Dictionary = {}
	for s: Ship in ships:
		var c0: Country = gw.country_by_id(s.c)
		if not s.alive() or c0 == null or not c0.eliminated:
			continue
		var to: int = 0
		if s.base != null and s.base.country_id != s.c and s.base.country_id > 0:
			to = s.base.country_id
		if to == 0 and _cap_seen.has(s.c):
			to = gw.cities[int(_cap_seen[s.c])].country_id
		var ct: Country = gw.country_by_id(to)
		if to == s.c or ct == null or ct.eliminated:
			to = 0
			var bd: float = INF
			for city: City in gw.cities:
				var cc: Country = gw.country_by_id(city.country_id)
				if cc != null and not cc.eliminated and city.country_id != s.c:
					var d: float = Vector2(city.center * GameWorld.CELL).distance_to(s.pos)
					if d < bd:
						bd = d
						to = city.country_id
		if to <= 0:
			continue
		var old: int = s.c
		if s.fleet != 0:
			fl.fleet_remove(s.fleet, s.id)
		s.c = to
		s.fleet = 0
		s.fresh = true
		s.ord = {}
		s.tgt = 0
		s.order_tgt = 0
		s.refit = ""
		s.auto = true
		s.base = null
		for f: Facility in bases_of(to):
			if base_body(f) == _body_px(s.pos):
				s.base = f
				break
		moved[to] = int(moved.get(to, 0)) + 1
		_ev({"k": "transfer", "ship": s.id, "c": to, "from": old, "pos": s.pos})
	for k in range(prod.size() - 1, -1, -1):
		var oc: Country = gw.country_by_id(int(prod[k]["c"]))
		if oc != null and oc.eliminated:
			prod.remove_at(k)
	for k2 in range(fl.fleets.size() - 1, -1, -1):
		var fc: Country = gw.country_by_id(int(fl.fleets[k2]["c"]))
		if fc != null and fc.eliminated:
			fl.fleets.remove_at(k2)
	var me: Country = gw.player
	if me != null and moved.has(me.id):
		gw.message.emit(Loc.msg(Loc.mk("Под ваш флаг перешли корабли капитулировавшей страны: %d", [int(moved[me.id])])))


func _track_bases() -> void :
	_sync_owners()
	for f: Facility in gw.mil.facilities:
		if f.kind != Facility.Kind.NAVAL_BASE:
			continue
		var ok: bool = gw.mil.alive(f)
		if ok and not bool(_alive_b.get(f.id, false)) and not base_armor.has(f.id):
			base_armor[f.id] = armor_max(f)
		elif ok and not bool(_alive_b.get(f.id, true)):
			base_armor[f.id] = armor_max(f)
		_alive_b[f.id] = ok





func launch_asm(s: Ship, t: Ship, n: int = 2) -> int:
	if s == null or t == null or not s.alive() or not t.alive():
		return 0
	return _salvo(s, t.id, t.pos, n)



func launch_asm_at(s: Ship, px: Vector2, n: int = 2) -> int:
	if s == null or not s.alive():
		return 0
	var best: float = 150.0
	var tgt: int = 0
	for o: Ship in ships:
		if o.alive() and _hostile(s.c, o.c) and o.pos.distance_to(px) < best:
			best = o.pos.distance_to(px)
			tgt = o.id
	for cs: Dictionary in convoys():
		if may_hit(s.c, int(cs["owner"]), -1, s) and (cs["pos"] as Vector2).distance_to(px) < best:
			best = (cs["pos"] as Vector2).distance_to(px)
			tgt = - int(cs["id"])
	if tgt == 0:
		_say(s.c, Loc.msg(Loc.mk("Нет вражеской цели у точки")))
		return 0
	return _salvo(s, tgt, _target_pos(tgt), n)


func _salvo(s: Ship, tgt: int, tp: Vector2, n: int) -> int:
	if int(s.ammo.get("asm", 0)) <= 0:
		_say(s.c, Loc.msg(Loc.mk("Нет ПКР: пополните у морской базы")))
		return 0
	if tp.distance_to(s.pos) > ASM_RANGE:
		_say(s.c, Loc.msg(Loc.mk("Цель дальше %.1f км", [ASM_RANGE / 1000.0])))
		return 0
	var owner: int = ship(tgt).c if tgt > 0 else int(convoy( - tgt).get("owner", 0))
	if not may_hit(s.c, owner, tgt, s):
		_say(s.c, Loc.msg(Loc.mk("Цель не враг")))
		return 0
	var k: int = mini(n, int(s.ammo["asm"]))
	s.ammo["asm"] = int(s.ammo["asm"]) - k
	for i in k:
		asm_queue.append([gw.game_time + float(i) * ASM_GAP, s.id, tgt, tp])
	return k




func salvo_quiet(s: Ship, tgt: int, tp: Vector2, n: int, delay: float = 0.0) -> int:
	if s == null or not s.alive() or int(s.ammo.get("asm", 0)) <= 0 or tp.distance_to(s.pos) > ASM_RANGE:
		return 0
	var owner: int = ship(tgt).c if tgt > 0 and ship(tgt) != null else (int(convoy( - tgt).get("owner", 0)) if tgt < 0 else 0)
	if owner == 0 or not may_hit(s.c, owner, tgt, s):
		return 0
	var k: int = mini(n, int(s.ammo["asm"]))
	s.ammo["asm"] = int(s.ammo["asm"]) - k
	for i in k:
		asm_queue.append([gw.game_time + delay + float(i) * ASM_GAP, s.id, tgt, tp])
	return k



func in_flight(tgt: int) -> int:
	var n: int = 0
	for m: Dictionary in msl:
		if int(m["tgt"]) == tgt and float(m.get("kill_t", -1.0)) < 0.0 and not bool(m.get("dec", false)):
			n += 1
	for q: Array in asm_queue:
		if int(q[2]) == tgt:
			n += 1
	return n


func _fire_asm(s: Ship, tgt: int, tp: Vector2) -> void :
	if s == null or not s.alive():
		return
	var owner: int = ship(tgt).c if tgt > 0 and ship(tgt) != null else (int(convoy( - tgt).get("owner", 0)) if tgt < 0 else 0)
	if owner == 0 or not may_hit(s.c, owner, tgt, s):
		s.ammo["asm"] = int(s.ammo.get("asm", 0)) + 1
		return
	var m: Dictionary = {"id": _mid, "c": s.c, "src": s.id, "pos": s.pos, "heading": (tp - s.pos).angle(), "tgt": tgt, "tp": tp, 
		"life": ASM_RANGE * 1.35 / ASM_SPEED, "res": "", "st": 0, "kill_t": -1.0, "trail": PackedVector2Array(), "tr_t": 0.0}
	if not _hostile(s.c, owner):
		m["nt"] = true
	_mid += 1
	msl.append(m)
	if tgt < 0:
		var cv: Dictionary = convoy( - tgt)
		if not cv.is_empty():
			cv["evade_until"] = gw.game_time + 20.0
	s.ash_t = gw.game_time
	stats["asm"] = int(stats["asm"]) + 1
	_ev({"k": "launch", "msl": m["id"], "c": s.c, "ship": s.id, "tgt": tgt, "victim": owner, "pos": s.pos})
	if gw._on_screen(s.pos, 60.0):
		gw.fx.spawn("atgm_launch", s.pos.round(), 6)


func _tick_msl(dt: float) -> void :
	var now: float = gw.game_time
	for k in range(msl.size() - 1, -1, -1):
		var m: Dictionary = msl[k]
		var kt: float = float(m.get("kill_t", -1.0))
		if kt >= 0.0 and now >= kt:
			msl.remove_at(k)
			stats["intercepted"] = int(stats["intercepted"]) + 1
			_ev({"k": "intercepted", "msl": m["id"], "c": m["c"], "by": String(m.get("res", "")), "pos": m["pos"]})
			if gw._on_screen(m["pos"], 60.0):
				_fx("intercept_flash", "explosion_s", m["pos"])
				_fx("explosion_s", "hit_small", m["pos"])
				vis.append({"k": "burst", "from": 0, "p0": m["pos"], "p": m["pos"], "t0": now, "t1": now + 0.5})
			continue
		var vc0: int = _victim_c(m)
		var nt_off: bool = false
		if bool(m.get("nt", false)) and vc0 > 0 and not _hostile(int(m["c"]), vc0):

			var src: Ship = ship(int(m.get("src", 0)))
			nt_off = src == null or not may_hit(int(m["c"]), vc0, int(m["tgt"]), src)
		if vc0 > 0 and not _hostile(int(m["c"]), vc0) and ( not bool(m.get("nt", false)) or nt_off):

			msl.remove_at(k)
			_ev({"k": "miss", "msl": m["id"], "c": m["c"], "pos": m["pos"], "decoy": false, "peace": true})
			if gw._on_screen(m["pos"], 60.0):
				_fx("splash_big", "splash", m["pos"])
			continue
		var decoyed: bool = bool(m.get("dec", false))
		var tp: Variant = null if decoyed else _target_pos(int(m["tgt"]))
		if tp != null:
			m["tp"] = tp
		var to: Vector2 = (m["tp"] as Vector2) - (m["pos"] as Vector2)
		var d: float = to.length()
		var hd: float = float(m["heading"])
		hd += clampf(wrapf(to.angle() - hd, - PI, PI), - ASM_TURN * dt, ASM_TURN * dt)
		m["heading"] = hd
		var step: float = ASM_SPEED * dt
		m["life"] = float(m["life"]) - dt
		m["tr_t"] = float(m.get("tr_t", 0.0)) + dt
		if float(m["tr_t"]) >= 0.05:
			m["tr_t"] = 0.0
			var tr: PackedVector2Array = m.get("trail", PackedVector2Array())
			tr.append(m["pos"])
			if tr.size() > 16:
				tr.remove_at(0)
			m["trail"] = tr
		if kt < 0.0 and not decoyed and tp != null:
			var st: int = int(m.get("st", 0))
			if st < 1 and d <= SAM_AT:
				m["st"] = 1
				_stage_sam(m)
			elif st < 2 and d <= DECOY_AT:
				m["st"] = 2
				_stage_decoy(m)
			elif st < 3 and d <= CIWS_AT:
				m["st"] = 3
				_stage_ciws(m)
		if d <= step + 4.0 and float(m.get("kill_t", -1.0)) < 0.0:
			msl.remove_at(k)
			if tp == null:
				_ev({"k": "miss", "msl": m["id"], "c": m["c"], "pos": m["tp"], "decoy": decoyed})
				if gw._on_screen(m["tp"], 60.0):
					_fx("splash_big", "splash", m["tp"])
					vis.append({"k": "splash", "from": 0, "p0": m["tp"], "p": m["tp"], "t0": now, "t1": now + 1.2})
				continue
			stats["asm_hit"] = int(stats["asm_hit"]) + 1
			var tg: int = int(m["tgt"])
			_ev({"k": "hit", "msl": m["id"], "c": m["c"], "tgt": tg, "victim": _victim_c(m), "pos": m["tp"]})
			if gw._on_screen(m["tp"], 60.0):
				_fx("explosion_sea", "explosion_m", m["tp"])
				_fx("explosion_m", "explosion_s", (m["tp"] as Vector2) + Vector2(0, -4))
				gw.fx.debris_burst((m["tp"] as Vector2).round(), 6, false)
				vis.append({"k": "burst", "from": 0, "p0": m["tp"], "p": m["tp"], "t0": now, "t1": now + 0.7, "big": true})
				if GameConfig.fx_level > 0 and gw._on_screen(m["tp"], -40.0):
					gw.camera_shake_small()
			if tg > 0:
				damage(ship(tg), ASM_DMG, int(m["c"]), "asm")
			else:
				hit_convoy(convoy( - tg), ASM_DMG, int(m["c"]))
			continue
		m["pos"] = (m["pos"] as Vector2) + Vector2.from_angle(hd) * step
		if float(m["life"]) <= 0.0:
			msl.remove_at(k)
			_ev({"k": "miss", "msl": m["id"], "c": m["c"], "pos": m["pos"], "decoy": false})



func _crew(s: Ship) -> float:
	return 0.4 + 0.6 * clampf(s.hp / maxf(1.0, s.hp_max), 0.0, 1.0)



func _threatened(s: Ship) -> bool:
	for m: Dictionary in msl:
		if int(m["tgt"]) == s.id and float(m.get("kill_t", -1.0)) < 0.0 and (m["pos"] as Vector2).distance_to(s.pos) < 400.0:
			return true
	return false



func _defends(d: Ship, victim_c: int, att: int) -> bool:
	return d.c == victim_c or (gw.diplo != null and gw.diplo.allied(d.c, victim_c) and _hostile(d.c, att))


func _victim_c(m: Dictionary) -> int:
	var tg: int = int(m["tgt"])
	if tg > 0:
		var v: Ship = ship(tg)
		return v.c if v != null else 0
	return int(convoy( - tg).get("owner", 0))



func _stage_sam(m: Dictionary) -> void :
	var mid: int = int(m["id"])
	var vc: int = _victim_c(m)
	var mp: Vector2 = m["pos"]
	var now: float = gw.game_time
	var best: Ship = null
	for d: Ship in ships:
		if not d.alive() or int(d.ammo.get("sam", 0)) <= 0 or d.sam_busy > now or d.pos.distance_to(mp) > SAM_R:
			continue
		if not _defends(d, vc, int(m["c"])):
			continue
		if d.id != int(m["tgt"]) and _threatened(d):
			continue
		if best == null or d.id == int(m["tgt"]):
			best = d
	if best == null:
		return
	best.ammo["sam"] = int(best.ammo["sam"]) - 1
	best.sam_busy = now + SAM_BUSY / float(maxi(1, best.count_mod("sam")))
	var t1: float = now + clampf(best.pos.distance_to(mp) / SAM_SPEED, 0.35, 1.2)
	vis.append({"k": "sam", "from": best.id, "p0": best.pos, "msl": mid, "t0": now, "t1": t1, "p": mp})
	if gw._on_screen(best.pos, 60.0):
		_fx("smoke_pop", "dust_s", best.pos + Vector2(0, -4))
	var ok: bool = _roll(mid, 1) < SAM_P * _crew(best)
	_ev({"k": "sam", "msl": mid, "ship": best.id, "ok": ok, "pos": mp, "c": best.c})
	if ok:
		m["kill_t"] = t1
		m["res"] = "sam"



func _stage_decoy(m: Dictionary) -> void :
	var tg: int = int(m["tgt"])
	var v: Ship = ship(tg) if tg > 0 else null
	if v == null or not v.alive() or int(v.ammo.get("decoy", 0)) <= 0:
		return
	var mid: int = int(m["id"])
	v.ammo["decoy"] = int(v.ammo["decoy"]) - 1
	if gw._on_screen(v.pos, 80.0):
		var side: Vector2 = Vector2.from_angle(v.heading).orthogonal()
		_fx("decoy_flare", "intercept_flash", v.pos + side * 10.0 + Vector2(0, -6))
		_fx("decoy_flare", "intercept_flash", v.pos - side * 12.0 + Vector2(0, -4))
		_fx("chaff_cloud", "smoke_pop", v.pos + side * 20.0)
		vis.append({"k": "flares", "from": v.id, "p0": v.pos, "p": v.pos, "hd": v.heading, "t0": gw.game_time, "t1": gw.game_time + 1.8})
	var ok: bool = _roll(mid, 2) < DECOY_P * _crew(v)
	_ev({"k": "decoy", "msl": mid, "ship": v.id, "ok": ok, "pos": v.pos, "c": v.c})
	if ok:
		m["dec"] = true
		m["res"] = "decoy"
		m["tp"] = v.pos + Vector2.from_angle(v.heading).orthogonal() * (45.0 if _roll(mid, 9) < 0.5 else -45.0)



func _stage_ciws(m: Dictionary) -> void :
	var mid: int = int(m["id"])
	var vc: int = _victim_c(m)
	var mp: Vector2 = m["pos"]
	var now: float = gw.game_time
	var step: int = 3
	for d: Ship in ships:
		if not d.alive() or not d.has_mod("ciws") or d.ciws_busy > now or int(d.ammo.get("ciws", 0)) < CIWS_BURST:
			continue
		if not _defends(d, vc, int(m["c"])) or (d.id != int(m["tgt"]) and d.pos.distance_to(mp) > CIWS_HELP_R):
			continue
		d.ammo["ciws"] = int(d.ammo["ciws"]) - CIWS_BURST
		d.ciws_busy = now + CIWS_BUSY / float(maxi(1, d.count_mod("ciws")))
		d.shot_t = now
		d.aim = (mp - d.pos).angle()
		vis.append({"k": "ciws", "from": d.id, "p0": d.pos, "msl": mid, "t0": now, "t1": now + 0.55, "p": mp})
		if gw._on_screen(d.pos, 60.0):
			_fx("muzzle_flash", "hit_small", d.pos + (mp - d.pos).normalized() * 5.0)
		var ok: bool = _roll(mid, step) < CIWS_P * _crew(d)
		step += 1
		_ev({"k": "ciws", "msl": mid, "ship": d.id, "ok": ok, "pos": d.pos, "c": d.c})
		if ok:
			m["kill_t"] = now + 0.4
			m["res"] = "ciws"
			return





func _point_defence() -> void :
	var mil: Military = gw.mil
	if mil == null or ships.is_empty():
		return
	var now: float = gw.game_time
	for dr: Drone in mil.drones:
		if (dr.state != Drone.State.FLY and dr.state != Drone.State.DIVE) or not dr.airborne() or dr.kind < 0 or dr.kind > 2:
			continue
		for s: Ship in ships:
			if dr.state == Drone.State.DONE:
				break
			if not s.alive():
				continue
			var dd: float = s.pos.distance_to(dr.pos)
			if dd > PD_CIWS_R or not _hostile(s.c, dr.country_id):
				continue
			var p: float = 0.0
			var gun: bool = false
			if s.has_mod("ciws") and s.ciws_busy <= now and int(s.ammo.get("ciws", 0)) >= PD_BURST:
				s.ammo["ciws"] = int(s.ammo["ciws"]) - PD_BURST
				s.ciws_busy = now + PD_BUSY / float(maxi(1, s.count_mod("ciws")))
				p = float(PD_CIWS_P[dr.kind])
			elif s.has_mod("gun") and s.pd_t <= now and dd <= PD_GUN_R and float(PD_GUN_P[dr.kind]) > 0.0:
				s.pd_t = now + PD_GUN_CD / float(maxi(1, s.count_mod("gun")))
				p = float(PD_GUN_P[dr.kind])
				gun = true
			else:
				continue
			s.shot_t = now
			s.aim = (dr.pos - s.pos).angle()
			vis.append({"k": "ciws", "from": s.id, "p0": s.pos, "t0": now, "t1": now + (0.18 if gun else 0.3), "p": dr.pos})
			_ev({"k": "gun" if gun else "ciws", "ship": s.id, "pos": s.pos, "c": s.c})
			stats["pd_shots"] = int(stats.get("pd_shots", 0)) + 1
			if _roll(dr.id * 131 + int(now * 4.0), s.id * 7 + (1 if gun else 0)) < p * _crew(s):
				mil.air._kill_drone(dr, DroneBrain.BY_POINT)
				stats["pd_kills"] = int(stats.get("pd_kills", 0)) + 1
				var kc: Country = gw.country_by_id(s.c)
				if kc != null:
					kc.destroyed += 150 if dr.kind == 1 else 100



func _cm_defence() -> void :
	if gw.mil == null:
		return
	var now: float = gw.game_time
	for dr: Drone in gw.mil.drones:
		if (dr.kind != 1 and dr.kind != 2) or dr.state != Drone.State.FLY:
			continue
		var sr: float = SAM_R * (0.7 if dr.low else 1.0)
		for s: Ship in ships:
			if not s.alive() or int(s.ammo.get("sam", 0)) <= 0 or s.sam_busy > now or s.pos.distance_to(dr.pos) > sr:
				continue
			if not _hostile(s.c, dr.country_id):
				continue
			var key: String = "%d:%d" % [dr.id, s.id]
			if _cm_tried.has(key):
				continue
			_cm_tried[key] = true
			s.ammo["sam"] = int(s.ammo["sam"]) - 1
			s.sam_busy = now + SAM_BUSY / float(maxi(1, s.count_mod("sam")))
			var t1: float = now + clampf(s.pos.distance_to(dr.pos) / SAM_SPEED, 0.35, 1.2)
			vis.append({"k": "sam", "from": s.id, "p0": s.pos, "drone": dr, "t0": now, "t1": t1, "p": dr.pos})
			var ok: bool = _roll(dr.id * 7919 + 17, s.id) < (JET_SAM_P if dr.kind == 2 else CM_SAM_P * (CM_LOW_SAM if dr.low else 1.0))
			_ev({"k": "sam_cm", "ship": s.id, "ok": ok, "pos": dr.pos, "c": s.c})
			if ok:
				_cm_kill.append([t1, dr, s.id])
			break
	if _cm_tried.size() > 400:
		_cm_tried.clear()



func launch_cruise(s: Ship, px: Vector2, n: int = 2, delay: float = 0.0) -> int:
	if s == null or not s.alive():
		return 0
	if not s.has_mod("vls"):
		_say(s.c, Loc.msg(Loc.mk("Нет УВП: крылатые ракеты только у крейсера с УВП")))
		return 0
	if s.pos.distance_to(px) > CM_RANGE:
		_say(s.c, Loc.msg(Loc.mk("Цель дальше %.1f км", [CM_RANGE / 1000.0])))
		return 0
	var cell: = Vector2i(floori(px.x / GameWorld.CELL), floori(px.y / GameWorld.CELL))
	var owner: int = gw.data.get_owner_id(cell.x, cell.y) if gw.data.inside(cell.x, cell.y) else 0
	if owner > 0 and owner != s.c and not _hostile(s.c, owner):
		_say(s.c, Loc.msg(Loc.mk("КР по стране без войны: подтвердите удар — будет объявлена война")))
		return 0
	var k: int = mini(n, int(s.ammo.get("cm", 0)))
	if k <= 0:
		_say(s.c, Loc.msg(Loc.mk("Нет крылатых ракет: пополните у морской базы")))
		return 0
	s.ammo["cm"] = int(s.ammo["cm"]) - k

	var t0: float = gw.game_time + delay
	for q: Array in cr_queue:
		if int(q[1]) == s.id:
			t0 = maxf(t0, float(q[0]) + CM_GAP)
	if s.vls_t > -50.0:
		t0 = maxf(t0, s.vls_t + CM_GAP)
	for i in k:
		cr_queue.append([t0 + float(i) * CM_GAP, s.id, px])
	return k


func _release_cm(s: Ship, target: Vector2) -> void :
	if s == null or not s.alive():
		return


	cm_boost.append({"c": s.c, "sid": s.id, "p0": s.pos, "tp": target, "t0": gw.game_time, "hd": (target - s.pos).angle(), "done": false})
	s.vls_t = gw.game_time
	if gw._on_screen(s.pos, 60.0):
		gw.camera_shake_tiny(s.pos)
	stats["cm"] = int(stats["cm"]) + 1
	var cell: = Vector2i(floori(target.x / GameWorld.CELL), floori(target.y / GameWorld.CELL))
	_ev({"k": "cm_launch", "ship": s.id, "c": s.c, "pos": s.pos, "tp": target, "victim": gw.data.get_owner_id(cell.x, cell.y) if gw.data.inside(cell.x, cell.y) else 0})
	if gw._on_screen(s.pos, 60.0):
		gw.fx.spawn("launch_cloud", s.pos.round(), 6)





static func cm_path(e: Dictionary, t: float) -> Array:
	var p0: Vector2 = e["p0"]
	var dirv: Vector2 = Vector2.from_angle(float(e["hd"]))
	if t <= CM_RISE:
		var u: float = clampf(t / CM_RISE, 0.0, 1.0)
		return [p0 + Vector2(0, - CM_UP * (0.3 * u + 0.7 * u * u)), - PI * 0.5]
	var v: float = clampf((t - CM_RISE) / CM_TURN, 0.0, 1.0)
	var a: Vector2 = p0 + Vector2(0, - CM_UP)
	var c: Vector2 = a + Vector2(0, -14.0) + dirv * CM_OUT * 0.15
	var b: Vector2 = p0 + dirv * CM_OUT
	var w: float = 1.0 - v
	var pos: Vector2 = a * (w * w) + c * (2.0 * w * v) + b * (v * v)
	var tan: Vector2 = (c - a) * (2.0 * w) + (b - c) * (2.0 * v)
	return [pos, tan.angle() if tan.length_squared() > 0.001 else - PI * 0.5]


func _cm_boost_tick(now: float) -> void :
	for k in range(cm_boost.size() - 1, -1, -1):
		var e: Dictionary = cm_boost[k]
		var t: float = now - float(e["t0"])
		if not bool(e["done"]) and t >= CM_RISE + CM_TURN:
			e["done"] = true
			_cm_spawn(e)
		if t > CM_RISE + CM_TURN + CM_SMOKE:
			cm_boost.remove_at(k)


func _cm_spawn(e: Dictionary) -> void :
	var mil: Military = gw.mil
	if mil == null:
		return
	var target: Vector2 = e["tp"]
	var p0: Vector2 = e["p0"]
	var hd: float = float(e["hd"])
	var d: = Drone.new()
	d.id = mil._next_drone_id
	mil._next_drone_id += 1
	d.kind = 1
	d.low = true
	d.country_id = int(e["c"])
	d.state = Drone.State.FLY
	d.pos = p0 + Vector2.from_angle(hd) * CM_OUT
	d.heading = hd
	d.speed = Air.CR_SPEED * 0.8
	d.h = CM_LOW_H
	d.cruise_speed = Air.CR_SPEED
	d.turn_rate = PI * 0.5
	d.cruise_h = CM_LOW_H
	d.route = [target]
	d.target = target
	d.range_px = CM_RANGE + 600.0
	d.route_len = d.pos.distance_to(target)
	d.airfield = null
	d.frame = posmod(roundi(hd / TAU * 16.0), 16)
	mil.drones.append(d)




func _missing(s: Ship) -> Dictionary:
	var full: Dictionary = ammo_full(s.hull, s.mods)
	var out: Dictionary = {}
	for k: String in AMMO_KEYS:
		var lack: int = int(full.get(k, 0)) - int(s.ammo.get(k, 0))
		if lack > 0:
			out[k] = lack
	return out




func rearm_load(s: Ship, kind: String = "", n: int = -1) -> Dictionary:
	var miss: Dictionary = _missing(s)
	if kind == "":
		return miss
	var k: String = "cm" if kind == "cruise" else kind
	if not AMMO_KEYS.has(k) or not miss.has(k):
		return {}
	var want: int = int(miss[k]) if n < 0 else mini(n, int(miss[k]))
	return {k: want} if want > 0 else {}


func rearm_cost(s: Ship, kind: String = "", n: int = -1) -> Dictionary:
	var out: Dictionary = {}
	var load: Dictionary = rearm_load(s, kind, n)
	for k: String in load:
		_add(out, REARM_PRICE.get(k, {}), int(load[k]))
	return out



static func rearm_time(load: Dictionary) -> float:
	var t: float = REARM_T0
	t += REARM_T_EACH * float(int(load.get("asm", 0)) + int(load.get("cm", 0)))
	t += 0.5 * float(int(load.get("sam", 0))) + 0.3 * float(int(load.get("decoy", 0)))
	t += 2.0 if int(load.get("ciws", 0)) > 0 else 0.0
	t += 0.15 * float(int(load.get("art", 0)))
	return t


func repair_cost(s: Ship) -> Dictionary:
	var lack: float = maxf(0.0, s.hp_max - s.hp)
	return {"money": ceili(lack * REPAIR_PRICE_HP), "metal": ceili(lack / REPAIR_METAL_HP)}


func _service_why(s: Ship) -> String:
	if s == null or not s.alive():
		return Loc.t("Корабль тонет")
	if near_base(s) == null:
		return Loc.t("Нужна своя морская база рядом (до %d м)") % int(DOCK_R)
	if s.refit != "":
		return Loc.t("Уже на обслуживании")
	if gw.game_time - s.hit_t < SERVICE_QUIET:
		return Loc.t("Под огнём: обслуживание невозможно")
	return ""



func rearm(s: Ship, kind: String = "", n: int = -1) -> String:
	var why: String = _service_why(s)
	if why != "":
		return why
	var load: Dictionary = rearm_load(s, kind, n)
	if load.is_empty():
		return Loc.t("Боекомплект полон") if kind == "" else Loc.t("Этот боекомплект полон или его нет на корабле")
	var cost: Dictionary = rearm_cost(s, kind, n)
	var c: Country = gw.country_by_id(s.c)
	if c == null or not c.has_res(cost):
		return Loc.t("Не хватает: %s") % (c.missing_res(cost) if c != null else "?")
	c.pay_res(cost)
	if gw.econ != null:
		gw.econ.stat_add(c, "spend", "navy", int(cost.get("money", 0)))
	stop(s)
	s.refit = "rearm"
	s.rf_load = load
	s.refit_t = rearm_time(load)
	return ""



func repair(s: Ship) -> String:
	var why: String = _service_why(s)
	if why != "":
		return why
	if s.hp >= s.hp_max - 1.0 and s.fires.is_empty():
		return Loc.t("Корабль цел")
	var cost: Dictionary = repair_cost(s)
	var c: Country = gw.country_by_id(s.c)
	if c == null or not c.has_res(cost):
		return Loc.t("Не хватает: %s") % (c.missing_res(cost) if c != null else "?")
	c.pay_res(cost)
	if gw.econ != null:
		gw.econ.stat_add(c, "spend", "navy", int(cost.get("money", 0)))
	stop(s)
	s.fires.clear()
	s.refit = "repair"
	s.refit_t = (s.hp_max - s.hp) / REPAIR_HP_S + 2.0
	return ""


func _refit_tick(s: Ship, dt: float) -> void :
	if s.state == Ship.State.SAIL or near_base(s) == null:
		s.refit = ""
		return
	s.refit_t -= dt
	if s.refit == "repair":
		s.hp = minf(s.hp_max, s.hp + REPAIR_HP_S * dt)
	if s.refit_t > 0.0:
		return
	if s.refit == "rearm":
		var full: Dictionary = ammo_full(s.hull, s.mods)
		var load: Dictionary = s.rf_load if not s.rf_load.is_empty() else _missing(s)
		for k: String in load:
			s.ammo[k] = mini(int(full.get(k, 0)), int(s.ammo.get(k, 0)) + int(load[k]))
		s.rf_load = {}
	else:
		s.hp = s.hp_max
	_ev({"k": s.refit, "ship": s.id, "c": s.c, "pos": s.pos})
	s.refit = ""




func convoys() -> Array:
	var pr: Ports = _ports()
	return pr.ships if pr != null else []


func convoy(id: int) -> Dictionary:
	for cs: Dictionary in convoys():
		if int(cs["id"]) == id:
			return cs
	return {}


func convoys_of(cid: int) -> Array:
	var out: Array = []
	for cs: Dictionary in convoys():
		if int(cs["owner"]) == cid:
			out.append(cs)
	return out


func hit_convoy(cs: Dictionary, dmg: float, by: int) -> void :
	if cs.is_empty():
		return
	if gw.supply != null:
		gw.supply.on_convoy_fired(cs, by)
	cs["evade_until"] = gw.game_time + 20.0
	cs["hp"] = float(cs.get("hp", CONVOY_HP)) - dmg
	cs["hit_t"] = gw.game_time
	if float(cs["hp"]) <= 0.0:
		_ports().sink_ship(cs, by)



func on_convoy_sunk(cs: Dictionary, by: int, value: int) -> void :
	var owner: int = int(cs.get("owner", 0))
	convoy_lost[owner] = int(convoy_lost.get(owner, 0)) + value
	stats["convoys_sunk"] = int(stats["convoys_sunk"]) + 1

	wrecks.append({"pos": cs["pos"], "heading": float(cs.get("heading", 0.0)), "frame": int(cs.get("frame", 0)), "t0": gw.game_time, "c": owner})
	if gw.supply == null:
		slicks.append([cs["pos"], gw.game_time + SLICK_T * 0.5])
	_ev({"k": "convoy_sunk", "convoy": cs["id"], "c": owner, "by": by, "pos": cs["pos"], "value": value})
	if gw.supply != null:
		gw.supply.on_convoy_sunk(cs, by, value)
	var me: Country = gw.player
	if me != null and owner == me.id:
		gw.message.emit(Loc.msg(Loc.mk("Конвой потоплен: потеряно ~%d", [value])))
	elif me != null and by == me.id:
		gw.message.emit(Loc.msg(Loc.mk("Вражеский конвой потоплен (−%d противнику)", [value])))






func ai_think(c: Country) -> void :
	var now: float = gw.game_time
	if now < AI_START or now < float(ai_next.get(c.id, 0.0)) or c.capital_id < 0 or c.eliminated:
		return
	ai_next[c.id] = now + AI_DT + float(c.id % 4)


	var fdt: float = clampf(now - float(_fund_t.get(c.id, now - AI_DT)), 0.0, 60.0)
	_fund_t[c.id] = now
	var smp: Array = ai_earn.get(c.id, [])
	if smp.size() < 3:
		ai_earn[c.id] = [now, c.earned, 0.0]
	elif now - float(smp[0]) >= 120.0:
		ai_earn[c.id] = [now, c.earned, float(c.earned - int(smp[1])) / maxf(1.0, now - float(smp[0])) * 60.0]
	var P: Dictionary = gw.ai.persona_of(c) if gw.ai != null else {}
	var reserve: int = gw.ai.treasury_reserve(c, P) if gw.ai != null else 1500
	_ai_coastal(c, reserve)
	var bases: Array[Facility] = bases_of(c.id)
	if bases.is_empty():
		if not bases_of(c.id, false).is_empty():
			return



		if now < float(BASE_AT[GameConfig.diff_of(c)]) or not wants_navy(c):
			return
		var bc: Dictionary = Economy.build_cost(Facility.Kind.NAVAL_BASE)

		var bfund: int = int(ai_fund.get(c.id, 0))
		if bfund < int(bc["money"]) and not _land_ok(c):
			ai_why[c.id] = "land first (%d/%d units)" % [gw.army.count_units(c.id), land_min(c)]
			return
		if bfund < int(bc["money"]):
			var inc3: float = ai_income(c)
			var share3: float = [0.2, 0.4, 0.6][GameConfig.diff_of(c)]
			var take3: int = clampi(mini(int(inc3 * share3 * fdt / 60.0), int(float(c.money - _land_keep(c, reserve)) * SURPLUS_SHARE[GameConfig.diff_of(c)])), 0, int(bc["money"]) - bfund)
			c.money -= take3
			bfund += take3
			ai_fund[c.id] = bfund
			ai_why[c.id] = "base fund %d/%d" % [bfund, int(bc["money"])]
			if bfund < int(bc["money"]):
				return
		c.money += bfund
		ai_fund[c.id] = 0
		var sub: bool = not c.has_res(bc)
		if sub and not gw.econ.can_substitute(bc, c):
			gw.econ.ai_blocked(c, _plus(bc, {"money": - int(bc["money"])}))
			ai_fund[c.id] = mini(bfund, c.money)
			c.money -= int(ai_fund[c.id])
			return
		var f: Facility = gw.econ.ai_place(c, Facility.Kind.NAVAL_BASE)
		if f == null:
			ai_why[c.id] = "no base site"
			ai_next[c.id] = now + 120.0
		if f != null:
			if sub:
				gw.econ.pay_substituted(c, bc)
			else:
				c.money -= int(bc["money"])
				gw.econ.pay_build(c, Facility.Kind.NAVAL_BASE)
		return
	var have: int = ships_of(c.id).size()
	var queued: int = 0
	for o: Dictionary in prod:
		if int(o["c"]) == c.id:
			queued += int(o["n"]) - int(o["done"])
	if have + queued >= fleet_target(c):
		return

	var dif: int = GameConfig.diff_of(c)
	var hull: int = 0
	if have >= 3 and dif == 2 and have % 4 == 3:
		hull = 2
	elif have >= [1, 3, 3][dif] and have % 3 == 2:
		hull = 1
	var base: Facility = bases[0]
	var fit: Array = art.ai_fit(c, hull, PRESETS[hull])
	var cost0: Dictionary = cost_of(hull, fit)



	var fund: int = int(ai_fund.get(c.id, 0))
	if fund < int(cost0["money"]) and _land_ok(c):
		var inc: float = ai_income(c)
		var share: float = [0.15, 0.4, 0.55][dif]
		if have < [1, 2, 3][dif]:
			share = minf(0.6, share * 1.4)
		var keep: int = _land_keep(c, reserve)
		var take: int = clampi(mini(int(inc * share * fdt / 60.0), int(float(c.money - keep) * SURPLUS_SHARE[dif])), 0, int(cost0["money"]) - fund)
		c.money -= take
		fund += take
		ai_fund[c.id] = fund
	var busy_n: int = 0
	for o2: Dictionary in prod:
		if int(o2["c"]) == c.id:
			busy_n += 1
	if busy_n >= SLIPWAYS:
		ai_why[c.id] = "fund %d/%d (yard busy)" % [fund, int(cost0["money"])]
		return
	if fund >= int(cost0["money"]) and c.has_res(_plus(cost0, {"money": - fund})):
		c.money += fund
		ai_fund[c.id] = 0
		ai_why[c.id] = order(base, hull, fit, 1)
		if ai_why[c.id] != "":
			ai_fund[c.id] = mini(fund, c.money)
			c.money -= int(ai_fund[c.id])
	elif fund >= int(cost0["money"]) and gw.econ != null and gw.mil.alive(base):

		c.money += fund
		ai_fund[c.id] = 0
		if gw.econ.can_substitute(cost0, c) and gw.econ.pay_substituted(c, cost0, "navy") == "":
			_enqueue(base, hull, fit, 1)
			ai_why[c.id] = "substituted"
		else:
			ai_fund[c.id] = mini(fund, c.money)
			c.money -= int(ai_fund[c.id])
			ai_why[c.id] = "fund full, short: %s" % c.missing_res(cost0)
			gw.econ.ai_blocked(c, _plus(cost0, {"money": - int(cost0["money"])}))
	else:
		ai_why[c.id] = "fund %d/%d %s" % [fund, int(cost0["money"]), c.missing_res(_plus(cost0, {"money": - int(cost0["money"])}))]
		if not c.has_res(_plus(cost0, {"money": - int(cost0["money"])})) and gw.econ != null:
			gw.econ.ai_blocked(c, _plus(cost0, {"money": - int(cost0["money"])}))




const SURPLUS_SHARE: Array = [0.3, 0.45, 0.8]


const LAND_MIN: Array = [26, 14, 20]


const LAND_PER_MIN: Array = [1.0, 0.8, 1.0]


func land_min(c: Country) -> int:
	var d: int = GameConfig.diff_of(c)
	return maxi(int(LAND_MIN[d]), int(gw.game_time / 60.0 * float(LAND_PER_MIN[d])))


func _land_ok(c: Country) -> bool:
	return gw.army == null or gw.army.count_units(c.id) >= land_min(c)


func _land_keep(c: Country, reserve: int) -> int:
	return reserve




func ai_income(c: Country) -> float:
	var smp: Array = ai_earn.get(c.id, [])
	var inc: float = float(smp[2]) if smp.size() > 2 else 0.0
	return maxf(600.0, maxf(inc, float(c.earned) / maxf(60.0, gw.game_time) * 60.0))



func fleet_target(c: Country) -> int:
	var smp: Array = ai_earn.get(c.id, [])
	var inc: float = float(smp[2]) if smp.size() > 2 else 0.0
	var d: int = GameConfig.diff_of(c)
	var late: int = 1 + d if gw.game_time > 900.0 else 0

	var base_n: int = [1, 2, 3][d] + (late if d > 0 else (1 if gw.game_time > 900.0 and inc > 1500.0 else 0))
	return clampi(base_n + int(inc / [3000.0, 2000.0, 1200.0][d]), 1, [2, 5, 8][d])



func wants_navy(c: Country) -> bool:
	var ce: Array = _wants.get(c.id, [])
	if not ce.is_empty() and gw.game_time - float(ce[0]) < 60.0:
		return bool(ce[1])
	var ok: bool = _wants_navy(c)
	if not ok and site_pending(c):
		return false
	_wants[c.id] = [gw.game_time, ok]
	return ok


func _wants_navy(c: Country) -> bool:
	var pr: Ports = _ports()
	if pr == null or ( not pr.has_port(c) and find_base_site(c).x < 0):
		return false
	if gw.naval != null and gw.naval.colony_count(c) > 0:
		return true
	if gw.supply != null and gw.supply.war_trade_target(c):
		return true
	if pr.has_port(c) and pr.ocean(pr.port_of(c)):
		return true
	return sea_rival(c) != null



func sea_rival(c: Country) -> Country:
	if c.capital_id < 0:
		return null
	var a: Vector2 = Vector2(gw.cities[c.capital_id].center * GameWorld.CELL)
	var searched: bool = false
	for o: Country in gw.countries:
		if o == c or o.eliminated or o.capital_id < 0:
			continue
		var key: String = "%d:%d" % [mini(c.id, o.id), maxi(c.id, o.id)]
		var ce: Array = _reach.get(key, [])
		if ce.is_empty() or gw.game_time - float(ce[0]) > 600.0:



			var ends: = Vector4i(gw.cities[c.capital_id].center.x, gw.cities[c.capital_id].center.y, gw.cities[o.capital_id].center.x, gw.cities[o.capital_id].center.y)
			if ce.size() >= 4 and int(ce[2]) == gw.econ.nav_solid_ver and ce[3] == ends:
				ce = [gw.game_time, ce[1], ce[2], ends]
				_reach[key] = ce
			elif searched and ce.is_empty():
				continue
			elif not searched:
				searched = true
				gw.econ.nav_path(a, Vector2(gw.cities[o.capital_id].center * GameWorld.CELL))
				ce = [gw.game_time, gw.econ.nav_last_ok, gw.econ.nav_solid_ver, ends]
				_reach[key] = ce
		if not bool(ce[1]) and (c.at_war.has(o.id) or a.distance_to(Vector2(gw.cities[o.capital_id].center * GameWorld.CELL)) < 9000.0):
			return o
	return null


func _cm_target(s: Ship) -> Facility:
	var best: Facility = null
	var bd: float = CM_RANGE
	for f: Facility in gw.mil.facilities:
		if not _hostile(s.c, f.country_id) or not gw.mil.alive(f):
			continue
		if gw.ai != null and gw.ai.get("sense") != null and gw.ai.sense.aim_veto(s.c, f.center_px(), "air") != "":
			continue
		var shore: bool = f.kind == Facility.Kind.COASTAL_ASM
		if not shore and f.kind != Facility.Kind.NAVAL_BASE and f.kind != Facility.Kind.PORT and f.kind != Facility.Kind.POWER_PLANT and f.kind != Facility.Kind.REFINERY:
			continue
		var d: float = f.center_px().distance_to(s.pos)
		if d > CM_RANGE:
			continue
		if shore:
			d *= 0.5
		if d < bd:
			bd = d
			best = f
	return best




func _next() -> int:
	_rn += 1
	return _rn



func _roll(a: int, b: int) -> float:
	if gw.data != null:
		_seed = int(gw.data.world_seed)
	var h: int = hash([_seed, a, b])
	return float(h & 16777215) / 16777216.0


func _ev(ev: Dictionary) -> void :
	ev["t"] = gw.game_time
	events.append(ev)
	if events.size() > 40:
		events.remove_at(0)
	event.emit(ev)


func _fx(name: String, alt: String, p: Vector2) -> void :
	if gw.fx == null:
		return
	gw.fx.spawn(name if gw.fx.atlas_of.has(name) else alt, p.round(), 6)


func _say(cid: int, text: String) -> void :
	var c: Country = gw.country_by_id(cid)
	if c != null and c.is_player:
		gw.say(c, text)


func save_state() -> Dictionary:
	var sh: Array = []
	for s: Ship in ships:
		sh.append(s.to_dict())
	return {"v": 1, "ships": sh, "prod": prod, "msl": msl, "wrecks": wrecks, "asm_queue": asm_queue, "cr_queue": cr_queue, "cm_boost": cm_boost, "slicks": slicks, 
		"base_armor": base_armor, "auto_refit": auto_refit, "convoy_lost": convoy_lost, "stats": stats, "ai_next": ai_next, 
		"ai_earn": ai_earn, "ai_fund": ai_fund, "names_n": names_n, "fleets_d": fl.save(), "_id": _id, "_mid": _mid, "_rn": _rn, "art": art.save(), 
		"site_off": _site_off.duplicate(), "site_fail": _site_fail.duplicate(), "site_pend": _site_pend.duplicate(true), "site_hit": _site_hit.duplicate(true), 
		"wants": _wants.duplicate(true), "fund_t": _fund_t.duplicate()}


func load_state(d: Dictionary) -> void :
	ships.clear()
	for sd: Variant in d.get("ships", []):
		if sd is Dictionary:
			var s: Ship = Ship.from_dict(sd)
			if s.hull < 0 or s.hull > 2:
				continue
			for k: String in AMMO_KEYS:
				s.ammo[k] = int(s.ammo.get(k, 0))
			ships.append(s)
	prod.clear()
	for o: Variant in d.get("prod", []):
		if o is Dictionary and (o as Dictionary).get("base") is Facility:
			prod.append(o)
	msl = (d.get("msl", []) as Array).duplicate()
	asm_queue = (d.get("asm_queue", []) as Array).duplicate()
	cr_queue = (d.get("cr_queue", []) as Array).duplicate()
	cm_boost = (d.get("cm_boost", []) as Array).duplicate(true)
	slicks = (d.get("slicks", []) as Array).duplicate()
	wrecks = (d.get("wrecks", []) as Array).duplicate()
	for k: String in ["base_armor", "auto_refit", "convoy_lost", "ai_next", "ai_earn", "ai_fund", "names_n"]:
		var v: Variant = d.get(k, {})
		set(k, (v as Dictionary).duplicate() if v is Dictionary else {})
	var st: Variant = d.get("stats", {})
	if st is Dictionary:
		for k2: Variant in st:
			stats[k2] = st[k2]
	_id = maxi(int(d.get("_id", 1)), 1)
	_mid = maxi(int(d.get("_mid", 1)), 1)
	_rn = int(d.get("_rn", 1))
	for s2: Ship in ships:
		_id = maxi(_id, s2.id + 1)
	_pcache.clear()
	_berth.clear()
	_alive_b.clear()
	_boat_t.clear()
	_coast_q.clear()
	vis.clear()
	_cm_kill.clear()
	_cm_tried.clear()
	var fd: Variant = d.get("fleets_d", {})
	fl.load(fd if fd is Dictionary else {})
	var ad: Variant = d.get("art", {})
	art.load(ad if ad is Dictionary else {})
	for k3: String in ["site_off", "site_fail", "site_pend", "site_hit", "wants", "fund_t"]:
		var src: Dictionary = d.get(k3, {}) if d.get(k3, {}) is Dictionary else {}
		var dst: Dictionary = {}
		for k4: Variant in src:
			dst[int(k4)] = (src[k4] as Array).duplicate() if src[k4] is Array else src[k4]
		set("_" + k3, dst)
	_track_bases()
