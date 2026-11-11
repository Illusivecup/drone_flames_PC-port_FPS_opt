class_name Cosmetics
extends RefCounted





const FILE: String = "res://ui/cosmetics.json"
const DEFAULT: Dictionary = {"frame": "fr_steel", "banner": "bn_steel", "title": ""}
const RARITY_RU: Dictionary = {"common": "ОБЫЧНЫЙ", "rare": "РЕДКИЙ", "epic": "ЭПИЧЕСКИЙ", "legendary": "ЛЕГЕНДАРНЫЙ"}
const DEV_COL: = Color("9ff2f0")

static var _items: Dictionary = {}
static var _order: Array = []


static func _load() -> void :
	if not _items.is_empty():
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if not (d is Dictionary):
		return
	for it: Dictionary in d.get("items", []):
		_items[String(it["code"])] = it
		_order.append(String(it["code"]))


static func item(code: String) -> Dictionary:
	_load()
	return _items.get(code, {})


static func known(code: String) -> bool:
	_load()
	return _items.has(code)



static func of_kind(kind: String) -> Array:
	_load()
	return _order.filter( func(c: String) -> bool: return String(_items[c]["kind"]) == kind)



static func shown(kind: String, code: Variant) -> String:
	var c: String = String(code) if code != null else ""
	return c if known(c) and String(item(c).get("kind", "")) == kind else String(DEFAULT[kind])


static func name_of(code: String) -> String:
	return String(item(code).get("name", ""))


static func rarity_color(code: String) -> Color:
	var it: Dictionary = item(code)
	match String(it.get("exclusive", "")):
		"dev":
			return DEV_COL
		"cbt":
			return UiKit.GREEN
	return {"common": UiKit.MUTED, "rare": UiKit.BLUE, "epic": UiKit.GOLD, "legendary": UiKit.RED}.get(String(it.get("rarity", "common")), UiKit.MUTED)


static func rarity_text(code: String) -> String:
	var it: Dictionary = item(code)
	if it.has("season"):
		return String(RARITY_RU.get(String(it.get("rarity", "common")), ""))
	if it.has("exclusive"):
		return "ЭКСКЛЮЗИВ"
	return String(RARITY_RU.get(String(it.get("rarity", "common")), ""))



static func hint(unlock: Variant, exclusive: String = "") -> String:
	if exclusive == "dev":
		return "ВЫДАЁТСЯ КОМАНДОЙ РАЗРАБОТКИ"
	if exclusive == "cbt":
		return "ВЫДАВАЛИ УЧАСТНИКАМ ЗБТ"
	if exclusive == "halloween":
		return "ВЫДАЁТСЯ НА ХЕЛЛОУИН"
	if not (unlock is Dictionary):
		return "ВЫДАЁТСЯ АДМИНИСТРАЦИЕЙ"
	var u: Dictionary = unlock
	var n: int = int(u.get("min", 0))
	var mode: String = String(u.get("mode", "any"))
	var where: String = "В ЛЮБОМ РЕЖИМЕ" if mode == "any" else "В " + mode.to_upper()
	match String(u.get("type", "")):
		"ranked_games":
			return "СЫГРАЙТЕ %d %s" % [n, _plural(n, "РЕЙТИНГОВУЮ ПАРТИЮ", "РЕЙТИНГОВЫЕ ПАРТИИ", "РЕЙТИНГОВЫХ ПАРТИЙ")]
		"wins":
			return "ПОБЕДИТЕ В %d %s" % [n, _plural(n, "РЕЙТИНГОВОЙ ПАРТИИ", "РЕЙТИНГОВЫХ ПАРТИЯХ", "РЕЙТИНГОВЫХ ПАРТИЯХ")]
		"rating":
			return "ДОСТИГНИТЕ РЕЙТИНГА %d %s" % [n, where]
		"peak":
			return "ДОСТИГНИТЕ РЕЙТИНГА %d ХОТЯ БЫ РАЗ" % n
	return ""


static func _plural(n: int, one: String, few: String, many: String) -> String:
	var m10: int = n % 10
	var m100: int = n % 100
	if m10 == 1 and m100 != 11:
		return one
	if m10 >= 2 and m10 <= 4 and (m100 < 10 or m100 >= 20):
		return few
	return many
