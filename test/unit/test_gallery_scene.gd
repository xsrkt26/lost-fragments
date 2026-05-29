extends GutTest

const GalleryScene = preload("res://src/ui/gallery/gallery_scene.tscn")

func test_gallery_scene_uses_split_book_art_and_item_grid() -> void:
	var gallery = add_child_autofree(GalleryScene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_null(gallery.get_node_or_null("Background"), "Gallery should be assembled from split art layers, not one full-screen bitmap.")
	var art_layer := gallery.get_node_or_null("DesignRoot/ArtLayer") as Control
	assert_not_null(art_layer)
	assert_true(art_layer.has_method("get_visible_page_sheet_count"))
	assert_eq(art_layer.call("get_visible_page_sheet_count"), 3)
	for node_name in [
		"WoodFloor",
		"RedBookCover",
		"AlbumPage",
		"AlbumRingRight",
		"GalleryTab",
		"Magnifier",
		"ForgetMeNot",
	]:
		var art := gallery.get_node_or_null("DesignRoot/ArtLayer/%s" % node_name) as TextureRect
		assert_not_null(art, "Gallery split art should expose %s" % node_name)
		assert_not_null(art.texture)
		assert_true(art.texture.resource_path != "res://assets/ui/gallery/gallery_background.png")
	var rope_grid := gallery.get_node_or_null("DesignRoot/ArtLayer/GridBackdrop") as Control
	assert_not_null(rope_grid)
	assert_not_null(rope_grid.get_script())

	var back_button := gallery.get_node_or_null("DesignRoot/UiLayer/BackButton") as Button
	assert_not_null(back_button)
	assert_true(back_button.size.x > 0.0)

	var item_grid := gallery.get_node_or_null("DesignRoot/UiLayer/ItemScroll/ItemGrid") as GridContainer
	assert_not_null(item_grid)
	assert_eq(item_grid.columns, 7)
	assert_true(item_grid.get_child_count() > 0)

	var first_button := item_grid.get_child(0) as Button
	assert_not_null(first_button)
	assert_true(first_button.has_meta("item_id"))
	assert_true(first_button.tooltip_text.length() > 0)
	assert_not_null(first_button.get_node_or_null("PhotoCorner"))
	assert_not_null(first_button.get_node_or_null("SelectionPin"))

	var selected_paper := gallery.get_node_or_null("DesignRoot/UiLayer/SelectedPaper") as Control
	var memory_paper := gallery.get_node_or_null("DesignRoot/UiLayer/MemoryPaper") as Control
	assert_not_null(selected_paper)
	assert_not_null(memory_paper)

	var detail_name := gallery.get_node_or_null("DesignRoot/UiLayer/DetailName") as Label
	assert_not_null(detail_name)
	assert_true(detail_name.text.length() > 0)
