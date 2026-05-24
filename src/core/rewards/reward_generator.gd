class_name RewardGenerator
extends RefCounted

const TYPE_SHARDS := "shards"
const TYPE_ITEM := "item"
const TYPE_ORNAMENT := "ornament"
const TYPE_TOOL := "tool"
const EconomyConfig = preload("res://src/core/rewards/economy_config.gd")
const RouteConfig = preload("res://src/core/route/route_config.gd")
const StageConfig = preload("res://src/core/stage/stage_config.gd")
const WeightedRandom = preload("res://src/core/random/weighted_random.gd")
const RARITY_WEIGHT := {
	"普通": 1,
	"进阶": 2,
	"稀有": 3,
}
const TAG_WEIGHT_STEP := 2.5

static func generate_options(run_manager: Node, item_db: Node, ornament_db: Node, count: int = 3, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if run_manager == null:
		return options
	var is_boss = run_manager.get_current_route_node_type() == RouteConfig.NODE_BOSS_BATTLE if run_manager.has_method("get_current_route_node_type") else false
	var act = max(1, int(run_manager.get("current_act")))
	var build_tags = _collect_build_tags(run_manager, item_db, ornament_db)
	var tool_db = _get_tool_db(run_manager)
	var weight_modifiers = StageConfig.get_reward_weight_modifiers(act)

	var ornament = _pick_ornament(run_manager, ornament_db, act, is_boss, build_tags, weight_modifiers, rng)
	if not ornament.is_empty():
		options.append(ornament)

	var item = _pick_item(item_db, is_boss, build_tags, weight_modifiers, rng)
	if not item.is_empty() and options.size() < count:
		options.append(item)

	if options.size() < count:
		options.append(_make_shards_reward(act, is_boss))

	var tool = _pick_tool(tool_db, weight_modifiers, rng)
	if not tool.is_empty() and options.size() < count:
		options.append(tool)

	var backup_ornaments = _pick_additional_ornaments(run_manager, ornament_db, act, is_boss, count - options.size(), options, build_tags, weight_modifiers, rng)
	for reward in backup_ornaments:
		options.append(reward)

	while options.size() < count:
		var shards = _make_shards_reward(act, is_boss)
		shards["amount"] = int(shards["amount"]) + options.size() * 2
		shards["title"] = "%d 碎片" % int(shards["amount"])
		options.append(shards)

	return options.slice(0, count)

static func _pick_item(item_db: Node, prefer_high_value: bool, build_tags: Dictionary, weight_modifiers: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	if item_db == null or not item_db.has_method("get_all_items"):
		return {}
	var items = item_db.get_all_items()
	items = items.filter(func(item): return item != null and item.can_draw)
	if rng == null:
		items.sort_custom(func(a, b): return int(a.price) > int(b.price) if prefer_high_value else int(a.price) < int(b.price))
		if items.is_empty():
			return {}
		return _make_item_reward(items[0])

	var candidates: Array[Dictionary] = []
	for item in items:
		candidates.append({
			"item": item,
			"weight": StageConfig.apply_weight_modifiers(_get_item_weight(item, prefer_high_value, build_tags), TYPE_ITEM, item.id, item.tags, "", weight_modifiers),
		})
	var picked = WeightedRandom.pick(candidates, rng)
	if picked.is_empty():
		return {}
	return _make_item_reward(picked.get("item"))

static func _make_item_reward(item) -> Dictionary:
	if item == null:
		return {}
	return {
		"type": TYPE_ITEM,
		"id": item.id,
		"title": item.item_name,
		"description": "加入卡组",
		"item_destination": "deck",
		"rarity": "",
		"amount": 1,
	}

static func _pick_tool(tool_db: Node, weight_modifiers: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	if tool_db == null or not tool_db.has_method("get_available_tools"):
		return {}
	var tools = tool_db.get_available_tools()
	if tools.is_empty():
		return {}
	if rng == null:
		tools.sort_custom(func(a, b): return int(a.price) < int(b.price) if int(a.price) != int(b.price) else a.id < b.id)
		return _make_tool_reward(tools[0])
	var candidates: Array[Dictionary] = []
	for tool in tools:
		candidates.append({"tool": tool, "weight": StageConfig.apply_weight_modifiers(_get_tool_weight(tool), TYPE_TOOL, tool.id, tool.tags, tool.rarity, weight_modifiers)})
	var picked = WeightedRandom.pick(candidates, rng)
	if picked.is_empty():
		return {}
	return _make_tool_reward(picked.get("tool"))

static func _make_tool_reward(tool) -> Dictionary:
	if tool == null:
		return {}
	return {
		"type": TYPE_TOOL,
		"id": tool.id,
		"title": tool.tool_name,
		"description": tool.effect_text,
		"rarity": tool.rarity,
		"amount": 1,
	}

static func _get_tool_weight(tool) -> float:
	match str(tool.rarity):
		"道具":
			return 7.0
		"罕见道具":
			return 4.0
		"稀有道具":
			return 2.0
	return 3.0

static func _get_item_weight(item, prefer_high_value: bool, build_tags: Dictionary) -> float:
	var price = int(item.price)
	var abs_price = abs(price)
	var weight := 8.0
	if price < 0:
		weight = 4.0
	elif price >= 10:
		weight = 7.0
	if prefer_high_value:
		weight += float(abs_price) * 0.35
	else:
		weight += max(0.0, 12.0 - float(abs_price)) * 0.25
	weight += _get_tag_affinity(item.tags, build_tags)
	if Array(item.tags).has("废弃物") and _has_build_tag(build_tags, "废弃物"):
		weight += 4.0
	if Array(item.tags).has("机械") and _has_build_tag(build_tags, "机械"):
		weight += 4.0
	return max(0.1, weight)

static func _pick_ornament(run_manager: Node, ornament_db: Node, act: int, prefer_high_value: bool, build_tags: Dictionary, weight_modifiers: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var rewards = _pick_additional_ornaments(run_manager, ornament_db, act, prefer_high_value, 1, [], build_tags, weight_modifiers, rng)
	return rewards[0] if not rewards.is_empty() else {}

static func _pick_additional_ornaments(run_manager: Node, ornament_db: Node, act: int, prefer_high_value: bool, count: int, existing: Array, build_tags: Dictionary, weight_modifiers: Dictionary, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if count <= 0 or ornament_db == null or not ornament_db.has_method("get_available_ornaments"):
		return result
	var owned: Array[String] = []
	if run_manager != null:
		for ornament_id in Array(run_manager.get("current_ornaments")):
			owned.append(str(ornament_id))
	var available = ornament_db.get_available_ornaments(act, owned)
	var existing_ids: Array[String] = []
	for reward in existing:
		if reward.get("type", "") == TYPE_ORNAMENT:
			existing_ids.append(str(reward.get("id", "")))
	available = available.filter(func(ornament): return not existing_ids.has(ornament.id))

	if rng == null:
		available.sort_custom(func(a, b): return _compare_ornaments(a, b, prefer_high_value))
		for ornament in available:
			result.append(_make_ornament_reward(ornament))
			if result.size() >= count:
				break
		return result

	var candidates: Array[Dictionary] = []
	for ornament in available:
		candidates.append({
			"ornament": ornament,
			"weight": StageConfig.apply_weight_modifiers(_get_ornament_weight(ornament, act, prefer_high_value, build_tags), TYPE_ORNAMENT, ornament.id, ornament.tags, ornament.rarity, weight_modifiers),
		})
	while result.size() < count and not candidates.is_empty():
		var index = WeightedRandom.pick_index(candidates, rng)
		if index < 0:
			break
		var picked = candidates[index]
		result.append(_make_ornament_reward(picked.get("ornament")))
		candidates.remove_at(index)
	return result

static func _get_ornament_weight(ornament, act: int, prefer_high_value: bool, build_tags: Dictionary) -> float:
	var rarity = str(ornament.rarity)
	var weight := 1.0
	match rarity:
		"普通":
			weight = 9.0
		"进阶":
			weight = 5.0
		"稀有":
			weight = 2.0
		_:
			weight = 3.0
	if rarity == "稀有" and act >= 5:
		weight += 2.0
	if rarity == "稀有" and act >= 6:
		weight += 2.0
	if prefer_high_value:
		weight += float(RARITY_WEIGHT.get(rarity, 0)) * 4.0
		weight += float(max(0, int(ornament.price))) / 40.0
	weight += _get_tag_affinity(ornament.tags, build_tags)
	return max(0.1, weight)

static func _collect_build_tags(run_manager: Node, item_db: Node, ornament_db: Node) -> Dictionary:
	var tags := {}
	if run_manager == null:
		return tags
	if item_db != null and item_db.has_method("get_item_by_id"):
		for item_id in Array(run_manager.get("current_deck")):
			_add_item_tags(tags, item_db.get_item_by_id(str(item_id)))
		for entry in Array(run_manager.get("current_backpack_items")):
			if entry is Dictionary:
				_add_item_tags(tags, item_db.get_item_by_id(str(entry.get("id", ""))))
	if ornament_db != null and ornament_db.has_method("get_ornament_by_id"):
		for ornament_id in Array(run_manager.get("current_ornaments")):
			var ornament = ornament_db.get_ornament_by_id(str(ornament_id))
			if ornament == null:
				continue
			for tag in Array(ornament.tags):
				_add_tag(tags, str(tag), 2.0)
	return tags

static func _add_item_tags(tags: Dictionary, item) -> void:
	if item == null:
		return
	for tag in Array(item.tags):
		_add_tag(tags, str(tag), 1.0)

static func _add_tag(tags: Dictionary, tag: String, amount: float) -> void:
	if tag == "" or tag == "特殊物品" or tag == "衍生物品":
		return
	tags[tag] = float(tags.get(tag, 0.0)) + amount

static func _get_tag_affinity(candidate_tags: Array, build_tags: Dictionary) -> float:
	var score := 0.0
	for tag_value in candidate_tags:
		var tag = str(tag_value)
		score += min(3.0, float(build_tags.get(tag, 0.0))) * TAG_WEIGHT_STEP
	return score

static func _has_build_tag(build_tags: Dictionary, tag: String) -> bool:
	return float(build_tags.get(tag, 0.0)) > 0.0

static func _compare_ornaments(a, b, prefer_high_value: bool) -> bool:
	var rarity_a = int(RARITY_WEIGHT.get(a.rarity, 0))
	var rarity_b = int(RARITY_WEIGHT.get(b.rarity, 0))
	if rarity_a != rarity_b:
		return rarity_a > rarity_b if prefer_high_value else rarity_a < rarity_b
	if int(a.price) != int(b.price):
		return int(a.price) > int(b.price) if prefer_high_value else int(a.price) < int(b.price)
	return a.id < b.id

static func _make_ornament_reward(ornament) -> Dictionary:
	return {
		"type": TYPE_ORNAMENT,
		"id": ornament.id,
		"title": ornament.ornament_name,
		"description": ornament.effect_text,
		"rarity": ornament.rarity,
		"amount": 1,
	}

static func _make_shards_reward(act: int, is_boss: bool) -> Dictionary:
	var amount = EconomyConfig.battle_reward_shards(act, is_boss)
	return {
		"type": TYPE_SHARDS,
		"id": "shards",
		"title": "%d 碎片" % amount,
		"description": "立即获得长期货币",
		"rarity": "",
		"amount": amount,
	}

static func _get_tool_db(run_manager: Node):
	if run_manager != null and run_manager.is_inside_tree():
		return run_manager.get_node_or_null("/root/ToolDatabase")
	return null
