@tool
class_name McpCustomToolSpec
extends RefCounted













var name: String = ""
var description: String = ""
var params_schema: Dictionary = {}


var script_path: String = ""
var method: StringName = &""


var source_path: String = ""
var source: String = ""


var promoted: bool = false


var timeout_ms: int = 4500
var deferred: bool = false
var requires_writable: bool = false
var undoable: bool = false


const MAX_DESCRIPTION_CHARS: = 600
const MAX_SCHEMA_BYTES: = 8192
const MAX_TIMEOUT_MS: = 120000
const MIN_TIMEOUT_MS: = 500





func validate() -> Array[String]:
	var errors: Array[String] = []
	if name.is_empty():
		errors.append("name is empty\n")
	if not name.is_valid_ascii_identifier():
		errors.append("name '%s' is not a valid identifier\n" % name)
	if description.length() > MAX_DESCRIPTION_CHARS:
		errors.append("description exceeds %d chars\n" % MAX_DESCRIPTION_CHARS)
	if JSON.stringify(params_schema).to_utf8_buffer().size() > MAX_SCHEMA_BYTES:
		errors.append("params_schema exceeds %d bytes\n" % MAX_SCHEMA_BYTES)
	if script_path.is_empty() or not ResourceLoader.exists(script_path):
		errors.append("script_path '%s' does not exist" % script_path)
	if method.is_empty():
		errors.append("method is empty")
	if timeout_ms < MIN_TIMEOUT_MS or timeout_ms > MAX_TIMEOUT_MS:
		errors.append("timeout_ms %d out of range [%d, %d]" % [timeout_ms, MIN_TIMEOUT_MS, MAX_TIMEOUT_MS])
	if source_path.is_empty() or not source_path.ends_with("plugin.cfg") or not FileAccess.file_exists(source_path):
		errors.append("source_path '%s' must be an existing plugin.cfg path" % source_path)
	return errors
