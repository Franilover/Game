@tool
extends EditorScript

const DEADZONE := 0.2


func _run() -> void:
	# Movimiento
	_set_action("move_up", [
		_key_physical(KEY_W),
		_key(KEY_UP),
		_joy_axis(JOY_AXIS_LEFT_Y, -1.0),
	])

	_set_action("move_down", [
		_key_physical(KEY_S),
		_key(KEY_DOWN),
		_joy_axis(JOY_AXIS_LEFT_Y, 1.0),
	])

	_set_action("move_left", [
		_key_physical(KEY_A),
		_key(KEY_LEFT),
		_joy_axis(JOY_AXIS_LEFT_X, -1.0),
	])

	_set_action("move_right", [
		_key_physical(KEY_D),
		_key(KEY_RIGHT),
		_joy_axis(JOY_AXIS_LEFT_X, 1.0),
	])

	_set_action("run", [
		_key(KEY_SHIFT),
		_joy_button(JOY_BUTTON_LEFT_STICK),
	])

	# Interacción / acciones
	_set_action("interact", [
		_key_physical(KEY_E),
		_joy_button(JOY_BUTTON_A),
	])

	_set_action("primary_action", [
		_mouse(MOUSE_BUTTON_LEFT),
		_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0),
	])

	_set_action("secondary_action", [
		_mouse(MOUSE_BUTTON_RIGHT),
		_joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0),
	])

	_set_action("confirm", [
		_key(KEY_ENTER),
		_joy_button(JOY_BUTTON_A),
	])

	_set_action("cancel", [
		_key(KEY_ESCAPE),
		_joy_button(JOY_BUTTON_B),
	])

	_set_action("dodge", [
		_key(KEY_SPACE),
		_joy_button(JOY_BUTTON_B),
	])

	# Investigación
	_set_action("analyze", [
		_key(KEY_TAB),
		_joy_button(JOY_BUTTON_LEFT_SHOULDER),
	])

	_set_action("focus", [
		_key_physical(KEY_Q),
		_joy_button(JOY_BUTTON_RIGHT_STICK),
	])

	_set_action("use_ium", [
		_key_physical(KEY_R),
		_joy_button(JOY_BUTTON_RIGHT_SHOULDER),
	])

	# Menús
	_set_action("inventory", [
		_key_physical(KEY_I),
		_joy_button(JOY_BUTTON_X),
	])

	_set_action("character", [
		_key_physical(KEY_C),
		_joy_button(JOY_BUTTON_Y),
	])

	_set_action("map", [
		_key_physical(KEY_M),
		_joy_button(JOY_BUTTON_DPAD_RIGHT),
	])

	_set_action("journal", [
		_key_physical(KEY_J),
		_joy_button(JOY_BUTTON_DPAD_UP),
	])

	_set_action("codex", [
		_key_physical(KEY_K),
		_joy_button(JOY_BUTTON_DPAD_DOWN),
	])

	_set_action("pause", [
		_key(KEY_ESCAPE),
		_joy_button(JOY_BUTTON_START),
	])

	# Cámara
	_set_action("camera_zoom_in", [
		_mouse(MOUSE_BUTTON_WHEEL_UP),
		_key(KEY_KP_ADD),
	])

	_set_action("camera_zoom_out", [
		_mouse(MOUSE_BUTTON_WHEEL_DOWN),
		_key(KEY_KP_SUBTRACT),
	])

	_set_action("camera_reset", [
		_key(KEY_HOME),
	])

	# Objetos rápidos
	_set_action("slot_1", [_key_physical(KEY_1)])
	_set_action("slot_2", [_key_physical(KEY_2)])
	_set_action("slot_3", [_key_physical(KEY_3)])
	_set_action("slot_4", [_key_physical(KEY_4)])
	_set_action("slot_5", [_key_physical(KEY_5)])
	_set_action("slot_6", [_key_physical(KEY_6)])
	_set_action("slot_7", [_key_physical(KEY_7)])
	_set_action("slot_8", [_key_physical(KEY_8)])

	var error := ProjectSettings.save()

	if error == OK:
		print("Garlia: Input Map guardado correctamente en project.godot")
	else:
		push_error("Garlia: no se pudo guardar project.godot. Error: %s" % error)


func _set_action(action_name: String, events: Array[InputEvent]) -> void:
	var setting_path := "input/" + action_name

	var action := {
		"deadzone": DEADZONE,
		"events": events,
	}

	ProjectSettings.set_setting(setting_path, action)


func _key(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = key
	return event


func _key_physical(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event
