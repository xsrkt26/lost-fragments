extends GutTest

const HubScene = preload("res://src/ui/hub/hub_scene.tscn")
const MainGameUI = preload("res://src/ui/main_game_ui.tscn")

var player

func before_each():
	player = add_child_autofree(load("res://src/ui/hub/hub_player.gd").new())

func test_mouse_move_target_is_set_and_cleared():
	player.move_to_global_x(420.0)
	assert_true(player.has_move_target)
	assert_eq(player.move_target_x, 420.0)

	player.clear_move_target()
	assert_false(player.has_move_target)

func test_backpack_overlay_mode_adds_close_button_and_keeps_ui_context():
	var ui = MainGameUI.instantiate()
	ui.configure_for_backpack_overlay()
	add_child_autofree(ui)

	await get_tree().create_timer(0.2).timeout

	assert_true(GlobalInput.is_context(GlobalInput.Context.UI))
	assert_not_null(ui.get_node_or_null("ContentLayer/CloseBackpackButton"))
	assert_false(ui.get_node("ContentLayer/DreamcatcherPanel").visible)
	assert_false(ui.get_node("ContentLayer/MenuButton").visible)

func test_hub_backpack_overlay_close_button_restores_world_context():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	hub._open_backpack_overlay()
	await get_tree().create_timer(0.2).timeout

	var overlay_root = hub.get_node("CanvasLayer/OverlayRoot")
	assert_eq(overlay_root.get_child_count(), 1)
	assert_true(GlobalInput.is_context(GlobalInput.Context.UI))
	var overlay = overlay_root.get_child(0)
	var close_button = overlay.get_node_or_null("ContentLayer/CloseBackpackButton")
	assert_not_null(close_button)

	close_button.pressed.emit()
	await get_tree().process_frame

	assert_eq(overlay_root.get_child_count(), 0)
	assert_true(GlobalInput.is_context(GlobalInput.Context.WORLD))

func test_hub_left_click_moves_player_with_mouse():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout
	GlobalInput.set_context(GlobalInput.Context.WORLD)
	var hub_player = hub.get_node("Player")
	hub_player.clear_move_target()

	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(320, 500)
	hub._unhandled_input(event)

	assert_true(hub_player.has_move_target)
	assert_eq(hub_player.move_target_x, 320.0)

func test_hub_player_uses_final_character_animation_frames():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var hub_player = hub.get_node("Player")
	assert_null(hub_player.get_node_or_null("Sprite2D"))

	var animated_sprite := hub_player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	assert_not_null(animated_sprite)
	assert_not_null(animated_sprite.sprite_frames)
	assert_true(animated_sprite.sprite_frames.has_animation(&"idle"))
	assert_true(animated_sprite.sprite_frames.has_animation(&"walk"))
	assert_eq(animated_sprite.sprite_frames.get_frame_count(&"idle"), 4)
	assert_eq(animated_sprite.sprite_frames.get_frame_count(&"walk"), 6)
	assert_eq(animated_sprite.animation, &"idle")

func test_hub_player_animation_controls_switch_between_idle_and_walk():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var hub_player = hub.get_node("Player")
	var animated_sprite := hub_player.get_node("AnimatedSprite2D") as AnimatedSprite2D

	hub_player.play_walk_animation()
	assert_eq(animated_sprite.animation, &"walk")
	assert_true(animated_sprite.is_playing())

	hub_player.play_move_animation_towards(hub_player.global_position.x - 100.0)
	assert_eq(animated_sprite.animation, &"walk")
	assert_true(animated_sprite.flip_h)

	hub_player.play_move_animation_towards(hub_player.global_position.x + 100.0)
	assert_false(animated_sprite.flip_h)

	hub_player.play_idle_animation()
	assert_eq(animated_sprite.animation, &"idle")

func test_hub_exposes_mouse_return_to_main_menu_button():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var button := hub.get_node_or_null("CanvasLayer/MainMenuButton") as Button
	assert_not_null(button)
	assert_eq(button.text, "回主界面")
	assert_eq(button.tooltip_text, "返回主界面")
	assert_true(button.pressed.is_connected(Callable(hub, "_on_main_menu_button_pressed")))
