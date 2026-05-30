class_name ReactiveImpactEffect
extends ItemEffect

## 梦境燃料罐效果：当其他物品被撞击时，自己也触发一次撞击

func on_draw(item_data: ItemData, context: GameContext) -> GameAction:
	var bus = context.get_root_node_or_null("/root/GlobalEventBus")
	if bus:
		# 注意：这里需要一个闭包或者弱引用，防止内存泄漏
		# 我们让它监听全局撞击信号
		if not bus.item_impacted.is_connected(_on_any_item_impacted):
			bus.item_impacted.connect(_on_any_item_impacted.bind(item_data, context))
	return null

func _on_any_item_impacted(hit_instance, _source_instance, my_data, context):
	# 检查上下文和战斗管理器是否仍然有效
	if not is_instance_valid(context) or not is_instance_valid(context.battle):
		return
		
	# 只有当被撞击的不是自己时才触发
	if hit_instance.data.runtime_id == my_data.runtime_id:
		return
		
	# 找到自己在背包中的位置并触发撞击
	var my_pos = context.battle._find_item_old_pos(my_data)
	if my_pos != Vector2i(-1, -1):
		print("[Effect] 梦境燃料罐感应到撞击，开始连锁! 源: ", hit_instance.data.item_name)
		# Queue this as a new chain to avoid recursive impact resolution.
		context.battle.queue_impact_at(my_pos, -1, null, "reactive_impact")
