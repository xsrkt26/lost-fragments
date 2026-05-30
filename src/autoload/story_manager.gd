extends Node

signal sequence_started(sequence_id: String)
signal sequence_finished(sequence_id: String)

const JSON_PATH: String = AssetPaths.STORY_EVENTS
const STORY_ENABLED: bool = true
const FIXED_EVENT_SEQUENCE_BY_ACT: Dictionary = {
	1: "固定事件1·小咪",
	2: "固定事件2·小舅",
	3: "固定事件3·姥姥",
	4: "固定事件4·父母",
	5: "固定事件5·小佳",
	6: "固定事件6·拾忆",
}

var _sequences: Dictionary = {}
var _played_flags: Dictionary = {}
var _sequence_queue: Array[String] = []
var _pending_hub_sequences: Array[String] = []
var current_playing_sequence: String = ""

func _ready() -> void:
	if not STORY_ENABLED:
		print("[StoryManager] Disabled.")
		return
	_load_json_data()
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		if rm.has_signal("run_started"):
			rm.run_started.connect(_on_run_started)
		rm.route_changed.connect(_on_route_changed)
		rm.run_finished.connect(_on_run_finished)
	var scene_mgr = _get_scene_manager()
	if scene_mgr != null and scene_mgr.has_signal("transition_finished"):
		scene_mgr.transition_finished.connect(_on_scene_transition_finished)

func _on_run_started() -> void:
	_played_flags.clear()
	_sequence_queue.clear()
	_pending_hub_sequences.clear()
	current_playing_sequence = ""

func _on_route_changed(current_act: int, route_index: int, _current_node: Dictionary) -> void:
	if route_index != 0:
		return
	_queue_first_available_hub_sequence([
		"enter_stage_" + str(current_act),
		"进入场景" + str(current_act),
	])
	var fixed_event_sequence: String = str(FIXED_EVENT_SEQUENCE_BY_ACT.get(current_act, ""))
	if fixed_event_sequence != "":
		_queue_hub_sequence(fixed_event_sequence)

func _on_run_finished(victory: bool) -> void:
	if not victory:
		play_sequence("end3")
		return
	var rm = get_node_or_null("/root/RunManager")
	var score = rm.current_shards if rm else 0
	if score > 50:
		play_sequence("end1")
	else:
		play_sequence("end2")

func _load_json_data() -> void:
	if not FileAccess.file_exists(JSON_PATH):
		push_error("[StoryManager] Missing story config: " + JSON_PATH)
		return
	var file = FileAccess.open(JSON_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("[StoryManager] Invalid story config JSON: " + JSON_PATH)
		return
	_sequences = parsed
	print("[StoryManager] Loaded story sequences: ", _sequences.size())

func has_sequence(sequence_id: String) -> bool:
	if not STORY_ENABLED:
		return false
	return _sequences.has(sequence_id)

func play_sequence(sequence_id: String) -> bool:
	if not STORY_ENABLED:
		return false
	if not has_sequence(sequence_id):
		return false
	if _played_flags.get(sequence_id, false):
		return false
	if current_playing_sequence != "":
		_queue_sequence(sequence_id)
		return true
	if not _is_cutscene_sequence(sequence_id) and not _is_dialogue_scene_active():
		_queue_hub_sequence(sequence_id)
		return true
	_start_sequence(sequence_id)
	return true

func _start_sequence(sequence_id: String) -> void:
	_played_flags[sequence_id] = true
	current_playing_sequence = sequence_id
	sequence_started.emit(sequence_id)
	if _is_cutscene_sequence(sequence_id):
		var scene_mgr = _get_scene_manager()
		if scene_mgr == null:
			push_warning("[StoryManager] Scene manager not found; skip cutscene: %s" % sequence_id)
			_played_flags.erase(sequence_id)
			current_playing_sequence = ""
			return
		scene_mgr.transition_to(scene_mgr.SceneType.CUTSCENE)
	else:
		_show_dialogue_overlay()

func _get_scene_manager() -> Node:
	var scene_mgr = get_node_or_null("/root/GlobalScene")
	if scene_mgr != null:
		return scene_mgr
	return get_node_or_null("/root/SceneManager")

func _show_dialogue_overlay() -> void:
	var dialogue_prefab = load("res://src/ui/story/dialogue_overlay.tscn")
	if dialogue_prefab:
		var overlay = dialogue_prefab.instantiate()
		var canvas = CanvasLayer.new()
		canvas.layer = 100
		canvas.name = "DialogueCanvas"
		get_tree().root.add_child(canvas)
		canvas.add_child(overlay)
		overlay.tree_exited.connect(func():
			canvas.queue_free()
			finish_current_sequence()
		)
		overlay.start_dialogue(current_playing_sequence)

func finish_current_sequence() -> void:
	if current_playing_sequence == "":
		return
	var seq = current_playing_sequence
	current_playing_sequence = ""
	sequence_finished.emit(seq)
	if not _sequence_queue.is_empty():
		var next_seq: String = _sequence_queue.pop_front()
		play_sequence(next_seq)
	else:
		_play_pending_hub_sequences_if_ready()

func get_sequence_frames(sequence_id: String) -> Array:
	return _sequences.get(sequence_id, [])

func _queue_sequence(sequence_id: String) -> void:
	if sequence_id == "" or sequence_id == current_playing_sequence or _sequence_queue.has(sequence_id):
		return
	_sequence_queue.append(sequence_id)

func _queue_hub_sequence(sequence_id: String) -> void:
	if sequence_id == "" or not has_sequence(sequence_id) or _played_flags.get(sequence_id, false):
		return
	if _is_hub_scene_active() and current_playing_sequence == "":
		play_sequence(sequence_id)
		return
	if not _pending_hub_sequences.has(sequence_id):
		_pending_hub_sequences.append(sequence_id)

func _queue_first_available_hub_sequence(sequence_ids: Array) -> bool:
	for sequence_id in sequence_ids:
		var normalized: String = str(sequence_id)
		if has_sequence(normalized):
			_queue_hub_sequence(normalized)
			return true
	return false

func _is_cutscene_sequence(sequence_id: String) -> bool:
	if sequence_id == "beginning" or sequence_id.begins_with("end"):
		return true
	var frames: Array = get_sequence_frames(sequence_id)
	if frames.is_empty():
		return false
	var first_frame = frames[0]
	if not (first_frame is Dictionary):
		return false
	return str(first_frame.get("type", "")) == "cutscene"

func _is_dialogue_scene_active() -> bool:
	var scene_mgr = _get_scene_manager()
	if scene_mgr == null:
		return false
	var scene_type: Variant = scene_mgr.get("current_scene_type")
	return scene_type == scene_mgr.SceneType.HUB or scene_type == scene_mgr.SceneType.BATTLE

func _is_hub_scene_active() -> bool:
	var scene_mgr = _get_scene_manager()
	if scene_mgr == null:
		return false
	return scene_mgr.get("current_scene_type") == scene_mgr.SceneType.HUB

func _on_scene_transition_finished(_new_scene) -> void:
	var scene_mgr = _get_scene_manager()
	if scene_mgr == null:
		return
	if scene_mgr.get("current_scene_type") == scene_mgr.SceneType.BATTLE:
		_play_battle_intro_if_available()
	_play_pending_hub_sequences_if_ready()

func _play_battle_intro_if_available() -> void:
	var rm = get_node_or_null("/root/RunManager")
	if rm == null:
		return
	if not rm.has_method("get_current_route_node_type"):
		return
	if not RouteConfig.is_battle_node_type(str(rm.get_current_route_node_type())):
		return
	var act: int = max(1, int(rm.get("current_act")))
	for sequence_id in ["enter_battle_" + str(act), "进入局内" + str(act)]:
		if has_sequence(sequence_id):
			play_sequence(sequence_id)
			return

func _play_pending_hub_sequences_if_ready() -> void:
	if current_playing_sequence != "" or _pending_hub_sequences.is_empty() or not _is_hub_scene_active():
		return
	var next_seq: String = _pending_hub_sequences.pop_front()
	play_sequence(next_seq)
