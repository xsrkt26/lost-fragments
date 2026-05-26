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


func test_mouse_move_target_is_clamped_to_walk_bounds():
	player.global_position = Vector2(100.0, 0.0)
	player.set_walk_bounds(200.0, 500.0)

	player.move_to_global_x(80.0)
	assert_eq(player.move_target_x, 200.0)

	player.move_to_global_x(620.0)
	assert_eq(player.move_target_x, 500.0)


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

	var hub_player := hub.get_node_or_null("Player") as CharacterBody2D
	assert_not_null(hub_player)
	assert_true(hub_player.visible)

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


func test_hub_scene_uses_split_hub_art_without_composited_reference():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var background := hub.get_node_or_null("HubArt/Background") as TextureRect
	assert_not_null(background)
	assert_not_null(background.texture)
	assert_eq(background.texture.resource_path, "res://assets/ui/book/wood_floor.png")
	assert_eq(background.size, Vector2(1593.0, 872.0))

	for node_path in [
		"HubArt/PageBack",
		"HubArt/PageRouteCover",
		"HubArt/PageBackpackCover",
		"HubArt/PageMiddle",
		"HubArt/Page",
		"HubArt/Room",
		"HubArt/RingRight",
		"HubArt/RouteTab",
		"HubArt/BackpackTab",
		"HubArt/GalleryTab",
		"HubArt/SettingsTab",
		"HubArt/CornerTopLeft",
		"HubArt/CornerTopRight",
		"HubArt/CornerBottomLeft",
		"HubArt/CornerBottomRight",
		"HubArt/SpeechBubble",
	]:
		var sprite := hub.get_node_or_null(node_path) as Sprite2D
		assert_not_null(sprite, "Hub split art should expose %s" % node_path)
		assert_not_null(sprite.texture)
		assert_true(sprite.texture.resource_path != "res://assets/ui/hub/hub_background.png")

	var speech_text := hub.get_node_or_null("HubArt/SpeechText") as Label
	assert_not_null(speech_text)
	var speech_bubble := hub.get_node_or_null("HubArt/SpeechBubble") as Sprite2D
	assert_not_null(speech_bubble)
	assert_false(speech_bubble.visible)
	assert_false(speech_text.visible)

	hub.show_speech_message()
	assert_true(speech_bubble.visible)
	assert_true(speech_text.visible)
	assert_eq(speech_text.text, "你终于醒了！")

	hub.show_speech_message("按 E 查看图鉴")
	assert_eq(speech_text.text, "按 E 查看图鉴")

	hub.hide_speech_message()
	assert_false(speech_bubble.visible)
	assert_false(speech_text.visible)

	var page := hub.get_node_or_null("HubArt/Page") as Sprite2D
	var page_back := hub.get_node_or_null("HubArt/PageBack") as Sprite2D
	var page_route_cover := hub.get_node_or_null("HubArt/PageRouteCover") as Sprite2D
	var page_backpack_cover := hub.get_node_or_null("HubArt/PageBackpackCover") as Sprite2D
	var page_middle := hub.get_node_or_null("HubArt/PageMiddle") as Sprite2D
	assert_true(page_back.position.x < page_route_cover.position.x)
	assert_true(page_route_cover.position.x < page_backpack_cover.position.x)
	assert_true(page_backpack_cover.position.x < page_middle.position.x)
	assert_true(page_middle.position.x < page.position.x)

	var route_tab := hub.get_node_or_null("HubArt/RouteTab") as Sprite2D
	var backpack_tab := hub.get_node_or_null("HubArt/BackpackTab") as Sprite2D
	var gallery_tab := hub.get_node_or_null("HubArt/GalleryTab") as Sprite2D
	var settings_tab := hub.get_node_or_null("HubArt/SettingsTab") as Sprite2D
	assert_true(route_tab.z_index > page_back.z_index)
	assert_true(route_tab.z_index < page_route_cover.z_index)
	assert_true(backpack_tab.z_index > page_route_cover.z_index)
	assert_true(backpack_tab.z_index < page_backpack_cover.z_index)
	assert_true(gallery_tab.z_index > page_backpack_cover.z_index)
	assert_true(gallery_tab.z_index < page_middle.z_index)
	assert_true(settings_tab.z_index > page_middle.z_index)
	assert_true(settings_tab.z_index < page.z_index)

	var route_button := hub.get_node_or_null("CanvasLayer/RouteButton") as Button
	assert_not_null(route_button)
	assert_eq(route_button.tooltip_text, "继续梦境")
	assert_true(route_button.pressed.is_connected(Callable(hub, "_on_route_button_pressed")))

	var backpack_button := hub.get_node_or_null("CanvasLayer/BackpackButton") as Button
	assert_not_null(backpack_button)
	assert_eq(backpack_button.tooltip_text, "整理背包")
	assert_true(backpack_button.pressed.is_connected(Callable(hub, "_on_backpack_button_pressed")))

	var gallery_button := hub.get_node_or_null("CanvasLayer/GalleryButton") as Button
	assert_not_null(gallery_button)
	assert_eq(gallery_button.tooltip_text, "图鉴")
	assert_true(gallery_button.pressed.is_connected(Callable(hub, "_on_gallery_button_pressed")))

	var settings_button := hub.get_node_or_null("CanvasLayer/SettingsButton") as Button
	assert_not_null(settings_button)
	assert_eq(settings_button.tooltip_text, "设置")
	assert_true(settings_button.pressed.is_connected(Callable(hub, "_on_settings_button_pressed")))

	assert_null(hub.get_node_or_null("CanvasLayer/RoutePanel"))


func test_hub_keeps_legacy_main_menu_button_hidden_from_left_tabs():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var button := hub.get_node_or_null("CanvasLayer/MainMenuButton") as Button
	assert_not_null(button)
	assert_eq(button.tooltip_text, "返回主界面")
	assert_false(button.visible)
	assert_true(button.pressed.is_connected(Callable(hub, "_on_main_menu_button_pressed")))
