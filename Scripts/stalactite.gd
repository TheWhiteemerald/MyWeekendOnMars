class_name Stalactite
extends CharacterBody2D

enum State {
	WAITING,
	WARNING,
	FALLING,
	LANDED
}

@export var gravity: float = 900.0
@export var maximum_fall_speed: float = 500.0
@export var warning_duration: float = 0.4

@onready var sprite: Sprite2D = $Sprite2D
@onready var trigger_area: Area2D = $"Trigger Area"
@onready var damage_area: Area2D = $"Damage Area"
@onready var warning_timer: Timer = $"Warning Timer"
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var state: State = State.WAITING

func _ready() -> void:
	warning_timer.one_shot = true
	warning_timer.wait_time = warning_duration

	warning_timer.timeout.connect(_on_warning_timer_timeout)
	trigger_area.body_entered.connect(_on_trigger_area_body_entered)
	damage_area.body_entered.connect(_on_damage_area_body_entered)

func _physics_process(delta: float) -> void:
	match state:
		State.WAITING:
			velocity = Vector2.ZERO

		State.WARNING:
			velocity = Vector2.ZERO

		State.FALLING:
			fall(delta)

		State.LANDED:
			velocity = Vector2.ZERO

func _on_trigger_area_body_entered(body: Node2D) -> void:
	if state != State.WAITING:
		return

	if not body.is_in_group("player"):
		return

	begin_warning()

func begin_warning() -> void:
	if state != State.WAITING:
		return

	state = State.WARNING
	velocity = Vector2.ZERO

	# Prevent additional detection once activated.
	trigger_area.set_deferred("monitoring", false)

	if animation_player.has_animation("Stalactite Shake"):
		animation_player.play("Stalactite Shake")

	warning_timer.start()

func _on_warning_timer_timeout() -> void:
	if state != State.WARNING:
		return

	state = State.FALLING

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

	if body.global_position.y <= global_position.y:
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
