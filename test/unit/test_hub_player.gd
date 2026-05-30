extends GutTest

const HubScene = preload("res://src/ui/hub/hub_scene.tscn")
const MainGameUI = preload("res://src/ui/main_game_ui.tscn")
const BackpackPage = preload("res://src/ui/backpack/backpack_page.tscn")
const BookBackgroundConfig = preload("res://src/ui/book/book_background_config.gd")

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


func test_backpack_page_adds_close_button_and_keeps_ui_context():
	var ui = BackpackPage.instantiate()
	ui.configure_for_backpack_overlay()
	add_child_autofree(ui)

	await get_tree().create_timer(0.2).timeout

	assert_true(GlobalInput.is_context(GlobalInput.Context.UI))
	assert_not_null(ui.get_node_or_null("ContentLayer/CloseButton"))
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
	assert_null(ui.get_node_or_null("Background"))
	assert_null(ui.get_node_or_null("ContentLayer/BattleArt"))
	assert_null(ui.get_node_or_null("ContentLayer/DreamcatcherPanel"))
	assert_null(ui.get_node_or_null("ContentLayer/MenuButton"))
	var overlay_art := ui.get_node_or_null("ContentLayer/BackpackArt") as Control
	assert_not_null(overlay_art)
	assert_true(overlay_art.visible)
	assert_eq(overlay_art.position, Vector2.ZERO)
	assert_eq(overlay_art.size, BookBackgroundConfig.DESIGN_SIZE)
	assert_eq(overlay_art.scale, Vector2.ONE)
	assert_true(overlay_art.has_method("get_visible_page_sheet_count"))
	assert_eq(overlay_art.call("get_visible_page_sheet_count"), 2)
	var overlay_album_page := ui.get_node_or_null("ContentLayer/BackpackArt/AlbumPage") as TextureRect
	var overlay_page_middle := ui.get_node_or_null("ContentLayer/BackpackArt/PageMiddle") as TextureRect
	var overlay_backpack_cover := ui.get_node_or_null("ContentLayer/BackpackArt/PageBackpackCover") as TextureRect
	var overlay_route_cover := ui.get_node_or_null("ContentLayer/BackpackArt/PageRouteCover") as TextureRect
	var overlay_hub_right_tab := ui.get_node_or_null("ContentLayer/BackpackArt/AlbumTabRight") as TextureRect
	var overlay_backpack_tab := ui.get_node_or_null("ContentLayer/BackpackArt/BackpackTab") as TextureRect
	var overlay_gallery_right_tab := ui.get_node_or_null("ContentLayer/BackpackArt/GalleryTabRight") as TextureRect
	var overlay_settings_tab := ui.get_node_or_null("ContentLayer/BackpackArt/SettingsTab") as TextureRect
	assert_not_null(overlay_album_page)
	assert_not_null(overlay_page_middle)
	assert_not_null(overlay_backpack_cover)
	assert_not_null(overlay_route_cover)
	assert_not_null(overlay_hub_right_tab)
	assert_not_null(overlay_backpack_tab)
	assert_not_null(overlay_gallery_right_tab)
	assert_not_null(overlay_settings_tab)
	assert_false(overlay_album_page.visible)
	assert_false(overlay_page_middle.visible)
	assert_true(overlay_backpack_cover.visible)
	assert_true(overlay_route_cover.visible)
	assert_false(overlay_hub_right_tab.visible)
	assert_true(overlay_backpack_tab.visible)
	assert_false(overlay_gallery_right_tab.visible)
	assert_true(overlay_settings_tab.visible)
	assert_eq(overlay_backpack_tab.z_index, BookBackgroundConfig.get_tab_z_index(BookBackgroundConfig.PAGE_BACKPACK, BookBackgroundConfig.PAGE_BACKPACK))
	assert_true(overlay_backpack_tab.z_index > overlay_backpack_cover.z_index)
	assert_true(overlay_settings_tab.z_index < overlay_backpack_tab.z_index)
	assert_true(ui.get_node("ContentLayer/GridPanel").visible)
	assert_not_null(ui.get_node_or_null("ContentLayer/GridPanel/BackpackUI"))
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
		var art := ui.get_node_or_null("ContentLayer/BackpackArt/%s" % node_name) as TextureRect
		assert_not_null(art, "Backpack page split art should expose %s" % node_name)
		assert_not_null(art.texture)
		assert_true(art.texture.resource_path != "res://assets/ui/backpack/backpack_overlay_background.png")
	var wood_floor := ui.get_node_or_null("ContentLayer/BackpackArt/WoodFloor") as TextureRect
	assert_not_null(wood_floor)
	var wood_rect: Rect2 = wood_floor.get_global_rect()
	assert_lte(wood_rect.position.x, 0.01)
	assert_lte(wood_rect.position.y, 0.01)
	assert_gte(wood_rect.end.x, viewport_size.x - 0.01)
	assert_gte(wood_rect.end.y, viewport_size.y - 0.01)
	assert_not_null(ui.get_node_or_null("ContentLayer/EffectsList"))
	assert_not_null(ui.get_node_or_null("ContentLayer/StatsLabel"))


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
	assert_eq(overlay_root.get_child_count(), 0)
	assert_null(overlay_root.get_node_or_null("EmbeddedBattleUI"))


func test_hub_battle_layer_uses_scene_dreamcatcher_visual():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var battle_layer := hub.get_node_or_null("CanvasLayer/BattleLayer") as Control
	var hub_net := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/DreamcatcherNet") as Sprite2D
	var dreamcatcher_button := hub.get_node_or_null("CanvasLayer/DesignRoot/DreamcatcherButton") as Button
	assert_not_null(battle_layer)
	assert_not_null(hub_net)
	assert_not_null(dreamcatcher_button)
	assert_null(battle_layer.get_node_or_null("ContentLayer/DreamcatcherPanel/DreamcatcherNet"))

	battle_layer.call("use_hub_dreamcatcher", hub_net, dreamcatcher_button)

	var layer_panel := battle_layer.get_node_or_null("ContentLayer/DreamcatcherPanel") as Control
	assert_not_null(layer_panel)
	assert_eq(battle_layer.get("dreamcatcher_net"), hub_net)
	assert_eq(battle_layer.get("dreamcatcher_panel"), layer_panel)
	assert_eq(battle_layer.get("draw_spawn_point"), layer_panel)
	assert_true(layer_panel.get_global_rect().has_point(hub._get_hub_dreamcatcher_focus_global_position()))


func test_hub_to_battle_focus_moves_only_cardboard_layer_toward_target():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var book_design_root := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot") as Control
	var canvas_design_root := hub.get_node_or_null("CanvasLayer/DesignRoot") as Control
	var hub_art := hub.get_node_or_null("HubPageVisualRoot/HubArt") as Node2D
	var board_viewport := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport") as Control
	var board_content := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent") as Control
	var room := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/Room") as Sprite2D
	var hub_net := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/DreamcatcherNet") as Sprite2D
	var top_left_corner := hub.get_node_or_null("HubPageVisualRoot/HubArt/CornerTopLeft") as Sprite2D
	var top_right_corner := hub.get_node_or_null("HubPageVisualRoot/HubArt/CornerTopRight") as Sprite2D
	var bottom_left_corner := hub.get_node_or_null("HubPageVisualRoot/HubArt/CornerBottomLeft") as Sprite2D
	var bottom_right_corner := hub.get_node_or_null("HubPageVisualRoot/HubArt/CornerBottomRight") as Sprite2D
	var hub_player := hub.get_node_or_null("HubPageVisualRoot/Player") as CharacterBody2D
	var dreamcatcher_button := hub.get_node_or_null("CanvasLayer/DesignRoot/DreamcatcherButton") as Button
	assert_not_null(book_design_root)
	assert_not_null(canvas_design_root)
	assert_not_null(hub_art)
	assert_not_null(board_viewport)
	assert_not_null(board_content)
	assert_not_null(room)
	assert_not_null(hub_net)
	assert_not_null(top_left_corner)
	assert_not_null(top_right_corner)
	assert_not_null(bottom_left_corner)
	assert_not_null(bottom_right_corner)
	assert_not_null(hub_player)
	assert_not_null(dreamcatcher_button)

	var viewport_size: Vector2 = hub.get_viewport_rect().size
	var start_point: Vector2 = hub._get_hub_dreamcatcher_focus_global_position()
	var expected_focus_zoom: float = hub._get_hub_to_battle_focus_zoom(start_point)
	var expected_target_point: Vector2 = hub._get_hub_to_battle_board_target_global_position()
	var end_focus := expected_target_point / viewport_size
	var before_board_rect := board_viewport.get_global_rect()
	var before_book_position := book_design_root.position
	var before_canvas_position := canvas_design_root.position
	var before_art_position := hub_art.position
	var before_board_viewport_position := board_viewport.position
	var before_board_content_position := board_content.position
	var expected_board_clip_rect := Rect2(hub._default_room_position, hub._default_room_display_size)
	var before_room_position := room.position
	var before_net_position := hub_net.position
	var before_corner_position := top_left_corner.position
	var before_top_right_corner_position := top_right_corner.position
	var before_bottom_left_corner_position := bottom_left_corner.position
	var before_bottom_right_corner_position := bottom_right_corner.position
	var before_player_position := hub_player.position
	var before_book_scale := book_design_root.scale
	var before_canvas_scale := canvas_design_root.scale
	var before_art_scale := hub_art.scale
	var before_board_viewport_scale := board_viewport.scale
	var before_board_viewport_size := board_viewport.size
	var before_board_content_pivot := board_content.pivot_offset
	var before_board_content_scale := board_content.scale
	var before_room_scale := room.scale
	var before_net_scale := hub_net.scale
	var before_corner_scale := top_left_corner.scale
	var before_top_right_corner_scale := top_right_corner.scale
	var before_bottom_left_corner_scale := bottom_left_corner.scale
	var before_bottom_right_corner_scale := bottom_right_corner.scale
	var before_player_scale := hub_player.scale

	hub._play_hub_to_battle_focus(start_point / viewport_size, end_focus, 0.0)

	var after_point: Vector2 = hub._get_hub_dreamcatcher_focus_global_position()
	var after_board_rect := board_viewport.get_global_rect()
	assert_almost_eq(after_board_rect.position.x, before_board_rect.position.x, 0.01)
	assert_almost_eq(after_board_rect.position.y, before_board_rect.position.y, 0.01)
	assert_almost_eq(after_board_rect.end.x, before_board_rect.end.x, 0.01)
	assert_almost_eq(after_board_rect.end.y, before_board_rect.end.y, 0.01)
	assert_almost_eq(after_point.x, expected_target_point.x, 1.0)
	assert_lte(after_point.y, expected_target_point.y)
	assert_eq(book_design_root.position, before_book_position)
	assert_eq(canvas_design_root.position, before_canvas_position)
	assert_eq(hub_player.position, before_player_position)
	assert_eq(hub_art.position, before_art_position)
	assert_eq(board_viewport.position, before_board_viewport_position)
	assert_almost_eq(board_viewport.position.x, expected_board_clip_rect.position.x, 0.01)
	assert_almost_eq(board_viewport.position.y, expected_board_clip_rect.position.y, 0.01)
	assert_almost_eq(board_viewport.size.x, expected_board_clip_rect.size.x, 0.01)
	assert_almost_eq(board_viewport.size.y, expected_board_clip_rect.size.y, 0.01)
	assert_eq(room.position, before_room_position)
	assert_eq(top_left_corner.position, before_corner_position)
	assert_eq(top_right_corner.position, before_top_right_corner_position)
	assert_eq(bottom_left_corner.position, before_bottom_left_corner_position)
	assert_eq(bottom_right_corner.position, before_bottom_right_corner_position)
	assert_eq(book_design_root.scale, before_book_scale)
	assert_eq(canvas_design_root.scale, before_canvas_scale)
	assert_eq(hub_art.scale, before_art_scale)
	assert_eq(board_viewport.scale, before_board_viewport_scale)
	assert_eq(board_viewport.size, before_board_viewport_size)
	assert_eq(board_content.pivot_offset, before_board_content_pivot)
	assert_true(board_viewport.clip_contents)
	assert_true(board_viewport.position.x > 0.0)
	assert_true(board_viewport.position.y > 0.0)
	assert_true(board_viewport.size.x < BookBackgroundConfig.DESIGN_SIZE.x)
	assert_true(board_viewport.size.y < BookBackgroundConfig.DESIGN_SIZE.y)
	assert_ne(board_content.position, before_board_content_position)
	assert_almost_eq(board_content.scale.x, before_board_content_scale.x * expected_focus_zoom, 0.001)
	assert_almost_eq(board_content.scale.y, before_board_content_scale.y * expected_focus_zoom, 0.001)
	var after_board_content_bottom_y := board_content.position.y + expected_board_clip_rect.end.y * board_content.scale.y
	assert_almost_eq(after_board_content_bottom_y, board_viewport.size.y, 0.01)
	assert_eq(room.scale, before_room_scale)
	assert_eq(room.position, before_room_position)
	assert_eq(hub_net.position, before_net_position)
	assert_eq(hub_net.scale, before_net_scale)
	assert_eq(top_left_corner.scale, before_corner_scale)
	assert_eq(top_right_corner.scale, before_top_right_corner_scale)
	assert_eq(bottom_left_corner.scale, before_bottom_left_corner_scale)
	assert_eq(bottom_right_corner.scale, before_bottom_right_corner_scale)
	assert_eq(hub_player.scale, before_player_scale)
	var focus_layers: Array[Node] = hub._get_hub_to_battle_focus_layers()
	assert_true(focus_layers.has(board_content))
	assert_false(focus_layers.has(hub_art))
	assert_false(focus_layers.has(board_viewport))
	assert_false(focus_layers.has(hub_net))
	assert_false(focus_layers.has(top_left_corner))
	assert_false(focus_layers.has(top_right_corner))
	assert_false(focus_layers.has(bottom_left_corner))
	assert_false(focus_layers.has(bottom_right_corner))
	assert_false(focus_layers.has(room))


func test_hub_left_click_moves_player_with_mouse():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout
	GlobalInput.set_context(GlobalInput.Context.WORLD)
	var hub_player = _get_hub_player(hub)
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


func test_hub_merchant_animation_follows_player_arrival_and_departure():
	var rm = get_node_or_null("/root/RunManager")
	assert_not_null(rm)
	rm.is_run_active = true
	rm.current_act = 1
	rm.current_route_index = 1

	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var merchant_sprite := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/MerchantSprite") as AnimatedSprite2D
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

	var hub_player := _get_hub_player(hub)
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

	var merchant_button := hub.get_node_or_null("CanvasLayer/DesignRoot/MerchantButton") as Button
	assert_not_null(merchant_button)
	assert_true(merchant_button.visible)
	assert_false(merchant_button.disabled)
	assert_true(merchant_button.size.x > 0.0)
	assert_true(merchant_button.size.y > 0.0)
	var room := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/Room") as Sprite2D
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

	var merchant_sprite := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/MerchantSprite") as AnimatedSprite2D
	var merchant_button := hub.get_node_or_null("CanvasLayer/DesignRoot/MerchantButton") as Button
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

	var net := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/DreamcatcherNet") as Sprite2D
	assert_not_null(net)
	assert_not_null(net.texture)
	assert_eq(net.texture.resource_path, "res://assets/ui/battle/dreamcatchers/act_1_xiaomi.png")
	assert_eq(net.scale, Vector2(0.5, 0.5))
	assert_false(net.region_enabled)
	assert_null(net.material)
	assert_gt(net.offset.y, net.texture.get_size().y * 0.75)

	hub._stop_hub_dreamcatcher_idle_swing()
	net.position = hub._dreamcatcher_net_base_position
	net.rotation = hub._dreamcatcher_net_base_rotation
	net.offset = hub._dreamcatcher_net_base_offset
	var visual_center := net.position + _get_scaled_sprite_offset(net).rotated(net.rotation)
	assert_almost_eq(visual_center.x, 918.0, 0.01)
	assert_almost_eq(visual_center.y, 556.0, 0.01)

	var dreamcatcher_button := hub.get_node_or_null("CanvasLayer/DesignRoot/DreamcatcherButton") as Button
	assert_not_null(dreamcatcher_button)
	assert_false(dreamcatcher_button.disabled)
	assert_true(dreamcatcher_button.pressed.is_connected(Callable(hub, "_on_dreamcatcher_button_pressed")))
	assert_true(hub._is_dreamcatcher_game_available())
	var visual_rect: Rect2 = hub._get_hub_dreamcatcher_global_rect()
	var hotspot_rect := dreamcatcher_button.get_global_rect()
	assert_gt(visual_rect.size.x, 1.0)
	assert_gt(visual_rect.size.y, 1.0)
	assert_lte(hotspot_rect.position.x, visual_rect.position.x + 1.0)
	assert_lte(hotspot_rect.position.y, visual_rect.position.y + 1.0)
	assert_gte(hotspot_rect.end.x, visual_rect.end.x - 1.0)
	assert_gte(hotspot_rect.end.y, visual_rect.end.y - 1.0)
	assert_true(hub._is_point_on_hub_dreamcatcher(visual_rect.get_center()))


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


func test_hub_dreamcatcher_tracks_current_stage_and_disables_on_shop_node():
	var rm = get_node_or_null("/root/RunManager")
	assert_not_null(rm)
	rm.is_run_active = true
	rm.current_act = 4
	rm.current_route_index = 0

	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var net := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/DreamcatcherNet") as Sprite2D
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

	var net := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/DreamcatcherNet") as Sprite2D
	assert_not_null(net)
	hub._stop_hub_dreamcatcher_idle_swing()
	var base_position: Vector2 = hub._dreamcatcher_net_base_position
	var base_rotation: float = hub._dreamcatcher_net_base_rotation
	var base_offset: Vector2 = hub._dreamcatcher_net_base_offset

	await hub._play_hub_dreamcatcher_start_swing()

	assert_eq(net.position, base_position)
	assert_almost_eq(net.rotation, base_rotation, 0.001)
	assert_eq(net.offset, base_offset)


func test_hub_left_bookmark_input_click_opens_book_page():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var navigator := hub.get_node_or_null("CanvasLayer/BookPageNavigator") as Control
	var backpack_button := hub.get_node_or_null("CanvasLayer/DesignRoot/BackpackButton") as Button
	var backpack_visual := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground/BackpackTab") as Control
	assert_not_null(navigator)
	assert_not_null(backpack_button)
	assert_not_null(backpack_visual)
	var click_position := backpack_visual.get_global_rect().get_center()
	assert_eq(
		str(hub.call("_get_left_bookmark_page_at_position", click_position)),
		BookBackgroundConfig.PAGE_BACKPACK
	)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = click_position
	hub.call("_input", click)
	await get_tree().create_timer(0.6).timeout

	assert_eq(navigator.current_page_id, BookBackgroundConfig.PAGE_BACKPACK)
	assert_true(GlobalInput.is_context(GlobalInput.Context.UI))


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
	assert_true(hub_tab.position.y > backpack_tab.position.y - 160.0)
	assert_true(backpack_tab.position.x > viewport_center_x)
	assert_true(gallery_tab.position.x > viewport_center_x)

	gallery_tab.pressed.emit()
	await get_tree().create_timer(0.6).timeout

	assert_eq(navigator.current_page_id, "gallery")
	assert_true(GlobalInput.is_context(GlobalInput.Context.UI))
	assert_true(backpack_tab.visible)
	assert_true(settings_tab.visible)
	assert_false(gallery_tab.visible)
	var gallery_page := navigator.get_node_or_null("GalleryPage") as Control
	assert_not_null(gallery_page)
	var gallery_art := gallery_page.get_node_or_null("DesignRoot/ArtLayer") as Control
	assert_not_null(gallery_art)
	var backpack_left_visual := gallery_art.get_node_or_null("BackpackTab") as Control
	var settings_left_visual := gallery_art.get_node_or_null("SettingsTab") as Control
	assert_not_null(backpack_left_visual)
	assert_not_null(settings_left_visual)
	var backpack_hit_rect := backpack_tab.get_global_rect()
	var backpack_visual_rect := backpack_left_visual.get_global_rect()
	var settings_hit_rect := settings_tab.get_global_rect()
	var settings_visual_rect := settings_left_visual.get_global_rect()
	assert_almost_eq(backpack_hit_rect.position.x, backpack_visual_rect.position.x, 1.0)
	assert_almost_eq(backpack_hit_rect.position.y, backpack_visual_rect.position.y, 1.0)
	assert_almost_eq(backpack_hit_rect.size.x, backpack_visual_rect.size.x, 1.0)
	assert_almost_eq(backpack_hit_rect.size.y, backpack_visual_rect.size.y, 1.0)
	assert_almost_eq(settings_hit_rect.position.x, settings_visual_rect.position.x, 1.0)
	assert_almost_eq(settings_hit_rect.position.y, settings_visual_rect.position.y, 1.0)
	assert_almost_eq(settings_hit_rect.size.x, settings_visual_rect.size.x, 1.0)
	assert_almost_eq(settings_hit_rect.size.y, settings_visual_rect.size.y, 1.0)
	assert_eq(
		str(navigator.call("_get_tab_button_page_at_position", backpack_hit_rect.get_center())),
		BookBackgroundConfig.PAGE_BACKPACK
	)
	assert_eq(
		str(navigator.call("_get_tab_button_page_at_position", settings_hit_rect.get_center())),
		BookBackgroundConfig.PAGE_SETTINGS
	)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = settings_hit_rect.get_center()
	hub.call("_input", click)
	await get_tree().create_timer(0.6).timeout

	assert_eq(navigator.current_page_id, BookBackgroundConfig.PAGE_SETTINGS)
	assert_true(GlobalInput.is_context(GlobalInput.Context.UI))


func test_hub_book_page_navigator_routes_all_book_pages_without_page_turn():
	var hub = autofree(HubScene.instantiate())
	var navigator := hub.get_node_or_null("CanvasLayer/BookPageNavigator") as Control
	assert_not_null(navigator)
	var page_ids := [
		BookBackgroundConfig.PAGE_HUB,
		BookBackgroundConfig.PAGE_GALLERY,
		BookBackgroundConfig.PAGE_BACKPACK,
		BookBackgroundConfig.PAGE_SETTINGS,
	]
	var mode_counts := {
		"compress": 0,
		"expand": 0,
		"page_to_page": 0,
	}
	for from_page in page_ids:
		for to_page in page_ids:
			if from_page == to_page:
				continue
			var transition_mode := str(navigator.call("_get_book_transition_mode", from_page, to_page))
			assert_false(transition_mode.is_empty(), "%s -> %s should use a book interaction route." % [from_page, to_page])
			mode_counts[transition_mode] = int(mode_counts[transition_mode]) + 1
	assert_eq(int(mode_counts["compress"]), 3)
	assert_eq(int(mode_counts["expand"]), 3)
	assert_eq(int(mode_counts["page_to_page"]), 6)


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
	assert_true(_get_hub_art(hub).visible)
	assert_true(GlobalInput.is_context(GlobalInput.Context.WORLD))


func test_hub_zone_triggers_do_not_show_current_prompt_bubbles():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var speech_bubble := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/SpeechBubble") as Sprite2D
	var speech_text := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/SpeechText") as Label
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

	var room := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/Room") as Sprite2D
	assert_not_null(room)
	assert_not_null(room.texture)
	assert_eq(room.texture.resource_path, "res://assets/ui/hub/backgrounds/xiaojia.png")
	assert_eq(room.position, hub._default_room_position)
	assert_true(room.scale.x > 0.0)
	assert_eq(room.scale.x, room.scale.y)

	var foreground := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/Foreground") as Sprite2D
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

	var room := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/Room") as Sprite2D
	assert_not_null(room)
	assert_not_null(room.texture)
	assert_eq(room.texture.resource_path, "res://assets/ui/hub/hub_room.png")

	var foreground := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/Foreground") as Sprite2D
	assert_not_null(foreground)
	assert_false(foreground.visible)
	assert_null(foreground.texture)


func test_hub_scene_serialized_preview_matches_project_default_viewport():
	var hub = autofree(HubScene.instantiate())
	var viewport_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	var scale_factor := minf(
		viewport_size.x / BookBackgroundConfig.DESIGN_SIZE.x,
		viewport_size.y / BookBackgroundConfig.DESIGN_SIZE.y
	)
	var source_offset := Vector2(0.0, 14.0)
	var expected_book_origin := (viewport_size - BookBackgroundConfig.DESIGN_SIZE * scale_factor) * 0.5
	var expected_art_origin := expected_book_origin + source_offset * scale_factor

	var book_design_root := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot") as Control
	var canvas_design_root := hub.get_node_or_null("CanvasLayer/DesignRoot") as Control
	var hub_art := _get_hub_art(hub)
	var floor_body := hub.get_node_or_null("Floor") as StaticBody2D
	var hub_player := _get_hub_player(hub)
	var interactions := hub.get_node_or_null("Interactions") as Node2D
	assert_not_null(book_design_root)
	assert_not_null(canvas_design_root)
	assert_not_null(hub_art)
	assert_not_null(floor_body)
	assert_not_null(hub_player)
	assert_not_null(interactions)
	var expected_floor_y: float = expected_art_origin.y + hub.PLAYER_FLOOR_SOURCE_Y * scale_factor
	assert_almost_eq(hub_art.position.x, expected_art_origin.x, 0.01)
	assert_almost_eq(hub_art.position.y, expected_art_origin.y, 0.01)
	assert_almost_eq(book_design_root.position.x, expected_book_origin.x, 0.01)
	assert_almost_eq(book_design_root.position.y, expected_book_origin.y, 0.01)
	assert_almost_eq(canvas_design_root.position.x, expected_book_origin.x, 0.01)
	assert_almost_eq(canvas_design_root.position.y, expected_book_origin.y, 0.01)
	assert_almost_eq(hub_art.scale.x, scale_factor, 0.001)
	assert_almost_eq(hub_art.scale.y, scale_factor, 0.001)
	assert_almost_eq(book_design_root.scale.x, scale_factor, 0.001)
	assert_almost_eq(canvas_design_root.scale.x, scale_factor, 0.001)
	assert_almost_eq(floor_body.position.y, expected_floor_y, 0.01)
	assert_almost_eq(hub_player.position.x, expected_art_origin.x + hub.PLAYER_START_SOURCE_X * scale_factor, 0.01)
	assert_almost_eq(hub_player.position.y, expected_floor_y - hub.PLAYER_FLOOR_OFFSET, 0.01)
	assert_false(interactions.visible)


func test_hub_scene_uses_split_hub_art_without_composited_reference():
	var hub = HubScene.instantiate()
	add_child_autofree(hub)
	await get_tree().create_timer(0.2).timeout

	var book_design_root := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot") as Control
	var canvas_design_root := hub.get_node_or_null("CanvasLayer/DesignRoot") as Control
	var hub_art := _get_hub_art(hub)
	assert_not_null(book_design_root)
	assert_not_null(canvas_design_root)
	assert_not_null(hub_art)
	assert_eq(book_design_root.position, canvas_design_root.position)
	assert_ne(book_design_root.position, hub_art.position)
	assert_eq(book_design_root.scale, hub_art.scale)
	assert_eq(canvas_design_root.scale, hub_art.scale)
	var background := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground/WoodFloor") as TextureRect
	assert_not_null(background)
	assert_not_null(background.texture)
	assert_eq(background.texture.resource_path, "res://assets/ui/book/wood_floor.png")
	assert_eq(background.size, BookBackgroundConfig.DESIGN_SIZE)
	var book_background := hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground") as Control
	assert_not_null(book_background)
	assert_eq(book_background.position, Vector2.ZERO)
	assert_eq(book_background.size, BookBackgroundConfig.DESIGN_SIZE)

	for node_path in [
		"BookCanvasLayer/BookDesignRoot/BookBackground/BackTab",
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
		"HubPageVisualRoot/HubArt/BoardViewport/BoardContent/Room",
		"HubPageVisualRoot/HubArt/CornerTopLeft",
		"HubPageVisualRoot/HubArt/CornerTopRight",
		"HubPageVisualRoot/HubArt/CornerBottomLeft",
		"HubPageVisualRoot/HubArt/CornerBottomRight",
		"HubPageVisualRoot/HubArt/BoardViewport/BoardContent/SpeechBubble",
	]:
		var sprite := hub.get_node_or_null(node_path) as Sprite2D
		assert_not_null(sprite, "Hub split art should expose %s" % node_path)
		assert_not_null(sprite.texture)
		assert_true(sprite.texture.resource_path != "res://assets/ui/hub/hub_background.png")

	var speech_text := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/SpeechText") as Label
	assert_not_null(speech_text)
	var speech_bubble := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/SpeechBubble") as Sprite2D
	assert_not_null(speech_bubble)
	assert_false(speech_bubble.visible)
	assert_false(speech_text.visible)

	hub.show_speech_message()
	assert_true(speech_bubble.visible)
	assert_true(speech_text.visible)
	assert_eq(speech_text.text, "浣犵粓浜庨啋浜嗭紒")

	hub.show_speech_message("鎸?E 鏌ョ湅鍥鹃壌")
	assert_eq(speech_text.text, "鎸?E 鏌ョ湅鍥鹃壌")

	hub.hide_speech_message()
	assert_false(speech_bubble.visible)
	assert_false(speech_text.visible)

	book_background = hub.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground") as Control
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
	var hub_player := _get_hub_player(hub)
	var dreamcatcher_net := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/DreamcatcherNet") as Sprite2D
	var merchant_sprite := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/MerchantSprite") as AnimatedSprite2D
	var speech_bubble_for_z := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/SpeechBubble") as Sprite2D
	var room := hub.get_node_or_null("HubPageVisualRoot/HubArt/BoardViewport/BoardContent/Room") as Sprite2D
	var top_right_corner := hub.get_node_or_null("HubPageVisualRoot/HubArt/CornerTopRight") as Sprite2D
	var bottom_right_corner := hub.get_node_or_null("HubPageVisualRoot/HubArt/CornerBottomRight") as Sprite2D
	var hub_offset: Vector2 = hub.get("hub_art_source_offset")
	assert_eq(hub_offset, Vector2(0.0, 14.0))
	assert_not_null(ring_right)
	assert_not_null(room)
	assert_not_null(room.texture)
	assert_not_null(top_right_corner)
	assert_not_null(bottom_right_corner)
	var room_right_edge := room.position.x + room.texture.get_size().x * room.scale.x
	assert_true(top_right_corner.position.x >= room_right_edge)
	assert_true(bottom_right_corner.position.x >= room_right_edge)
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
	assert_eq(backpack_button.tooltip_text, "鏁寸悊鑳屽寘")
	assert_true(backpack_button.pressed.is_connected(Callable(hub, "_on_backpack_button_pressed")))

	var gallery_button := hub.get_node_or_null("CanvasLayer/DesignRoot/GalleryButton") as Button
	assert_not_null(gallery_button)
	assert_eq(gallery_button.tooltip_text, "鍥鹃壌")
	assert_true(gallery_button.pressed.is_connected(Callable(hub, "_on_gallery_button_pressed")))

	var settings_button := hub.get_node_or_null("CanvasLayer/DesignRoot/SettingsButton") as Button
	assert_not_null(settings_button)
	assert_eq(settings_button.tooltip_text, "璁剧疆")
	assert_true(settings_button.pressed.is_connected(Callable(hub, "_on_settings_button_pressed")))

	var route_tab_rect := BookBackgroundConfig.get_tab_rect(BookBackgroundConfig.PAGE_HUB, BookBackgroundConfig.PAGE_HUB)
	var backpack_tab_rect := BookBackgroundConfig.get_tab_rect(BookBackgroundConfig.PAGE_BACKPACK, BookBackgroundConfig.PAGE_HUB)
	var gallery_tab_rect := BookBackgroundConfig.get_tab_rect(BookBackgroundConfig.PAGE_GALLERY, BookBackgroundConfig.PAGE_HUB)
	var settings_tab_rect := BookBackgroundConfig.get_tab_rect(BookBackgroundConfig.PAGE_SETTINGS, BookBackgroundConfig.PAGE_HUB)
	assert_eq(route_tab.position, route_tab_rect.position)
	assert_eq(route_tab.size, route_tab_rect.size)
	assert_eq(route_button.position, route_tab_rect.position)
	assert_eq(route_button.size, route_tab_rect.size)
	assert_eq(backpack_tab.position, backpack_tab_rect.position)
	assert_eq(backpack_tab.size, backpack_tab_rect.size)
	assert_eq(backpack_button.position, backpack_tab_rect.position)
	assert_eq(backpack_button.size, backpack_tab_rect.size)
	assert_eq(gallery_tab.position, gallery_tab_rect.position)
	assert_eq(gallery_tab.size, gallery_tab_rect.size)
	assert_eq(gallery_button.position, gallery_tab_rect.position)
	assert_eq(gallery_button.size, gallery_tab_rect.size)
	assert_eq(settings_tab.position, settings_tab_rect.position)
	assert_eq(settings_tab.size, settings_tab_rect.size)
	assert_eq(settings_button.position, settings_tab_rect.position)
	assert_eq(settings_button.size, settings_tab_rect.size)

	var merchant_button := hub.get_node_or_null("CanvasLayer/DesignRoot/MerchantButton") as Button
	assert_not_null(merchant_button)
	assert_eq(merchant_button.get_parent(), canvas_design_root)
	assert_true(merchant_button.pressed.is_connected(Callable(hub, "_on_merchant_button_pressed")))

	assert_null(hub.get_node_or_null("CanvasLayer/RoutePanel"))


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
