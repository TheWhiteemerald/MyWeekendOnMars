extends Control

signal exit_controls_menu

@onready var device_picker: OptionButton = %DevicePicker
@onready var rows: GridContainer = %Rows
@onready var status: Label = %Status
@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton

var buttons: Dictionary = {}
var capturing: String = ""
var remaining: float = 0.0
var neutral_axes: Dictionary = {}
var pressed_inputs: Dictionary = {}
var pending_axis: InputEventJoypadMotion = null

func _ready() -> void:
	hide()
	device_picker.add_item("Keyboard & Mouse", 0)
	device_picker.add_item("Controller", 1)
	device_picker.item_selected.connect(_on_device_selected)
	reset_button.pressed.connect(_on_reset)
	back_button.pressed.connect(_on_back)
	var navigation: Array[Control] = [device_picker]
	for action in InputSettings.ACTIONS:
		var label := Label.new()
		label.text = InputSettings.ACTIONS[action]
		rows.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 38)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.focus_mode = Control.FOCUS_ALL
		rows.add_child(button)
		buttons[action] = button
		button.pressed.connect(_begin_capture.bind(action))
		button.mouse_entered.connect(_hover_focus.bind(button))
		navigation.append(button)
	navigation.append(reset_button)
	navigation.append(back_button)
	for i in range(navigation.size()):
		var control := navigation[i]
		control.focus_neighbor_top = control.get_path_to(navigation[maxi(i - 1, 0)])
		control.focus_neighbor_bottom = control.get_path_to(navigation[mini(i + 1, navigation.size() - 1)])
		control.focus_previous = control.get_path_to(navigation[(i - 1 + navigation.size()) % navigation.size()])
		control.focus_next = control.get_path_to(navigation[(i + 1) % navigation.size()])
	visibility_changed.connect(_on_visibility_changed)
	_refresh()

func open_menu() -> void:
	show()
	_refresh()
	status.text = "Choose an action to change. Bindings save automatically."
	device_picker.grab_focus.call_deferred()

func _on_device_selected(_index: int) -> void:
	_refresh()
	status.text = "Choose an action to change. Bindings save automatically."

func _refresh() -> void:
	for action in buttons:
		var text: String = InputSettings.binding_text(action, device_picker.selected)
		buttons[action].text = text
		buttons[action].tooltip_text = text

func _hover_focus(button: Button) -> void:
	if capturing.is_empty():
		button.grab_focus()

func _begin_capture(action: String) -> void:
	capturing = action
	remaining = 10.0
	pressed_inputs.clear()
	neutral_axes.clear()
	pending_axis = null
	for pad in Input.get_connected_joypads():
		for axis in range(JOY_AXIS_MAX):
			neutral_axes[Vector2i(pad, axis)] = absf(Input.get_joy_axis(pad, axis)) < 0.25
	buttons[action].text = "Waiting..."
	status.text = "Press and release an input for %s. Escape cancels; timeout 10 seconds." % InputSettings.ACTIONS[action]

func _process(delta: float) -> void:
	if capturing.is_empty():
		return
	remaining -= delta
	if remaining <= 0.0:
		_finish_capture("No changes made (timed out).")

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or capturing.is_empty():
		return
	# Consume capture input before it reaches focused UI controls.
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		if not event.pressed:
			_finish_capture("No changes made.")
		return
	if InputSettings.device_kind(event) != device_picker.selected:
		return
	if event is InputEventKey:
		if event.echo or event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:
			return
		if event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			return
		var token := "key:%d" % event.physical_keycode
		if event.pressed:
			pressed_inputs[token] = true
		elif pressed_inputs.has(token):
			var binding := InputEventKey.new()
			binding.physical_keycode = event.physical_keycode
			_accept(binding)
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		var token := "%s:%d:%d" % [event.get_class(), event.device, event.button_index]
		if event.pressed:
			pressed_inputs[token] = true
			# Wheel inputs do not consistently provide release events.
			if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
				_accept(InputSettings.decode(InputSettings.encode(event)))
		elif pressed_inputs.has(token):
			_accept(InputSettings.decode(InputSettings.encode(event)))
	elif event is InputEventJoypadMotion:
		var token := Vector2i(event.device, event.axis)
		if absf(event.axis_value) < 0.25:
			neutral_axes[token] = true
			if pending_axis != null and pending_axis.device == event.device and pending_axis.axis == event.axis:
				_accept(InputSettings.decode(InputSettings.encode(pending_axis)))
		elif pending_axis == null and neutral_axes.get(token, false) and absf(event.axis_value) >= 0.65:
			pending_axis = event.duplicate() as InputEventJoypadMotion
			status.text = "Release the stick or trigger to confirm. Escape cancels."

func _accept(event: InputEvent) -> void:
	var message: String = InputSettings.bind_action(capturing, device_picker.selected, event)
	if message.begins_with("Already used"):
		status.text = message + " Escape cancels."
		pressed_inputs.clear()
		pending_axis = null
		remaining = 10.0
		return
	_finish_capture("Binding saved." if message.is_empty() else message)

func _finish_capture(message: String) -> void:
	var action := capturing
	capturing = ""
	pending_axis = null
	pressed_inputs.clear()
	_refresh()
	status.text = message
	if is_visible_in_tree() and buttons.has(action):
		buttons[action].grab_focus.call_deferred()

func _on_reset() -> void:
	var saved: bool = InputSettings.restore_defaults(device_picker.selected)
	_refresh()
	status.text = "Defaults restored for this device." if saved else "Defaults restored, but saving failed."

func _on_back() -> void:
	exit_controls_menu.emit()

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and capturing.is_empty() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		capturing = ""
		pending_axis = null
