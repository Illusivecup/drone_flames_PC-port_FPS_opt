extends SceneTree

const Bulk = preload("res://game/bulk_infrastructure.gd")


class EconomyStub:
	extends RefCounted
	var price: int = 100
	func can_upgrade(f: Facility) -> bool:
		return f.level < 3 and f.restore_t <= 0.0
	func upgrade_cost(f: Facility) -> Dictionary:
		return {"money": price, "metal": 5} if f.level < 3 else {}
	func upgrade(f: Facility, p: Country) -> String:
		var cost: Dictionary = upgrade_cost(f)
		if f.country_id != p.id or not p.has_res(cost):
			return "rejected"
		p.pay_res(cost)
		f.level += 1
		return ""


class QuietFx:
	extends FxLayer
	func spawn(_name: String, _pos: Vector2, _z: int = 6, _until: float = 0.0, _random: bool = false) -> AnimatedSprite2D:
		return null


func _initialize() -> void:
	var e: EconomyStub = EconomyStub.new()
	var player: Country = Country.new()
	player.id = 1
	player.money = 250
	player.metal = 10
	var a: Facility = Facility.new()
	a.country_id = 1
	var b: Facility = Facility.new()
	b.country_id = 1
	var other: Facility = Facility.new()
	other.country_id = 2
	var broken: Facility = Facility.new()
	broken.country_id = 1
	broken.restore_t = 5
	var facilities: Array = [a, other, b, broken]
	var preview: Dictionary = Bulk.plan(e, facilities, player)
	if preview.items.size() != 2 or preview.eligible != 2 or preview.cost != {"money": 200, "metal": 10}:
		push_error("bulk preview incorrectly counted ownership, damaged buildings or resources")
		quit(1)
		return
	b.country_id = 2
	var completed: int = Bulk.apply(e, facilities, player, preview)
	if completed != 1 or a.level != 2 or b.level != 1 or other.level != 1 or player.money != 150 or player.metal != 5:
		push_error("bulk apply changed another country's building or spent wrong resources")
		quit(1)
		return
	b.country_id = 1
	preview = Bulk.plan(e, facilities, player)
	e.price = 110
	if Bulk.apply(e, facilities, player, preview) != 0 or player.money != 150 or player.metal != 5:
		push_error("changed price was not revalidated")
		quit(1)
		return
	player.money = 0
	if not Bulk.plan(e, facilities, player).items.is_empty():
		push_error("unaffordable buildings were selected")
		quit(1)
		return
	var gw: GameWorld = GameWorld.new()
	gw.data = WorldData.new(16, 16, 42)
	gw.mil = Military.new(gw)
	gw.econ = Economy.new(gw)
	gw.fx = QuietFx.new()
	var real_player: Country = Country.new()
	real_player.id = 7
	real_player.money = 10000
	real_player.wood = 100
	gw.player = real_player
	var farm: Facility = Facility.new()
	farm.kind = Facility.Kind.FARM
	farm.country_id = real_player.id
	gw.mil.facilities.append(farm)
	var real_cost: Dictionary = gw.econ.upgrade_cost(farm)
	var expected_money: int = real_player.money - int(real_cost.money)
	var expected_wood: int = real_player.wood - int(real_cost.wood)
	var actual_preview: Dictionary = Bulk.plan(gw.econ, gw.mil.facilities, real_player)
	var actual_done: int = Bulk.apply(gw.econ, gw.mil.facilities, real_player, actual_preview)
	if actual_done != 1 or farm.level != 2 or real_player.money != expected_money or real_player.wood != expected_wood:
		push_error("real Economy.upgrade did not apply correct level and resource cost")
		quit(1)
		return
	gw.fx.free()
	gw.free()
	print("[BULK-TEST] PASS: preview, resource budget, ownership, damaged buildings and price changes")
	print("[BULK-TEST] PASS: actual Economy.upgrade changes level and charges its real cost")
	quit(0)
