extends Control

const DesignScaler = preload("res://src/ui/layout/ui_design_scaler.gd")

## 主菜单：DesignRoot 中的编辑器布局为唯一布局源，运行时只缩放整层。

const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const MENU_FLOAT_DURATION := 0.14
const MENU_TEXT_HOVER_RISE := -10.0
const MENU_LIGHTER_HOVER_RISE := -14.0
const MENU_PRESS_DROP := 3.0
const MENU_TEXT_HOVER_SCALE := 1.035
const MENU_LIGHTER_HOVER_SCALE := 1.045
const MENU_PRESS_SCALE := 0.985
const RESPONSIVE_CONTROL_NAMES := [
	"NewGameButton",
	"ContinueButton",
	"GalleryButton",
	"SettingsButton",
	"QuitButton",
	"ContinueDisabledOverlay",
]

@onready var design_root: Control = $DesignRoot
@onready var continue_button: Button = $DesignRoot/MenuHotspots/ContinueButton
@onready var continue_disabled_overlay: ColorRect = $DesignRoot/MenuHotspots/ContinueDisabledOverlay

var run_manager_override = null
var _menu_control_base_positions: Dictionary = {}
var _menu_control_base_scales: Dictionary = {}
var _menu_control_hovered: Dictionary = {}
var _menu_control_pressed: Dictionary = {}
var _menu_control_tweens: Dictionary = {}

func _ready() -> void:
	print("[MainMenu] Entered main menu.")
	GlobalInput.set_context(GlobalInput.Context.MENU)
	GlobalAudio.play_bgm("menu")

	_cache_menu_control_poses()
	resized.connect(_layout_design_root)
	call_deferred("_layout_design_root")
	_configure_interactive_feedback()
	_refresh_continue_state()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		GlobalScene.transition_to(GlobalScene.SceneType.DEBUG)

func _configure_interactive_feedback() -> void:
	for node_name in RESPONSIVE_CONTROL_NAMES:
		if node_name == "ContinueDisabledOverlay":
			continue
		var control := get_node_or_null("DesignRoot/MenuHotspots/%s" % node_name) as Control
		if control == null or not (control is BaseButton):
			continue
		var button := control as BaseButton
		button.set_meta(GlobalFeedback.BUTTON_FEEDBACK_DISABLED_META, true)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.mouse_entered.connect(_on_menu_control_mouse_entered.bind(control))
		button.mouse_exited.connect(_on_menu_control_mouse_exited.bind(control))
		button.button_down.connect(_on_menu_control_button_down.bind(control))
		button.button_up.connect(_on_menu_control_button_up.bind(control))
		button.tree_exiting.connect(_clear_menu_control_tween.bind(control), CONNECT_ONE_SHOT)

func _refresh_continue_state() -> void:
	var rm = _get_run_manager()
	var has_continue_save: bool = rm != null and rm.saver != null and rm.saver.has_save() and not rm.is_run_complete
	continue_button.disabled = not has_continue_save
	continue_disabled_overlay.visible = not has_continue_save
	if continue_button.disabled:
		var continue_key := String(continue_button.name)
		_menu_control_hovered[continue_key] = false
		_menu_control_pressed[continue_key] = false
		_apply_menu_control_state(continue_button, false)

func _cache_menu_control_poses() -> void:
	_menu_control_base_positions.clear()
	_menu_control_base_scales.clear()
	for node_name in RESPONSIVE_CONTROL_NAMES:
		var control := get_node_or_null("DesignRoot/MenuHotspots/%s" % node_name) as Control
		if control == null:
			continue
		_menu_control_base_positions[node_name] = control.position
		_menu_control_base_scales[node_name] = control.scale

func _layout_design_root() -> void:
	DesignScaler.layout_root(design_root, get_viewport_rect().size, DESIGN_SIZE, DesignScaler.SCALE_MODE_COVER)

func _on_menu_control_mouse_entered(control: Control) -> void:
	if _is_disabled_button(control):
		return
	_menu_control_hovered[String(control.name)] = true
	_apply_menu_control_state(control, true)

func _on_menu_control_mouse_exited(control: Control) -> void:
	var key := String(control.name)
	_menu_control_hovered[key] = false
	_menu_control_pressed[key] = false
	_apply_menu_control_state(control, true)

func _on_menu_control_button_down(control: Control) -> void:
	if _is_disabled_button(control):
		return
	_menu_control_pressed[String(control.name)] = true
	_apply_menu_control_state(control, true)

func _on_menu_control_button_up(control: Control) -> void:
	_menu_control_pressed[String(control.name)] = false
	_apply_menu_control_state(control, true)

func _apply_menu_control_state(control: Control, animate: bool) -> void:
	if control == null:
		return
	var key := String(control.name)
	var base_position: Vector2 = _menu_control_base_positions.get(key, control.position)
	var base_scale: Vector2 = _menu_control_base_scales.get(key, control.scale)
	var hovered := bool(_menu_control_hovered.get(key, false))
	var pressed := bool(_menu_control_pressed.get(key, false))
	if _is_disabled_button(control):
		hovered = false
		pressed = false

	var target_position := base_position
	var target_scale := base_scale
	if pressed:
		target_position += Vector2(0.0, MENU_PRESS_DROP)
		target_scale = base_scale * MENU_PRESS_SCALE
	elif hovered:
		var hover_rise := MENU_LIGHTER_HOVER_RISE if key == "QuitButton" else MENU_TEXT_HOVER_RISE
		var hover_scale := MENU_LIGHTER_HOVER_SCALE if key == "QuitButton" else MENU_TEXT_HOVER_SCALE
		target_position += Vector2(0.0, hover_rise)
		target_scale = base_scale * hover_scale

	_clear_menu_control_tween(control)
	if not animate or not is_inside_tree():
		control.position = target_position
		control.scale = target_scale
		return

	var tween := create_tween()
	_menu_control_tweens[key] = tween
	tween.set_parallel(true)
	tween.tween_property(control, "position", target_position, MENU_FLOAT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", target_scale, MENU_FLOAT_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _clear_menu_control_tween(control: Control) -> void:
	if control == null:
		return
	var key := String(control.name)
	if not _menu_control_tweens.has(key):
		return
	var tween: Tween = _menu_control_tweens[key]
	if tween != null and tween.is_running():
		tween.kill()
	_menu_control_tweens.erase(key)

func _is_disabled_button(control: Control) -> bool:
	return control is BaseButton and (control as BaseButton).disabled

func _on_new_game_button_pressed() -> void:
	print("[MainMenu] New game pressed.")
	if _start_new_run():
		var sm = get_node_or_null("/root/StoryManager")
		if not sm or not sm.play_sequence("beginning"):
			GlobalScene.transition_to(GlobalScene.SceneType.HUB)

func _on_continue_button_pressed() -> void:
	print("[MainMenu] Continue pressed.")
	GlobalScene.transition_to(GlobalScene.SceneType.HUB)

func _on_gallery_button_pressed() -> void:
	print("[MainMenu] Gallery pressed.")
	GlobalScene.transition_to(GlobalScene.SceneType.GALLERY)

func _on_settings_button_pressed() -> void:
	GlobalScene.transition_to(GlobalScene.SceneType.SETTINGS)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _get_run_manager():
	if run_manager_override != null:
		return run_manager_override
	return get_node_or_null("/root/RunManager")

func _start_new_run() -> bool:
	var rm = _get_run_manager()
	if rm == null or not rm.has_method("start_new_run"):
		push_warning("[MainMenu] RunManager is missing; cannot start new run.")
		return false
	rm.start_new_run()
	return true
