extends RefCounted

var mm_ref: Node = null
var main_ref: Node = null

func init_mod(mm: Node) -> void:
	mm_ref = mm
	if mm.has_method("register_hook"):
		mm.call("register_hook", "on_world_started", Callable(self, "_on_world_started"))

func cleanup_mod(mm: Node) -> void:
	if main_ref != null and is_instance_valid(main_ref) and main_ref.world != null:
		var air: Air = main_ref.world.mil.air
		for aircraft: Aircraft in air.aircraft:
			if aircraft.type == Aircraft.Type.FIGHTER and aircraft.pylon == 3:
				var country: Country = main_ref.world.country_by_id(aircraft.country_id)
				if country != null:
					country.missile_stock[Military.MT_KAB] += aircraft.pylon_n
				aircraft.pylon = 0
				aircraft.pylon_n = 0
		air.arsenal_enabled = false
	if mm != null and mm.has_method("unregister_hook"):
		mm.call("unregister_hook", "on_world_started", Callable(self, "_on_world_started"))
	main_ref = null

func _on_world_started(main: Node, world: Node) -> void:
	main_ref = main
	if world != null and world.mil != null and world.mil.air != null:
		world.mil.air.arsenal_enabled = true
