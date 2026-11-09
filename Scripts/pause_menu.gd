class_name PauseMenu
extends Control

@export_file("*.tscn") var main_menu_scene: String

@onready var resume: Button = \
	$TextureRect/MarginContainer/HBoxContainer/VBoxContainer/Resume

@onready var options_button: Button = \
	$"TextureRect/MarginContainer/HBoxContainer/VBoxContainer/Options Button"

@onready var main_menu_button: Button = \
	$"TextureRect/MarginContainer/HBoxContainer/VBoxContainer/Quit Button"

@onready var options_menu: OptionsMenu = $"Options Menu"
@onready var pause_panel: Control = $TextureRect
@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	# Receive input both during gameplay and while paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not resume.pressed.is_connected(_on_resume_game_pressed):
		resume.pressed.connect(_on_resume_game_pressed)

	if not options_button.pressed.is_connected(_on_options_pressed):
		options_button.pressed.connect(_on_options_pressed)

	if not main_menu_button.pressed.is_connected(_main_menu_pressed):
		main_menu_button.pressed.connect(_main_menu_pressed)

	if not options_menu.exit_options_menu.is_connected(_on_options_closed):
		options_menu.exit_options_menu.connect(_on_options_closed)

	# Hide the unused controls from the old menu.
	var old_controls := get_node_or_null("VBoxContainer")
	if old_controls is Control:
		old_controls.hide()

	options_menu.hide()
	pause_panel.show()
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return

	# Options and Controls handle their own Back/cancel input.
	if options_menu.is_visible_in_tree():
		return

	if event.is_action_pressed("Pause"):
		get_viewport().set_input_as_handled()

		if visible:
			_on_resume_game_pressed()
		elif not get_tree().paused:
			open_menu()

	elif visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume_game_pressed()

func open_menu() -> void:
	get_tree().paused = true

	options_menu.hide()
	pause_panel.show()
	show()

	resume.grab_focus.call_deferred()

func _on_resume_game_pressed() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()

	options_menu.hide()
	hide()
	get_tree().paused = false

func _on_options_pressed() -> void:
	pause_panel.hide()
	options_menu.open_menu()

func _on_options_closed() -> void:
	options_menu.hide()
	pause_panel.show()
	options_button.grab_focus.call_deferred()

func _main_menu_pressed() -> void:
	if main_menu_scene.is_empty():
		return

	var tree := get_tree()
	tree.paused = false

	var error := tree.change_scene_to_file(main_menu_scene)

	if error != OK:
		tree.paused = true
		push_error("Could not open the main menu: " + main_menu_scene)
		
