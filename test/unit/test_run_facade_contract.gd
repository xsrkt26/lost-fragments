extends GutTest

const RunManagerScript = preload("res://src/autoload/run_manager.gd")

const RUN_FACADE_METHODS: Array[String] = [
	"serialize_run",
	"deserialize_run",
	"save_backpack_state",
	"restore_backpack_state",
	"generate_current_shop_offers",
	"refresh_current_shop_offers",
	"buy_shop_offer",
	"pick_current_event",
	"apply_event_choice",
	"advance_route_node",
	"grant_item",
	"apply_reward",
	"grant_tool",
	"consume_tool",
	"reset_route_progress",
	"get_current_stage_route_id",
	"get_current_stage_config",
	"get_current_stage_visual",
	"get_current_battle_modifiers",
	"get_route_nodes",
	"get_current_route_node",
	"get_current_route_node_type",
	"can_enter_route_node",
	"get_scene_type_for_node",
	"get_current_node_scene_type",
	"get_current_battle_config",
	"current_battle_has_score_target",
	"get_current_battle_target_score",
	"is_current_battle_score_success",
	"has_empty_dream_trophy_reward_bonus",
	"random_float_for_run",
	"random_int_for_run",
	"shuffle_array_for_run",
]

const RUN_SIGNALS: Array[String] = [
	"run_started",
	"run_finished",
	"shards_changed",
	"deck_changed",
	"route_changed",
	"ornaments_changed",
	"pending_items_changed",
	"tools_changed",
]

func test_run_manager_facade_methods_remain_available():
	var manager = autofree(RunManagerScript.new())

	for method_name in RUN_FACADE_METHODS:
		assert_true(manager.has_method(method_name), "Missing RunManager facade method: %s" % method_name)

func test_run_manager_public_signals_remain_available():
	var manager = autofree(RunManagerScript.new())

	for signal_name in RUN_SIGNALS:
		assert_true(manager.has_signal(signal_name), "Missing RunManager signal: %s" % signal_name)
