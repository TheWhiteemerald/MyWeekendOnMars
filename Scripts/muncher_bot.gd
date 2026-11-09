extends CharacterBody2D

enum State {
	IDLE,
	CHASE,
	SEARCH,
	HIT_PAUSE
}

@export var idle_walk_speed := 10.0
@export var idle_min_time := 1.0
@export var idle_max_time := 3.0

@export var search_speed := 45.0
@export var search_time := 2.0

var idle_timer := 0.0
var search_timer := 0.0

var state: State = State.IDLE
var direction := -1

@export var patrol_speed := 40.0
@export var chase_speed := 75.0
@export var detection_range := 120.0
@export var idle_time := 1.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var sight_ray = $"Sight Ray"
@onready var animated_sprite_2d = $AnimatedSprite2D

@onready var player_character = get_tree().get_first_node_in_group("player")

@export var turn_cooldown_time := 0.2
var turn_cooldown := 0.0

@export var damage_amount := 1
@export var knockback_force := Vector2(150, -200)
@export var hit_pause_time := 0.6

var hit_pause_timer := 0.0

@onready var damage_area = $"Damage Area"

var sprite_start_pos: Vector2

@export var battery_scene: PackedScene
@export var screw_scene: PackedScene

@export_range(0.0, 1.0) var battery_drop_chance := 0.45
@export_range(0.0, 1.0) var screw_drop_chance := 0.15

const TILE_SIZE = 16

@export var lethal_fall_tiles := 5

var fall_start_y := 0.0
var was_on_floor := false

@export var blink_min_time := 2.0
@export var blink_max_time := 5.0

var blink_timer := 0.0
var is_playing_idle_special := false

var is_being_drilled := false

var fall_damage_ready := false

# Matches your existing art: unflipped faces left.
var facing_direction: int = -1

@export var chase_turn_delay: float = 0.4

# Maximum vertical distance between the drill area's center
# and the enemy body's center for a horizontal attack.
# Tune this with visible collision shapes enabled.
@export var side_attack_vertical_tolerance: float = 10.0

var pending_chase_direction: int = 0
var chase_turn_timer: float = 0.0
var is_dead: bool = false

@onready var body_shape: CollisionShape2D = $CollisionShape2D

@export_group("Defeat Effect")
@export var defeat_effect_scene: PackedScene

@export var rear_launch_speed: float = 180.0
@export var rear_launch_lift: float = 180.0

@export var upward_launch_side_speed: float = 90.0
@export var upward_launch_speed: float = 320.0

func _ready():
	damage_area.body_entered.connect(_on_damage_area_body_entered)
	pick_new_idle_behavior()
	update_sprite_direction()
	sprite_start_pos = animated_sprite_2d.position

	blink_timer = randf_range(blink_min_time, blink_max_time)
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)

	was_on_floor = is_on_floor()
	fall_start_y = global_position.y
	
	await get_tree().physics_frame
	was_on_floor = is_on_floor()
	fall_start_y = global_position.y
	fall_damage_ready = true

func _physics_process(delta):
	if turn_cooldown > 0.0:
		turn_cooldown -= delta

	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		State.IDLE:
			idle_state(delta)
		State.CHASE:
			chase_state(delta)
		State.SEARCH:
			search_state(delta)
		State.HIT_PAUSE:
			hit_pause_state(delta)

	move_and_slide()
	handle_fall_damage()

func idle_state(delta):
	handle_idle_animation(delta)
	
	if can_see_player():
		change_state(State.CHASE)
		return
	
	idle_timer -= delta
	
	velocity.x = direction * idle_walk_speed
	update_sprite_direction()
	
	if is_on_wall() and turn_cooldown <= 0.0:
		turn_around()
	
	if idle_timer <= 0.0:
		pick_new_idle_behavior()

func pick_new_idle_behavior():
	idle_timer = randf_range(idle_min_time, idle_max_time)
	
	var choice = randi_range(0, 2)
	
	match choice:
		0:
			direction = -1
		1:
			direction = 1
		2:
			direction = 0

func search_state(delta):
	search_timer -= delta
	
	if can_see_player():
		change_state(State.CHASE)
		return
	
	velocity.x = direction * search_speed
	update_sprite_direction()
	
	if is_on_wall() and turn_cooldown <= 0.0:
		turn_around()
	
	if search_timer <= 0.0:
		pick_new_idle_behavior()
		change_state(State.IDLE)

func chase_state(delta: float) -> void:
	if not can_see_player():
		pending_chase_direction = 0
		chase_turn_timer = 0.0
		search_timer = search_time
		change_state(State.SEARCH)
		return

	var difference_x: float = (
		player_character.global_position.x - global_position.x
	)

	# Avoid rapidly changing direction when the player is
	# almost directly above the enemy.
	if absf(difference_x) < 4.0:
		pending_chase_direction = 0
		chase_turn_timer = 0.0
		velocity.x = facing_direction * chase_speed
		return

	var desired_direction: int = 1 if difference_x > 0.0 else -1

	if desired_direction != facing_direction:
		if pending_chase_direction != desired_direction:
			pending_chase_direction = desired_direction
			chase_turn_timer = chase_turn_delay

		chase_turn_timer -= delta

		# Stop briefly, keeping the old facing direction.
		velocity.x = 0.0

		if chase_turn_timer <= 0.0:
			direction = desired_direction
			update_sprite_direction()
			pending_chase_direction = 0

		return

	pending_chase_direction = 0
	chase_turn_timer = 0.0
	direction = facing_direction
	velocity.x = direction * chase_speed

func can_see_player() -> bool:
	if player_character == null:
		return false

	var distance_to_player = global_position.distance_to(player_character.global_position)

	if distance_to_player > detection_range:
		return false

	sight_ray.target_position = sight_ray.to_local(player_character.global_position)
	sight_ray.force_raycast_update()

	if sight_ray.is_colliding():
		return sight_ray.get_collider() == player_character

	return false

func change_state(new_state: State):
	if state == new_state:
		return
	
	state = new_state
	print("Enemy state:", State.keys()[state])

func turn_around():
	direction *= -1
	turn_cooldown = turn_cooldown_time
	update_sprite_direction()

func update_sprite_direction() -> void:
	if direction != 0:
		facing_direction = 1 if direction > 0 else -1

	animated_sprite_2d.flip_h = facing_direction > 0

func _on_damage_area_body_entered(body) -> void:
	if is_dead or is_being_drilled or state == State.HIT_PAUSE:
		return

	if not body.is_in_group("player"):
		return

	# Resolve a valid launch before ordinary contact damage.
	if body.has_method("try_upward_launch_against"):
		if body.try_upward_launch_against(self):
			return

	# If the player pressed Dig as contact began, give a valid
	# drill attack a chance to resolve before contact damage.
	if Input.is_action_just_pressed("Dig"):
		if body.has_method("get_enemy_in_drill_range"):
			if body.get_enemy_in_drill_range() == self:
				if body.try_enemy_drill_attack(self):
					return

	if body.has_method("take_hit"):
		var push_direction: float = signf(
			body.global_position.x - global_position.x
		)

		if push_direction == 0.0:
			push_direction = facing_direction

		var final_knockback := Vector2(
			knockback_force.x * push_direction,
			knockback_force.y
		)

		body.take_hit(damage_amount, final_knockback)
		enter_hit_pause()
		
func hit_pause_state(delta):
	velocity.x = 0
	hit_pause_timer -= delta
	
	if hit_pause_timer <= 0.0:
		search_timer = search_time
		change_state(State.SEARCH)

func start_being_drilled(_player):
	velocity = Vector2.ZERO
	is_being_drilled = true
	change_state(State.HIT_PAUSE)
	hit_pause_timer = 999.0

func die(launch_velocity: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	is_dead = true
	is_being_drilled = false

	body_shape.set_deferred("disabled", true)
	damage_area.set_deferred("monitoring", false)
	damage_area.set_deferred("monitorable", false)
	$"Damage Area/CollisionShape2D".set_deferred("disabled", true)

	velocity = Vector2.ZERO
	set_physics_process(false)

	if launch_velocity != Vector2.ZERO:
		spawn_defeat_effect(launch_velocity)

	GameManager.add_score(100)
	drop_loot()

	hide()
	queue_free()

func enter_hit_pause():
	hit_pause_timer = hit_pause_time
	change_state(State.HIT_PAUSE)

func shake_sprite(amount: float = 1.5) -> void:
	animated_sprite_2d.position = sprite_start_pos + Vector2(
		randf_range(-amount, amount),
		randf_range(-amount, amount)
	)

func reset_sprite_position() -> void:
	animated_sprite_2d.position = sprite_start_pos

func drop_loot():
	var drop_position = global_position

	if battery_scene and randf() <= battery_drop_chance:
		var battery = battery_scene.instantiate()
		get_parent().add_child(battery)
		battery.global_position = drop_position + Vector2(-6, 0)

	if screw_scene and randf() <= screw_drop_chance:
		var screw = screw_scene.instantiate()
		get_parent().add_child(screw)
		screw.global_position = drop_position + Vector2(6, 0)

func handle_fall_damage():
	if not fall_damage_ready:
		return

	if was_on_floor and not is_on_floor():
		fall_start_y = global_position.y
	
	if not was_on_floor and is_on_floor():
		var fall_distance = global_position.y - fall_start_y
		var lethal_distance = lethal_fall_tiles * TILE_SIZE
		
		if fall_distance >= lethal_distance:
			print("Muncher died from fall!")
			die()
	
	was_on_floor = is_on_floor()

func update_drill_cracks(progress_ratio: float):
	if not is_being_drilled:
		return
	
	if animated_sprite_2d.animation != "cracks":
		animated_sprite_2d.play("cracks")
		animated_sprite_2d.pause()
	
	if progress_ratio >= 0.80:
		animated_sprite_2d.frame = 3
	elif progress_ratio >= 0.55:
		animated_sprite_2d.frame = 2
	elif progress_ratio >= 0.30:
		animated_sprite_2d.frame = 1
	else:
		animated_sprite_2d.frame = 0

func handle_idle_animation(delta):
	if is_being_drilled:
		return

	if is_playing_idle_special:
		return
	
	blink_timer -= delta
	
	if blink_timer <= 0.0:
		is_playing_idle_special = true
		animated_sprite_2d.play("blink")
	else:
		if animated_sprite_2d.animation != "default":
			animated_sprite_2d.play("default")
		
func stop_being_drilled() -> void:
	if is_dead:
		return

	is_being_drilled = false
	is_playing_idle_special = false
	reset_sprite_position()
	animated_sprite_2d.play("default")
	enter_hit_pause()

func _on_animation_finished():
	if animated_sprite_2d.animation == "blink":
		is_playing_idle_special = false
		blink_timer = randf_range(blink_min_time, blink_max_time)
		animated_sprite_2d.play("default")

func get_drill_response(
	attack_position: Vector2,
	attack_direction: Vector2
) -> StringName:
	if is_dead or is_being_drilled:
		return &"none"

	# This first prototype handles horizontal attacks only.
	if absf(attack_direction.x) < 0.5:
		return &"none"

	var offset := attack_position - body_shape.global_position

	# Do not classify an attack from well above/below as a rear hit.
	if absf(offset.y) > side_attack_vertical_tolerance:
		return &"none"

	# At the exact center, there is no reliable side to classify.
	if absf(offset.x) < 0.5:
		return &"none"

	var attack_side: int = 1 if offset.x > 0.0 else -1

	# The drill must point toward the enemy.
	if attack_direction.x * attack_side >= 0.0:
		return &"none"

	if attack_side == facing_direction:
		return &"clash"

	return &"defeat"

func can_be_drilled_from_below() -> bool:
	return not is_dead and not is_being_drilled


func receive_upward_drill_launch(
	rover_facing: float = 1.0
) -> bool:
	if not can_be_drilled_from_below():
		return false

	var launch_side: float = -1.0 if rover_facing < 0.0 else 1.0

	die(Vector2(
		upward_launch_side_speed * launch_side,
		-upward_launch_speed
	))

	return true

func spawn_defeat_effect(launch_velocity: Vector2) -> void:
	if defeat_effect_scene == null:
		return

	var effect = defeat_effect_scene.instantiate()

	# Add it alongside the enemy, so deleting the enemy
	# does not delete its visual effect.
	get_parent().add_child(effect)
	effect.setup(animated_sprite_2d, launch_velocity)


func defeat_from_behind(attack_direction: Vector2) -> void:
	var launch_side: float = (
		-1.0 if attack_direction.x < 0.0 else 1.0
	)

	die(Vector2(rear_launch_speed * launch_side,-rear_launch_lift))
