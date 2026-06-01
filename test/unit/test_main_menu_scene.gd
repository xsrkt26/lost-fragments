extends GutTest

const MainMenuScene = preload("res://src/ui/main_menu/main_menu.tscn")
const BookBackgroundConfig = preload("res://src/ui/book/book_background_config.gd")
const StageConfig = preload("res://src/core/stage/stage_config.gd")
const RouteConfig = preload("res://src/core/route/route_config.gd")
const TEXT_BUTTON_NAMES := [
	"NewGameButton",
	"ContinueButton",
	"GalleryButton",
	"SettingsButton",
]

class FakeRunManager:
	extends Node

	var saver = null
	var is_run_complete := false
	var current_act := 1
	var current_route_id: String = RouteConfig.DEFAULT_ROUTE_ID
	var current_route_index := 0
	var completed_route_nodes: Array[int] = []
	var is_run_active := false
	var debug_hub_page_request := ""
	var debug_hub_advance_next_node_request := false
	var start_new_run_call_count := 0
	var save_current_state_call_count := 0

	func start_new_run() -> void:
		start_new_run_call_count += 1
		is_run_active = true
		is_run_complete = false
		current_act = 1
		current_route_id = RouteConfig.DEFAULT_ROUTE_ID
		current_route_index = 0
		completed_route_nodes = []

	func save_current_state() -> void:
		save_current_state_call_count += 1


class FakeSaver:
	var has_save_result := false

	func _init(result: bool) -> void:
		has_save_result = result

	func has_save() -> bool:
		return has_save_result


class FakeSceneManager:
	extends Node

	var transition_calls: Array[Dictionary] = []

	func transition_to(scene_type: int, push_to_history: bool = true) -> void:
		transition_calls.append({
			"scene_type": scene_type,
			"push_to_history": push_to_history,
		})


func _press_key(menu: Node, keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	menu._input(event)

func test_main_menu_uses_full_background_art_and_click_hotspots() -> void:
	var menu = MainMenuScene.instantiate()
	var editor_button_state := {}
	for button_name in TEXT_BUTTON_NAMES:
		var editor_button := menu.get_node("DesignRoot/MenuHotspots/%s" % button_name) as Button
		editor_button_state[button_name] = {
			"text": editor_button.text,
			"tooltip": editor_button.tooltip_text,
			"theme_type_variation": editor_button.theme_type_variation,
			"font_size": editor_button.get_theme_font_size("font_size"),
			"font_color": editor_button.get_theme_color("font_color"),
			"font_hover_color": editor_button.get_theme_color("font_hover_color"),
		}
	var editor_quit_button := menu.get_node("DesignRoot/MenuHotspots/QuitButton") as TextureButton
	var editor_quit_tooltip := editor_quit_button.tooltip_text

	add_child_autofree(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	var background := menu.get_node_or_null("DesignRoot/Background") as TextureRect
	assert_not_null(background)
	assert_not_null(background.texture)
	assert_eq(background.texture.resource_path, "res://assets/ui/main_menu/main_menu_background.png")
	assert_eq(background.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	assert_eq(background.texture.get_size(), Vector2(1920.0, 1080.0))

	for button_name in TEXT_BUTTON_NAMES:
		var button := menu.get_node_or_null("DesignRoot/MenuHotspots/%s" % button_name) as Button
		assert_not_null(button, "Main menu should expose hotspot: %s" % button_name)
		var editor_state: Dictionary = editor_button_state[button_name]
		assert_eq(button.text, editor_state["text"])
		assert_eq(button.tooltip_text, editor_state["tooltip"])
		assert_true(button.size.x > 0.0)
		assert_true(button.size.y > 0.0)
		assert_eq(button.theme_type_variation, editor_state["theme_type_variation"])
		assert_not_null(button.get_theme_font("font"))
		assert_eq(button.get_theme_font_size("font_size"), editor_state["font_size"])
		assert_eq(button.get_theme_color("font_color"), editor_state["font_color"])
		assert_eq(button.get_theme_color("font_hover_color"), editor_state["font_hover_color"])
		var hover_style := button.get_theme_stylebox("hover") as StyleBoxFlat
		assert_not_null(hover_style)
		assert_almost_eq(hover_style.bg_color.a, 0.0, 0.001)
		assert_true(button.get_signal_connection_list("mouse_entered").size() > 0)
		assert_true(button.get_signal_connection_list("button_down").size() > 0)

	var quit_button := menu.get_node_or_null("DesignRoot/MenuHotspots/QuitButton") as TextureButton
	assert_not_null(quit_button, "Main menu should expose interactive lighter button")
	assert_not_null(quit_button.texture_normal)
	assert_not_null(quit_button.texture_hover)
	assert_not_null(quit_button.texture_pressed)
	assert_eq(quit_button.texture_normal.resource_path, "res://assets/ui/main_menu/lighter_closed.png")
	assert_eq(quit_button.texture_hover.resource_path, "res://assets/ui/main_menu/lighter_open.png")
	assert_eq(quit_button.texture_pressed.resource_path, "res://assets/ui/main_menu/lighter_open.png")
	assert_eq(quit_button.stretch_mode, TextureButton.STRETCH_KEEP_CENTERED)
	assert_true(quit_button.ignore_texture_size)
	assert_eq(quit_button.tooltip_text, editor_quit_tooltip)
	assert_true(quit_button.size.x > 0.0)
	assert_true(quit_button.size.y > 0.0)
	assert_true(quit_button.get_signal_connection_list("mouse_entered").size() > 0)

	assert_not_null(menu.get_node_or_null("DesignRoot/MenuHotspots/ContinueDisabledOverlay"))
	assert_null(menu.get_node_or_null("VersionLabel"))
	assert_null(menu.get_node_or_null("CanvasLayer/SettingsContainer"))
	assert_true(GlobalScene.SceneType.keys().has("SETTINGS"))
	assert_eq(GlobalScene.SCENE_PATHS[GlobalScene.SceneType.SETTINGS], "res://src/ui/settings/audio_settings_ui.tscn")
	assert_true(GlobalScene.SceneType.keys().has("STORY_BOOK"))
	assert_eq(GlobalScene.SCENE_PATHS[GlobalScene.SceneType.STORY_BOOK], "res://src/ui/story/story_book_scene.tscn")

func test_main_menu_hover_feedback_floats_text_and_lighter() -> void:
	var menu = add_child_autofree(MainMenuScene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	var new_game_button := menu.get_node("DesignRoot/MenuHotspots/NewGameButton") as Button
	var quit_button := menu.get_node("DesignRoot/MenuHotspots/QuitButton") as TextureButton
	var new_game_position := new_game_button.position
	var quit_position := quit_button.position
	var new_game_scale := new_game_button.scale
	var quit_scale := quit_button.scale

	new_game_button.mouse_entered.emit()
	quit_button.mouse_entered.emit()
	await get_tree().create_timer(0.18).timeout

	assert_true(new_game_button.position.y < new_game_position.y)
	assert_true(new_game_button.scale.x > new_game_scale.x)
	assert_true(quit_button.position.y < quit_position.y)
	assert_true(quit_button.scale.x > quit_scale.x)

	new_game_button.mouse_exited.emit()
	quit_button.mouse_exited.emit()
	await get_tree().create_timer(0.18).timeout

	assert_almost_eq(new_game_button.position.y, new_game_position.y, 1.0)
	assert_almost_eq(new_game_button.scale.x, new_game_scale.x, 0.02)
	assert_almost_eq(quit_button.position.y, quit_position.y, 1.0)
	assert_almost_eq(quit_button.scale.x, quit_scale.x, 0.02)

func test_new_game_action_starts_run_without_intermediate_scene() -> void:
	var menu = add_child_autofree(MainMenuScene.instantiate())
	var fake_run_manager = add_child_autofree(FakeRunManager.new())
	menu.run_manager_override = fake_run_manager

	assert_true(menu._start_new_run())
	assert_eq(fake_run_manager.start_new_run_call_count, 1)
	assert_false(GlobalScene.SceneType.keys().has("NEW_GAME"))
	assert_false(GlobalScene.SCENE_PATHS.values().has("res://src/ui/new_game/new_game_scene.tscn"))


func test_new_game_always_starts_beginning_story_and_keeps_continue_button_hidden() -> void:
	var menu = MainMenuScene.instantiate()
	var fake_run_manager: FakeRunManager = add_child_autofree(FakeRunManager.new())
	var fake_scene_manager: FakeSceneManager = add_child_autofree(FakeSceneManager.new())
	fake_run_manager.saver = FakeSaver.new(true)
	menu.run_manager_override = fake_run_manager
	menu.scene_manager_override = fake_scene_manager
	add_child_autofree(menu)
	await get_tree().process_frame

	var continue_button := menu.get_node("DesignRoot/MenuHotspots/ContinueButton") as Button
	var continue_disabled_overlay := menu.get_node("DesignRoot/MenuHotspots/ContinueDisabledOverlay") as ColorRect
	assert_false(continue_button.visible)
	assert_true(continue_button.disabled)
	assert_false(continue_disabled_overlay.visible)
	assert_eq(menu._resolve_dream_entry_scene(), GlobalScene.SceneType.STORY_BOOK)
	menu._on_new_game_button_pressed()
	assert_eq(fake_scene_manager.transition_calls.size(), 1)
	assert_eq(fake_scene_manager.transition_calls[0]["scene_type"], GlobalScene.SceneType.STORY_BOOK)
	assert_eq(fake_run_manager.start_new_run_call_count, 1)

	fake_run_manager.saver = FakeSaver.new(false)

	assert_eq(menu._resolve_dream_entry_scene(), GlobalScene.SceneType.STORY_BOOK)
	menu._on_new_game_button_pressed()
	assert_eq(fake_scene_manager.transition_calls.size(), 2)
	assert_eq(fake_scene_manager.transition_calls[1]["scene_type"], GlobalScene.SceneType.STORY_BOOK)
	assert_eq(fake_run_manager.start_new_run_call_count, 2)


func test_main_menu_f_shortcuts_jump_to_target_act_and_prepare_hub_run() -> void:
	var menu = add_child_autofree(MainMenuScene.instantiate())
	var fake_run_manager: FakeRunManager = add_child_autofree(FakeRunManager.new())
	var fake_scene_manager: FakeSceneManager = add_child_autofree(FakeSceneManager.new())
	menu.run_manager_override = fake_run_manager
	menu.scene_manager_override = fake_scene_manager

	for target_act in [1, 4, 6]:
		var keycode: int = KEY_F1 + (target_act - 1)
		_press_key(menu, keycode)
		assert_eq(fake_run_manager.current_act, target_act)
		assert_eq(fake_run_manager.current_route_index, 0)
		assert_eq(fake_run_manager.current_route_id, StageConfig.get_route_id_for_act(target_act, RouteConfig.DEFAULT_ROUTE_ID))
		assert_true(fake_run_manager.is_run_active)
		assert_false(fake_run_manager.is_run_complete)
	assert_eq(fake_run_manager.start_new_run_call_count, 3)
	assert_eq(fake_scene_manager.transition_calls.size(), 3)
	for call in fake_scene_manager.transition_calls:
		assert_eq(call["scene_type"], GlobalScene.SceneType.HUB)


func test_main_menu_f789f10_shortcuts_forward_hub_requests() -> void:
	var menu = add_child_autofree(MainMenuScene.instantiate())
	var fake_run_manager: FakeRunManager = add_child_autofree(FakeRunManager.new())
	var fake_scene_manager: FakeSceneManager = add_child_autofree(FakeSceneManager.new())
	menu.run_manager_override = fake_run_manager
	menu.scene_manager_override = fake_scene_manager
	fake_run_manager.is_run_active = true

	_press_key(menu, KEY_F7)
	assert_eq(fake_run_manager.debug_hub_page_request, BookBackgroundConfig.PAGE_BACKPACK)
	assert_false(fake_run_manager.debug_hub_advance_next_node_request)

	_press_key(menu, KEY_F8)
	assert_eq(fake_run_manager.debug_hub_page_request, BookBackgroundConfig.PAGE_GALLERY)
	assert_false(fake_run_manager.debug_hub_advance_next_node_request)

	_press_key(menu, KEY_F9)
	assert_eq(fake_run_manager.debug_hub_page_request, BookBackgroundConfig.PAGE_SETTINGS)
	assert_false(fake_run_manager.debug_hub_advance_next_node_request)

	_press_key(menu, KEY_F10)
	assert_eq(fake_run_manager.debug_hub_page_request, "")
	assert_true(fake_run_manager.debug_hub_advance_next_node_request)
	assert_eq(fake_scene_manager.transition_calls.size(), 4)
	for call in fake_scene_manager.transition_calls:
		assert_eq(call["scene_type"], GlobalScene.SceneType.HUB)


func test_scene_manager_caches_only_whitelisted_scenes() -> void:
	var previous_cache: Dictionary = GlobalScene._preloaded_scenes.duplicate()
	GlobalScene.clear_scene_cache(true)

	var hub_scene := PackedScene.new()
	var gallery_scene := PackedScene.new()
	GlobalScene._cache_scene_if_allowed(GlobalScene.SceneType.HUB, hub_scene)
	GlobalScene._cache_scene_if_allowed(GlobalScene.SceneType.GALLERY, gallery_scene)

	var caches_hub := GlobalScene._preloaded_scenes.has(GlobalScene.SceneType.HUB)
	var caches_gallery := GlobalScene._preloaded_scenes.has(GlobalScene.SceneType.GALLERY)
	var caches_main_menu := GlobalScene._should_cache_scene(GlobalScene.SceneType.MAIN_MENU)
	var caches_cutscene := GlobalScene._should_cache_scene(GlobalScene.SceneType.CUTSCENE)
	GlobalScene._preloaded_scenes = previous_cache

	assert_true(caches_hub)
	assert_false(caches_gallery)
	assert_true(caches_main_menu)
	assert_false(caches_cutscene)
