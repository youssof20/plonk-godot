class_name PlonkThumbnailCard
extends PanelContainer
## Single asset card: click to pick, Ctrl+click to add/remove from paint pool.


signal card_pressed(card_id: String)
signal card_pool_toggled(card_id: String, pooled: bool)

const PLACEHOLDER_COLOR := Color(0.30, 0.30, 0.30, 1.0)
const HOVER_COLOR        := Color(0.50, 0.70, 1.00, 0.25)
const SELECTED_COLOR     := Color(0.35, 0.60, 1.00, 0.55)
const POOL_DOT_COLOR     := Color(1.00, 0.72, 0.10, 1.00)

var card_id: String   = ""
var file_path: String = ""
var is_selected: bool = false
var is_pooled:   bool = false

var _texture_rect: TextureRect
var _overlay:      ColorRect
var _pool_dot:     ColorRect


func _ready() -> void:
	custom_minimum_size = Vector2(80, 80)
	mouse_filter         = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))

	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(PLACEHOLDER_COLOR)
	_texture_rect.texture = ImageTexture.create_from_image(img)
	add_child(_texture_rect)

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color        = Color.TRANSPARENT
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# Amber dot in the bottom-right corner — visible when card is in the pool.
	_pool_dot = ColorRect.new()
	_pool_dot.color          = POOL_DOT_COLOR
	_pool_dot.anchor_left    = 1.0
	_pool_dot.anchor_top     = 1.0
	_pool_dot.anchor_right   = 1.0
	_pool_dot.anchor_bottom  = 1.0
	_pool_dot.offset_left    = -10.0
	_pool_dot.offset_top     = -10.0
	_pool_dot.offset_right   = -2.0
	_pool_dot.offset_bottom  = -2.0
	_pool_dot.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_pool_dot.visible        = false
	add_child(_pool_dot)

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


## Marks this card as being in the multi-asset pool.
func set_pooled(v: bool) -> void:
	is_pooled = v
	if _pool_dot:
		_pool_dot.visible = v


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
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if mb.ctrl_pressed:
				# Ctrl+click: toggle pool membership without selecting.
				card_pool_toggled.emit(card_id, not is_pooled)
			else:
				card_pressed.emit(card_id)
