class_name Country
extends RefCounted


var id: int = 0
var name: String = ""
var is_player: bool = false
var style: Dictionary = {}
var color: Color = Color.WHITE
var color_light: Color = Color.WHITE
var color_dark: Color = Color.BLACK
var flag_image: Image
var flag_frames: SpriteFrames
var flag_tex: ImageTexture
var flag_spec: String = ""
var capital_id: int = -1
var money: int = 0:
	set(v):
		if mlog_on and v != money:
			_mlog(v - money)
		money = v



static var mlog_on: bool = false
static var mlog_tick: int = 0
static var mlog: Array = []


func _mlog(d: int) -> void :
	var who: PackedStringArray = PackedStringArray()
	for fr: Dictionary in get_stack():
		var src: String = String(fr.get("source", "")).get_file().get_basename()
		if src == "country":
			continue
		who.append("%s:%s:%d" % [src, String(fr.get("function", "")), int(fr.get("line", 0))])
		if who.size() >= 3:
			break
	mlog.append("%d c%d %+d %s" % [mlog_tick, id, d, "<".join(who)])
	if mlog.size() > 80:
		mlog.pop_front()
var missile_stock: Array[int] = [0, 0, 0, 0, 0, 0]
var fuel: int = 0
var power_cap: int = 0
var power_use: int = 0
var fuel_sold: int = 0
var at_war: Dictionary = {}
var city_ids: PackedInt32Array = PackedInt32Array()


var titanium: int = 0
var metal: int = 0
var wood: int = 0
var oil: int = 0
var precious: int = 0
var food: int = 0
var goods: int = 0
var trade_income: int = 0


var earned: int = 0
var destroyed: int = 0
var captured: int = 0
var lost: int = 0
var score: int = 0
var score_eco: int = 0
var score_mil: int = 0
var eliminated: bool = false


var doctrine_fpv: bool = true
var doctrine_assault: bool = true
var doctrine_retreat: bool = false
var army_defend: bool = false


var ai_t: float = 0.0
var ai_plan: int = 0
var ai_target_city: int = -1
var ai_war_t: float = 0.0


var army_groups: Array = []

var arch: int = 0

var uranium: int = 0

var ai_diff: int = -1


var ad_rules: PackedInt32Array = PackedInt32Array([1023, 1023, 1023, 1023, 1023])




func has_res(cost: Dictionary) -> bool:
	for k: String in cost:
		if int(get(k)) < int(cost[k]):
			return false
	return true


func pay_res(cost: Dictionary) -> void :
	for k: String in cost:
		set(k, int(get(k)) - int(cost[k]))



func missing_res(cost: Dictionary) -> String:
	var out: PackedStringArray = PackedStringArray()
	for k: String in cost:
		var lack: int = int(cost[k]) - int(get(k))
		if lack > 0:
			out.append("%s %d" % [String(RES_RU.get(k, k)), lack])
	return ", ".join(out)



const RES_RU: Dictionary = {"money": "деньги", "titanium": "титан", "metal": "металл", "wood": "дерево", "oil": "нефть", "precious": "драгметаллы", "food": "еда", "fuel": "топливо", "goods": "товары", "uranium": "уран"}




func first_missing(cost: Dictionary) -> String:
	for k: String in cost:
		if int(cost[k]) - int(get(k)) > 0:
			return k
	return ""



static func res_key_ru(nm: String) -> String:
	for k: String in RES_RU:
		if String(RES_RU[k]) == nm:
			return k
	return ""


func add_money(v: int) -> void :
	money += v
	if v > 0:
		earned += v
