extends Node

## 场景管理器：统一处理场景跳转、转场动画和导航历史

signal transition_started(target_scene)
signal transition_finished(new_scene)

const PAGE_TURN_SHADER = preload("res://src/ui/transitions/page_turn.gdshader")
const ZOOM_EXPAND_SHADER = preload("res://src/ui/transitions/zoom_expand.gdshader")
const PAGE_TURN_DURATION := 1.05
const ZOOM_EXPAND_DURATION := 0.85

enum SceneType {
	MAIN_MENU,
	HUB,
	BATTLE,
	SHOP,
	EVENT,
	GALLERY,
	SETTINGS,
	DEBUG,
	CUTSCENE
}

const SCENE_PATHS = {
	SceneType.MAIN_MENU: "res://src/ui/main_menu/main_menu.tscn",
	SceneType.HUB: "res://src/ui/hub/hub_scene.tscn",
	SceneType.BATTLE: "res://src/ui/main_game_ui.tscn",
	SceneType.SHOP: "res://src/ui/shop/shop_scene.tscn",
	SceneType.EVENT: "res://src/ui/event/event_scene.tscn",
	SceneType.GALLERY: "res://src/ui/gallery/gallery_scene.tscn",
	SceneType.SETTINGS: "res://src/ui/settings/audio_settings_ui.tscn",
	SceneType.DEBUG: "res://src/ui/debug/debug_sandbox.tscn",
	SceneType.CUTSCENE: "res://src/ui/story/cutscene_scene.tscn"
}

# 场景历史记录栈 (用于智能回退)
var _history_stack: Array[SceneType] = []
var current_scene_type: SceneType = SceneType.MAIN_MENU

# 转场 UI
var _overlay: ColorRect
var _page_texture_rect: TextureRect
var _page_material: ShaderMaterial
var _is_transitioning := false
var _page_turn_progress := 0.0
var _preloaded_scenes: Dictionary = {}

func _ready():
	_setup_transition_ui()
	if get_tree() and get_tree().root and not get_tree().root.size_changed.is_connected(_sync_transition_ui_to_viewport):
		get_tree().root.size_changed.connect(_sync_transition_ui_to_viewport)
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
	_sync_transition_ui_to_viewport()

func _sync_transition_ui_to_viewport() -> void:
	var viewport_size := Vector2(1920.0, 1080.0)
	var viewport := get_viewport()
	if viewport != null:
		var visible_size := viewport.get_visible_rect().size
		if visible_size.x > 0.0 and visible_size.y > 0.0:
			viewport_size = visible_size
	var transition_controls: Array[Control] = [_page_texture_rect, _overlay]
	for control in transition_controls:
		if control == null:
			continue
		control.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
		control.position = Vector2.ZERO
		control.size = viewport_size

func _detect_initial_scene():
	if not get_tree().current_scene: return
	var path = get_tree().current_scene.scene_file_path
	for type in SCENE_PATHS:
		if SCENE_PATHS[type] == path:
			current_scene_type = type
			break

func is_scene_available(target: SceneType) -> bool:
	if not SCENE_PATHS.has(target):
		return false
	var scene_path: String = SCENE_PATHS[target]
	if target == SceneType.DEBUG and not ResourceLoader.exists(scene_path):
		return false
	return true

func _warn_unavailable_scene(target: SceneType) -> void:
	var keys := SceneType.keys()
	var target_name := str(target)
	if int(target) >= 0 and int(target) < keys.size():
		target_name = str(keys[int(target)])
	var scene_path: String = str(SCENE_PATHS.get(target, ""))
	push_warning("[SceneManager] Scene unavailable: %s %s" % [target_name, scene_path])

func _preload_transition_targets() -> void:
	await get_tree().process_frame
	for target in SCENE_PATHS.keys():
		if target != current_scene_type and is_scene_available(target):
			preload_scene(target)

func preload_scene(target: SceneType) -> void:
	if not is_scene_available(target) or _preloaded_scenes.has(target):
		return
	var scene_path: String = SCENE_PATHS[target]
	if ResourceLoader.has_cached(scene_path):
		var cached_resource: Resource = load(scene_path)
		if cached_resource is PackedScene:
			_preloaded_scenes[target] = cached_resource
		return
	var status: int = ResourceLoader.load_threaded_get_status(scene_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var loaded_resource: Resource = ResourceLoader.load_threaded_get(scene_path)
		if loaded_resource is PackedScene:
			_preloaded_scenes[target] = loaded_resource
		return
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	var request_error: int = ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)
	if request_error != OK:
		push_warning("[SceneManager] Failed to preload scene: %s" % scene_path)

## 核心跳转方法：带有淡入淡出动画
func transition_to(target: SceneType, push_to_history: bool = true):
	if not is_scene_available(target):
		_warn_unavailable_scene(target)
		return
	if _is_transitioning:
		return
	_is_transitioning = true
	if push_to_history:
		_history_stack.append(current_scene_type)

	print("[SceneManager] 正在转场至: ", SceneType.keys()[target])
	transition_started.emit(target)
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	_sync_transition_ui_to_viewport()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var snapshot_texture = await _capture_current_scene_texture()
	if snapshot_texture == null:
		snapshot_texture = _make_fallback_page_texture()
	if snapshot_texture != null:
		await _transition_with_page_turn(target, snapshot_texture)
	else:
		await _transition_with_fade(target)

	_is_transitioning = false
	transition_finished.emit(get_tree().current_scene)

func transition_with_zoom(target: SceneType, start_focus: Vector2 = Vector2(0.5, 0.5), end_focus: Vector2 = Vector2(0.8, 0.8), push_to_history: bool = true):
	if not is_scene_available(target):
		_warn_unavailable_scene(target)
		return
	if _is_transitioning:
		return
	_is_transitioning = true
	if push_to_history:
		_history_stack.append(current_scene_type)

	print("[SceneManager] 正在缩放转场至: ", SceneType.keys()[target])
	transition_started.emit(target)
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	_sync_transition_ui_to_viewport()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var snapshot_texture = await _capture_current_scene_texture()
	if snapshot_texture == null:
		snapshot_texture = _make_fallback_page_texture()

	if snapshot_texture != null:
		await _transition_with_zoom_expand(target, snapshot_texture, start_focus, end_focus)
	else:
		await _transition_with_fade(target)

	_is_transitioning = false
	transition_finished.emit(get_tree().current_scene)


func transition_to_direct(target: SceneType, push_to_history: bool = true) -> void:
	if not is_scene_available(target):
		_warn_unavailable_scene(target)
		return
	if _is_transitioning:
		return
	_is_transitioning = true
	if push_to_history:
		_history_stack.append(current_scene_type)

	print("[SceneManager] 正在直接转场至: ", SceneType.keys()[target])
	transition_started.emit(target)
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	_clear_page_turn_overlay()
	_sync_transition_ui_to_viewport()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var packed_scene: PackedScene = await _get_scene_for_transition(target)
	if packed_scene == null:
		push_error("[SceneManager] Failed to load scene: %s" % SCENE_PATHS[target])
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_is_transitioning = false
		return

	current_scene_type = target
	var error: int = get_tree().change_scene_to_packed(packed_scene)
	if error != OK:
		push_error("[SceneManager] Failed to change scene: %s" % SCENE_PATHS[target])
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_is_transitioning = false
		return

	await get_tree().process_frame
	await get_tree().process_frame
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	transition_finished.emit(get_tree().current_scene)


func _transition_with_zoom_expand(target: SceneType, snapshot_texture: Texture2D, start_focus: Vector2, end_focus: Vector2) -> void:
	_page_material.shader = ZOOM_EXPAND_SHADER
	_page_material.set_shader_parameter("start_focus", start_focus)
	_page_material.set_shader_parameter("end_focus", end_focus)
	_show_page_turn_overlay(snapshot_texture)

	var packed_scene: PackedScene = await _get_scene_for_transition(target)
	if packed_scene == null:
		_clear_page_turn_overlay()
		return

	current_scene_type = target
	get_tree().change_scene_to_packed(packed_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	_sync_transition_ui_to_viewport()

	var tween: Tween = create_tween()
	tween.tween_method(_set_page_turn_progress, 0.0, 1.0, ZOOM_EXPAND_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	await tween.finished
	_clear_page_turn_overlay()
	_page_material.shader = PAGE_TURN_SHADER # 还原回默认翻页着色器

func transition_with_page_turn(change_callback: Callable) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	_sync_transition_ui_to_viewport()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var snapshot_texture = await _capture_current_scene_texture()
	if snapshot_texture == null:
		snapshot_texture = _make_fallback_page_texture()
	if snapshot_texture == null:
		if change_callback.is_valid():
			change_callback.call()
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_is_transitioning = false
		return

	_show_page_turn_overlay(snapshot_texture)

	if change_callback.is_valid():
		change_callback.call()

	await get_tree().process_frame
	await get_tree().process_frame
	_sync_transition_ui_to_viewport()

	var tween: Tween = _start_page_turn_tween()
	await tween.finished
	_clear_page_turn_overlay()
	_is_transitioning = false

func _transition_with_page_turn(target: SceneType, snapshot_texture: Texture2D) -> void:
	_show_page_turn_overlay(snapshot_texture)
	var packed_scene: PackedScene = await _get_scene_for_transition(target)
	if packed_scene == null:
		push_error("[SceneManager] Failed to load scene: %s" % SCENE_PATHS[target])
		_clear_page_turn_overlay()
		return

	current_scene_type = target
	var error: int = get_tree().change_scene_to_packed(packed_scene)
	if error != OK:
		push_error("[SceneManager] Failed to change scene: %s" % SCENE_PATHS[target])
		_clear_page_turn_overlay()
		return

	await get_tree().process_frame
	await get_tree().process_frame
	_sync_transition_ui_to_viewport()

	var tween: Tween = _start_page_turn_tween()
	await tween.finished
	_clear_page_turn_overlay()

func _show_page_turn_overlay(snapshot_texture: Texture2D) -> void:
	_page_texture_rect.texture = snapshot_texture
	_page_texture_rect.visible = true
	_page_texture_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.color = Color(0, 0, 0, 0)
	_set_page_turn_progress(0.0)

func _start_page_turn_tween() -> Tween:
	var tween: Tween = create_tween()
	tween.tween_method(_set_page_turn_progress, 0.0, 1.0, _get_page_turn_duration()).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return tween

func _get_scene_for_transition(target: SceneType) -> PackedScene:
	if _preloaded_scenes.has(target) and _preloaded_scenes[target] is PackedScene:
		return _preloaded_scenes[target] as PackedScene
	var scene_path: String = SCENE_PATHS[target]
	var status: int = ResourceLoader.load_threaded_get_status(scene_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(scene_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var threaded_resource: Resource = ResourceLoader.load_threaded_get(scene_path)
		if threaded_resource is PackedScene:
			_preloaded_scenes[target] = threaded_resource
			return threaded_resource as PackedScene
	var loaded_resource: Resource = load(scene_path)
	if loaded_resource is PackedScene:
		_preloaded_scenes[target] = loaded_resource
		return loaded_resource as PackedScene
	return null

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
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		return null
	else:
		await RenderingServer.frame_post_draw
	var viewport_texture = get_viewport().get_texture()
	if viewport_texture == null:
		return null
	var image = viewport_texture.get_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return null
	return ImageTexture.create_from_image(image)

func _make_fallback_page_texture() -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.12, 0.095, 0.065, 1.0))
	return ImageTexture.create_from_image(image)

func _set_page_turn_progress(value: float) -> void:
	_page_turn_progress = value
	if _page_material:
		_page_material.set_shader_parameter("progress", value)

func _get_page_turn_duration() -> float:
	var settings = get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_method("get_animation_speed_multiplier"):
		return PAGE_TURN_DURATION * float(settings.get_animation_speed_multiplier())
	return PAGE_TURN_DURATION

func _clear_page_turn_overlay() -> void:
	_page_texture_rect.texture = null
	_page_texture_rect.visible = false
	_page_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(0, 0, 0, 0)
	_set_page_turn_progress(0.0)

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
	if not is_scene_available(target):
		_warn_unavailable_scene(target)
		return
	current_scene_type = target
	get_tree().change_scene_to_file(SCENE_PATHS[target])
