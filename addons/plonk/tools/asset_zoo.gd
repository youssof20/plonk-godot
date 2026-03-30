class_name PlonkAssetZoo
extends RefCounted
## Lays out all browser assets in a grid under PlonkZoo, using real AABBs so nothing overlaps.


const ZOO_NAME := "PlonkZoo"
const MAX_COLS := 8
const LABEL_LIFT := 0.25


## Instantiates every asset path under parent, grid layout flush on y=0.
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
	zoo.owner = parent.owner if parent.owner else parent

	var gap := maxf(spacing, 0.1)
	var col := 0
	var x_cursor := 0.0
	var z_cursor := 0.0
	var row_max_z := 0.0  # deepest asset Z size in the current row

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
		node.owner = zoo.owner

		var la := _local_merged_aabb(node)
		# Centre each asset in its bounding box footprint and sit it flush on y=0
		node.position = Vector3(
			x_cursor - la.position.x,
			-la.position.y,
			z_cursor - la.position.z
		)

		var lbl := Label3D.new()
		lbl.text = p.get_file().get_basename()
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 24
		lbl.position = Vector3(la.get_center().x, la.size.y + LABEL_LIFT, la.get_center().z)
		node.add_child(lbl)

		row_max_z = maxf(row_max_z, la.size.z)
		x_cursor += la.size.x + gap
		col += 1
		if col >= MAX_COLS:
			col = 0
			x_cursor = 0.0
			z_cursor += row_max_z + gap
			row_max_z = 0.0


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
		return AABB(Vector3.ZERO, Vector3(1.0, 1.0, 1.0))
	return merged
