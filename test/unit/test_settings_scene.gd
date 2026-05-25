extends GutTest

const SettingsScene = preload("res://src/ui/settings/audio_settings_ui.tscn")

func test_settings_scene_uses_new_background_and_controls() -> void:
	var ui = add_child_autofree(SettingsScene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	var background := ui.get_node_or_null("Background") as TextureRect
	assert_not_null(background)
	assert_not_null(background.texture)
	assert_eq(background.texture.resource_path, "res://assets/ui/settings/settings_background.png")
	assert_eq(background.texture.get_size(), Vector2(1920.0, 1080.0))

	for node_name in [
		"BackButton",
		"ResolutionOption",
		"WindowModeOption",
		"MasterSlider",
		"MusicSlider",
		"SfxSlider",
		"MuteButton",
		"AnimationSpeedOption",
		"ResetButton",
		"CloseButton",
	]:
		var node := ui.get_node_or_null("UiLayer/%s" % node_name) as Control
		assert_not_null(node, "Settings UI should expose %s" % node_name)
		assert_true(node.size.x > 0.0)
		assert_true(node.size.y > 0.0)

func test_settings_scene_updates_audio_values() -> void:
	var ui = add_child_autofree(SettingsScene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	var previous: float = float(SettingsManager.audio_settings["master_volume"])
	var slider := ui.get_node("UiLayer/MasterSlider") as HSlider
	slider.value = 0.42
	await get_tree().process_frame

	assert_almost_eq(float(SettingsManager.audio_settings["master_volume"]), 0.42, 0.001)
	SettingsManager.set_master_volume(previous)
