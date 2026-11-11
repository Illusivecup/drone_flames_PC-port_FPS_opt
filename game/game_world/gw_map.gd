extends "res://game/game_world/gw_base.gd"




func _add_object_id(sid: int, x: int, y: int, kind: int) -> int:
	var id: int
	if not _free_ids.is_empty():
		id = _free_ids[_free_ids.size() - 1]
		_free_ids.resize(_free_ids.size() - 1)
		obj_spr[id] = sid
		obj_x[id] = x
		obj_y[id] = y
		obj_state[id] = 0
		obj_kind[id] = kind
		if id < obj_hidden.size():
			obj_hidden[id] = 0
		if id < obj_arch.size():
			obj_arch[id] = 0
	else:
		id = obj_spr.size()
		obj_spr.append(sid)
		obj_x.append(x)
		obj_y.append(y)
		obj_state.append(0)
		obj_kind.append(kind)
		obj_hidden.resize(obj_spr.size())
		obj_arch.resize(obj_spr.size())
	var ck: ObjChunk = objects.chunk_at_cell(x, y + spr_fd[sid] - 1)
	ck.ids.append(id)
	ck.mark()
	return id


func add_object(sprite_name: String, cell: Vector2i, kind: int) -> int:
	if not spr_index.has(sprite_name):
		push_warning("unknown sprite " + sprite_name)
		return -1
	return _add_object_id(int(spr_index[sprite_name]), cell.x, cell.y, kind)


func remove_object(id: int) -> void :
	if id < 0 or obj_state[id] == 2:
		return
	obj_state[id] = 2
	obj_fix.erase(id)
	var sid: int = obj_spr[id]
	var ck: ObjChunk = objects.chunk_at_cell(obj_x[id], obj_y[id] + spr_fd[sid] - 1)
	var k: int = ck.ids.find(id)
	if k >= 0:
		ck.ids.remove_at(k)
	ck.mark()
	_free_ids.append(id)


func _mark_obj_chunk(id: int) -> void :
	var sid: int = obj_spr[id]
	objects.chunk_at_cell(obj_x[id], obj_y[id] + spr_fd[sid] - 1).mark()


func remove_tree_at(c: Vector2i) -> void :
	var i: int = c.y * data.w + c.x
	if tree_at.has(i):
		remove_object(int(tree_at[i]))
		tree_at.erase(i)


func obj_sort_key(id: int) -> int:
	return (obj_y[id] + spr_fd[obj_spr[id]]) * 65536 + obj_x[id]


func draw_object(ci: CanvasItem, id: int, phase: int) -> void :
	var st: int = obj_state[id]
	if st == 2 or (id < obj_hidden.size() and obj_hidden[id] != 0):
		return
	var knd: int = obj_kind[id]
	if knd == KIND_TREE:
		var lod: int = GameConfig.eff_object_lod()
		if lod > 0 and camera != null:
			var zx: float = camera.zoom.x
			if lod == 1:
				if zx < 0.35 and (id & 3) == 1:
					return
			elif lod >= 2:
				if zx < 0.32 and (id % 3) != 0:
					return
				elif zx < 0.48 and (id & 1) != 0:
					return
	var s: int = obj_spr[id]
	if id < obj_arch.size() and obj_arch[id] != 0 and obj_arch[id] < arch_tab.size():
		var atb: PackedInt32Array = arch_tab[obj_arch[id]]
		if s < atb.size():
			s = atb[s]
	var ds: int = DmgStages.sid_for(self, id, s, st) if DmgStages.on else -1
	if ds >= 0:
		s = ds
	elif st == 1 and spr_ruin[s] >= 0:
		s = spr_ruin[s]
	var r: Rect2 = spr_rect[s]
	var fr: int = 0
	var nf: int = spr_frames[s]
	if st == 0 and obj_fix.has(id):
		fr = mini(int(obj_fix[id]), nf - 1)
	elif nf > 1 and objects.sway_enabled and obj_kind[id] == KIND_TREE:
		fr = (phase + id) % nf
	var a: Vector2 = spr_anchor[s]
	var pos: = Vector2(obj_x[id] * CELL - a.x, (obj_y[id] + spr_fd[s]) * CELL - a.y)
	ci.draw_texture_rect_region(spr_tex[s], Rect2(pos, r.size), Rect2(r.position.x + r.size.x * fr, r.position.y, r.size.x, r.size.y))



func obj_origin(id: int) -> Vector2:
	var s: int = obj_spr[id]
	var a: Vector2 = spr_anchor[s]
	return Vector2(obj_x[id] * CELL - a.x, (obj_y[id] + spr_fd[s]) * CELL - a.y)



func set_obj_frame(id: int, sprite_name: String, frame: int) -> void :
	if not spr_index.has(sprite_name):
		return
	var sid: int = int(spr_index[sprite_name])
	if obj_spr[id] == sid and int(obj_fix.get(id, -1)) == frame:
		return
	obj_spr[id] = sid
	obj_fix[id] = frame
	_mark_obj_chunk(id)


func fx_atlas_of(sprite_name: String) -> SpriteAtlas:
	return fx.atlas_of.get(sprite_name, fx_atlas)


func object_rect(id: int) -> Rect2i:
	var s: int = obj_spr[id]
	return Rect2i(obj_x[id], obj_y[id], spr_fw[s], spr_fd[s])



func set_map_mode(m: int) -> void :
	m = clampi(m, 0, MAP_MODE_NAMES.size() - 1)
	if m == map_mode:
		return
	map_mode = m
	map_mode_changed.emit(m)


func country_by_id(id: int) -> Country:
	if id <= 0 or id > countries.size():
		return null
	return countries[id - 1]


func _update_territory_colors() -> void :
	var cols: = PackedColorArray()
	cols.resize(9)
	for i in 9:
		cols[i] = Color(0, 0, 0, 0)
	for c in countries:
		if c.id < 9:
			cols[c.id] = c.color
	for spr: Sprite2D in [territory, territory_border]:
		var m: ShaderMaterial = spr.material
		m.set_shader_parameter("colors", cols)
		if data != null:
			m.set_shader_parameter("world_size", Vector2(data.w, data.h))


func can_found_city(cell: Vector2i, kind: int, adapt: bool = false) -> Dictionary:




	var plan: Dictionary = CityGen.plan(data, atlas, cell, kind, Hash32.h2(cell.x, cell.y, data.world_seed))
	if bool(plan["ok"]) or not adapt or not Biome.is_natural_land(data.get_biome(cell.x, cell.y)):
		return plan
	for r: int in [6, 12, 18]:
		for k in 8:
			var q: Vector2i = cell + Vector2i([1, 1, 0, -1, -1, -1, 0, 1][k], [0, 1, 1, 1, 0, -1, -1, -1][k]) * r
			if not data.inside(q.x, q.y) or data.get_owner_id(q.x, q.y) != data.get_owner_id(cell.x, cell.y):
				continue
			var p2: Dictionary = CityGen.plan(data, atlas, q, kind, Hash32.h2(q.x, q.y, data.world_seed))
			if bool(p2["ok"]):
				p2["center"] = q
				return p2
	return plan


func city_at_cell(c: Vector2i) -> City:
	for city: City in cities:
		if absi(city.center.x - c.x) <= city.radius and absi(city.center.y - c.y) <= city.radius:
			return city
	return null







func _grow_city(city: City, ignore_cost: bool = false) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if city.claim_done:
		return out
	var o: int = city.country_id
	var c: Vector2i = city.center
	var w: int = data.w
	var h: int = data.h
	var lim: int = city.claim_max
	var next: Array[Vector3i] = []


	var dirs: Array[Vector2i] = DIRS8
	var occ: Array[Vector2i] = []
	var br: Array = BORDER_GAP.bridges(self, city) if _gtab.is_empty() else BORDER_GAP.bridges_t(_gtab, city)
	var scan: int = lim * 13 / 10

	var hb: bool = not br.is_empty()
	var bx0: int = 1 << 30
	var by0: int = 1 << 30
	var bx1: int = - (1 << 30)
	var by1: int = - (1 << 30)
	for e: PackedInt32Array in br:
		scan = maxi(scan, maxi(absi(e[0] - c.x), absi(e[1] - c.y)) + e[3])
		bx0 = mini(bx0, e[4])
		by0 = mini(by0, e[5])
		bx1 = maxi(bx1, e[6])
		by1 = maxi(by1, e[7])
	var gap: Array = BORDER_GAP.ctx(self, c, scan, o) if _gtab.is_empty() else BORDER_GAP.ctx_t(_gtab, c, scan, o)
	var hg: bool = not gap.is_empty()
	var ext: int = BORDER_GAP.EXT
	city.grow_ticks += 1



	var ow: PackedByteArray = data.owners
	var bio: PackedByteArray = data.biome
	var fl: PackedByteArray = data.flags
	var bn: PackedByteArray = border_noise
	var oct: bool = BORDER_GAP.soft_on
	var w2: int = 2 * w
	var h2: int = 2 * h
	var mid: int = int(BORDER_FILL.MID_W)
	var vis: Dictionary = city.visited
	var claimed: PackedInt32Array = PackedInt32Array()
	for f: Vector3i in city.frontier:
		if f.z > 0 and not ignore_cost:
			next.append(Vector3i(f.x, f.y, f.z - 1))
			continue
		for d: Vector2i in dirs:
			var nx: int = f.x + d.x
			var ny: int = f.y + d.y
			if nx < 1 or ny < 1 or nx >= w - 1 or ny >= h - 1:
				continue
			var i: int = ny * w + nx
			if vis.has(i):
				continue
			var cheb: int = maxi(absi(nx - c.x), absi(ny - c.y))
			var wob: int = (int(bn[i]) - 128) * lim / 460
			var nv: int = 0
			if oct and (hg or cheb * 2 >= lim):

				var x3: int = (nx * 3) % w2
				var y3: int = (ny * 3) % h2
				if x3 >= w:
					x3 = w2 - 1 - x3
				if y3 >= h:
					y3 = h2 - 1 - y3
				var x7: int = (nx * 7) % w2
				var y7: int = (ny * 7) % h2
				if x7 >= w:
					x7 = w2 - 1 - x7
				if y7 >= h:
					y7 = h2 - 1 - y7
				nv = ((int(bn[i]) - 128) * 8 + (int(bn[y3 * w + x3]) - 128) * 5 + (int(bn[y7 * w + x7]) - 128) * 3) / 16
			if oct and cheb * 2 >= lim:
				wob = nv * lim / 320
			var beyond: bool = cheb > lim + wob
			var own: int = ow[i]
			if beyond and hb and nx >= bx0 and ny >= by0 and nx <= bx1 and ny <= by1 and BORDER_GAP.in_bridge(br, c.x, c.y, nx, ny, float(wob)):
				if own == o:
					continue
				beyond = false
			elif beyond and ( not hg or cheb > lim + wob + ext):
				continue
			if own == o:
				vis[i] = true
				next.append(Vector3i(nx, ny, 0))
			elif own == 0:
				var b: int = bio[i]
				if not Biome.can_claim(b):
					continue
				vis[i] = true
				if hg and not BORDER_GAP.may_claim(gap, nx, ny, beyond, float(clampi(nv * mid * 3 / 128, - mid, mid)) if oct else 0.0, o):
					continue
				claimed.append(i)
				out.append(Vector2i(nx, ny))
				next.append(Vector3i(nx, ny, Biome.claim_wait(b)))
				if (fl[i] & WorldData.F_OCCUPIED) != 0:
					occ.append(Vector2i(nx, ny))
	ow = PackedByteArray()
	for i: int in claimed:
		data.owners[i] = o
	city.frontier = next
	if not occ.is_empty() and mil != null:
		preload("res://game/ad_relocate.gd").on_claim(self, occ, o, city)
	if next.is_empty():
		city.claim_done = true
	if not out.is_empty():
		_own_mark(out)
	return out


func _own_mark(cells: Array[Vector2i]) -> void :
	var lo: Vector2i = cells[0]
	var hi: Vector2i = cells[0]
	for p: Vector2i in cells:
		lo = lo.min(p)
		hi = hi.max(p)
	var r: = Rect2i(lo, hi - lo + Vector2i.ONE)
	_own_rect = _own_rect.merge(r) if _own_rect.has_area() else r



func _grow_initial(city: City, rings: int, per_frame: int = 6) -> void :
	var t0: int = Time.get_ticks_usec()
	var cells: Array[Vector2i] = []
	var n: int = mini(rings, per_frame if cad344 == null or per_frame >= 999 or cad344.step_dt >= Cad344.GROW_LONG_DT else mini(per_frame, Cad344.GROW_RINGS))
	for k in n:
		cells.append_array(_grow_city(city, true))
	top.flash_cells(cells)
	_checkpoints_dirty = true
	if rings > n and not city.claim_done:
		_delay(0.0, _grow_initial.bind(city, rings - n))
	if rail != null:
		rail.pt("city_land" if per_frame < 999 else "capital_land", t0)


func country_stable(country_id: int) -> bool:
	var c: Country = country_by_id(country_id)
	if c == null:
		return false
	for id in c.city_ids:
		if not cities[id].claim_done:
			return false
	return true


func _expand_tick(part: int = -1, slices: int = EXP_SLICES) -> void :
	var mig: int = 0
	_gtab = BORDER_GAP.table(self)
	for city: City in cities:
		if part >= 0 and city.id % slices != part:
			continue
		if city.claim_v < 2 and mig < 2:
			if city.claim_v == 0 and city.claim_max == int([104, 52, 27][clampi(city.kind, 0, 2)]):
				city.claim_max = int(CityGen.params(city.kind)["claim"])
			city.claim_v = 2
			if city.country_id != 0 and not _warp_once.has(city.country_id) and not _warp_done.has(city.country_id):
				_warp_once[city.country_id] = true
				enclave_check(city.country_id)
			mig += 1
			if city.claim_done and city.country_id != 0:
				BORDER_GAP.reopen(self, city)
			BORDER_GAP.tab_set(_gtab, city)
		if naval != null and not naval.grows(city):
			continue
		var cells: Array[Vector2i] = _grow_city(city)
		if city.claim_done:
			BORDER_GAP.tab_set(_gtab, city)
		if not cells.is_empty():
			top.flash_cells(cells)
			_checkpoints_dirty = true
		elif city.claim_done and not city.visited.is_empty():
			city.visited = {}
			_checkpoints_dirty = true
			enclave_check(city.country_id)
	_gtab = []
	if slices == EXP_SLICES or part % (slices / EXP_SLICES) == slices / EXP_SLICES - 1:
		_fill_tick()


func _flush_territory() -> void :
	if data.owners_dirty or _own_rect.has_area():
		territory_img.set_data(data.w, data.h, false, Image.FORMAT_L8, data.owners)
		territory_tex.update(territory_img)
		var part: Rect2i = Rect2i() if data.owners_dirty else _own_rect
		data.owners_dirty = false
		_own_rect = Rect2i()
		if map_layer != null:
			map_layer.territory_changed(part)



func _enc_drain() -> void :
	if not _enc_job.is_empty() and int(_enc_job.get("task", -1)) >= 0:
		WorkerThreadPool.wait_for_task_completion(int(_enc_job["task"]))
	_enc_job = {}
	_enc_queue.clear()
	_fill_q.clear()
	_xfer_q.clear()
	_warp_once.clear()
	_warp_done.clear()





func _smooth_apply(o: int, sm: Array) -> void :
	var cl: PackedInt32Array = sm[0]
	var to: PackedInt32Array = sm[1]
	var fr: PackedInt32Array = sm[2]
	var w: int = data.w
	var stop_fl: int = WorldData.F_OCCUPIED | WorldData.F_CITY | WorldData.F_ROAD | WorldData.F_BRIDGE
	var moved: Array[Vector2i] = []
	var cnt: = PackedInt32Array()
	cnt.resize(256)
	var none: = PackedInt32Array()
	for k in cl.size():
		var gi: int = cl[k]
		var t: int = to[k]
		var f: int = fr[k]
		if data.owners[gi] != f or gi < 2 * w + 2 or gi >= data.owners.size() - 2 * w - 2:
			continue

		if BORDER_FILL.edge_rule(data.owners, data.biome, w, gi, o, none, cnt) != t:
			continue
		if f != 0 and (data.flags[gi] & stop_fl) != 0:
			continue
		if t != 0 and f != 0 and diplo != null and diplo.at_war(o, t):
			continue
		data.owners[gi] = t
		moved.append(Vector2i(gi % w, gi / w))
	if not moved.is_empty():
		fill_moved += moved.size()
		_own_mark(moved)
		_checkpoints_dirty = true



func _fill_cities() -> Array:
	var out: Array = []
	for c: City in cities:
		if c.country_id != 0:
			out.append(PackedInt32Array([c.center.x, c.center.y, BORDER_GAP.reach(c.radius), c.country_id, c.claim_max]))
	return out


func _fill_tick() -> void :
	if _fill_q.is_empty() and _xfer_q.is_empty():
		return
	var w: int = data.w
	var ow: PackedByteArray = data.owners
	var n_all: int = ow.size()
	var done: Array = []
	var moved: Array[Vector2i] = []
	var wr: = PackedInt32Array()
	var budget: int = FILL_CAP
	for o: int in _fill_q.keys():
		if budget <= 0:
			break
		var e: Array = _fill_q[o]
		var cells_f: PackedInt32Array = e[0]
		var st: PackedInt32Array = e[1]
		var r: int = int(e[2])
		var k: int = maxi(int(e[3]), st[r] if r < st.size() else cells_f.size())
		var b: int = st[r + 1] if r + 1 < st.size() else cells_f.size()
		var stop: int = mini(b, k + budget)
		budget -= stop - k
		var ft: PackedInt32Array = e[4] if e.size() > 4 else PackedInt32Array()
		while k < stop:
			var gi: int = cells_f[k]
			var to: int = ft[k] if k < ft.size() else o
			k += 1
			if ow[gi] != 0 or not Biome.can_claim(data.biome[gi]):
				continue
			var x: int = gi % w
			if x < 1 or x >= w - 1 or gi < w or gi >= n_all - w:
				continue
			if ow[gi - 1] != to and ow[gi + 1] != to and ow[gi - w] != to and ow[gi + w] != to\
			and ow[gi - w - 1] != to and ow[gi - w + 1] != to and ow[gi + w - 1] != to and ow[gi + w + 1] != to:
				continue
			if to != o:
				var tc: Country = country_by_id(to)
				if tc == null or tc.eliminated:
					continue
			moved.append(Vector2i(x, gi / w))
			wr.append(gi)
			wr.append(to)
		e[3] = k
		if k >= b:
			e[2] = r + 1
			if r + 1 >= st.size():
				done.append(o)
	for o2: int in done:
		_fill_q.erase(o2)
	done.clear()
	var stop_fl: int = WorldData.F_OCCUPIED | WorldData.F_CITY | WorldData.F_ROAD | WorldData.F_BRIDGE
	for o3: int in _xfer_q.keys():
		if budget <= 0:
			break
		var e3: Array = _xfer_q[o3]
		var xc: PackedInt32Array = e3[0]
		var xt: PackedInt32Array = e3[1]
		var xs: PackedInt32Array = e3[2]
		var xfr: PackedInt32Array = e3[5]
		var r3: int = int(e3[3])
		var k3: int = maxi(int(e3[4]), xs[r3] if r3 < xs.size() else xc.size())
		var b3: int = xs[r3 + 1] if r3 + 1 < xs.size() else xc.size()
		var stop3: int = mini(b3, k3 + budget)
		budget -= stop3 - k3
		while k3 < stop3:
			var gi3: int = xc[k3]
			var f3: int = xt[k3]
			var fr3: int = xfr[k3]
			k3 += 1
			if ow[gi3] != fr3 or (fr3 != 0 and (data.flags[gi3] & stop_fl) != 0):
				continue
			if fr3 == 0 and not Biome.can_claim(data.biome[gi3]):
				continue
			if fr3 != 0 and f3 != 0 and diplo != null and diplo.at_war(fr3, f3):
				continue
			var x3: int = gi3 % w
			if x3 < 1 or x3 >= w - 1 or gi3 < w or gi3 >= n_all - w:
				continue
			if ow[gi3 - 1] != f3 and ow[gi3 + 1] != f3 and ow[gi3 - w] != f3 and ow[gi3 + w] != f3\
			and ow[gi3 - w - 1] != f3 and ow[gi3 - w + 1] != f3 and ow[gi3 + w - 1] != f3 and ow[gi3 + w + 1] != f3:
				continue
			moved.append(Vector2i(x3, gi3 / w))
			wr.append(gi3)
			wr.append(f3)
		e3[4] = k3
		if k3 >= b3:
			e3[3] = r3 + 1
			if r3 + 1 >= xs.size():
				done.append(o3)
	for o4: int in done:
		_xfer_q.erase(o4)
	ow = PackedByteArray()
	if not moved.is_empty():
		for q in range(0, wr.size(), 2):
			data.owners[wr[q]] = wr[q + 1]
		fill_moved += moved.size()
		_own_mark(moved)
		_checkpoints_dirty = true


func enclave_check(cid: int) -> void :
	if cid > 0:
		_enc_queue[cid] = true


func _enclave_tick(dt: float) -> void :
	if not enclave_fix_on:
		return
	var t0: int = Time.get_ticks_usec()
	_enclave_tick2(dt)
	enc_main_us_max = maxi(enc_main_us_max, Time.get_ticks_usec() - t0)


func _enclave_tick2(dt: float) -> void :
	_enc_t += dt
	if _enc_t >= ENC_DT:
		_enc_t = 0.0
		for c: Country in countries:
			if not c.eliminated:
				_enc_queue[c.id] = true
	if not _enc_job.is_empty():
		if not job_ready(int(_enc_job["task"])):
			return
		WorkerThreadPool.wait_for_task_completion(int(_enc_job["task"]))
		_enc_apply(_enc_job)
		_enc_job = {}
	if _enc_queue.is_empty() or data == null:
		return
	var cid: int = int(_enc_queue.keys()[0])
	_enc_queue.erase(cid)
	_enc_job = {"o": cid, "w": data.w, "h": data.h, "owners": data.owners.duplicate(), "prot": _enc_protected(), "out": [], "data_id": data.get_instance_id(), "bio": data.biome.duplicate(), "drop": [], "fill": [], "cities": _fill_cities() if border_fill_on else [], "bn": border_noise, "lakes": data.lakes}


	if border_fill_on:
		var wl0: = PackedInt32Array()
		for c3: Country in countries:
			if c3.id != cid and diplo != null and diplo.at_war(cid, c3.id):
				wl0.append(c3.id)
		_enc_job["war"] = wl0
	if _warp_once.has(cid):
		_warp_once.erase(cid)
		_warp_done[cid] = true
		var wl: = PackedInt32Array()
		for c2: Country in countries:
			if c2.id != cid and diplo != null and diplo.at_war(cid, c2.id):
				wl.append(c2.id)
		_enc_job["xw"] = wl
	_enc_job["task"] = WorkerThreadPool.add_task(_enc_worker.bind(_enc_job), false, "enclaves")



func _enc_protected() -> Dictionary:
	var prot: Dictionary = {}
	for c: City in cities:
		prot[c.center.y * data.w + c.center.x] = true
	if mil != null:
		for f: Facility in mil.facilities:
			var fc: Vector2i = f.cell + f.size / 2
			if data.inside(fc.x, fc.y):
				prot[fc.y * data.w + fc.x] = true
			if data.inside(f.cell.x, f.cell.y):
				prot[f.cell.y * data.w + f.cell.x] = true
	return prot


func _enc_worker(job: Dictionary) -> void :
	var wet_box: Array = []
	job["out"] = enclave_scan(job["owners"], int(job["w"]), int(job["h"]), int(job["o"]), job["prot"], true, PackedByteArray(), job.get("bio", PackedByteArray()), wet_box)
	if not wet_box.is_empty():
		job["drop"] = water_islets(job["owners"], job["bio"], int(job["w"]), int(job["h"]), int(job["o"]), wet_box[0])
	if not (job.get("cities", []) as Array).is_empty():
		job["fill"] = BORDER_FILL.scan(job["owners"], job["bio"], int(job["w"]), int(job["h"]), int(job["o"]), job["cities"], job["bn"], job.get("lakes", []), job.get("war", PackedInt32Array()))
	if job.has("xw"):
		job["xf"] = BORDER_FILL.xfer(job["owners"], job["bio"], int(job["w"]), int(job["h"]), int(job["o"]), job["bn"], job["xw"], job.get("cities", []))
	if job.has("war"):
		job["sm"] = BORDER_FILL.smooth(job["owners"], job["bio"], int(job["w"]), int(job["h"]), int(job["o"]), job["war"], job.get("cities", []))






static func water_islets(own: PackedByteArray, bio: PackedByteArray, w: int, h: int, o: int, wet: PackedInt32Array) -> Array:
	var out: Array = []
	if wet.is_empty():
		return out
	var mark: = PackedByteArray()
	mark.resize(w * h)
	var dl: PackedInt32Array = PackedInt32Array([1, -1, w, - w, w + 1, w - 1, 1 - w, -1 - w])
	for c0: int in wet:
		if mark[c0] != 0:
			continue
		var comp: = PackedInt32Array([c0])
		mark[c0] = 1
		var land: bool = false
		var hd: int = 0
		while hd < comp.size():
			var c: int = comp[hd]
			hd += 1
			var cx: int = c % w
			var cy: int = c / w
			var edge: bool = cx == 0 or cy == 0 or cx == w - 1 or cy == h - 1
			for k in 8:
				if edge:
					var nx: int = cx + DIRS8[k].x
					var ny: int = cy + DIRS8[k].y
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
				var n: int = c + dl[k]
				if own[n] != o:
					continue
				if bio[n] > Biome.RIVER:
					land = true
				elif mark[n] == 0:
					mark[n] = 1
					comp.append(n)
		if not land:
			out.append(comp)
	return out




static func enclave_scan(own_in: PackedByteArray, w: int, h: int, o: int, prot: Dictionary, fix: bool, bio: PackedByteArray = PackedByteArray(), wbio: PackedByteArray = PackedByteArray(), wet_box: Array = []) -> Array:
	var own: PackedByteArray = own_in
	var x0: int = w
	var y0: int = h
	var x1: int = -1
	var y1: int = -1
	var wet: = PackedInt32Array()
	var collect: bool = not wbio.is_empty()
	var i: int = own.find(o, 0)
	while i >= 0:
		var x: int = i % w
		var y: int = i / w
		x0 = mini(x0, x)
		x1 = maxi(x1, x)
		y0 = mini(y0, y)
		y1 = maxi(y1, y)
		if collect and wbio[i] <= Biome.RIVER:
			wet.append(i)
		i = own.find(o, i + 1)
	if collect:
		wet_box.append(wet)
	if x1 < 0:
		return [] if fix else [0, 0, 0]
	x0 = maxi(0, x0 - 1)
	y0 = maxi(0, y0 - 1)
	x1 = mini(w - 1, x1 + 1)
	y1 = mini(h - 1, y1 + 1)
	var bw: int = x1 - x0 + 1
	var bh: int = y1 - y0 + 1
	var mark: = PackedByteArray()
	mark.resize(bw * bh)
	var q: = PackedInt32Array()
	for x in bw:
		for y: int in [0, bh - 1]:
			var gi: int = (y0 + y) * w + x0 + x
			if own[gi] != o and mark[y * bw + x] == 0:
				mark[y * bw + x] = 1
				q.append(y * bw + x)
	for y in range(1, bh - 1):
		for x: int in [0, bw - 1]:
			var gi2: int = (y0 + y) * w + x0 + x
			if own[gi2] != o and mark[y * bw + x] == 0:
				mark[y * bw + x] = 1
				q.append(y * bw + x)
	var head: int = 0
	var gd: int = y0 * w + x0
	var gw_: int = w - bw
	while head < q.size():
		var li: int = q[head]
		head += 1
		var lx: int = li % bw
		var ly: int = li / bw
		var g: int = li + ly * gw_ + gd
		if lx + 1 < bw and mark[li + 1] == 0 and own[g + 1] != o:
			mark[li + 1] = 1
			q.append(li + 1)
		if lx > 0 and mark[li - 1] == 0 and own[g - 1] != o:
			mark[li - 1] = 1
			q.append(li - 1)
		if ly + 1 < bh and mark[li + bw] == 0 and own[g + w] != o:
			mark[li + bw] = 1
			q.append(li + bw)
		if ly > 0 and mark[li - bw] == 0 and own[g - w] != o:
			mark[li - bw] = 1
			q.append(li - bw)
	var out: Array = []
	var pockets: int = 0
	var neutral_n: int = 0
	var kept: int = 0
	var li2: int = -1
	while true:
		li2 = mark.find(0, li2 + 1)
		if li2 < 0:
			break
		if own[(y0 + li2 / bw) * w + x0 + li2 % bw] == o:
			continue

		var cells: = PackedInt32Array()
		var foreign: bool = false
		var protected_: bool = false
		var land_any: bool = bio.is_empty()
		mark[li2] = 2
		cells.append(li2)
		var hd: int = 0
		while hd < cells.size():
			var cl: int = cells[hd]
			hd += 1
			var cx: int = cl % bw
			var cy: int = cl / bw
			var g: int = (y0 + cy) * w + x0 + cx
			if own[g] != 0:
				foreign = true
				if prot.has(g):
					protected_ = true
			if not bio.is_empty() and Biome.can_claim(bio[g]):
				land_any = true
			if cx + 1 < bw and mark[cl + 1] == 0 and own[g + 1] != o:
				mark[cl + 1] = 2
				cells.append(cl + 1)
			if cx > 0 and mark[cl - 1] == 0 and own[g - 1] != o:
				mark[cl - 1] = 2
				cells.append(cl - 1)
			if cy + 1 < bh and mark[cl + bw] == 0 and own[g + w] != o:
				mark[cl + bw] = 2
				cells.append(cl + bw)
			if cy > 0 and mark[cl - bw] == 0 and own[g - w] != o:
				mark[cl - bw] = 2
				cells.append(cl - bw)
		if not land_any:
			continue
		pockets += 1
		if not foreign:
			neutral_n += 1
		var take: bool = not foreign or (cells.size() <= ENC_MAX and not protected_)
		if not take:
			kept += 1
		elif fix:
			for cl2: int in cells:
				var g2: int = (y0 + cl2 / bw) * w + x0 + cl2 % bw
				out.append([g2, int(own[g2])])
	return out if fix else [pockets, neutral_n, kept]


func _enc_apply(job: Dictionary) -> void :
	if int(job["data_id"]) != data.get_instance_id():
		return
	var o: int = int(job["o"])
	var c: Country = country_by_id(o)
	if c == null or c.eliminated:
		return
	var n: int = 0
	var stale: bool = false
	var moved: Array[Vector2i] = []
	for e: Array in job["out"]:
		var gi: int = int(e[0])
		if data.owners[gi] != int(e[1]):
			stale = true
			continue
		if Biome.can_claim(data.biome[gi]) or int(e[1]) == 0:
			data.owners[gi] = o
			n += 1
			moved.append(Vector2i(gi % data.w, gi / data.w))
	for comp: PackedInt32Array in job.get("drop", []):
		if _islet_still(comp, o):
			for gi2: int in comp:
				data.owners[gi2] = 0
				moved.append(Vector2i(gi2 % data.w, gi2 / data.w))
			n += comp.size()
	var fl: Array = job.get("fill", [])
	if not fl.is_empty():
		_fill_q[o] = [fl[0], fl[1], 0, 0, fl[2] if fl.size() > 2 else PackedInt32Array()]
	var sm: Array = job.get("sm", [])
	if not sm.is_empty():
		_smooth_apply(o, sm)
	var xf: Array = job.get("xf", [])
	if not xf.is_empty():
		_xfer_q[o] = [xf[0], xf[1], xf[2], 0, 0, xf[3]]
	if stale:
		enclave_check(o)
	if n > 0:
		enc_moved += n
		_own_mark(moved)
		_checkpoints_dirty = true




func _islet_still(comp: PackedInt32Array, o: int) -> bool:
	var w: int = data.w
	var inside: Dictionary = {}
	for gi: int in comp:
		if data.owners[gi] != o or not Biome.is_water(data.biome[gi]):
			return false
		inside[gi] = true
	for gi: int in comp:
		var cx: int = gi % w
		var cy: int = gi / w
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx: int = cx + dx
				var ny: int = cy + dy
				if nx < 0 or ny < 0 or nx >= w or ny >= data.h:
					continue
				var n: int = ny * w + nx
				if data.owners[n] == o and not inside.has(n):
					return false
	return true


func _delay(dt: float, fn: Callable) -> void :
	_delayed.append([game_time + dt, fn])







func say(to: Variant, text: Variant) -> void :
	if player == null or to == null:
		return
	var cid: int = (to as Country).id if to is Country else int(to)
	if cid == player.id:
		_say_now(text)



func say2(a: Variant, b: Variant, text: Variant) -> void :
	if player == null:
		return
	for to: Variant in [a, b]:
		if to != null and ((to as Country).id if to is Country else int(to)) == player.id:
			_say_now(text)
			return



func _say_now(text: Variant) -> void :
	var was: bool = ui_mute
	ui_mute = false
	message.emit(Loc.msg(text))
	ui_mute = was



func news_m(m: Variant, col: String) -> void :
	news.emit(Loc.msg(m), col)




func job_ready(task: int) -> bool:
	if lab_tick >= 0 and not net_driven:
		while not WorkerThreadPool.is_task_completed(task):
			OS.delay_usec(50)
		return true
	if not net_driven:
		return WorkerThreadPool.is_task_completed(task)


	if not _job_first.has(task):
		_job_first[task] = net_tick
	if net_tick - int(_job_first[task]) < NetConfig.JOB_DELAY_TICKS:
		return false
	_job_first.erase(task)
	if not WorkerThreadPool.is_task_completed(task):
		var us: int = Time.get_ticks_usec()
		while not WorkerThreadPool.is_task_completed(task):
			OS.delay_usec(200)
		perf_job_wait_max = maxf(perf_job_wait_max, float(Time.get_ticks_usec() - us) / 1000.0)
	return true
