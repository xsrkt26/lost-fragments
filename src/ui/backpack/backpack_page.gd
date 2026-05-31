class_name BackpackPage
extends Control

signal close_requested

const DesignScaler = preload("res://src/ui/layout/ui_design_scaler.gd")
const ItemUIScene = preload("res://src/ui/item/item_ui.tscn")
const PendingItemPresenter = preload("res://src/ui/backpack/pending_item_presenter.gd")

const DESIGN_SIZE := BookBackgroundConfig.DESIGN_SIZE

@onready var content_layer: Control = $ContentLayer
@onready var art_layer: Control = $ContentLayer/BackpackArt
@onready var grid_panel: Control = $ContentLayer/GridPanel
@onready var backpack_ui: Control = $ContentLayer/GridPanel/BackpackUI
@onready var close_button: Button = $ContentLayer/CloseButton
@onready var effects_list: VBoxContainer = $ContentLayer/EffectsList
@onready var stats_label: Label = $ContentLayer/StatsLabel
@onready var pending_item_panel: Control = $ContentLayer/PendingItemPanel
@onready var pending_item_area: Control = $ContentLayer/PendingItemPanel/PendingItemArea
@onready var scene_battle_manager: BattleManager = $BattleManager

var battle_manager: BattleManager = null
var _book_page_navigator: Node = null
var _close_callback: Callable = Callable()
var _rendered_item_uis: Array[Control] = []
var run_manager_override = null
var item_database_override = null
var ornament_database_override = null


func configure_for_backpack_overlay(close_callback: Callable = Callable()) -> void:
	_close_callback = close_callback
	if is_node_ready():
		_apply_page_state()


func set_book_page_navigator(navigator: Node) -> void:
	_book_page_navigator = navigator


func _ready() -> void:
	GlobalInput.set_context(GlobalInput.Context.UI)
	if not resized.is_connected(_layout_page):
		resized.connect(_layout_page)
	if close_button != null and not close_button.pressed.is_connected(_request_close):
		close_button.pressed.connect(_request_close)
	_apply_page_state()
	call_deferred("_ensure_battle_manager_setup")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not GlobalInput.can_cancel():
		return
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		_request_close()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_persist_backpack()


func _apply_page_state() -> void:
	_configure_book_background()
	_layout_page()
	if close_button != null:
		close_button.show()
	if effects_list != null:
		effects_list.show()
	if stats_label != null:
		stats_label.show()


func _ensure_battle_manager_setup() -> void:
	if battle_manager == null:
		setup(scene_battle_manager)


func setup(p_battle_manager: BattleManager) -> void:
	if p_battle_manager == null:
		return
	battle_manager = p_battle_manager
	battle_manager.backpack_ui = backpack_ui
	_connect_backpack_ui_signals()
	_render_existing_backpack_items()
	_render_pending_items()
	_refresh_info()


func _connect_backpack_ui_signals() -> void:
	if backpack_ui == null or battle_manager == null:
		return
	if not backpack_ui.has_signal("item_dropped_on_grid"):
		return
	var place_callback := Callable(battle_manager, "request_place_item")
	if not backpack_ui.is_connected("item_dropped_on_grid", place_callback):
		backpack_ui.connect("item_dropped_on_grid", place_callback)


func _configure_book_background() -> void:
	if art_layer != null and art_layer.has_method("set_active_page_id"):
		art_layer.call("set_active_page_id", BookBackgroundConfig.PAGE_BACKPACK)


func _layout_page() -> void:
	if content_layer == null:
		return
	DesignScaler.layout_root(content_layer, get_viewport_rect().size, DESIGN_SIZE, DesignScaler.SCALE_MODE_COVER)
	if art_layer != null:
		art_layer.position = Vector2.ZERO
		art_layer.size = DESIGN_SIZE
		art_layer.scale = Vector2.ONE


func _render_existing_backpack_items() -> void:
	_clear_rendered_item_uis()
	if battle_manager == null or backpack_ui == null:
		return
	battle_manager.managed_item_uis.clear()
	if backpack_ui.get("item_ui_map") is Dictionary:
		backpack_ui.set("item_ui_map", {})
	for instance in battle_manager.backpack_manager.get_all_instances():
		var card := ItemUIScene.instantiate() as Control
		if card == null:
			continue
		add_child(card)
		card.setup(instance.data, battle_manager.context)
		card.set("item_instance", instance)
		battle_manager.managed_item_uis.append(card)
		_rendered_item_uis.append(card)
		_connect_item_ui_signals(card)
		if backpack_ui.has_method("add_item_visual"):
			backpack_ui.add_item_visual(card, instance.root_pos)


func _clear_rendered_item_uis() -> void:
	for item_ui in _rendered_item_uis:
		if is_instance_valid(item_ui):
			item_ui.queue_free()
	_rendered_item_uis.clear()


func _render_pending_items() -> void:
	if pending_item_panel == null or pending_item_area == null:
		return
	var rm = _get_run_manager()
	var item_db = _get_item_database()
	if rm == null or item_db == null or not rm.has_method("get_pending_item_rewards"):
		PendingItemPresenter.clear(pending_item_panel, pending_item_area)
		return
	var pending_items = rm.get_pending_item_rewards()
	var card_context = battle_manager.context if battle_manager != null else null
	PendingItemPresenter.render(pending_item_panel, pending_item_area, pending_items, item_db, card_context, Callable(self, "_connect_item_ui_signals"))


func _connect_item_ui_signals(card: Control) -> void:
	if not card.has_signal("dropped") or not card.has_signal("drag_moved") or not card.has_signal("rotation_requested"):
		return
	card.dropped.connect(func(mouse_pos, pivot): _handle_item_dropped(card, mouse_pos, pivot))
	card.drag_moved.connect(func(item_ui, mouse_pos, pivot): _handle_item_dragged(item_ui, mouse_pos, pivot))
	card.rotation_requested.connect(_handle_item_rotation_requested)


func _handle_item_dragged(item_ui: Control, mouse_pos: Vector2, pivot_offset: Vector2i) -> void:
	if backpack_ui == null or not backpack_ui.has_method("get_grid_pos_at") or not backpack_ui.has_method("highlight_placement"):
		return
	var mouse_grid_pos: Vector2i = backpack_ui.get_grid_pos_at(mouse_pos)
	var root_grid_pos := mouse_grid_pos - pivot_offset if mouse_grid_pos != Vector2i(-1, -1) else Vector2i(-1, -1)
	backpack_ui.highlight_placement(root_grid_pos, item_ui.get("item_data"))


func _handle_item_dropped(item_ui: Control, mouse_pos: Vector2, pivot_offset: Vector2i) -> void:
	if backpack_ui != null and backpack_ui.has_method("update_slot_visuals"):
		backpack_ui.update_slot_visuals()
	if battle_manager == null or backpack_ui == null or not backpack_ui.has_method("get_grid_pos_at"):
		return
	var mouse_grid_pos: Vector2i = backpack_ui.get_grid_pos_at(mouse_pos)
	var root_grid_pos := mouse_grid_pos - pivot_offset if mouse_grid_pos != Vector2i(-1, -1) else Vector2i(-1, -1)
	battle_manager.request_place_item(item_ui, root_grid_pos)
	_consume_pending_item_if_placed(item_ui)
	_persist_backpack()


func _handle_item_rotation_requested(item_ui: Control, mouse_global_pos: Vector2, pivot_offset: Vector2i) -> void:
	if battle_manager != null and battle_manager.has_method("request_rotate_item"):
		battle_manager.request_rotate_item(item_ui, mouse_global_pos, pivot_offset)
		_persist_backpack()


func _consume_pending_item_if_placed(item_ui: Control) -> void:
	if not item_ui.has_meta("pending_item_uid"):
		return
	if item_ui.get("item_instance") == null:
		return
	var rm = _get_run_manager()
	if rm != null and rm.has_method("consume_pending_item"):
		rm.consume_pending_item(int(item_ui.get_meta("pending_item_uid")))
	item_ui.remove_meta("pending_item_uid")
	if battle_manager != null and not battle_manager.managed_item_uis.has(item_ui):
		battle_manager.managed_item_uis.append(item_ui)
	_render_pending_items()


func _refresh_info() -> void:
	_refresh_effect_labels()
	_refresh_stats_label()


func _refresh_effect_labels() -> void:
	if effects_list == null:
		return
	var entries := _get_ornament_entries()
	var labels := effects_list.get_children()
	for i in range(labels.size()):
		var label := labels[i] as Label
		if label == null:
			continue
		if i < entries.size():
			label.text = "- " + entries[i]
			label.show()
		else:
			label.text = ""
			label.hide()


func _get_ornament_entries() -> Array[String]:
	var entries: Array[String] = []
	var rm = _get_run_manager()
	var ornament_db = _get_ornament_database()
	if rm != null and ornament_db != null:
		for ornament_id in rm.current_ornaments:
			var ornament = ornament_db.get_ornament_by_id(ornament_id)
			if ornament != null:
				entries.append(ornament.ornament_name)
	if entries.is_empty():
		entries.append("No active effects")
	var visible_entries: Array[String] = []
	for i in range(mini(entries.size(), 8)):
		visible_entries.append(entries[i])
	return visible_entries


func _refresh_stats_label() -> void:
	if stats_label == null:
		return
	var rm = _get_run_manager()
	var act := 1
	var node_index := 1
	if rm != null:
		act = int(rm.get("current_act"))
		node_index = int(rm.get("current_route_index")) + 1
	stats_label.text = "Run summary\nAct %d / Node %d\nBackpack changes save when closed." % [act, node_index]


func _request_close() -> void:
	_persist_backpack()
	close_requested.emit()
	if _close_callback.is_valid():
		_close_callback.call()
	elif _book_page_navigator != null and is_instance_valid(_book_page_navigator) and _book_page_navigator.has_method("return_to_main_menu"):
		_book_page_navigator.return_to_main_menu()
	else:
		GlobalScene.transition_to(GlobalScene.SceneType.MAIN_MENU, false)


func _persist_backpack() -> void:
	if battle_manager != null and battle_manager.has_method("persist_backpack_to_run"):
		battle_manager.persist_backpack_to_run()

func _get_run_manager():
	if run_manager_override != null:
		return run_manager_override
	return get_node_or_null("/root/RunManager")

func _get_item_database():
	if item_database_override != null:
		return item_database_override
	return get_node_or_null("/root/ItemDatabase")

func _get_ornament_database():
	if ornament_database_override != null:
		return ornament_database_override
	return get_node_or_null("/root/OrnamentDatabase")
