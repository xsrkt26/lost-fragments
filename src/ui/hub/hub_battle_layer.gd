extends "res://src/ui/main_game_ui.gd"

@export var auto_initialize := false

var _hub_close_callback: Callable = Callable()


func _ensure_battle_manager_setup() -> void:
	if auto_initialize:
		super._ensure_battle_manager_setup()


func setup(p_battle_manager: BattleManager, close_callback: Callable = Callable()) -> void:
	_hub_close_callback = close_callback
	super.setup(p_battle_manager)


func _complete_victory_route(rm) -> void:
	if rm:
		rm.win_battle(0)
	var next_scene = GlobalScene.SceneType.MAIN_MENU if rm and rm.is_run_complete else GlobalScene.SceneType.HUB
	if _hub_close_callback.is_valid():
		_hub_close_callback.call(next_scene)
	else:
		GlobalScene.transition_to(next_scene, false)
