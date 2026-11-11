@tool
extends RefCounted






const ScriptWork: = preload("res://addons/godot_ai/utils/script_work.gd")


func quiesce_for_script_swap() -> Dictionary:
	return ScriptWork.quiescence()
