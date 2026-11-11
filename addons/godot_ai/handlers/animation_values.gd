@tool
extends RefCounted

const VariantSerializer: = preload("res://addons/godot_ai/utils/variant_serializer.gd")

















const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")
const PropertyErrors: = preload("res://addons/godot_ai/handlers/_property_errors.gd")


const _NAMED_TRANSITIONS: = {
	"linear": 1.0, 
	"ease_in": 2.0, 
	"ease_out": 0.5, 
	"ease_in_out": -2.0, 
}




const _SUBPATH_COMPONENTS: = {
	TYPE_VECTOR2: ["xy", TYPE_FLOAT], 
	TYPE_VECTOR3: ["xyz", TYPE_FLOAT], 
	TYPE_VECTOR4: ["xyzw", TYPE_FLOAT], 
	TYPE_QUATERNION: ["xyzw", TYPE_FLOAT], 
	TYPE_COLOR: ["rgba", TYPE_FLOAT], 
	TYPE_VECTOR2I: ["xy", TYPE_INT], 
	TYPE_VECTOR3I: ["xyz", TYPE_INT], 
	TYPE_VECTOR4I: ["xyzw", TYPE_INT], 
}


var _handler_weak: WeakRef


func _init(handler) -> void :
	_handler_weak = weakref(handler)


func _h():
	return _handler_weak.get_ref()






func list_animations(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")

	if player_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: player_path")

	var handler = _h()
	if handler == null:
		return ErrorCodes.make_not_ready(
			ErrorCodes.SUB_EDITOR_UNAVAILABLE, 
			"AnimationHandler not available", false)
	var resolved: Dictionary = handler._resolve_player_read(player_path)
	if resolved.has("error"):
		return resolved
	var player: AnimationPlayer = resolved.player

	var animations: Array[Dictionary] = []
	for lib_name in player.get_animation_library_list():
		var lib: AnimationLibrary = player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			var anim: Animation = lib.get_animation(anim_name)
			var display_name: String = anim_name if lib_name == "" else "%s/%s" % [lib_name, anim_name]
			animations.append({
				"name": display_name, 
				"length": anim.length, 
				"loop_mode": loop_mode_to_string(anim.loop_mode), 
				"track_count": anim.get_track_count(), 
			})

	return {
		"data": {
			"player_path": player_path, 
			"animations": animations, 
			"count": animations.size(), 
		}
	}






func get_animation(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")
	var anim_name: String = params.get("animation_name", "")

	if player_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: player_path")
	if anim_name.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: animation_name")

	var handler = _h()
	if handler == null:
		return ErrorCodes.make_not_ready(
			ErrorCodes.SUB_EDITOR_UNAVAILABLE, 
			"AnimationHandler not available", false)
	var resolved: Dictionary = handler._resolve_player_read(player_path)
	if resolved.has("error"):
		return resolved
	var player: AnimationPlayer = resolved.player

	var anim_resolved: Dictionary = handler._resolve_animation(player, anim_name)
	if anim_resolved.has("error"):
		return anim_resolved
	var anim: Animation = anim_resolved.animation

	var tracks: Array[Dictionary] = []
	for i in anim.get_track_count():
		var track_type: = anim.track_get_type(i)
		var type_name: = track_type_to_string(track_type)
		var keys: Array[Dictionary] = []
		for k in anim.track_get_key_count(i):
			var key_val = anim.track_get_key_value(i, k)
			keys.append({
				"time": anim.track_get_key_time(i, k), 
				"value": serialize_value(key_val), 
				"transition": anim.track_get_key_transition(i, k), 
			})
		tracks.append({
			"index": i, 
			"type": type_name, 
			"path": str(anim.track_get_path(i)), 
			"interpolation": interp_to_string(anim.track_get_interpolation_type(i)), 
			"key_count": keys.size(), 
			"keys": keys, 
		})

	return {
		"data": {
			"player_path": player_path, 
			"name": anim_name, 
			"length": anim.length, 
			"loop_mode": loop_mode_to_string(anim.loop_mode), 
			"track_count": anim.get_track_count(), 
			"tracks": tracks, 
		}
	}






func validate_animation(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")
	var anim_name: String = params.get("animation_name", "")

	if player_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: player_path")
	if anim_name.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: animation_name")

	var handler = _h()
	if handler == null:
		return ErrorCodes.make_not_ready(
			ErrorCodes.SUB_EDITOR_UNAVAILABLE, 
			"AnimationHandler not available", false)
	var resolved: Dictionary = handler._resolve_player_read(player_path)
	if resolved.has("error"):
		return resolved
	var player: AnimationPlayer = resolved.player

	if not player.has_animation(anim_name):
		return ErrorCodes.make(ErrorCodes.PROPERTY_NOT_ON_CLASS, 
			"Animation '%s' not found on player at %s" % [anim_name, player_path])

	var anim: Animation = player.get_animation(anim_name)

	var root_node: = player_root_node(player)

	var broken_tracks: Array[Dictionary] = []
	var valid_count: = 0

	for i in anim.get_track_count():
		var track_path_str: = str(anim.track_get_path(i))







		var colon: = track_path_str.find(":")
		var node_part: String
		if colon >= 0:
			node_part = track_path_str.substr(0, colon)
		else:
			node_part = track_path_str

		var target_node: Node = null
		if root_node != null:
			target_node = root_node.get_node_or_null(node_part)

		if target_node == null:
			broken_tracks.append({
				"index": i, 
				"path": track_path_str, 
				"type": track_type_to_string(anim.track_get_type(i)), 
				"issue": "node_not_found", 
				"node_path": node_part, 
			})
		else:
			valid_count += 1

	return {
		"data": {
			"player_path": player_path, 
			"animation_name": anim_name, 
			"track_count": anim.get_track_count(), 
			"valid_count": valid_count, 
			"broken_count": broken_tracks.size(), 
			"broken_tracks": broken_tracks, 
			"valid": broken_tracks.is_empty(), 
		}
	}












static func player_root_node(player: AnimationPlayer) -> Node:
	if not player.is_inside_tree():
		return null
	var rn: = player.root_node
	if rn != NodePath():
		var n: = player.get_node_or_null(rn)
		if n != null:
			return n
	return player.get_parent()












static func coerce_value_for_track(value: Variant, track_path: String, player: AnimationPlayer, override_root_node: Node = null) -> Dictionary:
	var ctx: = resolve_track_prop_context(track_path, player, override_root_node)
	if ctx.has("error"):
		return {"error": ctx.error}
	return coerce_with_context(value, ctx)













static func resolve_track_prop_context(track_path: String, player: AnimationPlayer, override_root_node: Node = null) -> Dictionary:
	var colon: = track_path.find(":")
	if colon < 0:
		return {"pass_through": true}

	var node_part: = track_path.substr(0, colon)
	var prop_full: = track_path.substr(colon + 1)


	var sub_colon: = prop_full.find(":")
	var prop_base: = prop_full if sub_colon < 0 else prop_full.substr(0, sub_colon)
	var prop_sub: = "" if sub_colon < 0 else prop_full.substr(sub_colon + 1)

	var root_node: Node = override_root_node
	if root_node == null:
		root_node = player_root_node(player)
	if root_node == null:
		return {"pass_through": true}

	var target: Node = root_node.get_node_or_null(node_part)
	if target == null:

		return {"pass_through": true}

	for p in target.get_property_list():
		if p.name == prop_base:
			var base_type: int = p.get("type", TYPE_NIL)
			var coerce_type: = base_type
			if not prop_sub.is_empty():
				var sub_type: = subpath_component_type(base_type, prop_sub)
				if sub_type == TYPE_NIL:




					return {"pass_through": true}
				coerce_type = sub_type
			return {
				"pass_through": false, 
				"prop_type": coerce_type, 
				"prop_name": prop_full, 
			}



	return {"error":
		"%s (target path: '%s')" %
		[PropertyErrors.build_message(target, prop_base), node_part]}





static func subpath_component_type(base_type: int, sub: String) -> int:
	var entry = _SUBPATH_COMPONENTS.get(base_type)
	if entry == null or sub.length() != 1:
		return TYPE_NIL
	return entry[1] if (entry[0] as String).contains(sub) else TYPE_NIL


static func coerce_with_context(value: Variant, ctx: Dictionary) -> Dictionary:
	if ctx.get("pass_through", false):
		return {"ok": value}
	return coerce_for_type(value, ctx.prop_type, ctx.prop_name)





static func _is_usable_rotation(quat: Quaternion) -> bool:
	if not is_finite(quat.x) or not is_finite(quat.y) or not is_finite(quat.z) or not is_finite(quat.w):
		return false
	return absf(quat.length() - 1.0) <= 0.001




static func coerce_for_type(value: Variant, prop_type: int, prop_name: String) -> Dictionary:
	match prop_type:
		TYPE_COLOR:


			var col = McpJsonValues.parse_color(value)
			if col != null:
				return {"ok": col}
			return {"error": "Cannot coerce value to Color for property '%s' (expected \"#rrggbb(aa)\"/named string, {r,g,b[,a]}, [r,g,b(,a)], or Color)" % prop_name}
		TYPE_VECTOR2:
			var v2 = McpJsonValues.parse_vector2(value)
			if v2 != null:
				return {"ok": v2}
			return {"error": "Cannot coerce value to Vector2 for property '%s' (expected {x,y}, [x,y], or Vector2)" % prop_name}
		TYPE_VECTOR3:
			var v3 = McpJsonValues.parse_vector3(value)
			if v3 != null:
				return {"ok": v3}
			return {"error": "Cannot coerce value to Vector3 for property '%s' (expected {x,y,z}, [x,y,z], or Vector3)" % prop_name}
		TYPE_FLOAT:



			var parsed: Variant = McpJsonValues.parse_float(value)
			if parsed != null:
				return {"ok": parsed}
		TYPE_INT:
			if value is float or value is int:
				return {"ok": int(value)}
		TYPE_BOOL:
			if value is int or value is float or value is bool:
				return {"ok": bool(value)}
		TYPE_VECTOR3I:
			var v3i = McpJsonValues.parse_vector3i(value)
			if v3i != null:
				return {"ok": v3i}
			return {"error": "Cannot coerce value to Vector3i for property '%s' (expected {x,y,z}, [x,y,z], or Vector3i; components must be finite and within int32 range)" % prop_name}
		TYPE_QUATERNION:
			var quat = McpJsonValues.parse_quaternion(value)
			if quat == null:
				return {"error": "Cannot coerce value to Quaternion for property '%s' (expected {x,y,z,w}, [x,y,z,w], or Quaternion; components must be finite)" % prop_name}









			var largest: = maxf(maxf(absf(quat.x), absf(quat.y)), maxf(absf(quat.z), absf(quat.w)))
			if largest == 0.0:
				return {"error": "Cannot coerce value to Quaternion for property '%s': zero-length quaternion is not a rotation" % prop_name}
			var normalized: = Quaternion(
				quat.x / largest, quat.y / largest, quat.z / largest, quat.w / largest
			).normalized()


			if not _is_usable_rotation(normalized):
				return {"error": "Cannot coerce value to Quaternion for property '%s': components cannot be normalized to a usable rotation" % prop_name}
			return {"ok": normalized}
		TYPE_BASIS:
			var basis = McpJsonValues.parse_basis(value)
			if basis != null:
				return {"ok": basis}
			return {"error": "Cannot coerce value to Basis for property '%s' (expected {x,y,z} axis vectors, a 3x3 nested array, or Basis)" % prop_name}
		TYPE_TRANSFORM3D:
			var xform = McpJsonValues.parse_transform3d(value)
			if xform != null:
				return {"ok": xform}
			return {"error": "Cannot coerce value to Transform3D for property '%s' (expected {basis,origin}, {position,rotation_degrees?,scale?}, or Transform3D)" % prop_name}
		TYPE_RECT2:
			var rect = McpJsonValues.parse_rect2(value)
			if rect != null:
				return {"ok": rect}
			return {"error": "Cannot coerce value to Rect2 for property '%s' (expected {position,size}, [x,y,w,h], or Rect2)" % prop_name}
		TYPE_AABB:
			var aabb = McpJsonValues.parse_aabb(value)
			if aabb != null:
				return {"ok": aabb}
			return {"error": "Cannot coerce value to AABB for property '%s' (expected {position,size}, [x,y,z,w,h,d], or AABB)" % prop_name}
		TYPE_NODE_PATH:
			var node_path = McpJsonValues.parse_node_path(value)
			if node_path != null:
				return {"ok": node_path}
			return {"error": "Cannot coerce value to NodePath for property '%s' (expected a string path)" % prop_name}
		TYPE_STRING_NAME:
			var string_name = McpJsonValues.parse_string_name(value)
			if string_name != null:
				return {"ok": string_name}
			return {"error": "Cannot coerce value to StringName for property '%s' (expected a string)" % prop_name}
	return {"ok": value}








static func parse_transition(v: Variant) -> float:
	if v is float or v is int:
		return float(v)
	if v is String:
		var key: String = (v as String).to_lower()
		if _NAMED_TRANSITIONS.has(key):
			return float(_NAMED_TRANSITIONS[key])
	return 1.0






static func track_type_to_string(track_type: int) -> String:
	match track_type:
		Animation.TYPE_VALUE: return "value"
		Animation.TYPE_METHOD: return "method"
		Animation.TYPE_POSITION_3D: return "position_3d"
		Animation.TYPE_ROTATION_3D: return "rotation_3d"
		Animation.TYPE_SCALE_3D: return "scale_3d"
		Animation.TYPE_BLEND_SHAPE: return "blend_shape"
		Animation.TYPE_BEZIER: return "bezier"
		Animation.TYPE_AUDIO: return "audio"
		Animation.TYPE_ANIMATION: return "animation"
		_: return "unknown"


static func loop_mode_to_string(mode: int) -> String:
	match mode:
		Animation.LOOP_LINEAR: return "linear"
		Animation.LOOP_PINGPONG: return "pingpong"
		_: return "none"


static func interp_to_string(mode: int) -> String:
	match mode:
		Animation.INTERPOLATION_NEAREST: return "nearest"
		Animation.INTERPOLATION_CUBIC: return "cubic"
		_: return "linear"



static func serialize_value(value: Variant) -> Variant:




	return VariantSerializer.serialize(value)
