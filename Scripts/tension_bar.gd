extends CanvasLayer

@onready var character_body_2d = $"../CharacterBody2D"
@onready var clash_bar = $"Clash Bar"

func _ready():
	clash_bar.visible = false
	
	character_body_2d.clash_started.connect(show_clash_bar)
	character_body_2d.clash_ended.connect(hide_clash_bar)
	character_body_2d.clash_changed.connect(update_clash_bar)
	
	character_body_2d.clash_pressed.connect(pulse_clash_bar)

func show_clash_bar():
	clash_bar.visible = true

func hide_clash_bar():
	clash_bar.visible = false

func update_clash_bar(value, max_value):
	clash_bar.max_value = max_value
	clash_bar.value = value

func update_clash_bar_position(player_pos: Vector2, enemy_pos: Vector2):
	var midpoint = (player_pos + enemy_pos) / 2
	clash_bar.global_position = midpoint + Vector2(-clash_bar.size.x / 2, -32)
	
func pulse_clash_bar():
	clash_bar.scale = Vector2(1.15, 1.15)
	await get_tree().create_timer(0.06).timeout
	clash_bar.scale = Vector2.ONE
