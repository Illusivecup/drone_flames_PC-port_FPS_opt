@tool
class_name McpClientRefreshState
extends RefCounted














const IDLE: = 0




const DEFERRED_FOR_FILESYSTEM: = 1



const RUNNING: = 2



const RUNNING_TIMED_OUT: = 3



const SHUTTING_DOWN: = 4

const _NAMES: = {
	IDLE: "idle", 
	DEFERRED_FOR_FILESYSTEM: "deferred_for_filesystem", 
	RUNNING: "running", 
	RUNNING_TIMED_OUT: "running_timed_out", 
	SHUTTING_DOWN: "shutting_down", 
}


static func name_of(state: int) -> String:
	return _NAMES.get(state, "unknown(%d)" % state)




static func has_worker_alive(state: int) -> bool:
	return state == RUNNING or state == RUNNING_TIMED_OUT






static func should_disable_client_actions(state: int) -> bool:
	return state == RUNNING




static func is_blocked_for_spawn(state: int) -> bool:
	return state == SHUTTING_DOWN



static func should_show_checking_badge(state: int) -> bool:
	return state == RUNNING or state == RUNNING_TIMED_OUT




static func can_transition(from: int, to: int) -> bool:
	if from == to:
		return true

	if from == SHUTTING_DOWN:
		return false

	if to == SHUTTING_DOWN:
		return true
	match from:
		IDLE:
			return to == RUNNING or to == DEFERRED_FOR_FILESYSTEM
		DEFERRED_FOR_FILESYSTEM:


			return to == RUNNING or to == IDLE
		RUNNING:


			return to == IDLE or to == RUNNING_TIMED_OUT
		RUNNING_TIMED_OUT:


			return to == IDLE
	return false
