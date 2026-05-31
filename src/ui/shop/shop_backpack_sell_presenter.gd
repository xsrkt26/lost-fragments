extends RefCounted

const ItemUIScene = preload("res://src/ui/item/item_ui.tscn")

var backpack_manager: BackpackManager = null

func render(owner: Node, backpack_ui: Control, run_manager: Node, item_db: Node, item_input_callback: Callable) -> void:
	if owner == null or backpack_ui == null or run_manager == null or item_db == null:
		return
	_ensure_manager(owner)
	_setup_manager_from_run(run_manager)
	if run_manager.has_method("restore_backpack_state"):
		run_manager.restore_backpack_state(backpack_manager, item_db)
	_refresh_backpack_ui(backpack_ui)
	_render_item_cards(backpack_ui, item_input_callback)

func _ensure_manager(owner: Node) -> void:
	if backpack_manager != null:
		return
	backpack_manager = BackpackManager.new()
	owner.add_child(backpack_manager)

func _setup_manager_from_run(run_manager: Node) -> void:
	var config = run_manager.get_backpack_grid_config() if run_manager.has_method("get_backpack_grid_config") else {}
	backpack_manager.setup_grid(
		int(config.get("grid_width", 7)),
		int(config.get("grid_height", 7)),
		int(config.get("usable_width", 5)),
		int(config.get("usable_height", 5))
	)
	if backpack_manager.has_method("set_blocked_cells"):
		backpack_manager.set_blocked_cells(_to_vector2i_array(config.get("blocked_cells", [])))

func _refresh_backpack_ui(backpack_ui: Control) -> void:
	if backpack_ui.has_method("clear_item_visuals"):
		backpack_ui.clear_item_visuals()
	backpack_ui.set("manager", backpack_manager)
	if backpack_ui.has_method("_refresh_grid"):
		backpack_ui._refresh_grid()

func _render_item_cards(backpack_ui: Control, item_input_callback: Callable) -> void:
	for instance in backpack_manager.get_all_instances():
		if instance == null or instance.data == null:
			continue
		var card := ItemUIScene.instantiate() as Control
		if card == null:
			continue
		card.setup(instance.data)
		card.set("item_instance", instance)
		var runtime_id := int(instance.data.runtime_id)
		if item_input_callback.is_valid():
			card.gui_input.connect(func(event): item_input_callback.call(event, runtime_id))
		if backpack_ui.has_method("add_item_visual"):
			backpack_ui.add_item_visual(card, instance.root_pos)

func _to_vector2i_array(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for entry in Array(value):
		if entry is Vector2i:
			result.append(entry)
		elif entry is Dictionary:
			result.append(Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))))
	return result
