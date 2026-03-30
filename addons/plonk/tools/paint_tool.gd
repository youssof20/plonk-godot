class_name PlonkPaintTool
extends RefCounted
## Spacing gate for continuous paint strokes.


const NO_STAMP := 1e10


var spacing: float = 1.0
var scatter_radius: float = 0.0
var _last_stamp: Vector3 = Vector3(NO_STAMP, NO_STAMP, NO_STAMP)


## Returns true if a new stamp is allowed at the given world position.
func should_stamp(world_pos: Vector3) -> bool:
	if _last_stamp.x >= NO_STAMP - 1.0:
		return true
	return world_pos.distance_to(_last_stamp) >= maxf(spacing, 0.001)


## Records the last stamp position.
func record_stamp(world_pos: Vector3) -> void:
	_last_stamp = world_pos


## Clears stroke state (call on mouse release).
func end_stroke() -> void:
	_last_stamp = Vector3(NO_STAMP, NO_STAMP, NO_STAMP)


## Random XZ offset when scatter_radius > 0.
func apply_scatter(pos: Vector3) -> Vector3:
	if scatter_radius <= 0.0:
		return pos
	var ox := randf_range(-scatter_radius, scatter_radius)
	var oz := randf_range(-scatter_radius, scatter_radius)
	return pos + Vector3(ox, 0.0, oz)
