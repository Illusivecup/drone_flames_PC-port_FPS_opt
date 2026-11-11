class_name MapPreview
extends RefCounted







const GEN: int = 512
const PX: int = 128


const C_SAND: Array = ["#c0aa7c", "#e0d0a2", "#ece2be"]
const C_GRASS: Array = ["#649430", "#7da739", "#96b74b"]
const C_FOREST: Array = ["#2d5232", "#34682b", "#467c2c"]
const C_PINE: Array = ["#23402f", "#2d5232", "#34682b"]
const C_STEPPE: Array = ["#b29245", "#c6a855", "#d6bd6e"]
const C_HILLS: Array = ["#6c5744", "#846c4e", "#9c845e"]
const C_ROCK: Array = ["#585861", "#706f70", "#8b897f"]
const C_SNOW: Array = ["#c7cfe2", "#e2e6ee", "#f8f6ec"]
const W_FOAM: String = "#bde0ec"
const W_NEAR: String = "#77b3de"
const W_FRESH: String = "#98cbe6"
const W_SEA: Array = ["#5c9cd5", "#4886c9", "#3b72b9", "#3060a6", "#284e92"]



static func settings_for(seed_v: int) -> WorldSettings:
	var s: = WorldSettings.new()
	s.world_seed = seed_v
	s.size = int(GameConfig.SIZES[clampi(GameConfig.size_i, 0, GameConfig.SIZES.size() - 1)])
	var was: bool = GameConfig.tutorial
	GameConfig.tutorial = false
	GameConfig.apply_map(s)
	GameConfig.tutorial = was
	s.world_seed = seed_v
	if s.lakes < 0:
		s.lakes = maxi(2, s.size / 256 + 1)
	s.layout_size = s.size
	s.size = GEN
	return s



static func build(s: WorldSettings) -> Image:
	var d: WorldData = WorldGen.generate(s)
	return render(d)


static func _c(hex: String) -> Color:
	return Color.html(hex)



static func render(d: WorldData, n: int = PX, thumb: bool = false) -> Image:
	var k: int = maxi(1, d.w / n)
	var w: int = d.w
	var lake: = PackedByteArray()
	lake.resize(d.w * d.h)
	for e: Array in d.lakes:
		var r: Rect2i = e[0]
		var m: PackedByteArray = e[1]
		for y in r.size.y:
			for x in r.size.x:
				if m[y * r.size.x + x] == 1:
					lake[(r.position.y + y) * w + r.position.x + x] = 1

	var cls: = PackedByteArray()
	cls.resize(n * n)
	var bio: = PackedByteArray()
	bio.resize(n * n)
	var hgt: = PackedByteArray()
	hgt.resize(n * n)
	for py in n:
		for px in n:
			var fresh: int = 0
			var sea: int = 0
			for t in k:
				for q: Vector2i in [Vector2i(px * k + t, py * k + t), Vector2i(px * k + k - 1 - t, py * k + t)]:
					var i: int = q.y * w + q.x
					var b: int = d.biome[i]
					if b == Biome.RIVER or lake[i] == 1:
						fresh += 1
					elif b <= Biome.COAST:
						sea += 1
			var ci: int = (py * k + k / 2) * w + px * k + k / 2
			var o: int = py * n + px
			bio[o] = d.biome[ci]
			hgt[o] = d.height[ci]
			if fresh > 0 and sea < k * 2 - 1:
				cls[o] = 2
			elif sea > k:
				cls[o] = 0
			else:
				cls[o] = 1
	var img: = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for py in n:
		for px in n:
			var o: int = py * n + px
			var c: int = cls[o]
			var near_land: bool = false
			var near_sea: bool = false
			for dd: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var qx: int = px + dd.x
				var qy: int = py + dd.y
				if qx < 0 or qy < 0 or qx >= n or qy >= n:
					continue
				var c2: int = cls[qy * n + qx]
				if c2 != 0:
					near_land = true
				else:
					near_sea = true
			var col: Color
			if c == 0:
				if near_land:
					col = _c(W_FOAM)
				else:
					var near2: bool = false
					for dd2: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
						var qx2: int = clampi(px + dd2.x, 0, n - 1)
						var qy2: int = clampi(py + dd2.y, 0, n - 1)
						if cls[qy2 * n + qx2] != 0:
							near2 = true
							break
					if near2 and not thumb:
						col = _c(W_NEAR)
					else:
						var dep: int = d.sea_level - int(hgt[o])
						col = _c(W_SEA[0 if dep <= 6 else (1 if dep <= 16 else (2 if dep <= 28 else (3 if dep <= 44 else 4)))])
			elif c == 2:
				col = _c(W_FRESH)
			else:
				var ramp: Array = C_GRASS
				match int(bio[o]):
					Biome.SAND:
						ramp = C_SAND
					Biome.FOREST:
						ramp = C_FOREST
					Biome.PINE:
						ramp = C_PINE
					Biome.STEPPE:
						ramp = C_STEPPE
					Biome.HILLS:
						ramp = C_HILLS
					Biome.ROCK:
						ramp = C_ROCK
					Biome.SNOW:
						ramp = C_SNOW
				if near_sea and ramp != C_ROCK and ramp != C_SNOW and ( not thumb or (bio[o] == Biome.SAND or (py + px) % 3 == 0)):
					ramp = C_SAND
				var nw: int = int(hgt[maxi(0, py - 1) * n + maxi(0, px - 1)])
				var sl: int = int(hgt[o]) - nw
				col = _c(ramp[2 if sl >= 3 else (0 if sl <= -3 else 1)])
			img.set_pixel(px, py, col)
	return img
