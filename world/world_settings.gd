class_name WorldSettings
extends Resource


const SIZE_PRESETS: Array = [[512, "МАЛЫЙ"], [1024, "СРЕДНИЙ"], [2048, "БОЛЬШОЙ"], [4096, "ОГРОМНЫЙ"]]

@export var world_seed: int = 20261016
@export var size: int = 1024
@export_range(15, 85) var land_percent: int = 42
@export_range(1, 8) var continents: int = 3
@export_range(0, 100) var islands: int = 35
@export_range(0, 60) var rivers: int = 22
@export_range(0, 100) var mountains: int = 40
@export_range(0, 100) var forests: int = 50


@export var gen_version: int = 2



@export var map_type: int = 0


@export var lakes: int = -1


var layout_size: int = 0
