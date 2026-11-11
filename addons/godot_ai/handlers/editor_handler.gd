@tool
extends "res://addons/godot_ai/handlers/command_handler.gd"

const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")
const Telemetry: = preload("res://addons/godot_ai/telemetry.gd")
const PluginReload: = preload("res://addons/godot_ai/utils/plugin_reload.gd")
const VisionRoutingScript: = preload("res://addons/godot_ai/vision_routing.gd")



var _log_buffer: McpLogBuffer
var _connection: McpConnection
var _debugger_plugin: McpDebuggerPlugin
var _game_log_buffer: McpGameLogBuffer
var _editor_log_buffer: McpEditorLogBuffer
var _debugger_errors_root: Node
var _surfaced_error_tracker
var _vision_routing: VisionRoutingScript = null


func _init(log_buffer: McpLogBuffer, connection: McpConnection = null, debugger_plugin: McpDebuggerPlugin = null, game_log_buffer: McpGameLogBuffer = null, editor_log_buffer: McpEditorLogBuffer = null, debugger_errors_root: Node = null, surfaced_error_tracker = null, vision_routing: VisionRoutingScript = null) -> void :
	_log_buffer = log_buffer
	_connection = connection
	_debugger_plugin = debugger_plugin
	_game_log_buffer = game_log_buffer
	_editor_log_buffer = editor_log_buffer
	_debugger_errors_root = debugger_errors_root
	_surfaced_error_tracker = surfaced_error_tracker
	_vision_routing = vision_routing
	if _surfaced_error_tracker == null:
		_surfaced_error_tracker = McpSurfacedErrorTracker.new(_editor_log_buffer, _game_log_buffer, _debugger_errors_root)


func get_editor_state(_params: Dictionary) -> Dictionary:
	var scene_root: = EditorInterface.get_edited_scene_root()
	var game_status: = _current_game_status()
	var data: = {
		"godot_version": Engine.get_version_info().get("string", "unknown"), 
		"project_name": ProjectSettings.get_setting("application/config/name", ""), 
		"current_scene": scene_root.scene_file_path if scene_root else "", 
		"is_playing": EditorInterface.is_playing_scene(), 
		"readiness": McpConnection.get_readiness(), 



		"game_capture_ready": _debugger_plugin != null and _debugger_plugin.is_game_capture_ready(), 
		"game_status": game_status, 
		"helper_live": bool(game_status.get("helper_live", false)), 
		"session_active": bool(game_status.get("session_active", false)), 
	}
	return {"data": data}


func get_selection(_params: Dictionary) -> Dictionary:
	var scene_root: = EditorInterface.get_edited_scene_root()
	var selected: = EditorInterface.get_selection().get_selected_nodes()
	var paths: Array[String] = []
	for node in selected:
		paths.append(McpScenePath.from_node(node, scene_root))
	return {"data": {"selected_paths": paths, "count": paths.size()}}


const VALID_LOG_SOURCES: = ["plugin", "game", "editor", "all"]






const INPUT_SEQUENCE_TIMEOUT_SEC: = 30.0


func get_logs(params: Dictionary) -> Dictionary:



	var count: int = maxi(0, int(params.get("count", 50)))
	var offset: int = maxi(0, int(params.get("offset", 0)))
	var source: String = str(params.get("source", "plugin"))
	var include_details: bool = bool(params.get("include_details", false))
	var has_since_cursor: = params.has("since_cursor") and params.get("since_cursor") != null
	var since_cursor: int = maxi(0, int(params.get("since_cursor", 0)))
	var since_run_id: = "" if params.get("since_run_id", null) == null else str(params.get("since_run_id", ""))
	if not source in VALID_LOG_SOURCES:
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			"Invalid source '%s' — use 'plugin', 'game', 'editor', or 'all'" % source, 
		)

	match source:
		"plugin":
			return _get_plugin_logs(count, offset)
		"game":
			return _get_game_logs(count, offset, include_details, since_run_id)
		"editor":
			return _get_editor_logs(count, offset, include_details, has_since_cursor, since_cursor)
		"all":
			return _get_all_logs(count, offset, include_details)
	return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, "Unreachable")


func _current_game_status() -> Dictionary:
	if _debugger_plugin == null:
		return McpDebuggerPlugin.with_liveness_flags({
			"status": "stopped", 
			"active": false, 
			"ready": false, 
			"helper_expected": true, 
		})
	return _debugger_plugin.get_game_status()


func _get_plugin_logs(count: int, offset: int) -> Dictionary:
	var all_lines: = _log_buffer.get_recent(_log_buffer.total_count())
	var page: Array[Dictionary] = []
	var stop: = mini(all_lines.size(), offset + count)
	for i in range(mini(offset, all_lines.size()), stop):
		page.append({"source": "plugin", "level": "info", "text": all_lines[i]})
	return {
		"data": {
			"source": "plugin", 
			"lines": page, 
			"total_count": all_lines.size(), 
			"returned_count": page.size(), 
			"offset": offset, 
		}
	}


func _get_game_logs(count: int, offset: int, include_details: bool, since_run_id: String = "") -> Dictionary:
	var game_status: = _current_game_status()
	var helper_live: = bool(game_status.get("helper_live", false))
	var session_active: = bool(game_status.get("session_active", false))
	if _game_log_buffer == null:
		return {
			"data": {
				"source": "game", 
				"lines": [], 
				"total_count": 0, 
				"returned_count": 0, 
				"offset": offset, 
				"run_id": "", 
				"current_run_id": "", 
				"is_running": session_active, 
				"helper_live": helper_live, 
				"session_active": session_active, 
				"game_status": game_status, 
				"dropped_count": 0, 
				"stale_run_id": false, 
			}
		}
	var current_run_id: = _game_log_buffer.run_id()
	var target_run_id: = since_run_id if not since_run_id.is_empty() else current_run_id
	var stale_run_id: = not since_run_id.is_empty() and since_run_id != current_run_id
	var run_page: = _game_log_buffer.get_run_page(target_run_id, offset, count)
	var page: = _entries_for_response(run_page.get("entries", []), include_details)
	var data: = {
		"source": "game", 
		"lines": page, 
		"total_count": int(run_page.get("total_count", 0)), 
		"returned_count": page.size(), 
		"offset": offset, 
		"run_id": target_run_id, 
		"current_run_id": current_run_id, 
		"is_running": session_active, 
		"helper_live": helper_live, 
		"session_active": session_active, 
		"game_status": game_status, 
		"dropped_count": _game_log_buffer.dropped_count(), 
		"stale_run_id": stale_run_id, 
	}
	_merge_editor_errors_hint(data, game_status)
	return {"data": data}







func _merge_editor_errors_hint(data: Dictionary, game_status: Dictionary) -> void :
	if _debugger_plugin == null:
		return


	if bool(data.get("stale_run_id", false)):
		return



	if int(game_status.get("run_token", 0)) <= 0:
		return



	var errors_info: Dictionary = _debugger_plugin.recent_editor_errors_since(
		int(game_status.get("editor_log_cursor", 0)), true)
	if str(errors_info.get("scope", "none")) != "run":
		return
	var errors: Array = errors_info.get("errors", [])
	if errors.is_empty():
		return
	data["editor_errors_count"] = errors.size()
	data["editor_errors_hint"] = (
		"%d editor-side error%s from this run (first: %s) missing from the game log — boot-time parse/load errors occur before the game helper's logger attaches. Read logs_read(source='editor', include_details=true)."
		%[errors.size(), "s" if errors.size() != 1 else "", _format_editor_error_summary(errors[0])]
	)


func _format_editor_error_summary(entry: Dictionary) -> String:
	return McpSurfacedErrorTracker.format_editor_error_summary(entry)


func _get_editor_logs(count: int, offset: int, include_details: bool, has_since_cursor: bool = false, since_cursor: int = 0) -> Dictionary:






	if has_since_cursor:
		return _get_editor_logs_since(count, since_cursor, include_details)
	var all_entries: = _collect_editor_log_entries()
	var page: = _entries_for_response(_slice_entries(all_entries, offset, count), include_details)
	var appended_total: = _editor_log_buffer.appended_total() if _editor_log_buffer != null else 0
	return {
		"data": {
			"source": "editor", 
			"lines": page, 
			"total_count": all_entries.size(), 
			"returned_count": page.size(), 
			"offset": offset, 
			"dropped_count": _editor_log_buffer.dropped_count() if _editor_log_buffer != null else 0, 
			"next_cursor": appended_total, 
			"appended_total": appended_total, 
		}
	}


func _get_editor_logs_since(count: int, since_cursor: int, include_details: bool) -> Dictionary:




	var captured: = {
		"cursor": since_cursor, 
		"oldest_cursor": 0, 
		"next_cursor": 0, 
		"appended_total": 0, 
		"truncated": false, 
		"has_more": false, 
		"entries": [], 
	}
	var dropped: = 0
	if _editor_log_buffer != null:
		captured = _editor_log_buffer.get_since(since_cursor, count)
		dropped = _editor_log_buffer.dropped_count()
	var page: = _entries_for_response(captured.get("entries", []), include_details)
	return {
		"data": {
			"source": "editor", 
			"lines": page, 
			"total_count": int(captured.get("appended_total", 0)), 
			"returned_count": page.size(), 
			"offset": 0, 
			"dropped_count": dropped, 
			"cursor": int(captured.get("cursor", since_cursor)), 
			"oldest_cursor": int(captured.get("oldest_cursor", 0)), 
			"next_cursor": int(captured.get("next_cursor", 0)), 
			"appended_total": int(captured.get("appended_total", 0)), 
			"truncated": bool(captured.get("truncated", false)), 
			"has_more": bool(captured.get("has_more", false)), 
		}
	}


func _get_all_logs(count: int, offset: int, include_details: bool) -> Dictionary:






	var combined: Array[Dictionary] = []
	for line in _log_buffer.get_recent(_log_buffer.total_count()):
		combined.append({"source": "plugin", "level": "info", "text": line})
	for entry in _collect_editor_log_entries():
		combined.append(entry)
	var run_id: = ""
	var current_run_id: = ""
	var dropped: = 0
	if _game_log_buffer != null:
		run_id = _game_log_buffer.run_id()
		current_run_id = run_id
		dropped = _game_log_buffer.dropped_count()
		var run_page: = _game_log_buffer.get_run_page(run_id, 0, McpGameLogBuffer.MAX_LINES)
		for entry in run_page.get("entries", []):
			combined.append(entry)
	var stop: = mini(combined.size(), offset + count)
	var page: Array[Dictionary] = []
	for i in range(mini(offset, combined.size()), stop):
		page.append(combined[i])
	page = _entries_for_response(page, include_details)
	if _editor_log_buffer != null:
		dropped += _editor_log_buffer.dropped_count()
	var game_status: = _current_game_status()
	return {
		"data": {
			"source": "all", 
			"lines": page, 
			"total_count": combined.size(), 
			"returned_count": page.size(), 
			"offset": offset, 
			"run_id": run_id, 
			"current_run_id": current_run_id, 
			"is_running": bool(game_status.get("session_active", false)), 
			"helper_live": bool(game_status.get("helper_live", false)), 
			"session_active": bool(game_status.get("session_active", false)), 
			"game_status": game_status, 
			"dropped_count": dropped, 
		}
	}


func _entries_for_response(entries: Array[Dictionary], include_details: bool) -> Array[Dictionary]:



	var out: Array[Dictionary] = []
	for entry in entries:
		if include_details:
			out.append(entry.duplicate(true))
		else:
			var copy: Dictionary = entry.duplicate(false)
			copy.erase("details")
			out.append(copy)
	return out


func _collect_editor_log_entries() -> Array[Dictionary]:
	return _surfaced_error_tracker.collect_editor_log_entries()


static func _slice_entries(entries: Array[Dictionary], offset: int, count: int) -> Array[Dictionary]:
	var page: Array[Dictionary] = []
	var stop: = mini(entries.size(), offset + count)
	for i in range(mini(offset, entries.size()), stop):
		page.append(entries[i])
	return page



const MONITORS: = {
	"time/fps": Performance.TIME_FPS, 
	"time/process": Performance.TIME_PROCESS, 
	"time/physics_process": Performance.TIME_PHYSICS_PROCESS, 
	"time/navigation_process": Performance.TIME_NAVIGATION_PROCESS, 
	"memory/static": Performance.MEMORY_STATIC, 
	"memory/static_max": Performance.MEMORY_STATIC_MAX, 
	"memory/message_buffer_max": Performance.MEMORY_MESSAGE_BUFFER_MAX, 
	"object/count": Performance.OBJECT_COUNT, 
	"object/resource_count": Performance.OBJECT_RESOURCE_COUNT, 
	"object/node_count": Performance.OBJECT_NODE_COUNT, 
	"object/orphan_node_count": Performance.OBJECT_ORPHAN_NODE_COUNT, 
	"render/total_objects_in_frame": Performance.RENDER_TOTAL_OBJECTS_IN_FRAME, 
	"render/total_primitives_in_frame": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME, 
	"render/total_draw_calls_in_frame": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME, 
	"render/video_mem_used": Performance.RENDER_VIDEO_MEM_USED, 
	"physics_2d/active_objects": Performance.PHYSICS_2D_ACTIVE_OBJECTS, 
	"physics_2d/collision_pairs": Performance.PHYSICS_2D_COLLISION_PAIRS, 
	"physics_2d/island_count": Performance.PHYSICS_2D_ISLAND_COUNT, 
	"physics_3d/active_objects": Performance.PHYSICS_3D_ACTIVE_OBJECTS, 
	"physics_3d/collision_pairs": Performance.PHYSICS_3D_COLLISION_PAIRS, 
	"physics_3d/island_count": Performance.PHYSICS_3D_ISLAND_COUNT, 
	"navigation/active_maps": Performance.NAVIGATION_ACTIVE_MAPS, 
	"navigation/region_count": Performance.NAVIGATION_REGION_COUNT, 
	"navigation/agent_count": Performance.NAVIGATION_AGENT_COUNT, 
	"navigation/link_count": Performance.NAVIGATION_LINK_COUNT, 
	"navigation/polygon_count": Performance.NAVIGATION_POLYGON_COUNT, 
	"navigation/edge_count": Performance.NAVIGATION_EDGE_COUNT, 
	"navigation/edge_merge_count": Performance.NAVIGATION_EDGE_MERGE_COUNT, 
	"navigation/edge_connection_count": Performance.NAVIGATION_EDGE_CONNECTION_COUNT, 
	"navigation/edge_free_count": Performance.NAVIGATION_EDGE_FREE_COUNT, 
}






func _compute_coverage_angles(aabb: AABB) -> Array[Dictionary]:
	var size: = aabb.size
	var ground_x: = maxf(size.x, 0.01)
	var ground_z: = maxf(size.z, 0.01)


	var estab_azimuth: float
	if ground_x >= ground_z:
		estab_azimuth = 0.0
	else:
		estab_azimuth = 90.0


	var ground_ratio: = maxf(ground_x, ground_z) / minf(ground_x, ground_z)
	var estab_fov: = clampf(40.0 + ground_ratio * 5.0, 45.0, 65.0)

	return [
		{"label": "establishing", "elevation": 25.0, "azimuth": estab_azimuth + 20.0, 
			"fov": estab_fov, "ortho": false, "padding": 1.8}, 
		{"label": "top", "elevation": 90.0, "azimuth": 0.0, 
			"fov": 0.0, "ortho": true}, 
	]


func take_screenshot(params: Dictionary) -> Dictionary:






	if _vision_routing != null and _vision_routing.is_routing_enabled():
		return _vision_routing.route_editor_screenshot(params, Callable(self, "_take_screenshot_impl"), _connection)
	return _take_screenshot_impl(params)


func _take_screenshot_impl(params: Dictionary) -> Dictionary:
	var source: String = params.get("source", "viewport")
	var max_resolution: int = params.get("max_resolution", 0)
	var view_target: String = params.get("view_target", "")
	var coverage: bool = params.get("coverage", false)
	var custom_elevation = params.get("elevation", null)
	var custom_azimuth = params.get("azimuth", null)
	var custom_fov = params.get("fov", null)

	var viewport: Viewport
	match source:
		"viewport":
			viewport = EditorInterface.get_editor_viewport_3d()
			if viewport == null:
				return ErrorCodes.make_not_ready(
					ErrorCodes.SUB_EDITOR_VIEWPORT_UNAVAILABLE, 
					"No 3D viewport available", false)







			var precheck: = viewport_screenshot_precheck(EditorInterface.get_edited_scene_root())
			if precheck.has("error"):
				return precheck
		"game":
			if not EditorInterface.is_playing_scene():



				return ErrorCodes.make_not_ready(
					ErrorCodes.SUB_EDITOR_GAME_NOT_RUNNING, 
					"Game is not running — start the project first", false, 
					"Use source='viewport' for the editor viewport, or start the game with project_run and retry.")






			if _debugger_plugin == null or _connection == null:
				return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, "Debugger bridge unavailable — plugin may not be fully initialised")
			var request_id: String = params.get("_request_id", "")
			if request_id.is_empty():
				return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, "Missing request_id — cannot correlate deferred response")
			_debugger_plugin.request_game_screenshot(request_id, max_resolution, _connection)
			return McpDispatcher.DEFERRED_RESPONSE
		"cinematic":
			return _take_cinematic_screenshot(max_resolution)
		"viewport_2d":
			viewport = EditorInterface.get_editor_viewport_2d()
			if viewport == null:
				return ErrorCodes.make_not_ready(
					ErrorCodes.SUB_EDITOR_VIEWPORT_UNAVAILABLE, 
					"No 2D viewport available", false)
			var scene_root_2d: = EditorInterface.get_edited_scene_root()
			if scene_root_2d == null:
				return ErrorCodes.make_not_ready(
					ErrorCodes.SUB_EDITOR_NO_SCENE, 
					"No scene open — open a scene first", false, 
					"Call scene_open with a scene path (e.g. \"res://main.tscn\") first.")
			if not view_target.is_empty() or coverage or custom_elevation != null or custom_azimuth != null or custom_fov != null:
				return ErrorCodes.make(
					ErrorCodes.INVALID_PARAMS, 
					"view_target, coverage, elevation, azimuth, and fov are not supported with source='viewport_2d'"
				)

			RenderingServer.force_draw(false)
			var image_2d: Image = viewport.get_texture().get_image()
			if image_2d == null or image_2d.is_empty():
				return _empty_image_error(
					"viewport_2d", 
					"Captured an empty image from the 2D viewport. The 2D viewport produced no output — typically headless mode or the 2D viewport has not drawn a frame yet."
				)
			return _finalize_image(image_2d, "viewport_2d", max_resolution, viewport.use_hdr_2d)
		_:
			return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, "Invalid source '%s' — use 'viewport', 'viewport_2d', 'cinematic', or 'game'" % source)



	if not view_target.is_empty() and source == "viewport":
		var _scene_check: = McpNodeValidator.require_scene_or_error()
		if _scene_check.has("error"):
			return _scene_check
		var scene_root: Node = _scene_check.scene_root


		var raw_paths: = view_target.split(",")
		var seen: = {}
		var unique_paths: Array[String] = []
		for rp in raw_paths:
			var p: = rp.strip_edges()
			if not p.is_empty() and not seen.has(p):
				seen[p] = true
				unique_paths.append(p)


		var targets: Array[Node3D] = []
		var not_found: Array[String] = []
		for p in unique_paths:
			var node: = McpScenePath.resolve(p, scene_root)
			if node == null:
				not_found.append(p)
			elif not node is Node3D:
				not_found.append(p)
			else:
				targets.append(node as Node3D)

		if targets.is_empty():
			return ErrorCodes.make(ErrorCodes.NODE_NOT_FOUND, "No valid Node3D targets found: %s" % ", ".join(not_found))

		var cam: = viewport.get_camera_3d()
		if cam == null:
			return ErrorCodes.make_not_ready(
				ErrorCodes.SUB_EDITOR_VIEWPORT_UNAVAILABLE, 
				"No camera in 3D viewport", false)


		var combined_aabb: = _get_visual_aabb(targets[0])
		for i in range(1, targets.size()):
			combined_aabb = combined_aabb.merge(_get_visual_aabb(targets[i]))

		var cam_rid: = cam.get_camera_rid()
		var saved_xform: = cam.global_transform
		var saved_fov: = cam.fov
		var saved_near: = cam.near
		var saved_far: = cam.far


		if coverage:
			var images: Array[Dictionary] = []
			for preset in _compute_coverage_angles(combined_aabb):
				if preset.get("ortho", false):

					var ortho_size: = combined_aabb.size.length() * 1.8
					var cam_height: = maxf(combined_aabb.size.length() * 3.0, 10.0)
					var center: = combined_aabb.get_center()
					var xform: = Transform3D(Basis.IDENTITY, center + Vector3.UP * cam_height)
					xform = xform.looking_at(center, Vector3.FORWARD)
					RenderingServer.camera_set_orthogonal(cam_rid, ortho_size, saved_near, maxf(saved_far, cam_height * 2.0))
					RenderingServer.camera_set_transform(cam_rid, xform)
				else:

					var pad: float = preset.get("padding", 2.5)
					var xform: = _frame_transform_for_aabb(combined_aabb, preset.fov, preset.elevation, preset.azimuth, pad)
					RenderingServer.camera_set_perspective(cam_rid, preset.fov, saved_near, saved_far)
					RenderingServer.camera_set_transform(cam_rid, xform)
				RenderingServer.force_draw(false)
				var img: Image = viewport.get_texture().get_image()
				if img != null and not img.is_empty():
					var entry: = _finalize_image(img, "viewport", max_resolution)
					entry.data["label"] = preset.label
					entry.data["elevation"] = preset.elevation
					entry.data["azimuth"] = preset.azimuth
					entry.data["fov"] = preset.fov
					entry.data["ortho"] = preset.get("ortho", false)
					images.append(entry.data)


			RenderingServer.camera_set_perspective(cam_rid, saved_fov, saved_near, saved_far)
			RenderingServer.camera_set_transform(cam_rid, saved_xform)



			if images.is_empty():
				return _empty_image_error(
					"viewport", 
					"Coverage sweep rendered no images. The 3D viewport produced no output across any of the preset angles — typically because the editor is in headless mode (force_draw has no rendered output) or the 3D viewport has not drawn a frame yet."
				)

			var aabb_center: = combined_aabb.get_center()
			var aabb_size: = combined_aabb.size
			var result_data: = {
				"source": "viewport", 
				"view_target": view_target, 
				"view_target_count": targets.size(), 
				"coverage": true, 
				"images": images, 
				"aabb_center": [aabb_center.x, aabb_center.y, aabb_center.z], 
				"aabb_size": [aabb_size.x, aabb_size.y, aabb_size.z], 
				"aabb_longest_ground_axis": "x" if aabb_size.x >= aabb_size.z else "z", 
			}
			if not not_found.is_empty():
				result_data["view_target_not_found"] = not_found
			return {"data": result_data}


		var use_elev: float = 25.0 if custom_elevation == null else float(custom_elevation)
		var use_azim: float = 30.0 if custom_azimuth == null else float(custom_azimuth)
		var use_fov: float = saved_fov if custom_fov == null else float(custom_fov)

		var cam_xform: = _frame_transform_for_aabb(combined_aabb, use_fov, use_elev, use_azim)

		if custom_fov != null:
			RenderingServer.camera_set_perspective(cam_rid, use_fov, saved_near, saved_far)
		RenderingServer.camera_set_transform(cam_rid, cam_xform)
		RenderingServer.force_draw(false)

		var image: Image = viewport.get_texture().get_image()


		if custom_fov != null:
			RenderingServer.camera_set_perspective(cam_rid, saved_fov, saved_near, saved_far)
		RenderingServer.camera_set_transform(cam_rid, saved_xform)

		if image == null or image.is_empty():
			return _empty_image_error(
				"viewport", 
				"Framed viewport rendered an empty image after repositioning the camera onto the view_target. The 3D viewport produced no output — typically headless mode or the 3D viewport has not drawn a frame yet."
			)

		var result: = _finalize_image(image, "viewport", max_resolution)
		result.data["view_target"] = view_target
		result.data["view_target_count"] = targets.size()
		var aabb_c: = combined_aabb.get_center()
		var aabb_s: = combined_aabb.size
		result.data["aabb_center"] = [aabb_c.x, aabb_c.y, aabb_c.z]
		result.data["aabb_size"] = [aabb_s.x, aabb_s.y, aabb_s.z]
		result.data["aabb_longest_ground_axis"] = "x" if aabb_s.x >= aabb_s.z else "z"
		if custom_elevation != null or custom_azimuth != null:
			result.data["elevation"] = use_elev
			result.data["azimuth"] = use_azim
		if custom_fov != null:
			result.data["fov"] = use_fov
		if not not_found.is_empty():
			result.data["view_target_not_found"] = not_found
		return result

	var image: Image = viewport.get_texture().get_image()

	if image == null or image.is_empty():
		return _empty_image_error(
			source, 
			"Captured an empty image from %s. The 3D viewport produced no output — typically headless mode or the 3D viewport has not drawn a frame yet." % source
		)

	return _finalize_image(image, source, max_resolution)






func _take_cinematic_screenshot(max_resolution: int) -> Dictionary:
	var _scene_check: = McpNodeValidator.require_scene_or_error()
	if _scene_check.has("error"):
		return _scene_check
	var scene_root: Node = _scene_check.scene_root

	var scene_camera: = _find_current_camera_3d(scene_root)
	if scene_camera == null:
		return ErrorCodes.make(
			ErrorCodes.NODE_NOT_FOUND, 
			"No current Camera3D in scene — mark a Camera3D as `current` or add one to the scene", 
		)



	var render_size: = Vector2i(1920, 1080)
	var edit_vp: = EditorInterface.get_editor_viewport_3d()
	if edit_vp != null:
		var vs: = edit_vp.get_visible_rect().size
		if vs.x >= 1.0 and vs.y >= 1.0:
			render_size = Vector2i(int(vs.x), int(vs.y))

	var sub_vp: = SubViewport.new()
	sub_vp.size = render_size
	sub_vp.own_world_3d = false
	sub_vp.transparent_bg = false
	sub_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

	var cam: = Camera3D.new()
	cam.fov = scene_camera.fov
	cam.near = scene_camera.near
	cam.far = scene_camera.far
	cam.projection = scene_camera.projection
	cam.size = scene_camera.size
	cam.keep_aspect = scene_camera.keep_aspect
	cam.cull_mask = scene_camera.cull_mask
	cam.environment = scene_camera.environment
	cam.attributes = scene_camera.attributes
	cam.current = true

	sub_vp.add_child(cam)
	scene_root.add_child(sub_vp)


	cam.global_transform = scene_camera.global_transform





	cam.force_update_transform()

	RenderingServer.force_draw(false)
	var image: Image = sub_vp.get_texture().get_image()

	scene_root.remove_child(sub_vp)
	sub_vp.queue_free()

	if image == null or image.is_empty():
		return _empty_image_error(
			"cinematic", 
			"Cinematic render produced an empty image. The SubViewport returned no texture — typically headless mode (force_draw has no rendered output) or the scene's Camera3D is positioned so nothing visible is in frame."
		)

	var result: = _finalize_image(image, "cinematic", max_resolution)
	result.data["camera_path"] = McpScenePath.from_node(scene_camera, scene_root)
	return result













static func viewport_screenshot_precheck(scene_root: Node) -> Dictionary:
	if scene_root == null:
		var no_scene_err: = _make_viewport_not_3d_error(
			"", 
			"The editor 3D viewport is empty because no scene is open. Open a scene with `scene_open` first."
		)



		no_scene_err["error"]["data"]["sub_code"] = ErrorCodes.SUB_EDITOR_NO_SCENE
		return no_scene_err




	if _scene_has_node3d_content(scene_root):
		return {}
	var root_type: = scene_root.get_class()
	var hint: String
	var is_2d_scene: = scene_root is CanvasItem
	if is_2d_scene:
		hint = (
			"The 3D viewport is empty because the current scene is 2D (%s root) with no Node3D descendants. "
			+ "Options: (a) open a 3D scene, "
			+ "(b) use source=\"cinematic\" if a Camera3D exists in the scene, "
			+ "(c) use source=\"viewport_2d\" to capture the 2D editor viewport directly, "
			+ "(d) call scene_get_hierarchy first to inspect what's available."
		) % root_type
	else:
		hint = (
			"The 3D viewport is empty because the current scene (%s root) has no Node3D content anywhere in the tree. "
			+ "Options: (a) open or add a Node3D, "
			+ "(b) use source=\"cinematic\" if a Camera3D exists in the scene, "
			+ "(c) call scene_get_hierarchy first to inspect what's available."
		) % root_type
	var err: = _make_viewport_not_3d_error(root_type, hint)
	if is_2d_scene:
		err["error"]["data"]["suggestion"] = "use source='viewport_2d' for 2D scenes"
	return err




static func _scene_has_node3d_content(scene_root: Node) -> bool:
	if scene_root is Node3D:
		return true
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			if child is Node3D:
				return true
			stack.append(child)
	return false


static func _make_viewport_not_3d_error(scene_root_type: String, hint: String) -> Dictionary:



	var err: = ErrorCodes.make_not_ready(
		ErrorCodes.SUB_EDITOR_VIEWPORT_NOT_3D, hint, false)
	err["error"]["data"]["editor_state"] = "viewport_not_3d"
	err["error"]["data"]["scene_root_type"] = scene_root_type
	return err





static func _empty_image_error(source: String, hint: String) -> Dictionary:



	var err: = ErrorCodes.make_not_ready(
		ErrorCodes.SUB_EDITOR_VIEWPORT_EMPTY, hint, false)
	err["error"]["data"]["editor_state"] = "viewport_empty"
	err["error"]["data"]["source"] = source
	return err





func _find_current_camera_3d(root: Node) -> Camera3D:
	var first: Camera3D = null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Camera3D:
			if node.current:
				return node
			if first == null:
				first = node
		for child in node.get_children():
			stack.append(child)
	return first


func _finalize_image(image: Image, source: String, max_resolution: int, use_hdr_2d: = false) -> Dictionary:

	var encoded: = McpScreenshotEncode.downscale_and_encode(image, max_resolution, use_hdr_2d)
	return {
		"data": {
			"source": source, 
			"width": encoded.width, 
			"height": encoded.height, 
			"original_width": encoded.original_width, 
			"original_height": encoded.original_height, 
			"format": "png", 
			"image_base64": encoded.base64, 
		}
	}



func _get_visual_aabb(node: Node3D) -> AABB:
	var aabb: = AABB()
	var found: = false
	if node is VisualInstance3D:
		aabb = node.global_transform * node.get_aabb()
		found = true
	for child in node.get_children():
		if child is Node3D:
			var child_aabb: = _get_visual_aabb(child)
			if child_aabb.size != Vector3.ZERO:
				if found:
					aabb = aabb.merge(child_aabb)
				else:
					aabb = child_aabb
					found = true
	if not found:
		aabb = AABB(node.global_position - Vector3(0.5, 0.5, 0.5), Vector3(1, 1, 1))
	return aabb






func _frame_transform_for_aabb(aabb: AABB, fov_degrees: float = 75.0, elevation_deg: float = 25.0, azimuth_deg: float = 30.0, padding: float = 1.8) -> Transform3D:
	var center: = aabb.get_center()
	var radius: = aabb.size.length() * 0.5
	var fov_rad: = deg_to_rad(fov_degrees)
	var distance: = radius / tan(fov_rad * 0.5) * padding



	distance = maxf(distance, radius * 2.0 + 1.0)
	var elev: = deg_to_rad(elevation_deg)
	var azim: = deg_to_rad(azimuth_deg)
	var cam_pos: = center + Vector3(
		distance * cos(elev) * sin(azim), 
		distance * sin(elev), 
		distance * cos(elev) * cos(azim), 
	)
	var xform: = Transform3D(Basis.IDENTITY, cam_pos)


	var up: = Vector3.FORWARD if elevation_deg > 85.0 else Vector3.UP
	return xform.looking_at(center, up)


func get_performance_monitors(params: Dictionary) -> Dictionary:
	var filter: Array = params.get("monitors", [])
	var result: = {}

	if filter.is_empty():
		for key in MONITORS:
			result[key] = Performance.get_monitor(MONITORS[key])
	else:
		for key in filter:
			if MONITORS.has(key):
				result[key] = Performance.get_monitor(MONITORS[key])

	return {
		"data": {
			"monitors": result, 
			"monitor_count": result.size(), 
		}
	}


func clear_logs(params: Dictionary) -> Dictionary:
	var count: = _log_buffer.total_count()
	_log_buffer.clear()
	var data: = {"cleared_count": count}


	if bool(params.get("clear_debugger_errors", false)):
		data["debugger_errors_cleared"] = _clear_debugger_error_trees()
	return {"data": data}


func _clear_debugger_error_trees() -> int:
	return _surfaced_error_tracker.clear_debugger_error_trees()


func reload_plugin(_params: Dictionary) -> Dictionary:
	var work: = PluginReload.reserve_reload()
	if work == 0:
		return ErrorCodes.make(ErrorCodes.EDITOR_NOT_READY, "A plugin reload is already pending.")
	_log_buffer.log("reload_plugin requested, reloading next frame")



	Telemetry.record_pending_plugin_reload("mcp_tool")
	_do_reload_plugin.call_deferred(work)
	return {"data": {"status": "reloading", "message": "Plugin reload initiated"}}












static func _do_reload_plugin(work: int = 0) -> void :
	PluginReload.reload_after_scan(work)


func quit_editor(_params: Dictionary) -> Dictionary:
	_log_buffer.log("quit_editor requested, quitting next frame")

	EditorInterface.get_base_control().get_tree().call_deferred("quit")
	return {"data": {"status": "quitting", "message": "Editor quit initiated"}}


func game_eval(params: Dictionary) -> Dictionary:
	var code: String = params.get("code", "")
	if code.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "code is required")

	if _debugger_plugin == null or _connection == null:
		return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, 
			"Debugger bridge unavailable — plugin may not be fully initialised")

	if not EditorInterface.is_playing_scene():
		return ErrorCodes.make_not_ready(
			ErrorCodes.SUB_EDITOR_GAME_NOT_RUNNING, 
			"Game is not running — start the project first", false, 
			"Start the game with project_run (or wait for the user to run it), then retry.")

	var request_id: String = params.get("_request_id", "")
	if request_id.is_empty():
		return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, 
			"Missing request_id — cannot correlate deferred response")

	_debugger_plugin.request_game_eval(code, request_id, _connection)
	return McpDispatcher.DEFERRED_RESPONSE


func game_debug_control(params: Dictionary) -> Dictionary:
	var action: = str(params.get("action", ""))
	if action not in ["suspend", "resume", "next_frame", "debug_status"]:
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			"Invalid game debug action '%s' — use suspend, resume, next_frame, or debug_status" % action, 
		)
	if _debugger_plugin == null or _connection == null:
		return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, 
			"Debugger bridge unavailable — plugin may not be fully initialised")
	if not EditorInterface.is_playing_scene():
		return ErrorCodes.make_not_ready(
			ErrorCodes.SUB_EDITOR_GAME_NOT_RUNNING, 
			"Game is not running — start the project first", false, 
			"Start the game with project_run (or wait for the user to run it), then retry.")
	var request_id: = str(params.get("_request_id", ""))
	if request_id.is_empty():
		return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, 
			"Missing internal _request_id — cannot correlate deferred response")
	_debugger_plugin.request_game_debug_control(action, request_id, _connection)
	return McpDispatcher.DEFERRED_RESPONSE


func game_command(params: Dictionary) -> Dictionary:
	var op: String = str(params.get("op", ""))
	if op.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "op is required")

	if _debugger_plugin == null or _connection == null:
		return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, 
			"Debugger bridge unavailable — plugin may not be fully initialised")

	if not EditorInterface.is_playing_scene():
		return ErrorCodes.make_not_ready(
			ErrorCodes.SUB_EDITOR_GAME_NOT_RUNNING, 
			"Game is not running — start the project first", false, 
			"Start the game with project_run (or wait for the user to run it), then retry.")

	var request_id: String = params.get("_request_id", "")
	if request_id.is_empty():
		return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, 
			"Missing request_id — cannot correlate deferred response")

	var command_params: Dictionary = params.get("params", {})







	if op == "input_sequence":
		_debugger_plugin.request_game_command(
			op, command_params, request_id, _connection, INPUT_SEQUENCE_TIMEOUT_SEC
		)
		return {
			"_deferred": true, 
			"_deferred_timeout_ms": int(INPUT_SEQUENCE_TIMEOUT_SEC * 1000.0), 
		}

	_debugger_plugin.request_game_command(op, command_params, request_id, _connection)
	return McpDispatcher.DEFERRED_RESPONSE
