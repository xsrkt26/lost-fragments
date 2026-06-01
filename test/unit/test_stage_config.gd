extends GutTest

const StageConfig = preload("res://src/core/stage/stage_config.gd")
const RouteConfig = preload("res://src/core/route/route_config.gd")
const RunManagerScript = preload("res://src/autoload/run_manager.gd")
const BattleManagerScript = preload("res://src/battle/battle_manager.gd")

var rm_snapshot := {}
var gs_snapshot := {}

func before_each():
	StageConfig.clear_cache_for_tests()
	RouteConfig.clear_cache_for_tests()
	var rm = get_node_or_null("/root/RunManager")
	var gs = get_node_or_null("/root/GameState")
	if rm:
		rm_snapshot = rm.serialize_run()
	if gs:
		gs_snapshot = {"sanity": gs.current_sanity, "score": gs.current_score}
		gs.reset_game()

func after_each():
	var rm = get_node_or_null("/root/RunManager")
	var gs = get_node_or_null("/root/GameState")
	if rm and not rm_snapshot.is_empty():
		rm.deserialize_run(rm_snapshot)
	if gs:
		gs.reset_game()
		if not gs_snapshot.is_empty():
			gs.current_sanity = int(gs_snapshot.get("sanity", gs.current_sanity))
			gs.current_score = int(gs_snapshot.get("score", gs.current_score))
	rm_snapshot = {}
	gs_snapshot = {}

func test_stage_config_loads_all_six_acts_and_metadata():
	assert_eq(StageConfig.get_max_act(), 6)

	var stage_4 = StageConfig.get_stage(4)
	assert_eq(stage_4.get("id"), "act_4")
	assert_eq(StageConfig.get_route_id_for_act(4), "act_4_gearworks")
	assert_eq(StageConfig.get_boss_score_target_rule(4).target, 110)
	assert_eq(StageConfig.get_battle_modifiers(4).pollution_added_bonus, 1)
	assert_eq(StageConfig.get_visual(4).battle_bgm_key, "battle")
	assert_false(StageConfig.get_visual(1).has("hub_background_key"))
	assert_eq(StageConfig.get_visual(2).hub_background_key, "stage")
	assert_eq(StageConfig.get_visual(3).hub_background_key, "grandma")
	assert_eq(StageConfig.get_visual(4).hub_background_key, "parents")
	assert_eq(StageConfig.get_visual(5).hub_background_key, "xiaojia")
	assert_eq(StageConfig.get_visual(6).hub_background_key, "shiyi")
	assert_eq(StageConfig.get_boss_battle_modifiers(5).blocked_cells.size(), 2)
	assert_eq(StageConfig.get_boss_battle_modifiers(6).draw_cost_delta, 1)
	assert_eq(StageConfig.get_boss_battle_modifiers(6).pollution_added_bonus, 1)
	assert_eq(StageConfig.get_backpack_config(1).usable_width, 5)
	assert_eq(StageConfig.get_backpack_config(1).usable_height, 5)
	assert_eq(StageConfig.get_backpack_config(2).usable_width, 5)
	assert_eq(StageConfig.get_backpack_config(2).usable_height, 6)
	assert_eq(StageConfig.get_backpack_config(3).usable_width, 6)
	assert_eq(StageConfig.get_backpack_config(3).usable_height, 6)
	assert_eq(StageConfig.get_backpack_config(4).usable_width, 6)
	assert_eq(StageConfig.get_backpack_config(4).usable_height, 7)
	assert_eq(StageConfig.get_backpack_config(5).usable_width, 7)
	assert_eq(StageConfig.get_backpack_config(5).usable_height, 7)
	assert_eq(StageConfig.get_backpack_config(6).usable_width, 7)
	assert_eq(StageConfig.get_backpack_config(6).usable_height, 7)
	var expected_dreamcatchers := {
		1: {"path": "res://assets/ui/battle/dreamcatchers/act_1_xiaomi.png", "size": Vector2(456.0, 605.0)},
		2: {"path": "res://assets/ui/battle/dreamcatchers/act_2_uncle.png", "size": Vector2(244.0, 425.0)},
		3: {"path": "res://assets/ui/battle/dreamcatchers/act_3_grandma.png", "size": Vector2(410.0, 469.0)},
		4: {"path": "res://assets/ui/battle/dreamcatchers/act_4_parents.png", "size": Vector2(494.0, 295.0)},
		5: {"path": "res://assets/ui/battle/dreamcatchers/act_5_xiaojia.png", "size": Vector2(278.0, 483.0)},
		6: {"path": "res://assets/ui/battle/dreamcatchers/act_6_shiyi.png", "size": Vector2(396.0, 574.0)},
	}
	for act in expected_dreamcatchers.keys():
		var expected: Dictionary = expected_dreamcatchers[act]
		var path := str(expected.get("path", ""))
		assert_eq(StageConfig.get_visual(int(act)).dreamcatcher_net_path, path)
		var texture := load(path) as Texture2D
		assert_not_null(texture)
		if texture != null:
			assert_eq(texture.get_size(), expected.get("size", Vector2.ZERO))

func test_stage_routes_point_to_distinct_content_tracks():
	assert_eq(StageConfig.get_route_id_for_act(1), RouteConfig.DEFAULT_ROUTE_ID)
	assert_eq(StageConfig.get_route_id_for_act(2), "act_2_pollution")
	assert_eq(StageConfig.get_route_id_for_act(3), "act_3_grove")
	assert_eq(StageConfig.get_route_id_for_act(4), "act_4_gearworks")
	assert_eq(StageConfig.get_route_id_for_act(5), "act_5_rift")
	assert_eq(StageConfig.get_route_id_for_act(6), "act_6_finale")

	var finale_nodes = RouteConfig.get_route_nodes("act_6_finale")
	assert_eq(finale_nodes.size(), 5)
	assert_eq(finale_nodes[0].get("type"), RouteConfig.NODE_BATTLE)
	assert_eq(finale_nodes[4].get("type"), RouteConfig.NODE_BOSS_BATTLE)

func test_each_stage_route_has_two_growth_battles_and_one_boss():
	for route_id in [
		RouteConfig.DEFAULT_ROUTE_ID,
		"act_2_pollution",
		"act_3_grove",
		"act_4_gearworks",
		"act_5_rift",
		"act_6_finale",
	]:
		var nodes = RouteConfig.get_route_nodes(route_id)
		var normal_battles := 0
		var boss_battles := 0
		for node in nodes:
			match str(node.get("type", "")):
				RouteConfig.NODE_BATTLE:
					normal_battles += 1
				RouteConfig.NODE_BOSS_BATTLE:
					boss_battles += 1
				RouteConfig.NODE_ELITE_BATTLE:
					fail_test("No elite battle should be present in route %s during baseline tuning." % route_id)
		assert_eq(normal_battles, 2, route_id)
		assert_eq(boss_battles, 1, route_id)

func test_stage_config_falls_back_when_file_is_missing():
	var stage = StageConfig.get_stage(6, "user://missing_stages_for_test.json")

	assert_eq(StageConfig.get_max_act("user://missing_stages_for_test.json"), 6)
	assert_eq(stage.get("id"), "act_6")
	assert_eq(StageConfig.get_boss_score_target_rule(6, "user://missing_stages_for_test.json").target, 165)

func test_stage_config_cache_returns_defensive_copies():
	var table = StageConfig.load_stage_table_from_path(StageConfig.STAGE_DATA_PATH)
	var stages = table.get("stages", {})
	assert_true(stages is Dictionary)
	stages.clear()

	var cached_table = StageConfig.load_stage_table_from_path(StageConfig.STAGE_DATA_PATH)
	var cached_stages = cached_table.get("stages", {})
	assert_true(cached_stages is Dictionary)
	assert_true(cached_stages.has("1"))

func test_stage_config_supports_custom_route_and_weight_modifiers():
	var path = "user://custom_stages_for_test.json"
	_write_stage_table(path, {
		"version": 1,
		"max_act": 2,
		"default_stage_id": "custom_1",
		"stages": {
			"1": {
				"id": "custom_1",
				"name": "Custom One",
				"route_id": "default",
				"reward_weight_modifiers": {
					"types": {"item": 2.0},
					"ids": {"paper_ball": 3.0},
					"tags": {"废弃物": 2.0},
					"rarities": {}
				}
			},
			"2": {
				"id": "custom_2",
				"name": "Custom Two",
				"route_id": "hard_route",
				"boss": {"score_target": {"enabled": true, "value": 88}}
			}
		}
	})

	assert_eq(StageConfig.get_route_id_for_act(2, "default", path), "hard_route")
	assert_eq(StageConfig.get_boss_score_target_rule(2, path).target, 88)
	var modifiers = StageConfig.get_reward_weight_modifiers(1, path)
	var weight = StageConfig.apply_weight_modifiers(1.0, "item", "paper_ball", ["废弃物"], "", modifiers)
	assert_eq(weight, 12.0)
	DirAccess.remove_absolute(path)

func test_run_manager_exposes_stage_battle_config_and_completion():
	var manager = autofree(RunManagerScript.new())
	manager.is_run_active = true
	manager.current_act = 5
	manager.current_route_index = 4

	var config = manager.get_current_battle_config()
	var grid_config = manager.get_backpack_grid_config()

	assert_eq(config.stage.id, "act_5")
	assert_true(config.is_boss)
	assert_eq(config.target_score, 135)
	assert_eq(grid_config.usable_width, 7)
	assert_eq(grid_config.usable_height, 7)
	assert_eq(config.battle_modifiers.draw_cost_delta, 1)
	assert_eq(config.battle_modifiers.blocked_cells.size(), 3)
	assert_true(_cells_have(config.battle_modifiers.blocked_cells, Vector2i(1, 1)))
	assert_true(_cells_have(config.battle_modifiers.blocked_cells, Vector2i(5, 1)))
	assert_true(_cells_have(config.battle_modifiers.blocked_cells, Vector2i(1, 5)))

func test_late_act_boss_modifiers_only_apply_on_boss_nodes():
	var manager = autofree(RunManagerScript.new())
	manager.is_run_active = true
	manager.current_act = 6
	manager.current_route_index = 0

	var normal_config = manager.get_current_battle_config()
	assert_false(normal_config.is_boss)
	assert_eq(normal_config.battle_modifiers.draw_cost_delta, 2)
	assert_eq(normal_config.battle_modifiers.pollution_added_bonus, 1)
	assert_eq(normal_config.battle_modifiers.blocked_cells.size(), 2)

	manager.current_route_index = 4
	var boss_config = manager.get_current_battle_config()
	assert_true(boss_config.is_boss)
	assert_eq(boss_config.battle_modifiers.draw_cost_delta, 3)
	assert_eq(boss_config.battle_modifiers.pollution_added_bonus, 2)
	assert_eq(boss_config.battle_modifiers.blocked_cells.size(), 5)
	assert_true(_cells_have(boss_config.battle_modifiers.blocked_cells, Vector2i(3, 1)))

func test_stage_battle_modifiers_apply_to_grid_draw_cost_and_pollution():
	var rm = get_node_or_null("/root/RunManager")
	var gs = get_node_or_null("/root/GameState")
	var item_db = get_node_or_null("/root/ItemDatabase")
	assert_not_null(rm)
	assert_not_null(gs)
	assert_not_null(item_db)
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()

	rm.current_act = 6
	rm.current_route_index = 0
	rm.current_deck = ["paper_ball"] as Array[String]
	rm.current_backpack_items.clear()
	rm.backpack_locked_cells.clear()
	rm.backpack_deleted_cells.clear()
	rm.temporary_backpack_locked_cells.clear()
	gs.current_sanity = 100

	var manager = add_child_autofree(BattleManagerScript.new())
	await get_tree().process_frame

	assert_true(manager.backpack_manager.is_pos_blocked(Vector2i(1, 1)))
	assert_true(manager.backpack_manager.is_pos_blocked(Vector2i(5, 5)))

	var paper_draw = item_db.get_item_by_id("paper_ball")
	manager._process_new_item_acquisition(paper_draw)
	assert_eq(gs.current_sanity, 97)

	manager.backpack_manager.grid.clear()
	var paper = item_db.get_item_by_id("paper_ball")
	paper.direction = ItemData.Direction.RIGHT
	assert_true(manager.backpack_manager.place_item(paper, Vector2i(2, 2)))
	var instance = manager.backpack_manager.grid[Vector2i(2, 2)]
	var resolver = ImpactResolver.new(manager.backpack_manager, manager.context)
	resolver.add_pollution(instance, 1)
	assert_eq(instance.current_pollution, 2)

func _write_stage_table(path: String, table: Dictionary) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string(JSON.stringify(table))
	file.close()

func _cells_have(cells: Array, target: Vector2i) -> bool:
	for cell in cells:
		if cell is Vector2i and cell == target:
			return true
		if cell is Dictionary and Vector2i(int(cell.get("x", -1)), int(cell.get("y", -1))) == target:
			return true
	return false
