extends RefCounted

const DEFAULT_INTRO_ANIMATION := "intro"
const LOCK_OVERLAY_NAME := "ShopIntroInputLock"
const VISUAL_OVERLAY_NAME := "ShopIntroVisualOverlay"
const INTRO_TEXTURE_NAME := "ShopIntroTexture"
const DEFAULT_FRAME_RATE := 60.0
const DEFAULT_FRAME_TIME := 1.0 / DEFAULT_FRAME_RATE

var root: Control = null
var animation_player: AnimationPlayer = null
var animation_name := DEFAULT_INTRO_ANIMATION
var frame_paths := PackedStringArray()
var frame_time := DEFAULT_FRAME_TIME

var _lock_overlay: Control = null
var _visual_overlay: Control = null
var _intro_texture: TextureRect = null
var _ui_locked := false


func setup(
	p_root: Control,
	p_animation_player: AnimationPlayer = null,
	p_animation_name: String = DEFAULT_INTRO_ANIMATION,
	p_frame_paths: PackedStringArray = PackedStringArray(),
	p_frame_time: float = DEFAULT_FRAME_TIME
) -> void:
	root = p_root
	animation_player = p_animation_player
	animation_name = p_animation_name
	frame_paths = p_frame_paths
	frame_time = maxf(0.01, p_frame_time)


func is_ui_locked() -> bool:
	return _ui_locked


func play_intro_and_unlock() -> void:
	lock_ui()
	await play_shop_intro()
	unlock_ui()


func lock_ui() -> void:
	_ui_locked = true
	if root == null or not root.is_inside_tree():
		return
	var existing := root.get_node_or_null(LOCK_OVERLAY_NAME) as Control
	if existing != null:
		_lock_overlay = existing
	else:
		_lock_overlay = Control.new()
		_lock_overlay.name = LOCK_OVERLAY_NAME
		_lock_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		_lock_overlay.focus_mode = Control.FOCUS_ALL
		_lock_overlay.z_index = 4096
		_lock_overlay.gui_input.connect(_on_lock_overlay_gui_input)
		root.add_child(_lock_overlay)
	_lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_lock_overlay.visible = true
	_lock_overlay.grab_focus()


func unlock_ui() -> void:
	_ui_locked = false
	if _lock_overlay != null and is_instance_valid(_lock_overlay):
		_lock_overlay.queue_free()
	_lock_overlay = null


func play_shop_intro() -> void:
	if root == null or not root.is_inside_tree():
		return
	if not frame_paths.is_empty():
		await _play_frame_intro()
		return
	if animation_player == null or animation_name == "" or not animation_player.has_animation(animation_name):
		await root.get_tree().process_frame
		return
	animation_player.play(animation_name)
	await animation_player.animation_finished


func _on_lock_overlay_gui_input(_event: InputEvent) -> void:
	if _lock_overlay != null:
		_lock_overlay.accept_event()


func _play_frame_intro() -> void:
	_ensure_visual_overlay()
	if _intro_texture == null:
		return
	_visual_overlay.visible = true
	for path in frame_paths:
		if root == null or not root.is_inside_tree():
			return
		var frame := AssetPaths.load_texture(path)
		if frame == null:
			continue
		_intro_texture.texture = frame
		await root.get_tree().create_timer(frame_time).timeout
	_hide_visual_overlay()


func _ensure_visual_overlay() -> void:
	if root == null or not root.is_inside_tree():
		return
	var existing := root.get_node_or_null(VISUAL_OVERLAY_NAME) as Control
	if existing != null:
		_visual_overlay = existing
	else:
		_visual_overlay = Control.new()
		_visual_overlay.name = VISUAL_OVERLAY_NAME
		_visual_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_visual_overlay.z_index = 4095
		root.add_child(_visual_overlay)
	_visual_overlay.set_anchors_preset(Control.PRESET_FULL_RECT, true)

	_intro_texture = _visual_overlay.get_node_or_null(INTRO_TEXTURE_NAME) as TextureRect
	if _intro_texture == null:
		_intro_texture = TextureRect.new()
		_intro_texture.name = INTRO_TEXTURE_NAME
		_intro_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_intro_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_intro_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_visual_overlay.add_child(_intro_texture)
	_intro_texture.set_anchors_preset(Control.PRESET_FULL_RECT, true)


func _hide_visual_overlay() -> void:
	if _visual_overlay != null and is_instance_valid(_visual_overlay):
		_visual_overlay.queue_free()
	_visual_overlay = null
	_intro_texture = null
