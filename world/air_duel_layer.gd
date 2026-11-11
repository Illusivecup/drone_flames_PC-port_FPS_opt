class_name AirDuelLayer
extends RefCounted





const TRAIL_STEP: float = 3.0
const VAPOR_LIFE: float = 0.9
const VAPOR_HOLD: float = 0.4

const TURN_VAPOR: float = 0.7
static var _hd: Dictionary = {}
static var _vap: Dictionary = {}


static func _push(store: Dictionary, key: int, p: Vector2, now: float) -> void :
	if not store.has(key):
		store[key] = [PackedVector2Array(), PackedFloat32Array()]
	var e: Array = store[key]
	var pts: PackedVector2Array = e[0]
	if pts.is_empty() or pts[pts.size() - 1].distance_to(p) >= TRAIL_STEP:
		var ts: PackedFloat32Array = e[1]
		pts.append(p)
		ts.append(now)
		e[0] = pts
		e[1] = ts


static func _prune(store: Dictionary, life: float, now: float) -> void :
	for key: int in store.keys():
		var e: Array = store[key]
		var pts: PackedVector2Array = e[0]
		var ts: PackedFloat32Array = e[1]
		var cut: int = 0
		while cut < ts.size() and (now - ts[cut] > life or ts[cut] > now):
			cut += 1
		if cut >= ts.size():
			store.erase(key)
			continue
		if cut > 0:
			e[0] = pts.slice(cut)
			e[1] = ts.slice(cut)


static func draw(ci: CanvasItem, gw: GameWorld, see: Callable) -> void :
	var now: float = FxLayer.vt
	var air: Air = gw.mil.air
	for a: Aircraft in air.aircraft:

		if a.type != Aircraft.Type.HELI and a.state != Aircraft.State.DEAD and a.airborne():
			var lh: Array = _hd.get(a.id, [a.heading, now])
			var dtv: float = now - float(lh[1])
			if dtv >= 0.1:
				if dtv < 0.5 and absf(wrapf(a.heading - float(lh[0]), - PI, PI)) / dtv > TURN_VAPOR * float(Air.SPEC[a.type]["turn"]):
					AirDuel.vapor[a.id] = now
				_hd[a.id] = [a.heading, now]
			elif not _hd.has(a.id):
				_hd[a.id] = lh
		if a.state != Aircraft.State.DEAD and a.airborne() and now - float(AirDuel.vapor.get(a.id, -99.0)) < VAPOR_HOLD and now >= float(AirDuel.vapor.get(a.id, -99.0)):
			var side: Vector2 = Vector2.from_angle(a.heading + PI * 0.5) * 4.0
			_push(_vap, a.id * 2, a.pos + side, now)
			_push(_vap, a.id * 2 + 1, a.pos - side, now)
	_prune(_vap, VAPOR_LIFE, now)
	for key2: int in _vap.keys():
		var e2: Array = _vap[key2]
		var p2: PackedVector2Array = e2[0]
		var t2: PackedFloat32Array = e2[1]
		if p2.size() < 2 or not see.call(p2[p2.size() - 1]):
			continue
		for j in range(1, p2.size()):
			var age2: float = clampf((now - t2[j]) / VAPOR_LIFE, 0.0, 1.0)
			ci.draw_line(p2[j - 1].round() + Vector2(0.5, 0.5), p2[j].round() + Vector2(0.5, 0.5), Color(1, 1, 1, 0.55 * (1.0 - age2)), 1.0)
