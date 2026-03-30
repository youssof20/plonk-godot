class_name PlonkPlacementManager
extends RefCounted
## Coordinates placement modes and builds the ghost transform each tick.


enum Mode { FREE, GRID, SURFACE, VERTEX }

const DEFAULT_VERTEX_THRESHOLD := 0.2
const VERTEX_CAMERA_RANGE := 40.0
const COLLISION_MASK_ALL := 0xFFFFFFFF


var mode: int = Mode.FREE
var height_offset: float = 0.0
var grid_layer: int = 0
var grid_size: float = 1.0
var align_to_normal: bool = true
var vertex_threshold: float = DEFAULT_VERTEX_THRESHOLD

## Manual euler degrees (applied on top of surface basis when align is on).
var user_euler_deg: Vector3 = Vector3.ZERO
var user_scale: Vector3 = Vector3.ONE
var flip_x: bool = false
var flip_z: bool = false

## Last vertex snap pair for viewport overlay (set during update_ghost in vertex mode).
var _last_vertex_gizmo: Dictionary = { "ok": false }


func get_last_vertex_gizmo() -> Dictionary:
	return _last_vertex_gizmo.duplicate()


## Updates ghost transform from camera and mouse position.
func update_ghost(
	ghost: PlonkGhostController,
	camera: Camera3D,
	mouse_pos: Vector2,
	edited_scene_root: Node3D
) -> void:
	if not ghost.has_ghost():
		return
	_last_vertex_gizmo = { "ok": false }
	var plane_y := height_offset + float(grid_layer) * grid_size
	var t: Transform3D
	match mode:
		Mode.FREE:
			t = _transform_free(camera, mouse_pos, plane_y)
		Mode.GRID:
			t = _transform_grid(camera, mouse_pos, plane_y)
		Mode.SURFACE:
			t = _transform_surface(ghost, camera, mouse_pos, edited_scene_root, plane_y)
		Mode.VERTEX:
			t = _transform_vertex(ghost, camera, mouse_pos, edited_scene_root, plane_y)
	t = _with_flip_scale(t)
	ghost.set_world_transform(t)


func _basis_from_user() -> Basis:
	return Basis.from_euler(Vector3(
		deg_to_rad(user_euler_deg.x),
		deg_to_rad(user_euler_deg.y),
		deg_to_rad(user_euler_deg.z)
	))


func _transform_free(camera: Camera3D, mouse_pos: Vector2, plane_y: float) -> Transform3D:
	var hit := PlonkModeFree.intersect_plane(camera, mouse_pos, plane_y)
	if not bool(hit.get("ok", false)):
		return Transform3D(_basis_from_user(), camera.global_position)
	var pos: Vector3 = hit.position
	return Transform3D(_basis_from_user(), pos)


func _transform_grid(camera: Camera3D, mouse_pos: Vector2, plane_y: float) -> Transform3D:
	var hit := PlonkModeFree.intersect_plane(camera, mouse_pos, plane_y)
	if not bool(hit.get("ok", false)):
		return Transform3D(_basis_from_user(), camera.global_position)
	var pos: Vector3 = PlonkModeGrid.snap_position(hit.position, grid_size)
	return Transform3D(_basis_from_user(), pos)


func _transform_surface(
	ghost: PlonkGhostController,
	camera: Camera3D,
	mouse_pos: Vector2,
	_edited_root: Node3D,
	fallback_plane_y: float
) -> Transform3D:
	var space := camera.get_world_3d().direct_space_state
	var rc := PlonkModeSurface.raycast(space, camera, mouse_pos, COLLISION_MASK_ALL)
	if not bool(rc.get("ok", false)):
		return _transform_free(camera, mouse_pos, fallback_plane_y)
	var hit_pos: Vector3 = rc.position
	var n: Vector3 = rc.normal
	var basis: Basis
	if align_to_normal:
		var surf := PlonkModeSurface.basis_y_up(n)
		basis = surf * _basis_from_user()
	else:
		basis = _basis_from_user()
	ghost.set_world_transform(Transform3D(basis, hit_pos))
	var wa := ghost.get_world_aabb()
	var pos := PlonkModeSurface.align_support_on_surface(wa, hit_pos, n)
	return Transform3D(basis, pos)


func _transform_vertex(
	ghost: PlonkGhostController,
	camera: Camera3D,
	mouse_pos: Vector2,
	edited_root: Node3D,
	fallback_plane_y: float
) -> Transform3D:
	var base := _transform_surface(ghost, camera, mouse_pos, edited_root, fallback_plane_y)
	ghost.set_world_transform(base)
	var wa := ghost.get_world_aabb()
	var gc := PlonkModeVertex.corners_from_aabb(wa)
	var sc := PlonkModeVertex.collect_scene_corners(
		edited_root,
		camera.global_position,
		VERTEX_CAMERA_RANGE,
		ghost.get_root()
	)
	var snap := PlonkModeVertex.find_snap(gc, sc, vertex_threshold)
	if not bool(snap.get("ok", false)):
		return base
	_last_vertex_gizmo = snap.duplicate()
	var delta: Vector3 = snap.delta
	var t := base
	t.origin += delta
	return t


func _with_flip_scale(t: Transform3D) -> Transform3D:
	var s := user_scale
	if flip_x:
		s.x *= -1.0
	if flip_z:
		s.z *= -1.0
	var b := t.basis.scaled(s)
	return Transform3D(b, t.origin)


## Exposes snap gizmo points when in vertex mode (for drawing).
func get_vertex_gizmo(
	ghost: PlonkGhostController,
	camera: Camera3D,
	mouse_pos: Vector2,
	edited_root: Node3D,
	fallback_plane_y: float
) -> Dictionary:
	if mode != Mode.VERTEX or not ghost.has_ghost():
		return { "ok": false }
	var base := _transform_surface(ghost, camera, mouse_pos, edited_root, fallback_plane_y)
	ghost.set_world_transform(base)
	var wa := ghost.get_world_aabb()
	var gc := PlonkModeVertex.corners_from_aabb(wa)
	var sc := PlonkModeVertex.collect_scene_corners(
		edited_root,
		camera.global_position,
		VERTEX_CAMERA_RANGE,
		ghost.get_root()
	)
	return PlonkModeVertex.find_snap(gc, sc, vertex_threshold)


## Snapped grid position for overlay (grid mode).
func get_snapped_plane_position(camera: Camera3D, mouse_pos: Vector2) -> Vector3:
	var plane_y := height_offset + float(grid_layer) * grid_size
	var hit := PlonkModeFree.intersect_plane(camera, mouse_pos, plane_y)
	if not bool(hit.get("ok", false)):
		return Vector3.ZERO
	return PlonkModeGrid.snap_position(hit.position, grid_size)
