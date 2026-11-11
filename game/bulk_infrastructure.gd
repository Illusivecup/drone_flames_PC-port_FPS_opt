extends RefCounted
## A local-only convenience over the existing Economy.upgrade rules.

static func plan(econ: Variant, facilities: Array, player: Country) -> Dictionary:
	var remaining: Dictionary = {}
	var selected: Array = []
	var total: Dictionary = {}
	var eligible: int = 0
	if econ == null or player == null:
		return {"items": selected, "cost": total, "eligible": eligible}
	for f: Facility in facilities:
		if f == null or f.country_id != player.id or not econ.can_upgrade(f):
			continue
		eligible += 1
		var cost: Dictionary = econ.upgrade_cost(f)
		if cost.is_empty():
			continue
		var affordable: bool = true
		for key: String in cost:
			if not remaining.has(key):
				remaining[key] = int(player.get(key))
			if int(cost[key]) < 0 or int(remaining[key]) < int(cost[key]):
				affordable = false
		if not affordable:
			continue
		for key: String in cost:
			remaining[key] = int(remaining[key]) - int(cost[key])
			total[key] = int(total.get(key, 0)) + int(cost[key])
		selected.append({"facility": f, "cost": cost.duplicate(true)})
	return {"items": selected, "cost": total, "eligible": eligible}


static func apply(econ: Variant, facilities: Array, player: Country, preview: Dictionary) -> int:
	if econ == null or player == null:
		return 0
	var done: int = 0
	for item: Dictionary in preview.get("items", []):
		var f: Facility = item.get("facility") as Facility
		var cost: Dictionary = item.get("cost", {})
		if f == null or not facilities.has(f) or f.country_id != player.id or not econ.can_upgrade(f):
			continue
		if cost.is_empty() or econ.upgrade_cost(f) != cost or not player.has_res(cost):
			continue
		if String(econ.upgrade(f, player)) == "":
			done += 1
	return done
