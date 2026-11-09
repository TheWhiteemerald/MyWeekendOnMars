class_name MineralDeposit
extends StaticBody2D

signal mineral_broken(
	energy_amount: float,
	score_amount: int,
	world_position: Vector2
)

@export var energy_reward: float = 15.0
@export var score_reward: int = 100

@export var energy_fragment: PackedScene
@export var fragment_count: int = 5

var drilling_player: CharacterBody2D = null
var is_being_drilled: bool = false
var is_broken: bool = false

func start_being_drilled(player: CharacterBody2D) -> void:
	if is_broken:
		return

	drilling_player = player
	is_being_drilled = true
	
func break_from_drill(player: CharacterBody2D) -> void:
	if is_broken:
		return

	is_broken = true
	is_being_drilled = false
	drilling_player = player

	$CollisionShape2D.set_deferred("disabled", true)
	$Sprite2D.visible = false

	GameManager.add_score(score_reward)
	GameManager.collect_mineral(1)
	spawn_energy_fragments(player)

	mineral_broken.emit(
		energy_reward,
		score_reward,
		global_position
	)

	queue_free()

func spawn_energy_fragments(player: CharacterBody2D) -> void:
	if energy_fragment == null:
		push_error("MineralDeposit has no Energy Fragment scene assigned.")
		return

	var energy_per_fragment: float = energy_reward / fragment_count
	var score_per_fragment: int = score_reward / fragment_count

	for i in range(fragment_count):
		var fragment = energy_fragment.instantiate()
		get_tree().current_scene.add_child(fragment)

		fragment.global_position = global_position + Vector2(
			randf_range(-8.0, 8.0),
			randf_range(-8.0, 8.0)
		)

		fragment.setup(
			player,
			energy_per_fragment,
			score_per_fragment
		)

func get_drill_clash_settings() -> Dictionary:
	return {
		"gain_multiplier": 1.5,
		"drain_multiplier": 0.5,
		"failure_damage": 0
	}
