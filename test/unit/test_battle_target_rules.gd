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

func test_trash_drop_area_uses_inset_and_texture_alpha():
	var ui = autofree(load("res://src/ui/main_game_ui.gd").new())
	var trash: TextureRect = autofree(TextureRect.new())
	trash.position = Vector2(10.0, 20.0)
	trash.size = Vector2(100.0, 100.0)
	ui.trash_bin = trash
	ui.trash_drop_hit_inset = Vector2.ZERO
	ui.trash_drop_alpha_threshold = 0.5

	var alpha_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	alpha_image.fill(Color(0, 0, 0, 0))
	alpha_image.set_pixel(2, 2, Color(1, 1, 1, 1))
	trash.texture = ImageTexture.create_from_image(alpha_image)

	assert_true(ui._is_point_in_trash_drop_area(Vector2(72.0, 82.0)))
	assert_false(ui._is_point_in_trash_drop_area(Vector2(22.0, 32.0)))

	var opaque_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	opaque_image.fill(Color(1, 1, 1, 1))
	trash.texture = ImageTexture.create_from_image(opaque_image)
	ui.trash_drop_hit_inset = Vector2(20.0, 20.0)

	assert_false(ui._is_point_in_trash_drop_area(Vector2(20.0, 70.0)))
	assert_true(ui._is_point_in_trash_drop_area(Vector2(70.0, 70.0)))

func test_trash_hover_feedback_scales_without_tree_tween():
	var ui = autofree(load("res://src/ui/main_game_ui.gd").new())
	var trash: TextureRect = autofree(TextureRect.new())
	trash.size = Vector2(100.0, 100.0)
	trash.scale = Vector2(1.0, 1.0)
	ui.trash_bin = trash

	ui._set_trash_bin_drag_hover(true)
	assert_eq(trash.pivot_offset, Vector2(50.0, 50.0))
	assert_almost_eq(trash.scale.x, ui.trash_drop_hover_scale, 0.001)
	assert_almost_eq(trash.scale.y, ui.trash_drop_hover_scale, 0.001)

	ui._set_trash_bin_drag_hover(false)
	assert_eq(trash.scale, Vector2.ONE)
