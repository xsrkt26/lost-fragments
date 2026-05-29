extends Control

@onready var speaker_label = $Panel/VBoxContainer/SpeakerLabel
@onready var content_label = $Panel/VBoxContainer/ContentLabel

var _frames: Array = []
var _current_frame_idx: int = -1
var _is_typing: bool = false
var _type_timer: float = 0.0
const TYPE_SPEED = 0.05

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)

func start_dialogue(sequence_id: String) -> void:
	var sm = get_node_or_null("/root/StoryManager")
	if sm:
		_frames = sm.get_sequence_frames(sequence_id)
	_current_frame_idx = -1
	_next_frame()

func _next_frame() -> void:
	_current_frame_idx += 1
	if _current_frame_idx >= _frames.size():
		queue_free()
		return
	
	var frame = _frames[_current_frame_idx]
	speaker_label.text = frame.get("speaker", "")
	content_label.text = frame.get("text", "")
	content_label.visible_characters = 0
	_is_typing = true
	_type_timer = 0.0

func _process(delta: float) -> void:
	if _is_typing:
		_type_timer += delta
		if _type_timer >= TYPE_SPEED:
			_type_timer = 0.0
			content_label.visible_characters += 1
			if content_label.visible_characters >= content_label.get_total_character_count():
				_is_typing = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if _is_typing:
			content_label.visible_characters = content_label.get_total_character_count()
			_is_typing = false
		else:
			_next_frame()
