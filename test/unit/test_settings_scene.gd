extends GutTest

const SettingsScene = preload("res://src/ui/settings/audio_settings_ui.tscn")
const BookBackgroundConfig = preload("res://src/ui/book/book_background_config.gd")

func test_settings_scene_uses_split_book_art_and_controls() -> void:
	var ui = add_child_autofree(SettingsScene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_null(ui.get_node_or_null("Background"), "Settings should be assembled from split art layers, not one full-screen bitmap.")
	var art_layer := ui.get_node_or_null("DesignRoot/ArtLayer") as Control
	assert_not_null(art_layer)
	assert_true(art_layer.has_method("get_visible_page_sheet_count"))
	assert_eq(art_layer.call("get_visible_page_sheet_count"), 1)
	var album_page := ui.get_node_or_null("DesignRoot/ArtLayer/AlbumPage") as TextureRect
	var page_middle := ui.get_node_or_null("DesignRoot/ArtLayer/PageMiddle") as TextureRect
	var backpack_cover := ui.get_node_or_null("DesignRoot/ArtLayer/PageBackpackCover") as TextureRect
	var route_cover := ui.get_node_or_null("DesignRoot/ArtLayer/PageRouteCover") as TextureRect
	assert_not_null(album_page)
	assert_not_null(page_middle)
	assert_not_null(backpack_cover)
	assert_not_null(route_cover)
	assert_false(album_page.visible)
	assert_false(page_middle.visible)
	assert_false(backpack_cover.visible)
	assert_true(route_cover.visible)
	for node_name in [
		"WoodFloor",
		"RedBookCover",
		"AlbumPage",
		"AlbumRingRight",
		"SettingsTab",
		"ZipperVisualMaster",
	]:
		var art := ui.get_node_or_null("DesignRoot/ArtLayer/%s" % node_name) as Control
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
		"LabelMaster",
		"LabelWindowMode",
	]:
		var node := ui.get_node_or_null("DesignRoot/UiLayer/%s" % node_name) as Control
		assert_not_null(node, "Settings UI should expose %s" % node_name)
		assert_true(node.size.x > 0.0)
		assert_true(node.size.y > 0.0)

	var master_visual := ui.get_node("DesignRoot/ArtLayer/ZipperVisualMaster") as Control
	assert_almost_eq(master_visual.position.x, 754.0, 0.01)
	assert_almost_eq(master_visual.size.x, 520.0, 0.01)
	assert_almost_eq(art_layer.size.x, 1920.0, 0.01)
	assert_true(art_layer.scale.x > 0.0)

	var label_video := ui.get_node("DesignRoot/UiLayer/LabelVideo") as Label
	var label_resolution := ui.get_node("DesignRoot/UiLayer/LabelResolution") as Label
	var label_master := ui.get_node("DesignRoot/UiLayer/LabelMaster") as Label
	assert_true(label_resolution.position.x > label_video.position.x)
	assert_true(label_master.position.x > (ui.get_node("DesignRoot/UiLayer/LabelAudio") as Label).position.x)
	assert_false(label_resolution.text.contains(":"))
	assert_false(label_master.text.contains(":"))

	var mute_button := ui.get_node("DesignRoot/UiLayer/MuteButton") as Button
	var reset_button := ui.get_node("DesignRoot/UiLayer/ResetButton") as Button
	var close_button := ui.get_node("DesignRoot/UiLayer/CloseButton") as Button
	var master_value := ui.get_node("DesignRoot/UiLayer/MasterValue") as Label
	assert_almost_eq(mute_button.position.x, master_value.position.x, 0.01)
	assert_almost_eq(mute_button.position.x + mute_button.size.x, master_value.position.x + master_value.size.x, 0.01)
	assert_almost_eq(reset_button.position.y, close_button.position.y, 0.01)
	assert_true(reset_button.position.x < close_button.position.x)

	var album_tab_right := ui.get_node("DesignRoot/ArtLayer/AlbumTabRight") as TextureRect
	var backpack_tab_right := ui.get_node("DesignRoot/ArtLayer/BackpackTabRight") as TextureRect
	var gallery_tab_right := ui.get_node("DesignRoot/ArtLayer/GalleryTabRight") as TextureRect
	var settings_tab_right := ui.get_node("DesignRoot/ArtLayer/SettingsTabRight") as TextureRect
	var settings_tab := ui.get_node("DesignRoot/ArtLayer/SettingsTab") as TextureRect
	var album_ring_right := ui.get_node("DesignRoot/ArtLayer/AlbumRingRight") as TextureRect
	assert_true(album_tab_right.visible)
	assert_true(backpack_tab_right.visible)
	assert_true(gallery_tab_right.visible)
	assert_false(settings_tab_right.visible)
	assert_true(settings_tab.visible)
	assert_eq(settings_tab.z_index, BookBackgroundConfig.get_tab_z_index(BookBackgroundConfig.PAGE_SETTINGS, BookBackgroundConfig.PAGE_SETTINGS))
	assert_true(settings_tab.z_index > route_cover.z_index)
	assert_eq(album_tab_right.z_index, BookBackgroundConfig.get_right_tab_z_index())
	assert_eq(backpack_tab_right.z_index, BookBackgroundConfig.get_right_tab_z_index())
	assert_eq(gallery_tab_right.z_index, BookBackgroundConfig.get_right_tab_z_index())
	assert_true(gallery_tab_right.z_index > album_page.z_index)
	assert_true(gallery_tab_right.z_index < album_ring_right.z_index)
	var settings_tab_rect := BookBackgroundConfig.get_tab_rect(BookBackgroundConfig.PAGE_SETTINGS, BookBackgroundConfig.PAGE_SETTINGS)
	var album_tab_right_rect := BookBackgroundConfig.get_tab_rect(BookBackgroundConfig.PAGE_HUB, BookBackgroundConfig.PAGE_SETTINGS)
	var backpack_tab_right_rect := BookBackgroundConfig.get_tab_rect(BookBackgroundConfig.PAGE_BACKPACK, BookBackgroundConfig.PAGE_SETTINGS)
	var gallery_tab_right_rect := BookBackgroundConfig.get_tab_rect(BookBackgroundConfig.PAGE_GALLERY, BookBackgroundConfig.PAGE_SETTINGS)
	assert_eq(settings_tab.position, settings_tab_rect.position)
	assert_eq(settings_tab.size, settings_tab_rect.size)
	assert_eq(album_tab_right.position, album_tab_right_rect.position)
	assert_eq(album_tab_right.size, album_tab_right_rect.size)
	assert_eq(backpack_tab_right.position, backpack_tab_right_rect.position)
	assert_eq(backpack_tab_right.size, backpack_tab_right_rect.size)
	assert_eq(gallery_tab_right.position, gallery_tab_right_rect.position)
	assert_eq(gallery_tab_right.size, gallery_tab_right_rect.size)

func test_settings_scene_updates_audio_values() -> void:
	var ui = add_child_autofree(SettingsScene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	var previous: float = float(SettingsManager.audio_settings["master_volume"])
	var slider := ui.get_node("DesignRoot/UiLayer/MasterSlider") as HSlider
	slider.value = 0.42
	await get_tree().process_frame

	assert_almost_eq(float(SettingsManager.audio_settings["master_volume"]), 0.42, 0.001)
	SettingsManager.set_master_volume(previous)

func test_settings_manager_applies_audio_to_real_buses() -> void:
	var previous_audio := SettingsManager.audio_settings.duplicate(true)

	SettingsManager.set_music_volume(0.25)
	SettingsManager.set_sfx_volume(0.35)
	SettingsManager.set_muted(true)

	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	assert_true(music_bus != -1)
	assert_true(sfx_bus != -1)
	assert_almost_eq(db_to_linear(AudioServer.get_bus_volume_db(music_bus)), 0.25, 0.01)
	assert_almost_eq(db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)), 0.35, 0.01)
	assert_true(AudioServer.is_bus_mute(0))

	_restore_settings(previous_audio, SettingsManager.display_settings, SettingsManager.game_settings)

func test_settings_defaults_start_muted() -> void:
	var previous_audio := SettingsManager.audio_settings.duplicate(true)
	var previous_display := SettingsManager.display_settings.duplicate(true)
	var previous_game := SettingsManager.game_settings.duplicate(true)

	SettingsManager.reset_to_defaults()

	assert_true(bool(SettingsManager.audio_settings["is_muted"]))
	assert_true(AudioServer.is_bus_mute(0))

	_restore_settings(previous_audio, previous_display, previous_game)

func test_settings_scene_updates_all_setting_categories() -> void:
	var previous_audio := SettingsManager.audio_settings.duplicate(true)
	var previous_display := SettingsManager.display_settings.duplicate(true)
	var previous_game := SettingsManager.game_settings.duplicate(true)
	var ui = add_child_autofree(SettingsScene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	var music_slider := ui.get_node("DesignRoot/UiLayer/MusicSlider") as HSlider
	var sfx_slider := ui.get_node("DesignRoot/UiLayer/SfxSlider") as HSlider
	var mute_button := ui.get_node("DesignRoot/UiLayer/MuteButton") as Button
	var resolution_option := ui.get_node("DesignRoot/UiLayer/ResolutionOption") as OptionButton
	var window_mode_option := ui.get_node("DesignRoot/UiLayer/WindowModeOption") as OptionButton
	var animation_speed_option := ui.get_node("DesignRoot/UiLayer/AnimationSpeedOption") as OptionButton

	music_slider.value = 0.31
	sfx_slider.value = 0.47
	mute_button.emit_signal("pressed")
	resolution_option.emit_signal("item_selected", 1)
	window_mode_option.emit_signal("item_selected", 1)
	animation_speed_option.emit_signal("item_selected", 2)
	await get_tree().process_frame

	assert_almost_eq(float(SettingsManager.audio_settings["music_volume"]), 0.31, 0.001)
	assert_almost_eq(float(SettingsManager.audio_settings["sfx_volume"]), 0.47, 0.001)
	assert_ne(bool(SettingsManager.audio_settings["is_muted"]), bool(previous_audio["is_muted"]))
	assert_eq(SettingsManager.display_settings["resolution"], SettingsManager.RESOLUTION_OPTIONS[1])
	assert_eq(str(SettingsManager.display_settings["window_mode"]), SettingsManager.WINDOW_MODE_FULLSCREEN)
	assert_eq(str(SettingsManager.game_settings["animation_speed"]), SettingsManager.ANIMATION_SPEED_FAST)

	_restore_settings(previous_audio, previous_display, previous_game)

func test_settings_zipper_tracks_open_when_slider_is_lowered() -> void:
	var ui = add_child_autofree(SettingsScene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	var slider := ui.get_node("DesignRoot/UiLayer/MasterSlider") as HSlider
	var visual = ui.get_node("DesignRoot/ArtLayer/ZipperVisualMaster")
	var previous: float = float(SettingsManager.audio_settings["master_volume"])

	slider.value = 1.0
	await get_tree().process_frame
	var closed_layout: Dictionary = visual.call("get_debug_layout")
	assert_almost_eq(float(closed_layout["open_width"]), 0.0, 0.01)
	assert_true(float(closed_layout["closed_overlap"]) >= 6.0)
	assert_true(float(closed_layout["closed_gap"]) <= 0.0)

	slider.value = 0.2
	await get_tree().process_frame
	var open_layout: Dictionary = visual.call("get_debug_layout")
	assert_true(float(open_layout["open_start_x"]) >= float(open_layout["head_right_x"]) - 0.01)
	assert_true(float(open_layout["closed_width"]) > 0.0)
	assert_true(float(open_layout["open_width"]) > 0.0)
	assert_almost_eq(float(open_layout["closed_width"]) + float(open_layout["open_width"]), (visual as Control).size.x, 0.01)
	SettingsManager.set_master_volume(previous)

func _restore_settings(audio: Dictionary, display: Dictionary, game: Dictionary) -> void:
	SettingsManager.audio_settings = audio.duplicate(true)
	SettingsManager.display_settings = display.duplicate(true)
	SettingsManager.game_settings = game.duplicate(true)
	SettingsManager.apply_audio_settings()
	SettingsManager.apply_display_settings()
	SettingsManager.save_settings()
