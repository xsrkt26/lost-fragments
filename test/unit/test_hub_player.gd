extends GutTest

const HubScene = preload("res://src/ui/hub/hub_scene.tscn")
const MainGameUI = preload("res://src/ui/main_game_ui.tscn")

var player
var rm_snapshot := {}


func before_each():
	player = add_child_autofree(load("res://src/ui/hub/hub_player.gd").new())
	var rm = get_node_or_null("/root/RunManager")
	rm_snapshot = rm.serialize_run() if rm else {}


func after_each():
	var rm = get_node_or_null("/root/RunManager")
	if rm and not rm_snapshot.is_empty():
		rm.deserialize_run(rm_snapshot)
	rm_snapshot = {}


func _assert_dreamcatcher_net_centered_on_cloud(panel: TextureRect, net: Sprite2D) -> void:
	var expected_center := panel.texture.get_size() * 0.5
	var actual_center := net.position + net.offset.rotated(net.rotation)
	assert_almost_eq(actual_center.x, expected_center.x, 0.01)
	assert_almost_eq(actual_center.y, expected_center.y, 0.01)
	assert_gt(net.offset.y, net.texture.get_size().y * 0.75)


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
	var viewport_size: Vector2 = ui.get_viewport_rect().size
	var content_layer := ui.get_node_or_null("ContentLayer") as Control
	assert_not_null(content_layer)
	assert_eq(content_layer.position, Vector2.ZERO)
	assert_eq(content_layer.scale, Vector2.ONE)
	assert_almost_eq(content_layer.size.x, viewport_size.x, 0.01)
	assert_almost_eq(content_layer.size.y, viewport_size.y, 0.01)
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
	var wood_floor := ui.get_node_or_null("ContentLayer/BackpackOverlayArt/WoodFloor") as TextureRect
	assert_not_null(wood_floor)
	var wood_rect: Rect2 = wood_floor.get_global_rect()
	assert_lte(wood_rect.position.x, 0.01)
	assert_lte(wood_rect.position.y, 0.01)
	assert_gte(wood_rect.end.x, viewport_size.x - 0.01)
	assert_gte(wood_rect.end.y, viewport_size.y - 0.01)
	assert_not_null(ui.get_node_or_null("ContentLayer/OverlayEffectsList"))
	assert_not_null(ui.get_node_or_null("ContentLayer/OverlayStatsLabel"))
	assert_false(ui.get_node("ContentLayer/DreamcatcherPanel").visible)
	assert_false(ui.get_node("ContentLayer/MenuButton").visible)


func test_main_game_dreamcatcher_net_sits_above_cloud():
	var rm = get_node_or_null("/root/RunManager")
	assert_not_null(rm)
	if rm:
		rm.current_act = 1
	var ui = MainGameUI.instantiate()
	add_child_autofree(ui)
	await get_tree().create_timer(0.2).timeout

	var panel := ui.get_node_or_null("ContentLayer/DreamcatcherPanel") as TextureRect
	assert_not_null(panel)
	assert_not_null(panel.texture)
	assert_eq(panel.texture.resource_path, "res://assets/ui/battle/dreamcatcher_cloud.png")

	assert_null(ui.get_node_or_null("ContentLayer/DreamcatcherPanel/DreamcatcherOverlay"))

	var net := ui.get_node_or_null("ContentLayer/DreamcatcherPanel/DreamcatcherNet") as Sprite2D
	assert_not_null(net)
	assert_not_null(net.texture)
	assert_eq(net.texture.resource_path, "res://assets/ui/battle/dreamcatchers/act_1_xiaomi.png")
	assert_eq(net.texture.get_size(), Vector2(456.0, 605.0))
	_assert_dreamcatcher_net_centered_on_cloud(panel, net)
	assert_false(net.region_enabled)
	assert_null(net.material)

	var draw_button := ui.get_node_or_null("ContentLayer/DreamcatcherPanel/DrawButton") as TextureButton
	assert_not_null(draw_button)
	assert_true(net.get_index() < draw_button.get_index())


func test_main_game_dreamcatcher_net_tracks_current_stage():
	var rm = get_node_or_null("/root/RunManager")
	assert_not_null(rm)
	if rm:
		rm.current_act = 4
	var ui = MainGameUI.instantiate()
	add_child_autofree(ui)
	await get_tree().create_timer(0.2).timeout

	var panel := ui.get_node_or_null("ContentLayer/DreamcatcherPanel") as TextureRect
	assert_not_null(panel)
	var net := ui.get_node_or_null("ContentLayer/DreamcatcherPanel/DreamcatcherNet") as Sprite2D
	assert_not_null(net)
	assert_not_null(net.texture)
	assert_eq(net.texture.resource_path, "res://assets/ui/battle/dreamcatchers/act_4_parents.png")
	assert_eq(net.texture.get_size(), Vector2(410.0, 469.0))
	_assert_dreamcatcher_net_centered_on_cloud(panel, net)


func test_dreamcatcher_animation_swings_net_from_high_pivot_without_moving_cloud():
	var ui = MainGameUI.instantiate()
	add_child_autofree(ui)
	await get_tree().create_timer(0.2).timeout

	var panel := ui.get_node_or_null("ContentLayer/DreamcatcherPanel") as TextureRect
	var net := ui.get_node_or_null("ContentLayer/DreamcatcherPanel/DreamcatcherNet") as Sprite2D
	assert_not_null(panel)
	assert_null(ui.get_node_or_null("ContentLayer/DreamcatcherPanel/DreamcatcherOverlay"))
	assert_not_null(net)

	var panel_position: Vector2 = panel.position
	var panel_rotation: float = panel.rotation
	var panel_scale: Vector2 = panel.scale
	var net_position: Vector2 = net.position
	var net_rotation: float = net.rotation
	var net_offset: Vector2 = net.offset
	assert_gt(net_offset.y, net.texture.get_size().y * 0.75)
	await ui._play_dreamcatcher_animation()

	assert_eq(panel.position, panel_position)
	assert_almost_eq(panel.rotation, panel_rotation, 0.001)
	assert_eq(panel.scale, panel_scale)
	assert_eq(net.position, net_position)
	assert_almost_eq(net.rotation, net_rotation, 0.001)
	assert_eq(net.offset, net_offset)


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
	assert_eq(overlay_root.get_child_count(), 1)
	assert_true(GlobalInput.is_context(GlobalInput.Context.LOCKED))

	await get_tree().create_timer(2.0).timeout
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


func test_hub_shows_merchant_animation_on_shop_node():
	var rm = get_node_or_null("/root/RunManager")
	assert_not_null(rm)
	rm.is_run_active = true
	rm.current_act = 1
	rm.current_route_index = 1

	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var merchant_sprite := hub.get_node_or_null("HubArt/MerchantSprite") as AnimatedSprite2D
	assert_not_null(merchant_sprite)
	assert_true(merchant_sprite.visible)
	assert_not_null(merchant_sprite.sprite_frames)
	assert_true(merchant_sprite.sprite_frames.has_animation("idle"))
	assert_eq(merchant_sprite.sprite_frames.get_frame_count("idle"), 11)
	assert_false(merchant_sprite.sprite_frames.get_animation_loop("idle"))
	assert_eq(
		merchant_sprite.sprite_frames.get_frame_texture("idle", 0).resource_path,
		"res://assets/characters/merchant/cat/cat_0000.png"
	)
	assert_false(merchant_sprite.is_playing())
	assert_eq(merchant_sprite.frame, 0)

	merchant_sprite.speed_scale = 100.0
	hub._on_merchant_button_mouse_entered()
	assert_true(merchant_sprite.is_playing())
	await get_tree().create_timer(0.2).timeout
	assert_false(merchant_sprite.is_playing())
	assert_eq(merchant_sprite.frame, merchant_sprite.sprite_frames.get_frame_count("idle") - 1)

	var merchant_button := hub.get_node_or_null("CanvasLayer/MerchantButton") as Button
	assert_not_null(merchant_button)
	assert_true(merchant_button.visible)
	assert_false(merchant_button.disabled)
	assert_true(merchant_button.size.x > 0.0)
	assert_true(merchant_button.size.y > 0.0)


func test_hub_keeps_merchant_visible_before_shop_node_but_disables_entry():
	var rm = get_node_or_null("/root/RunManager")
	assert_not_null(rm)
	rm.is_run_active = true
	rm.current_act = 1
	rm.current_route_index = 0

	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var merchant_sprite := hub.get_node_or_null("HubArt/MerchantSprite") as AnimatedSprite2D
	var merchant_button := hub.get_node_or_null("CanvasLayer/MerchantButton") as Button
	assert_not_null(merchant_sprite)
	assert_not_null(merchant_button)
	assert_true(merchant_sprite.visible)
	assert_true(merchant_button.visible)
	assert_false(merchant_button.disabled)
	assert_false(merchant_sprite.is_playing())

	hub._on_merchant_button_pressed()
	assert_eq(rm.current_route_index, 0)
	assert_true(GlobalInput.is_context(GlobalInput.Context.WORLD))


func test_hub_zone_triggers_do_not_show_current_prompt_bubbles():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var speech_bubble := hub.get_node_or_null("HubArt/SpeechBubble") as Sprite2D
	var speech_text := hub.get_node_or_null("HubArt/SpeechText") as Label
	assert_not_null(speech_bubble)
	assert_not_null(speech_text)

	hub._on_battle_trigger_body_entered(null)
	assert_false(speech_bubble.visible)
	assert_false(speech_text.visible)

	hub._on_shop_trigger_body_entered(null)
	assert_false(speech_bubble.visible)
	assert_false(speech_text.visible)

	hub._on_gallery_trigger_body_entered(null)
	assert_false(speech_bubble.visible)
	assert_false(speech_text.visible)


func test_hub_scene_applies_stage_background_and_foreground():
	var rm = get_node_or_null("/root/RunManager")
	assert_not_null(rm)
	rm.is_run_active = true
	rm.current_act = 2

	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var room := hub.get_node_or_null("HubArt/Room") as Sprite2D
	assert_not_null(room)
	assert_not_null(room.texture)
	assert_eq(room.texture.resource_path, "res://assets/ui/hub/backgrounds/xiaojia.png")
	assert_eq(room.position, Vector2(156.0, 50.0))
	assert_true(room.scale.x > 0.0)
	assert_eq(room.scale.x, room.scale.y)

	var foreground := hub.get_node_or_null("HubArt/Foreground") as Sprite2D
	assert_not_null(foreground)
	assert_true(foreground.visible)
	assert_not_null(foreground.texture)
	assert_eq(foreground.texture.resource_path, "res://assets/ui/hub/backgrounds/xiaojia_foreground.png")
	assert_eq(foreground.position, room.position)
	assert_eq(foreground.scale, room.scale)


func test_hub_scene_keeps_default_room_art_without_active_run():
	var rm = get_node_or_null("/root/RunManager")
	assert_not_null(rm)
	rm.is_run_active = false
	rm.current_act = 2

	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var room := hub.get_node_or_null("HubArt/Room") as Sprite2D
	assert_not_null(room)
	assert_not_null(room.texture)
	assert_eq(room.texture.resource_path, "res://assets/ui/hub/hub_room.png")

	var foreground := hub.get_node_or_null("HubArt/Foreground") as Sprite2D
	assert_not_null(foreground)
	assert_false(foreground.visible)
	assert_null(foreground.texture)


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
