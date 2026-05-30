extends "res://src/core/ornaments/ornament_effect.gd"

const WASTE_TAG := "废弃物"
const MECHANICAL_TAG := "机械"
const SEED_TAG := "梦境之种"
const FOOD_IDS := ["apple", "roast_chicken"]

@export var effect_id: String = ""

func modify_sanity_loss(amount: int, reason: String, item_data: ItemData, _context: GameContext, _state: Dictionary) -> int:
	if effect_id == "sturdy_strap" and reason == "draw" and item_data != null and item_data.shape.size() >= 4:
		return max(1, amount - 2)
	return amount

func after_battle_started(context: GameContext, state: Dictionary) -> void:
	match effect_id:
		"collection_cabinet":
			var categories = {}
			var battle = _battle(context)
			if battle == null:
				return
			for runtime in battle.active_ornaments:
				var ornament = runtime.get("data")
				if ornament != null and ornament.category != "":
					categories[ornament.category] = true
			var score = int(categories.size() / 3) * 4
			if categories.size() >= 5:
				score += 8
			_add_score(context, score)
		"tri_phase_crown":
			state["pollution_seen"] = false
			state["seed_seen"] = false
			state["used"] = false

func after_item_drawn(item_data: ItemData, draw_count: int, context: GameContext, state: Dictionary) -> void:
	match effect_id:
		"stain_sticker":
			if _is_waste(item_data):
				var waste = _first_instance_with_tag(_backpack(context), WASTE_TAG)
				if waste != null:
					waste.add_pollution(1)
		"black_tide_bottle":
			if draw_count > 0 and draw_count % 6 == 0:
				for instance in _all_instances(_backpack(context)):
					if instance.current_pollution > 0:
						instance.add_pollution(1)
		"moon_dew_bottle":
			if draw_count > 0 and draw_count % 4 == 0:
				_upgrade_first_seed(context)
		"nightmare_contract":
			if context != null and context.state != null and context.state.current_sanity < 20 and not state.get("active", false):
				context.state.set_modifier("ornament_score_bonus", 1)
				state["active"] = true
		"twilight_hourglass":
			if draw_count >= 15 and not state.get("active", false):
				context.state.set_modifier("ornament_score_multiplier", 1.3)
				state["active"] = true

func after_item_placed(instance: BackpackManager.ItemInstance, context: GameContext, state: Dictionary) -> void:
	if effect_id != "buckle_guide" or instance == null:
		return
	var draw_count = _draw_count(context)
	if state.get("last_trigger_draw", -1) == draw_count:
		return
	for neighbor in _backpack(context).get_neighbor_instances(instance):
		if neighbor.data.direction == instance.data.direction:
			_add_score(context, 3)
			state["last_trigger_draw"] = draw_count
			return

func after_item_discarded(item_data: ItemData, old_instance: BackpackManager.ItemInstance, from_backpack: bool, context: GameContext, state: Dictionary) -> void:
	match effect_id:
		"sanity_coin_purse":
			state["discard_count"] = int(state.get("discard_count", 0)) + 1
			if int(state["discard_count"]) % 3 == 0:
				_change_sanity(context, 2)
		"light_pendant":
			if not state.get("used", false):
				_add_score(context, 6)
				if _is_waste(item_data):
					_add_score(context, 4)
				state["used"] = true
		"compost_bag":
			var draw_count = _draw_count(context)
			var key = "compost_count_%d" % draw_count
			if int(state.get(key, 0)) < 2:
				if _upgrade_first_seed(context) != null:
					state[key] = int(state.get(key, 0)) + 1
		"honey_spoon":
			if _is_food(item_data):
				_add_score(context, 4)
				_sow_from_instance(context, old_instance)
		"apple_wooden_tag":
			if from_backpack and item_data != null and item_data.id == "apple":
				_sow_from_instance(context, old_instance)
		"recycling_hook":
			if _is_waste(item_data) and int(state.get("waste_sanity_uses", 0)) < 2:
				_change_sanity(context, 1)
				state["waste_sanity_uses"] = int(state.get("waste_sanity_uses", 0)) + 1

func after_item_replaced(old_data: ItemData, new_instance: BackpackManager.ItemInstance, context: GameContext, _state: Dictionary) -> void:
	if effect_id != "apple_wooden_tag" or old_data == null or new_instance == null or new_instance.data == null:
		return
	if old_data.id == "apple_core" and new_instance.data.id == "apple":
		_add_score(context, 4)

func after_impact_chain_resolved(source: BackpackManager.ItemInstance, actions: Array[GameAction], context: GameContext, state: Dictionary) -> void:
	var hit_count = _count_impacts(actions)
	var targets = _impact_targets(actions)
	var summary = _resolution_summary(actions)
	match effect_id:
		"protective_gloves":
			for target in targets:
				if target.current_pollution > 0 and int(state.get("uses", 0)) < 2:
					_add_score(context, 2)
					state["uses"] = int(state.get("uses", 0)) + 1
		"leaking_valve":
			if _is_root_dream(source):
				for target in targets:
					target.add_pollution(1)
		"waste_receipt":
			for target in targets:
				if _is_waste(target.data) and target.current_pollution > 0:
					_add_score(context, target.current_pollution)
		"black_raincoat":
			for target in targets:
				if target.current_pollution >= 3:
					_add_score(context, 5)
		"pathology_lens":
			for target in targets:
				if target.current_pollution >= 5:
					_add_score(context, target.current_pollution * 2)
		"root_bell":
			for target in targets:
				if _is_seed(target):
					_upgrade_adjacent_seed(context, target)
		"harvest_basket":
			if not state.get("used", false):
				for target in targets:
					if _seed_stage(target) >= 4:
						_add_score(context, 25)
						state["used"] = true
						break
		"marble_spring":
			if _is_root_dream(source):
				_add_score(context, 3)
		"tailing_spark":
			if hit_count >= 3:
				_add_score(context, 8)
		"return_ruler":
			if not targets.is_empty() and source != null and targets[0].data.direction == source.data.direction:
				_add_score(context, 5)
		"chain_counter":
			if hit_count > 0:
				_add_score(context, hit_count + (8 if hit_count >= 6 else 0))
		"magnetic_pendant":
			for target in targets:
				if _has_tag(target.data, MECHANICAL_TAG):
					_add_score(context, 6)
					break
		"gear_oil":
			_add_score(context, min(int(summary.get("successful_mechanical_transmission_count", 0)), 5) * 2)
		"recoil_plate":
			var last_target = targets[targets.size() - 1] if not targets.is_empty() else null
			if not state.get("used", false) and last_target != null and _has_tag(last_target.data, MECHANICAL_TAG):
				_queue_recoil_impact(context, last_target)
				state["used"] = true
		"universal_bearing":
			if state.get("used_draw", -1) != _draw_count(context):
				for target in targets:
					if _has_tag(target.data, MECHANICAL_TAG):
						_queue_extra_impact(context, target)
						state["used_draw"] = _draw_count(context)
						break
		"overload_lamp":
			if hit_count > 0:
				var draw_count = _draw_count(context)
				if int(state.get("last_impact_draw", -999)) == draw_count - 1 and state.get("scored_draw", -1) != draw_count:
					_add_score(context, 12 + (8 if hit_count >= 5 else 0))
					state["scored_draw"] = draw_count
				state["last_impact_draw"] = draw_count
		"terminal_pressure_gauge":
			var mechanical_hit_count = int(summary.get("mechanical_hit_count", _mechanical_hit_count(targets)))
			if mechanical_hit_count >= 12:
				_add_score(context, 45)
			elif mechanical_hit_count >= 8:
				_add_score(context, 25)
		"kaleidoscope":
			if _different_tag_count(targets) >= 3:
				_add_score(context, 15)
		"black_market_stamp":
			for target in targets:
				if _is_waste(target.data):
					_add_score(context, int(target.data.price / 2))
		"fusion_badge":
			for target in targets:
				if _has_same_tag_neighbor(_backpack(context), target):
					_add_score(context, 2)
		"tri_phase_crown":
			if hit_count >= 5 and state.get("pollution_seen", false) and state.get("seed_seen", false) and not state.get("used", false):
				_add_score(context, 45)
				state["used"] = true

func after_seed_sown(_instance: BackpackManager.ItemInstance, context: GameContext, state: Dictionary) -> void:
	match effect_id:
		"gardener_gloves":
			if not state.get("used", false):
				_add_score(context, 3)
				state["used"] = true
		"tri_phase_crown":
			state["seed_seen"] = true

func after_seed_upgraded(_instance: BackpackManager.ItemInstance, old_level: int, new_level: int, context: GameContext, state: Dictionary) -> void:
	match effect_id:
		"greenhouse_glass":
			_add_score(context, 1 + _seed_level_bonus(old_level, new_level))
		"rejuvenation_talisman":
			if old_level < 30 and new_level >= 30 and not state.get("used", false):
				_change_sanity(context, 3)
				state["used"] = true
		"tri_phase_crown":
			state["seed_seen"] = true

func after_seed_sow_failed(_source: BackpackManager.ItemInstance, _direction: int, context: GameContext, state: Dictionary) -> void:
	if effect_id != "seed_insurance":
		return
	var draw_count = _draw_count(context)
	if state.get("used_draw", -1) == draw_count:
		return
	_add_score(context, 8)
	state["used_draw"] = draw_count

func get_extra_transmission_modes(instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, state: Dictionary) -> Array[int]:
	if effect_id != "universal_bearing" or instance == null or not _has_tag(instance.data, MECHANICAL_TAG):
		return [] as Array[int]
	var resolver_id = resolver.get_instance_id()
	if int(state.get("used_resolution_id", -1)) == resolver_id:
		return [] as Array[int]
	state["used_resolution_id"] = resolver_id
	return [ItemData.TransmissionMode.MECHANICAL_BIDIRECTIONAL] as Array[int]

func after_pollution_changed(instance: BackpackManager.ItemInstance, old_value: int, new_value: int, context: GameContext, state: Dictionary) -> void:
	if new_value > old_value:
		match effect_id:
			"sealed_bottle":
				if not state.get("used", false):
					_add_score(context, 4)
					state["used"] = true
			"active_petri_dish":
				if old_value > 0:
					var key = "draw_%d" % _draw_count(context)
					if int(state.get(key, 0)) < 3:
						_add_score(context, 2)
						state[key] = int(state.get(key, 0)) + 1
			"corrosion_guide":
				_add_score(context, 1)
			"tri_phase_crown":
				state["pollution_seen"] = true
	elif new_value < old_value:
		var purified = old_value - new_value
		match effect_id:
			"purification_bell":
				var used = int(state.get("sanity_used", 0))
				var amount = min(purified, max(0, 5 - used))
				if amount > 0:
					_change_sanity(context, amount)
					state["sanity_used"] = used + amount
			"black_market_trash_bag":
				state["purified_layers"] = int(state.get("purified_layers", 0)) + purified
				while int(state.get("purified_layers", 0)) >= 3:
					_add_score(context, 8)
					state["purified_layers"] = int(state.get("purified_layers", 0)) - 3
				if _is_waste(instance.data):
					_change_sanity(context, 1)

func after_tool_used(tool_data, target: Dictionary, result: Dictionary, context: GameContext, state: Dictionary) -> void:
	if tool_data == null:
		return
	match effect_id:
		"tool_belt":
			state["tool_uses"] = int(state.get("tool_uses", 0)) + 1
			if not state.get("first_tool_scored", false):
				_add_score(context, 3)
				state["first_tool_scored"] = true
			if int(state.get("tool_uses", 0)) >= 3 and not state.get("third_tool_scored", false):
				_add_score(context, 8)
				state["third_tool_scored"] = true
		"specimen_pin_case":
			if tool_data.tags.has("污染") or tool_data.tags.has("净化"):
				_add_score(context, 3)
				var instance = target.get("instance", null)
				if instance != null and instance.data != null and _is_waste(instance.data):
					_add_score(context, 3)
		"gardening_toolkit":
			if bool(result.get("seed_sown", false)) or bool(result.get("seed_upgraded", false)):
				_add_score(context, 4)
			if bool(result.get("seed_grew", false)):
				_add_score(context, 8)
		"recycling_hook":
			if tool_data.tags.has("丢弃"):
				_add_score(context, 4)
		"calibration_screwdriver":
			var instance = target.get("instance", null)
			if instance != null and instance.data != null and _has_tag(instance.data, MECHANICAL_TAG):
				instance.data.set_meta("orn_calibration_bonus_pending", 1)
		"universal_toolbox":
			_record_universal_toolbox_target(tool_data, target, context, state)

func _add_score(context: GameContext, amount: int) -> void:
	if context == null or amount <= 0:
		return
	var final_amount = amount
	if context.state != null and context.state.has_method("get_modifier"):
		final_amount += int(context.state.get_modifier("ornament_score_bonus", 0))
		final_amount = int(round(float(final_amount) * float(context.state.get_modifier("ornament_score_multiplier", 1.0))))
	if final_amount > 0:
		context.add_score(final_amount)

func _change_sanity(context: GameContext, amount: int) -> void:
	if context != null and amount != 0:
		context.change_sanity(amount)

func _record_universal_toolbox_target(tool_data, target: Dictionary, context: GameContext, state: Dictionary) -> void:
	var target_type = str(target.get("type", ""))
	match target_type:
		"item":
			state["used_on_item"] = true
		"empty_cell":
			state["used_on_empty_cell"] = true
		"dreamcatcher":
			state["used_on_dreamcatcher"] = true
	if state.get("rewarded", false):
		return
	if state.get("used_on_item", false) and state.get("used_on_empty_cell", false) and state.get("used_on_dreamcatcher", false):
		_add_score(context, 12)
		_grant_common_tool(context, tool_data.id)
		state["rewarded"] = true

func _grant_common_tool(context: GameContext, excluded_tool_id: String = "") -> void:
	if context == null or context.state == null:
		return
	var tool_db = context.get_root_node_or_null("/root/ToolDatabase")
	var rm = context.get_root_node_or_null("/root/RunManager")
	if tool_db == null or rm == null or not rm.has_method("grant_tool"):
		return
	var tools = tool_db.get_tools_by_rarity("道具") if tool_db.has_method("get_tools_by_rarity") else []
	tools.sort_custom(func(a, b): return a.id < b.id)
	for tool in tools:
		if tool.id != excluded_tool_id:
			rm.grant_tool(tool.id, 1, tool_db, "universal_toolbox")
			return

func _battle(context: GameContext):
	return context.battle if context != null else null

func _backpack(context: GameContext):
	var battle = _battle(context)
	return battle.backpack_manager if battle != null else null

func _draw_count(context: GameContext) -> int:
	var battle = _battle(context)
	return int(battle.draw_count) if battle != null else 0

func _item_db(context: GameContext):
	if context != null and context.state != null:
		return context.get_root_node_or_null("/root/ItemDatabase")
	return null

func _all_instances(backpack) -> Array:
	return backpack.get_all_instances() if backpack != null else []

func _impact_targets(actions: Array[GameAction]) -> Array:
	var result = []
	for action in actions:
		if action.type == GameAction.Type.IMPACT and action.item_instance != null and not result.has(action.item_instance):
			result.append(action.item_instance)
	return result

func _first_instance_with_tag(backpack, tag: String):
	for instance in _sorted_instances(_all_instances(backpack)):
		if _has_tag(instance.data, tag):
			return instance
	return null

func _sorted_instances(instances: Array) -> Array:
	var sorted = instances.duplicate()
	sorted.sort_custom(func(a, b): return _priority(a) < _priority(b))
	return sorted

func _priority(instance) -> int:
	if instance == null:
		return 999999
	return instance.root_pos.y * 100 + instance.root_pos.x

func _has_tag(item_data: ItemData, tag: String) -> bool:
	return item_data != null and item_data.tags.has(tag)

func _is_waste(item_data: ItemData) -> bool:
	return _has_tag(item_data, WASTE_TAG)

func _is_food(item_data: ItemData) -> bool:
	return item_data != null and (item_data.tags.has("食物") or FOOD_IDS.has(item_data.id))

func _is_seed(instance) -> bool:
	return instance != null and _has_tag(instance.data, SEED_TAG)

func _seed_level(instance) -> int:
	if not _is_seed(instance):
		return 0
	if instance.dream_seed_level > 0:
		return instance.dream_seed_level
	if instance.data != null and instance.data.has_meta("dream_seed_level"):
		return int(instance.data.get_meta("dream_seed_level"))
	return _seed_stage_min_level(_seed_stage(instance))

func _seed_stage(instance) -> int:
	if not _is_seed(instance):
		return 0
	for stage in range(1, 5):
		if instance.data.id == "dream_seed_%dx%d" % [stage, stage]:
			return stage
	return 1

func _seed_stage_min_level(stage: int) -> int:
	match stage:
		2:
			return 10
		3:
			return 20
		4:
			return 30
	return 1

func _is_root_dream(instance) -> bool:
	return instance != null and instance.data != null and instance.data.id == "root_dream"

func _upgrade_first_seed(context: GameContext):
	var backpack = _backpack(context)
	var item_db = _item_db(context)
	if backpack == null or item_db == null:
		return null
	for instance in _sorted_instances(backpack.get_all_instances()):
		if _is_seed(instance):
			return backpack.upgrade_seed(instance, item_db, 1)
	return null

func _upgrade_adjacent_seed(context: GameContext, source) -> void:
	var backpack = _backpack(context)
	var item_db = _item_db(context)
	if backpack == null or item_db == null:
		return
	for neighbor in backpack.get_neighbor_instances(source):
		if _is_seed(neighbor):
			backpack.upgrade_seed(neighbor, item_db, 1)
			return

func _sow_from_instance(context: GameContext, source) -> void:
	var backpack = _backpack(context)
	var item_db = _item_db(context)
	if backpack == null or item_db == null or source == null:
		return
	backpack.sow_seed(source, source.data.direction, item_db, 1)

func _queue_recoil_impact(context: GameContext, instance) -> void:
	var battle = _battle(context)
	if battle != null and battle.has_method("queue_impact_at"):
		battle.queue_impact_at(instance.root_pos, _opposite_direction(instance.data.direction), instance, effect_id, [MECHANICAL_TAG] as Array[String])

func _queue_extra_impact(context: GameContext, instance) -> void:
	var battle = _battle(context)
	if battle != null and battle.has_method("queue_impact_at"):
		battle.queue_impact_at(instance.root_pos, instance.data.direction, instance, effect_id)

func _opposite_direction(direction: int) -> int:
	match direction:
		ItemData.Direction.UP:
			return ItemData.Direction.DOWN
		ItemData.Direction.DOWN:
			return ItemData.Direction.UP
		ItemData.Direction.LEFT:
			return ItemData.Direction.RIGHT
		ItemData.Direction.RIGHT:
			return ItemData.Direction.LEFT
	return direction

func _different_tag_count(targets: Array) -> int:
	var tags = {}
	for target in targets:
		for tag in target.data.tags:
			tags[tag] = true
	return tags.size()

func _mechanical_hit_count(targets: Array) -> int:
	var count := 0
	for target in targets:
		if target != null and _has_tag(target.data, MECHANICAL_TAG):
			count += 1
	return count

func _resolution_summary(actions: Array[GameAction]) -> Dictionary:
	for index in range(actions.size() - 1, -1, -1):
		var action = actions[index]
		if action.type == GameAction.Type.EFFECT and action.value is Dictionary and action.value.get("type", "") == "impact_context_summary":
			var raw_summary = action.value.get("summary", {})
			return raw_summary if raw_summary is Dictionary else {}
	return {}

func _seed_level_bonus(old_level: int, new_level: int) -> int:
	for threshold in [10, 20, 30]:
		if old_level < threshold and new_level >= threshold:
			return 8
	return 0

func _has_same_tag_neighbor(backpack, target) -> bool:
	if backpack == null or target == null:
		return false
	for neighbor in backpack.get_neighbor_instances(target):
		for tag in target.data.tags:
			if neighbor.data.tags.has(tag):
				return true
	return false
