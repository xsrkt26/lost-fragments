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
	var album_page := gallery.get_node_or_null("DesignRoot/ArtLayer/AlbumPage") as TextureRect
	var page_middle := gallery.get_node_or_null("DesignRoot/ArtLayer/PageMiddle") as TextureRect
	var backpack_cover := gallery.get_node_or_null("DesignRoot/ArtLayer/PageBackpackCover") as TextureRect
	var route_cover := gallery.get_node_or_null("DesignRoot/ArtLayer/PageRouteCover") as TextureRect
	assert_not_null(album_page)
	assert_not_null(page_middle)
	assert_not_null(backpack_cover)
	assert_not_null(route_cover)
	assert_false(album_page.visible)
	assert_true(page_middle.visible)
	assert_true(backpack_cover.visible)
	assert_true(route_cover.visible)
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
	assert_false(rope_grid.visible)

	var back_button := gallery.get_node_or_null("DesignRoot/UiLayer/BackButton") as Button
	assert_not_null(back_button)
	assert_true(back_button.size.x > 0.0)

	var item_scroll := gallery.get_node_or_null("DesignRoot/UiLayer/ItemScroll") as ScrollContainer
	assert_not_null(item_scroll)
	assert_eq(item_scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_SHOW_NEVER)
	var grid_image_backdrop := gallery.get_node_or_null("DesignRoot/UiLayer/GridImageBackdrop") as Control
	assert_not_null(grid_image_backdrop)
	assert_not_null(grid_image_backdrop.get_script())
	assert_false(grid_image_backdrop.clip_contents)
	assert_eq(grid_image_backdrop.position, item_scroll.position)
	assert_eq(grid_image_backdrop.size, item_scroll.size)
	assert_true(grid_image_backdrop.get_index() < item_scroll.get_index())
	var frame_texture := load("res://assets/ui/gallery/gallery_grid_background.png") as Texture2D
	assert_not_null(frame_texture)
	assert_false(frame_texture.resource_path.contains("sourceImage"))
	var frame_image := frame_texture.get_image()
	assert_not_null(frame_image)
	assert_true(frame_image.get_pixel(10, 10).a < 0.1)
	assert_true(frame_image.get_pixel(94, 114).a > 0.5)

	var item_grid := gallery.get_node_or_null("DesignRoot/UiLayer/ItemScroll/ItemGrid") as GridContainer
	assert_not_null(item_grid)
	assert_eq(item_grid.columns, 6)
	assert_true(item_grid.get_child_count() > 0)

	var first_button := item_grid.get_child(0) as Button
	assert_not_null(first_button)
	assert_true(first_button.has_meta("item_id"))
	assert_true(first_button.tooltip_text.length() > 0)
	var cell_fill := first_button.get_node_or_null("CellFill") as ColorRect
	assert_not_null(cell_fill)
	assert_true(cell_fill.position.x > 0.0)
	assert_true(cell_fill.position.y > 0.0)
	assert_true(cell_fill.size.x < first_button.size.x)
	assert_true(cell_fill.size.y < first_button.size.y)
	assert_not_null(first_button.get_node_or_null("PhotoCorner"))
	var item_icon := first_button.get_node_or_null("ItemIcon") as TextureRect
	assert_not_null(item_icon)
	assert_not_null(item_icon.texture)
	assert_eq(item_icon.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	assert_not_null(first_button.get_node_or_null("SelectionPin"))
	item_scroll.scroll_vertical = 0
	gallery.call("_scroll_gallery_rows", 1)
	assert_eq(item_scroll.scroll_vertical, int(round(first_button.custom_minimum_size.y)))
	gallery.call("_scroll_gallery_rows", -1)
	assert_eq(item_scroll.scroll_vertical, 0)

	var selected_paper := gallery.get_node_or_null("DesignRoot/UiLayer/SelectedPaper") as Control
	var memory_paper := gallery.get_node_or_null("DesignRoot/UiLayer/MemoryPaper") as TextureRect
	assert_not_null(selected_paper)
	assert_null(selected_paper.get_script(), "Magnifier preview container should not draw a paper background.")
	assert_not_null(memory_paper)
	assert_not_null(memory_paper.texture)
	assert_eq(memory_paper.texture.resource_path, "res://assets/ui/gallery/gallery_memory_paper.png")
	var selected_icon := selected_paper.get_node_or_null("SelectedIcon") as TextureRect
	assert_not_null(selected_icon)
	assert_true(selected_icon.visible)
	assert_eq(selected_icon.texture, item_icon.texture)
	var selected_name := gallery.get_node_or_null("DesignRoot/UiLayer/SelectedName") as Label
	assert_not_null(selected_name)
	assert_eq(selected_name.get_parent(), gallery.get_node("DesignRoot/UiLayer"))
	assert_true(selected_name.text.contains("\n"))
	var selected_meta := selected_paper.get_node_or_null("SelectedMeta") as Label
	if selected_meta != null:
		assert_false(selected_meta.visible)

	var detail_text := gallery.get_node_or_null("DesignRoot/UiLayer/DetailText") as Label
	assert_not_null(detail_text)
	assert_true(detail_text.text.length() > 0)
	var item_db = gallery.get_node_or_null("/root/ItemDatabase")
	assert_not_null(item_db)
	var first_item: ItemData = item_db.items[str(first_button.get_meta("item_id"))]
	assert_string_contains(detail_text.text, str(first_item.price))
	assert_eq(selected_name.text.replace("\n", ""), first_item.item_name.replace(" ", ""))
