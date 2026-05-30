extends Node

signal sequence_started(sequence_id: String)
signal sequence_finished(sequence_id: String)

var _sequences: Dictionary = {}
var _played_flags: Dictionary = {}
var current_playing_sequence: String = ""

const AssetPaths = preload("res://src/core/assets/asset_paths.gd")
const JSON_PATH := AssetPaths.STORY_EVENTS
const STORY_ENABLED := false

func _ready() -> void:
	if not STORY_ENABLED:
		print("[StoryManager] Disabled for hub UI testing.")
		return
	_load_json_data()
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		rm.route_changed.connect(_on_route_changed)
		rm.run_finished.connect(_on_run_finished)

func _on_route_changed(current_act: int, route_index: int, current_node: Dictionary) -> void:
	# 简单逻辑：如果是每个 Act 的第一个节点，尝试播放对应剧情
	if route_index == 0:
		var seq_id = "enter_stage_" + str(current_act)
		# 兼容 CSV 里的叫法：有些叫 进入场景1
		var alternative_seq = "进入场景" + str(current_act)
		if has_sequence(seq_id):
			play_sequence(seq_id)
		elif has_sequence(alternative_seq):
			play_sequence(alternative_seq)

func _on_run_finished(victory: bool) -> void:
	# 游戏结束判定
	if not victory:
		if has_sequence("end3") or has_sequence("失败"):
			play_sequence("end3")
	else:
		# 高分/低分结局逻辑 (示例)
		var rm = get_node_or_null("/root/RunManager")
		var score = rm.current_shards if rm else 0
		if score > 50:
			play_sequence("end1")
		else:
			play_sequence("end2")

func _load_json_data() -> void:
	if not FileAccess.file_exists(JSON_PATH):
		push_error("[StoryManager] 找不到剧情配置文件: " + JSON_PATH)
		return
	
	var file = FileAccess.open(JSON_PATH, FileAccess.READ)
	var content = file.get_as_text()
	var parsed = JSON.parse_string(content)
	
	if parsed == null or not (parsed is Dictionary):
		push_error("[StoryManager] 剧情配置 JSON 格式错误")
		return
		
	_sequences = parsed
	print("[StoryManager] Loaded story sequences: ", _sequences.size())

func has_sequence(sequence_id: String) -> bool:
	if not STORY_ENABLED:
		return false
	return _sequences.has(sequence_id)

var _sequence_queue: Array[String] = []

func play_sequence(sequence_id: String) -> bool:
	if not STORY_ENABLED:
		return false
	if not has_sequence(sequence_id):
		return false
		
	# 过滤重复播放（已阅则不再播放，部分关键除外可自定义）
	if _played_flags.get(sequence_id, false):
		return false
		
	if current_playing_sequence != "":
		if sequence_id not in _sequence_queue and sequence_id != current_playing_sequence:
			_sequence_queue.append(sequence_id)
		return true
		
	_played_flags[sequence_id] = true
	current_playing_sequence = sequence_id
	sequence_started.emit(sequence_id)
	
	# 粗略判定是播片还是局内对话
	var is_cutscene = sequence_id == "beginning" or sequence_id.begins_with("end")
	
	if is_cutscene:
		var scene_mgr = _get_scene_manager()
		if scene_mgr == null:
			push_warning("[StoryManager] Scene manager not found; skip cutscene: %s" % sequence_id)
			_played_flags.erase(sequence_id)
			current_playing_sequence = ""
			return false
		scene_mgr.transition_to(scene_mgr.SceneType.CUTSCENE)
	else:
		_show_dialogue_overlay()
		
	return true

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
	if current_playing_sequence != "":
		var seq = current_playing_sequence
		current_playing_sequence = ""
		sequence_finished.emit(seq)
		
		if not _sequence_queue.is_empty():
			var next_seq = _sequence_queue.pop_front()
			play_sequence(next_seq)

func get_sequence_frames(sequence_id: String) -> Array:
	return _sequences.get(sequence_id, [])
