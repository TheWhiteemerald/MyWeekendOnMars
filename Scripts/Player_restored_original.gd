extends CharacterBody2D

# Resource Signals
signal health_changed(current, maximum)
signal energy_changed(current, maximum)

# Attack Signals
signal clash_started
signal clash_ended
signal clash_changed(current, maximum)
signal clash_position_changed(player_pos, enemy_pos)
signal clash_pressed

var is_invulnerable: bool = false
@export var invulnerability_time: float = 0.5
@export var max_health: int = 5

# Digging
var is_digging: bool = false
var dig_direction: Vector2 = Vector2.ZERO
var dig_start_position: Vector2
var dig_target_position: Vector2
var dig_target_tile: Vector2i
var dig_progress: float = 0.0

@export var dig_move_duration: float = 0.12
@export var dig_energy_per_tile: float = 0.2

@export var dig_duration: float = 0.16
@export var dig_energy_drain_per_second: float = 2.5
@export var upward_dig_boost: float = 180.0
@export var upward_gravity_pause: float = 0.28

# Energy System
@export var max_energy: float = 100.0
var energy: float
@export var energy_drain_per_second: float = 2.5

# Critical state
var is_energy_depleted: bool = false
@export var critical_duration: float = 2.0
var critical_timer: float = 100.0

# Surface recharge
var is_on_surface: bool = false
@export var surface_recharge_rate: float = 8.0

# Timer Variablies
var gravity_pause_timer: float = 0.0
var energy_regen_delay_timer: float = 0.0

# Resources (runtime state)
var health: int

# Movement Constants
const SPEED = 200.0
const JUMP_VELOCITY = -250.0
const ACCELERATION = 300.0
const FRICTION = 800.0
const WALL_JUMP_FORCE = Vector2(100, -350)
const TILE_SIZE = 16

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var rover_sprite = $"Rover Sprite"
@onready var tile_map = $"../TileMap"

@onready var drill_attack_area = $"Drill Attack Area"
@export var drill_attack_offset := 18.0

var current_drill_target = null
var is_drill_clashing := false

@export var clash_max_value := 100.0
@export var clash_drain_per_second := 85.0
@export var clash_gain_per_press := 22.0
@export var clash_start_value := 35.0

var clash_value := 0.0

var rover_sprite_start_pos: Vector2

func _ready():
	add_to_group("player")
	health = max_health
	energy = max_energy
	emit_resource_changed()
	rover_sprite_start_pos = rover_sprite.position

func _physics_process(delta):
	
	if is_drill_clashing:
		update_drill_clash(delta)
		return
	
	# Gravity
	if gravity_pause_timer > 0.0:
		gravity_pause_timer -= delta
	elif not is_on_floor():
		velocity.y += gravity * delta
	
	# Jump Input
	if Input.is_action_just_pressed("Jump") and is_on_floor() and not is_digging:
		velocity.y = JUMP_VELOCITY
	
	# Jump Released Early
	if Input.is_action_just_released("Jump") and velocity.y < -100:
		velocity.y = -100
	
	# Wall Jump
	if Input.is_action_just_pressed("Jump") and is_on_wall() and not is_on_floor() and not is_digging:
		var normal = get_wall_normal()
		velocity.x = normal.x * WALL_JUMP_FORCE.x
		velocity.y = WALL_JUMP_FORCE.y * 0.9
	
	if Input.is_action_just_pressed("Pause"):
		pass
	
	# Idle Energy
	var is_active = is_digging or abs(velocity.x) > 0.1
	
	if is_active and not is_on_surface and not is_energy_depleted:
		spend_energy(energy_drain_per_second * delta)
	
	if is_on_surface:
		gain_energy(surface_recharge_rate * delta)
	
	if is_energy_depleted:
		critical_timer -= delta
		if critical_timer <= 0.0:
			die()
		
	# Direction Control
	var direction = Input.get_axis("Left", "Right")
	
	if not is_digging:
		if direction:
			velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
			rover_sprite.flip_h = direction < 0
			update_drill_attack_area()
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
	
	handle_digging(delta)
	move_and_slide()

func handle_digging(delta: float) -> void:
	if is_digging:
		update_digging(delta)
		return
	
	if Input.is_action_just_pressed("Dig") and not is_drill_clashing:
		var enemy = get_enemy_in_drill_range()
		if enemy != null:
			start_drill_clash(enemy)
			return
	
	if Input.is_action_pressed("Dig"):
		var dir = get_dig_direction()
		if dir != Vector2.ZERO:
			start_dig(dir)

func start_dig(dir: Vector2) -> void:
	if is_digging:
		return
	
	var target_world_pos = global_position + dir * TILE_SIZE
	var tile_coords = tile_map.local_to_map(target_world_pos)
	var tile_id = tile_map.get_cell_source_id(0, tile_coords)
	
	if tile_id == -1:
		return
	
	is_digging = true
	dig_direction = dir
	dig_target_tile = tile_coords
	dig_start_position = global_position
	dig_target_position = tile_map.to_global(tile_map.map_to_local(tile_coords))
	dig_progress = 0.0
	
	spend_energy(dig_energy_per_tile)
		
func update_digging(delta: float) -> void:
	dig_progress += delta / dig_move_duration
	dig_progress = min(dig_progress, 1.0)
	
	global_position = dig_start_position.lerp(dig_target_position, dig_progress)
	
	if dig_progress >= 1.0:
		finish_dig()
		
func finish_dig() -> void:
	var tile_id = tile_map.get_cell_source_id(0, dig_target_tile)
	if tile_id != -1:
		tile_map.erase_cell(0, dig_target_tile)
	
	global_position = dig_target_position
	
	is_digging = false
	dig_progress = 0.0
	velocity = Vector2.ZERO
	
	if Input.is_action_pressed("Dig"):
		var next_dir = get_dig_direction()
		if next_dir != Vector2.ZERO:
			start_dig(next_dir)
	
func cancel_dig() -> void:
	is_digging = false
	dig_direction = Vector2.ZERO
	velocity = Vector2.ZERO

# Check which way the player is facing
func get_dig_direction() -> Vector2:
	if Input.is_action_pressed("Up"):
		print("Up")
		return Vector2.UP
	if Input.is_action_pressed("Down"):
		print("Down")
		return Vector2.DOWN
	if Input.is_action_pressed("Left"):
		print("Left")
		return Vector2.LEFT
	if Input.is_action_pressed("Right"):
		print("Right")
		return Vector2.RIGHT
	
	return Vector2.ZERO

# Checks which tile to break
func try_break_tile(dir: Vector2):
	var target_world_pos = global_position + dir * (TILE_SIZE * 0.75)
	var tile_coords = tile_map.local_to_map(target_world_pos)
	var tile_id = tile_map.get_cell_source_id(0, tile_coords)
	print("Checking tile:", tile_coords, "ID:", tile_id)

	if tile_id != -1:
		tile_map.erase_cell(0, tile_coords)

# Damage Application
func apply_damage(amount: int) -> void:
	health = max(health - amount, 0)
	health_changed.emit(health, max_health)
	print("Health:", health)

	if health <= 0:
		die()

# Healing Application
func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	health_changed.emit(health, max_health)

func take_hit(amount: int, knockback: Vector2) -> void:
	if is_drill_clashing:
		if current_drill_target and current_drill_target.has_method("enter_hit_pause"):
			current_drill_target.enter_hit_pause()
		end_drill_clash()
	
	# existing damage logic
	if is_invulnerable:
		return
	
	apply_damage(amount)
	velocity = knockback
	start_invulnerability()

func start_invulnerability() -> void:
	is_invulnerable = true
	hurt_flash()
	await get_tree().create_timer(invulnerability_time).timeout
	is_invulnerable = false
	rover_sprite.visible = true

# Energy Consumption
func spend_energy(amount: float) -> void:
	if is_energy_depleted:
		print("Energy:", energy)
		return
	
	energy = max(energy - amount, 0.0)
	energy_changed.emit(energy, max_energy)
	
	if energy <= 0.0:
		enter_critical_state()

# Energy Regained
func gain_energy(amount: float) -> void:
	energy = min(energy + amount, max_energy)
	energy_changed.emit(energy, max_energy)
	
	if energy > 0.0:
		is_energy_depleted = false

# Death Function
func die() -> void:
	print("Player died")

func emit_resource_changed():
	health_changed.emit(health, max_health)
	energy_changed.emit(energy, max_energy)
	
func hurt_flash() -> void:
	for i in range(6):
		rover_sprite.visible = false
		await get_tree().create_timer(0.08).timeout
		rover_sprite.visible = true
		await get_tree().create_timer(0.08).timeout
		
func enter_critical_state() -> void:
	is_energy_depleted = true
	critical_timer = critical_duration
	print("CRITICAL ENERGY")

func refill_energy_full() -> void:
	energy = max_energy
	is_energy_depleted = false
	energy_changed.emit(energy, max_energy)
	
func set_surface_state(state: bool) -> void:
	is_on_surface = state
	
func get_energy_ratio() -> float:
	return energy / max_energy

func get_enemy_in_drill_range():
	for body in drill_attack_area.get_overlapping_bodies():
		if body.has_method("start_being_drilled"):
			return body
	
	return null
	
func start_drill_clash(enemy):
	is_drill_clashing = true
	current_drill_target = enemy
	clash_value = clash_start_value
	
	velocity = Vector2.ZERO
	enemy.start_being_drilled(self)

	clash_started.emit()
	clash_changed.emit(clash_value, clash_max_value)

func update_drill_clash(delta):
	shake_rover_sprite()
	velocity = Vector2.ZERO
	
	clash_value -= clash_drain_per_second * delta
	
	if current_drill_target and current_drill_target.has_method("update_drill_cracks"):
		var ratio = clash_value / clash_max_value
		current_drill_target.update_drill_cracks(ratio)
	
	if Input.is_action_just_pressed("Dig"):
		clash_value += clash_gain_per_press
	
	clash_value = clamp(clash_value, 0.0, clash_max_value)
	clash_changed.emit(clash_value, clash_max_value)
	
	if current_drill_target:
		clash_position_changed.emit(global_position, current_drill_target.global_position)
	
	if clash_value >= clash_max_value:
		win_drill_clash()
	elif clash_value <= 0.0:
		lose_drill_clash()
	
	if current_drill_target and current_drill_target.has_method("shake_sprite"):
		current_drill_target.shake_sprite()
	
	if Input.is_action_just_pressed("Dig"):
		clash_value += clash_gain_per_press
		clash_pressed.emit()
	
func win_drill_clash():
	if current_drill_target and current_drill_target.has_method("die"):
		current_drill_target.die()
	
	end_drill_clash()
	
func lose_drill_clash():
	if current_drill_target:
		var push_direction = sign(global_position.x - current_drill_target.global_position.x)
		if push_direction == 0:
			push_direction = 1
		
		take_hit(1, Vector2(150 * push_direction, -200))
	
	if current_drill_target and current_drill_target.has_method("enter_hit_pause"):
		current_drill_target.enter_hit_pause()
	
	end_drill_clash()

func end_drill_clash():
	is_drill_clashing = false
	current_drill_target = null
	clash_value = 0.0
	clash_ended.emit()
	reset_rover_sprite_position()
	
	if current_drill_target and current_drill_target.has_method("reset_sprite_position"):
		current_drill_target.reset_sprite_position()

func update_drill_attack_area():
	if rover_sprite.flip_h:
		drill_attack_area.position.x = -drill_attack_offset
	else:
		drill_attack_area.position.x = drill_attack_offset

func shake_rover_sprite(amount: float = 1.5) -> void:
	rover_sprite.position = rover_sprite_start_pos + Vector2(
		randf_range(-amount, amount),
		randf_range(-amount, amount)
	)

func reset_rover_sprite_position() -> void:
	rover_sprite.position = rover_sprite_start_pos
