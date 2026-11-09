class_name GravelRock
extends CharacterBody2D

enum State {
	SUPPORTED,
	WARNING,
	FALLING,
	LANDED
}

@export var startup_support_delay: float = 0.1
var startup_time_remaining: float = 0.0

@export var gravity: float = 900.0
@export var maximum_fall_speed: float = 500.0
@export var warning_duration: float = 0.4
@export var landing_delay: float = 0.1

@onready var support_check:RayCast2D = $"Support Check"
@onready var warning_timer:Timer = $"Warning Timer"
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var damage_area: Area2D = $"Damage Area"

var state: State = State.SUPPORTED

func _ready() -> void:
	startup_time_remaining = startup_support_delay
	warning_timer.one_shot = true
	warning_timer.wait_time = warning_duration
	warning_timer.timeout.connect(_on_warning_timer_timeout)

	damage_area.body_entered.connect(_on_damage_area_body_entered)

func _physics_process(delta: float) -> void:
	if startup_time_remaining > 0.0:
		startup_time_remaining -= delta
		return

	match state:
		State.SUPPORTED:
			check_for_support()

		State.WARNING:
			# Cancel the warning if support is present again.
			if has_support():
				cancel_warning()

		State.FALLING:
			fall(delta)

		State.LANDED:
			velocity = Vector2.ZERO

func has_support() -> bool:
	support_check.force_raycast_update()
	return support_check.is_colliding()


func check_for_support() -> void:
	if not has_support():
		begin_warning()


func cancel_warning() -> void:
	warning_timer.stop()
	state = State.SUPPORTED
	velocity = Vector2.ZERO

	animation_player.stop()

	# Restore properties changed by the shake animation.
	if animation_player.has_animation("RESET"):
		animation_player.play("RESET")
		animation_player.advance(0.0)
	
func begin_warning() -> void:
	if state != State.SUPPORTED:
		return

	state = State.WARNING
	velocity = Vector2.ZERO

	if animation_player.has_animation("Gravel Shake"):
		animation_player.play("Gravel Shake")

	warning_timer.start()

func _on_warning_timer_timeout() -> void:
	if state != State.WARNING:
		return

	# Confirm support is still missing before committing to the fall.
	if has_support():
		cancel_warning()
		return

	state = State.FALLING

	if animation_player.has_animation("fall"):
		animation_player.play("fall")

func fall(delta: float) -> void:
	velocity.y = move_toward(
		velocity.y,
		maximum_fall_speed,
		gravity * delta
	)

	move_and_slide()

	if is_on_floor():
		land()

func land() -> void:
	if state != State.FALLING:
		return

	state = State.LANDED
	velocity = Vector2.ZERO

	if animation_player.has_animation("land"):
		animation_player.play("land")
		await animation_player.animation_finished

	queue_free()
		
func _on_damage_area_body_entered(body: Node2D) -> void:
	if state != State.FALLING:
		return

	if body.is_in_group("Player"):
		damage_player(body)
	elif body.is_in_group("Enemies"):
		crush_enemy(body)
		
func damage_player(player: Node) -> void:
	if player.has_method("apply_damage"):
		player.apply_damage(1)
		player.start_invulnerability()

func crush_enemy(enemy: Node) -> void:
	if enemy.has_method("die"):
		enemy.die()
