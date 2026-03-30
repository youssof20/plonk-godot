@tool
extends EditorPlugin
## Plonk editor entry: dock, 3D placement, paint, undo/redo.


const PLACEMENT_NAME_PREFIX := "PlonkInst_"

var _dock: PlonkDock
var _ghost: PlonkGhostController = PlonkGhostController.new()
var _pm: PlonkPlacementManager = PlonkPlacementManager.new()
var _paint: PlonkPaintTool = PlonkPaintTool.new()
var _mm: PlonkMultiMeshPainter = PlonkMultiMeshPainter.new()

var _placement_active: bool  = false
var _drag_placing:     bool  = false  # true when placement was started by dragging a card
var _asset_path:       String = ""
var _last_camera:      Camera3D
var _last_mouse:       Vector2 = Vector2.ZERO
var _placement_seq:    int  = 0
var _paint_holding:    bool  = false
var _editor: EditorInterface


func _enter_tree() -> void:
	_editor = get_editor_interface()
	var dock_scene: PackedScene = load("res://addons/plonk/dock/plonk_dock.tscn") as PackedScene
	_dock = dock_scene.instantiate() as PlonkDock
	add_control_to_dock(DOCK_SLOT_LEFT_UL, _dock)
	_dock.asset_selected.connect(_on_asset_selected)
	_dock.asset_drag_started.connect(_on_asset_drag_started)
	_dock.zoo_requested.connect(_on_zoo_requested)
	_dock.dock_settings_changed.connect(_sync_from_dock)
	if not _editor.scene_changed.is_connected(_on_scene_changed):
		_editor.scene_changed.connect(_on_scene_changed)
	set_process(true)
	set_process_input(true)


func _input(event: InputEvent) -> void:
	# Drag-to-place: release may happen over the dock (3D forward never sees it).
	if not _placement_active or not _drag_placing:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_drag_placing = false
			_commit_placement()


func _exit_tree() -> void:
	if _editor:
		if _editor.scene_changed.is_connected(_on_scene_changed):
			_editor.scene_changed.disconnect(_on_scene_changed)
	set_process_input(false)
	_end_placement()
	_mm.clear()
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func _process(delta: float) -> void:
	if not _placement_active or _last_camera == null:
		return
	_sync_from_dock()
	_apply_continuous_keys(delta)
	var root3 := _editor.get_edited_scene_root() as Node3D
	if root3 == null:
		return
	_pm.update_ghost(_ghost, _last_camera, _last_mouse, root3)
	if _paint_holding and _dock.is_paint_enabled():
		_stamp_paint_or_place()


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	_last_camera = camera
	if event is InputEventMouseMotion:
		_last_mouse = event.position
	if not _placement_active:
		return AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _dock.is_paint_enabled():
				_paint_holding = mb.pressed
				if mb.pressed:
					_stamp_paint_or_place()
			else:
				if mb.pressed and not _drag_placing:
					_commit_placement()
			return AFTER_GUI_INPUT_STOP
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_drag_placing = false
			_end_placement()
			return AFTER_GUI_INPUT_STOP
	if event is InputEventKey and event.pressed:
		if _handle_hotkey(event as InputEventKey):
			return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	if not _placement_active or _last_camera == null:
		return
	if _dock.get_placement_mode() != PlonkPlacementManager.Mode.GRID:
		return
	var center := _pm.get_snapped_plane_position(_last_camera, _last_mouse)
	var gs := _dock.get_grid_size()
	var plane_y := _dock.get_height_offset() + float(_dock.get_grid_layer()) * gs
	for i in range(-20, 21):
		var x0 := Vector3(center.x + float(i) * gs, plane_y, center.z - 20.0 * gs)
		var x1 := Vector3(center.x + float(i) * gs, plane_y, center.z + 20.0 * gs)
		var p0 := _last_camera.unproject_position(x0)
		var p1 := _last_camera.unproject_position(x1)
		overlay.draw_line(p0, p1, Color(1, 1, 1, 0.3), 1.0)
	for j in range(-20, 21):
		var z0 := Vector3(center.x - 20.0 * gs, plane_y, center.z + float(j) * gs)
		var z1 := Vector3(center.x + 20.0 * gs, plane_y, center.z + float(j) * gs)
		var q0 := _last_camera.unproject_position(z0)
		var q1 := _last_camera.unproject_position(z1)
		overlay.draw_line(q0, q1, Color(1, 1, 1, 0.3), 1.0)


func _on_asset_selected(path: String) -> void:
	_asset_path    = path
	_drag_placing  = false
	_begin_placement()


func _on_asset_drag_started(_path: String) -> void:
	# Pick already ran on mouse-down; only mark drag so placement commits on LMB release.
	_drag_placing = true


func _on_scene_changed() -> void:
	_end_placement()


func _on_zoo_requested() -> void:
	var root := _editor.get_edited_scene_root() as Node3D
	if root == null:
		return
	var parent := _resolve_parent_node() as Node3D
	if parent == null:
		parent = root
	var paths := _dock.get_scanned_paths()
	var spacing := 2.0
	PlonkAssetZoo.build_zoo(parent, paths, spacing, func (p: String) -> bool:
		return true
	)


func _begin_placement() -> void:
	var root := _editor.get_edited_scene_root()
	if root == null:
		return
	_placement_active = true
	_ghost.spawn(root, _asset_path)
	_sync_from_dock()
	if _dock:
		_dock.set_active_asset_path(_asset_path)


func _end_placement() -> void:
	_placement_active = false
	_drag_placing     = false
	_paint_holding    = false
	_paint.end_stroke()
	_ghost.clear()


func _sync_from_dock() -> void:
	_pm.mode = _dock.get_placement_mode()
	_pm.height_offset = _dock.get_height_offset()
	_pm.grid_layer = _dock.get_grid_layer()
	_pm.grid_size = _dock.get_grid_size()
	_pm.align_to_normal = _dock.get_align_to_normal()
	_pm.vertex_threshold = PlonkSettingsManager.get_float(PlonkSettingsManager.KEY_VERTEX_THRESHOLD, 0.2)
	_paint.spacing = _dock.get_paint_spacing()
	_paint.scatter_radius = _dock.get_scatter_radius()


func _handle_hotkey(ev: InputEventKey) -> bool:
	if ev.keycode == PlonkKeyBindings.get_keycode(PlonkKeyBindings.ACTION_CANCEL):
		_end_placement()
		return true
	var snap := _dock.get_rotation_snap_degrees()
	var shift := ev.shift_pressed
	if _key_matches(ev, PlonkKeyBindings.ACTION_ROT_Y_POS):
		_pm.user_euler_deg.y += snap if not shift else -snap
		return true
	if _key_matches(ev, PlonkKeyBindings.ACTION_PITCH_POS):
		_pm.user_euler_deg.x += snap if not shift else -snap
		return true
	if _key_matches(ev, PlonkKeyBindings.ACTION_ROLL_POS):
		_pm.user_euler_deg.z += snap if not shift else -snap
		return true
	var step := 0.1
	if ev.shift_pressed:
		step = 0.25
	if _key_matches(ev, PlonkKeyBindings.ACTION_SCALE_UP):
		_pm.user_scale *= Vector3.ONE * (1.0 + step)
		return true
	if _key_matches(ev, PlonkKeyBindings.ACTION_SCALE_DOWN):
		_pm.user_scale *= Vector3.ONE * (1.0 - step)
		return true
	if _key_matches(ev, PlonkKeyBindings.ACTION_HEIGHT_UP):
		_dock.bump_height_offset(0.1)
		return true
	if _key_matches(ev, PlonkKeyBindings.ACTION_HEIGHT_DOWN):
		_dock.bump_height_offset(-0.1)
		return true
	if _key_matches(ev, PlonkKeyBindings.ACTION_GRID_LAYER_UP):
		_dock.bump_grid_layer(1)
		return true
	if _key_matches(ev, PlonkKeyBindings.ACTION_GRID_LAYER_DOWN):
		_dock.bump_grid_layer(-1)
		return true
	if _key_matches(ev, PlonkKeyBindings.ACTION_FLIP_X):
		_pm.flip_x = not _pm.flip_x
		return true
	if _key_matches(ev, PlonkKeyBindings.ACTION_FLIP_Z):
		_pm.flip_z = not _pm.flip_z
		return true
	if _key_matches(ev, PlonkKeyBindings.ACTION_RESET_TRANSFORM):
		_pm.user_euler_deg = Vector3.ZERO
		_pm.user_scale = Vector3.ONE
		_pm.flip_x = false
		_pm.flip_z = false
		return true
	return false


func _key_matches(ev: InputEventKey, action: String) -> bool:
	return ev.pressed and ev.keycode == PlonkKeyBindings.get_keycode(action)


func _apply_continuous_keys(delta: float) -> void:
	var snap := _dock.get_rotation_snap_degrees()
	if Input.is_key_pressed(PlonkKeyBindings.get_keycode(PlonkKeyBindings.ACTION_ROT_Y_POS)):
		_pm.user_euler_deg.y += snap * delta * 4.0
	if Input.is_key_pressed(PlonkKeyBindings.get_keycode(PlonkKeyBindings.ACTION_ROT_Y_NEG)):
		_pm.user_euler_deg.y -= snap * delta * 4.0


func _commit_placement() -> void:
	if not _ghost.has_ghost():
		return
	var root := _editor.get_edited_scene_root() as Node3D
	if root == null:
		return
	var parent := _resolve_parent_node()
	if parent == null:
		return
	var gr := _ghost.get_root()
	if gr == null:
		return
	var xf := gr.global_transform
	xf = _apply_randomisation(xf)
	if _dock.is_multimesh_enabled():
		_place_multimesh(parent as Node3D, xf)
	else:
		_place_node_undoable(parent, xf)


func _stamp_paint_or_place() -> void:
	if not _ghost.has_ghost():
		return
	var root := _editor.get_edited_scene_root() as Node3D
	if root == null:
		return
	var parent := _resolve_parent_node()
	if parent == null:
		return
	var gr2 := _ghost.get_root()
	if gr2 == null:
		return
	var pos := gr2.global_position
	pos = _paint.apply_scatter(pos)
	if not _paint.should_stamp(pos):
		return
	_paint.record_stamp(pos)
	var xf := gr2.global_transform
	xf.origin = pos
	xf = _apply_randomisation(xf)
	if _dock.is_multimesh_enabled():
		_place_multimesh(parent as Node3D, xf)
	else:
		_place_node_undoable(parent, xf)


func _apply_randomisation(base: Transform3D) -> Transform3D:
	var r := _dock.get_randomisation()
	var y := randf_range(float(r.y_min), float(r.y_max))
	var tx := deg_to_rad(randf_range(-float(r.tilt_x), float(r.tilt_x)))
	var tz := deg_to_rad(randf_range(-float(r.tilt_z), float(r.tilt_z)))
	var sc := randf_range(float(r.s_min), float(r.s_max))
	var rb := Basis.from_euler(Vector3(tx, deg_to_rad(y), tz))
	var t := base
	t.basis = t.basis * rb
	t.basis = t.basis.scaled(Vector3(sc, sc, sc))
	return t


func _resolve_parent_node() -> Node:
	var root := _editor.get_edited_scene_root()
	if root == null:
		return null
	var pt := _dock.get_parent_path_text()
	if pt.is_empty() or pt == ".":
		return root
	var n := root.get_node_or_null(NodePath(pt))
	return n if n else root


func _place_node_undoable(parent: Node, xf: Transform3D) -> void:
	var path := _asset_path
	var body := _dock.get_collision_body()
	var shape := _dock.get_collision_shape()
	var edited := _editor.get_edited_scene_root()
	if edited == null:
		return
	var parent_rel := edited.get_path_to(parent)
	var ur := get_undo_redo()
	_placement_seq += 1
	var pid := _placement_seq
	ur.create_action("Plonk Place")
	ur.add_do_method(self, "_do_place", path, parent_rel, xf, body, shape, pid)
	ur.add_undo_method(self, "_undo_place", parent_rel, pid)
	ur.commit_action()


func _do_place(
	asset_path: String,
	parent_rel: NodePath,
	xf: Transform3D,
	body_kind: int,
	shape_kind: int,
	pid: int
) -> void:
	var edited := _editor.get_edited_scene_root()
	if edited == null:
		return
	var parent: Node = edited if parent_rel.is_empty() else edited.get_node_or_null(parent_rel)
	if parent == null:
		return
	var res: Resource = load(asset_path)
	if res == null:
		return
	var inst: Node3D = null
	if res is PackedScene:
		var node := (res as PackedScene).instantiate()
		if node is Node3D:
			inst = node as Node3D
	if inst == null:
		return
	inst.name = "PlonkVisual"
	inst.global_transform = xf
	var wrapped := PlonkCollisionBuilder.wrap(
		inst,
		parent,
		body_kind as PlonkCollisionBuilder.BodyKind,
		shape_kind as PlonkCollisionBuilder.ShapeKind
	)
	wrapped.name = "%s%d" % [PLACEMENT_NAME_PREFIX, pid]
	if edited:
		_set_owner_recursive(wrapped, edited)
	_apply_material_override(wrapped)


func _undo_place(parent_rel: NodePath, pid: int) -> void:
	var edited := _editor.get_edited_scene_root()
	if edited == null:
		return
	var parent: Node = edited if parent_rel.is_empty() else edited.get_node_or_null(parent_rel)
	if parent == null:
		return
	var n := parent.get_node_or_null("%s%d" % [PLACEMENT_NAME_PREFIX, pid])
	if n:
		n.queue_free()


func _set_owner_recursive(n: Node, owner: Node) -> void:
	n.owner = owner
	for c in n.get_children():
		_set_owner_recursive(c, owner)


func _apply_material_override(root: Node) -> void:
	var mp := _dock.get_material_path()
	if mp.is_empty():
		return
	var mat: Material = load(mp) as Material
	if mat == null:
		return
	var mode := _dock.get_material_mode()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if not (mi is MeshInstance3D):
			continue
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var mc := m.mesh.get_surface_count()
		for s in range(mc):
			if mode == 0:
				m.set_surface_override_material(s, mat)
			else:
				var active := m.get_active_material(s)
				if active is StandardMaterial3D:
					var dup := (active as StandardMaterial3D).duplicate() as StandardMaterial3D
					dup.next_pass = mat
					m.set_surface_override_material(s, dup)


func _place_multimesh(parent: Node3D, xf: Transform3D) -> void:
	var res: Resource = load(_asset_path)
	if res == null or not (res is PackedScene):
		return
	var tmp := (res as PackedScene).instantiate() as Node3D
	if tmp == null:
		return
	var mesh: Mesh = null
	for mi in tmp.find_children("*", "MeshInstance3D", true, false):
		if mi is MeshInstance3D and (mi as MeshInstance3D).mesh:
			mesh = (mi as MeshInstance3D).mesh
			break
	tmp.queue_free()
	if mesh == null:
		return
	var mmi := _mm.ensure_mmi(parent, mesh)
	var local_xf: Transform3D = mmi.global_transform.affine_inverse() * xf
	var edited_root := _editor.get_edited_scene_root()
	if edited_root == null:
		return
	var mmi_rel := edited_root.get_path_to(mmi)
	var ur := get_undo_redo()
	ur.create_action("Plonk MultiMesh")
	ur.add_do_method(self, "_do_mm_append", mmi_rel, local_xf)
	ur.add_undo_method(self, "_undo_mm_pop", mmi_rel)
	ur.commit_action()


func _do_mm_append(mmi_path: NodePath, local_xform: Transform3D) -> void:
	var root := _editor.get_edited_scene_root()
	if root == null:
		return
	var mmi := root.get_node_or_null(mmi_path) as MultiMeshInstance3D
	if mmi == null:
		return
	var mm := mmi.multimesh
	var n := mm.instance_count
	mm.instance_count = n + 1
	mm.set_instance_transform(n, local_xform)


func _undo_mm_pop(mmi_path: NodePath) -> void:
	var root := _editor.get_edited_scene_root()
	if root == null:
		return
	var mmi := root.get_node_or_null(mmi_path) as MultiMeshInstance3D
	if mmi == null:
		return
	var mm := mmi.multimesh
	if mm.instance_count <= 0:
		return
	mm.instance_count = mm.instance_count - 1
