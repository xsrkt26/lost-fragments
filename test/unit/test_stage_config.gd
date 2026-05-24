extends GutTest

const StageConfig = preload("res://src/core/stage/stage_config.gd")
const RouteConfig = preload("res://src/core/route/route_config.gd")
const RunManagerScript = preload("res://src/autoload/run_manager.gd")
const BattleManagerScript = preload("res://src/battle/battle_manager.gd")

var rm_snapshot := {}
var gs_snapshot := {}

func before_each():
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
	assert_eq(StageConfig.get_route_id_for_act(4), RouteConfig.DEFAULT_ROUTE_ID)
	assert_eq(StageConfig.get_boss_score_target_rule(4).target, 110)
	assert_eq(StageConfig.get_battle_modifiers(4).pollution_added_bonus, 1)
	assert_eq(StageConfig.get_visual(4).battle_bgm_key, "battle")

func test_stage_config_falls_back_when_file_is_missing():
	var stage = StageConfig.get_stage(6, "user://missing_stages_for_test.json")

	assert_eq(StageConfig.get_max_act("user://missing_stages_for_test.json"), 6)
	assert_eq(stage.get("id"), "act_6")
	assert_eq(StageConfig.get_boss_score_target_rule(6, "user://missing_stages_for_test.json").target, 150)

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
	manager.current_route_index = 6

	var config = manager.get_current_battle_config()

	assert_eq(config.stage.id, "act_5")
	assert_true(config.is_boss)
	assert_eq(config.target_score, 130)
	assert_eq(config.battle_modifiers.draw_cost_delta, 1)
	assert_eq(config.battle_modifiers.blocked_cells.size(), 1)

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

	manager.request_draw()
	await get_tree().process_frame
	await get_tree().process_frame
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
