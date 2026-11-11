class_name Biome
extends RefCounted


enum {DEEP, OCEAN, SHALLOW, COAST, RIVER, SAND, GRASS, FOREST, PINE, STEPPE, HILLS, ROCK, SNOW, ROAD, STREET, YARD, PLAZA, GARDEN, FIELD, INDUSTRIAL, CRATER, BURNT}


const KEYS: Array = ["deep", "ocean", "shallow", "coast_water", "river", "sand", "grass", "forest", "pine", "steppe", "hills", "rock", "snow", "road", "street", "yard", "plaza", "garden", "field", "industrial", "crater", "burnt"]


static func is_water(b: int) -> bool:
	return b <= RIVER


static func is_open_sea(b: int) -> bool:
	return b <= OCEAN


static func is_natural_land(b: int) -> bool:
	return b == SAND or b == GRASS or b == FOREST or b == PINE or b == STEPPE or b == HILLS or b == FIELD or b == BURNT


static func can_claim(b: int) -> bool:
	return b > OCEAN



static func road_cost(b: int) -> float:
	match b:
		ROAD, STREET:
			return 1.0
		GRASS, FIELD, SAND, STEPPE, BURNT, CRATER:
			return 2.5
		FOREST, PINE:
			return 4.5
		HILLS:
			return 6.5
		YARD, PLAZA, GARDEN, INDUSTRIAL:
			return 12.5
		ROCK:
			return 17.5
		SNOW:
			return 25.0
		RIVER:
			return 40.0
		SHALLOW, COAST:
			return 90.0
	return -1.0



static func claim_wait(b: int) -> int:
	match b:
		FOREST, PINE, HILLS:
			return 1
		RIVER, SHALLOW, COAST:
			return 7
		ROCK:
			return 3
		SNOW:
			return 4
	return 0
