class_name OrnamentEffect
extends Resource

func modify_sanity_loss(amount: int, _reason: String, _item_data: ItemData, _context: GameContext, _state: Dictionary) -> int:
	return amount

func after_battle_started(_context: GameContext, _state: Dictionary) -> void:
	pass

func after_item_drawn(_item_data: ItemData, _draw_count: int, _context: GameContext, _state: Dictionary) -> void:
	pass

func after_item_placed(_instance: BackpackManager.ItemInstance, _context: GameContext, _state: Dictionary) -> void:
	pass

func after_item_discarded(_item_data: ItemData, _old_instance: BackpackManager.ItemInstance, _from_backpack: bool, _context: GameContext, _state: Dictionary) -> void:
	pass

func after_item_replaced(_old_data: ItemData, _new_instance: BackpackManager.ItemInstance, _context: GameContext, _state: Dictionary) -> void:
	pass

func after_impact_chain_resolved(_source: BackpackManager.ItemInstance, _actions: Array[GameAction], _context: GameContext, _state: Dictionary) -> void:
	pass

func get_extra_transmission_modes(_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, _state: Dictionary) -> Array[int]:
	return [] as Array[int]

func after_seed_sown(_instance: BackpackManager.ItemInstance, _context: GameContext, _state: Dictionary) -> void:
	pass

func after_seed_upgraded(_instance: BackpackManager.ItemInstance, _old_level: int, _new_level: int, _context: GameContext, _state: Dictionary) -> void:
	pass

func after_seed_sow_failed(_source: BackpackManager.ItemInstance, _direction: int, _context: GameContext, _state: Dictionary) -> void:
	pass

func after_pollution_changed(_instance: BackpackManager.ItemInstance, _old_value: int, _new_value: int, _context: GameContext, _state: Dictionary) -> void:
	pass

func after_tool_used(_tool_data, _target: Dictionary, _result: Dictionary, _context: GameContext, _state: Dictionary) -> void:
	pass

func _count_impacts(actions: Array[GameAction]) -> int:
	var count = 0
	for action in actions:
		if action.type == GameAction.Type.IMPACT:
			count += 1
	return count
