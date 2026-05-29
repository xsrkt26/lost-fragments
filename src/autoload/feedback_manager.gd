extends Node

## 反馈管理器：全局“汁水” (Juice) 系统
## 负责屏幕震动、飘字、冻结帧等表现效果

enum TextType { SCORE, SANITY, INFO }

const BUTTON_FEEDBACK_META := "_lost_fragments_button_feedback_bound"
const BUTTON_FEEDBACK_DISABLED_META := "_lost_fragments_button_feedback_disabled"
const BUTTON_BASE_SCALE_META := "_lost_fragments_button_feedback_base_scale"
const BUTTON_HOVER_SCALE := Vector2(1.035, 1.035)
const BUTTON_HOVER_DURATION := 0.08

var _shake_tween: Tween = null
var _button_tweens: Dictionary = {}

func _ready():
	print("[GlobalFeedback] 反馈管理器已就绪。")
	if get_tree() and not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	call_deferred("bind_buttons", get_tree().root)

# --- 通用 UI 反馈 ---

func bind_buttons(root: Node) -> void:
	if root == null:
		return
	if root is BaseButton:
		bind_button(root)
	for child in root.get_children():
		bind_buttons(child)

func bind_button(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button) or button.has_meta(BUTTON_FEEDBACK_META) or button.has_meta(BUTTON_FEEDBACK_DISABLED_META):
		return
	button.set_meta(BUTTON_FEEDBACK_META, true)
	button.set_meta(BUTTON_BASE_SCALE_META, button.scale)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(func(): _on_button_hovered(button))
	button.mouse_exited.connect(func(): _on_button_unhovered(button))
	button.focus_entered.connect(func(): _on_button_hovered(button))
	button.focus_exited.connect(func(): _on_button_unhovered(button))
	button.pressed.connect(func(): _on_button_pressed(button))
	button.tree_exiting.connect(func(): _clear_button_tween(button), CONNECT_ONE_SHOT)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		call_deferred("_bind_button_deferred", node)

func _bind_button_deferred(button: Variant) -> void:
	if button == null or not is_instance_valid(button) or not (button is BaseButton):
		return
	bind_button(button as BaseButton)

func _on_button_hovered(button: BaseButton) -> void:
	if button == null or button.disabled or button.has_meta(BUTTON_FEEDBACK_DISABLED_META) or not is_inside_tree():
		return
	var base_scale: Vector2 = button.get_meta(BUTTON_BASE_SCALE_META, button.scale)
	_tween_button_scale(button, base_scale * BUTTON_HOVER_SCALE)

func _on_button_unhovered(button: BaseButton) -> void:
	if button == null or button.has_meta(BUTTON_FEEDBACK_DISABLED_META) or not is_inside_tree():
		return
	var base_scale: Vector2 = button.get_meta(BUTTON_BASE_SCALE_META, button.scale)
	_tween_button_scale(button, base_scale)

func _on_button_pressed(button: BaseButton) -> void:
	if button == null or button.disabled:
		return
	_play_ui_sfx("click")

func _tween_button_scale(button: BaseButton, target_scale: Vector2) -> void:
	var key = button.get_instance_id()
	if _button_tweens.has(key):
		var old_tween = _button_tweens[key]
		if old_tween and old_tween.is_running():
			old_tween.kill()
	var tween = create_tween()
	_button_tweens[key] = tween
	tween.tween_property(button, "scale", target_scale, BUTTON_HOVER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _clear_button_tween(button: BaseButton) -> void:
	if button == null:
		return
	var key = button.get_instance_id()
	if not _button_tweens.has(key):
		return
	var tween = _button_tweens[key]
	if tween and tween.is_running():
		tween.kill()
	_button_tweens.erase(key)

func _play_ui_sfx(sfx_key: String) -> void:
	var audio = get_node_or_null("/root/GlobalAudio")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(sfx_key, 0.04)

# --- 屏幕震动 (Screen Shake) ---

## 触发屏幕震动
func shake_screen(intensity: float = 5.0, duration: float = 0.2):
	var camera = _get_active_camera()
	if not camera: return
	
	# 核心修复：如果上一次震动还没结束，先杀掉它，防止多个 Tween 争夺 Offset 控制权
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()
	
	var original_pos = Vector2.ZERO # 假设基础偏移是 0
	_shake_tween = create_tween()
	
	# 产生随机抖动序列
	var steps = 4
	for i in range(steps):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		_shake_tween.tween_property(camera, "offset", offset, duration / steps)
		intensity *= 0.7 
		
	_shake_tween.tween_property(camera, "offset", original_pos, 0.05)

func _get_active_camera() -> Camera2D:
	var viewport = get_viewport()
	if viewport:
		return viewport.get_camera_2d()
	return null

# --- 飘字系统 (Floating Text) ---

## 在指定位置显示动画文字
func show_text(text: String, global_pos: Vector2, type: TextType = TextType.INFO):
	var label = Label.new()
	label.text = text
	label.z_index = 200 
	
	# 优化样式
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	match type:
		TextType.SCORE:
			label.add_theme_color_override("font_color", Color.YELLOW)
			label.add_theme_font_size_override("font_size", 24)
		TextType.SANITY:
			label.add_theme_color_override("font_color", Color.RED if "-" in text else Color.GREEN)
			label.add_theme_font_size_override("font_size", 24)
		TextType.INFO:
			label.add_theme_color_override("font_color", Color.WHITE)
			
	get_tree().root.add_child(label)
	
	# 修正初始位置：将中心点对齐到 global_pos
	label.global_position = global_pos - label.get_combined_minimum_size() / 2.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	# 向上飘移
	tween.tween_property(label, "global_position:y", global_pos.y - 60.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 渐隐
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.2)
	# 轻微缩放增加动感
	label.scale = Vector2(0.5, 0.5)
	label.pivot_offset = label.get_combined_minimum_size() / 2.0
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.chain().tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)
	
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

# --- 冻结帧 (Hit Stop) ---

func hit_stop(duration: float = 0.05):
	Engine.time_scale = 0.01
	await get_tree().create_timer(duration, true, false, true).timeout 
	Engine.time_scale = 1.0
