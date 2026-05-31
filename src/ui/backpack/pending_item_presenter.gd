extends RefCounted

const ItemUIScene = preload("res://src/ui/item/item_ui.tscn")

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
		var card := ItemUIScene.instantiate() as Control
		if card == null:
			continue
		area.add_child(card)
		card.setup(item_data, context)
		card.set_meta("pending_item_uid", int(entry.get("uid", -1)))
		card.scale = Vector2(0.58, 0.58)
		card.position = Vector2(12.0 + index * 92.0, 24.0)
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
