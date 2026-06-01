extends GutTest

const EventDatabaseScript = preload("res://src/autoload/event_database.gd")
const RunManagerScript = preload("res://src/autoload/run_manager.gd")
const BattleManagerScript = preload("res://src/battle/battle_manager.gd")

var event_db
var item_db

func before_each():
	event_db = get_node_or_null("/root/EventDatabase")
	if event_db == null:
		event_db = autofree(EventDatabaseScript.new())
	if event_db.events.is_empty():
		event_db.load_all_events()
	item_db = get_node_or_null("/root/ItemDatabase")
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()

func _make_run_manager(act: int = 1, route_index: int = 2):
	var rm = autofree(RunManagerScript.new())
	rm.current_act = act
	rm.current_route_index = route_index
	rm.current_shards = 20
	rm.current_deck = [] as Array[String]
	rm.current_ornaments = [] as Array[String]
	rm.backpack_usable_width = RunManagerScript.INITIAL_BACKPACK_USABLE_WIDTH
	rm.backpack_usable_height = RunManagerScript.INITIAL_BACKPACK_USABLE_HEIGHT
	rm.is_run_active = true
	return rm

func test_event_database_loads_events_and_filters_by_act():
	var all_events = event_db.get_all_events()
	var act_one = event_db.get_available_events(1)
	var act_two = event_db.get_available_events(2)
	var act_six = event_db.get_available_events(6)
	var act_one_ids = act_one.map(func(event_data): return event_data.id)
	var act_two_ids = act_two.map(func(event_data): return event_data.id)
	var act_six_ids = act_six.map(func(event_data): return event_data.id)

	assert_true(all_events.size() >= 4)
	assert_true(act_one_ids.has("forgotten_cache"))
	assert_false(act_one_ids.has("loose_straps"))
	assert_true(act_two_ids.has("loose_straps"))
	assert_true(act_two_ids.has("polluted_drain"))
	assert_true(act_six_ids.has("final_supply_cache"))

func test_pick_event_for_run_is_deterministic():
	var rm = _make_run_manager(1, 2)

	var first_pick = event_db.pick_event_for_run(rm)
	var second_pick = event_db.pick_event_for_run(rm)

	assert_not_null(first_pick)
	assert_eq(first_pick.id, second_pick.id)

func test_event_pool_filters_seen_events_and_falls_back_when_exhausted():
	var act_one = event_db.get_available_events(1, ["forgotten_cache", "quiet_rest"])
	var act_one_ids = act_one.map(func(event_data): return event_data.id)

	assert_false(act_one_ids.has("forgotten_cache"))
	assert_false(act_one_ids.has("quiet_rest"))
	assert_true(act_one_ids.has("ornament_peddler"))

	var exhausted = event_db.get_available_events(1, ["forgotten_cache", "quiet_rest", "ornament_peddler"])
	assert_true(exhausted.is_empty())

func test_pick_current_event_is_cached_and_records_seen_event_after_choice():
	var rm = _make_run_manager(1, 2)
	rm.set_random_seed(77)

	var picked = rm.pick_current_event(event_db)
	assert_not_null(picked)
	var cached = rm.pick_current_event(event_db)
	var choice = _find_choice_without_sanity(picked.choices)

	assert_eq(picked.id, cached.id)
	assert_true(choice.has("event_id"))
	assert_true(rm.apply_event_choice(choice))
	assert_true(rm.seen_event_ids.has(picked.id))

func test_weighted_event_pick_is_reproducible_with_seed():
	var rm_a = _make_run_manager(2, 5)
	var rm_b = _make_run_manager(2, 5)
	var rng_a = RandomNumberGenerator.new()
	var rng_b = RandomNumberGenerator.new()
	rng_a.seed = 404
	rng_b.seed = 404

	var pick_a = event_db.pick_event_for_run(rm_a, rng_a)
	var pick_b = event_db.pick_event_for_run(rm_b, rng_b)

	assert_not_null(pick_a)
	assert_eq(pick_a.id, pick_b.id)

func test_apply_event_choice_updates_long_term_state():
	var rm = _make_run_manager(2, 2)

	var accepted = rm.apply_event_choice({
		"cost_shards": 6,
		"effects": [
			{"type": "backpack_space", "width_delta": 1, "height_delta": 1},
			{"type": "item", "id": "paper_ball"},
			{"type": "ornament", "id": "old_pocket_watch"}
		]
	})
	var grid_config = rm.get_backpack_grid_config()

	assert_true(accepted)
	assert_eq(rm.current_shards, 14)
	assert_eq(rm.current_deck, ["paper_ball"])
	assert_eq(rm.current_ornaments, ["old_pocket_watch"])
	assert_eq(grid_config.usable_width, 6)
	assert_eq(grid_config.usable_height, 7)

func test_apply_event_choice_rejects_invalid_choices_without_partial_state():
	var rm = _make_run_manager(1, 2)
	rm.current_shards = 5

	assert_false(rm.apply_event_choice({
		"cost_shards": 6,
		"effects": [{"type": "shards", "amount": 99}]
	}))
	assert_eq(rm.current_shards, 5)

	rm.current_shards = 20
	rm.current_ornaments = ["old_pocket_watch"] as Array[String]
	assert_false(rm.apply_event_choice({
		"cost_shards": 3,
		"effects": [{"type": "ornament", "id": "old_pocket_watch"}]
	}))
	assert_eq(rm.current_shards, 20)
	assert_eq(rm.current_ornaments, ["old_pocket_watch"])

func test_backpack_lock_cells_moves_occupying_items_and_persists():
	var rm = _make_run_manager(2, 2)
	rm.current_backpack_items = [
		_make_backpack_entry("tin_can", 1, 1, [{"x": 0, "y": 0}, {"x": 1, "y": 0}], 10),
	] as Array[Dictionary]

	assert_true(rm.apply_event_choice({
		"effects": [
			{"type": "backpack_lock_cells", "cells": [{"x": 1, "y": 1}], "force_move": true}
		]
	}))

	assert_true(_cells_have(rm.backpack_locked_cells, Vector2i(1, 1)))
	assert_false(_entry_occupies(rm.current_backpack_items[0], Vector2i(1, 1)))

	var serialized = rm.serialize_run()
	var restored = autofree(RunManagerScript.new())
	restored.deserialize_run(serialized)
	assert_true(_cells_have(restored.backpack_locked_cells, Vector2i(1, 1)))

func test_backpack_lock_rolls_back_when_items_cannot_move():
	var rm = _make_run_manager(2, 2)
	rm.current_backpack_items = _filled_usable_backpack_entries()
	var before_items = rm.current_backpack_items.duplicate(true)

	assert_false(rm.apply_event_choice({
		"effects": [
			{"type": "backpack_lock_cells", "cells": [{"x": 1, "y": 1}], "force_move": true}
		]
	}))

	assert_true(rm.backpack_locked_cells.is_empty())
	assert_eq(rm.current_backpack_items, before_items)

func test_temporary_backpack_locks_apply_to_battle_config_and_expire_after_battle():
	var rm = _make_run_manager(2, 0)

	assert_true(rm.apply_event_choice({
		"effects": [
			{"type": "backpack_temp_lock_cells", "cells": [{"x": 2, "y": 2}], "duration_battles": 1}
		]
	}))
	var config = rm.get_backpack_grid_config()
	assert_true(_cells_have(config.blocked_cells, Vector2i(2, 2)))

	rm.win_battle(0)
	assert_true(rm.temporary_backpack_locked_cells.is_empty())

func test_backpack_space_persists_and_applies_to_battle_manager():
	var rm = _make_run_manager(2, 2)
	assert_true(rm.apply_event_choice({
		"effects": [{"type": "backpack_space", "width_delta": 2, "height_delta": 2}]
	}))
	var serialized = rm.serialize_run()

	var restored = autofree(RunManagerScript.new())
	restored.deserialize_run(serialized)
	assert_eq(restored.backpack_usable_width, 7)
	assert_eq(restored.backpack_usable_height, 7)

	var battle_manager = add_child_autofree(BattleManagerScript.new())
	battle_manager._apply_backpack_grid_config(restored)
	assert_eq(battle_manager.backpack_manager.usable_width, 7)
	assert_eq(battle_manager.backpack_manager.usable_height, 7)

func test_locked_backpack_cells_apply_to_battle_manager():
	var rm = _make_run_manager(2, 2)
	assert_true(rm.apply_event_choice({
		"effects": [
			{"type": "backpack_lock_cells", "cells": [{"x": 2, "y": 2}]}
		]
	}))

	var battle_manager = add_child_autofree(BattleManagerScript.new())
	battle_manager._apply_backpack_grid_config(rm)

	assert_true(battle_manager.backpack_manager.is_pos_blocked(Vector2i(2, 2)))
	assert_false(battle_manager.backpack_manager.can_place_item(item_db.get_item_by_id("paper_ball"), Vector2i(2, 2)))

func _find_choice_without_sanity(choices: Array[Dictionary]) -> Dictionary:
	for choice in choices:
		var has_sanity := false
		for effect in Array(choice.get("effects", [])):
			if effect is Dictionary and str(effect.get("type", "")) == "sanity":
				has_sanity = true
				break
		if not has_sanity:
			return choice
	return choices[0] if not choices.is_empty() else {}

func _make_backpack_entry(item_id: String, x: int, y: int, shape: Array, runtime_id: int) -> Dictionary:
	return {
		"id": item_id,
		"x": x,
		"y": y,
		"direction": ItemData.Direction.RIGHT,
		"shape": shape,
		"runtime_id": runtime_id,
	}

func _filled_usable_backpack_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var runtime_id := 1000
	for y in range(1, 6):
		for x in range(1, 6):
			result.append(_make_backpack_entry("paper_ball", x, y, [{"x": 0, "y": 0}], runtime_id))
			runtime_id += 1
	return result

func _cells_have(cells: Array, pos: Vector2i) -> bool:
	for cell in cells:
		if cell is Dictionary and int(cell.get("x", -1)) == pos.x and int(cell.get("y", -1)) == pos.y:
			return true
	return false

func _entry_occupies(entry: Dictionary, pos: Vector2i) -> bool:
	var root = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	for cell in Array(entry.get("shape", [])):
		if cell is Dictionary and root + Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0))) == pos:
			return true
	return false
