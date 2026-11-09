class_name OptionsMenu
extends Control

signal exit_options_menu

const CONTROLS_SCENE = preload("res://Menus/controls_menu.tscn")
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720)
]

@onready var main_options: Control = $MarginContainer
@onready var back_button: Button = $"Back Button"
@onready var controls_button: Button = $"Controls Button"
var controls_menu: Control

func _ready() -> void:
	hide()
	controls_menu = CONTROLS_SCENE.instantiate()
	add_child(controls_menu)
	if not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)
	controls_button.pressed.connect(_on_controls_button_pressed)
	controls_menu.connect("exit_controls_menu", _on_controls_menu_closed)

func open_menu() -> void:
	show()
	main_options.show()
	controls_menu.hide()
	controls_button.grab_focus.call_deferred()

func _on_controls_button_pressed() -> void:
	main_options.hide()
	controls_menu.call("open_menu")

func _on_controls_menu_closed() -> void:
	controls_menu.hide()
	main_options.show()
	controls_button.grab_focus.call_deferred()

func _on_back_button_pressed() -> void:
	hide()
	exit_options_menu.emit()

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and main_options.is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_button_pressed()

func _on_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, value)

func _on_option_button_item_selected(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(RESOLUTIONS[index])
