extends Area2D

@export var damage_amount: int = 1
@export var knockback_force: Vector2 = Vector2(150, -200)

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.has_method("take_hit"):
		var push_direction = sign(body.global_position.x - global_position.x)
		
		if push_direction == 0:
			push_direction = 1
		
		var final_knockback = Vector2(knockback_force.x * push_direction, knockback_force.y)
		body.take_hit(damage_amount, final_knockback)
		print("Player damaged. Current health:", body.health)
