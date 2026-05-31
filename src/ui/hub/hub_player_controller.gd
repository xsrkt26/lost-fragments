extends RefCounted

signal target_reached(interaction: String, target_x: float)

var player: CharacterBody2D = null
var pending_auto_interaction: String = ""


func setup(p_player: CharacterBody2D) -> void:
	player = p_player
	if player == null or not player.has_signal("move_target_reached"):
		return
	var callback := Callable(self, "_on_player_move_target_reached")
	if not player.is_connected("move_target_reached", callback):
		player.connect("move_target_reached", callback)


func has_pending_auto_interaction() -> bool:
	return pending_auto_interaction != ""


func get_pending_auto_interaction() -> String:
	return pending_auto_interaction


func clear_pending_auto_interaction() -> void:
	pending_auto_interaction = ""


func queue_auto_interaction(interaction: String, target_x: float) -> void:
	pending_auto_interaction = interaction
	_move_player_to(target_x)


func request_manual_move(target_x: float) -> void:
	clear_pending_auto_interaction()
	_move_player_to(target_x)


func clear_move_target() -> void:
	if player != null and player.has_method("clear_move_target"):
		player.clear_move_target()


func _move_player_to(target_x: float) -> void:
	if player != null and player.has_method("move_to_global_x"):
		player.move_to_global_x(target_x)


func _on_player_move_target_reached(target_x: float) -> void:
	var interaction := pending_auto_interaction
	pending_auto_interaction = ""
	target_reached.emit(interaction, target_x)
