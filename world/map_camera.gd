class_name MapCamera
extends Camera2D


signal zoom_changed(z: float)

const ZOOMS: Array = [0.25, 0.5, 1.0, 2.0, 3.0, 4.0]



static var ui_k: float = 1.0
static var zs: Array = ZOOMS.duplicate()



static func zk(z: float) -> float:
	return z / ui_k


static func set_ui_k(k: float, cam: Camera2D = null) -> void :
	var old: float = ui_k
	ui_k = clampf(k, 0.5, 2.0)
	zs = []
	for z: Variant in ZOOMS:
		zs.append(float(z) / ui_k)
	if cam is MapCamera and is_instance_valid(cam) and absf(old - ui_k) > 0.001:
		var mc: MapCamera = cam
		mc.set_zoom_at(mc.zoom.x * old / ui_k, mc.view_size() * 0.5)

var world_px: Vector2 = Vector2(4096, 4096)



var margin_top_px: float = 90.0
var margin_bottom_px: float = 240.0
var margin_left_px: float = 0.0
var margin_right_px: float = 0.0
var _shake_seq: Array = []
var _shake_t: float = 0.0
var _shake_i: int = 0
var _shake_step: float = 0.033

# PC Controls & Smooth Zoom settings
var smooth_zoom_enabled: bool = true
var smooth_zoom_speed: float = 15.0
var zoom_step_factor: float = 1.25
var _target_z: float = 0.0
var _last_wheel_time: int = 0


var _settle_z: float = 0.0
var _settle_f: Vector2 = Vector2.ZERO



var floor_z: float = 0.0



const STRAT_FULL: float = 0.17
const STRAT_WHEEL: float = 0.7
const DIVE_Z: float = 0.5
const DIVE_S: float = 0.45
var _dive_t: float = -1.0
var _dive_z0: float = 1.0
var _dive_w: Vector2 = Vector2.ZERO
var _dive_f0: Vector2 = Vector2.ZERO





const RUBBER_PX: float = 56.0
var _held_t: Dictionary = {}
var _held_m: bool = false


func min_zoom() -> float:
	if floor_z > 0.0:
		return floor_z if floor_z < float(zs[0]) else float(zs[0])
	return strat_floor()



func strat_floor() -> float:
	var vs: Vector2 = view_size()
	var fw: float = maxf(64.0, vs.x - margin_left_px - margin_right_px)
	var fh: float = maxf(64.0, vs.y - margin_top_px - margin_bottom_px)
	var fit: float = minf(fw / maxf(1.0, world_px.x), fh / maxf(1.0, world_px.y)) * 0.97
	return clampf(fit, 0.01, strat_full_z())



func strat_k() -> float:
	return strat_k_of(zoom.x) if floor_z <= 0.0 else 0.0


const STRAT_THRESHOLDS: Array = [0.17, 0.28, 0.40, 0.50]

static func strat_top() -> float:
	var idx: int = clampi(GameConfig.eff_strat_lod_z(), 0, STRAT_THRESHOLDS.size() - 1)
	if idx == 0:
		if zs.is_empty():
			zs = ZOOMS.duplicate()
		return float(zs[0])
	return float(STRAT_THRESHOLDS[idx]) * 1.45


static func strat_full_z() -> float:
	var idx: int = clampi(GameConfig.eff_strat_lod_z(), 0, STRAT_THRESHOLDS.size() - 1)
	var base_th: float = float(STRAT_THRESHOLDS[idx])
	var top: float = strat_top()
	var full: float = base_th / maxf(ui_k, 0.1)
	if full >= top:
		full = top * 0.68
	return full


static func strat_k_of(z: float) -> float:
	var top: float = strat_top()
	var bot: float = strat_full_z()
	if z >= top:
		return 0.0
	if z <= bot or top <= bot:
		return 1.0
	var t: float = (log(top) - log(maxf(z, 0.001))) / (log(top) - log(bot))
	return clampf(smoothstep(0.0, 1.0, t), 0.0, 1.0)


func is_strategic() -> bool:
	return strat_k() >= 0.999



func dive_to(screen_p: Vector2) -> void :
	_settle_z = 0.0
	_dive_z0 = zoom.x
	_dive_w = screen_to_world(screen_p)
	_dive_f0 = screen_p
	_dive_t = 0.0


func is_diving() -> bool:
	return _dive_t >= 0.0


func _ready() -> void :
	zoom = Vector2.ONE
	Sfx.set_listener(self)


func view_size() -> Vector2:
	return get_viewport_rect().size


func screen_to_world(p: Vector2) -> Vector2:
	return position + (p - view_size() * 0.5) / zoom.x


func world_to_screen(p: Vector2) -> Vector2:
	return (p - position) * zoom.x + view_size() * 0.5


func pan_screen(delta: Vector2) -> void :
	var k: float = strat_k()
	if k > 0.0:

		var z: float = maxf(0.01, zoom.x)
		var r: Array = _pos_range(z)
		var d: Vector2 = - delta / z
		var rb: float = RUBBER_PX / z * k
		for ax in 2:
			var lo: float = (r[0] as Vector2)[ax]
			var hi: float = (r[1] as Vector2)[ax]
			var p: float = position[ax]
			if (p <= lo + 0.001 and d[ax] < 0.0) or (p >= hi - 0.001 and d[ax] > 0.0):
				var out: float = (lo - p) if d[ax] < 0.0 else (p - hi)
				d[ax] *= 0.4 * clampf(1.0 - out / maxf(rb, 0.001), 0.0, 1.0)
		position += d
	else:
		position -= delta / zoom.x
	_clamp()



func is_held() -> bool:
	return _held_m or not _held_t.is_empty()


func _input(event: InputEvent) -> void :
	if event is InputEventScreenTouch:
		var st: = event as InputEventScreenTouch
		if st.pressed:
			_held_t[st.index] = true
		else:
			_held_t.erase(st.index)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_held_m = (event as InputEventMouseButton).pressed


func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var hovered := get_viewport().gui_get_hovered_control()
			if hovered:
				smooth_zoom_speed = 0.0
			else:
				smooth_zoom_speed = 15.0
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var hovered := get_viewport().gui_get_hovered_control()
			if hovered:
				smooth_zoom_speed = 0.0
			else:
				smooth_zoom_speed = 15.0




func _pos_range(z: float) -> Array:
	var half: Vector2 = view_size() * 0.5 / z
	var k: float = strat_k()
	var a: Vector2 = _axis_range(half.x, world_px.x, margin_left_px / z, margin_right_px / z, k)
	var b: Vector2 = _axis_range(half.y, world_px.y, margin_top_px / z, margin_bottom_px / z, k)
	return [Vector2(a.x, b.x), Vector2(a.y, b.y)]


static func _axis_range(half: float, size: float, m0: float, m1: float, k: float) -> Vector2:
	var lo: float = half - m0
	var hi: float = size - half + m1
	if lo > hi:
		lo = size * 0.5 - (m0 - m1) * 0.5
		hi = lo
	if k > 0.0:
		var c: float = (m0 - m1) * 0.5
		lo = lerpf(lo, minf(lo, - c), k)
		hi = lerpf(hi, maxf(hi, size - c), k)
	return Vector2(lo, hi)


func set_zoom_at(z: float, focus: Vector2) -> void :
	_settle_z = 0.0
	_dive_t = -1.0
	_zoom_at(z, focus)


func _zoom_at(z: float, focus: Vector2) -> void :
	var before: Vector2 = screen_to_world(focus)
	z = clampf(z, min_zoom(), float(zs[zs.size() - 1]))
	var z0: float = zoom.x
	zoom = Vector2(z, z)
	var after: Vector2 = screen_to_world(focus)
	position += before - after
	if z < z0 and strat_k() > 0.0:


		var f: float = min_zoom()
		if z0 - f > 0.0005:
			var hr: Array = _hard_range(z)
			var hc: Vector2 = position.clamp(hr[0], hr[1])
			position = hc + (position - hc) * clampf((z - f) / (z0 - f), 0.0, 1.0)
	_clamp()
	zoom_changed.emit(z)


func smooth_step_zoom(dir: float, focus: Vector2, factor_weight: float = 1.0) -> void :
	_dive_t = -1.0
	var now: int = Time.get_ticks_msec()
	var dt_ms: int = now - _last_wheel_time
	_last_wheel_time = now

	# Rate-scaling for rapid-fire events (macOS smooth scrolling utilities like Mos/Mac Mouse Fix)
	var rate_scale: float = 1.0
	if dt_ms < 60 and dt_ms > 0:
		rate_scale = clampf(float(dt_ms) / 60.0, 0.1, 1.0)

	var effective_weight: float = clampf(factor_weight, 0.05, 1.5) * rate_scale

	var cur_z: float = zoom.x
	var cur_tgt: float = _target_z if _target_z > 0.0 else cur_z

	# Direction reversal: eliminate any sponginess/lag when suddenly switching zoom direction
	if (dir < 0.0 and cur_tgt > cur_z) or (dir > 0.0 and cur_tgt < cur_z):
		cur_tgt = cur_z
	else:
		# Don't let target zoom get more than ~1.5 steps ahead of current visual zoom
		var max_ratio: float = pow(zoom_step_factor, 1.5)
		cur_tgt = clampf(cur_tgt, cur_z / max_ratio, cur_z * max_ratio)

	var factor: float = pow(zoom_step_factor, dir * effective_weight)
	var new_z: float = cur_tgt * factor
	var max_z: float = float(zs[zs.size() - 1]) * 1.5
	new_z = clampf(new_z, min_zoom(), max_z)
	_target_z = new_z
	_settle_z = new_z
	_settle_f = focus

func set_smooth_zoom_speed(spd: float) -> void :
	smooth_zoom_speed = clampf(spd, 4.0, 30.0)

func set_smooth_zoom_sensitivity(sens: float) -> void :
	zoom_step_factor = clampf(1.0 + 0.25 * sens, 1.05, 1.6)

func set_smooth_zoom_enabled(enabled: bool) -> void :
	smooth_zoom_enabled = enabled

func step_zoom(dir: float, focus: Vector2, factor_weight: float = 1.0) -> void :
	if smooth_zoom_speed <= 0.0:
		_target_z = 0.0
		_settle_z = 0.0
		return
	if smooth_zoom_enabled:
		smooth_step_zoom(dir, focus, factor_weight)
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_wheel_time < 50:
		return
	_last_wheel_time = now
	var idir: int = int(signf(dir))
	if floor_z <= 0.0 and (zoom.x < float(zs[0]) - 0.001 or idir < 0):
		var z0: float = zoom.x
		var bot: float = strat_full_z()
		if idir < 0 and z0 <= float(zs[0]) + 0.001:
			set_zoom_at(maxf(min_zoom(), bot if z0 > bot + 0.001 else z0 * STRAT_WHEEL), focus)
			return
		if idir > 0 and z0 < float(zs[0]) - 0.001:
			set_zoom_at(float(zs[0]) if z0 >= bot - 0.001 else minf(bot, z0 / STRAT_WHEEL), focus)
			return
	if min_zoom() < float(zs[0]):
		if idir < 0 and zoom.x <= float(zs[0]) + 0.001:
			set_zoom_at(min_zoom(), focus)
			return
		if idir > 0 and zoom.x < float(zs[0]) - 0.001:
			set_zoom_at(float(zs[0]), focus)
			return
	var idx: int = nearest_index(zoom.x)
	idx = clampi(idx + idir, 0, zs.size() - 1)
	set_zoom_at(float(zs[idx]), focus)


func snap_zoom(focus: Vector2) -> void :
	set_zoom_at(float(zs[nearest_index(zoom.x)]), focus)




func settle_zoom(focus: Vector2, dir: int) -> void :
	var z: float = clampf(zoom.x, min_zoom(), float(zs[zs.size() - 1]))
	var top: float = strat_top()
	var bot: float = strat_full_z()
	if floor_z <= 0.0 and z < top - 0.0001:


		if z <= bot + 0.0001:
			set_zoom_at(z, focus)
			return
		var tb: float = (log(top) - log(z)) / (log(top) - log(bot))
		var thb: float = 0.5 + 0.3 * float(signi(dir))
		_settle_z = maxf(min_zoom(), bot) if tb >= thb else top
		_settle_f = focus
		return
	if z < float(zs[0]) - 0.0001:
		set_zoom_at(min_zoom() if z < sqrt(min_zoom() * float(zs[0])) else float(zs[0]), focus)
		return
	var tgt: float = float(zs[nearest_index(z)])
	for i in zs.size() - 1:
		var lo: float = float(zs[i])
		var hi: float = float(zs[i + 1])
		if z >= lo and z <= hi:
			var t: float = (log(z) - log(lo)) / (log(hi) - log(lo))
			var th: float = 0.5 - 0.3 * float(signi(dir))
			tgt = hi if t >= th else lo
			break
	if absf(log(z) - log(tgt)) < 0.002:
		set_zoom_at(tgt, focus)
		return
	_settle_z = tgt
	_settle_f = focus


func is_settling() -> bool:
	return _settle_z > 0.0 or _dive_t >= 0.0


func nearest_index(z: float) -> int:
	var best: int = 0
	var bd: float = 1000000000.0
	for i in zs.size():
		var d: float = absf(log(z) - log(float(zs[i])))
		if d < bd:
			bd = d
			best = i
	return best


func center_on(p: Vector2) -> void :
	position = p
	_clamp()


func _clamp() -> void :
	var z: float = maxf(0.01, zoom.x)
	var k: float = strat_k()
	if k > 0.0:
		var r: Array = _pos_range(z)
		var rb: = Vector2.ONE * (RUBBER_PX / z * k)
		position = position.clamp((r[0] as Vector2) - rb, (r[1] as Vector2) + rb)
	else:
		var half: Vector2 = view_size() * 0.5 / z
		position.x = _clamp_axis(position.x, half.x, world_px.x, margin_left_px / z, margin_right_px / z)
		position.y = _clamp_axis(position.y, half.y, world_px.y, margin_top_px / z, margin_bottom_px / z)


	if zoom.x < 1.0:
		var st: float = 1.0 / zoom.x
		position = (position / st).round() * st



func _hard_range(z: float) -> Array:
	var half: Vector2 = view_size() * 0.5 / z
	var a: Vector2 = _axis_range(half.x, world_px.x, margin_left_px / z, margin_right_px / z, 0.0)
	var b: Vector2 = _axis_range(half.y, world_px.y, margin_top_px / z, margin_bottom_px / z, 0.0)
	return [Vector2(a.x, b.x), Vector2(a.y, b.y)]




static func _clamp_axis(pos: float, half: float, size: float, m0: float, m1: float) -> float:
	var lo: float = half - m0
	var hi: float = size - half + m1
	if lo > hi:
		return size * 0.5 - (m0 - m1) * 0.5
	return clampf(pos, lo, hi)



func free_rect() -> Rect2:
	var z: float = maxf(0.01, zoom.x)
	var vs: Vector2 = view_size()
	var tl: Vector2 = screen_to_world(Vector2(margin_left_px, margin_top_px))
	return Rect2(tl, Vector2(vs.x - margin_left_px - margin_right_px, vs.y - margin_top_px - margin_bottom_px) / z)



func _glide(delta: float) -> void :
	var dt: float = minf(delta, 0.05)
	if dt <= 0.0 or is_held() or _dive_t >= 0.0 or strat_k() <= 0.0:
		return
	var z: float = maxf(0.01, zoom.x)
	var r: Array = _pos_range(z)
	var c: Vector2 = position.clamp(r[0], r[1])
	if maxf(absf(position.x - c.x), absf(position.y - c.y)) * z >= 1.0:
		var f: float = 1.0 - exp( - dt * 14.0)
		var p: Vector2 = position
		for ax in 2:
			var dpx: float = (c[ax] - position[ax]) * z
			var mpx: float = signf(dpx) * minf(absf(dpx), maxf(1.0, absf(dpx) * f))
			p[ax] = position[ax] + mpx / z
		position = p
		_clamp()



func shake(big: bool) -> void :
	if big:
		_shake_seq = [Vector2(2, 0), Vector2(-1, 1), Vector2(1, -2), Vector2(-2, 1), Vector2(1, 1), Vector2(0, -1), Vector2(1, 0), Vector2(0, 0)]
	else:
		_shake_seq = [Vector2(1, 0), Vector2(-1, 1), Vector2(0, -1), Vector2(0, 0)]
	_shake_i = 0
	_shake_t = 0.0
	_shake_step = 0.033



func shake_pattern(seq: Array, step: float) -> void :
	_shake_seq = seq
	_shake_i = 0
	_shake_t = 0.0
	_shake_step = step


func _process(delta: float) -> void :
	_glide(delta)
	if _dive_t >= 0.0:
		_dive_t = minf(DIVE_S, _dive_t + minf(delta, 0.05))
		var e: float = smoothstep(0.0, 1.0, _dive_t / DIVE_S)
		var z1: float = exp(lerpf(log(_dive_z0), log(DIVE_Z), e))
		zoom = Vector2(z1, z1)
		var fr: Rect2 = Rect2(Vector2(margin_left_px, margin_top_px), view_size() - Vector2(margin_left_px + margin_right_px, margin_top_px + margin_bottom_px))
		var f: Vector2 = _dive_f0.lerp(fr.get_center(), e)
		position = _dive_w - (f - view_size() * 0.5) / z1
		_clamp()
		zoom_changed.emit(z1)
		if _dive_t >= DIVE_S:
			_dive_t = -1.0
	if _settle_z > 0.0:
		var lz: float = log(maxf(zoom.x, 0.01))
		var lt: float = log(_settle_z)
		var spd: float = smooth_zoom_speed if smooth_zoom_enabled else 16.0
		var nl: float = lerpf(lz, lt, 1.0 - exp( - minf(delta, 0.05) * spd))
		if absf(nl - lt) < 0.003:
			nl = lt
		_zoom_at(_settle_z if nl == lt else exp(nl), _settle_f)
		if nl == lt:
			_settle_z = 0.0
			_target_z = 0.0
	if _shake_seq.is_empty():
		return
	_shake_t += delta
	while _shake_t >= _shake_step and not _shake_seq.is_empty():
		_shake_t -= _shake_step
		var v: Vector2 = _shake_seq[_shake_i]
		offset = v / zoom.x
		_shake_i += 1
		if _shake_i >= _shake_seq.size():
			_shake_seq = []
			offset = Vector2.ZERO
