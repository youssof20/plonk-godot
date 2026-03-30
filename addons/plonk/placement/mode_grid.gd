class_name PlonkModeGrid
extends RefCounted
## Free placement with XZ snapping.


## Snaps x,z to grid; y from plane intersection.
static func snap_position(pos: Vector3, grid_size: float) -> Vector3:
	var g := maxf(grid_size, 0.0001)
	return Vector3(
		snappedf(pos.x, g),
		pos.y,
		snappedf(pos.z, g)
	)
