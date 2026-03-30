@tool
class_name PlonkThumbnailBrowser
extends Control
## Scrollable grid of asset cards with throttled EditorResourcePreview.

signal asset_selected(path: String)

const PREVIEW_MAX_IN_FLIGHT := 4
const PREVIEW_RETRY_MAX := 4
const PREVIEW_RETRY_DELAY_SEC := 0.5

var _grid: GridContainer
var _scroll: ScrollContainer
var _cards: Dictionary = {} # id -> PlonkThumbnailCard
var _path_by_id: Dictionary = {}
var _preview_inflight: int = 0
var _preview_backlog: Array[Dictionary] = []
var _card_size_px: float = 80.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid = GridContainer.new()
	_grid.columns = 4
	_scroll.add_child(_grid)
	add_child(_scroll)
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
		var ok := true
		if s.length() > 0:
			ok = fp.get_file().to_lower().find(s) >= 0
		card.visible = ok


## Sets thumbnail size in pixels (already scaled by editor scale).
func set_card_size(px: float) -> void:
	_card_size_px = maxf(60.0, minf(160.0, px))
	for id in _cards.keys():
		var card: PlonkThumbnailCard = _cards[id]
		card.configure(id, _path_by_id[id], _card_size_px)


func _drain_preview_queue() -> void:
	while _preview_inflight < PREVIEW_MAX_IN_FLIGHT and _preview_backlog.size() > 0:
		var item: Dictionary = _preview_backlog.pop_front()
		var path: String = item["path"]
		var id: String = item["id"]
		var retries: int = int(item.get("retries", 0))
		_preview_inflight += 1
		var previewer := EditorInterface.get_resource_previewer()
		previewer.queue_resource_preview(path, self, "_on_preview_ready", { "id": id, "path": path, "retries": retries })


## Callback from EditorResourcePreview.
func _on_preview_ready(path: String, preview: Texture2D, thumbnail: Texture2D, userdata: Variant) -> void:
	_preview_inflight -= 1
	var d: Dictionary = userdata
	var id: String = d.get("id", "")
	var retries: int = int(d.get("retries", 0))
	var card: PlonkThumbnailCard = _cards.get(id, null)
	if card == null:
		return
	var tex: Texture2D = thumbnail
	if tex == null:
		tex = preview
	if tex == null and retries < PREVIEW_RETRY_MAX:
		var timer := get_tree().create_timer(PREVIEW_RETRY_DELAY_SEC)
		timer.timeout.connect(
			func () -> void:
				_preview_backlog.push_front({ "id": id, "path": path, "retries": retries + 1 }),
			CONNECT_ONE_SHOT
		)
		return
	if tex == null:
		card.apply_preview(_fallback_icon())
	else:
		card.apply_preview(tex)


func _fallback_icon() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.55, 1.0))
	return ImageTexture.create_from_image(img)


func _on_card_pressed(card_id: String) -> void:
	if not _path_by_id.has(card_id):
		return
	asset_selected.emit(_path_by_id[card_id] as String)
