class_name RunPersistenceCodec
extends RefCounted

const SAVE_SCHEMA_VERSION := 1
const LEGACY_SCHEMA_VERSION := 0
const STATE_MARKER_KEYS := [
	"is_active",
	"shards",
	"deck",
	"backpack_items",
	"route_id",
	"act",
]


static func serialize(manager) -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
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
		"story_played_flags": manager.story_played_flags.duplicate(true),
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
	var migrated := migrate_save_data(data)
	if migrated.is_empty() or not is_save_data_compatible(migrated):
		return false
	manager.current_shards = migrated.get("shards", manager.INITIAL_SHARDS)
	manager.current_deck = _to_string_array(migrated.get("deck", manager.INITIAL_DECK))
	manager.current_backpack_items = _to_dictionary_array(migrated.get("backpack_items", []))
	manager.pending_item_rewards = _to_dictionary_array(migrated.get("pending_item_rewards", []))
	manager.next_pending_item_uid = max(int(migrated.get("next_pending_item_uid", 1)), _get_next_pending_uid_from_entries(manager.pending_item_rewards))
	manager.current_tools = _to_tool_counts(migrated.get("tools", {}))
	manager.backpack_locked_cells = _to_dictionary_array(migrated.get("backpack_locked_cells", []))
	manager.backpack_deleted_cells = _to_dictionary_array(migrated.get("backpack_deleted_cells", []))
	manager.temporary_backpack_locked_cells = _to_dictionary_array(migrated.get("temporary_backpack_locked_cells", []))
	manager.current_ornaments = _to_string_array(migrated.get("ornaments", []))
	manager.backpack_usable_width = clampi(int(migrated.get("backpack_usable_width", manager.INITIAL_BACKPACK_USABLE_WIDTH)), 1, manager.BACKPACK_GRID_WIDTH)
	manager.backpack_usable_height = clampi(int(migrated.get("backpack_usable_height", manager.INITIAL_BACKPACK_USABLE_HEIGHT)), 1, manager.BACKPACK_GRID_HEIGHT)
	manager.shop_purchase_state = _to_dictionary(migrated.get("shop_purchase_state", {}))
	manager.event_node_state = _to_dictionary(migrated.get("event_node_state", {}))
	manager.seen_event_ids = _to_string_array(migrated.get("seen_event_ids", []))
	manager.story_played_flags = _to_dictionary(migrated.get("story_played_flags", {}))
	manager._restore_random_source(int(migrated.get("rng_seed", 0)), int(migrated.get("rng_state", 0)))
	manager.current_depth = int(migrated.get("depth", 1))
	manager.current_route_id = RouteConfig.normalize_route_id(migrated.get("route_id", RouteConfig.DEFAULT_ROUTE_ID))
	manager.current_act = max(1, int(migrated.get("act", 1)))
	manager.current_route_index = clampi(int(migrated.get("route_index", 0)), 0, max(0, RouteConfig.get_route_size(manager.get_current_stage_route_id()) - 1))
	var completed_nodes: Array[int] = []
	for index in Array(migrated.get("completed_route_nodes", [])):
		completed_nodes.append(int(index))
	manager.completed_route_nodes = completed_nodes
	manager.is_run_active = bool(migrated.get("is_active", true))
	manager.is_run_complete = bool(migrated.get("is_complete", false))
	return true

static func migrate_save_data(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var migrated := data.duplicate(true)
	var schema_version := int(migrated.get("schema_version", LEGACY_SCHEMA_VERSION))
	if schema_version > SAVE_SCHEMA_VERSION:
		push_warning("[RunPersistenceCodec] Unsupported future save schema: %d." % schema_version)
		return {}
	if schema_version < LEGACY_SCHEMA_VERSION:
		push_warning("[RunPersistenceCodec] Unsupported save schema: %d." % schema_version)
		return {}
	migrated["schema_version"] = SAVE_SCHEMA_VERSION
	return migrated

static func is_save_data_compatible(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var schema_version := int(data.get("schema_version", LEGACY_SCHEMA_VERSION))
	if schema_version > SAVE_SCHEMA_VERSION:
		return false
	for key in STATE_MARKER_KEYS:
		if data.has(key):
			return true
	return false

static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for entry in Array(value):
		result.append(str(entry))
	return result

static func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in Array(value):
		if entry is Dictionary:
			result.append(Dictionary(entry).duplicate(true))
	return result

static func _to_dictionary(value: Variant) -> Dictionary:
	return Dictionary(value).duplicate(true) if value is Dictionary else {}

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
