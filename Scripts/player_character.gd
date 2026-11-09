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

enum DigVisualPhase {
	NONE,
	START,
	LOOP,
	END
}

var dig_visual_phase: DigVisualPhase = DigVisualPhase.NONE
var dig_visual_type: String = ""

var dig_visual_facing_left: bool = false

@export var dig_move_duration: float = 0.12
@export var dig_energy_per_tile: float = 0.2

@export var dig_duration: float = 0.16
@export var dig_energy_drain_per_second: float = 2.5
@export var upward_dig_boost: float = 300.0
@export var upward_gravity_pause: float = 0.08

# Energy System
@export var max_energy: float = 100.0
var energy: float
@export var energy_drain_per_second: float = 2.5

# Scoring System
signal score_changed(current_score)

var score: int = 0

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
const SPEED = 220.0
const JUMP_VELOCITY = -280.0

@export_group("Movement Feel")
@export var ground_acceleration: float = 250.0
@export var ground_turn_acceleration: float = 1000.0
@export var ground_friction: float = 1200.0

@export var air_acceleration: float = 300.0
@export var air_turn_acceleration: float = 800.0
@export var air_friction: float = 600.0

const WALL_JUMP_FORCE = Vector2(150, -350)
const TILE_SIZE = 16

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var rover_sprite = $"Rover Sprite"
@onready var tile_map = $"../TileMap"

@onready var drill_attack_area = $"Drill Attack Area"
@export var drill_attack_offset := 18.0

@onready var pause_menu = $"Pause Menu"

var current_drill_target = null
var is_drill_clashing := false

@export var clash_max_value := 100.0
@export var clash_drain_per_second := 85.0
@export var clash_gain_per_press := 22.0
@export var clash_start_value := 35.0

var clash_value := 0.0

var rover_sprite_start_pos: Vector2

var active_clash_gain_multiplier: float = 1.0
var active_clash_drain_multiplier: float = 1.0
var active_clash_failure_damage: int = 1

@onready var up_drill_check: ShapeCast2D = $UpDrillCheck

@export var upward_drill_attack_duration: float = 0.6

var upward_drill_attack_active: bool = false
var upward_drill_attack_timer: float = 0.0

var upward_launch_defeated_ids: Array[int] = []

var is_landing_animation: bool = false

var upward_launch_visual_active: bool = false

func _ready():
	add_to_group("player")
	health = max_health
	energy = max_energy
	emit_resource_changed()
	pause_menu.hide()
	rover_sprite_start_pos = rover_sprite.position
	score_changed.emit(score)
	rover_sprite.animation_finished.connect(
		_on_rover_animation_finished
	)

func _physics_process(delta: float) -> void:
	if is_drill_clashing:
		update_drill_clash(delta)
		return

	# Pause Menu
	#if Input.is_action_just_pressed("Pause"):
		#pause_menu.show()
		#get_tree().paused = true

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
	var direction := Input.get_axis("Left", "Right")

	if not is_digging:
		var grounded := is_on_floor()
		var acceleration := ground_acceleration if grounded \
			else air_acceleration
		var friction := ground_friction if grounded \
			else air_friction

		if direction != 0.0:
			# Stronger braking when input opposes current movement.
			var reversing := velocity.x * direction < 0.0

			if reversing:
				acceleration = ground_turn_acceleration if grounded \
					else air_turn_acceleration

			velocity.x = move_toward(
				velocity.x,
				direction * SPEED,
				acceleration * delta
			)

			rover_sprite.flip_h = direction < 0.0
			update_drill_attack_area()
		else:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				friction * delta
			)

		play_movement_animation()

	handle_digging(delta)
	update_dig_visual()

	if is_digging or is_drill_clashing:
		return

	var upward_speed_before_move: float = velocity.y

	update_upward_drill_attack(delta)

	var was_airborne := not is_on_floor()
	move_and_slide()

	resolve_upward_drill_contact()
	restore_upward_launch_momentum(upward_speed_before_move)

	if upward_launch_visual_active and (velocity.y >= 0.0 or is_on_floor()):
		upward_launch_visual_active = false

	if was_airborne and is_on_floor():
		if not is_invulnerable \
				and not is_digging \
				and not is_drill_clashing \
				and dig_visual_phase == DigVisualPhase.NONE:
			is_landing_animation = true
			rover_sprite.play(&"Rover Land")

	play_movement_animation()

# Handles the Dig Check for Tiles and Enemies
func handle_digging(delta: float) -> bool:
	if is_digging:
		return update_digging(delta)

	# Let the upward launch finish without starting another
	# tile dig or an ordinary clash during it.
	if upward_drill_attack_active:
		return false

	if Input.is_action_just_pressed("Dig") and not is_drill_clashing:
		# A deliberate upward attack can free the rover when
		# an enemy is sitting on its head.
		if get_dig_direction() == Vector2.UP:
			var above = get_drill_target_above()

			if above != null:
				start_drill_clash(above)
				return false

		var enemy = get_enemy_in_drill_range()

		if enemy != null and try_enemy_drill_attack(enemy):
			return false

	if Input.is_action_pressed("Dig"):
		var dir: Vector2 = get_dig_direction()

		if dir != Vector2.ZERO:
			start_dig(dir)

	return false

# Begins Dig When Tile Present
func start_dig(dir: Vector2) -> void:
	
	if is_digging:
		return
	
	var target_world_pos = global_position + dir * TILE_SIZE
	var tile_coords = tile_map.local_to_map(
	tile_map.to_local(target_world_pos)
)
	
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

# Handles Continous Digging When Players Hold Down Dig Button
func update_digging(delta: float) -> bool:
	dig_progress += delta / dig_move_duration
	dig_progress = min(dig_progress, 1.0)

	global_position = dig_start_position.lerp(
		dig_target_position,
		dig_progress
	)

	if dig_progress >= 1.0:
		return finish_dig()

	return false

# Handles the End of the Dig Process
func finish_dig() -> bool:
	var tile_id: int = tile_map.get_cell_source_id(
		0,
		dig_target_tile
	)

	if tile_id != -1:
		tile_map.erase_cell(0, dig_target_tile)
		tile_map.update_internals()

	global_position = dig_target_position

	is_digging = false
	dig_progress = 0.0

	if dig_direction == Vector2.UP and not has_tile_above(dig_target_tile):
		velocity.x = 0.0
		velocity.y = -upward_dig_boost
		gravity_pause_timer = upward_gravity_pause

		upward_drill_attack_active = true
		upward_drill_attack_timer = upward_drill_attack_duration

		dig_direction = Vector2.ZERO
		
		# The launch replaces the normal Dig Up End transition.
		dig_visual_phase = DigVisualPhase.NONE
		dig_visual_type = ""

		upward_launch_visual_active = not is_invulnerable
		if upward_launch_visual_active:
			rover_sprite.play(&"Rover Drill Jump")
			
		return true

	velocity = Vector2.ZERO
	dig_direction = Vector2.ZERO

	if Input.is_action_pressed("Dig"):
		var next_dir: Vector2 = get_dig_direction()

		if next_dir != Vector2.ZERO:
			start_dig(next_dir)

	return false

# Checks for Tiles Above for Upwards Momentum after Finsished Dig Process
func has_tile_above(tile_coords: Vector2i) -> bool:
	var tile_above: Vector2i = tile_coords + Vector2i.UP
	var tile_id: int = tile_map.get_cell_source_id(0, tile_above)

	return tile_id != -1

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
	var target_world_pos = global_position + dir * TILE_SIZE
	var tile_coords = tile_map.local_to_map(
	tile_map.to_local(target_world_pos)
)
	
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
	if is_invulnerable:
		return
		
	end_upward_drill_attack()

	if is_drill_clashing:
		end_drill_clash()

	apply_damage(amount)
	velocity = knockback
	start_invulnerability()

func start_invulnerability() -> void:
	# Repeated calls should not start overlapping timers.
	if is_invulnerable:
		return

	is_invulnerable = true

	# Damage interrupts the current dig animation.
	# Reset its visual state so it can restart cleanly afterward.
	dig_visual_phase = DigVisualPhase.NONE
	dig_visual_type = ""

	reset_rover_sprite_position()
	rover_sprite.visible = true
	rover_sprite.play("Rover Damaged")

	# Pause this timer when the game is paused.
	await get_tree().create_timer(
		invulnerability_time,
		false
	).timeout

	is_invulnerable = false
	rover_sprite.visible = true

	# Resume whichever animation matches the current action.
	update_dig_visual()
	play_movement_animation()

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
		if not is_instance_valid(body):
			continue

		if body.is_queued_for_deletion():
			continue

		if not body.has_method("start_being_drilled"):
			continue

		if body.has_method("get_drill_response"):
			var response: StringName = body.get_drill_response(
				drill_attack_area.global_position,
				get_enemy_attack_direction()
			)

			if response == &"none":
				continue

		return body

	return null
	
func start_drill_clash(enemy) -> void:
	if not is_instance_valid(enemy) or is_drill_clashing:
		return

	active_clash_gain_multiplier = 1.0
	active_clash_drain_multiplier = 1.0
	active_clash_failure_damage = 1

	if enemy.has_method("get_drill_clash_settings"):
		var settings: Dictionary = enemy.get_drill_clash_settings()

		active_clash_gain_multiplier = float(
			settings.get("gain_multiplier", 1.0)
		)
		active_clash_drain_multiplier = float(
			settings.get("drain_multiplier", 1.0)
		)
		active_clash_failure_damage = int(
			settings.get("failure_damage", 1)
		)

	is_drill_clashing = true
	current_drill_target = enemy
	clash_value = clash_start_value
	velocity = Vector2.ZERO

	enemy.start_being_drilled(self)

	clash_started.emit()
	clash_changed.emit(clash_value, clash_max_value)

func update_drill_clash(delta: float) -> void:
	if not is_instance_valid(current_drill_target):
		end_drill_clash()
		return

	if current_drill_target.is_queued_for_deletion():
		end_drill_clash()
		return

	shake_rover_sprite()
	velocity = Vector2.ZERO

	clash_value -= (
		clash_drain_per_second
		* active_clash_drain_multiplier
		* delta
	)

	if Input.is_action_just_pressed("Dig"):
		clash_value += (clash_gain_per_press * active_clash_gain_multiplier)
		clash_pressed.emit()

	clash_value = clampf(clash_value, 0.0, clash_max_value)
	clash_changed.emit(clash_value, clash_max_value)

	if current_drill_target.has_method("update_drill_cracks"):
		current_drill_target.update_drill_cracks(
			clash_value / clash_max_value
		)

	clash_position_changed.emit(
		global_position,
		current_drill_target.global_position
	)

	if clash_value >= clash_max_value:
		win_drill_clash()
		return

	if clash_value <= 0.0:
		lose_drill_clash()
		return

	if current_drill_target.has_method("shake_sprite"):
		current_drill_target.shake_sprite()
	
func win_drill_clash() -> void:
	if current_drill_target:
		if current_drill_target.has_method("break_from_drill"):
			current_drill_target.break_from_drill(self)
		elif current_drill_target.has_method("die"):
			current_drill_target.die()

	end_drill_clash()
	
func lose_drill_clash() -> void:
	var failure_damage := active_clash_failure_damage
	var push_direction: float = 1.0

	if is_instance_valid(current_drill_target):
		push_direction = signf(
			global_position.x - current_drill_target.global_position.x
		)

		if push_direction == 0.0:
			push_direction = 1.0

	end_drill_clash()

	if failure_damage > 0:
		take_hit(failure_damage, Vector2(150.0 * push_direction, -200.0))

func end_drill_clash() -> void:
	var previous_target = current_drill_target
	var was_clashing := is_drill_clashing

	is_drill_clashing = false
	current_drill_target = null
	clash_value = 0.0

	reset_rover_sprite_position()

	if is_instance_valid(previous_target):
		if not previous_target.is_queued_for_deletion():
			if previous_target.has_method("reset_sprite_position"):
				previous_target.reset_sprite_position()

			if previous_target.has_method("stop_being_drilled"):
				previous_target.stop_being_drilled()

	if was_clashing:
		clash_ended.emit()
	
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

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func collect_energy_fragment(
	energy_amount: float,
	score_amount: int
) -> void:
	gain_energy(energy_amount)
	add_score(score_amount)

func get_current_dig_visual_type() -> String:
	if not is_digging:
		return ""

	if dig_direction == Vector2.UP:
		return "Up"

	if dig_direction == Vector2.DOWN:
		return "Down"

	if dig_direction == Vector2.LEFT \
			or dig_direction == Vector2.RIGHT:
		return "Side"

	return ""


func play_dig_visual_animation(suffix: String) -> void:
	var animation_name := "Rover Dig %s %s" % [
		dig_visual_type,
		suffix
	]

	rover_sprite.play(animation_name)


func update_dig_visual() -> void:
	if is_invulnerable:
		return
	
	var requested_type := get_current_dig_visual_type()

	if requested_type != "":
		if requested_type == "Side":
			dig_visual_facing_left = dig_direction == Vector2.LEFT
			rover_sprite.flip_h = dig_visual_facing_left
			update_drill_attack_area()

		# Start when entering a dig, changing animation direction,
		# or interrupting a finishing animation.
		if requested_type != dig_visual_type \
				or dig_visual_phase == DigVisualPhase.NONE \
				or dig_visual_phase == DigVisualPhase.END:
			dig_visual_type = requested_type
			dig_visual_phase = DigVisualPhase.START
			play_dig_visual_animation("Start")

		return

	# Digging stopped, or changed to a direction without artwork.
	if dig_visual_phase == DigVisualPhase.START \
			or dig_visual_phase == DigVisualPhase.LOOP:
		dig_visual_phase = DigVisualPhase.END
		play_dig_visual_animation("End")

func _on_rover_animation_finished() -> void:
	if is_invulnerable:
		return

	if rover_sprite.animation == &"Rover Land":
		is_landing_animation = false
		play_movement_animation()
		return

	if dig_visual_type == "":
		return

	match dig_visual_phase:
		DigVisualPhase.START:
			var expected_animation := StringName(
				"Rover Dig %s Start" % dig_visual_type
			)

			if rover_sprite.animation != expected_animation:
				return

			if get_current_dig_visual_type() == dig_visual_type:
				dig_visual_phase = DigVisualPhase.LOOP
				play_dig_visual_animation("Loop")
			else:
				dig_visual_phase = DigVisualPhase.END
				play_dig_visual_animation("End")

		DigVisualPhase.END:
			var expected_animation := StringName(
				"Rover Dig %s End" % dig_visual_type
			)

			if rover_sprite.animation != expected_animation:
				return

			dig_visual_phase = DigVisualPhase.NONE
			dig_visual_type = ""

			# Pick up a new dig if one began during the transition.
			update_dig_visual()

			if dig_visual_phase == DigVisualPhase.NONE:
				if is_digging:
					rover_sprite.play("Rover Idle")
				else:
					play_movement_animation()

func play_movement_animation() -> void:
	if is_invulnerable:
		is_landing_animation = false
		play_rover_animation_if_changed(&"Rover Damaged")
		return

	if dig_visual_phase != DigVisualPhase.NONE:
		is_landing_animation = false

		if dig_visual_type == "Side":
			rover_sprite.flip_h = dig_visual_facing_left

		return

	if is_digging or is_drill_clashing:
		is_landing_animation = false
		return

	if upward_launch_visual_active:
		is_landing_animation = false
		play_rover_animation_if_changed(&"Rover Dig Up Launch")
		return

	# A new jump or leaving the platform interrupts recovery.
	# Checking velocity also catches a jump before the next
	# move_and_slide() updates the floor contact.
	if velocity.y < 0.0 or not is_on_floor():
		is_landing_animation = false

		if velocity.y < 0.0:
			play_rover_animation_if_changed(&"Rover Jump")
		else:
			play_rover_animation_if_changed(&"Rover Fall")

		return

	# Remain in the recovery animation until it finishes.
	if is_landing_animation:
		return

	if Input.get_axis("Left", "Right") != 0.0:
		play_rover_animation_if_changed(&"Rover Walk")
	else:
		play_rover_animation_if_changed(&"Rover Idle")

func play_rover_animation_if_changed(animation_name: StringName) -> void:
	if rover_sprite.animation != animation_name:
		rover_sprite.play(animation_name)

func get_enemy_attack_direction() -> Vector2:
	var aim := get_dig_direction()

	# Allow Dig without a direction to attack horizontally
	# in the direction the rover is facing.
	if aim == Vector2.ZERO:
		return Vector2.LEFT if rover_sprite.flip_h else Vector2.RIGHT

	return aim

func try_enemy_drill_attack(enemy) -> bool:
	if not is_instance_valid(enemy):
		return false

	if enemy.is_queued_for_deletion():
		return false

	if is_digging or is_drill_clashing:
		return false

	if enemy.has_method("get_drill_response"):
		var response: StringName = enemy.get_drill_response(
			drill_attack_area.global_position,
			get_enemy_attack_direction()
		)

		match response:
			&"defeat":
				if enemy.has_method("defeat_from_behind"):
					enemy.defeat_from_behind(
						get_enemy_attack_direction()
					)
				else:
					enemy.die()

				return true

			&"clash":
				start_drill_clash(enemy)
				return true

			_:
				return false

	# Preserve the old behavior for other enemies and crates.
	if enemy.has_method("start_being_drilled"):
		start_drill_clash(enemy)
		return true

	return false

func get_drill_target_above():
	up_drill_check.force_shapecast_update()

	for index in range(up_drill_check.get_collision_count()):
		var target = up_drill_check.get_collider(index)

		if not is_instance_valid(target):
			continue

		if target.is_queued_for_deletion():
			continue

		if not target.has_method("can_be_drilled_from_below"):
			continue

		if target.can_be_drilled_from_below():
			return target

	return null

func end_upward_drill_attack() -> void:
	upward_drill_attack_active = false
	upward_drill_attack_timer = 0.0


func update_upward_drill_attack(delta: float) -> void:
	if not upward_drill_attack_active:
		return

	upward_drill_attack_timer -= delta

	if upward_drill_attack_timer <= 0.0 or velocity.y >= 0.0:
		end_upward_drill_attack()
		return

	# Detect an enemy just above the rover before moving.
	var target = get_drill_target_above()

	if target != null:
		if defeat_enemy_with_upward_launch(target):
			end_upward_drill_attack()

func resolve_upward_drill_contact() -> void:
	if not upward_drill_attack_active:
		return

	# Movement may have brought the drill into range.
	var target = get_drill_target_above()

	if target != null:
		if defeat_enemy_with_upward_launch(target):
			end_upward_drill_attack()
			return

	# Also inspect actual body collisions. Hitting an enemy
	# can stop upward velocity before the next physics tick.
	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)

		# A downward-pointing collision normal means the rover
		# struck something overhead.
		if collision.get_normal().dot(Vector2.DOWN) < 0.5:
			continue

		var collider = collision.get_collider()

		if is_instance_valid(collider):
			if collider.has_method("receive_upward_drill_launch"):
				collider.receive_upward_drill_launch()

		end_upward_drill_attack()
		return

	if is_on_ceiling() or is_on_floor() or velocity.y >= 0.0:
		end_upward_drill_attack()

func try_upward_launch_against(enemy) -> bool:
	if not upward_drill_attack_active or velocity.y >= 0.0:
		return false

	if not is_instance_valid(enemy):
		return false

	if not enemy.has_method("receive_upward_drill_launch"):
		return false

	up_drill_check.force_shapecast_update()

	for index in range(up_drill_check.get_collision_count()):
		if up_drill_check.get_collider(index) == enemy:
			if enemy.receive_upward_drill_launch():
				end_upward_drill_attack()
				return true

	return false

func defeat_enemy_with_upward_launch(enemy) -> bool:
	if not is_instance_valid(enemy):
		return false

	if enemy.is_queued_for_deletion():
		return false

	if not enemy.has_method("receive_upward_drill_launch"):
		return false

	var enemy_id: int = enemy.get_instance_id()
	var rover_facing: float = -1.0 if rover_sprite.flip_h else 1.0

	if not enemy.receive_upward_drill_launch(rover_facing):
		return false

	upward_launch_defeated_ids.append(enemy_id)
	return true

func restore_upward_launch_momentum(previous_y_speed: float) -> void:
	if upward_launch_defeated_ids.is_empty():
		return

	var hit_other_ceiling := false

	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)

		# Only inspect surfaces struck from underneath.
		if collision.get_normal().dot(Vector2.DOWN) < 0.5:
			continue

		var collider_id: int = collision.get_collider_id()

		# The defeated enemy should not stop the launch.
		# Any other overhead obstacle still should.
		if not upward_launch_defeated_ids.has(collider_id):
			hit_other_ceiling = true
			break

	if previous_y_speed < 0.0 and not hit_other_ceiling:
		velocity.y = previous_y_speed

	upward_launch_defeated_ids.clear()
