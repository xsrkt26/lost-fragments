extends Control

const DEFAULT_SEQUENCE_ID := "beginning"

@export var story_sequence_id := DEFAULT_SEQUENCE_ID
@export var auto_start_sequence := true
@export var transition_on_finish := true
@export var next_scene_type: int = GlobalScene.SceneType.HUB

@onready var story_page: Control = $StoryBookPage

var _started := false
var _finishing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if story_page != null and story_page.has_method("set_book_page_navigator"):
		story_page.call("set_book_page_navigator", self)
	_preload_next_scene()
	if auto_start_sequence:
		call_deferred("_start_configured_sequence")


func is_standalone_story_book_scene() -> bool:
	return true


func play_story_book_page(sequence_id: String) -> bool:
	if story_page == null or not story_page.has_method("start_story_sequence"):
		return false
	if story_page.has_method("set_book_page_navigator"):
		story_page.call("set_book_page_navigator", self)
	story_page.call("start_story_sequence", sequence_id)
	return true


func finish_story_sequence(sequence_id: String) -> void:
	if _finishing:
		return
	_finishing = true
	var story_manager := get_node_or_null("/root/StoryManager")
	if story_manager != null and story_manager.has_method("finish_current_sequence"):
		var active_sequence: Variant = story_manager.get("current_playing_sequence")
		if sequence_id == "" or str(active_sequence) == sequence_id:
			story_manager.call("finish_current_sequence")
	await get_tree().process_frame
	if transition_on_finish:
		_transition_to_next_scene()


func _start_configured_sequence() -> void:
	if _started:
		return
	_started = true
	var story_manager := get_node_or_null("/root/StoryManager")
	if story_manager != null and story_manager.has_method("play_sequence"):
		if bool(story_manager.call("play_sequence", story_sequence_id)):
			return
	_transition_to_next_scene()


func _preload_next_scene() -> void:
	var scene_manager := get_node_or_null("/root/GlobalScene")
	if scene_manager != null and scene_manager.has_method("preload_scene"):
		scene_manager.call("preload_scene", next_scene_type)


func _transition_to_next_scene() -> void:
	var scene_manager := get_node_or_null("/root/GlobalScene")
	if scene_manager != null and scene_manager.has_method("transition_to"):
		scene_manager.call("transition_to", next_scene_type, false)
