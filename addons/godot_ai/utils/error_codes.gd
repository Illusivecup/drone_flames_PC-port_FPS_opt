@tool
class_name McpErrorCodes
extends RefCounted



















const INVALID_PARAMS: = "INVALID_PARAMS"
const EDITED_SCENE_MISMATCH: = "EDITED_SCENE_MISMATCH"
const EDITOR_NOT_READY: = "EDITOR_NOT_READY"
const UNKNOWN_COMMAND: = "UNKNOWN_COMMAND"
const INTERNAL_ERROR: = "INTERNAL_ERROR"
const DEFERRED_TIMEOUT: = "DEFERRED_TIMEOUT"




const FILESYSTEM_DISCOVERY_FAILED: = "FILESYSTEM_DISCOVERY_FAILED"


const TRANSPORT_OUTCOME_UNKNOWN: = "TRANSPORT_OUTCOME_UNKNOWN"
const TRANSPORT_OVERLOADED: = "TRANSPORT_OVERLOADED"
const NEW_CLIENT_SESSION_REQUIRED: = "NEW_CLIENT_SESSION_REQUIRED"
const ATTACH_LOCK_TIMEOUT: = "ATTACH_LOCK_TIMEOUT"
const ATTACH_LOCK_ERROR: = "ATTACH_LOCK_ERROR"
const ATTACH_RUNTIME_DIR_ERROR: = "ATTACH_RUNTIME_DIR_ERROR"
const PORT_OCCUPIED: = "PORT_OCCUPIED"
const BACKEND_START_FAILED: = "BACKEND_START_FAILED"
const BACKEND_START_TIMEOUT: = "BACKEND_START_TIMEOUT"

const EVAL_COMPILE_ERROR: = "EVAL_COMPILE_ERROR"
const EVAL_RUNTIME_ERROR: = "EVAL_RUNTIME_ERROR"






const EVAL_GAME_NOT_READY: = "EVAL_GAME_NOT_READY"






const EVAL_HUNG: = "EVAL_HUNG"





const EVAL_RESULT_TOO_LARGE: = "EVAL_RESULT_TOO_LARGE"









const GAME_HELPER_TIMEOUT: = "GAME_HELPER_TIMEOUT"



















const NODE_NOT_FOUND: = "NODE_NOT_FOUND"
const RESOURCE_NOT_FOUND: = "RESOURCE_NOT_FOUND"
const PROPERTY_NOT_ON_CLASS: = "PROPERTY_NOT_ON_CLASS"
const VALUE_OUT_OF_RANGE: = "VALUE_OUT_OF_RANGE"
const WRONG_TYPE: = "WRONG_TYPE"
const MISSING_REQUIRED_PARAM: = "MISSING_REQUIRED_PARAM"
const CUSTOM_TOOL_NOT_UNDOABLE: = "CUSTOM_TOOL_NOT_UNDOABLE"
const CUSTOM_TOOL_DISABLED: = "CUSTOM_TOOL_DISABLED"











const SUB_EDITOR_IMPORTING: = "EDITOR_IMPORTING"
const SUB_EDITOR_PLAYING: = "EDITOR_PLAYING"
const SUB_EDITOR_NO_SCENE: = "EDITOR_NO_SCENE"
const SUB_EDITOR_GAME_NOT_RUNNING: = "EDITOR_GAME_NOT_RUNNING"
const SUB_EDITOR_VIEWPORT_UNAVAILABLE: = "EDITOR_VIEWPORT_UNAVAILABLE"
const SUB_EDITOR_VIEWPORT_NOT_3D: = "EDITOR_VIEWPORT_NOT_3D"
const SUB_EDITOR_VIEWPORT_EMPTY: = "EDITOR_VIEWPORT_EMPTY"
const SUB_EDITOR_UNAVAILABLE: = "EDITOR_UNAVAILABLE"




const SUB_EDITOR_TEST_RUNNING: = "EDITOR_TEST_RUNNING"




const TEST_RUN_TIMEOUT: = "TEST_RUN_TIMEOUT"



static func make(code: String, message: String) -> Dictionary:
	return {"status": "error", "error": {"code": code, "message": message}}








static func make_not_ready(
	sub_code: String, message: String, retryable: bool, hint: String = ""
) -> Dictionary:
	var err: = make(EDITOR_NOT_READY, message)
	var data: = {"sub_code": sub_code, "retryable": retryable}
	if not hint.is_empty():
		data["hint"] = hint
	err["error"]["data"] = data
	return err







static func prefix_message(err: Dictionary, prefix: String) -> Dictionary:
	if prefix.is_empty():
		return err
	var inner: Dictionary = err.get("error", {})
	var code: String = inner.get("code", INTERNAL_ERROR)
	var message: String = inner.get("message", "")
	return make(code, "%s: %s" % [prefix, message])
