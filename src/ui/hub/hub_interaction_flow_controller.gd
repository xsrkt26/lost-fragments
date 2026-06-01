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
var _battle_request_token := 0
var _arrival_request_token := 0


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


func request_battle_start(run_manager: Node, hub_page_visible: bool, play_start_swing: Callable, on_complete: Callable = Callable()) -> bool:
	if state == State.TRANSITIONING or battle_controller == null:
		return false
	state = State.BATTLE_STARTING
	_battle_request_token += 1
	var request_token := _battle_request_token
	var accepted_result := battle_controller.enter_battle(
		run_manager,
		hub_page_visible,
		play_start_swing,
		Callable(self, "_on_battle_start_request_completed").bind(request_token, on_complete)
	)
	if not accepted_result:
		state = State.IDLE
		if on_complete.is_valid():
			on_complete.call()
		return false
	return true


func complete_player_arrival(
	interaction: String,
	target_x: float,
	run_manager: Node,
	merchant_sprite: AnimatedSprite2D,
	merchant_contains_x: Callable,
	on_complete: Callable = Callable()
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
				if state != State.TRANSITIONING:
					_arrival_request_token += 1
					var arrival_token := _arrival_request_token
					merchant_controller.complete_interaction(
						run_manager,
						played_merchant_arrival,
						Callable(self, "_on_player_arrival_complete").bind(arrival_token, on_complete)
					)
				else:
					merchant_controller.complete_interaction(run_manager, played_merchant_arrival)
			else:
				if state != State.TRANSITIONING:
					state = State.IDLE
		_:
			if state != State.TRANSITIONING:
				state = State.IDLE


func _on_battle_start_request_completed(request_token: int, on_complete: Callable = Callable()) -> void:
	if request_token != _battle_request_token:
		return
	if state == State.BATTLE_STARTING:
		state = State.IDLE
	if on_complete.is_valid():
		on_complete.call()


func _on_player_arrival_complete(token: int, on_complete: Callable = Callable()) -> void:
	if token != _arrival_request_token:
		return
	if state == State.MOVING or state == State.MERCHANT_INTERACTION:
		state = State.IDLE
	if on_complete.is_valid():
		on_complete.call()


func _get_state_for_auto_interaction(interaction: String) -> int:
	match interaction:
		AUTO_INTERACTION_MERCHANT:
			return State.MERCHANT_INTERACTION
		AUTO_INTERACTION_ROUTE, AUTO_INTERACTION_GALLERY:
			return State.MOVING
		_:
			return State.MOVING
