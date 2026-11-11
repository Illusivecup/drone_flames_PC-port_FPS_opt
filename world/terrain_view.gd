class_name TerrainView
extends Sprite2D

















signal cells_changed(cells: Array)

const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const PAL_PATH: String = "res://assets/palettes/terrain19.json"
const BANDS: int = 16

const NF_SEA: int = 1
const NF_FRESH: int = 2
const NF_ROCK: int = 4
const NF_LAND: int = 8
const NF_MIX: int = 16
const NF_FX: int = 32
const NF_LAKE: int = 64

const S_WIG: int = 4
const S_DSP: int = 3
const R2X: Array[int] = [2, -2, 0, 0, 1, -1, 1, -1]
const R2Y: Array[int] = [0, 0, 2, -2, 1, 1, -1, -1]

var world: WorldData
var image: Image
var tex: ImageTexture
var colors: Array = []
var pal: Dictionary = {}
var ramps: Array = []
var ramp_base: = PackedInt32Array()
var ramp_spread: = PackedInt32Array()
var water: = PackedInt64Array()
var near: = PackedByteArray()
var bw: int = 0
var bh: int = 0
var build_ms: int = 0
var threads: int = 4
var depth16: = PackedInt32Array()

var _rnd: = PackedByteArray()
var _lat_s: = PackedInt32Array()
var _rflat: = PackedInt64Array()
var _rlen: = PackedInt32Array()
var _bands: Array = []
var _blk_bands: Array = []
var _sd: int = 0
var _flag_of: = PackedByteArray()
var _mask_of: = PackedByteArray()
var _base16: = PackedInt32Array()


func _init() -> void :
	centered = false
	scale = Vector2(4, 4)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if OS.has_feature("mobile") or OS.get_name() == "Android":
		threads = clampi(OS.get_processor_count() - 1, 2, 4)
	else:
		threads = clampi(OS.get_processor_count(), 1, 8)


func _load_colors() -> void :
	var f: = FileAccess.open("res://assets/palettes/terrain_colors.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	colors.clear()
	for key: String in Biome.KEYS:
		var arr: Array = d[key]
		var row: = PackedInt64Array()
		for hex: String in arr:
			var c: = Color.html(hex)
			row.append(c.r8 | (c.g8 << 8) | (c.b8 << 16) | (255 << 24))
		colors.append(row)


static func rgba(hex: String) -> int:
	var c: = Color.html(hex)
	return c.r8 | (c.g8 << 8) | (c.b8 << 16) | (255 << 24)


func _load_palette() -> void :
	var f: = FileAccess.open(PAL_PATH, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var cd: Dictionary = d["colors"]
	for k: String in cd:
		pal[k] = rgba(String(cd[k]))
	var rd: Dictionary = d["ramps"]
	ramps.clear()
	ramps.resize(32)
	ramp_base.resize(32)
	ramp_spread.resize(32)
	var by_biome: Dictionary = {Biome.GRASS: "grass", Biome.FOREST: "forest", Biome.PINE: "pine", Biome.STEPPE: "steppe", Biome.SAND: "sand", Biome.HILLS: "hills", Biome.ROCK: "rock", Biome.SNOW: "snow"}
	for b: int in by_biome:
		var e: Array = rd[by_biome[b]]
		var row: = PackedInt64Array()
		for n: String in e[0]:
			row.append(int(pal[n]))
		ramps[b] = row
		ramp_base[b] = int(e[1])
		ramp_spread[b] = int(e[2])
	_rflat.resize(32 * 8)
	_rlen.resize(32)
	for b: int in by_biome:
		var row: PackedInt64Array = ramps[b]
		_rlen[b] = row.size()
		for t in row.size():
			_rflat[b * 8 + t] = row[t]
	water = PackedInt64Array()
	for n: String in (rd["water"] as Array)[0]:
		water.append(int(pal[n]))
	_flag_of.resize(32)
	_mask_of.resize(32)
	_base16.resize(32)
	for b in 32:
		var fb: int = 0
		if b <= Biome.COAST:
			fb = NF_SEA
		elif b == Biome.RIVER:
			fb = NF_FRESH
		else:
			fb = NF_LAND
			if b == Biome.ROCK or b == Biome.SNOW:
				fb |= NF_ROCK
		_flag_of[b] = fb
		_mask_of[b] = (1 << (b - Biome.SAND)) if _paintable(b) else 0
		_base16[b] = ramp_base[b] * 16 + 8
	depth16.resize(64)
	for d2 in 64:
		depth16[d2] = 16 + WorldGen2.isqrt(maxi(0, d2 - 1) * 484)




func build(w: WorldData) -> void :
	var t0: int = Time.get_ticks_msec()
	world = w
	if colors.is_empty():
		_load_colors()
	if pal.is_empty():
		_load_palette()
	_sd = w.world_seed

	_rnd.resize(65536)
	var lcg: int = (_sd * 2654435761 + 12345) & 2147483647
	for k in 65536:
		lcg = (lcg * 1103515245 + 12345) & 2147483647
		_rnd[k] = (lcg >> 16) & 255
	_lat_s = PackedInt32Array([maxi(8, w.w / 44), maxi(4, w.w / 150), S_WIG, S_DSP])
	var nthreads: int = threads if w.h >= BANDS * 4 else 1

	bw = (w.w + 3) / 4
	bh = (w.h + 3) / 4
	_blk_bands.clear()
	_blk_bands.resize(BANDS)
	_run(_blocks_band, nthreads)
	var blk2: = PackedByteArray()
	for k in BANDS:
		blk2.append_array(_blk_bands[k])
	_blk_bands.clear()
	var blk: = PackedByteArray()
	blk.resize(bw * bh)
	var bmask: = PackedByteArray()
	bmask.resize(bw * bh)
	for j in bw * bh:
		blk[j] = blk2[j * 2]
		bmask[j] = blk2[j * 2 + 1]
	for e: Array in w.lakes:
		var r: Rect2i = e[0]
		for by in range(r.position.y / 4, (r.end.y + 3) / 4):
			for bx in range(r.position.x / 4, (r.end.x + 3) / 4):
				if bx < bw and by < bh:
					blk[by * bw + bx] |= NF_LAKE
	for i: int in w.fx_cells:
		var bi: int = (i / w.w / 4) * bw + (i % w.w) / 4
		blk[bi] |= NF_FX

	var hf: = PackedByteArray()
	var hm: = PackedByteArray()
	hf.resize(bw * bh)
	hm.resize(bw * bh)
	for by in bh:
		var r: int = by * bw
		for bx in bw:
			var j: int = r + bx
			var f: int = blk[j]
			var m: int = bmask[j]
			if bx > 0:
				f |= blk[j - 1]
				m |= bmask[j - 1]
			if bx + 1 < bw:
				f |= blk[j + 1]
				m |= bmask[j + 1]
			hf[j] = f
			hm[j] = m
	near = PackedByteArray()
	near.resize(bw * bh)
	for by in bh:
		var r: int = by * bw
		for bx in bw:
			var j: int = r + bx
			var f: int = hf[j]
			var m: int = hm[j]
			if by > 0:
				f |= hf[j - bw]
				m |= hm[j - bw]
			if by + 1 < bh:
				f |= hf[j + bw]
				m |= hm[j + bw]
			if (m & (m - 1)) != 0:
				f |= NF_MIX
			near[j] = f
	var t1: int = Time.get_ticks_msec()

	_bands.clear()
	_bands.resize(BANDS)
	_run(_bake_band, nthreads)
	var bytes: = PackedByteArray()
	for k in BANDS:
		bytes.append_array(_bands[k])
	_bands.clear()
	image = Image.create_from_data(w.w, w.h, false, Image.FORMAT_RGBA8, bytes)
	tex = ImageTexture.create_from_image(image)
	texture = tex
	build_ms = Time.get_ticks_msec() - t0
	print("[TerrainView] built %dx%d in %d ms (blocks %d ms, bake %d ms, %d threads)" % [w.w, w.h, build_ms, t1 - t0, Time.get_ticks_msec() - t1, nthreads])


func _run(fn: Callable, nthreads: int) -> void :
	if nthreads > 1:
		var tid: int = WorkerThreadPool.add_group_task(fn, BANDS, nthreads, true, "terrain bake")
		WorkerThreadPool.wait_for_group_task_completion(tid)
	else:
		for k in BANDS:
			fn.call(k)


func _blocks_band(k: int) -> void :
	var d: WorldData = world
	var w: int = d.w
	var by0: int = bh * k / BANDS
	var by1: int = bh * (k + 1) / BANDS
	var out: = PackedByteArray()
	out.resize((by1 - by0) * bw * 2)
	var bio: PackedByteArray = d.biome
	var ft: PackedByteArray = _flag_of
	var mt: PackedByteArray = _mask_of
	var fa: = PackedByteArray()
	var ma: = PackedByteArray()
	fa.resize(bw)
	ma.resize(bw)
	for by in range(by0, by1):
		fa.fill(0)
		ma.fill(0)
		for y in range(by * 4, mini(d.h, by * 4 + 4)):
			var row: int = y * w
			for x in w:
				var b: int = bio[row + x]
				fa[x >> 2] |= ft[b]
				ma[x >> 2] |= mt[b]
		var o: int = (by - by0) * bw * 2
		for bx in bw:
			out[o + bx * 2] = fa[bx]
			out[o + bx * 2 + 1] = ma[bx]
	_blk_bands[k] = out



func _lat_row(k: int, y: int, rnd: PackedByteArray) -> PackedInt32Array:
	var st: int = _lat_s[k]
	var lw: int = world.w / st + 3
	var ly: int = y / st
	var fy: int = y - ly * st
	var out: = PackedInt32Array()
	out.resize(lw)
	var r0: int = ((ly + k * 61) & 255) << 8
	var r1: int = ((ly + 1 + k * 61) & 255) << 8
	var ox: int = k * 97
	for lx in lw:
		var a: int = rnd[r0 | ((lx + ox) & 255)]
		out[lx] = a + (int(rnd[r1 | ((lx + ox) & 255)]) - a) * fy / st
	return out


func _bake_band(k: int) -> void :
	var w: int = world.w
	var y0: int = world.h * k / BANDS
	var y1: int = world.h * (k + 1) / BANDS
	var buf: = PackedInt32Array()
	buf.resize((y1 - y0) * w)
	var j: int = 0
	var s0: int = _lat_s[0]
	var s1: int = _lat_s[1]
	var bio: PackedByteArray = world.biome
	var hgt: PackedByteArray = world.height
	var hbase: int = maxi(0, y0 - 3) * w
	var hl: PackedByteArray = hgt.slice(hbase, mini(world.h, y1 + 3) * w)
	var nr: PackedByteArray = near
	var sea: int = world.sea_level
	var wat: PackedInt64Array = water
	var dep: PackedInt32Array = depth16
	var b16: PackedInt32Array = _base16
	var spr: PackedInt32Array = ramp_spread
	var rnd: PackedByteArray = _rnd.duplicate()
	var rf: PackedInt64Array = _rflat.duplicate()
	var rl: PackedInt32Array = _rlen.duplicate()
	const SLOW_SEA: int = NF_LAND | NF_LAKE | NF_FX
	const SLOW_LAND: int = NF_SEA | NF_FRESH | NF_LAKE | NF_ROCK | NF_FX
	var hh: int = world.h
	for y in range(y0, y1):
		var r0: PackedInt32Array = _lat_row(0, y, rnd)
		var r1: PackedInt32Array = _lat_row(1, y, rnd)
		var r2: PackedInt32Array = _lat_row(2, y, rnd)
		var r3: PackedInt32Array = _lat_row(3, y, rnd)
		var row: int = y * w
		var nrow: int = (y >> 2) * bw
		var by4: int = (y & 3) * 4
		var rn: int = maxi(0, y - 1) * w
		for x in w:
			var i: int = row + x
			var b: int = bio[i]
			var fl: int = nr[nrow + (x >> 2)]
			var l2: int = x >> 2
			var a2: int = r2[l2]
			var nw: int = a2 + (r2[l2 + 1] - a2) * (x & 3) / 4
			var bay: int = BAYER[by4 + (x & 3)]
			if b <= Biome.COAST and (fl & SLOW_SEA) == 0:

				var d: int = mini(63, maxi(1, sea - hgt[i]))
				var v16: int = clampi(dep[d] + (nw - 128) / (7 if d < 6 else 14), 16, 159)
				var band: int = v16 >> 4
				var fr: int = v16 & 15
				if fr >= 12 and (fr - 12) * 4 > bay:
					band += 1
				buf[j] = wat[mini(band, 9)]
				j += 1
				continue
			var l0: int = x / s0
			var a0: int = r0[l0]
			var nb: int = a0 + (r0[l0 + 1] - a0) * (x - l0 * s0) / s0
			var l1: int = x / s1
			var a1: int = r1[l1]
			var nm: int = a1 + (r1[l1 + 1] - a1) * (x - l1 * s1) / s1
			if b >= Biome.SAND and b <= Biome.SNOW and (fl & SLOW_LAND) == 0:

				var b0: int = b
				if (fl & NF_MIX) != 0:
					var l3: int = x / 3
					var a3: int = r3[l3]
					var nd: int = a3 + (r3[l3 + 1] - a3) * (x - l3 * 3) / 3
					var dx: int = (nw - 128) * 5 / 256
					var dy: int = (nd - 128) * 5 / 256
					if dx != 0 or dy != 0:
						var b1: int = bio[clampi(y + dy, 0, hh - 1) * w + clampi(x + dx, 0, w - 1)]
						if b1 != b and b1 >= Biome.SAND and b1 <= Biome.SNOW:
							var b2: int = bio[clampi(y + dy / 2, 0, hh - 1) * w + clampi(x + dx / 2, 0, w - 1)]
							if bay < (12 if b2 == b1 else 6):
								b = b1
				var patch: int = (nb * 5 + nm * 3) / 8 + (nw - 128) / 5
				var v16: int = b16[b] + (patch - 128) * spr[b] / 128 + _relief16(hl, hbase, x, y, b)
				var tone: int = v16 >> 4
				var fr: int = v16 & 15
				if fr >= 12 and (fr - 12) * 4 > bay:
					tone += 1
				buf[j] = rf[b * 8 + clampi(tone, 0, rl[b] - 1)]
				b = b0
				j += 1
				continue
			var l3: int = x / 3
			var a3: int = r3[l3]
			var nd: int = a3 + (r3[l3 + 1] - a3) * (x - l3 * 3) / 3
			buf[j] = _shade(x, y, nb, nm, nw, nd)
			j += 1
	_bands[k] = buf.to_byte_array()



func _noise_at(k: int, x: int, y: int) -> int:
	var st: int = _lat_s[k]
	var lx: int = x / st
	var ly: int = y / st
	var fy: int = y - ly * st
	var r0: int = ((ly + k * 61) & 255) << 8
	var r1: int = ((ly + 1 + k * 61) & 255) << 8
	var ox: int = k * 97
	var a: int = _rnd[r0 | ((lx + ox) & 255)]
	var c: int = _rnd[r1 | ((lx + ox) & 255)]
	var b: int = _rnd[r0 | ((lx + 1 + ox) & 255)]
	var dd: int = _rnd[r1 | ((lx + 1 + ox) & 255)]
	var ra: int = a + (c - a) * fy / st
	var rb: int = b + (dd - b) * fy / st
	return ra + (rb - ra) * (x - lx * st) / st


func _cell(x: int, y: int) -> int:
	return _shade(x, y, _noise_at(0, x, y), _noise_at(1, x, y), _noise_at(2, x, y), _noise_at(3, x, y))



func flush() -> void :
	if world == null or world.dirty_cells.is_empty():
		return
	for c: Vector2i in world.dirty_cells:
		var col: int = _cell(c.x, c.y)
		image.set_pixel(c.x, c.y, Color8(col & 255, (col >> 8) & 255, (col >> 16) & 255, 255))
	cells_changed.emit(world.dirty_cells.duplicate())
	world.dirty_cells.clear()
	tex.update(image)





func _color_at(x: int, y: int) -> int:
	var ww: int = world.w
	var i: int = y * ww + x
	var b: int = world.biome[i]
	var row: PackedInt64Array = colors[b]
	var hh: int = Hash32.h2(x, y, 77) & 31
	var v: int = 0
	if b <= Biome.RIVER:
		v = 1 if hh == 0 else 0
	elif b >= Biome.ROAD and b != Biome.GARDEN and b != Biome.FIELD:
		v = 2 if hh < 2 else 0
	else:
		var sl: int = world.height[i] - world.height[maxi(0, y - 2) * ww + maxi(0, x - 2)]
		if sl >= 2:
			v = 1
		elif sl <= -2:
			v = 2
		elif hh < 3:
			v = 1
		elif hh < 6:
			v = 2
	return row[v]





static func _band(v16: int, bay: int, top: int) -> int:
	var band: int = v16 >> 4
	var fr: int = v16 & 15
	if fr >= 12 and (fr - 12) * 4 > bay:
		band += 1
	return clampi(band, 0, top)






func _relief16(hgt: PackedByteArray, base: int, x: int, y: int, b: int) -> int:
	var w: int = world.w
	var hh: int = world.h
	var h0: int = hgt[y * w + x - base]
	var nw2: int = hgt[maxi(0, y - 2) * w + maxi(0, x - 2) - base]
	var se2: int = hgt[mini(hh - 1, y + 2) * w + mini(w - 1, x + 2) - base]
	if h0 < world.hills_thr - 10 and b != Biome.HILLS and b != Biome.ROCK and b != Biome.SNOW:
		var sl: int = se2 - nw2
		return 16 if sl >= 5 else (-16 if sl <= -5 else 0)
	var t: int = clampi((se2 - nw2) * 12, -40, 40)
	var st: int = 2 if b == Biome.ROCK or b == Biome.SNOW else 3
	var lv: int = h0 / st
	var ln: int = int(hgt[maxi(0, y - 1) * w + x - base]) / st
	if ln > lv:
		t -= 18
	elif ln < lv:
		t += 10
	return t


static func _paintable(b: int) -> bool:
	return b >= Biome.SAND and b <= Biome.SNOW


func _lake_at(x: int, y: int) -> int:
	for e: Array in world.lakes:
		var r: Rect2i = e[0]
		if x >= r.position.x and y >= r.position.y and x < r.end.x and y < r.end.y:
			var m: int = (e[1] as PackedByteArray)[(y - r.position.y) * r.size.x + (x - r.position.x)]
			if m != 0:
				return m
	return 0



func _wkind(x: int, y: int, fl: int) -> int:
	if x < 0 or y < 0 or x >= world.w or y >= world.h:
		return 0
	var b: int = world.biome[y * world.w + x]
	if b > Biome.RIVER:
		return 0
	if b == Biome.RIVER:
		return 2
	if (fl & NF_LAKE) != 0 and _lake_at(x, y) != 0:
		return 2
	return 1


func _shade(x: int, y: int, nb: int, nm: int, nw: int, nd: int) -> int:
	var w: int = world.w
	var i: int = y * w + x
	var bio: PackedByteArray = world.biome
	var b: int = bio[i]
	if b > Biome.SNOW:
		return _color_at(x, y)
	var bay: int = BAYER[(y & 3) * 4 + (x & 3)]
	var fl: int = near[(y >> 2) * bw + (x >> 2)]
	if b <= Biome.RIVER:
		return _water(x, y, i, b, fl, bay, nm, nw)
	return _land(x, y, i, b, fl, bay, nb, nm, nw, nd)


func _water(x: int, y: int, i: int, b: int, fl: int, bay: int, nm: int, nw: int) -> int:
	var w: int = world.w
	var h: int = world.h
	var lk: int = _lake_at(x, y) if b != Biome.RIVER and (fl & NF_LAKE) != 0 else 0

	var adj: int = 0
	var adj2: int = 0
	if (fl & NF_LAND) != 0:
		var bio: PackedByteArray = world.biome
		if x + 1 < w and bio[i + 1] > Biome.RIVER:
			adj += 1
		if x > 0 and bio[i - 1] > Biome.RIVER:
			adj += 1
		if y + 1 < h and bio[i + w] > Biome.RIVER:
			adj += 1
		if y > 0 and bio[i - w] > Biome.RIVER:
			adj += 1
		if adj == 0:
			if x + 2 < w and bio[i + 2] > Biome.RIVER:
				adj2 += 1
			if x > 1 and bio[i - 2] > Biome.RIVER:
				adj2 += 1
			if y + 2 < h and bio[i + 2 * w] > Biome.RIVER:
				adj2 += 1
			if y > 1 and bio[i - 2 * w] > Biome.RIVER:
				adj2 += 1
			if x + 1 < w and y + 1 < h and bio[i + w + 1] > Biome.RIVER:
				adj2 += 1
			if x > 0 and y > 0 and bio[i - w - 1] > Biome.RIVER:
				adj2 += 1
			if x + 1 < w and y > 0 and bio[i - w + 1] > Biome.RIVER:
				adj2 += 1
			if x > 0 and y + 1 < h and bio[i + w - 1] > Biome.RIVER:
				adj2 += 1
	if (fl & NF_FX) != 0 and world.fx_cells.has(i):
		var fx: int = world.fx_cells[i]
		if fx == WorldGen2.FX_RAPID:

			return water[0] if (x + y * 2 + (nw >> 6)) % 5 == 0 else water[1]
		if fx == WorldGen2.FX_POOL:
			return water[0] if (x + y + (nw >> 6)) % 3 == 0 else water[1]
	if adj > 0 and (b == Biome.RIVER or lk == 1) and _quay_at(x, y):
		return water[6]
	if b == Biome.RIVER:
		if adj > 0:
			return water[3]
		if adj2 > 0:
			return water[4]
		return water[5]
	if lk == 2:
		return water[4]
	if lk == 1:
		var dl: int = maxi(1, world.sea_level - world.height[i])
		if adj > 0:
			return water[2]
		if adj2 > 0:
			return water[3] if bay < 10 else water[2]
		return water[_band(16 * 3 + dl * 2 + (nw - 128) / 10, bay, 4)]

	if adj > 0:
		return water[0] if nm + (nw - 128) / 2 > 96 else water[1]
	var d: int = mini(63, maxi(1, world.sea_level - world.height[i]))
	var r16: int = depth16[d] + (nw - 128) / (7 if d < 6 else 14)
	if adj2 > 0:
		r16 = mini(r16, 30)
	return water[_band(clampi(r16, 16, 9 * 16 + 15), bay, 9)]



func _quay_at(x: int, y: int) -> bool:
	var w: int = world.w
	var bio: PackedByteArray = world.biome
	var i: int = y * w + x
	return (x + 1 < w and bio[i + 1] == Biome.PLAZA) or (x > 0 and bio[i - 1] == Biome.PLAZA)\
	or (y + 1 < world.h and bio[i + w] == Biome.PLAZA) or (y > 0 and bio[i - w] == Biome.PLAZA)


func _land(x: int, y: int, i: int, b: int, fl: int, bay: int, nb: int, nm: int, nw: int, nd: int) -> int:
	var w: int = world.w
	var hh: int = world.h
	var bio: PackedByteArray = world.biome
	var hgt: PackedByteArray = world.height

	if (fl & NF_FX) != 0 and world.fx_cells.has(i):
		var fx: int = world.fx_cells[i]
		if fx == WorldGen2.FX_FALL:
			return water[0] if y % 3 != 0 else water[1]
		if fx == WorldGen2.FX_FALL_H:
			return water[0] if x % 3 != 0 else water[1]
		if fx == WorldGen2.FX_FALL_EDGE:
			return (ramps[Biome.ROCK] as PackedInt64Array)[1]

	var wd: int = 0
	var wk: int = 0
	if (fl & (NF_SEA | NF_FRESH | NF_LAKE)) != 0:
		for k in 4:
			var qx: int = x + (1 if k == 0 else (-1 if k == 1 else 0))
			var qy: int = y + (1 if k == 2 else (-1 if k == 3 else 0))
			var t: int = _wkind(qx, qy, fl)
			if t != 0 and (wk == 0 or t == 1):
				wk = t
		if wk != 0:
			wd = 1
		else:
			for k in 8:
				var qx: int = x + R2X[k]
				var qy: int = y + R2Y[k]
				var t: int = _wkind(qx, qy, fl)
				if t != 0 and (wk == 0 or t == 1):
					wk = t
			if wk != 0:
				wd = 2
	if wd > 0 and b != Biome.ROCK and b != Biome.SNOW:
		var lift: int = hgt[i] - world.sea_level
		if wk == 1:
			if wd == 1:
				return pal["s1"]
			if b == Biome.SAND or lift <= 5 or b == Biome.STEPPE:
				return pal["s3"]
		elif b != Biome.HILLS:
			if wd == 1:
				return pal["g4"] if b == Biome.GRASS or b == Biome.FOREST or b == Biome.PINE else pal["s1"]

	var eb: int = b
	if (fl & NF_MIX) != 0:
		var dx: int = (nw - 128) * 5 / 256
		var dy: int = (nd - 128) * 5 / 256
		if dx != 0 or dy != 0:
			var qx: int = clampi(x + dx, 0, w - 1)
			var qy: int = clampi(y + dy, 0, hh - 1)
			var b1: int = bio[qy * w + qx]
			if b1 != b and _paintable(b1):
				var b2: int = bio[clampi(y + dy / 2, 0, hh - 1) * w + clampi(x + dx / 2, 0, w - 1)]
				if bay < (12 if b2 == b1 else 6):
					eb = b1
	var row: PackedInt64Array = ramps[eb]
	var top: int = row.size() - 1

	var patch: int = (nb * 5 + nm * 3) / 8 + (nw - 128) / 5
	var tone: int = _band(ramp_base[eb] * 16 + 8 + (patch - 128) * ramp_spread[eb] / 128 + _relief16(hgt, 0, x, y, eb), bay, top)

	if wd == 2 and wk == 2 and (eb == Biome.GRASS or eb == Biome.FOREST or eb == Biome.STEPPE):
		tone -= 1
	tone = clampi(tone, 0, top)

	if (fl & NF_ROCK) != 0 and eb != Biome.ROCK and eb != Biome.SNOW:
		var rr: PackedInt64Array = ramps[Biome.ROCK]
		var near1: bool = false
		for k in 4:
			var qx: int = clampi(x + (1 if k == 0 else (-1 if k == 1 else 0)), 0, w - 1)
			var qy: int = clampi(y + (1 if k == 2 else (-1 if k == 3 else 0)), 0, hh - 1)
			var qb: int = bio[qy * w + qx]
			if qb == Biome.ROCK or qb == Biome.SNOW:
				near1 = true
				break
		if near1:
			if bay < 6:
				return rr[3]
		else:
			for k in 4:
				var qx: int = clampi(x + (2 if k == 0 else (-2 if k == 1 else 0)), 0, w - 1)
				var qy: int = clampi(y + (2 if k == 2 else (-2 if k == 3 else 0)), 0, hh - 1)
				var qb: int = bio[qy * w + qx]
				if qb == Biome.ROCK or qb == Biome.SNOW:
					if bay < 2:
						return rr[4]
					break
	return row[tone]
