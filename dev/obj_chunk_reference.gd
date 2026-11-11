class_name ObjChunkReference
extends Node2D













const GUEST_MAX: int = 256
const CLOSE_PX: float = 96.0

var gw: GameWorld
var ids: PackedInt32Array = PackedInt32Array()
var sorted: bool = true
var phase: int = 0
var idx: int = 0
var left: ObjChunk = null
var right: ObjChunk = null
var guests: PackedInt32Array = PackedInt32Array()
var _dirty: bool = false
var _sig: int = -1
var need_guests: bool = false
var _list: PackedInt32Array = PackedInt32Array()




var _own: PackedInt32Array = PackedInt32Array()


var cover: Dictionary = {}
var _cover_ok: bool = false






func mark() -> void :
	_dirty = true
	_cover_ok = false
	queue_redraw()
	var ol: ObjectsLayer = get_parent() as ObjectsLayer
	if ol != null:
		ol.cover_ver += 1
	if right != null:
		right.need_guests = true


func _draw() -> void :
	if gw == null:
		return
	if not sorted:
		_resort()
	elif _dirty:
		_quick()
	var lp: int = left.phase if left != null else phase
	var ng: int = guests.size()
	var taken: PackedInt32Array = right.guests if right != null else PackedInt32Array()
	var nt: int = taken.size()
	if nt == 0 and ng == 0:
		for id in _list:
			gw.draw_object(self, id, phase)
		return


	var tk: Dictionary = {}
	for id in taken:
		tk[id] = true
	var gs: Dictionary = {}
	for id in guests:
		gs[id] = true
	var lids: Dictionary = {}
	if ng > 0 and left != null:
		for id in left.ids:
			lids[id] = true
	var llp: int = left.left.phase if left != null and left.left != null else lp
	for id in _list:
		if nt > 0 and tk.has(id):
			continue
		if ng > 0 and gs.has(id):
			gw.draw_object(self, id, lp if left == null or lids.has(id) else llp)
		else:
			gw.draw_object(self, id, phase)




func _depth_sort(src: Array) -> PackedInt32Array:
	var g: GameWorld = gw
	var n: int = src.size()
	var ks: = PackedInt64Array()
	ks.resize(n)
	var oy: PackedInt32Array = g.obj_y
	var ox: PackedInt32Array = g.obj_x
	var osp: PackedInt32Array = g.obj_spr
	var fd: PackedInt32Array = g.spr_fd
	for i in n:
		var id: int = src[i]
		if id >= 4194304 or id < 0:
			var arr: Array = src.duplicate()
			arr.sort_custom( func(a: int, b: int) -> bool: return g.obj_sort_key(a) < g.obj_sort_key(b))
			return PackedInt32Array(arr)
		ks[i] = ((oy[id] + fd[osp[id]]) * 65536 + ox[id]) * 4194304 + id
	ks.sort()
	var out: = PackedInt32Array()
	out.resize(n)
	for i in n:
		out[i] = ks[i] & 4194303
	return out



func _ids_sig() -> int:
	var s1: int = ids.size()
	var s2: int = 0
	for id in ids:
		s1 += id
		s2 = (s2 + id * id * 2654435761) & 140737488355327
	return (s1 * 1000003) ^ s2




func _quick() -> void :
	_dirty = false
	var sg: int = _ids_sig()
	if sg == _sig:
		need_guests = need_guests or not guests.is_empty()
		return
	_sig = sg
	var arr: Array = Array(ids)
	_own = _depth_sort(arr)
	if guests.is_empty():
		_list = _own
	else:
		_list = _depth_sort(arr + Array(guests))
	need_guests = true


func _resort() -> void :
	_dirty = false
	_own = _depth_sort(Array(ids))
	_sig = _ids_sig()
	var old: PackedInt32Array = guests
	var ol: ObjectsLayer = get_parent() as ObjectsLayer
	if ol != null and not bool(ol.call("near_view", self)):
		guests = PackedInt32Array()
		need_guests = true
	else:
		guests = _find_guests()
		need_guests = false
	if guests.is_empty():
		_list = _own
	else:
		_list = _depth_sort(Array(_own) + Array(guests))
	sorted = true
	if left != null and old != guests:
		left.queue_redraw()
	if right != null and old != guests:
		right.need_guests = true



func obj_rect(id: int) -> Rect2:
	var g: GameWorld = gw
	var st: int = g.obj_state[id]
	if st == 2 or (id < g.obj_hidden.size() and g.obj_hidden[id] != 0):
		return Rect2()
	var s: int = _spr_of(id)
	var a: Vector2 = g.spr_anchor[s]
	return Rect2(Vector2(g.obj_x[id] * GameWorld.CELL - a.x, (g.obj_y[id] + g.spr_fd[s]) * GameWorld.CELL - a.y), g.spr_rect[s].size)


func _spr_of(id: int) -> int:
	var g: GameWorld = gw
	var s: int = g.obj_spr[id]
	if id < g.obj_arch.size() and g.obj_arch[id] != 0 and g.obj_arch[id] < g.arch_tab.size():
		var atb: PackedInt32Array = g.arch_tab[g.obj_arch[id]]
		if s < atb.size():
			s = atb[s]
	if g.obj_state[id] == 1 and g.spr_ruin[s] >= 0:
		s = g.spr_ruin[s]
	return s


func _find_guests() -> PackedInt32Array:
	var out: = PackedInt32Array()
	if left == null or ids.is_empty():
		return out
	var src: Array = Array(left.ids) + Array(left.guests)
	if src.is_empty():
		return out

	var own_r: Array = []
	var min_x: float = INF
	for id in ids:
		var r: Rect2 = obj_rect(id)
		if r.size.x <= 0.0:
			continue
		own_r.append([id, r])
		min_x = minf(min_x, r.position.x)
	if own_r.is_empty():
		return out
	var cand: Array = []
	var all_l: Array = []
	for id: int in src:
		var r: Rect2 = left.obj_rect(id)
		if r.size.x <= 0.0:
			continue
		if r.end.x <= min_x - CLOSE_PX:
			continue
		var e: Array = [id, r]
		all_l.append(e)
		if r.end.x > min_x:
			cand.append(e)
	if cand.is_empty():
		return out
	var picked: Dictionary = {}
	var max_x: float = - INF
	for c: Array in cand:
		max_x = maxf(max_x, (c[1] as Rect2).end.x)
	for o: Array in own_r:
		var orr: Rect2 = o[1]
		if orr.position.x >= max_x:
			continue
		for c: Array in cand:
			if not picked.has(c[0]) and orr.intersects(c[1] as Rect2):
				picked[c[0]] = c[1]
	if picked.is_empty():
		return out


	var frontier: Array = picked.keys()
	while not frontier.is_empty() and picked.size() < GUEST_MAX:
		var nxt: Array = []
		for gid: int in frontier:
			var gr: Rect2 = picked[gid]
			var gk: int = gw.obj_sort_key(gid)
			for c: Array in all_l:
				var cid: int = c[0]
				if picked.has(cid) or gw.obj_sort_key(cid) <= gk:
					continue
				if gr.intersects(c[1] as Rect2):
					picked[cid] = c[1]
					nxt.append(cid)
		frontier = nxt
	for k: int in picked:
		out.append(k)
	out.sort()
	return out





func cover_map() -> Dictionary:
	if _cover_ok:
		return cover
	cover = {}
	_cover_ok = true
	var g: GameWorld = gw
	if g == null:
		return cover
	var ol: ObjectsLayer = get_parent() as ObjectsLayer
	for id in ids:
		if g.obj_kind[id] != GameWorld.KIND_BUILDING:
			continue
		var r: Rect2 = obj_rect(id)
		if r.size.x <= 0.0:
			continue
		var s: int = _spr_of(id)
		var fw: int = g.spr_fw[s]
		var x0: int = g.obj_x[id] * GameWorld.CELL
		var x1: int = x0 + fw * GameWorld.CELL
		var base: int = (g.obj_y[id] + g.spr_fd[s]) * GameWorld.CELL
		var tops: PackedInt32Array = ol.column_tops(s, int(r.position.x), int(r.position.y), x0, x1, base) if ol != null else PackedInt32Array()
		if tops.is_empty():
			continue
		var tmin: int = base
		for t in tops:
			tmin = mini(tmin, t)
		var e: Array = [x0, x1, base, tops, tmin]
		for cx in range(g.obj_x[id], g.obj_x[id] + fw):
			if not cover.has(cx):
				cover[cx] = []
			(cover[cx] as Array).append(e)
	return cover
