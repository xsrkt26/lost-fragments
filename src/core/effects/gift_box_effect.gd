class_name GiftBoxEffect
extends ItemEffect

@export var score_amount: int = 5

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, context: GameContext, multiplier: int = 1) -> GameAction:
	if context and context.battle:
		_replace_with_random_one_slot_items(instance, context.battle.backpack_manager, context)

	var action = GameAction.new(GameAction.Type.NUMERIC, "Gift box score")
	action.value = {"type": "score", "amount": score_amount * multiplier}
	return action

func _replace_with_random_one_slot_items(instance: BackpackManager.ItemInstance, backpack: BackpackManager, context: GameContext) -> void:
	var occupied_cells: Array[Vector2i] = []
	for offset in instance.data.shape:
		occupied_cells.append(instance.root_pos + offset)

	backpack.remove_instance(instance)

	var item_db = context.get_root_node_or_null("/root/ItemDatabase") if context.state else null
	if item_db == null:
		return

	var candidates: Array[ItemData] = []
	for item in item_db.drawable_items:
		if item.id != "gift_box" and item.shape.size() == 1:
			candidates.append(item)

	if candidates.is_empty():
		return

	for cell in occupied_cells:
		if backpack.grid.has(cell):
			continue
		var random_index := context.random_index(candidates.size()) if context != null else randi() % candidates.size()
		var chosen = candidates[random_index].duplicate(true)
		backpack.place_item(chosen, cell)
