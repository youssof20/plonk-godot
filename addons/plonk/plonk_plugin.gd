@tool
extends EditorPlugin
## Plonk editor entry: dock, 3D placement, paint, undo/redo.


const PLACEMENT_NAME_PREFIX := "PlonkInst_"
const ERASE_RADIUS          := 2.0     # metres — erase hits within this distance

var _dock: PlonkDock
var _ghost: PlonkGhostController = PlonkGhostController.new()
var _pm: PlonkPlacementManager = PlonkPlacementManager.new()
var _paint: PlonkPaintTool = PlonkPaintTool.new()
var _mm: PlonkMultiMeshPainter = PlonkMultiMeshPainter.new()

var _placement_active: bool   = false
var _asset_path:       String = ""
var _last_asset_path:  String = ""   # for Space key re-pick
var _asset_pool:       PackedStringArray = []
var _last_camera:      Camera3D
var _last_mouse:       Vector2 = Vector2.ZERO
var _placement_seq:    int    = 0
var _paint_holding:    bool   = false
var _session_count:    int    = 0
var _editor: EditorInterface


func _enter_tree() -> void:
	_editor = get_editor_interface()
	var dock_scene: PackedScene = load("res://addons/plonk/dock/plonk_dock.tscn") as PackedScene
	_dock = dock_scene.instantiate() as PlonkDock
	add_control_to_dock(DOCK_SLOT_LEFT_UL, _dock)
	_dock.asset_selected.connect(_on_asset_selected)
	_dock.zoo_requested.connect(_on_zoo_requested)
	_dock.dock_settings_changed.connect(_sync_from_dock)
	_dock.placement_cancelled.connect(_end_placement)
	_dock.replace_selected_requested.connect(_replace_selected)
	_dock.asset_pool_changed.connect(_on_pool_changed)
	if not _editor.scene_changed.is_connected(_on_scene_changed):
		_editor.scene_changed.connect(_on_scene_changed)
	set_process(true)


func _exit_tree() -> void:
	if _editor:
		if _editor.scene_changed.is_connected(_on_scene_changed):
			_editor.scene_changed.disconnect(_on_scene_changed)
	_end_placement()
	_mm.clear()
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func _process(delta: float) -> void:
	if _dock and _dock.is_erase_mode():
		_update_erase_banner()
		return
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
	# Update mouse position on ANY mouse event (clicks included).
	if event is InputEventMouse:
		_last_mouse = (event as InputEventMouse).position
		update_overlays()

	# ── Erase mode: LMB erases nearest PlonkInst ──────────────────────────────
	if _dock and _dock.is_erase_mode():
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_erase_at_mouse(camera)
				return AFTER_GUI_INPUT_STOP
			if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				_dock.set_erase_mode(false)
				return AFTER_GUI_INPUT_STOP
		return AFTER_GUI_INPUT_PASS

	if not _placement_active:
		return AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# Alt+scroll: nudge height offset
		if mb.pressed and mb.alt_pressed and (
			mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN
		):
			var step := 0.05
			if mb.shift_pressed:
				step = 0.25
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				step = -step
			_dock.bump_height_offset(step)
			_sync_from_dock()
			return AFTER_GUI_INPUT_STOP

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _dock.is_paint_enabled():
				_paint_holding = mb.pressed
				if mb.pressed:
					_stamp_paint_or_place()
			elif mb.pressed:
				# Alt+click: place AND select the new node.
				_commit_placement(mb.alt_pressed)
			return AFTER_GUI_INPUT_STOP

		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_end_placement()
			return AFTER_GUI_INPUT_STOP

	if event is InputEventKey and event.pressed:
		if _handle_hotkey(event as InputEventKey):
			return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	# Erase mode overlay: red circle around cursor on the ground plane
	if _dock and _dock.is_erase_mode() and _last_camera != null:
		var plane_y := _dock.get_height_offset()
		var hit := PlonkModeFree.intersect_plane(_last_camera, _last_mouse, plane_y)
		if bool(hit.get("ok", false)):
			var world_pos: Vector3 = hit.position
			var screen_pos := _last_camera.unproject_position(world_pos)
			# Approximate screen radius from world radius (rough but fine for a brush indicator)
			var edge_world := world_pos + _last_camera.global_transform.basis.x * ERASE_RADIUS
			var edge_screen := _last_camera.unproject_position(edge_world)
			var screen_r := screen_pos.distance_to(edge_screen)
			overlay.draw_arc(screen_pos, max(screen_r, 6.0), 0.0, TAU, 32, Color(1.0, 0.2, 0.2, 0.8), 2.0)
		return

	if not _placement_active or _last_camera == null:
		return
	var mode := _dock.get_placement_mode()
	if mode == PlonkPlacementManager.Mode.GRID:
		var center := _pm.get_snapped_plane_position(_last_camera, _last_mouse)
		var gs := _dock.get_grid_size()
		var plane_y2 := _dock.get_height_offset() + float(_dock.get_grid_layer()) * gs
		for i in range(-20, 21):
			var x0 := Vector3(center.x + float(i) * gs, plane_y2, center.z - 20.0 * gs)
			var x1 := Vector3(center.x + float(i) * gs, plane_y2, center.z + 20.0 * gs)
			overlay.draw_line(_last_camera.unproject_position(x0), _last_camera.unproject_position(x1), Color(1, 1, 1, 0.3), 1.0)
		for j in range(-20, 21):
			var z0 := Vector3(center.x - 20.0 * gs, plane_y2, center.z + float(j) * gs)
			var z1 := Vector3(center.x + 20.0 * gs, plane_y2, center.z + float(j) * gs)
			overlay.draw_line(_last_camera.unproject_position(z0), _last_camera.unproject_position(z1), Color(1, 1, 1, 0.3), 1.0)
	elif mode == PlonkPlacementManager.Mode.VERTEX:
		var gz := _pm.get_last_vertex_gizmo()
		if bool(gz.get("ok", false)):
			var g0: Vector3 = gz.get("ghost_corner", Vector3.ZERO)
			var g1: Vector3 = gz.get("scene_corner", Vector3.ZERO)
			var pg0 := _last_camera.unproject_position(g0)
			var pg1 := _last_camera.unproject_position(g1)
			overlay.draw_line(pg0, pg1, Color(0.35, 0.92, 1.0, 0.9), 2.0)
			overlay.draw_circle(pg0, 4.0, Color(0.3, 0.85, 1.0, 0.95))
			overlay.draw_circle(pg1, 4.0, Color(0.35, 1.0, 0.45, 0.95))


func _on_asset_selected(path: String) -> void:
	_asset_path      = path
	_last_asset_path = path
	_session_count   = 0
	_begin_placement()


func _on_scene_changed() -> void:
	_end_placement()


func _on_pool_changed(paths: PackedStringArray) -> void:
	_asset_pool = paths


func _on_zoo_requested() -> void:
	var root := _editor.get_edited_scene_root() as Node3D
	if root == null:
		return
	var parent := _resolve_parent_node() as Node3D
	if parent == null:
		parent = root
	var paths := _dock.get_scanned_paths()
	PlonkAssetZoo.build_zoo(parent, paths, 2.0, func (_p: String) -> bool: return true)


func _begin_placement() -> void:
	var root := _editor.get_edited_scene_root()
	if root == null:
		push_warning("Plonk: no open scene — open a scene first.")
		return
	_placement_active = true
	_ghost.spawn(root, _asset_path)
	if not _ghost.has_ghost():
		push_warning("Plonk: could not spawn ghost for '%s'. Is it a valid PackedScene/GLB?" % _asset_path)
		_placement_active = false
		return
	_sync_from_dock()
	if _dock:
		_dock.set_active_asset_path(_asset_path)
		_dock.set_placement_status(_asset_path.get_file(), _dock.is_paint_enabled(), false, _session_count)


func _end_placement() -> void:
	_placement_active = false
	_paint_holding    = false
	_paint.end_stroke()
	_ghost.clear()
	if _dock:
		_dock.set_placement_status("", false)


func _update_erase_banner() -> void:
	if _dock:
		_dock.set_placement_status("", false, true)


func _sync_from_dock() -> void:
	_pm.mode = _dock.get_placement_mode()
	_pm.height_offset = _dock.get_height_offset()
	_pm.grid_layer = _dock.get_grid_layer()
	_pm.grid_size = _dock.get_grid_size()
	_pm.align_to_normal = _dock.get_align_to_normal()
	_pm.vertex_threshold = PlonkSettingsManager.get_float(PlonkSettingsManager.KEY_VERTEX_THRESHOLD, 0.2)
	_paint.spacing = _dock.get_paint_spacing()
	_paint.scatter_radius = _dock.get_scatter_radius()
	if _placement_active and _dock:
		_dock.set_placement_status(_asset_path.get_file(), _dock.is_paint_enabled(), false, _session_count)


# ── Slope filter ───────────────────────────────────────────────────────────────

func _passes_slope_filter() -> bool:
	var max_deg := _dock.get_max_slope_degrees()
	if max_deg >= 89.9:
		return true
	var angle := rad_to_deg(acos(clampf(_pm.last_hit_normal.dot(Vector3.UP), -1.0, 1.0)))
	return angle <= max_deg


# ── Pool / random asset selection ─────────────────────────────────────────────

func _get_stamp_asset() -> String:
	if _asset_pool.size() > 1:
		return _asset_pool[randi() % _asset_pool.size()]
	return _asset_path


## After stamping with a pool, re-seed the ghost to a new random asset.
func _reseed_ghost_from_pool() -> void:
	if _asset_pool.size() <= 1:
		return
	var next := _asset_pool[randi() % _asset_pool.size()]
	var root := _editor.get_edited_scene_root()
	if root:
		_ghost.spawn(root, next)


# ── Hotkeys ───────────────────────────────────────────────────────────────────

func _handle_hotkey(ev: InputEventKey) -> bool:
	if ev.keycode == PlonkKeyBindings.get_keycode(PlonkKeyBindings.ACTION_CANCEL):
		_end_placement()
		return true
	# Space: re-pick last used asset when nothing is active
	if ev.keycode == KEY_SPACE and not _placement_active and not _last_asset_path.is_empty():
		_asset_path = _last_asset_path
		_begin_placement()
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
		_pm.flip_y = false
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


# ── Placement ─────────────────────────────────────────────────────────────────

func _commit_placement(select_after: bool = false) -> void:
	var root_node := _editor.get_edited_scene_root()
	if root_node == null:
		return
	# Force a ghost position update right now — _process may not have ticked yet
	# (e.g. first click after picking an asset without moving the mouse first).
	if _last_camera != null:
		var root3 := root_node as Node3D
		if root3:
			_pm.update_ghost(_ghost, _last_camera, _last_mouse, root3)
	if not _ghost.has_ghost():
		return
	if not _passes_slope_filter():
		return
	var parent := _resolve_parent_node()
	if parent == null:
		return
	var gr := _ghost.get_root()
	if gr == null:
		return
	var xf := gr.global_transform
	xf = _apply_randomisation(xf)
	var stamp_path := _get_stamp_asset()
	_session_count += 1
	if _dock.is_multimesh_enabled():
		_place_multimesh(parent as Node3D, xf, stamp_path)
	else:
		_place_node_undoable(parent, xf, stamp_path, select_after)
	_dock.set_placement_status(_asset_path.get_file(), _dock.is_paint_enabled(), false, _session_count)
	_reseed_ghost_from_pool()


func _stamp_paint_or_place() -> void:
	if not _ghost.has_ghost():
		return
	var root := _editor.get_edited_scene_root() as Node3D
	if root == null:
		return
	if not _passes_slope_filter():
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
	var stamp_path := _get_stamp_asset()
	_session_count += 1
	if _dock.is_multimesh_enabled():
		_place_multimesh(parent as Node3D, xf, stamp_path)
	else:
		_place_node_undoable(parent, xf, stamp_path)
	_dock.set_placement_status(_asset_path.get_file(), _dock.is_paint_enabled(), false, _session_count)
	_reseed_ghost_from_pool()


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


func _place_node_undoable(parent: Node, xf: Transform3D, asset_path: String, select_after: bool = false) -> void:
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
	ur.add_do_method(self, "_do_place", asset_path, parent_rel, xf, body, shape, pid, select_after)
	ur.add_undo_method(self, "_undo_place", parent_rel, pid)
	ur.commit_action()


func _do_place(
	asset_path: String,
	parent_rel: NodePath,
	xf: Transform3D,
	body_kind: int,
	shape_kind: int,
	pid: int,
	select_after: bool
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
		inst, parent,
		body_kind as PlonkCollisionBuilder.BodyKind,
		shape_kind as PlonkCollisionBuilder.ShapeKind
	)
	wrapped.name = "%s%d" % [PLACEMENT_NAME_PREFIX, pid]
	if edited:
		_set_owner_recursive(wrapped, edited)
	_apply_material_override(wrapped)
	if select_after:
		call_deferred("_select_node", wrapped)


func _select_node(n: Node) -> void:
	_editor.get_selection().clear()
	_editor.get_selection().add_node(n)


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


# ── MultiMesh ─────────────────────────────────────────────────────────────────

func _place_multimesh(parent: Node3D, xf: Transform3D, asset_path: String) -> void:
	var res: Resource = load(asset_path)
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


# ── Erase ─────────────────────────────────────────────────────────────────────

func _erase_at_mouse(camera: Camera3D) -> void:
	var root := _editor.get_edited_scene_root()
	if root == null:
		return
	var space := camera.get_world_3d().direct_space_state
	var hit := PlonkModeSurface.raycast(space, camera, _last_mouse, 0xFFFFFFFF)
	var cursor_pos: Vector3
	if bool(hit.get("ok", false)):
		cursor_pos = hit.position
	else:
		var ph := PlonkModeFree.intersect_plane(camera, _last_mouse, _dock.get_height_offset())
		if not bool(ph.get("ok", false)):
			return
		cursor_pos = ph.position
	var best_node: Node3D = null
	var best_dist := ERASE_RADIUS
	_find_nearest_plonk(root, cursor_pos, best_dist, best_node)
	if best_node == null:
		return
	_erase_node_undoable(best_node)


func _find_nearest_plonk(node: Node, pos: Vector3, inout_dist: float, inout_node: Node3D) -> void:
	if node is Node3D and node.name.begins_with(PLACEMENT_NAME_PREFIX):
		var d := (node as Node3D).global_position.distance_to(pos)
		if d < inout_dist:
			inout_dist = d
			inout_node = node as Node3D
	for c in node.get_children():
		_find_nearest_plonk(c, pos, inout_dist, inout_node)


func _erase_node_undoable(target: Node3D) -> void:
	var edited := _editor.get_edited_scene_root()
	if edited == null:
		return
	var node_path := edited.get_path_to(target)
	var parent_path := edited.get_path_to(target.get_parent())
	var ur := get_undo_redo()
	ur.create_action("Plonk Erase")
	ur.add_do_method(self, "_do_erase", node_path)
	ur.add_undo_method(self, "_undo_erase_restore", parent_path, target)
	ur.commit_action()


func _do_erase(node_path: NodePath) -> void:
	var edited := _editor.get_edited_scene_root()
	if edited == null:
		return
	var n := edited.get_node_or_null(node_path)
	if n:
		n.queue_free()


func _undo_erase_restore(parent_path: NodePath, node: Node3D) -> void:
	var edited := _editor.get_edited_scene_root()
	if edited == null:
		return
	var parent := edited.get_node_or_null(parent_path)
	if parent == null:
		return
	parent.add_child(node)
	_set_owner_recursive(node, edited)


# ── Replace selected ───────────────────────────────────────────────────────────

func _replace_selected() -> void:
	if _asset_path.is_empty():
		return
	var edited := _editor.get_edited_scene_root()
	if edited == null:
		return
	var sel := _editor.get_selection().get_selected_nodes()
	if sel.is_empty():
		return
	var body := _dock.get_collision_body()
	var shape := _dock.get_collision_shape()
	for node in sel:
		if not (node is Node3D):
			continue
		var n := node as Node3D
		var parent_path := edited.get_path_to(n.get_parent())
		var xf := n.global_transform
		var node_path := edited.get_path_to(n)
		var ur := get_undo_redo()
		_placement_seq += 1
		var pid := _placement_seq
		ur.create_action("Plonk Replace")
		ur.add_do_method(self, "_do_erase", node_path)
		ur.add_do_method(self, "_do_place", _asset_path,
			parent_path, xf, body, shape, pid, false)
		ur.add_undo_method(self, "_undo_place", parent_path, pid)
		ur.add_undo_method(self, "_undo_erase_restore", parent_path, n)
		ur.commit_action()
