class_name Hash32
extends RefCounted


const M32: int = 4294967295


static func mix(v: int) -> int:
	var x: int = v & M32
	x ^= x >> 16
	x = (x * 2146121005) & M32
	x ^= x >> 15
	x = (x * 739982445) & M32
	x ^= x >> 16
	return x


static func h2(x: int, y: int, s: int) -> int:
	return mix((((x & 65535) | ((y & 65535) << 16)) ^ mix(s)) & M32)
