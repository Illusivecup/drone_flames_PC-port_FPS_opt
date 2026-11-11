@tool
class_name McpJsonValues
extends RefCounted














const COLOR_KEYS: Array[String] = ["r", "g", "b"]
const VECTOR2_KEYS: Array[String] = ["x", "y"]
const VECTOR3_KEYS: Array[String] = ["x", "y", "z"]
const VECTOR3I_KEYS: Array[String] = ["x", "y", "z"]
const QUATERNION_KEYS: Array[String] = ["x", "y", "z", "w"]
const BASIS_KEYS: Array[String] = ["x", "y", "z"]
const RECT2_KEYS: Array[String] = ["position", "size"]
const AABB_KEYS: Array[String] = ["position", "size"]




const INT32_MIN: = -2147483648
const INT32_MAX: = 2147483647


static func parse_color(value: Variant) -> Variant:
	if value is Color:
		return value
	if value is String:


		var a: = Color.from_string(value, Color(0, 0, 0, 0))
		var b: = Color.from_string(value, Color(1, 1, 1, 1))
		if a != b:
			return null
		return a
	if value is Dictionary:
		var d: Dictionary = value
		if not d.has_all(COLOR_KEYS):
			return null
		var alpha: Variant = d.get("a", 1.0)
		if not (_is_number(d.r) and _is_number(d.g) and _is_number(d.b) and _is_number(alpha)):
			return null
		return Color(float(d.r), float(d.g), float(d.b), float(alpha))
	if value is Array:
		var arr: Array = value
		if arr.size() != 3 and arr.size() != 4:
			return null
		for item in arr:
			if not _is_number(item):
				return null
		var a4: = float(arr[3]) if arr.size() == 4 else 1.0
		return Color(float(arr[0]), float(arr[1]), float(arr[2]), a4)
	return null


static func parse_vector2(value: Variant) -> Variant:
	if value is Vector2:
		return value
	if value is Dictionary:
		var d: Dictionary = value
		if not d.has_all(VECTOR2_KEYS) or not (_is_number(d.x) and _is_number(d.y)):
			return null
		return Vector2(float(d.x), float(d.y))
	if value is Array:
		var arr: Array = value
		if arr.size() != 2 or not (_is_number(arr[0]) and _is_number(arr[1])):
			return null
		return Vector2(float(arr[0]), float(arr[1]))
	return null


static func parse_vector3(value: Variant) -> Variant:
	if value is Vector3:
		return value
	if value is Dictionary:
		var d: Dictionary = value
		if not d.has_all(VECTOR3_KEYS):
			return null
		if not (_is_number(d.x) and _is_number(d.y) and _is_number(d.z)):
			return null
		return Vector3(float(d.x), float(d.y), float(d.z))
	if value is Array:
		var arr: Array = value
		if arr.size() != 3:
			return null
		for item in arr:
			if not _is_number(item):
				return null
		return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	return null








static func parse_float(value: Variant) -> Variant:
	if _is_number(value):
		return float(value)
	if value is String:
		var text: = value as String
		if text.is_valid_float():
			return text.to_float()
	return null


static func parse_vector3i(value: Variant) -> Variant:
	if value is Vector3i:
		return value
	var components: Array = []
	if value is Dictionary:
		var d: Dictionary = value
		if not d.has_all(VECTOR3I_KEYS):
			return null
		components = [d.x, d.y, d.z]
	elif value is Array:
		var arr: Array = value
		if arr.size() != 3:
			return null
		components = arr
	else:
		return null
	var parsed: Array = []
	for component in components:
		var number: Variant = _int32_component(component)
		if number == null:
			return null
		parsed.append(number)
	return Vector3i(parsed[0], parsed[1], parsed[2])


static func parse_quaternion(value: Variant) -> Variant:
	if value is Quaternion:
		return value
	var components: Array = []
	if value is Dictionary:
		var d: Dictionary = value
		if not d.has_all(QUATERNION_KEYS):
			return null
		components = [d.x, d.y, d.z, d.w]
	elif value is Array:
		var arr: Array = value
		if arr.size() != 4:
			return null
		components = arr
	else:
		return null
	var parsed: Array = []
	for component in components:
		if not _is_finite_number(component):
			return null
		parsed.append(float(component))



	var quat: = Quaternion(parsed[0], parsed[1], parsed[2], parsed[3])


	if not _is_finite_quaternion(quat):
		return null
	return quat





static func parse_basis(value: Variant) -> Variant:
	if value is Basis:
		return value
	var rows: Array = []
	if value is Dictionary:
		var d: Dictionary = value
		if not d.has_all(BASIS_KEYS):
			return null
		rows = [d.x, d.y, d.z]
	elif value is Array:
		var arr: Array = value
		if arr.size() != 3:
			return null
		rows = arr
	else:
		return null
	var axes: Array = []
	for row in rows:
		var axis: Variant = parse_vector3(row)
		if axis == null or not _is_finite_vector3(axis as Vector3):
			return null
		axes.append(axis)
	return Basis(axes[0], axes[1], axes[2])






static func parse_transform3d(value: Variant) -> Variant:
	if value is Transform3D:
		return value
	if not value is Dictionary:
		return null
	var d: Dictionary = value
	if d.has("basis") or d.has("origin"):
		if not (d.has("basis") and d.has("origin")):
			return null
		var basis: Variant = parse_basis(d.basis)
		var origin: Variant = parse_vector3(d.origin)
		if basis == null or origin == null or not _is_finite_vector3(origin as Vector3):
			return null
		return Transform3D(basis, origin)
	if d.has("position"):
		var pos: Variant = parse_vector3(d.position)
		if pos == null or not _is_finite_vector3(pos as Vector3):
			return null
		var rot_basis: = Basis.IDENTITY
		if d.has("rotation_degrees"):
			var rot_deg: Variant = parse_vector3(d.rotation_degrees)
			if rot_deg == null or not _is_finite_vector3(rot_deg as Vector3):
				return null
			rot_basis = Basis.from_euler((rot_deg as Vector3) * (PI / 180.0))
		elif d.has("rotation"):
			var rot: Variant = parse_vector3(d.rotation)
			if rot == null or not _is_finite_vector3(rot as Vector3):
				return null
			rot_basis = Basis.from_euler(rot)
		if d.has("scale"):
			var scale: Variant = parse_vector3(d.scale)
			if scale == null or not _is_finite_vector3(scale as Vector3):
				return null



			rot_basis = rot_basis.scaled_local(scale)
		return Transform3D(rot_basis, pos)
	return null


static func parse_rect2(value: Variant) -> Variant:
	if value is Rect2:
		return value
	if value is Dictionary:
		var d: Dictionary = value
		if not d.has_all(RECT2_KEYS):
			return null
		var pos: Variant = parse_vector2(d.position)
		var size: Variant = parse_vector2(d.size)
		if pos == null or size == null:
			return null
		if not (_is_finite_vector2(pos as Vector2) and _is_finite_vector2(size as Vector2)):
			return null
		return Rect2(pos, size)
	if value is Array:
		var arr: Array = value
		if arr.size() != 4:
			return null
		for item in arr:
			if not _is_number(item):
				return null
		var rect: = Rect2(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
		if not (_is_finite_vector2(rect.position) and _is_finite_vector2(rect.size)):
			return null
		return rect
	return null


static func parse_aabb(value: Variant) -> Variant:
	if value is AABB:
		return value
	if value is Dictionary:
		var d: Dictionary = value
		if not d.has_all(AABB_KEYS):
			return null
		var pos: Variant = parse_vector3(d.position)
		var size: Variant = parse_vector3(d.size)
		if pos == null or size == null:
			return null
		if not (_is_finite_vector3(pos as Vector3) and _is_finite_vector3(size as Vector3)):
			return null
		return AABB(pos, size)
	if value is Array:
		var arr: Array = value
		if arr.size() != 6:
			return null
		for item in arr:
			if not _is_number(item):
				return null
		var pos: = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
		var size: = Vector3(float(arr[3]), float(arr[4]), float(arr[5]))
		if not (_is_finite_vector3(pos) and _is_finite_vector3(size)):
			return null
		return AABB(pos, size)
	return null


static func parse_node_path(value: Variant) -> Variant:
	if value is NodePath:
		return value
	if value is String:
		return NodePath(value)
	return null


static func parse_string_name(value: Variant) -> Variant:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return null


static func _is_number(v: Variant) -> bool:
	return v is int or v is float




static func _int32_component(v: Variant) -> Variant:
	if not _is_number(v):
		return null
	var number: = float(v)
	if not is_finite(number) or number < float(INT32_MIN) or number > float(INT32_MAX):
		return null
	return int(number)


static func _is_finite_number(v: Variant) -> bool:
	return _is_number(v) and is_finite(float(v))


static func _is_finite_vector2(v: Vector2) -> bool:
	return is_finite(v.x) and is_finite(v.y)


static func _is_finite_vector3(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


static func _is_finite_quaternion(v: Quaternion) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z) and is_finite(v.w)
