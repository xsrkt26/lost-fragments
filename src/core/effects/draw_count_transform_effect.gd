class_name DrawCountTransformEffect
extends ItemEffect

@export var interval: int = 5
@export var target_item_id: String = ""

func on_global_item_drawn(_new_item: ItemData, my_instance: BackpackManager.ItemInstance, context: GameContext):
	if interval <= 0 or target_item_id == "":
		return
	if context == null or context.battle == null:
		return
	if context.battle.draw_count <= 0 or context.battle.draw_count % interval != 0:
		return

	var item_db = context.get_root_node_or_null("/root/ItemDatabase") if context.state else null
	var new_data = item_db.get_item_by_id(target_item_id) if item_db else null
	if new_data:
		context.battle.backpack_manager.replace_item_data(my_instance.root_pos, new_data)
