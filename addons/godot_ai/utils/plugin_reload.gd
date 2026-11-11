@tool
extends RefCounted



const PLUGIN_CFG: = "res://addons/godot_ai/plugin.cfg"
const ScriptWork: = preload("res://addons/godot_ai/utils/script_work.gd")




const SCAN_TIMEOUT_SECONDS: = 60.0


static var _scan_timeout_seconds: float = SCAN_TIMEOUT_SECONDS



static var _pending_scan: Dictionary = {}


static func is_reload_pending() -> bool:
	return not _pending_scan.is_empty()




static func reserve_reload() -> int:
	if is_reload_pending():
		return 0
	var work: = ScriptWork.begin("reload_plugin")
	_pending_scan = {"work": work}
	return work


static func reload_after_scan(work: int = 0) -> void :
	if work == 0:
		work = reserve_reload()
		if work == 0:
			return
	elif _pending_scan.get("work", 0) != work or bool(_pending_scan.get("toggling", false)):
		return
	_start_scan(EditorInterface.get_resource_filesystem(), null, work)


static func _start_scan(filesystem: Object, timer: Object, work: int) -> void :
	if not _pending_scan.is_empty() and (
		_pending_scan.get("work", 0) != work or _pending_scan.has("filesystem")
		or bool(_pending_scan.get("toggling", false))
	):
		if _pending_scan.get("work", 0) != work:
			ScriptWork.finish(work)
		push_error("MCP | a plugin reload is already waiting for its filesystem scan")
		return
	if timer == null:

		timer = Engine.get_main_loop().create_timer(_scan_timeout_seconds, true, false, true)
	var complete: = _finish_scan.bind(work, false)
	var timeout: = _finish_scan.bind(work, true)
	_pending_scan = {"work": work, "filesystem": filesystem, "timer": timer, 
		"complete": complete, "timeout": timeout}
	filesystem.filesystem_changed.connect(complete, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	timer.timeout.connect(timeout, CONNECT_ONE_SHOT)
	filesystem.scan()


static func _take_scan() -> Dictionary:
	var pending: = _pending_scan
	_pending_scan = {}
	if pending.has("filesystem"):
		if pending.filesystem.filesystem_changed.is_connected(pending.complete):
			pending.filesystem.filesystem_changed.disconnect(pending.complete)
		if pending.timer.timeout.is_connected(pending.timeout):
			pending.timer.timeout.disconnect(pending.timeout)
	return pending


static func _finish_scan(work: int, timed_out: bool) -> void :

	if _pending_scan.get("work", 0) != work or not _pending_scan.has("filesystem"):
		return
	if timed_out:
		var pending: = _take_scan()
		ScriptWork.finish(pending.work)
		push_error(
			"MCP | filesystem scan did not finish within %d s; plugin left unchanged, retry reload"
			%int(_scan_timeout_seconds)
		)
	else:
		reload_enabled_plugin()


static func reload_enabled_plugin() -> Error:


	if not is_reload_pending():
		reserve_reload()
	elif bool(_pending_scan.get("toggling", false)):
		return ERR_BUSY


	var pending: = _take_scan()
	_pending_scan = {"work": pending.work, "toggling": true}
	var result: = _toggle_enabled_plugin()
	_take_scan()
	ScriptWork.finish(pending.work)
	return result


static func _toggle_enabled_plugin() -> Error:
	if not EditorInterface.is_plugin_enabled(PLUGIN_CFG):
		push_error("MCP | cannot reload a disabled plugin")
		return ERR_UNAVAILABLE
	EditorInterface.set_plugin_enabled(PLUGIN_CFG, false)
	EditorInterface.set_plugin_enabled(PLUGIN_CFG, true)
	if not EditorInterface.is_plugin_enabled(PLUGIN_CFG):
		push_error("MCP | plugin could not be re-enabled after reload")
		return FAILED



	var error: = ProjectSettings.save()
	if error != OK:
		push_error("MCP | reloaded plugin enablement could not be saved: %s" % error_string(error))
	return error
