class_name ToolEffect
extends RefCounted

const ToolDataScript = preload("res://src/core/tools/tool_data.gd")
const WASTE_TAG := "废弃物"
const MECHANICAL_TAG := "机械"
const FOOD_IDS := ["apple", "roast_chicken"]

static func apply_tool(tool, target: Dictionary, battle, _run_manager: Node, _item_db: Node, _ornament_db: Node = null) -> Dictionary:
	var result := {
		"success": false,
		"reason": "",
		"tool_id": tool.id if tool != null else "",
		"target_type": str(target.get("type", "")),
	}
	if tool == null or battle == null:
		result["reason"] = "missing_context"
		return result

	match tool.id:
		"small_patch":
			return _apply_small_patch(tool, target, battle, result)
		"dream_value_candy":
			return _apply_dream_value_candy(target, battle, result)
		"turning_screw":
			return _apply_turning_screw(tool, target, battle, result)
		"cracked_marble":
			return _apply_cracked_marble(target, battle, result)
		"black_ink_drop":
			return _apply_black_ink_drop(target, battle, result)
		"disinfectant_spray":
			return _apply_disinfectant_spray(target, battle, result)
		"corrosive_acid":
			return _apply_corrosive_acid(target, battle, result)
		"extension_hook":
			return _apply_extension_hook(target, battle, result)
		"transmission_oil":
			return _apply_transmission_oil(target, battle, result)
		"apple_wax":
			return _apply_apple_wax(target, battle, result)
		"recycling_clip":
			return _apply_recycling_clip(target, battle, result)
		"blank_talisman":
			return _apply_blank_talisman(target, battle, result)

	result["reason"] = "unknown_tool"
	return result

static func make_tool_reward(tool) -> Dictionary:
	if tool == null:
		return {}
	return {
		"type": "tool",
		"id": tool.id,
		"title": tool.tool_name,
		"description": "进入待放置区，可拖入背包网格或堆叠到同名道具。\n%s" % tool.effect_text,
		"item_destination": "staging",
		"rarity": tool.rarity,
		"amount": 1,
	}

static func make_tool_offer(tool) -> Dictionary:
	if tool == null:
		return {}
	return {
		"type": "tool",
		"id": tool.id,
		"title": tool.tool_name,
		"description": "%s\n购买后进入待放置区，可拖入背包网格或堆叠到同名道具。" % tool.effect_text,
		"item_destination": "staging",
		"rarity": tool.rarity,
		"price": max(1, int(tool.price)),
		"weight": _tool_weight(tool),
	}

static func _apply_small_patch(_tool, target: Dictionary, _battle, result: Dictionary) -> Dictionary:
	var instance = _target_instance(target)
	if instance == null or instance.data == null:
		return _fail(result, "invalid_item_target")
	instance.data.price += 3
	result["value_delta"] = 3
	return _success(result)

static func _apply_dream_value_candy(target: Dictionary, battle, result: Dictionary) -> Dictionary:
	if str(target.get("type", "")) != ToolDataScript.TARGET_DREAMCATCHER:
		return _fail(result, "invalid_dreamcatcher_target")
	if battle.has_method("add_next_draw_cost_discount"):
		battle.add_next_draw_cost_discount(2)
		result["dream_cost_discount"] = 2
		return _success(result)
	return _fail(result, "missing_draw_discount_hook")

static func _apply_turning_screw(_tool, target: Dictionary, battle, result: Dictionary) -> Dictionary:
	var instance = _target_instance(target)
	if instance == null or instance.data == null or not instance.data.can_rotate:
		return _fail(result, "invalid_item_target")
	if not _rotate_instance_in_backpack(battle, instance):
		return _fail(result, "rotation_blocked")
	_add_score(battle, 2)
	result["score"] = 2
	return _success(result)

static func _apply_cracked_marble(target: Dictionary, battle, result: Dictionary) -> Dictionary:
	var instance = _target_instance(target)
	if not _is_instance_in_grid(battle, instance):
		return _fail(result, "invalid_item_target")
	if battle.queue_impact_at(instance.root_pos, instance.data.direction, instance, "tool_cracked_marble"):
		result["queued_impact"] = true
		return _success(result)
	return _fail(result, "impact_not_queued")

static func _apply_black_ink_drop(target: Dictionary, battle, result: Dictionary) -> Dictionary:
	var instance = _target_instance(target)
	if not _is_instance_in_grid(battle, instance):
		return _fail(result, "invalid_item_target")
	var amount := 1 + (1 if _is_waste(instance.data) else 0)
	_add_pollution(battle, instance, amount)
	result["pollution_added"] = amount
	return _success(result)

static func _apply_disinfectant_spray(target: Dictionary, battle, result: Dictionary) -> Dictionary:
	var instance = _target_instance(target)
	if not _is_instance_in_grid(battle, instance):
		return _fail(result, "invalid_item_target")
	var purified = max(0, int(instance.current_pollution))
	instance.current_pollution = 0
	if purified > 0:
		_add_score(battle, purified * 3)
	result["purified_layers"] = purified
	result["score"] = purified * 3
	return _success(result)

static func _apply_corrosive_acid(target: Dictionary, battle, result: Dictionary) -> Dictionary:
	var instance = _target_instance(target)
	if not _is_instance_in_grid(battle, instance):
		return _fail(result, "invalid_item_target")
	_add_pollution(battle, instance, 2)
	var old_price := int(instance.data.price)
	instance.data.price = max(1, old_price - 5)
	result["pollution_added"] = 2
	result["value_delta"] = int(instance.data.price) - old_price
	return _success(result)

static func _apply_extension_hook(target: Dictionary, _battle, result: Dictionary) -> Dictionary:
	var instance = _target_instance(target)
	if instance == null or instance.data == null:
		return _fail(result, "invalid_item_target")
	instance.data.set_meta("tool_extension_hook", true)
	result["item_status"] = "extension_hook"
	return _success(result)

static func _apply_transmission_oil(target: Dictionary, _battle, result: Dictionary) -> Dictionary:
	var instance = _target_instance(target)
	if instance == null or instance.data == null or not _has_tag(instance.data, MECHANICAL_TAG):
		return _fail(result, "invalid_mechanical_target")
	instance.data.set_meta("tool_transmission_oil_remaining", 3)
	result["item_status"] = "transmission_oil"
	return _success(result)

static func _apply_apple_wax(target: Dictionary, _battle, result: Dictionary) -> Dictionary:
	var instance = _target_instance(target)
	if instance == null or instance.data == null or not _is_food(instance.data):
		return _fail(result, "invalid_food_target")
	instance.data.set_meta("tool_apple_wax", true)
	result["item_status"] = "apple_wax"
	return _success(result)

static func _apply_recycling_clip(target: Dictionary, battle, result: Dictionary) -> Dictionary:
	if str(target.get("type", "")) != ToolDataScript.TARGET_DISCARD:
		return _fail(result, "invalid_discard_target")
	if battle.has_method("add_recycling_clip_pending"):
		battle.add_recycling_clip_pending(1)
		result["discard_status"] = "recycling_clip"
		return _success(result)
	return _fail(result, "missing_discard_hook")

static func _apply_blank_talisman(target: Dictionary, battle, result: Dictionary) -> Dictionary:
	if str(target.get("type", "")) != ToolDataScript.TARGET_ORNAMENT:
		return _fail(result, "invalid_ornament_target")
	var ornament_id = str(target.get("ornament_id", ""))
	if ornament_id == "" or not battle.has_method("refresh_ornament_once"):
		return _fail(result, "invalid_ornament_target")
	if not battle.refresh_ornament_once(ornament_id):
		return _fail(result, "ornament_refresh_blocked")
	result["ornament_refreshed"] = ornament_id
	return _success(result)

static func _rotate_instance_in_backpack(battle, instance) -> bool:
	if not _is_instance_in_grid(battle, instance):
		return false
	var backpack = battle.backpack_manager
	var root_pos = instance.root_pos
	var item_data: ItemData = instance.data
	var runtime_id = item_data.runtime_id
	var old_direction = item_data.direction
	var old_shape = item_data.shape.duplicate()

	backpack.remove_by_runtime_id(runtime_id)
	item_data.rotate_90()
	if backpack.can_place_item(item_data, root_pos):
		backpack.place_item(item_data, root_pos)
		_sync_rotated_item_ui(battle, runtime_id, root_pos)
		return true

	item_data.direction = old_direction
	item_data.shape = old_shape
	backpack.place_item(item_data, root_pos)
	_sync_rotated_item_ui(battle, runtime_id, root_pos)
	return false

static func _sync_rotated_item_ui(battle, runtime_id: int, root_pos: Vector2i) -> void:
	if battle == null or battle.backpack_ui == null:
		return
	var ui_map = battle.backpack_ui.get("item_ui_map")
	if not (ui_map is Dictionary) or not ui_map.has(runtime_id):
		if battle.backpack_ui.has_method("update_slot_visuals"):
			battle.backpack_ui.update_slot_visuals()
		return
	var item_ui = ui_map[runtime_id]
	if item_ui == null or not is_instance_valid(item_ui):
		return
	var new_instance = battle.backpack_manager.grid.get(root_pos)
	if new_instance != null:
		item_ui.set("item_instance", new_instance)
		item_ui.set("item_data", new_instance.data)
		if item_ui.has_method("_sync_visuals"):
			item_ui._sync_visuals()
		if battle.backpack_ui.has_method("add_item_visual"):
			battle.backpack_ui.add_item_visual(item_ui, root_pos)

static func _add_pollution(battle, instance, amount: int) -> void:
	var resolver = ImpactResolver.new(battle.backpack_manager, battle.context)
	resolver.add_pollution(instance, amount)

static func _add_score(battle, amount: int) -> void:
	if battle != null and battle.context != null:
		battle.context.add_score(amount)

static func _target_instance(target: Dictionary):
	return target.get("instance", null)

static func _is_instance_in_grid(battle, instance) -> bool:
	if battle == null or battle.backpack_manager == null or instance == null:
		return false
	if battle.has_method("_is_instance_in_grid"):
		return battle._is_instance_in_grid(instance)
	return battle.backpack_manager.grid.values().has(instance)

static func _has_tag(item_data: ItemData, tag: String) -> bool:
	return item_data != null and item_data.tags.has(tag)

static func _is_waste(item_data: ItemData) -> bool:
	return item_data != null and item_data.tags.has(WASTE_TAG)

static func _is_food(item_data: ItemData) -> bool:
	return item_data != null and (item_data.tags.has("食物") or FOOD_IDS.has(item_data.id))

static func _tool_weight(tool) -> float:
	match tool.rarity:
		"道具":
			return 7.0
		"罕见道具":
			return 4.0
		"稀有道具":
			return 2.0
	return 3.0

static func _success(result: Dictionary) -> Dictionary:
	result["success"] = true
	result["reason"] = ""
	return result

static func _fail(result: Dictionary, reason: String) -> Dictionary:
	result["success"] = false
	result["reason"] = reason
	return result
