class_name Sign
extends Area2D

@export_multiline var dialogue_pages: Array[String]
@export var characters_per_second: float = 40.0

@onready var dialogue_panel: Control = $CanvasLayer/DialoguePanel
@onready var label: Label = $CanvasLayer/DialoguePanel/MarginContainer/Label
@onready var interaction_icon = $InteractionIcon

var player_in_range: bool = false
var current_player: Node2D = null

var is_reading: bool = false
var is_typing: bool = false

var typing_progress: float = 0.0
var current_page: int = 0


func _ready() -> void:
	interaction_icon.hide()
	dialogue_panel.hide()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if is_typing:
		update_typewriter(delta)

	if not Input.is_action_just_pressed("Dig"):
		return

	if is_reading:
		handle_dialogue_input()
	elif player_in_range:
		start_dialogue()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = true
	current_player = body
	interaction_icon.show()


func _on_body_exited(body: Node2D) -> void:
	if body != current_player:
		return

	player_in_range = false
	current_player = null
	interaction_icon.hide()


func start_dialogue() -> void:
	if dialogue_pages.is_empty():
		return

	is_reading = true
	current_page = 0

	interaction_icon.hide()
	dialogue_panel.show()

	get_tree().paused = true

	show_current_page()


func end_dialogue() -> void:
	is_reading = false
	is_typing = false

	dialogue_panel.hide()

	get_tree().paused = false

	if player_in_range:
		interaction_icon.show()


func advance_dialogue() -> void:
	current_page += 1

	if current_page >= dialogue_pages.size():
		end_dialogue()
		return

	show_current_page()


func show_current_page() -> void:
	label.text = dialogue_pages[current_page]
	label.visible_characters = 0

	typing_progress = 0.0
	is_typing = true


func update_typewriter(delta: float) -> void:
	typing_progress += characters_per_second * delta

	label.visible_characters = int(typing_progress)

	if label.visible_characters >= label.text.length():
		label.visible_characters = -1
		is_typing = false


func handle_dialogue_input() -> void:
	if is_typing:
		label.visible_characters = -1
		is_typing = false
		return

	advance_dialogue()
