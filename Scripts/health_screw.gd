extends Area2D

@export var heal_amount: int = 1

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.has_method("heal"):
		body.heal(heal_amount)
		print("Player healed. Current health:", body.health)
		GameManager.add_score(25)
		queue_free()
