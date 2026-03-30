class_name PlonkThumbnailCard
extends PanelContainer
## Single asset card with hover, selected, and drag-start detection.


signal card_pressed(card_id: String)
signal card_drag_started(card_id: String)

const PLACEHOLDER_COLOR   := Color(0.30, 0.30, 0.30, 1.0)
const HOVER_COLOR         := Color(0.50, 0.70, 1.00, 0.25)
const SELECTED_COLOR      := Color(0.35, 0.60, 1.00, 0.55)
const DRAG_THRESHOLD_PX   := 5.0

var card_id: String   = ""
var file_path: String = ""
var is_selected: bool = false

var _texture_rect: TextureRect
var _overlay:      ColorRect
var _drag_start:   Vector2 = Vector2.ZERO
var _drag_active:  bool    = false
var _lmb_held:     bool    = false


func _ready() -> void:
	custom_minimum_size = Vector2(80, 80)
	mouse_filter         = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode       = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode      = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.mouse_filter      = Control.MOUSE_FILTER_IGNORE
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(PLACEHOLDER_COLOR)
	_texture_rect.texture = ImageTexture.create_from_image(img)
	add_child(_texture_rect)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color        = Color.TRANSPARENT
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	gui_input.connect(_on_gui_input)


## Configures id and path; sets square size.
func configure(id: String, path: String, px: float) -> void:
	card_id   = id
	file_path = path
	custom_minimum_size = Vector2(px, px)


## Sets the preview texture when async generation completes.
func apply_preview(tex: Texture2D) -> void:
	if tex and _texture_rect:
		_texture_rect.texture = tex


## Marks this card as the active/selected one.
func set_selected(v: bool) -> void:
	is_selected = v
	_refresh_overlay(false)


func _on_hover(entering: bool) -> void:
	_refresh_overlay(entering)


func _refresh_overlay(hovered: bool) -> void:
	if not _overlay:
		return
	if is_selected:
		_overlay.color = SELECTED_COLOR
	elif hovered:
		_overlay.color = HOVER_COLOR
	else:
		_overlay.color = Color.TRANSPARENT


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_lmb_held   = true
				_drag_active = false
				_drag_start  = mb.position
			else:
				_lmb_held = false
				if not _drag_active:
					card_pressed.emit(card_id)
				_drag_active = false
	elif event is InputEventMouseMotion:
		if _lmb_held and not _drag_active:
			if event.position.distance_to(_drag_start) >= DRAG_THRESHOLD_PX:
				_drag_active = true
				card_drag_started.emit(card_id)
