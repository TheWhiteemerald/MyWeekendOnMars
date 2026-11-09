extends Node2D

@export var minerals_required: int = 8
@export var secret_minerals_required: int = 12

func _ready() -> void:
	GameManager.start_level(
		minerals_required,
		secret_minerals_required
	)
