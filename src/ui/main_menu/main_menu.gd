extends Control

const DesignScaler = preload("res://src/ui/layout/ui_design_scaler.gd")
const BookBackgroundConfig = preload("res://src/ui/book/book_background_config.gd")

## 主菜单：DesignRoot 中的编辑器布局为唯一布局源，运行时只缩放整层。

const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const MENU_FLOAT_DURATION := 0.14
const MENU_TEXT_HOVER_RISE := -10.0
const MENU_LIGHTER_HOVER_RISE := -14.0
const MENU_PRESS_DROP := 3.0
const MENU_TEXT_HOVER_SCALE := 1.035
const MENU_LIGHTER_HOVER_SCALE := 1.045
const MENU_PRESS_SCALE := 0.985
const ENABLE_DEBUG_SHORTCUTS_IN_RELEASE := false
const RESPONSIVE_CONTROL_NAMES := [
	"NewGameButton",
	"ContinueButton",
	"GalleryButton",
	"SettingsButton",
	"QuitButton",
	"ContinueDisabledOverlay",
]
const REMOVED_MENU_ENTRY_NAMES := [
	"ContinueButton",
	"GalleryButton",
	"SettingsButton",
	"ContinueDisabledOverlay",
]

@onready var design_root: Control = $DesignRoot
@onready var continue_button: Button = $DesignRoot/MenuHotspots/ContinueButton
@onready var continue_disabled_overlay: ColorRect = $DesignRoot/MenuHotspots/ContinueDisabledOverlay

var run_manager_override = null
var scene_manager_override = null
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
	_hide_removed_menu_entries()

func _input(event: InputEvent) -> void:
	if not _is_debug_shortcut_enabled():
		return
	var debug_act := _debug_shortcut_act_from_event(event)
	if debug_act > 0:
		if _debug_jump_to_act(debug_act):
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var keycode := key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode
	match keycode:
		KEY_F7:
			if _debug_open_hub_page(BookBackgroundConfig.PAGE_BACKPACK):
				get_viewport().set_input_as_handled()
		KEY_F8:
			if _debug_open_hub_page(BookBackgroundConfig.PAGE_GALLERY):
				get_viewport().set_input_as_handled()
		KEY_F9:
			if _debug_open_hub_page(BookBackgroundConfig.PAGE_SETTINGS):
				get_viewport().set_input_as_handled()
		KEY_F10:
			if _debug_enter_next_route_node_from_menu():
				get_viewport().set_input_as_handled()
		KEY_F11:
			get_viewport().set_input_as_handled()
			_transition_to(GlobalScene.SceneType.DEBUG)

func _debug_shortcut_act_from_event(event: InputEvent) -> int:
	if not (event is InputEventKey):
		return 0
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return 0
	var keycode := key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode
	match keycode:
		KEY_F1:
			return 1
		KEY_F2:
			return 2
		KEY_F3:
			return 3
		KEY_F4:
			return 4
		KEY_F5:
			return 5
		KEY_F6:
			return 6
	return 0

func _debug_jump_to_act(act: int) -> bool:
	var rm = _get_run_manager()
	if rm == null or not rm.has_method("start_new_run"):
		push_warning("[MainMenu Debug] RunManager is missing; cannot jump to target act.")
		return false
	var target_act := clampi(act, 1, StageConfig.get_max_act())
	rm.start_new_run()
	rm.current_act = target_act
	rm.current_route_id = StageConfig.get_route_id_for_act(target_act, RouteConfig.DEFAULT_ROUTE_ID)
	rm.current_route_index = 0
	rm.completed_route_nodes = [] as Array[int]
	rm.is_run_active = true
	rm.is_run_complete = false
	rm.debug_hub_page_request = ""
	rm.debug_hub_advance_next_node_request = false
	if target_act > 1:
		_suppress_story_for_debug_jump(target_act)
	if rm.has_method("save_current_state"):
		rm.save_current_state()
	_transition_to(GlobalScene.SceneType.HUB)
	print("[MainMenu Debug] Jumped to act ", target_act, ".")
	return true


func _suppress_story_for_debug_jump(target_act: int) -> void:
	var story_manager := get_node_or_null("/root/StoryManager")
	if story_manager != null and story_manager.has_method("suppress_debug_jump_story"):
		story_manager.call("suppress_debug_jump_story", target_act)


func _debug_open_hub_page(page_id: String) -> bool:
	var rm = _get_run_manager()
	if not _ensure_debug_run_ready(rm):
		return false
	rm.debug_hub_page_request = page_id
	rm.debug_hub_advance_next_node_request = false
	_transition_to(GlobalScene.SceneType.HUB)
	return true

func _debug_enter_next_route_node_from_menu() -> bool:
	var rm = _get_run_manager()
	if not _ensure_debug_run_ready(rm):
		return false
	rm.debug_hub_page_request = ""
	rm.debug_hub_advance_next_node_request = true
	_transition_to(GlobalScene.SceneType.HUB)
	return true

func _ensure_debug_run_ready(rm) -> bool:
	if rm == null or not rm.has_method("start_new_run"):
		push_warning("[MainMenu Debug] RunManager is missing; cannot prepare debug run.")
		return false
	if not bool(rm.get("is_run_active")) or bool(rm.get("is_run_complete")):
		rm.start_new_run()
	if rm.has_method("save_current_state"):
		rm.save_current_state()
	return true

func _is_debug_shortcut_enabled() -> bool:
	return OS.is_debug_build() or ENABLE_DEBUG_SHORTCUTS_IN_RELEASE

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
	var has_continue_save := _has_continue_save()
	continue_button.disabled = not has_continue_save
	continue_disabled_overlay.visible = not has_continue_save
	if continue_button.disabled:
		var continue_key := String(continue_button.name)
		_menu_control_hovered[continue_key] = false
		_menu_control_pressed[continue_key] = false
		_apply_menu_control_state(continue_button, false)
	_hide_removed_menu_entries()

func _has_continue_save() -> bool:
	var rm = _get_run_manager()
	return rm != null and rm.saver != null and rm.saver.has_save() and not rm.is_run_complete

func _resolve_dream_entry_scene() -> int:
	return GlobalScene.SceneType.STORY_BOOK

func _hide_removed_menu_entries() -> void:
	for node_name in REMOVED_MENU_ENTRY_NAMES:
		var control := get_node_or_null("DesignRoot/MenuHotspots/%s" % node_name) as Control
		if control == null:
			continue
		control.visible = false
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if control is BaseButton:
			var button := control as BaseButton
			button.disabled = true
		_menu_control_hovered[node_name] = false
		_menu_control_pressed[node_name] = false
		_clear_menu_control_tween(control)

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
		_transition_to(_resolve_dream_entry_scene())

func _on_continue_button_pressed() -> void:
	print("[MainMenu] Continue pressed.")
	_transition_to(GlobalScene.SceneType.HUB)

func _on_gallery_button_pressed() -> void:
	print("[MainMenu] Gallery pressed.")
	_transition_to(GlobalScene.SceneType.GALLERY)

func _on_settings_button_pressed() -> void:
	_transition_to(GlobalScene.SceneType.SETTINGS)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _get_run_manager():
	if run_manager_override != null:
		return run_manager_override
	return get_node_or_null("/root/RunManager")

func _get_scene_manager():
	if scene_manager_override != null:
		return scene_manager_override
	return get_node_or_null("/root/GlobalScene")

func _transition_to(scene_type: int, push_to_history: bool = true) -> void:
	var scene_manager = _get_scene_manager()
	if scene_manager != null and scene_manager.has_method("transition_to"):
		scene_manager.transition_to(scene_type, push_to_history)

func _start_new_run() -> bool:
	var rm = _get_run_manager()
	if rm == null or not rm.has_method("start_new_run"):
		push_warning("[MainMenu] RunManager is missing; cannot start new run.")
		return false
	rm.start_new_run()
	return true

func _debug_enter_hub_after_first_dreamcatcher() -> void:
	print("[MainMenu Debug] F2: enter Hub after first dreamcatcher battle.")
	var rm = _get_run_manager()
	if rm == null or not rm.has_method("start_new_run"):
		push_warning("[MainMenu Debug] RunManager is missing; cannot prepare shop debug route.")
		return
	rm.start_new_run()
	_debug_skip_intro_story()
	if rm.has_method("get_current_route_node_type") and RouteConfig.is_battle_node_type(str(rm.get_current_route_node_type())):
		rm.advance_route_node()
	_transition_to(GlobalScene.SceneType.HUB)

func _debug_skip_intro_story() -> void:
	var sm = get_node_or_null("/root/StoryManager")
	var rm = _get_run_manager()
	var skipped_flags := {
		"beginning": true,
		"enter_stage_1": true,
		"进入场景1": true,
		"enter_battle_1": true,
		"进入局内1": true,
		"进入局内": true,
	}
	if rm != null and rm.has_method("set_story_played_flags"):
		rm.set_story_played_flags(skipped_flags, true)
	if sm != null and sm.has_method("set_played_flags"):
		sm.set_played_flags(skipped_flags)
