@tool
extends Node2D

const AssetPaths = preload("res://src/core/assets/asset_paths.gd")
const RouteConfig = preload("res://src/core/route/route_config.gd")
const BookBackgroundConfig = preload("res://src/ui/book/book_background_config.gd")
const BookPageNavigator = preload("res://src/ui/book/book_page_navigator.gd")

const PAGE_MAIN_MENU := BookPageNavigator.PAGE_MAIN_MENU
const HUB_SOURCE_SIZE := BookBackgroundConfig.DESIGN_SIZE
const DEFAULT_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const DREAMCATCHER_SWING_PIVOT_DISTANCE_RATIO: float = 0.82
const PLAYER_START_SOURCE_X := 548.0
const PLAYER_FLOOR_SOURCE_Y := 1000.0
const PLAYER_FLOOR_OFFSET := 64.0
const PLAYER_WALK_MIN_SOURCE_X := 410.0
const PLAYER_WALK_MAX_SOURCE_X := 1640.0
const AUTO_INTERACTION_ROUTE := "route"
const AUTO_INTERACTION_GALLERY := "gallery"
const AUTO_INTERACTION_MERCHANT := "merchant"
const LEFT_BOOKMARK_BUTTON_PATHS := [
	"CanvasLayer/DesignRoot/RouteButton",
	"CanvasLayer/DesignRoot/BackpackButton",
	"CanvasLayer/DesignRoot/GalleryButton",
	"CanvasLayer/DesignRoot/SettingsButton",
	"CanvasLayer/DesignRoot/MainMenuButton",
]
const HUB_LEFT_TAB_BUTTONS := {
	BookBackgroundConfig.PAGE_HUB: "RouteButton",
	BookBackgroundConfig.PAGE_BACKPACK: "BackpackButton",
	BookBackgroundConfig.PAGE_GALLERY: "GalleryButton",
	BookBackgroundConfig.PAGE_SETTINGS: "SettingsButton",
}
const HUB_LEFT_TAB_NODES := {
	BookBackgroundConfig.PAGE_HUB: "AlbumTab",
	BookBackgroundConfig.PAGE_BACKPACK: "BackpackTab",
	BookBackgroundConfig.PAGE_GALLERY: "GalleryTab",
	BookBackgroundConfig.PAGE_SETTINGS: "SettingsTab",
}
const HUB_BACK_TAB_BUTTON := "MainMenuButton"
const ROUTE_INTERACTION_SOURCE_X := 1326.0
const GALLERY_INTERACTION_SOURCE_X := 771.0
const HUB_BATTLE_LAYER_NAME := "BattleLayer"
const HUB_TO_BATTLE_FOCUS_ZOOM := 1.55
const HUB_TO_BATTLE_FOCUS_DURATION := 0.72
const HUB_TO_BATTLE_MIN_FOCUS_ZOOM := 1.05
const HUB_TO_BATTLE_BOARD_TARGET_UV := Vector2(0.24, 0.35)
const HUB_TO_BATTLE_BOARD_BOTTOM_LOCK_OFFSET := 0.0
const INVALID_HUB_POINT := Vector2(1.0e20, 1.0e20)
const DEFAULT_SPEECH_TEXT := "你终于醒了！"
const MERCHANT_FRAME_BOUNDS := {
	"cat": Rect2(1236.0, 467.0, 293.0, 367.0),
	"grandma": Rect2(1295.0, 459.0, 377.0, 476.0),
	"stage": Rect2(1162.0, 715.0, 372.0, 365.0),
}
const MERCHANT_ANIMATION_SPEED := 6.0
const MERCHANT_INTERACTION_SOURCE_OFFSET_X := -313.0
const MERCHANT_INTERACTION_REACH_DISTANCE := 18.0
const MERCHANT_INTERACTION_EXIT_PADDING_SOURCE_X := 58.0


func _first_existing_node(paths: Array[String]) -> Node:
	for path in paths:
		var node := get_node_or_null(path)
		if node != null:
			return node
	return null


@export var hub_art_source_offset := Vector2(0.0, 14.0):
	set(value):
		hub_art_source_offset = value
		if Engine.is_editor_hint() and is_node_ready():
			_layout_scene()

@onready var book_canvas_layer: CanvasLayer = $BookCanvasLayer
@onready var book_design_root: Control = $BookCanvasLayer/BookDesignRoot
@onready var book_background: Control = $BookCanvasLayer/BookDesignRoot/BookBackground
@onready var hub_art: Node2D = $HubArt
@onready var hub_board_viewport: Control = _first_existing_node(["HubArt/BoardViewport"]) as Control
@onready var hub_board_content: Node = _first_existing_node(["HubArt/BoardViewport/BoardContent", "HubArt"])
@onready var canvas_design_root: Control = $CanvasLayer/DesignRoot
@onready var overlay_root: Control = $CanvasLayer/OverlayRoot
@onready var player: CharacterBody2D = $Player
@onready var floor_body: StaticBody2D = $Floor
@onready var interactions: Node2D = $Interactions
@onready var room_art: Sprite2D = _first_existing_node(["HubArt/BoardViewport/BoardContent/Room", "HubArt/Room"]) as Sprite2D
@onready var foreground_art: Sprite2D = _first_existing_node(["HubArt/BoardViewport/BoardContent/Foreground", "HubArt/Foreground"]) as Sprite2D
@onready var speech_bubble: Sprite2D = _first_existing_node(["HubArt/BoardViewport/BoardContent/SpeechBubble", "HubArt/SpeechBubble"]) as Sprite2D
@onready var speech_text: Label = _first_existing_node(["HubArt/BoardViewport/BoardContent/SpeechText", "HubArt/SpeechText"]) as Label
@onready var dreamcatcher_net: Sprite2D = _first_existing_node(["HubArt/BoardViewport/BoardContent/DreamcatcherNet", "HubArt/DreamcatcherNet"]) as Sprite2D
@onready var merchant_sprite: AnimatedSprite2D = _first_existing_node(["HubArt/BoardViewport/BoardContent/MerchantSprite", "HubArt/MerchantSprite"]) as AnimatedSprite2D
@onready var merchant_button: Button = $CanvasLayer/DesignRoot/MerchantButton
@onready var dreamcatcher_button: Button = $CanvasLayer/DesignRoot/DreamcatcherButton
@onready var book_page_navigator: Control = $CanvasLayer/BookPageNavigator
@onready var battle_layer: Control = get_node_or_null("CanvasLayer/" + HUB_BATTLE_LAYER_NAME) as Control

var current_zone: String = ""
var _book_origin: Vector2 = Vector2.ZERO
var _art_origin: Vector2 = Vector2.ZERO
var _art_scale: float = 1.0
var _has_positioned_player := false
var _default_room_texture: Texture2D = null
var _default_room_position := Vector2.ZERO
var _default_room_scale := Vector2.ONE
var _default_room_display_size := Vector2.ZERO
var _dreamcatcher_button_source_position := Vector2.ZERO
var _dreamcatcher_button_source_size := Vector2.ZERO
var _merchant_frames_cache: Dictionary = {}
var _hub_background_textures: Dictionary = {}
var _hub_foreground_textures: Dictionary = {}
var _pending_auto_interaction := ""
var _is_player_at_merchant := false
var _hub_source_size := HUB_SOURCE_SIZE
var _hub_page_visual_root: Control = null
var _hub_transition_player_frozen := false
var _hub_transition_player_process_mode := Node.PROCESS_MODE_INHERIT
var _dreamcatcher_net_base_position := Vector2.ZERO
var _dreamcatcher_net_base_rotation := 0.0
var _dreamcatcher_net_base_offset := Vector2.ZERO
var _dreamcatcher_idle_tween: Tween = null
var _is_dreamcatcher_transition_pending := false
var _hub_battle_manager: BattleManager = null
var _is_hub_battle_session_active := false
var _hub_focus_layer_base_transforms: Dictionary = {}


func _ready() -> void:
	_cache_layout_source_data()
	_capture_default_hub_room_art()
	_setup_hub_page_visual_root()
	if Engine.is_editor_hint():
		_sync_editor_preview_state()
		_layout_scene()
		return

	if battle_layer != null:
		battle_layer.visible = false
		battle_layer.z_index = 40
		if _has_node_property(battle_layer, "auto_initialize"):
			battle_layer.set("auto_initialize", false)

	print("[Hub] Entered dream route.")
	_hub_background_textures = AssetPaths.load_texture_map(AssetPaths.HUB_BACKGROUND_PATHS)
	_hub_foreground_textures = AssetPaths.load_texture_map(AssetPaths.HUB_FOREGROUND_PATHS)
	GlobalInput.set_context(GlobalInput.Context.WORLD)
	GlobalAudio.play_bgm(_get_stage_bgm_key("hub_bgm_key", "hub"))
	_hide_speech()

	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.has_signal("route_changed"):
		var route_changed_callback := Callable(self, "_on_route_changed")
		if not rm.route_changed.is_connected(route_changed_callback):
			rm.route_changed.connect(route_changed_callback)
	_apply_stage_hub_background()
	_apply_hub_dreamcatcher_stage_visual()
	_configure_hub_dreamcatcher_swing_pivot()
	_capture_hub_dreamcatcher_pose()

	if rm and rm.is_run_complete:
		GlobalScene.transition_to(GlobalScene.SceneType.MAIN_MENU, false)
		return

	if interactions:
		interactions.hide()
	if get_viewport():
		get_viewport().size_changed.connect(_layout_scene)
	_layout_scene()
	if book_background != null and book_background.has_method("set_active_page_id"):
		book_background.call("set_active_page_id", BookBackgroundConfig.PAGE_HUB)
	if book_page_navigator != null and book_page_navigator.has_method("configure"):
		book_page_navigator.configure(self)
	_update_merchant_state()
	_update_dreamcatcher_state()
	_start_hub_dreamcatcher_idle_swing()
	var target_reached_callback := Callable(self, "_on_player_move_target_reached")
	if player != null and player.has_signal("move_target_reached") and not player.is_connected("move_target_reached", target_reached_callback):
		player.connect("move_target_reached", target_reached_callback)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _is_book_hub_current():
		return
	_sync_merchant_presence_state()


func _exit_tree() -> void:
	_stop_hub_dreamcatcher_idle_swing()


func _get_stage_bgm_key(key: String, fallback: String) -> String:
	var visual := _get_stage_visual()
	var bgm_key = str(visual.get(key, fallback))
	return bgm_key if bgm_key != "" else fallback


func _get_stage_visual() -> Dictionary:
	var rm = get_node_or_null("/root/RunManager")
	if rm == null or not rm.has_method("get_current_stage_visual"):
		return {}
	var visual = rm.get_current_stage_visual()
	return Dictionary(visual).duplicate(true) if visual is Dictionary else {}


func _on_route_changed(_current_act: int, _route_index: int, _current_node: Dictionary) -> void:
	_apply_stage_hub_background()
	_apply_hub_dreamcatcher_stage_visual()
	_configure_hub_dreamcatcher_swing_pivot()
	_capture_hub_dreamcatcher_pose()
	_update_dreamcatcher_state()
	_start_hub_dreamcatcher_idle_swing()
	_update_merchant_state()


func _capture_default_hub_room_art() -> void:
	if room_art == null or _default_room_texture != null:
		return
	_default_room_texture = room_art.texture
	_default_room_position = room_art.position
	_default_room_scale = room_art.scale
	if _default_room_texture != null:
		_default_room_display_size = _default_room_texture.get_size() * _default_room_scale


func _cache_layout_source_data() -> void:
	_hub_source_size = BookBackgroundConfig.DESIGN_SIZE
	if dreamcatcher_button != null:
		_dreamcatcher_button_source_position = dreamcatcher_button.position
		_dreamcatcher_button_source_size = dreamcatcher_button.size


func _apply_stage_hub_background() -> void:
	var rm = get_node_or_null("/root/RunManager")
	if rm == null or not bool(rm.get("is_run_active")):
		_restore_default_hub_background()
		_update_merchant_state()
		return

	var visual := _get_stage_visual()
	var configured_path := str(visual.get("hub_background_path", ""))
	var background_key := _normalize_hub_background_key(str(visual.get("hub_background_key", "")))
	if configured_path == "" and background_key == "":
		_restore_default_hub_background()
		_update_merchant_state()
		return

	var background_texture := _get_hub_background_texture(visual, background_key)
	if room_art == null or background_texture == null:
		_restore_default_hub_background()
		_update_merchant_state()
		return
	room_art.texture = background_texture
	_fit_hub_room_sprite(room_art, background_texture)

	if foreground_art == null:
		_update_merchant_state()
		return
	var foreground_texture := _get_hub_foreground_texture(visual, background_key)
	foreground_art.texture = foreground_texture
	foreground_art.visible = foreground_texture != null
	if foreground_texture != null:
		_fit_hub_room_sprite(foreground_art, foreground_texture)
	_update_merchant_state()


func _normalize_hub_background_key(key: String) -> String:
	if _hub_background_textures.has(key):
		return key
	return ""


func _get_hub_background_texture(visual: Dictionary, background_key: String) -> Texture2D:
	var configured_path := str(visual.get("hub_background_path", ""))
	var configured_texture := _load_texture_from_path(configured_path)
	if configured_texture != null:
		return configured_texture
	if background_key == "":
		return null
	return _hub_background_textures.get(background_key, null) as Texture2D


func _get_hub_foreground_texture(visual: Dictionary, background_key: String) -> Texture2D:
	var configured_path := str(visual.get("hub_foreground_path", ""))
	var configured_texture := _load_texture_from_path(configured_path)
	if configured_texture != null:
		return configured_texture
	var foreground_key := _normalize_hub_background_key(str(visual.get("hub_foreground_key", background_key)))
	return _hub_foreground_textures.get(foreground_key, null) as Texture2D


func _restore_default_hub_background() -> void:
	if room_art != null and _default_room_texture != null:
		room_art.texture = _default_room_texture
		room_art.position = _default_room_position
		room_art.scale = _default_room_scale
	if foreground_art != null:
		foreground_art.texture = null
		foreground_art.visible = false


func _apply_hub_dreamcatcher_stage_visual() -> void:
	if dreamcatcher_net == null:
		return
	var visual := _get_stage_visual()
	var texture_path := str(visual.get("dreamcatcher_net_path", ""))
	if texture_path == "":
		return
	var texture := _load_texture_from_path(texture_path)
	if texture != null:
		dreamcatcher_net.texture = texture


func _capture_hub_dreamcatcher_pose() -> void:
	if dreamcatcher_net == null:
		return
	_dreamcatcher_net_base_position = dreamcatcher_net.position
	_dreamcatcher_net_base_rotation = dreamcatcher_net.rotation
	_dreamcatcher_net_base_offset = dreamcatcher_net.offset


func _configure_hub_dreamcatcher_swing_pivot() -> void:
	if dreamcatcher_net == null or dreamcatcher_net.texture == null:
		return
	var texture_size := dreamcatcher_net.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var visual_center := _get_hub_dreamcatcher_visual_center()
	var pivot_distance := texture_size.y * DREAMCATCHER_SWING_PIVOT_DISTANCE_RATIO
	dreamcatcher_net.centered = true
	dreamcatcher_net.offset = Vector2(0.0, pivot_distance)
	dreamcatcher_net.position = visual_center - _get_hub_dreamcatcher_scaled_offset().rotated(dreamcatcher_net.rotation)


func _get_hub_dreamcatcher_visual_center() -> Vector2:
	if dreamcatcher_net == null:
		return Vector2.ZERO
	return dreamcatcher_net.position + _get_hub_dreamcatcher_scaled_offset().rotated(dreamcatcher_net.rotation)


func _get_hub_dreamcatcher_scaled_offset() -> Vector2:
	if dreamcatcher_net == null:
		return Vector2.ZERO
	return Vector2(
		dreamcatcher_net.offset.x * dreamcatcher_net.scale.x,
		dreamcatcher_net.offset.y * dreamcatcher_net.scale.y
	)


func _get_hub_dreamcatcher_focus_global_position() -> Vector2:
	if dreamcatcher_net != null:
		return dreamcatcher_net.to_global(dreamcatcher_net.offset)
	if dreamcatcher_button != null:
		return dreamcatcher_button.get_global_rect().get_center()
	return INVALID_HUB_POINT


func _start_hub_dreamcatcher_idle_swing() -> void:
	if dreamcatcher_net == null or not is_inside_tree() or not _is_book_hub_current():
		return
	_stop_hub_dreamcatcher_idle_swing()
	dreamcatcher_net.position = _dreamcatcher_net_base_position
	dreamcatcher_net.rotation = _dreamcatcher_net_base_rotation
	dreamcatcher_net.offset = _dreamcatcher_net_base_offset
	_dreamcatcher_idle_tween = create_tween()
	_dreamcatcher_idle_tween.set_loops()
	_dreamcatcher_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_dreamcatcher_idle_tween.tween_property(dreamcatcher_net, "rotation", _dreamcatcher_net_base_rotation - 0.026, 1.1)
	_dreamcatcher_idle_tween.tween_property(dreamcatcher_net, "rotation", _dreamcatcher_net_base_rotation + 0.026, 2.2)
	_dreamcatcher_idle_tween.tween_property(dreamcatcher_net, "rotation", _dreamcatcher_net_base_rotation, 1.1)


func _stop_hub_dreamcatcher_idle_swing() -> void:
	if _dreamcatcher_idle_tween != null:
		_dreamcatcher_idle_tween.kill()
		_dreamcatcher_idle_tween = null


func _play_hub_dreamcatcher_start_swing() -> void:
	if dreamcatcher_net == null or not is_inside_tree():
		return
	_stop_hub_dreamcatcher_idle_swing()
	dreamcatcher_net.position = _dreamcatcher_net_base_position
	dreamcatcher_net.rotation = _dreamcatcher_net_base_rotation
	dreamcatcher_net.offset = _dreamcatcher_net_base_offset
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(dreamcatcher_net, "rotation", _dreamcatcher_net_base_rotation - 0.08, 0.14)
	tween.tween_property(dreamcatcher_net, "rotation", _dreamcatcher_net_base_rotation + 0.065, 0.18)
	tween.tween_property(dreamcatcher_net, "rotation", _dreamcatcher_net_base_rotation - 0.035, 0.14)
	tween.tween_property(dreamcatcher_net, "rotation", _dreamcatcher_net_base_rotation, 0.12)
	await tween.finished
	if not is_inside_tree():
		return
	dreamcatcher_net.position = _dreamcatcher_net_base_position
	dreamcatcher_net.rotation = _dreamcatcher_net_base_rotation
	dreamcatcher_net.offset = _dreamcatcher_net_base_offset


func _update_dreamcatcher_state() -> void:
	if dreamcatcher_button == null:
		return
	var can_start_game := _is_dreamcatcher_game_available() and not _is_dreamcatcher_transition_pending and _is_book_hub_current()
	dreamcatcher_button.disabled = not can_start_game
	dreamcatcher_button.tooltip_text = "Start dream" if can_start_game else ""
	dreamcatcher_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_start_game else Control.CURSOR_ARROW


func _is_dreamcatcher_game_available() -> bool:
	var rm = get_node_or_null("/root/RunManager")
	if rm == null or not bool(rm.get("is_run_active")):
		return false
	if not rm.has_method("get_current_route_node_type"):
		return false
	if rm.has_method("can_enter_route_node") and not rm.can_enter_route_node(int(rm.get("current_route_index"))):
		return false
	return RouteConfig.is_battle_node_type(rm.get_current_route_node_type())


func _update_merchant_state() -> void:
	var hub_page_visible := _is_book_hub_current()
	var should_show := _should_show_merchant() and hub_page_visible
	var can_enter_shop := _is_merchant_shop_available()
	if merchant_sprite != null:
		merchant_sprite.visible = should_show
		if should_show:
			_apply_merchant_animation(_get_merchant_animation_key())
		else:
			merchant_sprite.stop()
			_is_player_at_merchant = false
	if merchant_button != null:
		merchant_button.visible = should_show
		merchant_button.disabled = false
		merchant_button.tooltip_text = "商店" if can_enter_shop else ""
		merchant_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_enter_shop else Control.CURSOR_ARROW
	_layout_merchant()
	_sync_merchant_presence_state()


func _should_show_merchant() -> bool:
	var rm = get_node_or_null("/root/RunManager")
	return rm != null and bool(rm.get("is_run_active"))


func _is_merchant_shop_available() -> bool:
	var rm = get_node_or_null("/root/RunManager")
	if rm == null or not bool(rm.get("is_run_active")):
		return false
	if not rm.has_method("get_current_route_node_type"):
		return false
	return rm.get_current_route_node_type() == RouteConfig.NODE_SHOP


func _get_merchant_animation_key() -> String:
	var rm = get_node_or_null("/root/RunManager")
	var act := int(rm.get("current_act")) if rm != null else 1
	match act:
		1:
			return "cat"
		2:
			return "grandma"
		_:
			return "stage"


func _apply_merchant_animation(animation_key: String) -> void:
	if merchant_sprite == null:
		return
	var frames := _get_merchant_sprite_frames(animation_key)
	if frames == null:
		merchant_sprite.visible = false
		return
	if merchant_sprite.sprite_frames != frames:
		merchant_sprite.sprite_frames = frames
		merchant_sprite.animation = &"idle"
		merchant_sprite.stop()
		merchant_sprite.frame = 0


func _get_merchant_sprite_frames(animation_key: String) -> SpriteFrames:
	if _merchant_frames_cache.has(animation_key):
		return _merchant_frames_cache[animation_key] as SpriteFrames
	var paths := AssetPaths.merchant_frame_paths(animation_key)
	if paths.is_empty():
		return null
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_loop("idle", false)
	frames.set_animation_speed("idle", MERCHANT_ANIMATION_SPEED)
	for path in paths:
		var texture := AssetPaths.load_texture(path)
		if texture != null:
			frames.add_frame("idle", texture)
	if frames.get_frame_count("idle") <= 0:
		return null
	_merchant_frames_cache[animation_key] = frames
	return frames


func _layout_merchant() -> void:
	if merchant_sprite != null and room_art != null:
		merchant_sprite.position = room_art.position
		merchant_sprite.scale = room_art.scale
	if merchant_button == null:
		return
	var target := _get_merchant_interaction_source_rect()
	merchant_button.position = target.position + hub_art_source_offset
	merchant_button.size = target.size


func _get_merchant_interaction_source_rect() -> Rect2:
	var animation_key := _get_merchant_animation_key()
	var frame_bounds: Rect2 = MERCHANT_FRAME_BOUNDS.get(animation_key, MERCHANT_FRAME_BOUNDS["stage"])
	var room_scale := room_art.scale if room_art != null else Vector2.ONE
	var room_position := room_art.position if room_art != null else _default_room_position
	var source_rect := Rect2(
		room_position + frame_bounds.position * room_scale,
		frame_bounds.size * room_scale
	)
	source_rect.position.x += MERCHANT_INTERACTION_SOURCE_OFFSET_X
	return source_rect


func _get_merchant_interaction_viewport_rect() -> Rect2:
	if merchant_button != null and merchant_button.size.x > 0.0 and merchant_button.size.y > 0.0:
		return merchant_button.get_global_rect()
	return _source_rect_to_viewport(_get_merchant_interaction_source_rect())


func _sync_merchant_presence_state() -> void:
	if player == null or merchant_sprite == null or not merchant_sprite.visible:
		_is_player_at_merchant = false
		return
	if _pending_auto_interaction != "" and _pending_auto_interaction != AUTO_INTERACTION_MERCHANT:
		return
	var is_at_merchant := _is_player_in_merchant_position()
	if is_at_merchant == _is_player_at_merchant:
		return
	_is_player_at_merchant = is_at_merchant
	if is_at_merchant:
		_play_merchant_arrival_animation()
	else:
		_play_merchant_departure_animation()


func _is_player_in_merchant_position() -> bool:
	if player == null or not _should_show_merchant():
		return false
	var interaction_rect := _get_merchant_interaction_viewport_rect()
	if interaction_rect.size.x <= 0.0:
		return absf(player.global_position.x - _get_merchant_interaction_target_x()) <= _get_merchant_reach_distance()
	if _is_player_at_merchant:
		var exit_padding := MERCHANT_INTERACTION_EXIT_PADDING_SOURCE_X * _art_scale
		interaction_rect = interaction_rect.grow_individual(exit_padding, 0.0, exit_padding, 0.0)
	return _player_overlaps_rect_x(interaction_rect)


func _player_overlaps_rect_x(rect: Rect2) -> bool:
	var player_half_width := _get_player_collision_half_width()
	return player.global_position.x + player_half_width >= rect.position.x and player.global_position.x - player_half_width <= rect.end.x


func _merchant_interaction_contains_x(global_x: float) -> bool:
	var interaction_rect := _get_merchant_interaction_viewport_rect()
	if interaction_rect.size.x <= 0.0:
		return absf(global_x - _get_merchant_interaction_target_x()) <= _get_merchant_reach_distance()
	return global_x >= interaction_rect.position.x and global_x <= interaction_rect.end.x


func _get_player_collision_half_width() -> float:
	if player == null:
		return 0.0
	var collision_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return 0.0
	var rectangle_shape := collision_shape.shape as RectangleShape2D
	if rectangle_shape == null:
		return 0.0
	return rectangle_shape.size.x * absf(collision_shape.scale.x) * 0.5


func _get_merchant_reach_distance() -> float:
	return maxf(8.0, MERCHANT_INTERACTION_REACH_DISTANCE * _art_scale)


func _play_merchant_arrival_animation() -> bool:
	if not _prepare_merchant_animation():
		return false
	merchant_sprite.stop()
	merchant_sprite.frame = 0
	merchant_sprite.play(&"idle", 1.0, false)
	return true


func _play_merchant_departure_animation() -> bool:
	if not _prepare_merchant_animation():
		return false
	var last_frame := _get_merchant_last_frame()
	if last_frame <= 0:
		return false
	var start_frame := clampi(merchant_sprite.frame, 0, last_frame)
	if start_frame <= 0:
		start_frame = last_frame
	merchant_sprite.stop()
	merchant_sprite.frame = start_frame
	merchant_sprite.play(&"idle", -1.0, false)
	return true


func _prepare_merchant_animation() -> bool:
	if merchant_sprite == null or not merchant_sprite.visible:
		return false
	_apply_merchant_animation(_get_merchant_animation_key())
	if merchant_sprite.sprite_frames == null or not merchant_sprite.sprite_frames.has_animation("idle"):
		return false
	if is_zero_approx(merchant_sprite.speed_scale):
		merchant_sprite.speed_scale = 1.0
	else:
		merchant_sprite.speed_scale = absf(merchant_sprite.speed_scale)
	return true


func _get_merchant_last_frame() -> int:
	if merchant_sprite == null or merchant_sprite.sprite_frames == null:
		return 0
	if not merchant_sprite.sprite_frames.has_animation("idle"):
		return 0
	return maxi(0, merchant_sprite.sprite_frames.get_frame_count("idle") - 1)


func _load_texture_from_path(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _sync_editor_preview_state() -> void:
	if book_canvas_layer != null:
		book_canvas_layer.visible = true
	if hub_art != null:
		hub_art.visible = true
	if canvas_design_root != null:
		canvas_design_root.visible = true
	if player != null:
		player.visible = true
	if floor_body != null:
		floor_body.visible = true
	if interactions != null:
		interactions.visible = false
	if book_page_navigator != null:
		book_page_navigator.visible = false
	if speech_bubble != null:
		speech_bubble.visible = false
	if speech_text != null:
		speech_text.visible = false
	if foreground_art != null and foreground_art.texture == null:
		foreground_art.visible = false
	if merchant_sprite != null:
		merchant_sprite.visible = false
	if merchant_button != null:
		merchant_button.visible = false
	if canvas_design_root != null:
		var main_menu_button := canvas_design_root.get_node_or_null(HUB_BACK_TAB_BUTTON) as Control
		if main_menu_button != null:
			main_menu_button.visible = true


func _fit_hub_room_sprite(sprite: Sprite2D, texture: Texture2D) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var display_size := _default_room_display_size
	if display_size.x <= 0.0 or display_size.y <= 0.0:
		display_size = texture_size
	var display_scale := minf(
		display_size.x / texture_size.x,
		display_size.y / texture_size.y
	)
	sprite.position = _default_room_position
	sprite.scale = Vector2(display_scale, display_scale)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not GlobalInput.can_cancel():
		return
	if _is_hub_battle_session_active:
		return

	if not _is_book_hub_current():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _activate_book_page_tab_at_position(event.position):
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
			_open_book_page(BookPageNavigator.PAGE_HUB)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _activate_left_bookmark_at_position(event.position):
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		if _has_overlay_backpack_content():
			_close_backpack_overlay_with_transition()
		else:
			_return_to_main_menu()
		get_viewport().set_input_as_handled()
		return

	if GlobalInput.is_context(GlobalInput.Context.WORLD):
		if _is_route_advance_shortcut(event):
			if _advance_current_route_by_shortcut():
				get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_E):
			get_viewport().set_input_as_handled()


func _is_route_advance_shortcut(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo and (key_event.keycode == KEY_Z or key_event.physical_keycode == KEY_Z)


func _advance_current_route_by_shortcut() -> bool:
	if _pending_auto_interaction != "" or _is_dreamcatcher_transition_pending:
		return false
	var rm = get_node_or_null("/root/RunManager")
	if rm == null or not bool(rm.get("is_run_active")):
		return false
	if not rm.has_method("can_enter_route_node") or not rm.can_enter_route_node(int(rm.get("current_route_index"))):
		return false

	var node_type: String = rm.get_current_route_node_type() if rm.has_method("get_current_route_node_type") else ""
	if RouteConfig.is_battle_node_type(node_type):
		_on_dreamcatcher_button_pressed()
		return true
	if node_type == RouteConfig.NODE_SHOP:
		_enter_current_route_node()
		return true
	if node_type == RouteConfig.NODE_EVENT:
		var skipped_node: Dictionary = rm.advance_route_node()
		if skipped_node.is_empty():
			return false
		print("[Hub] 事件节点暂未实现，已跳过: ", skipped_node.get("id", ""))
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _is_hub_battle_session_active:
		return
	if not _is_book_hub_current():
		return
	if _has_overlay_backpack_content():
		return
	if not GlobalInput.is_context(GlobalInput.Context.WORLD):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _activate_left_bookmark_at_position(event.position):
			get_viewport().set_input_as_handled()
			return
		if _activate_hub_dreamcatcher_at_position(event.position):
			get_viewport().set_input_as_handled()
			return
		_pending_auto_interaction = ""
		if player and player.has_method("move_to_global_x"):
			player.move_to_global_x(event.position.x)
			get_viewport().set_input_as_handled()


func _is_point_on_left_bookmark(point: Vector2) -> bool:
	return _get_left_bookmark_page_at_position(point) != ""


func _activate_left_bookmark_at_position(point: Vector2) -> bool:
	var page_id := _get_left_bookmark_page_at_position(point)
	if page_id == "":
		return false
	if page_id == PAGE_MAIN_MENU:
		_return_to_main_menu()
	else:
		_open_book_page(page_id)
	return true


func _activate_book_page_tab_at_position(point: Vector2) -> bool:
	if book_page_navigator == null or not book_page_navigator.has_method("activate_tab_at_position"):
		return false
	return bool(book_page_navigator.call("activate_tab_at_position", point))


func _activate_hub_dreamcatcher_at_position(point: Vector2) -> bool:
	if _is_dreamcatcher_transition_pending or not _is_dreamcatcher_game_available():
		return false
	if not _is_point_on_hub_dreamcatcher(point):
		return false
	_on_dreamcatcher_button_pressed()
	return true


func _is_point_on_hub_dreamcatcher(point: Vector2) -> bool:
	var visual_rect := _get_hub_dreamcatcher_global_rect()
	if visual_rect.size.x > 1.0 and visual_rect.size.y > 1.0:
		return visual_rect.has_point(point)
	if dreamcatcher_button == null or not dreamcatcher_button.visible:
		return false
	return dreamcatcher_button.get_global_rect().has_point(point)


func _get_hub_dreamcatcher_global_rect() -> Rect2:
	if dreamcatcher_net == null or not dreamcatcher_net.visible:
		return Rect2()
	return _get_sprite_global_rect(dreamcatcher_net)


func _get_sprite_global_rect(sprite: Sprite2D) -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2()
	var local_rect := sprite.get_rect()
	var transform := sprite.get_global_transform()
	return _get_aabb_from_points([
		transform * local_rect.position,
		transform * Vector2(local_rect.end.x, local_rect.position.y),
		transform * local_rect.end,
		transform * Vector2(local_rect.position.x, local_rect.end.y),
	])


func _get_aabb_from_points(points: Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_position: Vector2 = points[0]
	var max_position: Vector2 = points[0]
	for point: Vector2 in points:
		min_position.x = minf(min_position.x, point.x)
		min_position.y = minf(min_position.y, point.y)
		max_position.x = maxf(max_position.x, point.x)
		max_position.y = maxf(max_position.y, point.y)
	return Rect2(min_position, max_position - min_position)


func _get_left_bookmark_page_at_position(point: Vector2) -> String:
	if _is_book_background_child_hit("BackTab", point):
		return PAGE_MAIN_MENU
	for page_id in HUB_LEFT_TAB_NODES.keys():
		var tab_node_name := str(HUB_LEFT_TAB_NODES[page_id])
		if _is_book_background_child_hit(tab_node_name, point):
			return str(page_id)
	if canvas_design_root == null:
		return ""
	var main_menu_button := canvas_design_root.get_node_or_null(HUB_BACK_TAB_BUTTON) as Button
	if _is_bookmark_button_hit(main_menu_button, point):
		return PAGE_MAIN_MENU
	for page_id in HUB_LEFT_TAB_BUTTONS.keys():
		var button := canvas_design_root.get_node_or_null(str(HUB_LEFT_TAB_BUTTONS[page_id])) as Button
		if _is_bookmark_button_hit(button, point):
			return str(page_id)
	return ""


func _is_book_background_child_hit(child_name: String, point: Vector2) -> bool:
	if book_background == null or child_name == "":
		return false
	var child := book_background.get_node_or_null(child_name) as Control
	if child == null or not child.visible:
		return false
	return child.get_global_rect().has_point(point)


func _is_bookmark_button_hit(button: Button, point: Vector2) -> bool:
	if button == null or not button.visible or button.disabled:
		return false
	return button.get_global_rect().has_point(point)


func _queue_auto_interaction(interaction: String, target_x: float) -> void:
	_pending_auto_interaction = interaction
	if player != null and player.has_method("move_to_global_x"):
		player.move_to_global_x(target_x)


func _on_player_move_target_reached(_target_x: float) -> void:
	var interaction := _pending_auto_interaction
	_pending_auto_interaction = ""
	var reached_merchant := (interaction == AUTO_INTERACTION_MERCHANT or interaction == "") and _merchant_interaction_contains_x(_target_x)
	var played_merchant_arrival := false
	if reached_merchant and merchant_sprite != null and merchant_sprite.visible:
		if not _is_player_at_merchant:
			_is_player_at_merchant = true
			played_merchant_arrival = _play_merchant_arrival_animation()
	match interaction:
		AUTO_INTERACTION_ROUTE:
			_enter_current_route_node()
		AUTO_INTERACTION_GALLERY:
			_enter_gallery()
		AUTO_INTERACTION_MERCHANT:
			if _is_merchant_shop_available():
				if played_merchant_arrival and merchant_sprite != null and merchant_sprite.is_playing():
					await merchant_sprite.animation_finished
				if not is_inside_tree() or not _is_player_at_merchant:
					return
				_enter_current_route_node()


func _source_x_to_viewport(source_x: float) -> float:
	return _art_origin.x + source_x * _art_scale


func _get_merchant_interaction_target_x() -> float:
	if merchant_button != null and merchant_button.size.x > 0.0:
		return merchant_button.get_global_rect().get_center().x
	return _source_rect_to_viewport(_get_merchant_interaction_source_rect()).get_center().x


func _enter_current_route_node() -> void:
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		_enter_route_node(rm.current_route_index)


func _enter_route_node(index: int) -> void:
	var rm = get_node_or_null("/root/RunManager")
	if not rm or not rm.can_enter_route_node(index):
		print("[Hub] 节点未解锁，无法进入: ", index)
		return

	var node = rm.get_current_route_node()
	print("[Hub] 进入路线节点: ", node.get("id", ""))
	_lock_before_transition()

	# 获取点击的位置作为缩放中心（捕梦网）
	var dreamcatcher_uv := Vector2(0.5, 0.5)
	var dreamcatcher_focus := _get_hub_dreamcatcher_focus_global_position()
	if _is_valid_hub_point(dreamcatcher_focus):
		var focus_viewport_size = get_viewport_rect().size
		dreamcatcher_uv = dreamcatcher_focus / focus_viewport_size

	var end_focus := Vector2(0.32, 0.36)
	var battle_focus_target := _get_hub_to_battle_board_target_global_position()
	if _is_valid_hub_point(battle_focus_target):
		var target_viewport_size = get_viewport_rect().size
		end_focus = battle_focus_target / target_viewport_size

	var target_scene: int = rm.get_current_node_scene_type()
	var route_node_type := str(rm.get_current_route_node_type()) if rm.has_method("get_current_route_node_type") else ""
	var is_battle_route := target_scene == GlobalScene.SceneType.BATTLE or RouteConfig.is_battle_node_type(route_node_type)
	var target_scene_name := str(target_scene)
	if target_scene >= 0 and target_scene < GlobalScene.SceneType.keys().size():
		target_scene_name = str(GlobalScene.SceneType.keys()[target_scene])
	print(
		"[Hub] Entering route node. target_scene=", target_scene_name,
		", route_node_type=", route_node_type,
		", is_battle_route=", is_battle_route,
		", rm_can_enter=", rm.can_enter_route_node(index)
	)
	if is_battle_route:
		print("[Hub] Battle node: starting battle inside hub scene without scene transition.")
		await _play_hub_to_battle_focus(dreamcatcher_uv, end_focus)
		if not is_inside_tree():
			return
		await _open_hub_battle_session()
	else:
		print("[Hub] Non-battle node: fallback to SceneManager transition.")
		GlobalScene.transition_with_zoom(target_scene, dreamcatcher_uv, end_focus)


func _open_hub_battle_session() -> void:
	if battle_layer == null:
		push_warning("[Hub] BattleLayer is missing; cannot start battle inside hub.")
		_return_dreamcatcher_to_ready_state()
		return

	if _is_hub_battle_session_active:
		battle_layer.visible = true
		return

	_clear_overlay_children(true)
	if battle_layer.has_method("use_hub_dreamcatcher"):
		battle_layer.call("use_hub_dreamcatcher", dreamcatcher_net, dreamcatcher_button)
	_set_hub_chrome_visible_for_battle(false)

	if _has_node_property(battle_layer, "auto_initialize"):
		battle_layer.set("auto_initialize", false)

	var battle_manager := BattleManager.new()
	_remove_hub_battle_runtime_children()
	battle_layer.add_child(battle_manager)
	_hub_battle_manager = battle_manager
	battle_layer.z_index = 40
	battle_layer.visible = true
	_is_hub_battle_session_active = true

	if battle_layer.has_method("setup"):
		battle_layer.call("setup", battle_manager, Callable(self, "_on_hub_battle_session_closed"))
	else:
		push_warning("[Hub] BattleLayer does not expose setup().")
		_cleanup_hub_battle_session()
		_return_dreamcatcher_to_ready_state()


func _on_hub_battle_session_closed(target_scene: int) -> void:
	var next_scene = target_scene
	if next_scene == -1:
		next_scene = GlobalScene.SceneType.HUB

	_cleanup_hub_battle_session()
	_return_dreamcatcher_to_ready_state()

	if next_scene == GlobalScene.SceneType.MAIN_MENU:
		_transition_from_hub(next_scene, false)
		return

	_layout_scene()


func _cleanup_hub_battle_session(do_persist_backpack: bool = true) -> void:
	if _hub_battle_manager != null and is_instance_valid(_hub_battle_manager):
		if do_persist_backpack and _hub_battle_manager.has_method("persist_backpack_to_run"):
			_hub_battle_manager.persist_backpack_to_run()
		_hub_battle_manager.queue_free()
	_hub_battle_manager = null
	_remove_hub_battle_runtime_children()
	_is_hub_battle_session_active = false
	if battle_layer != null:
		battle_layer.visible = false


func _remove_hub_battle_runtime_children() -> void:
	if battle_layer == null or not is_instance_valid(battle_layer):
		return
	for child in battle_layer.get_children():
		if child.name != "ContentLayer":
			child.queue_free()


func _set_hub_chrome_visible_for_battle(is_visible: bool) -> void:
	if canvas_design_root != null:
		canvas_design_root.visible = is_visible
	if player != null:
		player.visible = is_visible
		if not is_visible and player.has_method("clear_move_target"):
			player.clear_move_target()
	if floor_body != null:
		floor_body.visible = is_visible
	if merchant_button != null:
		merchant_button.visible = is_visible and _should_show_merchant()
	if is_visible:
		_restore_hub_focus_layer_base_transforms()
		_layout_scene()
		_update_merchant_state()
		_update_dreamcatcher_state()
		_start_hub_dreamcatcher_idle_swing()
	else:
		_pending_auto_interaction = ""
		_stop_hub_dreamcatcher_idle_swing()
		_update_dreamcatcher_state()


func _return_dreamcatcher_to_ready_state() -> void:
	_is_dreamcatcher_transition_pending = false
	_update_dreamcatcher_state()
	GlobalInput.set_context(GlobalInput.Context.WORLD)
	_set_hub_chrome_visible_for_battle(true)


func _has_overlay_backpack_content() -> bool:
	if overlay_root == null:
		return false
	return overlay_root.get_child_count() > 0


func _has_node_property(node: Object, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _clear_overlay_children(do_persist_backpack: bool = true) -> void:
	if overlay_root == null:
		return
	for child in overlay_root.get_children():
		if do_persist_backpack:
			var manager = child.get("battle_manager")
			if manager != null and manager.has_method("persist_backpack_to_run"):
				manager.persist_backpack_to_run()
		child.queue_free()


func _play_hub_to_battle_focus(start_focus_uv: Vector2, end_focus_uv: Vector2, duration: float = HUB_TO_BATTLE_FOCUS_DURATION) -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	_stop_hub_dreamcatcher_idle_swing()
	var viewport_size := _validated_layout_viewport_size(get_viewport_rect().size)
	var start_focus := start_focus_uv * viewport_size
	var end_focus := end_focus_uv * viewport_size
	var focus_nodes := _get_hub_to_battle_focus_layers()
	var focus_scale := _get_hub_to_battle_focus_scale(start_focus)
	_capture_hub_focus_layer_base_transforms(focus_nodes)
	if duration <= 0.0:
		for node in focus_nodes:
			_apply_hub_focus_node(node, start_focus, end_focus, focus_scale)
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	for node in focus_nodes:
		_tween_hub_focus_node(tween, node, start_focus, end_focus, focus_scale, duration)
	await tween.finished


func _tween_hub_focus_node(tween: Tween, node: Node, focus_point: Vector2, target_point: Vector2, focus_scale: Vector2, duration: float) -> void:
	if node == null:
		return
	var canvas_item := node as CanvasItem
	if canvas_item == null or not canvas_item.visible:
		return
	var current_scale: Vector2 = node.get("scale")
	var target_scale := Vector2(current_scale.x * focus_scale.x, current_scale.y * focus_scale.y)
	var target_position := _get_hub_focus_target_local_position(canvas_item, focus_point, target_point, target_scale)
	tween.tween_property(node, "position", target_position, duration)
	tween.tween_property(node, "scale", target_scale, duration)


func _apply_hub_focus_node(node: Node, focus_point: Vector2, target_point: Vector2, focus_scale: Vector2) -> void:
	if node == null:
		return
	var canvas_item := node as CanvasItem
	if canvas_item == null or not canvas_item.visible:
		return
	var current_scale: Vector2 = node.get("scale")
	var target_scale := Vector2(current_scale.x * focus_scale.x, current_scale.y * focus_scale.y)
	node.set("position", _get_hub_focus_target_local_position(canvas_item, focus_point, target_point, target_scale))
	node.set("scale", target_scale)


func _get_hub_focus_target_local_position(canvas_item: CanvasItem, focus_point: Vector2, target_point: Vector2, target_scale: Vector2) -> Vector2:
	if canvas_item == hub_board_content:
		var parent_canvas := canvas_item.get_parent() as CanvasItem
		if parent_canvas != null:
			var focus_local := canvas_item.get_global_transform().affine_inverse() * focus_point
			var target_parent_position := parent_canvas.get_global_transform().affine_inverse() * target_point
			var target_position := target_parent_position - Vector2(focus_local.x * target_scale.x, focus_local.y * target_scale.y)
			target_position.y = _get_hub_board_bottom_locked_focus_y(target_position.y, target_scale.y)
			return target_position

	var current_global_position := canvas_item.get_global_transform().origin
	var mirrored_focus_target := focus_point - (target_point - focus_point)
	var fallback_zoom := (target_scale.x + target_scale.y) * 0.5
	var target_global_position := mirrored_focus_target + (current_global_position - focus_point) * fallback_zoom
	var fallback_parent_canvas := canvas_item.get_parent() as CanvasItem
	if fallback_parent_canvas == null:
		return target_global_position
	return fallback_parent_canvas.get_global_transform().affine_inverse() * target_global_position


func _get_hub_board_bottom_locked_focus_y(target_y: float, target_scale_y: float) -> float:
	if hub_board_viewport == null or target_scale_y <= 0.0:
		return target_y
	var clip_rect := _get_hub_board_source_clip_rect()
	if clip_rect.size.y <= 0.0 or hub_board_viewport.size.y <= 0.0:
		return target_y
	var locked_y := hub_board_viewport.size.y + HUB_TO_BATTLE_BOARD_BOTTOM_LOCK_OFFSET - clip_rect.end.y * target_scale_y
	return minf(target_y, locked_y)


func _get_hub_to_battle_focus_zoom(focus_point: Vector2) -> float:
	return HUB_TO_BATTLE_FOCUS_ZOOM if _is_valid_hub_point(focus_point) else HUB_TO_BATTLE_MIN_FOCUS_ZOOM


func _get_hub_to_battle_focus_scale(focus_point: Vector2) -> Vector2:
	var zoom := _get_hub_to_battle_focus_zoom(focus_point)
	return Vector2(zoom, zoom)


func _get_hub_to_battle_board_target_global_position() -> Vector2:
	if hub_board_viewport == null:
		return INVALID_HUB_POINT
	var board_rect := hub_board_viewport.get_global_rect()
	if board_rect.size.x <= 0.0 or board_rect.size.y <= 0.0:
		return INVALID_HUB_POINT
	return Vector2(
		board_rect.position.x + board_rect.size.x * HUB_TO_BATTLE_BOARD_TARGET_UV.x,
		board_rect.position.y + board_rect.size.y * HUB_TO_BATTLE_BOARD_TARGET_UV.y
	)


func _is_valid_hub_point(point: Vector2) -> bool:
	return absf(point.x) < INVALID_HUB_POINT.x * 0.5 and absf(point.y) < INVALID_HUB_POINT.y * 0.5


func _get_hub_to_battle_focus_layers() -> Array[Node]:
	var layers: Array[Node] = []
	if hub_board_content != null:
		layers.append(hub_board_content)
	return layers


func _is_hub_board_focus_item(canvas_item: CanvasItem) -> bool:
	if canvas_item == null or hub_board_content == null:
		return false
	if canvas_item == hub_board_content:
		return true
	var parent := canvas_item.get_parent()
	while parent != null:
		if parent == hub_board_content:
			return true
		parent = parent.get_parent()
	return false


func _capture_hub_focus_layer_base_transforms(nodes: Array[Node]) -> void:
	_hub_focus_layer_base_transforms.clear()
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		var layer_transform := {
			"node": node,
			"position": node.get("position"),
			"scale": node.get("scale"),
		}
		if _has_node_property(node, "rotation"):
			layer_transform["rotation"] = node.get("rotation")
		if _has_node_property(node, "offset"):
			layer_transform["offset"] = node.get("offset")
		_hub_focus_layer_base_transforms[node.get_instance_id()] = layer_transform


func _restore_hub_focus_layer_base_transforms() -> void:
	for layer_transform in _hub_focus_layer_base_transforms.values():
		if not (layer_transform is Dictionary):
			continue
		var node := layer_transform.get("node", null) as Node
		if node == null or not is_instance_valid(node):
			continue
		if layer_transform.has("position"):
			node.set("position", layer_transform["position"])
		if layer_transform.has("scale"):
			node.set("scale", layer_transform["scale"])
		if layer_transform.has("rotation"):
			node.set("rotation", layer_transform["rotation"])
		if layer_transform.has("offset"):
			node.set("offset", layer_transform["offset"])
	_hub_focus_layer_base_transforms.clear()


func _lock_before_transition() -> void:
	GlobalInput.set_context(GlobalInput.Context.LOCKED)


func _on_battle_trigger_body_entered(_body) -> void:
	current_zone = "battle"
	print("[Hub] Entered battle trigger.")


func _on_shop_trigger_body_entered(_body) -> void:
	current_zone = "shop"
	print("[Hub] Entered shop trigger.")


func _on_gallery_trigger_body_entered(_body) -> void:
	current_zone = "gallery"
	print("[Hub] Entered gallery trigger.")


func _on_zone_body_exited(_body) -> void:
	current_zone = ""
	print("[Hub] 离开区域")


func _on_main_menu_button_pressed() -> void:
	_return_to_main_menu()

func _on_route_button_pressed() -> void:
	_pending_auto_interaction = ""
	_open_book_page(BookPageNavigator.PAGE_HUB)

func _on_dreamcatcher_button_pressed() -> void:
	if not _is_dreamcatcher_game_available() or _is_dreamcatcher_transition_pending:
		return
	_is_dreamcatcher_transition_pending = true
	_update_dreamcatcher_state()
	await _play_hub_dreamcatcher_start_swing()
	if not is_inside_tree():
		return
	if _is_dreamcatcher_game_available():
		_enter_current_route_node()
	else:
		_is_dreamcatcher_transition_pending = false
		_update_dreamcatcher_state()
		_start_hub_dreamcatcher_idle_swing()

func _on_merchant_button_pressed() -> void:
	if not _is_merchant_shop_available():
		_pending_auto_interaction = ""
		if player != null and player.has_method("move_to_global_x"):
			player.move_to_global_x(_get_merchant_interaction_target_x())
		return
	_queue_auto_interaction(AUTO_INTERACTION_MERCHANT, _get_merchant_interaction_target_x())

func _on_gallery_button_pressed() -> void:
	_open_book_page(BookPageNavigator.PAGE_GALLERY)

func _on_settings_button_pressed() -> void:
	_open_book_page(BookPageNavigator.PAGE_SETTINGS)


func _return_to_main_menu() -> void:
	_transition_from_hub(GlobalScene.SceneType.MAIN_MENU, false)


func _enter_battle() -> void:
	_enter_current_route_node()


func _enter_shop() -> void:
	_enter_current_route_node()


func _enter_gallery() -> void:
	_open_book_page(BookPageNavigator.PAGE_GALLERY)


func _transition_from_hub(target: int, push_to_history: bool = true) -> void:
	_lock_before_transition()
	GlobalScene.transition_to(target, push_to_history)


func show_speech_message(message: String = "") -> void:
	if speech_bubble == null or speech_text == null:
		return
	speech_text.text = DEFAULT_SPEECH_TEXT if message.is_empty() else message
	speech_bubble.visible = true
	speech_text.visible = true


func hide_speech_message() -> void:
	_hide_speech()


func _hide_speech() -> void:
	if speech_bubble != null:
		speech_bubble.visible = false
	if speech_text != null:
		speech_text.visible = false


func _on_backpack_button_pressed() -> void:
	_open_book_page(BookPageNavigator.PAGE_BACKPACK)


func _open_book_page(page_id: String) -> void:
	if book_page_navigator != null and book_page_navigator.has_method("go_to_page"):
		book_page_navigator.go_to_page(page_id)


func _is_book_hub_current() -> bool:
	if book_page_navigator == null or not book_page_navigator.has_method("is_hub_current"):
		return true
	return bool(book_page_navigator.is_hub_current())


func get_book_hub_transition_layer() -> Control:
	return null


func set_book_hub_transition_frozen(frozen: bool) -> void:
	if player == null:
		return
	if frozen:
		if _hub_transition_player_frozen:
			return
		_hub_transition_player_frozen = true
		_hub_transition_player_process_mode = player.process_mode
		if player.has_method("clear_move_target"):
			player.clear_move_target()
		player.process_mode = Node.PROCESS_MODE_DISABLED
		return
	if not _hub_transition_player_frozen:
		return
	player.process_mode = _hub_transition_player_process_mode
	_hub_transition_player_frozen = false


func get_book_hub_transition_layers() -> Array[Node]:
	var layers: Array[Node] = []
	for node in [book_design_root, hub_art, player]:
		var layer := node as Node
		if layer != null and is_instance_valid(layer):
			layers.append(layer)
	return layers


func _setup_hub_page_visual_root() -> void:
	# Keep HubArt and Player at their stable scene paths; BookPageNavigator
	# temporarily reparents those layers only while a book transition is active.
	pass


func _layout_hub_page_visual_root(viewport_size: Vector2) -> void:
	if _hub_page_visual_root == null or not is_instance_valid(_hub_page_visual_root):
		return
	_hub_page_visual_root.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_hub_page_visual_root.position = Vector2.ZERO
	_hub_page_visual_root.size = viewport_size
	_hub_page_visual_root.scale = Vector2.ONE
	_hub_page_visual_root.pivot_offset = Vector2(viewport_size.x, 0.0)


func set_book_hub_visible(page_visible: bool) -> void:
	_setup_hub_page_visual_root()
	if _hub_page_visual_root != null:
		_hub_page_visual_root.visible = page_visible
	if book_canvas_layer != null:
		book_canvas_layer.visible = page_visible
	if book_design_root != null:
		book_design_root.visible = true
	if hub_art != null:
		hub_art.visible = page_visible
	if player != null:
		player.visible = page_visible
		if not page_visible and player.has_method("clear_move_target"):
			player.clear_move_target()
	if floor_body != null:
		floor_body.visible = page_visible
	if canvas_design_root != null:
		canvas_design_root.visible = page_visible
	if merchant_button != null:
		merchant_button.visible = page_visible and _should_show_merchant()
	if page_visible:
		_layout_scene()
		_update_merchant_state()
		_update_dreamcatcher_state()
		_start_hub_dreamcatcher_idle_swing()
	else:
		_pending_auto_interaction = ""
		_stop_hub_dreamcatcher_idle_swing()
		_update_dreamcatcher_state()


func _open_backpack_overlay_with_transition() -> void:
	GlobalScene.transition_with_page_turn(Callable(self, "_open_backpack_overlay"))


func _open_backpack_overlay() -> void:
	print("[Hub] 正在打开背包浮层...")
	GlobalInput.set_context(GlobalInput.Context.UI)
	var ui_scene = load("res://src/ui/backpack/backpack_page.tscn")
	var overlay = ui_scene.instantiate()
	if overlay.has_method("configure_for_backpack_overlay"):
		overlay.configure_for_backpack_overlay(Callable(self, "_return_to_main_menu"))
	overlay_root.add_child(overlay)


func _close_backpack_overlay_with_transition() -> void:
	if overlay_root.get_child_count() <= 0:
		return
	GlobalScene.transition_with_page_turn(Callable(self, "_close_backpack_overlay"))


func _close_backpack_overlay() -> void:
	print("[Hub] 正在关闭背包浮层")
	for child in overlay_root.get_children():
		var manager = child.get("battle_manager")
		if manager != null and manager.has_method("persist_backpack_to_run"):
			manager.persist_backpack_to_run()
		child.queue_free()
	GlobalInput.set_context(GlobalInput.Context.WORLD)

func _layout_scene() -> void:
	var viewport_size := _get_layout_viewport_size()
	if Engine.is_editor_hint():
		_has_positioned_player = false
	_layout_hub_page_visual_root(viewport_size)
	_layout_hub_art(viewport_size)
	_layout_book_design_root()
	_layout_canvas_design_root()
	_layout_player_and_floor(viewport_size)
	_layout_merchant()


func _get_layout_viewport_size() -> Vector2:
	if Engine.is_editor_hint():
		var width := DEFAULT_VIEWPORT_SIZE.x
		var height := DEFAULT_VIEWPORT_SIZE.y
		if ProjectSettings.has_setting("display/window/size/viewport_width"):
			width = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
		if ProjectSettings.has_setting("display/window/size/viewport_height"):
			height = float(ProjectSettings.get_setting("display/window/size/viewport_height"))
		return _validated_layout_viewport_size(Vector2(width, height))
	return _validated_layout_viewport_size(get_viewport_rect().size)


func _validated_layout_viewport_size(viewport_size: Vector2) -> Vector2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return DEFAULT_VIEWPORT_SIZE
	return viewport_size


func _layout_hub_art(viewport_size: Vector2) -> void:
	_art_scale = minf(
		viewport_size.x / _hub_source_size.x,
		viewport_size.y / _hub_source_size.y
	)
	var displayed_size := _hub_source_size * _art_scale
	_book_origin = (viewport_size - displayed_size) * 0.5
	_art_origin = _book_origin + hub_art_source_offset * _art_scale
	if hub_art != null:
		hub_art.position = _art_origin
		hub_art.scale = Vector2(_art_scale, _art_scale)
	if hub_board_viewport != null:
		var clip_rect := _get_hub_board_source_clip_rect()
		hub_board_viewport.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
		hub_board_viewport.position = clip_rect.position
		hub_board_viewport.size = clip_rect.size
		hub_board_viewport.clip_contents = true
		hub_board_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if hub_board_content != null:
			var board_content_control := hub_board_content as Control
			if board_content_control != null:
				board_content_control.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
				board_content_control.position = -clip_rect.position
				board_content_control.size = _hub_source_size
				board_content_control.pivot_offset = Vector2.ZERO
			else:
				var board_content_node_2d := hub_board_content as Node2D
				if board_content_node_2d != null:
					board_content_node_2d.position = -clip_rect.position


func _get_hub_board_source_clip_rect() -> Rect2:
	var room_rect := _get_default_room_source_rect()
	if room_rect.size.x > 0.0 and room_rect.size.y > 0.0:
		return room_rect
	return _get_hub_art_corner_source_bounds()


func _get_default_room_source_rect() -> Rect2:
	var room_size := _default_room_display_size
	if (room_size.x <= 0.0 or room_size.y <= 0.0) and _default_room_texture != null:
		room_size = _default_room_texture.get_size() * _default_room_scale
	return Rect2(_default_room_position, room_size)


func _get_hub_art_corner_source_bounds() -> Rect2:
	var has_clip_rect := false
	var clip_rect := Rect2(Vector2.ZERO, _hub_source_size)
	if hub_art == null:
		return clip_rect
	for child_name in ["CornerTopLeft", "CornerTopRight", "CornerBottomLeft", "CornerBottomRight"]:
		var sprite := hub_art.get_node_or_null(child_name) as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var sprite_rect := _get_sprite_parent_rect(sprite)
		if not has_clip_rect:
			clip_rect = sprite_rect
			has_clip_rect = true
		else:
			clip_rect = clip_rect.merge(sprite_rect)
	return clip_rect if has_clip_rect else Rect2(Vector2.ZERO, _hub_source_size)


func _get_sprite_parent_rect(sprite: Sprite2D) -> Rect2:
	var texture_size := sprite.texture.get_size()
	var local_origin := sprite.offset
	if sprite.centered:
		local_origin -= texture_size * 0.5
	var points := [
		sprite.transform * local_origin,
		sprite.transform * (local_origin + Vector2(texture_size.x, 0.0)),
		sprite.transform * (local_origin + texture_size),
		sprite.transform * (local_origin + Vector2(0.0, texture_size.y)),
	]
	var rect := Rect2(points[0], Vector2.ZERO)
	for index in range(1, points.size()):
		rect = rect.expand(points[index])
	return rect


func _layout_book_design_root() -> void:
	if book_design_root == null:
		return
	book_design_root.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	book_design_root.position = _book_origin
	book_design_root.size = _hub_source_size
	book_design_root.scale = Vector2(_art_scale, _art_scale)
	if book_background != null:
		book_background.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
		book_background.position = Vector2.ZERO
		book_background.size = _hub_source_size
		book_background.scale = Vector2.ONE

func _layout_canvas_design_root() -> void:
	if canvas_design_root == null:
		return
	canvas_design_root.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	canvas_design_root.position = _book_origin
	canvas_design_root.size = _hub_source_size
	canvas_design_root.scale = Vector2(_art_scale, _art_scale)
	_layout_hub_back_tab_button()
	_layout_hub_left_tab_buttons()
	_layout_hub_world_buttons()


func _layout_hub_back_tab_button() -> void:
	if canvas_design_root == null:
		return
	var button := canvas_design_root.get_node_or_null(HUB_BACK_TAB_BUTTON) as Control
	if button == null:
		return
	var rect := _get_book_background_child_rect("BackTab", BookBackgroundConfig.get_back_tab_rect())
	button.position = rect.position
	button.size = rect.size
	button.visible = true


func _layout_hub_left_tab_buttons() -> void:
	if canvas_design_root == null:
		return
	for page_id in HUB_LEFT_TAB_BUTTONS.keys():
		var button := canvas_design_root.get_node_or_null(str(HUB_LEFT_TAB_BUTTONS[page_id])) as Control
		if button == null:
			continue
		var tab_node_name := str(HUB_LEFT_TAB_NODES.get(BookBackgroundConfig.normalize_page_id(str(page_id)), ""))
		var rect := _get_book_background_child_rect(tab_node_name, BookBackgroundConfig.get_tab_rect(str(page_id), BookBackgroundConfig.PAGE_HUB))
		button.position = rect.position
		button.size = rect.size


func _get_book_background_child_rect(child_name: String, fallback_rect: Rect2) -> Rect2:
	if book_background == null or child_name == "":
		return fallback_rect
	var child := book_background.get_node_or_null(child_name) as Control
	if child == null:
		return fallback_rect
	var global_rect := child.get_global_rect()
	if global_rect.size.x <= 1.0 or global_rect.size.y <= 1.0:
		return fallback_rect
	var inverse_transform := canvas_design_root.get_global_transform().affine_inverse()
	var local_position := (inverse_transform * global_rect.position).round()
	var local_end := (inverse_transform * global_rect.end).round()
	return Rect2(local_position, local_end - local_position)


func _layout_hub_world_buttons() -> void:
	if dreamcatcher_button != null:
		var dreamcatcher_rect := _get_hub_dreamcatcher_button_local_rect()
		if dreamcatcher_rect.size.x > 1.0 and dreamcatcher_rect.size.y > 1.0:
			dreamcatcher_button.position = dreamcatcher_rect.position
			dreamcatcher_button.size = dreamcatcher_rect.size
		else:
			dreamcatcher_button.position = _dreamcatcher_button_source_position + hub_art_source_offset
			dreamcatcher_button.size = _dreamcatcher_button_source_size


func _get_hub_dreamcatcher_button_local_rect() -> Rect2:
	if canvas_design_root == null:
		return Rect2()
	var global_rect := _get_hub_dreamcatcher_global_rect()
	if global_rect.size.x <= 1.0 or global_rect.size.y <= 1.0:
		return Rect2()
	return _global_rect_to_canvas_design_rect(global_rect)


func _global_rect_to_canvas_design_rect(global_rect: Rect2) -> Rect2:
	var inverse_transform := canvas_design_root.get_global_transform().affine_inverse()
	var local_position := (inverse_transform * global_rect.position).round()
	var local_end := (inverse_transform * global_rect.end).round()
	return Rect2(local_position, local_end - local_position)


func _layout_player_and_floor(viewport_size: Vector2) -> void:
	var floor_y := _art_origin.y + PLAYER_FLOOR_SOURCE_Y * _art_scale
	if floor_body != null:
		floor_body.position = Vector2(viewport_size.x * 0.5, floor_y)
	if player == null:
		return

	var min_x := _art_origin.x + PLAYER_WALK_MIN_SOURCE_X * _art_scale
	var max_x := _art_origin.x + PLAYER_WALK_MAX_SOURCE_X * _art_scale
	if not Engine.is_editor_hint() and player.has_method("set_walk_bounds"):
		player.set_walk_bounds(min_x, max_x)

	if not _has_positioned_player:
		player.global_position = Vector2(
			_art_origin.x + PLAYER_START_SOURCE_X * _art_scale,
			floor_y - PLAYER_FLOOR_OFFSET
		)
		_has_positioned_player = true
	else:
		player.global_position.y = floor_y - PLAYER_FLOOR_OFFSET
		player.global_position.x = clampf(player.global_position.x, min_x, max_x)


func _source_rect_to_viewport(source_rect: Rect2) -> Rect2:
	return Rect2(
		_art_origin + source_rect.position * _art_scale,
		source_rect.size * _art_scale
	)
