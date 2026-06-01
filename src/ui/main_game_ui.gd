extends Control

const DesignScaler = preload("res://src/ui/layout/ui_design_scaler.gd")
const PendingItemPresenter = preload("res://src/ui/backpack/pending_item_presenter.gd")
const ToolPanelPresenter = preload("res://src/ui/battle/tool_panel_presenter.gd")

const BATTLE_FRAME_SIZE := Vector2(1920.0, 1080.0)
const DREAMCATCHER_SWING_PIVOT_DISTANCE_RATIO: float = 0.82
const STATS_FONT_SIZE_SANITY := 32
const STATS_FONT_SIZE_SCORE := 52
const STATS_FONT_SIZE_TARGET := 44
const STATS_FONT_SIZE_MIN := 26
const STATS_DARK_COLOR := Color(0.04, 0.035, 0.03)
const STATS_LOW_SANITY_COLOR := Color(1, 0, 0)
const STATS_SCORE_REACHED_COLOR := Color(0.2, 0.8, 0.2)
## 主游戏 UI 控制器：负责将布局中的各个部分与逻辑层连接

@onready var content_layer = $ContentLayer
@onready var battle_grid_panel: Control = get_node_or_null("ContentLayer/GridPanel") as Control
@onready var battle_backpack_ui: Control = get_node_or_null("ContentLayer/GridPanel/BackpackUI") as Control
@onready var sanity_label = $ContentLayer/StatsPanel/SanityLabel
@onready var score_label = $ContentLayer/StatsPanel/ScoreLabel
@onready var target_score_label = get_node_or_null("ContentLayer/StatsPanel/TargetScoreLabel") as Label
@onready var potion_bag = get_node_or_null("ContentLayer/StatsPanel/PotionBag") as TextureRect
@onready var draw_button = $ContentLayer/DreamcatcherPanel/DrawButton
@onready var dreamcatcher_panel = $ContentLayer/DreamcatcherPanel
@onready var dreamcatcher_net = get_node_or_null("ContentLayer/DreamcatcherPanel/DreamcatcherNet") as Sprite2D
@onready var draw_spawn_point = get_node_or_null(draw_spawn_point_path)
@onready var battle_trash_bin: Control = get_node_or_null("ContentLayer/GridPanel/TrashBin") as Control
@onready var battle_trash_icon_art: Control = get_node_or_null("ContentLayer/StatsPanel/TrashIconArt") as Control
@onready var ornaments_area = $ContentLayer/OrnamentsPanel/Slots
@onready var pending_item_panel = get_node_or_null("ContentLayer/PendingItemPanel")
@onready var pending_item_area = get_node_or_null("ContentLayer/PendingItemPanel/PendingItemArea")
@onready var tool_panel = get_node_or_null("ContentLayer/ToolPanel")
@onready var tool_slot_area = get_node_or_null("ContentLayer/ToolPanel/ToolSlots")
@onready var battle_art = get_node_or_null("ContentLayer/BattleArt")
@onready var playable_bag_art = get_node_or_null("ContentLayer/PlayableBagArt") as TextureRect
@onready var intro_bag_reveal = get_node_or_null("ContentLayer/IntroBagReveal") as TextureRect

@export var draw_spawn_point_path: NodePath = "ContentLayer/DreamcatcherPanel/DrawSpawnPoint"
@export var auto_initialize := true
@export_group("Battle Intro")
@export var play_battle_intro := true
@export var intro_bag_frame_paths := AssetPaths.intro_bag_reveal_frame_paths()
@export var intro_bag_offset := Vector2.ZERO
@export var intro_bag_drop_start_offset := Vector2(360.0, -520.0)
@export_range(0.1, 1.5, 0.01) var intro_bag_drop_duration := 0.62
@export_range(0.3, 1.2, 0.01) var intro_bag_drop_start_scale := 0.72
@export_range(-30.0, 30.0, 0.1) var intro_bag_drop_start_rotation_degrees := -7.0
@export_range(0.01, 0.8, 0.01) var intro_bag_frame_time := 0.34
@export_range(0.0, 32.0, 0.5) var intro_bag_jitter := 7.0
@export_range(0.0, 1.0, 0.01) var intro_bag_final_hold := 0.28
@export var intro_stats_start_offset := Vector2(0.0, 420.0)
@export_range(0.0, 2.0, 0.01) var intro_stats_rise_duration := 0.68
@export var intro_tool_start_offset := Vector2(0.0, 120.0)
@export_range(0.0, 1.0, 0.01) var intro_grid_reveal_duration := 0.32
@export var intro_grid_crossfade_enabled := false
@export_group("Trash Drop")
@export var trash_drop_hit_inset := Vector2(12.0, 10.0)
@export_range(0.0, 1.0, 0.01) var trash_drop_alpha_threshold := 0.08
@export_range(1.0, 1.5, 0.01) var trash_drop_hover_scale := 1.14
@export_range(1.0, 1.7, 0.01) var trash_drop_pulse_scale := 1.24
@export_range(0.01, 0.4, 0.01) var trash_drop_scale_duration := 0.11

var battle_manager: BattleManager
var game_state_override = null
var run_manager_override = null
var item_database_override = null
var tool_database_override = null
var ornament_database_override = null
var _is_battle_ended: bool = false
var _draw_locked: bool = false
var _dreamcatcher_net_base_position := Vector2.ZERO
var _dreamcatcher_net_base_rotation := 0.0
var _dreamcatcher_net_base_offset := Vector2.ZERO
var _selected_tool_id: String = ""
var _dragged_tool_id: String = ""
var _tool_drag_start: Vector2 = Vector2.ZERO
var backpack_ui: Control = null
var trash_bin: Control = null
var _intro_target_positions: Dictionary = {}
var _intro_bag_rect: TextureRect = null
var _potion_state_textures: Array[Texture2D] = []
var _trash_bin_base_scale := Vector2.ONE
var _trash_bin_base_scale_ready := false
var _trash_bin_base_node: Control = null
var _trash_bin_drag_hovered := false
var _trash_bin_tween: Tween = null
var _trash_hit_texture: Texture2D = null
var _trash_hit_image: Image = null
var _embedded_return_callback: Callable = Callable()
var _is_embedded_mode := false
var _last_drag_root_grid_pos := Vector2i(-999999, -999999)
var _last_drag_item_id := 0
var _last_drag_over_trash := false

@onready var stats_panel = $ContentLayer/StatsPanel
@onready var ornaments_panel = $ContentLayer/OrnamentsPanel
@onready var dreamcatcher_panel_node = $ContentLayer/DreamcatcherPanel

var _intro_playing := false


func _ready():
	_ensure_potion_state_textures()
	print("[MainGameUI Debug] UI初始化开始...")
	_select_active_backpack_ui()
	if not resized.is_connected(_layout_current_scene):
		resized.connect(_layout_current_scene)
	_layout_current_scene()
	_capture_dreamcatcher_net_pose()

	if auto_initialize:
		if play_battle_intro:
			_prepare_intro_animation()
		else:
			_set_intro_playing(false)

	var menu_btn = $ContentLayer/MenuButton
	if menu_btn:
		menu_btn.text = ""
		menu_btn.tooltip_text = "结束本局"
		menu_btn.flat = true
		menu_btn.focus_mode = Control.FOCUS_NONE

	# 检查关键节点是否成功获取
	if draw_button:
		# 强制确保按钮是可见的且接收鼠标
		draw_button.visible = true
		draw_button.tooltip_text = "捕梦"
		draw_button.focus_mode = Control.FOCUS_NONE
	if trash_bin:
		trash_bin.tooltip_text = "丢弃"
		_setup_trash_bin_feedback()
	_ensure_tool_panel()
	_layout_current_scene()
	if auto_initialize:
		call_deferred("_ensure_battle_manager_setup")
		call_deferred("_start_intro_sequence")

func _exit_tree() -> void:
	if _intro_playing:
		_set_intro_playing(false)
		_clear_intro_bag_reveal()
		if GlobalInput.is_context(GlobalInput.Context.LOCKED):
			GlobalInput.set_context(GlobalInput.Context.BATTLE)

func _prepare_intro_animation() -> void:
	if not play_battle_intro:
		_set_intro_playing(false)
		return
	_set_intro_playing(true)
	_capture_intro_target_positions()
	_apply_intro_prestart_state()

func _start_intro_sequence() -> void:
	if not play_battle_intro:
		_set_intro_playing(false)
		return
	_set_intro_playing(true)
	GlobalInput.set_context(GlobalInput.Context.LOCKED)
	_apply_intro_prestart_state()
	await get_tree().process_frame
	if not _should_continue_intro():
		return

	var bag_rect := _show_intro_bag_reveal()
	if bag_rect != null:
		await _animate_intro_bag_drop(bag_rect)
		await _play_intro_bag_frames(bag_rect)
	if not _should_continue_intro():
		_clear_intro_bag_reveal()
		return

	await _animate_intro_left_ui()
	if not _should_continue_intro():
		_clear_intro_bag_reveal()
		return
	await _reveal_intro_grid(bag_rect)
	if not _should_continue_intro():
		_clear_intro_bag_reveal()
		return

	_clear_intro_bag_reveal()
	_set_intro_playing(false)
	if not _is_battle_ended:
		GlobalInput.set_context(GlobalInput.Context.BATTLE)
	print("[MainGameUI] Battle intro finished")

func _set_intro_playing(playing: bool) -> void:
	_intro_playing = playing
	_sync_draw_button_state()


func _clear_intro_bag_reveal() -> void:
	var bag_rect := _get_intro_bag_reveal_node()
	if bag_rect != null and is_instance_valid(bag_rect):
		bag_rect.texture = null
		bag_rect.modulate = Color.WHITE
		bag_rect.rotation = 0.0
		bag_rect.scale = Vector2.ONE
		bag_rect.hide()
	_intro_bag_rect = null


func _get_playable_bag_art_node() -> TextureRect:
	if playable_bag_art == null:
		playable_bag_art = get_node_or_null("ContentLayer/PlayableBagArt") as TextureRect
	return playable_bag_art


func _hide_playable_bag_art() -> void:
	var bag_art := _get_playable_bag_art_node()
	if bag_art == null:
		return
	bag_art.hide()


func _show_playable_bag_art() -> void:
	var bag_art := _get_playable_bag_art_node()
	if bag_art == null:
		return
	var target_rect := _get_intro_bag_target_rect()
	if target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		return
	bag_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bag_art.stretch_mode = TextureRect.STRETCH_SCALE
	bag_art.position = target_rect.position
	bag_art.size = target_rect.size
	bag_art.pivot_offset = target_rect.size * 0.5
	bag_art.scale = Vector2.ONE
	bag_art.rotation = 0.0
	bag_art.modulate = Color.WHITE
	bag_art.show()


func _show_ornaments_panel_static() -> void:
	if ornaments_panel == null:
		return
	ornaments_panel.position = _get_intro_target_position("ornaments", ornaments_panel)
	ornaments_panel.modulate.a = 1.0
	ornaments_panel.show()


func _get_intro_bag_reveal_node() -> TextureRect:
	if intro_bag_reveal == null:
		intro_bag_reveal = get_node_or_null("ContentLayer/IntroBagReveal") as TextureRect
	return intro_bag_reveal


func _should_continue_intro() -> bool:
	return _intro_playing and is_inside_tree()


func _capture_intro_target_positions() -> void:
	_capture_intro_target_position("stats", stats_panel)
	_capture_intro_target_position("tool", tool_panel as Control)
	_capture_intro_target_position("ornaments", ornaments_panel)


func _capture_intro_target_position(key: String, control: Control) -> void:
	if control == null or _intro_target_positions.has(key):
		return
	_intro_target_positions[key] = control.position


func _get_intro_target_position(key: String, control: Control) -> Vector2:
	if _intro_target_positions.has(key):
		return _intro_target_positions[key]
	return control.position if control != null else Vector2.ZERO


func _apply_intro_prestart_state() -> void:
	_capture_intro_target_positions()
	_hide_playable_bag_art()
	if battle_grid_panel:
		battle_grid_panel.modulate.a = 0.0
		battle_grid_panel.hide()
	if stats_panel:
		stats_panel.position = _get_intro_target_position("stats", stats_panel) + intro_stats_start_offset
		stats_panel.modulate.a = 0.0
		stats_panel.show()
	if tool_panel:
		tool_panel.position = _get_intro_target_position("tool", tool_panel as Control) + intro_tool_start_offset
		tool_panel.modulate.a = 0.0
	if ornaments_panel:
		ornaments_panel.modulate.a = 0.0
		ornaments_panel.hide()


func _get_intro_bag_frames() -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for path in _get_intro_bag_frame_paths():
		var frame := AssetPaths.load_texture(path)
		if frame != null:
			frames.append(frame)
	return frames


func _get_intro_bag_frame_paths() -> PackedStringArray:
	return intro_bag_frame_paths


func _show_intro_bag_reveal() -> TextureRect:
	if battle_grid_panel == null:
		return null
	var frames := _get_intro_bag_frames()
	if frames.is_empty():
		_clear_intro_bag_reveal()
		return null
	_clear_intro_bag_reveal()
	var bag_rect := _get_intro_bag_reveal_node()
	if bag_rect == null:
		push_warning("[MainGameUI] IntroBagReveal missing from main_game_ui.tscn.")
		return null
	var target_rect := _get_intro_bag_target_rect()
	bag_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bag_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bag_rect.texture = frames[0]
	bag_rect.position = _get_intro_bag_drop_start_position(target_rect)
	bag_rect.size = target_rect.size
	bag_rect.pivot_offset = target_rect.size * 0.5
	bag_rect.scale = Vector2.ONE * intro_bag_drop_start_scale
	bag_rect.rotation = deg_to_rad(intro_bag_drop_start_rotation_degrees)
	bag_rect.z_index = max(120, battle_grid_panel.z_index + 20)
	bag_rect.modulate = Color.WHITE
	bag_rect.show()
	_intro_bag_rect = bag_rect
	return bag_rect


func _get_intro_bag_target_rect() -> Rect2:
	var target_rect := _get_intro_bag_alignment_rect()
	if target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		return Rect2()
	target_rect.position += intro_bag_offset
	return target_rect


func _get_intro_bag_alignment_rect() -> Rect2:
	var has_rect := false
	var alignment_rect := Rect2()
	if battle_grid_panel != null:
		alignment_rect = _get_control_visual_rect_in_parent(battle_grid_panel)
		has_rect = alignment_rect.size.x > 0.0 and alignment_rect.size.y > 0.0
	if ornaments_panel != null:
		var ornaments_position := _get_intro_target_position("ornaments", ornaments_panel)
		var ornaments_rect := _get_control_visual_rect_at_position(ornaments_panel, ornaments_position)
		if ornaments_rect.size.x > 0.0 and ornaments_rect.size.y > 0.0:
			alignment_rect = alignment_rect.merge(ornaments_rect) if has_rect else ornaments_rect
			has_rect = true
	return alignment_rect if has_rect else Rect2()


func _get_intro_bag_drop_start_position(target_rect: Rect2) -> Vector2:
	return target_rect.position + intro_bag_drop_start_offset


func _get_control_visual_rect_in_parent(control: Control) -> Rect2:
	return _get_control_visual_rect_at_position(control, control.position)


func _get_control_visual_rect_at_position(control: Control, control_position: Vector2) -> Rect2:
	if control == null:
		return Rect2()
	return Rect2(control_position, control.size * control.scale)


func _place_intro_bag_at_target(bag_rect: TextureRect) -> void:
	if bag_rect == null or not is_instance_valid(bag_rect):
		return
	var target_rect := _get_intro_bag_target_rect()
	if target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		return
	bag_rect.position = target_rect.position
	bag_rect.scale = Vector2.ONE
	bag_rect.rotation = 0.0


func _animate_intro_bag_drop(bag_rect: TextureRect) -> Signal:
	if bag_rect == null or not is_instance_valid(bag_rect):
		return get_tree().process_frame
	var target_rect := _get_intro_bag_target_rect()
	if target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		return get_tree().process_frame
	if intro_bag_drop_duration <= 0.0:
		_place_intro_bag_at_target(bag_rect)
		return get_tree().process_frame
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(bag_rect, "position", target_rect.position, intro_bag_drop_duration)
	tween.tween_property(bag_rect, "scale", Vector2.ONE, intro_bag_drop_duration)
	tween.tween_property(bag_rect, "rotation", 0.0, minf(intro_bag_drop_duration, 0.42))
	return tween.finished


func _play_intro_bag_frames(bag_rect: TextureRect) -> void:
	var frames := _get_intro_bag_frames()
	if frames.is_empty():
		return
	var target_rect := _get_intro_bag_target_rect()
	bag_rect.position = target_rect.position
	bag_rect.size = target_rect.size
	bag_rect.pivot_offset = target_rect.size * 0.5
	bag_rect.scale = Vector2.ONE
	bag_rect.rotation = 0.0
	var base_position := target_rect.position
	var base_rotation := 0.0
	for i in range(frames.size()):
		if i > 0:
			await get_tree().create_timer(intro_bag_frame_time).timeout
			if not _should_continue_intro():
				return
		bag_rect.texture = frames[i]
		bag_rect.position = base_position + _get_intro_bag_jitter(i, frames.size())
		bag_rect.rotation = base_rotation + deg_to_rad(_get_intro_bag_rotation_degrees(i, frames.size()))
	if intro_bag_final_hold > 0.0:
		await get_tree().create_timer(intro_bag_final_hold).timeout


func _get_intro_bag_jitter(index: int, frame_count: int) -> Vector2:
	if intro_bag_jitter <= 0.0 or index == 0 or index == frame_count - 1:
		return Vector2.ZERO
	var pattern := [
		Vector2(-0.75, 0.35),
		Vector2(0.55, -0.45),
		Vector2(-0.25, 0.22),
		Vector2(0.42, 0.18),
	]
	return pattern[index % pattern.size()] * intro_bag_jitter


func _get_intro_bag_rotation_degrees(index: int, frame_count: int) -> float:
	if index == 0 or index == frame_count - 1:
		return 0.0
	var pattern := [-0.45, 0.35, -0.2, 0.25]
	return pattern[index % pattern.size()]


func _animate_intro_left_ui() -> void:
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var has_tween := false
	if stats_panel:
		stats_panel.show()
		tween.tween_property(stats_panel, "position", _get_intro_target_position("stats", stats_panel), intro_stats_rise_duration)
		tween.tween_property(stats_panel, "modulate:a", 1.0, minf(intro_stats_rise_duration, 0.45))
		has_tween = true
	if tool_panel and tool_panel.visible:
		tween.tween_property(tool_panel, "position", _get_intro_target_position("tool", tool_panel as Control), intro_stats_rise_duration)
		tween.tween_property(tool_panel, "modulate:a", 1.0, minf(intro_stats_rise_duration, 0.45))
		has_tween = true
	if has_tween:
		await tween.finished
	else:
		tween.kill()


func _reveal_intro_grid(bag_rect: TextureRect) -> void:
	if battle_grid_panel == null:
		return
	_show_playable_bag_art()
	_show_ornaments_panel_static()
	battle_grid_panel.show()
	if not intro_grid_crossfade_enabled or intro_grid_reveal_duration <= 0.0:
		battle_grid_panel.modulate.a = 1.0
		if bag_rect != null and is_instance_valid(bag_rect):
			bag_rect.scale = Vector2.ONE
			bag_rect.modulate = Color.WHITE
			bag_rect.hide()
		return
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(battle_grid_panel, "modulate:a", 1.0, intro_grid_reveal_duration)
	if bag_rect != null and is_instance_valid(bag_rect):
		tween.tween_property(bag_rect, "modulate:a", 0.0, intro_grid_reveal_duration)
		tween.tween_property(bag_rect, "scale", Vector2.ONE, intro_grid_reveal_duration)
	await tween.finished


func _ensure_battle_manager_setup() -> void:
	if battle_manager == null:
		var mock_manager = BattleManager.new()
		add_child(mock_manager)
		setup(mock_manager)

func setup(p_battle_manager: BattleManager, embedded_return_callback: Callable = Callable()):
	print("[MainGameUI] Running setup...")
	if p_battle_manager == null:
		push_warning("[MainGameUI] setup called with null battle manager.")
		return
	_reset_battle_session_state()
	_set_intro_playing(false)
	_clear_intro_bag_reveal()
	if battle_manager != null and battle_manager != p_battle_manager:
		var old_manager := battle_manager
		battle_manager = null
		if is_instance_valid(old_manager):
			old_manager.queue_free()

	GlobalInput.set_context(GlobalInput.Context.BATTLE)
	GlobalAudio.play_bgm(_get_stage_bgm_key("battle_bgm_key", "battle"))
	battle_manager = p_battle_manager
	_embedded_return_callback = embedded_return_callback
	_is_embedded_mode = embedded_return_callback.is_valid()
	_select_active_backpack_ui()
	_apply_stage_visuals()

	var gs = _get_game_state()
	if gs:
		gs.reset_game()

	if backpack_ui == null:
		print("[MainGameUI] Error: backpack_ui is null.")

	battle_manager.backpack_ui = backpack_ui
	_clear_backpack_item_visuals()
	if not battle_manager.battle_finish_requested.is_connected(_on_battle_finish_requested):
		battle_manager.battle_finish_requested.connect(_on_battle_finish_requested)

	if not battle_manager.item_drawn.is_connected(_on_item_drawn):
		battle_manager.item_drawn.connect(_on_item_drawn)
	_connect_backpack_ui_signals()
	_render_existing_backpack_items()
	_render_pending_items()
	_render_ornaments()
	_connect_tool_inventory_signal()
	_render_tools()

	gs = _get_game_state()
	if gs:
		if gs.sanity_changed.is_connected(_on_sanity_changed): gs.sanity_changed.disconnect(_on_sanity_changed)
		if gs.score_changed.is_connected(_on_score_changed): gs.score_changed.disconnect(_on_score_changed)
		if gs.game_over.is_connected(_on_game_over): gs.game_over.disconnect(_on_game_over)

		gs.sanity_changed.connect(_on_sanity_changed)
		gs.score_changed.connect(_on_score_changed)
		gs.game_over.connect(_on_game_over)
	_update_stats_display(gs.current_sanity, gs.current_score)
	_sync_draw_button_state()
	if play_battle_intro and not auto_initialize:
		_apply_intro_prestart_state()
		call_deferred("_start_intro_sequence")


func _return_to_scene_with_embedded_support(target_scene: int, push_to_history: bool = true) -> void:
	if _is_embedded_mode:
		if _embedded_return_callback.is_valid():
			_embedded_return_callback.call(target_scene)
			return
	# Standalone fallback.
	GlobalScene.transition_to(target_scene, push_to_history)

func _reset_battle_session_state() -> void:
	_is_battle_ended = false
	_draw_locked = false
	_selected_tool_id = ""
	_dragged_tool_id = ""
	_tool_drag_start = Vector2.ZERO

func _clear_backpack_item_visuals() -> void:
	if backpack_ui == null:
		return
	if backpack_ui.has_method("clear_item_visuals"):
		backpack_ui.clear_item_visuals()
	elif backpack_ui.get("item_ui_map") is Dictionary:
		backpack_ui.set("item_ui_map", {})
	if battle_manager != null:
		battle_manager.managed_item_uis.clear()

func _connect_backpack_ui_signals() -> void:
	if backpack_ui == null or battle_manager == null:
		return
	if not backpack_ui.has_signal("item_dropped_on_grid"):
		push_warning("[MainGameUI] BackpackUI script is not ready; item drop signal was not connected.")
		return
	var place_callback := Callable(battle_manager, "request_place_item")
	if not backpack_ui.is_connected("item_dropped_on_grid", place_callback):
		backpack_ui.connect("item_dropped_on_grid", place_callback)


func _select_active_backpack_ui() -> void:
	backpack_ui = battle_backpack_ui
	trash_bin = battle_trash_icon_art if battle_trash_icon_art != null else battle_trash_bin


func _setup_trash_bin_feedback() -> void:
	if trash_bin == null:
		return
	if not _trash_bin_base_scale_ready or _trash_bin_base_node != trash_bin:
		_trash_bin_base_scale = trash_bin.scale
		_trash_bin_base_node = trash_bin
		_trash_bin_base_scale_ready = true
	_sync_trash_bin_pivot()


func _sync_trash_bin_pivot() -> void:
	if trash_bin == null:
		return
	trash_bin.pivot_offset = trash_bin.size * 0.5


func _is_point_in_trash_drop_area(point: Vector2) -> bool:
	if trash_bin == null or not trash_bin.visible:
		return false
	var trash_rect := trash_bin.get_global_rect()
	if trash_rect.size.x <= 0.0 or trash_rect.size.y <= 0.0:
		return false
	if not _get_trash_drop_global_rect().has_point(point):
		return false
	return _is_point_on_trash_texture(point, trash_rect)


func _get_trash_drop_global_rect() -> Rect2:
	if trash_bin == null:
		return Rect2()
	var rect := trash_bin.get_global_rect()
	var inset := _get_trash_hit_inset_global(rect)
	var max_inset := rect.size * 0.45
	inset = Vector2(minf(inset.x, max_inset.x), minf(inset.y, max_inset.y))
	return Rect2(rect.position + inset, rect.size - inset * 2.0)


func _get_trash_hit_inset_global(rect: Rect2) -> Vector2:
	if trash_bin == null or trash_bin.size.x <= 0.0 or trash_bin.size.y <= 0.0:
		return trash_drop_hit_inset
	return Vector2(
		trash_drop_hit_inset.x * rect.size.x / trash_bin.size.x,
		trash_drop_hit_inset.y * rect.size.y / trash_bin.size.y
	)


func _is_point_on_trash_texture(point: Vector2, trash_rect: Rect2) -> bool:
	var image := _get_trash_hit_image()
	if image == null or image.is_empty():
		return true
	var normalized := Vector2(
		(point.x - trash_rect.position.x) / trash_rect.size.x,
		(point.y - trash_rect.position.y) / trash_rect.size.y
	)
	if normalized.x < 0.0 or normalized.x > 1.0 or normalized.y < 0.0 or normalized.y > 1.0:
		return false
	var pixel := Vector2i(
		clampi(floori(normalized.x * float(image.get_width())), 0, image.get_width() - 1),
		clampi(floori(normalized.y * float(image.get_height())), 0, image.get_height() - 1)
	)
	return image.get_pixelv(pixel).a >= trash_drop_alpha_threshold


func _get_trash_hit_image() -> Image:
	if not (trash_bin is TextureRect):
		return null
	var texture := (trash_bin as TextureRect).texture
	if texture == null:
		return null
	if _trash_hit_texture != texture:
		_trash_hit_texture = texture
		_trash_hit_image = texture.get_image()
	return _trash_hit_image


func _set_trash_bin_drag_hover(hovered: bool) -> void:
	if trash_bin == null:
		return
	_setup_trash_bin_feedback()
	if _trash_bin_drag_hovered == hovered:
		return
	_trash_bin_drag_hovered = hovered
	var target_scale := trash_drop_hover_scale if hovered else 1.0
	_animate_trash_bin_scale(_trash_bin_base_scale * target_scale, trash_drop_scale_duration)


func _play_trash_bin_discard_pulse() -> void:
	if trash_bin == null:
		return
	_setup_trash_bin_feedback()
	_trash_bin_drag_hovered = false
	_kill_trash_bin_tween()
	if not is_inside_tree():
		trash_bin.scale = _trash_bin_base_scale
		return
	_trash_bin_tween = create_tween()
	_trash_bin_tween.set_trans(Tween.TRANS_BACK)
	_trash_bin_tween.set_ease(Tween.EASE_OUT)
	_trash_bin_tween.tween_property(trash_bin, "scale", _trash_bin_base_scale * trash_drop_pulse_scale, trash_drop_scale_duration)
	_trash_bin_tween.tween_property(trash_bin, "scale", _trash_bin_base_scale, trash_drop_scale_duration)


func _animate_trash_bin_scale(target_scale: Vector2, duration: float) -> void:
	if trash_bin == null:
		return
	_kill_trash_bin_tween()
	if not is_inside_tree():
		trash_bin.scale = target_scale
		return
	_trash_bin_tween = create_tween()
	_trash_bin_tween.set_trans(Tween.TRANS_BACK)
	_trash_bin_tween.set_ease(Tween.EASE_OUT)
	_trash_bin_tween.tween_property(trash_bin, "scale", target_scale, duration)


func _kill_trash_bin_tween() -> void:
	if _trash_bin_tween != null and _trash_bin_tween.is_valid():
		_trash_bin_tween.kill()
	_trash_bin_tween = null

func _get_stage_bgm_key(key: String, fallback: String) -> String:
	var rm = _get_run_manager()
	if rm == null or not rm.has_method("get_current_stage_visual"):
		return fallback
	var visual = rm.get_current_stage_visual()
	var bgm_key = str(visual.get(key, fallback))
	return bgm_key if bgm_key != "" else fallback

func _apply_stage_visuals() -> void:
	var rm = _get_run_manager()
	if rm == null or not rm.has_method("get_current_stage_visual"):
		return
	var visual = rm.get_current_stage_visual()
	var tint = str(visual.get("ui_tint", ""))
	var background = get_node_or_null("Background")
	if tint != "" and background is ColorRect:
		background.color = Color.html(tint)
	_apply_dreamcatcher_stage_visual(visual)
	_configure_dreamcatcher_swing_pivot()
	_capture_dreamcatcher_net_pose()

func _apply_dreamcatcher_stage_visual(visual: Dictionary) -> void:
	if dreamcatcher_net == null:
		return
	var texture_path := str(visual.get("dreamcatcher_net_path", ""))
	if texture_path == "":
		return
	var texture := load(texture_path)
	if texture is Texture2D:
		dreamcatcher_net.texture = texture

func _layout_battle_scene() -> void:
	_select_active_backpack_ui()
	_layout_content_layer_as_fixed_frame(BATTLE_FRAME_SIZE)
	var background = get_node_or_null("Background")
	if background is ColorRect:
		background.visible = true
	if battle_art:
		battle_art.show()
	if not _intro_playing:
		_show_playable_bag_art()
	if battle_grid_panel:
		battle_grid_panel.show()
	_setup_trash_bin_feedback()
	_configure_dreamcatcher_swing_pivot()
	_capture_dreamcatcher_net_pose()

func _layout_current_scene() -> void:
	_layout_battle_scene()

func _capture_dreamcatcher_net_pose() -> void:
	if dreamcatcher_net == null:
		return
	_dreamcatcher_net_base_position = dreamcatcher_net.position
	_dreamcatcher_net_base_rotation = dreamcatcher_net.rotation
	_dreamcatcher_net_base_offset = dreamcatcher_net.offset

func _configure_dreamcatcher_swing_pivot() -> void:
	if dreamcatcher_net == null or dreamcatcher_net.texture == null:
		return
	var texture_size: Vector2 = dreamcatcher_net.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var visual_center: Vector2 = _get_dreamcatcher_net_visual_center()
	var pivot_distance: float = texture_size.y * DREAMCATCHER_SWING_PIVOT_DISTANCE_RATIO
	dreamcatcher_net.centered = true
	dreamcatcher_net.offset = Vector2(0.0, pivot_distance)
	dreamcatcher_net.position = visual_center - dreamcatcher_net.offset.rotated(dreamcatcher_net.rotation)

func _get_dreamcatcher_net_visual_center() -> Vector2:
	if dreamcatcher_panel is TextureRect and dreamcatcher_panel.texture != null:
		return dreamcatcher_panel.texture.get_size() * 0.5
	if dreamcatcher_net != null:
		return dreamcatcher_net.position + dreamcatcher_net.offset.rotated(dreamcatcher_net.rotation)
	return Vector2.ZERO

func _layout_content_layer_as_fixed_frame(base_size: Vector2, cover_viewport: bool = false) -> void:
	if content_layer == null:
		return
	content_layer.custom_minimum_size = base_size
	var scale_mode := DesignScaler.SCALE_MODE_COVER if cover_viewport else DesignScaler.SCALE_MODE_CONTAIN
	DesignScaler.layout_root(content_layer, get_viewport_rect().size, base_size, scale_mode)

func _on_game_over():
	if _is_battle_ended: return
	var gs = _get_game_state()
	if gs and gs.current_sanity > 0:
		return
	print("[MainGameUI] 收到梦值归零信号，正在按当前战斗规则结算...")
	if battle_manager and battle_manager.has_method("request_finish_battle"):
		battle_manager.request_finish_battle("sanity_depleted")
	else:
		_finish_battle_from_current_state()

func _on_defeat():
	if _is_battle_ended: return
	_is_battle_ended = true
	if battle_manager and battle_manager.has_method("mark_battle_finished"):
		battle_manager.mark_battle_finished()
	print("[MainGameUI] 未满足当前战斗目标，正在显示失败浮窗...")
	_show_result_popup(false)

func _on_victory():
	if _is_battle_ended: return
	_is_battle_ended = true
	if battle_manager and battle_manager.has_method("mark_battle_finished"):
		battle_manager.mark_battle_finished()
	print("[MainGameUI] 达成目标分数，正在显示胜利浮窗...")
	_show_result_popup(true)

func _on_battle_finish_requested(_reason: String):
	_finish_battle_from_current_state()

func _show_result_popup(is_victory: bool):
	# 自动清理背包外物品 (核心需求)
	if battle_manager:
		battle_manager.discard_all_outside_items()
		if battle_manager.has_method("persist_backpack_to_run"):
			battle_manager.persist_backpack_to_run()

	# 禁用背景输入
	GlobalInput.set_context(GlobalInput.Context.LOCKED)

	var popup_scene = load("res://src/ui/battle/result_popup.tscn")
	var popup = popup_scene.instantiate()
	add_child(popup)

	# 获取组件
	var title = popup.get_node("%TitleLabel")
	var popup_score_label = popup.get_node("%ScoreLabel")
	var btn = popup.get_node("%ConfirmButton")

	# 设置文本
	var gs = _get_game_state()
	var rm = _get_run_manager()
	var score_rule = _get_current_score_rule()
	var target_text = _format_target_text(score_rule.has_target, score_rule.target)

	if is_victory:
		title.text = "梦境圆满"
		title.add_theme_color_override("font_color", Color("#ec3073")) # 暖粉/金色
		popup_score_label.text = "最终得分: %d / %s" % [gs.current_score, target_text]
		var reward_options = _get_reward_options(rm)
		if reward_options.is_empty():
			btn.text = "继续梦境"
			btn.pressed.connect(func(): _complete_victory_route(rm))
		else:
			btn.hide()
			_add_reward_choices(popup, reward_options, rm)
	else:
		title.text = "梦境惊醒"
		title.add_theme_color_override("font_color", Color("#555555")) # 灰色
		popup_score_label.text = "遗憾离场 (得分: %d / %s)" % [gs.current_score, target_text]
		btn.text = "回到现实"
		btn.pressed.connect(func():
			if rm:
				rm.fail_run()
			_return_to_scene_with_embedded_support(GlobalScene.SceneType.MAIN_MENU, false)
		)

func _get_reward_options(rm) -> Array[Dictionary]:
	if rm == null or not rm.has_method("generate_current_reward_options"):
		return []
	var item_db = _get_item_database()
	var ornament_db = _get_ornament_database()
	var option_count = 4 if _has_empty_dream_trophy_bonus(rm) else 3
	return rm.generate_current_reward_options(item_db, ornament_db, option_count)

func _has_empty_dream_trophy_bonus(rm) -> bool:
	var gs = _get_game_state()
	if rm == null or gs == null:
		return false
	if rm.has_method("has_empty_dream_trophy_reward_bonus"):
		return rm.has_empty_dream_trophy_reward_bonus(gs.current_score)
	if not Array(rm.current_ornaments).has("empty_dream_trophy"):
		return false
	var score_rule = _get_current_score_rule()
	return bool(score_rule.get("has_target", false)) and gs.current_score > int(score_rule.get("target", -1)) + 50

func _add_reward_choices(popup: Control, reward_options: Array[Dictionary], rm) -> void:
	var panel = popup.get_node("Panel")
	panel.custom_minimum_size = Vector2(640, 360)
	panel.offset_left = -320.0
	panel.offset_top = -180.0
	panel.offset_right = 320.0
	panel.offset_bottom = 180.0

	var container = popup.get_node("Panel/VBoxContainer")
	var reward_row = HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 12)
	container.add_child(reward_row)
	container.move_child(reward_row, max(0, container.get_child_count() - 2))

	for reward in reward_options:
		var reward_button = Button.new()
		reward_button.custom_minimum_size = Vector2(180, 92)
		reward_button.text = _format_reward_button_text(reward)
		reward_button.tooltip_text = str(reward.get("description", ""))
		reward_button.pressed.connect(func():
			if rm and rm.has_method("apply_reward"):
				var item_db = _get_item_database()
				rm.apply_reward(reward, item_db)
			_complete_victory_route(rm)
		)
		reward_row.add_child(reward_button)

func _format_reward_button_text(reward: Dictionary) -> String:
	var title = str(reward.get("title", "奖励"))
	var reward_type = str(reward.get("type", ""))
	match reward_type:
		"item":
			return "%s\n物品/%s" % [title, _format_item_destination(reward)]
		"ornament":
			return "%s\n%s饰品" % [title, str(reward.get("rarity", ""))]
		"tool":
			return "%s\n%s" % [title, str(reward.get("rarity", "道具"))]
		"shards":
			return title
	return title

func _format_item_destination(data: Dictionary) -> String:
	match str(data.get("item_destination", data.get("destination", "deck"))):
		"backpack":
			return "入背包"
		"staging":
			return "暂存"
	return "入卡组"

func _complete_victory_route(rm) -> void:
	if rm:
		rm.win_battle(0)
	var next_scene = GlobalScene.SceneType.MAIN_MENU if rm and rm.is_run_complete else GlobalScene.SceneType.HUB
	_return_to_scene_with_embedded_support(next_scene, false)

func _on_item_drawn(item_data: ItemData):
	var item_ui_scene = load("res://src/ui/item/item_ui.tscn")
	var card = item_ui_scene.instantiate()

	# 将卡牌放入 UI 层
	add_child(card)
	card.setup(item_data, battle_manager.context)
	_configure_item_ui_for_backpack_grid(card)

	# 注册到管理器以便自动清理
	if battle_manager:
		battle_manager.managed_item_uis.append(card)

	card.scale = Vector2.ONE

	# 初始位置：抽卡区中心
	card.global_position = _get_draw_spawn_position(card)
	_play_item_spawn_animation(card)

	# 连接拖拽信号
	_connect_item_ui_signals(card)

func _configure_item_ui_for_backpack_grid(card: Control) -> void:
	if card == null or backpack_ui == null or not backpack_ui.has_method("configure_item_for_grid"):
		return
	backpack_ui.configure_item_for_grid(card, card.get_parent())

func _get_backpack_grid_pos_at(mouse_pos: Vector2) -> Vector2i:
	if backpack_ui == null or not backpack_ui.has_method("get_grid_pos_at"):
		return Vector2i(-1, -1)
	return backpack_ui.get_grid_pos_at(mouse_pos)

func _add_item_visual_to_backpack(card: Control, root_pos: Vector2i) -> void:
	if backpack_ui == null or not backpack_ui.has_method("add_item_visual"):
		return
	backpack_ui.add_item_visual(card, root_pos)

func _highlight_backpack_placement(root_grid_pos: Vector2i, item_data: ItemData) -> void:
	if backpack_ui == null or not backpack_ui.has_method("highlight_placement"):
		return
	backpack_ui.highlight_placement(root_grid_pos, item_data)

func _update_backpack_slot_visuals() -> void:
	if backpack_ui == null or not backpack_ui.has_method("update_slot_visuals"):
		return
	backpack_ui.update_slot_visuals()

func _clear_backpack_placement_highlight() -> void:
	if backpack_ui != null and backpack_ui.has_method("clear_placement_highlight"):
		backpack_ui.clear_placement_highlight()
	else:
		_update_backpack_slot_visuals()

func _reset_drag_highlight_tracking() -> void:
	_last_drag_root_grid_pos = Vector2i(-999999, -999999)
	_last_drag_item_id = 0
	_last_drag_over_trash = false

func _get_drag_item_id(item_ui: Control) -> int:
	return int(item_ui.get_instance_id()) if item_ui != null else 0

func _render_existing_backpack_items():
	if not battle_manager or not backpack_ui:
		return
	var item_ui_scene = load("res://src/ui/item/item_ui.tscn")
	for instance in battle_manager.backpack_manager.get_all_instances():
		var card = item_ui_scene.instantiate()
		add_child(card)
		card.setup(instance.data, battle_manager.context)
		card.item_instance = instance
		battle_manager.managed_item_uis.append(card)
		_connect_item_ui_signals(card)
		_add_item_visual_to_backpack(card, instance.root_pos)

func _render_pending_items():
	if pending_item_panel == null or pending_item_area == null:
		return
	var rm = _get_run_manager()
	var item_db = _get_item_database()
	if rm == null or item_db == null or not rm.has_method("get_pending_item_rewards"):
		PendingItemPresenter.clear(pending_item_panel, pending_item_area)
		return
	var pending_items = rm.get_pending_item_rewards()
	var card_context = battle_manager.context if battle_manager != null else null
	PendingItemPresenter.render(pending_item_panel, pending_item_area, pending_items, item_db, card_context, Callable(self, "_connect_item_ui_signals"))

func _render_ornaments():
	if ornaments_area == null:
		return
	for child in ornaments_area.get_children():
		child.queue_free()
	var rm = _get_run_manager()
	var ornament_db = _get_ornament_database()
	if rm == null or ornament_db == null:
		return
	for ornament_id in rm.current_ornaments:
		var ornament = ornament_db.get_ornament_by_id(ornament_id)
		if ornament == null:
			continue
		var slot = Button.new()
		slot.custom_minimum_size = Vector2(54, 54)
		slot.text = ornament.ornament_name.substr(0, min(2, ornament.ornament_name.length()))
		slot.tooltip_text = ornament.get_tooltip_text()
		slot.focus_mode = Control.FOCUS_NONE
		slot.flat = true
		slot.set_meta("ornament_id", ornament.id)
		ornaments_area.add_child(slot)

func _ensure_tool_panel() -> void:
	tool_panel = get_node_or_null("ContentLayer/ToolPanel")
	tool_slot_area = get_node_or_null("ContentLayer/ToolPanel/ToolSlots")
	if tool_panel == null or tool_slot_area == null:
		push_warning("[MainGameUI] ToolPanel/ToolSlots missing from main_game_ui.tscn.")

func _connect_tool_inventory_signal() -> void:
	var rm = _get_run_manager()
	if rm != null and rm.has_signal("tools_changed") and not rm.tools_changed.is_connected(_on_tools_changed):
		rm.tools_changed.connect(_on_tools_changed)

func _on_tools_changed(_current_tools: Dictionary) -> void:
	_render_tools()

func _render_tools() -> void:
	_ensure_tool_panel()
	if tool_panel == null or tool_slot_area == null:
		return
	var rm = _get_run_manager()
	var tool_db = _get_tool_database()
	if rm == null or tool_db == null or not rm.has_method("get_tool_inventory_entries"):
		ToolPanelPresenter.clear(tool_panel, tool_slot_area)
		return
	var entries = rm.get_tool_inventory_entries(tool_db)
	if entries.is_empty():
		_selected_tool_id = ""
	ToolPanelPresenter.render(tool_panel, tool_slot_area, entries, tool_db, _selected_tool_id, Callable(self, "_on_tool_button_gui_input"))
	_layout_current_scene()

func _set_selected_tool(tool_id: String) -> void:
	_selected_tool_id = "" if _selected_tool_id == tool_id else tool_id
	_update_tool_selection_visuals()

func _update_tool_selection_visuals() -> void:
	ToolPanelPresenter.update_selection_visuals(tool_slot_area, _selected_tool_id)

func _on_tool_button_gui_input(event: InputEvent, tool_id: String, button: Button) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragged_tool_id = tool_id
			_tool_drag_start = _get_tool_event_position(event, button)
		elif _dragged_tool_id == tool_id:
			var dragged_far = _tool_drag_start.distance_to(_get_tool_event_position(event, button)) > 8.0
			_dragged_tool_id = ""
			if not dragged_far:
				_set_selected_tool(tool_id)
				var viewport = get_viewport()
				if viewport != null:
					viewport.set_input_as_handled()

func _get_tool_event_position(event: InputEventMouseButton, button: Button) -> Vector2:
	if button != null and button.is_inside_tree():
		return button.get_global_transform() * event.position
	return event.position

func _try_use_tool_at_mouse(tool_id: String, mouse_pos: Vector2) -> bool:
	if battle_manager == null or not battle_manager.has_method("request_use_tool"):
		return false
	var target = _make_tool_target_at(mouse_pos)
	if target.is_empty():
		return false
	var used = battle_manager.request_use_tool(tool_id, target)
	if used:
		_selected_tool_id = ""
		_render_tools()
	return used

func _make_tool_target_at(mouse_pos: Vector2) -> Dictionary:
	if dreamcatcher_panel != null and dreamcatcher_panel.get_global_rect().has_point(mouse_pos):
		return {"type": "dreamcatcher"}
	if ornaments_area != null and ornaments_area.get_global_rect().has_point(mouse_pos):
		for child in ornaments_area.get_children():
			if child is Control and child.get_global_rect().has_point(mouse_pos) and child.has_meta("ornament_id"):
				return {"type": "ornament", "ornament_id": str(child.get_meta("ornament_id"))}
		return {}
	if _is_point_in_trash_drop_area(mouse_pos):
		return {"type": "discard"}
	if backpack_ui != null and battle_manager != null:
		var grid_pos = _get_backpack_grid_pos_at(mouse_pos)
		if grid_pos != Vector2i(-1, -1):
			if battle_manager.backpack_manager.grid.has(grid_pos):
				return {
					"type": "item",
					"instance": battle_manager.backpack_manager.grid[grid_pos],
					"x": grid_pos.x,
					"y": grid_pos.y,
				}
			return {"type": "empty_cell", "x": grid_pos.x, "y": grid_pos.y}
	return {}

func _is_point_in_tool_panel(point: Vector2) -> bool:
	return tool_panel != null and tool_panel.visible and tool_panel.get_global_rect().has_point(point)

func _connect_item_ui_signals(card: Control):
	card.dropped.connect(func(_mouse_pos, _pivot): _handle_item_dropped(card, _mouse_pos, _pivot))
	card.drag_moved.connect(func(_item_ui, _mouse_pos, _pivot): _handle_item_dragged(_item_ui, _mouse_pos, _pivot))
	card.rotation_requested.connect(_handle_item_rotation_requested)

func _handle_item_dragged(item_ui: Control, mouse_pos: Vector2, item_pivot_offset: Vector2i):
	var drag_item_id := _get_drag_item_id(item_ui)
	var over_trash := _is_point_in_trash_drop_area(mouse_pos)
	_set_trash_bin_drag_hover(over_trash)
	if over_trash:
		if _last_drag_item_id != drag_item_id or not _last_drag_over_trash:
			_update_backpack_slot_visuals()
			_last_drag_root_grid_pos = Vector2i(-1, -1)
		_last_drag_item_id = drag_item_id
		_last_drag_over_trash = true
		return
	var mouse_grid_pos = _get_backpack_grid_pos_at(mouse_pos)
	var root_grid_pos = mouse_grid_pos - item_pivot_offset if mouse_grid_pos != Vector2i(-1, -1) else Vector2i(-1, -1)
	if _last_drag_item_id == drag_item_id and _last_drag_root_grid_pos == root_grid_pos and not _last_drag_over_trash:
		return
	_last_drag_item_id = drag_item_id
	_last_drag_root_grid_pos = root_grid_pos
	_last_drag_over_trash = false
	_highlight_backpack_placement(root_grid_pos, item_ui.item_data)

func _handle_item_rotation_requested(item_ui: Control, mouse_global_pos: Vector2, item_pivot_offset: Vector2i):
	_clear_backpack_placement_highlight()
	_reset_drag_highlight_tracking()
	if battle_manager and battle_manager.has_method("request_rotate_item"):
		battle_manager.request_rotate_item(item_ui, mouse_global_pos, item_pivot_offset)

func _handle_item_dropped(item_ui: Control, mouse_pos: Vector2, item_pivot_offset: Vector2i):
	_reset_drag_highlight_tracking()
	_update_backpack_slot_visuals() # 清除高亮

	# 1. 检查是否掉落在垃圾桶
	if _is_point_in_trash_drop_area(mouse_pos):
		_play_trash_bin_discard_pulse()
		if battle_manager:
			battle_manager.request_discard_item(item_ui)
		return
	_set_trash_bin_drag_hover(false)

	# 2. 检查是否掉落在饰品区
	if ornaments_area.get_global_rect().has_point(mouse_pos):
		if battle_manager and battle_manager.has_method("request_equip_ornament"):
			battle_manager.request_equip_ornament(item_ui)
		return

	# 3. 计算 root_pos 并交给管理器
	var mouse_grid_pos = _get_backpack_grid_pos_at(mouse_pos)
	var root_grid_pos = mouse_grid_pos - item_pivot_offset if mouse_grid_pos != Vector2i(-1, -1) else Vector2i(-1, -1)

	battle_manager.request_place_item(item_ui, root_grid_pos)
	_consume_pending_item_if_placed(item_ui)

func _consume_pending_item_if_placed(item_ui: Control) -> void:
	if not item_ui.has_meta("pending_item_uid"):
		return
	if item_ui.get("item_instance") == null:
		return
	var rm = _get_run_manager()
	if rm and rm.has_method("consume_pending_item"):
		rm.consume_pending_item(int(item_ui.get_meta("pending_item_uid")))
	item_ui.remove_meta("pending_item_uid")
	if battle_manager and not battle_manager.managed_item_uis.has(item_ui):
		battle_manager.managed_item_uis.append(item_ui)
	if battle_manager and battle_manager.has_method("persist_backpack_to_run"):
		battle_manager.persist_backpack_to_run()
	if pending_item_panel:
		pending_item_panel.visible = rm and rm.has_method("get_pending_item_rewards") and not rm.get_pending_item_rewards().is_empty()

func _on_draw_button_pressed():
	if not _is_draw_interaction_available():
		return
	_set_draw_locked(true)
	await _play_dreamcatcher_animation()
	if battle_manager and not _is_battle_ended:
		await battle_manager.request_draw()
	if not _is_battle_ended:
		_set_draw_locked(false)

func _input(event):
	if not visible:
		return
	if _intro_playing:
		return
	# 输入权限检查
	if not GlobalInput.can_cancel() or _is_battle_ended: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		if not event.pressed and _dragged_tool_id != "":
			var tool_id = _dragged_tool_id
			var dragged_far = _tool_drag_start.distance_to(mouse_pos) > 8.0
			_dragged_tool_id = ""
			if dragged_far and not _is_point_in_tool_panel(mouse_pos):
				_try_use_tool_at_mouse(tool_id, mouse_pos)
				get_viewport().set_input_as_handled()
				return
		elif event.pressed and _selected_tool_id != "" and not _is_point_in_tool_panel(mouse_pos):
			_try_use_tool_at_mouse(_selected_tool_id, mouse_pos)
			get_viewport().set_input_as_handled()
			return

	# ESC 键撤退回整备室
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		_return_to_hub()
		get_viewport().set_input_as_handled()

func _on_menu_button_pressed():
	if battle_manager and battle_manager.has_method("request_finish_battle"):
		battle_manager.request_finish_battle("manual")
	else:
		_finish_battle_from_current_state()

func _is_draw_interaction_available() -> bool:
	return not _intro_playing and not _is_battle_ended and not _draw_locked and battle_manager != null and battle_manager.battle_state == BattleManager.BattleState.INTERACTIVE

func _set_draw_locked(locked: bool) -> void:
	_draw_locked = locked
	_sync_draw_button_state()

func _sync_draw_button_state() -> void:
	if draw_button:
		draw_button.disabled = _intro_playing or _draw_locked or _is_battle_ended or battle_manager == null or battle_manager.battle_state != BattleManager.BattleState.INTERACTIVE

func _play_dreamcatcher_animation() -> void:
	if dreamcatcher_net == null or not is_inside_tree():
		return
	dreamcatcher_net.position = _dreamcatcher_net_base_position
	dreamcatcher_net.rotation = _dreamcatcher_net_base_rotation
	dreamcatcher_net.offset = _dreamcatcher_net_base_offset

	var base_position := _dreamcatcher_net_base_position
	var base_rotation := _dreamcatcher_net_base_rotation
	var base_offset := _dreamcatcher_net_base_offset
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(dreamcatcher_net, "rotation", base_rotation - 0.085, 0.16)
	tween.tween_property(dreamcatcher_net, "rotation", base_rotation + 0.075, 0.2)
	tween.tween_property(dreamcatcher_net, "rotation", base_rotation - 0.048, 0.17)
	tween.tween_property(dreamcatcher_net, "rotation", base_rotation + 0.022, 0.14)
	tween.tween_property(dreamcatcher_net, "rotation", base_rotation, 0.12)
	await tween.finished
	dreamcatcher_net.position = base_position
	dreamcatcher_net.rotation = base_rotation
	dreamcatcher_net.offset = base_offset

func _get_draw_spawn_position(card: Control) -> Vector2:
	var spawn_center: Vector2
	if draw_spawn_point:
		spawn_center = draw_spawn_point.global_position + draw_spawn_point.size / 2.0
	else:
		spawn_center = dreamcatcher_panel.global_position + (dreamcatcher_panel.size * dreamcatcher_panel.scale) / 2.0
	return spawn_center - (card.size * card.scale) / 2.0

func _play_item_spawn_animation(card: Control) -> void:
	card.modulate.a = 0.0
	var target_scale = card.scale
	card.scale = target_scale * 0.65
	var tween = create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(card, "scale", target_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 根据当前得分评估并结束战斗 (满足手动结束按钮需求)
func _evaluate_and_end_battle():
	if battle_manager and battle_manager.has_method("request_finish_battle"):
		battle_manager.request_finish_battle("manual")
	else:
		_finish_battle_from_current_state()

func _finish_battle_from_current_state():
	if _is_battle_ended: return

	var gs = _get_game_state()
	var rm = _get_run_manager()
	var score_rule = _get_current_score_rule()

	print("[MainGameUI] 正在结束战斗. 当前得分: ", gs.current_score, " 目标: ", _format_target_text(score_rule.has_target, score_rule.target))

	if rm and rm.has_method("is_current_battle_score_success"):
		if rm.is_current_battle_score_success(gs.current_score):
			_on_victory()
		else:
			_on_defeat()
	elif not score_rule.has_target or gs.current_score >= score_rule.target:
		_on_victory()
	else:
		_on_defeat()

func _return_to_hub():
	_return_to_scene_with_embedded_support(GlobalScene.SceneType.HUB, false)

func _on_sanity_changed(new_val):
	var gs = _get_game_state()
	if gs:
		_update_stats_display(new_val, gs.current_score)

func _on_score_changed(new_val):
	var gs = _get_game_state()
	if gs:
		_update_stats_display(gs.current_sanity, new_val)
	_try_request_boss_finish_on_target_reached(new_val)

func _try_request_boss_finish_on_target_reached(score: int, run_manager = null) -> void:
	if _is_battle_ended or battle_manager == null:
		return
	if battle_manager.battle_state == BattleManager.BattleState.FINISHING or battle_manager.battle_state == BattleManager.BattleState.FINISHED:
		return
	var rm = run_manager if run_manager != null else _get_run_manager()
	if rm == null or not rm.has_method("get_current_battle_config"):
		return
	var config = rm.get_current_battle_config()
	if not bool(config.get("is_boss", false)) or not bool(config.get("has_score_target", false)):
		return
	var target_score := int(config.get("target_score", -1))
	if target_score < 0 or score < target_score:
		return
	battle_manager.request_finish_battle("score_target_reached")

func _update_stats_display(san, score):
	var gs = _get_game_state()
	var score_rule = _get_current_score_rule()
	var max_san = gs.max_sanity if gs else 100
	_apply_stats_display(san, score, max_san, score_rule)

func _apply_stats_display(san: int, score: int, max_san: int, score_rule: Dictionary):
	var sanity_ratio := 0.0
	if max_san > 0:
		sanity_ratio = clampf(float(san) / float(max_san), 0.0, 1.0)
	_apply_potion_state(sanity_ratio)
	if sanity_label:
		var sanity_percent := roundi(sanity_ratio * 100.0)
		_set_stat_label_text(sanity_label, str(sanity_percent) + "%", STATS_FONT_SIZE_SANITY, 4)
		# 梦值低时变红
		if san <= max_san * 0.2:
			sanity_label.add_theme_color_override("font_color", STATS_LOW_SANITY_COLOR)
		else:
			sanity_label.add_theme_color_override("font_color", STATS_DARK_COLOR)

	if score_label:
		_set_stat_label_text(score_label, str(score), STATS_FONT_SIZE_SCORE)
		# 有目标且达成时变绿；无目标时保持默认深色。
		if score_rule.has_target and score >= score_rule.target:
			score_label.add_theme_color_override("font_color", STATS_SCORE_REACHED_COLOR)
		else:
			score_label.add_theme_color_override("font_color", STATS_DARK_COLOR)
	if target_score_label:
		_set_stat_label_text(target_score_label, _format_target_text(score_rule.has_target, score_rule.target), STATS_FONT_SIZE_TARGET)
		target_score_label.add_theme_color_override("font_color", STATS_DARK_COLOR)

func _apply_potion_state(sanity_ratio: float) -> void:
	if potion_bag == null:
		return
	if not _ensure_potion_state_textures():
		return
	var state_index := mini(_get_potion_state_index(sanity_ratio), _potion_state_textures.size() - 1)
	potion_bag.texture = _potion_state_textures[state_index]


func _ensure_potion_state_textures() -> bool:
	if _potion_state_textures.is_empty():
		_potion_state_textures = AssetPaths.load_texture_list(PackedStringArray(AssetPaths.POTION_STATE_PATHS))
	return not _potion_state_textures.is_empty()

func _get_potion_state_index(sanity_ratio: float) -> int:
	var ratio := clampf(sanity_ratio, 0.0, 1.0)
	if ratio >= 0.8:
		return 0
	if ratio >= 0.6:
		return 1
	if ratio >= 0.4:
		return 2
	if ratio >= 0.2:
		return 3
	return 4

func _set_stat_label_text(label: Label, text: String, base_font_size: int, full_size_length: int = 3) -> void:
	label.text = text
	var font_size := base_font_size
	if text.length() > full_size_length:
		font_size = maxi(STATS_FONT_SIZE_MIN, roundi(float(base_font_size) * float(full_size_length) / float(text.length())))
	label.add_theme_font_size_override("font_size", font_size)

func _get_current_score_rule() -> Dictionary:
	var rm = _get_run_manager()
	if rm and rm.has_method("get_current_battle_config"):
		var config = rm.get_current_battle_config()
		return {
			"has_target": bool(config.get("has_score_target", false)),
			"target": int(config.get("target_score", -1))
		}
	return {
		"has_target": true,
		"target": 50
	}

func _format_target_text(has_target: bool, target: int) -> String:
	if not has_target or target < 0:
		return "无"
	return str(target)

func _get_game_state():
	if game_state_override != null:
		return game_state_override
	return get_node_or_null("/root/GameState")

func _get_run_manager():
	if run_manager_override != null:
		return run_manager_override
	return get_node_or_null("/root/RunManager")

func _get_item_database():
	if item_database_override != null:
		return item_database_override
	return get_node_or_null("/root/ItemDatabase")

func _get_tool_database():
	if tool_database_override != null:
		return tool_database_override
	return get_node_or_null("/root/ToolDatabase")

func _get_ornament_database():
	if ornament_database_override != null:
		return ornament_database_override
	return get_node_or_null("/root/OrnamentDatabase")
