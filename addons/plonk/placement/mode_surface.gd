class_name PlonkModeSurface
extends RefCounted
## Physics raycast placement with optional align-to-normal.


const RAY_LENGTH := 100000.0


## Returns { ok, position, normal } from physics ray.
static func raycast(
	space_state: PhysicsDirectSpaceState3D,
	camera: Camera3D,
	mouse_pos: Vector2,
	collision_mask: int
) -> Dictionary:
	var origin := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * RAY_LENGTH)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = collision_mask
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return { "ok": false }
	return {
		"ok": true,
		"position": hit.position,
		"normal": hit.normal,
		"collider": hit.collider
	}


## Builds a basis with local +Y along world normal.
static func basis_y_up(normal: Vector3) -> Basis:
	var y := normal.normalized()
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 1e-8:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## Moves ghost so world AABB support point along -normal touches hit position.
static func align_support_on_surface(world_aabb: AABB, hit_point: Vector3, normal: Vector3) -> Vector3:
	var n := normal.normalized()
	var support_dir := -n
	var corners := _aabb_corners(world_aabb)
	var best: Vector3 = corners[0]
	for c in corners:
		if c.dot(support_dir) < best.dot(support_dir):
			best = c
	return hit_point - best


static func _aabb_corners(a: AABB) -> Array[Vector3]:
	var mn := a.position
	var mx := a.position + a.size
	return [
		Vector3(mn.x, mn.y, mn.z),
		Vector3(mx.x, mn.y, mn.z),
		Vector3(mn.x, mx.y, mn.z),
		Vector3(mx.x, mx.y, mn.z),
		Vector3(mn.x, mn.y, mx.z),
		Vector3(mx.x, mn.y, mx.z),
		Vector3(mn.x, mx.y, mx.z),
		Vector3(mx.x, mx.y, mx.z)
	]
