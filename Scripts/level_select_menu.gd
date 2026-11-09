extends Control

@export_file("*.tscn") var main_menu_scene: String

@onready var rows: VBoxContainer = $MarginContainer/VBoxContainer/Rows
@onready var details_label: Label = $DetailsLabel
@onready var back_button: Button = $BackButton

var cards: Array[LevelSelectCard] = []

func _ready() -> void:
	# Collect cards in row order.
	for row in rows.get_children():
		var grid := row.get_node("LevelGrid")

		for child in grid.get_children():
			if child is LevelSelectCard:
				cards.append(child)
				child.card_selected.connect(_show_details)

	configure_navigation()

	back_button.pressed.connect(_go_back)
	back_button.mouse_entered.connect(_focus_back)
	back_button.focus_entered.connect(_clear_details)

	if not cards.is_empty():
		cards[0].grab_focus.call_deferred()
	else:
		back_button.grab_focus.call_deferred()

func configure_navigation() -> void:
	var columns := 3

	for i in range(cards.size()):
		var card := cards[i]
		var column := i % columns

		# At the left/right edge, keep focus on this card.
		var left_index := i
		var right_index := i

		if column > 0:
			left_index = i - 1

		if column < columns - 1 and i + 1 < cards.size():
			right_index = i + 1

		card.focus_neighbor_left = card.get_path_to(cards[left_index])
		card.focus_neighbor_right = card.get_path_to(cards[right_index])

		if i >= columns:
			card.focus_neighbor_top = card.get_path_to(
				cards[i - columns]
			)
		else:
			card.focus_neighbor_top = card.get_path_to(card)

		if i + columns < cards.size():
			card.focus_neighbor_bottom = card.get_path_to(
				cards[i + columns]
			)
		else:
			card.focus_neighbor_bottom = card.get_path_to(back_button)

	if not cards.is_empty():
		back_button.focus_neighbor_top = back_button.get_path_to(
			cards[cards.size() - 1]
		)

	back_button.focus_neighbor_bottom = back_button.get_path_to(back_button)
	back_button.focus_neighbor_left = back_button.get_path_to(back_button)
	back_button.focus_neighbor_right = back_button.get_path_to(back_button)

func _show_details(description: String) -> void:
	details_label.text = description

func _focus_back() -> void:
	back_button.grab_focus()

func _clear_details() -> void:
	details_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()

func _go_back() -> void:
	if not main_menu_scene.is_empty():
		get_tree().change_scene_to_file(main_menu_scene)
	
