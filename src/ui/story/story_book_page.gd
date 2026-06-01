extends Control

const DesignScaler = preload("res://src/ui/layout/ui_design_scaler.gd")

const DESIGN_SIZE := BookBackgroundConfig.DESIGN_SIZE
const TEXT_PANEL_DESIGN_RECT := Rect2(720.0, 210.0, 760.0, 360.0)
const TYPE_SPEED := 0.035
const DISABLED_BOOKMARK_PAGE_IDS := [
	BookBackgroundConfig.PAGE_HUB,
	BookBackgroundConfig.PAGE_BACKPACK,
	BookBackgroundConfig.PAGE_GALLERY,
	BookBackgroundConfig.PAGE_SETTINGS,
]

@onready var design_root: Control = $DesignRoot
@onready var text_panel: Control = $DesignRoot/UiLayer/TextPanel
@onready var content_label: Label = $DesignRoot/UiLayer/TextPanel/MarginContainer/ContentLabel

var _book_page_navigator: Node = null
var _sequence_id := ""
var _frames: Array = []
var _current_frame_idx := -1
var _is_typing := false
var _type_timer := 0.0
var _finishing := false
var _waiting_for_first_click := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	set_process_input(true)
	if not resized.is_connected(_layout_page):
		resized.connect(_layout_page)
	_layout_page()
	call_deferred("_layout_page")


func set_book_page_navigator(navigator: Node) -> void:
	_book_page_navigator = navigator


func start_story_sequence(sequence_id: String) -> void:
	_sequence_id = sequence_id
	_frames.clear()
	_current_frame_idx = -1
	_is_typing = false
	_type_timer = 0.0
	_finishing = false
	_waiting_for_first_click = true
	if content_label != null:
		content_label.text = ""
		content_label.visible_characters = 0
	var story_manager := get_node_or_null("/root/StoryManager")
	if story_manager != null and story_manager.has_method("get_sequence_frames"):
		var raw_frames: Variant = story_manager.call("get_sequence_frames", sequence_id)
		if raw_frames is Array:
			_frames = Array(raw_frames)


func get_story_display_state() -> Dictionary:
	var state := {
		"sequence_id": _sequence_id,
		"current_frame_idx": _current_frame_idx,
		"waiting_for_first_click": _waiting_for_first_click,
	}
	if content_label != null:
		state["content_text"] = content_label.text
		state["visible_characters"] = content_label.visible_characters
	return state


func apply_story_display_state(state: Dictionary) -> void:
	_sequence_id = str(state.get("sequence_id", _sequence_id))
	_current_frame_idx = int(state.get("current_frame_idx", _current_frame_idx))
	_waiting_for_first_click = bool(state.get("waiting_for_first_click", false))
	_is_typing = false
	_type_timer = 0.0
	_finishing = true
	set_process(false)
	set_process_input(false)
	if content_label == null:
		return
	content_label.text = str(state.get("content_text", content_label.text))
	content_label.visible_characters = int(state.get("visible_characters", content_label.get_total_character_count()))


func _layout_page() -> void:
	if design_root == null:
		return
	DesignScaler.layout_root(design_root, get_viewport_rect().size, DESIGN_SIZE, DesignScaler.SCALE_MODE_COVER)
	if text_panel == null:
		return
	text_panel.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	text_panel.position = TEXT_PANEL_DESIGN_RECT.position
	text_panel.size = TEXT_PANEL_DESIGN_RECT.size


func _process(delta: float) -> void:
	if not _is_typing or content_label == null:
		return
	_type_timer += delta
	if _type_timer < TYPE_SPEED:
		return
	_type_timer = 0.0
	content_label.visible_characters += 1
	if content_label.visible_characters >= content_label.get_total_character_count():
		_is_typing = false
		set_process(false)


func _input(event: InputEvent) -> void:
	if _finishing:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			if _is_disabled_story_bookmark_click(mouse_event.position):
				return
			_advance_or_finish_typing()


func _is_disabled_story_bookmark_click(global_position: Vector2) -> bool:
	if design_root == null:
		return false
	var design_position := design_root.get_global_transform().affine_inverse() * global_position
	if BookBackgroundConfig.get_back_tab_rect().has_point(design_position):
		return true
	for page_id in DISABLED_BOOKMARK_PAGE_IDS:
		var tab_rect := BookBackgroundConfig.get_tab_rect(str(page_id), BookBackgroundConfig.PAGE_HUB)
		if tab_rect.has_point(design_position):
			return true
	return false


func _advance_or_finish_typing() -> void:
	if content_label == null:
		return
	if _waiting_for_first_click:
		_waiting_for_first_click = false
		_next_frame()
		return
	if _is_typing:
		content_label.visible_characters = content_label.get_total_character_count()
		_is_typing = false
		set_process(false)
		return
	_next_frame()


func _next_frame() -> void:
	_current_frame_idx += 1
	if _current_frame_idx >= _frames.size():
		_finish_story_sequence()
		return
	var raw_frame: Variant = _frames[_current_frame_idx]
	var frame_data: Dictionary = Dictionary(raw_frame) if raw_frame is Dictionary else {}
	var speaker := str(frame_data.get("speaker", ""))
	var text := str(frame_data.get("text", ""))
	content_label.text = text if speaker == "" else "%s\n\n%s" % [speaker, text]
	content_label.visible_characters = 0
	_is_typing = true
	_type_timer = 0.0
	set_process(true)


func _finish_story_sequence() -> void:
	if _finishing:
		return
	_finishing = true
	set_process(false)
	set_process_input(false)
	if _book_page_navigator != null and is_instance_valid(_book_page_navigator) and _book_page_navigator.has_method("finish_story_sequence"):
		_book_page_navigator.call("finish_story_sequence", _sequence_id)
		return
	var story_manager := get_node_or_null("/root/StoryManager")
	if story_manager != null and story_manager.has_method("finish_current_sequence"):
		story_manager.call("finish_current_sequence")
