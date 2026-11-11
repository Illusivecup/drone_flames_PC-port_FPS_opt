@tool
class_name McpServerState
extends RefCounted


const UNINITIALIZED: = 0
const SPAWNING: = 1

const READY: = 3
const INCOMPATIBLE: = 4
const CRASHED: = 5
const NO_COMMAND: = 6
const PORT_EXCLUDED: = 7
const FOREIGN_PORT: = 8
const STOPPING: = 10
const STOPPED: = 11
const UNSUPPORTED_CONFIG: = 12

const _NAMES: = {
	UNINITIALIZED: "uninitialized", 
	SPAWNING: "spawning", 
	READY: "ready", 
	INCOMPATIBLE: "incompatible", 
	CRASHED: "crashed", 
	NO_COMMAND: "no_command", 
	PORT_EXCLUDED: "port_excluded", 
	FOREIGN_PORT: "foreign_port", 
	STOPPING: "stopping", 
	STOPPED: "stopped", 
	UNSUPPORTED_CONFIG: "unsupported_config", 
}





static func name_of(state: int) -> String:
	return _NAMES.get(state, "unknown(%d)" % state)




static func is_terminal_diagnosis(state: int) -> bool:
	return (
		state == CRASHED
		or state == NO_COMMAND
		or state == PORT_EXCLUDED
		or state == INCOMPATIBLE
		or state == FOREIGN_PORT
		or state == UNSUPPORTED_CONFIG
	)







static func blocks_client_health(state: int) -> bool:
	return state in [INCOMPATIBLE, UNSUPPORTED_CONFIG]
