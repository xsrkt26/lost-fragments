class_name RunPersistenceCodec
extends RefCounted


static func serialize(manager) -> Dictionary:
	return {
		"shards": manager.current_shards,
		"deck": manager.current_deck.duplicate(),
		"backpack_items": manager.current_backpack_items.duplicate(true),
		"pending_item_rewards": manager.pending_item_rewards.duplicate(true),
		"next_pending_item_uid": manager.next_pending_item_uid,
		"tools": manager.current_tools.duplicate(true),
		"backpack_locked_cells": manager.backpack_locked_cells.duplicate(true),
		"backpack_deleted_cells": manager.backpack_deleted_cells.duplicate(true),
		"temporary_backpack_locked_cells": manager.temporary_backpack_locked_cells.duplicate(true),
		"ornaments": manager.current_ornaments.duplicate(),
		"backpack_usable_width": manager.backpack_usable_width,
		"backpack_usable_height": manager.backpack_usable_height,
		"shop_purchase_state": manager.shop_purchase_state.duplicate(true),
		"event_node_state": manager.event_node_state.duplicate(true),
		"seen_event_ids": manager.seen_event_ids.duplicate(),
		"rng_seed": manager.rng_seed,
		"rng_state": manager.rng_state,
		"depth": manager.current_depth,
		"route_id": manager.current_route_id,
		"act": manager.current_act,
		"route_index": manager.current_route_index,
		"completed_route_nodes": manager.completed_route_nodes.duplicate(),
		"is_active": manager.is_run_active,
		"is_complete": manager.is_run_complete,
	}

static func deserialize_into(manager, data: Dictionary) -> bool:
	if data.is_empty():
		return false
	manager.current_shards = data.get("shards", manager.INITIAL_SHARDS)
	manager.current_deck = _to_string_array(data.get("deck", manager.INITIAL_DECK))
	manager.current_backpack_items = _to_dictionary_array(data.get("backpack_items", []))
	manager.pending_item_rewards = _to_dictionary_array(data.get("pending_item_rewards", []))
	manager.next_pending_item_uid = max(int(data.get("next_pending_item_uid", 1)), _get_next_pending_uid_from_entries(manager.pending_item_rewards))
	manager.current_tools = _to_tool_counts(data.get("tools", {}))
	manager.backpack_locked_cells = _to_dictionary_array(data.get("backpack_locked_cells", []))
	manager.backpack_deleted_cells = _to_dictionary_array(data.get("backpack_deleted_cells", []))
	manager.temporary_backpack_locked_cells = _to_dictionary_array(data.get("temporary_backpack_locked_cells", []))
	manager.current_ornaments = _to_string_array(data.get("ornaments", []))
	manager.backpack_usable_width = clampi(int(data.get("backpack_usable_width", manager.INITIAL_BACKPACK_USABLE_WIDTH)), 1, manager.BACKPACK_GRID_WIDTH)
	manager.backpack_usable_height = clampi(int(data.get("backpack_usable_height", manager.INITIAL_BACKPACK_USABLE_HEIGHT)), 1, manager.BACKPACK_GRID_HEIGHT)
	manager.shop_purchase_state = Dictionary(data.get("shop_purchase_state", {}))
	manager.event_node_state = Dictionary(data.get("event_node_state", {}))
	manager.seen_event_ids = _to_string_array(data.get("seen_event_ids", []))
	manager._restore_random_source(int(data.get("rng_seed", 0)), int(data.get("rng_state", 0)))
	manager.current_depth = data.get("depth", 1)
	manager.current_route_id = RouteConfig.normalize_route_id(data.get("route_id", RouteConfig.DEFAULT_ROUTE_ID))
	manager.current_act = max(1, int(data.get("act", 1)))
	manager.current_route_index = clampi(int(data.get("route_index", 0)), 0, max(0, RouteConfig.get_route_size(manager.get_current_stage_route_id()) - 1))
	var completed_nodes: Array[int] = []
	for index in Array(data.get("completed_route_nodes", [])):
		completed_nodes.append(int(index))
	manager.completed_route_nodes = completed_nodes
	manager.is_run_active = data.get("is_active", true)
	manager.is_run_complete = data.get("is_complete", false)
	return true

static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for entry in Array(value):
		result.append(str(entry))
	return result

static func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in Array(value):
		if entry is Dictionary:
			result.append(entry)
	return result

static func _to_tool_counts(value: Variant) -> Dictionary:
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

static func _get_next_pending_uid_from_entries(entries: Array[Dictionary]) -> int:
	var highest_uid := 0
	for entry in entries:
		highest_uid = max(highest_uid, int(entry.get("uid", 0)))
	return highest_uid + 1
