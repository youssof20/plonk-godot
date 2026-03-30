@tool
class_name PlonkDock
extends Control
## Main Plonk dock: browser, placement options, tools, and persistence hooks.


signal asset_selected(path: String)
signal folder_changed(path: String)
signal dock_settings_changed
signal zoo_requested
signal placement_cancelled

const EXTENSIONS: PackedStringArray = [
	"glb", "gltf", "fbx", "obj", "dae", "blend", "tscn", "scn", "res", "mesh"
]

const BASE_FONT_PX := 13
const BASE_CARD_PX := 80.0
const BASE_MARGIN := 6.0

var editor_scale: float = 1.0

var _root_v: VBoxContainer
var _parent_edit: LineEdit
var _folder_edit: LineEdit
var _search: LineEdit
var _browser: PlonkThumbnailBrowser
var _mode_option: OptionButton
var _align_normal: CheckBox
var _snap_option: OptionButton
var _grid_size: SpinBox
var _height_spin: SpinBox
var _layer_spin: SpinBox
var _rand_y_min: SpinBox
var _rand_y_max: SpinBox
var _rand_tilt_x: SpinBox
var _rand_tilt_z: SpinBox
var _rand_s_min: SpinBox
var _rand_s_max: SpinBox
var _paint_toggle: CheckBox
var _paint_space: SpinBox
var _scatter: SpinBox
var _mm_toggle: CheckBox
var _body_option: OptionButton
var _shape_option: OptionButton
var _mat_edit: LineEdit
var _mat_mode: OptionButton
var _format_checks: Dictionary = {}
var _folder_dialog: EditorFileDialog

var _scanned_paths: PackedStringArray = []

## Status banner — shown at the very top when placement is active.
var _status_bar: PanelContainer
var _status_label: Label
var _cancel_btn: Button


func _ready() -> void:
	editor_scale = EditorInterface.get_editor_scale()
	PlonkKeyBindings.load_all_defaults()
	_build_ui()
	_load_settings_into_ui()
	_folder_dialog = EditorFileDialog.new()
	_folder_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_folder_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_folder_dialog.dir_selected.connect(_on_dir_picked)
	add_child(_folder_dialog)


func get_editor_scale() -> float:
	return editor_scale


func get_scanned_paths() -> PackedStringArray:
	return _scanned_paths


func get_placement_mode() -> int:
	return _mode_option.get_selected_id()


func get_rotation_snap_degrees() -> float:
	var t := _snap_option.get_item_text(_snap_option.selected)
	return float(t.replace("°", ""))


func get_align_to_normal() -> bool:
	return _align_normal.button_pressed


func get_grid_size() -> float:
	return float(_grid_size.value)


func get_height_offset() -> float:
	return float(_height_spin.value)


func get_grid_layer() -> int:
	return int(_layer_spin.value)


func get_randomisation() -> Dictionary:
	return {
		"y_min": float(_rand_y_min.value),
		"y_max": float(_rand_y_max.value),
		"tilt_x": float(_rand_tilt_x.value),
		"tilt_z": float(_rand_tilt_z.value),
		"s_min": float(_rand_s_min.value),
		"s_max": float(_rand_s_max.value)
	}


func is_paint_enabled() -> bool:
	return _paint_toggle.button_pressed


func get_paint_spacing() -> float:
	return float(_paint_space.value)


func get_scatter_radius() -> float:
	return float(_scatter.value)


func is_multimesh_enabled() -> bool:
	return _mm_toggle.button_pressed and _paint_toggle.button_pressed


func get_collision_body() -> int:
	return _body_option.get_selected_id()


func get_collision_shape() -> int:
	return _shape_option.get_selected_id()


func get_material_path() -> String:
	return _mat_edit.text.strip_edges()


func get_material_mode() -> int:
	return _mat_mode.get_selected_id()


func get_parent_path_text() -> String:
	return _parent_edit.text.strip_edges()


## Adjusts height offset spinbox by delta metres.
func bump_height_offset(delta: float) -> void:
	_height_spin.value = float(_height_spin.value) + delta
	_save_settings()


## Adjusts grid layer spinbox by integer delta.
func bump_grid_layer(delta: int) -> void:
	_layer_spin.value = float(_layer_spin.value) + float(delta)
	_save_settings()


func _build_ui() -> void:
	var m := BASE_MARGIN * editor_scale
	# Root VBox fills the whole dock; status bar at top, then scrollable content.
	var dock_v := VBoxContainer.new()
	dock_v.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dock_v)

	# ── Status banner ──────────────────────────────────────────────────────────
	_status_bar = PanelContainer.new()
	_status_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_bar.visible = false
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.14, 0.56, 0.25, 0.92)
	bar_style.set_corner_radius_all(4)
	bar_style.content_margin_left = 8
	bar_style.content_margin_right = 6
	bar_style.content_margin_top = 5
	bar_style.content_margin_bottom = 5
	_status_bar.add_theme_stylebox_override("panel", bar_style)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 6)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.clip_text = true
	_status_label.add_theme_font_size_override("font_size", int(BASE_FONT_PX * editor_scale))
	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel (ESC)"
	_cancel_btn.add_theme_font_size_override("font_size", int((BASE_FONT_PX - 1) * editor_scale))
	_cancel_btn.pressed.connect(func() -> void: placement_cancelled.emit())
	bar_row.add_child(_status_label)
	bar_row.add_child(_cancel_btn)
	_status_bar.add_child(bar_row)
	dock_v.add_child(_status_bar)

	# ── Scrollable content ─────────────────────────────────────────────────────
	var outer_scroll := ScrollContainer.new()
	outer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock_v.add_child(outer_scroll)

	_root_v = VBoxContainer.new()
	_root_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_v.add_theme_constant_override("separation", int(m))
	outer_scroll.add_child(_root_v)
	_add_section("Library")
	_add_label("Parent node (NodePath from scene root)")
	_parent_edit = LineEdit.new()
	_parent_edit.placeholder_text = "."
	_parent_edit.text_changed.connect(_on_any_setting_changed)
	_parent_edit.tooltip_text = "Empty or \".\" = scene root. Example: Props/Furniture places under that child node."
	_root_v.add_child(_parent_edit)
	var zoo_btn := Button.new()
	zoo_btn.text = "Create Asset Zoo"
	zoo_btn.tooltip_text = "Arranges every scanned asset in a grid under the parent so you can compare scale and style at a glance."
	zoo_btn.pressed.connect(func () -> void: zoo_requested.emit())
	_root_v.add_child(zoo_btn)
	_add_label("Asset folder")
	var folder_row := HBoxContainer.new()
	_folder_edit = LineEdit.new()
	_folder_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_folder_edit.text_changed.connect(_on_any_setting_changed)
	_folder_edit.tooltip_text = "Folder scanned for meshes and scenes. Thumbnails load on demand so large libraries stay responsive."
	var folder_btn := Button.new()
	folder_btn.text = "Browse…"
	folder_btn.tooltip_text = "Choose a project folder containing your assets."
	folder_btn.pressed.connect(_on_pick_folder)
	folder_row.add_child(_folder_edit)
	folder_row.add_child(folder_btn)
	_root_v.add_child(folder_row)
	_add_label("Format filter")
	var fmt_btn_row := HBoxContainer.new()
	var all_on := Button.new()
	all_on.text = "All On"
	all_on.pressed.connect(_all_formats.bind(true))
	var all_off := Button.new()
	all_off.text = "All Off"
	all_off.pressed.connect(_all_formats.bind(false))
	fmt_btn_row.add_child(all_on)
	fmt_btn_row.add_child(all_off)
	_root_v.add_child(fmt_btn_row)
	all_on.tooltip_text = "Show every file type in the list."
	all_off.tooltip_text = "Hide every type; turn individual formats back on below."
	var fmt_grid := GridContainer.new()
	fmt_grid.columns = 3
	for ext in EXTENSIONS:
		var cb := CheckBox.new()
		cb.text = ext.to_upper()
		cb.toggled.connect(_on_format_toggled)
		_format_checks[ext] = cb
		fmt_grid.add_child(cb)
	_root_v.add_child(fmt_grid)
	_add_label("Search assets")
	_search = LineEdit.new()
	_search.placeholder_text = "Filter by filename…"
	_search.text_changed.connect(_on_search_changed)
	_search.tooltip_text = "Filters the list by substring. Does not rescan disk."
	_root_v.add_child(_search)
	_browser = PlonkThumbnailBrowser.new()
	_browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_browser.custom_minimum_size = Vector2(0, 180 * editor_scale)
	_browser.asset_selected.connect(_on_asset_selected)
	_browser.tooltip_text = "Click a thumbnail to pick an asset, then click in the 3D view to place it."
	_root_v.add_child(_browser)
	_add_section("Placement")
	_add_label("Placement mode")
	_mode_option = OptionButton.new()
	_mode_option.add_item("Free", PlonkPlacementManager.Mode.FREE)
	_mode_option.add_item("Grid", PlonkPlacementManager.Mode.GRID)
	_mode_option.add_item("Surface", PlonkPlacementManager.Mode.SURFACE)
	_mode_option.add_item("Vertex", PlonkPlacementManager.Mode.VERTEX)
	_mode_option.item_selected.connect(_on_any_idx_changed)
	_mode_option.tooltip_text = "Free: ground plane. Grid: XZ snap + overlay. Surface: ray onto physics. Vertex: corner snap to nearby mesh corners (see cyan line when it locks)."
	_root_v.add_child(_mode_option)
	_align_normal = CheckBox.new()
	_align_normal.text = "Align to normal (surface mode)"
	_align_normal.button_pressed = true
	_align_normal.toggled.connect(_on_any_bool_changed)
	_align_normal.tooltip_text = "When on, surface mode rotates the asset to sit flush on slopes."
	_root_v.add_child(_align_normal)
	_add_label("Rotation snap")
	_snap_option = OptionButton.new()
	for d in [1, 15, 45, 90]:
		_snap_option.add_item("%d°" % d, d)
	_snap_option.item_selected.connect(_on_any_idx_changed)
	_snap_option.tooltip_text = "Step for rotation hotkeys while placing."
	_root_v.add_child(_snap_option)
	_grid_size = _add_spin("Grid size", 0.1, 100.0, 1.0, "Spacing for grid snap and overlay lines.")
	_height_spin = _add_spin("Height offset", -1000.0, 1000.0, 0.1, "World Y of the placement plane in free/grid modes. Alt+scroll in the 3D view nudges this.")
	_layer_spin = _add_spin("Grid layer", -1000, 1000, 1, "Offsets height by (layer × grid size) for stacked floors.")
	_add_section("Randomisation")
	_rand_y_min = _add_spin("Y rot min°", -360, 360, 1, "Random yaw range applied per stamp.")
	_rand_y_max = _add_spin("Y rot max°", -360, 360, 1, "Random yaw range applied per stamp.")
	_rand_tilt_x = _add_spin("Tilt X max°", 0, 180, 1, "Random tilt around X (degrees, ±).")
	_rand_tilt_z = _add_spin("Tilt Z max°", 0, 180, 1, "Random tilt around Z (degrees, ±).")
	_rand_s_min = _add_spin("Scale min", 0.01, 100.0, 0.01, "Uniform scale randomisation lower bound.")
	_rand_s_max = _add_spin("Scale max", 0.01, 100.0, 0.01, "Uniform scale randomisation upper bound.")
	_add_section("Paint & MultiMesh")
	_paint_toggle = CheckBox.new()
	_paint_toggle.text = "Paint mode"
	_paint_toggle.toggled.connect(_on_any_bool_changed)
	_paint_toggle.tooltip_text = "Hold left mouse in the viewport to stroke along the ghost path instead of single clicks."
	_root_v.add_child(_paint_toggle)
	_paint_space = _add_spin("Paint spacing", 0.01, 100.0, 1.0, "Minimum distance between stamps along the stroke.")
	_scatter = _add_spin("Scatter radius", 0.0, 100.0, 0.1, "Random XY offset around each stamp for organic scatter.")
	_mm_toggle = CheckBox.new()
	_mm_toggle.text = "MultiMesh paint"
	_mm_toggle.toggled.connect(_on_any_bool_changed)
	_mm_toggle.tooltip_text = "When paint is on, instances go into one MultiMeshInstance3D for fewer draw calls. Collision options below do not apply to MultiMesh instances (add collision separately if needed)."
	_root_v.add_child(_mm_toggle)
	_add_section("Collision")
	_body_option = OptionButton.new()
	_body_option.add_item("None", PlonkCollisionBuilder.BodyKind.NONE)
	_body_option.add_item("StaticBody3D", PlonkCollisionBuilder.BodyKind.STATIC)
	_body_option.add_item("RigidBody3D", PlonkCollisionBuilder.BodyKind.RIGID)
	_body_option.add_item("CharacterBody3D", PlonkCollisionBuilder.BodyKind.CHARACTER)
	_body_option.add_item("Area3D", PlonkCollisionBuilder.BodyKind.AREA)
	_body_option.item_selected.connect(_on_any_idx_changed)
	_body_option.tooltip_text = "Wraps each single placement in a physics body. Not used for MultiMesh paint (instances only)."
	_root_v.add_child(_body_option)
	_shape_option = OptionButton.new()
	_shape_option.add_item("Trimesh", PlonkCollisionBuilder.ShapeKind.TRIMESH)
	_shape_option.add_item("Convex", PlonkCollisionBuilder.ShapeKind.CONVEX)
	_shape_option.add_item("Box", PlonkCollisionBuilder.ShapeKind.BOX)
	_shape_option.add_item("Sphere", PlonkCollisionBuilder.ShapeKind.SPHERE)
	_shape_option.add_item("Capsule", PlonkCollisionBuilder.ShapeKind.CAPSULE)
	_shape_option.item_selected.connect(_on_any_idx_changed)
	_shape_option.tooltip_text = "Trimesh/convex from mesh; primitives are fast approximations."
	_root_v.add_child(_shape_option)
	_add_section("Material override")
	_mat_edit = LineEdit.new()
	_mat_edit.placeholder_text = "res://path/to/material.tres"
	_mat_edit.text_changed.connect(_on_any_setting_changed)
	_mat_edit.tooltip_text = "Optional material applied to mesh surfaces after place. Leave empty to use asset materials."
	_root_v.add_child(_mat_edit)
	_mat_mode = OptionButton.new()
	_mat_mode.add_item("Replace", 0)
	_mat_mode.add_item("Next Pass", 1)
	_mat_mode.item_selected.connect(_on_any_idx_changed)
	_mat_mode.tooltip_text = "Replace: override surface material. Next pass: chain as next_pass on a duplicated StandardMaterial3D."
	_root_v.add_child(_mat_mode)


func _add_section(title: String) -> void:
	var sep := HSeparator.new()
	_root_v.add_child(sep)
	var hl := Label.new()
	hl.text = title
	hl.add_theme_font_size_override("font_size", int((BASE_FONT_PX + 2) * editor_scale))
	_root_v.add_child(hl)


func _add_spin(label: String, mn: Variant, mx: Variant, step: float, tip: String = "") -> SpinBox:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(120 * editor_scale, 0)
	var s := SpinBox.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.min_value = float(mn)
	s.max_value = float(mx)
	s.step = step
	s.value_changed.connect(_on_any_float_changed)
	if not tip.is_empty():
		s.tooltip_text = tip
	row.add_child(l)
	row.add_child(s)
	_root_v.add_child(row)
	return s


func _add_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(BASE_FONT_PX * editor_scale))
	_root_v.add_child(lbl)


func _on_any_setting_changed(_t: String) -> void:
	_save_settings()
	dock_settings_changed.emit()


func _on_any_float_changed(_v: float) -> void:
	_save_settings()
	dock_settings_changed.emit()


func _on_any_bool_changed(_p: bool) -> void:
	_save_settings()
	dock_settings_changed.emit()


func _on_any_idx_changed(_i: int) -> void:
	_save_settings()
	dock_settings_changed.emit()


func _on_format_toggled(_p: bool) -> void:
	_save_settings()
	_rescan_folder()
	dock_settings_changed.emit()


func _on_pick_folder() -> void:
	_folder_dialog.popup_centered_ratio(0.5)


func _on_dir_picked(dir: String) -> void:
	_folder_edit.text = dir
	_save_settings()
	_rescan_folder()
	folder_changed.emit(dir)


func _rescan_folder() -> void:
	var dir := _folder_edit.text.strip_edges()
	_scanned_paths = _scan_directory(dir)
	_browser.set_paths(_scanned_paths)
	_on_search_changed(_search.text)


func _scan_directory(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if dir.is_empty():
		return out
	var da := DirAccess.open(dir)
	if da == null:
		return out
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if fname.begins_with("."):
			fname = da.get_next()
			continue
		if da.current_is_dir():
			fname = da.get_next()
			continue
		var ext := fname.get_extension().to_lower()
		if ext not in EXTENSIONS:
			fname = da.get_next()
			continue
		var chk: CheckBox = _format_checks.get(ext, null)
		if chk != null and not chk.button_pressed:
			fname = da.get_next()
			continue
		out.append(dir.path_join(fname))
		fname = da.get_next()
	da.list_dir_end()
	return out


func _on_search_changed(t: String) -> void:
	_browser.apply_search_filter(t)


func _on_asset_selected(path: String) -> void:
	asset_selected.emit(path)


## Updates the browser highlight for the active asset path.
func set_active_asset_path(path: String) -> void:
	if _browser:
		_browser.set_active_path(path)


## Shows or hides the status banner. Pass empty string to clear (hide).
func set_placement_status(asset_name: String, is_paint: bool) -> void:
	if asset_name.is_empty():
		_status_bar.visible = false
		return
	var mode_hint := " — hold LMB to paint" if is_paint else " — click scene to place, RMB/ESC to cancel"
	_status_label.text = "Placing: %s%s" % [asset_name, mode_hint]
	_status_bar.visible = true


func _all_formats(on: bool) -> void:
	for ext in _format_checks.keys():
		var cb: CheckBox = _format_checks[ext]
		cb.button_pressed = on
	_save_settings()
	_rescan_folder()
	dock_settings_changed.emit()


func _load_settings_into_ui() -> void:
	_parent_edit.text = PlonkSettingsManager.get_string(PlonkSettingsManager.KEY_PARENT_PATH, ".")
	_folder_edit.text = PlonkSettingsManager.get_string(PlonkSettingsManager.KEY_FOLDER, "")
	_grid_size.value = PlonkSettingsManager.get_float(PlonkSettingsManager.KEY_GRID_SIZE, 1.0)
	_height_spin.value = PlonkSettingsManager.get_float(PlonkSettingsManager.KEY_HEIGHT_OFFSET, 0.0)
	_layer_spin.value = PlonkSettingsManager.get_float(PlonkSettingsManager.KEY_GRID_LAYER, 0.0)
	_rand_y_min.value = PlonkSettingsManager.get_float(PlonkSettingsManager.KEY_RANDOM_Y_MIN, 0.0)
	_rand_y_max.value = PlonkSettingsManager.get_float(PlonkSettingsManager.KEY_RANDOM_Y_MAX, 0.0)
	_rand_tilt_x.value = PlonkSettingsManager.get_float(PlonkSettingsManager.KEY_RANDOM_TILT_X, 0.0)
	_rand_tilt_z.value = PlonkSettingsManager.get_float(PlonkSettingsManager.KEY_RANDOM_TILT_Z, 0.0)
	_rand_s_min.value = PlonkSettingsManager.get_float(PlonkSettingsManager.KEY_RANDOM_SCALE_MIN, 1.0)
	_rand_s_max.value = PlonkSettingsManager.get_float(PlonkSettingsManager.KEY_RANDOM_SCALE_MAX, 1.0)
	_paint_space.value = PlonkSettingsManager.get_float(PlonkSettingsManager.KEY_PAINT_SPACING, 1.0)
	_scatter.value = PlonkSettingsManager.get_float(PlonkSettingsManager.KEY_SCATTER_RADIUS, 0.0)
	_mat_edit.text = PlonkSettingsManager.get_string(PlonkSettingsManager.KEY_MATERIAL_PATH, "")
	_align_normal.button_pressed = PlonkSettingsManager.get_bool(PlonkSettingsManager.KEY_ALIGN_NORMAL, true)
	var fmt := PlonkSettingsManager.load_format_filters(EXTENSIONS)
	for ext in fmt.keys():
		if _format_checks.has(ext):
			var cb: CheckBox = _format_checks[ext]
			cb.button_pressed = bool(fmt[ext])
	var card := PlonkSettingsManager.get_float(PlonkSettingsManager.KEY_CARD_SIZE, BASE_CARD_PX * editor_scale)
	_browser.set_card_size(card)
	_set_mode_select(PlonkSettingsManager.get_int(PlonkSettingsManager.KEY_PLACEMENT_MODE, PlonkPlacementManager.Mode.FREE))
	var snap := PlonkSettingsManager.get_int(PlonkSettingsManager.KEY_ROTATION_SNAP, 15)
	_select_snap(snap)
	_select_option_id(_body_option, PlonkSettingsManager.get_int(PlonkSettingsManager.KEY_COLLISION_BODY, PlonkCollisionBuilder.BodyKind.NONE))
	_select_option_id(_shape_option, PlonkSettingsManager.get_int(PlonkSettingsManager.KEY_COLLISION_SHAPE, PlonkCollisionBuilder.ShapeKind.BOX))
	_mat_mode.select(PlonkSettingsManager.get_int(PlonkSettingsManager.KEY_MATERIAL_MODE, 0))
	if not _folder_edit.text.is_empty():
		_rescan_folder()


func _set_mode_select(m: int) -> void:
	_select_option_id(_mode_option, m)


func _select_option_id(opt: OptionButton, id: int) -> void:
	for i in range(opt.item_count):
		if opt.get_item_id(i) == id:
			opt.select(i)
			return


func _select_snap(deg: int) -> void:
	for i in range(_snap_option.item_count):
		if _snap_option.get_item_id(i) == deg:
			_snap_option.select(i)
			return
	_snap_option.select(1)


func _save_settings() -> void:
	PlonkSettingsManager.set_string(PlonkSettingsManager.KEY_PARENT_PATH, _parent_edit.text)
	PlonkSettingsManager.set_string(PlonkSettingsManager.KEY_FOLDER, _folder_edit.text)
	PlonkSettingsManager.set_float(PlonkSettingsManager.KEY_GRID_SIZE, float(_grid_size.value))
	PlonkSettingsManager.set_float(PlonkSettingsManager.KEY_HEIGHT_OFFSET, float(_height_spin.value))
	PlonkSettingsManager.set_float(PlonkSettingsManager.KEY_GRID_LAYER, float(_layer_spin.value))
	PlonkSettingsManager.set_float(PlonkSettingsManager.KEY_RANDOM_Y_MIN, float(_rand_y_min.value))
	PlonkSettingsManager.set_float(PlonkSettingsManager.KEY_RANDOM_Y_MAX, float(_rand_y_max.value))
	PlonkSettingsManager.set_float(PlonkSettingsManager.KEY_RANDOM_TILT_X, float(_rand_tilt_x.value))
	PlonkSettingsManager.set_float(PlonkSettingsManager.KEY_RANDOM_TILT_Z, float(_rand_tilt_z.value))
	PlonkSettingsManager.set_float(PlonkSettingsManager.KEY_RANDOM_SCALE_MIN, float(_rand_s_min.value))
	PlonkSettingsManager.set_float(PlonkSettingsManager.KEY_RANDOM_SCALE_MAX, float(_rand_s_max.value))
	PlonkSettingsManager.set_float(PlonkSettingsManager.KEY_PAINT_SPACING, float(_paint_space.value))
	PlonkSettingsManager.set_float(PlonkSettingsManager.KEY_SCATTER_RADIUS, float(_scatter.value))
	PlonkSettingsManager.set_string(PlonkSettingsManager.KEY_MATERIAL_PATH, _mat_edit.text)
	PlonkSettingsManager.set_bool(PlonkSettingsManager.KEY_ALIGN_NORMAL, _align_normal.button_pressed)
	var fmt := {}
	for ext in _format_checks.keys():
		var cb: CheckBox = _format_checks[ext]
		fmt[ext] = cb.button_pressed
	PlonkSettingsManager.save_format_filters(fmt)
	PlonkSettingsManager.set_int(PlonkSettingsManager.KEY_PLACEMENT_MODE, _mode_option.get_selected_id())
	PlonkSettingsManager.set_int(PlonkSettingsManager.KEY_ROTATION_SNAP, _snap_option.get_selected_id())
	PlonkSettingsManager.set_int(PlonkSettingsManager.KEY_COLLISION_BODY, _body_option.get_selected_id())
	PlonkSettingsManager.set_int(PlonkSettingsManager.KEY_COLLISION_SHAPE, _shape_option.get_selected_id())
	PlonkSettingsManager.set_int(PlonkSettingsManager.KEY_MATERIAL_MODE, _mat_mode.get_selected_id())
