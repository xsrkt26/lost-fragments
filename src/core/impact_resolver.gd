class_name ImpactResolver
extends RefCounted

class ImpactResolutionContext:
	var hit_instances: Array = []
	var hit_positions: Array[Vector2i] = []
	var hit_directions: Array[int] = []
	var blocked_instances: Array = []
	var hit_count: int = 0
	var mechanical_hit_count: int = 0
	var turn_transmission_count: int = 0
	var bidirectional_transmission_count: int = 0
	var successful_mechanical_transmission_count: int = 0

	func has_seen(instance: Variant) -> bool:
		return hit_instances.has(instance) or blocked_instances.has(instance)

	func record_hit(instance: Variant, pos: Vector2i, direction: int) -> bool:
		if has_seen(instance):
			return false
		hit_instances.append(instance)
		hit_positions.append(pos)
		hit_directions.append(direction)
		hit_count += 1
		if instance != null and instance.data != null and instance.data.tags.has("机械"):
			mechanical_hit_count += 1
		return true

	func block_instance(instance: Variant) -> void:
		if instance != null and not blocked_instances.has(instance):
			blocked_instances.append(instance)

	func to_summary() -> Dictionary:
		return {
			"hit_count": hit_count,
			"mechanical_hit_count": mechanical_hit_count,
			"turn_transmission_count": turn_transmission_count,
			"bidirectional_transmission_count": bidirectional_transmission_count,
			"successful_mechanical_transmission_count": successful_mechanical_transmission_count,
		}

var backpack: BackpackManager
var context: GameContext
var actions_history: Array[GameAction] = []
var visited: Array = []
var resolution_context := ImpactResolutionContext.new()

func _init(p_backpack: BackpackManager, p_context: GameContext):
	backpack = p_backpack
	context = p_context

func resolve_impact(start_pos: Vector2i, dir: ItemData.Direction, source: BackpackManager.ItemInstance = null, initial_filters: Array[String] = []) -> Array[GameAction]:
	actions_history = []
	visited = []
	resolution_context = ImpactResolutionContext.new()
	_resolve_recursive(start_pos, dir, actions_history, source, initial_filters)
	_apply_after_resolution_effects(actions_history)
	_append_resolution_summary(actions_history)
	return actions_history

func get_current_resolution_summary() -> Dictionary:
	return resolution_context.to_summary()

func block_instance_for_current_resolution(instance: BackpackManager.ItemInstance, direction: int = -1) -> void:
	resolution_context.block_instance(instance)
	visited.append({"target": instance, "dir": direction})

func _resolve_recursive(current_pos: Vector2i, dir: ItemData.Direction, actions: Array[GameAction], source_instance: BackpackManager.ItemInstance = null, active_filters: Array[String] = [], ignore_visited: bool = false, branch_flags: Dictionary = {}) -> bool:
	var filters: Array[String] = active_filters
	if source_instance and not source_instance.data.hit_filter_tags.is_empty():
		filters = source_instance.data.hit_filter_tags

	var step = _direction_to_step(dir)
	var scan_start = current_pos
	if source_instance != null:
		scan_start = current_pos + step

	var next_item_pos = _find_next_item(scan_start, dir, filters, source_instance)
	if next_item_pos == Vector2i(-1, -1):
		return false

	var instance = backpack.grid[next_item_pos]
	if not ignore_visited and _has_seen_instance(instance):
		return false
	resolution_context.record_hit(instance, next_item_pos, dir)
	visited.append({"target": instance, "dir": dir})

	var hit_action = GameAction.new(GameAction.Type.IMPACT, "Hit " + instance.data.item_name)
	hit_action.item_instance = instance
	hit_action.value = {"pos": next_item_pos, "impact_context": resolution_context.to_summary()}
	actions.append(hit_action)

	var bus = context.get_root_node_or_null("/root/GlobalEventBus") if context and context.state else null
	if bus:
		bus.item_impacted.emit(instance, source_instance)

	var current_pollution = instance.current_pollution
	var total_multiplier = 1 + current_pollution

	for effect in instance.data.effects:
		var effect_action = effect.on_hit(instance, source_instance, self, context, total_multiplier)
		if effect_action:
			if effect_action.item_instance == null:
				effect_action.item_instance = instance
			actions.append(effect_action)

	if instance.data.transmission_mode == ItemData.TransmissionMode.NONE:
		return true

	if source_instance:
		for source_effect in source_instance.data.effects:
			if source_effect.has_method("execute_after_hit"):
				source_effect.execute_after_hit(instance, source_instance, self, context, actions)

	var did_hit_others = false
	match instance.data.transmission_mode:
		ItemData.TransmissionMode.NORMAL:
			if instance.data.direction == dir:
				for offset in instance.data.shape:
					if _resolve_recursive(instance.root_pos + offset, instance.data.direction, actions, instance, filters, false, branch_flags):
						did_hit_others = true
						if instance.data.tags.has("机械"):
							resolution_context.successful_mechanical_transmission_count += 1
							_append_tool_transmission_bonus(instance, actions)
		ItemData.TransmissionMode.OMNI:
			for next_dir in [ItemData.Direction.UP, ItemData.Direction.DOWN, ItemData.Direction.LEFT, ItemData.Direction.RIGHT]:
				for offset in instance.data.shape:
					if _resolve_recursive(instance.root_pos + offset, next_dir, actions, instance, filters, false, branch_flags):
						did_hit_others = true
		ItemData.TransmissionMode.MECHANICAL_LEFT:
			if _resolve_mechanical_transmission(instance, [_relative_left(instance.data.direction)], actions, false, branch_flags):
				did_hit_others = true
		ItemData.TransmissionMode.MECHANICAL_RIGHT:
			if _resolve_mechanical_transmission(instance, [_relative_right(instance.data.direction)], actions, false, branch_flags):
				did_hit_others = true
		ItemData.TransmissionMode.MECHANICAL_BIDIRECTIONAL:
			if resolution_context.mechanical_hit_count >= 3:
				if _resolve_mechanical_transmission(instance, [_relative_left(instance.data.direction), _relative_right(instance.data.direction)], actions, true, branch_flags):
					did_hit_others = true
		ItemData.TransmissionMode.MECHANICAL_OMNI:
			if not branch_flags.get("suppress_star_ring_bearing", false) and not instance.data.get_meta("star_ring_bearing_used", false):
				instance.data.set_meta("star_ring_bearing_used", true)
				var next_flags = branch_flags.duplicate(true)
				next_flags["suppress_star_ring_bearing"] = true
				if _resolve_mechanical_transmission(instance, [ItemData.Direction.UP, ItemData.Direction.RIGHT, ItemData.Direction.DOWN, ItemData.Direction.LEFT], actions, false, next_flags):
					did_hit_others = true

	if _resolve_extra_ornament_transmissions(instance, actions, branch_flags):
		did_hit_others = true

	if not did_hit_others and _resolve_tool_extension_hook(instance, actions, filters, branch_flags):
		did_hit_others = true

	for effect in instance.data.effects:
		if effect.has_method("after_impact"):
			var post_action = effect.after_impact(instance, did_hit_others, self, context, total_multiplier)
			if post_action:
				if post_action.item_instance == null:
					post_action.item_instance = instance
				actions.append(post_action)

	return true

func _resolve_extra_ornament_transmissions(instance: BackpackManager.ItemInstance, actions: Array[GameAction], branch_flags: Dictionary) -> bool:
	if context == null or context.battle == null or not (context.battle.get("active_ornaments") is Array):
		return false
	var hit_any = false
	for runtime in context.battle.active_ornaments:
		var ornament = runtime.get("data")
		var state = runtime.get("state", {}) as Dictionary
		if ornament != null and ornament.effect != null and ornament.effect.has_method("get_extra_transmission_modes"):
			for mode in ornament.effect.get_extra_transmission_modes(instance, self, context, state):
				match mode:
					ItemData.TransmissionMode.MECHANICAL_BIDIRECTIONAL:
						if _resolve_mechanical_transmission(instance, [_relative_left(instance.data.direction), _relative_right(instance.data.direction)], actions, true, branch_flags):
							hit_any = true
	return hit_any

func _resolve_mechanical_transmission(instance: BackpackManager.ItemInstance, directions: Array[int], actions: Array[GameAction], is_bidirectional: bool, branch_flags: Dictionary) -> bool:
	var hit_any = false
	for next_dir in directions:
		var branch_hit = false
		for offset in instance.data.shape:
			if _resolve_recursive(instance.root_pos + offset, next_dir, actions, instance, ["机械"] as Array[String], false, branch_flags):
				branch_hit = true
		if branch_hit:
			hit_any = true
			resolution_context.turn_transmission_count += 1
			resolution_context.successful_mechanical_transmission_count += 1
			_append_tool_transmission_bonus(instance, actions)
	if hit_any and is_bidirectional:
		resolution_context.bidirectional_transmission_count += 1
	return hit_any

func _resolve_tool_extension_hook(instance: BackpackManager.ItemInstance, actions: Array[GameAction], filters: Array[String], branch_flags: Dictionary) -> bool:
	if instance == null or instance.data == null or not instance.data.get_meta("tool_extension_hook", false):
		return false
	var step = _direction_to_step(instance.data.direction)
	if step == Vector2i.ZERO:
		return false
	var hit_any = false
	for offset in instance.data.shape:
		var extended_start = instance.root_pos + offset + step
		if _resolve_recursive(extended_start, instance.data.direction, actions, instance, filters, false, branch_flags):
			hit_any = true
	return hit_any

func _append_tool_transmission_bonus(instance: BackpackManager.ItemInstance, actions: Array[GameAction]) -> void:
	if instance == null or instance.data == null:
		return
	var score := 0
	var oil_remaining = int(instance.data.get_meta("tool_transmission_oil_remaining", 0))
	if oil_remaining > 0:
		score += 3
		instance.data.set_meta("tool_transmission_oil_remaining", oil_remaining - 1)
	var calibration_remaining = int(instance.data.get_meta("orn_calibration_bonus_pending", 0))
	if calibration_remaining > 0:
		score += 5
		instance.data.set_meta("orn_calibration_bonus_pending", calibration_remaining - 1)
	if score <= 0:
		return
	var action = GameAction.new(GameAction.Type.NUMERIC, "Tool transmission bonus")
	action.item_instance = instance
	action.value = {"type": "score", "amount": score}
	actions.append(action)

func _apply_after_resolution_effects(actions: Array[GameAction]) -> void:
	for instance in resolution_context.hit_instances:
		if instance == null or instance.data == null:
			continue
		var total_multiplier = 1 + instance.current_pollution
		for effect in instance.data.effects:
			if effect.has_method("after_resolution"):
				var post_action = effect.after_resolution(instance, self, context, total_multiplier)
				if post_action:
					if post_action.item_instance == null:
						post_action.item_instance = instance
					actions.append(post_action)

func _append_resolution_summary(actions: Array[GameAction]) -> void:
	var action = GameAction.new(GameAction.Type.EFFECT, "撞击结算上下文")
	action.value = {
		"type": "impact_context_summary",
		"summary": resolution_context.to_summary(),
	}
	actions.append(action)

func _has_seen_instance(instance: BackpackManager.ItemInstance) -> bool:
	if resolution_context.has_seen(instance):
		return true
	for entry in visited:
		if entry is Dictionary and entry.get("target") == instance:
			return true
	return false

func add_pollution(instance: BackpackManager.ItemInstance, amount: int) -> void:
	if instance == null or amount <= 0:
		return
	var stage_bonus := 0
	if context != null and context.battle != null and context.battle.has_method("get_stage_pollution_added_bonus"):
		stage_bonus = int(context.battle.get_stage_pollution_added_bonus())
	amount += max(0, stage_bonus)

	var old_pollution = instance.current_pollution
	instance.add_pollution(amount)
	var added = instance.current_pollution - old_pollution
	if added <= 0:
		return

	for effect in instance.data.effects:
		if effect.has_method("on_pollution_added"):
			var action = effect.on_pollution_added(instance, added, old_pollution, self, context)
			if action:
				if action.item_instance == null:
					action.item_instance = instance
				actions_history.append(action)

func _find_next_item(pos: Vector2i, _dir: ItemData.Direction, filters: Array[String], exclude: BackpackManager.ItemInstance) -> Vector2i:
	if pos.x < 0 or pos.x >= backpack.grid_width or pos.y < 0 or pos.y >= backpack.grid_height:
		return Vector2i(-1, -1)

	if backpack.grid.has(pos):
		var found = backpack.grid[pos]
		if found != exclude:
			if filters.is_empty():
				return pos
			for tag in found.data.tags:
				if tag in filters:
					return pos

	return Vector2i(-1, -1)

func _direction_to_step(dir: ItemData.Direction) -> Vector2i:
	match dir:
		ItemData.Direction.UP:
			return Vector2i(0, -1)
		ItemData.Direction.DOWN:
			return Vector2i(0, 1)
		ItemData.Direction.LEFT:
			return Vector2i(-1, 0)
		ItemData.Direction.RIGHT:
			return Vector2i(1, 0)
	return Vector2i.ZERO

func _relative_left(dir: ItemData.Direction) -> ItemData.Direction:
	match dir:
		ItemData.Direction.UP:
			return ItemData.Direction.LEFT
		ItemData.Direction.RIGHT:
			return ItemData.Direction.UP
		ItemData.Direction.DOWN:
			return ItemData.Direction.RIGHT
		ItemData.Direction.LEFT:
			return ItemData.Direction.DOWN
	return ItemData.Direction.LEFT

func _relative_right(dir: ItemData.Direction) -> ItemData.Direction:
	match dir:
		ItemData.Direction.UP:
			return ItemData.Direction.RIGHT
		ItemData.Direction.RIGHT:
			return ItemData.Direction.DOWN
		ItemData.Direction.DOWN:
			return ItemData.Direction.LEFT
		ItemData.Direction.LEFT:
			return ItemData.Direction.UP
	return ItemData.Direction.RIGHT
