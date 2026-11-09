class_name CrawlerBot
extends CharacterBody2D

@export var speed: float = 40.0

@onready var surface_ray: RayCast2D = $SurfaceRay
@onready var forward_ray: RayCast2D = $ForwardRay

func _physics_process(_delta: float) -> void:
	surface_ray.force_raycast_update()
	forward_ray.force_raycast_update()

	if forward_ray.is_colliding():
		print("Inside turn at: ", global_position)
		turn_inside_corner()

		# Refresh the rays after rotating their parent.
		surface_ray.force_raycast_update()
		forward_ray.force_raycast_update()

	elif not surface_ray.is_colliding():
		velocity = Vector2.ZERO
		return  # Diagnostic: stop instead of repeatedly turning.

	var move_direction: Vector2 = Vector2.RIGHT.rotated(rotation)
	velocity = move_direction * speed
	move_and_slide()

func turn_inside_corner() -> void:
	rotation -= PI / 2.0

func turn_outside_corner() -> void:
	rotation += PI / 2.0
