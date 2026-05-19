extends Node2D

## 枢纽场景控制器：负责场景间的交互流转
## 交互模式：进入区域后按 E 键触发

@onready var overlay_root = $CanvasLayer/OverlayRoot
@onready var player = $Player
@onready var interactions = $Interactions

var current_zone: String = ""
var route_panel: Control

func _ready():
	print("[Hub] 已进入梦境路线。")
	GlobalInput.set_context(GlobalInput.Context.WORLD)
	GlobalAudio.play_bgm("hub")
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.is_run_complete:
		GlobalScene.transition_to(GlobalScene.SceneType.MAIN_MENU, false)
		return
	if interactions:
		interactions.hide()
	_build_route_ui()

	if rm and not rm.route_changed.is_connected(_on_route_changed):
		rm.route_changed.connect(_on_route_changed)

func _input(event):
	# 输入权限检查
	if not GlobalInput.can_cancel(): return

	# ESC 键处理：如果有浮窗则关闭浮窗，否则回到主界面
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		if overlay_root.get_child_count() > 0:
			_close_backpack_overlay()
			get_viewport().set_input_as_handled()
		else:
			_return_to_main_menu()
			get_viewport().set_input_as_handled()
		return

	# 兼容旧触发区：当前已改为路线按钮驱动。
	if GlobalInput.is_context(GlobalInput.Context.WORLD):
		if event.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_E):
			_enter_current_route_node()

func _unhandled_input(event):
	if overlay_root.get_child_count() > 0:
		return
	if not GlobalInput.is_context(GlobalInput.Context.WORLD):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if player and player.has_method("move_to_global_x"):
			player.move_to_global_x(event.position.x)
			get_viewport().set_input_as_handled()

func _build_route_ui():
	if route_panel and is_instance_valid(route_panel):
		route_panel.queue_free()

	route_panel = Control.new()
	route_panel.name = "RoutePanel"
	route_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	route_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	route_panel.custom_minimum_size = Vector2(0, 130)
	$CanvasLayer.add_child(route_panel)

	var act_label = Label.new()
	act_label.name = "ActLabel"
	act_label.position = Vector2(24, 86)
	act_label.size = Vector2(260, 28)
	route_panel.add_child(act_label)

	var node_row = HBoxContainer.new()
	node_row.name = "NodeRow"
	node_row.position = Vector2(180, 24)
	node_row.size = Vector2(920, 70)
	node_row.add_theme_constant_override("separation", 8)
	route_panel.add_child(node_row)

	_refresh_route_ui()

func _refresh_route_ui():
	if not route_panel or not is_instance_valid(route_panel):
		return
	var rm = get_node_or_null("/root/RunManager")
	if not rm:
		return
	var act_label = route_panel.get_node_or_null("ActLabel")
	if act_label:
		act_label.text = "第 %d 场景" % rm.current_act
	var node_row = route_panel.get_node_or_null("NodeRow")
	if not node_row:
		return
	for child in node_row.get_children():
		child.queue_free()

	var nodes = rm.get_route_nodes()
	for i in range(nodes.size()):
		var node = nodes[i]
		var button = Button.new()
		button.custom_minimum_size = Vector2(96, 54)
		button.tooltip_text = node.get("label", "")
		button.text = _get_route_button_text(rm, node, i)
		button.disabled = not rm.can_enter_route_node(i)
		button.pressed.connect(func(): _enter_route_node(i))
		node_row.add_child(button)

func _get_route_button_text(rm, node: Dictionary, index: int) -> String:
	var prefix = "."
	if rm.completed_route_nodes.has(index):
		prefix = "✓"
	elif index == rm.current_route_index:
		prefix = ">"
	return "%s %s" % [prefix, node.get("label", "节点")]

func _on_route_changed(_act: int, _route_index: int, _node: Dictionary):
	_refresh_route_ui()

func _enter_current_route_node():
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		_enter_route_node(rm.current_route_index)

func _enter_route_node(index: int):
	var rm = get_node_or_null("/root/RunManager")
	if not rm or not rm.can_enter_route_node(index):
		print("[Hub] 节点未解锁，无法进入: ", index)
		return
	var node = rm.get_current_route_node()
	print("[Hub] 进入路线节点: ", node.get("id", ""))
	await _move_player_to_route_index(index)
	GlobalScene.transition_to(rm.get_current_node_scene_type())

func _move_player_to_route_index(index: int):
	if not player:
		return
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	var nodes = get_node_or_null("CanvasLayer/RoutePanel/NodeRow")
	var target_x = 160.0 + float(index) * 110.0
	if nodes and index < nodes.get_child_count():
		var button = nodes.get_child(index)
		target_x = button.global_position.x + button.size.x * 0.5
	if player.has_method("play_move_animation_towards"):
		player.play_move_animation_towards(target_x)
	var tween = create_tween()
	tween.tween_property(player, "global_position:x", target_x, 0.35)
	await tween.finished
	if player.has_method("play_idle_animation"):
		player.play_idle_animation()

# --- 区域进入/退出判定 ---

func _on_battle_trigger_body_entered(_body):
	current_zone = "battle"
	print("[Hub] 站在 [进入战斗] 区域。按 E 进入。")

func _on_shop_trigger_body_entered(_body):
	current_zone = "shop"
	print("[Hub] 站在 [梦境商店] 区域。按 E 进入。")

func _on_gallery_trigger_body_entered(_body):
	current_zone = "gallery"
	print("[Hub] 站在 [物品图鉴] 区域。按 E 进入。")

func _on_zone_body_exited(_body):
	current_zone = ""
	print("[Hub] 离开区域")

# --- 场景切换逻辑 ---

func _on_main_menu_button_pressed():
	_return_to_main_menu()

func _return_to_main_menu():
	GlobalScene.transition_to(GlobalScene.SceneType.MAIN_MENU, false)

func _enter_battle():
	_enter_current_route_node()

func _enter_shop():
	_enter_current_route_node()

func _enter_gallery():
	print("[Hub] 图鉴请从主菜单进入。")

# --- 浮动背包逻辑 ---

func _on_backpack_button_pressed():
	if overlay_root.get_child_count() > 0:
		_close_backpack_overlay()
	else:
		_open_backpack_overlay()

func _open_backpack_overlay():
	print("[Hub] 正在打开背包浮层...")
	GlobalInput.set_context(GlobalInput.Context.UI)
	var ui_scene = load("res://src/ui/main_game_ui.tscn")
	var overlay = ui_scene.instantiate()
	if overlay.has_method("configure_for_backpack_overlay"):
		overlay.configure_for_backpack_overlay(_close_backpack_overlay)
	overlay_root.add_child(overlay)

func _close_backpack_overlay():
	print("[Hub] 正在关闭背包浮层")
	for child in overlay_root.get_children():
		if child.has_method("_on_menu_button_pressed") and child.get("battle_manager") != null:
			var manager = child.get("battle_manager")
			if manager and manager.has_method("persist_backpack_to_run"):
				manager.persist_backpack_to_run()
		child.queue_free()
	GlobalInput.set_context(GlobalInput.Context.WORLD)
