@tool
extends "res://addons/godot_ai/handlers/command_handler.gd"



const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")


func _init() -> void :
	pass





















func get_atlas_tiles(params: Dictionary) -> Dictionary:
	var resolved: = _resolve_atlas_source(params)
	if resolved.has("error"):
		return resolved
	var src: TileSetAtlasSource = resolved.src

	var tiles: Array = []
	for i in range(src.get_tiles_count()):
		var v: Vector2i = src.get_tile_id(i)
		tiles.append({"col": v.x, "row": v.y})

	return {"data": {"tiles": tiles, "count": tiles.size()}}
























func get_atlas_image(params: Dictionary) -> Dictionary:
	var resolved: = _resolve_atlas_source(params)
	if resolved.has("error"):
		return resolved
	var source_id: int = resolved.source_id
	var src: TileSetAtlasSource = resolved.src

	var tex: Texture2D = src.texture
	if tex == null:
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE, 
			"Source %d has no texture assigned" % source_id
		)

	var img: Image = tex.get_image()
	if img == null:
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE, 
			"Could not retrieve image data from texture of source %d" % source_id
		)
	if img.is_compressed():
		var decompress_err: = img.decompress()
		if decompress_err != OK:
			return ErrorCodes.make(
				ErrorCodes.INTERNAL_ERROR, 
				"Could not decompress texture of source %d: %s" % [source_id, error_string(decompress_err)]
			)

	var original_width: int = img.get_width()
	var original_height: int = img.get_height()

	var max_size: int = params.get("max_size", 0)
	if max_size > 0:
		var longest_edge: int = max(original_width, original_height)
		if longest_edge > max_size:
			var scale: float = float(max_size) / float(longest_edge)
			var new_w: int = max(1, int(original_width * scale))
			var new_h: int = max(1, int(original_height * scale))
			img.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)

	var png_bytes: PackedByteArray = img.save_png_to_buffer()
	if png_bytes.is_empty():
		return ErrorCodes.make(
			ErrorCodes.INTERNAL_ERROR, 
			"PNG encoding produced empty output for source %d" % source_id
		)
	var b64: String = Marshalls.raw_to_base64(png_bytes)

	return {
		"data": {
			"image_base64": b64, 
			"width": img.get_width(), 
			"height": img.get_height(), 
			"original_width": original_width, 
			"original_height": original_height, 
			"format": "png", 
		}
	}


func _resolve_atlas_source(params: Dictionary) -> Dictionary:
	var tileset_path: String = params.get("tileset_path", "")
	if tileset_path.is_empty():
		return ErrorCodes.make(
			ErrorCodes.MISSING_REQUIRED_PARAM, 
			"'tileset_path' parameter is required and must not be empty"
		)

	if not params.has("source_id"):
		return ErrorCodes.make(
			ErrorCodes.MISSING_REQUIRED_PARAM, 
			"'source_id' parameter is required"
		)

	var tileset_path_err = McpPathValidator.loadable_error(tileset_path, "tileset_path")
	if tileset_path_err != null:
		return tileset_path_err

	if not ResourceLoader.exists(tileset_path):
		return ErrorCodes.make(
			ErrorCodes.RESOURCE_NOT_FOUND, 
			"TileSet resource not found: %s" % tileset_path
		)

	var ts = load(tileset_path)
	if not ts is TileSet:
		var loaded_type: = "null" if ts == null else ts.get_class()
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE, 
			"Resource at '%s' is not a TileSet (got %s)" % [tileset_path, loaded_type]
		)

	var source_id: int = int(params.get("source_id", -999))
	if source_id < 0 or not ts.has_source(source_id):
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			"source_id %d does not exist in TileSet" % source_id
		)

	var src = ts.get_source(source_id)
	if not src is TileSetAtlasSource:
		var source_type: String = "null" if src == null else src.get_class()
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE, 
			"Source %d is not a TileSetAtlasSource (got %s)" % [source_id, source_type]
		)

	return {
		"source_id": source_id, 
		"src": src, 
	}
