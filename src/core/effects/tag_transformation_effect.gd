class_name TagTransformationEffect
extends ItemEffect

## 标签转换效果：监听到特定标签被抽到时，变身为另一个物品。
## 适用于：苹果核 (抽到“水” -> 变回苹果)。

@export var trigger_tag: String = "水"
@export var target_item_id: String = "apple"

func on_draw(item_data: ItemData, context: GameContext) -> GameAction:
	var bus = context.get_root_node_or_null("/root/GlobalEventBus")
	if bus:
		if not bus.item_drawn.is_connected(_on_item_drawn):
			bus.item_drawn.connect(_on_item_drawn.bind(item_data, context))
	return null

func _on_item_drawn(drawn_item_data: ItemData, my_data: ItemData, context: GameContext):
	if drawn_item_data.tags.has(trigger_tag):
		var item_db = context.get_root_node_or_null("/root/ItemDatabase")
		var new_data = item_db.get_item_by_id(target_item_id) if item_db else null
		
		if new_data:
			print("[Effect] 进化！", my_data.item_name, " 感应到 ", trigger_tag, " 变身为 ", new_data.item_name)
			var my_pos = context.battle._find_item_old_pos(my_data)
			if my_pos != Vector2i(-1, -1):
				context.battle.backpack_manager.replace_item_data(my_pos, new_data)
