extends Node

signal score_changed(current_score: int)
signal minerals_changed(
	current: int,
	required: int,
	secret_required: int
)

var score: int = 0

var minerals_collected: int = 0
var minerals_required: int = 0
var secret_minerals_required: int = 0

# Add Points to Score
func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

# Resets Score At Start of Game
func reset_score() -> void:
	score = 0
	score_changed.emit(score)

# Add Collected Minerals
func collect_mineral(amount: int = 1) -> void:
	minerals_collected += amount

	minerals_changed.emit(
		minerals_collected,
		minerals_required,
		secret_minerals_required
	)

# Set Up New Level
func start_level(
	required_minerals: int,
	secret_required: int
) -> void:
	minerals_collected = 0
	minerals_required = required_minerals
	secret_minerals_required = secret_required

	minerals_changed.emit(
		minerals_collected,
		minerals_required,
		secret_minerals_required
	)

# Check Main Goal
func has_met_level_requirement() -> bool:
	return minerals_collected >= minerals_required

# Check Secret Goal
func has_met_secret_requirement() -> bool:
	return minerals_collected >= secret_minerals_required

# Transition to New Levels
func change_level(level_path: String) -> void:
	if level_path.is_empty():
		push_error("No level path was provided.")
		return

	var error := get_tree().change_scene_to_file(level_path)

	if error != OK:
		push_error(
			"Failed to load scene: " + level_path
		)
