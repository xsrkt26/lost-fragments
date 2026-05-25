extends GutTest

const GalleryScene = preload("res://src/ui/gallery/gallery_scene.tscn")

func test_gallery_scene_uses_new_background_and_item_grid() -> void:
	var gallery = add_child_autofree(GalleryScene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	var background := gallery.get_node_or_null("Background") as TextureRect
	assert_not_null(background)
	assert_not_null(background.texture)
	assert_eq(background.texture.resource_path, "res://assets/ui/gallery/gallery_background.png")
	assert_eq(background.texture.get_size(), Vector2(1920.0, 1080.0))

	var back_button := gallery.get_node_or_null("UiLayer/BackButton") as Button
	assert_not_null(back_button)
	assert_true(back_button.size.x > 0.0)

	var item_grid := gallery.get_node_or_null("UiLayer/ItemScroll/ItemGrid") as GridContainer
	assert_not_null(item_grid)
	assert_eq(item_grid.columns, 7)
	assert_true(item_grid.get_child_count() > 0)

	var first_button := item_grid.get_child(0) as Button
	assert_not_null(first_button)
	assert_true(first_button.has_meta("item_id"))
	assert_true(first_button.tooltip_text.length() > 0)

	var detail_name := gallery.get_node_or_null("UiLayer/DetailName") as Label
	assert_not_null(detail_name)
	assert_true(detail_name.text.length() > 0)
