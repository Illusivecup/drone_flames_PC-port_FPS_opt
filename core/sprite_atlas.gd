class_name SpriteAtlas
extends RefCounted


var texture: Texture2D
var sprites: Dictionary = {}
var cell_px: int = 4


static func load_atlas(png_path: String, json_path: String, optional: bool = false) -> SpriteAtlas:
	var a: = SpriteAtlas.new()
	if not ResourceLoader.exists(png_path) or not FileAccess.file_exists(json_path):
		if not optional:
			push_warning("SpriteAtlas: missing %s - empty atlas" % png_path)
		a.texture = PlaceholderTexture2D.new()
		return a
	a.texture = load(png_path) as Texture2D
	var f: = FileAccess.open(json_path, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	a.sprites = d["sprites"]

	if d.has("size") and a.texture != null:
		var want: = Vector2(float(d["size"][0]), float(d["size"][1]))
		if a.texture.get_size() != want:
			push_error("SpriteAtlas %s: texture %s != json size %s - reimport the PNG" % [png_path, a.texture.get_size(), want])
	if d.has("cell_px"):
		a.cell_px = int(d["cell_px"])
	return a


func has(sprite_name: String) -> bool:
	return sprites.has(sprite_name)


func info(sprite_name: String) -> Dictionary:
	return sprites[sprite_name]


func rect(sprite_name: String, frame: int = 0) -> Rect2:
	var s: Dictionary = sprites[sprite_name]
	return Rect2(float(s["x"]) + float(s["w"]) * frame, float(s["y"]), float(s["w"]), float(s["h"]))


func region(sprite_name: String, frame: int = 0) -> AtlasTexture:
	var t: = AtlasTexture.new()
	t.atlas = texture
	t.region = rect(sprite_name, frame)
	return t
