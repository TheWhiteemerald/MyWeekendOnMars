extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.has_method("set_surface_state"):
		print("Surface Reached")
		body.set_surface_state(true)

func _on_body_exited(body):
	if body.has_method("set_surface_state"):
		print("Surface Left")
		body.set_surface_state(false)
