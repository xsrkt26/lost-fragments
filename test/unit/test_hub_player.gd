extends GutTest

const HubScene = preload("res://src/ui/hub/hub_scene.tscn")
const HubBattleLayer = preload("res://src/ui/hub/hub_battle_layer.tscn")
const MainGameUI = preload("res://src/ui/main_game_ui.tscn")
const BackpackPage = preload("res://src/ui/backpack/backpack_page.tscn")
const BookBackgroundConfig = preload("res://src/ui/book/book_background_config.gd")
const BATTLE_BAG_FINAL_FRAME_PATH := "res://assets/ui/battle/intro_bag_reveal/bag_reveal_05.png"
const BATTLE_BAG_SOURCE_SIZE := Vector2(825.0, 1008.0)
const BATTLE_BAG_GRID_SOURCE_RECT := Rect2(122.0, 380.0, 590.0, 527.0)

var player
var rm_snapshot := {}


class ReturnNavigatorStub:
	extends Node
	var return_to_main_menu_count := 0

	func return_to_main_menu() -> void:
		return_to_main_menu_count += 1


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


func _get_hub_player(hub: Node) -> CharacterBody2D:
	var hub_player := hub.get_node_or_null("HubPageVisualRoot/Player") as CharacterBody2D
	if hub_player == null:
		hub_player = hub.get_node_or_null("Player") as CharacterBody2D
	return hub_player


func _get_hub_art(hub: Node) -> Node2D:
	var hub_art := hub.get_node_or_null("HubPageVisualRoot/HubArt") as Node2D
	if hub_art == null:
		hub_art = hub.get_node_or_null("HubArt") as Node2D
	return hub_art


func _get_texture_image(path: String) -> Image:
	var texture := load(path) as Texture2D
	assert_not_null(texture)
	if texture == null:
		return Image.new()
	var image := texture.get_image()
	assert_not_null(image)
	if image == null:
		return Image.new()
	return image


func _get_png_alpha_rect(path: String, alpha_threshold: float = 0.03) -> Rect2:
	var image := _get_texture_image(path)
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > alpha_threshold:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2()
	return Rect2(float(min_x), float(min_y), float(max_x - min_x + 1), float(max_y - min_y + 1))


func _get_png_size(path: String) -> Vector2:
	var image := _get_texture_image(path)
	return Vector2(image.get_width(), image.get_height())


func _map_alpha_rect_to_control_rect(control_rect: Rect2, texture_size: Vector2, alpha_rect: Rect2) -> Rect2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2()
	var scale := Vector2(control_rect.size.x / texture_size.x, control_rect.size.y / texture_size.y)
	return Rect2(control_rect.position + alpha_rect.position * scale, alpha_rect.size * scale)


func _assert_battle_grid_matches_bag_texture(scene_root: Node) -> void:
	var playable_bag := scene_root.get_node_or_null("ContentLayer/PlayableBagArt") as TextureRect
	var grid_panel := scene_root.get_node_or_null("ContentLayer/GridPanel") as Control
	var backpack_ui := scene_root.get_node_or_null("ContentLayer/GridPanel/BackpackUI") as Control
	assert_not_null(playable_bag)
	assert_not_null(grid_panel)
	assert_not_null(backpack_ui)
	if playable_bag == null or grid_panel == null or backpack_ui == null:
		return

	assert_eq(playable_bag.texture.resource_path, BATTLE_BAG_FINAL_FRAME_PATH)
	assert_eq(_get_png_size(BATTLE_BAG_FINAL_FRAME_PATH), BATTLE_BAG_SOURCE_SIZE)
	assert_eq(grid_panel.scale, Vector2.ONE)
	assert_eq(backpack_ui.scale, Vector2.ONE)
	assert_almost_eq(backpack_ui.rotation, 0.0, 0.001)

	var bag_rect := Rect2(playable_bag.position, playable_bag.size * playable_bag.scale)
	assert_almost_eq(grid_panel.position.x, bag_rect.position.x, 0.001)
	assert_almost_eq(grid_panel.position.y, bag_rect.position.y, 0.001)
	assert_almost_eq(grid_panel.size.x, bag_rect.size.x, 0.001)
	assert_almost_eq(grid_panel.size.y, bag_rect.size.y, 0.001)

	var expected_local_grid_rect := _map_alpha_rect_to_control_rect(
		Rect2(Vector2.ZERO, grid_panel.size),
		BATTLE_BAG_SOURCE_SIZE,
		BATTLE_BAG_GRID_SOURCE_RECT
	)
	assert_almost_eq(backpack_ui.position.x, expected_local_grid_rect.position.x, 0.01)
	assert_almost_eq(backpack_ui.position.y, expected_local_grid_rect.position.y, 0.01)
	assert_almost_eq(backpack_ui.size.x, expected_local_grid_rect.size.x, 0.01)
	assert_almost_eq(backpack_ui.size.y, expected_local_grid_rect.size.y, 0.01)


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
	var playable_bag := ui.get_node_or_null("ContentLayer/PlayableBagArt") as TextureRect
	var intro_bag := ui.get_node_or_null("ContentLayer/IntroBagReveal") as TextureRect
	var stats_target := stats_panel.position
	var ornaments_target := ornaments_panel.position
	assert_not_null(playable_bag)
	assert_not_null(intro_bag)
	assert_false(intro_bag.visible)

	ui.call("_prepare_intro_animation")

	assert_true(bool(ui.get("_intro_playing")))
	assert_false(playable_bag.visible)
	assert_false(grid_panel.visible)
	assert_almost_eq(grid_panel.modulate.a, 0.0, 0.001)
	assert_eq(stats_panel.position, stats_target + ui.get("intro_stats_start_offset"))
	assert_almost_eq(stats_panel.modulate.a, 0.0, 0.001)
	assert_eq(ornaments_panel.position, ornaments_target)
	assert_false(ornaments_panel.visible)

	var frame_paths: PackedStringArray = ui.call("_get_intro_bag_frame_paths")
	assert_eq(frame_paths.size(), 5)
	assert_eq(frame_paths[0], "res://assets/ui/battle/intro_bag_reveal/bag_reveal_01.png")
	assert_eq(frame_paths[3], "res://assets/ui/battle/intro_bag_reveal/bag_reveal_04.png")
	assert_eq(frame_paths[4], "res://assets/ui/battle/intro_bag_reveal/bag_reveal_05.png")


func test_main_game_intro_bag_reveal_is_serialized_in_scene():
	var ui = autofree(MainGameUI.instantiate())
	var playable_bag := ui.get_node_or_null("ContentLayer/PlayableBagArt") as TextureRect
	var intro_bag := ui.get_node_or_null("ContentLayer/IntroBagReveal") as TextureRect
	var grid_panel := ui.get_node_or_null("ContentLayer/GridPanel") as TextureRect
	var grid_background := ui.get_node_or_null("ContentLayer/GridPanel/GridBackground") as TextureRect
	var ornaments_panel := ui.get_node_or_null("ContentLayer/OrnamentsPanel") as TextureRect
	assert_not_null(playable_bag)
	assert_true(playable_bag.visible)
	assert_not_null(playable_bag.texture)
	assert_eq(playable_bag.texture.resource_path, "res://assets/ui/battle/intro_bag_reveal/bag_reveal_05.png")
	assert_eq(playable_bag.stretch_mode, TextureRect.STRETCH_SCALE)
	assert_not_null(grid_panel)
	assert_null(grid_panel.texture)
	assert_not_null(grid_background)
	assert_false(grid_background.visible)
	assert_null(grid_background.texture)
	assert_not_null(ornaments_panel)
	assert_null(ornaments_panel.texture)
	assert_not_null(intro_bag)
	assert_false(intro_bag.visible)
	assert_not_null(intro_bag.texture)
	assert_eq(intro_bag.texture.resource_path, "res://assets/ui/battle/intro_bag_reveal/bag_reveal_01.png")


func test_battle_backpack_ui_matches_bag_texture_grid_pixels():
	var main_game_ui = autofree(MainGameUI.instantiate())
	_assert_battle_grid_matches_bag_texture(main_game_ui)

	var hub_battle_layer = autofree(HubBattleLayer.instantiate())
	_assert_battle_grid_matches_bag_texture(hub_battle_layer)


func test_main_game_intro_bag_reveal_drops_from_upper_right_to_grid_target():
	var ui = MainGameUI.instantiate()
	ui.set("play_battle_intro", false)
	ui.set("intro_bag_drop_duration", 0.0)
	add_child_autofree(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	var intro_bag := ui.call("_show_intro_bag_reveal") as TextureRect
	var target_rect: Rect2 = ui.call("_get_intro_bag_target_rect")
	var grid_panel := ui.get_node("ContentLayer/GridPanel") as Control
	var ornaments_panel := ui.get_node("ContentLayer/OrnamentsPanel") as Control
	var playable_bag := ui.get_node("ContentLayer/PlayableBagArt") as TextureRect
	var expected_target_rect: Rect2 = ui.call("_get_control_visual_rect_in_parent", grid_panel)
	expected_target_rect = expected_target_rect.merge(ui.call("_get_control_visual_rect_in_parent", ornaments_panel))
	var drop_start_offset: Vector2 = ui.get("intro_bag_drop_start_offset")
	assert_not_null(intro_bag)
	assert_true(intro_bag.visible)
	assert_eq(intro_bag.stretch_mode, TextureRect.STRETCH_SCALE)
	assert_almost_eq(target_rect.position.x, expected_target_rect.position.x, 0.001)
	assert_almost_eq(target_rect.position.y, expected_target_rect.position.y, 0.001)
	assert_almost_eq(target_rect.size.x, expected_target_rect.size.x, 0.001)
	assert_almost_eq(target_rect.size.y, expected_target_rect.size.y, 0.001)
	assert_almost_eq(intro_bag.position.x, target_rect.position.x + drop_start_offset.x, 0.001)
	assert_almost_eq(intro_bag.position.y, target_rect.position.y + drop_start_offset.y, 0.001)
	assert_almost_eq(intro_bag.size.x, target_rect.size.x, 0.001)
	assert_almost_eq(intro_bag.size.y, target_rect.size.y, 0.001)
	assert_eq(intro_bag.scale, Vector2.ONE * float(ui.get("intro_bag_drop_start_scale")))
	assert_almost_eq(intro_bag.rotation, deg_to_rad(float(ui.get("intro_bag_drop_start_rotation_degrees"))), 0.001)

	await ui._animate_intro_bag_drop(intro_bag)

	assert_almost_eq(intro_bag.position.x, target_rect.position.x, 0.001)
	assert_almost_eq(intro_bag.position.y, target_rect.position.y, 0.001)
	assert_eq(intro_bag.scale, Vector2.ONE)
	assert_almost_eq(intro_bag.rotation, 0.0, 0.001)

	await ui._reveal_intro_grid(intro_bag)

	assert_true(playable_bag.visible)
	assert_eq(playable_bag.texture.resource_path, "res://assets/ui/battle/intro_bag_reveal/bag_reveal_05.png")
	assert_almost_eq(playable_bag.position.x, target_rect.position.x, 0.001)
	assert_almost_eq(playable_bag.position.y, target_rect.position.y, 0.001)
	assert_almost_eq(playable_bag.size.x, target_rect.size.x, 0.001)
	assert_almost_eq(playable_bag.size.y, target_rect.size.y, 0.001)
	assert_true(grid_panel.visible)
	assert_true(ornaments_panel.visible)
	assert_almost_eq(ornaments_panel.position.x, expected_target_rect.position.x, 0.001)
	assert_almost_eq(ornaments_panel.position.y, expected_target_rect.position.y, 0.001)
	assert_almost_eq(ornaments_panel.modulate.a, 1.0, 0.001)
	assert_almost_eq(grid_panel.modulate.a, 1.0, 0.001)
	assert_false(intro_bag.visible)
	assert_eq(intro_bag.scale, Vector2.ONE)
	assert_almost_eq(intro_bag.modulate.a, 1.0, 0.001)


func test_main_game_intro_final_frame_pixel_bounds_match_playable_bag_art():
	var ui = MainGameUI.instantiate()
	ui.set("play_battle_intro", false)
	ui.set("intro_bag_drop_duration", 0.0)
	add_child_autofree(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	var intro_bag := ui.call("_show_intro_bag_reveal") as TextureRect
	await ui._animate_intro_bag_drop(intro_bag)
	intro_bag.texture = load("res://assets/ui/battle/intro_bag_reveal/bag_reveal_05.png") as Texture2D
	assert_eq(intro_bag.stretch_mode, TextureRect.STRETCH_SCALE)
	await ui._reveal_intro_grid(intro_bag)

	var final_frame_path := "res://assets/ui/battle/intro_bag_reveal/bag_reveal_05.png"
	var final_alpha_rect := _get_png_alpha_rect(final_frame_path)
	var intro_pixel_rect := _map_alpha_rect_to_control_rect(
		Rect2(intro_bag.position, intro_bag.size * intro_bag.scale),
		_get_png_size(final_frame_path),
		final_alpha_rect
	)

	var playable_bag := ui.get_node("ContentLayer/PlayableBagArt") as TextureRect
	assert_true(playable_bag.visible)
	assert_eq(playable_bag.texture.resource_path, final_frame_path)
	assert_eq(playable_bag.stretch_mode, TextureRect.STRETCH_SCALE)
	var playable_pixel_rect := _map_alpha_rect_to_control_rect(
		Rect2(playable_bag.position, playable_bag.size * playable_bag.scale),
		_get_png_size(final_frame_path),
		final_alpha_rect
	)

	assert_almost_eq(intro_pixel_rect.position.x, playable_pixel_rect.position.x, 0.001)
	assert_almost_eq(intro_pixel_rect.position.y, playable_pixel_rect.position.y, 0.001)
	assert_almost_eq(intro_pixel_rect.end.x, playable_pixel_rect.end.x, 0.001)
	assert_almost_eq(intro_pixel_rect.end.y, playable_pixel_rect.end.y, 0.001)


func test_main_game_intro_finishes_into_battle_context():
	var ui = MainGameUI.instantiate()
	ui.set("intro_bag_frame_time", 0.01)
	ui.set("intro_bag_final_hold", 0.0)
	ui.set("intro_stats_rise_duration", 0.01)
	ui.set("intro_grid_reveal_duration", 0.01)
	ui.set("intro_bag_frame_paths", PackedStringArray())
	add_child_autofree(ui)

	await get_tree().create_timer(1.0).timeout

	var grid_panel := ui.get_node("ContentLayer/GridPanel") as Control
	var stats_panel := ui.get_node("ContentLayer/StatsPanel") as Control
	var ornaments_panel := ui.get_node("ContentLayer/OrnamentsPanel") as Control
	var playable_bag := ui.get_node("ContentLayer/PlayableBagArt") as TextureRect
	assert_false(bool(ui.get("_intro_playing")))
	assert_true(GlobalInput.is_context(GlobalInput.Context.BATTLE))
	assert_true(playable_bag.visible)
	assert_eq(playable_bag.texture.resource_path, "res://assets/ui/battle/intro_bag_reveal/bag_reveal_05.png")
	assert_true(grid_panel.visible)
	assert_almost_eq(grid_panel.modulate.a, 1.0, 0.001)
	assert_true(stats_panel.visible)
	assert_almost_eq(stats_panel.modulate.a, 1.0, 0.001)
	assert_true(ornaments_panel.visible)
	assert_almost_eq(ornaments_panel.modulate.a, 1.0, 0.001)
	var intro_bag := ui.get_node_or_null("ContentLayer/IntroBagReveal") as TextureRect
	assert_not_null(intro_bag)
	assert_false(intro_bag.visible)


func test_hub_backpack_overlay_uses_static_back_tab_rect():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	hub._open_backpack_overlay()
	await get_tree().create_timer(0.2).timeout

	var overlay_root = hub.get_node("CanvasLayer/OverlayRoot")
	assert_eq(overlay_root.get_child_count(), 1)
	assert_true(GlobalInput.is_context(GlobalInput.Context.UI))
	var overlay = overlay_root.get_child(0)
	assert_eq(overlay.scene_file_path, "res://src/ui/backpack/backpack_page.tscn")
	var close_button = overlay.get_node_or_null("ContentLayer/CloseButton")
	assert_not_null(close_button)
	var back_tab_rect: Rect2 = BookBackgroundConfig.get_back_tab_rect()
	assert_eq(close_button.position, back_tab_rect.position)
	assert_eq(close_button.size, back_tab_rect.size)


func test_book_page_back_tab_buttons_return_to_main_menu():
	var expected_rect: Rect2 = BookBackgroundConfig.get_back_tab_rect()
	var navigator: ReturnNavigatorStub = add_child_autofree(ReturnNavigatorStub.new())

	var gallery = add_child_autofree(load("res://src/ui/gallery/gallery_scene.tscn").instantiate())
	gallery.set_book_page_navigator(navigator)
	await get_tree().create_timer(0.2).timeout
	var gallery_back := gallery.get_node_or_null("DesignRoot/UiLayer/BackButton") as Button
	assert_not_null(gallery_back)
	assert_eq(gallery_back.position, expected_rect.position)
	assert_eq(gallery_back.size, expected_rect.size)
	gallery_back.pressed.emit()
	assert_eq(navigator.return_to_main_menu_count, 1)
	gallery.queue_free()
	await get_tree().process_frame

	var settings = add_child_autofree(load("res://src/ui/settings/audio_settings_ui.tscn").instantiate())
	settings.set_book_page_navigator(navigator)
	await get_tree().create_timer(0.2).timeout
	var settings_back := settings.get_node_or_null("DesignRoot/UiLayer/BackButton") as Button
	assert_not_null(settings_back)
	assert_eq(settings_back.position, expected_rect.position)
	assert_eq(settings_back.size, expected_rect.size)
	settings_back.pressed.emit()
	assert_eq(navigator.return_to_main_menu_count, 2)
	settings.queue_free()
	await get_tree().process_frame

	var backpack = add_child_autofree(BackpackPage.instantiate())
	backpack.set_book_page_navigator(navigator)
	await get_tree().create_timer(0.2).timeout
	var backpack_back := backpack.get_node_or_null("ContentLayer/CloseButton") as Button
	assert_not_null(backpack_back)
	assert_eq(backpack_back.position, expected_rect.position)
	assert_eq(backpack_back.size, expected_rect.size)
	backpack_back.pressed.emit()
	assert_eq(navigator.return_to_main_menu_count, 3)


func test_book_page_z_ranges_cover_static_page_layers():
	var page_range: Vector2i = BookBackgroundConfig.get_page_z_range(BookBackgroundConfig.PAGE_BACKPACK)
	assert_true(BookBackgroundConfig.is_z_index_in_range(BookBackgroundConfig.PAGE_CONTENT_Z_INDEX, page_range))
	assert_true(BookBackgroundConfig.is_z_index_in_range(BookBackgroundConfig.PAGE_CONTROL_Z_INDEX, page_range))
	assert_true(BookBackgroundConfig.is_z_index_in_range(BookBackgroundConfig.PAGE_FLOATING_Z_INDEX, page_range))
	assert_false(BookBackgroundConfig.is_z_index_in_range(BookBackgroundConfig.PAGE_TURN_EFFECT_Z_INDEX, page_range))
	assert_true(BookBackgroundConfig.PAGE_TURN_EFFECT_Z_INDEX > BookBackgroundConfig.Z_RANGE_PAGE_FLOATING.y)

	var backpack: Control = autofree(BackpackPage.instantiate())
	assert_eq((backpack.get_node("ContentLayer/GridPanel") as Control).z_index, BookBackgroundConfig.PAGE_CONTENT_Z_INDEX)
	assert_eq((backpack.get_node("ContentLayer/CloseButton") as Control).z_index, BookBackgroundConfig.PAGE_CONTROL_Z_INDEX)
	assert_eq((backpack.get_node("ContentLayer/EffectsList") as Control).z_index, BookBackgroundConfig.PAGE_CONTROL_Z_INDEX)
	assert_eq((backpack.get_node("ContentLayer/StatsLabel") as Control).z_index, BookBackgroundConfig.PAGE_CONTROL_Z_INDEX)
	assert_eq((backpack.get_node("ContentLayer/PendingItemPanel") as Control).z_index, BookBackgroundConfig.PAGE_FLOATING_Z_INDEX)

	var gallery: Control = autofree(load("res://src/ui/gallery/gallery_scene.tscn").instantiate())
	assert_eq((gallery.get_node("DesignRoot/UiLayer") as Control).z_index, BookBackgroundConfig.PAGE_CONTENT_Z_INDEX)

	var settings: Control = autofree(load("res://src/ui/settings/audio_settings_ui.tscn").instantiate())
	assert_eq((settings.get_node("DesignRoot/UiLayer") as Control).z_index, BookBackgroundConfig.PAGE_CONTENT_Z_INDEX)


func test_hub_battle_layer_is_part_of_hub_scene_not_overlay_root():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var overlay_root = hub.get_node("CanvasLayer/OverlayRoot")
	var battle_layer = hub.get_node_or_null("CanvasLayer/BattleLayer")
	assert_not_null(battle_layer)
	assert_eq(battle_layer.scene_file_path, "res://src/ui/hub/hub_battle_layer.tscn")
	assert_false(battle_layer.visible)
	assert_eq(overlay_root.get_child_count(), 0)
	assert_null(hub.get_node_or_null("MainGameUI"))
	assert_null(hub.get_node_or_null("CanvasLayer/OverlayRoot/MainGameUI"))
	assert_null(hub.get_node_or_null("CanvasLayer/OverlayRoot/EmbeddedBattleUI"))

	hub._open_backpack_overlay()
	await get_tree().create_timer(0.2).timeout
	assert_eq(overlay_root.get_child_count(), 1)
	assert_eq(overlay_root.get_child(0).scene_file_path, "res://src/ui/backpack/backpack_page.tscn")
	assert_null(hub.get_node_or_null("CanvasLayer/OverlayRoot/MainGameUI"))


func test_hub_uses_preplaced_battle_layer_instead_of_overlay_battle_ui():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var overlay_root = hub.get_node("CanvasLayer/OverlayRoot")
	var battle_layer = hub.get_node_or_null("CanvasLayer/BattleLayer")
	assert_not_null(battle_layer)
	assert_eq(battle_layer.scene_file_path, "res://src/ui/hub/hub_battle_layer.tscn")
	assert_true(battle_layer.is_inside_tree())
	assert_false(battle_layer.visible)
	assert_false(bool(battle_layer.get("auto_initialize")))
	assert_true(bool(battle_layer.get("play_battle_intro")))
	assert_eq(overlay_root.get_child_count(), 0)
	assert_null(overlay_root.get_node_or_null("EmbeddedBattleUI"))


func test_hub_left_bookmark_click_does_not_move_player():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout
	GlobalInput.set_context(GlobalInput.Context.WORLD)
	var hub_player = _get_hub_player(hub)
	hub_player.clear_move_target()

	var bookmark_paths := [
		"CanvasLayer/DesignRoot/MainMenuButton",
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
	var hub_player = _get_hub_player(hub)

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

	var hub_player := _get_hub_player(hub)
	assert_not_null(hub_player)
	assert_true(hub_player.visible)

	var animated_sprite := hub_player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	assert_not_null(animated_sprite)
	assert_not_null(animated_sprite.sprite_frames)
	assert_true(animated_sprite.sprite_frames.has_animation("idle"))
	assert_true(animated_sprite.sprite_frames.has_animation("walk"))
	assert_eq(animated_sprite.sprite_frames.get_frame_count("idle"), 4)
	assert_eq(animated_sprite.sprite_frames.get_frame_count("walk"), 6)
	assert_eq(animated_sprite.scale, Vector2(0.3, 0.3))
	assert_not_null(animated_sprite.sprite_frames.get_frame_texture("idle", 0))
	assert_not_null(animated_sprite.sprite_frames.get_frame_texture("walk", 0))


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
	var hub_player := _get_hub_player(hub)
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


func test_hub_back_tab_is_visible_low_layer_and_returns_to_main_menu():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var back_tab := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground/BackTab") as TextureRect
	assert_not_null(back_tab)
	assert_true(back_tab.visible)
	assert_eq(back_tab.position, BookBackgroundConfig.get_back_tab_rect().position)
	assert_eq(back_tab.size, BookBackgroundConfig.get_back_tab_rect().size)
	assert_eq(back_tab.z_index, BookBackgroundConfig.get_back_tab_z_index())
	var page_route_cover := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground/PageRouteCover") as TextureRect
	assert_not_null(page_route_cover)
	assert_true(back_tab.z_index < page_route_cover.z_index)

	var button := hub.get_node_or_null("CanvasLayer/DesignRoot/MainMenuButton") as Button
	assert_not_null(button)
	assert_false(button.tooltip_text.is_empty())
	assert_true(button.visible)
	assert_eq(button.position, BookBackgroundConfig.get_back_tab_rect().position)
	assert_eq(button.size, BookBackgroundConfig.get_back_tab_rect().size)
	assert_true(button.pressed.is_connected(Callable(hub, "_on_main_menu_button_pressed")))
	var duplicate_art := button.get_node_or_null("Art") as CanvasItem
	if duplicate_art != null:
		assert_false(duplicate_art.visible)
