class_name Ed25519
extends RefCounted






const _L: Array = [237, 211, 245, 92, 26, 99, 18, 88, 214, 156, 247, 162, 222, 249, 222, 20, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16]
const _D: Array = [30883, 4953, 19914, 30187, 55467, 16705, 2637, 112, 59544, 30585, 16505, 36039, 
	65139, 11119, 27886, 20995]
const _D2: Array = [61785, 9906, 39828, 60374, 45398, 33411, 5274, 224, 53552, 61171, 33010, 6542, 
	64743, 22239, 55772, 9222]
const _X: Array = [54554, 36645, 11616, 51542, 42930, 38181, 51040, 26924, 56412, 64982, 57905, 49316, 
	21502, 52590, 14035, 8553]
const _Y: Array = [26200, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 
	26214, 26214, 26214, 26214]
const _I: Array = [41136, 18958, 6951, 50414, 58488, 44335, 6150, 12099, 55207, 15867, 153, 11085, 
	57099, 20417, 9344, 11139]

const _K32: Array = [
	1116352408, 3609767458, 1899447441, 602891725, 3049323471, 3964484399, 3921009573, 2173295548, 
	961987163, 4081628472, 1508970993, 3053834265, 2453635748, 2937671579, 2870763221, 3664609560, 
	3624381080, 2734883394, 310598401, 1164996542, 607225278, 1323610764, 1426881987, 3590304994, 
	1925078388, 4068182383, 2162078206, 991336113, 2614888103, 633803317, 3248222580, 3479774868, 
	3835390401, 2666613458, 4022224774, 944711139, 264347078, 2341262773, 604807628, 2007800933, 
	770255983, 1495990901, 1249150122, 1856431235, 1555081692, 3175218132, 1996064986, 2198950837, 
	2554220882, 3999719339, 2821834349, 766784016, 2952996808, 2566594879, 3210313671, 3203337956, 
	3336571891, 1034457026, 3584528711, 2466948901, 113926993, 3758326383, 338241895, 168717936, 
	666307205, 1188179964, 773529912, 1546045734, 1294757372, 1522805485, 1396182291, 2643833823, 
	1695183700, 2343527390, 1986661051, 1014477480, 2177026350, 1206759142, 2456956037, 344077627, 
	2730485921, 1290863460, 2820302411, 3158454273, 3259730800, 3505952657, 3345764771, 106217008, 
	3516065817, 3606008344, 3600352804, 1432725776, 4094571909, 1467031594, 275423344, 851169720, 
	430227734, 3100823752, 506948616, 1363258195, 659060556, 3750685593, 883997877, 3785050280, 
	958139571, 3318307427, 1322822218, 3812723403, 1537002063, 2003034995, 1747873779, 3602036899, 
	1955562222, 1575990012, 2024104815, 1125592928, 2227730452, 2716904306, 2361852424, 442776044, 
	2428436474, 593698344, 2756734187, 3733110249, 3204031479, 2999351573, 3329325298, 3815920427, 
	3391569614, 3928383900, 3515267271, 566280711, 3940187606, 3454069534, 4118630271, 4000239992, 
	116418474, 1914138554, 174292421, 2731055270, 289380356, 3203993006, 460393269, 320620315, 
	685471733, 587496836, 852142971, 1086792851, 1017036298, 365543100, 1126000580, 2618297676, 
	1288033470, 3409855158, 1501505948, 4234509866, 1607167915, 987167468, 1816402316, 1246189591]
const _H32: Array = [1779033703, 4089235720, 3144134277, 2227873595, 1013904242, 4271175723, 2773480762, 1595750129, 
	1359893119, 2917565137, 2600822924, 725511199, 528734635, 4215389547, 1541459225, 327033209]

static var _k: PackedInt64Array = PackedInt64Array()
static var _d2: PackedInt64Array = PackedInt64Array()



static func prepare() -> void :
	if _d2.is_empty():
		_d2 = _gf(_D2)
	if _k.is_empty():
		var k: = PackedInt64Array()
		for i in 80:
			k.append((int(_K32[2 * i]) << 32) | int(_K32[2 * i + 1]))
		_k = k



static func verify(sig: PackedByteArray, msg: PackedByteArray, pk: PackedByteArray) -> bool:
	if sig.size() != 64 or pk.size() != 32:
		return false
	prepare()
	if not _below_l(sig.slice(32, 64)):
		return false
	var q: Array = _unpackneg(pk)
	if q.is_empty():
		return false
	var hm: PackedByteArray = sig.slice(0, 32)
	hm.append_array(pk)
	hm.append_array(msg)
	var h: PackedByteArray = _reduce(sha512(hm))
	var p: Array = _point()
	_scalarmult(p, q, h)
	var b: Array = [_gf(_X), _gf(_Y), _gf([1]), _gf()]
	_mul(b[3], b[0], b[1])
	var r: Array = _point()
	_scalarmult(r, b, sig.slice(32, 64))
	_add(p, r)
	return _pack(p) == sig.slice(0, 32)




static func _gf(init: Array = []) -> PackedInt64Array:
	var o: = PackedInt64Array()
	o.resize(16)
	for i in init.size():
		o[i] = init[i]
	return o


static func _point() -> Array:
	return [_gf(), _gf([1]), _gf([1]), _gf()]


static func _car(o: PackedInt64Array) -> void :
	for i in 16:
		o[i] += 65536
		var c: int = o[i] >> 16
		if i < 15:
			o[i + 1] += c - 1
		else:
			o[0] += 38 * (c - 1)
		o[i] -= c << 16


static func _sel(p: PackedInt64Array, q: PackedInt64Array, b: int) -> void :
	var c: int = ~ (b - 1)
	for i in 16:
		var t: int = c & (p[i] ^ q[i])
		p[i] ^= t
		q[i] ^= t


static func _pack25519(n: PackedInt64Array) -> PackedByteArray:
	var t: PackedInt64Array = n.duplicate()
	var m: = _gf()
	_car(t)
	_car(t)
	_car(t)
	for _j in 2:
		m[0] = t[0] - 65517
		for i in range(1, 15):
			m[i] = t[i] - 65535 - ((m[i - 1] >> 16) & 1)
			m[i - 1] &= 65535
		m[15] = t[15] - 32767 - ((m[14] >> 16) & 1)
		var b: int = (m[15] >> 16) & 1
		m[14] &= 65535
		_sel(t, m, 1 - b)
	var o: = PackedByteArray()
	o.resize(32)
	for i in 16:
		o[2 * i] = t[i] & 255
		o[2 * i + 1] = (t[i] >> 8) & 255
	return o


static func _unpack25519(n: PackedByteArray) -> PackedInt64Array:
	var o: = _gf()
	for i in 16:
		o[i] = n[2 * i] + (n[2 * i + 1] << 8)
	o[15] &= 32767
	return o


static func _addf(o: PackedInt64Array, a: PackedInt64Array, b: PackedInt64Array) -> void :
	for i in 16:
		o[i] = a[i] + b[i]


static func _subf(o: PackedInt64Array, a: PackedInt64Array, b: PackedInt64Array) -> void :
	for i in 16:
		o[i] = a[i] - b[i]


static func _mul(o: PackedInt64Array, a: PackedInt64Array, b: PackedInt64Array) -> void :
	var t: = PackedInt64Array()
	t.resize(31)
	for i in 16:
		var ai: int = a[i]
		for j in 16:
			t[i + j] += ai * b[j]
	for i in 15:
		t[i] += 38 * t[i + 16]
	for i in 16:
		o[i] = t[i]
	_car(o)
	_car(o)


static func _inv(i: PackedInt64Array) -> PackedInt64Array:
	var c: PackedInt64Array = i.duplicate()
	for a in range(253, -1, -1):
		_mul(c, c, c)
		if a != 2 and a != 4:
			_mul(c, c, i)
	return c


static func _pow2523(i: PackedInt64Array) -> PackedInt64Array:
	var c: PackedInt64Array = i.duplicate()
	for a in range(250, -1, -1):
		_mul(c, c, c)
		if a != 1:
			_mul(c, c, i)
	return c


static func _neq(a: PackedInt64Array, b: PackedInt64Array) -> bool:
	return _pack25519(a) != _pack25519(b)


static func _par(a: PackedInt64Array) -> int:
	return _pack25519(a)[0] & 1




static func _add(p: Array, q: Array) -> void :
	var a: = _gf()
	var b: = _gf()
	var c: = _gf()
	var d: = _gf()
	var t: = _gf()
	var e: = _gf()
	var f: = _gf()
	var g: = _gf()
	var h: = _gf()
	_subf(a, p[1], p[0])
	_subf(t, q[1], q[0])
	_mul(a, a, t)
	_addf(b, p[0], p[1])
	_addf(t, q[0], q[1])
	_mul(b, b, t)
	_mul(c, p[3], q[3])
	_mul(c, c, _d2)
	_mul(d, p[2], q[2])
	_addf(d, d, d)
	_subf(e, b, a)
	_subf(f, d, c)
	_addf(g, d, c)
	_addf(h, b, a)
	_mul(p[0], e, f)
	_mul(p[1], h, g)
	_mul(p[2], g, f)
	_mul(p[3], e, h)


static func _cswap(p: Array, q: Array, b: int) -> void :
	for i in 4:
		_sel(p[i], q[i], b)


static func _pack(p: Array) -> PackedByteArray:
	var zi: PackedInt64Array = _inv(p[2])
	var tx: = _gf()
	var ty: = _gf()
	_mul(tx, p[0], zi)
	_mul(ty, p[1], zi)
	var r: PackedByteArray = _pack25519(ty)
	r[31] ^= _par(tx) << 7
	return r



static func _scalarmult(p: Array, q: Array, s: PackedByteArray) -> void :
	for i in range(255, -1, -1):
		var bit: int = (s[i >> 3] >> (i & 7)) & 1
		_cswap(p, q, bit)
		_add(q, p)
		_add(p, p)
		_cswap(p, q, bit)



static func _unpackneg(pk: PackedByteArray) -> Array:
	var y: PackedInt64Array = _unpack25519(pk)
	if _pack25519(y) != _clear_top(pk):
		return []
	var r: Array = [_gf(), y, _gf([1]), _gf()]
	var num: = _gf()
	var den: = _gf()
	var den2: = _gf()
	var den4: = _gf()
	var den6: = _gf()
	var t: = _gf()
	var chk: = _gf()
	_mul(num, r[1], r[1])
	_mul(den, num, _gf(_D))
	_subf(num, num, r[2])
	_addf(den, r[2], den)
	_mul(den2, den, den)
	_mul(den4, den2, den2)
	_mul(den6, den4, den2)
	_mul(t, den6, num)
	_mul(t, t, den)
	t = _pow2523(t)
	_mul(t, t, num)
	_mul(t, t, den)
	_mul(t, t, den)
	_mul(r[0], t, den)
	_mul(chk, r[0], r[0])
	_mul(chk, chk, den)
	if _neq(chk, num):
		_mul(r[0], r[0], _gf(_I))
	_mul(chk, r[0], r[0])
	_mul(chk, chk, den)
	if _neq(chk, num):
		return []
	if _par(r[0]) == (pk[31] >> 7):
		_subf(r[0], _gf(), r[0])
	_mul(r[3], r[0], r[1])
	return r


static func _clear_top(pk: PackedByteArray) -> PackedByteArray:
	var o: PackedByteArray = pk.duplicate()
	o[31] &= 127
	return o




static func _below_l(s: PackedByteArray) -> bool:
	for i in range(31, -1, -1):
		if s[i] != _L[i]:
			return s[i] < _L[i]
	return false


static func _reduce(r: PackedByteArray) -> PackedByteArray:
	var x: = PackedInt64Array()
	x.resize(64)
	for i in 64:
		x[i] = r[i]
	var carry: int = 0
	for i in range(63, 31, -1):
		carry = 0
		var j: int = i - 32
		while j < i - 12:
			x[j] += carry - 16 * x[i] * _L[j - (i - 32)]
			carry = (x[j] + 128) >> 8
			x[j] -= carry << 8
			j += 1
		x[j] += carry
		x[i] = 0
	carry = 0
	for j in 32:
		x[j] += carry - (x[31] >> 4) * _L[j]
		carry = x[j] >> 8
		x[j] &= 255
	for j in 32:
		x[j] -= carry * _L[j]
	var o: = PackedByteArray()
	o.resize(32)
	for i in 32:
		x[i + 1] += x[i] >> 8
		o[i] = x[i] & 255
	return o




static func _rotr(x: int, n: int) -> int:
	return ((x >> n) & ((1 << (64 - n)) - 1)) | (x << (64 - n))


static func _shr(x: int, n: int) -> int:
	return (x >> n) & ((1 << (64 - n)) - 1)


static func sha512(data: PackedByteArray) -> PackedByteArray:
	prepare()
	var h: = PackedInt64Array()
	for i in 8:
		h.append((int(_H32[2 * i]) << 32) | int(_H32[2 * i + 1]))
	var m: PackedByteArray = data.duplicate()
	var bits: int = data.size() * 8
	m.append(128)
	while m.size() % 128 != 112:
		m.append(0)
	for i in 8:
		m.append(0)
	for i in range(7, -1, -1):
		m.append((bits >> (8 * i)) & 255)
	var w: = PackedInt64Array()
	w.resize(80)
	for blk in range(0, m.size(), 128):
		for t in 16:
			var v: int = 0
			for k in 8:
				v = (v << 8) | m[blk + 8 * t + k]
			w[t] = v
		for t in range(16, 80):
			var x15: int = w[t - 15]
			var x2: int = w[t - 2]
			var s0: int = _rotr(x15, 1) ^ _rotr(x15, 8) ^ _shr(x15, 7)
			var s1: int = _rotr(x2, 19) ^ _rotr(x2, 61) ^ _shr(x2, 6)
			w[t] = w[t - 16] + s0 + w[t - 7] + s1
		var a: int = h[0]
		var b: int = h[1]
		var c: int = h[2]
		var d: int = h[3]
		var e: int = h[4]
		var f: int = h[5]
		var g: int = h[6]
		var hh: int = h[7]
		for t in 80:
			var t1: int = hh + (_rotr(e, 14) ^ _rotr(e, 18) ^ _rotr(e, 41)) + ((e & f) ^ ( ~ e & g)) + _k[t] + w[t]
			var t2: int = (_rotr(a, 28) ^ _rotr(a, 34) ^ _rotr(a, 39)) + ((a & b) ^ (a & c) ^ (b & c))
			hh = g
			g = f
			f = e
			e = d + t1
			d = c
			c = b
			b = a
			a = t1 + t2
		h[0] += a
		h[1] += b
		h[2] += c
		h[3] += d
		h[4] += e
		h[5] += f
		h[6] += g
		h[7] += hh
	var o: = PackedByteArray()
	for i in 8:
		for k in range(7, -1, -1):
			o.append((h[i] >> (8 * k)) & 255)
	return o
