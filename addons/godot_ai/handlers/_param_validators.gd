@tool
class_name McpParamValidators
extends RefCounted

const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")

















static func require_string(name: String, value: Variant) -> Variant:
	var t: = typeof(value)
	if t == TYPE_STRING or t == TYPE_STRING_NAME:
		return null
	return ErrorCodes.make(
		ErrorCodes.WRONG_TYPE, 
		"Param '%s' must be a String, got %s" % [name, type_string(t)], 
	)
