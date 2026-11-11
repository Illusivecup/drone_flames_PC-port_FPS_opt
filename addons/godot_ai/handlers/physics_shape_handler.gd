@tool
extends "res://addons/godot_ai/handlers/command_handler.gd"

const Refresh: = preload("res://addons/godot_ai/handlers/physics_shape_refresh.gd")
const ErrorCodes: = preload("res://addons/godot_ai/utils/error_codes.gd")








var _undo_redo: EditorUndoRedoManager
var _connection


func _init(undo_redo: EditorUndoRedoManager, connection = null) -> void :
	_undo_redo = undo_redo
	_connection = connection


const _SHAPE_3D_CLASSES: = {
	"box": "BoxShape3D", 
	"sphere": "SphereShape3D", 
	"capsule": "CapsuleShape3D", 
	"cylinder": "CylinderShape3D", 
}





const _GENERATE_SHAPE_3D_CLASSES: = {
	"box": "BoxShape3D", 
	"sphere": "SphereShape3D", 
	"capsule": "CapsuleShape3D", 
	"cylinder": "CylinderShape3D", 
	"convex": "ConvexPolygonShape3D", 
	"trimesh": "ConcavePolygonShape3D", 
}

const _SHAPE_2D_CLASSES: = {
	"rectangle": "RectangleShape2D", 
	"circle": "CircleShape2D", 
	"capsule": "CapsuleShape2D", 
}

const _GENERATED_BODY_CLASSES: = {
	"static": "StaticBody3D", 
	"area": "Area3D", 
	"rigid": "RigidBody3D", 
	"character": "CharacterBody3D", 
}



const _GENERATE_CONCAVE_BODIES: = ["static", "area"]


const _GENERATE_DYNAMIC_BODIES: = ["rigid", "character"]
const _GENERATE_DIRECT_MAX_PATHS: = 16
const _GENERATE_MAX_PATHS: = 1024



const _GENERATE_DEFERRED_TIMEOUT_MS: = 30000



const _GENERATE_FRAME_BUDGET_USEC: = 4000
const _GENERATE_COLLIDER_SUFFIX: = "Collider"
const _GENERATE_SCALE_EPSILON: = 0.0001



const _GENERATE_SNAP_EPSILON: = 1e-06


const MeshWorkload: = preload("res://addons/godot_ai/utils/mesh_workload.gd")
const _GENERATE_HULL_MAX_TRIANGLES: = MeshWorkload.MAX_TRIANGLES
const _GENERATE_HULL_MAX_VERTICES: = MeshWorkload.MAX_VERTICES
const _GENERATE_HULL_MAX_SURFACES: = MeshWorkload.MAX_SURFACES






static func _normalize_shape_type(type_map: Dictionary, requested: String) -> String:
	if type_map.has(requested):
		return requested
	for short_form in type_map:
		if type_map[short_form] == requested:
			return short_form
	return ""







func generate(params: Dictionary) -> Dictionary:
	var validated: = _validate_generate_request(params)
	if validated.has("error"):
		return validated

	var request_id: String = params.get("_request_id", "")
	if _connection != null and not request_id.is_empty():
		var job: = _generate_job(validated, _undo_redo, _connection, request_id)
		_drive_generate_job(job, _connection)
		return {
			"_deferred": true, 
			"_deferred_timeout_ms": _GENERATE_DEFERRED_TIMEOUT_MS, 
		}




	var path_count: int = validated.paths.size()
	if path_count > _GENERATE_DIRECT_MAX_PATHS:
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			(
				"physics_shape_generate received %d paths; inside batch_execute at most %d are "
				+ "supported — call resource_manage(op='physics_shape_generate') directly for larger batches"
			) % [path_count, _GENERATE_DIRECT_MAX_PATHS], 
		)
	var job: = _generate_job(validated, _undo_redo, null, "")
	while not _generate_step(job, -1):
		pass
	return job.result




static func _validate_generate_request(params: Dictionary) -> Dictionary:
	var requested_shape: = String(params.get("shape_type", "box"))
	var shape_type: = "auto" if requested_shape == "auto" else _normalize_shape_type(_GENERATE_SHAPE_3D_CLASSES, requested_shape)
	if shape_type.is_empty():
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			"Invalid shape_type '%s'. Valid: auto, %s" % [requested_shape, ", ".join(_GENERATE_SHAPE_3D_CLASSES.keys())]
		)
	var body_type: = String(params.get("body_type", "static"))
	if not _GENERATED_BODY_CLASSES.has(body_type):
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			"Invalid body_type '%s'. Valid: %s" % [body_type, ", ".join(_GENERATED_BODY_CLASSES.keys())]
		)
	if shape_type == "trimesh" and not _GENERATE_CONCAVE_BODIES.has(body_type):
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			(
				"body_type '%s' cannot carry a trimesh shape — a ConcavePolygonShape3D only "
				+ "simulates on a StaticBody3D or Area3D; use shape_type 'convex' or a primitive"
			) % body_type
		)




	var dynamic_body: = _GENERATE_DYNAMIC_BODIES.has(body_type)
	var reparent_mesh: = dynamic_body
	if params.has("reparent_mesh"):
		if not params["reparent_mesh"] is bool:
			return ErrorCodes.make(ErrorCodes.WRONG_TYPE, "reparent_mesh must be a boolean")
		reparent_mesh = params["reparent_mesh"]
		if dynamic_body and not reparent_mesh:
			return ErrorCodes.make(
				ErrorCodes.VALUE_OUT_OF_RANGE, 
				(
					"body_type '%s' must own its visual mesh — a detached dynamic body "
					+ "moves away from the stationary mesh. Pass reparent_mesh=true, or use "
					+ "body_type 'static' or 'area' for a sibling collider"
				) % body_type
			)

	if params.has("overwrite") and params.overwrite is not bool:
		return ErrorCodes.make(ErrorCodes.WRONG_TYPE, "overwrite must be a boolean")
	var raw_paths: Variant = params.get("paths", [])
	if not raw_paths is Array:
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE, 
			"paths must be an array of MeshInstance3D scene paths, got %s" % type_string(typeof(raw_paths)), 
		)
	if raw_paths.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: paths")
	if raw_paths.size() > _GENERATE_MAX_PATHS:
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			"paths supports at most %d entries per request, got %d" % [_GENERATE_MAX_PATHS, raw_paths.size()], 
		)
	var paths: Array[String] = []
	var seen: = {}
	for index in raw_paths.size():
		var raw_path: Variant = raw_paths[index]
		if not raw_path is String:
			return ErrorCodes.make(
				ErrorCodes.WRONG_TYPE, 
				"paths[%d] must be a MeshInstance3D scene path string, got %s"
				%[index, type_string(typeof(raw_path))], 
			)
		if seen.has(raw_path):
			return ErrorCodes.make(
				ErrorCodes.VALUE_OUT_OF_RANGE, 
				"paths lists %s twice (entries %d and %d); each mesh gets one collider"
				%[raw_path, int(seen[raw_path]), index], 
			)
		seen[raw_path] = index
		paths.append(raw_path)

	var scene_check: = McpScenePath.require_edited_scene(params.get("scene_file", ""))
	if scene_check.has("error"):
		return scene_check
	return {
		"data": true, 
		"scene_root": scene_check.node, 
		"scene_file": params.get("scene_file", ""), 
		"shape_type": shape_type, 
		"body_type": body_type, 
		"reparent_mesh": reparent_mesh, 
		"paths": paths, 
		"overwrite": params.get("overwrite", false), 
	}


static func _mesh_workload(mesh: Mesh) -> Dictionary:
	return MeshWorkload.estimate(mesh)


static func _validate_hull_workload(mesh: Mesh, mesh_path: String, shape_type: String) -> Dictionary:
	var workload: = _mesh_workload(mesh)
	if workload.has("error"):
		return workload
	if int(workload.triangles) == 0:
		return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, 
			"MeshInstance3D at %s has a mesh with no faces - a %s shape needs triangles" % [mesh_path, shape_type])
	if int(workload.triangles) > _GENERATE_HULL_MAX_TRIANGLES or int(workload.vertices) > _GENERATE_HULL_MAX_VERTICES:
		return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, 
			"MeshInstance3D at %s exceeds the synchronous hull input limit: at most %d triangles and %d vertices; estimated %d triangles and %d vertices. Reduce geometry or use a primitive collision shape." % [
				mesh_path, _GENERATE_HULL_MAX_TRIANGLES, _GENERATE_HULL_MAX_VERTICES, 
				int(workload.triangles), int(workload.vertices)])
	return {}


static func _auto_generate_shape(mesh: Mesh) -> String:
	if mesh is SphereMesh:
		return "sphere"
	if mesh is CapsuleMesh:
		return "capsule"
	if mesh is CylinderMesh:
		return "cylinder"
	return "box"



static func _plan_generate_mesh(
	mesh_path: String, scene_file: String, scene_root: Node, shape_type: String, reparent_mesh: bool
) -> Dictionary:
	var resolved: = McpNodeValidator.resolve_or_error(mesh_path, "paths", scene_file)
	if resolved.has("error"):
		return resolved
	var node: Node = resolved.node
	if node == scene_root:
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			"%s is the scene root — a sibling body needs a parent inside the scene" % mesh_path
		)
	if not node is MeshInstance3D:
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE, 
			"Node at %s is %s — must be MeshInstance3D" % [mesh_path, node.get_class()]
		)
	var mesh: = node as MeshInstance3D
	if mesh.has_meta(Refresh.MARKER):
		return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, "Mesh at %s already has a collider sibling or generated collider provenance; use overwrite=true to refresh its shape" % mesh_path)
	var parent: = mesh.get_parent()
	if parent != null and parent.has_meta(Refresh.MARKER):
		return ErrorCodes.make(ErrorCodes.VALUE_OUT_OF_RANGE, "Cannot create beneath a generated body at %s: missing or inconsistent source provenance" % mesh_path)
	if parent == null:
		return ErrorCodes.make(
			ErrorCodes.INVALID_PARAMS, 
			"MeshInstance3D at %s has no parent — cannot create a sibling body" % mesh_path
		)
	if mesh.mesh == null:
		return ErrorCodes.make(
			ErrorCodes.RESOURCE_NOT_FOUND, 
			"MeshInstance3D at %s has no mesh resource — there are no bounds to fit" % mesh_path
		)
	var auto_shape: = shape_type == "auto"
	if auto_shape:
		shape_type = _auto_generate_shape(mesh.mesh)
	if shape_type == "convex" or shape_type == "trimesh":
		var error: = _validate_hull_workload(mesh.mesh, mesh_path, shape_type)
		if not error.is_empty():
			return error
	var collider_name: = mesh.name + _GENERATE_COLLIDER_SUFFIX
	var existing: = parent.get_node_or_null(NodePath(collider_name))
	if existing != null:
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			"MeshInstance3D at %s already has a collider sibling at %s — remove or rename it first"
			%[mesh_path, McpScenePath.from_node(existing, scene_root)]
		)


	if reparent_mesh and mesh.top_level:
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			"MeshInstance3D at %s has top_level enabled — reparent_mesh cannot couple it to the generated body" % mesh_path
		)





	if not mesh.top_level and shape_type != "box" and parent is Node3D:
		var parent_scale: Vector3 = (parent as Node3D).global_transform.basis.get_scale()
		var spread: = absf(parent_scale.x - parent_scale.y)
		spread = maxf(spread, absf(parent_scale.y - parent_scale.z))
		if spread > _GENERATE_SCALE_EPSILON * maxf(1.0, parent_scale.length()):
			return ErrorCodes.make(
				ErrorCodes.VALUE_OUT_OF_RANGE, 
				(
					"MeshInstance3D at %s sits under a parent chain scaled %s; a %s collider "
					+ "cannot be scaled non-uniformly — use shape_type 'box' or reparent the mesh"
				) % [mesh_path, parent_scale, shape_type]
			)
	var source_transform: = mesh.global_transform if mesh.top_level else mesh.transform
	var body_transform: = Transform3D(
		Basis(source_transform.basis.get_rotation_quaternion()), 
		source_transform.origin, 
	)



	var mesh_to_body: = body_transform.affine_inverse() * source_transform
	var bounds: AABB = mesh_to_body * mesh.get_aabb()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			"MeshInstance3D at %s has empty bounds %s — nothing to fit" % [mesh_path, bounds]
		)
	return {"plan": {
		"mesh": mesh, 
		"mesh_path": mesh_path, 
		"mesh_name": mesh.name, 
		"auto_shape": auto_shape, 
		"shape_type": shape_type, 
		"source_mesh": mesh.mesh, 
		"source_bounds": mesh.get_aabb(), 
		"parent": parent, 
		"collider_name": collider_name, 
		"top_level": mesh.top_level, 
		"source_transform": source_transform, 
		"body_transform": body_transform, 
		"mesh_to_body": mesh_to_body, 
		"bounds": bounds, 
	}}






static func _plan_stale_reason(plan: Dictionary) -> String:




	var mesh_ref = plan.mesh



	if not is_instance_valid(mesh_ref) or not mesh_ref.is_inside_tree():
		return "was removed"
	var mesh: MeshInstance3D = mesh_ref
	if mesh.name != plan.mesh_name:
		return "was renamed"
	var parent_ref = plan.parent
	if not is_instance_valid(parent_ref) or mesh.get_parent() != parent_ref:
		return "was reparented"
	var parent: Node = parent_ref
	if mesh.top_level != bool(plan.top_level):
		return "changed its top_level setting"
	var source_transform: = mesh.global_transform if mesh.top_level else mesh.transform
	if not source_transform.is_equal_approx(plan.source_transform):
		return "moved"
	if mesh.mesh == null:
		return "lost its mesh resource"
	var auto_stale: = _auto_source_stale_reason(mesh, plan)
	if not auto_stale.is_empty():
		return auto_stale
	if parent.get_node_or_null(NodePath(str(plan.collider_name))) != null:
		return "gained a collider sibling"
	return ""


static func _auto_source_stale_reason(mesh: MeshInstance3D, snapshot: Dictionary) -> String:
	if bool(snapshot.get("auto_shape", false)):
		if mesh.mesh != snapshot.source_mesh:
			return "changed its mesh resource"
		if not mesh.get_aabb().is_equal_approx(snapshot.source_bounds):
			return "changed its mesh bounds"
	return ""





static func _create_generated_entry(
	plan: Dictionary, shape_type: String, body_type: String, reparent_mesh: bool
) -> Dictionary:
	var mesh: MeshInstance3D = plan.mesh
	if shape_type == "convex" or shape_type == "trimesh":
		var error: = _validate_hull_workload(mesh.mesh, str(plan.mesh_path), shape_type)
		if not error.is_empty():
			return error
	var bounds: AABB = plan.bounds
	var shape: Shape3D
	if shape_type == "convex" or shape_type == "trimesh":


		shape = _fit_mesh_shape(mesh, shape_type, plan.mesh_to_body)
		if shape == null:
			return ErrorCodes.make(
				ErrorCodes.VALUE_OUT_OF_RANGE, 
				"MeshInstance3D at %s could not produce a %s shape — the mesh geometry is degenerate"
				%[str(plan.mesh_path), shape_type]
			)
	else:
		shape = ClassDB.instantiate(_SHAPE_3D_CLASSES[shape_type])
		_apply_shape_size(shape, shape_type, {"aabb": bounds}, true)
	var body: CollisionObject3D = ClassDB.instantiate(_GENERATED_BODY_CLASSES[body_type])
	body.name = str(plan.collider_name)
	body.top_level = bool(plan.top_level)
	body.transform = plan.body_transform
	var collision: = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	if shape_type != "convex" and shape_type != "trimesh":
		collision.position = _snap_tiny(bounds.get_center())
	collision.shape = shape
	body.add_child(collision)
	var entry: = {
		"mesh": mesh, 
		"mesh_path": str(plan.mesh_path), 
		"mesh_name": mesh.name, 
		"body_name": body.name, 
		"shape_type": shape_type, 
		"auto_shape": bool(plan.get("auto_shape", false)), 
		"source_mesh": plan.get("source_mesh"), 
		"source_bounds": plan.get("source_bounds"), 
		"mesh_local_transform": plan.mesh_to_body, 
		"parent": plan.parent, 
		"body": body, 
		"collision": collision, 
		"reparent_mesh": reparent_mesh, 
	}
	if reparent_mesh:

		entry["mesh_parent"] = mesh.get_parent()
		entry["mesh_index"] = mesh.get_index()
		entry["mesh_transform"] = mesh.transform
		entry["mesh_owner"] = mesh.owner
	Refresh.prepare_markers(entry)
	return entry





static func _fit_mesh_shape(mesh: MeshInstance3D, shape_type: String, mesh_to_body: Transform3D) -> Shape3D:
	var shape: Shape3D = (
		mesh.mesh.create_convex_shape() if shape_type == "convex" else mesh.mesh.create_trimesh_shape()
	)
	if shape == null:
		return null
	if mesh_to_body.is_equal_approx(Transform3D.IDENTITY):
		return shape
	if shape is ConvexPolygonShape3D:
		var points: = (shape as ConvexPolygonShape3D).points
		for index in points.size():
			points[index] = mesh_to_body * points[index]
		(shape as ConvexPolygonShape3D).points = points
	else:
		var faces: = (shape as ConcavePolygonShape3D).get_faces()
		for index in faces.size():
			faces[index] = mesh_to_body * faces[index]
		if mesh_to_body.basis.determinant() < 0.0:


			for index in range(0, faces.size(), 3):
				var swapped: = faces[index + 1]
				faces[index + 1] = faces[index + 2]
				faces[index + 2] = swapped
		(shape as ConcavePolygonShape3D).set_faces(faces)
	return shape




static func _snap_tiny(value: Vector3) -> Vector3:
	return Vector3(_snap_tiny_component(value.x), _snap_tiny_component(value.y), _snap_tiny_component(value.z))


static func _snap_tiny_component(component: float) -> float:
	return 0.0 if absf(component) < _GENERATE_SNAP_EPSILON else component








static func _applied_stale_reason(created_nodes: Array[Dictionary]) -> String:
	for entry in created_nodes:


		var mesh = entry.mesh
		if not is_instance_valid(mesh) or not mesh.is_inside_tree():
			return "%s was removed" % str(entry.mesh_path)
		if mesh.name != entry.mesh_name:
			return "%s was renamed" % str(entry.mesh_path)
		var auto_stale: = _auto_source_stale_reason(mesh, entry)
		if not auto_stale.is_empty():
			return "%s %s" % [str(entry.mesh_path), auto_stale]
		var parent = entry.parent
		if not is_instance_valid(parent):
			return "%s was reparented" % str(entry.mesh_path)



		var mesh_parent = entry.body if bool(entry.get("reparent_mesh", false)) else parent
		if not is_instance_valid(mesh_parent) or mesh.get_parent() != mesh_parent:
			return "%s was reparented" % str(entry.mesh_path)
		var body = entry.body
		if not is_instance_valid(body) or not body.is_inside_tree():
			return "the generated body for %s was removed" % str(entry.mesh_path)
		if body.name != entry.body_name:
			return "the generated body for %s was renamed" % str(entry.mesh_path)
		if body.get_parent() != parent:
			return "the generated body for %s was reparented" % str(entry.mesh_path)
		var collision = entry.collision
		if not is_instance_valid(collision) or collision.get_parent() != body:
			return "the generated collision shape for %s was removed" % str(entry.mesh_path)
		if collision.name != &"CollisionShape3D":
			return "the generated collision shape for %s was renamed" % str(entry.mesh_path)
	return ""






static func _commit_generated_action(
	created_nodes: Array[Dictionary], 
	scene_root: Node, 
	undo_redo: EditorUndoRedoManager, 
	execute: bool, 
) -> void :
	undo_redo.create_action("MCP: Generate physics shapes for %d mesh(es)" % created_nodes.size(), UndoRedo.MERGE_DISABLE, scene_root)
	for entry in created_nodes:
		if bool(entry.get("refresh", false)):
			undo_redo.add_do_method(ClassDB, "class_set_property", entry.collision, "shape", entry.new_shape)
			undo_redo.add_do_method(ClassDB, "class_set_property", entry.collision, "transform", entry.new_transform)
			undo_redo.add_undo_method(ClassDB, "class_set_property", entry.collision, "shape", entry.old_shape)
			undo_redo.add_undo_method(ClassDB, "class_set_property", entry.collision, "transform", entry.old_transform)
			continue
		Refresh.record_marker_action(entry, undo_redo, execute)
		var parent: Node = entry.parent
		var body: CollisionObject3D = entry.body
		var collision: CollisionShape3D = entry.collision
		undo_redo.add_do_method(parent, "add_child", body, true)
		undo_redo.add_do_method(body, "set_owner", scene_root)
		undo_redo.add_do_method(collision, "set_owner", scene_root)
		if bool(entry.reparent_mesh):
			var mesh: MeshInstance3D = entry.mesh
			var mesh_parent: Node = entry.mesh_parent
			undo_redo.add_do_method(mesh, "reparent", body, true)
			undo_redo.add_do_method(mesh, "set_owner", scene_root)
			undo_redo.add_do_method(mesh, "set_transform", entry.mesh_local_transform)
			undo_redo.add_undo_method(mesh, "reparent", mesh_parent, true)
			undo_redo.add_undo_method(mesh_parent, "move_child", mesh, int(entry.mesh_index))
			undo_redo.add_undo_method(mesh, "set_transform", entry.mesh_transform)
			undo_redo.add_undo_method(mesh, "set_owner", entry.mesh_owner)
		undo_redo.add_do_reference(body)
		undo_redo.add_undo_method(parent, "remove_child", body)
	undo_redo.commit_action(execute)



static func _generated_response(
	created_nodes: Array[Dictionary], scene_root: Node, body_type: String
) -> Dictionary:
	var created: Array[Dictionary] = []
	for entry in created_nodes:
		created.append({
			"mesh_path": McpScenePath.from_node(entry.mesh, scene_root), 
			"body_path": McpScenePath.from_node(entry.body, scene_root), 
			"shape_path": McpScenePath.from_node(entry.collision, scene_root), 
			"shape_type": str(entry.shape_type), 
			"body_type": body_type, 
			"operation": "refresh" if bool(entry.get("refresh", false)) else "create", 
		})
	return {"data": {"created": created, "undoable": true}}






static func _generate_job(
	validated: Dictionary, undo_redo: EditorUndoRedoManager, connection, request_id: String
) -> Dictionary:
	return {
		"refresh_worker": Refresh.new(), 
		"validated": validated, 
		"undo_redo": undo_redo, 
		"connection": connection, 
		"request_id": request_id, 
		"phase": "plan", 
		"index": 0, 
		"plans": [], 
		"created": [], 
		"committed": false, 
		"result": {}, 
		"started_ms": Time.get_ticks_msec(), 
	}





static func _generate_step(job: Dictionary, budget_usec: int) -> bool:
	if str(job.phase) == "done":
		return true
	if bool(job.validated.get("overwrite", false)):
		return job.refresh_worker.step(job, budget_usec)
	var validated: Dictionary = job.validated
	var connection = job.connection
	if connection != null:
		if not _deferred_request_pending(connection, str(job.request_id)):


			_generate_rollback(job)
			job.phase = "done"
			return true
		if Time.get_ticks_msec() - int(job.started_ms) > _GENERATE_DEFERRED_TIMEOUT_MS:
			return _generate_fail(job, ErrorCodes.make(
				ErrorCodes.DEFERRED_TIMEOUT, 
				"physics_shape_generate exceeded its %d ms budget" % _GENERATE_DEFERRED_TIMEOUT_MS, 
			))



	var scene_root_ref = validated.scene_root
	if not is_instance_valid(scene_root_ref) or EditorInterface.get_edited_scene_root() != scene_root_ref:
		return _generate_fail(job, ErrorCodes.make(
			ErrorCodes.EDITED_SCENE_MISMATCH, 
			"The edited scene changed while physics shapes were generated", 
		))
	var scene_root: Node = scene_root_ref


	var frame_start: = Time.get_ticks_usec()
	var work: = 0
	var paths: Array = validated.paths
	while str(job.phase) == "plan":
		if int(job.index) >= paths.size():
			job.phase = "apply"
			job.index = 0
			break
		if work > 0 and budget_usec >= 0 and Time.get_ticks_usec() - frame_start >= budget_usec:
			return false
		var planned: = _plan_generate_mesh(
			str(paths[int(job.index)]), str(validated.scene_file), scene_root, 
			str(validated.shape_type), bool(validated.reparent_mesh)
		)
		if planned.has("error"):
			return _generate_fail(job, planned)
		job.plans.append(planned.plan)
		job.index = int(job.index) + 1
		work += 1
	var plans: Array = job.plans
	while str(job.phase) == "apply" and int(job.index) < plans.size():
		if work > 0 and budget_usec >= 0 and Time.get_ticks_usec() - frame_start >= budget_usec:
			return false
		var plan: Dictionary = plans[int(job.index)]
		var stale: = _plan_stale_reason(plan)
		if not stale.is_empty():
			var code: String = ErrorCodes.NODE_NOT_FOUND if stale == "was removed" else ErrorCodes.EDITED_SCENE_MISMATCH
			return _generate_fail(job, ErrorCodes.make(
				code, 
				"MeshInstance3D at %s %s while physics shapes were generated; nothing was changed"
				%[str(plan.mesh_path), stale], 
			))
		var entry: = _create_generated_entry(
			plan, str(plan.shape_type), str(validated.body_type), bool(validated.reparent_mesh)
		)
		if entry.has("error"):
			return _generate_fail(job, entry)
		var parent: Node = plan.parent
		parent.add_child(entry.body, true)
		entry.body.set_owner(scene_root)
		entry.collision.set_owner(scene_root)
		if bool(validated.reparent_mesh):



			entry.mesh.reparent(entry.body, true)
			entry.mesh.set_owner(scene_root)
			entry.mesh.transform = entry.mesh_local_transform
		job.created.append(entry)
		job.index = int(job.index) + 1
		work += 1




	var created: Array[Dictionary] = []
	created.assign(job.created)
	var applied_stale: = _applied_stale_reason(created)
	if not applied_stale.is_empty():
		var code: String = (
			ErrorCodes.NODE_NOT_FOUND if applied_stale.ends_with("was removed")
			else ErrorCodes.EDITED_SCENE_MISMATCH
		)
		return _generate_fail(job, ErrorCodes.make(
			code, 
			"Scene changed while physics shapes were applied: %s; nothing was changed" % applied_stale, 
		))


	_commit_generated_action(created, scene_root, job.undo_redo, false)
	job.committed = true
	job.result = _generated_response(
		created, scene_root, str(validated.body_type)
	)
	job.phase = "done"
	return true


static func _generate_fail(job: Dictionary, error: Dictionary) -> bool:
	_generate_rollback(job)
	job.result = error
	job.phase = "done"
	return true



static func _generate_rollback(job: Dictionary) -> void :


	if bool(job.get("committed", false)):
		return
	if bool(job.validated.get("overwrite", false)):
		job.refresh_worker.cleanup(job)
		return
	for entry in job.created:


		var body = entry.body
		if not is_instance_valid(body):
			continue
		if bool(entry.get("reparent_mesh", false)):
			_restore_reparented_mesh(entry)
		var parent: Node = body.get_parent()
		if parent != null:
			parent.remove_child(body)
		body.free()
	job.created.clear()





static func _restore_reparented_mesh(entry: Dictionary) -> void :
	var mesh = entry.mesh
	if not is_instance_valid(mesh):
		return
	if mesh.get_parent() != entry.body:
		return


	var mesh_parent = entry.mesh_parent
	if not is_instance_valid(mesh_parent):



		var fallback = entry.body.get_parent()
		if is_instance_valid(fallback):
			mesh.reparent(fallback, true)
		else:
			entry.body.remove_child(mesh)
		return
	mesh.reparent(mesh_parent, true)
	var index: = int(entry.mesh_index)
	if index < mesh_parent.get_child_count():
		mesh_parent.move_child(mesh, index)
	mesh.transform = entry.mesh_transform
	mesh.set_owner(entry.mesh_owner)



static func _deferred_request_pending(connection, request_id: String) -> bool:
	if not is_instance_valid(connection):
		return false
	var dispatcher = connection.dispatcher
	return dispatcher == null or dispatcher.has_pending_deferred_response(request_id)




static func _drive_generate_job(job: Dictionary, connection, frame_signal: Variant = null) -> void :
	var work_id: = ScriptWork.begin("physics_shape_generate")
	job["work_id"] = work_id
	if not is_instance_valid(connection):
		_cancel_generate_job(job)
		return
	if not connection.is_inside_tree():
		_cancel_generate_job(job)
		return
	var tree: SceneTree = connection.get_tree()
	if tree == null:
		_cancel_generate_job(job)
		return
	var resume_signal: Signal = frame_signal if frame_signal is Signal else tree.process_frame





	await resume_signal




	while (
		is_instance_valid(connection)
		and connection.is_inside_tree()
		and not _generate_step(job, _GENERATE_FRAME_BUDGET_USEC)
	):
		await resume_signal
	if str(job.phase) != "done":
		_generate_rollback(job)
		job.phase = "done"
	if is_instance_valid(connection) and connection.is_inside_tree() and not job.result.is_empty():
		connection.send_deferred_response(str(job.request_id), job.result)
	_finish_generate_job(job)




static func _cancel_generate_job(job: Dictionary) -> void :
	if str(job.get("phase", "")) != "done":
		_generate_rollback(job)
		job.phase = "done"
	_finish_generate_job(job)



static func _finish_generate_job(job: Dictionary) -> void :
	var work_id: = int(job.get("work_id", 0))
	if work_id != 0:
		ScriptWork.finish(work_id)
		job["work_id"] = 0


func autofit(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return ErrorCodes.make(ErrorCodes.MISSING_REQUIRED_PARAM, "Missing required param: path")

	var _resolved: = McpNodeValidator.resolve_or_error(node_path, "node_path")
	if _resolved.has("error"):
		return _resolved
	var node: Node = _resolved.node
	var scene_root: Node = _resolved.scene_root

	var is_3d: = node is CollisionShape3D
	var is_2d: = node is CollisionShape2D
	if not (is_3d or is_2d):
		return ErrorCodes.make(
			ErrorCodes.WRONG_TYPE, 
			"Node at %s is %s — must be CollisionShape3D or CollisionShape2D" % [node_path, node.get_class()]
		)

	var source_path: String = params.get("source_path", "")
	var source: Node = null
	if source_path.is_empty():
		var search: = _find_bounds_visual(node, is_3d, scene_root)
		if search.has("error"):
			return search.error
		source = search.source
	else:
		source = McpScenePath.resolve(source_path, scene_root)
		if source == null:
			return ErrorCodes.make(ErrorCodes.NODE_NOT_FOUND, 
				"source_path: %s" % McpScenePath.format_node_error(source_path, scene_root))

	var requested_shape: String = params.get("shape_type", "box" if is_3d else "rectangle")
	var type_map: = _SHAPE_3D_CLASSES if is_3d else _SHAPE_2D_CLASSES
	var shape_type: = _normalize_shape_type(type_map, requested_shape)
	if shape_type.is_empty():
		var valid_pairs: Array[String] = []
		for short_form in type_map:
			valid_pairs.append("%s (%s)" % [short_form, type_map[short_form]])
		return ErrorCodes.make(
			ErrorCodes.VALUE_OUT_OF_RANGE, 
			"Invalid shape_type '%s' for %s. Valid: %s" % [requested_shape, node.get_class(), ", ".join(valid_pairs)]
		)
	var shape_class: String = type_map[shape_type]


	var bounds: = _measure_bounds(source, is_3d)
	if bounds.has("error"):
		return bounds.error



	var existing_shape: Shape3D = null
	var existing_shape_2d: Shape2D = null
	if is_3d:
		existing_shape = node.shape
	else:
		existing_shape_2d = node.shape

	var needs_new_shape: = false
	if is_3d:
		needs_new_shape = existing_shape == null or existing_shape.get_class() != shape_class
	else:
		needs_new_shape = existing_shape_2d == null or existing_shape_2d.get_class() != shape_class

	var target_shape: Resource
	if needs_new_shape:
		var instance: = ClassDB.instantiate(shape_class)
		if instance == null:
			return ErrorCodes.make(ErrorCodes.INTERNAL_ERROR, "Failed to instantiate %s" % shape_class)
		target_shape = instance
	else:
		target_shape = existing_shape if is_3d else existing_shape_2d


	var size_info: = _apply_shape_size(target_shape, shape_type, bounds, is_3d)
	var old_shape = existing_shape if is_3d else existing_shape_2d

	_undo_redo.create_action("MCP: Autofit %s on %s" % [shape_class, node.name])
	if needs_new_shape:
		_undo_redo.add_do_property(node, "shape", target_shape)
		_undo_redo.add_undo_property(node, "shape", old_shape)
		_undo_redo.add_do_reference(target_shape)
	else:

		for key in size_info.applied:
			var new_val = target_shape.get(key)
			var old_val = size_info.previous.get(key)
			_undo_redo.add_do_property(target_shape, key, new_val)
			_undo_redo.add_undo_property(target_shape, key, old_val)
	_undo_redo.commit_action()

	return {
		"data": {
			"path": node_path, 
			"source_path": McpScenePath.from_node(source, scene_root) if source_path.is_empty() else source_path, 
			"shape_type": shape_type, 
			"shape_class": shape_class, 
			"shape_created": needs_new_shape, 
			"size": size_info.size_response, 
			"undoable": true, 
		}
	}





static func _find_bounds_visual(collision_node: Node, is_3d: bool, scene_root: Node) -> Dictionary:
	var parent: = collision_node.get_parent()
	if parent == null:
		return {"error": _no_visual_error(is_3d)}




	var siblings: = _measurable_visuals(parent.get_children(), collision_node, is_3d, false)
	if not siblings.is_empty():
		return {"source": siblings[0]}





	var grandparent: = parent.get_parent()
	if grandparent == null:
		return {"error": _no_visual_error(is_3d)}
	var uncles: = _measurable_visuals(grandparent.get_children(), parent, is_3d, true)
	if uncles.size() == 1:
		return {"source": uncles[0]}
	if uncles.size() > 1:
		var paths: Array[String] = []
		for n in uncles:
			paths.append(McpScenePath.from_node(n, scene_root))
		var msg: = "Multiple visual candidates near %s — pass source_path explicitly. Candidates: %s" % [
			McpScenePath.from_node(collision_node, scene_root), 
			", ".join(paths), 
		]
		var err: = ErrorCodes.make(ErrorCodes.INVALID_PARAMS, msg)
		err["error"]["data"] = {"candidates": paths}
		return {"error": err}
	return {"error": _no_visual_error(is_3d)}






static func _measurable_visuals(nodes: Array, exclude: Node, is_3d: bool, strict: bool) -> Array[Node]:
	var out: Array[Node] = []
	for n in nodes:
		if n == exclude:
			continue
		if is_3d:
			if strict:
				if n is GeometryInstance3D:
					out.append(n)
			elif n is VisualInstance3D:
				out.append(n)
		elif n is Sprite2D or n is TextureRect:
			out.append(n)
	return out


static func _no_visual_error(is_3d: bool) -> Dictionary:
	var hint: = "MeshInstance3D" if is_3d else "Sprite2D"
	return ErrorCodes.make(
		ErrorCodes.INVALID_PARAMS, 
		"No visual found near collision shape — searched siblings and parent-siblings. Pass source_path explicitly (e.g. a %s)" % hint, 
	)







static func _measure_bounds(source: Node, is_3d: bool) -> Dictionary:
	if is_3d:
		if source is VisualInstance3D:
			var aabb: AABB = (source as VisualInstance3D).get_aabb()




			var scale_3d: Vector3 = (source as Node3D).transform.basis.get_scale()
			return {"aabb": Transform3D(Basis.from_scale(scale_3d), Vector3.ZERO) * aabb}
		return {"error": ErrorCodes.make(
			ErrorCodes.WRONG_TYPE, 
			"Source %s has no measurable 3D bounds (must be VisualInstance3D subclass)" % source.get_class()
		)}

	if source is Sprite2D:
		var s: Sprite2D = source
		var srect: Rect2 = s.get_rect()

		srect.position = srect.position * s.scale
		srect.size = srect.size * s.scale
		return {"rect": srect}
	if source is TextureRect:
		var tr: TextureRect = source




		var tr_size: Vector2 = tr.size
		if tr_size.is_zero_approx():
			if tr.texture != null:
				tr_size = tr.texture.get_size() * tr.scale
			else:
				return {"error": ErrorCodes.make(
					ErrorCodes.INVALID_PARAMS, 
					"TextureRect at %s has zero layout size and no texture to fall back to — autofit would produce a zero-sized shape" % source.name
				)}
		return {"rect": Rect2(Vector2.ZERO, tr_size)}
	return {"error": ErrorCodes.make(
		ErrorCodes.WRONG_TYPE, 
		"Source %s has no measurable 2D bounds (must be Sprite2D or TextureRect)" % source.get_class()
	)}




static func _apply_shape_size(shape: Resource, shape_type: String, bounds: Dictionary, is_3d: bool) -> Dictionary:
	var applied: Array[String] = []
	var previous: = {}
	var size_response: = {}

	if is_3d:
		var aabb: AABB = bounds.aabb
		var size_v: Vector3 = aabb.size
		match shape_type:
			"box":
				previous["size"] = shape.get("size")
				(shape as BoxShape3D).size = size_v
				applied.append("size")
				size_response = {"x": size_v.x, "y": size_v.y, "z": size_v.z}
			"sphere":
				var r: = maxf(maxf(size_v.x, size_v.y), size_v.z) * 0.5
				previous["radius"] = shape.get("radius")
				(shape as SphereShape3D).radius = r
				applied.append("radius")
				size_response = {"radius": r}
			"capsule":
				var cap: = shape as CapsuleShape3D
				var r2: = maxf(size_v.x, size_v.z) * 0.5
				var h: = size_v.y
				previous["radius"] = cap.radius
				previous["height"] = cap.height



				cap.radius = r2
				cap.height = h
				applied.append("radius")
				applied.append("height")
				size_response = {"radius": cap.radius, "height": cap.height}
			"cylinder":
				var cyl: = shape as CylinderShape3D
				var r3: = maxf(size_v.x, size_v.z) * 0.5
				var ch: = size_v.y
				previous["radius"] = cyl.radius
				previous["height"] = cyl.height
				cyl.radius = r3
				cyl.height = ch
				applied.append("radius")
				applied.append("height")
				size_response = {"radius": cyl.radius, "height": cyl.height}
	else:
		var rect: Rect2 = bounds.rect
		var sz: Vector2 = rect.size
		match shape_type:
			"rectangle":
				previous["size"] = shape.get("size")
				(shape as RectangleShape2D).size = sz
				applied.append("size")
				size_response = {"x": sz.x, "y": sz.y}
			"circle":
				var cr: = maxf(sz.x, sz.y) * 0.5
				previous["radius"] = shape.get("radius")
				(shape as CircleShape2D).radius = cr
				applied.append("radius")
				size_response = {"radius": cr}
			"capsule":
				var cap2: = shape as CapsuleShape2D
				var cr2: = sz.x * 0.5
				var ch2: = sz.y
				previous["radius"] = cap2.radius
				previous["height"] = cap2.height


				cap2.radius = cr2
				cap2.height = ch2
				applied.append("radius")
				applied.append("height")
				size_response = {"radius": cap2.radius, "height": cap2.height}

	return {"applied": applied, "previous": previous, "size_response": size_response}
