extends Area2D

@export var energy_amount: float = 25.0

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.has_method("gain_energy"):
		body.gain_energy(energy_amount)
		GameManager.add_score(50)
		queue_free()
