extends CanvasLayer

@onready var health_display = $MarginContainer/VBoxContainer/HealthDisplay
@onready var energy_bar = $MarginContainer/VBoxContainer/EnergyBar
@onready var character_body_2d = $"../CharacterBody2D"
@onready var score_label = $ScoreLabel
@onready var mineral_label = $MineralLabel

@export var health_5: Texture2D
@export var health_4: Texture2D
@export var health_3: Texture2D
@export var health_2: Texture2D
@export var health_1: Texture2D
@export var health_0: Texture2D

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.minerals_changed.connect(_on_minerals_changed)

	_on_score_changed(GameManager.score)

	_on_minerals_changed(
		GameManager.minerals_collected,
		GameManager.minerals_required,
		GameManager.secret_minerals_required
	)

	character_body_2d.health_changed.connect(_on_health_changed)
	character_body_2d.energy_changed.connect(_on_energy_changed)

	_on_health_changed(character_body_2d.health, character_body_2d.max_health)
	_on_energy_changed(character_body_2d.energy, character_body_2d.max_energy)

func _on_score_changed(current_score: int) -> void:
	$ScoreLabel.text = "%06d" % current_score

func _on_health_changed(current, _maximum):
	match current:
		5:
			health_display.texture = health_5
		4:
			health_display.texture = health_4
		3:
			health_display.texture = health_3
		2:
			health_display.texture = health_2
		1:
			health_display.texture = health_1
		_:
			health_display.texture = health_0

func _on_energy_changed(current, maximum):
	energy_bar.max_value = maximum
	energy_bar.value = current
	
	var ratio = current / maximum
	
	if ratio > 0.3:
		energy_bar.modulate = Color(1, 1, 1) # normal
	elif ratio > 0.15:
		energy_bar.modulate = Color(1, 1, 0.5) # yellow
	elif ratio > 0.05:
		energy_bar.modulate = Color(1, 0.5, 0.2) # orange
	else:
		energy_bar.modulate = Color(1, 0.2, 0.2) # red
		start_energy_warning()
var is_flashing := false

func start_energy_warning():
	if is_flashing:
		return
	
	is_flashing = true
	flash_energy_bar()

func flash_energy_bar() -> void:
	while character_body_2d.get_energy_ratio() < 0.1:
		energy_bar.visible = false
		await get_tree().create_timer(0.1).timeout
		energy_bar.visible = true
		await get_tree().create_timer(0.1).timeout
	
	is_flashing = false

func _on_minerals_changed(
	current: int,
	required: int,
	secret_required: int
) -> void:
	$MineralLabel.text = "%d/%d" % [
		current,
		required
	]

	if current >= secret_required:
		$MineralLabel.add_theme_color_override(
			"font_color",
			Color.CYAN
		)

	elif current >= required:
		$MineralLabel.add_theme_color_override(
			"font_color",
			Color.LIGHT_BLUE
		)

	else:
		$MineralLabel.add_theme_color_override(
			"font_color",
			Color.WHITE
		)
