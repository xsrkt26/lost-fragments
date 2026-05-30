class_name TransformationEffect
extends ItemEffect

## 转换效果：被撞击后变身为另一个物品

@export var target_item_id: String = "" # 变身后的物品 ID (如果为空则随机)
@export var bonus_score: int = 20 # 变身时额外加分

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, context: GameContext, multiplier: int = 1) -> GameAction:
	var item_db = context.get_root_node_or_null("/root/ItemDatabase")
	if not item_db: return null
	
	var new_data: ItemData
	if target_item_id == "":
		new_data = item_db.get_random_item()
	else:
		new_data = item_db.get_item_by_id(target_item_id)
		
	if new_data:
		print("[Effect] 物品变身! ", instance.data.item_name, " -> ", new_data.item_name)
		
		# 1. 逻辑层替换
		var manager = context.battle.backpack_manager
		manager.replace_item_data(instance.root_pos, new_data)
		
		# 2. 表现层同步：通知 UI 更新 (可以通过信号或者直接获取 UI)
		var ui = context.battle.backpack_ui
		if ui:
			# 这里为了简单，我们让 UI 重新刷新该格子的表现
			if manager.grid.has(instance.root_pos):
				var old_runtime_id = instance.data.runtime_id
				var new_instance = manager.grid[instance.root_pos]
				new_instance.data.runtime_id = old_runtime_id # 保持 ID 连贯性，防止 UI 映射丢失
			pass
			
	var action = GameAction.new(GameAction.Type.NUMERIC, "物品变身")
	action.value = {"type": "score", "amount": bonus_score * multiplier}
	return action
