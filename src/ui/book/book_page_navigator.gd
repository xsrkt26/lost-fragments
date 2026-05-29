extends Control

signal page_changed(page_id: String)

const BookBackgroundConfig = preload("res://src/ui/book/book_background_config.gd")
const BookPageTurnEffectScript = preload("res://src/ui/book/book_page_turn_effect.gd")

const PAGE_HUB := BookBackgroundConfig.PAGE_HUB
const PAGE_BACKPACK := BookBackgroundConfig.PAGE_BACKPACK
const PAGE_GALLERY := BookBackgroundConfig.PAGE_GALLERY
const PAGE_SETTINGS := BookBackgroundConfig.PAGE_SETTINGS
const PAGE_MAIN_MENU := "main_menu"

const DESIGN_SIZE := BookBackgroundConfig.DESIGN_SIZE
const PAGE_STACK_Z := BookBackgroundConfig.PAGE_STACK_Z
const PAGE_SCENE_PATHS := {
	PAGE_BACKPACK: "res://src/ui/main_game_ui.tscn",
	PAGE_GALLERY: "res://src/ui/gallery/gallery_scene.tscn",
	PAGE_SETTINGS: "res://src/ui/settings/audio_settings_ui.tscn",
}

@export var turn_duration := 0.68

var current_page_id := PAGE_HUB
var _hub_scene: Node = null
var _pages: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _is_turning := false
var _turn_effect: BookPageTurnEffect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_turn_visuals()
	_setup_tab_hotspots()
	if not resized.is_connected(_layout_navigation):
		resized.connect(_layout_navigation)
	call_deferred("_layout_navigation")


func configure(hub_scene: Node) -> void:
	_hub_scene = hub_scene
	current_page_id = PAGE_HUB
	_set_hub_page_visible(true)
	_sync_page_visibility()
	_layout_navigation()


func go_to_page(page_id: String) -> void:
	if not PAGE_STACK_Z.has(page_id):
		return
	if page_id == current_page_id or _is_turning:
		return
	_is_turning = true
	var previous_page := current_page_id
	var visual_left_to_right := _is_visual_turn_left_to_right(previous_page, page_id)
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	visible = true
	_ensure_page(page_id)
	_prepare_target_visibility(page_id)
	var turn_sheet_info := _get_page_turn_sheet_info(previous_page if visual_left_to_right else page_id)
	if not _is_valid_page_turn_sheet_info(turn_sheet_info):
		turn_sheet_info = _get_page_turn_sheet_info(previous_page)
	var start_progress := 0.0 if visual_left_to_right else 1.0
	var target_progress := 1.0 if visual_left_to_right else 0.0
	_prepare_turn_effect(true, turn_sheet_info, start_progress)
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	if visual_left_to_right:
		current_page_id = page_id
		_sync_page_visibility()
	else:
		_sync_tab_buttons()
	await get_tree().process_frame
	await _play_turn(target_progress)
	if not visual_left_to_right:
		current_page_id = page_id
		_sync_page_visibility()
	_finish_transition()


func request_page(page_id: String) -> void:
	go_to_page(page_id)


func return_to_main_menu() -> void:
	if _is_turning:
		return
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	GlobalScene.transition_to(GlobalScene.SceneType.MAIN_MENU, false)


func is_hub_current() -> bool:
	return current_page_id == PAGE_HUB and not _is_turning


func is_turning() -> bool:
	return _is_turning


func get_visual_turn_direction(from_page_id: String, to_page_id: String) -> int:
	if not PAGE_STACK_Z.has(from_page_id) or not PAGE_STACK_Z.has(to_page_id):
		return 0
	return 1 if _is_visual_turn_left_to_right(from_page_id, to_page_id) else -1


func _is_visual_turn_left_to_right(from_page_id: String, to_page_id: String) -> bool:
	return int(PAGE_STACK_Z[to_page_id]) < int(PAGE_STACK_Z[from_page_id])


func _ensure_page(page_id: String) -> Control:
	if page_id == PAGE_HUB:
		return null
	if _pages.has(page_id) and is_instance_valid(_pages[page_id]):
		return _pages[page_id] as Control
	var scene_path: String = str(PAGE_SCENE_PATHS.get(page_id, ""))
	if scene_path == "":
		return null
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("[BookPageNavigator] Failed to load page scene: %s" % scene_path)
		return null
	var page := packed.instantiate() as Control
	if page == null:
		push_warning("[BookPageNavigator] Page scene is not a Control: %s" % scene_path)
		return null
	page.name = "%sPage" % page_id.capitalize()
	page.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	page.visible = false
	page.z_index = 1
	_configure_page(page_id, page)
	add_child(page)
	move_child(page, 0)
	_pages[page_id] = page
	return page


func _configure_page(page_id: String, page: Control) -> void:
	if page_id == PAGE_BACKPACK and page.has_method("configure_for_backpack_overlay"):
		page.configure_for_backpack_overlay(Callable(self, "return_to_main_menu"))
	if page.has_method("set_book_page_navigator"):
		page.set_book_page_navigator(self)


func _prepare_target_visibility(page_id: String) -> void:
	if page_id == PAGE_HUB:
		return
	var page := _ensure_page(page_id)
	if page != null:
		page.visible = false
		page.set_process_input(false)
		page.set_process_unhandled_input(false)


func _sync_page_visibility() -> void:
	var hub_visible := current_page_id == PAGE_HUB
	_set_hub_page_visible(hub_visible)
	for page_id in _pages.keys():
		var page := _pages[page_id] as Control
		if page == null:
			continue
		var page_visible := str(page_id) == current_page_id
		page.visible = page_visible
		page.set_process_input(page_visible)
		page.set_process_unhandled_input(page_visible)
	visible = not hub_visible or _is_turning
	_layout_navigation()
	_sync_tab_buttons()


func _set_hub_page_visible(page_visible: bool) -> void:
	if _hub_scene == null or not is_instance_valid(_hub_scene):
		return
	if _hub_scene.has_method("set_book_hub_visible"):
		_hub_scene.set_book_hub_visible(page_visible)


func _finish_transition() -> void:
	if _turn_effect != null:
		_turn_effect.finish_turn()
	_is_turning = false
	_sync_page_visibility()
	GlobalInput.set_context(GlobalInput.Context.WORLD if current_page_id == PAGE_HUB else GlobalInput.Context.UI)
	page_changed.emit(current_page_id)


func _setup_turn_visuals() -> void:
	_turn_effect = get_node_or_null("PageTurnEffect") as BookPageTurnEffect
	if _turn_effect == null:
		_turn_effect = BookPageTurnEffectScript.new()
		_turn_effect.name = "PageTurnEffect"
		add_child(_turn_effect)
	_turn_effect.visible = false
	_turn_effect.mouse_filter = Control.MOUSE_FILTER_STOP
	_turn_effect.z_index = 100


func _setup_tab_hotspots() -> void:
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color(1.0, 1.0, 1.0, 0.0)
	for page_id in BookBackgroundConfig.PAGE_ORDER:
		var button := Button.new()
		button.name = "%sTabButton" % str(page_id).capitalize()
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.text = ""
		button.z_index = 80
		button.add_theme_stylebox_override("normal", transparent)
		button.add_theme_stylebox_override("hover", transparent)
		button.add_theme_stylebox_override("pressed", transparent)
		button.add_theme_stylebox_override("disabled", transparent)
		button.pressed.connect(Callable(self, "go_to_page").bind(str(page_id)))
		add_child(button)
		_tab_buttons[page_id] = button


func _sync_tab_buttons() -> void:
	for page_id in _tab_buttons.keys():
		var button := _tab_buttons[page_id] as Button
		if button == null:
			continue
		var enabled := current_page_id != PAGE_HUB and str(page_id) != current_page_id and not _is_turning
		button.visible = enabled
		button.disabled = not enabled
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _layout_navigation() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = DESIGN_SIZE
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_layout_turn_visuals(viewport_size)
	_layout_tab_buttons(viewport_size)


func _layout_turn_visuals(viewport_size: Vector2) -> void:
	if _turn_effect == null:
		return
	if _turn_effect.visible:
		return
	_turn_effect.position = Vector2.ZERO
	_turn_effect.size = viewport_size


func _layout_tab_buttons(viewport_size: Vector2) -> void:
	var scale_factor := maxf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	var origin := (viewport_size - DESIGN_SIZE * scale_factor) * 0.5
	for page_id in _tab_buttons.keys():
		var button := _tab_buttons[page_id] as Button
		if button == null:
			continue
		var rect := BookBackgroundConfig.get_tab_rect(str(page_id), current_page_id)
		button.position = origin + rect.position * scale_factor
		button.size = rect.size * scale_factor


func _play_turn(target_progress: float) -> void:
	if _turn_effect == null:
		return
	var tween := create_tween()
	tween.tween_property(_turn_effect, "progress", target_progress, turn_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _prepare_turn_effect(left_to_right: bool, sheet_info: Dictionary, start_progress: float) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = DESIGN_SIZE
	if _turn_effect == null:
		return
	var turn_rect: Rect2 = sheet_info.get("global_rect", Rect2(Vector2.ZERO, viewport_size))
	var page_texture := sheet_info.get("texture", null) as Texture2D
	var front_tint: Color = sheet_info.get("modulate", Color.WHITE)
	_turn_effect.position = turn_rect.position
	_turn_effect.size = turn_rect.size
	_turn_effect.start_turn(left_to_right, page_texture, start_progress, front_tint)


func _get_page_turn_sheet_info(page_id: String) -> Dictionary:
	var background := _get_book_background_for_page(page_id)
	if background != null and background.has_method("get_page_turn_sheet_info"):
		var info = background.call("get_page_turn_sheet_info")
		if info is Dictionary:
			var typed_info: Dictionary = info
			if not typed_info.is_empty():
				return typed_info
	return {
		"global_rect": Rect2(Vector2.ZERO, get_viewport_rect().size),
		"texture": null,
		"modulate": Color.WHITE,
	}


func _is_valid_page_turn_sheet_info(sheet_info: Dictionary) -> bool:
	var turn_rect: Rect2 = sheet_info.get("global_rect", Rect2())
	return sheet_info.get("texture", null) is Texture2D and turn_rect.size.x > 1.0 and turn_rect.size.y > 1.0


func _get_book_background_for_page(page_id: String) -> Node:
	if page_id == PAGE_HUB:
		return _find_book_background(_hub_scene)
	if not _pages.has(page_id):
		return null
	return _find_book_background(_pages[page_id] as Node)


func _find_book_background(root: Node) -> Node:
	if root == null or not is_instance_valid(root):
		return null
	if root.has_method("get_page_turn_sheet_info"):
		return root
	for child in root.get_children():
		var found := _find_book_background(child)
		if found != null:
			return found
	return null
