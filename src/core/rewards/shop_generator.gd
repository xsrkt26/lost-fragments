class_name ShopGenerator
extends RefCounted

const TYPE_ITEM := "item"
const TYPE_ORNAMENT := "ornament"
const TYPE_TOOL := "tool"
const EconomyConfig = preload("res://src/core/rewards/economy_config.gd")
const StageConfig = preload("res://src/core/stage/stage_config.gd")
const WeightedRandom = preload("res://src/core/random/weighted_random.gd")

const TAG_WEIGHT_STEP := 2.0

static func generate_offers(run_manager: Node, item_db: Node, ornament_db: Node, count: int = 4, rng: RandomNumberGenerator = null, excluded_keys: Array = []) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var act = max(1, int(run_manager.get("current_act"))) if run_manager != null else 1
	var build_tags = _collect_build_tags(run_manager, item_db, ornament_db)
	var tool_db = _get_tool_db(run_manager)
	var weight_modifiers = StageConfig.get_shop_weight_modifiers(act)

	var items = _get_item_offers(item_db, act, count, build_tags, weight_modifiers, excluded_keys)
	var ornaments = _get_ornament_offers(run_manager, ornament_db, act, count, build_tags, weight_modifiers, excluded_keys)
	var tools = _get_tool_offers(tool_db, act, count, weight_modifiers, excluded_keys)

	_append_weighted_offer(offers, items, rng)
	_append_weighted_offer(offers, ornaments, rng)
	_append_weighted_offer(offers, tools, rng)

	var pool: Array[Dictionary] = []
	pool.append_array(items)
	pool.append_array(ornaments)
	pool.append_array(tools)
	_remove_existing_offers(pool, offers)

	while offers.size() < count and not pool.is_empty():
		_append_weighted_offer(offers, pool, rng)

	var stripped: Array[Dictionary] = []
	for offer in offers.slice(0, count):
		stripped.append(_strip_offer_metadata(offer))
	return stripped

static func calculate_refresh_cost(act: int, refresh_count: int) -> int:
	return EconomyConfig.shop_refresh_cost(act, refresh_count)

static func make_offer_key(offer: Dictionary) -> String:
	return "%s:%s" % [str(offer.get("type", "")), str(offer.get("id", ""))]

static func _get_item_offers(item_db: Node, act: int, count: int, build_tags: Dictionary, weight_modifiers: Dictionary, excluded_keys: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if item_db == null or not item_db.has_method("get_all_items"):
		return result
	var items = item_db.get_all_items()
	items = items.filter(func(item): return item != null and item.can_draw)
	for item in items:
		var offer = {
			"type": TYPE_ITEM,
			"id": item.id,
			"title": item.item_name,
			"description": "%s\n购买后暂存，整理背包时可摆放。" % item.description,
			"item_destination": "staging",
			"price": _calculate_item_price(item, act),
			"weight": StageConfig.apply_weight_modifiers(_get_item_weight(item, build_tags), TYPE_ITEM, item.id, item.tags, "", weight_modifiers),
		}
		if not excluded_keys.has(make_offer_key(offer)):
			result.append(offer)
	result.sort_custom(func(a, b): return _compare_offer_priority(a, b))
	return result.slice(0, max(count * 3, count))

static func _get_ornament_offers(run_manager: Node, ornament_db: Node, act: int, count: int, build_tags: Dictionary, weight_modifiers: Dictionary, excluded_keys: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if ornament_db == null or not ornament_db.has_method("get_available_ornaments"):
		return result
	var owned: Array[String] = []
	if run_manager != null:
		for ornament_id in Array(run_manager.get("current_ornaments")):
			owned.append(str(ornament_id))
	var ornaments = ornament_db.get_available_ornaments(act, owned)
	for ornament in ornaments:
		var offer = {
			"type": TYPE_ORNAMENT,
			"id": ornament.id,
			"title": ornament.ornament_name,
			"description": ornament.effect_text,
			"rarity": ornament.rarity,
			"price": _calculate_ornament_price(ornament, act),
			"weight": StageConfig.apply_weight_modifiers(_get_ornament_weight(ornament, act, build_tags), TYPE_ORNAMENT, ornament.id, ornament.tags, ornament.rarity, weight_modifiers),
		}
		if not excluded_keys.has(make_offer_key(offer)):
			result.append(offer)
	result.sort_custom(func(a, b): return _compare_offer_priority(a, b))
	return result.slice(0, max(count * 3, count))

static func _get_tool_offers(tool_db: Node, act: int, count: int, weight_modifiers: Dictionary, excluded_keys: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if tool_db == null or not tool_db.has_method("get_available_tools"):
		return result
	for tool in tool_db.get_available_tools():
		var offer = {
			"type": TYPE_TOOL,
			"id": tool.id,
			"title": tool.tool_name,
			"description": tool.effect_text,
			"rarity": tool.rarity,
			"price": _calculate_tool_price(tool, act),
			"amount": 1,
			"weight": StageConfig.apply_weight_modifiers(_get_tool_weight(tool), TYPE_TOOL, tool.id, tool.tags, tool.rarity, weight_modifiers),
		}
		if not excluded_keys.has(make_offer_key(offer)):
			result.append(offer)
	result.sort_custom(func(a, b): return _compare_offer_priority(a, b))
	return result.slice(0, max(count * 3, count))

static func _append_weighted_offer(offers: Array[Dictionary], candidates: Array[Dictionary], rng: RandomNumberGenerator = null) -> void:
	if candidates.is_empty():
		return
	var index := WeightedRandom.pick_index(candidates, rng)
	if index < 0:
		return
	var offer = candidates[index]
	offers.append(offer)
	candidates.remove_at(index)
	_remove_existing_offers(candidates, offers)

static func _remove_existing_offers(candidates: Array[Dictionary], offers: Array[Dictionary]) -> void:
	var keys: Array[String] = []
	for offer in offers:
		keys.append(make_offer_key(offer))
	for index in range(candidates.size() - 1, -1, -1):
		if keys.has(make_offer_key(candidates[index])):
			candidates.remove_at(index)

static func _compare_offer_priority(a: Dictionary, b: Dictionary) -> bool:
	var weight_a = float(a.get("weight", 0.0))
	var weight_b = float(b.get("weight", 0.0))
	if not is_equal_approx(weight_a, weight_b):
		return weight_a > weight_b
	var price_a = int(a.get("price", 0))
	var price_b = int(b.get("price", 0))
	if price_a != price_b:
		return price_a < price_b
	return make_offer_key(a) < make_offer_key(b)

static func _strip_offer_metadata(offer: Dictionary) -> Dictionary:
	var result = offer.duplicate(true)
	result.erase("weight")
	return result

static func _calculate_item_price(item, act: int) -> int:
	return EconomyConfig.shop_item_price(int(item.price), act)

static func _calculate_ornament_price(ornament, act: int) -> int:
	return EconomyConfig.shop_ornament_price(int(ornament.price), str(ornament.rarity), act)

static func _calculate_tool_price(tool, act: int) -> int:
	return EconomyConfig.shop_item_price(int(tool.price), act)

static func _get_item_weight(item, build_tags: Dictionary) -> float:
	var price = int(item.price)
	var weight := 7.0
	if price < 0:
		weight = 4.0
	elif price >= 10:
		weight = 6.0
	weight += _get_tag_affinity(item.tags, build_tags)
	if Array(item.tags).has("废弃物") and float(build_tags.get("废弃物", 0.0)) > 0.0:
		weight += 5.0
	if Array(item.tags).has("机械") and float(build_tags.get("机械", 0.0)) > 0.0:
		weight += 5.0
	return max(0.1, weight)

static func _get_ornament_weight(ornament, act: int, build_tags: Dictionary) -> float:
	var weight := 1.0
	match str(ornament.rarity):
		"普通":
			weight = 9.0
		"进阶":
			weight = 6.0
		"稀有":
			weight = 2.0
		_:
			weight = 4.0
	if str(ornament.rarity) == "稀有" and act >= 5:
		weight += 2.0
	if str(ornament.rarity) == "稀有" and act >= 6:
		weight += 2.0
	weight += _get_tag_affinity(ornament.tags, build_tags)
	return max(0.1, weight)

static func _get_tool_weight(tool) -> float:
	match str(tool.rarity):
		"道具":
			return 7.0
		"罕见道具":
			return 4.0
		"稀有道具":
			return 2.0
	return 3.0

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

static func _get_tool_db(run_manager: Node):
	if run_manager != null and run_manager.is_inside_tree():
		return run_manager.get_node_or_null("/root/ToolDatabase")
	return null
