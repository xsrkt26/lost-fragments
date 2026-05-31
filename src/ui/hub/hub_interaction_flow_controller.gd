extends RefCounted

signal request_enter_route_node
signal request_open_gallery

const AUTO_INTERACTION_ROUTE := "route"
const AUTO_INTERACTION_GALLERY := "gallery"
const AUTO_INTERACTION_MERCHANT := "merchant"

enum State {
	IDLE,
	MOVING,
	MERCHANT_INTERACTION,
	BATTLE_STARTING,
	TRANSITIONING,
}

var player_controller = null
var merchant_controller = null
var battle_controller = null

var state: int = State.IDLE


func setup(p_player_controller: RefCounted, p_merchant_controller: RefCounted, p_battle_controller: RefCounted) -> void:
	player_controller = p_player_controller
	merchant_controller = p_merchant_controller
	battle_controller = p_battle_controller


func is_busy() -> bool:
	return state != State.IDLE


func mark_transitioning() -> void:
	state = State.TRANSITIONING


func mark_idle() -> void:
	state = State.IDLE


func has_pending_auto_interaction() -> bool:
	return player_controller != null and player_controller.has_pending_auto_interaction() == true


func get_pending_auto_interaction() -> String:
	if player_controller == null:
		return ""
	return str(player_controller.get_pending_auto_interaction())


func clear_pending_auto_interaction() -> void:
	if player_controller != null:
		player_controller.clear_pending_auto_interaction()
	if state != State.TRANSITIONING:
		state = State.IDLE


func queue_auto_interaction(interaction: String, target_x: float) -> void:
	state = _get_state_for_auto_interaction(interaction)
	if player_controller != null:
		player_controller.queue_auto_interaction(interaction, target_x)


func request_manual_move(target_x: float) -> bool:
	if state == State.TRANSITIONING or state == State.BATTLE_STARTING:
		return false
	state = State.MOVING
	if player_controller != null:
		player_controller.request_manual_move(target_x)
		return true
	return false


func request_merchant_interaction(run_manager: Node) -> bool:
	if state == State.TRANSITIONING or merchant_controller == null:
		return false
	state = State.MERCHANT_INTERACTION
	merchant_controller.interact(run_manager)
	return true


func request_battle_start(run_manager: Node, hub_page_visible: bool, play_start_swing: Callable) -> bool:
	if state == State.TRANSITIONING or battle_controller == null:
		return false
	state = State.BATTLE_STARTING
	var accepted_result: Variant = await battle_controller.enter_battle(run_manager, hub_page_visible, play_start_swing)
	if state == State.BATTLE_STARTING:
		state = State.IDLE
	return accepted_result == true


func complete_player_arrival(
	interaction: String,
	target_x: float,
	run_manager: Node,
	merchant_sprite: AnimatedSprite2D,
	merchant_contains_x: Callable
) -> void:
	var reached_merchant := false
	if merchant_contains_x.is_valid():
		reached_merchant = (interaction == AUTO_INTERACTION_MERCHANT or interaction == "") and bool(merchant_contains_x.call(target_x))

	var played_merchant_arrival := false
	if reached_merchant and merchant_controller != null and merchant_sprite != null and merchant_sprite.visible:
		if not merchant_controller.is_player_at_merchant:
			merchant_controller.is_player_at_merchant = true
			played_merchant_arrival = merchant_controller.play_arrival_animation() == true

	match interaction:
		AUTO_INTERACTION_ROUTE:
			state = State.TRANSITIONING
			request_enter_route_node.emit()
		AUTO_INTERACTION_GALLERY:
			state = State.IDLE
			request_open_gallery.emit()
		AUTO_INTERACTION_MERCHANT:
			if merchant_controller != null:
				await merchant_controller.complete_interaction(run_manager, played_merchant_arrival)
			if state != State.TRANSITIONING:
				state = State.IDLE
		_:
			if state != State.TRANSITIONING:
				state = State.IDLE


func _get_state_for_auto_interaction(interaction: String) -> int:
	match interaction:
		AUTO_INTERACTION_MERCHANT:
			return State.MERCHANT_INTERACTION
		AUTO_INTERACTION_ROUTE, AUTO_INTERACTION_GALLERY:
			return State.MOVING
		_:
			return State.MOVING
