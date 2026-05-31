extends RefCounted

signal request_enter_battle
signal request_idle_restart

var dreamcatcher_button: Button = null
var owner_node: Node = null
var transition_pending := false


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


func enter_battle(run_manager: Node, hub_page_visible: bool, play_start_swing: Callable) -> bool:
	if transition_pending or not can_enter_battle(run_manager):
		return false
	transition_pending = true
	update_state(run_manager, hub_page_visible)
	if play_start_swing.is_valid():
		await play_start_swing.call()
	if owner_node != null and (not is_instance_valid(owner_node) or not owner_node.is_inside_tree()):
		return true
	if not can_enter_battle(run_manager):
		return_to_ready_state(run_manager, hub_page_visible)
		request_idle_restart.emit()
		return true
	request_enter_battle.emit()
	return true


func return_to_ready_state(run_manager: Node, hub_page_visible: bool) -> void:
	transition_pending = false
	update_state(run_manager, hub_page_visible)
