class_name PlonkThumbnailCard
extends PanelContainer
## Single asset card with async thumbnail.


signal card_pressed(card_id: String)

const PLACEHOLDER_COLOR := Color(0.35, 0.35, 0.35, 1.0)

var card_id: String = ""
var file_path: String = ""

var _texture_rect: TextureRect
var _retry_count: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(80, 80)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(PLACEHOLDER_COLOR)
	_texture_rect.texture = ImageTexture.create_from_image(img)
	add_child(_texture_rect)
	gui_input.connect(_on_gui_input)


## Configures id and path for this card.
func configure(id: String, path: String, px: float) -> void:
	card_id = id
	file_path = path
	custom_minimum_size = Vector2(px, px)
	_texture_rect.custom_minimum_size = Vector2(px, px)


## Sets the preview texture when async generation completes.
func apply_preview(tex: Texture2D) -> void:
	if tex:
		_texture_rect.texture = tex


## Increments retry counter for slow previews.
func bump_retry() -> int:
	_retry_count += 1
	return _retry_count


func get_retry_count() -> int:
	return _retry_count


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_pressed.emit(card_id)
