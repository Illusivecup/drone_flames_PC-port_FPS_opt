class_name DmgStages
extends RefCounted




















const STYLE_FILES: Array = ["east", "usa", "west", "asia", "clad"]
const ST_KEYS: Array = ["d1a", "d1b", "d2a", "d2b", "d3a", "d3b", "d4a", "d4b"]
const R_CELLS: Array = [2, 4, 7]
const FACADE_SPRITES: bool = false
const SHELL_P: float = 0.3

static var on: bool = false
static var tab: Dictionary = {}
static var key_of: Dictionary = {}
static var stage: Dictionary = {}
static var hits: Dictionary = {}
static var ruined: Dictionary = {}
static var _data_id: int = 0
static var _last_t: float = 0.0




static func register(w: GameWorld) -> void :
	tab.clear()
	key_of.clear()
	reset()
	var added: Array = []
	for k: String in STYLE_FILES:
		var a: SpriteAtlas = SpriteAtlas.load_atlas("res://assets/sprites/atlas_dmg314_%s.png" % k, "res://assets/sprites/atlas_dmg314_%s.json" % k, true)
		if a.sprites.is_empty():
			continue
		w._add_sprites(a)
		added.append_array(a.sprites.keys())
	if added.is_empty():
		on = false
		return
	var n0: int = w.spr_ruin.size()
	w.spr_ruin.resize(w.spr_rect.size())
	for i in range(n0, w.spr_rect.size()):
		w.spr_ruin[i] = -1
	for key: String in added:
		var base: String = key.get_slice("#", 0)
		var sk: int = ST_KEYS.find(key.get_slice("#", 1))
		var bsid: int = int(w.spr_index.get(base, -1))
		if bsid < 0 or sk < 0:
			continue
		if not tab.has(bsid):
			var arr: = PackedInt32Array()
			arr.resize(8)
			arr.fill(-1)
			tab[bsid] = arr
			key_of[base] = true
		var arr2: PackedInt32Array = tab[bsid]
		arr2[sk] = int(w.spr_index[key])
		tab[bsid] = arr2

	for bsid: int in tab.keys():
		var nm: String = w.spr_name[bsid]
		if not nm.begins_with("clad:"):
			continue
		var bstyle: String = nm.get_slice(">", 0).trim_prefix("clad:")
		var bn: String = nm.get_slice("/", 1)
		var src: int = int(w.spr_index.get(bn if bstyle == "east" else bstyle + ":" + bn, -1))
		if src >= 0 and tab.has(src):
			var arr3: PackedInt32Array = tab[bsid]
			var sa: PackedInt32Array = tab[src]
			for j in range(4, 8):
				arr3[j] = sa[j]
			tab[bsid] = arr3
	on = not tab.is_empty()
	print("[DmgStages] %d damage sprites for %d looks" % [added.size(), tab.size()])



static func reset() -> void :
	stage.clear()
	hits.clear()
	ruined.clear()
	_last_t = 0.0


static func _check(w: GameWorld) -> void :
	var did: int = w.data.get_instance_id() if w.data != null else 0
	if did != _data_id or w.game_time + 1.0 < _last_t:
		reset()
		_data_id = did
	_last_t = w.game_time



static func on_impact(w: GameWorld, p: Vector2, size: int) -> void :
	if not on or w == null or w.data == null or w.objects == null:
		return
	_check(w)
	var c: = Vector2i(floori(p.x / GameWorld.CELL), floori(p.y / GameWorld.CELL))
	var r: int = int(R_CELLS[clampi(size, 0, 2)])
	var box: = Rect2i(c - Vector2i(r + 8, r + 8), Vector2i(2 * r + 16, 2 * r + 16))
	for ck: ObjChunk in w.objects.chunks_in_rect(box):
		var dirty: bool = false
		for id in ck.ids:
			if w.obj_kind[id] != GameWorld.KIND_BUILDING or w.obj_state[id] == 2:
				continue
			var rr: Rect2i = w.object_rect(id)
			var qx: int = clampi(c.x, rr.position.x, rr.end.x - 1)
			var qy: int = clampi(c.y, rr.position.y, rr.end.y - 1)
			var d2: int = (qx - c.x) * (qx - c.x) + (qy - c.y) * (qy - c.y)
			if d2 > r * r:
				continue
			var hn: int = int(hits.get(id, 0)) + 1
			hits[id] = hn
			if w.obj_state[id] == 1:
				dirty = dirty or hn == 2
				continue
			if not tab.has(ArchStyle.draw_sid(w, id)):
				continue
			if size == 0 and d2 > 1 and randf() >= SHELL_P:
				continue
			var g0: int = int(stage.get(id, 0))
			var g: int = mini(2, g0 + (2 if size == 2 and d2 <= 4 else 1))
			if g != g0:
				stage[id] = g
				dirty = true
		if dirty:
			_redraw(ck)







static func _redraw(ck: ObjChunk) -> void :
	ck.queue_redraw()
	if ck.right != null and not ck.right.guests.is_empty():
		ck.right.queue_redraw()




static func sid_for(w: GameWorld, id: int, s: int, st: int) -> int:
	if not on or (st == 0 and stage.is_empty() and ruined.is_empty()):
		return -1
	var arr: Variant = tab.get(s)
	if st == 1:
		ruined[id] = true
		stage.erase(id)
		if arr == null:
			return -1
		var heavy: bool = int(hits.get(id, 0)) >= 2 or (id * 2654435761) % 3 == 0
		return (arr as PackedInt32Array)[(6 if heavy else 4) + (id & 1)]
	if st != 0:
		return -1
	if not FACADE_SPRITES:
		ruined.erase(id)
		return -1
	if ruined.has(id):
		ruined.erase(id)
		hits.erase(id)
		stage.erase(id)
		return -1
	if arr == null:
		return -1
	var g: int = int(stage.get(id, 0))
	if g <= 0:
		return -1
	return (arr as PackedInt32Array)[(g - 1) * 2 + (id & 1)]



static func sprite_for(w: GameWorld, obj_id: int, base_key: String) -> String:
	if not on or not key_of.has(base_key) or w == null:
		return base_key
	var s: int = int(w.spr_index.get(base_key, -1))
	var ds: int = sid_for(w, obj_id, s, w.obj_state[obj_id]) if s >= 0 else -1
	return w.spr_name[ds] if ds >= 0 else base_key
