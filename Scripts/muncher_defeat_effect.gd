extends Node2D

@export var effect_gravity: float = 500.0
@export var spin_speed_degrees: float = 720.0
@export var lifetime: float = 1.5
@export var fade_duration: float = 0.25

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var flight_velocity := Vector2.ZERO
var spin_direction: float = 1.0
var time_left: float = 0.0


func setup(
	source: AnimatedSprite2D,
	launch_velocity: Vector2
) -> void:
	# Match the original sprite's world position, rotation,
	# and scale. The child sprite remains at its local origin.
	global_transform = source.global_transform

	sprite.sprite_frames = source.sprite_frames
	sprite.flip_h = source.flip_h
	sprite.flip_v = source.flip_v
	sprite.centered = source.centered
	sprite.offset = source.offset
	sprite.texture_filter = source.texture_filter

	flight_velocity = launch_velocity
	spin_direction = -1.0 if launch_velocity.x < 0.0 else 1.0
	time_left = lifetime

	# Use dedicated artwork when available.
	# Otherwise, spin a frozen copy of the current frame.
	if sprite.sprite_frames.has_animation(&"defeat"):
		sprite.play(&"defeat")
	else:
		sprite.animation = source.animation
		sprite.set_frame_and_progress(
			source.frame,
			source.frame_progress
		)
		sprite.pause()


func _physics_process(delta: float) -> void:
	time_left -= delta

	if time_left <= 0.0:
		queue_free()
		return

	flight_velocity.y += effect_gravity * delta
	global_position += flight_velocity * delta

	global_rotation += (
		deg_to_rad(spin_speed_degrees)
		* spin_direction
		* delta
	)

	if fade_duration > 0.0 and time_left < fade_duration:
		modulate.a = clampf(time_left / fade_duration, 0.0, 1.0)
