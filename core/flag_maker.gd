class_name FlagMaker
extends RefCounted


const WAVE: Array = [[0, 0, 1, 0, -1, -1, 0, 1, 1], [0, 0, 0, 1, 1, 0, -1, -1, 0], [0, 0, -1, -1, 0, 1, 1, 0, -1]]
const FLAG_COLORS: Array = ["roof_red", "roof_blue", "roof_green", "amber", "white", "ui_rubber", "water_coast", "steppe_light", "brick_dark", "forest", "window_light", "intercept_cyan"]

const SHADE: Dictionary = {
	"roof_red": ["fire_orange", "brick_dark"], "roof_blue": ["water_coast", "water_ocean"], 
	"roof_green": ["grass_light", "forest"], "amber": ["window_light", "amber_dark"], 
	"white": ["white", "concrete_light"], "ui_rubber": ["ui_rubber_light", "black"], 
	"water_coast": ["water_foam", "water_shallow"], "steppe_light": ["sand_light", "steppe"], 
	"brick_dark": ["brick", "earth_dark"], "forest": ["grass_dark", "forest_dark"], 
	"window_light": ["white", "amber"], "intercept_cyan": ["water_foam", "water_coast"], 
}



static func make(rng: Rng, main_color: String) -> Dictionary:
	var cols: Array = [main_color]
	var guard: int = 0
	while cols.size() < 3 and guard < 50:
		guard += 1
		var c: String = rng.pick(FLAG_COLORS)
		if not cols.has(c):
			cols.append(c)
	var pattern: int = rng.range_i(6)
	var grid: Array = []
	for y in 6:
		var row: Array = []
		for x in 9:
			var ci: int = 0
			match pattern:
				0:
					ci = y / 2
					if x < 3 and y < 3:
						ci = 2 if y / 2 != 2 else 0
				1:
					ci = x / 3
					if (x == 4 and (y == 2 or y == 3)):
						ci = 0 if x / 3 != 0 else 2
				2:
					ci = 0 if y < 3 else 1
					if x <= mini(y, 5 - y):
						ci = 2
				3:
					ci = 1 if (x == 2 or x == 3 or y == 2 or y == 3) else 0
					if (x == 2 or x == 3) and (y == 2 or y == 3):
						ci = 2
				4:
					ci = 0 if x * 6 < y * 9 else 1
					if absi(x * 6 - y * 9) < 7:
						ci = 2
				_:
					ci = 0
					if x >= 3 and x <= 5 and y >= 1 and y <= 4 and not ((x == 3 or x == 5) and (y == 1 or y == 4)):
						ci = 1
					if x == 4 and (y == 2 or y == 3):
						ci = 2
			row.append(cols[ci])
		grid.append(row)

	if pattern == 1 or pattern == 2 or pattern == 4:
		var emb: String = "white"
		for cand: String in ["white", "amber", "window_light", "ui_rubber"]:
			if not cols.has(cand):
				emb = cand
				break
		for e: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]:
			grid[e.y][e.x + (6 if pattern == 1 else 0)] = emb
	var img: = Image.create(9, 6, false, Image.FORMAT_RGBA8)
	for y in 6:
		for x in 9:
			img.set_pixel(x, y, Palette.c(grid[y][x]))
	var frames: Array[ImageTexture] = []
	for f in 3:
		var fi: = Image.create(9, 8, false, Image.FORMAT_RGBA8)
		var wave: Array = WAVE[f]
		for x in 9:
			var dy: int = int(wave[x])
			var shade: int = 0
			if x > 0:
				var prev: int = int(wave[x - 1])
				if dy < prev:
					shade = 1
				elif dy > prev:
					shade = 2
			for y in 6:
				if x == 8 and y == 0 and f != 1:
					continue
				var cname: String = grid[y][x]
				if shade > 0 and SHADE.has(cname):
					cname = SHADE[cname][shade - 1]
				fi.set_pixel(x, y + 1 + dy, Palette.c(cname))
		frames.append(ImageTexture.create_from_image(fi))
	return {"grid": grid, "image": img, "frames": frames}










const COLS: Array = [
	["БЕЛЫЙ", "f4f6f8", "ffffff", "d6dde6"], ["КОСТЬ", "e8d8a0", "fff1a8", "d4bd78"], 
	["ЗОЛОТО", "ffb000", "ffe08a", "c97a00"], ["ОРАНЖЕВЫЙ", "ff7a1f", "ffc23d", "c95a12"], 
	["АЛЫЙ", "c0392b", "e8402a", "8a1f14"], ["ВИННЫЙ", "6a3024", "8e4430", "4a1a12"], 
	["НЕБЕСНЫЙ", "7cc0f0", "bfe6f5", "4a90e0"], ["СИНИЙ", "2f6fd0", "4a90e0", "2552b0"], 
	["ТЁМНО-СИНИЙ", "1c3a8a", "2552b0", "0b1430"], ["СТАЛЬНОЙ", "5b7fa0", "7c9cba", "45627d"], 
	["ЗЕЛЁНЫЙ", "7aad34", "9bc53d", "5a8f2c"], ["ЛЕСНОЙ", "2e5a22", "3f6e24", "224418"], 
	["БИРЮЗОВЫЙ", "4f7a5a", "6f9a78", "3a5c43"], ["ФИОЛЕТОВЫЙ", "6b3fa0", "8d63c4", "4a2a72"], 
	["СЕРЫЙ", "6e6e6c", "8c8c88", "50504f"], ["ЧЁРНЫЙ", "1e1f1c", "2c2d29", "0e0f0c"], 
]
const LAYOUTS: Array = ["ОДНОТОННЫЙ", "2 ПОЛОСЫ", "3 ПОЛОСЫ", "2 СТОЛБА", "3 СТОЛБА", "ПОЯС", "СТОЛП", "КАНТОН", 
	"КРЕСТ", "КОСОЙ КРЕСТ", "ДИАГОНАЛЬ", "ПЕРЕВЯЗЬ", "КЛИН", "КАЙМА", "ДИСК", "ЧЕТВЕРТИ", 
	"5 ПОЛОС", "ШЕВРОН", "РОМБ", "ДВОЙНАЯ КАЙМА", "СТУПЕНИ", "ВОЛНА", "УГЛЫ", "ШИРОКИЙ СТОЛП"]
const L_NCOL: Array = [1, 2, 3, 2, 3, 2, 2, 2, 3, 2, 2, 3, 3, 2, 2, 2, 3, 3, 2, 3, 2, 3, 2, 3]
const EMBLEMS: Array = ["", "star", "stars3", "sun", "gear", "wings", "bird", "shield", "laurel", "crown", "tower", "swords", "prop", 
	"anchor", "key", "tree", "mount", "wheat", "wolf", "horse", "bolt", "castle", "rocket", "fish", "ship", "flame", 
	"deer", "owl", "snow", "bee"]
const EMB_NAMES: Array = ["НЕТ", "ЗВЕЗДА", "ТРИ ЗВЕЗДЫ", "СОЛНЦЕ", "ШЕСТЕРНЯ", "КРЫЛЬЯ", "ПТИЦА", "ЩИТ", "ЛАВР", "КОРОНА", "БАШНЯ", "МЕЧИ", "ДРОН", 
	"ЯКОРЬ", "КЛЮЧ", "ЕЛЬ", "ГОРЫ", "КОЛОС", "ВОЛК", "КОНЬ", "МОЛНИЯ", "ЗАМОК", "РАКЕТА", "РЫБА", "КОРАБЛЬ", "ПЛАМЯ", 
	"ОЛЕНЬ", "СОВА", "СНЕЖИНКА", "ПЧЕЛА"]


const OLD_LAYOUTS: int = 16
const OLD_EMBLEMS: int = 13
const PLACES: Array = ["ЦЕНТР", "КАНТОН", "У ДРЕВКА"]
const SIZE_NAMES: Array = ["МАЛ.", "СРЕД.", "БОЛ."]

const HARMONY: Array = [[8, 2, 0], [4, 0, 8], [11, 1, 2], [5, 2, 1], [15, 2, 4], [6, 0, 2], [10, 0, 4], [13, 2, 0], 
	[12, 1, 5], [9, 0, 4], [3, 0, 11], [7, 2, 0], [14, 4, 15], [8, 4, 1], [11, 2, 15], [5, 0, 6], [0, 4, 8], 
	[1, 11, 5], [2, 15, 4], [7, 0, 4], [13, 1, 15], [6, 8, 0]]
const WORLD_W: int = 12
const WORLD_H: int = 8

const MAIN_OF: Dictionary = {"roof_blue": 7, "roof_red": 4, "roof_green": 10, "amber": 2, "ui_rubber": 13, "white": 0, 
	"intercept_cyan": 6, "brick_dark": 5}
const TINY: Array = [".#.", "###", ".#."]
const EMB_MASKS: Dictionary = {
	"star": {
		5: ["..#..", ".###.", "#####", ".###.", ".#.#."], 
		9: ["....#....", "....#....", "...###...", "#########", ".#######.", "..#####..", "..##.##..", ".##...##.", ".#.....#."], 
		15: [".......#.......", ".......#.......", "......###......", "......###......", ".....#####.....", "###############", ".#############.", "..###########..", "...#########...", "...#########...", "..#####.#####..", "..####...####..", ".####.....####.", ".###.......###.", ".#...........#."], 
	}, 
	"stars3": {
		5: ["..#..", ".....", "#...#", ".....", "....."], 
		9: [".........", "....#....", "...###...", "....#....", ".........", ".#.....#.", "###...###", ".#.....#.", "........."], 
		15: ["...............", ".......#.......", "......###......", ".....#####.....", "......###......", "......#.#......", "...............", "...............", "..#.........#..", ".###.......###.", "#####.....#####", ".###.......###.", ".#.#.......#.#.", "...............", "..............."], 
	}, 
	"sun": {
		5: ["#.#.#", ".###.", "#####", ".###.", "#.#.#"], 
		9: ["....#....", ".#.....#.", "...###...", "..#####..", "#.#####.#", "..#####..", "...###...", ".#.....#.", "....#...."], 
		15: [".......#.......", ".#.....#.....#.", "..#.........#..", ".....#####.....", "....#######....", "...#########...", "...#########...", "##.#########.##", "...#########...", "...#########...", "....#######....", ".....#####.....", "..#.........#..", ".#.....#.....#.", ".......#......."], 
	}, 
	"gear": {
		5: [".#.#.", "#####", ".#.#.", "#####", ".#.#."], 
		9: ["...###...", ".#.###.#.", "..#####..", "####.####", "###...###", "####.####", "..#####..", ".#.###.#.", "...###..."], 
		15: [".....#####.....", "..##.#####.##..", ".####.###.####.", ".#############.", "..####ooo####..", "#####o...o#####", "####o.....o####", "####o.....o####", "####o.....o####", "#####o...o#####", "..####ooo####..", ".#############.", ".####.###.####.", "..##.#####.##..", ".....#####....."], 
	}, 
	"wings": {
		5: [".....", "#...#", "##.##", ".###.", "..#.."], 
		9: [".........", "##.....##", "###...###", "####.####", ".#######.", "..##o##..", "....#....", ".........", "........."], 
		15: ["...............", "##...........##", "####.......####", "#####.....#####", ".######.######.", "..####ooo####..", ".#####ooo#####.", "..####ooo####..", "...###.#.###...", "....#..#..#....", ".......#.......", "...............", "...............", "...............", "..............."], 
	}, 
	"bird": {
		5: ["..#..", "#.#.#", "#####", "..#..", ".#.#."], 
		9: ["....##...", "#...#....", "##.###..#", "###.#.###", ".#######.", "...###...", "...###...", "..#.#.#..", "........."], 
		15: [".......##......", "......####.....", "#.....##.......", "##....##......#", "###..####....##", "####.####...###", ".############.#", "..###########..", "....#######....", "......###......", "......###......", ".....#####.....", "....##.#.##....", "...............", "..............."], 
	}, 
	"shield": {
		5: ["#####", "#ooo#", "##o##", ".###.", "..#.."], 
		9: ["#########", "#########", "##ooooo##", "###ooo###", "####o####", ".#######.", ".#######.", "..#####..", "....#...."], 
		15: ["###############", "#ooooooooooooo#", "#o###########o#", "#o###########o#", "#o#o#######o#o#", "#o##o#####o##o#", "#o###o###o###o#", "#o####o#o####o#", ".#o####o####o#.", ".#o#########o#.", "..#o#######o#..", "..##o#####o##..", "...##o###o##...", ".....##o##.....", ".......#......."], 
	}, 
	"laurel": {
		5: ["#...#", "#...#", "##.##", ".#.#.", "..#.."], 
		9: ["##.....##", ".#.....#.", "##.....##", ".#.....#.", "##.....##", ".##...##.", "..##.##..", "...#.#...", "..#...#.."], 
		15: [".##.........##.", "..#.........#..", "###.........###", ".##.........##.", "###.........###", ".##.........##.", "###.........###", ".###.......###.", "..##.......##..", ".####.....####.", "...##.....##...", "...####.####...", ".....##.##.....", "......#.#......", ".....#...#....."], 
	}, 
	"crown": {
		5: ["#.#.#", "#.#.#", "#####", "#####", "....."], 
		9: ["....#....", "#..###..#", "#..###..#", "##.###.##", "#########", "#########", "#o#o#o#o#", "#########", "........."], 
		15: [".......#.......", "......###......", ".#.....#.....#.", "###...###...###", ".#....###....#.", ".##..#####..##.", ".###.#####.###.", ".#############.", ".#############.", ".#############.", ".#o#o#o#o#o#o#.", ".#############.", ".#############.", "...............", "..............."], 
	}, 
	"tower": {
		5: ["#.#.#", "#####", "##.##", "##.##", "#####"], 
		9: ["#.#.#.#.#", "#########", ".#######.", ".###o###.", ".##ooo##.", ".#######.", ".##ooo##.", ".##ooo##.", "#########"], 
		15: ["##.##.##.##.##.", "##############.", "##############.", ".############..", ".#####o######..", ".####ooo#####..", ".############..", ".############..", ".#####ooo####..", ".####ooooo###..", ".####ooooo###..", ".####ooooo###..", "##############.", "##############.", "..............."], 
	}, 
	"swords": {
		5: ["#...#", ".#.#.", "..#..", "##.##", "#...#"], 
		9: ["#.......#", ".#.....#.", "..#...#..", "...#.#...", "....#....", "...#.#...", ".###.###.", "..#...#..", ".#.....#."], 
		15: ["#.............#", "##...........##", ".##.........##.", "..##.......##..", "...##.....##...", "....##...##....", ".....##.##.....", "......###......", ".....##.##.....", "....##...##....", ".#.##.....##.#.", "..##.......##..", ".####.....####.", "##...........##", "#.............#"], 
	}, 
	"anchor": {
		5: ["..#..", ".###.", "..#..", "#.#.#", ".###."], 
		9: ["...###...", "...#.#...", "...###...", ".#######.", "....#....", "#...#...#", "##..#..##", ".#######.", "...###..."], 
		15: [".....#####.....", ".....#...#.....", ".....#####.....", ".......#.......", "...#########...", "...#########...", ".......#.......", ".......#.......", ".......#.......", "##.....#.....##", "###....#....###", ".##....#....##.", "..###..#..###..", "...#########...", ".....#####....."], 
	}, 
	"key": {
		5: [".....", "##...", "#####", "##.##", "....."], 
		9: [".........", ".........", ".###.....", "#...#####", "#...#.#.#", ".###..#.#", ".........", ".........", "........."], 
		15: ["...............", "...............", "...............", "..####.........", ".######........", "##....##.......", "##....#########", "##....#########", ".######...##.##", "..####....##.##", "...............", "...............", "...............", "...............", "..............."], 
	}, 
	"tree": {
		5: ["..#..", ".###.", ".###.", "#####", "..#.."], 
		9: ["....#....", "...###...", "..#####..", "...###...", "..#####..", ".#######.", "#########", "....o....", "....o...."], 
		15: [".......#.......", "......###......", ".....#####.....", "....#######....", "......###......", ".....#####.....", "....#######....", "...#########...", ".....#####.....", "....#######....", "...#########...", "..###########..", ".#############.", "......ooo......", "......ooo......"], 
	}, 
	"mount": {
		5: [".#...", "###..", "#o##.", "#o#o#", "#####"], 
		9: [".........", "..#......", ".###.....", ".#o#..#..", "##oo####.", "#ooo##oo#", "#ooo#ooo#", "#########", "........."], 
		15: ["...............", "...............", ".....#.........", ".....#.........", "....##o........", "...###oo.......", "...###oo...#...", "..####ooo..#...", "..####ooo.##o..", ".#####oooo##oo.", "######ooooo#oo.", "######ooooo#ooo", "######ooooooooo", "###############", "..............."], 
	}, 
	"wheat": {
		5: [".#.#.", "..#..", ".#.#.", "..#..", "..#.."], 
		9: ["....#....", "...###...", "..#.#.#..", "..##.##..", ".#..#..#.", ".##.#.##.", "....#....", "....#....", "...#.#..."], 
		15: [".......#.......", "......###......", "....##.#.##....", "....###.###....", ".....##.##.....", "...##..#..##...", "...###.#.###...", "....##.#.##....", "...##..#..##...", "...###.#.###...", "....##.#.##....", ".......#.......", ".......#.......", "......#.#......", ".....#...#....."], 
	}, 
	"wolf": {
		5: ["#...#", "#####", "#.#.#", ".###.", "..#.."], 
		9: ["#.......#", "##.....##", "#########", "#.#####.#", "#########", ".#######.", "..#####..", "...#o#...", "....#...."], 
		15: [".#...........#.", ".##.........##.", ".###.......###.", ".####.....####.", "###############", "###############", "##..#######..##", "###.#######.###", ".#############.", "..###########..", "...#########...", "....#######....", ".....#ooo#.....", "......###......", ".......#......."], 
	}, 
	"horse": {
		5: [".##..", "####.", "#.##.", "..##.", ".###."], 
		9: ["...#.#...", "..#####..", ".##.####.", "#######o.", "###..###.", "....####.", "...#####.", "..######.", ".#######."], 
		15: [".....##.#......", "....#######....", "...#########...", "..###.#######..", ".############o.", "######..#####o.", "####....######.", ".#......######.", "........######.", ".......#######.", "......#######..", ".....#######...", "....########...", "...##########..", "..############."], 
	}, 
	"bolt": {
		5: ["...##", "..##.", ".####", "..##.", ".#..."], 
		9: [".....###.", "....###..", "...###...", "..######.", ".######..", "....###..", "...###...", "..##.....", ".#......."], 
		15: [".........####..", "........####...", ".......####....", "......####.....", ".....####......", "....#########..", "...#########...", "........####...", ".......####....", "......####.....", ".....####......", "....###........", "...##..........", "..#............", "..............."], 
	}, 
	"castle": {
		5: ["#...#", "#.#.#", "#####", "##o##", "##o##"], 
		9: ["#.#...#.#", "###...###", "###.#.###", "#########", "#########", "###ooo###", "##ooooo##", "##ooooo##", "#########"], 
		15: ["##.##.....##.##", "#####.....#####", "#####.....#####", ".###.......###.", ".###.#.#.#.###.", ".#############.", ".#############.", ".###.#####.###.", ".#############.", ".######.######.", ".#####ooo#####.", ".####ooooo####.", ".####ooooo####.", ".####ooooo####.", "###############"], 
	}, 
	"rocket": {
		5: ["..#..", ".###.", ".###.", ".###.", "##.##"], 
		9: ["....#....", "...###...", "...#o#...", "...###...", "...###...", "..#####..", ".##.#.##.", ".#..#..#.", "....o...."], 
		15: [".......#.......", "......###......", "......###......", ".....#####.....", ".....##o##.....", ".....#####.....", ".....#####.....", ".....#####.....", ".....#####.....", "....#######....", "...##.###.##...", "..##..###..##..", "..#...#.#...#..", "......o.o......", ".......o......."], 
	}, 
	"fish": {
		5: [".....", ".##.#", "#####", ".##.#", "....."], 
		9: [".........", ".........", "..####..#", ".######.#", "#.#####o#", "########.", ".######.#", "..####..#", "........."], 
		15: ["...............", "...............", "...............", "...............", "..#######.....#", ".#####o###..###", "##.###o########", "######o########", "######o########", ".#####o###..###", "..#######.....#", "...............", "...............", "...............", "..............."], 
	}, 
	"ship": {
		5: ["..#..", "..##.", "#.###", "#####", ".###."], 
		9: ["....#....", "....##...", "....###..", ".#..####.", "##..#....", "....#....", "#########", ".#######.", "..#####.."], 
		15: [".......#.......", ".......##......", ".......###.....", ".......####....", ".......#####...", ".......######..", "...#...#######.", "..##...#######.", ".###...#.......", "####...#.......", ".......#.......", "###############", ".#############.", "..###########..", "...#########..."], 
	}, 
	"flame": {
		5: ["..#..", ".#.#.", "##.##", "#####", ".###."], 
		9: ["...#.....", "..##...#.", "..###.##.", ".######..", ".#######.", "####.####", "###...###", ".##...##.", "..#####.."], 
		15: [".......#.......", "......##.......", "......###......", ".....####...#..", "....#####..##..", "...######.###..", "...##########..", "..####o#######.", "..###ooo######.", ".####ooo#####..", ".###ooooo####..", ".###ooooo###...", "..###ooo###....", "...#######.....", ".....###......."], 
	}, 
	"deer": {
		5: ["#.#.#", "##.##", ".###.", ".###.", "..#.."], 
		9: ["#.#...#.#", ".##...##.", "..#...#..", "##.###.##", "...#.#...", "...###...", "...###...", "....o....", "........."], 
		15: ["#.#.#.....#.#.#", ".###.......###.", "..##.......##..", "...##.....##...", "....##...##....", ".##..#####..##.", "..##.#####.##..", ".....#####.....", ".....#.#.#.....", ".....#####.....", ".....#####.....", "......###......", "......###......", "......ooo......", "..............."], 
	}, 
	"owl": {

		5: ["#...#", "#####", "#.#.#", "##o##", ".###."], 
		9: [".#.....#.", ".##...##.", "#########", "#o.o#o.o#", "#.o.#.o.#", "#o.o#o.o#", ".###o###.", "..#####..", "..#...#.."], 
		15: ["..#.........#..", "..##.......##..", "..###########..", ".#############.", ".##ooo###ooo##.", ".#o.oo###o.oo#.", ".##ooo###ooo##.", ".######o######.", ".#############.", ".##o#o###o#o##.", ".#############.", "..###########..", "...#########...", "....#.....#....", "...##.....##..."], 
	}, 
	"snow": {
		5: ["..#..", "#.#.#", ".###.", "#.#.#", "..#.."], 
		9: ["....#....", "....#....", "##..#..##", "..##.##..", "....#....", "..##.##..", "##..#..##", "....#....", "....#...."], 
		15: [".......#.......", ".....#.#.#.....", "......###......", ".#.....#.....#.", "..##...#...##..", "##..##.#.##..##", "......###......", "......#o#......", "......###......", "##..##.#.##..##", "..##...#...##..", ".#.....#.....#.", "......###......", ".....#.#.#.....", ".......#......."], 
	}, 
	"bee": {
		5: [".#.#.", "..#..", "#####", "#o#o#", ".###."], 
		9: ["...#.#...", "....#....", "##.###.##", "#o#####o#", ".##ooo##.", "...###...", "...ooo...", "...###...", "....#...."], 
		15: ["..##.......##..", ".#oo#.....#oo#.", ".#ooo#...#ooo#.", "..#ooo#.#ooo#..", "...##.###.##...", ".....#####.....", ".....ooooo.....", "....#######....", "....ooooooo....", "....#######....", ".....ooooo.....", ".....#####.....", "......###......", ".......#.......", "..............."], 
	}, 
	"prop": {
		5: ["##.##", "##.##", "..#..", "##.##", "##.##"], 
		9: [".###.###.", "#o#...#o#", ".###.###.", "...#.#...", "....#....", "...#.#...", ".###.###.", "#o#...#o#", ".###.###."], 
		15: [".###.......###.", "#ooo#.....#ooo#", "#o#o#.....#o#o#", "#ooo#.....#ooo#", ".####.....####.", ".....#...#.....", "......###......", "......###......", "......###......", ".....#...#.....", ".####.....####.", "#ooo#.....#ooo#", "#o#o#.....#o#o#", "#ooo#.....#ooo#", ".###.......###."], 
	}, 
}

static var _cache: Dictionary = {}
static var _cols: Array = []


static func col(i: int, tone: int = 0) -> Color:
	if _cols.is_empty():
		for e: Array in COLS:
			_cols.append([Color.html(String(e[1])), Color.html(String(e[2])), Color.html(String(e[3]))])
	return (_cols[clampi(i, 0, COLS.size() - 1)] as Array)[clampi(tone, 0, 2)]


static func encode(sp: Dictionary) -> String:
	var c: Array = sp.get("c", [0, 0, 0])
	return "1.%d.%d.%d.%d.%d.%d.%d.%d" % [int(sp.get("l", 0)), int(c[0]), int(c[1]), int(c[2]), int(sp.get("e", 0)), 
		int(sp.get("ec", 0)), int(sp.get("p", 0)), int(sp.get("s", 1))]



static func decode(code: String) -> Dictionary:
	var p: PackedStringArray = code.split(".")
	if p.size() != 9 or p[0] != "1":
		return {}
	for k in range(1, 9):
		if not p[k].is_valid_int():
			return {}
	var n: int = COLS.size() - 1
	return {"l": clampi(p[1].to_int(), 0, LAYOUTS.size() - 1), "c": [clampi(p[2].to_int(), 0, n), clampi(p[3].to_int(), 0, n), 
		clampi(p[4].to_int(), 0, n)], "e": clampi(p[5].to_int(), 0, EMBLEMS.size() - 1), "ec": clampi(p[6].to_int(), 0, n), 
		"p": clampi(p[7].to_int(), 0, PLACES.size() - 1), "s": clampi(p[8].to_int(), 0, SIZE_NAMES.size() - 1)}


static func default_place(l: int) -> int:
	return 1 if l == 7 or l == 10 or l == 15 else (2 if l == 12 else 0)



static func contrast(a: int, b: int) -> float:
	var la: float = col(a).get_luminance()
	var lb: float = col(b).get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)



static func pair_ok(_a: int, _b: int) -> bool:
	return true



static func emb_ok(_sp: Dictionary) -> bool:
	return true



static func field_at_emblem(sp: Dictionary) -> int:
	var w: int = 48
	var h: int = 32
	var ctr: Vector2 = _emb_center(sp, w, h)
	var s: int = _slot(int(sp["l"]), clampi(int(ctr.x), 0, w - 1), clampi(int(ctr.y), 0, h - 1), w, h)
	return int((sp["c"] as Array)[s])



static func auto_ec(sp: Dictionary) -> int:
	var f: int = field_at_emblem(sp)
	var best: int = 0
	var bv: float = -1.0
	var cs: Array = sp["c"]
	for cand: int in [cs[0], cs[1], cs[2], 0, 2, 1, 15, 4, 8]:
		if int(sp.get("e", 0)) == 1 and (cand == 4 or cand == 5):
			continue
		var ct: float = contrast(cand, f)

		var v: float = minf(ct, 4.0) + (1.6 if cs.has(cand) and ct >= 1.9 else 0.0) + (0.5 if cand == 0 or cand == 2 else 0.0)
		if cand != f and v > bv:
			bv = v
			best = cand
	return best



static func _slot(l: int, x: int, y: int, w: int, h: int) -> int:
	var fx: float = float(x) + 0.5
	var fy: float = float(y) + 0.5
	match l:
		1:
			return (y * 2) / h
		2:
			return (y * 3) / h
		3:
			return (x * 2) / w
		4:
			return (x * 3) / w
		5:
			return 1 if y * 4 >= h and y * 4 < h * 3 else 0
		6:
			return 1 if x * 4 >= w and x * 4 < w * 3 else 0
		7:
			return 1 if x * 2 < w and y * 2 < h else 0
		8:
			var th: int = maxi(1, roundi(h * 0.2))
			if (h - th) % 2 != 0:
				th += 1
			var tv: int = th
			if (w - tv) % 2 != 0:
				tv += 1
			var y0: int = (h - th) / 2
			var x0: int = (w - tv) / 2
			if (y >= y0 and y < y0 + th) or (x >= x0 and x < x0 + tv):
				return 1
			if h >= 12 and ((y >= y0 - 1 and y < y0 + th + 1) or (x >= x0 - 1 and x < x0 + tv + 1)):
				return 2
			return 0
		9:
			var ln: float = sqrt(float(w * w + h * h))
			var d1: float = absf(fx * h - fy * w) / ln
			var d2: float = absf((w - fx) * h - fy * w) / ln
			return 1 if minf(d1, d2) < maxf(0.75, h * 0.1) else 0
		10:
			return 0 if fx * h + fy * w < float(w * h) else 1
		11:
			var s: float = (fx * h + fy * w - float(w * h)) / sqrt(float(w * w + h * h))
			if absf(s) < maxf(0.8, h * 0.16):
				return 1
			return 0 if s < 0.0 else 2
		12:
			if fx < (h * 0.5 - absf(fy - h * 0.5)) * (w * 0.42) / (h * 0.5):
				return 2
			return (y * 2) / h
		13:
			var t: int = maxi(1, roundi(h * 0.12))
			return 1 if x < t or y < t or x >= w - t or y >= h - t else 0
		14:
			var r: float = h * 0.32
			return 1 if (fx - w * 0.5) * (fx - w * 0.5) + (fy - h * 0.5) * (fy - h * 0.5) < r * r else 0
		15:
			return ((x * 2) / w + (y * 2) / h) % 2
		16:
			return int([0, 1, 2, 1, 0][clampi((y * 5) / h, 0, 4)])
		17:
			var cy: float = h * 0.12 + absf(fx - w * 0.5) * float(h) / (w * 0.5)
			var dv: float = fy - cy
			if absf(dv) < maxf(0.9, h * 0.15):
				return 1
			return 2 if dv > 0.0 else 0
		18:
			return 1 if absf(fx - w * 0.5) / (w * 0.5) + absf(fy - h * 0.5) / (h * 0.5) < 0.86 else 0
		19:
			var t1: int = maxi(1, roundi(h * 0.1))
			var t2: int = t1 + maxi(1, roundi(h * 0.06))
			var dm: int = mini(mini(x, y), mini(w - 1 - x, h - 1 - y))
			return 1 if dm < t1 else (2 if dm < t2 else 0)
		20:
			var st: int = clampi((x * 4) / w, 0, 3)
			return 1 if fy > h * (0.8 - 0.2 * st) else 0
		21:
			var yc: float = h * 0.5 + sin(fx / w * TAU * 1.5) * h * 0.14
			if absf(fy - yc) < maxf(0.9, h * 0.14):
				return 1
			return 0 if fy < yc else 2
		22:
			var ca: float = minf(fx, w - fx) / (h * 0.5) + minf(fy, h - fy) / (h * 0.5)
			return 1 if ca < 0.75 else 0
		23:
			return 0 if x * 4 < w else (2 if x * 4 >= w * 3 else 1)
	return 0


static func _emb_center(sp: Dictionary, w: int, h: int) -> Vector2:
	match int(sp.get("p", 0)):
		1:
			return Vector2(w * 0.25, h * 0.25)
		2:
			return Vector2(w * (0.15 if int(sp["l"]) == 12 else 0.22), h * 0.5)
	return Vector2(w * 0.5, h * 0.5)



static func _emb_box(sp: Dictionary, h: int) -> int:
	var s: int = int(sp.get("s", 1))
	match int(sp.get("p", 0)):
		1:
			return roundi(h * [0.3, 0.4, 0.48][s])
		2:
			return roundi(h * [0.32, 0.42, 0.52][s])
	return roundi(h * [0.42, 0.6, 0.8][s])



static func _mask(e: String, bs: int) -> Array:
	var ms: Dictionary = EMB_MASKS.get(e, {})
	var best: Array = []
	var bv: int = 0
	for m: int in [15, 9, 5]:
		var k: int = bs / m
		if k < 1 or not ms.has(m):
			continue
		var v: int = m * k - (k - 1) * 4
		if v > bv:
			bv = v
			best = [ms[m], k]
	if best.is_empty() and bs >= 3:
		best = [TINY, 1]
	return best



static func _raster(sp: Dictionary, w: int, h: int) -> PackedByteArray:
	var out: = PackedByteArray()
	out.resize(w * h)
	var l: int = int(sp["l"])
	var cs: Array = sp["c"]
	for y in h:
		for x in w:
			out[y * w + x] = int(cs[_slot(l, x, y, w, h)])
	var e: int = int(sp.get("e", 0))
	if e <= 0 or e >= EMBLEMS.size():
		return out
	var mk: Array = _mask(String(EMBLEMS[e]), _emb_box(sp, h))
	if mk.is_empty():
		return out
	var rows: Array = mk[0]
	var k: int = mk[1]
	var mw: int = String(rows[0]).length() * k
	var mh: int = rows.size() * k
	var ctr: Vector2 = _emb_center(sp, w, h)
	var x0: int = roundi(ctr.x - mw * 0.5)
	var y0: int = roundi(ctr.y - mh * 0.5)
	var ec: int = int(sp.get("ec", 0))
	for my in mh:
		var row: String = rows[my / k]
		for mx in mw:
			var ch: String = row[mx / k]
			if ch == ".":
				continue
			var px: int = x0 + mx
			var py: int = y0 + my
			if px < 0 or py < 0 or px >= w or py >= h:
				continue
			out[py * w + px] = ec | (32 if ch == "o" else 0)
	if String(rows[0]).length() < 9:
		return out


	var rim: int = 15 if col(ec).get_luminance() > 0.45 else 0
	var em: = PackedByteArray()
	em.resize(w * h)
	for my2 in mh:
		for mx2 in mw:
			var qx: int = x0 + mx2
			var qy: int = y0 + my2
			if qx >= 0 and qy >= 0 and qx < w and qy < h and String(rows[my2 / k])[mx2 / k] != ".":
				em[qy * w + qx] = 1
	for qy2 in range(maxi(0, y0 - 1), mini(h, y0 + mh + 1)):
		for qx2 in range(maxi(0, x0 - 1), mini(w, x0 + mw + 1)):
			var i: int = qy2 * w + qx2
			if em[i] != 0 or contrast(out[i] & 31, ec) >= 1.8:
				continue
			if (qx2 > 0 and em[i - 1] != 0) or (qx2 < w - 1 and em[i + 1] != 0) or (qy2 > 0 and em[i - w] != 0) or (qy2 < h - 1 and em[i + w] != 0):
				out[i] = rim
	return out


static func _px(v: int, shade: int) -> Color:
	var i: int = v & 31
	if v & 32:
		return col(i, 2) if shade != 2 else col(i, 0)
	return col(i, shade)



static func render(code: String, w: int, h: int) -> Image:
	var sp: Dictionary = decode(code)
	var img: = Image.create(maxi(1, w), maxi(1, h), false, Image.FORMAT_RGBA8)
	if sp.is_empty():
		img.fill(col(14))
		return img
	var r: PackedByteArray = _raster(sp, w, h)
	for y in h:
		for x in w:
			img.set_pixel(x, y, _px(r[y * w + x], 0))
	return img




static func frames(code: String, w: int, h: int, amp: int = 1, n: int = 3) -> Array[ImageTexture]:
	var sp: Dictionary = decode(code)
	var r: PackedByteArray = _raster(sp, w, h) if not sp.is_empty() else PackedByteArray()
	var out: Array[ImageTexture] = []
	var per: float = maxf(9.0, w * 1.1)
	for f in n:
		var img: = Image.create(w, h + amp * 2, false, Image.FORMAT_RGBA8)
		for x in w:
			var a: float = TAU * float(x) / per - TAU * float(f) / float(n)
			var damp: float = clampf(float(x) / maxf(1.0, w * 0.18), 0.0, 1.0)
			var dy: int = roundi(amp * damp * sin(a))
			var slope: float = damp * cos(a)
			var shade: int = 1 if slope < -0.75 else (2 if slope > 0.75 else 0)
			for y in h:
				var v: int = r[y * w + x] if not r.is_empty() else 14
				img.set_pixel(x, y + amp + dy, _px(v, shade))
		out.append(ImageTexture.create_from_image(img))
	return out



static func tex(code: String, w: int, h: int) -> ImageTexture:
	var key: String = "%s@%dx%d" % [code, w, h]
	var t: Variant = _cache.get(key)
	if t != null:
		return t
	if _cache.size() > 800:
		_cache.clear()
	var nt: = ImageTexture.create_from_image(render(code, w, h))
	_cache[key] = nt
	return nt




static func tex_for(c: Country, sz: Vector2) -> Texture2D:
	if c == null:
		return null
	if c.flag_spec == "" or decode(c.flag_spec).is_empty():
		return c.flag_tex
	return tex(c.flag_spec, maxi(3, roundi(sz.x)), maxi(2, roundi(sz.y)))






static func random_spec(rng: Rng, main: int = -1, wide: bool = false) -> Dictionary:
	var pool: Array = []
	for hm: Array in HARMONY:
		if main < 0 or hm.has(main):
			pool.append(hm)
	if pool.is_empty():
		pool = HARMONY
	var cs: Array = (rng.pick(pool) as Array).duplicate()
	if main >= 0 and cs.has(main):
		cs.erase(main)
		cs.push_front(main)
	var l: int = rng.range_i(LAYOUTS.size() if wide else OLD_LAYOUTS)
	var e: int = 0
	if l <= 6 or l == 15 or l == 16 or l == 23 or rng.range_i(100) < 50:
		e = 1 + rng.range_i((EMBLEMS.size() if wide else OLD_EMBLEMS) - 1)
	var sp: Dictionary = {"l": l, "c": cs, "e": e, "ec": 0, "p": default_place(l), "s": 2 if l == 0 else 1}
	if l == 14 and e > 0:
		sp["s"] = 0
	sp["ec"] = auto_ec(sp)
	return sp
