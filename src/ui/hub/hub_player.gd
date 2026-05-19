extends CharacterBody2D

const ANIM_IDLE: StringName = &"idle"
const ANIM_WALK: StringName = &"walk"

@export var speed: float = 260.0
@export var gravity: float = 1200.0
@export var click_stop_distance: float = 6.0

var has_move_target: bool = false
var move_target_x: float = 0.0

@onready var animated_sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var legacy_sprite := get_node_or_null("Sprite2D") as Sprite2D


func _ready() -> void:
	_play_animation(ANIM_IDLE)


func move_to_global_x(target_x: float) -> void:
	move_target_x = target_x
	has_move_target = true


func clear_move_target() -> void:
	has_move_target = false


func _physics_process(delta: float) -> void:
	if not GlobalInput.can_move():
		velocity.x = 0.0
		clear_move_target()
		_apply_gravity(delta)
		move_and_slide()
		_play_animation(ANIM_IDLE)
		return

	_apply_gravity(delta)

	var direction := _get_keyboard_direction()
	var is_moving_horizontally := false

	if direction != 0:
		clear_move_target()
		velocity.x = direction * speed
		_face_direction(direction)
		is_moving_horizontally = true
	elif has_move_target:
		var distance := move_target_x - global_position.x
		if abs(distance) <= click_stop_distance:
			clear_move_target()
			velocity.x = 0.0
		else:
			var move_dir: float = sign(distance)
			velocity.x = move_dir * speed
			_face_direction(move_dir)
			is_moving_horizontally = true
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 0.2)
		is_moving_horizontally = abs(velocity.x) > 0.1

	move_and_slide()
	_play_animation(ANIM_WALK if is_moving_horizontally else ANIM_IDLE)


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


func _face_direction(direction: float) -> void:
	if direction == 0.0:
		return
	if animated_sprite != null:
		animated_sprite.flip_h = direction < 0.0
	if legacy_sprite != null:
		legacy_sprite.flip_h = direction < 0.0


func _play_animation(animation_name: StringName) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
	elif not animated_sprite.is_playing():
		animated_sprite.play()
