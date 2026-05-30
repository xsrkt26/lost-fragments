class_name AppleDiscardEffect
extends ItemEffect

@export var score_amount: int = 3
@export var core_item_id: String = "apple_core"

func on_discard_instance(instance: BackpackManager.ItemInstance, context: GameContext) -> GameAction:
	if context and context.state:
		context.state.add_score(score_amount)

	if context and context.battle and instance:
		var item_db = context.get_root_node_or_null("/root/ItemDatabase")
		var core_data = item_db.get_item_by_id(core_item_id) if item_db else null
		if core_data:
			context.battle.backpack_manager.place_item(core_data, instance.root_pos)

	var action = GameAction.new(GameAction.Type.NUMERIC, "Apple discard score")
	action.value = {"type": "score", "amount": score_amount}
	return action

func on_discard(_item_data: ItemData, context: GameContext) -> GameAction:
	return null
