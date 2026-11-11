@tool
extends Node



static func available() -> bool:
	return false


func start() -> void :
	queue_free()
