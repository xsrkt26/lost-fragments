extends Node

## 场景管理器：统一处理场景跳转、转场动画和导航历史

signal transition_started(target_scene)
signal transition_finished(new_scene)

enum SceneType {
	MAIN_MENU,
	HUB,
	BATTLE,
	SHOP,
	EVENT,
	GALLERY,
	DEBUG
}

const SCENE_PATHS = {
	SceneType.MAIN_MENU: "res://src/ui/main_menu/main_menu.tscn",
	SceneType.HUB: "res://src/ui/hub/hub_scene.tscn",
	SceneType.BATTLE: "res://src/ui/main_game_ui.tscn",
	SceneType.SHOP: "res://src/ui/shop/shop_scene.tscn",
	SceneType.EVENT: "res://src/ui/event/event_scene.tscn",
	SceneType.GALLERY: "res://src/ui/gallery/gallery_scene.tscn",
	SceneType.DEBUG: "res://src/ui/debug/debug_sandbox.tscn"
}

# 场景历史记录栈 (用于智能回退)
var _history_stack: Array[SceneType] = []
var current_scene_type: SceneType = SceneType.MAIN_MENU

# 转场 UI
var _overlay: ColorRect

func _ready():
	_setup_transition_ui()
	# 初始判断当前是哪个场景
	_detect_initial_scene()

func _setup_transition_ui():
	# 创建一个最高层级的画布
	var canvas = CanvasLayer.new()
	canvas.layer = 128 # 确保在所有 UI 之上
	add_child(canvas)
	
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_overlay)

func _detect_initial_scene():
	if not get_tree().current_scene: return
	var path = get_tree().current_scene.scene_file_path
	for type in SCENE_PATHS:
		if SCENE_PATHS[type] == path:
			current_scene_type = type
			break

## 核心跳转方法：带有淡入淡出动画
func transition_to(target: SceneType, push_to_history: bool = true):
	if push_to_history:
		_history_stack.append(current_scene_type)
	
	print("[SceneManager] 正在转场至: ", SceneType.keys()[target])
	transition_started.emit(target)
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	
	# 1. 黑屏淡入
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	await tween.tween_property(_overlay, "color:a", 1.0, 0.3).finished
	
	# 2. 物理切换场景
	current_scene_type = target
	get_tree().change_scene_to_file(SCENE_PATHS[target])
	
	# 等待一帧确保场景已挂载
	await get_tree().process_frame
	
	# 3. 黑屏淡出并恢复输入
	tween = create_tween()
	await tween.tween_property(_overlay, "color:a", 0.0, 0.3).finished
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	transition_finished.emit(get_tree().current_scene)

## 智能回退：回到上一级
func go_back():
	if _history_stack.is_empty():
		# 如果没有历史记录，默认回主菜单
		transition_to(SceneType.MAIN_MENU, false)
		return
	
	var prev = _history_stack.pop_back()
	transition_to(prev, false)

## 快捷跳转 (无动画，测试用)
func quick_goto(target: SceneType):
	current_scene_type = target
	get_tree().change_scene_to_file(SCENE_PATHS[target])
