extends GutTest

const SettingsScene = preload("res://src/ui/settings/audio_settings_ui.tscn")

func test_settings_scene_uses_split_book_art_and_controls() -> void:
	var ui = add_child_autofree(SettingsScene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_null(ui.get_node_or_null("Background"), "Settings should be assembled from split art layers, not one full-screen bitmap.")
	var art_layer := ui.get_node_or_null("ArtLayer") as Control
	assert_not_null(art_layer)
	for node_name in [
		"WoodFloor",
		"RedBookCover",
		"AlbumPage",
		"AlbumRingRight",
		"SettingsTab",
		"ZipperVisualMaster",
	]:
		var art := ui.get_node_or_null("ArtLayer/%s" % node_name) as Control
		assert_not_null(art, "Settings split art should expose %s" % node_name)
		if art is TextureRect:
			assert_not_null(art.texture)
			assert_true(art.texture.resource_path != "res://assets/ui/settings/settings_background.png")

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

func test_settings_zipper_tracks_open_when_slider_is_lowered() -> void:
	var ui = add_child_autofree(SettingsScene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	var slider := ui.get_node("UiLayer/MasterSlider") as HSlider
	var visual = ui.get_node("ArtLayer/ZipperVisualMaster")
	var previous: float = float(SettingsManager.audio_settings["master_volume"])

	slider.value = 1.0
	await get_tree().process_frame
	var closed_layout: Dictionary = visual.call("get_debug_layout")
	assert_almost_eq(float(closed_layout["open_width"]), 0.0, 0.01)
	assert_true(float(closed_layout["closed_gap"]) > 0.0)

	slider.value = 0.2
	await get_tree().process_frame
	var open_layout: Dictionary = visual.call("get_debug_layout")
	assert_true(float(open_layout["closed_width"]) > 0.0)
	assert_true(float(open_layout["open_width"]) > 0.0)
	assert_almost_eq(float(open_layout["closed_width"]) + float(open_layout["open_width"]), (visual as Control).size.x, 0.01)
	SettingsManager.set_master_volume(previous)
