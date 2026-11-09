class_name MainMenu
extends Control

@onready var start_game_button: Button = $"TextureRect/MarginContainer/HBoxContainer/VBoxContainer/Start Game Button"
@onready var load_game_button: Button = $"TextureRect/MarginContainer/HBoxContainer/VBoxContainer/Load Game Button"
@onready var options_button: Button = $"TextureRect/MarginContainer/HBoxContainer/VBoxContainer/Options Button"
@onready var quit_button: Button = $"TextureRect/MarginContainer/HBoxContainer/VBoxContainer/Quit Button"
@onready var options_menu: OptionsMenu = $"Options Menu"
@onready var margin_container: MarginContainer = $TextureRect/MarginContainer

@export var start_level: PackedScene = preload("res://Levels/level_1.tscn")
@export var level_select: PackedScene = preload("res://Menus/level_select_menu.tscn")

func _ready() -> void:
	start_game_button.pressed.connect(_on_start_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	options_menu.exit_options_menu.connect(_on_options_closed)

	options_menu.hide()
	margin_container.show()

func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_packed(start_level)

func _on_load_game_pressed() -> void:
	# Add loading logic here.
	get_tree().change_scene_to_packed(level_select)

func _on_options_pressed() -> void:
	margin_container.hide()
	options_menu.show()

func _on_options_closed() -> void:
	options_menu.hide()
	margin_container.show()
	options_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()
