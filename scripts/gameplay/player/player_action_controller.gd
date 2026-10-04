extends RefCounted
class_name PlayerActionController

## Estado de acciones especiales del jugador.
## No conoce input, UI ni física.

var jump_time: float = 0.0
var jump_cooldown_timer: float = 0.0
var dash_time: float = 0.0
var dash_cooldown_timer: float = 0.0

func actualizar_cooldowns(delta: float) -> void:
	jump_cooldown_timer = maxf(jump_cooldown_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)

func puede_saltar() -> bool:
	return jump_cooldown_timer <= 0.0

func puede_hacer_dash() -> bool:
	return dash_cooldown_timer <= 0.0

func iniciar_salto(duracion: float, cooldown: float) -> bool:
	if not puede_saltar():
		return false
	jump_time = maxf(duracion, 0.0)
	jump_cooldown_timer = maxf(cooldown, 0.0)
	return true

func iniciar_dash(duracion: float, cooldown: float) -> bool:
	if not puede_hacer_dash():
		return false
	dash_time = maxf(duracion, 0.0)
	dash_cooldown_timer = maxf(cooldown, 0.0)
	return true

func procesando_salto() -> bool:
	return jump_time > 0.0

func procesando_dash() -> bool:
	return dash_time > 0.0

func avanzar_salto(delta: float) -> void:
	jump_time = maxf(jump_time - delta, 0.0)

func avanzar_dash(delta: float) -> void:
	dash_time = maxf(dash_time - delta, 0.0)
