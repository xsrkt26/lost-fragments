extends Control

@onready var content_label = $MarginContainer/ContentLabel
@onready var animation_player = $AnimationPlayer

var _frames: Array = []
var _current_frame_idx: int = -1

func _ready() -> void:
	var sm = get_node_or_null("/root/StoryManager")
	if sm and sm.current_playing_sequence != "":
		_frames = sm.get_sequence_frames(sm.current_playing_sequence)
	else:
		push_error("[Cutscene] No active sequence.")
	
	_next_frame()

func _next_frame() -> void:
	_current_frame_idx += 1
	if _current_frame_idx >= _frames.size():
		_finish_cutscene()
		return
	
	var frame = _frames[_current_frame_idx]
	content_label.text = frame.get("text", "")
	animation_player.play("fade_in_text")

func _finish_cutscene() -> void:
	var sm = get_node_or_null("/root/StoryManager")
	var seq = ""
	if sm:
		seq = sm.current_playing_sequence
		sm.finish_current_sequence()
		
	var scene_mgr = _get_scene_manager()
	if scene_mgr:
		var target = scene_mgr.SceneType.MAIN_MENU
		if seq == "beginning":
			target = scene_mgr.SceneType.HUB
		elif not seq.begins_with("end"):
			target = scene_mgr.SceneType.HUB
		scene_mgr.transition_to(target)

func _get_scene_manager() -> Node:
	var scene_mgr = get_node_or_null("/root/GlobalScene")
	if scene_mgr != null:
		return scene_mgr
	return get_node_or_null("/root/SceneManager")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if animation_player.is_playing():
			animation_player.seek(animation_player.current_animation_length, true)
		else:
			animation_player.play("fade_out_text")
