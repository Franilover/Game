extends RefCounted
class_name PlayerInputController

## Adapta las acciones configuradas en InputMap a una intención de gameplay.
## No mueve al jugador ni decide si una acción puede ejecutarse.


func capturar() -> Dictionary:
	return {
		"focus_pressed": Input.is_action_pressed("focus"),
		"dash_just_pressed": Input.is_action_just_pressed("dash"),
		"run_pressed": Input.is_action_pressed("run"),
		"direction": Input.get_vector(
			"move_left",
			"move_right",
			"move_up",
			"move_down"
		),
		"eterium_sprint_pressed": Input.is_action_pressed("eterium_sprint"),
		"menu_key_pressed": Input.is_key_pressed(KEY_M)
	}


func es_combinacion_menu_reinos(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var tecla := event as InputEventKey
	return tecla.pressed and not tecla.echo and tecla.keycode == KEY_M and tecla.shift_pressed
