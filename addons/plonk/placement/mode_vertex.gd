class_name PlonkModeVertex
extends RefCounted
## Corner-to-corner snap against scene mesh instances.


const MAX_CORNERS_PER_MESH := 8


## Collects world AABB corners for MeshInstance3D nodes within range of camera.
static func collect_scene_corners(
	root: Node,
	camera_pos: Vector3,
	max_dist: float,
	exclude: Node
) -> PackedVector3Array:
	var out := PackedVector3Array()
	if root == null:
		return out
	var dist_sq := max_dist * max_dist
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if exclude != null and (exclude as Node).is_ancestor_of(mi as Node):
			continue
		if not (mi is MeshInstance3D):
			continue
		var m := mi as MeshInstance3D
		var mesh := m.mesh
		if mesh == null:
			continue
		if m.global_position.distance_squared_to(camera_pos) > dist_sq:
			continue
		var waabb := m.global_transform * mesh.get_aabb()
		_append_corners(out, waabb)
	return out


## Finds best snap translation between ghost corners and scene corners.
static func find_snap(
	ghost_corners: PackedVector3Array,
	scene_corners: PackedVector3Array,
	threshold: float
) -> Dictionary:
	if ghost_corners.is_empty() or scene_corners.is_empty():
		return { "ok": false }
	var best_d := INF
	var best_g := Vector3.ZERO
	var best_s := Vector3.ZERO
	for g in ghost_corners:
		for s in scene_corners:
			var d := g.distance_to(s)
			if d < best_d:
				best_d = d
				best_g = g
				best_s = s
	if best_d > threshold:
		return { "ok": false }
	return {
		"ok": true,
		"delta": best_s - best_g,
		"ghost_corner": best_g,
		"scene_corner": best_s
	}


static func corners_from_aabb(a: AABB) -> PackedVector3Array:
	var arr := PackedVector3Array()
	_append_corners(arr, a)
	return arr


static func _append_corners(arr: PackedVector3Array, a: AABB) -> void:
	var mn := a.position
	var mx := a.position + a.size
	var c: Array[Vector3] = [
		Vector3(mn.x, mn.y, mn.z),
		Vector3(mx.x, mn.y, mn.z),
		Vector3(mn.x, mx.y, mn.z),
		Vector3(mx.x, mx.y, mn.z),
		Vector3(mn.x, mn.y, mx.z),
		Vector3(mx.x, mn.y, mx.z),
		Vector3(mn.x, mx.y, mx.z),
		Vector3(mx.x, mx.y, mx.z)
	]
	for v in c:
		arr.append(v)
