extends GutTest

const RouteConfig = preload("res://src/core/route/route_config.gd")

var run_manager

func before_each():
	RouteConfig.clear_cache_for_tests()
	run_manager = autofree(load("res://src/autoload/run_manager.gd").new())
	run_manager.reset_route_progress()
	run_manager.is_run_active = true

func test_default_route_is_configured():
	var nodes = run_manager.get_route_nodes()
	assert_eq(nodes.size(), 5)
	assert_eq(nodes[0].get("type"), RouteConfig.NODE_BATTLE)
	assert_eq(nodes[1].get("type"), RouteConfig.NODE_SHOP)
	assert_eq(nodes[2].get("type"), RouteConfig.NODE_BATTLE)
	assert_eq(nodes[3].get("type"), RouteConfig.NODE_SHOP)
	assert_eq(nodes[4].get("type"), RouteConfig.NODE_BOSS_BATTLE)
	assert_eq(nodes[4].get("scene"), RouteConfig.SCENE_BATTLE)

func test_default_route_loads_from_external_config():
	var table = RouteConfig.load_route_table_from_path(RouteConfig.ROUTE_DATA_PATH)
	var routes = table.get("routes", {})
	assert_true(routes is Dictionary)
	assert_true(routes.has(RouteConfig.DEFAULT_ROUTE_ID))
	assert_eq(RouteConfig.get_max_act(), 6)
	assert_eq(RouteConfig.get_route_size(), 5)

func test_route_config_cache_returns_defensive_copies():
	var table = RouteConfig.load_route_table_from_path(RouteConfig.ROUTE_DATA_PATH)
	var routes = table.get("routes", {})
	assert_true(routes is Dictionary)
	routes.clear()

	var cached_table = RouteConfig.load_route_table_from_path(RouteConfig.ROUTE_DATA_PATH)
	var cached_routes = cached_table.get("routes", {})
	assert_true(cached_routes is Dictionary)
	assert_true(cached_routes.has(RouteConfig.DEFAULT_ROUTE_ID))

func test_route_config_falls_back_when_file_is_missing():
	var table = RouteConfig.load_route_table_from_path("user://missing_routes_for_test.json")
	var routes = table.get("routes", {})
	assert_true(routes is Dictionary)
	assert_true(routes.has(RouteConfig.DEFAULT_ROUTE_ID))
	assert_eq(Array(routes[RouteConfig.DEFAULT_ROUTE_ID]).size(), 5)

func test_route_config_falls_back_when_json_is_invalid():
	var path = "user://invalid_routes_for_test.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string("{invalid")
	file.close()

	var table = RouteConfig.load_route_table_from_path(path)
	var routes = table.get("routes", {})
	assert_true(routes is Dictionary)
	assert_true(routes.has(RouteConfig.DEFAULT_ROUTE_ID))
	assert_eq(Array(routes[RouteConfig.DEFAULT_ROUTE_ID]).size(), 5)
	DirAccess.remove_absolute(path)

func test_route_config_supports_custom_route_nodes_and_score_rules():
	var path = "user://custom_routes_for_test.json"
	_write_route_table(path, {
		"default_route_id": "custom",
		"max_act": 2,
		"routes": {
			"custom": [
				{"id": "intro", "type": RouteConfig.NODE_CUTSCENE, "label": "开场CG", "scene": RouteConfig.SCENE_EVENT, "metadata": {"cg": "intro"}},
				{"id": "elite_1", "type": RouteConfig.NODE_ELITE_BATTLE, "label": "精英局内游戏", "score_target": {"enabled": true, "value": 25}}
			]
		}
	})

	var nodes = RouteConfig.get_route_nodes("custom", path)
	assert_eq(nodes.size(), 2)
	assert_eq(RouteConfig.get_max_act(path), 2)
	assert_eq(RouteConfig.normalize_route_id("missing", path), "custom")
	assert_eq(RouteConfig.get_scene_key_for_node(nodes[0]), RouteConfig.SCENE_EVENT)
	assert_true(RouteConfig.is_battle_node_type(nodes[1].get("type", "")))
	assert_eq(RouteConfig.get_score_target_rule(nodes[1], 1).target, 25)
	DirAccess.remove_absolute(path)

func test_new_route_progress_starts_at_first_node():
	var node = run_manager.get_current_route_node()
	assert_eq(run_manager.current_act, 1)
	assert_eq(run_manager.current_route_index, 0)
	assert_eq(node.get("id"), "battle_1")
	assert_true(run_manager.can_enter_route_node(0))
	assert_false(run_manager.can_enter_route_node(1))

func test_reset_route_progress_clears_completion_state():
	run_manager.is_run_complete = true
	run_manager.is_run_active = false
	run_manager.reset_route_progress()
	assert_false(run_manager.is_run_active)
	assert_false(run_manager.is_run_complete)
	assert_eq(run_manager.current_act, 1)
	assert_eq(run_manager.current_route_index, 0)

func test_advance_route_node_unlocks_next_node():
	var completed = run_manager.advance_route_node()
	assert_eq(completed.get("id"), "battle_1")
	assert_eq(run_manager.current_route_index, 1)
	assert_true(run_manager.completed_route_nodes.has(0))
	assert_false(run_manager.can_enter_route_node(0))
	assert_true(run_manager.can_enter_route_node(1))

func test_advance_rejects_unexpected_node_id():
	var completed = run_manager.advance_route_node("wrong_node")
	assert_true(completed.is_empty())
	assert_eq(run_manager.current_route_index, 0)
	assert_true(run_manager.completed_route_nodes.is_empty())

func test_route_wraps_to_next_act_after_last_node():
	for _i in range(RouteConfig.get_route_size()):
		run_manager.advance_route_node()
	assert_eq(run_manager.current_act, 2)
	assert_eq(run_manager.current_route_index, 0)
	assert_true(run_manager.completed_route_nodes.is_empty())

func test_run_completes_after_max_act_route_finish():
	for _i in range(RouteConfig.get_route_size() * RouteConfig.MAX_ACT):
		run_manager.advance_route_node()
	assert_false(run_manager.is_run_active)
	assert_true(run_manager.is_run_complete)
	assert_eq(run_manager.current_act, RouteConfig.MAX_ACT)
	assert_false(run_manager.can_enter_route_node(run_manager.current_route_index))

func test_deserialize_old_save_defaults_route_fields():
	run_manager.deserialize_run({
		"shards": 12,
		"deck": ["paper_ball"],
		"ornaments": [],
		"depth": 3,
		"is_active": true
	})
	assert_eq(run_manager.current_route_id, RouteConfig.DEFAULT_ROUTE_ID)
	assert_eq(run_manager.current_act, 1)
	assert_eq(run_manager.current_route_index, 0)
	assert_false(run_manager.is_run_complete)
	assert_eq(run_manager.get_current_route_node().get("id"), "battle_1")

func test_scene_mapping_supports_current_route_node_types():
	assert_eq(run_manager.get_scene_type_for_node({"type": RouteConfig.NODE_BATTLE}), GlobalScene.SceneType.BATTLE)
	assert_eq(run_manager.get_scene_type_for_node({"type": RouteConfig.NODE_BOSS_BATTLE}), GlobalScene.SceneType.BATTLE)
	assert_eq(run_manager.get_scene_type_for_node({"type": RouteConfig.NODE_SHOP}), GlobalScene.SceneType.SHOP)
	assert_eq(run_manager.get_scene_type_for_node({"type": RouteConfig.NODE_EVENT}), GlobalScene.SceneType.EVENT)
	assert_eq(run_manager.get_scene_type_for_node({"type": RouteConfig.NODE_ELITE_BATTLE}), GlobalScene.SceneType.BATTLE)
	assert_eq(run_manager.get_scene_type_for_node({"type": RouteConfig.NODE_REWARD}), GlobalScene.SceneType.EVENT)
	assert_eq(run_manager.get_scene_type_for_node({"type": RouteConfig.NODE_CUTSCENE, "scene": RouteConfig.SCENE_HUB}), GlobalScene.SceneType.HUB)

func test_normal_battle_has_no_score_target():
	run_manager.current_route_index = 0
	var config = run_manager.get_current_battle_config()
	assert_false(config.has_score_target)
	assert_eq(config.target_score, run_manager.NO_SCORE_TARGET)
	assert_true(run_manager.is_current_battle_score_success(0))

func test_boss_battle_requires_score_target():
	run_manager.current_route_index = 4
	var config = run_manager.get_current_battle_config()
	assert_true(config.is_boss)
	assert_true(config.has_score_target)
	assert_eq(config.target_score, 45)
	assert_false(run_manager.is_current_battle_score_success(44))
	assert_true(run_manager.is_current_battle_score_success(45))

func test_boss_target_scales_by_act():
	run_manager.current_route_index = 4
	run_manager.current_act = 3
	assert_eq(run_manager.get_current_battle_target_score(), 85)

func test_run_random_helpers_are_seeded_and_serializable():
	run_manager.set_random_seed(4242)
	var first_shuffle = run_manager.shuffle_array_for_run(["a", "b", "c", "d"] as Array, true)
	var first_next = run_manager.random_int_for_run(100, true)
	var serialized = run_manager.serialize_run()
	var first_after_snapshot = run_manager.random_int_for_run(100, true)

	var restored = autofree(load("res://src/autoload/run_manager.gd").new())
	restored.deserialize_run(serialized)
	var restored_after_snapshot = restored.random_int_for_run(100, true)

	var repeated = autofree(load("res://src/autoload/run_manager.gd").new())
	repeated.is_run_active = true
	repeated.set_random_seed(4242)
	var repeated_shuffle = repeated.shuffle_array_for_run(["a", "b", "c", "d"] as Array, true)
	var repeated_next = repeated.random_int_for_run(100, true)

	assert_eq(first_shuffle, repeated_shuffle)
	assert_eq(first_next, repeated_next)
	assert_eq(restored_after_snapshot, first_after_snapshot)

func _write_route_table(path: String, table: Dictionary) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string(JSON.stringify(table))
	file.close()
