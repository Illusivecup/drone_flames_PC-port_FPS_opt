class_name WorldData
extends RefCounted


const F_ROAD: int = 1
const F_BRIDGE: int = 2
const F_OCCUPIED: int = 4
const F_CITY: int = 8

var w: int = 0
var h: int = 0
var world_seed: int = 0
var sea_level: int = 128
var height: PackedByteArray = PackedByteArray()
var biome: PackedByteArray = PackedByteArray()
var owners: PackedByteArray = PackedByteArray()
var flags: PackedByteArray = PackedByteArray()
var dirty_cells: Array[Vector2i] = []
var owners_dirty: bool = false

var gen_version: int = 1
var hills_thr: int = 256
var lakes: Array = []
var fx_cells: Dictionary = {}



func lake_at(x: int, y: int) -> int:
	for e: Array in lakes:
		var r: Rect2i = e[0]
		if x >= r.position.x and y >= r.position.y and x < r.end.x and y < r.end.y:
			var m: int = (e[1] as PackedByteArray)[(y - r.position.y) * r.size.x + (x - r.position.x)]
			if m != 0:
				return m
	return 0


func _init(width: int, height_cells: int, seed_value: int) -> void :
	w = width
	h = height_cells
	world_seed = seed_value
	var n: int = w * h
	height.resize(n)
	biome.resize(n)
	owners.resize(n)
	flags.resize(n)


func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h


func get_biome(x: int, y: int) -> int:
	return biome[y * w + x]


func set_biome(x: int, y: int, b: int) -> void :
	var i: int = y * w + x
	if biome[i] != b:
		biome[i] = b
		dirty_cells.append(Vector2i(x, y))


func get_owner_id(x: int, y: int) -> int:
	return owners[y * w + x]


## Совместимость для модов (алиас к get_owner_id)
func get_owner(x: int, y: int) -> int:
	return owners[y * w + x]


func set_owner_id(x: int, y: int, o: int) -> void :
	owners[y * w + x] = o
	owners_dirty = true


## Совместимость для модов (алиас к set_owner_id)
func set_owner(x: int, y: int, o: int) -> void:
	set_owner_id(x, y, o)


func has_flag(x: int, y: int, f: int) -> bool:
	return (flags[y * w + x] & f) != 0


func add_flag(x: int, y: int, f: int) -> void :
	var i: int = y * w + x
	flags[i] = flags[i] | f


func clear_flag(x: int, y: int, f: int) -> void :
	var i: int = y * w + x
	flags[i] = flags[i] & ( ~ f & 255)
