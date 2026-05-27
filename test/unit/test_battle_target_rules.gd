extends GutTest

const BattleManagerScript = preload("res://src/battle/battle_manager.gd")

func before_each():
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		rm.reset_route_progress()
		rm.is_run_active = true

func after_each():
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		rm.reset_route_progress()

func test_score_target_text_supports_none():
	var ui = autofree(load("res://src/ui/main_game_ui.gd").new())
	assert_eq(ui._format_target_text(false, -1), "无")
	assert_eq(ui._format_target_text(true, 50), "50")

func test_reaching_boss_target_does_not_auto_end_battle():
	var ui = autofree(load("res://src/ui/main_game_ui.gd").new())
	ui.sanity_label = autofree(Label.new())
	ui.score_label = autofree(Label.new())
	ui.target_score_label = autofree(Label.new())

	ui._apply_stats_display(100, 50, 100, {"has_target": true, "target": 50})

	assert_eq(ui.sanity_label.text, "100%")
	assert_eq(ui.score_label.text, "50")
	assert_eq(ui.target_score_label.text, "50")
	assert_false(ui._is_battle_ended)

func test_potion_state_tracks_sanity_ratio():
	var ui = autofree(load("res://src/ui/main_game_ui.gd").new())
	ui.potion_bag = autofree(TextureRect.new())

	ui._apply_stats_display(100, 0, 100, {"has_target": true, "target": 50})
	assert_eq(ui.potion_bag.texture.resource_path, "res://assets/ui/battle/potion_state_100.png")

	ui._apply_stats_display(79, 0, 100, {"has_target": true, "target": 50})
	assert_eq(ui.potion_bag.texture.resource_path, "res://assets/ui/battle/potion_state_75.png")

	ui._apply_stats_display(50, 0, 100, {"has_target": true, "target": 50})
	assert_eq(ui.potion_bag.texture.resource_path, "res://assets/ui/battle/potion_state_50.png")

	ui._apply_stats_display(20, 0, 100, {"has_target": true, "target": 50})
	assert_eq(ui.potion_bag.texture.resource_path, "res://assets/ui/battle/potion_state_25.png")

	ui._apply_stats_display(19, 0, 100, {"has_target": true, "target": 50})
	assert_eq(ui.potion_bag.texture.resource_path, "res://assets/ui/battle/potion_state_0.png")

func test_draw_lock_updates_button_disabled_state():
	var ui = autofree(load("res://src/ui/main_game_ui.gd").new())
	var manager = autofree(BattleManagerScript.new())
	ui.draw_button = autofree(Button.new())
	ui.battle_manager = manager
	manager.battle_state = BattleManager.BattleState.INTERACTIVE

	ui._set_draw_locked(false)
	assert_false(ui.draw_button.disabled)

	ui._set_draw_locked(true)
	assert_true(ui.draw_button.disabled)

func test_draw_interaction_requires_interactive_battle_state():
	var ui = autofree(load("res://src/ui/main_game_ui.gd").new())
	var manager = autofree(BattleManagerScript.new())
	ui.battle_manager = manager
	manager.battle_state = BattleManager.BattleState.INTERACTIVE

	assert_true(ui._is_draw_interaction_available())

	manager.battle_state = BattleManager.BattleState.DRAWING
	assert_false(ui._is_draw_interaction_available())

	manager.battle_state = BattleManager.BattleState.INTERACTIVE
	ui._draw_locked = true
	assert_false(ui._is_draw_interaction_available())
