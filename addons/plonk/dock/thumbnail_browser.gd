@tool
class_name PlonkThumbnailBrowser
extends ScrollContainer
## Scrollable grid of asset cards with throttled EditorResourcePreview.


signal asset_selected(path: String)

const PREVIEW_MAX_IN_FLIGHT := 4
const PREVIEW_RETRY_MAX := 4
const PREVIEW_RETRY_DELAY_SEC := 0.5

var _grid: GridContainer
var _cards: Dictionary = {}     # id -> PlonkThumbnailCard
var _path_by_id: Dictionary = {}
var _preview_inflight: int = 0
var _preview_backlog: Array[Dictionary] = []
var _card_size_px: float = 80.0


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid = GridContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.columns = _columns_for(int(_card_size_px))
	add_child(_grid)
	set_process(true)


func _process(_delta: float) -> void:
	_drain_preview_queue()


## Rebuilds cards from absolute file paths (res:// or user://).
func set_paths(paths: PackedStringArray) -> void:
	for c in _grid.get_children():
		c.queue_free()
	_cards.clear()
	_path_by_id.clear()
	_preview_backlog.clear()
	_preview_inflight = 0
	var i := 0
	for p in paths:
		var id := "%d_%s" % [i, p]
		_path_by_id[id] = p
		var card := PlonkThumbnailCard.new()
		card.configure(id, p, _card_size_px)
		card.card_pressed.connect(_on_card_pressed)
		_grid.add_child(card)
		_cards[id] = card
		_preview_backlog.append({ "id": id, "path": p, "retries": 0 })
		i += 1


## Filters visible cards by substring on filename.
func apply_search_filter(substr: String) -> void:
	var s := substr.strip_edges().to_lower()
	for id in _cards.keys():
		var card: PlonkThumbnailCard = _cards[id]
		var fp: String = _path_by_id[id] as String
		var ok := s.length() == 0 or fp.get_file().to_lower().find(s) >= 0
		card.visible = ok


## Sets thumbnail card size in pixels and re-columns the grid.
func set_card_size(px: float) -> void:
	_card_size_px = clampf(px, 60.0, 160.0)
	if _grid:
		_grid.columns = _columns_for(int(_card_size_px))
	for id in _cards.keys():
		var card: PlonkThumbnailCard = _cards[id]
		card.configure(id, _path_by_id[id], _card_size_px)


func _columns_for(px: int) -> int:
	return maxi(1, 280 / maxi(px, 1))


func _drain_preview_queue() -> void:
	while _preview_inflight < PREVIEW_MAX_IN_FLIGHT and _preview_backlog.size() > 0:
		var item: Dictionary = _preview_backlog.pop_front()
		var path: String = item["path"]
		var id: String = item["id"]
		var retries: int = int(item.get("retries", 0))
		_preview_inflight += 1
		EditorInterface.get_resource_previewer().queue_resource_preview(
			path, self, "_on_preview_ready", { "id": id, "path": path, "retries": retries }
		)


## Callback from EditorResourcePreview.
func _on_preview_ready(path: String, preview: Texture2D, thumbnail: Texture2D, userdata: Variant) -> void:
	_preview_inflight -= 1
	var d: Dictionary = userdata
	var id: String = d.get("id", "")
	var retries: int = int(d.get("retries", 0))
	var card: PlonkThumbnailCard = _cards.get(id, null)
	if card == null:
		return
	var tex: Texture2D = thumbnail if thumbnail else preview
	if tex == null and retries < PREVIEW_RETRY_MAX:
		get_tree().create_timer(PREVIEW_RETRY_DELAY_SEC).timeout.connect(
			func () -> void:
				_preview_backlog.push_front({ "id": id, "path": path, "retries": retries + 1 }),
			CONNECT_ONE_SHOT
		)
		return
	card.apply_preview(tex if tex else _fallback_icon())


func _fallback_icon() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.55, 1.0))
	return ImageTexture.create_from_image(img)


func _on_card_pressed(card_id: String) -> void:
	if _path_by_id.has(card_id):
		asset_selected.emit(_path_by_id[card_id] as String)
