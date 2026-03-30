class_name PlonkMultiMeshPainter
extends RefCounted
## Accumulates MultiMesh instances for paint strokes.


var _mmi: MultiMeshInstance3D
var _source_mesh: Mesh


## Returns the active MultiMeshInstance3D or null.
func get_instance() -> MultiMeshInstance3D:
	return _mmi


## Ensures a MultiMeshInstance3D exists under parent with the given mesh.
func ensure_mmi(parent: Node3D, mesh: Mesh) -> MultiMeshInstance3D:
	if _mmi != null and is_instance_valid(_mmi) and _source_mesh == mesh:
		return _mmi
	clear()
	_source_mesh = mesh
	_mmi = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	_mmi.multimesh = mm
	parent.add_child(_mmi)
	return _mmi


## Appends a transform in local space relative to the MultiMeshInstance3D.
func append_transform_local(local_xform: Transform3D) -> void:
	if _mmi == null or not is_instance_valid(_mmi):
		return
	var mm := _mmi.multimesh
	var n := mm.instance_count
	mm.instance_count = n + 1
	mm.set_instance_transform(n, local_xform)


func clear() -> void:
	if _mmi != null and is_instance_valid(_mmi):
		_mmi.queue_free()
	_mmi = null
	_source_mesh = null
