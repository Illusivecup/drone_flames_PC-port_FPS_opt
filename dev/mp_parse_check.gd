extends SceneTree
## Quick parse check of the net scripts (RESILIENT work): run with
##   godot --headless --path . -s dev/mp_parse_check.gd
func _init() -> void:
	var bad: int = 0
	for p: String in ["res://net/net_config.gd", "res://net/net_session.gd", "res://net/net_hash.gd", "res://net/net_codec.gd", "res://game/save.gd"]:
		var s: Script = load(p)
		if s == null:
			print("FAIL: %s does not load" % p)
			bad += 1
			continue
		if s is GDScript and not (s as GDScript).can_instantiate() and (p != "res://net/net_config.gd" and p != "res://net/net_hash.gd"):
			# RefCounted tool scripts without constructors still instantiate; a failed compile can be caught via reload
			print("WARN: %s loaded but cannot instantiate" % p)
		print("OK: %s" % p)
	# Constants sanity
	print("HOLD_SLOW=%d HOLD_BACKLOG=%d HOLD_MAX=%d SNAP_PARTS_PER_TURN=%d TURN_MARGIN=%d CATCHUP_MS=%.1f RESYNC_CONFIRM=%s" % [
		NetConfig.HOLD_SLOW, NetConfig.HOLD_BACKLOG, NetConfig.HOLD_MAX, NetConfig.SNAP_PARTS_PER_TURN, NetConfig.TURN_MARGIN, NetConfig.CATCHUP_MS, str(NetConfig.RESYNC_CONFIRM)])
	quit(1 if bad > 0 else 0)
