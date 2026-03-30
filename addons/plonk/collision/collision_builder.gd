class_name PlonkCollisionBuilder
extends RefCounted
## Wraps placed instances in a physics body with a collision shape.


enum BodyKind { NONE, STATIC, RIGID, CHARACTER, AREA }
enum ShapeKind { TRIMESH, CONVEX, BOX, SPHERE, CAPSULE }


## Wraps the instantiated root under parent when body_kind is not NONE; returns the outermost Node3D to parent.
static func wrap(
	instance_root: Node3D,
	parent: Node,
	body_kind: BodyKind,
	shape_kind: ShapeKind
) -> Node3D:
	if body_kind == BodyKind.NONE:
		parent.add_child(instance_root)
		return instance_root
	var body := _make_body(body_kind)
	parent.add_child(body)
	var cs := CollisionShape3D.new()
	var waabb := _merged_world_aabb(instance_root)
	var laabb := _world_aabb_to_local(instance_root, waabb)
	var mesh: Mesh = _first_mesh(instance_root)
	var shape: Shape3D = _build_shape(shape_kind, mesh, laabb)
	cs.shape = shape
	cs.transform = Transform3D(Basis.IDENTITY, laabb.get_center())
	body.add_child(cs)
	body.add_child(instance_root)
	return body


static func _make_body(kind: BodyKind) -> CollisionObject3D:
	match kind:
		BodyKind.STATIC:
			return StaticBody3D.new()
		BodyKind.RIGID:
			return RigidBody3D.new()
		BodyKind.CHARACTER:
			return CharacterBody3D.new()
		BodyKind.AREA:
			return Area3D.new()
	return StaticBody3D.new()


static func _first_mesh(root: Node3D) -> Mesh:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if mi is MeshInstance3D:
			var m := mi as MeshInstance3D
			if m.mesh:
				return m.mesh
	return null


static func _merged_world_aabb(root: Node3D) -> AABB:
	var first := true
	var merged := AABB()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if not (mi is MeshInstance3D):
			continue
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var wa: AABB = m.global_transform * m.mesh.get_aabb()
		if first:
			merged = wa
			first = false
		else:
			merged = merged.merge(wa)
	if first:
		return AABB(root.global_position, Vector3(0.1, 0.1, 0.1))
	return merged


static func _world_aabb_to_local(root: Node3D, waabb: AABB) -> AABB:
	var inv := root.global_transform.affine_inverse()
	var corners := _aabb_corners(waabb)
	var first := true
	var out := AABB()
	for c in corners:
		var lc := inv * c
		if first:
			out = AABB(lc, Vector3.ZERO)
			first = false
		else:
			out = out.expand(lc)
	return out


static func _aabb_corners(a: AABB) -> Array[Vector3]:
	var mn := a.position
	var mx := a.position + a.size
	return [
		Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z),
		Vector3(mn.x, mx.y, mn.z), Vector3(mx.x, mx.y, mn.z),
		Vector3(mn.x, mn.y, mx.z), Vector3(mx.x, mn.y, mx.z),
		Vector3(mn.x, mx.y, mx.z), Vector3(mx.x, mx.y, mx.z)
	]


static func _build_shape(kind: ShapeKind, mesh: Mesh, laabb: AABB) -> Shape3D:
	match kind:
		ShapeKind.TRIMESH:
			if mesh:
				var ts: Shape3D = mesh.create_trimesh_shape()
				if ts:
					return ts
		ShapeKind.CONVEX:
			if mesh:
				var cs: Shape3D = mesh.create_convex_shape()
				if cs:
					return cs
		ShapeKind.BOX:
			var box := BoxShape3D.new()
			box.size = laabb.size
			if box.size.length_squared() < 1e-8:
				box.size = Vector3(0.1, 0.1, 0.1)
			return box
		ShapeKind.SPHERE:
			var sp := SphereShape3D.new()
			sp.radius = maxf(laabb.size.x, maxf(laabb.size.y, laabb.size.z)) * 0.5
			if sp.radius < 0.01:
				sp.radius = 0.05
			return sp
		ShapeKind.CAPSULE:
			var cap := CapsuleShape3D.new()
			cap.radius = maxf(laabb.size.x, laabb.size.z) * 0.5
			if cap.radius < 0.01:
				cap.radius = 0.05
			var h := maxf(laabb.size.y, 0.02)
			cap.height = maxf(h - 2.0 * cap.radius, 0.01)
			return cap
	var fb := BoxShape3D.new()
	fb.size = Vector3(0.1, 0.1, 0.1)
	return fb
