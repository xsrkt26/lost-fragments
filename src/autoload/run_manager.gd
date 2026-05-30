extends Node

## 运行管理器：单局游戏的数据源 (Source of Truth)
## 负责跨场景保存金钱、卡组、深度等核心数据。

const RouteConfig = preload("res://src/core/route/route_config.gd")
const RewardGenerator = preload("res://src/core/rewards/reward_generator.gd")
const ShopGenerator = preload("res://src/core/rewards/shop_generator.gd")
const EconomyConfig = preload("res://src/core/rewards/economy_config.gd")
const StageConfig = preload("res://src/core/stage/stage_config.gd")
const ItemDrawPool = preload("res://src/core/items/item_draw_pool.gd")
const RunPersistenceCodec = preload("res://src/core/run/run_persistence_codec.gd")
const RunRouteProgress = preload("res://src/core/run/run_route_progress.gd")
const RunRngService = preload("res://src/core/run/run_rng_service.gd")

# --- 核心信号 ---
signal run_started
signal run_finished(victory: bool)
signal shards_changed(new_amount: int)
signal deck_changed(new_deck: Array)
signal route_changed(current_act: int, route_index: int, current_node: Dictionary)
signal ornaments_changed(current_ornaments: Array[String])
signal pending_items_changed(pending_items: Array[Dictionary])
signal tools_changed(current_tools: Dictionary)

# --- 配置项 ---
const INITIAL_SHARDS = 10
const INITIAL_DECK: Array[String] = [
	"baseball", "baseball", "baseball",
	"alarm_clock", "alarm_clock", "alarm_clock",
	"tin_can", "tin_can", "tin_can",
	"mineral_water_bottle", "mineral_water_bottle", "mineral_water_bottle",
	"apple", "apple", "apple"
]
const NO_SCORE_TARGET := -1
const BACKPACK_GRID_WIDTH := 7
const BACKPACK_GRID_HEIGHT := 7
const INITIAL_BACKPACK_USABLE_WIDTH := 5
const INITIAL_BACKPACK_USABLE_HEIGHT := 5
const ROOT_DREAM_ID := "root_dream"
const ITEM_DEST_DECK := "deck"
const ITEM_DEST_BACKPACK := "backpack"
const ITEM_DEST_STAGING := "staging"
const INITIAL_BACKPACK_ITEMS: Array[Dictionary] = [
	{
		"id": ROOT_DREAM_ID,
		"x": 1,
		"y": 3,
		"direction": ItemData.Direction.RIGHT,
		"shape": [{"x": 0, "y": 0}],
		"runtime_id": -1,
	},
]

# --- 状态数据 ---
var current_shards: int = INITIAL_SHARDS
var current_deck: Array[String] = INITIAL_DECK.duplicate()
var current_backpack_items: Array[Dictionary] = []
var pending_item_rewards: Array[Dictionary] = []
var next_pending_item_uid: int = 1
var current_tools: Dictionary = {}
var backpack_locked_cells: Array[Dictionary] = []
var backpack_deleted_cells: Array[Dictionary] = []
var temporary_backpack_locked_cells: Array[Dictionary] = []
var current_ornaments: Array[String] = []
var backpack_usable_width: int = INITIAL_BACKPACK_USABLE_WIDTH
var backpack_usable_height: int = INITIAL_BACKPACK_USABLE_HEIGHT
var shop_purchase_state: Dictionary = {}
var event_node_state: Dictionary = {}
var seen_event_ids: Array[String] = []
var rng_seed: int = 0
var rng_state: int = 0
var current_depth: int = 1
var current_route_id: String = RouteConfig.DEFAULT_ROUTE_ID
var current_act: int = 1
var current_route_index: int = 0
var completed_route_nodes: Array[int] = []
var is_run_active: bool = false
var is_run_complete: bool = false

var saver: SaveManager = null
var _route_progress: RunRouteProgress = RunRouteProgress.new()
var _rng_service: RunRngService = RunRngService.new()

func _ready():
	if saver == null:
		saver = SaveManager.new()
	add_child(saver)
	# 自动尝试恢复存档
	if saver.has_save():
		deserialize_run(saver.load_run())

## 开启新的一局
func start_new_run():
	print("[RunManager] 开启新的一局...")
	
	# 重置全局战斗状态（梦值、分数等）
	var gs = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if gs:
		gs.reset_game()
	
	current_shards = INITIAL_SHARDS
	current_deck = INITIAL_DECK.duplicate()
	current_backpack_items = _get_initial_backpack_items()
	pending_item_rewards = []
	next_pending_item_uid = 1
	current_tools = {}
	backpack_locked_cells = []
	backpack_deleted_cells = []
	temporary_backpack_locked_cells = []
	current_ornaments = []
	backpack_usable_width = INITIAL_BACKPACK_USABLE_WIDTH
	backpack_usable_height = INITIAL_BACKPACK_USABLE_HEIGHT
	shop_purchase_state.clear()
	event_node_state.clear()
	seen_event_ids = []
	_initialize_random_source()
	current_depth = 1
	reset_route_progress()
	is_run_active = true
	is_run_complete = false
	
	save_current_state()
	run_started.emit()
	_emit_route_changed()

## 胜利结算
func win_battle(reward_shards: int):
	current_shards += reward_shards
	current_depth += 1
	if RouteConfig.is_battle_node_type(get_current_route_node_type()):
		_tick_temporary_backpack_locks()
	print("[RunManager] 战斗胜利! 获得碎片: ", reward_shards, " | 当前深度: ", current_depth)
	if RouteConfig.is_battle_node_type(get_current_route_node_type()):
		advance_route_node()
	shards_changed.emit(current_shards)
	save_current_state()

## 失败结算 (彻底重来)
func fail_run():
	print("[RunManager] 梦境惊醒... 运行结束。")
	is_run_active = false
	is_run_complete = false
	current_backpack_items.clear()
	if saver:
		saver.delete_save()
	run_finished.emit(false)

## 购买卡牌
func add_to_deck(item_id: String, cost: int):
	if current_shards >= cost:
		current_shards -= cost
		current_deck.append(item_id)
		print("[RunManager] 购买成功: ", item_id, " | 剩余碎片: ", current_shards)
		shards_changed.emit(current_shards)
		deck_changed.emit(current_deck)
		save_current_state()
		return true
	return false

func add_ornament(ornament_id: String, save_after: bool = true) -> bool:
	if ornament_id == "" or current_ornaments.has(ornament_id):
		return false
	current_ornaments.append(ornament_id)
	ornaments_changed.emit(current_ornaments)
	if save_after:
		save_current_state()
	return true

func has_ornament(ornament_id: String) -> bool:
	return current_ornaments.has(ornament_id)

func remove_ornament(ornament_id: String) -> bool:
	if not current_ornaments.has(ornament_id):
		return false
	current_ornaments.erase(ornament_id)
	ornaments_changed.emit(current_ornaments)
	save_current_state()
	return true

func generate_current_reward_options(item_db: Node, ornament_db: Node, count: int = 3) -> Array[Dictionary]:
	var options = RewardGenerator.generate_options(self, item_db, ornament_db, count, _get_random_source())
	_sync_random_state()
	save_current_state()
	return options

func apply_reward(reward: Dictionary, item_db: Node = null, save_after: bool = true) -> bool:
	var reward_type = str(reward.get("type", ""))
	match reward_type:
		RewardGenerator.TYPE_SHARDS:
			var amount = max(0, int(reward.get("amount", 0)))
			current_shards += amount
			shards_changed.emit(current_shards)
		RewardGenerator.TYPE_ITEM:
			var item_id = str(reward.get("id", ""))
			var destination = _get_item_destination(reward, ITEM_DEST_DECK)
			if not grant_item(item_id, destination, item_db, "reward", false):
				return false
		RewardGenerator.TYPE_ORNAMENT:
			var ornament_id = str(reward.get("id", ""))
			if not add_ornament(ornament_id, false):
				return false
		RewardGenerator.TYPE_TOOL:
			var tool_id = str(reward.get("id", ""))
			var amount = max(1, int(reward.get("amount", 1)))
			var tool_db = get_node_or_null("/root/ToolDatabase") if is_inside_tree() else null
			if not grant_tool(tool_id, amount, tool_db, "reward", false):
				return false
		_:
			return false
	if save_after:
		save_current_state()
	return true

func generate_current_shop_offers(item_db: Node, ornament_db: Node, count: int = ShopGenerator.DEFAULT_OFFER_COUNT) -> Array[Dictionary]:
	var state = _get_current_shop_state()
	var cached = _to_dictionary_array(state.get("offers", []))
	if not cached.is_empty():
		return cached
	return _generate_and_cache_current_shop_offers(item_db, ornament_db, count, state)

func refresh_current_shop_offers(item_db: Node, ornament_db: Node, count: int = ShopGenerator.DEFAULT_OFFER_COUNT) -> Array[Dictionary]:
	var state = _get_current_shop_state()
	var cost = get_current_shop_refresh_cost()
	if current_shards < cost:
		return _to_dictionary_array(state.get("offers", []))
	current_shards -= cost
	shards_changed.emit(current_shards)
	state["refresh_count"] = int(state.get("refresh_count", 0)) + 1
	state.erase("offers")
	return _generate_and_cache_current_shop_offers(item_db, ornament_db, count, state)

func get_current_shop_refresh_cost() -> int:
	var state = _get_current_shop_state()
	return ShopGenerator.calculate_refresh_cost(current_act, int(state.get("refresh_count", 0)))

func buy_shop_offer(offer: Dictionary, item_db: Node = null) -> bool:
	var price = get_current_shop_offer_price(offer)
	if current_shards < price:
		return false

	var offer_type = str(offer.get("type", ""))
	match offer_type:
		ShopGenerator.TYPE_ITEM:
			var item_id = str(offer.get("id", ""))
			if item_id == "":
				return false
			current_shards -= price
			if not grant_item(item_id, _get_item_destination(offer, ITEM_DEST_DECK), item_db, "shop", false):
				current_shards += price
				return false
		ShopGenerator.TYPE_ORNAMENT:
			var ornament_id = str(offer.get("id", ""))
			if ornament_id == "" or current_ornaments.has(ornament_id):
				return false
			current_shards -= price
			current_ornaments.append(ornament_id)
			ornaments_changed.emit(current_ornaments)
		ShopGenerator.TYPE_TOOL:
			var tool_id = str(offer.get("id", ""))
			if tool_id == "":
				return false
			var amount = max(1, int(offer.get("amount", 1)))
			var tool_db = get_node_or_null("/root/ToolDatabase") if is_inside_tree() else null
			current_shards -= price
			if not grant_tool(tool_id, amount, tool_db, "shop", false):
				current_shards += price
				return false
		_:
			return false

	shards_changed.emit(current_shards)
	_record_shop_purchase(offer)
	save_current_state()
	return true

func sell_backpack_item(runtime_id: int, item_db: Node = null) -> int:
	if runtime_id == -1:
		return 0
	if item_db == null and is_inside_tree():
		item_db = get_node_or_null("/root/ItemDatabase")
	for index in range(current_backpack_items.size() - 1, -1, -1):
		var entry: Dictionary = current_backpack_items[index]
		if not (entry is Dictionary) or int(entry.get("runtime_id", 0)) != runtime_id:
			continue
		var item_id: String = str(entry.get("id", ""))
		if item_id == ROOT_DREAM_ID or item_id == "":
			return 0
		var item_data = item_db.get_item_by_id(item_id) if item_db != null and item_db.has_method("get_item_by_id") else null
		var base_price: int = int(item_data.price) if item_data != null else max(1, int(entry.get("price", 1)))
		var sell_value: int = EconomyConfig.shop_item_sell_value(base_price, current_act)
		current_backpack_items.remove_at(index)
		current_shards += sell_value
		shards_changed.emit(current_shards)
		save_current_state()
		return sell_value
	return 0

func grant_tool(tool_id: String, amount: int = 1, tool_db: Node = null, source: String = "", save_after: bool = true) -> bool:
	if tool_id == "" or amount <= 0:
		return false
	if tool_db == null and is_inside_tree():
		tool_db = get_node_or_null("/root/ToolDatabase")
	if tool_db != null and tool_db.has_method("get_tool_by_id") and tool_db.get_tool_by_id(tool_id) == null:
		return false
	current_tools[tool_id] = max(0, int(current_tools.get(tool_id, 0))) + amount
	tools_changed.emit(get_current_tools())
	if save_after:
		save_current_state()
	return true

func consume_tool(tool_id: String, amount: int = 1, save_after: bool = true) -> bool:
	if tool_id == "" or amount <= 0:
		return false
	var current_count = int(current_tools.get(tool_id, 0))
	if current_count < amount:
		return false
	var next_count = current_count - amount
	if next_count <= 0:
		current_tools.erase(tool_id)
	else:
		current_tools[tool_id] = next_count
	tools_changed.emit(get_current_tools())
	if save_after:
		save_current_state()
	return true

func get_tool_count(tool_id: String) -> int:
	return max(0, int(current_tools.get(tool_id, 0)))

func get_current_tools() -> Dictionary:
	return current_tools.duplicate(true)

func get_tool_inventory_entries(tool_db: Node = null) -> Array[Dictionary]:
	if tool_db == null and is_inside_tree():
		tool_db = get_node_or_null("/root/ToolDatabase")
	var result: Array[Dictionary] = []
	for tool_id in current_tools.keys():
		var count = int(current_tools.get(tool_id, 0))
		if count <= 0:
			continue
		var entry: Dictionary = {
			"id": str(tool_id),
			"count": count,
			"title": str(tool_id),
			"description": "",
			"rarity": "",
			"target_type": "",
		}
		if tool_db != null and tool_db.has_method("get_tool_by_id"):
			var tool = tool_db.get_tool_by_id(str(tool_id))
			if tool != null:
				entry["title"] = tool.tool_name
				entry["description"] = tool.effect_text
				entry["rarity"] = tool.rarity
				entry["target_type"] = tool.target_type
		result.append(entry)
	result.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return result

func grant_item(item_id: String, destination: String = ITEM_DEST_DECK, item_db: Node = null, source: String = "", save_after: bool = true) -> bool:
	if item_id == "":
		return false
	var normalized_destination = _normalize_item_destination(destination)
	match normalized_destination:
		ITEM_DEST_DECK:
			current_deck.append(item_id)
			deck_changed.emit(current_deck)
		ITEM_DEST_BACKPACK:
			if not _try_add_item_to_backpack_state(item_id, item_db):
				_add_pending_item_reward(item_id, source, ITEM_DEST_BACKPACK, false)
		ITEM_DEST_STAGING:
			_add_pending_item_reward(item_id, source, ITEM_DEST_STAGING, false)
		_:
			return false
	if save_after:
		save_current_state()
	return true

func get_pending_item_rewards() -> Array[Dictionary]:
	return pending_item_rewards.duplicate(true)

func consume_pending_item(uid: int, save_after: bool = true) -> bool:
	for index in pending_item_rewards.size():
		if int(pending_item_rewards[index].get("uid", -1)) == uid:
			pending_item_rewards.remove_at(index)
			pending_items_changed.emit(get_pending_item_rewards())
			if save_after:
				save_current_state()
			return true
	return false

func move_pending_item_to_deck(uid: int) -> bool:
	var entry = _get_pending_item(uid)
	if entry.is_empty():
		return false
	if not consume_pending_item(uid, false):
		return false
	current_deck.append(str(entry.get("id", "")))
	deck_changed.emit(current_deck)
	save_current_state()
	return true

func place_pending_item_in_backpack(uid: int, item_db: Node) -> bool:
	var entry = _get_pending_item(uid)
	if entry.is_empty():
		return false
	if not _try_add_item_to_backpack_state(str(entry.get("id", "")), item_db):
		return false
	return consume_pending_item(uid)

func _get_pending_item(uid: int) -> Dictionary:
	for entry in pending_item_rewards:
		if int(entry.get("uid", -1)) == uid:
			return entry.duplicate(true)
	return {}

func _add_pending_item_reward(item_id: String, source: String, preferred_destination: String, save_after: bool = true) -> Dictionary:
	var entry = {
		"uid": next_pending_item_uid,
		"id": item_id,
		"source": source,
		"preferred_destination": preferred_destination,
	}
	next_pending_item_uid += 1
	pending_item_rewards.append(entry)
	pending_items_changed.emit(get_pending_item_rewards())
	if save_after:
		save_current_state()
	return entry

func _try_add_item_to_backpack_state(item_id: String, item_db: Node) -> bool:
	if item_db == null or not item_db.has_method("get_item_by_id"):
		return false
	var item_data = item_db.get_item_by_id(item_id)
	if item_data == null:
		return false

	var backpack = BackpackManager.new()
	backpack.setup_grid(BACKPACK_GRID_WIDTH, BACKPACK_GRID_HEIGHT, backpack_usable_width, backpack_usable_height)
	backpack.set_blocked_cells(_to_vector2i_cells(_get_all_blocked_backpack_cells()))
	restore_backpack_state(backpack, item_db)
	var target_pos = backpack.find_available_pos(item_data)
	if target_pos == Vector2i(-1, -1):
		backpack.free()
		return false
	if not backpack.place_item(item_data, target_pos):
		backpack.free()
		return false
	save_backpack_state(backpack)
	backpack.free()
	return true

func _get_item_destination(source_data: Dictionary, fallback: String) -> String:
	return _normalize_item_destination(str(source_data.get("item_destination", source_data.get("destination", fallback))))

func _normalize_item_destination(destination: String) -> String:
	match destination:
		ITEM_DEST_DECK, ITEM_DEST_BACKPACK, ITEM_DEST_STAGING:
			return destination
	return ITEM_DEST_DECK

func get_current_shop_offer_price(offer: Dictionary) -> int:
	var price = max(1, int(offer.get("price", 0)))
	if str(offer.get("type", "")) != ShopGenerator.TYPE_ITEM:
		return price
	if not current_ornaments.has("recycling_coupon"):
		return price
	var state = _get_current_shop_state()
	if bool(state.get("discount_next_item", false)):
		return max(1, floori(float(price) * 0.8))
	return price

func _record_shop_purchase(offer: Dictionary) -> void:
	var key = _get_current_shop_state_key()
	var state = _get_current_shop_state()
	var purchased_keys = _to_string_array(state.get("purchased_offer_keys", []))
	var offer_key = ShopGenerator.make_offer_key(offer)
	if offer_key != ":" and not purchased_keys.has(offer_key):
		purchased_keys.append(offer_key)
	state["purchased_offer_keys"] = purchased_keys
	if current_ornaments.has("recycling_coupon") and str(offer.get("type", "")) == ShopGenerator.TYPE_ITEM:
		if bool(state.get("discount_next_item", false)):
			state["discount_next_item"] = false
		elif not bool(state.get("first_item_purchase_done", false)):
			state["first_item_purchase_done"] = true
			state["discount_next_item"] = true
	shop_purchase_state[key] = state

func _get_current_shop_state() -> Dictionary:
	return Dictionary(shop_purchase_state.get(_get_current_shop_state_key(), {}))

func _get_current_shop_state_key() -> String:
	return "%d:%d" % [current_act, current_route_index]

func _generate_and_cache_current_shop_offers(item_db: Node, ornament_db: Node, count: int, state: Dictionary) -> Array[Dictionary]:
	var excluded_keys = _to_string_array(state.get("purchased_offer_keys", []))
	var offers = ShopGenerator.generate_offers(self, item_db, ornament_db, count, _get_random_source(), excluded_keys)
	_sync_random_state()
	state["offers"] = offers
	shop_purchase_state[_get_current_shop_state_key()] = state
	save_current_state()
	return offers

func pick_current_event(event_db: Node):
	if event_db == null or not event_db.has_method("pick_event_for_run"):
		return null
	var key = _get_current_node_state_key()
	var state = Dictionary(event_node_state.get(key, {}))
	var event_id = str(state.get("event_id", ""))
	if event_id != "" and event_db.has_method("get_event_by_id"):
		var cached_event = event_db.get_event_by_id(event_id)
		if cached_event != null:
			return cached_event
	var event_data = event_db.pick_event_for_run(self, _get_random_source())
	_sync_random_state()
	if event_data != null:
		state["event_id"] = event_data.id
		event_node_state[key] = state
	save_current_state()
	return event_data

func _get_current_node_state_key() -> String:
	return "%d:%d" % [current_act, current_route_index]

func apply_event_choice(choice: Dictionary) -> bool:
	var cost_shards = max(0, int(choice.get("cost_shards", 0)))
	if current_shards < cost_shards:
		return false

	var effects = _to_dictionary_array(choice.get("effects", []))
	if effects.is_empty():
		return false

	var snapshot = {
		"shards": current_shards,
		"deck": current_deck.duplicate(),
		"backpack_items": current_backpack_items.duplicate(true),
		"pending_item_rewards": pending_item_rewards.duplicate(true),
		"next_pending_item_uid": next_pending_item_uid,
		"tools": current_tools.duplicate(true),
		"backpack_locked_cells": backpack_locked_cells.duplicate(true),
		"backpack_deleted_cells": backpack_deleted_cells.duplicate(true),
		"temporary_backpack_locked_cells": temporary_backpack_locked_cells.duplicate(true),
		"ornaments": current_ornaments.duplicate(),
		"backpack_width": backpack_usable_width,
		"backpack_height": backpack_usable_height,
	}

	current_shards -= cost_shards
	if cost_shards > 0:
		shards_changed.emit(current_shards)

	for effect in effects:
		if not _apply_event_effect(effect):
			_restore_event_snapshot(snapshot)
			return false

	var event_id = str(choice.get("event_id", choice.get("_event_id", "")))
	if event_id != "" and not seen_event_ids.has(event_id):
		seen_event_ids.append(event_id)
	save_current_state()
	return true

func get_backpack_grid_config() -> Dictionary:
	var stage_modifiers = get_current_battle_modifiers()
	var blocked_cells = _merge_cell_arrays(_get_all_blocked_backpack_cells(), Array(stage_modifiers.get("blocked_cells", [])))
	return {
		"grid_width": BACKPACK_GRID_WIDTH,
		"grid_height": BACKPACK_GRID_HEIGHT,
		"usable_width": clampi(backpack_usable_width, 1, BACKPACK_GRID_WIDTH),
		"usable_height": clampi(backpack_usable_height, 1, BACKPACK_GRID_HEIGHT),
		"blocked_cells": blocked_cells,
	}

func _apply_event_effect(effect: Dictionary) -> bool:
	var effect_type = str(effect.get("type", ""))
	match effect_type:
		RewardGenerator.TYPE_SHARDS, RewardGenerator.TYPE_ITEM, RewardGenerator.TYPE_ORNAMENT, RewardGenerator.TYPE_TOOL:
			var item_db = get_node_or_null("/root/ItemDatabase") if is_inside_tree() else null
			return apply_reward(effect, item_db, false)
		"sanity":
			var amount = int(effect.get("amount", 0))
			if amount == 0:
				return false
			var gs = get_node_or_null("/root/GameState") if is_inside_tree() else null
			if gs == null or not gs.has_method("heal_sanity"):
				return false
			gs.heal_sanity(amount)
			return true
		"backpack_space":
			var width_delta = int(effect.get("width_delta", 0))
			var height_delta = int(effect.get("height_delta", 0))
			var next_width = clampi(backpack_usable_width + width_delta, INITIAL_BACKPACK_USABLE_WIDTH, BACKPACK_GRID_WIDTH)
			var next_height = clampi(backpack_usable_height + height_delta, INITIAL_BACKPACK_USABLE_HEIGHT, BACKPACK_GRID_HEIGHT)
			if next_width == backpack_usable_width and next_height == backpack_usable_height:
				return false
			backpack_usable_width = next_width
			backpack_usable_height = next_height
			return true
		"backpack_lock_cells", "backpack_delete_cells", "backpack_temp_lock_cells", "backpack_force_move":
			return _apply_backpack_cell_effect(effect)
	return false

func _apply_backpack_cell_effect(effect: Dictionary) -> bool:
	var effect_type = str(effect.get("type", ""))
	var cells = _normalize_cell_array(effect.get("cells", []))
	if cells.is_empty() or not _are_cells_in_physical_grid(cells):
		return false

	if effect_type == "backpack_force_move":
		var moved_items = _move_items_out_of_cells(cells, _get_all_blocked_backpack_cells(), true)
		if not (moved_items is Array):
			return false
		current_backpack_items = moved_items
		return true

	var next_locked = backpack_locked_cells.duplicate(true)
	var next_deleted = backpack_deleted_cells.duplicate(true)
	var next_temporary = temporary_backpack_locked_cells.duplicate(true)
	match effect_type:
		"backpack_lock_cells":
			next_locked = _merge_cell_arrays(next_locked, cells)
		"backpack_delete_cells":
			next_deleted = _merge_cell_arrays(next_deleted, cells)
		"backpack_temp_lock_cells":
			var duration = max(1, int(effect.get("duration_battles", 1)))
			var temp_cells: Array[Dictionary] = []
			for cell in cells:
				var entry = cell.duplicate(true)
				entry["remaining_battles"] = duration
				temp_cells.append(entry)
			next_temporary = _merge_cell_arrays(next_temporary, temp_cells)
		_:
			return false

	var next_blocked = _merge_cell_arrays(_merge_cell_arrays(next_locked, next_deleted), next_temporary)
	var moved = _move_items_out_of_cells(next_blocked, next_blocked, bool(effect.get("force_move", true)))
	if not (moved is Array):
		return false
	backpack_locked_cells = next_locked
	backpack_deleted_cells = next_deleted
	temporary_backpack_locked_cells = next_temporary
	current_backpack_items = moved
	return true

func _move_items_out_of_cells(trigger_cells: Array[Dictionary], blocked_cells: Array[Dictionary], force_move: bool):
	var trigger_lookup = _cell_lookup(trigger_cells)
	var blocked_lookup = _cell_lookup(blocked_cells)
	var unaffected: Array[Dictionary] = []
	var affected: Array[Dictionary] = []
	var occupied := {}
	for entry in current_backpack_items:
		if _entry_overlaps_lookup(entry, trigger_lookup):
			affected.append(entry.duplicate(true))
		else:
			var kept = entry.duplicate(true)
			unaffected.append(kept)
			_add_entry_cells_to_lookup(occupied, kept)
	if affected.is_empty():
		return current_backpack_items.duplicate(true)
	if not force_move:
		return null
	var result = unaffected.duplicate(true)
	for entry in affected:
		var next_pos = _find_available_root_for_entry(entry, blocked_lookup, occupied)
		if next_pos == Vector2i(-1, -1):
			return null
		entry["x"] = next_pos.x
		entry["y"] = next_pos.y
		result.append(entry)
		_add_entry_cells_to_lookup(occupied, entry)
	return result

func _find_available_root_for_entry(entry: Dictionary, blocked_lookup: Dictionary, occupied_lookup: Dictionary) -> Vector2i:
	for y in range(BACKPACK_GRID_HEIGHT):
		for x in range(BACKPACK_GRID_WIDTH):
			var root = Vector2i(x, y)
			if _can_entry_fit_at(entry, root, blocked_lookup, occupied_lookup):
				return root
	return Vector2i(-1, -1)

func _can_entry_fit_at(entry: Dictionary, root: Vector2i, blocked_lookup: Dictionary, occupied_lookup: Dictionary) -> bool:
	for offset in _entry_shape(entry):
		var cell = root + offset
		if cell.x < 0 or cell.x >= BACKPACK_GRID_WIDTH or cell.y < 0 or cell.y >= BACKPACK_GRID_HEIGHT:
			return false
		if not _is_cell_in_usable_rect(cell):
			return false
		var key = _cell_key(cell)
		if blocked_lookup.has(key) or occupied_lookup.has(key):
			return false
	return true

func _entry_overlaps_lookup(entry: Dictionary, lookup: Dictionary) -> bool:
	var root = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	for offset in _entry_shape(entry):
		if lookup.has(_cell_key(root + offset)):
			return true
	return false

func _add_entry_cells_to_lookup(lookup: Dictionary, entry: Dictionary) -> void:
	var root = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	for offset in _entry_shape(entry):
		lookup[_cell_key(root + offset)] = true

func _entry_shape(entry: Dictionary) -> Array[Vector2i]:
	var fallback: Array[Vector2i] = [Vector2i.ZERO]
	return _deserialize_shape(Array(entry.get("shape", [])), fallback)

func _is_cell_in_usable_rect(cell: Vector2i) -> bool:
	var width = clampi(backpack_usable_width, 1, BACKPACK_GRID_WIDTH)
	var height = clampi(backpack_usable_height, 1, BACKPACK_GRID_HEIGHT)
	var start_x = floori((BACKPACK_GRID_WIDTH - width) / 2.0)
	var start_y = floori((BACKPACK_GRID_HEIGHT - height) / 2.0)
	return cell.x >= start_x and cell.x < start_x + width and cell.y >= start_y and cell.y < start_y + height

func _normalize_cell_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in Array(value):
		if entry is Vector2i:
			result.append({"x": entry.x, "y": entry.y})
		elif entry is Dictionary:
			result.append({"x": int(entry.get("x", 0)), "y": int(entry.get("y", 0))})
	return _unique_cells(result)

func _are_cells_in_physical_grid(cells: Array[Dictionary]) -> bool:
	for cell in cells:
		var pos = Vector2i(int(cell.get("x", -1)), int(cell.get("y", -1)))
		if pos.x < 0 or pos.x >= BACKPACK_GRID_WIDTH or pos.y < 0 or pos.y >= BACKPACK_GRID_HEIGHT:
			return false
	return true

func _merge_cell_arrays(a: Variant, b: Variant) -> Array[Dictionary]:
	var merged: Array[Dictionary] = []
	merged.append_array(_normalize_cell_array(a))
	merged.append_array(_normalize_cell_array(b))
	return _unique_cells(merged)

func _unique_cells(cells: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	for cell in cells:
		var normalized = {"x": int(cell.get("x", 0)), "y": int(cell.get("y", 0))}
		if cell.has("remaining_battles"):
			normalized["remaining_battles"] = int(cell.get("remaining_battles", 1))
		var key = "%d:%d" % [int(normalized.get("x", 0)), int(normalized.get("y", 0))]
		if seen.has(key):
			continue
		seen[key] = true
		result.append(normalized)
	return result

func _cell_lookup(cells: Array[Dictionary]) -> Dictionary:
	var lookup := {}
	for cell in cells:
		lookup[_cell_key(Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0))))] = true
	return lookup

func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func _get_all_blocked_backpack_cells() -> Array[Dictionary]:
	return _merge_cell_arrays(_merge_cell_arrays(backpack_locked_cells, backpack_deleted_cells), temporary_backpack_locked_cells)

func _to_vector2i_cells(cells: Array[Dictionary]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0))))
	return result

func _tick_temporary_backpack_locks() -> void:
	var next_cells: Array[Dictionary] = []
	for cell in temporary_backpack_locked_cells:
		var remaining = int(cell.get("remaining_battles", 1)) - 1
		if remaining > 0:
			next_cells.append({
				"x": int(cell.get("x", 0)),
				"y": int(cell.get("y", 0)),
				"remaining_battles": remaining,
			})
	temporary_backpack_locked_cells = next_cells

func _restore_event_snapshot(snapshot: Dictionary) -> void:
	current_shards = int(snapshot.get("shards", current_shards))
	current_deck = _to_string_array(snapshot.get("deck", current_deck))
	current_backpack_items = _to_dictionary_array(snapshot.get("backpack_items", current_backpack_items))
	pending_item_rewards = _to_dictionary_array(snapshot.get("pending_item_rewards", pending_item_rewards))
	next_pending_item_uid = int(snapshot.get("next_pending_item_uid", next_pending_item_uid))
	current_tools = _to_tool_counts(snapshot.get("tools", current_tools))
	backpack_locked_cells = _to_dictionary_array(snapshot.get("backpack_locked_cells", backpack_locked_cells))
	backpack_deleted_cells = _to_dictionary_array(snapshot.get("backpack_deleted_cells", backpack_deleted_cells))
	temporary_backpack_locked_cells = _to_dictionary_array(snapshot.get("temporary_backpack_locked_cells", temporary_backpack_locked_cells))
	current_ornaments = _to_string_array(snapshot.get("ornaments", current_ornaments))
	backpack_usable_width = int(snapshot.get("backpack_width", backpack_usable_width))
	backpack_usable_height = int(snapshot.get("backpack_height", backpack_usable_height))
	shards_changed.emit(current_shards)
	deck_changed.emit(current_deck)
	ornaments_changed.emit(current_ornaments)
	pending_items_changed.emit(get_pending_item_rewards())
	tools_changed.emit(get_current_tools())
	save_current_state()

func save_backpack_state(backpack: BackpackManager) -> void:
	current_backpack_items.clear()
	if backpack == null:
		return
	for instance in backpack.get_all_instances():
		if _is_derived_item(instance):
			continue
		current_backpack_items.append(_serialize_backpack_instance(instance))
	save_current_state()

func restore_backpack_state(backpack: BackpackManager, item_db: Node) -> void:
	if backpack == null:
		return
	backpack.grid.clear()
	if item_db == null:
		return
	for entry in current_backpack_items:
		var item_id = str(entry.get("id", ""))
		var item_data = item_db.get_item_by_id(item_id) if item_db.has_method("get_item_by_id") else null
		if item_data == null:
			continue
		var runtime_data: ItemData = item_data.duplicate(true)
		runtime_data.runtime_id = int(entry.get("runtime_id", randi()))
		runtime_data.direction = int(entry.get("direction", runtime_data.direction))
		runtime_data.shape = _deserialize_shape(Array(entry.get("shape", [])), runtime_data.shape)
		var root_pos = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		if not backpack.place_item(runtime_data, root_pos, true):
			push_warning("[RunManager] Failed to restore backpack item '%s' at %s." % [item_id, root_pos])
	_ensure_required_backpack_items(backpack, item_db)

func _serialize_backpack_instance(instance: BackpackManager.ItemInstance) -> Dictionary:
	return {
		"id": instance.data.id,
		"x": instance.root_pos.x,
		"y": instance.root_pos.y,
		"direction": int(instance.data.direction),
		"shape": _serialize_shape(instance.data.shape),
		"runtime_id": instance.data.runtime_id
	}

func _serialize_shape(shape: Array[Vector2i]) -> Array:
	var result = []
	for cell in shape:
		result.append({"x": cell.x, "y": cell.y})
	return result

func _deserialize_shape(value: Array, fallback: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in value:
		if cell is Dictionary:
			result.append(Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0))))
	if result.is_empty():
		return fallback
	return result

func _get_initial_backpack_items() -> Array[Dictionary]:
	return _to_dictionary_array(INITIAL_BACKPACK_ITEMS).duplicate(true)

func _ensure_required_backpack_items(backpack: BackpackManager, item_db: Node) -> void:
	if _backpack_has_item(backpack, ROOT_DREAM_ID):
		return
	for entry in INITIAL_BACKPACK_ITEMS:
		if str(entry.get("id", "")) == ROOT_DREAM_ID:
			_place_required_backpack_item(backpack, item_db, entry)
			return

func _backpack_has_item(backpack: BackpackManager, item_id: String) -> bool:
	if backpack == null:
		return false
	for instance in backpack.get_all_instances():
		if instance != null and instance.data != null and instance.data.id == item_id:
			return true
	return false

func _place_required_backpack_item(backpack: BackpackManager, item_db: Node, entry: Dictionary) -> bool:
	var item_id = str(entry.get("id", ""))
	var item_data = item_db.get_item_by_id(item_id) if item_db != null and item_db.has_method("get_item_by_id") else null
	if item_data == null:
		return false

	var runtime_data: ItemData = item_data.duplicate(true)
	runtime_data.direction = int(entry.get("direction", runtime_data.direction))
	runtime_data.shape = _deserialize_shape(Array(entry.get("shape", [])), runtime_data.shape)

	var root_pos = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	if backpack.can_place_item(runtime_data, root_pos):
		return backpack.place_item(runtime_data, root_pos)

	var fallback_pos = backpack.find_available_pos(runtime_data)
	if fallback_pos != Vector2i(-1, -1):
		return backpack.place_item(runtime_data, fallback_pos)
	return false

func _is_derived_item(instance: BackpackManager.ItemInstance) -> bool:
	return instance != null and instance.data != null and instance.data.tags.has("衍生物品")

func reset_route_progress(route_id: String = RouteConfig.DEFAULT_ROUTE_ID):
	_route_progress.reset_route_progress(self, route_id)
	_emit_route_changed()

func get_current_stage_route_id() -> String:
	return _route_progress.get_current_stage_route_id(self)

func get_current_stage_config() -> Dictionary:
	return _route_progress.get_current_stage_config(self)

func get_current_stage_visual() -> Dictionary:
	return _route_progress.get_current_stage_visual(self)

func get_current_battle_modifiers() -> Dictionary:
	return _route_progress.get_current_battle_modifiers(self)

func get_route_nodes() -> Array:
	return _route_progress.get_route_nodes(self)

func get_current_route_node() -> Dictionary:
	return _route_progress.get_current_route_node(self)

func get_current_route_node_type() -> String:
	return _route_progress.get_current_route_node_type(self)

func can_enter_route_node(index: int) -> bool:
	return _route_progress.can_enter_route_node(self, index)

func get_scene_type_for_node(node: Dictionary) -> int:
	return _route_progress.get_scene_type_for_node(node)

func get_current_node_scene_type() -> int:
	return _route_progress.get_current_node_scene_type(self)

func get_current_battle_config() -> Dictionary:
	return _route_progress.get_current_battle_config(self)

func current_battle_has_score_target() -> bool:
	return _route_progress.current_battle_has_score_target(self)

func get_current_battle_target_score() -> int:
	return _route_progress.get_current_battle_target_score(self)

func is_current_battle_score_success(score: int) -> bool:
	return _route_progress.is_current_battle_score_success(self, score)

func has_empty_dream_trophy_reward_bonus(score: int) -> bool:
	return _route_progress.has_empty_dream_trophy_reward_bonus(self, score)

func _get_boss_target_score() -> int:
	return _route_progress.get_boss_target_score(self)

func advance_route_node(expected_node_id: String = "") -> Dictionary:
	return _route_progress.advance_route_node(self, expected_node_id)

func _complete_run() -> void:
	print("[RunManager] 已完成全部 ", StageConfig.get_max_act(), " 个场景，整局胜利。")
	is_run_active = false
	is_run_complete = true
	current_act = StageConfig.get_max_act()
	current_route_index = max(0, RouteConfig.get_route_size(get_current_stage_route_id()) - 1)
	completed_route_nodes = []
	if saver:
		saver.delete_save()
	run_finished.emit(true)

func _emit_route_changed():
	route_changed.emit(current_act, current_route_index, get_current_route_node())

## 存档序列化
func save_current_state():
	if not is_run_active: return
	if saver:
		saver.save_run(serialize_run())

func serialize_run() -> Dictionary:
	return RunPersistenceCodec.serialize(self)

func deserialize_run(data: Dictionary):
	if not RunPersistenceCodec.deserialize_into(self, data):
		return
	pending_items_changed.emit(get_pending_item_rewards())
	tools_changed.emit(get_current_tools())
	_emit_route_changed()

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for entry in Array(value):
		result.append(str(entry))
	return result

func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in Array(value):
		if entry is Dictionary:
			result.append(entry)
	return result

func _to_tool_counts(value: Variant) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for key in value.keys():
			var count = int(value.get(key, 0))
			if count > 0:
				result[str(key)] = count
	elif value is Array:
		for entry in Array(value):
			if entry is Dictionary:
				var tool_id = str(entry.get("id", ""))
				var count = int(entry.get("count", entry.get("amount", 0)))
				if tool_id != "" and count > 0:
					result[tool_id] = int(result.get(tool_id, 0)) + count
	return result

func _get_next_pending_uid_from_entries() -> int:
	var highest_uid := 0
	for entry in pending_item_rewards:
		highest_uid = max(highest_uid, int(entry.get("uid", 0)))
	return highest_uid + 1

func set_random_seed(seed_value: int) -> void:
	_initialize_random_source(seed_value)

func _initialize_random_source(seed_value: int = 0) -> void:
	_rng_service.set_seed(seed_value)
	_sync_random_state()

func _restore_random_source(seed_value: int, state_value: int) -> void:
	_rng_service.restore(seed_value, state_value)
	_sync_random_state()

func _get_random_source() -> RandomNumberGenerator:
	return _get_random_service().get_rng()

func _get_random_service() -> RunRngService:
	if rng_seed == 0:
		_initialize_random_source()
	else:
		_rng_service.restore(rng_seed, rng_state)
	return _rng_service

func _sync_random_state() -> void:
	var serialized_rng := _rng_service.serialize()
	rng_seed = int(serialized_rng.get("rng_seed", 0))
	rng_state = int(serialized_rng.get("rng_state", 0))

func random_float_for_run(save_after: bool = false) -> float:
	var value := _get_random_service().randf_for_run()
	_sync_random_state()
	if save_after:
		save_current_state()
	return value

func random_int_for_run(max_exclusive: int, save_after: bool = false) -> int:
	if max_exclusive <= 0:
		return 0
	var value := _get_random_service().randi_index(max_exclusive)
	_sync_random_state()
	if save_after:
		save_current_state()
	return value

func shuffle_array_for_run(values: Array, save_after: bool = false) -> Array:
	var result := _get_random_service().shuffle(values)
	_sync_random_state()
	if save_after:
		save_current_state()
	return result

func draw_item_id_for_current_act(item_db: Node, save_after: bool = true) -> String:
	var item_id := ItemDrawPool.draw_item_id(self, item_db)
	_sync_random_state()
	if save_after:
		save_current_state()
	return item_id

func build_current_draw_deck(item_db: Node, draw_count: int = ItemDrawPool.DEFAULT_DECK_SIZE, save_after: bool = true) -> Array[String]:
	var result := ItemDrawPool.build_deck(self, item_db, draw_count)
	_sync_random_state()
	if save_after:
		save_current_state()
	return result

## 获取当前战斗的目标分数。无分数目标时返回 NO_SCORE_TARGET。
func get_target_score() -> int:
	return get_current_battle_target_score()
