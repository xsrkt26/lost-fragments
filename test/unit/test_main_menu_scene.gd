extends GutTest

const MainMenuScene = preload("res://src/ui/main_menu/main_menu.tscn")
const BUTTON_NAMES := [
	"NewGameButton",
	"ContinueButton",
	"GalleryButton",
	"SettingsButton",
	"QuitButton",
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
	var menu = add_child_autofree(MainMenuScene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	var background := menu.get_node_or_null("Background") as TextureRect
	assert_not_null(background)
	assert_not_null(background.texture)
	assert_eq(background.texture.resource_path, "res://assets/ui/main_menu/main_menu_background.png")
	assert_eq(background.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	assert_eq(background.texture.get_size(), Vector2(1920.0, 1080.0))

	for button_name in BUTTON_NAMES:
		var button := menu.get_node_or_null("MenuHotspots/%s" % button_name) as Button
		assert_not_null(button, "Main menu should expose hotspot: %s" % button_name)
		assert_eq(button.text, "")
		assert_true(button.tooltip_text.length() > 0)
		assert_true(button.size.x > 0.0)
		assert_true(button.size.y > 0.0)
		assert_null(button.get_node_or_null("Scroll"), "New main menu art already contains the labels and tabs.")
		var hover_style := button.get_theme_stylebox("hover") as StyleBoxFlat
		assert_not_null(hover_style)
		assert_almost_eq(hover_style.bg_color.a, 0.0, 0.001)

	assert_not_null(menu.get_node_or_null("MenuHotspots/ContinueDisabledOverlay"))
	assert_null(menu.get_node_or_null("CanvasLayer/SettingsContainer"))
	assert_true(GlobalScene.SceneType.keys().has("SETTINGS"))
	assert_eq(GlobalScene.SCENE_PATHS[GlobalScene.SceneType.SETTINGS], "res://src/ui/settings/audio_settings_ui.tscn")

func test_new_game_action_starts_run_without_intermediate_scene() -> void:
	var menu = add_child_autofree(MainMenuScene.instantiate())
	var fake_run_manager = add_child_autofree(FakeRunManager.new())
	menu.run_manager_override = fake_run_manager

	assert_true(menu._start_new_run())
	assert_eq(fake_run_manager.start_new_run_call_count, 1)
	assert_false(GlobalScene.SceneType.keys().has("NEW_GAME"))
	assert_false(GlobalScene.SCENE_PATHS.values().has("res://src/ui/new_game/new_game_scene.tscn"))
