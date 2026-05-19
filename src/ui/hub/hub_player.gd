extends CharacterBody2D

const ANIMATION_IDLE := &"idle"
const ANIMATION_WALK := &"walk"

@export var speed: float = 400.0
@export var gravity: float = 1200.0
@export var click_stop_distance: float = 6.0
@export var animation_deadzone: float = 1.0

var has_move_target: bool = false
var move_target_x: float = 0.0

@onready var _animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

func _ready() -> void:
	play_idle_animation()

func move_to_global_x(target_x: float) -> void:
	move_target_x = target_x
	has_move_target = true

func clear_move_target() -> void:
	has_move_target = false

func play_idle_animation() -> void:
	_play_animation(ANIMATION_IDLE)

func play_walk_animation() -> void:
	_play_animation(ANIMATION_WALK)

func play_move_animation_towards(target_x: float) -> void:
	var distance := target_x - global_position.x
	if abs(distance) <= click_stop_distance:
		play_idle_animation()
		return
	var direction: float = sign(distance)
	_face_direction(direction)
	play_walk_animation()

func _physics_process(delta: float) -> void:
	if not GlobalInput.can_move():
		velocity.x = 0.0
		clear_move_target()
		_apply_gravity(delta)
		move_and_slide()
		play_idle_animation()
		return

	_apply_gravity(delta)

	var direction := _get_keyboard_direction()
	if direction != 0:
		clear_move_target()
		velocity.x = float(direction) * speed
		_face_direction(float(direction))
	elif has_move_target:
		_apply_target_movement()
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 0.2)

	var is_moving_horizontally: bool = abs(velocity.x) > animation_deadzone
	move_and_slide()
	_update_movement_animation(is_moving_horizontally)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

func _get_keyboard_direction() -> int:
	var direction := 0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1
	return direction

func _apply_target_movement() -> void:
	var distance := move_target_x - global_position.x
	if abs(distance) <= click_stop_distance:
		clear_move_target()
		velocity.x = 0.0
		return

	var move_direction: float = sign(distance)
	velocity.x = move_direction * speed
	_face_direction(move_direction)

func _update_movement_animation(is_moving_horizontally: bool) -> void:
	if is_moving_horizontally:
		play_walk_animation()
	else:
		play_idle_animation()

func _face_direction(direction: float) -> void:
	if _animated_sprite == null or is_zero_approx(direction):
		return
	_animated_sprite.flip_h = direction < 0.0

func _play_animation(animation_name: StringName) -> void:
	if _animated_sprite == null:
		return
	if _animated_sprite.sprite_frames == null:
		return
	if not _animated_sprite.sprite_frames.has_animation(animation_name):
		return

	if _animated_sprite.animation != animation_name:
		_animated_sprite.play(animation_name)
	elif not _animated_sprite.is_playing():
		_animated_sprite.play()
