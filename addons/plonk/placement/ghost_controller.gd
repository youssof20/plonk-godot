class_name PlonkGhostController
extends RefCounted
## Instantiates and updates the ghost preview; applies semi-transparent materials.


const GHOST_ALPHA := 0.5


var _root: Node3D
var _asset_path: String = ""


## Returns true if a ghost is active.
func has_ghost() -> bool:
	return _root != null and is_instance_valid(_root)


## Instantiates ghost from path under parent; owner stays null for editor.
func spawn(parent: Node, path: String) -> void:
	clear()
	_asset_path = path
	if path.is_empty():
		return
	var res: Resource = load(path)
	if res == null:
		return
	var node: Node
	if res is PackedScene:
		node = (res as PackedScene).instantiate()
	else:
		return
	if not (node is Node3D):
		node.queue_free()
		return
	_root = node as Node3D
	parent.add_child(_root)
	_root.owner = null
	_apply_ghost_materials(_root)


## Updates world transform of ghost.
func set_world_transform(xform: Transform3D) -> void:
	if not has_ghost():
		return
	_root.global_transform = xform


## Computes merged world AABB of all MeshInstance3D under ghost.
func get_world_aabb() -> AABB:
	if not has_ghost():
		return AABB()
	var first := true
	var merged := AABB()
	for mi in _root.find_children("*", "MeshInstance3D", true, false):
		if mi is MeshInstance3D:
			var m := mi as MeshInstance3D
			var mesh := m.mesh
			if mesh == null:
				continue
			var a := m.global_transform * mesh.get_aabb()
			if first:
				merged = a
				first = false
			else:
				merged = merged.merge(a)
	if first:
		return AABB(_root.global_position, Vector3.ZERO)
	return merged


## Removes ghost from tree.
func clear() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_asset_path = ""


func get_asset_path() -> String:
	return _asset_path


## Returns the instantiated ghost root for exclusion queries.
func get_root() -> Node3D:
	return _root


static func _apply_ghost_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh:
			for s in range(mesh.get_surface_count()):
				var mat := mi.get_active_material(s)
				if mat is StandardMaterial3D:
					var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					var c := dup.albedo_color
					c.a = GHOST_ALPHA
					dup.albedo_color = c
					mi.set_surface_override_material(s, dup)
				elif mat != null:
					var dup2 := mat.duplicate()
					mi.set_surface_override_material(s, dup2)
	for c in node.get_children():
		_apply_ghost_materials(c)
