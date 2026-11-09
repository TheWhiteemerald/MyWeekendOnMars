class_name LevelSelectCard
extends Button

signal card_selected(description: String)

@export var level_name: String = "Level 1"
@export var thumbnail: Texture2D
@export_file("*.tscn") var scene_path: String

# Temporary Inspector values.
# Later, populate these from saved progress.
@export var replay_unlocked: bool = false
@export var crystal_requirement_met: bool = false
@export var locked_reason: String = "Beat this level to unlock replay."

@onready var thumbnail_rect: TextureRect = \
	$MarginContainer/VBoxContainer/Thumbnail
@onready var name_label: Label = \
	$MarginContainer/VBoxContainer/LevelName
@onready var status_label: Label = \
	$MarginContainer/VBoxContainer/StatusLabel

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL

	thumbnail_rect.texture = thumbnail
	name_label.text = level_name
	refresh_status()

	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_on_focus_entered)
	pressed.connect(_on_pressed)

func refresh_status() -> void:
	if not replay_unlocked:
		status_label.text = "Locked"
	elif crystal_requirement_met:
		status_label.text = "Beaten • Crystals complete"
	else:
		status_label.text = "Beaten • Crystals incomplete"

func _on_mouse_entered() -> void:
	grab_focus()

func _on_focus_entered() -> void:
	var description := locked_reason

	if replay_unlocked:
		description = "Replay " + level_name

		if crystal_requirement_met:
			description += " — crystal requirement already met."
		else:
			description += " — crystal requirement still incomplete."
	
	card_selected.emit(description)


func _on_pressed() -> void:
	if not replay_unlocked:
		card_selected.emit(locked_reason)
		return
	
	if scene_path.is_empty():
		card_selected.emit("No scene assigned to this card yet.")
		return
	
	var error := get_tree().change_scene_to_file(scene_path)
	
	if error != OK:
		push_error("Could not open level: " + scene_path)
	
