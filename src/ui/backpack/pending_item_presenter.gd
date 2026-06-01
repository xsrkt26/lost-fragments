extends RefCounted

const ItemUIScene = preload("res://src/ui/item/item_ui.tscn")

const CARD_SCALE := Vector2(0.58, 0.58)
const CARD_SPACING := 8.0
const CARD_MARGIN := Vector2(10.0, 16.0)

static func render(
	panel: Control,
	area: Control,
	pending_items: Array,
	item_db: Node,
	context,
	connect_card_callback: Callable
) -> Array[Control]:
	var cards: Array[Control] = []
	if panel == null or area == null:
		return cards
	_clear_area(area)
	if item_db == null:
		panel.hide()
		return cards
	panel.visible = not pending_items.is_empty()
	if pending_items.is_empty():
		return cards
	var index := 0
	for entry in pending_items:
		var item_data = item_db.get_item_by_id(str(entry.get("id", ""))) if item_db.has_method("get_item_by_id") else null
		if item_data == null:
			continue
		if entry.has("stack_count"):
			item_data.set_meta("stack_count", max(1, int(entry.get("stack_count", 1))))
		var card := ItemUIScene.instantiate() as Control
		if card == null:
			continue
		area.add_child(card)
		card.setup(item_data, context)
		card.set_meta("pending_item_uid", int(entry.get("uid", -1)))
		card.scale = CARD_SCALE
		var area_size: Vector2 = area.size
		var card_size := card.size * CARD_SCALE
		var safe_area_width := max(area_size.x - CARD_MARGIN.x * 2.0, 1.0)
		var columns := int(floor(safe_area_width / max(card_size.x + CARD_SPACING, 1.0)))
		if columns <= 0:
			columns = 1
		var row := index / columns
		var column := index % columns
		var row_start := row * columns
		var row_items_count := mini(columns, pending_items.size() - row_start)
		if row_items_count <= 0:
			row_items_count = 1
		var row_width := float(row_items_count) * card_size.x + max(0.0, float(row_items_count - 1) * CARD_SPACING)
		var row_x_offset := maxf(0.0, (safe_area_width - row_width) * 0.5)
		var x := CARD_MARGIN.x + row_x_offset + float(column) * (card_size.x + CARD_SPACING)
		var y := CARD_MARGIN.y + float(row) * (card_size.y + CARD_SPACING)
		var safe_area_height := max(area_size.y - CARD_MARGIN.y * 2.0, 1.0)
		if y + card_size.y > safe_area_height and safe_area_height > 0.0:
			y = max(0.0, safe_area_height - card_size.y)
		card.position = Vector2(max(0.0, x), max(0.0, y))
		if connect_card_callback.is_valid():
			connect_card_callback.call(card)
		cards.append(card)
		index += 1
	return cards

static func clear(panel: Control, area: Control) -> void:
	if area != null:
		_clear_area(area)
	if panel != null:
		panel.hide()

static func _clear_area(area: Control) -> void:
	for child in area.get_children():
		child.queue_free()
