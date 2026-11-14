extends SceneTree

func _init() -> void:
	var ok: bool = ClassDB.class_exists("DFArmy")
	print("[DFARMY-TEST] class_exists=", ok)
	if not ok:
		quit(1)
		return
	var core: Object = ClassDB.instantiate("DFArmy")
	print("[DFARMY-TEST] version=", core.call("version"))
	var bio: PackedByteArray = PackedByteArray()
	var flg: PackedByteArray = PackedByteArray()
	for y in 64:
		for x in 64:
			var b: int = 6  # суша (GRASS)
			if x >= 28 and x <= 31:
				b = 4  # RIVER
			bio.append(b)
			flg.append(0)
	core.call("grid_set_biome", 64, 64, 4.0, bio, flg, 4, 2)
	var pick: Dictionary = core.call("ford_pick", Vector2(8, 32), Vector2(56, 32), 400.0)
	print("[DFARMY-TEST] ford_pick ok=", pick.get("ok"), " site=", pick.get("site"))
	# степпинг через реку: юнит на (26*4, 128) с путём до (38*4, 128)
	var pos: PackedVector2Array = PackedVector2Array([Vector2(104, 128)])
	var pi: PackedInt32Array = PackedInt32Array([0])
	var starts: PackedInt32Array = PackedInt32Array([0, 1])
	var paths: PackedVector2Array = PackedVector2Array([Vector2(152, 128)])
	var spd: PackedFloat32Array = PackedFloat32Array([20.0])
	var ford: PackedByteArray = PackedByteArray([1])
	var veh: PackedByteArray = PackedByteArray([1])
	var intb: PackedByteArray = PackedByteArray([0])
	var back: PackedByteArray = PackedByteArray([0])
	var res: Dictionary = core.call("step", 1.0 / 30.0, pos, paths, starts, pi, spd, ford, veh, intb, back)
	print("[DFARMY-TEST] step pos=", res.get("pos"), " pi=", res.get("pi"), " water=", res.get("water"), " arrived=", res.get("arrived"))
	var moved: bool = (res.get("pos") as PackedVector2Array)[0].x > 104.0
	print("[DFARMY-TEST] moved=", moved, " RESULT=", "PASS" if (pick.get("ok") and moved) else "FAIL")
	core.free()
	quit(0 if (pick.get("ok") and moved) else 1)
