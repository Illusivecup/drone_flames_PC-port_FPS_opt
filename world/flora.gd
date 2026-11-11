class_name Flora
extends RefCounted






const ATLAS_PNG: String = "res://assets/sprites/atlas_flora.png"
const ATLAS_JSON: String = "res://assets/sprites/atlas_flora.json"
const DECID: Array = ["tree_oak_a", "tree_oak_b", "tree_birch_a", "tree_oak_a", "tree_oak_b"]
const PINES: Array = ["tree_pine_a", "tree_pine_b"]

static var atlas: SpriteAtlas


static func load_atlas() -> SpriteAtlas:
	if atlas == null:
		atlas = SpriteAtlas.load_atlas(ATLAS_PNG, ATLAS_JSON, true)
	return atlas






static func register(gw: GameWorld) -> void :
	var a: SpriteAtlas = load_atlas()
	if a.sprites.is_empty():
		return
	var trees: = SpriteAtlas.new()
	trees.texture = a.texture
	var oy: int = 0
	var old_tex: Texture2D = gw.atlas.texture
	var wimg: Image = old_tex.get_image() if old_tex != null and not (old_tex is PlaceholderTexture2D) else null
	var fimg: Image = a.texture.get_image()
	if wimg != null and fimg != null and not wimg.is_empty() and not fimg.is_empty():
		if wimg.is_compressed():
			wimg.decompress()
		if fimg.is_compressed():
			fimg.decompress()
		wimg.convert(Image.FORMAT_RGBA8)
		fimg.convert(Image.FORMAT_RGBA8)
		oy = wimg.get_height() + 1
		var merged: = Image.create(maxi(wimg.get_width(), fimg.get_width()), oy + fimg.get_height(), false, Image.FORMAT_RGBA8)
		merged.blit_rect(wimg, Rect2i(Vector2i.ZERO, wimg.get_size()), Vector2i.ZERO)
		merged.blit_rect(fimg, Rect2i(Vector2i.ZERO, fimg.get_size()), Vector2i(0, oy))
		var mtex: = ImageTexture.create_from_image(merged)
		for i in gw.spr_tex.size():
			if gw.spr_tex[i] == old_tex:
				gw.spr_tex[i] = mtex
		gw.atlas.texture = mtex
		trees.texture = mtex
	for n: String in a.sprites:
		var e: Dictionary = a.sprites[n]
		if String(e.get("kind", "")) == "tree":
			var e2: Dictionary = e.duplicate()
			e2["y"] = float(e["y"]) + float(oy)
			trees.sprites[n] = e2
	var first: int = gw.spr_rect.size()
	gw._add_sprites(trees)
	gw.spr_ruin.resize(gw.spr_rect.size())
	for i in range(first, gw.spr_rect.size()):
		gw.spr_ruin[i] = int(gw.spr_index.get("tree_burnt", -1))
	print("[Flora] %d tree sprites, merged into atlas_world: %s" % [gw.spr_rect.size() - first, oy > 0])


static func ready(gw: GameWorld) -> bool:
	return gw.spr_index.has("tree_oak_a_green") and gw.spr_index.has("tree_pine_a_dark")




static func spawn_trees(gw: GameWorld) -> void :
	var t0: int = Time.get_ticks_msec()
	var d: WorldData = gw.data
	var s: WorldSettings = gw.settings
	var fm: int = 50 + s.forests
	var nbig: PackedByteArray = WorldGen._noise_layer(d.w, d.h, maxi(4, d.w / 44), s.world_seed + 3301)
	var nmid: PackedByteArray = WorldGen._noise_layer(d.w, d.h, maxi(4, d.w / 150), s.world_seed + 3302)
	var dec: Array = []
	for n: String in DECID:
		dec.append([int(gw.spr_index[n + "_green"]), int(gw.spr_index[n + "_lime"]), int(gw.spr_index[n + "_gold"])])
	var pin: Array = []
	for n: String in PINES:
		pin.append([int(gw.spr_index[n + "_green"]), int(gw.spr_index[n + "_dark"])])
	var w: int = d.w
	var sd: int = d.world_seed + 5
	var bio: PackedByteArray = d.biome
	var n_trees: int = 0
	for y in d.h:
		var row: int = y * w
		for x in w:
			var i: int = row + x
			var b: int = bio[i]
			if b < Biome.GRASS or b > Biome.HILLS:
				continue
			var mid: int = nmid[i]
			var dn: int = 0
			match b:
				Biome.FOREST:
					dn = 80 if mid >= 78 else 26
				Biome.PINE:
					dn = 92 if mid >= 70 else 34
				Biome.GRASS:
					dn = 2 + maxi(0, mid - 160) * 70 / 95
				Biome.STEPPE:
					dn = 1 + maxi(0, mid - 185) * 30 / 70
				Biome.HILLS:
					dn = 12 + maxi(0, mid - 150) / 4
			dn = dn * fm / 100
			var hh: int = Hash32.h2(x, y, sd)
			if (hh & 255) >= dn:
				continue
			var roll: int = (hh >> 16) & 255
			var big: int = nbig[i]
			var sid: int
			if b == Biome.PINE or (b == Biome.HILLS and (hh >> 8) % 3 != 0):
				sid = pin[(hh >> 8) % 2][1 if big + (roll & 63) > 190 else 0]
			else:
				var r: Array = dec[(hh >> 8) % DECID.size()]
				var aut: int = 28 if big >= 228 else 1
				var lime: int = 52 if b == Biome.GRASS else 36
				if roll < aut:
					sid = r[2]
				elif roll < aut + lime:
					sid = r[1]
				else:
					sid = r[0]
			gw.tree_at[i] = gw._add_object_id(sid, x, y, GameWorld.KIND_TREE)
			n_trees += 1
	print("[Flora] trees: %d in %d ms" % [n_trees, Time.get_ticks_msec() - t0])
