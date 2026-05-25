extends Node

## 场景管理器：统一处理场景跳转、转场动画和导航历史

signal transition_started(target_scene)
signal transition_finished(new_scene)

const PAGE_TURN_SHADER = preload("res://src/ui/transitions/page_turn.gdshader")
const PAGE_TURN_DURATION := 0.62

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
var _page_texture_rect: TextureRect
var _page_material: ShaderMaterial
var _is_transitioning := false

func _ready():
	_setup_transition_ui()
	# 初始判断当前是哪个场景
	_detect_initial_scene()

func _setup_transition_ui():
	# 创建一个最高层级的画布
	var canvas = CanvasLayer.new()
	canvas.layer = 128 # 确保在所有 UI 之上
	add_child(canvas)

	_page_material = ShaderMaterial.new()
	_page_material.shader = PAGE_TURN_SHADER
	_page_material.set_shader_parameter("progress", 0.0)

	_page_texture_rect = TextureRect.new()
	_page_texture_rect.visible = false
	_page_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_page_texture_rect.material = _page_material
	canvas.add_child(_page_texture_rect)

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
	if _is_transitioning:
		return
	_is_transitioning = true
	if push_to_history:
		_history_stack.append(current_scene_type)

	print("[SceneManager] 正在转场至: ", SceneType.keys()[target])
	transition_started.emit(target)
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var snapshot_texture = await _capture_current_scene_texture()
	if snapshot_texture:
		await _transition_with_page_turn(target, snapshot_texture)
	else:
		await _transition_with_fade(target)

	_is_transitioning = false
	transition_finished.emit(get_tree().current_scene)

func _transition_with_page_turn(target: SceneType, snapshot_texture: Texture2D) -> void:
	_page_texture_rect.texture = snapshot_texture
	_page_texture_rect.visible = true
	_page_texture_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_page_material.set_shader_parameter("progress", 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.color = Color(0, 0, 0, 0)

	current_scene_type = target
	var error = get_tree().change_scene_to_file(SCENE_PATHS[target])
	if error != OK:
		push_error("[SceneManager] Failed to change scene: %s" % SCENE_PATHS[target])
		_clear_page_turn_overlay()
		return

	await get_tree().process_frame
	await get_tree().process_frame

	var tween = create_tween()
	tween.tween_method(_set_page_turn_progress, 0.0, 1.0, PAGE_TURN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_clear_page_turn_overlay()

func _transition_with_fade(target: SceneType) -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	await tween.tween_property(_overlay, "color:a", 1.0, 0.3).finished

	current_scene_type = target
	var error = get_tree().change_scene_to_file(SCENE_PATHS[target])
	if error != OK:
		push_error("[SceneManager] Failed to change scene: %s" % SCENE_PATHS[target])
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	# 等待一帧确保场景已挂载
	await get_tree().process_frame

	tween = create_tween()
	await tween.tween_property(_overlay, "color:a", 0.0, 0.3).finished
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _capture_current_scene_texture() -> Texture2D:
	await RenderingServer.frame_post_draw
	var viewport_texture = get_viewport().get_texture()
	if viewport_texture == null:
		return null
	var image = viewport_texture.get_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return null
	return ImageTexture.create_from_image(image)

func _set_page_turn_progress(value: float) -> void:
	if _page_material:
		_page_material.set_shader_parameter("progress", value)

func _clear_page_turn_overlay() -> void:
	_page_texture_rect.texture = null
	_page_texture_rect.visible = false
	_page_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(0, 0, 0, 0)

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
