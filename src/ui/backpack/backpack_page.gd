class_name BackpackPage
extends Control

signal close_requested

const DesignScaler = preload("res://src/ui/layout/ui_design_scaler.gd")
const ItemUIScene = preload("res://src/ui/item/item_ui.tscn")
const PendingItemPresenter = preload("res://src/ui/backpack/pending_item_presenter.gd")
const OrnamentSlotBar = preload("res://src/ui/ornament/ornament_slot_bar.gd")

const DESIGN_SIZE := BookBackgroundConfig.DESIGN_SIZE
const EFFECT_ENTRY_FONT_SIZE := 20
const STATS_FONT_SIZE := 24
const EMPTY_ORNAMENT_TEXT := "暂无饰品效果"
const EMPTY_RUN_TEXT := "没有正在进行的梦境"
const DEFAULT_BACKPACK_USABLE_WIDTH := 5
const DEFAULT_BACKPACK_USABLE_HEIGHT := 5

@onready var content_layer: Control = $ContentLayer
@onready var art_layer: Control = $ContentLayer/BackpackArt
@onready var grid_panel: Control = $ContentLayer/GridPanel
@onready var backpack_ui: Control = $ContentLayer/GridPanel/BackpackUI
@onready var close_button: Button = $ContentLayer/CloseButton
@onready var ornament_slots: Control = $ContentLayer/OrnamentSlots
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
var _last_drag_root_grid_pos := Vector2i(-999999, -999999)
var _last_drag_item_id := 0


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


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED or not visible or not is_node_ready():
		return
	_refresh_backpack_page_from_run()


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
	_refresh_info()


func _ensure_battle_manager_setup() -> void:
	if battle_manager == null:
		setup(scene_battle_manager)


func setup(p_battle_manager: BattleManager) -> void:
	if p_battle_manager == null:
		return
	battle_manager = p_battle_manager
	battle_manager.backpack_ui = backpack_ui
	_connect_run_manager_signals()
	_connect_backpack_ui_signals()
	_refresh_backpack_page_from_run()


func _connect_run_manager_signals() -> void:
	var rm = _get_run_manager()
	if rm == null:
		return
	_connect_run_signal(rm, "shards_changed", Callable(self, "_on_run_summary_changed"))
	_connect_run_signal(rm, "deck_changed", Callable(self, "_on_run_summary_changed"))
	_connect_run_signal(rm, "ornaments_changed", Callable(self, "_on_run_summary_changed"))
	_connect_run_signal(rm, "pending_items_changed", Callable(self, "_on_run_summary_changed"))
	_connect_run_signal(rm, "tools_changed", Callable(self, "_on_run_summary_changed"))
	_connect_run_signal(rm, "route_changed", Callable(self, "_on_route_changed"))


func _connect_run_signal(rm: Node, signal_name: StringName, callback: Callable) -> void:
	if rm.has_signal(signal_name) and not rm.is_connected(signal_name, callback):
		rm.connect(signal_name, callback)


func _on_run_summary_changed(_a = null, _b = null, _c = null) -> void:
	_render_pending_items()
	_refresh_info()


func _on_route_changed(_current_act: int, _route_index: int, _current_node: Dictionary) -> void:
	_refresh_info()


func _refresh_backpack_page_from_run() -> void:
	_restore_backpack_from_run()
	_render_existing_backpack_items()
	_render_pending_items()
	_refresh_info()


func _restore_backpack_from_run() -> void:
	if battle_manager == null or battle_manager.backpack_manager == null:
		return
	var rm = _get_run_manager()
	var item_db = _get_item_database()
	if rm == null or item_db == null or not rm.has_method("restore_backpack_state"):
		return
	if rm.has_method("get_backpack_grid_config"):
		var config = rm.get_backpack_grid_config()
		if config is Dictionary:
			var grid_width := int(config.get("grid_width", battle_manager.backpack_manager.grid_width))
			var grid_height := int(config.get("grid_height", battle_manager.backpack_manager.grid_height))
			if grid_width == battle_manager.backpack_manager.grid_width and grid_height == battle_manager.backpack_manager.grid_height:
				battle_manager.backpack_manager.setup_grid(
					grid_width,
					grid_height,
					int(config.get("usable_width", grid_width)),
					int(config.get("usable_height", grid_height))
				)
			if battle_manager.backpack_manager.has_method("set_blocked_cells"):
				battle_manager.backpack_manager.set_blocked_cells(_to_vector2i_array(Array(config.get("blocked_cells", []))))
	rm.restore_backpack_state(battle_manager.backpack_manager, item_db)


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
	if backpack_ui.has_method("clear_item_visuals"):
		backpack_ui.clear_item_visuals()
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
	_replace_owned_item_signal_connection(card, "dropped", Callable(self, "_handle_item_dropped"))
	_replace_owned_item_signal_connection(card, "drag_moved", Callable(self, "_handle_item_dragged"))
	_replace_owned_item_signal_connection(card, "rotation_requested", Callable(self, "_handle_item_rotation_requested"))


func _replace_owned_item_signal_connection(card: Control, signal_name: StringName, expected_callback: Callable) -> void:
	var has_expected := false
	for connection in card.get_signal_connection_list(signal_name):
		var connected_callback: Callable = connection.get("callable", Callable())
		if connected_callback == expected_callback:
			has_expected = true
		elif connected_callback.is_valid() and connected_callback.get_object() == self:
			card.disconnect(signal_name, connected_callback)
	if not has_expected:
		card.connect(signal_name, expected_callback)


func _reset_drag_highlight_tracking() -> void:
	_last_drag_root_grid_pos = Vector2i(-999999, -999999)
	_last_drag_item_id = 0


func _get_drag_item_id(item_ui: Control) -> int:
	return int(item_ui.get_instance_id()) if item_ui != null else 0


func _clear_backpack_placement_highlight() -> void:
	if backpack_ui == null:
		return
	if backpack_ui.has_method("clear_placement_highlight"):
		backpack_ui.clear_placement_highlight()
	elif backpack_ui.has_method("update_slot_visuals"):
		backpack_ui.update_slot_visuals()


func _handle_item_dragged(item_ui: Control, mouse_pos: Vector2, pivot_offset: Vector2i) -> void:
	if backpack_ui == null or not backpack_ui.has_method("get_grid_pos_at") or not backpack_ui.has_method("highlight_placement"):
		return
	var drag_item_id := _get_drag_item_id(item_ui)
	var mouse_grid_pos: Vector2i = backpack_ui.get_grid_pos_at(mouse_pos)
	var root_grid_pos := mouse_grid_pos - pivot_offset if mouse_grid_pos != Vector2i(-1, -1) else Vector2i(-1, -1)
	if _last_drag_item_id == drag_item_id and _last_drag_root_grid_pos == root_grid_pos:
		return
	_last_drag_item_id = drag_item_id
	_last_drag_root_grid_pos = root_grid_pos
	var item_data = item_ui.get("item_data") if item_ui != null else null
	backpack_ui.highlight_placement(root_grid_pos, item_data)


func _handle_item_dropped(item_ui: Control, mouse_pos: Vector2, pivot_offset: Vector2i) -> void:
	_reset_drag_highlight_tracking()
	if backpack_ui != null and backpack_ui.has_method("update_slot_visuals"):
		backpack_ui.update_slot_visuals()
	if battle_manager == null or backpack_ui == null or not backpack_ui.has_method("get_grid_pos_at"):
		return
	var mouse_grid_pos: Vector2i = backpack_ui.get_grid_pos_at(mouse_pos)
	var root_grid_pos := mouse_grid_pos - pivot_offset if mouse_grid_pos != Vector2i(-1, -1) else Vector2i(-1, -1)
	battle_manager.request_place_item(item_ui, root_grid_pos)
	_consume_pending_item_if_placed(item_ui)
	_persist_backpack()
	_refresh_info()


func _handle_item_rotation_requested(item_ui: Control, mouse_global_pos: Vector2, pivot_offset: Vector2i) -> void:
	_clear_backpack_placement_highlight()
	_reset_drag_highlight_tracking()
	if battle_manager != null and battle_manager.has_method("request_rotate_item"):
		battle_manager.request_rotate_item(item_ui, mouse_global_pos, pivot_offset)
		_persist_backpack()
		_refresh_info()


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
	_refresh_info()


func _refresh_info() -> void:
	_render_ornament_slots()
	_refresh_effect_labels()
	_refresh_stats_label()


func _render_ornament_slots() -> void:
	if ornament_slots == null:
		return
	var rm = _get_run_manager()
	var ornament_db = _get_ornament_database()
	if rm == null or ornament_db == null:
		OrnamentSlotBar.clear(ornament_slots)
		return
	OrnamentSlotBar.render_to_container(ornament_slots, Array(rm.current_ornaments), ornament_db)


func _refresh_effect_labels() -> void:
	if effects_list == null:
		return
	_clear_effect_labels()
	var entries := _get_ornament_entries()
	for entry in entries:
		effects_list.add_child(_make_effect_label(entry, EFFECT_ENTRY_FONT_SIZE))


func _clear_effect_labels() -> void:
	for child in effects_list.get_children():
		effects_list.remove_child(child)
		child.queue_free()


func _make_effect_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color(0.05, 0.03, 0.015, 1))
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _get_ornament_entries() -> Array[String]:
	var entries: Array[String] = []
	var rm = _get_run_manager()
	var ornament_db = _get_ornament_database()
	if rm != null and ornament_db != null:
		for ornament_id in Array(rm.current_ornaments):
			var ornament = ornament_db.get_ornament_by_id(ornament_id)
			if ornament != null:
				entries.append(_format_ornament_effect_entry(ornament))
	if entries.is_empty():
		entries.append(EMPTY_ORNAMENT_TEXT)
	return entries


func _format_ornament_effect_entry(ornament) -> String:
	var name := str(ornament.ornament_name)
	var rarity := str(ornament.rarity)
	var effect_text := str(ornament.effect_text)
	if effect_text == "":
		effect_text = "效果待记录"
	return "- %s / %s：%s" % [name, rarity, effect_text]


func _refresh_stats_label() -> void:
	if stats_label == null:
		return
	stats_label.add_theme_font_size_override("font_size", STATS_FONT_SIZE)
	var rm = _get_run_manager()
	if rm == null or not bool(rm.get("is_run_active")):
		stats_label.text = EMPTY_RUN_TEXT
		return
	stats_label.text = "\n".join(_build_run_summary_lines(rm))


func _build_run_summary_lines(rm: Node) -> Array[String]:
	var act: int = max(1, int(rm.get("current_act")))
	var route_index: int = max(0, int(rm.get("current_route_index")))
	var route_size := _get_route_size(rm)
	var current_node := _get_current_route_node(rm)
	var node_label := _format_current_node_label(current_node, route_index, route_size)
	var grid_config := _get_backpack_grid_config(rm)
	var target_text := _get_target_score_text(rm)
	var lines: Array[String] = [
		"当局记录",
		"关卡：第%d幕  %s" % [act, _get_stage_name(rm, act)],
		"进度：%d/%d  %s" % [route_index + 1, max(1, route_size), node_label],
		"碎片：%d" % int(rm.get("current_shards")),
		"牌库：%d 件" % Array(rm.get("current_deck")).size(),
		"背包：%d 件 / %d 格占用" % [_get_backpack_item_count(rm), _get_occupied_backpack_cell_count(rm)],
		"容量：%dx%d 可用" % [int(grid_config.get("usable_width", 5)), int(grid_config.get("usable_height", 5))],
		"饰品：%d/%d" % [Array(rm.get("current_ornaments")).size(), OrnamentSlotBar.SLOT_COUNT],
		"暂存：%d 件" % _get_pending_item_count(rm),
		"目标分：%s" % target_text,
	]
	var tool_count := _get_total_tool_count(rm)
	if tool_count > 0:
		lines.append("道具：%d 件" % tool_count)
	return lines


func _get_stage_name(rm: Node, act: int) -> String:
	if rm.has_method("get_current_stage_config"):
		var stage = rm.get_current_stage_config()
		if stage is Dictionary:
			var name := str(stage.get("name", ""))
			if name != "":
				return name
	return "Act %d" % act


func _get_route_size(rm: Node) -> int:
	if rm.has_method("get_route_nodes"):
		return Array(rm.get_route_nodes()).size()
	return 1


func _get_current_route_node(rm: Node) -> Dictionary:
	if rm.has_method("get_current_route_node"):
		var node = rm.get_current_route_node()
		if node is Dictionary:
			return Dictionary(node)
	return {}


func _format_current_node_label(node: Dictionary, route_index: int, _route_size: int) -> String:
	var label := str(node.get("label", ""))
	var node_type := str(node.get("type", ""))
	var type_label := _format_route_node_type(node_type)
	if label == "":
		label = "节点 %d" % (route_index + 1)
	if type_label == "":
		return label
	return "%s（%s）" % [label, type_label]


func _format_route_node_type(node_type: String) -> String:
	match node_type:
		RouteConfig.NODE_BATTLE:
			return "普通战斗"
		RouteConfig.NODE_ELITE_BATTLE:
			return "精英战斗"
		RouteConfig.NODE_BOSS_BATTLE:
			return "Boss战"
		RouteConfig.NODE_SHOP:
			return "商店"
		RouteConfig.NODE_EVENT:
			return "事件"
		RouteConfig.NODE_REWARD:
			return "奖励"
		RouteConfig.NODE_CUTSCENE:
			return "剧情"
	return ""


func _get_backpack_grid_config(rm: Node) -> Dictionary:
	if rm.has_method("get_backpack_grid_config"):
		var config = rm.get_backpack_grid_config()
		if config is Dictionary:
			return Dictionary(config)
	return {
		"usable_width": DEFAULT_BACKPACK_USABLE_WIDTH,
		"usable_height": DEFAULT_BACKPACK_USABLE_HEIGHT,
	}


func _get_backpack_item_count(rm: Node) -> int:
	return Array(rm.get("current_backpack_items")).size()


func _get_occupied_backpack_cell_count(rm: Node) -> int:
	var occupied := {}
	for entry in Array(rm.get("current_backpack_items")):
		if not (entry is Dictionary):
			continue
		var dict := entry as Dictionary
		var root := Vector2i(int(dict.get("x", 0)), int(dict.get("y", 0)))
		for offset in _entry_shape(dict):
			var cell := root + offset
			occupied["%d:%d" % [cell.x, cell.y]] = true
	return occupied.size()


func _entry_shape(entry: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for raw_cell in Array(entry.get("shape", [])):
		if raw_cell is Vector2i:
			result.append(raw_cell)
		elif raw_cell is Dictionary:
			result.append(Vector2i(int(raw_cell.get("x", 0)), int(raw_cell.get("y", 0))))
	if result.is_empty():
		result.append(Vector2i.ZERO)
	return result


func _to_vector2i_array(value: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for entry in value:
		if entry is Vector2i:
			result.append(entry)
		elif entry is Dictionary:
			result.append(Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))))
	return result


func _get_pending_item_count(rm: Node) -> int:
	if rm.has_method("get_pending_item_rewards"):
		return Array(rm.get_pending_item_rewards()).size()
	return 0


func _get_total_tool_count(rm: Node) -> int:
	var total := 0
	var tools = rm.get("current_tools")
	if tools is Dictionary:
		for value in tools.values():
			total += max(0, int(value))
	return total


func _get_target_score_text(rm: Node) -> String:
	if not rm.has_method("get_current_battle_config"):
		return "无"
	var config = rm.get_current_battle_config()
	if not (config is Dictionary):
		return "无"
	if not bool(config.get("has_score_target", false)):
		return "无"
	return str(int(config.get("target_score", -1)))


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
