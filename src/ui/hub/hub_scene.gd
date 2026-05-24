extends Node2D

@onready var overlay_root: Control = $CanvasLayer/OverlayRoot
@onready var player: CharacterBody2D = $Player
@onready var interactions: Node2D = $Interactions

var current_zone: String = ""


func _ready() -> void:
	print("[Hub] 已进入梦境路线。")
	GlobalInput.set_context(GlobalInput.Context.WORLD)
	GlobalAudio.play_bgm(_get_stage_bgm_key("hub_bgm_key", "hub"))

	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.is_run_complete:
		GlobalScene.transition_to(GlobalScene.SceneType.MAIN_MENU, false)
		return

	if interactions:
		interactions.hide()

func _get_stage_bgm_key(key: String, fallback: String) -> String:
	var rm = get_node_or_null("/root/RunManager")
	if rm == null or not rm.has_method("get_current_stage_visual"):
		return fallback
	var visual = rm.get_current_stage_visual()
	var bgm_key = str(visual.get(key, fallback))
	return bgm_key if bgm_key != "" else fallback


func _input(event: InputEvent) -> void:
	if not GlobalInput.can_cancel():
		return

	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		if overlay_root.get_child_count() > 0:
			_close_backpack_overlay()
		else:
			_return_to_main_menu()
		get_viewport().set_input_as_handled()
		return

	if GlobalInput.is_context(GlobalInput.Context.WORLD):
		if event.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_E):
			_enter_current_route_node()


func _unhandled_input(event: InputEvent) -> void:
	if overlay_root.get_child_count() > 0:
		return
	if not GlobalInput.is_context(GlobalInput.Context.WORLD):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if player and player.has_method("move_to_global_x"):
			player.move_to_global_x(event.position.x)
			get_viewport().set_input_as_handled()


func _enter_current_route_node() -> void:
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		_enter_route_node(rm.current_route_index)


func _enter_route_node(index: int) -> void:
	var rm = get_node_or_null("/root/RunManager")
	if not rm or not rm.can_enter_route_node(index):
		print("[Hub] 节点未解锁，无法进入: ", index)
		return

	var node = rm.get_current_route_node()
	print("[Hub] 进入路线节点: ", node.get("id", ""))
	await _lock_briefly_before_transition()
	GlobalScene.transition_to(rm.get_current_node_scene_type())


func _lock_briefly_before_transition() -> void:
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	await get_tree().create_timer(0.1).timeout


func _on_battle_trigger_body_entered(_body) -> void:
	current_zone = "battle"
	print("[Hub] 站在 [进入战斗] 区域。按 E 进入。")


func _on_shop_trigger_body_entered(_body) -> void:
	current_zone = "shop"
	print("[Hub] 站在 [梦境商店] 区域。按 E 进入。")


func _on_gallery_trigger_body_entered(_body) -> void:
	current_zone = "gallery"
	print("[Hub] 站在 [物品图鉴] 区域。按 E 进入。")


func _on_zone_body_exited(_body) -> void:
	current_zone = ""
	print("[Hub] 离开区域")


func _on_main_menu_button_pressed() -> void:
	_return_to_main_menu()


func _return_to_main_menu() -> void:
	GlobalScene.transition_to(GlobalScene.SceneType.MAIN_MENU, false)


func _enter_battle() -> void:
	_enter_current_route_node()


func _enter_shop() -> void:
	_enter_current_route_node()


func _enter_gallery() -> void:
	print("[Hub] 图鉴请从主菜单进入。")


func _on_backpack_button_pressed() -> void:
	if overlay_root.get_child_count() > 0:
		_close_backpack_overlay()
	else:
		_open_backpack_overlay()


func _open_backpack_overlay() -> void:
	print("[Hub] 正在打开背包浮层...")
	GlobalInput.set_context(GlobalInput.Context.UI)
	var ui_scene = load("res://src/ui/main_game_ui.tscn")
	var overlay = ui_scene.instantiate()
	if overlay.has_method("configure_for_backpack_overlay"):
		overlay.configure_for_backpack_overlay(_close_backpack_overlay)
	overlay_root.add_child(overlay)


func _close_backpack_overlay() -> void:
	print("[Hub] 正在关闭背包浮层")
	for child in overlay_root.get_children():
		if child.has_method("_on_menu_button_pressed") and child.get("battle_manager") != null:
			var manager = child.get("battle_manager")
			if manager and manager.has_method("persist_backpack_to_run"):
				manager.persist_backpack_to_run()
		child.queue_free()
	GlobalInput.set_context(GlobalInput.Context.WORLD)
