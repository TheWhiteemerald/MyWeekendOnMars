class_name LevelGoal
extends Area2D

@export_file("*.tscn") var normal_level_path: String
@export_file("*.tscn") var secret_level_path: String

var is_activated: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_activated:
		return

	if not body.is_in_group("player"):
		return

	if not GameManager.has_met_level_requirement():
		print("Not enough minerals.")
		return

	is_activated = true

	if GameManager.has_met_secret_requirement():
		GameManager.change_level(secret_level_path)
	else:
		GameManager.change_level(normal_level_path)
