class_name PlonkSettingsManager
extends RefCounted
## Persists Plonk state under EditorSettings prefix plonk/.

const PREFIX := "plonk/"
const KEY_FOLDER := PREFIX + "folder_path"
const KEY_CARD_SIZE := PREFIX + "card_size_px"
const KEY_GRID_SIZE := PREFIX + "grid_size"
const KEY_ROTATION_SNAP := PREFIX + "rotation_snap_degrees"
const KEY_PLACEMENT_MODE := PREFIX + "placement_mode"
const KEY_HEIGHT_OFFSET := PREFIX + "height_offset"
const KEY_GRID_LAYER := PREFIX + "grid_layer"
const KEY_ALIGN_NORMAL := PREFIX + "align_to_normal"
const KEY_RANDOM_Y_MIN := PREFIX + "random_y_deg_min"
const KEY_RANDOM_Y_MAX := PREFIX + "random_y_deg_max"
const KEY_RANDOM_TILT_X := PREFIX + "random_tilt_x_max"
const KEY_RANDOM_TILT_Z := PREFIX + "random_tilt_z_max"
const KEY_RANDOM_SCALE_MIN := PREFIX + "random_scale_min"
const KEY_RANDOM_SCALE_MAX := PREFIX + "random_scale_max"
const KEY_PAINT_SPACING := PREFIX + "paint_spacing"
const KEY_SCATTER_RADIUS := PREFIX + "scatter_radius"
const KEY_MATERIAL_PATH := PREFIX + "material_override_path"
const KEY_MATERIAL_MODE := PREFIX + "material_override_mode"
const KEY_PARENT_PATH := PREFIX + "parent_node_path"
const KEY_VERTEX_THRESHOLD := PREFIX + "vertex_snap_threshold"
const KEY_COLLISION_BODY := PREFIX + "collision_body_type"
const KEY_COLLISION_SHAPE := PREFIX + "collision_shape_type"
const KEY_FORMAT_PREFIX := PREFIX + "format_"

static func _es() -> EditorSettings:
	return EditorInterface.get_editor_settings()


static func get_string(key: String, default: String = "") -> String:
	var es := _es()
	if not es.has_setting(key):
		return default
	return es.get_setting(key)


static func set_string(key: String, value: String) -> void:
	var es := _es()
	es.set_setting(key, value)
	es.save()


static func get_float(key: String, default: float = 0.0) -> float:
	var es := _es()
	if not es.has_setting(key):
		return default
	return float(es.get_setting(key))


static func set_float(key: String, value: float) -> void:
	var es := _es()
	es.set_setting(key, value)
	es.save()


static func get_int(key: String, default: int = 0) -> int:
	var es := _es()
	if not es.has_setting(key):
		return default
	return int(es.get_setting(key))


static func set_int(key: String, value: int) -> void:
	var es := _es()
	es.set_setting(key, value)
	es.save()


static func get_bool(key: String, default: bool = false) -> bool:
	var es := _es()
	if not es.has_setting(key):
		return default
	return bool(es.get_setting(key))


static func set_bool(key: String, value: bool) -> void:
	var es := _es()
	es.set_setting(key, value)
	es.save()


static func format_key(ext: String) -> String:
	return KEY_FORMAT_PREFIX + ext.to_lower()


static func load_format_filters(extensions: PackedStringArray) -> Dictionary:
	var out := {}
	for ext in extensions:
		var k := format_key(ext)
		out[ext] = get_bool(k, true)
	return out


static func save_format_filters(filters: Dictionary) -> void:
	for ext in filters.keys():
		set_bool(format_key(str(ext)), bool(filters[ext]))
