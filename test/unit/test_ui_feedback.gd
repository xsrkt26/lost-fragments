extends GutTest


func after_each():
	GlobalFeedback.clear_floating_text_pool()
	await get_tree().process_frame


func test_bind_button_marks_button_and_is_idempotent():
	var button = autofree(Button.new())

	GlobalFeedback.bind_button(button)
	var pressed_connections = button.get_signal_connection_list("pressed").size()
	GlobalFeedback.bind_button(button)

	assert_true(button.has_meta(GlobalFeedback.BUTTON_FEEDBACK_META))
	assert_eq(button.get_signal_connection_list("pressed").size(), pressed_connections)
	assert_eq(button.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)


func test_bind_buttons_recursively_binds_dynamic_buttons():
	var root = autofree(Control.new())
	var nested = Control.new()
	var direct_button = Button.new()
	var nested_button = Button.new()
	root.add_child(direct_button)
	root.add_child(nested)
	nested.add_child(nested_button)

	GlobalFeedback.bind_buttons(root)

	assert_true(direct_button.has_meta(GlobalFeedback.BUTTON_FEEDBACK_META))
	assert_true(nested_button.has_meta(GlobalFeedback.BUTTON_FEEDBACK_META))


func test_button_hover_feedback_restores_scale():
	var button = add_child_autofree(Button.new())
	button.size = Vector2(120, 40)
	GlobalFeedback.bind_button(button)

	button.mouse_entered.emit()
	await get_tree().create_timer(0.12).timeout
	assert_true(button.scale.x > 1.0)
	assert_true(button.scale.y > 1.0)

	button.mouse_exited.emit()
	await get_tree().create_timer(0.12).timeout
	assert_almost_eq(button.scale.x, 1.0, 0.01)
	assert_almost_eq(button.scale.y, 1.0, 0.01)


func test_floating_text_reuses_pooled_label():
	GlobalFeedback.clear_floating_text_pool()

	GlobalFeedback.show_text("+3", Vector2(100.0, 100.0), GlobalFeedback.TextType.SCORE)
	await get_tree().create_timer(0.9).timeout

	assert_eq(GlobalFeedback._floating_text_pool.size(), 1)
	var pooled_label: Label = GlobalFeedback._floating_text_pool[0]
	assert_false(pooled_label.visible)

	GlobalFeedback.show_text("-1", Vector2(120.0, 100.0), GlobalFeedback.TextType.SANITY)
	await get_tree().process_frame

	assert_eq(GlobalFeedback._floating_text_pool.size(), 0)
	assert_true(pooled_label.visible)

	await get_tree().create_timer(0.9).timeout

	assert_eq(GlobalFeedback._floating_text_pool.size(), 1)
	assert_eq(GlobalFeedback._floating_text_pool[0], pooled_label)
