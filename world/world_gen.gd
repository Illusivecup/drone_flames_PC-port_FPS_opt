class_name WorldGen
extends RefCounted




const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func generate(s: WorldSettings) -> WorldData:
	var t0: int = Time.get_ticks_msec()
	var w: int = s.size
	var h: int = s.size
	var world: = WorldData.new(w, h, s.world_seed)
	var n: int = w * h
	var sd: int = s.world_seed


	var relief: = PackedInt32Array()
	relief.resize(n)
	var cells: Array = [w / 4, w / 8, w / 16, w / 32, w / 64, w / 128]
	var weights: Array = [10, 7, 5, 3, 2, 1]
	var wsum: int = 0
	for k in cells.size():
		var c: int = maxi(2, int(cells[k]))
		var wt: int = int(weights[k])
		var layer: PackedByteArray = _noise_layer(w, h, c, sd + k * 1013)
		wsum += wt
		for i in n:
			relief[i] += layer[i] * wt


	var mask: PackedByteArray = _continent_mask(s, w, h)


	var margin: int = maxi(8, w / 14)
	var rk: int = 6 if s.map_type == 1 else 5
	var mk: int = 12 - rk
	var hist: = PackedInt32Array()
	hist.resize(256)
	for y in h:
		var ey: int = mini(y, h - 1 - y)
		for x in w:
			var i: int = y * w + x
			var v: int = (relief[i] / wsum * rk + mask[i] * mk) / 12
			var e: int = mini(mini(x, w - 1 - x), ey)
			if e < margin:
				v -= (margin - e) * 140 / margin
			v = clampi(v, 0, 255)
			world.height[i] = v
			hist[v] += 1


	var target: int = n * s.land_percent / 100
	var acc: int = 0
	var sea: int = 255
	while sea > 0 and acc + hist[sea] < target:
		acc += hist[sea]
		sea -= 1
	world.sea_level = sea

	if s.map_type == 2 or s.map_type == 3:
		_cut_channels(world, s)


	var land_total: int = 0
	for v in range(sea, 256):
		land_total += hist[v]
	var rock_thr: int = _quantile_from_top(hist, sea, land_total * s.mountains / 1000)
	var hills_thr: int = _quantile_from_top(hist, sea, land_total * s.mountains * 24 / 10000)
	var snow_thr: int = _quantile_from_top(hist, sea, land_total * s.mountains * 3 / 10000)
	if s.mountains == 0:
		rock_thr = 256
		hills_thr = 256
		snow_thr = 256
	world.hills_thr = hills_thr
	world.gen_version = s.gen_version


	var m1: PackedByteArray = _noise_layer(w, h, maxi(2, w / 8), sd + 7777)
	var m2: PackedByteArray = _noise_layer(w, h, maxi(2, w / 32), sd + 8888)
	var m3: PackedByteArray = _noise_layer(w, h, maxi(2, w / 128), sd + 9999)
	var forest_thr: int = 218 - s.forests * 12 / 10
	var steppe_thr: int = 92 + (50 - s.forests) / 3


	for i in n:
		var v: int = world.height[i]
		var b: int = Biome.GRASS
		if v < sea:
			var d: int = sea - v
			if d > 40:
				b = Biome.DEEP
			elif d > 16:
				b = Biome.OCEAN
			elif d > 6:
				b = Biome.SHALLOW
			else:
				b = Biome.COAST
		elif v >= snow_thr:
			b = Biome.SNOW
		elif v >= rock_thr:
			b = Biome.ROCK
		elif v - sea <= 2:
			b = Biome.SAND
		else:
			var moist: int = (m1[i] * 4 + m2[i] * 2 + m3[i] * 2) / 8
			if v >= hills_thr:
				b = Biome.PINE if moist >= forest_thr - 20 else Biome.HILLS
			elif moist >= forest_thr:
				b = Biome.PINE if moist >= forest_thr + 34 else Biome.FOREST
			elif moist < steppe_thr:
				b = Biome.STEPPE
		world.biome[i] = b


	if s.gen_version >= 2:
		WorldGen2.rivers(world, s, hills_thr, snow_thr)
	else:
		_rivers(world, s, hills_thr, snow_thr)
	
	if s.map_type >= 4:
		var custom_idx: int = s.map_type - 4
		var custom_maps: Array = GameConfig.custom_maps_cache
		if custom_maps.is_empty():
			var loop = Engine.get_main_loop()
			if loop != null and "root" in loop and loop.root != null and loop.root.has_node("ModManager"):
				var mm = loop.root.get_node("ModManager")
				custom_maps = mm.get_custom_map_types()
		if custom_idx >= 0 and custom_idx < custom_maps.size():
			var gen_fn = custom_maps[custom_idx].get("generator")
			if gen_fn is Callable and gen_fn.is_valid():
				gen_fn.call(world, s)
	
	print("[WorldGen] %dx%d seed=%d sea=%d in %d ms" % [w, h, sd, sea, Time.get_ticks_msec() - t0])
	return world



static func _noise_layer(w: int, h: int, cell: int, s: int) -> PackedByteArray:
	var gw: int = w / cell + 2
	var gh: int = h / cell + 2
	var data: = PackedByteArray()
	data.resize(gw * gh)
	for y in gh:
		for x in gw:
			data[y * gw + x] = Hash32.h2(x, y, s) & 255
	var img: = Image.create_from_data(gw, gh, false, Image.FORMAT_L8, data)
	img.resize(gw * cell, gh * cell, Image.INTERPOLATE_BILINEAR)
	var off: int = cell / 2
	return img.get_region(Rect2i(off, off, w, h)).get_data()


static func _continent_mask(s: WorldSettings, w: int, h: int) -> PackedByteArray:
	if s.map_type == 1 or s.map_type == 2 or s.map_type == 3:
		return _type_mask(s, w, h)

	var lw: int = maxi(32, (s.layout_size if s.layout_size > 0 else w) / 8)
	var lh: int = maxi(32, (s.layout_size if s.layout_size > 0 else h) / 8)
	var rng: = Rng.new(s.world_seed * 7 + 3)
	var blobs: Array = []
	var area: float = float(lw * lh) * float(s.land_percent) / 100.0
	var base_r: int = maxi(4, int(sqrt(area / (PI * float(s.continents))) * 1.25))
	for c in s.continents:
		var cx: int = rng.range_ab(lw * 22 / 100, lw * 78 / 100)
		var cy: int = rng.range_ab(lh * 22 / 100, lh * 78 / 100)
		var rx: int = maxi(3, base_r * rng.range_ab(80, 125) / 100)
		var ry: int = maxi(3, base_r * rng.range_ab(70, 115) / 100)
		blobs.append([cx, cy, rx, ry, 255])

		for k in 4:
			var ox: int = cx + rng.range_ab( - rx, rx) * 8 / 10
			var oy: int = cy + rng.range_ab( - ry, ry) * 8 / 10
			blobs.append([ox, oy, maxi(2, rx * rng.range_ab(35, 65) / 100), maxi(2, ry * rng.range_ab(35, 65) / 100), 235])
	var isl: int = s.islands * (s.continents + 2) / 14
	for k in isl:
		var r: int = maxi(2, base_r * rng.range_ab(8, 22) / 100)
		blobs.append([rng.range_ab(lw / 10, lw * 9 / 10), rng.range_ab(lh / 10, lh * 9 / 10), r, r * rng.range_ab(70, 130) / 100, 215])
	var data: = PackedByteArray()
	data.resize(lw * lh)

	var warp_x: PackedByteArray = _noise_layer(lw, lh, maxi(2, lw / 6), s.world_seed + 5151)
	var warp_y: PackedByteArray = _noise_layer(lw, lh, maxi(2, lw / 6), s.world_seed + 6161)
	var warp_x2: PackedByteArray = _noise_layer(lw, lh, maxi(2, lw / 20), s.world_seed + 7171)
	var warp_y2: PackedByteArray = _noise_layer(lw, lh, maxi(2, lw / 20), s.world_seed + 8181)
	var amp: int = maxi(2, base_r * 40 / 100)
	var amp2: int = maxi(1, base_r * 12 / 100)
	for y in lh:
		for x in lw:
			var best: int = 0
			var wi: int = y * lw + x
			var sx: int = x + (int(warp_x[wi]) - 128) * amp / 128 + (int(warp_x2[wi]) - 128) * amp2 / 128
			var sy: int = y + (int(warp_y[wi]) - 128) * amp / 128 + (int(warp_y2[wi]) - 128) * amp2 / 128
			for bl in blobs:
				var dx: int = (sx - int(bl[0])) * 1000 / int(bl[2])
				var dy: int = (sy - int(bl[1])) * 1000 / maxi(1, int(bl[3]))
				var d2: int = dx * dx + dy * dy
				if d2 < 1000000:
					var val: int = (1000000 - d2) / 1000 * int(bl[4]) / 1000
					if val > best:
						best = val
			data[y * lw + x] = best
	var img: = Image.create_from_data(lw, lh, false, Image.FORMAT_L8, data)
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return img.get_data()








static func _type_mask(s: WorldSettings, w: int, h: int) -> PackedByteArray:
	var lw: int = maxi(32, (s.layout_size if s.layout_size > 0 else w) / 8)
	var lh: int = maxi(32, (s.layout_size if s.layout_size > 0 else h) / 8)
	var rng: = Rng.new(s.world_seed * 7 + 3 + s.map_type * 1013)
	var blobs: Array = []
	var warp_pct: int = 40
	var amp2_pct: int = 12
	var base_r: int = 4
	var off: int = lw * 9 / 100
	var ls: int = s.layout_size if s.layout_size > 0 else w
	var span: int = lw - off * 2
	match s.map_type:
		1:


			var g: int = 3 if ls <= 512 else (4 if ls <= 1024 else 5)
			var slot: int = span / g
			base_r = maxi(3, slot * 30 / 100)
			warp_pct = 40
			amp2_pct = 22
			var order: Array = range(g * g)
			for i in range(order.size() - 1, 0, -1):
				var j: int = rng.range_i(i + 1)
				var tmp: Variant = order[i]
				order[i] = order[j]
				order[j] = tmp
			var big_n: int = maxi(4, g * g / 2)
			for oi in order.size():
				var gx: int = int(order[oi]) % g
				var gy: int = int(order[oi]) / g
				var cx: int = off + gx * slot + slot / 2 + rng.range_ab( - slot * 16 / 100, slot * 16 / 100)
				var cy: int = off + gy * slot + slot / 2 + rng.range_ab( - slot * 16 / 100, slot * 16 / 100)
				var kind: int = 0 if oi < big_n else rng.range_i(4)
				var ang: int = rng.range_i(360)
				var dx: int = WorldGen2.icos(ang)
				var dy: int = WorldGen2.isin(ang)
				match kind:
					0:
						var r: int = maxi(3, slot * rng.range_ab(28, 40) / 100)
						var rx: int = maxi(3, r * rng.range_ab(65, 140) / 100)
						var ry: int = maxi(3, r * r / rx)
						blobs.append([cx, cy, rx, ry, 255])
						for k in rng.range_ab(3, 5):
							blobs.append([cx + rng.range_ab( - rx, rx) * 8 / 10, cy + rng.range_ab( - ry, ry) * 8 / 10, maxi(2, rx * rng.range_ab(30, 60) / 100), maxi(2, ry * rng.range_ab(30, 60) / 100), 234])
						for k in 2:
							var dd: int = r * (85 + k * 40) / 100
							blobs.append([cx + dx * dd / 4096, cy + dy * dd / 4096, maxi(2, r * (34 - k * 10) / 100), maxi(2, r * (26 - k * 8) / 100), 226])
					1:
						var n: int = rng.range_ab(3, 5)
						var stp: int = maxi(2, slot * rng.range_ab(13, 19) / 100)
						for k in n:
							var o: int = (k * 2 - (n - 1)) * stp / 2
							var rr: int = maxi(2, slot * rng.range_ab(8, 17) / 100)
							blobs.append([cx + dx * o / 4096, cy + dy * o / 4096, rr, maxi(2, rr * rng.range_ab(60, 120) / 100), 240])
					2:
						for k in 2:
							var rr2: int = maxi(2, slot * rng.range_ab(13, 23) / 100)
							blobs.append([cx + rng.range_ab( - slot / 5, slot / 5), cy + rng.range_ab( - slot / 5, slot / 5), rr2, maxi(2, rr2 * rng.range_ab(60, 140) / 100), 245])
					_:
						for k in rng.range_ab(2, 4):
							var rr3: int = maxi(1, slot * rng.range_ab(5, 9) / 100)
							blobs.append([cx + rng.range_ab( - slot / 3, slot / 3), cy + rng.range_ab( - slot / 3, slot / 3), rr3, rr3, 220])
			for k in g * g * 2:
				var r2: int = maxi(1, slot * rng.range_ab(4, 9) / 100)
				blobs.append([off + rng.range_i(span), off + rng.range_i(span), r2, r2, 212])
		2:
			var cols: int = 3 if ls >= 2048 else 2
			var rows: int = 2
			var sw: int = span / cols
			var sh: int = (lh - off * 2) / rows
			base_r = mini(sw, sh) * 34 / 100
			warp_pct = 34
			for gy in rows:
				for gx in cols:
					var cx: int = off + gx * sw + sw / 2 + rng.range_ab( - sw / 10, sw / 10)
					var cy: int = off + gy * sh + sh / 2 + rng.range_ab( - sh / 10, sh / 10)
					var rx: int = sw * rng.range_ab(30, 38) / 100
					var ry: int = sh * rng.range_ab(30, 38) / 100
					blobs.append([cx, cy, rx, ry, 255])
					for k in 4:
						blobs.append([cx + rng.range_ab( - rx, rx) * 7 / 10, cy + rng.range_ab( - ry, ry) * 7 / 10, maxi(2, rx * rng.range_ab(38, 60) / 100), maxi(2, ry * rng.range_ab(38, 60) / 100), 236])
			for k in 6:
				var r3: int = maxi(1, base_r * rng.range_ab(8, 16) / 100)
				blobs.append([off + rng.range_i(span), off + rng.range_i(span), r3, r3, 212])
		3:

			var lines: Array = _chan_lines(s)
			if not lines.is_empty():
				var ln: Array = lines[0]
				var c: int = WorldGen2.icos(int(ln[2]))
				var sn: int = WorldGen2.isin(int(ln[2]))
				base_r = lw * 20 / 100
				warp_pct = 44
				amp2_pct = 20
				for side: int in [-1, 1]:
					var cx: int = lw / 2 - side * sn * lw * 24 / 100 / 4096
					var cy: int = lh / 2 + side * c * lh * 24 / 100 / 4096
					var ra: int = lw * rng.range_ab(28, 35) / 100
					var rb: int = lw * rng.range_ab(13, 17) / 100
					var rx: int = (absi(c) * ra + absi(sn) * rb) / 4096
					var ry: int = (absi(sn) * ra + absi(c) * rb) / 4096
					blobs.append([cx, cy, maxi(4, rx), maxi(4, ry), 255])
					for k in 7:
						blobs.append([cx + rng.range_ab( - rx, rx) * 8 / 10, cy + rng.range_ab( - ry, ry) * 8 / 10, maxi(3, rx * rng.range_ab(30, 60) / 100), maxi(3, ry * rng.range_ab(30, 60) / 100), 236])
					for k in 2:
						var ang: int = int(ln[2]) + (90 if side > 0 else 270) + rng.range_ab(-60, 60)
						var dd: int = maxi(rx, ry) * rng.range_ab(80, 105) / 100
						blobs.append([cx + WorldGen2.icos(ang) * dd / 4096, cy + WorldGen2.isin(ang) * dd / 4096, maxi(2, ra * rng.range_ab(14, 24) / 100), maxi(2, ra * rng.range_ab(10, 18) / 100), 226])
				for k in 5:
					var r4: int = maxi(1, base_r * rng.range_ab(6, 14) / 100)
					blobs.append([off + rng.range_i(span), off + rng.range_i(span), r4, r4, 210])
		_:
			pass
	var data: = PackedByteArray()
	data.resize(lw * lh)
	var warp_x: PackedByteArray = _noise_layer(lw, lh, maxi(2, lw / 6), s.world_seed + 5151)
	var warp_y: PackedByteArray = _noise_layer(lw, lh, maxi(2, lw / 6), s.world_seed + 6161)
	var warp_x2: PackedByteArray = _noise_layer(lw, lh, maxi(2, lw / 20), s.world_seed + 7171)
	var warp_y2: PackedByteArray = _noise_layer(lw, lh, maxi(2, lw / 20), s.world_seed + 8181)
	var amp: int = maxi(2, base_r * warp_pct / 100)
	var amp2: int = maxi(1, base_r * amp2_pct / 100)
	var lines2: Array = _chan_lines(s)
	for y in lh:
		for x in lw:
			var best: int = 0
			var wi: int = y * lw + x
			var sx: int = x + (int(warp_x[wi]) - 128) * amp / 128 + (int(warp_x2[wi]) - 128) * amp2 / 128
			var sy: int = y + (int(warp_y[wi]) - 128) * amp / 128 + (int(warp_y2[wi]) - 128) * amp2 / 128
			for bl: Array in blobs:
				var ex: int = sx - int(bl[0])
				var ey: int = sy - int(bl[1])
				if absi(ex) >= int(bl[2]) or absi(ey) >= int(bl[3]):
					continue
				var dx: int = ex * 1000 / maxi(1, int(bl[2]))
				var dy: int = ey * 1000 / maxi(1, int(bl[3]))
				var d2: int = dx * dx + dy * dy
				if d2 < 1000000:
					var val: int = (1000000 - d2) / 1000 * int(bl[4]) / 1000
					if val > best:
						best = val
			if not lines2.is_empty() and best > 0:
				var cd: int = _chan_dist(lines2, (x * 2 + 1) * 512 / lw, (y * 2 + 1) * 512 / lh, s.world_seed)
				if cd < CHAN_FADE:
					best = best * maxi(0, cd - CHAN_HALF) / (CHAN_FADE - CHAN_HALF)
			data[y * lw + x] = best
	var img: = Image.create_from_data(lw, lh, false, Image.FORMAT_L8, data)
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return img.get_data()




const CHAN_HALF: int = 30
const CHAN_FADE: int = 70
const CHAN_SINK: int = 24



static func _chan_lines(s: WorldSettings) -> Array:
	var r: = Rng.new(s.world_seed * 13 + 17)
	if s.map_type == 3:
		var a: int = [90, 0, 45, 135][r.range_i(4)] + r.range_ab(-10, 10)
		return [[512 + r.range_ab(-40, 40), 512 + r.range_ab(-40, 40), a, 1, 85]]
	if s.map_type == 2:
		var out: Array = [[512, 512 + r.range_ab(-24, 24), 0, 2, 34]]
		if (s.layout_size if s.layout_size > 0 else s.size) >= 2048:
			out.append([352 + r.range_ab(-20, 20), 512, 90, 3, 24])
			out.append([672 + r.range_ab(-20, 20), 512, 90, 4, 24])
		else:
			out.append([512 + r.range_ab(-24, 24), 512, 90, 3, 34])
		return out
	return []



static func _chan_dist(lines: Array, ux: int, uy: int, sd: int) -> int:
	var best: int = 1 << 30
	for ln: Array in lines:
		var c: int = WorldGen2.icos(int(ln[2]))
		var sn: int = WorldGen2.isin(int(ln[2]))
		var dx: int = ux - int(ln[0])
		var dy: int = uy - int(ln[1])
		var along: int = (dx * c + dy * sn) / 4096 + 4096
		var across: int = (dy * c - dx * sn) / 4096
		var i0: int = along / 150
		var f: int = (along - i0 * 150) * 256 / 150
		f = f * f * (768 - 2 * f) / 65536
		var a0: int = (Hash32.h2(i0, int(ln[3]), sd) & 127) - 64
		var a1: int = (Hash32.h2(i0 + 1, int(ln[3]), sd) & 127) - 64
		var wv: int = (a0 * 256 + (a1 - a0) * f) / 256


		var bamp: int = int(ln[4]) if ln.size() > 4 else 0
		var j0: int = along / 520
		var g: int = (along - j0 * 520) * 256 / 520
		g = g * g * (768 - 2 * g) / 65536
		var b0: int = (Hash32.h2(j0, int(ln[3]) + 50, sd) & 255) - 128
		var b1: int = (Hash32.h2(j0 + 1, int(ln[3]) + 50, sd) & 255) - 128
		var bend: int = (b0 * 256 + (b1 - b0) * g) / 256 * bamp / 128
		var k0: int = along / 46
		var q: int = (along - k0 * 46) * 256 / 46
		var f0: int = (Hash32.h2(k0, int(ln[3]) + 90, sd) & 15) - 8
		var f1: int = (Hash32.h2(k0 + 1, int(ln[3]) + 90, sd) & 15) - 8
		var fw: int = (f0 * 256 + (f1 - f0) * q) / 256
		var m0: int = along / 230
		var wid: int = ((Hash32.h2(m0, int(ln[3]) + 70, sd) & 31) - 16) * (1 if bamp > 0 else 0)
		best = mini(best, absi(across - wv * 3 / 4 - bend - fw) - wid)
	return best




static func _cut_channels(world: WorldData, s: WorldSettings) -> void :
	var lines: Array = _chan_lines(s)
	if lines.is_empty():
		return
	var w: int = world.w
	var h: int = world.h
	var deep: int = maxi(0, world.sea_level - 22)
	for by in range(0, h, 4):
		for bx in range(0, w, 4):
			if _chan_dist(lines, (bx + 2) * 1024 / w, (by + 2) * 1024 / h, s.world_seed) >= CHAN_SINK:
				continue
			for y in range(by, mini(h, by + 4)):
				for x in range(bx, mini(w, bx + 4)):
					var i: int = y * w + x
					if world.height[i] > deep:
						world.height[i] = deep


static func _quantile_from_top(hist: PackedInt32Array, sea: int, count: int) -> int:
	var acc: int = 0
	var v: int = 255
	while v > sea and acc + hist[v] < count:
		acc += hist[v]
		v -= 1
	return v + 1 if count > 0 else 256


static func _rivers(world: WorldData, s: WorldSettings, hills_thr: int, snow_thr: int) -> void :
	if s.rivers <= 0:
		return
	var w: int = world.w
	var st: int = 4
	var cw: int = w / st
	var ch: int = world.h / st
	var rng: = Rng.new(s.world_seed + 4242)
	var sources: Array[Vector2i] = []
	var min_d: int = maxi(8, cw / 14)
	var src_low: int = mini(hills_thr - 14, world.sea_level + (255 - world.sea_level) / 3)
	for tries in s.rivers * 60:
		if sources.size() >= s.rivers:
			break
		var p: = Vector2i(rng.range_ab(2, cw - 3), rng.range_ab(2, ch - 3))
		var v: int = world.height[(p.y * st + 2) * w + p.x * st + 2]
		if v < src_low or v >= snow_thr:
			continue
		var ok: bool = true
		for q in sources:
			if absi(q.x - p.x) + absi(q.y - p.y) < min_d:
				ok = false
				break
		if ok:
			sources.append(p)


	var dist: = PackedInt32Array()
	dist.resize(cw * ch)
	dist.fill(1 << 20)
	var queue: Array[Vector2i] = []
	for y in ch:
		for x in cw:
			if Biome.is_water(world.biome[(y * st + 2) * w + x * st + 2]):
				dist[y * cw + x] = 0
				queue.append(Vector2i(x, y))
	var head: int = 0
	while head < queue.size():
		var q: Vector2i = queue[head]
		head += 1
		var dq: int = dist[q.y * cw + q.x] + 1
		for d in DIRS4:
			var nb: Vector2i = q + d
			if nb.x < 0 or nb.y < 0 or nb.x >= cw or nb.y >= ch:
				continue
			if dist[nb.y * cw + nb.x] > dq:
				dist[nb.y * cw + nb.x] = dq
				queue.append(nb)
	for src in sources:
		if dist[src.y * cw + src.x] < 8:
			continue
		var path: Array[Vector2i] = [src]
		var cur: Vector2i = src
		var seen: Dictionary = {src: true}
		var flat_run: int = 0
		for step in 2000:
			var cd: int = dist[cur.y * cw + cur.x]
			if cd == 0:
				break
			var best: = Vector2i(-1, -1)
			var bv: int = 1 << 30
			for d in DIRS4:
				var nb: Vector2i = cur + d
				if nb.x < 0 or nb.y < 0 or nb.x >= cw or nb.y >= ch or seen.has(nb):
					continue
				var nd: int = dist[nb.y * cw + nb.x]
				if nd > cd or (nd == cd and flat_run >= 3):
					continue

				var nv: int = world.height[(nb.y * st + 2) * w + nb.x * st + 2] + (Hash32.h2(nb.x / 3, nb.y / 3, s.world_seed + step / 6) & 127) + (40 if nd == cd else 0)
				if nv < bv:
					bv = nv
					best = nb
			if best.x < 0:
				break
			flat_run = flat_run + 1 if dist[best.y * cw + best.x] == cd else 0
			path.append(best)
			seen[best] = true
			cur = best

		var pts: Array[Vector2] = []
		for q: Vector2i in path:
			pts.append(Vector2(q * st) + Vector2(2 + (Hash32.h2(q.x, q.y, 11) & 1), 2 + (Hash32.h2(q.x, q.y, 12) & 1)))
		pts = _chaikin(_chaikin(pts))
		var total: int = pts.size()
		var prev: = Vector2i(-99999, -99999)
		for i in total - 1:
			var width: int = 1 if i < total / 6 else 2
			if i > total / 2:
				width = 3
			if total > 280 and i > total * 85 / 100:
				width = 4
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var steps: int = int(maxf(absf(b.x - a.x), absf(b.y - a.y)) * 2.0) + 1
			for t in steps + 1:
				var p: Vector2 = a.lerp(b, float(t) / float(steps))
				var cc: = Vector2i(floori(p.x), floori(p.y))
				if cc == prev:
					continue
				if prev.x > -99999 and cc.x != prev.x and cc.y != prev.y:
					_stamp(world, Vector2i(prev.x, cc.y), width)
				_stamp(world, cc, width)
				prev = cc


static func _chaikin(pts: Array[Vector2]) -> Array[Vector2]:
	if pts.size() < 3:
		return pts
	var out: Array[Vector2] = [pts[0]]
	for i in pts.size() - 1:
		out.append(pts[i].lerp(pts[i + 1], 0.25))
		out.append(pts[i].lerp(pts[i + 1], 0.75))
	out.append(pts[pts.size() - 1])
	return out


static func _stamp(world: WorldData, c: Vector2i, width: int) -> void :
	var o: int = width / 2
	for oy in width:
		for ox in width:
			_set_water(world, c.x + ox - o, c.y + oy - o, Biome.RIVER)


static func _river_line(world: WorldData, a: Vector2i, b: Vector2i, width: int) -> void :
	var x: int = a.x
	var y: int = a.y
	var sx: int = signi(b.x - a.x)
	var sy: int = signi(b.y - a.y)
	while true:
		for oy in width:
			for ox in width:
				_set_water(world, x + ox, y + oy, Biome.RIVER)
		if x != b.x:
			x += sx
		elif y != b.y:
			y += sy
		else:
			break


static func _set_water(world: WorldData, x: int, y: int, b: int) -> void :
	if not world.inside(x, y):
		return
	var i: int = y * world.w + x
	if Biome.is_water(world.biome[i]):
		return
	world.biome[i] = b
	world.height[i] = maxi(0, world.sea_level - 3)
