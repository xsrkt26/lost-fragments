extends GutTest

const MainMenuScene = preload("res://src/ui/main_menu/main_menu.tscn")
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
	var start_new_run_call_count := 0

	func start_new_run() -> void:
		start_new_run_call_count += 1

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
