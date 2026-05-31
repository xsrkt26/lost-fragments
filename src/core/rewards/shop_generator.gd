class_name ShopGenerator
extends RefCounted

const TYPE_ITEM := "item"
const TYPE_ORNAMENT := "ornament"
const TYPE_TOOL := "tool"

const TAG_WEIGHT_STEP := 2.0
const DEFAULT_OFFER_COUNT := 8
const SHOP_ITEM_COUNT := 2
const SHOP_ORNAMENT_COUNT := 4
const SHOP_TOOL_COUNT := 2

static func generate_offers(run_manager: Node, item_db: Node, ornament_db: Node, count: int = DEFAULT_OFFER_COUNT, rng: RandomNumberGenerator = null, excluded_keys: Array = []) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var act = max(1, int(run_manager.get("current_act"))) if run_manager != null else 1
	var build_tags = _collect_build_tags(run_manager, item_db, ornament_db)
	var tool_db = _get_tool_db(run_manager)
	var weight_modifiers = StageConfig.get_shop_weight_modifiers(act)

	var items = _get_item_offers(item_db, act, count, build_tags, weight_modifiers, excluded_keys)
	var ornaments = _get_ornament_offers(run_manager, ornament_db, act, count, build_tags, weight_modifiers, excluded_keys)
	var tools = _get_tool_offers(tool_db, run_manager, act, count, weight_modifiers, excluded_keys)
	var target_counts = _get_target_offer_counts(count, not tools.is_empty())

	_append_weighted_offers(offers, ornaments, int(target_counts.get(TYPE_ORNAMENT, 0)), rng)
	_append_weighted_offers(offers, tools, int(target_counts.get(TYPE_TOOL, 0)), rng)
	_append_weighted_offers(offers, items, int(target_counts.get(TYPE_ITEM, 0)), rng)

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
	var allowed_item_ids := _get_unlocked_item_ids(item_db, act)
	var items = item_db.get_all_items()
	items = items.filter(func(item): return item != null and item.can_draw and allowed_item_ids.has(str(item.id)))
	for item in items:
		var offer = {
			"type": TYPE_ITEM,
			"id": item.id,
			"title": item.item_name,
			"description": "%s\n购买后进入待放置区，可拖入背包网格。" % item.description,
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

static func _get_tool_offers(tool_db: Node, run_manager: Node, act: int, count: int, weight_modifiers: Dictionary, excluded_keys: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if tool_db == null or not tool_db.has_method("get_available_tools") or not ToolDrawPool.tools_enabled_for_route(run_manager):
		return result
	for tool in ToolDrawPool.get_available_tools(run_manager, tool_db):
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

static func _append_weighted_offers(offers: Array[Dictionary], candidates: Array[Dictionary], amount: int, rng: RandomNumberGenerator = null) -> void:
	for _i in range(max(0, amount)):
		if candidates.is_empty():
			return
		_append_weighted_offer(offers, candidates, rng)

static func _get_target_offer_counts(count: int, include_tools: bool) -> Dictionary:
	var target_count = max(0, count)
	var result := {}
	result[TYPE_ITEM] = 0
	result[TYPE_ORNAMENT] = 0
	result[TYPE_TOOL] = 0
	if target_count <= 0:
		return result

	var remaining = target_count
	result[TYPE_ORNAMENT] = min(2, remaining)
	remaining -= int(result[TYPE_ORNAMENT])
	if remaining > 0:
		result[TYPE_ITEM] = 1
		remaining -= 1
	if include_tools and remaining > 0:
		result[TYPE_TOOL] = 1
		remaining -= 1

	var fill_order = [TYPE_ORNAMENT, TYPE_TOOL, TYPE_ITEM] if include_tools else [TYPE_ORNAMENT, TYPE_ITEM]
	var caps := {}
	caps[TYPE_ITEM] = SHOP_ITEM_COUNT
	caps[TYPE_ORNAMENT] = SHOP_ORNAMENT_COUNT
	caps[TYPE_TOOL] = SHOP_TOOL_COUNT
	while remaining > 0:
		var changed := false
		for offer_type in fill_order:
			if remaining <= 0:
				break
			var current = int(result.get(offer_type, 0))
			if current >= int(caps.get(offer_type, 0)):
				continue
			result[offer_type] = current + 1
			remaining -= 1
			changed = true
		if not changed:
			break
	return result

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

static func _get_unlocked_item_ids(item_db: Node, act: int) -> Dictionary:
	var result := {}
	var by_category := ItemDrawPool.get_unlocked_items_by_category(item_db, act)
	for entries in by_category.values():
		for entry in Array(entries):
			if entry is Dictionary:
				result[str(entry.get("id", ""))] = true
	return result

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
	var price = max(1, int(item.price))
	var is_waste := Array(item.tags).has("废弃物")
	var weight := 7.0
	if is_waste:
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
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		return tree.root.get_node_or_null("ToolDatabase")
	return null
