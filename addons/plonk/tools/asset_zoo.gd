class_name PlonkAssetZoo
extends RefCounted
## Lays out all browser assets in a grid under PlonkZoo.


const ZOO_NAME := "PlonkZoo"


## Instantiates every asset path under parent, grid layout on y=0 plane.
static func build_zoo(
	parent: Node3D,
	paths: PackedStringArray,
	spacing: float,
	format_filter: Callable
) -> void:
	var existing := parent.find_child(ZOO_NAME, true, false)
	if existing:
		existing.queue_free()
	var zoo := Node3D.new()
	zoo.name = ZOO_NAME
	parent.add_child(zoo)
	var ix := 0
	var iz := 0
	var cols := 8
	var i := 0
	for p in paths:
		if not format_filter.call(p):
			continue
		var res: Resource = load(p)
		if res == null:
			continue
		var node: Node3D = null
		if res is PackedScene:
			var inst := (res as PackedScene).instantiate()
			if inst is Node3D:
				node = inst as Node3D
			else:
				inst.queue_free()
		if node == null:
			continue
		zoo.add_child(node)
		node.position = Vector3(ix * spacing, 0.0, iz * spacing)
		var la := _local_merged_aabb(node)
		node.position.y = -la.position.y
		var lbl := Label3D.new()
		lbl.text = p.get_file().get_basename()
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(0, la.size.y + 0.2, 0)
		node.add_child(lbl)
		ix += 1
		i += 1
		if ix >= cols:
			ix = 0
			iz += 1


static func _local_merged_aabb(root: Node3D) -> AABB:
	var first := true
	var merged := AABB()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if not (mi is MeshInstance3D):
			continue
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var la: AABB = m.transform * m.mesh.get_aabb()
		if first:
			merged = la
			first = false
		else:
			merged = merged.merge(la)
	if first:
		return AABB(Vector3.ZERO, Vector3(0.1, 0.1, 0.1))
	return merged
