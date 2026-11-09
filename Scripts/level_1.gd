extends Node2D

@export var minerals_required: int = 12
@export var secret_minerals_required: int = 15

func _ready() -> void:
	GameManager.start_level(
		minerals_required,
		secret_minerals_required
	)
