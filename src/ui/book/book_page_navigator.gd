extends Control

signal page_changed(page_id: String)


const PAGE_HUB := BookBackgroundConfig.PAGE_HUB
const PAGE_BACKPACK := BookBackgroundConfig.PAGE_BACKPACK
const PAGE_GALLERY := BookBackgroundConfig.PAGE_GALLERY
const PAGE_SETTINGS := BookBackgroundConfig.PAGE_SETTINGS
const PAGE_MAIN_MENU := "main_menu"

const DESIGN_SIZE := BookBackgroundConfig.DESIGN_SIZE
const PAGE_STACK_Z := BookBackgroundConfig.PAGE_STACK_Z
const PAGE_SCENE_PATHS := {
	PAGE_BACKPACK: "res://src/ui/backpack/backpack_page.tscn",
	PAGE_GALLERY: "res://src/ui/gallery/gallery_scene.tscn",
	PAGE_SETTINGS: "res://src/ui/settings/audio_settings_ui.tscn",
}
const PAGE_TAB_NODE_NAMES := {
	PAGE_HUB: "AlbumTab",
	PAGE_BACKPACK: "BackpackTab",
	PAGE_GALLERY: "GalleryTab",
	PAGE_SETTINGS: "SettingsTab",
}
const PAGE_TAB_TEXTURE_PATHS := {
	PAGE_HUB: "res://assets/ui/book/tab_album.png",
	PAGE_BACKPACK: "res://assets/ui/book/tab_backpack.png",
	PAGE_GALLERY: "res://assets/ui/book/tab_gallery.png",
	PAGE_SETTINGS: "res://assets/ui/book/tab_settings.png",
}
const PAGE_SHEET_NODE_NAMES := {
	PAGE_HUB: "AlbumPage",
	PAGE_GALLERY: "PageMiddle",
	PAGE_BACKPACK: "PageBackpackCover",
	PAGE_SETTINGS: "PageRouteCover",
}
const BOOK_BASE_ART_NODE_NAMES := [
	"WoodFloor",
	"RedBookCover",
	"AlbumRingRight",
]
const BACK_TAB_TEXTURE_PATH := "res://assets/ui/book/tab_back.png"
const TRANSITION_PAGE_TO_PAGE := "page_to_page"
const PAGE_TO_PAGE_COMPRESS := "compress"
const PAGE_TO_PAGE_EXPAND := "expand"
const TRANSITION_BACK_LAYER_Z := 0
const TRANSITION_FRONT_LAYER_Z := 2500
const TRANSITION_CANVAS_LAYER := 10
const TRANSITION_PAGE_Z_STEP := 800
const TRANSITION_SHEETS_ROOT_Z := 0
const TRANSITION_TABS_ROOT_Z := 1000
const TRANSITION_CONTENTS_ROOT_Z := 2000
const TRANSITION_SHEET_LOCAL_Z := 0
const TRANSITION_TAB_LOCAL_Z := 10
const TRANSITION_CONTENT_LOCAL_Z := 20
const TRANSITION_BACK_TAB_Z := 5

@export var hub_stretch_duration := 0.48
@export var layer_collapse_width_ratio := 0.1
@export var compressed_tab_end_offset_x := -120.0

var current_page_id := PAGE_HUB
var _hub_scene: Node = null
var _pages: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _is_turning := false
var _turn_effect: BookPageTurnEffect
var _transition_canvas: CanvasLayer = null
var _transition_stack_root: Control = null
var _transition_stack_records: Array[Dictionary] = []
var _transition_content_records: Array[Dictionary] = []
var _transition_hidden_background_records: Array[Dictionary] = []
var _persistent_stack_page_id := ""
var _compressed_stack_root: Control = null
var _compressed_stack_page_id := ""
var _hub_transition_body: Control = null
var _hub_transition_records: Array[Dictionary] = []
var _transition_tab_overlay: Control = null
var _transition_hidden_backgrounds: Array[Node] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	_setup_turn_visuals()
	_setup_tab_hotspots()
	if not resized.is_connected(_layout_navigation):
		resized.connect(_layout_navigation)
	call_deferred("_layout_navigation")


func configure(hub_scene: Node) -> void:
	_hub_scene = hub_scene
	current_page_id = PAGE_HUB
	_ensure_transition_canvas()
	_ensure_transition_stack_root()
	_ensure_compressed_stack_root()
	_ensure_hub_transition_body()
	_cleanup_realtime_transition_layers()
	_set_hub_page_visible(true)
	_sync_page_visibility()
	_layout_navigation()


func go_to_page(page_id: String) -> void:
	if not PAGE_STACK_Z.has(page_id):
		return
	if page_id == current_page_id or _is_turning:
		return
	_is_turning = true
	_hide_compressed_page_stack()
	var previous_page := current_page_id
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	visible = true
	_ensure_page(page_id)
	_prepare_target_visibility(page_id)
	var transition := _build_book_transition(previous_page, page_id)
	if not transition.is_empty():
		await _play_book_transition(transition)
		return
	await _play_direct_page_switch_transition(page_id)


func _build_book_transition(previous_page: String, page_id: String) -> Dictionary:
	var mode := _get_book_transition_mode(previous_page, page_id)
	if mode == "":
		return {}
	var transition := {
		"mode": mode,
		"from_page": previous_page,
		"to_page": page_id,
	}
	if mode == TRANSITION_PAGE_TO_PAGE:
		var direction := _get_page_to_page_transition_direction(previous_page, page_id)
		transition["page_to_page_direction"] = direction
	return transition


func _get_book_transition_mode(previous_page: String, page_id: String) -> String:
	if not PAGE_STACK_Z.has(previous_page) or not PAGE_STACK_Z.has(page_id):
		return ""
	if previous_page == page_id:
		return ""
	return TRANSITION_PAGE_TO_PAGE


func _get_page_to_page_transition_direction(previous_page: String, page_id: String) -> String:
	if int(PAGE_STACK_Z[page_id]) > int(PAGE_STACK_Z[previous_page]):
		return PAGE_TO_PAGE_EXPAND
	return PAGE_TO_PAGE_COMPRESS


func _play_book_transition(transition: Dictionary) -> void:
	var mode := str(transition.get("mode", ""))
	var page_id := str(transition.get("to_page", ""))
	if mode == TRANSITION_PAGE_TO_PAGE:
		await _play_page_to_page_transition(transition)
	else:
		await _play_direct_page_switch_transition(page_id)


func _play_page_to_page_transition(transition: Dictionary) -> void:
	var page_id := str(transition.get("to_page", ""))
	var previous_page := str(transition.get("from_page", current_page_id))
	_prepare_realtime_transition_layers(previous_page, page_id)
	if _transition_stack_records.is_empty():
		_cleanup_realtime_transition_layers()
		await _play_direct_page_switch_transition(page_id)
		return
	await _play_page_stack_transition()
	current_page_id = page_id
	_sync_compressed_page_stack()
	await get_tree().process_frame
	_cleanup_realtime_transition_layers()
	_finish_transition(true)

func _get_transition_layer(page_id: String) -> Control:
	if page_id == PAGE_HUB:
		return _get_hub_transition_visual_root()
	return _ensure_page(page_id) as Control


func _play_actual_page_layer_transition(previous_layer: Control, target_layer: Control, direction: String, _previous_page_id: String = "", target_page_id: String = "") -> void:
	var transition_rect := _get_page_transition_rect()
	_prepare_actual_page_layer_for_animation(previous_layer, transition_rect)
	_prepare_actual_page_layer_for_animation(target_layer, transition_rect)
	previous_layer.visible = true
	target_layer.visible = true
	previous_layer.set_process_input(false)
	previous_layer.set_process_unhandled_input(false)
	target_layer.set_process_input(false)
	target_layer.set_process_unhandled_input(false)
	_tween_transition_tabs_to_page(target_page_id)
	if direction == PAGE_TO_PAGE_EXPAND:
		previous_layer.z_index = TRANSITION_BACK_LAYER_Z
		target_layer.z_index = TRANSITION_FRONT_LAYER_Z
		_move_layer_to_draw_back(previous_layer)
		_move_layer_to_draw_front(target_layer)
		_set_actual_page_layer_progress(target_layer, 1.0)
		_set_actual_page_layer_progress(previous_layer, 0.0)
		await _tween_actual_page_layer_progress(target_layer, 0.0)
	else:
		previous_layer.z_index = TRANSITION_FRONT_LAYER_Z
		target_layer.z_index = TRANSITION_BACK_LAYER_Z
		_move_layer_to_draw_back(target_layer)
		_move_layer_to_draw_front(previous_layer)
		_set_actual_page_layer_progress(previous_layer, 0.0)
		_set_actual_page_layer_progress(target_layer, 0.0)
		await _tween_actual_page_layer_progress(previous_layer, 1.0)
	_reset_actual_page_layer(previous_layer)
	_reset_actual_page_layer(target_layer)


func _prepare_actual_page_layer_for_animation(layer: Control, transition_rect: Rect2) -> void:
	if layer == null:
		return
	layer.clip_contents = true
	layer.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	var rect := transition_rect
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		rect = Rect2(Vector2.ZERO, _get_transition_viewport_size())
	var global_scale := _get_node_global_scale(layer)
	layer.scale = Vector2.ONE
	layer.global_position = rect.position
	layer.size = Vector2(
		rect.size.x / global_scale.x,
		rect.size.y / global_scale.y
	)
	layer.pivot_offset = Vector2(layer.size.x, 0.0)
	layer.scale = Vector2.ONE


func _set_actual_page_layer_progress(layer: Control, progress: float) -> void:
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var scale_x := lerpf(1.0, layer_collapse_width_ratio, clamped_progress)
	layer.scale = Vector2(scale_x, 1.0)


func _tween_actual_page_layer_progress(layer: Control, target_progress: float) -> void:
	var target_scale := Vector2(lerpf(1.0, layer_collapse_width_ratio, clampf(target_progress, 0.0, 1.0)), 1.0)
	var tween := create_tween()
	tween.tween_property(layer, "scale", target_scale, hub_stretch_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _reset_actual_page_layer(layer: Control) -> void:
	layer.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	layer.position = Vector2.ZERO
	layer.scale = Vector2.ONE
	layer.pivot_offset = Vector2.ZERO
	layer.z_index = BookBackgroundConfig.PAGE_ROOT_Z_INDEX


func _move_layer_to_draw_front(layer: CanvasItem) -> void:
	if layer == null:
		return
	var parent := layer.get_parent()
	if parent != null:
		parent.move_child(layer, parent.get_child_count() - 1)


func _move_layer_to_draw_back(layer: CanvasItem) -> void:
	if layer == null:
		return
	var parent := layer.get_parent()
	if parent != null:
		parent.move_child(layer, 0)


func _play_direct_page_switch_transition(page_id: String) -> void:
	current_page_id = page_id
	_sync_page_visibility()
	await get_tree().process_frame
	_finish_transition()


func request_page(page_id: String) -> void:
	go_to_page(page_id)


func activate_tab_at_position(pointer_global_position: Vector2) -> bool:
	if not visible or current_page_id == PAGE_HUB or _is_turning:
		return false
	var target_page := _get_tab_button_page_at_position(pointer_global_position)
	if target_page == "":
		return false
	go_to_page(target_page)
	return true


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if not activate_tab_at_position(mouse_event.position):
		return
	get_viewport().set_input_as_handled()


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
	page.z_index = BookBackgroundConfig.PAGE_ROOT_Z_INDEX
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
		var hub_body := _ensure_hub_transition_body()
		if hub_body != null:
			hub_body.visible = false
			hub_body.set_process_input(false)
			hub_body.set_process_unhandled_input(false)
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
	_hide_hub_transition_body()
	visible = not hub_visible or _is_turning
	_layout_navigation()
	_sync_tab_buttons()
	_sync_suppressed_background_tabs()
	if _is_turning:
		_hide_compressed_page_stack()
	else:
		_sync_compressed_page_stack()


func _set_hub_page_visible(page_visible: bool) -> void:
	if _hub_scene == null or not is_instance_valid(_hub_scene):
		return
	if _hub_scene.has_method("set_book_hub_visible"):
		_hub_scene.set_book_hub_visible(page_visible)


func _finish_transition(_keep_hub_strip: bool = false) -> void:
	if _turn_effect != null:
		_turn_effect.finish_turn()
	_is_turning = false
	_sync_page_visibility()
	GlobalInput.set_context(GlobalInput.Context.WORLD if current_page_id == PAGE_HUB else GlobalInput.Context.UI)
	page_changed.emit(current_page_id)


func _setup_turn_visuals() -> void:
	_turn_effect = get_node_or_null("PageTurnEffect") as BookPageTurnEffect
	if _turn_effect != null:
		_turn_effect.visible = false
		_turn_effect.mouse_filter = Control.MOUSE_FILTER_STOP
		_turn_effect.z_index = BookBackgroundConfig.PAGE_TURN_EFFECT_Z_INDEX


func _setup_tab_hotspots() -> void:
	for page_id in BookBackgroundConfig.PAGE_ORDER:
		var button := get_node_or_null("%sTabButton" % str(page_id).capitalize()) as Button
		if button == null:
			push_warning("[BookPageNavigator] %sTabButton missing from hub_scene.tscn." % str(page_id).capitalize())
			continue
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.text = ""
		button.z_index = BookBackgroundConfig.NAV_TAB_BUTTON_Z_INDEX
		var page_callback := Callable(self, "go_to_page").bind(str(page_id))
		if not button.pressed.is_connected(page_callback):
			button.pressed.connect(page_callback)
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


func _get_tab_button_page_at_position(pointer_global_position: Vector2) -> String:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = DESIGN_SIZE
	for page_id in _tab_buttons.keys():
		if current_page_id == PAGE_HUB or str(page_id) == current_page_id or _is_turning:
			continue
		var visual_rect := _get_tab_hotspot_global_rect(str(page_id), viewport_size)
		if visual_rect.has_point(pointer_global_position):
			return str(page_id)
		var button := _tab_buttons[page_id] as Button
		if button != null and button.visible and not button.disabled and button.get_global_rect().has_point(pointer_global_position):
			return str(page_id)
	return ""


func _sync_suppressed_background_tabs() -> void:
	var suppressed_tabs := []
	for page_id in _pages.keys():
		var background := _get_book_background_for_page(str(page_id))
		if background == null or not background.has_method("set_suppressed_tab_page_ids"):
			continue
		background.call("set_suppressed_tab_page_ids", suppressed_tabs)


func _layout_navigation() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = DESIGN_SIZE
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_layout_transition_stack_root(viewport_size)
	_layout_compressed_stack_root(viewport_size)
	_layout_hub_transition_body(viewport_size)
	_layout_transition_tab_overlay(viewport_size)
	_layout_turn_visuals(viewport_size)
	_layout_tab_buttons(viewport_size)


func _apply_full_rect_offsets(control: Control) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_FULL_RECT, false)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _apply_top_left_rect(control: Control, rect_size: Vector2) -> void:
	if control == null:
		return
	if rect_size.x <= 0.0 or rect_size.y <= 0.0:
		rect_size = DESIGN_SIZE
	control.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	control.position = Vector2.ZERO
	control.size = rect_size


func _layout_turn_visuals(viewport_size: Vector2) -> void:
	if _turn_effect != null and not _turn_effect.visible:
		_turn_effect.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		_turn_effect.position = Vector2.ZERO
		_turn_effect.size = viewport_size


func _layout_tab_buttons(viewport_size: Vector2) -> void:
	for page_id in _tab_buttons.keys():
		var button := _tab_buttons[page_id] as Button
		if button == null:
			continue
		var rect := _get_tab_hotspot_global_rect(str(page_id), viewport_size)
		var inverse_transform := get_global_transform().affine_inverse()
		var local_position := inverse_transform * rect.position
		var local_end := inverse_transform * rect.end
		button.position = local_position
		button.size = local_end - local_position


func _get_tab_hotspot_global_rect(page_id: String, viewport_size: Vector2) -> Rect2:
	if current_page_id != PAGE_HUB and BookBackgroundConfig.should_place_tab_on_right(page_id, current_page_id):
		return _get_transition_page_tab_rect_as_global(page_id, 1.0)
	var background := _get_book_background_for_page(current_page_id) as Control
	if background != null:
		var tab_node_name := str(PAGE_TAB_NODE_NAMES.get(BookBackgroundConfig.normalize_page_id(page_id), ""))
		if tab_node_name != "":
			if BookBackgroundConfig.should_place_tab_on_right(page_id, current_page_id):
				tab_node_name += "Right"
			var tab := background.get_node_or_null(tab_node_name) as Control
			if tab != null:
				var tab_rect := tab.get_global_rect()
				if tab_rect.size.x > 1.0 and tab_rect.size.y > 1.0:
					return tab_rect
	var scale_factor := maxf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	var origin := (viewport_size - DESIGN_SIZE * scale_factor) * 0.5
	var fallback_rect := BookBackgroundConfig.get_tab_rect(page_id, current_page_id)
	return Rect2(origin + fallback_rect.position * scale_factor, fallback_rect.size * scale_factor)


func _get_transition_page_tab_rect_as_global(page_id: String, progress: float) -> Rect2:
	var viewport_rect := _get_design_rect_as_viewport(_get_transition_page_tab_rect(page_id, progress))
	var canvas_transform := get_global_transform()
	return Rect2(
		canvas_transform * viewport_rect.position,
		viewport_rect.size * canvas_transform.get_scale().abs()
	)


func _get_page_transition_rect() -> Rect2:
	return Rect2(Vector2.ZERO, _get_transition_viewport_size())


func _get_transition_viewport_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return DESIGN_SIZE
	return viewport_size


func _get_node_global_scale(node: CanvasItem) -> Vector2:
	if node == null:
		return Vector2.ONE
	var node_transform := node.get_global_transform()
	var node_scale := node_transform.get_scale()
	return Vector2(maxf(1e-6, abs(node_scale.x)), maxf(1e-6, abs(node_scale.y)))


func _get_book_background_for_page(page_id: String) -> Node:
	if page_id == PAGE_HUB:
		if _hub_scene != null and is_instance_valid(_hub_scene):
			var hub_background := _hub_scene.get_node_or_null("BookCanvasLayer/BookDesignRoot/BookBackground")
			if hub_background != null:
				return hub_background
		return _find_book_background(_hub_scene)
	if not _pages.has(page_id):
		return null
	return _find_book_background(_pages[page_id] as Node)


func _prepare_realtime_transition_layers(previous_page_id: String, target_page_id: String) -> void:
	_cleanup_realtime_transition_layers()
	_set_hub_page_visible(true)
	_prepare_hub_transition_body()
	_prepare_transition_page_stack(previous_page_id, target_page_id)


func _cleanup_realtime_transition_layers() -> void:
	_persistent_stack_page_id = ""
	_restore_transition_content_nodes()
	_restore_hub_transition_layers()
	_set_hub_transition_frozen(false)
	_restore_transition_hidden_background_visibility()
	_restore_transition_hidden_backgrounds()
	_hide_transition_tab_overlay()
	_hide_transition_stack_root()
	_hide_hub_transition_body()


func _ensure_transition_canvas() -> CanvasLayer:
	if _transition_canvas != null and is_instance_valid(_transition_canvas):
		return _transition_canvas
	var canvas := CanvasLayer.new()
	canvas.name = "BookRealtimeTransitionCanvas"
	canvas.layer = TRANSITION_CANVAS_LAYER
	add_child(canvas)
	_transition_canvas = canvas
	return _transition_canvas


func _ensure_transition_stack_root() -> Control:
	if _transition_stack_root != null and is_instance_valid(_transition_stack_root):
		return _transition_stack_root
	var canvas := _ensure_transition_canvas()
	if canvas == null:
		return null
	var root := Control.new()
	root.name = "BookRealtimeTransitionStack"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	root.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	canvas.add_child(root)
	_transition_stack_root = root
	_layout_transition_stack_root(_get_transition_viewport_size())
	return _transition_stack_root


func _layout_transition_stack_root(viewport_size: Vector2) -> void:
	if _transition_stack_root == null or not is_instance_valid(_transition_stack_root):
		return
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = DESIGN_SIZE
	_apply_full_rect_offsets(_transition_stack_root)


func _prepare_transition_page_stack(previous_page_id: String, target_page_id: String) -> void:
	var root := _ensure_transition_stack_root()
	if root == null:
		return
	_clear_transition_stack_root()
	root.visible = true
	_layout_transition_stack_root(_get_transition_viewport_size())
	_add_transition_book_base_art(root)
	var previous_index := _get_page_stack_index(previous_page_id)
	var target_index := _get_page_stack_index(target_page_id)
	if previous_index < 0 or target_index < 0:
		return
	for index in range(BookBackgroundConfig.PAGE_ORDER.size() - 1, -1, -1):
		var page_id := str(BookBackgroundConfig.PAGE_ORDER[index])
		var start_progress := 1.0 if index < previous_index else 0.0
		var end_progress := 1.0 if index < target_index else 0.0
		var page_z_index := _get_transition_page_layer_z_index(index)
		var sheet_layer := _create_transition_sheet_layer(page_z_index + TRANSITION_SHEET_LOCAL_Z)
		root.add_child(sheet_layer)
		_add_transition_page_sheet(sheet_layer, page_id)
		var content_layer: Control = null
		var content_node: Node = null
		if index <= maxi(previous_index, target_index):
			content_layer = _create_transition_content_layer(page_id, page_z_index + TRANSITION_CONTENT_LOCAL_Z)
			root.add_child(content_layer)
			content_node = _attach_actual_page_content(page_id, content_layer)
		var tab := _add_transition_page_tab(root, page_id, page_z_index + TRANSITION_TAB_LOCAL_Z)
		var record := {
			"page_id": page_id,
			"page_index": index,
			"sheet_layer": sheet_layer,
			"content_layer": content_layer,
			"content_node": content_node,
			"tab": tab,
			"start_progress": start_progress,
			"end_progress": end_progress,
		}
		_transition_stack_records.append(record)
		_apply_transition_page_record_progress(start_progress, record)
	_add_transition_back_tab(root)


func _create_transition_global_layer_root(parent: Control, layer_name: String, layer_z_index: int) -> Control:
	var root := Control.new()
	root.name = "Transition%sRoot" % layer_name
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = layer_z_index
	root.z_as_relative = true
	root.clip_contents = false
	_apply_top_left_rect(root, _get_transition_viewport_size())
	parent.add_child(root)
	return root


func _get_transition_page_layer_z_index(stack_index: int) -> int:
	return (BookBackgroundConfig.PAGE_ORDER.size() - stack_index) * TRANSITION_PAGE_Z_STEP


func _create_transition_page_layer(page_id: String, stack_index: int) -> Control:
	var layer := Control.new()
	layer.name = "%sTransitionPageLayer" % page_id.capitalize()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = (BookBackgroundConfig.PAGE_ORDER.size() - stack_index) * TRANSITION_PAGE_Z_STEP
	layer.z_as_relative = true
	layer.clip_contents = false
	_apply_top_left_rect(layer, _get_transition_viewport_size())
	return layer


func _create_transition_sheet_layer(page_z_index: int) -> Control:
	var layer := Control.new()
	layer.name = "SheetAndContent"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = page_z_index
	layer.z_as_relative = true
	layer.clip_contents = false
	_apply_top_left_rect(layer, _get_transition_viewport_size())
	layer.pivot_offset = Vector2(layer.size.x, 0.0)
	return layer


func _add_transition_page_sheet(sheet_layer: Control, page_id: String) -> void:
	if sheet_layer == null:
		return
	var source := _get_transition_page_sheet_source(page_id)
	_add_transition_texture_item(sheet_layer, "%sTransitionSheet" % page_id.capitalize(), source, TRANSITION_SHEET_LOCAL_Z)


func _add_transition_book_base_art(sheets_root: Control) -> void:
	if sheets_root == null:
		return
	var background := _get_any_transition_book_background()
	if background == null:
		return
	for node_name in BOOK_BASE_ART_NODE_NAMES:
		var source_node := background.get_node_or_null(str(node_name)) as TextureRect
		if source_node == null:
			continue
		var source := {
			"texture": source_node.texture,
			"rect": _get_texture_rect_visual_rect(source_node),
			"modulate": source_node.modulate,
		}
		_add_transition_texture_item(sheets_root, "%sTransitionBaseArt" % str(node_name), source, source_node.z_index)


func _add_transition_texture_item(parent: Control, item_name: String, source: Dictionary, item_z_index: int) -> void:
	if parent == null:
		return
	var texture := source.get("texture", null) as Texture2D
	if texture == null:
		return
	var sheet := TextureRect.new()
	sheet.name = item_name
	sheet.texture = texture
	sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sheet.stretch_mode = TextureRect.STRETCH_SCALE
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sheet_modulate := Color.WHITE
	var source_modulate = source.get("modulate", Color.WHITE)
	if source_modulate is Color:
		sheet_modulate = source_modulate
	sheet.modulate = sheet_modulate
	sheet.z_index = item_z_index
	var design_rect := Rect2(Vector2.ZERO, DESIGN_SIZE)
	var source_rect = source.get("rect", design_rect)
	if source_rect is Rect2:
		design_rect = source_rect
	var viewport_rect := _get_design_rect_as_viewport(design_rect)
	sheet.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	sheet.position = viewport_rect.position
	sheet.size = viewport_rect.size
	parent.add_child(sheet)


func _create_transition_content_layer(page_id: String, page_z_index: int) -> Control:
	var layer := Control.new()
	layer.name = "%sTransitionContent" % page_id.capitalize()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = page_z_index
	layer.z_as_relative = true
	layer.clip_contents = false
	_apply_top_left_rect(layer, _get_transition_viewport_size())
	layer.pivot_offset = Vector2(layer.size.x, 0.0)
	return layer


func _attach_actual_page_content(page_id: String, content_layer: Control) -> Node:
	if content_layer == null:
		return null
	var content_node := _get_actual_page_content_node(page_id)
	if content_node == null or not is_instance_valid(content_node):
		return null
	_transition_content_records.append(_capture_transition_node_record(content_node))
	content_node.reparent(content_layer, true)
	var canvas_item := content_node as CanvasItem
	if canvas_item != null:
		canvas_item.visible = true
	var control := content_node as Control
	if control != null:
		control.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		control.position = Vector2.ZERO
		control.size = _get_transition_viewport_size()
		control.scale = Vector2.ONE
		control.pivot_offset = Vector2.ZERO
		control.set_process_input(false)
		control.set_process_unhandled_input(false)
	_hide_transition_book_art_in_node(content_node)
	return content_node


func _get_actual_page_content_node(page_id: String) -> Node:
	if page_id == PAGE_HUB:
		return _get_hub_transition_visual_root()
	var page := _ensure_page(page_id)
	if page != null:
		page.visible = true
		page.set_process_input(false)
		page.set_process_unhandled_input(false)
	return page


func _add_transition_page_tab(tabs_root: Control, page_id: String, page_z_index: int) -> TextureRect:
	if tabs_root == null:
		return null
	var texture := _get_tab_texture(page_id)
	if texture == null:
		return null
	var tab := TextureRect.new()
	tab.name = "%sTransitionTab" % page_id.capitalize()
	tab.texture = texture
	tab.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tab.stretch_mode = TextureRect.STRETCH_SCALE
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.z_index = page_z_index + TRANSITION_TAB_LOCAL_Z
	tab.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	tabs_root.add_child(tab)
	return tab


func _add_transition_back_tab(root: Control) -> void:
	if root == null:
		return
	var texture := _get_tab_texture("back")
	if texture == null:
		return
	var back_tab := TextureRect.new()
	back_tab.name = "BackTransitionTab"
	back_tab.texture = texture
	back_tab.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back_tab.stretch_mode = TextureRect.STRETCH_SCALE
	back_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_tab.z_index = TRANSITION_BACK_TAB_Z
	var rect := _get_design_rect_as_viewport(BookBackgroundConfig.get_back_tab_rect())
	back_tab.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	back_tab.position = rect.position
	back_tab.size = rect.size
	root.add_child(back_tab)


func _play_page_stack_transition() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var has_moving_page := false
	for record in _transition_stack_records:
		var start_progress := float(record.get("start_progress", 0.0))
		var end_progress := float(record.get("end_progress", 0.0))
		if absf(start_progress - end_progress) <= 0.001:
			continue
		has_moving_page = true
		tween.tween_method(
			Callable(self, "_apply_transition_page_record_progress").bind(record),
			start_progress,
			end_progress,
			hub_stretch_duration
		)
	if has_moving_page:
		await tween.finished
	else:
		tween.kill()
		await get_tree().process_frame


func _finalize_persistent_page_stack(page_id: String) -> void:
	_persistent_stack_page_id = page_id
	if _transition_stack_root != null and is_instance_valid(_transition_stack_root):
		_transition_stack_root.visible = true
	var active_index := _get_page_stack_index(page_id)
	for record in _transition_stack_records:
		var page_index := int(record.get("page_index", -1))
		var final_progress := 1.0 if page_index < active_index else 0.0
		_apply_transition_page_record_progress(final_progress, record)
		_sync_persistent_record_visibility(record, active_index)
	_hide_transition_tab_overlay()
	_sync_persistent_page_stack_visibility()


func _is_persistent_page_stack_active() -> bool:
	return (
		_persistent_stack_page_id != ""
		and _transition_stack_root != null
		and is_instance_valid(_transition_stack_root)
		and not _transition_stack_records.is_empty()
	)


func _sync_persistent_page_stack_visibility() -> void:
	var active_index := _get_page_stack_index(current_page_id)
	if active_index <= 0:
		return
	if _transition_canvas != null and is_instance_valid(_transition_canvas):
		_transition_canvas.layer = TRANSITION_CANVAS_LAYER
	if _transition_stack_root != null and is_instance_valid(_transition_stack_root):
		_transition_stack_root.visible = true
	for record in _transition_stack_records:
		_sync_persistent_record_visibility(record, active_index)
	for page_id in _pages.keys():
		var page := _pages[page_id] as Control
		if page == null:
			continue
		var page_index := _get_page_stack_index(str(page_id))
		var page_visible := page_index >= 0 and page_index <= active_index
		var page_active := str(page_id) == current_page_id
		page.visible = page_visible
		page.set_process_input(page_active)
		page.set_process_unhandled_input(page_active)
	if _hub_transition_body != null and is_instance_valid(_hub_transition_body):
		_hub_transition_body.visible = active_index > 0
		_hub_transition_body.set_process_input(false)
		_hub_transition_body.set_process_unhandled_input(false)
	visible = true
	_layout_navigation()
	for record in _transition_stack_records:
		var page_index := int(record.get("page_index", -1))
		var final_progress := 1.0 if page_index < active_index else 0.0
		_apply_transition_page_record_progress(final_progress, record)
		_sync_persistent_record_visibility(record, active_index)
	_sync_tab_buttons()
	_sync_suppressed_background_tabs()


func _sync_persistent_record_visibility(record: Dictionary, active_index: int) -> void:
	var page_id := str(record.get("page_id", ""))
	var page_index := int(record.get("page_index", -1))
	var visible_in_stack := page_index >= 0 and page_index <= active_index
	var sheet_layer := record.get("sheet_layer", null) as Control
	if sheet_layer != null:
		sheet_layer.visible = visible_in_stack
	var tab := record.get("tab", null) as Control
	if tab != null:
		tab.visible = visible_in_stack
	var content_layer := record.get("content_layer", null) as Control
	if content_layer != null:
		content_layer.visible = visible_in_stack
	var content_node := record.get("content_node", null) as Node
	var canvas_item := content_node as CanvasItem
	if canvas_item != null:
		canvas_item.visible = visible_in_stack
	var control := content_node as Control
	if control != null:
		var is_active_page := page_id == current_page_id
		control.set_process_input(is_active_page)
		control.set_process_unhandled_input(is_active_page)


func _apply_transition_page_record_progress(progress: float, record: Dictionary) -> void:
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var page_id := str(record.get("page_id", ""))
	var sheet_layer := record.get("sheet_layer", null) as Control
	if sheet_layer != null:
		_prepare_transition_page_layer_for_progress(sheet_layer, page_id)
		_set_actual_page_layer_progress(sheet_layer, clamped_progress)
	var content_layer := record.get("content_layer", null) as Control
	if content_layer != null:
		_prepare_transition_page_layer_for_progress(content_layer, page_id)
		_set_actual_page_layer_progress(content_layer, clamped_progress)
	var tab := record.get("tab", null) as Control
	if tab != null:
		var tab_rect := _get_transition_page_tab_rect(page_id, clamped_progress)
		var viewport_rect := _get_design_rect_as_viewport(tab_rect)
		tab.position = viewport_rect.position
		tab.size = viewport_rect.size


func _prepare_transition_page_layer_for_progress(layer: Control, page_id: String) -> void:
	_prepare_actual_page_layer_for_animation(layer, _get_page_transition_rect())
	layer.pivot_offset = Vector2(_get_transition_page_pivot_x(page_id), 0.0)


func _get_transition_page_pivot_x(page_id: String) -> float:
	var source: Dictionary = _get_transition_page_sheet_source(page_id)
	var source_rect: Rect2 = source.get("rect", Rect2(Vector2.ZERO, DESIGN_SIZE))
	var viewport_rect := _get_design_rect_as_viewport(source_rect)
	return viewport_rect.end.x


func _get_transition_page_tab_rect(page_id: String, progress: float) -> Rect2:
	var left_rect := BookBackgroundConfig.get_tab_rect(page_id, PAGE_HUB)
	var right_rect := BookBackgroundConfig.get_tab_rect(page_id, _get_bottom_page_id())
	var clamped_progress := _get_tab_motion_progress(left_rect, right_rect, progress)
	var end_offset := Vector2(compressed_tab_end_offset_x * clampf(progress, 0.0, 1.0), 0.0)
	return Rect2(
		left_rect.position.lerp(right_rect.position + end_offset, clamped_progress),
		left_rect.size.lerp(right_rect.size, clamped_progress)
	)


func _get_tab_motion_progress(left_rect: Rect2, right_rect: Rect2, page_progress: float) -> float:
	var page_scale := lerpf(1.0, layer_collapse_width_ratio, clampf(page_progress, 0.0, 1.0))
	var source_distance_to_pivot := maxf(1.0, DESIGN_SIZE.x - left_rect.position.x)
	var target_distance_to_pivot := maxf(0.0, DESIGN_SIZE.x - right_rect.position.x)
	var target_scale := clampf(target_distance_to_pivot / source_distance_to_pivot, layer_collapse_width_ratio, 1.0)
	var target_motion := 1.0 - target_scale
	if target_motion <= 0.001:
		return clampf(page_progress, 0.0, 1.0)
	return clampf((1.0 - page_scale) / target_motion, 0.0, 1.0)


func _get_transition_page_sheet_source(page_id: String) -> Dictionary:
	var sheet_name := str(PAGE_SHEET_NODE_NAMES.get(BookBackgroundConfig.normalize_page_id(page_id), ""))
	var background := _get_any_transition_book_background()
	var sheet: TextureRect = null
	if background != null and sheet_name != "":
		sheet = background.get_node_or_null(sheet_name) as TextureRect
	if sheet == null:
		return {
			"texture": null,
			"rect": Rect2(Vector2.ZERO, DESIGN_SIZE),
			"modulate": Color.WHITE,
		}
	return {
		"texture": sheet.texture,
		"rect": _get_texture_rect_visual_rect(sheet),
		"modulate": sheet.modulate,
	}


func _get_texture_rect_visual_rect(texture_rect: TextureRect) -> Rect2:
	if texture_rect == null:
		return Rect2(Vector2.ZERO, DESIGN_SIZE)
	return Rect2(texture_rect.position, texture_rect.size * texture_rect.scale.abs())


func _get_any_transition_book_background() -> Node:
	if _hub_transition_body != null and is_instance_valid(_hub_transition_body):
		var hub_body_background := _find_book_background(_hub_transition_body)
		if hub_body_background != null:
			return hub_body_background
	var hub_background := _get_book_background_for_page(PAGE_HUB)
	if hub_background != null:
		return hub_background
	for page_id in _pages.keys():
		var background := _get_book_background_for_page(str(page_id))
		if background != null:
			return background
	return null


func _get_page_stack_index(page_id: String) -> int:
	return BookBackgroundConfig.PAGE_ORDER.find(BookBackgroundConfig.normalize_page_id(page_id))


func _get_bottom_page_id() -> String:
	if BookBackgroundConfig.PAGE_ORDER.is_empty():
		return PAGE_SETTINGS
	return str(BookBackgroundConfig.PAGE_ORDER[BookBackgroundConfig.PAGE_ORDER.size() - 1])


func _clear_transition_stack_root() -> void:
	_transition_stack_records.clear()
	if _transition_stack_root == null or not is_instance_valid(_transition_stack_root):
		return
	for child in _transition_stack_root.get_children():
		_transition_stack_root.remove_child(child)
		child.queue_free()


func _hide_transition_stack_root() -> void:
	_clear_transition_stack_root()
	if _transition_stack_root == null or not is_instance_valid(_transition_stack_root):
		return
	_transition_stack_root.visible = false


func _ensure_compressed_stack_root() -> Control:
	if _compressed_stack_root != null and is_instance_valid(_compressed_stack_root):
		return _compressed_stack_root
	var canvas := _ensure_transition_canvas()
	if canvas == null:
		return null
	var root := Control.new()
	root.name = "RightCompressedStackRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	root.z_index = TRANSITION_BACK_LAYER_Z
	root.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	canvas.add_child(root)
	_compressed_stack_root = root
	_layout_compressed_stack_root(_get_transition_viewport_size())
	return _compressed_stack_root


func _layout_compressed_stack_root(viewport_size: Vector2) -> void:
	if _compressed_stack_root == null or not is_instance_valid(_compressed_stack_root):
		return
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = DESIGN_SIZE
	_apply_full_rect_offsets(_compressed_stack_root)


func _sync_compressed_page_stack() -> void:
	var active_index := _get_page_stack_index(current_page_id)
	if current_page_id == PAGE_HUB or active_index <= 0:
		_hide_compressed_page_stack()
		return
	var root := _ensure_compressed_stack_root()
	if root == null:
		return
	if _compressed_stack_page_id == current_page_id and root.visible:
		return
	_clear_compressed_page_stack()
	_compressed_stack_page_id = current_page_id
	root.visible = true
	_layout_compressed_stack_root(_get_transition_viewport_size())
	for index in range(active_index - 1, -1, -1):
		var page_id := str(BookBackgroundConfig.PAGE_ORDER[index])
		var page_z := (active_index - index) * TRANSITION_PAGE_Z_STEP
		_add_compressed_page_stack_item(root, page_id, page_z, page_id == PAGE_HUB)


func _hide_compressed_page_stack() -> void:
	_clear_compressed_page_stack()
	_compressed_stack_page_id = ""
	if _compressed_stack_root == null or not is_instance_valid(_compressed_stack_root):
		return
	_compressed_stack_root.visible = false


func _clear_compressed_page_stack() -> void:
	if _compressed_stack_root == null or not is_instance_valid(_compressed_stack_root):
		return
	for child in _compressed_stack_root.get_children():
		_compressed_stack_root.remove_child(child)
		child.queue_free()


func _add_compressed_page_stack_item(root: Control, page_id: String, page_z: int, show_content: bool = true) -> void:
	var sheet_layer := Control.new()
	sheet_layer.name = "%sCompressedSheetLayer" % page_id.capitalize()
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet_layer.z_index = page_z + TRANSITION_SHEET_LOCAL_Z
	root.add_child(sheet_layer)
	_add_compressed_page_sheet(sheet_layer, page_id)

	var tab := _create_compressed_page_tab(page_id)
	if tab != null:
		tab.z_index = page_z + TRANSITION_TAB_LOCAL_Z
		root.add_child(tab)

	var content_layer := Control.new()
	content_layer.visible = show_content
	content_layer.name = "%sCompressedContentLayer" % page_id.capitalize()
	content_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_layer.z_index = page_z + TRANSITION_CONTENT_LOCAL_Z
	root.add_child(content_layer)
	var content_node := _create_compressed_page_content(page_id)
	if content_node != null:
		content_layer.add_child(content_node)
		_prepare_compressed_page_content_node(content_node)

	_apply_transition_page_record_progress(1.0, {
		"page_id": page_id,
		"sheet_layer": sheet_layer,
		"content_layer": content_layer,
		"tab": tab,
	})


func _add_compressed_page_sheet(parent: Control, page_id: String) -> void:
	var source: Dictionary = _get_transition_page_sheet_source(page_id)
	var texture := source.get("texture", null) as Texture2D
	if texture == null:
		return
	var source_rect: Rect2 = source.get("rect", Rect2(Vector2.ZERO, DESIGN_SIZE))
	var source_modulate: Color = source.get("modulate", Color.WHITE)
	var viewport_rect := _get_design_rect_as_viewport(source_rect)
	var sheet := TextureRect.new()
	sheet.name = "%sCompressedSheet" % page_id.capitalize()
	sheet.texture = texture
	sheet.modulate = source_modulate
	sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sheet.stretch_mode = TextureRect.STRETCH_SCALE
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.position = viewport_rect.position
	sheet.size = viewport_rect.size
	parent.add_child(sheet)


func _create_compressed_page_tab(page_id: String) -> TextureRect:
	var texture := _get_tab_texture(page_id)
	if texture == null:
		return null
	var tab_rect := _get_transition_page_tab_rect(page_id, 1.0)
	var viewport_rect := _get_design_rect_as_viewport(tab_rect)
	var tab := TextureRect.new()
	tab.name = "%sCompressedTab" % page_id.capitalize()
	tab.texture = texture
	tab.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tab.stretch_mode = TextureRect.STRETCH_SCALE
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.position = viewport_rect.position
	tab.size = viewport_rect.size
	return tab


func _create_compressed_page_content(page_id: String) -> Node:
	if page_id == PAGE_HUB:
		return _create_compressed_hub_content()
	var scene_path := str(PAGE_SCENE_PATHS.get(page_id, ""))
	if scene_path == "":
		return null
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return null
	var page := packed.instantiate() as Control
	if page == null:
		return null
	page.name = "%sCompressedContent" % page_id.capitalize()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.visible = true
	return page


func _create_compressed_hub_content() -> Control:
	var container := _create_hub_page_visual_root("HubCompressedVisualRoot")
	var layers: Array = []
	var active_hub_content := _get_active_hub_transition_content_node()
	if active_hub_content != null:
		layers.append(active_hub_content)
	elif _hub_scene != null and is_instance_valid(_hub_scene) and _hub_scene.has_method("get_book_hub_transition_layer"):
		var hub_layer := _hub_scene.call("get_book_hub_transition_layer") as Node
		if hub_layer != null:
			layers.append(hub_layer)
	elif _hub_scene != null and is_instance_valid(_hub_scene) and _hub_scene.has_method("get_book_hub_transition_layers"):
		layers = _hub_scene.call("get_book_hub_transition_layers")
	if layers.is_empty() and _hub_scene != null and is_instance_valid(_hub_scene):
		layers = [
			_hub_scene.get_node_or_null("BookCanvasLayer/BookDesignRoot"),
			_hub_scene.get_node_or_null("HubArt"),
			_hub_scene.get_node_or_null("Player"),
		]
	for layer in layers:
		var source := layer as Node
		if source == null or not is_instance_valid(source):
			continue
		var clone := source.duplicate()
		if clone == null:
			continue
		_prepare_compressed_hub_clone(clone)
		container.add_child(clone)
	return container


func _get_active_hub_transition_content_node() -> Node:
	for record in _transition_stack_records:
		if str(record.get("page_id", "")) != PAGE_HUB:
			continue
		var content_node := record.get("content_node", null) as Node
		if content_node != null and is_instance_valid(content_node):
			return content_node
	return null


func _prepare_compressed_hub_clone(clone: Node) -> void:
	var canvas_item := clone as CanvasItem
	if canvas_item != null:
		canvas_item.visible = true
	var control := clone as Control
	if control != null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip_compressed_hub_player_to_board(clone)


func _clip_compressed_hub_player_to_board(root: Node) -> void:
	var player := root.get_node_or_null("Player") as Node2D
	var board_content := root.get_node_or_null("HubArt/BoardViewport/BoardContent") as CanvasItem
	if player == null or board_content == null:
		return
	var player_global_transform := player.get_global_transform()
	player.reparent(board_content, false)
	player.transform = board_content.get_global_transform().affine_inverse() * player_global_transform


func _prepare_compressed_page_content_node(content_node: Node) -> void:
	var viewport_size := _get_transition_viewport_size()
	var control := content_node as Control
	if control != null:
		control.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		control.position = Vector2.ZERO
		control.size = viewport_size
	var canvas_item := content_node as CanvasItem
	if canvas_item != null:
		canvas_item.visible = true
	_hide_compressed_book_art_in_node(content_node)
	_disable_compressed_page_interaction(content_node)


func _hide_compressed_book_art_in_node(root: Node) -> void:
	var background := _find_book_background(root)
	if background == null:
		return
	if background.has_method("set_transition_tabs_hidden"):
		background.call("set_transition_tabs_hidden", true)
	for node_name in BOOK_BASE_ART_NODE_NAMES:
		var base_item := background.get_node_or_null(str(node_name)) as CanvasItem
		if base_item != null:
			base_item.visible = false
	for sheet_name in PAGE_SHEET_NODE_NAMES.values():
		var sheet := background.get_node_or_null(str(sheet_name)) as CanvasItem
		if sheet != null:
			sheet.visible = false


func _disable_compressed_page_interaction(root: Node) -> void:
	root.set_process(false)
	root.set_physics_process(false)
	root.set_process_input(false)
	root.set_process_unhandled_input(false)
	var control := root as Control
	if control != null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button := root as BaseButton
	if button != null:
		button.disabled = true
	for child in root.get_children():
		_disable_compressed_page_interaction(child)


func _ensure_hub_transition_body() -> Control:
	if _hub_transition_body != null and is_instance_valid(_hub_transition_body):
		return _hub_transition_body
	var canvas := _ensure_transition_canvas()
	if canvas == null:
		return null
	var body := Control.new()
	body.name = "HubTransitionBody"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.clip_contents = true
	body.visible = false
	body.z_index = TRANSITION_BACK_LAYER_Z
	body.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	canvas.add_child(body)
	_hub_transition_body = body
	_layout_hub_transition_body(_get_transition_viewport_size())
	return _hub_transition_body


func _layout_hub_transition_body(viewport_size: Vector2) -> void:
	if _hub_transition_body == null or not is_instance_valid(_hub_transition_body):
		return
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = DESIGN_SIZE
	_apply_full_rect_offsets(_hub_transition_body)
	_hub_transition_body.pivot_offset = Vector2(viewport_size.x, 0.0)


func _prepare_hub_transition_body() -> void:
	var body := _ensure_hub_transition_body()
	if body == null or _hub_scene == null or not is_instance_valid(_hub_scene):
		return
	_set_hub_transition_frozen(true)
	_layout_hub_transition_body(_get_transition_viewport_size())
	body.visible = true
	body.set_process_input(false)
	body.set_process_unhandled_input(false)
	_clear_hub_transition_body_visual_roots()
	var visual_root := _create_hub_page_visual_root("HubTransitionVisualRoot")
	body.add_child(visual_root)
	var layers: Array = []
	if _hub_scene.has_method("get_book_hub_transition_layer"):
		var hub_layer := _hub_scene.call("get_book_hub_transition_layer") as Node
		if hub_layer != null:
			layers.append(hub_layer)
	elif _hub_scene.has_method("get_book_hub_transition_layers"):
		layers = _hub_scene.call("get_book_hub_transition_layers")
	if layers.is_empty():
		layers = [
			_hub_scene.get_node_or_null("BookCanvasLayer/BookDesignRoot"),
			_hub_scene.get_node_or_null("HubArt"),
			_hub_scene.get_node_or_null("Player"),
		]
	for layer in layers:
		var node := layer as Node
		if node == null or not is_instance_valid(node):
			continue
		var parent := node.get_parent()
		if parent == null:
			continue
		_hub_transition_records.append(_capture_transition_node_record(node))
		node.reparent(visual_root, true)
		_prepare_hub_transition_visual_node(node)


func _set_hub_transition_frozen(frozen: bool) -> void:
	if _hub_scene == null or not is_instance_valid(_hub_scene):
		return
	if not _hub_scene.has_method("set_book_hub_transition_frozen"):
		return
	_hub_scene.call("set_book_hub_transition_frozen", frozen)


func _create_hub_page_visual_root(root_name: String) -> Control:
	var root := Control.new()
	root.name = root_name
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.clip_contents = false
	root.visible = true
	_apply_top_left_rect(root, _get_transition_viewport_size())
	return root


func _prepare_hub_transition_visual_node(node: Node) -> void:
	var canvas_item := node as CanvasItem
	if canvas_item != null:
		canvas_item.visible = true
	var control := node as Control
	if control != null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.set_process_input(false)
		control.set_process_unhandled_input(false)


func _get_hub_transition_visual_root() -> Control:
	if _hub_transition_body == null or not is_instance_valid(_hub_transition_body):
		return _ensure_hub_transition_body()
	var visual_root := _hub_transition_body.get_node_or_null("HubTransitionVisualRoot") as Control
	if visual_root != null:
		var hub_page_root := visual_root.get_node_or_null("HubPageVisualRoot") as Control
		if hub_page_root != null:
			return hub_page_root
		return visual_root
	return _hub_transition_body


func _clear_hub_transition_body_visual_roots() -> void:
	if not _hub_transition_records.is_empty():
		return
	if _hub_transition_body == null or not is_instance_valid(_hub_transition_body):
		return
	for child in _hub_transition_body.get_children():
		if child.name != "HubTransitionVisualRoot":
			continue
		_hub_transition_body.remove_child(child)
		child.queue_free()


func _capture_transition_node_record(node: Node) -> Dictionary:
	var record := {
		"node": node,
		"parent": node.get_parent(),
		"index": node.get_index(),
	}
	var canvas_item := node as CanvasItem
	if canvas_item != null:
		record["visible"] = canvas_item.visible
		record["z_index"] = canvas_item.z_index
	var control := node as Control
	if control != null:
		record["position"] = control.position
		record["scale"] = control.scale
		record["rotation"] = control.rotation
		record["size"] = control.size
		record["pivot_offset"] = control.pivot_offset
		record["anchor_left"] = control.anchor_left
		record["anchor_top"] = control.anchor_top
		record["anchor_right"] = control.anchor_right
		record["anchor_bottom"] = control.anchor_bottom
		record["offset_left"] = control.offset_left
		record["offset_top"] = control.offset_top
		record["offset_right"] = control.offset_right
		record["offset_bottom"] = control.offset_bottom
		return record
	var node_2d := node as Node2D
	if node_2d != null:
		record["position"] = node_2d.position
		record["scale"] = node_2d.scale
		record["rotation"] = node_2d.rotation
	return record


func _restore_hub_transition_layers() -> void:
	for record in _hub_transition_records:
		var node := record.get("node", null) as Node
		var parent := record.get("parent", null) as Node
		if node == null or parent == null or not is_instance_valid(node) or not is_instance_valid(parent):
			continue
		node.reparent(parent, false)
		var target_index := clampi(int(record.get("index", node.get_index())), 0, max(0, parent.get_child_count() - 1))
		parent.move_child(node, target_index)
		_restore_transition_node_record(node, record)
	_hub_transition_records.clear()
	_clear_hub_transition_body_visual_roots()


func _restore_transition_content_nodes() -> void:
	for record in _transition_content_records:
		var node := record.get("node", null) as Node
		var parent := record.get("parent", null) as Node
		if node == null or parent == null or not is_instance_valid(node) or not is_instance_valid(parent):
			continue
		node.reparent(parent, false)
		var target_index := clampi(int(record.get("index", node.get_index())), 0, max(0, parent.get_child_count() - 1))
		parent.move_child(node, target_index)
		_restore_transition_node_record(node, record)
	_transition_content_records.clear()


func _restore_transition_node_record(node: Node, record: Dictionary) -> void:
	var canvas_item := node as CanvasItem
	if canvas_item != null:
		canvas_item.visible = bool(record.get("visible", canvas_item.visible))
		canvas_item.z_index = int(record.get("z_index", canvas_item.z_index))
	var control := node as Control
	if control != null:
		control.anchor_left = float(record.get("anchor_left", control.anchor_left))
		control.anchor_top = float(record.get("anchor_top", control.anchor_top))
		control.anchor_right = float(record.get("anchor_right", control.anchor_right))
		control.anchor_bottom = float(record.get("anchor_bottom", control.anchor_bottom))
		control.offset_left = float(record.get("offset_left", control.offset_left))
		control.offset_top = float(record.get("offset_top", control.offset_top))
		control.offset_right = float(record.get("offset_right", control.offset_right))
		control.offset_bottom = float(record.get("offset_bottom", control.offset_bottom))
		control.position = record.get("position", control.position)
		control.scale = record.get("scale", control.scale)
		control.rotation = float(record.get("rotation", control.rotation))
		control.size = record.get("size", control.size)
		control.pivot_offset = record.get("pivot_offset", control.pivot_offset)
		return
	var node_2d := node as Node2D
	if node_2d != null:
		node_2d.position = record.get("position", node_2d.position)
		node_2d.scale = record.get("scale", node_2d.scale)
		node_2d.rotation = float(record.get("rotation", node_2d.rotation))


func _hide_transition_background_in_node(root: Node) -> void:
	var background := _find_book_background(root) as CanvasItem
	if background == null:
		return
	if not _is_transition_background_visibility_recorded(background):
		_transition_hidden_background_records.append({
			"node": background,
			"visible": background.visible,
		})
	background.visible = false


func _hide_transition_tabs_in_node(root: Node) -> void:
	var background := _find_book_background(root)
	if background == null or not background.has_method("set_transition_tabs_hidden"):
		return
	if not _transition_hidden_backgrounds.has(background):
		_transition_hidden_backgrounds.append(background)
	background.call("set_transition_tabs_hidden", true)


func _hide_transition_book_art_in_node(root: Node) -> void:
	var background := _find_book_background(root)
	if background == null:
		return
	if background.has_method("set_transition_tabs_hidden"):
		if not _transition_hidden_backgrounds.has(background):
			_transition_hidden_backgrounds.append(background)
		background.call("set_transition_tabs_hidden", true)
	for node_name in BOOK_BASE_ART_NODE_NAMES:
		var base_item := background.get_node_or_null(str(node_name)) as CanvasItem
		_hide_transition_canvas_item_temporarily(base_item)
	for sheet_name in PAGE_SHEET_NODE_NAMES.values():
		var sheet := background.get_node_or_null(str(sheet_name)) as CanvasItem
		_hide_transition_canvas_item_temporarily(sheet)


func _hide_transition_canvas_item_temporarily(item: CanvasItem) -> void:
	if item == null:
		return
	if not _is_transition_background_visibility_recorded(item):
		_transition_hidden_background_records.append({
			"node": item,
			"visible": item.visible,
		})
	item.visible = false


func _is_transition_background_visibility_recorded(background: CanvasItem) -> bool:
	for record in _transition_hidden_background_records:
		if record.get("node", null) == background:
			return true
	return false


func _restore_transition_hidden_background_visibility() -> void:
	for record in _transition_hidden_background_records:
		var background := record.get("node", null) as CanvasItem
		if background != null and is_instance_valid(background):
			background.visible = bool(record.get("visible", background.visible))
	_transition_hidden_background_records.clear()


func _hide_hub_transition_body() -> void:
	if _hub_transition_body == null or not is_instance_valid(_hub_transition_body):
		return
	if not _hub_transition_records.is_empty():
		return
	_hub_transition_body.visible = false
	_hub_transition_body.set_process_input(false)
	_hub_transition_body.set_process_unhandled_input(false)


func _ensure_transition_tab_overlay() -> Control:
	if _transition_tab_overlay != null and is_instance_valid(_transition_tab_overlay):
		return _transition_tab_overlay
	var canvas := _ensure_transition_canvas()
	if canvas == null:
		return null
	var overlay := Control.new()
	overlay.name = "TransitionTabOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	overlay.z_index = TRANSITION_FRONT_LAYER_Z
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	canvas.add_child(overlay)
	_transition_tab_overlay = overlay
	_layout_transition_tab_overlay(_get_transition_viewport_size())
	return _transition_tab_overlay


func _layout_transition_tab_overlay(viewport_size: Vector2) -> void:
	if _transition_tab_overlay == null or not is_instance_valid(_transition_tab_overlay):
		return
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = DESIGN_SIZE
	_apply_full_rect_offsets(_transition_tab_overlay)


func _prepare_transition_tab_overlay(previous_page_id: String, target_page_id: String) -> void:
	var overlay := _ensure_transition_tab_overlay()
	if overlay == null:
		return
	_clear_transition_tab_overlay()
	overlay.visible = true
	_layout_transition_tab_overlay(_get_transition_viewport_size())
	if _should_draw_transition_back_tab(previous_page_id):
		_add_transition_tab_item("back", _get_tab_texture("back"), BookBackgroundConfig.get_back_tab_rect(), BookBackgroundConfig.get_back_tab_z_index())
	for page_id in BookBackgroundConfig.PAGE_ORDER:
		if not _should_draw_transition_tab(str(page_id), previous_page_id, target_page_id):
			continue
		_add_transition_tab_item(
			str(page_id),
			_get_tab_texture(str(page_id)),
			BookBackgroundConfig.get_tab_rect(str(page_id), previous_page_id),
			_get_transition_tab_z_index(str(page_id), previous_page_id)
		)


func _add_transition_tab_item(item_name: String, texture: Texture2D, source_design_rect: Rect2, source_z_index: int) -> void:
	if texture == null or _transition_tab_overlay == null:
		return
	var item := TextureRect.new()
	item.name = "%sTransitionTab" % item_name.capitalize()
	item.texture = texture
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_SCALE
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.z_index = source_z_index
	var source_rect := _get_design_rect_as_viewport(source_design_rect)
	item.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	item.position = source_rect.position
	item.size = source_rect.size
	_transition_tab_overlay.add_child(item)


func _tween_transition_tabs_to_page(_target_page_id: String) -> void:
	return


func _get_transition_tab_z_index(page_id: String, active_page_id: String) -> int:
	if BookBackgroundConfig.should_place_tab_on_right(page_id, active_page_id):
		return BookBackgroundConfig.get_right_tab_z_index()
	return BookBackgroundConfig.get_tab_z_index(page_id, active_page_id)


func _should_draw_transition_back_tab(_previous_page_id: String) -> bool:
	return true


func _should_draw_transition_tab(_page_id: String, _previous_page_id: String, _target_page_id: String) -> bool:
	return true


func _get_tab_texture(page_id: String) -> Texture2D:
	var texture_path := BACK_TAB_TEXTURE_PATH if page_id == "back" else str(PAGE_TAB_TEXTURE_PATHS.get(BookBackgroundConfig.normalize_page_id(page_id), ""))
	if texture_path == "":
		return null
	return load(texture_path) as Texture2D


func _get_design_rect_as_viewport(rect: Rect2) -> Rect2:
	var viewport_size := _get_transition_viewport_size()
	var scale_factor := maxf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	var origin := (viewport_size - DESIGN_SIZE * scale_factor) * 0.5
	return Rect2(origin + rect.position * scale_factor, rect.size * scale_factor)


func _clear_transition_tab_overlay() -> void:
	if _transition_tab_overlay == null or not is_instance_valid(_transition_tab_overlay):
		return
	for child in _transition_tab_overlay.get_children():
		child.queue_free()


func _hide_transition_tab_overlay() -> void:
	if _transition_tab_overlay == null or not is_instance_valid(_transition_tab_overlay):
		return
	_clear_transition_tab_overlay()
	_transition_tab_overlay.visible = false


func _set_transition_tabs_hidden_for_page(page_id: String, tabs_hidden: bool) -> void:
	var background := _get_book_background_for_page(page_id)
	if background == null or not background.has_method("set_transition_tabs_hidden"):
		return
	if tabs_hidden and not _transition_hidden_backgrounds.has(background):
		_transition_hidden_backgrounds.append(background)
	background.call("set_transition_tabs_hidden", tabs_hidden)


func _restore_transition_hidden_backgrounds() -> void:
	for background in _transition_hidden_backgrounds:
		if background != null and is_instance_valid(background) and background.has_method("set_transition_tabs_hidden"):
			background.call("set_transition_tabs_hidden", false)
	_transition_hidden_backgrounds.clear()


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
