extends Node

signal sequence_started(sequence_id: String)
signal sequence_finished(sequence_id: String)

const JSON_PATH: String = AssetPaths.STORY_EVENTS
const STORY_ENABLED: bool = true
const DIALOGUE_CANVAS_NAME := "DialogueCanvas"
const COMPLETION_ACTION_ADVANCE_EVENT_ROUTE := "advance_event_route"
const COMPLETION_ACTION_RETURN_TO_MAIN_MENU := "return_to_main_menu"
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
var _completion_actions: Dictionary = {}
var _sequence_queue: Array[String] = []
var _pending_hub_sequences: Array[String] = []
var _previous_input_context: int = -1
var current_playing_sequence: String = ""


func _ready() -> void:
	if not STORY_ENABLED:
		print("[StoryManager] Disabled.")
		return
	_load_json_data()
	var rm: Node = _get_run_manager()
	if rm != null:
		_load_played_flags_from_run(rm)
		if rm.has_signal("run_started") and not rm.run_started.is_connected(_on_run_started):
			rm.run_started.connect(_on_run_started)
		if rm.has_signal("route_changed") and not rm.route_changed.is_connected(_on_route_changed):
			rm.route_changed.connect(_on_route_changed)
		if rm.has_signal("run_finished") and not rm.run_finished.is_connected(_on_run_finished):
			rm.run_finished.connect(_on_run_finished)
	var scene_mgr: Node = _get_scene_manager()
	if scene_mgr != null and scene_mgr.has_signal("transition_finished"):
		var callback := Callable(self, "_on_scene_transition_finished")
		if not scene_mgr.transition_finished.is_connected(callback):
			scene_mgr.transition_finished.connect(callback)


func _on_run_started() -> void:
	_played_flags.clear()
	_completion_actions.clear()
	_sequence_queue.clear()
	_pending_hub_sequences.clear()
	_previous_input_context = -1
	current_playing_sequence = ""
	_sync_played_flags_to_run()


func _on_route_changed(current_act: int, route_index: int, _current_node: Dictionary) -> void:
	_refresh_played_flags_from_run()
	var rm: Node = _get_run_manager()
	if rm != null and not bool(rm.get("is_run_active")):
		return
	if route_index != 0:
		return
	if current_act <= 1:
		_queue_act_opening_sequences(current_act)
	else:
		_queue_completed_act_sequences(current_act - 1)
	call_deferred("_play_pending_hub_sequences_if_ready")


func _on_run_finished(victory: bool) -> void:
	if not victory:
		_queue_run_finish_sequence("end3")
		return
	var rm: Node = _get_run_manager()
	var score := 0
	if rm != null:
		score = int(rm.get("current_shards"))
	_queue_completed_act_sequences(StageConfig.get_max_act(), false)
	_queue_run_finish_sequence("end1" if score > 50 else "end2")


func _load_json_data() -> void:
	if not FileAccess.file_exists(JSON_PATH):
		push_error("[StoryManager] Missing story config: " + JSON_PATH)
		return
	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("[StoryManager] Cannot open story config: " + JSON_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("[StoryManager] Invalid story config JSON: " + JSON_PATH)
		return
	_sequences = Dictionary(parsed).duplicate(true)
	print("[StoryManager] Loaded story sequences: ", _sequences.size())


func has_sequence(sequence_id: String) -> bool:
	if not STORY_ENABLED:
		return false
	return _sequences.has(sequence_id)


func play_sequence(sequence_id: String) -> bool:
	_refresh_played_flags_from_run()
	if not _can_accept_sequence(sequence_id):
		return false
	if current_playing_sequence != "":
		_queue_sequence(sequence_id)
		return true
	var is_cutscene_sequence := _is_cutscene_sequence(sequence_id)
	if is_cutscene_sequence and sequence_id == "beginning" and not _can_show_story_book_page_on_current_scene():
		_queue_hub_sequence(sequence_id, true)
		return true
	if is_cutscene_sequence or _can_show_dialogue_overlay_now():
		_start_sequence(sequence_id)
		return true
	_queue_hub_sequence(sequence_id)
	return true


func play_current_battle_intro() -> bool:
	_refresh_played_flags_from_run()
	var rm: Node = _get_run_manager()
	if rm == null or not rm.has_method("get_current_route_node_type"):
		return false
	if not RouteConfig.is_battle_node_type(str(rm.call("get_current_route_node_type"))):
		return false
	var act: int = max(1, int(rm.get("current_act")))
	return _play_first_available_sequence(_get_battle_intro_sequence_ids(act))


func get_current_event_sequence_id() -> String:
	var rm: Node = _get_run_manager()
	if rm == null or not rm.has_method("get_current_route_node_type"):
		return ""
	if str(rm.call("get_current_route_node_type")) != RouteConfig.NODE_EVENT:
		return ""
	var node: Dictionary = {}
	if rm.has_method("get_current_route_node"):
		var raw_node: Variant = rm.call("get_current_route_node")
		if raw_node is Dictionary:
			node = Dictionary(raw_node)
	var configured: String = str(node.get("story_sequence", node.get("sequence_id", "")))
	if has_sequence(configured):
		return configured
	var act: int = max(1, int(rm.get("current_act")))
	for sequence_id in _get_event_sequence_ids(act, node):
		if has_sequence(sequence_id):
			return sequence_id
	return ""


func play_current_event_sequence(advance_route_after: bool = true) -> bool:
	_refresh_played_flags_from_run()
	var sequence_id := get_current_event_sequence_id()
	if not _can_accept_sequence(sequence_id):
		return false
	if advance_route_after:
		_completion_actions[sequence_id] = COMPLETION_ACTION_ADVANCE_EVENT_ROUTE
	if not play_sequence(sequence_id):
		_completion_actions.erase(sequence_id)
		return false
	return true


func finish_current_sequence() -> void:
	if current_playing_sequence == "":
		return
	var sequence_id := current_playing_sequence
	current_playing_sequence = ""
	_restore_input_after_story()
	sequence_finished.emit(sequence_id)
	_apply_completion_action(sequence_id)
	if not _sequence_queue.is_empty():
		var next_sequence_id: String = _sequence_queue.pop_front()
		play_sequence(next_sequence_id)
	else:
		_play_pending_hub_sequences_if_ready()


func get_sequence_frames(sequence_id: String) -> Array:
	var frames: Variant = _sequences.get(sequence_id, [])
	if frames is Array:
		return Array(frames)
	return []


func get_played_flags() -> Dictionary:
	return _played_flags.duplicate(true)


func set_played_flags(flags: Dictionary) -> void:
	_played_flags = flags.duplicate(true)


func _can_accept_sequence(sequence_id: String) -> bool:
	if not STORY_ENABLED:
		return false
	if sequence_id == "" or not has_sequence(sequence_id):
		return false
	return not bool(_played_flags.get(sequence_id, false))


func _start_sequence(sequence_id: String) -> void:
	_mark_sequence_played(sequence_id)
	current_playing_sequence = sequence_id
	_lock_input_for_story()
	sequence_started.emit(sequence_id)
	if _is_cutscene_sequence(sequence_id):
		if _try_show_story_book_page(sequence_id):
			return
		var scene_mgr: Node = _get_scene_manager()
		if scene_mgr == null or not scene_mgr.has_method("transition_to"):
			push_warning("[StoryManager] Scene manager not found; skip cutscene: %s" % sequence_id)
			_unmark_sequence_played(sequence_id)
			current_playing_sequence = ""
			_restore_input_after_story()
			return
		scene_mgr.call("transition_to", GlobalScene.SceneType.CUTSCENE)
	else:
		if _try_show_hub_bubble_dialogue(sequence_id):
			return
		_show_dialogue_overlay()


func _try_show_story_book_page(sequence_id: String) -> bool:
	var current_scene := get_tree().current_scene
	if current_scene == null or not current_scene.has_method("play_story_book_page"):
		return false
	return bool(current_scene.call("play_story_book_page", sequence_id))


func _try_show_hub_bubble_dialogue(sequence_id: String) -> bool:
	if not _is_hub_scene_active():
		return false
	var current_scene := get_tree().current_scene
	if current_scene == null or not current_scene.has_method("play_story_bubble_dialogue"):
		return false
	return bool(current_scene.call("play_story_bubble_dialogue", sequence_id))


func _show_dialogue_overlay() -> void:
	var dialogue_prefab := load("res://src/ui/story/dialogue_overlay.tscn") as PackedScene
	if dialogue_prefab == null:
		push_warning("[StoryManager] Dialogue overlay missing.")
		finish_current_sequence()
		return
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.name = DIALOGUE_CANVAS_NAME
	get_tree().root.add_child(canvas)
	var overlay := dialogue_prefab.instantiate()
	canvas.add_child(overlay)
	overlay.tree_exited.connect(func() -> void:
		if canvas != null and is_instance_valid(canvas):
			canvas.queue_free()
		finish_current_sequence()
	)
	if overlay.has_method("start_dialogue"):
		overlay.start_dialogue(current_playing_sequence)


func _queue_sequence(sequence_id: String) -> void:
	if sequence_id == "" or sequence_id == current_playing_sequence or _sequence_queue.has(sequence_id):
		return
	_sequence_queue.append(sequence_id)


func play_pending_hub_sequences_if_ready() -> void:
	_play_pending_hub_sequences_if_ready()


func has_pending_hub_sequences() -> bool:
	return current_playing_sequence != "" or not _pending_hub_sequences.is_empty()


func _queue_hub_sequence(sequence_id: String, front: bool = false, start_if_ready: bool = true) -> bool:
	if not _can_accept_sequence(sequence_id):
		return false
	if start_if_ready and _can_start_hub_sequence_now() and current_playing_sequence == "":
		_start_sequence(sequence_id)
		return true
	if _pending_hub_sequences.has(sequence_id):
		_pending_hub_sequences.erase(sequence_id)
	if front:
		_pending_hub_sequences.push_front(sequence_id)
	else:
		_pending_hub_sequences.append(sequence_id)
	return true


func _queue_first_available_hub_sequence(sequence_ids: Array[String], start_if_ready: bool = true) -> bool:
	for sequence_id in sequence_ids:
		if _queue_hub_sequence(sequence_id, false, start_if_ready):
			return true
	return false


func _queue_act_opening_sequences(act: int) -> void:
	if act != 1:
		return
	_queue_first_available_hub_sequence(_get_stage_intro_sequence_ids(act), false)


func _queue_completed_act_sequences(act: int, start_if_ready: bool = false) -> void:
	_queue_first_available_hub_sequence(_get_fixed_event_sequence_ids(act), start_if_ready)


func _queue_run_finish_sequence(sequence_id: String) -> void:
	if _queue_hub_sequence(sequence_id, false, false):
		_completion_actions[sequence_id] = COMPLETION_ACTION_RETURN_TO_MAIN_MENU
		call_deferred("_play_pending_hub_sequences_if_ready")


func _play_first_available_sequence(sequence_ids: Array[String]) -> bool:
	for sequence_id in sequence_ids:
		if has_sequence(sequence_id):
			return play_sequence(sequence_id)
	return false


func _is_cutscene_sequence(sequence_id: String) -> bool:
	if sequence_id == "beginning" or sequence_id.begins_with("end"):
		return true
	var frames: Array = get_sequence_frames(sequence_id)
	if frames.is_empty():
		return false
	var first_frame: Variant = frames[0]
	if not (first_frame is Dictionary):
		return false
	return str(Dictionary(first_frame).get("type", "")) == "cutscene"


func _can_show_dialogue_overlay_now() -> bool:
	var scene_type: int = _get_current_scene_type()
	return [
		GlobalScene.SceneType.HUB,
		GlobalScene.SceneType.BATTLE,
		GlobalScene.SceneType.EVENT,
		GlobalScene.SceneType.SHOP,
	].has(scene_type)


func _is_hub_scene_active() -> bool:
	if _get_current_scene_type() == GlobalScene.SceneType.HUB:
		return true
	var current_scene := get_tree().current_scene
	if _is_standalone_story_book_scene(current_scene):
		return false
	return current_scene != null and current_scene.has_method("play_story_book_page")


func _can_show_story_book_page_on_current_scene() -> bool:
	var current_scene := get_tree().current_scene
	return current_scene != null and current_scene.has_method("play_story_book_page")


func _can_start_hub_sequence_now() -> bool:
	if not _is_hub_scene_active():
		return false
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("can_play_pending_story_sequence"):
		return bool(current_scene.call("can_play_pending_story_sequence"))
	return true


func _is_standalone_story_book_scene(scene: Node) -> bool:
	if scene == null or not scene.has_method("is_standalone_story_book_scene"):
		return false
	return bool(scene.call("is_standalone_story_book_scene"))


func _on_scene_transition_finished(_new_scene: Node) -> void:
	if _get_current_scene_type() == GlobalScene.SceneType.BATTLE:
		play_current_battle_intro()
	_play_pending_hub_sequences_if_ready()


func _play_pending_hub_sequences_if_ready() -> void:
	if current_playing_sequence != "" or _pending_hub_sequences.is_empty() or not _can_start_hub_sequence_now():
		return
	var next_sequence_id: String = _pending_hub_sequences.pop_front()
	play_sequence(next_sequence_id)


func _apply_completion_action(sequence_id: String) -> void:
	var action: String = str(_completion_actions.get(sequence_id, ""))
	_completion_actions.erase(sequence_id)
	match action:
		COMPLETION_ACTION_ADVANCE_EVENT_ROUTE:
			_advance_current_event_route_after_story()
		COMPLETION_ACTION_RETURN_TO_MAIN_MENU:
			_return_to_main_menu_after_story()


func _advance_current_event_route_after_story() -> void:
	var rm: Node = _get_run_manager()
	if rm != null and rm.has_method("get_current_route_node_type") and str(rm.call("get_current_route_node_type")) == RouteConfig.NODE_EVENT:
		rm.call("advance_route_node")
	var scene_mgr: Node = _get_scene_manager()
	if scene_mgr != null and _get_current_scene_type() == GlobalScene.SceneType.EVENT:
		scene_mgr.call("transition_to", GlobalScene.SceneType.HUB, false)


func _return_to_main_menu_after_story() -> void:
	var scene_mgr: Node = _get_scene_manager()
	if scene_mgr != null and scene_mgr.has_method("transition_to"):
		scene_mgr.call("transition_to", GlobalScene.SceneType.MAIN_MENU, false)


func _get_stage_intro_sequence_ids(act: int) -> Array[String]:
	return [
		"enter_stage_%d" % act,
		"进入场景%d" % act,
	]


func _get_fixed_event_sequence_ids(act: int) -> Array[String]:
	var result: Array[String] = [
		"fixed_event_%d" % act,
		"固定事件%d" % act,
	]
	var mapped: String = str(FIXED_EVENT_SEQUENCE_BY_ACT.get(act, ""))
	if mapped != "":
		result.append(mapped)
	return result


func _get_battle_intro_sequence_ids(act: int) -> Array[String]:
	var result: Array[String] = [
		"enter_battle_%d" % act,
		"进入局内%d" % act,
	]
	if act == 1:
		result.append("进入局内")
	return result


func _get_event_sequence_ids(act: int, node: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var node_id: String = str(node.get("id", ""))
	if node_id != "":
		result.append("event_%s" % node_id)
		result.append("事件_%s" % node_id)
	return result


func _mark_sequence_played(sequence_id: String) -> void:
	_played_flags[sequence_id] = true
	_sync_played_flags_to_run()


func _unmark_sequence_played(sequence_id: String) -> void:
	_played_flags.erase(sequence_id)
	_sync_played_flags_to_run()


func _load_played_flags_from_run(run_manager: Node) -> void:
	if run_manager.has_method("get_story_played_flags"):
		var flags: Variant = run_manager.call("get_story_played_flags")
		_played_flags = Dictionary(flags).duplicate(true) if flags is Dictionary else {}
		return
	var stored: Variant = run_manager.get("story_played_flags")
	_played_flags = Dictionary(stored).duplicate(true) if stored is Dictionary else {}


func _refresh_played_flags_from_run() -> void:
	var rm: Node = _get_run_manager()
	if rm != null:
		_load_played_flags_from_run(rm)


func _sync_played_flags_to_run() -> void:
	var rm: Node = _get_run_manager()
	if rm == null:
		return
	if rm.has_method("set_story_played_flags"):
		rm.call("set_story_played_flags", _played_flags, true)
	elif _has_node_property(rm, "story_played_flags"):
		rm.set("story_played_flags", _played_flags.duplicate(true))
		if rm.has_method("save_current_state"):
			rm.call("save_current_state")


func _lock_input_for_story() -> void:
	var input_manager := get_node_or_null("/root/GlobalInput")
	if input_manager == null:
		return
	if _previous_input_context < 0:
		_previous_input_context = int(input_manager.get("current_context"))
	GlobalInput.set_context(GlobalInput.Context.LOCKED)


func _restore_input_after_story() -> void:
	if _previous_input_context < 0:
		return
	var input_manager := get_node_or_null("/root/GlobalInput")
	if input_manager != null:
		GlobalInput.set_context(_previous_input_context as GlobalInput.Context)
	_previous_input_context = -1


func _get_run_manager() -> Node:
	return get_node_or_null("/root/RunManager")


func _get_scene_manager() -> Node:
	var scene_mgr: Node = get_node_or_null("/root/GlobalScene")
	if scene_mgr != null:
		return scene_mgr
	return get_node_or_null("/root/SceneManager")


func _get_current_scene_type() -> int:
	var scene_mgr: Node = _get_scene_manager()
	if scene_mgr == null:
		return -1
	var value: Variant = scene_mgr.get("current_scene_type")
	if typeof(value) == TYPE_INT:
		return int(value)
	return -1


func _has_node_property(node: Object, property_name: String) -> bool:
	if node == null:
		return false
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false
