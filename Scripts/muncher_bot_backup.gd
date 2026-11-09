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

func _ready():
	damage_area.body_entered.connect(_on_damage_area_body_entered)
	pick_new_idle_behavior()
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

func chase_state(_delta):
	if not can_see_player():
		search_timer = search_time
		change_state(State.SEARCH)
		return
	
	var player_dir = sign(player_character.global_position.x - global_position.x)
	
	if player_dir != 0:
		direction = player_dir
	
	velocity.x = direction * chase_speed
	update_sprite_direction()

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

func update_sprite_direction():
	if direction == 0:
		return
	
	animated_sprite_2d.flip_h = direction > 0

func _on_damage_area_body_entered(body):
	if state == State.HIT_PAUSE:
		return
	
	if body.has_method("take_hit"):
		var push_direction = sign(body.global_position.x - global_position.x)
		
		if push_direction == 0:
			push_direction = direction
		
		var final_knockback = Vector2(knockback_force.x * push_direction, knockback_force.y)
		body.take_hit(damage_amount, final_knockback)
		
		change_state(State.HIT_PAUSE)
		hit_pause_timer = hit_pause_time
		
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

func die():
	print("Muncher destroyed!")
	GameManager.add_score(100)
	drop_loot()
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
		
func stop_being_drilled():
	is_being_drilled = false
	animated_sprite_2d.play("default")

func _on_animation_finished():
	if animated_sprite_2d.animation == "blink":
		is_playing_idle_special = false
		blink_timer = randf_range(blink_min_time, blink_max_time)
		animated_sprite_2d.play("default")
