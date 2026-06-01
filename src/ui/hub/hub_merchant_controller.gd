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
const MERCHANT_INTERACTION_REACH_DISTANCE := 42.0
const MERCHANT_INTERACTION_ENTER_PADDING_SOURCE_X := 88.0
const MERCHANT_INTERACTION_EXIT_PADDING_SOURCE_X := 150.0
const MERCHANT_HOVER_SCALE := 1.04
const MERCHANT_CLICK_HIT_PADDING := Vector4(44.0, 28.0, 44.0, 28.0)
const MERCHANT_ALPHA_THRESHOLD := 0.03
const DEFAULT_MERCHANT_ANIMATION_KEY := "stage"
const PRESENCE_ANIMATION_NONE := 0
const PRESENCE_ANIMATION_ARRIVAL := 1
const PRESENCE_ANIMATION_DEPARTURE := -1
const MERCHANT_ACT_ANIMATION_KEYS := {
	1: "cat",
	2: "stage",
	3: "grandma",
	4: "parents",
	5: "xiaojia",
	6: "shiyi",
}

var merchant_sprite: AnimatedSprite2D = null
var merchant_button: Button = null
var player: CharacterBody2D = null
var room_art: Sprite2D = null
var is_player_at_merchant := false
var shop_click_ready := false
var _complete_interaction_token := 0
var _complete_interaction_callback: Callable = Callable()

var _frames_cache: Dictionary = {}
var _frame_bounds_cache: Dictionary = {}
var _frame_canvas_size_cache: Dictionary = {}
var _default_room_position := Vector2.ZERO
var _source_to_viewport: Callable = Callable()
var _get_player_half_width: Callable = Callable()
var _art_scale := 1.0
var _base_sprite_scale := Vector2.ONE
var _base_sprite_position := Vector2.ZERO
var _is_hovered := false
var _hover_tween: Tween = null
var _presence_animation_direction := PRESENCE_ANIMATION_NONE

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
	if merchant_button != null:
		var enter_callback := Callable(self, "_on_merchant_mouse_entered")
		if not merchant_button.mouse_entered.is_connected(enter_callback):
			merchant_button.mouse_entered.connect(enter_callback)
		var exit_callback := Callable(self, "_on_merchant_mouse_exited")
		if not merchant_button.mouse_exited.is_connected(exit_callback):
			merchant_button.mouse_exited.connect(exit_callback)

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
			shop_click_ready = false
			_is_hovered = false
			_presence_animation_direction = PRESENCE_ANIMATION_NONE
	if merchant_button != null:
		merchant_button.visible = should_show
		merchant_button.disabled = false
		merchant_button.tooltip_text = "点击进入商店" if can_enter_shop and shop_click_ready else "点击接近商人" if can_enter_shop else ""
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
	if can_open_shop(run_manager) and is_player_at_merchant and shop_click_ready:
		request_open_shop.emit()
		return
	shop_click_ready = false
	var target_x := get_interaction_target_x()
	move_requested.emit(target_x, can_open_shop(run_manager))

func complete_interaction(run_manager: Node, played_arrival: bool, on_complete: Callable = Callable()) -> void:
	_complete_interaction_token += 1
	var interaction_token := _complete_interaction_token
	_complete_interaction_callback = on_complete
	if not is_player_at_merchant:
		_invoke_complete_interaction_callback(interaction_token)
		return
	if not played_arrival:
		played_arrival = play_arrival_animation()
	if played_arrival and merchant_sprite != null and merchant_sprite.is_playing():
		merchant_sprite.animation_finished.connect(
			Callable(self, "_on_complete_interaction_animation_finished").bind(interaction_token, run_manager),
			Object.CONNECT_ONE_SHOT
		)
		return
	if can_open_shop(run_manager):
		shop_click_ready = true
		if merchant_button != null:
			merchant_button.tooltip_text = "点击进入商店"
	_invoke_complete_interaction_callback(interaction_token)


func _on_complete_interaction_animation_finished(token: int, run_manager: Node, _result = null) -> void:
	if token != _complete_interaction_token:
		return
	if not is_player_at_merchant:
		_invoke_complete_interaction_callback(token)
		return
	if can_open_shop(run_manager):
		shop_click_ready = true
		if merchant_button != null:
			merchant_button.tooltip_text = "点击进入商店"
	_invoke_complete_interaction_callback(token)


func _invoke_complete_interaction_callback(interaction_token: int) -> void:
	if interaction_token != _complete_interaction_token:
		return
	if _complete_interaction_callback.is_valid():
		var callback := _complete_interaction_callback
		_complete_interaction_callback = Callable()
		callback.call()

func get_animation_key(run_manager: Node) -> String:
	var configured_key := _get_configured_animation_key(run_manager)
	if configured_key != "":
		return configured_key
	var act := int(run_manager.get("current_act")) if run_manager != null else 1
	return str(MERCHANT_ACT_ANIMATION_KEYS.get(act, DEFAULT_MERCHANT_ANIMATION_KEY))

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
		_presence_animation_direction = PRESENCE_ANIMATION_NONE

func layout(source_offset: Vector2) -> void:
	if merchant_sprite != null and room_art != null:
		var animation_key := get_animation_key(_get_run_manager())
		_base_sprite_position = room_art.position
		_base_sprite_scale = _get_merchant_canvas_scale(animation_key)
		merchant_sprite.scale = _get_hover_target_scale()
		merchant_sprite.position = _get_hover_target_position()
	if merchant_button == null:
		return
	var target := get_click_source_rect()
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
	return get_interaction_viewport_rect().get_center().x

func get_interaction_source_rect() -> Rect2:
	var run_manager := _get_run_manager()
	var animation_key := get_animation_key(run_manager)
	var frame_bounds := get_interaction_frame_bounds(run_manager)
	var room_scale := _get_merchant_canvas_scale(animation_key)
	var room_position := room_art.position if room_art != null else _default_room_position
	var source_rect := Rect2(
		room_position + frame_bounds.position * room_scale,
		frame_bounds.size * room_scale
	)
	source_rect.position.x += MERCHANT_INTERACTION_SOURCE_OFFSET_X
	var trigger_padding := MERCHANT_INTERACTION_ENTER_PADDING_SOURCE_X * absf(room_scale.x)
	return source_rect.grow_individual(trigger_padding, 0.0, trigger_padding, 0.0)

func get_click_source_rect() -> Rect2:
	var run_manager := _get_run_manager()
	var animation_key := get_animation_key(run_manager)
	var frame_bounds := get_interaction_frame_bounds(run_manager)
	var room_scale := _get_merchant_canvas_scale(animation_key)
	var room_position := room_art.position if room_art != null else _default_room_position
	var padding := MERCHANT_CLICK_HIT_PADDING
	return Rect2(
		room_position + Vector2(frame_bounds.position.x - padding.x, frame_bounds.position.y - padding.y) * room_scale,
		Vector2(frame_bounds.size.x + padding.x + padding.z, frame_bounds.size.y + padding.y + padding.w) * room_scale
	)

func get_interaction_frame_bounds(run_manager: Node = null) -> Rect2:
	var resolved_run_manager := run_manager if run_manager != null else _get_run_manager()
	var configured_rect := _get_configured_interaction_rect(resolved_run_manager)
	if configured_rect.size.x > 0.0 and configured_rect.size.y > 0.0:
		return configured_rect
	return _get_default_frame_bounds(get_animation_key(resolved_run_manager))

func get_interaction_viewport_rect() -> Rect2:
	if _source_to_viewport.is_valid():
		return _source_to_viewport.call(get_interaction_source_rect())
	if merchant_button != null and merchant_button.size.x > 0.0 and merchant_button.size.y > 0.0:
		return merchant_button.get_global_rect()
	return Rect2()

func get_reach_distance() -> float:
	return maxf(8.0, MERCHANT_INTERACTION_REACH_DISTANCE * _art_scale)

func play_arrival_animation() -> bool:
	if _is_presence_animation_playing(PRESENCE_ANIMATION_ARRIVAL):
		return true
	if not _prepare_animation():
		return false
	if _is_arrival_visual_complete():
		_presence_animation_direction = PRESENCE_ANIMATION_NONE
		return false
	merchant_sprite.stop()
	merchant_sprite.frame = 0
	_presence_animation_direction = PRESENCE_ANIMATION_ARRIVAL
	_bind_presence_animation_finished()
	merchant_sprite.play(&"idle", 1.0, false)
	return true

func play_departure_animation() -> bool:
	if _is_presence_animation_playing(PRESENCE_ANIMATION_DEPARTURE):
		return true
	if not _prepare_animation():
		return false
	shop_click_ready = false
	var last_frame := _get_last_frame()
	if last_frame <= 0:
		return false
	var start_frame := clampi(merchant_sprite.frame, 0, last_frame)
	if start_frame <= 0:
		merchant_sprite.stop()
		_presence_animation_direction = PRESENCE_ANIMATION_NONE
		return false
	merchant_sprite.stop()
	merchant_sprite.frame = start_frame
	_presence_animation_direction = PRESENCE_ANIMATION_DEPARTURE
	_bind_presence_animation_finished()
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

func _is_presence_animation_playing(direction: int) -> bool:
	return (
		merchant_sprite != null
		and merchant_sprite.is_playing()
		and _presence_animation_direction == direction
	)

func _is_arrival_visual_complete() -> bool:
	if merchant_sprite == null:
		return false
	var last_frame := _get_last_frame()
	return last_frame > 0 and merchant_sprite.frame >= last_frame and not merchant_sprite.is_playing()

func _bind_presence_animation_finished() -> void:
	if merchant_sprite == null:
		return
	var callback := Callable(self, "_on_presence_animation_finished")
	if not merchant_sprite.animation_finished.is_connected(callback):
		merchant_sprite.animation_finished.connect(callback)

func _on_presence_animation_finished() -> void:
	_presence_animation_direction = PRESENCE_ANIMATION_NONE

func _on_merchant_mouse_entered() -> void:
	if not shop_click_ready:
		return
	_is_hovered = true
	_tween_hover_transform()

func _on_merchant_mouse_exited() -> void:
	_is_hovered = false
	_tween_hover_transform()

func _get_hover_target_scale() -> Vector2:
	var hover_scale := MERCHANT_HOVER_SCALE if _is_hovered and shop_click_ready else 1.0
	return _base_sprite_scale * hover_scale

func _get_hover_target_position() -> Vector2:
	var hover_scale := MERCHANT_HOVER_SCALE if _is_hovered and shop_click_ready else 1.0
	if is_equal_approx(hover_scale, 1.0):
		return _base_sprite_position
	var rect := get_click_source_rect()
	var center := rect.get_center()
	return center + (_base_sprite_position - center) * hover_scale

func _tween_hover_transform() -> void:
	if merchant_sprite == null or not merchant_sprite.visible:
		return
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = merchant_sprite.create_tween()
	_hover_tween.set_parallel(true)
	_hover_tween.set_trans(Tween.TRANS_QUAD)
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(merchant_sprite, "scale", _get_hover_target_scale(), 0.12)
	_hover_tween.tween_property(merchant_sprite, "position", _get_hover_target_position(), 0.12)

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

func _get_configured_animation_key(run_manager: Node) -> String:
	var visual := _get_stage_visual(run_manager)
	var animation_key := str(visual.get("merchant_animation_key", ""))
	if animation_key != "" and AssetPaths.MERCHANT_FRAME_SPECS.has(animation_key):
		return animation_key
	return ""

func _get_configured_interaction_rect(run_manager: Node) -> Rect2:
	var visual := _get_stage_visual(run_manager)
	var rect_value = visual.get("merchant_interaction_rect", visual.get("merchant_frame_bounds", null))
	return _rect_from_variant(rect_value)

func _get_stage_visual(run_manager: Node) -> Dictionary:
	if run_manager == null or not run_manager.has_method("get_current_stage_visual"):
		return {}
	var visual = run_manager.get_current_stage_visual()
	return Dictionary(visual).duplicate(true) if visual is Dictionary else {}

func _rect_from_variant(value) -> Rect2:
	if value is Rect2:
		return value
	if value is Dictionary:
		var source := value as Dictionary
		var width = source.get("w", source.get("width", 0.0))
		var height = source.get("h", source.get("height", 0.0))
		return Rect2(
			Vector2(float(source.get("x", 0.0)), float(source.get("y", 0.0))),
			Vector2(float(width), float(height))
		)
	if value is Array:
		var values := value as Array
		if values.size() >= 4:
			return Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3])))
	return Rect2()

func _get_default_frame_bounds(animation_key: String) -> Rect2:
	if _frame_bounds_cache.has(animation_key):
		return _frame_bounds_cache[animation_key] as Rect2
	var rect := _scan_first_frame_alpha_bounds(animation_key)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		rect = MERCHANT_FRAME_BOUNDS.get(animation_key, MERCHANT_FRAME_BOUNDS[DEFAULT_MERCHANT_ANIMATION_KEY]) as Rect2
	_frame_bounds_cache[animation_key] = rect
	return rect

func _scan_first_frame_alpha_bounds(animation_key: String) -> Rect2:
	var texture := _get_first_frame_texture(animation_key)
	if texture == null:
		return Rect2()
	var image := texture.get_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return Rect2()
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= MERCHANT_ALPHA_THRESHOLD:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2()
	return Rect2(float(min_x), float(min_y), float(max_x - min_x + 1), float(max_y - min_y + 1))

func _get_merchant_canvas_scale(animation_key: String) -> Vector2:
	if room_art == null:
		return Vector2.ONE
	var room_texture := room_art.texture
	if room_texture == null:
		return room_art.scale
	var canvas_size := _get_first_frame_canvas_size(animation_key)
	var room_display_size := room_texture.get_size() * room_art.scale.abs()
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0 or room_display_size.x <= 0.0 or room_display_size.y <= 0.0:
		return room_art.scale
	return Vector2(room_display_size.x / canvas_size.x, room_display_size.y / canvas_size.y)

func _get_first_frame_canvas_size(animation_key: String) -> Vector2:
	if _frame_canvas_size_cache.has(animation_key):
		return _frame_canvas_size_cache[animation_key] as Vector2
	var texture := _get_first_frame_texture(animation_key)
	var size := texture.get_size() if texture != null else Vector2.ZERO
	_frame_canvas_size_cache[animation_key] = size
	return size

func _get_first_frame_texture(animation_key: String) -> Texture2D:
	var paths := AssetPaths.merchant_frame_paths(animation_key)
	if paths.is_empty():
		return null
	return AssetPaths.load_texture(str(paths[0]))

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
