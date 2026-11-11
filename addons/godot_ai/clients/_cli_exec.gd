@tool
class_name McpCliExec
extends RefCounted




































const DEFAULT_TIMEOUT_MS: = 8000
const _POLL_INTERVAL_MS: = 50
const _QUICK_EXIT_WINDOW_MS: = 250
const _KILL_GRACE_MS: = 500
const PortResolver: = preload("res://addons/godot_ai/utils/port_resolver.gd")
const UvResolution: = preload("res://addons/godot_ai/utils/uv_resolution_policy.gd")


static func run(
	exe: String, 
	args: Array, 
	timeout_ms: int = DEFAULT_TIMEOUT_MS, 
	capture_stderr: bool = true, 
	cancel_check: Callable = Callable(), 
	isolate_uv_resolution: bool = false, 
) -> Dictionary:
	if exe.is_empty():
		return _spawn_failed_result()
	return _run_piped(
		exe, args, timeout_ms, capture_stderr, cancel_check, isolate_uv_resolution
	)


static func _run_piped(
	exe: String, 
	args: Array, 
	timeout_ms: int, 
	capture_stderr: bool, 
	cancel_check: Callable, 
	isolate_uv_resolution: bool, 
) -> Dictionary:

	var spawn_exe: = exe
	var spawn_args: = args
	if OS.get_name() == "Windows":
		var lower: = exe.to_lower()
		if lower.ends_with(".cmd") or lower.ends_with(".bat"):








			spawn_exe = "cmd.exe"
			spawn_args = ["/c", exe]
			spawn_args.append_array(args)

	PortResolver.lock_process_spawn()
	var saved_uv_environment: = (
		UvResolution.isolate_environment() if isolate_uv_resolution else {}
	)
	var info: = OS.execute_with_pipe(spawn_exe, spawn_args)
	UvResolution.restore_environment(saved_uv_environment)
	PortResolver.unlock_process_spawn()
	if info.is_empty():
		return _spawn_failed_result()

	var pid: int = int(info.get("pid", -1))
	var stdio: Variant = info.get("stdio", null)
	var stderr_pipe: Variant = info.get("stderr", null)
	if pid <= 0:
		_close_pipes(stdio, stderr_pipe)
		return _spawn_failed_result()
	var deadline: = Time.get_ticks_msec() + maxi(timeout_ms, _POLL_INTERVAL_MS)
	var kill_grant: Dictionary = {}




	var quick_deadline: = mini(deadline, Time.get_ticks_msec() + _QUICK_EXIT_WINDOW_MS)
	var cancellation_requested: = false
	while OS.is_process_running(pid) and Time.get_ticks_msec() < quick_deadline:
		if cancel_check.is_valid() and bool(cancel_check.call()):
			cancellation_requested = true
			break
		OS.delay_msec(mini(_POLL_INTERVAL_MS, maxi(0, quick_deadline - Time.get_ticks_msec())))
	if OS.is_process_running(pid):
		kill_grant = PortResolver.capture_process_kill_grant(pid)

	while OS.is_process_running(pid):
		var cancelled: = cancellation_requested or (cancel_check.is_valid() and bool(cancel_check.call()))
		if cancelled or Time.get_ticks_msec() >= deadline:




			var killed: Array[int] = []
			if not kill_grant.is_empty():
				killed = PortResolver.kill_exact_processes([kill_grant], false, true)
			var kill_deadline: = Time.get_ticks_msec() + _KILL_GRACE_MS
			while PortResolver.pid_alive(pid) and Time.get_ticks_msec() < kill_deadline:
				OS.delay_msec(_POLL_INTERVAL_MS)

			var termination_failed: = (
				PortResolver.pid_alive(pid)
				or OS.get_name() != "Windows"
				or not killed.has(pid)
			)
			var partial_stdout: = ""
			var partial_stderr: = ""
			if not termination_failed:
				partial_stdout = _drain_pipe(stdio)
				partial_stderr = _drain_pipe(stderr_pipe) if capture_stderr else ""
			_close_pipes(stdio, stderr_pipe)
			return {
				"exit_code": -1, 
				"stdout": partial_stdout, 
				"stderr": partial_stderr, 
				"output": _join_streams(partial_stdout, partial_stderr), 
				"timed_out": not cancelled, 
				"cancelled": cancelled, 
				"spawn_failed": false, 
				"termination_failed": termination_failed, 
			}
		OS.delay_msec(_POLL_INTERVAL_MS)

	var stdout: = _drain_pipe(stdio)
	var stderr_text: = _drain_pipe(stderr_pipe) if capture_stderr else ""
	_close_pipes(stdio, stderr_pipe)

	return {
		"exit_code": OS.get_process_exit_code(pid), 
		"stdout": stdout, 
		"stderr": stderr_text, 
		"output": _join_streams(stdout, stderr_text), 
		"timed_out": false, 
		"cancelled": false, 
		"spawn_failed": false, 
		"termination_failed": false, 
	}


static func _spawn_failed_result() -> Dictionary:
	return {
		"exit_code": -1, 
		"stdout": "", 
		"stderr": "", 
		"output": "", 
		"timed_out": false, 
		"cancelled": false, 
		"spawn_failed": true, 
		"termination_failed": false, 
	}


static func _drain_pipe(pipe: Variant) -> String:
	if not (pipe is FileAccess):
		return ""
	var f: = pipe as FileAccess
	var bytes: = PackedByteArray()
	var max_bytes: = 1 << 20
	while bytes.size() < max_bytes:
		var chunk: = f.get_buffer(mini(4096, max_bytes - bytes.size()))
		if chunk.is_empty():
			break
		bytes.append_array(chunk)
		if f.eof_reached():
			break
	return bytes.get_string_from_utf8()


static func _join_streams(stdout: String, stderr_text: String) -> String:




	if stderr_text.is_empty():
		return stdout
	if stdout.is_empty():
		return stderr_text
	return "%s\n%s" % [stdout, stderr_text]


static func _close_pipes(stdio: Variant, stderr_pipe: Variant) -> void :
	if stdio is FileAccess:
		(stdio as FileAccess).close()
	if stderr_pipe is FileAccess:
		(stderr_pipe as FileAccess).close()
