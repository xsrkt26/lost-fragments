extends GutTest

const ItemUIScene = preload("res://src/ui/item/item_ui.tscn")
const BackpackUIScene = preload("res://src/ui/backpack/backpack_ui.tscn")

func after_each():
	GlobalTooltip.hide()
	await get_tree().process_frame

func _get_locked_cell_pin(grid: GridContainer, pos: Vector2i) -> TextureRect:
	var slot := grid.get_node_or_null("Slot_%d_%d" % [pos.x, pos.y]) as Control
	assert_not_null(slot)
	if slot == null:
		return null
	var pin := slot.get_node_or_null("LockedCellPin") as TextureRect
	assert_not_null(pin)
	return pin

func test_item_ui_updates_pollution_badge_when_instance_changes():
	var item = _make_item_data()
	var ui = add_child_autofree(ItemUIScene.instantiate())
	await get_tree().process_frame

	ui.setup(item)
	var instance = BackpackManager.ItemInstance.new(item, Vector2i(0, 0))
	ui.item_instance = instance

	assert_false(ui.pollution_label.visible)

	instance.current_pollution = 4

	assert_true(ui.pollution_label.visible)
	assert_eq(ui.pollution_label.text, "4")

	instance.current_pollution = 0

	assert_false(ui.pollution_label.visible)

func test_item_ui_uses_configured_grid_cell_size_for_shape_size():
	var item = _make_item_data()
	item.shape = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)] as Array[Vector2i]
	var ui = add_child_autofree(ItemUIScene.instantiate())
	await get_tree().process_frame

	ui.setup(item)
	ui.set_cell_size(Vector2(80.0, 72.0))

	assert_eq(ui.cell_size, Vector2(80.0, 72.0))
	assert_eq(ui.custom_minimum_size, Vector2(160.0, 144.0))
	assert_eq(ui.size, Vector2(160.0, 144.0))


func test_item_ui_direction_marker_uses_solid_thick_line_without_label_marker():
	var item = _make_item_data()
	var ui = add_child_autofree(ItemUIScene.instantiate())
	await get_tree().process_frame

	ui.setup(item)
	ui.set_cell_size(Vector2(100.0, 70.0))

	var line_width: float = ui.call("_get_direction_line_width")
	assert_false(ui.direction_icon.visible)
	assert_true(line_width >= 2.75)
	assert_true(line_width <= 4.25)

	ui.set("_is_hovered", true)
	var active_line_width: float = ui.call("_get_direction_line_width")
	assert_true(active_line_width > line_width)
	assert_true(active_line_width <= 4.25)


func test_item_ui_direction_marker_stays_on_top_right_cell_when_direction_changes():
	var item = _make_item_data()
	item.shape = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i]
	var ui = add_child_autofree(ItemUIScene.instantiate())
	await get_tree().process_frame

	ui.setup(item)
	ui.set_cell_size(Vector2(100.0, 70.0))

	var center_before: Vector2 = ui.call("_get_direction_marker_center")
	item.direction = ItemData.Direction.DOWN
	ui.call("_sync_visuals")
	var center_after: Vector2 = ui.call("_get_direction_marker_center")

	assert_eq(center_after, center_before)
	assert_true(absf(center_after.x - 180.0) < 0.01)
	assert_true(absf(center_after.y - 19.6) < 0.01)


func test_item_ui_direction_line_flashes_when_direction_changes():
	var item = _make_item_data()
	var ui = add_child_autofree(ItemUIScene.instantiate())
	await get_tree().process_frame

	ui.setup(item)
	assert_eq(ui.get("_direction_flash"), 0.0)

	item.direction = ItemData.Direction.DOWN
	ui.call("_sync_visuals")

	var flash: float = ui.get("_direction_flash")
	assert_true(flash > 0.0)


func test_item_ui_processes_only_while_dragging():
	var item = _make_item_data()
	var ui = add_child_autofree(ItemUIScene.instantiate())
	await get_tree().process_frame
	ui.setup(item)

	assert_false(ui.is_processing())

	ui._start_drag()

	assert_true(ui.is_processing())

	ui._stop_drag()

	assert_false(ui.is_processing())

	ui._start_drag()
	ui._request_rotation()

	assert_false(ui.is_processing())


func test_item_ui_shows_configured_icon_texture():
	var item = _make_item_data()
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	item.icon = ImageTexture.create_from_image(image)
	var ui = add_child_autofree(ItemUIScene.instantiate())
	await get_tree().process_frame

	ui.setup(item)

	assert_eq(ui.icon.texture, item.icon)
	assert_true(ui.icon.visible)


func test_item_ui_uses_item_art_without_background_fill():
	var item = _make_item_data()
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	item.icon = ImageTexture.create_from_image(image)
	var ui = add_child_autofree(ItemUIScene.instantiate())
	await get_tree().process_frame

	ui.setup(item)

	assert_false(ui.background.visible)


func test_item_ui_keeps_placeholder_background_without_icon():
	var item = _make_item_data()
	var ui = add_child_autofree(ItemUIScene.instantiate())
	await get_tree().process_frame

	ui.setup(item)

	assert_true(ui.background.visible)


func test_backpack_configures_item_ui_with_grid_cell_size():
	var backpack = add_child_autofree(BackpackUIScene.instantiate())
	backpack.custom_minimum_size = Vector2(700.0, 490.0)
	backpack.size = Vector2(700.0, 490.0)
	await get_tree().process_frame

	var item = _make_item_data()
	var ui = add_child_autofree(ItemUIScene.instantiate())
	await get_tree().process_frame
	ui.setup(item)

	backpack.configure_item_for_grid(ui, backpack)

	assert_eq(backpack.get_grid_cell_size(), Vector2(100.0, 70.0))
	assert_eq(ui.cell_size, Vector2(100.0, 70.0))
	assert_eq(ui.custom_minimum_size, Vector2(100.0, 70.0))

func test_backpack_grid_slots_are_serialized_in_scene():
	var backpack = autofree(BackpackUIScene.instantiate())
	var grid := backpack.get_node_or_null("GridContainer") as GridContainer
	assert_not_null(grid)
	assert_eq(grid.get_child_count(), 49)
	assert_not_null(grid.get_node_or_null("Slot_0_0"))
	assert_not_null(grid.get_node_or_null("Slot_6_6"))
	for child in grid.get_children():
		assert_true(child is ColorRect)
		var pin := (child as Control).get_node_or_null("LockedCellPin") as TextureRect
		assert_not_null(pin)
		assert_false(pin.visible)
		assert_not_null(pin.texture)
		assert_eq(pin.texture.resource_path, "res://assets/ui/backpack/locked_cell_pin.png")


func test_backpack_locked_cell_pins_track_unusable_and_blocked_slots():
	var backpack = add_child_autofree(BackpackUIScene.instantiate())
	await get_tree().process_frame
	var grid := backpack.get_node_or_null("GridContainer") as GridContainer
	assert_not_null(grid)

	var manager = autofree(BackpackManager.new())
	manager.setup_grid(7, 7, 5, 5)
	var blocked_cells: Array[Vector2i] = [Vector2i(3, 3)]
	manager.set_blocked_cells(blocked_cells)
	backpack.manager = manager
	backpack._refresh_grid()

	assert_true(_get_locked_cell_pin(grid, Vector2i(0, 0)).visible)
	assert_false(_get_locked_cell_pin(grid, Vector2i(1, 1)).visible)
	assert_true(_get_locked_cell_pin(grid, Vector2i(3, 3)).visible)


func test_backpack_refresh_uses_existing_static_grid_slots():
	var backpack = add_child_autofree(BackpackUIScene.instantiate())
	await get_tree().process_frame
	var grid := backpack.get_node_or_null("GridContainer") as GridContainer
	assert_not_null(grid)
	var slot_count := grid.get_child_count()

	backpack.call("_refresh_grid")

	assert_eq(grid.get_child_count(), slot_count)
	assert_eq(slot_count, 49)


func test_backpack_highlight_restores_only_previous_highlighted_slots():
	var backpack = add_child_autofree(BackpackUIScene.instantiate())
	await get_tree().process_frame
	var grid := backpack.get_node_or_null("GridContainer") as GridContainer
	assert_not_null(grid)

	var manager = autofree(BackpackManager.new())
	manager.setup_grid(7, 7, 7, 7)
	backpack.manager = manager
	backpack._refresh_grid()

	var unrelated_slot := grid.get_node("Slot_6_6") as ColorRect
	var first_slot := grid.get_node("Slot_1_1") as ColorRect
	var second_slot := grid.get_node("Slot_2_2") as ColorRect
	unrelated_slot.color = Color.MAGENTA

	var item = _make_item_data()
	backpack.highlight_placement(Vector2i(1, 1), item)
	backpack.highlight_placement(Vector2i(2, 2), item)

	assert_eq(first_slot.color, Color(1, 1, 1, 0))
	assert_eq(second_slot.color, Color(0.2, 0.8, 0.2, 0.4))
	assert_eq(unrelated_slot.color, Color.MAGENTA)


func test_backpack_add_item_visual_positions_immediately_from_grid_coordinates():
	var backpack = add_child_autofree(BackpackUIScene.instantiate())
	backpack.custom_minimum_size = Vector2(700.0, 490.0)
	backpack.size = Vector2(700.0, 490.0)
	await get_tree().process_frame

	var manager = autofree(BackpackManager.new())
	manager.setup_grid(7, 7, 7, 7)
	backpack.manager = manager
	backpack._refresh_grid()

	var item = _make_item_data()
	item.runtime_id = 42
	var ui = add_child_autofree(ItemUIScene.instantiate())
	await get_tree().process_frame
	ui.setup(item)

	backpack.add_item_visual(ui, Vector2i(2, 3))

	assert_eq(ui.get_parent(), backpack)
	assert_eq(backpack.get_grid_cell_size(), Vector2(100.0, 70.0))
	assert_eq(ui.position, Vector2(200.0, 210.0))

func test_backpack_add_item_visual_does_not_depend_on_slot_layout_position():
	var backpack = add_child_autofree(BackpackUIScene.instantiate())
	backpack.custom_minimum_size = Vector2(700.0, 490.0)
	backpack.size = Vector2(700.0, 490.0)
	await get_tree().process_frame

	var manager = autofree(BackpackManager.new())
	manager.setup_grid(7, 7, 7, 7)
	backpack.manager = manager
	backpack._refresh_grid()
	var grid = backpack.get_node("GridContainer") as GridContainer
	for slot in grid.get_children():
		if slot is Control:
			slot.position = Vector2.ZERO

	var item = _make_item_data()
	item.runtime_id = 43
	var ui = add_child_autofree(ItemUIScene.instantiate())
	await get_tree().process_frame
	ui.setup(item)

	backpack.add_item_visual(ui, Vector2i(3, 3))

	assert_eq(ui.position, Vector2(300.0, 210.0))
	assert_eq(backpack.get_slot_center_position(Vector2i(3, 3)), Vector2(350.0, 245.0))

func test_global_tooltip_shows_dynamic_pollution_status():
	var item = _make_item_data()
	var instance = BackpackManager.ItemInstance.new(item, Vector2i(0, 0))
	instance.current_pollution = 5

	GlobalTooltip.show_item(item, instance)
	await get_tree().create_timer(0.25).timeout

	var tooltip = GlobalTooltip._tooltip_instance
	assert_not_null(tooltip)
	assert_true(tooltip.is_panel_visible())

	var status_label = tooltip.get_node("PanelContainer/MarginContainer/VBoxContainer/StatusLabel")
	assert_true(status_label.visible)
	assert_true(status_label.text.contains("5"))

func test_global_tooltip_ignores_null_item_data():
	var item = _make_item_data()
	GlobalTooltip.show_item(item)
	await get_tree().create_timer(0.25).timeout

	GlobalTooltip.show_item(null)
	await get_tree().create_timer(0.15).timeout

	var tooltip = GlobalTooltip._tooltip_instance
	assert_not_null(tooltip)
	assert_false(tooltip.is_panel_visible())

func _make_item_data() -> ItemData:
	var item = ItemData.new()
	item.id = "tooltip_test_item"
	item.item_name = "Tooltip Test"
	item.description = "On hit: +2 score"
	var shape: Array[Vector2i] = [Vector2i(0, 0)]
	item.shape = shape
	return item
