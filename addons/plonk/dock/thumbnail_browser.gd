@tool
class_name PlonkThumbnailBrowser
extends ScrollContainer
## Scrollable, auto-column grid of asset cards with throttled EditorResourcePreview.
## Ctrl+click cards to build a multi-asset paint pool (amber dot indicator).


signal asset_selected(path: String)
signal asset_pool_changed(paths: PackedStringArray)

const PREVIEW_MAX_IN_FLIGHT := 4
const PREVIEW_RETRY_MAX     := 4
const PREVIEW_RETRY_DELAY   := 0.5
const CARD_GAP              := 4

var _grid:             GridContainer
var _cards:            Dictionary = {}   # id -> PlonkThumbnailCard
var _path_by_id:       Dictionary = {}
var _active_id:        String     = ""
var _pool_ids:         Dictionary = {}   # id -> true  (pool membership)
var _preview_inflight: int        = 0
var _preview_backlog:  Array[Dictionary] = []
var _card_size_px:     float      = 96.0


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_grid = GridContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", CARD_GAP)
	_grid.add_theme_constant_override("v_separation", CARD_GAP)
	_grid.columns = 3
	add_child(_grid)
	resized.connect(_update_columns)
	set_process(true)


func _process(_delta: float) -> void:
	_drain_preview_queue()


## Rebuilds cards from a list of absolute file paths.
func set_paths(paths: PackedStringArray) -> void:
	for c in _grid.get_children():
		c.queue_free()
	_cards.clear()
	_path_by_id.clear()
	_pool_ids.clear()
	_preview_backlog.clear()
	_preview_inflight = 0
	_active_id = ""
	var i := 0
	for p in paths:
		var id := "%d_%s" % [i, p]
		_path_by_id[id] = p
		var card := PlonkThumbnailCard.new()
		card.configure(id, p, _card_size_px)
		card.card_pressed.connect(_on_card_pressed)
		card.card_pool_toggled.connect(_on_card_pool_toggled)
		_grid.add_child(card)
		_cards[id] = card
		_preview_backlog.append({ "id": id, "path": p, "retries": 0 })
		i += 1
	_update_columns()


## Returns all paths currently in the paint pool.
func get_pool_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for id in _pool_ids.keys():
		if _path_by_id.has(id):
			out.append(_path_by_id[id] as String)
	return out


## Filters visible cards by filename substring.
func apply_search_filter(substr: String) -> void:
	var s := substr.strip_edges().to_lower()
	for id in _cards.keys():
		var card: PlonkThumbnailCard = _cards[id]
		var fp: String = _path_by_id[id] as String
		card.visible = s.length() == 0 or fp.get_file().to_lower().find(s) >= 0
	_update_columns()


## Changes thumbnail card size and reflows columns.
func set_card_size(px: float) -> void:
	_card_size_px = clampf(px, 60.0, 160.0)
	for id in _cards.keys():
		(_cards[id] as PlonkThumbnailCard).configure(id, _path_by_id[id], _card_size_px)
	_update_columns()
	PlonkSettingsManager.set_float(PlonkSettingsManager.KEY_CARD_SIZE, _card_size_px)


## Marks a card as selected, clearing the previous selection.
func set_active_path(path: String) -> void:
	for id in _cards.keys():
		var card := _cards[id] as PlonkThumbnailCard
		var is_active := (_path_by_id[id] as String) == path
		card.set_selected(is_active)
		if is_active:
			_active_id = id


func _update_columns() -> void:
	if _grid == null:
		return
	var avail := size.x
	if avail < 1.0:
		avail = 200.0
	var cols := maxi(1, int((avail + CARD_GAP) / (_card_size_px + CARD_GAP)))
	if _grid.columns != cols:
		_grid.columns = cols


func _drain_preview_queue() -> void:
	while _preview_inflight < PREVIEW_MAX_IN_FLIGHT and _preview_backlog.size() > 0:
		var item: Dictionary = _preview_backlog.pop_front()
		_preview_inflight += 1
		EditorInterface.get_resource_previewer().queue_resource_preview(
			item["path"], self, "_on_preview_ready",
			{ "id": item["id"], "path": item["path"], "retries": item.get("retries", 0) }
		)


## Callback from EditorResourcePreview (bound to self — safe across rebuilds via id).
func _on_preview_ready(path: String, preview: Texture2D, thumbnail: Texture2D, userdata: Variant) -> void:
	_preview_inflight -= 1
	var d: Dictionary  = userdata
	var id: String     = d.get("id", "")
	var retries: int   = int(d.get("retries", 0))
	var card: PlonkThumbnailCard = _cards.get(id, null)
	if card == null:
		return
	var tex: Texture2D = thumbnail if thumbnail else preview
	if tex == null and retries < PREVIEW_RETRY_MAX:
		get_tree().create_timer(PREVIEW_RETRY_DELAY).timeout.connect(
			func() -> void: _preview_backlog.push_front({ "id": id, "path": path, "retries": retries + 1 }),
			CONNECT_ONE_SHOT
		)
		return
	card.apply_preview(tex if tex else _fallback_icon())


func _fallback_icon() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.45, 0.45, 0.50, 1.0))
	return ImageTexture.create_from_image(img)


func _on_card_pressed(card_id: String) -> void:
	if not _path_by_id.has(card_id):
		return
	var path: String = _path_by_id[card_id]
	set_active_path(path)
	asset_selected.emit(path)


func _on_card_pool_toggled(card_id: String, pooled: bool) -> void:
	if not _path_by_id.has(card_id):
		return
	var card := _cards.get(card_id, null) as PlonkThumbnailCard
	if card == null:
		return
	if pooled:
		_pool_ids[card_id] = true
	else:
		_pool_ids.erase(card_id)
	card.set_pooled(pooled)
	asset_pool_changed.emit(get_pool_paths())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.ctrl_pressed:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_card_size(_card_size_px + 8.0)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_card_size(_card_size_px - 8.0)
			accept_event()
