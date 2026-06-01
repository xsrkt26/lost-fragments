extends RefCounted

signal request_enter_battle
signal request_idle_restart

var dreamcatcher_button: Button = null
var owner_node: Node = null
var transition_pending := false
var _active_battle_enter_callback: Callable = Callable()
var _active_battle_run_manager: Node = null
var _active_battle_hub_page_visible := false


func setup(p_dreamcatcher_button: Button, p_owner_node: Node = null) -> void:
	dreamcatcher_button = p_dreamcatcher_button
	owner_node = p_owner_node


func is_transition_pending() -> bool:
	return transition_pending


func update_state(run_manager: Node, hub_page_visible: bool) -> void:
	if dreamcatcher_button == null:
		return
	var can_start_game := can_enter_battle(run_manager) and not transition_pending and hub_page_visible
	dreamcatcher_button.disabled = not can_start_game
	dreamcatcher_button.tooltip_text = "Start dream" if can_start_game else ""
	dreamcatcher_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_start_game else Control.CURSOR_ARROW


func can_enter_battle(run_manager: Node) -> bool:
	if run_manager == null or not bool(run_manager.get("is_run_active")):
		return false
	if run_manager.has_method("can_enter_current_battle"):
		return run_manager.can_enter_current_battle()
	if not run_manager.has_method("get_current_route_node_type"):
		return false
	if run_manager.has_method("can_enter_route_node") and not run_manager.can_enter_route_node(int(run_manager.get("current_route_index"))):
		return false
	return RouteConfig.is_battle_node_type(run_manager.get_current_route_node_type())


func enter_battle(run_manager: Node, hub_page_visible: bool, play_start_swing: Callable, on_complete: Callable = Callable()) -> bool:
	if transition_pending or not can_enter_battle(run_manager):
		if on_complete.is_valid():
			on_complete.call()
		return false
	transition_pending = true
	update_state(run_manager, hub_page_visible)
	_active_battle_enter_callback = on_complete
	_active_battle_run_manager = run_manager
	_active_battle_hub_page_visible = hub_page_visible
	if play_start_swing.is_valid():
		var play_state := play_start_swing.call()
		if play_state is GDScriptFunctionState and play_state.is_valid():
			play_state.connect("completed", Callable(self, "_on_battle_start_swing_completed"), Object.CONNECT_ONE_SHOT)
			return true
		_finalize_battle_entry_request()
		return true
	_finalize_battle_entry_request()
	return true


func return_to_ready_state(run_manager: Node, hub_page_visible: bool) -> void:
	transition_pending = false
	update_state(run_manager, hub_page_visible)


func _on_battle_start_swing_completed(_result = null) -> void:
	_finalize_battle_entry_request()


func _finalize_battle_entry_request() -> void:
	if not transition_pending:
		_clear_battle_start_context()
		return
	if owner_node != null and (not is_instance_valid(owner_node) or not owner_node.is_inside_tree()):
		return_to_ready_state(_active_battle_run_manager, _active_battle_hub_page_visible)
	_call_battle_start_complete_callback()
	_clear_battle_start_context()
		return
	if not can_enter_battle(_active_battle_run_manager):
		return_to_ready_state(_active_battle_run_manager, _active_battle_hub_page_visible)
		request_idle_restart.emit()
		_call_battle_start_complete_callback()
		_clear_battle_start_context()
		return
	request_enter_battle.emit()
	_call_battle_start_complete_callback()
	_clear_battle_start_context()


func _call_battle_start_complete_callback() -> void:
	if _active_battle_enter_callback.is_valid():
		_active_battle_enter_callback.call()


func _clear_battle_start_context() -> void:
	_active_battle_enter_callback = Callable()
	_active_battle_run_manager = null
	_active_battle_hub_page_visible = false
