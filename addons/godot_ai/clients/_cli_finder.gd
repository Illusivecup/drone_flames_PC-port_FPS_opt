@tool
class_name McpCliFinder
extends RefCounted



















static var _mutex: Mutex = Mutex.new()
static var _cache: Dictionary = {}
static var _searched: Dictionary = {}

const _LOOKUP_TIMEOUT_MS: = 3000
const _TRACE_PATH_LIMIT: = 16
const _TRACE_PATH_MAX_CHARS: = 512




static func find(exe_names: Array[String], trace: Callable = Callable()) -> String:
	for name in exe_names:
		var hit: = _find_one(name, trace)
		if not hit.is_empty():
			return hit
	return ""



static func invalidate(exe_name: String = "") -> void :
	_mutex.lock()
	if exe_name.is_empty():
		_cache.clear()
		_searched.clear()
	else:
		_cache.erase(exe_name)
		_searched.erase(exe_name)
	_mutex.unlock()


static func _find_one(exe_name: String, trace: Callable = Callable()) -> String:
	var started: = Time.get_ticks_msec()
	_mutex.lock()
	var already_searched: bool = _searched.get(exe_name, false)
	var cached: String = _cache.get(exe_name, "")
	_mutex.unlock()
	if already_searched:
		_trace_lookup(
			trace, 
			"cache", 
			"resolved" if not cached.is_empty() else "cached_miss", 
			started, 
			{}, 
			true, 
			cached, 
		)
		return cached





	var hit: = _resolve(exe_name, trace)
	_mutex.lock()
	_cache[exe_name] = hit
	_searched[exe_name] = true
	_mutex.unlock()
	return hit


static func _resolve(exe_name: String, trace: Callable = Callable()) -> String:
	var started: = Time.get_ticks_msec()
	var is_windows: = OS.get_name() == "Windows"


	var well_known_paths: = PackedStringArray()
	for dir in _well_known_dirs():
		var full: = dir.path_join(exe_name)
		well_known_paths.append(full)
		if FileAccess.file_exists(full):
			_trace_lookup(trace, "well_known", "resolved", started, {}, false, full, well_known_paths)
			return full
	_trace_lookup(trace, "well_known", "no_match", started, {}, false, "", well_known_paths)


	if not is_windows:



		var shell: = McpPathTemplate.env_lookup("SHELL")
		if shell.is_empty():
			shell = "/bin/bash"
		var stripped: = exe_name.trim_suffix(".exe")
		started = Time.get_ticks_msec()
		var login_result: = McpCliExec.run(shell, ["-lc", "command -v %s" % stripped], _LOOKUP_TIMEOUT_MS, false)
		if int(login_result.get("exit_code", -1)) == 0:
			var login_found: String = str(login_result.get("stdout", "")).strip_edges()
			if not login_found.is_empty() and FileAccess.file_exists(login_found):
				_trace_lookup(
					trace, 
					"login_shell", 
					"resolved", 
					started, 
					login_result, 
					false, 
					login_found, 
					PackedStringArray([login_found]), 
				)
				return login_found
		_trace_lookup(trace, "login_shell", _lookup_failure(login_result, false), started, login_result)


	return _resolve_inherited_path(exe_name, is_windows, trace)





static func _resolve_inherited_path(
	exe_name: String, 
	is_windows: bool, 
	trace: Callable = Callable(), 
	lookup_runner: Callable = Callable(), 
) -> String:
	var lookup: = "where" if is_windows else "which"
	var started: = Time.get_ticks_msec()
	var result: Dictionary = {}
	if lookup_runner.is_valid():
		var injected: Variant = lookup_runner.call(lookup, exe_name)
		if injected is Dictionary:
			result = injected
	else:
		result = McpCliExec.run(lookup, [exe_name], _LOOKUP_TIMEOUT_MS, false)
	var lines: = PackedStringArray(str(result.get("stdout", "")).split("\n"))
	if int(result.get("exit_code", -1)) == 0:
		var found: = _pick_best_path(lines) if is_windows else lines[0].strip_edges()
		if not found.is_empty():
			_trace_lookup(trace, "inherited_path", "resolved", started, result, false, found, lines)
			return found
	_trace_lookup(
		trace, "inherited_path", _lookup_failure(result, true), started, result, false, "", lines
	)
	return ""


static func _lookup_failure(result: Dictionary, absence_exit: bool) -> String:
	for flag in ["termination_failed", "cancelled", "timed_out", "spawn_failed"]:
		if bool(result.get(flag, false)):
			return flag
	var code: = int(result.get("exit_code", -1))
	if code == 0:
		return "empty_output" if str(result.get("stdout", "")).strip_edges().is_empty() else "unusable_output"
	return "not_found" if absence_exit and code == 1 else "nonzero_exit"


static func _trace_lookup(
	trace: Callable, tier: String, status: String, started: int, 
	result: Dictionary = {}, cache_hit: = false, resolved_path: = "", 
	candidate_paths: PackedStringArray = PackedStringArray(), 
) -> void :
	if not trace.is_valid():
		return
	trace.call({
		"tier": tier, "status": status, 
		"elapsed_ms": clampi(Time.get_ticks_msec() - started, 0, 2147483647), 
		"cache_hit": cache_hit, 
		"exit_code": clampi(int(result.get("exit_code", -1)), -2147483648, 2147483647), 
		"timed_out": bool(result.get("timed_out", false)), 
		"spawn_failed": bool(result.get("spawn_failed", false)), 
		"cancelled": bool(result.get("cancelled", false)), 
		"termination_failed": bool(result.get("termination_failed", false)), 
		"resolved_path": _bounded_trace_path(resolved_path), 
		"candidate_paths": _bounded_trace_paths(candidate_paths), 
	})




static func _bounded_trace_paths(paths: PackedStringArray) -> Array[String]:
	var bounded: Array[String] = []
	for raw in paths:
		var path: = _bounded_trace_path(raw)
		if path.is_empty() or bounded.has(path):
			continue
		bounded.append(path)
		if bounded.size() >= _TRACE_PATH_LIMIT:
			break
	return bounded


static func _bounded_trace_path(raw: String) -> String:
	var path: = raw.strip_edges()
	if not _is_traceable_path(path):
		return ""
	return path.left(_TRACE_PATH_MAX_CHARS)


static func _is_traceable_path(path: String) -> bool:
	if path.is_empty() or path.contains("\n") or path.contains("\r"):
		return false
	if path.begins_with("/") or path.begins_with("\\\\"):
		return true
	return (
		path.length() >= 3
		and path.substr(1, 1) == ":"
		and (path.substr(2, 1) == "\\" or path.substr(2, 1) == "/")
	)






const _WINDOWS_EXEC_EXTS: = [".exe", ".cmd", ".bat", ".com"]


















static func _pick_best_path(lines: PackedStringArray) -> String:
	var stripped: = PackedStringArray()
	for raw in lines:
		var line: = raw.strip_edges()
		if not line.is_empty():
			stripped.append(line)
	if stripped.is_empty():
		return ""
	for ext in _WINDOWS_EXEC_EXTS:
		for candidate in stripped:
			if candidate.to_lower().ends_with(ext):
				return candidate
	return stripped[0]


static func _well_known_dirs() -> Array[String]:


	var home: = McpPathTemplate.env_lookup("HOME")
	if home.is_empty():
		home = McpPathTemplate.env_lookup("USERPROFILE")
	match OS.get_name():
		"macOS":
			return [
				home.path_join(".local/bin"), 
				home.path_join(".claude/local"), 
				home.path_join(".cargo/bin"), 
				"/opt/homebrew/bin", 
				"/usr/local/bin", 
			]
		"Windows":
			var local: = McpPathTemplate.env_lookup("LOCALAPPDATA")
			var prog: = McpPathTemplate.env_lookup("ProgramFiles")
			var paths: Array[String] = []
			if not home.is_empty():
				paths.append(home.path_join(".claude/local"))
				paths.append(home.path_join(".local/bin"))
				paths.append(home.path_join(".cargo/bin"))
				paths.append(home.path_join("AppData/Local/Programs/uv"))
			if not local.is_empty():
				paths.append(local.path_join("Programs/uv"))
			if not prog.is_empty():
				paths.append(prog.path_join("uv"))
			return paths
		_:
			return [
				home.path_join(".local/bin"), 
				home.path_join(".claude/local"), 
				home.path_join(".cargo/bin"), 
				"/usr/local/bin", 
			]
