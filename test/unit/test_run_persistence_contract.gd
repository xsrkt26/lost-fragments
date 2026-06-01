extends GutTest

const RunManagerScript = preload("res://src/autoload/run_manager.gd")
const RunPersistenceCodec = preload("res://src/core/run/run_persistence_codec.gd")
const RouteConfig = preload("res://src/core/route/route_config.gd")

const EXPECTED_SAVE_KEYS: Array[String] = [
	"act",
	"backpack_deleted_cells",
	"backpack_items",
	"backpack_locked_cells",
	"backpack_usable_height",
	"backpack_usable_width",
	"completed_route_nodes",
	"deck",
	"depth",
	"event_node_state",
	"is_active",
	"is_complete",
	"next_pending_item_uid",
	"ornaments",
	"pending_item_rewards",
	"rng_seed",
	"rng_state",
	"route_id",
	"route_index",
	"seen_event_ids",
	"schema_version",
	"shards",
	"shop_purchase_state",
	"story_played_flags",
	"temporary_backpack_locked_cells",
	"tools",
]

var run_manager

func before_each():
	RouteConfig.clear_cache_for_tests()
	run_manager = autofree(RunManagerScript.new())

func test_serialize_run_keeps_save_schema_keys_stable():
	var actual = _sorted_string_keys(run_manager.serialize_run())
	var expected: Array[String] = []
	expected.append_array(EXPECTED_SAVE_KEYS)
	expected.sort()

	assert_eq(actual, expected)

func test_deserialize_run_keeps_defaults_for_missing_legacy_fields():
	run_manager.deserialize_run({"is_active": true})

	assert_eq(run_manager.current_shards, RunManagerScript.INITIAL_SHARDS)
	assert_eq(run_manager.current_deck, RunManagerScript.INITIAL_DECK)
	assert_eq(run_manager.backpack_usable_width, RunManagerScript.INITIAL_BACKPACK_USABLE_WIDTH)
	assert_eq(run_manager.backpack_usable_height, RunManagerScript.INITIAL_BACKPACK_USABLE_HEIGHT)
	assert_eq(run_manager.current_route_id, RouteConfig.DEFAULT_ROUTE_ID)
	assert_eq(run_manager.current_act, 1)
	assert_eq(run_manager.current_route_index, 0)
	assert_true(run_manager.is_run_active)
	assert_false(run_manager.is_run_complete)

func test_deserialize_run_accepts_legacy_tool_entry_arrays():
	run_manager.deserialize_run({
		"is_active": true,
		"tools": [
			{"id": "small_patch", "count": 2},
			{"id": "small_patch", "amount": 1},
			{"id": "", "count": 5},
			{"id": "dream_value_candy", "count": 0},
		],
	})

	assert_true(run_manager.current_tools.is_empty())
	assert_eq(run_manager.pending_item_rewards.size(), 1)
	assert_eq(str(run_manager.pending_item_rewards[0].get("id", "")), "small_patch")
	assert_eq(int(run_manager.pending_item_rewards[0].get("stack_count", 0)), 3)

func test_serialize_run_includes_current_schema_version():
	var serialized = run_manager.serialize_run()

	assert_eq(int(serialized.get("schema_version", 0)), RunPersistenceCodec.SAVE_SCHEMA_VERSION)

func test_deserialize_run_rejects_future_schema_version():
	var before_shards = run_manager.current_shards
	var accepted = RunPersistenceCodec.deserialize_into(run_manager, {
		"schema_version": RunPersistenceCodec.SAVE_SCHEMA_VERSION + 1,
		"is_active": true,
		"shards": before_shards + 99,
	})

	assert_false(accepted)
	assert_eq(run_manager.current_shards, before_shards)

func test_serialize_run_returns_defensive_mutable_copies():
	run_manager.current_deck = ["paper_ball"] as Array[String]
	var backpack_items: Array[Dictionary] = [
		{
			"id": "paper_ball",
			"shape": [{"x": 0, "y": 0}],
		},
	]
	run_manager.current_backpack_items = backpack_items
	run_manager.current_tools = {"small_patch": 1}
	run_manager.shop_purchase_state = {"1:0": {"offers": [{"id": "paper_ball"}]}}
	var serialized = run_manager.serialize_run()

	serialized["deck"].append("mutated_item")
	serialized["backpack_items"][0]["id"] = "mutated_item"
	serialized["backpack_items"][0]["shape"][0]["x"] = 99
	serialized["tools"]["small_patch"] = 99
	serialized["shop_purchase_state"]["1:0"]["offers"][0]["id"] = "mutated_item"

	assert_eq(run_manager.current_deck, ["paper_ball"] as Array[String])
	assert_eq(str(run_manager.current_backpack_items[0].get("id", "")), "paper_ball")
	assert_eq(int(run_manager.current_backpack_items[0].get("shape", [])[0].get("x", -1)), 0)
	assert_eq(run_manager.current_tools, {"small_patch": 1})
	assert_eq(str(run_manager.shop_purchase_state["1:0"]["offers"][0].get("id", "")), "paper_ball")

func test_rng_seed_and_state_roundtrip_without_advancing():
	run_manager.is_run_active = true
	run_manager.set_random_seed(13579)
	run_manager.random_int_for_run(1000, true)
	var serialized = run_manager.serialize_run()
	var expected_next_value = run_manager.random_int_for_run(1000, true)

	var restored = autofree(RunManagerScript.new())
	restored.deserialize_run(serialized)
	var restored_next_value = restored.random_int_for_run(1000, true)

	assert_eq(int(serialized.get("rng_seed", 0)), 13579)
	assert_ne(int(serialized.get("rng_state", 0)), 0)
	assert_eq(restored_next_value, expected_next_value)

func _sorted_string_keys(value: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in value.keys():
		result.append(str(key))
	result.sort()
	return result
