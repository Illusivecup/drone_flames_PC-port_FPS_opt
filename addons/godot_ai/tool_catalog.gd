@tool
class_name McpToolCatalog
extends RefCounted














const CORE_TOOLS: = [
	"editor_state", 
	"node_get_properties", 
	"scene_get_hierarchy", 
	"session_activate", 
]





const ALWAYS_ON_TOOLS: = [
	"session_manage", 
]







const DOMAINS: = [
	{"id": "animation", "label": "animation", "count": 2, "tools": ["animation_create", "animation_manage"]}, 
	{"id": "api", "label": "api", "count": 1, "tools": ["api_manage"]}, 
	{"id": "audio", "label": "audio", "count": 1, "tools": ["audio_manage"]}, 
	{"id": "autoload", "label": "autoload", "count": 1, "tools": ["autoload_manage"]}, 
	{"id": "batch", "label": "batch", "count": 1, "tools": ["batch_execute"]}, 
	{"id": "camera", "label": "camera", "count": 1, "tools": ["camera_manage"]}, 
	{"id": "client", "label": "client", "count": 1, "tools": ["client_manage"]}, 
	{"id": "custom", "label": "custom", "count": 1, "tools": ["custom_manage"]}, 
	{"id": "editor", "label": "editor", "count": 4, "tools": ["editor_manage", "editor_reload_plugin", "editor_screenshot", "logs_read"]}, 
	{"id": "filesystem", "label": "filesystem", "count": 1, "tools": ["filesystem_manage"]}, 
	{"id": "game", "label": "game", "count": 1, "tools": ["game_manage"]}, 
	{"id": "input_map", "label": "input_map", "count": 1, "tools": ["input_map_manage"]}, 
	{"id": "material", "label": "material", "count": 1, "tools": ["material_manage"]}, 
	{"id": "navigation", "label": "navigation", "count": 1, "tools": ["navigation_manage"]}, 
	{"id": "node", "label": "node", "count": 4, "tools": ["node_create", "node_find", "node_manage", "node_set_property"]}, 
	{"id": "particle", "label": "particle", "count": 1, "tools": ["particle_manage"]}, 
	{"id": "project", "label": "project", "count": 2, "tools": ["project_manage", "project_run"]}, 
	{"id": "resource", "label": "resource", "count": 1, "tools": ["resource_manage"]}, 
	{"id": "scene", "label": "scene", "count": 3, "tools": ["scene_manage", "scene_open", "scene_save"]}, 
	{"id": "script", "label": "script", "count": 4, "tools": ["script_attach", "script_create", "script_manage", "script_patch"]}, 
	{"id": "signal", "label": "signal", "count": 1, "tools": ["signal_manage"]}, 
	{"id": "testing", "label": "testing", "count": 2, "tools": ["test_manage", "test_run"]}, 
	{"id": "theme", "label": "theme", "count": 1, "tools": ["theme_manage"]}, 
	{"id": "tilemap", "label": "tilemap", "count": 1, "tools": ["tilemap_manage"]}, 
	{"id": "tileset", "label": "tileset", "count": 1, "tools": ["tileset_manage"]}, 
	{"id": "gridmap", "label": "gridmap", "count": 1, "tools": ["gridmap_manage"]}, 
	{"id": "csg", "label": "csg", "count": 1, "tools": ["csg_manage"]}, 
	{"id": "ui", "label": "ui", "count": 1, "tools": ["ui_manage"]}, 
]






static func is_excludable_domain(id: String) -> bool:
	for d in DOMAINS:
		if d["id"] == id:
			return true
	return false




static func total_tool_count() -> int:
	var n: = CORE_TOOLS.size() + ALWAYS_ON_TOOLS.size()
	for d in DOMAINS:
		n += int(d["count"])
	return n



static func enabled_tool_count(excluded: PackedStringArray) -> int:
	var n: = CORE_TOOLS.size() + ALWAYS_ON_TOOLS.size()
	for d in DOMAINS:
		if excluded.find(d["id"]) == -1:
			n += int(d["count"])
	return n






static func canonical(excluded: PackedStringArray) -> String:
	var seen: = PackedStringArray()
	for e in excluded:
		var t: = e.strip_edges()
		if not t.is_empty() and seen.find(t) == -1:
			seen.append(t)
	seen.sort()
	return ",".join(seen)
