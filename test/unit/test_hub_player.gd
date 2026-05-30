extends GutTest

const HubScene = preload("res://src/ui/hub/hub_scene.tscn")
const MainGameUI = preload("res://src/ui/main_game_ui.tscn")
const BookBackgroundConfig = preload("res://src/ui/book/book_background_config.gd")

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


func _get_scaled_sprite_offset(sprite: Sprite2D) -> Vector2:
	return Vector2(sprite.offset.x * sprite.scale.x, sprite.offset.y * sprite.scale.y)


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
	assert_almost_eq(content_layer.size.x, 1920.0, 0.01)
	assert_almost_eq(content_layer.size.y, 1080.0, 0.01)
	assert_true(content_layer.scale.x > 0.0)
	assert_almost_eq(content_layer.scale.x, content_layer.scale.y, 0.001)
	var content_end := content_layer.position + content_layer.size * content_layer.scale
	assert_lte(content_layer.position.x, 0.01)
	assert_lte(content_layer.position.y, 0.01)
	assert_gte(content_end.x, viewport_size.x - 0.01)
	assert_gte(content_end.y, viewport_size.y - 0.01)
	var background := ui.get_node_or_null("Background") as ColorRect
	assert_not_null(background)
	assert_false(background.visible)
	var overlay_art := ui.get_node_or_null("ContentLayer/BackpackOverlayArt") as Control
	assert_not_null(overlay_art)
	assert_true(overlay_art.visible)
	assert_eq(overlay_art.position, Vector2.ZERO)
	assert_eq(overlay_art.size, BookBackgroundConfig.DESIGN_SIZE)
	assert_eq(overlay_art.scale, Vector2.ONE)
	assert_true(overlay_art.has_method("get_visible_page_sheet_count"))
	assert_eq(overlay_art.call("get_visible_page_sheet_count"), 2)
	var overlay_album_page := ui.get_node_or_null("ContentLayer/BackpackOverlayArt/AlbumPage") as TextureRect
	var overlay_backpack_tab := ui.get_node_or_null("ContentLayer/BackpackOverlayArt/BackpackTab") as TextureRect
	var overlay_settings_tab := ui.get_node_or_null("ContentLayer/BackpackOverlayArt/SettingsTab") as TextureRect
	assert_not_null(overlay_album_page)
	assert_not_null(overlay_backpack_tab)
	assert_not_null(overlay_settings_tab)
	assert_true(overlay_backpack_tab.visible)
	assert_true(overlay_settings_tab.visible)
	assert_eq(overlay_backpack_tab.z_index, BookBackgroundConfig.get_tab_z_index(BookBackgroundConfig.PAGE_BACKPACK, BookBackgroundConfig.PAGE_BACKPACK))
	assert_true(overlay_backpack_tab.z_index > overlay_album_page.z_index)
	assert_true(overlay_settings_tab.z_index < overlay_backpack_tab.z_index)
	assert_true(ui.get_node("ContentLayer/BackpackOverlayGridPanel").visible)
	assert_false(ui.get_node("ContentLayer/GridPanel").visible)
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
	ui.set("play_battle_intro", false)
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
	ui.set("play_battle_intro", false)
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
	ui.set("play_battle_intro", false)
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


func test_main_game_intro_prepares_bag_reveal_and_hidden_targets():
	var ui = MainGameUI.instantiate()
	ui.set("play_battle_intro", false)
	add_child_autofree(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	ui.set("play_battle_intro", true)
	var stats_panel := ui.get_node("ContentLayer/StatsPanel") as Control
	var ornaments_panel := ui.get_node("ContentLayer/OrnamentsPanel") as Control
	var grid_panel := ui.get_node("ContentLayer/GridPanel") as Control
	var stats_target := stats_panel.position
	var ornaments_target := ornaments_panel.position

	ui.call("_prepare_intro_animation")

	assert_true(bool(ui.get("_intro_playing")))
	assert_false(grid_panel.visible)
	assert_almost_eq(grid_panel.modulate.a, 0.0, 0.001)
	assert_eq(stats_panel.position, stats_target + ui.get("intro_stats_start_offset"))
	assert_almost_eq(stats_panel.modulate.a, 0.0, 0.001)
	assert_eq(ornaments_panel.position, ornaments_target + ui.get("intro_ornaments_start_offset"))
	assert_false(ornaments_panel.visible)

	var frame_paths: PackedStringArray = ui.call("_get_intro_bag_frame_paths")
	assert_eq(frame_paths.size(), 5)
	assert_eq(frame_paths[0], "res://assets/ui/battle/intro_bag_reveal/bag_reveal_01.png")
	assert_eq(frame_paths[3], "res://assets/ui/battle/intro_bag_reveal/bag_reveal_04.png")
	assert_eq(frame_paths[4], "res://assets/ui/battle/intro_bag_reveal/bag_reveal_05.png")


func test_main_game_intro_finishes_into_battle_context():
	var ui = MainGameUI.instantiate()
	ui.set("intro_bag_frame_time", 0.01)
	ui.set("intro_bag_final_hold", 0.0)
	ui.set("intro_stats_rise_duration", 0.01)
	ui.set("intro_ornaments_slide_duration", 0.01)
	ui.set("intro_grid_reveal_duration", 0.01)
	ui.set("intro_bag_frame_1_path", "")
	ui.set("intro_bag_frame_2_path", "")
	ui.set("intro_bag_frame_3_path", "")
	ui.set("intro_bag_frame_4_path", "")
	ui.set("intro_bag_frame_5_path", "")
	add_child_autofree(ui)

	await get_tree().create_timer(1.0).timeout

	var grid_panel := ui.get_node("ContentLayer/GridPanel") as Control
	var stats_panel := ui.get_node("ContentLayer/StatsPanel") as Control
	var ornaments_panel := ui.get_node("ContentLayer/OrnamentsPanel") as Control
	assert_false(bool(ui.get("_intro_playing")))
	assert_true(GlobalInput.is_context(GlobalInput.Context.BATTLE))
	assert_true(grid_panel.visible)
	assert_almost_eq(grid_panel.modulate.a, 1.0, 0.001)
	assert_true(stats_panel.visible)
	assert_almost_eq(stats_panel.modulate.a, 1.0, 0.001)
	assert_true(ornaments_panel.visible)
	assert_almost_eq(ornaments_panel.modulate.a, 1.0, 0.001)
	assert_null(ui.get_node_or_null("ContentLayer/IntroBagReveal"))


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


func test_hub_left_bookmark_click_does_not_move_player():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout
	GlobalInput.set_context(GlobalInput.Context.WORLD)
	var hub_player = hub.get_node("Player")
	hub_player.clear_move_target()

	var bookmark_paths := [
		"CanvasLayer/DesignRoot/RouteButton",
		"CanvasLayer/DesignRoot/BackpackButton",
		"CanvasLayer/DesignRoot/GalleryButton",
		"CanvasLayer/DesignRoot/SettingsButton",
	]
	for path in bookmark_paths:
		var button := hub.get_node_or_null(path) as Control
		assert_not_null(button)
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = button.get_global_rect().get_center()
		hub._unhandled_input(event)
		assert_false(hub_player.has_move_target, "%s should not move the player." % path)


func test_hub_player_walk_bounds_are_limited_to_scene_range():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout
	GlobalInput.set_context(GlobalInput.Context.WORLD)
	var hub_player = hub.get_node("Player")

	var min_x: float = hub._source_x_to_viewport(hub.PLAYER_WALK_MIN_SOURCE_X)
	var max_x: float = hub._source_x_to_viewport(hub.PLAYER_WALK_MAX_SOURCE_X)
	assert_true(hub_player.has_walk_bounds)
	assert_eq(hub_player.walk_min_x, min_x)
	assert_eq(hub_player.walk_max_x, max_x)

	hub_player.move_to_global_x(min_x - 500.0)
	assert_eq(hub_player.move_target_x, min_x)
	hub_player.move_to_global_x(max_x + 500.0)
	assert_eq(hub_player.move_target_x, max_x)


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


func test_hub_merchant_animation_follows_player_arrival_and_departure():
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

	var hub_player := hub.get_node_or_null("Player") as CharacterBody2D
	assert_not_null(hub_player)
	var merchant_x: float = hub._get_merchant_interaction_target_x()
	var merchant_rect: Rect2 = hub._get_merchant_interaction_viewport_rect()
	assert_true(merchant_rect.size.x > 0.0)
	assert_true(merchant_rect.size.y > 0.0)
	merchant_sprite.speed_scale = 100.0
	hub_player.global_position.x = merchant_rect.position.x + 1.0
	hub._sync_merchant_presence_state()
	assert_true(merchant_sprite.is_playing())
	await get_tree().create_timer(0.2).timeout
	assert_false(merchant_sprite.is_playing())
	assert_eq(merchant_sprite.frame, merchant_sprite.sprite_frames.get_frame_count("idle") - 1)

	hub._sync_merchant_presence_state()
	assert_false(merchant_sprite.is_playing())
	assert_eq(merchant_sprite.frame, merchant_sprite.sprite_frames.get_frame_count("idle") - 1)

	var exit_padding: float = hub.MERCHANT_INTERACTION_EXIT_PADDING_SOURCE_X * hub._art_scale
	hub_player.global_position.x = merchant_rect.position.x - hub._get_player_collision_half_width() - exit_padding - 32.0
	hub._sync_merchant_presence_state()
	assert_true(merchant_sprite.is_playing())
	await get_tree().create_timer(0.2).timeout
	assert_false(merchant_sprite.is_playing())
	assert_eq(merchant_sprite.frame, 0)

	var merchant_button := hub.get_node_or_null("CanvasLayer/MerchantButton") as Button
	assert_not_null(merchant_button)
	assert_true(merchant_button.visible)
	assert_false(merchant_button.disabled)
	assert_true(merchant_button.size.x > 0.0)
	assert_true(merchant_button.size.y > 0.0)
	var room := hub.get_node_or_null("HubArt/Room") as Sprite2D
	assert_not_null(room)
	var frame_bounds: Rect2 = hub.MERCHANT_FRAME_BOUNDS[hub._get_merchant_animation_key()]
	var unshifted_center: float = hub._source_x_to_viewport(room.position.x + frame_bounds.get_center().x * room.scale.x)
	assert_almost_eq(unshifted_center - merchant_x, absf(hub.MERCHANT_INTERACTION_SOURCE_OFFSET_X) * hub._art_scale, 0.01)


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


func test_hub_dreamcatcher_is_stage_art_and_battle_entry_hotspot():
	var rm = get_node_or_null("/root/RunManager")
	assert_not_null(rm)
	rm.is_run_active = true
	rm.current_act = 1
	rm.current_route_index = 0

	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var net := hub.get_node_or_null("HubArt/DreamcatcherNet") as Sprite2D
	assert_not_null(net)
	assert_not_null(net.texture)
	assert_eq(net.texture.resource_path, "res://assets/ui/battle/dreamcatchers/act_1_xiaomi.png")
	assert_eq(net.scale, Vector2(0.663, 0.663))
	assert_false(net.region_enabled)
	assert_null(net.material)
	assert_gt(net.offset.y, net.texture.get_size().y * 0.75)

	hub._stop_hub_dreamcatcher_idle_swing()
	net.position = hub._dreamcatcher_net_base_position
	net.rotation = hub._dreamcatcher_net_base_rotation
	net.offset = hub._dreamcatcher_net_base_offset
	var visual_center := net.position + _get_scaled_sprite_offset(net).rotated(net.rotation)
	assert_almost_eq(visual_center.x, 918.0, 0.01)
	assert_almost_eq(visual_center.y, 624.0, 0.01)

	var dreamcatcher_button := hub.get_node_or_null("CanvasLayer/DesignRoot/DreamcatcherButton") as Button
	assert_not_null(dreamcatcher_button)
	assert_false(dreamcatcher_button.disabled)
	assert_true(dreamcatcher_button.pressed.is_connected(Callable(hub, "_on_dreamcatcher_button_pressed")))
	assert_true(hub._is_dreamcatcher_game_available())


func test_hub_z_shortcut_enters_battle_without_hidden_layer_locking_input():
	var rm = get_node_or_null("/root/RunManager")
	assert_not_null(rm)
	rm.is_run_active = true
	rm.current_act = 1
	rm.current_route_index = 0
	rm.completed_route_nodes = [] as Array[int]
	GlobalInput.set_context(GlobalInput.Context.WORLD)

	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	assert_true(GlobalInput.is_context(GlobalInput.Context.WORLD))
	var event := InputEventKey.new()
	event.keycode = KEY_Z
	event.physical_keycode = KEY_Z
	event.pressed = true
	hub._input(event)
	await get_tree().create_timer(2.0).timeout

	var battle_layer := hub.get_node_or_null("CanvasLayer/BattleLayer") as Control
	assert_not_null(battle_layer)
	assert_true(battle_layer.visible)
	assert_true(bool(hub.get("_is_hub_battle_session_active")))


func test_hub_route_tab_no_longer_drives_route_progression():
	var rm = get_node_or_null("/root/RunManager")
	assert_not_null(rm)
	rm.is_run_active = true
	rm.current_act = 1
	rm.current_route_index = 0

	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout
	var hub_player := hub.get_node_or_null("Player") as CharacterBody2D
	assert_not_null(hub_player)
	hub_player.clear_move_target()
	hub._pending_auto_interaction = ""

	var route_button := hub.get_node_or_null("CanvasLayer/DesignRoot/RouteButton") as Button
	assert_not_null(route_button)
	route_button.pressed.emit()

	assert_eq(rm.current_route_index, 0)
	assert_eq(hub._pending_auto_interaction, "")
	assert_false(hub_player.has_move_target)


func test_hub_z_shortcut_skips_unimplemented_event_node():
	var rm = get_node_or_null("/root/RunManager")
	assert_not_null(rm)
	rm.is_run_active = true
	rm.current_act = 1
	rm.current_route_index = 2
	rm.completed_route_nodes = [] as Array[int]

	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	assert_true(hub._advance_current_route_by_shortcut())
	assert_eq(rm.current_route_index, 3)
	assert_true(rm.completed_route_nodes.has(2))


func test_hub_dreamcatcher_tracks_current_stage_and_disables_on_shop_node():
	var rm = get_node_or_null("/root/RunManager")
	assert_not_null(rm)
	rm.is_run_active = true
	rm.current_act = 4
	rm.current_route_index = 0

	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var net := hub.get_node_or_null("HubArt/DreamcatcherNet") as Sprite2D
	assert_not_null(net)
	assert_not_null(net.texture)
	assert_eq(net.texture.resource_path, "res://assets/ui/battle/dreamcatchers/act_4_parents.png")
	assert_true(hub._is_dreamcatcher_game_available())

	var dreamcatcher_button := hub.get_node_or_null("CanvasLayer/DesignRoot/DreamcatcherButton") as Button
	assert_not_null(dreamcatcher_button)
	assert_false(dreamcatcher_button.disabled)

	rm.current_route_index = 1
	hub._on_route_changed(rm.current_act, rm.current_route_index, rm.get_current_route_node())
	assert_false(hub._is_dreamcatcher_game_available())
	assert_true(dreamcatcher_button.disabled)


func test_hub_dreamcatcher_start_swing_returns_to_base_pose():
	var rm = get_node_or_null("/root/RunManager")
	assert_not_null(rm)
	rm.is_run_active = true
	rm.current_act = 1
	rm.current_route_index = 0

	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var net := hub.get_node_or_null("HubArt/DreamcatcherNet") as Sprite2D
	assert_not_null(net)
	hub._stop_hub_dreamcatcher_idle_swing()
	var base_position: Vector2 = hub._dreamcatcher_net_base_position
	var base_rotation: float = hub._dreamcatcher_net_base_rotation
	var base_offset: Vector2 = hub._dreamcatcher_net_base_offset

	await hub._play_hub_dreamcatcher_start_swing()

	assert_eq(net.position, base_position)
	assert_almost_eq(net.rotation, base_rotation, 0.001)
	assert_eq(net.offset, base_offset)


func test_hub_book_page_navigator_opens_gallery_and_returns_to_hub():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var navigator := hub.get_node_or_null("CanvasLayer/BookPageNavigator") as Control
	assert_not_null(navigator)
	var turn_effect := navigator.get_node_or_null("PageTurnEffect") as Control
	assert_not_null(turn_effect)
	assert_true(turn_effect.has_method("start_turn"))
	assert_true(turn_effect.has_method("finish_turn"))
	assert_false(turn_effect.visible)
	assert_null(navigator.get_node_or_null("TurnSheet"))
	assert_null(navigator.get_node_or_null("TurnShadow"))
	assert_eq(navigator.current_page_id, "hub")
	assert_eq(navigator.PAGE_STACK_Z["hub"], 0)
	assert_eq(navigator.PAGE_STACK_Z["gallery"], -1)
	assert_eq(navigator.PAGE_STACK_Z["backpack"], -2)
	assert_eq(navigator.PAGE_STACK_Z["settings"], -3)
	assert_eq(navigator.get_visual_turn_direction("hub", "gallery"), 1)
	assert_eq(navigator.get_visual_turn_direction("gallery", "hub"), -1)
	assert_eq(navigator.get_visual_turn_direction("gallery", "settings"), 1)
	assert_eq(navigator.get_visual_turn_direction("settings", "backpack"), -1)
	var page_sheet := hub.get_node("BookCanvasLayer/BookDesignRoot/BookBackground/AlbumPage") as TextureRect
	var page_sheet_rect := page_sheet.get_global_rect()

	hub._open_book_page("gallery")
	await get_tree().create_timer(0.1).timeout
	assert_true(turn_effect.visible)
	var turn_material := turn_effect.material as ShaderMaterial
	assert_not_null(turn_material)
	assert_almost_eq(float(turn_material.get_shader_parameter("turn_direction")), -1.0, 0.001)
	assert_almost_eq(turn_effect.position.x, page_sheet_rect.position.x, 1.0)
	assert_almost_eq(turn_effect.position.y, page_sheet_rect.position.y, 1.0)
	assert_almost_eq(turn_effect.size.x, page_sheet_rect.size.x, 1.0)
	await get_tree().create_timer(0.75).timeout

	assert_eq(navigator.current_page_id, "gallery")
	assert_false(turn_effect.visible)
	assert_false(hub.get_node("BookCanvasLayer").visible)
	assert_false(hub.get_node("HubArt").visible)
	assert_false(hub.get_node("CanvasLayer/DesignRoot").visible)
	var gallery_page := navigator.get_node_or_null("GalleryPage") as Control
	assert_not_null(gallery_page)
	assert_true(gallery_page.visible)
	assert_true(GlobalInput.is_context(GlobalInput.Context.UI))

	navigator.go_to_page("hub")
	await get_tree().create_timer(0.1).timeout
	assert_true(turn_effect.visible)
	assert_almost_eq(float(turn_material.get_shader_parameter("turn_direction")), -1.0, 0.001)
	await get_tree().create_timer(0.85).timeout

	assert_eq(navigator.current_page_id, "hub")
	assert_true(hub.get_node("BookCanvasLayer").visible)
	assert_true(hub.get_node("HubArt").visible)
	assert_true(hub.get_node("CanvasLayer/DesignRoot").visible)
	assert_true(GlobalInput.is_context(GlobalInput.Context.WORLD))


func test_hub_book_page_navigator_repositions_right_side_tabs_between_pages():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var navigator := hub.get_node_or_null("CanvasLayer/BookPageNavigator") as Control
	assert_not_null(navigator)

	hub._open_book_page("settings")
	await get_tree().create_timer(0.75).timeout

	var viewport_center_x := get_viewport().get_visible_rect().size.x * 0.5
	var hub_tab := navigator.get_node_or_null("HubTabButton") as Button
	var backpack_tab := navigator.get_node_or_null("BackpackTabButton") as Button
	var gallery_tab := navigator.get_node_or_null("GalleryTabButton") as Button
	var settings_tab := navigator.get_node_or_null("SettingsTabButton") as Button
	assert_not_null(hub_tab)
	assert_not_null(backpack_tab)
	assert_not_null(gallery_tab)
	assert_not_null(settings_tab)
	assert_true(hub_tab.visible)
	assert_true(backpack_tab.visible)
	assert_true(gallery_tab.visible)
	assert_false(settings_tab.visible)
	assert_true(hub_tab.position.x > viewport_center_x)
	assert_true(hub_tab.position.y < backpack_tab.position.y)
	assert_true(backpack_tab.position.x > viewport_center_x)
	assert_true(gallery_tab.position.x > viewport_center_x)

	gallery_tab.pressed.emit()
	await get_tree().create_timer(0.75).timeout

	assert_eq(navigator.current_page_id, "gallery")
	assert_true(GlobalInput.is_context(GlobalInput.Context.UI))


func test_hub_book_page_navigator_red_tab_returns_to_hub():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var navigator := hub.get_node_or_null("CanvasLayer/BookPageNavigator") as Control
	assert_not_null(navigator)

	hub._open_book_page("settings")
	await get_tree().create_timer(0.75).timeout

	var hub_tab := navigator.get_node_or_null("HubTabButton") as Button
	assert_not_null(hub_tab)
	assert_true(hub_tab.visible)
	assert_true(hub_tab.position.x > get_viewport().get_visible_rect().size.x * 0.5)
	assert_true(hub_tab.position.y > 100.0)

	hub_tab.pressed.emit()
	await get_tree().create_timer(0.75).timeout

	assert_eq(navigator.current_page_id, "hub")
	assert_true(hub.get_node("BookCanvasLayer").visible)
	assert_true(hub.get_node("HubArt").visible)
	assert_true(GlobalInput.is_context(GlobalInput.Context.WORLD))


func test_hub_book_page_navigator_opens_backpack_overlay_mode():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var navigator := hub.get_node_or_null("CanvasLayer/BookPageNavigator") as Control
	assert_not_null(navigator)

	hub._open_book_page("backpack")
	await get_tree().create_timer(0.9).timeout

	assert_eq(navigator.current_page_id, "backpack")
	var backpack_page := navigator.get_node_or_null("BackpackPage") as Control
	assert_not_null(backpack_page)
	assert_true(backpack_page.visible)
	assert_true(bool(backpack_page.call("_is_backpack_overlay_mode")))
	assert_not_null(backpack_page.get("battle_manager"))
	assert_false((backpack_page.get_node("ContentLayer/BattleArt") as Control).visible)
	assert_true((backpack_page.get_node("ContentLayer/BackpackOverlayArt") as Control).visible)
	assert_true((backpack_page.get_node("ContentLayer/BackpackOverlayGridPanel") as Control).visible)
	assert_true(GlobalInput.is_context(GlobalInput.Context.UI))


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
	assert_eq(room.position, Vector2(188.0, 74.0))
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

	var background := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground/WoodFloor") as TextureRect
	assert_not_null(background)
	assert_not_null(background.texture)
	assert_eq(background.texture.resource_path, "res://assets/ui/book/wood_floor.png")
	assert_eq(background.size, BookBackgroundConfig.DESIGN_SIZE)

	for node_path in [
		"BookCanvasLayer/BookDesignRoot/BookBackground/PageRouteCover",
		"BookCanvasLayer/BookDesignRoot/BookBackground/PageBackpackCover",
		"BookCanvasLayer/BookDesignRoot/BookBackground/PageMiddle",
		"BookCanvasLayer/BookDesignRoot/BookBackground/AlbumPage",
		"BookCanvasLayer/BookDesignRoot/BookBackground/AlbumRingRight",
		"BookCanvasLayer/BookDesignRoot/BookBackground/AlbumTab",
		"BookCanvasLayer/BookDesignRoot/BookBackground/BackpackTab",
		"BookCanvasLayer/BookDesignRoot/BookBackground/GalleryTab",
		"BookCanvasLayer/BookDesignRoot/BookBackground/SettingsTab",
	]:
		var art := hub.get_node_or_null(node_path) as TextureRect
		assert_not_null(art, "Hub book background should expose %s" % node_path)
		assert_not_null(art.texture)
		assert_true(art.texture.resource_path != "res://assets/ui/hub/hub_background.png")

	for node_path in [
		"HubArt/Room",
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

	var book_background := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground") as Control
	assert_not_null(book_background)
	assert_true(book_background.has_method("get_visible_page_sheet_count"))
	assert_true(book_background.has_method("get_page_turn_sheet_info"))
	assert_eq(book_background.call("get_visible_page_sheet_count"), 4)

	var page := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground/AlbumPage") as TextureRect
	var turn_sheet_info: Dictionary = book_background.call("get_page_turn_sheet_info")
	var page_route_cover := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground/PageRouteCover") as TextureRect
	var page_backpack_cover := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground/PageBackpackCover") as TextureRect
	var page_middle := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground/PageMiddle") as TextureRect
	var ring_right := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground/AlbumRingRight") as TextureRect
	assert_eq(turn_sheet_info.get("texture"), page.texture)
	assert_eq(turn_sheet_info.get("global_rect"), page.get_global_rect())
	assert_true(page_route_cover.position.x < page_backpack_cover.position.x)
	assert_true(page_backpack_cover.position.x < page_middle.position.x)
	assert_true(page_middle.position.x < page.position.x)
	assert_almost_eq(page_route_cover.position.y, -8.0, 0.01)
	assert_almost_eq(page_backpack_cover.position.y, 2.0, 0.01)
	assert_almost_eq(page_middle.position.y, 10.0, 0.01)
	assert_almost_eq(page.position.y, 18.0, 0.01)
	assert_almost_eq(ring_right.position.y, page.position.y, 0.01)
	assert_almost_eq(ring_right.size.y, page.size.y, 0.01)

	var route_tab := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground/AlbumTab") as TextureRect
	var backpack_tab := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground/BackpackTab") as TextureRect
	var gallery_tab := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground/GalleryTab") as TextureRect
	var settings_tab := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground/SettingsTab") as TextureRect
	var hub_player := hub.get_node_or_null("Player") as CharacterBody2D
	var dreamcatcher_net := hub.get_node_or_null("HubArt/DreamcatcherNet") as Sprite2D
	var merchant_sprite := hub.get_node_or_null("HubArt/MerchantSprite") as AnimatedSprite2D
	var speech_bubble_for_z := hub.get_node_or_null("HubArt/SpeechBubble") as Sprite2D
	var room := hub.get_node_or_null("HubArt/Room") as Sprite2D
	var top_right_corner := hub.get_node_or_null("HubArt/CornerTopRight") as Sprite2D
	var bottom_right_corner := hub.get_node_or_null("HubArt/CornerBottomRight") as Sprite2D
	var hub_offset: Vector2 = hub.get("hub_art_source_offset")
	assert_eq(hub_offset, Vector2(0.0, 14.0))
	assert_not_null(ring_right)
	assert_not_null(room)
	assert_not_null(room.texture)
	assert_not_null(top_right_corner)
	assert_not_null(bottom_right_corner)
	var room_right_edge := room.position.x + room.texture.get_size().x * room.scale.x
	assert_almost_eq(room_right_edge, ring_right.position.x, 0.25)
	assert_almost_eq(top_right_corner.position.x, ring_right.position.x, 0.01)
	assert_almost_eq(bottom_right_corner.position.x, ring_right.position.x, 0.01)
	assert_eq(route_tab.z_index, BookBackgroundConfig.get_tab_z_index(BookBackgroundConfig.PAGE_HUB))
	assert_eq(gallery_tab.z_index, BookBackgroundConfig.get_tab_z_index(BookBackgroundConfig.PAGE_GALLERY))
	assert_eq(backpack_tab.z_index, BookBackgroundConfig.get_tab_z_index(BookBackgroundConfig.PAGE_BACKPACK))
	assert_eq(settings_tab.z_index, BookBackgroundConfig.get_tab_z_index(BookBackgroundConfig.PAGE_SETTINGS))
	assert_true(route_tab.z_index > gallery_tab.z_index)
	assert_true(gallery_tab.z_index > backpack_tab.z_index)
	assert_true(backpack_tab.z_index > settings_tab.z_index)
	assert_true(route_tab.z_index > page.z_index)
	assert_true(gallery_tab.z_index > page_middle.z_index)
	assert_true(gallery_tab.z_index < page.z_index)
	assert_true(backpack_tab.z_index > page_backpack_cover.z_index)
	assert_true(backpack_tab.z_index < page_middle.z_index)
	assert_true(settings_tab.z_index > page_route_cover.z_index)
	assert_true(settings_tab.z_index < page_backpack_cover.z_index)
	assert_not_null(hub_player)
	assert_not_null(dreamcatcher_net)
	assert_not_null(merchant_sprite)
	assert_not_null(speech_bubble_for_z)
	assert_true(hub_player.z_index > dreamcatcher_net.z_index)
	assert_true(hub_player.z_index > merchant_sprite.z_index)
	assert_true(hub_player.z_index < speech_bubble_for_z.z_index)

	var route_button := hub.get_node_or_null("CanvasLayer/DesignRoot/RouteButton") as Button
	assert_not_null(route_button)
	assert_false(route_button.tooltip_text.is_empty())
	assert_true(route_button.pressed.is_connected(Callable(hub, "_on_route_button_pressed")))

	var backpack_button := hub.get_node_or_null("CanvasLayer/DesignRoot/BackpackButton") as Button
	assert_not_null(backpack_button)
	assert_eq(backpack_button.tooltip_text, "整理背包")
	assert_true(backpack_button.pressed.is_connected(Callable(hub, "_on_backpack_button_pressed")))

	var gallery_button := hub.get_node_or_null("CanvasLayer/DesignRoot/GalleryButton") as Button
	assert_not_null(gallery_button)
	assert_eq(gallery_button.tooltip_text, "图鉴")
	assert_true(gallery_button.pressed.is_connected(Callable(hub, "_on_gallery_button_pressed")))

	var settings_button := hub.get_node_or_null("CanvasLayer/DesignRoot/SettingsButton") as Button
	assert_not_null(settings_button)
	assert_eq(settings_button.tooltip_text, "设置")
	assert_true(settings_button.pressed.is_connected(Callable(hub, "_on_settings_button_pressed")))

	assert_null(hub.get_node_or_null("CanvasLayer/RoutePanel"))


func test_hub_keeps_legacy_main_menu_button_hidden_from_left_tabs():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var button := hub.get_node_or_null("CanvasLayer/DesignRoot/MainMenuButton") as Button
	assert_not_null(button)
	assert_false(button.tooltip_text.is_empty())
	assert_false(button.visible)
	assert_true(button.pressed.is_connected(Callable(hub, "_on_main_menu_button_pressed")))
