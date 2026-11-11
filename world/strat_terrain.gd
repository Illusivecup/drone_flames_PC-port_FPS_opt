extends RefCounted











const C_DEEP: int = 0
const C_SEA: int = 1
const C_SHAL: int = 2
const C_LAKE: int = 3
const C_RIVER: int = 4
const C_SAND: int = 5
const C_GRASS: int = 6
const C_FOREST: int = 7
const C_PINE: int = 8
const C_STEPPE: int = 9
const C_HILLS: int = 10
const C_ROCK: int = 11
const C_SNOW: int = 12
const C_URBAN: int = 13
const C_FIELD: int = 14
const C_SCAR: int = 15
const BASE_MAX: int = 2048

const LUT: Array[int] = [C_DEEP, C_SEA, C_SHAL, C_SHAL, C_RIVER, C_SAND, C_GRASS, C_FOREST, C_PINE, C_STEPPE, C_HILLS, 
	C_ROCK, C_SNOW, C_URBAN, C_URBAN, C_URBAN, C_URBAN, C_FIELD, C_FIELD, C_URBAN, C_SCAR, C_SCAR]

const PRI: Array[int] = [3, 2, 4, 1, 9, 5, 0, 6, 6, 3, 8, 9, 10, 9, 4, 7]


const PAL_HEX: Array[String] = [
	"1d3a72", "1d3a72", "1d3a72", "2a5596", 
	"24498a", "24498a", "24498a", "3768ad", 
	"3768ad", "3d70b6", "3d70b6", "6aa3d6", 
	"4a86c6", "4a86c6", "4a86c6", "86bce0", 
	"5a96d0", "5a96d0", "5a96d0", "5a96d0", 
	"b09a6e", "c4b083", "d4c294", "8e7a58", 
	"4e7f2e", "5f9032", "77a53c", "3f6a27", 
	"2d5a2c", "376a2c", "467c2f", "264c26", 
	"24452c", "2c5530", "386536", "1e3a26", 
	"8c7443", "a3884a", "b89d58", "735f38", 
	"6a5848", "806b53", "988162", "56473c", 
	"57565f", "6e6d70", "8a887f", "45454f", 
	"a9b4cf", "c5cde0", "e0e5ee", "8e9cc0", 
	"6e6a66", "8a857c", "a39d90", "5a5753", 
	"8f9a45", "a0a94f", "b4b862", "78833a", 
	"4a3f3a", "5b4d43", "6c5c4e", "3d3431", 
]


static func palette() -> PackedColorArray:
	var out: = PackedColorArray()
	for hx: String in PAL_HEX:
		out.append(Color(hx))
	return out



static func build(biome: PackedByteArray, height: PackedByteArray, w: int, h: int, lakes: Array, hills_thr: int) -> Image:
	var n: int = w * h
	if biome.size() != n or height.size() != n or n == 0:
		return null

	var lut: = PackedByteArray()
	lut.resize(256)
	for i in 256:
		lut[i] = LUT[i] if i < LUT.size() else C_GRASS
	var cls: = PackedByteArray()
	cls.resize(n)
	for i in n:
		cls[i] = lut[biome[i]]
	for e: Array in lakes:
		var r: Rect2i = e[0]
		var mk: PackedByteArray = e[1]
		for y in r.size.y:
			var cy: int = r.position.y + y
			if cy < 0 or cy >= h:
				continue
			for x in r.size.x:
				var cx: int = r.position.x + x
				if cx < 0 or cx >= w or mk[y * r.size.x + x] == 0:
					continue
				var ci: int = cy * w + cx
				if cls[ci] == C_SHAL:
					cls[ci] = C_LAKE
	var hg: PackedByteArray = height
	var lw: int = w
	var lh: int = h

	while maxi(lw, lh) > BASE_MAX:
		var d: Array = _down(cls, hg, lw, lh)
		cls = d[0]
		hg = d[1]
		lw = d[2]
		lh = d[3]
	var bw: int = lw
	var bh: int = lh
	var data: = PackedByteArray()
	var lv: int = 0
	var sc: int = maxi(1, w / bw)
	while true:
		data.append_array(_tones(cls, hg, lw, lh, lv, sc, hills_thr))
		if lw == 1 and lh == 1:
			break
		var d2: Array = _down(cls, hg, lw, lh)
		cls = d2[0]
		hg = d2[1]
		lw = d2[2]
		lh = d2[3]
		lv += 1
	var img: = Image.create_from_data(bw, bh, true, Image.FORMAT_R8, data)
	return img



static func _down(cls: PackedByteArray, hg: PackedByteArray, lw: int, lh: int) -> Array:
	var nw: int = maxi(1, lw >> 1)
	var nh: int = maxi(1, lh >> 1)
	var oc: = PackedByteArray()
	var oh: = PackedByteArray()
	oc.resize(nw * nh)
	oh.resize(nw * nh)
	var pri: PackedByteArray = PackedByteArray(PRI)
	for y in nh:
		var y0: int = mini(y * 2, lh - 1)
		var y1: int = mini(y * 2 + 1, lh - 1)
		var r0: int = y0 * lw
		var r1: int = y1 * lw
		var orow: int = y * nw
		for x in nw:
			var x0: int = mini(x * 2, lw - 1)
			var x1: int = mini(x * 2 + 1, lw - 1)
			var a: int = cls[r0 + x0]
			var b: int = cls[r0 + x1]
			var c: int = cls[r1 + x0]
			var d: int = cls[r1 + x1]
			oh[orow + x] = (hg[r0 + x0] + hg[r0 + x1] + hg[r1 + x0] + hg[r1 + x1]) >> 2
			if a == b and b == c and c == d:
				oc[orow + x] = a
				continue
			if a == C_RIVER or b == C_RIVER or c == C_RIVER or d == C_RIVER:
				oc[orow + x] = C_RIVER
				continue
			var wc: int = int(a <= C_RIVER) + int(b <= C_RIVER) + int(c <= C_RIVER) + int(d <= C_RIVER)
			if wc >= 3:
				var f: int = a if a <= C_RIVER else (b if b <= C_RIVER else c)
				if a > C_RIVER: a = f
				if b > C_RIVER: b = f
				if c > C_RIVER: c = f
				if d > C_RIVER: d = f
			elif wc > 0:
				var g: int = a if a > C_RIVER else (b if b > C_RIVER else (c if c > C_RIVER else d))
				if a <= C_RIVER: a = g
				if b <= C_RIVER: b = g
				if c <= C_RIVER: c = g
				if d <= C_RIVER: d = g
			oc[orow + x] = _mode4(a, b, c, d, pri)
	return [oc, oh, nw, nh]


static func _mode4(a: int, b: int, c: int, d: int, pri: PackedByteArray) -> int:
	if a == b:
		if c == d and c != a:
			return a if pri[a] >= pri[c] else c
		return a
	if a == c:
		if b == d:
			return a if pri[a] >= pri[b] else b
		return a
	if a == d:
		if b == c:
			return a if pri[a] >= pri[b] else b
		return a
	if b == c or b == d:
		return b
	if c == d:
		return c
	var m: int = a
	for v: int in [b, c, d]:
		if pri[v] > pri[m]:
			m = v
	return m



static func _tones(cls: PackedByteArray, hg: PackedByteArray, lw: int, lh: int, lv: int, sc: int, hills_thr: int) -> PackedByteArray:
	var out: = PackedByteArray()
	out.resize(lw * lh)
	var span: int = sc << lv

	var t_up: int = clampi(int(round(1.5 * sqrt(float(span)))), 1, 12)
	var t_low: int = clampi(int(round(4.0 * sqrt(float(span)))), 3, 30)
	var hthr: int = hills_thr - 10
	for y in lh:
		var row: int = y * lw
		var rn: int = maxi(0, y - 1) * lw
		var rs: int = mini(lh - 1, y + 1) * lw
		for x in lw:
			var i: int = row + x
			var c: int = cls[i]
			var xw: int = maxi(0, x - 1)
			var xe: int = mini(lw - 1, x + 1)
			var cn: int = cls[rn + x]
			var cs: int = cls[rs + x]
			var cw: int = cls[row + xw]
			var ce: int = cls[row + xe]
			var tone: int = 1
			if c <= C_RIVER:
				tone = 0
				if c != C_RIVER and (cn > C_RIVER or cs > C_RIVER or cw > C_RIVER or ce > C_RIVER):
					tone = 3
			elif (cn <= C_LAKE or cs <= C_LAKE or cw <= C_LAKE or ce <= C_LAKE):
				tone = 3
			elif c != C_URBAN:
				var dh: int = int(hg[rs + x]) + int(hg[row + xe]) - int(hg[rn + x]) - int(hg[row + xw])
				var up: bool = c == C_HILLS or c == C_ROCK or c == C_SNOW or int(hg[i]) >= hthr
				var t: int = t_up if up else t_low
				if dh >= t:
					tone = 2
				elif dh <= - t:
					tone = 0
			out[i] = c * 4 + tone
	return out
