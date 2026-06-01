extends GutTest

const AssetPaths = preload("res://src/core/assets/asset_paths.gd")


func test_runtime_asset_paths_do_not_point_to_source_image() -> void:
	var paths := _collect_registered_runtime_paths()
	for path in paths:
		assert_false(path.contains("res://assets/sourceImage"), "Runtime asset path should not use sourceImage: %s" % path)


func test_registered_runtime_paths_exist() -> void:
	var paths := _collect_registered_runtime_paths()
	for path in paths:
		assert_true(ResourceLoader.exists(path) or FileAccess.file_exists(path), "Registered asset path should exist: %s" % path)


func test_numbered_sequences_are_generated_from_specs() -> void:
	var bag_frames := AssetPaths.intro_bag_reveal_frame_paths()
	assert_eq(bag_frames.size(), 5)
	assert_eq(bag_frames[0], "res://assets/ui/battle/intro_bag_reveal/bag_reveal_01.png")
	assert_eq(bag_frames[4], "res://assets/ui/battle/intro_bag_reveal/bag_reveal_05.png")

	var cat_frames := AssetPaths.merchant_frame_paths("cat")
	assert_eq(cat_frames.size(), 11)
	assert_eq(cat_frames[0], "res://assets/characters/merchant/cat/cat_0000.png")
	assert_eq(cat_frames[1], "res://assets/characters/merchant/cat/cat_0000.png")
	assert_eq(cat_frames[4], "res://assets/characters/merchant/cat/cat_0004.png")
	assert_eq(cat_frames[10], "res://assets/characters/merchant/cat/cat_0010.png")


func _collect_registered_runtime_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	paths.append(AssetPaths.FONT_BODY)
	paths.append(AssetPaths.FONT_DISPLAY)
	paths.append(AssetPaths.STORY_EVENTS)
	paths.append(AssetPaths.PHOTO_CORNER)
	paths.append(AssetPaths.GALLERY_MEMORY_PAPER)
	paths.append(AssetPaths.XIAOMI_CAT)
	paths.append_array(PackedStringArray(AssetPaths.SHOP_SKULL_PATHS))
	_append_dictionary_values(paths, AssetPaths.BGM_PATHS)
	_append_dictionary_values(paths, AssetPaths.SFX_PATHS)
	_append_dictionary_values(paths, AssetPaths.HUB_BACKGROUND_PATHS)
	_append_dictionary_values(paths, AssetPaths.HUB_FOREGROUND_PATHS)
	paths.append_array(PackedStringArray(AssetPaths.POTION_STATE_PATHS))
	paths.append_array(AssetPaths.intro_bag_reveal_frame_paths())
	for merchant_id in AssetPaths.MERCHANT_FRAME_SPECS.keys():
		paths.append_array(AssetPaths.merchant_frame_paths(str(merchant_id)))
	return paths


func _append_dictionary_values(paths: PackedStringArray, source: Dictionary) -> void:
	for value in source.values():
		paths.append(str(value))
