extends GutTest

const StoryBookPage = preload("res://src/ui/story/story_book_page.tscn")
const StoryBookScene = preload("res://src/ui/story/story_book_scene.tscn")
const BookBackgroundScene = preload("res://src/ui/book/book_background.tscn")
const BookPageNavigator = preload("res://src/ui/book/book_page_navigator.gd")
const BookBackgroundConfig = preload("res://src/ui/book/book_background_config.gd")


class FakeSceneManager:
	extends Node

	var preload_calls := []
	var transition_calls := []
	var direct_transition_calls := []
	var story_return_requested := false

	func preload_scene(scene_type: int) -> void:
		preload_calls.append(scene_type)

	func transition_to(scene_type: int, push_to_history: bool = true) -> void:
		transition_calls.append({
			"scene_type": scene_type,
			"push_to_history": push_to_history,
		})

	func transition_to_direct(scene_type: int, push_to_history: bool = true) -> void:
		direct_transition_calls.append({
			"scene_type": scene_type,
			"push_to_history": push_to_history,
		})

	func request_story_book_return_transition(_page_state: Dictionary) -> void:
		story_return_requested = true


func test_story_book_page_shows_pinned_disabled_left_bookmarks() -> void:
	var page := add_child_autofree(StoryBookPage.instantiate()) as Control
	await get_tree().process_frame
	await get_tree().process_frame

	var art_layer := page.get_node_or_null("DesignRoot/ArtLayer") as Control
	assert_not_null(art_layer)
	assert_eq(art_layer.call("get_visible_page_sheet_count"), 5)

	var tab_pages := {
		BookBackgroundConfig.PAGE_HUB: "AlbumTab",
		BookBackgroundConfig.PAGE_BACKPACK: "BackpackTab",
		BookBackgroundConfig.PAGE_GALLERY: "GalleryTab",
		BookBackgroundConfig.PAGE_SETTINGS: "SettingsTab",
	}
	for page_id in tab_pages.keys():
		var tab_name := str(tab_pages[page_id])
		var tab := art_layer.get_node_or_null(tab_name) as TextureRect
		var pin := art_layer.get_node_or_null("%sDisabledPin" % tab_name) as TextureRect
		var expected_rect := BookBackgroundConfig.get_tab_rect(str(page_id), BookBackgroundConfig.PAGE_HUB)
		assert_not_null(tab)
		assert_true(tab.visible)
		assert_eq(tab.position, expected_rect.position)
		assert_eq(tab.size, expected_rect.size)
		assert_not_null(pin)
		assert_true(pin.visible)
		assert_not_null(pin.texture)
		assert_eq(pin.texture.resource_path, "res://assets/ui/backpack/locked_cell_pin.png")
		assert_eq(pin.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_true(pin.z_index > tab.z_index)

	var back_tab := art_layer.get_node_or_null("BackTab") as TextureRect
	assert_not_null(back_tab)
	assert_true(back_tab.visible)
	assert_eq(back_tab.position, BookBackgroundConfig.get_back_tab_rect().position)
	assert_eq(back_tab.size, BookBackgroundConfig.get_back_tab_rect().size)
	assert_eq(back_tab.z_index, BookBackgroundConfig.get_back_tab_z_index())

	art_layer.set_process(false)
	var pinned_album_position := (art_layer.get_node("AlbumTab") as TextureRect).position
	art_layer.call("_set_hovered_bookmark", BookBackgroundConfig.PAGE_HUB)
	await get_tree().create_timer(0.16).timeout
	assert_eq((art_layer.get_node("AlbumTab") as TextureRect).position, pinned_album_position)

	var design_root := page.get_node("DesignRoot") as Control
	var back_tab_global_position := design_root.get_global_transform() * BookBackgroundConfig.get_back_tab_rect().get_center()
	var album_tab_center := BookBackgroundConfig.get_tab_rect(BookBackgroundConfig.PAGE_HUB, BookBackgroundConfig.PAGE_HUB).get_center()
	var album_tab_global_position := design_root.get_global_transform() * album_tab_center
	assert_true(page.call("_is_disabled_story_bookmark_click", back_tab_global_position))
	assert_true(page.call("_is_disabled_story_bookmark_click", album_tab_global_position))
	assert_false(page.call("_is_disabled_story_bookmark_click", design_root.get_global_transform() * Vector2(900.0, 360.0)))


func test_bookmark_hover_pulls_visible_tabs_outward() -> void:
	var background := add_child_autofree(BookBackgroundScene.instantiate()) as Control
	await get_tree().process_frame
	background.set_process(false)

	background.call("set_active_page_id", BookBackgroundConfig.PAGE_HUB)
	var album_tab := background.get_node("AlbumTab") as TextureRect
	var left_base := BookBackgroundConfig.get_tab_rect(BookBackgroundConfig.PAGE_HUB, BookBackgroundConfig.PAGE_HUB)
	background.call("set_hovered_bookmark", BookBackgroundConfig.PAGE_HUB)
	await get_tree().create_timer(0.16).timeout

	var pull := BookBackgroundConfig.TAB_HOVER_PULL_DISTANCE
	assert_eq(album_tab.position, left_base.position + Vector2(-pull, 0.0))
	assert_eq(album_tab.size, left_base.size + Vector2(pull, 0.0))

	background.call("clear_hovered_bookmark")
	await get_tree().create_timer(0.16).timeout
	background.call("set_active_page_id", BookBackgroundConfig.PAGE_SETTINGS)
	var album_tab_right := background.get_node("AlbumTabRight") as TextureRect
	var right_base := BookBackgroundConfig.get_tab_rect(BookBackgroundConfig.PAGE_HUB, BookBackgroundConfig.PAGE_SETTINGS)
	background.call("set_hovered_bookmark", BookBackgroundConfig.PAGE_HUB)
	await get_tree().create_timer(0.16).timeout

	assert_eq(album_tab_right.position, right_base.position)
	assert_eq(album_tab_right.size, right_base.size + Vector2(pull, 0.0))


func test_book_page_tab_button_hover_pulls_right_bookmark() -> void:
	var navigator := BookPageNavigator.new() as Control
	for page_id in [
		BookBackgroundConfig.PAGE_HUB,
		BookBackgroundConfig.PAGE_BACKPACK,
		BookBackgroundConfig.PAGE_GALLERY,
		BookBackgroundConfig.PAGE_SETTINGS,
	]:
		var button := Button.new()
		button.name = "%sTabButton" % str(page_id).capitalize()
		navigator.add_child(button)
	add_child_autofree(navigator)

	var background := add_child_autofree(BookBackgroundScene.instantiate()) as Control
	background.set_process(false)
	background.call("set_active_page_id", BookBackgroundConfig.PAGE_SETTINGS)
	navigator.set("_pages", {BookBackgroundConfig.PAGE_SETTINGS: background})
	navigator.set("current_page_id", BookBackgroundConfig.PAGE_SETTINGS)
	await get_tree().process_frame

	var album_tab_right := background.get_node("AlbumTabRight") as TextureRect
	var right_base := BookBackgroundConfig.get_tab_rect(BookBackgroundConfig.PAGE_HUB, BookBackgroundConfig.PAGE_SETTINGS)
	var pull := BookBackgroundConfig.TAB_HOVER_PULL_DISTANCE

	navigator.call("_on_tab_button_mouse_entered", BookBackgroundConfig.PAGE_HUB)
	await get_tree().create_timer(0.16).timeout

	assert_eq(album_tab_right.position, right_base.position)
	assert_eq(album_tab_right.size, right_base.size + Vector2(pull, 0.0))

	navigator.call("_on_tab_button_mouse_exited", BookBackgroundConfig.PAGE_HUB)
	await get_tree().create_timer(0.16).timeout

	assert_eq(album_tab_right.position, right_base.position)
	assert_eq(album_tab_right.size, right_base.size)


func test_standalone_story_book_scene_hosts_existing_story_page() -> void:
	var scene := StoryBookScene.instantiate() as Control
	scene.set("auto_start_sequence", false)
	scene.set("transition_on_finish", false)
	add_child_autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(scene.has_method("is_standalone_story_book_scene"))
	assert_true(scene.call("is_standalone_story_book_scene"))
	assert_true(scene.has_method("play_story_book_page"))
	assert_true(scene.has_method("finish_story_sequence"))

	var page := scene.get_node_or_null("StoryBookPage") as Control
	assert_not_null(page)
	assert_eq(page.scene_file_path, "res://src/ui/story/story_book_page.tscn")
	assert_true(scene.call("play_story_book_page", "beginning"))
	assert_eq(str(page.get("_sequence_id")), "beginning")


func test_standalone_story_book_returns_to_hub_with_book_return_request() -> void:
	var scene := StoryBookScene.instantiate() as Control
	var fake_scene_manager := FakeSceneManager.new()
	add_child_autofree(fake_scene_manager)
	scene.set("auto_start_sequence", false)
	scene.set("scene_manager_override", fake_scene_manager)
	add_child_autofree(scene)
	await get_tree().process_frame

	scene.call("_transition_to_next_scene")

	assert_true(fake_scene_manager.story_return_requested)
	assert_eq(fake_scene_manager.direct_transition_calls.size(), 1)
	assert_eq(fake_scene_manager.direct_transition_calls[0]["scene_type"], GlobalScene.SceneType.HUB)
	assert_false(bool(fake_scene_manager.direct_transition_calls[0]["push_to_history"]))
	assert_eq(fake_scene_manager.transition_calls.size(), 0)


func test_story_to_hub_has_book_stack_transition_record() -> void:
	var navigator := BookPageNavigator.new() as Control
	for page_id in [
		BookBackgroundConfig.PAGE_HUB,
		BookBackgroundConfig.PAGE_BACKPACK,
		BookBackgroundConfig.PAGE_GALLERY,
		BookBackgroundConfig.PAGE_SETTINGS,
	]:
		var button := Button.new()
		button.name = "%sTabButton" % str(page_id).capitalize()
		navigator.add_child(button)
	add_child_autofree(navigator)
	await get_tree().process_frame

	navigator.call("_prepare_transition_page_stack", BookBackgroundConfig.PAGE_STORY, BookBackgroundConfig.PAGE_HUB)

	var records: Array = navigator.get("_transition_stack_records")
	assert_false(records.is_empty())
	var story_record := {}
	for record in records:
		if str(Dictionary(record).get("page_id", "")) == BookBackgroundConfig.PAGE_STORY:
			story_record = Dictionary(record)
			break
	assert_false(story_record.is_empty())
	assert_almost_eq(float(story_record.get("start_progress", -1.0)), 0.0, 0.001)
	assert_almost_eq(float(story_record.get("end_progress", -1.0)), 1.0, 0.001)


func test_story_page_bookmark_hotspots_stay_disabled() -> void:
	var navigator := BookPageNavigator.new() as Control
	for page_id in [
		BookBackgroundConfig.PAGE_HUB,
		BookBackgroundConfig.PAGE_BACKPACK,
		BookBackgroundConfig.PAGE_GALLERY,
		BookBackgroundConfig.PAGE_SETTINGS,
	]:
		var button := Button.new()
		button.name = "%sTabButton" % str(page_id).capitalize()
		navigator.add_child(button)
	add_child_autofree(navigator)
	await get_tree().process_frame

	navigator.set("current_page_id", BookBackgroundConfig.PAGE_STORY)
	navigator.call("_sync_tab_buttons")

	for button in navigator.get_children():
		if button is Button:
			assert_false(button.visible)
			assert_true(button.disabled)
			assert_eq(button.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_false(navigator.call("activate_tab_at_position", Vector2(80.0, 250.0)))
	assert_eq(str(navigator.get("current_page_id")), BookBackgroundConfig.PAGE_STORY)


func test_compressed_navigation_stack_ignores_story_page() -> void:
	var navigator := BookPageNavigator.new() as Control
	for page_id in [
		BookBackgroundConfig.PAGE_HUB,
		BookBackgroundConfig.PAGE_BACKPACK,
		BookBackgroundConfig.PAGE_GALLERY,
		BookBackgroundConfig.PAGE_SETTINGS,
	]:
		var button := Button.new()
		button.name = "%sTabButton" % str(page_id).capitalize()
		navigator.add_child(button)
	add_child_autofree(navigator)
	await get_tree().process_frame

	navigator.set("current_page_id", BookBackgroundConfig.PAGE_SETTINGS)
	navigator.call("_sync_compressed_page_stack")

	var root := navigator.get_node_or_null("BookRealtimeTransitionCanvas/RightCompressedStackRoot") as Control
	assert_not_null(root)
	assert_true(root.visible)
	assert_null(root.get_node_or_null("StoryCompressedSheetLayer"))
	assert_null(root.get_node_or_null("StoryCompressedContentLayer"))

	var hub_sheet := root.get_node_or_null("HubCompressedSheetLayer") as Control
	var hub_content := root.get_node_or_null("HubCompressedContentLayer") as Control
	var gallery_sheet := root.get_node_or_null("GalleryCompressedSheetLayer") as Control
	var backpack_sheet := root.get_node_or_null("BackpackCompressedSheetLayer") as Control
	assert_not_null(hub_sheet)
	assert_not_null(hub_content)
	assert_not_null(gallery_sheet)
	assert_not_null(backpack_sheet)
	assert_true(hub_content.visible)
	assert_true(hub_sheet.z_index > gallery_sheet.z_index)
	assert_true(gallery_sheet.z_index > backpack_sheet.z_index)
