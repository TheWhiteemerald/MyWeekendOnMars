extends Node
## Add as an Autoload named InputSettings before opening ControlsMenu.

const ACTIONS := {
	"Left": "Move left", "Right": "Move right",
	"Up": "Aim drill up", "Down": "Aim drill down",
	"Jump": "Jump", "Dig": "Dig / Drill attack", "Pause": "Pause"
}
const SAVE_PATH := "user://rover_controls.cfg"
var defaults: Dictionary = {}
var config := ConfigFile.new()

func _ready() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			push_error("Missing Input Map action: " + action)
			continue
		defaults[action] = InputMap.action_get_events(action)
	if config.load(SAVE_PATH) == OK:
		for action in ACTIONS:
			for device in range(2):
				var data = config.get_value(str(device), action, null)
				if data is Dictionary:
					var event := decode(data)
					if event != null and device_kind(event) == device:
						apply_binding(action, device, event)

func device_kind(event: InputEvent) -> int:
	if event is InputEventKey or event is InputEventMouseButton:
		return 0
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return 1
	return -1

func apply_binding(action: String, device: int, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	for old in InputMap.action_get_events(action):
		if device_kind(old) == device:
			InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, event)

func bind_action(action: String, device: int, event: InputEvent) -> String:
	if not InputMap.has_action(action):
		return "Add the action '%s' in Project Settings > Input Map first." % action
	for other in ACTIONS:
		if other != action and InputMap.has_action(other):
			for existing in InputMap.action_get_events(other):
				if same_binding(event, existing):
					return "Already used by %s. Choose another input." % ACTIONS[other]
	apply_binding(action, device, event)
	config.set_value(str(device), action, encode(event))
	if config.save(SAVE_PATH) != OK:
		return "Applied for this session, but saving failed."
	return ""

func same_binding(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		if a.physical_keycode != 0 and b.physical_keycode != 0:
			return a.physical_keycode == b.physical_keycode
		var a_code: int = a.keycode if a.physical_keycode == 0 else DisplayServer.keyboard_get_keycode_from_physical(a.physical_keycode)
		var b_code: int = b.keycode if b.physical_keycode == 0 else DisplayServer.keyboard_get_keycode_from_physical(b.physical_keycode)
		return a_code == b_code
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false

func restore_defaults(device: int) -> bool:
	for action in defaults:
		for event in InputMap.action_get_events(action):
			if device_kind(event) == device:
				InputMap.action_erase_event(action, event)
		for event in defaults[action]:
			if device_kind(event) == device:
				InputMap.action_add_event(action, event)
	if config.has_section(str(device)):
		config.erase_section(str(device))
	return config.save(SAVE_PATH) == OK

func binding_text(action: String, device: int) -> String:
	var names := PackedStringArray()
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			if device_kind(event) == device:
				names.append(describe(event))
	return " / ".join(names) if not names.is_empty() else "Unassigned"

func describe(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: int = event.keycode
		if event.physical_keycode != 0:
			key = DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
		return OS.get_keycode_string(key)
	if event is InputEventJoypadMotion:
		var axis_names := ["Left stick X", "Left stick Y", "Right stick X", "Right stick Y", "Left trigger", "Right trigger"]
		var axis_name: String = axis_names[event.axis] if event.axis < axis_names.size() else "Axis %d" % event.axis
		var direction := "+" if event.axis_value > 0 else "-"
		if event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_RIGHT_X:
			direction = "right" if event.axis_value > 0 else "left"
		elif event.axis == JOY_AXIS_LEFT_Y or event.axis == JOY_AXIS_RIGHT_Y:
			direction = "down" if event.axis_value > 0 else "up"
		return axis_name + " " + direction
	return event.as_text()

func encode(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"kind": "key", "code": int(event.physical_keycode)}
	if event is InputEventMouseButton:
		return {"kind": "mouse", "code": int(event.button_index)}
	if event is InputEventJoypadButton:
		return {"kind": "button", "code": int(event.button_index)}
	if event is InputEventJoypadMotion:
		return {"kind": "axis", "code": int(event.axis), "value": event.axis_value}
	return {}

func decode(data: Dictionary) -> InputEvent:
	var code := int(data.get("code", -1))
	if code < 0:
		return null
	match data.get("kind", ""):
		"key":
			var event := InputEventKey.new()
			event.physical_keycode = code
			return event
		"mouse":
			var event := InputEventMouseButton.new()
			event.button_index = code
			return event
		"button":
			var event := InputEventJoypadButton.new()
			event.device = -1
			event.button_index = code
			return event
		"axis":
			var event := InputEventJoypadMotion.new()
			event.device = -1
			event.axis = code
			event.axis_value = 1.0 if float(data.get("value", 1.0)) > 0 else -1.0
			return event
	return null
