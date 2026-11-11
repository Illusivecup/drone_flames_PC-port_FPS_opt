@tool
class_name McpServerVersionCheck
extends RefCounted






const FIRST_BRIDGE_TOLERANT_VERSION: = "4.0.4"




static func attached_bridges_follow(from_version: String, to_version: String) -> bool:
	var from_tuple: = version_tuple(from_version)
	var to_tuple: = version_tuple(to_version)
	if from_tuple.is_empty() or to_tuple.is_empty():
		return false
	if int(from_tuple[0]) != int(to_tuple[0]):
		return false
	return compare(from_tuple, version_tuple(FIRST_BRIDGE_TOLERANT_VERSION)) >= 0






static func version_tuple(version: String) -> Array:
	var regex: = RegEx.create_from_string("^(\\d+)\\.(\\d+)\\.(\\d+)(?:$|[.+-][0-9A-Za-z][0-9A-Za-z.+-]*$)")
	var found: = regex.search(version.strip_edges())
	if found == null:
		return []
	return [int(found.get_string(1)), int(found.get_string(2)), int(found.get_string(3))]


static func compare(a: Array, b: Array) -> int:
	for index in range(3):
		if int(a[index]) != int(b[index]):
			return -1 if int(a[index]) < int(b[index]) else 1
	return 0





static func is_older_same_major(candidate: String, reference: String) -> bool:
	var candidate_tuple: = version_tuple(candidate)
	var reference_tuple: = version_tuple(reference)
	if candidate_tuple.is_empty() or reference_tuple.is_empty():
		return false
	if int(candidate_tuple[0]) != int(reference_tuple[0]):
		return false
	return compare(candidate_tuple, reference_tuple) < 0


static func evaluate(actual_version: String, expected_version: String) -> Dictionary:
	if actual_version.is_empty():
		return {"compatible": false, "reason": "missing_version"}
	var compatible: = actual_version == expected_version
	return {
		"compatible": compatible, 
		"reason": "" if compatible else "version_mismatch", 
	}
