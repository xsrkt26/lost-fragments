class_name ValueBoosterEffect
extends ItemEffect

## 垃圾回收器效果：有废弃物被撞击时，使其价值 +1

func on_draw(item_data: ItemData, context: GameContext) -> GameAction:
	var bus = context.get_root_node_or_null("/root/GlobalEventBus")
	if bus:
		if not bus.item_impacted.is_connected(_on_item_impacted):
			bus.item_impacted.connect(_on_item_impacted.bind(item_data, context))
	return null

func _on_item_impacted(hit_instance, source_instance, my_data, context):
	# 检查自己是否还在背包中 (防止已被丢弃但信号未断开)
	if context.battle:
		var my_pos = context.battle._find_item_old_pos(my_data)
		if my_pos == Vector2i(-1, -1): return

	# 检查被撞击的是否是废弃物
	if hit_instance.data.tags.has("废弃物"):
		hit_instance.data.price += 1
		print("[Effect] 垃圾回收器运作！", hit_instance.data.item_name, " 价值提升至: ", hit_instance.data.price)
