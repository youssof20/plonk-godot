class_name PlonkKeyBindings
extends RefCounted
## Remappable editor actions under plonk/key/.

const PREFIX := "plonk/key/"

const ACTION_ROT_Y_POS := "rotate_y_pos"
const ACTION_ROT_Y_NEG := "rotate_y_neg"
const ACTION_PITCH_POS := "pitch_pos"
const ACTION_PITCH_NEG := "pitch_neg"
const ACTION_ROLL_POS := "roll_pos"
const ACTION_ROLL_NEG := "roll_neg"
const ACTION_SCALE_UP := "scale_up"
const ACTION_SCALE_DOWN := "scale_down"
const ACTION_HEIGHT_UP := "height_up"
const ACTION_HEIGHT_DOWN := "height_down"
const ACTION_GRID_LAYER_UP := "grid_layer_up"
const ACTION_GRID_LAYER_DOWN := "grid_layer_down"
const ACTION_FLIP_X := "flip_x"
const ACTION_FLIP_Z := "flip_z"
const ACTION_RESET_TRANSFORM := "reset_transform"
const ACTION_CANCEL := "cancel_placement"

static func _key(action: String) -> String:
	return PREFIX + action


static func default_for(action: String) -> Key:
	match action:
		ACTION_ROT_Y_POS:
			return KEY_R
		ACTION_ROT_Y_NEG:
			return KEY_R
		ACTION_PITCH_POS:
			return KEY_E
		ACTION_PITCH_NEG:
			return KEY_E
		ACTION_ROLL_POS:
			return KEY_Q
		ACTION_ROLL_NEG:
			return KEY_Q
		ACTION_SCALE_UP:
			return KEY_BRACKETRIGHT
		ACTION_SCALE_DOWN:
			return KEY_BRACKETLEFT
		ACTION_HEIGHT_UP:
			return KEY_PAGEUP
		ACTION_HEIGHT_DOWN:
			return KEY_PAGEDOWN
		ACTION_GRID_LAYER_UP:
			return KEY_HOME
		ACTION_GRID_LAYER_DOWN:
			return KEY_END
		ACTION_FLIP_X:
			return KEY_G
		ACTION_FLIP_Z:
			return KEY_B
		ACTION_RESET_TRANSFORM:
			return KEY_T
		ACTION_CANCEL:
			return KEY_ESCAPE
	return KEY_UNKNOWN


static func get_keycode(action: String) -> int:
	var k := _key(action)
	if not EditorInterface.get_editor_settings().has_setting(k):
		return int(default_for(action))
	return int(EditorInterface.get_editor_settings().get_setting(k))


static func set_keycode(action: String, code: int) -> void:
	var es := EditorInterface.get_editor_settings()
	es.set_setting(_key(action), code)
	es.save()


static func load_all_defaults() -> void:
	var es := EditorInterface.get_editor_settings()
	var actions := [
		ACTION_ROT_Y_POS, ACTION_ROT_Y_NEG, ACTION_PITCH_POS, ACTION_PITCH_NEG,
		ACTION_ROLL_POS, ACTION_ROLL_NEG, ACTION_SCALE_UP, ACTION_SCALE_DOWN,
		ACTION_HEIGHT_UP, ACTION_HEIGHT_DOWN, ACTION_GRID_LAYER_UP, ACTION_GRID_LAYER_DOWN,
		ACTION_FLIP_X, ACTION_FLIP_Z, ACTION_RESET_TRANSFORM, ACTION_CANCEL
	]
	for a in actions:
		if not es.has_setting(_key(a)):
			es.set_setting(_key(a), int(default_for(a)))
	es.save()
