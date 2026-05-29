extends Node2D

const RouteConfig = preload("res://src/core/route/route_config.gd")
const BookBackgroundConfig = preload("res://src/ui/book/book_background_config.gd")
const BookPageNavigator = preload("res://src/ui/book/book_page_navigator.gd")

const HUB_SOURCE_SIZE := BookBackgroundConfig.DESIGN_SIZE
const HUB_BACKGROUND_TEXTURES := {
	"grandma": preload("res://assets/ui/hub/backgrounds/grandma.png"),
	"xiaojia": preload("res://assets/ui/hub/backgrounds/xiaojia.png"),
	"parents": preload("res://assets/ui/hub/backgrounds/parents.png"),
	"cardboard": preload("res://assets/ui/hub/backgrounds/cardboard.png"),
	"stage": preload("res://assets/ui/hub/backgrounds/stage.png"),
}
const HUB_FOREGROUND_TEXTURES := {
	"xiaojia": preload("res://assets/ui/hub/backgrounds/xiaojia_foreground.png"),
	"stage": preload("res://assets/ui/hub/backgrounds/stage_foreground.png"),
}
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
const ROUTE_INTERACTION_SOURCE_X := 1326.0
const GALLERY_INTERACTION_SOURCE_X := 771.0
const DEFAULT_SPEECH_TEXT := "你终于醒了！"
const MERCHANT_ANIMATION_FRAME_PATHS := {
	"cat": [
		"res://assets/characters/merchant/cat/cat_0000.png",
		"res://assets/characters/merchant/cat/cat_0001.png",
		"res://assets/characters/merchant/cat/cat_0002.png",
		"res://assets/characters/merchant/cat/cat_0003.png",
		"res://assets/characters/merchant/cat/cat_0004.png",
		"res://assets/characters/merchant/cat/cat_0005.png",
		"res://assets/characters/merchant/cat/cat_0006.png",
		"res://assets/characters/merchant/cat/cat_0007.png",
		"res://assets/characters/merchant/cat/cat_0008.png",
		"res://assets/characters/merchant/cat/cat_0009.png",
		"res://assets/characters/merchant/cat/cat_0010.png",
	],
	"grandma": [
		"res://assets/characters/merchant/grandma/grandma_0000.png",
		"res://assets/characters/merchant/grandma/grandma_0001.png",
		"res://assets/characters/merchant/grandma/grandma_0002.png",
		"res://assets/characters/merchant/grandma/grandma_0003.png",
		"res://assets/characters/merchant/grandma/grandma_0004.png",
	],
	"stage": [
		"res://assets/characters/merchant/stage/stage_0000.png",
		"res://assets/characters/merchant/stage/stage_0001.png",
		"res://assets/characters/merchant/stage/stage_0002.png",
		"res://assets/characters/merchant/stage/stage_0003.png",
		"res://assets/characters/merchant/stage/stage_0004.png",
		"res://assets/characters/merchant/stage/stage_0005.png",
		"res://assets/characters/merchant/stage/stage_0006.png",
	],
}
const MERCHANT_FRAME_BOUNDS := {
	"cat": Rect2(1236.0, 467.0, 293.0, 367.0),
	"grandma": Rect2(1295.0, 459.0, 377.0, 476.0),
	"stage": Rect2(1162.0, 715.0, 372.0, 365.0),
}
const MERCHANT_ANIMATION_SPEED := 6.0
const MERCHANT_INTERACTION_SOURCE_OFFSET_X := -313.0
const MERCHANT_INTERACTION_REACH_DISTANCE := 18.0
const MERCHANT_INTERACTION_EXIT_PADDING_SOURCE_X := 58.0

@export var hub_art_source_offset := Vector2(0.0, 14.0)

@onready var book_canvas_layer: CanvasLayer = $BookCanvasLayer
@onready var book_design_root: Control = $BookCanvasLayer/BookDesignRoot
@onready var book_background: Control = $BookCanvasLayer/BookDesignRoot/BookBackground
@onready var hub_art: Node2D = $HubArt
@onready var canvas_design_root: Control = $CanvasLayer/DesignRoot
@onready var overlay_root: Control = $CanvasLayer/OverlayRoot
@onready var player: CharacterBody2D = $Player
@onready var floor_body: StaticBody2D = $Floor
@onready var interactions: Node2D = $Interactions
@onready var room_art: Sprite2D = $HubArt/Room
@onready var foreground_art: Sprite2D = $HubArt/Foreground
@onready var speech_bubble: Sprite2D = $HubArt/SpeechBubble
@onready var speech_text: Label = $HubArt/SpeechText
@onready var dreamcatcher_net: Sprite2D = $HubArt/DreamcatcherNet
@onready var merchant_sprite: AnimatedSprite2D = $HubArt/MerchantSprite
@onready var merchant_button: Button = $CanvasLayer/MerchantButton
@onready var dreamcatcher_button: Button = $CanvasLayer/DesignRoot/DreamcatcherButton
@onready var book_page_navigator: Control = $CanvasLayer/BookPageNavigator

var current_zone: String = ""
var _art_origin: Vector2 = Vector2.ZERO
var _art_scale: float = 1.0
var _has_positioned_player := false
var _default_room_texture: Texture2D = null
var _default_room_position := Vector2.ZERO
var _default_room_scale := Vector2.ONE
var _default_room_display_size := Vector2.ZERO
var _merchant_frames_cache: Dictionary = {}
var _pending_auto_interaction := ""
var _is_player_at_merchant := false
var _hub_source_size := HUB_SOURCE_SIZE
var _dreamcatcher_net_base_position := Vector2.ZERO
var _dreamcatcher_net_base_rotation := 0.0
var _dreamcatcher_net_base_offset := Vector2.ZERO
var _dreamcatcher_idle_tween: Tween = null
var _is_dreamcatcher_transition_pending := false


func _ready() -> void:
	print("[Hub] Entered dream route.")
	GlobalInput.set_context(GlobalInput.Context.WORLD)
	GlobalAudio.play_bgm(_get_stage_bgm_key("hub_bgm_key", "hub"))
	_hide_speech()
	_cache_layout_source_data()
	_capture_default_hub_room_art()

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
	if HUB_BACKGROUND_TEXTURES.has(key):
		return key
	return ""


func _get_hub_background_texture(visual: Dictionary, background_key: String) -> Texture2D:
	var configured_path := str(visual.get("hub_background_path", ""))
	var configured_texture := _load_texture_from_path(configured_path)
	if configured_texture != null:
		return configured_texture
	if background_key == "":
		return null
	return HUB_BACKGROUND_TEXTURES.get(background_key, null) as Texture2D


func _get_hub_foreground_texture(visual: Dictionary, background_key: String) -> Texture2D:
	var configured_path := str(visual.get("hub_foreground_path", ""))
	var configured_texture := _load_texture_from_path(configured_path)
	if configured_texture != null:
		return configured_texture
	var foreground_key := _normalize_hub_background_key(str(visual.get("hub_foreground_key", background_key)))
	return HUB_FOREGROUND_TEXTURES.get(foreground_key, null) as Texture2D


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
	var paths: Array = MERCHANT_ANIMATION_FRAME_PATHS.get(animation_key, [])
	if paths.is_empty():
		return null
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_loop("idle", false)
	frames.set_animation_speed("idle", MERCHANT_ANIMATION_SPEED)
	for path in paths:
		var texture := load(str(path)) as Texture2D
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
	var target := _source_rect_to_viewport(_get_merchant_interaction_source_rect())
	merchant_button.position = target.position
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
		return Rect2(merchant_button.position, merchant_button.size)
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
	if not GlobalInput.can_cancel():
		return

	if not _is_book_hub_current():
		if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
			_open_book_page(BookPageNavigator.PAGE_HUB)
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		if overlay_root.get_child_count() > 0:
			_close_backpack_overlay_with_transition()
		else:
			_return_to_main_menu()
		get_viewport().set_input_as_handled()
		return

	if GlobalInput.is_context(GlobalInput.Context.WORLD):
		if event.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_E):
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_book_hub_current():
		return
	if overlay_root.get_child_count() > 0:
		return
	if not GlobalInput.is_context(GlobalInput.Context.WORLD):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _is_point_on_left_bookmark(event.position):
			get_viewport().set_input_as_handled()
			return
		_pending_auto_interaction = ""
		if player and player.has_method("move_to_global_x"):
			player.move_to_global_x(event.position.x)
			get_viewport().set_input_as_handled()


func _is_point_on_left_bookmark(point: Vector2) -> bool:
	for path in LEFT_BOOKMARK_BUTTON_PATHS:
		var button := get_node_or_null(path) as Control
		if button != null and button.visible and button.get_global_rect().has_point(point):
			return true
	return false


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
		return merchant_button.position.x + merchant_button.size.x * 0.5
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
	if dreamcatcher_button != null:
		var btn_pos = dreamcatcher_button.global_position + dreamcatcher_button.size * 0.5
		var viewport_size = get_viewport_rect().size
		dreamcatcher_uv = btn_pos / viewport_size

	# 设定入场动画的聚焦目标：右下角
	# 通过 Panning，捕梦网会从其位置移向左上方（相对于缩放中心），从而在视野中移向右上角
	var end_focus := Vector2(0.75, 0.75)

	GlobalScene.transition_with_zoom(rm.get_current_node_scene_type(), dreamcatcher_uv, end_focus)


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


func set_book_hub_visible(page_visible: bool) -> void:
	if book_canvas_layer != null:
		book_canvas_layer.visible = page_visible
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
	var ui_scene = load("res://src/ui/main_game_ui.tscn")
	var overlay = ui_scene.instantiate()
	if overlay.has_method("configure_for_backpack_overlay"):
		overlay.configure_for_backpack_overlay(_close_backpack_overlay_with_transition)
	overlay_root.add_child(overlay)


func _close_backpack_overlay_with_transition() -> void:
	if overlay_root.get_child_count() <= 0:
		return
	GlobalScene.transition_with_page_turn(Callable(self, "_close_backpack_overlay"))


func _close_backpack_overlay() -> void:
	print("[Hub] 正在关闭背包浮层")
	for child in overlay_root.get_children():
		if child.has_method("_on_menu_button_pressed") and child.get("battle_manager") != null:
			var manager = child.get("battle_manager")
			if manager and manager.has_method("persist_backpack_to_run"):
				manager.persist_backpack_to_run()
		child.queue_free()
	GlobalInput.set_context(GlobalInput.Context.WORLD)

func _layout_scene() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	_layout_hub_art(viewport_size)
	_layout_book_design_root()
	_layout_canvas_design_root()
	_layout_player_and_floor(viewport_size)
	_layout_merchant()


func _layout_hub_art(viewport_size: Vector2) -> void:
	_art_scale = maxf(
		viewport_size.x / _hub_source_size.x,
		viewport_size.y / _hub_source_size.y
	)
	var displayed_size := _hub_source_size * _art_scale
	_art_origin = (viewport_size - displayed_size) * 0.5 + hub_art_source_offset * _art_scale
	if hub_art != null:
		hub_art.position = _art_origin
		hub_art.scale = Vector2(_art_scale, _art_scale)

func _layout_book_design_root() -> void:
	if book_design_root == null:
		return
	book_design_root.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	book_design_root.position = _art_origin
	book_design_root.size = _hub_source_size
	book_design_root.scale = Vector2(_art_scale, _art_scale)

func _layout_canvas_design_root() -> void:
	if canvas_design_root == null:
		return
	canvas_design_root.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	canvas_design_root.position = _art_origin
	canvas_design_root.size = _hub_source_size
	canvas_design_root.scale = Vector2(_art_scale, _art_scale)


func _layout_player_and_floor(viewport_size: Vector2) -> void:
	var floor_y := _art_origin.y + PLAYER_FLOOR_SOURCE_Y * _art_scale
	if floor_body != null:
		floor_body.position = Vector2(viewport_size.x * 0.5, floor_y)
	if player == null:
		return

	var min_x := _art_origin.x + PLAYER_WALK_MIN_SOURCE_X * _art_scale
	var max_x := _art_origin.x + PLAYER_WALK_MAX_SOURCE_X * _art_scale
	if player.has_method("set_walk_bounds"):
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
