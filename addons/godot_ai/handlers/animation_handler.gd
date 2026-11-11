@tool
extends "res://addons/godot_ai/handlers/command_handler.gd"

const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")
















const AnimationPresets: = preload("res://addons/godot_ai/handlers/animation_presets.gd")
const AnimationValues: = preload("res://addons/godot_ai/handlers/animation_values.gd")

var _undo_redo: EditorUndoRedoManager
var _presets
var _values

const _LOOP_MODES: = {
	"none": Animation.LOOP_NONE, 
	"linear": Animation.LOOP_LINEAR, 
	"pingpong": Animation.LOOP_PINGPONG, 
}

const _INTERP_MODES: = {
	"nearest": Animation.INTERPOLATION_NEAREST, 
	"linear": Animation.INTERPOLATION_LINEAR, 
	"cubic": Animation.INTERPOLATION_CUBIC, 
}


func _init(undo_redo: EditorUndoRedoManager) -> void :
	_undo_redo = undo_redo
	_presets = AnimationPresets.new(self)
	_values = AnimationValues.new(self)






func create_player(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var node_name: String = params.get("name", "AnimationPlayer")

	var _scene_check: = McpNodeValidator.require_scene_or_error()
	if _scene_check.has("error"):
		return _scene_check
	var scene_root: Node = _scene_check.scene_root

	var parent: Node = scene_root
	if not parent_path.is_empty():
		parent = McpScenePath.resolve(parent_path, scene_root)
		if parent == null:
			return ErrorCodes.make(ErrorCodes.NODE_NOT_FOUND, McpScenePath.format_parent_error(parent_path, scene_root))

	var player: = AnimationPlayer.new()
	if not node_name.is_empty():
		player.name = node_name


	var library: = AnimationLibrary.new()
	player.add_animation_library("", library)

	_undo_redo.create_action("MCP: Create AnimationPlayer %s" % player.name)
	_undo_redo.add_do_method(parent, "add_child", player, true)
	_undo_redo.add_do_method(player, "set_owner", scene_root)
	_undo_redo.add_do_reference(player)
	_undo_redo.add_do_reference(library)
	_undo_redo.add_undo_method(parent, "remove_child", player)
	_undo_redo.commit_action()

	return {
		"data": {
			"path": McpScenePath.from_node(player, scene_root), 
			"parent_path": McpScenePath.from_node(parent, scene_root), 
			"name": String(player.name), 
			"undoable": true, 
		}
	}






func create_animation(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")
	var anim_name: String = params.get("name", "")
	var length: float = float(params.get("length", 1.0))
	var loop_mode_str: String = params.get("loop_mode", "none")

	if player_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: player_path")
	if anim_name.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: name")
	if length <= 0.0:
		return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, "length must be > 0 (got %s)" % length)

	if not _LOOP_MODES.has(loop_mode_str):
		return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, 
			"Invalid loop_mode '%s'. Valid: %s" % [loop_mode_str, ", ".join(_LOOP_MODES.keys())])

	var resolved: = _resolve_player(player_path, true)
	if resolved.has("error"):
		return resolved
	var player: AnimationPlayer = resolved.player
	var library: AnimationLibrary = resolved.library
	var created_player: bool = resolved.get("player_created", false)
	var player_parent: Node = resolved.get("player_parent", null)
	var created_library: = false
	if library == null:
		library = AnimationLibrary.new()
		created_library = true

	var overwrite: bool = params.get("overwrite", false)
	var old_anim: Animation = null
	if library.has_animation(anim_name):
		if not overwrite:
			return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, 
				"Animation '%s' already exists. Pass overwrite=true or delete it first." % anim_name)
		old_anim = library.get_animation(anim_name)

	var anim: = Animation.new()
	anim.length = length
	anim.loop_mode = _LOOP_MODES[loop_mode_str]

	_commit_animation_add("MCP: Create animation %s" % anim_name, 
		player, library, created_library, anim_name, anim, old_anim, 
		created_player, player_parent)

	return {
		"data": {
			"player_path": player_path, 
			"name": anim_name, 
			"length": length, 
			"loop_mode": loop_mode_str, 
			"library_created": created_library or created_player, 
			"animation_player_created": created_player, 
			"overwritten": old_anim != null, 
			"undoable": true, 
		}
	}






func delete_animation(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")
	var anim_name: String = params.get("animation_name", "")

	if player_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: player_path")
	if anim_name.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: animation_name")

	var resolved: = _resolve_player(player_path)
	if resolved.has("error"):
		return resolved
	var player: AnimationPlayer = resolved.player




	var anim_resolved: = _resolve_animation(player, anim_name)
	if anim_resolved.has("error"):
		return anim_resolved
	var old_anim: Animation = anim_resolved.animation
	var library: AnimationLibrary = anim_resolved.library


	var clip_key: String = anim_name
	var slash: = anim_name.find("/")
	if slash >= 0:
		clip_key = anim_name.substr(slash + 1)

	_undo_redo.create_action("MCP: Delete animation %s" % anim_name)
	_undo_redo.add_do_method(library, "remove_animation", clip_key)
	_undo_redo.add_undo_method(library, "add_animation", clip_key, old_anim)
	_undo_redo.add_do_reference(old_anim)
	_undo_redo.commit_action()

	return {
		"data": {
			"player_path": player_path, 
			"animation_name": anim_name, 
			"library_key": anim_resolved.get("library_key", ""), 
			"undoable": true, 
		}
	}






func add_property_track(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")
	var anim_name: String = params.get("animation_name", "")
	var track_path: String = params.get("track_path", "")
	var keyframes = params.get("keyframes", [])
	var interp_str: String = params.get("interpolation", "linear")

	if player_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: player_path")
	if anim_name.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: animation_name")
	if track_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, 
			"Missing required param: track_path (format: 'NodeName:property', e.g. 'Panel:modulate')")
	if not track_path.contains(":"):
		return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, 
			"track_path must include ':property' suffix (e.g. 'Panel:modulate', '.:position')")
	if not _INTERP_MODES.has(interp_str):
		return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, 
			"Invalid interpolation '%s'. Valid: %s" % [interp_str, ", ".join(_INTERP_MODES.keys())])
	if typeof(keyframes) != TYPE_ARRAY or keyframes.is_empty():
		return ErrorCodes.make(ErrorCodes.WRONG_TYPE, "keyframes must be a non-empty array")

	var resolved: = _resolve_player(player_path)
	if resolved.has("error"):
		return resolved
	var player: AnimationPlayer = resolved.player

	var anim_resolved: = _resolve_animation(player, anim_name)
	if anim_resolved.has("error"):
		return anim_resolved
	var anim: Animation = anim_resolved.animation





	var ctx: = AnimationValues.resolve_track_prop_context(track_path, player)
	if ctx.has("error"):
		return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, ctx.error)
	var coerced_keyframes: Array = []
	for kf in keyframes:
		if typeof(kf) != TYPE_DICTIONARY:
			return ErrorCodes.make(ErrorCodes.WRONG_TYPE, "Each keyframe must be a dictionary")
		if not "time" in kf:
			return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Each keyframe must have a 'time' field")
		if not "value" in kf:
			return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Each keyframe must have a 'value' field")
		var coerce_result: = AnimationValues.coerce_with_context(kf.get("value"), ctx)
		if coerce_result.has("error"):
			return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, coerce_result.error)
		coerced_keyframes.append({
			"time": kf.get("time"), 
			"value": coerce_result.ok, 
			"transition": kf.get("transition", "linear"), 
		})

	_create_scene_pinned_action("MCP: Add property track %s to %s" % [track_path, anim_name])
	_undo_redo.add_do_method(self, "_do_add_property_track", anim, track_path, interp_str, coerced_keyframes)



	_undo_redo.add_undo_method(self, "_undo_remove_track_by_path", anim, track_path, Animation.TYPE_VALUE)
	_undo_redo.commit_action()

	return {
		"data": {
			"player_path": player_path, 
			"animation_name": anim_name, 
			"track_path": track_path, 
			"interpolation": interp_str, 
			"keyframe_count": keyframes.size(), 
			"undoable": true, 
		}
	}






func _do_add_property_track(
	anim: Animation, 
	track_path: String, 
	interp_str: String, 
	keyframes: Array, 
) -> void :
	var idx: = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(idx, NodePath(track_path))
	anim.track_set_interpolation_type(idx, _INTERP_MODES.get(interp_str, Animation.INTERPOLATION_LINEAR))
	for kf in keyframes:
		var t: float = float(kf.get("time", 0.0))
		var trans: float = AnimationValues.parse_transition(kf.get("transition", "linear"))
		anim.track_insert_key(idx, t, kf.get("value"), trans)






func add_method_track(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")
	var anim_name: String = params.get("animation_name", "")
	var target_path: String = params.get("target_node_path", "")
	var keyframes = params.get("keyframes", [])

	if player_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: player_path")
	if anim_name.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: animation_name")
	if target_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: target_node_path")
	if target_path.contains(":"):
		return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, 
			"target_node_path is a bare NodePath without ':property' (got '%s'). " % target_path + 
			"Method name goes in each keyframe's 'method' field, not the path.")
	if typeof(keyframes) != TYPE_ARRAY or keyframes.is_empty():
		return ErrorCodes.make(ErrorCodes.WRONG_TYPE, "keyframes must be a non-empty array")

	for kf in keyframes:
		if typeof(kf) != TYPE_DICTIONARY:
			return ErrorCodes.make(ErrorCodes.WRONG_TYPE, "Each keyframe must be a dictionary")
		if not "time" in kf:
			return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Each keyframe must have a 'time' field")
		if not "method" in kf:
			return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Each keyframe must have a 'method' field")
		var method_field = kf.get("method")
		if typeof(method_field) != TYPE_STRING or (method_field as String).is_empty():
			return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, "'method' must be a non-empty string")
		if kf.has("args") and typeof(kf.get("args")) != TYPE_ARRAY:
			return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, 
				"'args' must be an array if provided (got %s)" % type_string(typeof(kf.get("args"))))

	var resolved: = _resolve_player(player_path)
	if resolved.has("error"):
		return resolved
	var player: AnimationPlayer = resolved.player

	var anim_resolved: = _resolve_animation(player, anim_name)
	if anim_resolved.has("error"):
		return anim_resolved
	var anim: Animation = anim_resolved.animation

	_create_scene_pinned_action("MCP: Add method track %s to %s" % [target_path, anim_name])
	_undo_redo.add_do_method(self, "_do_add_method_track", anim, target_path, keyframes)

	_undo_redo.add_undo_method(self, "_undo_remove_track_by_path", anim, target_path, Animation.TYPE_METHOD)
	_undo_redo.commit_action()

	return {
		"data": {
			"player_path": player_path, 
			"animation_name": anim_name, 
			"target_node_path": target_path, 
			"keyframe_count": keyframes.size(), 
			"undoable": true, 
		}
	}






func _undo_remove_track_by_path(anim: Animation, track_path: String, track_type: int) -> void :
	var idx: = anim.find_track(NodePath(track_path), track_type)
	if idx >= 0:
		anim.remove_track(idx)


func _do_add_method_track(anim: Animation, target_path: String, keyframes: Array) -> void :
	var idx: = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(idx, NodePath(target_path))
	for kf in keyframes:
		var t: float = float(kf.get("time", 0.0))
		var method_name: String = str(kf.get("method", ""))
		var args: Array = kf.get("args", [])
		anim.track_insert_key(idx, t, {"method": method_name, "args": args})






func set_autoplay(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")
	var anim_name: String = params.get("animation_name", "")

	if player_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: player_path")

	var resolved: = _resolve_player(player_path)
	if resolved.has("error"):
		return resolved
	var player: AnimationPlayer = resolved.player


	if not anim_name.is_empty() and not player.has_animation(anim_name):
		return ErrorCodes.make(ErrorCodes.PROPERTY_NOT_ON_CLASS, 
			"Animation '%s' not found on player at %s" % [anim_name, player_path])

	var old_autoplay: String = player.autoplay

	_undo_redo.create_action("MCP: Set autoplay %s on %s" % [anim_name, player_path])
	_undo_redo.add_do_property(player, "autoplay", anim_name)
	_undo_redo.add_undo_property(player, "autoplay", old_autoplay)
	_undo_redo.commit_action()

	return {
		"data": {
			"player_path": player_path, 
			"animation_name": anim_name, 
			"previous_autoplay": old_autoplay, 
			"cleared": anim_name.is_empty(), 
			"undoable": true, 
		}
	}






func play(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")
	var anim_name: String = params.get("animation_name", "")

	if player_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: player_path")

	var resolved: = _resolve_player(player_path)
	if resolved.has("error"):
		return resolved
	var player: AnimationPlayer = resolved.player

	if not anim_name.is_empty() and not player.has_animation(anim_name):
		return ErrorCodes.make(ErrorCodes.PROPERTY_NOT_ON_CLASS, 
			"Animation '%s' not found on player at %s" % [anim_name, player_path])

	player.play(anim_name)

	return {
		"data": {
			"player_path": player_path, 
			"animation_name": anim_name, 
			"undoable": false, 
			"reason": "Runtime playback state — not saved with scene", 
		}
	}






func stop(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")

	if player_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: player_path")

	var resolved: = _resolve_player(player_path)
	if resolved.has("error"):
		return resolved
	var player: AnimationPlayer = resolved.player

	player.stop()

	return {
		"data": {
			"player_path": player_path, 
			"undoable": false, 
			"reason": "Runtime playback state — not saved with scene", 
		}
	}






func create_simple(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")
	var anim_name: String = params.get("name", "")
	var tweens = params.get("tweens", [])
	var loop_mode_str: String = params.get("loop_mode", "none")

	if player_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: player_path")
	if anim_name.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: name")
	if typeof(tweens) != TYPE_ARRAY or tweens.is_empty():
		return ErrorCodes.make(ErrorCodes.WRONG_TYPE, "tweens must be a non-empty array")
	if not _LOOP_MODES.has(loop_mode_str):
		return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, 
			"Invalid loop_mode '%s'. Valid: %s" % [loop_mode_str, ", ".join(_LOOP_MODES.keys())])


	var seen_paths: = {}
	for spec in tweens:
		if typeof(spec) != TYPE_DICTIONARY:
			return ErrorCodes.make(ErrorCodes.WRONG_TYPE, "Each tween spec must be a dictionary")
		for field in ["target", "property", "from", "to", "duration"]:
			if not field in spec:
				return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, 
					"Each tween spec must have '%s'" % field)
		if float(spec.get("duration", 0.0)) <= 0.0:
			return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, 
				"tween 'duration' must be > 0")
		var dup_key: String = str(spec.target) + ":" + str(spec.property)
		if seen_paths.has(dup_key):
			return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, 
				"Duplicate tween target '%s' — merge keyframes into a single track " % dup_key + 
				"via animation_add_property_track instead of two separate tweens.")
		seen_paths[dup_key] = true



	var has_length: bool = params.has("length") and params.get("length") != null
	var computed_length: float = 0.0
	if has_length:
		computed_length = float(params.get("length"))
		if computed_length <= 0.0:
			return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, 
				"'length' must be > 0 when provided (got %s)" % str(params.get("length")))
	else:
		for spec in tweens:
			var end_time: float = float(spec.get("delay", 0.0)) + float(spec.get("duration", 0.0))
			if end_time > computed_length:
				computed_length = end_time
		if computed_length <= 0.0:
			computed_length = 1.0

	var resolved: = _resolve_player(player_path, true)
	if resolved.has("error"):
		return resolved
	var player: AnimationPlayer = resolved.player
	var library: AnimationLibrary = resolved.library
	var created_player: bool = resolved.get("player_created", false)
	var player_parent: Node = resolved.get("player_parent", null)
	var created_library: = false
	if library == null:
		library = AnimationLibrary.new()
		created_library = true

	var overwrite: bool = params.get("overwrite", false)
	var old_anim: Animation = null
	if library.has_animation(anim_name):
		if not overwrite:
			if created_player:
				player.queue_free()
			return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, 
				"Animation '%s' already exists. Pass overwrite=true or delete it first." % anim_name)
		old_anim = library.get_animation(anim_name)





	var coerce_root: Node = player_parent if created_player else null
	var per_track_keyframes: Array = []
	for spec in tweens:
		var target: String = str(spec.get("target", ""))
		var property: String = str(spec.get("property", ""))
		var track_path: String = target + ":" + property
		var duration: float = float(spec.get("duration", 1.0))
		var delay: float = float(spec.get("delay", 0.0))
		var trans_str = spec.get("transition", "linear")
		var from_result: = AnimationValues.coerce_value_for_track(spec.get("from"), track_path, player, coerce_root)
		if from_result.has("error"):
			if created_player:
				player.queue_free()
			return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, "tween '%s': %s" % [track_path, from_result.error])
		var to_result: = AnimationValues.coerce_value_for_track(spec.get("to"), track_path, player, coerce_root)
		if to_result.has("error"):
			if created_player:
				player.queue_free()
			return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, "tween '%s': %s" % [track_path, to_result.error])
		per_track_keyframes.append({
			"track_path": track_path, 
			"keyframes": [
				{"time": delay, "value": from_result.ok, "transition": trans_str}, 
				{"time": delay + duration, "value": to_result.ok, "transition": trans_str}, 
			], 
		})


	var anim: = Animation.new()
	anim.length = computed_length
	anim.loop_mode = _LOOP_MODES[loop_mode_str]

	for entry in per_track_keyframes:
		_do_add_property_track(anim, entry.track_path, "linear", entry.keyframes)



	_commit_animation_add("MCP: Create animation %s (%d tracks)" % [anim_name, anim.get_track_count()], 
		player, library, created_library, anim_name, anim, old_anim, 
		created_player, player_parent)

	return {
		"data": {
			"player_path": player_path, 
			"name": anim_name, 
			"length": computed_length, 
			"loop_mode": loop_mode_str, 
			"track_count": anim.get_track_count(), 
			"library_created": created_library or created_player, 
			"animation_player_created": created_player, 
			"overwritten": old_anim != null, 
			"undoable": true, 
		}
	}








func preset_fade(params: Dictionary) -> Dictionary:
	return _presets.preset_fade(params)


func preset_slide(params: Dictionary) -> Dictionary:
	return _presets.preset_slide(params)


func preset_shake(params: Dictionary) -> Dictionary:
	return _presets.preset_shake(params)


func preset_pulse(params: Dictionary) -> Dictionary:
	return _presets.preset_pulse(params)


func list_animations(params: Dictionary) -> Dictionary:
	return _values.list_animations(params)


func get_animation(params: Dictionary) -> Dictionary:
	return _values.get_animation(params)


func validate_animation(params: Dictionary) -> Dictionary:
	return _values.validate_animation(params)











func _commit_animation_add(
	action_label: String, 
	player: AnimationPlayer, 
	library: AnimationLibrary, 
	created_library: bool, 
	anim_name: String, 
	anim: Animation, 
	old_anim: Animation, 
	created_player: bool = false, 
	player_parent: Node = null, 
) -> void :
	_undo_redo.create_action(action_label)
	if created_player:
		var scene_root: = EditorInterface.get_edited_scene_root()
		_undo_redo.add_do_method(player_parent, "add_child", player, true)
		_undo_redo.add_do_method(player, "set_owner", scene_root)
		_undo_redo.add_do_reference(player)
		_undo_redo.add_do_reference(library)
		_undo_redo.add_undo_method(player_parent, "remove_child", player)
	elif created_library:
		_undo_redo.add_do_method(player, "add_animation_library", "", library)
		_undo_redo.add_undo_method(player, "remove_animation_library", "")
		_undo_redo.add_do_reference(library)
	if old_anim != null:
		_undo_redo.add_do_method(library, "remove_animation", anim_name)
	_undo_redo.add_do_method(library, "add_animation", anim_name, anim)
	if old_anim != null:
		_undo_redo.add_undo_method(library, "remove_animation", anim_name)
		_undo_redo.add_undo_method(library, "add_animation", anim_name, old_anim)
		_undo_redo.add_do_reference(old_anim)
	else:
		_undo_redo.add_undo_method(library, "remove_animation", anim_name)
	_undo_redo.add_do_reference(anim)
	_undo_redo.commit_action()










func _create_scene_pinned_action(action_label: String) -> void :
	_undo_redo.create_action(
		action_label, UndoRedo.MERGE_DISABLE, EditorInterface.get_edited_scene_root(), 
	)

















func _resolve_player(player_path: String, create_if_missing: bool = false) -> Dictionary:
	var _scene_check: = McpNodeValidator.require_scene_or_error()
	if _scene_check.has("error"):
		return _scene_check
	var scene_root: Node = _scene_check.scene_root
	var node: = McpScenePath.resolve(player_path, scene_root)
	if node == null:
		if not create_if_missing:
			return ErrorCodes.make(ErrorCodes.NODE_NOT_FOUND, McpScenePath.format_node_error(player_path, scene_root))
		return _instantiate_player(player_path, scene_root)
	if not node is AnimationPlayer:
		return ErrorCodes.make(ErrorCodes.WRONG_TYPE, 
			"Node at %s is not an AnimationPlayer (got %s)" % [player_path, node.get_class()])
	var player: = node as AnimationPlayer
	var lib: AnimationLibrary = null
	if player.has_animation_library(""):
		lib = player.get_animation_library("")
	return {"player": player, "library": lib, "player_created": false, "player_parent": null}





func _instantiate_player(player_path: String, scene_root: Node) -> Dictionary:
	var slash: = player_path.rfind("/")
	var parent_path: String
	var player_name: String
	if slash < 0:
		parent_path = ""
		player_name = player_path
	else:
		parent_path = player_path.substr(0, slash)
		player_name = player_path.substr(slash + 1)
	if player_name.is_empty():
		return ErrorCodes.make(ErrorCodes.INVALID_PARAMS, 
			"Cannot auto-create AnimationPlayer: player_path '%s' has no leaf name" % player_path)
	var parent: Node
	if parent_path.is_empty():
		parent = scene_root
	else:
		parent = McpScenePath.resolve(parent_path, scene_root)
	if parent == null:
		return ErrorCodes.make(ErrorCodes.NODE_NOT_FOUND, 
			"Cannot auto-create AnimationPlayer at %s: %s" % [
				player_path, McpScenePath.format_parent_error(parent_path, scene_root)])
	var new_player: = AnimationPlayer.new()
	new_player.name = player_name
	var lib: = AnimationLibrary.new()
	new_player.add_animation_library("", lib)
	return {
		"player": new_player, 
		"library": lib, 
		"player_created": true, 
		"player_parent": parent, 
	}



func _resolve_player_read(player_path: String) -> Dictionary:
	var resolved: = McpNodeValidator.resolve_or_error(player_path, "player_path")
	if resolved.has("error"):
		return resolved
	var node: Node = resolved.node
	if not node is AnimationPlayer:
		return ErrorCodes.make(ErrorCodes.WRONG_TYPE, 
			"Node at %s is not an AnimationPlayer (got %s)" % [player_path, node.get_class()])
	return {"player": node as AnimationPlayer}





func _resolve_animation(player: AnimationPlayer, anim_name: String) -> Dictionary:
	if not player.has_animation(anim_name):
		return ErrorCodes.make(ErrorCodes.PROPERTY_NOT_ON_CLASS, 
			"Animation '%s' not found on player. Available: %s" % [
				anim_name, 
				", ".join(Array(player.get_animation_list()))
			])

	var slash: = anim_name.find("/")
	if slash >= 0:
		var lib_key: = anim_name.substr(0, slash)
		var clip_key: = anim_name.substr(slash + 1)
		if player.has_animation_library(lib_key):
			var lib: AnimationLibrary = player.get_animation_library(lib_key)
			if lib.has_animation(clip_key):
				return {"animation": lib.get_animation(clip_key), "library": lib, "library_key": lib_key}

	for lib_name in player.get_animation_library_list():
		var lib2: AnimationLibrary = player.get_animation_library(lib_name)
		if lib2.has_animation(anim_name):
			return {"animation": lib2.get_animation(anim_name), "library": lib2, "library_key": lib_name}

	return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, "Animation found by player but not in any library")
