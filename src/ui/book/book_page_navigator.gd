extends Control

signal page_changed(page_id: String)

const BookBackgroundConfig = preload("res://src/ui/book/book_background_config.gd")

const PAGE_HUB := BookBackgroundConfig.PAGE_HUB
const PAGE_BACKPACK := BookBackgroundConfig.PAGE_BACKPACK
const PAGE_GALLERY := BookBackgroundConfig.PAGE_GALLERY
const PAGE_SETTINGS := BookBackgroundConfig.PAGE_SETTINGS
const PAGE_MAIN_MENU := "main_menu"

const DESIGN_SIZE := BookBackgroundConfig.DESIGN_SIZE
const TURN_DURATION := 0.32
const PAGE_STACK_Z := BookBackgroundConfig.PAGE_STACK_Z
const PAGE_SCENE_PATHS := {
	PAGE_BACKPACK: "res://src/ui/main_game_ui.tscn",
	PAGE_GALLERY: "res://src/ui/gallery/gallery_scene.tscn",
	PAGE_SETTINGS: "res://src/ui/settings/audio_settings_ui.tscn",
}

var current_page_id := PAGE_HUB
var _hub_scene: Node = null
var _pages: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _is_turning := false
var _turn_sheet: ColorRect
var _turn_shadow: ColorRect


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
	var turn_left_to_right := int(PAGE_STACK_Z[page_id]) < int(PAGE_STACK_Z[previous_page])
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	visible = true
	_ensure_page(page_id)
	_prepare_target_visibility(page_id)
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	await _play_turn_cover(turn_left_to_right)
	current_page_id = page_id
	_sync_page_visibility()
	await get_tree().process_frame
	await _play_turn_reveal(turn_left_to_right)
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
	add_child(page)
	move_child(page, 0)
	_configure_page(page_id, page)
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
	_turn_sheet.visible = false
	_turn_shadow.visible = false
	_is_turning = false
	_sync_page_visibility()
	GlobalInput.set_context(GlobalInput.Context.WORLD if current_page_id == PAGE_HUB else GlobalInput.Context.UI)
	page_changed.emit(current_page_id)


func _setup_turn_visuals() -> void:
	_turn_sheet = ColorRect.new()
	_turn_sheet.name = "TurnSheet"
	_turn_sheet.color = Color(0.86, 0.76, 0.58, 1.0)
	_turn_sheet.visible = false
	_turn_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_turn_sheet.z_index = 100
	add_child(_turn_sheet)

	_turn_shadow = ColorRect.new()
	_turn_shadow.name = "TurnShadow"
	_turn_shadow.color = Color(0.08, 0.045, 0.02, 0.28)
	_turn_shadow.visible = false
	_turn_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_shadow.z_index = 99
	add_child(_turn_shadow)


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
	if _turn_sheet == null or _turn_shadow == null:
		return
	_turn_sheet.position = Vector2.ZERO
	_turn_sheet.size = viewport_size
	_turn_shadow.position = Vector2.ZERO
	_turn_shadow.size = viewport_size


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


func _play_turn_cover(left_to_right: bool) -> void:
	_prepare_turn_sheet(left_to_right)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_turn_sheet, "scale:x", 1.0, TURN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_turn_shadow, "color:a", 0.34, TURN_DURATION)
	await tween.finished


func _play_turn_reveal(left_to_right: bool) -> void:
	var viewport_size := get_viewport_rect().size
	if left_to_right:
		_turn_sheet.pivot_offset = Vector2(viewport_size.x, viewport_size.y * 0.5)
	else:
		_turn_sheet.pivot_offset = Vector2(0.0, viewport_size.y * 0.5)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_turn_sheet, "scale:x", 0.0, TURN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_turn_shadow, "color:a", 0.0, TURN_DURATION)
	await tween.finished


func _prepare_turn_sheet(left_to_right: bool) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = DESIGN_SIZE
	_turn_sheet.visible = true
	_turn_sheet.position = Vector2.ZERO
	_turn_sheet.size = viewport_size
	_turn_sheet.scale = Vector2(0.0, 1.0)
	_turn_sheet.pivot_offset = Vector2(0.0 if left_to_right else viewport_size.x, viewport_size.y * 0.5)
	_turn_shadow.visible = true
	_turn_shadow.position = Vector2.ZERO
	_turn_shadow.size = viewport_size
	_turn_shadow.color.a = 0.0
