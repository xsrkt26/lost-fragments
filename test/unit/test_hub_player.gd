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
	var overlay_art := ui.get_node_or_null("ContentLayer/BackpackOverlayArt") as Control
	assert_not_null(overlay_art)
	assert_true(overlay_art.visible)
	for node_name in [
		"WoodFloor",
		"RedBookCover",
		"AlbumPage",
		"AlbumRingRight",
		"BackpackTab",
		"BagBase",
		"BagPatch",
		"StatsPaper",
	]:
		var art := ui.get_node_or_null("ContentLayer/BackpackOverlayArt/%s" % node_name) as TextureRect
		assert_not_null(art, "Backpack overlay split art should expose %s" % node_name)
		assert_not_null(art.texture)
		assert_true(art.texture.resource_path != "res://assets/ui/backpack/backpack_overlay_background.png")
	assert_not_null(ui.get_node_or_null("ContentLayer/OverlayEffectsList"))
	assert_not_null(ui.get_node_or_null("ContentLayer/OverlayStatsLabel"))
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


func test_hub_player_uses_character_animation_frames():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var animated_sprite := hub.get_node_or_null("Player/AnimatedSprite2D") as AnimatedSprite2D
	assert_not_null(animated_sprite)
	assert_not_null(animated_sprite.sprite_frames)
	assert_true(animated_sprite.sprite_frames.has_animation("idle"))
	assert_true(animated_sprite.sprite_frames.has_animation("walk"))
	assert_eq(animated_sprite.sprite_frames.get_frame_count("idle"), 4)
	assert_eq(animated_sprite.sprite_frames.get_frame_count("walk"), 6)
	assert_eq(animated_sprite.scale, Vector2(0.3, 0.3))
	assert_not_null(animated_sprite.sprite_frames.get_frame_texture("idle", 0))
	assert_not_null(animated_sprite.sprite_frames.get_frame_texture("walk", 0))


func test_hub_scene_uses_left_side_hub_art_without_route_map():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var background := hub.get_node_or_null("Background") as TextureRect
	assert_not_null(background)
	assert_not_null(background.texture)
	assert_eq(background.texture.resource_path, "res://assets/ui/hub/hub_background.png")

	var backpack_button := hub.get_node_or_null("CanvasLayer/BackpackButton") as Button
	assert_not_null(backpack_button)
	assert_eq(backpack_button.position.x, 24.0)

	var backpack_art := hub.get_node_or_null("CanvasLayer/BackpackButton/Art") as TextureRect
	assert_not_null(backpack_art)
	assert_not_null(backpack_art.texture)
	assert_eq(backpack_art.texture.resource_path, "res://assets/ui/hub/hub_backpack_tab.png")

	var main_menu_button := hub.get_node_or_null("CanvasLayer/MainMenuButton") as Button
	assert_not_null(main_menu_button)
	assert_eq(main_menu_button.position.x, 24.0)

	var exit_art := hub.get_node_or_null("CanvasLayer/MainMenuButton/Art") as TextureRect
	assert_not_null(exit_art)
	assert_not_null(exit_art.texture)
	assert_eq(exit_art.texture.resource_path, "res://assets/ui/hub/hub_exit_tab.png")

	assert_null(hub.get_node_or_null("CanvasLayer/RoutePanel"))


func test_hub_exposes_mouse_return_to_main_menu_button():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var button := hub.get_node_or_null("CanvasLayer/MainMenuButton") as Button
	assert_not_null(button)
	assert_eq(button.tooltip_text, "返回主界面")
	assert_not_null(button.get_node_or_null("Art"))
	assert_not_null(button.get_node_or_null("Caption"))
	assert_true(button.pressed.is_connected(Callable(hub, "_on_main_menu_button_pressed")))
