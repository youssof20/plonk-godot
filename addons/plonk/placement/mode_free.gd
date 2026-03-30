class_name PlonkModeFree
extends RefCounted
## Ray-plane placement at y = height_offset.

const PLANE_EPS := 0.0001


## Returns { ok: bool, position: Vector3 } in world space (rotation handled by caller).
static func intersect_plane(camera: Camera3D, mouse_pos: Vector2, plane_y: float) -> Dictionary:
	var origin := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	if absf(dir.y) < PLANE_EPS:
		return { "ok": false }
	var t := (plane_y - origin.y) / dir.y
	if t < 0.0:
		return { "ok": false }
	var pos := origin + dir * t
	return { "ok": true, "position": pos }
