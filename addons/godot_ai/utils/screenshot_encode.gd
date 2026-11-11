@tool
class_name McpScreenshotEncode
extends RefCounted













static func downscale_and_encode(image: Image, max_resolution: int, use_hdr_2d: = false) -> Dictionary:




	if use_hdr_2d and RenderingServer.get_current_rendering_method() != "gl_compatibility":
		image.convert(Image.FORMAT_RGBA8)
		image.linear_to_srgb()
	var original_width: = image.get_width()
	var original_height: = image.get_height()

	if max_resolution > 0:
		var longest: = maxi(original_width, original_height)
		if longest > max_resolution:
			var scale: = float(max_resolution) / float(longest)



			var new_w: = maxi(1, int(original_width * scale))
			var new_h: = maxi(1, int(original_height * scale))
			image.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)

	return {
		"base64": Marshalls.raw_to_base64(image.save_png_to_buffer()), 
		"width": image.get_width(), 
		"height": image.get_height(), 
		"original_width": original_width, 
		"original_height": original_height, 
	}
