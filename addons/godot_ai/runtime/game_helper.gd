extends Node




















const CAPTURE_PREFIX: = "mcp"


const FLUSH_BATCH_LIMIT: = 200












const FIRST_FRAME_WAIT_SEC: = 6.0






const MAIN_LOOP_STALL_MSEC: = 1000









const RENDER_STALL_MSEC: = 1500

const GameLogger: = preload("res://addons/godot_ai/runtime/game_logger.gd")
const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")



const ScreenshotEncode: = preload("res://addons/godot_ai/utils/screenshot_encode.gd")

var _registered: = false

var _logger: Logger
var _logger_attached: = false




var _pending_outbound: Array = []








var _inflight_evals: Dictionary = {}
var _eval_token_counter: int = 0




var _last_loop_tick_msec: int = -1
var _mcp_runtime_process_ticks: int = 0
var _last_debug_status_reply: Dictionary = {}





var _last_frames_drawn_seen: int = -1
var _last_frames_advance_msec: int = -1




var _last_eval_liveness_reply: Dictionary = {}


func _ready() -> void :







	if Engine.is_editor_hint():
		return




	process_mode = Node.PROCESS_MODE_ALWAYS


	EngineDebugger.register_message_capture(CAPTURE_PREFIX, _on_debug_message)
	_registered = true



	_logger = GameLogger.new()
	OS.add_logger(_logger)
	_logger_attached = true


	print("[godot_ai game_helper] registered mcp capture (debugger active=%s, logger=%s)"
		%[EngineDebugger.is_active(), _logger_attached])


	if EngineDebugger.is_active():
		EngineDebugger.send_message("mcp:hello", [])


func _process(_delta: float) -> void :
	_mcp_runtime_process_ticks += 1



	_last_loop_tick_msec = Time.get_ticks_msec()



	var frames_now: = Engine.get_frames_drawn()
	if frames_now != _last_frames_drawn_seen:
		_last_frames_drawn_seen = frames_now
		_last_frames_advance_msec = _last_loop_tick_msec






	if not _logger_attached or _logger == null:
		_pending_outbound.clear()
		return
	if not EngineDebugger.is_active():


		_logger.clear()
		_pending_outbound.clear()
		return
	if _pending_outbound.is_empty():
		if not _logger.has_pending():
			return
		_pending_outbound = _logger.drain()
	var batch: = _pending_outbound.slice(0, FLUSH_BATCH_LIMIT)
	_pending_outbound = _pending_outbound.slice(FLUSH_BATCH_LIMIT)
	EngineDebugger.send_message("mcp:log_batch", [batch])


func _exit_tree() -> void :
	if _registered:
		EngineDebugger.unregister_message_capture(CAPTURE_PREFIX)
		_registered = false
	if _logger_attached and _logger != null:
		OS.remove_logger(_logger)
		_logger_attached = false
		_logger = null






func _on_debug_message(message: String, data: Array) -> bool:
	var action: = message.trim_prefix("mcp:")
	match action:
		"take_screenshot":
			_handle_take_screenshot(data)
			return true
		"eval_liveness":
			_reply_eval_liveness(data)
			return true
		"debug_status":
			_reply_debug_status(data)
			return true
		"eval":
			_handle_eval(data)
			return true
		"eval_check":
			_handle_eval_check(data)
			return true
		"game_command":
			_handle_game_command(data)
			return true
	return false





func _reply_eval_liveness(data: Array) -> void :
	var request_id: String = data[0] if data.size() > 0 else ""
	var loop_live: = not _main_loop_appears_stalled()
	_last_eval_liveness_reply = {"request_id": request_id, "loop_live": loop_live}
	if EngineDebugger.is_active():
		EngineDebugger.send_message("mcp:eval_liveness_response", [request_id, loop_live])


func _debug_status_snapshot() -> Dictionary:
	var inside_tree: = is_inside_tree()
	var tree: = get_tree() if inside_tree else null
	return {
		"probe_version": 1, 
		"helper_found": true, 



		"suspended": inside_tree and not can_process(), 
		"loop_live": not _main_loop_appears_stalled(), 
		"loop_tick_msec": _last_loop_tick_msec, 
		"process_ticks": _mcp_runtime_process_ticks, 
		"tree_paused": tree.paused if tree != null else false, 
		"frames_drawn": Engine.get_frames_drawn(), 
		"process_frames": Engine.get_process_frames(), 
		"physics_frames": Engine.get_physics_frames(), 
		"time_scale": Engine.time_scale, 
	}


func _reply_debug_status(data: Array) -> void :
	var request_id: String = data[0] if data.size() > 0 else ""
	var state: = _debug_status_snapshot()
	_last_debug_status_reply = {"request_id": request_id, "state": state.duplicate(true)}
	if EngineDebugger.is_active():
		EngineDebugger.send_message("mcp:debug_status_response", [request_id, state])


func _handle_take_screenshot(data: Array) -> void :
	var request_id: String = data[0] if data.size() > 0 else ""
	var max_resolution: int = int(data[1]) if data.size() > 1 else 0

	var tree: = get_tree()
	var viewport: = tree.root if tree != null else null
	if viewport == null:
		_reply_error(request_id, "No game root viewport available")
		return









	if _should_capture_stale_sync(
		_main_loop_appears_stalled(), 
		_rendering_appears_stalled(), 
		tree.current_scene != null, 
		Engine.get_frames_drawn()
	):
		_capture_and_reply(request_id, viewport, max_resolution, Engine.get_frames_drawn())
		return







	var deadline: = Time.get_ticks_msec() + int(FIRST_FRAME_WAIT_SEC * 1000.0)
	while tree.current_scene == null and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	var frames_at_request: = Engine.get_frames_drawn()
	while Engine.get_frames_drawn() <= frames_at_request and Time.get_ticks_msec() < deadline:
		await tree.process_frame

	_capture_and_reply(request_id, viewport, max_resolution, frames_at_request)









static func _should_capture_stale_sync(
	loop_stalled: bool, render_stalled: bool, has_current_scene: bool, frames_drawn: int
) -> bool:
	return (loop_stalled or render_stalled) and has_current_scene and frames_drawn > 0




func _main_loop_appears_stalled() -> bool:



	if _last_loop_tick_msec < 0:
		return true
	return Time.get_ticks_msec() - _last_loop_tick_msec > MAIN_LOOP_STALL_MSEC








func _rendering_appears_stalled() -> bool:
	if _last_frames_advance_msec < 0:
		return false
	return Time.get_ticks_msec() - _last_frames_advance_msec > RENDER_STALL_MSEC







func _capture_and_reply(
	request_id: String, viewport: Viewport, max_resolution: int, frames_at_request: int
) -> void :
	var texture: = viewport.get_texture()
	if texture == null:
		_reply_error(request_id, "Root viewport has no texture (headless?)")
		return

	var image: = texture.get_image()
	if image == null or image.is_empty():
		_reply_error(request_id, "Captured an empty image from game viewport")
		return

	var encoded: Dictionary = ScreenshotEncode.downscale_and_encode(image, max_resolution, viewport.use_hdr_2d)
	var frames_drawn: = Engine.get_frames_drawn()
	var stale: = frames_drawn <= frames_at_request

	_last_screenshot_reply = {
		"kind": "response", 
		"request_id": request_id, 
		"frames_drawn": frames_drawn, 
		"stale": stale, 
		"width": encoded.width, 
		"height": encoded.height, 
	}
	if EngineDebugger.is_active():


		EngineDebugger.send_message("mcp:screenshot_response", [
			request_id, 
			encoded.base64, 
			encoded.width, 
			encoded.height, 
			encoded.original_width, 
			encoded.original_height, 
			frames_drawn, 
			stale, 
		])





var _last_screenshot_reply: Dictionary = {}


func _reply_error(request_id: String, message: String) -> void :
	_last_screenshot_reply = {"kind": "error", "request_id": request_id, "message": message}
	if EngineDebugger.is_active():
		EngineDebugger.send_message("mcp:screenshot_error", [request_id, message])




func _handle_game_command(data: Array) -> void :
	var request_id: String = data[0] if data.size() > 0 else ""
	var op: String = data[1] if data.size() > 1 else ""
	var params_json: String = data[2] if data.size() > 2 else "{}"

	if request_id.is_empty():
		return
	if op.is_empty():
		_reply_game_command_error(request_id, "No op provided")
		return

	var json: = JSON.new()
	var parse_err: = json.parse(params_json)
	if parse_err != OK or not (json.data is Dictionary):
		_reply_game_command_error(request_id, "Invalid params JSON")
		return

	var result: Dictionary
	match op:
		"get_scene_tree":
			result = _game_get_scene_tree(json.data)
		"get_node_info":
			result = _game_get_node_info(json.data)
		"get_ui_elements":
			result = _game_get_ui_elements(json.data)
		"input_key":
			result = _game_input_key(json.data)
		"input_mouse":
			result = _game_input_mouse(json.data)
		"input_gamepad":
			result = _game_input_gamepad(json.data)
		"input_action":
			result = _game_input_action(json.data)
		"input_state":
			result = _game_input_state(json.data)
		"input_sequence":



			_run_input_sequence(request_id, json.data)
			return
		_:
			_reply_game_command_error(request_id, "Unknown game op: %s" % op)
			return

	result["source"] = "game"
	result["op"] = op
	EngineDebugger.send_message("mcp:game_command_response", 
		[request_id, JSON.stringify(_variant_to_json(result))])


func _reply_game_command_error(request_id: String, message: String) -> void :
	EngineDebugger.send_message("mcp:game_command_error", [request_id, message])


func _game_get_scene_tree(params: Dictionary) -> Dictionary:
	var depth: = maxi(0, int(params.get("depth", 10)))
	var root: = _resolve_runtime_node(str(params.get("root_path", "")))
	if root == null:
		return {"root": "", "nodes": [], "total_count": 0, "not_found": params.get("root_path", "")}

	var nodes: Array[Dictionary] = []
	_collect_runtime_nodes(root, 0, depth, nodes)
	return {
		"root": _runtime_path(root), 
		"nodes": nodes, 
		"total_count": nodes.size(), 
	}


func _collect_runtime_nodes(node: Node, current_depth: int, max_depth: int, out: Array[Dictionary]) -> void :
	out.append({
		"name": node.name, 
		"type": node.get_class(), 
		"path": _runtime_path(node), 
		"children_count": node.get_child_count(), 
	})
	if current_depth >= max_depth:
		return
	for child in node.get_children():
		if child is Node:
			_collect_runtime_nodes(child, current_depth + 1, max_depth, out)


func _game_get_node_info(params: Dictionary) -> Dictionary:
	var path: = str(params.get("path", ""))
	var node: = _resolve_runtime_node(path)
	if node == null:
		return {"path": path, "found": false}

	var info: = {
		"path": _runtime_path(node), 
		"name": node.name, 
		"type": node.get_class(), 
		"children_count": node.get_child_count(), 
		"groups": node.get_groups(), 
		"found": true, 
	}
	if bool(params.get("include_properties", true)):
		info["properties"] = _runtime_node_properties(node)
	return info


func _game_get_ui_elements(params: Dictionary) -> Dictionary:
	var max_depth: = maxi(0, int(params.get("max_depth", 10)))
	var include_hidden: = bool(params.get("include_hidden", false))
	var include_disabled: = bool(params.get("include_disabled", true))
	var root_path: = str(params.get("root_path", ""))
	var root: = _resolve_runtime_node(root_path)
	if root == null:
		return {"root": "", "elements": [], "total_count": 0, "not_found": root_path}

	var elements: Array[Dictionary] = []
	_collect_ui_elements(root, 0, max_depth, include_hidden, include_disabled, elements)
	return {
		"root": _runtime_path(root), 
		"elements": elements, 
		"total_count": elements.size(), 
	}


func _collect_ui_elements(
	node: Node, 
	current_depth: int, 
	max_depth: int, 
	include_hidden: bool, 
	include_disabled: bool, 
	out: Array[Dictionary]
) -> void :
	if node is Control:
		var control: = node as Control
		var visible: = _control_visible_in_tree(control)
		var disabled: = _control_disabled(control)
		if (include_hidden or visible) and (include_disabled or not disabled):
			out.append(_ui_element_info(control, visible, disabled))

	if current_depth >= max_depth:
		return
	for child in node.get_children():
		if child is Node:
			_collect_ui_elements(
				child, 
				current_depth + 1, 
				max_depth, 
				include_hidden, 
				include_disabled, 
				out
			)


func _ui_element_info(control: Control, visible: bool, disabled: bool) -> Dictionary:
	var info: = {
		"path": _runtime_path(control), 
		"name": control.name, 
		"type": control.get_class(), 
		"visible": visible, 
		"disabled": disabled, 
		"rect": _variant_to_json(control.get_rect()), 
		"global_rect": _variant_to_json(control.get_global_rect()), 
	}
	if _object_has_property(control, "text"):
		info["text"] = str(control.get("text"))
	return info


func _control_disabled(control: Control) -> bool:
	if _object_has_property(control, "disabled"):
		return bool(control.get("disabled"))
	return false


func _control_visible_in_tree(control: Control) -> bool:
	if not control.visible:
		return false
	var parent: = control.get_parent()
	while parent != null:
		if parent is CanvasItem and not (parent as CanvasItem).visible:
			return false
		parent = parent.get_parent()
	if Engine.is_editor_hint():
		return true
	return control.is_visible_in_tree()


static var _property_name_cache: Dictionary = {}


func _object_has_property(obj: Object, property_name: String) -> bool:
	var key: = _property_cache_key(obj)
	if not _property_name_cache.has(key):
		var names: = {}
		for prop in obj.get_property_list():
			names[str(prop.get("name", ""))] = true
		_property_name_cache[key] = names
	return (_property_name_cache[key] as Dictionary).has(property_name)


func _property_cache_key(obj: Object) -> String:
	var script = obj.get_script()
	if script == null:
		return obj.get_class()
	var script_id: = str(script.get_instance_id())
	if not script.resource_path.is_empty():
		script_id = script.resource_path
	return "%s:%s" % [obj.get_class(), script_id]


func _runtime_node_properties(node: Node) -> Dictionary:
	var props: = {}
	for p in node.get_property_list():
		var name: = str(p.get("name", ""))
		var usage: = int(p.get("usage", 0))
		if name.is_empty() or (usage & PROPERTY_USAGE_EDITOR) == 0:
			continue
		props[name] = _variant_to_json(node.get(name))
	return props


func _resolve_runtime_node(path: String) -> Node:
	var scene_root: = _current_scene_root()
	if scene_root == null:
		return null
	if path.is_empty() or path == "/":
		return scene_root

	if path.begins_with("/root/"):
		return get_tree().root.get_node_or_null(path.trim_prefix("/root/"))

	var scene_path: = path.trim_prefix("/")
	if scene_path == str(scene_root.name):
		return scene_root
	var prefix: = str(scene_root.name) + "/"
	if scene_path.begins_with(prefix):
		scene_path = scene_path.substr(prefix.length())
	return scene_root.get_node_or_null(scene_path)


func _runtime_path(node: Node) -> String:
	var scene_root: = _current_scene_root()
	if scene_root == null:
		return str(node.get_path())
	if node == scene_root:
		return "/" + str(scene_root.name)
	return "/" + str(scene_root.name) + "/" + str(scene_root.get_path_to(node))


func _current_scene_root() -> Node:
	var tree: = get_tree()
	if tree == null:
		return null
	var scene_root: = tree.current_scene
	if scene_root == null and Engine.is_editor_hint():






		var editor: = Engine.get_singleton(&"EditorInterface")
		if editor:
			scene_root = editor.get_edited_scene_root()
	return scene_root


func _game_input_key(params: Dictionary) -> Dictionary:
	var key_name: = str(params.get("key", ""))
	var keycode: = OS.find_keycode_from_string(key_name)
	if keycode == KEY_NONE:
		return {"sent": false, "error": "Unknown key: %s" % key_name}
	var ev: = InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = bool(params.get("pressed", true))
	ev.echo = bool(params.get("echo", false))
	Input.parse_input_event(ev)
	return {"sent": true, "key": key_name, "pressed": ev.pressed}


func _game_input_mouse(params: Dictionary) -> Dictionary:
	var event: = str(params.get("event", "button"))
	var pos_result: = _resolve_mouse_position(params.get("position"))
	if pos_result.has("error"):
		return {"sent": false, "event": event, "error": pos_result.error}
	var pos: Vector2 = pos_result.position
	match event:
		"motion":
			var motion: = InputEventMouseMotion.new()
			motion.position = pos
			motion.global_position = pos
			Input.parse_input_event(motion)
			return {"sent": true, "event": "motion", "position": _variant_to_json(pos)}
		"button":
			var button_event: = InputEventMouseButton.new()
			button_event.position = pos
			button_event.global_position = pos
			button_event.button_index = _mouse_button_index(str(params.get("button", "left")))
			button_event.pressed = bool(params.get("pressed", true))
			Input.parse_input_event(button_event)
			return {
				"sent": true, 
				"event": "button", 
				"button": params.get("button", "left"), 
				"pressed": button_event.pressed, 
				"position": _variant_to_json(pos), 
			}
	return {"sent": false, "error": "Invalid mouse event: %s" % event}


func _game_input_gamepad(params: Dictionary) -> Dictionary:
	var device: = int(params.get("device", 0))
	var control: = str(params.get("control", "button"))
	match control:
		"button":
			var button: = InputEventJoypadButton.new()
			button.device = device
			button.button_index = int(params.get("index", 0))
			button.pressed = bool(params.get("pressed", true))
			Input.parse_input_event(button)
			return {"sent": true, "control": "button", "device": device, "index": button.button_index, "pressed": button.pressed}
		"axis":
			var axis: = InputEventJoypadMotion.new()
			axis.device = device
			axis.axis = int(params.get("index", 0))
			axis.axis_value = float(params.get("value", 0.0))
			Input.parse_input_event(axis)
			return {"sent": true, "control": "axis", "device": device, "index": axis.axis, "value": axis.axis_value}
	return {"sent": false, "error": "Invalid gamepad control: %s" % control}


func _game_input_action(params: Dictionary) -> Dictionary:
	var action: = str(params.get("action", ""))
	if action.is_empty():
		return {"sent": false, "error": "Missing action"}
	if not InputMap.has_action(action):
		return {"sent": false, "action": action, "error": "Unknown action: %s" % action}
	var pressed: = bool(params.get("pressed", true))
	var strength: = clampf(float(params.get("strength", 1.0)), 0.0, 1.0)
	if pressed:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)
	return {
		"sent": true, 
		"action": action, 
		"pressed": pressed, 
		"strength": strength, 
		"delivery": "action_state", 
	}


func _game_input_state(params: Dictionary) -> Dictionary:
	var actions: Array = params.get("actions", [])
	if actions.is_empty():
		actions = InputMap.get_actions()
	var states: = {}
	for action in actions:
		var name: = str(action)
		states[name] = Input.is_action_pressed(name)
	return {"actions": states}























const MAX_SEQUENCE_STEPS: = 256
const MAX_SEQUENCE_FRAMES: = 600




var _last_game_command_reply: Dictionary = {}








var _frame_waiter: Callable = Callable()





func _plan_input_sequence(params: Dictionary) -> Dictionary:
	var raw_steps: Variant = params.get("steps", null)
	if not (raw_steps is Array):
		return {"error": "steps must be an array"}
	var steps_arr: Array = raw_steps
	if steps_arr.is_empty():
		return {"error": "steps must not be empty"}
	if steps_arr.size() > MAX_SEQUENCE_STEPS:
		return {"error": "steps exceeds cap of %d (got %d)" % [MAX_SEQUENCE_STEPS, steps_arr.size()]}








	var settle_raw: Variant = params.get("settle_frames", 0)
	if not _is_number(settle_raw):
		return {"error": "settle_frames must be a number"}
	var settle_frames: = int(settle_raw)
	if settle_frames < 0:
		return {"error": "settle_frames must be >= 0"}

	var normalized: Array = []
	var prev_frame: = -1
	for i in steps_arr.size():
		var raw: Variant = steps_arr[i]
		if not (raw is Dictionary):
			return {"error": "steps[%d] must be an object" % i}
		var step: Dictionary = raw
		if not (step.get("action", "") is String) or str(step.get("action", "")).is_empty():
			return {"error": "steps[%d].action is required" % i}
		var action: String = step["action"]
		var at_frame_raw: Variant = step.get("at_frame", 0)
		if not _is_number(at_frame_raw):
			return {"error": "steps[%d].at_frame must be a number" % i}
		var at_frame: = int(at_frame_raw)
		if at_frame < 0:
			return {"error": "steps[%d].at_frame must be >= 0" % i}
		if at_frame < prev_frame:
			return {"error": "steps must be ordered by at_frame (steps[%d]=%d < previous %d)" % [i, at_frame, prev_frame]}
		prev_frame = at_frame
		var pressed_raw: Variant = step.get("pressed", true)
		if not (pressed_raw is bool):
			return {"error": "steps[%d].pressed must be a boolean" % i}
		var strength_raw: Variant = step.get("strength", 1.0)
		if not _is_number(strength_raw):
			return {"error": "steps[%d].strength must be a number" % i}
		normalized.append({
			"at_frame": at_frame, 
			"action": action, 
			"pressed": pressed_raw, 
			"strength": clampf(float(strength_raw), 0.0, 1.0), 
		})

	var end_frame: int = int(normalized[-1]["at_frame"]) + settle_frames
	if end_frame > MAX_SEQUENCE_FRAMES:
		return {"error": "sequence spans %d frames, exceeds cap of %d" % [end_frame, MAX_SEQUENCE_FRAMES]}
	return {"steps": normalized, "end_frame": end_frame}







func _run_input_sequence(request_id: String, params: Dictionary) -> void :
	var plan: = _plan_input_sequence(params)
	if plan.has("error"):
		_reply_input_sequence_error(request_id, plan["error"])
		return

	var steps: Array = plan["steps"]
	var end_frame: int = plan["end_frame"]



	for step in steps:
		if not InputMap.has_action(step["action"]):
			_reply_input_sequence_error(request_id, "Unknown action: %s" % step["action"])
			return

	var tree: = get_tree()
	if tree == null:
		_reply_input_sequence_error(request_id, "No SceneTree available for input sequence")
		return

	var applied: Array = []
	var step_i: = 0
	for f in range(0, end_frame + 1):
		while step_i < steps.size() and int(steps[step_i]["at_frame"]) == f:
			var step: Dictionary = steps[step_i]
			_game_input_action(step)
			applied.append({"at_frame": f, "action": step["action"], "pressed": step["pressed"]})
			step_i += 1
		if f < end_frame:
			if _frame_waiter.is_valid():
				await _frame_waiter.call()
			else:
				await tree.process_frame

	_reply_input_sequence_ok(request_id, {
		"completed": true, 
		"steps_applied": applied.size(), 
		"frames_elapsed": end_frame, 
		"applied": applied, 
		"actions_pressed_at_end": _actions_pressed_at_end(steps), 
	})





func _actions_pressed_at_end(steps: Array) -> Array:
	var seen: = {}
	var pressed: Array = []
	for step in steps:
		var action: String = step["action"]
		if seen.has(action):
			continue
		seen[action] = true
		if Input.is_action_pressed(action):
			pressed.append(action)
	return pressed


func _reply_input_sequence_ok(request_id: String, result: Dictionary) -> void :
	result["source"] = "game"
	result["op"] = "input_sequence"
	_last_game_command_reply = {"kind": "response", "op": "input_sequence", "result": result}
	if EngineDebugger.is_active():
		EngineDebugger.send_message("mcp:game_command_response", 
			[request_id, JSON.stringify(_variant_to_json(result))])


func _reply_input_sequence_error(request_id: String, message: String) -> void :
	_last_game_command_reply = {"kind": "error", "op": "input_sequence", "message": message}
	if EngineDebugger.is_active():
		EngineDebugger.send_message("mcp:game_command_error", [request_id, message])







func _resolve_mouse_position(value: Variant) -> Dictionary:
	var viewport: = get_viewport()
	var fallback: = viewport.get_mouse_position() if viewport != null else Vector2.ZERO
	if value == null:
		return {"position": fallback}
	if value is Dictionary:
		var dict: Dictionary = value
		if dict.is_empty():
			return {"position": fallback}


		if not dict.has("x") and not dict.has("y"):
			return {"error": "position object must have an 'x' and/or 'y' key (got keys %s)" % str(dict.keys())}
		var x_val: Variant = dict.get("x", fallback.x)
		var y_val: Variant = dict.get("y", fallback.y)
		if not _is_number(x_val) or not _is_number(y_val):
			return {"error": "position x/y must be numbers (got x=%s, y=%s)" % [type_string(typeof(x_val)), type_string(typeof(y_val))]}
		return {"position": Vector2(float(x_val), float(y_val))}
	if value is Array:
		var arr: Array = value
		if arr.size() != 2:
			return {"error": "position array must be [x, y] (got %d elements)" % arr.size()}
		if not _is_number(arr[0]) or not _is_number(arr[1]):
			return {"error": "position array elements must be numbers (got [%s, %s])" % [type_string(typeof(arr[0])), type_string(typeof(arr[1]))]}
		return {"position": Vector2(float(arr[0]), float(arr[1]))}
	return {"error": "position must be a {x, y} object or [x, y] array (got %s)" % type_string(typeof(value))}


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


func _mouse_button_index(name: String) -> int:
	match name:
		"right":
			return MOUSE_BUTTON_RIGHT
		"middle":
			return MOUSE_BUTTON_MIDDLE
		"wheel_up":
			return MOUSE_BUTTON_WHEEL_UP
		"wheel_down":
			return MOUSE_BUTTON_WHEEL_DOWN
	return MOUSE_BUTTON_LEFT




























const EVAL_TIMEOUT_SEC: = 8.0


func _handle_eval(data: Array) -> void :
	var request_id: String = data[0] if data.size() > 0 else ""
	var code: String = data[1] if data.size() > 1 else ""

	if code.is_empty():
		_reply_eval_error(request_id, "No code provided")
		return






	_eval_token_counter += 1
	var token: = str(_eval_token_counter)
	var run_fn: = "_mcp_run_%s" % token
	var script_source: = _build_eval_script_source(run_fn, code)








	var baseline: int = _logger.script_error_seq() if _logger != null else 0

	var script: GDScript = GDScript.new()
	script.source_code = script_source





	EngineDebugger.send_message("mcp:eval_ack", [request_id])





	var err: int = script.reload()
	if err != OK:
		_reply_eval_error(request_id, 
			"Failed to compile GDScript (error %d). Check syntax." % err)
		return



	EngineDebugger.send_message("mcp:eval_compiled", [request_id])

	var temp_node: = Node.new()
	temp_node.set_script(script)
	temp_node.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(temp_node)

	if not temp_node.has_method("execute"):
		temp_node.queue_free()
		_reply_eval_error(request_id, "Internal error: eval wrapper is missing execute().")
		return




	_inflight_evals[request_id] = {"node": temp_node, "token": token, "baseline": baseline}






	var holder: = {"done": false, "value": null, "abandoned": false}
	_drive_eval(temp_node, holder)

	var tree: = get_tree()
	var deadline_ms: = int(EVAL_TIMEOUT_SEC * 1000.0)
	var start_ms: = Time.get_ticks_msec()
	while not holder["done"] and (Time.get_ticks_msec() - start_ms) < deadline_ms:




		if _try_report_eval_runtime_error(request_id):
			holder["abandoned"] = true
			return
		await tree.process_frame

	if not holder["done"]:


		holder["abandoned"] = true
		if _try_report_eval_runtime_error(request_id):
			return
		_inflight_evals.erase(request_id)
		if is_instance_valid(temp_node):
			remove_child(temp_node)
		_reply_eval_error(request_id, 
			("Eval exceeded %ds and was aborted — the code likely awaits "
				+ "something that never completes (a signal that never fires, a timer on "
				+ "a paused tree) or loops forever. Check logs_read(source='game').")
				%int(EVAL_TIMEOUT_SEC), 
			ErrorCodes.EVAL_HUNG)
		return


	_inflight_evals.erase(request_id)
	temp_node.queue_free()
	_reply_eval_response(request_id, holder["value"])















func _drive_eval(node: Node, holder: Dictionary) -> void :
	var value = await node.execute()
	if holder.get("abandoned", false):
		if is_instance_valid(node):
			node.queue_free()
		return
	holder["value"] = value
	holder["done"] = true








const EVAL_RESULT_MAX_BYTES: = 6 * 1024 * 1024



var _last_eval_reply: Dictionary = {}





func _reply_eval_error(request_id: String, message: String, code: String = "") -> void :
	_last_eval_reply = {"kind": "error", "request_id": request_id, 
		"message": message, "code": code}
	var payload: = [request_id, message]
	if not code.is_empty():
		payload.append(code)
	if EngineDebugger.is_active():
		EngineDebugger.send_message("mcp:eval_error", payload)


func _reply_eval_response(request_id: String, value: Variant) -> void :
	var serialized: = JSON.stringify(_variant_to_json(value))
	var serialized_bytes: = serialized.to_utf8_buffer().size()
	if serialized_bytes > EVAL_RESULT_MAX_BYTES:
		_reply_eval_error(request_id, 
			("Eval result too large to return (%d bytes serialized, limit %d). "
				+ "Return a smaller slice instead — e.g. counts, node paths, or a "
				+ "truncated substring.") % [serialized_bytes, EVAL_RESULT_MAX_BYTES], 
			ErrorCodes.EVAL_RESULT_TOO_LARGE)
		return
	_last_eval_reply = {"kind": "response", "request_id": request_id}
	if EngineDebugger.is_active():
		EngineDebugger.send_message("mcp:eval_response", [request_id, serialized])










func _try_report_eval_runtime_error(request_id: String) -> bool:
	if _logger == null:
		return false
	var entry = _inflight_evals.get(request_id)
	if entry == null:
		return false
	var text: String = _logger.find_script_error_since(
		int(entry["baseline"]), "_mcp_run_%s" % str(entry["token"]))
	if text.is_empty():
		return false
	_inflight_evals.erase(request_id)
	var node: Node = entry["node"]
	if node != null and is_instance_valid(node):
		node.queue_free()
	if EngineDebugger.is_active():
		EngineDebugger.send_message("mcp:eval_runtime_error", [request_id, text])
	return true








func _handle_eval_check(data: Array) -> void :
	var request_id: String = data[0] if data.size() > 0 else ""
	if request_id.is_empty():
		return
	_try_report_eval_runtime_error(request_id)








static func _build_eval_script_source(run_fn: String, code: String) -> String:
	return (
		"extends Node\n"
		+ "func execute() -> Variant:\n"
		+ "\treturn await %s()\n\n" % run_fn
		+ "@warning_ignore(\"untyped_declaration\") func %s():\n" % run_fn
		+ _indent_eval_code(code)
	)


static func _indent_eval_code(code: String) -> String:
	var lines: PackedStringArray = code.split("\n")
	var out: = ""
	for line in lines:
		out += "\t" + line + "\n"
	return out




func _variant_to_json(value: Variant) -> Variant:
	if value == null:
		return null
	if value is bool or value is int or value is float or value is String:
		return value
	if value is Vector2:
		return {"x": value.x, "y": value.y}
	if value is Vector3:
		return {"x": value.x, "y": value.y, "z": value.z}
	if value is Vector4:
		return {"x": value.x, "y": value.y, "z": value.z, "w": value.w}
	if value is Vector2i:
		return {"x": value.x, "y": value.y}
	if value is Vector3i:
		return {"x": value.x, "y": value.y, "z": value.z}
	if value is Vector4i:
		return {"x": value.x, "y": value.y, "z": value.z, "w": value.w}
	if value is Color:
		return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
	if value is Quaternion:
		return {"x": value.x, "y": value.y, "z": value.z, "w": value.w}
	if value is Basis:
		return {
			"x": _variant_to_json(value.x), 
			"y": _variant_to_json(value.y), 
			"z": _variant_to_json(value.z), 
		}
	if value is Transform3D:
		return {
			"basis": _variant_to_json(value.basis), 
			"origin": _variant_to_json(value.origin), 
		}
	if value is Transform2D:
		return {
			"x": _variant_to_json(value.x), 
			"y": _variant_to_json(value.y), 
			"origin": _variant_to_json(value.origin), 
		}
	if value is Rect2:
		return {
			"position": _variant_to_json(value.position), 
			"size": _variant_to_json(value.size), 
		}
	if value is Rect2i:
		return {
			"position": _variant_to_json(value.position), 
			"size": _variant_to_json(value.size), 
		}
	if value is AABB:
		return {
			"position": _variant_to_json(value.position), 
			"size": _variant_to_json(value.size), 
		}
	if value is NodePath or value is StringName:
		return str(value)
	if value is Plane:
		return {
			"normal": _variant_to_json(value.normal), 
			"d": value.d, 
		}
	if value is Projection:
		return {
			"x": _variant_to_json(value.x), 
			"y": _variant_to_json(value.y), 
			"z": _variant_to_json(value.z), 
			"w": _variant_to_json(value.w), 
		}

	if value is PackedByteArray:
		var arr: Array = []
		for item in value: arr.append(item)
		return arr
	if value is PackedInt32Array or value is PackedInt64Array:
		var arr: Array = []
		for item in value: arr.append(item)
		return arr
	if value is PackedFloat32Array or value is PackedFloat64Array:
		var arr: Array = []
		for item in value: arr.append(item)
		return arr
	if value is PackedStringArray:
		var arr: Array = []
		for item in value: arr.append(item)
		return arr
	if value is PackedVector2Array:
		var arr: Array = []
		for item in value: arr.append({"x": item.x, "y": item.y})
		return arr
	if value is PackedVector3Array:
		var arr: Array = []
		for item in value: arr.append({"x": item.x, "y": item.y, "z": item.z})
		return arr
	if value is PackedVector4Array:
		var arr: Array = []
		for item in value: arr.append({"x": item.x, "y": item.y, "z": item.z, "w": item.w})
		return arr
	if value is PackedColorArray:
		var arr: Array = []
		for item in value: arr.append({"r": item.r, "g": item.g, "b": item.b, "a": item.a})
		return arr

	if value is Array:
		var arr: Array = []
		for item in value:
			arr.append(_variant_to_json(item))
		return arr
	if value is Dictionary:
		var dict: Dictionary = {}
		for key in value.keys():
			dict[str(key)] = _variant_to_json(value[key])
		return dict

	return str(value)
