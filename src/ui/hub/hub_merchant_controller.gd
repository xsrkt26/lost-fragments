extends RefCounted

signal move_requested(target_x: float, should_open_shop: bool)
signal request_open_shop

const MERCHANT_FRAME_BOUNDS := {
	"cat": Rect2(1236.0, 467.0, 293.0, 367.0),
	"grandma": Rect2(1295.0, 459.0, 377.0, 476.0),
	"stage": Rect2(1162.0, 715.0, 372.0, 365.0),
}
const MERCHANT_ANIMATION_SPEED := 6.0
const MERCHANT_INTERACTION_SOURCE_OFFSET_X := -313.0
const MERCHANT_INTERACTION_REACH_DISTANCE := 18.0
const MERCHANT_INTERACTION_EXIT_PADDING_SOURCE_X := 58.0

var merchant_sprite: AnimatedSprite2D = null
var merchant_button: Button = null
var player: CharacterBody2D = null
var room_art: Sprite2D = null
var is_player_at_merchant := false

var _frames_cache: Dictionary = {}
var _default_room_position := Vector2.ZERO
var _source_to_viewport: Callable = Callable()
var _get_player_half_width: Callable = Callable()
var _art_scale := 1.0

func setup(
	p_merchant_sprite: AnimatedSprite2D,
	p_merchant_button: Button,
	p_player: CharacterBody2D,
	p_room_art: Sprite2D,
	default_room_position: Vector2,
	source_to_viewport: Callable,
	get_player_half_width: Callable
) -> void:
	merchant_sprite = p_merchant_sprite
	merchant_button = p_merchant_button
	player = p_player
	room_art = p_room_art
	_default_room_position = default_room_position
	_source_to_viewport = source_to_viewport
	_get_player_half_width = get_player_half_width

func set_layout_scale(scale_factor: float) -> void:
	_art_scale = scale_factor

func update_state(run_manager: Node, hub_page_visible: bool) -> void:
	var should_show := should_show(run_manager) and hub_page_visible
	var can_enter_shop := can_open_shop(run_manager)
	if merchant_sprite != null:
		merchant_sprite.visible = should_show
		if should_show:
			apply_animation(get_animation_key(run_manager))
		else:
			merchant_sprite.stop()
			is_player_at_merchant = false
	if merchant_button != null:
		merchant_button.visible = should_show
		merchant_button.disabled = false
		merchant_button.tooltip_text = "Shop" if can_enter_shop else ""
		merchant_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_enter_shop else Control.CURSOR_ARROW

func should_show(run_manager: Node) -> bool:
	return run_manager != null and bool(run_manager.get("is_run_active"))

func can_open_shop(run_manager: Node) -> bool:
	if run_manager == null:
		return false
	if run_manager.has_method("can_enter_current_shop"):
		return run_manager.can_enter_current_shop()
	if not bool(run_manager.get("is_run_active")):
		return false
	if not run_manager.has_method("get_current_route_node_type"):
		return false
	return run_manager.get_current_route_node_type() == RouteConfig.NODE_SHOP

func interact(run_manager: Node) -> void:
	var target_x := get_interaction_target_x()
	move_requested.emit(target_x, can_open_shop(run_manager))

func complete_interaction(run_manager: Node, played_arrival: bool) -> void:
	if not is_player_at_merchant:
		return
	if not played_arrival:
		played_arrival = play_arrival_animation()
	if played_arrival and merchant_sprite != null and merchant_sprite.is_playing():
		await merchant_sprite.animation_finished
	if not is_player_at_merchant:
		return
	if can_open_shop(run_manager):
		request_open_shop.emit()

func get_animation_key(run_manager: Node) -> String:
	var act := int(run_manager.get("current_act")) if run_manager != null else 1
	match act:
		1:
			return "cat"
		2:
			return "grandma"
		_:
			return "stage"

func apply_animation(animation_key: String) -> void:
	if merchant_sprite == null:
		return
	var frames := _get_sprite_frames(animation_key)
	if frames == null:
		merchant_sprite.visible = false
		return
	if merchant_sprite.sprite_frames != frames:
		merchant_sprite.sprite_frames = frames
		merchant_sprite.animation = &"idle"
		merchant_sprite.stop()
		merchant_sprite.frame = 0

func layout(source_offset: Vector2) -> void:
	if merchant_sprite != null and room_art != null:
		merchant_sprite.position = room_art.position
		merchant_sprite.scale = room_art.scale
	if merchant_button == null:
		return
	var target := get_interaction_source_rect()
	merchant_button.position = target.position + source_offset
	merchant_button.size = target.size

func sync_presence_state(run_manager: Node, pending_auto_interaction: String, merchant_auto_interaction: String) -> void:
	if player == null or merchant_sprite == null or not merchant_sprite.visible:
		is_player_at_merchant = false
		return
	if pending_auto_interaction != "" and pending_auto_interaction != merchant_auto_interaction:
		return
	var is_at_merchant := is_player_in_position(run_manager)
	if is_at_merchant == is_player_at_merchant:
		return
	is_player_at_merchant = is_at_merchant
	if is_at_merchant:
		play_arrival_animation()
	else:
		play_departure_animation()

func is_player_in_position(run_manager: Node) -> bool:
	if player == null or not should_show(run_manager):
		return false
	var interaction_rect := get_interaction_viewport_rect()
	if interaction_rect.size.x <= 0.0:
		return absf(player.global_position.x - get_interaction_target_x()) <= get_reach_distance()
	if is_player_at_merchant:
		var exit_padding := MERCHANT_INTERACTION_EXIT_PADDING_SOURCE_X * _art_scale
		interaction_rect = interaction_rect.grow_individual(exit_padding, 0.0, exit_padding, 0.0)
	return _player_overlaps_rect_x(interaction_rect)

func interaction_contains_x(global_x: float) -> bool:
	var interaction_rect := get_interaction_viewport_rect()
	if interaction_rect.size.x <= 0.0:
		return absf(global_x - get_interaction_target_x()) <= get_reach_distance()
	return global_x >= interaction_rect.position.x and global_x <= interaction_rect.end.x

func get_interaction_target_x() -> float:
	if merchant_button != null and merchant_button.size.x > 0.0:
		return merchant_button.get_global_rect().get_center().x
	return get_interaction_viewport_rect().get_center().x

func get_interaction_source_rect() -> Rect2:
	var animation_key := get_animation_key(_get_run_manager())
	var frame_bounds: Rect2 = MERCHANT_FRAME_BOUNDS.get(animation_key, MERCHANT_FRAME_BOUNDS["stage"])
	var room_scale := room_art.scale if room_art != null else Vector2.ONE
	var room_position := room_art.position if room_art != null else _default_room_position
	var source_rect := Rect2(
		room_position + frame_bounds.position * room_scale,
		frame_bounds.size * room_scale
	)
	source_rect.position.x += MERCHANT_INTERACTION_SOURCE_OFFSET_X
	return source_rect

func get_interaction_viewport_rect() -> Rect2:
	if merchant_button != null and merchant_button.size.x > 0.0 and merchant_button.size.y > 0.0:
		return merchant_button.get_global_rect()
	if _source_to_viewport.is_valid():
		return _source_to_viewport.call(get_interaction_source_rect())
	return Rect2()

func get_reach_distance() -> float:
	return maxf(8.0, MERCHANT_INTERACTION_REACH_DISTANCE * _art_scale)

func play_arrival_animation() -> bool:
	if not _prepare_animation():
		return false
	merchant_sprite.stop()
	merchant_sprite.frame = 0
	merchant_sprite.play(&"idle", 1.0, false)
	return true

func play_departure_animation() -> bool:
	if not _prepare_animation():
		return false
	var last_frame := _get_last_frame()
	if last_frame <= 0:
		return false
	var start_frame := clampi(merchant_sprite.frame, 0, last_frame)
	if start_frame <= 0:
		start_frame = last_frame
	merchant_sprite.stop()
	merchant_sprite.frame = start_frame
	merchant_sprite.play(&"idle", -1.0, false)
	return true

func _prepare_animation() -> bool:
	if merchant_sprite == null or not merchant_sprite.visible:
		return false
	apply_animation(get_animation_key(_get_run_manager()))
	if merchant_sprite.sprite_frames == null or not merchant_sprite.sprite_frames.has_animation("idle"):
		return false
	if is_zero_approx(merchant_sprite.speed_scale):
		merchant_sprite.speed_scale = 1.0
	else:
		merchant_sprite.speed_scale = absf(merchant_sprite.speed_scale)
	return true

func _get_sprite_frames(animation_key: String) -> SpriteFrames:
	if _frames_cache.has(animation_key):
		return _frames_cache[animation_key] as SpriteFrames
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
	_frames_cache[animation_key] = frames
	return frames

func _get_last_frame() -> int:
	if merchant_sprite == null or merchant_sprite.sprite_frames == null:
		return 0
	if not merchant_sprite.sprite_frames.has_animation("idle"):
		return 0
	return maxi(0, merchant_sprite.sprite_frames.get_frame_count("idle") - 1)

func _player_overlaps_rect_x(rect: Rect2) -> bool:
	var player_half_width := 0.0
	if _get_player_half_width.is_valid():
		player_half_width = float(_get_player_half_width.call())
	return player.global_position.x + player_half_width >= rect.position.x and player.global_position.x - player_half_width <= rect.end.x

func _get_run_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("RunManager")
