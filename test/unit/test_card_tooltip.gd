extends GutTest

const ItemUIScene = preload("res://src/ui/item/item_ui.tscn")
const BackpackUIScene = preload("res://src/ui/backpack/backpack_ui.tscn")

func after_each():
	GlobalTooltip.hide()
	await get_tree().process_frame

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
