class_name EnergyFragment
extends Node2D

enum State {
	SCATTER,
	HOMING
}

var state: State = State.SCATTER

var scatter_velocity: Vector2
var scatter_timer: float = 0.15

@export var move_speed: float = 220.0
@export var acceleration: float = 600.0
@export var arrival_distance: float = 6.0

var target: Node2D
var current_speed: float = 0.0

var energy_value: float = 0.0
var score_value: int = 0


func setup(
	new_target: Node2D,
	new_energy_value: float,
	new_score_value: int
) -> void:
	target = new_target
	energy_value = new_energy_value
	score_value = new_score_value


func _ready() -> void:
	scatter_velocity = Vector2.RIGHT.rotated(
		randf_range(0.0, TAU)
	) * randf_range(40.0, 100.0)


func _process(delta: float) -> void:
	match state:
		State.SCATTER:
			update_scatter(delta)

		State.HOMING:
			move_toward_target(delta)


func update_scatter(delta: float) -> void:
	global_position += scatter_velocity * delta

	scatter_velocity = scatter_velocity.move_toward(
		Vector2.ZERO,
		300.0 * delta
	)

	scatter_timer -= delta

	if scatter_timer <= 0.0:
		state = State.HOMING


func move_toward_target(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	current_speed = move_toward(
		current_speed,
		move_speed,
		acceleration * delta
	)

	var direction: Vector2 = global_position.direction_to(
		target.global_position
	)

	global_position += direction * current_speed * delta

	if global_position.distance_to(
		target.global_position
	) <= arrival_distance:
		arrive()


func arrive() -> void:
	if target.has_method("collect_energy_fragment"):
		target.collect_energy_fragment(
			energy_value,
			score_value
		)

	queue_free()
